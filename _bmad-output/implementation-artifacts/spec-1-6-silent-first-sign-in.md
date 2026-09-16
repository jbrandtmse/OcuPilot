---
title: 'Story 1.6: Silent-first sign-in'
type: 'feature'
created: '2026-09-11'
status: 'done'
baseline_revision: '5d0ebfadcaac8fe2c45b4dfa0326a07f12b11f1f'
baseline_commit: '5d0ebfadcaac8fe2c45b4dfa0326a07f12b11f1f'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-1-5-the-static-shell-serves-the-spa-including-deep-links.md'
  - '{project-root}/.claude/rules/objectscript-basics.md'
  - '{project-root}/.claude/rules/objectscript-testing.md'
warnings: ['oversized']
deferred:
  - summary: >-
      The INSTALL.* classifier `isInstallInFlight` has no production call site: `ApiService`
      never reads an envelope code, so a 503 during install reaches the caller raw.
    evidence: |-
      grep over ui/src finds the only callers in ui/tools/session.test.mjs. Story 1.6 has no
      data call to wire it to — Api.Router's UrlMap is empty and only the CSP server's token
      endpoints are reachable. Story 1.8 adds the first route with a body and is named as the
      first consumer in this spec's Consumed-by list.
    location: >-
      ui/src/app/core/api.ts (request) and ui/src/app/core/session.ts (isInstallInFlight)
    severity: medium
  - summary: >-
      Two concurrent install-backoff probe chains are possible once a data call exists, each
      minting its own sid and the loser overwriting the winner's stored pair.
    evidence: |-
      `enterInstalling` increments and schedules unconditionally and is reached from
      probeAndSettle, formLogin and runRefresh. Unreachable in Story 1.6 — there is no data
      call, and the form is hidden while `installing`, so only one chain can exist. It becomes
      reachable with 1.8's first data call. A single in-flight flag on the backoff, plus a test
      that enters the state twice, settles it.
    location: >-
      ui/src/app/core/session.ts (enterInstalling, probeAndSettle)
    severity: medium
  - summary: >-
      A rejected sign-in loses keyboard focus: formLogin enters `probing`, the card unmounts,
      and the re-rendered form leaves focus on the document body.
    evidence: |-
      `role="alert"` announces the failure but restores nothing, so a keyboard or screen-reader
      user loses their place on every failed attempt. The trivial half — aria-describedby and
      aria-invalid on both fields — was patched in this pass. Restoring focus means either not
      entering `probing` on a form submit or an explicit focus call, both of which touch the
      state machine or the chrome Story 1.10 owns.
    location: >-
      ui/src/app/shell/sign-in.ts
    severity: medium
  - summary: >-
      The IRIS host port is now written in four files, and CLAUDE.md's mirror list names two.
    evidence: |-
      ui/proxy.conf.json and ui/tools/angular-json.test.mjs both carry http://localhost:52774,
      alongside docker-compose.yml and ocupilot.code-workspace. The test asserts the duplicate
      against itself, so a port change fails loudly rather than silently — but CLAUDE.md's
      "change it in both places" list is now stale. Fixing it edits an agent-context file,
      which the implement stage does not touch.
    location: >-
      CLAUDE.md (the ocupilot-iris profile section)
    severity: low
---

<intent-contract>

## Intent

**Problem:** Story 1.5 left `/api/ocupilot` password-authenticated with JWT at 60/900 s and joined to
`%ISCMgtPortal`, but nothing on the client speaks to it: `ui/src/app/` holds five files, no HTTP, no token,
no session. A user reaching `/ocupilot` gets a bare `<p>OcuPilot</p>` and no way in.

**Approach:** Build the client transport layer. A silent-first probe mints a token pair from the browser's
existing portal login; a form login is the fallback; the pair lives per tab and travels only as a Bearer
header; one API service owns a single-flight refresh. The **token endpoints need no server code** — verified,
`/login`, `/refresh`, `/logout` and `/revoke` are handled by the CSP server before OcuPilot's dispatch runs
(`irissys/%CSP/REST.cls:56-65`). The server half of this story is therefore small: disable CORS explicitly,
fix `Kernel.Utils.ReadRequestBody` (DW-24), give `Kernel.Utils` its first executed test host (DW-23), and pin
the token contract over the real wire.

## Boundaries & Constraints

**Always:**

- Only `Authorization: Bearer <access>` authorizes an API call (AD-28). Every API path is absolute from the
  origin root and the API service **refuses a relative path** (AD-20) — the deep-link fallback would answer
  one with `index.html`.
- Auth logic is **framework-free TypeScript under `ui/src/app/core/`**, with `fetch`, storage and `now()`
  injected. Verified 2026-09-11 on Node 26.8.1: `node --test` imports a `.ts` module from that folder
  directly (`ui/tools/entity-id.test.mjs:28` already does, green), so this story's logic gets executed,
  falsifiable coverage without a component runner. Type-stripping erases types only — no enums, no
  namespaces, no parameter properties, no decorators in those modules.
- Refresh is **single-flight** and a background concern of the API service; no screen or panel handles it.
- Every user-facing word comes from `ui/src/app/core/strings.ts`; every color from an existing
  `--ocu-*` token.
- Secrets and tokens are never logged, never written to a cookie, never placed in a URL, never posted into a
  frame (AD-35, AD-47).

**Never:**

- No readiness endpoint, no `/info` call, no version guard — 1.17 and 1.8 own those (AD-45).
- No header, rail, side bar or agent panel — 1.10 owns the chrome. This story renders only the two states
  sign-in needs: the signing-in skeleton and the form-login card.
- No new color token (`ui/tools/design-tokens.test.mjs:76` asserts the exact 64-role set).
- No client component test runner — DW-93 is owned by 1.9. No karma target
  (`ui/tools/angular-json.test.mjs:14` forbids it).
- No `New $ROLES` and no impersonation in tests; throwaway principals authenticate for real.
- No account on the live instance is created, modified, locked or expired except the story's own throwaway
  principals, removed in teardown.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Silent mint | `CSPBrowserId` cookie present; empty-body `POST /api/ocupilot/login` | 200; pair stored per tab; no form; requested route honored | No error expected |
| Cold browser | No cookie; same probe | 401, empty body, no `WWW-Authenticate` | Form login once; route preserved |
| Form accepted | JSON body `{"user","password"}` to `/login` | 200 pair; `Set-Cookie: CSPBrowserId=…; path=/` signs the browser into every `%ISCMgtPortal` app | No error expected |
| Form rejected | Wrong password | 401 | Keeps user name, clears password, renders `authSignInFailed` in `role="alert"` |
| Install in flight (DW-1) | `/login` answers 404 / 5xx / network failure, or any API call answers 503 with an `INSTALL.*` code | Stays in the signing-in presentation and re-probes with backoff | **Never** `authSignInFailed` — only a 401 from `/login` is a credential failure |
| Concurrent 401s (DW-4) | Three in-flight calls 401 at once | **One** refresh; the other two await it and retry with the new access token | A failed refresh resolves all waiters to the session-ended path, once |
| Refresh rotation | `POST /refresh`, `refresh_token` in the JSON body | 200 new pair; the **old access token and old refresh token are both dead** | Replaying either → 401 |
| Refresh as Bearer | Refresh token in `Authorization: Bearer`, no body | 401 — refused | Treated as a failed refresh |
| Refresh failed | 401 from `/refresh` | Silent probe runs **once more**; on 200 continue invisibly | On 401, form login with `authSessionEnded`, route preserved |
| Tab duplicated (DW-6) | `sessionStorage` copied; navigation type is not `reload`/`back_forward` | Stored pair and tab nonce discarded; a fresh nonce is stamped; the tab re-probes | No error expected |
| Relative API path | `api.request('api/ocupilot/x')` | Throws before any network call | AD-20; a relative path is a programming error, never a request |
| Body read fault (DW-24) | `%request.GetMimeData` absent and `%request.Content` throws | `ReadRequestBody` returns an **error** `%Status` naming the read stage | Previously returned `$$$OK` with an empty body |

</intent-contract>

## Code Map

**Extend, never duplicate.** Paths are `done` unless marked *new*. Line anchors verified 2026-09-11.

**Verified ground truth — the token endpoints are the CSP server's, not OcuPilot's.**
`irissys/%CSP/REST.cls:56-65` declares `TokenLoginEndpoint`/`TokenLogoutEndpoint`/`TokenRevokeEndpoint`/
`TokenRefreshEndpoint`; the response writer is `HandleTokenResponse` at `:425-454`, emitting exactly
`{access_token, refresh_token, sub, iat, exp}` (`:438-444`). The credential check lives in the deployed
kernel routine `%SYS.cspServer` and is unreadable. Probed live on `ocupilot-iris` (52774):

