/**
 * The one API service (AD-20, AD-28). Every read and write in the product goes through
 * `request()`, which is what makes three invariants checkable in one place instead of
 * being a convention sixty screens have to keep.
 *
 * 1. **A relative path is refused before any network call.** The shell is served under
 *    `/ocupilot` with a deep-link fallback, so `fetch('api/ocupilot/x')` would resolve
 *    against `<base href>` and be answered with `index.html` -- a 200 carrying HTML that
 *    a JSON parse turns into a confusing error a long way from the mistake. Throwing is
 *    the point: a relative path is a programming error, never a request.
 * 2. **`Authorization: Bearer <access>` is the only credential on the wire.** No cookie
 *    (`credentials: 'omit'`), no query parameter, nothing written to a frame. The
 *    browser-level cookie authorizes nothing here; it exists only so the token endpoints
 *    can mint silently, and only `Session` sends it.
 * 3. **Refresh is single-flight and lives here, not in a screen.** A 401 awaits
 *    `Session.refresh()` -- one request however many callers are waiting -- and retries
 *    exactly once. A second 401 after the retry is returned as it is: refreshing again
 *    would be a loop, and on this instance replaying a rotated refresh token revokes the
 *    session outright.
 *
 * Framework-free so `ui/tools/api.test.mjs` can execute it under `node --test`.
 */

import type { FetchLike, HttpRequestInit, HttpResponseLike, Session } from './session';
import type { TokenStore } from './token-store';

export interface ApiOptions {
  readonly fetch: FetchLike;
  readonly tokens: TokenStore;
  readonly session: Session;
  /**
   * Called once for every 403 a JSON call answers with -- the shape `noteInstallInFlight`
   * already has for an install-in-flight 503, and the channel `NavigationService` re-reads its
   * map on (AD-8: privilege is never cached, so a refusal is news). It is told, not asked: the
   * result is still returned to the caller as an error either way.
   */
  readonly onForbidden?: () => void;
}

export interface ApiRequestInit {
  method?: string;
  headers?: Record<string, string>;
  body?: string;
}

/**
 * What one JSON call came back as. Three outcomes, because the shell has three things to
 * do about them: render the body, wait for an install to finish, or report a failure by
 * its machine `code` -- never by the human `reason`, which is rewordable (AD-39).
 *
 * `installing` is separated from `error` because an `INSTALL.*` 503 is not a failure the
 * caller can act on: the instance is coming up, `Session` has been told to back off, and
 * the caller's own state should stay where it is.
 */
export type JsonResult<T> =
  | { readonly kind: 'ok'; readonly status: number; readonly body: T }
  | { readonly kind: 'installing'; readonly status: number; readonly code: string | null }
  | {
      readonly kind: 'error';
      readonly status: number;
      readonly code: string | null;
      readonly reason: string | null;
    };

/** A body that is not JSON is `null`, not a throw: the caller still has the status. */
function parseBody(text: string): unknown {
  try {
    return JSON.parse(text) as unknown;
  } catch {
    return null;
  }
}

/** One string field of OcuPilot's error envelope, or null when it is absent or not a string. */
function envelopeString(parsed: unknown, key: 'code' | 'reason'): string | null {
  if (typeof parsed !== 'object' || parsed === null) return null;
  const value = (parsed as Record<string, unknown>)[key];
  return typeof value === 'string' ? value : null;
}

/**
 * The only prefix this service will send a Bearer to.
 *
 * Spelled out rather than imported from `session.ts`'s `API_ROOT`, and held equal to it by an
 * assertion in `ui/tools/api.test.mjs`, which imports both by path. Story 1.9 removed the
 * reason this could not simply be imported -- `tsconfig.json` now allows the `.ts` extension
 * `node --test`'s resolver needs -- and left the duplication and its assertion in place rather
 * than reshaping a module this story does not otherwise touch.
 */
export const API_PATH_PREFIX = '/api/ocupilot/';

/** The one message a bad path reports. Named so the test can pin it. */
export const RELATIVE_PATH_MESSAGE =
  'OcuPilot API paths are absolute from the origin root and under ' +
  API_PATH_PREFIX +
  ' (AD-20, AD-47); received: ';

/**
 * A base the guard resolves against. Any absolute origin does: only the resolved
 * `pathname`, and the fact that resolution did not change the origin, are read from it.
 * A constant rather than `location.origin` because these modules are executed by
 * `node --test`, where there is no `location`.
 */
const GUARD_BASE = 'https://ocupilot.invalid';

/**
 * Whether `path` is one this service may attach a Bearer to: absolute from the origin
 * root and still under `/api/ocupilot` **after the URL parser has normalized it**.
 *
 * **Comparing the spelling is not enough; the request-target is what leaves the machine.**
 * `fetch` resolves the path before sending, and that resolution removes dot segments and
 * treats a backslash as a separator: `/api/ocupilot/../../csp/sys/UtilHome.csp`,
 * `/api/ocupilot/%2E%2E/%2E%2E/csp/sys` and `/api/ocupilot/..\..\csp/sys/x` all begin with
 * the API root as text and all arrive at `/csp/sys/...` on the wire. A prefix test alone
 * therefore admits the classic portal, and `/\evil.example/x` resolves off-origin outright.
 *
 * So the guard normalizes the same way the network stack will and re-tests the result:
 * the origin must be unchanged and the resolved `pathname` must still be under the API
 * root. That is closed by construction rather than a list of the escapes thought of so far
 * — a percent-encoded dot and a backslash are covered without being enumerated.
 *
 * It is also what enforces AC3's last clause: no request OcuPilot makes to `/csp/sys` or a
 * vendor editor can carry the token pair, because this service refuses to send one there.
 */
