/**
 * Home's Findings panel over `/api/ocupilot/ui/findings` (Story 16.21): the store, and the pure
 * `findingLines` that turns an answer into each group's lines.
 *
 * **Its own caller-own chrome read.** It carries the shell's namespace like every other call, and
 * no timer re-reads it (AD-43): Home loads it when it opens, on a namespace switch and on a covered
 * change event. A read that does not answer leaves the previous answer standing and raises
 * `failed()`; only the newest read settles, and `reset()` drops a departed principal's answer.
 *
 * **An unread check is never clean.** A group says "Nothing to report." only when every one of its
 * checks answered `checked`; each other check says "Not checked" with why.
 *
 * Framework-free, like the rest of `core/` (AD-19).
 */

import type { ApiService, JsonResult } from './api';
import { STRINGS } from './strings.ts';

/** Absolute from the origin root, through the one API service (AD-20). */
export const FINDINGS_PATH = '/api/ocupilot/ui/findings';

/** The nine checks, in the order the panel lists them, each with its group. */
export const FINDING_CHECKS = [
  'webapp-open',
  'monitor-open',
  'all-holder',
  'certificate',
  'auditing-off',
  'database-dismounted',
  'database-full',
  'task-manager',
  'task-error',
] as const;

export type FindingCheck = (typeof FINDING_CHECKS)[number];

export type FindingGroupKey = 'security' | 'operations';

export const FINDING_GROUPS: readonly FindingGroupKey[] = ['security', 'operations'];

const GROUP_OF: Readonly<Record<FindingCheck, FindingGroupKey>> = {
  'webapp-open': 'security',
  'monitor-open': 'security',
  'all-holder': 'security',
  certificate: 'security',
  'auditing-off': 'security',
  'database-dismounted': 'operations',
  'database-full': 'operations',
  'task-manager': 'operations',
  'task-error': 'operations',
};

const CHECK_NAMES: Readonly<Record<FindingCheck, string>> = {
  'webapp-open': STRINGS.findingsCheckWebappOpen,
  'monitor-open': STRINGS.findingsCheckMonitorOpen,
  'all-holder': STRINGS.findingsCheckAllHolder,
  certificate: STRINGS.findingsCheckCertificate,
  'auditing-off': STRINGS.findingsCheckAuditingOff,
  'database-dismounted': STRINGS.findingsCheckDatabaseDismounted,
  'database-full': STRINGS.findingsCheckDatabaseFull,
  'task-manager': STRINGS.findingsCheckTaskManager,
  'task-error': STRINGS.findingsCheckTaskError,
};

/** The two banner keys a `task-manager` finding's `detail` may carry. */
const TASK_MANAGER_BANNERS = ['taskManagerSuspendedBanner', 'taskManagerStoppedBanner'] as const;

type TaskManagerBanner = (typeof TASK_MANAGER_BANNERS)[number];

export type CheckStatus = 'checked' | 'unchecked' | 'truncated' | 'failed';

export type FindingFix = 'agent' | 'link' | 'refused';

export interface CheckRow {
  readonly check: FindingCheck;
  readonly status: CheckStatus;
  /** The pair the caller lacks, on an `unchecked` row; `''` otherwise. */
  readonly pair: string;
}

export interface Finding {
  readonly check: FindingCheck;
  readonly group: FindingGroupKey;
  readonly name: string;
  readonly id: string;
  readonly route: string;
  readonly scope: string;
  readonly detail: string;
  readonly expired: boolean;
  readonly fix: FindingFix;
  /** The prohibited set's code and sentence, on a `refused` finding; `null` otherwise. */
  readonly refused: { readonly code: string; readonly reason: string } | null;
}

export interface FindingsAnswer {
  readonly checks: readonly CheckRow[];
  readonly findings: readonly Finding[];
}

/** One line of a group: a finding, an unread check, or the group's clean line. */
export interface FindingLine {
  readonly key: string;
  readonly kind: 'finding' | 'unread' | 'clean';
  /** The finding's sentence, or the unread or clean line. */
  readonly text: string;
  /** Why it matters; `''` where the sentence carries it or the line is not a finding. */
  readonly why: string;
  /** What to do; `''` where the line is not a finding. */
  readonly todo: string;
  readonly finding: Finding | null;
}

