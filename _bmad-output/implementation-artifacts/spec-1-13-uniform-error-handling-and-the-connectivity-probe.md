---
title: 'Story 1.13: Uniform error handling and the connectivity probe'
type: 'feature'
created: '2026-09-12'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: true
context: []
warnings: ['oversized']
deferred:
  - summary: >-
      The expired-password banner links "the README" to the repository's public GitHub URL,
      which is a product decision the owner has not taken.
    evidence: |-
      `sign-in.ts` hard-codes `https://github.com/jbrandtmse/OcuPilot#readme`. It is the repo's
      actual `origin`, not invented, and EXPERIENCE.md :427 requires both links -- but the
      project is dark until 2026-09-24, so the URL may 404 for every user who reaches the
      state, and it puts the owner's account name in shipped copy. The state has no trigger on
      this build, so nothing renders it today. Settled by the owner naming the destination, or
      by dropping that anchor (`linkParts` already keeps the sentence whole without it).
    location: >-
      ui/src/app/shell/sign-in.ts:34
    severity: medium
  - summary: >-
      No executed test crosses from a thrown fetch to a rendered banner: the service half runs
      without a DOM and the component half against hand-written stubs.
    evidence: |-
      The real `ConnectivityService` is constructed only in `src/main.ts` and in
      `ui/tools/fault.test.mjs`; `app.spec.ts`, `fault-banner.spec.ts` and `status-bar.spec.ts`
      each provide a `StubConnectivity`. A wiring fault between the two halves would be
      invisible to both. The browser-runtime harness is DW-159, routed to 1.17; until then the
      lead's per-story smoke is the covering gate.
    location: >-
      ui/src/app/shell/fault-banner.spec.ts
    severity: medium
  - summary: >-
      The connectivity probe has no timeout, so a connection that is accepted and never
      answered stalls the backoff chain indefinitely.
    evidence: |-
      `runProbe` awaits `requestJson` with nothing racing it. Pre-existing rather than caused
      here: `ui/` contains no `AbortController` anywhere, which the spec's own Code Map
      records. A transport fault is reported promptly; only a hung socket is affected.
    location: >-
      ui/src/app/core/connectivity.ts:175
    severity: medium
  - summary: >-
      The banner's gated "Open messages.log" control carries no reason, unlike every other
      gated control in the shell.
    evidence: |-
      Home's tile, the locator segment and the side bar all name the failed pair through
      `privilegeRequiresResource` and `aria-describedby`. The banner's control is gated today
      because no screen over `log-entry` is built, and EXPERIENCE.md publishes no sentence for
      "not built yet" -- so rendering one would invent copy (DW-126). The verdict-refused half,
      which does have a pair to name, arrives with the first log screen in Epic 6.
    location: >-
      ui/src/app/shell/fault-banner.ts:129
    severity: low
  - summary: >-
      The `"string"` type hint on the rendered `code` cannot be falsified while `IsValidCode`
      refuses every numeric code.
    evidence: |-
      `TestRenderedCodeIsAlwaysAJsonString` passes with or without the hint, and its own doc
      comment says so. The guard makes the hint unreachable defense rather than dead code, so
      there is no useful assertion to add; recorded here rather than removed, since deleting
      the hint would rely on the guard never being widened.
    location: >-
      src/OcuPilot/Api/Error.cls:195
    severity: low
baseline_revision: '5eebe5585c6f7c9c3b676a80d9d623155fec13cc'
baseline_commit: '5eebe5585c6f7c9c3b676a80d9d623155fec13cc'
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
| **Submit meets an unreachable instance** (`DW-104`) | `formLogin` transport fault (`session.ts:410`) | the form stays on screen with the typed password intact and the unreachable banner above it; pressing `actionRetry`, or the probe succeeding, re-submits what the user typed | 404 / 5xx keep the 1.6 `installing` behavior |
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

### Review Findings

**2026-09-12 — first code review.** Four layers at `full-opus`, 55 rows grouping to 22 root causes: 2 high, 4 medium, 16 low. Every high and medium is patched here or ledgered with an owner; nothing is left unresolved. Verified after the patches: 390 tool tests, 171 component tests (17 files), a clean build through `version-guard` / `client-lint` / `screen-mirror --check`, and `Log` 10, `Fault` 5, `Wire` 13 on `ocupilot-iris`, confirmed against `%UnitTest_Result` by the numeric-run-index probe. Seven mutations were demonstrated red and reverted byte-identical; one stayed green and corrected its test.

Patched:

