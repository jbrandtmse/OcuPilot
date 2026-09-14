---
title: 'Story 2.1: The AdminPort reproduces the vendor''s dispatcher, exactly once'
type: 'feature'
created: '2026-09-13'
status: 'done'
baseline_revision: '0688712f8cfc4292313aaeacac8d9dc6c3bf28e4'
baseline_commit: '0688712f8cfc4292313aaeacac8d9dc6c3bf28e4'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
deferred:
  - summary: >-
      A caller holding %Admin_Secure but not %Admin_Operate can queue a Security.Audit.Record LIST task through AdminPort.Invoke, then have its AsyncResult poll refused 403, leaving the queued task row behind.
    evidence: |-
      Live source: Audit.Record ResourcesOR() is %Admin_Secure alone, AsyncResult ResourcesOR() is %Admin_Operate alone; AwaitTask returns the poll's fault without ForgetTask. Unverified: no principal with that split exists in this story (%All passes both), and AD-29's descriptor gate would refuse such a caller first if Story 2.10's descriptor declares both pairs. Settles when Story 2.10's descriptor privilege set is written, or Story 2.5's denied principal runs the audit LIST.
    location: >-
      src/OcuPilot/Port/AdminPort.cls AwaitTask
    severity: medium (unverified)
  - summary: >-
      AdminPort.Invoke fails with a 500 INTERNAL when its caller is already inside a %SYS.Capture that has buffered output, because the vendor BeginCaptureOutput refuses a nested capture.
    evidence: |-
      irislib/%SYS/Capture.int BeginCapture returns "Capture Already Active" whenever ^||%capture exists; Sequence stops on that status. Unverified: no consumer in this story invokes the port under a capture (REST handlers do not). Settles when the turn job or tool executor (Epic 3/4) is shown to call the port inside %SYS.Capture.
    location: >-
      src/OcuPilot/Port/AdminPort.cls Sequence
    severity: medium (unverified)
---

<intent-contract>

## Intent

**Problem:** `OcuPilot.Port.AdminPort` only verifies the instance (Story 1.8), so nothing can call an admin endpoint yet. Called naively, an endpoint loses its HTTP status under `IsRunningAsync`, runs with an empty identifier when `ValidateQueryParams()` is skipped, ignores a `maxRows` cap seeded anywhere but `%request.Data`, throws `<CLASS DOES NOT EXIST>` outside `%SYS`, and answers an async request with a 202 that nobody polls.

**Approach:** Add one invocation entry to `AdminPort` that reproduces `%Api.Admin.Dispatch.v1:Main()` in the vendor's own order, in `%SYS`, behind port-owned stubs for `%request`, `%response` and `%session`. Resolve an async answer by polling `async-result`, normalize every failure through `Kernel.Fault`, and pin the containment check with a planted reference.

## Boundaries & Constraints

**Always:**
- The sequence follows `Main()` on the pinned build, in its order:
  - Construct at `ApiVersion` 2.
  - Gate on `ResourcesOR()` with `$System.Security.Check(res, "U")`. Holding any one resource passes.
  - Seed `%request.Data(name, 1)`, call `SaveQueryParams()`, then `ValidateQueryParams()`. A throw there is a 400.
  - Call `ValidateRequest(body)`, where an error is a 400, then `ValidateSemantics()`, then `ShouldRunAsync()`.
  - Wrap `Run(.tSC, body)` in `BeginCaptureOutput`/`EndCaptureOutput`. A `<PROTECT>` system exception is a 403.
  - An error `tSC` under a 2xx status becomes a 500.
- Callers name an endpoint package-relative (`WebApp.App`) and a type by its vendor parameter suffix: `GET`, `LIST`, or `INFO` for `TYPEINFO`.
  - An unknown class or suffix is refused before construction.
  - No caller names `%Api.Admin` or a vendor type number.
- The invoking frame `New`s `%request`, `%response` and `%session`, then assigns stubs:
  - a `%CSP.Request` with `Method` set and a synthetic `URL` under `/api/admin/v2/ocupilot/`;
  - a `%CSP.Response`;
  - a session stub whose `Username` is `$USERNAME`.
- The stubs keep the caller's own CSP objects out of reach: none is read or written.
- `IsRunningAsync` stays 0 on every endpoint the port constructs.
- The port enters `%SYS` by explicit save and restore (AD-16), with the restore first in every `Catch`. The caller's namespace is unchanged on return.
- The outcome is read from both `tSC` and `%response.Status`.
  - Success means exactly this: `tSC` is OK and the status is 2xx.
  - Anything else returns an error `%Status` and a fault `{error, reason, code}` built by `Kernel.Fault`.
  - The raw vendor text goes only to `Fault.LogRaw`.
- Every invocation first requires `VerifyInstance` to report version 2 with a passing probe. Otherwise it refuses with `unavailable` / `PORT.UNAVAILABLE` and names what failed.
- Only `src/OcuPilot/Port/AdminPort.cls` names `%Api.Admin`, whether in ObjectScript code, an XData body, or ObjectScript embedded in `scripts/*.sh`.

