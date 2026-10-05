/**
 * Data browser's pure rules (Story 19.7): the tri-state sort, the grid's cell moves, offset paging,
 * how a cell reads, a column's track, which columns take a filter, and the status lines. Story 19.8
 * adds the editors' parsers, the BIT toggle, a row's key, which cells may change, and the staged
 * changes a save sends (`StagedChanges`).
 * Story 19.16 adds the tab cap, go to row, a page's CSV cells and the shortcuts
 * (`DATA_BROWSER_SHORTCUTS`). Story 19.9 adds the page's CSV file (`pageCsvText`), which writes a
 * number column's cell bare when it is wholly a number (DW-2061).
 *
 * Ported from iris-table-editor v0.2.3 (MIT, `ui/licenses/iris-table-editor.txt`),
 * `packages/webview/src/grid.js`: `handleColumnSort` (:3961-3999) as `nextSort`; the read-only keys
 * of `handleCellKeydown` (:3424-3515) and `getVisibleRowCount` (:3559-3571) as `moveCell`, the header
 * row joining the rows it moves over; the pagination (:4277-4530) as the offset functions; and
 * `formatCellValue` (:262-313) as `cellView`, which shows the instance's ODBC form rather than
 * reformatting it. Its call sites are kept; its names are not.
 *
 * Framework-free, like the rest of `core/`, so `ui/tools/data-browser-model.test.mjs` runs it under
 * `node --test`.
 */

import { CSV_BOM, csvField } from './csv.ts';
import { STRINGS } from './strings.ts';
import { groupDigits } from './table-model.ts';

/** A column's kind, as the instance answers it. */
export type DataKind = 'number' | 'boolean' | 'date' | 'time' | 'timestamp' | 'stream' | 'binary' | 'text';

export type SortDirection = 'asc' | 'desc';

/** The one column a page is sorted by, or none. */
export interface SortState {
  readonly column: string;
  readonly direction: SortDirection;
}

/** The page sizes Rows per page offers, the default, and the furthest offset the route takes. */
export const PAGE_SIZES: readonly number[] = [50, 100, 250, 500];
export const DEFAULT_PAGE_SIZE = 100;
export const MAX_OFFSET = 99_999_999;

/** `text` with each `<placeholder>` of `values` replaced. */
function fill(template: string, values: Readonly<Record<string, string>>): string {
  let text = template;
  for (const [key, value] of Object.entries(values)) text = text.split(`<${key}>`).join(value);
  return text;
}

/**
 * The sort after a header for `column` is activated: a new column starts ascending; the same column
 * goes ascending, descending, then none.
 */
export function nextSort(current: SortState | null, column: string): SortState | null {
  if (current === null || current.column !== column) return { column, direction: 'asc' };
  if (current.direction === 'asc') return { column, direction: 'desc' };
  return null;
}

/** A cell of the grid: `row` -1 is the header row, `column` 0 the first column. */
export interface CellPosition {
  readonly row: number;
  readonly column: number;
}

/** The keys `moveCell` answers. */
const MOVE_KEYS: ReadonlySet<string> = new Set(['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Home', 'End', 'PageUp', 'PageDown']);

/** Whether `key` with `control` (Ctrl, or Cmd on a Mac) moves the active cell. */
export function isCellMoveKey(key: string, control: boolean): boolean {
  if (control && (key === 'PageUp' || key === 'PageDown')) return false;
  return MOVE_KEYS.has(key);
}

/**
 * The active cell after `key` over `rows` data rows and `columns` columns, the header row being row
 * -1, with `visibleRows` rows to a page. Arrows do not wrap; Home and End go to the row's first and
 * last cell; with `control`, to the grid's first cell, in the header row, and its last; PageUp and
 * PageDown move by `visibleRows`, stopping at the header and the last row. `null` for a key that does
 * not move, or a grid with no column.
 */
export function moveCell(position: CellPosition, key: string, control: boolean, rows: number, columns: number, visibleRows: number): CellPosition | null {
  if (columns <= 0 || !isCellMoveKey(key, control)) return null;
  const lastRow = rows - 1;
  const lastColumn = columns - 1;
  const row = Math.min(Math.max(position.row, -1), lastRow);
  const column = Math.min(Math.max(position.column, 0), lastColumn);
  const page = Math.max(1, visibleRows);
  switch (key) {
    case 'ArrowUp':
      return { row: Math.max(-1, row - 1), column };
    case 'ArrowDown':
      return { row: Math.min(lastRow, row + 1), column };
    case 'ArrowLeft':
      return { row, column: Math.max(0, column - 1) };
    case 'ArrowRight':
      return { row, column: Math.min(lastColumn, column + 1) };
    case 'Home':
      return control ? { row: -1, column: 0 } : { row, column: 0 };
    case 'End':
      return control ? { row: lastRow, column: lastColumn } : { row, column: lastColumn };
    case 'PageUp':
      return { row: Math.max(-1, row - page), column };
    case 'PageDown':
      return { row: Math.min(lastRow, row + page), column };
    default:
      return null;
  }
}

