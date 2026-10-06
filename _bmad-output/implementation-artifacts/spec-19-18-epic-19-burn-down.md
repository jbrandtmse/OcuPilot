---
title: 'Story 19.18: Epic 19 burn-down'
type: 'bugfix'
created: '2026-10-05'
status: 'done'
baseline_revision: '66f177f6cdaa187c18819afd5d6e004b4fd6e35d'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-19-context.md'
warnings: ['multiple-goals', 'oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Four defects Epic 19 filed against its own surfaces are still open:

- **DW-1001.** 36 derived read-tool criteria take one exact name or literal text, but the model is told each is "a comma-separated list of names. * matches any name."
- **DW-1945.** `ExplorerWrite`'s agent legs for compile and delete call the tool's `View` directly, so a schema, pairs or governance regression on those tools passes.
- **DW-2092.** The data browser and the SQL console read "1 rows change", "1 changes waiting to be saved", "1 rows changed" and similar.
- **DW-2093.** `ExplorerDescriptor`'s area-count method is named for counts it stopped asserting two stories ago.

**Approach:**

- Declare a short, true `hint` on each of the 36 criteria. This is Story 18.19's existing mechanism (AD-36), so there is no grammar or spine change. Pin it with a roster test that reads the descriptions a provider request carries.
- Route the two `ExplorerWrite` legs through `Dispatch.Answer`, as `ExplorerTransfer`'s import leg does.
- Give every count sentence in the data browser and the console a singular form at 1, with the three-count save sentence composed from per-count phrases.
- Rename the test method and its eight `SurfaceCoverage` rows.

## Boundaries & Constraints

**Always:**

- **Hints:**
  - A hint lives in its descriptor's `read.criteria.fields` entry (AD-5), and `ui/src/app/core/screens.generated.ts` is regenerated, never hand-edited.
  - Each hint is one sentence of at most 300 characters. It says what the port accepts: the form, and which read answers the value.
  - The text is the one in Tasks, measured in Design Notes.
- **What a hint changes:** a hint changes no read, field, filter, bound, criterion kind or screen (AD-24, AD-36). The screen never shows it, so it needs no `strings.ts` key.
- **Comma lists:** the eight criteria that really are comma lists keep the generic description. These are `logs.audit`'s six, and `explorer.classes` and `explorer.routines` `pattern`.
- **Governance:** the agent legs reach the tools by wire name through the dispatcher. The baseline is unchanged (AD-22).
- **Count sentences:**
  - A count reads singular at exactly 1, and plural at 0 and at 2 or more.
  - Every new literal is in `strings.ts` and in its EXPERIENCE.md Fixed-strings row. Edits go inside the existing rows :597 and :599, so no cited line moves.
  - Non-ASCII is written as escapes (Rule 14).
- **Budgets:**
  - Re-base the bundle warning to the measured build (DW-1166). Stop and ask above 3,800 kB.
  - Raise the Fixed-strings bound only as the `strings.test.mjs` task states.

**Never:**

- No change to `Screen/Registry.cls`'s criteria grammar, `Screen/Tool/Read.cls`, the `screen-mirror.mjs` rules or the spine.
- No hint on the eight comma-list criteria, and no change to any `choice` or `datetime` criterion.
- No change to any count sentence outside the data browser and the SQL console, including the shared table's "<n> rows" on the data table, command bar, context chip and ledger (see Design Notes, ledger candidates).
- DW-1977 is not redone. Story 19.14 delivered it (f1d89c56), and it was closed at the gate.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Exact-name criterion | `explorer.sqltable.read`'s `table` in `ProviderTools`' emitted schema | description = its hint + " At most 257 characters."; no "comma-separated" | unchanged: `*` refused 400 `PORT.VALIDATION` |
| Parent-scoped criterion | `osmgmt.databasedetails.read` `dir` | hint names `osmgmt.databases.read` and its `Directory` | omitted still 400 `READ.CRITERION` |
| Optional exact name | `explorer.sqltables.read` `schema` omitted | hint says omitting lists every schema; rows of every schema | unchanged |
| Comma-list criterion | `logs.audit.read` `usernames` | generic comma-list description kept | — |
| One staged row of each kind | save dialog | "1 row changes, 1 is added and 1 is deleted in <table>, and this cannot be undone from OcuPilot." | — |
| Zero and two | 2 updates, 0 inserts, 0 deletes | "2 rows change, 0 are added and 0 are deleted in <table>, …" | — |
| One staged change | tab name, status, discard, save of 1 | "<table>, 1 change waiting to be saved." · "1 change discarded." · "Saved 1 of 1 change; 0 rolled back." | — |
| Console singulars | a query of 1 row, cut at Max rows 1, DML of 1 row, 1 value asked | "1 row" · "1 row is shown; the answer holds more." · "1 row changed" · "This statement takes 1 value." | — |

</intent-contract>

## Code Map

Paths are under `src/OcuPilot/` or `ui/` unless given in full. Line numbers were read at HEAD `3a0f5a4f`.

- **The hint mechanism (read-only; Story 18.19):**
  - `Screen/Tool/Read.cls` `AddCriteria` :151–198. A text criterion with a hint and no default publishes the hint alone (:171–181). The generic text sentence is :192–195.
  - `Screen/Tool/Registry.cls`: `EmitProperty` :364 appends " At most N characters.", and `ProviderTools` :256 builds `pTools(n, "name"|"description"|"inputSchema")`. `ListTools` :106 gives `{name, kind, class, descriptor}` (derived reads: `class` = `ReadToolClass()`), and `WireName` :212.
  - `Screen/Registry.cls` `CriteriaHintProblem` :1851 (≤ `CRITERIONHINTMAX` 300, :1846) and `DescriptorForRoute` :3698.
  - `Screen/Descriptor/Base.cls` `DeclarationJson` :64, `ParentScope` :274 and `ToolIdentifier` :508.
  - `ui/tools/screen-mirror.mjs` `criteriaHintProblem` :1905. `node tools/screen-mirror.mjs` writes the mirror, and `--check` (in `prebuild`) verifies it.
  - Exemplar: `Test/JournalDescriptor.cls` `TestJournalRecordsCriteriaAreThePortsClosedSets` :338–367.
- **The 36 criteria.** Line of each in-scope `"kind": "text"` entry in `Screen/Descriptor/`:
  - `OpenApiViewer`:58, `WalletSecretList`:70, `ExplorerSearch`:59, `ExplorerMacro`:58–59;
  - `ExplorerSqlTables`:57, `ExplorerSqlViews`:54, `ExplorerSqlProcedures`:55;
  - `ExplorerSqlTable`:55, `ExplorerSqlFields`:54, `ExplorerSqlIndices`:54, `ExplorerSqlTriggers`:54, `ExplorerSqlConstraints`:53, `ExplorerSqlPartitions`:55, `ExplorerSqlPartitionMappings`:55, `ExplorerSqlCachedQueries`:56, `ExplorerSqlTableStatements`:61;
  - `ExplorerSqlView`:58, `ExplorerSqlViewFields`:55, `ExplorerSqlViewStatements`:61, `ExplorerSqlProcedure`:58, `ExplorerSqlProcedureStatements`:61;
  - `ExplorerClassDocument`:58, `ExplorerRoutineDocument`:58;
  - `DatabaseDetails`:124, `DatabaseVolumeList`:93, `GlobalMappingList`:58, `PackageMappingList`:58, `RoutineMappingList`:58, `JournalFileDetails`:58, `JournalFileDatabaseList`:52, `LanguageServerActivity`:62, `ProcessDetails`:98;
  - `TaskDetails`:107, `TaskRunList`:77, `TaskHistoryList`:79.
- **Exact-JSON pins a hint breaks:** `Test/MappingDescriptor.cls`:44 (the namespace criterion) and `Test/LanguageServer.cls`:73 (the Activity log's criteria). A search by `labelKey`, `maxLength` and text found no other test comparing an in-scope criterion's declaration or the generic sentence; the targeted runs and the sweep are the check.
- **DW-1945:**
  - `Test/ExplorerWrite.cls`: `MintFor` :76–93, the compile leg `TestTheAgentCompilesThroughConfirm` :219–246, the delete leg `TestTheAgentsDeleteIsGovernedAndThenConfirmed` :278–303 (its `Gate.Decide` assertions :284–286), and the header :1–14.
  - The exemplar is `Test/ExplorerTransfer.cls` `DispatchFor` :85–113 and the import leg :228–232.
  - `Kernel/Agent/Dispatch.cls` `Answer` :131.
  - `Kernel/Governance/Baseline.cls`:171–172 holds `compile` true and `delete` false.
- **DW-2093:** `Test/ExplorerDescriptor.cls`:131–141, whose doc and assertions say 26 reads and 11 writes, and `Test/SurfaceCoverage.cls`:324–331. `SurfaceCoverage`:657 refuses a row whose method is not compiled.
- **DW-2092:**
  - `ui/src/app/core/strings.ts`: `explorerSqlRowsCut` :5114, `explorerSqlRowsChanged` :5116, `explorerSqlTakesValues` :5124, `explorerSqlDataSaveConsequence` :5330, `explorerSqlDataWaiting` :5334, `explorerSqlDataDiscarded` :5338 and `explorerSqlDataSavedSummary` :5340. Each is cited `EXPERIENCE.md:597` or `:599`.
  - `ui/src/app/core/data-browser-model.ts` is framework-free, already imports `STRINGS` and owns the status lines. `ui/tools/data-browser-model.test.mjs` tests it.
  - `ui/src/app/areas/system-explorer/data-browser.page.ts`: :455 (the tab name) and :605–609 (`saveConsequence`).
  - `ui/src/app/areas/system-explorer/data-browser.store.ts`: :567 (discarded), :619 (the saved summary) and :768 (waiting).
  - `ui/src/app/core/sql-answer.ts` `statusLineFor` :90–109 (:94 rows and cut, :96 changed, :103 values). The proposal card reads it through `turn.ts` `outputLinesOf`.
  - House pattern: a `...One` key chosen at 1 (`explorer-compile-dialog.ts`:69, `broadcast-dialog.ts`:129). `core/impact.ts`:137–260 composes per-count phrases into one line.
  - EXPERIENCE.md :597 is the SQL query row, :599 the data browser editing row and :314 the shared table row, which this story does not edit.
- **Assertions that pin today's plural at 1** (update them):
  - `data-browser-tabs.page.spec.ts`:97, 324, 344, 453;
  - `data-browser.page.spec.ts`:715, 746, 1007, 1036, 1050–1051;
  - `sql-query.page.spec.ts`:232, 427, 516, 569, 589;
  - browser: `agent-sql`:197, `system-explorer-data-browser-chords`:223, 235, `system-explorer-data-browser-tabs`:198, 206, 221, 331, `system-explorer-data-browser-edit`:280 and `system-explorer-sql-query`:166, 252.
- **Budgets:**
  - `ui/angular.json`:54 is `2954kB`, pinned at `ui/tools/angular-json.test.mjs`:525 with the comment block above.
  - `ui/tools/strings.test.mjs`:583–587 bounds the table at 2,700; this branch measures 2,664.

## Tasks & Acceptance

**Execution:**

- [ ] `src/OcuPilot/Screen/Descriptor/*.cls` (the 35 files the Code Map lists): add `"hint"` to each in-scope criterion. Nothing else changes. The texts, where `<x>.read` is a tool's canonical name:
  - **`OpenApiViewer` `application`:** "One REST application, spelled as webapp.restapis.read answers its Name: a web application path starting with /, or a spec-based service's package name."
  - **`WalletSecretList` `collection`:** "One wallet collection, spelled as security.wallet.read answers its Name."
  - **`ExplorerSearch` `text`:** "The text to find, matched literally, so * and commas are searched for as themselves."
  - **`ExplorerMacro`:**
    - `document`: "The class or routine whose include files, imports and superclasses give the macro its context, spelled as explorer.classes.read or explorer.routines.read answers its Name."
    - `macro`: "One macro's name, with or without its three leading dollar signs."
  - **`ExplorerSqlTables`, `ExplorerSqlViews` and `ExplorerSqlProcedures` `schema`:** "One schema, spelled as explorer.sqlschemas.read answers its Schema; omit it to list every schema's tables." Use "views" and "procedures" in the other two.
  - **The nine table tabs' `table`:** "One table, as Schema.Table, spelled as explorer.sqltables.read answers its Table."
  - **The three view tabs' `view`:** "One view, as Schema.View, spelled as explorer.sqlviews.read answers its View."
  - **The two procedure tabs' `procedure`:** "One procedure, as Schema.Procedure, spelled as explorer.sqlprocedures.read answers its Procedure."
  - **`ExplorerClassDocument` `name`:** "One class, as Package.Name.cls, spelled as explorer.classes.read answers its Name."
  - **`ExplorerRoutineDocument` `name`:** "One routine or include file, as Name.mac, .int, .inc, .bas, .mvi or .mvb, spelled as explorer.routines.read answers its Name."
  - **`DatabaseDetails` and `DatabaseVolumeList` `dir`:** "One database directory, spelled as osmgmt.databases.read answers its Directory."
  - **The three mapping lists' `namespace`:** "One namespace, spelled as osmgmt.namespaces.read answers its Name."
  - **`JournalFileDetails` and `JournalFileDatabaseList` `file`:** "One journal file, spelled as osmgmt.journals.read answers its Name."
  - **`LanguageServerActivity` `name`:** "One external language server, spelled as osmgmt.languageservers.read answers its Name."
  - **`ProcessDetails` `pid`:** "One process id, a whole number, as osmgmt.processes.read answers its Pid."
  - **`TaskDetails` `taskId`:** "One task's whole-number id, as tasks.schedule.read answers its Id."
  - **`TaskRunList` `taskId`:** "One task's whole-number id, as tasks.schedule.read answers its Id; omit it to read every task's runs."
  - **`TaskHistoryList` `search`:** "Text to find in any column of a run, ignoring case; * and commas are matched as themselves."
- [ ] `ui/src/app/core/screens.generated.ts`: regenerate with `cd ui && node tools/screen-mirror.mjs`, then `--check` it.
- [ ] `src/OcuPilot/Test/CriterionHints.cls` (new): pins DW-1001 against `Registry.ListTools` and `ProviderTools`. The header says what it pins and that it needs only an installed instance. Three methods:
  - every derived read tool's `text` criterion either declares a hint or is one of the eight comma-list criteria, an exact two-sided roster (`logs.audit.read:eventSources|eventTypes|events|usernames|pids|namespaces`, `explorer.classes.read:pattern`, `explorer.routines.read:pattern`);
  - each hinted text criterion's description in `ProviderTools`' emitted schema equals hint + " At most <maxLength> characters.". Each of the eight starts "A server-search criterion, as a comma-separated list of names.";
  - each hinted criterion of a parent-scoped read names its parent's read, `<DescriptorForRoute(ParentScope).ToolIdentifier>.read answers its `.
- [ ] `src/OcuPilot/Test/MappingDescriptor.cls`:44 and `src/OcuPilot/Test/LanguageServer.cls`:73: carry the new `hint` in the expected JSON.
- [ ] `src/OcuPilot/Test/ExplorerWrite.cls`:
  - Add `DispatchFor(pToolName, pNamespace, pInput, …)` shaped as `ExplorerTransfer.DispatchFor`: a seeded completed turn, one `tool_use` named by `WireName`, `Dispatch.Answer`, then parse.
  - The compile leg mints through `DispatchFor("explorer.classes.compile", …)`. It asserts `'is_error`, and that the dispatched tool result holds no console line.
  - The delete leg asserts at the baseline that `DispatchFor("explorer.classes.delete", …)` answers `is_error` with code `GOVERNANCEDISABLED`, replacing the `Gate.Decide` lines. It keeps the direct `MintFor` + `ConfirmIn` 403. Once the key is enabled, it mints through `DispatchFor` and confirms the delete.
  - Update the header and the two doc comments.
- [ ] `src/OcuPilot/Test/ExplorerDescriptor.cls`:141 and `src/OcuPilot/Test/SurfaceCoverage.cls`:324–331:
  - Rename the method to `TestTheAreaHoldsTwentySixReadsAndElevenWrites` and point the eight rows' `method=` at it.
  - The rows' `corpus` becomes "the area's eleven writes are asserted together in one loop".
- [ ] `ui/src/app/core/strings.ts`:
  - **Changed value:** `explorerSqlDataSaveConsequence` becomes '<updated>, <added> and <deleted> in <table>, and this cannot be undone from OcuPilot.'.
  - **New keys beside it** (`/** EXPERIENCE.md:599 */`): `explorerSqlDataSaveUpdated` '<n> rows change', `…UpdatedOne` '1 row changes', `explorerSqlDataSaveAdded` '<n> are added', `…AddedOne` '1 is added', `explorerSqlDataSaveDeleted` '<n> are deleted', `…DeletedOne` '1 is deleted'. Then `explorerSqlDataWaitingOne` '1 change waiting to be saved.', `explorerSqlDataDiscardedOne` '1 change discarded.' and `explorerSqlDataSavedSummaryOne` 'Saved <a> of 1 change; <b> rolled back.'.
  - **New keys after the console's** (`:597`): `explorerSqlRowCountOne` '1 row', `explorerSqlRowsCutOne` '1 row is shown; the answer holds more.', `explorerSqlRowsChangedOne` '1 row changed' and `explorerSqlTakesValuesOne` 'This statement takes 1 value.'.
- [ ] `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`: make each edit inside its line.
  - **:599:** replace the consequence literal with the new template, and add the nine new literals. Extend the Where cell with "the save consequence composed from its three counted phrases, and the singular of each count line at 1 [ADDED 2026-10-05 - Story 19.18]".
  - **:597:** add the four console literals. Extend its Where cell likewise.
- [ ] `ui/src/app/core/data-browser-model.ts` and `ui/tools/data-browser-model.test.mjs`:
  - Export `saveConsequenceText(counts, table)`, `waitingText(count)`, `discardedText(count)` and `savedSummaryText(saved, total, failed)`. Each picks a `...One` template at exactly 1 through one shared chooser, and the consequence composes its three phrases.
  - Test each at 0, 1 and 2, and the consequence with mixed counts.
- [ ] `ui/src/app/areas/system-explorer/data-browser.page.ts` (:455 and :608) and `data-browser.store.ts` (:567, :619 and :768): call those functions.
- [ ] `ui/src/app/core/sql-answer.ts` `statusLineFor` and `ui/tools/sql-answer.test.mjs`:
  - At 1, use `explorerSqlRowCountOne`, `explorerSqlRowsCutOne`, `explorerSqlRowsChangedOne` and `explorerSqlTakesValuesOne`.
  - Test 1 and 2 for each.
- [ ] Update the singular-at-1 assertions the Code Map lists in the component and browser specs.
- [ ] `ui/tools/strings.test.mjs`:583–587, for the lead's approval at the spec gate:
  - Raise the bound from 2,700 to 2,800, with the comment "Story 19.18's thirteen literals take the table to 2,677, and Epic 18's branch, merged beside them, to about 2,718; the bound moves to 2,800 under the same protocol".
  - Measured: base `cbdeecc4` holds 2,650, this branch 2,664 and Epic 18's head `63f1a2f7` 2,691. The merged figure is an inference, assuming disjoint row edits; Epic 18 edits rows :364 and :516.
- [ ] `ui/angular.json`:54 and `ui/tools/angular-json.test.mjs`:525: re-base `maximumWarning` to the measured initial total rounded up to the next kB, with a Story 19.18 comment line. Stop and ask above 3,800 kB.

**Acceptance Criteria:**

- **DW-1001:**
  - Given the provider tool list a turn sends, when any derived read tool's text criterion that takes one exact name or literal text is read, then its description is its declared hint followed by its "At most N characters." sentence, and none carries the comma-list sentence.
  - Given every derived read tool, when its text criteria are enumerated, then exactly the eight comma-list criteria lack a hint and keep the generic description. A criterion added later without a hint reddens `CriterionHints`, naming it.
  - Given a parent-scoped read's hinted criterion, when its hint is read, then it names the parent screen's read tool as the source of the value.
- **DW-1945:**
  - Given `ExplorerWrite`'s compile leg, when the agent's compile call goes as a `tool_use` through `Dispatch.Answer`, then a proposal is minted and its confirm compiles both documents, as before.
  - Given the baseline, when the agent's delete call goes through `Dispatch.Answer`, then it answers `is_error` with `GOVERNANCEDISABLED` and nothing is deleted. A proposal minted directly is refused 403 at confirm. With the key enabled, the dispatched delete is minted, confirmed, and reads back not found.
- **DW-2092:**
  - Given the data browser with one staged update, insert and delete, when the save dialog opens, then it reads "1 row changes, 1 is added and 1 is deleted in <table>, and this cannot be undone from OcuPilot.".
  - Given one staged change, when the tab strip and the status are read, then each reads "1 change waiting to be saved."; when it is discarded, "1 change discarded."; and when it is saved, "Saved 1 of 1 change; 0 rolled back.". Counts of 0 and 2 read plural, and the tab name and the saved summary read so in the browser on the throwaway.
  - Given the SQL console, when a query answers one row, a query is cut at Max rows 1, a DML statement changes one row, or the statement asks for one value, then the status reads "1 row", "1 row is shown; the answer holds more.", "1 row changed" or "This statement takes 1 value.", and a confirmed agent run's card line reads "1 row changed".
- **DW-2093:** Given `ExplorerDescriptor`, when its area-count method runs, then its name states twenty-six reads and eleven writes, and `SurfaceCoverage`'s eight rows resolve to it.

## Spec Change Log

- 2026-10-05, lead (spec gate): accepted as planned. The Fixed-strings bound raise to 2,800 in `ui/tools/strings.test.mjs` is approved (sized for the merge with Epic 18). The epic context's count of OS management and Tasks criteria is 12, not 13 (the plan's parse). The plural-only counts outside this scope (the shared `<n> rows` count and the code list's export status) are DW-2101, routed to the range-end cleanup.

## Review Triage Log

### 2026-10-05 — Review pass

- verdicts: 7 findings — high 0, medium 1, low 4, false 2, maybe-false 0
- findings:
  - `[medium]` `[patch]` saved-summary singular wiring at `data-browser.store.ts:622` pinned only by browser specs — added a jsdom case in `data-browser.page.spec.ts` and a mutation line, observed red.
  - `[low]` `[reject]` `CriterionHints` floor `tRows > 40` is looser than the derived count — the two-sided roster and per-descriptor tests still redden on a lost entry; an exact count adds a number to maintain.
  - `[low]` `[reject]` `TestAHintedCriterionIsDescribedByItsHint` has no compared-rows floor — the roster method reddens first when every hint is emptied.
  - `[low]` `[reject]` `SurfaceCoverage` corpus text says eleven writes while eight rows name the method — the sentence describes the method, which asserts all eleven.
  - `[false]` `[reject]` shared `tableRowCount` footer still reads "1 rows" — the spec's Never list excludes the shared table string by name.
  - `[false]` `[reject]` hints not checked for one sentence or 300 characters — `CriteriaHintProblem` (Registry.cls) refuses a longer hint at declaration, and `screen-mirror.mjs --check` repeats it.
  - `[low]` `[reject]` mutation lines name only some branches of `sql-answer.ts` — `sql-answer.test.mjs` asserts every branch at 0, 1 and 2.

## Design Notes

**Recount (DW-1001).** Parsed with `screen-mirror.mjs` `readSources()`, not grepped:

- 80 criteria, 51 of them `text`, 44 of those with no hint.
- **Comma lists (8):** `logs.audit`'s six criteria, and `explorer.classes` and `explorer.routines` `pattern`.
- **In scope (36):** the 22 the AC names; `explorer.class` and `explorer.routine` `name`; 9 in OS management (2 `dir`, 3 `namespace`, 2 `file`, `name`, `pid`); and 3 in Tasks (2 `taskId`, `search`).
- The context's "13 in OS management and Tasks" was 12: 22 + 2 + 12 + 8 = 44.
- No Epic 18 descriptor at `63f1a2f7` adds a text criterion. `EncryptionStartup` declares none.

**Hints measured** on `ocupilot-a2-ci`, 2026-10-05 (planning), through `Screen.Tool.Read.View`, for a valid value, a comma list, `*` and an omitted value:

- **What was probed:** one criterion per code path. These were `dir` on both readers, `GlobalMappingList` `namespace`, `file` on both readers, `LanguageServerActivity` `name`, `pid`, `taskId` on both readers, Task history `search`, `collection`, `application`, `explorer.class` `name`, `explorer.sqltables` `schema`, the `table` and `procedure` tabs, and `explorer.macro` and `explorer.search`.
- **A comma list or `*` is never a list or a pattern.** Each answered 400 `PORT.VALIDATION`, 404, or no rows, with two exceptions:
  - `pid` `1667,1667` read process 1667 alone.
  - Task history `search` `*` matched only rows whose text holds a literal `*`: 5 of 5 did.
- **Measured omissions:**
  - `schema` omitted reads every schema. For tables this was measured; for views and procedures it is the same fixed SQL, `? IS NULL OR …SCHEMA = ?`.
  - `TaskRunList` `taskId` omitted reads every task's runs.
- **Case:**
  - Task history `search` matches ignoring case ("purge" and "PURGE"), and `*` and `,` are literal ("pur*" and "purge,purge" both answer 0).
  - A class name is case-sensitive (lower case answers 404).
- **Macro:** a macro is accepted with and without `$$$`. The hint words it without a `$` so that no `$$$` sits in an XData block.

**Decisions:**

- **One mechanism, no spine edit (lead ruling; AD-36's hint clause covers it).**
  - The test reads `ProviderTools`, the outermost in-process surface the model sees.
  - The two-sided roster makes a later hintless text criterion a tripwire. It is not a new rule: the AC's general clause applies to every derived read.
- **Plural forms (DW-2092):**
  - The save sentence composes three per-count phrases, the `impact.ts` approach. Each single-count line takes the house `...One` key.
  - The console's "1 row" is `explorerSqlRowCountOne` in the console's own row. The shared `tableRowCount` row (:314) and its test (`strings.test.mjs`:739) stay unchanged.
- **DW-1945:** only the two named legs move. The edit-after-mint, oversized-set and own-code legs test mint-side refusals and keep `MintFor`.
- **DW-2093:** the name follows the counts, per the ruling. The doc comment already names them.

**Budget estimates (inference):** about 3.5 kB of hint text in the mirror plus about 1 kB of strings and code, giving roughly 2,959 kB, well under 3,800 kB. Epic 18 re-bases the same `angular.json` line (2973kB at `63f1a2f7`), so the forward merge conflicts there; the integrator re-measures the merged build.

**ADs:** AD-3, AD-5, AD-6, AD-22, AD-24, AD-36, AD-53, AD-61. No AC contradicts an AD.

**Integration ACs:** none. This story introduces no service, module or shared component. **Consumes:** the hint mechanism (`Read.AddCriteria`, Story 18.19), `Registry.ProviderTools`, `Dispatch.Answer`, `GovernanceFixture`, `ProposalFixture` and `data-browser-model.ts`. **Consumed-by:** none.

**Ledger inbox:** DW-1001 is addressed by the descriptor, mirror and `CriterionHints` tasks; DW-1945 by the `ExplorerWrite` task; DW-2092 by the strings, EXPERIENCE.md, model, page, store, `sql-answer` and spec tasks; and DW-2093 by the rename task. DW-1977 is closed and not in the inbox.

**Ledger candidates for the lead (out of scope, same root cause as DW-2092):**

- The shared "<n> rows" (`tableRowCount` through `formatRowCount`) reads "1 rows" on the data table footer, the command bar's match count, the context chip and the agent ledger page.
- The class and routine lists' export status reads "Saved 1 documents as <file>." (`code-list.page.spec.ts`:540).

**Footprint (Rule 11), checked against `.worktrees/epic-18` at `63f1a2f7`:**

- **`footprint_extensions`, add-only (lead ruling; Epic 18's areas, Epic 18 paused):**
  - the nine OS management descriptors (`DatabaseDetails`, `DatabaseVolumeList`, the three mapping lists, `JournalFileDetails`, `JournalFileDatabaseList`, `LanguageServerActivity` and `ProcessDetails`) and the three Tasks descriptors (`TaskDetails`, `TaskRunList` and `TaskHistoryList`);
  - `WalletSecretList`, which Story 18.24 may edit (inference);
  - their tests `MappingDescriptor.cls` and `LanguageServer.cls`.
- **Outside `paths_hint`** (`footprint_extensions`): EXPERIENCE.md, rows :597 and :599. Epic 18 edits :168, :173, :364 and :516.
- **Contended, add-only:** `SurfaceCoverage`'s rows, `strings.ts` (18.23 adds keys elsewhere) and `screens.generated.ts` (regenerate, never hand-merge).
- **Contended, not add-only:** `ui/angular.json` with its test (both branches re-base), and `strings.test.mjs`'s bound.

## Verification

Load source into `ocupilot-a2-ci` and never restart it:

1. `rsync -a --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-19/src/ /tmp/ocupilot-a2-ci/src/`
2. In `docker exec -i ocupilot-a2-ci iris session iris -U HSCUSTOM`, run `$System.OBJ.LoadDir("/opt/ocupilot/src","ck",.tErrors,1)`, then check the status and `tErrors`.

**Stateful test classes run one at a time**, each landing in `%UnitTest_Result` before the next. Never re-submit after a client-side timeout. Every probe document, proposal and governance setting is removed or restored, as the classes already do.

**Commands:**

- `uv run scripts/check-objectscript.py && uv run scripts/test_check_objectscript.py` (loop): expected green.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-a2-ci --class OcuPilot.Test.<Class>` (loop), one class per call: expected green. Run it for:
  - `CriterionHints`, `ExplorerWrite`, `ExplorerDescriptor`, `SurfaceCoverage`;
  - `MappingDescriptor`, `LanguageServer`, `JournalDescriptor`, `CriteriaCorpus`;
  - `ReadTool`, `ToolEmit`, `ToolWire`, `GeminiEmptyEnum`, `ExplorerTransfer`.
- `cd ui && node tools/screen-mirror.mjs --check && npm run test:tools && npx ng test --include 'src/app/areas/system-explorer/**/*.spec.ts'` (loop): expected green.
- `bash scripts/lint-docs.sh && cd ui && npm run test:tools` (loop, after the EXPERIENCE.md edit): expected green.
- Browser (loop):
  - Build and deploy first: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-a2-ci:/durable/iris/csp/ocupilot/`. Record the measured initial total for the budget task.
  - Then run each file alone with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52780 OCUPILOT_BROWSER_CONTAINER=ocupilot-a2-ci node --test --test-concurrency=1 browser/<file>` for `agent-sql`, `system-explorer-data-browser-chords`, `system-explorer-data-browser-tabs`, `system-explorer-data-browser-edit` and `system-explorer-sql-query` (`.browser-spec.mjs`): expected green.
- `cd ui && npm test` (once, before dev_complete): expected green, with the budget re-based.
- The full browser suite (once, before dev_complete) is CI's three `browser-shard` jobs on fresh throwaways, not run locally (Rule 29).
- `cd ui && node tools/ci-runner.mjs --container ocupilot-a2-ci`, the full ObjectScript sweep, one class at a time (once, before dev_complete): expected green apart from residue already in the ledger (19.11 recorded `WireSecurityRead`, DW-1554, and `Retention`, DW-1929).

**Mutations (Rule 19)**, each applied on `ocupilot-a2-ci` (classes recompiled, bundle rebuilt and redeployed for the browser ones), observed red and reverted byte-identical (`cmp`):

- mutation: DW-1001 roster: deleted `ExplorerSqlTable`'s `hint`. Observed red: `CriterionHints.TestEveryTextCriterionHasAHintOrIsACommaList`, naming `explorer.sqltable.read:table` (run 2171).
- mutation: DW-1001 emitted: `AddCriteria` ignores `hint` for a `text` criterion. Observed red: `TestAHintedCriterionIsDescribedByItsHint` (run 2172).
- mutation: DW-1001 parent: `DatabaseDetails`'s hint pointed at `osmgmt.namespaces.read`. Observed red: `TestAParentScopedHintNamesTheParentsRead` (run 2173).
- mutation: DW-1945 dispatch: `ADVERTISED` 0 on `ExplorerClassCompile`. Observed red: `ExplorerWrite.TestTheAgentCompilesThroughConfirm` and `TestOcuPilotsOwnCodeIsRefusedOnBothCallers` (run 2174), and `ExplorerDescriptor`'s roster (run 2175).
- mutation: DW-1945 governance: `explorer.classes.delete` true in `Baseline.cls`. Observed red: `ExplorerWrite.TestTheAgentsDeleteIsGovernedAndThenConfirmed` and `TestTheBaselineShipsTheDeletesDisabled` (run 2176).
- mutation: DW-2092 data browser: the shared chooser never takes the singular. Observed red: `data-browser-model.test.mjs`, then, after rebuild and redeploy, 2 of 4 tests of `system-explorer-data-browser-tabs.browser-spec.mjs`.
- mutation: DW-2092 console: `statusLineFor` drops the `explorerSqlRowsChangedOne` branch. Observed red: `sql-answer.test.mjs` (1 failed) and, after rebuild and redeploy, `agent-sql.browser-spec.mjs` (1 failed).
- mutation: DW-2092 saved summary: `data-browser.store.ts` builds the line without `savedSummaryText`. Observed red: `data-browser.page.spec.ts` 'a save of exactly one change reads singular in the status line' (1 failed of 37).
- mutation: DW-2093: renamed the method and left the rows. Observed red: `SurfaceCoverage.TestEveryCoverageRowNamesATestTheSuiteExecutes` (run 2177).

## Auto Run Result

Status: done
Blocking condition: none

Summary: 36 hints (35 descriptors) and `Test/CriterionHints`; `ExplorerWrite` compile and delete legs through `Dispatch.Answer`; `ExplorerDescriptor` method renamed with its eight `SurfaceCoverage` rows; singular count sentences in the data browser and SQL console (13 literals, `data-browser-model.ts` and `sql-answer.ts` helpers, EXPERIENCE.md rows :597/:599); `angular.json` warning re-based 2987kB to 2992kB (measured 2,991,592 bytes); Fixed strings 2,718, bound 2,800 unchanged.

Review: 7 findings, 1 patched (jsdom case for a one-change save, with its mutation line), 0 deferred, 6 rejected with reasons in the triage log. Follow-up review recommended: false (patched 0 high, 1 medium).

Verified: `check-objectscript.py` and its harness; targeted classes green on `ocupilot-a2-ci` (runs 2157-2169, `CriterionHints` 3 tests); `npm test` (1841 tools, 2533 component tests, plus the new one); five browser specs one at a time; eight-plus-one mutations observed red. Full ObjectScript sweep once: 481 classes, 3,870 tests, 1 failed, only known residue (`WireSecurityRead` DW-1554 and the six unarmed encryption classes). Full browser suite left to CI (Rule 29). Outside the spec's file list: five browser specs, three component specs, `ui/tools/angular-json.test.mjs`.
