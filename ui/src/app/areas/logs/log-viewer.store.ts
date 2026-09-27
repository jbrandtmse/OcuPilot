import { Injectable, Injector, inject } from '@angular/core';

import { ApiService } from '../../core/api';
import { classifyFault, type Fault } from '../../core/fault';
import { parseFileLines, type LogFileEntry, type LogLine } from './log-line';

/**
 * Which file a viewer is reading (AD-21: the source key is bound by the route, so the path carries
 * no file name the caller chose). Each log screen contributes one of these rather than a store of
 * its own.
 */
export interface LogViewerSource {
  readonly tailPath: string;
  /**
   * The route listing the files this source can page (Story 16.20), present only on a source whose
   * older rotated files a caller may name. A source without it offers no file choice and issues no
   * list request.
   */
  readonly filesPath?: string;
  /** The name `filesPath`'s list answers for the source's own file, which the address never carries. */
  readonly ownFile?: string;
  /**
   * Whether the route answers the newest entries rather than a page of a file (Story 16.8): a bare
   * GET with no cursor, answered as `{source, entries, truncated}` already normalized on the server.
   */
  readonly entries?: true;
}

/** The alerts.log screen's route. */
export const ALERTS_SOURCE: LogViewerSource = {
  tailPath: '/api/ocupilot/logs/alerts',
};

/** The messages.log screen's route, bound to the `messages` source key by `Api/Router.cls`. */
export const MESSAGES_SOURCE: LogViewerSource = {
  tailPath: '/api/ocupilot/logs/messages',
  filesPath: '/api/ocupilot/logs/messages/files',
  ownFile: 'messages.log',
};

/** The six secondary logs (Story 16.8), each bound to its own source key by `Api/Router.cls`. */
export const SYSTEM_MONITOR_SOURCE: LogViewerSource = { tailPath: '/api/ocupilot/logs/systemmonitor', entries: true };
export const TASK_ERRORS_SOURCE: LogViewerSource = { tailPath: '/api/ocupilot/logs/taskerrors', entries: true };
export const XDBC_SOURCE: LogViewerSource = { tailPath: '/api/ocupilot/logs/xdbc', entries: true };
export const SQL_DIAGNOSTICS_SOURCE: LogViewerSource = { tailPath: '/api/ocupilot/logs/sqldiagnostics', entries: true };
export const EVENT_LOG_SOURCE: LogViewerSource = { tailPath: '/api/ocupilot/logs/eventlog', entries: true };
export const ANALYTICS_SOURCE: LogViewerSource = { tailPath: '/api/ocupilot/logs/analytics', entries: true };

/**
 * `OcuPilot.Api.Error`'s code for a log file this instance does not have. It is a 404 rather than an
 * empty page because a caller paging a file by byte offset asked for a file; the viewer asked for
 * the instance's entries, so it renders its own empty state instead of a refusal.
 */
const ABSENT_CODE = 'LOG.ABSENT';

