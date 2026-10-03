/**
 * Journal file details' own rules (Story 18.5), framework-free like `database-details.store.ts`, so
 * the page's spec and `node --test` can exercise them without an Angular test bed.
 */

import type { Fault } from '../../core/fault.ts';
import type { TableColumn } from '../../core/screens.generated.ts';
import { cellView, fieldOf } from '../../core/table-model.ts';

/** The screen whose declared read lists a journal file's databases (AD-5): the page issues it. */
export const JOURNAL_DATABASES_ROUTE = 'os-management/journals/databases';

/** The databases read's row cap: one file's databases are never many (86 at plan, Story 18.5). */
export const JOURNAL_DATABASES_MAX_ROWS = 500;

/**
 * The code the instance refuses a journal file it no longer lists with (AD-21's eighth case). A
 * details read refused with it is the file having left the list -- purged since the list was read --
 * so the page draws its gone state rather than a refusal.
 */
export const JOURNAL_FILE_UNLISTED = 'JOURNAL.FILE.UNLISTED';

/** Whether `fault` is the instance no longer listing the file the page names. */
export function isUnlisted(fault: Fault | null): boolean {
  return fault !== null && fault.code === JOURNAL_FILE_UNLISTED;
}

/** One rendered cell of a row, through the shared `cellView` rule every table uses. */
export interface CellText {
  readonly field: string;
  readonly text: string;
}

/** `row`'s cells for `columns`, in declared order, each rendered as text. */
export function rowCells(columns: readonly TableColumn[], row: unknown): readonly CellText[] {
  return columns.map((column) => ({
    field: column.field,
    text: cellView(fieldOf(row, column.field), column.kind, column.emptyKey ?? '').text,
  }));
}
