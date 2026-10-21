---
title: 'Story 23.11: The range-end cleanup, part 10'
type: 'bugfix'
created: '2026-10-15'
status: 'done'
baseline_revision: '9b9274439800f6a9259e935d4ce0db42d3575478'
baseline_commit: '9b9274439800f6a9259e935d4ce0db42d3575478'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['multiple-goals', 'oversized']
deferred:
  - summary: >-
      `_bmad/custom/parallel.yaml:54` still says `ui/browser.config.mjs` defaults to `ocupilot-ci`; the config now has no default for either browser variable.
    evidence: |-
      `browserConfig` throws unless `OCUPILOT_BROWSER_ORIGIN` and `OCUPILOT_BROWSER_CONTAINER` are both set (`ui/browser.config.mjs`, pinned by `ui/tools/browser-config.test.mjs`). An implement pass never edits `_bmad/custom/*`.
    location: >-
      _bmad/custom/parallel.yaml:54
    severity: low
---

<intent-contract>

## Intent

**Problem:** Ten ledger entries are owned by this story. The agent's class read refuses some large classes as `TOOL.RESULTTOOLARGE`. Two screens raise a second, wrong alert when the instance is unreachable. Twenty-eight text-bearing controls set a fixed height, so a text-only resize clips them. The test harness has literal shared-surface counts, a browser config that falls back to slot A, narrow passes that measure before the layout settles, and three flakes.

**Approach:** Four area batches, in this order: (a) the agent's class read and three ObjectScript tests; (b) the client test harness; (c) styles and fault rendering; (d) the narrow-pass settle sweep and the browser-spec literals. Each batch is one implement pass and one code commit, with CI green on its own head. Every fix has a pinning test that reddens on the defect, or on a forced race for a flake, with its `mutation:` line under Verification.

## Boundaries & Constraints

**Always:**

- Work in `/Users/jbrandt/git/OcuPilot/.worktrees/epic-23` on `OCU-1-epic23`, and check `git rev-parse --show-toplevel` first. Every IRIS MCP call carries `server: "ocupilot-slot-a"`, which reaches the dev instance `ocupilot`, never the throwaway.
- Run tests, probes and mutations only on the throwaway `ocupilot-ci` (52776/1975), and only once `docker inspect -f '{{.State.Health.Status}}' ocupilot-ci` reads `healthy`. Keep one test run in flight. Await each run in `%UnitTest_Result` or at the browser run's exit. Run every command in the foreground with `timeout: 600000`.
- One implement pass per batch. The lead re-opens the spec for each batch and scopes the pass to that batch's unchecked items. A red batch is reopened alone.
- Red first (Rule 19). Before reading any result, rebuild and redeploy the bundle, or reload `src` and recompile the mutated class and its descendants.
- Extend the sibling named under Design Notes (Rule 31). Comments state the contract. Write non-ASCII in source as `\uXXXX` (Rule 14).
- A derived expectation reads the registry, a descriptor or the mirror. A roster's own pin stays literal (Rule 30).

**Never:**

- Implement passes never edit the spine, `CLAUDE.md`, `.claude/rules/*`, `_bmad/custom/*`, `epics.md`, `deferred-work.md` or another story's spec. The lead applies Design Notes › Lead edits.
- Never raise or remove a read bound. The class view stays cut by whole rows (AD-24). Never change an envelope, a fault kind, or a published sentence.
- Never stop, remove, recreate or `down` `ocupilot`, any `ocupilot-slot-*` container, `ocupilot-ci`, `ocupilot-b-ci` or `iris-community-edition`.
- No commits; pushing is the lead's job. Never put `[skip ci]` on code.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Large class view (DW-2246) | `explorer.class.read` on a class whose view is larger than the reply's share | The first rows that fit, `truncated` true, `rowsSent` below `rowsAvailable`, at most the share | A payload whose row-free part alone exceeds the share is still refused `TOOL.RESULTTOOLARGE` |
| Kept set at the edge (DW-2246) | The kept rows end within the count's extra digits of the share | One row fewer is answered, and the count it writes is the count it carries | No error expected |
| Busy task history (DW-2182) | An instance holding more than 1,000 task-history rows | The both-pairs leg reads one task's runs, the same rows as the test account | No error expected |
| Late query start (DW-2460) | A check phase slower than the cancel's retry window | The cancel is sent once the job is in the delayed port, and the run reads canceled within 3 s | No error expected |
| Absent instant (DW-2462) | The file is removed at a look and written back four looks later | `changed` 0 at the bound, at least one absent look, and no second process touching the file | A file that stays absent: `changed` 1 at the bound, and the page reads 404 `LOG.ABSENT` |
| Unreachable read (DW-2449) | The Guardrails read, or the class-access tab's read, answers status 0 or a 5xx | The surface adds no alert: the shell's banner is the one alert. When the instance answers again, the surface reads again. | A 403, a 404 or an unreadable answer: the in-place `FaultBanner` with Retry |
| Text-only resize (DW-2439) | Caption and body type doubled, light and dark | Each of the 28 controls grows, and none clips | The virtualized `data-table` and `log-viewer` rows stay fixed (DESIGN.md:912) |
| No browser target (DW-2221) | `browserConfig` with either variable unset or empty | Refused, naming both variables and slot A's pair as the example | The live and slot containers are refused as today |
| Foreign real timer (DW-2458) | A real timer another test left arms fake timers while AC6 runs | AC6 green on all three Node bands | The page's own interval or self-re-arming poll: AC6 red |
| Settled narrow pass (DW-2455) | An overflow present only once the panel settles at 320 px | The 720 px structural pass is red | An overflow a settled pass exposes is fixed in this batch |
| A member added (DW-2202) | A story adds an area, a screen or a tile | Only the roster's own pins need editing | No error expected |

</intent-contract>

## Code Map

**Batch a: the agent's class read and three ObjectScript tests.**

- DW-2246:
  - `src/OcuPilot/Kernel/Agent/Bound.cls` `Apply`, step 3 (`:115-153`): the base is measured with `rowsSent` 0 (`:130`), the greedy keep (`:132-139`), and the final check (`:148`) that refuses.
  - `src/OcuPilot/Kernel/Agent/Dispatch.cls:336-347`: a rows-shaped result goes through `Bound.Apply` at the reply's share (`Answer` `:140`, default `Limits.TOOLRESULTMAXLENGTH` 65,536). Screen context shares the cutter (`Api/Turn.cls:570-593`).
  - `src/OcuPilot/Screen/Tool/Read.cls:215-282` `View`: the tool's view is `{fields, rows, truncated, rowsAvailable, criteria}`.
  - Descriptor: `Screen/Descriptor/ExplorerClassDocument.cls`, with one row per member and `Description` as a field.
  - Tests:
    - `src/OcuPilot/Test/ContextBound.cls:102` `TestTheTotalSizeCutDropsTrailingRowsAndRefusesWhenNothingFits` is the sibling.
    - `src/OcuPilot/Test/ExplorerWire.cls:187-233` is the dispatch leg. Story 18.10 moved it to `Limits.cls` (`f33263ed`). Its header says it issues reads only.
    - `src/OcuPilot/Test/ExplorerProbe.cls:26` `MakeClass` (`SetTextFromString`, uncompiled), and `:150` `Remove` (package `OcuProbe192`).
- DW-2182:
  - `src/OcuPilot/Test/WireSecurityRead.cls:491-499`: `:497` reads `tasks.taskhistory` unscoped.
  - `:1086-1112` `AssertSameRowsAsTestAccount` asserts `truncated` 0 at `maxRows=1000` (`:1099`).
  - `DemoTaskId` is at `:504`. `TaskRunList`'s `taskId` criterion scopes the read to one task.
- DW-2460:
  - `src/OcuPilot/Test/SqlBackgroundJob.cls:340-357`: the cancel is sent on `startedAt`.
  - `Area/Explorer/SqlBackground.cls`: `Run` `:249-310` (gate, `Check`, then `PortClass().Run`); `Cancel` `:332-346`, which retries `CANCELTRIES` 10 × `CANCELPAUSE` 0.2 s.
  - `Test/SqlPortDelayed.cls`: `Hang` `DELAYSECONDS` 1 inside `Run`. `Test/SqlBackgroundDelayed.cls` overrides only `PortClass`.
  - A cancel the retries miss is lost: the run completes, and reads neither canceled nor within 3 s (run 12; DW-2466).
  - `%SYS.ProcessQuery` precedent: `Test/EcpProbe.cls:447`.
- DW-2462:
  - `src/OcuPilot/Test/LogTail.cls:296-320`: the writer job deletes at 0.4 s. The tail looks every `CHECK` 0.2 s from the hold's start, so the delete lands on the third look.
  - `Writer` `:147-158` (the `gap` mode); `StartWriter` `:160`.
  - `src/OcuPilot/Test/LogSourceFixture.cls`: `TailState` `:308-318` is the look seam, run in the test's own process and counting `tailLooks` and `tailAbsent`. `ArmTailThrow` `:265-273` is the sibling arm.

**Batch b: the client test harness.**

- DW-2458:
  - `ui/src/app/areas/logs/log-viewer.spec.ts:344-427` (AC6): the async advance `:410` and the async drain `:418` yield to the real event loop.
  - The bounded real-loop wait `:372-376` is a copy of `ui/src/app/areas/home/home.page.spec.ts:1376-1382`, which already advances synchronously (`:1392`).
  - `settle()` is at `log-viewer.spec.ts:228`.
- DW-2221:
  - `ui/browser.config.mjs:72-110` `browserConfig`; `DEFAULT_ORIGIN` `:33`, `DEFAULT_CONTAINER` `:51`, `LIVE_CONTAINER` `:54`.
  - Module-scope call: `ui/browser/preferences-reset.mjs:51`, imported by `ui/tools/preferences-reset.test.mjs:36` in `npm run test:tools`, where the variables are unset.
  - Tests that pin the constants: `ui/tools/angular-json.test.mjs:300,307`; `ui/tools/ci.test.mjs:1595-1665`, whose comment at `:1655-1656` speaks of a container default.
  - Docs: `docs/DEVELOPMENT.md:483`. README has no browser-run line.
- DW-2202, part 1 (tools, components, ObjectScript). These derive from:
  - client: `AREAS`, `SCREENS` (`core/screens.generated.ts`), and `orderedAreas`, `listedScreensForArea` (`core/navigation.ts`);
  - ObjectScript: `Screen.Area.List`, `Screen.Registry.ScreensForArea`, `ListedScreensForArea`.

**Batch c: styles and fault rendering.**

- DW-2449:
  - The store: `ui/src/app/core/guardrails.ts:220-300`. `failed()` is a boolean, and `load` is at `:268`.
  - It is built at `ui/src/main.ts:237` without `connectivity`, while its siblings get it (`:230`, `:233`).
  - The page: `ui/src/app/areas/agent/guardrails.page.ts:59-61` renders a `<p role="alert">`.
  - The tab: `ui/src/app/areas/web-applications/web-app-class-access-tab.ts:48-50`. `load` is at `:189-200`, and the read already answers `{kind: 'fault', fault}` (`core/screen-read.ts:233-234`).
  - Siblings:
    - `core/findings.ts:330-355` `load` (with the unreadable-ok branch as `rejected`) and `core/system-info.ts:141-167`.
    - `home.page.ts:976-986`, and `shell/fault-banner.ts`'s in-place mode (`fault`, `retried`, `logOpened`).
  - Tests: `guardrails.page.spec.ts`, `web-app-class-access-tab.spec.ts`, `ui/tools/guardrails.test.mjs`, the stub `ui/src/app/testing/guardrails.ts:50`, `ui/browser/guardrails.browser-spec.mjs` and `ui/browser/web-applications-class-access.browser-spec.mjs`.
- DW-2439:
  - `ui/src/styles/_components.scss`, 28 `height:` sites on text-bearing rules (`:182`, `:206`, `:232`, `:270`, `:294`, `:506`, `:551`, `:785`, `:1001`, `:1098`, `:1227`, `:1281`, `:1345`, `:1442`, `:1562`, `:1682`, `:1746`, `:1777`, `:1898`, `:2140`, `:2691`, `:2731`, `:2906`, `:3162`, `:5652`, `:6036`, `:7355`, `:8822`), against DESIGN.md:912.
  - `:1548` is already a minimum through `:6067-6071` (inference: same selector, later rule).
  - The fixed rows that stay: `:2383` (`[itemSize]`, `data-table.ts:343`), `:5497`, `:5526`, `:5556`.
  - The doubled-type technique is local to `ui/browser/home-system-information.browser-spec.mjs:241-299`.

**Batch d: the narrow-pass settle sweep and the browser-spec literals.**