- `[high]` `[patch]` **DW-104's parked re-send was deleted before anything could drain it.** `formLogin`'s unreachable arm settles on `form`, which notifies, and `App.verifyWhenSignedIn` answers every not-signed-in notification with `connectivity.reset()` — clearing `pending` one turn after `main.ts` parked the re-send. Reproduced A/B against the real modules: with `App`'s subscriber the submit is never re-sent and the tab ends on `form`; without it, Retry re-sends and the tab signs in. The I/O matrix row's "pressing `actionRetry`, or the probe succeeding, re-submits what the user typed" did not happen in the shipped composition, and no test saw it because `fault.test.mjs` rebuilds the graph without `App`. Fixed with a `survivesReset` park that `reset()` keeps; `App`'s subscriber is now in the DW-104 row, and the composition-root test asserts the `true`.
- `[high]` `[patch]` **A park could still be stranded — the same sibling one kind further along.** `note()` drained only on a success and armed only on `unreachable`, so an answer of a kind the banner has no copy for replaced the verdict, took the strip off screen and scheduled nothing. Reproduced: a 500 parks `verify()` and raises the banner, a 403 on another reader clears it, and the tab sits on `checking` with no banner, no timer and nothing outstanding — DW-119's own condition. The probe is now armed for a park that has just lost its trigger, and only for that: a park made under a kind that never had a banner arms nothing, because a 403 is reported and never retried (AD-8).
- `[medium]` `[patch]` **Only the probe's own answer ended the backoff.** The review pass removed the reset in `note()`'s success arm on a mutation that stayed green — green because every backoff row recovers by firing the scheduled probe, the one path `runProbe`'s reset covers. An outage that ends while ordinary traffic is flowing left `probeAttempts` at the cap, so a second outage re-probed at 8 s. Restored, with a row that recovers through an ordinary call.
- `[medium]` `[patch]` **The `everAdopted` guard silenced the tabs that earned the message.** It is set only by `adopt()`, and `start()`'s DW-6 reload branch reaches `signed-in` without calling it — so a reloaded tab whose refresh was later refused settled on the bare form instead of `session-ended` (EXPERIENCE.md `:571`). Set in the adopted branch; a third row covers the reload path the two existing rows share a blind spot on.
- `[low]` `[patch]` **`Log.Redact` compacted a sparse array.** `%GetNext` skips unassigned elements and `%Push` appends, so `["a",,,"z"]` came back as `["a","z"]` — two members gone and the last moved from index 3 to index 1. Reproduced on the instance. The array branch now writes each member back at its own index, which also deletes two branches. No shipped caller builds a sparse payload today; the fix is the same rule the dense case already had.
- `[low]` `[patch]` `Kernel.Fault.Normalize`'s `Catch` reset three of its four outputs, leaving `pDetail` holding vendor text.
- `[low]` `[patch]` Three doc claims corrected at their origin: `note()`'s "any answer is the drain trigger" and `retryWhenReachable`'s "drains on the first answer of any kind" (neither was true, and the test named for it exercised only a success); `post()`'s "all three token endpoints" (`signOut` posts `/logout` directly); `hasUnansweredSubmit`'s "the form's Retry is live exactly while it is" (the form renders no Retry); `isBannerFault`'s claim that all four other kinds have surfaces (`absent` has none until Epic 2).

Dispositioned, not patched:

- `[medium]` `[routed]` `shell/rail.ts:167` is DW-161's third site and still takes `screensForArea()[0]`. Latent on this build — one navigating area, one screen, no privileges — and `rail.ts` is Story 1.10's file, so the residual is recorded on DW-161 rather than re-filed.
- `[medium]` `[routed]` The banner's error variant reads `--ocu-error-container` / `--ocu-on-error-container`, which `:root.ocu-theme-dark` does not remap, so the theme toggle does not reach it and the spec's "contrast in both token sets" claim cannot be settled by one. Pre-existing and whole-stylesheet: recorded as an occurrence on **DW-118**, beside `_components.scss:318` and `:1453`.
- `[low]` `[wontfix-theoretical]` **DW-170** — `Render` type-hints `code` but not `reason`.
- `[low]` `[wontfix-accepted]` **DW-171** — the frontmatter `location:` lines and `## Auto Run Result` carry claims this diff superseded (all five locations miss their subject; the "nothing crosses from a thrown fetch to a banner" risk is closed by QA's own `fault-banner.wire.spec.ts`; `spec-1-12-home.md` was amended in `5eebe55`; the counts read 390/167 against 390/171). Recorded rather than corrected because a review may not edit those sections.
- `[low]` `[wontfix-theoretical]` `reset()` leaves `recovering` set, so a sign-out during an outage can carry "Signing in again…" into the next principal's first request. The frame is not rendered while signed out and the first successful call clears it, so the window is one request.
- `[low]` Closed at emission, one line each. `by-design`: `Redact`'s catch-all returns an empty value of the same kind with no marker (the method's own comment states that rationale — an empty value can carry no secret); the probe's recovery costs two GETs of the same path, which `PROBE_PATH = INSTANCE_PATH` buys deliberately and a row asserts. `wontfix-theoretical`: `currentPassword` can outlive the form when a silent probe adopts while a submit is unanswered — narrowed by the DW-104 patch above, which now drains and clears it inside the same request chain; `Session`'s install backoff and the connectivity probe are two chains against one unreachable instance, each capped at 8 s. `wontfix-accepted`: `TestCredentialValuesAreMaskedInTheEmittedLine` spells the key `"refresh token"` where `TestCredentialNameMatching` covers the canonical `refresh_token`; `Test/Envelope`'s parameter sweep walks inherited parameters and its `tChecked >= 19` floor is hand-maintained; `home.page.spec.ts`'s gated-in-place row leans on its `visibleArea()` assertion because `router.url` is `/` either way; `linkParts` requires its phrases in sentence order and says so nowhere; `app-fault-banner:empty { display: none }` is a fourth geometric claim absent from the list handed to the browser gate.
- `[low]` `[by-design]` QA's `fault-banner.wire.spec.ts` holds up: it constructs the production `TokenStore`, `Session`, `ConnectivityService`, `ApiService` and `NavigationService` with only `fetch`, `schedule` and storage as seams, drives the real `FaultBanner` through `TestBed`, and asserts rendered DOM. All three of its recorded mutations discriminate. Its one limit — `Session` is built without `onUnreachable`, so the DW-104 crossing is not in it — is what the first high above was hiding behind; the DW-104 row now carries that crossing. The browser-runtime gap itself stays DW-159.

