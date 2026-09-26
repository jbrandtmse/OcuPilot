/**
 * The data table's browser harness (Story 2.4): `DataTable` over the real `ScreenStores`,
 * `RefreshService` and `createScreenRead`, reading `GET /api/ocupilot/screens/<id>/read` from the
 * origin that serves it. `browser/data-table.browser-spec.mjs` serves `dist/table-harness` and answers
 * that read, so geometry, focus under recycling and 1,000-row timing are observed in a real browser
 * with no instance.
 *
 * Built only by `ng build --configuration production,harness` (`tsconfig.harness.json`); nothing
 * reachable from `src/main.ts` imports this directory, and `ui/tools/client-lint.mjs` refuses a
 * shipped file that would.
 *
 * `window.ocuHarness` lets the spec re-read with a row set of its own, mark a key changed, pause
 * the screen's refresh with a live proposal, sort by a field, and read the column widths the store
 * holds and the last view value it sent.
 */

import {
  ChangeDetectionStrategy,
  Component,
  inject,
  provideZonelessChangeDetection,
} from '@angular/core';
import { bootstrapApplication } from '@angular/platform-browser';
import { provideRouter } from '@angular/router';

import type { ApiService, JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import type { ConnectivityService } from '../../core/connectivity';
import { OverlayStack } from '../../core/overlay-stack';
import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { createScreenRead } from '../../core/screen-read';
import { ScreenStores } from '../../core/screen-store';
import { DataTable } from '../../shell/data-table';
import { lastRemembered, stubAccountPreferences } from '../account-preferences';
import { tableDeclaration } from '../table-declaration';

/** What `reread` answers the next reads with, instead of the origin. */
interface RowSet {
  readonly rows: readonly unknown[];
  readonly truncated: boolean;
}

/** The hooks the browser spec drives. */
export interface TableHarnessHooks {
  reread(rows: readonly unknown[], truncated?: boolean): Promise<void>;
  markChanged(key: string): void;
  pause(): void;
  paused(): boolean;
  active(): string;
  selection(): readonly string[];
  /** The column widths the store holds, by field (Story 15.8). */
  widths(): Readonly<Record<string, number>>;
  /** The last `view` value the table sent to the account store, or `''` before any. */
  rememberedView(): string;
  /** Sort the table by `field`, as the screen's sort control does. */
  sort(field: string): void;
}

declare global {
  interface Window {
    ocuHarness?: TableHarnessHooks;
  }
}

const NAMESPACE = 'HSCUSTOM';

const declaration = tableDeclaration({
  refreshes: true,
  refreshRates: [10],
  rowActions: [{ id: 'disable', selfProtection: '' }],
  table: { ...tableDeclaration().table!, emptyNextKey: '', emptyAgentKey: 'classicLinkCardTitle' },
});

let override: RowSet | null = null;

const api: Pick<ApiService, 'requestJson'> = {
  async requestJson<T>(path: string): Promise<JsonResult<T>> {
    if (override !== null) {
      return { kind: 'ok', status: 200, body: { fields: [], rows: override.rows, truncated: override.truncated } as T };
    }
    try {
      const response = await fetch(path, { headers: { accept: 'application/json' } });
      const body = (await response.json()) as T;
      if (response.ok) return { kind: 'ok', status: response.status, body };
      return { kind: 'error', status: response.status, code: null, reason: null, detail: null };
    } catch {
      return { kind: 'error', status: 0, code: null, reason: null, detail: null };
    }
  },
};

const bus = new ChangeBus();
const account = stubAccountPreferences();
const stores = new ScreenStores({ account });
const refresh = new RefreshService({
  stores,
  connectivity: { retryWhenReachable: () => {} } as unknown as ConnectivityService,
  bus,
  namespace: () => NAMESPACE,
  schedule: () => {},
});
const store = stores.for(declaration.descriptor, declaration.refreshRates, declaration.route);
const overlays = new OverlayStack();

// The table draws a row action only while a handler is registered for it (DW-389), so every row
// action the harness declares is registered here. Running one does nothing: the specs over this
// harness pin the menu's geometry and keyboard, never an action's effect.
const actions = new ScreenActions();
for (const action of declaration.rowActions) {
  actions.register(declaration.descriptor, action.id, () => {});
}

refresh.bind(declaration, createScreenRead(api, declaration));

window.ocuHarness = {
  reread(rows, truncated = false) {
    override = { rows, truncated };
    return refresh.readNow();
  },
  markChanged(key) {
    store.markChanged(key);
  },
  pause() {
    refresh.setRate(10);
    bus.publish({ kind: 'proposal-open', type: declaration.entityType, scope: NAMESPACE, id: 'harness', proposalId: 'harness' });
  },
  paused: () => refresh.paused(),
  active: () => store.active(),
  selection: () => store.selection(),
  widths: () => Object.fromEntries(store.columnWidths()),
  rememberedView: () => lastRemembered(account.calls, declaration.route) ?? '',
  sort: (field) => store.setSort(field),
};

/** The page: the table filling the viewport, and the shell's one Escape handler. */
@Component({
  selector: 'app-table-harness',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [DataTable],
  host: { '(document:keydown.escape)': 'onEscape()' },
  styles: [':host { box-sizing: border-box; display: flex; flex-direction: column; height: 100vh; padding: var(--ocu-gutter); }'],
  template: `<app-data-table [screen]="screen" [store]="store" />`,
})
class TableHarness {
  private readonly overlays = inject(OverlayStack);
  protected readonly screen = declaration;
  protected readonly store = store;

  protected onEscape(): void {
    this.overlays.closeTop();
  }
}

bootstrapApplication(TableHarness, {
  providers: [
    provideZonelessChangeDetection(),
    provideRouter([{ path: '**', children: [] }]),
    { provide: RefreshService, useValue: refresh },
    { provide: ScreenStores, useValue: stores },
    { provide: ChangeBus, useValue: bus },
    { provide: OverlayStack, useValue: overlays },
    { provide: ScreenActions, useValue: actions },
    { provide: ScopeService, useValue: { namespace: () => NAMESPACE, subscribe: () => () => {} } as unknown as ScopeService },
  ],
})
  .then(() => refresh.readNow())
  .catch((err) => console.error(err));
