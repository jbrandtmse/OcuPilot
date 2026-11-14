---
title: 'Story 21.1: The harvest seam'
type: 'feature'
created: '2026-11-14'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Epic 21 brings across the MCP suite's `ExecuteMCPv2.REST.*` handler bodies. Each one answers only through `..RenderResponseBody(tSC, , tResult)`, inherited from `%Atelier.REST`, which writes the vendor's `{status, console, result}` envelope to the device. OcuPilot has no class those bodies can inherit from, and no port that can run one.

**Approach:** Add an OcuPilot base class with the exact `RenderResponseBody` signature. It writes nothing: it records the one render on a stub response. Add one port, `HarvestPort`, that gates the call, runs a body behind stub CSP state, and turns the recorded render into OcuPilot's one envelope (AD-12, AD-39). Prove it with a fixture holding one current sibling body (`Task.TaskList`), changed only by its base class and the rename.

## Boundaries & Constraints

**Always:**

- `RenderResponseBody(pStatus As %Status, pMsgPart As %DynamicArray, pResPart As %DynamicObject) As %Status` is a class method with that exact signature. It reads omitted formals with `$Get`, writes nothing to the device, and calls no other `OcuPilot.*` class.
- `HarvestPort.Invoke` evaluates the caller's declared pair set through `GateClass()`'s `EvaluateRequired` before anything else. An empty set fails closed (AD-29).
- The body runs behind `New %request, %response, %session`. The caller's three variables, its device and its `$NAMESPACE` are the same on return on every path. The namespace is restored before the port calls any OcuPilot class (AD-16).
- The answer follows the port convention: `Output pResult, Output pHttpStatus, Output pFault`, and `pFault` is `{error, reason, code[, detail]}` built by `OcuPilot.Kernel.Fault`. Vendor text goes to the log only (AD-39).
- Harvested bodies live under `src/OcuPilot/Port/Harvest/` and extend `OcuPilot.Port.Harvest.Handler`. A harvested `##class(ExecuteMCPv2.Utils).X(` is renamed `..X(`.

**Never:**

- No `%Atelier` superclass and no forbidden rename token: the checker refuses both.
- No bare `Write`, and no harvested body that names `OcuPilot.Api.Response`, `OcuPilot.Api.Error` or `%response`.
- No route, screen, tool, governance key or user-facing string in this story. No product handler is harvested: Story 21.2 is the first.
- No edit to `Api/Error.cls`. Every code used here already exists.

## I/O & Edge-Case Matrix

The fixture handler is `OcuPilot.Test.HarvestFixture`. Every case runs through `OcuPilot.Test.HarvestPortFixture.Invoke`.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Success | `Success`: `Do ..RenderResponseBody($$$OK, , {"a":1})` | `pResult` is `{"a":1}` exactly, with no `status`, `console` or `result` wrapper. 200, `pFault` empty. | none |
| Harvested body | `TaskList` (a verbatim copy of the current sibling body) | `pResult` has exactly the keys `tasks` and `count`, with `count` equal to the size of `tasks`. 200. | none |
| Sanitized failure | `Failure`: renders `..SanitizeError($$$ERROR($$$GeneralError,"vendor text X"))` | 500 `INTERNAL`, the generic reason, and "vendor text X" absent from `pFault` | raw text logged once through `LogFault` |
| Access refusal | `Protect`: renders `..SanitizeError` of a `<PROTECT>` exception | 403 `PORT.ACCESSDENIED`, slug `forbidden` | logged |
| Classified status | `Absent`: renders a raw `$$$LoadObjectNotFound` status | 404 `PORT.NOTFOUND` | logged |
| Two renders | `Twice`: renders a fault, then a success | 500 `INTERNAL`. Neither render is answered. | logged, naming the handler, the method and the render count |
| No render | `Never`: returns `$$$OK` without rendering | 500 `INTERNAL` | logged |
| Helper while switched | `Switched`: in `%SYS`, renders `..SanitizeError(...)` before restoring | 500 `INTERNAL` with the generic reason. No `<CLASS DOES NOT EXIST>` in the logged text. | logged |
| Namespace left switched | `Strand`: sets `$NAMESPACE="%SYS"`, renders OK, returns | 200. The caller is back in its own namespace. | none |
| Device output | `Chatter`: `$System.Status.DisplayError(...)`, then renders OK | 200 with the result. Over the wire (`HarvestRouteFixture`), the body is one parseable object with no `}{`. | output captured and discarded |
| Seeded request | `Echo`: answers `%request.Data` key `k`, `..ReadRequestBody` and `%request.Method` | `pQuery("k")` and the JSON body come back. Method is `POST` with a body and `GET` without one. | none |
| Gate | an empty pair set, or a pair the armed `OcuPilot.Test.ScreenGate` withholds | 403 `AUTH.NOPRIVILEGE`, with `detail.failedPair` when a pair failed. The body's run counter is unchanged. | not logged |
| Not a handler | `pHandler` is `OcuPilot.Kernel.Utils`, or the method is absent | 500 `INTERNAL`. Nothing runs. | logged |
| Outside the port | `RenderResponseBody` called with `%response` undefined, or a plain `%CSP.Response` | an error `%Status` returned. Nothing is written and nothing is recorded. | none |

