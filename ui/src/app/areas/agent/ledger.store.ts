import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { builtScreensForArea, orderedAreas, screenForRoute } from '../../core/navigation';
import { STRINGS, stringFor } from '../../core/strings';

/** The one route the agent ledger is read through, absolute from the origin root (AD-20). */
export const LEDGER_PATH = '/api/ocupilot/agent/ledger';

/** The separator a stored reference joins its type, scope and id with (AD-13). */
const REFERENCE_SEPARATOR = '\u0002';

/** How a reference's parts, and a status and its code, are shown joined. */
const PART_JOIN = ' \u00b7 ';

/** The criteria form's four fields. */
export type LedgerField = 'user' | 'route' | 'begin' | 'end';

/** What the form holds. */
export type LedgerForm = Readonly<Record<LedgerField, string>>;

const EMPTY_FORM: LedgerForm = { user: '', route: '', begin: '', end: '' };

/** One ledger row as the route answers it. */
export interface LedgerRow {
  readonly ledgerId: string;
  readonly user: string;
  readonly time: string;
  readonly kind: string;
  readonly name: string;
  readonly model: string;
  readonly route: string;
  readonly target: string;
  readonly arguments: string;
  readonly status: string;
  readonly code: string;
  readonly fields: string;
  readonly fieldsTruncated: boolean;
  readonly auditMarked: string;
  readonly requestTokens: number;
  readonly responseTokens: number;
  readonly requiredPairs: string;
  readonly pairsSense: string;
}

/** The criteria the instance applied, in its local time. */
export interface LedgerCriteria {
  readonly user: string;
  readonly route: string;
  readonly begin: string;
  readonly end: string;
  readonly allUsers: boolean;
}

/** The whole answer. */
export interface LedgerView {
  readonly rows: readonly LedgerRow[];
  readonly truncated: boolean;
  readonly rowsWithheld: number;
  readonly rowsDropped: number;
  readonly criteria: LedgerCriteria;
}

/**
 * Where the search stands: not yet asked, in flight, answered, refused for privilege (403), refused
 * for a criterion (400), or refused otherwise (a store fault, a transport fault).
 */
export type LedgerPhase = 'idle' | 'loading' | 'ready' | 'denied' | 'invalid' | 'refused';

function record(value: unknown): Record<string, unknown> | null {
  return value !== null && typeof value === 'object' && !Array.isArray(value) ? (value as Record<string, unknown>) : null;
}

function text(source: Record<string, unknown>, key: string): string {
  const value = source[key];
  return typeof value === 'string' ? value : '';
}

function count(source: Record<string, unknown>, key: string): number {
  const value = source[key];
  return typeof value === 'number' ? value : 0;
}

/**
 * The request path for `form`: every non-empty field as its own parameter, and `all=1` whenever
 * User is empty, so an OcuPilot administrator's search spans every user while anyone else's reads
 * their own rows (AD-46). Each value is percent-encoded.
 */
export function ledgerPath(form: LedgerForm): string {
  const parts: string[] = [];
  const user = form.user.trim();
  if (user === '') parts.push('all=1');
  else parts.push(`user=${encodeURIComponent(user)}`);
  for (const field of ['route', 'begin', 'end'] as const) {
    const value = form[field].trim();
    if (value !== '') parts.push(`${field}=${encodeURIComponent(value)}`);
  }
  return `${LEDGER_PATH}?${parts.join('&')}`;
}

/** One wire row, or `null` when `value` is not one. */
export function parseRow(value: unknown): LedgerRow | null {
  const row = record(value);
  if (row === null || text(row, 'ledgerId') === '') return null;
  return {
    ledgerId: text(row, 'ledgerId'),
    user: text(row, 'user'),
    time: text(row, 'time'),
    kind: text(row, 'kind'),
    name: text(row, 'name'),
    model: text(row, 'model'),
    route: text(row, 'route'),
    target: text(row, 'target'),
    arguments: text(row, 'arguments'),
    status: text(row, 'status'),
    code: text(row, 'code'),
    fields: text(row, 'fields'),
    fieldsTruncated: row['fieldsTruncated'] === true,
    auditMarked: text(row, 'auditMarked'),
    requestTokens: count(row, 'requestTokens'),
    responseTokens: count(row, 'responseTokens'),
    requiredPairs: text(row, 'requiredPairs'),
    pairsSense: text(row, 'pairsSense'),
  };
}

