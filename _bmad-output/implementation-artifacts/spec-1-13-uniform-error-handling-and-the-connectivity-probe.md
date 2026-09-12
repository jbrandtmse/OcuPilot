---
title: 'Story 1.13: Uniform error handling and the connectivity probe'
type: 'feature'
created: '2026-09-12'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The envelope is uniform on the wire but the shell cannot tell its failures apart: a transport fault, a 403, a 404, a 5xx and an install-in-flight all reach the same dead ends, so an unreachable instance reads as one the user has no rights on, a failed identity or navigation-map read waits forever with nothing scheduled to ask again, and a typed password is discarded with no way back.

**Approach:** One client-side failure taxonomy — `unreachable` / `not-installed` / `rejected` / `refused` / `absent` / `server-fault` — classified once from the outcome `api.ts` already produces, published by one connectivity service that owns the probe and its backoff, and rendered by one `role="alert"` banner plus the status bar's connection segment. Server-side, the code half of the envelope is closed: every code becomes a declared, format-guarded identifier, and a vendor `%Status` is normalized to slug + code + written reason with its raw text kept for the log alone.

## Boundaries & Constraints

**Always:** The probe is client-side and re-issues `GET /api/ocupilot/instance`; any HTTP response — 401, 403, 503 included — proves reachability, and only a transport fault (`status: 0`) is `unreachable`. Unreachability is simulated at the injected `fetch` seam, never by stopping the live container. One error writer (`Api/Error.cls`), one logger (`Kernel/Audit/Log.cls`), one probe timer; the client verdict is presentation, the server stays the gate (AD-8). Every user-facing string comes from `core/strings.ts`, authorized through `EXTRACTED_FROM_PROSE`.

**Never:** No new web application and no readiness route (AD-45 gives both to 1.17). No new envelope field, no second envelope shape (AD-12, AD-39). No `REQUIRED_ALONGSIDE_TABLE` growth. No invented UI copy — a missing string is a DW-126 occurrence. A 403 is reported, never retried (AD-8). No `docker compose up`/`down`/`restart`; no namespace, database or account change.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Reachable, allowed | any `requestJson` returns `kind: 'ok'` | `Connectivity.fault()` is `null`; status bar reads `statusConnectionConnected`; no banner | No error expected |
| **Unreachable** | `fetch` throws → `{kind:'error', status:0}` | fault `unreachable`; one `role="alert"` banner reading `connectivityBannerUnreachable` with `actionRetry`; status bar reads `statusConnectionRetrying`; probe re-arms on backoff and the fault clears on the first response | Probe never surfaces its own failure |
| Not installed | 503 with `code` starting `INSTALL.` → `kind:'installing'` | fault `not-installed`; existing `Session.enterInstalling()` backoff owns it; status bar reads `statusConnectionSigningIn`; no unreachable banner | Unchanged from 1.6 |
| Rejected | 401 after the one refresh-and-retry (`api.ts:217-223`) | fault `rejected`; sign-in surface as today | Never a second retry |
| **Refused** (`DW-135`) | 403 on any call | fault `refused`; inline `role="alert"` naming the failed pair via `privilegeRequiresResource`; data on screen kept; `navigation.noteForbidden()` still re-reads the map | Never retried (AD-8) |
| **Absent** (`DW-11`) | 404 on a read | fault `absent` carrying the request path; classified and pinned; no detail route exists in Epic 1 to render it | See Design Notes |
| Server fault | >= 500 and not `INSTALL.*` | fault `server-fault`; banner reads `connectivityServerFault` with `actionRetry` and `actionOpenMessagesLog`; instance logs the full detail through `Audit.Log.Error` with credential-named values masked | Generic reason only in the browser |
| **Identity limbo** (`DW-119`) | `instance.runVerify` takes the unclassified branch (`instance.ts:259-263`) | the fault is noted and `verify()` is re-run when the probe next reports a response; the shell no longer sits on `checking` with nothing scheduled | Re-ask is idempotent — `verifyInFlight` single-flights it |
| **Map read fails** (`DW-135`) | `navigation.runLoad` gets a non-`ok` result (`navigation.ts:339`) | verdicts stay `UNGATED` (fail-open; the server is the gate) **and** the fault is published, so an unreachable instance shows the connectivity banner rather than reading as a no-rights instance; the read is re-run on probe success. `scope.ts:318` gets the same treatment | Never the no-privileges notice |
| **Submit meets an unreachable instance** (`DW-104`) | `formLogin` transport fault (`session.ts:410`) | the form stays on screen with the typed password intact and the unreachable banner above it; pressing `actionRetry`, or the probe succeeding, re-submits what the user typed | 404 / 5xx keep the 1.6 `installing` behaviour |
| **Tile / locator target** (`DW-161`) | area allowed, first built screen refused | the tile and the locator's area segment open the first built screen **whose own `screenVerdict` allows**; when none does, the control is gated in place like the side bar's entry | Never navigates into the refusal page |
| Code emitted | `Error.Render` called with `""`, `"403"`, or `"route.notfound"` | refused with an error `%Status`; nothing is written to the response device | The guard is in the writer, not at call sites |
| Vendor `%Status` crosses a port | an `%Api.Admin.*` error status | `Kernel.Fault.Normalize` returns a slug, a dotted-uppercase code and a written reason; the raw text reaches `Audit.Log.Error` only | Unmapped statuses default to `server_error` / `INTERNAL` |

