/**
 * Data browser mounted over stubs of what the instance supplies (Story 19.16's component specs): the
 * SQL schemas, tables and views reads that fill the tree, the screen's own page route -- answered per
 * table, held on demand -- the action handler a save goes through, `FormDirty`, the overlay stack,
 * the navigation map, the screen stores and the scope. The real page, store, tree and grid run.
 *
 * Imported by `data-browser-tabs.page.spec.ts` and `data-browser-export.page.spec.ts` only; nothing
 * reachable from `src/main.ts` imports this directory (`ui/tools/client-lint.mjs`).
 */

import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';

import { DataBrowserPage } from '../areas/system-explorer/data-browser.page';
import { DATA_PATH } from '../areas/system-explorer/data-browser.store';
import type { ApiRequestInit, JsonResult } from '../core/api';
import { ApiService } from '../core/api';
import { FormDirty } from '../core/form-dirty';
import { NavigationService } from '../core/navigation';
import { OverlayStack } from '../core/overlay-stack';
import { ScopeService } from '../core/scope';
import { ScreenStores } from '../core/screen-store';
import { SCREENS, type ScreenDeclaration } from '../core/screens.generated';
import { ScreenActionHandler, type ActionRefusal, type ActionSink, type ActionValues } from '../shell/screen-action-handler';
import { stubAccountPreferences } from './account-preferences';

export const DATA_BROWSER_SCREEN = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.ExplorerSqlData') as ScreenDeclaration;

/** The probe schema the tree lists, whose tables and view open in tabs. */
export const SCHEMA = 'OcuProbe198';

export const SCHEMAS_PATH = '/api/ocupilot/screens/explorer.sqlschemas/read?maxRows=1000&system=no';

export function tablesPath(schema: string): string {
  return `/api/ocupilot/screens/explorer.sqltables/read?maxRows=1000&system=no&schema=${encodeURIComponent(schema)}`;
}

export function viewsPath(schema: string): string {
  return `/api/ocupilot/screens/explorer.sqlviews/read?maxRows=1000&system=no&schema=${encodeURIComponent(schema)}`;
}

/** One answer of a stubbed route: a body, or a refusal envelope. */
export type Answer = { readonly ok: unknown } | { readonly status: number; readonly code: string; readonly reason: string; readonly detail?: Record<string, unknown> };

export interface Request {
  readonly path: string;
  readonly body: Record<string, unknown> | null;
  readonly scope: string | null | undefined;
}

export interface Send {
  readonly actionId: string;
  readonly target: string;
  readonly values: ActionValues | undefined;
  readonly scope: string | undefined;
}

export type SendAnswer = { readonly applied: true; readonly output: unknown } | { readonly applied: false; readonly code: string; readonly reason: string };

/** The editable table's columns: a key, text, a whole number, BIT and a stream. */
export const COLUMNS = [
  { name: 'Code', type: 'varchar', kind: 'text', nullable: false, key: true },
  { name: 'Name', type: 'varchar', kind: 'text', nullable: true, key: false },
  { name: 'Num', type: 'integer', kind: 'number', nullable: true, key: false },
  { name: 'Flag', type: 'bit', kind: 'boolean', nullable: true, key: false },
  { name: 'Memo', type: 'longvarchar', kind: 'stream', nullable: true, key: false },
];

