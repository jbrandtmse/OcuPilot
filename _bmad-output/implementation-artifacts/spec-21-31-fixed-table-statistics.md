---
title: 'Story 21.31: Fixed table statistics'
type: 'feature'
created: '2026-11-23'
status: 'done'
baseline_revision: '253a19794db11e9dfe2f3ff7210d8bc0b0eaa023'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-21-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-21-25-index-rebuild-and-tune-table.md'
warnings: ['oversized']
deferred:
  - summary: >-
      TestAnOutlierValueIsNeverRun's marker is read only in USER and has no positive control showing it detects an expression the vendor ran.
    evidence: |-
      The recorded mutation reddens all four code legs, which the verdict and mint parts alone explain. Task 0 (c) measured the execution once, in HSCUSTOM. A positive control would set a code expression through the vendor on a probe and assert the marker becomes set.
    location: >-
      src/OcuPilot/Test/SqlTableFixedStats.cls
    severity: low
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

### Review Findings

Code review 2026-11-23 (stage `21-31-cr`, Opus). The diff is `16a1401d9..0798022c1`. The spine is read at HEAD `a2ab9a618`, which carries AD-51's amendment `c08b08d38` (orchestrator ruling U-153, recorded after this stage was spawned).

**Rework items** (in-story; the story re-opens for its one iteration):

- [ ] [Review][Patch] HIGH (Rule 6, AD-51 as amended by U-153): the outlier value contract is still "the caller writes a literal" [src/OcuPilot/Port/SqlPort.cls:ValueProblem, OutlierLiteral, SettingCall, SettingSnippet; Screen/Tool/SqlTableSetAction.cls:ValueProblem; ExplorerSqlFieldSetSelectivity.cls:DESCRIPTION, VALUEDESCRIPTIONS; Test/SqlTableFixedStats.cls:TestAnOutlierValueIsNeverRun]
  - The amended rule: the caller sends plain data (at most 128 characters, no control character). The port builds the expression: a canonical number as is, anything else as a quoted literal with its quotes doubled.
  - Today, `'q'` and `q` are refused, and the agent is told to quote text itself.
  - Fix-risk: med. The fix spans the port, the tool, the script and the tests.
  - Before coding, the rework decides how `FIELDSTATS` presents a held value: the instance reads one back in expression form (`"q"`, `1`). An echo of the read must not be quoted twice.
  - The current grammar is safe. Review probe run 1049 tried 21 code-shaped values against the port, the agent's mint and the screen. Every one was refused, with 0 vendor calls and the markers unset. Two doubled-quote literals were stored as data and passed back by both callers without running.
  - Setter-argument audit (ruling `audit_all_setter_args`, measured on `ocupilot-ci`): only `OutlierValue` is evaluated, and the positive control incremented the marker. Selectivity, outlier selectivity, average size, extent size, block count, field name and map name are not run; an average size of `$Increment(^OcuRv)` was stored as text. A delimited field name cannot hold `^` (SQLCODE -1).
- [ ] [Review][Patch] HIGH (Rule 6, AD-51 as amended by U-153): a map size of 0 is accepted, but the amended rule makes it 1 or more [SqlPort.cls:WHOLEPATTERN, ValueProblem; screen-action-handler.ts set-map-size hint; Test/SqlTableFixedStatsCard.cls:TestTheLowerBoundZeroIsAValidValue, TestAMapSizeOfZeroIsSetAndReadBack]
  - Fix-risk: low. `AverageFieldSize` keeps 0.
  - The refusal sentence for "1 or more" is not in the ruled set. The rework takes it from the U-153 package, or escalates it.
