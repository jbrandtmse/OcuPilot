---
title: 'Story 1.8: Instance identity and the API version guard'
type: 'feature'
created: '2026-09-12'
status: 'done'
baseline_revision: '2b66251c2605ecb0faf4a62402e8c95fe010a77b'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-1-7-sign-out.md'
  - '{project-root}/.claude/rules/objectscript-testing.md'
warnings: ['oversized']
deferred:
  - summary: >-
      EXPERIENCE.md's Fixed strings table carries a row for the no-privileges notice but none
      for the version-mismatch sentence, which the same document authors inline at :427. The
      string ships via `strings.test.mjs`'s `REQUIRED_ALONGSIDE_TABLE`; the lead should add
      the table row so that mechanism does not become a bypass.
    evidence: |-
      Read directly 2026-09-12: EXPERIENCE.md:248-302 holds no row matching "admin API" or
      "version"; EXPERIENCE.md:427 spells the sentence inside a State Patterns row the table's
      own rule calls an illustration. Amending a planning artifact is the lead's (Rule 5).
    location: >-
      EXPERIENCE.md Fixed strings table (:248-302); ui/tools/strings.test.mjs
      REQUIRED_ALONGSIDE_TABLE
    severity: medium
  - summary: >-
      An identity call that fails in a way that is neither AUTH.NOADMIN nor INSTALL.* leaves the
      shell on `checking` with nothing scheduled to ask again, so a signed-in tab can sit on a
      blank content area until something else moves the session.
    evidence: |-
      instance.ts runVerify's fall-through deliberately does not settle, and the only caller is
      app.ts's session subscription. An install recovers (the session changes state); a 500, a
      proxy error or a dropped connection does not. A retry needs a scheduler this service does
      not take, which is the seam Story 1.13 owns (uniform error handling and the connectivity
      probe) per this spec's own Consumed-by.
    location: 'ui/src/app/core/instance.ts (runVerify fall-through); Story 1.13'
    severity: medium
  - summary: >-
      The `--ocu-*` colour layer is theme-static: `:root.ocu-theme-dark` remaps only `--mat-sys-*`,
      so every colour in `_components.scss` keeps its light value in dark mode. Pre-existing and
      whole-file, newly visible because this story is the first to use the error roles.
    evidence: |-
      Read directly 2026-09-12: _theme.scss:127-128 maps --mat-sys-error-container to
      --ocu-error-container-dark, and the dark block redefines no --ocu-* role; _tokens.scss:66-69
      holds the -dark values, unreachable from a rule naming --ocu-error-container. Every colour
      in _components.scss uses the --ocu-* form, which is also what this story's intent requires,
      so the fix is a design-system decision, not a component edit. No code applies
      `ocu-theme-dark` yet.
    location: 'ui/src/styles/_theme.scss:107-145; ui/src/styles/_components.scss'
    severity: medium
  - summary: >-
      The blocking instance notice replaces the whole product surface but carries no heading, no
      live region and no focus move, so a screen-reader user reaching `signed-in` is told nothing.
    evidence: |-
      instance-notice.ts renders one section with a paragraph and one control. A heading would need
      a string the intent forbids adding, and the right treatment (heading vs live region, focus
      management) spans the chrome Stories 1.9 and 1.10 build. DESIGN.md is cited here for
      appearance only and says nothing about announcement.
    location: 'ui/src/app/shell/instance-notice.ts; DESIGN.md empty-state (:1066, :1090)'
    severity: medium
  - summary: >-
      DW-3's pinning test cannot distinguish the version row from the compiled-in constant, because
      on any instance this build installed the two are both "dev".
    evidence: |-
      Test/Instance.cls arms InstanceFixture.BuildIdentity, so the production body does not run;
      the production comparison that follows is green whether BuildIdentity() reads the row or
      Installer.BUILDIDENTITY. The row's existence is now asserted (this pass), but telling the two
      apart needs an overridable VersionRow() seam a fixture can point at a stamp no build carries.
      The upgrade case DW-3 exists for is exactly where they differ.
    location: 'src/OcuPilot/Api/Instance.cls BuildIdentity(); src/OcuPilot/Test/Instance.cls'
    severity: medium
  - summary: >-
      `Api.Instance.Handle()`'s internal-error branch is reachable in production and exercised by no
      test, so the first route's failure path could stop producing OcuPilot's one envelope unnoticed.
    evidence: |-
      Nothing makes Payload return an error: InstanceFixture's VerifyInstance always returns $$$OK.
      Driving it needs a throwing fixture mode plus the output capture Test/Utils and
      Test/BodyRequest provide for the router's own error paths, which is more than a patch.
      AD-12's one-envelope contract is pinned generally by Test/Envelope, not for this handler.
    location: 'src/OcuPilot/Api/Instance.cls Handle(); src/OcuPilot/Test/InstanceFixture.cls'
    severity: medium
  - summary: >-
      The admin API version OcuPilot requires is stated in two languages -- AdminPort's APIVERSION
      and the client's REQUIRED_ADMIN_API_VERSION -- with no check that they agree.
    evidence: |-
      The client half is now pinned to the user-facing sentence (this pass), but nothing ties either
      to the server parameter; a version bump on one side leaves the other silently wrong. Closing
      it needs a cross-language check, which this epic has no home for until CI lands in 1.17.
    location: 'src/OcuPilot/Port/AdminPort.cls APIVERSION; ui/src/app/core/instance.ts'
    severity: low
  - summary: >-
      `ProbeAnswers`' third branch -- an endpoint that answers ShouldRunAsync() with a non-boolean
      rather than throwing -- has no fixture mode and no test.
    evidence: |-
      ProbeFixture offers ok / noconstruct / noresources / asyncthrows; the throwing mode lands in
      the Catch, a different branch with a different message. The non-boolean branch is the one
      AD-26's synchronous-versus-async distinction actually rests on.
    location: 'src/OcuPilot/Port/AdminPort.cls ProbeAnswers(); src/OcuPilot/Test/ProbeFixture.cls'
    severity: low
---

<intent-contract>

## Intent

**Problem:** `Api.Router`'s `UrlMap` is empty and `ApiService.request()` has no production call site, so
OcuPilot has never made a data call. Nothing verifies that this instance's admin API is the v2 OcuPilot is
built against (AD-27, NFR-8), and a user holding no `%Admin_*` resource has no way to learn that is why
nothing works.

**Approach:** Add the first route — `GET /api/ocupilot/instance` — and the first production API caller.
The route reports the usable admin API version, the instance name and version, and the deployed build
stamp; the shell blocks on a mismatch with a notice that names it, and renders the no-privileges notice on
the router's own 403. Wiring that first call is also what makes the four routed client-side ledger items
reachable, so they are closed here.

## Boundaries & Constraints

**Always:**

- Only `Port/AdminPort` names an `%Api.Admin.*` class (AD-27). The version is derived the same way the
  vendor derives it — the highest `Dispatch.v<N>` in `%Api.Admin`'s own `UrlMap` XData — so OcuPilot and
  `/api/admin/info` cannot disagree.
- Success through `Api.Response.JSON`, failure through `Api.Error.Render` (AD-12). No handler writes to the
  response device; `Call=` targets stay thin (Router `:55-56`).
