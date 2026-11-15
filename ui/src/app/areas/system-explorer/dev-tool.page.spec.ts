import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import type { ConnectivityService } from '../../core/connectivity';
import { NavigationService } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenArrivals } from '../../core/screen-arrival';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS, type ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { DevToolPage } from './dev-tool.page';

/**
 * Code metrics and Document hashes over the shipped descriptors, with the real `RefreshService`, `ScreenStores`, `ChangeBus` and
 * `ScreenArrivals` and a stubbed HTTP answer (Story 24.1): nothing read before a search, the search's exact criteria, the rows the
 * read answered held by the screen's store, a refused search shown with the instance's reason in place of the rows, an agent's
 * arrival run once, and a re-read when a class in the namespace changes.
 */

const METRICS = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.ExplorerCodeMetrics') as ScreenDeclaration;
const HASHES = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.ExplorerDocumentHashes') as ScreenDeclaration;

const HASH_ROWS = [
  { Document: 'Demo.One.cls', Hash: 'A'.repeat(64), Modified: '2026-11-15 05:26:40.7' },
  { Document: 'Demo.Two.cls', Hash: 'B'.repeat(64), Modified: '2026-11-15 05:27:40.7' },
];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 20));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

const planted: HTMLElement[] = [];

async function mount(
  screen: ScreenDeclaration,
  options: { rows?: readonly unknown[]; truncated?: boolean; arrivals?: ScreenArrivals; refusal?: { status: number; code: string; reason: string | null } } = {}
) {
  TestBed.resetTestingModule();
  const paths: string[] = [];
  const answer = { refusal: options.refusal };
  const bus = new ChangeBus();
  const api = {
    requestJson: async <T,>(path: string): Promise<JsonResult<T>> => {
      paths.push(path);
      if (answer.refusal !== undefined) return { kind: 'error', status: answer.refusal.status, code: answer.refusal.code, reason: answer.refusal.reason, detail: null };
      return { kind: 'ok', status: 200, body: { fields: [], rows: options.rows ?? HASH_ROWS, truncated: options.truncated ?? false, banner: '' } as T };
    },
  };
  const stores = new ScreenStores({ account: stubAccountPreferences() });
  const refresh = new RefreshService({
    stores,
    connectivity: { retryWhenReachable: () => {} } as unknown as ConnectivityService,
    bus,
    namespace: () => 'HSCUSTOM',
    schedule: () => {},
  });
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: NavigationService, useValue: { screenForUrl: () => screen } as unknown as NavigationService },
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: RefreshService, useValue: refresh },
      { provide: ScreenStores, useValue: stores },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: OverlayStack, useValue: new OverlayStack() },
      { provide: ChangeBus, useValue: bus },
      { provide: ScreenArrivals, useValue: options.arrivals ?? new ScreenArrivals() },
      {
        provide: ScopeService,
        useValue: { loaded: () => true, namespace: () => 'HSCUSTOM', subscribe: () => () => undefined } as unknown as ScopeService,
      },
    ],
  });
  await TestBed.inject(Router).navigateByUrl(`/${screen.route}?ns=HSCUSTOM`);
  const fixture = TestBed.createComponent(DevToolPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  const host = fixture.nativeElement as HTMLElement;
  return {
    host,
    paths,
    bus,
    stores,
    answer,
    search: async (spec: string, generated = false) => {
      const input = host.querySelector('[data-ocu-devtool="spec"]') as HTMLInputElement;
      input.value = spec;
      input.dispatchEvent(new Event('input'));
      const box = host.querySelector('[data-ocu-devtool="generated"]') as HTMLInputElement;
      box.checked = generated;
      box.dispatchEvent(new Event('change'));
      (host.querySelector('[data-ocu-devtool="submit"]') as HTMLButtonElement).click();
      await settle(fixture);
    },
    settle: () => settle(fixture),
  };
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
});

