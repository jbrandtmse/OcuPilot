/**
 * The session state machine behind silent-first sign-in (AD-28), framework-free so
 * `ui/tools/session.test.mjs` can execute it under `node --test`.
 *
 * The states are EXPERIENCE.md's Session table (`:490-499`). The three requests are the
 * CSP server's own token endpoints -- `/login`, `/refresh` and `/logout` are intercepted
 * before OcuPilot dispatches, so nothing here talks to OcuPilot code.
 *
 * Two rules carry the whole design, and both are verified against the live instance in
 * `OcuPilot.Test.Token`:
 *
 * 1. **Only a 401 from `/login` is a credential failure (DW-1).** A 404, a 5xx or a network
 *    fault means the instance is not serving yet -- install runs at container start and the
 *    API refuses until it finishes (AD-38). Those enter `installing`, which renders the same
 *    signing-in presentation and re-probes with backoff. Reporting a failed sign-in there
 *    would tell the user to check a password that was never the problem.
 *
 *    `isInstallInFlight` is the other half of that rule, for the `INSTALL.*` 503 an
 *    **ordinary API call** answers with. `ApiService.requestJson` asks it through
 *    `noteInstallInFlight`, which classifies and backs off in one step, so the rule has one
 *    home and a data call and the silent probe share one backoff chain.
 * 2. **Refresh is single-flight.** A successful refresh rotates the pair in place on the
 *    same `sid`, and replaying the rotated refresh token *revokes the session* -- the
 *    freshly issued pair dies with it (observed on the instance; pinned by
 *    `OcuPilot.Test.Token.TestReplayingARotatedRefreshTokenRevokesTheSession`). So two
 *    concurrent refreshes do not merely race: the loser destroys what the winner just
 *    established. One in-flight refresh, every waiter resolved from it.
 */

import type { TokenPair, TokenStore } from './token-store';

/** Every API path is absolute from the origin root (AD-20). */
export const API_ROOT = '/api/ocupilot';
export const LOGIN_PATH = `${API_ROOT}/login`;
export const REFRESH_PATH = `${API_ROOT}/refresh`;
export const LOGOUT_PATH = `${API_ROOT}/logout`;

/**
 * The states EXPERIENCE.md `:490-499` names.
 *
 * `password-expired` has **no trigger on this build**, and that is a verified negative
 * rather than an omission. Settled on a throwaway container on 2026-09-11: a throwaway
 * principal's password was expired with `Security.Users.ExpireUserPasswords`, and a probe
 * web application -- JWT on, `%ISCMgtPortal`, its own dispatch class overriding
 * `Login()` to record `%request.Data("Error:ErrorCode",1)` -- was driven through a login
 * with the expired password, a wrong password, and no credentials at all. Its record global
 * stayed empty on every attempt: the dispatch class's `Login()` callback is never invoked
 * for a JWT-enabled application, so `$$$PasswordChangeRequired` (935) never reaches one and
 * every 401 on `/login` is byte-identical. Nothing here guesses at a discriminator; the
 * state and its message stay, because the state is what a later story will set once one is
 * found, and because the README's documented unexpire command is what a user in it needs.
 *
 * **DW-105, settled: the rendering half is built, the trigger half is declined.** `sign-in.ts`
 * now renders the sentence with the account's own name substituted and both published links
 * anchored, so the state is complete wherever it is reached from. The state stays unreachable
 * on this build for the verified reason above, and manufacturing a discriminator would be
 * inventing a protocol the instance does not speak.
 */
export type SessionState =
  | 'probing'
  | 'signed-in'
  | 'form'
  | 'form-rejected'
  | 'password-expired'
  | 'session-ended'
  | 'signed-out'
  | 'installing'
  | 'install-unreadable';

/** The `STRINGS` key each state's message slot renders, or null when it has none. */
export type SessionMessageKey =
  | 'statusConnectionSigningIn'
  | 'authSignInFailed'
  | 'authPasswordExpired'
  | 'authSessionEnded'
  | 'authSignedOut'
  | 'authInstallStateUnreadable';

/**
 * What a response to a token endpoint means.
 *
 * `unreachable` is split out of `unavailable` by **DW-104**, and the split is narrow on
 * purpose. DW-1's rule stands whole: a 404 or a 5xx is still `unavailable`, still enters
 * `installing`, and is still never reported as a credential problem. What changed is the one
 * outcome that is not a response at all -- nothing answered -- because that is the one with
 * published copy and a recovery: the unreachable banner and its Retry.
 */
export type LoginOutcomeKind = 'ok' | 'credential-failure' | 'unavailable' | 'unreachable';

/** The slice of `Response` this module reads. */
export interface HttpResponseLike {
  readonly status: number;
  text(): Promise<string>;
}

