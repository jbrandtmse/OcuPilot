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
 *    **ordinary API call** answers with. It is **not wired to `ApiService` in this story**,
 *    which has no data call to wire it to: `Api.Router`'s `UrlMap` is empty and only the
 *    CSP server's token endpoints are reachable. Story 1.8, which adds the first route with
 *    a body, is its first consumer and is where the branch lands.
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
 * found (routed to 1.13), and because the README's documented unexpire command is what a
 * user in it needs.
 */
export type SessionState =
  | 'probing'
  | 'signed-in'
  | 'form'
  | 'form-rejected'
  | 'password-expired'
  | 'session-ended'
  | 'signed-out'
  | 'installing';

/** The `STRINGS` key each state's message slot renders, or null when it has none. */
export type SessionMessageKey =
  | 'statusConnectionSigningIn'
  | 'authSignInFailed'
  | 'authPasswordExpired'
  | 'authSessionEnded'
  | 'authSignedOut';

/** What a response to a token endpoint means. */
export type LoginOutcomeKind = 'ok' | 'credential-failure' | 'unavailable';

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
}

export type FetchLike = (path: string, init?: HttpRequestInit) => Promise<HttpResponseLike>;

export interface SessionOptions {
  readonly fetch: FetchLike;
  readonly tokens: TokenStore;
  /** Milliseconds since the epoch. Injected so a test owns the clock. */
  readonly now?: () => number;
  /** Defaults to `setTimeout`. Injected so a test drives the backoff by hand. */
  readonly schedule?: (run: () => void, delayMs: number) => void;
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

/**
 * Whether an ordinary API response says install has not finished (AD-38). The code is
 * read from OcuPilot's one envelope, never the human `reason` (AD-12, AD-39).
 *
 * **No caller in this story** -- see the module header. Story 1.8's first data call is what
 * branches on it; until then this is the decision written down, not a decision being taken.
 */
export function isInstallInFlight(status: number, code: string | null): boolean {
  return status === 503 && code !== null && code.startsWith('INSTALL.');
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
  return null;
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

  private currentState: SessionState = 'probing';
  private currentUserName = '';
  private currentPassword = '';
  private readonly listeners = new Set<() => void>();

  private refreshInFlight: Promise<boolean> | null = null;
  private submitInFlight: Promise<boolean> | null = null;
  private installAttempts = 0;
  /**
   * Bumped whenever the pair changes or the session ends. A scheduled renewal captures the
   * value it was armed with and does nothing if it no longer matches, which is how a timer
   * is cancelled without a handle -- `schedule` is injected as a bare
   * `(run, delayMs) => void` so a test can drive it, and that signature has nowhere to
   * return a cancellation token.
   */
  private renewalGeneration = 0;
  /**
   * Bumped by `signOut()` and by nothing else. Every chain that can adopt a pair --
   * the probe, the refresh, and the backoff timer `enterInstalling()` arms -- captures
   * it on entry and abandons, touching no state, when it no longer matches.
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

  constructor(options: SessionOptions) {
    this.http = options.fetch;
    this.tokens = options.tokens;
    this.clock = options.now ?? (() => Date.now());
    this.schedule =
      options.schedule ??
      ((run, delayMs) => {
        setTimeout(run, delayMs);
      });
  }

  state(): SessionState {
    return this.currentState;
  }

  /**
   * The user name the form should show. Kept across a rejection, which is exactly what
   * EXPERIENCE.md `:424` asks for: the password is cleared, the name is not. Also set
   * from a minted pair's `sub`, so a silently signed-in tab knows who it is.
   */
  userName(): string {
    return this.currentUserName;
  }

  setUserName(value: string): void {
    this.currentUserName = value;
  }

  /**
   * The password the form is holding, and the only place this client ever holds one.
   * Cleared on every outcome of a submit -- accepted, rejected or unreachable -- so it
   * never outlives the request that used it. Never stored, never logged, never in a URL
   * (AD-35).
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
    this.currentPassword = '';
    this.notify();
    return accepted;
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
    this.installAttempts = 0;
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

  private async retryProbeThenEnd(): Promise<boolean> {
    this.refusalState = 'session-ended';
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

  private enterInstalling(): void {
    const generation = this.signOutGeneration;
    this.setState('installing');
    this.installAttempts += 1;
    const delay = Math.min(
      BACKOFF_BASE_MS * Math.pow(2, this.installAttempts - 1),
      BACKOFF_MAX_MS
    );
    this.schedule(() => {
      // A sign-out has happened since this probe was armed. It must not run at all:
      // `probeAndSettle` would set `probing` before it even reached the wire, putting the
      // signed-out tab back on the signing-in presentation.
      if (generation !== this.signOutGeneration) return;
      void this.probeAndSettle();
    }, delay);
  }

  private adopt(pair: TokenPair): void {
    this.tokens.write(pair);
    if (pair.sub !== '') this.currentUserName = pair.sub;
    this.installAttempts = 0;
    this.refusalState = 'form';
    this.setState('signed-in');
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
      // A network fault is not a credential failure (DW-1).
      return { kind: 'unavailable', pair: null };
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

  private setState(next: SessionState): void {
    if (this.currentState === next) return;
    this.currentState = next;
    this.notify();
  }

  private notify(): void {
    for (const listener of this.listeners) listener();
  }
}
