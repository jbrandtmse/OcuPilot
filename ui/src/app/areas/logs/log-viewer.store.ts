import { Injectable, Injector, inject } from '@angular/core';

import { ApiService } from '../../core/api';
import { classifyFault, type Fault } from '../../core/fault';
import {
  mergeLogLines,
  parseFileLines,
  parseMonitorRow,
  tagForNewest,
  tagForWindow,
  type LogLine,
} from './log-line';

/**
 * Which file a viewer is reading, and where each half lives (AD-21: the source key is bound by the
 * route, so neither path carries a file name the caller chose).
 *
 * `recentPath` is `''` for a file with no monitoring half, which is what Story 6.14's messages.log
 * screen declares: the viewer then renders the bounded tail alone and offers no recent-entries
 * notice, because there is no second half to fail.
 */
export interface LogViewerSource {
  readonly tailPath: string;
  readonly recentPath: string;
}

/** The alerts.log screen's two routes. */
export const ALERTS_SOURCE: LogViewerSource = {
  tailPath: '/api/ocupilot/logs/alerts',
  recentPath: '/api/ocupilot/logs/alerts/recent',
};

function linesOf(body: unknown): readonly string[] {
  if (body === null || typeof body !== 'object') return [];
  const lines = (body as Record<string, unknown>)['lines'];
  return Array.isArray(lines) ? lines.filter((line): line is string => typeof line === 'string') : [];
}

function rowsOf(body: unknown): readonly unknown[] {
  if (body === null || typeof body !== 'object') return [];
  const rows = (body as Record<string, unknown>)['rows'];
  return Array.isArray(rows) ? rows : [];
}

function textAt(body: unknown, key: string): string {
  if (body === null || typeof body !== 'object') return '';
  const value = (body as Record<string, unknown>)[key];
  return typeof value === 'string' ? value : '';
}

function numberAt(body: unknown, key: string): number {
  if (body === null || typeof body !== 'object') return 0;
  const value = (body as Record<string, unknown>)[key];
  return typeof value === 'number' ? value : 0;
}

function flagAt(body: unknown, key: string): boolean {
  if (body === null || typeof body !== 'object') return false;
  return (body as Record<string, unknown>)[key] === true;
}

/**
 * The log viewer's own state: the merged entries on screen, the tail cursor they were read under,
 * and the two halves' faults held apart (AD-19).
 *
 * **Nothing here streams, and nothing here ticks** (AD-43). There is no interval, no `EventSource`
 * and no `WebSocket`; the only reads are the one this store issues when a screen opens and the one
 * an explicit Load newer issues. A screen left open issues nothing at all.
 *
 * **The two halves fail independently.** The bounded tail is the screen; the monitoring API is the
 * "and anything since" on top of it. A monitoring failure leaves the tail's rows standing and
 * raises one polite line, and a tail failure is the screen's own refusal. Holding one fault field
 * for both would make either failure blank the screen.
 *
 * **Root-provided**, like the application error log's drill, so the cursor and the rows survive a
 * navigation. What it holds is which lines this principal was reading, so it belongs in the
 * sign-out teardown beside `auditSearch` and `errorLogDrill`; that teardown lives in `app.ts`,
 * which this story does not own, and until it is wired the rows survive a sign-out in the same tab
 * -- DW-1110.
 *
 * Framework-only in its injection: the API service is resolved on the first read rather than in the
 * constructor, so constructing the shell does not drag a leaf screen's data dependency in behind it.
 */
@Injectable({ providedIn: 'root' })
export class LogViewerStore {
  private readonly injector = inject(Injector);

  private sourceValue: LogViewerSource = ALERTS_SOURCE;

  private fileEntries: readonly LogLine[] = [];

  private monitorEntries: readonly LogLine[] = [];

  private mergedValue: readonly LogLine[] = [];

  private offsetValue = 0;

  private identityValue = '';

  private sizeValue = 0;

  private restartedValue = false;

  private truncatedValue = false;

  private cursorValue = false;

  private loadingValue = false;

  private loadedValue = false;

  private faultValue: Fault | null = null;

  private failedPairValue = '';

  /** Set when the monitoring half alone failed, which is a notice rather than a refusal. */
  private recentUnavailableValue = false;

  /** Bumped per issued read, so a late answer to a screen the user has left is dropped. */
  private generation = 0;

  private readonly listeners = new Set<() => void>();

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /** Forget everything this principal had. See the class note on the sign-out teardown (DW-1110). */
  reset(): void {
    this.fileEntries = [];
    this.monitorEntries = [];
    this.mergedValue = [];
    this.offsetValue = 0;
    this.identityValue = '';
    this.sizeValue = 0;
    this.restartedValue = false;
    this.truncatedValue = false;
    this.cursorValue = false;
    this.loadingValue = false;
    this.loadedValue = false;
    this.faultValue = null;
    this.failedPairValue = '';
    this.recentUnavailableValue = false;
    this.generation += 1;
    this.notify();
  }

  /**
   * Point the viewer at one file. A different source drops everything the previous one left, so a
   * second log screen cannot render the first one's rows under its own title.
   */
  setSource(source: LogViewerSource): void {
    if (source.tailPath === this.sourceValue.tailPath && source.recentPath === this.sourceValue.recentPath) return;
    this.sourceValue = source;
    this.reset();
  }

