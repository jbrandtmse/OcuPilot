---
title: 'Story 2.1: The AdminPort reproduces the vendor''s dispatcher, exactly once'
type: 'feature'
created: '2026-09-13'
status: 'ready-for-dev'
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

## Spec Change Log

- 2026-09-14, lead (owner-delegated decision on the plan's intent gap): all three recommended amendments accepted and written into the spine (AD-2 corrected to `Main()`'s order, `%request.Data` seeding, `%session` stub, `%SYS`; AD-26 async is one path with two entries converging on one `AsyncResult` poll, a bounded wait failing `PORT.TIMEOUT`) and into epics.md Story 2.1 AC2, AC4 and AC6 and Story 2.2's inventory wording. Re-plan against the amended text.

## Review Triage Log

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

**The port deletes a finished task.** The GUID never leaves the port, so nobody else can poll the row. No scheduled purge was found. Without the delete, each audit search leaves a row, and a shared-instance test could only clean up by naming the vendor class. A timed-out row stays, because its worker still owns it. The delete removes only the row the same call queued, so the net state is unchanged and it is not a mutating vendor call.

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

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

This pass re-planned the spec against the amended AD-2, AD-26 and epics.md AC6, with the intent block unchanged. The async rows are no longer blocked.

Live probes on `ocupilot-iris`:
- Both async entries answer 202 with an `async-result?id=` location, finish within 28 ms, and read back through `AsyncResult` GET.
- `%DeleteId` removes a task row. The probe rows were deleted, and the table reads 0.
- `%session` is read only as `Username`.
- No scheduled purge was found.

Plan changes:
- The session stub is a `%DynamicObject`; `AdminSession` is dropped.
- New seams: `PollTask`, `ForgetTask` and `AsyncTimeout`.
- The port deletes a task once it is terminal, and the third AC pins this. The unverified-instance AC is covered by the matrix's AC7 row.

DW-60 is still declined.
