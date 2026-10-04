import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { FormDirty } from '../../core/form-dirty';
import { NavigationService } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { ScopeService } from '../../core/scope';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS, type ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { ScreenActionHandler, type ActionRefusal, type ActionSink, type ActionValues } from '../../shell/screen-action-handler';
import { ARCHETYPE_PAGES, DESCRIPTOR_PAGES, resolveScreenPage } from '../../shell/screen-outlet';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { DataBrowserPage } from './data-browser.page';
import { DATA_PATH } from './data-browser.store';

/**
 * Data browser over stubs of what the instance supplies -- the SQL schemas, tables and views reads
 * that fill the tree and the screen's own page route (Story 19.7). The real store, tree, grid and
 * template run, so the assertions are about rendered DOM: the schemas holding a table or a view, a
 * schema expanding to its tables then its views, a view marked, the empty, cut and refused lines, a
 * refused schema read again on its next expand, the tree read once the scope resolves and again on a
 * namespace switch, which closes every tab, a table opening to its first page posted in scope,
 * the status line with and without a total, Last drawn unavailable while the total is unknown, the
 * paging buttons, the Page field, Rows per page and Ctrl/Cmd+PageDown and PageUp each posting their
 * offset, no page past the route's furthest offset, a BIT filter's yes and no words, a stopped page
 * and an SQL error, a refusal as an alert, and no page entering the screen's store. Story 19.8 adds,
 * over a stub of the action handler: the row actions on a table and the read-only line on a view;
 * Add, Duplicate, Delete and Restore; the save dialog's Proceed and Cancel; a mixed answer rolled back
 * by key and the page read again, a failed insert kept staged; the Change column through a save;
 * staged rows surviving paging; `FormDirty`; another table opening in its own tab beside staged rows,
 * and the leave dialog when that tab closes (Story 19.16); a save's answer arriving after its staging
 * was dropped; leaving the route dropping what is staged; a refused save; and a namespace switch
 * closing every tab and discarding what any staged.
 */

const SCREEN = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.ExplorerSqlData') as ScreenDeclaration;

const SCHEMAS_PATH = '/api/ocupilot/screens/explorer.sqlschemas/read?maxRows=1000&system=no';

function tablesPath(schema: string): string {
  return `/api/ocupilot/screens/explorer.sqltables/read?maxRows=1000&system=no&schema=${encodeURIComponent(schema)}`;
}

function viewsPath(schema: string): string {
  return `/api/ocupilot/screens/explorer.sqlviews/read?maxRows=1000&system=no&schema=${encodeURIComponent(schema)}`;
}

type Answer = { readonly ok: unknown } | { readonly status: number; readonly code: string; readonly reason: string; readonly detail?: Record<string, unknown> };

interface Request {
  readonly path: string;
  readonly body: Record<string, unknown> | null;
  readonly scope: string | null | undefined;
}

interface Send {
  readonly descriptor: string;
  readonly actionId: string;
  readonly target: string;
  readonly values: ActionValues | undefined;
  readonly scope: string | undefined;
}

type SendAnswer = { readonly applied: true; readonly output: unknown } | { readonly applied: false; readonly code: string; readonly reason: string };

interface Mounted {
  readonly fixture: ComponentFixture<DataBrowserPage>;
  readonly host: HTMLElement;
  readonly stores: ScreenStores;
  readonly requests: Request[];
  readonly routes: Map<string, Answer[]>;
  /** What a data post answers when no route is queued for it. */
  page: Answer;
  /** While set, each data post waits in `held` until the test answers it. */
  hold: boolean;
  readonly held: ((answer: Answer) => void)[];
  /** Resolve the scope to `namespace` and tell its subscribers, as a namespace switch does. */
  switchTo(namespace: string): Promise<void>;
  readonly sends: Send[];
  /** What the next save is answered. */
  sendAnswer: SendAnswer;
  /** While set, each save waits in `heldSends` until the test lets it go. */
  holdSend: boolean;
  readonly heldSends: (() => void)[];
  readonly formDirty: FormDirty;
}

interface MountOptions {
  /** Whether the scope has resolved when the page is created; `false` leaves it unresolved. */
  readonly loaded?: boolean;
  /** Changes to the routes before the page is created. */
  readonly routes?: (routes: Map<string, Answer[]>) => void;
}

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

function readAnswer(rows: unknown[], truncated = false): Answer {
  return { ok: { fields: [], rows, truncated, banner: '', bannerRequires: '' } };
}

const COLUMNS = [
  { name: 'Name', type: 'varchar', kind: 'text', nullable: true, key: false },
  { name: 'Num', type: 'integer', kind: 'number', nullable: true, key: true },
  { name: 'Flag', type: 'bit', kind: 'boolean', nullable: true, key: false },
  { name: 'Notes', type: 'longvarchar', kind: 'stream', nullable: true, key: false },
];

function pageAnswer(rows: (string | null)[][], extra: Record<string, unknown> = {}): Answer {
  return {
    ok: {
      outcome: 'rows',
      table: { schema: 'OcuProbe197', name: 'Plain', type: 'table' },
      columns: COLUMNS,
      key: ['Num'],
      rows,
      offset: 0,
      size: 100,
      more: false,
      total: rows.length,
      truncated: false,
      ...extra,
    },
  };
}

async function mount(options: MountOptions = {}): Promise<Mounted> {
  TestBed.resetTestingModule();
  const scope = { loaded: options.loaded ?? true, namespace: 'USER', listeners: new Set<() => void>() };
  const stores = new ScreenStores({ account: stubAccountPreferences() });
  const mounted = {
    requests: [] as Request[],
    routes: new Map<string, Answer[]>(),
    page: pageAnswer([]),
    hold: false,
    held: [] as ((answer: Answer) => void)[],
    sends: [] as Send[],
    sendAnswer: { applied: true, output: null } as SendAnswer,
    holdSend: false,
    heldSends: [] as (() => void)[],
    formDirty: new FormDirty(),
  };
  let lastRefusal: ActionRefusal | null = null;
  let lastOutput: unknown = null;
  const handler = {
    sendFor: async (descriptor: string, actionId: string, target: string, values?: ActionValues, sink?: ActionSink, scope?: string) => {
      mounted.sends.push({ descriptor, actionId, target, values, scope });
      if (mounted.holdSend) await new Promise<void>((resolve) => mounted.heldSends.push(resolve));
      const outcome = mounted.sendAnswer;
      if (!outcome.applied) {
        lastRefusal = { reason: outcome.reason, code: outcome.code, violations: [], detail: null };
        lastOutput = null;
        sink?.setRefusal(outcome.reason);
        return false;
      }
      lastRefusal = null;
      lastOutput = outcome.output;
      return true;
    },
    lastRefusal: () => lastRefusal,
    lastOutput: () => lastOutput,
  };
  mounted.routes.set(SCHEMAS_PATH, [
    readAnswer([
      { Schema: 'OcuProbe197', Tables: true, Views: true, Procedures: false },
      { Schema: 'Empty', Tables: false, Views: false, Procedures: true },
      { Schema: 'OnlyViews', Tables: false, Views: true, Procedures: false },
    ]),
  ]);
  mounted.routes.set(tablesPath('OcuProbe197'), [readAnswer([{ Table: 'OcuProbe197.Plain', Schema: 'OcuProbe197', Name: 'Plain' }])]);
  mounted.routes.set(viewsPath('OcuProbe197'), [readAnswer([{ View: 'OcuProbe197.Over30', Schema: 'OcuProbe197', Name: 'Over30' }])]);
  mounted.routes.set(tablesPath('OnlyViews'), [readAnswer([], true)]);
  mounted.routes.set(viewsPath('OnlyViews'), [readAnswer([])]);
  options.routes?.(mounted.routes);
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      mounted.requests.push({ path, body: init.body === undefined ? null : (JSON.parse(init.body) as Record<string, unknown>), scope: init.scope });
      const answer =
        path === DATA_PATH && mounted.hold
          ? await new Promise<Answer>((resolve) => mounted.held.push(resolve))
          : (mounted.routes.get(path)?.shift() ?? (path === DATA_PATH ? mounted.page : { status: 404, code: 'ROUTE.NOTFOUND', reason: 'no route' }));
      if ('ok' in answer) return { kind: 'ok', status: 200, body: answer.ok as T };
      return { kind: 'error', status: answer.status, code: answer.code, reason: answer.reason, detail: answer.detail ?? null };
    },
  };
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ScreenActionHandler, useValue: handler as unknown as ScreenActionHandler },
      { provide: FormDirty, useValue: mounted.formDirty },
      { provide: OverlayStack, useValue: new OverlayStack() },
      { provide: NavigationService, useValue: { screenForUrl: () => SCREEN } as unknown as NavigationService },
      { provide: ScreenStores, useValue: stores },
      {
        provide: ScopeService,
        useValue: {
          loaded: () => scope.loaded,
          namespace: () => (scope.loaded ? scope.namespace : ''),
          subscribe: (listener: () => void) => {
            scope.listeners.add(listener);
            return () => scope.listeners.delete(listener);
          },
        } as unknown as ScopeService,
      },
    ],
  });
  await TestBed.inject(Router).navigateByUrl(`/${SCREEN.route}?ns=USER`);
  const fixture = TestBed.createComponent(DataBrowserPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  const switchTo = async (namespace: string): Promise<void> => {
    scope.loaded = true;
    scope.namespace = namespace;
    for (const listener of [...scope.listeners]) listener();
    await settle(fixture);
  };
  return Object.assign(mounted, { fixture, host: fixture.nativeElement as HTMLElement, stores, switchTo }) as Mounted;
}