## Spec Change Log

**Decision (overnight): the `EXPERIENCE.md:n` comment drift is whole-file, so all of it is corrected, not four keys.** Tasks & Acceptance says the four connectivity and status-bar keys are "one line short ... so the block does not read as two conventions". Measured: 108 of `strings.ts`'s 113 numeric references are one short, and the three at `:207`, `:246`, `:252` are correct — commit `15bc466` inserted the version-mismatch row at EXPERIENCE.md `:253` and shifted every row below it. Correcting only four would *create* the two conventions the task exists to prevent. So every reference `>= 253` gains 1, the three below stay, and the new keys are written at their true rows. Comment-only; no value, key or test expectation changes.

**Correction (implement stage): the count above is 108/113, and the drift is 105/113. The blanket "`>= 253` gains 1" rule would have broken three already-correct references.** Re-measured mechanically, by resolving each reference against the line EXPERIENCE.md actually carries its value on rather than by applying the shift: 105 references are one short and 8 are already correct. The eight are `:207` (×2) and `:246` (×2), which the entry already names; `:252`, likewise; **and `:315`, `:316`, `:319`** — Story 1.10's three, authored *after* commit `15bc466` and therefore written against the shifted file. `:590` (×2), authored before it, is one short and becomes `:591`. So the rule applied is "correct each reference to the row that carries its value", not "+1 below a line number": the 104 key-row comments were resolved against the Fixed strings table's own row range (located by heading, as `ui/tools/strings.test.mjs` locates it), 103 moved by exactly +1, `authNoAdminPrivileges` was already right, and the prose references were checked one at a time. Still comment-only; no value, key or test expectation changed.

## Review Triage Log

### 2026-09-12 — Review pass

