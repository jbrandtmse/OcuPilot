---
title: 'Story 1.5: The static shell serves the SPA, including deep links'
type: 'feature'
created: '2026-09-11'
status: 'done'
baseline_revision: '19e31b59b1ecfb321e93164b839ca89b6e7a4aca'
baseline_commit: '19e31b59b1ecfb321e93164b839ca89b6e7a4aca'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md'
  - '{project-root}/.claude/rules/objectscript-basics.md'
  - '{project-root}/.claude/rules/objectscript-testing.md'
warnings: ['oversized']
deferred:
  - summary: >-
      The client half of the deep-link criterion has no executed test host: the router wiring,
      the route table and the DeepLink component are pinned only by a manual browser check.
    evidence: |-
      ui/package.json's test script runs `node --test tools/` only; angular.json declares no
      test target and no .spec.ts exists, so nothing executes ui/src/app. Dropping
      provideRouter from main.ts leaves `npm --prefix ui test` and every ObjectScript suite
      green. Closing it means standing up a client test runner (ng test / vitest), which is
      larger than this slice.
    location: >-
      ui/src/app/app.routes.ts, ui/src/app/shell/deep-link.ts, ui/package.json
    severity: medium
  - summary: >-
      Install adopts and repairs whatever web application sits at /ocupilot or /api/ocupilot,
      with no check that install created it, and Uninstall then deletes it.
    evidence: |-
      EnsureWebApplication branches on Security.Applications.Exists(pName) alone, so a
      pre-existing application at either path is rewritten to OcuPilot's dispatch class, auth
      bit, matching role and path, reported as a repair, and removed by Uninstall. The spec's
      Boundaries say "repair only what install created, and report the rest"; AC12 requires a
      repeat install to repair drift at those paths. The two pull opposite ways and the spec
      does not settle which wins, so this is a product call rather than a patch: install has
      no provenance record for these two objects (the Fixture's DW-13 guard uses the demo
      inventory, which these have no equivalent of).
    location: >-
      src/OcuPilot/Install/Installer.cls (EnsureWebApplication)
    severity: medium
---

<intent-contract>

## Intent

**Problem:** OcuPilot has an installer, a traffic gate and an Angular bundle, but no web applications: nothing
serves the shell, nothing answers `/api/ocupilot`, and a pasted or reloaded client route reaches IRIS's own
404. `Api.Router`'s `UrlMap` is empty, `Test.Http` has no application to call, and the built bundle never
leaves the developer's `ui/dist`.

**Approach:** Extend the one installer with the two applications the silent-first design needs — `/ocupilot`,
unauthenticated, dispatching to a new `Api.StaticHandler` that serves the bundle with a deep-link fallback,
containment checks, cache headers and a restrictive CSP; and `/api/ocupilot`, password-authenticated with JWT
at 60/900 seconds, in the vendor's management-portal group, with no application or matching roles and a
router gate that refuses a caller holding no `%Admin_*` resource. Carry the built bundle into the instance on
the container start path, give the client a router so a deep link resolves with its selection intact, and
settle the entity-id wire contract the ledger routed here.

## Boundaries & Constraints

**Always:**

- One installer class, guard-then-act, every `%SYS` hop an explicit save/restore with the restore first in
  every `Catch` and before every failing `Quit` inside the switched region (AD-16, AD-17); no
  `##class(OcuPilot.*)` call while `$NAMESPACE` is `%SYS` — reports are deferred and drained by
  `FlushReports`.
- Both applications are created by `Install()` itself, so the Docker path and the IPM path cannot drift, and
  both are removed by `Uninstall`, named in `AnyObjectExists` and folded into `StateFingerprint`.
- The static handler resolves its root directory **on the instance at request time** and never from anything
  the caller sends (AD-21); it applies a literal `..` rejection **and** a post-normalization prefix
  containment check; it never reflects request text into a response; it streams in bounded chunks.
- Failures render through the one error writer as `{error, reason, code, detail}` with a stable
  dotted-uppercase code that is never a number (AD-12, AD-39). The static handler writes file bytes only.
- Every API path the client uses is absolute from the origin root (AD-20) — the deep-link fallback answers a
  relative one with `index.html`.
- Every gate resolves the **authenticated** user and rejects `UnknownUser` and `_PUBLIC` explicitly, never
  inferring authorization from roles alone (AD-21).
- Class names ≤ 29 characters, `p`/`t` prefixes, `$$$` macros, no hand-written `Storage`, no `%` or `_` in
  names; all project ObjectScript under `src/OcuPilot/`.

**Never:**

- Never build the readiness endpoint or the smoke script (Story 1.17), the sign-in flow or token handling
  (1.6), the descriptor-driven route table (1.9), chrome (1.10), or the IPM manifest (1.16).
- Never grant the API application an application or matching role, and never give either application a role
  beyond the minimum IRIS requires to execute its own dispatch class (see `## Design Notes` → *the privilege
  floor*).
- Never modify a vendor web application, the `%DB_*` public permissions, `UnknownUser`, the Web Gateway
  configuration, or an application at these paths that install did not create — repair only what install
  created, and report the rest.
- Never run `docker compose up`/`down`/`restart` against this repository's compose file; the live `ocupilot`
  container is the owner's.
- Never decode a dispatch path segment twice, and never hand a caller-supplied string to the filesystem.
- Never add a CDN, an inline script, or any runtime evaluation of fetched text to the bundle.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Shell root | `GET /ocupilot/` anonymous | 200, `index.html`, `text/html`, `Cache-Control: no-store, no-cache, must-revalidate`, CSP + `X-Content-Type-Options: nosniff`, nonce substituted | Bundle absent → 503 `unavailable` / `STATIC.NOBUNDLE` |
| Deep link, cold or reloaded | `GET /ocupilot/permissions/users/_SYSTEM?ns=HSCUSTOM` | 200 `index.html`; the client routes to `area=permissions, screen=users, id=_SYSTEM, ns=HSCUSTOM` with the URL unchanged | Same as above |
| Hashed asset (**DW-3**) | `GET /ocupilot/main-<hash>.js` | 200, exact bytes, `application/javascript`, `Cache-Control: public, max-age=31536000, immutable` | Missing → `index.html` (AD-21) |
| Unresolved path | `GET /ocupilot/anything/at/all` | 200 `index.html` | — |
| Traversal attempt | path containing `..`, `$Char(0)`, a backslash, or resolving outside the root | 400 `bad_request` / `STATIC.BADPATH`, input never echoed, no file read | One envelope, nothing streamed |
| Wrong verb on the shell | `POST /ocupilot/x` | 405 through the one error writer with `Allow: GET, HEAD` | — |
| API, anonymous | `GET /api/ocupilot/` with no credentials | 401 from the CSP server before dispatch; no OcuPilot code runs | Empty body, no envelope — see Design Notes |
| API, signed in, no `%Admin_*` | Basic/Bearer as a user holding only `<install db>:R` | 403 `forbidden` / `AUTH.NOADMIN`, reason naming missing administrative privileges | `pContinue = 0`, no handler runs |
| API, signed in, admin | user holding `%Admin_Operate:U` | dispatch proceeds; no route exists yet → 404 `not_found` / `ROUTE.NOTFOUND` | — |
| Entity id over the wire (**DW-31**) | `GET /api/<fixture>/items/<Encode(id)>` for each corpus id | the handler receives the id byte-exact after exactly one `Kernel.EntityId.Decode` | A segment the web server refuses never reaches IRIS; recorded, not worked around |
| `OnPreDispatch` fails (**DW-25**) | gate read throws | exactly one 500 envelope, `code` `INTERNAL`, detail logged not sent | — |
| Framework status with no route (**DW-34**) | `ReportHttpStatusCode(403, $$$OK)` | 403 `forbidden` / `ROUTE.FORBIDDEN` — a slug-derived code, never a number | — |
| Repeat start | second `docker compose up` on the same volume | applications and role unchanged, bundle refreshed, `StateFingerprint` byte-identical | Drift is repaired and reported |
| Bundle not built | `ui/dist` missing at container start | install reports a `warn` naming the directory and continues; health check still goes healthy | Never fails install |

</intent-contract>

## Code Map

**Extend, never duplicate.** Every path below exists and is `done` unless marked *new*.