/** A page of `table` holding `rows`, its total the row count unless `extra` says otherwise. */
export function pageAnswer(table: string, rows: (string | null)[][], extra: Record<string, unknown> = {}): Answer {
  return {
    ok: {
      outcome: 'rows',
      table: { schema: SCHEMA, name: table, type: 'table' },
      columns: COLUMNS,
      key: ['Code'],
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

/** `count` rows whose Code is `<prefix><n>`, numbered from `from`. */
export function rowsOf(prefix: string, count: number, from = 1): (string | null)[][] {
  return Array.from({ length: count }, (_, at) => [`${prefix}${from + at}`, `name${from + at}`, String(from + at), '1', 'memo']);
}

export function readAnswer(rows: unknown[], truncated = false): Answer {
  return { ok: { fields: [], rows, truncated, banner: '', bannerRequires: '' } };
}

export interface MountOptions {
  /** The tables the probe schema lists, in tree order; `Edit` and `Pair` by default. */
  readonly tables?: readonly string[];
}

export interface Mounted {
  readonly fixture: ComponentFixture<DataBrowserPage>;
  readonly host: HTMLElement;
  readonly requests: Request[];
  /** Each table's page, by name; a data post for a table with none answers `page`. */
  readonly pages: Map<string, Answer>;
  page: Answer;
  /** While set, each data post waits in `held`, by table, until the test answers it. */
  hold: boolean;
  readonly held: { readonly table: string; readonly answer: (answer: Answer) => void }[];
  readonly sends: Send[];
  sendAnswer: SendAnswer;
  readonly formDirty: FormDirty;
  readonly overlays: OverlayStack;
  readonly routes: Map<string, Answer[]>;
  /** Resolve the scope to `namespace` and tell its subscribers, as a namespace switch does. */
  switchTo(namespace: string): Promise<void>;
}

const planted: HTMLElement[] = [];

/** Remove every page a spec mounted. */
export function unmountAll(): void {
  for (const node of planted.splice(0)) node.remove();
}

/** Let reads, renders and `afterNextRender` callbacks settle. */
export async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

export async function mountDataBrowser(options: MountOptions = {}): Promise<Mounted> {
  TestBed.resetTestingModule();
  const scope = { namespace: 'USER', listeners: new Set<() => void>() };
  const tables = options.tables ?? ['Edit', 'Pair'];
  const mounted = {
    requests: [] as Request[],
    pages: new Map<string, Answer>(),
    page: pageAnswer('Edit', []),
    hold: false,
    held: [] as { table: string; answer: (answer: Answer) => void }[],
    sends: [] as Send[],
    sendAnswer: { applied: true, output: null } as SendAnswer,
    formDirty: new FormDirty(),
    overlays: new OverlayStack(),
    routes: new Map<string, Answer[]>(),
  };
  let lastRefusal: ActionRefusal | null = null;
  let lastOutput: unknown = null;
  const handler = {
    sendFor: async (_descriptor: string, actionId: string, target: string, values?: ActionValues, sink?: ActionSink, sendScope?: string) => {
      mounted.sends.push({ actionId, target, values, scope: sendScope });
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
  mounted.routes.set(SCHEMAS_PATH, [readAnswer([{ Schema: SCHEMA, Tables: true, Views: true, Procedures: false }])]);
  mounted.routes.set(tablesPath(SCHEMA), [readAnswer(tables.map((name) => ({ Schema: SCHEMA, Name: name })))]);
  mounted.routes.set(viewsPath(SCHEMA), [readAnswer([{ Schema: SCHEMA, Name: 'EditView' }])]);
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const body = init.body === undefined ? null : (JSON.parse(init.body) as Record<string, unknown>);
      mounted.requests.push({ path, body, scope: init.scope });
      const table = String(body?.['table'] ?? '');
      let answer: Answer;
      if (path === DATA_PATH && mounted.hold) answer = await new Promise<Answer>((resolve) => mounted.held.push({ table, answer: resolve }));
      else if (path === DATA_PATH) answer = mounted.pages.get(table) ?? mounted.page;
      else answer = mounted.routes.get(path)?.shift() ?? { status: 404, code: 'ROUTE.NOTFOUND', reason: 'no route' };
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
      { provide: OverlayStack, useValue: mounted.overlays },
      { provide: NavigationService, useValue: { screenForUrl: () => DATA_BROWSER_SCREEN } as unknown as NavigationService },
      { provide: ScreenStores, useValue: new ScreenStores({ account: stubAccountPreferences() }) },
      {
        provide: ScopeService,
        useValue: {
          loaded: () => true,
          namespace: () => scope.namespace,
          subscribe: (listener: () => void) => {
            scope.listeners.add(listener);
            return () => scope.listeners.delete(listener);
          },
        } as unknown as ScopeService,
      },
    ],
  });
  await TestBed.inject(Router).navigateByUrl(`/${DATA_BROWSER_SCREEN.route}?ns=USER`);
  const fixture = TestBed.createComponent(DataBrowserPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  const switchTo = async (namespace: string): Promise<void> => {
    scope.namespace = namespace;
    for (const listener of [...scope.listeners]) listener();
    await settle(fixture);
  };
  return Object.assign(mounted, { fixture, host: fixture.nativeElement as HTMLElement, switchTo }) as Mounted;
}

/** Mount a second page into the same testing module, as a return to the route does. */
export async function mountAgain(): Promise<{ readonly fixture: ComponentFixture<DataBrowserPage>; readonly host: HTMLElement }> {
  const fixture = TestBed.createComponent(DataBrowserPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, host: fixture.nativeElement as HTMLElement };
}

export function el<T extends HTMLElement>(host: ParentNode, slot: string): T {
  return host.querySelector(`[data-ocu-data="${slot}"]`) as T;
}

export function all(host: ParentNode, slot: string): HTMLElement[] {
  return [...host.querySelectorAll<HTMLElement>(`[data-ocu-data="${slot}"]`)];
}

export function texts(host: ParentNode, slot: string): string[] {
  return all(host, slot).map((node) => node.textContent?.replace(/\s+/g, ' ').trim() ?? '');
}

export function dataPosts(mounted: Mounted): Record<string, unknown>[] {
  return mounted.requests.filter((request) => request.path === DATA_PATH).map((request) => request.body ?? {});
}

export async function click(mounted: Mounted, node: HTMLElement): Promise<void> {
  node.click();
  await settle(mounted.fixture);
}

/** Expand the probe schema in the tree, once. */
export async function expand(mounted: Mounted): Promise<void> {
  if (all(mounted.host, 'tree-object').length === 0) await click(mounted, all(mounted.host, 'tree-schema')[0]);
}

/** Open the table or view named `name` from the tree. */
export async function openFromTree(mounted: Mounted, name: string): Promise<void> {
  await expand(mounted);
  const node = all(mounted.host, 'tree-object').find((candidate) => candidate.querySelector('.ocu-data-browser-tree-name')?.textContent?.trim() === name);
  if (node === undefined) throw new Error(`the tree lists no ${name}`);
  await click(mounted, node);
}

/** The strip's tab for `label`, `<schema>.<table>`. */
export function tabFor(host: ParentNode, label: string): HTMLElement {
  return all(host, 'tab').find((tab) => tab.querySelector('.ocu-data-browser-tab-label')?.textContent?.trim() === label) as HTMLElement;
}

/** Dispatch a keydown on `target` and let it settle; the event, to read whether it was kept from the browser. */
export async function press(mounted: Mounted, target: HTMLElement, init: KeyboardEventInit): Promise<KeyboardEvent> {
  const event = new KeyboardEvent('keydown', { bubbles: true, cancelable: true, ...init });
  target.dispatchEvent(event);
  await settle(mounted.fixture);
  return event;
}

/** The body cell at grid row `row` and grid column `column` (column 0 is the Change column). */
export function cellAt(host: ParentNode, row: number, column: number): HTMLElement {
  return host.querySelector(`#ocu-data-cell-r${row}-c${column}`) as HTMLElement;
}

/** Edit grid row `row`'s grid column `column` to `text`: activate it, F2, type, Enter. */
export async function edit(mounted: Mounted, row: number, column: number, text: string): Promise<void> {
  await click(mounted, cellAt(mounted.host, row, column));
  el(mounted.host, 'grid').dispatchEvent(new KeyboardEvent('keydown', { key: 'F2', bubbles: true }));
  await settle(mounted.fixture);
  const editor = el<HTMLInputElement>(mounted.host, 'editor');
  editor.value = text;
  editor.dispatchEvent(new Event('input'));
  editor.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
  await settle(mounted.fixture);
}