export function isOcuPilotApiPath(path: string): boolean {
  if (!path.startsWith(API_PATH_PREFIX)) return false;
  let resolved: URL;
  try {
    resolved = new URL(path, GUARD_BASE);
  } catch {
    return false;
  }
  if (resolved.origin !== GUARD_BASE) return false;
  return resolved.pathname.startsWith(API_PATH_PREFIX);
}

export class ApiService {
  private readonly http: FetchLike;
  private readonly tokens: TokenStore;
  private readonly session: Session;
  private readonly onForbidden: (() => void) | null;

  constructor(options: ApiOptions) {
    this.http = options.fetch;
    this.tokens = options.tokens;
    this.session = options.session;
    this.onForbidden = options.onForbidden ?? null;
  }

  /**
   * Issue one API request. `path` is absolute from the origin root, e.g.
   * `/api/ocupilot/info`.
   */
  async request(path: string, init: ApiRequestInit = {}): Promise<HttpResponseLike> {
    if (!isOcuPilotApiPath(path)) {
      throw new Error(RELATIVE_PATH_MESSAGE + JSON.stringify(path));
    }

    // A pair whose access token has already expired buys nothing but a round trip and a
    // 401, so renew first. The refresh is the same single-flight one the 401 path uses.
    //
    // `exp === 0` means the instance told us nothing about expiry, not that the token has
    // expired: pre-empting on it would refresh before EVERY call, and each refresh rotates
    // the pair. Unknown expiry therefore waits for a real 401.
    // A failed pre-emptive refresh has already cleared the pair and settled the session on
    // `session-ended` or `form`. The call still goes out -- the caller asked for it and is
    // owed a response -- but it must not fall into the 401 path below, which would call
    // `refresh()` a second time and start another probe chain behind a session that has
    // already ended.
    const held = this.tokens.read();
    if (held !== null && held.exp !== 0 && this.session.remainingMs() === 0) {
      const renewedEarly = await this.session.refresh();
      if (!renewedEarly) return this.http(path, this.buildInit(init));
    }

    const first = await this.http(path, this.buildInit(init));
    if (first.status !== 401) return first;

    const renewed = await this.session.refresh();
    if (!renewed) return first;

    return this.http(path, this.buildInit(init));
  }

  /**
   * Issue one API request and read OcuPilot's envelope off it (AD-12, AD-39).
   *
   * `request()` itself is untouched, so every pin over the raw response still holds; this
   * is the layer above it that every screen and tool will call. The body is buffered once,
   * because `HttpResponseLike.text()` is single-read -- a second `text()` on the same
   * response would reject, and the caller would see an empty body rather than a failure.
   */
  async requestJson<T>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> {
    // A bad path stays a throw. Invariant 1 above is that a relative or off-root path is a
    // programming error, never a request; catching `request()`'s throw below would turn it
    // into `status: 0`, which reads as a transport fault and hides the mistake from the
    // caller that made it. Asked here, before the try, so the two outcomes cannot merge.
    if (!isOcuPilotApiPath(path)) {
      throw new Error(RELATIVE_PATH_MESSAGE + JSON.stringify(path));
    }

    // A transport fault -- offline, DNS, a connection dropped mid-flight -- is an outcome
    // here, not an exception for the caller to catch. Callers reach this through `void`
    // (the identity check does), so a rejection would surface as an unhandled rejection
    // and no screen would ever hear about it. Status 0 is the browser's own spelling for
    // "the request never got an answer", and carries no envelope to read.
    let response: HttpResponseLike;
    try {
      response = await this.request(path, init);
    } catch {
      return { kind: 'error', status: 0, code: null, reason: null };
    }

    let text = '';
    try {
      text = await response.text();
    } catch {
      text = '';
    }
    const parsed = parseBody(text);

    if (response.status >= 200 && response.status < 300) {
      return { kind: 'ok', status: response.status, body: parsed as T };
    }

    const code = envelopeString(parsed, 'code');
    // The classification itself is `Session`'s -- `isInstallInFlight` lives there and this
    // module cannot import it at runtime (see `API_PATH_PREFIX`), so the question is asked
    // through the injected session rather than answered twice. Saying yes also arms the one
    // backoff chain, which is a no-op while one is already armed (DW-102).
    if (this.session.noteInstallInFlight(response.status, code)) {
      return { kind: 'installing', status: response.status, code };
    }

    // A refusal is news, not just an outcome: whatever the caller does with it, the shell's
    // idea of what this user may reach was computed before the refusal and is now suspect
    // (AD-8). Told after the install-in-flight branch, so a 503 never reaches it.
    if (response.status === 403 && this.onForbidden !== null) this.onForbidden();

    return {
      kind: 'error',
      status: response.status,
      code,
      reason: envelopeString(parsed, 'reason'),
    };
  }

  private buildInit(init: ApiRequestInit): HttpRequestInit {
    const headers: Record<string, string> = { ...(init.headers ?? {}) };
    const access = this.tokens.accessToken();
    if (access !== '') headers['Authorization'] = `Bearer ${access}`;
    const built: HttpRequestInit = { headers, credentials: 'omit' };
    if (init.method !== undefined) built.method = init.method;
    if (init.body !== undefined) built.body = init.body;
    return built;
  }
}
