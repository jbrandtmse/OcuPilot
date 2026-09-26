/**
 * The one source of what the context chip shows and what a turn's screen context is judged
 * against: the caller's own sharing choice, the instance default, the resolved row cap, and
 * where a turn's provider call goes (Story 4.11, AD-42).
 *
 * Mirrors `agent-status.ts`'s shape -- the ungated-caller-own read, the answered/unanswered
 * gate, the generation/request/newest stale-answer guard, and the re-read on both agent change
 * types -- over
 * `GET/PUT /api/ocupilot/agent/context` (Story 4.4) instead of the definitions list and the
 * restraint verdict. `leavesInstance`, `provider` and `endpointHost` come only from this read;
 * nothing downstream re-derives them (AD-42's "the chip cannot disagree with where the request
 * actually goes").
 *
 * Framework-free, like the rest of `core/` (AD-19), so `ui/tools/agent-context.test.mjs`
 * executes it under `node --test`.
 */

import { AGENT_DEFINITION_ENTITY, AGENT_SWITCH_ENTITY } from './agent-status.ts';
import type { ApiService } from './api';
import type { ChangeBus, ChangeEvent } from './change-bus';
import type { ConnectivityService } from './connectivity';

/** Absolute from the origin root, through the one API service (AD-20). */
export const AGENT_CONTEXT_PATH = '/api/ocupilot/agent/context';

/** The seven facts `GET/PUT /agent/context` answers (`Api/Context.cls Body`). */
export interface AgentContextInfo {
  /** The caller's effective choice: their own stored choice, or `shareDefault` when they have none. */
  readonly share: boolean;
  /** The instance-wide default (`Switches.shareContextByDefault`). */
  readonly shareDefault: boolean;
  /** The caller's own stored choice, or `null` when they have never set one. */
  readonly userChoice: boolean | null;
  /** The resolved row cap (`Switches.contextRowCap`), 1 to 1,000 (AD-24). */
  readonly contextRowCap: number;
  /** The default definition's provider family, or `''` with no enabled default. */
  readonly provider: string;
  /** The default definition's resolved endpoint host, or `''` with no enabled default. */
  readonly endpointHost: string;
  /** Whether that endpoint leaves the instance, or `null` with no enabled default. */
  readonly leavesInstance: boolean | null;
}

/** The answer before one has landed, and what a malformed body falls back to. */
export const NO_CONTEXT_INFO: AgentContextInfo = {
  share: false,
  shareDefault: false,
  userChoice: null,
  contextRowCap: 200,
  provider: '',
  endpointHost: '',
  leavesInstance: null,
};

function boolAt(source: Record<string, unknown>, key: string): boolean {
  return source[key] === true;
}

function boolOrNullAt(source: Record<string, unknown>, key: string): boolean | null {
  const value = source[key];
  return typeof value === 'boolean' ? value : null;
}

function textAt(source: Record<string, unknown>, key: string): string {
  const value = source[key];
  return typeof value === 'string' ? value : '';
}

function numberAt(source: Record<string, unknown>, key: string, fallback: number): number {
  const value = source[key];
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback;
}

/** `body` narrowed key by key, or `null` when it is not the shape `Api.Context` answers. */
function infoOf(body: unknown): AgentContextInfo | null {
  if (body === null || typeof body !== 'object') return null;
  const row = body as Record<string, unknown>;
  return {
    share: boolAt(row, 'share'),
    shareDefault: boolAt(row, 'shareDefault'),
    userChoice: boolOrNullAt(row, 'userChoice'),
    contextRowCap: numberAt(row, 'contextRowCap', NO_CONTEXT_INFO.contextRowCap),
    provider: textAt(row, 'provider'),
    endpointHost: textAt(row, 'endpointHost'),
    leavesInstance: boolOrNullAt(row, 'leavesInstance'),
  };
}

/** Whether two answers say the same thing, so a re-read that confirms one re-renders nothing. */
function sameInfo(a: AgentContextInfo, b: AgentContextInfo): boolean {
  return (
    a.share === b.share &&
    a.shareDefault === b.shareDefault &&
    a.userChoice === b.userChoice &&
    a.contextRowCap === b.contextRowCap &&
    a.provider === b.provider &&
    a.endpointHost === b.endpointHost &&
    a.leavesInstance === b.leavesInstance
  );
}

export interface AgentContextOptions {
  readonly api: ApiService;
  /** The one client bus (AD-14): re-reads on `agent-switch` and on `agent-definition`. */
  readonly bus?: ChangeBus;
  /** Where a failed read is parked (DW-135's shape). Optional so a narrow test can leave it out. */
  readonly connectivity?: ConnectivityService;
}

export class AgentContext {
  private readonly api: ApiService;
  private readonly connectivity: ConnectivityService | null;

  private info: AgentContextInfo = NO_CONTEXT_INFO;
  private answeredValue = false;

  /** Bumped by `reset()`, read across every await -- the same shape `AgentStatus` uses (AD-8). */
  private generation = 0;

  /** Bumped by every `load()` and `setShare()`, read across the await, so only the newest settles. */
  private request = 0;

