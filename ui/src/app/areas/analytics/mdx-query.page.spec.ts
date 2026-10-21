import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { runPath } from '../../core/background-run';
import { NavigationService } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { ScopeService } from '../../core/scope';
import { screenReadPath } from '../../core/screen-read';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS, type ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { ARCHETYPE_PAGES, DESCRIPTOR_PAGES, resolveScreenPage } from '../../shell/screen-outlet';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { MDX_BACKGROUND_SCHEDULE, MdxQueryPage } from './mdx-query.page';
import { MDX_BACKGROUND_PATH, MDX_CUBES_DESCRIPTOR, MDX_CUBES_MAX_ROWS } from './mdx-query.store';

/**
 * MDX query over stubs of what the instance supplies -- the Cubes list's declared read and the MDX
 * background run's start, poll and cancel routes (Story 20.33). The real store, the real warning
 * dialog, the real result grid and the real template run, so the assertions are about rendered DOM and
 * the requests sent: Run's body, the grid of row labels and drill buttons, a cell's drill body, the
 * picker filling only an empty statement, the confirmation drawn only on the instance's `confirm` and
 * Proceed re-sending exactly the statement it was asked for with the confirmation (and no first start
 * ever carrying it), a drill after a confirmed run carrying it, refusals as an alert, the vendor's
 * error as text, Cancel, and the polling stopped when the page goes.
 */

const SCREEN = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.AnalyticsMdxQuery') as ScreenDeclaration;

const CUBES_SCREEN = SCREENS.find((screen) => screen.descriptor === MDX_CUBES_DESCRIPTOR) as ScreenDeclaration;

const CUBES_PATH = screenReadPath(CUBES_SCREEN, MDX_CUBES_MAX_ROWS);

/** A run id the stubs answer with. */
const RUN_ID = '0123456789abcdef0123456789abcdef';

const POLL_PATH = runPath(MDX_BACKGROUND_PATH, RUN_ID);

const CANCEL_PATH = runPath(MDX_BACKGROUND_PATH, RUN_ID, true);

const STATEMENT = 'SELECT {[Measures].[Visits],[Measures].[Cost]} ON 0, [Region].[H1].[Name].Members ON 1 FROM [OcuPilotProbeVisits]';

const CELLS = {
  outcome: 'cells',
  cube: 'OcuPilotProbeVisits',
  columns: ['Visits', 'Cost'],
  rows: [
    { label: 'North', cells: ['3', '9'] },
    { label: 'South', cells: ['<b>5</b>', '15'] },
  ],
  rowsAvailable: 2,
  columnsAvailable: 2,
  truncated: false,
  seconds: 1,
};

const LISTING = { outcome: 'rows', columns: ['Id', 'Region'], rows: [['1', 'North'], ['2', 'North']], truncated: false };

interface Post {
  readonly path: string;
  readonly method: string;
  readonly body: Record<string, unknown>;
  readonly scope: string | null | undefined;
}

type Answer = { readonly ok: unknown } | { readonly status: number; readonly code: string; readonly reason: string; readonly detail?: Record<string, unknown> };

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

interface Mounted {
  readonly fixture: ComponentFixture<MdxQueryPage>;
  readonly host: HTMLElement;
  readonly stores: ScreenStores;
  readonly overlays: OverlayStack;
  /** Every request the page sent, in order. */
  readonly posts: Post[];
  /** What a request to one path answers, first queued first. */
  readonly routes: Map<string, Answer[]>;
  /** The polls the page scheduled and has not yet been sent. */
  readonly scheduled: (() => void)[];
  /** The namespace the page is scoped to, and a change of it. */
  readonly scope: { current: string; change: (to: string) => void };
}

