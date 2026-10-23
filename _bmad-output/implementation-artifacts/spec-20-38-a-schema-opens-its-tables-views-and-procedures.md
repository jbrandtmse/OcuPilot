---
title: 'Story 20.38: A schema opens its tables, views and procedures'
type: 'bugfix'
created: '2026-10-23'
status: 'done'
baseline_revision: '8c9c61f5d7863a34d3b14ab724a8f9f492fc04bb'
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

All paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-20`. Lines were read at `145fea3e1a3ff7800400557557ea645169cceff4`; source is unchanged since `0e929fa6fb9de8b240c4fae4a989a0a8121a7686`.

- `src/OcuPilot/Port/AtelierPort.cls`: the catalog endpoints (:101-112), the list statements (:166-174) and column maps (:227-233), `REASONCATALOGSCHEMA` (:637, "schema must be 1 to 128 characters, with no control character."), `IsCatalog` (:1224), `CatalogStatement` (:1231), `CatalogColumns` (:1238) and `CatalogRows` (:1268). The list branch reads `system` and `schema` at :1292-1304 and binds them at :1306-1317. `MinVersion` (:793) gives every catalog endpoint the `Query` route's version.
- `src/OcuPilot/Screen/Descriptor/ExplorerSqlTables.cls`, `ExplorerSqlViews.cls`, `ExplorerSqlProcedures.cls`: the reads, columns, context and prompts the tabs reuse. They are not edited.
- `ExplorerSqlTable.cls` and `ExplorerSqlFields.cls` (Story 19.5), `ExplorerSqlView*.cls`, `ExplorerSqlProcedure*.cls` (Story 19.14): the parent-scoped group grammar. The cube Relationships tab (Story 20.11) is the precedent for a `rowTarget` on a tab.
- `ExplorerSqlSchemas.cls`: the list. It is not edited, because its name cell picks up the new head through `documentScreenFor` (`ui/src/app/core/navigation.ts` :306).
- `ui/src/app/shell/data-table.ts` :685-701: the name cell's link chain, with `rowTarget` first and the list's own route last.
- `ui/src/app/core/navigation.ts`: `DIALOG_EDITORS` (:289) and `hasIdRoute` (:658).
- `ui/tools/screen-mirror.mjs` :2844 and :2993: the `rowTarget` checks. They admit a `detail` tab with a table, and refuse a screen that already pairs its own surface. `Registry.cls` :712-797 holds `TabGroupProblem`.
- `src/OcuPilot/Test/ExplorerSqlProbe.cls`: the `OcuProbe195` objects in `USER`, with `Make` at :103 and `Remove` at :225. The schema holds tables, views and the procedure `OcuProbe195.Echo`.
- `ui/browser/system-explorer-sql.browser-spec.mjs`: the browser sibling. It uses the helpers `recordReads`, `rowShowing` and `openTab`, and `filterToSubset` and `clickRowCentre` from `list-spec.mjs`.
- `ui/browser/structural-walk.mjs`: walks every built screen at run time, so CI's a11y spec opens the new tabs from the schemas list's first row.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Port/AtelierPort.cls`
  - Add the endpoints `Catalog.SchemaTables`, `Catalog.SchemaViews` and `Catalog.SchemaProcedures` beside the list endpoints.
  - Each resolves its statement and column map through the list it extends: `Catalog.Tables`, `Catalog.Views` or `Catalog.Procedures`. Add no statement text and no column-map text. `IsCatalog`, `CatalogStatement` and `CatalogColumns` answer them.
  - In `CatalogRows`, these three never read `system` and bind the flag on (`SYSTEM TABLE` for tables, `1` for views and procedures).
  - `schema` is required. A schema that is absent, empty, longer than `MAXSCHEMA` or holds a control character is refused 400 `PORT.VALIDATION` `REASONCATALOGSCHEMA` before any route.
  - Update the endpoint and `CatalogRows` doc comments, contract only.
