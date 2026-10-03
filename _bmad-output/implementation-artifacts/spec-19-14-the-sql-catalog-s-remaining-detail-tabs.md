---
title: "Story 19.14: The SQL catalog's remaining detail tabs"
type: 'feature'
created: '2026-10-03'
status: 'ready-for-dev'
review_loop_iteration: 0
baseline_revision: 'a56f52d52919ba783ae1c8a47be6e2964fd2c9aa'
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-19-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-19-5-the-sql-catalog-browser.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** A table in System Explorer opens to five catalog tabs, and a view or a stored procedure opens to nothing, so a developer still uses the classic SQL page for a table's partitions, cached queries and SQL statements, and for a view's or procedure's details.

**Approach:** On Story 19.5's `Catalog.*` family in `AtelierPort`, add nine endpoints, each one fixed statement with every caller value bound. Add nine descriptors on 19.5's parent-scoped tab mechanism (AD-5): four more table tabs, a new views group and a new procedures group. Each screen's read is an advertised read tool.

## Boundaries & Constraints

**Always:**

- 19.5's order, binding and limits for every new endpoint. The order is: gate, endpoint, version (`Query:6`), arguments, resolve, route. `query` is a port parameter, `parameters` holds only validated or resolved values, and `max` is the read's `maxRows`, else `CATALOGMAX`.
- A view's tabs resolve `view` (`Schema.View`, at most 257 characters, no control character) through `INFORMATION_SCHEMA.VIEWS` first, and a procedure's tabs resolve `procedure` through `INFORMATION_SCHEMA.ROUTINES`. Each then binds the exact schema and name its row answers. None is 404 `PORT.NOTFOUND` (unlogged); two is 400 `PORT.VALIDATION`.
- `Catalog.Partitions` and `Catalog.PartitionMappings` send their statement only when the resolved table row's `IS_PARTITIONED` reads `YES`. Otherwise they answer zero rows with no `Query` call.
- The three SQL statements tabs read `INFORMATION_SCHEMA`'s statement tables (Design Notes › Statements).
- A view's text, a procedure's description (as plain text, `PlainText`), a statement's text and a cached query's text are row fields: untrusted (AD-11), cut by AD-24's per-field bound in a tool result and in screen context, passed through AD-60, and shown whole on the screen.
- Each screen declares `classicPage` `%CSP.UI.Portal.SQL.Home`, `%Development:USE`, scope `namespace`, entity type `class`, and three prompts in the `webAppPromptGroupCode` group. The table tabs follow the classic page's order.

**Never:**

- `%SQL_Manager.StatementIndex`. Never select `UserName`, `ClientName`, `ClientIP`, `ClientApp`, `CallStack`, `Plan` or `JSONPlan`.
- Caller text in `query`, a catalog query's `pFilter`, or `positional`.
- A write tool, a governance key, a new error code, a third-party library, or an edit to `Api/Error.cls`.
- The `work` routes, `docnames`' `filter`, or `POST modified` (AD-61 rule 7).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Table tabs | USER, probe `OcuProbe195`, a partitioned table | Partitions and Partition mappings (vendor rows), Cached queries, SQL statements (the probe's statement, its kept literal shown) | None |
| Not partitioned | Partitions or Partition mappings of a plain table | Zero rows, empty state, no `Query` call after the resolve | None |
| View tabs | `view` `OcuProbe195.VisibleNames` | View info (one row, with its text), Fields, SQL statements | None |
| Procedure tabs | `procedure` naming a probe query procedure | Stored procedure info (one row), SQL statements | None |
| Case | `ocuprobe195.visiblenames` | Resolves to the same view | None |
| Absent or unprivileged | No such view or procedure, or one the caller holds no privilege on | 404 `PORT.NOTFOUND`, unlogged | Banner |
| Ambiguous | Two rows answer one name | 400 `PORT.VALIDATION` with the port's reason | Banner |
| Bad input | `view` or `procedure` with no `.`, over 257, or with a control character | 400 `PORT.VALIDATION` before any route | Banner |
| Long text | A view text, a description or a statement over 1,000 characters | The screen shows it whole; the tool and screen context cut it and list it in `truncatedFields` | None |
| Gate | No `%Development:USE`, or no READ on the namespace's code database | 403 `AUTH.NOPRIVILEGE` naming the pair, before any route | Banner |
| Old instance | Highest version 5 | 501 `PORT.NOTIMPLEMENTED` | Banner |
| SQL error | The route answers 200 with `status.errors` | 500 `INTERNAL`; vendor text logged, never sent | Banner |

</intent-contract>

## Code Map