**Never:**
- A slice, descriptor, handler, tool or screen read. Those start in Story 2.3.
- An HTTP call to `/api/admin` (AD-1).
- Caching privilege, the verification result or an async result across calls (AD-8).
- `New $NAMESPACE`, or a `JOB`.
- A mutating vendor call from any test on the shared instance. Reads only.
- Editing `irissys/` or the `AdminInventory` XData. Story 2.2 owns re-deriving it.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Absent web app (AC3) | GET `WebApp.App` with a `name` no instance has | Failure with HTTP 404 and `not_found` / `PORT.NOTFOUND`. Never `{}` as a success | Probed: under `IsRunningAsync` 1 the vendor reads 200 with `{}` |
| Identifier populated (AC4) | GET `WebApp.App`, `name` `/csp/sys` | The endpoint's `Name` is `/csp/sys` when `Run` starts, and the call succeeds with that application | Probed: skipping `ValidateQueryParams()` leaves `Name` empty and fails 404 with `ERROR #5813: Null oid` |
| Row cap reaches the query | LIST `WebApp.App` with `maxRows` 2 | Exactly 2 rows | Probed: seeded by `SaveOneQueryParam` alone, the cap is ignored and 45 rows return |
| Gate refusal | The caller holds none of `ResourcesOR()` | Failure 403 with `forbidden` / `PORT.ACCESSDENIED`. Neither `ValidateQueryParams` nor `Run` executes | none |
| Non-2xx, tSC OK (AC5) | The endpoint sets `404 Not Found` and leaves `tSC` OK | Failure 404, with no success result | none |
| Error tSC under 2xx | The endpoint returns an error `tSC` and leaves the status alone | Failure 500 with Fault's reason | Vendor text appears only in the log |
| `<PROTECT>` | `Run` throws `<PROTECT>` | Failure 403 | none |
| Device output | `Run` writes to the device | Nothing reaches the caller's device, and the result is the endpoint's return value | none |
| Caller untouched | The caller holds its own `%request`, `%response` and `%session`, in `HSCUSTOM` | All three and `$NAMESPACE` are unchanged, after a success and after a failure | none |
| Unverified instance (AC7) | The admin API reports v1, or the probe fails | Refused with `unavailable` / `PORT.UNAVAILABLE`. No endpoint is constructed | The detail names the version or the probe failure |
| Async by `ShouldRunAsync` (AC6) | `Database.SysCRUD` `INFO` on a mounted database directory | Handed off through `AsyncTaskEndpoint`, labelled `<Method> /v2/ocupilot/...`, polled through `AsyncResult` GET, and returned as an ordinary success carrying the task's `Result` | `Failed` gives a failure with Fault's reason. No terminal state within the bound gives `unavailable` / `PORT.TIMEOUT` |
| Audit record LIST (AC6) | `Security.Audit.Record` `LIST` with `maxRows` 1 | `Run()` self-queues and answers 202 with an `async-result` location; the port polls `AsyncResult` to completion and returns the rows as an ordinary result; a poll past `ASYNCTIMEOUT` fails `PORT.TIMEOUT` (AD-26 as amended 2026-09-14) | — |

</intent-contract>

## Code Map

- `src/OcuPilot/Port/AdminPort.cls`: Story 1.8 surface, with the seams `AdminApiClass` (`:40`) and `ProbeEndpointClass` (`:47`), plus `EndpointPackage` (`:55`) and `VerifyInstance` (`:142`). The class doc at `:4-8` says Epic 2 grows the sequence here.
- Vendor classes are `[Hidden]`. Read them with `iris_doc_get` in `%SYS` on `ocupilot-iris`, and never load them.
  - `Dispatch.v1:Main` (`:1485-1577`) is the sequence. Its `ShouldRunAsync()` branch is `AsyncTaskEndpoint.%New(%request, endpoint)`, then `SaveRequestBody(body)`, then `AddToAsyncQueue()`. An error `tSC` under 200, 201 or 202 becomes a 500.
  - `Endpoint`:
    - `%OnNew(type, apiVersion)`;
    - `SaveQueryParams`, which reads `%request.Data`;
    - `SetRespStatus`, guarded by `IsRunningAsync`;
    - `GetName(request)` = `Method _ " " _ $Piece(URL, "api/admin", 2)`.
  - `Util.AsyncTask.AddToAsyncQueue` stamps `%session.Username` and saves a row whose IdKey is `GUID`. It queues the row on a one-worker `WorkMgr`, then sets `202 Accepted` and `Location` `/api/admin/v1/async-result?id=<GUID>`. The terminal states are `Finished` and `Failed`.
  - Self-queued: `Security.Audit.Record.RunList` (`%Admin_Secure`) builds a `RecordListTask`, labels it `..GetName(%request)`, queues it and returns `{}`.
  - `Database.SysCRUD` `TYPEINFO` (11) requires `dir`. Its `RunInfo` is read-only.
  - `Endpoints.AsyncResult` requires `id` and `%Admin_Operate`. `ValidateSemantics` calls `%OpenId` and returns 404 on a user mismatch. `RunGet` returns `State`, `TaskName`, `Result` and `FailureReason`.
  - Probed as `_SYSTEM`:
    - Both entries answer 202 with that `Location`, finish within 28 ms, and read back through `AsyncResult` GET.
    - `%DeleteId(GUID)` removes the row.
    - `%session` is read only as `.Username` in 77 source classes. A `{"Username": ($USERNAME)}` dynamic object works as the stub.
    - No task-schedule entry or exported source calls `PurgeAsyncQueue`.
  - **Trap** (objectscript-basics.md): a task OREF held across the wait makes each poll's `%OpenId` return the stale `Queued` copy. Drop the `AsyncTaskEndpoint` reference before polling.
- `src/OcuPilot/Kernel/Fault.cls`: `Normalize` (`:46`) and `LogRaw` (`:114`). The paragraph at `:17-21` says there is no port call site yet.
- `src/OcuPilot/Api/Error.cls:155-176` holds the `PORT.*` codes. The doc at `:156` says "five". The `UNAVAILABLE` slug is at `:54`.
- `src/OcuPilot/Test/PortFixture.cls`: seam overrides through `^||OcuPilotPortFixture`, falling back to `##super()`. `Test/ProbeFixture.cls` is the duck-typed endpoint precedent. `Test/Instance.cls` and `Test/Fault.cls` pin the existing surface.
- `scripts/check-objectscript.py:576-631`: `check_admin_api_containment` scans ObjectScript under `SCAN_ROOTS` only, with no harness case. Follow the pattern of `FixtureTreeCase` (`scripts/test_check_objectscript.py:44`).
- `scripts/ci-image-compile.sh:109-111` names `"%Api.Admin"` twice in embedded ObjectScript, pinned by `ui/tools/ci.test.mjs:1446-1450`.
- `ui/tools/ci-runner.mjs` runs every `Test/*.cls`. Its leak check covers probe web applications only.

