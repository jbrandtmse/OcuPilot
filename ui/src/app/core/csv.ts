/**
 * A data table's view as a CSV file (Story 16.23): the field encoder, the file text and its name.
 * `shell/data-table.ts` decides which rows and columns go in and saves the result; nothing here
 * reads a store or touches the page.
 *
 * Framework-free, like the rest of `core/`, so `ui/tools/csv.test.mjs` executes it under
 * `node --test`.
 */

import type { TableColumn } from './screens.generated';
import { cellView, fieldOf } from './table-model.ts';

/** The UTF-8 byte-order mark a spreadsheet reads the file's encoding from (Rule 14: an escape). */
export const CSV_BOM = '\ufeff';

/** The characters a spreadsheet may read as the start of a formula. */
const FORMULA_LEAD = /^[=+\-@\t\r]/;

/** The characters that make a field need quoting (RFC 4180). */
const NEEDS_QUOTES = /[",\r\n]/;

/**
 * One field: a leading `'` where the text starts like a formula, then RFC 4180 quoting where the
 * text holds a quote, a comma, a CR or an LF, with each inner quote doubled.
 */
export function csvField(text: string): string {
  const guarded = FORMULA_LEAD.test(text) ? `'${text}` : text;
  return NEEDS_QUOTES.test(guarded) ? `"${guarded.replace(/"/g, '""')}"` : guarded;
}

/** The file's text: the BOM, then the header and each row as fields joined by `,`, each line ending CRLF. */
export function csvText(header: readonly string[], rows: readonly (readonly string[])[]): string {
  return CSV_BOM + [header, ...rows].map((row) => `${row.map(csvField).join(',')}\r\n`).join('');
}

/**
 * Each row's cells in `columns` order, as the table displays them (`cellView`): Yes/No, a declared
 * `emptyKey` word. The "(none)" placeholder and a column still in `pendingFields` are written
 * empty. Only the declared columns are read, so a field the row carries and the table does not
 * show never reaches the file.
 */
export function tableCsvRows(
  rows: readonly unknown[],
  columns: readonly TableColumn[],
  lookup: (key: string) => string,
  pendingFields: readonly string[] = []
): string[][] {
  return rows.map((row) =>
    columns.map((column) => {
      if (pendingFields.includes(column.field)) return '';
      const view = cellView(fieldOf(row, column.field), column.kind, column.emptyKey ?? '', lookup);
      return view.empty ? '' : view.text;
    })
  );
}

/**
 * `<slug>-<YYYYMMDD>-<HHMMSS>.csv` in `date`'s local time. The slug is `label` lower-cased with
 * each run of anything outside `[a-z0-9]` turned into one `-` and the ends trimmed, or `table`
 * where nothing is left.
 */
export function csvFileName(label: string, date: Date): string {
  const slug = label.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '') || 'table';
  const two = (value: number) => String(value).padStart(2, '0');
  const day = `${date.getFullYear()}${two(date.getMonth() + 1)}${two(date.getDate())}`;
  const time = `${two(date.getHours())}${two(date.getMinutes())}${two(date.getSeconds())}`;
  return `${slug}-${day}-${time}.csv`;
}
