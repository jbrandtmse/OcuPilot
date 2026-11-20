import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { ApiService } from '../../core/api';
import { screenForDescriptor } from '../../core/navigation';
import { ScopeService } from '../../core/scope';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { STRINGS } from '../../core/strings';
import { DetailPage } from '../../shell/detail-page';
import { MDX_BACKGROUND_SCHEDULE } from './mdx-query.page';
import { MdxQueryState, PIVOT_RUN_KIND, type MdxQueryDeps } from './mdx-query.store';
import { MdxRunView } from './mdx-run-view';

/** The Definition tab's descriptor (Story 24.14). */
export const FOLDER_ITEM_DEFINITION = 'OcuPilot.Screen.Descriptor.AnalyticsFolderItemDefinitionTab';

/** The text of `row`'s member `name`, or `''`. */
function memberText(row: unknown, name: string): string {
  if (row === null || typeof row !== 'object') return '';
  const value = (row as Readonly<Record<string, unknown>>)[name];
  return typeof value === 'string' ? value : '';
}

/**
 * Analytics' Definition tab of a folder item (Story 24.14, AD-5): the detail page over the shared list page, which draws the one row of what a saved pivot or
 * dashboard holds, and under it, for a pivot, Run: MDX query's own run over the pivot's MDX, which the instance composes from the saved item (the browser
 * sends the item's name, never a statement; AD-11, AD-65). The status line, the grid, the drill-through and the confirmation a stored SQL restriction asks
 * first are `MdxRunView`'s, the same as MDX query's. A refusal (an item that is not a pivot on a cube the namespace holds) is the banner above Run.
 *
 * The run's state belongs to this page and the item it shows: another item, or leaving the page, drops it (a run left running is left, as MDX query's is).
 * A dashboard offers no Run.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-folder-item-definition-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [DetailPage, MdxRunView],
  // The height chain every page host carries, so the list's viewport keeps its height; the run's panel scrolls within its own share.
  styles: `
    :host {
      display: flex;
      flex: 1 1 auto;
      flex-direction: column;
      min-height: 0;
    }
    .ocu-pivot-run {
      flex: 0 0 auto;
      max-height: 50%;
      overflow: auto;
    }
  `,
  template: `<app-detail-page />
    @if (isPivot) {
      <section class="ocu-form-page ocu-mdx-query ocu-pivot-run" data-ocu-pivot="run-panel" [attr.aria-busy]="busy">
        @if (hasRefusal) {
          <p class="ocu-banner ocu-banner-warning" role="alert" data-ocu-pivot="banner">{{ refusal }}</p>
        }
        <div class="ocu-criteria-controls">
          @if (running) {
            <button type="button" class="ocu-button-text" data-ocu-pivot="cancel" (click)="onCancelRun()">{{ STRINGS.actionCancel }}</button>
          }
          <button type="button" class="ocu-button-primary" data-ocu-pivot="run" [attr.aria-disabled]="blocked" (click)="onRun()">{{ STRINGS.actionRun }}</button>
        </div>
        <app-mdx-run-view [state]="state" [deps]="deps" [version]="version" />
      </section>
    }`,
})
export class FolderItemDefinitionPage {
  private readonly stores = inject(ScreenStores);
  private readonly scope = inject(ScopeService);

  protected readonly STRINGS = STRINGS;

  protected state: MdxQueryState = new MdxQueryState(PIVOT_RUN_KIND);

  protected readonly deps: MdxQueryDeps;

  private readonly store: ScreenStore | null;

  /** The item this page's state belongs to. */
  private itemName = '';

  /** Bumped by the store and the state, so the page re-renders under `OnPush`. */
  private readonly generation = signal(0);

  private stopState: () => void = () => undefined;

  constructor() {
    const screen = screenForDescriptor(FOLDER_ITEM_DEFINITION);
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    this.deps = {
      api: inject(ApiService),
      scope: () => this.scope.namespace(),
      schedule: inject(MDX_BACKGROUND_SCHEDULE),
    };
    this.follow();
    const stopStore = this.store === null ? () => undefined : this.store.subscribe(() => this.onRows());
    const stopScope = this.scope.subscribe(() => this.state.scopeChanged(this.deps));
    this.onRows();
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopScope();
      this.stopState();
      this.state.leave();
    });
  }

  /** The state's change count, which the run view re-renders on. */
  protected get version(): number {
    return this.generation();
  }

  /** The tab's one row, or `null` when it reads none. */
  private get row(): unknown {
    return this.store?.data()[0] ?? null;
  }

  /** Whether the item is a pivot: it names a cube. A dashboard names none. */
  protected get isPivot(): boolean {
    this.generation();
    return memberText(this.row, 'Name') !== '' && memberText(this.row, 'Cube') !== '';
  }

  protected get busy(): boolean {
    this.generation();
    return this.state.busy();
  }

  protected get running(): boolean {
    this.generation();
    return this.state.status() === 'running';
  }

  /** Run answers nothing while a run is live. */
  protected get blocked(): boolean {
    this.generation();
    return this.state.busy() || this.itemName === '';
  }

  protected get refusal(): string {
    this.generation();
    return this.state.refusal();
  }

  protected get hasRefusal(): boolean {
    return this.refusal !== '';
  }

  protected onRun(): void {
    if (this.blocked) return;
    void this.state.runStatement(this.deps);
  }

  protected onCancelRun(): void {
    void this.state.cancelRun(this.deps);
  }

  /** The row changed: a run belongs to the item it was started for, so another item starts with a state of its own. */
  private onRows(): void {
    const name = memberText(this.row, 'Name');
    if (name !== this.itemName) {
      this.itemName = name;
      this.stopState();
      this.state.leave();
      this.state = new MdxQueryState(PIVOT_RUN_KIND);
      this.state.setText(name);
      void this.state.loadCubes(this.deps);
      this.follow();
    }
    this.bump();
  }

  /** Re-render when the current state changes. */
  private follow(): void {
    this.stopState = this.state.subscribe(() => this.bump());
  }

  private bump(): void {
    this.generation.update((value) => value + 1);
  }
}