/** The slice of `RequestInit` this module sends. */
export interface HttpRequestInit {
  method?: string;
  headers?: Record<string, string>;
  body?: string;
  credentials?: 'omit' | 'same-origin' | 'include';
  /**
   * The abort signal `fetch` is given, when the caller set a timeout (DW-167). Declared here
   * rather than in `ApiService` because this is the shape every `FetchLike` implements --
   * `src/main.ts`'s injected bare `fetch` reads it as its own `RequestInit.signal`, and a test
   * seam reads it to prove a request that never answers is the one that got aborted.
   */
  signal?: AbortSignal;
}

export type FetchLike = (path: string, init?: HttpRequestInit) => Promise<HttpResponseLike>;

export interface SessionOptions {
  readonly fetch: FetchLike;
  readonly tokens: TokenStore;
  /** Milliseconds since the epoch. Injected so a test owns the clock. */
  readonly now?: () => number;
  /** Defaults to `setTimeout`. Injected so a test drives the backoff by hand. */
  readonly schedule?: (run: () => void, delayMs: number) => void;
  /**
   * Called with the path whenever a token-endpoint request gets no answer at all (DW-104).
   *
   * The three token endpoints are posted with `fetch` directly rather than through
   * `ApiService.requestJson`, so they never reach its classifier -- and a cold start against an
   * unreachable instance makes exactly one request, this one. Without this seam the banner the
   * whole story is about could never appear on the sign-in card.
   *
   * Injected rather than imported for the reason `ApiOptions.onFault` is, and told rather than
   * asked: whatever the listener does, the outcome of the post is unchanged.
   */
  readonly onUnreachable?: (path: string) => void;
}

/** Backoff between re-probes while the instance reports it is still installing. */
export const BACKOFF_BASE_MS = 500;
export const BACKOFF_MAX_MS = 8000;

/**
 * How long before `exp` the renewal timer fires (AD-28: "the client refreshes on a timer
 * derived from the token's own lifetime"). The access token's own lifetime on this
 * instance is 60 s, so the margin has to be a small fraction of it: 10 s leaves the
 * renewal well clear of expiry while still spending most of each token's life on it.
 *
 * The margin is why a turn can outlive an access token (AD-7 polls for the length of the
 * turn) without any screen or panel knowing that tokens exist.
 */
export const RENEWAL_MARGIN_MS = 10000;

/**
 * DW-1, as one pure function. A 200 is a pair; a **401 is the only credential decision**
 * this endpoint makes; everything else says the instance could not answer, which is not
 * the user's fault and must never be reported as one.
 */
export function classifyLoginStatus(status: number): LoginOutcomeKind {
  if (status === 200) return 'ok';
  if (status === 401) return 'credential-failure';
  return 'unavailable';
}

/** The placeholder the Fixed strings table leaves for the account a sentence is about. */
export const USER_PLACEHOLDER = '<user>';

/**
 * The expired-password sentence with the account's own name in place of its `<user>` (DW-105).
 *
 * A function rather than a `replace` inside the component, for the reason
 * `formatVersionMismatch` is one: renaming the placeholder on one side only would ship the
 * placeholder to the user, and a source-text pin cannot see that.
 */
export function formatUser(template: string, userName: string): string {
  return template.split(USER_PLACEHOLDER).join(userName);
}

/**
 * The expired-password sentence cut into the parts a renderer needs, so its two published link
 * phrases can be anchored without a component typing either of them (DW-105).
 *
 * EXPERIENCE.md's Form login state requires the sentence "with both links": the classic portal,
 * where the password is changed, and the README, which carries the command that clears the
 * expiry. The link *labels* are spans of the canonical sentence itself, located in it rather
 * than transcribed -- so no new copy exists, and a reworded table row moves the anchors with it
 * instead of shipping a stale duplicate.
 *
 * A phrase the sentence does not carry is not linked and not dropped: the whole sentence still
 * renders, as one unlinked part. Losing a link is a degradation; losing a clause would be a lie.
 */
export function linkParts(
  sentence: string,
  phrases: readonly { readonly phrase: string; readonly href: string }[]
): readonly { readonly key: string; readonly text: string; readonly href: string | null }[] {
  const parts: { key: string; text: string; href: string | null }[] = [];
  let rest = sentence;
  let index = 0;
  for (const { phrase, href } of phrases) {
    const at = rest.indexOf(phrase);
    if (at < 0) continue;
    if (at > 0) parts.push({ key: `t${index}`, text: rest.slice(0, at), href: null });
    index += 1;
    parts.push({ key: `a${index}`, text: phrase, href });
    index += 1;
    rest = rest.slice(at + phrase.length);
  }
  if (rest !== '') parts.push({ key: `t${index}`, text: rest, href: null });
  return parts;
}