/** The whole wire answer, or `null` when `value` is not one. */
export function parseView(value: unknown): LedgerView | null {
  const body = record(value);
  if (body === null || !Array.isArray(body['rows'])) return null;
  const rows: LedgerRow[] = [];
  for (const raw of body['rows']) {
    const row = parseRow(raw);
    if (row !== null) rows.push(row);
  }
  const applied = record(body['criteria']) ?? {};
  return {
    rows,
    truncated: body['truncated'] === true,
    rowsWithheld: count(body, 'rowsWithheld'),
    rowsDropped: count(body, 'rowsDropped'),
    criteria: {
      user: text(applied, 'user'),
      route: text(applied, 'route'),
      begin: text(applied, 'begin'),
      end: text(applied, 'end'),
      allUsers: applied['allUsers'] === true,
    },
  };
}

/**
 * The form field a 400 names: `detail.criterion` as the route sends it, `all` being the User
 * field's, a refused account-name shape being the User field's too, and a refused window being the
 * Begin field's, since Begin is the only field that sets the window.
 */
export function refusedField(code: string | null, criterion: unknown): LedgerField | '' {
  if (criterion === 'all' || criterion === 'user') return 'user';
  if (criterion === 'route' || criterion === 'begin' || criterion === 'end') return criterion;
  if (code === 'LEDGER.USER.INVALID') return 'user';
  return code === 'LEDGER.WINDOW.INVALID' ? 'begin' : '';
}

/** The label a row's kind reads, or the kind itself for one this client does not know. */
export function kindLabel(kind: string): string {
  switch (kind) {
    case 'llm':
      return STRINGS.agentLedgerKindModel;
    case 'tool':
      return STRINGS.agentLedgerKindTool;
    case 'write':
      return STRINGS.agentLedgerKindWrite;
    case 'access':
      return STRINGS.agentLedgerKindAccess;
    default:
      return kind;
  }
}

/** The screen a row ran from: the mirror's label for its route, else the route, else the empty word. */
export function screenLabel(route: string): string {
  if (route === '') return STRINGS.tableEmptyValue;
  const screen = screenForRoute(route);
  const label = screen === null ? '' : stringFor(screen.labelKey);
  return label === '' ? route : label;
}

/** A row's target: a stored reference shown as its parts joined, anything else as stored. */
export function targetText(target: string): string {
  return target.split(REFERENCE_SEPARATOR).join(PART_JOIN);
}

/** A row's status, with its machine code beside it when it has one. */
export function statusText(row: Pick<LedgerRow, 'status' | 'code'>): string {
  return row.code === '' ? row.status : `${row.status}${PART_JOIN}${row.code}`;
}

/** The dialog's Arguments block: the stored string verbatim, or the empty word. */
export function argumentsText(row: Pick<LedgerRow, 'arguments'>): string {
  return row.arguments === '' ? STRINGS.tableEmptyValue : row.arguments;
}

/** The dialog's Result block: the row's outcome members as indented JSON text. */
export function resultText(row: LedgerRow): string {
  return JSON.stringify(
    {
      status: row.status,
      code: row.code,
      fields: row.fields,
      fieldsTruncated: row.fieldsTruncated,
      auditMarked: row.auditMarked,
      model: row.model,
      requestTokens: row.requestTokens,
      responseTokens: row.responseTokens,
      requiredPairs: row.requiredPairs,
      pairsSense: row.pairsSense,
    },
    null,
    2
  );
}

/** One screen the Screen criterion offers. */
export interface ScreenOption {
  readonly route: string;
  readonly label: string;
}

/** One area's screens, under its label. */
export interface ScreenGroup {
  readonly key: string;
  readonly label: string;
  readonly screens: readonly ScreenOption[];
}

/** Every built screen with a route, grouped under its area's label in rail order (Home has none). */
export function screenGroups(): readonly ScreenGroup[] {
  const groups: ScreenGroup[] = [];
  for (const area of orderedAreas()) {
    const screens = builtScreensForArea(area.key)
      .filter((screen) => screen.route !== '')
      .map((screen) => ({ route: screen.route, label: stringFor(screen.labelKey) || screen.route }));
    if (screens.length > 0) groups.push({ key: area.key, label: stringFor(area.labelKey), screens });
  }
  return groups;
}

/**
 * The Agent audit ledger's own state (Story 16.16, AD-19): what the criteria form holds, the last
 * answer, and whether the page should search when it opens.
 *
 * **It is root-provided rather than component-local**, for `AuditSearch`'s reason: a row's dialog
 * opens on its own `/:id` route, which destroys and re-creates the page, and the search must
 * survive that. It is reset at sign-out beside `AuditSearch`, because what it holds is this
 * principal's own search and the rows it answered.
 *
 * **Nothing here decides what a caller may see.** The instance answers every row through
 * `Kernel.Audit.Ledger`'s gate; the store renders what came back, and a refusal carries no rows.
 * The API service is resolved on the first search, so constructing the shell does not drag it in.
 */