- The client calls one absolute path through the one API service (AD-20), Bearer only (AD-28), and reads
  the envelope's `code`, never the human `reason` (AD-39).
- Every user-facing word comes from `ui/src/app/core/strings.ts`; every colour from an existing `--ocu-*`
  token. `core/` stays framework-free so `node --test` executes it.
- No real account is created, modified, locked or expired, and no browser session this story did not mint
  is ever ended. A denial test uses a purpose-built throwaway principal, removed in teardown.

**Never:**

- No second envelope field, no second response writer, no second install gate. The 401 / install-in-flight
  / namespace branches are `OnPreDispatch`'s and stay there.
- **No full AD-2 invocation sequence.** `VerifyInstance` reads the vendor contract; `ValidateRequest`,
  `BeginCaptureOutput`/`Run`/`EndCaptureOutput` and the `%response.Status` read are Epic 2's.
- No rail, side bar, command box, header or status bar — 1.9 and 1.10 own the chrome. This story renders
  the notice and withholds the routed outlet; it makes nothing "inert" because nothing to make inert exists.
- No new string beyond the one version-mismatch sentence. `authNoAdminPrivileges` (`strings.ts:54`),
  `actionSignOut` (`:112`) and `classicLinkCardTitle` (`:232`) already exist and are reused verbatim.
- `%Api.Admin.Info()` is never called in-process: it reads `%session.Username`, sets `%response.Status`,
  and returns `Dispatch.v1.RenderResponseBody(...)`, which *writes* its JSON to the device.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Version mismatch | `VerifyInstance` reports anything but 2 | 200 carrying that number; the mismatch notice renders with the classic-portal link; the routed outlet is withheld | Not an error envelope — the client needs the number to name it |
| Admin API absent | `%Api.Admin` missing, or its `UrlMap` forwards to no `Dispatch.v<N>` | `adminApiVersion: 0`; the same notice | Actionable detail through `Error.LogError` |
| Probe contract broken | The named probe endpoint is absent, will not construct at ApiVersion 2, or returns an empty `ResourcesOR()` | `adminApiVersion: 0`; the same notice; the log line names the probe class and what it lacked | AD-27: loud, never a partly-working screen |
| No administrative privilege | Caller holds none of `Router:40`'s thirteen resources | `OnPreDispatch` 403, code `AUTH.NOADMIN`; the no-privileges notice with Sign out | Never dressed as a version mismatch, nor the reverse |
| Install in flight (**DW-101**) | 503 whose envelope `code` starts `INSTALL.` | `ApiService` classifies it through `isInstallInFlight`; the session enters backoff and the caller is told "installing" | The caller never sees the raw 503 |
| Two backoff chains (**DW-102**) | The data call and the session probe both enter install backoff | One chain runs; a second is a no-op while one is armed, so no second `sid` is minted and no stored pair is overwritten | Single-flight, as `refresh()` is at `session.ts:408-416` |
| Refresh after sign-out (**DW-107**) | A refresh starts *after* `signOut()`; no pair is held | It returns false without probing; the tab stays `signed-out` | Never re-mints from a login a failed logout left alive |
| Wrong verb | `POST /api/ocupilot/instance` | 405 with `Allow: GET` through `Error.Render405` | The framework calls `Router.Http405` once a GET is mapped |

</intent-contract>

## Code Map

**Extend, never duplicate.** Anchors verified 2026-09-12 against the working tree and the live instance.

- `src/OcuPilot/Api/Router.cls` (228) — `UrlMap` empty `:57-61`; ordering invariants `:42-56`;
  `ADMINRESOURCES` (thirteen) `:40`. `OnPreDispatch` `:145-191` already emits every branch the client
  classifies: install gate `:150-165`, anonymous `:167-172`, **`AUTH.NOADMIN` 403 `:174-178`**, `?ns=`
  `:180-185`. `Http405` `:222-226` is framework-called, so the wrong-verb row costs no route.
  `ResolvedUsername` `:69-72` / `GateStatus` `:82-85` — the override-for-test seam to copy.
- `src/OcuPilot/Api/Response.cls` — `JSON` `:13-22`, `JSONStatus` `:25-29`.
  `src/OcuPilot/Api/Error.cls` — `Render` `:105-131`, slug enum `:20-54`, code parameters `:59-90`,
  `LogError` `:165-168`. The only two classes `scripts/check-objectscript.py:325` lets `Write`.
- `src/OcuPilot/Kernel/State/Version.cls` — `SchemaVersion` `:25`, `Phase` `:31`, **`BuildIdentity` `:46`**,
  `GuardedCurrentForProfile` `:51-59`. `src/OcuPilot/Install/Installer.cls` — `BUILDIDENTITY = "dev"` `:73`,
  `CurrentVersionRow` `:903-906`, `GateStatus` `:1009-1043`. Live row: schema 1, `installed`, `"dev"`.
- `src/OcuPilot/Kernel/Utils.cls` — `SwitchNamespace`/`RestoreNamespace` `:43-67`; `ReadRequestBody`
  `:366-395` (see **Declined DW-23**). `src/OcuPilot/Port/` holds only `.gitkeep`; nothing in the tree names
  an `%Api.Admin.*` class.
- Live instance (`server: "ocupilot-iris"`): `%Api.Admin`'s `UrlMap` maps `/info`, `/v1`, `/v2`, and
  `Info()` takes `apiVersion` from the highest `Dispatch.v<N>` in that XData. `%Api.Admin.Endpoints.*` =
  **70** (`%Dictionary.CompiledClass`); templates 21 / 17 / 1 / 1 by name, matching AD-3; `ShouldRunAsync`
  locally overridden by **7**. Instance name: `%SYS.System.GetInstanceName()`
  (`irissys/%SYS/System.cls:85`); version: `$ZVERSION`.
- `src/OcuPilot/Test/` — `Http.cls` (262) `AbsoluteRequest` `:206`, `BASEPATH` `:35`; `RouterFixture.cls`
  (189) + `Routing.cls` (183) the fixture-subclass pattern; `Token.cls` (687) the throwaway-principal +
  `OnAfterAllTests` teardown; `Wire.cls` (369) the over-the-wire suite; `Utils.cls` (240) + `BodyRequest.cls`
  (52) `%request` substitution in a `New` frame.
- `ui/src/app/core/api.ts` (149) — `request()` `:109`, path guard `:82-92` applied `:110-112`, pre-emptive
  refresh `:125-129`, the one 401 retry `:131-137`, `buildInit` `:140-148`. **No envelope read in the file.**