/** The gate's code for an install state it cannot read at all (AD-38, DW-96). */
export const INSTALL_UNREADABLE_CODE = 'INSTALL.UNREADABLE';

/**
 * Whether an ordinary API response says install has not finished (AD-38). The code is
 * read from OcuPilot's one envelope, never the human `reason` (AD-12, AD-39).
 *
 * `INSTALL.UNREADABLE` is excluded (DW-96): it keeps the `INSTALL.` prefix so an older client
 * still refuses to serve, but waiting never clears it, so it must not arm the backoff.
 *
 * Its one caller is `noteInstallInFlight`, which every data call reaches through
 * `ApiService.requestJson`.
 */
export function isInstallInFlight(status: number, code: string | null): boolean {
  return (
    status === 503 && code !== null && code.startsWith('INSTALL.') && code !== INSTALL_UNREADABLE_CODE
  );
}

/**
 * Whether an ordinary API response says the gate cannot read OcuPilot's install state
 * (AD-38, DW-96) -- the sibling of `isInstallInFlight`, which classifies it into its own
 * session state rather than into the backoff.
 */
export function isInstallUnreadable(status: number, code: string | null): boolean {
  return status === 503 && code === INSTALL_UNREADABLE_CODE;
}

/**
 * The message slot's key for a state, or null where the state carries no message.
 *
 * `signed-out` and `session-ended` are deliberately different messages for deliberately
 * different events: the user ended this one, and the instance ended that one. Reporting
 * "Your session ended." to someone who has just chosen Sign out reads as a fault.
 */
export function sessionMessageKey(state: SessionState): SessionMessageKey | null {
  if (state === 'probing' || state === 'installing') return 'statusConnectionSigningIn';
  if (state === 'form-rejected') return 'authSignInFailed';
  if (state === 'password-expired') return 'authPasswordExpired';
  if (state === 'session-ended') return 'authSessionEnded';
  if (state === 'signed-out') return 'authSignedOut';
  if (state === 'install-unreadable') return 'authInstallStateUnreadable';
  return null;
}

/** Whether the shell must render the install-state-unreadable notice (DW-96). */
export function isInstallStateUnreadable(state: SessionState): boolean {
  return state === 'install-unreadable';
}

/** Whether the shell may render the routed screen, or must render sign-in instead. */
export function isSignedIn(state: SessionState): boolean {
  return state === 'signed-in';
}

/**
 * Whether sign-in should render the signing-in skeleton rather than the credentials form.
 *
 * `installing` renders the same presentation as `probing` deliberately (DW-1): during an
 * install the shell genuinely is still signing in, and presenting a password field there
 * asks the user to fix something that was never their problem. Exported beside
 * `isSignedIn` so the component reads the rule rather than restating it -- a local copy in
 * the template's getter is a second place for the two states to drift apart, and the
 * component has no executed test host of its own until Story 1.9 (DW-93).
 */
export function isWaiting(state: SessionState): boolean {
  return state === 'probing' || state === 'installing';
}

interface LoginOutcome {
  kind: LoginOutcomeKind;
  pair: TokenPair | null;
}

function pairFromBody(body: string): TokenPair | null {
  let parsed: unknown;
  try {
    parsed = JSON.parse(body);
  } catch {
    return null;
  }
  if (typeof parsed !== 'object' || parsed === null) return null;
  const raw = parsed as Record<string, unknown>;
  const access = raw['access_token'];
  const refresh = raw['refresh_token'];
  if (typeof access !== 'string' || access === '') return null;
  if (typeof refresh !== 'string' || refresh === '') return null;
  return {
    accessToken: access,
    refreshToken: refresh,
    sub: typeof raw['sub'] === 'string' ? raw['sub'] : '',
    iat: typeof raw['iat'] === 'number' ? raw['iat'] : 0,
    exp: typeof raw['exp'] === 'number' ? raw['exp'] : 0,
  };
}

export class Session {
  private readonly http: FetchLike;
  private readonly tokens: TokenStore;
  private readonly clock: () => number;
  private readonly schedule: (run: () => void, delayMs: number) => void;
  private readonly onUnreachable: ((path: string) => void) | null;

  private currentState: SessionState = 'probing';
  private currentUserName = '';
  private currentPassword = '';
  /**
   * Whether the credentials in the fields are a submit that never got an answer (DW-104), and
   * so are still owed one. Set only by the transport-fault branch of `formLogin`, cleared by
   * every other outcome and by `signOut()`.
   */
  private submitUnanswered = false;
  private readonly listeners = new Set<() => void>();