- `src/OcuPilot/Install/Installer.cls` (2,231 lines) — class doc :15 *"No web application is created here
  (Story 1.5)"*; `Names` :97-126 (production/probe name pairs, refuses any other profile; probe names are
  wholly distinct, never nested); `Install` :340-555 (namespace guard :357, `Names` :367, `LockInstall` :374,
  version read :408-444, `SwitchNamespace("%SYS")` :449, nine ensure steps :453-489 each followed by
  `Set $NAMESPACE = tOrigNS  Quit` on error, `ReportGatewayGap` :492, restore :494, `RunMigrations` :497,
  `EnsureVersion("installed")` :520, unlock :543, `FlushReports` :553); `StartPath` :580-610 →
  `StartPathLocked` :615-637 (`Install("", 1)` :617, demo fixtures :620-633); **`EnsureApplication`
  :1545-1602 is the guard-then-act + drift-repair precedent to copy** (Exists → Get → compare three
  properties → Modify with a `warn` "Repaired…" → else `info`; Create sets `Type`, `Enabled`, `Description`,
  `MatchRoles`, `Routines`); `ReportGatewayGap` :1081-1106 (today emits one fixed line :1092 saying this step
  created no web application, then the timeout; **callers pass one argument** — Test/Version.cls:596, :616,
  Test/GatewayIni.cls:119 — so a created-apps parameter must be optional); `StateFingerprint` :1808-1916
  (13 values folded at :1910, `READFAILED` sentinel); `Uninstall` :2006-2229 (`AnyObjectExists` :1921-1932
  covers 8 objects, the confirmation message :2065 lists them, deletes :2152-2183 each
  `If Exists { Delete  If $$$ISERR { restore  Quit } }`).
- `src/OcuPilot/Install/Fixture.cls` — `CreateWebApp` :243-296 is the only existing
  `Security.Applications.Create` call for a **CSP** application (`Type=2`, `Enabled=0`, `NameSpace`,
  `Description`, :275-279), its DW-13 "exists and we did not create it" guard :246-271, the inventory row
  :284, and its own Gateway-gap line :292 carrying `data.path` — the per-application gap precedent.
- `src/OcuPilot/Api/Router.cls` (170 lines) — `Parameter UseSession = 0` :14; empty `UrlMap` :34-38;
  `OnPreDispatch` :93-133 (install gate :98-113, anonymous rejection :115-120, `ns` resolution :122-127,
  `Catch` :128); `ReportHttpStatusCode` :139-157 (`$$$ISERR` branch :142 = **DW-25**, `Else` branch :146-155 =
  **DW-34**); `Http405` :164.
- `src/OcuPilot/Api/Error.cls` (203 lines) — closed slug enum :20-54, `INSTALL.*` code parameters :56-70 (the
  convention new codes follow), `Render` :85, `RenderInternal` :119, `LogError` seam :145, `Render405` :153,
  `GetSlugForStatus` :179.
- `src/OcuPilot/Api/Response.cls` — with `Api/Error.cls`, the only two files in
  `scripts/check-objectscript.py`'s `WRITE_ALLOWED` (:77-80). A bare `Write` anywhere else fails the check;
  dotted calls (`tStream.OutputToDevice()`) do not.
- `src/OcuPilot/Kernel/EntityId.cls` (34 lines) — `Encode` :21 (`$ZConvert(...,"O","URL")` then `/`→`%2F`),
  `Decode` :31. **DW-31 lives here.**
- `src/OcuPilot/Kernel/Audit/Log.cls` — `Info`/`Warn`/`Error` :16-34, `WriteConsole` probe seam :76.
- `src/OcuPilot/Test/Http.cls` (146 lines) — `MakeRequest` :63 and `RawRequest` :117 always prefix
  `BASEPATH = "/api/ocupilot"` :26 and always send `_SYSTEM`/`SYS` :72-73, :123-124; neither returns response
  headers and `Data.Read()` truncates around 32 KB. Its own header :1-5 names **this story as its first
  consumer**. Overrides live in `^OcuPilotTest(...)` :29-50.
- `src/OcuPilot/Test/Dispatch.cls` — `Invoke(pRouterClass, pUrl, pMethod, pParams, .pBody, .pStatus,
  .pAllowHeader)` :29 calls `DispatchRequest` directly (never `Page()`), stubs `%request`/`%response`, and
  leaves `%response` readable after the call (Envelope.cls:225 reads a header that way).
- `src/OcuPilot/Test/RouterFixture.cls` — 12 fixture routes :38-51 including `/items/:id`; `_fixtureUser`
  override :16-19; :156-160 records that the `Page()`-level path "first runs for real" in this story.
- `src/OcuPilot/Test/Envelope.cls` (228 lines) — `AssertSingleEnvelope` :17 (the `}{` check),
  `AssertExactKeySet` :39, `TestSlugForStatusMapping` :172 (the only existing `GetSlugForStatus` coverage).
- `src/OcuPilot/Test/EntityId.cls` — corpus :13 (`_SYSTEM`, `a/b`, `a b`, `100%`, `café`, `x?y`, `#frag`),
  round trip :17-19, double-decode guard :27. Nothing exercises a browser-encoded input.
- `src/OcuPilot/Test/State.cls` (451 lines) — the throwaway-principal pattern: `#DENIALUSER` :24,
  `#DENIALROLE` :26, role creation with `<install-ns db resource>:RW,%Admin_Operate:U` :79-88, user creation
  :90-96, teardown :111-146. **Its role holds `%Admin_Operate`, so it is not a "no `%Admin_*`" principal, and
  its password is discarded** — this story needs a second, HTTP-usable pair.
- `src/OcuPilot/Test/Installer.cls` (758 lines, already over the ~500-line guidance) — `OnBeforeOneTest`
  :32-47 installs the production **and** probe profiles, `OnAfterOneTest` :49-52 uninstalls probe;
  `TestSecondRunRepairsDriftedApplication` :195 is the drift-repair precedent;
  `Test/Demo.cls:614` (`TestDemoWebAppFixtureCreatedWhenAbsent`) is the property-by-property web-application
  assertion precedent and `Demo.cls:703-713` the gap-line assertion helper.
- `scripts/container-start.sh` (254 lines) — namespace resolution and `MarkInstalling` :102-112, demo flag
  read from `/proc/1/environ` :160-168, load/compile + `StartPath` session :191-202, outcome handling
  :212-253, here-doc rules :177-190 (one statement per line, no `$$$`, escape every `$`).
  `scripts/container-health.sh` — start-key marker :56-64, `GateStatus()` :78-84.
- `docker-compose.yml` — pinned image :7, `OCUPILOT_DEMO` :25, `./src` and `./scripts` read-only mounts
  :29-30, `--after` hook :34, health check :35-43.
- `ui/angular.json` — `baseHref "/ocupilot/"` :19, `outputHashing "all"` :20, production sets **only** budgets
  :26-34, so `optimization` defaults to true and critical-CSS inlining is on.
- `ui/src/index.html` — `<base href="/ocupilot/">` :6, `<app-root>` :10. `ui/src/main.ts` — zoneless
  bootstrap, **no router**. `ui/src/app/app.ts` — inline template with `{{ STRINGS.productName }}` and a
  `class` attribute, which `ui/tools/build-output.test.mjs:150-159` requires to keep existing.
- `ui/tools/` — `build-output.test.mjs` runs a real `npm run build`, **deletes `ui/dist` first (:55)**, and
  asserts hashed `main-*.js`/`styles-*.css` (:71-94), five `media/*.woff2` (:108-122) and no external fetches
  (:124-141); `compose.test.mjs` asserts compose by single-pattern text match with no exact volume list;
  `angular-json.test.mjs` asserts builder, hashing and base href only; `client-lint.mjs` rejects literal text
  nodes and literal/unknown-key interpolations but **allows any data binding** (:229-245);
  `strings.mjs`/`strings.test.mjs` pin the `STRINGS` key set to EXPERIENCE.md's table, so **no new string key
  may be added in this story**.
- `README.md` — the throwaway-container procedure at :294-342 (scratch compose `name: ocupilot-fresh`, ports
  `1975:1972`/`52776:52773`, `-f <scratch>/compose.yml up -d --wait` … `down -v`); it has no `ui` mount yet.

**Live ground truth (verified 2026-09-11; vendor settings read-only on `ocupilot-iris`, behaviour on a
throwaway `intersystems/irishealth-community:2026.2` container on ports 52778/1977, torn down after):**

