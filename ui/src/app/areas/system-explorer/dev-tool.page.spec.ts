import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
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
 * Code metrics, Document hashes and (Story 24.8) Compare namespaces over the shipped descriptors, with the real `RefreshService`, `ScreenStores`, `ChangeBus` and
 * `ScreenArrivals` and a stubbed HTTP answer (Story 24.1): nothing read before a search, the search's exact criteria, the rows the
 * read answered held by the screen's store, a refused search shown with the instance's reason in place of the rows, an agent's
 * arrival run once, and a re-read when a class in the namespace changes.
 */

const METRICS = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.ExplorerCodeMetrics') as ScreenDeclaration;
const HASHES = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.ExplorerDocumentHashes') as ScreenDeclaration;
const DIFF = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.ExplorerNamespaceDiff') as ScreenDeclaration;

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

/** A promote's dry-run and action requests, kept apart from the reads the other specs count in `paths`. */
interface PromoteRequest {
  readonly path: string;
  readonly body: Record<string, unknown>;
}

async function mount(
  screen: ScreenDeclaration,
  options: {
    rows?: readonly unknown[];
    truncated?: boolean;
    arrivals?: ScreenArrivals;
    namespaces?: readonly string[];
    refusal?: { status: number; code: string; reason: string | null };
    dryRun?: JsonResult<unknown>;
    action?: JsonResult<unknown>;
  } = {}
) {
  TestBed.resetTestingModule();
  const paths: string[] = [];
  const promoteRequests: PromoteRequest[] = [];
  const answer = { refusal: options.refusal };
  const bus = new ChangeBus();
  const actions = new ScreenActions();
  const api = {
    requestJson: async <T,>(path: string, init?: ApiRequestInit): Promise<JsonResult<T>> => {
      if (path.endsWith('/dryrun') || path.endsWith('/action')) {
        promoteRequests.push({ path, body: JSON.parse(String(init?.body ?? '{}')) as Record<string, unknown> });
        return (path.endsWith('/dryrun') ? options.dryRun : options.action) as JsonResult<T>;
      }
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
      { provide: ScreenActions, useValue: actions },
      { provide: OverlayStack, useValue: new OverlayStack() },
      { provide: ChangeBus, useValue: bus },
      { provide: ScreenArrivals, useValue: options.arrivals ?? new ScreenArrivals() },
      {
        provide: ScopeService,
        useValue: {
          loaded: () => true,
          namespace: () => 'HSCUSTOM',
          namespaces: () => (options.namespaces ?? ['HSCUSTOM', 'USER', 'ZED']).map((name) => ({ name })),
          subscribe: () => () => undefined,
        } as unknown as ScopeService,
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
    promoteRequests,
    actions,
    bus,
    stores,
    answer,
    search: async (spec: string, generated = false, target?: string) => {
      if (target !== undefined) {
        const select = host.querySelector('[data-ocu-devtool="target"]') as HTMLSelectElement;
        select.value = target;
        select.dispatchEvent(new Event('change'));
      }
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

describe('System Explorer Compare namespaces', () => {
  it("offers the instance's other namespaces first in the form, defaulting to the first, and no other control for the two screens without one", async () => {
    // Mutation (Rule 19): offer this namespace too in `targetOptions` -> the options assertion goes red.
    const { host } = await mount(DIFF);
    const select = host.querySelector('[data-ocu-devtool="target"]') as HTMLSelectElement;
    expect(host.querySelector('.ocu-criteria-field label')?.textContent?.trim()).toBe(STRINGS.explorerOtherNamespaceLabel);
    expect(Array.from(select.options).map((option) => option.value)).toEqual(['USER', 'ZED']);
    expect(select.value).toBe('USER');
    expect(host.querySelector('[data-ocu-devtool="invite"]')?.textContent?.trim()).toBe(STRINGS.explorerNamespaceDiffInvite);
    expect(host.querySelector('[data-ocu-devtool="no-target"]')).toBeNull();
    const { host: plain } = await mount(HASHES);
    expect(plain.querySelector('[data-ocu-devtool="target"]')).toBeNull();
  });

  it('sends the chosen namespace, and the first one when none was chosen', async () => {
    // Mutation (Rule 19): leave `target` out of `search()` -> both request assertions go red.
    const first = await mount(DIFF);
    await first.search('Demo.*.cls');
    expect(first.paths).toEqual(['/api/ocupilot/screens/explorer.namespacediff/read?maxRows=1000&target=USER&spec=Demo.*.cls&generated=no']);
    const chosen = await mount(DIFF);
    await chosen.search('Demo.*.cls', true, 'ZED');
    expect(chosen.paths).toEqual(['/api/ocupilot/screens/explorer.namespacediff/read?maxRows=1000&target=ZED&spec=Demo.*.cls&generated=yes']);
  });

  it('says there is no other namespace to choose, and sends nothing, on an instance with only this one', async () => {
    // Mutation (Rule 19): drop `this.targetOptions.length === 0` from `noTargetChoice` -> the hint assertion goes red; drop the empty-target refusal from `search()` -> the no-request assertion goes red.
    const { host, paths, search } = await mount(DIFF, { namespaces: ['HSCUSTOM'] });
    expect(host.querySelector('[data-ocu-devtool="no-target"]')?.textContent?.trim()).toBe(STRINGS.explorerTargetReason);
    await search('Demo.*.cls');
    expect(paths).toEqual([]);
  });

  it("runs an agent's arrival with the other namespace it names shown in the form", async () => {
    const arrivals = new ScreenArrivals();
    arrivals.set({ route: DIFF.route, criterion: '', criteria: { target: 'ZED', spec: 'Demo.*.cls' } });
    const { host, paths } = await mount(DIFF, { arrivals });
    expect(paths).toEqual(['/api/ocupilot/screens/explorer.namespacediff/read?maxRows=1000&target=ZED&spec=Demo.*.cls&generated=no']);
    expect((host.querySelector('[data-ocu-devtool="target"]') as HTMLSelectElement).value).toBe('ZED');
  });
});

const DIFF_ROWS = [
  { Document: 'Demo.Changed.cls', Change: STRINGS.explorerChangeDiffers, Hash: 'A'.repeat(64), OtherHash: 'B'.repeat(64), Modified: '2026-11-16 10:00:00', OtherModified: '2026-11-16 10:05:00', Promotable: true },
  { Document: 'Demo.OnlyHere.cls', Change: STRINGS.explorerChangeOnlyHere, Hash: 'C'.repeat(64), OtherHash: '', Modified: '2026-11-16 10:00:00', OtherModified: '', Promotable: true },
  { Document: 'Demo.OnlyThere.cls', Change: STRINGS.explorerChangeOnlyThere, Hash: '', OtherHash: 'D'.repeat(64), Modified: '', OtherModified: '2026-11-16 10:00:00', Promotable: false },
];

const REVIEW_LINES = ['Demo.Changed.cls -- Content differs', 'Demo.OnlyHere.cls -- Only in this namespace', STRINGS.explorerPromoteWarningOne].join('\n');
const DRY_RUN: JsonResult<unknown> = { kind: 'ok', status: 200, body: { rows: [{ field: 'Documents', before: '', after: REVIEW_LINES }], review: { Digest: 'F'.repeat(64) } } };

function applied(output: unknown): JsonResult<unknown> {
  return { kind: 'ok', status: 200, body: { action: 'updated', target: { type: 'class', scope: 'HSCUSTOM', id: 'Demo.Changed.cls,Demo.OnlyHere.cls' }, readBack: null, output } };
}

/** Check the two promotable rows, press Promote and let the dry run answer. */
async function promoteChecked(ctx: Awaited<ReturnType<typeof mount>>): Promise<void> {
  await ctx.search('Demo.*.cls', false, 'ZED');
  ctx.stores.for(DIFF.descriptor, DIFF.refreshRates).setChecked(['Demo.OnlyHere.cls', 'Demo.Changed.cls']);
  expect(ctx.actions.run(DIFF.descriptor, 'promote')).toBe(true);
  await ctx.settle();
}

/** Type `name` into the open typed-name dialog and confirm it. */
async function confirmByName(ctx: Awaited<ReturnType<typeof mount>>, name: string): Promise<void> {
  const field = ctx.host.querySelector('app-typed-name-dialog .ocu-typed-name-field') as HTMLInputElement;
  field.value = name;
  field.dispatchEvent(new Event('input'));
  await ctx.settle();
  (ctx.host.querySelector('app-typed-name-dialog .ocu-button-destructive') as HTMLButtonElement).click();
  await ctx.settle();
}

describe('System Explorer Compare namespaces, Promote', () => {
  it('registers Promote for the screen that declares it, and for no other of the three', async () => {
    // Mutation (Rule 19): register the action whether or not the descriptor declares it -> the Code metrics and Document hashes legs go red.
    for (const [screen, expected] of [[DIFF, true], [METRICS, false], [HASHES, false]] as const) {
      const { actions } = await mount(screen);
      expect(actions.has(screen.descriptor, 'promote')).toBe(expected);
    }
  });

  it('reviews the checked set with the criteria last searched, and states the consequence and the review above the typed name', async () => {
    // Mutation (Rule 19): leave `generated` out of the values `onPromote` sends -> the request assertion goes red.
    const ctx = await mount(DIFF, { rows: DIFF_ROWS, dryRun: DRY_RUN });
    await promoteChecked(ctx);
    expect(ctx.promoteRequests).toEqual([
      {
        path: '/api/ocupilot/screens/explorer.namespacediff/dryrun',
        body: { action: 'promote', id: 'Demo.Changed.cls,Demo.OnlyHere.cls', values: { target: 'ZED', spec: 'Demo.*.cls', generated: 'no' } },
      },
    ]);
    expect(ctx.host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(`${STRINGS.explorerPromoteAction} ZED`);
    expect(Array.from(ctx.host.querySelectorAll('[data-ocu-review] li')).map((item) => item.textContent?.trim())).toEqual(REVIEW_LINES.split('\n'));
    expect(ctx.host.querySelector('.ocu-typed-name-consequence')?.textContent?.trim()).toBe(STRINGS.explorerPromoteConsequence);
    expect((ctx.host.querySelector('app-typed-name-dialog .ocu-button-destructive') as HTMLElement).getAttribute('aria-disabled')).toBe('true');
  });

  it('sends the reviewed hash once the other namespace is typed, then draws the status and the per-document output and unchecks the rows', async () => {
    // Mutation (Rule 19): leave `Reviewed` out of the confirm's values in `ScreenActionHandler.confirmReviewed` -> the second request assertion goes red.
    const output = {
      documents: [
        { Document: 'Demo.Changed.cls', Outcome: STRINGS.explorerPromoteReplaced, Reason: '' },
        { Document: 'Demo.OnlyHere.cls', Outcome: STRINGS.explorerPromoteAdded, Reason: '' },
      ],
      lines: ['Compilation finished'],
      errors: false,
      stopped: false,
    };
    const ctx = await mount(DIFF, { rows: DIFF_ROWS, dryRun: DRY_RUN, action: applied(output) });
    await promoteChecked(ctx);
    await confirmByName(ctx, 'ZED');
    expect(ctx.promoteRequests[1]).toEqual({
      path: '/api/ocupilot/screens/explorer.namespacediff/action',
      body: { action: 'promote', id: 'Demo.Changed.cls,Demo.OnlyHere.cls', values: { target: 'ZED', spec: 'Demo.*.cls', generated: 'no', Reviewed: 'F'.repeat(64) } },
    });
    expect(ctx.host.querySelector('[data-explorer-write="status"]')?.textContent?.trim()).toBe(STRINGS.explorerPromoteDone.replace('<n>', '2'));
    expect(ctx.host.querySelector('[data-explorer-write="output"]')?.textContent).toBe(['Replaced: Demo.Changed.cls', 'Added: Demo.OnlyHere.cls', 'Compilation finished'].join('\n'));
    expect(ctx.stores.for(DIFF.descriptor, DIFF.refreshRates).checked().size).toBe(0);
  });

  it("says where a promote stopped, and that the compile's errors were reported", async () => {
    // Mutation (Rule 19): drop the stopped branch of `promoteStatus` -> the stopped leg goes red.
    const stopped = {
      documents: [
        { Document: 'Demo.Changed.cls', Outcome: STRINGS.explorerPromoteReplaced, Reason: '' },
        { Document: 'Demo.OnlyHere.cls', Outcome: STRINGS.explorerPromoteFailed, Reason: 'The document is held by another process.' },
      ],
      lines: [],
      errors: false,
      stopped: true,
    };
    const first = await mount(DIFF, { rows: DIFF_ROWS, dryRun: DRY_RUN, action: applied(stopped) });
    await promoteChecked(first);
    await confirmByName(first, 'ZED');
    expect(first.host.querySelector('[data-explorer-write="status"]')?.textContent?.trim()).toBe(STRINGS.explorerPromoteStopped.replace('<document>', 'Demo.OnlyHere.cls'));
    expect(first.host.querySelector('[data-explorer-write="output"]')?.textContent).toBe('Replaced: Demo.Changed.cls\nFailed: Demo.OnlyHere.cls -- The document is held by another process.');
    const errored = await mount(DIFF, { rows: DIFF_ROWS, dryRun: DRY_RUN, action: applied({ documents: [{ Document: 'Demo.Changed.cls', Outcome: STRINGS.explorerPromoteReplaced, Reason: '' }], lines: ['ERROR 5001'], errors: true, stopped: false }) });
    await promoteChecked(errored);
    await confirmByName(errored, 'ZED');
    expect(errored.host.querySelector('[data-explorer-write="status"]')?.textContent?.trim()).toBe(STRINGS.explorerPromoteDoneErrors.replace('<n>', '1'));
  });

  it("shows the instance's reason when the review is refused, and opens no dialog", async () => {
    const reason = STRINGS.explorerPromoteSystemReason;
    const ctx = await mount(DIFF, { rows: DIFF_ROWS, dryRun: { kind: 'error', status: 400, code: 'EXPLORER.PROMOTE.SYSTEM', reason, detail: null } });
    await promoteChecked(ctx);
    expect(ctx.host.querySelector('[data-explorer-write="status"]')?.textContent?.trim()).toBe(reason);
    expect(ctx.host.querySelector('app-typed-name-dialog')).toBeNull();
    expect(ctx.promoteRequests).toHaveLength(1);
  });

  it("draws the instance's reason for a document only the other namespace holds, and no checkable box", async () => {
    const ctx = await mount(DIFF, { rows: DIFF_ROWS });
    await ctx.search('Demo.*.cls', false, 'ZED');
    const rows = Array.from(ctx.host.querySelectorAll('.ocu-data-table-row, [role="row"]')).filter((row) => row.textContent?.includes('Demo.OnlyThere.cls'));
    const box = rows[0]?.querySelector('.ocu-data-table-check') as HTMLElement | null;
    expect(box?.getAttribute('aria-disabled')).toBe('true');
    expect(box?.getAttribute('aria-description')).toBe(STRINGS.explorerPromoteIneligible);
  });
});