- `ui/src/app/core/session.ts` (620) — `HttpResponseLike` `:77-80` (`status` + **single-read** `text()`);
  `isInstallInFlight` `:134-136`, caller-less; `refreshInFlight` single-flight `:408-416` (DW-102's model);
  `runRefresh` `:465-493`, whose `pair === null` return `:467-470` reaches `retryProbeThenEnd` `:495-498` →
  `probeAndSettle` `:500-516` **before** the generation guard `:475` (DW-107); `enterInstalling` `:518-533`,
  unguarded; `adopt` `:535-542`; `signOutGeneration` `:237`, bumped only `:443`; `SessionState` `:55-63`.
- `ui/src/app/core/strings.ts` — 107 keys; `authNoAdminPrivileges` `:54`, `actionSignOut` `:112`,
  `classicLinkCardTitle` `:232`. `ui/src/app/app.ts` (65) — gate `:40-45`, `signedIn` `:62-64`.
  `ui/src/app/shell/sign-in.ts` (232) — the component to imitate.
  `ui/src/styles/_components.scss` — `@mixin ocu-focus-ring` `:27`, `.ocu-banner` `:248`.
- `ui/tools/` — `client-lint.mjs` (348) colours `:80-107`, paren-free conditions `:154-155`, literal text
  nodes `:175-194`, whole-string copy attributes `:130-131`/`:263-275`; `strings.test.mjs` (178)
  `extractFixedStringsTable` `:48-68`, `REQUIRED_ALONGSIDE_TABLE` and the count assertion `:100-118`;
  `api.test.mjs` (437) the `ui/src` source scan `:347-369`; `session.test.mjs` (1330), flat `test()` blocks.
- `EXPERIENCE.md` — `:427` Version mismatch (trigger, and the sentence); `:428` No administrative privileges;
  `:248-302` the Fixed strings table; `:317` the status bar's instance fields. `DESIGN.md` — `:1066` both
  notices as `empty-state` compositions, "Neither is a banner"; `:1090` `empty-state`; `:1201` error colours.

## Tasks & Acceptance

**Execution — server:**

- `src/OcuPilot/Port/AdminPort.cls` — *new*. `Parameter PROBEENDPOINT = "%Api.Admin.Endpoints.WebSession"`.
  `VerifyInstance(Output pVersion As %Integer, Output pDetail As %String) As %Status`: derive the reported
  version from `%Api.Admin`'s `UrlMap` XData (highest `Dispatch.v<N>`; 0 when the class or the forward is
  absent), then confirm the probe endpoint answers the port's contract — it constructs as
  `%New(<type>, 2)`, `ResourcesOR()` returns a non-empty `%List`, and `ShouldRunAsync()` answers. Report
  `pVersion = 0` and an actionable `pDetail` when either half fails. The only class in the tree naming an
  `%Api.Admin.*` class (AD-27).
- `src/OcuPilot/Api/Instance.cls` — *new*. The thin handler: call `AdminPort.VerifyInstance`, log a
  non-empty detail through `Error.LogError`, read `BuildIdentity` from the current version row
  (`Installer.CurrentVersionRow`), and emit `{adminApiVersion, instanceName, instanceVersion, buildIdentity}`
  through `Response.JSON`. `instanceName` from `%SYS.System.GetInstanceName()`, `instanceVersion` from
  `$ZVERSION` — neither needs a namespace switch. **DW-3 (server half).**
- `src/OcuPilot/Api/Router.cls` — add `<Route Url="/instance" Method="GET" Call="Instance"/>` as the first
  entry in `UrlMap` `:59-60`, plus the thin `Instance()` wrapper delegating to `Api.Instance`. Change
  nothing else; the ordering invariants `:42-56` are unaffected by a single explicit-verb route.
- `src/OcuPilot/Test/AdminInventory.cls` — *new*. An XData block holding the checked-in inventory: one row
  per `%Api.Admin.Endpoints.*` class with its body-template method name (or none), whether it locally
  overrides `ShouldRunAsync`, and whether its UDL source references `%request` or `%response`. A
  `Regenerate()` class method emits the block as source (AD-3: a checked-in artifact, never runtime
  reflection), and a test re-derives from the instance and fails on any difference. **A failed
  `%Compiler.UDL.TextServices.GetTextAsString` fails the derivation — it is never scored as "no match".**

**Execution — client:**

- `ui/src/app/core/api.ts` — add `requestJson<T>()` over `request()`, returning a discriminated result
  (`ok` with the parsed body, `installing`, or `error` with `status`, `code` and `reason`). It buffers
  `text()` once — `HttpResponseLike.text()` is single-read — parses the envelope, and calls
  `isInstallInFlight(status, code)`. `request()` itself is unchanged so its existing pins hold. **DW-101.**
- `ui/src/app/core/session.ts` — (a) give the install-backoff chain the single-flight shape `refresh()` uses
  at `:408-416`: `enterInstalling()` is a no-op while a chain is armed, and the guard clears when the chain
  settles. **DW-102.** (b) In `runRefresh()` `:465-470`, return false without probing when no pair is held
  *and* the state is already `signed-out`, so the fall-through to `probeAndSettle()` cannot re-mint.
  **DW-107.**
- `ui/src/app/core/instance.ts` — *new*, framework-free. `InstanceService` holding a signal over
  `'checking' | 'ready' | 'version-mismatch' | 'no-privileges'`, plus `adminApiVersion`, `instanceName`,
  `instanceVersion` and `buildIdentity`. One `verify()` calling `requestJson` on
  `/api/ocupilot/instance`: 200 with `adminApiVersion === 2` → `ready`; 200 with anything else →
  `version-mismatch`; `error` with `code === 'AUTH.NOADMIN'` → `no-privileges`.
- `ui/src/app/core/strings.ts` — add exactly one key, `authAdminApiVersionMismatch`, whose value is
  EXPERIENCE.md `:427`'s sentence with its resolved `1` returned to the table's `<n>` placeholder:
  `This instance's admin API is version <n>; OcuPilot needs version 2.` The apostrophe is ASCII U+0027
  verbatim from `:427` (checked byte-for-byte 2026-09-12) — a typographic quote would respell the string
  and fail `strings.test.mjs`; inside the single-quoted TypeScript literal it is written `\'`.
- `ui/tools/strings.test.mjs` — add that literal to `REQUIRED_ALONGSIDE_TABLE` `:92`, citing EXPERIENCE.md
  `:427` as its authority, exactly as the three existing extras do.
- `ui/src/app/shell/instance-notice.ts` — *new*. `app-instance-notice`, `OnPush`, the signal bridge
  `sign-in.ts` uses. One `empty-state` composition with two variants (DESIGN.md `:1066`, `:1090`): the
  mismatch variant renders `{{ STRINGS.authAdminApiVersionMismatch }}` with `<n>` replaced in TypeScript by
  the reported version, and a link to the classic portal reading `{{ STRINGS.classicLinkCardTitle }}`; the
  no-privileges variant renders `{{ STRINGS.authNoAdminPrivileges }}` and a `button-text` control reading
  `{{ STRINGS.actionSignOut }}` that calls `session.signOut()`. Error colours from existing tokens
  (DESIGN.md `:1201`). No literal text node; every control-flow condition paren-free.
- `ui/src/app/app.ts` — inside the `@if (signedIn)` branch `:40-45`, render `<app-instance-notice />` when
  the instance is not `ready` and `<router-outlet />` only when it is; call `InstanceService.verify()` once
  the session reaches `signed-in`.
- `ui/src/styles/_components.scss` — the `empty-state` rules, from existing tokens only. Add no colour token.

**Execution — tests:**

- `src/OcuPilot/Test/Instance.cls` — *new*. A fixture subclass overriding the version seam (the
  `RouterFixture.ResolvedUsername` / `GateStatus` pattern) so version 1, version 3 and an absent API are
  pinned **without touching the instance's own state**; plus the probe-contract failure and the
  `buildIdentity` passthrough.