- `/login` accepts **`Authorization: Basic`** or a **JSON body `{"user":…,"password":…}`**. Form-encoded and
  query-string forms return 401. Field names are `user` and `password`, not `username`.
- Empty-body `POST /login` carrying only `CSPBrowserId` → **200 with a pair for the same user**; no cookie or
  a bogus one → 401. Cookie is `CSPBrowserId`, `path=/`, `HttpOnly`, `SameSite=Strict`, no `Secure` over
  HTTP (`irissys/%sySecurity.inc:1511`; group id built by `bldRunGroupId` at `:1510`). `path=/` is what
  shares it across the 25 `%ISCMgtPortal` applications, `/csp/sys` and the vendor editors included.
- Every 401 on this path is **byte-identical**: zero-length body, no `WWW-Authenticate`. Wrong password,
  unknown user, dead refresh token and no credentials are indistinguishable to a client.
- `/refresh` takes `refresh_token` in the body (JSON, form or query all work); as a Bearer it is refused.
  **A successful refresh invalidates the old access token as well as the old refresh token**, in place on
  the same `sid` — `%SYS.TokenAuth` holds one `AccessTokenHash`/`RefreshTokenHash` pair per row
  (`irissys/%SYS/TokenAuth.cls:10-24`). This is why DW-4 needs single-flight, not just retry-on-401.
- Two tabs hold two `sid`s concurrently; a silent login never revokes a sibling; `/logout` and `/revoke` are
  per-`sid`.
- **Expired password has no client-visible discriminator** on this path (see Design Notes).
- `iris_webapp_get` on `/api/ocupilot`: `AutheEnabled=32`, `JWTAuthEnabled=1`, `JWTAccessTokenTimeout=60`,
  `JWTRefreshTokenTimeout=900`, `GroupById=%ISCMgtPortal`, `MatchRoles=""`, `Resource=""`,
  `DispatchClass=OcuPilot.Api.Router`. Nothing here changes.

**Server.**

- `src/OcuPilot/Api/Router.cls` (218) — `Parameter UseSession = 0` :17; `ADMINRESOURCES` :30 (13 resources);
  **empty `UrlMap` :47-51** — unchanged by this story; `OnPreDispatch` :135-181 = install gate :140-155
  (503 on `INSTALL.INSTALLING`/`UPGRADEREQUIRED`/`FAILED`) → anonymous rejection :157-162 (`AUTH.ANONYMOUS`,
  an inline literal) → admin gate :164-168 (`AUTH.NOADMIN`) → `ns` :170-175. **`Parameter
  HandleCorsRequest` is not declared**, so it inherits `%CSP.REST`'s unspecified default
  (`irissys/%CSP/REST.cls:119`), under which a route's own `Cors="true"` would be honored (`:83`).
- `src/OcuPilot/Api/StaticHandler.cls` (414) — CSP built at :343; `connect-src 'self'` **already permits**
  same-origin fetch to `/api/ocupilot`, so the policy needs no change. `src/OcuPilot/Test/Static.cls`
  asserts that string **exactly**.
- `src/OcuPilot/Kernel/Utils.cls` (388) — `ReadRequestBody` :358-386: the inner `Catch` :368-370 binds **no**
  exception variable, sets `tStream=""`, and the argumentless `Quit` :372 exits the `Try` to `:385 Quit tSC`
  with `tSC` still `$$$OK` — **DW-24, confirmed verbatim**. `DecodeUtf8Stream` :241-270 (carryover via
  `IncompleteUtf8TailLength` :332-348, `UTF8CHUNKSIZE = 1000000` :34); `ApplyOutputCeiling` :187-204 with
  `SurrogateSafeCutLength` :213-223 (`OUTPUTCEILING = 32768` :28); `SanitizeError` :116-174, bracket scan
  :142-150. **DW-23 confirmed by four checks** (`##class(...)` calls, `..` self-calls, subclasses,
  `$classmethod` indirection, no `.inc`/`Include`): `SanitizeError`, `ApplyOutputCeiling` and
  `ReadRequestBody` have **zero** call sites; `DecodeUtf8Stream` has one, from `ReadRequestBody`.
- `src/OcuPilot/Test/Http.cls` (237) — `MakeRequest` :93 and `RawRequest` :147 carry a body but are nailed to
  `_SYSTEM`/`SYS` (:102-103, :153-154); `AbsoluteRequest` :193 takes a principal (`""` sends none) and
  returns response headers (`Merge pHeaders` :223) but **has no body parameter**. **No helper can set a raw
  `Authorization` header** — all three go through `%Net.HttpRequest`'s `Username`/`Password`, which emits
  Basic; `SetHeader` is called nowhere in the tree.
- `src/OcuPilot/Test/Wire.cls` (369) — the pattern to copy: crypto-random password **retained** in
  `Property PreparedPassword` :51 (generated :76), `EnsurePrincipal` :169-186, `EnsureFixtureApplication`
  :191-207, teardown :130-165 reporting leftovers through the returned `%Status` (not an assertion — the
  method frame is gone by `OnAfterAllTests`). Contrast `Test/State.cls:90`, whose password is discarded and
  which therefore cannot be driven over HTTP.
- `scripts/check-objectscript.py` — class name **≤ 29 chars** including package dots (:82); every declared
  method parameter `p`-prefixed except 13 framework callbacks (:121-137); bare `Write` only in
  `Api/Response.cls` and `Api/Error.cls` (:76-80); `New $ROLES` only in `Kernel/State/Base.cls` and
  `Test/State.cls` (:346-393); forbidden literals include `iris_` and `%Atelier` **in comments too**.

**Client.** `ui/src/app/` holds exactly five `.ts` files. **No HTTP, no token, no storage, no guard, no
interceptor exists** — verified against the file structure, not one grep; every match for `fetch`/`Bearer`/
`sessionStorage`/`token` in `ui/src` is a comment or a design-token identifier.

- `ui/src/main.ts` (15) — providers are exactly `provideZonelessChangeDetection()` and `provideRouter(routes)`.
  `provideHttpClient` is absent and `@angular/common/http` is imported nowhere.
- `ui/src/app/app.ts` (29) — `<p class="ocu-type-display">{{ STRINGS.productName }}</p><router-outlet />`.
  **`ui/tools/build-output.test.mjs:195-226` couples the suite to this template**: it needs an inline
  `template:` backtick block, a first `{{ STRINGS.<key> }}` whose value must appear in the emitted JS, and a
  first `class="…"` whose class has a rule in the **global** `styles-<hash>.css`. A component-scoped
  `styles:` array does not satisfy the CSS half.
- `ui/src/app/core/entity-id.ts` (41) + `ui/tools/entity-id.test.mjs` — **the pattern this story follows**:
  a framework-free `.ts` module in `core/`, `await import()`ed by a Node test (`:28`) and also imported by an
  Angular component.
- `ui/src/app/core/strings.ts` (265, **104 keys**) — `statusConnectionSigningIn` :78 ("Signing in…"),
  `statusConnectionSigningInAgain` :84, `statusConnectionConnected` :80, `statusConnectionRetrying` :82,
  `authSignInFailed` :216, `authPasswordExpired` :218, `authSessionEnded` :220, `authSignedOut` :222,
  `authNoAdminPrivileges` :54 all exist verbatim. **"Sign in", "User name" and "Password" do not.**
- `ui/tools/strings.test.mjs:44-57` — `extractFixedStringsTable` scans EXPERIENCE.md lines **252..302**, a
  hardcoded range; `:83` `REQUIRED_ALONGSIDE_TABLE` permits exactly three extras; `:93` asserts
  `keys === literals + 3`. Extending an **existing row** adds literals without shifting a line; adding a
  **new row** pushes a data row past 302 and silently breaks the converse test.
- `EXPERIENCE.md` — the canonical string owner (`:248`). Action-names row **`:262`** (omits "Sign in"),
  Form-login row **`:291`**. Behavior: `:424` silent-login-in-progress (shell chrome, content skeleton,
  status-bar "Signing in…"), `:425` form login, `:426` expired password, `:490-499` the Session state table,
  `:571` the silent retry before the form, `:582` `role="alert"` for the sign-in failure, `:348` skeletons
  are `aria-hidden` inside an `aria-busy` region and static under reduced motion.
  `DESIGN.md:1064` — the form-login card: 440px, `surface-container-lowest`, `rounded.lg`, elevation 3,
  `spacing.6` padding, the horizontal lockup at 40px, a `masked-secret-field` reveal toggle, "Sign in" as a
  full-width `button-primary`; `:1092-1094` and `:649-653` the skeleton spec.
- `ui/angular.json` (69) — `baseHref /ocupilot/` :19, `outputHashing all` :20, budgets `initial`
  500kB warn / **1MB error** :38-44, `inlineCritical: false`. The `serve` target :54-65 has
  **`configurations` only and no `options` block**; there is no `proxy.conf.json` anywhere in `ui/`.
  `ui/tools/angular-json.test.mjs:14-30` requires every builder to start `@angular/build:` and forbids the
  literals `webpack` and `@angular-devkit/build-angular` in the file; a `proxyConfig` key passes all five
  of its tests and **nothing pins it**.