## Tasks & Acceptance

**Execution:**
- `src/OcuPilot/Api/Error.cls`: add `PORTUNAVAILABLE = "PORT.UNAVAILABLE"` and `PORTTIMEOUT = "PORT.TIMEOUT"`, both on the `unavailable` slug, and change "five" to "seven".
- `src/OcuPilot/Kernel/Fault.cls`: map the HTTP status first, then fall back to `Normalize(tSC)`. Replace `:17-21`.
  - 403 → `PORT.ACCESSDENIED`
  - 404 → `PORT.NOTFOUND`
  - 409 → `PORT.CONFLICT`
  - 400 or 422 → `PORT.VALIDATION`
- `src/OcuPilot/Port/AdminPort.cls`: add `Invoke(pEndpoint, pType, ByRef pQuery, pBody, Output pResult, Output pHttpStatus, Output pFault) As %Status`.
  - Seams:
    - `EndpointClass(pEndpoint)`: shape, and that the compiled class exists.
    - `HoldsResource(pResource)`: wraps `$System.Security.Check`.
    - `OnBeforeRun(pEndpoint)`: a no-op.
    - `PollTask(pGuid, Output pAnswer)`: `AsyncResult` GET through the same sequence.
    - `ForgetTask(pGuid)`: `%DeleteId`, with a failure sent only to `LogRaw`.
    - `AsyncTimeout()`: `Parameter ASYNCTIMEOUT = 30` seconds.
  - The session stub is a `%DynamicObject`.
  - A 202 whose `Location` carries `async-result?id=` is polled, from either entry, with a short `Hang` between polls:
    - `Finished` returns `Result` as a 200 success.
    - `Failed` is a 500, with `Fault` building the reason from `FailureReason`.
    - Both terminal states call `ForgetTask`.
    - No terminal state within `AsyncTimeout()` gives `PORT.TIMEOUT` and leaves the row.
  - Rewrite the class doc as the contract.
- `src/OcuPilot/Test/PortFixture.cls`: overrides for:
  - `EndpointClass`, `HoldsResource` and `AsyncTimeout`;
  - `OnBeforeRun`, which records `$Property(endpoint, "Name")`;
  - `PollTask`, which returns an armed canned answer, or else calls `##super()` and records `TaskName`;
  - `ForgetTask`, which records the GUID and calls `##super()` only when no canned answer is armed.
- `src/OcuPilot/Test/EndpointFixture.cls` (new): a duck-typed endpoint with four modes: set 404 with an OK `tSC`, return an error `tSC`, throw `<PROTECT>`, or write to the device.
- `scripts/check-objectscript.py`: extend containment to the lines of `ROOT/scripts/*.sh` that do not start with `#`.
- `scripts/ci-image-compile.sh`: use `##class(OcuPilot.Port.AdminPort).AdminApiClass()` for both literals, and update the pin in `ui/tools/ci.test.mjs` to match.
- Tests (each with a `mutation:` line in `## Verification`):
  - `scripts/test_check_objectscript.py` `TestAdminApiContainment`:
    - A planted reference in a `Test/` class, in an XData body, and on a `scripts/x.sh` code line each yields a problem naming the file.
    - A doc comment, a `#` line and `AdminPort.cls` yield none.
  - `src/OcuPilot/Test/AdminPortSync.cls`: the absent web app, identifier, row cap and caller-untouched rows, against the real `WebApp.App`.
  - `src/OcuPilot/Test/AdminPortFault.cls`, through the fixtures:
    - gate, non-2xx, error-under-2xx, `<PROTECT>`, device output and unverified instance;
    - `Failed`, from a canned answer, gives 500;
    - timeout, from a canned `Running` answer with `AsyncTimeout` 1, gives `PORT.TIMEOUT` and no `ForgetTask` call.
  - `src/OcuPilot/Test/AdminPortAsync.cls`:
    - `Database.SysCRUD` `INFO` on the test namespace's globals-database directory, and `Security.Audit.Record` `LIST` with `maxRows` 1.
    - Each is an ordinary success, and its recorded `TaskName` starts with `GET /v2/ocupilot/`.
    - The `AsyncResult` `LIST` count read through `Invoke` is unchanged afterwards.

**Acceptance Criteria:**
- Given a class, an XData body or a CI script other than `AdminPort.cls` that names `%Api.Admin` in code, when `uv run scripts/check-objectscript.py` runs locally, in the pre-commit hook or in CI's `gates` job, then it exits 1 naming the file and line; on the shipped tree it reports no containment problem over a non-zero file count.
- Given any endpoint invoked through `AdminPort.Invoke`, when it runs, then the vendor steps execute in `Main()`'s order and every matrix row holds.
- Given an async call that reaches `Finished` or `Failed`, when `Invoke` returns, then the task row it queued is gone and the caller's `AsyncResult` `LIST` count equals its value before the call.

### Review Findings

Code review 2026-09-14, tier `full-opus`, all four layers (blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor). Rule 3: exempt, since the port has no user-facing surface until Story 2.5.

