---
title: 'Story 1.7: Sign-out'
type: 'feature'
created: '2026-09-11'
status: 'done'
baseline_revision: '8299f4c5ae7048847363cf5d73fb6481619b772e'
baseline_commit: '8299f4c5ae7048847363cf5d73fb6481619b772e'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-1-6-silent-first-sign-in.md'
  - '{project-root}/.claude/rules/objectscript-testing.md'
warnings: ['oversized']
deferred:
  - summary: >-
      AD-28's Rule says "Bearer alone leaves the browser-level login intact". Measured, that
      holds only for a superseded session: the cookie resolves to the most recently minted
      session in the group, and a Bearer-only logout of that one ends the browser-level login.
    evidence: |-
      Demonstrated by mutation at implement on ocupilot-iris 2026-09-12: removing the
      interposed silent mint from TestABearerOnlyLogoutLeavesTheBrowserLevelLoginIntact makes
      "the cookie still mints" go red. The design conclusion is unchanged and better founded —
      a tab cannot know whether another tab has minted since — so this is a wording amendment
      to the spine's AD-28, which Rule 5 forbids this stage from making.
    location: >-
      ARCHITECTURE-SPINE.md AD-28 (Rule, final sentence); this spec's Boundaries and "Bearer
      only" matrix row restate it
    severity: medium
  - summary: >-
      A refresh STARTED after sign-out finds no pair, falls through retryProbeThenEnd() to
      probeAndSettle(), and could re-mint from a browser-level login a failed logout left alive.
    evidence: |-
      signOutGeneration guards chains started BEFORE sign-out, which is what this story's task
      specifies, and runRefresh() returns retryProbeThenEnd() before its guard is consulted.
      Unreachable today: ApiService.request() has no production call site, so nothing calls
      refresh() outside the renewal timer, which signOut() disarms. It becomes reachable with
      Story 1.8's first data call.
    location: >-
      ui/src/app/core/session.ts (runRefresh, retryProbeThenEnd, probeAndSettle)
    severity: medium
  - summary: >-
      account-menu.ts has no executed component test host, so its open/close behavior and the
      effect-driven focus move to the first item are pinned only by source reads.
    evidence: |-
      Same gap already ledgered as DW-93 for sign-in.ts; Story 1.9 is named as the owner of the
      component runner. This is an occurrence of that root cause, not a new one — every
      assertion over account-menu.ts is a source read whose removal type-checks and builds.
    location: >-
      ui/src/app/shell/account-menu.ts; ui/tools/session.test.mjs (the account-menu source reads)
    severity: medium
  - summary: >-
      The spec's two manual browser checks were not performed, so the keyboard path and the
      post-sign-out reload were not observed in a real browser.
    evidence: |-
      Both need this bundle installed into the owner's live container, and the sign-out check
      ends a browser-level %ISCMgtPortal login while the owner has a live _SYSTEM browser
      session open — which the run's standing prohibition forbids ("never end a session you did
      not create"). The wire half of the same claim is covered automatically by
      TestLogoutWithTheCookieEndsTheBrowserLevelLogin.
    location: >-
      this spec's Verification -> Manual checks
    severity: medium
  - summary: >-
      Sign-out leaves focus on document.body. The account menu unmounts with the focused menu
      item inside it, and nothing gives the sign-in form a named focus destination.
    evidence: |-
      EXPERIENCE.md :581 — "No control is disabled or removed while it holds focus without a
      named destination." chooseSignOut() closes the panel and signOut() drives app.ts to
      withhold the branch, so the item and its host both go in the same change-detection pass;
      focusing the trigger first (as closeAndRefocus does) would not help, since the trigger is
      removed too. The destination has to be in sign-in.ts, which has no component test host
      until Story 1.9 (DW-93), so the fix cannot be verified in this story.
    location: >-
      ui/src/app/shell/account-menu.ts (chooseSignOut); ui/src/app/shell/sign-in.ts
    severity: medium
  - summary: >-
      The signed-out banner is not announced to assistive technology, so a screen-reader user
      who chooses Sign out gets no confirmation.
    evidence: |-
      EXPERIENCE.md :582 enumerates the polite role="status" messages and the role="alert" ones;
      the signed-out banner is in neither list, and neither is the session-ended banner that
      shipped with Story 1.6 — so adding role="status" here would deviate from a closed UX
      enumeration and split the two banners' treatment. It is a UX call for the owner, not an
      implementation choice, and it should settle both banners together.
    location: >-
      ui/src/app/shell/sign-in.ts (the authSignedOut and authSessionEnded banners)
    severity: medium
  - summary: >-
      The account menu stays open when the user clicks or tabs outside it, with
      aria-expanded="true" and Escape no longer reachable.
    evidence: |-
      It closes only on Escape (bound on the wrapper div), a second trigger click, and choosing
      the item. EXPERIENCE.md :532 and this spec name only Escape, so this is inside the letter
      of the intent; a focusout/outside-click handler is new branching that no executed test
      could cover before Story 1.9's runner, and Story 1.10 re-homes the component into the
      status bar where the dismissal model is settled for the whole band.
    location: >-
      ui/src/app/shell/account-menu.ts
    severity: medium
  - summary: >-
      `id="ocu-account-trigger"` is a document-global constant, so a second instance of the
      component breaks the panel's aria-labelledby.
    evidence: |-
      Harmless today — app.ts mounts exactly one — and it bites the moment Story 1.10 mounts
      the component into the status-bar band while the interim mount still exists, or if the
      menu is ever reused. A per-instance id generated in the component settles it.
    location: >-
      ui/src/app/shell/account-menu.ts (trigger id, panel aria-labelledby)
    severity: low
  - summary: >-
      `src/OcuPilot/Test/Token.cls` is now 686 lines, past the roughly-500-line guidance for a
      %UnitTest class.
    evidence: |-
      .claude/rules/objectscript-testing.md — "Keep a test class to roughly 500 lines; split
      larger suites into several classes", and the same file mandates per-class runs, which a
      smaller class makes cheaper. The four logout methods plus PostTokenTo/LogoutAt/BrowserCookie
      would move cleanly; splitting mid-review risks the shared OnBeforeAllTests fixture, which
      is exactly the race that rule warns about.
    location: >-
      src/OcuPilot/Test/Token.cls
    severity: low
  - summary: >-
      `ui/tools/strings.test.mjs` locates EXPERIENCE.md's Fixed strings table by the hardcoded
      line range 252..302, so any insertion above line 252 silently shifts what it reads.
    evidence: |-
      strings.test.mjs:47. The range is now cited in two documents and one source file as a
      reason not to add a table row — a test limitation quoted as if it were a product
      constraint. Locating the table by its heading would remove it. Out of this story's
      footprint: the extractor is Story 1.2's.
    location: >-
      ui/tools/strings.test.mjs:47
    severity: medium
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
- Every user-facing word from `ui/src/app/core/strings.ts`; every color an existing `--ocu-*` token; the
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
  `:130-131`, `:256-275`; no color literal outside `_tokens.scss` `:80-107`.
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
  `aria-haspopup="menu"` and a bound `[attr.aria-expanded]`; a `role="menu"` panel labeled by the
  trigger's id (no new string), holding one `role="menuitem"` button
  reading `{{ STRINGS.actionSignOut }}` that calls `session.signOut()`. Escape closes and returns focus to
  the trigger (EXPERIENCE.md `:532`); the open flag is a paren-free getter. No literal text node anywhere.