- `ui/tools/client-lint.mjs` (348) — wired into `prebuild`/`prestart`, so a violation fails `npm test`
  through `build-output.test.mjs`. `no-literal-text-node` :246, `no-unsourced-interpolation` :229 (an
  interpolation passes only as exactly `STRINGS.<existing key>`, or if it contains no quoted literal),
  `no-literal-copy-attribute` :256 over `aria-label`/`title`/`placeholder`/`alt`. Color rule :80-107 exempts
  only `src/styles/_tokens.scss`.
- `ui/tools/typography.test.mjs` — tree-wide: no `font-weight: 700` :120, no size below 11px :139, no
  external host in any `url()`/`src=`/`<link>` :230.
- `ui/src/styles/` — `_tokens.scss` (64 roles), `_theme.scss` (`mat.theme` + 30 `--mat-sys-*` → `--ocu-*`
  re-points, so a Material form field themes itself), `_typography.scss`, `_metrics.scss`. **No component
  CSS exists**: no skeleton rule, no focus-ring rule, no card, no banner, no status-bar band.

## Tasks & Acceptance

**Execution — strings and UX source (do first; everything client-side depends on it):**

- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` — append `· "Sign in"` to
  the **existing** action-names row at `:262` and `· "User name" · "Password"` to the **existing** Form-login
  row at `:291`. Transcribe only; both are already named in `DESIGN.md:1064`. Extend rows **in place** — do
  not add a row, which would push a data row past the hardcoded `252..302` extractor range in
  `ui/tools/strings.test.mjs:47` and break the converse test with no other symptom.
- `ui/src/app/core/strings.ts` — add `actionSignIn`, `fieldUserName`, `fieldPassword` (104 → 107 keys).
  Values transcribed verbatim; non-ASCII as `\uXXXX` escapes.

**Execution — client core (framework-free TypeScript; no Angular import in any of these three):**

- `ui/src/app/core/token-store.ts` — *new*. Per-tab pair storage plus the DW-6 tab-identity check: stamp a
  `crypto.randomUUID()` nonce beside the pair in `sessionStorage`; on load adopt a stored pair **only** when
  this navigation continues the same tab (`PerformanceNavigationTiming.type` is `reload` or `back_forward`),
  otherwise clear the pair, stamp a fresh nonce and re-probe. Storage and the navigation-type reader are
  injected so the Node suite can drive both. Never writes `document.cookie`, `localStorage`, or a
  `BroadcastChannel`.
- `ui/src/app/core/session.ts` — *new*. The framework-free session state machine over the states
  EXPERIENCE.md `:490-499` names — `probing`, `signed-in`, `form`, `form-rejected`, `password-expired`,
  `session-ended`, `installing` — with `silentProbe()` (empty-body POST), `formLogin(user, password)` (JSON
  body `{user, password}`), `refresh()` and the classifier. **Only a 401 from `/login` is a credential
  failure** (DW-1): a 404, a 5xx, a network fault, or any 503 carrying an `INSTALL.*` code enters
  `installing` and re-probes with backoff. A failed refresh runs the silent probe once more
  (EXPERIENCE.md `:571`) before `session-ended`. `fetch`, storage and `now()` are constructor-injected.
- `ui/src/app/core/api.ts` — *new*. The one API service. Throws on a relative path before any network call
  (AD-20); attaches `Authorization: Bearer <access>` and nothing else; never sends credentials or a cookie;
  on 401 awaits the **single-flight** refresh (DW-4) and retries **once**. A second 401 after the retry is
  not refreshed again.

**Execution — client Angular layer:**

- `ui/src/app/shell/sign-in.ts` — *new*. OnPush component rendering two states: the signing-in skeleton
  (`aria-hidden` bars inside an `aria-busy` region, static under reduced motion) with the status line
  `STRINGS.statusConnectionSigningIn`, and the form-login card per `DESIGN.md:1064` — lockup, user-name and
  password fields with a reveal toggle, a full-width Sign in button, and beneath them the status slot:
  `authSignInFailed` in `role="alert"`, `authPasswordExpired` and `authSessionEnded` as banners. Every word
  is `{{ STRINGS.<key> }}`; every color an existing `--ocu-*`.
- `ui/src/app/app.ts` — edit. Gate `<router-outlet />` behind the session state, rendering `app-sign-in`
  until `signed-in`. **Preserve all three `build-output.test.mjs:195-226` pins**: an inline `template:`
  block, a first `{{ STRINGS.<key> }}` interpolation, and a first `class="…"` whose rule lands in the
  global bundle.
- `ui/src/main.ts` — edit. Construct the `Session` over the real `fetch`/`sessionStorage`, provide it, and
  start the silent probe at bootstrap so the probe is in flight while the shell paints. Do **not** add
  `provideHttpClient`; the core modules use `fetch` so they stay importable by `node --test`.
- `ui/src/styles/_components.scss` — *new*, `@use`d from `ui/src/styles.scss` (edit) so its rules reach the
  **global** bundle. Skeleton, focus ring, card, banner and the status line, composed from existing tokens.
  Add no color token.
- `ui/src/assets/lockup/` — *new*. Copy `imports/OcuPilot-Lockup-horizontal.png` from the UX folder and
  reference it from `_components.scss` with a relative `url()`, the same mechanism the fonts use. No
  external host.
- `ui/proxy.conf.json` — *new*, and `ui/angular.json` — edit: add a `serve.options` block naming it, mapping
  `/api/ocupilot` to `http://localhost:52774` so the dev loop runs through the IRIS origin and the
  `SameSite=Strict` cookie is carried (AD-28).

**Execution — server:**

- `src/OcuPilot/Api/Router.cls` and `src/OcuPilot/Api/StaticHandler.cls` — edit. Declare
  `Parameter HandleCorsRequest = 0` on both. Unspecified is the inherited default and delegates the decision
  to a route's `Cors` attribute; `0` turns CORS processing off unconditionally, which is the falsifiable
  form of "no CORS allowance exists in either configuration".
- `src/OcuPilot/Kernel/Utils.cls` — edit `ReadRequestBody` only (DW-24). Bind the inner `Catch`'s exception
  and return an error `%Status` naming the read stage instead of falling through to `Quit tSC` with
  `$$$OK` and an empty body. A genuinely absent body must still return `$$$OK` with `pBody = ""` — the two
  cases are what the fix separates.
- `src/OcuPilot/Test/Utils.cls` — *new*. DW-23's first executed test host: `DecodeUtf8Stream` over a stream
  larger than `UTF8CHUNKSIZE` with a multi-byte sequence straddling the 1,000,000-byte boundary (assert the
  decoded text round-trips), `ApplyOutputCeiling` cutting exactly where a surrogate pair would be split,
  `SanitizeError`'s bracket scan over a nested-paren routine reference, and both `ReadRequestBody` branches
  from DW-24.
- `src/OcuPilot/Test/Http.cls` — edit. Give `AbsoluteRequest` optional request-body, content-type and
  extra-header parameters (`p`-prefixed) so one helper can send a Bearer header, a JSON login body, or
  neither. Leave `MakeRequest`/`RawRequest` untouched — every existing caller keeps its signature.
- `src/OcuPilot/Test/Token.cls` — *new*. The over-the-wire token contract, using `Test/Wire.cls`'s throwaway
  principal pattern (crypto-random password, retained for the run, principal deleted in teardown): a JSON-body
  login mints a pair and returns `Set-Cookie: CSPBrowserId=…; path=/`; that cookie alone mints silently on a
  second, empty-body request; no cookie → 401 with an empty body and no `WWW-Authenticate`; a refresh kills
  **both** old tokens; a refresh token sent as a Bearer is refused; `/logout` is per-`sid` and leaves a
  sibling session live. **The Bearer's wire anchor:** with the `UrlMap` empty, a minted access token sent as
  `Authorization: Bearer` to `GET /api/ocupilot/` answers **404 in OcuPilot's own envelope** — it passed the
  install gate, the anonymous rejection and the admin gate and found no route, which is the success signal
  this story has; the same request with no header answers a bare 401 with an empty body, before dispatch.

**Acceptance Criteria:**

- Given a browser holding a `%ISCMgtPortal` login, when the shell loads any route, then the empty-body probe
  returns a pair for the same user, no form is shown, and the requested route is the one rendered — and
  while the probe is in flight the skeleton and `statusConnectionSigningIn` are on screen.
- Given no such cookie, when the probe returns 401, then the form appears **once** with the requested route
  preserved and restored after sign-in; a rejected attempt keeps the user name, clears the password, and
  renders `authSignInFailed` in a `role="alert"` region.