</intent-contract>

## Code Map

Server (`src/OcuPilot/`):
- `Api/Error.cls` — the one error writer. `Render` :133 (JSON assembly :145-154), slug enum :20-54 closed by `IsKnownSlug` :246, code parameters :59-118, `RenderInternal` :167, `LogError` seam :193, `GetSlugForStatus` :227. The `pCode = ""` guard is :141; there is no format guard.
- `Api/Router.cls` — `UrlMap` :56-63 (three GETs), `OnPreDispatch` :220-287 (install gate :229, anonymous :249 emits the bare literal `AUTH.ANONYMOUS`, `AUTH.NOADMIN` :255, `NS.UNKNOWN` :263, `NS.DENIED` :277), `ReportHttpStatusCode` :293-311 (literal `ROUTE.NOTFOUND` :299; computed `"ROUTE." _ $ZConvert(tSlug,"U")` :308 — the underscore-bearing second spelling family).
- `Api/StaticHandler.cls` :404 / :407 — byte-identical duplicates of those two lines. AD-12's carve-out; its failures already render through `Error`.
- `Kernel/Audit/Log.cls` — `Info`/`Warn`/`Error`/`Debug` :16-34 → `Emit` :41, `pData` serialized verbatim :50-52. No redaction anywhere.
- `Kernel/Utils.cls:118` `SanitizeError` — strips `$ZERROR`, stacks and `^routine`; tested, zero production callers. It is a *detail stripper*, not a secret redactor (see Design Notes).
- `Port/AdminPort.cls` — `VerifyInstance` :142, `ProbeAnswers` :107; returns raw `%Status` plus hand-built English. No slug mapping exists anywhere in the tree.
- Vendor primitives, read in `irislib/%SYSTEM/Status.cls`: `Equals` :98 (domain/msgid match — the mapping primitive), `GetOneStatusText` :92 (strips domain/id/source), `GetErrorCodes` :63, `DecomposeStatus` :56 (appends to `errorlist`; `Kill` it first, never pass a `"d"` qspec from a handler).
- `Test/Envelope.cls` — `AssertSingleEnvelope` :17, `AssertExactKeySet` :39, `TestSlugForStatusMapping` :172, `TestFrameworkStatusWithNoRouteRendersASlugDerivedCode` :228. `Test/ErrorProbe.cls` and `Test/LogProbe.cls` capture the two log seams. `Test/Dispatch.cls` is the in-process harness.

