---
title: 'Story 20.33: The MDX query tool'
type: 'feature'
created: '2026-10-14'
status: 'draft'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** An analytics developer who wants to query a cube still opens the classic MDX Query Tool. That tool has no time bound, no cancel button and no owner check: the vendor's `%CancelQuery` stops anyone's query by its cube and key (measured). OcuPilot has the analytics port (Story 20.11, planned) but no way to run MDX.

**Approach:**

- A listed Analytics screen, **MDX query**, where a person writes one MDX statement and runs it.
- The run is an **owner-scoped background run**: the SQL console's background run (Story 19.15), extended to a second kind rather than copied. It has a row cap, a time bound and cancel.
- The answer renders as a grid of axis labels and cells. A cell drills through to the vendor's listing for that cell, and a `DRILLTHROUGH` statement shows its listing directly.
- `AnalyticsPort` gains the MDX calls behind its own gate (AD-65). OcuPilot writes nothing to the instance of its own. A statement whose text the vendor would splice into SQL or evaluate as code (`%SEARCH`, `%SQLRESTRICT`, `RETURN`, `%ORDER`) runs only after the person confirms, in a confirmation that names the consequence in plain words: "This query runs server-side code or SQL with your rights." A statement without them runs as a plain read. (Orchestrator ruling Q2 C, 2026-10-14, the owner's developer-tool-first rule; AD-65. The classic page runs them unasked, so this is stricter than the vendor.)

## Boundaries & Constraints

**Always:**

- **Gate first (AD-29, AD-65)**, before any vendor call, in the start request and again in the job:
  1. the screen's pairs, the classic page's custom resource included;
  2. `AnalyticsPort`'s own pairs, `MDXPAIRS`;
  3. the namespace's shape, and that the namespace reports analytics (else 409 `ANALYTICS.NAMESPACE`);
  4. READ on the namespace's globals and routines databases;
  5. WRITE on the database that `^DeepSee.Cache.Results` maps to in that namespace (`%SYS.Namespace.GetGlobalDest`), and that database mounted read-write (else 409 `ANALYTICS.MDX.READONLY`).

  A refusal names the failed pair.
- **The statement is untrusted text.** It reaches only `%DeepSee.ResultSet.%PrepareMDX`. Before prepare, the port detects any text that names `%SEARCH`, `%SQLRESTRICT`, `RETURN` or `%ORDER`, case-insensitive, anywhere (the vendor splices those into SQL or evaluates them as ObjectScript; Design Notes › Measured) and runs it only when the start request carries the person's confirmation of that consequence; without it the start answers that confirmation is needed, naming the consequence, and nothing runs. Both paths are pinned by tests, the measured `%SEARCH.&[...{$Increment(^g)}]` case among them: not run until confirmed, then run. After prepare, only `queryType` `SELECT` (at most two axes) and `DRILLTHROUGH` run. `CREATE`, `DROP` and `%BITSET` are refused 422 `ANALYTICS.MDX.KIND`, and three or more axes 422 `ANALYTICS.MDX.AXES`.
- **A drill-through is composed on the instance.** From the person's original statement and a cell's ordinals (its 1-based row and column positions, as the cells answer lists them), the job re-prepares the statement, reads the vendor's own `%GetFiltersForCellRange` for that one cell, and runs `DRILLTHROUGH MAXROWS <MDXMAXLISTINGROWS> SELECT FROM [<cube>] %FILTER <f>…`. Nothing from the client enters that text except the original statement, which has passed the checks above.
- **Named limits (AD-7), all on `AnalyticsPort`, each with its reason:**
  - `MDXMAXSTATEMENT` is 100,000 characters;
  - `MDXMAXROWS` is 1,000 row positions read and `MDXMAXCOLUMNS` 100 column positions;
  - `MDXMAXLISTINGROWS` is 1,000 listing rows;
  - `MDXMAXCELL` is 1,000 characters a cell and `MDXMAXANSWER` 1,000,000 characters in all;
  - `MDXSECONDS` is 120, the time bound;
  - `MDXSETTLESECONDS` is 10.

  A truncated answer says so. At the bound, or on the owner's cancel, the job calls `%CancelQuery` and waits up to `MDXSETTLESECONDS` for the vendor to report the query finished. A stopped or canceled run leaves no job and no vendor worker running it.
- **Owner-scoped (AD-7, AD-33, AD-41).** The run row is `Kernel.State.SqlRun` with `Kind` `mdx`. Another user's run, an unknown id and a swept run answer the same 404. A user has at most one live run per kind, and the instance at most five of all kinds together. The statement is never stored or logged. The answer, including the vendor's error text, which can quote part of the statement as the SQL console's errors do, is held for its owner's poll alone, then swept after 900 s.
- **Screen-only payload (AD-36, AD-39's sixth exception).** Cells, labels, listings and the vendor's error text reach the screen only, rendered as interpolated text. They never reach screen context, a read tool, the model, the ledger or a log line.
- **Extend, don't copy (Rule 31).**
  - The route and job machinery moves from `Area/Explorer/SqlBackground` into a kernel class that both slices extend.
  - The client's background-run polling moves from `SqlQueryState` into `core/background-run.ts`.
  - The SQL page's result grid moves into `shell/result-grid.ts`.
  - `SqlPort.Executed`'s fetch loop becomes a public `SqlPort.FetchRows`.
  - The SQL console's behavior and DOM are unchanged.
- **Contended files take add-only edits** (Design Notes › Rule 11).

**Never:**

- No call to `/api/deepsee`, `%Api.DeepSee` or `%DeepSee.REST.*`. The statement is never written to a log line, an audit row or the run row.
- No write tool, governance key, row action, proposal or read tool. The agent's MDX read is Story 20.35 (orchestrator ruling Q1 A), which refuses those four constructs with `ANALYTICS.MDX.SQL`.
- AD-65's Never list stands: no `%GetMemberTree`, `%GetDimensionMembers` or `%GetFavoritesForUser`, and no member-value read.
- No session state: `CREATE`/`DROP` are refused, and nothing is kept between runs except the vendor's own cache.
- No `$System.Process.Terminate` in product code, and no product code reads or writes `^DeepSee.Cache.*` directly (the fixture's cleanup is a test's).
- No edits to `app.routes.ts`, `angular.json`, `Kernel/Proposal/Prohibited.cls`, `Kernel/Governance/Baseline.cls`, `.github/workflows/ci.yml`, `ui/tools/ci-shards.mjs`, `ui/tools/ci-timings.json`, `ui/tools/ci.test.mjs`, `epics.md` or the spine. The lead writes the spine drafts.

## I/O & Edge-Case Matrix

Rows run in USER on `ocupilot-b-ci` with `AnalyticsProbe` (20.11, planned) created there, as `_SYSTEM` unless named. "Start" is `POST /api/ocupilot/analytics/mdx/background?ns=USER`.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Cells | Start a SELECT over `OcuPilotProbeVisits` with one of its measures on columns and its category level's members on rows (the names 20.11's fixture declares), then poll | 202 `{id, status: running}`. Then `ended` with `result {outcome: "cells", cube, columns, rows: [{label, cells}], rowsAvailable, columnsAvailable, truncated: false, seconds}`. Labels and cells equal the vendor's `%GetOrdinalLabel`/`%GetOrdinalValue` for that statement | - |
| Cell drill | Start `{statement: <same>, drill: {row: 2, column: 1}}` | `ended`, `result {outcome: "rows", columns, rows, truncated}`. The rows equal the vendor's listing for the composed `DRILLTHROUGH … %FILTER` of that cell, at most 1,000 | - |
| Typed drill | `DRILLTHROUGH SELECT FROM [OcuPilotProbeVisits]` | The cube's default listing, at most 1,000 rows, `truncated` when the source holds more | - |
| Row cap | A members set with more than 1,000 positions on rows | 1,000 rows, `rowsAvailable` the axis size, `truncated` true | - |
| Cancel | Start the grid crossjoin (Task 0's slow query); cancel after 1 s | `canceled` within 12 s. The job's pid is gone, `%GetQueryStatus` reads 100, and no process in USER runs `%DeepSee` code | - |
| Bound | The same query through the fixture whose `BoundSeconds()` is 2 | `ended`, `result {outcome: "stopped", seconds: 2}`, and nothing running, as above | - |
| Syntax | `SELECT FROM [OcuPilotProbeVisits` | 200 `{outcome: "error", message}` with the vendor's text, before any spawn | - |
| Kind | `CREATE MEMBER [OcuPilotProbeVisits].[Measures].[X] AS '1'` | Nothing spawned | 422 `ANALYTICS.MDX.KIND` |
| Axes | Three axes (`ON 2`) | Nothing spawned | 422 `ANALYTICS.MDX.AXES` |
| Spliced | Text naming `%SEARCH`, `%SQLRESTRICT`, `RETURN` or `%ORDER` | Nothing prepared | 422 `ANALYTICS.MDX.SQL` |
| Input | Empty text, over 100,000 characters, or a `drill` that is not two positive integers within the caps | Nothing prepared | 400 `ANALYTICS.MDX.INPUT` |
| Busy | A second start while the first runs | Nothing spawned | 409 `ANALYTICS.MDX.BUSY`, `detail.runId` names the live run |
| Kinds apart | An MDX run live; the same user starts a SQL background run | The SQL run starts. Five live runs of any kind refuse a sixth start of either kind | 503 `ANALYTICS.MDX.FULL` or `EXPLORER.SQL.BACKGROUND.FULL` |
| Not yours | Another user polls or cancels the id | The same body as an unknown id. The owner's run is unchanged | 404 `ANALYTICS.MDX.NOTFOUND` |
| No analytics | Start in HSCUSTOM | No vendor call | 409 `ANALYTICS.NAMESPACE` |
| Read-only cache | Start in HSLIB, whose database is read-only | No vendor call | 409 `ANALYTICS.MDX.READONLY` |
| No WRITE | A principal holding `%DB_USER:R` (not W), `%Development:USE` | Refused before any vendor call, which would answer `<PROTECT>` | 403 `AUTH.NOPRIVILEGE`, `failedPair` `%DB_USER:WRITE` |
| No pair | A principal without `%Development:USE` | Refused | 403 naming `%Development:USE` |
| No SQL grant | P3 (RW, `%Development`, no SELECT on the probe source) drills a cell | `ended`, `{outcome: "error", message}` carrying the vendor's SQLCODE -99 text | - |

</intent-contract>

## Code Map

All paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-20`. Line numbers were read at `3a8d6867d35bf5ce744cf5b9810d1e385ee37fed`. Stories 20.11 and 20.32 land first. Their symbols are marked **(20.11, planned)** and **(20.32, planned)**, and Task 0 re-anchors them.

### The sibling to extend: the SQL console's background run (Story 19.15)

- **`src/OcuPilot/Area/Explorer/SqlBackground.cls`** (448 lines):
  - parameters: `DESCRIPTORCLASS` :25, `CONSOLECLASS` :28, `STORECLASS` :31, `SPAWNTIMEOUT` 5 :34, `IDPATTERN` :38, `CANCELSECONDS` 3, `CANCELTRIES` 10 and `CANCELPAUSE` 0.2 (:41-47), `LOGSUBSYSTEM` :53;
  - seams: `PortClass` :56, `MaxRunning` :62, `LimitsClass` :68;
  - routes: `HandleStart` :80 (SQL-specific checks :84-111), `HandlePoll` :134, `HandleCancel` :156;
  - the job: `Start` :192 (reserve, then spawn), `Spawn` :231 (the one `JOB`, :234, hands `$ClassName()` to the job), `Run` :249 (the SQL-specific part is :280-301), `FinishRefused` :312;
  - `Cancel` :332, the `$SYSTEM.SQL.CancelQuery` retry loop;
  - `View` :360, the faults `QueryOnly`/`Busy`/`Full`/`NotFound`/`Lost` :370-408, `Envelope`, `Render`, `Finish` and `Log` :411-446.
- **`src/OcuPilot/Area/Explorer/SqlConsole.cls`**: `Read` :126, `Check` :151, `Gate` :226 (`Screen.Gate.Evaluate` on the descriptor, then `Kernel.Denial.Envelope`), `RenderFault` :243.
- **`src/OcuPilot/Kernel/State/SqlRun.cls`**:
  - properties :39-69 (`RunKey`, `UserName`, `Namespace`, `State`, `JobId`, `CancelRequested`, timestamps, `Answer`);
  - `GuardedReserve` :91. Its live-row select is :104, the per-user busy check :111, the cap :116 and the ended-row delete :120.
  - `GuardedBegin` :142, `GuardedFinish` :183, `GuardedCancel` :221, `GuardedViewForOwner` :266, `GuardedSweep` :302, `Reconcile` :341, `LockHeld` :382, `IdForOwner` :396.
- **`src/OcuPilot/Kernel/Agent/Limits.cls`**: `RETENTIONSECONDS` 900 :28, `QUEUEDSECONDS` 10 :60. **`Kernel/Retention.cls`**:61 sweeps runs daily.
- **`src/OcuPilot/Port/SqlPort.cls`**: `MAXSTATEMENT` :89, `MAXROWS` :95, `MAXCELL` :105, `MAXANSWER` :107; `BoundSeconds` :321; `Executed` :1013, whose fetch loop :1049-1097 becomes `FetchRows`.
- **`src/OcuPilot/Api/Router.cls`**: routes :244-246 (the `:id` routes first), and the handlers :1812-1832.
- **`src/OcuPilot/Api/AtelierError.cls`** :172-200: the five `EXPLORER.SQL.BACKGROUND.*` codes, each with its `REASON*`. They are the shape for the MDX codes.
- **`scripts/check-objectscript.py`**: `JOB_ALLOWED` :863 (prose :159, :858). **`scripts/test_check_objectscript.py`** :1057-1059 names `SqlBackground` as an allowed spawn site.

### Analytics (planned)

- **`src/OcuPilot/Port/AnalyticsPort.cls`** **(20.11, planned)**: `PORTALPAIRS`, `Pairs`, `GateClass()`, `Admit` (the gate order), private `Deny`/`Refuse`/`Conflict`, and the `<PROTECT>` mapping.
- **`src/OcuPilot/Api/AnalyticsError.cls`** **(20.11, planned)**: `NAMESPACE`, `REASONNAMESPACE`.
- **`src/OcuPilot/Kernel/Shell/Namespaces.cls`**: `GlobalDatabase` :84, `RoutineDatabase` :92. **`Kernel/Shell/NamespaceFeatures.cls`** `Reports` :26.
- **`src/OcuPilot/Screen/Descriptor/ExplorerSqlQuery.cls`** is the descriptor sibling: a `form-page` with no read and no context.
- **The Cubes list** `analytics.cubes` **(20.11, planned)**. Its read is the cube picker's.
- **Side-bar positions**: 20.11 takes 1-3 and 20.32 takes 4-6 **(20.32, planned)**.

### Tests and rosters

- **Background-run tests to keep green:**
  - `Test/SqlBackgroundJob.cls`: `Settle` :84, bound :300, cancel :312, job death :383-408;
  - `Test/SqlBackgroundRoutes.cls`, whose other-user 404 is at :282;
  - `Test/SqlRunStore.cls` :91-147, :183, :207, :274;
  - `Test/ClassicPageGate.cls` :434-470 and `Test/Retention.cls` :295;
  - the fixtures `SqlBackgroundFixture`, `Delayed`, `Unspawned`, `Unindexed` and `Probe`, and `SqlPortFixture.PROBESECONDS`.
- **`Test/DeveloperFloorRoutes.cls`** :87-88, the GET and other route lists. **`Test/EndpointCoverage.cls`** `Probes`, whose SQL background rows :258-260 set the row format.
- **`Test/StageTwoTools.cls`** `Elsewhere` :121. The load-bearing test is `TestTheRosterAndElsewhereAreEveryRegisteredScreen`.
- **`Test/SurfaceCoverage.cls`** `Coverage` :54; row format :180.
- **`Test/Navigation.cls`**: the analytics block, 10 screens **(20.32, planned)**. **`Test/DeveloperFloor.cls`** `SCREENS` :38.
- **`Test/PortGate.cls`** `ROSTER` :29, with its `AnalyticsPort` row **(20.11, planned)**.
- **The analytics test classes (20.11, planned):** `AnalyticsProbe` (`Enable`, `Create`, `Remove`, `Gone`), `AnalyticsGate` (P1, P2, `EnsurePrincipals`) and `AnalyticsGateSeam`.
- **`scripts/ci-throwaway.sh`** :434-503: the `# classes:` lines of `OCUPILOT_ALLOW_PRINCIPALS`.

### Client

- **`ui/src/app/areas/system-explorer/sql-query.store.ts`**:
  - `SQL_BACKGROUND_PATH` :38, `BACKGROUND_POLL_MS` :41, `backgroundPath` :44;
  - `refusalText` :115, `backgroundViewOf` :124, `backgroundStatusLineFor` :144;
  - `startBackground` :327, `pollBackground` :369, `cancelBackground` :379, `stopPolling` :389, `attach` :443, `readBackground` :453, `schedulePoll` :483.
- **`sql-query.page.ts`**: `trackTemplate` :49; the background section :153-175; the `#grid` template :176-209; polling resumes on return :249 and stops on destroy :252-256.
- **`core/sql-answer.ts`** `answerOf`/`statusLineFor`. Epic 23 edits this file, so this story imports it only.
- **`core/poll-schedule.ts`** `schedulePoll`; **`core/screen-read.ts`** `screenReadPath` :177.
- **`shell/screen-outlet.ts`** `DESCRIPTOR_PAGES` :96, with the SQL page's line at :211.
- **`core/strings.ts`**: the SQL background strings :5436-5455. **`src/styles/_components.scss`**: the results styles :7836-7881.
- **`ui/tools/self-protection.test.mjs`** :610-660 pins each refusal sentence to `strings.ts` and EXPERIENCE.md. **`ui/tools/analytics.test.mjs`** **(20.11, planned)** is the analytics twin.
- **Browser:**
  - `ui/browser/system-explorer-sql-query.browser-spec.mjs`: `structural` :91-113, `makeBackgroundProbe` and `removeBackgroundProbe` :124/:133, `backgroundReads` :144, AC11 :235-254;
  - `structural-walk.mjs` (`VIEWPORTS`, `INVARIANTS`, `detectScreen`, `compare`, `readBaseline`, `assertThrowaway`);
  - `analytics.browser-spec.mjs` **(20.11, planned)**: `before`/`after` with `AnalyticsProbe`.

### Vendor (read only; `irislib/%DeepSee/`)

- **`ResultSet.cls`:**
  - `%PrepareMDX` :159, which writes cache nodes (:216);
  - `%ExecuteAsynch` :855. A DRILLTHROUGH forces the wait (:873-878) and its listing runs in the caller (:973-978).
  - `%GetStatus` :650 and `%GetQueryStatus` :475, where 100 means done or failed;
  - `%CancelQuery` :598, a class method with no owner check;
  - `%GetQueryKey` :378, `%GetCubeName` :385, `%GetListingResultSet` :418, `%IsDrillThrough` :437;
  - `%GetAxisSize` :2293, `%GetAxisCount` :2318, `%GetOrdinalValue` :2387, `%GetOrdinalLabel` :2461, `%GetFiltersForCellRange` :4018;
  - the RETURN splice :1708-1714 and the `%ORDER BY` splice :2006.
- **`Query/query.cls`**: `queryType` :16 (`SELECT,DRILLTHROUGH,CREATE,DROP,%BITSET`) and `%MaxListingRows` 1000 :136. **`Query/Parser.cls`**: RETURN :3170-3198; there is no `%KILL`.
- **`ComputedDimension/Base.cls`**: `%ProcessSQL`'s `{…}` is evaluated as ObjectScript (:653, :796-829).
- **`UI/MDXQuery.cls`**: `RESOURCE` `%DeepSee_Admin,%Development` (:15), re-checked in `%OnPreHTTP` (:518-528). It has no cancel button and no timeout.
- **Elsewhere:** `%SYSTEM/WorkMgr.cls`:38-39 (agents run in the caller's security context); `%SYS/Namespace.cls` `GetGlobalDest` :93.

## Tasks & Acceptance

**Execution:**

- [ ] **Task 0 (re-anchor and measure, no product code).** First run `git rev-parse --show-toplevel`.
  - **Re-anchor.** After 20.11 and 20.32 merge into this branch, re-anchor every (20.11, planned) and (20.32, planned) symbol above. If the links do not hold positions 4-6, MDX query takes the next free position.
  - **Contention.** Run `git -C /Users/jbrandt/git/OcuPilot/.worktrees/epic-23 diff --stat origin/feature/OCU-1_ocupilot-mvp...HEAD`. Any file this story edits other than `strings.ts` and EXPERIENCE.md goes to the lead before Task 1.
  - **Measure on `ocupilot-b-ci`**, removing what you create:
    1. The slow query for the job tests. Find a crossjoin over `AnalyticsProbe`'s grid cube (below) that runs at least 10 s. At plan time a 2,000 × 2,000 `NON EMPTY` crossjoin over 50,000 facts took 20 s for its axes and 122 s in all.
    2. `%GetOrdinalLabel`'s label order for a crossjoin tuple. Fix outer-to-inner in the answer.
    3. How a listing's column names are read. `%GetListingResultSet`'s field list came back empty at plan time; use the statement's metadata.
    4. That `$SYSTEM.SQL.CancelQuery` sent to a job that runs no SQL returns at once.
    5. The run of `%PrepareMDX`, `%ExecuteAsynch` and the poll from a `JOB`'d process, the port switching namespace for each call.
    6. That the strings' values are unique, and that the literal count stays more than 50 under `strings.test.mjs`'s bound.

    A measurement that contradicts this spec halts the stage with its evidence.
- [ ] **`src/OcuPilot/Kernel/State/SqlRun.cls`**: add `Kind` (`MAXLEN` 16, `InitialExpression` `"sql"`).
  - `GuardedReserve` gains a trailing `pKind` (default `"sql"`). The busy check and the ended-row delete count only rows of `pKind`, while the instance cap counts live rows of every kind. A row with no `Kind` reads as `sql`.
  - `IdForOwner`, `GuardedViewForOwner` and `GuardedCancel` match the kind too, with a trailing `pKind` defaulting to `"sql"`.
  - Add `GuardedCancelRequested(pKey, Output pRequested)`, a fresh SQL read, never a held OREF.
  - Doc comments name both kinds.
- [ ] **`src/OcuPilot/Kernel/Shell/BackgroundRun.cls`** (new, abstract): move the slice-free part of `SqlBackground` into it, behavior unchanged:
  - the reserve and spawn, the one `JOB` and the job entry (owner check, begin, cancel-before-begin, the screen gate again);
  - the poll and cancel routes' screen gate on the subclass's `DESCRIPTORCLASS` (`Screen.Gate.Evaluate`, then `Kernel.Denial.Envelope`);
  - `Cancel`, `View`, the 404 / busy / full / lost faults and `Envelope`/`Render`/`Finish`/`Log`.

  Each kind supplies hooks: `Admit` (the start's checks, answering a refusal, an immediate answer or a request list), `Work` (the job's work), `CancelJob` (what a cancel sends to the job), `Kind`, and the codes and reasons. **`Area/Explorer/SqlBackground.cls`** becomes a subclass holding only SQL's checks and its `CancelQuery` loop, its seams and public methods unchanged. **`scripts/check-objectscript.py`**'s `JOB_ALLOWED` names the new file in place of `SqlBackground.cls`, and **`scripts/test_check_objectscript.py`**'s case moves with it.
- [ ] **`src/OcuPilot/Port/SqlPort.cls`**: move `Executed`'s fetch loop into a public `FetchRows(pSet, pColumns, pMaxRows, Output pRows, Output pTruncated, Output pMore, Output pCut)` with `MAXCELL` and `MAXANSWER` as now; `Executed` calls it.
- [ ] **`src/OcuPilot/Api/AnalyticsError.cls`** (add to 20.11's class): `MDXINPUT` 400, `MDXSQL` 422, `MDXKIND` 422, `MDXAXES` 422, `MDXREADONLY` 409, `MDXBUSY` 409, `MDXFULL` 503, `MDXNOTFOUND` 404 and `MDXLOST` 503. Codes are `ANALYTICS.MDX.*`; each sentence is in Design Notes › Strings.
- [ ] **`src/OcuPilot/Port/AnalyticsPort.cls`** (extend 20.11's port):
  - **Parameters.** `MDXPAIRS` `%DeepSee_Portal:USE,%Development:USE`, and the named limits in Always, each doc comment giving its reason (Design Notes › Limits).
  - **`MdxAdmit(ns)`.** The gate in Always' order. The cache database is resolved by `GetGlobalDest` and checked WRITE and not read-only.
  - **`MdxSpliced(text)`.** Pure: answers whether the text names a refused token.
  - **`MdxPrepare(ns, text, drill, .rs, .answer, .http, .fault)`.**
    - Prepares the statement and classifies it.
    - A prepare error is `{outcome: "error", message}`.
    - For `drill`, it executes the original, waiting, then reads `%GetFiltersForCellRange` for that one cell, composes the drill text with the cube name bracket-quoted (`]` doubled), and prepares it.
  - **`MdxStart(ns, rs, .cube, .key)`**, **`MdxStatus(ns, rs, .error)`** and **`MdxCancel(ns, cube, key)`**.
  - **`MdxAnswer(ns, rs, seconds)`.**
    - `cells`: each column header and each row's `label` joins that position's labels with " / ", outer to inner; a query with no rows axis answers one row whose label is empty; the caps applied.
    - Listing `rows`: through `SqlPort.FetchRows`.
    - Zero axes read as one cell.
  - **Every call** switches namespace by explicit save and restore (AD-16), calls no `OcuPilot.*` class while switched, and maps a vendor status or `<PROTECT>` as 20.11's reads do.
  - **The class doc** names AD-65's MDX clause.
- [ ] **`src/OcuPilot/Screen/Descriptor/AnalyticsMdxQuery.cls`** (new; sibling `ExplorerSqlQuery`):
  - route `analytics/mdx-query`; area `analytics`; `labelKey` `analyticsMdxQueryLabel`; `sideBarPosition` 7; archetype `form-page`; `built` true; `refreshes` false;
  - `privileges` `[%DeepSee_Portal:USE, %Development:USE]` and `ownPrivileges` `[%Development:USE]`;
  - `entityType` `cube`, scope `namespace`, id `none`; no actions; context empty;
  - `commandAliases` `["mdx query", "run mdx", "mdx"]`; three prompts in `webAppPromptGroupCode`;
  - `classicPage` `%DeepSee.UI.MDXQuery`; `toolIdentifier` `analytics.mdxquery`.

  The doc names AD-5, AD-8, AD-29, AD-36, AD-44 and AD-65.
- [ ] **`src/OcuPilot/Area/Analytics/MdxQuery.cls`** (new; extends `Kernel.Shell.BackgroundRun`, `Kind` `mdx`):
  - **`Admit`.** Reads the body `{statement, drill?}` and the scope, then runs `MdxAdmit`, the splice check, `MdxPrepare` and the kind and axes refusals. It spawns nothing for a refusal or an error answer.
  - **`Work` (the job).** It repeats `Admit`'s checks.
    1. For a SELECT: `MdxStart`, then a loop every 0.1 s on `MdxStatus` that reads `GuardedCancelRequested`. On a cancel, or at `$ZHorolog` past `BoundSeconds()`, it calls `MdxCancel` and waits up to `MDXSETTLESECONDS` for status 100, then ends `canceled` or `{outcome: "stopped", seconds}`.
    2. For a drill: the one waiting call under `$System.Alarm.Set` of the time that remains, as `SqlPort.Executed` bounds its statement. `<ALARM>` cancels and stops.
    3. It finishes with `MdxAnswer`.
  - **`CancelJob`.** One `$SYSTEM.SQL.CancelQuery(job,,0)`, which reaches a drill's listing statement.
  - **Seams**, beside the kernel class's `PortClass`, `MaxRunning`, `LimitsClass` and `Spawn`: `BoundSeconds()`, which answers `AnalyticsPort.#MDXSECONDS`. Production overrides none.
  - **Routes.** `HandleStart`, `HandlePoll` and `HandleCancel` delegate to the kernel class.
- [ ] **`src/OcuPilot/Api/Router.cls`** (add-only): `POST /analytics/mdx/background/:id/cancel`, `GET /analytics/mdx/background/:id` and `POST /analytics/mdx/background`, in that order, with thin `AnalyticsMdxBackground*` handlers.
- [ ] **`src/OcuPilot/Test/AnalyticsProbe.cls`** (extend 20.11's fixture):
  - `Create` also compiles `OcuPilotProbe.Analytics.Grid` (50,000 deterministic rows: `Sub = i#2000`, `Sub2 = (i\7)#2000`, `Amount = i#100`) and the cube `OcuPilotProbeGrid` (dimensions `Sub` and `Sub2`, measure `Amount`, a listing), and builds it.
  - `Remove` also kills each probe cube's remaining `^DeepSee.Cache.Results(<cube>)` subtree, because `%KillCube` leaves an `activeChunk` node per query key (measured). `Gone` checks those subtrees too.
- [ ] **Server tests** (new; the first four armed `OCUPILOT_ALLOW_PRINCIPALS`, `Remove`/`Enable`/`Create` before all, `Remove` and `Gone` after all):
  - **`Test/AnalyticsMdx.cls`** (port):
    - the cells answer equals the vendor's own labels and values, read in the test;
    - the cell drill equals the vendor's listing for the composed text;
    - the row, column, cell and total caps;
    - `MdxSpliced` for each token, mixed case included;
    - CREATE, DROP and three axes are refused, and a syntax error answers the vendor's text;
    - HSCUSTOM answers 409 `ANALYTICS.NAMESPACE`, and HSLIB 409 `ANALYTICS.MDX.READONLY`.
  - **`Test/AnalyticsMdxJob.cls`** (sibling `SqlBackgroundJob`):
    - the owner's cancel ends `canceled` within 12 s, then `'$Data(^$JOB(pid))`, `%GetQueryStatus` 100, and no `%SYS.ProcessQuery` row in USER whose `Routine` starts `%DeepSee`;
    - the bound, through the fixture subclass `Test/AnalyticsMdxFixture` (new) whose `BoundSeconds()` is 2, ends `stopped` with the same three checks;
    - a cancel before the job begins;
    - the job's failure log line carries no statement.
  - **`Test/AnalyticsMdxRoutes.cls`** (sibling `SqlBackgroundRoutes`):
    - another user's poll and cancel equal the unknown id's 404;
    - a second start answers 409 naming the run;
    - an MDX run does not block the same user's SQL background start;
    - the instance cap counts both kinds;
    - the id shape;
    - a custom resource assigned to `%DeepSee.UI.MDXQuery` gates all three routes (`ClassicPageGate`'s pattern).
  - **`Test/AnalyticsMdxGate.cls`**, reusing `AnalyticsGate`'s principal setup (made reachable):
    - P1 (`%DB_USER:R`) is refused 403 naming `%DB_USER:WRITE`;
    - P3 (`%DB_USER:RW`, `%Development:USE`) runs the cells query, and its cell drill answers `error` with SQLCODE -99;
    - P4 (RW without `%Development`) is refused naming `%Development:USE`.
  - **`Test/AnalyticsMdxDescriptor.cls`** (unarmed): the declaration's values, `Registry.Validate`, `classicPage` equals `NormalizePage("_DeepSee.UI.MDXQuery.zen")`, and the compiled `RESOURCE` names `%Development`.
  - **`Test/SqlRunStore.cls`**: add per-kind busy, the cross-kind cap, and kind-matched lookups.
  - **`Test/PortGate.cls`**: `MDXPAIRS` joins `AnalyticsPort`'s row, with its denial leg.
- [ ] **Rosters, each name read from the instance:**
  - `StageTwoTools` `Elsewhere` +1;
  - `SurfaceCoverage` one `<screen>` row naming `AnalyticsMdxDescriptor`;
  - `EndpointCoverage` three probes;
  - `Navigation.cls` analytics block 10 → 11;
  - `DeveloperFloor` `SCREENS` +1;
  - `DeveloperFloorRoutes` the GET and the two POSTs;
  - `InteropFloor` unchanged: its principals hold no `%Development` (checked at the sweep).
- [ ] **`scripts/ci-throwaway.sh`**: `# classes:` entries for the four armed classes.
- [ ] **`ui/src/app/core/background-run.ts`** (new, framework-free): move `SqlQueryState`'s start, attach, poll, cancel, stop and read logic into `BackgroundRun`, configured by its base path, its busy code and its answer parser. The generation guard, the re-poll on `installing`, status 0 or ≥500, and the clear on 404 all move with it. `SqlQueryState` keeps its public API and delegates; its specs stay unchanged.
- [ ] **`ui/src/app/shell/result-grid.ts`** (new): move the SQL page's `#grid` template and `trackTemplate` into `ResultGrid` (inputs `answer`, `label`, `slot`). The SQL page uses it and its DOM is unchanged, `data-ocu-sql` slots included.
- [ ] **`ui/src/app/core/mdx-answer.ts`** (new): `mdxAnswerOf(body)` for `cells`, `rows` (through `answerOf`), `error` and `stopped`, and `mdxStatusLineFor`.
- [ ] **`ui/src/app/areas/analytics/mdx-query.store.ts`** and **`mdx-query.page.ts`** (new):
  - **Cube select.** Fed by `screenReadPath` of `analytics.cubes`. A pick fills the statement with `SELECT FROM [<name>]` only while the statement is empty.
  - **Statement and Run.** A statement textarea, and Run, disabled while a run is live.
  - **The run.** A `BackgroundRun` at `/api/ocupilot/analytics/mdx/background`: a status line, Cancel while running, and a refusal banner. A vendor error shows in a `<pre>`.
  - **The cells grid.** The page's own template on `.ocu-data-table-*`: a first column headed `analyticsMdxRowHeader` whose cells are `role="rowheader"` labels, drawn only when some row has a label. Each value cell is a `<button>` with the `analyticsMdxDrillCell` label, which starts a drill of the last-run statement at that row and column. The cells stay shown while the drill runs.
  - **The listing.** Under "Drill-through" in `ResultGrid`.
  - **Slots.** `data-ocu-mdx` slots for the tests. No inline color, tokens only.
- [ ] **`ui/src/app/shell/screen-outlet.ts`**: one `DESCRIPTOR_PAGES` loader line. Add the **`ui/src/app/core/strings.ts`** literals (add-only), then run `cd ui && node tools/screen-mirror.mjs`.
- [ ] **Client tests:**
  - `ui/tools/background-run.test.mjs` (start, busy attach, poll, cancel, 404 clear, transient re-poll, stale answer dropped);
  - `ui/tools/mdx-answer.test.mjs`;
  - `ui/tools/analytics.test.mjs`: the nine `REASONMDX*` sentences equal their `strings.ts` value and EXPERIENCE.md literal;
  - `mdx-query.page.spec.ts` (run, cancel, cell button → drill request body, picker fills only an empty statement);
  - `result-grid.spec.ts`;
  - `ui/tools/navigation.test.mjs` (the route) and `ui/tools/screen-mirror.test.mjs` (the owners list).
- [ ] **`ui/browser/analytics-mdx.browser-spec.mjs`** (new). `before` refuses the live container, requires readiness, and runs `AnalyticsProbe` `Remove`, `Enable` and `Create`. `after` runs `Remove` and asserts `Gone`. Each leg carries its mutation comment:
  - **AC1:** in USER, the cells query's grid equals the instance's answer, read through `runIris`.
  - **AC2:** a cell's drill shows the listing the instance answers for that cell.
  - **AC3:** the slow query's Cancel reads "Canceled.", and `runIris` finds nothing running.
  - **AC5:** a CREATE statement shows its refusal sentence.
  - **AC8:** `structural` on `analytics/mdx-query` with a result shown finds no fresh entry at 1280 light, 720 light or 1280 dark.
  - If `structural-walk.mjs`, which walks the route in HSCUSTOM, reports a fresh entry for it, fix the page, or append the entry as that file says.
- [ ] **EXPERIENCE.md:**
  - the side-bar prose :159 gains "then MDX query (Story 20.33)";
  - the Fixed strings get one row with this story's literals;
  - run `cd ui && npm run test:tools`.
- [ ] **Roster sweep (Rule 30).** Search `src/OcuPilot/Test`, `ui/tools`, `ui/browser` and the `ui/src` specs for the analytics side bar, the built-screen count, `SCREENS`, the developer route lists, `JOB_ALLOWED` and `SqlBackground`. Each changed file joins `(loop)`.

**Acceptance Criteria:**

- **AC1 (the story's criterion: results render).**
  - **Given** `AnalyticsProbe` in USER and `_SYSTEM` on MDX query.
  - **When** the person runs a SELECT over `OcuPilotProbeVisits`.
  - **Then** the grid shows the vendor's row labels, column headers and cells for that statement, as the instance reads them, and the status line gives the shown and available rows and columns.
- **AC2 (drill-through).**
  - **Given** AC1's grid.
  - **When** the person activates a value cell, or runs a `DRILLTHROUGH` statement.
  - **Then** a listing appears with the rows the vendor's listing answers for that cell's own filters (or the statement), at most 1,000, the cells grid still shown.
- **AC3 (cancel leaves nothing running).**
  - **Given** the slow grid query running.
  - **When** the owner cancels.
  - **Then** the run reads Canceled within 12 s; its job has exited, the vendor reports the query finished, and no process in USER runs DeepSee query code.
- **AC4 (time bound and caps; AD-7).**
  - **Given** the bound at 2 s through the fixture, or a query beyond a cap.
  - **When** it runs.
  - **Then** the bound stops it ("Stopped after 2 seconds.") with nothing left running, and each cap answers at most its limit with truncation reported.
- **AC5 (never a write; untrusted text).**
  - **Given** a CREATE or DROP, three axes, or text naming `%SEARCH`, `%SQLRESTRICT`, `RETURN` or `%ORDER`.
  - **When** it is started.
  - **Then** it is refused by its code and sentence before any spawn, nothing is prepared for the spliced tokens, and OcuPilot writes nothing to the instance.
- **AC6 (owner-scoped; AD-33, AD-41).**
  - **Given** a live run.
  - **When** another user polls or cancels it, or the owner starts again.
  - **Then** the other user reads the unknown id's 404, and the owner's second start answers 409 naming the run. An MDX run never blocks the owner's SQL background run, and the instance's five-run cap counts both kinds.
- **AC7 (gate first; AD-29, AD-65).**
  - **Given** HSCUSTOM, HSLIB, or P1, P3 or P4.
  - **When** a run starts.
  - **Then** each refusal in the matrix is the gate's, before any vendor call. P1's names `%DB_USER:WRITE`. P3's cell drill answers the vendor's SQLCODE -99 as an error outcome. `PortGate` holds `MDXPAIRS`' denial, and a custom resource on `%DeepSee.UI.MDXQuery` gates the routes.
- **AC8 (declared, rostered, structural).**
  - **Given** the descriptor.
  - **When** the instance validates it and the build regenerates the mirror.
  - **Then:**
    - it validates on both sides with three prompts;
    - its `Elsewhere` row is load-bearing (removed, that test alone reddens);
    - Analytics navigation carries 11 screens in the pinned order;
    - the developer floor opens it and its routes;
    - the structural check finds no fresh entry in either theme.
- **AC9 (Integration, Rule 1, and the extended sibling).**
  - **Given** the kernel background run and the client `BackgroundRun`.
  - **When** the MDX page starts, polls and cancels through `MdxQuery` and `AnalyticsPort`, and the SQL console runs its background query.
  - **Then** both render their answers. The SQL console's background routes, job, store and browser tests pass unchanged.

## Spec Change Log

- 2026-10-14, spec gate (runner): the orchestrator ruled Q1 (A, the agent's read is Story 20.35, chartered) and Q2 (C: the screen asks first and runs on confirmation; the agent refuses). The intent contract carries Q2 C; status reset to `draft` for a re-plan around it. The spine's AD-65 clause is written.

## Review Triage Log

## Design Notes

**Governing ADs (Rule 6).**

- **AD-65:** the port's MDX extension and its gate.
- **AD-29:** the gate before any call (measured).
- **AD-7:** the run never mutates; the vendor's cache is its new cost shape.
- **AD-33 and AD-41:** owner-scoped runs and the bounds.
- **AD-36:** a screen-only payload.
- **AD-8:** the pairs.
- **AD-44:** the classic page.
- **AD-16:** switched calls.
- **AD-21:** untrusted statement text.
- **AD-11 and AD-60:** untrusted results.
- **AD-42:** the spawn site.
- **AD-5 and AD-19:** a `form-page` with one loader line, and a framework-free store.
- **AD-64:** the screen is adjustable, the port's pairs are not.

Checked and not engaged: AD-6, AD-10, AD-15, AD-22 and AD-51 to AD-53, because nothing writes and no tool or key is added; AD-43, because the screen does not refresh; AD-47 and AD-63, because nothing is framed.

**Measured at this plan on `ocupilot-b-ci`** (2026-10-14; IRIS for Health 2026.2 build 221U). The probe enabled analytics on `/csp/user`, compiled a 50,000-row source and a three-dimension cube, created two principals, and removed all of it. USER's flags were restored and its `^DeepSee.Cache.*`, `AgentLog`, `Agents`, `Update` and IRISTEMP nodes were cleared. The vendor counters `^DeepSee.Tasks` and `TaskGroups` and statement-index rows stay, as 20.11 names.

- **Running.** `%PrepareMDX` plus `%ExecuteAsynch(.key,,0)` plus a 0.1 s `%GetStatus` poll ran a small query in 0.1 s.
  - A 2,000 × 2,000 crossjoin took 20 s for its axes and 122 s in all.
  - While it ran, one WorkMgr worker ran `%DeepSee.Query.setFunction` in USER.
  - A cancel's status reached 100 after 1.1 to 5.4 s, with `<EXTERNAL INTERRUPT>` as the vendor's error.
  - Afterwards no process ran in USER and the job had exited.
  - A canceled statement re-run computes again.
- **Writes.**
  - Even `%DeepSee.ResultSet.%New()` writes `^DeepSee.Cache.LocalResults("session")`.
  - A principal holding `%DB_USER:R` got `<PROTECT> … ^DeepSee.Cache.LocalResults("session"),/durable/iris/mgr/user/`, and one holding RW ran.
  - In HSLIB, whose database is read-only, `%New()` threw the same `<PROTECT>` as `%All`.
  - A crossjoin canceled at 3 s left 4,667,688 `^DeepSee.Cache.Axis` nodes; `%KillCube` cleared them but left one `activeChunk` node per query key.
- **The splices.**
  - `%SEARCH.&[Amount > {$Increment(^g)}]` incremented `^g` before its SQL failed: the braces run ObjectScript.
  - `RETURN Note,(SELECT COUNT(*) FROM …) AS N` ran the subquery.
  - `%SQLRESTRICT` (the same `ComputedDimension.SQL` path) and `%ORDER BY`'s raw splice (RS:2006) are inferences from the source.
- **Kinds.** After prepare: CREATE and DROP read their type, three axes read `axes` 3, `%SHOWPLAN SELECT` reads SELECT, and a syntax error and an unknown cube each answer #5001 text.
- **Drill.**
  - `%GetFiltersForCellRange` gave `f(0)` (slicer) and `f(2)` (rows), and the composed `DRILLTHROUGH MAXROWS 3 … %FILTER …` ran.
  - A DRILLTHROUGH without MAXROWS answered 1,000 rows.
  - P3 without a SELECT grant got #5540 SQLCODE -99 from `%ExecuteAsynch`.
- **Shared key.** Another process running the same text ended with the same `<EXTERNAL INTERRUPT>` 1.1 s after this process canceled. One cancel stops every run of that text.
- **Classic page.** `NormalizePage("_DeepSee.UI.MDXQuery.zen")` is `%DeepSee.UI.MDXQuery` (compiled), `RESOURCE` `%DeepSee_Admin,%Development`. `GetGlobalDest("USER","^DeepSee.Cache.Results")` is `^/durable/iris/mgr/user/`.

**Decisions.**

- **One background run, two kinds.** The SQL run's row, lock, sweep, owner 404 and bounds are what this tool needs. A copy of `SqlBackground` would be about 300 near-identical lines.
  - The machinery moves to the kernel because a slice never depends on another slice.
  - The SQL console keeps one live run per user.
  - The instance cap of five, measured against the license for SQL jobs, counts every kind (inference: an MDX job holds a license unit as a SQL job does).
- **The job polls; the vendor computes.** The query runs on the vendor's agents in the person's security context. The job owns the deadline and the cancel, which is why a time bound and a "nothing running" proof are possible.
  - *Rejected:* starting the query in the request and polling the vendor from each poll. That needs the statement stored, and nobody enforces the bound while nobody polls.
- **Refuse, don't name, the splices.** 20.11's charter named `RETURN`, `%SQLRESTRICT` and computed dimensions as limits. The plan measured that `%SEARCH`'s braces run ObjectScript and write, and that `RETURN` runs SQL text. This plan's brief says query text never reaches anything executed outside the MDX parser and no writing statement is admitted. A text-level refusal is conservative: false positives only. The planned refusal changes the charter, so it is Q2.
- **Limits.**
  - Rows 1,000: the SQL console's Max rows, and the vendor's listing default.
  - Columns 100: a wider grid cannot be read on screen (inference).
  - Cell and total characters: AD-36's screen-only bounds.
  - 120 s: the measured slow crossjoin (122 s) is stopped, and a forgotten run frees its slot of five within two minutes.
  - Settle 10 s: twice the slowest measured settle.
- **Pairs.** `%DeepSee_Portal:USE` comes from the area, and `%Development:USE` is the screen's own: a named narrower audience than the classic page's either-of, 20.11's Q2 precedent. The cache WRITE pair is the port's, read at call time.
- **The grid.** Value cells are buttons, so drill-through is reachable by keyboard. It is the page's own template because it has row headers and buttons. The listing reuses `ResultGrid`.
- **Not done:** member values (the person queries members with MDX), session sets and members, formatting by measure format (cells are the vendor's raw values), and auto-refresh.

**Named limits.**

- **The shared key.** A cancel or bound stops the vendor's computation of that text for every process running it, including the classic tool's (measured).
- **The cache.** A query, even a canceled one, leaves the vendor's cache in the namespace's database until the cube is next built or killed (AD-7's new shape).
- **Code the query names.** `%KPI` and a cube's own listing or computed-dimension code run as the person, as on the classic page. Those are the cube author's code, not the statement's.
- **False positives.** A statement whose member keys contain a refused word is refused.
- **The drill listing.** The vendor scans every matching fact before `TOP`. A cancel during the listing statement waits for `CancelQuery` to reach it.
- **HSLIB** reports analytics but cannot run MDX.

**Questions for the orchestrator.**

- **Q1, the agent's MDX read** (the charter's question; the PRD lists MDX execute among the rider's read tools, `extract-stages.md`:346).
  - (A, planned) No agent tool in this story. Charter it as its own story: synchronous in the turn job through `AnalyticsPort`'s same calls, with the same caps, the Q2 refusals, AD-60, and Rule 3 evidence. Its plan must keep AD-11's no-write rule, which a model-written `%SEARCH` would break (measured).
  - (B) Add `analytics.mdxquery.read` here. This adds a tool class, the `ReadTool`, `ToolRoundTrip`, `ToolEmit` and `SurfaceCoverage` rows, and an integration test, about a quarter more story.
- **Q2, the splices.**
  - (A, planned) Refuse `%SEARCH`, `%SQLRESTRICT`, `RETURN` and `%ORDER` (`ANALYTICS.MDX.SQL`).
  - (B) Keep the charter's named limits. The audience, who holds `%Development:USE` and WRITE on the database, can already run code through the source editor (inference), and the classic page allows them.

  Under (B), `MdxSpliced`, its refusal code and string, and its test and mutation rows are dropped, and AD-21's draft becomes a named limit.

**Size.** One story, large. If the lead wants a smaller cut, the cell drill-through and the cube picker split off. That moves the criterion's drill-through clause, which is Rule 5 ask-first.

**Rule 31 (extend, don't copy).**

- **Extended:**
  - `SqlBackground` → `Kernel.Shell.BackgroundRun`;
  - `SqlRun` (+`Kind`);
  - `SqlQueryState`'s polling → `core/background-run.ts`;
  - the SQL grid → `ResultGrid`;
  - `SqlPort.Executed`'s loop → `FetchRows`;
  - `AnalyticsProbe`, `AnalyticsGate`'s principals and `AnalyticsError`.
- **New siblings, each following one:** `AnalyticsMdxJob` and `AnalyticsMdxRoutes` follow `SqlBackgroundJob` and `SqlBackgroundRoutes`, and `AnalyticsMdxDescriptor` follows `ExplorerDescriptor`'s SQL query test.
- **The copy:** the cells grid's template (row headers and drill buttons) is its own, on the shared CSS classes.

**Integration, Consumes, Consumed-by (Rules 1 and 2).**

- **Integration:** AC9. The MDX page consumes the start, poll and cancel routes, which consume `AnalyticsPort` and the kernel run against the real instance (the AC1-AC3 browser legs). The SQL console consumes the same kernel run and client helper.
- **Consumes:**
  - 20.11: `AnalyticsPort`, `AnalyticsError`, `AnalyticsProbe`, `AnalyticsGate`, Cubes and `cube`;
  - 20.32: positions 4-6;
  - 19.15's run and 19.6's fetch loop;
  - 20.29's loader map.
- **Consumed-by:**
  - 20.34, whose build can outlast a request: it can extend `Kernel.Shell.BackgroundRun` with a third kind (inference);
  - Q1's agent read;
  - 20.12's Investigate (inference);
  - Epic 21's analytics editors.

**Ledger inbox (Rule 17):** none owned (`owned_ledger=0`).

**Rule 11 (contended files).**

- **Add-only:** `Test/SurfaceCoverage.cls`, `Test/StageTwoTools.cls`, `screens.generated.ts` (regenerated), `strings.ts` and EXPERIENCE.md.
- **Unchanged:** `Kernel/EntityType.cls` (it uses 20.11's `cube`), `Test/Descriptor.cls`, `Test/ReadTool.cls`, `Screen/Registry.cls`, `Screen/Read.cls` and `Prohibited.cls`.
- **Epic 23** (`bdd7d415`) edits `core/sql-answer.ts`, `strings.ts`, EXPERIENCE.md, `command-box.ts` and `data-table.ts`. This story imports `sql-answer.ts` and edits none of the others beyond add-only lines.
- **Footprint extensions** (outside `paths_hint`): `src/OcuPilot/Area/Explorer/SqlBackground.cls`, `src/OcuPilot/Area/Analytics/MdxQuery.cls`, `scripts/check-objectscript.py`, `scripts/test_check_objectscript.py`, `scripts/ci-throwaway.sh` and EXPERIENCE.md.

**Spine drafts (Rule 20; the lead writes them at the gate).**

- **AD-65, a Story 20.33 clause:**
  - MDX runs through `AnalyticsPort`'s `Mdx*` calls behind `MDXPAIRS` and WRITE on the database `^DeepSee.Cache.Results` maps to (read-only refused 409 `ANALYTICS.MDX.READONLY`).
  - Only SELECT with at most two axes, and DRILLTHROUGH, run. A drill-through is composed from the vendor's `%GetFiltersForCellRange`.
  - The statement's text never names `%SEARCH`, `%SQLRESTRICT`, `RETURN` or `%ORDER`.
  - The vendor's `%CancelQuery` checks no owner, so the run row is the owner check.
- **AD-7:** "So does the MDX tool's query (Story 20.33): it writes the vendor's result and axis cache in the namespace's database, kept after a cancel, plus `^DeepSee.AgentLog`, `^DeepSee.Agents` and IRISTEMP's `^IRIS.Temp.DeepSee*`. The MDX job is the background run's second kind and never mutates."
- **AD-41:** "Background runs carry a kind: a user has at most one live run per kind, and the instance at most five of all kinds (Story 20.33)."
- **AD-42:** the fourth spawn site is `Kernel/Shell/BackgroundRun`, shared by the SQL console and the MDX tool, with the same rules.
- **AD-36:** "An MDX run's cells and listing are a screen-only payload (Story 20.33), bounded by `AnalyticsPort`'s `MDX*` limits, held as the SQL console's background answer is."
- **AD-8:** MDX query requires `%DeepSee_Portal:USE` and its own `%Development:USE`, a named narrower audience than the classic page's either-of.
- **AD-44:** `%DeepSee.UI.MDXQuery`.
- **AD-21:** "The MDX tool's statement is the caller's own query: it reaches only the vendor's parser, and a text naming `%SEARCH`, `%SQLRESTRICT`, `RETURN` or `%ORDER` is refused (Story 20.33)." Under Q2 (B), it becomes a named limit instead.

**Strings (about 20 literals, add-only; reused keys keep their values).**

- **Reused:** `explorerSqlBackgroundRunning`, `explorerSqlBackgroundCanceled`, `explorerSqlStopped`, `actionCancel`, and SQL's "Statement", "Run" and row-count lines.
- **New labels and lines:**
  - `analyticsMdxQueryLabel` "MDX query";
  - `analyticsMdxCubeLabel` "Start from cube";
  - `analyticsMdxEmpty` "Write one MDX statement, then Run.";
  - `analyticsMdxDrillHeading` "Drill-through";
  - `analyticsMdxRowHeader` "Members";
  - `analyticsMdxDrillCell` "Drill through <row>, <column>";
  - `analyticsMdxCellsLine` "Rows: <r> of <R>. Columns: <c> of <C>.";
  - `analyticsMdxErrorLine` "The instance answered this statement with an error."
- **Refusals (each `REASONMDX*` equal to its value):**
  - INPUT "Send one MDX statement of up to 100,000 characters.";
  - SQL "This statement names %SEARCH, %SQLRESTRICT, RETURN or %ORDER, which the instance turns into SQL or code; it is not run here.";
  - KIND "Only SELECT and DRILLTHROUGH statements run here; CREATE and DROP change only a session, which this tool does not keep.";
  - AXES "A query here uses at most two axes: columns and rows.";
  - READONLY "This namespace keeps its analytics cache in a read-only database, so MDX cannot run here.";
  - BUSY "An MDX query you started is still running; cancel it or wait for it to end.";
  - FULL "As many background queries as this instance allows are running, SQL and MDX together; try again when one ends.";
  - NOTFOUND "No MDX run of yours has this id; an ended run is kept for 15 minutes.";
  - LOST "The MDX run ended without an answer; run it again."
- **Prompts:** "How do I put one dimension on rows and another on columns?", "How do I filter an MDX query to one member?", "What does a drill-through show for a cell?"

**Weight.** The initial bundle gains the strings and one mirror entry, about 5 kB (inference), against `maximumWarning` 1992kB on a measured 1.94 MB. The MDX page is a new lazy chunk of about 20 to 30 kB (inference), under the 88 kB ceiling. `background-run.ts` and `result-grid.ts` land in lazy chunks shared with the SQL page.

## Verification

**Shared surfaces:**

- `SqlRun`'s per-user and per-instance counts (the SQL background tests);
- `JOB_ALLOWED`;
- `StageTwoTools` `Elsewhere`, `SurfaceCoverage`'s screens, `EndpointCoverage`'s probes;
- `Navigation.cls`' analytics block;
- `DeveloperFloor` `SCREENS` and `DeveloperFloorRoutes`' lists;
- `PortGate`'s `ROSTER`;
- `navigation.test.mjs`' routes and `screen-mirror.test.mjs`' owners;
- the strings table and EXPERIENCE.md :159 and its Fixed strings;
- the built-screen count Screen permissions derives (+1);
- USER's analytics flags and `^DeepSee.Cache.Results` while the probe runs;
- the SQL page's DOM.

*Every test added or changed passes on a fresh environment, in either order.* `AnalyticsProbe` creates and removes everything it asserts on, its cache residue included, and each job test settles its own runs.

**Setup (slot B; never the dev instance `ocupilot-slot-b`):**

- `(loop)` **Load `src`:**
  1. Run `rsync -a --checksum --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-20/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`.
  2. In `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`, run `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)`.
- `(loop)` **Before any browser run:** `cd ui && npm run build && docker exec ocupilot-b-ci sh -c 'cd /durable/iris/csp/ocupilot && rm -rf ./*' && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`.

**Commands.** Run each in the foreground with `timeout: 600000`, one at a time, and read each class's result from `%UnitTest_Result`. Size batches to about 8 minutes from `ui/tools/ci-timings.json`. A job class waits on slow queries, so run it alone.

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.AnalyticsMdx --class OcuPilot.Test.AnalyticsMdxDescriptor --class OcuPilot.Test.AnalyticsMdxGate --class OcuPilot.Test.PortGate`. Expected: green.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.AnalyticsMdxJob`, then `--class OcuPilot.Test.AnalyticsMdxRoutes`. Expected: green.
- `(loop)` The same runner, in batches:
  1. `SqlRunStore`, `SqlBackgroundJob`, `SqlBackgroundRoutes`, `ClassicPageGate` and `Retention`;
  2. `StageTwoTools`, `SurfaceCoverage`, `EndpointCoverage`, `Navigation`, `DeveloperFloor`, `DeveloperFloorRoutes`, `AnalyticsPort`, `AnalyticsGate` and `ScreenAccessWire`;
  3. every class the sweep changes.

  Expected: green.
- `(loop)` `cd ui && npm run test:tools`, then `cd ui && npm run test:components`. Expected: green.
- `(loop)` `cd ui && npm run build -- --verbose`. Expected: the prebuild chain is green, the MDX page in its own lazy chunk, and the initial total under 1992kB (record both).
- `(loop)` `uv run scripts/check-objectscript.py <each changed .cls>`, `uv run scripts/test_check_objectscript.py` and `bash scripts/lint-docs.sh`. Expected: clean.
- `(loop)` `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/<file>`, one file per call, after the redeploy. Expected: green.
  - `analytics-mdx.browser-spec.mjs`
  - `system-explorer-sql-query.browser-spec.mjs`
  - `a11y-structural-invariants.browser-spec.mjs` (about 430 s)
  - each side-bar spec the sweep changes
- `(once)`, **lead-owned (the runner's):** the full ObjectScript sweep, `cd ui && npm test`, `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`, and Rule 30's fresh check.
- **Left to CI:** the full browser suite.

**Planned pinning mutations (Rule 19).** Revert each byte-identical. Reload, or rebuild and redeploy, the whole tree before the next.

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | `MdxAnswer` reads labels innermost first | `AnalyticsMdx`'s cells test and the browser AC1 grid |
| AC2 | The drill composes without the slicer `f(0)` | `AnalyticsMdx`'s drill test (rows differ) and the browser AC2 |
| AC3 | `Work` ends `canceled` without `MdxCancel` | `AnalyticsMdxJob`'s cancel test (a `%DeepSee` process remains) |
| AC4 | `Work` ignores the deadline | `AnalyticsMdxJob`'s bound test |
| AC4 | `MDXMAXROWS` is not applied | `AnalyticsMdx`'s row cap test |
| AC5 | `MdxSpliced` drops `RETURN` | `AnalyticsMdx`'s splice test (the subquery runs) |
| AC5 | Kind accepts CREATE | `AnalyticsMdx`'s kind test and the browser AC5 |
| AC6 | `IdForOwner` ignores the owner | `AnalyticsMdxRoutes`' other-user test |
| AC6 | `GuardedReserve`'s busy check ignores the kind | `AnalyticsMdxRoutes`' kinds-apart test and `SqlRunStore`'s per-kind test |
| AC7 | `MdxAdmit` skips the cache WRITE | `AnalyticsMdxGate` P1 (an unnamed `<PROTECT>`, not 403 naming `%DB_USER:WRITE`) |
| AC7 | `MDXPAIRS` loses `%Development:USE` | `AnalyticsMdxGate` P4, and `PortGate`'s leg |
| AC8 | The `Elsewhere` row is removed | `StageTwoTools.TestTheRosterAndElsewhereAreEveryRegisteredScreen`, alone |
| AC8 | A pale color on a drill cell | The browser structural leg |
| AC9 | `BackgroundRun` drops the 404 clear | `background-run.test.mjs` and `sql-query.page.spec.ts`' swept-run case |

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Planned against 20.11's and 20.32's specs (both planned), with the vendor's MDX run, cancel, drill-through, writes and splices measured on `ocupilot-b-ci` and the probe removed. Q1 (the agent's MDX read) and Q2 (refusing the spliced tokens) are for the orchestrator at the spec gate. The Rule 20 drafts are in Design Notes.
