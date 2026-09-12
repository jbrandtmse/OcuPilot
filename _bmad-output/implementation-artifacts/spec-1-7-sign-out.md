---
title: 'Story 1.7: Sign-out'
type: 'feature'
created: '2026-09-11'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-1-6-silent-first-sign-in.md'
  - '{project-root}/.claude/rules/objectscript-testing.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Story 1.6 built `Session.signOut()` and nothing reaches it: no control calls it, `actionSignOut`
and `authSignedOut` are dead keys, and it lands on `form`, whose slot renders no message. A user on a shared
machine has no way to end the session, and a failed logout would leave the pair in the tab (DW-5).

**Approach:** Add the account-menu affordance that invokes it and a `signed-out` state carrying
"You're signed out."; make the local half unconditional so no logout outcome can leave a token behind; and
pin over the real wire that a logout carrying **both** the Bearer and the cookie ends the browser-level
`%ISCMgtPortal` login, while a Bearer-only one does not.

## Boundaries & Constraints

**Always:**

- Sign-out is `POST /api/ocupilot/logout` carrying the Bearer **and** `credentials: 'include'` (AD-28).
  Verified live on `ocupilot-iris` 2026-09-12: Bearer+cookie → 200 and the browser-level login is gone;
  Bearer-only → 200 and it survives; cookie-only → 401. Both credentials are load-bearing.
- The local half — clear the pair, disarm the renewal, settle the state — runs **first and unconditionally**,
  before the request and never gated on its outcome (DW-5).
- Every user-facing word from `ui/src/app/core/strings.ts`; every colour an existing `--ocu-*` token; the
  session logic stays framework-free in `core/` so `node --test` executes it.
- No token, cookie value or credential reaches a log, a URL, a status message or an assertion description
  (AD-35) — `%UnitTest.Manager.LogAssert` persists descriptions on pass as well as failure.

**Never:**

- No new string and **no new row in EXPERIENCE.md's Fixed strings table**: `actionSignOut` (`strings.ts:112`)
  and `authSignedOut` (`:224`) already exist, and a new row shifts a data row past the hardcoded `252..302`
  range in `ui/tools/strings.test.mjs:47`.
- No OcuPilot route. `/logout` is the CSP server's, intercepted before dispatch; `Api.Router`'s `UrlMap`
  stays empty and no ObjectScript source file changes except the test classes.
- No status bar, header, rail or side bar — 1.10 owns the chrome and mounts this component into it.
- No confirm dialog: EXPERIENCE.md `:171` enumerates every dialog that exists and sign-out is not one.
- No account on the live instance created, modified, locked or expired except this story's throwaway
  principal, removed in teardown. No real user's live session is ever revoked.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Sign out | Signed-in tab; user chooses Sign out | `POST /logout` with `Authorization: Bearer` **and** `credentials: 'include'`; pair cleared; state `signed-out`; form shows `authSignedOut` | No error expected |
| Browser-level end | That logout, over the wire | The same cookie stops minting on `/api/ocupilot/login` **and** on the sibling JWT application `/api/interop-editors/login` — both 401 | — |
| Bearer only | `/logout` with no cookie | 200, but the cookie still mints: the browser-level login survives | Why `credentials: 'include'` is not optional |
| Cookie only | `/logout` with no Bearer | 401, and the browser-level login survives | The Bearer is not optional either |
| Logout fails (DW-5) | `fetch` rejects, or answers 401/5xx (a dead pair logs out twice → 401, observed) | The tab is **already** cleared and `signed-out`; the outcome is ignored | Never blocks or reverts the local half |
| Logout hangs (DW-5) | The request never settles | Same — the local half completed before the request was issued | `signOut()` still awaits, so callers see completion |
| Re-mint after sign-out | A backoff or refresh chain started before sign-out lands after it | It is abandoned; no pair is adopted and the state stays `signed-out` | A stale chain must not sign the tab back in |
| Signed out elsewhere | `?IRISLogout=end`, or another JWT app revoking this `sid`; next call 401s | One refresh, then one silent probe: 200 → `signed-in` invisibly; 401 → `session-ended` | Never `authSignedOut` — the user did not choose it |

</intent-contract>

## Code Map

**Extend, never duplicate.** All anchors verified 2026-09-11 against the working tree.

