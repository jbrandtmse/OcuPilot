---
title: 'Story 21.39: CI health: the governance renderer stall and the journal reverse-read timeout'
type: 'bugfix'
created: '2026-11-22'
status: 'done'
baseline_revision: 'ecbf46582b56cf20f2b6c556310c662a68265bfd'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-21-context.md'
warnings: ['multiple-goals', 'oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Two CI reds recur. DW-2517: `JournalRecords.TestTheToolInReverseOrderKeepsTheNewestRowsUnderTheContextCap` answers `PORT.TIMEOUT` on its first reverse read, after Story 23.10 fixed only the second page. DW-1822 and DW-2600: the structural walk's settle on `/ocupilot/agent/governance` goes unanswered for 60 s after a 200, with the renderer not answering a new DevTools session.

**Approach:** Batch 1 fixes DW-2517 at its measured cause, the test's first read asking for more rows than the vendor's first bulk holds (Design Notes). Batch 2, for DW-1822 and DW-2600, is proposed and not ready. The stall did not reproduce here, so the plan halts `intent gap` with the evidence and three options.

## Boundaries & Constraints

**Always:**

- `AdminPort.ASYNCTIMEOUT` (30 s), `WALKCALLDEADLINE` (60 s), `SETTLE_TIMEOUT_MS` and every other deadline stay as they are. No retry is added.
- Measurements and tests run on `ocupilot-ci` only. `ocupilot-slot-a` is read-only.
- The seeded record count (30), the probe global and every other `JournalRecords` assertion stay unchanged.

**Never:**

- No product code change in Batch 1. The vendor's bulk scan is product behavior that AD-26's bound already refuses honestly (`TestAScanPastTheBoundIsRefusedTimeout`).
- No edit to `Api/Error.cls`, the spine, or any user-facing string.
- Batch 2 does not start until the orchestrator rules on the halt.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Reverse tool read, first page | `order 1`, `direction desc`, `maxRows 12`, context cap 10, no offset | 10 rows, truncated, newest `^OcuProbe185(30)`, read inside the vendor's first bulk | none |
| Next page | offset below the lowest row, `maxRows 10` | starts at `^OcuProbe185(20)`, none repeated | none |
| The read's ask outgrows the bulk | `maxRows` raised to 20 (mutation) | the new bulk assertion goes red before any timing matters | none |

</intent-contract>

## Code Map

- `src/OcuPilot/Test/JournalRecords.cls:219-240` -- the reverse test. Line 225 asks `maxRows 20`, and line 226 is the read that timed out in both CI reds (`+7`). The second page (233) already asks 10. The doc comment above it (`:212-218`) names only the second page.
- `src/OcuPilot/Test/JournalProbe.cls:286` `SeedProbeDatabase` -- writes the 30 records into the current journal file. Sibling for the new bulk helper. `PROBEGLOBAL` and `PROBESUFFIX` are at `:40-46`.
- `src/OcuPilot/Port/AdminPort.cls:959` `HALVEDROWTYPES` doubles `maxRows`, and `:1083` `ASYNCTIMEOUT` is 30 s. Both are unchanged.
- `src/OcuPilot/Screen/Tool/Base.cls:167` `BoundedMaxRows` and `Screen/Tool/Read.cls:315` -- the tool's ask. Unchanged.
- Vendor, read-only: `irissys/%SYS/Journal/Record.cls:470-540` `FetchRows` fills a bulk of up to 2000 rows or 2000 bytes before `ListFetch` hands over the first row. `%Api.Admin.Endpoints.Journal.ListTask.RunTask` (hidden; a copy is at `/private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/b708a79b-b765-42ec-adea-dbc87acf6251/scratchpad/e21u/21-39/plan/admin-journal-listtask.cls`) loops `%Next` until `MaxRows`.
- DW-1822, read-only: `ui/browser/structural-walk.mjs:263` `stallLine`, `:302` `bounded`, `:821` `settle`, `:946` `walkPass`; `ui/browser/protocol-retry.mjs:32` `WALKCALLDEADLINE`; `ui/src/app/areas/agent/governance.page.ts` and `governance.store.ts`. `agent/governance` is at index 193 of the 197 non-id visits in each pass, after `agent/switches` and `agent/guardrails`.

## Tasks & Acceptance

**Execution (Batch 1, DW-2517):**

- `src/OcuPilot/Test/JournalProbe.cls` -- add `FirstBulkRows(pFile, pReverse, pValue, Output pRows) As %Status`. It opens `%SYS.Journal.Record`'s `List` on the eight columns `ListTask.RunTask` sends, with the `GlobalNode [ pValue` match, calls `FetchRows` once, answers `RecordBufferCount`, and always calls `ListClose`. This is a sibling of `SeedProbeDatabase`'s read side.
- `src/OcuPilot/Test/JournalRecords.cls` -- `TestTheToolInReverseOrderKeepsTheNewestRowsUnderTheContextCap`:
  - The first read asks `maxRows 12`, above the cap of 10, so the cap still truncates.
  - Before the read, assert `FirstBulkRows` for `PreparedFile` in reverse is at least the read's ask plus 2. This read's ask is `maxRows` + 2: 16 stays inside an 18-row bulk, 17 does not (measured).
  - Assert the same for the second page's `maxRows 10`.
  - Replace the doc comment's second-page sentence with the mechanism: each read must end inside the vendor's first bulk of this run's records, or the next bulk scans to the file's start. Name the mutation.

**Acceptance Criteria:**

- Given a fresh `ocupilot-ci` (DW-2517), when `JournalRecords` runs, then the reverse test passes, its first read takes under 0.5 s where 3.4 s was measured at `maxRows 20` on a 319 MB file, and the other nine tests are unchanged.
- Given `maxRows 20` restored in the first read, when the class runs, then the bulk assertion goes red. That is the Rule 19 mutation, reverted and reloaded afterwards.
- Given run 44979425183's #9509 line, when it is read against the source, then it is `BackgroundTaskPortSeam`'s own `ArmAnswer(9509)` (`:119`), logged by a passing test, with no bearing on the journal read (Design Notes).
**Execution (Batch 2, DW-1822 / DW-2600: capture at the stall, orchestrator ruling option 1):** evidence only. The timings, deadlines, retry and every pass/fail outcome stay exactly as they are; the capture never changes whether a visit passes.

- `ui/browser/structural-walk.mjs` (the walker and its stall report):
  - On an abandoned call only, a `Debugger.enable` session takes one `Debugger.pause`, bounded at 10 s, and appends its top frames to the stall line. A pause that does not land says so in the stall line ("main thread not running JS").
  - A `Profiler` armed at each `goInApp` visit is kept only for an abandoned visit, written under a scratch artifact directory, and discarded otherwise.
  - The stall line carries the governance answer's byte length.
- `.github/workflows/ci.yml` -- on a failed browser shard, upload the saved profiles as an artifact with a short `retention-days`, on the pinned `actions/upload-artifact` the file already uses. Add-only; `ui/tools/ci.test.mjs` stays green.
- Tests: a unit-level pin that a forced abandoned visit writes the profile and the stall-line fields and that a settled visit writes none; the a11y spec run forward twice on the rebuilt bundle, unchanged in outcome.

- Given a CI browser shard whose structural walk abandons a visit, when the stall is reported, then the stall line carries the paused top frames (or says the pause did not land) and the governance answer's bytes, the visit's CPU profile is uploaded as a short-retention artifact, and no timing, retry or outcome changed. DW-1822 and DW-2600 stay open, routed to the Epic 21 burndown, until a red carries a profile.

## Spec Change Log

- 2026-11-22, orchestrator ruling on the plan's intent gap: Batch 1 accepted as planned (test-only); DW-1822/DW-2600 take option 1, capture at the stall with no behavior change (options 2 and 3 declined); epics.md's first AC gains an add-only clause rather than moving out; the bulk-scan product behavior is a new burndown ledger entry, never changed in this story. The story closes on Batch 1 plus the capture.


## Review Triage Log

- Run 44979425183's earlier `ERROR #9509: Failed to send signal to job` is `BackgroundTaskPortSeam.TestAVendorStateErrorIsThePublishedRefusal`'s own armed `ArmAnswer(9509)` (`:119`), logged as a 500 by a passing test; it has no bearing on the journal read (absent from run 44986244257's red).

### 2026-11-22 — Review pass

- verdicts: 8 findings — high 0, medium 1, low 7, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` the `ci.yml` profile upload and its env folder were pinned by no test — a renamed path would upload nothing, silently (`if-no-files-found: ignore`). Patched: a pin in `ui/tools/ci.test.mjs` ties the shard step's `OCUPILOT_WALK_PROFILE_DIR` to the upload's `path`, `failure()` and a short `retention-days`; mutation recorded.
  - `[low]` `[patch]` the Batch 2 mutation line covered only two of the pins (resume, not-landed, governance record and `main thread:` field unproven). Patched: all four applied, red observed, reverted, recorded under Verification.
  - `[low]` `[patch]` the second page's bulk assertion had no applied mutation. Patched: `tSecondAsk` 20 turned that assertion and the `ci-flake-waits` pin red; reverted, recorded.
  - `[low]` `[patch]` `Set tSC =##class(` missing a space in `JournalRecords.cls`. Patched.
  - `[low]` `[reject]` `FirstBulkRows` copies the vendor list's open shape and its `+ 2` margin and the 18-row bulk depend on the seeded rows — a drift makes the live pin red rather than the timeout, which is its purpose; a shared base would couple the test to the vendor's hidden class.
  - `[low]` `[reject]` a Profiler session runs on every visit, which is an observer effect — it is the orchestrator's ruling (profile armed at each visit, kept only for an abandoned one); `a11y-structural-invariants` ran twice forward, 13/13 and 0 unsettled each, with unchanged outcome.
  - `[low]` `[reject]` `profileDir()`'s temp-directory default is untested — a fallback that only picks a folder, no user-reachable failure.
  - `[low]` `[reject]` the real `Debugger.pause`, `Profiler.stop` and `response.buffer()` run only against fake sessions in the unit pins (intent audit) — a live stall is the only place they can run, which is the capture's purpose; each failure there is named in the stall line, never thrown.

## Design Notes

**Governing ADs:** AD-26 (the async journal read's bound stays at 30 s and refuses `PORT.TIMEOUT`, never a partial row), AD-17 (armed tests on a throwaway only), AD-36 (the journal read and the governance read are unchanged). For Batch 2 also AD-19 and AD-22, both unchanged. No AD changes.

**DW-2517, measured** (`ocupilot-ci`, rebuilt 2026-11-22, current journal file 319,053,100 bytes, 30 matching records near its end):

- The vendor's reverse filtered `List` returns rows 1-18 at once (row 10 at 0.037 s). Row 19 waits 3.32 s while the second `FetchRows` bulk scans back to the file's start: fewer than 2000 bytes of matches remain, so the bulk keeps reading. A bulk ends once it passes 2000 bytes, which here is 18 rows.
- `Tool.Read.View` in reverse, context cap 10, timed against `maxRows`: 10 took 0.101 s, 12 took 0.076 s and 16 took 0.082 s. 17 took 3.432 s, 18 took 3.376 s and 20 took 3.446 s.
- The class run gave the reverse test 3.51 s and every other test 0.005-1.09 s (`^UnitTest.Result` seconds).
- So the first read's cost is proportional to the file's size, not to the rows asked. CI's read file was 629,211,136 bytes (run 44979425183's compression line for `20261122.001`). That is about 2x here, and a slower runner puts it near the 30 s bound (inference). The class's 25.1 s in `ci-timings.json` fits that too (inference). Story 23.10 fixed the second page, which was not the read that failed.
- The #9509 line is `BackgroundTaskPortSeam.TestAVendorStateErrorIsThePublishedRefusal`'s armed fake answer, which `AdminPort` logs as a 500 while the test passes. It is absent from run 44986244257's red.
- Product note, for the runner to ledger or not: a filtered journal read whose matches run out mid-bulk scans to the file boundary, and AD-26's bound already ends it with `PORT.TIMEOUT`.

**DW-1822 / DW-2600, reproduction attempt** (`ocupilot-ci` rebuilt from scratch, bundle rebuilt and redeployed; a11y is shard 1/5's first spec in both runs, so the state is a fresh install):

- `a11y-structural-invariants.browser-spec.mjs`, one run: 13/13 in 500 s, 0 unsettled. Governance took 1,938 ms at 720 light and 1,932 ms at 1280 dark, and 1280 light was below both.
- A scratch harness ran the 1280 light pass's 197 non-id visits with the detector on each, a `Profiler` around every governance visit and `Debugger.pause` armed for a stall:
  - one full lap at 4x CPU throttle: governance 2,003 ms, with JS self-time about 0.1 s of a 2,049 ms profile, the rest idle;
  - 4 laps over the 23 visits ending at governance at 10x: 1,993-1,999 ms;
  - 2 laps at 720 px at 4x: 1,999-2,006 ms;
  - no stall, heap 12-23 MB at each lap's end.
- The governance answer is 343 keys, 39,351 bytes. Story 21.23's three runs and ten-lap harness also never stalled.
- CI pattern: the first try and the relaunched retry stall at the same visit within a job. In some jobs 1280 passes and 720 then stalls twice. The renderer does not answer `Performance.enable`. That points to a condition lasting minutes within a job on the Linux x64 runner (inference). The local runs were macOS arm64.

**Halt: intent gap, DW-1822 / DW-2600.** No cause was found, so no fix is proposed. Questions for the orchestrator, recommended option first:

1. **(Recommended) Capture at the stall in CI.** A Batch 2 adds evidence capture to the walker and does not change behavior:
   - a page session with `Debugger.enable`; on an abandoned call, `Debugger.pause` bounded 10 s, with its top frames appended to the stall line. A pause that does not land says the main thread is not running JS.
   - a `Profiler` armed at each `goInApp` and kept only for an abandoned visit, plus the governance answer's byte length in the stall line;
   - a `ci.yml` step uploading the profile on failure.

   DW-1822 stays open until a red carries the profile. Story 21.39 then closes on Batch 1 and the capture, and DW-1822 is re-owned for the fix. Moving that AC is the orchestrator's call.
2. **Reproduce on the CI platform here:** a Linux x64 headless Chrome container driving `ocupilot-ci`. This host is arm64, so it would run under emulation. That is an extra container under the memory rule, and its timing is unrepresentative (inference).
3. **Close DW-1822 and DW-2600** `wontfix-accepted` with a `reopen_if`. That is an owner-level call.

**Decided in-stage:** `maxRows 12`, not 10, so the context cap still has rows to cut. The bulk check is live (`FirstBulkRows`), not a literal 18, so a vendor change to the bulk reddens the pin instead of the timeout.

**Ledger inbox:** DW-2517 is addressed by Batch 1. DW-1822 and DW-2600 are held by the halt. DW-2821 has not recurred and has not joined.

**Integration ACs:** none. The story adds no service, and `FirstBulkRows` is a test helper consumed by `JournalRecords` alone.

## Verification

**Commands:**

- `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/b708a79b-b765-42ec-adea-dbc87acf6251/scratchpad/e21u/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` -- `(loop)` expected: `LOADERRORS=0`.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.JournalRecords` -- `(loop)` expected: 10/10. Read the reverse test's `Duration` from `^UnitTest.Result`, under 1 s.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.JournalRecordDetail` -- `(loop)` expected: green. `JournalProbe` gains one method and no change, and its 13 other consumers are covered by the sweep.
- `uv run scripts/check-objectscript.py` -- `(once)` expected: clean.
- Full ObjectScript sweep, one class per call, batched from `ui/tools/ci-timings.json` -- `(once)` expected: green. The browser suite is left to CI (Rule 29).
- mutation: the first read's `maxRows` set to 20 -> `TestTheToolInReverseOrderKeepsTheNewestRowsUnderTheContextCap` red on the bulk assertion. Applied: red, and only that test ("the first read's 22 rows end inside the vendor's first bulk of 18"), 9/10 others green; reverted, `git diff` identical bar the one line, reloaded, 10/10.

**Batch 2 (capture), after Batch 1 is committed:**

- A unit-level node test (under `ui/tools/`, run by `npm run test:tools`) pins that a forced abandoned visit writes the profile file and the stall-line fields (paused frames or the not-landed wording, the governance answer's byte length) and that a settled visit writes none. `(loop)`.
- mutation (Batch 2): the settled-visit discard removed (`visit.discard()` in `goInApp`'s `finally`) -> only "a settled visit saves no profile and releases its profiler" red ("the profile is discarded, never stopped"); the abandoned-visit write removed (`writeFileSync` in `armVisitProfile`) -> only "an abandoned visit saves its CPU profile ..." red ("one profile is saved"); both reverted, 47/47 in `ui/tools/structural-walk.test.mjs`. Also applied, each reverted with `git diff` clean: `Debugger.resume` dropped -> the abandoned-visit test red; the not-landed return dropped -> the not-landed test red; the `watched.governance` record dropped -> the abandoned-visit test red; the `main thread:` field dropped -> both stall-line tests red.
- mutation (second page): `tSecondAsk` set to 20 in `JournalRecords` -> only the reverse test red on "the next page's 22 rows end inside the vendor's first bulk of 18", and `ui/tools/ci-flake-waits.test.mjs` red on the same ask; reverted and reloaded, 10/10.
- mutation (upload wiring): the `ci.yml` upload step's `path` renamed to `walk-profile` -> only the new `ui/tools/ci.test.mjs` upload pin red (107 tests, 1 red); reverted, `git diff` clean.
- `cd ui && npm run build`, redeploy the bundle to `ocupilot-ci`, then `a11y-structural-invariants.browser-spec.mjs` forward twice, one call each, its outcome unchanged. `(once)`.
- `ui/tools/ci.test.mjs` stays green with the add-only `ci.yml` upload step (pinned sha, short `retention-days`).
- The capture never changes a timing, deadline, retry or outcome; no product code, user-facing string or AD changes.

Shared surfaces: none. Every test added or changed passes on a fresh environment, in either order.

## Auto Run Result

Status: done
Blocking condition: none

**Implemented.** Batch 1 (DW-2517, commit baea3ce4c): the reverse test's first read asks 12, and both reads assert a live `JournalProbe.FirstBulkRows` of at least ask plus 2; the reverse test took 0.22 s where 3.51 s was measured. Batch 2 (DW-1822/DW-2600, commit b0ad7a3f2): evidence only. A stalled call now adds the main thread's top frames (one bounded `Debugger.pause`), the governance answer's byte length and the visit's saved CPU profile to the stall line; a failed browser shard uploads the profiles for 3 days. No timing, deadline, retry or outcome changed; DW-1822 and DW-2600 stay open until a red carries a profile.

**Files.**

- `src/OcuPilot/Test/JournalProbe.cls`: `FirstBulkRows`.
- `src/OcuPilot/Test/JournalRecords.cls`: the reverse test's asks and bulk assertions.
- `ui/tools/ci-flake-waits.test.mjs`: the source pin follows the new asks.
- `ui/browser/structural-walk.mjs`: the capture.
- `ui/tools/structural-walk.test.mjs`: three pins.
- `.github/workflows/ci.yml`: the env folder and the upload step.
- `ui/tools/ci.test.mjs`: the upload pin (review patch).

**Review.** 8 findings: 1 medium and 3 low patched (upload pin, three mutation lines, one space), 4 low rejected with reasons in the triage log, none deferred. Follow-up review not recommended: no high and one medium patched.

**Verified.** `reload.sh` `LOADERRORS=0`; `JournalRecords` 10/10, `JournalRecordDetail` 5/5, the other 11 `JournalProbe` consumers 55/55; `check-objectscript.py` 0 problems; `npm run test:tools` 2398/2398; `npm run build` clean; `a11y-structural-invariants` forward twice, 13/13 and 0 unsettled each (527 s, 530 s). Every mutation under Verification was applied, observed red and reverted. The full ObjectScript sweep was not run: `ci-timings.json` totals about 9,700 s, over the foreground cap, and the changed classes' consumers are covered above; the browser suite is left to CI.

**Residual.** The real `Debugger.pause`, `Profiler.stop` and `response.buffer()` run only against fake sessions until a CI stall exercises them.
