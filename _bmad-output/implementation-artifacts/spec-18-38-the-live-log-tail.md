---
title: 'Story 18.38: The live log tail'
type: 'feature'
created: '2026-10-12'
status: 'done'
baseline_revision: 'ad0fb51feefb1ce52a318fc5f8d7c2148eefb49c'
baseline_commit: 'ad0fb51feefb1ce52a318fc5f8d7c2148eefb49c'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred:
  - summary: >-
      A client that disconnects while a tail is held leaves its CSP process in the wait until the bound (50 s); nothing ends it earlier.
    evidence: |-
      Measured on ocupilot-ci (Task 0 e): a client dropped at 12 s left its process in Tail (HANG) until about 50 s; the beats at 20, 30 and 40 s returned OK, because Response.Flush answers $$$OK and the gateway keeps draining. Only the gateway's own 504 interrupts the process (<EXTERNAL INTERRUPT>, answered unlogged). Turning Live tail off, or a person leaving, therefore holds up to one process per tail still in flight for up to the bound.
    location: >-
      OcuPilot.Port.LogSourcePort.Tail; OcuPilot.Api.Response.Heartbeat
    severity: low
  - summary: >-
      No automated test sees a beat arrive on time: Heartbeat's flush properties are pinned in process, and the delivery itself was measured by hand.
    evidence: |-
      The wire tests read a whole body, so they cannot tell a beat at 10 s from one released with the envelope; Task 0 b timed it with a raw socket and curl -sN --compressed on ocupilot-ci (beats at 10.1, 20.2, 30.3 and 40.4 s, envelope at 50.5 s).
    location: >-
      OcuPilot.Test.Envelope.TestAHeartbeatSetsTheStreamingPropertiesBeforeItsFirstFlushOnly
    severity: low
---

<intent-contract>

## Intent

**Problem:** Log viewers read bounded pages; newer lines arrive only on a Load newer press (EXPERIENCE.md :899, "live tail is P2"), so nobody can watch `messages.log` or `alerts.log` as they are written.

**Approach:** `messages` and `alerts` opt in at their port. `GET /logs/<source>/tail` takes the page's `identity` and `size`, holds until the file moves or the gateway-derived bound passes, with heartbeat newlines before its one envelope, and answers `{source, changed}`. The viewer's Live tail toggle chains these polls and reads each change through the page route. Every other source keeps bounded pages.

## Boundaries & Constraints

**Always:**

- Refuse in `Page`'s order, before any wait or heartbeat (the matrix's codes); after the first heartbeat, answer only `{source, changed}`.
- Wait at most `TestCall.BoundSeconds` (50 s: gateway 60 s, read on `ocupilot`), re-checking each second. An absent or unreadable file is no change before the bound and `changed: true` at it, so the page read reports it.
- Only `Api/Response` writes heartbeats (AD-12); the port never writes to the device.
- The client chains awaits: no timer, `EventSource` or `WebSocket` (`ui/tools/refresh.test.mjs` :1191-1217).

**Never:** another source, a rotated file, the hub, integrity or Activity; a descriptor key, tool or governance key (AD-22); a new `Api/Error.cls` parameter (989 of 1,000), so three `LOG.*` codes are reused with their own sentences; a spawn, an escalation, or a log line for a client that has gone; a file in Epic 20's diff.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected | Error handling |
|---|---|---|---|
| Moved | `size` or `identity` differs | `changed: true` at once, no heartbeat | -- |
| Moves mid-wait | a line written | `changed: true` within about 1 s | -- |
| Still | nothing written | held to the bound, a newline every 10 s, `changed: false` | -- |
| Partial line | bytes, no newline | `changed: true`; the next tail, at the new size, waits | -- |
| Rotation | `MoveConsoleLog` mid-wait | `changed: true`; the page answers `restarted` | an absent instant is waited out |
| Refused | non-tail source; no pair; bad cursor; `file` | 404 `LOG.SOURCE`; 403; 400 `LOG.OFFSET`; 400 `LOG.FILE` | no heartbeat; a gate refusal touches no file |
| Client gone | a heartbeat write fails, or the gateway interrupts | the wait ends; a dropped socket's wait runs to the bound [AMENDED 2026-10-13 - see the Spec Change Log] | nothing logged |

</intent-contract>

