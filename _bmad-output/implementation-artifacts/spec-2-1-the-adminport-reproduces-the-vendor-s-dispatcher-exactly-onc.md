---
title: 'Story 2.1: The AdminPort reproduces the vendor''s dispatcher, exactly once'
type: 'feature'
created: '2026-09-13'
status: 'draft'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
deferred: []
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

- `src/OcuPilot/Port/AdminPort.cls` holds the Story 1.8 surface: `AdminApiClass`/`ProbeEndpointClass` seams (`:40`, `:47`), `EndpointPackage` (`:55`) and `VerifyInstance` (`:142`). The class doc at `:4-8` says Epic 2 grows the sequence here.
- The vendor source is `[Hidden]`, so it is absent from `irissys/`. Read it with `iris_doc_get` in `%SYS` on `server: "ocupilot-iris"`. Never load it.
  - `%Api.Admin.Dispatch.v1` `Main` is the sequence. `Dispatch.v2` extends v1, so its `ApiVersion()` reads 2.
  - `%Api.Admin.Endpoint`: `%OnNew(type, apiVersion)`, `SaveQueryParams` (reads `%request.Data`), `SetRespStatus` guarded by `IsRunningAsync`, `GetName(request)` = `Method _ " " _ $Piece(URL, "api/admin", 2)`, and `NormalizeLocationHeader` (reads `%request.URL`).
  - `%Api.Admin.Util.AsyncTaskEndpoint.%OnNew(request, endpoint)` copies `request.Data`.
  - `%Api.Admin.Util.AsyncTask.AddToAsyncQueue` reads `%session.Username`. It sets `%response.Status` to 202 directly and sets the `Location` header `.../async-result?id=<GUID>`.
  - `%Api.Admin.Endpoints.AsyncResult` requires the `id` query parameter and `%Admin_Operate`. `ValidateSemantics` 404s when `task.Username '= %session.Username`, and `RunGet` returns `State`, `Result` and `FailureReason`.
  - `%Api.Admin.Util.ClassQuery.GetMaxRows` reads `%request.Data` directly.
- `src/OcuPilot/Kernel/Fault.cls`: `Normalize` (`:46`) maps by message id and `LogRaw` (`:114`) logs the raw text. Its doc at `:17-21` says the port call site does not exist yet.
- `src/OcuPilot/Api/Error.cls:155-176` declares the five `PORT.*` codes. `UNAVAILABLE` is the slug at `:54`.
- `src/OcuPilot/Test/PortFixture.cls` holds the `^||OcuPilotPortFixture` seam overrides with a `##super()` fallback. `Test/ProbeFixture.cls` is the duck-typed endpoint precedent, extending no vendor class. `Test/Instance.cls` pins `VerifyInstance`, and `Test/Fault.cls` pins `Normalize`.
- `scripts/check-objectscript.py:573-631`: `ADMIN_API_ALLOWED`, `ADMIN_API_RE` and `check_admin_api_containment` scan non-comment lines of ObjectScript under `SCAN_ROOTS`. `scripts/test_check_objectscript.py` has no case for this rule. `FixtureTreeCase` (`:44`) is the pattern to follow.
- `scripts/ci-image-compile.sh:109-111` names `"%Api.Admin"` twice in embedded ObjectScript. `ui/tools/ci.test.mjs:1444-1453` pins that literal.
- `ui/tools/ci-runner.mjs` discovers every `.cls` under `src/OcuPilot/Test/`, so new test classes run in CI's `instance` job with no registration.

## Tasks & Acceptance

**Execution:**
- `src/OcuPilot/Port/AdminPort.cls`: add `Invoke(pEndpoint, pType, ByRef pQuery, pBody, Output pResult, Output pHttpStatus, Output pFault) As %Status`, with these overridable seams:
  - `EndpointClass(pEndpoint)`, which validates the shape and that the compiled class exists.
  - `HoldsResource(pResource)`, over `$System.Security.Check`.
  - `OnBeforeRun(pEndpoint)`, a no-op.
  - `AwaitAsync`, which polls `AsyncResult` GET through the same synchronous sequence against a `Parameter ASYNCTIMEOUT` bound.
  - Rewrite the class doc to describe the contract.
