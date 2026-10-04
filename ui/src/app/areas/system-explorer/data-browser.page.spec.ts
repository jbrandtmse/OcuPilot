import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { NavigationService } from '../../core/navigation';
import { ScopeService } from '../../core/scope';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS, type ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { ARCHETYPE_PAGES, DESCRIPTOR_PAGES, resolveScreenPage } from '../../shell/screen-outlet';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { DataBrowserPage } from './data-browser.page';
import { DATA_PATH } from './data-browser.store';

/**
 * Data browser over stubs of what the instance supplies -- the SQL schemas, tables and views reads
 * that fill the tree and the screen's own page route (Story 19.7). The real store, tree, grid and
 * template run, so the assertions are about rendered DOM: the schemas holding a table or a view, a
 * schema expanding to its tables then its views, a view marked, the empty and cut lines, a table
 * opening to its first page posted in scope, the status line with and without a total, Last drawn
 * unavailable while the total is unknown, the paging buttons, the Page field and Rows per page each
 * posting their offset, a stopped page and an SQL error, a refusal as an alert, and no page entering
 * the screen's store.
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

async function mount(): Promise<Mounted> {
  TestBed.resetTestingModule();
  const stores = new ScreenStores({ account: stubAccountPreferences() });
  const mounted = {
    requests: [] as Request[],
    routes: new Map<string, Answer[]>(),
    page: pageAnswer([]),
    hold: false,
    held: [] as ((answer: Answer) => void)[],
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
      { provide: NavigationService, useValue: { screenForUrl: () => SCREEN } as unknown as NavigationService },
      { provide: ScreenStores, useValue: stores },
      { provide: ScopeService, useValue: { loaded: () => true, namespace: () => 'USER', subscribe: () => () => undefined } as unknown as ScopeService },
    ],
  });
  await TestBed.inject(Router).navigateByUrl(`/${SCREEN.route}?ns=USER`);
  const fixture = TestBed.createComponent(DataBrowserPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return Object.assign(mounted, { fixture, host: fixture.nativeElement as HTMLElement, stores }) as Mounted;
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

  // Mutation (Rule 19): drop the generation check in `DataBrowserState.read` -> the older answer lands
  // last and this goes red.
  it('an answer to an older request is dropped, so a slow first table never replaces the second', async () => {
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
});