- [x] [Review][Patch] `[medium]` A read type the endpoint leaves to the vendor base class answered 200 `{}`, and QA's test pinned it. This contradicts the story's so-that and AD-2's *Prevents*. `EndpointType` now refuses it 501 `PORT.NOTIMPLEMENTED` through `ImplementsRead`, and the test asserts the refusal. [src/OcuPilot/Port/AdminPort.cls:383]
- [x] [Review][Patch] `[medium]` The session stub's `Username = $USERNAME` had no pin: an empty stub kept every async assertion green. `EndpointFixture` now records it at `Run()`, and `TestTheVendorStepsRunInMainsOrder` asserts it. [src/OcuPilot/Test/AdminPortFault.cls:67]
- [x] [Review][Patch] `[low]` `Fail` discarded `Outcome`'s `%Status`; the status is now logged. [src/OcuPilot/Port/AdminPort.cls:576]
- [x] [Review][Patch] `[low]` The timeout test had no upper bound; it now asserts under 10 s. [src/OcuPilot/Test/AdminPortFault.cls:244]
- [x] [Review][Patch] `[low]` The timeout and refused-poll logs did not name the task GUID; both do now, and both tests assert it. [src/OcuPilot/Port/AdminPort.cls:563]
- [x] [Review][Patch] `[low]` The `AdminPortFault` header did not state the resource it needs; it does now. [src/OcuPilot/Test/AdminPortFault.cls:7]
- [x] [Review][Patch] `[low]` The hook-trigger pin could match outside the pathspec and the `if` block; it is now bounded to both. [ui/tools/ci.test.mjs:1464]
- [x] [Review][Patch] `[low]` The hook comment named only two scanned trees; it now names three. [.githooks/pre-commit:73]
- [x] [Review][Patch] `[low]` `RunSequence`'s doc said the 2xx raise matches `Main()`; it now states the difference. [src/OcuPilot/Port/AdminPort.cls:413]
- [x] [Review][Patch] `[low]` `TaskCount` accepted a non-array answer; it now returns -1 for one. [src/OcuPilot/Test/AdminPortAsync.cls:35]
- [x] [Review][Patch] `[low]` The ApiVersion 2 pin had no `mutation:` line; one is recorded under Verification.
- [x] [Review][Defer] `ImplementsRead` trusts any class that overrides `Run`, so 14 such endpoints can still answer an unbuilt GET or LIST with `{}`. [src/OcuPilot/Port/AdminPort.cls:393] — deferred: DW-251 `wontfix-accepted`, `reopen_if` in the ledger.
- [x] [Review][Defer] `Sequence` calls OcuPilot seams while in `%SYS`, where OcuPilot is not mapped. [src/OcuPilot/Port/AdminPort.cls:447] — deferred: DW-252 `wontfix-theoretical`. It would become real if a call in `%SYS` reached a class the process had not loaded.

Rejected:
- `[low]` The outer `Catch` in `Invoke` and `ForgetTask`'s failure log are untested. They are safety nets, and no AC rests on them.
- `[low]` A refused poll's 404 reads `not_found`. The prior pass pinned this deliberately; it is reachable only if another process deletes the row.
- `[low]` Captured console lines are discarded. The spec requires only that nothing reaches the caller; logging them needs plumbing through three frames.
- `[low]` The poll loop costs a full sequence per poll. Probed tasks finish within 28 ms.
- `[false]` Containment misses `ui/tools/ci-runner.mjs`. That file names no `%Api.Admin`, and the intent names `scripts/*.sh`.
- `[low]` A shell-only commit also runs the client checkers. The cost is seconds.
- `[low]` `HTTPFORBIDDEN`/`HTTPBADREQUEST` repeat `%CSP.REST` literals. Cosmetic.
- `[low]` A `Canceled`/`Paused` task, an error after `AddToAsyncQueue`, `TaskCount` at 1000 rows, and the 406/415 steps. All four were rejected in the prior pass, and these reports add no new angle.
- `[false]` A poll refused under the `%Admin_Secure`/`%Admin_Operate` split, and a nested capture. These duplicate DW-249 and DW-250.
- `[low]` `Failed` and unmapped 401/405/415/423 collapse to `INTERNAL`. Both follow from the spec's mapping.
- `[false]` A 2xx poll with no answer object logs nothing. `AsyncResult` `RunGet` always returns an object.
- `[false]` A heredoc `#dim` line, an unreadable script, and a nested `scripts/**/*.sh`. None exists, and `#` directives do not run in `iris session`.
- `[low]` The malformed-name assertion cannot fail for the `$Match` guard. Rejected in the prior pass; no AC rests on the guard.
- `[false]` `asyncAtRun` 0 cannot fail. The AC3 mutation (`IsRunningAsync = 1`) is observed red.
- `[low]` A vendor-gate 403 does not name a privilege. AD-8's naming governs the descriptor gate (Story 2.3), and an OR list has no single failing pair.

## Spec Change Log

- 2026-09-14, lead (owner-delegated decision on the plan's intent gap): all three recommended amendments accepted and written into the spine (AD-2 corrected to `Main()`'s order, `%request.Data` seeding, `%session` stub, `%SYS`; AD-26 async is one path with two entries converging on one `AsyncResult` poll, a bounded wait failing `PORT.TIMEOUT`) and into epics.md Story 2.1 AC2, AC4 and AC6 and Story 2.2's inventory wording. Re-plan against the amended text.

## Review Triage Log