export interface FindingGroupLines {
  readonly key: FindingGroupKey;
  readonly heading: string;
  readonly lines: readonly FindingLine[];
}

const STATUSES: readonly CheckStatus[] = ['checked', 'unchecked', 'truncated', 'failed'];

const FIXES: readonly FindingFix[] = ['agent', 'link', 'refused'];

function isCheck(value: unknown): value is FindingCheck {
  return typeof value === 'string' && (FINDING_CHECKS as readonly string[]).includes(value);
}

function record(value: unknown): Record<string, unknown> | null {
  return typeof value === 'object' && value !== null && !Array.isArray(value) ? (value as Record<string, unknown>) : null;
}

function text(value: Record<string, unknown>, key: string): string {
  const member = value[key];
  return typeof member === 'string' ? member : '';
}

/**
 * The answer `body` carries, narrowed: a check row or finding naming no known check, or a status
 * or fix outside its vocabulary, is dropped, and a check the answer does not list reads as never
 * checked. `null` for a body that is not an answer.
 */
export function findingsOf(body: unknown): FindingsAnswer | null {
  const answer = record(body);
  if (answer === null || !Array.isArray(answer['checks']) || !Array.isArray(answer['findings'])) return null;
  const checks: CheckRow[] = [];
  for (const entry of answer['checks']) {
    const row = record(entry);
    if (row === null || !isCheck(row['check'])) continue;
    const status = text(row, 'status') as CheckStatus;
    if (!STATUSES.includes(status)) continue;
    checks.push({ check: row['check'], status, pair: text(row, 'pair') });
  }
  const findings: Finding[] = [];
  for (const entry of answer['findings']) {
    const row = record(entry);
    if (row === null || !isCheck(row['check'])) continue;
    const fix = text(row, 'fix') as FindingFix;
    if (!FIXES.includes(fix)) continue;
    const refusedRow = record(row['refused']);
    const refused = refusedRow === null ? null : { code: text(refusedRow, 'code'), reason: text(refusedRow, 'reason') };
    if (fix === 'refused' && (refused === null || refused.reason === '')) continue;
    findings.push({
      check: row['check'],
      group: GROUP_OF[row['check']],
      name: text(row, 'name'),
      id: text(row, 'id'),
      route: text(row, 'route'),
      scope: text(row, 'scope'),
      detail: text(row, 'detail'),
      expired: row['expired'] === true,
      fix,
      refused: fix === 'refused' ? refused : null,
    });
  }
  return { checks, findings };
}

function filled(template: string, values: Readonly<Record<string, string>>): string {
  let out = template;
  for (const [placeholder, value] of Object.entries(values)) out = out.split(`<${placeholder}>`).join(value);
  return out;
}

/** A finding's sentence, why and what to do, or `null` for one this client cannot phrase. */
function phrase(finding: Finding): { text: string; why: string; todo: string } | null {
  const name = { name: finding.name };
  switch (finding.check) {
    case 'webapp-open':
      return { text: filled(STRINGS.findingWebappOpen, name), why: STRINGS.findingWebappOpenWhy, todo: STRINGS.findingWebappOpenDo };
    case 'monitor-open':
      return { text: filled(STRINGS.findingMonitorOpen, name), why: STRINGS.findingMonitorOpenWhy, todo: STRINGS.findingMonitorOpenDo };
    case 'all-holder':
      return { text: filled(STRINGS.findingAllHolder, name), why: STRINGS.findingAllHolderWhy, todo: STRINGS.findingAllHolderDo };
    case 'certificate':
      return {
        text: filled(finding.expired ? STRINGS.findingCertificateExpired : STRINGS.findingCertificate, { ...name, date: finding.detail }),
        why: STRINGS.findingCertificateWhy,
        todo: STRINGS.findingCertificateDo,
      };
    case 'auditing-off':
      return { text: STRINGS.auditingStatusOff, why: STRINGS.findingAuditingOffWhy, todo: STRINGS.findingAuditingOffDo };
    case 'database-dismounted':
      return { text: filled(STRINGS.findingDatabaseDismounted, name), why: STRINGS.findingDatabaseDismountedWhy, todo: STRINGS.findingDatabaseDismountedDo };
    case 'database-full':
      return {
        text: filled(STRINGS.findingDatabaseFull, { ...name, percent: finding.detail }),
        why: STRINGS.findingDatabaseFullWhy,
        todo: STRINGS.findingDatabaseFullDo,
      };
    case 'task-manager': {
      if (!(TASK_MANAGER_BANNERS as readonly string[]).includes(finding.detail)) return null;
      const banner = finding.detail as TaskManagerBanner;
      return {
        text: STRINGS[banner],
        why: '',
        todo: banner === 'taskManagerSuspendedBanner' ? STRINGS.findingTaskManagerSuspendedDo : STRINGS.findingTaskManagerStoppedDo,
      };
    }
    case 'task-error':
      return { text: filled(STRINGS.findingTaskError, name), why: STRINGS.findingTaskErrorWhy, todo: STRINGS.findingTaskErrorDo };
  }
}