- `Security.Applications` has no `Roles` property: "application roles" are `MatchRoles` entries of the form
  `:Role`. JWT defaults are already 60/900. `/api/admin` and `/api/interop-editors` are the JWT-enabled
  management applications; 24 applications carry `GroupById = %ISCMgtPortal`, the only group in use.
  `/ui/interop` has **no dispatch class** — it is plain CSP file serving with hash routing, so it is a
  precedent for "unauthenticated", not for a deep-link fallback.
- `UnknownUser` is enabled with **no roles**; `%DB_HSCUSTOM` has no public permission; HSCUSTOM's routines
  and globals database is `HSCUSTOM`.
- An unauthenticated application whose dispatch class is compiled in HSCUSTOM and which carries **no**
  `MatchRoles` answers **500** with `ERROR #5002 … <PROTECT>^%CSP.REST.1 ^|^^/usr/irissys/mgr/HSCUSTOM/|…` —
  a body that leaks the database directory to an anonymous caller. The same class without an `AccessCheck`
  override answers a bare **403**. With `MatchRoles = ":%DB_HSCUSTOM"` the same request answers **200** as
  `UnknownUser` holding that role. An `AccessCheck` override cannot rescue it: the override itself is the
  code that cannot be loaded.
- A path segment reaches a `%CSP.REST` class **already percent-decoded exactly once and UTF-8 decoded**; dot
  segments are resolved and the query string stripped before dispatch; `%2F` and `%00` are refused by the
  container's own Apache before IRIS sees them; `%25` survives (`/a%252Fb` → `a%2Fb`); the raw form remains
  in `REQUEST_URI`.
- On a password-only application an anonymous request is refused **before** `OnPreDispatch`; `/login`,
  `/refresh`, `/logout` are intercepted by the CSP server before dispatch and return
  `access_token, refresh_token, sub, iat, exp` with `exp-iat` of 60 s and 900 s. A signed-in user without
  read on the code database never reaches `OnPreDispatch` either.
- `$System.Util.DataDirectory()` is `/durable/iris/` in the container and the install directory on an
  ordinary install; `/usr/irissys/csp` is **not writable**, `/durable/iris/csp` is. A new `/ocupilot` path
  needs no Web Gateway change (`[APP_PATH_INDEX]` maps `/` to IRIS).