  private refreshInFlight: Promise<boolean> | null = null;
  private submitInFlight: Promise<boolean> | null = null;
  private installAttempts = 0;
  /**
   * Whether a backoff probe is already scheduled. The install-backoff chain is
   * single-flight for the reason `refreshInFlight` is (DW-102): two callers can reach it at
   * once -- the session's own probe and a data call that met an `INSTALL.*` 503 -- and a
   * second chain would double the attempt count, shorten nothing, and race the first to
   * mint and store a pair.
   *
   * Cleared when the scheduled probe runs, so the chain continues at the next delay, and by
   * `signOut()`, so a tab signed out while a chain was armed can back off again after a
   * later sign-in.
   */
  private backoffArmed = false;
  /**
   * Bumped when an unreadable install state is noted (DW-96). A backoff probe armed before it
   * captures the old value and does not run, so the tab never returns to "Signing in..." on a
   * timer while waiting cannot help.
   */
  private installGeneration = 0;
  /**
   * Bumped whenever the pair changes or the session ends. A scheduled renewal captures the
   * value it was armed with and does nothing if it no longer matches, which is how a timer
   * is cancelled without a handle -- `schedule` is injected as a bare
   * `(run, delayMs) => void` so a test can drive it, and that signature has nowhere to
   * return a cancellation token.
   */
  private renewalGeneration = 0;
  /**
   * Bumped by `signOut()` and by nothing else. Every chain that can still be in flight
   * across a sign-out -- the probe, the refresh, and the backoff timer `enterInstalling()`
   * arms -- captures it on entry and abandons, touching no state, when it no longer
   * matches. `formLogin()` also adopts and is deliberately not guarded: the form renders
   * only while the tab is not signed in and the account menu only while it is, so a submit
   * cannot be in flight when a sign-out happens, and one started afterwards captures the
   * new value and is a fresh sign-in.
   *
   * Disarming the renewal timer is not enough on its own. A refresh or a backoff probe
   * started before the sign-out is still in flight afterwards, and the browser-level
   * login a failed logout left alive would answer its `/login` with a fresh pair -- so
   * the tab would sign itself back in seconds after the user signed out, which is
   * DW-5's failure with an extra step.
   */
  private signOutGeneration = 0;
  /** Which state a 401 settles on next -- `form` on a cold start, `session-ended` after a refresh. */
  private refusalState: SessionState = 'form';

  /**
   * Whether this tab has ever held a pair. Set by `adopt()`, cleared by `signOut()`.
   *
   * It is what tells "your session ended" from "you never had one". Since Story 1.13 the
   * connectivity probe re-issues the identity read on a tab that may never have signed in, and
   * an anonymous 401 sends `ApiService` into `refresh()` exactly as a lapsed pair would --
   * which used to escalate `refusalState` and greet a first-time visitor with
   * `authSessionEnded`. A session that never existed cannot have ended (DW-1's rule: never
   * report as the user's what was the instance's).
   */
  private everAdopted = false;

  constructor(options: SessionOptions) {
    this.http = options.fetch;
    this.tokens = options.tokens;
    this.clock = options.now ?? (() => Date.now());
    this.schedule =
      options.schedule ??
      ((run, delayMs) => {
        setTimeout(run, delayMs);
      });
    this.onUnreachable = options.onUnreachable ?? null;
  }

  state(): SessionState {
    return this.currentState;
  }

  /**
   * The user name the form should show. Kept across a rejection, which is exactly what
   * EXPERIENCE.md's Form login state asks for: the password is cleared, the name is not.
   * Also set from a minted pair's `sub`, so a silently signed-in tab knows who it is.
   *
   * `signOut()` does clear it. That rule is scoped to a rejected *attempt* inside one
   * sign-in; a sign-out is the shared machine being handed over, and leaving the name in
   * the field tells the next person who was just using it.
   */
  userName(): string {
    return this.currentUserName;
  }

  setUserName(value: string): void {
    this.currentUserName = value;
  }

  /**
   * The password the form is holding, and the only place this client ever holds one.
   *
   * Cleared on every outcome of a submit that **got an answer** -- accepted or rejected -- so
   * it never outlives the request that used it. Never stored, never logged, never in a URL
   * (AD-35, AD-47: memory only, for exactly as long as the form is on screen).
   *
   * **DW-104 is the one exception, and it is not a widening.** A submit that met an unreachable
   * instance got no answer, so the form does not leave the screen: clearing the field there
   * discards what the user typed for a failure that was never theirs and offers no way back.
   * The value stays in the same place, for the same lifetime, while the same form is up --
   * `signOut()` and an answered submit both clear it.
   */
  password(): string {
    return this.currentPassword;
  }

