---
title: 'Story 19.5: The SQL catalog browser'
type: 'feature'
created: '2026-10-02'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-19-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** System Explorer cannot show a namespace's SQL catalog, so a developer still opens the classic SQL page to see which schemas, tables, views and procedures exist and how a table is built.

**Approach:** `AtelierPort` gains a catalog endpoint family over Atelier's `POST action/query`, each endpoint one port-owned fixed statement with every caller value in `parameters`. Four listed screens (Schemas, Tables, Views, Procedures) read the information schema and the classic page's `Schemas` query; a table opens to a parent-scoped tab group (Table info, Fields, Maps/Indices, Triggers, Constraints) reading the classic page's own catalog queries. Each screen's read is an advertised read tool.

## Boundaries & Constraints

**Always:**

- AD-61's order for every catalog endpoint: the gate (`%Development:USE`, then the namespace's READ pairs), the endpoint, the version (`MINVERSIONS` `Query:6`), the arguments, then the route.
- The body is `{query, parameters}` through `AtelierRequest.SetJsonBody`. `query` is the endpoint's fixed text from a port parameter; `parameters` holds only validated caller values in declared order. `max` is the read's `maxRows` (cap plus one), or 2 for the table resolve.
- A tab's `table` (`Schema.Table`) is resolved first through the privilege-filtered `INFORMATION_SCHEMA.TABLES`; the catalog call is then bound with the exact schema and table that row answers. No row is 404 `PORT.NOTFOUND` (unlogged); two rows is 400 `PORT.VALIDATION`.
- Trigger `Code` reaches a tool and screen context only as a row field, cut by AD-24's per-field bound and wrapped by AD-60.
- Every screen declares `classicPage` `%CSP.UI.Portal.SQL.Home`, `%Development:USE`, scope `namespace`, entity type `class`, and three prompts in the `webAppPromptGroupCode` group.

**Never:**

- Caller text in `query`, a catalog query's `pFilter` argument, or `positional`.
- `Fields`' `OUTLIER_VALUE` or `HISTOGRAM` (data values) in any row.
- `ViewInfo`, `ViewInfo2`, `ViewFields`, `ProcedureInfo`, `Partitions`, `PartitionMappings`, `CachedQuery*` or `StatementIndex` (Story 19.14 after the split; Design Notes).
- A write tool, a governance key, a new error code, a third-party library, or an edit to `Api/Error.cls`.
- The `work` routes, `docnames`' `filter`, or `POST modified` (AD-61 rule 7).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Lists | USER, probe schema `OcuProbe195`; `system` no | Schemas, Tables, Views, Procedures rows for the caller; no `%` or `INFORMATION_SCHEMA` row | None |
| System | `system` yes | `%` schemas and system tables also list | None |
| Schema | Tables with `schema` `OcuProbe195` | Only that schema's tables | None |
| Over the cap | more rows than `maxRows` | Exactly the cap; `truncated` true | Cap notice |
| Table tabs | `table` `OcuProbe195.Visible` | Info (one row), Fields, Indices, Triggers (with `Code`), Constraints | None |
| Case | `table` `ocuprobe195.visible` | Resolves to the same table | None |
| Absent or unprivileged | no such table, or one the caller has no privilege on | 404 `PORT.NOTFOUND`, unlogged | Banner |
| Ambiguous | two tables answer one `Schema.Table` (delimited names with dots) | 400 `PORT.VALIDATION` with the port's reason | Banner |
| Bad input | `schema` over 128 or with a control character; `table` with no `.`; `system` not yes/no | 400 `PORT.VALIDATION` before any route | Banner |
| Gate | no `%Development:USE`, or no READ on the namespace's code database | 403 `AUTH.NOPRIVILEGE` naming the pair, before any route | Banner |
| Old instance | highest version 5 | 501 `PORT.NOTIMPLEMENTED` | Banner |
| SQL error | the route answers 200 with `status.errors` | 500 `INTERNAL`; vendor text logged, never sent | Banner |

</intent-contract>

## Code Map

