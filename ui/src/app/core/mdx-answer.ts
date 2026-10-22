/**
 * What an MDX run answered, as the MDX query page reads it (AD-39's sixth exception, Story 20.33): the
 * answer's shape, the status line it reads as, and the ask-first answer a start gives for a statement
 * whose text the instance asks the person to confirm.
 *
 * Framework-free, and in `core/` beside `sql-answer.ts`, whose listing reader it imports. Nothing here
 * is stored or sent: the cells, the listing and the vendor's error text live on the screen alone.
 */

import { pickCount } from './count-phrase.ts';
import { answerOf, statusLineFor, type SqlRows } from './sql-answer.ts';
import { STRINGS } from './strings.ts';

/** `template` with each `<placeholder>` of `values` replaced. */
function fill(template: string, values: Readonly<Record<string, string | number>>): string {
  let result = template;
  for (const [key, value] of Object.entries(values)) result = result.split(`<${key}>`).join(String(value));
  return result;
}

function text(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

function texts(value: unknown): readonly string[] {
  return Array.isArray(value) ? value.map((entry) => (typeof entry === 'string' ? entry : String(entry ?? ''))) : [];
}

function whole(value: unknown, otherwise: number): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : otherwise;
}

/** One row of the cells grid: the labels of its position on the rows axis, and a cell for each column. */
export interface MdxRow {
  readonly label: string;
  readonly cells: readonly string[];
}

/** The grid a SELECT answered, bounded by the instance's row and column caps. */
export interface MdxCells {
  readonly outcome: 'cells';
  readonly cube: string;
  readonly columns: readonly string[];
  readonly rows: readonly MdxRow[];
  /** How many row and column positions the answer holds, of which `rows` and `columns` are the first. */
  readonly rowsAvailable: number;
  readonly columnsAvailable: number;
  readonly truncated: boolean;
  readonly seconds: number;
}

/** What a run last answered, as the page draws it. */
export type MdxAnswer =
  | MdxCells
  | { readonly outcome: 'rows'; readonly result: SqlRows }
  | { readonly outcome: 'error'; readonly message: string }
  | { readonly outcome: 'stopped'; readonly seconds: number };

/** The grid of a `cells` answer, or `null` when its rows are not a list. */
function cellsOf(record: Readonly<Record<string, unknown>>): MdxCells | null {
  const listed = record['rows'];
  if (!Array.isArray(listed)) return null;
  const columns = texts(record['columns']);
  const rows = listed.map((entry): MdxRow => {
    const row = entry !== null && typeof entry === 'object' ? (entry as Readonly<Record<string, unknown>>) : {};
    return { label: text(row['label']), cells: texts(row['cells']) };
  });
  return {
    outcome: 'cells',
    cube: text(record['cube']),
    columns,
    rows,
    rowsAvailable: whole(record['rowsAvailable'], rows.length),
    columnsAvailable: whole(record['columnsAvailable'], columns.length),
    truncated: record['truncated'] === true,
    seconds: whole(record['seconds'], 0),
  };
}

/** One answer of an MDX run (a poll's `result`, or a start's immediate answer), or `null` for any other shape. */
export function mdxAnswerOf(body: unknown): MdxAnswer | null {
  if (body === null || typeof body !== 'object') return null;
  const record = body as Readonly<Record<string, unknown>>;
  switch (record['outcome']) {
    case 'cells':
      return cellsOf(record);
    case 'rows': {
      const listing = answerOf(body);
      return listing !== null && listing.outcome === 'rows' ? { outcome: 'rows', result: listing.result } : null;
    }
    case 'error':
      return { outcome: 'error', message: text(record['message']) };
    case 'stopped':
      return { outcome: 'stopped', seconds: whole(record['seconds'], 0) };
    default:
      return null;
  }
}

/**
 * The constructs a start's `confirm` answer names, or `null` for any other body. A statement the
 * instance could not read is a `confirm` whose list is empty: `[]`, which is an answer, never `null`.
 */
export function mdxConfirmOf(body: unknown): readonly string[] | null {
  if (body === null || typeof body !== 'object') return null;
  const record = body as Readonly<Record<string, unknown>>;
  if (record['outcome'] !== 'confirm') return null;
  return texts(record['constructs']);
}

/** The status line an answer reads, or the empty page's invitation before any. */
export function mdxStatusLineFor(answer: MdxAnswer | null): string {
  if (answer === null) return STRINGS.analyticsMdxEmpty;
  switch (answer.outcome) {
    case 'cells': {
      const line = fill(STRINGS.analyticsMdxCellsLine, {
        r: answer.rows.length,
        R: answer.rowsAvailable,
        c: answer.columns.length,
        C: answer.columnsAvailable,
      });
      return answer.truncated ? `${line} ${STRINGS.analyticsMdxCut}` : line;
    }
    case 'rows':
      return statusLineFor({ outcome: 'rows', kind: '', result: answer.result });
    case 'error':
      return STRINGS.analyticsMdxErrorLine;
    case 'stopped':
      return fill(pickCount(answer.seconds, STRINGS.explorerSqlStoppedOne, STRINGS.explorerSqlStopped), { s: answer.seconds });
  }
}
