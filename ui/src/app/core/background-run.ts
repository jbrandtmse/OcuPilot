/**
 * The client half of an owner-scoped background run (Story 19.15's SQL console, Story 20.33's MDX
 * query): start it, follow it by polling, cancel it, stop following it, and read what it answered.
 *
 * Framework-free, and in `core/` because two screens' stores configure one `BackgroundRun` each by
 * its base path, the code its start answers when the caller's own run is still live, and the parser
 * of its answer. A run lives on the instance (`Kernel.Shell.BackgroundRun`); this holds only what the
 * screen shows of it: its id, where it stands, its answer and its refusal.
 *
 * **A start answers one of three things.** A run id attaches the run and polls it; a 200 body with no
 * id is the caller's own answer (the SQL console's `parameters` and `error` outcomes, the MDX query's
 * `confirm` and `error`), handed back untouched and attaching nothing; a refusal comes back as its
 * sentence, and a busy owner's refusal also attaches the run it names.
 *
 * **Polling.** A run its poll no longer finds (swept, replaced, never the caller's) leaves the
 * section; a transient failure (the instance installing, no answer, a 5xx) polls again; any other
 * refusal ends the polling with its sentence, and the run then no longer reads running. A tick or an
 * answer of an older poll is dropped (`generation`), and `stopPolling` drops the pending ones.
 *
 * Nothing here is stored or sent beyond the request it is handed: the answer is the screen's alone
 * (AD-39's sixth exception).
 */

import type { ApiService, JsonResult } from './api';
import { schedulePoll } from './poll-schedule.ts';
import { STRINGS } from './strings.ts';

/** How often a background run is polled while it runs, in milliseconds. */
export const BACKGROUND_POLL_MS = 1000;

/** Where a background run stands, as its poll reads it. */
export type BackgroundStatus = 'running' | 'ended' | 'canceled' | 'failed';

/** What a run's calls go through, the namespace they are scoped to, and when its next poll is sent. */
export interface BackgroundDeps {
  readonly api: Pick<ApiService, 'requestJson'>;
  readonly scope: () => string;
  /** When the next poll is sent; `schedulePoll` by default. A spec drives the poll by hand. */
  readonly schedule?: (run: () => void, delayMs: number) => void;
}

/** The sentence a refusal shows, from its envelope's code, reason and detail. */
export type RefusalText = (code: string | null, reason: string | null, detail: Readonly<Record<string, unknown>> | null) => string;

/** What makes one kind of run: where its routes are, what its busy refusal is called, and how its answer reads. */
export interface BackgroundConfig<A> {
  /** The start route; the poll route is `<path>/<id>` and the cancel route `<path>/<id>/cancel`. */
  readonly path: string;
  /** The machine code a start answers when the caller's own run of this kind is still running. */
  readonly busyCode: string;
  /** One run's `result`, or `null` for any other shape. */
  readonly answerOf: (result: unknown) => A | null;
  readonly refusalText: RefusalText;
}

/** One answer of the poll or cancel route, or `null` for any other shape. */
export interface BackgroundView<A> {
  readonly id: string;
  readonly status: BackgroundStatus;
  readonly answer: A | null;
  readonly refusal: string;
}

/** What a start came to. */
export type BackgroundStart =
  | { readonly kind: 'attached'; readonly id: string }
  | { readonly kind: 'answered'; readonly body: unknown }
  | { readonly kind: 'refused'; readonly refusal: string; readonly attached: boolean };

/** A run's poll route, or its cancel route when `cancel`, under the start route `path`. */
export function runPath(path: string, id: string, cancel = false): string {
  return `${path}/${encodeURIComponent(id)}${cancel ? '/cancel' : ''}`;
}

/** One answer of a run's poll or cancel route, read with `answerOf` and `refusalText`, or `null` for any other shape. */
export function backgroundViewOf<A>(body: unknown, answerOf: (result: unknown) => A | null, refusalText: RefusalText): BackgroundView<A> | null {
  if (body === null || typeof body !== 'object') return null;
  const record = body as Readonly<Record<string, unknown>>;
  const status = record['status'];
  if (typeof record['id'] !== 'string' || (status !== 'running' && status !== 'ended' && status !== 'canceled' && status !== 'failed')) return null;
  const refused = record['refusal'];
  let refusal = '';
  if (refused !== null && typeof refused === 'object') {
    const envelope = refused as Readonly<Record<string, unknown>>;
    const detail = envelope['detail'];
    refusal = refusalText(
      typeof envelope['code'] === 'string' ? envelope['code'] : null,
      typeof envelope['reason'] === 'string' ? envelope['reason'] : null,
      detail !== null && typeof detail === 'object' ? (detail as Readonly<Record<string, unknown>>) : null
    );
  }
  return { id: record['id'], status, answer: answerOf(record['result']), refusal };
}

export class BackgroundRun<A> {
  private readonly config: BackgroundConfig<A>;

  private readonly onChange: () => void;

  /** The run on screen: its id, where it stands, its answer and its refusal. */
  private idValue: string | null = null;

  private statusValue: BackgroundStatus | null = null;

  private answerValue: A | null = null;

  private refusalValue = '';

  /** Whether a start is on its way. */
  private startingValue = false;

  /** Which poll is current; a tick or an answer of an older one is dropped. */
  private generation = 0;

  /** `onChange` is called after every change of what the screen shows. */
  constructor(config: BackgroundConfig<A>, onChange: () => void) {
    this.config = config;
    this.onChange = onChange;
  }

