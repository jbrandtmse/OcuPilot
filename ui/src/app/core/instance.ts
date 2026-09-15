/**
 * The instance the shell is talking to, and whether it is one OcuPilot can drive (AD-27,
 * NFR-8). One call, `GET /api/ocupilot/instance`, and three outcomes the shell gates on.
 *
 * Framework-free, like the rest of `core/`, so `ui/tools/session.test.mjs` can execute it
 * under `node --test`; the Angular layer mirrors what it hears into a signal, exactly as it
 * does for `Session`.
 *
 * Three settled states and one unsettled one:
 *
 * - `ready` -- the admin API is the v2 OcuPilot is built against, so the routed screen may
 *   render.
 * - `version-mismatch` -- it answered with some other number (0 when it is absent or its
 *   named probe endpoint no longer answers). The number is kept, because the notice names
 *   it, and a mismatch is never presented as a privilege problem.
 * - `no-privileges` -- the router refused the call with `AUTH.NOADMIN`, so this user holds
 *   none of its administrative resources. Read from the envelope's machine `code`, never
 *   from the human `reason` (AD-39), and never presented as a version mismatch.
 * - `checking` -- nothing conclusive yet: the instance is still installing, or the call
 *   failed some other way. The shell shows the notice for neither, and a later `verify()`
 *   can still settle it.
 */

// Type-only, and it must stay type-only: `connectivity.ts` imports `INSTANCE_PATH` from this
// module at runtime, so a value import back would be a cycle. A type import is erased.
import type { ApiService } from './api';
import type { ConnectivityService } from './connectivity';

/** Absolute from the origin root, through the one API service (AD-20). */
export const INSTANCE_PATH = '/api/ocupilot/instance';

/** The admin API version this build is written against (NFR-8). */
export const REQUIRED_ADMIN_API_VERSION = 2;

/** The machine code the router's administrative gate refuses with. */
export const NO_ADMIN_CODE = 'AUTH.NOADMIN';

export type InstanceStatus = 'checking' | 'ready' | 'version-mismatch' | 'no-privileges';

/**
 * Whether the routed screen may render (AD-27). Exported as a predicate, not spelled as a
 * comparison in the shell, so the gate is one executed assertion over every
 * `InstanceStatus` rather than a string the next reader can widen unnoticed -- the shape
 * `isSignedIn` already uses for the session gate. Stories 1.9 and 1.10 read this.
 */
export function isInstanceReady(status: InstanceStatus): boolean {
  return status === 'ready';
}

/**
 * EXPERIENCE.md "Version mismatch"'s sentence with the version the instance reported in place of the
 * Fixed strings table's `<n>`. A function rather than a `replace` inside the component,
 * because the component has no executed test host until Story 1.9 (DW-93) and this is the
 * one sentence a user reads: as a source-text pin, renaming the placeholder on one side
 * only would ship the notice with `<n>` still in it.
 */
export function formatVersionMismatch(template: string, version: number): string {
  return template.split(VERSION_PLACEHOLDER).join(String(version));
}

/** The placeholder the Fixed strings table leaves for a value the component supplies. */
export const VERSION_PLACEHOLDER = '<n>';

/** The seven fields `GET /api/ocupilot/instance` answers with. */
export interface InstanceIdentity {
  adminApiVersion?: unknown;
  instanceName?: unknown;
  instanceVersion?: unknown;
  buildIdentity?: unknown;
  serverFlag?: unknown;
  licensedTo?: unknown;
  serverName?: unknown;
}

/** What the status bar draws for a reported system mode. */
export type ServerFlagKind = 'none' | 'live' | 'test' | 'failover' | 'development' | 'unknown';

/** The four modes IRIS's own setter accepts (`irissys/%SYSTEM/Version.cls`). */
const KNOWN_SERVER_FLAGS: readonly ServerFlagKind[] = ['live', 'test', 'failover', 'development'];

/**
 * Which badge a reported system mode gets (DW-10).
 *
 * Three answers, and the first is the common one: an instance with no mode set reports `''`
 * and gets **no badge at all**. Dressing absence as `Live` is the failure the ledger entry is
 * about, and it is the state this container is in.
 *
 * Stored modes are upper case -- the vendor's setter upper-cases its argument -- so the
 * comparison case-folds rather than string-matching what happens to be stored today. A value
 * outside the four can only reach the global by a direct write; it is `unknown`, and the badge
 * draws it verbatim in the restrained pair rather than guessing which of the four it meant.
 */
export function serverFlagKind(value: string): ServerFlagKind {
  const folded = value.trim().toLowerCase();
  if (folded === '') return 'none';
  const known = KNOWN_SERVER_FLAGS.find((flag) => flag === folded);
  return known ?? 'unknown';
}

export interface InstanceOptions {
  readonly api: ApiService;
  /**
   * Where an inconclusive answer is parked (DW-119). Optional so a test that is not about the
   * re-ask can leave it out; production always supplies it, because without it the `checking`
   * state has nothing scheduled to leave it.
   */
  readonly connectivity?: ConnectivityService;
}

