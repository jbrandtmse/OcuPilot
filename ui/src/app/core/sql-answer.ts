/**
 * What a SQL statement's run answered, as the console and a confirmed run's card read it (AD-39's sixth
 * exception, Stories 19.6 and 19.11): the answer's shape, the status line it reads as, and the lines a
 * confirmed run's `output` shows on a proposal card.
 *
 * Framework-free, and in `core/` because the proposal card (`turn.ts`) and the SQL query page both read
 * it; the console's store re-exports it. Nothing here is stored or sent: the rows, the SQLCODE and the
 * message live on the screen and the card alone.
 */

import { STRINGS } from './strings.ts';

/** `template` with each `<placeholder>` of `values` replaced. */
function fill(template: string, values: Readonly<Record<string, string | number>>): string {
  let result = template;
  for (const [key, value] of Object.entries(values)) result = result.split(`<${key}>`).join(String(value));
  return result;
}

/** `one` at exactly 1, `many` at 0 and at 2 or more. */
function pick(count: number, one: string, many: string): string {
  return count === 1 ? one : many;
}

function text(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

function texts(value: unknown): readonly string[] {
  return Array.isArray(value) ? value.map((entry) => (typeof entry === 'string' ? entry : String(entry ?? ''))) : [];
}

/** The rows a query or a CALL answered, as text cells. */
export interface SqlRows {
  readonly columns: readonly string[];
  readonly rows: readonly (readonly string[])[];
  readonly truncated: boolean;
}

/** What the instance last answered, as the page draws it. */
export type SqlAnswer =
  | { readonly outcome: 'rows'; readonly kind: string; readonly result: SqlRows }
  | { readonly outcome: 'done'; readonly kind: string; readonly rowCount: number }
  | { readonly outcome: 'error'; readonly kind: string; readonly sqlcode: number | null; readonly message: string; readonly rolledBack: boolean }
  | { readonly outcome: 'stopped'; readonly kind: string; readonly seconds: number }
  | { readonly outcome: 'parameters'; readonly count: number }
  | { readonly outcome: 'plan'; readonly plan: string; readonly truncated: boolean }
  | { readonly outcome: 'noplan' };

/** The rows of an answer, each a list of text cells, or `null`. */
function rowsOf(record: Readonly<Record<string, unknown>>): SqlRows | null {
  const rows = record['rows'];
  if (!Array.isArray(rows)) return null;
  return {
    columns: texts(record['columns']),
    rows: rows.map((row) => texts(row)),
    truncated: record['truncated'] === true,
  };
}

/** One answer of the run route, the plan route or a confirmed run's `output`, or `null` for any other shape. */
export function answerOf(body: unknown): SqlAnswer | null {
  if (body === null || typeof body !== 'object') return null;
  const record = body as Readonly<Record<string, unknown>>;
  const kind = text(record['kind']);
  switch (record['outcome']) {
    case 'rows': {
      const result = rowsOf(record);
      return result === null ? null : { outcome: 'rows', kind, result };
    }
    case 'done':
      return { outcome: 'done', kind, rowCount: typeof record['rowCount'] === 'number' ? record['rowCount'] : 0 };
    case 'error':
      return {
        outcome: 'error',
        kind,
        sqlcode: typeof record['sqlcode'] === 'number' ? record['sqlcode'] : null,
        message: text(record['message']),
        rolledBack: record['rolledBack'] === true,
      };
    case 'stopped':
      return { outcome: 'stopped', kind, seconds: typeof record['seconds'] === 'number' ? record['seconds'] : 0 };
    case 'parameters':
      return { outcome: 'parameters', count: typeof record['count'] === 'number' ? record['count'] : 0 };
    case 'plan':
      return { outcome: 'plan', plan: text(record['plan']), truncated: record['truncated'] === true };
    case 'noplan':
      return { outcome: 'noplan' };
    default:
      return null;
  }
}

/** The status line an answer reads, or the empty console's invitation before any. */
export function statusLineFor(answer: SqlAnswer | null): string {
  if (answer === null) return STRINGS.explorerSqlEmpty;
  switch (answer.outcome) {
    case 'rows':
      return fill(
        answer.result.truncated
          ? pick(answer.result.rows.length, STRINGS.explorerSqlRowsCutOne, STRINGS.explorerSqlRowsCut)
          : pick(answer.result.rows.length, STRINGS.explorerSqlRowCountOne, STRINGS.tableRowCount),
        { n: answer.result.rows.length },
      );
    case 'done':
      return answer.kind === 'dml' ? fill(pick(answer.rowCount, STRINGS.explorerSqlRowsChangedOne, STRINGS.explorerSqlRowsChanged), { n: answer.rowCount }) : STRINGS.explorerSqlDone;
    case 'error':
      if (answer.sqlcode !== null) return fill(STRINGS.explorerSqlCode, { code: answer.sqlcode });
      return answer.rolledBack ? STRINGS.explorerSqlRolledBack : '';
    case 'stopped':
      return fill(answer.kind === 'dml' ? STRINGS.explorerSqlStoppedUndone : STRINGS.explorerSqlStopped, { s: answer.seconds });
    case 'parameters':
      return fill(pick(answer.count, STRINGS.explorerSqlTakesValuesOne, STRINGS.explorerSqlTakesValues), { n: answer.count });
    case 'noplan':
      return STRINGS.explorerSqlNoPlan;
    case 'plan':
      return '';
  }
}

/**
 * The lines a confirmed SQL run's `output` shows on its proposal card: its status line, and for an
 * `error` outcome the instance's own message beneath it. `[]` for an `output` that is not a run's answer.
 */
export function sqlOutcomeLines(output: unknown): readonly string[] {
  const answer = answerOf(output);
  if (answer === null) return [];
  const line = statusLineFor(answer);
  const lines = line === '' ? [] : [line];
  if (answer.outcome === 'error' && answer.message !== '') lines.push(answer.message);
  return lines;
}