</intent-contract>

## Code Map

- `src/OcuPilot/Kernel/Utils.cls` -- the already-harvested `ExecuteMCPv2.Utils` (`SanitizeError` :119, `ReadRequestBody` :375). The base extends it, so the renamed `..X(` calls resolve.
- `src/OcuPilot/Kernel/Fault.cls` -- `Outcome(pHttp, pStatus, .fault, .detail)` :120, `Build` :156, `LogRaw` :197. These build the envelope.
- `src/OcuPilot/Port/AtelierPort.cls` -- the sibling port. Reuse its shape: `GATECLASS` :78, `GateClass()` :675, the gate call in `Invoke` :884, `Deny`/`Refuse`/`Fail` :3347-3368, `LogFault` :3327, and the stub-and-capture sequence in `Route` :3046-3140 (`New` the stubs, `$$BeginCapture^%SYS.Capture` and `EndCapture`, restore the namespace in every `Catch`).
- `src/OcuPilot/Port/AtelierRequest.cls` -- the JSON-body request stub (`SetJsonBody`). Reused for a body call. Its header says that only `AtelierPort` constructs it.
- `src/OcuPilot/Screen/Gate.cls:492` -- `EvaluateRequired`, which refuses an empty list.
- `src/OcuPilot/Kernel/Denial.cls` -- the 403 `AUTH.NOPRIVILEGE` envelope parts that `Deny` uses.
- `src/OcuPilot/Area/Explorer/SqlConsole.cls:243` -- `RenderFault`, the route-side pattern for writing a port fault.
- `src/OcuPilot/Test/Dispatch.cls:199` -- `InvokeHandler`, which captures a handler's raw, unparsed body.
- `src/OcuPilot/Test/Envelope.cls:17` -- `AssertSingleEnvelope`, the `}{` check to mirror.
- `src/OcuPilot/Test/ScreenGate.cls`, `src/OcuPilot/Test/AtelierPortFixture.cls:110` -- the deny-gate pattern: a `GateClass()` override forced by a `^||` node.
- `/Users/jbrandt/git/iris-execute-mcp-v2/src/ExecuteMCPv2/REST/Task.cls:14-63` -- `TaskList`, read at sibling HEAD `c6aad31`. Read-only source.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Port/Harvest/Response.cls` -- new, `Extends %CSP.Response`. It holds `Renders` (`%Integer`), `RenderStatus` (`%Status`), `MsgPart` and `ResPart`. Only `HarvestPort` constructs it.
- `src/OcuPilot/Port/Harvest/Handler.cls` -- new, `Extends OcuPilot.Kernel.Utils`. `RenderResponseBody` does nothing but this: when `$IsObject($Get(%response))` and `%response.%IsA("OcuPilot.Port.Harvest.Response")`, it increments `Renders`, keeps the first render's parts and returns `$$$OK`. Otherwise it returns an error status.
- `src/OcuPilot/Port/HarvestPort.cls` -- new. `Invoke(pHandler, pMethod, pPairs As %List, ByRef pQuery, pBody = "", Output pResult, Output pHttpStatus, Output pFault, Output pConsole, pArgs...) As %Status` runs these steps in order:
  1. Gate (403).
  2. Handler check (`%Extends` of the base and a compiled class method; otherwise `INTERNAL`).
  3. Stubs: the query goes into `%request.Data(k,1)`, and a body goes in through `AtelierRequest.SetJsonBody` with `POST`.
  4. Capture, then `$ClassMethod(pHandler, pMethod, pArgs...)`, then end the capture and discard the output.
  5. Restore the namespace.
  6. Outcome, per the matrix and the table in Design Notes.

  Also add `GATECLASS`, `LOGSUBSYSTEM = "harvestport"`, and overridable `GateClass()` and `LogFault()`. `pConsole` is the render's `pMsgPart`.
- `src/OcuPilot/Port/AtelierRequest.cls` -- doc sentence only: name `HarvestPort` as its second constructor.
- `src/OcuPilot/Test/HarvestFixture.cls` -- new, `Extends OcuPilot.Port.Harvest.Handler`.
  - `TaskList`: copied from the sibling. Two changes only: the base class, and `##class(ExecuteMCPv2.Utils).` becomes `..`.
  - Bodies for every other matrix row.
  - A `^||OcuPilotHarvestFixture` run counter, with `Reset`.