@Injectable({ providedIn: 'root' })
export class LedgerSearch {
  private readonly injector = inject(Injector);

  private form: LedgerForm = EMPTY_FORM;

  /** The fields the person changed since the last search was sent; an answer's echo leaves them. */
  private readonly edited = new Set<LedgerField>();

  private phaseValue: LedgerPhase = 'idle';

  private viewValue: LedgerView | null = null;

  private reasonValue = '';

  private failedPairValue = '';

  private criterionValue: LedgerField | '' = '';

  private searchedOnce = false;

  private readNeeded = true;

  private gridFocusWanted = false;

  /** Bumped per search, so a late answer to a search since replaced is dropped. */
  private generation = 0;

  private readonly listeners = new Set<() => void>();

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /** Forget everything this principal had, from the sign-out teardown. */
  reset(): void {
    this.form = EMPTY_FORM;
    this.edited.clear();
    this.phaseValue = 'idle';
    this.viewValue = null;
    this.reasonValue = '';
    this.failedPairValue = '';
    this.criterionValue = '';
    this.searchedOnce = false;
    this.readNeeded = true;
    this.gridFocusWanted = false;
    this.generation += 1;
    this.notify();
  }

  value(field: LedgerField): string {
    return this.form[field];
  }

  setValue(field: LedgerField, value: string): void {
    this.form = { ...this.form, [field]: value };
    this.edited.add(field);
    this.notify();
  }

  phase(): LedgerPhase {
    return this.phaseValue;
  }

  view(): LedgerView | null {
    return this.viewValue;
  }

  /** The instance's own reason for a refused criterion, shown at the form. */
  reason(): string {
    return this.reasonValue;
  }

  /** The pair a privilege refusal named, or `''`. */
  failedPair(): string {
    return this.failedPairValue;
  }

  /** The form field a refused criterion names, or `''` when the refusal named none. */
  invalidField(): LedgerField | '' {
    return this.criterionValue;
  }

  /** Whether the page should search when it opens: on a first visit and on a return. */
  needsRead(): boolean {
    return this.readNeeded;
  }

  /**
   * The page has left the screen: its next visit searches again -- with the form as it stands
   * when the person had searched, and with the defaults when they had not.
   */
  leave(): void {
    this.readNeeded = true;
    if (!this.searchedOnce) {
      this.form = EMPTY_FORM;
      this.edited.clear();
    }
  }

  /** The person pressed Search. */
  noteSearched(): void {
    this.searchedOnce = true;
  }

  requestGridFocus(): void {
    this.gridFocusWanted = true;
  }

  /** Whether a grid focus was asked for, clearing the request either way. */
  takeGridFocusRequest(): boolean {
    const wanted = this.gridFocusWanted;
    this.gridFocusWanted = false;
    return wanted;
  }

  /**
   * Search with the form as it stands. The answer's applied criteria then fill the form (AD-36),
   * except a field the person has typed into since.
   */
  async search(): Promise<void> {
    this.generation += 1;
    const generation = this.generation;
    this.readNeeded = false;
    this.edited.clear();
    this.phaseValue = 'loading';
    this.reasonValue = '';
    this.failedPairValue = '';
    this.criterionValue = '';
    this.notify();
    const result: JsonResult<unknown> = await this.injector.get(ApiService).requestJson<unknown>(ledgerPath(this.form), { scope: null });
    if (generation !== this.generation) return;
    if (result.kind === 'ok') {
      const view = parseView(result.body);
      this.viewValue = view;
      this.phaseValue = view === null ? 'refused' : 'ready';
      if (view !== null) this.applyEcho(view.criteria);
    } else if (result.kind === 'error' && result.status === 403) {
      this.viewValue = null;
      this.phaseValue = 'denied';
      const pair = result.detail?.['failedPair'];
      this.failedPairValue = typeof pair === 'string' ? pair : '';
    } else if (result.kind === 'error' && result.status === 400) {
      this.viewValue = null;
      this.phaseValue = 'invalid';
      this.reasonValue = result.reason ?? '';
      this.criterionValue = refusedField(result.code, result.detail?.['criterion']);
    } else {
      this.viewValue = null;
      this.phaseValue = 'refused';
    }
    this.notify();
  }

  /** Fill each field the person has not edited since the search from what the instance applied. */
  private applyEcho(criteria: LedgerCriteria): void {
    const applied: LedgerForm = {
      user: criteria.allUsers ? '' : criteria.user,
      route: criteria.route,
      begin: criteria.begin,
      end: criteria.end,
    };
    const next: Record<LedgerField, string> = { ...this.form };
    for (const field of ['user', 'route', 'begin', 'end'] as const) {
      if (!this.edited.has(field)) next[field] = applied[field];
    }
    this.form = next;
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