/** The page change Ctrl/Cmd+PageDown and PageUp ask for, or `null`. */
export function pageKey(key: string, control: boolean): 'next' | 'previous' | null {
  if (!control) return null;
  if (key === 'PageDown') return 'next';
  if (key === 'PageUp') return 'previous';
  return null;
}

/** The previous page's offset: one page back, never before the first row. */
export function previousOffset(offset: number, size: number): number {
  return Math.max(0, offset - size);
}

/** The next page's offset: past the rows this page kept, so a page cut short skips nothing. */
export function nextOffset(offset: number, rowsKept: number): number {
  return offset + rowsKept;
}

/** The last page's offset while the total is known, else `null`. */
export function lastOffset(total: number | null, size: number): number | null {
  if (total === null) return null;
  if (total <= 0) return 0;
  return Math.floor((total - 1) / size) * size;
}

/** How many pages the total fills, at least one, while it is known; else `null`. */
export function pageCount(total: number | null, size: number): number | null {
  if (total === null) return null;
  return Math.max(1, Math.ceil(total / size));
}

/** The page `offset` falls on, counting from 1. */
export function pageOf(offset: number, size: number): number {
  return Math.floor(offset / size) + 1;
}

/**
 * The offset a typed page number goes to: a whole number from 1 to the page count while the total is
 * known, or from 1 while it is not, within the route's furthest offset; else `null`.
 */
export function goToPageOffset(text: string, size: number, total: number | null): number | null {
  const trimmed = text.trim();
  if (!/^[0-9]{1,9}$/.test(trimmed)) return null;
  const page = Number(trimmed);
  if (page < 1) return null;
  const count = pageCount(total, size);
  if (count !== null && page > count) return null;
  const offset = (page - 1) * size;
  return offset <= MAX_OFFSET ? offset : null;
}

/** How one cell reads: its text, and whether it is NULL (drawn muted) and a number (right-aligned). */
export interface CellView {
  readonly text: string;
  readonly isNull: boolean;
  readonly numeric: boolean;
}

/**
 * A cell of kind `kind` holding `value` (`null` for SQL NULL): NULL reads "NULL", distinct from an
 * empty value; BIT reads the yes and no words; a number is flagged for right-aligned tabular
 * figures; a date, time or timestamp shows the instance's ODBC form as answered; a stream's text and
 * binary's `0x` hex are the instance's own cut.
 */
export function cellView(kind: DataKind, value: string | null): CellView {
  if (value === null) return { text: STRINGS.explorerSqlDataNull, isNull: true, numeric: false };
  if (kind === 'boolean') {
    if (value === '1') return { text: STRINGS.tableStatusYes, isNull: false, numeric: false };
    if (value === '0') return { text: STRINGS.tableStatusNo, isNull: false, numeric: false };
  }
  return { text: value, isNull: false, numeric: kind === 'number' };
}

/**
 * A filter on a column of kind `kind` as the instance matches it: on a BIT column the yes or no word
 * `cellView` shows, in any case, is the 1 or 0 the column stores; any other text is sent as typed.
 */
export function filterValue(kind: DataKind, text: string): string {
  if (kind !== 'boolean') return text;
  const word = text.toLowerCase();
  if (word === STRINGS.tableStatusYes.toLowerCase()) return '1';
  if (word === STRINGS.tableStatusNo.toLowerCase()) return '0';
  return text;
}

/** A column's floor in CSS pixels, by kind: the width it never goes below. */
export function columnFloor(kind: DataKind): number {
  const floor: Readonly<Record<DataKind, number>> = {
    number: 112,
    boolean: 112,
    date: 128,
    time: 112,
    timestamp: 192,
    stream: 240,
    binary: 240,
    text: 160,
  };
  return floor[kind] ?? 160;
}

/** A column's track in the grid's template: a floor by kind that never shrinks, sharing the rest. */
export function columnTrack(kind: DataKind): string {
  return `minmax(${columnFloor(kind)}px, 1fr)`;
}

/** Whether a column of `kind` takes a filter or a sort: any kind but a stream and binary. */
export function isFilterable(kind: DataKind): boolean {
  return kind !== 'stream' && kind !== 'binary';
}

/**
 * The status line of a page of `rowsShown` rows at `offset`: "Rows <first>\u2013<last> of <total>", or
 * "Rows <first>\u2013<last>" while the total is unknown; an empty page reads "No rows." or, with
 * `filtered`, "No rows match the filters.".
 */
export function rowsLine(offset: number, rowsShown: number, total: number | null, filtered: boolean): string {
  if (rowsShown === 0) return filtered ? STRINGS.explorerSqlDataNoMatch : STRINGS.explorerSqlDataNoRows;
  const range = { first: groupDigits(offset + 1), last: groupDigits(offset + rowsShown) };
  if (total === null) return fill(STRINGS.explorerSqlDataRows, range);
  return fill(STRINGS.explorerSqlDataRowsOf, { ...range, total: groupDigits(total) });
}

/** The polite announcement of a sort change. */
export function sortLine(sort: SortState | null): string {
  if (sort === null) return STRINGS.explorerSqlDataSortCleared;
  return fill(sort.direction === 'asc' ? STRINGS.explorerSqlDataSortedAscending : STRINGS.explorerSqlDataSortedDescending, { column: sort.column });
}