- `src/OcuPilot/Port/AtelierPort.cls` -- the port.
  - Parameters: `MINVERSIONS` :65, `ENDPOINT*` :80-96, `REQUESTTYPE` :134, `CAPTURECEILING` :320, `FILEDEVICEROUTES` :328, `REASON*` :337-417.
  - `MinVersion` :549-565 (the endpoint-to-route `$Select` :554). `Invoke` :616-747: gate :626, namespace pairs :639-647, served check :649-656, version :657-664, `maxRows` :723-727, dispatch :728-740; row-shape doc :567-612.
  - `MacroRows` :975-1044 is the JSON-body precedent (`Route(..., tBody)` :1002). `Route` :2391-2501 (`SetJsonBody` :2408-2410, params :2414-2419). `Outcome` :2523-2611 (soft error → 500 unless `<PROTECT>` or `ACCESSDENIEDCODES`, :2595-2606). `SnippetForm` :2681 answers "" for reads.
- `src/OcuPilot/Screen/Read.cls:431-446` -- the atelier branch: `maxRows` cap+1 (:435), `SeedCriteria` (:954-1021), no parent-criterion check, so the port refuses a missing `table`.
- `src/OcuPilot/Screen/Registry.cls` -- criteria kinds :1383, keys :1533, `maxLength` required :1608; atelier refuses `rowGet` :1236; `TabProblem` :549-597 and `TabGroupProblem` :668-733 (shared area and archetype, positions 1..n, the head needs no side-bar position); `parentScope` :3593-3623 with one criterion :1438-1444; tool identifier pattern :990; prompt groups :2735-2740. `ui/tools/screen-mirror.mjs` mirrors each rule.
- Descriptor precedents: `Screen/Descriptor/ExplorerClassList.cls:33-90` (criteria list), `OAuthServerDescriptionTab.cls:74` and `OAuthClientTab.cls:85` (tab group), `GlobalMappingList.cls` (parent-scoped list served by `ListPage`).
- Client:
  - `ui/src/app/shell/screen-outlet.ts:192-201` `DESCRIPTOR_PAGES` (`CodeListPage` serves criteria lists; `list (server criteria)` otherwise falls to `AuditPage`, :104-116).
  - `areas/system-explorer/code-list.page.ts` -- the criteria form (yes/no as a checkbox), arrivals :312-332.
  - `shell/detail-page.ts:49-164` -- the tab strip over `ListPage`; `open()` :151 navigates to the bare `tab.route`, dropping the id.
  - `core/navigation.ts:256-266` `documentScreenFor` (`<list>/document`), `parentCriteria` :387-397, `tabMembersFor` :358-364; `shell/side-bar.ts:162` maps a tab to its group head.
- Tests: `Test/AtelierPortFixture.cls` (`Answer` :255-294 records body and content type; add `Query` beside :236-239); `Test/AtelierDenialProbe.cls:27` endpoint loop; `Test/AtelierPortDenial.cls` (`EnsurePrincipal`, `ProbeAs`); `Test/InjectionChannels.cls:256-269` and `InjectionSeed.cls:156-195,429-434` (sources (h), (i)).
- Vendor (read, never edited): `irissys/%Api/Atelier/v6.cls:173-275` (`Query`; `max` :217-219; fetch stops :384-386; row typing :309-352); `%SQL.Manager.Catalog` (Hidden; exported to the scratchpad at plan) `Schemas` :1580, `TablesOnly` :2728, `Fields` :619, `Indices` :975, `Triggers` :3251, `Constraints` :510, `GetFilters` :3912; `irislib/INFORMATION/SCHEMA/{SCHEMATA,TABLES,VIEWS,ROUTINES}.cls`; `irissys/%CSP/UI/Portal/SQL/Home.cls` (`RESOURCE` :22, tabs :473-488, calls :938-1033, :1561-1630).

## Tasks & Acceptance

**Execution:**