- `ui/src/app/shell/sign-in.ts` — add a fourth status block: a `signedOut` getter over
  `sessionMessageKey(...) === 'authSignedOut'` rendering `{{ STRINGS.authSignedOut }}` as
  `ocu-banner ocu-banner-restrained` — a banner, not an alert, because the user caused it.
- `ui/src/app/app.ts` — render `<app-account-menu />` inside the `@if (signedIn)` branch, above
  `<router-outlet />`. Leave line `:34` exactly as it is; `build-output.test.mjs:195-226` reads it.
- `ui/src/styles/_components.scss` — add the account-menu rules (trigger, panel, item, hover, focus ring via
  the existing mixin) from existing tokens. Add no color token.

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

### Review Findings

**2026-09-12 — code review (first review, four layers at the `full-opus` tier).** 36 raw findings
across the four layers grouped to 12 root-cause entries: high 0, medium 4, low 8, 12 rejected.
No high. Every medium was patched in-pass, so nothing re-opens the story. The seven patches add
four tests: `npm --prefix ui test` is now **203/203**, superseding the `## Auto Run Result`'s 199.
`npm --prefix ui run build` exit 0 (initial 256.01 kB), `check-objectscript` 0,
`bash scripts/lint-docs.sh` clean, and `OcuPilot.Test.Token` 12/12 confirmed against
`%UnitTest_Result` at run index 757, with no throwaway principal left on the instance.

