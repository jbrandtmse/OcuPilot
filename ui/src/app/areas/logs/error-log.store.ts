import { Injectable, Injector, inject } from '@angular/core';

import { ApiService } from '../../core/api';
import { classifyFault, type Fault } from '../../core/fault';
import { ERROR_LOG_PATH_PREFIX } from '../../core/log-paths';

/** The four drill levels, spelled as the routes that serve them bind them. */
export type ErrorLogLevel = 'namespaces' | 'dates' | 'list' | 'detail';

/** The entity type a confirmed application-error delete publishes on the change bus (AD-13, AD-14). */
export const ERROR_LOG_ENTITY_TYPE = 'application-error';

/**
 * The refusal codes that say the level the user is standing on is no longer there (AD-39). Each is
 * the port's own name for a level the log has stopped carrying, and a drill that meets one steps
 * up rather than showing an empty frame under a scope line that is no longer true.
 */
const VANISHED_LEVEL_CODES: readonly string[] = ['LOG.NAMESPACE', 'LOG.DATE', 'LOG.ENTRY'];

/** One namespace that holds application errors. */
export interface ErrorLogNamespaceRow {
  readonly namespace: string;
}

/** One date that namespace holds errors for, with how many. */
export interface ErrorLogDateRow {
  readonly date: string;
  readonly count: number;
}

/** One error, in the summary projection the list route and the read tool share (AD-48). */
export interface ErrorLogErrorRow {
  readonly errorNumber: number;
  readonly time: string;
  readonly errorText: string;
  readonly routine: string;
  readonly line: string;
  readonly username: string;
  readonly process: string;
}

/** One logged expression and its value. */
export interface ErrorLogExpressionRow {
  readonly expression: string;
  readonly value: string;
}

/** One stack level: its number and the frame text, which already carries the frame's label. */
export interface ErrorLogStackRow {
  readonly level: string;
  readonly detail: string;
}

/** One local variable at one stack level. */
export interface ErrorLogVariableRow {
  readonly level: string;
  readonly name: string;
  readonly value: string;
}

/** One error's captured detail, which never leaves the screen (AD-48). */
export interface ErrorLogDetail {
  readonly expressions: readonly ErrorLogExpressionRow[];
  readonly stack: readonly ErrorLogStackRow[];
  readonly variables: readonly ErrorLogVariableRow[];
  readonly truncated: boolean;
}

function rowsOf(body: unknown): readonly unknown[] {
  if (body === null || typeof body !== 'object') return [];
  const rows = (body as Record<string, unknown>)['rows'];
  return Array.isArray(rows) ? rows : [];
}

/**
 * Whether the answer says the port cut it at the row cap (AD-36, DW-293).
 *
 * Every level computes `truncated` and the client used to read only `rows`, so a list cut at the
 * port's 1,000-row default rendered on screen as the complete set -- the one thing a log viewer
 * must not do. Only a literal `true` counts: an absent flag is not a cut list.
 */
function truncatedAt(body: unknown): boolean {
  if (body === null || typeof body !== 'object') return false;
  return (body as Record<string, unknown>)['truncated'] === true;
}

function textAt(row: unknown, key: string): string {
  if (row === null || typeof row !== 'object') return '';
  const value = (row as Record<string, unknown>)[key];
  return typeof value === 'string' ? value : typeof value === 'number' ? String(value) : '';
}

function numberAt(row: unknown, key: string): number {
  if (row === null || typeof row !== 'object') return 0;
  const value = (row as Record<string, unknown>)[key];
  return typeof value === 'number' ? value : 0;
}

function sectionOf(body: unknown, key: string): readonly unknown[] {
  if (body === null || typeof body !== 'object') return [];
  const value = (body as Record<string, unknown>)[key];
  return Array.isArray(value) ? value : [];
}