function el<T extends HTMLElement>(host: ParentNode, slot: string): T {
  return host.querySelector(`[data-ocu-data="${slot}"]`) as T;
}

function all(host: ParentNode, slot: string): HTMLElement[] {
  return [...host.querySelectorAll<HTMLElement>(`[data-ocu-data="${slot}"]`)];
}

function texts(host: ParentNode, slot: string): string[] {
  return all(host, slot).map((node) => node.textContent?.replace(/\s+/g, ' ').trim() ?? '');
}

function dataPosts(mounted: Mounted): Record<string, unknown>[] {
  return mounted.requests.filter((request) => request.path === DATA_PATH).map((request) => request.body ?? {});
}

async function click(mounted: Mounted, node: HTMLElement): Promise<void> {
  node.click();
  await settle(mounted.fixture);
}

async function expandAndOpen(mounted: Mounted): Promise<void> {
  await click(mounted, all(mounted.host, 'tree-schema')[0]);
  await click(mounted, all(mounted.host, 'tree-object')[0]);
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
});

describe('Data browser', () => {
  it("is the screen's own page; the tree lists the schemas holding a table or a view, and the empty state invites a pick", async () => {
    expect(resolveScreenPage(DESCRIPTOR_PAGES, ARCHETYPE_PAGES, SCREEN.descriptor, SCREEN.archetype)).toBe(DataBrowserPage);
    const { host, requests } = await mount();
    expect(requests[0].path).toBe(SCHEMAS_PATH);
    expect(texts(host, 'tree-schema')).toEqual(['\u25b8OcuProbe197', '\u25b8OnlyViews']);
    expect(el(host, 'tree').getAttribute('role')).toBe('tree');
    expect(el(host, 'tree').getAttribute('tabindex')).toBe('0');
    expect(el(host, 'empty').textContent?.trim()).toBe(STRINGS.explorerSqlDataPick);
  });

  it('expanding a schema lists its tables and views', async () => {
    const mounted = await mount();
    await click(mounted, all(mounted.host, 'tree-schema')[0]);
    expect(mounted.requests.map((request) => request.path).slice(1)).toEqual([tablesPath('OcuProbe197'), viewsPath('OcuProbe197')]);
    expect(texts(mounted.host, 'tree-object')).toEqual(['Plain', `Over30${STRINGS.viewMenuLabel}`]);
    const schema = mounted.host.querySelector('[role="treeitem"][aria-level="1"]') as HTMLElement;
    expect(schema.getAttribute('aria-expanded')).toBe('true');
    await click(mounted, all(mounted.host, 'tree-schema')[1]);
    expect(texts(mounted.host, 'tree-line')).toEqual([STRINGS.explorerSqlDataSchemaEmpty, STRINGS.explorerSqlDataTreeCut]);
  });

  it('the tree follows the APG keys: Down, Right to expand and to the first child, Enter to open, Left to the parent', async () => {
    const mounted = await mount();
    const tree = el(mounted.host, 'tree');
    tree.dispatchEvent(new FocusEvent('focus'));
    await settle(mounted.fixture);
    expect(tree.getAttribute('aria-activedescendant')).toBe('ocu-data-tree-s0');
    tree.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowRight', bubbles: true }));
    await settle(mounted.fixture);
    expect(texts(mounted.host, 'tree-object').length).toBe(2);
    tree.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowRight', bubbles: true }));
    await settle(mounted.fixture);
    expect(tree.getAttribute('aria-activedescendant')).toBe('ocu-data-tree-s0-o0');
    tree.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
    await settle(mounted.fixture);
    expect(dataPosts(mounted)).toHaveLength(1);
    tree.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowLeft', bubbles: true }));
    await settle(mounted.fixture);
    expect(tree.getAttribute('aria-activedescendant')).toBe('ocu-data-tree-s0');
    tree.dispatchEvent(new KeyboardEvent('keydown', { key: 'End', bubbles: true }));
    await settle(mounted.fixture);
    expect(tree.getAttribute('aria-activedescendant')).toBe('ocu-data-tree-s1');
  });

  it('opening a table posts its first page in scope and draws the grid, its status and its controls', async () => {
    const mounted = await mount();
    mounted.page = pageAnswer([
      ['n1', '1', '1', 'note1'],
      [null, '2', '0', ''],
    ]);
    await expandAndOpen(mounted);
    expect(mounted.requests.at(-1)).toEqual({
      path: DATA_PATH,
      body: { schema: 'OcuProbe197', table: 'Plain', filters: {}, sort: null, offset: 0, size: 100 },
      scope: 'USER',
    });
    expect(el(mounted.host, 'heading').textContent?.trim()).toBe('OcuProbe197.Plain');
    expect(el(mounted.host, 'status').textContent?.trim()).toBe('Rows 1\u20132 of 2');
    expect(texts(mounted.host, 'cell')).toEqual(['n1', '1', STRINGS.tableStatusYes, 'note1', STRINGS.explorerSqlDataNull, '2', STRINGS.tableStatusNo, '']);
    expect(el(mounted.host, 'first').getAttribute('aria-disabled')).toBe('true');
    expect(el(mounted.host, 'next').getAttribute('aria-disabled')).toBe('true');
    expect(el(mounted.host, 'last').getAttribute('aria-disabled')).toBe('true');
    expect(el(mounted.host, 'page-count').textContent?.trim()).toBe('of 1');
    expect(el(mounted.host, 'page').getAttribute('aria-describedby')).toBe('ocu-data-page-count');
    expect(mounted.stores.for(SCREEN.descriptor, SCREEN.refreshRates).data()).toEqual([]);
  });

  it('with an unknown total the status reads Rows a\u2013b, Last stays unavailable, and Next moves past the rows shown', async () => {
    const mounted = await mount();
    const rows = Array.from({ length: 100 }, (_, at) => [`n${at + 1}`, String(at + 1), '1', '']);
    mounted.page = pageAnswer(rows, { more: true, total: null });
    await expandAndOpen(mounted);
    expect(el(mounted.host, 'status').textContent?.trim()).toBe('Rows 1\u2013100');
    expect(el(mounted.host, 'last').getAttribute('aria-disabled')).toBe('true');
    expect(el(mounted.host, 'page-count')).toBeNull();
    await click(mounted, el(mounted.host, 'last'));
    expect(dataPosts(mounted)).toHaveLength(1);
    mounted.page = pageAnswer(rows.slice(0, 40), { offset: 100, total: null });
    await click(mounted, el(mounted.host, 'next'));
    expect(dataPosts(mounted).at(-1)?.['offset']).toBe(100);
    expect(el(mounted.host, 'status').textContent?.trim()).toBe('Rows 101\u2013140');
    const field = el<HTMLInputElement>(mounted.host, 'page');
    field.value = 'x';
    field.dispatchEvent(new Event('input'));
    field.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
    await settle(mounted.fixture);
    expect(el(mounted.host, 'page-problem').textContent?.trim()).toBe('Enter a page from 1 to 1,000,000.');
  });

  it('Ctrl+PageDown and Cmd+PageUp on the grid post the next and the previous page', async () => {
    const mounted = await mount();
    const rows = Array.from({ length: 100 }, (_, at) => [`n${at + 1}`, String(at + 1), '1', '']);
    mounted.page = pageAnswer(rows, { more: true, total: 250 });
    await expandAndOpen(mounted);
    mounted.page = pageAnswer(rows, { offset: 100, more: true, total: 250 });
    el(mounted.host, 'grid').dispatchEvent(new KeyboardEvent('keydown', { key: 'PageDown', ctrlKey: true, bubbles: true }));
    await settle(mounted.fixture);
    expect(dataPosts(mounted).at(-1)?.['offset']).toBe(100);
    mounted.page = pageAnswer(rows, { more: true, total: 250 });
    el(mounted.host, 'grid').dispatchEvent(new KeyboardEvent('keydown', { key: 'PageUp', metaKey: true, bubbles: true }));
    await settle(mounted.fixture);
    expect(dataPosts(mounted).at(-1)?.['offset']).toBe(0);
  });

  it('no Next or Last starts past the furthest offset the route takes', async () => {
    const mounted = await mount();
    const rows = Array.from({ length: 100 }, (_, at) => [`n${at + 1}`, String(at + 1), '1', '']);
    mounted.page = pageAnswer(rows, { more: true, total: 150_000_000 });
    await expandAndOpen(mounted);
    expect(el(mounted.host, 'last').getAttribute('aria-disabled')).toBe('true');
    mounted.page = pageAnswer(rows, { offset: 99_999_900, more: true, total: null });
    await click(mounted, el(mounted.host, 'refresh'));
    expect(el(mounted.host, 'next').getAttribute('aria-disabled')).toBe('true');
  });

  it('a BIT filter takes the yes and no words the grid shows, in any case', async () => {
    const mounted = await mount();
    mounted.page = pageAnswer([['n1', '1', '1', '']]);
    await expandAndOpen(mounted);
    const flag = all(mounted.host, 'filter')[2] as HTMLInputElement;
    flag.value = STRINGS.tableStatusYes.toUpperCase();
    flag.dispatchEvent(new Event('input'));
    flag.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
    await settle(mounted.fixture);
    expect(dataPosts(mounted).at(-1)?.['filters']).toEqual({ Flag: '1' });
  });

  // Mutation (Rule 19): drop the page's `onScopeChange` subscription -> the old namespace's tree and
  // tabs stay on screen and this goes red.
  it("a namespace switch closes every tab, drops an answer on its way, and reads the new namespace's tree", async () => {
    const mounted = await mount();
    await expandAndOpen(mounted);
    mounted.hold = true;
    await click(mounted, all(mounted.host, 'tree-object')[1]);
    expect(mounted.held).toHaveLength(1);
    expect(all(mounted.host, 'tab')).toHaveLength(2);
    mounted.routes.set(SCHEMAS_PATH, [readAnswer([{ Schema: 'Samples', Tables: true, Views: false, Procedures: false }])]);
    await mounted.switchTo('SAMPLES');
    mounted.held[0](pageAnswer([['p1', '1', '1', '']]));
    await settle(mounted.fixture);
    expect(mounted.requests.filter((request) => request.path === SCHEMAS_PATH)).toHaveLength(2);
    expect(texts(mounted.host, 'tree-schema')).toEqual(['\u25b8Samples']);
    expect(all(mounted.host, 'tab')).toHaveLength(0);
    expect(el(mounted.host, 'heading')).toBeNull();
    expect(el(mounted.host, 'empty').textContent?.trim()).toBe(STRINGS.explorerSqlDataPick);
  });

  it('the tree waits for the scope to resolve before it reads', async () => {
    const mounted = await mount({ loaded: false });
    expect(mounted.requests).toEqual([]);
    await mounted.switchTo('USER');
    expect(mounted.requests.map((request) => request.path)).toEqual([SCHEMAS_PATH]);
    expect(texts(mounted.host, 'tree-schema')).toEqual(['\u25b8OcuProbe197', '\u25b8OnlyViews']);
  });

  it('a refused schema read says so in place of the empty line and is read again on its next expand', async () => {
    const mounted = await mount({
      routes: (routes) => {
        routes.set(tablesPath('OcuProbe197'), [{ status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'denied' }, readAnswer([{ Schema: 'OcuProbe197', Name: 'Plain' }])]);
        routes.set(viewsPath('OcuProbe197'), [readAnswer([]), readAnswer([])]);
      },
    });
    const schema = (): HTMLElement => all(mounted.host, 'tree-schema')[0];
    await click(mounted, schema());
    expect(texts(mounted.host, 'tree-line')).toEqual([STRINGS.connectivityRequestRefused]);
    await click(mounted, schema());
    await click(mounted, schema());
    expect(texts(mounted.host, 'tree-object')).toEqual(['Plain']);
    expect(texts(mounted.host, 'tree-line')).toEqual([]);
  });

  it('a refused schemas read, and one cut at its cap, each say so', async () => {
    const refused = await mount({ routes: (routes) => routes.set(SCHEMAS_PATH, [{ status: 500, code: 'INTERNAL', reason: 'failed' }]) });
    expect(el(refused.host, 'tree-fault').textContent?.trim()).toBe(STRINGS.connectivityRequestRefused);
    const cut = await mount({ routes: (routes) => routes.set(SCHEMAS_PATH, [readAnswer([{ Schema: 'OcuProbe197', Tables: true, Views: false, Procedures: false }], true)]) });
    expect(el(cut.host, 'tree-cut').textContent?.trim()).toBe(STRINGS.explorerSqlDataTreeCut);
  });

  it('First, Previous, Last, the Page field and Rows per page each post their offset', async () => {
    const mounted = await mount();
    const rows = Array.from({ length: 100 }, (_, at) => [`n${at + 1}`, String(at + 1), '1', '']);
    mounted.page = pageAnswer(rows, { more: true, total: 260 });
    await expandAndOpen(mounted);
    mounted.page = pageAnswer(rows.slice(0, 60), { offset: 200, more: false, total: 260 });
    await click(mounted, el(mounted.host, 'last'));
    expect(dataPosts(mounted).at(-1)?.['offset']).toBe(200);
    expect(el(mounted.host, 'last').getAttribute('aria-disabled')).toBe('true');
    mounted.page = pageAnswer(rows.slice(0, 50), { size: 50, more: true, total: 260 });
    const sizes = el<HTMLSelectElement>(mounted.host, 'size');
    sizes.value = '50';
    sizes.dispatchEvent(new Event('change'));
    await settle(mounted.fixture);
    expect(dataPosts(mounted).at(-1)).toMatchObject({ offset: 0, size: 50 });
    mounted.page = pageAnswer(rows, { offset: 100, size: 50, more: true, total: 260 });
    const field = el<HTMLInputElement>(mounted.host, 'page');
    field.value = '3';
    field.dispatchEvent(new Event('input'));
    field.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
    await settle(mounted.fixture);
    expect(dataPosts(mounted).at(-1)).toMatchObject({ offset: 100, size: 50 });
    expect(el<HTMLInputElement>(mounted.host, 'page').value).toBe('3');
    expect(el(mounted.host, 'page-count').textContent?.trim()).toBe('of 6');
    await click(mounted, el(mounted.host, 'previous'));
    expect(dataPosts(mounted).at(-1)?.['offset']).toBe(50);
    await click(mounted, el(mounted.host, 'first'));
    expect(dataPosts(mounted).at(-1)?.['offset']).toBe(0);
    const before = dataPosts(mounted).length;
    const again = el<HTMLInputElement>(mounted.host, 'page');
    again.value = '9';
    again.dispatchEvent(new Event('input'));
    again.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
    await settle(mounted.fixture);
    expect(dataPosts(mounted)).toHaveLength(before);
    expect(el(mounted.host, 'page-problem').textContent?.trim()).toBe('Enter a page from 1 to 6.');
  });

  // Mutation (Rule 19): `cycleSort` keeps the offset -> each step, taken from the second page, posts
  // offset 100 and this goes red.
  it('a header cycles the sort ascending, descending and none, each from the first page, with aria-sort and an announcement', async () => {
    const mounted = await mount();
    const rows = Array.from({ length: 100 }, (_, at) => [`n${at + 1}`, String(at + 1), '1', '']);
    mounted.page = pageAnswer(rows, { more: true, total: 250 });
    await expandAndOpen(mounted);
    const header = (): HTMLElement => all(mounted.host, 'header')[1];
    for (const [sort, ariaSort, line] of [
      [{ column: 'Num', direction: 'asc' }, 'ascending', 'Sorted by Num, ascending.'],
      [{ column: 'Num', direction: 'desc' }, 'descending', 'Sorted by Num, descending.'],
      [null, null, 'Sort cleared.'],
    ] as const) {
      await click(mounted, el(mounted.host, 'next'));
      expect(dataPosts(mounted).at(-1)?.['offset']).toBe(100);
      await click(mounted, header());
      expect(dataPosts(mounted).at(-1)).toMatchObject({ sort, offset: 0 });
      expect(header().getAttribute('aria-sort')).toBe(ariaSort);
      expect(el(mounted.host, 'status').textContent?.trim().startsWith(line)).toBe(true);
    }
    const streamHeader = all(mounted.host, 'header')[3];
    const before = dataPosts(mounted).length;
    await click(mounted, streamHeader);
    expect(dataPosts(mounted)).toHaveLength(before);
  });

  // Mutation (Rule 19): `applyFilter` keeps the offset -> the Enter leg, taken from the second page,
  // posts offset 100 and this goes red.
  it('a filter applies on Enter and clears on Escape, each from the first page, and a stream column takes none', async () => {
    const mounted = await mount();
    const rows = Array.from({ length: 100 }, (_, at) => [`n${at + 1}`, String(at + 1), '1', '']);
    mounted.page = pageAnswer(rows, { more: true, total: 250 });
    await expandAndOpen(mounted);
    expect(el(mounted.host, 'filters').getAttribute('aria-label')).toBe(STRINGS.explorerSqlDataFilters);
    expect(all(mounted.host, 'filter').map((input) => input.getAttribute('aria-label'))).toEqual(['Filter Name', 'Filter Num', 'Filter Flag']);
    await click(mounted, el(mounted.host, 'next'));
    expect(dataPosts(mounted).at(-1)?.['offset']).toBe(100);
    const name = all(mounted.host, 'filter')[0] as HTMLInputElement;
    name.value = 'n3*';
    name.dispatchEvent(new Event('input'));
    name.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
    await settle(mounted.fixture);
    expect(dataPosts(mounted).at(-1)).toMatchObject({ filters: { Name: 'n3*' }, offset: 0 });
    mounted.page = pageAnswer([]);
    await click(mounted, el(mounted.host, 'refresh'));
    expect(el(mounted.host, 'status').textContent?.trim()).toBe(STRINGS.explorerSqlDataNoMatch);
    mounted.page = pageAnswer(rows, { more: true, total: 250 });
    await click(mounted, el(mounted.host, 'refresh'));
    await click(mounted, el(mounted.host, 'next'));
    expect(dataPosts(mounted).at(-1)).toMatchObject({ filters: { Name: 'n3*' }, offset: 100 });
    mounted.page = pageAnswer([]);
    const again = all(mounted.host, 'filter')[0] as HTMLInputElement;
    again.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
    await settle(mounted.fixture);
    expect(dataPosts(mounted).at(-1)).toMatchObject({ filters: {}, offset: 0 });
    expect((all(mounted.host, 'filter')[0] as HTMLInputElement).value).toBe('');
    expect(el(mounted.host, 'status').textContent?.trim()).toBe(STRINGS.explorerSqlDataNoRows);
  });

  it('Clear filters drops every filter and returns to the first page', async () => {
    const mounted = await mount();
    const rows = Array.from({ length: 100 }, (_, at) => [`n${at + 1}`, String(at + 1), '1', '']);
    mounted.page = pageAnswer(rows, { more: true, total: 250 });
    await expandAndOpen(mounted);
    expect(el(mounted.host, 'clear-filters').getAttribute('aria-disabled')).toBe('true');
    const name = all(mounted.host, 'filter')[0] as HTMLInputElement;
    name.value = 'n*';
    name.dispatchEvent(new Event('input'));
    name.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
    await settle(mounted.fixture);
    await click(mounted, el(mounted.host, 'next'));
    expect(dataPosts(mounted).at(-1)).toMatchObject({ filters: { Name: 'n*' }, offset: 100 });
    await click(mounted, el(mounted.host, 'clear-filters'));
    expect(dataPosts(mounted).at(-1)).toMatchObject({ filters: {}, offset: 0 });
    expect((all(mounted.host, 'filter')[0] as HTMLInputElement).value).toBe('');
  });

  // Mutation (Rule 19): `nextPage` steps by the page size -> the cut page's Next posts offset 100 and
  // this goes red.
  it('Next after a page cut short moves past the rows it kept, so none is skipped', async () => {
    const mounted = await mount();
    const rows = Array.from({ length: 37 }, (_, at) => [`n${at + 1}`, String(at + 1), '1', '']);
    mounted.page = pageAnswer(rows, { more: true, total: 250, truncated: true });
    await expandAndOpen(mounted);
    expect(el(mounted.host, 'status').textContent?.trim()).toBe('Rows 1\u201337 of 250');
    await click(mounted, el(mounted.host, 'next'));
    expect(dataPosts(mounted).at(-1)?.['offset']).toBe(37);
  });

  // Mutation (Rule 19): drop the generation check in `DataTab.read` -> the older answer to the first
  // table's tab lands last and this goes red.
  it("a slow first table's answer fills its own tab, never the second's, and an older answer to one tab is dropped", async () => {
    const mounted = await mount();
    await click(mounted, all(mounted.host, 'tree-schema')[0]);
    mounted.hold = true;
    await click(mounted, all(mounted.host, 'tree-object')[0]);
    await click(mounted, all(mounted.host, 'tree-object')[1]);
    expect(mounted.held).toHaveLength(2);
    const [first, second] = mounted.held;
    second({ ok: { ...(pageAnswer([['v31', '31', '1', '']]) as { ok: Record<string, unknown> }).ok, table: { schema: 'OcuProbe197', name: 'Over30', type: 'view' } } });
    await settle(mounted.fixture);
    first(pageAnswer([['p1', '1', '1', ''], ['p2', '2', '0', '']]));
    await settle(mounted.fixture);
    expect(el(mounted.host, 'heading').textContent?.trim()).toBe('OcuProbe197.Over30');
    expect(texts(mounted.host, 'cell')[0]).toBe('v31');
    expect(el(mounted.host, 'status').textContent?.trim()).toBe('Rows 1\u20131 of 1');
    await click(mounted, tabNamed(mounted, 'OcuProbe197.Plain'));
    expect(mounted.held).toHaveLength(2);
    expect(texts(mounted.host, 'cell')[0]).toBe('p1');
    await click(mounted, el(mounted.host, 'refresh'));
    await click(mounted, all(mounted.host, 'header')[1]);
    const [older, newer] = mounted.held.slice(2);
    newer(pageAnswer([['new', '1', '1', '']]));
    await settle(mounted.fixture);
    older(pageAnswer([['old', '1', '1', '']]));
    await settle(mounted.fixture);
    expect(texts(mounted.host, 'cell')[0]).toBe('new');
  });

  it('a stopped page and an SQL error read their status lines, the message as text', async () => {
    const mounted = await mount();
    mounted.page = { ok: { outcome: 'stopped', table: { schema: 'OcuProbe197', name: 'Plain', type: 'table' }, columns: COLUMNS, key: [], seconds: 50 } };
    await expandAndOpen(mounted);
    expect(el(mounted.host, 'status').textContent?.trim()).toBe('Stopped after 50 seconds.');
    mounted.page = { ok: { outcome: 'error', table: { schema: 'OcuProbe197', name: 'Plain', type: 'table' }, columns: COLUMNS, key: [], sqlcode: -99, message: 'Privilege violation' } };
    await click(mounted, el(mounted.host, 'refresh'));
    expect(el(mounted.host, 'status').textContent?.trim()).toBe('SQLCODE -99');
    expect(el(mounted.host, 'message').textContent?.trim()).toBe('Privilege violation');
    expect(texts(mounted.host, 'cell')).toEqual([]);
  });

  it('a refusal is an alert: the envelope reason, or the missing pair', async () => {
    const mounted = await mount();
    mounted.page = { status: 404, code: 'EXPLORER.DATA.NOTFOUND', reason: STRINGS.explorerSqlDataNotFoundReason };
    await expandAndOpen(mounted);
    expect(el(mounted.host, 'refusal').getAttribute('role')).toBe('alert');
    expect(el(mounted.host, 'refusal').textContent?.trim()).toBe(STRINGS.explorerSqlDataNotFoundReason);
    mounted.page = { status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'denied', detail: { failedPair: '%Development:USE' } };
    await click(mounted, el(mounted.host, 'refresh'));
    expect(el(mounted.host, 'refusal').textContent?.trim()).toBe('Requires %Development:USE');
  });

  // --- Story 19.8: editing, staging and saving -----------------------------------------------------

  // AC9. Mutation (Rule 19): `writable` drops its key check -> the keyless table offers the row actions
  // and this goes red; `writable` ignores `keyUnique` -> the table keyed by a repeating column offers
  // them and this goes red.
  it('a table whose key this account lists offers the row actions; a view, a keyless table and one whose key may repeat read the read-only line and offer none', async () => {
    const mounted = await mount();
    mounted.page = pageAnswer([['n1', '1', '1', 'note1']]);
    await expandAndOpen(mounted);
    expect(texts(mounted.host, 'edit-actions')[0]).toContain(STRINGS.explorerSqlDataAddRow);
    expect(el(mounted.host, 'save').textContent?.trim()).toBe('Save changes (0)');
    expect(el(mounted.host, 'save').getAttribute('aria-disabled')).toBe('true');
    expect(el(mounted.host, 'read-only')).toBeNull();
    expect(all(mounted.host, 'status-cell')).toHaveLength(1);
    mounted.page = { ok: { ...(pageAnswer([['v1', '31', '1', '']]) as { ok: Record<string, unknown> }).ok, table: { schema: 'OcuProbe197', name: 'Over30', type: 'view' } } };
    await click(mounted, all(mounted.host, 'tree-object')[1]);
    expect(el(mounted.host, 'edit-actions')).toBeNull();
    expect(el(mounted.host, 'read-only').textContent?.trim()).toBe(STRINGS.explorerSqlDataReadOnly);
    expect(all(mounted.host, 'status-cell')).toHaveLength(0);
    mounted.page = pageAnswer([['k1', '1', '1', '']], { key: [] });
    await click(mounted, all(mounted.host, 'tree-object')[0]);
    await click(mounted, el(mounted.host, 'refresh'));
    expect(el(mounted.host, 'heading').textContent?.trim()).toBe('OcuProbe197.Plain');
    expect(el(mounted.host, 'edit-actions')).toBeNull();
    expect(el(mounted.host, 'read-only').textContent?.trim()).toBe(STRINGS.explorerSqlDataReadOnly);
    expect(all(mounted.host, 'status-cell')).toHaveLength(0);
    mounted.page = pageAnswer([['r1', '1', '1', '']], { keyUnique: false });
    await click(mounted, el(mounted.host, 'refresh'));
    expect(el(mounted.host, 'edit-actions')).toBeNull();
    expect(el(mounted.host, 'read-only').textContent?.trim()).toBe(STRINGS.explorerSqlDataReadOnly);
    expect(all(mounted.host, 'status-cell')).toHaveLength(0);
  });

  // AC1, AC3. Mutation (Rule 19): `frameOf` drops `generated` -> the computed cell opens an editor and
  // this goes red; `answerOf` drops `cuts` -> the cut cell opens one.
  it('a generated, an identity or a cut cell opens no editor, and Duplicate leaves each out, as the answer says', async () => {
    const mounted = await mount();
    const columns = [
      ...COLUMNS,
      { name: 'Calc', type: 'varchar', kind: 'text', nullable: true, key: false, generated: true },
      { name: 'Seq', type: 'integer', kind: 'number', nullable: false, key: false, identity: true },
    ];
    mounted.page = pageAnswer(
      [
        ['cut', '1', '1', 'note1', 'c1', '7'],
        ['n2', '2', '0', 'note2', 'c2', '8'],
      ],
      { columns, cuts: [[0, 0]] }
    );
    await expandAndOpen(mounted);
    for (const column of [1, 5, 6]) {
      await click(mounted, cellAt(mounted, 0, column));
      el(mounted.host, 'grid').dispatchEvent(new KeyboardEvent('keydown', { key: 'F2', bubbles: true }));
      await settle(mounted.fixture);
      expect(el(mounted.host, 'editor'), `grid column ${column}`).toBeNull();
      expect(el(mounted.host, 'status').textContent).toContain(STRINGS.explorerSqlDataNotEditable);
    }
    await click(mounted, cellAt(mounted, 1, 1));
    el(mounted.host, 'grid').dispatchEvent(new KeyboardEvent('keydown', { key: 'F2', bubbles: true }));
    await settle(mounted.fixture);
    expect(el(mounted.host, 'editor')).not.toBeNull();
    el(mounted.host, 'editor').dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
    await settle(mounted.fixture);
    await click(mounted, cellAt(mounted, 0, 3));
    await click(mounted, el(mounted.host, 'duplicate-row'));
    const NULL = STRINGS.explorerSqlDataNull;
    expect(texts(mounted.host, 'cell').slice(0, 6)).toEqual([NULL, NULL, STRINGS.tableStatusYes, NULL, NULL, NULL]);
  });

  // AC3. Mutation (Rule 19): `afterStaging` ignores a refused staging -> the status line keeps the count
  // and this goes red.
  it('the 101st staged row is refused with its sentence', async () => {
    const mounted = await mount();
    mounted.page = pageAnswer([['n1', '1', '1', 'note1']]);
    await expandAndOpen(mounted);
    const add = el(mounted.host, 'add-row');
    for (let at = 0; at < 100; at += 1) add.click();
    await settle(mounted.fixture);
    expect(el(mounted.host, 'status').textContent).toContain('100 changes waiting to be saved.');
    el(mounted.host, 'add-row').click();
    await settle(mounted.fixture);
    expect(el(mounted.host, 'status').textContent).toContain(STRINGS.explorerSqlDataCap);
    expect(texts(mounted.host, 'status-cell').filter((text) => text === STRINGS.explorerSqlDataNew)).toHaveLength(100);
  });

  // AC3.
  it('Add row puts a new row at the top; Duplicate copies the active row but its key and stream; Delete marks a row, Restore unmarks it, and removes a new row', async () => {
    const mounted = await mount();
    mounted.page = pageAnswer([['n1', '1', '1', 'note1'], ['n2', '2', '0', 'note2']]);
    await expandAndOpen(mounted);
    await click(mounted, el(mounted.host, 'add-row'));
    expect(texts(mounted.host, 'status-cell')).toEqual([STRINGS.explorerSqlDataNew, '', '']);
    expect(el(mounted.host, 'save').textContent?.trim()).toBe('Save changes (1)');
    expect(el(mounted.host, 'status').textContent?.trim()).toContain('1 changes waiting to be saved.');
    await click(mounted, cellAt(mounted, 1, 1));
    await click(mounted, el(mounted.host, 'duplicate-row'));
    expect(texts(mounted.host, 'status-cell')).toEqual([STRINGS.explorerSqlDataNew, STRINGS.explorerSqlDataNew, '', '']);
    expect(texts(mounted.host, 'cell').slice(0, 4)).toEqual(['n1', STRINGS.explorerSqlDataNull, STRINGS.tableStatusYes, STRINGS.explorerSqlDataNull]);
    await click(mounted, cellAt(mounted, 3, 1));
    expect(el(mounted.host, 'delete-row').textContent?.trim()).toBe(STRINGS.explorerSqlDataDeleteRow);
    await click(mounted, el(mounted.host, 'delete-row'));
    expect(texts(mounted.host, 'status-cell')[3]).toBe(STRINGS.explorerSqlDataDeleted);
    expect(el(mounted.host, 'delete-row').textContent?.trim()).toBe(STRINGS.explorerSqlDataRestoreRow);
    await click(mounted, el(mounted.host, 'delete-row'));
    expect(texts(mounted.host, 'status-cell')[3]).toBe('');
    await click(mounted, cellAt(mounted, 0, 1));
    await click(mounted, el(mounted.host, 'delete-row'));
    expect(texts(mounted.host, 'status-cell')).toEqual([STRINGS.explorerSqlDataNew, '', '']);
  });

  // AC4.
  it('Save opens the dialog naming the table and the counts; Cancel sends nothing; Proceed sends one save action with the staged rows', async () => {
    const mounted = await mount();
    mounted.page = pageAnswer([['n1', '1', '1', 'note1'], ['n2', '2', '0', 'note2']]);
    await expandAndOpen(mounted);
    await edit(mounted, 0, 1, 'renamed');
    await click(mounted, cellAt(mounted, 1, 1));
    await click(mounted, el(mounted.host, 'delete-row'));
    await click(mounted, el(mounted.host, 'add-row'));
    await edit(mounted, 0, 1, 'fresh');
    expect(mounted.formDirty.dirty()).toBe(true);
    await click(mounted, el(mounted.host, 'save'));
    const dialog = mounted.host.querySelector('app-warning-dialog') as HTMLElement;
    expect(dialog.textContent).toContain('Save changes to OcuProbe197.Plain?');
    expect(dialog.textContent).toContain('1 rows change, 1 are added and 1 are deleted in OcuProbe197.Plain, and this cannot be undone from OcuPilot.');
    await click(mounted, [...dialog.querySelectorAll('button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLElement);
    expect(mounted.sends).toEqual([]);
    expect(mounted.host.querySelector('app-warning-dialog')).toBeNull();
    mounted.sendAnswer = { applied: true, output: { outcome: 'saved', results: [], saved: 0, failed: 0 } };
    await click(mounted, el(mounted.host, 'save'));
    await proceed(mounted);
    expect(mounted.sends).toHaveLength(1);
    const sent = mounted.sends[0];
    expect([sent.descriptor, sent.actionId, sent.target, sent.scope]).toEqual([SCREEN.descriptor, 'save', 'sql', 'USER']);
    expect(sent.values?.['schema']).toBe('OcuProbe197');
    expect(sent.values?.['table']).toBe('Plain');
    expect(JSON.parse(sent.values?.['changes'] ?? '[]')).toEqual([
      { op: 'delete', key: { Num: '2' } },
      { op: 'update', key: { Num: '1' }, original: { Name: 'n1' }, values: { Name: 'renamed' } },
      { op: 'insert', values: { Name: 'fresh' } },
    ]);
  });

  // AC5. Mutation (Rule 19): `applyResults` keeps failed rows staged -> the changed row still reads its
  // staged value and this goes red.
  it('a mixed answer: the saved row leaves staging and the page reads again; a failed row rolls back and its Change cell names why; the status line summarizes', async () => {
    const mounted = await mount();
    mounted.page = pageAnswer([['n1', '1', '1', 'note1'], ['n2', '2', '0', 'note2'], ['n3', '3', '1', 'note3']]);
    await expandAndOpen(mounted);
    await edit(mounted, 0, 1, 'one');
    await edit(mounted, 1, 1, 'two');
    await edit(mounted, 2, 1, 'three');
    mounted.sendAnswer = {
      applied: true,
      output: {
        outcome: 'saved',
        results: [
          { index: 0, outcome: 'saved', rowCount: 1 },
          { index: 1, outcome: 'changed', rowCount: 0 },
          { index: 2, outcome: 'refused', sqlcode: -99 },
        ],
        saved: 1,
        failed: 2,
      },
    };
    mounted.page = pageAnswer([['one', '1', '1', 'note1'], ['n2', '2', '0', 'note2'], ['n3', '3', '1', 'note3']]);
    const before = dataPosts(mounted).length;
    await click(mounted, el(mounted.host, 'save'));
    await proceed(mounted);
    expect(dataPosts(mounted)).toHaveLength(before + 1);
    expect(texts(mounted.host, 'cell').filter((_, at) => at % 4 === 0)).toEqual(['one', 'n2', 'n3']);
    expect(texts(mounted.host, 'status-cell')).toEqual([STRINGS.formSaved, STRINGS.explorerSqlDataOutcomeChanged, STRINGS.explorerSqlDataOutcomeRefused]);
    expect(el(mounted.host, 'status').textContent?.trim().startsWith('Saved 1 of 3 changes; 2 rolled back.')).toBe(true);
    expect(el(mounted.host, 'save').textContent?.trim()).toBe('Save changes (0)');
    expect(mounted.formDirty.dirty()).toBe(false);
  });

  // AC5, AC10. Mutation (Rule 19): `applyResults` removes a failed insert -> the typed row goes and this
  // goes red; `outcomeText` drops an error's message -> its Change cell goes red; `outcomeText` reads a
  // stopped row as skipped -> its Change cell goes red.
  it('a failed insert stays staged with what was typed and names why; an error row names its SQLCODE and message; the stopped row reads its bound and those after it Not run', async () => {
    const mounted = await mount();
    const rows = [
      ['n1', '1', '1', 'note1'],
      ['n2', '2', '0', 'note2'],
      ['n3', '3', '1', 'note3'],
    ];
    mounted.page = pageAnswer(rows);
    await expandAndOpen(mounted);
    await edit(mounted, 0, 1, 'one');
    await edit(mounted, 1, 1, 'two');
    await edit(mounted, 2, 1, 'three');
    await click(mounted, el(mounted.host, 'add-row'));
    await edit(mounted, 0, 1, 'fresh');
    mounted.sendAnswer = {
      applied: true,
      output: {
        outcome: 'saved',
        results: [
          { index: 0, outcome: 'error', sqlcode: -105, message: 'Value out of range' },
          { index: 1, outcome: 'stopped', seconds: 2 },
          { index: 2, outcome: 'skipped' },
          { index: 3, outcome: 'error', sqlcode: -119, message: 'Duplicate key' },
        ],
        saved: 0,
        failed: 4,
      },
    };
    await click(mounted, el(mounted.host, 'save'));
    await proceed(mounted);
    expect(JSON.parse(mounted.sends[0].values?.['changes'] ?? '[]').map((change: { op: string }) => change.op)).toEqual(['update', 'update', 'update', 'insert']);
    expect(texts(mounted.host, 'status-cell')).toEqual([
      `${STRINGS.explorerSqlCode.replace('<code>', '-119')}: Duplicate key`,
      `${STRINGS.explorerSqlCode.replace('<code>', '-105')}: Value out of range`,
      STRINGS.explorerSqlStopped.replace('<s>', '2'),
      STRINGS.explorerSqlDataOutcomeSkipped,
    ]);
    expect(texts(mounted.host, 'cell').filter((_, at) => at % 4 === 0)).toEqual(['fresh', 'n1', 'n2', 'n3']);
    expect(el(mounted.host, 'status').textContent?.trim().startsWith('Saved 0 of 4 changes; 4 rolled back.')).toBe(true);
    expect(el(mounted.host, 'save').textContent?.trim()).toBe('Save changes (1)');
    expect(mounted.formDirty.dirty()).toBe(true);
    await edit(mounted, 0, 1, 'fresher');
    expect(texts(mounted.host, 'status-cell')[0]).toBe(STRINGS.explorerSqlDataNew);
  });

  // AC12. Mutation (Rule 19): the page draws the grid's Change column only while it offers its editors
  // -> the column goes while the save is on its way and this goes red.
  it('the Change column and its cells stay while a save is on its way, and no editor opens', async () => {
    const mounted = await mount();
    mounted.page = pageAnswer([['n1', '1', '1', 'note1']]);
    await expandAndOpen(mounted);
    await edit(mounted, 0, 1, 'pending');
    const columns = el(mounted.host, 'grid').getAttribute('aria-colcount');
    mounted.holdSend = true;
    mounted.sendAnswer = { applied: true, output: { outcome: 'saved', results: [{ index: 0, outcome: 'saved', rowCount: 1 }], saved: 1, failed: 0 } };
    await click(mounted, el(mounted.host, 'save'));
    await proceed(mounted);
    expect(el(mounted.host, 'grid').getAttribute('aria-colcount')).toBe(columns);
    expect(texts(mounted.host, 'status-cell')).toEqual([STRINGS.tableChangedTag]);
    el(mounted.host, 'grid').dispatchEvent(new KeyboardEvent('keydown', { key: 'F2', bubbles: true }));
    await settle(mounted.fixture);
    expect(el(mounted.host, 'editor')).toBeNull();
    for (const release of mounted.heldSends.splice(0)) release();
    await settle(mounted.fixture);
    expect(texts(mounted.host, 'status-cell')).toEqual([STRINGS.formSaved]);
  });

  // AC11. Mutation (Rule 19): `save` applies an answer whose staging was dropped meanwhile -> the page is
  // read again and its status line claims the old save, and this goes red.
  it('a save answering after its staging was dropped applies nothing to what is staged now', async () => {
    const mounted = await mount();
    mounted.page = pageAnswer([['n1', '1', '1', 'note1']]);
    await expandAndOpen(mounted);
    await edit(mounted, 0, 1, 'old');
    mounted.holdSend = true;
    mounted.sendAnswer = { applied: true, output: { outcome: 'saved', results: [{ index: 0, outcome: 'saved', rowCount: 1 }], saved: 1, failed: 0 } };
    await click(mounted, el(mounted.host, 'save'));
    await proceed(mounted);
    mounted.routes.set(SCHEMAS_PATH, [readAnswer([{ Schema: 'OcuProbe197', Tables: true, Views: true, Procedures: false }])]);
    mounted.routes.set(tablesPath('OcuProbe197'), [readAnswer([{ Schema: 'OcuProbe197', Name: 'Plain' }])]);
    mounted.routes.set(viewsPath('OcuProbe197'), [readAnswer([])]);
    await mounted.switchTo('SAMPLES');
    await expandAndOpen(mounted);
    await edit(mounted, 0, 1, 'new');
    const posts = dataPosts(mounted).length;
    for (const release of mounted.heldSends.splice(0)) release();
    await settle(mounted.fixture);
    expect(dataPosts(mounted)).toHaveLength(posts);
    expect(el(mounted.host, 'status').textContent).not.toContain('Saved 1 of 1');
    expect(el(mounted.host, 'save').textContent?.trim()).toBe('Save changes (1)');
    expect(texts(mounted.host, 'status-cell')).toEqual([STRINGS.tableChangedTag]);
  });

  // AC11. Mutation (Rule 19): the page keeps what is staged when it is left -> the page opened again
  // still offers Save changes (1) and this goes red.
  it('leaving the route drops what is staged, so the page opened again offers nothing to save', async () => {
    const mounted = await mount();
    mounted.page = pageAnswer([['n1', '1', '1', 'note1']]);
    await expandAndOpen(mounted);
    await edit(mounted, 0, 1, 'left');
    expect(el(mounted.host, 'save').textContent?.trim()).toBe('Save changes (1)');
    mounted.fixture.destroy();
    expect(mounted.formDirty.dirty()).toBe(false);
    const again = TestBed.createComponent(DataBrowserPage);
    document.body.appendChild(again.nativeElement);
    planted.push(again.nativeElement);
    await settle(again);
    const host = again.nativeElement as HTMLElement;
    expect(el(host, 'save').textContent?.trim()).toBe('Save changes (0)');
    expect(texts(host, 'status-cell')).toEqual(['']);
    expect(texts(host, 'cell')[0]).toBe('n1');
  });

  // Mutation (Rule 19): `discard` leaves a save on its way marked as saving -> the page opened again
  // offers no row action and this goes red.
  it('leaving the page while a save is on its way does not leave editing off when it opens again', async () => {
    const mounted = await mount();
    mounted.page = pageAnswer([['n1', '1', '1', 'note1']]);
    await expandAndOpen(mounted);
    await edit(mounted, 0, 1, 'pending');
    mounted.holdSend = true;
    mounted.sendAnswer = { applied: true, output: { outcome: 'saved', results: [{ index: 0, outcome: 'saved', rowCount: 1 }], saved: 1, failed: 0 } };
    await click(mounted, el(mounted.host, 'save'));
    await proceed(mounted);
    expect(el(mounted.host, 'add-row').getAttribute('aria-disabled')).toBe('true');
    mounted.fixture.destroy();
    for (const release of mounted.heldSends.splice(0)) release();
    await new Promise((resolve) => setTimeout(resolve, 20));
    const again = TestBed.createComponent(DataBrowserPage);
    document.body.appendChild(again.nativeElement);
    planted.push(again.nativeElement);
    await settle(again);
    expect(el(again.nativeElement as HTMLElement, 'heading').textContent?.trim()).toBe('OcuProbe197.Plain');
    expect(el(again.nativeElement as HTMLElement, 'add-row').getAttribute('aria-disabled')).toBe('false');
  });

  // AC6, AC11.
  it('staged rows survive paging and Refresh, shown on the row with the same key; FormDirty reads dirty meanwhile', async () => {
    const mounted = await mount();
    const rows = Array.from({ length: 100 }, (_, at) => [`n${at + 1}`, String(at + 1), '1', '']);
    mounted.page = pageAnswer(rows, { more: true, total: 250 });
    await expandAndOpen(mounted);
    await edit(mounted, 1, 1, 'second');
    expect(mounted.formDirty.dirty()).toBe(true);
    mounted.page = pageAnswer(rows.slice(0, 50).map((row, at) => [`m${at}`, String(at + 101), '1', '']), { offset: 100, more: true, total: 250 });
    await click(mounted, el(mounted.host, 'next'));
    expect(texts(mounted.host, 'cell')).not.toContain('second');
    mounted.page = pageAnswer([...rows].reverse(), { more: true, total: 250 });
    await click(mounted, el(mounted.host, 'first'));
    const names = texts(mounted.host, 'cell').filter((_, at) => at % 4 === 0);
    expect(names[98]).toBe('second');
    expect(texts(mounted.host, 'status-cell')[98]).toBe(STRINGS.tableChangedTag);
    await click(mounted, el(mounted.host, 'refresh'));
    expect(texts(mounted.host, 'cell').filter((_, at) => at % 4 === 0)[98]).toBe('second');
    expect(el(mounted.host, 'save').textContent?.trim()).toBe('Save changes (1)');
  });

  // AC11, as Story 19.16 changes it: opening another table opens a tab and replaces nothing, so the
  // question moves to closing the tab that holds the staged rows.
  it('opening another table over staged rows opens it in its own tab and asks nothing; closing the staged tab asks Leave without saving?: Cancel keeps it, Confirm drops its rows', async () => {
    const mounted = await mount();
    mounted.page = pageAnswer([['n1', '1', '1', 'note1']]);
    await expandAndOpen(mounted);
    await edit(mounted, 0, 1, 'kept');
    const posts = dataPosts(mounted).length;
    await click(mounted, all(mounted.host, 'tree-object')[1]);
    expect(mounted.host.querySelector('app-dialog')).toBeNull();
    expect(dataPosts(mounted)).toHaveLength(posts + 1);
    expect(dataPosts(mounted).at(-1)?.['table']).toBe('Over30');
    expect(el(mounted.host, 'heading').textContent?.trim()).toBe('OcuProbe197.Over30');
    expect(mounted.formDirty.dirty()).toBe(true);
    await click(mounted, tabNamed(mounted, 'OcuProbe197.Plain, 1 changes waiting to be saved.'));
    expect(dataPosts(mounted)).toHaveLength(posts + 1);
    expect(el(mounted.host, 'save').textContent?.trim()).toBe('Save changes (1)');
    await click(mounted, el(mounted.host, 'close-tab'));
    const leave = mounted.host.querySelector('app-dialog') as HTMLElement;
    expect(leave.textContent).toContain(STRINGS.formLeaveWithoutSaving);
    mounted.formDirty.answer(false);
    await settle(mounted.fixture);
    expect(el(mounted.host, 'heading').textContent?.trim()).toBe('OcuProbe197.Plain');
    expect(el(mounted.host, 'save').textContent?.trim()).toBe('Save changes (1)');
    await click(mounted, el(mounted.host, 'close-tab'));
    await click(mounted, el(mounted.host, 'leave'));
    expect(el(mounted.host, 'heading').textContent?.trim()).toBe('OcuProbe197.Over30');
    expect(all(mounted.host, 'tab')).toHaveLength(1);
    expect(mounted.formDirty.dirty()).toBe(false);
  });

  it('a refused save keeps the staged rows and shows the refusal; Discard drops them and says how many', async () => {
    const mounted = await mount();
    mounted.page = pageAnswer([['n1', '1', '1', 'note1']]);
    await expandAndOpen(mounted);
    await edit(mounted, 0, 1, 'kept');
    mounted.sendAnswer = { applied: false, code: 'EXPLORER.DATA.READONLY', reason: STRINGS.explorerSqlDataReadOnlyReason };
    await click(mounted, el(mounted.host, 'save'));
    await proceed(mounted);
    expect(el(mounted.host, 'refusal').textContent?.trim()).toBe(STRINGS.explorerSqlDataReadOnlyReason);
    expect(el(mounted.host, 'save').textContent?.trim()).toBe('Save changes (1)');
    await click(mounted, el(mounted.host, 'discard'));
    expect(el(mounted.host, 'save').textContent?.trim()).toBe('Save changes (0)');
    expect(el(mounted.host, 'status').textContent?.trim()).toContain('1 changes discarded.');
    expect(texts(mounted.host, 'cell')[0]).toBe('n1');
  });

  // AC11. Mutation (Rule 19): the store's `forget` drops nothing -> the status line never says why the
  // rows went and this goes red.
  it('a namespace switch closes every tab, discards what any staged, and says so once', async () => {
    const mounted = await mount();
    mounted.page = pageAnswer([['n1', '1', '1', 'note1']]);
    await expandAndOpen(mounted);
    await edit(mounted, 0, 1, 'lost');
    await click(mounted, all(mounted.host, 'tree-object')[1]);
    await edit(mounted, 0, 1, 'also lost');
    expect(all(mounted.host, 'tab').map((tab) => tab.getAttribute('aria-label'))).toEqual([
      'OcuProbe197.Plain, 1 changes waiting to be saved.',
      'OcuProbe197.Over30, 1 changes waiting to be saved.',
    ]);
    expect(mounted.formDirty.dirty()).toBe(true);
    mounted.routes.set(SCHEMAS_PATH, [readAnswer([{ Schema: 'OcuProbe197', Tables: true, Views: true, Procedures: false }])]);
    mounted.routes.set(tablesPath('OcuProbe197'), [readAnswer([{ Schema: 'OcuProbe197', Name: 'Plain' }])]);
    mounted.routes.set(viewsPath('OcuProbe197'), [readAnswer([])]);
    await mounted.switchTo('SAMPLES');
    expect(mounted.formDirty.dirty()).toBe(false);
    expect(all(mounted.host, 'tab')).toHaveLength(0);
    expect(el(mounted.host, 'status').textContent?.trim()).toBe(STRINGS.explorerSqlDataScopeDiscarded);
    await expandAndOpen(mounted);
    expect(el(mounted.host, 'save').textContent?.trim()).toBe('Save changes (0)');
    expect(texts(mounted.host, 'cell')[0]).toBe('n1');
  });
});

/** The strip's tab whose accessible name is `name` (Story 19.16). */
function tabNamed(mounted: Mounted, name: string): HTMLElement {
  return all(mounted.host, 'tab').find((tab) => tab.getAttribute('aria-label') === name) as HTMLElement;
}

/** The body cell at grid row `row` and grid column `column` (column 0 is the Change column). */
function cellAt(mounted: Mounted, row: number, column: number): HTMLElement {
  return mounted.host.querySelector(`#ocu-data-cell-r${row}-c${column}`) as HTMLElement;
}

/** Edit grid row `row`'s grid column `column` to `text`: activate it, F2, type, Enter. */
async function edit(mounted: Mounted, row: number, column: number, text: string): Promise<void> {
  await click(mounted, cellAt(mounted, row, column));
  el(mounted.host, 'grid').dispatchEvent(new KeyboardEvent('keydown', { key: 'F2', bubbles: true }));
  await settle(mounted.fixture);
  const editor = el<HTMLInputElement>(mounted.host, 'editor');
  editor.value = text;
  editor.dispatchEvent(new Event('input'));
  editor.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
  await settle(mounted.fixture);
}

/** Press the save dialog's Proceed. */
async function proceed(mounted: Mounted): Promise<void> {
  const dialog = mounted.host.querySelector('app-warning-dialog') as HTMLElement;
  const button = [...dialog.querySelectorAll('button')].find((candidate) => candidate.textContent?.trim() === STRINGS.actionProceed) as HTMLElement;
  button.dispatchEvent(new MouseEvent('click', { bubbles: true }));
  await settle(mounted.fixture);
}
