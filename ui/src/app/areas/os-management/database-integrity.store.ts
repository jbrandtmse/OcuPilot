import { Injectable, Injector, inject } from '@angular/core';

import { ApiService } from '../../core/api';
import { canonicalDirectorySet } from '../../core/entity-ref';
import { FormDirty } from '../../core/form-dirty';
import { screenForRoute } from '../../core/navigation';
import { createScreenRead, screenReadPath } from '../../core/screen-read';
import { ScreenStores } from '../../core/screen-store';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { DATABASE_LIST_DESCRIPTOR, INTEGRITY_ACTION } from './database-actions';

/** The flow's three steps, in order. */
export const DATABASES_STEP = 'databases';
export const GLOBALS_STEP = 'globals';
export const REPORT_STEP = 'report';
export const INTEGRITY_STEPS: readonly string[] = [DATABASES_STEP, GLOBALS_STEP, REPORT_STEP];

/** The two fields the instance's step check names (`OcuPilot.Area.OsMgmt.DatabaseRules`' `globals` step). */
export const DATABASES_FIELD = 'Databases';
export const GLOBALS_FIELD = 'Globals';

/** The Databases list's route, whose declared read the checklist issues (AD-5). */
export const DATABASE_LIST_ROUTE = 'os-management/databases';

/** The Integrity log's route, whose declared read the Report step issues for the finished check. */
export const INTEGRITY_LOG_ROUTE = 'os-management/databases/integrity-log';

/** The step check's route, which the local database form's steps share (Story 18.3). */
export const DATABASE_CHECK_PATH = '/api/ocupilot/database/check';

/** How many databases the checklist reads: an instance's databases are never many. */
export const DATABASE_LIST_MAX_ROWS = 1000;

/** How many report lines the Report step reads through the Integrity log's declared read. */
export const REPORT_MAX_ROWS = 1000;

/** One database the checklist offers: its directory and its status word, as the list read answers them. */
export interface IntegrityDatabase {
  readonly directory: string;
  readonly status: string;
}

/** Where the check stands once sent: `finished` with its report, `continues` past the port's wait, or `refused`. */
export type IntegrityOutcome = 'none' | 'running' | 'finished' | 'continues' | 'refused';

function textAt(source: unknown, key: string): string {
  if (source === null || typeof source !== 'object') return '';
  const value = (source as Record<string, unknown>)[key];
  if (typeof value === 'string') return value;
  if (typeof value === 'number') return String(value);
  return '';
}

/** The global names the field holds, one per line, blank lines dropped and each trimmed. */
export function globalNames(text: string): readonly string[] {
  return text
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line !== '');
}

/**
 * The Check integrity flow's store (Story 18.4, AC6): which databases are checked, the globals to
 * check in one of them, and the check's outcome.
 *
 * **It composes no body.** Next asks the instance to check the step (`POST /database/check`, step
 * `globals`), and Check integrity sends the Databases list's declared `integrity` action through the
 * shell's handler with the checked directories as its target -- a JSON array, spelled canonically
 * (AD-13) -- and the globals as its one declared value (AD-56 (ii)); the port builds the vendor's body.
 *
 * **The report is the Integrity log's.** A check that finishes within the port's wait is shown by
 * issuing that screen's declared read, which answers the newest check's lines; nothing here reads
 * the vendor's task, so no task is read twice (AD-26). A check still running shows the still-running
 * sentence instead.
 *
 * **The leave guard arms on an edit and disarms once the check is sent.** Opening, and the
 * checklist's preselection of the Databases list's selected row, leave the form clean.
 */
@Injectable({ providedIn: 'root' })
export class DatabaseIntegrityFlow {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private stepValue = DATABASES_STEP;

  private reachedValue = 0;

  private databasesValue: readonly IntegrityDatabase[] = [];

  private loadedValue = false;

  private faultValue = false;

  private checkedValue: ReadonlySet<string> = new Set();

  private globalsValue = '';

  private violationList: readonly Violation[] = [];

  private reasonValue = '';

  private checkingValue = false;

  private outcomeValue: IntegrityOutcome = 'none';

  private sinceValue: Date | null = null;

  private reportTimeValue = '';

  private reportLinesValue: readonly string[] = [];

  private reportFaultValue = false;

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  // --- reads -----------------------------------------------------------------------------------

  step(): string {
    return this.stepValue;
  }

  /** Whether step `key` may be opened: the current one and every one Next has passed. */
  reachable(key: string): boolean {
    return INTEGRITY_STEPS.indexOf(key) <= this.reachedValue;
  }

  databases(): readonly IntegrityDatabase[] {
    return this.databasesValue;
  }

  loaded(): boolean {
    return this.loadedValue;
  }

  fault(): boolean {
    return this.faultValue;
  }

  checked(directory: string): boolean {
    return this.checkedValue.has(directory);
  }

