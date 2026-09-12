/**
 * The one subscribable failure verdict, and the probe that clears it.
 *
 * Every call in the client passes through `ApiService.requestJson`, which classifies its
 * outcome (`core/fault.ts`) and reports it here. This service holds the current verdict, owns
 * the re-probe and its backoff, and owns the one re-read each failed reader is owed when the
 * instance answers again. The banner and the status bar read it; nothing else decides for
 * itself what "unreachable" means.
 *
 * **The probe adds no server route.** It re-issues `GET /api/ocupilot/instance`, because every
 * reachable state of the API already answers: the install gate refuses 503 before
 * authentication, an anonymous caller gets 401, a non-admin 403. **A response of any kind is
 * the reachability signal**, and only a transport fault is not. A second probe route now would
 * be the thing 1.17 removes when AD-45's readiness application lands.
 *
 * **One re-read per reader per clearing, not one per tick.** `InstanceService`,
 * `NavigationService` and `ScopeService` each register a re-run keyed by the path they failed
 * on, so a reader that failed four times still re-runs once; the whole set drains when the
 * probe gets a response, and the keys are dropped as they run.
 *
 * Framework-free, like the rest of `core/`, so `ui/tools/fault.test.mjs` executes it under
 * `node --test`; the backoff runs on an injected `schedule` seam mirroring `session.ts`'s.
 */

import type { ApiService } from './api';
import type { Fault } from './fault';
import { INSTANCE_PATH } from './instance.ts';

/**
 * The path the probe re-issues. The identity read, deliberately: it is the one route the shell
 * already depends on, it answers in every reachable state, and re-using it means a recovered
 * instance settles the identity check in the same round trip that clears the banner.
 *
 * `instance.ts` is imported for the value rather than the string being spelled twice. The
 * dependency runs one way only -- `instance.ts` names this service through a **type-only**
 * import, which is erased -- so there is no runtime cycle.
 */
export const PROBE_PATH = INSTANCE_PATH;

/** Backoff between re-probes while the instance is unreachable, matching `session.ts`'s. */
export const PROBE_BACKOFF_BASE_MS = 500;
export const PROBE_BACKOFF_MAX_MS = 8000;

export interface ConnectivityOptions {
  /**
   * The API service, asked for rather than held, because the two need each other: this service
   * probes through `ApiService`, and `ApiService` reports every outcome to this service. The
   * arrow is never called during construction -- only when a probe is actually issued -- which
   * is what lets `src/main.ts` build them in either order (the shape `ApiOptions.scope` uses).
   */
  readonly api: () => ApiService;
  /** Defaults to `setTimeout`. Injected so a test drives the backoff by hand. */
  readonly schedule?: (run: () => void, delayMs: number) => void;
}

export class ConnectivityService {
  private readonly resolveApi: () => ApiService;
  private readonly schedule: (run: () => void, delayMs: number) => void;

  private currentFault: Fault | null = null;

  /**
   * Whether the instance has been unreachable since the last call that actually succeeded.
   *
   * It outlives the fault on purpose. An instance that comes back answering 401 has cleared
   * `unreachable` -- a response arrived -- while the tab is still re-establishing its session,
   * and "Signing in again…" is the published word for exactly that gap (EXPERIENCE.md's
   * status-bar connection row). A successful call is what ends it.
   */
  private recovering = false;

  /** Whether a backoff probe is already scheduled -- one chain however many callers (DW-102). */
  private probeArmed = false;

  private probeAttempts = 0;

  /** One entry per reader, keyed by the path it failed on, so repeats collapse. */
  private readonly pending = new Map<string, () => void>();

  private readonly listeners = new Set<() => void>();

  constructor(options: ConnectivityOptions) {
    this.resolveApi = options.api;
    this.schedule =
      options.schedule ??
      ((run, delayMs) => {
        setTimeout(run, delayMs);
      });
  }

  /** The verdict on the last answer the client got, or `null` when it succeeded. */
  fault(): Fault | null {
    return this.currentFault;
  }