### 2026-09-14 — Review pass
- verdicts: 64 findings — high 0, medium 8, low 36, false 15, maybe-false 5
- findings:
  - `[medium]` `[patch]` Blind: the pre-commit hook does not run the checker when only `scripts/*.sh` is staged — `'scripts/*.sh'` added to `OS_TRIGGER`, pinned in `ci.test.mjs`.
  - `[low]` `[patch]` Blind: `ForgetTask`'s doc says nobody else can read the row, but `AsyncResult` `LIST` returns it — doc and the Design Notes sentence corrected.
  - `[false]` `[reject]` Blind: a hand-off `Finished` hides an endpoint's 404 — the one reachable hand-off, `SysCRUD` `INFO`, sets its 404 in `ValidateSemantics`, which runs synchronously; `RunInfo`'s `{}` is identical sync and async.
  - `[low]` `[reject]` Blind: `Failed` is always 500 `INTERNAL` — spec-bound ("`Failed` is a 500").
  - `[false]` `[reject]` Blind: the row cap is lost on the hand-off path — no hand-off serves a LIST (live `ShouldRunAsync` overrides: `INFO`, `MAPPINGS`, `INTEROP`, actions only).
  - `[low]` `[patch]` Blind: suffix check weaker than its doc, since every endpoint inherits `TYPEGET`/`TYPELIST` — `Invoke`'s doc now states what is refused; residual recorded below.
  - `[low]` `[reject]` Blind: `AcceptsContentType` and `NeedsRequestBody` steps omitted — reads only, no HTTP content negotiation in-process; not in the intent's step list.
  - `[low]` `[patch]` Blind: `Outcome` can return with `pFault` unset — `pFault` defaults to the internal fault before the `Try`.
  - `[low]` `[reject]` Blind: HTTP status and slug can disagree (400 → `validation_failed`) — spec-bound mapping.
  - `[low]` `[patch]` Blind: a failed poll under a 2xx reports HTTP 200 — raised to 500.
  - `[low]` `[patch]` Blind: dead midnight-wrap in `AwaitTask` (`$ZHOROLOG` counts from startup) — deleted.
  - `[maybe-false]` `[defer]` Blind: a refused poll leaves the queued row — see the grouped deferred item.
  - `[low]` `[reject]` Blind: port-decided refusals log nothing — no vendor text exists to log; rare paths.
  - `[low]` `[patch]` Blind: a throwing `VerifyInstance` is logged twice — `ElseIf`.
  - `[low]` `[reject]` Blind: `$Get(%objlasterror)` may be stale — no endpoint `%OnNew` fails (live: only the base overrides it).
  - `[medium]` `[patch]` Blind: the port's 400 paths have no test — `queryinvalid`/`requestinvalid` fixture modes and two `AdminPortFault` tests.
  - `[medium]` `[patch]` Blind: `Fault.Outcome` has no test — `TestOutcomeMapsTheHttpStatusFirstThenFallsBackToNormalize`.
  - `[low]` `[patch]` Blind: `AdminPortSync` kills the process's CSP objects — `New` in the test method, `Kill` removed.
  - `[low]` `[reject]` Blind: `TaskCount` misses a leak past 1000 rows or under same-user activity — unlikely on a test instance.
  - `[false]` `[reject]` Blind: `RunInfo`'s `FileCompact(dir, 0)` mutates the database — `SYS.Database` doc: a `TargetFree` of 0 moves no blocks.
  - `[low]` `[patch]` Blind: `AdminPortFault` header overstates what vendor code runs — corrected.
  - `[low]` `[patch]` Blind: `PortFixture` records unread `logCalls` — removed.
  - `[low]` `[patch]` Blind: `PORTACCESSDENIED` doc names `Normalize` as sole producer — corrected.
  - `[low]` `[reject]` Blind: checker summary does not count shell scripts — the shipped-tree harness test asserts a non-zero shell population.
  - `[false]` `[reject]` Blind: Auto Run Result not updated — finalize writes it.
  - `[low]` `[reject]` Blind: matrix probe wording differs from the observed mutation — fix edits the intent block.
  - `[false]` `[reject]` Blind: lines added to an oversized spec — Rule 19 requires the mutation lines.
  - `[low]` `[patch]` Edge: GET/LIST on an endpoint implementing neither reads 200 `{}` — same entry as the suffix-check row.
  - `[low]` `[reject]` Edge: `Canceled`/`Paused` states poll to `PORT.TIMEOUT` — needs a cancel within the bound; the result is a fault, not a false success.
  - `[maybe-false]` `[defer]` Edge: a caller holding `%Admin_Secure` but not `%Admin_Operate` queues an audit task, then its poll is refused — grouped deferred item.
  - `[low]` `[reject]` Edge: an error after `AddToAsyncQueue` orphans the row — theoretical (`SaveRequestBody` of `{}`).
  - `[low]` `[reject]` Edge: a 202 without an `async-result` location — `AddToAsyncQueue` always sets it.
  - `[maybe-false]` `[defer]` Edge: `Invoke` under an active `%SYS.Capture` with output fails — grouped deferred item.
  - `[low]` `[patch]` Edge: `Outcome` leaves `pFault` unset — same entry as the Blind row.
  - `[low]` `[reject]` Edge: a heredoc line starting with `#` escapes containment — no such ObjectScript line is valid in `iris session`.
  - `[medium]` `[patch]` Edge: pre-commit clause of the first AC — same entry as the Blind row.
  - `[maybe-false]` `[defer]` Edge: the third AC fails for a poll-refused caller — grouped deferred item.
  - `[low]` `[reject]` Edge: `Main()` passes `{}` for bodiless types where the port passes `pBody` — reads only; no caller passes a body.
  - `[medium]` `[patch]` Gap: `Outcome` 409/400/422 and fallback untested — same entry as the Blind row.
  - `[medium]` `[patch]` Gap: the port's own 400 paths untested — same entry as the Blind row.
  - `[medium]` `[patch]` Gap: `AwaitTask`'s poll-failure branch untested — `SetCannedPollRefusal` seam and `TestARefusedPollIsItsOwnFailure`.
  - `[medium]` `[patch]` Gap: pre-commit trigger — same entry as the Blind row.
  - `[low]` `[reject]` Gap: the malformed-name assertion cannot fail for the `$Match` guard — the refusal outcome it asserts holds; no AC rests on the guard.
  - `[low]` `[patch]` Gap: no `mutation:` lines for vendor-text-only-in-log, `Failed` → failure and the class existence check — applied, observed red, recorded.
  - `[maybe-false]` `[defer]` Gap: capture already active — grouped with the Edge row.
  - `[low]` `[reject]` Intent: 406/415 steps omitted — same as the Blind row.
  - `[false]` `[reject]` Intent: construction precedes the `%SYS` switch — no vendor endpoint overrides `%OnNew` (live dictionary), so construction has no namespace-dependent effect.
  - `[false]` `[reject]` Intent: `New` sits in `RunSequence`, not `Invoke` — that frame invokes the vendor sequence, per poll.
  - `[false]` `[reject]` Intent: `Sequence`'s catches do not restore the namespace — it never switches; `RunSequence` restores.
  - `[false]` `[reject]` Intent: the failed-probe wire reason is generic — it names the probe failure; the detail is logged.
  - `[false]` `[reject]` Intent: `ForgetTask` deletes vendor rows — decided in Design Notes.
  - `[false]` `[reject]` Intent: `docker-compose.yml` and `.githooks` not scanned — the intent names `scripts/*.sh`.
  - `[low]` `[reject]` Intent: audit LIST asserts `<= 1` — the cap mutation still goes red with two or more audit records.
  - `[false]` `[reject]` Intent: `Name` recorded before capture, not at `Run` — nothing writes `Name` in between.
  - `[false]` `[reject]` Intent: caller-untouched covers one success and one failure — the matrix row asks for exactly that.
  - `[low]` `[reject]` Intent: step order observed through the fixture only — real-endpoint rows pin the vendor behaviour.
  - `[low]` `[reject]` Intent: the production `HoldsResource` is never seen denying — spec-acknowledged; Story 2.5.
  - `[low]` `[reject]` Intent: `Failed`/timeout via the fixture only — both entries share `AwaitTask`.
  - `[low]` `[patch]` Intent: no mutation line for the `%SYS` switch — applied, observed red, recorded.
  - `[low]` `[reject]` Intent: restore-first in `Catch` untested — the catch is unreachable from a vendor throw, which `Sequence` catches first.
  - `[false]` `[reject]` Intent: no test for AD-8's no-cache rule — version-one refusal runs after verified calls in the same process and goes green.
  - `[low]` `[reject]` Intent: "no caller names a vendor type number" is unenforced — no caller exists yet.
  - `[low]` `[patch]` Intent: `Invoke`'s outer `Catch` returns the raw exception status — now returns the fault's own text; the exception goes to the log.
  - `[false]` `[reject]` Intent: spec status line stale — finalize writes it.