- [x] [Review][Patch] `signOut()` left `currentUserName` set, so the sign-in form it lands on
  pre-filled the previous user's name on a shared machine [ui/src/app/core/session.ts:443] —
  EXPERIENCE.md's keep-the-name rule is scoped to a rejected *attempt* inside one sign-in, not to a
  sign-out, and state 8 says "tab storage cleared". All four layers raised it. It was also the one
  `[defer]` verdict of the implement pass that reached neither the spec's `deferred:` block nor the
  ledger (the `## Auto Run Result`'s "12 collapse to 10" arithmetic conceals the drop: 12 defers less
  4 self-declared duplicates is 8 unique, and only 8 of the 10 `deferred:` entries are review's).
  Fixed and pinned instead of re-filed.
- [x] [Review][Patch] The account menu's one opening affordance was pinned by nothing
  [ui/src/app/shell/account-menu.ts:59] — deleting `(click)="toggle()"` type-checked, built clean
  and left the whole suite green with Sign out unreachable and the story's Intent undelivered. The
  focus `effect()` and `#firstItem` were in the same position. Added an executed source-read pin for
  all three.
- [x] [Review][Patch] The signed-out banner's *reachability* was unpinned
  [ui/src/app/shell/sign-in.ts:126] — the two existing assertions match the banner wherever it sits,
  so nesting `@if (signedOut)` inside `@if (rejected)` (conditions that can never both hold) left
  them green while AC 2's confirmation never rendered. Added a brace-counted assertion that the four
  status conditions are siblings at the slot's own level.
- [x] [Review][Patch] `Token.cls` carried the claim AD-28 was corrected away from
  [src/OcuPilot/Test/Token.cls:677] — `LogoutAt()`'s doc comment stated "must leave the browser-level
  login alone" as the helper's contract, which the corrected AD-28 says is true only of a superseded
  session. Separately, the credentialled-logout method cited
  `TestLogoutIsPerSidAndLeavesASiblingLive` as the contrast case; that test performs a *Bearer-only*
  logout over two independently password-minted sessions and cannot support a claim about a
  credentialled one. Both corrected by replacing the wrong sentence.
- [x] [Review][Patch] DW-110 — `strings.test.mjs` located EXPERIENCE.md's Fixed strings table by the
  hardcoded range `252..302` [ui/tools/strings.test.mjs:47]. Now located by the `**Fixed strings**`
  paragraph and the `| String | Where |` header row. Demonstrated both ways: with one line inserted
  above the table the old extractor goes red and the new one stays green. The three source files that
  quoted the range as a reason not to add a table row no longer do.
- [x] [Review][Patch] `signOutGeneration`'s doc comment claimed every chain that can adopt a pair
  captures it [ui/src/app/core/session.ts:223] — `formLogin()` adopts and is not guarded. The guard
  would be dead code (the form and the menu are mutually exclusive surfaces), so the claim was
  narrowed to what the code does and why `formLogin` is exempt.
- [x] [Review][Patch] The `access === ''` early return in `signOut()` was unpinned
  [ui/src/app/core/session.ts:444] — deleting it sent `Authorization: Bearer ` with no token and left
  the suite green. Pinned.
- [x] [Review][Defer] The logout POST sets no `keepalive`, so a document unload before the request
  bytes leave the client loses the logout and the browser-level login survives
  [ui/src/app/core/session.ts:445] — deferred: DW-114, `wontfix-accepted`. The request is dispatched
  synchronously inside `chooseSignOut()` on a warm connection, before any human action; adding
  `keepalive` means changing the one request the story rests on with no browser-executed test to
  falsify it.
- [x] [Review][Defer] `role="menu"` / `role="menuitem"` ship without the arrow, Home/End or roving
  `tabindex` model those roles imply [ui/src/app/shell/account-menu.ts:65] — deferred: DW-115,
  `wontfix-accepted`. With one item there is nowhere to arrow to and the item already holds focus;
  EXPERIENCE.md's Interaction Primitives defines no menu model to build against.
- [x] [Review][Defer] The three new wire tests discard about a dozen further `%Status` values, so a
  transport failure reads as "expected 200, got 0" [src/OcuPilot/Test/Token.cls] — deferred: DW-116,
  `wontfix-accepted`. Diagnostics only, and the diff takes the file from roughly 15 such call sites
  to 27, which is past a fix-pack item.
- [x] [Review][Defer] The "most recently minted session" mechanism and AD-28's "any sibling JWT
  application" are asserted flatly in six places from a two-application probe, without the
  `(inference)` label CLAUDE.md requires at each document boundary
  [ARCHITECTURE-SPINE.md:352] — deferred: DW-117, `wontfix-accepted`. The conclusion is
  mechanism-backed (the credentialled logout deletes the group node) and unchanged; only the
  epistemic labeling is short, and the spine is the lead's under Rule 20.
- [x] [Review][Defer] The sign-out focus-destination defer was appended as a bare `occurrence` on
  DW-103, whose body describes a different mechanism [deferred-work.md:634] — deferred: a note
  trailer was appended to DW-103 preserving its status and owner, so Story 1.10 inherits the
  distinguishing fact (sign-out unmounts the item *and* the trigger in one pass, so the destination
  has to be built in `sign-in.ts`).

**Rejected.**

- `[false]` The implementation violates a governing AD — it does not. The acceptance auditor checked
  all seven ACs, the eight matrix rows and the ten ADs against the working tree and found the
  implementation matching every one; every finding above is a claim, tracking or falsifiability
  defect, not a behavioural one.
- `[low]` The spec's Boundaries and "Bearer only" matrix row still state the unqualified Bearer-only
  claim that AD-28 was corrected away from — the fix edits the spec under review, both lines sit
  inside the frozen `<intent-contract>`, and `deferred:` #1 in this same frontmatter already records
  the correction and names those two locations. The spine, which is the contract, is correct.
- `[low]` A reload after a *failed* logout re-mints silently from the surviving cookie — by design:
  that is exactly AD-28's silent-first sign-in, and the proposed persistent signed-out marker would
  contradict it and add per-tab storage AD-47 does not sanction.
- `[low]` Opening the menu with the mouse moves focus to the item, whose only highlight is
  `:focus-visible` — one hover-styled item; the fix adds a keyboard-versus-pointer branch for a case
  not met in everyday use.
- `[low]` AC 7 states "the key count is still 107" and no test asserts that number — the fix either
  edits the AC (spec under review) or hardcodes 107, which would go red on every legitimate string
  added later. The pinned claim, "the table plus exactly three named extras", is the durable one.
- `[low]` `TestAJsonLoginMintsAPairAndItsCookieMintsSilently` parses the `Set-Cookie` header twice
  after the `BrowserCookie()` refactor — duplication in test code with no behavioural harm;
  refactoring an ObjectScript test mid-review risks the shared `OnBeforeAllTests` fixture, which is
  the race `.claude/rules/objectscript-testing.md` warns about.
- `[low]` `SIBLINGAPIPATH`'s comment omits that `/api/interop-editors` carries a `MatchRoles` grant —
  true, and it changes nothing: the test modifies no application and the session is ended in
  teardown. A prose addition with no named harm.
- `[low]` `.ocu-account-name` is emitted but styled nowhere — a layout hook; removing it changes the
  DOM Story 1.10 is being handed for the status-bar band.
- `[low]` DW-112 and `deferred:` #9 say `Token.cls` is 686 lines; it is 687 — the ledger body is
  written once and append-only, and the entry's point (past the ~500-line guidance) stands either
  way.
- `[low]` The state list in `session.test.mjs` is three hand-maintained arrays — the fix exports a
  runtime `SESSION_STATES`, new public surface on `session.ts` for a developer-only drift risk.
- `[low]` AD-28's amendment is roughly 110 words replacing a 13-word clause, against CLAUDE.md's
  prose discipline — a spine edit, and the spine is the lead's under Rule 20.
- `[low]` `TestABearerOnlyLogoutLeavesTheBrowserLevelLoginIntact`'s *name* carries the unqualified
  claim its doc comment then narrows — renaming reaches this spec's `## Verification` and
  `## Auto Run Result`, which this stage may not edit.
- `[low]` `lint-docs.sh` covers 18 files and none under `_bmad-output/implementation-artifacts/`, and
  the cycle log's lint note is not reproducible from the committed tree — project tooling out of this
  story's footprint, and the cycle log is not this stage's to edit.

## Spec Change Log

**Decision (overnight) — AD-28's Bearer-only clause is narrower than it reads; the implementation is
unchanged.** Measured and re-demonstrated by mutation: the cookie resolves to the most recently minted
session in the group, so a Bearer-only logout ends the browser-level login from the tab holding that
session and leaves it alive from any other. A tab cannot know which it is, so both credentials are still
required. Amending AD-28's wording is the lead's (Rule 5) and is filed under `deferred:`.

**Decision (overnight) — the matrix's cookie-only row needed a test, and got one.** The Matrix Test Audit
found no `/logout` in the suite carrying a cookie and no Bearer. Added
`OcuPilot.Test.Token.TestACookieOnlyLogoutIsRefused`.

**Decision (overnight) — sign-out does reach the user's other OcuPilot tabs, and that is now pinned.**
Review asked whether a credentialled logout leaves sibling tabs signed in. Probed on `ocupilot-iris`:
a sid minted from the same browser-level cookie answers **401** afterwards, so it dies with the login,
while a sid from its own password login survives (`TestLogoutIsPerSidAndLeavesASiblingLive`). That is
EXPERIENCE.md `:497`'s "classic portal and embedded editors signed out too", and the assertion is now
part of `TestLogoutWithTheCookieEndsTheBrowserLevelLogin` rather than an open question.

## Review Triage Log

### 2026-09-12 — Review pass

- verdicts: 32 findings — high 0, medium 17, low 9, false 6, maybe-false 0
- findings:
  - `[false]` `[reject]` A credentialled sign-out leaves other OcuPilot tabs signed in — probed on the instance: a sid minted from the same browser-level cookie answers 401 after the credentialled logout, so it dies with the login. Now pinned by a permanent assertion in `TestLogoutWithTheCookieEndsTheBrowserLevelLogin`.
  - `[medium]` `[defer]` `chooseSignOut()` removes the focused control with no named destination (EXPERIENCE.md `:581`) — real; the destination belongs in `sign-in.ts`, which has no test host until 1.9.
  - `[medium]` `[defer]` The signed-out banner is never announced — real, but EXPERIENCE.md `:582`'s `role="status"` list is a closed enumeration that excludes it and the session-ended banner alike; a UX call that should settle both.
  - `[medium]` `[defer]` The account menu never dismisses on outside click or focus loss — real; only Escape is specified, and 1.10 re-homes the component.
  - `[low]` `[defer]` `id="ocu-account-trigger"` is a document-global constant — harmless at one instance, bites when 1.10 mounts a second.
  - `[medium]` `[patch]` Nothing pinned that the trigger renders `{{ userName() }}` — confirmed: deleting the span left the suite green and the button with no accessible name. Added the assertion; demonstrated red.
  - `[medium]` `[patch]` `installAttempts = 0` in `signOut()` untested — confirmed: deleting it kept all 197 green. Added a backoff-reset test; demonstrated red.
  - `[false]` `[reject]` `signOut()` issues no logout when the tab holds no pair — there is nothing a request could do: a cookie-only logout is refused 401, now pinned by `TestACookieOnlyLogoutIsRefused`. `signed-out` is the correct state for a tab holding no pair.
  - `[medium]` `[defer]` The `runRefresh()` re-mint hole is a one-line move inside this story's footprint — the hole is real (already `deferred:` #2) but the proposed fix is wrong: a refresh started after sign-out captures the post-sign-out generation, so moving the existing guard changes nothing. Unreachable until 1.8's first data call.
  - `[medium]` `[patch]` The two in-flight tests had no `mutation:` line — demonstrated both guards separately (probeAndSettle, runRefresh) and wrote them into `## Verification`.
  - `[medium]` `[patch]` `TestACookieOnlyLogoutIsRefused` missing from `## Verification`; "two new methods" stale — added the pinning entry with its demonstrated mutation; corrected to three.
  - `[false]` `[reject]` The spec's Boundaries and matrix row still carry the imprecise Bearer-only claim — both sit inside `<intent-contract>`, which this stage may not edit (step-03/04 rule); that is precisely why the amendment is deferred to the lead. The Change Log paragraph was trimmed.
  - `[false]` `[reject]` `## Auto Run Result` is stale — written at finalize, which is this pass's last step.
  - `[low]` `[reject]` `lint-docs.sh` does not lint this story's spec — true, but the file set is project tooling outside this story's footprint, and a LOW is not worth a burn-down slot (Rule 15).
  - `[low]` `[patch]` SCSS comments disagreed with each other and the code about the item insets — the code follows the house pattern for a fixed-height control (no global `border-box`); corrected both comments.
  - `[low]` `[defer]` `Token.cls` is past the ~500-line guidance — real; splitting mid-review risks the shared fixture.
  - `[medium]` `[patch]` The new ObjectScript tests overclaim their cleanup — early exits abandon a live sid; softened both sentences to state the green path and name `OnAfterAllTests` as the backstop.
  - `[low]` `[patch]` Comment mass running ahead of code — trimmed `signOut()`'s doc comment from 26 lines to 17, removing evidence already recorded in the Change Log.
  - `[medium]` `[defer]` `strings.test.mjs`'s hardcoded `252..302` range is a test limitation quoted as a product constraint — out of footprint (Story 1.2's extractor).
  - `[false]` `[reject]` formLogin in flight when `signOut()` runs reaches `adopt()` unguarded — the form renders only when not signed-in and the menu only when signed-in, so the interleaving is unreachable; `submitInFlight` self-clears in `runSubmit`'s `.finally`, so the leak half is wrong too.
  - `[medium]` `[defer]` Refresh started after sign-out can re-mint — duplicate of `deferred:` #2, kept.
  - `[medium]` `[defer]` Menu left open on outside click/focus loss — grouped with the dismissal entry above.
  - `[medium]` `[defer]` Sign-out chosen by keyboard drops focus to `<body>` — grouped with the focus-destination entry above.
  - `[medium]` `[defer]` `signOut()` does not clear `currentUserName`, so the form pre-fills the previous user's name on a shared machine — real and squarely in DW-5's scenario, but the spec's task list enumerates the local half and omits it, and EXPERIENCE.md `:424` keeps the name across a rejection. A product call, not an implementation one.
  - `[low]` `[reject]` `If tCookie = "" Quit` abandons a live sid — bounded: the sessions belong to the throwaway principal `OnAfterAllTests` deletes. The overclaiming comment was the substantive half and is patched above.
  - `[low]` `[reject]` A non-200 credentialled logout leaves the browser login live — only on an already-red run; adding recovery branching to a failing test is complexity for no user-reachable benefit.
  - `[low]` `[reject]` Transport failures read as "expected 200, got 0" because the `%Status` is discarded — diagnostics only, pre-existing pattern throughout the file; fixing it means asserting status at ~15 call sites.
  - `[medium]` `[patch]` The `signedOut` getter's comparison was pinned only by template text — confirmed: flipping it to `authSessionEnded` type-checked, built clean and left all 197 green. Added the gate assertion; demonstrated red.
  - `[medium]` `[defer]` `account-menu.ts` has no executed test host — duplicate of `deferred:` #3 (DW-93 / Story 1.9), kept.
  - `[low]` `[patch]` `assert.ok(pending instanceof Promise)` cannot fail on an `async` method — replaced with an assertion that the promise has not settled while the request is in flight; demonstrated red.
  - `[medium]` `[patch]` The 7th AC had no pinning bullet at all — added it naming the strings-table test, with a demonstrated mutation.
  - `[false]` `[reject]` Row 8's trigger cannot fire, so the row changes nothing — descriptive, not a defect; the ACs' pins are the two pre-existing refresh tests and the `ApiService` call site is 1.8's, already recorded in `deferred:` #2.

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
  three new methods and the unchanged `TestLogoutIsPerSidAndLeavesASiblingLive`.