function linesOf(body: unknown): readonly string[] {
  if (body === null || typeof body !== 'object') return [];
  const lines = (body as Record<string, unknown>)['lines'];
  return Array.isArray(lines) ? lines.filter((line): line is string => typeof line === 'string') : [];
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
 * A `Recent` answer's entries as rows, oldest first as the viewer draws them. Each already carries
 * its local stamp, pid, severity and text, so no grammar is parsed here.
 */
function entriesOf(body: unknown): readonly LogLine[] {
  if (body === null || typeof body !== 'object') return [];
  const entries = (body as Record<string, unknown>)['entries'];
  if (!Array.isArray(entries)) return [];
  const lines: LogLine[] = [];
  for (const entry of entries) {
    lines.push({
      stamp: textAt(entry, 'time'),
      pid: textAt(entry, 'pid'),
      severity: textAt(entry, 'severity'),
      category: '',
      text: textAt(entry, 'text'),
      raw: textAt(entry, 'raw'),
      head: true,
    });
  }
  return lines.reverse();
}

function filesOf(body: unknown): readonly LogFileEntry[] {
  if (body === null || typeof body !== 'object') return [];
  const files = (body as Record<string, unknown>)['files'];
  if (!Array.isArray(files)) return [];
  const entries: LogFileEntry[] = [];
  for (const file of files) {
    const name = textAt(file, 'name');
    if (name === '') continue;
    entries.push({ name, size: numberAt(file, 'size'), modified: textAt(file, 'modified') });
  }
  return entries;
}

/**
 * The log viewer's own state: the entries on screen and the tail cursor they were read under.
 *
 * **Nothing here streams, and nothing here ticks** (AD-43). There is no interval, no `EventSource`
 * and no `WebSocket`; the only reads are the one this store issues when a screen opens and the one
 * an explicit Load newer issues. A screen left open issues nothing at all.
 *
 * **Root-provided**, like the application error log's drill, so the cursor and the rows survive a
 * navigation. What it holds is which lines this principal was reading, so `app.ts`'s sign-out
 * teardown resets it beside `auditSearch` and `errorLogDrill`.
 *
 * **A secondary log reads entries, not pages** (Story 16.8): its source declares `entries`, its read
 * is a bare GET for the newest window, and Load newer reads that window again.
 *
 * Framework-only in its injection: the API service is resolved on the first read rather than in the
 * constructor, so constructing the shell does not drag a leaf screen's data dependency in behind it.
 */
@Injectable({ providedIn: 'root' })
export class LogViewerStore {
  private readonly injector = inject(Injector);

  private sourceValue: LogViewerSource = ALERTS_SOURCE;

  /** The rotated file the window reads, `''` for the source's own file. */
  private fileValue = '';

  private filesValue: readonly LogFileEntry[] = [];

  private filesLoadedValue = false;

  /** Whether the named file answered `LOG.ABSENT`: it was removed since it was listed or linked. */
  private goneValue = false;

  /** Bumped per issued list read, so a late list for a source the user has left is dropped. */
  private filesGeneration = 0;

  private fileEntries: readonly LogLine[] = [];

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

  /** Bumped per issued read, so a late answer to a screen the user has left is dropped. */
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
    this.fileValue = '';
    this.filesValue = [];
    this.filesLoadedValue = false;
    this.filesGeneration += 1;
    this.clearWindow();
  }

  /** Drop the window and its cursor, keeping the source's file list. */
  private clearWindow(): void {
    this.goneValue = false;
    this.fileEntries = [];
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
    this.generation += 1;
    this.notify();
  }

  /**
   * Point the viewer at one file: `file` names a rotated file of a source that lists them, `''`
   * the source's own file. A different source drops everything the previous one left, so a second
   * log screen cannot render the first one's rows under its own title; a different file on the same
   * source drops the window and keeps the list. Neither reads anything: the caller opens.
   */
  setSource(source: LogViewerSource, file = ''): void {
    const named = source.filesPath === undefined ? '' : file;
    if (source.tailPath !== this.sourceValue.tailPath) {
      this.sourceValue = source;
      this.reset();
      this.fileValue = named;
      return;
    }
    if (named === this.fileValue) return;
    this.fileValue = named;
    this.clearWindow();
  }

  source(): LogViewerSource {
    return this.sourceValue;
  }

  /** The rotated file the window reads, `''` for the source's own file. */
  file(): string {
    return this.fileValue;
  }

  /** The files the source can page, its own first, as the last list read answered them. */
  files(): readonly LogFileEntry[] {
    return this.filesValue;
  }

  /** Whether a list read has answered. A refused or failed list leaves this false. */
  filesLoaded(): boolean {
    return this.filesLoadedValue;
  }

  /** Whether the file the window names is no longer in the manager directory. */
  gone(): boolean {
    return this.goneValue;
  }

  /**
   * Read the source's file list. A source with no `filesPath` issues nothing; a refused list leaves
   * the choice unrendered and the window as it is.
   */
  async loadFiles(): Promise<void> {
    const path = this.sourceValue.filesPath;
    if (path === undefined) return;
    const generation = (this.filesGeneration += 1);
    const result = await this.injector.get(ApiService).requestJson<unknown>(path, { scope: null });
    if (generation !== this.filesGeneration) return;
    if (result.kind !== 'ok') {
      this.filesValue = [];
      this.filesLoadedValue = false;
      this.notify();
      return;
    }
    this.filesValue = filesOf(result.body);
    this.filesLoadedValue = true;
    this.notify();
  }

  lines(): readonly LogLine[] {
    return this.fileEntries;
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
   * Whether Load newer is offered: only once a page has answered and left a cursor, or, for a
   * source that reads entries, once its window has answered.
   *
   * There is no control for the other end. The first page is the file's own tail, so the oldest end
   * is where the window starts; the viewer offers no way to ask for a page before it and issues no
   * request for one.
   */
  canLoadNewer(): boolean {
    if (this.sourceValue.entries === true) return this.loadedValue && this.faultValue === null;
    return this.cursorValue;
  }

  /** The first read: the last bytes of the file. */
  async open(): Promise<void> {
    this.fileEntries = [];
    this.restartedValue = false;
    await this.read('');
  }

  /**
   * One more page, from the cursor the last page returned; for a source that reads entries, the
   * newest window again.
   *
   * A rotation answers `restarted` true, which is an outcome and not a fault: the page is the new
   * file's own start, so the rows it replaces are gone and the held cursor with them.
   */
  async loadNewer(): Promise<void> {
    if (this.sourceValue.entries === true) {
      await this.read('');
      return;
    }
    if (!this.cursorValue) return;
    await this.read(String(this.offsetValue));
  }

  private async read(offset: string): Promise<void> {
    const generation = (this.generation += 1);
    this.loadingValue = true;
    this.faultValue = null;
    this.failedPairValue = '';
    this.goneValue = false;
    this.notify();

    const entriesMode = this.sourceValue.entries === true;
    const params: string[] = [];
    if (!entriesMode && offset !== '') {
      params.push('offset=' + encodeURIComponent(offset), 'identity=' + encodeURIComponent(this.identityValue));
    }
    if (!entriesMode && this.fileValue !== '') params.push('file=' + encodeURIComponent(this.fileValue));
    const path = this.sourceValue.tailPath + (params.length === 0 ? '' : '?' + params.join('&'));
    const result = await this.injector.get(ApiService).requestJson<unknown>(path, { scope: null });
    if (generation !== this.generation) return;

    if (result.kind !== 'ok') {
      this.loadingValue = false;
      // A log the instance has not written yet is an empty screen, not a refusal: a fresh instance
      // that has raised no alert has no alerts.log, and the port says so by name. A rotated file the
      // address named and the directory no longer holds is the one exception: it was there.
      if (result.kind === 'error' && result.code === ABSENT_CODE) {
        this.fileEntries = [];
        this.cursorValue = false;
        this.goneValue = this.fileValue !== '';
        this.loadedValue = true;
        this.notify();
        return;
      }
      this.faultValue = classifyFault(result, path);
      if (result.kind === 'error') {
        const pair = result.detail === null ? undefined : result.detail['failedPair'];
        this.failedPairValue = typeof pair === 'string' ? pair : '';
      }
      this.notify();
      return;
    }

    if (entriesMode) {
      this.fileEntries = entriesOf(result.body);
      this.truncatedValue = flagAt(result.body, 'truncated');
      this.cursorValue = false;
      this.loadedValue = true;
      this.loadingValue = false;
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
    this.loadedValue = true;
    this.loadingValue = false;
    this.notify();
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