Client (`ui/src/app/`):
- `core/api.ts` — `JsonResult<T>` :73-87; transport fault → `{kind:'error', status:0, …}` at :249-253; 401 refresh-and-retry :217-223; `onForbidden` fired at :279 (the callback precedent this story copies); fetch seam `ApiOptions.fetch` :28; AD-20 guard :157-167. No timeout or `AbortController` anywhere in `ui/`.
- `core/session.ts` — `SessionState` :54-62; `formLogin` :398-412 (transport fault falls to `enterInstalling()` :410); `runSubmit` :317-324 clears the password unconditionally at :321; `runRefresh` :477-511; `enterInstalling` :563-583 (backoff 500 ms → 8 s); `schedule` seam :97/:203/:256-260 — **the only timer seam in the client**; `password-expired` :59 has no `setState` caller.
- `core/instance.ts` — `runVerify` :232-264; the unclassified branch :259-263 sets `checking` and schedules nothing; `InstanceOptions` :97-99 is `{api}` only.
- `core/navigation.ts` — `Verdict` :33-36, `UNGATED` :39, `runLoad` :336-369 (early return :339), `loaded()` :217-219 has no production reader, `noteForbidden` :306. Same early-return shape at `core/scope.ts:318`.
- `shell/status-bar.ts` — `connectionState` :139-142 and `connectionWord` :144-148 read only `isSignedIn`; the class doc :30-33 defers the other two words to this story.
- `shell/sign-in.ts` — `expired` getter :223-225, banner :126 renders `authPasswordExpired` with the literal `<user>` unsubstituted and no links. `formatVersionMismatch` (used at `instance-notice.ts:95`) is the substitution precedent.
- `app.ts` — two nested gates :96-116; `<div class="ocu-shell-content">` :102-108. `app.spec.ts:266-271` pins that column's children as exactly `['app-locator-bar','app-command-bar','main']`.
- `areas/home/home.page.ts` :186-213 (`areaVerdict` :192, `route` from `screensForArea(...)[0]` :194/:209) and `activate` :271-276; `shell/locator-bar.ts` :167/:250-253 and `open` :241-244 — the two DW-161 sites. `shell/side-bar.ts:150`/:218-219 is the contrast case that already uses `screenVerdict`.
- `core/strings.ts` — flat `STRINGS` :52-334, 125 keys. Already present and unread: `connectivityInstanceUnreachable` :74, `connectivityRequestRefused` :76, `statusConnectionRetrying` :82, `statusConnectionSigningInAgain` :84.
- `ui/tools/strings.test.mjs` — `REQUIRED_ALONGSIDE_TABLE` :255-259 pinned at three by :289; `EXTRACTED_FROM_PROSE` :161-167 is the sanctioned route for a new key.
- `ui/tools/api.test.mjs:562-578` — the existing transport-fault test and the model for every unreachable simulation. `ui/tools/session.test.mjs:296-315` — the DW-1 pin whose `throw` row this story amends.

## Tasks & Acceptance