**Pinning tests (Rule 19) — one per acceptance criterion:**

- Sign-out carries both credentials and ends the browser-level login →
  `OcuPilot.Test.Token.TestLogoutWithTheCookieEndsTheBrowserLevelLogin`, plus
  `ui/tools/session.test.mjs` "sign-out carries the Bearer and the cookie, and clears the tab".
  `mutation: removed credentials: 'include' from signOut()'s logout request -> "sign-out carries the Bearer and the cookie, and clears the tab" red; and, on the wire half, dropped the Cookie header from the credentialled logout -> TestLogoutWithTheCookieEndsTheBrowserLevelLogin red on both "after" assertions.`
- Bearer alone is not enough → `OcuPilot.Test.Token.TestABearerOnlyLogoutLeavesTheBrowserLevelLoginIntact`.
  `mutation: removed the interposed silent mint, so the Bearer names the cookie's current session -> TestABearerOnlyLogoutLeavesTheBrowserLevelLoginIntact red on "but the cookie still mints".`
- The tab clears and the form shows `authSignedOut` → `ui/tools/session.test.mjs`, the state/message mapping
  test extended with `signed-out`.
  `mutation: sessionMessageKey('signed-out') returned 'authSessionEnded' -> "each state selects the message its slot renders" red, and the sign-out test's message assertion with it.`