- [ ] Task 0 (`ocupilot-a2-ci`, before code): ten background jobs of 40 catalog calls each through a probe port subclass under the capture; any death adds `Query` to `FILEDEVICEROUTES`. Confirm the resolve's case-insensitive match and `%STARTSWITH '%'`. Record both in Design Notes.
- [ ] `src/OcuPilot/Port/AtelierPort.cls` -- the catalog family.
  - Nine endpoints `Catalog.Schemas`, `Catalog.Tables`, `Catalog.Views`, `Catalog.Procedures`, `Catalog.Table`, `Catalog.Fields`, `Catalog.Indices`, `Catalog.Triggers`, `Catalog.Constraints`, served for `LIST` only; `MinVersion` arms and `Query:6`.
  - One parameter per statement (Design Notes › Statements) and one column map per endpoint.
  - `CatalogRows`: validate the criteria; resolve `table` for the five tab endpoints; route `Query`; map columns to the declared fields; read `"0"`/`"1"` flags as booleans; cut at `maxRows`.
  - `REASON*` sentences (Design Notes › Strings); one doc paragraph.
- [ ] `src/OcuPilot/Screen/Descriptor/` (new, nine) -- `ExplorerSqlSchemas`, `ExplorerSqlTables`, `ExplorerSqlViews`, `ExplorerSqlProcedures` (listed, side bar 6-9, `list (server criteria)`, criteria `system` choice yes/no default no, plus `schema` text 128 on the last three); `ExplorerSqlTable`, `ExplorerSqlFields`, `ExplorerSqlIndices`, `ExplorerSqlTriggers`, `ExplorerSqlConstraints` (`detail`, side bar 0, `parentScope` `system-explorer/sql-tables`, criterion `table` text 257, `tab.group` `system-explorer/sql-tables/document`, positions 1-5). Fields, tables, context, prompts and tool identifiers per Design Notes.
- [ ] `src/OcuPilot/Screen/Registry.cls` and `ui/tools/screen-mirror.mjs` -- a parent-scoped tab group: every member declares the same `parentScope` and the same one criterion, or the group is refused (AD-5 draft).
- [ ] `ui/src/app/shell/detail-page.ts` -- in a parent-scoped group, `open()` keeps the route id; the side bar marks the parent list current for its tabs (`side-bar.ts`).
- [ ] `ui/src/app/shell/screen-outlet.ts` -- the four lists in `DESCRIPTOR_PAGES` → `CodeListPage`; regenerate `screens.generated.ts`.
- [ ] `ui/src/app/core/strings.ts` -- the keys, each `/** EXPERIENCE.md:595 */`.
- [ ] EXPERIENCE.md -- one Fixed-strings row after :594; :159 in place: "Classes · Routines · Search · Compare · Macros · SQL schemas · SQL tables · SQL views · SQL procedures; a table opens to its catalog tabs".
- [ ] `src/OcuPilot/Test/AtelierPortCatalog.cls` (new) -- through the fixture: each endpoint's exact `query`, `parameters` and `max`; every validation refusal before any route; the version gate; a soft SQL error → 500 with nothing sent.
- [ ] `src/OcuPilot/Test/AtelierPortCatalogLive.cls` (new) with `Test/ExplorerSqlProbe.cls` -- in USER, creates and drops schema `OcuProbe195` (a table with a primary key, an index, a trigger, a unique key and a foreign key; a second table; a view; a procedure; two delimited names that collide as `Schema.Table`): every matrix row live, cap and `truncated` through `Screen.Read`, and a purpose-built principal granted SELECT on one table only.
- [ ] `src/OcuPilot/Test/ExplorerCatalog.cls` (new) -- over HTTP `/screens/<Descriptor>/read` for a list and a tab; each tool through dispatch: rows only, `Code` past 1,000 in `truncatedFields`; arrival criteria accepted.
- [ ] `Test/AtelierPortDenial.cls`, `AtelierDenialProbe.cls` -- catalog legs refused without `%Development`, and without the namespace's READ.
- [ ] `Test/InjectionChannels.cls`, `InjectionSeed.cls` -- source (j): a probe trigger whose code carries the seed, read through `explorer.sqltriggers.read`.
- [ ] Rosters (Design Notes › Rosters).
- [ ] Client tests: `detail-page` spec (id kept across a parent-scoped group); `code-list.page.spec.ts` (a catalog list's System box and schema field); `ui/browser/system-explorer-sql.browser-spec.mjs` (new): Tables → open the probe table → Fields → Triggers keeps the table and shows the code as text; System toggle.
- [ ] `ui/angular.json`, `ui/tools/angular-json.test.mjs` -- re-base `maximumWarning` to the measured build (DW-1166); stop and ask above 3,800 kB.

**Acceptance Criteria:**

- AC1: Given probe objects in USER, when a person opens SQL schemas, SQL tables, SQL views and SQL procedures, then each lists the rows the instance answers for that account, system items only when System is chosen, bounded by the cap with the cut announced.
- AC2: Given a table in SQL tables, when the person opens it, then Table info, Fields, Maps/Indices, Triggers and Constraints show the classic page's catalog rows for it, and switching tabs keeps the table.
- AC3: Given any catalog read, when it executes, then `action/query` receives one of the port's fixed statements with every caller value only in `parameters`, and no `pFilter`.
- AC4: Given a principal granted SELECT on one probe table and nothing on another, when it reads the catalog, then the ungranted table is absent from SQL tables and each of its tabs answers not found.
- AC5: Given the agent's tools, when they are listed, then the nine `explorer.sql*.read` tools are advertised and answer bounded rows; a seeded trigger's code produces no proposal or navigation (AD-11 rule 5).
- AC6: Given classic parity (AD-44), when the descriptors are read, then each declares `%CSP.UI.Portal.SQL.Home`, and a custom resource on that page gates all nine.
- AC7: Given a `%Developer` account, when it opens the nine screens in USER, then it reads them, and is refused by name where it cannot read the code database (`DeveloperFloor`).
- AC8 (Integration, Rule 1): Given a row in SQL tables on the real instance, when the person opens it and switches to Triggers, then that tab reads the same table through its own declared read.

## Spec Change Log

- 2026-10-03, lead (spec gate, by=merge_gate): the split is approved as recommended: this story keeps the four lists and a table's Table info, Fields, Maps/Indices, Triggers and Constraints tabs; Story 19.14 (`19-14-the-sql-catalog-s-remaining-detail-tabs`, right after 19.5) takes the rest. The detail-tab privilege decision is accepted (a tab answers only for a table the caller's Tables list shows). The spine carries the drafts (AD-61 rules 2, 3, 6, 7, 8; AD-7's fifth shape; AD-36; AD-5). The plan's `deferred:` items are harvested: the `action/query` privilege bypass as DW-1963 (vendor-defect candidate) and DW-1964 (design constraint routed to 19.6, named in epics.md 19.6 and 19.11), the criteria description as a DW-1001 occurrence. `strings.test.mjs`'s Fixed-strings bound goes from 2100 to 2300 (approved by=merge_gate; whoever lands second takes the larger cap that covers the merged count and keeps Story 18.5's comment).