/** The line a page field outside 1 to `count` reads. */
export function pageRangeLine(count: number | null): string {
  return fill(STRINGS.explorerSqlDataPageRange, { n: count === null ? '1' : groupDigits(count) });
}

// --- Editing, staging and saving (Story 19.8) ------------------------------------------------------

/**
 * A column as an editor reads it: its catalog type and kind, whether it takes NULL, and whether it is
 * a key, an identity or a generated column.
 */
export interface EditColumn {
  readonly name: string;
  readonly type: string;
  readonly kind: DataKind;
  readonly nullable: boolean;
  readonly key: boolean;
  readonly identity?: boolean;
  readonly generated?: boolean;
}

/** What an editor's text parses to: the value to stage (`null` for NULL), or the sentence it fails. */
export type CellParse = { readonly value: string | null } | { readonly problem: string };

/** The catalog's whole-number types; `double` alone takes an exponent. */
const INTEGER_TYPES: ReadonlySet<string> = new Set(['tinyint', 'smallint', 'integer', 'bigint']);
const WHOLE = /^[+-]?[0-9]+$/;
const DECIMAL = /^[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)$/;
const DOUBLE = /^[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?$/;

function pad(value: number, width: number): string {
  return String(value).padStart(width, '0');
}

/** The days month `month` of `year` holds. */
function daysIn(year: number, month: number): number {
  const leap = (year % 4 === 0 && year % 100 !== 0) || year % 400 === 0;
  return [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1] ?? 0;
}

/**
 * A date typed as `YYYY-M-D`, `D-M-YYYY` or `M/D/YYYY` -- `D/M/YYYY` when the first number is over 12
 * -- in the ODBC form `YYYY-MM-DD`, its day held to its month; `null` for anything else.
 */
function parseDate(text: string): string | null {
  let year: number;
  let month: number;
  let day: number;
  const iso = /^([0-9]{4})-([0-9]{1,2})-([0-9]{1,2})$/.exec(text);
  const dashed = /^([0-9]{1,2})-([0-9]{1,2})-([0-9]{4})$/.exec(text);
  const slashed = /^([0-9]{1,2})\/([0-9]{1,2})\/([0-9]{4})$/.exec(text);
  if (iso !== null) {
    [year, month, day] = [Number(iso[1]), Number(iso[2]), Number(iso[3])];
  } else if (dashed !== null) {
    [day, month, year] = [Number(dashed[1]), Number(dashed[2]), Number(dashed[3])];
  } else if (slashed !== null) {
    const first = Number(slashed[1]);
    const second = Number(slashed[2]);
    year = Number(slashed[3]);
    [month, day] = first > 12 ? [second, first] : [first, second];
  } else {
    return null;
  }
  if (year < 1 || month < 1 || month > 12 || day < 1 || day > daysIn(year, month)) return null;
  return `${pad(year, 4)}-${pad(month, 2)}-${pad(day, 2)}`;
}

/** A time typed as `H:MM[:SS[.f]]` with an optional AM/PM, as `HH:MM:SS[.f]`, the fraction kept; else `null`. */
function parseTime(text: string): string | null {
  const match = /^([0-9]{1,2}):([0-9]{2})(?::([0-9]{2})(\.[0-9]+)?)?(?:\s*(am|pm|a|p)\.?)?$/i.exec(text);
  if (match === null) return null;
  let hours = Number(match[1]);
  const minutes = Number(match[2]);
  const seconds = match[3] === undefined ? 0 : Number(match[3]);
  const meridian = match[5]?.toLowerCase();
  if (meridian !== undefined) {
    if (hours < 1 || hours > 12) return null;
    const afternoon = meridian.startsWith('p');
    if (afternoon && hours !== 12) hours += 12;
    if (!afternoon && hours === 12) hours = 0;
  }
  if (hours > 23 || minutes > 59 || seconds > 59) return null;
  return `${pad(hours, 2)}:${pad(minutes, 2)}:${pad(seconds, 2)}${match[4] ?? ''}`;
}

/** A timestamp typed as a date and a time, or a date alone at midnight, as `YYYY-MM-DD HH:MM:SS[.f]`; else `null`. */
function parseTimestamp(text: string): string | null {
  const match = /^(.+?)(?:T|\s+)([0-9]{1,2}:[0-9]{2}(?::[0-9]{2}(?:\.[0-9]+)?)?(?:\s*(?:am|pm|a|p)\.?)?)$/i.exec(text);
  if (match !== null) {
    const date = parseDate(match[1].trim());
    const time = parseTime(match[2]);
    return date === null || time === null ? null : `${date} ${time}`;
  }
  const date = parseDate(text);
  return date === null ? null : `${date} 00:00:00`;
}

/**
 * What an editor's `text` stages for `column`. Text is staged exactly as typed. Every other kind is
 * read trimmed, and an empty entry is NULL where the column takes it: a whole number is digits with
 * an optional sign; a NUMERIC a decimal, and a DOUBLE a decimal with an optional exponent, each sent
 * as typed, never through `Number()`; a date, a time and a timestamp in the ODBC form, the fraction
 * kept; BIT 1 or 0, or the yes and no words. Anything else answers the kind's hint.
 *
 * Ported from iris-table-editor v0.2.3 (MIT, `ui/licenses/iris-table-editor.txt`),
 * `packages/core/src/utils/DataTypeFormatter.ts`: `parseUserTimeInput` (:98-154),
 * `parseUserDateInput` (:172-230), `parseUserTimestampInput` (:250-300) and `parseNumericInput`
 * (:320-338), with no `Number()`, no comma stripping, no `new Date()` fallback, impossible dates
 * refused and fractions kept.
 */
export function parseCellInput(column: EditColumn, text: string): CellParse {
  if (column.kind === 'text') return { value: text };
  const trimmed = text.trim();
  if (trimmed === '') return column.nullable ? { value: null } : { problem: STRINGS.explorerSqlDataNotNull };
  switch (column.kind) {
    case 'number': {
      const type = column.type.toLowerCase();
      if (INTEGER_TYPES.has(type)) return WHOLE.test(trimmed) ? { value: trimmed } : { problem: STRINGS.explorerSqlDataHintInteger };
      return (type === 'double' ? DOUBLE : DECIMAL).test(trimmed) ? { value: trimmed } : { problem: STRINGS.explorerSqlDataHintNumber };
    }
    case 'date': {
      const value = parseDate(trimmed);
      return value === null ? { problem: STRINGS.explorerSqlDataHintDate } : { value };
    }
    case 'time': {
      const value = parseTime(trimmed);
      return value === null ? { problem: STRINGS.explorerSqlDataHintTime } : { value };
    }
    case 'timestamp': {
      const value = parseTimestamp(trimmed);
      return value === null ? { problem: STRINGS.explorerSqlDataHintTimestamp } : { value };
    }
    case 'boolean': {
      const word = trimmed.toLowerCase();
      if (trimmed === '1' || word === STRINGS.tableStatusYes.toLowerCase()) return { value: '1' };
      if (trimmed === '0' || word === STRINGS.tableStatusNo.toLowerCase()) return { value: '0' };
      return { problem: STRINGS.explorerSqlDataNotEditable };
    }
    default:
      return { problem: STRINGS.explorerSqlDataNotEditable };
  }
}

/**
 * A BIT cell's value after a toggle: NULL to 1, 1 to 0, and 0 to NULL where the column takes it, else
 * to 1. Ported from the harvest's boolean toggle (`grid.js` :378-438).
 */
export function nextBoolean(value: string | null, nullable: boolean): string | null {
  if (value === null) return '1';
  if (value === '1') return '0';
  if (value === '0') return nullable ? null : '1';
  return '1';
}

/** A row's identity: the canonical JSON of `values`' key columns, in `key`'s order. */
export function rowKey(key: readonly string[], values: Readonly<Record<string, string | null>>): string {
  return JSON.stringify(key.map((name) => (Object.hasOwn(values, name) ? values[name] : null)));
}

/** Whether a save may change `column` on a row it read: not a key, identity, generated, stream or binary column. */
export function editable(column: EditColumn): boolean {
  return !column.key && insertable(column);
}

/** Whether a save may set `column` on a new row: as `editable`, a key column included. */
export function insertable(column: EditColumn): boolean {
  return column.identity !== true && column.generated !== true && column.kind !== 'stream' && column.kind !== 'binary';
}

/** Whether `cuts`, an answer's `[row, column]` pairs, names the cell at `row`, `column`. */
export function isCut(cuts: readonly (readonly number[])[], row: number, column: number): boolean {
  return cuts.some((pair) => pair[0] === row && pair[1] === column);
}

/** The most staged rows one save carries. */
export const MAX_STAGED_ROWS = 100;

/** A staged row's outcome, as the instance answered it. */
export type RowOutcome = 'saved' | 'changed' | 'gone' | 'refused' | 'error' | 'stopped' | 'skipped';

/** What a save answered for one row: its outcome, an SQL error's code and message, and the bound a stopped row ran out of. */
export interface OutcomeNote {
  readonly outcome: RowOutcome;
  readonly sqlcode: number | null;
  readonly message: string;
  readonly seconds?: number;
}

/** One row's result in a save's answer. */
export interface SaveResult {
  readonly index: number;
  readonly outcome: RowOutcome;
  readonly sqlcode?: number | null;
  readonly message?: string;
  readonly seconds?: number;
}

/** One change as a save sends it (Story 19.8's wire). */
export type WireChange =
  | {
      readonly op: 'update';
      readonly key: Readonly<Record<string, string>>;
      readonly original: Readonly<Record<string, string | null>>;
      readonly values: Readonly<Record<string, string | null>>;
    }
  | { readonly op: 'insert'; readonly values: Readonly<Record<string, string | null>> }
  | { readonly op: 'delete'; readonly key: Readonly<Record<string, string>> };

/** A page row with what is staged on it shown. */
export interface OverlayRow {
  /** Its identity, `''` where the table has no key. */
  readonly key: string;
  readonly cells: readonly (string | null)[];
  readonly staged: readonly boolean[];
  readonly deleted: boolean;
  readonly outcome: OutcomeNote | null;
}

/** A new row, staged for an insert, with the outcome the last save kept for it when it failed. */
export interface NewRow {
  readonly id: string;
  readonly values: Readonly<Record<string, string | null>>;
  readonly outcome: OutcomeNote | null;
}

interface StagedUpdate {
  readonly key: Readonly<Record<string, string>>;
  readonly original: Record<string, string | null>;
  readonly values: Record<string, string | null>;
}

type Sent = { readonly kind: 'update' | 'delete'; readonly rowKey: string } | { readonly kind: 'insert'; readonly id: string };

/**
 * The rows a person has changed and not saved, each keyed by the row's identity (`rowKey`) rather than
 * by its place on a page, so paging, sorting, filtering and a refresh leave them where they belong:
 * updates, holding each changed column's value read and new value; inserts, by a client id; and
 * deletes. It refuses a 101st row (`MAX_STAGED_ROWS`).
 *
 * `toWire` composes a save -- deletes, then updates, then inserts -- and records which staged row each
 * sent index is; `applyResults` drops the saved rows, rolls every failed update and delete back to the
 * values read, keeps a failed insert staged with what was typed, and keeps each outcome by key (a new
 * row's by its id), so an answer applied after the page moved marks rows by key, never by position.
 *
 * Re-expresses the harvest's per-cell save and its index-keyed reconciliation (`grid.js` :1767,
 * :1865-2004) as staging keyed by the row's key. Framework-free.
 */
export class StagedChanges {
  private readonly updates = new Map<string, StagedUpdate>();

  private readonly inserts = new Map<string, Record<string, string | null>>();

  private readonly deletes = new Map<string, Readonly<Record<string, string>>>();

  private readonly outcomes = new Map<string, OutcomeNote>();

  /** The outcomes kept for new rows a save could not insert, by their id. */
  private readonly newOutcomes = new Map<string, OutcomeNote>();

  private sent: Sent[] = [];

  private nextId = 1;

  /** How many rows are staged: an updated or deleted row once, and each new row. */
  count(): number {
    const keys = new Set([...this.updates.keys(), ...this.deletes.keys()]);
    return keys.size + this.inserts.size;
  }

  /** How many rows a save would change, add and delete. */
  counts(): { readonly update: number; readonly insert: number; readonly delete: number } {
    let update = 0;
    for (const key of this.updates.keys()) if (!this.deletes.has(key)) update += 1;
    return { update, insert: this.inserts.size, delete: this.deletes.size };
  }

  /** Whether a row not yet staged would be refused. */
  full(): boolean {
    return this.count() >= MAX_STAGED_ROWS;
  }

  /**
   * Stage `value` for `column` of the row `rowKey` identifies by `key`, whose value read is `original`;
   * a value equal to the value read unstages the cell. `false` when it would stage a 101st row.
   */
  stage(rowKey: string, key: Readonly<Record<string, string>>, column: string, original: string | null, value: string | null): boolean {
    const entry = this.updates.get(rowKey);
    const read = entry !== undefined && Object.hasOwn(entry.original, column) ? entry.original[column] : original;
    if (value === read) {
      this.unstage(rowKey, column);
      return true;
    }
    if (entry === undefined && !this.deletes.has(rowKey) && this.full()) return false;
    const staged = entry ?? { key: { ...key }, original: {}, values: {} };
    if (!Object.hasOwn(staged.original, column)) staged.original[column] = read;
    staged.values[column] = value;
    this.updates.set(rowKey, staged);
    this.outcomes.delete(rowKey);
    return true;
  }

  /** Drop the staged value of `column` on row `rowKey`, and the row once nothing of it is staged. */
  unstage(rowKey: string, column: string): void {
    const entry = this.updates.get(rowKey);
    if (entry === undefined) return;
    delete entry.values[column];
    delete entry.original[column];
    if (Object.keys(entry.values).length === 0) this.updates.delete(rowKey);
  }

  /** Mark row `rowKey` deleted, or restore it; `false` when marking it would stage a 101st row. */
  toggleDelete(rowKey: string, key: Readonly<Record<string, string>>): boolean {
    if (this.deletes.has(rowKey)) {
      this.deletes.delete(rowKey);
      return true;
    }
    if (!this.updates.has(rowKey) && this.full()) return false;
    this.deletes.set(rowKey, { ...key });
    this.outcomes.delete(rowKey);
    return true;
  }

  isDeleted(rowKey: string): boolean {
    return this.deletes.has(rowKey);
  }

  /** Stage a new row holding `values`, answering its id, or `null` at the cap. */
  addRow(values: Readonly<Record<string, string | null>> = {}): string | null {
    if (this.full()) return null;
    const id = `new${this.nextId}`;
    this.nextId += 1;
    this.inserts.set(id, { ...values });
    return id;
  }

  /**
   * Stage a copy of `values` as a new row, leaving out each key column, left empty, and every
   * identity, generated, stream, binary or cut cell (`cut` names the cut ones). `null` at the cap.
   */
  duplicate(columns: readonly EditColumn[], values: Readonly<Record<string, string | null>>, cut: (column: string) => boolean): string | null {
    const copy: Record<string, string | null> = {};
    for (const column of columns) {
      if (column.key || !insertable(column) || cut(column.name) || !Object.hasOwn(values, column.name)) continue;
      copy[column.name] = values[column.name];
    }
    return this.addRow(copy);
  }

  /** Set `column` of the new row `id` to `value`, which drops the outcome a failed save kept for it. */
  setNew(id: string, column: string, value: string | null): void {
    const values = this.inserts.get(id);
    if (values === undefined) return;
    values[column] = value;
    this.newOutcomes.delete(id);
  }

  /** Remove the new row `id`. */
  removeNew(id: string): void {
    this.inserts.delete(id);
    this.newOutcomes.delete(id);
  }

  /** The new rows, the newest first, each with the outcome a failed save kept for it. */
  newRows(): readonly NewRow[] {
    return [...this.inserts.entries()].reverse().map(([id, values]) => ({ id, values: { ...values }, outcome: this.newOutcomes.get(id) ?? null }));
  }

  /** Forget every staged row and outcome, answering how many rows were staged. */
  discard(): number {
    const count = this.count();
    this.updates.clear();
    this.inserts.clear();
    this.deletes.clear();
    this.outcomes.clear();
    this.newOutcomes.clear();
    this.sent = [];
    return count;
  }

  /** The outcome kept for row `rowKey`, or `null`. */
  outcomeFor(rowKey: string): OutcomeNote | null {
    return this.outcomes.get(rowKey) ?? null;
  }

  /**
   * `rows`, a page of cells in `columns`' order, each with what is staged on it shown: the staged
   * values on the row whose `key` matches, which cells those are, whether it is deleted, and the
   * outcome a save kept for it. A table with no key overlays nothing.
   */
  overlay(key: readonly string[], columns: readonly { readonly name: string }[], rows: readonly (readonly (string | null)[])[]): OverlayRow[] {
    return rows.map((cells) => {
      if (key.length === 0) return { key: '', cells, staged: cells.map(() => false), deleted: false, outcome: null };
      const values: Record<string, string | null> = {};
      columns.forEach((column, at) => (values[column.name] = cells[at] ?? null));
      const identity = rowKey(key, values);
      const entry = this.updates.get(identity);
      const shown = columns.map((column, at) => (entry !== undefined && Object.hasOwn(entry.values, column.name) ? entry.values[column.name] : (cells[at] ?? null)));
      const staged = columns.map((column) => entry !== undefined && Object.hasOwn(entry.values, column.name));
      return { key: identity, cells: shown, staged, deleted: this.deletes.has(identity), outcome: this.outcomes.get(identity) ?? null };
    });
  }

  /**
   * The changes a save sends -- deletes, then updates, then each new row that sets a value -- and the
   * staged row each index is, which `applyResults` reads.
   */
  toWire(): WireChange[] {
    const changes: WireChange[] = [];
    const sent: Sent[] = [];
    for (const [identity, key] of this.deletes) {
      changes.push({ op: 'delete', key: { ...key } });
      sent.push({ kind: 'delete', rowKey: identity });
    }
    for (const [identity, entry] of this.updates) {
      if (this.deletes.has(identity)) continue;
      changes.push({ op: 'update', key: { ...entry.key }, original: { ...entry.original }, values: { ...entry.values } });
      sent.push({ kind: 'update', rowKey: identity });
    }
    for (const [id, values] of this.inserts) {
      if (Object.keys(values).length === 0) continue;
      changes.push({ op: 'insert', values: { ...values } });
      sent.push({ kind: 'insert', id });
    }
    this.sent = sent;
    return changes;
  }

  /**
   * Apply a save's `results` to what `toWire` sent, in place of the outcomes the last save kept: a saved
   * row leaves staging; a failed update is dropped and a failed delete restored, back to the values
   * read; a failed insert stays staged with what was typed. Each row's outcome is kept by its key, a
   * saved insert's under the `key` columns its values set and a failed insert's by its id. Answers how
   * many were saved and how many failed.
   */
  applyResults(results: readonly SaveResult[], key: readonly string[]): { readonly saved: number; readonly failed: number } {
    let saved = 0;
    let failed = 0;
    this.outcomes.clear();
    this.newOutcomes.clear();
    for (const result of results) {
      const sent = this.sent[result.index];
      if (sent === undefined) continue;
      const note: OutcomeNote = {
        outcome: result.outcome,
        sqlcode: typeof result.sqlcode === 'number' ? result.sqlcode : null,
        message: result.message ?? '',
        ...(typeof result.seconds === 'number' ? { seconds: result.seconds } : {}),
      };
      if (result.outcome === 'saved') saved += 1;
      else failed += 1;
      if (sent.kind === 'insert') {
        if (result.outcome !== 'saved') {
          if (this.inserts.has(sent.id)) this.newOutcomes.set(sent.id, note);
          continue;
        }
        const values = this.inserts.get(sent.id) ?? {};
        this.inserts.delete(sent.id);
        if (key.length > 0 && key.every((name) => typeof values[name] === 'string')) this.outcomes.set(rowKey(key, values), note);
        continue;
      }
      this.updates.delete(sent.rowKey);
      if (sent.kind === 'delete') this.deletes.delete(sent.rowKey);
      this.outcomes.set(sent.rowKey, note);
    }
    this.sent = [];
    return { saved, failed };
  }
}

// --- Tabs, go to row, the page as CSV and the shortcuts (Story 19.16) ----------------------------

/** The most tables open at once, each in its own tab. */
export const MAX_TABS = 8;

/**
 * The largest row number Go to row takes: the total while it is known, else `MAX_OFFSET` plus the
 * page size, and never past the last row of the furthest page the route reads.
 */
export function rowRangeMax(total: number | null, size: number): number {
  const furthest = (Math.floor(MAX_OFFSET / size) + 1) * size;
  return Math.min(total ?? MAX_OFFSET + size, furthest);
}

/**
 * Where a typed row number lands: row `n` counts the rows the filters match, in the current sort,
 * and is read at offset `floor((n - 1) / size) * size`, at `index` on that page. `null` for anything
 * but 1 to 9 digits, or for an `n` outside 1 to `rowRangeMax`, or an offset past `MAX_OFFSET`.
 */
export function goToRow(text: string, size: number, total: number | null): { readonly offset: number; readonly index: number } | null {
  const trimmed = text.trim();
  if (!/^[0-9]{1,9}$/.test(trimmed)) return null;
  const row = Number(trimmed);
  if (row < 1 || row > rowRangeMax(total, size)) return null;
  const offset = Math.floor((row - 1) / size) * size;
  if (offset > MAX_OFFSET) return null;
  return { offset, index: row - 1 - offset };
}

/**
 * A page's rows as a CSV file writes them, in `columns`' order: each cell as the grid shows it
 * (`cellView`), BIT as the yes and no words, a cut cell as cut, and NULL empty.
 */
export function pageCsvRows(columns: readonly { readonly kind: DataKind }[], rows: readonly (readonly (string | null)[])[]): string[][] {
  return rows.map((cells) =>
    columns.map((column, at) => {
      const value = cells[at] ?? null;
      return value === null ? '' : cellView(column.kind, value).text;
    })
  );
}

/**
 * A number column's cell written bare in a page's CSV file: the whole text a number, as the instance
 * answers one in ODBC form -- an optional `-`, digits with an optional fraction or a fraction alone
 * (`-.5` is -0.5), and an optional exponent (DW-2061).
 */
export const CSV_NUMBER = /^-?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][-+]?[0-9]+)?$/;