describe('System Explorer Code metrics and Document hashes', () => {
  it("draw the descriptor's labels and hint, read nothing until Search is pressed with a pattern, and invite a search", async () => {
    for (const [screen, invite] of [
      [METRICS, STRINGS.explorerCodeMetricsInvite],
      [HASHES, STRINGS.explorerDocumentHashesInvite],
    ] as const) {
      const { host, paths, search } = await mount(screen);
      expect(paths).toEqual([]);
      expect(host.querySelector('label[for="ocu-devtool-spec"]')?.textContent?.trim()).toBe(STRINGS.explorerDocumentsLabel);
      expect(host.querySelector('.ocu-criteria-hint')?.textContent?.trim()).toBe('Names separated by commas, with * and ? as wildcards, such as MyApp.*.cls,*.mac.');
      expect(host.querySelector('.ocu-criteria-marker')?.textContent?.trim()).toBe(STRINGS.explorerIncludeGeneratedLabel);
      expect(host.querySelector('[data-ocu-devtool="invite"]')?.textContent?.trim()).toBe(invite);
      expect(host.querySelector('app-data-table')).toBeNull();
      await search('   ');
      expect(paths).toEqual([]);
    }
  });

  it('sends the pattern and the generated choice as typed, and holds the rows the read answered', async () => {
    const { host, paths, search, stores } = await mount(HASHES);
    await search('Demo.*.cls', true);
    expect(paths).toEqual(['/api/ocupilot/screens/explorer.documenthashes/read?maxRows=1000&spec=Demo.*.cls&generated=yes']);
    expect(host.querySelector('app-data-table')).not.toBeNull();
    expect(host.querySelector('[data-ocu-devtool="invite"]')).toBeNull();
    expect(stores.for(HASHES.descriptor, HASHES.refreshRates).data()).toEqual(HASH_ROWS);
    expect(host.querySelector('[data-ocu-devtool="status"]')?.textContent?.trim()).toBe('');
  });

  it('says the list was cut when the read truncated it', async () => {
    const { host, search } = await mount(HASHES, { truncated: true });
    await search('Demo.*.cls');
    expect(host.querySelector('[data-ocu-devtool="status"]')?.textContent?.trim()).toBe(STRINGS.tableRowCapNotice.replace('<n>', '1,000'));
  });

  it("draws a refused search with the instance's reason, and no table", async () => {
    // Mutation (Rule 19): draw the generic sentence alone in `refusalText` -> the reason assertion goes red.
    const { host, search } = await mount(METRICS, { refusal: { status: 400, code: 'EXPLORER.SPEC.WIDE', reason: STRINGS.explorerSpecWideReason } });
    await search('*');
    expect(host.querySelector('[data-ocu-devtool="fault"] .ocu-data-table-refusal-message')?.textContent?.trim()).toBe(STRINGS.explorerSpecWideReason);
    expect(host.querySelector('app-data-table')).toBeNull();
    expect(host.querySelector('[data-ocu-devtool="status"]')?.textContent?.trim()).toBe('');
  });

  it('falls back to the generic sentence for a refusal that carries no reason', async () => {
    const { host, search } = await mount(METRICS, { refusal: { status: 403, code: 'AUTH.NOPRIVILEGE', reason: null } });
    await search('Demo.*.cls');
    expect(host.querySelector('[data-ocu-devtool="fault"] .ocu-data-table-refusal-message')?.textContent?.trim()).toBe(STRINGS.connectivityRequestRefused);
  });

  it("runs an agent's arrival once, with its criteria shown in the form", async () => {
    const arrivals = new ScreenArrivals();
    arrivals.set({ route: METRICS.route, criterion: '', criteria: { spec: 'Demo.*.cls', generated: 'yes' } });
    const { host, paths } = await mount(METRICS, { arrivals });
    expect(paths).toEqual(['/api/ocupilot/screens/explorer.codemetrics/read?maxRows=1000&spec=Demo.*.cls&generated=yes']);
    expect((host.querySelector('[data-ocu-devtool="spec"]') as HTMLInputElement).value).toBe('Demo.*.cls');
    expect((host.querySelector('[data-ocu-devtool="generated"]') as HTMLInputElement).checked).toBe(true);
  });

  it('runs the last search again when a class in this namespace changes', async () => {
    const { paths, search, bus, settle: wait } = await mount(HASHES);
    await search('Demo.*.cls');
    bus.publish({ kind: 'changed', type: 'class', scope: 'HSCUSTOM', id: 'Demo.One.cls', action: 'updated' });
    await wait();
    expect(paths).toHaveLength(2);
    expect(paths[1]).toBe(paths[0]);
  });

  it('clears a refusal when the next search is answered, and Retry runs the refused search again', async () => {
    // Mutation (Rule 19): make `onRetry` do nothing -> the second request never happens and the retry leg goes red; keep the
    // refusal after an answered read -> the clearing leg goes red.
    const { host, paths, search, answer, settle: wait } = await mount(METRICS, { refusal: { status: 400, code: 'EXPLORER.SPEC.WIDE', reason: STRINGS.explorerSpecWideReason } });
    await search('*');
    expect(host.querySelector('[data-ocu-devtool="fault"]')).not.toBeNull();
    answer.refusal = undefined;
    (host.querySelector('[data-ocu-devtool="fault"] button') as HTMLButtonElement).click();
    await wait();
    expect(paths).toHaveLength(2);
    expect(paths[1]).toBe(paths[0]);
    expect(host.querySelector('[data-ocu-devtool="fault"]')).toBeNull();
    expect(host.querySelector('app-data-table')).not.toBeNull();
  });
});