- Given a successful form login, when it completes, then the response carries `CSPBrowserId` at `path=/`, a
  subsequent empty-body probe at another `%ISCMgtPortal` application mints for the same user, and no request
  OcuPilot makes to `/csp/sys` or a vendor editor carries the token pair.
- Given a stored pair, when any API call is made, then the only credential on the wire is
  `Authorization: Bearer <access>` — the token authenticates past the whole gate chain to a 404 in
  OcuPilot's envelope, while the same request without the header is refused with a bare 401 — and no
  OcuPilot code writes `document.cookie`, `localStorage`, a `BroadcastChannel`, a `storage` event listener,
  or posts into a frame, asserted by a source scan over `ui/src`.
- **Integration AC** — given the session in each state, when `app.ts` renders, then `app-sign-in` is on
  screen for `probing`, `form`, `form-rejected`, `password-expired`, `session-ended` and `installing`, and
  `<router-outlet />` only for `signed-in`.
- Given `ng serve`, when the dev loop runs, then `/api/ocupilot` is proxied through the IRIS origin and
  neither configuration carries a CORS allowance: `HandleCorsRequest = 0` on both dispatch classes, and no
  `Access-Control-Allow-*` header on any probed response.

### Review Findings

**2026-09-12 — code review (first review, full-opus, four layers: blind-hunter, edge-case-hunter,
verification-gap, acceptance-auditor).** 46 raw findings → **17 root-cause entries**: 2 high, 9 medium,
6 low. **13 patched in-pass**, 3 routed, 1 by-design, 2 wontfix, 1 occurrence appended. No high or
medium is left unresolved. Suite after the patches: `npm --prefix ui test` **186/186**, build exit 0
(initial 242.84 kB), `check-objectscript.py` 0, `lint-docs.sh` clean, `Token` 9/9, `Utils` 9/9,
`Wire` 7/7, `Static` 15/15.

**High — both patched.**

- `[high]` `[patch]` **The path guard admitted dot segments, so the Bearer could reach `/csp/sys`.**
  `isOcuPilotApiPath` compared the spelling of the path; `fetch` sends the *resolved* request-target.
  Verified in Node: `/api/ocupilot/../../csp/sys/UtilHome.csp`, `/api/ocupilot/%2E%2E/%2E%2E/csp/sys`
  and `/api/ocupilot/..\..\csp/sys/x` all passed the guard and all resolve to `/csp/sys/...`, which
  falsifies AC4's last clause and AD-20/AD-47. The previous pass's backslash fix did not cover them,
  and the doc comment claimed the check was "closed". Fixed by normalizing with the same parser the
  network stack uses and re-testing origin and `pathname`; five escape rows and two must-still-pass
  rows added to `api.test.mjs`. Fix-risk low — one pure function, `%252F`-encoded ids still accepted.
- `[high]` `[patch]` **No renewal timer: AD-28's Rule and the epic's own AC for this story both
  require one.** AD-28 says "the client refreshes on a timer derived from the token's own lifetime …
  because a turn can outlive an access token"; epics.md:1204 says "an access token **approaching
  expiry**"; FR-1 says "refreshed before expiry". The only `setTimeout` in `ui/src` was the install
  backoff, and renewal happened only at the moment of a call, only once already expired — so an idle
  tab's 900 s refresh token died behind its 60 s access token with nothing to renew from, and
  `start()` reported `signed-in` on a stored pair expired since 1970 (an existing test had encoded
  that defect in its fixture). Fixed with `RENEWAL_MARGIN_MS`, a generation-guarded `scheduleRenewal()`
  armed on every `adopt()`, and a `start()` that renews a dead pair instead of adopting it. Fix-risk
  med — contained to `session.ts`, which already injected `schedule` and `now` for exactly this.

**Medium.**

- `[med]` `[patch]` A live `CSPBrowserId` value was concatenated into a `$$$AssertTrue` description
  (`Token.cls`), and `%UnitTest.Manager.LogAssert` persists and prints descriptions on pass as well as
  failure — a credential in a log, against AD-35. Value removed; `path=/` re-scoped to that cookie's
  own attribute list rather than the comma-joined header.
- `[med]` `[patch]` **Rule 19** — the Integration AC's pinning test filtered `isSignedIn` over a string
  array and never read `app.ts`; inverting its gate left the suite green. Pinned by a read of `app.ts`'s
  own template, the technique `signInTemplate` already used for `sign-in.ts`.
- `[med]` `[patch]` **Rule 19** — `main.ts` had no executed host. Deleting `session.start()`, or
  reverting either of the two HIGH boot-path patches at their call site, type-checked, built clean and
  left every test green. Pinned by a source read of the composition root.
- `[med]` `[patch]` **Rule 19** — `sign-in.ts`'s `waiting` getter restated the state rule locally;
  `state === 'probing'` alone left the suite green and would present a password field during an
  install (DW-1's user-visible half). `isWaiting()` exported from `session.ts` beside `isSignedIn`.
- `[med]` `[patch]` **Rule 19** — `readNavigationKind()`, the reader DW-6's whole decision rests on,
  was never executed: every test injected its own. `return 'reload'` left the suite green and makes
  every duplicated tab adopt its parent's pair. Two cases added against Node's real timeline.
- `[med]` `[patch]` Two submits in flight minted two `sid`s, the second `adopt()` overwriting the
  first pair and leaving that session live with nothing holding it. `submitForm()` is now single-flight
  like `refresh()`.
- `[med]` `[patch]` `ApiService.request` discarded the pre-emptive refresh's result and sent the call
  anyway — with no `Authorization` header, since the failed refresh had cleared the pair — then let the
  401 call `refresh()` a second time behind an ended session. It now sends once and does not retry.
- `[med]` `[routed 1-13]` **DW-104** — a form submit that meets an unreachable instance is discarded
  with no message: `formLogin`'s `unavailable` branch leaves `refusalState` at `form` (its sibling in
  `runRefresh` sets `session-ended`), so the backoff probe's 401 shows a bare form. No published string
  fits a never-established session and adding an EXPERIENCE.md row is the hazard this story is
  forbidden to trigger; 1.13 owns the connectivity copy.
- `[med]` `[routed 1-13]` **DW-105** — the `password-expired` banner renders the literal `<user>`
  placeholder with no substitution and no links, against epics.md:1194. The state has no trigger on
  this build (the verified negative below), so the rendering half was unowned; routed alongside the
  discriminator half.
- `[med]` `[occurrence]` **DW-102** — the scheduled backoff probe carries no cancellation handle, so
  it can fire after the state it was armed for is gone (a `signOut()` re-minting from the cookie; a
  `signed-in` screen torn down by a stale probe). Same root cause as the two-concurrent-chains entry
  already routed to 1.8; occurrence appended rather than a duplicate filed. Unreachable in this story —
  `signOut()` and `ApiService.request()` both have no production call site.

**Low.**

- `[low]` `[patch]` `proxy.conf.json`'s `logLevel: "debug"` is an `http-proxy-middleware` key; Angular
  22's dev server is Vite-based and ignores it. Dead configuration in the file AC6 rests on — removed.
- `[low]` `[patch]` `CLAUDE.md`'s new port-mirror sentence claimed the two client tests make a
  half-done port change fail the suite. Neither cross-checks the other's file: each asserts the literal
  `52774` against its own. Corrected to say so.
- `[low]` `[patch]` **Rule 19** — six `mutation:` lines quoted truncated test titles with no ellipsis,
  so grepping the quoted string found nothing. Corrected against the real titles.
- `[low]` `[by-design]` No attempt ceiling or escalation while `installing`: a permanent 403/400/429
  holds the user on the skeleton indefinitely. Spec-bound — the Design Notes assign the installing copy
  and the escalation to `statusConnectionRetrying` to 1.13 and 1.17, and the sibling finding was
  already closed on that ground in the previous pass.
- `[low]` `[wontfix-theoretical]` `Session` retains a password typed but never submitted. No exposure
  beyond the DOM input holding the same value. `reopen_if`: `Session` is ever serialized, logged, or
  sent to an error reporter.
- `[low]` `[wontfix-accepted]` The sign-in screen has no `<h1>` and no landmark, and pressing Sign in
  on an empty form posts blank credentials. `reopen_if=either survives Story 1.10's chrome pass` —
  1.10 rebuilds this screen's chrome and owns both.

**Verified clean** (checked, not assumed): AD-21's gate chain resolves the authenticated user via
`ResolvedUsername()` and rejects `""`/`UnknownUser`/`_PUBLIC` explicitly before the admin gate, and is
anchored over the wire by `Token.TestTheBearerAuthenticatesPastTheWholeGateChain`;
`$System.Security.Login()` appears nowhere in the diff; after the `Token.cls` patch no credential,
token or password reaches a log, a URL, a status message or an assertion description; the single-flight
refresh assigns its promise before any `await`, so no interleaving can drop or duplicate a pair;
`HandleCorsRequest = 0` really is the unconditional-off form (`irissys/%CSP/REST.cls:117-119`).

