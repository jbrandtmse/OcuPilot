/**
 * System Explorer's Data browser state (AD-19, Story 19.7): the schema tree, the open table or view,
 * its applied filters and their drafts, the sort, the offset and page size, the instance's last
 * answer, the refusal on screen and the last announcement.
 *
 * **Framework-free.** It imports nothing from Angular; `data-browser.page.ts` holds one per screen
 * store and hands it what it needs as plain functions, so the component specs drive it directly.
 *
 * **The tree reads three other screens' declared reads** (AD-5): SQL schemas', with `system=no`,
 * once, and SQL tables' and SQL views', with `system=no` and the schema, when a schema expands --
 * each under its own screen's gate and cap. **A page is posted to the screen's own route**,
 * `POST /explorer/sql/data`, scoped to the namespace; a request generation drops an older answer.
 *
 * **The answer is screen-only** (AD-36, AD-39's sixth exception): rows, an SQLCODE and its message
 * live in this state and are rendered as text; none of it enters the screen's store, so none of it
 * reaches screen context.
 */

import type { ApiService, JsonResult } from '../../core/api';
import {
  DEFAULT_PAGE_SIZE,
  PAGE_SIZES,
  lastOffset,
  nextOffset,
  nextSort,
  previousOffset,
  sortLine,
  type DataKind,
  type SortState,
} from '../../core/data-browser-model';
import { createScreenRead } from '../../core/screen-read';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { refusalText } from './sql-query.store';

/** The screen's own route. */
export const DATA_PATH = '/api/ocupilot/explorer/sql/data';

/** The rows each tree read asks for: the read cap's ceiling. */
export const TREE_MAX_ROWS = 1000;

/** A table or a view the tree lists under its schema. */
export interface TreeObject {
  readonly schema: string;
  readonly name: string;
  readonly view: boolean;
}

/** A schema node: its tables then views once read, or `null` before; whether a read was cut. */
export interface TreeSchema {
  readonly name: string;
  readonly expanded: boolean;
  readonly loading: boolean;
  readonly objects: readonly TreeObject[] | null;
  readonly truncated: boolean;
  readonly fault: string;
}

/** A column as the instance answers it. */
export interface BrowseColumn {
  readonly name: string;
  readonly type: string;
  readonly kind: DataKind;
  readonly nullable: boolean;
  readonly key: boolean;
}

/** The table or view an answer is about. */
export interface BrowseTable {
  readonly schema: string;
  readonly name: string;
  readonly type: string;
}

interface AnswerFrame {
  readonly table: BrowseTable;
  readonly columns: readonly BrowseColumn[];
  readonly key: readonly string[];
}

/** What the instance last answered for the open table or view. */
export type BrowseAnswer =
  | (AnswerFrame & {
      readonly outcome: 'rows';
      readonly rows: readonly (readonly (string | null)[])[];
      readonly offset: number;
      readonly size: number;
      readonly more: boolean;
      readonly total: number | null;
      readonly truncated: boolean;
    })
  | (AnswerFrame & { readonly outcome: 'stopped'; readonly seconds: number })
  | (AnswerFrame & { readonly outcome: 'error'; readonly sqlcode: number | null; readonly message: string });

/** What the state reads and posts through, and the namespace it is scoped to. */
export interface DataBrowserDeps {
  readonly api: Pick<ApiService, 'requestJson'>;
  readonly scope: () => string;
  /** The SQL schemas, SQL tables and SQL views screens, whose declared reads fill the tree. */
  readonly schemas: ScreenDeclaration | null;
  readonly tables: ScreenDeclaration | null;
  readonly views: ScreenDeclaration | null;
}

const KINDS: ReadonlySet<string> = new Set(['number', 'boolean', 'date', 'time', 'timestamp', 'stream', 'binary', 'text']);