- `ui/src/app/core/session.ts` (556) — `signOut()` `:390-408` already sends Bearer + `credentials: 'include'`
  and swallows a throw, but clears **after** the request and lands on `'form'`. `SessionState` `:55-62`,
  `SessionMessageKey` `:65-69`, `sessionMessageKey()` `:137-143`, `isSignedIn()` `:146-148`,
  `isWaiting()` `:160-162`. `probeAndSettle()` `:443-457` and `enterInstalling()` `:459-469` are the chains
  that can land after a sign-out; `nextRenewalGeneration()` `:508-511` disarms only the renewal timer.
- `ui/src/app/shell/sign-in.ts` (219) — the status slot `:116-126`: three `@if` blocks over three paren-free
  getters `:170-180`, `role="alert"` on the rejection only, banners for the other two. The component to
  imitate: signal bridge `:136-137`; glyphs computed in TypeScript (`revealGlyph` `:150`), never typed into
  a template.
- `ui/src/app/app.ts` (59) — `@if (signedIn) { <router-outlet /> } @else { <app-sign-in /> }` `:34-39`.
  `ui/tools/build-output.test.mjs:195-226` pins line `:34`: the inline `template:`, its first
  `{{ STRINGS.<key> }}` and its first `class="…"`, whose rule must be in the global bundle.
- `ui/src/app/core/strings.ts` — `actionSignOut` `:112`, `authSignedOut` `:224`; both referenced nowhere.
  107 keys, and `strings.test.mjs` asserts `keys === literals + 3`, so the count must not move.
- `ui/src/styles/_components.scss` (262) — `@mixin ocu-focus-ring` `:27`, `.ocu-signin-status` `:236`,
  `.ocu-banner` `:246`/`-restrained` `:259`. No chrome rules and no `focus-ring.on-chrome` variant exist.
- `ui/tools/client-lint.mjs` — no literal text node `:175-194`; a control-flow condition must be **paren-free**
  (`@if (open)`, never `@if (isOpen())`) `:154-160`; `aria-label` takes only a whole `{{ STRINGS.<key> }}`
  `:130-131`, `:256-275`; no colour literal outside `_tokens.scss` `:80-107`.
- `ui/tools/session.test.mjs` (894) — `:401` and `:425` already pin the two "signed out elsewhere" outcomes.
  `:549`, `:566`, `:580`, `:596`, `:753` and `:854` enumerate the state list or expect `'form'` after
  `signOut()`, and all must gain `signed-out`.
- `ui/tools/api.test.mjs:382-395` — the source scan over `ui/src` for cookie / persistent-storage /
  cross-tab / frame writes. A new component must not trip it.
- `src/OcuPilot/Test/Token.cls` (491) — `PostToken(endpoint, body, cookie, bearer, …)` `:184-191` already
  expresses the credentialled, cookie-only and bare forms; `LoginBody()` `:195`, `HeaderValue()` `:168`,
  `Logout()` `:487`; `TestLogoutIsPerSidAndLeavesASiblingLive` `:406` covers the per-`sid` half. Its doc
  comment `:215-220` claims "No second JWT-enabled application exists on the instance" — **wrong**: nine of
  the 25 `%ISCMgtPortal` applications are JWT-enabled, `/api/interop-editors` among them.
- `src/OcuPilot/Api/Router.cls` (228) — `UrlMap` empty; unchanged. `src/OcuPilot/Test/Wire.cls` — the
  throwaway-principal pattern `Token.cls` already follows.

## Tasks & Acceptance

**Execution — client core:**

- `ui/src/app/core/session.ts` — add `'signed-out'` to `SessionState` and `'authSignedOut'` to
  `SessionMessageKey`, and map the two in `sessionMessageKey()`. Rewrite `signOut()` so the local half runs
  first: capture the access token, `nextRenewalGeneration()`, `tokens.clear()`, clear the password, set
  `refusalState = 'form'`, `setState('signed-out')`, **then** issue the POST with the captured Bearer inside
  a `try`/`catch` whose outcome is ignored. Add one `signOutGeneration` counter bumped only by `signOut()`;
  `probeAndSettle()`, `runRefresh()` and `enterInstalling()`'s scheduled callback capture it on entry and
  abandon without touching state when it has changed — so a chain started before sign-out cannot adopt a pair
  after it. `isSignedIn` and `isWaiting` stay false for the new state.