/**
 * A page's CSV file (`core/csv.ts`'s byte-order mark, CRLF and quoting): the column names, then
 * `pageCsvRows`' cells. A number column's cell that `CSV_NUMBER` matches whole is written bare, so a
 * spreadsheet reads `-12.5` as a number; every other cell, and the header, goes through `csvField`
 * and keeps its formula guard.
 */
export function pageCsvText(
  columns: readonly { readonly name: string; readonly kind: DataKind }[],
  rows: readonly (readonly (string | null)[])[]
): string {
  const body = pageCsvRows(columns, rows).map((cells) =>
    cells.map((text, at) => (columns[at].kind === 'number' && CSV_NUMBER.test(text) ? text : csvField(text)))
  );
  return CSV_BOM + [columns.map((column) => csvField(column.name)), ...body].map((fields) => `${fields.join(',')}\r\n`).join('');
}

/** Where focus is when a key is pressed: the grid or any other control, a tab of the strip, a text field, or an open cell editor. */
export type ShortcutPlace = 'grid' | 'tab' | 'text' | 'editor';

/** What a shortcut does: the control it stands for. */
export type ShortcutAction = 'help' | 'save' | 'goToRow' | 'export' | 'addRow' | 'duplicateRow' | 'deleteRow' | 'page' | 'tab' | 'closeTab';