## Review Triage Log

## Design Notes

**The split (approved by=merge_gate 2026-10-03).** The epics.md criterion asks for every classic detail tab. `%CSP.UI.Portal.SQL.Home` has nine table tabs (Table Info, Fields, Maps/Indices, Partitions, Partition Mappings, Triggers, Constraints, Cached Queries, Table's SQL Statements), two view tabs and two procedure tabs (`Home.cls:473-488`). Full parity is 17 screens and 17 read tools, against 19.4's three, which already ran oversized. **Recommended split:**

- **19.5 (amended, this spec):** the four lists, and a table's Table info, Fields, Maps/Indices, Triggers and Constraints. That is nine screens. Amended AC1: "…schemas, tables, views and procedures list, and a table opens to its Table info, Fields, Maps/Indices, Triggers and Constraints tabs." AC2 is unchanged.
- **19.14 (new, `N.<M+1>`; key `19-14-the-sql-catalogs-remaining-detail-tabs`):** View info (`ViewInfo`, `ViewInfo2`, `ViewFields`) and View's SQL Statements; Stored procedure Info and its SQL Statements; a table's Partitions, Partition Mappings, Cached Queries and SQL Statements. That is nine screens on this spec's port family and tab mechanism. It carries the questions this split keeps out of 19.5:
  - `StatementIndex` answers other users' statement text, `USERNAME`, `CLIENTIP` and `CALLSTACK` to any `%Development` holder (`Catalog.cls:2258-2262`), and calls `CheckAggregateStats^%SYS.SQLSRV` (may write; inference).
  - `Partitions` fails the whole fetch with #31007 on a non-partitioned table.
  - `ProcedureInfo` declares `RETURN_VALUE` twice, so the route's object rows keep only the second.
  - A view's full SQL and a procedure's HTML description become row text.

**Measured on `ocupilot-a2-ci`, 2026-10-02.** Probe schema `OcuProbe195` and principals `OcuProbe195*` in USER were created and removed and checked gone. Statement-index rows for the probe statements remain on the throwaway.

- **`action/query`** prepares with `checkPriv` 0 (`v6.cls:229`):
  - `max` stops the fetch per result set (`v6.cls:384-386`), and only v6+ reads it.
  - A CALL's rows come back as strings, keyed by column name.
  - A SQL error answers 200 with `status.errors`, and rows already fetched are discarded.
- **Privileges:**
  - INFORMATION_SCHEMA filters every row by the caller's privileges, at either `checkPriv`.
  - `Schemas`, `TablesOnly` and `Fields` filter too.
  - `Indices`, `Triggers` and `Constraints` do not: an ungranted user read another table's trigger code.
  - At `checkPriv` 1, a non-`%All` caller gets -99 on every `%SQL_Manager` call; the route's `checkPriv` 0 is what lets such a caller run them.
  - A principal with `%DB_USER:R` alone (no WRITE) prepared and ran all three statement kinds.
  - A `%Developer` sees 73 tables in USER.
- **Input hazards:**
  - `pFilter` becomes a `?@` pattern (`GetFilters` :3912). Eight `*_` pairs ran over 30 s, and the process outlived the request.
  - `%schema` and `%table` are global subscripts: empty or 600 characters raised `<SUBSCRIPT>`.
  - `Fields` subscripts are case-exact (:657).
  - Hence the bounds on the inputs, and the exact names from the resolve.
- **Cost (HSCUSTOM, `%All`):**

  | Read | Rows | Time |
  |---|---|---|
  | `Schemas(0)` | 637 | 0.11 s, 163k global references |
  | INFORMATION_SCHEMA.TABLES, whole namespace | 2,066 | 0.043 s |
  | `TablesOnly(HS_Message)` | — | 0.006 s |
  | `Fields`, a 141-column table | 141 | 0.016 s |
  | `Indices`, `Triggers`, `Constraints` | — | under 0.005 s each |

  For a non-`%All` caller, privilege checks dominate: 0.059 s for 3 rows.
- **Counts (HSCUSTOM):**

  | | System off | System on |
  |---|---|---|
  | Tables | 1,484 in 230 schemas | 2,055 |
  | Views | 0 | 11 |
  | Procedures | 5,429 | 6,510 |

  The largest schema holds 195 tables, under the 1,000 cap.

**Decisions.**

- *Route.* `action/query` with port-owned statements, so Atelier carries every call and AD-61 needs no named case. It is safe without 19.6's guard because no caller text reaches `query`. AC3's fixture leg pins that.
- *Gate.* The port's pairs alone (`%Development:USE`, the namespace's READ pairs), as `Home.cls:22`'s `%Development`. Rows are filtered by the vendor's own privilege checks.
- *Detail tabs answer only what the caller's Tables list shows.* The INFORMATION_SCHEMA resolve is stricter than the classic page. The classic tabs, given any name, read `Indices`, `Triggers` and `Constraints` unfiltered. An agent can name any table, so this is the safer default (decision for the spec gate).
- *Not carried:*
  - The classic Deprecated box: INFORMATION_SCHEMA marks no deprecated items, so deprecated tables list.
  - The classic tree's pattern filter (hazard above). The table's own filter box and `schema` serve instead.
  - `Fields`' data-value columns.