- [ ] [Review][Patch] HIGH (U-151 condition; U-153 chose "the U-152 sentence"): a set that fails after `FixTableStats` reads "nothing changed" [SqlPort.cls:TableWritten; ui core/strings.ts, proposal-view.ts, screen-action-handler.ts]
  - Both the screen and the card show `sqlTableRefusalVendor`, "The instance did not apply this change to the table.", while the table's collected statistics are now fixed (`HasFixed` 1). `detail.statisticsFixed` is read by no client code.
  - Sentence proposed by this review, modeled on `explorerSaveNotCompiled` and **not shipped**: "The table's collected statistics were saved as its fixed statistics, but the instance did not apply this change." The rework ships the U-152 text as ruled.
  - The `Catch` arm of `SettingCall` (a setter that throws after the save) is reached by no test. Give the seam a throw arm and pin 409 with `statisticsFixed`.
- [ ] [Review][Patch] MED (AC2, AD-53): the screen's Set extent size and Set map size fields refuse any value over nine digits [ui/src/app/shell/warning-dialog.ts:16 `WHOLE_NUMBER`; screen-action-handler.ts `WARNING_VALUES`]
  - The person cannot set 1,000,000,000 to 1,000,000,000,000. The hint offers those values and the agent can set them.
  - Fix-risk: low. Use the text kind, or a per-field digit bound, and pin the limit on the screen.
- [ ] [Review][Patch] MED (I/O "Changed target", AD-6): Set map size's fingerprint has no `StatsKind`, `HasFixed` or `CollectedAt`, so statistics collected after the mint are not refused [Screen/Tool/ExplorerSqlIndexSetMapSize.cls:READANSWERS, FINGERPRINTSUBJECT; SqlPort.cls:TableAnswer INDEX]
  - Fix-risk: low to med. Add a map leg to `TestAChangedTargetIsRefusedTargetChanged`.