  checkedCount(): number {
    return this.checkedValue.size;
  }

  allChecked(): boolean {
    return this.databasesValue.length > 0 && this.databasesValue.every((row) => this.checkedValue.has(row.directory));
  }

  /** Whether globals may be named: exactly one database is checked. */
  globalsEnabled(): boolean {
    return this.checkedValue.size === 1;
  }

  globals(): string {
    return this.globalsValue;
  }

  violations(): readonly Violation[] {
    return this.violationList;
  }

  violationFor(field: string): string {
    return reasonForField(this.violationList, field);
  }

  /** An envelope refusal's own sentence (AD-39), or `''`. */
  reason(): string {
    return this.reasonValue;
  }

  checking(): boolean {
    return this.checkingValue;
  }

  outcome(): IntegrityOutcome {
    return this.outcomeValue;
  }

  /** When the check was sent, while it runs. */
  since(): Date | null {
    return this.sinceValue;
  }

  /** The finished check's start, as the Integrity log's read answers it, or `''`. */
  reportTime(): string {
    return this.reportTimeValue;
  }

  reportLines(): readonly string[] {
    return this.reportLinesValue;
  }

  /** Whether the Integrity log's read of the finished check failed. */
  reportFault(): boolean {
    return this.reportFaultValue;
  }

  /** The check's target: the checked directories as the canonical `database` id (AD-13). */
  target(): string {
    const directories = this.databasesValue.filter((row) => this.checkedValue.has(row.directory)).map((row) => row.directory);
    return canonicalDirectorySet(JSON.stringify(directories));
  }

  // --- writes ----------------------------------------------------------------------------------

  /** Forget everything: from the sign-out teardown and when the flow is left. */
  reset(): void {
    this.generation += 1;
    this.stepValue = DATABASES_STEP;
    this.reachedValue = 0;
    this.databasesValue = [];
    this.loadedValue = false;
    this.faultValue = false;
    this.checkedValue = new Set();
    this.globalsValue = '';
    this.violationList = [];
    this.reasonValue = '';
    this.checkingValue = false;
    this.outcomeValue = 'none';
    this.sinceValue = null;
    this.reportTimeValue = '';
    this.reportLinesValue = [];
    this.reportFaultValue = false;
    this.formDirty.reset();
    this.notify();
  }

  /**
   * Open the flow: read the Databases list's declared read for the checklist, checking the row the
   * list has selected, if any, without marking the form dirty.
   */
  async open(): Promise<void> {
    this.reset();
    const generation = this.generation;
    const screen = screenForRoute(DATABASE_LIST_ROUTE);
    if (screen === null || screen.read === null) {
      this.loadedValue = true;
      this.faultValue = true;
      this.notify();
      return;
    }
    const read = createScreenRead(this.api(), screen);
    const result = await read({ maxRows: DATABASE_LIST_MAX_ROWS });
    if (generation !== this.generation) return;
    this.loadedValue = true;
    if (result.kind !== 'ok') {
      this.faultValue = true;
      this.notify();
      return;
    }
    const rows: IntegrityDatabase[] = [];
    for (const row of result.rows) {
      const directory = textAt(row, 'Directory');
      if (directory === '') continue;
      rows.push({ directory, status: textAt(row, 'Status') });
    }
    this.databasesValue = rows;
    const selected = this.injector.get(ScreenStores).for(screen.descriptor, screen.refreshRates).selection()[0] ?? '';
    if (selected !== '' && rows.some((row) => row.directory === selected)) this.checkedValue = new Set([selected]);
    this.notify();
  }

  setChecked(directory: string, checked: boolean): void {
    if (this.checkingValue || this.checkedValue.has(directory) === checked) return;
    const next = new Set(this.checkedValue);
    if (checked) next.add(directory);
    else next.delete(directory);
    this.checkedValue = next;
    this.edit(DATABASES_FIELD);
  }

  /** Check all, or clear every check when all are checked. */
  toggleAll(): void {
    if (this.checkingValue || this.databasesValue.length === 0) return;
    this.checkedValue = this.allChecked() ? new Set() : new Set(this.databasesValue.map((row) => row.directory));
    this.edit(DATABASES_FIELD);
  }

  setGlobals(text: string): void {
    if (this.checkingValue || this.globalsValue === text) return;
    this.globalsValue = text;
    this.edit(GLOBALS_FIELD);
  }

  /** Open step `key`, where it is reachable. */
  goTo(key: string): void {
    if (!INTEGRITY_STEPS.includes(key) || !this.reachable(key) || key === this.stepValue) return;
    this.stepValue = key;
    this.notify();
  }

  back(): void {
    const index = INTEGRITY_STEPS.indexOf(this.stepValue);
    if (index > 0) this.goTo(INTEGRITY_STEPS[index - 1]);
  }