- *Entity type `class`:* a table is a class's projection. 19.2's class change events re-fetch these screens (AD-14), and `EntityType.cls` (contended) is untouched.
- *Ids:* the Tables list's id is `Table`, `TABLE_SCHEMA.TABLE_NAME`, one AD-13 segment. A tab's `table` is that value.

**Statements** (`max` the read's `maxRows`; `?` bound in order):

| Endpoint | `query` | Fields |
|---|---|---|
| `Catalog.Schemas` | `CALL %SQL_Manager.Schemas(?)` (system 0/1) | `Schema`, `Tables`, `Views`, `Procedures` |
| `Catalog.Tables` | `SELECT TABLE_SCHEMA, TABLE_NAME, CLASSNAME, OWNER, IS_SHARDED, IS_PARTITIONED FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE IN ('BASE TABLE', ?) AND (? = '' OR TABLE_SCHEMA = ?)` | `Table`, `Schema`, `Name`, `Class`, `Owner`, `Sharded`, `Partitioned` |
| `Catalog.Views` | `SELECT TABLE_SCHEMA, TABLE_NAME, CLASSNAME, OWNER, IS_UPDATABLE, CHECK_OPTION FROM INFORMATION_SCHEMA.VIEWS WHERE (? = 1 OR (TABLE_SCHEMA NOT %STARTSWITH '%' AND TABLE_SCHEMA <> 'INFORMATION_SCHEMA')) AND (? = '' OR TABLE_SCHEMA = ?)` | `View`, `Schema`, `Name`, `Class`, `Owner`, `Updatable`, `CheckOption` |
| `Catalog.Procedures` | the same over `INFORMATION_SCHEMA.ROUTINES` (`ROUTINE_SCHEMA`, `ROUTINE_NAME`, `ROUTINE_TYPE`, `CLASSNAME`, `METHOD_OR_QUERY_NAME`), never `ROUTINE_DEFINITION` | `Procedure`, `Schema`, `Name`, `Type`, `Class`, `Method` |
| resolve (`max` 2) | `SELECT TABLE_SCHEMA, TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE IN ('BASE TABLE', 'SYSTEM TABLE') AND TABLE_SCHEMA \|\| '.' \|\| TABLE_NAME = ?` | — |
| `Catalog.Table` | `CALL %SQL_Manager.TablesOnly(?, 0)`, kept to the resolved row | `Name`, `Owner`, `LastCompiled`, `External`, `ReadOnly`, `Partitioned`, `Class`, `ExtentSize`, `ExternalType` |
| `Catalog.Fields` | `CALL %SQL_Manager.Fields(?, ?)` | `Field`, `Type`, `Column`, `Required`, `Unique`, `Collation`, `Hidden`, `MaxLength`, `MinValue`, `MaxValue`, `Stream`, `XdbcType`, `ReferenceTo`, `VersionColumn`, `Selectivity` |
| `Catalog.Indices` | `CALL %SQL_Manager.Indices(?, ?)` | `Index`, `Map`, `Fields`, `Type`, `BitmapArgument`, `SizeMB`, `Inherited`, `Global`, `Status` |
| `Catalog.Triggers` | `CALL %SQL_Manager.Triggers(?, ?)` | `Trigger`, `Event`, `Order`, `Code` |
| `Catalog.Constraints` | `CALL %SQL_Manager."Constraints"(?, ?)` (a reserved word) | `Constraint`, `Type`, `Data` |

Each list's `table` has one `name` column (the qualified name), `emptyNextKey` `tableReadOnlyEmptyNext`, sort by the qualified name, filter on name, `Schema` and `Class`. Each tab's name column is its first field. Context fields equal the table's columns.

**Spine amendments for the spec gate (draft).**

- **AD-61:**
  - rule 2: `Query` needs version 6, the first to read `max`.
  - rule 3: a catalog body is `{query, parameters}`. `query` is one of the port's fixed statements, and `parameters` holds the validated caller values. A tab's names come from the privilege-filtered information-schema row.
  - rule 6: a SQL error answers 200 with `status.errors`, so it is 500 `INTERNAL`, logged and never sent.
  - rule 7: no caller text in `query` and no catalog `pFilter` (an ObjectScript pattern whose backtracking ran past 30 s, measured). The route prepares any statement with privilege checks off (measured: SELECT and UPDATE on an ungranted table), so its open use waits for 19.6's guard.
  - rule 8: the measured costs above.
  - Rule 5 per Task 0.
- **AD-7, a fifth shape:** "the SQL statement index entry and cached query a prepared statement records". Measured: a READ-only principal's first prepare of a new statement added a statement-index row. Each fixed statement records one per namespace, once (inference).
- **AD-36:** "A row may carry a trigger's code (Story 19.5), as a search match does."
- **AD-5:** "A tab group may be parent-scoped (Story 19.5). Every member names the same `parentScope` and one criterion, the head is the parent list's `<route>/document`, and the strip carries the route id. Validated alike by `Screen/Registry.cls` and `ui/tools/screen-mirror.mjs`."
- **AD-11 rule 5:** source (j), a trigger's code.

**Strings** (one row, :595). The ten port reasons:

- Inputs: "schema must be 1 to 128 characters, with no control character."; "system must be yes or no."; "Name one table, as Schema.Table."
- Resolve: "That name matches more than one table in this namespace."; "This namespace holds no table by that name that this account can see."

Also: four side-bar labels ("SQL schemas", "SQL tables", "SQL views", "SQL procedures"), five tab labels, the column headers above, two criteria labels (reuse 19.1's System items key), nine empty states, 27 prompts (group Code).

Estimate (inference): about 150 strings against 28 of headroom under `strings.test.mjs:577`'s 2,100. Raising the bound is a not-add-only edit: lead approval.

**Rosters** (verify each at edit time):

- `ExplorerDescriptor`: `DESCRIPTORS` :15, listed :31, reads :42, the tool literal and method name :123-138 (cited by `SurfaceCoverage` :287-294).
- `ReadTool`: 218→227 :93, names :94, pairs :112, criteria descriptors 23→32 :368.
- `ToolRoundTrip` `REFUSEEMPTY` :61: the five tabs, `PORT.VALIDATION`.
- `SurfaceCoverage`: nine rows after :158. `Descriptor` `ReadShapes`: nine rows after :138.
- `DeveloperFloor`: `SCREENS` 15→24 :33, `TOOLS` 14→23 :36, reads :237, the count words at :9, :416 and :439.
- `screen-mirror.test.mjs` `withCriteria` :1249-1276 and atelier :2621-2641.
- `navigation.test.mjs` :255-266, `navigation-wire.test.mjs` :552-590, `rail-wire.spec.ts` :557-590 and :660-661.
- `self-protection.test.mjs` `FIND_REFUSALS` :536-541.

**Consumes:** `Route`, `Outcome`, the gate, `CodeListPage`, `DetailPage`, `ListPage`, `Screen.Read`. **Consumed-by:**

- 19.14: the port family and the tab mechanism.
- 19.7 and 19.8: the data browser's schema tree and column metadata, through these reads (AD-5's page-issues-another-read).
- 19.6 and 19.11: the `Query` route plumbing, behind their guard.

**ADs.** AD-5, AD-7, AD-8, AD-11, AD-13, AD-14, AD-16, AD-21, AD-24, AD-29, AD-36, AD-39, AD-44, AD-60, AD-61.

**Footprint (Rule 11).** Checked 2026-10-02 against `.worktrees/epic-18` at `71e24556d9b041a2f354275097ba2345e36b90ca`, committed and uncommitted.

- **Contended, add-only:**
  - `ToolRoundTrip`, `SurfaceCoverage` and `Descriptor` rows.
  - `screen-outlet.ts`.
  - `navigation.test.mjs`, `navigation-wire.test.mjs`, `rail-wire.spec.ts`, `screen-mirror.test.mjs` (System Explorer blocks).
  - `strings.ts` (keys at the Explorer block's end).
  - EXPERIENCE.md :159 in place and a row after :594 (Epic 18 edits :164 and :378).
  - `screens.generated.ts` (regenerated).
- **Contended, not add-only (lead approval):** `ReadTool` :93/:94/:368; `angular.json` with `angular-json.test.mjs`; the spine.
- **Not contended, not add-only (lead approval per the epic context):** `strings.test.mjs` :577.
- **Not contended:** `AtelierPort.cls`, `Registry.cls`, `screen-mirror.mjs`, `detail-page.ts`, `side-bar.ts`, `navigation.ts`, `ExplorerDescriptor`, `DeveloperFloor*`, the `Atelier*` tests, the `Injection*` tests.

Re-check both diffs at edit time.

**Ledger inbox:** none owned. DW-1001 occurrence in `deferred:`.

## Verification

Load source into `ocupilot-a2-ci` and never restart it:

1. `rsync -a --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-19/src/ /tmp/ocupilot-a2-ci/src/`
2. In `docker exec -i ocupilot-a2-ci iris session iris -U HSCUSTOM`, run `$System.OBJ.LoadDir("/opt/ocupilot/src","ck",.tErrors,1)`, then check the status and `tErrors`.

**Run one test-runner call at a time, and wait for each.** Never re-submit after a client-side timeout. Every `OcuProbe195*` object and principal is removed.

**Commands:**

- `uv run scripts/check-objectscript.py && uv run scripts/test_check_objectscript.py` (loop) -- expected: green.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-a2-ci --class OcuPilot.Test.<Class>` (loop), one class per call -- expected: green. Run it for:
  - `AtelierPortCatalog`, `AtelierPortCatalogLive`, `ExplorerCatalog`, `AtelierPortDenial`, `AtelierPort`, `ExplorerDescriptor`, `ExplorerWire`;
  - `ReadTool`, `ToolRoundTrip`, `SurfaceCoverage`, `Descriptor`, `DeveloperFloor`, `DeveloperFloorRoutes`, `InjectionChannels`, `CriteriaCorpus`.
- `cd ui && npm run test:tools && npx ng test --include 'src/app/areas/system-explorer/**/*.spec.ts' --include 'src/app/shell/**/*.spec.ts'` (loop) -- expected: green.
- Browser (loop). Build and deploy first: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-a2-ci:/durable/iris/csp/ocupilot/`. Then run each file alone with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52780 OCUPILOT_BROWSER_CONTAINER=ocupilot-a2-ci node --test --test-concurrency=1 browser/<file>`, for `system-explorer-sql.browser-spec.mjs`, `system-explorer.browser-spec.mjs` and `a11y-structural-invariants.browser-spec.mjs` -- expected: green. The full browser suite is CI's.
- `bash scripts/lint-docs.sh && cd ui && npm run test:tools` (loop, after the EXPERIENCE.md edit) -- expected: green.
- `cd ui && npm test` (once, before dev_complete) -- expected: green, with the budget re-based.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-a2-ci`, the full ObjectScript sweep, one class at a time (once, before dev_complete) -- expected: green apart from the known `WireSecurityRead` (DW-1554) and `Retention` (DW-1929) residue.

**Planned mutations (Rule 19)**, one per AC:

- AC1: `Catalog.Tables` binds `system` as always `SYSTEM TABLE` → the live system leg.
- AC2: `Catalog.Fields` binds schema and table swapped → the live Fields leg; `open()` dropping the id again → the detail-page spec and the browser Triggers leg.
- AC3: `query` built with the schema spliced in → the fixture exact-body leg.
- AC4: the resolve skipped for `Catalog.Triggers` → the principal's Hidden-trigger leg.
- AC5: `Bound.Apply`'s per-field cut skipped → the `ExplorerCatalog` bound leg.
- AC6: `ExplorerSqlTriggers` `classicPage` `""` → `ExplorerDescriptor`.
- AC7: `ExplorerSqlTables` privileges `[]` → `DeveloperFloor` and the denial leg.
- AC8: the Tables name cell linking to the list itself, rebuilt and redeployed → the browser open leg.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

- This pass: the plan only. Everything below the intent is written for the recommended 19.5 scope. With the split approved and epics.md amended, the spec gate can set `ready-for-dev` once it has ruled on the four spine drafts and the detail-tab privilege decision.
- For the lead: `deferred:` carries the measured `action/query` privilege bypass (checkPriv 0: SELECT and UPDATE on an ungranted table), design input for 19.6 and 19.11. The approvals this scope needs are the strings bound and the `angular.json` budget.