**Correction to `## Auto Run Result`'s Rule 19 count.** It states 18 `mutation:` lines and a 168/168
suite. `## Verification` carried 20 at review time (the QA pass appended two without restating the
total) and carries **29** after this review; the suite is **186/186**.

## Spec Change Log

- **Decision (overnight) — the two accessibility containers the matrix names get an executed pin.** The
  "Form rejected" row requires `authSignInFailed` in `role="alert"`, and AC1 requires the skeleton
  `aria-hidden` inside an `aria-busy` region; both lived only in `sign-in.ts`, which has no component runner
  until 1.9 (DW-93), so the Matrix Test Audit had no executed host for them. Closed by reading the
  component's own template in `ui/tools/session.test.mjs` — the same source-scan technique
  `ui/tools/api.test.mjs` already uses, not a component runner.

## Review Triage Log

### 2026-09-12 — Review pass

- verdicts: 38 findings — high 3, medium 9, low 13, false 9, maybe-false 4
- findings:
  - `[high]` `[patch]` `isAbsoluteOriginPath` admits `/\host/x`, which the URL parser resolves off-origin, so the Bearer leaves the instance — verified with Node: `new URL('/\\evil.example/x', origin)` is `http://evil.example/x` and the `//` check does not see it. Fixed by requiring the API root rather than listing escapes; `/csp/sys` and the backslash form are now table rows.
  - `[high]` `[patch]` `main.ts` reads `sessionStorage` at module scope, which **throws** where site data is blocked, aborting the bootstrap before anything paints — the store's own try/catch never gets the object. Fixed with `readSessionStorage()`, an in-memory fallback.
  - `[high]` `[patch]` `crypto.randomUUID()` is secure-context-only, so on an instance reached as `http://<host>:52773` the `TokenStore` constructor throws and the shell never renders. Fixed with `defaultNonce()`; the nonce is not a secret, so unpredictability bought nothing and the hard failure cost everything.
  - `[medium]` `[patch]` `remainingMs()` returns 0 for a pair with no `exp`, so `ApiService` would pre-emptively refresh before **every** call, and a replayed rotated token revokes the session. Fixed: pre-empt only when `exp` is known.
  - `[medium]` `[patch]` The status-line containment assertion I added in the Matrix audit sliced to the first `</div>`, which is a skeleton bar's — the slice stayed inside the `aria-hidden` subtree. Fixed with a brace-counted extent, and the mutation re-demonstrated.
  - `[medium]` `[patch]` `test('the backoff is capped')` constructed no subject: it recomputed `Math.min` over two exported constants and stayed green with the clamp deleted. Replaced by a test that drives `enterInstalling` eleven attempts past the cap; mutation demonstrated.
  - `[medium]` `[patch]` AC3's "no request to `/csp/sys` carries the token pair" held only because no consumer exists yet. Closed by the narrowed guard above — same fix as the backslash finding.
  - `[medium]` `[patch]` `Token.cls` asserts `access_token`/`refresh_token`/`sub` but not `exp`, the field the client's renewal decision reads. Added numeric `iat`/`exp` assertions with `exp > iat`.
  - `[medium]` `[patch]` `session.ts`'s header and `isInstallInFlight`'s doc claimed an `INSTALL.*` 503 on a data call enters `installing`; nothing calls it. Both passages corrected to say it is unwired and 1.8 is its first consumer; the spec's pinning line too. Wiring itself deferred.
  - `[medium]` `[defer]` Two concurrent backoff chains are possible if `enterInstalling` is entered twice — unreachable today (no data call exists, and the form is hidden while `installing`), reachable when 1.8 adds the first data call. Deferred with that trigger named.
  - `[medium]` `[defer]` Focus is lost after a rejected sign-in: `formLogin` enters `probing`, the card unmounts, and the re-rendered form leaves focus on `<body>`. The trivial half (`aria-describedby`/`aria-invalid`) was patched; restoring focus changes the state machine and belongs with 1.10's chrome.
  - `[medium]` `[patch]` `Utils.TestDecodeUtf8StreamHandlesEveryTailLength` row 3 asserted only the high surrogate, so a decoder dropping the low half stayed green. Added a length assertion and the low-surrogate check.
  - `[low]` `[patch]` `Kernel.Utils.ReadRequestBody` set `tStage = "decode"` before `Rewind()`/`Size`, both of which are reads — a read fault reported the wrong stage, contradicting the method's own new doc comment. Moved one line down.
  - `[low]` `[patch]` `angular-json.test.mjs` justified the dev proxy with "`SameSite=Strict`, so a dev server on its own origin never receives it" — cookies are not port-scoped and `localhost:4200`/`localhost:52774` are the same site. Corrected to lead with CORS, keeping the SameSite case as the different-host one.
  - `[low]` `[patch]` `angular-json.test.mjs`'s `!includes('access-control')` cannot distinguish a CORS allowance from its absence — a proxy expresses CORS through header-rewrite keys. Deleted; the falsifiable half is `TestNeitherDispatchClassEnablesCors`.
  - `[low]` `[patch]` The DW-6 doc comment claimed the nonce lets a tab tell its own storage from a copy — it is copied with everything else. Corrected: the navigation kind decides, the nonce records the decision.
  - `[low]` `[patch]` `Session.start()` adopted a pair without restoring `currentUserName` from its `sub`, contradicting `userName()`'s own doc comment. One line.
  - `[low]` `[patch]` `runRefresh`'s `unavailable` branch left `refusalState` at `form`, so a refresh that 503s and then a probe that 401s showed a bare form instead of `authSessionEnded`. One line.
  - `[low]` `[patch]` The forbidden-channel scan's extension set omitted `.js`/`.mjs` while the test's name claims "no code under ui/src". Added both.
  - `[low]` `[patch]` `_components.scss`'s header claimed "Every value is an existing token" over a file carrying `10px`, `60vh`, `40px`/`195px`, `600` and `1.2s`. Narrowed to what is enforced, and the geometry literals named.
  - `[low]` `[patch]` `Token.cls` stated cross-application cookie sharing as observed fact; only one application was probed. Labeled `(inference)` with what was actually observed.
  - `[low]` `[patch]` `Http.AbsoluteRequest`'s new `pRequestBody` is written to the entity body verbatim, so a non-ASCII body would go out as the wrong bytes. Restriction documented on the `@param`.
  - `[low]` `[patch]` `TestApplyOutputCeilingNeverCutsASurrogatePair` carried two assertions on the same byte, the second with a message about stranded surrogates it did not check. Replaced by a scan for a surrogate half anywhere in the result.
  - `[low]` `[patch]` `assert.equal(init.headers['Cookie'], undefined)` cannot fail while the `deepEqual(Object.keys(...), ['Authorization'])` above it passes. Deleted, its meaning folded into that assertion's message.
  - `[low]` `[patch]` `assert.notEqual(session.state(), 'form-rejected')` follows `assert.equal(session.state(), 'installing')` and cannot fail independently. Deleted.
  - `[low]` `[patch]` `## Auto Run Result` said 15 mutation lines where `## Verification` carried 16. Recomputed and restated at finalize.
  - `[low]` `[defer]` `ui/proxy.conf.json` adds a fourth place the host port is written, and `CLAUDE.md` names only two. Fixing that edits an agent-context file, which this stage does not touch.
  - `[low]` `[reject]` `authSignedOut` has no state that selects it — the string predates this story and Story 1.7 owns sign-out; nothing calls `signOut()` yet.
  - `[low]` `[reject]` `signOut()` may leave the browser-level login intact — it already sends `credentials: 'include'` per AD-28, which is what ends it; whether the CSP server honours that is 1.7's to pin.
  - `[low]` `[reject]` `installing` never escalates to `statusConnectionRetrying` — spec-bound: Design Notes assign the installing copy to 1.13 and 1.17 and say this state renders the signing-in presentation.
  - `[low]` `[reject]` The wordmark appears twice on the sign-in screen — `app.ts`'s line is Story 1.5's placeholder that `build-output.test.mjs:195-226` pins and the spec requires preserved; 1.10 replaces it.
  - `[low]` `[reject]` No `@media (forced-colors)` fallback for the lockup background — a real gap, but the fix adds a CSS branch for a case no assertion covers, and 1.10 owns chrome polish.
  - `[low]` `[reject]` `Token.cls` parses `tRaw` without a status guard at two sites — a developer meets this only when the test is already failing, and the fix adds branches rather than correcting anything.
  - `[low]` `[reject]` `ReadRequestBody` does not route `ex.DisplayString()` through `SanitizeError` — the method has no production call site, and AD-12 has `Error.Render` emit a generic reason for internal failures, so no vendor text is user-reachable.
  - `[low]` `[reject]` The reveal toggle's accessible name repeats the field label — real ambiguity, but the only fix is new wording, and adding a row to EXPERIENCE.md's table is the hazard this story is explicitly forbidden to trigger.
  - `[false]` `[reject]` "EXPERIENCE.md was amended with no change-log entry" — the spec's `## Tasks & Acceptance` directs exactly that edit, naming both rows and line numbers; it is spec-directed, not an undocumented amendment.
  - `[false]` `[reject]` "The `signInTemplate` regex fails silently on a reformat" — it is `assert.ok(match, '...')`, which fails loudly with its message.
  - `[maybe-false]` `[reject]` Password-manager autofill could submit blank credentials by setting DOM values without dispatching `input`. Would need a browser matrix to settle; if true it is low, since the user simply retries.
  - `[maybe-false]` `[reject]` Clock skew beyond the 60 s token lifetime would make every call pre-refresh. Would need a skewed-clock browser to settle; the `exp !== 0` patch removes the unbounded case, and a rotation per call is wasteful rather than harmful.

