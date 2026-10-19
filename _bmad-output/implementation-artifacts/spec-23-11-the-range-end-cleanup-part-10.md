---
title: 'Story 23.11: The range-end cleanup, part 10'
type: 'bugfix'
created: '2026-10-15'
status: 'done'
baseline_revision: '4dba7011b5b40b35401c6c68304698470b109e0e'
baseline_commit: 'a69613d295e28b1fcbf3ff6ca63816c28cbf183e'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['multiple-goals', 'oversized']
deferred: []
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
  - `SqlRun.GuardedFinish` ends a cancel-flagged row `canceled`. The red this fixes is therefore the 3 s bound (inference).
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

### Batch b: the client test harness

- [ ] **DW-2458: AC6 never yields to the real loop while it counts.**
  - New `ui/src/app/testing/real-timers.ts` exports `activeRealTimers()` and `awaitRealTimersIdle()` (the bounded 50 × 20 ms wait). Both `log-viewer.spec.ts` and `home.page.spec.ts` import them in place of their copies.
  - In AC6, the advance is `vi.advanceTimersByTime(10 * 60 * 1000)` followed by `await settle()`. Each drain pass is `vi.runOnlyPendingTimers()` followed by `await settle()`. The count and its message are unchanged.
  - The comment states this contract in at most eight lines.
- [ ] **DW-2221: the browser tier needs both variables.**
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
- [ ] **DW-2202, part 1: derive the counts outside their roster.**
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

### Batch c: styles and fault rendering

- [ ] **DW-2449: a banner fault adds no alert of its own.**
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
- [ ] **DW-2439: text-bearing heights are minimums.**
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

### Batch d: the narrow-pass settle sweep and the browser-spec literals

- [ ] **DW-2455: every structural pass measures the settled layout.**
  - In each of the 42 files, the pass loop sets its viewport with `settleViewport(page, viewport)`. After the theme toggle it awaits `transitionsSettled(page, config.navigationTimeoutMs)` before `detectScreen`. Both helpers are imported from `panel-spec.mjs`.
  - The same applies to `cardViolations` (drop its ignored edge wait), the local loop in `agent-code-save:305-310`, and `header-lockup:231`.
  - `read-back:102` and `permissions-effective:148` call the shared `transitionsSettled`.
  - Any overflow a settled pass exposes is fixed in this batch, in CSS, and that pass is its pin.
  - New `ui/tools/browser-settle.test.mjs` scans each `ui/browser/*.mjs` that calls `detectScreen(`. Between the last viewport change (`setViewport(` or `settleViewport(`) and each `detectScreen(` call, in text order, there must be a `transitionsSettled(` or `panelSettlesAt(` call. A file it flags beyond the 47 is settled the same way.
- [ ] **DW-2202, part 2: derive the browser specs' positions.**
  - Each positional pin reads its index as `sideBarLabels(area).indexOf(<label>)`, asserts it is at least 0, and asserts the drawn entry at that index carries the label.
  - Each prefix pin compares against `sideBarLabels(area).slice(0, n)`, or is dropped where the spec's derived full-list check already covers the side bar. Record which.
  - `system-explorer:132` takes the area's index in `AREAS`' rail order. `system-explorer:143-145` joins `sideBarLabels('system-explorer')`.
  - The three editor specs stop pinning the whole strip and assert only the tabs they open, by their `STRINGS` label. The page specs stay the strips' one pin.

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

## Design Notes

**Verdicts at head `a69613d2`** (Rule 17 inbox):

| Entry | Verdict | Evidence | Batch |
| --- | --- | --- | --- |
| DW-2246 | confirmed | Measured below; the window was reproduced on `ocupilot` | a |
| DW-2182 | confirmed | `WireSecurityRead.cls:497` is unscoped and `:1099` asserts `truncated` 0. `ocupilot` holds 3,555 task-history rows; `ocupilot-b-ci` held 1,224. | a |
| DW-2460 | confirmed (inference) | The cancel's window is about 2 s from `startedAt`, while the query starts after gate + `Check` + 1 s + prepare. A run missed by the retries reaches the 3 s bound. | a |
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
- **DW-2460, DW-2462: the race moves out of the test.** The product is unchanged. A cancel the retries miss still ends at the port's bound and reads canceled (`GuardedFinish`). A file deleted mid-look reads as a change, which the viewer's next page read reports.
- **Batches:** DW-2455 and DW-2202's browser-spec sites share batch d, because both are browser-spec sweeps over overlapping files.

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
- `mutation:` the drop loop removed from `Bound.Apply`. Expected red: `ContextBound.TestTheTotalCutMeasuresTheCountItWrites`, and `ExplorerWire.TestALargeClassViewIsCutByWholeRows`'s second dispatch (`TOOL.RESULTTOOLARGE`). Observed red, each the only failing test of its class: `Apply` refused the ceilings 1 under the 10-row edge and 2 and 1 under the 100-row edge, and the second dispatch answered `TOOL.RESULTTOOLARGE`. With the loop's exit made unconditional (run 26), the test's answered-count and problems assertions both red, the only failing test of 15.
- `mutation:` the `&taskId=` scope dropped from the both-pairs read, `pEveryFieldEquals` kept. Expected: the `TaskId` assertion red when the throwaway's history holds another task's run; otherwise record the task ids it held, as an honest null. Observed: red at "every row has TaskId 1003"; the throwaway held 52 history rows over 21 task ids, the demo task's 3. The 1,000-row bound itself is not reproduced there.
- `mutation:` `Hang 1.5` in `SqlBackgroundDelayed.PortClass` (a slow check phase). Expected: the leg as it was (cancel on `startedAt`) red at "within three seconds"; the new leg green. Then `CANCELTRIES` 1. Expected: the new leg red. Observed: the leg as it was red at "within three seconds" (12.18 s); the new leg green (12 of 12). With `CANCELTRIES` 1 (`SqlBackground` and its four subclasses recompiled) the new leg red (10.43 s).
- `mutation:` `ArmTailGap`'s write-back dropped. Expected red: "an absent instant that ends unchanged is no change". `Tail` answering `changed` as soon as the file is absent. Expected: the leg red, as its existing mutation says. Observed red, the only failing test of 11: with the write-back dropped, at that assertion alone; with `Tail` answering at once (`LogSourcePort` and its three subclasses recompiled), at that assertion and "waited out to the bound", "no earlier" and the heartbeat count.

