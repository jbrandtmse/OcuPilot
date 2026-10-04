/**
 * Data browser's pure rules (Story 19.7): the tri-state sort, the grid's cell moves, offset paging,
 * how a cell reads, a column's track, which columns take a filter, and the status lines.
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

/** A column's track in the grid's template: a floor by kind that never shrinks, sharing the rest. */
export function columnTrack(kind: DataKind): string {
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
  return `minmax(${floor[kind] ?? 160}px, 1fr)`;
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