  setPassword(value: string): void {
    this.currentPassword = value;
  }

  /**
   * Submit the credentials the form is holding. The user name survives whatever happens;
   * the password does not.
   */
  async submitForm(): Promise<boolean> {
    // Single-flight, for the same reason `refresh()` is. Two submits in flight mint two
    // `sid`s, the second `adopt()` overwrites the first pair, and the first session is
    // left live on the instance with nothing holding it. The form does unmount as soon as
    // `formLogin` sets `probing`, but change detection is scheduled rather than
    // synchronous (AD-19, zoneless), so a second Enter or click can land before it.
    const inFlight = this.submitInFlight;
    if (inFlight !== null) return inFlight;
    const started = this.runSubmit().finally(() => {
      this.submitInFlight = null;
    });
    this.submitInFlight = started;
    return started;
  }

  private async runSubmit(): Promise<boolean> {
    const user = this.currentUserName;
    const password = this.currentPassword;
    const accepted = await this.formLogin(user, password);
    // DW-104: the password is cleared on every answered outcome and kept on the one unanswered
    // one, so a user whose instance was unreachable presses Retry rather than typing it again.
    if (!this.submitUnanswered) this.currentPassword = '';
    this.notify();
    return accepted;
  }

  /**
   * Send again what the user typed, if a submit is still unanswered (DW-104).
   *
   * Reached two ways, and they are the same recovery: the unreachable banner's Retry, and the
   * connectivity probe finding the instance again. A tab with nothing unanswered does nothing,
   * which is what lets the probe's own recovery path call this unconditionally.
   */
  retrySubmit(): Promise<boolean> {
    if (!this.submitUnanswered) return Promise.resolve(false);
    return this.submitForm();
  }

  /**
   * Whether a submit is still owed an answer. The form itself renders no Retry -- the one the
   * user presses is the connectivity banner's, above the card -- so this is read by tests and
   * by `retrySubmit()`'s own guard rather than by a control.
   */
  hasUnansweredSubmit(): boolean {
    return this.submitUnanswered;
  }

  /** The pair this tab holds, or null. */
  pair(): TokenPair | null {
    return this.tokens.read();
  }