- DW-2455:
  - Shared waits in `ui/browser/panel-spec.mjs`: `settleViewport` `:100-104` (no transition wait, by its doc) and `transitionsSettled` `:107-112`. `VIEWPORTS.narrow` is 720×450 (`structural-walk.mjs:67-70`). `detectScreen` sets no viewport (`:587`).
  - 42 spec files set the narrow viewport bare inside their local pass loop. The `page.setViewport(viewport)` lines:
    - A–D: `allowed-directories:148`, `audit-copy-purge:124`, `background-tasks:84`, `dashboard:48`, `dashboard-drill-downs:238`, `definitions:585`
    - E–I: `egress-line:189`, `home-findings:251`, `home-performance:271`, `impact:239,324`
    - interop: `interop-host-tabs:91`, `interop-item-settings:84`, `interop-item-test:79`, `interop-items:78`, `interop-lookup-tables:120`, `interop-message-resend:113`, `interop-productions:74`, `interop-usage:87`
    - L–P: `language-server-editor:190`, `language-servers:148`, `license-usage:62`, `locks:201`, `log-hub:425`, `messages-log-files:185`, `oauth-server-description-editor:120`, `process-broadcast:126`, `prometheus-metrics:236`
    - S: `secondary-logs:339`, `sql-activity:232`
    - System Explorer: `system-explorer:100`, `system-explorer-data-browser:88`, `system-explorer-data-browser-edit:101`, `system-explorer-data-browser-tabs:97`, `system-explorer-documatic:107`, `system-explorer-find:73`, `system-explorer-sql:101`, `system-explorer-sql-query:101`
    - T–X: `task-transfer:101`, `tasks:152`, `token-revoke:184`, `web-sessions:136`, `x509-import:328`
  - Shared loop: `ui/browser/proposal-card-spec.mjs:31-58` `cardViolations` (used by `agent-code-save`, `agent-code-create`, `agent-editor-save`). Its edge wait is `.catch`-ignored.
  - Local loops: `agent-code-save.browser-spec.mjs:305-310`; `header-lockup.browser-spec.mjs:231`.
  - Local waits named otherwise: `read-back.browser-spec.mjs:102` `settled`, `permissions-effective.browser-spec.mjs:148` `frames`.
- DW-2202, part 2 (browser specs):
  - Positional `labels[N]` / `entries[N]` pins:
    - interop and remote: `interop-usage:174`, `remote-databases:302`, `mft-connections:121`, `routine-applications:150`, `superservers:124`
    - journals and encryption: `journals:281,283`, `journal-settings:231,232`, `encryption-keys:221,222`, `encryption-key-file:266`
    - ECP: `ecp-settings:229`, `ecp-application-servers:228`, `ecp-data-servers:375`
    - licenses: `license-servers:252`, `license-key:221`, `license-usage:134-136`
    - others: `web-sessions:225`, `docdb-applications:128`, `background-tasks:182`, `prometheus-metrics:105`
  - Prefix pins: `permissions:276`, `security:279`, `oauth:298`, `tasks:1214`, `rest-apis:114`, `definitions:438`, `local-databases:500`, `namespaces:379`.
  - Rail position: `system-explorer:132`. Tile caption: `system-explorer:143-145`.
  - Whole tab strips: `users-editor:216`, `roles-editor:265`, `web-applications-editor:200` (used at `:226`, `:381`). The editors' own page specs pin those strips (`user-editor.page.spec.ts:159`, `role-editor.page.spec.ts:158`, `web-app-editor.page.spec.ts:167`).
  - Derive from `sideBarLabels(area)` (`ui/browser/side-bar-spec.mjs:21`, from the mirror) and `AREAS`.

## Tasks & Acceptance

**Execution:**

- One implement pass per batch leaves the tree for one commit: `fix(23.11): batch <x> - <area>`.
- Each task names its fix and its pinning test. Its `mutation:` line is under Verification.
- Update every test that asserts a shared surface's old shape, listed in Verification's `Shared surfaces:`, in the same pass.
- The lead writes ledger trailers once the batch's commit is green.

### Batch a: the agent's class read and three ObjectScript tests

- [x] **DW-2246: the total cut measures the count it writes.**
  - **The fix.** In `Bound.cls` `Apply` step 3, after the greedy keep, write the kept rows and their `rowsSent` and serialize. While the JSON exceeds `pTotalMax` and rows remain, drop the last kept row, rewrite `rowsSent` and serialize again. Answer 0 only when the payload holding no rows exceeds `pTotalMax`. The method's doc says the count is measured with the rows it reports.
  - **Tests:**
    - `ContextBound.cls`: new `TestTheTotalCutMeasuresTheCountItWrites`. The payload holds 150 rows of fixed, known lengths. For every cap within 40 characters of each length at which the kept count changes from 9 to 10 rows and from 99 to 100 rows, `Apply` answers 1, the JSON is at most the cap, and the parsed `rowsSent` equals the parsed `rows` size.
    - `ExplorerProbe.cls`: add `MakeLargeClass(pNamespace, pName, pMethods, pDocLength)` beside `MakeClass`. It is uncompiled like `MakeClass`; compile it only if the class read answers no member rows uncompiled.
    - `ExplorerWire.cls`: new `TestALargeClassViewIsCutByWholeRows`. It makes `OcuProbe192.LargeView` with 80 methods, each with a 1,500-character doc comment.
      - Dispatched at default limits, `explorer.class.read` answers with `is_error` 0, `truncated` true and `rowsSent` below `rowsAvailable`, and the content is at most 65,536 characters.
      - Dispatched again with `pMaxLength` one under that content's length, it answers `is_error` 0 with one row fewer, and the content is at most that cap.
      - It deletes its class.
      - The class header now says it saves and deletes one probe class.
- [x] **DW-2182: one task's history.** `WireSecurityRead.cls:497`'s both-pairs leg reads `tasks.taskhistory` with `&taskId=` set from `DemoTaskId()`, and it first asserts that id is not empty. `AssertSameRowsAsTestAccount` gains an optional `pEveryFieldEquals` of the form `<field>=<value>`, asserted on every row; this leg passes `TaskId=<id>`.
- [x] **DW-2460: cancel once the job is in the delayed port.** In `TestAnEarlyCancelIsSentAgainUntilTheQueryRuns`:
  - read the run's `JobId` by SQL, as `TestARunWhoseJobDiedReadsLost` does;
  - then poll `%SYS.ProcessQuery` (open fresh each pass, the reference dropped between polls) until `CurrentLineAndRoutine` names `OcuPilot.Test.SqlPortDelayed`, bounded at 10 s, before the cancel.
  - Assert the job was seen there.
  - `SqlPortDelayed`'s doc says its delay is counted from the port's entry.
  - The other assertions are unchanged.
- [x] **DW-2462: the gap is made between looks.**
  - `LogSourceFixture.cls`: add `ArmTailGap(pAtLook, pLooks, pContent)` beside `ArmTailThrow`. `TailState` deletes the file it looks at before reading on look `pAtLook`, and writes `pContent` to it before reading on look `pAtLook + pLooks`. Looks are counted from 0, as `tailLooks` is; `Clear` forgets the arm.
  - `LogTail.cls`: the absent-file leg arms a gap at look 2 for 4 looks in place of `StartWriter(0.4, "gap", …)`. Drop `Writer`'s `gap` mode, which no other caller uses.
  - The page-read assertion reads `$Select($IsObject(tPageFault): tPageFault.code, 1: "")`, so a present file fails an assertion rather than raising `<INVALID OREF>`.

**Acceptance criteria:**

- Given a class whose view is larger than the reply's share, when the agent calls `explorer.class.read`, then it answers the first rows that fit, marked truncated, and never `TOOL.RESULTTOOLARGE`.
- Integration AC: given `OcuProbe192.LargeView` on the throwaway, when `Kernel/Agent/Dispatch.Answer` runs `explorer.class.read` at the default share and at a share one character under its default answer, then both answer rows within their share.
- Given the both-pairs principal, when it reads the demo task's history, then it reads exactly the test account's rows, every one that task's.
- Given a check phase slower than the cancel's retry window, when the cancel is sent once the job is inside the delayed port, then the run reads canceled within three seconds.

### Review Findings (batch a)

Code review 2026-10-19, layers `blind-hunter`, `edge-case-hunter`, `verification-gap`, `acceptance-auditor`. 22 rows, 20 entries: 4 patch, 1 defer, 15 rejected.

- [x] [Review][Patch] The early-cancel leg's job-id wait is a copy of `TestARunWhoseJobDiedReadsLost`'s loop, the same SQL, deadline and exit, with no stated reason (med, Rule 2; fix-risk low: two test callers, one helper) [src/OcuPilot/Test/SqlBackgroundJob.cls:362]. Fixed: both tests call the new `RunJob`. `SqlBackgroundJob` 12 of 12 (run 718).
- [x] [Review][Patch] The DW-2246 mutation that two test docs and Verification name ("drop the loop") is not the one that produced the reds: removing the loop leaves `pJson` empty, so `Apply` answers 1. The reds came from step 3 writing once with no row dropped (low, Rule 19; fix-risk low: wording, plus the named mutation re-run) [src/OcuPilot/Test/ContextBound.cls:90]. Fixed: both docs and the Verification line name that mutation. It was applied on `ocupilot-ci` and was red in runs 714 and 715, then reverted (tree byte-identical) and green in runs 716 and 717.
- [x] [Review][Patch] `ExplorerWire`'s header says the large-view test "saves one probe class and deletes it". The save needs WRITE on the namespace's code database for the running process, and `ExplorerProbe.Remove` removes every probe document (low; fix-risk low: comment) [src/OcuPilot/Test/ExplorerWire.cls:158]. Fixed: the header now says both.
- [x] [Review][Patch] The DW-2460 `mutation:` line records only the "within three seconds" red. Runs 12, 13 and 703 also red at "the run reads canceled, with no answer" (low, Rule 19; fix-risk low: Verification record) [spec Verification, Batch a]. Fixed: the Observed text names both reds and the run ids.
- [x] [Review][Defer] `TestTheOwnersCancelStopsTheQuery` still cancels at `startedAt` + 0.5 s without confirming the query runs. The production port leaves about 2.5 s of check phase before the retries miss (inference), and no red is recorded [src/OcuPilot/Test/SqlBackgroundJob.cls:312] — deferred: pre-existing sibling, DW-2465 `wontfix-theoretical`, with `reopen_if` set to a red at "within three seconds"

Rejected:

- `low` The second dispatch discriminates only when the first answer keeps 10 or more rows. AD-24 fixes both numbers it depends on (65,536 and 1,000), and they keep about 56 rows. A narrower field bound would make every row fit, so `rowsSent < rowsAvailable` would go red loudly.
- `low` Row order is pinned only by the first row's `Kind`. `Apply`'s keep is a prefix loop, and the first-row check fails on any cut from the front.
- `false` `AbsentLooks() >= 1` could be `= 4`. Each named mutation is already red at another assertion, so an exact count adds nothing.
- `false` QA's mutations left the latest runs red. Runs 707–713 are green after runs 696–706 in `%UnitTest_Result`.
- `low` The Review Triage Log's DW-2182 reject cites a null that QA's run 701 replaced. The row was accurate when written, run 701 strengthens the pin, and the fix would edit the spec outside Verification.
- `false` `WireSecurityRead`'s doc names only the pairs mutation. That mutation still holds, and the scope's `mutation:` line is under Verification.
- `low` `ArmTailGap` on an unredirected path would delete the console log. Its one caller redirects in `Rearm`, so the guard would be for a misuse no caller makes.
- `low` `ArmTailGap` with `pLooks` < 1, `MakeLargeClass` with 1,000 or more methods, and `pEveryFieldEquals` without `=`: each has one caller, which passes 4, 80 and `TaskId=<id>` (after asserting the id is not empty).
- `low` A failed `%ExecDirect` in the job-id wait is read as "the run's job has begun". It fails loudly.
- `low` A cancel that lands after the port's 1 s hang skips the re-send path. The job is seen within a 20 ms poll of entering the port, and the `CANCELTRIES` 1 mutation went red twice (runs 13 and 703).
- `false` "Whole rows at any share". The matrix row's Error Handling column keeps the row-free refusal.
- `false` `AwaitInDelayedPort` opens `%SYS.ProcessQuery` with no `Try`. `%OnOpen` answers an empty slot or a refused open as a status, so `%OpenId` gives `""` and the `$IsObject` guard reads it.
- `low` `MakeLargeClass` repeats `MakeClass`'s one-line package guard. The bodies differ, and a helper for one line reads worse than two copies (Rule 31).
- `low` The Code Map's DW-2460 inference ("the red this fixes is therefore the 3 s bound") is contradicted by runs 12, 13 and 703. That is outside Verification; the lead corrects it at origin.

### Batch b: the client test harness

- [x] **DW-2458: AC6 never yields to the real loop while it counts.**
  - New `ui/src/app/testing/real-timers.ts` exports `activeRealTimers()` and `awaitRealTimersIdle()` (the bounded 50 × 20 ms wait). Both `log-viewer.spec.ts` and `home.page.spec.ts` import them in place of their copies.
  - In AC6, the advance is `vi.advanceTimersByTime(10 * 60 * 1000)` followed by `await settle()`. Each drain pass is `vi.runOnlyPendingTimers()` followed by `await settle()`. The count and its message are unchanged.
  - The comment states this contract in at most eight lines.