  /**
   * Next: ask the instance to check what the flow holds so far -- the checked databases, and from the
   * Globals step the globals too -- and open the next step when it answers no violation.
   */
  async next(): Promise<boolean> {
    const index = INTEGRITY_STEPS.indexOf(this.stepValue);
    if (index < 0 || index >= INTEGRITY_STEPS.length - 1 || this.checkingValue) return false;
    const generation = this.generation;
    const values: Record<string, unknown> = { [DATABASES_FIELD]: this.checkedDirectories() };
    if (this.stepValue === GLOBALS_STEP) values[GLOBALS_FIELD] = this.globalsSent();
    this.checkingValue = true;
    this.violationList = [];
    this.reasonValue = '';
    this.notify();
    const result = await this.api().requestJson<unknown>(DATABASE_CHECK_PATH, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ step: GLOBALS_STEP, values }),
    });
    if (generation !== this.generation) return false;
    this.checkingValue = false;
    if (result.kind !== 'ok') {
      this.violationList = violationsOf(result);
      this.reasonValue = this.violationList.length === 0 && result.kind === 'error' ? (result.reason ?? '') : '';
      this.notify();
      return false;
    }
    const violations: Violation[] = [];
    const raw = result.body !== null && typeof result.body === 'object' ? (result.body as Record<string, unknown>)['violations'] : null;
    for (const entry of Array.isArray(raw) ? raw : []) {
      const field = textAt(entry, 'field');
      const code = textAt(entry, 'code');
      if (field === '' || code === '') continue;
      violations.push({ field, code, reason: textAt(entry, 'reason') });
    }
    this.violationList = violations;
    if (violations.length > 0) {
      this.notify();
      return false;
    }
    this.stepValue = INTEGRITY_STEPS[index + 1];
    this.reachedValue = Math.max(this.reachedValue, index + 1);
    this.notify();
    return true;
  }

  /**
   * Check integrity: send the Databases list's `integrity` action on the checked set with its
   * globals, through the shell's handler, then show the report or the still-running sentence. A
   * refusal is the envelope's own sentence.
   */
  async check(): Promise<void> {
    if (this.checkingValue || this.stepValue !== REPORT_STEP || this.checkedValue.size === 0) return;
    const generation = this.generation;
    const handler = this.injector.get(ScreenActionHandler);
    this.checkingValue = true;
    this.reasonValue = '';
    this.outcomeValue = 'running';
    this.sinceValue = new Date();
    this.reportTimeValue = '';
    this.reportLinesValue = [];
    this.reportFaultValue = false;
    this.notify();
    let refusal = '';
    const applied = await handler.sendFor(
      DATABASE_LIST_DESCRIPTOR,
      INTEGRITY_ACTION,
      this.target(),
      { [GLOBALS_FIELD]: JSON.stringify(this.globalsSent()) },
      {
        setRefusal: (reason) => {
          refusal = reason;
        },
      }
    );
    if (generation !== this.generation) return;
    this.checkingValue = false;
    // The check was sent, applied or refused: nothing on the form is unsaved any longer.
    this.formDirty.setDirty(false);
    if (!applied) {
      this.outcomeValue = 'refused';
      this.reasonValue = refusal;
      this.notify();
      return;
    }
    if (handler.continued()) {
      this.outcomeValue = 'continues';
      this.notify();
      return;
    }
    this.outcomeValue = 'finished';
    this.notify();
    await this.loadReport(generation);
  }

  // --- internals ------------------------------------------------------------------------------

  private api(): ApiService {
    return this.injector.get(ApiService);
  }

  private checkedDirectories(): readonly string[] {
    return this.databasesValue.filter((row) => this.checkedValue.has(row.directory)).map((row) => row.directory);
  }

  /** The globals sent: the field's names where one database is checked, none otherwise. */
  private globalsSent(): readonly string[] {
    return this.globalsEnabled() ? globalNames(this.globalsValue) : [];
  }

  /** The finished check's report, through the Integrity log's declared read (its newest check's lines). */
  private async loadReport(generation: number): Promise<void> {
    const screen = screenForRoute(INTEGRITY_LOG_ROUTE);
    if (screen === null || screen.read === null) return;
    const result = await this.api().requestJson<{ readonly rows?: unknown }>(screenReadPath(screen, REPORT_MAX_ROWS));
    if (generation !== this.generation) return;
    const rows = result.kind === 'ok' && Array.isArray(result.body?.rows) ? (result.body.rows as readonly unknown[]) : null;
    if (rows === null) {
      this.reportFaultValue = true;
      this.notify();
      return;
    }
    // The declared read answers the newest check's lines in the report's own order.
    this.reportTimeValue = textAt(rows[0], 'time');
    this.reportLinesValue = rows.map((row) => textAt(row, 'text'));
    this.notify();
  }

  private edit(field: string): void {
    this.violationList = this.violationList.filter((entry) => entry.field !== field);
    this.formDirty.setDirty(true);
    this.notify();
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