- `src/OcuPilot/Port/AtelierPort.cls` is the port. Line numbers are at the baseline.
  - Registration: `ENDPOINT*` :105-121, `CATALOGTABS` :125, `CATALOG*QUERY` :132-155, `CATALOG*COLUMNS` :163-179 (kinds `flag`, `number`, `qualified`), keys :184-186, `MAXTABLE` :192, `CATALOGMAX` :195, `REASONCATALOG*` :523-533.
  - `MinVersion` :665 maps every `IsCatalog` endpoint to `Query:6`, so `MINVERSIONS` needs no edit. The served check is `Invoke` :770-771 (`LIST` only); dispatch is :847-849.
  - `IsCatalog` :1086, `CatalogStatement` :1093, `CatalogColumns` :1100.
  - `CatalogRows` :1123-1206: validation :1132-1154, binding :1156-1172, `max` :1177, row filter :1191.
  - `CatalogResolve` :1208-1241 is the model for the view and procedure resolves. `CatalogRow` :1243 is where the `plain` kind goes. `PlainText` :2653. `SnippetForm` :2994 answers `""` for reads.
- `src/OcuPilot/Screen/Descriptor/ExplorerSqlTable.cls` (head) and `ExplorerSqlTriggers.cls` (tab) are the templates.
  - `ExplorerSqlTriggers` moves from position 4 to 6, and `ExplorerSqlConstraints` from 5 to 7.
  - `ExplorerSqlViews.cls:7` and `ExplorerSqlProcedures.cls:7` say "never read"; those sentences become untrue.
- The mechanism is generic, so no client or registry code changes.
  - `Screen/Registry.cls`: `TabProblem` :549-597; `TabGroupProblem` :671-757, where one criterion is shared at :741-745 and the group is `parentScope + "/document"` at :748-751; `READTOOLIDENTIFIERPATTERN` :1036.
  - `ui/src/app/shell/data-table.ts:654-662` and `core/navigation.ts:262-266` (`documentScreenFor`): a list's name cell links to a built, unlisted, id-keyed `<list>/document`, with the `name` column's field as the id. So `View` and `Procedure` link with no change.
  - `detail-page.ts:143-147`: the strip's title is the head's `labelKey`.
  - `side-bar.ts:163-164` marks any group's parent list.
  - `screen-outlet.ts:115` sends every `detail` screen to `DetailPage`.
- Tests:
  - `Test/AtelierPortCatalog.cls` (305 lines): `Body`, `Resolved` and `ArmCatalog`. `Test/AtelierPortFixture.cls` `Query` :263.
  - `Test/AtelierPortCatalogLive.cls` (383) and `Test/ExplorerSqlProbe.cls` (179; `Make` :50-81, `Remove` :107-134, `RunAs` :141).
  - `Test/ExplorerCatalog.cls`: the tool loop :117, and :120 needs more than zero rows.
  - `Test/AtelierDenialProbe.cls:29-38`; `AtelierPortDenial.TestTheCatalogIsRefusedNamingThePair` :392.
  - `Test/InjectionSeed.cls`: sources :6-13 and `Plant`/`Remove`/`ReadCall` :144-209, :492. `Test/InjectionChannels.cls` `TestTriggerCode` :271.
  - Rosters are under Design Notes. `ui/browser/system-explorer-sql.browser-spec.mjs`: the five labels at :152, and probe setup :49-62.
- Vendor sources are read, never edited:
  - `%SQL.Manager.Catalog` is Hidden. 19.5's export is in the session scratchpad at `vendor195/Catalog.cls`; otherwise re-export it with `GetTextAsString`. Queries: `CachedQueryTable` :421, `ProcedureInfo` :1476 (declares `RETURN_VALUE` twice), `StatementIndex` :2233 (`CheckAggregateStats` :2246), `Partitions` :2805, `PartitionMappings` :2856, `ViewFields` :3308, `ViewInfo` :3381, `ViewInfo2` :3443.
  - `irissys/%CSP/UI/Portal/SQL/Home.cls`: tabs :473-488, panes :590-740, view and procedure drawing :3400-3560.
  - `irislib/INFORMATION/SCHEMA/STATEMENTS.cls` (identifying columns :90-102), `STATEMENTRELATIONS.cls`, `STATEMENTLOCATIONS.cls`.

## Tasks & Acceptance

**Execution:**

- [ ] `src/OcuPilot/Port/AtelierPort.cls`: the family.
  - Nine endpoints, `LIST` only: `Catalog.Partitions`, `Catalog.PartitionMappings`, `Catalog.CachedQueries`, `Catalog.TableStatements`, `Catalog.View`, `Catalog.ViewFields`, `Catalog.ViewStatements`, `Catalog.Procedure`, `Catalog.ProcedureStatements`.
  - Keys `view` and `procedure`; tab lists for each kind. Two resolves, and `IS_PARTITIONED` added to 19.5's resolve.
  - The statements, column maps and the `plain` kind (Design Notes › Statements). `Catalog.View` merges `ViewInfo`'s text into `ViewInfo2`'s one row.
  - Six `REASON*` sentences (Design Notes › Strings) and one doc paragraph.