## Code Map

Under `src/OcuPilot/` at `093b3f34`.

- `Port/LogSourcePort.cls`: header :1-77; `Page` :709-842, the order to copy; helpers `Resolve` :2916, `OpenStream` :666, `Identity` :3429, `FileRefusal` :3254, `DeniedRefusal` :2511, `Gate` :2904, `Refuse` :3580, `Fail` :3590.
- `Api/LogPage.cls` `Handle` :33, `Answer` :87; `Api/Response.cls`, the sole writer (:2-5).
- `Kernel/Provider/TestCall.cls` `BoundSeconds` :88, `GatewaySeconds` :61; the sibling seam `Port/SqlPort.cls` `BoundSeconds` :321; the bounded-wait precedent `Port/AdminPort.cls` `AwaitTask` :3488.
- `irislib/%CSP/Response.cls` `Flush` :420: once sent, status and headers are fixed.
- `ui/src/app/areas/logs/log-viewer.store.ts`: `LogViewerSource` :12 (`tailPath` is the page route), `reset` :289, `loadNewer` :458, `read` :467 (cursor :536-541; `generation` drops a late answer). `core/api.ts` `requestJson` :328: no client timeout; the body is `JSON.parse`d.

## Tasks & Acceptance

**Task 0** (on `ocupilot-ci` after the runner's sweep; findings under "For the lead"; one defeating a criterion halts `intent gap` with the amendment). Through the built route: (a) a hold to the bound answers 200, and past the gateway timeout (`TailBoundSeconds` mutated on the mounted copy, then restored) what and when; (b) whether heartbeats reach `curl -sN` on 52776 on time or with the envelope, gzip included; (c) what the route and `%File.Exists` see across `Config.Startup.MoveConsoleLog`; (d) one `TailState` check's cost; (e) whether a heartbeat fails after a disconnect, ending the process; (f) three concurrent tails by one principal beside a page read and a sign-in, and any license line.

**Execution:**

1. `Port/LogSourcePort.cls` (add-only; header corrected in place):
   - `TAILSOURCES = "messages,alerts"`, `TAILCHECKSECONDS` 1, `TAILBEATSECONDS` 10, `TailSources()`, and the seams `TailBoundSeconds()` (`SqlPort.BoundSeconds`' line), `TailCheckSeconds()`, `TailBeatSeconds()`.
   - `TailState(pPath, .pSize, .pIdentity) As %Boolean`, through `OpenStream` and `Identity`.
   - `Tail(pSource, pIdentity, pSize, pFile, pBeatClass, .pResult, .pHttpStatus, .pFault)`: the Boundaries' refusals in order (cursor: `identity` `^[A-Za-z0-9_=-]{1,64}$`, `size` digits, both required [AMENDED 2026-10-13 - see the Spec Change Log]), `Resolve`, then the matrix's loop, calling `$ClassMethod(pBeatClass, "Heartbeat")` per beat. A throw before the first beat is `Fail`; after it, logged and answered `changed`. A failed heartbeat ends the wait, unlogged.
2. `Api/Response.cls`: `Heartbeat()` sets JSON `ContentType`, writes `$Char(10)`, `%response.Flush()`.
3. `Api/LogPage.cls`: `HandleTail(pSource)` passes `identity`, `size`, `file` to `Tail(..., "OcuPilot.Api.Response", ...)`, through `Answer`.
4. `Api/Router.cls`: `GET /logs/alerts/tail` above :152 and `/logs/messages/tail` above :154; thin `LogAlertsTail` and `LogMessagesTail` beside `LogAlerts` :1129 and `LogMessages` :974.
5. "Nothing streams" in `Screen/Descriptor/LogMessageViewer.cls` :17-19, `LogAlertViewer.cls` :19-21, `log-viewer.page.ts` :121 and the store's :215 becomes, in place: no auto-refresh (AD-43); newer lines come on Load newer or the live tail its source opts into.
6. `log-viewer.store.ts`: `livePath` (`/api/ocupilot/logs/<source>/tail`) on the two sources (:42, :47). `canLive()`: the path, the current file, a cursor, not windowed; `live()` reports the loop. `setLive(on)` tails with `identity` and `size`, runs `loadNewer` on `changed` until a page is not `truncated`, and stops on off, a fault (shown as a read fault is), or a new live generation, which `reset`, `clearWindow` (:298) and `setSource` (:323) also start.
7. `log-viewer.page.ts`: a "Live tail" toggle (button-secondary, `aria-pressed`) beside Load newer (:313) while `canLive() || live()`; off on a file change and in `onDestroy` (:421).
8. `strings.ts`: `logViewerLiveTail: 'Live tail'` under `/** EXPERIENCE.md:379 */`. EXPERIENCE.md :379 in place, line count unchanged: ` · "Live tail"` after `"Load newer"`, and `, the live tail's toggle (Story 18.38)` after "its tail control (`:402`)". Literals 3,316 + 1 (3,341 after 18.46 and 18.37); if the recount here exceeds 3,350, raise `strings.test.mjs`'s bound to 3,800 under its protocol and comment pattern.

**Tests:**

9. `Test/LogTail.cls` (new): `LogSourceFixture` over a scratch file (bound 3 s, beat 1 s, check 0.2 s), its own writer job stopped in `OnAfterOneTest`. Every matrix row through `Tail` with a beat-counting class; a refusal makes no beat, a gate refusal no file access; `TailSources()` is exactly `messages,alerts`.
10. `Test/LogTailWire.cls` (new; `Http.AbsoluteRequest` :207, `pTimeout` the bound + 15): refusals answer within 2 s; a cursor a byte behind `messages.log` answers `changed: true` within 2 s; its current cursor answers within the bound + 5 s: 200, zero or more newlines, one `{source, changed}` envelope, no `}{`.
11. `Test/LogSourceDenial.cls` (add-only, armed by `OCUPILOT_ALLOW_PRINCIPALS`): a principal without `%Admin_Operate:USE` is refused 403 on both routes within 2 s.
12. `log-viewer.spec.ts`: :279 becomes "with Live tail off, nothing streams", looping over a rotated file, the six secondary logs, integrity and Activity (no toggle, request or timer). New: the toggle on the two current files only; Live tails with the cursor, appends the page on `changed` and tails again on `false`; off, a file change and destroy drop an in-flight answer and request nothing more; a 403 stops Live and shows the fault; `vi.getTimerCount()` stays 0.
13. `ui/browser/messages-log.browser-spec.mjs`: press Live tail, write a marker (its writer, :91-125); the row appears within 10 s, no Load newer; turn Live tail off.
14. Rule 30 sweep, one class per run:
    - `EndpointCoverage` (add-only): two GET probes with `expect="code=LOG.OFFSET"`.
    - `Descriptor` :1076 and :1120 read "no auto-refresh (AD-43); its source opts into the live tail" and assert the endpoint is in `TailSources()`; the loop at :1190 asserts each secondary source is not.
    - Unchanged, run: `DeveloperFloorRoutes`, `InteropFloorRoutes`, `LogSource`, `LogSourceWire`, `ReadTool`, `SurfaceCoverage`; browser `alerts-log`, `messages-log-files`, `secondary-logs`; `npm run test:tools`.

**Acceptance Criteria:**

- **AC1 (epics.md).** Given messages.log or alerts.log on its current file, when a person turns Live tail on and the instance writes a line, then the line appears without Load newer, carried by `GET /logs/<source>/tail`, held up to the bound with a heartbeat before its one envelope.
- **AC2.** Given any other log, a rotated file, or Live tail off, when the screen stays open, then no toggle is drawn or nothing is requested.
- **AC3.** Given a refused tail, when it is asked, then it is refused before any wait or heartbeat, with the matrix's status and code.
- **AC4.** Given Live tail on, when the person turns it off, chooses another file or leaves, then nothing more is requested and an in-flight answer is dropped.
- **Integration.** Given the log viewer, the route's one consumer, when a marker is written under Live tail, then its row appears (task 13).

## Spec Change Log

- 2026-10-13, lead, implement halt (Task 0 e), Rule 5 tier 1: the vendor does not fail a heartbeat after a client disconnects, so the matrix's "Client gone" row now reads that a dropped socket's wait runs to the bound (at most `BoundSeconds`, one CSP process, nothing logged), the bounded hold the Design Notes already name; the cursor is required whole (`EndpointCoverage`'s bare probe draws `LOG.OFFSET`). AD-12's carve-out names the two response properties Task 0 b measured. Resumed at review (`in-review`) over the uncommitted implementation.

- 2026-10-13, lead spec gate: "For the lead" applied (AD-12's second carve-out and AD-43's live tail in the spine; EXPERIENCE.md :646, :848, :899 in place, line count unchanged, `test:tools` 1948/1948). `Descriptor.cls` :1076 and :1120 are the Rule 11 ask to the orchestrator.

## Review Triage Log

### 2026-10-13 - Review pass

- verdicts: 26 findings - high 0, medium 3, low 19, false 4, maybe-false 0
- findings (G = verification-gap layer, I = intent-alignment layer):
  - `[medium]` `[patch]` G1 heartbeat newline and its `HandleTail` wiring verified nowhere: `Envelope` never reads the device and `LogTailWire` accepted zero newlines - `LogTailWire` held-cursor test now holds past a beat interval (up to three tries, since the instance writes `messages.log` now and then) and asserts a newline per full beat and a hold to the bound when unchanged
  - `[medium]` `[patch]` G2 the alerts tail route's source binding verified nowhere: every 200 assertion ran on messages - the cursor-behind test now loops both routes and asserts `source`
  - `[low]` `[patch]` G3 the shipped bound had only an upper limit on the wire - the held-to-the-bound assertion in the same test
  - `[low]` `[patch]` G4 the absent-file gap leg could pass on a writer that never ran - the fixture counts absent looks, the leg asserts at least one
  - `[low]` `[reject]` G5a no mutation line for the identity term - Rule 19 asks one demonstrated mutation per AC; AC1 has several
  - `[low]` `[patch]` G5b no mutation for the bound or the second-envelope and space-heartbeat claims - the unobserved claim left the test header; the bound mutation is recorded
  - `[low]` `[patch]` G5c no mutation for the heartbeat write or the beat class - two mutations recorded (runs 680, 681)
  - `[low]` `[patch]` G5d no mutation for the alerts binding - recorded (run 685)
  - `[low]` `[reject]` G5e no mutation for the `livePath` term of `canLive` - per-AC discipline met by the current-file term
  - `[low]` `[reject]` G5f no mutation for the `LOG.FILE` branch - per-AC discipline met by the cursor, gate and roster mutations
  - `[low]` `[reject]` G6 writer-job tests carry about 1.3 s of start margin - generous for a job start, and a fix adds a readiness signal to every writer test
  - `[false]` `[reject]` G7 the absent-file answer is not tied to the alerts route - the matrix row is the port's, tested by the absent-file test; the alerts route runs the same `Tail`
  - `[low]` `[reject]` G8 gate-before-malformed-cursor precedence untested - no matrix row states it, and a reorder leaks only the cursor grammar
  - `[medium]` `[patch]` I1 the heartbeat bytes are checked at the port with a fake class and on the wire only as "zero or more" - the G1 fix
  - `[low]` `[patch]` I2 the envelope written after a flushed heartbeat is covered by no guaranteed-heartbeat test - the G1 test parses the whole body after four newlines (run 678)
  - `[low]` `[reject]` I3 the 1 s check interval default is referenced by no test - a slow default would show in the browser spec's 10 s window
  - `[low]` `[reject]` I4 rotation tested on a scratch file, never `MoveConsoleLog` - measured in Task 0 (c); rotating the instance log in a test breaks hermeticity
  - `[low]` `[reject]` I5 a dropped socket is driven by no test - the accepted consequence of the Rule 5 amendment; the deferred entry stands
  - `[false]` `[reject]` I6 the 404 `LOG.SOURCE` row is reachable only at the port - the Router maps the two tail sources only; the port test pins the row
  - `[low]` `[patch]` I7 alerts held and changed paths unexercised on the wire - the G2 fix exercises the changed-at-once path; the held path is the same `Tail`
  - `[low]` `[reject]` I8 opt-in is declared at the port, the Router and the client - AD-5; the descriptor tests tie the viewers to `TailSources()`
  - `[low]` `[patch]` I9 `LOG.FILE` reused the page's rotated-file sentence - `Tail` now has its own
  - `[low]` `[reject]` I10 `Page`'s order is mirrored, not shared or compared - the matrix's codes are pinned row by row
  - `[low]` `[reject]` I11 the component spec runs against `StubApi` - the browser spec runs the real client
  - `[false]` `[reject]` I12 `EXPERIENCE.md` and `strings.ts` are also in Epic 20's diff - the stage ruling lists both as shared add-only files; the hunks do not overlap
  - `[false]` `[reject]` I13 the intent's `:899` quote is gone from the tree - the spec gate amended that line

## Design Notes

**Governing ADs:** AD-5, 8, 12, 16, 19, 21, 22, 29, 30, 31, 36, 39, 43. **Consumes:** 6.13 and 6.14 (`Page`, the viewer), 16.20 (the file choice), 10.5 (`TestCall`). **Consumed-by:** no story beyond the two viewers. **Ledger:** none.

**Who opts in.** Only `messages` and `alerts` append under one offset-and-identity cursor; the secondary logs are merged vendor windows, integrity a report, Activity a vendor read; a rotated file never grows. The route enforces `TAILSOURCES`; `livePath` names routes as `tailPath` does, so AD-5 is unchanged.

**A wake signal, not lines.** A flushed response cannot change its status, so the tail only says the file moved; the page route keeps `Page`'s window, restart and refusals. The cursor is `size`, not `offset`: `ReadWindow` leaves a partial last line unread, so an offset test would wake forever.

**The agent keeps bounded pages:** a tool runs in a turn step that must stay short and re-check stop, kill switch and lease (AD-30, AD-31), and `logs.messages.read` and `logs.alerts.read` answer the newest window (AD-36). No new tool, so `ReadTool` :93-94, `ToolEmit`, `SurfaceCoverage`, `StageTwoTools` and `Navigation` keep their literals.

**Siblings (Rule 31):** `Tail` reuses `Page`'s helpers; the bound seam repeats `SqlPort.BoundSeconds`' line, as each port's seam does; the wait follows `AdminPort.AwaitTask`; the store reuses `loadNewer`.

**Named consequences:** an open Live tail holds a CSP process up to the bound (Task 0 e, f); the gate is checked per call, so a pair withdrawn mid-wait is refused at the next tail.

**Rule 11:** Epic 20's diff (2026-10-12) touches none of these files; `Descriptor.cls`'s two reworded messages are the one in-place edit to a shared add-only file, the lead's ask.

**For the lead** (Rule 20; tag `[AMENDED 2026-10-12, Story 18.38 spec gate, Rule 20]`):

- **AD-12**, after the static-handler carve-out:
  > **A second carve-out: the live log tail's heartbeat.** While `GET /logs/<source>/tail` waits, `Response.Heartbeat` writes one newline and flushes, at most every `LogSourcePort.TAILBEATSECONDS`, before the route's one envelope; JSON reads leading whitespace as nothing, and `Response` and `Error` stay the only writers. A flushed response cannot change its status, so every refusal precedes the first heartbeat; after it, a fault is logged and answered as a change, which the viewer's next page read reports.
- **AD-43**, at its end:
  > **The live log tail is not auto-refresh.** A log source opts in at its port (`LogSourcePort.TAILSOURCES`: `messages`, `alerts`), and its viewer offers Live tail on the current file only: one chained long poll, never a timer. `GET /logs/<source>/tail` takes the page's `identity` and `size`, is held until the file moves or `TestCall.BoundSeconds` passes, re-checking each second (no vendor event signals a log write), with AD-12's heartbeat, and answers `{source, changed}`; the viewer then reads its next bounded page (AD-36). It is no declared read or tool, joins no Auto-refresh roster, and pauses for no proposal, since nothing writes a log line. Every other source, a rotated file included, streams nothing.
- **EXPERIENCE.md**, in place, line count unchanged (no citation quotes these lines):
  - :646: replace `Bounded paging and the non-live tail: Screen Synchronization and Live Data.` with `Bounded paging, and the live tail alerts.log and messages.log opt into: Screen Synchronization and Live Data.`, and after `"Load newer" (button-secondary) at the tail;` insert ` on alerts.log's and messages.log's current file, a "Live tail" toggle (button-secondary, aria-pressed) beside it (Story 18.38);`.
  - :848: replace `Load newer only` with `Load newer; Live tail on alerts.log and messages.log`.
  - :899, the whole line: `- **Tail, live where the source opts in.** Log viewers load bounded pages and offer "Load newer"; on alerts.log's and messages.log's current file, "Live tail" also holds a long poll that brings newer lines as the instance writes them (Story 18.38); every other log, an older rotated file included, streams nothing.`
- No vendor defect candidate.
- **Task 0 findings** (`ocupilot-ci`, 2026-10-13, through Apache and the CSP gateway on 52776; measured, not recalled):
  - **(a)** A hold to the 50 s bound answers 200 with a beat every 10 s and one envelope. With `TailBoundSeconds` mutated to 75 s it answered 200 at 75.6 s, so a beat restarts the gateway's 60 s timer; with the beat mutated to 1,000 s it answered 504 `text/html` with no body at 60.07 s, and the gateway interrupted the process at that instant (`<EXTERNAL INTERRUPT>` inside `Tail`).
  - **(b)** As first written, only the first beat arrived on time; for a client sending `Accept-Encoding: gzip`, every browser, nothing arrived until the envelope (`Content-Length` 39). `Heartbeat` therefore sets `%response.GzipOutput = 0` and `%response.AllowOutputFlush = 1` before its first write, neither settable after it. Then `curl -sN --compressed` shows a beat at 10.1, 20.2, 30.3 and 40.4 s and the envelope at 50.5 s.
  - **(c)** Across `MoveConsoleLog` a 2 ms sampler never saw an absent instant: `%File.Exists` and `TailState` stayed true; size 1,845,227 -> 325 and the identity changed at the call (2 ms), and the held tail answered `changed: true` 0.49 s later. A rotated `messages.old_20261013_1` remains on `ocupilot-ci`.
  - **(d)** One `TailState` costs 0.29 ms (1,000 calls, 0.29 s; the same on 1.8 MB and 2.3 KB).
  - **(e)** A heartbeat does not fail after a disconnect: `Response.Flush` answers OK. A client dropped at 12 s left its process in `Tail` until about 50 s, the beats at 20, 30 and 40 s returning OK, nothing logged. The matrix's "Client gone" row holds for a failing heartbeat and for the gateway's interrupt (both end the wait unlogged; the interrupt was logged as an error until `Tail` named it), not for a dropped socket: that costs one process to the bound, the Named consequence at its edge (deferred, low).
  - **(f)** Three concurrent tails by `_SYSTEM` (one gzip-accepting, one with no cursor) held 50 s with beats on time beside a page read (7.7 ms), a sign-in (6.3 ms) and `/instance` (5.1 ms); `LUConsumed` read 2 before, during and after; no `messages.log` line.
  - **Amendments recommended, not applied:** AD-12's carve-out names the two response properties ("`Response.Heartbeat` turns compression off and output flushing on, before its first write"); the matrix's "Client gone" row reads "a heartbeat write fails, or the gateway interrupts | the wait ends; a dropped socket's wait runs to the bound | nothing logged". The cursor is required (both `identity` and `size`; neither is `LOG.OFFSET`), so `EndpointCoverage`'s bare probe is refused at once rather than held.

## Verification

**Commands** (one run per call, `timeout: 600000`):

- `(loop)` `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/carry-2026-10-08/epic-18-d8/load-ocupilot-ci.sh`: `LOAD-OK`, `STARTPATH-OK`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one at a time, totals in `%UnitTest_Result`: tasks 9-11 and task 14's classes.
- `(loop)` `cd ui && npm run test:tools && npm run test:components && npm run build`, the bundle under the 1,992 kB warning.
- `(loop)` `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`; then, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`, `node --test --test-concurrency=1 browser/<spec>.browser-spec.mjs` for tasks 13 and 14.
- `(loop)` `uv run scripts/check-objectscript.py`, `bash scripts/lint-docs.sh`: 0 problems. The full ObjectScript sweep is the runner's; the full browser suite is CI's.

**Shared surfaces:** the routes, probes and route sweeps; the Fixed strings and `strings.ts`; EXPERIENCE.md :379, :646, :848, :899; `Descriptor.cls`'s log-viewer pins. Request-sequence pins hold with Live tail off by default (`log-viewer.spec.ts` :270-277, :432-448, :691-696; `alerts-log.browser-spec.mjs` :264-299).

every test added or changed passes on a fresh environment, in either order

**Results** (ocupilot-ci, final code, totals confirmed in `%UnitTest_Result`): `LogTail` 11 (run 688), `LogTailWire` 4 (687), `LogSource` 22 (686), `LogSourceDenial` 8 (667), `EndpointCoverage` 2 (668), `Descriptor` 60 (669), `DeveloperFloorRoutes` 1 (670), `InteropFloorRoutes` 1 (671), `LogSourceWire` 9 (673), `ReadTool` 28 (674), `SurfaceCoverage` 4 (675), `Envelope` 17 (676). `test:tools` 1,969/1,969; `test:components` 3,063 in 244 files; `check-objectscript` 0 problems and `lint-docs` 0 problems. Browser on the rebuilt bundle: `messages-log` 5/5, `alerts-log` 7/7, `messages-log-files` 5/5, `secondary-logs` 7/7, and `screen-height` 15/15 for the wrapped Load newer row. Build: initial total 1.91 MB (warning at 1,992 kB), largest lazy chunk `data-browser-page` 83.32 kB (cap 88 kB). Fixed strings: 3,356 -> 3,357 literals under the unchanged bound 3,400; 43 remain, so the next story that adds literals raises it. The review pass changed ObjectScript only (`LogSourcePort.Tail`'s `LOG.FILE` sentence, `LogSourceFixture`, `LogTail`, `LogTailWire`); the classes above it ran before it stand.

**Mutations** (observed, each reverted; ObjectScript on `ocupilot-ci`'s mounted copy with the class and its descendants recompiled, client rebuilt and redeployed before the browser read it):

- mutation: `Tail` drops the size term from its moved comparison -> `LogTail` moved, mid-wait, partial-line and gate-served legs (4 red); `LogTailWire` cursor-a-byte-behind (50.35 s, not 2 s)
- mutation: `Tail` never calls its heartbeat -> `LogTail` still-file (0 beats), absent-file, client-gone and fault-after-first-beat legs (4 red)
- mutation: a file access before the gate in `Tail` -> `LogTail` gate-refusal and the refusal rows' access count (red)
- mutation: the cursor check removed from `Tail` (nothing before the first beat refuses) -> `LogTail` refusal rows, status, code and access count (red)
- mutation: a failed or thrown heartbeat ignored -> `LogTail` client-gone (red); the external-interrupt branch removed -> the same test, status and nothing-logged (red)
- mutation: `TAILSOURCES` plus `systemmonitor` -> `LogTail` roster and refusal row (red) and `Descriptor` secondary-log loop (red); `TAILSOURCES` minus `alerts` -> `Descriptor` alert leg (red)
- mutation: the gate skipped in `Tail` -> `LogSourceDenial` both-tails leg (red, 403 expected)
- mutation: `AllowOutputFlush` line deleted from `Heartbeat` -> `Envelope` heartbeat leg at "output flushing on" (red); `GzipOutput` line deleted -> the same leg at "compression off" (red)
- mutation: `Write $Char(10)` deleted from `Heartbeat` -> `LogTailWire` held-cursor test at "a newline for each full beat interval held (4 after 50.3 s): 0" (run 680); `HandleTail` passing no beat class -> the same assertion (run 681)
- mutation: `TailBoundSeconds` answers 15 -> `LogTailWire` held-cursor test at "an unchanged tail was held to the bound: 15.1" (run 682)
- mutation: `LogAlertsTail` bound to the console log's key -> `LogTailWire` cursor-a-byte-behind test at "alerts: naming the source the route bound" (run 685)
- mutation: `Tail` answers changed true as soon as the file is absent -> `LogTail` absent-file test (4 red, run 683); the gap writer started after the bound -> its "a look did find the file absent" assertion alone (run 684)
- mutation: the `/logs/alerts/tail` probe deleted -> `EndpointCoverage` (196 probes, 197 routes, red); the `/logs/messages/tail` route deleted -> `LogTailWire` 4 of 4 red
- mutation: `canLive` without the current-file test -> `log-viewer.spec.ts` AC6 loop, rotated-file and file-change legs (3 red)
- mutation: `stopLive` keeps the live generation -> the four AC4 legs: off, page in flight, file change, leaving (4 red)
- mutation: no `loadNewer` on `changed` -> the Live chain, truncated-pages, in-flight-page and refused-page legs (4 red); `messages-log.browser-spec.mjs` Live tail test (red: no line within 10 s)
- mutation: page `onDestroy` without `setLive(false)` -> the leaving leg (red); `clearWindow` without `stopLive` -> the file-change and sign-out legs (2 red)
- (QA) mutation: `Tail` moves on growth only (`tNowSize > tBaseSize`) -> `LogTail` moved-file identity leg and rotation test (2 red, run 691)
- (QA) mutation: `Tail`'s `LOG.FILE` refusal disabled -> `LogTail` refusal rows with a file name (run 692) and `LogTailWire` refusal rows with a file name (run 693), one test red each
- (QA) mutation: `EnsureAlertLine` skipped on an instance whose `alerts.log` is absent (moved aside on `ocupilot-ci`, restored after) -> `LogTailWire` alerts leg at "alerts: the page supplies a cursor" (run 689); the unmutated tree green on the same instance (run 690), the file it created removed again
- (QA) mutation: `livePath` added to the `systemmonitor` source -> survived (equivalent: `canLive` already excludes every windowed source, so no source is offered the tail by `livePath` alone)
- (QA) files: `src/OcuPilot/Test/LogTailWire.cls` changed (`EnsureAlertLine`, `OnAfterAllTests`, `AwaitQuiet`, four holds); no test file created. Final tree: `LogTailWire` 4 (run 694); browser `messages-log` 5/5 and `alerts-log` 7/7 on the rebuilt, redeployed bundle.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** `messages` and `alerts` opt into a live tail (`LogSourcePort.TAILSOURCES`, `Tail`, `TailState` and the three timing seams); `GET /logs/<source>/tail` is held up to the gateway-derived bound with a heartbeat newline each 10 s (`Api/Response.Heartbeat`: JSON type, compression off, flushing on, then newline and flush) before one `{source, changed}` envelope; the log viewer's Live tail toggle chains the polls (no timer) and reads each change through the page route. The agent gets no tool. Task 0's measurements are under Design Notes; the lead's answer (a dropped socket waits out the bound; the cursor is required whole; AD-12 names the two flush properties) is in the Spec Change Log.

**Files.** Port: `Port/LogSourcePort.cls` (tail seams, `Tail`, `TailState`). API: `Api/Response.cls` (`Heartbeat`), `Api/LogPage.cls` (`HandleTail`), `Api/Router.cls` (two routes, two thin targets). Descriptors: `LogMessageViewer.cls`, `LogAlertViewer.cls` (the no-auto-refresh sentence). Client: `log-viewer.store.ts` (`livePath`, `canLive`, `setLive`, the chained loop), `log-viewer.page.ts` (toggle), `strings.ts` (+1), `_components.scss` (toggle row). Tests: `Test/LogTail.cls`, `LogTailWire.cls`, `ResponseProbe.cls` (new), `LogSourceFixture.cls`, `LogSourceDenial.cls`, `Envelope.cls`, `EndpointCoverage.cls`, `Descriptor.cls`, `log-viewer.spec.ts`, `messages-log.browser-spec.mjs`. Planning: `EXPERIENCE.md` :379 in place.

**Review.** Two layers, 26 findings: 3 medium, 19 low, 4 false (rows under Review Triage Log). Patched: the held-cursor wire test now binds the heartbeat newlines and the bound's floor; the cursor-behind wire test covers the alerts route; the absent-file leg asserts an absent look; `Tail` has its own `LOG.FILE` sentence; five mutation lines recorded. Rejected: the remaining lows (reasons in the log) and four false claims. Deferred: the two first-pass entries stand (the dropped-client hold is now the accepted consequence); nothing new.

**Follow-up review: recommended** (two medium entries patched). Unverified until CI: the new wire assertions assume `messages.log` stays still for one beat interval in one of three holds, and the alerts leg assumes an `alerts.log` on a fresh shard throwaway (a fresh one carries a few lines).

**Verified** on `ocupilot-ci` (results and mutations under Verification): `LogTail` 11, `LogTailWire` 4, `LogSource` 22 after the patches; every other class and the client tiers are from the implement pass over unchanged code; `check-objectscript` 0 problems. The throwaway holds no probe leftovers; the rotated log Task 0 made was removed.

**Residual risk.** A dropped client holds one CSP process to the bound (deferred, accepted); no automated test sees a beat arrive on time (deferred).