async function mount(cubes: readonly string[] = ['OcuPilotProbeVisits', 'Zeta]Cube']): Promise<Mounted> {
  TestBed.resetTestingModule();
  const stores = new ScreenStores({ account: stubAccountPreferences() });
  const overlays = new OverlayStack();
  const listeners = new Set<() => void>();
  const scope = {
    current: 'USER',
    change: (to: string) => {
      scope.current = to;
      for (const listener of [...listeners]) listener();
    },
  };
  const mounted = {
    posts: [] as Post[],
    routes: new Map<string, Answer[]>(),
    scheduled: [] as (() => void)[],
    scope,
    overlays,
    stores,
  };
  const fixedCubes: Answer = { ok: { fields: ['Name'], rows: cubes.map((Name) => ({ Name })), truncated: false, banner: '', bannerRequires: '' } };
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      mounted.posts.push({ path, method: init.method ?? 'GET', body: JSON.parse(init.body ?? '{}') as Record<string, unknown>, scope: init.scope });
      const answer = mounted.routes.get(path)?.shift() ?? (path === CUBES_PATH ? fixedCubes : undefined);
      if (answer === undefined) throw new Error(`no answer queued for ${path}`);
      if ('ok' in answer) return { kind: 'ok', status: 200, body: answer.ok as T };
      return { kind: 'error', status: answer.status, code: answer.code, reason: answer.reason, detail: answer.detail ?? null };
    },
  };
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: NavigationService, useValue: { screenForUrl: () => SCREEN } as unknown as NavigationService },
      { provide: ScreenStores, useValue: stores },
      { provide: OverlayStack, useValue: overlays },
      {
        provide: ScopeService,
        useValue: {
          loaded: () => true,
          namespace: () => scope.current,
          subscribe: (listener: () => void) => {
            listeners.add(listener);
            return () => listeners.delete(listener);
          },
        } as unknown as ScopeService,
      },
      { provide: MDX_BACKGROUND_SCHEDULE, useValue: (run: () => void) => mounted.scheduled.push(run) },
    ],
  });
  await TestBed.inject(Router).navigateByUrl(`/${SCREEN.route}?ns=USER`);
  const fixture = TestBed.createComponent(MdxQueryPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return Object.assign(mounted, { fixture, host: fixture.nativeElement as HTMLElement }) as Mounted;
}

function el<T extends HTMLElement>(host: ParentNode, slot: string): T {
  return host.querySelector(`[data-ocu-mdx="${slot}"]`) as T;
}

function all(host: ParentNode, slot: string): HTMLElement[] {
  return [...host.querySelectorAll<HTMLElement>(`[data-ocu-mdx="${slot}"]`)];
}

async function type(mounted: Mounted, text: string): Promise<void> {
  const area = el<HTMLTextAreaElement>(mounted.host, 'statement');
  area.value = text;
  area.dispatchEvent(new Event('input'));
  await settle(mounted.fixture);
}

async function run(mounted: Mounted): Promise<void> {
  el<HTMLButtonElement>(mounted.host, 'run').click();
  await settle(mounted.fixture);
}

function status(host: HTMLElement): string {
  return el(host, 'status').textContent?.trim() ?? '';
}

function dialog(): HTMLElement | null {
  return document.body.querySelector('[role="dialog"]');
}

/** The requests sent to the MDX run's routes, without the cube read. */
function sent(mounted: Mounted): Post[] {
  return mounted.posts.filter((post) => post.path !== CUBES_PATH);
}

/** The starts the page sent: the POSTs to the start route. */
function starts(mounted: Mounted): Post[] {
  return mounted.posts.filter((post) => post.path === MDX_BACKGROUND_PATH);
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
});

/** Queue `answers` for requests to `path`. */
function route(mounted: Mounted, path: string, ...answers: Answer[]): void {
  mounted.routes.set(path, [...(mounted.routes.get(path) ?? []), ...answers]);
}

/** A run's poll answer. */
function view(state: string, extra: Record<string, unknown> = {}): Answer {
  return { ok: { id: RUN_ID, status: state, startedAt: '2026-10-21T00:00:00Z', endedAt: state === 'running' ? null : '2026-10-21T00:00:05Z', cancelRequested: false, ...extra } };
}

/** Send the polls the page scheduled, and let their answers land. */
async function flush(mounted: Mounted): Promise<void> {
  for (const send of mounted.scheduled.splice(0)) send();
  await settle(mounted.fixture);
}

/** Write `STATEMENT`, run it, and let the run end with `result`. */
async function runToEnd(mounted: Mounted, result: unknown, text = STATEMENT): Promise<void> {
  route(mounted, MDX_BACKGROUND_PATH, { ok: { id: RUN_ID, status: 'running' } });
  route(mounted, POLL_PATH, view('ended', { result }));
  await type(mounted, text);
  await run(mounted);
}

function confirmAnswer(constructs: readonly string[]): Answer {
  return { ok: { outcome: 'confirm', constructs, consequence: STRINGS.analyticsMdxConfirmConsequence } };
}

