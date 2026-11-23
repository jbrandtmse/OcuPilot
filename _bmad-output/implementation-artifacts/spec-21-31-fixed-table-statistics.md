---
title: 'Story 21.31: Fixed table statistics'
type: 'feature'
created: '2026-11-23'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-21-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-21-25-index-rebuild-and-tune-table.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Story 21.25 gave System Explorer the classic Tune Table window's collect, clear and rebuild, but not its edits: a person still needs the classic page to fix a table's extent size, a field's selectivity or a map's size.

**Approach:** Add the three setters as confirmed writes through `SqlPort`'s `Tables` endpoint, on 21.25's table-write base, each reached by the screen and by the agent. Set extent size is a page action on the Table info tab, Set map size a row action on the Indices tab, and Set selectivity a row action on the Field statistics tab, which moves to a new `sql-field` entity type.

## Boundaries & Constraints

**Always:**

- Each write is one operation with two callers, the screen action and the agent's confirmed proposal (AD-53). It runs in the confirm or action request, never in a job (AD-7, line 246). Names reach the vendor bare, as method arguments, and values only after their shape check. Nothing is concatenated into SQL or code (AD-21).
- A table in an `OcuPilot` schema, or whose class name begins with `OcuPilot` in any case, is refused `PROHIBITED.OCUPILOTTABLE` from either caller before any write. The target is resolved at the write, and a failed resolve refuses (AD-10, line 411).
- Every test makes its own probe through `SqlTuningProbe` and removes it through the product's Clear fixed statistics tool. It purges the probe tables' cached queries before dropping them. No test asserts that a store is empty.

**Never:**