- `src/OcuPilot/Test/AdminInventoryTest.cls` — *new*. Re-derives the inventory live and asserts it equals
  the checked-in XData; asserts the four counts (70 / 21 / 17 / 1 / 1 / 7) and that a failed source lookup
  raises rather than counting as absent.
- `src/OcuPilot/Test/Wire.cls` — add the over-the-wire identity test (200, the four fields, `adminApiVersion`
  = 2) and the 405-on-POST test, and a denial test that mints a throwaway principal holding **no**
  `%Admin_*` resource, asserts 403 with `code` `AUTH.NOADMIN`, and removes it in `OnAfterAllTests`. That
  principal must still hold **read on the install namespace's database**: without it IRIS cannot load the
  router for the request and the framework answers a bare 403 with no envelope (`Router.cls:125-129`),
  which passes a status-only assertion while pinning nothing.
- `ui/tools/session.test.mjs`, `ui/tools/api.test.mjs` — the DW-101/102/107 tests and the `requestJson`
  envelope tests, in the existing flat `test()` style.

**Acceptance Criteria:**

- Given a signed-in tab on an instance whose admin API is v2, when the shell loads, then exactly one
  `GET /api/ocupilot/instance` goes out carrying only a Bearer, and its 200 body carries
  `adminApiVersion: 2`, the instance name, the instance version and the version row's `buildIdentity`.
- Given `AdminPort.VerifyInstance` finds the admin API absent, at a version other than 2, or the named probe
  endpoint failing the port's contract, when the handler resolves, then the response reports that version
  (0 for absent or probe-failed) and an actionable detail naming what was missing reaches the log — never a
  screen that half works.
- **Integration AC** — given the session is `signed-in`, when `InstanceService` settles `version-mismatch`,
  then `app.ts` renders `app-instance-notice` in its mismatch variant naming the reported version with the
  classic-portal link, and withholds `<router-outlet />`; when it settles `ready`, the outlet renders and
  the notice does not.
- Given a signed-in user holding none of `Router:40`'s thirteen resources, when the identity call resolves,
  then the 403's `AUTH.NOADMIN` drives the no-privileges variant with a working Sign out, and neither
  notice ever renders the other's words.
- Given CI has not been built yet, when `OcuPilot.Test.AdminInventoryTest` runs against the instance, then
  it re-derives the endpoint inventory and fails on any disagreement with the checked-in XData — including
  a source lookup that failed rather than matched.
- **DW-3** — given any successful identity call, when the response reaches the browser, then its
  `buildIdentity` field is the version row's value byte-for-byte; the client-side stale-bundle prompt is
  declined below.
- Given the whole story, when `ui/tools/strings.test.mjs` runs, then the string source holds exactly the
  Fixed strings table's literals plus the named extras, now four rather than three.

## Spec Change Log

- **Decision (overnight) — the matrix's `Allow: GET` ships as `Allow: GET,OPTIONS`.** The route maps one
  verb; `%CSP.REST` composes the header itself and pushes `OPTIONS` onto every enabled route's verb list
  (`irissys/%CSP/REST.cls:625`, read directly). A bare `GET` would need the vendor's own composition
  overridden, and would misreport OPTIONS, which the framework does answer. The matrix row's behavioural
  claim — 405, GET named, rendered by the one error writer — holds; the test asserts the whole value so a
  vendor change is caught.
- **Decision (overnight) — the inventory test class is `OcuPilot.Test.Inventory`.** `AdminInventoryTest` is
  32 characters against the spine's 29-character limit, which `scripts/check-objectscript.py` enforces. The
  `## Verification` command names the runnable class; `## Tasks` and the ACs still spell the old name and are
  the lead's to amend.
- **Decision (overnight) — three claims this story falsified were corrected at their origin**, not only
  where noticed: `Test/Token.cls:5` and `:35` and `Test/RouterFixture.cls:2` each asserted the production
  `UrlMap` is empty. The route table is no longer empty; the application root is simply unmapped, which is
  what those tests actually rely on.

## Review Triage Log

### 2026-09-12 — Review pass

