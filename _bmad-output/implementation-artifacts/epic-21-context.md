# Epic 21 Context: Stage 5 - custom-REST parity from the MCP suite's handlers

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Make every remaining classic-portal leaf in the instance-administration and data areas reachable through OcuPilot's own API, where the leaf has a backing class but no admin or Atelier route: backup, the mirror monitor, the startup and memory tables, NLS and SQL settings, globals and the data tools, the SQL tuning track, and the last leaves in the six original areas. Handler bodies harvested from the MCP suite go through one seam. Interoperability, analytics, developer tools and the agent's harvested tools moved to Epic 24. What remains open is the rest of the SQL tuning track, split from Story 21.6: runtime statistics, the index analyzer with its advice, alternate show plans and the troubleshooting reports. Together they give a developer diagnosing a slow query one place to do the whole job.

## Stories

- Story 21.1: The harvest seam
- Story 21.2: Backup
- Story 21.3: Startup, memory and compatibility settings
- Story 21.4: NLS locales and SQL settings
- Story 21.5: Globals and the data tools
- Story 21.6: The SQL tuning track
- Story 21.10: The remaining leaves across the six areas
- Story 21.12: Mirroring
- Story 21.13: DDL mappings
- Story 21.14: NLS configured defaults and locale definitions
- Story 21.15: Locale and table import
- Story 21.16: Custom locales
- Story 21.17: Global export and import
- Story 21.18: Global find and replace
- Story 21.19: Shell, advisor, permission and task leaves
- Story 21.20: OS management and log leaves
- Story 21.21: Leaves that wait on the owner
- Story 21.22: CI flake hardening
- Story 21.23: Test hygiene and contended client fixes
- Story 21.24: The Task Manager mail password is masked in OcuPilot's audit read
- Story 21.25: Index rebuild and tune table
- Story 21.26: Runtime statistics
- Story 21.27: The index analyzer and its advice
- Story 21.28: Alternate show plans
- Story 21.29: Troubleshooting reports
- Story 21.30: OcuPilot's guarded storage refuses a caller that is not an administrator
- Story 21.31: Fixed table statistics
- Story 21.32: A SQL settings change leaves the instance's class-query lists working
- Story 21.33: OcuPilot's other guarded stores refuse a caller who may not write them
- Story 21.34: A backup action leaves the web process's null device open
- Story 21.35: OcuPilot's install records and other users' state answer only to their callers
- Story 21.36: Task output and mail password
- Story 21.37: Page resources
- Story 21.38: Shared Rules helpers, the source-control follow-up and escalated wording
- Story 21.39: CI health: the governance renderer stall and the journal reverse-read timeout
- Story 21.40: The governance page's render cost

All stories are done except 21.26 to 21.29, which are in the backlog.

## Requirements & Constraints