- `src/OcuPilot/Port/AdminSession.cls` (new): the `%RegisteredObject` session stub, with a `Username` property.
- `src/OcuPilot/Kernel/Fault.cls`: add HTTP-status-first normalization.
  - 403 maps to `PORT.ACCESSDENIED`, 404 to `PORT.NOTFOUND`, 409 to `PORT.CONFLICT`, and 400 or 422 to `PORT.VALIDATION`.
  - Otherwise use `Normalize(tSC)`.
  - Replace the "no port call site yet" paragraph.
- `src/OcuPilot/Api/Error.cls`: declare `PORTUNAVAILABLE = "PORT.UNAVAILABLE"` and `PORTTIMEOUT = "PORT.TIMEOUT"`, both on the `unavailable` slug.
- `src/OcuPilot/Test/PortFixture.cls`: add endpoint-class, `HoldsResource` and `OnBeforeRun` overrides. The `OnBeforeRun` override records `$Property(endpoint, "Name")`.
- `src/OcuPilot/Test/EndpointFixture.cls` (new): a duck-typed endpoint whose modes set 404 with an OK `tSC`, return an error `tSC`, throw `<PROTECT>`, or write to the device.
- `scripts/check-objectscript.py`: extend the containment rule to the non-`#` lines of `ROOT/scripts/*.sh`. `scripts/ci-image-compile.sh`: replace both literals with `##class(OcuPilot.Port.AdminPort).AdminApiClass()`. `ui/tools/ci.test.mjs`: update the `:1447` pin to match.
- Tests, each with a `mutation:` line in `## Verification`:
  - `scripts/test_check_objectscript.py` `TestAdminApiContainment`: a planted reference in a `Test/` class, in an XData body, and on a `scripts/x.sh` code line each yields a problem naming the file. A doc comment, a `#` line and `AdminPort.cls` yield none.
  - `src/OcuPilot/Test/AdminPortSync.cls`: the absent web app, identifier, row cap, caller-untouched and namespace rows, against the real `WebApp.App`.
  - `src/OcuPilot/Test/AdminPortFault.cls`: the gate, non-2xx, error-under-2xx, `<PROTECT>`, device-output and unverified-instance rows, through `PortFixture` and `EndpointFixture`.
  - `src/OcuPilot/Test/AdminPortAsync.cls`: the `ShouldRunAsync` row. The audit LIST row waits on the amendment.

**Acceptance Criteria:**
- Given a class, an XData body or a CI script other than `AdminPort.cls` that names `%Api.Admin` in code, when `uv run scripts/check-objectscript.py` runs locally, in the pre-commit hook or in CI's `gates` job, then it exits 1 naming the file and line. On the shipped tree it reports no containment problem over a non-zero file count.
- Given any endpoint invoked through `AdminPort.Invoke`, when it runs, then the vendor steps execute in `Main()`'s order and every matrix row holds.
- Given an instance whose admin API does not report v2, or whose probe fails, when anything invokes the port, then it refuses with `PORT.UNAVAILABLE` before constructing an endpoint.

## Spec Change Log

- 2026-09-14, lead (owner-delegated decision on the plan's intent gap): all three recommended amendments accepted and written into the spine (AD-2 corrected to `Main()`'s order, `%request.Data` seeding, `%session` stub, `%SYS`; AD-26 async is one path with two entries converging on one `AsyncResult` poll, a bounded wait failing `PORT.TIMEOUT`) and into epics.md Story 2.1 AC2, AC4 and AC6 and Story 2.2's inventory wording. Re-plan against the amended text.

## Review Triage Log

## Design Notes