/**
 * The application error log's own state: which level the user has drilled to, the namespace and
 * date they drilled through, and the rows each level answered (AD-19).
 *
 * **It is root-provided rather than component-local, and that is load-bearing.** The screen's
 * descriptor declares a composite id, so `buildRoutes` emits a `<route>/:id` route beside the bare
 * one, and any navigation across that boundary destroys and re-creates the page. Drill state in a
 * component field would drop the user back to the namespace list. It is reset on sign-out beside
 * the audit screen's store, for the same reason: what it holds is this principal's own drill.
 *
 * **Every call carries `scope: null`** (`core/api.ts`). The route's `?ns=` is data scope for every
 * other screen (AD-44); this one source overrides it, because the namespace an application error
 * read acts on has exactly one source -- the level the user drilled to -- and it travels under this
 * endpoint's own `namespace` parameter (AD-48). Two sources would let a later delete purge a
 * namespace other than the one on screen.
 *
 * **No declared read, so no `ScreenStore` and no refresh binding.** Three levels with three
 * different column sets cannot be one declared read: `read` is singular, the client's
 * `RefreshService` holds one binding, and one descriptor gets one persisted view entry. This store
 * issues its own reads and holds its own rows.
 *
 * Framework-only in its injection, like `AuditSearch`: the API service is resolved on the first
 * read rather than in the constructor, so constructing the shell does not drag a leaf screen's data
 * dependency in behind it.
 */
@Injectable({ providedIn: 'root' })
export class ErrorLogDrill {
  private readonly injector = inject(Injector);

  private levelValue: ErrorLogLevel = 'namespaces';

  private namespaceValue = '';

  private dateValue = '';

  private errorNumberValue = '';

  private namespaceRows: readonly ErrorLogNamespaceRow[] = [];

  private dateRows: readonly ErrorLogDateRow[] = [];

  private errorRows: readonly ErrorLogErrorRow[] = [];

  private detailValue: ErrorLogDetail | null = null;

  /**
   * Whether the level currently on screen was cut at the row cap (DW-293). One flag rather than
   * one per level, because one level is on screen at a time and every `open*` resets it before its
   * own read -- which is what keeps the previous level's notice from standing under a new scope
   * line, the same rule its rows already follow.
   */
  private truncatedValue = false;

  private loadingValue = false;

  private loadedValue = false;

  private faultValue: Fault | null = null;

  /**
   * The `(resource, permission)` pair the last refusal named (AD-8), or `''` when it named none.
   *
   * Held here rather than on `Fault`: `detail` is still in hand in this store's own error arm, and
   * the page needs the pair only to resolve its own refusal sentence. It is cleared wherever
   * `faultValue` is, so a pair cannot survive into a refusal that carries none.
   */
  private failedPairValue = '';

  /** Bumped per issued read, so a late answer to a level the user has left is dropped. */
  private generation = 0;

  private readonly listeners = new Set<() => void>();

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /**
   * Forget everything this principal had, from the same sign-out teardown as `refresh.reset()`.
   *
   * What it holds is which namespace's errors they were reading and the captured detail of one of
   * them -- which can carry `$ROLES`, `$USERNAME` and, on an IRIS for Health instance, patient data
   * (AD-48). Leaving it in place would show it to whoever signs in next in the same tab.
   */
  reset(): void {
    this.levelValue = 'namespaces';
    this.namespaceValue = '';
    this.dateValue = '';
    this.errorNumberValue = '';
    this.namespaceRows = [];
    this.dateRows = [];
    this.errorRows = [];
    this.detailValue = null;
    this.truncatedValue = false;
    this.loadingValue = false;
    this.loadedValue = false;
    this.faultValue = null;
    this.failedPairValue = '';
    this.generation += 1;
    this.notify();
  }

  level(): ErrorLogLevel {
    return this.levelValue;
  }

  namespace(): string {
    return this.namespaceValue;
  }

  date(): string {
    return this.dateValue;
  }

  errorNumber(): string {
    return this.errorNumberValue;
  }

  namespaces(): readonly ErrorLogNamespaceRow[] {
    return this.namespaceRows;
  }

  dates(): readonly ErrorLogDateRow[] {
    return this.dateRows;
  }

  errors(): readonly ErrorLogErrorRow[] {
    return this.errorRows;
  }

  detail(): ErrorLogDetail | null {
    return this.detailValue;
  }

  /** Whether the level on screen was cut at the row cap (DW-293). */
  truncated(): boolean {
    return this.truncatedValue;
  }

  loading(): boolean {
    return this.loadingValue;
  }

  /** Whether the current level's read has answered at least once since it was opened. */
  loaded(): boolean {
    return this.loadedValue;
  }

