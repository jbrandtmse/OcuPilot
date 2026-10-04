/**
 * System Explorer's SQL query state (AD-19, Story 19.6): the statement being written, the values the
 * instance asked for, Max rows, whether a request is running, the instance's last answer, the
 * statement a confirmation waits on, and the refusal on screen.
 *
 * **Framework-free.** It imports nothing from Angular; `sql-query.page.ts` holds one per screen store
 * and hands it what it needs as plain functions, so the component spec drives it directly.
 *
 * **Nothing that changes state is decided here** (AD-11). Run posts the statement to the console's
 * run route, which answers rows for a query and `confirm` for anything else; only then is the
 * confirmation drawn, and Proceed sends the screen action `run` (AD-53), which classifies the
 * statement again on the instance. Explain plan posts to the plan route and executes nothing.
 *
 * **The answer is screen-only** (AD-39's sixth exception): rows, an SQL error and a plan live in this
 * state and are rendered as text; none of it enters the screen's store, so none of it reaches screen
 * context.
 */

import type { ApiService, JsonResult } from '../../core/api';
import { STRINGS } from '../../core/strings';
import type { ActionRefusal, ActionSink, ActionValues } from '../../shell/screen-action-handler';
import { fillPlaceholders } from './code-list.store';

/** The console's two routes. */
export const SQL_RUN_PATH = '/api/ocupilot/explorer/sql/run';
export const SQL_PLAN_PATH = '/api/ocupilot/explorer/sql/plan';

/** The screen action a confirmed run sends, its one target and its three declared values (AD-56 (ii)). */
export const RUN_ACTION = 'run';
export const RUN_TARGET = 'sql';
export const STATEMENT_VALUE = 'statement';
export const PARAMETERS_VALUE = 'parameters';
export const MAX_ROWS_VALUE = 'maxRows';

/** Max rows before the person changes it. */
export const DEFAULT_MAX_ROWS = '1000';

/** The machine code a privilege denial carries (AD-39), whose pair the refusal names. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

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

/** A statement the instance answered `confirm` for, waiting on the person's Proceed. */
export interface SqlConfirm {
  readonly kind: string;
  readonly tables: readonly string[];
}

/** What sends the confirmed run and answers its outcome: the shell's `ScreenActionHandler`. */
export interface RunSender {
  sendFor(descriptor: string, actionId: string, target: string, values?: ActionValues, sink?: ActionSink, scope?: string): Promise<boolean>;
  lastOutput(): unknown;
  lastRefusal(): ActionRefusal | null;
}

/** What the console posts through, sends its confirmed run through, and the namespace it is scoped to. */
export interface SqlQueryDeps {
  readonly api: Pick<ApiService, 'requestJson'>;
  readonly sender: RunSender;
  readonly descriptor: string;
  readonly scope: () => string;
}

