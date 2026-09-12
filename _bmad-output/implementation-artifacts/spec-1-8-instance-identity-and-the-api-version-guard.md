---
title: 'Story 1.8: Instance identity and the API version guard'
type: 'feature'
created: '2026-09-12'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
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

## Review Triage Log

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
- `iris_execute_tests` on `OcuPilot.Test.Instance`, then `OcuPilot.Test.AdminInventoryTest`, then
  `OcuPilot.Test.Wire`, then `OcuPilot.Test.Routing` — **one class per message**, each awaited.

**Pinning tests (Rule 19) — one per acceptance criterion, then one per matrix row no AC covers:**

- Identity happy path → `OcuPilot.Test.Wire`, the over-the-wire identity test.
  `mutation: _(implement stage)_`
- `VerifyInstance` reports a mismatch or a failed probe loudly → `OcuPilot.Test.Instance`, the version-1,
  version-3, absent-API and probe-contract cases over the fixture seam.
  `mutation: _(implement stage)_`
- Integration AC (`app.ts` renders the notice and withholds the outlet on anything but `ready`) →
  `ui/tools/session.test.mjs`, the `app.ts` template read extended to the notice, plus
  `npm --prefix ui run build` type-checking it under `strictTemplates`.
  `mutation: _(implement stage)_`
- The 403 drives the no-privileges variant and the two never swap words → `OcuPilot.Test.Wire`'s
  throwaway-principal denial test, plus `ui/tools/session.test.mjs`'s variant-selection test.
  `mutation: _(implement stage)_`
- The inventory fixture fails on disagreement, and a failed lookup is not a match →
  `OcuPilot.Test.AdminInventoryTest`.
  `mutation: _(implement stage)_`
- DW-3 server half → `OcuPilot.Test.Instance`, the `buildIdentity` passthrough.
  `mutation: _(implement stage)_`
- The string source grows by exactly one → `ui/tools/strings.test.mjs` "the string source holds nothing the
  documents do not authorize".
  `mutation: _(implement stage)_`
- DW-101 → `ui/tools/api.test.mjs`, `requestJson` on a 503 carrying an `INSTALL.*` code.
  `mutation: _(implement stage)_`
- DW-102 → `ui/tools/session.test.mjs`, two `enterInstalling()` calls arming one chain.
  `mutation: _(implement stage)_`
- DW-107 → `ui/tools/session.test.mjs`, a refresh started after `signOut()` adopting nothing.
  `mutation: _(implement stage)_`
- Wrong verb → `OcuPilot.Test.Wire`, the `POST /instance` 405 with `Allow: GET`.
  `mutation: _(implement stage)_`

Whoever adds or materially changes a pinning test writes its `mutation:` line in the same pass: name the
smallest change that violates the AC, apply it, observe red, revert, and confirm `git status --short` and
`git diff --stat` are unchanged.

**Manual checks:**

- In desktop Chrome against the live instance at `http://localhost:52774/ocupilot/`: sign in and confirm the
  routed outlet renders with no notice, and that the network panel shows exactly one
  `GET /api/ocupilot/instance` carrying an `Authorization` header and no cookie.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