- Angular 22.1.5 production inlines critical CSS and emits `<link … media="print" onload="this.media='all'">`
  plus an 18 KB inline `<style>`; `script-src 'self'` blocks that `onload`. Angular injects component styles
  as runtime `<style>` elements, and every `@angular/material` component uses `ViewEncapsulation.None`, so a
  strict `style-src` needs a per-response nonce (`ngCspNonce` / `CSP_NONCE`) or `'unsafe-inline'`. The router
  needs only `provideRouter` plus the existing `<base href>`; `withComponentInputBinding()` exists.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Api/StaticHandler.cls` — *new* `OcuPilot.Api.StaticHandler Extends %CSP.REST`
  (`Parameter UseSession = 0`; `UrlMap` with one `GET` and one `HEAD` route on `/(.*)`; `Http405` and
  `ReportHttpStatusCode` overridden to delegate to `Api.Error` exactly as `Api.Router` does; **no**
  `AccessCheck` override). Public `RootDirectory(pApplication)` resolves the bundle directory from
  `$System.Util.DataDirectory()` and the matched application name and nothing else; `ResolvePath` applies the
  literal rejection set and the post-normalization prefix containment check against
  `%File.NormalizeDirectory(root)` (keep the trailing separator — the sibling-directory gap in the harvested
  original); a resolved regular file is streamed with `%response.NoCharSetConvert = 1` through
  `%Stream.FileBinary.OutputToDevice()`; a directory or an unresolved path falls back to `index.html`; the
  `index.html` response substitutes a freshly generated nonce for the placeholder and sets the CSP header.
  Rationale: AD-21, AD-47, the harvest plan's `AdminUIHandler` → `Api/StaticHandler.cls` move.
- `src/OcuPilot/Api/Error.cls` — add the code parameters `STATIC.BADPATH`, `STATIC.NOBUNDLE` and
  `AUTH.NOADMIN` beside the `INSTALL.*` ones. No new slug, no new envelope field. Rationale: AD-12, AD-39.
- `src/OcuPilot/Api/Router.cls` — add the administrative-privilege gate to `OnPreDispatch` after the
  anonymous rejection: the caller must hold at least one `%Admin_*` resource at `USE`, checked in the calling
  process against a closed list held as a class parameter; otherwise 403 `forbidden` / `AUTH.NOADMIN`.
  Document, at the method, that a caller lacking read on the install database is refused by the framework
  before this method runs. Rationale: the FR-65 resource gate, AD-8.
- `src/OcuPilot/Kernel/EntityId.cls` — settle **DW-31**: `Encode` produces the wire segment (UTF-8 first,
  then percent-encoded twice, so the CSP server's own single decode leaves exactly what `Decode` expects);
  `Decode` percent-decodes once and UTF-8-decodes, and is called exactly once per id. Document the wire
  contract and that `%2F` is refused by the web server, which is why the second encode exists.
- `src/OcuPilot/Install/Installer.cls` — extend the one installer: `Names` gains the shell application, the
  API application, the shell role and the shell directory (probe values wholly distinct); new ensure steps
  `EnsureShellRole`, `EnsureShellApplication`, `EnsureApiApplication` inside the existing `%SYS` window,
  each guard-then-act with drift repair and a deferred report, each recording the path in a created-apps
  array; `ReportGatewayGap` gains that optional array and emits one line per created application carrying
  `data.path`; `EnsureShellFiles` copies a bundle from a caller-named source directory into the shell
  directory, replacing what is there, and reports a `warn` (never an error) when the source is absent;
  `StartPath` gains the bundle-source argument and passes it; `StateFingerprint` folds both applications'
  asserted settings; `Uninstall`, `AnyObjectExists` and the confirmation message cover both applications, the
  role and the shell directory. Rationale: AD-17, AD-25's separation, AD-38's ordering.
- `scripts/container-start.sh` — pass the bundle directory (`/opt/ocupilot/ui/dist/ocupilot-ui/browser`) to
  `StartPath`, and log one line when it is absent. Keep the here-doc rules at :177-190.
- `docker-compose.yml` — add `./ui:/opt/ocupilot/ui:ro` (mount `ui/`, not `ui/dist`, because
  `ui/tools/build-output.test.mjs` deletes `ui/dist` on every `npm test` and would break a mount pinned to
  it). No other change.
- `ui/angular.json` — set the production `optimization` object explicitly with `inlineCritical` off, so the
  emitted `index.html` carries no inline `<style>` and no `onload` handler. Spell out every key: omitted keys
  in the object form mean false.
- `ui/src/index.html` — add the CSP nonce placeholder attribute to `<app-root>`.
- `ui/src/main.ts` — add `provideRouter(routes)`.
- `ui/src/app/app.routes.ts` — *new*: `''`, `:area/:screen`, `:area/:screen/:id` and a wildcard, all to the
  placeholder below. Story 1.9 replaces this table with the descriptor registry; keep it that small.
- `ui/src/app/shell/deep-link.ts` — *new* placeholder component exposing the resolved `area`, `screen`,
  decoded `id` and `ns` as data attributes so a browser check can read them. No new `STRINGS` key.
- `ui/src/app/core/entity-id.ts` — *new*: the client mirror of the codec (encode twice, decode once), the
  single place the client encodes or decodes an id.
- `ui/src/app/app.ts` — add `<router-outlet />` **beside** the existing `{{ STRINGS.productName }}` element,
  which `build-output.test.mjs:150-159` still requires.
- `ui/tools/build-output.test.mjs` — assert the built `index.html` has no inline `<script>`, no inline
  `<style>`, no `onload=` attribute, and carries the nonce placeholder. Rationale: these are the build
  settings the CSP depends on, and nothing else pins them.
- `ui/tools/compose.test.mjs` — assert the new read-only `ui` mount and the bundle argument in the hook.
- `src/OcuPilot/Test/Http.cls` — extend (this story is its first consumer): an absolute-path request that
  optionally sends no credentials or a caller-supplied principal, returns response headers, and reads a body
  large enough for the bundle.
- `src/OcuPilot/Test/WebApp.cls` — *new*: every asserted setting of both applications and the shell role
  after install, drift repair on a second run, fingerprint sensitivity, the Gateway-gap lines, and
  uninstall's removal.
- `src/OcuPilot/Test/Static.cls` — *new*: the static handler over the wire against the probe profile's shell
  application (root, deep link, hashed asset, unresolved path, wrong verb, bundle absent, headers), plus
  in-process `ResolvePath` assertions over a hostile-input corpus the web server would never forward.
- `src/OcuPilot/Test/Wire.cls` — *new*: the API application over the wire (anonymous, no-`%Admin_*`
  principal, administrative principal, single envelope), and the **DW-31** corpus replayed through a
  test-owned fixture application pointed at `Test.RouterFixture`, created and removed by the class.
- `src/OcuPilot/Test/Envelope.cls` + `src/OcuPilot/Test/PreFault.cls` — *new fixture, extended suite*:
  **DW-25**'s `$$$ISERR(pSC)` branch through a router fixture whose `OnPreDispatch` returns a failing status,
  and **DW-34**'s `Else` branch asserted as a slug-derived code.
- `src/OcuPilot/Test/EntityId.cls` — extend the corpus with the wire round trip (encode → the server's own
  single decode → `Decode`) and with a browser-encoded input.
- `README.md` — the two applications and their settings, the `npm run build` step and where the bundle must
  be for the container to serve it, the read-on-the-install-database requirement for API callers, and the
  `ui` mount in the throwaway procedure at :294-342.

**Acceptance Criteria:**

- **AC1 (static application, AD-28).** Given install has run, when `/ocupilot`'s settings are read, then it
  is enabled in the install namespace, unauthenticated, dispatches to `OcuPilot.Api.StaticHandler`, serves no
  files itself, carries the bundle directory as its path, carries **no application or matching role beyond
  the single purpose-built read-only role IRIS requires to execute that dispatch class** (AD-21, amended by
  the owner's decision of 2026-09-11), and the client bundle it serves declares
  the non-root base href `/ocupilot/` set at build time.
- **AC2 (API application, FR-65).** Given install has run, when `/api/ocupilot`'s settings are read, then it
  is enabled in the install namespace, password-authenticated, JWT-enabled with a 60-second access and
  900-second refresh timeout, joined to the vendor's `%ISCMgtPortal` group, dispatching to
  `OcuPilot.Api.Router` whose `UseSession` parameter is 0, with **no** application or matching role and no
  application resource — and an install-time test asserts every one of those settings rather than leaving
  them to inspection.
- **AC3 (deep link).** Given the built bundle is installed, when
  `/ocupilot/permissions/users/_SYSTEM?ns=HSCUSTOM` is loaded cold and then reloaded, then the server answers
  `index.html` both times and the client resolves that route with `area`, `screen`, `id` and `ns` intact and
  the address unchanged — no redirect to the shell root.
- **AC4 (path safety, AD-21).** Given any request naming a file, when the handler resolves it, then it
  applies both a literal `..` rejection and a post-normalization prefix containment check, serves `index.html`
  for anything unresolved, refuses anything that escapes the root with one envelope that never echoes the
  request, accepts no filesystem path from a caller, and streams in bounded chunks.
- **AC5 (content security, AD-47).** Given the served bundle, when the page loads in a browser, then the
  document response carries a Content-Security-Policy naming only the instance's own origin, with no CDN
  reachable, every library vendored, no inline or fetched script evaluated at runtime, and the browser
  console records **zero** policy violations.
- **AC6 (cache policy, DW-3).** Given a container restart that installs a new bundle, when a browser holding
  the old bundle reloads, then it receives the current `index.html` because that response is never cached,
  while hashed assets carry immutable caching so the old bundle stays coherent until the reload.
- **AC7 (authenticated-user gates, AD-21).** Given the static application is unauthenticated by design, when
  any OcuPilot gate evaluates a caller, then it resolves the authenticated user and rejects `UnknownUser` and
  `_PUBLIC` explicitly rather than inferring authorization from roles, and the static application serves only
  files — it exposes no data route, reads no OcuPilot global, and answers no JSON but its own error envelope.
- **AC8 (administrative gate).** Given a signed-in caller who holds no `%Admin_*` resource, when they call the
  API, then they receive one 403 envelope with the code `AUTH.NOADMIN` and a reason naming the missing
  administrative privilege, while a caller holding one reaches dispatch — observed as the route-not-found
  envelope, since this story adds no route.
- **AC9 (entity ids over the wire, DW-31).** Given each id in the shared corpus, when the client encodes it,
  the web server and `%CSP.REST` deliver it, and the route target decodes it exactly once, then the handler
  receives the original id byte-for-byte — and any corpus member the web server refuses outright is recorded
  as a stack limitation with the encoding that avoids it, not worked around in a slice.
- **AC10 (envelope branches, DW-25 and DW-34).** Given `OnPreDispatch` returns a failing status, when the
  framework reports it, then exactly one internal-error envelope reaches the wire with the detail logged and
  not sent; and given a framework status with no matching route, when it is reported, then the envelope's
  code is derived from the slug and is never a number.
- **AC11 (bundle delivery).** Given a container start whose bundle directory holds a built bundle, when the
  start path completes, then the shell serves that bundle's `index.html`; and given the bundle directory is
  absent or empty, then install reports one `warn` naming the directory, completes, and the shell answers
  `STATIC.NOBUNDLE` rather than failing the start or the health check.
- **AC12 (repeat-safe and removable, NFR-9, AD-17).** Given an instance already carrying both applications,
  when install runs again, then net state is unchanged — `StateFingerprint` byte-identical, one application
  per path, drift repaired and reported, and the Gateway-registration gap reported for each application this
  run created; and when uninstall runs, both applications, the shell role and the shell directory are gone.

## Design Notes

### Governing architecture decisions (Rule 6)

`AD-28` (the two applications and their exact settings; silent-first depends on them), `AD-21` (the static
application is unauthenticated, carries a dispatch class, serves only files; the handler is the one place a
caller-supplied name resolves to a file, under both checks; anonymous does not mean unprivileged), `AD-47`
(the static origin is hostile ground: restrictive CSP, no CDN, no runtime evaluation, no reflected input),
`AD-20` (the deep-link fallback makes a relative API path fail silently, which is why every API path is
absolute), `AD-13` (one shared id codec, one path segment, the scoped triple), `AD-12` and `AD-39` (one
response writer, one flat envelope, a stable dotted-uppercase code), `AD-17` (one installer class, install at
container start, guard-then-act, reports the Gateway registration gap), `AD-38` (install completes before the
API serves; the static application is deliberately outside that gate so the shell can render the install
state), `AD-16` (explicit namespace save and restore), `AD-8` (privilege checked in the calling process at
call time), `AD-10` (OcuPilot's own web applications are in the prohibited set — creation and removal are
install, never a tool), `AD-9` (OcuPilot's code lives in the install namespace's ordinary database, which is
what makes the privilege floor below a real constraint), `AD-45` (the readiness endpoint is 1.17's; see
below), `AD-27` (the pinned image), `AD-18` (nothing in the install path may assume IPM). Consistency
Conventions: *REST route ordering*, *Error shape*, *Ids and keys*, *Client asset homes*, *Tests*, *Names
never inherited from siblings* (the harvested handler keeps its call sites, never its names or its
`sa-static` path). Stack: Angular 22.1.x, `@angular/build`, `outputHashing: all`.

### The privilege floor — why the run is blocked

Database READ is routine-execution permission (AD-9 says so, and the throwaway proved it): an anonymous
request cannot load `OcuPilot.Api.StaticHandler` from the install namespace's database unless the process
holds read on it. AC1's "carries no application or matching roles" and AD-21's "still carries a dispatch
class" cannot both hold on the image this project pins. The recommendation, the alternatives and the evidence
are in `## Auto Run Result`; the rest of this spec is planned on the recommendation.

Containment argument for the recommended role: it grants read on the install namespace's ordinary database
only, for requests to `/ocupilot` only; OcuPilot's own state lives in the separate protected database (AD-9)
and is not reachable through it, and the handler reads no global at all.

### Decisions this story records rather than decides