## Design Notes

**Governing ADs:**
- AD-1: in-process.
- AD-2: the sequence.
- AD-8: no cache.
- AD-9: never called from an escalated frame.
- AD-12 and AD-39: vendor text normalized at the port.
- AD-16: `%SYS` by save and restore.
- AD-26: one async path, two entries, one poll.
- AD-27: containment and verification.
- AD-29: `ResourcesOR` is inherited.
- AD-36: the row cap reaches the query.
- Conventions: *Status handling*, *Tests*, *ObjectScript naming*.

**Gate before query parameters,** as `Main()` does. All 63 `ResourcesOR()` definitions are constants or branch on `Type` alone (scanned live), so a refused caller reads 403, never 400.

**`%SYS` and the session stub.** In `HSCUSTOM`, `WebApp.App` GET throws `<CLASS DOES NOT EXIST> Security.Applications` (probed). `AsyncResult` returns 404 when the poll's session user differs, and the turn job (AD-7) has no `%session`.

**`%All` cannot test the gate.** Under `%All`, `$System.Security.Check` returns 1 even for a nonexistent resource (probed). The refusal row therefore uses `HoldsResource`, and Story 2.5 observes a real denied principal.

**The port deletes a finished task.** Only the port knows which GUID the call queued, though `AsyncResult` `LIST` shows every row the user owns. No scheduled purge was found. Without the delete, each audit search leaves a row, and a shared-instance test could only clean up by naming the vendor class. A timed-out row stays, because its worker still owns it. The delete removes only the row the same call queued, so the net state is unchanged and it is not a mutating vendor call.

**"Exactly two Release 1 async paths"** is an inventory fact that Story 2.2's fixture pins. This story pins one call per entry.

**Integration ACs.** No consumers in this story; the first consumer will be Story 2.3 (shared read); Story 2.5 is the first HTTP consumer. The containment check's consumer is CI's `gates` job (first AC).

**Consumes:** `VerifyInstance` (Story 1.8), `Kernel.Fault`, `Api.Error` codes.

**Consumed-by:**
- `2-3-one-descriptor-declared-read-serves-both-the-screen-and-its`: every admin-backed read.
- `2-5` through `2-9`: their lists.
- `2-10-the-audit-database-viewer-with-its-agent-marker-filter`: the self-queued path.
- `2-2`: the inventory, with both async entries.

**Declined DW-60:** `GateStatus()` measured 0.072 ms per call (500 live calls as `_SYSTEM`), against NFR-1's 2 s. A terminal-phase cache in long-lived CSP processes would miss another process's `installing` mark (AD-38). `Version` holds one row per profile, so an index buys nothing.

## Verification

**Shared runtime.** Every class runs on the shared instance and in CI's `instance` job, and cleans up after itself.
- No web application, user, role, resource or Task Manager task is created.
- `AdminPortAsync` queues two vendor task rows. The port deletes both, and the class asserts the count is unchanged.
- The `Failed` and timeout rows queue nothing.

Compile through `iris_doc_load` and `iris_doc_compile` on `ocupilot-iris`. Send one class per `iris_execute_tests` call, and send the next only after the run lands in `%UnitTest_Result`.

**Commands:**
- `uv run scripts/check-objectscript.py && uv run scripts/test_check_objectscript.py`. Expected: exit 0, with `TestAdminApiContainment` green.
- `iris_execute_tests` on `OcuPilot.Test.AdminPortSync`, `AdminPortFault`, `AdminPortAsync`, `Instance` and `Fault`, one at a time. Expected: green in the `%UnitTest_Result` probe.
- `cd ui && node --test tools/ci.test.mjs`. Expected: green.
- `bash scripts/lint-docs.sh`. Expected: 0 issues.

**Planned mutations (Rule 19), each recorded as a `mutation:` line when its pin lands:**

