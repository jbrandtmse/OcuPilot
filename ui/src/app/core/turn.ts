/**
 * The turn store (Story 4.5): send a message, watch it run, stop it, and restore the
 * conversation across a reload -- the client half of 4.1's turn job and 4.5's conversation
 * lock. Framework-free, like the rest of `core/` (AD-19), so `ui/tools/turn.test.mjs` executes
 * it under `node --test`; `panel.ts` mirrors it into signals the same way it already mirrors
 * `AgentStatus` and `PanelState`.
 *
 * **One conversation per tab.** The id lives in `sessionStorage` (`ocupilot.conversation`) and
 * is adopted only on reload or Back/Forward -- `token-store.ts`'s navigation-kind rule, reused
 * here rather than duplicated, so a new or duplicated tab always starts fresh. `restore()` is
 * called once, at bootstrap: with no adopted id it resolves at once: with one, it reads the
 * conversation back and drops the id on a 404 (the owner deleted it, or it never existed).
 *
 * **Ensure, then send.** `send()` mints a conversation with `POST /conversation` when this tab
 * holds none yet, then posts the turn. It sets `busy()` **before** either network call so a
 * second Enter in the same tick is refused locally rather than racing the request; a 409 from
 * another tab is the same refusal arriving late. `send()`'s own promise settles as soon as the
 * outcome is known -- `'sent'`, `'locked'` or `'error'` -- which is what lets `panel.ts` clear
 * the draft the moment a send is accepted rather than waiting for the whole turn; "Send returns
 * when the turn ends, with focus unchanged" (Boundaries & Constraints) is a statement about the
 * control, not this promise -- nothing here ever moves focus, and the poll loop that keeps
 * `busy()` true and appends the finished entry to `entries()` runs detached from this call.
 *
 * **The lock banner is not "another turn exists" -- it is "the last attempt was refused".** This
 * tab has no channel onto a turn another tab is running, so there is nothing to poll to learn
 * when that turn ends. `locked()` is raised by a refused attempt (this tab already busy, or a
 * 409) and is cleared by this tab's own turn finishing, or by the next attempt that gets past
 * the local busy check -- which re-raises it if the instance still refuses. (Judgment call: the
 * spec's matrix pins the same-tab case; the cross-tab case has no wire signal to key a clear on,
 * so the next attempt is what re-asks the question.)
 *
 * **Steps are read, never written, here.** A step's shape mirrors
 * `OcuPilot.Kernel.State.Step.GuardedRows`; `stepLabel` and `turnErrorBanner` are the two pure
 * projections `panel.ts` and `tool-call-card.ts` both need over it, kept here so the wire shape
 * and its two renderings cannot drift apart.
 */

import type { ApiService, JsonResult } from './api';
import type { ScreenContextPayload } from './screen-context';
import type { NavigationKind, TokenStorage } from './token-store';

export const CONVERSATION_PATH = '/api/ocupilot/conversation';
export const TURN_PATH = '/api/ocupilot/turn';

export function conversationReadPath(id: string): string {
  return CONVERSATION_PATH + '/' + encodeURIComponent(id);
}

export function turnProgressPath(id: string): string {
  return TURN_PATH + '/' + encodeURIComponent(id) + '/progress';
}

export function turnStopPath(id: string): string {
  return TURN_PATH + '/' + encodeURIComponent(id) + '/stop';
}

/** Storage key for the per-tab conversation id (Boundaries & Constraints). */
export const CONVERSATION_STORAGE_KEY = 'ocupilot.conversation';

export type TurnState = 'queued' | 'running' | 'completed' | 'stopped' | 'abandoned' | 'failed';

const TERMINAL_STATES: ReadonlySet<TurnState> = new Set([
  'completed',
  'stopped',
  'abandoned',
  'failed',
]);

export function isTerminalState(state: TurnState): boolean {
  return TERMINAL_STATES.has(state);
}

/** A step's status vocabulary (`OcuPilot.Kernel.State.Step`), plus `stopped` (Story 4.5). */
export type TurnStepStatus = 'running' | 'ok' | 'error' | 'stopped';

export interface TurnStepResult {
  readonly rowsReturned: number;
  readonly rowsSent: number;
  readonly truncated: boolean;
}

export interface TurnStep {
  readonly seq: number;
  readonly kind: 'model' | 'tool';
  readonly name: string;
  readonly status: TurnStepStatus;
  readonly summary: string;
  readonly text: string;
  readonly code: string;
  readonly truncated: boolean;
  readonly target: string;
  readonly arguments: string;
  readonly result: TurnStepResult | null;
  readonly reason: string;
  readonly failedPair: string;
}