function text(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

/** Whether a catalog read's flag field reads set. */
export function flagged(value: unknown): boolean {
  return value === true || value === 1 || value === '1' || value === 'true';
}

function frameOf(record: Readonly<Record<string, unknown>>): AnswerFrame {
  const table = record['table'] !== null && typeof record['table'] === 'object' ? (record['table'] as Readonly<Record<string, unknown>>) : {};
  const columns = Array.isArray(record['columns']) ? record['columns'] : [];
  return {
    table: { schema: text(table['schema']), name: text(table['name']), type: text(table['type']) },
    columns: columns
      .filter((column): column is Readonly<Record<string, unknown>> => column !== null && typeof column === 'object')
      .map((column) => ({
        name: text(column['name']),
        type: text(column['type']),
        kind: (KINDS.has(text(column['kind'])) ? text(column['kind']) : 'text') as DataKind,
        nullable: column['nullable'] === true,
        key: column['key'] === true,
      })),
    key: Array.isArray(record['key']) ? record['key'].filter((name): name is string => typeof name === 'string') : [],
  };
}

/** One answer of the route, or `null` for any other shape. */
export function answerOf(body: unknown): BrowseAnswer | null {
  if (body === null || typeof body !== 'object') return null;
  const record = body as Readonly<Record<string, unknown>>;
  const frame = frameOf(record);
  switch (record['outcome']) {
    case 'rows': {
      if (!Array.isArray(record['rows'])) return null;
      const rows = record['rows'].map((row) =>
        Array.isArray(row) ? row.map((cell) => (cell === null ? null : typeof cell === 'string' ? cell : String(cell))) : []
      );
      return {
        ...frame,
        outcome: 'rows',
        rows,
        offset: typeof record['offset'] === 'number' ? record['offset'] : 0,
        size: typeof record['size'] === 'number' ? record['size'] : DEFAULT_PAGE_SIZE,
        more: record['more'] === true,
        total: typeof record['total'] === 'number' ? record['total'] : null,
        truncated: record['truncated'] === true,
      };
    }
    case 'stopped':
      return { ...frame, outcome: 'stopped', seconds: typeof record['seconds'] === 'number' ? record['seconds'] : 0 };
    case 'error':
      return { ...frame, outcome: 'error', sqlcode: typeof record['sqlcode'] === 'number' ? record['sqlcode'] : null, message: text(record['message']) };
    default:
      return null;
  }
}

/** The tree objects of a SQL tables or SQL views read's rows, marked as views when `view`. */
function objectsOf(rows: readonly unknown[], view: boolean): TreeObject[] {
  return rows
    .filter((row): row is Readonly<Record<string, unknown>> => row !== null && typeof row === 'object')
    .map((row) => ({ schema: text(row['Schema']), name: text(row['Name']), view }))
    .filter((object) => object.schema !== '' && object.name !== '');
}

export class DataBrowserState {
  private schemasValue: readonly TreeSchema[] | null = null;

  private schemasLoadingValue = false;

  private schemasTruncatedValue = false;

  private schemasFaultValue = '';

  private openValue: TreeObject | null = null;

  private filtersValue: Readonly<Record<string, string>> = {};

  private draftsValue: Readonly<Record<string, string>> = {};

  private sortValue: SortState | null = null;

  private offsetValue = 0;

  private sizeValue = DEFAULT_PAGE_SIZE;

  private answerValue: BrowseAnswer | null = null;

  private loadingValue = false;

  private refusalValue = '';

  private announcementValue = '';

  /** Which page request is current; an answer to an older one is dropped. */
  private generation = 0;

  private readonly listeners = new Set<() => void>();

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  schemas(): readonly TreeSchema[] | null {
    return this.schemasValue;
  }

  schemasLoading(): boolean {
    return this.schemasLoadingValue;
  }

  schemasTruncated(): boolean {
    return this.schemasTruncatedValue;
  }

  schemasFault(): string {
    return this.schemasFaultValue;
  }

  /** The table or view open in the grid, or `null`. */
  open(): TreeObject | null {
    return this.openValue;
  }

  filters(): Readonly<Record<string, string>> {
    return this.filtersValue;
  }

  drafts(): Readonly<Record<string, string>> {
    return this.draftsValue;
  }

  sort(): SortState | null {
    return this.sortValue;
  }

  offset(): number {
    return this.offsetValue;
  }

  size(): number {
    return this.sizeValue;
  }

  answer(): BrowseAnswer | null {
    return this.answerValue;
  }

  loading(): boolean {
    return this.loadingValue;
  }

  refusal(): string {
    return this.refusalValue;
  }

  /** The last sort announcement, read by the page's polite status line. */
  announcement(): string {
    return this.announcementValue;
  }

  /** Read the schemas holding a table or a view, once; a later call keeps what was read. */
  async loadSchemas(deps: DataBrowserDeps): Promise<void> {
    if (this.schemasValue !== null || this.schemasLoadingValue || deps.schemas === null) return;
    this.schemasLoadingValue = true;
    this.notify();
    const read = createScreenRead(deps.api, deps.schemas, () => ({ system: 'no' }));
    const result = await read({ maxRows: TREE_MAX_ROWS });
    this.schemasLoadingValue = false;
    if (result.kind !== 'ok') {
      this.schemasFaultValue = STRINGS.connectivityRequestRefused;
      this.notify();
      return;
    }
    this.schemasFaultValue = '';
    this.schemasTruncatedValue = result.truncated;
    this.schemasValue = result.rows
      .filter((row): row is Readonly<Record<string, unknown>> => row !== null && typeof row === 'object')
      .filter((row) => flagged(row['Tables']) || flagged(row['Views']))
      .map((row) => ({ name: text(row['Schema']), expanded: false, loading: false, objects: null, truncated: false, fault: '' }))
      .filter((schema) => schema.name !== '');
    this.notify();
  }

  /** Expand `name`, reading its tables and then its views the first time, or collapse it. */
  async toggle(deps: DataBrowserDeps, name: string): Promise<void> {
    const node = this.schemasValue?.find((schema) => schema.name === name);
    if (node === undefined) return;
    if (node.expanded) {
      this.replace(name, { expanded: false });
      return;
    }
    if (node.objects !== null || node.loading) {
      this.replace(name, { expanded: true });
      return;
    }
    this.replace(name, { expanded: true, loading: true });
    const criteria = (): Readonly<Record<string, string>> => ({ system: 'no', schema: name });
    const objects: TreeObject[] = [];
    let truncated = false;
    let fault = '';
    for (const [declaration, view] of [
      [deps.tables, false],
      [deps.views, true],
    ] as const) {
      if (declaration === null) continue;
      const result = await createScreenRead(deps.api, declaration, criteria)({ maxRows: TREE_MAX_ROWS });
      if (result.kind !== 'ok') {
        fault = STRINGS.connectivityRequestRefused;
        continue;
      }
      truncated = truncated || result.truncated;
      objects.push(...objectsOf(result.rows, view));
    }
    this.replace(name, { loading: false, objects, truncated, fault });
  }

  /** Open `object`: its filters, sort and offset start over, the page size is kept, and its first page is read. */
  async openObject(deps: DataBrowserDeps, object: TreeObject): Promise<void> {
    this.openValue = object;
    this.filtersValue = {};
    this.draftsValue = {};
    this.sortValue = null;
    this.offsetValue = 0;
    this.answerValue = null;
    await this.read(deps);
  }

  /** Read the page on screen again. */
  async refresh(deps: DataBrowserDeps): Promise<void> {
    await this.read(deps);
  }

  /** What a column's filter input holds, applied or not. */
  setDraft(column: string, value: string): void {
    this.draftsValue = { ...this.draftsValue, [column]: value };
    this.notify();
  }

  /** Apply `column`'s typed filter -- an empty one removes it -- and return to the first page. */
  async applyFilter(deps: DataBrowserDeps, column: string): Promise<void> {
    const value = (this.draftsValue[column] ?? '').trim();
    const filters: Record<string, string> = { ...this.filtersValue };
    if (value === '') delete filters[column];
    else filters[column] = value;
    this.filtersValue = filters;
    this.draftsValue = { ...this.draftsValue, [column]: value };
    this.offsetValue = 0;
    await this.read(deps);
  }

  /** Clear `column`'s filter and apply, returning to the first page. */
  async clearFilter(deps: DataBrowserDeps, column: string): Promise<void> {
    const filters: Record<string, string> = { ...this.filtersValue };
    delete filters[column];
    this.filtersValue = filters;
    this.draftsValue = { ...this.draftsValue, [column]: '' };
    this.offsetValue = 0;
    await this.read(deps);
  }

  /** Clear every filter and return to the first page. */
  async clearFilters(deps: DataBrowserDeps): Promise<void> {
    this.filtersValue = {};
    this.draftsValue = {};
    this.offsetValue = 0;
    await this.read(deps);
  }

  /** A header for `column` was activated: the sort cycles, is announced, and the first page is read. */
  async cycleSort(deps: DataBrowserDeps, column: string): Promise<void> {
    this.sortValue = nextSort(this.sortValue, column);
    this.offsetValue = 0;
    await this.read(deps, sortLine(this.sortValue));
  }

  async firstPage(deps: DataBrowserDeps): Promise<void> {
    await this.goTo(deps, 0);
  }

  async previousPage(deps: DataBrowserDeps): Promise<void> {
    if (this.offsetValue === 0) return;
    await this.goTo(deps, previousOffset(this.offsetValue, this.sizeValue));
  }

  /** The next page, past the rows the last page kept, while the instance says more exist. */
  async nextPage(deps: DataBrowserDeps): Promise<void> {
    const answer = this.answerValue;
    if (answer === null || answer.outcome !== 'rows' || !answer.more) return;
    await this.goTo(deps, nextOffset(answer.offset, answer.rows.length));
  }

  /** The last page, only while the total is known. */
  async lastPage(deps: DataBrowserDeps): Promise<void> {
    const answer = this.answerValue;
    const last = answer !== null && answer.outcome === 'rows' ? lastOffset(answer.total, this.sizeValue) : null;
    if (last === null) return;
    await this.goTo(deps, last);
  }

  /** Go to the page starting at `offset`. */
  async goTo(deps: DataBrowserDeps, offset: number): Promise<void> {
    this.offsetValue = Math.max(0, offset);
    await this.read(deps);
  }

  /** Rows per page: one of the four sizes, returning to the first page. */
  async setSize(deps: DataBrowserDeps, size: number): Promise<void> {
    if (!PAGE_SIZES.includes(size)) return;
    this.sizeValue = size;
    this.offsetValue = 0;
    await this.read(deps);
  }

  /** The request a page posts: the open object, its applied filters, its sort, the offset and the size. */
  private body(): string {
    const open = this.openValue as TreeObject;
    const body: Record<string, unknown> = {
      schema: open.schema,
      table: open.name,
      filters: this.filtersValue,
      sort: this.sortValue,
      offset: this.offsetValue,
      size: this.sizeValue,
    };
    return JSON.stringify(body);
  }

  /** Post the page, `announcement` the line its status reads first; a refusal keeps the open object and shows its sentence. */
  private async read(deps: DataBrowserDeps, announcement = ''): Promise<void> {
    if (this.openValue === null) return;
    const generation = ++this.generation;
    this.loadingValue = true;
    this.refusalValue = '';
    this.announcementValue = announcement;
    this.notify();
    const result: JsonResult<unknown> = await deps.api.requestJson<unknown>(DATA_PATH, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: this.body(),
      scope: deps.scope(),
    });
    if (generation !== this.generation) return;
    this.loadingValue = false;
    if (result.kind !== 'ok') {
      this.answerValue = null;
      this.refusalValue =
        (result.kind === 'error' ? refusalText(result.code, result.reason, result.detail) : '') || STRINGS.connectivityRequestRefused;
      this.notify();
      return;
    }
    this.answerValue = answerOf(result.body);
    this.notify();
  }

  /** Replace schema `name`'s node with `change` applied. */
  private replace(name: string, change: Partial<TreeSchema>): void {
    this.schemasValue = (this.schemasValue ?? []).map((schema) => (schema.name === name ? { ...schema, ...change } : schema));
    this.notify();
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