- No `KeepClassUpToDate`: the port passes 0 (AD-51, line 1271). No histogram edit and no `SamplePercent`.
- No probe schema or table whose name holds `"` (DW-2851: the vendor's last-table drop breaks `INFORMATION_SCHEMA.SCHEMATA`). A delimited name that only needs quoting, such as 21.25's `OcuProbe225 Delim`, is allowed.
- No edit to `Api/Error.cls`; new codes go in `Api/AtelierError.cls`. The spine stays add-only. No test or write runs on `ocupilot` or a slot instance.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Set extent size | A probe table, `ExtentSize` 5000 | `TABLESTATS` reads 5000, `StatsKind` `fixed`; read-back holds | none |
| Set selectivity | A probe field, `Selectivity` `2.5%` | `FIELDSTATS` `Selectivity` reads `2.5%` | none |
| Omitted outliers | Selectivity set, outlier values not declared | The field's fixed outlier selectivity, outlier value and average size are unchanged | none |
| Set map size | A probe map, `SizeMB` 3 | The map's size reads 3 | none |
| Collected first | A probe whose statistics are collected, not fixed | After the set, the other fields and the extent size still read their collected values, now as fixed (Task 0 (d)) | none |
| Bad value | Extent size negative, fractional, empty or over 10^12; selectivity outside its shape; map size negative or fractional | 400 with the shape sentence before any write, from both callers | none |
| Own table | `OcuPilot_Kernel_State.Turn` and one of its fields and maps | `PROHIBITED.OCUPILOTTABLE` from both callers, nothing changes | A failed resolve refuses |
| Absent field or map | A name the table does not hold | 400 `PORT.VALIDATION` before any write | none |
| Changed target | Statistics collected after the mint | Confirm refuses `PROPOSAL.TARGETCHANGED`, writes nothing | none |
| Gate | No `%Development:USE` or no `AtelierPort.WritePairs` | 403 naming the pair, before any read or write | none |
| Vendor refusal | The seam returns an error status | 409 `SQL.TABLE.VENDOR`, its message in `detail` only | none |
| Delimited name | Schema `OcuProbe225 Delim`, table `Probe Table` | Each setter round-trips through both callers | none |

</intent-contract>

## Code Map

- **Classic source (read-only):** `irislib/%CSP/UI/Portal/SQL/TuneTable.cls`. `SaveData` :582 runs `FixTableStats` when the statistics are collected, appends `%` to a selectivity, then calls `SetFieldSelectivity`. `SaveMap` :591 and `SaveTableSize` :643 do the same with `SetMapBlockCount` and `SetTableExtentSize`. The field query is at :752 and the map query at :760; the map query's columns are `SIZE_MB`.
- **Vendor setters:** `%SQL.Manager.Catalog` is hidden and its setters are `[ Internal ]`. Their bodies are not served (`GetTextAsArray` on `ocupilot-ci` answers the signatures only). The signatures are `SetTableExtentSize(pSchema, pTablename, pExtentSize, pKeepClassUpToDate=0)`, `SetFieldSelectivity(pSchema, pTableName, pFieldName, pSelectivity, pKeepClassUpToDate=0, pOutlierSelectivity="", pOutlierValue="", pAverageFieldSize="", pHistogram="")` and `SetMapBlockCount(pSchema, pTableName, pMapName, pBlockCount As %String, pKeepClassUpToDate=0)`. What each does must therefore be measured (Task 0).
- `src/OcuPilot/Port/SqlPort.cls`:
  - Parameters: `COMPOSEDTYPES` :66 and `TABLEWRITES` :120.
  - `TablesInvoke` :1167 (order: 501, gate, shape, resolve, call) and `TableTarget` :1259.
  - `TableFacts` :1286, the place to add a map's size and a field's row.
  - `TableAnswer` :1361, `TableWrite` :1385, `TableWritten` :1407.
  - The seam `TableCall` :1434, which the fixture overrides, and `TableSnippet` :1494 (AD-59).
  - `Literal` :2089 and `TuneValues` :1210, the value-check precedent.
- `src/OcuPilot/Port/AtelierPort.cls` -- `CATALOGFIELDSTATISTICSQUERY` :221, `CATALOGFIELDSTATISTICSCOLUMNS` :280, and `CatalogRows` :1465, which names `Table` on index rows only.
- **Tool siblings:**
  - `Screen/Tool/SqlTableAction.cls`: target `Schema.Table`, `RefusedBeforeState`, `CLASSICPAGES`, no state row.
  - `SqlTableTuneAction.cls`: declared values in the query, fingerprint, `ArgumentProblem` and `ScreenActionDelta`; booleans only.
  - `ExplorerSqlIndexRebuild.cls`: composite id, `NameOf`, `MintClass`.
  - `SqlIndexMint.cls`: a `MappingMint` subclass.
  - `ExplorerSqlTableClearStatistics.cls`: the tool the tests restore through.
- **Kernel:**
  - `Kernel/Proposal/Prohibited.cls`: `TYPESQLINDEX` :205, `COVEREDTYPES` :338, the table dispatch :1831 and `TableEntry` :3713, which needs `Table` and `Class` in the fresh read.
  - `Kernel/EntityType.cls`: `TYPES` :174 and the doc comment :165.
  - `Kernel/Governance/Baseline.cls` :253-257.
- **Descriptors:** `Screen/Descriptor/ExplorerSqlTable.cls` (page actions), `ExplorerSqlIndices.cls` (composite `[Table, Map]`, row action `rebuild`), `ExplorerSqlFieldStatistics.cls` (`entityType` `class`, id `single`, no row action, `emptyAgentKey` empty).
- **Client:**
  - `ui/src/app/shell/screen-action-handler.ts`: `SCREEN_ACTION_DESCRIPTORS` :174, `UNDRAWN_ACTIONS` :627, `WARNING_CONSEQUENCES` :1127, `WarningValue` :1177 (flag or whole-number field) and `WARNING_VALUES` :1184. The value is sent at :1530 and drawn at :1767.
  - `shell/warning-dialog.ts` already draws a text field (`fieldKind: 'text'`, used by the allowed-directory dialog).
  - `core/screen-actions.ts` :210-217, `core/proposal-view.ts` :779-782 and `core/strings.ts` :5563-5594.
  - `areas/system-explorer/sql-table.page.ts` with `route-target-actions.ts`.
- **Tests to extend:** `Test/SqlTuningProbe.cls`, `Test/SqlTableTune.cls` (the tab test), `Test/SqlTableRead.cls`, `Test/SqlIndexRebuild.cls`, and `ui/browser/system-explorer-sql-tuning.browser-spec.mjs`.

## Tasks & Acceptance

**Execution:** Task 0 first, then two batches, each committed on its own. A handoff builds one batch. Strings are only the ruled set (Design Notes, "Strings, escalated"); any other sentence a person reads is `## Clarification Needed`.

**Task 0, measured on `ocupilot-ci` before code.** Use probe tables of under 1,000 rows. Record each result in Design Notes. Restore every value, then remove every probe and read it back absent.

- (a) Is `SetMapBlockCount`'s value in MB, as the classic column says? Read it back through `%SQL_Manager.MapBlockCount` and the Indices row's `SizeMB`, and say whether the two agree.
- (b) Which `Selectivity` and `OutlierSelectivity` texts the vendor accepts and how each reads back: `1`, `2.5`, `2.5%`, `0%`, `99.999%`, `100%`, `0.0001%`.
- (c) Whether an `OutlierValue` holding quotes and parentheses is stored as data and never run.
- (d) A set on a table with collected statistics, with and without `FixTableStats` first. Does the extent size and every other field read its collected value afterwards, or a default? Repeat on a table with no statistics.
- (e) Whether the port's Collect statistics (`TUNE`, `ClearValues` 0) keeps each set value, and whether Clear fixed statistics removes each.
- (f) Whether passing a field's current fixed outlier values back leaves them unchanged, and what `""` does.
- (g) Each setter with the bare names of `OcuProbe225 Delim`.`Probe Table`.

**Batch 1, server.**

- `src/OcuPilot/Port/SqlPort.cls`:
  - Add the read `FIELDSTATS`: target composite `[Table, Field]`, answering `{Namespace, Table, Class, Field, Selectivity, OutlierSelectivity, OutlierValue, AverageFieldSize, StatsKind, HasFixed}`. Each value is the one in use, the fixed one when the table has fixed statistics and the collected one otherwise, as `TABLESTATS`'s `ExtentSize` is. A field the table does not hold is 400 `PORT.VALIDATION`.
  - Add `SizeMB` to `INDEX`'s answer, by the same rule.
  - Add the writes `SETEXTENT` (`Schema.Table`), `SETSELECTIVITY` (`[Table, Field]`) and `SETMAPSIZE` (`[Table, Map]`) to `TABLEWRITES` and `COMPOSEDTYPES`. Each value is checked against Design Notes' shapes before any call (a `TuneValues` sibling).
  - In `TableCall`, call `FixTableStats` first when `StatsKind` is `collected` (unless Task 0 (d) shows it is not needed), then the setter with `KeepClassUpToDate` 0. A selectivity's undeclared outlier values are the field's fixed values read just before the call.
  - Add each setter to `TableSnippet`, every name and value through `Literal`.
- `src/OcuPilot/Port/AtelierPort.cls` -- `CatalogRows` names `Table` on `Catalog.FieldStatistics` rows too.
- `src/OcuPilot/Api/AtelierError.cls` (add-only) -- consequence codes `SQL.TABLE.SETEXTENTSIZE`, `.SETSELECTIVITY` and `.SETMAPSIZE`, which share one sentence, and the shape sentences.
- `src/OcuPilot/Screen/Tool/SqlTableTuneAction.cls` -- add hooks whose defaults keep today's boolean behavior: `REQUIREDVALUES` (default every `VALUENAMES`), `ValueProblem(name, value)` and `QueryValue(name, value)`.
- New `src/OcuPilot/Screen/Tool/SqlTableSetAction.cls` (abstract, extends `SqlTableTuneAction`) -- typed values and their shape checks.
- New `ExplorerSqlTableSetExtentSize.cls` (`explorer.sqltable.setextentsize`, `ExtentSize`, `SCREENVALUES` `set-extent-size=ExtentSize`).
- New `ExplorerSqlIndexSetMapSize.cls` (`explorer.sqlindices.setmapsize`, `SizeMB`, `MintClass` `SqlIndexMint`, `NameOf` as in `ExplorerSqlIndexRebuild`).
- New `ExplorerSqlFieldSetSelectivity.cls` (`explorer.sqlfieldstatistics.setselectivity`) -- `Selectivity` required, and `OutlierSelectivity`, `OutlierValue` and `AverageFieldSize` optional. `SCREENVALUES` is `set-selectivity=Selectivity`.
- New `src/OcuPilot/Screen/Tool/SqlFieldMint.cls` -- a `SqlIndexMint` sibling over `MappingMint` for `[Table, Field]`.
- Each new tool reads with a read type that answers the declared value's field. The merge then shows the old and new value on the card. Each declares `CONSEQUENCECODE` and the `CLASSICPAGES` it inherits.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` and `Kernel/EntityType.cls` (add-only) -- `sql-field` (composite `Table`, `Field`, exact, namespace-scoped). It joins `COVEREDTYPES`, gets a `TYPESQLFIELD` parameter, and is sent to `TableEntry` beside `sql-index`.
- `src/OcuPilot/Kernel/Governance/Baseline.cls` (add-only) -- the three keys `false`.
- Descriptors:
  - `ExplorerSqlTable` gains the page action `set-extent-size`.
  - `ExplorerSqlIndices` gains the row action `set-map-size`.
  - `ExplorerSqlFieldStatistics` moves to `entityType` `sql-field`, with id composite `["Table", "Field"]` and `Table` in its read and context fields. It gets the row action `set-selectivity`, `"emptyNextKey": ""`, `emptyAgentKey` `explorerSqlSchemaTuneEmptyAgent` ("tune table", already published) and `commandAliases` `["table statistics"]`.
- `src/OcuPilot/Test/SqlTuningProbe.cls` -- a helper that sets a field's or a map's fixed value through the vendor, for preconditions only.
- New `src/OcuPilot/Test/SqlTableFixedStats.cls` (live-safe, under 500 lines) -- the matrix rows on both callers. Each set value is restored through `explorer.sqltable.clearstatistics`, and the changed `TableCall` is pinned through the seam.
- Update every shared-surface test under Verification, with names read from the instance. That includes the rosters `ConfirmNamespaceRoster`, `CompositeMintSweep` (`SqlFieldMint`) and `MappingDescriptor`'s `CLASSICROSTER`.

**Batch 2, client.**

- `shell/screen-action-handler.ts` (add-only):
  - `WarningValue` gains `kind: 'text'`, drawn as the dialog's text field. Proceed stays unavailable while it is empty.
  - `WARNING_VALUES` gains `set-extent-size` and `set-map-size` (whole-number fields) and `set-selectivity` (text). Each field's hint is its shape sentence.
  - The three actions join `WARNING_CONSEQUENCES` and `UNDRAWN_ACTIONS` as their siblings do, and `ExplorerSqlFieldStatistics` joins `SCREEN_ACTION_DESCRIPTORS`.
  - The shape sentences join `PUBLISHED_PROBLEMS`.
- `areas/system-explorer/sql-table.page.ts` -- register `set-extent-size` through `registerRouteTargetActions`.
- `core/screen-actions.ts`, `core/proposal-view.ts` and `core/strings.ts` -- the labels, the three consequence codes and the ruled strings.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` -- one add-only Fixed strings row for 21.31. Regenerate the mirror and `Titles.cls` (`node tools/screen-mirror.mjs`).
- `ui/browser/system-explorer-sql-tuning.browser-spec.mjs` -- two new steps:
  - Set extent size on the Table info tab reads back.
  - Set selectivity on the Field statistics tab reads back in its row.

  Each step waits for the answered signal. The `after` hook clears fixed statistics, purges the probe's cached queries and drops the probe.

**Acceptance Criteria:**

- AC1. Given a probe table, when either caller sets its extent size, a field's selectivity or a map's size and confirms, then the value reads back as sent by the time the confirm answers. The card showed the old and the new value, and a declared-but-omitted outlier value is unchanged.
- AC2. Given a value outside its shape, when either caller sends it, then it is refused before any vendor call. The screen shows the published shape sentence.
- AC3. Given a table of OcuPilot's own, when either caller attempts any of the three setters, then each is refused with the published sentence and the table's statistics are unchanged.
- AC4. Given a probe table, when the person opens the Field statistics tab and the agent calls `explorer.sqlfieldstatistics.read`, then both answer the same rows, each naming its `Table`, and a row's id is `[Table, Field]`. A stored `class` reference to the table still resolves to the class screen.
- AC5. Given the throwaway, when the tuning browser spec runs forward and in reverse with `system-explorer-sql.browser-spec.mjs`, then it passes and leaves no probe schema, table, statistic or cached query.

## Spec Change Log

- 2026-11-23, orchestrator ruling at the spec gate (veto U-151), authoritative:
  - **`sql-field` accepted.** Append it at the end of EntityType TYPES and Prohibited COVEREDTYPES, and extend the existing `tType` guards by prefix rather than rewriting them. The self-protection arm judges a [Table, Field] row by its Table part through `TableEntry`, so an OcuPilot table refuses `PROHIBITED.OCUPILOTTABLE` (pinned by a test). AC4 (an old `class:` citation still opens the class screen) stays. If Epic 24 appends types first, this story's entries go after feature's and the order is re-checked against the pinned tests.
  - **Strings accepted as written**; measure-first clauses ship only as measured, and any correction is reported verbatim. The extent-size upper bound (1,000,000,000,000) is a named constant with a boundary test (at the limit accepted, one over refused); Task 0 measures whether the vendor itself accepts 0 and accepts that limit. "Map size (MB)" or "(blocks)" follows the measured unit. "Enter at most 128 characters." is model-facing only.
  - **AD-51 add-only** (written by the runner, `ARCHITECTURE-SPINE.md` after :1271): the reads, the optional outlier values, and the ordering rule. The `FixTableStats` sentence is appended by the runner only if Task 0 (d) measures it needed.
  - **`FixTableStats` ordering:** it runs only inside the confirmed write, after the prohibited check and the value-shape check, never at mint or preview, so a refused or ill-shaped value changes nothing (pinned: a refused value leaves the collected statistics unfixed). If the set fails after `FixTableStats` succeeded, the outcome says so rather than reading "nothing changed".
  - The stage's decisions stand: Set selectivity on the screen asks for the selectivity only (the agent may send the subset); all three keys ship `false`; no `"`-named schema in tests (DW-2851).

## Review Triage Log

## Design Notes

**Governing ADs (spine line ranges):**

- AD-6 and AD-34 (fingerprint, single transition), and AD-7 :211-251 (its 21.25 paragraph at :246 covers "a fixed-statistics change").
- AD-10 :385-452 (the 21.25 table arm at :411 already names these three setters), AD-13 (composite ids) and AD-14.
- AD-15, AD-16, AD-21, AD-22 and AD-29 :784-799 (the gate is `%Development:USE` plus `AtelierPort.WritePairs`; 21.25 Task 0 (c) measured that the setters need `%DB_<ns>:RW`).
- AD-36 :864-925 (one read for the tab and the tool), AD-39 and AD-44.
- AD-51 :1202-1272 (the 21.25 case at :1269 names `FIELDSTATS`, the three setters and their declared arguments; :1271 rules out `KeepClassUpToDate`).
- AD-52 :1273-1304, AD-53 :1305-1346, AD-56 :1376-1389, AD-58 :1402-1411 and AD-59.

**AD record for the runner** (Rule 20, add-only, proposed text). Append to AD-51 after :1271:

> "Story 21.31's case: before a setter, when the table's statistics are collected, `SqlPort` calls `$SYSTEM.SQL.Stats.Table.FixTableStats` for the table, as the classic page does. `INDEX` answers the map's `SizeMB` and `FIELDSTATS` answers one field's row, each the value in use. A selectivity's outlier selectivity, outlier value and average size are optional. An omitted one is the field's fixed value read just before the call."

Drop the first sentence if Task 0 (d) shows `FixTableStats` is not needed. Recommendation: allow.

**Decided in-stage:**

- **The Field statistics tab moves to `sql-field`.** A tool's target type is its descriptor's primary type (`Operation.TargetRefOf`), so under `class` the class arm would judge `[Table, Field]` as a class name. 21.25 moved the Info, Indices and Schema tabs for the same reason.
  - **Consumers of its type, from a grep over `src`, `ui/src`, `ui/tools` and `ui/browser`:**
    - Server: `ExplorerDescriptor` :62 (roster row literal `"class"`), `Descriptor` :201, `ReadTool` :94, `StageTwoTools` :212, `DeveloperFloor` :45, `SurfaceCoverage` :188, `ToolRoundTrip` :118, `AtelierPortCatalogTabs` :267 (row shape) and `SqlTableTune` (the tab test).
    - Client: `core/navigation.ts` :595, :602 and :708 (screens found by `entityType`), `core/citations.ts` :96, `screens.generated.ts`, `screen-mirror.test.mjs` :1070, :1610 and :3278, `navigation.test.mjs` :391, `detail-page.spec.ts` :297 and `system-explorer-sql.browser-spec.mjs` :299.
  - **Stored rows keyed on it:** none. The tab has had no write, so no proposal, ledger or audit row names it. Screen permissions and preferences are keyed by route, not by type. A conversation's stored `class:<Schema.Table>` citation keeps resolving to the class screen. It is not rewritten or migrated, and the new type only adds a navigation target. AC4 pins that an old `class` reference is still accepted.
- **The screen's Set selectivity asks for `Selectivity` alone**, because the warning dialog takes one value (`WarningValue`). The agent may also send the three outlier values. AD-56 lets a screen action send a subset of the declared values.
- **Calls follow the classic page.** `FixTableStats` runs first on collected statistics, `%` is appended to a bare selectivity, and `KeepClassUpToDate` is 0.
- **Value shapes** (Task 0 (a), (b) may correct them):
  - `ExtentSize`: a whole number from 0 to 10^12.
  - `Selectivity` and `OutlierSelectivity`: `1`, or a percentage over 0 and up to 99.999, with or without `%`.
  - `AverageFieldSize` and `SizeMB`: whole numbers, 0 or more.
  - `OutlierValue`: at most 128 characters with no control character.
- **Keys:** all three `false`, as 21.25 decided: a fixed value overrides what the optimizer measures. None is destructive.
- **The own-table refusal** reuses the published `OCUPILOTTABLE` sentence; the setters are the Tune Table window's edits.
- **The fixture** never creates a `"`-named schema (DW-2851). One leg uses 21.25's `OcuProbe225 Delim` (a space), which pins the bare-name passing that DW-2847 settled.

**Strings, escalated as one batch for the spec gate** (none is in EXPERIENCE.md yet). Factual claims marked *measure-first* are measured at Task 0 and ship only as measured. A correction is reported verbatim.

1. **Actions:**
   - "Set extent size", the Table info tab's page action (sibling: "Collect statistics").
   - "Set selectivity", the Field statistics tab's row action (sibling: "Rebuild index").
   - "Set map size", the Indices tab's row action (sibling: "Rebuild index").
2. **Value labels:**
   - "Map size (MB)" is new (sibling: "Initial size (MB)"). *Measure-first* (Task 0 (a)): if the value is in blocks, the label is "Map size (blocks)".
   - Reused, already published: "Extent size", "Selectivity", "Outlier selectivity", "Outlier value" and "Average field size".
   - "Clear values" is published by 21.25, and 21.31 adds no use of it.
3. **Consequence**, shared by the three setters (sibling: Clear fixed statistics' sentence):
   - Starting point: "The optimizer uses this value for the table until statistics are collected again." This is **contradicted** by 21.25 Task 0 (g): a fixed 777 stayed after a collect with `ClearValues` 0, which is what the port's Collect statistics passes.
   - Proposed instead: "The optimizer uses this value in place of the collected one until the table's fixed statistics are cleared. If the table's statistics were collected, they are first saved as its fixed statistics." *Measure-first:* (e) a collect keeps each set value and Clear fixed statistics removes it; (d) `FixTableStats` saves the collected values as fixed. If (d) drops `FixTableStats`, the second sentence goes.
4. **Shape refusals**, shown as the server sends them (AD-39), and each also the dialog field's hint (sibling: "Older than (days) is a whole number from 0 to 99999."):
   - "Enter a whole number from 0 to 1,000,000,000,000." (extent size)
   - "Enter 1, or a percentage over 0% and up to 99.999%." (selectivity) *Measure-first* (Task 0 (b)).
   - "Enter a whole number, 0 or more." (map size, and the agent's average size)
   - "Enter at most 128 characters." (the agent's outlier value) Recommended model-facing only: no screen collects it.
5. **Alias:** "table statistics", on the Field statistics tab (sibling: "tune table"). The tab's empty-state agent phrase reuses the published "tune table", so no new phrase is needed.

**Extend, don't copy (Rule 2/31):**

- `SqlTableSetAction` extends `SqlTableTuneAction` through three new hooks; the boolean defaults are unchanged.
- `SqlFieldMint` is `SqlIndexMint`'s sibling over `MappingMint`; it is a copy because its two description parameters differ.
- The port reads and writes extend `TableFacts`, `TableWrite`, `TableCall` and `TableSnippet` rather than adding a seam.
- The dialog's text kind reuses `warning-dialog.ts`'s existing text field.

**Integration ACs:** the three tools are `SqlPort`'s consumers through both callers (AC1 to AC3), and the agent's read consumes the tab's read (AC4).

- **Consumed-by:** none beyond this story.
- **Consumes:** Story 21.25's `Tables` endpoint, `SqlTableAction`, `SqlTableTuneAction`, `SqlIndexMint`, `SqlTuningProbe`, the Field statistics read and Clear fixed statistics.

**Ledger inbox:** none (`LEDGER slice 21-31-fixed-table-statistics` is empty). DW-2847 and DW-2848 are resolved by 21.25. DW-2851 is a constraint here, not owned.

**Context sources.** The epic context was reused as the plan block directs, although planning files have newer commits. epics.md :9673-9685 and the spine ranges above were read directly. The continuity story is 21.25, not 21.30, which is unrelated.

**Contended paths** (Epic 24), checked 2026-11-23 with `git log origin/OCU-1-epic24 ^origin/feature/OCU-1_ocupilot-mvp`: 0 commits on every path in the Code Map and the rosters.

## Verification

**Shared surfaces** (all `(loop)`):

- The table tab group: `ExplorerDescriptor`, `Descriptor`, `screen-mirror.test.mjs`, `navigation.test.mjs`, `detail-page.spec.ts` and `system-explorer-sql.browser-spec.mjs`.
- The tool registry: `ReadTool`, `ReadDescriptions`, `ToolEmit`, `ToolRoundTrip`, `ToolWrite`, `StageTwoTools`, `DeveloperFloor`, `SurfaceCoverage` and `DraftRegistry`.
- Entity types: `EntityRef` and `Prohibited`'s covered types.
- Governance: `Governance` and `GovernanceBaseline`.
- Gates and catalog: `PortGate`, `ClassicPageGate`, `AtelierPortCatalogTabs`, `AtelierPortCatalogTabsLive` and `EndpointCoverage`.
- Rosters: `ConfirmNamespaceRoster`, `CompositeMintSweep` and `MappingDescriptor`.
- 21.25's tests on the changed `INDEX` and field rows: `SqlTableRead`, `SqlTableTune` and `SqlIndexRebuild`.
- Client tools: `self-protection.test.mjs`, `proposal-view.test.mjs` and `suggested-prompts.test.mjs`.

Grep `ui/browser`, `ui/tools`, the `ui/src` specs and `src/OcuPilot/Test` for each surface; each test changed joins `(loop)`.

*Every test added or changed passes on a fresh environment, in either order.*

**Commands.** Each runs in its own foreground call with `timeout: 600000`, against `ocupilot-ci` only, one test call per message.

- `(loop)` `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/e21-kit/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` -- expected: `LOADERRORS=0`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.SqlTableFixedStats` -- expected: green. Then, one class per call: `SqlTableRead`, `SqlTableTune`, `SqlIndexRebuild`, `Prohibited`, and every shared-surface class above.
- `(loop)` `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh` -- expected: clean.
- `(loop)` `cd ui && node --test tools/screen-mirror.test.mjs tools/navigation.test.mjs tools/self-protection.test.mjs tools/proposal-view.test.mjs tools/suggested-prompts.test.mjs` -- expected: green.
- `(loop)` `cd ui && npm run build`, then `npm run test:components`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/system-explorer-sql-tuning.browser-spec.mjs browser/system-explorer-sql.browser-spec.mjs` -- expected: green, and green in reverse order.
- `(once)` `cd ui && npm run test:tools` -- expected: green (EXPERIENCE.md changes).
- `(once)`, runner-owned: the full ObjectScript sweep one class per call, `smoke.sh --container ocupilot-ci`, and Rule 30's fresh check. The full browser suite is left to CI.

**Mutations (Rule 19).** One per AC. Each is applied, observed red and reverted, the tree is confirmed identical, and the source is reloaded.

- AC1: `TableCall` passes the old value for `SETEXTENT`; the omitted-outlier read is skipped -> `SqlTableFixedStats` red on read-back.
- AC2: the selectivity shape check accepts anything -> red on the shape legs.
- AC3: `Prohibits` does not send `sql-field` to `TableEntry` -> red on both callers.
- AC4: `CatalogRows` stops naming `Table` on field rows -> the tab test red.
- AC5: `ExplorerSqlFieldStatistics` loses its `set-selectivity` row action -> the browser spec red, after rebuild and redeploy.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