  fault(): Fault | null {
    return this.faultValue;
  }

  /** The `(resource, permission)` pair the last refusal named (AD-8), or `''`. */
  failedPair(): string {
    return this.failedPairValue;
  }

  /** The instance-wide namespace list: the drill's first level, and where Back from a date ends. */
  openNamespaces(): Promise<void> {
    this.levelValue = 'namespaces';
    this.namespaceValue = '';
    this.dateValue = '';
    this.errorNumberValue = '';
    this.namespaceRows = [];
    this.detailValue = null;
    this.truncatedValue = false;
    return this.read('namespaces', {});
  }

  /**
   * One namespace's dates.
   *
   * The level's own rows are dropped before the read, not on its answer. A refused read never
   * reaches `absorb()`, so rows kept here would render under the NEW scope line — and on this
   * screen a 403 for one namespace while another is served is the ordinary case, not an exotic one
   * (AD-48). Showing namespace A's errors under a line reading B is the one failure this screen
   * must not have.
   */
  openDates(namespace: string): Promise<void> {
    this.levelValue = 'dates';
    this.namespaceValue = namespace;
    this.dateValue = '';
    this.errorNumberValue = '';
    this.dateRows = [];
    this.detailValue = null;
    this.truncatedValue = false;
    return this.read('dates', { namespace });
  }

  /** One namespace and date's errors. Drops its own rows first, for `openDates`'s reason. */
  openList(date: string): Promise<void> {
    this.levelValue = 'list';
    this.dateValue = date;
    this.errorNumberValue = '';
    this.errorRows = [];
    this.detailValue = null;
    this.truncatedValue = false;
    return this.read('list', { namespace: this.namespaceValue, date });
  }

  /**
   * One error's captured detail. This is the only call in the client that reaches `ErrorDetail`,
   * and the only surface the variable table renders on: the read tool carries the five summary
   * fields and never this (AD-48).
   */
  openDetail(errorNumber: number): Promise<void> {
    this.levelValue = 'detail';
    this.errorNumberValue = String(errorNumber);
    this.detailValue = null;
    this.truncatedValue = false;
    return this.read('detail', {
      namespace: this.namespaceValue,
      date: this.dateValue,
      errorNumber: String(errorNumber),
    });
  }

  /**
   * Re-read the level the user is on, in place (DW-260).
   *
   * Not `back()` and not a fresh drill: the namespace, the date and the error number stay where
   * they are, and only the rows are read again.
   *
   * **It does not go through `open*`, because those drop the level's rows first.** A drill step
   * clears the rows it is leaving so the previous level's contents never sit under a new scope
   * line; a refresh is the opposite -- the scope has not changed, and the rows on screen are the
   * ones being replaced. Routed through `open*` the rows blanked and `showSkeleton` -- which is
   * `loading()` over an empty view -- drew the first-load skeleton over them, which is what
   * "Refresh is silent: no skeleton, no announcement" forbids. Sending the read directly leaves
   * the rows standing until `absorb()` swaps them.
   */
  reopen(): Promise<void> {
    if (this.levelValue === 'detail') {
      return this.read('detail', {
        namespace: this.namespaceValue,
        date: this.dateValue,
        errorNumber: this.errorNumberValue,
      });
    }
    if (this.levelValue === 'list') {
      return this.read('list', { namespace: this.namespaceValue, date: this.dateValue });
    }
    if (this.levelValue === 'dates') return this.read('dates', { namespace: this.namespaceValue });
    return this.read('namespaces', {});
  }

  /**
   * Re-read in place after a confirmed delete against `namespace` (AD-14: a screen showing the
   * type re-fetches and never patches its own rows).
   *
   * **It re-reads, it does not remove a row.** The rows that leave are the ones the instance stops
   * answering with, so a delete that removed less than the card listed still shows the truth.
   *
   * **It steps up when the level the user is on has gone.** A namespace with no errors left
   * carries no dates, no list and no detail, and the port answers each of those with its own
   * refusal code; the drill walks back until it reaches a level the instance still serves. The
   * loop is bounded by the three levels above `namespaces`, which is where every walk ends.
   *
   * A delete against another namespace changes nothing below the top level, so a drill inside one
   * namespace ignores an event about another; the top level re-reads either way, because the
   * purged namespace leaves its list.
   */
  async applyDeleted(namespace: string): Promise<void> {
    if (this.levelValue !== 'namespaces' && !sameNamespace(this.namespaceValue, namespace)) return;
    await this.reopen();
    for (let step = 0; step < 3; step += 1) {
      const code = this.faultValue === null ? null : this.faultValue.code;
      if (code === null || !VANISHED_LEVEL_CODES.includes(code)) return;
      await this.back();
    }
  }