- **Readiness hosting (1.17), a `decision`.** The readiness endpoint must answer an unauthenticated caller
  (AD-45). Verified: a password-only application refuses anonymous callers before any OcuPilot code runs, so
  `/api/ocupilot` cannot host it; and the static application serves only files (AC7). What 1.17 inherits is
  therefore: a third, unauthenticated web application (a path under `/api/ocupilot/`, which IRIS resolves by
  longest prefix) with its own dispatch class — the recommendation — or an amendment of AC2 to enable
  unauthenticated access on the API application and admit only the readiness route. Nothing in this story
  forecloses either; the third application would need the same privilege floor as the shell.
- **The entity-id wire contract (DW-31), settled here.** The web server delivers a segment already decoded
  once, `%2F` never arrives at all, and Latin-1 output does not survive the trip (`%E9` came back as `?`).
  Encoding twice on write and decoding once on read is the only scheme in which every corpus member —
  including a web application name such as `/csp/myapp` — survives. This has architectural weight: the lead
  writes it into the spine against AD-13 (Rule 20).
- **`index.html` for a missing asset.** AD-21 says "serving `index.html` for anything unresolved", so a
  missing hashed asset answers `index.html` with 200. The cost is a MIME-type error in the browser rather
  than a 404 for a genuinely missing chunk; the vendor's own Angular handler 404s asset-shaped paths instead.
  Recorded as an AD-governed trade-off, not smoothed over: changing it is a spine amendment, not a slice
  decision.
- **What an anonymous API request actually returns.** 401 with an empty body and no `WWW-Authenticate`
  challenge, because `%CSP.REST.Login`'s generated dispatch map cannot load the router class as the pre-login
  `UnknownUser` (verified). The refusal is correct and no OcuPilot code runs; `/login` is unaffected because
  the CSP server intercepts it before dispatch (which is what 1.6 depends on). A signed-in caller lacking
  read on the install database is likewise refused by the framework with a bare 403 — OcuPilot cannot render
  an envelope for a request whose code never loads, and the README says so.

### Ledger inbox (Rule 17)

- **DW-3** — addressed in part, in AC6 and the matrix: `index.html` is never cached and hashed assets are
  immutable, so a restart that installs a new bundle is one reload away. The other half — the API returning
  its build stamp and the client prompting a mismatched bundle to reload — belongs to Story 1.8's identity
  and version guard, which this spec names under `Consumed-by`; 1.4 already stores the build identity on the
  version row for it.
- **DW-25** — addressed: AC10 and `Test/PreFault.cls`.
- **DW-31** — addressed: AC9, the codec change, and the decision above.
- **DW-34** — addressed: AC10's second half, plus the recorded finding that the framework's own 403
  (`AccessCheck`) never reaches `ReportHttpStatusCode`, so the `Else` branch's only production caller is
  `Http403()` for an application with no dispatch class.

### Integration ACs, `Consumes`, `Consumed-by` (Rules 1 and 2)

**Integration ACs:** AC3 (the browser, a consumer this story does not own, resolves a deep link the handler
answered) and AC8 (`Test.Http` calls the API application over the wire as a purpose-built principal and
observes the envelope), both asserted at the consumer's surface, never by reading the handler's internals.

**Consumes:** `Install.Installer` (the one installer and its report/lock/fingerprint machinery),
`Kernel.State.Base` naming parameters, `Api.Router`, `Api.Error`, `Api.Response`, `Kernel.EntityId`,
`Kernel.Audit.Log`, `Test.Http`, `Test.Dispatch`, `Test.RouterFixture`, `Test.Envelope`, `Test.State`'s
throwaway-principal pattern, `ui/src/app/core/strings.ts`.

**Consumed-by:** **1.6** (silent-first sign-in — the API application's JWT, group and no-session settings,
and the fact that `/login` bypasses dispatch), **1.7** (sign-out on the same application), **1.8** (the
identity and version guard, and DW-3's build-stamp prompt), **1.9** (the descriptor registry replaces
`app.routes.ts`; the client id codec is the mirror it uses), **1.10** (chrome inside the shell — and the
first consumer of the CSP nonce, because Material injects styles at runtime), **1.13** (error rendering from
this envelope), **1.16** (the IPM manifest declares both applications and copies the same built bundle into
the same directory), **1.17** (the smoke script and the readiness endpoint; CI builds the bundle this story
serves), **3.7** (nothing here precludes the one read-only/kill-switch enforcement point).

## Verification

Every check below names its pinning test; the implement stage fills in each `mutation:` line when it
demonstrates red (Rule 19).

**Where each check runs.** The live `ocupilot` container (web 52774, SuperServer 1973) is the owner's and
must not be recreated, removed or restarted: no `docker compose up`/`down`/`restart` against this
repository's `docker-compose.yml`. On the live instance, run only idempotent or read-only work through the
IRIS MCP tools with `server: "ocupilot-iris"` — load and compile `src/OcuPilot/`, re-run `Install("")` (the
production install is idempotent and is what the live instance is meant to carry), and run the `%UnitTest`
classes. Everything on the install path or destructive — a first install on an empty volume, the start hook,
the health check, the bundle copy, `Uninstall`, and the whole-container behaviour behind AC11 and AC12 —
runs **only** on a throwaway: a scratch compose project with its own project name, container name, host
ports (never 52774 or 1973) and scratch volume, per `README.md` :294-342, torn down with `down -v`.

**One test class per tool call.** Every party that runs these tests sends one `iris_execute_tests` call per
message, waits for it to land in `%UnitTest_Result`, and never re-submits on a client-side timeout
(`.claude/rules/objectscript-testing.md`, "Never run two test classes at once"). Read totals from
`%UnitTest_Result` before calling a suite green.

**Commands:**

- `bash scripts/lint-docs.sh` — expected: clean for every authored Markdown file this story touches.
- `python3 scripts/check-objectscript.py` — expected: seven checks pass, including the write-discipline check
  the static handler must satisfy without a bare `Write`.
- `npm --prefix ui run build` — expected: builds; the emitted `index.html` carries no inline script or style,
  no `onload`, and the nonce placeholder.
- `npm --prefix ui test` — expected: `build-output`, `compose`, `angular-json`, `client-lint`, `strings`,
  `design-tokens`, `typography` and `version-guard` all green.
- `iris_execute_tests` per class, one per message: `OcuPilot.Test.WebApp`, `OcuPilot.Test.Static`,
  `OcuPilot.Test.Wire`, `OcuPilot.Test.EntityId`, `OcuPilot.Test.Envelope`, `OcuPilot.Test.Installer`,
  `OcuPilot.Test.Version`, `OcuPilot.Test.Routing`, `OcuPilot.Test.Gate`, `OcuPilot.Test.Demo` — the last
  five as the regression set.

**Per-AC pinning tests:**

- AC1 — `OcuPilot.Test.WebApp` (shell settings, property by property).
  `mutation: Installer.EnsureShellApplication asserts ServeFiles = 1 instead of 0 → WebApp.TestShellApplicationSettings`
- AC2 — `OcuPilot.Test.WebApp` (API settings, including the JWT timeouts, the group, and the empty
  `MatchRoles`).
  `mutation: Installer.JWTACCESSSECONDS 60 → 300 → WebApp.TestApiApplicationSettings`
- AC3 — server half: `OcuPilot.Test.Static` (deep link answers `index.html` over the wire); client half: a
  browser check on the live instance through the chrome-devtools tools — load
  `http://localhost:52774/ocupilot/permissions/users/_SYSTEM?ns=HSCUSTOM`, assert the address is unchanged
  after bootstrap and the placeholder's resolved selection matches.
  `mutation: StaticHandler.ResolvePath answers "reject" instead of "index" for an unresolved path → Static.TestDeepLinkAnswersTheShellDocument`
- AC4 — `OcuPilot.Test.Static` (in-process `ResolvePath` corpus plus the over-the-wire fallback rows).
  `mutation: the literal rejection line deleted from StaticHandler.ResolvePath → Static.TestResolvePathRefusesHostileInput (backslash and colon rows)`
- AC5 — the same browser check, asserting zero CSP violations in the console, plus
  `ui/tools/build-output.test.mjs` for the build settings the policy depends on.
  `mutation: ui/angular.json production inlineCritical false → true → build-output.test.mjs "no inline script, no inline style, no onload handler, and the nonce placeholder"`
- AC6 — `OcuPilot.Test.Static` (cache headers on `index.html` and on a hashed asset).
  `mutation: StaticHandler.INDEXCACHECONTROL and ASSETCACHECONTROL swapped → Static.TestHashedAssetIsServedByteExactAndImmutable`