/** The parts of a key event a shortcut reads, so the matchers run on a plain object under `node --test`. */
export interface ShortcutEvent {
  readonly key: string;
  readonly code: string;
  readonly ctrlKey: boolean;
  readonly metaKey: boolean;
  readonly altKey: boolean;
  readonly shiftKey: boolean;
}

/** One shortcut: what it does, its label and keys as the help dialog lists them, and whether `event` in `place` is its chord. */
export interface DataBrowserShortcut {
  readonly action: ShortcutAction;
  readonly labelKey: keyof typeof STRINGS;
  readonly keysKey: keyof typeof STRINGS;
  readonly matches: (event: ShortcutEvent, place: ShortcutPlace) => boolean;
}

/** Ctrl, or Cmd on a Mac, with `letter` by its key in any case, and neither Alt nor Shift. */
function controlLetter(event: ShortcutEvent, letter: string): boolean {
  return (event.ctrlKey || event.metaKey) && !event.altKey && !event.shiftKey && event.key.toLowerCase() === letter;
}

/** Alt/Option and Shift with no Ctrl or Cmd: the product's chord family (the data table's resize). */
function optionShift(event: ShortcutEvent): boolean {
  return event.altKey && event.shiftKey && !event.ctrlKey && !event.metaKey;
}

/**
 * Alt/Option+Shift with `letter`, by its key in any case, or by its physical key when the key is no
 * ASCII letter, since macOS answers Option+Shift+letter with another character. A key that is a
 * letter is read as that letter, so on another layout the physical key never makes a chord the
 * browser reads as a different letter's (Dvorak's KeyN types B: Chrome's Alt+Shift+B).
 */