  /**
   * The newest request in flight -- read or write -- so a superseded read resolves on it rather
   * than on itself. Every bump of `request` must move this too: a bump that did not would leave
   * the read it superseded awaiting its own promise, which never settles.
   */
  private newest: Promise<void> = Promise.resolve();

  private readonly listeners = new Set<() => void>();

  constructor(options: AgentContextOptions) {
    this.api = options.api;
    this.connectivity = options.connectivity ?? null;
    // Never unsubscribed: this service lives as long as the tab does (see `AgentStatus`).
    options.bus?.subscribe((event) => this.onChange(event));
  }

  /** Whether a read (or a successful write) has ever landed. Nothing renders an audience before it has. */
  answered(): boolean {
    return this.answeredValue;
  }

  share(): boolean {
    return this.info.share;
  }

  shareDefault(): boolean {
    return this.info.shareDefault;
  }

  userChoice(): boolean | null {
    return this.info.userChoice;
  }

  contextRowCap(): number {
    return this.info.contextRowCap;
  }

  provider(): string {
    return this.info.provider;
  }

  endpointHost(): string {
    return this.info.endpointHost;
  }

  leavesInstance(): boolean | null {
    return this.info.leavesInstance;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /**
   * Read `GET /agent/context` and settle the answer.
   *
   * A refusal or an unreachable instance leaves the previous answer standing and parks the next
   * attempt on `connectivity` -- the same "never guess" discipline `AgentStatus.load()` follows.
   * Resolves once the **newest** read is in, not necessarily this one (see `AgentStatus`).
   */
  load(): Promise<void> {
    const run = this.read();
    this.newest = run;
    return run;
  }

  private async read(): Promise<void> {
    const generation = this.generation;
    const request = (this.request += 1);
    const result = await this.api.requestJson<unknown>(AGENT_CONTEXT_PATH);
    if (generation !== this.generation) return;
    if (request !== this.request) {
      await this.newest;
      return;
    }
    if (result.kind !== 'ok') {
      this.connectivity?.retryWhenReachable(AGENT_CONTEXT_PATH, () => void this.load());
      return;
    }
    const next = infoOf(result.body);
    if (next === null) return;
    const moved = !this.answeredValue || !sameInfo(this.info, next);
    this.info = next;
    this.answeredValue = true;
    if (moved) this.notify();
  }

  /**
   * Mirror `share` at once, then `PUT /agent/context {share}` and adopt the 200 body (Boundaries
   * & Constraints, AD-20, AD-28). A refusal reverts the mirror and adds no new error surface --
   * the caller (`context-chip.ts`) reports nothing further. Answers whether the write landed.
   */
  setShare(share: boolean): Promise<boolean> {
    const run = this.write(share);
    // This write bumps `request`, so it is now the newest request and `read()`'s superseded
    // branch must await it. A rejection is not that barrier's business -- the caller's own `run`
    // answers for it -- so it is absorbed here rather than thrown into an unrelated read.
    this.newest = run.then(
      () => undefined,
      () => undefined
    );
    return run;
  }

  private async write(share: boolean): Promise<boolean> {
    const generation = this.generation;
    const previous = this.info;
    this.info = { ...this.info, share };
    this.notify();
    const request = (this.request += 1);
    const result = await this.api.requestJson<unknown>(AGENT_CONTEXT_PATH, {
      method: 'PUT',
      body: JSON.stringify({ share }),
    });
    if (generation !== this.generation) {
      // Superseded by sign-out: the answer belongs to a principal who has already left.
      return false;
    }
    if (request !== this.request) {
      // A later `load()` or `setShare()` has already landed; leave its answer standing.
      return result.kind === 'ok';
    }
    if (result.kind !== 'ok') {
      this.info = previous;
      this.notify();
      return false;
    }
    const next = infoOf(result.body);
    if (next === null) {
      // A malformed 200 body: the server's actual answer was never adopted, so the optimistic
      // mirror must not stand as if it had been -- revert exactly like the refusal branch above.
      this.info = previous;
      this.notify();
      return false;
    }
    this.info = next;
    this.answeredValue = true;
    this.notify();
    return true;
  }

  /** Forget the answer, so the next `load()` asks again (sign-out; see `AgentStatus.reset()`). */
  reset(): void {
    this.generation += 1;
    this.request += 1;
    this.info = NO_CONTEXT_INFO;
    this.answeredValue = false;
    this.notify();
  }

  /**
   * A switch or a definition changed: re-read (AD-14), the same pair `AgentStatus.onChange`
   * listens to. Both move something in this answer. `agent-switch` carries the row cap and
   * `shareContextByDefault`; `agent-definition` carries Enable/Disable, the **default marker**
   * and a saved endpoint -- and `provider`, `endpointHost` and `leavesInstance` are all the
   * *default definition's*. AD-42 makes the chip's egress statement uncomputable from anything
   * else and says it "cannot disagree with where the request actually goes", so a moved default
   * this store did not re-read would leave the chip naming the previous host, or showing no
   * "leaves the instance" pill for an endpoint that now has one, until a reload.
   */
  private onChange(event: ChangeEvent): void {
    if (event.kind !== 'changed') return;
    if (event.type !== AGENT_SWITCH_ENTITY && event.type !== AGENT_DEFINITION_ENTITY) return;
    void this.load();
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