| Row | Mutation | Test that goes red |
| --- | --- | --- |
| AC1 | Drop `check_admin_api_containment` from `CHECKS` | planted class |
| AC1 | Drop the `*.sh` scan | shell line |
| AC3 | Set `IsRunningAsync = 1` | absent web app |
| AC4 | Remove `ValidateQueryParams()` | identifier |
| Row cap | Seed with `SaveOneQueryParam` only | row cap (45 rows) |
| AC5 | Judge success on `tSC` alone | non-2xx |
| Gate | Skip `HoldsResource` | refusal |
| `<PROTECT>` | Drop its mapping | `<PROTECT>` |
| Capture | Remove it | device output |
| Stubs | Remove `New %response` | caller untouched |
| AC7 | Skip `VerifyInstance` | unverified |
| AC6 | Return the 202 unpolled | `INFO` and `LIST` |
| AC6 | Poll only when `ShouldRunAsync()` | `LIST` |
| AC6 | Leave `/api/admin` out of the stub URL | `TaskName` |
| AC6 | Return the last answer at the bound | timeout |
| Cleanup | Skip `ForgetTask` | the count |

**Observed mutations** (each applied, observed red, reverted; `cmp` byte-identical after revert):
- mutation: `check_admin_api_containment` dropped from `CHECKS` → `TestAdminApiContainment.test_a_planted_reference_in_a_test_class_is_refused_through_the_checker_run` red.
- mutation: the `iter_shell_scripts()` loop iterates `[]` → `test_a_planted_reference_on_a_shell_code_line_is_refused` red.
- mutation: containment reads `iter_code_lines` (XData skipped) → `test_a_planted_reference_in_an_xdata_body_is_refused` red.
- mutation: `iter_shell_code_lines` stops exempting `#` lines → `test_a_doc_comment_a_shell_comment_and_the_port_itself_pass` and `TestShippedTreeAdminApiContainment` red.
- mutation: `ci-image-compile.sh` reads `HighestDispatchVersion("%Api.Admin")` again → `ci.test.mjs` "ci-image-compile.sh's verdict arms" red.
- mutation: `IsRunningAsync = 1` → `AdminPortSync.TestAnAbsentWebApplicationFailsNotFound` red (500, not 404).
- mutation: `ValidateQueryParams()` skipped → `AdminPortSync.TestTheIdentifierReachesTheEndpointBeforeRun` and `TestTheCallersCspObjectsAndNamespaceAreUntouched` red (`PORT.NOTFOUND`).
- mutation: query seeded by `SaveOneQueryParam` only → `AdminPortSync.TestTheRowCapReachesTheQuery` red (45 returned).
- mutation: `New %response` removed → `AdminPortSync.TestTheCallersCspObjectsAndNamespaceAreUntouched` red.
- mutation: `ValidateSemantics()` moved before `ValidateRequest()` → `AdminPortFault.TestTheVendorStepsRunInMainsOrder` red.
- mutation: gate forced to `tAllowed = 1` → `AdminPortFault.TestACallerHoldingNoListedResourceIsRefused` red.
- mutation: success judged on the sequence status alone → `AdminPortFault.TestANon2xxStatusUnderAnOkStatusIsAFailure` red.
- mutation: error-under-2xx raise to 500 deleted → `AdminPortFault.TestAnErrorStatusUnder2xxIsA500` red.
- mutation: `<PROTECT>` 403 mapping deleted → `AdminPortFault.TestAProtectFromRunIsA403` red.
- mutation: `BeginCaptureOutput` call deleted → `AdminPortFault.TestDeviceOutputNeverReachesTheCaller` red.
- mutation: verification branch replaced by `If 0` → `AdminPortFault.TestAnApiAtVersionOneIsRefusedBeforeConstruction` and `TestAFailedProbeIsRefusedBeforeConstruction` red.
- mutation: `TYPESUFFIXES` check deleted → `AdminPortFault.TestAnUnknownEndpointOrSuffixIsRefusedBeforeConstruction` red.
- mutation: bound returns the last answer as a 200 → `AdminPortFault.TestATaskStillRunningAtTheBoundTimesOut` red.
- mutation: both `ForgetTask` calls deleted → `AdminPortFault.TestAFailedTaskIsA500AndIsForgotten`, `TestAFinishedTaskReturnsItsResultAndIsForgotten` and both `AdminPortAsync` count assertions red (leaked rows deleted by hand).
- mutation: 202 poll branch replaced by `If 0` → both `AdminPortAsync` tests red (leaked rows deleted by hand).
- mutation: poll only after the `ShouldRunAsync()` branch → `AdminPortAsync.TestTheSelfQueuedAuditListIsPolledToAnOrdinarySuccess` red, `INFO` green (leaked row deleted by hand).
- mutation: `STUBURLPREFIX` without `/api/admin` → both `AdminPortAsync` `TaskName` assertions red (`GET `).
- mutation: `'scripts/*.sh'` dropped from the hook's `OS_TRIGGER` → `ci.test.mjs` "the pre-commit hook runs the ObjectScript checker when only a CI shell script is staged" red.
- mutation: `Set $NAMESPACE = "%SYS"` removed from `RunSequence` → all four `AdminPortSync` tests red (`INTERNAL`).
- mutation: `Outcome`'s 409 row deleted and its `Normalize` fallback replaced by `INTERNAL` → `Fault.TestOutcomeMapsTheHttpStatusFirstThenFallsBackToNormalize` red on the 409 row and both 500 rows.
- The next six were applied together in one run and each attributed by its own assertion message:
  - mutation: the 400 in the `ValidateQueryParams` catch deleted → `AdminPortFault.TestAQueryParameterThrowIsA400` red (HTTP status, slug, code).
  - mutation: the 400 in the `ValidateRequest` branch deleted → `TestARequestValidationErrorIsA400` red.
  - mutation: `AwaitTask`'s poll-failure branch deleted → `TestARefusedPollIsItsOwnFailure` red.
  - mutation: `Fail` returns the vendor status → `TestAnErrorStatusUnder2xxIsA500` red ("nor the returned status").
  - mutation: `Failed` handled as `Finished` → `TestAFailedTaskIsA500AndIsForgotten` red.
  - mutation: `EndpointClass`'s `%ExistsId` check deleted → `TestAnUnknownEndpointOrSuffixIsRefusedBeforeConstruction` red (unknown class).