- [ ] `src/OcuPilot/Screen/Descriptor/`, nine new descriptors (Design Notes › Screens). Change `ExplorerSqlTriggers` and `ExplorerSqlConstraints` positions to 6 and 7. Correct the "never read" sentence in `ExplorerSqlViews` and `ExplorerSqlProcedures`.
- [ ] `ui/src/app/core/strings.ts`: append the keys at the end, each `/** EXPERIENCE.md:596 */`. Regenerate `screens.generated.ts`.
- [ ] EXPERIENCE.md:
  - Edit :159 in place: "(Stories 19.1, 19.4, 19.5 and 19.14) … a table opens to its catalog tabs, and a view and a stored procedure to theirs."
  - Add one Fixed-strings row after :595, `[ADDED 2026-10-03 - Story 19.14]`.
- [ ] `src/OcuPilot/Test/ExplorerSqlProbe.cls`. `Make` adds:
  - partitioned table `Parted` (`PARTITION BY RANGE (D) INTERVAL 1 MONTHS`, two rows);
  - view `LongView` (text over 1,000 characters), and view `HiddenNames` over `Hidden`;
  - class `OcuProbe195.Described` with a `[SqlProc]` method whose HTML description runs over 1,000 characters;
  - query procedure `Names`;
  - and runs `SELECT * FROM OcuProbe195.Names()` and a statement on `Visible` with a kept literal `((...))`.

  `Remove` drops these too.
- [ ] `src/OcuPilot/Test/AtelierPortCatalogTabs.cls` (new), through the fixture:
  - each new endpoint's exact `query`, `parameters` and `max`, including `Catalog.View`'s two calls and a dotted name's `$Char(1)` relation key;
  - the view and procedure resolves answering none (404) and two (400);
  - the partitions short-circuit (no call after a resolve answering `NO`);
  - every validation refusal before any route; the version gate on all nine; a soft SQL error → 500 with nothing sent;
  - row shapes: `plain`, and no identifying key.
- [ ] `src/OcuPilot/Test/AtelierPortCatalogTabsLive.cls` (new), live in USER through `ExplorerSqlProbe`:
  - every matrix row;
  - `LongView`'s text whole through `Screen.Read`;
  - a principal created and removed as `AtelierPortCatalogLive`'s is (armed by `OCUPILOT_ALLOW_PRINCIPALS`, :20, :74, :333), granted SELECT on `Visible` and `VisibleNames` and EXECUTE on `Names`: `HiddenNames`' and `Echo`'s tabs are 404.
  - `scripts/ci-throwaway.sh`: add the class to the `OCUPILOT_ALLOW_PRINCIPALS` roster after :294, which `ui/tools/ci.test.mjs` holds against the declaring classes.
- [ ] `Test/ExplorerCatalog.cls`: the nine tools through dispatch, with rows only and `LongView`'s `Text` past 1,000 in `truncatedFields`. `Parted` has no partition mapping configured (measured: zero rows), so the mappings tool's leg asserts 200 and an empty `rows`. Add one HTTP leg for a view tab.
- [ ] `Test/AtelierDenialProbe.cls`, `AtelierPortDenial.cls`: legs for `Catalog.View` and `Catalog.Procedure`, refused without `%Development` and without the namespace's READ.
- [ ] `Test/InjectionSeed.cls`, `InjectionChannels.cls`:
  - source `k`, a view's text, read through `explorer.sqlview.read`;
  - source `l`, a SqlProc's description, read through `explorer.sqlprocedure.read`;
  - source `m`, a statement's kept literal, read through `explorer.sqltablestatements.read` and `explorer.sqlcachedqueries.read`.
- [ ] Rosters (Design Notes › Rosters).
- [ ] Client tests:
  - `detail-page.spec.ts`: nine labels in classic order, and the views group keeps the id.
  - `screen-mirror.test.mjs`, `navigation.test.mjs`, `self-protection.test.mjs` (six `FIND_REFUSALS` rows).
  - `system-explorer-sql.browser-spec.mjs`: nine table tabs; Partitions empty on `Visible`; SQL statements shows the probe statement; open a view (View info shows its text, then Fields, then SQL statements); open a procedure.
- [ ] `ui/angular.json`, `ui/tools/angular-json.test.mjs`: re-base `maximumWarning` to the measured build (DW-1166). Repair the cut comment lines at :424, :430 and :433. Stop and ask above 3,800 kB.

**Acceptance Criteria:**