export interface TurnErrorInfo {
  readonly seq: number;
  readonly code: string;
  readonly reason: string;
}

/** One turn, restored from the conversation or held live while it runs. */
export interface TurnEntry {
  /** The server's 1-based position, or `-1` for the live entry -- the server has not assigned
   * one yet, since `Entry` rows are appended only once the turn ends. */
  readonly seq: number;
  readonly message: string;
  readonly state: TurnState;
  readonly reply: string | null;
  readonly error: TurnErrorInfo | null;
  readonly steps: readonly TurnStep[];
  readonly stepsDropped: number;
  /** True only for the turn this tab is currently running. Never true for a restored entry. */
  readonly live: boolean;
}

export type SendOutcome = 'sent' | 'locked' | 'error';

function textAt(source: Record<string, unknown>, key: string): string {
  const value = source[key];
  return typeof value === 'string' ? value : '';
}

function numberAt(source: Record<string, unknown>, key: string): number {
  const value = source[key];
  return typeof value === 'number' && Number.isFinite(value) ? value : 0;
}

function boolAt(source: Record<string, unknown>, key: string): boolean {
  return source[key] === true;
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return typeof value === 'object' && value !== null ? (value as Record<string, unknown>) : null;
}

function parseStepResult(value: unknown): TurnStepResult | null {
  const row = asRecord(value);
  if (row === null) return null;
  return {
    rowsReturned: numberAt(row, 'rowsReturned'),
    rowsSent: numberAt(row, 'rowsSent'),
    truncated: boolAt(row, 'truncated'),
  };
}

function parseStep(value: unknown): TurnStep | null {
  const row = asRecord(value);
  if (row === null) return null;
  const kind = textAt(row, 'kind') === 'model' ? 'model' : 'tool';
  const status = textAt(row, 'status');
  const validStatus: TurnStepStatus =
    status === 'ok' || status === 'error' || status === 'stopped' ? status : 'running';
  return {
    seq: numberAt(row, 'seq'),
    kind,
    name: textAt(row, 'name'),
    status: validStatus,
    summary: textAt(row, 'summary'),
    text: textAt(row, 'text'),
    code: textAt(row, 'code'),
    truncated: boolAt(row, 'truncated'),
    target: textAt(row, 'target'),
    arguments: textAt(row, 'arguments'),
    result: parseStepResult(row['result']),
    reason: textAt(row, 'reason'),
    failedPair: textAt(row, 'failedPair'),
  };
}

function parseSteps(value: unknown): TurnStep[] {
  if (!Array.isArray(value)) return [];
  const steps: TurnStep[] = [];
  for (const raw of value) {
    const step = parseStep(raw);
    if (step !== null) steps.push(step);
  }
  return steps;
}

function parseError(value: unknown): TurnErrorInfo | null {
  const row = asRecord(value);
  if (row === null) return null;
  return { seq: numberAt(row, 'seq'), code: textAt(row, 'code'), reason: textAt(row, 'reason') };
}

function parseState(value: unknown): TurnState {
  const text = typeof value === 'string' ? value : '';
  if (
    text === 'queued' ||
    text === 'running' ||
    text === 'completed' ||
    text === 'stopped' ||
    text === 'abandoned' ||
    text === 'failed'
  ) {
    return text;
  }
  return 'queued';
}

/**
 * `steps` as a finished turn shows them: a step still `running` when its turn ended (its job died
 * mid-call) is shown `error`, carrying the turn's own error reason, so no finished turn renders a
 * running card.
 */
function settledSteps(steps: readonly TurnStep[], error: TurnErrorInfo | null): TurnStep[] {
  return steps.map((step): TurnStep =>
    step.status === 'running' ? { ...step, status: 'error', reason: step.reason || (error?.reason ?? '') } : step
  );
}

/** One restored conversation entry (`OcuPilot.Kernel.State.Convo.GuardedView`'s `turns[]`). */
function parseRestoredEntry(value: unknown): TurnEntry | null {
  const row = asRecord(value);
  if (row === null) return null;
  const replyRaw = row['reply'];
  const error = parseError(row['error']);
  return {
    seq: numberAt(row, 'seq'),
    message: textAt(row, 'message'),
    state: parseState(row['state']),
    reply: typeof replyRaw === 'string' ? replyRaw : null,
    error,
    steps: settledSteps(parseSteps(row['steps']), error),
    stepsDropped: numberAt(row, 'stepsDropped'),
    live: false,
  };
}

