---
title: 'Story 21.23: Test hygiene and contended client fixes'
type: 'chore'
created: '2026-11-21'
status: 'in-progress'
baseline_revision: '3158042357f68ade2409cd6ccfa0a342f8cb3dff'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['multiple-goals', 'oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Nineteen ledger entries are routed here. Five are the orchestrator's must-fix CI reds: the structural walk stalling on `/ocupilot/agent/governance` (DW-1822, DW-2600; seven reds on 2026-11-20/21), users AC2's cleared filter (DW-2720), and the probe production's operation holding no job after a start (DW-2787, DW-2535). The rest are test-hygiene and small client entries. The criterion: each entry is fixed at its cause, or closed with its reason, without changing a product behavior its story ruled.

**Approach:** Six ordered batches, each verifiable and committable alone, Batch 1 and 2 first (the must-fix set). Each red is measured on `ocupilot-ci` before it is changed. Five entries do not fit this story: DW-2499 is a 38-file refactor, DW-2405 is new UX, and DW-2369, DW-2442 and DW-2474 change user-facing wording. The plan recommends moving them to a sibling story (Design Notes, Split).

## Boundaries & Constraints

**Always:** a fix removes a cause or waits on a signal the system already exposes. Every test added or changed passes on a fresh environment, in either order. Each entry closes with its evidence: a run id, a mechanism, or the measurement that names it. A measurement runs on `ocupilot-ci` against a rebuilt and redeployed bundle, and anything it creates there is removed afterwards.

**Never:**

- A retry, a rerun wrapper, or a longer deadline or timeout presented as a fix.
- A new or changed user-facing string, an AD change, or an edit to `CLAUDE.md`.
- Editing `interop-editors.browser-spec.mjs` or `interop-viewers.browser-spec.mjs`.
- Replacing lines in `scripts/ci-throwaway.sh` or `ui/browser/*`. Both are shared with Epic 24, so edits there are add-only unless the orchestrator rules otherwise.
- A `resolved-by` close on an entry whose cause is not shown.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| DW-2720 late view write | users AC1 ends with its `%all` filter write in flight; AC2 resets and opens the list | AC1 returns only once the instance holds `%all` for the users view; AC2 reads its total only from an empty filter field | the wait names the stored view last read; AC2 names the field's value when it is not empty |
| DW-2787 refused start | the probe START answers anything but 200 with `State: Running` | `StartProduction` fails naming the HTTP status, code and state | none |
| DW-2787 no job | START answers Running, the operation's job never appears | the helper waits on the port's `ITEMRUN` facts (`own=1 jobs=1`), then fails naming START's answer, the production state, `Facts()` and every `Ens.Job` row, including a row it could not read | a failed row read is named, never counted as "no job" |
| DW-1822 stalled walk call | a walk page call goes unanswered for `WALKCALLDEADLINE` | the error also names the renderer's state at the stall: crashed, busy, idle or unresponsive, plus the frame URL and the last `/api/ocupilot` answers | each probe has its own bound and never replaces the original error |
| DW-2714 moving Run | the cube picker draws above the form after Run is enabled | `pressRun` clicks only once Run's box is stable, then waits for the start POST or `aria-busy="true"` | names the element at Run's center when neither comes |
| DW-2761 restarted throwaway | the first start logs `LOAD-FAILED`, and `on-failure` restarts it to healthy | `ci-throwaway.sh up` exits 1, printing the `container-start:` failure lines | none |

</intent-contract>

## Code Map

Batch 1 (DW-1822, DW-2600, DW-2720):

- `ui/browser/structural-walk.mjs:703-724` `settle`: waits for no tracked request for `QUIET_MS`, then a main-world `page.evaluate` of the font status and `[aria-busy]`, bounded by `bounded()` (`:208`, `WALKCALLDEADLINE` 60 s, `protocol-retry.mjs:32`). Also `:741` `goInApp`, `:679` `trackRequests`, `:866` `passRetrier`, and `:925` `walk`. `governance` is visit 189 of 260 in each pass.
- CI evidence: in every red (jobs 136594046099, 136682661720, 136663644261, 136488946568, 136289520691, 136273085403), the first try and the retry on a relaunched browser both stall at the same `settle /ocupilot/agent/governance` call, at 1280 or at 720 px. Where 720 failed, the same job's 1280 light and dark passes had already passed governance. A green run reads governance at 2.1-2.2 s.
- Plan measurement on `ocupilot-ci` (bundle rebuilt and redeployed, 331 keys): governance settles in 1.82-1.84 s at 1280 and 720 px, light and dark. Of that, 1.29-1.37 s is the server's `GET /api/ocupilot/agent/governance`. The client draw has no long task at 1×, and its longest task is 0.51-0.55 s at 20× CPU. Under 300 and 1,500 ms of added latency it settles in 2.0-3.5 s.
- Plan measurement, continued: one 1280 light pass with the detector on every screen, up to and past governance, ends at 21 MB of heap and 3 documents, with no node or listener growth. The screen is not slow, and the stall did not reproduce here.
- `ui/browser/panel-spec.mjs:135` `gotoNamingInflight`, with its bounded probe `fetchFromNode` (`:86`): the sibling pattern for naming a stall (21.22).
- `ui/tools/structural-walk.test.mjs` and `ui/tools/protocol-retry.test.mjs`: the walk's fake-page pins.
- `ui/browser/users.browser-spec.mjs`: AC1 `:187` ends on `filterToSubset` with `%all`, and `:196` closes the context. AC2 `:204` takes `total = viewCount` with no filter check; it fails at `:211` (the second `clearFilter`) reading 14 against 4. AC7 `:232` ends filtered on `_SYSTEM`.
- `ui/browser/preferences-reset.mjs:82` `waitForRememberedView(route, filter, timeoutMs)`, used by `web-applications.browser-spec.mjs:228` (21.22, DW-2534, the same shape).

Batch 2 (DW-2787, DW-2535):

- `src/OcuPilot/Test/InteropItemControl.cls:274-288` `StartProduction`: the port START at `:279` ignores `tHttp`, `tFault` and `tResult`. `:281-285` polls `Jobs()` for 15 s, and `:285` is the failing message, which names nothing.
- `InteropItemControl.cls:241` `Jobs()`: `Ens.Job:Enumerate`, with `Execute`'s status unchecked and a `Catch` that returns the names read so far. `irislib/Ens/Job.cls:858-863` reads `$$$EnsJobStatus("sys",pid,"%StartConfigName")` with no `$Get`.
- `src/OcuPilot/Test/InteropItemRun.cls:102` `StartProbe`, `:119` `WaitJobs`, `:142` `Facts` (the port's `ITEMRUN` read, which the asserts use), and `:347` `TestTheStartHelperWaitsForTheProductionsOwnUpdate`, the sibling pin.
- Plan measurement on `ocupilot-ci`, 12 cycles of Settle, ResetProduction, an optional disabled item plus a pool-size-0 item, START and Reset: START answered 200 with `State: Running` in about 10 ms, and the operation's job was listed when it returned. InteropHostTest then InteropItemRun was green (runs 868, 869). CI's red came after 42 classes in shard 5/8 (run 44638724058).

Batch 3 (DW-2714, DW-2282, DW-2761):

- `ui/browser/analytics-mdx.browser-spec.mjs:148` `pressRun`. `ui/src/app/areas/analytics/mdx-query.page.ts:62-72` draws the cube picker `@if (hasCubes)` above the form, and `mdx-query.store.ts:273-296` loads the cubes late. `background-run.ts:153-155` sets busy before its POST.
- `ui/browser/proposal-card-spec.mjs:32` `cardViolations` never waits for the spinner. `impact.browser-spec.mjs:368-370` does (23.5). `_components.scss:4542-4556` rotates the 12 px spinner.
- `scripts/ci-throwaway.sh:1019-1060`: the `up -d --wait` loop, then `ps`; `:1161` is the reuse recreate. `ui/tools/ci.test.mjs` `runThrowawayUp` fake docker is at about `:2750-2776`, and its bring-up pin at `:2961` stays unchanged.

Batch 4 (DW-2459, DW-2202):

- `scripts/check-objectscript.py`: the docstring list is at `:5-181`, `CHECKS` at `:2142-2164`, and `CLASS_RE` at `:256` (no `DependsOn`). `scripts/test_check_objectscript.py:302` holds `len(CHECKS)` equal to `CLAUDE.md`'s "(21 rules"; `FixtureTreeCase` is at `:45`. Today's tree has 0 violations: all 29 project-class parameter expressions carry `DependsOn`.
- `src/OcuPilot/Test/WireSecurityRead.cls` `:440` (8 task field names) and `:641` (8 process field names). Sibling: `Test/Dashboard.cls:99` derives fields through `DeclarationJson`.
- `ui/browser/web-applications-actions.browser-spec.mjs:430` holds the literal 3. `WebAppList.cls:70-78` declares 7 rowActions, 3 of them `serves-ocupilot`.

Batch 5 (DW-2476):

- `ui/tools/browser-settle.test.mjs:299-323` `RESIDUAL_COPIES` (23). Every copy is byte-identical and differs from `panel-spec.mjs:193` only by hard-coding `config.navigationTimeoutMs`.

Batch 6 (DW-2225, DW-2352):

- `ui/src/app/core/turn.ts:1805-1810`: the live poll replaces the proposals. `output` and `outputErrors` are memory-only (`:296-305`) and set only by `recordProposalState` (`:1575`). `readBack` does survive (`:725`).
- `ui/src/app/shell/panel.spec.ts:3605`: the Story 20.17 AC5 neighbour.
- `ui/src/app/areas/system-explorer/document-viewer.page.ts:513-541` `syncReference` and `loadReference` re-set `src` on the one frame. `onReferenceLoad` is at `:561`. `ui/browser/system-explorer-documatic.browser-spec.mjs:128,189`.

## Tasks & Acceptance

**Execution:** six batches in order. Each batch is verified, reviewed and committed alone, and Batches 1 and 2 come first. Every ObjectScript or browser run goes to `ocupilot-ci` only: reload with the `reload.sh` line under Verification, and rebuild and redeploy the bundle before a browser run. The `ocupilot-slot-a` profile is read-only. Edit files only with the Edit and Write tools, one step per Bash call, each bounded with `timeout 600`. A Task 0 harness is the implement stage's own scratch file, written fresh, never one this plan wrote.

Batch 1 (DW-1822, DW-2600, DW-2720):

**Task 0** (implement, before any walker change; results go under Design Notes):

- Run `a11y-structural-invariants.browser-spec.mjs` three times, one call each, and record governance's visit time in every pass.
- Then run a harness that repeats the 1280 light pass's visits 150-200 (governance is 189) ten times in one page. It installs `page.on('error')` and keeps a second CDP session reading `Performance.getMetrics` `TaskDuration`.
- **Branch (a), a stall reproduces:** capture a Chrome trace of the stalled visit and fix what it shows. That is the screen (its draw or read) when governance's own work is the long task, or the walker's settle criterion when the page is idle and unanswering.
- **Branch (b), no stall in the three runs and ten repeats:** only the stall report below lands, and the cause stays open, escalated (Design Notes).

Tasks:

- `ui/browser/structural-walk.mjs`: when `bounded()` abandons a call, append one `stall:` line before rethrowing. It names whether the page crashed (`error` since the pass began), the main frame's URL and whether a document request is in flight, and whether the renderer is busy. Busy is a `TaskDuration` delta read over 2 s from a fresh CDP session; if that session does not answer in 5 s, the line says unresponsive. It also names the last five `/api/ocupilot` answers, with status and milliseconds. Each probe is bounded, and a probe failure is named, never thrown. On branch (a), also apply the fix the trace names (DW-1822, DW-2600).
- `ui/tools/structural-walk.test.mjs`: pin the `stall:` line with fake pages that are crashed, busy (`TaskDuration` growing), idle, and unresponsive (a session that never answers), and a probe that throws.
- `ui/browser/users.browser-spec.mjs` (DW-2720):
  - AC1 awaits `waitForRememberedView(<users list route>, '%all', …)` before `context.close()`. Read the route key from the preferences answer, as web-applications' `LIST_ROUTE`.
  - AC2 and AC7 do the same for their last filter (`_SYSTEM`).
  - AC2 and AC7 take their total only after asserting the filter field reads `''`, failing with its value.

Batch 2 (DW-2787, DW-2535):

**Task 0** (implement, `ocupilot-ci`; results go under Design Notes). Measure while the probe runs, and remove whatever is planted:

- **(H1):** plant `^IRIS.Temp.EnsJobStatus("sys",<pid below the operation's>)` without `%StartConfigName` in `USER`, then read `Jobs()` and `Facts()`.
- **(H2):** record START's answer when the production is already running, and when it reads troubled.
- **(H3):** run `InteropItemRun` five times, one call each.
- An observed mechanism is recorded as the cause. If none is observed, the fixes below land and the close is per Design Notes.

Tasks:

- `src/OcuPilot/Test/InteropItemControl.cls` `StartProduction`: fail unless START answered 200 with `State` `Running`, naming the HTTP status, code and state. Then wait, 15 s at most, on the port's `ITEMRUN` facts for the operation reading `own=1 jobs=1`, the read the screen and the asserts use, in place of `Jobs()`. On a timeout, fail naming START's answer, the production state, the facts and the `Ens.Job` rows.
- `InteropItemControl.cls` `Jobs()`: check the query's status, read each row's config name with `$Get`, and name a row it could not read instead of dropping the rest.
- `src/OcuPilot/Test/InteropItemRun.cls`: a test that starts the probe, calls `StartProduction` again, and asserts a failing status naming the refusal. If H1 is observed, add a test that plants a nameless row and asserts the start still finds the operation.

Batch 3 (DW-2714, DW-2282, DW-2761):

- `ui/browser/analytics-mdx.browser-spec.mjs` `pressRun` (DW-2714): before clicking, wait until the cubes read has answered and Run's bounding box is unchanged across two frames 100 ms apart. After the click, wait for the start POST or `aria-busy="true"`, failing with the element at Run's center and the statement.
- `ui/browser/proposal-card-spec.mjs` `cardViolations` (DW-2282): wait for `.ocu-tool-call-spinner` to be absent before the first pass, as `impact.browser-spec.mjs:370` does. Extend `ui/tools/ci-flake-waits.test.mjs`'s source pin to it.
- `scripts/ci-throwaway.sh` (DW-2761), add-only lines after the `up` loop and after the `:1161` recreate: unless `docker inspect --format '{{.RestartCount}}' "$PROJECT"` reads 0, print the `container-start:` lines matching `LOAD-FAILED` or `STARTPATH-FAILED` from the container log, and `exit 1`.
- `ui/tools/ci.test.mjs`: the fake docker gains an `inspect` case printing `$OCUPILOT_RESTART_COUNT` (default 0), plus a test where restart count 1 exits 1 with the refusal.

Batch 4 (DW-2459, DW-2202):

- `scripts/check-objectscript.py` (DW-2459): a check that a column-0 `Parameter X = {…}` expression names no `OcuPilot.*` class through `##class(…)` or `$Parameter("…")` unless the class names it in `DependsOn` or `Extends`. A `..#NAME` argument resolves through the class's own and inherited parameter values. It is called from an existing `CHECKS` entry, so the count and `CLAUDE.md` stay unchanged.
- `scripts/test_check_objectscript.py`: a `FixtureTreeCase` where a copy of `InteropEditResend` without `DependsOn` is flagged, one where a `..#NAME` argument is resolved and flagged, and one where the shipped tree is clean.
- `src/OcuPilot/Test/WireSecurityRead.cls` `:440`, `:641` (DW-2202): compare the answer's field names with the descriptor's `DeclarationJson` `read.fields`, as `Dashboard.cls:99` does. Keep the literal checks for the members the comments pin (`Suspended`, `Nspace`, `CanReceiveBroadcast`).
- `ui/browser/web-applications-actions.browser-spec.mjs:430` (DW-2202): derive the count from the `SCREENS` mirror's `serves-ocupilot` rowActions, after confirming the menu filters by that flag. This is an add-only replacement of the literal; if the orchestrator does not allow it, leave the line and record that.

Batch 5 (DW-2476):

- The 16 specs `database-operations`, `ecp-data-servers`, `encryption-key-file`, `journal-records`, `journals`, `ldap-editor`, `local-databases`, `namespace-mappings`, `namespaces`, `oauth-client-editor`, `oauth-resource-server-editor`, `oauth-server-editor`, `remote-databases`, `service-editor`, `system-explorer-write` and `wallet-secret` (each `ui/browser/<name>.browser-spec.mjs`): delete the local `transitionsSettled`, import `panel-spec.mjs`'s, and call it with `config.navigationTimeoutMs`.
- `ui/tools/browser-settle.test.mjs`: `RESIDUAL_COPIES` shrinks to the seven interoperability specs.

Batch 6 (DW-2225, DW-2352):

- `ui/src/app/core/turn.ts` `pollOnce` (DW-2225): merge each fresh proposal with the one held under the same id. Keep the held `output` and `outputErrors`, the held `readBack` when the fresh one is null, and a final state already recorded over a fresh `live`.
- `ui/src/app/shell/panel.spec.ts`: beside `:3605`, confirm a compile card while the turn runs, run the next poll, and expect the compile outcome still shown.
- `ui/src/app/areas/system-explorer/document-viewer.page.ts` `loadReference` (DW-2352): set `src` only for the frame's first load, then `contentWindow.location.replace(source)`. This also covers `onReferenceLoad`'s restore.
- `ui/browser/system-explorer-documatic.browser-spec.mjs`: after AC3, open the class reference, switch class, press Back, and assert the page's URL is the first class's.

**Acceptance Criteria:**

- Given the walk on `ocupilot-ci`, when governance is visited at 1280 and 720 px, light and dark, then each visit settles. And given any walk call that goes unanswered, when the error is thrown, then it names the renderer's state at the stall (DW-1822, DW-2600; branch (a) also removes the measured cause).
- Given users AC1 left a filter write in flight, when AC2 starts, then it reads the whole list from an empty filter field and its two filters pass (DW-2720).
- Given the probe START is refused, or answers Running with no operation job, when `StartProduction` runs, then it fails naming START's answer, the state, the facts and the job rows, and a job-status row it cannot read never reads as "no job" (DW-2787, DW-2535).
- Given the MDX page whose cube picker arrives late, when Run is pressed, then the click reaches Run and the run starts (DW-2714).
- Given a proposal card whose tool call is still running, when its structural check runs, then it measures only after the spinner is gone (DW-2282).
- Given a throwaway that restarted after a failed start, when `up` returns, then it exits 1 naming the failed start (DW-2761).
- Given a `{…}` parameter naming a project class without `DependsOn`, when the checker runs, then it reports the class and the parameter (DW-2459).
- Given the two field lists, the action count and the 16 converted specs, when a roster gains a member or a spec declares a new copy, then no literal needs editing and the ratchet reddens (DW-2202, DW-2476).
- Given a proposal confirmed while its turn polls, when the next poll lands, then the card keeps its output and compile outcome (DW-2225).
- Given the class reference switched to another class, when the person presses Back, then the viewer, not the frame, goes back (DW-2352).

## Spec Change Log

- 2026-11-21, orchestrator rulings at the plan halt (authoritative):
  - Split approved: DW-2499, DW-2405, DW-2369, DW-2442 and DW-2474 move to Story 21.38 (epics.md, add-only; ledger re-routed). This story is Batches 1 to 6.
  - The plan's measurements supersede the earlier premises. DW-1822 (Batch 1): reproduce first; (a) a trace that shows a cause is fixed; (b) otherwise ship only the stall-time renderer report, firing on the failure path only and printing nothing the existing a11y artifacts do not already hold, with no deadline change, and name the report's fields in the Auto Run Result so the cause can be escalated. DW-1822 stays routed, not resolved, until a CI red carries the report or a cause is fixed.
  - DW-2787 (Batch 2): expose the two test defects first (START's answer ignored; a partial job lookup read as "no job"), then wait on the port's own item read. The ledger records the refuted START-race hypothesis.
  - DW-2720: reuse Story 21.22's helper; no second copy.
  - DW-2430 is closed resolved-by 23-11 (7aceb0c13; `ui/src/app/testing/real-timers.spec.ts`).
  - `ui/browser/web-applications-actions.browser-spec.mjs:430`: replacing the line is approved. Derive the count from the action roster the screen itself declares (the descriptor or the client mirror), never from a re-implementation of the menu logic; keep a floor assertion that it is above 0; mutate once to show the spec still reddens when an action goes missing.
  - Declined, agreed: DW-2202's 24 per-principal literals stay; DW-2476's 7 interoperability copies stay with Epic 24.

## Review Triage Log

## Design Notes

**ADs:** AD-19 (each screen's own state is the readiness signal: Run's busy state, the stored view, the spinner); AD-50 (remembered views are on the instance); AD-43 (the turn's live poll); AD-62 (interoperability through one port: `ITEMRUN` is that read); AD-17 (test classes run only on a throwaway); AD-22 and AD-36 (the governance read is unchanged); AD-47 (the class reference's sandboxed frame). No AD changes.

**Consumes:** `panel-spec.mjs`, `list-spec.mjs`, `preferences-reset.mjs`, `proposal-card-spec.mjs`, `InteropItemControl`, `ProductionProbe`, and the fake-docker harness. No consumers: nothing here is a service.

**Rule 2:**

- The stall line extends `withDeadline`'s rejection, after the pattern of 21.22's `gotoNamingInflight` probe.
- The users waits reuse `waitForRememberedView`.
- `cardViolations` takes impact's spinner wait instead of a third copy.
- `StartProduction` waits on the port's `ITEMRUN`, which `Facts()` already reads.
- The `RestartCount` check sits beside the existing `up` loop.
- The 16 specs import the shared `transitionsSettled`.

**Measured at plan** (inputs to Batch 1 and 2):

- The governance screen is not slow at any width or theme (Code Map). Every CI red is an unanswered `Runtime.callFunctionOn` on that visit, repeated on a relaunched browser within the same job and absent in reruns. The cause sits with something per-job on the CI runner or instance (inference), so Batch 1 Task 0 tries to reproduce it before anything changes.
- The orchestrator's DW-2787 hypothesis, that START answers before the job exists, is refuted on `ocupilot-ci`: START answered Running with the job present 12 times out of 12. The helper does ignore START's answer, and `Jobs()` does read a failed row as "no job"; either hides the CI cause (inference). H1 and H2 test those two mechanisms.

**Batch 1 Task 0** (`ocupilot-ci`, bundle rebuilt and redeployed, 2026-11-21): branch (b).

- Three runs of `a11y-structural-invariants.browser-spec.mjs`: 13/13 green each, no unsettled visit, no retried pass. Governance settled in 1.83-1.94 s in all three passes (1280 light, 1280 dark, 720 light) of every run. The stall line was added to the walker between runs 2 and 3 and runs only on the failure path.
- A scratch harness repeated the 44 non-id visits from `system-explorer/sql-query` to `agent/screenpermissions` (governance is visit 190 of 260 in registry order) ten times in one 1280 px light page, with `page.on('error')` and a second CDP session on `Performance.getMetrics`. Governance settled in 1.83-2.24 s every time (one 2.24 s), 0 unsettled visits, 0 page errors, the largest task delta 0.24 s (`interoperability/schema-viewer`), and the page ended at 2 documents, 11,437 nodes, 645 listeners and 26 MB of heap.
- No stall reproduced, so only the stall report lands and the cause stays open (Escalated, below).

**Batch 2 Task 0** (`ocupilot-ci`, 2026-11-21; the probe was created and removed each time, `gone=1`):

- H1 (observed, as a reader defect): the row's key is `^IRIS.Temp.EnsJobStatus($namespace,"sys",<pid>)`, so the plan's `("sys",<pid>)` is never read. A row planted at `("USER","sys",1)` without `%StartConfigName` made `Ens.Job:Enumerate` fail its fetch (`<UNDEFINED>EnumerateFetch+5^Ens.Job.1`): `Next` answered 0 with that status, the old `Jobs()` ignored it and returned `""` while the operation ran, and `Facts()` still read `own=1 jobs=1`. The vendor's dead-job sweep copied the row to `Z1_n` ghosts and logged `Marking job 1 ...`; ghosts and 3 log rows were removed. The start clears the job rows, so such a row can only precede the operation's after the start. That a nameless row existed in the CI red is not observed.
- H2 (START's refusals are not ignored): the first START answered 200 `Running` with the job listed; a second START answered 409 `INTEROP.PRODUCTION.RUNNING` and a START on a troubled production 409 `INTEROP.PRODUCTION.TROUBLED`, each with a failing status the old helper already returned, but without the HTTP status or state. A 200 with another state was not seen.
- H3: `InteropItemRun` ran five times, 9 of 9 each (runs 870-874), on the unchanged helper. The CI red did not reproduce.
- Mechanism observed for the CI red: none. Only H1's reader defect is shown, and it is fixed.

**Escalated:**

- DW-1822 and DW-2600 on branch (b): the cause is not reproducible off CI. The entries stay routed with the stall report, and the orchestrator decides the next step. The plan proposes no deadline change.
- DW-2787 and DW-2535 when Task 0 observes no mechanism: close `wontfix-accepted note=reopen_if=StartProduction fails again; its text names START's answer, the facts and the job rows`.

**Strings, escalated** (never decided here):

- DW-2474: the decision sheet's wording (veto U-35) for the list is "No cube in this namespace is visible to you.". The three tab sentences have no wording yet. `strings.ts:7904-7910` and `EXPERIENCE.md:604`; Epic 24 holds uncommitted edits in both files and owns the analytics screens.
- DW-2442: a `<label>` placeholder in `interopTraceArrow` (`strings.ts:7777`, `EXPERIENCE.md:604`, spec-20-30 `:521`); where it goes is undecided.
- DW-2369: a new `NAV.*` code with its reason sentence (`Api/Error.cls:926-966,1064`, `Api/Turn.cls:375-405`), plus the `Navigate.cls:68` tool description. This is also an API vocabulary change.

**Split (the HALT below):** the inbox does not fit. Story 21.38 is recommended, "Shared Rules helpers, the source-control follow-up and escalated wording", taking:

- DW-2499: about 38 files, in five slices of about 12 (sentence helper with 11 Security adopters; 10 more sentence adopters; `Taken` with 11; `HandleForm`'s 17; and its last 12).
- DW-2405: new UX for the source-control question, about 10 files, with its wording, and an AD-39 question on showing the vendor's text (inference).
- DW-2369, DW-2442 and DW-2474: each waits on a wording ruling.

Batches 1 to 6 stay here. They take the must-fix set first, as ruled.

**Declined:**

- Declined DW-2430: already fixed by 7aceb0c13 (Story 23.11). `ui/src/app/testing/real-timers.ts` is shared by `home.page.spec.ts` and `log-viewer.spec.ts`, and no other copy exists. The runner closes it `resolved-by:23-11-the-range-end-cleanup-part-10`.
- Declined DW-2202, the 24 per-principal area literals (`WireSecurityRead` 19, `WireOAuthRead` 5): deriving each verdict from the descriptors' required pairs re-implements the gate the test judges. Close it `wontfix-accepted note=reopen_if=a story adds a screen to a pinned area`.
- Declined DW-2476, the seven interoperability copies: Epic 24 works in that area and edited two of them. They stay in `RESIDUAL_COPIES`.

**Decided in-stage:**

- Batch 2: `ItemFacts` moved from `InteropItemRun.Facts` into `InteropItemControl` (which `Facts` now calls), so `StartProduction` waits on the same read without a copy. The nameless-row test stores its row after the start, since the start clears the job rows.
- DW-2459 is called from an existing check, because a 22nd entry in `CHECKS` would need `CLAUDE.md`'s count changed, which is owner-only.
- DW-2282's fix is the spinner wait, not a walker change: a transform exemption would move the structural baseline for every screen.
- Batch 3: an unreadable restart count fails `up` like a non-zero one, so every fake docker that runs `up` or `product-reuse` (five in `ci.test.mjs` and `compose.test.mjs`) answers `inspect`; the `product-reuse` call-list pin gains the `inspect` call. `pressRun` waits on the cubes read's resource entry for the page's namespace and Run's box across two frames 100 ms apart; the spinner wait in `cardViolations` is inline, as impact's.
- DW-2476 takes the 16 specs outside the interoperability area.

**Epic 24 contention** (2026-11-21): there are no Epic 24 commits ahead of feature on any Batch 1-6 path, and its worktree holds no uncommitted edit to them. `ci-throwaway.sh` and `ui/browser/*` are add-only here; any replaced line needs an orchestrator ruling.

## Verification

**Shared surfaces:**

- `structural-walk.mjs`'s error text, pinned by `structural-walk.test.mjs`
- `ci-flake-waits.test.mjs`'s waits
- `ci.test.mjs`'s fake docker
- `browser-settle.test.mjs` `RESIDUAL_COPIES`
- `check-objectscript.py`'s rule set and its harness
- `InteropItemControl.StartProduction`, used by the `InteropItem*` classes

The implement stage greps `ui/browser`, `ui/tools`, the `ui/src` specs and `src/OcuPilot/Test` for each, and every test it changes joins `(loop)`.

*Every test added or changed passes on a fresh environment, in either order.*

**Commands.** One per foreground call with `timeout: 600000`, never two test calls in one message. Before each browser run: `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`. Browser runs use `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`.

- `(loop)` `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/b708a79b-b765-42ec-adea-dbc87acf6251/scratchpad/e21u/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` -- `LOADERRORS=0`.
- Batch 1:
  - `(loop)` `cd ui && node --test tools/structural-walk.test.mjs tools/protocol-retry.test.mjs` -- green.
  - `(loop)` `cd ui && node --test --test-concurrency=1 browser/a11y-structural-invariants.browser-spec.mjs` -- green, governance settled in every pass.
  - `(loop)` `cd ui && node --test --test-concurrency=1 browser/users.browser-spec.mjs` -- green.
- Batch 2: `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.InteropItemRun`, then `InteropItemControl`, then `InteropItemRunGate`, one call each -- green.
- Batch 3:
  - `(loop)` `cd ui && node --test tools/ci.test.mjs tools/ci-flake-waits.test.mjs` -- green.
  - `(loop)` `cd ui && node --test --test-concurrency=1 browser/analytics-mdx.browser-spec.mjs browser/agent-code-save.browser-spec.mjs browser/impact.browser-spec.mjs` -- green.
- Batch 4:
  - `(loop)` `uv run scripts/check-objectscript.py` and `uv run scripts/test_check_objectscript.py` -- clean.
  - `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.WireSecurityRead` -- green.
  - `(loop)` `cd ui && node --test --test-concurrency=1 browser/web-applications-actions.browser-spec.mjs` -- green.
- Batch 5:
  - `(loop)` `cd ui && node --test tools/browser-settle.test.mjs` -- green.
  - `(loop)` the 16 specs in three calls of five or six -- green.
- Batch 6:
  - `(loop)` `cd ui && npx ng test --include 'src/app/shell/panel.spec.ts' --include 'src/app/core/**/*.spec.ts'` -- green.
  - `(loop)` `cd ui && node --test --test-concurrency=1 browser/system-explorer-documatic.browser-spec.mjs` -- green.
- Every batch:
  - `(loop)` `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh` -- clean.
  - `(once)` `cd ui && npm run test:tools` -- green.
  - `(once)`, runner-owned: the ObjectScript sweep, one class per call; `smoke.sh --container ocupilot-ci`; and Rule 30's fresh check. The full browser suite is CI's.

**Mutations (Rule 19).** One per AC. Each is applied, observed red, and reverted; the tree is confirmed identical with `git status --short` and `git diff --stat`, and reverted ObjectScript is reloaded.

- Stall line: drop the busy probe → the busy fake red; let a probe throw → the probe-failure fake red.
  - mutation: the busy verdict made `grew >= Infinity` in `rendererState` → "the stall line reads the renderer as busy ..." red alone (1 of 32); reverted. The `probe` wrapper in `stallLine` made `read()` with no catch → the stall-line cases and the hung-call cases red (15 of 32), among them "a probe that throws is named in the line ..."; reverted. After each revert `git diff | md5` read the same as before the mutation and the file passed 32 of 32.
- DW-2720: remove AC1's `waitForRememberedView` and seed `%all` for the users view before AC2 → AC2 red at its filter-empty assertion.
  - mutation: after `resetRememberedState()` in `signedInAtList`, a `POST {kind:'view', action:'set', route:'permissions/users', value:'{"filter":"%all"}'}` (the late write, standing in for AC1's unawaited one) → AC2 and AC7 red at "the list opens from an empty filter field; it holds "%all"", and AC1 red with the original shape (aria-rowcount 14 against 4); reverted, `git diff | md5` identical, and the spec read 4 of 4 in the two runs before the mutation and the one after.
- DW-2787: drop the START answer check → the new double-start test red.
  - mutation: the START answer check after the port's `START` in `InteropItemControl.StartProduction` replaced by `If 0 {` → `TestTheStartHelperNamesAStartThePortRefuses` red alone (1 of 11, run 884: the helper answered OK from the facts); reverted. `Continue` after the unread-row note in `Jobs()` made `Quit` → `TestTheJobListNamesAnUnreadableRowBesideTheOperation` red alone (1 of 11, run 885: the operation missing from the list); reverted. After each revert `git diff | md5` read the same as before the mutation, and the reverted source was reloaded into `ocupilot-ci`.
- DW-2714: delay `loadCubes`' assignment in `mdx-query.store.ts` by 1 s, with the bundle redeployed, and use the old `pressRun` → AC1 red; with the new one → green.
  - mutation: a 40 ms `setTimeout` before `this.cubesValue = names` in `loadCubes` (a 1 s delay after the answer cannot reach a click made within milliseconds of it), the bundle rebuilt and redeployed, and `runBoxStable` removed from `pressRun` (the cubes-read clause kept) → 11 of 11 green. With a 12 ms delay → AC8 (QA) red alone (1 of 11): "expected the click on Run to start a run ... the element at Run's center is ..."; with `runBoxStable` back, the same bundle → 11 of 11 green. The 12 ms row reddened once in one run and is timing-dependent (inference). The store mutation reverted, the bundle rebuilt and redeployed, `git diff | md5` identical to before the mutation.
- DW-2282: drop the spinner wait → `ci-flake-waits.test.mjs` red.
  - mutation: the `waitForFunction` line deleted from `cardViolations` → "cardViolations waits for the tool-call spinner ..." red alone (1 of 10); reverted, `git diff | md5` identical, 10 of 10.
- DW-2761: delete the `RestartCount` check → the restart-count-1 test red.
  - mutation: `refuse_restarted_start` removed after the `up` loop → "DW-2761: a throwaway that restarted after a failed start fails `up` ..." red alone (1 of 106); reverted, `git diff | md5` identical, 106 of 106.
- DW-2459: drop the `DependsOn` lookup → the shipped-tree case red.
  - mutation: `allowed` in `check_parameter_dependencies` made `set(info["supers"]) | {name}` → the shipped-tree case and the two `DependsOn`-clean fixtures red (3 of 9); the call removed from `check_naming` → the three flagged fixtures red (3 of 9); each reverted, `git diff | md5` identical, 172 of 172 and the checker clean (0 problems, 21 rules).
- DW-2202: drop `Suspended` from `TaskScheduleList`'s declaration → `WireSecurityRead` red; mark one more rowAction `serves-ocupilot` → `:430` red.
  - mutation: `"Suspended"` removed from `TaskScheduleList`'s `read.fields`, reloaded into `ocupilot-ci` → "Suspended among them" red alone (1 of 25, run 890; the answer-equals-declaration assertion stays green because the answer is built from the declaration); reverted and reloaded, 25 of 25 (run 891). `add-application-role` marked `serves-ocupilot` in `screens.generated.ts` (the spec reads that file, the deployed bundle unchanged) → AC3 red at the count, 3 against 4; reverted, 3 of 3, `git diff | md5` identical.
- DW-2476: re-add a copy to a converted spec → the ratchet red.
  - mutation: a local `transitionsSettled` declaration added back to `system-explorer-write.browser-spec.mjs` → "the specs that declare their own transitionsSettled are the residual list ..." red alone (1 of 19), the actual list gaining that spec; reverted, `git diff | md5` identical to before the mutation, 19 of 19.
- DW-2225: remove the merge → the new panel test red.
- DW-2352: restore `setAttribute('src', …)` for every load → the Back test red.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none (lead, 2026-11-21: split to Story 21.38 approved; see Spec Change Log). Plan-stage note kept for the record: the 19-entry inbox does not fit one story. Recommend a sibling Story 21.38 ("Shared Rules helpers, the source-control follow-up and escalated wording") taking DW-2499, DW-2405, DW-2369, DW-2442 and DW-2474. Batches 1 to 6 of this spec, the 14 other entries with the must-fix set first, are ready for development once the split is applied.

Planned at plan stage on `ocupilot-ci`: the bundle was rebuilt and redeployed, the governance settle was measured at 1280 and 720 px, light and dark, a walk pass's memory was profiled, the probe START was measured over 12 cycles, and InteropHostTest then InteropItemRun was run green. Nothing the measurements created remains: the probe was removed, and each measuring browser context was closed by its harness.