- verdicts: 60 findings — high 0, medium 17, low 20, false 6, maybe-false 0, rejected-as-duplicate-of-a-routed-entry 17
- layers: blind-hunter 31, edge-case-hunter 12, verification-gap 14, intent-alignment 3
- findings:
  - `[medium]` `[patch]` blind-hunter: `InstanceService` is never reset, so a second principal signing in to the same tab inherits the first one's verdict — verified: `signOut()` clears in place without a reload (`session.ts:450-476`), so the service outlives the user; added `reset()` plus a generation guard, called from `app.ts` whenever the session leaves `signed-in`, with two tests.
  - `[low]` `[patch]` blind-hunter: `checking` renders an empty `ocu-empty-state` box — verified: both variants are false there and `app.ts` renders the element anyway; the whole composition now sits behind `hasNotice`, with a test.
  - `[medium]` `[defer]` blind-hunter: nothing retries after an inconclusive answer that is not an install — verified; a retry needs a scheduler this service does not take, which is Story 1.13's declared seam. Deferred.
  - `[medium]` `[patch]` blind-hunter: a rejected `fetch` becomes an unhandled promise rejection — verified: `requestJson` awaited outside any `try` and callers reach it through `void`; now returns `status: 0` as an outcome, with a test.
  - `[low]` `[reject]` blind-hunter: a non-JSON 2xx is reported as "version 0" — real but unreachable from this route, which always emits JSON; 0 is already the honest "not usable" value, and a guard adds a branch for a proxy fault nothing demonstrates.
  - `[medium]` `[patch]` blind-hunter: three uncoupled copies of the supported version (`APIVERSION`, `REQUIRED_ADMIN_API_VERSION`, the sentence's literal "2") — the client pair is now pinned by a test asserting the sentence names `REQUIRED_ADMIN_API_VERSION`; the cross-language half is deferred.
  - `[false]` `[reject]` blind-hunter: a broken probe on a healthy v2 instance reports version 0 — that is the matrix's own "Probe contract broken" row verbatim (`adminApiVersion: 0`), so it is the specified behaviour, not a defect.
  - `[medium]` `[patch]` blind-hunter: `AdminInventory.Derive` reads a failed query as an empty population — verified: `%Execute` is unchecked, so a failure returns `$$$OK` with no rows and `Regenerate` emits an empty block; now checks `%SQLCODE`, the same discipline the class header states for `SourceState`.
  - `[low]` `[patch]` blind-hunter: `SourceState`'s CSP column is a substring scan including comments but is documented as a structural claim — corrected the doc to say what it measures, labelled `(inference)` where it generalises.
  - `[low]` `[reject]` blind-hunter: the spec's "a failed lookup fails the derivation" is not literally what shipped — the fix is an edit to this build's spec; recorded instead as an overnight decision in the Spec Change Log. AC5 is satisfied either way: an unreadable row disagrees with a checked-in `none` and fails the comparison.
  - `[low]` `[reject]` blind-hunter: the `AdminInventoryTest` → `Inventory` rename is not corrected in the Code Map, AC5 and Design Notes — the fix is an edit to this build's spec; the Change Log records it as the lead's to amend.
  - `[low]` `[patch]` blind-hunter: `Payload` reads and then discards `VerifyInstance`'s status with no note — the downgrade is deliberate (a version the client cannot use is still a 200 carrying the number); documented at the method.
  - `[medium]` `[patch]` blind-hunter: `Test/Instance.cls:190`'s `If $IsObject(tRow)` comparison can silently vanish — verified: no preceding assertion, unlike its twin in `Wire.cls`; added `$$$AssertTrue($IsObject(tRow), ...)`.
  - `[low]` `[patch]` blind-hunter: the async-probe test asserts only the probe class name, which holds under all three failure modes — now also asserts "failed the port's contract", the wording unique to that branch.
  - `[low]` `[defer]` blind-hunter: `ProbeAnswers`' non-boolean `ShouldRunAsync` branch has no fixture mode — real; needs a new fixture mode. Deferred.
  - `[medium]` `[defer]` blind-hunter: `Api.Instance.Handle()`'s failure path is untested — verified: nothing can make `Payload` fail through the fixture; driving it needs output capture. Deferred.
  - `[medium]` `[patch]` blind-hunter: AD-27's containment ("only `Port/AdminPort` names an `%Api.Admin.*` class") is enforced by nothing — added `check_admin_api_containment` to `scripts/check-objectscript.py`, scanning code lines only so prose may still explain the rule; demonstrated it fires on a second class and stays silent on a doc-comment mention.
  - `[low]` `[patch]` blind-hunter: `ProbeFixture.STATEGLOBAL` is a documented parameter nothing reads — deleted; the note explaining the process-private global moved to the class header.
  - `[low]` `[patch]` blind-hunter: `AdminApiFlat`'s header contradicts its own XData — corrected to "no `Dispatch.v<N>` **of its own**", which is what the fixture demonstrates.
  - `[low]` `[reject]` blind-hunter: the inventory pair inverts the `<Thing>Fixture` naming convention — cosmetic, and the fix is a rename across files rather than a direct correction.
  - `[low]` `[reject]` blind-hunter: no routing test covers the production route's ordering — with one route there is no ordering to demonstrate; the invariants become observable on the production table when 1.9's descriptor registry adds the second route.
  - `[low]` `[reject]` blind-hunter: `OPTIONS` is now advertised and never pinned — verified at `irissys/%CSP/REST.cls:269-272` that OPTIONS is answered ahead of authorization for the dispatch class as a whole, so mapping a route changed what it reports, not whether it answers; CORS is already pinned off by `Test/Token.TestNeitherDispatchClassEnablesCors`.
  - `[low]` `[reject]` blind-hunter: the install gate's effect on the new route is pinned only client-side — the gate is in `OnPreDispatch`, ahead of dispatch and route-independent, and is already pinned by `Test/Gate` and `Test/GateLadder`; a per-route copy asserts the same branch again.
  - `[low]` `[patch]` blind-hunter: `_components.scss`'s header keeps a closed inventory of sanctioned raw pixel values that the new rules make incomplete — extended the list.
  - `[medium]` `[defer]` blind-hunter: the new error-coloured surface will not follow the dark theme — verified at `_theme.scss:107-145` and `_tokens.scss:66-69`: dark remaps only `--mat-sys-*`, and every colour in `_components.scss` uses the `--ocu-*` form the intent requires. Pre-existing and whole-file. Deferred.
  - `[low]` `[reject]` blind-hunter: brace-matching template parsing is duplicated in `session.test.mjs` — test-only duplication; extraction is a refactor, not a direct correction.
  - `[low]` `[patch]` blind-hunter: the new string is the first entry to break `strings.mjs`'s documented one-pair-per-line contract — verified: `PAIR_RE` matches only because `\s*` crosses the newline; the entry is now on one line.
  - `[low]` `[patch]` blind-hunter: placeholder substitution is rolled locally and replaces only the first occurrence — folded into the extracted `formatVersionMismatch`, which replaces every occurrence and is executed by a test.
  - `[low]` `[patch]` blind-hunter: `instance.ts`'s header says "Two settled states" and then lists three — corrected.
  - `[medium]` `[defer]` blind-hunter: the blocking notice has no heading, live region or focus move — real; a heading needs a string the intent forbids adding, and the treatment spans 1.9/1.10's chrome. Deferred.
  - `[low]` `[patch]` blind-hunter: the rewritten `RouterFixture` sentence lost its causal link — rewritten to state why the production table cannot demonstrate the invariants; the duplicated trailing clause removed.
  - `[low]` `[patch]` edge-case-hunter: `checking` renders an empty box — same root cause as the blind-hunter row above; closed by `hasNotice`.
  - `[medium]` `[defer]` edge-case-hunter: no retry after an inconclusive answer — same root cause; deferred.
  - `[medium]` `[patch]` edge-case-hunter: a rejecting fetch escapes `requestJson` — same root cause; closed.
  - `[medium]` `[patch]` edge-case-hunter: a different user signing in to the same tab reuses the previous verdict — same root cause; closed by `reset()`.
  - `[medium]` `[patch]` edge-case-hunter: `backoffArmed` clears when the timer fires, not when the chain settles, so a caller arriving while the probe's `/login` is on the wire arms a second chain — verified by reading `enterInstalling`: the scheduled callback clears the flag before probing, and the matrix row forbids exactly "a second `sid` … a stored pair overwritten". `noteInstallInFlight` now refuses while the session is `installing` (the whole chain, armed and probing alike); the chain's own continuation calls `enterInstalling()` directly and is unaffected. New test.
  - `[false]` `[reject]` edge-case-hunter: a stale probe disarms the live chain's guard — `signOut()` sets `backoffArmed = false` itself (`session.ts:461`) and the scheduled callback's generation check returns before probing, so no live chain exists to disarm across a sign-out.
  - `[medium]` `[patch]` edge-case-hunter: a 503 answering after sign-out re-enters `installing` — verified: `noteInstallInFlight` did not read the state, so a call already on the wire put the signed-out tab back on the installing presentation (the generation guard stopped the re-mint but not the state change). Now refused, with a test.
  - `[false]` `[reject]` edge-case-hunter: the notice reads "admin API is version 0", presenting absence as a version — the matrix specifies `adminApiVersion: 0` for both absent and probe-failed, and one notice for both; changing the sentence would need a string the intent forbids.
  - `[medium]` `[patch]` edge-case-hunter: `AdminInventory.Derive` does not check `%SQLCODE` — same root cause as the blind-hunter row; closed.
  - `[medium]` `[patch]` edge-case-hunter: `Test/Instance.cls`'s conditional version-row assertion — same root cause; closed.
  - `[low]` `[reject]` edge-case-hunter (claim): the spec says a failed lookup fails the derivation — the fix is an edit to this build's spec; recorded as an overnight decision instead.
  - `[medium]` `[patch]` edge-case-hunter (claim): DW-102's "no-op while armed" is narrower than claimed — the substantive half is the in-flight window, closed above. The `setState('installing')` that precedes the guard is deliberate and correct: a second caller must still see the waiting state, which is what the matrix row's "both callers" means.
  - `[medium]` `[patch]` verification-gap: `NO_ADMIN_CODE` and `INSTANCE_PATH` are asserted only against themselves — verified: both fixture and expectation are built from the same constant, so a rename stays green while the real 403 misses the branch. Both are now pinned to the literals the server emits and serves.
  - `[medium]` `[patch]` verification-gap: the mismatch sentence's substitution is pinned only by a source regex, so renaming `VERSION_PLACEHOLDER` on one side ships `<n>` to the user — extracted `formatVersionMismatch` into framework-free `core/`, asserted under `node --test` over real versions; the component's source pin now requires delegation and forbids a second copy.
  - `[medium]` `[patch]` verification-gap: `instanceReady` is pinned by a source substring that survives being broadened — exported `isInstanceReady` and asserted it over all four statuses, the shape `isSignedIn` already uses.
  - `[medium]` `[defer]` verification-gap: DW-3's pinning test cannot tell the version row from the build constant — verified against the live row (`BuildIdentity = "dev"`) and `Installer.cls:73`; the row's existence is now asserted, but distinguishing the two needs a `VersionRow()` seam. Deferred.
  - `[medium]` `[defer]` verification-gap: `Api.Instance.Handle()`'s internal-error branch is unreachable from any test — same root cause as the blind-hunter row; deferred.
  - `[medium]` `[patch]` verification-gap (Rule 19 sweep): `Test/Instance.cls:191` is green whether `BuildIdentity()` reads the row or the constant, and is skipped entirely if the row is absent — the skip is closed by the added assertion; the row-versus-constant half is deferred.
  - `[low]` `[reject]` verification-gap (Rule 19 sweep): `Inventory.cls:93`'s `AssertNotEquals(..., "none")` is implied by the line above — it is a redundant restatement, not the pinning assertion (which is `:91`, demonstrated red this pass); deleting it loses the documented intent and gains no discriminating power.
  - `[medium]` `[patch]` verification-gap (Rule 19 sweep): `session.test.mjs`'s self-referential expectations — same root cause as the `NO_ADMIN_CODE` row; closed.
  - `[low]` `[reject]` verification-gap (Rule 19 sweep): the row-for-row classification test compares the predicate against itself — it does pin that `requestJson` consults the one rule rather than owning a second copy, which is what the task asked for; the comment's claim is stronger than the assertion, but the assertion is not vacuous (dropping the call reddens it, demonstrated).
  - `[low]` `[reject]` verification-gap (Rule 19 sweep): `app.ts`, `instance-notice.ts` and `main.ts` have no executed test host — the repo's declared position until Story 1.9 (DW-93). The two consequences that could be closed without a runner were, by moving the gate predicate and the formatter into executed `core/` code.
  - `[medium]` `[patch]` verification-gap (other): `settled` is never reset — same root cause as the blind-hunter row; closed.
  - `[medium]` `[patch]` verification-gap (other): a rejecting fetch escapes `requestJson` — same root cause; closed.
  - `[low]` `[patch]` verification-gap (other): `ProbeFixture.STATEGLOBAL` is a knob that does nothing — same root cause; closed.
  - `[false]` `[reject]` verification-gap (other): `Instance.cls:27`'s `$$$ISERR(tVerify) && (tDetail = "")` is unreachable through any fixture — it is unreachable through the *current* port, whose contract guarantees a detail with every error status, which is precisely why it is a fallback. Code that holds when a collaborator breaks its documented contract is not a defect.
  - `[low]` `[reject]` intent-alignment: the `checking` state renders an empty element — same root cause as the blind-hunter row; closed by `hasNotice`.
  - `[medium]` `[patch]` intent-alignment: a settled verdict is cached for the tab's life, not the user's, against AD-8's "privilege resolved in the calling process, never cached" — same root cause; closed by `reset()`.
  - `[medium]` `[patch]` intent-alignment: `Wire.cls`'s 405 doc comment names a mutation the spec records as impossible (`ERROR #5001`) — verified against both: corrected the comment to the mutation actually demonstrated (a second `POST /instance` route).


## Design Notes

**Governing ADs (Rule 6).** AD-27 (the port verifies v2 and a named probe endpoint, fails loudly, and is
the only class naming `%Api.Admin.*`; the inventory is a fixture, not prose), AD-2 (the port's invocation
contract — this story reads it, Epic 2 runs it), AD-12/AD-39 (one writer, one flat envelope, the `code`
read and not the `reason`), AD-20 (absolute paths through the one service), AD-28 (Bearer only, per-tab),
AD-8 (privilege resolved in the calling process, never cached), AD-21 (anonymous placeholders rejected —
already `OnPreDispatch`'s), AD-16 (no namespace switch is needed: `%SYS.System` and `$ZVERSION` are
`%`-mapped), AD-38 (the version row's stamp and the install gate), AD-19 (zoneless, `OnPush`, signals),
AD-44 (the classic-portal link back), AD-47 (no cookie, no cross-tab), AD-36 (this read returns one record,
so no cap applies).

**Decision (overnight) — the version comes from `%Api.Admin`'s `UrlMap`, not from calling `Info()`.** Read
on the instance 2026-09-12: `Info()` reads `%session.Username`, sets `%response.Status`, and returns
`Dispatch.v1.RenderResponseBody(...)`, which writes its JSON to the device — so calling it in-process needs
a `%session` stub, a `%response` stub, output capture and a namespace switch, and then parsing back bytes
OcuPilot just captured. `Info()` derives `apiVersion` from that same XData, so reading it directly is the
identical computation and the two cannot disagree.

**Decision (overnight) — the no-privileges notice is driven by the router's own 403.**
`OnPreDispatch:174-178` already refuses a caller holding none of `ADMINRESOURCES` (thirteen, a superset of
the eleven `Info()` checks), so such a caller never reaches the handler. EXPERIENCE.md `:428`'s "privilege
map holds no `%Admin_*`" and the epic AC's "the admin API's 403" describe the same user in the same state,
and resolving it in the calling process is AD-8's rule. No privilege map is returned here — 1.9 owns
privilege-driven navigation and will need one.

**Decision (overnight) — the notices are `empty-state` compositions, not banners.** EXPERIENCE.md `:427-428`
say "empty-state shape with a banner (error)"; DESIGN.md `:1066` says "Neither is a banner". DESIGN.md is
the authority on appearance and the more specific statement, so "(error)" is the colour treatment
(DESIGN.md `:1201`) on the empty state, not a second stacked component.

**Decision (overnight) — the version-mismatch string ships through `REQUIRED_ALONGSIDE_TABLE`.** The Fixed
strings table (`:248-302`) carries the no-privileges sentence but not the version-mismatch one, which the
same document authors at `:427`; three literals already sit in `REQUIRED_ALONGSIDE_TABLE` for exactly this
reason. `:427`'s resolved `1` returns to the table's `<n>` convention — the inverse of the rule permitting
an illustration to resolve a placeholder. Amending the table is the lead's (Rule 5) and is filed under
`deferred:`.

**Decision (overnight) — "inert rail, side bar and command box" has no subject here.** None of the three
exists; 1.9 and 1.10 build them. The half 1.8 delivers is "no area screen loads" — `app.ts` withholds the
routed outlet, the gate shape 1.7 used — and it exposes one `ready` predicate for those stories to gate on.

**Decision (overnight) — AC 5's "Given CI runs" is honoured as a suite, not a pipeline.** Epic 1 has no CI
until 1.17. The fixture re-derives and fails on disagreement now; 1.17 puts it in CI.

**Declined DW-23:** this story's whole surface is one GET, so it adds no body-carrying route and
`Kernel.Utils.ReadRequestBody:366-395` still has no production call site. The ledger's routing note assumed
a body-carrying route this story's acceptance criteria do not contain. `Test/Utils.cls` already gives the
method an executed host, so the residue is call-site existence only; the first OcuPilot route that accepts a
body is `POST /api/ocupilot/turn` (AD-7, Epic 7).

**Declined DW-3 (client half):** the API reporting its build stamp is delivered above; prompting a
mismatched bundle to reload is not. Neither EXPERIENCE.md nor DESIGN.md specifies a reload prompt — no
state row, no component, and no sentence in the Fixed strings table to transcribe — so it would mean
authoring new product copy, which is the owner's call, and the client has no build identity of its own to
compare against until a build-time stamp generator exists (`Installer.cls:73` is the literal `"dev"`). That
generator is packaging work; 1.16 generates the manifest from the same tree and 1.17 owns CI.

**Consumes:** 1.1 (`Api.Response`, `Api.Error` and its slug/code enums, `Kernel.Utils`), 1.3/1.4 (the
version row, `BuildIdentity`, `Installer.GateStatus`), 1.5 (`/api/ocupilot`, `Api.Router`'s
`OnPreDispatch`, `Test.Http.AbsoluteRequest`), 1.6 (`TokenStore`, `Session`, `ApiService`), 1.7 (`app.ts`'s
gate, `signOut()`, `Test.Token`'s throwaway-principal pattern).

**Consumed-by:** 1.9 — reads the `ready` predicate to keep the rail and side bar inert on a mismatch, and
will need the privilege map this story leaves out; 1.10 — renders `instanceName` and `instanceVersion` in
the status bar (EXPERIENCE.md `:317`) and makes the command box inert; 1.13 — uniform error handling and the
connectivity probe build on `requestJson`'s envelope reader; 1.14 — auto-refresh calls through the same
service; 1.17 — puts `AdminInventoryTest` in CI; Epic 2 — grows `AdminPort` into AD-2's full invocation
sequence around `VerifyInstance`.

**Ledger inbox.** DW-101, DW-102 and DW-107 each have a matrix row, a task and a pinning test; DW-3 is
addressed on the server and declined on the client above; DW-23 is declined above.

## Verification

**Environments.** The live `ocupilot` container (web 52774, SuperServer 1973) must **not** be recreated — no
`docker compose up`/`down`/`restart` against this repository's compose file. Every check here is read-only or
idempotent and runs against it through the IRIS MCP tools with **`server: "ocupilot-iris"`** on every call.
**The version guard is pinned by a fixture subclass overriding the version seam, never by editing the
instance's version row or its admin API** — so nothing here is destructive or install-path and **no throwaway
container is required**. If one becomes necessary it is a separate scratch compose project with its own
project name, container name, host ports (never 52774/1973) and scratch volume, per `README.md` § "Verifying
the start path against a throwaway container", torn down with `down -v`. No real account is created,
modified, locked or expired: the denial test's principal is minted by the test and removed in
`OnAfterAllTests`.

**One test class per tool call.** Send **one** `iris_execute_tests` call per message, wait for it to land in
`%UnitTest_Result`, and never re-submit on a client-side timeout — a returned call is not a finished run, and
these classes share one instance.

**Commands:**

- `npm --prefix ui test` — expected: green; `strings.test.mjs` at the table's literals plus four extras.
- `npm --prefix ui run build` — expected: exit 0, `initial` under the 1MB budget (`ui/angular.json:38-44`),
  `client-lint: clean`.
- `uv run scripts/check-objectscript.py` — expected: no findings (new classes are under `Api`, `Port` and
  `Test`; no bare `Write` outside the two writers).
- `bash scripts/lint-docs.sh` — expected: clean.
- `iris_doc_load` + `iris_doc_compile` on `src/OcuPilot/` (`server: "ocupilot-iris"`) — expected: clean.
- `iris_execute_tests` on `OcuPilot.Test.Instance`, then `OcuPilot.Test.Inventory` (named for the
  29-character class-name limit, which `OcuPilot.Test.AdminInventoryTest` exceeds at 32), then
  `OcuPilot.Test.Wire`, then `OcuPilot.Test.Routing` — **one class per message**, each awaited.

**Pinning tests (Rule 19) — one per acceptance criterion, then one per matrix row no AC covers:**

- Identity happy path → `OcuPilot.Test.Wire`, the over-the-wire identity test.
  `mutation: dropped the instanceName field from Api.Instance.Payload -> TestTheIdentityRouteReportsTheInstance red on "the instance names itself"; the other three fields stayed green, so the test reads each field rather than the response's shape.`
- `VerifyInstance` reports a mismatch or a failed probe loudly → `OcuPilot.Test.Instance`, the version-1,
  version-3, absent-API and probe-contract cases over the fixture seam.
  `mutation: deleted the ProbeAnswers block from AdminPort.VerifyInstance -> the three probe-contract tests and TestTheProbeIsConstructedAtTheApiVersionOcuPilotPins red (4 of 13); a broken probe then reported a usable version, which is AD-27's "a screen that half works".`
- Integration AC (`app.ts` renders the notice and withholds the outlet on anything but `ready`) →
  `ui/tools/session.test.mjs`, the `app.ts` template read extended to the notice, plus
  `npm --prefix ui run build` type-checking it under `strictTemplates`.
  `mutation: swapped the bodies of app.ts's @if (instanceReady) / @else branches -> "Integration AC: app.ts renders the instance notice and withholds the outlet on anything but ready" red; the session-gate test stayed green under it, which is why the nested gate needed its own. The predicate behind the gate is pinned separately and executed, over all four statuses.`
- The 403 drives the no-privileges variant and the two never swap words → `OcuPilot.Test.Wire`'s
  throwaway-principal denial test, plus `ui/tools/session.test.mjs`'s variant-selection test.
  `mutation: deleted the HoldsAdminResource block from Router.OnPreDispatch -> TestTheIdentityRouteRefusesACallerHoldingNoAdminResource red (the no-admin principal got a 200 version report), along with the two pre-existing gate tests. On the client half: pointed instance-notice.ts's mismatch getter at 'no-privileges' -> "AC4: the two notice variants are siblings, and neither carries the other's words" red.`
- The inventory fixture fails on disagreement, and a failed lookup is not a match →
  `OcuPilot.Test.Inventory`.
  `mutation: initialised AdminInventory.SourceState's result to "none" instead of "unreadable" -> three of four red: the failed-lookup test, the unreadable count, and the fixture-versus-instance comparison on all three stub rows.`
- DW-3 server half → `OcuPilot.Test.Instance`, the `buildIdentity` passthrough.
  `mutation: emitted Installer.BUILDIDENTITY from Api.Instance.Payload instead of calling BuildIdentity() -> TestThePayloadCarriesTheVersionRowsBuildIdentity red on "the stamp travels unchanged". Changing what BuildIdentity() reads would NOT go red: on this instance the deployed constant and the row are both "dev".`
- The string source grows by exactly one → `ui/tools/strings.test.mjs` "the string source holds nothing the
  documents do not authorize".
  `mutation: added one key to strings.ts -> that test red, naming the unauthorized value.`
- DW-101 → `ui/tools/api.test.mjs`, `requestJson` on a 503 carrying an `INSTALL.*` code.
  `mutation: deleted the install-in-flight branch from ApiService.requestJson -> "DW-101: an INSTALL.* 503 is classified installing and the session enters backoff" and the row-for-row agreement test red.`
- DW-102 → `ui/tools/session.test.mjs`, two `enterInstalling()` calls arming one chain.
  `mutation: deleted the "if (this.currentState === 'installing') return true;" guard from noteInstallInFlight() -> "DW-102: a caller arriving while the armed probe is on the wire arms no second chain" red (two chains, two /login calls, two sids). backoffArmed alone does not cover that window: the scheduled callback clears it before it probes.`
- DW-107 → `ui/tools/session.test.mjs`, a refresh started after `signOut()` adopting nothing.
  `mutation: deleted the "if (this.currentState === 'signed-out') return false;" line from runRefresh() -> "DW-107: a refresh started after sign-out adopts nothing and issues no request" red; the scope test stayed green, which is what shows the guard is not disarming the EXPERIENCE.md :571 rescue.`
- Wrong verb → `OcuPilot.Test.Wire`, the `POST /instance` 405 with `Allow: GET`.
  `mutation: mapped a second route, POST /instance, to the same handler -> TestTheIdentityRouteRefusesAPostAndNamesTheVerbItAllows red on all three assertions. Dropping the Method attribute instead does not compile: %CSP.REST refuses a route without one (ERROR #5001, missing required attribute 'Method').`

Whoever adds or materially changes a pinning test writes its `mutation:` line in the same pass: name the
smallest change that violates the AC, apply it, observe red, revert, and confirm `git status --short` and
`git diff --stat` are unchanged.

**Manual checks:**

- In desktop Chrome against the live instance at `http://localhost:52774/ocupilot/`: sign in and confirm the
  routed outlet renders with no notice, and that the network panel shows exactly one
  `GET /api/ocupilot/instance` carrying an `Authorization` header and no cookie.

## Auto Run Result

Status: done
Blocking condition: none

**What shipped.** The first route (`GET /api/ocupilot/instance`), the first production caller of
`ApiService`, and the first envelope reader. `Port/AdminPort` derives the admin API version from
`%Api.Admin`'s own `UrlMap` the way the vendor does and confirms the named probe endpoint still answers
the port's contract; `Api/Instance` emits the four identity fields through the one success writer; the
shell settles `ready` / `version-mismatch` / `no-privileges` and withholds the routed outlet on anything
but `ready`. DW-101, DW-102 and DW-107 each have a matrix row, an implementation and a pinning test.

**Files changed.** Server: `Port/AdminPort.cls` (new, the only class naming `%Api.Admin.*`),
`Api/Instance.cls` (new handler), `Api/Router.cls` (one route plus its thin `Call=` target),
`Test/AdminInventory.cls` + `Test/Inventory.cls` (the checked-in 70-row inventory and its drift check),
`Test/Instance.cls` and five fixtures (`PortFixture`, `ProbeFixture`, `InstanceFixture`, `AdminApiV1`,
`AdminApiV3`, `AdminApiFlat`), `Test/Wire.cls` (identity, 405, denial), and doc corrections in
`Test/Token.cls` and `Test/RouterFixture.cls`. Client: `core/instance.ts` (new service, the gate
predicate and the sentence formatter), `core/api.ts` (`requestJson`), `core/session.ts`
(`noteInstallInFlight` and the two guards), `core/strings.ts` (one key), `shell/instance-notice.ts`
(new), `app.ts`, `main.ts`, `styles/_components.scss`, and the three test files. Tooling:
`scripts/check-objectscript.py` gains AD-27's containment rule.

**Review findings.** 60 findings across four layers — 0 high, 17 medium, 20 low, 6 false, 0 maybe-false,
17 duplicates of a routed entry. Patched: 11 medium and 11 low (one entry per root cause; the duplicate
rows share their route). Deferred: 7 new items in the frontmatter `deferred:` list, alongside the one
the plan stage filed. Rejected with reasons recorded per row above: 6 false, 2 spec-edit fixes (the
`unreadable` wording and the `AdminInventoryTest` rename, both recorded instead as overnight decisions),
and 9 lows not worth their fix.

**Verification performed.** `npm --prefix ui test` — 238 pass, 0 fail (was 228 before this pass's
patches). `npm --prefix ui run build` — exit 0, `client-lint: clean`, initial 264.09 kB against the 1 MB
budget. `uv run scripts/check-objectscript.py` — 0 problems, including the new AD-27 rule, which was
demonstrated to fire on a second class naming `%Api.Admin` on a code line and to stay silent on a
doc-comment mention. `bash scripts/lint-docs.sh` — clean. `iris_doc_load` + compile of all 71 classes
against `ocupilot-iris` — clean. Test classes, one per message and each awaited: `Test.Instance` 13/13,
`Test.Inventory` 4/4, `Test.Wire` 10/10, `Test.Routing` 12/12, and `Test.Token` 12/12 as a regression
check on the newly mapped route. The first four were confirmed independently against `%UnitTest_Result`
by the run-index probe, not from the runner envelope alone. The container was never recreated; no real
account was created, modified or expired; the version guard is pinned entirely over fixture seams.

**Mutations (Rule 19).** All eleven pinning entries were demonstrated in this stage — each mutation
applied, observed red, reverted, with `git status --short` and `git diff --stat` confirmed unchanged
afterwards. Two lines were rewritten after the review patches changed the code they name: DW-102's (the
guard moved from `backoffArmed` to the whole-chain state check) and the Integration AC's (the gate now
reads an executed predicate). Both were re-demonstrated after rewriting.

**Follow-up review recommended: true.** The specific unverified risk is the two behaviours written
during the review rather than the implement pass — `Session.noteInstallInFlight`'s whole-chain guard and
`InstanceService.reset()` with its generation guard. Both are pinned by new tests and both change what
the shell does at sign-out and during an install, and neither has been exercised in a browser: the
manual check below did not run, and the shell components still have no executed component runner
(DW-93, Story 1.9).

**Residual risks.** (1) The manual browser check in `## Manual checks` was not performed — it needs this
bundle installed into the owner's live container, which means running the installer against the live
`./iris-data` volume, outside this run's bounds. The wire half is covered by
`Test.Wire.TestTheIdentityRouteReportsTheInstance`; "exactly one call carrying a Bearer and no cookie"
is pinned by `api.test.mjs`'s `credentials: 'omit'` assertions and the single-call test, not by an
observed network panel. (2) `app.ts`, `main.ts` and `instance-notice.ts` remain pinned by source reads
plus `strictTemplates`; the two properties that could be moved into executed code — the gate predicate
and the sentence substitution — were. (3) The seven deferred items, of which the dark-theme one is
pre-existing and whole-file rather than this story's.