- Integration AC (`app.ts` renders the menu only while signed-in; its item drives the session to
  `signed-out`) → `ui/tools/session.test.mjs`, the `app.ts` template read extended to the menu, plus
  `npm --prefix ui run build` type-checking the template under `strictTemplates`.
  `mutation: moved <app-account-menu /> from the @if (signedIn) branch into the @else -> "Integration AC: app.ts withholds the routed outlet from every state but signed-in" red.`
- Signed out elsewhere → `ui/tools/session.test.mjs:401` ("a failed refresh runs the silent probe once more,
  and on 200 the user sees nothing") and `:425` ("a failed refresh whose silent retry is also refused ends
  the session, with the route preserved") — both already green; this story names them as this AC's pins.
  `mutation: a refused refresh settled 'session-ended' directly instead of running the silent probe -> :401 red; and, for the second pin, dropped refusalState = 'session-ended' from retryProbeThenEnd() -> :425 red.`
- DW-5 → `ui/tools/session.test.mjs`, the three logout-outcome tests (throw, 401, never settles).
  `mutation: moved the awaited logout POST back above the local half -> "the tab is already cleared and signed-out when the logout is issued" and "a logout that never settles does not hold the tab signed in" red. The throw and 401 tests stay green under it, which is the point: the ordering, not the catch, is what covers all three outcomes.`
- A stale chain cannot re-mint → `ui/tools/session.test.mjs`, three tests, one per chain that can adopt a
  pair: the backoff probe scheduled before sign-out, the probe already in flight, and the refresh already
  in flight. Each guard is separately falsifiable, so one mutation per guard.
  `mutation: deleted the signOutGeneration guard from enterInstalling()'s scheduled callback -> "a backoff probe armed before sign-out lands after it and adopts nothing" red; deleted it from probeAndSettle() -> "a probe already in flight when sign-out happens adopts nothing" red; deleted it from runRefresh() -> "a refresh already in flight when sign-out happens adopts nothing" red.`
- The string source does not grow → `ui/tools/strings.test.mjs` "the string source holds nothing the
  documents do not authorize — the table plus exactly three named extras".
  `mutation: added one key to strings.ts -> that test red, naming the unauthorized value.`
- Cookie only (I/O matrix row) → `OcuPilot.Test.Token.TestACookieOnlyLogoutIsRefused`.
  `mutation: sent the Bearer alongside the cookie -> the logout answers 200 and "a logout carrying the cookie alone is refused" red.`
- Sign-out ends the sibling tabs the same browser-level login minted (EXPERIENCE.md `:497`) →
  `OcuPilot.Test.Token.TestLogoutWithTheCookieEndsTheBrowserLevelLogin`, the assertion that the sid the
  cookie had minted is dead after the credentialled logout.
  `mutation: dropped the Cookie header from the logout -> that assertion red along with the two "after" ones; measured 401, so the credentialled logout does end sessions minted from the same cookie, which a Bearer-only logout does not (TestLogoutIsPerSidAndLeavesASiblingLive).`

**Added at code review (2026-09-12), each demonstrated red and reverted:**

- Sign-out clears the user name → `ui/tools/session.test.mjs` "sign-out clears the user name, so the
  form does not pre-fill the last user on a shared machine".
  `mutation: deleted this.currentUserName = '' from signOut() -> that test red; nothing else moved.`
- Sign-out issues no logout when the tab holds no pair → `ui/tools/session.test.mjs` "sign-out from a
  tab holding no pair settles locally and issues no logout".
  `mutation: deleted the if (access === '') return guard -> that test red.`
- The account menu can be opened at all → `ui/tools/session.test.mjs` "the trigger is what opens the
  menu, and opening moves focus into it".
  `mutation: deleted (click)="toggle()" from the trigger -> that test red; before it was added the
  same deletion left all 199 green with Sign out unreachable.`
- The signed-out banner is reachable in the state that sets it → `ui/tools/session.test.mjs` "each
  status block opens at the slot's own level, so none is unreachable behind another".
  `mutation: nested the @if (signedOut) block inside @if (rejected) -> that test red; the two
  pre-existing banner assertions stayed green under it, which is why it was needed.`
- The strings table is located by its heading, not by line number (DW-110) →
  `ui/tools/strings.test.mjs`, the existing completeness test.
  `mutation: inserted one blank line above the Fixed strings paragraph in EXPERIENCE.md -> red under
  the old 252..302 extractor, green under the heading-anchored one; EXPERIENCE.md reverted.`

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

Status: done
Blocking condition: none

**What was implemented.** Sign-out is now reachable and unconditional. `session.ts` gains a `signed-out`
state mapped to `authSignedOut`, and `signOut()` runs its local half **first** — capture the token, bump
`signOutGeneration`, disarm the renewal, clear the pair and the password, reset the backoff, settle the
state — then issues the POST carrying the Bearer and `credentials: 'include'` and reads no outcome of it.
`signOutGeneration` is captured on entry by all three chains that can adopt a pair (`probeAndSettle`,
`runRefresh`, `enterInstalling`'s armed callback), so none can sign the tab back in afterwards. A new
`app-account-menu` supplies the affordance and `app.ts` mounts it inside the signed-in branch only.

**Files changed.**

- `ui/src/app/core/session.ts` — the `signed-out` state, the message mapping, the reordered `signOut()`, and the three sign-out generation guards.
- `ui/src/app/shell/account-menu.ts` — *new*. The trigger, the one-item `role="menu"` panel, Escape handling.
- `ui/src/app/shell/sign-in.ts` — the fourth status block rendering `authSignedOut` as a restrained banner.
- `ui/src/app/app.ts` — mounts `app-account-menu` in the `@if (signedIn)` branch; line 34 untouched.
- `ui/src/styles/_components.scss` — the account-menu rules, from existing tokens only.
- `ui/tools/session.test.mjs` — the state lists, the sign-out expectations, and 13 new tests.
- `src/OcuPilot/Test/Token.cls` — `SIBLINGAPIPATH`, the `PostTokenTo`/`LogoutAt`/`BrowserCookie` helpers, three new wire tests, and the corrected `:215-220` doc comment.

**Review findings.** 32 findings across four layers — high 0, medium 17, low 9, false 6. Patched 10
(medium 7, low 3): the unpinned `signedOut` getter comparison, the unpinned trigger user name, the untested
`installAttempts` reset, the unfalsifiable `instanceof Promise` assertion, three missing or incomplete
`mutation:` entries, the overclaimed ObjectScript cleanup comments, the SCSS inset comments, and an
over-long doc comment. Deferred 12 findings, which collapse to 10 `deferred:` items after duplicates.
Rejected 10, each with its reason in the triage log — the sharpest being "a credentialled sign-out leaves
other OcuPilot tabs signed in", which a direct probe refuted (the sibling sid answers 401) and which is now
a permanent assertion rather than an open question.

**Verification.** `npm --prefix ui test` 199/199; `npm --prefix ui run build` exit 0, initial 255.99 kB
against the 1 MB budget, `client-lint: clean`; `uv run scripts/check-objectscript.py` 0 problems;
`bash scripts/lint-docs.sh` clean; `iris_doc_load` + compile of all 60 classes clean;
`iris_execute_tests` on `OcuPilot.Test.Token` 12/12, confirmed against `%UnitTest_Result` at run index 756
(12/12/0). Teardown verified: no `OcuPilotToken*` principal left on the instance. Every IRIS call carried
`server: "ocupilot-iris"`; one test class per message throughout; the live container was never recreated.
Seventeen mutations were applied, observed red and reverted by the stage agent itself — ten at implement
covering the seven acceptance criteria, seven at review covering the tests the review added or changed —
with the tree confirmed byte-identical after each.

**Follow-up review recommended: true.** The named unverified risk is the account menu's *runtime*
behavior. `account-menu.ts` has no executed component test host until Story 1.9 (DW-93), so its open/close
cycle, the `effect()` that moves focus to the first item, and the `(keydown.escape)` binding are pinned
only by source reads — assertions whose removal type-checks and builds clean. The spec's two manual browser
checks, which would have exercised exactly that path, were not performed: they require the bundle installed
into the owner's live container and would end a browser-level `%ISCMgtPortal` login while the owner holds a
live `_SYSTEM` session, which this run's standing prohibition forbids.

**Residual risks.** Focus lands on `document.body` after sign-out and the signed-out banner is not
announced (both deferred, both needing a UX call plus 1.9's runner); the menu does not dismiss on outside
click; a refresh *started* after sign-out could re-mint once Story 1.8 adds the first data call; and AD-28's
"Bearer alone leaves the browser-level login intact" needs the lead's amendment — measured, it holds only
for a superseded session.