**Execution:**
- `src/OcuPilot/Api/Error.cls` -- declare the five undeclared codes as parameters (`AUTH.ANONYMOUS`, `ROUTE.NOTFOUND`, `ROUTE.METHODNOTALLOWED`, `ROUTE.NOTIMPLEMENTED`, `INTERNAL`); add `CodeForStatus(pStatusCode)` returning the unseparated derivation so the two files stop duplicating it; add a format guard in `Render` refusing a code that is empty, canonical-numeric, or not `^[A-Z][A-Z0-9]*(\.[A-Z][A-Z0-9]*)*$`; pass the `"string"` type hint on `%Set("code", …)` -- closes the two spelling families and makes "never a number" an invariant of the writer instead of a comment plus two call-site tests.
- `src/OcuPilot/Api/Router.cls`, `src/OcuPilot/Api/StaticHandler.cls` -- replace the inline literals and the local derivation in both `ReportHttpStatusCode` overrides with the new parameters and `CodeForStatus` -- one code vocabulary, one home.
- `src/OcuPilot/Kernel/Fault.cls` (new) -- `Normalize(pStatus, Output pSlug, Output pCode, Output pReason) As %Status`: match with `$System.Status.Equals` against a small table, take the written reason from `GetOneStatusText`, default to `server_error` / `INTERNAL`, and hand the raw `GetErrorText` output to `Audit.Log.Error` only -- AD-39's normalization, in one place, before any port needs it.
- `src/OcuPilot/Kernel/Audit/Log.cls` -- add a backstop redactor over `pData` in `Emit`, masking values whose key matches the credential name pattern -- the Conventions "secrets redacted before emission" row; schema-driven redaction (FR-21) stays Epic 4's.
- `ui/src/app/core/fault.ts` (new) -- the `Fault` discriminated union and the pure `classifyFault(result)`; no Angular import, so it runs under `node --test`.
- `ui/src/app/core/connectivity.ts` (new) -- `ConnectivityService`: holds the current fault, `note(fault)`, `retry()`, `subscribe()`, and the probe's backoff through an injected `schedule` seam mirroring `session.ts:97`; on a response it clears the fault and notifies. It is the one subscribable failure verdict.
- `ui/src/app/core/api.ts` -- add an `onFault` callback fired from `requestJson` alongside the existing `onForbidden` at :279, wired in `src/main.ts` -- keeps `api.ts` free of a service import, exactly as `onForbidden` does.
- `ui/src/app/core/instance.ts` -- DW-119: the unclassified branch notes the fault and re-runs `verify()` when connectivity next reports a response.
- `ui/src/app/core/navigation.ts`, `ui/src/app/core/scope.ts` -- DW-135: the non-`ok` branch notes the fault and re-runs the read on probe success; verdicts stay `UNGATED`.
- `ui/src/app/core/session.ts` -- DW-104: split the transport-fault row out of `formLogin`'s unavailable branch so the form and the typed password survive; keep 404/5xx on the 1.6 `installing` path. DW-105: substitute `<user>` in `authPasswordExpired`.
- `ui/src/app/shell/fault-banner.ts` (new) -- one `role="alert"` banner rendering the unreachable and server-fault copy with `actionRetry` (and `actionOpenMessagesLog` for a server fault), mounted once in `app.ts` **outside both gates** so it is visible on the sign-in form and in the `checking` limbo, neither of which renders the frame.
- `ui/src/app/shell/status-bar.ts` -- the connection segment reads connectivity, producing all four published words instead of two.
- `ui/src/app/shell/sign-in.ts` -- render the expired-password banner with the substituted user name and its two links (classic portal, README).
- `ui/src/app/areas/home/home.page.ts`, `ui/src/app/shell/locator-bar.ts` -- DW-161: target the first built screen whose `screenVerdict` allows; gate the control when none does.
- `ui/src/app/core/strings.ts`, `ui/tools/strings.test.mjs` -- add `connectivityBannerUnreachable`, `connectivityServerFault`, `actionRetry`, `actionOpenMessagesLog` with targeted `EXTRACTED_FROM_PROSE` extractors over EXPERIENCE.md:233/:436/:438; non-ASCII as `\uXXXX`. The four connectivity and status-bar keys already there carry `/** EXPERIENCE.md:n */` comments one line short of their rows (:260 and :261); correct those four while adding the new keys, so the block does not read as two conventions.
- `src/OcuPilot/Test/Fault.cls` (new), `src/OcuPilot/Test/Envelope.cls`, `src/OcuPilot/Test/Log.cls`, `ui/tools/fault.test.mjs` (new), `ui/tools/api.test.mjs`, `ui/tools/session.test.mjs`, and the four affected `*.spec.ts` -- one test per I/O matrix row.