- AC7 — `OcuPilot.Test.Routing` (existing anonymous-placeholder rejections) plus `OcuPilot.Test.Wire`.
  `mutation: Router.OnPreDispatch's UnknownUser/_PUBLIC condition replaced by a constant false → Routing.TestPreDispatchDenialRejectsUnknownUser`
- AC8 — `OcuPilot.Test.Wire` (two purpose-built principals over the wire; the password is kept for HTTP, the
  role holds only read on the install database, and neither test uses `New $ROLES`).
  `mutation: Router.OnPreDispatch's HoldsAdminResource condition replaced by a constant false → Wire.TestAdministrativeGateSeparatesTheTwoPrincipals`
- AC9 — `OcuPilot.Test.EntityId` (corpus, including a browser-encoded input), `OcuPilot.Test.Wire` (the same
  corpus over the wire through the fixture application) and `ui/tools/entity-id.test.mjs` (the client mirror
  against the same table).
  `mutation: EntityId.Encode percent-encodes once instead of twice → EntityId.TestCorpusSurvivesTheWireTrip`
- AC10 — `OcuPilot.Test.Envelope` with `OcuPilot.Test.PreFault`.
  `mutation: Router.ReportHttpStatusCode's final branch emits "ROUTE." _ tStatus → Envelope.TestFrameworkStatusWithNoRouteRendersASlugDerivedCode`
- AC11 — throwaway container: bring it up with and without a built bundle and assert the shell's answer and
  the install report each time; plus `OcuPilot.Test.WebApp` for the install report itself.
  `mutation: Installer.EnsureShellFiles returns an error instead of a warn for a named but absent source → WebApp.TestAbsentBundleSourceIsAWarnAndNeverAnError`
- AC12 — `OcuPilot.Test.WebApp` (second run, fingerprint, uninstall) plus the throwaway's repeat start.
  `mutation: Installer.EnsureWebApplication returns early when the application exists → WebApp.TestSecondRunRepairsDriftedApplication`

**Manual checks:**

- On the throwaway only: `docker compose -f <scratch>/compose.yml up -d --wait` returns 0 with the health
  check green, `/ocupilot/` and a deep link both answer `index.html` on the scratch port, the API answers 401
  anonymously, and `down -v` removes it.
- The live container's `docker inspect ocupilot --format '{{.State.Status}} {{.State.StartedAt}}
  {{.RestartCount}}'` is identical before and after all verification.

## Auto Run Result

Status: done
Blocking condition: none

**Implemented.** Install now creates OcuPilot's two web applications and the shell's one purpose-built
read-only role, copies the built client bundle into the shell application's own directory on the container
start path, and removes all four on uninstall. A new `Api.StaticHandler` serves that bundle unauthenticated
with the deep-link fallback, both AD-21 containment checks, DW-3's cache policy and a per-response CSP nonce;
`Api.Router` gained the FR-65 administrative gate; `Kernel.EntityId` settled DW-31 as encode-twice /
decode-once; and the client gained a router, a deep-link placeholder and the mirror of the codec.

**Files changed** (28 + 1 added at review): `Api/StaticHandler.cls` *new* (the shell's dispatch class);
`Api/Error.cls` (three machine codes); `Api/Router.cls` (`ADMINRESOURCES`, `HoldsAdminResource`, the gate);
`Kernel/EntityId.cls` (the wire contract); `Install/Installer.cls` (`Names`, `EnsureShellRole`,
`EnsureShellFiles`, `CopyTree`, `EnsureShellApplication`, `EnsureApiApplication`, `EnsureWebApplication`,
`EnsureSqlPrivileges`, `ReportGatewayGap`, `StateFingerprint`, `AnyObjectExists`, `Uninstall`);
`scripts/container-start.sh` (the bundle argument, stdout-only messages, captured session stderr);
`docker-compose.yml` (the read-only `ui` mount); `README.md` (both applications, the bundle, the throwaway
procedure); `ui/angular.json`, `ui/src/index.html`, `ui/src/main.ts`, `ui/src/app/app.ts`,
`ui/src/app/app.routes.ts` *new*, `ui/src/app/shell/deep-link.ts` *new*, `ui/src/app/core/entity-id.ts` *new*;
tests `Test/{WebApp,Static,Wire,PreFault}.cls` *new*, `Test/{Http,Dispatch,EntityId,Envelope,Routing,
InstallerProbe}.cls` extended, `ui/tools/{build-output,compose,angular-json}.test.mjs` extended and
`ui/tools/entity-id.test.mjs` *new*.

**Two defects found live during implementation, both fixed here.** (1) `Kernel.State.Base`'s guarded reads
run dynamic SQL, which enforces SQL privileges the escalation role did not hold, so the install gate answered
`INSTALL.INSTALLING` forever to every caller without `%All` — invisible while every test ran as `_SYSTEM`.
`EnsureSqlPrivileges` grants the protected schema to that one role. (2) `/iris-main` treats any stderr from
its `--after` command as a failed start (controlled probe on the pinned image), so three pre-existing
"carrying on" branches in the start hook would have stopped the container; every message now goes to stdout
and both `iris session` calls capture their own stderr.

**Review findings: 51 across four layers — 0 high, 17 medium, 34 low.** 21 grouped entries were patched
(9 at medium, 12 at low), 2 deferred, 16 rejected. Every row, with its verdict and evidence, is in
`## Review Triage Log` below. Rejected findings and why, in one line each: the new install step's
hard-failure path and its unspecified status (no realistic principal can create databases and roles but not
`GRANT`); the duplicated framework-error overrides in the two dispatch classes (consolidating adds public
surface to `Api.Error` and belongs with 1.13); `RootDirectory`'s non-injective name mapping (only install
creates these applications, and it uses fixed names); the absent `Referrer-Policy` / `Permissions-Policy` /
`COOP` / `X-Frame-Options` (beyond AC5, and `frame-ancestors 'none'` already covers framing); a mid-stream
write failure appending an envelope to partial bytes (needs a local file to vanish mid-response); the
over-large-document path reusing `STATIC.NOBUNDLE` (1 MB limit against a 689-byte document, and the audit
line records the real cause); the production shell not being driven over the wire by the suite (same handler
as the probe, and the browser check and the throwaway both drive it); `Test.EntityId.ServerDecode`
duplicating `Decode` (disclosed in the class doc and validated by `Test.Wire`); tests hardcoding names
`Names` owns (a public accessor is new surface); a zero-byte or placeholder-less `index.html` (the build
pins the placeholder and the clearing step is now guarded); a delivered segment that is not valid UTF-8
decoding to `?` (no route consumes an id until 1.9, and changing `Decode`'s contract is that story's);
`ROUTE.BAD_REQUEST` from an underscore-bearing slug (the branch's only production caller is `Http403`); the
spec's "omitted keys mean false" claim about `@angular/build` (a spec edit, and both the config and the
emitted artifact are now pinned); and four intent-alignment observations that describe surfaces the spec
itself designates as manual or throwaway checks.

**Follow-up review recommended: true.** The named unverified risk: the patch pass added three new guards on
the install path whose red has not been observed — `EnsureShellFiles`' "the target directory could not be
cleared" and "the source is the target" branches, and `Uninstall`'s "the bundle directory could not be
removed" branch. Each was reasoned from a discarded return value rather than from a reproduced failure, and
no test drives them; a fresh throwaway confirmed only that the success path still works.

**Verification performed.** `bash scripts/lint-docs.sh` clean (18 files, 0 issues);
`python3 scripts/check-objectscript.py` 0 problems; `npm --prefix ui run build` clean;
`npm --prefix ui test` 117/117. `%UnitTest`, one class per tool call, waiting for each to land: all 22
OcuPilot test classes green, 176 methods, 0 failures, confirmed by the `%UnitTest_Result` latest-run-per-class
SQL probe rather than from the runner envelope. Browser check on the live instance (chrome-devtools):
`/ocupilot/permissions/users/_SYSTEM?ns=HSCUSTOM` resolves `area/screen/id/ns` cold and after a
cache-ignoring reload with the address unchanged, the nonce is substituted, and the console records zero
policy violations. Two throwaway containers (`ocupilot-fresh` before the patches, `ocupilot-fresh2` after,
own project and container names, ports 52776/1975 and 52778/1977, torn down with `down -v` and confirmed
gone): first start with no bundle → `up -d --wait` exit 0, healthy, install `warn` naming the source
directory, `/ocupilot/` `STATIC.NOBUNDLE`, API 401 anonymous; bundle added and restarted → healthy, document
served with its CSP, nonce and `no-store`, `/ocupilot/index.html` served the same way, hashed asset
`immutable`, deep link 200, and `StateFingerprint` byte-identical across the two starts. The live `ocupilot`
container's state line was `running 2026-09-11T18:14:41.310714044Z 0` before and after everything.