**QA independent reproduction (this pass).** The four medium fixes written after the review layers ran (Auto Run Result's stated risk) had not been read by an independent layer; QA re-applied each named mutation, observed the same red, reverted, recompiled the restored class, and reran the class to green:
- mutation: `'scripts/*.sh'` dropped from `OS_TRIGGER` → `ci.test.mjs`'s hook-trigger test red; reverted, `node --test tools/ci.test.mjs` 51/51.
- mutation: `Outcome`'s 409 row deleted and its `Normalize` fallback replaced by the internal default → `Fault.TestOutcomeMapsTheHttpStatusFirstThenFallsBackToNormalize` red on the 409 row and both 500 rows; reverted, `OcuPilot.Test.Fault` 6/6.
- mutation: the 400 in the `ValidateQueryParams` catch and in the `ValidateRequest` branch both deleted, together with `AwaitTask`'s poll-failure branch → `AdminPortFault.TestAQueryParameterThrowIsA400`, `TestARequestValidationErrorIsA400` and `TestARefusedPollIsItsOwnFailure` red, the other 12 methods unaffected; reverted, `OcuPilot.Test.AdminPortFault` 15/15.
- mutation: `IsRunningAsync = 1` (the AC3 row, re-checked as the one real-runtime 404 pin) → `AdminPortSync.TestAnAbsentWebApplicationFailsNotFound` red, the other 4 methods (including the new row below) unaffected; reverted, `OcuPilot.Test.AdminPortSync` 5/5.

Each revert was confirmed byte-identical (`git status --short` / `git diff --stat` empty) before the affected class was recompiled on `ocupilot-iris`.

**Code review (2026-09-14).** Each mutation was applied, observed red and reverted (`cmp` byte-identical, recompiled); after the reverts, `AdminPortSync` 5/5, `AdminPortFault` 15/15, `AdminPortAsync` 2/2 and `Instance` 21/21 passed (runs 1299–1304):
- mutation: `ImplementsRead` check deleted from `EndpointType` → `AdminPortSync.TestAnUnimplementedReadTypeIsRefused` red.
- The next three were applied together, each attributed by its own assertion message:
  - mutation: session stub `{"Username": ""}` → `AdminPortFault.TestTheVendorStepsRunInMainsOrder` red ("the session stub names the calling user").
  - mutation: endpoint constructed at version 1 → `TestTheVendorStepsRunInMainsOrder` red ("constructed at ApiVersion 2").
  - mutation: `AwaitTask` bound reads `ASYNCTIMEOUT` instead of `AsyncTimeout()` → `TestATaskStillRunningAtTheBoundTimesOut` red (30.01 s).

## Auto Run Result

Status: done
Blocking condition: none

This pass implemented and reviewed the story. `AdminPort.Invoke` runs `Main()`'s steps in `%SYS` behind `New`ed stubs, polls either async entry to a terminal state, deletes the finished row, and returns faults through `Kernel.Fault.Outcome`. The containment check now reads `scripts/*.sh`, and the pre-commit hook fires on them.

Files changed:
- `src/OcuPilot/Port/AdminPort.cls`: `Invoke` and its seams.
- `src/OcuPilot/Kernel/Fault.cls`: `Outcome`, `Build`, and `Classify` shared with `Normalize`.
- `src/OcuPilot/Api/Error.cls`: `PORT.UNAVAILABLE` and `PORT.TIMEOUT`.
- `scripts/check-objectscript.py`, `scripts/test_check_objectscript.py`: shell-script containment and its harness cases.
- `scripts/ci-image-compile.sh`, `ui/tools/ci.test.mjs`: literals routed through `AdminApiClass()`; the hook-trigger pin.
- `.githooks/pre-commit`: `scripts/*.sh` in `OS_TRIGGER`.
- `src/OcuPilot/Test/`: `AdminPortSync`, `AdminPortFault`, `AdminPortAsync`, `EndpointFixture` (new); `PortFixture` and `Fault` extended.

Deviations from the Tasks, kept after review: `PollTask` returns the poll's HTTP status; `LogFault` is a seam; unknown names and suffixes are 501 `PORT.NOTIMPLEMENTED`; `UNAVAILABLE`/`TIMEOUT` use 503; the endpoint is constructed before the `%SYS` switch, since fixture classes do not resolve from `%SYS` and no vendor endpoint overrides `%OnNew`.

Review: 64 findings (medium 8, low 36, false 15, maybe-false 5, no high). Patched 16 entries (4 medium, 12 low). Deferred 2 grouped entries (medium, unverified). Rejections and their reasons are in the triage log. No `intent_gap` or `bad_spec`.

Follow-up review recommended: true. Patched: 4 medium, 12 low. Risk: the four medium patches (hook trigger, `Outcome` test, the two 400-path tests, and the refused-poll test with its `SetCannedPollRefusal` seam) were written by the lead after the review layers ran, so no independent layer has read them. The refused poll is pinned only through a canned refusal, never a real `%Admin_Operate` denial.

Verification:
- `check-objectscript.py`: 0 problems over 135 files. `test_check_objectscript.py`: 54 OK. `ci.test.mjs`: 51 pass. `lint-docs.sh`: 0 issues.
- Full ObjectScript suite, one class per call: 44 classes, 387/387 in the `%UnitTest_Result` latest-run probe (runs 1244–1287).
- Live instance left clean: 0 async task rows, and `ProbeApps.Existing()` is empty.
- Rule 19: every new or unlined pin has a recorded mutation, all reverted byte-identical.

Residual risks:
- `Invoke` refuses a read the endpoint leaves to the base class, but trusts a class that overrides `Run` (DW-251).
- Seam calls made from `%SYS` (`HoldsResource`, `OnBeforeRun`) rely on the class already being loaded in the process; shown on the instance, not documented.

DW-60 is still declined.