function asString(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

function asNumber(value: unknown): number {
  return typeof value === 'number' ? value : 0;
}

export class InstanceService {
  private readonly api: ApiService;
  private readonly connectivity: ConnectivityService | null;

  private currentStatus: InstanceStatus = 'checking';
  private currentVersion = 0;
  private currentName = '';
  private currentInstanceVersion = '';
  private currentBuildIdentity = '';
  private currentServerFlag = '';
  private currentLicensedTo = '';
  private currentServerName = '';

  private readonly listeners = new Set<() => void>();

  /**
   * One call however many callers, for the reason `Session.refresh()` is single-flight: the
   * shell can reach `verify()` from more than one change-detection pass, and the acceptance
   * criterion is that exactly one request goes out.
   */
  private verifyInFlight: Promise<InstanceStatus> | null = null;

  /** Whether a conclusive answer has been had. An inconclusive one is retried. */
  private settled = false;

  /**
   * Bumped by `reset()`. A verify captures the value it started under and settles nothing
   * if it no longer matches, so a call already on the wire when the user signed out cannot
   * land the previous principal's verdict on the next one -- the shape `Session` uses for
   * its own scheduled work.
   */
  private generation = 0;

  constructor(options: InstanceOptions) {
    this.api = options.api;
    this.connectivity = options.connectivity ?? null;
  }

  status(): InstanceStatus {
    return this.currentStatus;
  }

  /** The version the instance reported; 0 when the admin API is absent or failed its probe. */
  adminApiVersion(): number {
    return this.currentVersion;
  }

  instanceName(): string {
    return this.currentName;
  }

  instanceVersion(): string {
    return this.currentInstanceVersion;
  }

  /** The version row's build stamp, for whatever compares bundles against it later. */
  buildIdentity(): string {
    return this.currentBuildIdentity;
  }

  /**
   * The instance's system mode, verbatim and unfolded, or `''` when none is set. The badge
   * decides what to draw through `serverFlagKind`; this returns what the instance said, so an
   * unrecognised mode can still be shown as it was reported.
   */
  serverFlag(): string {
    return this.currentServerFlag;
  }

  /** The customer name on the active licence key, or `''`. */
  licensedTo(): string {
    return this.currentLicensedTo;
  }

  /** The host node this instance runs on, or `''`. */
  serverName(): string {
    return this.currentServerName;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /**
   * Forget everything learned about the instance, so the next `verify()` asks again.
   *
   * The verdict is about **this user on this instance**, not about the tab: the
   * administrative gate resolves privilege per caller (AD-8), and `signOut()` clears the
   * tab in place without a reload, so a second principal signing in to the same tab would
   * otherwise inherit the first one's answer -- an administrator held behind the
   * no-privileges notice whose only control is Sign out, or worse, a user with no
   * administrative resource handed the routed screen.
   */
  reset(): void {
    this.generation += 1;
    this.settled = false;
    this.verifyInFlight = null;
    this.currentVersion = 0;
    this.currentName = '';
    this.currentInstanceVersion = '';
    this.currentBuildIdentity = '';
    this.currentServerFlag = '';
    this.currentLicensedTo = '';
    this.currentServerName = '';
    this.set('checking');
  }

  verify(): Promise<InstanceStatus> {
    const inFlight = this.verifyInFlight;
    if (inFlight !== null) return inFlight;
    if (this.settled) return Promise.resolve(this.currentStatus);
    // Clear only the slot this call owns. `reset()` nulls `verifyInFlight` while a call may
    // still be on the wire, so an unconditional `finally` would clear the slot belonging to
    // the verify started after that reset, and the next `verify()` would issue a second
    // concurrent identity call for the same principal.
    const started: Promise<InstanceStatus> = this.runVerify().finally(() => {
      if (this.verifyInFlight === started) this.verifyInFlight = null;
    });
    this.verifyInFlight = started;
    return started;
  }

  private async runVerify(): Promise<InstanceStatus> {
    const generation = this.generation;
    const result = await this.api.requestJson<InstanceIdentity>(INSTANCE_PATH);
    // A reset happened while this was on the wire: the answer is about a principal who is
    // no longer here, so none of it is kept.
    if (generation !== this.generation) return this.currentStatus;

    if (result.kind === 'ok') {
      const body = result.body ?? {};
      this.currentVersion = asNumber(body.adminApiVersion);
      this.currentName = asString(body.instanceName);
      this.currentInstanceVersion = asString(body.instanceVersion);
      this.currentBuildIdentity = asString(body.buildIdentity);
      this.currentServerFlag = asString(body.serverFlag);
      this.currentLicensedTo = asString(body.licensedTo);
      this.currentServerName = asString(body.serverName);
      this.settle(
        this.currentVersion === REQUIRED_ADMIN_API_VERSION ? 'ready' : 'version-mismatch'
      );
      return this.currentStatus;
    }

    if (result.kind === 'error' && result.code === NO_ADMIN_CODE) {
      this.settle('no-privileges');
      return this.currentStatus;
    }

    // Install in flight, or a failure this shell cannot explain. `Session` has already been
    // told about the first; neither is an answer about the instance, so nothing is settled
    // and the shell keeps waiting rather than accusing the user or the vendor.
    //
    // **DW-119: waiting is not the same as being scheduled to ask again.** Before this the
    // branch set `checking` and arranged nothing, so a tab could sit on the blocking notice
    // indefinitely with no request outstanding and no timer armed. The re-ask is parked with
    // connectivity, which owns the probe: when the instance next answers anything at all, this
    // runs once. `verify()` is single-flight and this branch settles nothing, so the re-ask is
    // idempotent -- reaching it from several failures still produces one request.
    this.set('checking');
    this.connectivity?.retryWhenReachable(INSTANCE_PATH, () => {
      void this.verify();
    });
    return this.currentStatus;
  }

  private settle(next: InstanceStatus): void {
    this.settled = true;
    this.set(next);
  }

  private set(next: InstanceStatus): void {
    if (this.currentStatus === next) return;
    this.currentStatus = next;
    for (const listener of this.listeners) listener();
  }
}