- [x] **DW-2221: the browser tier needs both variables.**
  - `browser.config.mjs`: `browserConfig` throws unless `OCUPILOT_BROWSER_ORIGIN` and `OCUPILOT_BROWSER_CONTAINER` are both set and not empty. The message names both, with slot A's pair (`DEFAULT_ORIGIN`, `DEFAULT_CONTAINER`) as the example. The live and slot refusal is kept. The two half-set branches go, because the new check covers them. The doc says the constants are slot A's throwaway pair, named in the refusal and never a fallback.
  - `preferences-reset.mjs`: resolve the config on first use inside the exported functions, not at import.
  - `preferences-reset.test.mjs`: set both variables to slot A's pair for its own calls and restore them after; its header changes to match.
  - `browser-config.test.mjs`:
    - both unset is refused, naming both variables;
    - either one alone, or an empty value, is refused;
    - both set resolves to exactly them;
    - the live and slot cases are unchanged.
  - `ci.test.mjs:1655-1656`: the comment says the config has no default.
  - `docs/DEVELOPMENT.md:483`, in place: "`npm run test:browser` needs `OCUPILOT_BROWSER_ORIGIN` and `OCUPILOT_BROWSER_CONTAINER` both set."
- [x] **DW-2202, part 1: derive the counts outside their roster.**
  - `ui/tools/screen-mirror.test.mjs:116`: `areas.length` equals `AREAS.length` from the generated mirror, never `11`.
  - `ui/tools/strings.test.mjs:457-469`: the area names come from `orderedAreas()`'s label keys.
  - `src/OcuPilot/Test/Navigation.cls`: `:431` and `:354` take their sizes from `Area.List` and `ListedScreensForArea("permissions")`. The area loop at `:399` (and its expected strings at `:224`, `:237`) takes its keys from `Area.List`.
  - `src/OcuPilot/Test/NamespaceFeatures.cls:140`: the size is `Area.List`'s.
  - `src/OcuPilot/Test/Wire.cls`:
    - `:380` takes `Area.List`'s size, and `:476` takes `ScreensForArea("agent")`'s.
    - The literal screen JSON at `:534`, `:567`, `:617`, `:666` and `:787` becomes the area's `ScreensForArea` with each descriptor's route and label, plus the caller's verdict from the gate. Keep each splice the test makes today (the startup screen, the drill-downs, the editor).
  - `src/OcuPilot/Test/ExplorerDescriptor.cls:38`: Agent's `railPosition` equals the area count from `Area.List`.
  - `ui/src/app/areas/home/home.page.spec.ts:410-421`, `:438`, `:1551`: the tile count and names come from `tileAreas` (derived at `:441`).
  - `ui/src/app/shell/area-verdict.spec.ts:144`, `:163`: the expected entries come from `listedScreensForArea('logs')` and `listedScreensForArea('os-management')`.

**Acceptance criteria:**

- Given AC6 runs after a test that left a real timer arming fake timers, when it counts, then it reads only the page's own timers, and it is green on Node 22.22.3, 24.15.0 and 26.0.0 (CI `gates`).
- Given either browser variable unset or empty, when any browser spec or tool resolves its config, then it refuses before touching an instance; `npm run test:tools` still runs with neither set.
- Given a story adds an area, a screen or a tile, when the batch's changed tests run, then none of them needs editing.

### Review Findings (batch b)

Code review 2026-10-20, layers `blind-hunter`, `edge-case-hunter`, `verification-gap`, `acceptance-auditor` (full-opus). 37 rows, 25 entries: 12 patch, 2 defer, 11 rejected. Rule 3 exempt: test harness and tooling, no user-facing surface.

- [x] [Review][Patch] Home's Story 15.4 timer count still yields to the real loop through `await vi.advanceTimersByTimeAsync(0)`, so a foreign real timer can reach the fake clock, against `real-timers.ts`'s own contract (med, Rule 19 hermeticity; fix-risk low: one test) [ui/src/app/areas/home/home.page.spec.ts:1374]. Fixed: a synchronous `advanceTimersByTime(0)` and microtask turns, with a seeded 1 ms foreign interval cleared in `finally`. Mutation line under Verification.
- [x] [Review][Patch] `Wire`'s os-management leg asserted seven listed screens "listed last" and the drill-downs "lead the area", so an added os-management screen reddens a batch-b test, against AC3 (med; fix-risk low: one test) [src/OcuPilot/Test/Wire.cls:752]. Fixed: each entry is asserted whole by containment and stays in the derived comparison; `tSpliced` and the story-history narration are gone. Mutation line under Verification.
- [x] [Review][Patch] The DW-1852 block in `area-verdict.spec.ts` pinned the 13 Security entries as a literal and clicked `items[4]`, so an added Security screen reddens it (med, DW-2202, Rule 30; fix-risk low) [ui/src/app/shell/area-verdict.spec.ts:266]. Fixed: `expectedEntries` now takes the map and the routes a tab opens, and both describes use it; the click finds OAuth 2.0 by route. Mutation line under Verification.
- [x] [Review][Patch] Three `Wire` doc mutations (WebAppList `[]`, TaskScheduleList swapped, ProcessList less `%Admin_Manage`) still claimed the entry assertion goes red; the entry is derived from the same declaration now (low; fix-risk low: comments) [src/OcuPilot/Test/Wire.cls:558]. Fixed: each names the read's refusal assertion, observed red alone on `ocupilot-ci` (runs 710, 711, 712), reverted, green (run 713).
- [x] [Review][Patch] `ExpectedAreaVerdicts`' doc said "an added area changes no expectation here"; it names an area's first declared pair, which is the gate's answer only while the holder lacks it (low; fix-risk low: comment) [src/OcuPilot/Test/Navigation.cls:419]. Fixed: the doc states that scope, and the "two areas" comment no longer counts.
- [x] [Review][Patch] `real-timers.spec.ts`'s bounded test held the wait on its 6 s guard timer, so its interval and "still pending" assertion were not load-bearing (low; fix-risk low) [ui/src/app/testing/real-timers.spec.ts:28]. Fixed: the interval ends itself and is the only timer armed; clearing it must drop the count by one. Mutation line corrected under Verification.
- [x] [Review][Patch] AC6's `realAtFake` was sampled before QA's foreign interval was armed, so its message counted one real timer too few (low; fix-risk low) [ui/src/app/areas/logs/log-viewer.spec.ts:384]. Fixed: sampled after the interval, just before the clock is faked.
- [x] [Review][Patch] Home's tile tests picked tiles by literal index (`tiles()[0]`, `[1]`, `[3]`), so an area inserted ahead of Logs reddens them (low; fix-risk low) [ui/src/app/areas/home/home.page.spec.ts:317]. Fixed: `tileOf(key)` finds each by its place in `TILE_AREAS`. `ExplorerDescriptor`'s rail position 8 stays literal: it is that area's own declaration.
- [x] [Review][Patch] Count prose left beside derived assertions: Home's header "the nine tiles", and `Wire`'s Security doc "twenty-eight built screens" with its story list (low; fix-risk low: comments) [src/OcuPilot/Test/Wire.cls:625]. Fixed.
- [x] [Review][Patch] Stale "default" comments: `angular-json.test.mjs` said the container default is the throwaway's, and `ci.test.mjs`'s rewritten comment kept the 2026-09-16 date (low; fix-risk low) [ui/tools/angular-json.test.mjs:306]. Fixed.
- [x] [Review][Patch] `preferences-reset.mjs` said it refuses the live container's origin; it checks the container name (low; fix-risk low: comment) [ui/browser/preferences-reset.mjs:39]. Fixed. The origin guard itself is rejected below.
- [x] [Review][Patch] `Wire`'s os-management `tSpliced` was an 18-route hand list kept in step with the splices, and the comments above it narrated the roster's history (low) [src/OcuPilot/Test/Wire.cls:752]. Fixed with the os-management patch above.
- [x] [Review][Defer] `WireSecurityRead` (19) and `WireOAuthRead` (5) compare whole-area screen rosters as literals per principal, so an added Permissions, Security, Logs or Tasks screen still needs editing; the DW-2202 census missed them (med; fix-risk high: deriving per-principal verdicts would weaken the real-principal pins) [src/OcuPilot/Test/WireSecurityRead.cls:426] -- deferred: DW-2202 occurrence, owner this story, for its adjudication at batch d
- [x] [Review][Defer] `_bmad/custom/parallel.yaml:67` also says a missing browser container execs into slot A's throwaway [_bmad/custom/parallel.yaml:67] -- deferred: DW-2467 occurrence (`_bmad/` is owner-only)

Rejected:

- `low` Derived counts no longer force a real-wire assertion for an added area or agent screen (`Wire.cls:420`, `:518`). AC3 asks for exactly this; the per-key verdicts stay the test's own pins (by-design).
- `low` `ExpectedScreens` holds only `%Admin_Operate:USE`, while `ADMINUSER` also holds its code database's read. No descriptor declares that resource or a public pair, and a mismatch fails red.
- `low` A refused tab-group head with an allowed tab would make `expectedEntries` disagree with the side bar. No Logs or OS management group does that in the map, and modelling it would re-implement `openableEntry`.
- `low` The origin is never checked against the live and slot ports. This predates the batch, every refusal names slot A's pair, and the guard would be a third copy of the slot port list.
- `low` A whitespace-only variable passes the empty check and fails at the first fetch.
- `low` A throw inside `ExpectedScreens` leaves its held pair armed. Every descriptor has the three members it calls, and a throw already reddens the test.
- `low` `awaitRealTimersIdle` hangs under fake timers, and does not count unref'd timers or immediates. Both callers wait before faking, and nothing yields while counting.
- `low` Removing the literal rosters from `Wire` and `area-verdict.spec.ts` drops their membership pins. The task directs the derivation; `navigation.test.mjs` and `Navigation.cls` keep the rosters' own pins (by-design).
- `low` The Auto Run Result predates QA (component count, residual risk, paths). The fix edits the spec outside Verification.
- `false` No CI run covers QA's and this review's changes. They are uncommitted; the lead's push runs CI on them.
- `false` `preferences-reset.test.mjs` restores `undefined` as a string. Each case restores the value the `before` hook set, and the `after` hook deletes a variable the shell had not set.

### Batch c: styles and fault rendering