  /** Back one level, which is where the drill's own affordance goes. */
  back(): Promise<void> {
    if (this.levelValue === 'detail') return this.openList(this.dateValue);
    if (this.levelValue === 'list') return this.openDates(this.namespaceValue);
    if (this.levelValue === 'dates') return this.openNamespaces();
    return Promise.resolve();
  }

  private async read(level: ErrorLogLevel, params: Readonly<Record<string, string>>): Promise<void> {
    const generation = (this.generation += 1);
    this.loadingValue = true;
    this.loadedValue = false;
    this.faultValue = null;
    this.failedPairValue = '';
    this.notify();

    const query = Object.entries(params)
      .map(([key, value]) => encodeURIComponent(key) + '=' + encodeURIComponent(value))
      .join('&');
    const path = ERROR_LOG_PATH_PREFIX + level + (query === '' ? '' : '?' + query);
    const result = await this.injector.get(ApiService).requestJson<unknown>(path, { scope: null });
    if (generation !== this.generation) return;

    this.loadingValue = false;
    if (result.kind !== 'ok') {
      this.faultValue = classifyFault(result, path);
      // The `installing` arm carries no `detail`, so the narrow is required rather than defensive.
      if (result.kind === 'error') {
        const pair = result.detail === null ? undefined : result.detail['failedPair'];
        this.failedPairValue = typeof pair === 'string' ? pair : '';
      }
      this.notify();
      return;
    }
    this.loadedValue = true;
    this.absorb(level, result.body);
    this.notify();
  }

  private absorb(level: ErrorLogLevel, body: unknown): void {
    // Read once, for every level: the flag is on the answer's envelope, not inside its rows, and
    // reading it per branch is how three of the four dropped it (DW-293).
    this.truncatedValue = truncatedAt(body);
    if (level === 'namespaces') {
      this.namespaceRows = rowsOf(body).map((row) => ({ namespace: textAt(row, 'namespace') }));
      return;
    }
    if (level === 'dates') {
      this.dateRows = rowsOf(body).map((row) => ({
        date: textAt(row, 'date'),
        count: numberAt(row, 'count'),
      }));
      return;
    }
    if (level === 'list') {
      this.errorRows = rowsOf(body).map((row) => ({
        errorNumber: numberAt(row, 'errorNumber'),
        time: textAt(row, 'time'),
        errorText: textAt(row, 'errorText'),
        routine: textAt(row, 'routine'),
        line: textAt(row, 'line'),
        username: textAt(row, 'username'),
        process: textAt(row, 'process'),
      }));
      return;
    }
    this.detailValue = {
      expressions: sectionOf(body, 'expressions').map((row) => ({
        expression: textAt(row, 'expression'),
        value: textAt(row, 'value'),
      })),
      stack: sectionOf(body, 'stack').map((row) => ({
        level: textAt(row, 'level'),
        detail: textAt(row, 'detail'),
      })),
      variables: sectionOf(body, 'variables').map((row) => ({
        level: textAt(row, 'level'),
        name: textAt(row, 'name'),
        value: textAt(row, 'value'),
      })),
      truncated: truncatedAt(body),
    };
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

/**
 * Whether two namespace spellings name one namespace.
 *
 * `SYS.ApplicationError` resolves a namespace case-insensitively, which is why
 * `application-error` carries the `foldcase` id rule (AD-13) -- so the id a change event carries is
 * the canonical lower-case spelling while the drill holds the instance's own. Comparing them any
 * other way would leave the screen the user is standing on unrefreshed by the very write they just
 * confirmed.
 */
function sameNamespace(held: string, published: string): boolean {
  return held.toLowerCase() === published.toLowerCase();
}
