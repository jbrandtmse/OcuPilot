import { Injectable, Injector, inject } from '@angular/core';

import { ApiService } from '../../core/api';
import { classifyFault, type Fault } from '../../core/fault';
import { screenReadPath } from '../../core/screen-read';
import type { ScreenDeclaration } from '../../core/screens.generated';

/** One timeline row, as the hub's composed read answers it (AD-36 as amended). */
export interface LogHubRow {
  /** Instance-local `YYYY-MM-DDTHH:MM:SS.mmm`, the form the log viewers show. */
  readonly time: string;
  /** The member's route, which is also how its label and its page are found. */
  readonly source: string;
  /** On the console scale -2..3, or `''` where the source records none. */
  readonly severity: string;
  readonly text: string;
  /** The member's composite id (AD-13), or `''`. */
  readonly id: string;
}

/** One member's summary: whether it was shown, the pair it needs, its count, its cut and its newest entry. */
export interface LogHubSource {
  readonly source: string;
  readonly shown: boolean;
  readonly requires: string;
  readonly count: number;
  readonly truncated: boolean;
  readonly last: LogHubRow | null;
}

/**
 * The second after `stamp`, an instance-local `YYYY-MM-DD HH:MM:SS` with no zone, in the same form.
 * Computed on the UTC calendar so the browser's own zone and its daylight changes never enter it;
 * a stamp that is not that form answers itself.
 */
export function nextSecond(stamp: string): string {
  const match = /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$/.exec(stamp);
  if (match === null) return stamp;
  const at = new Date(
    Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3]), Number(match[4]), Number(match[5]), Number(match[6]) + 1)
  );
  const two = (value: number): string => String(value).padStart(2, '0');
  return (
    String(at.getUTCFullYear()).padStart(4, '0') +
    '-' +
    two(at.getUTCMonth() + 1) +
    '-' +
    two(at.getUTCDate()) +
    ' ' +
    two(at.getUTCHours()) +
    ':' +
    two(at.getUTCMinutes()) +
    ':' +
    two(at.getUTCSeconds())
  );
}

function textAt(value: unknown, key: string): string {
  if (value === null || typeof value !== 'object') return '';
  const member = (value as Record<string, unknown>)[key];
  return typeof member === 'string' ? member : '';
}

function rowOf(value: unknown): LogHubRow | null {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) return null;
  return {
    time: textAt(value, 'time'),
    source: textAt(value, 'source'),
    severity: textAt(value, 'severity'),
    text: textAt(value, 'text'),
    id: textAt(value, 'id'),
  };
}

function rowsOf(body: unknown): readonly LogHubRow[] {
  if (body === null || typeof body !== 'object') return [];
  const rows = (body as Record<string, unknown>)['rows'];
  if (!Array.isArray(rows)) return [];
  return rows.map(rowOf).filter((row): row is LogHubRow => row !== null);
}

function sourcesOf(body: unknown): readonly LogHubSource[] {
  if (body === null || typeof body !== 'object') return [];
  const sources = (body as Record<string, unknown>)['sources'];
  if (!Array.isArray(sources)) return [];
  const out: LogHubSource[] = [];
  for (const entry of sources) {
    if (entry === null || typeof entry !== 'object') continue;
    const record = entry as Record<string, unknown>;
    out.push({
      source: textAt(entry, 'source'),
      shown: record['shown'] === true,
      requires: textAt(entry, 'requires'),
      count: typeof record['count'] === 'number' ? record['count'] : 0,
      truncated: record['truncated'] === true,
      last: rowOf(record['last']),
    });
  }
  return out;
}

function criteriaOf(body: unknown): Readonly<Record<string, string>> {
  const out: Record<string, string> = {};
  if (body === null || typeof body !== 'object') return out;
  const criteria = (body as Record<string, unknown>)['criteria'];
  if (criteria === null || typeof criteria !== 'object' || Array.isArray(criteria)) return out;
  for (const [key, value] of Object.entries(criteria as Record<string, unknown>)) {
    if (typeof value === 'string') out[key] = value;
  }
  return out;
}

/**
 * The unified log hub's own state (Story 16.9): the composed read's rows, its per-source summary
 * and the bound it applied, and the two client-side filters beside the command bar's text filter.
 *
 * **It fetches through `ApiService` rather than `createScreenRead`**, which answers rows and
 * `truncated` alone and would drop `sources`. The request is the screen's ordinary read route
 * (`screenReadPath`), so the hub's gate, cap and criterion allow-list are the read's own (AD-21).
 *
 * **Root-provided**, like the log viewer's store, so the rows survive a navigation to a source and
 * back; what it holds is what THIS principal read, so `app.ts`'s sign-out teardown resets it.
 *
 * Framework-only in its injection: the API service is resolved on the first read.
 */