## Design Notes

**Governing ADs (Rule 6).** AD-28 (silent-first, Bearer-only, per-tab, refresh in the JSON body, dev through
the IRIS origin — this story's spine), AD-47 (hostile origin: per-tab storage, no cross-tab broadcast, no
CORS in development either), AD-20 (absolute API paths, enforced by the one service), AD-19 (zoneless,
`OnPush`, signals), AD-21 (gates resolve the **authenticated** user; `UnknownUser`/`_PUBLIC` rejected — the
gate is already in `Router.cls:157-162` and is unchanged here), AD-38 (install completes before traffic; the
DW-1 classifier is the client half), AD-12/AD-39 (one envelope; the classifier reads `code`, never `reason`),
AD-8 (privilege checked in the calling process, never cached — no token carries authorization), AD-35
(no credential in a log, a status or a URL), AD-45 (readiness is 1.17's, which is why this story has no
readiness probe), AD-17 (the installer already sets every JWT property; this story changes none of them).

**Decision (overnight) — the token endpoints get no OcuPilot server code.** Verified twice, from
`irissys/%CSP/REST.cls:56-65` and empirically: `/login`, `/refresh`, `/logout` and `/revoke` are intercepted
by the CSP server before dispatch, so `Api.Router`'s `UrlMap` stays empty and this story adds no route. The
first real route is 1.8's.

**Decision (overnight) — expired password has no verified discriminator.** Every 401 on this path is
byte-identical: zero-length body, no distinguishing header; even the audit log records the same description
for a wrong password and an unknown user. A discriminator exists inside IRIS
(`irissys/%occErrors.inc:752`, `$$$PasswordChangeRequired` = 935) and `%ZHSLIB/Login/Utils.cls:98-105`
reads it from `%request.Data("Error:ErrorCode",1)` for a dispatch-class application — but the observed 401s
never invoke the dispatch class's `Login()` callback at all, so the two signals conflict *(inference: that
the callback is skipped for JWT applications; only its absence from the response was observed)*. The story
therefore does **not** guess. The client renders `authPasswordExpired` whenever the session reports
`password-expired`, and one bounded implement-stage experiment **on the throwaway container** settles the
trigger: create a throwaway principal, expire its password, override `Login()` on a probe router, and record
whether 935 arrives. If it does, wire it. If it does not, record the verified negative in this spec's
Verification section and file the residue for 1.13 — the state stays reachable because it is the state the
README's documented unexpire command addresses.

