/**
 * The hand-off behind a Findings panel's "Fix it" (Story 16.21, AD-11).
 *
 * Home opens the affected screen and then records which check was asked about; the panel takes the
 * request and sends that check's fixed sentence through its own Send path, with the context the
 * opened screen assembles. The sentence is a constant per check and carries no instance text: the
 * object reaches the agent only as that screen's own context.
 *
 * The gate is `ExplainEntry`'s (Story 11.2), delegated rather than copied: the control shows once
 * the agent status and the sharing setting have answered, and refuses under the kill switch, a
 * running turn and sharing off, described by that reason's id.
 *
 * Framework-free, like the rest of `core/` (AD-19).
 */

import type { ExplainEntry, ExplainEntryReason } from './explain-entry';

/** Each fixable check's fixed user message, by its `strings.ts` key. A closed map. */
const SENTENCE_KEYS = {
  'webapp-open': 'findingFixWebappOpen',
  'monitor-open': 'findingFixMonitorOpen',
  'all-holder': 'findingFixAllHolder',
  'auditing-off': 'findingFixAuditingOff',
  'task-error': 'findingFixTaskError',
  'task-manager': 'findingFixTaskManager',
} as const;

export type FixableCheck = keyof typeof SENTENCE_KEYS;

export type FixSentenceKey = (typeof SENTENCE_KEYS)[FixableCheck];

/** Whether `check` has a fixed sentence, and so a write tool that fixes it. */
export function isFixable(check: string): check is FixableCheck {
  return Object.prototype.hasOwnProperty.call(SENTENCE_KEYS, check);
}

/** `check`'s fixed sentence key. Throws for a check outside the closed map. */
export function fixSentenceKey(check: string): FixSentenceKey {
  if (!isFixable(check)) throw new Error(`no fixed sentence for the check '${check}'`);
  return SENTENCE_KEYS[check];
}

/** One pending request: the check and its sentence key. */
export interface FixFindingRequest {
  readonly check: FixableCheck;
  readonly key: FixSentenceKey;
}

export interface FixFindingOptions {
  readonly explainEntry: Pick<ExplainEntry, 'shown' | 'reason' | 'describedBy' | 'subscribe'>;
}

export class FixFinding {
  private readonly gate: FixFindingOptions['explainEntry'];
  private pending: FixFindingRequest | null = null;
  private readonly listeners = new Set<() => void>();

  constructor(options: FixFindingOptions) {
    this.gate = options.explainEntry;
  }

  /** Whether a Fix it control renders at all: `ExplainEntry.shown()`. */
  shown(): boolean {
    return this.gate.shown();
  }

  /** Why a shown control refuses, or `null`: `ExplainEntry.reason()`. */
  reason(): ExplainEntryReason | null {
    return this.gate.reason();
  }

  /** The DOM id of `reason()`'s sentence, or `null`: `ExplainEntry.describedBy()`. */
  describedBy(): string | null {
    return this.gate.describedBy();
  }

  /**
   * Record one request for the panel to send, replacing any not yet taken, and answer whether it
   * was recorded. Throws for a check with no fixed sentence; refused, recording nothing, while the
   * control is not shown or `reason()` names a reason.
   */
  request(check: string): boolean {
    const key = fixSentenceKey(check);
    if (!this.shown() || this.reason() !== null) return false;
    this.pending = { check: check as FixableCheck, key };
    this.notify();
    return true;
  }

  /** The pending request, cleared as it is returned, or `null`. */
  take(): FixFindingRequest | null {
    const pending = this.pending;
    this.pending = null;
    return pending;
  }

  /** Forget a request not yet taken, so a sign-out sends nothing for the departed principal. */
  reset(): void {
    this.pending = null;
  }

  /** Notified by this store's own requests and by every notification of the gate it reads. */
  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    const stopGate = this.gate.subscribe(listener);
    return () => {
      this.listeners.delete(listener);
      stopGate();
    };
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