- verdicts: 44 findings from the four layers — high 2, medium 20, low 21, false 1, maybe-false 0 — plus 1 high the pre-commit gate caught that no layer did (last row)
- findings:
  - `[medium]` `[patch]` `Log.Redact` rebuilt a nested array as an object — reproduced on the instance (`{"left":["a"]}` → `{"left":{"0":"a"}}`); `Installer.Uninstall` logs a pushed array, so it is a live path. Fixed with `IsArray`/`EmptyLike` + `%Push`; pinned by `TestRedactKeepsAnArrayAnArray`.
  - `[medium]` `[patch]` `probeAttempts` never reset — reproduced: a second outage's first re-probe waited 8000 ms. Reset in `runProbe` on any response; pinned by two rows (success and non-ok answer).
  - `[medium]` `[patch]` the probe drove a never-signed-in tab to `session-ended` — reproduced end to end (cold start, instance returns 401, card reads "Your session ended."). Fixed with `Session.everAdopted` guarding `retryProbeThenEnd`'s escalation.
  - `[high]` `[patch]` a parked re-ask could be stranded — reproduced: a 500 parks `verify()`, an unrelated success clears the fault and takes the banner (its only trigger) with it, leaving `checking` with nothing scheduled. `note(null)` now drains; pinned.
  - `[medium]` `[patch]` parked work survived sign-out — reproduced: the departed principal's map was re-read after a sign-out. `ConnectivityService.reset()` added and called from `app.ts` beside the other three.
  - `[medium]` `[patch]` `navigation.ts` parked before its generation guard while `scope.ts` guarded first — guard moved above the failure branch; pinned.
  - `[low]` `[patch]` `status-bar.ts`'s doc claimed a server fault takes the error disc, which its own test disproves — comment corrected.
  - `[low]` `[patch]` `data-fault` documented as "read by CSS" with no rule reading it — comment corrected to say what it is and what still owes a rule.
  - `[medium]` `[patch]` `Kernel/Fault.cls` minted five `PORT.*` codes and two defaults as literals — the exact drift `CodeForStatus` was added to close. Declared in `Api/Error.cls` and referenced.
  - `[low]` `[reject]` `Render`'s refusal is discarded by both `ReportHttpStatusCode` overrides — real, but unreachable: every declared code now passes the guard, and the sweep below proves it per code. Fixing it would add branches to a path no shipped input reaches.
  - `[medium]` `[patch]` nothing verified the 105 rewritten `EXPERIENCE.md:n` comments — resolver test added to `strings.test.mjs`; it passes, which independently confirms the renumbering.
  - `[low]` `[patch]` `CREDENTIALNAMES`' comment promised a bare `key` match the list does not make — corrected, and the gap named as the backstop's known edge.
  - `[low]` `[reject]` `retry()` has no in-flight guard — repeated clicks issue extra GETs; `refresh()` is already single-flight, so the harm is negligible and the fix adds state and an affordance.
  - `[low]` `[defer]` the banner's gated `Open messages.log` carries no reason — today's reason ("not built yet") has no published copy, so rendering one would invent it; the verdict-refused half arrives with Epic 6.
  - `[medium]` `[patch]` `main.ts`'s six wiring lines had no guard — each deletable with a green suite. Six clauses added to `session.test.mjs`'s composition-root test, as 1.6/1.9/1.10/1.11 each did.
  - `[low]` `[reject]` `Kernel.Fault` has no production caller — by-design and stated in the spec and the class header; Epic 2 is where a port produces vendor failures.
  - `[low]` `[patch]` the shipped-codes sweep was a hand-typed list that already omitted `PORT.*` — replaced by a sweep over the writer's own parameters, with a floor so an empty sweep cannot pass.
  - `[low]` `[reject]` the Verification line referenced a mutation list not yet written — the finalize step writes it; a finding whose fix edits this build's spec is rejected by rule.
  - `[low]` `[reject]` the spec is `oversized` and grew — same rule; the sections added here are the ones the workflow mandates.
  - `[medium]` `[defer]` `sign-in.ts` hard-codes `https://github.com/jbrandtmse/OcuPilot#readme` — it is the repo's actual remote, not fabricated, and the state is unreachable on this build, but publishing a URL is the owner's call under the pre-release policy.
  - `[low]` `[patch]` `drain()` notified on every tick, contradicting `note()`'s own "notifies nobody" rule — now silent when nothing was pending.
  - `[medium]` `[patch]` (edge-case layer) `probeAttempts` — same root cause as above; same fix.
  - `[medium]` `[patch]` (edge-case layer) array redaction — same root cause as above; same fix.
  - `[low]` `[reject]` one parked reader throwing would strand the rest — no reachable synchronous throw was shown; every parked closure is a `void`-wrapped call.
  - `[medium]` `[patch]` (edge-case layer) navigation guard order — same root cause as above; same fix.
  - `[medium]` `[defer]` the probe has no timeout, so a connection that never settles stalls the chain — pre-existing: `ui/` has no `AbortController` anywhere, and the Code Map records that.
  - `[low]` `[patch]` (edge-case layer) bare `key` not matched — same root cause as above; comment corrected.
  - `[medium]` `[patch]` (edge-case layer) `PORT.*` vocabulary — same root cause as above; same fix.
  - `[low]` `[reject]` AC3's "the banner disappears" vs a 5xx probe response keeping it — the behavior is right (the instance answered and failed); the AC's wording is about the unreachable fault clearing. Spec-bound, closed by-design.
  - `[medium]` `[patch]` `isRecovering()`'s producer had no executed test host — the arm could be deleted with a green suite, making the fourth published word unreachable. Row added over the real service.
  - `[medium]` `[patch]` (verification-gap layer) `main.ts` wiring — same root cause as above; same fix.
  - `[low]` `[defer]` the `"string"` type hint on `code` is unfalsifiable while `IsValidCode` refuses every numeric code — no useful test exists to add; recorded rather than removed.
  - `[medium]` `[patch]` (verification-gap layer) array redaction — same root cause as above; same fix.
  - `[medium]` `[patch]` (verification-gap layer) `probeAttempts` — same root cause as above; same fix.
  - `[low]` `[patch]` AC3's banner-clearing clause had no `mutation:` line — added to `## Verification`.
  - `[high]` `[patch]` (intent layer) the probe's reach: every park site parks on any non-`ok` result while only `unreachable` armed a probe — the same root cause as the stranded re-ask; closed by draining on any answer.
  - `[medium]` `[defer]` nothing crosses from a thrown `fetch` to a rendered banner — the service half runs without a DOM, the component half against stubs. DW-159 routed the browser harness to 1.17.
  - `[low]` `[reject]` the Refused row's inline `role="alert"` is not new work — by-design: the spec's Design Notes say the per-action phrase has no published template, and the gated-control refusal is shipped.
  - `[low]` `[reject]` (intent layer) `Kernel.Fault` uncalled — same as above; by-design.
  - `[false]` redaction masks nothing on the actual 500 path — checked: `RenderInternal` logs under the key `detail`, which carries no credential; the row asks for credential-named values masked, and there are none on that path. Not a defect.
  - `[low]` `[reject]` DW-161 is exercised against fixtures — the shipped mirror has one built screen, so the precondition cannot arise from it; the tests say so and `navigation.test.mjs` pins the real roster too.
  - `[low]` `[reject]` `Open messages.log` ships inert — by-design; the destination resolves from the descriptor mirror and goes live in Epic 6 with no code change.
  - `[medium]` `[patch]` (intent layer) backoff reset — same root cause as above; same fix.
  - `[high]` `[patch]` **(not from a review layer — `.githooks/pre-commit` refused the commit)** two test fixtures named `%Api.Admin` in string values, which AD-27 caps at `Port/AdminPort.cls` however the name is spelled; `scripts/check-objectscript.py` targets exactly that spelling and exempts doc comments. Both replaced with a stand-in class name; the prose explaining what it stands for stays. Worth recording that four layers reading the same diff missed it and a nine-line rule did.
  - `[low]` `[reject]` scope beyond the intent (whole-file comment renumber, the fourth status word, DW-105's links) — the renumber is recorded as a decision above; the fourth word is EXPERIENCE.md `:261`'s own and the status bar's published contract; the README URL is its own row.

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

**DW-139 occurrence (chrome divergence, not resolved here).** EXPERIENCE.md:397 scopes the banner component to the panel, form-pages and the Task schedule and does not list instance-unreachable, while :436 puts exactly that banner "at the top of content" and DESIGN.md:1201 names `instance unreachable` as a use of the error variant; :397/:333 call a banner a "full-width strip" and DESIGN.md:1201 calls it "an inline notice, never floating" constrained to the form or table width. DESIGN.md:1021 also says "the three connection words" against the four at EXPERIENCE.md:261, offers three disc colours with no word-to-color mapping, and points at a subsection of EXPERIENCE.md that does not exist. This story builds a full-width strip at the top of the shell and maps `unreachable` and `server-fault` to the error disc, the two signing-in words to the warning disc, and connected to success — recorded as a decision, not as a resolution of the divergence.

**`SanitizeError` is not the redactor.** `Kernel/Utils.cls:118` strips detail; the AC asks for the detail *in full* with secrets removed. Using it here would satisfy neither half. The backstop name-pattern matcher in `Log.Emit` is the right layer, per the Conventions "Secrets" row; the schema-driven layer arrives with FR-21.

## Verification

**Commands (client):**

- `cd ui && npm run test:tools` -- expected: green, including the new `fault.test.mjs` and the amended `api.test.mjs` / `session.test.mjs`.
- `cd ui && npm run test:components` -- expected: green, including the amended `status-bar.spec.ts`, `app.spec.ts`, `home.page.spec.ts`, `locator-bar.spec.ts` and the new `fault-banner.spec.ts`.
- `cd ui && npm run build` -- expected: `prebuild` passes `client-lint.mjs` (no literal copy in a template) and `screen-mirror.mjs --check`.

**Commands (server):** load and compile through the IRIS MCP tools with `server: "ocupilot-iris"`, never the VS Code extension. **One `iris_execute_tests` call per message, awaited, and never re-submitted on a client-side timeout** — these classes share one live instance and a second concurrent run races their fixtures. Run, in separate messages: `OcuPilot.Test.Fault`, `OcuPilot.Test.Envelope`, `OcuPilot.Test.Log`, `OcuPilot.Test.Routing`, `OcuPilot.Test.Static`, `OcuPilot.Test.Wire`. Confirm the totals against `%UnitTest_Result` with the numeric-run-index SQL probe before calling any of them green.

**What runs live, and what needs a seam.** Everything server-side runs against the live `ocupilot` container unchanged: no namespace, database, account, web application or session is created, modified or ended. **The connectivity probe is never tested by stopping the instance.** Unreachability is produced entirely at the injected `fetch` seam (`ApiOptions.fetch` throwing a `TypeError`, exactly as `ui/tools/api.test.mjs:562-578` already does) and the probe's backoff at the injected `schedule` seam. If a future check ever needs a genuinely absent instance, it runs on a throwaway compose project, never against this repository's compose file.

**Pinning tests, one per AC.** Every `mutation:` below was applied, observed red, reverted, and the tree confirmed byte-identical (`git diff` against `baseline_revision` unchanged after each). **42 were demonstrated in all** — 30 over the first cut and 12 over the review patches, the latter listed with the patched rows under `## Auto Run Result`. Two more were applied and **stayed green**; each is recorded where it matters rather than quietly dropped, because a mutation that does not go red is a claim about the test that was wrong.

- Total classification -- `ui/tools/fault.test.mjs`, table-driven over every `JsonResult` arm and status band, plus a sweep over 0-599 asserting no status is unclassified. _mutation: `classifyFault`'s 403 branch returns `server-fault` -> the 403 table rows go red._
- Vendor text never reaches the envelope -- `OcuPilot.Test.Fault`, over the body `Test.Dispatch` captures from the `/vendor-fault` fixture route, with the raw text asserted present in the `Test.LogProbe` capture. _mutation: `Normalize` sets `pReason` to its `GetOneStatusText` output -> `TestVendorTextReachesTheLogAndNeverTheEnvelope` red on "the vendor class name never reaches the rendered envelope"._
- Code format guard -- `OcuPilot.Test.Envelope`, `Render` refused for ten malformed codes with nothing written, and every shipped code asserted to pass. _mutation: `IsValidCode`'s body replaced with `Quit pCode '= ""` -> `TestMalformedCodeIsRefusedAndNothingIsWritten` red on `403`, `500` and `route.notfound`._
- Code vocabulary has one spelling -- `OcuPilot.Test.Envelope`. _mutation: `$Translate` dropped from `CodeForStatus` -> `TestCodeForStatusIsUnseparatedAndPassesTheWritersOwnGuard` red with `ROUTE.SERVER_ERROR`._
- Redaction -- `OcuPilot.Test.Log`, over the emitted line via `Test.LogProbe`, plus a direct pin that `Redact` copies rather than masking in place. _mutation: the `Redact` call deleted from `Emit` -> `TestCredentialValuesAreMaskedInTheEmittedLine` red while `TestRedactCopiesRatherThanMasksInPlace` stayed green._
- One re-ask per reader per clear -- `ui/tools/fault.test.mjs` counting calls across a fault-then-clear cycle. _mutation: `drain()` no longer clears `pending` -> "nothing is owed a second re-read" red. **Not** the keyed-map-to-array mutation the plan proposed: that one was applied and stayed green, because each reader's own `load()`/`verify()` is already single-flight, so duplicate keys collapse at the reader rather than in the map. Draining once is the property this AC actually rests on._
- **Integration AC (status bar)** -- `ui/src/app/shell/status-bar.spec.ts`, asserting the rendered text equals `STRINGS.statusConnectionRetrying` and `data-connection !== 'connected'`. _mutation: the `unreachable` arm deleted from `connectionWord` -> the Integration AC row red; deleting the `isRecovering` arm separately reddens the fourth-word row._
- **Integration AC (DW-161)** -- `home.page.spec.ts` and `locator-bar.spec.ts`, each with a stub whose first built screen is refused and second is allowed. _mutation: `screens[0]` restored as the target in each -> both "opens the first screen whose OWN verdict allows" rows red; forcing `blocked`/`gated` false reddens both "gated in place" rows._
- DW-104 -- `ui/tools/session.test.mjs`, a transport fault on submit leaves the state on the form with the password retained and one re-submit on retry; 404/5xx rows assert the 1.6 behavior unchanged. _mutation: `formLogin`'s `unreachable` arm no longer sets `submitUnanswered` -> state, password and re-send rows red; clearing the password unconditionally in `runSubmit` reddens the password row alone._
- DW-105 -- `sign-in.spec.ts`, the banner renders the substituted user name and both links, with no literal `<user>` in the DOM. _mutation: the `formatUser` call dropped -> "expected ... to contain '_SYSTEM'" red; passing `[]` for the link phrases reddens the two-anchor row._
- DW-119 / DW-135 -- `ui/tools/fault.test.mjs` (the wired harness lives there, beside `ConnectivityService`); `ui/tools/api.test.mjs` carries the `onFault` seam itself. _mutation: each reader's `retryWhenReachable` park disabled in turn -> the instance, map and namespace re-read rows red one at a time; deleting `Session.post`'s `report(path)` reddens the DW-1 third row._
- The banner clears when the fault does -- `ui/src/app/shell/fault-banner.spec.ts`, the row that publishes `null` after an `unreachable` and asserts the strip is gone (not vacuous: the rows above it prove the same stub renders the strip). _mutation: `isBannerFault` widened to every kind but `not-installed` -> the "goes the moment the fault clears" row stays green but the four-other-kinds row goes red; returning `true` for a null fault reddens the clearing row itself._
- **(QA) DW-159 sibling -- the thrown-fetch-to-rendered-banner crossing** -- `ui/src/app/shell/fault-banner.wire.spec.ts` (new), the real `ApiService` and `ConnectivityService` wired exactly as `src/main.ts` wires them over an injected `fetch`, asserted against the real `FaultBanner`'s rendered DOM for `unreachable` (a thrown `TypeError`) and `server-fault` (a plain 500), plus Retry re-probing through the real service. _mutation: `ApiService.report`'s `this.onFault(...)` call removed -> all three rows red, since `ConnectivityService.note` is never told. mutation: `ConnectivityService.retry` no longer calls `runProbe` -> the Retry row's call-count assertion red. mutation: `classifyFault`'s final branch returns `rejected` instead of `server-fault` -> the server-fault row red._

**Added by the code review (2026-09-12), each applied, observed red and reverted byte-identical.**

- AC3's first clause, the fault itself clearing -- `ui/tools/fault.test.mjs`'s "any HTTP response clears the unreachable verdict" row, which had no line of its own here. _mutation: guard `note`'s assignment as `if (fault !== null) this.currentFault = fault;` -> the `[200, null]` row reads `unreachable` and goes red, while the drain and banner rows are unaffected._
- DW-104 crosses `App`'s own reset -- the DW-104 row now runs `app.ts`'s session subscriber. _mutation: drop the `true` third argument from `retryWhenReachable` in the harness -> "the submit was sent again" red with the tab still on `form`; dropping it in `main.ts` reddens the composition-root row in `session.test.mjs`._
- A park is never left with neither a banner nor a timer. _mutation: delete the `isBannerFault(previous) && !isBannerFault(fault)` arm from `note` -> the 403-after-500 row red with nothing scheduled._
- ...and AD-8's other half, that a park which never had a banner arms nothing. _mutation: widen that arm to `this.pending.size > 0` alone -> the two-refusal row red. **Applied first against a one-read version of that row and it stayed green** -- a reader registers its park after `requestJson` resolves, so at the first `note` the pending set is still empty and any arming rule passes. The test was corrected, not the claim._
- An ordinary success ends the backoff. _mutation: delete `this.probeAttempts = 0;` from `note`'s success arm -> the second outage's first delay is 8000 and the new row goes red; deleting `runProbe`'s reset instead reddens the two probe-recovery rows, not this one._
- A reloaded tab that held a pair still reports that its session ended. _mutation: delete `this.everAdopted = true;` from `start()`'s adopted branch -> the reload row reads `form` and goes red while the two rows around it stay green._
- A sparse array keeps its holes and its indices -- `OcuPilot.Test.Log`. _mutation: write the array branch back as `%Push` -> `TestRedactKeepsASparseArraySparse` red on size and index while `TestRedactKeepsAnArrayAnArray` stays green._

**Geometric claims for the lead's browser gate (jsdom computes no layout).** That the banner is a full-width strip at the top of the shell, that it does not overlay the header or the status bar, and that its error variant meets contrast in both token sets. There is still no browser-runtime harness (DW-159, routed to 1.17), so the lead's per-story smoke is the covering gate for these three.

## Auto Run Result

Status: done
Blocking condition: none

One client failure taxonomy (`core/fault.ts`), one connectivity service owning the verdict, the probe and its backoff (`core/connectivity.ts`), one `role="alert"` banner mounted above both of `app.ts`'s gates, and the status bar's four published connection words. Server-side the `code` half of AD-12/AD-39 closes: five undeclared codes plus five `PORT.*` declared in the one writer, the two `ROUTE.*` spelling families collapsed into `CodeForStatus`, and "never a number" made a guard in `Render` rather than a comment. Plus `Kernel/Fault.cls` for `%Status` normalization and a backstop redactor in `Log.Emit`. Every I/O matrix row has a pinning test that ran and passed.

**Files changed.** Server: `Api/Error.cls` (five undeclared + five `PORT.*` codes, `CodeForStatus`, `IsValidCode` + `CODEPATTERN`, the `"string"` hint), `Api/Router.cls` and `Api/StaticHandler.cls` (literals and both local derivations replaced), `Kernel/Fault.cls` (new — `Normalize`/`LogRaw` over the one writer's slugs and codes), `Kernel/Audit/Log.cls` (`Redact`/`IsCredentialName`/`IsArray`/`EmptyLike`), `Test/Fault.cls`, `Test/FaultProbe.cls` (new), `Test/Envelope.cls`, `Test/Log.cls`, `Test/RouterFixture.cls`. Client: `core/fault.ts`, `core/connectivity.ts`, `shell/fault-banner.ts` (+ spec) new; `core/api.ts` (`onFault`), `core/instance.ts`/`navigation.ts`/`scope.ts` (parked re-asks), `core/session.ts` (DW-104's split, `formatUser`/`linkParts`, `everAdopted`), `core/strings.ts` (four keys, all line references corrected), `app.ts`, `shell/status-bar.ts`, `shell/sign-in.ts`, `areas/home/home.page.ts`, `shell/locator-bar.ts`, `src/main.ts`, `styles/_components.scss`, and eight test files.

**Review findings: 44 across four layers — 2 high, 20 medium, 21 low, 1 false.** 27 rows patched (grouped into 13 root causes), 5 deferred, 11 rejected with reasons; every row is in the triage log. The two `high` rows were one root cause: a re-ask parked by a kind that arms no probe had nothing to drain it, and the next successful call cleared the fault and took the banner — its only remaining trigger — with it, leaving the tab on `checking` with nothing scheduled, which is DW-119's own condition one layer up. Four findings were reproduced against the real modules before being graded (stranded re-ask; `session-ended` on a tab that never had a session; parked work surviving sign-out; a second outage starting at the 8 s cap).

**Verified after the patches.** Client: `npm run test:tools` 390 pass, `npm run test:components` 167 pass (16 files), `npm run build` clean through `version-guard`, `client-lint` and `screen-mirror --check`. Server, one `iris_execute_tests` call per message against `ocupilot-iris`: `Fault` 5, `Envelope` 15, `Log` 9, `Routing` 18, `Static` 16, `Wire` 13 — 76 methods, 76 passed, confirmed against `%UnitTest_Result` with the numeric-run-index probe. Unreachability was produced only at the injected `fetch` seam and the backoff only at the injected `schedule` seam; no container command, namespace, database, account, application or session was touched.

**Mutations demonstrated: 42** (Rule 19), each applied, observed red, reverted, with the tree confirmed byte-identical after. The twelve over the review patches: `note`'s success arm no longer drains → the stranded-re-ask row; `runProbe`'s `probeAttempts = 0` deleted → both backoff rows; `reset()` emptied → the AD-8 row; `nextRecovering`'s on-arm dropped → the `isRecovering` row; `navigation.ts`'s generation guard moved back below the failure branch → the departed-principal row; the `everAdopted` guard dropped → the never-had-a-session row; `onFault` deleted from `main.ts` → the composition-root row; one `EXPERIENCE.md:n` comment decremented → the resolver row; `connectivity.reset()` deleted from `app.ts` → the AD-8 component row; `EmptyLike` forced to `{}` → the array row; `PORT.ACCESSDENIED` re-minted as `PORT.ACCESS_DENIED` → the parameter sweep, which named the offending parameter and which the previous hand-typed list could not have caught; `isBannerFault` returning true for a null fault → the banner-clearing row.

**Two mutations were applied and stayed green, and each produced a correction rather than being dropped.** (1) The plan's proposed "replace the keyed `pending` map with an array" does *not* redden the one-re-ask-per-reader row, because each reader's own `load()`/`verify()` is already single-flight and collapses the duplicates itself; the property that row actually rests on is that `drain()` clears before it runs, and that is now the recorded mutation. (2) Deleting `probeAttempts = 0` from `note`'s success arm reddened nothing, because `runProbe` resets on the same response — the line was redundant and was removed rather than left unpinnable.

**Three decisions the spec left open, taken and recorded.**

**Three decisions the first cut took, kept after review.**

1. **The taxonomy's residual is `rejected`, not `server-fault`.** "Total over `JsonResult` plus HTTP status" needs an answer for 400, 405, 409, 412, 415 and 422, which the matrix's six rows do not name. They map to `rejected` — the instance refused the request and no retry would help — because that kind drives no surface of its own, and mapping them to `server-fault` would raise the "Something failed on the instance" banner for `NS.UNKNOWN`, which `ScopeService.runVerify` *provokes deliberately* on every unresolved namespace.
2. **`Normalize`'s written reason is the table's own sentence, not `GetOneStatusText`'s output.** The task line and the AC disagree: `GetOneStatusText` strips the domain, id and source but not a class name interpolated into the message body, and an interpolated class name is exactly what an `%Api.Admin.*` failure carries — so taking the reason from it would fail the AC it sits beside. The AC wins. `GetOneStatusText` is still used, as `pDetail`, a stripped one-liner for the log beside the raw `GetErrorText` output.
3. **The transport fault splits at `formLogin` only; the silent probe and the refresh keep DW-1's `installing`.** The Design Notes say both "DW-1's rule stands" and "only the transport fault changes". A cold-start probe has no form on screen and no typed password to protect, and routing it to `form` after a failed refresh would have set `session-ended` — "Your session ended" for an instance that is simply not there, which is DW-1's own failure. What every transport fault gains instead is the report that raises the banner. `session.test.mjs:296-315`'s third row is amended accordingly, and DW-104's state change is pinned by its own test beside it.

**One spec-bound item remained the lead's, and is now applied.** Story 1.12's I/O matrix row read "the first built route"; the lead amended it to "the first built route whose screen verdict allows, gated when none does" at `5eebe55`, before this story's implement stage ran, so DW-161 was implementable here rather than worked around. (Corrected by the lead 2026-09-13: this paragraph previously said the amendment was outstanding.)

**Follow-up review: recommended, for one named risk.** A `high` entry was patched, and the risk its fix does not close is that **nothing executed crosses from a thrown `fetch` to a banner on screen**: the connectivity service is exercised under `node --test` with no DOM, and every component that reads it is exercised against a hand-written `StubConnectivity`. The patch for the stranded re-ask changed `note()`, which both halves depend on and neither spans, so a wiring fault between them would still be invisible. The lead's per-story browser smoke is the covering gate until DW-159's harness lands in 1.17; the same smoke is what settles the three geometric claims above (full-width strip at the top of the shell, no overlay of the header or status bar, error-variant contrast in both token sets).

**Residual risks.** The five `deferred:` entries, of which two are the ones a reader should weigh now: the expired-password banner's README link is a real repository URL but a public one, and publishing it before the 2026-09-24 release is the owner's call; and the probe has no timeout, so a socket that is accepted and never answered stalls the chain — pre-existing, since `ui/` carries no `AbortController` anywhere.