**Acceptance Criteria:**
- Given the classifier, when it is handed each outcome `api.ts` can produce, then every outcome maps to exactly one `Fault` kind and no outcome is unclassified — the union is total over `JsonResult` plus HTTP status.
- Given a `%Status` that carries a vendor class name or an internal id, when it crosses `Kernel.Fault.Normalize`, then no substring of the raw text appears in the rendered envelope, and the raw text does appear in the captured log line.
- Given a fault is live, when the probe's next request returns any HTTP response, then the fault clears, the banner disappears and every reader whose read failed (`instance`, `navigation`, `scope`) re-runs once — not once per reader per tick.
- **Integration AC:** Given `ConnectivityService` publishes an `unreachable` fault, when `StatusBar` renders, then its connection segment's text equals `STRINGS.statusConnectionRetrying` and its disc's `data-connection` is not `connected` — asserted in the component runner against the rendered DOM, not against the service's state.
- **Integration AC (DW-161):** Given an area the user may enter whose first built screen their `screenVerdict` refuses, when the Home tile or the locator's area segment is activated, then the router URL is the first built screen that *is* allowed, or unchanged with the control `aria-disabled="true"` when none is — the same refusal the side bar already performs in place.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs:** AD-12 and AD-39 (one envelope, one writer, a stable dotted-uppercase code, vendor text normalized at the port); AD-8 (a 403 is reported never retried; the server stays the gate, so a client verdict is presentation); AD-19 (signal stores, no component-field state); AD-20 (absolute API paths); AD-28 (the 401 refresh-and-retry is the API service's business, invisible to screens); AD-37 (a reference that no longer resolves renders as "no longer present" rather than failing the screen); AD-38 (`INSTALL.*` refusals are a distinct kind, not a server fault); AD-45 (readiness is a third unauthenticated application, owned by 1.17); AD-47 (the origin is hostile ground — the typed password is held in memory only, for exactly as long as the form is on screen).