function optionShiftLetter(event: ShortcutEvent, letter: string): boolean {
  if (!optionShift(event)) return false;
  if (/^[a-z]$/i.test(event.key)) return event.key.toLowerCase() === letter;
  return event.code === `Key${letter.toUpperCase()}`;
}

function isPageKey(event: ShortcutEvent): boolean {
  return event.key === 'PageDown' || event.key === 'PageUp';
}

/**
 * Data browser's shortcuts, in the order its Keyboard shortcuts dialog lists them. The page handles
 * exactly these chords and the dialog lists exactly these rows, so the dialog cannot name a chord
 * that is not bound. None is a command Chromium reserves (Ctrl/Cmd+N, Ctrl+Shift+N, Ctrl+T,
 * Ctrl+Shift+T, Ctrl+W, Ctrl+F4, Ctrl+Shift+W, Ctrl+Tab, Ctrl+Shift+Tab, Ctrl+PageDown, Ctrl+PageUp),
 * a zoom or reload chord, the shell's Ctrl/Cmd+K, I or B, Chrome's Alt+Shift A, B, R or T, or a
 * single character; Delete closes only a focused tab, so the grid's Delete still stages NULL.
 */
export const DATA_BROWSER_SHORTCUTS: readonly DataBrowserShortcut[] = [
  {
    action: 'help',
    labelKey: 'explorerSqlDataShortcuts',
    keysKey: 'explorerSqlDataKeysHelp',
    // Shift is ignored, for the layouts that type `/` with it.
    matches: (event) => (event.ctrlKey || event.metaKey) && !event.altKey && event.key === '/',
  },
  { action: 'save', labelKey: 'explorerSqlDataSaveShortcut', keysKey: 'explorerSqlDataKeysSave', matches: (event) => controlLetter(event, 's') },
  { action: 'goToRow', labelKey: 'explorerSqlDataGoToRow', keysKey: 'explorerSqlDataKeysGoToRow', matches: (event) => controlLetter(event, 'g') },
  { action: 'export', labelKey: 'tableDownloadCsv', keysKey: 'explorerSqlDataKeysExport', matches: (event) => controlLetter(event, 'e') },
  { action: 'addRow', labelKey: 'explorerSqlDataAddRow', keysKey: 'explorerSqlDataKeysAddRow', matches: (event) => optionShiftLetter(event, 'n') },
  { action: 'duplicateRow', labelKey: 'explorerSqlDataDuplicateRow', keysKey: 'explorerSqlDataKeysDuplicateRow', matches: (event) => optionShiftLetter(event, 'd') },
  {
    action: 'deleteRow',
    labelKey: 'explorerSqlDataDeleteRow',
    keysKey: 'explorerSqlDataKeysDeleteRow',
    matches: (event) => optionShift(event) && (event.key === 'Delete' || event.key === 'Backspace'),
  },
  {
    action: 'page',
    labelKey: 'explorerSqlDataPageShortcut',
    keysKey: 'explorerSqlDataKeysPage',
    matches: (event) => event.altKey && !event.shiftKey && !event.ctrlKey && !event.metaKey && isPageKey(event),
  },
  { action: 'tab', labelKey: 'explorerSqlDataTabShortcut', keysKey: 'explorerSqlDataKeysTab', matches: (event) => optionShift(event) && isPageKey(event) },
  {
    action: 'closeTab',
    labelKey: 'explorerSqlDataCloseTab',
    keysKey: 'explorerSqlDataKeysCloseTab',
    matches: (event, place) =>
      optionShiftLetter(event, 'w') ||
      (place === 'tab' && event.key === 'Delete' && !event.altKey && !event.shiftKey && !event.ctrlKey && !event.metaKey),
  },
];

/**
 * The action `event` asks for in `place`, or `null`. With an editor open only Save acts, and an
 * Alt/Option chord does nothing in a text field, which still types its character.
 */
export function shortcutFor(event: ShortcutEvent, place: ShortcutPlace): ShortcutAction | null {
  for (const shortcut of DATA_BROWSER_SHORTCUTS) {
    if (place === 'editor' && shortcut.action !== 'save') continue;
    if (place === 'text' && event.altKey) continue;
    if (shortcut.matches(event, place)) return shortcut.action;
  }
  return null;
}

/** The direction a page or tab chord moves: PageDown forward, PageUp back. */
export function shortcutStep(event: ShortcutEvent): 1 | -1 {
  return event.key === 'PageDown' ? 1 : -1;
}
