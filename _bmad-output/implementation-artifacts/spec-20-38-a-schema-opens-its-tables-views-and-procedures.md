---
title: 'Story 20.38: A schema opens its tables, views and procedures'
type: 'bugfix'
created: '2026-10-23'
status: 'draft'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** On the SQL schemas list, a schema's name links to the list's own id route, `system-explorer/sql-schemas/<schema>`. That route shows the list again with the row selected. The address and the breadcrumb change, and no schema screen opens. Nothing stops other lists from linking a name to nowhere in the same way.

**Approach (as the runner ruled on 2026-10-23; see Design Notes, Runner's rulings):**

- A schema opens a parent-scoped tab group at `system-explorer/sql-schemas/document/<schema>`, in Story 19.5's shape, with the tabs Tables, Views and Procedures. Each tab lists every object in its schema, system ones included, through the existing `AtelierPort` catalog statements with the system flag bound on, and each object's name opens its existing screen.
- A client test fails whenever a built list's name cell links back to its own list, except for an exact allow-list of the 17 other lists Story 20.39 fixes.

## Boundaries & Constraints

**Always:**

- Each screen has one descriptor, and each tab one descriptor (AD-5).
- The schema is the route id, encoded by the shared pair (AD-13).
- The catalog reads extend `AtelierPort`'s fixed statements and gate (AD-61, Rule 31).
- The tab names "Tables", "Views" and "Procedures" and the breadcrumb "SQL schemas › <schema>" are fixed by the story. The empty-tab sentences are the runner's ruling: "This schema has no SQL tables.", "This schema has no SQL views." and "This schema has no SQL procedures."
- `ui/tools/screen-mirror.mjs` and `src/OcuPilot/Screen/Registry.cls` take add-only edits only (the orchestrator reserves them to Story 23.12 for anything else).

**Never:**

- No new agent action or write.
- No change to what the SQL tables, views and procedures screens show on their own.
- No stored data, installer, start path, `module.xml` or compose change.
- No schema editing.
- No AD amended in-stage.

## I/O & Edge-Case Matrix

The rows follow the runner's rulings.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Open a schema | Click `Ens` on SQL schemas | The schema screen at `sql-schemas/document/Ens` (Q1), with the breadcrumb SQL schemas › Ens | - |
| A tab of a kind the schema holds | The Procedures tab of `Ens` | Ens's procedure rows; a name opens that procedure's screen | - |
| A tab of a kind the schema lacks | The Views tab of `Ens` (no views on `ocupilot-b-ci` or `ocupilot-slot-b`) | "This schema has no SQL views." | - |
| A system schema | `%Library`, opened from the list with System items on | Its objects show, whatever the System box says | - |
| The caller lacks the pairs | No `%Development:USE` | The tab is refused, naming the pair | AD-29 refusal, never an empty list |

</intent-contract>

## Code Map

All paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-20`. Lines were read at `0e929fa6fb9de8b240c4fae4a989a0a8121a7686`.

- `src/OcuPilot/Screen/Descriptor/ExplorerSqlSchemas.cls`: the list. Schema is a `name` column, the id is `single` and there is no `rowTarget`. Its page is `CodeListPage` (`ui/src/app/shell/screen-outlet.ts` :211).
- `ExplorerSqlTables.cls`, `ExplorerSqlViews.cls`, `ExplorerSqlProcedures.cls`: the reads the tabs extend, each with the `system` and `schema` criteria.
- `ExplorerSqlTable.cls` (head, `sql-tables/document`, `tab` position 1) and `ExplorerSqlFields.cls`: Story 19.5's parent-scoped group, which is the sibling grammar (Rule 31).
- `src/OcuPilot/Port/AtelierPort.cls`: :166-174 holds the catalog statements, and :1290-1330 binds `system` and `schema`.
- `src/OcuPilot/Screen/Registry.cls`: :232 (a unique tool identifier), :363 (a unique route), :712-797 (`TabGroupProblem`), :1610-1612 (the read tool's name), :1772-1787 (one criterion on a parent-scoped read).
- `ui/tools/screen-mirror.mjs`: :2052 and :2710-2763, the mirror's twins of those checks.
- `ui/src/app/shell/data-table.ts` :671-725: the name cell's link chain. The fallback to the list's own route is at :701.
- `ui/src/app/core/navigation.ts`: :240-330 (the paired surfaces) and :783-803 (`withQuery` carries only `ns`).
- `ui/src/app/app.routes.ts` :82-109: the route table and the `<route>/:id` routes.
- `ui/src/app/shell/list-page.ts`: :69-80 and :238-255. A list opened on its own id selects that row (DW-1419).
- `ui/src/app/shell/locator-bar.ts` :347-378.
- `ui/src/app/areas/logs/audit.page.ts` :303-318: the detail dialog for whatever row the id names.
- `ui/browser/system-explorer-sql.browser-spec.mjs`: the browser sibling.
- `/private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/eae04a03-b589-4d2f-8258-acd58fae0712/scratchpad/e20u/20-38/plan/hits.mjs`: the read-only scan behind Q4. Run it from `ui/`.

## Tasks & Acceptance

**Execution:** the re-plan writes the tasks from the runner's rulings.

**Acceptance Criteria:** these are the story's ACs (`epics.md`, Story 20.38, amended 2026-10-23 per the rulings); the re-plan restates them:

- Given the SQL schemas list, when a schema's name is clicked, then the schema's own screen opens with the tabs Tables, Views and Procedures:
  - each tab lists that schema's objects through the existing reads;
  - each object's name opens its existing screen;
  - the breadcrumb reads SQL schemas › <schema>.
- Given a tab of a kind the schema lacks, when it opens, then it says so plainly.
- Given the agent on the schema's screen, when it reads the screen, then its context and tools are the tab's own read, scoped to the schema, and no agent action is added.
- Given every built list whose name column links somewhere, when the client tests run, then a test fails for any link to a route with no built screen to show it.
- Given the browser suite, when a schema name is clicked, then the schema's screen opens, its Procedures rows show, and one procedure opens.

## Design Notes

- **Governing ADs (Rule 6):**
  - AD-5: a descriptor per screen, tab groups and the paired surfaces.
  - AD-13: one id segment, and the list's own id route.
  - AD-24: the screen context's `tools`.
  - AD-36: one declared read per screen and tool.
  - AD-44: `classicPage` is `%CSP.UI.Portal.SQL.Home`.
  - AD-61: `AtelierPort`'s fixed statements and gate.
  - AD-29: the port is the gate.
  - AD-19: client state lives in the store.
- **Rule 31 siblings:** Story 19.5's SQL table group for the tab grammar, and the three list reads and their statements for the reads. Under Q2's Option A, the reads extend in the port, and the descriptors are new declarations over the same endpoints.
- **Integration (Rules 1 and 2):** no service is introduced. Consumes: Epic 19's SQL catalog reads and screens. Consumed-by: none planned.
- **Upgrade triggers:** none under any option. Nothing touches `Kernel/State/**`, any `%Persistent` class, `Install/**`, the start path, `module.xml` or compose.
- **Contention (Rule 11):**
  - Epic 23's branch differs from feature only in five `_bmad-output` files, and its worktree is clean (read-only `git diff --stat` and `git status -s`).
  - The recommended plan touches neither `Screen/Tool/Read.cls` nor `Kernel/Agent/Prompt.cls`.
  - Q4 rows 10, 12 and 13 would touch the database and task descriptors.
- **Ledger inbox (Rule 17):** none.
- **Runner's rulings (2026-10-23, unattended; recorded in the run's log, the veto items in the owner's inbox):**
  - **Q1, the address (veto):** Option A. The schema screen is a parent-scoped group at `system-explorer/sql-schemas/document/<schema>`, in Story 19.5's shape (head at `sql-schemas/document`, the other tabs at `sql-schemas/views` and `sql-schemas/procedures`, parentScope `system-explorer/sql-schemas`). The list's own id route keeps selecting the row. AD-5 is complied with, not amended. `epics.md` 20.38's first AC is amended to that URL.
  - **Q2, System items (veto):** Option A. Each tab lists every object in its schema, system ones included, and shows no System control of its own: the flag is bound on in `AtelierPort`, over the existing statements and column maps (Rule 31: extend, never a new statement), with `schema` required. The three existing list screens are unchanged. `epics.md` 20.38's "carried over" bullet is amended to say so.
  - **Q3, tools (decide):** the three tab reads are the "tabs' own reads" the AC names, so their three read tools are allowed. No write, row action or primary action is added. The epic context's "no new tool" is read as "no new agent action".
  - **Q4, the bug-class check (decide, split within `limits.split_children`):** this story builds the schema screen and the check. The check holds rows 2-18 of the table under Plan findings in a named, exact allow-list, so a fix that leaves its row in place, or a new self-link, turns it red. Story 20.39 ("Every list's name opens something", chartered in `epics.md`) fixes rows 2-18 after Story 23.12 merges. The seven non-defects (two dialog editors, three detail dialogs, two that never draw the table) are a declared set, not allow-list rows. The shared table's fallback (`data-table.ts` :701) is not changed in this story.
  - **The empty-tab sentences (veto):** "This schema has no SQL tables.", "This schema has no SQL views." and "This schema has no SQL procedures." The existing list sentences ("No SQL views in <NAMESPACE> match.") are not reused: a schema tab has no visible filter, and "match" would name one. Add them to `strings.ts` beside `explorerSqlTablesEmpty` and its siblings, and to EXPERIENCE.md's fixed strings if the sibling sentences are listed there.
  - **The AC's Ens example** is corrected at origin: Ens holds tables (26) and procedures (44) but no views (measured on `ocupilot-slot-b` and `ocupilot-b-ci`). The browser spec may use `Ens` for both a Procedures row and the empty Views tab.
- **Contention ruling from the orchestrator (2026-10-23, from Story 23.12's plan):**
  - 23.12 adds a `row` line to each of the 157 read-declaring descriptors and a `label` line to 35 of them (add-only), modifies `ui/tools/screen-mirror.mjs` (allowed read keys, a new validator, and generating a new `src/OcuPilot/Screen/Titles.cls` from `strings.ts`) and `src/OcuPilot/Screen/Registry.cls` (allowed keys, a validator), regenerates `screens.generated.ts` and `Titles.cls`, and adds a roster test, `ReadDescriptions`, that fails on any production read without a title, a `row` and fields, or any confusable-group tool without its `label`.
  - `screen-mirror.mjs` and `Registry.cls` are reserved to 23.12 for non-add-only edits. This story may only add to them. If it needs more there, the implement stage HALTs with `intent gap` naming the edit, and the runner asks the orchestrator first.
  - If 23.12 merges first, the runner's integrate-forward gives each new read descriptor its `row` line (and a `label` where 23.12's rules call for one), regenerates with `node tools/screen-mirror.mjs`, and pushes that merge alone. If this story merges first, 23.12 adds them on its side.
  - The link check and its fixes are this story's. 23.12's `row` and `label` lines in the same descriptor files are add-only, so they union plainly.

## Plan findings (answered: see Design Notes, Runner's rulings)

The first plan pass stopped on an `intent gap` with the four questions below; the runner ruled on each on 2026-10-23. The evidence stays here because the Q4 table is the allow-list's source.

### Q1: the schema screen's address (AD-5)

AD-5's Rule: "A tab group may be parent-scoped: every member names the same `parentScope` and its one criterion, the head is the parent list's `<route>/document`, and the tab strip carries the route id from tab to tab, validated alike by `Screen/Registry.cls` and `ui/tools/screen-mirror.mjs` (a SQL table's catalog tabs, Story 19.5)."

Measured:

- `system-explorer/sql-schemas/<schema>` is the schemas list's own id route. It serves the list's page and selects the row (AD-13, DW-1419), which is the defect the owner saw.
- No second descriptor can declare that route (`Registry.cls` :363).
- A parent-scoped group with any head other than `<route>/document` is refused (`Registry.cls` :788, `screen-mirror.mjs` :2763).

The options:

- **Option A (recommended): amend the AC's URL to `system-explorer/sql-schemas/document/<schema>`.**
  - The group takes Story 19.5's shape. Tables heads it at `sql-schemas/document`, with Views at `sql-schemas/views` and Procedures at `sql-schemas/procedures`, all with parentScope `system-explorer/sql-schemas`.
  - The list's name cell already links to a built `<list route>/document` (`documentScreenFor`, `data-table.ts` :693-701), so no shell code changes.
  - With the head labeled "SQL schemas", the locator reads "System Explorer › SQL schemas › <schema>".
  - The list's own id route keeps selecting the row for the agent's `shell.screen.open`.
- **Option B: amend AD-5 so that the exact URL works.** Proposed text: "A parent-scoped group's head may instead answer its parent list's own id route, `<route>/<id>`, which then opens the head rather than selecting the row; its other tabs stay at `<route>/<tab>`." The cost: the route table, `screenForUrl`, `ownIdSegment`, the locator, screen-context capture and the agent's open-on-id all change what that route means. Both engines' validation changes too (inference, from the call sites in the Code Map).

### Q2: carrying the System items criterion over (AD-5)

AD-5's Rule gives a parent-scoped group "its one criterion". Both engines refuse a parent-scoped read that declares more than one: "a parent-scoped read declares exactly one read.criteria field, which its route id fills" (`Registry.cls` :1772-1787, `screen-mirror.mjs` :2052). So a tab cannot carry `system` beside `schema`.

It matters because, with `system` set to `no`, the views and procedures statements drop every `%` and `INFORMATION_SCHEMA` schema, and the tables statement drops `SYSTEM TABLE` rows (`AtelierPort.cls` :170-174 and :1308-1318). A system schema opened from the list with System items on would show empty tabs. A name-cell link carries only `ns`.

- **Option A (recommended): the tabs read their schema's objects whatever the System box says, and show no System control of their own.** The schema already narrows the set, so the flag only decides whether a system schema's own objects show.
  - Built as three `AtelierPort` endpoints over the existing statements and column maps, with the flag bound to 1 and `schema` required. No new statement is written, and the three list screens are unchanged.
  - This reads "carried over" as "a system schema opened from the list still shows its objects".
- **Option B: amend AD-5 to let a parent-scoped read declare further `choice` criteria with defaults.** Each tab shows them, and they are carried from the parent list. Both engines' criteria checks, `parentCriteria` and the search store change.

### Q3: "no new tool" against one read per tab (AD-5, AD-36)

AD-5's Rule says "Each tab carries its own primary entity type, read, tool and privilege set". AD-36's Rule says "A screen's list and its read tool resolve through **one** descriptor-declared read".

- A built read is the tool `<toolIdentifier>.read`, and every identifier is unique (`Registry.cls` :232 and :1610-1612). So three tabs are three new read tools.
- On each tab, the screen context's `tools` names that tab's own read (AD-24).
- The story's AC says "no new agent action". The epic context and this dispatch say "no new agent action, tool or write".

**Recommended ruling:** the three tab reads are "the tabs' own reads" the AC asks for, so they are allowed. No write, row action or primary action is added. Without this ruling, the AC cannot be met under AD-5 and AD-36.

### Q4: the bug-class check finds 18 lists (dispatch guard)

Measured over the mirror with the shared table's own link chain (`data-table.ts` :693-701, the scan in the Code Map):

- Of 209 built screens, 152 draw a `name` column. 70 render it as text, 57 open a paired surface, and 25 link to their own id route.
- Seven of those 25 are not defects:
  - ResourceList and AuditUserEventList are `DIALOG_EDITORS`.
  - AuditList, JournalRecordList and TaskHistoryList open a detail dialog on their id.
  - LicenseKey and OpenApiViewer never draw the table.

The other 18 change the address and stay put, or they open the wrong thing:

| # | List (route · name field) | Today | Proposed |
|---|---|---|---|
| 1 | `system-explorer/sql-schemas` · Schema | the list again | the schema screen (this story) |
| 2 | `system-explorer/classes/document` · Name (Structure) | opens a document named after the member | text |
| 3 | `system-explorer/routines/document` · Name | the viewer again | text |
| 4 | `permissions/sql-privileges` · Object | an "Audit event" dialog with no data (inference: `AuditPage` serves every `list (server criteria)` screen that has no page of its own, `audit.page.ts` :303-318) | **choice:** the object's table, view or procedure screen, or text |
| 5 | `permissions/sql-column-privileges` · Column | the same dialog (inference) | text |
| 6 | `permissions/sql-admin-privileges` · Privilege | the same dialog (inference) | text |
| 7 | `web-applications/list/class-access` · Name | the same dialog (inference) | **choice:** the class's document viewer, or text |
| 8 | `security/auditing/system-events` · EventName | leaves Auditing configuration for the bare list | text |
| 9 | `security/allowed-directories` · Directory | the list again | text |
| 10 | `os-management/database-free-space` · Directory | the list again | **choice:** the database's own screen, or text |
| 11 | `os-management/ecp-application-servers/ssl` · SSLComputerName | the tab again | text |
| 12 | `tasks/on-demand` · Name | the list again | Task details (obvious), through a `rowTarget` on the task descriptor |
| 13 | `tasks/upcoming` · Name | the list again | Task details (obvious), the same way |
| 14 | `tasks/background` · Task | the list again | text |
| 15 | `system-explorer/docdb` · Name | the list again | **choice:** text, or a database screen |
| 16 | `interoperability/business-partners` · Name | the list again | **choice:** text now, or a partner screen with Story 20.26 |
| 17 | `analytics/folder-items` · Name | the list again | **choice:** the item's vendor page (Story 20.32's links), or text |
| 18 | `agent/screenpermissions` · Screen | the list again | **choice:** the named screen, the adjust dialog, or text |

Rows 10, 12 and 13 would edit the database and task descriptors, whose labels Story 23.12 changes. That is a non-add-only edit to a contended file.

- **Recommended split:** 20.38 keeps the schema screen and the check. The check holds rows 2-18 in a named allow-list and asserts it exactly, so a fix that does not remove its row turns red, and so does a new self-link. A sibling story, chartered by the runner after 23.12 merges, fixes rows 2-18 with the owner's rulings on rows 4, 7, 10, 15, 16, 17 and 18.
- **Alternative that keeps one story:** the shared table stops linking a name to its own list. The fallback at `data-table.ts` :701 is dropped, and a declared set names the pages that open their own id (the seven above). All 17 rows then become text at once, with no descriptor edit, and targets for the choice rows come later. Because this changes 17 screens in one line, it is a ruling for the runner, not a plan-stage choice.

### Also for the re-plan

- **The AC's example is wrong on this instance.** `ocupilot-b-ci`'s `CALL %SQL_Manager.Schemas(0)` answers `Ens` with TABLE_EXISTS 1, VIEW_EXISTS 0 and PROCEDURE_EXISTS 1, and `INFORMATION_SCHEMA.TABLES` holds 26 `BASE TABLE` rows under `Ens` (measured read-only). So Ens holds tables and procedures but no views, and the empty-tab example is Ens's Views tab. The browser spec can use `Ens` for both a Procedures row and an empty tab.
- **Proposed empty-tab sentence:** reuse the existing sentences ("No SQL views in <NAMESPACE> match.", `strings.ts` :5021-5025). Not taken: see the runner's rulings.

## Spec Change Log

- 2026-10-23, runner, after the first plan pass's `intent gap`: ruled Q1-Q4 and the empty-tab sentences (Design Notes, Runner's rulings); recorded the orchestrator's contention ruling; amended `epics.md` Story 20.38's ACs (address, System items, the Ens example, the split) and chartered Story 20.39; status reset to `draft` for the re-plan.

## Verification

Shared surfaces, under the recommended options:

- the screen mirror;
- the tab-group and criteria corpora (`TabCorpus`, `CriteriaCorpus`);
- the read-tool rosters (`ReadTool`, `ToolRoundTrip`, `SurfaceCoverage`);
- `AtelierPort`'s endpoint roster;
- every list whose name cell changes under Q4.

Every test added or changed passes on a fresh environment, in either order. The commands are written once Q1-Q4 are ruled on, in Rule 29's shape on `ocupilot-b-ci`.

## Auto Run Result

Status: blocked
Blocking condition: intent gap

Planning only, with no code changed. Q1-Q3 each need a ruling against an AD-5 or AD-36 Rule, and Q4 needs a split ruling and seven product choices. The recommendations are: Q1 Option A, Q2 Option A, Q3 allow the tab reads, and Q4 split with an exact allow-list.