describe('MDX query', () => {
  it("is the screen's own page, and the empty page invites a statement with Run unavailable", async () => {
    const loader = resolveScreenPage(DESCRIPTOR_PAGES, ARCHETYPE_PAGES, SCREEN.descriptor, SCREEN.archetype);
    expect(await loader?.()).toBe(MdxQueryPage);
    const { host } = await mount();
    expect(status(host)).toBe(STRINGS.analyticsMdxEmpty);
    const area = el<HTMLTextAreaElement>(host, 'statement');
    expect(area.classList.contains('ocu-source-text')).toBe(true);
    expect(area.getAttribute('spellcheck')).toBe('false');
    expect(host.querySelector(`label[for="${area.id}"]`)?.textContent?.trim()).toBe(STRINGS.explorerSqlColumnStatement);
    expect(el(host, 'run').getAttribute('aria-disabled')).toBe('true');
    expect(el(host, 'cancel')).toBeNull();
    expect(el(host, 'grid')).toBeNull();
    expect(dialog()).toBeNull();
  });

  it('offers the cubes the Cubes list reads, in scope, and a pick fills the statement with the cube only while it is empty', async () => {
    const mounted = await mount();
    expect(mounted.posts[0]).toEqual({ path: CUBES_PATH, method: 'GET', body: {}, scope: 'USER' });
    const select = el<HTMLSelectElement>(mounted.host, 'cube');
    expect(mounted.host.querySelector(`label[for="${select.id}"]`)?.textContent?.trim()).toBe(STRINGS.analyticsMdxCubeLabel);
    expect([...select.options].map((option) => option.value)).toEqual(['', 'OcuPilotProbeVisits', 'Zeta]Cube']);
    const pick = async (name: string): Promise<void> => {
      select.value = name;
      select.dispatchEvent(new Event('change'));
      await settle(mounted.fixture);
    };
    await pick('OcuPilotProbeVisits');
    expect(el<HTMLTextAreaElement>(mounted.host, 'statement').value).toBe('SELECT FROM [OcuPilotProbeVisits]');
    expect(el(mounted.host, 'run').getAttribute('aria-disabled')).toBe('false');
    await pick('Zeta]Cube');
    expect(el<HTMLTextAreaElement>(mounted.host, 'statement').value).toBe('SELECT FROM [OcuPilotProbeVisits]');
    await type(mounted, '');
    await pick('Zeta]Cube');
    expect(el<HTMLTextAreaElement>(mounted.host, 'statement').value).toBe('SELECT FROM [Zeta]]Cube]');
  });

  it('draws no picker when the Cubes list answers nothing, and the page still runs', async () => {
    const mounted = await mount([]);
    expect(el(mounted.host, 'cube')).toBeNull();
    await type(mounted, STATEMENT);
    expect(el(mounted.host, 'run').getAttribute('aria-disabled')).toBe('false');
  });

  it("runs a statement: its body is the statement alone, posted in scope, and the cells draw a grid of row labels, headers and drill buttons", async () => {
    const mounted = await mount();
    await runToEnd(mounted, CELLS);
    expect(sent(mounted)[0]).toEqual({ path: MDX_BACKGROUND_PATH, method: 'POST', body: { statement: STATEMENT }, scope: 'USER' });
    expect(Object.keys(sent(mounted)[0].body)).toEqual(['statement']);
    const grid = el(mounted.host, 'grid');
    expect(grid.getAttribute('role')).toBe('table');
    expect(grid.getAttribute('aria-label')).toBe(STRINGS.analyticsMdxQueryLabel);
    expect([...grid.querySelectorAll('[role="columnheader"]')].map((cell) => cell.textContent?.trim())).toEqual([STRINGS.analyticsMdxRowHeader, 'Visits', 'Cost']);
    expect(all(grid, 'row-header').map((cell) => cell.textContent)).toEqual(['North', 'South']);
    expect(all(grid, 'row-header').every((cell) => cell.closest('[role="rowheader"]') !== null)).toBe(true);
    const buttons = all(grid, 'drill-cell');
    expect(buttons.map((button) => button.textContent?.trim())).toEqual(['3', '9', '<b>5</b>', '15']);
    expect(buttons.every((button) => button.tagName === 'BUTTON' && button.getAttribute('type') === 'button')).toBe(true);
    // Mutation (Rule 19): drop the value from `drillLabel` -> the names read only the drill-through and this goes red.
    expect(buttons.map((button) => button.getAttribute('aria-label'))).toEqual([
      '3, Drill through North, Visits',
      '9, Drill through North, Cost',
      '<b>5</b>, Drill through South, Visits',
      '15, Drill through South, Cost',
    ]);
    expect(grid.querySelector('b')).toBeNull();
    expect(status(mounted.host)).toBe('Rows: 2 of 2. Columns: 2 of 2.');
    expect(dialog()).toBeNull();
    expect(mounted.stores.for(SCREEN.descriptor, SCREEN.refreshRates).data()).toEqual([]);
  });

  it('draws no row-header column when no row carries a label, and says what was cut', async () => {
    const mounted = await mount();
    await runToEnd(mounted, {
      ...CELLS,
      columns: ['Visits'],
      rows: [{ label: '', cells: ['42'] }],
      rowsAvailable: 5000,
      truncated: true,
    });
    const grid = el(mounted.host, 'grid');
    expect([...grid.querySelectorAll('[role="columnheader"]')].map((cell) => cell.textContent?.trim())).toEqual(['Visits']);
    expect(all(grid, 'row-header')).toEqual([]);
    expect(status(mounted.host)).toBe(`Rows: 1 of 5000. Columns: 1 of 2. ${STRINGS.analyticsMdxCut}`);
  });

  it('polls a running run until it ends: Cancel is drawn while it runs, Run is unavailable, and the status line reads running', async () => {
    const mounted = await mount();
    route(mounted, MDX_BACKGROUND_PATH, { ok: { id: RUN_ID, status: 'running' } });
    route(mounted, POLL_PATH, view('running'));
    await type(mounted, STATEMENT);
    await run(mounted);
    expect(status(mounted.host)).toBe(STRINGS.explorerSqlBackgroundRunning);
    expect(el(mounted.host, 'cancel').textContent?.trim()).toBe(STRINGS.actionCancel);
    expect(el(mounted.host, 'run').getAttribute('aria-disabled')).toBe('true');
    expect(mounted.scheduled.length).toBe(1);
    const before = sent(mounted).length;
    await run(mounted);
    expect(sent(mounted).length).toBe(before);
    route(mounted, POLL_PATH, view('ended', { result: CELLS }));
    await flush(mounted);
    expect(el(mounted.host, 'cancel')).toBeNull();
    expect(el(mounted.host, 'run').getAttribute('aria-disabled')).toBe('false');
    expect(all(mounted.host, 'drill-cell').length).toBe(4);
  });

  it('cancels a run: Cancel posts the cancel route, and the status reads Canceled with no grid', async () => {
    const mounted = await mount();
    route(mounted, MDX_BACKGROUND_PATH, { ok: { id: RUN_ID, status: 'running' } });
    route(mounted, POLL_PATH, view('running'));
    await type(mounted, STATEMENT);
    await run(mounted);
    route(mounted, CANCEL_PATH, view('running', { cancelRequested: true }));
    el<HTMLButtonElement>(mounted.host, 'cancel').click();
    await settle(mounted.fixture);
    expect(mounted.posts.at(-1)).toEqual({ path: CANCEL_PATH, method: 'POST', body: {}, scope: 'USER' });
    route(mounted, POLL_PATH, view('canceled', { cancelRequested: true }));
    await flush(mounted);
    expect(status(mounted.host)).toBe(STRINGS.explorerSqlBackgroundCanceled);
    expect(el(mounted.host, 'cancel')).toBeNull();
    expect(el(mounted.host, 'grid')).toBeNull();
    expect(el(mounted.host, 'run').getAttribute('aria-disabled')).toBe('false');
  });

  it("starts a drill from a value cell: the run's statement and the cell's 1-based row and column, with no confirmation, while the cells stay shown", async () => {
    const mounted = await mount();
    await runToEnd(mounted, CELLS);
    route(mounted, MDX_BACKGROUND_PATH, { ok: { id: RUN_ID, status: 'running' } });
    route(mounted, POLL_PATH, view('running'));
    // The textarea changes after the run: the drill still names the statement that produced the grid.
    await type(mounted, 'SELECT FROM [Other]');
    all(mounted.host, 'drill-cell')[2].click();
    await settle(mounted.fixture);
    const drill = starts(mounted)[1];
    expect(drill).toEqual({ path: MDX_BACKGROUND_PATH, method: 'POST', body: { statement: STATEMENT, drill: { row: 2, column: 1 } }, scope: 'USER' });
    expect('confirmed' in drill.body).toBe(false);
    expect(status(mounted.host)).toBe(STRINGS.explorerSqlBackgroundRunning);
    expect(all(mounted.host, 'drill-cell').length).toBe(4);
    expect(all(mounted.host, 'row-header').map((cell) => cell.textContent)).toEqual(['North', 'South']);
    expect(all(mounted.host, 'drill-cell')[0].getAttribute('aria-disabled')).toBe('true');
    const sentBefore = starts(mounted).length;
    all(mounted.host, 'drill-cell')[0].click();
    await settle(mounted.fixture);
    expect(starts(mounted).length).toBe(sentBefore);
  });

  it('draws the listing a drill answered under the Drill-through heading, the cells still shown, and a second drill replaces it', async () => {
    const mounted = await mount();
    await runToEnd(mounted, CELLS);
    route(mounted, MDX_BACKGROUND_PATH, { ok: { id: RUN_ID, status: 'running' } });
    route(mounted, POLL_PATH, view('ended', { result: LISTING }));
    all(mounted.host, 'drill-cell')[1].click();
    await settle(mounted.fixture);
    expect(starts(mounted)[1].body).toEqual({ statement: STATEMENT, drill: { row: 1, column: 2 } });
    const listing = el(mounted.host, 'listing');
    expect(listing.querySelector('h2')?.textContent?.trim()).toBe(STRINGS.analyticsMdxDrillHeading);
    expect(listing.querySelector('[role="table"]')?.getAttribute('aria-label')).toBe(STRINGS.analyticsMdxDrillHeading);
    expect([...listing.querySelectorAll('[role="columnheader"]')].map((cell) => cell.textContent?.trim())).toEqual(['Id', 'Region']);
    expect([...listing.querySelectorAll('[data-ocu-sql="listing-cell"]')].map((cell) => cell.textContent)).toEqual(['1', 'North', '2', 'North']);
    expect(el(listing, 'listing-status').textContent?.trim()).toBe(STRINGS.tableRowCount.replace('<n>', '2'));
    expect(all(mounted.host, 'drill-cell').length).toBe(4);
    expect(status(mounted.host)).toBe('Rows: 2 of 2. Columns: 2 of 2.');
    route(mounted, MDX_BACKGROUND_PATH, { ok: { id: RUN_ID, status: 'running' } });
    route(mounted, POLL_PATH, view('running'));
    all(mounted.host, 'drill-cell')[3].click();
    await settle(mounted.fixture);
    expect(starts(mounted)[2].body).toEqual({ statement: STATEMENT, drill: { row: 2, column: 2 } });
    expect(el(mounted.host, 'listing')).toBeNull();
  });

  it("shows a typed DRILLTHROUGH's listing with its own count in the status line and no grid", async () => {
    const mounted = await mount();
    await runToEnd(mounted, { ...LISTING, truncated: true }, 'DRILLTHROUGH SELECT FROM [OcuPilotProbeVisits]');
    expect(el(mounted.host, 'grid')).toBeNull();
    expect(el(mounted.host, 'listing').querySelector('h2')?.textContent?.trim()).toBe(STRINGS.analyticsMdxDrillHeading);
    expect(status(mounted.host)).toBe(STRINGS.explorerSqlRowsCut.replace('<n>', '2'));
    expect(el(mounted.host, 'listing-status')).toBeNull();
  });

  it("shows the vendor's error as text under its own line, from an immediate answer and from an ended run; a drill's error leaves the grid", async () => {
    const mounted = await mount();
    route(mounted, MDX_BACKGROUND_PATH, { ok: { outcome: 'error', message: ' Unknown term at start of query: <i>SELEKT</i>' } });
    await type(mounted, 'SELEKT FROM [OcuPilotProbeVisits]');
    await run(mounted);
    expect(status(mounted.host)).toBe(STRINGS.analyticsMdxErrorLine);
    expect(el(mounted.host, 'error').tagName).toBe('PRE');
    expect(el(mounted.host, 'error').textContent).toBe(' Unknown term at start of query: <i>SELEKT</i>');
    expect(el(mounted.host, 'error').querySelector('i')).toBeNull();
    expect(mounted.scheduled.length).toBe(0);
    expect(starts(mounted).length).toBe(1);
    await runToEnd(mounted, CELLS);
    expect(el(mounted.host, 'error')).toBeNull();
    expect(all(mounted.host, 'drill-cell').length).toBe(4);
    route(mounted, MDX_BACKGROUND_PATH, { ok: { id: RUN_ID, status: 'running' } });
    route(mounted, POLL_PATH, view('ended', { result: { outcome: 'error', message: ' SQLCODE -99 not privileged' } }));
    all(mounted.host, 'drill-cell')[0].click();
    await settle(mounted.fixture);
    expect(el(mounted.host, 'error').textContent).toBe(' SQLCODE -99 not privileged');
    expect(status(mounted.host)).toBe(STRINGS.analyticsMdxErrorLine);
    expect(all(mounted.host, 'drill-cell').length).toBe(4);
  });

  it('reads a stopped run as its bound in seconds, in the singular at one', async () => {
    const mounted = await mount();
    await runToEnd(mounted, { outcome: 'stopped', seconds: 120 });
    expect(status(mounted.host)).toBe(STRINGS.explorerSqlStopped.replace('<s>', '120'));
    expect(el(mounted.host, 'grid')).toBeNull();
    await runToEnd(mounted, { outcome: 'stopped', seconds: 1 });
    expect(status(mounted.host)).toBe(STRINGS.explorerSqlStoppedOne);
  });

  it("shows a start's refusal as an alert in the instance's sentence, a missing pair named, and a busy owner's live run attached", async () => {
    const mounted = await mount();
    route(mounted, MDX_BACKGROUND_PATH, { status: 422, code: 'ANALYTICS.MDX.KIND', reason: 'a reason the code overrides' });
    await type(mounted, 'CREATE MEMBER [OcuPilotProbeVisits].[Measures].[X] AS \'1\'');
    await run(mounted);
    expect(el(mounted.host, 'banner').getAttribute('role')).toBe('alert');
    expect(el(mounted.host, 'banner').textContent?.trim()).toBe(STRINGS.analyticsRefusalMdxKind);
    expect(mounted.scheduled.length).toBe(0);
    route(mounted, MDX_BACKGROUND_PATH, { status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'denied', detail: { failedPair: '%DB_USER:WRITE' } });
    await run(mounted);
    expect(el(mounted.host, 'banner').textContent?.trim()).toBe(STRINGS.privilegeRequiresResource.replace('<resource>', '%DB_USER:WRITE'));
    route(mounted, MDX_BACKGROUND_PATH, { status: 409, code: 'ANALYTICS.NAMESPACE', reason: 'unused' });
    await run(mounted);
    expect(el(mounted.host, 'banner').textContent?.trim()).toBe(STRINGS.analyticsRefusalNamespace);
    route(mounted, MDX_BACKGROUND_PATH, { status: 409, code: 'ANALYTICS.MDX.BUSY', reason: 'unused', detail: { runId: RUN_ID } });
    route(mounted, POLL_PATH, view('running'));
    await run(mounted);
    expect(el(mounted.host, 'banner').textContent?.trim()).toBe(STRINGS.analyticsRefusalMdxBusy);
    expect(mounted.posts.at(-1)?.path).toBe(POLL_PATH);
    expect(status(mounted.host)).toBe(STRINGS.explorerSqlBackgroundRunning);
    expect(el(mounted.host, 'cancel')).not.toBeNull();
  });

  it("shows a failed run's refusal in the instance's sentence, and a run its poll no longer finds ends the page's busy state", async () => {
    const mounted = await mount();
    route(mounted, MDX_BACKGROUND_PATH, { ok: { id: RUN_ID, status: 'running' } });
    route(mounted, POLL_PATH, view('failed', { refusal: { code: 'ANALYTICS.MDX.LOST', reason: 'overridden by the code' } }));
    await type(mounted, STATEMENT);
    await run(mounted);
    expect(el(mounted.host, 'banner').textContent?.trim()).toBe(STRINGS.analyticsRefusalMdxLost);
    expect(status(mounted.host)).toBe('');
    route(mounted, MDX_BACKGROUND_PATH, { ok: { id: RUN_ID, status: 'running' } });
    route(mounted, POLL_PATH, { status: 404, code: 'ANALYTICS.MDX.NOTFOUND', reason: STRINGS.analyticsRefusalMdxNotFound });
    await run(mounted);
    expect(el(mounted.host, 'banner')).toBeNull();
    expect(el(mounted.host, 'run').getAttribute('aria-disabled')).toBe('false');
  });

  it('draws no dialog for a plain run, and the first start never carries a confirmation', async () => {
    // Mutation (Rule 19): send `confirmed: true` on the first start -> the key check goes red.
    const mounted = await mount();
    await runToEnd(mounted, CELLS);
    expect(dialog()).toBeNull();
    expect(mounted.host.querySelector('app-warning-dialog')).toBeNull();
    expect(starts(mounted).length).toBe(1);
    expect('confirmed' in starts(mounted)[0].body).toBe(false);
  });

  it('asks first on a confirm answer: the dialog names the consequence, nothing starts, and Cancel sends nothing more', async () => {
    const mounted = await mount();
    route(mounted, MDX_BACKGROUND_PATH, confirmAnswer(['%SEARCH']));
    await type(mounted, STATEMENT);
    await run(mounted);
    const open = dialog();
    expect(open?.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.analyticsMdxConfirmTitle);
    expect(open?.querySelector('.ocu-warning-consequence')?.textContent?.trim()).toBe(STRINGS.analyticsMdxConfirmConsequence);
    expect(open?.querySelector('.ocu-button-primary')?.textContent?.trim()).toBe(STRINGS.actionProceed);
    // Mutation (Rule 19): send `confirmed: true` on the first start -> the exact-body check goes red.
    expect(starts(mounted).map((post) => post.body)).toEqual([{ statement: STATEMENT }]);
    expect(sent(mounted).length).toBe(1);
    expect(mounted.scheduled.length).toBe(0);
    expect(el(mounted.host, 'grid')).toBeNull();
    (open?.querySelector('.ocu-button-secondary') as HTMLButtonElement).click();
    await settle(mounted.fixture);
    expect(dialog()).toBeNull();
    expect(sent(mounted).length).toBe(1);
    expect(mounted.scheduled.length).toBe(0);
  });

  it('closes the confirmation on Escape and on the scrim, and sends nothing', async () => {
    const mounted = await mount();
    route(mounted, MDX_BACKGROUND_PATH, confirmAnswer(['RETURN']), confirmAnswer(['RETURN']));
    await type(mounted, STATEMENT);
    await run(mounted);
    expect(dialog()).not.toBeNull();
    expect(mounted.overlays.closeTop()).toBe(true);
    await settle(mounted.fixture);
    expect(dialog()).toBeNull();
    await run(mounted);
    expect(dialog()).not.toBeNull();
    (document.body.querySelector('.ocu-dialog-scrim') as HTMLElement).dispatchEvent(new MouseEvent('mousedown', { bubbles: true }));
    await settle(mounted.fixture);
    expect(dialog()).toBeNull();
    expect(sent(mounted).length).toBe(2);
  });

  it('re-sends exactly the asked statement with the confirmation on Proceed, even when the box changed meanwhile, and the run then ends as any run does', async () => {
    // Mutation (Rule 19): send the textarea's text instead of the held statement -> the body check goes red.
    const mounted = await mount();
    route(mounted, MDX_BACKGROUND_PATH, confirmAnswer(['%SEARCH']));
    await type(mounted, STATEMENT);
    await run(mounted);
    await type(mounted, 'SELECT FROM [Changed]');
    route(mounted, MDX_BACKGROUND_PATH, { ok: { id: RUN_ID, status: 'running' } });
    route(mounted, POLL_PATH, view('ended', { result: CELLS }));
    (dialog()?.querySelector('.ocu-button-primary') as HTMLButtonElement).click();
    await settle(mounted.fixture);
    expect(starts(mounted).map((post) => post.body)).toEqual([{ statement: STATEMENT }, { statement: STATEMENT, confirmed: true }]);
    expect(dialog()).toBeNull();
    expect(all(mounted.host, 'drill-cell').length).toBe(4);
    expect(el<HTMLTextAreaElement>(mounted.host, 'statement').value).toBe('SELECT FROM [Changed]');
  });

  it('draws the same dialog for a confirm that names no construct, a statement the instance could not read', async () => {
    // Mutation (Rule 19): `mdxConfirmOf` answers null for an empty list -> no dialog and this goes red.
    const mounted = await mount();
    route(mounted, MDX_BACKGROUND_PATH, confirmAnswer([]));
    await type(mounted, 'SELECT FROM [OcuPilotProbeVisits');
    await run(mounted);
    const open = dialog();
    expect(open?.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.analyticsMdxConfirmTitle);
    expect(open?.querySelector('.ocu-warning-consequence')?.textContent?.trim()).toBe(STRINGS.analyticsMdxConfirmConsequence);
    route(mounted, MDX_BACKGROUND_PATH, { ok: { outcome: 'error', message: 'Unexpected end of statement' } });
    (open?.querySelector('.ocu-button-primary') as HTMLButtonElement).click();
    await settle(mounted.fixture);
    expect(starts(mounted).map((post) => post.body)).toEqual([{ statement: 'SELECT FROM [OcuPilotProbeVisits' }, { statement: 'SELECT FROM [OcuPilotProbeVisits', confirmed: true }]);
    expect(el(mounted.host, 'error').textContent).toBe('Unexpected end of statement');
  });

  it("carries a run's confirmation into each drill of its grid, and a drill after an unconfirmed run carries none", async () => {
    const mounted = await mount();
    route(mounted, MDX_BACKGROUND_PATH, confirmAnswer(['%SEARCH']));
    await type(mounted, STATEMENT);
    await run(mounted);
    route(mounted, MDX_BACKGROUND_PATH, { ok: { id: RUN_ID, status: 'running' } });
    route(mounted, POLL_PATH, view('ended', { result: CELLS }));
    (dialog()?.querySelector('.ocu-button-primary') as HTMLButtonElement).click();
    await settle(mounted.fixture);
    route(mounted, MDX_BACKGROUND_PATH, { ok: { id: RUN_ID, status: 'running' } });
    route(mounted, POLL_PATH, view('ended', { result: LISTING }));
    all(mounted.host, 'drill-cell')[3].click();
    await settle(mounted.fixture);
    expect(starts(mounted)[2].body).toEqual({ statement: STATEMENT, drill: { row: 2, column: 2 }, confirmed: true });
    expect(dialog()).toBeNull();
    expect(el(mounted.host, 'listing')).not.toBeNull();
    // A new, plain run of another statement is its own: its drill carries no confirmation.
    await runToEnd(mounted, CELLS, 'SELECT FROM [Plain]');
    route(mounted, MDX_BACKGROUND_PATH, { ok: { id: RUN_ID, status: 'running' } });
    route(mounted, POLL_PATH, view('running'));
    all(mounted.host, 'drill-cell')[0].click();
    await settle(mounted.fixture);
    expect(starts(mounted)[4].body).toEqual({ statement: 'SELECT FROM [Plain]', drill: { row: 1, column: 1 } });
  });

  it('drops a confirmation when the page goes, and the page that returns holds none and sends nothing', async () => {
    const mounted = await mount();
    route(mounted, MDX_BACKGROUND_PATH, confirmAnswer(['%SEARCH']));
    await type(mounted, STATEMENT);
    await run(mounted);
    expect(dialog()).not.toBeNull();
    mounted.fixture.destroy();
    const again = TestBed.createComponent(MdxQueryPage);
    document.body.appendChild(again.nativeElement);
    planted.push(again.nativeElement);
    await settle(again);
    expect(dialog()).toBeNull();
    expect(el<HTMLTextAreaElement>(again.nativeElement, 'statement').value).toBe(STATEMENT);
    expect(starts(mounted).length).toBe(1);
  });

  it('drops a confirmation that answers after the page went', async () => {
    const mounted = await mount();
    let answerStart: (() => void) | null = null;
    const api = TestBed.inject(ApiService) as unknown as { requestJson: (path: string, init?: ApiRequestInit) => Promise<JsonResult<unknown>> };
    const answer = api.requestJson;
    api.requestJson = async (path, init) => {
      if (path === MDX_BACKGROUND_PATH) await new Promise<void>((resolve) => (answerStart = resolve));
      return answer(path, init);
    };
    route(mounted, MDX_BACKGROUND_PATH, confirmAnswer(['%SEARCH']));
    await type(mounted, STATEMENT);
    await run(mounted);
    mounted.fixture.destroy();
    (answerStart as (() => void) | null)?.();
    await settle(mounted.fixture);
    const again = TestBed.createComponent(MdxQueryPage);
    document.body.appendChild(again.nativeElement);
    planted.push(again.nativeElement);
    await settle(again);
    expect(dialog()).toBeNull();
  });

  it('drops a confirmation when the namespace changes, and the next Run asks in the new namespace', async () => {
    const mounted = await mount();
    route(mounted, MDX_BACKGROUND_PATH, confirmAnswer(['%SEARCH']), confirmAnswer(['%SEARCH']));
    await type(mounted, STATEMENT);
    await run(mounted);
    expect(dialog()).not.toBeNull();
    mounted.scope.change('HSCUSTOM');
    await settle(mounted.fixture);
    expect(dialog()).toBeNull();
    expect(starts(mounted).length).toBe(1);
    expect(mounted.posts.filter((post) => post.path === CUBES_PATH).map((post) => post.scope)).toEqual(['USER', 'HSCUSTOM']);
    await run(mounted);
    expect(dialog()).not.toBeNull();
    expect(starts(mounted)[1].scope).toBe('HSCUSTOM');
  });

  it('drills a grid only in the namespace it ran in: after a namespace change its cells are unavailable and a click sends nothing', async () => {
    // Mutation (Rule 19): drop the namespace test from the store's `drill` and `drillable` -> the click posts a drill in HSCUSTOM and this goes red.
    const mounted = await mount();
    await runToEnd(mounted, CELLS);
    expect(all(mounted.host, 'drill-cell')[0].getAttribute('aria-disabled')).toBe('false');
    mounted.scope.change('HSCUSTOM');
    await settle(mounted.fixture);
    expect(all(mounted.host, 'drill-cell').length).toBe(4);
    expect(all(mounted.host, 'drill-cell')[0].getAttribute('aria-disabled')).toBe('true');
    all(mounted.host, 'drill-cell')[0].click();
    await settle(mounted.fixture);
    expect(starts(mounted).length).toBe(1);
    mounted.scope.change('USER');
    await settle(mounted.fixture);
    expect(all(mounted.host, 'drill-cell')[0].getAttribute('aria-disabled')).toBe('false');
  });

  it('stops polling when the page goes, and follows a run still running again on its return', async () => {
    const mounted = await mount();
    route(mounted, MDX_BACKGROUND_PATH, { ok: { id: RUN_ID, status: 'running' } });
    route(mounted, POLL_PATH, view('running'));
    await type(mounted, STATEMENT);
    await run(mounted);
    const count = mounted.posts.length;
    mounted.fixture.destroy();
    await flush(mounted);
    expect(mounted.posts.length).toBe(count);
    route(mounted, POLL_PATH, view('ended', { result: CELLS }));
    const again = TestBed.createComponent(MdxQueryPage);
    document.body.appendChild(again.nativeElement);
    planted.push(again.nativeElement);
    await settle(again);
    expect(mounted.posts.filter((post) => post.path === POLL_PATH).length).toBe(2);
    expect(status(again.nativeElement)).toBe('Rows: 2 of 2. Columns: 2 of 2.');
  });
});