  source(): LogViewerSource {
    return this.sourceValue;
  }

  lines(): readonly LogLine[] {
    return this.mergedValue;
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

  failedPair(): string {
    return this.failedPairValue;
  }

  /** Whether the monitoring half failed while the tail answered (AD-12's code, not its reason). */
  recentUnavailable(): boolean {
    return this.recentUnavailableValue;
  }

  /** Whether the last tail page re-seeded from byte 1 because the file had rotated under it. */
  restarted(): boolean {
    return this.restartedValue;
  }

  /** Whether the window stopped short of the end of the file. */
  truncated(): boolean {
    return this.truncatedValue;
  }

  size(): number {
    return this.sizeValue;
  }

  /**
   * Whether Load newer is offered: only once a page has answered and left a cursor.
   *
   * There is no control for the other end. The first page is the file's own tail, so the oldest end
   * is where the window starts; the viewer offers no way to ask for a page before it and issues no
   * request for one.
   */
  canLoadNewer(): boolean {
    return this.cursorValue;
  }

  /** The first read: the last bytes of the file, then whatever the monitoring API has since. */
  async open(): Promise<void> {
    this.fileEntries = [];
    this.monitorEntries = [];
    this.mergedValue = [];
    this.restartedValue = false;
    await this.read('');
  }

  /**
   * One more page, from the cursor the last page returned.
   *
   * A rotation answers `restarted` true, which is an outcome and not a fault: the page is the new
   * file's own start, so the rows it replaces are gone and the held cursor with them.
   */
  async loadNewer(): Promise<void> {
    if (!this.cursorValue) return;
    await this.read(String(this.offsetValue));
  }

  private async read(offset: string): Promise<void> {
    const generation = (this.generation += 1);
    this.loadingValue = true;
    this.faultValue = null;
    this.failedPairValue = '';
    this.recentUnavailableValue = false;
    this.notify();

    const query =
      offset === ''
        ? ''
        : '?offset=' + encodeURIComponent(offset) + '&identity=' + encodeURIComponent(this.identityValue);
    const path = this.sourceValue.tailPath + query;
    const result = await this.injector.get(ApiService).requestJson<unknown>(path, { scope: null });
    if (generation !== this.generation) return;

    if (result.kind !== 'ok') {
      this.loadingValue = false;
      this.faultValue = classifyFault(result, path);
      if (result.kind === 'error') {
        const pair = result.detail === null ? undefined : result.detail['failedPair'];
        this.failedPairValue = typeof pair === 'string' ? pair : '';
      }
      this.notify();
      return;
    }

    const restarted = flagAt(result.body, 'restarted');
    const window = parseFileLines(linesOf(result.body));
    this.offsetValue = numberAt(result.body, 'offset');
    this.identityValue = textAt(result.body, 'identity');
    this.sizeValue = numberAt(result.body, 'size');
    this.truncatedValue = flagAt(result.body, 'truncated');
    this.restartedValue = restarted;
    this.cursorValue = this.identityValue !== '' && this.offsetValue > 0;
    // A restart is the file's own start, so what stood before it belongs to a file that no longer
    // exists -- the rows are replaced rather than appended to, and the held cursor goes with them.
    this.fileEntries = offset === '' || restarted ? window : [...this.fileEntries, ...window];
    if (offset === '' || restarted) this.monitorEntries = [];
    this.loadedValue = true;
    this.mergedValue = mergeLogLines(this.fileEntries, this.monitorEntries);
    this.loadingValue = false;
    this.notify();

    await this.readRecent(generation, offset !== '' && !restarted);
  }

  /**
   * The monitoring half.
   *
   * On the first window -- a screen opening, or a rotation re-seeding from byte 1 -- the cursor is
   * that window's **earliest** head line, so the two windows coincide and no entry can fall between
   * them. On a Load newer the file half has already advanced, so the cursor is the **newest** head
   * line held: asking again from the first window's start would re-request every entry since the
   * screen opened, growing each time until the port's size bound refuses a session that was working
   * moments earlier.
   *
   * A window with no head line at all opens mid-continuation and can supply no cursor, so no call
   * is made; a source with no monitoring half makes none either. A failure here is a notice, never
   * a refusal: the tail's rows are already on screen.
   */
  private async readRecent(generation: number, fromNewest: boolean): Promise<void> {
    if (this.sourceValue.recentPath === '') return;
    const tag = fromNewest ? tagForNewest(this.fileEntries) : tagForWindow(this.fileEntries);
    if (tag === '') return;
    const path = this.sourceValue.recentPath + '?tag=' + encodeURIComponent(tag);
    const result = await this.injector.get(ApiService).requestJson<unknown>(path, { scope: null });
    if (generation !== this.generation) return;
    if (result.kind !== 'ok') {
      this.recentUnavailableValue = true;
      this.notify();
      return;
    }
    this.monitorEntries = rowsOf(result.body).map(parseMonitorRow);
    this.mergedValue = mergeLogLines(this.fileEntries, this.monitorEntries);
    this.notify();
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
