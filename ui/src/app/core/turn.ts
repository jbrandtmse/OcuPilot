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

export function turnNavigationPath(id: string): string {
  return TURN_PATH + '/' + encodeURIComponent(id) + '/navigation';
}

/** The one refusal code this client is ever the author of (Story 4.7, `POST /turn/:id/navigation`'s
 * closed vocabulary) -- a dirty `form-page`'s decline, and nothing else. */
export const NAV_REFUSED_UNSAVED_CODE = 'NAV.REFUSEDUNSAVED';

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
  readonly kind: 'model' | 'tool' | 'announce';
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

/**
 * A pending navigation directive (Story 4.7, AD-11 rule 3): the server's own answer to
 * `OcuPilot.Kernel.State.Turn.GuardedView`'s `navigation?` key, carried only while it is paired
 * with the `announce` step it names -- `parseNavigation` enforces that pairing again on this
 * side, so a directive can never be observed here without its announcement already in `steps`.
 */
export interface TurnNavigation {
  readonly seq: number;
  readonly route: string;
  readonly entityId: string;
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

/**
 * A refused Send, as the panel renders it (Story 4.8, DW-1054): the envelope's own `code` and
 * written `reason` where the instance supplied them, and the transport status either way.
 *
 * It carries no sentence of its own. Every refusal the API can produce already has a written
 * `reason` on the instance (`Api/Error.cls`) and `JsonResult`'s error arm already parses it, so
 * the panel renders that; a wrapper sentence here would be a second, weaker copy of the server's
 * own words in front of the user (AD-39). `reason` is `null` only when the answer carried no
 * envelope at all -- a status 0, or a body that is not one -- and the panel falls back to the
 * connectivity sentence `classifyFault` already selects for that status.
 */
export interface SendRefusal {
  readonly status: number;
  readonly code: string | null;
  readonly reason: string | null;
}

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
  const kindRaw = textAt(row, 'kind');
  const kind: TurnStep['kind'] = kindRaw === 'model' ? 'model' : kindRaw === 'announce' ? 'announce' : 'tool';
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

/**
 * The `navigation` key, or `null` -- including when the server's own pairing condition failed
 * to hold on this side for some other reason (a truncated `steps` array, `stepsDropped` having
 * carried the announce step away): the announce step named by `seq` must be present in `steps`,
 * a second check on top of the one `GuardedView` already applies, so a reader here can never
 * observe a directive whose announcement it cannot also see (AD-11 rule 3, AC3).
 */
function parseNavigation(value: unknown, steps: readonly TurnStep[]): TurnNavigation | null {
  const row = asRecord(value);
  if (row === null) return null;
  const seq = numberAt(row, 'seq');
  const announced = steps.some((step) => step.kind === 'announce' && step.seq === seq);
  if (!announced) return null;
  const entityIdRaw = row['entityId'];
  return {
    seq,
    route: textAt(row, 'route'),
    entityId: typeof entityIdRaw === 'string' ? entityIdRaw : '',
  };
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
 * **Two templates, because two real paths name no step** (Story 4.8, DW-1053). A job-level refusal
 * finishes with `errorSeq` 0, and `Step.GuardedAppend` answers a seq for a row it did not store
 * once `MAXSTEPS` is reached -- in both the `seq` lookup misses, and substituting an empty
 * `<step>` rendered "The turn stopped at : ...". `noStepTemplate` names no step at all, so the
 * empty substitution can no longer happen. The choice is made on the rendered **label**, not on the
 * `seq` lookup alone: a step that is found but whose `name` and `target` are both empty substitutes
 * to nothing, so it takes the no-step wording too rather than rendering "at :" again.
 *
 * Both templates end "... <reason>." and every published `TURN.*` and `PROVIDER.*` reason sentence
 * (`Api/Error.cls`, `Kernel/Provider/Base.cls`) may end with its own period, so substituting
 * verbatim would double it ("...abandoned.."). One trailing period is trimmed off `reason` before
 * substitution -- a rendering nicety over a server-authored fixed sentence, not a reformatting of
 * model or tool output (AD-11 governs that text, not this one).
 */
export function turnErrorBanner(
  entry: Pick<TurnEntry, 'state' | 'error' | 'steps'>,
  template: string,
  noStepTemplate: string
): string | null {
  if (entry.state === 'completed' || entry.state === 'stopped') return null;
  if (entry.error === null) return null;
  const step = entry.steps.find((candidate) => candidate.seq === entry.error?.seq) ?? null;
  const reason = entry.error.reason.endsWith('.') ? entry.error.reason.slice(0, -1) : entry.error.reason;
  const label = step === null ? '' : stepLabel(step);
  if (label === '') return noStepTemplate.split('<reason>').join(reason);
  return template.split('<step>').join(label).split('<reason>').join(reason);
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

  /** The last Send the instance refused with anything but 409, or `null` (Story 4.8, DW-1054). */
  private sendErrorValue: SendRefusal | null = null;

  /** Where `createConversation` leaves a refusal for `send()` to read; `null` after a mint that
   * succeeded. Both `send()` and `newConversation()` promote it, because the banner is about the
   * press the user just made and either press can be the one refused. */
  private mintRefusalValue: SendRefusal | null = null;

  /** The live turn's own pending navigation directive, or `null` (Story 4.7). */
  private pendingNavigationValue: TurnNavigation | null = null;

  /**
   * The highest directive `seq` this store has already acted on -- posted to
   * `settleNavigation`, or answered locally with no directive standing at all. `navigation()`
   * excludes it, which is what keeps a directive from being acted on twice: the ~1 s
   * announce-then-move delay and the settle round trip both outlast a single 1,000 ms poll tick,
   * so several polls land while one directive is still open, and every one of them must see it
   * as already spoken for.
   */
  private actedNavigationSeq = 0;

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
   * The Send the instance refused, or `null` (Story 4.8, DW-1054). Set on every non-409 refusal of
   * `POST /turn` and on a conversation mint that failed, whichever press asked for that mint;
   * cleared at the start of the next `send()`, by a `newConversation()` that succeeded and by
   * `endSession()`. A 409 is the lock banner's and never lands here.
   */
  sendError(): SendRefusal | null {
    return this.sendErrorValue;
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
    this.sendErrorValue = null;
    this.pendingNavigationValue = null;
    this.actedNavigationSeq = 0;
    const generation = (this.pollGeneration += 1);
    this.notify();

    if (this.conversationIdValue === null) {
      const created = await this.createConversation();
      if (created === null) {
        if (generation === this.pollGeneration) {
          this.busyValue = false;
          this.sendErrorValue = this.mintRefusalValue;
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
      // `installing` is Session's surface, not this one (`api.ts`): it is not a refusal the user
      // can act on, and the caller's state stays where it is.
      if (started.kind === 'error') {
        this.sendErrorValue = { status: started.status, code: started.code, reason: started.reason };
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
    if (created === null) {
      // The press was refused, and the refusal it left is this surface's (DW-1054). Nothing was
      // started, so the transcript and the lock stay exactly where they were.
      this.sendErrorValue = this.mintRefusalValue;
      this.notify();
      return false;
    }
    this.entriesValue = [];
    this.lockedValue = false;
    // A refusal belongs to the Send that met it. Leaving it set here would float it over a fresh,
    // empty transcript belonging to a conversation it was never about.
    this.sendErrorValue = null;
    this.notify();
    return true;
  }

  /** Sign-out: drop the id, the transcript and any turn in flight (Boundaries & Constraints). */
  endSession(): void {
    this.pollGeneration += 1;
    this.busyValue = false;
    this.lockedValue = false;
    this.sendErrorValue = null;
    this.mintRefusalValue = null;
    this.currentTurnId = null;
    this.liveEntryValue = null;
    this.entriesValue = [];
    this.conversationIdValue = null;
    this.restoredValue = false;
    this.pendingNavigationValue = null;
    this.actedNavigationSeq = 0;
    this.removeItem(CONVERSATION_STORAGE_KEY);
    this.notify();
  }

  /**
   * The live turn's own pending navigation directive (Story 4.7, AD-11 rule 3), or `null` when
   * there is none, or when the one the last poll carried has already been acted on
   * (`settleNavigation`, or a directive that arrived with nothing pending to answer).
   */
  navigation(): TurnNavigation | null {
    if (this.pendingNavigationValue === null) return null;
    if (this.pendingNavigationValue.seq <= this.actedNavigationSeq) return null;
    return this.pendingNavigationValue;
  }

  /**
   * Answer the live turn's own pending directive: `opened` once the browser has navigated,
   * `refused` with `NAV_REFUSED_UNSAVED_CODE` when the departing screen declined. Posts
   * `POST /turn/{id}/navigation`; `code` travels only for a refusal, since the instance's own
   * closed vocabulary (`Api/Turn.cls`'s `NavigationViolation`) accepts it only there.
   *
   * The directive is marked acted **before** the request is sent, not after it resolves: the
   * caller (`agent-navigator.ts`) computes `opened`/`refused` from `Router.navigateByUrl`'s own
   * settled promise, by which point the multi-second announce-then-move sequence is already
   * over, so there is nothing left to race against on this side -- what this ordering actually
   * guards is a second call for the same `seq` (a stale re-render, a caller that already
   * settled) finding `navigation()` already empty rather than posting twice.
   */
  async settleNavigation(outcome: 'opened' | 'refused', code: string | null = null): Promise<boolean> {
    const directive = this.pendingNavigationValue;
    if (directive === null || directive.seq <= this.actedNavigationSeq || this.currentTurnId === null) {
      return false;
    }
    this.actedNavigationSeq = directive.seq;
    const body: Record<string, unknown> = { seq: directive.seq, outcome };
    if (code !== null) body['code'] = code;
    const result = await this.api.requestJson<{ settled: boolean }>(turnNavigationPath(this.currentTurnId), {
      method: 'POST',
      body: JSON.stringify(body),
    });
    return result.kind === 'ok';
  }

  private async createConversation(): Promise<string | null> {
    const generation = this.pollGeneration;
    this.mintRefusalValue = null;
    const result = await this.api.requestJson<{ conversationId: string }>(CONVERSATION_PATH, {
      method: 'POST',
    });
    if (result.kind !== 'ok') {
      if (result.kind === 'error') {
        this.mintRefusalValue = { status: result.status, code: result.code, reason: result.reason };
      }
      return null;
    }
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
    // Only a turn that is still running can carry a directive worth acting on. A stop, an
    // abandon or a failure can land on the same poll as the directive itself, and `notify()`
    // below runs before `finalizeLive` clears it -- so subscribers would otherwise see a live
    // directive for a turn that has already ended.
    this.pendingNavigationValue = isTerminalState(state) ? null : parseNavigation(body['navigation'], steps);
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
    this.pendingNavigationValue = null;
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