**Decision (overnight) — DW-1 is the negative half, and it uses an existing string.** The install gate lives
in `OnPreDispatch`, which a token endpoint never reaches, so a login during install does not fail — it
succeeds, and the *next* call 503s. The guard is therefore a classifier rule ("only a 401 from `/login` is a
credential failure") plus an `installing` state that re-probes. That state renders the signing-in
presentation, which is truthful and needs no new string; 1.13 and 1.17 own the eventual installing copy.

**Decision (overnight) — the story renders two states, not a shell.** AC1 names a status bar, which 1.10
owns. This story builds only the signing-in skeleton with its status line and the form-login card; 1.10
absorbs the status line into the real band.

**Consumes:** 1.1 (`Kernel.Utils`, `Api.Error`/`Response`), 1.2 (`strings.ts`, the token and type layers),
1.3 (the install gate and version stamp the DW-1 classifier reads through), 1.5 (`/api/ocupilot` with its JWT
and group settings, `Api.Router`'s gate chain, the CSP's `connect-src 'self'`, `Test.Wire`'s throwaway
principal pattern, `Test.Http.AbsoluteRequest`).

**Consumed-by:** 1.7 — sign-out calls `/logout` with both the Bearer and the cookie and clears this store;
1.8 — the first Bearer data call, and the first consumer of the API service's `INSTALL.*` classifier;
1.9–1.12 — every screen read goes through this API service; 1.13 — extends the classifier with the
connectivity probe and owns the installing copy; 1.14 — auto-refresh rides the same service.

**Ledger inbox.** DW-1, DW-4 and DW-6 are addressed by the matrix rows and tasks that name them. DW-23 is
addressed by `src/OcuPilot/Test/Utils.cls` — the "never executed" half closes; the "no production call site"
half does **not**, because the login POST is handled by the CSP server and never reaches `ReadRequestBody`
(verified above), so the first production consumer will be 1.8's first route with a body. DW-24 is addressed
by the `Kernel/Utils.cls` fix and pinned by that suite.

**Hazard for a later story.** `ui/tools/strings.test.mjs:47` hardcodes the EXPERIENCE.md line range
`252..302`. Adding a *row* to the Fixed strings table silently drops a literal from the expected set. This
story extends existing rows to avoid it; whoever first needs a new row must widen the range in the same
commit.

## Verification

**Environments.** The live `ocupilot` container (web 52774, SuperServer 1973) must **not** be recreated — no
`docker compose up`/`down`/`restart` against this repository's compose file. Read-only and idempotent checks
run against it through the IRIS MCP tools with **`server: "ocupilot-iris"`** on every call. Anything
destructive or install-path — the expired-password experiment, and any check that needs a fresh install
state — runs only on a **throwaway** scratch compose project with its own project name, container name, host
ports (never 52774/1973) and scratch volume, per `README.md` § "Verifying the start path against a throwaway
container", torn down with `down -v`. No real account is created, modified, locked or expired anywhere; the
story's principals are purpose-built throwaways in the `Test/Wire.cls` pattern, removed in teardown.

**One test class per tool call.** Every party running tests for this story sends **one** `iris_execute_tests`
call per message, waits for it to land in `%UnitTest_Result`, and never re-submits on a client-side timeout —
a returned call is not a finished run, and this suite's classes share one instance.

**Commands:**

- `npm --prefix ui test` — expected: green, including the three new `ui/tools/*.test.mjs` files and the
  unchanged `strings.test.mjs` count equality at 107 keys.
- `npm --prefix ui run build` — expected: exit 0, and the `initial` bundle stays under the 1MB budget error
  (`ui/angular.json:38-44`). Measure this **early**: `@angular/forms` and Material form-field/input/button
  enter the graph for the first time in this story.
- `uv run scripts/check-objectscript.py` — expected: no findings (new class names ≤ 29 chars, `p`-prefixed
  parameters, no bare `Write`, no `New $ROLES`).
- `bash scripts/lint-docs.sh` — expected: clean, after the EXPERIENCE.md edit.
- `iris_doc_load` + `iris_doc_compile` on `src/OcuPilot/` (`server: "ocupilot-iris"`) — expected: clean
  compile of `Kernel/Utils.cls`, `Api/Router.cls`, `Api/StaticHandler.cls`, `Test/Http.cls`, `Test/Utils.cls`,
  `Test/Token.cls`.
- `iris_execute_tests` on `OcuPilot.Test.Utils`, then `OcuPilot.Test.Token`, then `OcuPilot.Test.Static`,
  then `OcuPilot.Test.Wire` — **one class per message**. Expected: all green. `Static` and `Wire` are
  regression: the CSP string is asserted exactly and `Wire`'s six methods must survive the
  `AbsoluteRequest` signature change.
- `curl -sS -D- -o/dev/null -X POST http://localhost:52774/api/ocupilot/login` — expected: `401`,
  `content-length: 0`, no `WWW-Authenticate`, and **no `Access-Control-Allow-*` header**.

**Pinning tests (Rule 19) — one per acceptance criterion:**

- Silent mint → `OcuPilot.Test.Token`, the cookie-only empty-body mint.
  `mutation: send the second, empty-body login without the Cookie header → Token.TestAJsonLoginMintsAPairAndItsCookieMintsSilently (the silent-mint half answers 401)`
- Form login, rejection and route preservation → `ui/tools/session.test.mjs`, the `form` → `form-rejected`
  transition asserting the user name is kept, the password cleared and `authSignInFailed` selected.
  `mutation: Session.submitForm stops clearing currentPassword → session.test.mjs "form rejected: the user name is kept, the password is cleared, authSignInFailed is selected"`
  `mutation: drop role="alert" from the failure line, and aria-busy from the skeleton region, in sign-in.ts → session.test.mjs "the sign-in failure is announced..." and "the signing-in skeleton is decoration inside a busy region..."`
- Browser-level sign-in shared, token never presented → `OcuPilot.Test.Token` (the `path=/` cookie and the
  second silent mint) plus the `ui/src` source scan in `ui/tools/api.test.mjs`.
  `mutation: add localStorage.setItem("t", access) to ui/src/app/core/token-store.ts → api.test.mjs "no code under ui/src writes a cookie, persistent storage, a cross-tab channel or a frame message"`
- Bearer-only, per-tab, no broadcast → `ui/tools/api.test.mjs` (the path guard and the header set)
  and `ui/tools/token-store.test.mjs` (DW-6: a non-`reload` navigation with a stored pair clears it).
  `mutation: isOcuPilotApiPath returns true unconditionally → api.test.mjs "a relative path throws before any network call is made"`
  `mutation: relax isOcuPilotApiPath to path.startsWith('/') && !path.startsWith('//') → api.test.mjs "isOcuPilotApiPath accepts an API path and refuses everything else" and "the classic portal is refused before any network call, not merely never called" (both /csp/sys and the backslash form reach the wire)`
  `mutation: TokenStore's constructor adopts a stored pair whatever the navigation kind → token-store.test.mjs "DW-6: a duplicated tab discards the pair it inherited and stamps a fresh nonce"`
- Single-flight refresh and the retry → `ui/tools/session.test.mjs`, three concurrent 401s resolving through
  **one** refresh call against an injected `fetch` that counts invocations (DW-4).
  `mutation: drop the refreshInFlight guard from Session.refresh → session.test.mjs "DW-4: three concurrent 401s resolve through exactly one refresh, and each retries once" (counts 3)`
- Install in flight is never a sign-in failure → `ui/tools/session.test.mjs`, the DW-1 classifier over 404,
  5xx and a thrown network fault on `/login`. `isInstallInFlight` — the `INSTALL.*`-on-a-data-call half — is
  tested as a pure function and is **not wired to `ApiService`**: this story has no data call to wire it to
  (`UrlMap` is empty), and 1.8 is its first consumer (`deferred:`).
  `mutation: classifyLoginStatus returns 'credential-failure' for any non-200 → session.test.mjs "DW-1: only a 401 from /login is a credential failure" and "DW-1: a 404, a 5xx and a network fault all enter installing and re-probe, never form-rejected"`
  `mutation: delete the Math.min clamp in Session.enterInstalling → session.test.mjs "the backoff stops doubling at the cap, driven through the session rather than computed"`
- Integration AC (`app.ts` gating) → `npm --prefix ui run build` type-checks the template under
  `strictTemplates`; the state-to-component mapping is pinned in `ui/tools/session.test.mjs`, the consumer
  side by a read of `app.ts`'s own template, and the render half is confirmed by the manual browser check
  below.
  `mutation: isSignedIn also returns true for 'form' → session.test.mjs "Integration AC: only signed-in renders the routed screen; every other state renders sign-in"`
- Dev proxy and no CORS → `ui/tools/angular-json.test.mjs` (edit: assert `serve.options.proxyConfig` and that
  `ui/proxy.conf.json` targets the IRIS origin) and `OcuPilot.Test.Token`'s assertion that no probed response
  carries an `Access-Control-Allow-*` header.
  `mutation: delete the serve.options block from ui/angular.json → angular-json.test.mjs "the dev server proxies /api/ocupilot through the IRIS origin, and the proxy file says so"`
  `mutation: delete Parameter HandleCorsRequest from Api/Router.cls → Token.TestNeitherDispatchClassEnablesCors`
- DW-24 → `OcuPilot.Test.Utils`, the injected read fault asserting `$$$ISERR`.
  `mutation: restore the pre-fix inner Catch in Kernel.Utils.ReadRequestBody (swallow the exception and set the stream empty) → Utils.TestReadRequestBodyReportsAReadFaultInsteadOfAnEmptyBody, while TestReadRequestBodyTreatsAnAbsentBodyAsOk stays green`
- DW-23 → `OcuPilot.Test.Utils`, the >1 MB straddled-boundary decode, the surrogate cut and the bracket scan.
  `mutation: delete the carry-back branch in DecodeUtf8Stream → Utils.TestDecodeUtf8StreamCarriesASequenceAcrossTheChunkBoundary`
  `mutation: drop the SurrogateSafeCutLength call from ApplyOutputCeiling → Utils.TestApplyOutputCeilingNeverCutsASurrogatePair`
  `mutation: scan to the first ")" instead of the depth loop in SanitizeError → Utils.TestSanitizeErrorRemovesANestedParenRoutineReference`
- Lockup reaches the bundle → `ui/tools/build-output.test.mjs`, the hashed asset the emitted CSS references.
  `mutation: delete the background-image rule from ui/src/styles/_components.scss → build-output.test.mjs "the sign-in lockup reaches the bundle as a hashed asset the emitted CSS references"` (no file is emitted)
- (QA) Two of the three HIGH boot-path patches (`readSessionStorage`, `defaultNonce`) had no executed test
  host at all — added to `ui/tools/token-store.test.mjs`, each calling the real production function against
  Node's real globals (a real `crypto.randomUUID()` call on the happy path, a property getter that throws to
  reproduce the blocked-site-data failure, an object with no `randomUUID` to reproduce the non-secure-context
  failure), not a caller-supplied fake standing in for the browser.
  `mutation: drop the try/catch in readSessionStorage (return sessionStorage unconditionally) → token-store.test.mjs "readSessionStorage falls back to a working in-memory store when the property read throws"`
  `mutation: drop the typeof webCrypto.randomUUID === 'function' guard in defaultNonce → token-store.test.mjs "defaultNonce falls back to a non-crypto id, without throwing, when randomUUID is unavailable"`
- (Code review) The API path guard, the renewal timer, the two consumer-side gates and the three readers
  the review added or narrowed. Every line below was applied, observed red, and reverted with
  `git status --short` and `git diff --stat` unchanged.
  `mutation: revert isOcuPilotApiPath to a bare path.startsWith(API_PATH_PREFIX) → api.test.mjs "isOcuPilotApiPath accepts an API path and refuses everything else" and "the classic portal is refused before any network call, not merely never called" (the dot-segment rows reach /csp/sys carrying the Bearer)`
  `mutation: delete the scheduleRenewal() call from Session.adopt → session.test.mjs "a minted pair arms a renewal timer derived from its own exp, short of expiry"`
  `mutation: drop the generation check in Session.scheduleRenewal's callback → session.test.mjs "a renewal armed for a superseded pair does not rotate the pair that replaced it"`
  `mutation: make Session.start adopt a stored pair whatever its exp (drop the remainingMs() === 0 branch) → session.test.mjs "a reloaded tab holding an EXPIRED pair renews it instead of reporting signed-in"`
  `mutation: drop the submitInFlight guard from Session.submitForm → session.test.mjs "two submits in flight produce one login, not two sids"`
  `mutation: narrow isWaiting to state === 'probing' → session.test.mjs "installing renders the signing-in presentation, never the credentials form (DW-1)"`
  `mutation: swap app.ts's @if (signedIn) branches → session.test.mjs "Integration AC: app.ts withholds the routed outlet from every state but signed-in"`
  `mutation: comment out session.start() in ui/src/main.ts → session.test.mjs "main.ts starts the probe at bootstrap through the two guarded browser readers"`
  `mutation: replace readNavigationKind's body with return 'reload' → token-store.test.mjs "an empty Performance timeline reads as unknown, which is a discarding kind"`

**Manual checks:**

- In desktop Chrome against the live instance: sign in to `/csp/sys`, then open `/ocupilot` — no form, the
  requested route renders. Then in a fresh incognito window open `/ocupilot` — the form appears once; a wrong
  password shows `authSignInFailed`; a correct one lands on the requested route. Confirm in DevTools that
  every `/api/ocupilot` request carries `Authorization: Bearer` and that the token appears in no cookie, no
  `localStorage` entry and no URL.
- Duplicate the signed-in tab (DW-6): the duplicate re-probes and takes its own `sid` rather than reusing
  the copied pair.
- Record the expired-password experiment's outcome here, with the command run and its result, before the
  story closes.