  /** The run's id, or `null` when none is on screen. */
  id(): string | null {
    return this.idValue;
  }

  status(): BackgroundStatus | null {
    return this.statusValue;
  }

  answer(): A | null {
    return this.answerValue;
  }

  refusal(): string {
    return this.refusalValue;
  }

  /** Whether a start is on its way or the run on screen still runs. */
  busy(): boolean {
    return this.startingValue || this.statusValue === 'running';
  }

  /**
   * Post `body` to the start route. `null` when a run is already live and nothing was sent; otherwise
   * what the start came to. A run id attaches the run and polls it, unless polling stopped while the
   * start was on its way (the page went): it is then attached unpolled, and followed again when the
   * page returns.
   *
   * `settle`, when given, is called with the outcome before anything is attached or polled, so a caller
   * that must decide what the run means is not raced by the first poll's answer.
   */
  async start(deps: BackgroundDeps, body: string, settle?: (outcome: BackgroundStart) => void): Promise<BackgroundStart | null> {
    if (this.busy()) return null;
    this.startingValue = true;
    this.onChange();
    const polling = this.generation;
    const result: JsonResult<unknown> = await deps.api.requestJson<unknown>(this.config.path, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body,
      scope: deps.scope(),
    });
    this.startingValue = false;
    const follow = polling === this.generation;
    if (result.kind === 'ok') {
      const answered = result.body as Readonly<Record<string, unknown>> | null;
      const id = answered !== null && typeof answered === 'object' ? answered['id'] : undefined;
      if (typeof id === 'string' && id !== '') {
        const attached: BackgroundStart = { kind: 'attached', id };
        settle?.(attached);
        this.attach(deps, id, follow);
        return attached;
      }
      const answer: BackgroundStart = { kind: 'answered', body: result.body };
      settle?.(answer);
      this.onChange();
      return answer;
    }
    const refusal =
      (result.kind === 'error' ? this.config.refusalText(result.code, result.reason, result.detail) : '') || STRINGS.connectivityRequestRefused;
    const running = result.kind === 'error' && result.code === this.config.busyCode ? result.detail?.['runId'] : undefined;
    if (typeof running === 'string' && running !== '') {
      const refused: BackgroundStart = { kind: 'refused', refusal, attached: true };
      settle?.(refused);
      this.attach(deps, running, follow);
      return refused;
    }
    const refused: BackgroundStart = { kind: 'refused', refusal, attached: false };
    settle?.(refused);
    this.onChange();
    return refused;
  }

  /** Poll the run on screen once, and again every `BACKGROUND_POLL_MS` while it runs. */
  async poll(deps: BackgroundDeps): Promise<void> {
    const id = this.idValue;
    if (id === null) return;
    const generation = ++this.generation;
    const result: JsonResult<unknown> = await deps.api.requestJson<unknown>(runPath(this.config.path, id), { scope: deps.scope() });
    if (generation !== this.generation || id !== this.idValue) return;
    this.read(deps, result, generation);
  }

  /** Cancel the run on screen: its answer is read as a poll's, and polling goes on until it ends. */
  async cancel(deps: BackgroundDeps): Promise<void> {
    const id = this.idValue;
    if (id === null || this.statusValue !== 'running') return;
    const generation = ++this.generation;
    const result: JsonResult<unknown> = await deps.api.requestJson<unknown>(runPath(this.config.path, id, true), { method: 'POST', scope: deps.scope() });
    if (generation !== this.generation || id !== this.idValue) return;
    this.read(deps, result, generation);
  }

  /** Stop polling: a scheduled tick and an answer on its way are dropped. The run itself is left. */
  stop(): void {
    this.generation += 1;
  }

  /** Show the run `id` as running, and poll it when `follow`. */
  private attach(deps: BackgroundDeps, id: string, follow: boolean): void {
    this.idValue = id;
    this.statusValue = 'running';
    this.answerValue = null;
    this.refusalValue = '';
    this.onChange();
    if (follow) void this.poll(deps);
  }

  /** Read one poll or cancel answer, and schedule the next poll while the run runs. */
  private read(deps: BackgroundDeps, result: JsonResult<unknown>, generation: number): void {
    if (result.kind === 'installing' || (result.kind === 'error' && (result.status === 0 || result.status >= 500))) {
      this.schedule(deps, generation);
      return;
    }
    if (result.kind === 'error' && result.status === 404) {
      this.idValue = null;
      this.statusValue = null;
      this.answerValue = null;
      this.refusalValue = '';
      this.onChange();
      return;
    }
    const view = result.kind === 'ok' ? backgroundViewOf(result.body, this.config.answerOf, this.config.refusalText) : null;
    if (view === null) {
      this.statusValue = 'failed';
      this.answerValue = null;
      this.refusalValue =
        (result.kind === 'error' ? this.config.refusalText(result.code, result.reason, result.detail) : '') || STRINGS.connectivityRequestRefused;
      this.onChange();
      return;
    }
    this.statusValue = view.status;
    this.answerValue = view.answer;
    this.refusalValue = view.refusal;
    this.onChange();
    if (view.status === 'running') this.schedule(deps, generation);
  }

  /** Send the next poll after `BACKGROUND_POLL_MS`, unless polling moved on meanwhile. */
  private schedule(deps: BackgroundDeps, generation: number): void {
    const schedule = deps.schedule ?? schedulePoll;
    schedule(() => {
      if (generation !== this.generation) return;
      void this.poll(deps);
    }, BACKGROUND_POLL_MS);
  }
}