- [x] **DW-2449: a banner fault adds no alert of its own.**
  - `core/guardrails.ts`: keep a `fault(): Fault | null` beside `failed()`.
    - Use `classifyFailure`, and record an unreadable ok answer as `rejected`, as `Findings.load` does.
    - Park a banner fault with `connectivity.retryWhenReachable(GUARDRAILS_PATH, …)`. `GuardrailsOptions` gains an optional `connectivity`, and `main.ts:237` passes it.
  - `guardrails.page.ts`: render `<app-fault-banner [fault]="inPlaceFault" (retried)="retry()" />`, where `inPlaceFault` is `null` for a banner fault. No section is drawn on any failure.
  - `web-app-class-access-tab.ts`:
    - keep the read's `fault` in place of `loadFailedSignal`, and render the same in-place banner;
    - park a banner fault with the injected `ConnectivityService`;
    - an empty list is drawn only with no fault.
  - Tests:
    - `ui/tools/guardrails.test.mjs` and `guardrails.page.spec.ts`: status 0, 503, 404 and an unreadable answer.
    - `web-app-class-access-tab.spec.ts`: status 0 and 404.
    - `guardrails.browser-spec.mjs` and `web-applications-class-access.browser-spec.mjs`, each with a status-0 leg and a 404 leg. Each counts every `role="alert"` in the document: one (the shell's banner) at status 0, and the in-place banner with Retry at 404. Use the interception idiom at `home-system-information.browser-spec.mjs:315-323`.
- [x] **DW-2439: text-bearing heights are minimums.**
  - `_components.scss`: each of the 28 sites in the Code Map becomes `min-height:` with its value.
  - Where the doubled-type pass still finds that element clipping, fix the clipping declaration in the same rule (a px `line-height`, or a clipping `overflow`).
  - The fixed rows of the virtualized lists stay as they are.
  - `ui/browser/panel-spec.mjs`: export `scaleTypeTokens(page, factor)`, promoted from `home-system-information.browser-spec.mjs:241-277`. It answers the tokens it could not parse, and that spec imports it.
  - New `ui/browser/text-reflow.browser-spec.mjs`, in light and dark:
    - At 1440×900, double the type, then assert `scrollHeight <= clientHeight + 1` for every element matching each changed selector.
    - Elements come from the shell, Home, a list page with criteria and its menus opened, a form page, and a typed-name confirm, closed with Cancel.
    - A selector no opened screen draws without a write is measured on an element carrying that class, inserted into its real parent.
    - The spec fails on a selector it finds no element for.

**Acceptance criteria:**

- Given the instance is unreachable, when the Guardrails page or a web application's class-access tab reads, then the document holds one alert, the shell's banner, and once the instance answers the surface reads again.
- Given a 403, a 404 or an unreadable answer on either surface, when it renders, then `FaultBanner`'s in-place mode draws its sentence for that kind with Retry, and Retry reads again.
- Given caption and body type doubled, when any of the 28 controls renders, in light or dark, then it grows and does not clip.

### Review Findings (batch c)

Code review 2026-10-21, layers `blind-hunter`, `edge-case-hunter`, `verification-gap`, `acceptance-auditor` (full-opus). 27 rows, 20 entries: 6 patch, 2 defer, 12 rejected. Rule 3 met: `guardrails`, `web-applications-class-access` and `text-reflow` drive the deployed bundle in a real browser.

- [x] [Review][Patch] `.ocu-command-bar-refresh` never grows: its `line-height` is a fixed 32 px under `nowrap` and `overflow: hidden`, so `min-height` changes nothing and the chip clips from about 3x type, against DESIGN.md `:912` (low; fix-risk low: one declaration inside a ruled rule, unchanged at 1x) [ui/src/styles/_components.scss:1746]. Fixed: `line-height: max(var(--ocu-control-height), calc(var(--ocu-type-body-line-height) * 1em))`, as `.ocu-server-flag` does; `text-reflow` now sees the chip's `height:` revert, and `design-tokens.test.mjs` pins the line. Mutation lines under Verification.
- [x] [Review][Patch] Comments the batch made wrong: the account section says its items are a "fixed" `control-height` and padding "would overflow", the chip's comment says `height` is restated, and a tools assertion message names "the fault line" (low; fix-risk low: comments) [ui/src/styles/_components.scss:481]. Fixed: each states the minimum; `text-reflow`'s note on the chip as an exception is gone with the exception.
- [x] [Review][Patch] `FaultBanner`'s note on why it draws no refused row lists only About, System Information and Findings as caller-own and ungated; the Guardrails page and the class-access tab now mount it too, and the tab's read is gated (low; fix-risk low: comment) [ui/src/app/shell/fault-banner.ts:186]. Fixed: it names both mounts and says a 403 in place reads as the generic sentence. Epic 20 has not changed the file.
- [x] [Review][Patch] `stubGuardrails`' `setUnreachable` and `unreachable` seed have no caller left, beside the new `setStatus` that overrides them (low; fix-risk low: deletion) [ui/src/app/testing/guardrails.ts:16]. Fixed: both removed; `setStatus(0)` is the one way to fail a read.
- [x] [Review][Patch] Three mutation comments name legs that cannot go red: each loop stops at its first failing case (low; fix-risk low: comments) [ui/src/app/areas/agent/guardrails.page.spec.ts:209]. Fixed: each names the loop's first case, as the recorded observations do.
- [x] [Review][Patch] `text-reflow`'s clip report reads a button's `value`, which is `''`, so every clipped button entry names no text (low; fix-risk low: one expression) [ui/browser/text-reflow.browser-spec.mjs:283]. Fixed: only an input reports its value; the chip's mutation run named "Auto-refresh: off".
- [x] [Review][Defer] A 200 answer that is not the read's shape leaves every `read-state` screen with no alert: `screen-read.ts` classifies it `server-fault`, `ApiService` reports a success so no shell banner rises, and `showRefusal` hides banner faults (med; fix-risk high: the classifier is shared by every screen's read) [ui/src/app/core/screen-read.ts:231] -- deferred: pre-existing outside batch c, which fixed it in the tab only (Design Notes); DW-2471, `escalated` to the decision sheet
- [x] [Review][Defer] `audit-copy-purge`'s AC2 reads today before the dialog does, so a run across local midnight is red; it reddened CI run 39517085403 on `dba8275c` (low; fix-risk low) [ui/browser/audit-copy-purge.browser-spec.mjs:214] -- deferred: DW-2472, `wontfix-accepted`; a pin needs a forced day turn the browser tier cannot stage without a clock seam

Rejected:

- `low` The form bar can now grow, but the toast lift and the form page's `scroll-padding-bottom` still add its 56 px token (`_components.scss:6179`, `:6227`). It needs a caption wrapping past 72 px at enlarged type with a toast or a bottom field at once, and a fix must measure the bar from script.
- `low` (by-design) A 403 on either surface draws the generic sentence with Open messages.log rather than EXPERIENCE.md's refusal row. AC2 names `FaultBanner`'s in-place sentence and no `strings.ts` change; the tab's read declares the editor's own pairs.
- `low` The Auto Run Result's counts predate QA (6, 6 and 4 tests now) and miscount the triage log. The fix edits the spec outside Verification; this review's final runs are recorded below.
- `false` (by-design) Buttons whose labels already wrapped now grow at normal type (log viewer bar, SQL query). DESIGN.md `:912` makes every height a minimum, and CI run 39517085403 ran the full browser suite with no other red.
- `low` Local `signedInAt` copies gain `prepare`, the two component specs declare their own `StubNavigation` and `StubShell`, and Home keeps its own `readAlerts`. The local helpers predate the batch, per-spec stubs are the house pattern across twenty specs, and Home's variant locates its block by heading and reports three places.
- `low` A destroyed tab whose read fails after a newer tab parked replaces that park. It needs two tabs and an outage that answers out of order, and the fix is a new guard.
- `low` Overlapping tab reads that settle out of order let an older failure win. Pre-existing, and the fix is request sequencing.
- `false` `text-reflow` cannot see a clipped `<select>`. The criteria rule's `height:` mutation reported `.ocu-criteria-select` clipped in both themes, so a select's `scrollHeight` does exceed its box.
- `low` The dead `.ocu-guardrails-fault` selector. Already DW-2470, owned by this story for batch d.
- `low` (by-design) The tab holds its read's fault in a component signal (AD-19). Its rows have lived there since Story 18.10, as in the other pages that call `createScreenRead` directly, and the Task names the field.
- `false` The guardrails and class-access specs have no dark leg. AC1 and AC2 name no theme, and the banner draws bare roles (Conventions › Theme).
- `false` The spec reads `status: done` with batch d open. It is build-auto's per-batch machine state.

### Batch d: the narrow-pass settle sweep and the browser-spec literals

- [x] **DW-2455: every structural pass measures the settled layout.**
  - In each of the 42 files, the pass loop sets its viewport with `settleViewport(page, viewport)`. After the theme toggle it awaits `transitionsSettled(page, config.navigationTimeoutMs)` before `detectScreen`. Both helpers are imported from `panel-spec.mjs`.
  - The same applies to `cardViolations` (drop its ignored edge wait), the local loop in `agent-code-save:305-310`, and `header-lockup:231`.
  - `read-back:102` and `permissions-effective:148` call the shared `transitionsSettled`.
  - Any overflow a settled pass exposes is fixed in this batch, in CSS, and that pass is its pin.
  - New `ui/tools/browser-settle.test.mjs` scans each `ui/browser/*.mjs` that calls `detectScreen(`. Between the last viewport change (`setViewport(` or `settleViewport(`) and each `detectScreen(` call, in text order, there must be a `transitionsSettled(` or `panelSettlesAt(` call. A file it flags beyond the 47 is settled the same way.
- [x] **DW-2202, part 2: derive the browser specs' positions.**
  - Each positional pin reads its index as `sideBarLabels(area).indexOf(<label>)`, asserts it is at least 0, and asserts the drawn entry at that index carries the label.
  - Each prefix pin compares against `sideBarLabels(area).slice(0, n)`, or is dropped where the spec's derived full-list check already covers the side bar. Record which.
  - `system-explorer:132` takes the area's index in `AREAS`' rail order. `system-explorer:143-145` joins `sideBarLabels('system-explorer')`.
  - The three editor specs stop pinning the whole strip and assert only the tabs they open, by their `STRINGS` label. The page specs stay the strips' one pin.
  - Not in this pass: the `WireSecurityRead` (19) and `WireOAuthRead` (5) per-principal roster literals, batch b review's DW-2202 occurrence. MED with high fix-risk, so the lead escalates that residual at this batch's adjudication (Rule 15).
- [x] **DW-2470: drop the dead `.ocu-guardrails-fault` selector.** Remove it from its shared selector list in `_components.scss` (around `:7480` after the 20.12 merge); the rule's other selectors and declarations stay. No pin: a deleted unused selector has no behavior to pin; `grep -rn ocu-guardrails-fault ui/` reads empty after it.

**Acceptance criteria:**

- Given a narrow pass in any browser spec, when it measures, then the viewport has settled and no CSS transition runs, and `browser-settle.test.mjs` refuses a pass that measures earlier.
- Given a screen inserted mid-list in any area's side bar, when the batch's changed specs run, then none needs editing.

## Spec Change Log

## Review Triage Log

### 2026-10-19 -- Review pass (batch a)

- verdicts: 13 findings -- high 0, medium 0, low 6, false 7, maybe-false 0
- findings:
  - `[low]` `[patch]` `LogTail.cls` header says the writer job "briefly removes" the scratch file -- the `gap` mode is gone and `ArmTailGap` removes it; the header now says so.
  - `[low]` `[patch]` DW-2182 `mutation:` line names "`pEveryFieldEquals` ignored", which cannot redden -- the observed half is a different mutation; the line now names the one run (Rule 19).
  - `[low]` `[reject]` The DW-2182 `TaskId` assertion fails only where the history holds another task's run -- the defect is data volume, which a hermetic test cannot seed into the system task history; the Verification line records the null.
  - `[low]` `[patch]` `AssertEquals(tChecked, 81)` cannot fail -- it now counts answered ceilings; red under the loop's removal (run 26).
  - `[low]` `[reject]` `AwaitInDelayedPort` fails if the test process stalls about a second before its first sample -- it fails loudly, never passes falsely, and `DELAYSECONDS` cannot rise past the cancel's retry window.
  - `[false]` `[reject]` The default-share leg passes without the fix -- it is the AC's first leg; the second dispatch carries the discrimination and went red alone under the mutation.
  - `[false]` `[reject]` The second dispatch's share is constructed -- the AC names it ("one character under its default answer"); a real class sits in the window over two characters.
  - `[false]` `[reject]` `AdminPort` is not pinned and the default share does not reproduce the refusal -- Design Notes measure the window; the AC pins `OcuProbe192.LargeView`.
  - `[false]` `[reject]` The turn loop's share derivation and 256-character floor are untested -- neither is changed by the diff, and `Answer` takes the share as an argument.
  - `[false]` `[reject]` The row-free refusal has no tool-level test -- the refusal path is unchanged (`tKeep` 0, then the check) and `TestTheTotalSizeCutDropsTrailingRowsAndRefusesWhenNothingFits` pins it.
  - `[false]` `[reject]` `Api/Turn.cls` is not pinned -- it shares `Apply`, pinned at the function; `TurnContext` and `ScreenGrounding` ran green in the implement pass.
  - `[low]` `[reject]` DW-2182: no test makes the history exceed 1,000 rows -- same root cause and route as the third row.
  - `[false]` `[reject]` DW-2460: `SqlBackgroundDelayed` is untouched and the slow check phase is only a transient mutation -- the test waits for the job inside the delayed port, so it is independent of the check phase; the `Hang 1.5` mutation shows the old leg red and the new leg green.
