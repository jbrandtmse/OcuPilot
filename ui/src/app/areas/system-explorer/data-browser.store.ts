/**
 * System Explorer's Data browser state (AD-19, Story 19.7): the schema tree, the namespace it was read
 * in, and the open tables, each in a tab (Story 19.16) holding its own open table or view, applied
 * filters and their drafts, sort, offset and page size, the instance's last answer, the refusal on
 * screen, the last announcement, its staged changes and its active cell.
 *
 * **Framework-free.** It imports nothing from Angular; `data-browser.page.ts` holds one per screen
 * store and hands it what it needs as plain functions, so the component specs drive it directly.
 *
 * **The tree reads three other screens' declared reads** (AD-5): SQL schemas', with `system=no`,
 * once per namespace, and SQL tables' and SQL views', with `system=no` and the schema, when a schema
 * expands -- each under its own screen's gate and cap. **A page is posted to the screen's own route**,
 * `POST /explorer/sql/data`, scoped to the namespace; a tab's request generation drops an older
 * answer, and an answer for a tab, shown or not, changes only that tab and nothing once it is closed.
 * **A namespace switch forgets everything read in the old one** and closes every tab (AD-44,
 * `scopeTo`).
 *
 * **The answer is screen-only** (AD-36, AD-39's sixth exception): rows, an SQLCODE and its message
 * live in this state and are rendered as text; none of it enters the screen's store, so none of it
 * reaches screen context. A tab's page saved as CSV (`exportPage`) is built from the answer the tab
 * already holds and issues no request.
 *
 * **Edits are staged per tab** (Story 19.8): each tab's `StagedChanges`, keyed by each row's key,
 * survives paging, sorting, filtering, Refresh and a switch to another tab, and goes when that tab
 * closes or the namespace changes, which says so. `FormDirty` reads dirty while any tab holds a
 * staged row. A save is the screen action `save` of `explorer.sqldata.save` for the selected tab's
 * table, sent through the action handler (AD-53); its answer is applied by key and the page is read
 * again.
 *
 * The members the page reads keep their Story 19.7 and 19.8 names and answer for the selected tab.
 */

import type { ApiService, JsonResult } from '../../core/api';
import { csvFileName } from '../../core/csv';
import {
  DEFAULT_PAGE_SIZE,
  MAX_TABS,
  PAGE_SIZES,
  StagedChanges,
  discardedText,
  filterValue,
  goToRow,
  isCut,
  lastOffset,
  nextOffset,
  nextSort,
  pageCsvText,
  previousOffset,
  rowKey,
  rowRangeMax,
  savedSummaryText,
  sortLine,
  type DataKind,
  type NewRow,
  type OverlayRow,
  type RowOutcome,
  type SaveResult,
  type SortState,
  waitingText,
} from '../../core/data-browser-model';
import type { FormDirty } from '../../core/form-dirty';
import { createScreenRead } from '../../core/screen-read';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { groupDigits } from '../../core/table-model';
import type { ActionSink, ActionValues } from '../../shell/screen-action-handler';
import { fillPlaceholders } from './code-list.store';
import { refusalText, type RunSender } from './sql-query.store';

/** The screen's own route. */
export const DATA_PATH = '/api/ocupilot/explorer/sql/data';

/** The rows each tree read asks for: the read cap's ceiling. */
export const TREE_MAX_ROWS = 1000;

/** The screen action a save sends, its one target, and its three values (Story 19.8). */
export const SAVE_ACTION = 'save';
export const SAVE_TARGET = 'sql';
export const SCHEMA_VALUE = 'schema';
export const TABLE_VALUE = 'table';
export const CHANGES_VALUE = 'changes';

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

/** A column as the instance answers it, with whether it is an identity or a generated column. */
export interface BrowseColumn {
  readonly name: string;
  readonly type: string;
  readonly kind: DataKind;
  readonly nullable: boolean;
  readonly key: boolean;
  readonly identity?: boolean;
  readonly generated?: boolean;
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
  /** Whether the key names one row each: `false` for a column merely named ID, which orders a page but may repeat. */
  readonly keyUnique: boolean;
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
      /** The cells the instance cut, as `[row, column]` pairs. */
      readonly cuts: readonly (readonly number[])[];
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
  /** What a save is sent through (Story 19.8), and the screen it is sent for. */
  readonly sender: RunSender;
  readonly descriptor: string;
  /** Marked dirty while any tab holds a staged row, so leaving the route asks first. */
  readonly formDirty: Pick<FormDirty, 'setDirty'>;
}