**Governing ADs:**
- AD-1: in-process, no HTTP.
- AD-2: the sequence. See the amendment below.
- AD-8: no cache.
- AD-9: never called from an escalated frame.
- AD-12 and AD-39: one envelope, and vendor text normalized at the port.
- AD-16: `%SYS` by save and restore.
- AD-26: the async paths. See the amendment below.
- AD-27: containment and verification.
- AD-29: the port inherits `ResourcesOR`.
- AD-36: the row cap reaches the query.
- Conventions: *Status handling*, *Tests* and *ObjectScript naming*.

**Why gate before query parameters.** `Main()` does. Every one of the 63 `ResourcesOR()` definitions in the endpoint package is a constant or branches on `Type` alone (scanned live). So the order changes no resource set. It keeps endpoint code from running for a caller the gate would refuse, and a refused caller with a missing parameter reads 403, never 400.

**Why `%SYS`, and why a session stub.** In `HSCUSTOM`, `WebApp.App` GET throws `<CLASS DOES NOT EXIST> Security.Applications` (probed). `AddToAsyncQueue` stamps `%session.Username`, and `AsyncResult` 404s a poll whose session user differs. The turn job (AD-7) has no `%session` at all.

**Why `%All` cannot test the gate.** `$System.Security.Check` returns 1 for a nonexistent resource under `%All` (probed), so the refusal row goes through the `HoldsResource` seam. Story 2.5's HTTP test observes a real denied principal.

**Integration ACs.** `Invoke` has no production consumer in this story. The first is Story 2.3's shared read, and the first HTTP consumer is Story 2.5. The containment check's consumer is CI's `gates` job (the first AC).

**Consumes:** `VerifyInstance` (Story 1.8), `Kernel.Fault` and the `Api.Error` codes.

**Consumed-by:**
- `2-3-one-descriptor-declared-read-serves-both-the-screen-and-its` resolves every admin-backed read through `Invoke`.
- `2-5` through `2-9` build their lists on it.
- `2-10-the-audit-database-viewer-with-its-agent-marker-filter` uses the async path.
- `2-2` re-derives the inventory beside `EndpointPackage`.

**Declined DW-60:** `GateStatus()` measured 0.072 ms per call (500 calls, live, as `_SYSTEM`) against NFR-1's 2 s. A terminal-phase cache in long-lived CSP processes would miss the `installing` mark another process writes (AD-38). `Version` holds one row per profile, so an index buys nothing.

## Verification

**Shared runtime.** Every instance test is a read. No web application, user, role, resource or task is created. Async calls leave vendor `AsyncTask` rows, which the vendor's `PurgeAsyncQueue` removes (inference). Compile through `iris_doc_load` and `iris_doc_compile` on `ocupilot-iris`. Run one test class per `iris_execute_tests` call, and start the next only after the run has landed in `%UnitTest_Result`.

**Commands:**
- `uv run scripts/check-objectscript.py && uv run scripts/test_check_objectscript.py` -- expected: exit 0, and `TestAdminApiContainment` green.
- `iris_execute_tests` for `OcuPilot.Test.AdminPortSync`, `AdminPortFault`, `AdminPortAsync`, `Instance` and `Fault`, one at a time -- expected: all green in the `%UnitTest_Result` probe.
- `cd ui && node --test tools/ci.test.mjs` -- expected: green.
- `bash scripts/lint-docs.sh` -- expected: 0 issues.

**Planned mutations (Rule 19). Record each `mutation:` line as its pin lands:**
- AC1: `check_admin_api_containment` is removed from `CHECKS`, making the planted-class test red. The `scripts/*.sh` scan is dropped, making the shell test red.
- AC3: the port sets `IsRunningAsync = 1`, making the absent-web-app test red because the call reads as a success.
- AC4: the `ValidateQueryParams()` call is removed, making the identifier test red.
- Row cap: seeding goes through `SaveOneQueryParam` only, making the row-cap test red with 45 rows instead of 2.
- AC5: success is judged on `tSC` alone, making the non-2xx test red.
- Gate: `HoldsResource` is skipped, making the refusal test red. `<PROTECT>` mapping is dropped, making that test red. Capture is removed, making the device-output test red. `New %response` is removed, making the caller-untouched test red.
- AC7: `VerifyInstance` is skipped, making the unverified test red.
- AC6: `Invoke` returns the 202 without polling, making the `INFO` test red.

