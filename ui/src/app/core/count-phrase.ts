/**
 * The one rule that chooses between a count sentence's singular and its plural.
 *
 * A count of exactly 1 reads the singular; 0 and every count of 2 or more read the plural. A count
 * sentence that can be filled with 1 has a singular, and it is chosen through `pickCount`, never by a
 * comparison of its own; `ui/tools/count-phrase.test.mjs` scans the app source for one. A count fixed
 * above 1 (a declared cap or maximum) has no singular. A sentence with two counts picks nested, the
 * outer pick on the first count. A sentence carrying a schedule's "every N" is wording about a
 * cadence, not a count, and is chosen where it is built.
 *
 * Framework-free, like the rest of `core/`, so `node --test` executes it.
 */

import { STRINGS } from './strings.ts';
import { formatCapNotice, formatRowCount } from './table-model.ts';

/** `one` at exactly 1, `many` at 0 and at 2 or more. */
export function pickCount(count: number, one: string, many: string): string {
  return count === 1 ? one : many;
}

/**
 * The footer's, the filter's and the context chip's row count: "1 row" at one, "<n> rows" otherwise,
 * the number grouped in thousands.
 */
export function rowCountPhrase(count: number): string {
  return formatRowCount(pickCount(count, STRINGS.explorerSqlRowCountOne, STRINGS.tableRowCount), count);
}

/** The data table's cap notice with the store's cap filled in: "Showing the first row." at a cap of one. */
export function capNoticePhrase(cap: number): string {
  return formatCapNotice(pickCount(cap, STRINGS.tableRowCapNoticeOne, STRINGS.tableRowCapNotice), cap);
}

/** The Download CSV control's description at the cap: "The file holds the first row only." at a cap of one. */
export function downloadCappedPhrase(cap: number): string {
  return formatCapNotice(pickCount(cap, STRINGS.tableDownloadCsvCappedOne, STRINGS.tableDownloadCsvCapped), cap);
}