/** A row of the grid as staged: a page row with its staged values shown, or a new row. */
export interface StagedRow {
  /** `p<index>` for the page's row at that index, or a new row's id. */
  readonly id: string;
  /** The row's identity, which a re-read keeps: a page row's key values, or a new row's id. */
  readonly key: string;
  /** The page row's index, or `null` for a new row. */
  readonly page: number | null;
  readonly cells: readonly (string | null)[];
  readonly staged: readonly boolean[];
  /** Whether each cell is one the instance cut. */
  readonly cut: readonly boolean[];
  readonly deleted: boolean;
  readonly isNew: boolean;
  /** What the row's Change cell reads, or `''`. */
  readonly status: string;
}

/** A tab's active cell: the grid row's id (`null` on the header row) and the data column (-1 the Change column). */
export interface ActiveCell {
  readonly row: string | null;
  readonly column: number;
}

/** One tab of the strip as the page draws it: its id, its `<schema>.<table>`, how many rows it holds staged, and whether it is selected. */
export interface TabView {
  readonly id: string;
  readonly label: string;
  readonly staged: number;
  readonly active: boolean;
}

/** The page on screen as a CSV file: its text, its name, and the first and last row numbers it holds. */
export interface PageExport {
  readonly text: string;
  readonly fileName: string;
  readonly first: number;
  readonly last: number;
}

/** What Go to row answers: the page row index to make active, the sentence a number outside the range reads, or `null` when no row is there to make active. */
export type RowJump = { readonly index: number } | { readonly problem: string } | null;

/** The Change cell's words for a kept outcome; `seconds` is the bound a stopped row ran out of. */
export function outcomeText(outcome: RowOutcome, sqlcode: number | null, message: string, seconds?: number): string {
  switch (outcome) {
    case 'saved':
      return STRINGS.formSaved;
    case 'changed':
      return STRINGS.explorerSqlDataOutcomeChanged;
    case 'gone':
      return STRINGS.explorerSqlDataOutcomeGone;
    case 'refused':
      return STRINGS.explorerSqlDataOutcomeRefused;
    case 'stopped':
      return typeof seconds === 'number' ? fillPlaceholders(STRINGS.explorerSqlStopped, { s: seconds }) : STRINGS.explorerSqlDataOutcomeSkipped;
    case 'skipped':
      return STRINGS.explorerSqlDataOutcomeSkipped;
    default: {
      const code = sqlcode === null ? '' : fillPlaceholders(STRINGS.explorerSqlCode, { code: sqlcode });
      return [code, message].filter((part) => part !== '').join(': ');
    }
  }
}

const OUTCOMES: ReadonlySet<string> = new Set(['saved', 'changed', 'gone', 'refused', 'error', 'stopped', 'skipped']);

/** The per-row results of a save's `output`, or `[]` for any other shape. */
export function resultsOf(output: unknown): SaveResult[] {
  if (output === null || typeof output !== 'object') return [];
  const results = (output as Readonly<Record<string, unknown>>)['results'];
  if (!Array.isArray(results)) return [];
  return results
    .filter((result): result is Readonly<Record<string, unknown>> => result !== null && typeof result === 'object')
    .filter((result) => typeof result['index'] === 'number' && OUTCOMES.has(String(result['outcome'])))
    .map((result) => ({
      index: result['index'] as number,
      outcome: result['outcome'] as RowOutcome,
      sqlcode: typeof result['sqlcode'] === 'number' ? result['sqlcode'] : null,
      message: typeof result['message'] === 'string' ? result['message'] : '',
      ...(typeof result['seconds'] === 'number' ? { seconds: result['seconds'] } : {}),
    }));
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
        identity: column['identity'] === true,
        generated: column['generated'] === true,
      })),
    key: Array.isArray(record['key']) ? record['key'].filter((name): name is string => typeof name === 'string') : [],
    keyUnique: record['keyUnique'] !== false,
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
        cuts: Array.isArray(record['cuts'])
          ? record['cuts'].filter((pair): pair is number[] => Array.isArray(pair) && pair.length === 2 && pair.every((at) => typeof at === 'number'))
          : [],
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

/** Whether `a` and `b` name the same table or view. */
function sameObject(a: TreeObject, b: TreeObject): boolean {
  return a.schema === b.schema && a.name === b.name && a.view === b.view;
}

/** What a tab tells the screen's state: that something it shows changed, and that what it stages changed. */
interface TabHost {
  notify(): void;
  stagingChanged(deps: DataBrowserDeps): void;
}

/**
 * One open table or view (Story 19.16): everything Stories 19.7 and 19.8 kept for the one open table,
 * now one per tab. A read or a save answers only the tab that sent it, whether it is shown or not,
 * and changes nothing once the tab is closed. Framework-free.
 */
export class DataTab {
  private filtersValue: Readonly<Record<string, string>> = {};