**Execution — client shell:**

- `ui/src/app/shell/account-menu.ts` — *new*. `app-account-menu`, `OnPush`, the signal bridge `sign-in.ts`
  uses. A trigger button carrying the session's `userName()` plus a down-triangle glyph computed in
  TypeScript as the escape `'\u25BE'`, never a literal byte (Rule 14), and rendered `aria-hidden`, with
  `aria-haspopup="menu"` and a bound `[attr.aria-expanded]`; a `role="menu"` panel labelled by the
  trigger's id (no new string), holding one `role="menuitem"` button
  reading `{{ STRINGS.actionSignOut }}` that calls `session.signOut()`. Escape closes and returns focus to
  the trigger (EXPERIENCE.md `:532`); the open flag is a paren-free getter. No literal text node anywhere.
- `ui/src/app/shell/sign-in.ts` — add a fourth status block: a `signedOut` getter over
  `sessionMessageKey(...) === 'authSignedOut'` rendering `{{ STRINGS.authSignedOut }}` as
  `ocu-banner ocu-banner-restrained` — a banner, not an alert, because the user caused it.
- `ui/src/app/app.ts` — render `<app-account-menu />` inside the `@if (signedIn)` branch, above
  `<router-outlet />`. Leave line `:34` exactly as it is; `build-output.test.mjs:195-226` reads it.
- `ui/src/styles/_components.scss` — add the account-menu rules (trigger, panel, item, hover, focus ring via
  the existing mixin) from existing tokens. Add no colour token.

**Execution — tests:**

- `ui/tools/session.test.mjs` — add `signed-out` to the state lists at `:566`, `:580`, `:596` and `:854`,
  and change `:549` and `:753` to expect `'signed-out'` instead of `'form'`. Add: the local half completes
  when the logout throws; when it answers 401;
  and when it never settles (a `fetch` returning a promise that is not resolved). Add: a backoff probe
  scheduled before sign-out lands after it and adopts nothing.
- `ui/tools/api.test.mjs` — no edit. Its `:382-395` scan walks `ui/src` wholesale, so the new component is
  covered the moment it exists; confirm it stays green rather than adding an expectation.
- `src/OcuPilot/Test/Token.cls` — add `TestLogoutWithTheCookieEndsTheBrowserLevelLogin`: mint with a JSON
  body, assert the cookie mints silently at `/api/ocupilot/login` **and** at `/api/interop-editors/login`
  (both 200, the guard that makes the "after" meaningful), log out with Bearer **and** cookie, then assert
  both answer 401. Add `TestABearerOnlyLogoutLeavesTheBrowserLevelLoginIntact`: the same shape with no cookie
  on the logout — 200, and the cookie still mints. Neither asserts anything about `/csp/sys` rendering a
  form. Correct the `:215-220` doc comment at the same time: `/api/interop-editors` is the second
  JWT-enabled application in the group, so the crossing is observed rather than inferred.

**Acceptance Criteria:**

- Given a signed-in tab, when the user chooses Sign out from the account menu, then one `POST /logout` goes
  out carrying `Authorization: Bearer <access>` and `credentials: 'include'`, and the same browser-level
  cookie afterwards mints on neither `/api/ocupilot/login` nor `/api/interop-editors/login`.
- Given sign-out has completed, when the user lands, then the tab holds no pair, the renewal is disarmed, the
  state is `signed-out`, and the form shows `authSignedOut` — not `authSessionEnded`, which belongs to a
  session the user did not end.
- **Integration AC** — given the session is `signed-in`, when `app.ts` renders, then `app-account-menu` is on
  screen and `app-sign-in` is not; and choosing its Sign out item drives the session to `signed-out`, at
  which point `app-sign-in` renders `authSignedOut` and the routed outlet is withheld.
- Given the user was signed out elsewhere — `?IRISLogout=end`, or another JWT application revoking this
  `sid` — when OcuPilot's next call 401s, then one refresh and then one silent probe run, landing on
  `signed-in` invisibly if the browser-level login still mints and on `session-ended` if it does not.
- **DW-5** — given the logout call throws, answers a non-2xx, or never settles, when sign-out runs, then the
  tab is already cleared and `signed-out`, and no outcome of that request changes it.