- `src/OcuPilot/Screen/Descriptor/ExplorerSqlSchema.cls`, `ExplorerSqlSchemaViews.cls`, `ExplorerSqlSchemaProcedures.cls` (new): the group, in the Design Notes' golden example's shape. Write each doc comment in its sibling's shape.
- `ui/src/app/core/strings.ts`: after `explorerSqlProceduresEmpty`, add `explorerSqlSchemaTablesEmpty`, `explorerSqlSchemaViewsEmpty` and `explorerSqlSchemaProceduresEmpty`, with the three ruled sentences. Each carries `/** EXPERIENCE.md:595 */`.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` line 595, edited in place with no line added:
  - add the three sentences after "This table has no constraints.";
  - add "; the empty states of a schema's Tables, Views and Procedures tabs [ADDED 2026-10-23 - Story 20.38]" to the description.
- `ui/src/app/core/screens.generated.ts`: regenerate with `cd ui && node tools/screen-mirror.mjs`. Never hand-edit it.
- `ui/src/app/core/navigation.ts` and `ui/src/app/shell/data-table.ts`: move the chain at data-table.ts :685-701 verbatim into an exported `nameLinkTarget(screen)`, which `data-table.ts` then calls. Behavior does not change, and the :701 fallback stays.
- `ui/tools/name-links.test.mjs` (new). For every built screen that draws a `name` column, take `nameLinkTarget`:
  - a target that `hasIdRoute` must be built;
  - the set of screens whose target is the screen itself must equal, exactly, `NON_DEFECTS` (the seven under Plan findings, each with its reason, and `DIALOG_EDITORS` among them) plus `STORY_20_39_ALLOW_LIST` (rows 2-18 of the table there, by descriptor);
  - the two sets are disjoint, and SQL schemas is in neither;
  - SQL schemas links to `system-explorer/sql-schemas/document`;
  - the three tabs link to `sql-tables/document`, `sql-views/document` and `sql-procedures/document` through `Table`, `View` and `Procedure`.
- `src/OcuPilot/Test/ExplorerSqlProbe.cls`:
  - add `BARESCHEMA` (`OcuProbe2038`) and `BARETABLE` (`OcuProbe2038.Bare`);
  - add `MakeBare(pNamespace)`, which creates that one table and no view or procedure;
  - add `RemoveBare(pNamespace)`, which drops it and fails if any `OcuProbe2038` class or table is left;
  - leave `Make` and `Remove` unchanged.
- `src/OcuPilot/Test/AtelierPortCatalog.cls`:
  - Add `TestEachSchemaTabSendsItsListsStatementWithSystemItems`. Each new endpoint sends exactly its list's statement, bound `["SYSTEM TABLE",s,s]` or `[1,s,s]`, with `system=no` supplied too.
  - Add `TestASchemaTabRequiresOneSchema`. An absent, empty, 129-character or control-character schema is refused 400 `REASONCATALOGSCHEMA` before any route.
  - Add the three endpoints to the version-gate loop (:264), and a schema-tab leg to the gate test (:241): a caller with no `%Development:USE` is refused 403 naming it.
- `src/OcuPilot/Test/AtelierPortCatalogLive.cls`: add `TestASchemaTabListsEveryObjectOfItsSchema`, which calls `MakeBare` and `RemoveBare` itself and asserts the removal. It checks that:
  - each new endpoint's rows for `OcuProbe195` equal its list's rows with `system=yes`;
  - `%Dictionary`'s tables include `%Dictionary.ClassDefinition`, and `%Library`'s procedures are not empty, with no `system` key and with `system=no`;
  - `OcuProbe2038`'s views and procedures answer 200 with no rows, while its tables answer `OcuProbe2038.Bare`;
  - a missing schema is refused 400.
- `src/OcuPilot/Test/ExplorerDescriptor.cls`:
  - Add the three descriptors to `DESCRIPTORS` after `ExplorerSqlProcedureStatements`, and to the expected tuples.
  - Add three `explorer.sqlschema*.read` names to the advertised tools. The writers stay unchanged; read the names off the instance.
  - Widen the SQL slice to 21 (`$List(…,10,30)`), and rename `…GatesAllEighteen` to `…GatesEverySqlScreen`.
  - Update the header's counts.
  - Add `TestTheSchemaTabsFormOneParentScopedGroup`. It checks positions, `labelKey`, `tab.labelKey`, the parent, the one criterion `schema/text/128`, the empty keys and the `rowTarget`s. It also checks that `OcuPilot.Screen.Context.ScreenTools(<tab>)` answers exactly the tab's own read wire name.
  - If the class passes about 520 lines, move the new method into a new `OcuPilot.Test.ExplorerSqlSchemaGroup`.
- `src/OcuPilot/Test/ExplorerCatalog.cls`:
  - add the three tools to the dispatch loop (:138), each answering rows for `OcuProbe195`;
  - add a `{}` leg that is refused `PORT.VALIDATION`;
  - change the header's "eighteen" to "twenty-one".
- Roster rows, add-only, with names read off the instance:
  - `ReadTool.cls`: the names, and the count 400 becomes 403;
  - `ToolRoundTrip.cls`: `REFUSEEMPTY`, three times `:PORT.VALIDATION`;
  - `DeveloperFloor.cls`: `SCREENS` and `TOOLS`, plus their counts;
  - `SurfaceCoverage.cls`: three `<screen>` rows naming the new method;
  - `StageTwoTools.cls`: `Elsewhere`;
  - `Descriptor.cls`: `ReadShapes`.
- Client rosters:
  - `ui/tools/screen-mirror.test.mjs`: the atelier read roster (:3066, `schema=`), the tab-group members (:955) and the criteria list (:1505);
  - `ui/tools/navigation.test.mjs`: the unlisted-route order (:335);
  - `ui/src/app/shell/detail-page.spec.ts`: add the schema group's routes to `SQL_TAB_ROUTES`, and an `it` for its strip, labeled "SQL schemas" with Tables, Views and Procedures, carrying the schema from tab to tab;
  - `ui/src/app/shell/side-bar.spec.ts`: an `it` checking that every tab of the schema group marks SQL schemas current.
- `ui/browser/system-explorer-sql.browser-spec.mjs`: `before` and `after` also call `MakeBare` and `RemoveBare`. Add one test that:
  - filters SQL schemas in `USER` to `OcuProbe195` and clicks its name;
  - checks the path `/ocupilot/system-explorer/sql-schemas/document/OcuProbe195`;
  - checks the locator, which reads SQL schemas › OcuProbe195 here and again on the Procedures tab;
  - checks the tabs Tables, Views and Procedures, and that the Tables read carries `schema=OcuProbe195` and no `system`;
  - opens Procedures, sees `OcuProbe195.Echo` and clicks it, landing on `sql-procedures/document/OcuProbe195.Echo` with Stored procedure info;
  - opens `OcuProbe2038` from the list: Tables shows `OcuProbe2038.Bare`, and Views shows exactly "This schema has no SQL views."

**Acceptance Criteria:**

- **AC1.** Given SQL schemas, when a schema's name is clicked, then `system-explorer/sql-schemas/document/<schema>` opens with the tabs Tables, Views and Procedures:
  - each tab lists every object of its kind in that schema, system ones included, through its list's own statement;
  - each object's name opens its table, view or procedure screen;
  - the breadcrumb reads SQL schemas › <schema> on every tab.
- **AC2.** Given a schema with no objects of a tab's kind, when that tab opens, then it shows that kind's ruled sentence, and a tab of a kind the schema holds shows its rows.
- **AC3.** Given the agent on any of the three tabs, when it reads the screen, then the context's tools are that tab's own read alone, which requires `schema`, and no write, row action or primary action is added.
- **AC4.** Given every built list whose name column links somewhere, when `npm run test:tools` runs, then it fails on any link to an unbuilt screen and on any self-link outside the declared non-defects and Story 20.39's exact allow-list. SQL schemas is in neither set.
- **AC5.** Given the browser suite, when a spec clicks a schema's name, then it lands on the schema's screen, sees the Procedures tab's rows and opens one procedure.

## Spec Change Log

- 2026-10-23, runner, after the first plan pass's `intent gap`: ruled Q1-Q4 and the empty-tab sentences (Design Notes, Runner's rulings); recorded the orchestrator's contention ruling; amended `epics.md` Story 20.38's ACs (address, System items, the Ens example, the split) and chartered Story 20.39; status reset to `draft` for the re-plan.

## Review Triage Log

### 2026-10-23 - Review pass

- verdicts: 14 findings - high 0, medium 1, low 4, false 9, maybe-false 0
- findings:
  - `[medium]` `[patch]` AC4's "never links to an unbuilt screen" assertion cannot fail: the mirror carries only built screens and every chain arm filters on `built` - patched: the predicate is `unbuiltLinkTargets(screens)`, and a control test feeds it a synthetic unbuilt copy of `AllowedDirectoryList` and expects it flagged; the mutation line is recorded.
  - `[low]` `[patch]` AC1's breadcrumb clause had no `mutation:` line, and the browser test read the locator on two of three tabs - patched in the pass (Rule 19 closes a missing line in the review): the Views tab's locator is asserted, and the mutation line is recorded.
  - `[low]` `[patch]` Mutation instructions at `data-table.spec.ts` (the Wallet, Activity log and Task schedule tests) and the SQL browser spec (the Tables and Views clicks) named a `linkTarget` chain in `data-table.ts`, which this story moved - patched: they name `nameLinkTarget` in `navigation.ts`.
  - `[low]` `[patch]` The paired-editor test's instruction in `data-table.spec.ts` predated the move and named code no longer there - patched the same way, its mutation (drop the two `editorScreenFor` terms) run red, reverted byte-identical.
  - `[low]` `[patch]` The allow-list's count of 17 is a tripwire with no note that Story 20.39 deletes it - patched: a one-line comment.
  - `[false]` `[reject]` The a11y structural walk was not run: no defect is claimed, and the spec leaves the full browser suite to CI.
  - `[false]` `[reject]` The list's click is fixed indirectly, through `documentScreenFor`, and only the browser spec drives it: the Code Map says the list is not edited, AC5 pins the click in the browser and AC4's test pins the function.
  - `[false]` `[reject]` The matrix examples `Ens` and `%Library` are not driven end to end: the plan rules probe-made schemas so a test makes what it asserts, the live test reads `%Dictionary` and `%Library` through the port with and without the system key, and `%` in a route id uses the shared encode pair that `detail-page.spec.ts` exercises for `%Library`.
  - `[false]` `[reject]` Only the Procedures `rowTarget` is clicked, and only the Views empty sentence is rendered: AC5 names the Procedures click, and the Table, View and Procedure `rowTarget`s and the three `emptyStateKey`s are pinned by the descriptor test and `name-links.test.mjs`.
  - `[false]` `[reject]` The refusal row is tested below the shell: the matrix row is the AD-29 port refusal, pinned for each tab by `TestTheGateRefusesBeforeAnyRoute`, and the shell's rendering of a refused read is shared grammar this story does not change.
  - `[false]` `[reject]` "Every object" against the read cap: measured on `ocupilot-b-ci`, the largest counts are 184 procedures (`HS_FHIR_DTL_FROMSDA`), 171 (`%Library`) and 57 tables (`%Dictionary`) against a cap of 1001, and the cap with its notice is the grammar of the lists the tabs extend.
  - `[false]` `[reject]` The guard evaluates `nameLinkTarget` rather than the drawn cell: `data-table.ts` calls that same function for its target, and the steps after it (the id route, the row-target field) are pinned by `data-table.spec.ts`.
  - `[false]` `[reject]` The test allows 24 self-links, not the contract's 17: AC4 and the Q4 ruling declare the seven non-defects as their own set, and the 17 are held exactly (count, exact-set, disjoint).
  - `[false]` `[reject]` Three new read tools against "no new agent action": the Q3 ruling reads it so, AC3 allows the tabs' own reads, and no write, row action or primary action is added.

## Design Notes

- **Governing ADs (Rule 6):**
  - AD-5: descriptors, the parent-scoped group and `rowTarget`.
  - AD-13: the schema is one encoded id segment.
  - AD-24: the context's `tools`.
  - AD-29: the port is the gate.
  - AD-36: one declared read per tab and tool.
  - AD-43: no refresh.
  - AD-44: `classicPage` is `%CSP.UI.Portal.SQL.Home`.
  - AD-61: fixed statements and bound values.
  - AD-19: client state lives in the store.
  - None is amended. The design uses existing grammar, so the spine is unchanged.
- **Rule 31 siblings:**
  - The descriptors extend Story 19.5's `ExplorerSqlTable` and `ExplorerSqlFields`, and copy their lists' fields, columns and context.
  - The endpoints extend `Catalog.Tables`, `Catalog.Views` and `Catalog.Procedures` in the port.
  - The link check shares `data-table.ts`'s chain through `nameLinkTarget` rather than copying it.
  - The tests extend `AtelierPortCatalog`, `AtelierPortCatalogLive`, `ExplorerDescriptor`, `ExplorerCatalog`, `ExplorerSqlProbe` and the SQL browser spec.
- **Integration (Rules 1 and 2):** no service is introduced.
  - Consumes Epic 19's SQL catalog: the three list statements and column maps, and the table, view and procedure groups as row targets.
  - Consumed-by: Story 20.39, which empties the link check's allow-list.
- **Upgrade triggers:** none. Nothing touches `Kernel/State/**`, a `%Persistent` class, `Install/**`, the start path, `module.xml`, compose or the governance baseline, and there is no write key.
- **Side bar and locator:**
  - Every member is unlisted (position 0, no aliases), as Story 19.5's group is.
  - The side bar marks SQL schemas current on every tab.
  - Every member's `labelKey` is `explorerSqlSchemasLabel`, so the locator reads System Explorer › SQL schemas › <schema>, and its middle crumb returns to the list.
  - The strip's names come from `tab.labelKey`: `explorerSqlColumnTables`, `explorerSqlColumnViews` and `explorerSqlColumnProcedures`.
- **Contention (Rule 11):**
  - At plan time, Epic 23's diff and worktree held only `_bmad-output` files, by read-only `git diff --stat` and `git status -s`.
  - This plan edits neither `screen-mirror.mjs` nor `Registry.cls`. The mirror is only regenerated.
  - It edits no existing descriptor, nor `Screen/Tool/Read.cls`, nor `Kernel/Agent/Prompt.cls`.
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
- **Decided in-stage (unattended):**
  - **Names.** The descriptors are `ExplorerSqlSchema`, `ExplorerSqlSchemaViews` and `ExplorerSqlSchemaProcedures`. The tools are `explorer.sqlschematables`, `explorer.sqlschemaviews` and `explorer.sqlschemaprocedures`, named for what they read. The endpoints are `Catalog.SchemaTables`, `Catalog.SchemaViews` and `Catalog.SchemaProcedures`.
  - **Labels.** Every member is labeled "SQL schemas". The siblings label each tab by its own name, but that would put a "Views" crumb in front of a link to SQL schemas, and the AC's breadcrumb would hold only on the head.
  - **Prompts.** Each tab reuses its list's prompts 2 and 3 plus `homeStarterPromptExplainScreen`, in the Code group. Prompt 1 names the namespace, not the schema. Reusing keys has precedent (19 prompt keys are already shared between descriptors), and adds no string.
  - **The empty-tab check** uses a probe-made schema with one table (`OcuProbe2038`), not `Ens`, so that the test makes what it asserts (Rule 30). The procedure rows come from `OcuProbe195.Echo`.
  - **The schema criterion's `hint`** is "One schema, spelled as explorer.sqlschemas.read answers its Schema." It is tool text: no page renders a criterion's hint.
  - **The bare schema's Procedures tab** lists the one procedure its table projects, `OcuProbe2038.Bare_Extent` (measured on `ocupilot-b-ci`), so `TestASchemaTabListsEveryObjectOfItsSchema` asserts that row for Procedures and no rows for Views; the browser test asserts Views only.
  - **The shared chain** is `nameLinkTarget` in `navigation.ts`, with the two predicates `data-table.ts` also reads, `hasClassicRowLink` and `rowTargetScreenFor`, exported beside it rather than copied.
  - **A self-link** in `name-links.test.mjs` is a name cell whose target is the screen itself and has an id route; a target with no id route leaves the cell as text. It measured 24 lists, the seven non-defects and rows 2-18.
  - **A roster the plan did not name:** `ReadTool.TestEveryCriteriaCorpusCaseGetsItsSentence` counts descriptors that declare criteria, 69 to 72.
- **Golden example**, the head's distinctive keys. Everything else follows `ExplorerSqlTables` and `ExplorerSqlTable`:

  ```json
  "route": "system-explorer/sql-schemas/document", "labelKey": "explorerSqlSchemasLabel", "sideBarPosition": 0,
  "archetype": "detail", "parentScope": "system-explorer/sql-schemas", "emptyStateKey": "explorerSqlSchemaTablesEmpty",
  "read": {"source": {"port": "atelier", "endpoint": "Catalog.SchemaTables", "type": "LIST"}, "...": "fields, filter, sort, paging as ExplorerSqlTables",
    "criteria": {"fields": [{"param": "schema", "labelKey": "explorerSqlColumnSchema", "kind": "text", "maxLength": 128, "hint": "..."}]}},
  "rowTarget": {"route": "system-explorer/sql-tables/document", "field": "Table"},
  "tab": {"group": "system-explorer/sql-schemas/document", "position": 1, "labelKey": "explorerSqlColumnTables"},
  "toolIdentifier": "explorer.sqlschematables"
  ```

## Plan findings: the self-linking lists (Q4)

Q1-Q3's evidence, as ruled, is this file at `10b4a6958becbb3fe63c66c01a33397ec3f4a274`.

The first pass measured these with the shared table's own chain:

- Of 209 built screens, 152 draw a `name` column: 70 render it as text, 57 open a paired surface, and 25 link to their own id route. Re-measured at this plan, with the same counts.
- Seven of the 25 are the declared non-defects (`NON_DEFECTS`):
  - `ResourceList` and `AuditUserEventList` are `DIALOG_EDITORS`.
  - `AuditList`, `JournalRecordList` and `TaskHistoryList` open a detail dialog on their id.
  - `LicenseKey` and `OpenApiViewer` never draw the table.

Row 1 is fixed here, and rows 2-18 are `STORY_20_39_ALLOW_LIST`. "Today" is what each does now. "Proposed" is for Story 20.39.

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

## Verification

All runtime work targets the throwaway `ocupilot-b-ci` (52777). The MCP profile is `ocupilot-slot-b`, and nothing is written to the dev instance. Each command runs in the foreground with `timeout: 600000`, one test-runner call at a time.

**Shared surfaces:**

- the screen mirror (`screens.generated.ts`, regenerated);
- System Explorer's descriptor and tool rosters (`ExplorerDescriptor`: `DESCRIPTORS`, the SQL slice and count, the advertised `explorer.*` list);
- the read-tool rosters (`ReadTool`'s names and count, `ToolRoundTrip`'s `REFUSEEMPTY`, `DeveloperFloor`'s `SCREENS` and `TOOLS`, `ExplorerCatalog`'s tool loop);
- the screen rosters (`SurfaceCoverage`, `StageTwoTools`' `Elsewhere`, `Descriptor`'s `ReadShapes`);
- `AtelierPort`'s catalog endpoint roster (`AtelierPortCatalog`'s loops, `screen-mirror.test.mjs`'s atelier read roster);
- the client rosters (`screen-mirror.test.mjs`'s tab-group members and criteria list, `navigation.test.mjs`'s unlisted-route order, `detail-page.spec.ts`, `side-bar.spec.ts`);
- `strings.ts` (add-only) and EXPERIENCE.md line 595 (in place);
- the probe fixture `ExplorerSqlProbe` (new methods only);
- unchanged: the System Explorer side bar (every member unlisted), and the tab-group and criteria corpora (`TabCorpus`, `CriteriaCorpus`), since there is no new grammar.

Every test added or changed passes on a fresh environment, in either order.

**Commands:**

- (loop) Load `src` into the throwaway: `rsync -a --checksum --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-20/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`, then `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)` inside `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`. Expected: `tErrors` is 0.
- (loop) The story's own classes, one per call: `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<Class>`, for `AtelierPortCatalog`, `AtelierPortCatalogLive`, `ExplorerDescriptor` and `ExplorerCatalog`. Expected: every method passes.
- (loop) The touched rosters, about 41 s by `ci-timings.json`: `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.ReadTool --class OcuPilot.Test.ToolRoundTrip --class OcuPilot.Test.SurfaceCoverage --class OcuPilot.Test.DeveloperFloor --class OcuPilot.Test.StageTwoTools --class OcuPilot.Test.Descriptor`. Expected: green.
- (once) The untouched consumers, about 65 s: `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.ScreenAccessDescriptor --class OcuPilot.Test.AtelierPortCatalogTabsLive --class OcuPilot.Test.AtelierPortDenial --class OcuPilot.Test.EndpointCoverage --class OcuPilot.Test.ToolEmit --class OcuPilot.Test.TurnScope --class OcuPilot.Test.Navigation --class OcuPilot.Test.RegistryCache`. Expected: green.
- (loop) `cd ui && npm run test:tools`. Expected: green, including `name-links.test.mjs` and EXPERIENCE.md's line citations.
- (loop) `cd ui && npm run test:components`. Expected: green, including `data-table` over `nameLinkTarget`.
- (loop) `cd ui && npm run build`. Expected: the prebuild checkers pass, `screen-mirror.mjs --check` among them, and the bundle stays under 2500 kB / 4000 kB. A crossing is reported, never re-based.
- (loop) The browser spec: `cd ui && npm run build`, then `docker exec ocupilot-b-ci sh -c 'cd /durable/iris/csp/ocupilot && rm -rf ./*' && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/system-explorer-sql.browser-spec.mjs`. Expected: green.
- (once) `uv run scripts/check-objectscript.py` reports 0 problems, and `bash scripts/lint-docs.sh` is clean for EXPERIENCE.md.
- **Lead-owned:**
  - the full ObjectScript sweep;
  - `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`;
  - the Rule 30 fresh check.
- **Left to CI:** the full browser suite, including the a11y structural walk over the new tabs.

**Pinning tests and mutations (Rule 19; the implement stage demonstrates each and records the `mutation:` line):**

- **AC1.** The browser test.
  - Mutation: drop `ExplorerSqlSchemaProcedures`' `rowTarget`, then regenerate, rebuild and redeploy. The wait for the procedure's path times out.
  - mutation: dropped `ExplorerSqlSchemaProcedures`' `rowTarget`, regenerated the mirror, rebuilt, redeployed -> `system-explorer-sql.browser-spec.mjs` "Story 20.38 AC1, AC2, AC5" red (`clickRowCentre: the row carries no .ocu-data-table-link`); reverted and rebuilt, green, the descriptor and `screens.generated.ts` byte-identical.
  - Supporting: the live test (mutation: bind the flag from `system` for the schema endpoints, and the `%Dictionary` and `%Library` legs go red), and `AtelierPortCatalog`'s bodies (mutation: bind 0, and red).
  - mutation: bound the flag from `system` for the schema tabs in `AtelierPort.CatalogRows` -> `AtelierPortCatalogLive.TestASchemaTabListsEveryObjectOfItsSchema` red on its four `%Dictionary` and `%Library` legs.
  - mutation: bound the flag as 0 in `AtelierPort.CatalogRows` -> `AtelierPortCatalog.TestEachSchemaTabSendsItsListsStatementWithSystemItems` red on all three tabs (and `TestEachListSendsItsFixedStatementAndBoundValues` on its `system=yes` legs).
  - mutation: dropped the empty-schema test from `AtelierPort.CatalogRows` -> `AtelierPortCatalog.TestASchemaTabRequiresOneSchema` red on the absent and empty legs of all three tabs.
  - mutation: labeled `ExplorerSqlSchemaViews` `explorerSqlColumnViews` instead of `explorerSqlSchemasLabel`, regenerated, rebuilt, redeployed -> the same browser test red at "and the same on the Views tab" (the locator read Views, not SQL schemas); reverted and rebuilt, green, the descriptor and `screens.generated.ts` byte-identical.
- **AC2.** The browser test's `OcuProbe2038` leg.
  - Mutation: point `ExplorerSqlSchemaViews`' `emptyStateKey` at `explorerSqlViewsEmpty`. The sentence assertion goes red.
  - mutation: pointed `ExplorerSqlSchemaViews`' `emptyStateKey` at `explorerSqlViewsEmpty`, regenerated, rebuilt, redeployed -> the same browser test red on "a schema with no views says so" (`No SQL views in USER match.` for `This schema has no SQL views.`); reverted and rebuilt, green, byte-identical.
- **AC3.** `ExplorerDescriptor.TestTheSchemaTabsFormOneParentScopedGroup`'s `ScreenTools` leg.
  - Mutation: drop the `BoundTo` filter in `OcuPilot.Screen.Context.ScreenTools`, and recompile. The exact-tools assertion goes red.
  - mutation: dropped the `BoundTo` filter in `OcuPilot.Screen.Context.ScreenTools`, reloaded `src` -> `ExplorerDescriptor.TestTheSchemaTabsFormOneParentScopedGroup` red on its three "name its own read alone" legs (four other `ScreenTools` tests in the class red too); reverted and reloaded, green, `Context.cls` byte-identical.
  - Supporting: `ToolRoundTrip`'s `PORT.VALIDATION` rows.
- **AC4.** `name-links.test.mjs`.
  - Mutation: drop the `documentScreenFor` arm from `nameLinkTarget`. SQL schemas and other document-paired lists self-link, and the exact-set assertion goes red naming them.
  - mutation: dropped the `documentScreenFor` arm from `nameLinkTarget` -> `name-links.test.mjs` "the lists whose name cell links back to themselves are exactly the declared..." red, naming SQL schemas, the Classes, Routines, Tables, Views and Procedures lists, four interoperability lists, Cubes and REST APIs, and "the SQL schemas list opens the schema screen" red; reverted, green, `navigation.ts` byte-identical.
  - A second mutation: delete one allow-list row. Red.
  - mutation: deleted the `AgentScreenPermissions` row from `STORY_20_39_ALLOW_LIST` -> the same exact-set test red naming it, and the disjoint-sets test red on its row count; reverted, green, byte-identical.
  - mutation: made `unbuiltLinkTargets` in `name-links.test.mjs` never flag (`target.built !== true` became `false`) -> "the unbuilt-target check flags a name cell that links to a screen that is not built" red; reverted, byte-identical.
- **AC5.** AC1's browser test, with AC1's mutation.
  - mutation: AC1's first mutation -> the same browser test red at the click on the procedure's name.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** A schema's name on SQL schemas opens a parent-scoped group at `system-explorer/sql-schemas/document/<schema>` with Tables, Views and Procedures tabs. Each lists every object of its kind in the schema, system ones included, through its list's own statement, and each object's name opens its screen. A client test fails on any list whose name cell links back to itself outside the declared non-defects and Story 20.39's allow-list.

**Files changed.**

- Port: `src/OcuPilot/Port/AtelierPort.cls` - the three `Catalog.Schema*` endpoints over their lists' statements and column maps, the system flag bound on, `schema` required.
- Screens: new `ExplorerSqlSchema`, `ExplorerSqlSchemaViews` and `ExplorerSqlSchemaProcedures` descriptors; `ui/src/app/core/screens.generated.ts` regenerated; three empty-tab strings in `ui/src/app/core/strings.ts`; EXPERIENCE.md line 595 edited in place.
- Client: `nameLinkTarget` (with `hasClassicRowLink` and `rowTargetScreenFor`) moved from `data-table.ts` into `ui/src/app/core/navigation.ts`; new `ui/tools/name-links.test.mjs`.
- ObjectScript tests and rosters: `ExplorerSqlProbe` (`MakeBare`, `RemoveBare`), `AtelierPortCatalog`, `AtelierPortCatalogLive`, `ExplorerDescriptor`, `ExplorerCatalog`, `ReadTool` (403 tools, 72 criteria screens), `ToolRoundTrip`, `DeveloperFloor`, `SurfaceCoverage`, `StageTwoTools`, `Descriptor`.
- Client tests: `screen-mirror.test.mjs`, `navigation.test.mjs`, `detail-page.spec.ts`, `side-bar.spec.ts`, `data-table.spec.ts` (mutation comments only), and the SQL browser spec's new test.

**Review.** 14 findings: 5 patched (1 medium, 4 low), 9 rejected `false`, none deferred (`deferred: []`). Patches are in the triage log. `screen-mirror.mjs`, `Registry.cls` and every existing descriptor are untouched.

**Follow-up review recommended:** false. One medium was patched, no high.

**Verification** (all on `ocupilot-b-ci`, after the last patch unless noted):

- the four story classes (10, 9, 17 and 5 tests) and the six touched rosters (108): green, on the tree as loaded;
- the eight untouched consumers (63): green, run once after the last patch;
- `npm run test:tools` (2,151) and `npm run test:components` (3,340): green;
- `npm run build`: the prebuild checkers pass and the initial total is 2.00 MB, under the 2,500 kB warning;
- the SQL browser spec: 8 of 8, on the final bundle;
- `check-objectscript.py`: 0 problems; `lint-docs.sh`: 0 issues;
- the matrix's five rows are each covered by a test that ran and passed;
- every mutation is recorded under Verification, each reverted byte-identical.

**Residual risks.**

- Story 23.12 (Epic 23, slot A) changes `ExplorerDescriptor.cls`, `strings.ts`, `screens.generated.ts` and `screen-mirror.test.mjs`, which this story also edits, and the new read descriptors need its `row` and `label` lines if it merges first. The integrate-forward resolves both.
- Not run here, left to the lead: the full ObjectScript sweep, `smoke.sh`, the Rule 30 fresh check and the full browser suite with the a11y structural walk.
- A schema named `document`, `views` or `procedures` shares its list route id with a group route; judged negligible.