- **Acceptance for each remaining story:** each leaf round-trips over its backing class. Stories 21.26, 21.27 and 21.28 each add their own read to the `slowquery` guided workflow, and the workflow stays read-only, with no write step. Story 21.29 adds no workflow read.
- **One contract for every screen:** one descriptor and one port per screen. The read tool and the write tools' field lists derive from the descriptor. Every write is a server-minted proposal with an instance-computed diff, an explicit confirmation and an agent audit marker, reached by two callers (the screen action and the agent).
- **Governance:** every new write key joins the baseline in the same story. An absent key defaults to disabled, and every new destructive key ships disabled. Keys so far are `true` only where the change is cheap and reversible (freeze, purge, collect statistics). They are `false` where it overrides the optimizer or cannot be undone (clear statistics, clean, fixed values, rebuild). No SQL-track write has been destructive yet, so none needs a typed name.
- **Leaf inventory, probed read-only on `ocupilot` on 2026-11-15.** Every page needs `%Development` (`USE`), and none had a custom resource. Re-confirm each against the instance before building.
  - **21.26, runtime statistics:** pages `%CSP.UI.Portal.SQL.QButtons.RuntimeStats` and `RuntimeStatsSettings`. Backed by `$SYSTEM.SQL.SetSQLStats(level, 1, "", terminate)`, which is a system-wide collection level and timeout, and by `%SYS.PTools.StatsSQL` `ViewStatsSQL`, `ViewStatsSQLDetails` and `clearStatsSQL` (a namespace purge). "Plan with stats" runs the query. Expected scope: 2 reads and 2 writes. Its plan settles whether the system-wide level needs an AD-51 named entry or a settings shape.
  - **21.27, index analyzer and advice:** page `QButtons.IndexAnalyzer`. The reports are `getAllSQLStmts`, `indexUsage`, `tableScans`, `tempIndices`, `joinIndices` and `outlierIndices` in `^%SYS.PTools2`, which the classic page runs as a `job`. Results go to `^%sqlcq($NAMESPACE,"PTools","util")` and are read through `%SYS.PTools.UtilSQLAnalysis`. Each report writes result rows for its namespace. Inputs are a schema and three flags. The advice is harvested from the MCP suite's `SqlAdvisor` (`AdviseData`, behind `iris_sql_analyze`'s `advise`). Its SQL is concatenated and must be rewritten with bound values (AD-21).
  - **21.28, alternate show plans:** page `QButtons.ShowPlanAlt`, backed by `JobPossiblePlans`, `JobComparePlans` (which calls `ShowPlanAlt^%apiSQL`) and `StatsSQL:possiblePlansStats`. A comparison runs the person's statement once per chosen plan. Its plan decides whether that run is a read (AD-7) or a confirmed run.
  - **21.29, troubleshooting reports:** generate uses page `QButtons.ReportGenerator`, backed by `%SQL.Manager.QButtons.Base` `InsertQuery` and `WriteAllToFile`. It runs the query, stores a row in `^IRIS.QButtons.BaseD` and writes XML at a server path the caller gives. The classic page also offers a client `mailto:` to vendor support; the server sends nothing. Import uses `QButtons.ReportLoader`, backed by `Base.ConsumeReport(file, "ckd", 1, ns)`, which loads and compiles the class and INT code the XML carries. The story is gated on the owner on two points: the import compiles code from a file, and the page mails the vendor. The catalog ranks both leaves P3.
  - Measured on 2026-11-15: `GetSQLStatsFlag()` read off. `%SYS_PTools.StatsSQL`, the analyzer's two result tables and `QButtons.Base` held 0 rows. Two leaves have no owner: export and import of frozen plans, and query history.
- **Tests:** every test makes its own probe through `SqlTuningProbe` and restores what it changed through the same port call. It purges its probe tables' cached queries before dropping them. No test asserts that a store is empty. Never create a schema whose name contains `"` (DW-2851: the vendor's drop of a quoted schema's last table breaks `INFORMATION_SCHEMA.SCHEMATA`). Whole-namespace or system-wide writes go in an armed class (`OCUPILOT_ALLOW_*`, add-only `# classes:` line in `scripts/ci-throwaway.sh`). No test or write runs on `ocupilot` or a slot instance.

## Technical Decisions

- **The port is `SqlPort` (`Port/SqlPort.cls`).** Extend it, never copy it.
  - `TuningInvoke` serves the `Statements`, `CachedQueries` and `Tables` endpoints. `COMPOSEDTYPES` lists each port-composed read and write type.
  - Vendor calls go through the existing seam (`StatementCall`, then `TableCall`, overridden by `SqlTuningGateSeam`). Widen the seam; do not add a second one.
  - `SqlPort.ValueProblem` is the single shape check. Tools' `ArgumentProblem` and `ScreenActionDelta` call it, so the mint, the screen and the port refuse with one sentence.
  - Catalog reads are one more `AtelierPort` `CATALOGTABS` statement with bound `?` values. `Screen/Read` already dispatches any `atelier` endpoint.
- **Tool bases:** `SqlStatementAction`, then `SqlTableAction`, then `SqlTableTuneAction`, then `SqlTableSetAction`. They provide the precondition field, the state row, `RefusalCode`, `CONSEQUENCECODE`, composite-target ids and optional-value merge. Purges use `SqlCachedQueryPurge`.
- **Entity types:** a tool's target type is its descriptor's primary type (`Operation.TargetRefOf`). A new SQL screen therefore takes its own type and never `class`, or the class arm would judge `Schema.Table` as a class name. Existing types are `statement-index-entry`, `cached-query`, `sql-table`, `sql-index`, `sql-field` and `sql-schema`. A type change lists its consumers on the server and the client. Stored `class:` citations keep resolving.
- **Gate (AD-29, AD-61):**
  - Writes need `%Development:USE` plus `AtelierPort.WritePairs(ns)`. The vendor's own check is only a lower bound.
  - A missing WRITE pair can make the vendor silently do nothing (freeze) or throw `<PROTECT>` (tune). The read-back (AD-58) exposes the first, and `Applied` catches the second.