- Given a refresh or backoff chain in flight when sign-out happens, when it lands afterwards, then it adopts
  no pair and the state stays `signed-out`.
- Given the whole story, when `ui/tools/strings.test.mjs` runs, then the key count is still 107 and
  EXPERIENCE.md's Fixed strings table is unchanged.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs (Rule 6).** AD-28 (sign-out is `POST /api/ocupilot/logout` carrying both the Bearer and the
cookie — this story's spine, and now verified rather than assumed), AD-47 (per-tab storage, no cross-tab
broadcast — sign-out clears one tab and the instance ends the rest), AD-20 (absolute API paths through the
one service), AD-19 (zoneless, `OnPush`, signals), AD-21 (gates resolve the authenticated user; unchanged
here), AD-35 (no credential in a log, a status or an assertion description), AD-12/AD-39 (one envelope — the
token endpoints are the CSP server's and emit none, which is why nothing here reads one), AD-31 (sign-out
abandons the user's running turns — no turn exists before Epic 7, so that half lands with the turn job),
AD-37 (invalidating sessions is the lifecycle rule this implements for the user's own session).

**Decision (overnight) — verified live, so the story has no server half.** Probed on `ocupilot-iris`
2026-09-12 with a self-minted throwaway session for `_SYSTEM` (own cookie jar, never the owner's browser
session, ended in teardown): logout with Bearer **and** cookie answers 200 and deletes both
`^%cspSession(-3,"%iscmgtportal:<browserId>")` and `^%cspSession(-4,<cookie>)`, after which the same cookie
is refused (401) by `/api/ocupilot/login` and by `/api/interop-editors/login`. Bearer-only answers 200 and
leaves both intact; cookie-only answers 401. AD-28 is correct as written and `Session.signOut()` already
sends the right request — no OcuPilot route, and `%CSP.Session.Logout(1)` (the vendor editors' own path) is
not needed.

**Decision (overnight) — "the vendor's editors" means their API.** `/ui/interop` is in the group with
`JWTAuthEnabled=false` and mints nothing; `/api/interop-editors` is JWT-enabled in the same group, so it is
what the cross-application claim is observable against.

**Decision (overnight) — the account menu is this story's component, and 1.10 moves it.** The AC places Sign
out in the status bar's account menu (EXPERIENCE.md `:79`, `:317`) and 1.10 owns the band. Building the menu
here and mounting it in `app.ts` keeps the AC observable now and leaves 1.10 a component to place rather than
a feature to invent — the split 1.6 made for its status line. `focus-ring.on-chrome` arrives with the band;
on today's surface the existing `ocu-focus-ring` mixin is the correct ring.

**Decision (overnight) — the local half runs first.** DW-5's evidence is "tokens remain in the tab on a
shared machine after apparent sign-out". Clearing before the request covers a throw, a non-2xx and a hang by
one ordering, where a `catch` covers only the throw. The `signOutGeneration` guard closes the other half: a
backoff chain already in flight could otherwise re-mint from a cookie a failed logout left alive.

**Decision (overnight) — sign-out preserves the route, by doing nothing to it.** `app.ts` withholds the
outlet instead of redirecting (`:14-17`), so the address survives every non-signed-in state; a redirect for
this one state would contradict that design and reach into navigation 1.9 and 1.10 own.

**Consumes:** 1.2 (`strings.ts`, the token and type layers), 1.5 (`/api/ocupilot` with its JWT and
`GroupById` settings, `Test.Http.AbsoluteRequest`), 1.6 (`TokenStore`, `Session`, `ApiService`, `sign-in.ts`,
`app.ts`'s gate, `Test.Token`'s throwaway-principal pattern and `PostToken` helper).

**Consumed-by:** 1.8 — the no-privileges notice's sign-out link (EXPERIENCE.md `:428`, DESIGN.md `:1066`)
calls the same `signOut()`; 1.10 — mounts `app-account-menu` into the real status-bar band and adds the
command-box "Sign out" alias; 1.13 — the connectivity probe shares the classifier the sign-out path leaves
untouched; Epic 7 — the turn job's abandonment on sign-out (AD-31).

**Ledger inbox.** DW-5 is addressed by the two DW-5 matrix rows, the ordering task on `session.ts`, and the
DW-5 acceptance criterion.

## Verification

**Environments.** The live `ocupilot` container (web 52774, SuperServer 1973) must **not** be recreated — no
`docker compose up`/`down`/`restart` against this repository's compose file. Every check in this story is
read-only or idempotent and runs against it through the IRIS MCP tools with **`server: "ocupilot-iris"`** on
every call; the `%UnitTest` classes create and remove only their own throwaway principal. Nothing here is
destructive or install-path, so **no throwaway container is required**; if one becomes necessary it is a
separate scratch compose project with its own project name, container name, host ports (never 52774/1973)
and scratch volume, per `README.md` § "Verifying the start path against a throwaway container", torn down
with `down -v`. No real account is created, modified, locked or expired, and **no real user's live session is
revoked** — every session this story ends is one its own test minted seconds earlier.

**One test class per tool call.** Send **one** `iris_execute_tests` call per message, wait for it to land in
`%UnitTest_Result`, and never re-submit on a client-side timeout — a returned call is not a finished run, and
these classes share one instance.

**Commands:**

- `npm --prefix ui test` — expected: green, `strings.test.mjs` still at 107 keys.
- `npm --prefix ui run build` — expected: exit 0, `initial` under the 1MB budget error (`ui/angular.json:38-44`).
- `uv run scripts/check-objectscript.py` — expected: no findings.
- `bash scripts/lint-docs.sh` — expected: clean.
- `iris_doc_load` + `iris_doc_compile` on `src/OcuPilot/` (`server: "ocupilot-iris"`) — expected: clean
  compile of `Test/Token.cls`.
- `iris_execute_tests` on `OcuPilot.Test.Token` — **one class per message**. Expected: green, including the
  two new methods and the unchanged `TestLogoutIsPerSidAndLeavesASiblingLive`.

**Pinning tests (Rule 19) — one per acceptance criterion:**

- Sign-out carries both credentials and ends the browser-level login →
  `OcuPilot.Test.Token.TestLogoutWithTheCookieEndsTheBrowserLevelLogin`, plus
  `ui/tools/session.test.mjs` "sign-out carries the Bearer and the cookie, and clears the tab".
  `mutation: _(implement stage)_`
- Bearer alone is not enough → `OcuPilot.Test.Token.TestABearerOnlyLogoutLeavesTheBrowserLevelLoginIntact`.
  `mutation: _(implement stage)_`
- The tab clears and the form shows `authSignedOut` → `ui/tools/session.test.mjs`, the state/message mapping
  test extended with `signed-out`. `mutation: _(implement stage)_`
- Integration AC (`app.ts` renders the menu only while signed-in; its item drives the session to
  `signed-out`) → `ui/tools/session.test.mjs`, the `app.ts` template read extended to the menu, plus
  `npm --prefix ui run build` type-checking the template under `strictTemplates`.
  `mutation: _(implement stage)_`
- Signed out elsewhere → `ui/tools/session.test.mjs:401` ("a failed refresh runs the silent probe once more,
  and on 200 the user sees nothing") and `:425` ("a failed refresh whose silent retry is also refused ends
  the session, with the route preserved") — both already green; this story names them as this AC's pins.
  `mutation: _(implement stage)_`
- DW-5 → `ui/tools/session.test.mjs`, the three logout-outcome tests (throw, 401, never settles).
  `mutation: _(implement stage)_`
- A stale chain cannot re-mint → `ui/tools/session.test.mjs`, the backoff probe scheduled before sign-out.
  `mutation: _(implement stage)_`

Whoever adds or materially changes a pinning test writes its `mutation:` line in the same pass: name the
smallest change that violates the AC, apply it, observe red, revert, and confirm `git status --short` and
`git diff --stat` are unchanged.

**Manual checks:**

- In desktop Chrome against the live instance at `http://localhost:52774/ocupilot/`: sign in, open the
  account menu with the keyboard, confirm Escape closes it and returns focus to the trigger, choose Sign out.
  Expect the form with "You're signed out.", `sessionStorage` empty, and a reload that shows the form again
  rather than signing straight back in — the browser-level cookie is what would otherwise do so, and ending
  it is the point of the story.
- With the classic portal open in a second tab, sign out of OcuPilot and record what `/csp/sys` does on its
  next interaction. Record the observation; assert nothing about it — `/csp/sys` also permits unauthenticated
  access, so it may keep rendering.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