**Residual risks.** (1) The client half of AC3 and AC5 rests on a manual browser check — deferred, with the
reason. (2) Install adopts whatever application sits at OcuPilot's two paths — deferred, as a product call
the spec does not settle. (3) The 405 `Allow` header reads `GET,OPTIONS,HEAD` where the matrix says
`GET, HEAD`: `%CSP.REST` pushes `OPTIONS` onto every route's verb list in its generated dispatch map
(`irislib/%CSP/REST.cls`:369, :625) and the application genuinely answers it, so trimming the header would
advertise a refusal that is not real; the test asserts `GET` and `HEAD` are both named. (4) `%UnitTest`
classes install and uninstall the same probe profile, so the "one test class per tool call" rule in
`## Verification` is a property of how the suite is run, not of the code.

**Resolved by the owner, 2026-09-11: option 1.** The static application carries one purpose-built read-only
matching role. `epics.md` AC1 is amended at its origin; AD-21 (the privilege floor), AD-45 (readiness is a
third unauthenticated application, so Story 1.17 inherits a decision rather than re-deriving it) and AD-13
(the encode-twice/decode-once wire contract) are amended in the spine, memlog entries 53-55. The plan below
was written on exactly this reading, so nothing in it changes; the record of the gap follows.

**The gap.** Story 1.5's first acceptance criterion in `epics.md` (:1137-1139) says the `/ocupilot` static
application "serves files unauthenticated … and carries no application or matching roles". AD-21 says the
static application "is unauthenticated by design and still carries a dispatch class". On the image this
project pins, those two cannot both hold: database READ is routine-execution permission (AD-9), so an
anonymous request cannot load a dispatch class compiled in the install namespace's database unless the
request holds read on that database, and the only per-application way to hold it is an application role.