- AC1: Given a table in SQL tables, when the person opens it, then the strip holds Table info, Fields, Maps/Indices, Partitions, Partition mappings, Triggers, Constraints, Cached queries and SQL statements in that order. The four new tabs show the instance's rows for that table, and switching tabs keeps the table.
- AC2: Given a view in SQL views, when the person opens it, then View info shows its owner, last compile, read-only and updatable flags, class, check option, class type and text. Fields shows its columns and SQL statements shows its statements, and switching tabs keeps the view.
- AC3: Given a procedure in SQL procedures, when the person opens it, then Stored procedure info shows its class, type, method, plain-text description, parameter counts and lists, interface, result columns and return value. SQL statements shows its statements.
- AC4: Given a table that is not partitioned, when Partitions or Partition mappings opens, then it shows its empty state and the port sends no `Query` after the resolve.
- AC5: Given statements another account ran, when any SQL statements tab is read by the screen or a tool, then each row carries statement text and statistics and never a user name, client name, address, application or call stack. The statement sent is the `INFORMATION_SCHEMA` one, never `StatementIndex`. (Accepted by=merge_gate as classic parity; the reversal, if the owner asks, is one `WHERE` limiting the read to the caller's own statements.)
- AC6: Given a principal granted SELECT on one probe view and EXECUTE on one probe procedure, when it reads the catalog, then those tabs read, and an ungranted view's or procedure's tabs answer not found.
- AC7: Given the agent's tools, when they are listed, then the nine new read tools are advertised and answer bounded rows. A view's text, a description and a statement's text past 1,000 characters are cut and reported, and a seeded injection in each produces no proposal or navigation (AD-11 rule 5).
- AC8: Given any new catalog read, when it executes, then `action/query` receives one of the port's fixed statements with every caller value only in `parameters`, and no `pFilter`.
- AC9: Given classic parity (AD-44), when the descriptors are read, then each declares `%CSP.UI.Portal.SQL.Home`, and a custom resource on that page gates all eighteen catalog screens.
- AC10: Given a `%Developer` account, when it opens the nine screens in USER, then it reads them, and it is refused by name where it cannot read the code database (`DeveloperFloor`).
- AC11 (Integration, Rule 1): Given a row in SQL views and one in SQL procedures on the real instance, when the person opens each from its list's name cell, then the new head opens, and switching to SQL statements reads the same object through that tab's own declared read.

## Spec Change Log

- 2026-10-03, lead (spec gate): the spine carries the drafts (AD-61 rules 3, 7, 8; AD-36). The three open questions are accepted as decided in Design Notes (statements without identifying columns from `INFORMATION_SCHEMA`, never `StatementIndex`; partition tabs short-circuit on an unpartitioned table; definitions and statement text as bounded row fields). The plan's `deferred:` DW-1001 occurrence is harvested to the ledger. The Fixed-strings bound raise (2300 to 2500) is approved by=merge_gate.

## Review Triage Log

## Design Notes

**Measured on `ocupilot-a2-ci`, 2026-10-03.** The probe objects were schema `OcuProbe1914` in USER, class `OcuProbe1914.Described`, `OcuProbe1914.Port` in HSCUSTOM (a subclass of the port, calling `Route`), and principal `OcuProbe1914User`/`Role` (`%Development:U`, `%DB_USER:R`). All were removed and read back gone, together with the stopped run's leftover principal and data globals. The probe's statement-index rows remain.

- **Privilege filtering.**
  - `INFORMATION_SCHEMA.VIEWS` and `ROUTINES` filter by privilege. The principal's resolve answered 0 rows for an ungranted view, an ungranted procedure and an ungranted query procedure, and matched case-insensitively.
  - `ViewInfo`, `ViewInfo2`, `ProcedureInfo` and `Partitions` do not filter. The principal read the ungranted view's text and the ungranted procedure's info.
  - `ViewFields` drops ungranted columns, and `CachedQueryTable` drops statements the caller cannot run.
  - Hence the resolve before every view and procedure tab.
- **Partitions.**
  - On a table that is not partitioned, `Partitions` and `PartitionMappings` fail the fetch (SQLCODE -400, #31007). Through the port that is 500 `INTERNAL`, and each read logs an error-severity line to messages.log.
  - On a partitioned table, the classic query answers sub-partition rows: 4 rows where `INFORMATION_SCHEMA.TABLE_PARTITIONS` answers 2.
  - `IS_PARTITIONED` reads `YES` or `NO` in the table resolve.
- **Statements.**
  - The principal read every account's statements on a table, through both `StatementIndex` and `INFORMATION_SCHEMA.STATEMENTS`. That included `irisowner`'s user name and call stack, a literal kept by `((...))`, a join naming a table it cannot see, and the statements on that hidden table. The privilege expression in `STATEMENTS.cls:261` admits a `%Development` holder (inference).
  - `StatementIndex` returns no rows for a function or a non-query procedure, and one row for a query procedure. The information-schema relation join answered the same, object for object.
  - **`StatementIndex` starts a write.** The first call after a quiet interval started a process (43 → 44 jobs) that journaled 74 SETs of `^rINDEXSQL("sqlidx",5,<hash>,"stat",…)` into IRISSYS, HSCUSTOM and USER. A second call within seconds started none.
    - The principal's call, holding READ alone, did the same: 78 SETs in databases the principal cannot write. No `^ERRORS` entry was added.
    - An `INFORMATION_SCHEMA.STATEMENTS` read started no process and journaled nothing.
  - Repeated calls of `CachedQueryTable`, `Partitions`, `ViewInfo` and `ProcedureInfo` journaled nothing.
- **Route.**
  - `ProcedureInfo`'s object row keeps only the second `RETURN_VALUE`, the return parameter's text (`_isc_sp_ret_val INTEGER`). `PROCEDURE_INTERFACE` 2 or -2 still says a value is returned.
  - `%ODBCOUT(StatFirst)` answers `2026-10-03`.
- **Lengths (HSCUSTOM).**
  - The longest view text is 5,856 characters (`%SYS_PTools.StatsSQLView`).
  - 174 of 5,953 SqlProc method descriptions run over 1,000 characters (the longest 41,734), and 71 of 2,156 query descriptions do.
  - `ViewInfo` keeps a SQL comment in a view's text. The statement index strips comments but keeps a `((...))` literal.
- **Cost (HSCUSTOM, `%All`).** These are AD-61 rule 8's numbers.

  | Read | Rows | Time |
  |---|---|---|
  | Statements read, busiest relation (first prepare) | 48 | 0.039 s, 50k global references |
  | The same statements read, again | 48 | 0.0012 s |
  | Routine resolve | — | 0.02-0.04 s, 52k-90k global references |
  | View resolve | — | 0.02 s |
  | `ViewInfo`, the longest view | — | 0.004 s |
  | `ProcedureInfo`, `CachedQueryTable` | — | under 0.001 s |
  | Classic `Partitions` | — | 0.004-0.05 s |

**Decisions for the spec gate.**

- *Q1, what a SQL statements tab may show.* Every statement on the object, as the classic tab lists them, with the identifying columns never selected.
  - AD-29 holds: a `%Development` holder reads all of it directly, through the classic page and `INFORMATION_SCHEMA.STATEMENTS` (measured).
  - AD-44: the classic tab's own columns omit user, client and call stack, so dropping them is parity. The resolve is stricter than the classic page.
  - Named consequence: a statement's text can carry another account's literal values. It is untrusted, bounded content (AD-24, AD-60).
  - The two other options are refused. "The caller's own statements" filters on whoever prepared a statement first, not on who ran it. A stricter gate has no pair in the spine to stand on.
- *Source: the information schema, not `StatementIndex`.* `StatementIndex`'s aggregation is a vendor process writing IRISSYS and every namespace's routines database on a read, which AD-7 does not admit. The information-schema read starts nothing (measured).
  - Named difference: its statistics are the last aggregated ones, while the classic page aggregates first, so the classic page's counts can be newer (inference).
  - Rejected alternative: `StatementIndex` with a sixth AD-7 shape.
- *Q2: the resolve decides.* The classic query, sent only for a partitioned table, keeps classic parity. `TABLE_PARTITIONS` answers level-1 rows only, costs 0.15 s, and also does not filter.
- *Q3: row fields, reaching the agent bounded.* Trigger code is the precedent (AD-36). A screen-only payload would need a non-`detail` head, and a tab group shares one archetype (`Registry.cls:700-707`).
- *View fields get their own tab.* The classic View Info draws the info, the text and the columns together. One read cannot answer two row shapes (AD-36), so the views group is View info, Fields and SQL statements. That makes nine screens.

**Statements.** Each `?` is bound in order. A tab first binds the resolved names.

| Endpoint | `query` | Fields (`COLUMN:kind`) |
|---|---|---|
| table resolve (19.5, amended) | 19.5's statement with `, IS_PARTITIONED` in its select list | — |
| view resolve (`max` 2) | `SELECT TABLE_SCHEMA, TABLE_NAME FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_SCHEMA \|\| '.' \|\| TABLE_NAME = ?` | — |
| procedure resolve (`max` 2) | `SELECT ROUTINE_SCHEMA, ROUTINE_NAME FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_SCHEMA \|\| '.' \|\| ROUTINE_NAME = ?` | — |
| `Catalog.Partitions` | `CALL %SQL_Manager.Partitions(?, ?)` | `Partition` PARTITION_ID, `Buckets`, `Rows`, `EstimatedSize` (each `:number`), `Location` |
| `Catalog.PartitionMappings` | `CALL %SQL_Manager.PartitionMappings(?, ?)` | `Rule` RULE, then as Partitions |
| `Catalog.CachedQueries` | `CALL %SQL_Manager.CachedQueryTable(?, ?)` | `CachedQuery` Routine, `Query`, `Created` CreateTime, `Source:flag`, `QueryType` QueryTypeExt, `Features` STATEMENT_OPTIONS |
| `Catalog.*Statements` (three) | the statements read below; one parameter, the relation key `$ZConvert(schema,"U")_"."_$ZConvert($Translate(name,".",$Char(1)),"U")`, the vendor's own rule (`Catalog.cls:2244`) | `Statement`, `PlanState`, `NewPlan:flag`, `Executions`, `TotalTime`, `AverageTime`, `StdDevTime`, `RowCount`, `Commands` (each `:number`), `FirstSeen`, `Location` |
| `Catalog.View` | `CALL %SQL_Manager.ViewInfo2(?, ?)`, then `CALL %SQL_Manager.ViewInfo(?, ?)` merged into its row | `Owner`, `LastCompiled`, `ReadOnly:flag` DEFINED_AS_READ_ONLY, `Updatable:flag`, `Class` CLASSNAME, `CheckOption`, `ClassType`, `Text` VIEW_QUERY |
| `Catalog.ViewFields` | `CALL %SQL_Manager.ViewFields(?, ?)` | `Field`, `Type` DATATYPE, `Collation`, `MaxLength:number`, `MaxValue`, `MinValue`, `Stream:flag` BLOB, `Length`, `Precision`, `Scale` (each `:number`) |
| `Catalog.Procedure` | `CALL %SQL_Manager.ProcedureInfo(?, ?)` | `Class`, `Type`, `Method`, `Description:plain`, `Inputs`, `InOuts`, `Outputs`, `Interface`, `Columns` (each `:number`), `InputParameters`, `InOutParameters`, `OutputParameters`, `ResultColumns`, `ReturnValue` |

The statements read, sent as measured through the route:

```sql
SELECT CASE s.Frozen WHEN 1 THEN 'Frozen/Explicit' WHEN 2 THEN 'Frozen/Upgrade' WHEN 3 THEN 'Unfrozen/Parallel' ELSE 'Unfrozen' END AS PLAN_STATE,
  s.FrozenDifferent AS FROZEN_DIFF, s.StatCount AS EXECUTIONS, s.StatTotal AS TOTAL_TIME, s.StatAverage AS AVERAGE_TIME,
  s.StatStdDev AS STDDEV_TIME, s.StatRowCount AS ROW_COUNT, s.StatCommands AS COMMANDS, %ODBCOUT(s.StatFirst) AS FIRST_SEEN,
  SUBSTRING(s.Statement, 1, 1024) AS STATEMENT, l.Location AS LOCATION
FROM INFORMATION_SCHEMA.STATEMENT_RELATIONS r JOIN INFORMATION_SCHEMA.STATEMENTS s ON s.Hash = r.Statement
LEFT OUTER JOIN INFORMATION_SCHEMA.STATEMENT_LOCATIONS l ON l.Statement = s.Hash WHERE r.Relation = ?
```

The `SUBSTRING` keeps a full answer under the capture ceiling. It cuts at 1,024 characters, as the classic tab does. `plain` reads a value through `PlainText`.

**Screens.** All nine are `detail`, side bar 0, `id` single, and declare the group's one criterion (`text` 257). Context fields equal the table's columns.

| Descriptor | Route under `system-explorer/` | Group, position | Criterion | Tool `explorer.` |
|---|---|---|---|---|
| `ExplorerSqlPartitions` | `sql-tables/partitions` | tables, 4 | `table` | `sqlpartitions` |
| `ExplorerSqlPartitionMappings` | `sql-tables/partition-mappings` | tables, 5 | `table` | `sqlpartitionmappings` |
| `ExplorerSqlCachedQueries` | `sql-tables/cached-queries` | tables, 8 | `table` | `sqlcachedqueries` |
| `ExplorerSqlTableStatements` | `sql-tables/statements` | tables, 9 | `table` | `sqltablestatements` |
| `ExplorerSqlView` (head) | `sql-views/document` | views, 1 | `view` | `sqlview` |
| `ExplorerSqlViewFields` | `sql-views/fields` | views, 2 | `view` | `sqlviewfields` |
| `ExplorerSqlViewStatements` | `sql-views/statements` | views, 3 | `view` | `sqlviewstatements` |
| `ExplorerSqlProcedure` (head) | `sql-procedures/document` | procedures, 1 | `procedure` | `sqlprocedure` |
| `ExplorerSqlProcedureStatements` | `sql-procedures/statements` | procedures, 2 | `procedure` | `sqlprocedurestatements` |

**Spine amendments (drafts for the spec gate).**

- **AD-61 rule 3:** "A view's or a procedure's tab binds the schema and name that its own privilege-filtered `INFORMATION_SCHEMA.VIEWS` or `ROUTINES` row answers (Story 19.14)."
- **AD-61 rule 7:**
  - "A SQL statements tab reads `INFORMATION_SCHEMA`'s statement tables and never `%SQL_Manager.StatementIndex`. Its aggregation check starts a process that writes statement statistics into IRISSYS and every namespace's routines database, for a caller holding READ alone too (measured, Story 19.14). No statement read selects a user name, client or call stack."
  - "`ViewInfo`, `ViewInfo2`, `ProcedureInfo` and `Partitions` filter nothing by privilege (measured). `Partitions` and `PartitionMappings` are sent only for a table whose resolved row reads partitioned, because on any other table they fail the fetch."
- **AD-61 rule 8:** the cost table above.
- **AD-36:** "A view's text, a stored procedure's description as plain text, a SQL statement's text and a cached query's text are such row fields too (Story 19.14), shown whole on the screen."

**Strings.**

- One Fixed-strings row holds the new literals.
  - Eight tab and title labels: "Partitions", "Partition mappings", "Cached queries", "SQL statements", "SQL view", "View info", "SQL procedure", "Stored procedure info".
  - About 40 column headers. Reuse any existing key with the same text ("Fields", "Owner", "Class", "Location"…).
  - Nine empty states, for example "This table has no partitions." and "No SQL statements reference this view.".
  - 27 prompts.
- The six reasons:
  - "Name one view, as Schema.View."
  - "Name one procedure, as Schema.Procedure."
  - "That name matches more than one view in this namespace."
  - "That name matches more than one procedure in this namespace."
  - "This namespace holds no view by that name that this account can see."
  - "This namespace holds no procedure by that name that this account can see."
- About 90 literals in all (inference) against 2,179 measured. 19.14 alone stays under the 2,300 bound. With Story 18.19's row merged it reaches about 2,300 (inference), so **the bound needs raising: 2,500 is recommended**, a contended edit for the lead at whichever merge lands second.

**Rosters** (verify each at edit time):

- `ExplorerDescriptor`:
  - `DESCRIPTORS` :17 (18 → 27), read rows :50-52, criteria defaults :78.
  - The tool literal :148, and the name and doc of `TestTheAreaHoldsFifteenReadsAndEightWrites` :124-133 (24 reads).
  - The table group's expected string :256-273, plus views and procedures group tests.
  - `TestACustomResourceOnTheSqlPageGatesAllNine` :280-297, which becomes eighteen.
- `ReadTool`: 229 → 238 at :93, names :94, pairs :112, criteria descriptors 32 → 41 at :368.
- `ToolRoundTrip` `REFUSEEMPTY` :63: nine `:PORT.VALIDATION` entries.
- `SurfaceCoverage`: nine screen rows after :167. `Descriptor` `ReadShapes`: nine rows after :147.
- `DeveloperFloor`:
  - `SCREENS` :33 (+9) and `TOOLS` :36 (+9).
  - The count words "twenty-three" → "thirty-two" at :9, :432 and :455.
  - The read loop :261 gains a view and a procedure the `%Developer` sees in USER.
  - If the class passes 500 lines, the catalog read leg moves to a new `DeveloperFloorCatalog`.
- `screen-mirror.test.mjs`: tab members :795-817, `withCriteria` :1258-1294, atelier map :2641-2672.
- `navigation.test.mjs` :263-268 (do not rewrite :289), `detail-page.spec.ts` :52 and :175-196, `self-protection.test.mjs` :538-549.

**Consumes:** 19.5's port family (`Route`, `Outcome`, `CatalogResolve`, `CatalogRow`), the parent-scoped tab mechanism, `DetailPage`, `Screen.Read`. **Consumed-by:**

- 19.10: the statement-text decision (identifying columns never read) and the information-schema statement read.
- 19.11: the read tools, for the agent's SQL.

**ADs.** AD-5, AD-7, AD-8, AD-11, AD-12, AD-13, AD-16, AD-21, AD-24, AD-27, AD-29, AD-36, AD-39, AD-44, AD-60, AD-61.

**Footprint (Rule 11).** Checked 2026-10-03 against `.worktrees/epic-18` at `a2334efb8f419a5c8d548e646d57e4a55fd173be` (Story 18.19, implement; committed, tree clean). Epic 18 has not merged 19.5, so the conflicts already exist.

- **Contended, add-only:**
  - `SurfaceCoverage` rows after :167 and `Descriptor` rows after :147. Epic 18 inserts at :173 and :152.
  - `screen-mirror.test.mjs` SQL blocks. Avoid :1256.
  - `navigation.test.mjs` :263-268.
  - `strings.ts`, appended at the end.
  - EXPERIENCE.md :159 and a row after :595. Epic 18 edits :173, :378 and :656.
  - `screens.generated.ts` is regenerated.
  - `scripts/ci-throwaway.sh`, one roster line after :294. Epic 18 inserts at :301. This is a footprint extension, as it was for 19.5.
- **Contended, not add-only (lead approval):**
  - `ReadTool` :93, :94 and :368.
  - The `strings.test.mjs` bound.
  - `angular.json` with `angular-json.test.mjs`.
  - The spine: AD-36 and AD-61. Epic 18 edits AD-21 :400 and Deferred :1179.
- **Not contended:** `AtelierPort.cls`, all `ExplorerSql*` descriptors, `ExplorerDescriptor`, `ToolRoundTrip`, `DeveloperFloor*`, the `Atelier*` tests, `ExplorerSqlProbe`, `ExplorerCatalog`, the `Injection*` tests, `detail-page.spec.ts`, `self-protection.test.mjs`, the browser spec.

**Integration ACs:** AC11. **Ledger inbox:** none owned; DW-1001 occurrence in `deferred:`.

## Verification

Load source into `ocupilot-a2-ci` and never restart it:

1. `rsync -a --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-19/src/ /tmp/ocupilot-a2-ci/src/`
2. In `docker exec -i ocupilot-a2-ci iris session iris -U HSCUSTOM`, run `$System.OBJ.LoadDir("/opt/ocupilot/src","ck",.tErrors,1)`, then check the status and `tErrors`.

**Run one test-runner call at a time, and wait for each.** Never re-submit after a client-side timeout. Every `OcuProbe195*` object and principal is removed.

**Commands:**

- `uv run scripts/check-objectscript.py && uv run scripts/test_check_objectscript.py` (loop): expected green.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-a2-ci --class OcuPilot.Test.<Class>` (loop), one class per call: expected green. Run it for:
  - `AtelierPortCatalogTabs`, `AtelierPortCatalogTabsLive`, `AtelierPortCatalog`, `AtelierPortCatalogLive`, `ExplorerCatalog`, `AtelierPortDenial`, `ExplorerDescriptor`;
  - `ReadTool`, `ToolRoundTrip`, `SurfaceCoverage`, `Descriptor`, `DeveloperFloor`, `InjectionChannels`.
- `cd ui && npm run test:tools && npx ng test --include 'src/app/shell/**/*.spec.ts'` (loop): expected green.
- Browser (loop). Build and deploy first: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-a2-ci:/durable/iris/csp/ocupilot/`. Then run `OCUPILOT_BROWSER_ORIGIN=http://localhost:52780 OCUPILOT_BROWSER_CONTAINER=ocupilot-a2-ci node --test --test-concurrency=1 browser/system-explorer-sql.browser-spec.mjs`, then the same for `a11y-structural-invariants.browser-spec.mjs`, each alone: expected green. The full browser suite is CI's.
- `bash scripts/lint-docs.sh && cd ui && npm run test:tools` (loop, after the EXPERIENCE.md edit): expected green.
- `cd ui && npm test` (once, before dev_complete): expected green, with the budget re-based.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-a2-ci`, the full ObjectScript sweep, one class at a time (once, before dev_complete): expected green apart from the known `WireSecurityRead` (DW-1554) and `Retention` (DW-1929) residue.

**Planned mutations (Rule 19)**, one per AC:

- AC1: `Catalog.CachedQueries` binds schema and name swapped → the live table-tabs leg.
- AC2: `Catalog.View` drops the `ViewInfo` merge → the live view leg (its `Text`).
- AC3: `Description` mapped without `plain` → the live procedure leg (no tag survives).
- AC4: the short-circuit skipped → the fixture leg (a `Query` call after a `NO` resolve).
- AC5: `UserName` added to the statements read and its map → the fixture's exact-body leg and the live row-shape leg.
- AC6: the view resolve skipped for `Catalog.View` → the principal's ungranted-view leg.
- AC7: `Bound.Apply`'s per-field cut skipped → the `ExplorerCatalog` bound leg.
- AC8: the relation key spliced into the statement → the fixture's exact-body leg.
- AC9: `ExplorerSqlView` `classicPage` `""` → `ExplorerDescriptor`.
- AC10: `ExplorerSqlProcedure` privileges `[]` → `DeveloperFloor`.
- AC11: the Views name cell linking to the list itself, rebuilt and redeployed → the browser view leg.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