## Auto Run Result

Status: blocked
Blocking condition: intent gap: AC6 and AD-26 route the audit record LIST through the ShouldRunAsync() -> AsyncTaskEndpoint branch, but on the pinned instance ShouldRunAsync() is 0 for Security.Audit.Record LIST; that LIST queues its own task inside Run() and answers 202, so "exactly two Release 1 paths take this branch" is false and AD-26's "only these two paths exist" is incomplete

**Evidence (probed on `ocupilot-iris`, 2026-09-13).**
- On a constructed `Security.Audit.Record`, `ShouldRunAsync()` reads 0 at type 0 (LIST) and 1 at types 10 (COPY) and 11 (PURGE). Its source says: "The list endpoint also runs async, but it does its own logic to queue up a special async task".
- `RunList` builds `Security.Audit.RecordListTask`, which extends `%Api.Admin.Util.AsyncTaskList` rather than `AsyncTaskEndpoint`. It labels the task with `..GetName(%request)` and calls `AddToAsyncQueue()`, which sets 202 and an `async-result` `Location` itself.
- `Database.SysCRUD` reads `ShouldRunAsync()` 1 only at `TYPEINFO` (11), so the AC holds for the directory-info call.
- The three `GetName(%request)` classes all self-queue from `Run()`, never through `AsyncTaskEndpoint`: `Database.Actions` compact, defragment and integrity; `Journal.Record` LIST; `Security.Audit.Record` LIST. `Database.Actions.ShouldRunAsync` returns 0 for those types, commenting "they use their own logic for queuing special async tasks".
- The two readings differ observably. Forcing the LIST through `AsyncTaskEndpoint` runs `RunList` in a worker, which queues a second task. Honouring the vendor answer needs a second async entry the AC and AD-26 do not name.

**Recommended amendment. A lead decision is required, and the spine is edited in the same commit (Rule 20).**
1. AC6 (epics.md `:1765-1769`) should read: "Given an endpoint call the vendor answers asynchronously, either because `ShouldRunAsync()` is true for its request type (the port hands off through `%Api.Admin.Util.AsyncTaskEndpoint`) or because its `Run()` queues its own task and answers 202 with an `async-result` location, when the port runs it, then it polls the task through the `AsyncResult` endpoint and exposes the result as an ordinary call that resolves later, with no slice writing polling logic; and for the three classes that label their own task with `..GetName(%request)`, the port's stub request supplies a synthetic label; and exactly two Release 1 paths are asynchronous: the audit record LIST (self-queued) and the database directory info call (`ShouldRunAsync`)." AD-26's Rule should get the matching change: one synchronous path, and one async path with two entries converging on one poll. Story 2.10's `:2050` wording still holds. Story 2.2's inventory `async` column records only `ShouldRunAsync` overrides, so it misses self-queued classes such as `Journal.Record`.
2. AD-2 needs wording corrections in the same edit. These are apply-and-report candidates, and the matrix and Boundaries above already follow the vendor behaviour.
   - Step 4's gate precedes step 3's query parameters in `Main()`.
   - Step 3's `SaveOneQueryParam()` should be "seed `%request.Data`, then `SaveQueryParams()`". `ClassQuery.GetMaxRows` and `AsyncTaskEndpoint.%OnNew` read `%request.Data` directly. Probed: 45 rows came back instead of the 2 requested.
   - Step 2 should also stub `%session`, and the sequence runs in `%SYS` (AD-16).
   - AC4's "Invalid Application name" reads `ERROR #5813: Null oid, class 'Security.Applications'` on this build for GET. Its pinning assertion is unaffected.
3. "Resolves later" is planned as a bounded blocking wait that returns `PORT.TIMEOUT` rather than a partial result. Confirm this, or amend it in the same edit.

**Ledger inbox.** DW-60 is declined under Design Notes, with a measurement.