/** A step's rendered label: its canonical name, plus its target when it carries one. */
export function stepLabel(step: Pick<TurnStep, 'name' | 'target'>): string {
  return step.target === '' ? step.name : step.name + ' ' + step.target;
}

/**
 * The error banner text for `entry`, or `null` when none should show. `completed` and `stopped`
 * never show one -- a stop is not an error (Design Notes; the I/O matrix's Stop row: "no reply,
 * no error banner") even though a stopped turn's own `error.code` is `TURN.STOPPED`.
 *
 * `template` ends "... <reason>." (`STRINGS.agentTurnStoppedBanner`) and every published
 * `TURN.*` reason sentence (`Api/Error.cls`) already ends with its own period, so substituting
 * verbatim would double it ("...abandoned.."). One trailing period is trimmed off `reason`
 * before substitution -- a rendering nicety over a server-authored fixed sentence, not a
 * reformatting of model or tool output (AD-11 governs that text, not this one).
 */
export function turnErrorBanner(entry: Pick<TurnEntry, 'state' | 'error' | 'steps'>, template: string): string | null {
  if (entry.state === 'completed' || entry.state === 'stopped') return null;
  if (entry.error === null) return null;
  const step = entry.steps.find((candidate) => candidate.seq === entry.error?.seq) ?? null;
  const stepText = step === null ? '' : stepLabel(step);
  const reason = entry.error.reason.endsWith('.') ? entry.error.reason.slice(0, -1) : entry.error.reason;
  return template.split('<step>').join(stepText).split('<reason>').join(reason);
}

export interface TurnStoreOptions {
  readonly api: ApiService;
  /** The tab's `sessionStorage`, or an in-memory stand-in (`token-store.ts`'s `readSessionStorage`). */
  readonly storage: TokenStorage;
  /** How this document was navigated to, read once at construction (`token-store.ts`). */
  readonly navigationType: () => NavigationKind;
  /** Defaults to `setTimeout`. Injected so `turn.test.mjs` drives the poll by hand. */
  readonly schedule?: (run: () => void, delayMs: number) => void;
  /** The poll interval in ms. Defaults to 1,000 (Boundaries & Constraints). */
  readonly pollMs?: number;
}

export class TurnStore {
  private readonly api: ApiService;
  private readonly storage: TokenStorage;
  private readonly schedule: (run: () => void, delayMs: number) => void;
  private readonly pollMs: number;

  private conversationIdValue: string | null = null;
  private entriesValue: TurnEntry[] = [];
  private liveEntryValue: TurnEntry | null = null;
  private currentTurnId: string | null = null;
  private busyValue = false;
  private lockedValue = false;
  private restoredValue = false;

  /** Bumped on every `send()` and on `endSession()`, so a stale poll loop's tick is inert. */
  private pollGeneration = 0;

  private readonly listeners = new Set<() => void>();