/** Why an unread check was not read, appended to its "Not checked" line. */
function unreadSuffix(row: CheckRow): string {
  if (row.status === 'truncated') return STRINGS.impactTooMany;
  if (row.status === 'failed') return STRINGS.findingsCouldNotRead;
  return row.pair === '' ? '' : filled(STRINGS.impactRequires, { pair: row.pair });
}

/**
 * Each group's lines, Security first: its findings in answer order, then a "Not checked" line for
 * each check that was not read, or "Nothing to report." when every check of the group was read
 * and none found anything.
 */
export function findingLines(answer: FindingsAnswer): readonly FindingGroupLines[] {
  return FINDING_GROUPS.map((group) => {
    const lines: FindingLine[] = [];
    for (const finding of answer.findings) {
      if (finding.group !== group) continue;
      const phrased = phrase(finding);
      if (phrased === null) continue;
      lines.push({ key: `${finding.check}:${finding.id}`, kind: 'finding', ...phrased, finding });
    }
    let allChecked = true;
    for (const check of FINDING_CHECKS) {
      if (GROUP_OF[check] !== group) continue;
      const row = answer.checks.find((candidate) => candidate.check === check);
      if (row !== undefined && row.status === 'checked') continue;
      allChecked = false;
      if (row === undefined) continue;
      lines.push({
        key: `unread:${check}`,
        kind: 'unread',
        text: filled(STRINGS.findingsNotChecked, { check: CHECK_NAMES[check] }) + unreadSuffix(row),
        why: '',
        todo: '',
        finding: null,
      });
    }
    if (allChecked && lines.length === 0) {
      lines.push({ key: `clean:${group}`, kind: 'clean', text: STRINGS.findingsNothing, why: '', todo: '', finding: null });
    }
    return { key: group, heading: group === 'security' ? STRINGS.findingsSecurity : STRINGS.findingsOperations, lines };
  });
}

export interface FindingsOptions {
  readonly api: ApiService;
}

export class Findings {
  private readonly api: ApiService;

  private dataValue: FindingsAnswer | null = null;

  private failedValue = false;

  /** Bumped by `reset()`, so an answer for a departed principal never lands (AD-8). */
  private generation = 0;

  /** Bumped by every `load()`, so only the newest settles. */
  private request = 0;

  private readonly listeners = new Set<() => void>();

  constructor(options: FindingsOptions) {
    this.api = options.api;
  }

  /** Whether a read has ever answered. */
  answered(): boolean {
    return this.dataValue !== null;
  }

  /** Whether the most recent read did not answer. Cleared by the next one that does. */
  failed(): boolean {
    return this.failedValue;
  }

  /** The last answer, or `null` before the first. */
  data(): FindingsAnswer | null {
    return this.dataValue;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /** Read the findings. A read that does not answer leaves the previous answer standing. */
  async load(): Promise<void> {
    const generation = this.generation;
    const request = (this.request += 1);
    const result: JsonResult<unknown> = await this.api.requestJson<unknown>(FINDINGS_PATH);
    if (generation !== this.generation || request !== this.request) return;
    const answer = result.kind === 'ok' ? findingsOf(result.body) : null;
    if (answer === null) {
      if (this.failedValue) return;
      this.failedValue = true;
      this.notify();
      return;
    }
    this.dataValue = answer;
    this.failedValue = false;
    this.notify();
  }

  /** Forget the answer, so a sign-out leaves nothing of the departed principal's on Home. */
  reset(): void {
    this.generation += 1;
    this.request += 1;
    this.dataValue = null;
    this.failedValue = false;
    this.notify();
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