@Injectable({ providedIn: 'root' })
export class LogHubStore {
  private readonly injector = inject(Injector);

  private rowsValue: readonly LogHubRow[] = [];

  private sourcesValue: readonly LogHubSource[] = [];

  private criteriaValue: Readonly<Record<string, string>> = {};

  private truncatedValue = false;

  private loadingValue = false;

  private loadedValue = false;

  private faultValue: Fault | null = null;

  private failedPairValue = '';

  private sourceFilterValue = '';

  private severityFilterValue = '';

  /** The bound the person last searched with, `null` for the declared default. */
  private searchedSinceValue: string | null = null;

  /** Bumped per issued read, so a late answer is dropped. */
  private generation = 0;

  private readonly listeners = new Set<() => void>();

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /** Forget everything this principal had; the sign-out teardown calls it. */
  reset(): void {
    this.rowsValue = [];
    this.sourcesValue = [];
    this.criteriaValue = {};
    this.truncatedValue = false;
    this.loadingValue = false;
    this.loadedValue = false;
    this.faultValue = null;
    this.failedPairValue = '';
    this.sourceFilterValue = '';
    this.severityFilterValue = '';
    this.searchedSinceValue = null;
    this.generation += 1;
    this.notify();
  }

  /** The bound the person last searched with, `null` while the declared default stands. */
  searchedSince(): string | null {
    return this.searchedSinceValue;
  }

  /** Record the bound a Search sends; `''` is an unset bound. */
  setSearchedSince(since: string): void {
    this.searchedSinceValue = since;
  }

  rows(): readonly LogHubRow[] {
    return this.rowsValue;
  }

  sources(): readonly LogHubSource[] {
    return this.sourcesValue;
  }

  /** The criteria the last read applied, `since` among them. */
  criteria(): Readonly<Record<string, string>> {
    return this.criteriaValue;
  }

  truncated(): boolean {
    return this.truncatedValue;
  }

  loading(): boolean {
    return this.loadingValue;
  }

  loaded(): boolean {
    return this.loadedValue;
  }

  fault(): Fault | null {
    return this.faultValue;
  }

  /** The `(resource, permission)` pair a refusal named (AD-8), or `''`. */
  failedPair(): string {
    return this.failedPairValue;
  }

  /** The route the Source filter keeps, `''` for Any. */
  sourceFilter(): string {
    return this.sourceFilterValue;
  }

  setSourceFilter(route: string): void {
    if (route === this.sourceFilterValue) return;
    this.sourceFilterValue = route;
    this.notify();
  }

  /** The severity chip key the Severity filter keeps, `''` for Any. */
  severityFilter(): string {
    return this.severityFilterValue;
  }

  setSeverityFilter(key: string): void {
    if (key === this.severityFilterValue) return;
    this.severityFilterValue = key;
    this.notify();
  }

  /**
   * Read the hub at `maxRows`, sending `since` when it is given (an empty one is an unset bound;
   * an absent one takes the declared default, an hour back). Answers the fault, or `null`.
   */
  async read(screen: Pick<ScreenDeclaration, 'toolIdentifier' | 'read'>, maxRows: number, since?: string): Promise<Fault | null> {
    const generation = (this.generation += 1);
    this.loadingValue = true;
    this.faultValue = null;
    this.failedPairValue = '';
    this.notify();
    const path = screenReadPath(screen, maxRows, since === undefined ? {} : { since });
    const result = await this.injector.get(ApiService).requestJson<unknown>(path);
    if (generation !== this.generation) return null;
    this.loadingValue = false;
    if (result.kind !== 'ok' || result.body === null || typeof result.body !== 'object') {
      const failed = result.kind === 'ok' ? { kind: 'error' as const, status: result.status, code: null, reason: null, detail: null } : result;
      this.faultValue = classifyFault(failed, path);
      if (failed.kind === 'error') {
        const pair = failed.detail === null ? undefined : failed.detail['failedPair'];
        this.failedPairValue = typeof pair === 'string' ? pair : '';
      }
      this.notify();
      return this.faultValue;
    }
    this.rowsValue = rowsOf(result.body);
    this.sourcesValue = sourcesOf(result.body);
    this.criteriaValue = criteriaOf(result.body);
    this.truncatedValue = (result.body as Record<string, unknown>)['truncated'] === true;
    this.loadedValue = true;
    this.notify();
    return null;
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