- own checks: `AwaitInDelayedPort` opens `%SYS.ProcessQuery` from `HSCUSTOM` with no namespace switch, and it resolved on this build (the leg's seen-in-port assertion green, and red under `CANCELTRIES` 1); it sets `tProcess` to `""` after each poll, so no reference survives a pass. `WireSecurityRead.cls` is large and no defect was found in it.

### 2026-10-20 -- Review pass (batch b)

- verdicts: 15 findings -- high 0, medium 1, low 12, false 2, maybe-false 0
- findings:
  - `[medium]` `[patch]` `preferences-reset.test.mjs` cleared the browser variables only in a hook that runs after its top-level import, so a shell exporting both hid a module-scope `browserConfig()` -- the file now clears both before the import and restores them after; the mutation is red with both exported and with neither.
  - `[low]` `[patch]` `Navigation.AreaVerdicts` and `ExpectedAreaVerdicts` return the same sentence when `Area.List` fails -- the test asserts the status and a non-empty list first.
  - `[false]` `[reject]` `rail.spec.ts` count literals -- its `AREAS` is the spec's own 11-entry stub (`:83`), not the shipped mirror, so a new area changes none of them.
  - `[low]` `[patch]` The Logs half of `area-verdict.spec.ts` could no longer observe a gated entry -- it asserts one, as the OS management half does; red with the gated routes opened.
  - `[low]` `[patch]` `Wire` `ExpectedScreens`, the agent leg and the area counts had no non-empty floor -- `ExpectedScreens` answers a sentence for an area with no built screen, and each count asserts a non-empty list; red when raised to 1000.
  - `[low]` `[reject]` The recorded Wire mutations leave the permissions and security legs unreddened -- Rule 19 asks one mutation per acceptance criterion, and `ExpectedScreens("tasks")` named `"nosuch"` reddens a leg of the same shape.
  - `[low]` `[patch]` The refusal test matched `new RegExp(name)`, which the message always satisfies -- it matches `must both be set and not empty`, and `requests === 0` stays the discriminating check.
  - `[low]` `[reject]` Four `.cls` test classes sit in a batch the intent calls the client harness -- the spec's Tasks place them in batch b.
  - `[low]` `[reject]` `ci.yml` and `preferences-integration.browser-spec.mjs` carry comment-only edits outside the Footprint list -- each replaced a sentence the batch made wrong, and both are reported.
  - `[low]` `[reject]` No committed test loads a browser spec or the runner with the variables unset -- `browserConfig` is the one resolver all 201 specs call, pinned at the function and at the one tools-tier importer.
  - `[low]` `[defer]` `_bmad/custom/parallel.yaml:54` still says the config defaults to `ocupilot-ci` -- an implement pass never edits `_bmad/custom/*`; the lead corrects it at origin.
  - `[low]` `[reject]` The `DEFAULT_*` assertion messages in `angular-json.test.mjs` and `ci.test.mjs` still say "default" -- they name the constants, which the spec keeps.
  - `[false]` `[reject]` The recorded band run is 26.8.1, not the 26.0.0 floor -- AC6's specs also ran green on 26.0.0 in this pass.
  - `[low]` `[reject]` No committed test forces a foreign timer, the named mutation reddened nothing, and the idle wait asserts nothing -- AC6 is the pin, the `mutation:` line records the construction that reddens, and the spec states the wait asserts nothing.
  - `[low]` `[reject]` No committed test adds a member, `Wire` shares the gate's logic, and part 2 is absent -- the spec asks for derived expectations pinned by an off-by-one mutation, the real check still runs on the wire, and part 2 is batch d.
- own checks: the gap layer's `rail.spec.ts` claim read `AREAS` as the mirror; line 83 declares it locally. The intent layer's 26.0.0 point was run: `log-viewer`, `home.page` and `area-verdict` 153 of 153.

### 2026-10-20 -- Review pass (batch c)

- verdicts: 18 findings -- high 0, medium 2, low 12, false 4, maybe-false 0
- findings:
  - `[medium]` `[patch]` The class-access tab drew nothing for a 200 answer that is not the read's shape -- `screen-read.ts` classifies it `server-fault`, a banner fault the tab leaves to a shell banner that never rises -- the tab records a success-status failure as `rejected` and draws it in place; its spec now covers 403, 404 and the unreadable answer.
  - `[low]` `[patch]` The tab's `destroyed` guard had no test -- a departed-tab case was added.
  - `[low]` `[reject]` The `min-height: 0` resets on `.ocu-log-explain` and the warning pair are pinned by source text only -- `design-tokens.test.mjs` reads the shipped stylesheet by this file's own convention, the mutation reddened it each time, and no acceptance criterion asks for a rendered measurement.
  - `[low]` `[reject]` `text-reflow`'s `CHANGED` roster is hand-listed -- 27 of 28 rules were observed red when put back, and a derivation from the stylesheet is not possible in the other direction.
  - `[low]` `[patch]` Acceptance criterion 2 and the `main.ts` wiring had no mutation line, and two test comments named mutations that were not run -- the Retry binding, `inPlaceFault` answering `null`, and the dropped `main.ts` argument were applied, observed red and reverted.
  - `[low]` `[patch]` `text-reflow`'s header said it writes nothing -- `signedInAt` resets the account's remembered screen state; the header says so.
  - `[low]` `[defer]` `.ocu-guardrails-fault` is a dead selector in a shared rule -- the stylesheet clearance covers the 28 heights and the clipping declaration; deferred to the frontmatter list.
  - `[low]` `[reject]` Doubling the unitless line-height tokens makes a fourfold line box -- it is the established technique (`home-system-information`), and the header states what the helper does to the tokens.
  - `[false]` `[reject]` The component specs prove only the surface's half of "the shell's banner is the one alert" -- the browser legs count every alert in the document.
  - `[false]` `[reject]` Browser coverage is status 0 and 404 only -- the spec's Tasks name those two legs, and 503, 403 and the unreadable answer run in the tools and component tiers.
  - `[medium]` `[patch]` The unreadable answer on the tab is handled differently from the Guardrails store -- the same root cause as the first row, fixed there.
  - `[low]` `[reject]` The Guardrails park lives in the store and has no destroyed guard, the tab's lives in the component -- each follows its sibling (`Findings`, `HomePage.systemFault`), and a store outlives its page.
  - `[low]` `[defer]` The leftover `.ocu-guardrails-fault` selector -- the same entry as above.
  - `[low]` `[reject]` `.ocu-command-bar-refresh` is pinned by source text only -- its 32 px line height holds the doubled text either way, and the mutation line records the one test that reddens.
  - `[false]` `[reject]` Four selectors are measured on inserted markup -- the spec names this for a selector no screen draws without a write.
  - `[low]` `[reject]` The pass doubles six roles, not caption and body -- a superset of the stated stimulus; the Design Notes record it.
  - `[low]` `[reject]` "Doubled" is about a fourfold line box -- the same as the line-height row above.
  - `[false]` `[reject]` The clip check is vertical and at 1,440 x 900 only -- the spec asks for that viewport and that comparison.
- own checks: the tab's unreadable-answer claim was traced through `createScreenRead` and `classifyFailure` (status 200 reaches the last branch) and then reproduced by mutation. Fixing it reddened `web-app-editor.page.spec.ts`, whose stub answered the list read with the form's body; the stub now answers the list in its shape.

### 2026-10-20 -- Review pass (batch d)

- verdicts: 16 findings -- high 0, medium 1, low 14, false 1, maybe-false 0
- findings:
  - `[medium]` `[patch]` The settle scan keys on `detectScreen(`, so `agent-code-save` and `header-lockup`, two of the 47 swept files, were held by convention -- a `LOCAL_PASSES` rule now requires a settle after each of their viewport changes; it flagged their bare restores (`agent-code-save` `:327`, `header-lockup` `:244`), which now settle; red when `header-lockup`'s restore settle is removed.
  - `[low]` `[patch]` The scan did not order a theme toggle against the settle, against AC1's "no CSS transition runs" -- a toggle now resets the settle; it flagged `agent-picker` `:141`, whose settle moved after its toggle; red when the reset is dropped and when `agent-picker` is put back.
  - `[low]` `[patch]` AC2 had no insertion evidence -- a mid-list shift of 14 entries was run on `ocupilot-ci`: the batch's 13 os-management specs green unedited, the pre-batch versions red.
  - `[low]` `[patch]` `side-bar-pins` leg 2 passed `entries.slice(0, 7)` against a literal list, the shape this batch removes -- `MAPPED` takes `.slice(...)`; red with HEAD's `oauth` line back.
  - `[low]` `[patch]` `system-explorer` compared an index within the applying areas with an index within all areas, both from `AREAS`, so an area not applying in HSCUSTOM would fail it falsely -- the assertion is gone and the page-observing ones stay; red when the neighbour read is off by one.
  - `[low]` `[patch]` The scan's floor was 40 against 82 scanned specs -- raised to 75.
  - `[low]` `[patch]` `oauth`, `namespaces` and `local-databases` titles and one `routine-applications` comment still carried ordinals nothing pins -- removed.
  - `[low]` `[patch]` `agent-code-save` `:327` measured row edges straight after a bare viewport restore -- same root and fix as the first row.
  - `[low]` `[reject]` The scan checks token order in text, takes a raw `setViewport(` in 35 untouched files, and counts `panelSettlesAt(` as a settle -- the task specifies exactly this lexical rule and those two waits; its theme-toggle half is the second row.
  - `[low]` `[reject]` 27 other files change the viewport without calling `detectScreen` -- they are not structural passes, and the task scopes the scan to files that call it; the two that measure otherwise are the first row.
  - `[low]` `[reject]` "Settled" now means the viewport taken, two frames, no running transition, where `agent-code-save` and `cardViolations` waited for the panel edge with errors swallowed -- the task names the shared helpers and says to drop that ignored wait, and a swallowed wait asserted nothing.
  - `[false]` `[reject]` No test pins "an overflow present only once the panel settles turns the 720 px pass red" -- `.ocu-proposal-card-title`'s fix is pinned by the settled passes of `agent-code-create`, `agent-code-save` and `guided-workflow`, with a recorded mutation and a Decisions line for its origin.
  - `[low]` `[reject]` Leg 4 covers four spellings, the helper test one area, and the helper restates the full-list compare in most files -- the helper names the one entry a spec is about, the full-list compare is the order pin, and the insertion evidence is the second row; `rest-apis` asserts the explorer's place because that is its subject.
  - `[low]` `[reject]` Five specs lost their literal published-word lists -- the task drops a prefix pin where the spec's derived full-list check covers the side bar, and the verification-gap layer found the wording still pinned at `navigation.test.mjs:717` and `ssl.browser-spec.mjs:230` (not re-checked here word by word).
  - `[low]` `[patch]` The `system-explorer` rail comparison reaches past side-bar pins -- same root and fix as the fifth row.
  - `[low]` `[reject]` The three editor specs assert tab membership, not the strip -- the task says they assert only the tabs they open, and the page specs keep the strips' one pin.
- own checks: the `LOCAL_PASSES` and theme rules were run against the shipped tree before the fixes (they named exactly `agent-picker:141`, `agent-code-save:327` and `header-lockup:244`); the 8 specs the patches touched ran 42 of 42 on `ocupilot-ci`; the probe bundle was replaced by a full `npm run build` (prebuild checkers included) and redeployed.

## Design Notes

**Verdicts at head `a69613d2`** (Rule 17 inbox):

| Entry | Verdict | Evidence | Batch |
| --- | --- | --- | --- |
| DW-2246 | confirmed | Measured below; the window was reproduced on `ocupilot` | a |
| DW-2182 | confirmed | `WireSecurityRead.cls:497` is unscoped and `:1099` asserts `truncated` 0. `ocupilot` holds 3,555 task-history rows; `ocupilot-b-ci` held 1,224. | a |
| DW-2460 | confirmed (inference) | The cancel's window is about 2 s from `startedAt`, while the query starts after gate + `Check` + 1 s + prepare. A cancel the retries miss is lost and the run completes (run 12). | a |
| DW-2462 | confirmed (inference) | The red read `AbsentLooks` 0 at .406 s. The writer's delete at 0.4 s coincides with the third 0.2 s look; the second leg then met the writer's write-back, and the page answered 200 (`<INVALID OREF>` at `tPageFault.code`). | a |
| DW-2458 | confirmed | `log-viewer.spec.ts:410,418` yield to the real loop; Home's sibling moved to a synchronous advance for the same contamination (`home.page.spec.ts:1357-1368`) | b |
| DW-2221 | confirmed | `browser.config.mjs:73,99` default both; `browser-config.test.mjs:11-15` allows both unset | b |
| DW-2202 | confirmed (part) | 20 count sites in 8 files (part 1); 33 position sites in 28 files, the System Explorer tile caption and three editor strips (part 2). Refuted: the entity-type literals in `MftConnectionDescriptor` and `SuperserverDescriptor` are gone (`b276085e`). Kept literal (Rule 30): the rosters' own pins (below). | b, d |
| DW-2439 | confirmed | 28 sites by census. Of the ledger's examples, `:1001` is confirmed; `:1548` is already a minimum (inference); "DESIGN.md:5571" does not exist (DESIGN.md has 1,279 lines). | c |
| DW-2449 | confirmed | `guardrails.page.ts:60` and `web-app-class-access-tab.ts:49` render the generic sentence under a boolean | c |
| DW-2455 | confirmed | 82 files use `VIEWPORTS.narrow`: 42 bare (43 sites), 1 weak (`cardViolations`), 39 settled | d |

Counts: 10 confirmed, 0 refuted, 0 already fixed (DW-2202's two named sites refuted within a confirmed entry).

**DW-2246 measurement** (on `ocupilot`, read-only and in memory; its code is main's build from 2026-10-12, which matches head in `Bound.cls`, `Read.cls` and the dispatch's cut):

- The path: `explorer.class.read` is `Read.View` over `ExplorerClassDocument`'s declared read (rows only), cut by `Bound.Apply` at the reply's share. Neither the per-field bound (it cuts and never refuses) nor the source reads' 60,000 cut (`explorer.class.source`) is involved.
- `AdminPort.cls`: 268,786 bytes at head, 247,939 at `fe8e3832`. Its view is 185 rows and 126,191 characters. At 65,536 the cut keeps 131 rows (65,072 characters).
- With the cap at 65,070 or 65,071, `Apply` answers 0 although 130 rows (64,874 characters) fit; at 65,069 and 65,072 it answers.
  - The cause: the base is measured with `rowsSent` 0 (`:130`), but the kept count is what is written, so the final check (`:148`) fails within the count's extra digits.
  - Any share in that window refuses, and a turn's remaining budget can put the share anywhere (inference).
- The largest shipped class is `InteropPort.cls`, at 442,198 bytes. Its view is 74,070 characters (200 of 228 rows), and the cut keeps 190 rows. `Installer.cls`'s view is 97,060 characters over 99 rows.
- `explorer.class.source` on `AdminPort` answers 644 of 4,037 lines, 60,094 characters.
- The `fe8e3832` red is this window (inference). The cut path is unchanged since that commit, and no other branch answers `TOOL.RESULTTOOLARGE` for a rows-shaped read.

**Kept literal under DW-2202 (Rule 30):** tests of the function that produces a roster:

- `navigation.test.mjs:106-110`, `:141-427`, `:440-480`, `:564-573`; `Navigation.cls:499-505`, `:523-524`, `:539-540`; `ExplorerDescriptor.cls:41`; `ReadTool.cls:93-94`.
- `Descriptor.cls:1797` (`EntityType.Count` 73) and `:1929-1944` (the area table).
- The editors' page specs; `PROMPT_GROUP_KEYS`; `SHORTCUT_ROUTES`; `Smoke.cls:871,892`; `AgentViolation.cls:48`; `Prohibited.cls:767`; `Descriptor.cls:1480`.
- `SurfaceCoverage`, `EndpointCoverage` and `FLOORONLY`.

**Declined:** none.

**Decisions:**

- **DW-2246: fix the cut, not the read.** The cut answers one row fewer in the window, so AD-24's contract (whole rows from the end, reported) holds unchanged, and no spine amendment is needed.
- **DW-2458: no yield while counting.** A synchronous advance and drain let no real timer reach the fake clock, so the count is the page's own on every band. This is the shape Home's sibling already takes.
- **DW-2221: keep the constants.** `DEFAULT_ORIGIN` and `DEFAULT_CONTAINER` stay as slot A's pair: the refusal names them, and `ci.test.mjs` holds the origin equal to `ci-throwaway.sh`'s port.
- **DW-2460, DW-2462: the race moves out of the test.** The product is unchanged. A cancel the retries miss is lost and the run completes (DW-2466, `wontfix-accepted`). A file deleted mid-look reads as a change, which the viewer's next page read reports.
- **Batches:** DW-2455 and DW-2202's browser-spec sites share batch d, because both are browser-spec sweeps over overlapping files.
- **DW-2439: a rule that overrides a changed rule's height restates its minimum.** `.ocu-panel-banner-link`, `.ocu-panel-warning-send`/`-edit` and `.ocu-log-explain` gain `min-height: 0`, because the button rule's new minimum beats their `height: auto` and fixed log-row height; `.ocu-server-flag`'s `line-height: 16px` becomes `max(16px, 1em of the label line height)`, the one clip the pass found. All four are outside the 28 sites, and add-only except that `line-height`.
- **DW-2449: the tab records an answer with a success status that is not the read's shape as `rejected`**, as `Guardrails.load` and `Findings.load` do; `screen-read.ts` stays as it is because every screen's read shares it. The editor page spec's stub answers the list read in that shape.
- **DW-2439: `text-reflow` doubles all six type roles, measures a text input by its one line and a menu's items alone while open.** An input reports `scrollHeight` equal to `clientHeight`, and a popup counts toward its host's `scrollHeight`. `ClassicLinkCard` is mounted by no template, so its action is measured on an inserted card.
- **DW-2455: the settled 720 px pass of `cardViolations` read the countdown 20 to 47 px past the card header** (the title's longest word held its minimum width), so `.ocu-proposal-card-title` gains `min-width: 0` and `overflow-wrap: anywhere`; the settled passes of the 4 specs that use it are its pin.
- **DW-2455: the scan is lexical, so `read-back` and `permissions-effective` keep a literal `transitionsSettled(` call in each pass loop beside their local helpers, which now call the shared one; `openapi-try-it` (flagged beyond the 47) is settled the same way.**
- **DW-2202: prefix pins in `permissions`, `security`, `oauth`, `tasks` and `definitions` are dropped (the derived full-list check beside each covers them); `local-databases` and `namespaces` compare `sideBarLabels('os-management').slice(0, n)`; `rest-apis` asserts the explorer through `assertDrawnAtDeclaredIndex`, because its subject is the explorer's place.** Test titles lose their ordinals; the files' header comments keep theirs.
- **DW-2202: positional pins call `assertDrawnAtDeclaredIndex` (new, in `side-bar-spec.mjs`), and `side-bar-pins.test.mjs` gains a no-literal-index leg and a helper leg**; the editor specs look up a non-General tab by label and keep `tabs[0]` for General.
- **DW-2455: the scan also resets on a theme toggle and covers `agent-code-save` and `header-lockup` (`LOCAL_PASSES`), which measure without `detectScreen`**; `agent-picker`'s settle moved after its toggle, and the two files settle their restores. `system-explorer` takes the rail index from `appliedAreas` alone.

**Governing ADs (Rule 6):**

| Batch | ADs and conventions |
| --- | --- |
| a | AD-24, AD-36, AD-60, AD-61, AD-7; Conventions › Tests |
| b | AD-19, AD-5; Conventions › Tests |
| c | AD-12, AD-39, AD-19; Conventions › Theme |
| d | AD-5; Conventions › Tests |

No AC contradicts an AD. No read bound or envelope changes.

**Integration ACs (Rule 1).** No product service is introduced. `Bound.Apply` is consumed by the dispatch in Batch a's Integration AC, and by screen context through `Api/Turn.cls:570`.

Consumed-by (all Story 23.11):

- `real-timers.ts`: `log-viewer.spec.ts`, `home.page.spec.ts`.
- `scaleTypeTokens`: `home-system-information`, `text-reflow`.
- `MakeLargeClass`: `ExplorerWire`.
- `ArmTailGap`: `LogTail`.

Consumes: `FaultBanner`'s in-place mode (Story 23.5), and `settleViewport` and `transitionsSettled` (Story 23.5).

**Siblings (Rule 31):**

- The Guardrails store follows `Findings.load`, and its page and the tab follow `HomePage.systemFault`.
- `MakeLargeClass` sits beside `MakeClass`, and `ArmTailGap` beside `ArmTailThrow`.
- `real-timers.ts` promotes the wait copied in two specs, and `scaleTypeTokens` promotes Home's local technique.
- The settle sweep reuses `settleViewport` and `transitionsSettled`.

**Footprint (Rule 11).** Checked against Epic 20's outstanding diff (`OCU-1-epic20` at `5f40b92f` against feature `49d32222`). None of this story's files is contended, and `strings.ts` and EXPERIENCE.md are not edited.

- Batch a: `Kernel/Agent/Bound.cls`; `Test/ContextBound.cls`, `Test/ExplorerProbe.cls`, `Test/ExplorerWire.cls`, `Test/WireSecurityRead.cls`, `Test/SqlBackgroundJob.cls`, `Test/SqlPortDelayed.cls`, `Test/LogSourceFixture.cls`, `Test/LogTail.cls`.
- Batch b:
  - harness and config: `ui/src/app/testing/real-timers.ts` (new), `log-viewer.spec.ts`, `home.page.spec.ts`, `ui/browser.config.mjs`, `ui/browser/preferences-reset.mjs`;
  - tools tests: `browser-config.test.mjs`, `preferences-reset.test.mjs`, `ci.test.mjs` (comment), `screen-mirror.test.mjs`, `strings.test.mjs`;
  - ObjectScript tests: `Navigation.cls`, `NamespaceFeatures.cls`, `Wire.cls`, `ExplorerDescriptor.cls`;
  - `area-verdict.spec.ts`, and `docs/DEVELOPMENT.md` (`:483`).
- Batch c:
  - store and page code: `core/guardrails.ts`, `main.ts`, `guardrails.page.ts`, `web-app-class-access-tab.ts`, `testing/guardrails.ts`, `_components.scss`;
  - client tests: `guardrails.page.spec.ts`, `web-app-class-access-tab.spec.ts`, `ui/tools/guardrails.test.mjs`;
  - browser specs and helpers: `panel-spec.mjs`, `home-system-information`, `text-reflow` (new), `guardrails`, `web-applications-class-access`.
- Batch d: the 42 files, `proposal-card-spec.mjs`, `agent-code-save`, `header-lockup`, `read-back`, `permissions-effective`, the part-2 files, `ui/tools/browser-settle.test.mjs` (new), and `_components.scss` for any exposed overflow.

**Lead edits.** For the Planner (never an implement pass):

- `CLAUDE.md:129`: "`npm run test:browser` drives a pinned headless Chrome against the throwaway `OCUPILOT_BROWSER_ORIGIN` and `OCUPILOT_BROWSER_CONTAINER` name, and refuses to start unless both are set".
- `.claude/rules/objectscript-testing.md`'s redeploy block: "then re-run the spec with both browser variables set".

**Planned dispositions:** each entry `resolved-by:23-11-the-range-end-cleanup-part-10` with its batch's commit, DW-2202 at Batch d's.

**Named for filing:** 35 settled specs carry word-for-word local copies of `transitionsSettled` (inference: grep count).

## Verification

**Slot A.**

- The MCP profile is `ocupilot-slot-a`: the dev instance, never the throwaway.
- The throwaway is `ocupilot-ci` (dir `/Users/jbrandt/.ocupilot-throwaways/ocupilot-ci`, web 52776, super 1975). Use it only once it reads `healthy`, and never down it.
- Keep one test run in flight. Every command is `(loop)`; the runner runs the full ObjectScript sweep, and CI runs the full browser suite.
- Size each multi-spec call from `ui/tools/ci-timings.json` to about 8 minutes.

**Shared steps:**

- Load (loop): `rsync -a --delete src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-ci/src/`, then `Do $System.OBJ.LoadDir("/opt/ocupilot/src","ck-d",.e,1)` in `docker exec -i ocupilot-ci iris session iris -U HSCUSTOM`. Expected: 0 errors.
- Class (loop): `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`. Expected: 0 failed, confirmed in `%UnitTest_Result`.
- Deploy (loop): `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`. Expected: the prebuild checkers and the budgets pass.
- Spec (loop): `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/<name>.browser-spec.mjs …`, after Deploy. Expected: green.
- Checks (loop): `cd ui && npm run test:tools` and `cd ui && npm run test:components` green; `uv run scripts/check-objectscript.py <changed .cls>` clean; `bash scripts/lint-docs.sh` clean when Markdown changes.

**Shared surfaces:**

- The total cut: `ContextBound`, `ToolDispatch`, `Sanitize`, `ExplorerWire`, and the screen-context tests that assert `rowsSent` at a cap.
- The browser config: `browser-config.test.mjs`, `preferences-reset.test.mjs`, `ci.test.mjs:1595-1665`, `angular-json.test.mjs:290-312`, and every browser command (both variables).
- Fault copy: `guardrails.page.spec.ts`, `web-app-class-access-tab.spec.ts`, `ui/tools/guardrails.test.mjs`, `testing/guardrails.ts`, and both surfaces' browser specs.
- Fixed heights: any spec asserting a changed control's height. Sweep `ui/browser` and the `ui/src` specs for each selector.
- Fake timers: `home.page.spec.ts`.
- Structural passes: the 47 batch-d sweep files (the 42, `proposal-card-spec.mjs`, `agent-code-save`, `header-lockup`, `read-back`, `permissions-effective`).
- Side-bar, rail, tile and area counts: every DW-2202 file.

Every test added or changed passes on a fresh environment, in either order.

**Batch a (loop):**

- Run Load, then Class `ContextBound`, `ExplorerWire`, `ToolDispatch`, `Sanitize`, `WireSecurityRead`, `SqlBackgroundJob` and `LogTail`, one per call. Then Checks.
- `mutation:` step 3 of `Bound.Apply` writes once and drops no row (the loop's exit made unconditional). Expected red: `ContextBound.TestTheTotalCutMeasuresTheCountItWrites`, and `ExplorerWire.TestALargeClassViewIsCutByWholeRows`'s second dispatch (`TOOL.RESULTTOOLARGE`). Observed red (code review, runs 714 and 715), each the only failing test of its class: `ContextBound`'s answered-count and problems assertions at both edges, where `Apply` refused the ceilings 1 under the 10-row edge and 2 and 1 under the 100-row edge, and the second dispatch answered `TOOL.RESULTTOOLARGE`. Reverted: both green (runs 716 and 717).
- `mutation:` (QA) the final refusal in `Bound.Apply` made unreachable (`If $Length(pJson) > pTotalMax` replaced by `If 0`). Expected red: the row-free refusal, at the function and at the dispatch. Observed red (runs 698 and 699), each the only failing test of its class: `ContextBound.TestTheTotalSizeCutDropsTrailingRowsAndRefusesWhenNothingFits` ("a rowless payload that cannot fit is refused") and `ToolDispatch.TestAFailureInsideTheDispatchPathIsUnavailableAndLogged` ("a result over the cap once every row is dropped is refused").
- `mutation:` the `&taskId=` scope dropped from the both-pairs read, `pEveryFieldEquals` kept. Expected: the `TaskId` assertion red when the throwaway's history holds another task's run; otherwise record the task ids it held, as an honest null. Observed (QA, run 701): red at "nothing is cut at 1,000" and at "every row has TaskId 1003", the only failing test of 25; the throwaway's unscoped history read answered 1,000 rows, truncated, over 93 task ids.
- `mutation:` `Hang 1.5` in `SqlBackgroundDelayed.PortClass` (a slow check phase). Expected: the leg as it was (cancel on `startedAt`) red at "within three seconds"; the new leg green. Then `CANCELTRIES` 1. Expected: the new leg red. Observed: the leg as it was red at "the run reads canceled, with no answer" and "within three seconds" (12.18 s, run 12); the new leg green (12 of 12). With `CANCELTRIES` 1 (`SqlBackground` and its four subclasses recompiled) the new leg red at the same two (10.43 s, run 13; QA run 703, 10.47 s).
- `mutation:` `ArmTailGap`'s write-back dropped. Expected red: "an absent instant that ends unchanged is no change". `Tail` answering `changed` as soon as the file is absent. Expected: the leg red, as its existing mutation says. Observed red, the only failing test of 11: with the write-back dropped, at that assertion alone; with `Tail` answering at once (`LogSourcePort` and its three subclasses recompiled), at that assertion and "waited out to the bound", "no earlier" and the heartbeat count.

**Batch b (loop):**

- Run Checks; Load, then Class `Navigation`, `NamespaceFeatures`, `Wire` and `ExplorerDescriptor`. Run Spec for one browser spec with both variables set, and confirm `npm run test:tools` runs with neither set.
- `mutation:` a `setInterval(() => {}, 1000)` armed in `LogViewerPage`'s constructor. Expected red: AC6's count. Observed (Node 26.8.1): red at AC6's count ("1 fake timers pending, 8 real timers active, 8 when the clock was faked") and at Story 18.38 AC1's timer count, the only two failing tests of 78. Reverted, file byte-identical.
- `mutation:` a self-re-arming `setTimeout` poll in the same constructor. Expected red: AC6's count after the drain. Observed: red at the same two tests; reverted.
- `mutation:` a real `setInterval(() => setTimeout(() => {}, 1), 5)` started before AC6 and left running. Expected: with the async advance restored, AC6 red; with the fix, green. Observed: as written it reddens nothing, even on the spec as it stood before this pass (three runs green), because the drain passes clear the one-shot fake timers it arms. Applied as `setInterval(() => setInterval(() => {}, 1000), 5)`, which arms a fake interval no drain clears: the spec as it stood was red in both runs at AC6's count (2 fake timers pending, about 175 real timers active), the only failing test of 78, and the fixed spec was green in three. `log-viewer.spec.ts`, `home.page.spec.ts` and `area-verdict.spec.ts` ran green on Node 22.22.3, 24.15.0 and 26.8.1 (153 tests each).
- `mutation:` `env.OCUPILOT_BROWSER_ORIGIN ?? DEFAULT_ORIGIN` restored. Expected red: `browser-config.test.mjs`'s both-unset case. Observed: with one fallback restored alone, both-unset still refuses (the other variable is still unset); the red is "either variable alone, or an empty value, is refused" and `preferences-reset.test.mjs`'s "refused before any request", for the origin fallback and for the container's alike. With both fallbacks restored, the both-unset case is red too. Reverted.
- `mutation:` `const config = browserConfig();` restored at module scope in `preferences-reset.mjs`. Expected: `npm run test:tools` red at loading `preferences-reset.test.mjs`. Observed on that file alone, with both variables exported in the shell and with neither: it fails at load with the `browser.config` refusal, because the file clears both before its import. Reverted; the whole suite ran green with neither variable on Node 22.22.3, 24.15.0 and 26.8.1 (2,036 tests).
- `mutation:` in each DW-2202 file, its derived expectation off by one. Expected: that file's site red. Observed, each reverted byte-identical:
  - `screen-mirror.test.mjs` (`AREAS.length + 1`) -> "the mirror carries the kernel vocabulary, the areas and every descriptor"; `strings.test.mjs` (first area dropped) -> "the table's area-names row lists the navArea keys' values, in rail order".
  - `Navigation.cls` (`tDeclared.%Size() + 1`; `ExpectedAreaVerdicts` skipping the first area; the `> 0` floor raised to 1000) -> `TestThePayloadCarriesEveryAreaWithAVerdict`, both verdict rows of `TestAnAreaOpensWhenAnyScreenItListsIsAllowed` and `TestAGatedAreaNamesItsSetsFirstUnheldPairThenItsFirstListedScreens` (run 5, 3 of 14).
  - `NamespaceFeatures.cls` (`+ 1`) -> `TestThePayloadCarriesApplies` (run 6). `ExplorerDescriptor.cls` (`+ 1`) -> `TestTheAreaIsTheEighthRailItem` (run 7).
  - `Wire.cls` (area count `+ 1`; agent built count `+ 1`; `ExpectedScreens` skipping the first tasks screen) -> `TestTheNavigationMapGatesEveryAreaForARealPrincipal`, `TestTheAgentAreaNeverGatesWhileItsScreensGateOnOcuPilotsOwnResource` and `TestTheTaskScheduleIsDeniedToAPrincipalWithoutAdminTask` (run 8). `ExpectedScreens` without its `Hold` -> the web applications, tasks and processes legs (run 9).
  - `home.page.spec.ts` (`TILE_AREAS.slice(1)`) -> five tile tests; `area-verdict.spec.ts` (`expectedEntries` dropping its first entry) -> "a rail click on Logs and on OS management ...". With the two gated Logs routes opened in the map, the equality alone stays green and the Logs `some(gated)` assertion goes red; reverted.
  - The `> 0` floors added to `Navigation`, `NamespaceFeatures` and `Wire`, each raised to 1000 -> `TestAnAreaOpensWhenAnyScreenItListsIsAllowed` and `TestThePayloadCarriesEveryAreaWithAVerdict` (run 22), `TestThePayloadCarriesApplies` (run 23), `TestTheNavigationMapGatesEveryAreaForARealPrincipal` and `TestTheAgentAreaNeverGatesWhileItsScreensGateOnOcuPilotsOwnResource` (run 24). `ExpectedScreens("tasks")` named `"nosuch"` -> `TestTheTaskScheduleIsDeniedToAPrincipalWithoutAdminTask` (run 24). Reverted byte-identical; runs 25 to 27 green, confirmed in `%UnitTest_Result` on `ocupilot-ci`.
  - After the reverts, `Navigation`, `NamespaceFeatures`, `ExplorerDescriptor` and `Wire` were green (runs 10 to 13: 14, 5, 16 and 20 tests; `Wire` again in run 14 after a comment move), confirmed in `%UnitTest_Result` on `ocupilot-ci`.
- (QA) `ui/src/app/testing/real-timers.spec.ts` (new): pins `activeRealTimers` and `awaitRealTimersIdle` (3 tests, each arms and clears its own timers).
- (QA) `ui/src/app/areas/logs/log-viewer.spec.ts`: AC6 arms a real interval that arms a timer on the global clock whenever it fires, after the idle wait and before the clock is faked, and clears it in `finally`, so the foreign timer the Given names is constructed rather than left to test order.
- `mutation:` (QA) AC6's advance restored to `await vi.advanceTimersByTimeAsync(10 * 60 * 1000)`, the seeded interval in place. Expected red: AC6's count. Observed red in three runs of three, the only failing test of 78 (4 fake timers pending, 1 real timer active); the committed form is green on Node 22.22.3, 24.15.0 and 26.0.0 (156 of 156 with the new spec). Restored byte-identical (`cmp`).
- `mutation:` (QA) `activeRealTimers` counting `'Immediate'` in place of `'Timeout'` -> all three `real-timers.spec.ts` tests red. `awaitRealTimersIdle`'s loop made a no-op (`attempt < 0`) -> its due-timer and bounded tests red. Its `attempt < 50` bound dropped -> the bounded test red (CR: 7.3 s, at "the interval was still pending", once the interval ended itself). (CR) The bounded test's interval replaced by a no-op -> red at the same assertion. QA's reverted with `git checkout`; the review's restored byte-identical (`cmp`).
- `mutation:` (CR) Home's Story 15.4 settle restored to `await vi.advanceTimersByTimeAsync(0)`, its 1 ms foreign interval seeded. Expected: red. Observed: red in 5 of 5 runs ("expected 1 to be +0"); the committed form green in 5 of 5, and red when `HomePage`'s constructor arms an interval. `home.page`, `log-viewer`, `area-verdict` and `real-timers` specs green on Node 22.22.3, 24.15.0 and 26.0.0 (156 of 156). Restored (`cmp`).
- `mutation:` (CR) a member added: a listed os-management probe at position 23 (a copy of `MetricsList`) on `ocupilot-ci`. Expected: the reviewed `Wire` green, the batch's `Wire` red. Observed: green (run 708); the batch's `Wire.cls` red at the seven "listed last" splices of `TestTheProcessesListIsDeniedToAPrincipalWithoutAdminManage` (run 709). Probe deleted, `src` reloaded with 0 errors, `Wire` 20 of 20 and `Navigation` 14 of 14 green (runs 713, 714).
- `mutation:` (CR) `openableEntry`'s tab branch made unreachable. Expected red: the DW-1852 test. Observed: red at the entries' equality, the only failing test of 3; restored (`cmp`).
- `mutation:` (QA) `env.OCUPILOT_BROWSER_ORIGIN ?? DEFAULT_ORIGIN` restored -> `browser-config.test.mjs` "either variable alone, or an empty value, is refused" and `preferences-reset.test.mjs` "refused before any request" red, both-unset still refuses (the container is still unset); reverted. `developer-floor.browser-spec.mjs` with neither or only the origin set exits with the refusal (1 of 1 failed); with both set it passes.
- `mutation:` (QA) a member added, expected green, then the pre-batch files as the control. Area `zz-probe` (rail position 11, Agent moved to 12) added to `Area.cls` with its string, its EXPERIENCE.md name, a rail icon and a regenerated mirror. With no edit to any test: `screen-mirror.test.mjs` and `strings.test.mjs` (98 of 98), `home.page.spec.ts`, `area-verdict.spec.ts` and `log-viewer.spec.ts` (153 of 153), and `Navigation`, `NamespaceFeatures`, `ExplorerDescriptor` and `Wire` (runs 693 to 696: 14, 5, 16, 20) green. The pre-batch versions of those eight files against the same probe: red at the two tools tests, three `home.page.spec.ts` tests, `TestThePayloadCarriesEveryAreaWithAVerdict`, `TestThePayloadCarriesApplies`, `TestTheAreaIsTheEighthRailItem` and `TestTheNavigationMapGatesEveryAreaForARealPrincipal` (runs 697 to 700); `area-verdict.spec.ts` stayed green because the probe area lists no Logs or OS management screen.
- `mutation:` (QA) two built screens added, `permissions/zz-probe` listed at 5 and `logs/zz-probe` listed at 12 (copies of `ServiceList` and `LogMessageViewer`). `Wire` (run 703) and `area-verdict.spec.ts` green. `Navigation` red only at the Logs roster's own count ("which carries its eleven built screens", run 702), the roster pin the matrix row names; `log-viewer.spec.ts` and the read-note roster in `screen-mirror.test.mjs` also went red on the probe's route and note, rosters outside this batch's changed assertions. Probe files deleted, their two compiled classes deleted from `ocupilot-ci`, `src` reloaded with 0 errors (11 areas, 4 Permissions and 11 Logs listed screens), `Navigation` and `Wire` green (runs 704, 705).

**Batch c (loop):**

- Run Checks and Deploy. Then run Spec for `guardrails`, `web-applications-class-access`, `home-system-information` and `text-reflow`, each in light and dark.
- `mutation:` `inPlaceFault` answering the banner fault too. Expected red: `guardrails.page.spec.ts`'s status-0 case and `guardrails.browser-spec.mjs`'s status-0 leg (two alerts). Observed red, each the only failing test of its file: the page spec ("status 0 adds no alert of its own") and the browser leg, whose document held two alerts, the shell's and the page's; the 404 leg stayed green. Reverted (`cmp`).
- `mutation:` the same in the tab. Expected red: `web-app-class-access-tab.spec.ts` and the class-access status-0 leg. Observed red, each the only failing test of its file ("status 0 adds no alert of its own"; two alerts); the 404 leg stayed green. Reverted (`cmp`).
- `mutation:` the `retryWhenReachable` park dropped. Expected red: `ui/tools/guardrails.test.mjs`'s park case. Observed red: that case (1 of 13), and also `guardrails.page.spec.ts` ("status 0 is read again", 1 read for 2) and `guardrails.browser-spec.mjs`'s status-0 leg at its last wait (30 s). Dropped in the tab: `web-app-class-access-tab.spec.ts` and the class-access status-0 leg (30 s), each the only red in its file. Reverted (`cmp`).
- `mutation:` the unreadable answer recorded as `server-fault`. Expected red: its tools case and its page case. Observed red, each the only failing test of its file: `guardrails.test.mjs`'s classification case (1 of 13) and `guardrails.page.spec.ts`'s in-place case ("unreadable: one alert, the banner's own", 0 of 1). Reverted (`cmp`).
- `mutation:` each changed rule back to `height:`, one at a time (bundle rebuilt and redeployed). Expected red: `text-reflow`, naming that selector, in light and in dark. Observed: 27 of 28 red in both the light leg and the dark leg, each naming the rule's own selector. A rule with two selectors names both, and a rule whose element carries both classes names both (`.ocu-button-secondary`'s rule names `.ocu-classic-link-card-action`, and the card's own rule names `.ocu-button-secondary`). `.ocu-command-bar-refresh` (`:1746`) stayed green while its `line-height` was a fixed 32 px, which held its doubled 26 px text; code review made that line a minimum, and `text-reflow` now sees the chip (the (CR) line below). `design-tokens.test.mjs`'s DW-173 assertion, which now names `min-height`, reddens on it alone, as it does on `.ocu-header` (`:1098`) and the card action (`:2140`). Reverted (`cmp`).
- `mutation:` `.ocu-server-flag`'s `line-height` back to `16px`. Expected red: `text-reflow`, naming `.ocu-server-flag`. Observed red in both themes (content 21 px in a 16 px box), the only entry. Reverted (`cmp`).
- `mutation:` the agent picker fixture's host renamed. Expected red: `text-reflow`'s measured-selector assertion. Observed red in both themes, naming `.ocu-agent-picker-button` alone (0 elements). Reverted (`cmp`).
- `mutation:` `min-height: 0` deleted from `.ocu-panel-banner-link`, `.ocu-panel-warning-send`/`-edit` and `.ocu-log-explain`, one at a time. Expected red: `design-tokens.test.mjs`'s reset case. Observed red, the only failing test, each time; for the banner link the bundle was rebuilt and `suggested-view.browser-spec.mjs`'s DW-1154 leg read 34 px against the 32 px bound. Reverted (`cmp`).
- `mutation:` (CR) the tab's success-status unreadable answer left as `server-fault` (the `rejected` mapping dropped from `load`). Expected red: the tab's in-place case. Observed red, the only failing test of 12: "unreadable: one alert, the banner's own: expected 0 to be 1". Reverted (`cmp`).
- `mutation:` (CR) the tab's `destroyed` guard deleted. Expected red: its departed-tab case. Observed red, the only failing test of 12: "the parked read does not run for a departed tab: expected 2 to be 1". Reverted (`cmp`).
- `mutation:` (CR) `inPlaceFault` answering `null` for every fault, in the page and in the tab, each alone. Expected red: each component spec's in-place case. Observed red at "403: one alert, the banner's own", the only failing test of each. With both applied and the bundle rebuilt and redeployed, `guardrails` and `web-applications-class-access` were each red at their 404 leg's first wait (30 s), the other four green. Reverted (`cmp`).
- `mutation:` (CR) the `(retried)` binding dropped, in the page and in the tab, each alone. Expected red: each in-place case. Observed red at "403: Retry reads again: expected 1 to be 2", the only failing test of each. Reverted (`cmp`).
- `mutation:` (CR) the `connectivity` argument dropped at `main.ts:237` (bundle rebuilt and redeployed). Expected red: `guardrails.browser-spec.mjs`'s status-0 leg. Observed red at its last wait (30 s), the other four green. Reverted (`cmp`), bundle rebuilt and redeployed.
- `mutation:` (QA) `inPlaceFault` in the page and in the tab answering every fault but an unreachable one (bundle rebuilt and redeployed). Expected red: the two new 500 legs. Observed red, each the only failing test of its file (two alerts, the shell's and the surface's); the status 0 and 404 legs stayed green. Reverted (`git checkout`; the tree equals its pre-mutation diff).
- `mutation:` (QA) the `retryWhenReachable` park dropped in `Guardrails.load` and in the tab (bundle rebuilt and redeployed). Expected red: the 500 legs' last wait. Observed red at that wait (30 s) in the 500 leg and the status 0 leg of each file; the 404 leg stayed green. Reverted.
- `mutation:` (QA) `.ocu-side-bar-item` and `.ocu-command-bar-refresh` back to `height:` (bundle rebuilt and redeployed). Expected red: `text-reflow` for the side bar alone, `design-tokens.test.mjs` for the refresh chip alone. Observed: `text-reflow` red in both themes with 40 entries, all `.ocu-side-bar-item`, none for the chip; `design-tokens.test.mjs` red at its DW-173 case, the only failing test of 40. That held while the chip's `line-height` was a fixed 32 px (client 32 px, scroll 32/32/39/47 px at 1x to 4x); see the (CR) line below. Reverted.
- `mutation:` (QA) the dark leg of `text-reflow` drawn with `setDarkTheme(page, false)`. Expected red: the dark leg. Observed red, the only failing test, at "Home is drawn in the dark theme when it is measured" (`light` read); the light leg stayed green. Restored (`cmp`).
- `mutation:` (QA) `.ocu-data-table-row` and then `.ocu-log-row` on `min-height:` in place of `height:` (bundle rebuilt and redeployed each time). Expected red: `text-reflow`'s fixed-rows test. Observed red in both themes, naming the data-table row (73.8 px read, 36 px expected) and the log row (73.8 px, 28 px); the control test stayed green. Reverted.
- (QA) `ui/browser/text-reflow.browser-spec.mjs`: `drawnTheme` asserts the theme each leg claims is the one drawn, and a fixed-rows test pair (light, dark) pins `:912`'s virtualized rows at doubled type. `ui/browser/panel-spec.mjs`: `interceptRead` gains a `'fault'` mode (500). `ui/browser/guardrails.browser-spec.mjs` and `ui/browser/web-applications-class-access.browser-spec.mjs`: one 500 leg each (the shell's banner is the one alert; the shell's Retry reads again). No file created.
- `mutation:` (CR) `.ocu-command-bar-refresh` back to `height:`, its `line-height` now `max(var(--ocu-control-height), calc(var(--ocu-type-body-line-height) * 1em))` (bundle rebuilt and redeployed). Expected red: `text-reflow`, naming the chip. Observed red in both themes (2 of 4, the fixed-rows pair green): the chip, which is also `.ocu-button-text`, read 73 px of content in a 32 px box on Home, before and after the fixtures went in, and on Task schedule. Reverted (`cmp`), rebuilt and redeployed.
- `mutation:` (CR) the chip's `line-height` back to `var(--ocu-control-height)`. Expected red: `design-tokens.test.mjs`'s DW-173 case. Observed red, the only failing test of 40. Reverted (`cmp`).
- (CR) Final state on `ocupilot-ci`, bundle rebuilt and redeployed: `guardrails` 6 of 6, `web-applications-class-access` 6 of 6, `home-system-information` 8 of 8, `text-reflow` 4 of 4. `npm run test:tools` with neither variable set 2,039 of 2,039; `npm run test:components` 3,278 of 3,278; initial bundle 1.96 MB, under the budgets.

**Batch d (loop):**

- Run Checks and Deploy. Then run Spec for every batch-d file, in calls of about 8 minutes.
- `mutation:` the diff-row wrap rule after `.ocu-diff-arrow` deleted (bundle rebuilt and redeployed). Expected: `impact`'s settled AC2 pass red; with its settle removed, green. Observed: red at the agent's role delete test (`app-long-block>span.ocu-diff-before: 127px past its containing block`), the only failing test of 5; with its `transitionsSettled` call also removed, green (5 of 5). Reverted (`cmp`), bundle rebuilt and redeployed.
- `mutation:` one swept file's `transitionsSettled` call removed. Expected red: `browser-settle.test.mjs`, naming the file and line. Observed red, the only failing test, naming `locks.browser-spec.mjs:205`, and for `proposal-card-spec.mjs` `:46`; the scan's reset on a viewport change dropped -> "a viewport change after the settle asks for a new one" red; its reset on a theme toggle dropped -> "a theme toggle after the settle asks for a new one" red; `agent-picker`'s settle put back before its theme toggle -> the shipped-specs test names `agent-picker.browser-spec.mjs:141`; `header-lockup`'s restore settle removed -> "the specs that measure without detectScreen settle after every viewport change" names `:244`. Reverted (`cmp`).
- `mutation:` in each DW-2202 part-2 file, the derived index off by one. Expected: that file red. Observed, each reverted (`cmp`):
  - `indexOf(label) + 1` in `assertDrawnAtDeclaredIndex`: the 20 files that call it each red at one test (14 of 47 and 6 of 21 tests); `side-bar-pins.test.mjs`'s helper leg red.
  - `slice(1, n + 1)` on the derived side in `local-databases` and `namespaces`; the previous rail neighbour read from `applied[explorerIndex]` and the caption's `.slice(1)` in `system-explorer`; an offered tab label the strip lacks in the three editors (web applications also reddens its visual gate): each red at its own test.
  - A literal `bar.entries[12]` back in `journals`: `side-bar-pins.test.mjs` names `journals.browser-spec.mjs:281`. HEAD's `entries.slice(0, 7)` against a literal list back in `oauth`: leg 2 names `oauth.browser-spec.mjs:298`.
- `mutation:` `.ocu-proposal-card-title`'s `min-width: 0` and `overflow-wrap: anywhere` removed (bundle rebuilt and redeployed). Expected red: the 720 px pass of `cardViolations`. Observed red: `agent-code-create` (`countdown: 20px past its containing block`), `agent-code-save` (2 tests, 47 px) and `guided-workflow` (45 px), before the fix and again under this mutation (`agent-code-create`); green with it (16 of 16). Reverted (`cmp`), bundle rebuilt and redeployed.
- `mutation:` (CR) AC2: `os-management/license-usage` moved to the end of the mirror (`sideBarPosition` 99, built with `ng build` to skip the mirror check, bundle redeployed), which shifts 14 entries. Expected: the batch's os-management specs green with no edit, their pre-batch versions red. Observed: `journals`, `journal-settings`, `license-key`, `license-servers`, `license-usage`, `ecp-settings`, `ecp-application-servers`, `ecp-data-servers`, `remote-databases`, `prometheus-metrics`, `interop-usage`, `local-databases` and `namespaces` green, 54 of 54; the HEAD versions of eight of them red in 7 of 38 tests at their literal positions (`namespaces` sits before the moved entry and stayed green). Mirror restored (`cmp`), bundle rebuilt and redeployed.

## Auto Run Result

Status: done
Blocking condition: none

Batch d (DW-2455, DW-2202 part 2, DW-2470), implement, review and finalize. It is the story's last batch.

- **Change.**
  - DW-2455: 49 passes in 46 files settle their viewport with `settleViewport` and wait on `transitionsSettled` after the theme toggle; `cardViolations` lost its ignored edge wait. The settled 720 px pass exposed one overflow, `.ocu-proposal-card-countdown` 20 to 47 px past the card header, fixed in `.ocu-proposal-card-title` (`min-width: 0`, `overflow-wrap: anywhere`). New `ui/tools/browser-settle.test.mjs` scans the 82 specs that call `detectScreen(` and the two `LOCAL_PASSES`.
  - DW-2202 part 2: `assertDrawnAtDeclaredIndex` (new, `side-bar-spec.mjs`) is called by 20 specs in place of their literal indexes; five prefix pins are dropped and two derived; `system-explorer` and the three editor specs derive or lose their positions, and titles lose their ordinals. `side-bar-pins.test.mjs` gains a no-literal-index leg, a helper leg and a `.slice` form in leg 2.
  - DW-2470: `.ocu-guardrails-fault` is out of its shared selector; `grep -rn ocu-guardrails-fault ui/` is empty.
- **Review.** Layers: verification-gap and intent-alignment. 16 findings: medium 1, low 14, false 1. Patched 7 entries (1 medium, 6 lows), rejected 7 with reasons in the Review Triage Log, deferred none. `followup_review_recommended` is false. The frontmatter's `.ocu-guardrails-fault` deferral is removed, since this batch fixed it.
- **Verification.** `npm run test:tools` with neither variable set: 2,060 of 2,060. `npm run test:components`: 3,290 of 3,290. On `ocupilot-ci`, every changed spec file ran green on the built bundle (333 tests in 8 calls), the 8 files the patches touched ran 42 of 42, and 7 files re-ran 25 of 25 on the rebuilt final bundle. The final `npm run build` passes its checkers and the budgets. `lint-docs.sh` is clean. Every `mutation:` line was observed red and reverted.
- **Paths beyond the Footprint list.** `ui/browser/side-bar-spec.mjs`, `ui/tools/side-bar-pins.test.mjs`, `ui/browser/agent-picker.browser-spec.mjs` and `ui/browser/openapi-try-it.browser-spec.mjs`; none is among Epic 20's uncommitted files (`structural-walk.mjs`, `analytics.browser-spec.mjs`, `screen-mirror.mjs` and four `ui/tools` tests).
- **Residual risk.** After Epic 20 merges, `browser-settle.test.mjs` scans its new `analytics.browser-spec.mjs`; a pass there that measures after a viewport change without a settle reddens it, and the fix is the same two calls.
