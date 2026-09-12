/**
 * The one client-side failure taxonomy (AD-8, AD-12, AD-38, AD-39).
 *
 * The envelope is uniform on the wire, which is what lets the shell tell its failures apart
 * here instead of at sixty call sites: a transport fault, an install in flight, a 401, a 403,
 * a 404 and a 5xx reach the shell as the same `JsonResult` shape and mean six different
 * things to a user. `classifyFault` is the one place that decides which.
 *
 * **It is presentation, never a gate.** The server recomputes every verdict from live state
 * on every call (AD-8); a fault is what the shell says about the last answer it got, and no
 * shell verdict widens or narrows what a request may do.
 *
 * **Total by construction.** Every `JsonResult` arm and every HTTP status maps to exactly one
 * kind -- the last branch takes everything the earlier ones did not -- so no outcome is
 * unclassified and no caller has to handle `undefined`.
 *
 * Framework-free, so `ui/tools/fault.test.mjs` executes it under `node --test`.
 */

import type { JsonResult } from './api';

/**
 * What went wrong, at the coarseness the shell has distinct behaviour for.
 *
 * - `unreachable` -- nothing answered. The only kind a **transport** fault produces, and the
 *   only one the probe re-arms on: any HTTP response at all, 401 and 403 and 503 included,
 *   proves the instance is reachable.
 * - `not-installed` -- an `INSTALL.*` 503 (AD-38). Not a server fault: the instance is coming
 *   up, `Session` has already been told to back off, and the caller's state should stay put.
 * - `rejected` -- the instance refused the request itself and no retry would help: a 401 after
 *   the one refresh-and-retry, and every other 4xx that is neither 403 nor 404 (a malformed
 *   request, an unknown namespace, a failed precondition). It drives no surface of its own --
 *   the sign-in presentation is `Session`'s, from the session state, not from this.
 * - `refused` -- a 403. Reported, **never retried** (AD-8); the data already on screen stays.
 * - `absent` -- a 404 on a read. The reference no longer resolves (AD-37). Classified and
 *   carried here; Epic 1 builds no detail route to render it on.
 * - `server-fault` -- a 5xx that is not `INSTALL.*`, and anything else that is not a 4xx. The
 *   browser is told a generic reason; the detail is on the instance, in `messages.log`.
 */
export type FaultKind =
  | 'unreachable'
  | 'not-installed'
  | 'rejected'
  | 'refused'
  | 'absent'
  | 'server-fault';

export interface Fault {
  readonly kind: FaultKind;
  /** The HTTP status that produced it; `0` for a transport fault, which has none. */
  readonly status: number;
  /** The envelope's machine code (AD-39), or `null` when there was no envelope to read. */
  readonly code: string | null;
  /**
   * The request path this is about. Carried for `absent` in particular (DW-11): "the thing you
   * asked for is not there" is only actionable if the shell can say which thing.
   */
  readonly path: string;
}

/**
 * The fault one outcome means, or `null` when the call succeeded.
 *
 * The branches are ordered by how much they know, not by status number: the two non-`error`
 * arms first, then the statuses the shell has a distinct surface for, then the 4xx band, then
 * everything else.
 */
export function classifyFault(result: JsonResult<unknown>, path: string): Fault | null {
  if (result.kind === 'ok') return null;
  if (result.kind === 'installing') {
    return { kind: 'not-installed', status: result.status, code: result.code, path };
  }
  const at = (kind: FaultKind): Fault => ({ kind, status: result.status, code: result.code, path });
  // Status 0 is the browser's own spelling for "the request never got an answer" -- there is no
  // response, so there is nothing else this can be.
  if (result.status === 0) return at('unreachable');
  if (result.status === 403) return at('refused');
  if (result.status === 404) return at('absent');
  if (result.status >= 400 && result.status < 500) return at('rejected');
  return at('server-fault');
}

/**
 * The fault a transport failure outside `ApiService` produces -- `Session`'s three token
 * endpoints, which post with `fetch` directly rather than through `requestJson` and so never
 * reach `classifyFault`.
 *
 * It is spelled here rather than in `session.ts` so there is one construction of an
 * `unreachable` fault in the client, and so `session.ts` needs no import from this module.
 */
export function transportFault(path: string): Fault {
  return { kind: 'unreachable', status: 0, code: null, path };
}

/**
 * Whether a fault is one the connectivity banner has published copy for. The other four kinds
 * are classified, published and read by other surfaces -- the sign-in card, the inline refusal,
 * the status bar -- and EXPERIENCE.md publishes no banner sentence for any of them (DW-126).
 */
export function isBannerFault(fault: Fault | null): boolean {
  return fault !== null && (fault.kind === 'unreachable' || fault.kind === 'server-fault');
}