**Evidence** (throwaway `intersystems/irishealth-community:2026.2` container, ports 52778/1977, created and
torn down 2026-09-11; the live `ocupilot` container's state line byte-identical before and after):

- Baseline matched the live instance: `UnknownUser` enabled with no roles, `%DB_HSCUSTOM` with no public
  permission, HSCUSTOM's routines database `HSCUSTOM`.
- Unauthenticated application, dispatch class compiled in HSCUSTOM, no `MatchRoles`, `AccessCheck` overridden
  to authorize: **HTTP 500**, body `ERROR #5002: ObjectScript error:
  <PROTECT>^%CSP.REST.1 ^|^^/usr/irissys/mgr/HSCUSTOM/|Plan15.Probe.1` — which also leaks the database
  directory to an anonymous caller.
- Same application, class **without** an `AccessCheck` override: **HTTP 403**, zero-length body.
- Same application with `MatchRoles = ":%DB_HSCUSTOM"`: **HTTP 200**, dispatching as `UnknownUser` holding
  `%DB_HSCUSTOM`.

**Recommended amendment (option 1).** Amend the story's first acceptance criterion to: *"…and carries exactly
one matching role, purpose-built and read-only — granting read on the install namespace's database and
nothing else, because IRIS requires database READ to execute the dispatch class — and no other application or
matching role, which the install-time test asserts."* The installer creates that role beside the two
applications and uninstall removes it; AD-21 gains the fact and the constraint in the same commit (Rule 20).
Cost: one role in the installer, its uninstall and its fingerprint entry. This spec is planned on that
reading.

**Alternatives, each rejected as more than a slice decision.** (2) Put the static handler's code in a second,
public-read database mapped into the install namespace: keeps the wording literally, but contradicts AD-9
("OcuPilot's code does not [live behind a resource]") and Story 1.3's
`TestNoPackageOrRoutineMappingIsCreated`, and adds a database to install and uninstall. (3) Drop the dispatch
class and serve the bundle with CSP file serving plus hash-based client routing, as the vendor's
`/ui/interop` does: keeps the wording and needs no code, but contradicts AD-13, AD-20 and AD-21 and this
story's own deep-link criterion.

**What changes if the owner picks 2 or 3.** Option 2 replaces the `EnsureShellRole` task with a database,
resource and package-mapping step and amends AD-9; every other task, AC and test in this spec stands. Option
3 deletes `Api/StaticHandler.cls`, AC4, AC5's nonce, AC6 and `Test/Static.cls`, changes AC3's route shape to
a fragment, and amends AD-13, AD-20, AD-21 and AD-47.

**Two further decisions are recorded, not halted on** — readiness hosting for Story 1.17, and the entity-id
wire contract (DW-31) — both under `## Design Notes` → *Decisions this story records rather than decides*.
Neither blocks planning: readiness is 1.17's to build and nothing here forecloses it, and the wire contract
is settled by live evidence inside this story's own scope.

## Review Triage Log

### 2026-09-11 — Review pass

- verdicts: 51 findings — high 0, medium 17, low 34, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` `GET /ocupilot/index.html` resolves as an asset, so the document is served immutably cached, with no CSP and the nonce placeholder intact — confirmed over the wire on the live instance; `ResolvePath` now returns `"index"` when the resolved file is the index, pinned by `Static.TestIndexNamedByFilenameIsStillTheDocument`.
  - `[medium]` `[patch]` the CSP nonce came from `$Random`, a per-process PRNG, not a CSPRNG — switched to `$System.Encryption.GenCryptRand(16)`; the throwaway account's password in `Test.Wire` likewise.
  - `[medium]` `[patch]` `EnsureShellFiles` cleared the shell directory with the result discarded, so a failed clear left stale hashed assets beside the new bundle while reporting success — the result is now checked and a failure leaves the installed bundle in place and reports it.
  - `[low]` `[patch]` the "no bundle" warn fired for a run that named no source at all (every MCP and IPM install) — the no-source case is now its own `info`, and the start hook always names the directory so install stays the one place that decides what an absent bundle means.
  - `[low]` `[reject]` `EnsureSqlPrivileges` is unspecified and install-fatal — no realistic installing principal can create databases, resources, roles and web applications but not `GRANT`, and failing loudly beats a gate that answers `installing` forever.
  - `[low]` `[patch]` `EnsureSqlPrivileges`' doc claimed every profile's rows live in one database, which `Names` contradicts — corrected at the sentence; the grant is schema-scoped and the schema is one per namespace, so the step is correct as written.
  - `[medium]` `[patch]` the start hook's "nothing writes to stderr" guarantee did not cover its `iris session` children, whose stderr `/iris-main` reads as a failed start — both sessions now capture `2>&1`, the claim is narrowed to what it guarantees, and `compose.test.mjs` checks the sessions as well as the messages.
  - `[low]` `[reject]` `StaticHandler`'s `ReportHttpStatusCode` and `Http405` duplicate `Api.Router`'s, and the 404 branch of the copy is unreachable — consolidating adds a public classmethod to `Api.Error` and belongs with 1.13's error rendering; both copies are covered by their own tests.
  - `[low]` `[patch]` nothing asserted that a repeat install repairs *nothing* — added `WebApp.TestRepeatInstallRepairsNothing`, which would catch a wanted value IRIS normalises on write and so "repairs" forever.
  - `[medium]` `[patch]` `ADMINRESOURCES` is hand-transcribed and unpinned, so a typo in any of the twelve entries the suite never grants locks out an administrator silently — added `Wire.TestEveryAdminResourceNamedExistsOnTheInstance`.
  - `[low]` `[reject]` `RootDirectory`'s name mapping is not injective, so two applications could share a bundle directory — only install creates these applications and it uses fixed names; a uniqueness registry is complexity for an unreachable state.
  - `[low]` `[patch]` `HEAD` is routed but unexercised, and `Serve` writes the body regardless of verb — the body claim is refuted (the CSP server suppresses it; `curl -I` returns headers only), but nothing asserted the headers, so `Static.TestHeadCarriesTheDocumentHeadersAndNoBody` was added.
  - `[low]` `[reject]` the document carries no `Referrer-Policy`, `Permissions-Policy`, `COOP` or `X-Frame-Options` — beyond AC5, which asks for a CSP naming only the instance's origin; `frame-ancestors 'none'` already covers framing and the page makes no cross-origin request.
  - `[low]` `[reject]` a mid-stream `OutputToDevice` failure would append a 500 envelope to partial bytes — structurally real but needs a local file to vanish or the device to break mid-response, at which point the connection is the larger problem. Would become real if streaming moved to a remote or mounted store.
  - `[low]` `[reject]` the over-large-document path answers `STATIC.NOBUNDLE`, which is untrue when a bundle is installed — the limit is 1 MB against a 689-byte document, and the audit line records the real cause.
  - `[low]` `[patch]` `build-output.test.mjs`'s comment claimed `angular-json.test.mjs` reads the optimization knob, which it did not — the comment is corrected and `angular-json.test.mjs` now pins `inlineCritical: false`.
  - `[medium]` `[patch]` the client codec, route table and deep-link component have no executed test host, so an encode-twice regression ships green — added `ui/tools/entity-id.test.mjs` against the same table the server test uses (mutation demonstrated: a single `encodeURIComponent` turns two of its four tests red). The router half is deferred, below.
  - `[medium]` `[patch]` `TestInstalledBundleDeclaresTheNonRootBaseHref` was red by default: nothing in the suite can install a real bundle, so its green depended on the instance's history — replaced by `TestProductionShellServesWhatIsInstalled`, which asserts both states, with the build-time half pinned in `build-output.test.mjs`, which runs a real build every time.
  - `[low]` `[reject]` the production shell is never driven over the wire by the suite — the handler is the same code the probe tests drive, and the browser check and both throwaway runs drive `/ocupilot` itself.
  - `[low]` `[reject]` `Test.EntityId.ServerDecode` duplicates `Kernel.EntityId.Decode`, so the in-process corpus test asserts a property of the codec against a model of the server — disclosed in the class doc and validated by `Wire.TestEntityIdCorpusSurvivesTheRealWire`.
  - `[low]` `[patch]` `Uninstall` discarded the bundle directory's removal result, so a failed removal reported a clean uninstall while `AnyObjectExists` kept reading the profile as present — the result is kept and reported after the namespace restore.
  - `[low]` `[reject]` test suites hardcode names `Names` owns — `Names` is `[ Private ]`; a public accessor is new surface for a developer-only duplication.
  - `[medium]` `[patch]` `ResolvePath`'s empty-root guard was dead code: `%File.NormalizeDirectory("")` returns the namespace's own directory on this build, so an empty root resolved request paths against it — verified live, and `pRoot` is now refused before normalization.
  - `[low]` `[reject]` a mid-stream write failure appends an envelope to partial bytes — same root cause as the entry above it, rejected on the same grounds.
  - `[low]` `[reject]` a zero-byte `index.html` would answer 200 with an empty page — a broken install the operator meets immediately, and the clearing step that could produce one is now guarded.
  - `[low]` `[reject]` an `index.html` with no nonce placeholder would name a nonce nothing carries — `build-output.test.mjs` pins the placeholder in every build, so only a hand-substituted bundle reaches it.
  - `[medium]` `[patch]` the nonce is drawn from `$Random` — same root cause as the second entry, patched with it.
  - `[low]` `[patch]` `HEAD` writes the full body — same root cause as the `HEAD` entry above, patched with it.
  - `[medium]` `[patch]` `RemoveDirectoryTree`'s result is discarded before the copy — same root cause as the third entry, patched with it.
  - `[low]` `[patch]` a bundle source that normalizes to the shell directory would delete the source before copying it — `EnsureShellFiles` now refuses that case with a `warn`.
  - `[low]` `[patch]` `Uninstall` discards `RemoveDirectoryTree` — same root cause as the `Uninstall` entry above, patched with it.
  - `[low]` `[reject]` `Decode` on a segment whose percent-decoded bytes are not valid UTF-8 silently yields `?` — no route consumes an entity id until 1.9, and giving `Decode` a failure return is that story's contract change. Reopen when the first id-bearing route lands.
  - `[low]` `[reject]` an underscore-bearing slug would render `ROUTE.BAD_REQUEST` — the branch's only production caller is `%CSP.REST.Page()`'s `Http403()`, whose slug has no underscore.
  - `[low]` `[reject]` the spec claims omitted keys in the optimization object mean false, where `@angular/build` defaults them to true — the fix is a spec edit; both the config key and the emitted document are now pinned, which is what the claim was protecting.
  - `[low]` `[patch]` `Test.Static`'s class doc claimed nothing there touches the production application, but `OnBeforeAllTests` runs the production install — corrected at the sentence.
  - `[medium]` `[patch]` `Wire`'s teardown assertions are discarded by `%UnitTest` (the per-method frame is popped before `OnAfterAllTests`, and `LogAssert` drops assertions with an empty method name), so a teardown regression would leave a privileged throwaway account on the instance and still report green — teardown now returns a failing `%Status`, which the manager does record.
  - `[medium]` `[patch]` the client entity-id codec has no executed test host — same root cause as the client-codec entry above, patched with it.
  - `[medium]` `[defer]` AC3's and AC5's client halves rest on a manual browser check; the router wiring and `DeepLink` have no executed test host — deferred, since closing it means standing up a client test runner.
  - `[medium]` `[patch]` `ADMINRESOURCES` has thirteen entries of which one is ever exercised — same root cause as the `ADMINRESOURCES` entry above, patched with it.
  - `[low]` `[patch]` `IsInsideRoot`'s recorded mutation does not hold: both call sites pass an already-normalized root, so removing the internal `NormalizeDirectory` changes nothing — the doc comment now names a mutation that works (drop the trailing separator from the comparison).
  - `[low]` `[patch]` the containment test's last assertion compared a string with the string it was built from, so it held by construction — deleted; the four assertions above it carry the test.
  - `[low]` `[patch]` `HoldsAdminResource`'s doc claimed it is public so `Test.Wire` can call it, which `Wire` never did — the sentence now states what the test actually checks.
  - `[medium]` `[patch]` the start hook's stderr claim does not cover child processes — same root cause as the stderr entry above, patched with it.
  - `[medium]` `[defer]` install adopts and repairs whatever application sits at `/ocupilot` or `/api/ocupilot`, against the spec's "repair only what install created", while AC12 requires exactly that repair at those paths — deferred as a product call the spec does not settle; install holds no provenance record for these two objects.
  - `[low]` `[reject]` the two container-lifecycle rows are evidenced by text assertions over compose and the start hook — the spec designates them throwaway checks, and both were run on a throwaway this pass.
  - `[low]` `[reject]` `EnsureSqlPrivileges` sits outside every reading of the intent — instrumentally in scope: without it the intent's own "API, signed in" rows cannot produce their stated outputs.
  - `[low]` `[reject]` the `container-start.sh` stderr rewrite touches Story 1.4 failure reporting — required for AC11's "never fails install" to hold on the container path, and now pinned by `compose.test.mjs`.
  - `[low]` `[reject]` `Test.Http`'s default port moved 52774 → 52773 — a `%UnitTest` run executes inside the container, where the host-side mapping does not exist; the resolver reads the instance's own configured port first.
  - `[low]` `[reject]` the shell's wire tests drive `/probeocupilot`, not `/ocupilot` — same root cause as the production-shell entry above, rejected on the same grounds.
  - `[medium]` `[patch]` `TestInstalledBundleDeclaresTheNonRootBaseHref`'s truth is a property of the instance's history — same root cause as the by-default-red entry above, patched with it.
  - `[low]` `[patch]` the bundle-absent test passes a named directory where the container passed `""` — resolved by the start-hook change: the container now always names the directory, so the test's input is the container's input.

## Spec Change Log

- 2026-09-11 (lead, after the plan stage's `intent gap` HALT): the owner chose option 1 for the privilege
  floor and the third unauthenticated application for readiness. `epics.md` AC1 amended at origin; AD-21,
  AD-45 and AD-13 amended in the spine (Rule 20). Frontmatter `status` reset `blocked` -> `ready-for-dev`;
  AC1's blocked-clause pointer replaced by the AD-21 citation. No re-plan: the spec was planned on this
  reading. Spec flagged `oversized` - nothing else is added until it is `done`.