- [ ] [Review][Patch] MED: a held numeric outlier value below 1 is cleared by a later selectivity-only set [SqlPort.cls:OUTLIERNUMBERPATTERN; SettingCall's average-size check]
  - The instance stores the evaluated value. An outlier value of `0.5` is stored as `.5`, which the pass-back pattern rejects, so it is dropped and the instance clears it. The average-size pass-back pattern has the same gap.
  - Fix-risk: low. Accept the canonical form, and pin it with a kept-`0.5` leg.
- [ ] [Review][Patch] MED (Rule 19 hermeticity): the browser spec's Set extent size step waits for `collected`, which only an earlier step's collect makes true [ui/browser/system-explorer-sql-tuning.browser-spec.mjs:279]
  - Run alone, it times out and then passes on `notEqual(restored, 'fixed')`.
  - The Set selectivity step leaves its restore to the `after` hook's direct `ClearTableStats`, not to the product's Clear fixed statistics (Boundaries, Always).
  - Fix-risk: low. Compare with the value the step read before it set, as 21.25's Clear step does.
- [ ] [Review][Patch] MED (I/O "Delimited name"): `TestATableWithADelimitedNameIsSetOnBothCallers` covers 4 of its 6 legs [Test/SqlTableFixedStats.cls:423]
  - The agent's selectivity (through the new `SqlFieldMint`) and the screen's map size are not covered, although the doc comment claims all six.
  - Fix-risk: low.
- [ ] [Review][Patch] LOW: the 21.31 Fixed strings row omits the ruled alias "table statistics", which the descriptor ships [EXPERIENCE.md:631]
  - Add it with the row's other rework edits.
- [ ] [Review][Patch] LOW (AD-59): `SettingSnippet` differs from the write in two ways [SqlPort.cls:SettingSnippet]
  - Its condition for the save is `HasFixedStats` plus a stat object, where the write's is `StatsKind` `collected`.
  - The save's `tSC` is overwritten before it is checked.
  - Bring both in step when the outlier rule changes.

**Patched in this pass:**

- [x] [Review][Patch] LOW: a 409 that saved nothing is pinned to omit `statisticsFixed` [Test/SqlIndexRebuild.cls:TestTheInstancesRefusalIsAnsweredWithItsMessageInDetailAlone]
- [x] [Review][Patch] LOW: the own-table test asserts the extent size was read before it compares [Test/SqlTableFixedStats.cls:TestATableOfOcuPilotsOwnIsRefusedOnBothCallers]
- [x] [Review][Patch] LOW: the selectivity's accepted edges (99.999 with and without `%`, six decimals, `1`) and one step over are pinned [Test/SqlTableFixedStatsCard.cls:TestASelectivityAtItsBoundsIsAValidValue]

**Routed:**

- [x] [Review][Defer] MED (Rule 2/31): `SqlTableSetAction`'s composite-target methods (`IdArgument`, `TargetName`, `NameOf`, `InputSchema`, `IdProblem`) are a parameterized near-copy of `ExplorerSqlIndexRebuild`'s, which 21.25 left in place [Screen/Tool/SqlTableSetAction.cls; ExplorerSqlIndexRebuild.cls:36-84] — deferred: the fix moves them into `SqlTableAction` and touches 21.25's merged tool, so it is routed to burndown (DW-2853).

**Decided:**

- The kernel's `sql-field` own-table arm cannot be reached from a caller. Every OcuPilot class projects to an `OcuPilot_*` SQL schema (`SqlTableName` overrides keep the package schema), so the tool's own-name refusal answers first. `Test.Prohibited`'s pin stands.
- The extent-size boundary (`MAXEXTENTSIZE` accepted, one over refused) is pinned through the agent and the port (`SqlTableFixedStats.cls:214`). Rework item 4 covers the screen's side of it.

**Rejected:**

- `false`: "Enter at most 128 characters." reaches no screen. No screen collects an outlier value, and the screen's Set selectivity refuses one it is sent (probe run 1049).
- `false`: an outlier value without an outlier selectivity "silently does nothing". The tool's description and value text say so.
- `low`, rejected: a JSON-type mismatch from the agent (a string `"5000"` for `ExtentSize`) is refused with the shape sentence. It conforms to the declared schema, and a type-naming branch adds surface.
- `low`, rejected: "Enter 1" means a unique field for Selectivity, while an outlier selectivity of `1` is sent as `1%`. The vendor itself stores an outlier `1` as `1%` (Task 0 (b)).
- `low`, rejected: the own-table test uses `OcuPilot_Kernel_State.Convo`, not `Turn`, and compares only the extent size. Both are OcuPilot tables, and the seam's 0 calls pins that nothing was written.
- `low`, rejected (theoretical): a non-numeric average size coerced to 0, a schema name holding `.`, and a `<Null>` outlier passed back as empty. The instance emits none of these through this path.
- `maybe-false`, rejected: an extent size of 0 may read back as `differs`. Task 0 (f) measured that the vendor accepts 0. If it is wrong, the fix is a one-leg test, which rework item 2 can add.

## Spec Change Log

- 2026-11-23, orchestrator ruling at the spec gate (veto U-151), authoritative:
  - **`sql-field` accepted.** Append it at the end of EntityType TYPES and Prohibited COVEREDTYPES, and extend the existing `tType` guards by prefix rather than rewriting them. The self-protection arm judges a [Table, Field] row by its Table part through `TableEntry`, so an OcuPilot table refuses `PROHIBITED.OCUPILOTTABLE` (pinned by a test). AC4 (an old `class:` citation still opens the class screen) stays. If Epic 24 appends types first, this story's entries go after feature's and the order is re-checked against the pinned tests.
  - **Strings accepted as written**; measure-first clauses ship only as measured, and any correction is reported verbatim. The extent-size upper bound (1,000,000,000,000) is a named constant with a boundary test (at the limit accepted, one over refused); Task 0 measures whether the vendor itself accepts 0 and accepts that limit. "Map size (MB)" or "(blocks)" follows the measured unit. "Enter at most 128 characters." is model-facing only.
  - **AD-51 add-only** (written by the runner, `ARCHITECTURE-SPINE.md` after :1271): the reads, the optional outlier values, and the ordering rule. The `FixTableStats` sentence is appended by the runner only if Task 0 (d) measures it needed.
  - **`FixTableStats` ordering:** it runs only inside the confirmed write, after the prohibited check and the value-shape check, never at mint or preview, so a refused or ill-shaped value changes nothing (pinned: a refused value leaves the collected statistics unfixed). If the set fails after `FixTableStats` succeeded, the outcome says so rather than reading "nothing changed".
  - The stage's decisions stand: Set selectivity on the screen asks for the selectivity only (the agent may send the subset); all three keys ship `false`; no `"`-named schema in tests (DW-2851).

## Review Triage Log

### 2026-11-23 -- Review pass

- verdicts: 8 findings -- high 0, medium 3, low 2, false 0, maybe-false 0, reject 2, defer 1
- findings:
  - `[medium]` `[patch]` The card's old and new value (AC1) is asserted by no test -- a minted proposal's diff is never read; patched by a diff assertion per tool.
  - `[medium]` `[patch]` The lower bound 0 is never validated or set (extent size, map size, average size), and a map size of 0 may read back as a mismatch -- patched by tests for 0.
  - `[medium]` `[patch]` AC4's stored `class` reference clause has no pinning test -- patched by a client test with a `mutation:` line.
  - `[low]` `[patch]` Several mutation claims in the test headers were never observed, and the AC3 plan line says "red on both callers" where only `Test.Prohibited` goes red -- each observed and recorded, the AC3 line corrected.
  - `[low]` `[defer]` `TestAnOutlierValueIsNeverRun` has no positive control that its marker detects execution outside USER -- Task 0 (c) measured the execution once.
  - `[reject]` The Set selectivity browser step asserts the shared table has no fixed selectivity first -- the table is the spec's own probe, the check is a precondition that fails loudly, and `after` restores it.
  - `[reject]` Intent audit: the tests exercise the server entry points, not the rendered tab, for AC1 to AC3 -- descriptive; the browser spec drives two of the three setters end to end and the jsdom specs cover the dialog.
  - `[reject]` Intent audit: Set map size has no browser step -- the spec names two browser steps only.

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

**Task 0 results**, measured on `ocupilot-ci` (HSCUSTOM, schema `OcuMeas31` and `OcuProbe225 Delim`, 2026-11-23; tables of 50 to 300 rows; every value cleared through `ClearTableStats`, every table dropped, none of the schemas' tables, classes or cached queries left; the statement index keeps 20 relation rows for the dropped tables, as 21.25 recorded):

- (a) **`SetMapBlockCount`'s value is a block count, not MB.** One block is 2 KB: 512 blocks read as 1 MB, 1,536 as 3 MB, 512,000,000 as 1,000,000 MB, 1 block as .002 MB, and the classic page converts its MB field with `MB * 1024 / 2` (`TuneTable.cls:364`). `%SQL_Manager.MapBlockCount` and the Indices list's `SIZE_MB` agree in MB for a measured or defined size (`1` and `1 (Defined)`, `.008` and `.008 (Measured)`). They disagree for an estimated one: `MapBlockCount` reads 1334 where the Indices list reads `2.605 (Estimated)`, which is the same count in blocks. The tool therefore declares `SizeMB`, and the port passes `SizeMB * 512`. A map size of 0 blocks resets the map to the measured size (.008 on a 200-row table). The vendor accepts a negative, fractional, empty or text count without error, so the port checks the shape. A map name the table does not hold comes back as an error status (`<UNDEFINED>SetBlockCount`), so the port refuses it first. The data map and the bitmap extent map accept a size like any other.
- (b) **Selectivity texts**, each set on a collected, fixed table and read from `FieldCurrentSelectivity`: `1` reads `1` (unique); `2.5%` reads `2.5000%`; `0.0001%` reads `0.0001%`; `99.999%` and `100%` read `100.0000%`; `30%` reads `30.0003%`; `0%`, `0`, empty and text read empty (the fixed value is removed); `101%` reads `100.9999%`; `-5%` stores a value that makes `FieldCurrentSelectivity` raise `<ILLEGAL VALUE>`, so the port must refuse it. A bare number other than `1` is a row count, not a percentage (`2.5` reads `1.2500%` and `50` reads `25.0000%` on a 200-row table; the vendor's documentation says the same), so the port appends `%` to every value but `1` that lacks it, as the classic page does. `OutlierSelectivity` stores `1` as `1%`, `2.5` as `2.5%`, `0%` as `0%`, `0.0001%` as `.0001%` and text as `0%`. The vendor validates none of it.
- (c) **An `OutlierValue` is evaluated as an ObjectScript expression and run, not stored as data.** `$Increment(^Meas31Cnt)` incremented the global and `1 Set ^Meas31Cnt=99` executed the `Set`; `1+1` stored `2`, `$Piece("a,b",",",1)` stored `"a"`, a plain `q` or `'q'` stored nothing (the value reads `<Null>`), and `"q"` stored `"q"`. A value is stored only after its outlier selectivity; with none, the value is dropped. The classic page's hint reads "use double quotes for a string". The port therefore accepts an `OutlierValue` only as a number literal or a double-quoted string literal whose embedded quotes are doubled, at most 128 characters and no control character, and the same shape bounds any outlier value it passes back.
- (d) **`FixTableStats` is needed.** On a table with collected statistics, a set without it makes `HasFixed` 1 and leaves every other field's fixed selectivity and average size blank (`FSEL` empty; the extent size set to the new value, the maps back to their estimates). With it, `FixTableStats` copies the collected extent size, each field's selectivity, outlier values and average size, and each map's size into the fixed statistics (`HasFixed` 1, current extent 300, fields equal their collected values), and the later set changes only its own value. On a table with no statistics a set works (`HasFixed` 1, the extent size or the field set, the rest default), and `FixTableStats` answers SQLCODE -484 "has no collected table statistics", so it runs only when `StatsKind` is `collected`. A map size set with no fixed statistics defines the size and leaves `HasFixed` 0.
- (e) **A collect keeps every set value, and Clear fixed statistics removes each.** After sets on the extent size (777), a field (`40%`, outlier `10%`, average 9) and a map (4 blocks), `TuneTable` with `ClearValues` 0 left all of them; `ClearTableStats` left `HasFixed` 0, the extent size at the default 100000, the field's fixed values empty and the map at its estimate.
- (f) **Passing a field's current fixed outlier selectivity, value and average size back leaves them unchanged; omitting them clears them.** A set with the three left out cleared them (outlier selectivity, value and average size all read empty), a set with the values read from `FieldCurrentSelectivity` kept all three, and `""` cleared each. The extent bounds: the vendor accepts 0, 1, 1,000,000,000,000 and every value above or below it, a fraction and text, so the port holds the bound. The set of an empty extent size changes nothing.
- (g) **Each setter and `FixTableStats` take the bare names** `OcuProbe225 Delim` and `Probe Table`, the table as `Schema.Table` text for `FixTableStats`: the three round-trip and `ClearTableStats` clears them.
- **The value in use.** The Indices list's `SIZE_MB` is the size the map reads as (a defined or measured size once fixed; an estimate otherwise, even where a collected size exists), so `INDEX`'s `SizeMB` is that list's number (a measured correction to "the collected one otherwise"). `FIELDSTATS` follows the spec: the fixed row's values when the table has fixed statistics, the collected row's otherwise; `FieldCurrentSelectivity` shows `<Null>` for an outlier selectivity with no value, which the port answers as empty.
- **Corrections to the spec's measure-first clauses:** (a) the value is blocks, so the label "Map size (MB)" stands with the port converting; (c) is false, as above; the sentence "Enter at most 128 characters." covers the length only, and the number-or-quoted-text shape has no published sentence (an agent-facing problem text and the generic `PORT.VALIDATION` reason carry it). Every other measure-first clause held.

**Decided in-stage (Batch 1):**

- **The port owns the shapes.** `SqlPort.ValueProblem` is the one check; the tools' `ArgumentProblem` and `ScreenActionDelta` call it, so the mint, the screen and the port refuse with one sentence. The shapes: `MAXEXTENTSIZE` 10^12 (named constant, boundary pinned); a map size or average size is `0` or 1 to 15 digits; a selectivity is `1` or 1 to 2 digits with up to six decimals, over 0 and at most 99.999, with or without `%`; an outlier value is a number or a double-quoted string, at most 128 characters.
- **A bare selectivity gets its `%`** (`2.5` reads 1.25% on a 200-row table), except `1`. An outlier selectivity always gets one.
- **Optional values.** The payload the proposal stores carries the fresh read's in-use values, and a screen action merges the same way, so they would reach the port as though declared. The agent's merge (`SqlTableSetAction.MergeUpdate`) makes the unsent optional ones `null`; the port drops any optional value equal to the field's in-use value and checks the rest after the field is read, then `SettingCall` passes back the fixed values it reads after the save. A collected table's fractional average size therefore does not meet the whole-number shape.
- **The fingerprint** covers the merged payload, so the declared value is the one reviewed: a change to the old value alone, such as another caller's set, is not seen. Statistics collected, saved or cleared after the mint are.
- **The outcome after a failed set** is `detail.statisticsFixed` on the 409 `SQL.TABLE.VENDOR`, beside the instance's message. No sentence says it on screen; one is `## Clarification Needed`.
- **`TableCall` gains a fifth, output argument** (`pFixed`); the test fixture follows.
- **`SqlTableSetAction` carries the composite-target methods** (`IdArgument`, `IdProblem`, `NameOf`, `TargetName`, `InputSchema`) for the map and field setters through `SECONDARGUMENT`, so neither tool copies `ExplorerSqlIndexRebuild`'s.
- **The read-back** compares `ExtentSize` and `SizeMB` (`matches`). A selectivity has none: the instance reads it back rounded (`30%` reads `30.0003%`).
- **A map size of 0** is accepted (a whole number, 0 or more) and is set as 0 blocks, which resets the map to its measured size; its read-back, comparing the declared 0 with the re-read size, reads `differs` naming `SizeMB`, which is what the map then holds, and no special case is made (pinned by `SqlTableFixedStatsCard`).
- **Not in this batch:** the screen mirror and `Titles.cls` (`node tools/screen-mirror.mjs`), the client and EXPERIENCE.md are Batch 2's; `screen-mirror.mjs --check` reads stale until then.

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
- AC3: `Prohibits` does not send `sql-field` to `TableEntry` -> `Test.Prohibited`'s field leg red; `SqlTableFixedStats` goes red only when the tool's own-name refusal (`SqlTableAction.RefusedBeforeState`) is mutated too.
- AC4: `CatalogRows` stops naming `Table` on field rows -> the tab test red.
- AC5: `ExplorerSqlFieldStatistics` loses its `set-selectivity` row action -> the browser spec red, after rebuild and redeploy.
- Observed (Batch 1, each applied on `ocupilot-ci`, reverted, the file's `git hash-object` identical, source reloaded):
  - mutation: AC1, `SqlPort.SettingCall` passes the extent size plus 1 -> `SqlTableFixedStats` red on both callers' read-back, the delimited-name leg and the bound legs (run 984); the omitted-outlier read replaced by `""` -> `TestASelectivityIsSetOnBothCallersAndAnOmittedOutlierIsKept` red on the kept outlier value (run 985); `FixTableStats` skipped -> the extent, selectivity, map and failed-set tests red (run 986).
  - mutation: AC2, `SqlPort.PercentValid` answers 1 -> every selectivity leg of `TestAValueOutsideItsShapeIsRefusedBeforeAnyCall` red (run 987); `OutlierLiteral` answers 1 -> `TestAnOutlierValueIsNeverRun` red on all four code legs and the stored-as-data leg (run 992).
  - mutation: AC3, `Prohibits` does not send `sql-field` to `TableEntry` -> `Test.Prohibited`'s field leg red, `SqlTableFixedStats` green (run 995, 996): the tool's own-name refusal answers first on both callers. With `SqlTableAction.RefusedBeforeState` also answering 0, `TestATableOfOcuPilotsOwnIsRefusedOnBothCallers` is red on both callers' field legs (run 997).
  - mutation: AC4, `AtelierPort.CatalogRows` stops naming `Table` on field statistics rows -> `SqlTableTune.TestTheFieldStatisticsTabAndTheAgentsReadAnswerTheDirectRows` red on every field (run 998).
  - mutation: `SqlPort.TableWritten` leaves `statisticsFixed` out -> `TestASetThatFailsAfterTheStatisticsWereSavedSaysSo` red (run 993); `SettingSnippet` drops the `FixTableStats` line -> `TestEachSettersScriptDoesWhatTheWriteDoes` red (run 994).
- Observed (Batch 2, each applied, reverted, the file's `git hash-object` identical; browser mutations after `npm run build` and `docker cp` into `ocupilot-ci`):
  - mutation: AC5, `ExplorerSqlFieldStatistics` is dropped from `SCREEN_ACTION_DESCRIPTORS` (the tab registers no `set-selectivity`, the client-side form of losing the row action) and `SQL_TABLE_SET_EXTENT_SIZE` is dropped from `SqlTablePage`'s actions -> the browser spec's two new steps red alone, on "the command bar offers Set selectivity" and "...Set extent size"; the other four steps green.
  - mutation: AC1, `WARNING_VALUES` loses the `set-extent-size` entry -> `sql-table.page.spec.ts` "Set extent size warns with its sentence and a whole-number field" red; the map size's value is sent as `Size` instead of `SizeMB` -> `screen-action-handler-sqlstats.spec.ts` "Set map size warns..." red; `kind: 'field'` for the selectivity -> its two tests red (the field kind and the text typed); `screen-action-dialogs.ts` loses `[fieldKind]` -> "draws the Set selectivity field as text" red alone.
  - mutation: AC2, `PUBLISHED_PROBLEMS` loses the three shape sentences -> "shows a shape refusal as its published sentence" red; one word of `sqlTableWholeNumberShape` changed -> `self-protection.test.mjs`'s refusal roster red; the map size leg dropped from `consequenceSentence` -> `proposal-view.test.mjs`'s setters' test red.
  - mutation: AC5, the descriptor registrations for `sql-field` and `set-extent-size` are in the same browser mutation as above; forward and in reverse order with `system-explorer-sql.browser-spec.mjs` the spec passed (6 of 6 each) and the `after` hook found no probe table, statistic or cached query.

- Observed (review rework, each applied on `ocupilot-ci`, reverted, `git status --short` and `git diff --stat` showing only the intended files, source reloaded):
  - mutation: AC1, `SqlPort.TableAnswer` reads a field's collected values although the table has fixed statistics -> `SqlTableFixedStats.TestTheFieldStatisticsAndTheMapSizeAreReadAsInUse` (run 1037) and `SqlTableFixedStatsCard.TestEachCardShowsTheValueInUseAsOldAndTheDeclaredOneAsNew` (run 1038) red on the old value.
  - mutation: AC1, `SqlTableSetAction.MergeUpdate` sets an undeclared outlier selectivity as declared -> the card test red on the selectivity's row (run 1039).
  - mutation: AC1, `SqlPort.SettingCall` passes the MB as the block count -> `TestAMapSizeIsSetOnBothCallers` red on the agent's and the screen's set (run 1040).
  - mutation: AC1, `SqlPort.SettingCall` quotes the schema -> the instance refuses it and `TestATableWithADelimitedNameIsSetOnBothCallers` goes red with six other tests (run 1041); the quoting is refused for any schema, so the leg is not specific to a delimited one.
  - mutation: AC2, the extent size pattern refuses 0 -> `SqlTableFixedStatsCard.TestTheLowerBoundZeroIsAValidValue` red (run 1036).
  - mutation: AD-6, `FINGERPRINTSUBJECT` of `SqlTableAction` without `StatsKind` and `CollectedAt` -> every setter test is red (run 1042; the confirms answer nothing, the cause being the narrowed payload losing `StatsKind` (inference)), so the subject leg cannot be isolated; `Confirm` not refusing a mismatched fingerprint (`If 0` for `If 'tMatches`) -> `TestAChangedTargetIsRefusedTargetChanged` red alone, on both legs (run 1043).
  - mutation: AC3 gate, `SqlPort.TablesInvoke` gates every type as a read -> `TestTheGatesRefuseBeforeAnyReadOrWrite` red on the three setters' WRITE legs and the no-call assertion (run 1044).
  - mutation: AC4, the Field statistics screen back on `class` in `screens.generated.ts` -> `citation-chips.test.mjs`'s "a stored class citation of a table still resolves to the class screen" red alone.

- Observed (code review, each applied on `ocupilot-ci`, reverted, `git diff --stat` showing only the review's test patches, source reloaded):
  - mutation: AC2, `SqlPort.PercentValid` bounds with `<` for `<=` -> `SqlTableFixedStatsCard.TestASelectivityAtItsBoundsIsAValidValue` red alone, on 99.999 with and without `%` (run 1051).
  - mutation: U-151, `SqlPort.TableWritten` sets `statisticsFixed` unconditionally -> `SqlIndexRebuild.TestTheInstancesRefusalIsAnsweredWithItsMessageInDetailAlone` red alone, on REBUILD and REBUILDALL (run 1054).

## Auto Run Result

Status: done
Blocking condition: none

- **Change:** the three setters (extent size, selectivity, map size) are confirmed writes through `SqlPort`'s `Tables` endpoint, reached by the screen and by the agent. The Field statistics tab moves to a new `sql-field` type with a `[Table, Field]` id and a `FIELDSTATS` read, `INDEX` answers `SizeMB`, and the client adds a text field to the confirmation dialog.
- **Task 0:** `FixTableStats` is needed. Without it a set leaves every other field's fixed value blank. It runs only for a collected table, inside the confirmed write. Corrections to measure-first clauses, as recorded in Design Notes: the map value is in 2 KB blocks and the port sends `SizeMB * 512` (the label "Map size (MB)" stands); an outlier value is run by the vendor as an expression, so the port accepts only a number or a double-quoted string literal; `INDEX`'s `SizeMB` is the Indices list's own number (the compiler's estimate) when the table has no fixed statistics. The vendor accepts any extent size, so the port holds the bound (`MAXEXTENTSIZE`, boundary tested).
- **Commits:** Batch 1 `1d7d0561f` (server), Batch 2 `04ac615bc` (client), finalize on top.
- **Review:** 8 findings, 3 medium patched (card diff, lower bound 0, the stored `class` citation), 1 low patched (unobserved mutation claims), 1 low deferred (positive control for the never-run marker), 3 rejected with reasons in the Review Triage Log. Follow-up review recommended: true, for one risk, a map size of 0, which the vendor answers by resetting to the measured size, so the tool's read-back verdict reads `differs` after a successful set.
- **Verification:** every class and spec the batches touched green on `ocupilot-ci`; `check-objectscript` 0 problems; `lint-docs` clean; `npm run build`, `test:components` (3917) and `test:tools` (2405) green; the tuning browser spec 6/6 forward and in reverse after `system-explorer-sql.browser-spec.mjs`. The full ObjectScript sweep, smoke and the AD-51 `FixTableStats` sentence are the runner's.
- **Residual:** `ExplorerSqlTableSetExtentSize` and its siblings reach an own-table refusal through `Test.Prohibited` alone for the `sql-field` arm. No sentence exists for a failed set after the statistics were saved; it is `detail.statisticsFixed` on the 409. Batch 1's first commit attempt was swept into the runner's bookkeeping commit and re-done after it was reset.