- **Runs in the request (AD-7):** writes run synchronously in the confirm or action request, never in a detached job. This is AD-7's named case for Story 21.25, against the Web Gateway's 60 s response timeout (named limit). The analyzer's and plan comparison's `job` calls need the same treatment, or an AD-7 case, decided after measuring.
- **Prohibited set (AD-10):**
  - `PROHIBITED.OCUPILOTSQL` refuses OcuPilot's own statements. `PROHIBITED.OCUPILOTTABLE` refuses OcuPilot's tables and schemas, matching an `OcuPilot` schema, or a class name beginning `OcuPilot` in any case.
  - Both are read at the write, and a failed read refuses. Any new arm, such as an imported report carrying an OcuPilot document (`OCUPILOTCODE`), goes in the kernel.
- **No caller path and no concatenation (AD-21):**
  - Story 21.19's AD-51 case is the precedent for a file argument: a declared root and path resolved through `PathPort`, or a temporary file OcuPilot names and deletes.
  - Vendor inputs can be evaluated as ObjectScript. A fixed outlier value was measured executing, so the port builds the literal itself. Measure every new vendor input for this.
- **Spine records:**
  - A vendor call that carries caller-chosen values needs an AD-51 named entry. Every existing SQL-track case (21.6, 21.25, 21.31) names its composed read type and the exact vendor calls.
  - The runner writes the entry add-only at the spec gate (Rule 20) when the owner or orchestrator allows it.
- **Errors:**
  - New codes go in `Api/AtelierError.cls`, never `Api/Error.cls`.
  - A hostile id answers 400 `PORT.VALIDATION`, and an absent target answers 404.
  - A vendor refusal answers 409 with the vendor's message in `detail` only, never logged (AD-39).
- **Task 0 discipline:** before writing code, measure on `ocupilot-ci` and record the result in the spec:
  - duration against the 60 s bound;
  - whether the call writes to the current device (none has so far);
  - the minimal pairs needed;
  - concurrency behavior;
  - whether the vendor actually does what the classic page's wording claims. Earlier stories found several such claims false.
- **Copy-out (AD-59)**, read-back (AD-58), the change event (AD-14) and namespace save and restore (AD-16) apply to every write.

## UX & Interaction Patterns

- The new screens join System Explorer's SQL slice. A list takes the next free side-bar position at implement time (the SQL statements list is 20). Tabs join a table's tab set.
- A row action is drawn by the shell's handler. A whole-target page action (target `*`) is registered by the page. Known limit: page actions register under row-action ids, so they are drawn only after a row is selected.
- The proposal card shows the target, before and after rows from a fresh read, and the consequence sentence.
- New strings are escalated as one batch at the spec gate and then added to EXPERIENCE.md's Fixed strings: titles, columns, empty states, actions, consequences, refusals, suggested prompts and command aliases. Reuse a published sentence where one fits.

## Cross-Story Dependencies

- 21.26, 21.27 and 21.28 build on 21.6's `SqlPort` endpoints, statement index and `slowquery` entry (`Kernel/Agent/Workflow` `XData Catalog`). Adding a workflow read changes the `WorkflowCatalog`, `screen-mirror.test.mjs` and `suggested-prompts.test.mjs` pins. 21.27's advice may recommend a 21.25 rebuild (inference). The recommended order is 21.26 to 21.29.
- Open deferrals that touch this track:
  - 21.6's all-namespace purge default is not pinned by any test.
  - 21.25's delimited-identifier branch of `SqlPort.QuotedName` is untested against the vendor.
- Epic 24 runs on slot B and edits shared rosters: `Baseline`, `Prohibited`, `EntityType`, `ReadTool`, `ToolEmit`, `ToolRoundTrip`, `screen-action-handler.ts`, `strings.ts`, `EXPERIENCE.md` and `ci-throwaway.sh`. Before editing, check them with `git log origin/OCU-1-epic24 ^origin/feature/OCU-1_ocupilot-mvp`. Keep edits there add-only, and expect count literals to merge as a union.