function text(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

function texts(value: unknown): readonly string[] {
  return Array.isArray(value) ? value.map((entry) => (typeof entry === 'string' ? entry : String(entry ?? ''))) : [];
}

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

/** The run route's `confirm` answer, or `null`. */
export function confirmOf(body: unknown): SqlConfirm | null {
  if (body === null || typeof body !== 'object') return null;
  const record = body as Readonly<Record<string, unknown>>;
  if (record['outcome'] !== 'confirm') return null;
  return { kind: text(record['kind']), tables: texts(record['tables']) };
}

/** The confirmation's consequence for a statement of `kind` over `tables`: one sentence per kind. */
export function consequenceFor(confirm: SqlConfirm): string {
  if (confirm.kind === 'dml') return fillPlaceholders(STRINGS.explorerSqlConfirmDml, { tables: confirm.tables.join(', ') });
  if (confirm.kind === 'ddl') return STRINGS.explorerSqlConfirmDdl;
  if (confirm.kind === 'call') return STRINGS.explorerSqlConfirmCall;
  return STRINGS.explorerSqlConfirmOther;
}

/** The status line an answer reads, or the empty console's invitation before any. */
export function statusLineFor(answer: SqlAnswer | null): string {
  if (answer === null) return STRINGS.explorerSqlEmpty;
  switch (answer.outcome) {
    case 'rows':
      return fillPlaceholders(answer.result.truncated ? STRINGS.explorerSqlRowsCut : STRINGS.tableRowCount, { n: answer.result.rows.length });
    case 'done':
      return answer.kind === 'dml' ? fillPlaceholders(STRINGS.explorerSqlRowsChanged, { n: answer.rowCount }) : STRINGS.explorerSqlDone;
    case 'error':
      if (answer.sqlcode !== null) return fillPlaceholders(STRINGS.explorerSqlCode, { code: answer.sqlcode });
      return answer.rolledBack ? STRINGS.explorerSqlRolledBack : '';
    case 'stopped':
      return fillPlaceholders(answer.kind === 'dml' ? STRINGS.explorerSqlStoppedUndone : STRINGS.explorerSqlStopped, { s: answer.seconds });
    case 'parameters':
      return fillPlaceholders(STRINGS.explorerSqlTakesValues, { n: answer.count });
    case 'noplan':
      return STRINGS.explorerSqlNoPlan;
    case 'plan':
      return '';
  }
}

/** The sentence a refusal shows: a privilege denial names the pair it lacks (AD-8), any other the envelope's own (AD-39). */
export function refusalText(code: string | null, reason: string | null, detail: Readonly<Record<string, unknown>> | null): string {
  const pair = detail?.['failedPair'];
  if (code === NO_PRIVILEGE_CODE && typeof pair === 'string' && pair !== '') {
    return fillPlaceholders(STRINGS.privilegeRequiresResource, { resource: pair });
  }
  return reason ?? '';
}

export class SqlQueryState {
  private textValue = '';

  private valuesValue: readonly string[] = [];

  private maxRowsValue = DEFAULT_MAX_ROWS;

  private runningValue = false;

  private answerValue: SqlAnswer | null = null;

  private confirmValue: SqlConfirm | null = null;

  private refusalValue = '';

  /** Which request is current; an answer to an older one is dropped. */
  private generation = 0;

  private readonly listeners = new Set<() => void>();

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  text(): string {
    return this.textValue;
  }

  /** The value fields' contents, one per value the instance asked for, `[]` before it asks. */
  values(): readonly string[] {
    return this.valuesValue;
  }

  maxRows(): string {
    return this.maxRowsValue;
  }

  running(): boolean {
    return this.runningValue;
  }

  answer(): SqlAnswer | null {
    return this.answerValue;
  }

  /** The statement a confirmation waits on, or `null`. */
  confirm(): SqlConfirm | null {
    return this.confirmValue;
  }

  refusal(): string {
    return this.refusalValue;
  }

  /** A new statement: the value fields and the last answer belong to the old one, so both go. */
  setText(value: string): void {
    if (value === this.textValue) return;
    this.textValue = value;
    this.valuesValue = [];
    this.answerValue = null;
    this.refusalValue = '';
    this.notify();
  }

  setValue(index: number, value: string): void {
    if (index < 0 || index >= this.valuesValue.length) return;
    this.valuesValue = this.valuesValue.map((entry, at) => (at === index ? value : entry));
    this.notify();
  }

  setMaxRows(value: string): void {
    this.maxRowsValue = value;
    this.notify();
  }

  /**
   * Run: post the statement, its values and Max rows. Rows, an SQL error or a stop are shown; a
   * `parameters` answer draws that many empty value fields; a `confirm` answer waits on Proceed and
   * runs nothing; a refusal keeps the statement and shows its sentence.
   */
  async run(deps: SqlQueryDeps): Promise<void> {
    const result = await this.post(deps, SQL_RUN_PATH, true);
    if (result === null) return;
    const confirm = confirmOf(result);
    if (confirm !== null) {
      this.confirmValue = confirm;
      this.notify();
      return;
    }
    this.adopt(answerOf(result));
  }

  /** Explain plan: post the statement to the plan route, which executes nothing, and show the plan. */
  async plan(deps: SqlQueryDeps): Promise<void> {
    const result = await this.post(deps, SQL_PLAN_PATH, false);
    if (result === null) return;
    this.adopt(answerOf(result));
  }

  /** Proceed: send the confirmed run as the screen action, and show what the instance answered. */
  async proceed(deps: SqlQueryDeps): Promise<boolean> {
    if (this.confirmValue === null) return false;
    const generation = ++this.generation;
    this.confirmValue = null;
    this.runningValue = true;
    this.refusalValue = '';
    this.notify();
    let refused = '';
    const sink: ActionSink = { setRefusal: (reason) => (refused = reason) };
    const maxRows = this.maxRowsValue.trim();
    const values: ActionValues = {
      [STATEMENT_VALUE]: this.textValue,
      [PARAMETERS_VALUE]: JSON.stringify(this.valuesValue),
      // Digits as the run route's number reads them, so a leading zero confirmed there is not refused here.
      [MAX_ROWS_VALUE]: /^[0-9]+$/.test(maxRows) ? String(Number(maxRows)) : maxRows,
    };
    const applied = await deps.sender.sendFor(deps.descriptor, RUN_ACTION, RUN_TARGET, values, sink, deps.scope());
    if (generation !== this.generation) return applied;
    this.runningValue = false;
    if (!applied) {
      const last = deps.sender.lastRefusal();
      this.refusalValue = (last === null ? '' : refusalText(last.code, last.reason, last.detail)) || refused || STRINGS.connectivityRequestRefused;
      this.notify();
      return false;
    }
    this.answerValue = answerOf(deps.sender.lastOutput());
    this.notify();
    return true;
  }

  /** Cancel: the confirmation closes and nothing runs. */
  cancelConfirm(): void {
    if (this.confirmValue === null) return;
    this.confirmValue = null;
    this.notify();
  }

  /** The request a Run or Explain plan posts: the statement, its values and, for a run, Max rows. */
  private body(withMaxRows: boolean): string {
    const maxRows = this.maxRowsValue.trim();
    const body: Record<string, unknown> = { [STATEMENT_VALUE]: this.textValue, [PARAMETERS_VALUE]: this.valuesValue };
    if (withMaxRows) body[MAX_ROWS_VALUE] = /^[0-9]+$/.test(maxRows) ? Number(maxRows) : maxRows;
    return JSON.stringify(body);
  }

  /** Post to `path`; the answer's body, or `null` after a refusal or an older request's answer. */
  private async post(deps: SqlQueryDeps, path: string, withMaxRows: boolean): Promise<unknown> {
    if (this.runningValue) return null;
    const generation = ++this.generation;
    this.runningValue = true;
    this.refusalValue = '';
    this.confirmValue = null;
    this.notify();
    const result: JsonResult<unknown> = await deps.api.requestJson<unknown>(path, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: this.body(withMaxRows),
      scope: deps.scope(),
    });
    if (generation !== this.generation) return null;
    this.runningValue = false;
    if (result.kind !== 'ok') {
      this.refusalValue =
        (result.kind === 'error' ? refusalText(result.code, result.reason, result.detail) : '') || STRINGS.connectivityRequestRefused;
      this.notify();
      return null;
    }
    return result.body;
  }

  /** Show `answer`; a `parameters` answer also draws that many empty value fields. */
  private adopt(answer: SqlAnswer | null): void {
    this.answerValue = answer;
    if (answer !== null && answer.outcome === 'parameters') {
      this.valuesValue = Array.from({ length: answer.count }, (_, at) => this.valuesValue[at] ?? '');
    }
    this.notify();
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