- **(QA, 2026-09-12) The follow-up above, performed against the live, patched bundle at
  `http://localhost:52774/ocupilot/`** via browser-MCP (chrome-devtools), closing the residual risk that the
  three HIGH boot-path patches had only been checked pre-patch. Cold isolated context: silent probe 401,
  form renders, no console exception (the module-scope `readSessionStorage`/`defaultNonce` calls in `main.ts`
  survived). Wrong password: `role="alert"` fired live, `aria-invalid`/`aria-describedby` wired, user name
  kept, password cleared. Correct password (`_SYSTEM`): pair minted, `Set-Cookie: CSPBrowserId=...;
  path=/; httpOnly; sameSite=strict`, `document.cookie` empty, `localStorage.length` 0, pair and a
  `crypto.randomUUID()`-shaped nonce present only in `sessionStorage`, sign-in card replaced by the routed
  screen. A second tab sharing the isolated context's cookie: empty-body `/login` minted `[200]` with no
  form ever shown and its own independent `sid`/nonce — the silent-mint AC end to end, against the real
  server, for the first time since the patches landed. **DW-6 (the bullet above), closed:** a genuine
  duplicate (`window.open(location.href)` from the signed-in tab, which the HTML standard's storage-area
  propagation rule delivers with a copy of `sessionStorage`) landed with `navigationType() === 'navigate'`,
  stamped its own nonce, and re-probed to a **new** `sid` (confirmed by decoding the access token's JWT
  payload in each tab) rather than reusing the copied one.

**Expired password: a verified negative** (throwaway compose project `ocupilot-expiry`, container
`ocupilot-expiry`, ports 52780/1979, own scratch volume, created and torn down with `down -v` on
2026-09-11; the live `ocupilot` container's state line was `running 2026-09-11T18:14:41.310714044Z 0`
before and after).

- Setup: a throwaway principal (`ExpiryProbeUser`, `%DB_HSCUSTOM:R` + `%Admin_Operate:U`) and a probe web
  application `/probeexpiry` — `AutheEnabled=32`, `JWTAuthEnabled=1`, `GroupById=%ISCMgtPortal`, dispatching
  to `Probe.ExpiryProbe`, whose `Login()` override records
  `%request.Data("Error:ErrorCode",1)` into `^ProbeLogin` before calling `##super`.
- Baseline: `POST /probeexpiry/login` and `POST /api/ocupilot/login` with the good password both `200`.
- `Do ##class(Security.Users).ExpireUserPasswords("ExpiryProbeUser")` → `ChangePassword=1` read back.
- Expired login on `/api/ocupilot/login` → `401`, `CONTENT-LENGTH: 0`, no `WWW-Authenticate` — byte-identical
  to a wrong password and to no credentials at all.
- `^ProbeLogin` stayed at **0 entries** across every attempt: the expired login, a wrong password, an
  anonymous request, and again after the probe application was given `MatchRoles = ":%DB_HSCUSTOM"` so the
  pre-login process could load the class.

**Conclusion: the dispatch class's `Login()` callback is never invoked for a JWT-enabled web application on
this build**, so `$$$PasswordChangeRequired` (935) never reaches one and no client-visible discriminator
exists. The `password-expired` state and its message stay (the state is what a later story sets once a
discriminator is found) and nothing guesses at a trigger. **Residue for 1.13:** find a discriminator, or
record that the state is unreachable and remove it.

**A second finding, from the live instance while writing `OcuPilot.Test.Token`.** Replaying a **rotated**
refresh token does not merely fail: it **revokes the session**, killing the pair the successful refresh had
just issued. That is why DW-4 needs single-flight rather than retry-on-401 — a second concurrent refresh
destroys what the first established. Pinned by
`Token.TestReplayingARotatedRefreshTokenRevokesTheSession`, and it is the reason
`Session.refresh()` hands every waiter one promise.


## Auto Run Result

Status: done
Blocking condition: none

**Implemented.** The client gained its transport layer: three framework-free modules under
`ui/src/app/core/` — a per-tab `TokenStore` carrying the DW-6 tab-identity check, a `Session` state machine
with the silent probe, the form login, the DW-1 classifier and a single-flight `refresh()`, and one
`ApiService` that refuses any path outside `/api/ocupilot/` and attaches nothing but a Bearer. Above them a
`SignIn` component rendering the story's two states, an `app.ts` that gates `<router-outlet />` behind
`signed-in`, a `main.ts` that constructs the layer over the real browser and starts the probe at bootstrap,
the first component stylesheet, and a dev proxy through the IRIS origin. On the server: `HandleCorsRequest = 0`
on both dispatch classes, DW-24 fixed in `Kernel.Utils.ReadRequestBody`, and DW-23's "never executed" half
closed by `OcuPilot.Test.Utils`. The token endpoints needed no OcuPilot code, and `UrlMap` stays empty.

**Files changed (26).** *New:* `ui/src/app/core/{token-store,session,api}.ts` (per-tab storage, the state
machine, the one API service); `ui/src/app/shell/sign-in.ts` (skeleton and form card);
`ui/src/styles/_components.scss` (the first component layer); `ui/src/assets/lockup/OcuPilot-Lockup-horizontal.png`;
`ui/proxy.conf.json` (dev through the IRIS origin); `ui/tools/{token-store,session,api}.test.mjs`;
`src/OcuPilot/Test/{Utils,Token,BodyRequest}.cls` (DW-23/DW-24's host, the wire token contract, a `%request`
stub). *Edited:* `ui/src/app/core/strings.ts` (107 keys); `ui/src/app/app.ts` (the session gate);
`ui/src/main.ts` (composition root); `ui/src/styles.scss`; `ui/angular.json` (`serve.options`);
`ui/tools/{angular-json,build-output}.test.mjs`; `src/OcuPilot/Api/{Router,StaticHandler}.cls` (CORS off);
`src/OcuPilot/Kernel/Utils.cls` (DW-24); `src/OcuPilot/Test/Http.cls` (optional body/headers on
`AbsoluteRequest`); EXPERIENCE.md's two existing string rows.

**Review findings.** 38 findings across four layers — 3 high, 9 medium, 13 low, 9 false, 4 maybe-false.
**23 patched** (3 high, 7 medium, 13 low), **4 deferred**, **11 rejected**; every one is logged with its
reason under `## Review Triage Log`. The three high patches were all latent boot- or credential-level
failures the suite could not see: `/\host/x` resolving off-origin past the path guard, a module-scope
`sessionStorage` read that throws where site data is blocked, and `crypto.randomUUID()` being
secure-context-only on the plain-HTTP hostnames an IRIS instance is normally reached at.

**Verification performed.** `npm --prefix ui test` **168/168** green; `npm --prefix ui run build` exit 0 with
the `initial` bundle at **241.91 kB** against the 1 MB budget error; `uv run scripts/check-objectscript.py`
0 problems; `bash scripts/lint-docs.sh` clean. `iris_doc_load` + compile of all 60 classes on
`ocupilot-iris`: clean. `iris_execute_tests` one class per message — `Utils` 9/9, `Token` 9/9, `Static` 15/15,
`Wire` 7/7 — and the `%UnitTest_Result` latest-run-per-class SQL probe reads **200 methods, 200 passed,
0 failed** across `OcuPilot.Test.*`. `curl -X POST /api/ocupilot/login` → `401`, `CONTENT-LENGTH: 0`, no
`WWW-Authenticate`, no `Access-Control-Allow-*`. The patched bundle was installed into the live container
through `docker compose cp` to `/tmp` plus `Install("", 0, <that path>)`, the temp copy removed, and
`/ocupilot/` confirmed serving it; the container was never recreated, restarted or removed.

**Rule 19.** `## Verification` carries **18** `mutation:` lines, at least one per acceptance criterion. The
implementation pass demonstrated 15; this pass added three (the accessibility containers, the narrowed path
guard, the backoff clamp) and re-demonstrated four more by hand — the path guard, the single-flight guard,
the `serve.options` block and the accessibility containers — each applied, observed red, reverted, with
`git status --short` and `git diff --stat` unchanged afterwards.

**Follow-up review recommended: true.** The named risk: the manual browser pass on the live instance was run
against the **pre-patch** bundle. The three high patches all sit on the boot path — `main.ts`'s storage
read, the nonce generator, and the request guard — and their replacements are verified by the node suite, a
clean type-checked build and the re-installed bundle answering at `/ocupilot/`, but not by a second
end-to-end browser pass. A follow-up should repeat the DevTools check: cold tab, wrong password, correct
password, tab duplication.

**Residual risks.** (1) `sign-in.ts` and `app.ts` have no executed test host — DW-93 is 1.9's; their gating
logic is pinned in `session.test.mjs` and their two accessibility containers by a template source scan.
(2) The dev proxy is asserted as configuration; no `ng serve` run exercised it. (3) `password-expired`
renders a branch nothing reaches — a verified negative recorded under `## Verification`, routed to 1.13.
(4) The live container has no `./ui` mount, so the start-path bundle copy is exercised only on a throwaway.