  /** Whether the instance has answered since going unreachable but nothing has succeeded yet. */
  isRecovering(): boolean {
    return this.recovering;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /**
   * Report what one call came back as. `null` is a success.
   *
   * The last answer wins, and that is the design: a banner is "not dismissible while the
   * condition persists, gone the moment it clears", so a call that succeeds while an
   * unreachable fault is live has just disproved it. Only a transport fault arms the probe --
   * every other kind already had a response.
   */
  note(fault: Fault | null): void {
    // Both halves of the published state are compared before either is written, so one call
    // notifies at most once and a repeat of the verdict already held notifies nobody -- which
    // is what keeps a failing poll from waking every subscriber on every tick.
    const wasRecovering = this.recovering;
    const nextRecovering = fault === null ? false : fault.kind === 'unreachable' || wasRecovering;
    const changed = nextRecovering !== wasRecovering || this.differs(fault);

    this.recovering = nextRecovering;
    this.currentFault = fault;
    if (changed) this.notify();

    // **Any answer is the drain trigger, not only the probe's own.** The AC is that a reader
    // whose read failed re-runs when the instance answers again, and a call that succeeded has
    // answered -- so draining only from `runProbe` stranded every re-ask parked by a kind that
    // arms no probe. A 500 parks `verify()`, an unrelated call then succeeds and clears the
    // fault, and the tab sat on `checking` with no banner, no timer and no request outstanding:
    // DW-119's own condition, reintroduced one layer up. A success also ends the backoff, so
    // the next outage starts at the base delay rather than at the cap it left off on.
    if (fault === null) {
      this.drain();
      return;
    }
    if (fault.kind === 'unreachable') this.armProbe();
  }

  /**
   * Forget this principal's parked re-reads.
   *
   * The shape `InstanceService`, `NavigationService` and `ScopeService` already have, called
   * from the same place in `app.ts` and for the same reason (AD-8): a parked re-read is a
   * request about **this user**, and sign-out clears the tab in place without a reload, so one
   * left armed fires the previous principal's map, namespace and identity reads at whoever
   * signs in next.
   *
   * **The verdict itself is deliberately kept**, which is where this differs from its three
   * siblings. Their state is an answer about a principal; a fault is an observation about the
   * instance, and an unreachable instance is unreachable for everybody. Clearing it here would
   * take the banner off the sign-in card in exactly the state DW-104 put it there for -- this
   * runs on every pass through a not-signed-in state, not only on a sign-out.
   */
  reset(): void {
    this.pending.clear();
  }

  /** Whether `next` is a different verdict from the one held -- kind and subject, not identity. */
  private differs(next: Fault | null): boolean {
    const current = this.currentFault;
    if (current === null || next === null) return current !== next;
    return current.kind !== next.kind || current.path !== next.path;
  }

  /**
   * Register the one re-read `run` owes its caller when the instance answers again, keyed by
   * the path that failed.
   *
   * Keyed, not queued: a reader that meets four faults before the instance comes back still
   * re-reads once. The whole set drains on the first answer of any kind -- the probe's next
   * response, `retry()`, or an ordinary call that simply succeeded -- and each entry is removed
   * as it runs, so nothing re-runs twice for one clearing.
   */
  retryWhenReachable(key: string, run: () => void): void {
    this.pending.set(key, run);
  }

  /**
   * The banner's Retry. It probes immediately rather than waiting out the backoff, and a
   * response drains the pending re-reads exactly as the scheduled probe does -- which is what
   * makes Retry and "the probe succeeded" the same recovery rather than two.
   */
  retry(): void {
    void this.runProbe();
  }

  private armProbe(): void {
    // One chain, however many callers (DW-102's rule at the other end of the client): a second
    // arming would count a second attempt, so the two chains would probe at different delays.
    if (this.probeArmed) return;
    this.probeArmed = true;
    this.probeAttempts += 1;
    const delay = Math.min(
      PROBE_BACKOFF_BASE_MS * Math.pow(2, this.probeAttempts - 1),
      PROBE_BACKOFF_MAX_MS
    );
    this.schedule(() => {
      this.probeArmed = false;
      void this.runProbe();
    }, delay);
  }

  private async runProbe(): Promise<void> {
    // `requestJson` reports its own outcome through `onFault`, which is this service's `note()`
    // -- so the verdict is already updated by the time this resumes, and a probe that met
    // another transport fault has already re-armed the chain. What is left to this method is
    // the half `note()` cannot know: whether THIS request is the one that got an answer.
    const result = await this.resolveApi().requestJson<unknown>(PROBE_PATH);
    if (result.kind === 'error' && result.status === 0) return;
    // A response of any kind proves reachability, so the backoff starts over from the base
    // delay next time rather than resuming at the cap this outage climbed to.
    this.probeAttempts = 0;
    this.drain();
  }

  /**
   * Hand every waiting reader its one re-read. Cleared first, so a re-run cannot re-enter it.
   *
   * Silent when nothing was waiting: a drain that notified regardless woke every subscriber on
   * every probe tick and every successful call, which is the churn `note()`'s own change
   * comparison exists to prevent. A verdict that actually moved has already notified there.
   */
  private drain(): void {
    if (this.pending.size === 0) return;
    const runs = [...this.pending.values()];
    this.pending.clear();
    for (const run of runs) run();
    this.notify();
  }

  private notify(): void {
    for (const listener of this.listeners) listener();
  }
}
