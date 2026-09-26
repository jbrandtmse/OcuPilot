/**
 * The hand-off behind a log or audit entry's "Explain this entry" control (Story 11.2, FR-70).
 *
 * A page records which entry was asked about; the panel takes it and sends the fixed sentence
 * through its own Send path, which is what cancels live cards and follows the transcript. A page
 * never sends a turn itself. The request is a client-side hand-off, not a context channel: what
 * reaches the model is still only the `screen_context` payload the panel assembles (AD-11).
 *
 * The gate is the one "Explain this screen" answers, in its order: the control shows once the
 * agent status has answered with an enabled definition and the sharing setting has answered, and it refuses under the kill switch, a
 * running turn and sharing off, described by that reason's id.
 *
 * Framework-free, like the rest of `core/` (AD-19).
 */

import type { AgentContext } from './agent-context';
import type { AgentStatus } from './agent-status';
import type { ScreenDeclaration } from './screens.generated';
import type { TurnStore } from './turn';

/** The kill-switch banner's id, which is a refused control's reason while the agent is switched off. */
export const KILL_SWITCH_ID = 'ocu-panel-kill-switch';

/** The running-turn reason's id (Story 4.5). */
export const BUSY_REASON_ID = 'ocu-panel-busy-reason';

/** The context chip's sharing-off sentence's id, which describes a control that needs sharing on. */
export const CONTEXT_CHIP_OFF_ID = 'ocu-context-chip-off';

/** Why an entry control refuses, topmost first. */
export type ExplainEntryReason = 'kill-switch' | 'busy' | 'sharing-off';

/** One pending request: the screen the entry is on and the entry as that screen shows it. */
export interface ExplainEntryRequest {
  readonly screen: ScreenDeclaration;
  readonly row: object;
}

export interface ExplainEntryOptions {
  readonly agentStatus: Pick<AgentStatus, 'answered' | 'configured' | 'restraint' | 'subscribe'>;
  readonly agentContext: Pick<AgentContext, 'answered' | 'share' | 'subscribe'>;
  readonly turn: Pick<TurnStore, 'busy' | 'subscribe'>;
}

const REASON_IDS: Readonly<Record<ExplainEntryReason, string>> = {
  'kill-switch': KILL_SWITCH_ID,
  busy: BUSY_REASON_ID,
  'sharing-off': CONTEXT_CHIP_OFF_ID,
};

export class ExplainEntry {
  private readonly agentStatus: ExplainEntryOptions['agentStatus'];
  private readonly agentContext: ExplainEntryOptions['agentContext'];
  private readonly turn: ExplainEntryOptions['turn'];
  private pending: ExplainEntryRequest | null = null;
  private readonly listeners = new Set<() => void>();

  constructor(options: ExplainEntryOptions) {
    this.agentStatus = options.agentStatus;
    this.agentContext = options.agentContext;
    this.turn = options.turn;
  }

  /** Whether an entry control renders at all: the status answered with an enabled definition, and the sharing setting answered. */
  shown(): boolean {
    return this.agentStatus.answered() && this.agentStatus.configured() && this.agentContext.answered();
  }

  /** Why a shown control refuses, or `null`: the kill switch, a running turn, then sharing off. */
  reason(): ExplainEntryReason | null {
    if (this.agentStatus.restraint().killSwitch) return 'kill-switch';
    if (this.turn.busy()) return 'busy';
    if (!this.agentContext.share()) return 'sharing-off';
    return null;
  }

  /** The DOM id of `reason()`'s sentence, for a refused control's `aria-describedby`, or `null`. */
  describedBy(): string | null {
    const reason = this.reason();
    return reason === null ? null : REASON_IDS[reason];
  }

  /**
   * Record one request for the panel to send, replacing any not yet taken, and answer whether it
   * was recorded. Refused, recording nothing, while the control is not shown or `reason()` names a
   * reason.
   */
  request(screen: ScreenDeclaration, row: object): boolean {
    if (!this.shown() || this.reason() !== null) return false;
    this.pending = { screen, row };
    this.notify();
    return true;
  }

  /** The pending request, cleared as it is returned, or `null`. */
  take(): ExplainEntryRequest | null {
    const pending = this.pending;
    this.pending = null;
    return pending;
  }

  /** Notified by this store's own requests and by every notification of the three stores it reads. */
  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    const stops = [
      this.agentStatus.subscribe(listener),
      this.agentContext.subscribe(listener),
      this.turn.subscribe(listener),
    ];
    return () => {
      this.listeners.delete(listener);
      for (const stop of stops) stop();
    };
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
