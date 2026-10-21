---
title: 'Story 20.33: The MDX query tool'
type: 'feature'
created: '2026-10-14'
status: 'done'
baseline_revision: '4122309739f3405c0f7717546514c781c54cca7c'
baseline_commit: '053c1b15118bbb1efe1925a65949a21eb7552000'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
warnings: [oversized]
deferred:
  - "Test/AnalyticsPort.Snapshot concatenates every ^DeepSee.Cache* node into one string, so a vendor cache over about 3.6 MB raises <MAXSTRING> and TestTheReadsWriteNothing reddens on residue it did not make (it reddened on this story's measurement residue until the probe cleaned it); a hash per global would remove the dependence."
---

<intent-contract>

## Intent

**Problem:** An analytics developer who wants to query a cube still opens the classic MDX Query Tool. That tool has no time bound, no cancel button and no owner check: the vendor's `%CancelQuery` stops anyone's query by its cube and key (measured). OcuPilot has the analytics port (Story 20.11, planned) but no way to run MDX.

**Approach:**

- A listed Analytics screen, **MDX query**, where a person writes one MDX statement and runs it.
- The run is an **owner-scoped background run**: the SQL console's background run (Story 19.15), extended to a second kind rather than copied. It has a row cap, a time bound and cancel.
- The answer renders as a grid of axis labels and cells. A cell drills through to the vendor's listing for that cell, and a `DRILLTHROUGH` statement shows its listing directly.
- `AnalyticsPort` gains the MDX calls behind its own gate (AD-65). OcuPilot writes nothing to the instance of its own. A statement whose text the vendor would splice into SQL or evaluate as code (`%SEARCH`, `%SQLRESTRICT`, `RETURN`, `%ORDER`, `%PARM`), or that the detector cannot read, runs only after the person confirms, in a confirmation that names the consequence in plain words: "This query runs server-side code or SQL with your rights." A statement without them runs as a plain read. (Orchestrator ruling Q2 C, 2026-10-14, the owner's developer-tool-first rule; AD-65. The classic page runs them unasked, so this is stricter than the vendor.)

## Boundaries & Constraints

**Always:**

- **Gate first (AD-29, AD-65)**, before any vendor call, in the start request and again in the job:
  1. the screen's pairs, the classic page's custom resource included;
  2. `AnalyticsPort`'s own pairs, `MDXPAIRS`;
  3. the namespace's shape, and that the namespace reports analytics (else 409 `ANALYTICS.NAMESPACE`);
  4. READ on the namespace's globals and routines databases;
  5. WRITE on the database that `^DeepSee.Cache.Results` maps to in that namespace (`%SYS.Namespace.GetGlobalDest`), and that database mounted read-write (else 409 `ANALYTICS.MDX.READONLY`).

  A refusal names the failed pair.
- **The statement is untrusted text.** It reaches only `%DeepSee.ResultSet.%PrepareMDX`. Before prepare, the port detects any of `%SEARCH`, `%SQLRESTRICT`, `RETURN`, `%ORDER` and `%PARM` in the vendor's own tokens (`%Tokenize`) and in each quoted string's tokens, so a comment inside a word (`%SE/**/ARCH`) is still found, and after prepare it runs the detector again on the variable-resolved text; it fails closed (a failed tokenize or an unreadable resolved text asks first, as if a construct were found). The vendor splices those into SQL or evaluates them as ObjectScript (Design Notes › Measured); orchestrator ruling Q1 B at 20.35's gate, 2026-10-15; stored definitions are a named limit (DW-2451). A statement with a finding runs only when the start request carries the person's confirmation of that consequence; without it the start answers that confirmation is needed, naming the consequence, and nothing runs. Both paths are pinned by tests, the measured `%SEARCH.&[...{$Increment(^g)}]` case among them: not run until confirmed, then run. After prepare, only `queryType` `SELECT` (at most two axes) and `DRILLTHROUGH` run. `CREATE`, `DROP` and `%BITSET` are refused 422 `ANALYTICS.MDX.KIND`, and three or more axes 422 `ANALYTICS.MDX.AXES`.
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
- No write tool, governance key, row action, proposal or read tool. The agent's MDX read is Story 20.35 (orchestrator ruling Q1 A), which refuses those five constructs, and a statement the detector cannot read, with `ANALYTICS.MDX.SQL`.
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
| Syntax | `SELEKT FROM [OcuPilotProbeVisits]` | 200 `{outcome: "error", message}` with the vendor's text, before any spawn | - |
| Kind | `CREATE MEMBER [OcuPilotProbeVisits].[Measures].[X] AS '1'` | Nothing spawned | 422 `ANALYTICS.MDX.KIND` |
| Axes | Three axes (`ON 2`) | Nothing spawned | 422 `ANALYTICS.MDX.AXES` |
| Spliced | Text naming `%SEARCH`, `%SQLRESTRICT`, `RETURN`, `%ORDER` or `%PARM` in the vendor's tokens or a string literal's, or text the detector cannot read, without `confirmed` | 200 `{outcome: "confirm", constructs, consequence}`; nothing prepared or spawned. With `confirmed: true` the run starts (202) | - |
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

All paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-20`. Line numbers were read at `d09e50936d74cc5fac57b3738d305581ab1ba142`. Stories 20.11 and 20.32 land first. Their symbols are marked **(20.11, planned)** and **(20.32, planned)**, and Task 0 re-anchors them.

### The sibling to extend: the SQL console's background run (Story 19.15)

- **`src/OcuPilot/Area/Explorer/SqlBackground.cls`** (448 lines):
  - parameters: `DESCRIPTORCLASS` :25, `CONSOLECLASS` :28, `STORECLASS` :31, `SPAWNTIMEOUT` 5 :34, `IDPATTERN` :38, `CANCELSECONDS` 3, `CANCELTRIES` 10 and `CANCELPAUSE` 0.2 (:41-47), `LOGSUBSYSTEM` :53;
  - seams: `PortClass` :56, `MaxRunning` :62, `LimitsClass` :68;
  - routes: `HandleStart` :80 (SQL-specific checks :84-111), `HandlePoll` :134, `HandleCancel` :156;
  - the job: `Start` :192 (reserve, then spawn; the request is a `$ListBuild` handed to the job, never stored), `Spawn` :231 (the one `JOB`, :234, hands `$ClassName()` to the job), `Run` :249 (the SQL-specific part is :280-301; a refusal ends the run `failed` with its envelope), `FinishRefused` :312;
  - `Cancel` :332, the `$SYSTEM.SQL.CancelQuery` retry loop;
  - `View` :360, the faults `QueryOnly`/`Busy`/`Full`/`NotFound`/`Lost` :370-408, `Envelope`, `Render`, `Finish` and `Log` :411-446.
- **`src/OcuPilot/Area/Explorer/SqlConsole.cls`**: `OUTCOMECONFIRM` :27 and the `{outcome: confirm, kind, statementType, tables}` answer :50-60, the sibling of this story's ask-first answer; `Read` :126, `Check` :151, `Gate` :226 (`Screen.Gate.Evaluate` on the descriptor, then `Kernel.Denial.Envelope`), `RenderFault` :243.
- **`src/OcuPilot/Kernel/State/SqlRun.cls`**:
  - properties :39-69 (`RunKey`, `UserName`, `Namespace`, `State`, `JobId`, `CancelRequested`, timestamps, `Answer`);
  - `GuardedReserve` :91. Its live-row select is :104, the per-user busy check :111, the cap :116 and the ended-row delete :120.
  - `GuardedBegin` :142, `GuardedFinish` :183, `GuardedCancel` :221, `GuardedViewForOwner` :266, `GuardedSweep` :302, `Reconcile` :341, `LockHeld` :382, `IdForOwner` :396.
- **`src/OcuPilot/Kernel/Agent/Limits.cls`**: `RETENTIONSECONDS` 900 :28, `QUEUEDSECONDS` 10 :60. **`Kernel/Retention.cls`**:61 sweeps runs daily.
- **`src/OcuPilot/Port/SqlPort.cls`**: `MAXSTATEMENT` :89, `MAXROWS` :95, `MAXCELL` :105, `MAXANSWER` :107; `BoundSeconds` :321; `Executed` :1013, whose fetch loop :1049-1097 becomes `FetchRows`.
- **`src/OcuPilot/Api/Router.cls`**: routes :245-247 (the `:id` routes first), and the handlers :1820-1840.
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
  - `Test/ClassicPageGate.cls` :437-479 and `Test/Retention.cls` :295;
  - the fixtures `SqlBackgroundFixture`, `Delayed`, `Unspawned`, `Unindexed` and `Probe`, and `SqlPortFixture.PROBESECONDS`.
- **`Test/DeveloperFloorRoutes.cls`** :94-95, the GET and other route lists. **`Test/EndpointCoverage.cls`** `XData Probes` :73, whose SQL background rows :259-261 set the row format.
- **`Test/StageTwoTools.cls`** `XData Elsewhere` :121. The load-bearing test is `TestTheRosterAndElsewhereAreEveryRegisteredScreen` :415.
- **`Test/SurfaceCoverage.cls`** `XData Coverage` :54.
- **`Test/Navigation.cls`**: the analytics block, 10 screens **(20.32, planned)**. **`Test/DeveloperFloor.cls`** `SCREENS` :38.
- **`Test/PortGate.cls`** `ROSTER` :29, with its `AnalyticsPort` row **(20.11, planned)**.
- **The analytics test classes (20.11, planned):** `AnalyticsProbe` (`Enable`, `Create`, `Remove`, `Gone`), `AnalyticsGate` (P1, P2, `EnsurePrincipals`) and `AnalyticsGateSeam`.
- **`scripts/ci-throwaway.sh`** :444-520: the `# classes:` lines of `OCUPILOT_ALLOW_PRINCIPALS`.

### Client

- **`ui/src/app/areas/system-explorer/sql-query.store.ts`**:
  - `SQL_BACKGROUND_PATH` :38, `BACKGROUND_POLL_MS` :41, `backgroundPath` :44;
  - the ask-first sibling: `SqlConfirm` :65, `confirmOf` :99, `consequenceFor` :107, `confirm()` :215, the `confirm` branch of a run :268-288, `proceed` :291, `cancelConfirm` :394;
  - `refusalText` :115, `backgroundViewOf` :124, `backgroundStatusLineFor` :144;
  - `startBackground` :327, `pollBackground` :369, `cancelBackground` :379, `stopPolling` :389, `attach` :443, `readBackground` :453, `schedulePoll` :483.
- **`sql-query.page.ts`**: `trackTemplate` :49; the background section :153-175; the `#grid` template :176-209; the `WarningDialog` :210-216 and its `confirming`/`consequence`/`onProceed`/`onCancel` :402-452; leaving the page cancels a pending confirmation and stops polling :249-256.
- **`ui/src/app/shell/warning-dialog.ts`** `WarningDialog` (`app-warning-dialog`): inputs `verb` and `consequence` :93-97, outputs `confirmed` and `cancelled` :114-118. Proceed is `button-primary`, Cancel takes initial focus.
- **`core/sql-answer.ts`** `answerOf`/`statusLineFor`; this story imports it only.
- **`core/poll-schedule.ts`** `schedulePoll`; **`core/screen-read.ts`** `screenReadPath` :177.
- **`shell/screen-outlet.ts`** `DESCRIPTOR_PAGES` :100, with the SQL page's line at :215.
- **`core/strings.ts`**: `explorerSqlConfirmTitle` "Run this statement?" :5443; the SQL background strings :5513-5527. **`src/styles/_components.scss`**: the SQL query styles :7862-7915.
- **`ui/tools/self-protection.test.mjs`** :610-660 pins each refusal sentence to `strings.ts` and EXPERIENCE.md. **`ui/tools/analytics.test.mjs`** **(20.11, planned)** is the analytics twin. **`ui/tools/build-output.test.mjs`** `LAZYCHUNKMAX` 88 kB :267.
- **Browser:**
  - `ui/browser/system-explorer-sql-query.browser-spec.mjs`: `structural` :91-113, `makeBackgroundProbe` and `removeBackgroundProbe` :124/:133, `backgroundReads` :144, AC11 :235-254;
  - `structural-walk.mjs` (`VIEWPORTS`, `INVARIANTS`, `detectScreen`, `compare`, `readBaseline`, `assertThrowaway`);
  - `analytics.browser-spec.mjs` **(20.11, planned)**: `before`/`after` with `AnalyticsProbe`.
- **EXPERIENCE.md**: the Side-bar screen lists table :157-170, whose Analytics row is **(20.32, planned)**; the Dialogs list :173, whose "warnings that precede a non-delete write" already hold SQL query's run of a changing statement (Story 19.6) and Data transformations' Test, "its code runs as you" (Story 20.27).

### Vendor (read only; `irislib/%DeepSee/`)

- **`ResultSet.cls`:**
  - `%PrepareMDX(pMDX, ByRef pVariables, Output pResolvedMDX)` :159: it resolves pivot variables from `pVariables` alone and sets the resolved text (:186-202) before it parses (:204), calls `%PrepareObject` (:208, which calls the query's `%Prepare`), and writes the query-text cache node (:213-215);
  - `%ExecuteAsynch` :855. A DRILLTHROUGH forces the wait (:873-878) and its listing runs in the caller (:973-978). Both execute paths call `%InitializeResultsCache` (:794, :926);
  - `%GetStatus` :650 and `%GetQueryStatus` :475, where 100 means done or failed;
  - `%CancelQuery` :598, a class method with no owner check;
  - `%GetQueryKey` :378, `%GetCubeName` :385, `%GetListingResultSet` :418, `%IsDrillThrough` :437;
  - `%GetAxisSize` :2293, `%GetAxisCount` :2318, `%GetOrdinalValue` :2387, `%GetOrdinalLabel` :2461, `%GetFiltersForCellRange` :4018;
  - the RETURN splice :1708-1714 and the `%ORDER BY` splice :2006.
- **`Query/query.cls`**: `queryType` :16 (`SELECT,DRILLTHROUGH,CREATE,DROP,%BITSET`), `%MaxListingRows` 1000 :136; `%Prepare` :190 parses filters and resolves no member; `%InitializeResultsCache` :2570 calls `%PreProcessQuery` :2659/:2776, which resolves members. **`Query/memberComputed.cls`** :93/:300 calls `%ComputeBitset`, which reaches `ComputedDimension/SQL.cls` :38 `%ProcessSQL`, so `%SEARCH`'s braces run at execute (measured, Design Notes › Measured).
  - `%ResolveVariablesInText` :6855 turns an unsupplied `$variable.<name>` into `""`; a stored calculated member's expression resolves with the query's own variables (:4704-4711), which are the ones `%PrepareMDX` was handed.
  - `%ResolveNamedParm` :5154 runs `X` on a braced `%PARM` value (:5178-5181), reached from `constant.cls` :28-38 and `memberSpec.cls` :120.
- **`Query/Parser.cls`**:
  - `%Tokenize` :99 (`[Internal]`, `pTokens(n) = $LB(type, value)`). `%NextToken` :254 drops `/* */`, `//` and `--` comments outside a bracket (:273-305), makes `'` a token by itself (:333-347), a `[…]` one `QSTR` token that keeps a comment (:292, :348-353), and a `"…"` literal one `LIT` token (:354-358, :523-538). `%UnquoteIdent` :197. They set only the parser's own properties (inference from source: :99-114, :254-610).
  - The vendor's own recognition, which the detector mirrors: `%ValidateText` :3448 matches `$$$UPPER` of `%Tokenize`'s values (`%SQLRESTRICT` :3473); `%SEARCH` as `%SEARCH` or `[%SEARCH]` (:263, :2560, :2637); `RETURN` :3080, whose `%LISTING` form names a stored listing (:3085-3137); `%ORDER` after it (:3163-3170); `%PARM` :958, whose braced value enters state 21 (:1291-1294, :1310-1314), which no branch handles. There is no `%KILL`.
- **`ComputedDimension/Base.cls`**: `%ProcessSQL`'s `{…}` is evaluated as ObjectScript (:653, :796-829).
- **`UI/MDXQuery.cls`**: `RESOURCE` `%DeepSee_Admin,%Development` (:15), re-checked in `%OnPreHTTP` (:518-528). It has no cancel button, no timeout and no confirmation.
- **Elsewhere:** `%SYSTEM/WorkMgr.cls`:38-39 (agents run in the caller's security context); `%SYS/Namespace.cls` `GetGlobalDest` :93.

## Tasks & Acceptance

**Execution:**

- [x] **Task 0 (re-anchor and measure, no product code).** First run `git rev-parse --show-toplevel` and confirm it is `/Users/jbrandt/git/OcuPilot/.worktrees/epic-20`.
  - **Re-anchor.** After 20.11 and 20.32 merge into this branch, re-anchor every (20.11, planned) and (20.32, planned) symbol above. If the links do not hold positions 4-6, MDX query takes the next free position.
  - **Contention.** Run `git diff --stat origin/feature/OCU-1_ocupilot-mvp...origin/OCU-1-epic23` from this working directory. Any file this story edits beyond add-only lines goes to the lead before Task 1.
  - **Measure on `ocupilot-b-ci`**, removing what you create:
    1. The slow query for the job tests. Find a crossjoin over `AnalyticsProbe`'s grid cube (below) that runs at least 10 s. At plan time a 2,000 × 2,000 `NON EMPTY` crossjoin over 50,000 facts took 20 s for its axes and 122 s in all.
    2. `%GetOrdinalLabel`'s label order for a crossjoin tuple. Fix outer-to-inner in the answer.
    3. How a listing's column names are read. `%GetListingResultSet`'s field list came back empty at plan time; use the statement's metadata.
    4. That `$SYSTEM.SQL.CancelQuery` sent to a job that runs no SQL returns at once.
    5. The run of `%PrepareMDX`, `%ExecuteAsynch` and the poll from a `JOB`'d process, the port switching namespace for each call.
    6. That the strings' values are unique, and that the literal count stays more than 50 under `strings.test.mjs`'s bound.
    7. The ask-first statements over the grid cube: the `%SEARCH` text whose braces run `$Increment(^OcuPilotProbeMdxSplice(<n>))` in USER, its `%SE/**/ARCH` spelling, and the `%PARM` text. On a scratch cube, `%PrepareMDX` alone left the node undefined and execute defined it, and the `%PARM` text failed prepare (Design Notes › Measured). Confirm both on the grid cube and record the texts the tests use.

    A measurement that contradicts this spec halts the stage with its evidence.
- [x] **`src/OcuPilot/Kernel/State/SqlRun.cls`**: add `Kind` (`MAXLEN` 16, `InitialExpression` `"sql"`).
  - `GuardedReserve` gains a trailing `pKind` (default `"sql"`). The busy check and the ended-row delete count only rows of `pKind`, while the instance cap counts live rows of every kind. A row with no `Kind` reads as `sql`.
  - `IdForOwner`, `GuardedViewForOwner` and `GuardedCancel` match the kind too, with a trailing `pKind` defaulting to `"sql"`.
  - Add `GuardedCancelRequested(pKey, Output pRequested)`, a fresh SQL read, never a held OREF.
  - Doc comments name both kinds.
- [x] **`src/OcuPilot/Kernel/Shell/BackgroundRun.cls`** (new, abstract): move the slice-free part of `SqlBackground` into it, behavior unchanged:
  - the reserve and spawn, the one `JOB` and the job entry (owner check, begin, cancel-before-begin, the screen gate again);
  - the poll and cancel routes' screen gate on the subclass's `DESCRIPTORCLASS` (`Screen.Gate.Evaluate`, then `Kernel.Denial.Envelope`);
  - `Cancel`, `View`, the 404 / busy / full / lost faults and `Envelope`/`Render`/`Finish`/`Log`.

  Each kind supplies hooks: `Admit` (the start's checks, answering a refusal, an immediate 200 answer or the request list the job is handed), `Work` (the job's work), `CancelJob` (what a cancel sends to the job), `Kind`, and the codes and reasons. **`Area/Explorer/SqlBackground.cls`** becomes a subclass holding only SQL's checks and its `CancelQuery` loop, its seams and public methods unchanged. **`scripts/check-objectscript.py`**'s `JOB_ALLOWED` names the new file in place of `SqlBackground.cls`, and **`scripts/test_check_objectscript.py`**'s case moves with it.
- [x] **`src/OcuPilot/Port/SqlPort.cls`**: move `Executed`'s fetch loop into a public `FetchRows(pSet, pColumns, pMaxRows, Output pRows, Output pTruncated, Output pMore, Output pCut)` with `MAXCELL` and `MAXANSWER` as now; `Executed` calls it.
- [x] **`src/OcuPilot/Api/AnalyticsError.cls`** (add to 20.11's class): `MDXINPUT` 400, `MDXKIND` 422, `MDXAXES` 422, `MDXREADONLY` 409, `MDXBUSY` 409, `MDXFULL` 503, `MDXNOTFOUND` 404 and `MDXLOST` 503. Codes are `ANALYTICS.MDX.*`; each sentence is in Design Notes › Strings. No `MDXSQL`: that code is Story 20.35's.
- [x] **`src/OcuPilot/Port/AnalyticsPort.cls`** (extend 20.11's port):
  - **Parameters.** `MDXPAIRS` `%DeepSee_Portal:USE,%Development:USE`; the named limits in Always, each doc comment giving its reason (Design Notes › Limits); `MDXCONSTRUCTS` `%SEARCH,%SQLRESTRICT,RETURN,%ORDER,%PARM`; `MDXSTRINGDEPTH` 3, how deep a string literal is read; and `MDXCONSEQUENCE` "This query runs server-side code or SQL with your rights."
  - **`MdxAdmit(ns)`.** The gate in Always' order. The cache database is resolved by `GetGlobalDest` and checked WRITE and not read-only.
  - **`MdxConstructs(text, Output found, Output unread) As %Boolean`.** Public, the one detection of AD-65's splice clause; it writes nothing and switches no namespace. It answers 1 when:
    - a token of `%DeepSee.Query.Parser.%Tokenize(text)`, a `[…]` token unquoted as `%UnquoteIdent` does, then upper-cased, equals a member of `MDXCONSTRUCTS`;
    - or a token of a string literal does: each `LIT` token's value is tokenized the same way, to `MDXSTRINGDEPTH` levels;
    - or, fail closed with `unread` 1, the text is blank, a tokenize answers an error or throws, or a literal lies deeper than `MDXSTRINGDEPTH`.

    `found` is a `$ListBuild` of the names found, in `MDXCONSTRUCTS` order, without repeats (empty when only `unread` is set). A single-quoted span needs no rule: `'` is a token by itself, so its content is in the stream (measured). Story 20.35 calls it for its refusal.
  - **`MdxPrepare(ns, text, .rs, .answer, .http, .fault, .ask, .found, .variables)`.** Prepares with `%PrepareMDX(text, .variables, .resolved)` and classifies; executes nothing. A prepare error is `{outcome: "error", message}`. Kinds and axes are refused here. Then it runs `MdxConstructs` on `$Get(resolved)`, so an unreadable resolved text reads blank and asks: `ask` is that answer and `found` its names. No production caller hands `variables` (Design Notes › Named limits).
  - **`MdxStart(ns, rs, .cube, .key)`**, **`MdxStatus(ns, rs, .error)`** and **`MdxCancel(ns, cube, key)`**.
  - **`MdxDrill(ns, rs, row, column, .drill, .http, .fault)`**, called on an executed original: an ordinal past its axis's size is refused 400 `ANALYTICS.MDX.INPUT`; otherwise it reads `%GetFiltersForCellRange` for that one cell, composes `DRILLTHROUGH MAXROWS <MDXMAXLISTINGROWS> SELECT FROM [<cube>] %FILTER <f>…` with the cube name bracket-quoted (`]` doubled), and prepares it.
  - **`MdxAnswer(ns, rs, seconds)`.**
    - `cells`: each column header and each row's `label` joins that position's labels with " / ", outer to inner; a query with no rows axis answers one row whose label is empty; the caps applied.
    - Listing `rows`: through `SqlPort.FetchRows`.
    - Zero axes read as one cell.
  - **Every vendor call** switches namespace by explicit save and restore (AD-16), calls no `OcuPilot.*` class while switched, and maps a vendor status or `<PROTECT>` as 20.11's reads do.
  - **The class doc** names AD-65's MDX clauses.
- [x] **`src/OcuPilot/Screen/Descriptor/AnalyticsMdxQuery.cls`** (new; sibling `ExplorerSqlQuery`):
  - route `analytics/mdx-query`; area `analytics`; `labelKey` `analyticsMdxQueryLabel`; `sideBarPosition` 7; archetype `form-page`; `built` true; `refreshes` false;
  - `privileges` `[%DeepSee_Portal:USE, %Development:USE]` and `ownPrivileges` `[%Development:USE]`;
  - `entityType` `cube`, scope `namespace`, id `none`; no actions; context empty;
  - `commandAliases` `["mdx query", "run mdx", "mdx"]`; three prompts in `webAppPromptGroupCode`;
  - `classicPage` `%DeepSee.UI.MDXQuery`; `toolIdentifier` `analytics.mdxquery`.

  The doc names AD-5, AD-8, AD-29, AD-36, AD-44 and AD-65.
- [x] **`src/OcuPilot/Area/Analytics/MdxQuery.cls`** (new; extends `Kernel.Shell.BackgroundRun`, `Kind` `mdx`):
  - **`Admit`.** Reads the body `{statement, drill?, confirmed?}` and the scope. `statement` is a string, `drill` is `{row, column}` (positive integers within `MDXMAXROWS` and `MDXMAXCOLUMNS`), `confirmed` is absent or `true`; any other key or shape is 400 `ANALYTICS.MDX.INPUT`. Then, in order:
    1. `MdxAdmit`;
    2. `MdxConstructs` on the statement: when it answers 1 and `confirmed` is absent, 200 `{outcome: "confirm", constructs: found, consequence: MDXCONSEQUENCE}` (`constructs` empty for an unread statement);
    3. `MdxPrepare` with `Variables()`, and its refusals and error answer;
    4. the same confirm answer when `MdxPrepare`'s `ask` is 1 and `confirmed` is absent.

    It reserves and spawns nothing for a refusal, an error answer or a confirm answer. The request list is `$ListBuild(statement, row, column, confirmed)`.
  - **`Work` (the job).** It repeats the gate, both checks and `MdxPrepare`. A finding the flag does not confirm ends the run `failed` with `MDXLOST`'s envelope, as `FinishRefused` ends a refused SQL run, and executes nothing. Then:
    1. The run loop: `MdxStart`, then every 0.1 s `MdxStatus` and `GuardedCancelRequested`. On a cancel, or at `$ZHorolog` past `BoundSeconds()`, it calls `MdxCancel`, waits up to `MDXSETTLESECONDS` for status 100, and ends `canceled` or `{outcome: "stopped", seconds}`.
    2. For a drill, the loop runs the original, then `MdxDrill`; the listing's start (`MdxStart`, which waits for the MDX portion) and its read (`MdxAnswer`, where the listing's SQL runs when its rows are fetched, measured) each run under `$System.Alarm.Set` of the time that remains, as `SqlPort.Executed` bounds its statement. `<ALARM>`, or the SQL engine's -450, stops the run. A typed `DRILLTHROUGH` is that start and read alone.
    3. It finishes with `MdxAnswer`.
  - **`CancelJob`.** One `$SYSTEM.SQL.CancelQuery(job,,0)`, which reaches a listing statement.
  - **Seams**, beside the kernel class's `PortClass`, `MaxRunning`, `LimitsClass` and `Spawn`: `BoundSeconds()`, which answers `AnalyticsPort.#MDXSECONDS`, and `Variables(Output variables)`, the pivot variables handed to `MdxPrepare`, which answers none. Production overrides neither.
  - **Routes.** `HandleStart`, `HandlePoll` and `HandleCancel` delegate to the kernel class.
- [x] **`src/OcuPilot/Api/Router.cls`** (add-only): `POST /analytics/mdx/background/:id/cancel`, `GET /analytics/mdx/background/:id` and `POST /analytics/mdx/background`, in that order, with thin `AnalyticsMdxBackground*` handlers.
- [x] **`src/OcuPilot/Test/AnalyticsProbe.cls`** (extend 20.11's fixture):
  - `Create` also compiles `OcuPilotProbe.Analytics.Grid` (50,000 deterministic rows: `Sub = i#2000`, `Sub2 = (i\7)#2000`, `Amount = i#100`) and the cube `OcuPilotProbeGrid` (dimensions `Sub` and `Sub2`, measure `Amount`, a listing), and builds it.
  - `Remove` also kills each probe cube's remaining `^DeepSee.Cache.Results(<cube>)` subtree, because `%KillCube` leaves an `activeChunk` node per query key (measured), `^OcuPilotProbeMdxSplice` in USER, and `^DeepSee.ComputedSQL` when its value names a probe class (a `%SEARCH` run leaves its SQL there, measured). `Gone` checks all three.
- [x] **Server tests** (new; the first four armed `OCUPILOT_ALLOW_PRINCIPALS`, `Remove`/`Enable`/`Create` before all, `Remove` and `Gone` after all):
  - **`Test/AnalyticsMdx.cls`** (port):
    - the cells answer equals the vendor's own labels and values, read in the test;
    - the cell drill equals the vendor's listing for the composed text, and an ordinal past its axis is refused `ANALYTICS.MDX.INPUT`;
    - the row, column, cell and total caps;
    - `MdxConstructs`, written first and shown red against cycle 2's detector (the four words as a case-insensitive substring of the raw text) before the token version turns it green:
      - finds each of the five in mixed case, in `MDXCONSTRUCTS` order, and none in a plain SELECT;
      - finds each measured obfuscation: `/**/` inside each of the five words, `%SEARCH` split by a `--` and by a `//` line comment, `%SE/**/ARCH` inside a `%MDX("…")` literal and inside a single-quoted `WITH MEMBER … AS '…'`, and `WITH %PARM P AS 'VALUE:{…}'`;
      - finds `[%SEARCH]` and a member key named exactly `[RETURN]` (the named false positive), and none in `[%SE/**/ARCH]`, whose bracket keeps the comment (Story 20.35's Not-a-construct row);
      - fails closed: an unterminated `[` or `"`, `3rd`, a blank text and a literal nested deeper than `MDXSTRINGDEPTH` each answer 1 with `unread` 1 and nothing found;
    - `MdxPrepare`'s second check: with `variables("v")` holding the `%SEARCH` text (node 10), `… WHERE $variable.v` answers `ask` 1 naming `%SEARCH` and leaves the node undefined; with none, `ask` is 0;
    - CREATE, DROP and three axes are refused, and a syntax error answers the vendor's text;
    - HSCUSTOM answers 409 `ANALYTICS.NAMESPACE`, and HSLIB 409 `ANALYTICS.MDX.READONLY`.
  - **`Test/AnalyticsMdxJob.cls`** (sibling `SqlBackgroundJob`):
    - the owner's cancel ends `canceled` within 12 s, then `'$Data(^$JOB(pid))`, `%GetQueryStatus` 100, and no `%SYS.ProcessQuery` row in USER whose `Routine` starts `%DeepSee`;
    - the bound, through the fixture subclass `Test/AnalyticsMdxFixture` (new) whose `BoundSeconds()` is 2, ends `stopped` with the same three checks;
    - the resolved-text case, through the same fixture, whose `Variables()` hands `v` the `%SEARCH` text (node 5), started as `SqlBackgroundJob` starts its fixture: `… WHERE $variable.v` answers `confirm` naming `%SEARCH`, reserves nothing and leaves the node undefined;
    - a cancel before the job begins;
    - the job's failure log line carries no statement.
  - **`Test/AnalyticsMdxRoutes.cls`** (sibling `SqlBackgroundRoutes`):
    - **ask first:** Task 0's statement with `^OcuPilotProbeMdxSplice(1)`, started without `confirmed`, answers 200 `{outcome: "confirm", constructs: ["%SEARCH"], consequence}` equal to `MDXCONSEQUENCE`, reserves no run row and leaves the node undefined; started with `confirmed: true` it answers 202, ends, and the node is defined;
    - the comment-split `%SE/**/ARCH` text (node 3) asks first the same way, its node undefined until confirmed; the `%PARM` text (node 4) asks first, and confirmed answers the vendor's prepare error with the node still undefined (measured);
    - the tokenizer-failure case: `SELECT FROM [OcuPilotProbeVisits` answers `confirm` with `constructs` empty and reserves nothing; confirmed, it answers 200 `{outcome: "error"}` with the vendor's "Unexpected end of statement" text and spawns nothing. `SELEKT FROM [OcuPilotProbeVisits]` answers `error` with no confirmation;
    - `confirmed` of any value but `true` is 400 `ANALYTICS.MDX.INPUT`, and a plain SELECT with `confirmed: true` runs as it would without it;
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
- [x] **Rosters, each name read from the instance:**
  - `StageTwoTools` `Elsewhere` +1;
  - `SurfaceCoverage` one `<screen>` row naming `AnalyticsMdxDescriptor`;
  - `EndpointCoverage` three probes;
  - `Navigation.cls` analytics block 10 → 11;
  - `DeveloperFloor` `SCREENS` +1;
  - `DeveloperFloorRoutes` the GET and the two POSTs;
  - `InteropFloor` unchanged: its principals hold no `%Development` (checked at the sweep).
- [x] **`scripts/ci-throwaway.sh`**: `# classes:` entries for the four armed classes.
- [x] **`ui/src/app/core/background-run.ts`** (new, framework-free): move `SqlQueryState`'s start, attach, poll, cancel, stop and read logic into `BackgroundRun`, configured by its base path, its busy code and its answer parser. A start's 200 answer goes back to the caller. The generation guard, the re-poll on `installing`, status 0 or ≥500, and the clear on 404 all move with it. `SqlQueryState` keeps its public API and delegates; its specs stay unchanged.
- [x] **`ui/src/app/shell/result-grid.ts`** (new): move the SQL page's `#grid` template and `trackTemplate` into `ResultGrid` (inputs `answer`, `label`, `slot`). The SQL page uses it and its DOM is unchanged, `data-ocu-sql` slots included.
- [x] **`ui/src/app/core/strings.ts`**: add the literals in Design Notes › Strings (add-only).
- [x] **`ui/src/app/core/mdx-answer.ts`** (new): `mdxAnswerOf(body)` for `cells`, `rows` (through `answerOf`), `error` and `stopped`; `mdxConfirmOf(body)` for `confirm`, answering its `constructs` or `null`; and `mdxStatusLineFor`.
- [x] **`ui/src/app/areas/analytics/mdx-query.store.ts`** and **`mdx-query.page.ts`** (new):
  - **Cube select.** Fed by `screenReadPath` of `analytics.cubes`. A pick fills the statement with `SELECT FROM [<name>]` only while the statement is empty.
  - **Statement and Run.** A statement textarea, and Run, disabled while a run is live.
  - **The run.** A `BackgroundRun` at `/api/ocupilot/analytics/mdx/background`: a status line, Cancel while running, and a refusal banner. A vendor error shows in a `<pre>`.
  - **Ask first.** A `confirm` answer holds the statement it was asked for and draws `WarningDialog` with `verb` `analyticsMdxConfirmTitle` and `consequence` `analyticsMdxConfirmConsequence`. Proceed starts that statement with `confirmed: true`; Cancel, Escape and the scrim close it with nothing sent; leaving the page or changing namespace drops it, as the SQL page does.
  - **The cells grid.** The page's own template on `.ocu-data-table-*`: a first column headed `analyticsMdxRowHeader` whose cells are `role="rowheader"` labels, drawn only when some row has a label. Each value cell is a `<button>` with the `analyticsMdxDrillCell` label, which starts a drill of the last-run statement at that row and column, carrying that run's `confirmed`. The cells stay shown while the drill runs.
  - **The listing.** Under "Drill-through" in `ResultGrid`.
  - **Slots.** `data-ocu-mdx` slots for the tests. No inline color, tokens only; a style the drill buttons need is an add-only rule in `_components.scss`.
- [x] **`ui/src/app/shell/screen-outlet.ts`**: one `DESCRIPTOR_PAGES` loader line, then run `cd ui && node tools/screen-mirror.mjs`.
- [x] **Client tests:**
  - `ui/tools/background-run.test.mjs` (start, a 200 answer returned, busy attach, poll, cancel, 404 clear, transient re-poll, stale answer dropped);
  - `ui/tools/mdx-answer.test.mjs` (each outcome, `mdxConfirmOf` included, which answers `[]`, never `null`, for a `confirm` with empty `constructs`);
  - `ui/tools/analytics.test.mjs`: the eight `REASONMDX*` sentences and `MDXCONSEQUENCE` equal their `strings.ts` value and EXPERIENCE.md literal;
  - `mdx-query.page.spec.ts`: run, cancel, the cell button's drill request body, the picker fills only an empty statement; a `confirm` answer draws the dialog with the consequence, Cancel sends nothing more, Proceed re-sends the asked statement with `confirmed: true`, a drill after a confirmed run carries it, a `confirm` with empty `constructs` draws the same dialog, and a plain run draws no dialog;
  - `result-grid.spec.ts`;
  - `ui/tools/navigation.test.mjs` (the route) and `ui/tools/screen-mirror.test.mjs` (the owners list).
- [x] **`ui/browser/analytics-mdx.browser-spec.mjs`** (new). `before` refuses the live container, requires readiness, and runs `AnalyticsProbe` `Remove`, `Enable` and `Create`. `after` runs `Remove` and asserts `Gone`. Each leg carries its mutation comment:
  - **AC1:** in USER, the cells query's grid equals the instance's answer, read through `runIris`, and no dialog opens.
  - **AC2:** a cell's drill shows the listing the instance answers for that cell.
  - **AC3:** the slow query's Cancel reads "Canceled.", and `runIris` finds nothing running.
  - **AC5:** a CREATE statement shows its refusal sentence.
  - **AC8:** `structural` on `analytics/mdx-query` with a result shown finds no fresh entry at 1280 light, 720 light or 1280 dark.
  - **AC10:** Task 0's statement with `^OcuPilotProbeMdxSplice(2)` opens the dialog with the consequence sentence, and `structural` with it open finds no fresh entry at 1280 light or 1280 dark. Cancel closes it and `runIris` reads the node undefined; Run and Proceed end the run, and `runIris` reads it defined.
  - If `structural-walk.mjs`, which walks the route in HSCUSTOM, reports a fresh entry for it, fix the page, or append the entry as that file says.
- [x] **`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`** (add-only):
  - the Analytics row of the Side-bar screen lists table (:157-170, written by 20.32) gains "MDX query (Story 20.33)" after 20.32's entries;
  - the Dialogs list :173 gains, among the warnings that precede a non-delete write, "run an MDX query whose text runs server-side code or SQL (MDX query, Story 20.33)";
  - the Fixed strings get one row with this story's literals;
  - run `cd ui && npm run test:tools`.
- [x] **Roster sweep (Rule 30).** Search `src/OcuPilot/Test`, `ui/tools`, `ui/browser` and the `ui/src` specs for the analytics side bar, the built-screen count, `SCREENS`, the developer route lists, `JOB_ALLOWED` and `SqlBackground`. Each changed file joins `(loop)`.

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
- **AC5 (never a write).**
  - **Given** a CREATE or DROP, or three axes.
  - **When** it is started.
  - **Then** it is refused by its code and sentence before any spawn, and OcuPilot writes nothing to the instance.
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
- **AC10 (ask first; orchestrator ruling Q2 C, AD-65).**
  - **Given** `AnalyticsProbe` in USER and a statement whose `%SEARCH` braces define `^OcuPilotProbeMdxSplice(<n>)`.
  - **When** the person runs it, then cancels the confirmation, then runs it again and proceeds.
  - **Then** the first run opens the warning "This query runs server-side code or SQL with your rights." with nothing started and the node undefined; Cancel sends nothing; Proceed starts it with the confirmation, the run ends, and the node is defined. A start without the confirmation answers `confirm` naming the consequence, reserving and preparing nothing. Each of the five constructs is detected in the vendor's tokens and in a string literal's, a comment inside a word included. A statement the detector cannot read is asked the same way; one whose variable-resolved text names a construct is asked after a prepare that executes nothing. A statement without them runs with no dialog.

### Review Findings

Code review, 2026-10-21 (four layers; each patch verified on `ocupilot-b-ci`, mutations in Verification).

- [x] [Review][Patch] HIGH: a SELECT's start had no alarm, and the vendor runs a member's SQL inside the start, so a confirmed `%SEARCH` (or a cube's SQL computed dimension) escaped the 120 s bound (AD-42, AD-7; measured: its SQL ran in the job until an alarm ended it with SQLCODE -450) [src/OcuPilot/Area/Analytics/MdxQuery.cls:366]
- [x] [Review][Patch] The alarm in a start reads as SQLCODE -450 (#5540), which `Execute` answered as an error; `Alarmed` reads it as the bound (QA item b) [src/OcuPilot/Area/Analytics/MdxQuery.cls:437]
- [x] [Review][Patch] A cancel that reached no statement (during the job's checks, a start or between a drill's steps) was lost until the listing ended or the bound; the job now reads its flag before each start and each listing's read [src/OcuPilot/Area/Analytics/MdxQuery.cls:289]
- [x] [Review][Patch] A typed DRILLTHROUGH sent with a `drill` was re-composed as a cell drill, dropping the person's `MAXROWS`; refused 400 `ANALYTICS.MDX.INPUT` at the start and in `MdxDrill` (QA item a) [src/OcuPilot/Area/Analytics/MdxQuery.cls:96]
- [x] [Review][Patch] An axis the vendor answered empty read as one blank position (`%GetRowCount` floors at 1), and its blank cell drilled to the slicer's facts; positions now come from `%GetAxisSize` [src/OcuPilot/Port/AnalyticsPort.cls:1141]
- [x] [Review][Patch] A drill after a namespace change ran the old grid's statement, with its confirmation, in the new namespace; a grid is drilled only in the namespace it ran in [ui/src/app/areas/analytics/mdx-query.store.ts:298]
- [x] [Review][Patch] A drill cell's accessible name replaced its value, so a screen reader never read the grid's values; the name is the value, then the drill label [ui/src/app/areas/analytics/mdx-query.page.ts:333]
- [x] [Review][Patch] The total cap's assertion could not fail (`a && b <= c` reads `(a && b) <= c`) and its leg was cut by the row and cell caps first; the leg now stays under them [src/OcuPilot/Test/AnalyticsMdx.cls:291]
- [x] [Review][Patch] The total cap counted headers approximately and no envelope, so a full answer reached 1,000,163 characters; the answer's frame is measured by its own JSON [src/OcuPilot/Port/AnalyticsPort.cls:1070]
- [x] [Review][Patch] An execute-time vendor error (an unknown measure) had no test; the route leg polls it to the vendor's text [src/OcuPilot/Test/AnalyticsMdxRoutes.cls:250]
- [x] [Review][Patch] The resolved-text test's "reserved no run" assertion called `Check`, which cannot reserve; removed (the route's ask-first test pins the shared no-reserve branch) [src/OcuPilot/Test/AnalyticsMdxJob.cls:351]
- [x] [Review][Patch] The Never-list scanner missed a `^["ns"]` extended reference to the vendor's cache [ui/tools/analytics.test.mjs:144]
- [x] [Review][Patch] Stale doc text: `MdxStart` (listing runs in the start), `Execute`, `CancelJob`, `SLOWLISTING`, `AnalyticsProbe` (cube count) and `AnalyticsGate` (cube count) [src/OcuPilot/Port/AnalyticsPort.cls:859]
- [x] [Review][Defer] Spine AD-42 :963 still names `Area/Explorer/SqlBackground` as the spawn site [ARCHITECTURE-SPINE.md:963] — deferred: DW-2489, open for the lead (spine is lead-owned)
- [x] [Review][Defer] `MdxStatus` reads 100 as done without the pending-results flag, so a plugin cell may be read early [src/OcuPilot/Port/AnalyticsPort.cls:884] — deferred: DW-2490, maybe-false, routed to 20.35; settled by a `%KPI("%DeepSee.Median")` run
- [x] [Review][Defer] A `<PROTECT>` from `MdxStart`/`MdxStatus` shows as the run's error text, not a 403 [src/OcuPilot/Port/AnalyticsPort.cls:859] — deferred: DW-2491, wontfix-accepted (low)
- [x] [Review][Defer] A cancel during a DRILLTHROUGH's MDX portion waits for that wait or the bound [src/OcuPilot/Area/Analytics/MdxQuery.cls:478] — deferred: DW-2492, wontfix-accepted (low)

Rejected:

- `false`: `MdxStatus` below 100 with an error loops to the deadline -- `%GetQueryStatus` answers 100 whenever an error is recorded (`ResultSet.cls`, `%GetQueryStatus`).
- `false`: the job's prepare runs outside the bound -- `%PrepareMDX` resolves no member; member resolution is in the start, now under the alarm.
- `false`: a run can outlast 120 s by the settle -- `MDXSETTLESECONDS` is the named settle after the bound.
- `false`: the port's fault log lines carry vendor text that quotes the statement -- only raised exceptions are logged; statement errors are answers, never logged (`TestTheJobsFailureLineCarriesNoStatement`).
- `false`: the SQL console's DOM changed -- the `app-result-grid` host is `display: contents`; its slots and the SQL specs are unchanged.
- `false`: an earlier error stays beside a later refusal or confirmation -- the last answer stays until a new run is accepted, as the grid does (Decided in-stage).
- `low`: a drill cell clips a value wider than its column with no ellipsis (`display: flex`) -- cells are short values; the fix changes the cell's layout under the structural walk.
- `low`: a busy refusal attaching another tab's run that ends with cells reads a row count with no grid -- rare, and the fix adds a branch.
- `low`: a query with no rows axis names its cells "Drill through , <column>" -- the string's shape is specified; the value now leads the name.

### Rework (smoke)

- [x] [Smoke] The runner's full ObjectScript sweep (merged tree `96eaf715`, `ocupilot-b-ci` run 611): `OcuPilot.Test.SaveHoldCoverage.TestEveryWriteRouteTakesTheHoldOrIsExempt` reds on the two new write routes this story added, `POST /analytics/mdx/background` and `POST /analytics/mdx/background/:id/cancel`. Neither takes a target hold, and neither is listed in `SaveHoldCoverage.Exemptions`. What the fix must do: add one exemption row for each, with its reason, mirroring the SQL console's two rows (`POST /explorer/sql/background`: runs only a statement in the caller's own background run; `.../:id/cancel`: stops the caller's own background run, which is OcuPilot's own state). The MDX start writes nothing to the instance (AC5) and the cancel stops only the caller's own run. Confirm with `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.SaveHoldCoverage` green. Record a `mutation:` line: drop one of the two rows, and that test goes red naming its route.

## Spec Change Log

- 2026-10-14, spec gate (runner): the orchestrator ruled Q1 (A, the agent's read is Story 20.35, chartered) and Q2 (C: the screen asks first and runs on confirmation; the agent refuses). The intent contract carries Q2 C; status reset to `draft` for a re-plan around it. The spine's AD-65 clause is written.
- 2026-10-14, spec gate (runner, cycle 2): the intent contract's `Spliced` row follows Q2 C (Design Notes' erratum applied); the spine carries the Story 20.33 clauses in AD-7, AD-8, AD-21, AD-36, AD-41, AD-42, AD-44 and AD-65.
- 2026-10-15, lead (orchestrator ruling Q1 B at 20.35's plan gate): the one detector reads the vendor's tokens and each quoted string's tokens, the set gains `%PARM`, a second check runs on the variable-resolved text after prepare, and it fails closed; stored definitions are a named limit (DW-2451). Back to `draft` for a plan amendment that measures the resolved-text check now; each measured obfuscation reddens the detector before the fix, with one resolved-text and one tokenizer-failure case per path.
- 2026-10-15, spec gate (runner, cycle 3): the intent contract's five errata applied as Design Notes suggested (`Syntax` row input `SELEKT FROM [OcuPilotProbeVisits]`; `Spliced` row, Approach and Never bullets name five constructs and an unreadable statement; the Always bullet's sentence split); AD-65's Story 20.33 clause names five constructs.

## Review Triage Log

### 2026-10-21 -- Review pass

- verdicts: 15 findings -- high 0, medium 3, low 4, false 8, maybe-false 0
- findings:
  - `[medium]` `[patch]` The ended-row delete in `GuardedReserve` is not pinned to the run's kind (verification-gap) -- verified: the per-kind test ended only the MDX run, so a delete ignoring the kind left every assertion green. Patched: the test ends both runs and asserts each kind's reserve replaces only its own ended run (`SqlRunStore.TestAnOwnerHasOneLiveRunOfEachKind`); mutation observed red and recorded.
  - `[low]` `[patch]` A kind-less row is tested through the lookups, not the reserve path (verification-gap) -- verified: `Reconcile` answering the raw kind left the test green. Patched: one reserve against the kind-less row must name it busy (`SqlRunStore.TestLookupsMatchTheKind...`); mutation observed red and recorded.
  - `[medium]` `[patch]` The bound and cancel paths of the DRILLTHROUGH wait have no test (verification-gap) -- verified and larger than filed: a probe on the throwaway showed `%ExecuteAsynch` of a DRILLTHROUGH returns in 0.2 s and the listing's SQL runs at the first `%Next()` in `MdxAnswer`, outside the alarm, so a slow listing ignored the bound (a run ran 18 s under a 2 s bound); the cancel reached it (`CancelQuery`). Patched: `MdxAnswer` takes `pBound` and arms the alarm around the fetch (SQLCODE -450 or `<ALARM>` answers `stopped`), `MdxQuery.Process` passes the time that remains, and the alarm's seconds are rounded up, never zero (`Alarm.Set(0)` never fires, measured). Three new job tests pin the listing's bound, a sub-second bound and the listing's cancel, each with a mutation observed red. The fix is inside this story's own new code and the spec's intent (bound the listing) is unchanged; the Tasks sentence that placed the wait in `MdxStart` is corrected at its origin.
  - `[false]` `[reject]` A cancel during the blocking branch ends the run `ended` with the vendor's text, not `canceled` (verification-gap, other) -- `GuardedFinish` ends a run whose cancel flag is set `canceled` whatever the work answered; `TestTheOwnersCancelEndsAListingRunCanceled` reads `canceled` against a real slow listing.
  - `[low]` `[patch]` A test title claims a Proceed that outran the namespace change (page spec) -- verified: the body never calls Proceed after the change. Patched: the title says what the body pins.
  - `[low]` `[patch]` A fixed `Hang 1` stands in for the job's exit before the local-cache count (`AnalyticsMdxJob`) -- verified: the run row ends before the job closes its result sets, so only a slow instance could redden it. Patched: the test waits on the job's exit (`AwaitExit`), after each run and before the count.
  - `[false]` `[reject]` Rule 19 legs without a recorded mutation (the HSCUSTOM and HSLIB legs, the custom-resource and -99 legs, the roster rows, the column and total caps, the client ordinals) -- Rule 19 asks one demonstrated mutation per acceptance criterion, and AC1 to AC10 each carry one or more.
  - `[low]` `[reject]` The holder-side assertion in `ClassicPageGate.TestAnAssignedPageGatesTheMdxRun` accepts any answer but the page resource's refusal -- it pins what it claims (the page resource is not what refuses the holder); a refusal by another pair is the port's own gate, pinned by `AnalyticsMdxGate`; a tighter assertion needs the holder's exact answer, which the leg does not own.
  - `[medium]` `[patch]` Paths with no test at any surface: the bound and cancel of the blocking DRILLTHROUGH path (intent-alignment) -- the same root cause as the third row above; closed there.
  - `[false]` `[reject]` Rows asserted below the HTTP surface (row cap, cancel proofs, the five words, the cells oracle) (intent-alignment) -- the spec's Tasks put each of these at the port or job class, and each ran green; the cells oracle reverses labels because Task 0 fixed outer-to-inner, and its mutation is recorded.
  - `[false]` `[reject]` The second detection, on the resolved text, is reachable only through the seam (intent-alignment) -- by design: no production caller hands variables (Named limits), and the recorded mutation reddens the port and job cases.
  - `[false]` `[reject]` The job's screen-gate repeat is pinned for the SQL kind (intent-alignment) -- the MDX job runs the same `BackgroundRun.Run`, and the MDX start and job both call `MdxQuery.Check`, so one gate path serves both; the custom-resource leg pins the MDX routes.
  - `[false]` `[reject]` The input 400 precedes the pair 403s, and a busy 409 follows a prepare (intent-alignment) -- the order is the Tasks' `Admit` order: body, `MdxAdmit`, detection, prepare, then reserve.
  - `[false]` `[reject]` Two users running the same text share the vendor's cancel (intent-alignment) -- a named limit (measured), not a defect.
  - `[false]` `[reject]` The confirmation is a flag in the start body, enforced by the client and the flag (intent-alignment) -- the spec's reading: the carrier is `confirmed: true` in the same body (Design Notes), pinned by the route, page-spec and browser legs.

### 2026-10-21 -- Review pass (rework, the smoke item)

- verdicts: 9 findings -- high 0, medium 0, low 5, false 4, maybe-false 0
- findings:
  - `[low]` `[patch]` Dropping the cancel row cannot redden `SaveHoldCoverage` and no mutation names that row (verification-gap) -- verified: with only the cancel row dropped the class stays green, because the start row's slash boundary exempts the cancel route. Patched: the cancel route's `Url` renamed on the throwaway reddens the stale-row assertion for the cancel row alone (run 728); reverted byte-identical, reloaded, green (run 729). Both mutations are in `## Verification`.
  - `[low]` `[reject]` The start row's slash boundary exempts every later write route under `/analytics/mdx/background/` (verification-gap, other) -- the class's documented rule (a row exempts its own url and every url continuing it after a slash), shared by every row including the SQL console's pair; narrowing it changes the roster's mechanism, which is not this item.
  - `[low]` `[patch]` The new mutation line sat under the "(code review) mutations" heading (verification-gap, other) -- verified. Patched at its origin: the line is its own "(smoke rework) mutations" bullet.
  - `[false]` `[reject]` The start reason's "SELECT or DRILLTHROUGH" claim (verification-gap, other) -- the layer reported it checked and true (`MdxPrepare` refuses CREATE and DROP, with tests); nothing to fix.
  - `[false]` `[reject]` The start reason is silent on the confirmed path and the vendor's own writes (intent-alignment) -- the reason's subject is OcuPilot, as AC5 and the contract word it ("OcuPilot writes nothing to the instance of its own"); a confirmed statement is the person's own server-side code under the confirmation that names it, and only SELECT and DRILLTHROUGH run either way.
  - `[low]` `[patch]` The cancel row is not load-bearing for the route check (intent-alignment) -- the same root cause as the first row; closed there.
  - `[low]` `[patch]` The mutation line covers one row (intent-alignment) -- the same root cause as the first row; closed there.
  - `[false]` `[reject]` The box is ticked with no run record in the diff (intent-alignment) -- the runs are recorded in this pass's `## Auto Run Result` and the mutation lines; a spec's tracking carries no run record in a diff.
  - `[false]` `[reject]` The `DeveloperFloorRoutes` and `EndpointCoverage` rosters already carry the MDX routes and only `SaveHoldCoverage` lacked them (intent-alignment) -- a description, not a defect: the sweep's red named this class alone.

## Design Notes

**Intent-contract errata (for the lead).** The Always bullet on the statement carries ruling Q1 B and governs; this plan implements it. Five places predate it:

1. **The `Syntax` row.** `SELECT FROM [OcuPilotProbeVisits` fails `%Tokenize` ("Unexpected end of statement", measured), so under Q1 B it asks first, and confirmed it answers the vendor's error. The plan pins the row's behavior with `SELEKT FROM [OcuPilotProbeVisits]` (measured: it tokenizes, and prepare answers "Unknown term at start of query: SELEKT"), and uses the row's text as the tokenizer-failure case. Suggested input: `SELEKT FROM [OcuPilotProbeVisits]`.
2. **The `Spliced` row** names four words. Suggested: "Text naming `%SEARCH`, `%SQLRESTRICT`, `RETURN`, `%ORDER` or `%PARM` in the vendor's tokens or a string literal's, or text the detector cannot read, without `confirmed`".
3. **The Approach bullet** lists the four; **the Never bullet** says Story 20.35 "refuses those four constructs". Both should say five, and a statement the detector cannot read.
4. **The Always bullet's second sentence** reads as two sentences spliced: the ruling's clause sits between "detects any of …" and "and runs it only when the start request carries the person's confirmation". Suggested: end the ruling's sentence at "(DW-2451)", then "A statement with a finding runs only when the start request carries …".

**Governing ADs (Rule 6).**

- **AD-65:** the port's MDX extension, its gate, and its splice clause: one token detector over five constructs, run before and after prepare, failing closed (the screen asks first, Story 20.35 refuses).
- **AD-29:** the gate before any call (measured).
- **AD-7:** the run never mutates of its own; the vendor's cache is its new cost shape.
- **AD-33 and AD-41:** owner-scoped runs and the bounds.
- **AD-36:** a screen-only payload.
- **AD-8:** the pairs.
- **AD-44:** the classic page.
- **AD-16:** switched calls.
- **AD-21:** the statement is the person's own query, never concatenated by OcuPilot.
- **AD-11 and AD-60:** untrusted text and results; a statement the detector cannot read is treated as one with a finding.
- **AD-42:** the spawn site.
- **AD-5 and AD-19:** a `form-page` with one loader line, and a framework-free store.
- **AD-64:** the screen is adjustable, the port's pairs are not.

Checked and not engaged: AD-6, AD-34 and AD-40, because the confirmation is the person's own step on their own query (AD-65), with no proposal, token or ledger row, on a REST route the model cannot reach (AD-1; this story adds no tool); AD-10, AD-15, AD-22 and AD-51 to AD-53, because nothing writes and no tool or key is added; AD-43, because the screen does not refresh; AD-47 and AD-63, because nothing is framed.

**Measured at the first plan on `ocupilot-b-ci`** (2026-10-14; IRIS for Health 2026.2 build 221U). The probe enabled analytics on `/csp/user`, compiled a 50,000-row source and a three-dimension cube, created two principals, and removed all of it. USER's flags were restored and its `^DeepSee.Cache.*`, `AgentLog`, `Agents`, `Update` and IRISTEMP nodes were cleared. The vendor counters `^DeepSee.Tasks` and `TaskGroups` and statement-index rows stay, as 20.11 names.

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
  - The braces run at execute, not at prepare (measured at the third plan, below). So the start request's prepare runs none of the person's code.
- **Kinds.** After prepare: CREATE and DROP read their type, three axes read `axes` 3, `%SHOWPLAN SELECT` reads SELECT, and a syntax error and an unknown cube each answer #5001 text.
- **Drill.**
  - `%GetFiltersForCellRange` gave `f(0)` (slicer) and `f(2)` (rows), and the composed `DRILLTHROUGH MAXROWS 3 … %FILTER …` ran.
  - A DRILLTHROUGH without MAXROWS answered 1,000 rows.
  - P3 without a SELECT grant got #5540 SQLCODE -99 from `%ExecuteAsynch`.
- **Shared key.** Another process running the same text ended with the same `<EXTERNAL INTERRUPT>` 1.1 s after this process canceled. One cancel stops every run of that text.
- **Classic page.** `NormalizePage("_DeepSee.UI.MDXQuery.zen")` is `%DeepSee.UI.MDXQuery` (compiled), `RESOURCE` `%DeepSee_Admin,%Development`. `GetGlobalDest("USER","^DeepSee.Cache.Results")` is `^/durable/iris/mgr/user/`.

**Measured at the third plan on `ocupilot-b-ci`** (2026-10-15, build 221U). A 300-row scratch cube in USER, with no flag changed; the cube, its classes, the splice nodes and the cache, `ComputedSQL`, `Update` and `CubeEvent` residue it left were removed afterwards.

- **The tokenizer.**
  - `%Tokenize` reads `%SE/**/ARCH`, `%SQL/**/RESTRICT`, `RET/**/URN`, `%ORD/**/ER` and `%PA/**/RM` as the five words, and `%SE--` or `%SE//` followed by a newline and `ARCH` as `%SEARCH`.
  - `[%SEARCH]` is one `QSTR` token, and `[%SE/**/ARCH]` keeps its comment. A `"…"` literal is one `LIT` token with its comments dropped (`LIT<SELECT %SEARCH x>`). `'` is a token by itself, so `'VALUE:{…}'`'s content is in the stream.
  - It fails on an unterminated `[` (the matrix's Syntax text: "Unexpected end of statement") or `"`, and on `3rd` ("Invalid number").
- **Where the splices run.**
  - `%SE/**/ARCH.&[…{$Increment(…)}]`, its `--` spelling and `[%SEARCH].&[…]` each left the node undefined after `%PrepareMDX` and defined it at execute.
  - `WITH %PARM P AS 'VALUE:{…}'` failed prepare with "Query has no SELECT section" in four placements, `{3}` included, and the node stayed undefined. The braced value enters a parser state no branch handles (Code Map › Vendor), so the rest of the text is swallowed. `'VALUE:3'` prepared and ran. A braced `%PARM` is unreachable from statement text on this build.
- **The resolved text.** `%PrepareMDX`'s third argument read the statement itself, `""` in place of `$variable.v` when no variables were handed, and the variable's value when one was. A `%SEARCH` value handed that way prepared with the node undefined.

**Decisions.**

- **One background run, two kinds.** The SQL run's row, lock, sweep, owner 404 and bounds are what this tool needs. A copy of `SqlBackground` would be about 300 near-identical lines.
  - The machinery moves to the kernel because a slice never depends on another slice.
  - The SQL console keeps one live run per user.
  - The instance cap of five, measured against the license for SQL jobs, counts every kind (inference: an MDX job holds a license unit as a SQL job does).
- **The job polls; the vendor computes.** The query runs on the vendor's agents in the person's security context. The job owns the deadline and the cancel, which is why a time bound and a "nothing running" proof are possible.
  - *Rejected:* starting the query in the request and polling the vendor from each poll. That needs the statement stored, and nobody enforces the bound while nobody polls.
- **The request prepares, the job executes.** A drill's original statement executes in the job, under the run loop's bound and cancel, never in the start request, which only classifies.
- **Ask first (Q2 C, and Q1 B for detection).**
  - **One detection.** `AnalyticsPort.MdxConstructs` is the only place that knows the five constructs and the fail-closed rule, so the screen's ask-first and Story 20.35's refusal cannot drift.
  - **The vendor's tokens, the vendor's matching.** The detector compares `%Tokenize`'s values as the vendor's own `%ValidateText` does, and unquotes a bracket as the parser does for `%SEARCH`. A substring match missed every comment-split word (measured), and token equality no longer asks first for `[Return Policy]`.
  - **Two checks.** Before prepare on the statement, after prepare on the variable-resolved text, in the request and again in the job. The first is the one that matters on this build: no production caller hands variables, so the resolved text differs only by `""` (measured). The second is Story 20.35's seam and a guard for a later caller that hands some.
  - **The answer.** A start without the confirmation answers 200 `{outcome: "confirm", constructs, consequence}`, the shape of the SQL console's `confirm` answer (Story 19.6), and reserves and spawns nothing; a finding in the statement itself is answered before any prepare. The page draws the shell's `WarningDialog`, as the SQL page does for a changing statement.
  - **The carrier.** The confirmation is `confirmed: true` in the same start body as the statement, so it confirms exactly the text sent with it. A server token is rejected: it would bind the confirmation to text the server keeps, and the statement is never stored.
  - **Drills.** A drill re-runs the original statement, so it carries the confirmation the person gave that statement's run, with no second dialog.
  - The confirmation guards the person against a statement they did not read, as the SQL console's warning does. It is not a barrier against the person.
- **Limits.**
  - Rows 1,000: the SQL console's Max rows, and the vendor's listing default.
  - Columns 100: a wider grid cannot be read on screen (inference).
  - Cell and total characters: AD-36's screen-only bounds.
  - 120 s: the measured slow crossjoin (122 s) is stopped, and a forgotten run frees its slot of five within two minutes.
  - Settle 10 s: twice the slowest measured settle.
  - String depth 3: a literal inside a literal inside a literal, more than a `%MDX("…")` nesting needs (inference); deeper text asks first.
- **Pairs.** `%DeepSee_Portal:USE` comes from the area, and `%Development:USE` is the screen's own: a named narrower audience than the classic page's either-of, 20.11's Q2 precedent. The cache WRITE pair is the port's, read at call time.
- **The grid.** Value cells are buttons, so drill-through is reachable by keyboard. It is the page's own template because it has row headers and buttons. The listing reuses `ResultGrid`.
- **Not done:** member values (the person queries members with MDX), session sets and members, formatting by measure format (cells are the vendor's raw values), and auto-refresh.

**Named limits.**

- **The shared key.** A cancel or bound stops the vendor's computation of that text for every process running it, including the classic tool's (measured).
- **The cache.** A query, even a canceled one, leaves the vendor's cache in the namespace's database until the cube is next built or killed (AD-7's new shape).
- **Code the query names.** `%KPI` and a cube's own listing or computed-dimension code run as the person, as on the classic page. Those are the cube author's code, not the statement's.
- **False positives, the fail-closed side.** A statement asks first when one of its tokens, or a string literal's, is one of the five words (a member named `[RETURN]`, a caption "Return rate"); when it names `%PARM` at all; and when it does not tokenize (an unterminated bracket, `3rd`, or a literal holding `--` or `//`, which the lexer reads as a comment: inference from source, `Parser.cls`:292-301).
- **Stored definitions (DW-2451, `wontfix-accepted`).** Shared calculated members and named filters expand from stores their authors write, and the detector never reads them. Pivot variables reach a query only when a caller hands them: no production caller does, so each `$variable.<name>` resolves to `""` (measured), in a stored calculated member too (`query.cls`:4704-4711).
- **A braced `%PARM` does not parse on this build** (measured). The set keeps `%PARM` for a build that fixes the parser; the first check sees it before any prepare, so a build that ran the braces at prepare would still ask first.
- **`%Tokenize` is `[Internal]`.** If a later build removes it or it throws, every statement asks first; `AnalyticsMdx`'s obfuscation cases catch a build whose tokens change.
- **The confirmation is a step.** Any client of the start route can send `confirmed: true`.
- **The drill listing.** The vendor scans every matching fact before `TOP`. A cancel during the listing statement waits for `CancelQuery` to reach it.
- **HSLIB** reports analytics but cannot run MDX.

**Size.** One story, large. Two seams, if the lead wants a smaller cut:

- the Rule 31 extractions (`Kernel.Shell.BackgroundRun`, `core/background-run.ts`, `ResultGrid`, `FetchRows`, `SqlRun.Kind`), a refactor whose proof is the SQL console's tests, as a precursor;
- the cell drill-through and the cube picker, which moves the criterion's drill-through clause (Rule 5 ask-first).

A split needs the orchestrator's ruling.

**Rule 31 (extend, don't copy).**

- **Extended:**
  - `SqlBackground` → `Kernel.Shell.BackgroundRun`;
  - `SqlRun` (+`Kind`);
  - `SqlQueryState`'s polling → `core/background-run.ts`;
  - the SQL grid → `ResultGrid`;
  - `SqlPort.Executed`'s loop → `FetchRows`;
  - the shell's `WarningDialog`, used as is;
  - `AnalyticsProbe`, `AnalyticsGate`'s principals and `AnalyticsError`.
- **New siblings, each following one:** `AnalyticsMdxJob` and `AnalyticsMdxRoutes` follow `SqlBackgroundJob` and `SqlBackgroundRoutes`, and `AnalyticsMdxDescriptor` follows `ExplorerDescriptor`'s SQL query test.
- **The copies:**
  - the cells grid's template (row headers and drill buttons) is its own, on the shared CSS classes;
  - `mdxConfirmOf` beside SQL's `confirmOf`: the answers differ (constructs, against a kind and tables), and `sql-query.store.ts` is the SQL screen's.

**Integration, Consumes, Consumed-by (Rules 1 and 2).**

- **Integration:** AC9 and AC10. The MDX page consumes the start, poll and cancel routes, which consume `AnalyticsPort` and the kernel run against the real instance (the AC1-AC3 and AC10 browser legs). The SQL console consumes the same kernel run and client helper.
- **Consumes:**
  - 20.11: `AnalyticsPort`, `AnalyticsError`, `AnalyticsProbe`, `AnalyticsGate`, Cubes and `cube`;
  - 20.32: positions 4-6;
  - 19.15's run, 19.6's fetch loop and `confirm` answer, and the shell's `WarningDialog`;
  - 20.29's loader map.
- **Consumed-by:**
  - 20.35, the agent's MDX read: `MdxConstructs` (its answer, with `unread`) and `MdxPrepare`'s `ask` and `found`, handed no `variables`, for its `ANALYTICS.MDX.SQL` refusal; `MDXCONSTRUCTS`, the `MDX*` caps, and `MdxStart`, `MdxStatus`, `MdxCancel`, `MdxDrill` and `MdxAnswer`, all public on `AnalyticsPort`;
  - 20.34, whose build can outlast a request: it can extend `Kernel.Shell.BackgroundRun` with a third kind (inference);
  - 20.12's Investigate (inference);
  - Epic 21's analytics editors.

**Ledger inbox (Rule 17):** none owned (`owned_ledger=0`).

**Rule 11 (contended files).**

- **Add-only:** `Test/SurfaceCoverage.cls`, `Test/StageTwoTools.cls`, `screens.generated.ts` (regenerated), `strings.ts`, `_components.scss` (if touched) and EXPERIENCE.md.
- **Unchanged:** `Kernel/EntityType.cls` (it uses 20.11's `cube`), `Test/Descriptor.cls`, `Test/ReadTool.cls`, `Screen/Registry.cls`, `Screen/Read.cls`, `Prohibited.cls` and `shell/warning-dialog.ts` and `shell/dialog.ts` (imported only).
- **Epic 23** (`origin/OCU-1-epic23` at `a555c2a8af4c14acd488a461d10a5620f28c33a4`, 23.5 batch d, against the feature head) edits `Screen/Registry.cls`, `Test/ReadTool.cls`, `Test/ExplorerDescriptor.cls`, `screens.generated.ts`, `_components.scss` (+44), `screen-mirror.mjs` and its test, `shell/data-table.ts`, `shell/detail-page.ts` and EXPERIENCE.md (2 lines). This story edits `screen-mirror.test.mjs` (the owners list), `screens.generated.ts` (regenerated), `_components.scss` and EXPERIENCE.md, each add-only, and none of the others.
- **Footprint extensions** (outside `paths_hint`):
  - approved by the orchestrator: `src/OcuPilot/Area/Explorer/SqlBackground.cls`, `scripts/check-objectscript.py`, `scripts/test_check_objectscript.py` and `scripts/ci-throwaway.sh`;
  - reported (Rule 11 (b)): the new `src/OcuPilot/Area/Analytics/MdxQuery.cls`, and EXPERIENCE.md's add-only rows.

**Spine (Rule 20).** The Story 20.33 clauses are written (AD-7 :238, AD-8 :347, AD-21 :610, AD-36 :864, AD-41 :929, AD-42 :943, AD-44 :1048, AD-65 :1402-1404), and AD-65's splice clause carries ruling Q1 B. Corrections for the lead:

- **AD-65's Story 20.33 clause** (:1404) says "`MdxConstructs` is the one detection of the splice clause's four constructs". It should read "five constructs, and a statement it cannot read".
- **The splice clause's named limit** (:1402) lists pivot variables. No production caller hands any, so each resolves to `""` (measured); the limit that remains is shared calculated members and named filters. Optional, for precision; DW-2451's summary lists pivot variables too.

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
  - `analyticsMdxErrorLine` "The instance answered this statement with an error.";
  - `analyticsMdxConfirmTitle` "Run this query?";
  - `analyticsMdxConfirmConsequence` "This query runs server-side code or SQL with your rights." (equal to `MDXCONSEQUENCE`).
- **Refusals (each `REASONMDX*` equal to its value):**
  - INPUT "Send one MDX statement of up to 100,000 characters; a drill-through names one cell of its answer.";
  - KIND "Only SELECT and DRILLTHROUGH statements run here; CREATE and DROP change only a session, which this tool does not keep.";
  - AXES "A query here uses at most two axes: columns and rows.";
  - READONLY "This namespace keeps its analytics cache in a read-only database, so MDX cannot run here.";
  - BUSY "An MDX query you started is still running; cancel it or wait for it to end.";
  - FULL "As many background queries as this instance allows are running, SQL and MDX together; try again when one ends.";
  - NOTFOUND "No MDX run of yours has this id; an ended run is kept for 15 minutes.";
  - LOST "The MDX run ended without an answer; run it again."
- **Prompts:** "How do I put one dimension on rows and another on columns?", "How do I filter an MDX query to one member?", "What does a drill-through show for a cell?"

**Weight.** The owner's `maximumWarning` is a fixed 2500 kB on a measured 1.95 MB initial, never re-based; a crossing is reported. The initial bundle gains the strings and one mirror entry, about 5 kB (inference), for about 1.96 MB. The MDX page is a new lazy chunk of about 20 to 30 kB (inference), under `LAZYCHUNKMAX`'s 88 kB. `background-run.ts`, `result-grid.ts` and `WarningDialog` land in lazy chunks shared with the SQL page.

**Decided in-stage (implement pass, 2026-10-21).**

- **`FetchRows` is inherited, not called.** A call from the switched namespace to another `OcuPilot.*` class does not resolve (measured: `<CLASS DOES NOT EXIST>` from `USER`, also with the routine already loaded), while a same-class call does, and `%Next()` on a `USER` cursor from `HSCUSTOM` answers no rows. So the fetch loop lives in the abstract `OcuPilot.Kernel.RowFetch`, which `SqlPort` and `AnalyticsPort` both extend: `SqlPort.FetchRows` is public as the task names it, and `AnalyticsPort` reads its listing through its own compiled copy. `MAXCELL` and `MAXANSWER` moved to `RowFetch`; `AnalyticsPort` overrides them from `MDXMAXCELL` and `MDXMAXANSWER`.
- **`BackgroundRun` answers through a `Reply` hook.** `scripts/check-objectscript.py` allows `Kernel/Shell/` no API class but `Api.Error`, so each kind writes its JSON through `Api.Response` in its own `Reply`. The other hooks are as the task lists, plus `RUNKIND`; `Begin` (reserve and spawn), `Enter` (the job's one entry, which runs the invoked class's own `Run`) and `Spawn` are the base's. `SqlBackground.Start`, `Run`, `Cancel`, `View` and its seams are unchanged in signature.
- **`MdxQuery.Check`** is public and shared: the start and the job both call it (gate, detector, prepare, detector on the resolved text), and the fixture tests call it directly. `Work` repeats it, so a finding the flag does not confirm ends the run `failed` with `MDXLOST`'s envelope.
- **A typed or composed DRILLTHROUGH reads one row past the cap.** `MdxStart` raises the prepared query's `%MaxListingRows` (an `[Internal]` property) from the cap to the cap plus one, so `FetchRows` learns whether more exist and `truncated` is exact (the Visits cube's exactly 1,000 rows are not flagged). A person's own `MAXROWS` below the cap is kept. The composed text still says `MAXROWS 1000`. Named limit: a build that removes the property fails a DRILLTHROUGH start.
- **A result set is closed in the namespace it was made in.** The vendor's destructor clears the result set's local cache (`^DeepSee.Cache.LocalResults`, `LocalAxis`) in the namespace it runs in, so a job holding one in `HSCUSTOM` left a cache behind in `USER` for every run (measured). `AnalyticsPort.MdxRelease` closes one in its namespace, the port releases the ones it does not hand back, `MdxQuery.Work` releases both of its on every path, and `AnalyticsProbe` clears, and `Gone` checks, what remains (`LocalCaches`), a fourth check beside the three the task names.
- **`AnalyticsProbe.Remove` matches the cache and the computed SQL as the vendor keys them.** `^DeepSee.Cache.Results` is keyed by the cube name as the query spelled it, not upper-cased, and `^DeepSee.ComputedSQL` names a probe class as its fact table (`OcuPilotProbe_Analytics_...`), so both are matched case-insensitively and in either spelling.
- **The custom-resource leg is in `ClassicPageGate`.** `TestAnAssignedPageGatesTheMdxRun` assigns the probe resource to `%DeepSee.UI.MDXQuery` with that class's principals and restore; putting it in `AnalyticsMdxRoutes` would have armed a second variable (`OCUPILOT_ALLOW_NAMESPACE_CONFIG`). The job's repeat of the gate is the kernel run's, pinned for the SQL kind there. `AnalyticsMdxRoutes`' principals come from `InteropTestGate.CreatePrincipals`, not `AnalyticsGate.EnsurePrincipals`, which is unchanged beyond its cube lists.
- **A drill-through's listing reads the source table**, which the probe principals hold no SELECT on (the P3 case), so the route tests run drills as the suite's account and `AnalyticsMdxGate` pins the -99 answer.
- **Existing 20.11 and 20.32 checks that count the probe's cubes took the fourth cube:** `AnalyticsPort` and `AnalyticsGate` (four and six cubes), `analytics.browser-spec.mjs` (four cubes, 50,000 facts), and the side-bar label lists of `analytics.browser-spec.mjs` and `analytics-links.browser-spec.mjs` (seven entries), each add-only.
- **A listing's SQL runs when its rows are fetched, so the bound encloses the fetch (review pass).** `%ExecuteAsynch` of a DRILLTHROUGH returned in 0.2 s with the listing's SQL not yet run (measured); the SQL runs at the first `%Next()` and, under an alarm, ends with SQLCODE -450. `MdxAnswer` takes a trailing `pBound` (0 by default) that arms the alarm around the fetch and answers `{outcome: "stopped"}`, and `MdxQuery.Process` passes the time that remains and ends the run `stopped` with the bound's seconds. The alarm's seconds are the next whole second, never zero: `Alarm.Set(0)` never fires (measured).
- **Client choices** (the client half): the grid's row header reads "Row members" because "Members" is `roleEditorTabMembers` and the strings table holds one key per value; `analyticsMdxCut` is the one added key (the cut-answer sentence); the Fixed strings were appended to the 20.11 and 20.32 row and the side-bar sentence (the tree has no Analytics table row); `BackgroundRun` takes the page's `refusalText` and a `settle` callback that runs before a start is attached, so a first poll cannot resolve before the store knows what the run means; a replaced grid is shown until a new Run is accepted and kept while a drill runs; a namespace change drops a pending confirmation through `ScopeService`; Run and the drill buttons use `aria-disabled`, as the SQL page does.

## Verification

**Shared surfaces:**

- `SqlRun`'s per-user and per-instance counts (the SQL background tests);
- `JOB_ALLOWED`;
- `StageTwoTools` `Elsewhere`, `SurfaceCoverage`'s screens, `EndpointCoverage`'s probes;
- `Navigation.cls`' analytics block;
- `DeveloperFloor` `SCREENS` and `DeveloperFloorRoutes`' lists;
- `PortGate`'s `ROSTER`;
- `navigation.test.mjs`' routes and `screen-mirror.test.mjs`' owners;
- the strings table, EXPERIENCE.md's side-bar table :157-170, its Dialogs list :173 and its Fixed strings;
- the built-screen count Screen permissions derives (+1);
- USER's analytics flags, `^DeepSee.Cache.Results`, `^DeepSee.ComputedSQL` and `^OcuPilotProbeMdxSplice` while the probe runs (nodes 1, 3, 4 and 5 server-side, 2 browser, 10 port; Story 20.35 takes 351 on);
- the SQL page's DOM.

*Every test added or changed passes on a fresh environment, in either order.* `AnalyticsProbe` creates and removes everything it asserts on, its cache residue and the splice node included. Each ask-first leg uses its own node subscript, so its statement text is its own, and each job test settles its own runs.

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
- `(loop)` `cd ui && npm run build -- --verbose`. Expected: the prebuild chain green, the initial total under 2500kB (about 1.96 MB) and the MDX page in its own lazy chunk under 88 kB (about 20 to 30 kB). Record both.
- `(loop)` `uv run scripts/check-objectscript.py <each changed .cls>`, `uv run scripts/test_check_objectscript.py` and `bash scripts/lint-docs.sh`. Expected: clean.
- `(loop)` `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/<file>`, one file per call, after the redeploy. Expected: green.
  - `analytics-mdx.browser-spec.mjs`
  - `system-explorer-sql-query.browser-spec.mjs`
  - `a11y-structural-invariants.browser-spec.mjs` (about 430 s)
  - each side-bar spec the sweep changes
- **Lead-owned (the runner's), not run by the implement stage:** the full ObjectScript sweep, `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`, and Rule 30's fresh check.
- **Left to CI:** the full browser suite.

**Planned pinning mutations (Rule 19).** Revert each byte-identical. Reload, or rebuild and redeploy, the whole tree before the next.

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | `MdxAnswer` reads labels innermost first | `AnalyticsMdx`'s cells test and the browser AC1 grid |
| AC2 | The drill composes without the slicer `f(0)` | `AnalyticsMdx`'s drill test (rows differ) and the browser AC2 |
| AC3 | `Work` ends `canceled` without `MdxCancel` | `AnalyticsMdxJob`'s cancel test (a `%DeepSee` process remains) |
| AC4 | `Work` ignores the deadline | `AnalyticsMdxJob`'s bound test |
| AC4 | `MDXMAXROWS` is not applied | `AnalyticsMdx`'s row cap test |
| AC5 | Kind accepts CREATE | `AnalyticsMdx`'s kind test and the browser AC5 |
| AC6 | `IdForOwner` ignores the owner | `AnalyticsMdxRoutes`' other-user test |
| AC6 | `GuardedReserve`'s busy check ignores the kind | `AnalyticsMdxRoutes`' kinds-apart test and `SqlRunStore`'s per-kind test |
| AC7 | `MdxAdmit` skips the cache WRITE | `AnalyticsMdxGate` P1 (an unnamed `<PROTECT>`, not 403 naming `%DB_USER:WRITE`) |
| AC7 | `MDXPAIRS` loses `%Development:USE` | `AnalyticsMdxGate` P4, and `PortGate`'s leg |
| AC8 | The `Elsewhere` row is removed | `StageTwoTools.TestTheRosterAndElsewhereAreEveryRegisteredScreen`, alone |
| AC8 | A pale color on a drill cell | The browser structural leg |
| AC9 | `BackgroundRun` drops the 404 clear | `background-run.test.mjs` and `sql-query.page.spec.ts`' swept-run case |
| AC10 | `Admit` skips the confirmation check | `AnalyticsMdxRoutes`' ask-first test (202, and the node defined before any confirmation) and the browser AC10 (no dialog) |
| AC10 | `MdxConstructs` is cycle 2's detector, the four words as a case-insensitive substring of the raw text | `AnalyticsMdx`'s obfuscation cases (each `/**/` word, `--`, `//`, both literals, the braced `%PARM`) and `AnalyticsMdxRoutes`' node-3 and node-4 cases |
| AC10 | `MdxConstructs` reads no string literal's tokens | `AnalyticsMdx`'s `%MDX("…")` case |
| AC10 | `MdxConstructs` answers 0 when a tokenize fails | `AnalyticsMdx`'s fail-closed cases and `AnalyticsMdxRoutes`' tokenizer-failure case (an error answer, not `confirm`) |
| AC10 | `MdxPrepare` skips the check on the resolved text | `AnalyticsMdx`'s variable case and `AnalyticsMdxJob`'s resolved-text case |
| AC10 | `MDXCONSTRUCTS` loses `%PARM` | `AnalyticsMdx`'s `%PARM` cases and `AnalyticsMdxRoutes`' node-4 case |
| AC10 | `mdxConfirmOf` answers `null` for empty `constructs` | `mdx-answer.test.mjs` and the page spec's empty-constructs case |
| AC10 | The store sends `confirmed: true` on the first start | `mdx-query.page.spec.ts`' ask-first case |

**Measured and observed (implement pass, 2026-10-21; slot B, `ocupilot-b-ci`, IRIS for Health 2026.2 build 221U).**

- **Task 0.**
  - The 20.11 and 20.32 symbols re-anchored; positions 1 to 6 are taken, so MDX query is position 7. The contention check against `origin/OCU-1-epic23` named none of this story's files.
  - The slow query is `SELECT {[Measures].[Amount]} ON 0, NON EMPTY CROSSJOIN([Sub].[H1].[Sub].Members,[Sub2].[H1].[Sub2].Members) ON 1 FROM [OcuPilotProbeGrid]`: 130 s in all, 14,000 rows, a cancel at 3 s answers status 100 with `<EXTERNAL INTERRUPT>`, and the vendor's worker exits within one second of a cancel. The fixture builds 50,000 rows and the cube in about 2 s.
  - A crossjoin tuple's labels list innermost first, so the answer reverses them: `1 / 0`. A listing's column names are the statement's metadata (`Sub`, `Sub2`, `Amount`); `%GetListingResultSet`'s field list is empty. `$SYSTEM.SQL.CancelQuery` sent to a job that runs no SQL returns at once with #6164. A `JOB`'d process ran `%PrepareMDX`, `%ExecuteAsynch` and the poll in 0.11 s with the namespace restored after each call.
  - `%SEARCH.&[ID > {$Increment(^OcuPilotProbeMdxSplice(n))}]` leaves the node undefined after `%PrepareMDX` and defines it at execute, as a `WHERE` slicer or a set, also when spelled `%SE/**/ARCH` (the field `Amount` is not a fact column, `ID` is); the `%PARM` text fails prepare with the node undefined; a `$variable.v` handed that text prepares with the node undefined and runs it at execute. `strings.test.mjs` holds the values unique.
- **Bundle.** `npm run build -- --verbose`: initial total 2.00 MB (1,995.5 kB raw, 355.02 kB transfer), under the fixed 2,500 kB warning; the MDX page is its own lazy chunk of 16.08 kB raw (4.77 kB transfer), under `LAZYCHUNKMAX`'s 88 kB; the SQL page's chunk is 10.28 kB.
- **Run.** 20 ObjectScript classes, 146 tests, all green: `AnalyticsMdx` 11, `AnalyticsMdxDescriptor` 2, `AnalyticsMdxGate` 2, `AnalyticsMdxJob` 9, `AnalyticsMdxRoutes` 7, `AnalyticsPort` 11, `AnalyticsGate` 8, `AnalyticsLinkMap` 4, `SqlRunStore` 13, `SqlBackgroundJob` 12, `SqlBackgroundRoutes` 9, `ClassicPageGate` 9, `Retention` 10, `StageTwoTools` 4, `SurfaceCoverage` 4, `EndpointCoverage` 2, `Navigation` 14, `DeveloperFloor` 10, `DeveloperFloorRoutes` 1, `PortGate` 4; and `InteropFloor`, `InteropFloorRoutes` and `InteropFloorOwnPairs` unchanged and green. `npm run test:tools` 2,110 tests and `npm run test:components` 3,337 tests green; `uv run scripts/test_check_objectscript.py` 146 green; `bash scripts/lint-docs.sh` and `uv run scripts/check-objectscript.py` clean. Browser: `analytics-mdx` 5, `system-explorer-sql-query` 3, `analytics` 5, `analytics-links` 6 and `a11y-structural-invariants` 13 green.
- **Mutations observed (Rule 19), each applied, observed red, reverted byte-identical, the tree reloaded before the next.**
  - mutation: AC1, `MdxAnswer` joins labels innermost first -> `AnalyticsMdx.TestTheCellsAnswerEqualsTheVendorsLabelsAndValues` red.
  - mutation: AC2, the drill composes without the slicer's `f(0)` -> `AnalyticsMdx.TestACellsDrillThroughIsTheVendorsListingForThatCell` red (its sliced case).
  - mutation: AC2/AC4, `MdxStart` reads no row past the cap -> `TestATypedDrillThroughReadsToTheCapAndSaysWhenMoreExist` red.
  - mutation: AC3, `Stop` does not call `MdxCancel` -> `AnalyticsMdxJob` cancel and bound tests red, and the browser AC3 leg red.
  - mutation: AC4, `Execute` ignores its deadline -> `AnalyticsMdxJob.TestAQueryPastTheBoundIsStoppedAndLeavesNothingRunning` red.
  - mutation: AC4, `MDXMAXROWS` is not applied -> `AnalyticsMdx.TestTheRowColumnCellAndTotalCapsCutAndSaySo` red.
  - mutation: AC5, the kind check accepts CREATE -> `AnalyticsMdx.TestCreateDropAndThreeAxes...` red, and the browser AC5 leg red.
  - mutation: AC6, `IdForOwner` ignores the owner -> `SqlRunStore` (three tests) and `AnalyticsMdxRoutes.TestAnotherUsersRunAnswersTheSameNotFound...` red.
  - mutation: AC6, `GuardedReserve`'s busy check ignores the kind -> `SqlRunStore.TestAnOwnerHasOneLiveRunOfEachKind` and `AnalyticsMdxRoutes.TestAnOwnersSecondStart...` red.
  - mutation: AC6, `IdForOwner` ignores the kind -> `SqlRunStore.TestLookupsMatchTheKind...` and `AnalyticsMdxRoutes.TestAnOwnersSecondStart...` red.
  - mutation: AC6, the cap counts only the requested kind -> `SqlRunStore.TestTheInstanceCapCountsEveryKind` and `AnalyticsMdxRoutes.TestTheInstanceCapCountsBothKinds` red.
  - mutation: AC6, `Run` drops the cancel-before-begin branch -> `AnalyticsMdxJob.TestACancelBeforeTheJobBeginsEndsTheRunCanceled` red (its statement is one no other test runs, so the vendor holding it is the signal).
  - mutation: AC7, `MdxAdmit` skips the cache WRITE -> `AnalyticsMdxGate` red.
  - mutation: AC7, `MDXPAIRS` loses `%Development:USE` -> `PortGate.TestEveryPortEvaluatesItsDeclaredGate` red.
  - mutation: AC8, the `Elsewhere` row is removed -> `StageTwoTools.TestTheRosterAndElsewhereAreEveryRegisteredScreen` red, alone.
  - mutation: AC8, a pale token on the drill cell (a hex is refused by the build's lint) -> the browser AC1 structural leg red: `1.25:1 under 4.5:1` light and `1.43:1 under 4.5:1` dark.
  - mutation: AC9, the failure log carries the statement -> `AnalyticsMdxJob.TestTheJobsFailureLineCarriesNoStatement` red.
  - mutation: AC10, `Check` never answers `confirm` (both detections) -> `AnalyticsMdxRoutes` ask-first and unreadable-text tests red, and the browser AC10 leg red. With only the first detection skipped, the second (the resolved text) still asks, and the browser leg stays green; `AnalyticsMdxRoutes` still reddens on the unreadable text.
  - mutation: AC10, `confirmed` of any value accepted -> `AnalyticsMdxRoutes.TestEveryRefusalIsAnswered...` red.
  - mutation: AC10, `MdxConstructs` is the four-word substring test of the raw text -> `AnalyticsMdx` (four tests) and `AnalyticsMdxRoutes` (two tests) red.
  - mutation: AC10, no string literal's tokens are read -> `AnalyticsMdx` literal and fail-closed cases red.
  - mutation: AC10, a failed tokenize answers 0 -> `AnalyticsMdx.TestTheDetectorFailsClosed` and `AnalyticsMdxRoutes` tokenizer case red.
  - mutation: AC10, `MdxPrepare` skips the resolved text -> `AnalyticsMdx.TestPrepareChecksTheResolvedText...` and `AnalyticsMdxJob` resolved-text case red.
  - mutation: AC10, `MDXCONSTRUCTS` loses `%PARM` -> `AnalyticsMdx` and `AnalyticsMdxRoutes` `%PARM` cases red.
  - mutation: the job drops its result-set release -> `AnalyticsMdxJob.TestAFinishedRunLeavesNoLocalCache` red.
  - mutation: AC9 (client), `BackgroundRun` drops the 404 clear -> `background-run.test.mjs` and the swept-run cases of `sql-query.page.spec.ts` and `mdx-query.page.spec.ts` red.
  - mutation: AC10 (client), `mdxConfirmOf` answers `null` for empty `constructs` -> `mdx-answer.test.mjs` and the page spec's empty-constructs case red.
  - mutation: AC10 (client), the store sends `confirmed: true` on the first start -> five page-spec cases red, the ask-first case among them.
  - mutation: AC10 (client), one word changed in a refusal sentence -> `analytics.test.mjs` and three `strings.test.mjs` assertions red.
  - mutation (review pass): AC4, the listing read gets no alarm (`MdxAnswer`'s bound branch skipped) -> `AnalyticsMdxJob.TestAListingPastTheBoundIsStoppedAndLeavesNothingRunning` and `TestABoundUnderASecondStillStopsAListing` red.
  - mutation (review pass): AC4, the alarm seconds round down (`AlarmSeconds` answers `pRemaining \ 1`) -> `AnalyticsMdxJob.TestABoundUnderASecondStillStopsAListing` red alone.
  - mutation (review pass): AC3, `CancelJob` sends no `$SYSTEM.SQL.CancelQuery` -> `AnalyticsMdxJob.TestTheOwnersCancelEndsAListingRunCanceled` red (the listing runs on; the leftover job also reddened the next cancel test, and nothing was left running after the revert).
  - mutation (review pass): AC6, `GuardedReserve`'s ended-row delete ignores the kind -> `SqlRunStore.TestAnOwnerHasOneLiveRunOfEachKind` red.
  - mutation (review pass): AC6, `Reconcile` answers the row's raw kind -> `SqlRunStore.TestLookupsMatchTheKindAndARowWithNoKindReadsAsSql` red.

- (QA) pass, files (a fixture is marked `fixture`):
  - (QA) `src/OcuPilot/Test/AnalyticsPortHang.cls` (fixture) and `src/OcuPilot/Test/AnalyticsMdxHang.cls` (fixture): the port and the MDX kind whose DRILLTHROUGH waits end only by the run's alarm.
  - (QA) `src/OcuPilot/Test/AnalyticsMdx.cls` (`TestTheAnswersCarryTheContractsFieldsInOrder`, `TestAnMdxRunWritesNothingOfItsOwn`), `src/OcuPilot/Test/AnalyticsMdxJob.cls` (`TestAnAlarmThatInterruptsTheStartStopsTheRun`, `TestAnAlarmThatInterruptsTheListingsReadStopsTheRun`) and `src/OcuPilot/Test/AnalyticsMdxRoutes.cls` (`TestADrillOfACellPastTheAnswerEndsTheRunFailedAndRefused`, `TestTheStatementIsKeptNowhereTheRunStores`).
  - (QA) `src/OcuPilot/Test/AnalyticsPort.cls`: `Snapshot` takes an optional `pRuntime` (default 1, as before); 0 leaves out the vendor's cache and session nodes.
  - (QA) `ui/browser/analytics-mdx.browser-spec.mjs`: six legs (a keyboard drill with the grid and listing in the structural walk, a typed DRILLTHROUGH, the vendor's error text in the walk, an unreadable statement asking first, the cube picker, and the HSCUSTOM and HSLIB refusals).
  - (QA) `ui/tools/analytics.test.mjs`: the Never list held to the product source, and its scanner.
- (QA) mutations, each applied, observed red, reverted byte-identical (`git status` and `git diff` digest equal before and after), the tree reloaded or rebuilt and redeployed before the next:
  - mutation: AC1, `MdxAnswer` leaves the cube out of the cells answer -> `AnalyticsMdx.TestTheAnswersCarryTheContractsFieldsInOrder` red, alone.
  - mutation: AC5, `MdxStart` increments a favorite of the signed-in user (an idempotent write stayed green, because earlier tests had made it) -> `AnalyticsMdx.TestAnMdxRunWritesNothingOfItsOwn` red, alone.
  - mutation: AC4, `MdxQuery.Execute` matches `<ALARMX>` in the start's status text -> `AnalyticsMdxJob.TestAnAlarmThatInterruptsTheStartStopsTheRun` red, alone.
  - mutation: AC4, `MdxAnswer` matches `ex.Name = "<ALARMX>"` -> `AnalyticsMdxJob.TestAnAlarmThatInterruptsTheListingsReadStopsTheRun` red, alone.
  - mutation: AC2/AC7, the drill branch of `MdxQuery.Process` ends the run `ended` with no answer instead of refusing -> `AnalyticsMdxRoutes.TestADrillOfACellPastTheAnswerEndsTheRunFailedAndRefused` red, alone, in all three legs.
  - mutation: AD-7/AD-36, `MdxQuery.Process` adds the statement to the answer it stores -> `AnalyticsMdxRoutes.TestTheStatementIsKeptNowhereTheRunStores` red, alone, in the poll and the store legs.
  - mutation: AC10, `AnalyticsPort.ScanTokens` answers unread 0 when a tokenize fails -> the browser `AC10 (QA)` leg red (no warning opens).
  - mutation: AC8, `AnalyticsPort.ErrorAnswer` carries no message -> the browser `AC8 (QA)` vendor-error leg red.
  - mutation: AC7, `AnalyticsPort.MdxAdmit` skips the read-only refusal -> the browser `AC7 (QA)` leg red (HSLIB shows the generic access sentence).
  - mutation: AC2, `AnalyticsPort.MdxAnswer` reads one listing row -> the browser `AC2 (QA)` typed DRILLTHROUGH leg red.
  - mutation: AC2/AC8, the drill cell is a `div` with the click handler -> the browser keyboard leg red alone (the mouse `AC2` leg stays green); rebuilt and redeployed.
  - mutation: AC1, `onCube` writes no pick -> the browser `AC1 (QA)` picker leg red; rebuilt and redeployed.
  - mutation: Never list, `Set tX = $System.Process.Terminate(1)` in `AnalyticsPort.cls` -> `analytics.test.mjs`'s Never-list test red (no instance needed).
- (code review) mutations, each observed red by its own named assertion and reverted (the hash of `git diff` and the untracked fixtures equal before and after), the tree reloaded with the mutated class recompiled with its subclasses, or the spec re-run; two pairs and one triple were applied together, each reddening a different assertion:
  - mutation: AC4, `Execute` arms no alarm for a SELECT's start -> `AnalyticsMdxJob.TestTheBoundHoldsWhileTheVendorStartsAQuery` red.
  - mutation: AC3, `Execute` and `Process` drop their cancel reads before a start and before a listing's read -> `AnalyticsMdxJob.TestACancelThatReachesNoStatementIsReadBeforeTheListing` red.
  - mutation: AC2, `Admit` accepts a drill of a DRILLTHROUGH -> `AnalyticsMdxRoutes.TestEveryRefusalIsAnsweredByItsCodeAndNothingIsSpawned` red (202, and a run reserved).
  - mutation: AC1, `Execute` reads a start's error as done -> `AnalyticsMdxRoutes.TestTheStartAnswersARunIdAtOnceAndAPollReadsItsAnswer` red (the unknown measure polls to a blank grid).
  - mutation: AC2, `MdxDrill` drops its SELECT check -> `AnalyticsMdx.TestAnEmptyAxisHasNoPositionsAndADrillNamesACellTheAnswerHas` red (its DRILLTHROUGH leg).
  - mutation: AC1, AC2, `Positions` counts with `%GetRowCount` and `%GetColumnCount` -> the same test red (its empty-answer and drill legs).
  - mutation: AC4, the total cap sets no `truncated` -> `AnalyticsMdx.TestTheRowColumnCellAndTotalCapsCutAndSaySo` red (its total leg).
  - mutation: AC10 (client), `drill` and `drillable` ignore the namespace -> `mdx-query.page.spec.ts`' namespace-drill case red.
  - mutation: AC1 (client), `drillLabel` drops the value -> `mdx-query.page.spec.ts`' grid case red.
  - mutation: Never list, `CACHE_REFERENCE` drops the bracket form -> `analytics.test.mjs`' scanner test red.
- (smoke rework) mutations on `OcuPilot.Test.SaveHoldCoverage.TestEveryWriteRouteTakesTheHoldOrIsExempt`, each reverted byte-identical (`git diff` digest equal before and after) and the throwaway reloaded:
  - mutation: the `POST /analytics/mdx/background` row dropped from `Exemptions` -> red, naming `POST /analytics/mdx/background` (`BackgroundRun.HandleStart`).
  - mutation: the cancel route's `Url` in `Router.UrlMap` renamed `.../:id/cancelx` -> red, on "the exemption 'POST /analytics/mdx/background/:id/cancel' names a route in the map". Dropping only the cancel row stays green: the start row's slash boundary already exempts the cancel route, so the cancel row is a mirror of the SQL console's pair that the stale-row check holds to a real route.

## Auto Run Result

Status: done
Blocking condition: none

**This pass (rework iteration 1, the one `[Smoke]` item).** `SaveHoldCoverage.Exemptions` gains one row for each MDX write route, `POST /analytics/mdx/background` and `POST /analytics/mdx/background/:id/cancel`, beside the SQL console's pair. Files changed: `src/OcuPilot/Test/SaveHoldCoverage.cls` and this spec (the item ticked, the `mutation:` lines, the triage entry). The earlier passes closed in the first 2026-10-21 entry of the Review Triage Log, committed at `d280ee5f`.

**Review.** Two layers ran: 9 findings, high 0, medium 0, low 5, false 4. Patched: two low entries (the cancel row's own mutation, and the mutation line's placement). Deferred: none new. Rejected: one low and four false, each with its reason in the Review Triage Log. Follow-up review recommended: false (no high patched).

**Verified.** The reloaded `src` loaded with `IsOK` 1. `node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.SaveHoldCoverage` reds on the two routes before the rows (run 721) and is green after (runs 722 and 726, 2 tests). The start-row mutation reddens it (run 723) and so does the cancel route's rename (run 728); each was reverted byte-identical (`git diff` digest equal) and the class is green again on the reloaded tree (run 729). `check-objectscript` (2,159 files, 0 problems) and `lint-docs` are clean. No matrix row is touched, so the Matrix Test Audit was not re-run. Not run here, left to the lead: the full ObjectScript sweep, `scripts/smoke.sh` and Rule 30's fresh check.