- `src/OcuPilot/Test/HarvestPortFixture.cls` -- new, `Extends OcuPilot.Port.HarvestPort`. `GateClass()` can be forced to `OcuPilot.Test.ScreenGate`. `LogFault()` records into `^||OcuPilotHarvestPortFixture` instead of logging, so no test writes the instance log.
- `src/OcuPilot/Test/HarvestRouteFixture.cls` -- new. `Handle()` reads `%request.Get("case")`, invokes the port and writes the answer, using `Response.JSONStatus` or `Error.Render` as in `SqlConsole.RenderFault`.
- `src/OcuPilot/Test/Harvest.cls` -- new, under 500 lines. It covers every matrix row and the ACs below. `OnBeforeOneTest` and `OnAfterOneTest` reset both fixtures and `ScreenGate`.

**Acceptance Criteria:**

- **AC1.** Given `OcuPilot.Port.Harvest.Handler`, when its compiled `RenderResponseBody` is read from `%Dictionary.CompiledMethod`, then it is a class method with FormalSpec `pStatus:%Status,pMsgPart:%DynamicArray,pResPart:%DynamicObject` and return type `%Library.Status`. A success through the port answers the bare result object (matrix row "Success").
- **AC2.** Given every compiled `OcuPilot.*` class that `%Extends` the base, when the implementation of each method it defines is read, then none names `OcuPilot.Api.Response`, `OcuPilot.Api.Error` or `%response`, and at least one class was scanned. Given the verbatim `TaskList`, when it runs through the port, then it answers OcuPilot's envelope (matrix row "Harvested body").
- **AC3.** Given the `Twice` and `Chatter` cases over `HarvestRouteFixture` through `OcuPilot.Test.Dispatch.InvokeHandler`, when the raw body is read, then it contains no `}{` and parses as one object: the `INTERNAL` fault for `Twice`, the result for `Chatter`. `OcuPilot.Test.Envelope` stays green.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs:** AD-23 (the seam), AD-12 and AD-39 (one envelope, normalized vendor text), AD-29 (a port's own gate), AD-16 (save and restore), AD-1 and AD-7 (the stubs let a turn job call the port in process), AD-61 (the in-process call, stub and capture pattern; a `<PROTECT>` is an access refusal), and AD-36 (no read in this story; bounds belong to each harvesting story).

**Measured on `ocupilot-ci` (2026-11-14):**

- The only inherited member that any of the sibling's 19 handler files calls is `RenderResponseBody`. Every other `..X(` is defined in its own file.
- No `OcuPilot.*` class is visible from `%SYS`. `##class(OcuPilot.Kernel.Utils).X()` raises `<CLASS DOES NOT EXIST>` while switched, even after it has been loaded in `HSCUSTOM`.
- An inherited `..X()` from a subclass, and property sets on a stub created before the switch, both work in `%SYS`.

So the base records only, the port builds the envelope after restoring the namespace, and the base extends `Kernel.Utils`.

**Outcome table.** When exactly one render was recorded:

- OK status: `pResult` is `ResPart` (`{}` when omitted), 200.
- Raw status text containing `<PROTECT>`: `Fault.Outcome(403, …)`.
- Otherwise: `Fault.Outcome(0, …)`.

HTTP status by code: `PORT.ACCESSDENIED` 403, `PORT.NOTFOUND` 404, `PORT.CONFLICT` 409, `PORT.VALIDATION` 400, `PORT.NOTIMPLEMENTED` 501, anything else 500.

**Decided in-stage:**

- The base "emits OcuPilot's envelope" by recording the one render for the port to shape. The bytes are written by the route's `Response`/`Error`, because AD-12 forbids a handler writing and AD-1 needs the call to work in process.
- Two renders, or none, is `INTERNAL`. It is never "first wins", because a second render is the double-envelope defect.
- The request method is `POST` with a body and `GET` without one.
- Device output is discarded.
- Every body fault is logged. A later story that reads an absence on purpose adds an unlogged list, as `AdminPort` does.
- `RenderResponseBody` outside a `HarvestPort` call records nothing and fails, so a body cannot be wired as a route past the port's gate.

**Named limits:**

- `SanitizeError` collapses a status to `GeneralError`, so a harvested refusal reaches a caller as `INTERNAL` unless its area port validates first.
- A body that names another `OcuPilot.*` class while switched fails `INTERNAL` (measured above). Its harvesting story reaches that class through `..` or restores the namespace first.

**Extend, don't copy (Rule 2/31):**

- The base extends `Kernel.Utils`.
- `HarvestPort` reuses `Fault`, `Screen.Gate.EvaluateRequired`, `Kernel.Denial` and `AtelierRequest`.
- `HarvestPort` copies about 15 lines of `AtelierPort.Route`'s capture. Reason: `Route` is private and route-specific (file device, ceiling, kept text), and this capture discards its output.
- `Deny`, `Refuse` and `Fail` follow the per-port private-helper convention that every port carries.

**Integration ACs:** No consumers in this story; the first consumer will be Story 21.2. `HarvestRouteFixture` stands in for the route side.
**Consumed-by:** 21.2, 21.3, 21.4, 21.5, 21.6, 21.7, 21.8, 21.9 and 21.10 each harvest handler bodies through `HarvestPort`, with their own area port's pairs.
**Consumes:** `Kernel.Utils`, `Kernel.Fault`, `Screen.Gate`, `Kernel.Denial`, `AtelierRequest`.

**Proposed spine amendment (Rule 20; for the runner's veto window, not applied here).**

- Append to AD-23's Rule: "Harvested bodies live under `Port/Harvest/`. They extend `OcuPilot.Port.Harvest.Handler`, which extends `OcuPilot.Kernel.Utils`, so a harvested `##class(ExecuteMCPv2.Utils).X` becomes `..X` and resolves while a body is in `%SYS`, where no OcuPilot class is visible (measured). Its `RenderResponseBody` writes nothing: it records the one render on `HarvestPort`'s stub response, and outside a `HarvestPort` call it records nothing and fails. `HarvestPort` is the only caller of a harvested body. It evaluates the caller's declared pairs first, failing closed on an empty set. It runs the body behind `New`ed stubs with device output captured and discarded, and restores `$NAMESPACE`. It answers the result on an OK render and a `Fault`-normalized envelope otherwise, with vendor text going to the log only. None or two renders is `INTERNAL`."
- Add `HarvestPort` to AD-29's Binds.

## Verification

**Shared surfaces:** none. The four new test classes join the instance suite untimed, and the merge gate refreshes `ci-timings.json`. `AtelierRequest`'s edit is a doc comment only.
*Every test added or changed passes on a fresh environment, in either order.* Each test resets both fixtures' `^||` nodes and `ScreenGate`, and asserts only on its own fixture's answers.

**Commands.** Run each in the foreground with `timeout: 600000`, one at a time, against the throwaway `ocupilot-ci` only.

- `(loop)` `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/f9329139-8fb8-421f-b2bb-04300ba71baf/scratchpad/e21u/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci`. Expected: `LOADERRORS=0`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.Harvest`. Expected: green.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.Envelope`. Expected: green.
- `(loop)` `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh`. Expected: clean.
- `(once)` `cd ui && npm run test:tools`. Expected: green.
- `(once)`, lead-owned: the full ObjectScript sweep, one class per call; `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS`; and Rule 30's fresh check. The full browser suite is left to CI.

**Mutations (Rule 19), one per AC:**

- AC1: retype `pMsgPart` to `%DynamicObject` in the base. Expected red: the signature test.
- AC1: record `{status, console, result}` as `ResPart`. Expected red: Success.
- AC2: add `Do ##class(OcuPilot.Api.Response).JSON(tResult)` to the fixture's `TaskList`. Expected red: the scan.
- AC3: make the port answer the first of two renders. Expected red: Twice, in process and over the wire.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