**Batch b (loop):**

- Run Checks; Load, then Class `Navigation`, `NamespaceFeatures`, `Wire` and `ExplorerDescriptor`. Run Spec for one browser spec with both variables set, and confirm `npm run test:tools` runs with neither set.
- `mutation:` a `setInterval(() => {}, 1000)` armed in `LogViewerPage`'s constructor. Expected red: AC6's count.
- `mutation:` a self-re-arming `setTimeout` poll. Expected red: AC6's count after the drain.
- `mutation:` a real `setInterval(() => setTimeout(() => {}, 1), 5)` started before AC6 and left running. Expected: with the async advance restored, AC6 red; with the fix, green.
- `mutation:` `env.OCUPILOT_BROWSER_ORIGIN ?? DEFAULT_ORIGIN` restored. Expected red: `browser-config.test.mjs`'s both-unset case.
- `mutation:` `const config = browserConfig();` restored at module scope in `preferences-reset.mjs`. Expected: `npm run test:tools` red at loading `preferences-reset.test.mjs`.
- `mutation:` in each DW-2202 file, its derived expectation off by one. Expected: that file's site red.

**Batch c (loop):**

- Run Checks and Deploy. Then run Spec for `guardrails`, `web-applications-class-access`, `home-system-information` and `text-reflow`, each in light and dark.
- `mutation:` `inPlaceFault` answering the banner fault too. Expected red: `guardrails.page.spec.ts`'s status-0 case and `guardrails.browser-spec.mjs`'s status-0 leg (two alerts).
- `mutation:` the same in the tab. Expected red: `web-app-class-access-tab.spec.ts` and the class-access status-0 leg.
- `mutation:` the `retryWhenReachable` park dropped. Expected red: `ui/tools/guardrails.test.mjs`'s park case.
- `mutation:` the unreadable answer recorded as `server-fault`. Expected red: its tools case and its page case.
- `mutation:` each changed rule back to `height:`, one at a time (bundle rebuilt and redeployed). Expected red: `text-reflow`, naming that selector, in light and in dark.

**Batch d (loop):**

- Run Checks and Deploy. Then run Spec for every batch-d file, in calls of about 8 minutes.
- `mutation:` the diff-row wrap rule after `.ocu-diff-arrow` deleted (bundle rebuilt and redeployed). Expected: `impact`'s settled AC2 pass red; with its settle removed, green.
- `mutation:` one swept file's `transitionsSettled` call removed. Expected red: `browser-settle.test.mjs`, naming the file and line.
- `mutation:` in each DW-2202 part-2 file, the derived index off by one. Expected: that file red.

## Auto Run Result

Status: done
Blocking condition: none

Batch a (DW-2246, DW-2182, DW-2460, DW-2462), review and finalize. Batches b, c and d are later passes.

- **Change.** `Bound.Apply` step 3 writes the kept rows with the count they report and drops the last kept row while the written payload is over the ceiling, so the class read answers whole rows at any share. Three ObjectScript tests are made deterministic: the both-pairs task history reads one task's runs (`WireSecurityRead`), the early-cancel leg waits for the job inside the delayed port (`SqlBackgroundJob`, `SqlPortDelayed`), and the absent-file leg arms its gap between looks (`LogSourceFixture.ArmTailGap`, `LogTail`). New tests: `ContextBound.TestTheTotalCutMeasuresTheCountItWrites`, `ExplorerWire.TestALargeClassViewIsCutByWholeRows`, with `ExplorerProbe.MakeLargeClass`.
- **Review.** Layers: verification-gap and intent-alignment. 13 findings: low 6, false 7. Patched 3 lows (the `LogTail` header, the DW-2182 `mutation:` line, the `ContextBound` answered-count assertion), rejected 10 with reasons in the Review Triage Log, deferred none. `followup_review_recommended` is false.
- **Verification.** On `ocupilot-ci` after reloading `src` (0 errors): `ContextBound` 15 of 15 (run 27, green), `LogTail` 11 of 11 (run 28), confirmed by SQL on `%UnitTest_Result`. The patched assertion was falsified with the loop's exit made unconditional: red in run 26, the only failing test, then `Bound.cls` restored from git and reloaded. `ExplorerWire`, `ToolDispatch`, `Sanitize`, `WireSecurityRead`, `SqlBackgroundJob`, `TurnContext` and `ScreenGrounding` were run green by the implement pass and are untouched since. `uv run scripts/check-objectscript.py` on the nine changed classes: 0 problems.
- **Residual risk.** DW-2182's 1,000-row bound is not reproduced on any throwaway; the scoped read is pinned by its `TaskId` assertion, which can fail only where another task has history.