  /**
   * Milliseconds of access-token life left, from the `exp` the instance itself minted
   * (seconds since the epoch) against the injected clock. Zero when this tab holds no
   * pair, and zero for a pair already past its expiry -- which is what lets
   * `ApiService` refresh before sending rather than after a wasted 401.
   *
   * Zero is also what a pair with **no** `exp` reports, so a caller that pre-empts on this
   * must check `exp` itself first; `ApiService` does.
   */
  remainingMs(): number {
    const pair = this.tokens.read();
    if (pair === null || pair.exp === 0) return 0;
    return Math.max(0, pair.exp * 1000 - this.clock());
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /**
   * Start the silent probe. Called at bootstrap so the request is in flight while the
   * shell paints; a tab that already holds a pair (a reload, per DW-6) skips straight to
   * `signed-in` and probes nothing.
   */
  start(): void {
    const adopted = this.tokens.adopted() ? this.tokens.read() : null;
    if (adopted !== null) {
      // A pair read back out of storage is a pair this tab held: the reload (DW-6) is the one
      // way into `signed-in` that does not pass through `adopt()`, so without this line a
      // reloaded tab whose refresh is later refused settled on the bare form and was never told
      // its session had ended -- EXPERIENCE.md `:571`'s rule, lost to the guard that was added
      // to stop a first-time visitor being told the same thing.
      this.everAdopted = true;
      // The adopted pair carries the name it was minted for, so a reloaded tab knows who
      // it is without a round trip -- which is what `userName()` promises its callers.
      if (adopted.sub !== '') this.currentUserName = adopted.sub;

      // A stored pair is not a live pair. Access tokens last 60 s, so a tab reloaded even
      // a minute later holds one that has already expired; reporting `signed-in` on it
      // renders the whole product against a credential the instance will refuse. Renew
      // first and let the outcome settle the state -- a good refresh token signs the tab
      // back in invisibly, and a dead one falls through to the probe and then the form.
      if (adopted.exp !== 0 && this.remainingMs() === 0) {
        this.setState('probing');
        this.refusalState = 'session-ended';
        void this.refresh();
        return;
      }
      this.setState('signed-in');
      this.scheduleRenewal();
      return;
    }
    this.setState('probing');
    this.refusalState = 'form';
    void this.probeAndSettle();
  }

  /**
   * One empty-body `POST /login`. The browser's own `%ISCMgtPortal` cookie is what
   * authenticates it, and `credentials: 'include'` is what makes the browser attach it --
   * the one request in this client that carries a cookie, and it carries no token.
   */
  async silentProbe(): Promise<boolean> {
    return this.probeAndSettle();
  }

  /**
   * The form fallback. Field names are `user` and `password` -- not `username` -- which
   * is what the CSP server reads.
   */
  async formLogin(user: string, password: string): Promise<boolean> {
    this.currentUserName = user;
    this.submitUnanswered = false;
    this.setState('probing');
    const outcome = await this.post(LOGIN_PATH, JSON.stringify({ user, password }));
    if (outcome.kind === 'ok' && outcome.pair !== null) {
      this.adopt(outcome.pair);
      return true;
    }
    if (outcome.kind === 'credential-failure') {
      this.setState('form-rejected');
      return false;
    }
    if (outcome.kind === 'unreachable') {
      // **DW-104.** Nothing answered, so there is nothing to report about the credentials and
      // no install to wait out: the instance is not there. Entering `installing` here showed
      // the signing-in skeleton over a form that had just been typed into, discarded the
      // password with it, and left the user no way back -- for a state whose published copy
      // (the unreachable banner, with Retry) says exactly what happened and what to do.
      //
      // `form`, not `form-rejected`: no credential decision was made. The banner above the card
      // is the whole message, and `connectivity` has already been told by `post()`.
      this.submitUnanswered = true;
      this.setState('form');
      return false;
    }
    this.enterInstalling();
    return false;
  }

  /**
   * Refresh the pair, at most one request at a time. Every concurrent caller is handed
   * the same promise, so a 401 storm across several in-flight API calls produces one
   * `/refresh` and one outcome (DW-4).
   */
  refresh(): Promise<boolean> {
    const inFlight = this.refreshInFlight;
    if (inFlight !== null) return inFlight;
    const started = this.runRefresh().finally(() => {
      this.refreshInFlight = null;
    });
    this.refreshInFlight = started;
    return started;
  }

  /**
   * End the session: **locally first, then on the instance** (DW-5).
   *
   * The order is the whole design. A request can fail three ways -- throw, answer a non-2xx
   * (a dead pair logged out twice answers 401), or never settle -- and clearing first covers
   * all three by construction, where a `catch` covers only the throw. So the pair is
   * captured, the renewal disarmed, the store cleared and the state settled **before** the
   * POST is issued, and no outcome of that POST is read.
   *
   * Both credentials are load-bearing (AD-28). `Authorization: Bearer` authorizes the logout;
   * `credentials: 'include'` is what makes the browser attach the `CSPBrowserId` cookie
   * *(inference -- no browser executes this code in any test; see `OcuPilot.Test.Token`,
   * which sets the header by hand)*, and a logout carrying that cookie ends the
   * `%ISCMgtPortal` login the whole browser shares, along with every session minted from it.
   * The Bearer alone will not do: the cookie resolves to the most recently minted session in
   * the group, so a Bearer-only logout ends the login from the tab holding that session and
   * leaves it alive from any other, and a tab cannot know which it is.
   *
   * The method awaits the request, so a caller that awaits it sees the round trip complete --
   * but nothing the tab shows is waiting on it.
   */
  async signOut(): Promise<void> {
    const pair = this.tokens.read();
    const access = pair === null ? '' : pair.accessToken;

    this.signOutGeneration += 1;
    this.nextRenewalGeneration();
    this.tokens.clear();
    this.currentPassword = '';
    this.currentUserName = '';
    this.submitUnanswered = false;
    this.everAdopted = false;
    this.installAttempts = 0;
    this.backoffArmed = false;
    this.refusalState = 'form';
    this.setState('signed-out');

    if (access === '') return;
    try {
      await this.http(LOGOUT_PATH, {
        method: 'POST',
        headers: { Authorization: `Bearer ${access}` },
        credentials: 'include',
      });
    } catch {
      // Deliberately unread. The tab was already cleared and settled above; there is no
      // outcome here that should change what the user sees.
    }
  }

  private async runRefresh(): Promise<boolean> {
    const generation = this.signOutGeneration;
    const pair = this.tokens.read();
    if (pair === null) {
      // DW-107. A refresh STARTED after a sign-out captures the post-sign-out generation,
      // so the guard below cannot catch it -- and the fall-through to `retryProbeThenEnd()`
      // would probe `/login`, which a browser-level login a failed logout left alive would
      // answer with a fresh pair. The tab would sign itself back in seconds after the user
      // signed out. A tab holding no pair in a state it deliberately reached signs nothing.
      if (this.currentState === 'signed-out') return false;
      return this.retryProbeThenEnd();
    }
    const outcome = await this.post(
      REFRESH_PATH,
      JSON.stringify({ refresh_token: pair.refreshToken })
    );
    if (generation !== this.signOutGeneration) return false;
    if (outcome.kind === 'ok' && outcome.pair !== null) {
      this.adopt(outcome.pair);
      return true;
    }
    if (outcome.kind === 'credential-failure') {
      // EXPERIENCE.md :571 -- the silent probe runs once more before the form, because a
      // browser-level login that is still good mints a fresh pair and the user sees nothing.
      this.nextRenewalGeneration();
      this.tokens.clear();
      return this.retryProbeThenEnd();
    }
    // The instance could not answer. The backoff probe that follows is a continuation of
    // this refresh, so when it is refused the session has ended -- without this the probe
    // would settle on a bare `form` and the user would never be told why.
    this.refusalState = 'session-ended';
    this.enterInstalling();
    return false;
  }

  /**
   * Probe once more, then settle on whichever refusal this tab has earned.
   *
   * `session-ended` only for a tab that held a pair: EXPERIENCE.md `:571`'s rule is that a
   * refresh which failed ran out of a session, and a tab that never had one falls back to the
   * plain form instead of being told something ended.
   */
  private async retryProbeThenEnd(): Promise<boolean> {
    if (this.everAdopted) this.refusalState = 'session-ended';
    return this.probeAndSettle();
  }

  private async probeAndSettle(): Promise<boolean> {
    const generation = this.signOutGeneration;
    if (this.currentState !== 'installing') this.setState('probing');
    const outcome = await this.post(LOGIN_PATH, null);
    if (generation !== this.signOutGeneration) return false;
    if (outcome.kind === 'ok' && outcome.pair !== null) {
      this.adopt(outcome.pair);
      return true;
    }
    if (outcome.kind === 'credential-failure') {
      this.installAttempts = 0;
      this.setState(this.refusalState);
      return false;
    }
    this.enterInstalling();
    return false;
  }

  /**
   * Classify an ordinary API response and, when it says install has not finished, enter the
   * same backoff the silent probe uses. Returns whether the response was an `INSTALL.*` refusal
   * this method handled, which is how `ApiService` tells its caller "not serving" without owning
   * a second copy of the rule.
   *
   * `INSTALL.UNREADABLE` is handled too, and differently (DW-96): the tab enters
   * `install-unreadable`, any armed backoff is cancelled, and nothing is armed, because waiting
   * never clears it. The notice's Retry is the one way back (`retryInstallState`).
   *
   * Being the same chain is the point (DW-102): a data call and the session's own probe can
   * both land here, and the second arms nothing while the first is still waiting.
   */
  noteInstallInFlight(status: number, code: string | null): boolean {
    if (isInstallUnreadable(status, code)) {
      if (this.currentState !== 'signed-out') this.enterInstallUnreadable();
      return true;
    }
    if (!isInstallInFlight(status, code)) return false;
    // A tab the user signed out of is not waiting for an install (DW-107's rule, at the
    // other end of the same window): a call already on the wire when Sign out was chosen
    // answers afterwards, and arming here would put the signed-out tab back on the
    // installing presentation. The caller is still told "installing" -- that is what its
    // 503 said -- but nothing is armed.
    if (this.currentState === 'signed-out') return true;
    // DW-102: one chain, however many callers. `backoffArmed` alone covers only the armed
    // window; it is cleared when the timer fires, so a second caller arriving while the
    // probe's own /login is still on the wire would arm a second chain, and the two would
    // mint two sids and overwrite each other's stored pair. The session stays `installing`
    // for the whole chain -- armed and running alike -- so that is the state to read.
    // The chain's own continuation calls `enterInstalling()` directly and is unaffected.
    if (this.currentState === 'installing') return true;
    this.enterInstalling();
    return true;
  }

  /**
   * Re-check an unreadable install state once (DW-96): a tab holding a pair returns to
   * `signed-in`, so the shell re-issues its identity read and the gate answers again; a tab with
   * no pair returns to the form. Does nothing in any other state.
   */
  retryInstallState(): void {
    if (this.currentState !== 'install-unreadable') return;
    this.setState(this.tokens.read() === null ? 'form' : 'signed-in');
  }

  private enterInstallUnreadable(): void {
    this.installGeneration += 1;
    this.backoffArmed = false;
    this.installAttempts = 0;
    this.setState('install-unreadable');
  }

  private enterInstalling(): void {
    const generation = this.signOutGeneration;
    const installGeneration = this.installGeneration;
    this.setState('installing');
    // DW-102: one chain, however many callers. A second arming would count a second
    // attempt, so the two chains would probe at different delays and both could adopt.
    if (this.backoffArmed) return;
    this.backoffArmed = true;
    this.installAttempts += 1;
    const delay = Math.min(
      BACKOFF_BASE_MS * Math.pow(2, this.installAttempts - 1),
      BACKOFF_MAX_MS
    );
    this.schedule(() => {
      this.backoffArmed = false;
      // A sign-out has happened since this probe was armed. It must not run at all:
      // `probeAndSettle` would set `probing` before it even reached the wire, putting the
      // signed-out tab back on the signing-in presentation.
      if (generation !== this.signOutGeneration) return;
      if (installGeneration !== this.installGeneration) return;
      void this.probeAndSettle();
    }, delay);
  }

  private adopt(pair: TokenPair): void {
    this.tokens.write(pair);
    this.everAdopted = true;
    if (pair.sub !== '') this.currentUserName = pair.sub;
    this.installAttempts = 0;
    this.refusalState = 'form';
    // A renewal that lands while the install state is unreadable rotates the pair and keeps the
    // notice: the token endpoints are not gated, so a fresh pair says nothing about the gate.
    if (this.currentState !== 'install-unreadable') this.setState('signed-in');
    this.scheduleRenewal();
  }

  /**
   * Arm the renewal timer for the pair this tab now holds (AD-28). The delay comes from
   * the token's own `exp`, less `RENEWAL_MARGIN_MS`, so the pair is rotated a little
   * before the instance would start refusing it and no call ever spends a round trip
   * discovering that it expired.
   *
   * A pair with **no** `exp` arms nothing: there is no lifetime to derive a timer from,
   * and guessing one would rotate the pair on a schedule the instance never agreed to.
   * Those pairs keep the retry-on-401 path, which is the other half of AD-28's rule.
   */
  private scheduleRenewal(): void {
    const generation = this.nextRenewalGeneration();
    const pair = this.tokens.read();
    if (pair === null || pair.exp === 0) return;
    const delay = Math.max(0, this.remainingMs() - RENEWAL_MARGIN_MS);
    this.schedule(() => {
      // A sign-out, a later pair, or an ended session has happened since this was armed.
      if (generation !== this.renewalGeneration) return;
      if (this.tokens.read() === null) return;
      void this.refresh();
    }, delay);
  }

  /**
   * Disarm whatever renewal is pending. Called wherever the pair stops being this tab's
   * credential, so a timer armed for a pair that no longer exists cannot sign the tab back
   * in after it was signed out.
   */
  private nextRenewalGeneration(): number {
    this.renewalGeneration += 1;
    return this.renewalGeneration;
  }

  /**
   * POST to a token endpoint. `credentials: 'include'` is deliberate and is scoped to
   * these three paths: the browser-level `CSPBrowserId` cookie is what a silent mint and
   * a sign-out need, and it is never authorization for a data call (AD-28) -- the API
   * service sends `credentials: 'omit'` for everything else.
   */
  private async post(path: string, body: string | null): Promise<LoginOutcome> {
    const init: HttpRequestInit = { method: 'POST', credentials: 'include' };
    if (body !== null) {
      init.headers = { 'Content-Type': 'application/json' };
      init.body = body;
    }
    let response: HttpResponseLike;
    try {
      response = await this.http(path, init);
    } catch {
      // A network fault is not a credential failure (DW-1), and it is not a response either
      // (DW-104): nothing answered, which is the one outcome with its own published copy and
      // its own recovery. Reported here, once, for both token endpoints that go through this
      // method -- `/login` and `/refresh`. `signOut()` posts `/logout` with `this.http`
      // directly and swallows its throw on purpose: the tab is already cleared and settled, so
      // there is no outcome there that should change what the user sees.
      this.report(path);
      return { kind: 'unreachable', pair: null };
    }
    const kind = classifyLoginStatus(response.status);
    if (kind !== 'ok') return { kind, pair: null };
    let text = '';
    try {
      text = await response.text();
    } catch {
      return { kind: 'unavailable', pair: null };
    }
    const pair = pairFromBody(text);
    // A 200 whose body is not a pair is the instance failing to answer, not the user
    // failing to authenticate.
    if (pair === null) return { kind: 'unavailable', pair: null };
    return { kind: 'ok', pair };
  }

  /**
   * Tell whoever is listening that a token endpoint got no answer. Guarded, because a listener
   * that throws must not turn one failure into two -- the same rule `ApiService.report` follows.
   */
  private report(path: string): void {
    if (this.onUnreachable === null) return;
    try {
      this.onUnreachable(path);
    } catch {
      // Deliberately unread: reporting is informational and never changes the outcome.
    }
  }

  private setState(next: SessionState): void {
    if (this.currentState === next) return;
    this.currentState = next;
    this.notify();
  }

  private notify(): void {
    for (const listener of this.listeners) listener();
  }
}