  private draftsValue: Readonly<Record<string, string>> = {};

  private sortValue: SortState | null = null;

  private offsetValue = 0;

  private answerValue: BrowseAnswer | null = null;

  private loadingValue = false;

  private refusalValue = '';

  private announcementValue = '';

  /** Which page request is current; an answer to an older one is dropped. */
  private generation = 0;

  /** The rows changed and not saved (Story 19.8). */
  private readonly staged = new StagedChanges();

  /** Which staging is current; a save answering after its staging was dropped is not applied. */
  private stagingGeneration = 0;

  private savingValue = false;

  private closedValue = false;

  private activeCellValue: ActiveCell | null = null;

  constructor(
    readonly id: string,
    readonly object: TreeObject,
    private sizeValue: number,
    private readonly host: TabHost
  ) {}

  /** The tab's name: `<schema>.<table>`. */
  label(): string {
    return `${this.object.schema}.${this.object.name}`;
  }

  closed(): boolean {
    return this.closedValue;
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

  announcement(): string {
    return this.announcementValue;
  }

  /** Put `text` on the tab's status line until the next one. */
  announce(text: string): void {
    this.announcementValue = text;
    this.host.notify();
  }

  saving(): boolean {
    return this.savingValue;
  }

  stagedCount(): number {
    return this.staged.count();
  }

  stagedCounts(): { readonly update: number; readonly insert: number; readonly delete: number } {
    return this.staged.counts();
  }

  /** The cell the grid last made active in this tab, which a switch back restores. */
  activeCell(): ActiveCell | null {
    return this.activeCellValue;
  }

  /** Keep `cell` as the tab's active cell; the page re-renders when its row changed. */
  setActiveCell(cell: ActiveCell): void {
    const before = this.activeCellValue?.row ?? null;
    this.activeCellValue = cell;
    if (before !== cell.row) this.host.notify();
  }

  /** Whether the open table's rows may change here: a table, not a view, whose key this account can list and which names one row each. */
  writable(): boolean {
    const answer = this.answerValue;
    return answer !== null && answer.table.type === 'table' && answer.key.length > 0 && answer.keyUnique;
  }

  /** Whether Download CSV has a page to write: rows answered, at least one, with no read on its way. */
  canExport(): boolean {
    const answer = this.answerValue;
    return !this.loadingValue && answer !== null && answer.outcome === 'rows' && answer.rows.length > 0;
  }

  /** Whether Go to row has a range to go in: rows answered, with no read on its way and a total other than 0. */
  canGoToRow(): boolean {
    const answer = this.answerValue;
    return !this.loadingValue && answer !== null && answer.outcome === 'rows' && answer.total !== 0;
  }

  /**
   * The grid's rows: each new row, the newest first, then the page's rows with their staged values
   * shown, each with the instance's cut cells and what its Change cell reads.
   */
  rows(): readonly StagedRow[] {
    const answer = this.answerValue;
    if (answer === null || answer.outcome !== 'rows') return [];
    const columns = answer.columns;
    const fresh: StagedRow[] = this.writable()
      ? this.staged.newRows().map((row: NewRow) => ({
          id: row.id,
          key: row.id,
          page: null,
          cells: columns.map((column) => (Object.hasOwn(row.values, column.name) ? row.values[column.name] : null)),
          staged: columns.map((column) => Object.hasOwn(row.values, column.name)),
          cut: columns.map(() => false),
          deleted: false,
          isNew: true,
          status: (row.outcome === null ? '' : outcomeText(row.outcome.outcome, row.outcome.sqlcode, row.outcome.message, row.outcome.seconds)) || STRINGS.explorerSqlDataNew,
        }))
      : [];
    const overlaid: OverlayRow[] = this.writable() ? this.staged.overlay(answer.key, columns, answer.rows) : this.staged.overlay([], columns, answer.rows);
    const page: StagedRow[] = overlaid.map((row, index) => ({
      id: `p${index}`,
      key: row.key,
      page: index,
      cells: row.cells,
      staged: row.staged,
      cut: columns.map((_, at) => isCut(answer.cuts, index, at)),
      deleted: row.deleted,
      isNew: false,
      status: row.deleted
        ? STRINGS.explorerSqlDataDeleted
        : row.staged.some((flag) => flag)
          ? STRINGS.tableChangedTag
          : row.outcome !== null
            ? outcomeText(row.outcome.outcome, row.outcome.sqlcode, row.outcome.message, row.outcome.seconds)
            : '',
    }));
    return [...fresh, ...page];
  }

  /**
   * Stage `value` for column `column` of grid row `id`: a new row's cell, or a page row's, compared
   * with the value the page read so the value read unstages it. Refused at the cap, which says so.
   */
  edit(deps: DataBrowserDeps, id: string, column: number, value: string | null): void {
    const answer = this.answerValue;
    if (answer === null || answer.outcome !== 'rows' || !this.writable()) return;
    const name = answer.columns[column]?.name;
    if (name === undefined) return;
    if (!id.startsWith('p')) {
      this.staged.setNew(id, name, value);
      this.afterStaging(deps, true);
      return;
    }
    const target = this.pageRow(id);
    if (target === null) return;
    this.afterStaging(deps, this.staged.stage(target.identity, target.key, name, target.values[name] ?? null, value));
  }

  /** Stage a new, empty row at the top; its id, or `null` at the cap, which says so. */
  addRow(deps: DataBrowserDeps): string | null {
    if (!this.writable()) return null;
    const id = this.staged.addRow();
    this.afterStaging(deps, id !== null);
    return id;
  }

  /** Stage a copy of grid row `id` as a new row, its key, identity, generated, stream, binary and cut cells left out. */
  duplicate(deps: DataBrowserDeps, id: string): string | null {
    const answer = this.answerValue;
    if (answer === null || answer.outcome !== 'rows' || !this.writable()) return null;
    const row = this.rows().find((entry) => entry.id === id);
    if (row === undefined) return null;
    const values: Record<string, string | null> = {};
    answer.columns.forEach((column, at) => (values[column.name] = row.cells[at] ?? null));
    const copy = this.staged.duplicate(answer.columns, values, (name) => row.cut[answer.columns.findIndex((column) => column.name === name)] === true);
    this.afterStaging(deps, copy !== null);
    return copy;
  }

  /** Mark grid row `id` deleted or restore it; a new row is removed instead. */
  toggleDelete(deps: DataBrowserDeps, id: string): void {
    if (!this.writable()) return;
    if (!id.startsWith('p')) {
      this.staged.removeNew(id);
      this.afterStaging(deps, true);
      return;
    }
    const target = this.pageRow(id);
    if (target === null) return;
    this.afterStaging(deps, this.staged.toggleDelete(target.identity, target.key));
  }

  /** Whether grid row `id` is marked deleted. */
  deleted(id: string): boolean {
    const target = id.startsWith('p') ? this.pageRow(id) : null;
    return target !== null && this.staged.isDeleted(target.identity);
  }

  /** Drop every staged row, saying how many; a save still on its way is no longer applied. */
  discard(deps: DataBrowserDeps): void {
    const count = this.staged.discard();
    this.stagingGeneration += 1;
    this.savingValue = false;
    this.host.stagingChanged(deps);
    this.announcementValue = count === 0 ? '' : discardedText(count);
    this.host.notify();
  }

  /**
   * Close the tab: drop what it stages, and let no read or save still on its way change it. Answers
   * how many rows it held staged. The screen's state says what changed.
   */
  close(): number {
    const count = this.staged.discard();
    this.closedValue = true;
    this.generation += 1;
    this.stagingGeneration += 1;
    this.savingValue = false;
    this.loadingValue = false;
    return count;
  }

  /**
   * Save every staged row as one screen action for this tab's table. Applied, the answer marks each
   * row by its key -- a saved row leaves staging, a failed one rolls back -- the status line
   * summarizes, and the page is read again. Refused, nothing is applied, the staged rows stay, and
   * the refusal shows. `false` when nothing was sent or it was refused.
   */
  async save(deps: DataBrowserDeps): Promise<boolean> {
    if (this.closedValue || this.savingValue || !this.writable()) return false;
    const changes = this.staged.toWire();
    if (changes.length === 0) return false;
    const staging = this.stagingGeneration;
    const key = this.answerValue?.key ?? [];
    this.savingValue = true;
    this.refusalValue = '';
    this.host.notify();
    let refused = '';
    const sink: ActionSink = { setRefusal: (reason) => (refused = reason) };
    const values: ActionValues = {
      [SCHEMA_VALUE]: this.object.schema,
      [TABLE_VALUE]: this.object.name,
      [CHANGES_VALUE]: JSON.stringify(changes),
    };
    const applied = await deps.sender.sendFor(deps.descriptor, SAVE_ACTION, SAVE_TARGET, values, sink, deps.scope());
    if (staging !== this.stagingGeneration || this.closedValue) return applied;
    this.savingValue = false;
    if (!applied) {
      const last = deps.sender.lastRefusal();
      this.refusalValue = (last === null ? '' : refusalText(last.code, last.reason, last.detail)) || refused || STRINGS.connectivityRequestRefused;
      this.host.notify();
      return false;
    }
    const results = resultsOf(deps.sender.lastOutput());
    const { saved, failed } = this.staged.applyResults(results, key);
    this.host.stagingChanged(deps);
    await this.read(deps, savedSummaryText(saved, results.length, failed));
    return true;
  }

  /**
   * The page on screen as a CSV file, built from the answer the tab already holds and nothing else:
   * the column names, then each row as the instance read it, cells as the grid shows them, so no
   * staged value and no new row is written. `null` while there is no row to write.
   */
  exportPage(now: Date): PageExport | null {
    const answer = this.answerValue;
    if (!this.canExport() || answer === null || answer.outcome !== 'rows') return null;
    return {
      text: pageCsvText(answer.columns, answer.rows),
      fileName: csvFileName(this.label(), now),
      first: answer.offset + 1,
      last: answer.offset + answer.rows.length,
    };
  }

  /**
   * Go to row number `text`: refused with the range line when it falls outside 1 to the total, or to
   * the furthest row the route reads while the total is unknown; otherwise the page holding it is
   * read, staged changes kept, and its index on that page answered. A page holding no such row says
   * "No row <n> here." and answers `null`, as does a tab closed meanwhile.
   */
  async goToRowNumber(deps: DataBrowserDeps, typed: string): Promise<RowJump> {
    const answer = this.answerValue;
    if (!this.canGoToRow() || answer === null || answer.outcome !== 'rows') return null;
    const hit = goToRow(typed, this.sizeValue, answer.total);
    if (hit === null) return { problem: fillPlaceholders(STRINGS.explorerSqlDataRowRange, { n: groupDigits(rowRangeMax(answer.total, this.sizeValue)) }) };
    await this.goTo(deps, hit.offset);
    const now = this.answerValue;
    if (this.closedValue || now === null || now.outcome !== 'rows') return null;
    if (hit.index >= now.rows.length) {
      this.announce(fillPlaceholders(STRINGS.explorerSqlDataNoRow, { n: hit.offset + hit.index + 1 }));
      return null;
    }
    return { index: hit.index };
  }

  /** Read the page on screen again. */
  async refresh(deps: DataBrowserDeps): Promise<void> {
    await this.read(deps);
  }

  /** What a column's filter input holds, applied or not. */
  setDraft(column: string, value: string): void {
    this.draftsValue = { ...this.draftsValue, [column]: value };
    this.host.notify();
  }

  /** Apply `column`'s typed filter -- an empty one removes it -- and return to the first page. */
  async applyFilter(deps: DataBrowserDeps, column: string): Promise<void> {
    const value = (Object.hasOwn(this.draftsValue, column) ? this.draftsValue[column] : '').trim();
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

  /** Page row `id`'s identity, key values and every value read, or `null` when it holds a key value that is NULL. */
  private pageRow(id: string): { readonly identity: string; readonly key: Readonly<Record<string, string>>; readonly values: Readonly<Record<string, string | null>> } | null {
    const answer = this.answerValue;
    const index = Number(id.slice(1));
    if (answer === null || answer.outcome !== 'rows' || !Number.isInteger(index)) return null;
    const cells = answer.rows[index];
    if (cells === undefined) return null;
    const values: Record<string, string | null> = {};
    answer.columns.forEach((column, at) => (values[column.name] = cells[at] ?? null));
    const key: Record<string, string> = {};
    for (const name of answer.key) {
      const value = values[name];
      if (typeof value !== 'string') return null;
      key[name] = value;
    }
    return { identity: rowKey(answer.key, values), key, values };
  }

  /** After a staging change: the dirty flag over every tab, and the staged count, or the cap's sentence when it refused. */
  private afterStaging(deps: DataBrowserDeps, accepted: boolean): void {
    const count = this.staged.count();
    this.host.stagingChanged(deps);
    this.announcementValue = !accepted ? STRINGS.explorerSqlDataCap : count === 0 ? '' : waitingText(count);
    this.host.notify();
  }

  /**
   * The request a page posts: the open object, its applied filters -- a BIT column's as the instance
   * matches it (`filterValue`) -- its sort, the offset and the size.
   */
  private body(): string {
    const kinds = new Map((this.answerValue?.columns ?? []).map((column) => [column.name, column.kind]));
    const filters: Record<string, string> = {};
    for (const [column, value] of Object.entries(this.filtersValue)) filters[column] = filterValue(kinds.get(column) ?? 'text', value);
    const body: Record<string, unknown> = {
      schema: this.object.schema,
      table: this.object.name,
      filters,
      sort: this.sortValue,
      offset: this.offsetValue,
      size: this.sizeValue,
    };
    return JSON.stringify(body);
  }

  /** Post the page, `announcement` the line its status reads first; a refusal keeps the open object and shows its sentence. */
  private async read(deps: DataBrowserDeps, announcement = ''): Promise<void> {
    if (this.closedValue) return;
    const generation = ++this.generation;
    this.loadingValue = true;
    this.refusalValue = '';
    this.announcementValue = announcement;
    this.host.notify();
    const result: JsonResult<unknown> = await deps.api.requestJson<unknown>(DATA_PATH, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: this.body(),
      scope: deps.scope(),
    });
    if (generation !== this.generation || this.closedValue) return;
    this.loadingValue = false;
    if (result.kind !== 'ok') {
      this.answerValue = null;
      this.refusalValue =
        (result.kind === 'error' ? refusalText(result.code, result.reason, result.detail) : '') || STRINGS.connectivityRequestRefused;
      this.host.notify();
      return;
    }
    this.answerValue = answerOf(result.body);
    this.host.notify();
  }
}

export class DataBrowserState implements TabHost {
  private schemasValue: readonly TreeSchema[] | null = null;