**Consumes:** 1.1 (`Api/Response.cls`, `Api/Error.cls`, the router and its gates), 1.2 (`core/strings.ts` and the lint that enforces it), 1.6 (`Session`, its `schedule` seam and the install backoff), 1.8 (`InstanceService` and the version guard), 1.9 (`NavigationService`, `Verdict`, `screenVerdict`), 1.10 (`StatusBar`, the shell bands), 1.11 (`ScopeService`), 1.12 (Home's tiles).

**Consumed-by:** 1.14 (a refresh tick that meets a fault suspends rather than re-arms), 1.15 (the classic-link card is the published fallback when a route fails), 1.17 (the readiness endpoint and the smoke script read the same taxonomy; the browser-runtime harness, DW-159, is where the banner's geometry finally gets asserted), and every Epic 2+ screen, whose list and detail surfaces are the first real consumers of the `refused` and `absent` kinds.

**Decision (overnight): the probe adds no server route.** Every reachable state of `/api/ocupilot` already answers — the install gate refuses 503 before authentication (`Router.cls:229-244`), an anonymous caller gets 401, a non-admin 403 — so a *response of any kind* is the reachability signal and only a transport fault is not. A second probe route now would be the thing 1.17 removes when AD-45's readiness application lands.

**Decision (overnight): fail open, but never silently.** A failed navigation-map read leaves every verdict `UNGATED` because AD-8 makes the server the gate and a client-side closure would lock a user out of screens they hold. What DW-135 actually asks for is that the failure be *visible and retried*, which is what the published connectivity copy now provides — so an unreachable instance no longer borrows the no-privileges notice.

**Decision (overnight): one banner, mounted outside both gates.** `app.ts`'s inner gate means the frame — and with it the status bar — is absent in exactly the two states this story is about (`checking` limbo, sign-in). Mounting the banner above both `@if`s is the only position that serves all of them, and it keeps `app.spec.ts:266-271`'s pin on the content column intact.

**Decision (overnight): DW-104 splits the transport-fault row from DW-1's.** DW-1's rule was "never show a credential rejection for an instance problem", and that stands: 404 and 5xx keep entering `installing`. Only the transport fault changes, to the state that has published copy and a recovery. `ui/tools/session.test.mjs:296-315` loops `['404','503','throw']` and must be amended for the third row; whoever amends it writes its `mutation:` line in the same pass (Rule 19).

**DW-11 — addressed in part, and the remainder named.** The `absent` kind, its classification and its pinning test land here. Its *rendering* does not: Epic 1 builds one screen and no detail route, and AD-37's phrase "no longer present" is architecture prose, not published UI copy — EXPERIENCE.md has no row for a deleted entity at all. The first detail screen (Epic 2) renders it, against copy the owner publishes. Recorded as a DW-126 occurrence.

**DW-105 — the rendering half is addressed, the trigger half declined.** The banner now substitutes the user name and carries both links EXPERIENCE.md:427 requires. The state remains unreachable because no server-side expired-password signal exists on this build — Story 1.6 verified that negative — and manufacturing one would be inventing a protocol. `Declined DW-105 (trigger half): the login endpoint returns an ordinary 401 for an expired password on this build; a discriminator needs a server signal that does not exist.`

**DW-161 is spec-bound — recommended amendment.** Story 1.12's I/O matrix row reads "the first built route". It should read: *the first built route whose screen verdict allows, and the tile is gated when none does*. The lead applies it to `spec-1-12-home.md` with the usual change-log entry; this story's AC is written to the amended wording. Working around the row instead would leave two specs disagreeing about the same click.

**Copy: what is published, and what is not (DW-126 occurrence).** Published and canonical, already in `strings.ts`: the four status-bar connection words (EXPERIENCE.md:261, em dash and ellipsis — the epic AC at epics.md:1482 spells it with an ASCII hyphen; the Fixed-strings table is canonical per EXPERIENCE.md:248, and the shipped key already carries the em dash), the two connectivity outcome names (:260), and the expired-password sentence (:292). Published but *outside* the Fixed-strings table, so authorized by extractor rather than by transcription: the unreachable banner body (:233 Voice-and-Tone *Do* column and :436, identical both times) and the generic server-fault body (:438). Named as controls but absent from the action-names row at :263: `Retry` and `Open messages.log` — taken verbatim from :436/:438 rather than invented. **Absent entirely**, and therefore *not* rendered by this story: a sentence for a deleted entity (DW-11), for a submit that met an unreachable instance (DW-104 — the recovery is behavioural, the banner supplies the words), for a failed navigation-map read (DW-135 — the connectivity copy covers it), and for the AD-38 installing/upgrade refusals (which reuse `statusConnectionSigningIn`, as DW-1 decided). The inline 403 names the missing privilege through the shipped `privilegeRequiresResource`; the published pattern's second half — a per-action verb phrase, "You need %Admin_Manage to terminate processes." — has no published template and no per-route source, so it is not attempted. All of the above go on DW-126 as one occurrence; nothing is added to `REQUIRED_ALONGSIDE_TABLE`.

**DW-139 occurrence (chrome divergence, not resolved here).** EXPERIENCE.md:397 scopes the banner component to the panel, form-pages and the Task schedule and does not list instance-unreachable, while :436 puts exactly that banner "at the top of content" and DESIGN.md:1201 names `instance unreachable` as a use of the error variant; :397/:333 call a banner a "full-width strip" and DESIGN.md:1201 calls it "an inline notice, never floating" constrained to the form or table width. DESIGN.md:1021 also says "the three connection words" against the four at EXPERIENCE.md:261, offers three disc colours with no word-to-colour mapping, and points at a subsection of EXPERIENCE.md that does not exist. This story builds a full-width strip at the top of the shell and maps `unreachable` and `server-fault` to the error disc, the two signing-in words to the warning disc, and connected to success — recorded as a decision, not as a resolution of the divergence.

**`SanitizeError` is not the redactor.** `Kernel/Utils.cls:118` strips detail; the AC asks for the detail *in full* with secrets removed. Using it here would satisfy neither half. The backstop name-pattern matcher in `Log.Emit` is the right layer, per the Conventions "Secrets" row; the schema-driven layer arrives with FR-21.

## Verification

**Commands (client):**
- `cd ui && npm run test:tools` -- expected: green, including the new `fault.test.mjs` and the amended `api.test.mjs` / `session.test.mjs`.
- `cd ui && npm run test:components` -- expected: green, including the amended `status-bar.spec.ts`, `app.spec.ts`, `home.page.spec.ts`, `locator-bar.spec.ts` and the new `fault-banner.spec.ts`.
- `cd ui && npm run build` -- expected: `prebuild` passes `client-lint.mjs` (no literal copy in a template) and `screen-mirror.mjs --check`.

**Commands (server):** load and compile through the IRIS MCP tools with `server: "ocupilot-iris"`, never the VS Code extension. **One `iris_execute_tests` call per message, awaited, and never re-submitted on a client-side timeout** — these classes share one live instance and a second concurrent run races their fixtures. Run, in separate messages: `OcuPilot.Test.Fault`, `OcuPilot.Test.Envelope`, `OcuPilot.Test.Log`, `OcuPilot.Test.Routing`, `OcuPilot.Test.Static`, `OcuPilot.Test.Wire`. Confirm the totals against `%UnitTest_Result` with the numeric-run-index SQL probe before calling any of them green.

**What runs live, and what needs a seam.** Everything server-side runs against the live `ocupilot` container unchanged: no namespace, database, account, web application or session is created, modified or ended. **The connectivity probe is never tested by stopping the instance.** Unreachability is produced entirely at the injected `fetch` seam (`ApiOptions.fetch` throwing a `TypeError`, exactly as `ui/tools/api.test.mjs:562-578` already does) and the probe's backoff at the injected `schedule` seam. If a future check ever needs a genuinely absent instance, it runs on a throwaway compose project, never against this repository's compose file.

**Pinning tests, one per AC** (`mutation:` lines are written at the implement stage):
- Total classification -- `ui/tools/fault.test.mjs`, table-driven over every `JsonResult` arm and status band. _mutation: (implement stage)_
- Vendor text never reaches the envelope -- `OcuPilot.Test.Fault`, asserting the raw substring is absent from the rendered body and present in the `Test.LogProbe` capture. _mutation: (implement stage)_
- Code format guard -- `OcuPilot.Test.Envelope`, `Render` refused for `""`, `"403"` and a lower-case code, with nothing written. _mutation: (implement stage)_
- Redaction -- `OcuPilot.Test.Log`, a `pData` key matching the credential pattern is masked in the captured line. _mutation: (implement stage)_
- One re-ask per reader per clear -- `ui/tools/fault.test.mjs` counting calls across a fault-then-clear cycle. _mutation: (implement stage)_
- **Integration AC (status bar)** -- `ui/src/app/shell/status-bar.spec.ts`, asserting the rendered text equals `STRINGS.statusConnectionRetrying` and `data-connection !== 'connected'`. _mutation: (implement stage)_
- **Integration AC (DW-161)** -- `home.page.spec.ts` and `locator-bar.spec.ts`, each with a stub whose first built screen is refused and second is allowed, asserting `router.url` and, in the none-allowed case, `aria-disabled="true"` with `router.url` unchanged. _mutation: (implement stage)_
- DW-104 -- `ui/tools/session.test.mjs`, a transport fault on submit leaves the state on the form with the password retained and one re-submit on retry. _mutation: (implement stage)_
- DW-105 -- `sign-in.spec.ts`, the banner renders the substituted user name and both links, with no literal `<user>` in the DOM. _mutation: (implement stage)_
- DW-119 / DW-135 -- `ui/tools/api.test.mjs`, the identity and map reads re-run exactly once on the probe's first success. _mutation: (implement stage)_

**Geometric claims for the lead's browser gate (jsdom computes no layout).** That the banner is a full-width strip at the top of the shell, that it does not overlay the header or the status bar, and that its error variant meets contrast in both token sets. There is still no browser-runtime harness (DW-159, routed to 1.17), so the lead's per-story smoke is the covering gate for these three.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Planned only; halted after planning as dispatched. Nothing was implemented and nothing was committed. All six routed ledger entries are dispositioned: DW-104, DW-119, DW-135 and DW-161 addressed by I/O matrix rows and acceptance criteria; DW-11 addressed in its classification half with the rendering half named and deferred to the first detail screen; DW-105 addressed in its rendering half with the trigger half declined under Design Notes. Two amendments are recommended to the lead rather than applied: Story 1.12's I/O matrix row "the first built route" (DW-161, spec-bound), and one DW-126 occurrence plus one DW-139 occurrence for the copy and chrome gaps this story met.