  constructor(options: TurnStoreOptions) {
    this.api = options.api;
    this.storage = options.storage;
    this.schedule =
      options.schedule ??
      ((run, delayMs) => {
        setTimeout(run, delayMs);
      });
    this.pollMs = options.pollMs ?? 1000;

    const kind = options.navigationType();
    const continuesThisTab = kind === 'reload' || kind === 'back_forward';
    const stored = this.readItem(CONVERSATION_STORAGE_KEY);
    if (continuesThisTab && stored !== null && stored !== '') {
      this.conversationIdValue = stored;
    } else {
      this.removeItem(CONVERSATION_STORAGE_KEY);
    }
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  conversationId(): string | null {
    return this.conversationIdValue;
  }

  /** Whether `restore()` has settled -- once, at bootstrap. */
  restored(): boolean {
    return this.restoredValue;
  }

  /** Every finished turn, oldest first, then the live turn while one is running. */
  entries(): readonly TurnEntry[] {
    return this.liveEntryValue === null ? this.entriesValue : [...this.entriesValue, this.liveEntryValue];
  }

  busy(): boolean {
    return this.busyValue;
  }

  locked(): boolean {
    return this.lockedValue;
  }

  /**
   * Read the adopted conversation back, once. A no-op (resolves at once) when this tab adopted
   * no id -- a new or duplicated tab starts fresh. A 404 drops the id (Boundaries & Constraints).
   */
  async restore(): Promise<void> {
    if (this.conversationIdValue === null) {
      this.restoredValue = true;
      this.notify();
      return;
    }
    const generation = this.pollGeneration;
    const result = await this.api.requestJson<Record<string, unknown>>(
      conversationReadPath(this.conversationIdValue)
    );
    // Superseded by `endSession()` while the read was in flight: the transcript is the signed-out
    // principal's, and must not land.
    if (generation !== this.pollGeneration) return;
    if (result.kind === 'error' && result.status === 404) {
      this.conversationIdValue = null;
      this.removeItem(CONVERSATION_STORAGE_KEY);
      this.entriesValue = [];
    } else if (result.kind === 'ok') {
      const turnsRaw = result.body['turns'];
      const turns = Array.isArray(turnsRaw) ? turnsRaw : [];
      const entries: TurnEntry[] = [];
      for (const raw of turns) {
        const entry = parseRestoredEntry(raw);
        if (entry !== null) entries.push(entry);
      }
      this.entriesValue = entries;
    }
    // Any other outcome (a transport fault, a refusal) leaves the id and the transcript as they
    // were: only a confirmed 404 says the conversation is gone, and dropping an id over a blip
    // would lose a conversation that is still there.
    this.restoredValue = true;
    this.notify();
  }

  /**
   * Send `message`, with `context` (Story 4.11) attached to the body when it is not `null` --
   * `panel.ts` assembles it fresh at the moment Send is pressed (`assembleScreenContext`), so a
   * turn always carries the screen the user was on when they sent it, never a cached one. Refused
   * locally (no request at all) when this tab already has a turn running; refused by the instance
   * with 409 when another tab does. Both refusals raise the lock banner and leave the draft to
   * the caller -- this store never reads or clears it (`PanelState` owns the draft, and clears it
   * itself on `'sent'`).
   *
   * **Resolves as soon as the outcome is known** -- accepted, locked or refused -- not once the
   * turn ends: `busy()` and `entries()` already reflect an accepted send by the time this
   * resolves, which is what lets the caller clear the draft immediately on `'sent'`. Polling runs
   * detached from this call; `busy()` clears itself, and the finished turn lands in `entries()`,
   * whenever the poll loop reaches a terminal state.
   */
  async send(message: string, context: ScreenContextPayload | null = null): Promise<SendOutcome> {
    if (this.busyValue) {
      this.lockedValue = true;
      this.notify();
      return 'locked';
    }
    this.busyValue = true;
    this.lockedValue = false;
    const generation = (this.pollGeneration += 1);
    this.notify();

    if (this.conversationIdValue === null) {
      const created = await this.createConversation();
      if (created === null) {
        if (generation === this.pollGeneration) {
          this.busyValue = false;
          this.notify();
        }
        return 'error';
      }
    }
    const started = await this.api.requestJson<{ turnId: string }>(TURN_PATH, {
      method: 'POST',
      body: JSON.stringify({
        message,
        conversationId: this.conversationIdValue,
        ...(context !== null ? { context } : {}),
      }),
    });
    if (generation !== this.pollGeneration) {
      // Superseded by `endSession()` while the request was in flight -- already reset.
      return 'error';
    }
    if (started.kind === 'error' && started.status === 409) {
      this.busyValue = false;
      this.lockedValue = true;
      this.notify();
      return 'locked';
    }
    if (started.kind !== 'ok') {
      if (started.kind === 'error' && started.status === 404) {
        // The conversation is gone; the next send starts a fresh one.
        this.conversationIdValue = null;
        this.removeItem(CONVERSATION_STORAGE_KEY);
      }
      this.busyValue = false;
      this.notify();
      return 'error';
    }
    this.currentTurnId = started.body.turnId;
    this.liveEntryValue = {
      seq: -1,
      message,
      state: 'running',
      reply: null,
      error: null,
      steps: [],
      stepsDropped: 0,
      live: true,
    };
    this.notify();
    void this.pollUntilTerminal(generation).then(() => {
      if (generation !== this.pollGeneration) return;
      this.busyValue = false;
      this.lockedValue = false;
      this.currentTurnId = null;
      this.notify();
    });
    return 'sent';
  }

  /**
   * Ask this tab's own live turn to stop, when there is one. Fire-and-forget from the caller's
   * side: the next poll tick observes the resulting `stopped` state, which is what actually
   * updates the transcript. Answers the server's own `stopRequested`, for a caller that wants it.
   */
  async stop(): Promise<boolean> {
    if (!this.busyValue || this.currentTurnId === null) return false;
    const result = await this.api.requestJson<{ stopRequested: boolean }>(turnStopPath(this.currentTurnId), {
      method: 'POST',
    });
    return result.kind === 'ok' && result.body.stopRequested === true;
  }

  /**
   * Start a fresh conversation and clear the transcript. Refused while busy -- the caller
   * (`panel.ts`) also holds the control `aria-disabled` for the same reason, but this guard
   * keeps the store correct on its own.
   */
  async newConversation(): Promise<boolean> {
    if (this.busyValue) return false;
    const created = await this.createConversation();
    if (created === null) return false;
    this.entriesValue = [];
    this.lockedValue = false;
    this.notify();
    return true;
  }

  /** Sign-out: drop the id, the transcript and any turn in flight (Boundaries & Constraints). */
  endSession(): void {
    this.pollGeneration += 1;
    this.busyValue = false;
    this.lockedValue = false;
    this.currentTurnId = null;
    this.liveEntryValue = null;
    this.entriesValue = [];
    this.conversationIdValue = null;
    this.restoredValue = false;
    this.removeItem(CONVERSATION_STORAGE_KEY);
    this.notify();
  }

  private async createConversation(): Promise<string | null> {
    const generation = this.pollGeneration;
    const result = await this.api.requestJson<{ conversationId: string }>(CONVERSATION_PATH, {
      method: 'POST',
    });
    if (result.kind !== 'ok') return null;
    if (generation !== this.pollGeneration) {
      // Superseded by `endSession()` while the request was in flight -- already reset.
      return null;
    }
    this.conversationIdValue = result.body.conversationId;
    this.writeItem(CONVERSATION_STORAGE_KEY, this.conversationIdValue);
    return this.conversationIdValue;
  }

  private pollUntilTerminal(generation: number): Promise<void> {
    return new Promise((resolve) => {
      const tick = () => {
        this.schedule(() => {
          void this.pollOnce(generation).then((done) => {
            if (done || generation !== this.pollGeneration) {
              resolve();
              return;
            }
            tick();
          });
        }, this.pollMs);
      };
      tick();
    });
  }

  /** One poll. Answers `true` once the turn is done (terminal, not found, or unreadable). */
  private async pollOnce(generation: number): Promise<boolean> {
    if (generation !== this.pollGeneration || this.currentTurnId === null) return true;
    const result: JsonResult<Record<string, unknown>> = await this.api.requestJson(
      turnProgressPath(this.currentTurnId)
    );
    if (generation !== this.pollGeneration) return true;
    if (result.kind === 'installing' || (result.kind === 'error' && (result.status === 0 || result.status >= 500))) {
      // A transport fault or a server error is transient: keep polling, which also keeps the
      // turn's lease renewed (AD-31).
      return false;
    }
    if (result.kind !== 'ok') {
      // A refusal (404: the turn's own record swept; 401/403) ends the wait; there is nothing
      // further this tab can learn about a turn it can no longer see.
      this.finalizeLive('abandoned', null, null);
      return true;
    }
    const body = result.body;
    const state = parseState(body['state']);
    const steps = parseSteps(body['steps']);
    const stepsDropped = numberAt(body, 'stepsDropped');
    const replyRaw = body['reply'];
    const reply = typeof replyRaw === 'string' ? replyRaw : null;
    const error = parseError(body['error']);
    if (this.liveEntryValue !== null) {
      this.liveEntryValue = { ...this.liveEntryValue, state, steps, stepsDropped, reply, error };
      this.notify();
    }
    if (!isTerminalState(state)) return false;
    this.finalizeLive(state, reply, error);
    return true;
  }

  /** Move the live entry into history with its final outcome, and drop the live slot. */
  private finalizeLive(state: TurnState, reply: string | null, error: TurnErrorInfo | null): void {
    if (this.liveEntryValue === null) return;
    const finished: TurnEntry = {
      ...this.liveEntryValue,
      state,
      reply,
      error,
      steps: settledSteps(this.liveEntryValue.steps, error),
      live: false,
    };
    this.entriesValue = [...this.entriesValue, finished];
    this.liveEntryValue = null;
    this.notify();
  }

  private readItem(key: string): string | null {
    try {
      return this.storage.getItem(key);
    } catch {
      return null;
    }
  }

  private writeItem(key: string, value: string): void {
    try {
      this.storage.setItem(key, value);
    } catch {
      // deliberately ignored -- see token-store.ts
    }
  }

  private removeItem(key: string): void {
    try {
      this.storage.removeItem(key);
    } catch {
      // deliberately ignored -- see token-store.ts
    }
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