  private schemasLoadingValue = false;

  private schemasTruncatedValue = false;

  private schemasFaultValue = '';

  /** Which tree is current; a tree read answering after a namespace switch is dropped. */
  private treeGeneration = 0;

  /** The namespace the tree and the tabs were read in, `''` before the first. */
  private namespaceValue = '';

  /** The open tables, in strip order (Story 19.16). */
  private tabsValue: readonly DataTab[] = [];

  /** The selected tab's id, or `''` while none is open. */
  private activeId = '';

  /** How many tabs this state has opened, which names the next one. */
  private tabsOpened = 0;

  /** The status line while no tab is open, such as why staged rows went. */
  private announcementValue = '';

  private readonly listeners = new Set<() => void>();

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /** A tab's change reached the screen. */
  notify(): void {
    for (const listener of [...this.listeners]) listener();
  }

  /** What any tab stages changed: `FormDirty` reads dirty while any tab holds a staged row. */
  stagingChanged(deps: DataBrowserDeps): void {
    deps.formDirty.setDirty(this.anyStaged());
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

  /** The tabs as the strip draws them. */
  tabs(): readonly TabView[] {
    return this.tabsValue.map((tab) => ({ id: tab.id, label: tab.label(), staged: tab.stagedCount(), active: tab.id === this.activeId }));
  }

  /** The selected tab, or `null` while none is open. */
  activeTab(): DataTab | null {
    return this.tabsValue.find((tab) => tab.id === this.activeId) ?? null;
  }

  /** Whether any tab holds a staged row. */
  anyStaged(): boolean {
    return this.tabsValue.some((tab) => tab.stagedCount() > 0);
  }

  /** Select tab `id`; nothing is read. `false` when it is unknown or already selected. */
  selectTab(id: string): boolean {
    if (id === this.activeId || !this.tabsValue.some((tab) => tab.id === id)) return false;
    this.activeId = id;
    this.notify();
    return true;
  }

  /** Select the tab `step` places along the strip, wrapping at either end; nothing with fewer than two tabs. */
  nextTab(step: number): boolean {
    const count = this.tabsValue.length;
    if (count < 2) return false;
    const at = this.tabsValue.findIndex((tab) => tab.id === this.activeId);
    return this.selectTab(this.tabsValue[(((at + step) % count) + count) % count].id);
  }

  /**
   * Close tab `id`, dropping what it stages: the tab to its right, else to its left, is selected when
   * it was the selected one, the status line says "<table> closed.", and `FormDirty` follows what the
   * other tabs stage. The page asks first when the tab holds staged rows.
   */
  closeTab(deps: DataBrowserDeps, id: string): void {
    const at = this.tabsValue.findIndex((tab) => tab.id === id);
    if (at < 0) return;
    const tab = this.tabsValue[at];
    tab.close();
    this.tabsValue = this.tabsValue.filter((entry) => entry.id !== id);
    if (this.activeId === id) this.activeId = (this.tabsValue[at] ?? this.tabsValue[at - 1])?.id ?? '';
    this.stagingChanged(deps);
    this.announce(fillPlaceholders(STRINGS.explorerSqlDataTabClosed, { table: tab.label() }));
  }

  /** The table or view open in the selected tab, or `null`. */
  open(): TreeObject | null {
    return this.activeTab()?.object ?? null;
  }

  filters(): Readonly<Record<string, string>> {
    return this.activeTab()?.filters() ?? {};
  }

  drafts(): Readonly<Record<string, string>> {
    return this.activeTab()?.drafts() ?? {};
  }

  sort(): SortState | null {
    return this.activeTab()?.sort() ?? null;
  }

  offset(): number {
    return this.activeTab()?.offset() ?? 0;
  }

  /** The selected tab's page size, or the default while none is open. */
  size(): number {
    return this.activeTab()?.size() ?? DEFAULT_PAGE_SIZE;
  }

  answer(): BrowseAnswer | null {
    return this.activeTab()?.answer() ?? null;
  }

  loading(): boolean {
    return this.activeTab()?.loading() ?? false;
  }

  refusal(): string {
    return this.activeTab()?.refusal() ?? '';
  }

  /** The last announcement, read by the page's polite status line: the selected tab's, or the screen's while none is open. */
  announcement(): string {
    return this.activeTab()?.announcement() ?? this.announcementValue;
  }

  /** Put `text` on the status line until the next one. */
  announce(text: string): void {
    const tab = this.activeTab();
    if (tab !== null) {
      tab.announce(text);
      return;
    }
    this.announcementValue = text;
    this.notify();
  }

  /** Whether a save is on its way for the selected tab. */
  saving(): boolean {
    return this.activeTab()?.saving() ?? false;
  }

  /** How many rows the selected tab stages. */
  stagedCount(): number {
    return this.activeTab()?.stagedCount() ?? 0;
  }

  /** How many rows a save of the selected tab would change, add and delete. */
  stagedCounts(): { readonly update: number; readonly insert: number; readonly delete: number } {
    return this.activeTab()?.stagedCounts() ?? { update: 0, insert: 0, delete: 0 };
  }

  writable(): boolean {
    return this.activeTab()?.writable() ?? false;
  }

  rows(): readonly StagedRow[] {
    return this.activeTab()?.rows() ?? [];
  }

  /** The selected tab's active cell, or `null`. */
  activeCell(): ActiveCell | null {
    return this.activeTab()?.activeCell() ?? null;
  }

  setActiveCell(cell: ActiveCell): void {
    this.activeTab()?.setActiveCell(cell);
  }

  canExport(): boolean {
    return this.activeTab()?.canExport() ?? false;
  }

  canGoToRow(): boolean {
    return this.activeTab()?.canGoToRow() ?? false;
  }

  /** The selected tab's page as a CSV file, or `null` while it has no row to write. */
  exportPage(now: Date): PageExport | null {
    return this.activeTab()?.exportPage(now) ?? null;
  }

  /** Go to a row number in the selected tab (`DataTab.goToRowNumber`). */
  async goToRowNumber(deps: DataBrowserDeps, typed: string): Promise<RowJump> {
    return (await this.activeTab()?.goToRowNumber(deps, typed)) ?? null;
  }

  edit(deps: DataBrowserDeps, id: string, column: number, value: string | null): void {
    this.activeTab()?.edit(deps, id, column, value);
  }

  addRow(deps: DataBrowserDeps): string | null {
    return this.activeTab()?.addRow(deps) ?? null;
  }

  duplicate(deps: DataBrowserDeps, id: string): string | null {
    return this.activeTab()?.duplicate(deps, id) ?? null;
  }

  toggleDelete(deps: DataBrowserDeps, id: string): void {
    this.activeTab()?.toggleDelete(deps, id);
  }

  deleted(id: string): boolean {
    return this.activeTab()?.deleted(id) ?? false;
  }

  /** Drop every row the selected tab stages, saying how many. */
  discard(deps: DataBrowserDeps): void {
    this.activeTab()?.discard(deps);
  }

  /** Drop every row any tab stages, as leaving the route does; the tabs stay open. */
  discardAll(deps: DataBrowserDeps): void {
    for (const tab of this.tabsValue) if (tab.stagedCount() > 0 || tab.saving()) tab.discard(deps);
    deps.formDirty.setDirty(false);
  }

  /** Save every row the selected tab stages (`DataTab.save`). */
  async save(deps: DataBrowserDeps): Promise<boolean> {
    return (await this.activeTab()?.save(deps)) ?? false;
  }

  /**
   * Scope the state to `namespace` (AD-44): a namespace other than the one the tree and the tabs were
   * read in forgets both and drops every read still on its way, then the tree is read. `''`, a scope
   * not yet resolved, reads nothing.
   */
  async scopeTo(deps: DataBrowserDeps, namespace: string): Promise<void> {
    if (namespace === '') return;
    if (namespace !== this.namespaceValue) {
      this.namespaceValue = namespace;
      this.forget(deps);
    }
    await this.loadSchemas(deps);
  }

  /** Read the schemas holding a table or a view, once; a later call keeps what was read. */
  async loadSchemas(deps: DataBrowserDeps): Promise<void> {
    if (this.schemasValue !== null || this.schemasLoadingValue || deps.schemas === null) return;
    const tree = this.treeGeneration;
    this.schemasLoadingValue = true;
    this.notify();
    const read = createScreenRead(deps.api, deps.schemas, () => ({ system: 'no' }));
    const result = await read({ maxRows: TREE_MAX_ROWS });
    if (tree !== this.treeGeneration) return;
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

  /** Expand `name`, reading its tables and then its views the first time or after a read failed, or collapse it. */
  async toggle(deps: DataBrowserDeps, name: string): Promise<void> {
    const node = this.schemasValue?.find((schema) => schema.name === name);
    if (node === undefined) return;
    if (node.expanded) {
      this.replace(name, { expanded: false });
      return;
    }
    if ((node.objects !== null && node.fault === '') || node.loading) {
      this.replace(name, { expanded: true });
      return;
    }
    const tree = this.treeGeneration;
    this.replace(name, { expanded: true, loading: true, fault: '' });
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
      if (tree !== this.treeGeneration) return;
      if (result.kind !== 'ok') {
        fault = STRINGS.connectivityRequestRefused;
        continue;
      }
      truncated = truncated || result.truncated;
      objects.push(...objectsOf(result.rows, view));
    }
    this.replace(name, { loading: false, objects, truncated, fault });
  }

  /**
   * Open `object` (Story 19.16): an object already open has its tab selected and reads nothing; past
   * `MAX_TABS` nothing opens and the status line says so; otherwise a tab opens with the selected
   * tab's page size, is selected, and reads its first page. Nothing staged anywhere is dropped. The
   * selection is made before the first read is sent.
   */
  async openObject(deps: DataBrowserDeps, object: TreeObject): Promise<void> {
    const known = this.tabsValue.find((tab) => sameObject(tab.object, object));
    if (known !== undefined) {
      this.selectTab(known.id);
      return;
    }
    if (this.tabsValue.length >= MAX_TABS) {
      this.announce(fillPlaceholders(STRINGS.explorerSqlDataTabCap, { n: MAX_TABS }));
      return;
    }
    this.tabsOpened += 1;
    const tab = new DataTab(`ocu-data-tab-${this.tabsOpened}`, object, this.size(), this);
    this.tabsValue = [...this.tabsValue, tab];
    this.activeId = tab.id;
    this.notify();
    await tab.refresh(deps);
  }

  /** Read the selected tab's page again. */
  async refresh(deps: DataBrowserDeps): Promise<void> {
    await this.activeTab()?.refresh(deps);
  }

  setDraft(column: string, value: string): void {
    this.activeTab()?.setDraft(column, value);
  }

  async applyFilter(deps: DataBrowserDeps, column: string): Promise<void> {
    await this.activeTab()?.applyFilter(deps, column);
  }

  async clearFilter(deps: DataBrowserDeps, column: string): Promise<void> {
    await this.activeTab()?.clearFilter(deps, column);
  }

  async clearFilters(deps: DataBrowserDeps): Promise<void> {
    await this.activeTab()?.clearFilters(deps);
  }

  async cycleSort(deps: DataBrowserDeps, column: string): Promise<void> {
    await this.activeTab()?.cycleSort(deps, column);
  }

  async firstPage(deps: DataBrowserDeps): Promise<void> {
    await this.activeTab()?.firstPage(deps);
  }

  async previousPage(deps: DataBrowserDeps): Promise<void> {
    await this.activeTab()?.previousPage(deps);
  }

  async nextPage(deps: DataBrowserDeps): Promise<void> {
    await this.activeTab()?.nextPage(deps);
  }

  async lastPage(deps: DataBrowserDeps): Promise<void> {
    await this.activeTab()?.lastPage(deps);
  }

  async goTo(deps: DataBrowserDeps, offset: number): Promise<void> {
    await this.activeTab()?.goTo(deps, offset);
  }

  async setSize(deps: DataBrowserDeps, size: number): Promise<void> {
    await this.activeTab()?.setSize(deps, size);
  }

  /**
   * Drop the tree and close every tab, with what each staged and every read on its way; the status
   * line says once that staged rows were discarded when any tab held one.
   */
  private forget(deps: DataBrowserDeps): void {
    let discarded = 0;
    for (const tab of this.tabsValue) discarded += tab.close();
    this.tabsValue = [];
    this.activeId = '';
    deps.formDirty.setDirty(false);
    this.treeGeneration += 1;
    this.schemasValue = null;
    this.schemasLoadingValue = false;
    this.schemasTruncatedValue = false;
    this.schemasFaultValue = '';
    this.announcementValue = discarded > 0 ? STRINGS.explorerSqlDataScopeDiscarded : '';
    this.notify();
  }

  /** Replace schema `name`'s node with `change` applied. */
  private replace(name: string, change: Partial<TreeSchema>): void {
    this.schemasValue = (this.schemasValue ?? []).map((schema) => (schema.name === name ? { ...schema, ...change } : schema));
    this.notify();
  }
}
