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

import type { ApiService } from './api';

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
 * EXPERIENCE.md `:427`'s sentence with the version the instance reported in place of the
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

/** The four fields `GET /api/ocupilot/instance` answers with. */
export interface InstanceIdentity {
  adminApiVersion?: unknown;
  instanceName?: unknown;
  instanceVersion?: unknown;
  buildIdentity?: unknown;
}

export interface InstanceOptions {
  readonly api: ApiService;
}

function asString(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

function asNumber(value: unknown): number {
  return typeof value === 'number' ? value : 0;
}

export class InstanceService {
  private readonly api: ApiService;

  private currentStatus: InstanceStatus = 'checking';
  private currentVersion = 0;
  private currentName = '';
  private currentInstanceVersion = '';
  private currentBuildIdentity = '';

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
    this.set('checking');
  }

  verify(): Promise<InstanceStatus> {
    const inFlight = this.verifyInFlight;
    if (inFlight !== null) return inFlight;
    if (this.settled) return Promise.resolve(this.currentStatus);
    const started = this.runVerify().finally(() => {
      this.verifyInFlight = null;
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
    this.set('checking');
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
