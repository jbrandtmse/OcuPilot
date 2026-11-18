---
title: 'Story 24.12: Quality measures (Batch 1: the read surface)'
type: 'feature'
created: '2026-11-18'
status: 'done'
baseline_revision: 'a0c930f99130cfa844894d0a20aa1ededd5598ed'
baseline_commit: 'a0c930f99130cfa844894d0a20aa1ededd5598ed'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-11-listing-groups.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-11-listing-groups-2.md'
warnings: ['oversized']
deferred:
  - summary: >-
      A person cannot reach the Documentation screen from a measure: both child screens declare the Quality measures list as parent, and only the first is opened by a row.
    evidence: |-
      childListFor answers the first child (Groups and elements); Documentation is reached by its route or the agent's navigate tool, and the AC3 browser test opens it by URL.
      A tab group (as the cube tabs) or a link from the Groups and elements screen would reach it; either changes the spec's routes or adds a strings row, so it is the owner's call.
    location: >-
      src/OcuPilot/Screen/Descriptor/AnalyticsQualityMeasureMetaList.cls
    severity: medium
---

<intent-contract>

## Intent

**Problem:** The classic Quality Measures Manager (`%DeepSee.UI.QualityMeasures`) has no OcuPilot screen. A quality measure is a class extending `%DeepSee.QualityMeasure.QualityMeasure` whose `QualityMeasure` XData holds the measure (`catalog/set/id`, caption, subject area, expression), its groups of MDX elements and its documentation items; compiling it registers the name in `^DeepSee.QMsrs` (measured). Nobody can see or change one from OcuPilot.

**Approach:** Batches inside the story (Design Notes › Questions 1). This spec is Batch 1, the read surface, built exactly as Story 24.11 Batch 1 built listing groups. `AnalyticsPort` gains three `LIST` endpoints, `QualityMeasures`, `QualityMeasureElements` and `QualityMeasureMetas`; three descriptors read them (the last two parent-scoped); the registry derives `analytics.qualitymeasures.read`, `analytics.qualitymeasureelements.read` and `analytics.qualitymeasuremetas.read`. Nothing is written.

## Boundaries & Constraints

**Always:**

- **Gate, in AD-65's order:** `QUALITYMEASUREPAIRS` = `%DeepSee_Portal:USE,%DeepSee_PortalEdit:USE`, then `AdmitNamespace`. The classic page asks `%DeepSee_PortalEdit:USE` (`RESOURCE` :17, `%OnPreHTTP` :1796) and nothing more (`%CheckPrivilege` answers 1), so this equals it. The vendor runs nothing before the gate passes.
- **Vendor calls are the measured pure reads only:** `%DeepSee.QualityMeasure.Utils` `%GetQualityMeasureList(.list)`, `%GetQualityMeasureClass(name, .sc)` and `%GetModel(name, .sc, 1)` (which follows a link, as the classic page reads it), and `$System.OBJ.IsUpToDate(class)`.
- **Rows** (one per measure name; the class the vendor's registry names answers):
  - `QualityMeasures`: `Name`, `Catalog`, `Set`, `Id`, `Caption`, `Description`, `SubjectArea`, `Expression`, `LinkedTo`, `Published`, `Format`, `Href`, `Class`, `Compiled`, `Groups` (count).
  - `QualityMeasureElements` (criterion `qualitymeasure`): `QualityMeasure`, `Group`, `GroupCaption`, `GroupDescription`, `GroupDisabled`, `Name`, `Caption`, `MDX`, `Disabled`; a group with no element is one row with empty element fields.
  - `QualityMeasureMetas` (criterion `qualitymeasure`): `QualityMeasure`, `Name`, `Caption`, `Section`, `Content`, `Disabled`.
- **One capped read** serves each screen and its tool and reports truncation (AD-36); text reaches the model through the existing sanitizer (AD-60), and `Content` and `MDX` are shown as text, never rendered (AD-11).

**Never:**

- Any write: `%SaveQMsrDefinition`, `$System.OBJ.*` beyond `IsUpToDate`, `DeleteQMeasure`, or `^DeepSee.LastQMSR`. A class's `%GetModel` called directly (it throws `<UNDEFINED>` on a disabled measure, measured).
- `/api/deepsee`, or any vendor call not listed under Always.
- `emptyAgentKey` on these read-only descriptors (`screen-mirror.mjs` refuses it); the writes' batches add it.
- A spine edit; Story 24.13's partial cube update (U-34), which nothing here touches.

## I/O & Edge-Case Matrix

Rows run in USER on `ocupilot-b-ci`, over marker classes `Test/AnalyticsProbe` saves and compiles and removes afterwards. Each measured state is under Design Notes › Measured.

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Compiled | A measure with two groups (one element disabled) and one documentation item | Its row equals the model; `Compiled` true, `Groups` 2 | - |
| Refused compile | Expression names an unknown group (compile refused, name still registered) | Row present, `Compiled` false | - |
| Linked | A measure whose `linkedTo` names the first | Own caption and `LinkedTo`; its Elements are the master's | - |
| Twin | A second class declaring the first measure's name | One row; `Class` is the registered class | - |
| Nameless | A disabled measure (listed with an empty name) | No row; every other row reads | - |
| Elements, Documentation | Criterion = a measure's name (it holds `/`) | One row per element (group fields repeated) or item; fields equal the model | - |
| Unknown | Criterion names no measure, or is empty | No rows | - |
| Cap | `maxRows` below the count | `truncated` true | - |
| Gate | No `%DeepSee_PortalEdit:USE`; a namespace without analytics | Refused before any vendor call | 403 naming the pair; 409 `ANALYTICS.NAMESPACE` |

</intent-contract>

## Code Map

Paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-24` (HEAD `17b9e506d`). **Follow Story 24.11 Batch 1's read-surface commit `f13e912a8` file for file** (its QA `5de9887f8` and fresh-instance fix `d0e2b83bc` too): this batch changes the same files for the same reasons, except that it adds no gate test class (Design Notes › Decided 7). Epic 21 has changed no file beyond feature (`git log --no-merges origin/OCU-1-epic21 ^origin/feature/OCU-1_ocupilot-mvp`, empty on 2026-11-18); the implement stage re-runs it and marks any hit "(contended: add-only)".

- **`src/OcuPilot/Port/AnalyticsPort.cls`** (5,153 lines). Extend the listing-group read branches; do not copy them:
  - `ENDPOINTS` :107, endpoint parameters beside :134-136, `QUALITYMEASUREPAIRS` beside `LISTINGGROUPPAIRS` :153, a `QUALITYMEASUREKEY` criterion beside `LISTINGGROUPKEY` :345, a `Pairs` :487 branch;
  - `Invoke` :636-651: the two criteria, read as `LISTINGGROUPKEY` is (an empty one names none);
  - `Collect` :755: a branch after the listing-group one (:855-903), keeping the `pMax` stop; `Rows` :930: branches after :981-1005.
- **Descriptors** (new, `src/OcuPilot/Screen/Descriptor/`): `AnalyticsQualityMeasureList.cls`, as `AnalyticsListingGroupList.cls` reads at `f13e912a8`; `AnalyticsQualityMeasureElementList.cls` and `AnalyticsQualityMeasureMetaList.cls`, as `AnalyticsListingGroupListingList.cls` reads at `f13e912a8` (`parentScope`, criterion, no actions). Routes `analytics/quality-measures`, `.../elements`, `.../documentation`; `classicPage` `%DeepSee.UI.QualityMeasures`; side-bar position 10; ids single, composite `[QualityMeasure, Group, Name]` and `[QualityMeasure, Name]`; criterion `maxLength` 752.
- **`src/OcuPilot/Kernel/EntityType.cls`**: `quality-measure`, `quality-measure-element`, `quality-measure-meta` in `TYPES` :144 and the doc above it; `Test/Descriptor.cls` :1844 count.
- **Client:** `ui/src/app/core/strings.ts` (analytics block, after :8204, once the strings are ruled); `screens.generated.ts` and `Screen/Titles.cls`, regenerated by `screen-mirror.mjs`. No page component (the archetype's list page).
- **Rosters (Rule 30; the grep for `ListingGroupListingList` and `listinggrouplistings` finds them; contended: add-only for `Test/ReadTool.cls`, `Test/SurfaceCoverage.cls`, `Test/ToolRoundTrip.cls`, `strings.ts`, `screens.generated.ts`, `scripts/ci-throwaway.sh` and the EXPERIENCE.md row):** `Test/ReadTool.cls` :93-94 and :112; `PortGate.cls` :302; `Descriptor.cls` :95-96; `AnalyticsDescriptor.cls` `SCREENS` :18, :142-144, :156, :202; `Navigation.cls` :600; `StageTwoTools.cls` :156-157; `SurfaceCoverage.cls` :335-336; `ToolNavigateContract.cls` :16; `ToolRoundTrip.cls` :107; `ui/tools/screen-mirror.test.mjs` :1562, :2756-2757, :3547-3548; `navigation.test.mjs` :464-478, :963-969; `analytics.test.mjs` :423; `ui/browser/structural-walk.mjs` :147; `analytics-links.browser-spec.mjs`; `scripts/ci-throwaway.sh` :620 (the arming roster comment) with `ui/tools/ci.test.mjs`.
- **Fixture:** `Test/AnalyticsProbe.cls`: `CreateQualityMeasures` and `RemoveQualityMeasures` beside `CreateListingGroups` :603, classes in the probe package so `Left()` :992 reports leftovers, plus `^DeepSee.QMsrs` marker nodes in `Left()`.
- **EXPERIENCE.md** (`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/`): one Fixed strings row after :612.
- **Vendor (read only):** `irislib/%DeepSee/QualityMeasure/Utils.cls` (the reads; `%SaveQMsrDefinition`), `QualityMeasure.cls` (the `%GetModel` generator's compile checks), `QualityMeasureProjection.cls` (registration), `Model/QualityMeasure/*.cls`, `UI/QualityMeasures.cls` (`RESOURCE` :17, `renderDetails` :1610, `DeleteQMeasure` :1225, `SubmitQMsr` :1239, `%OnPreHTTP` :1796), `UI/Dialog/QualityMeasureSave.cls` (name rules :64-125).

## Tasks & Acceptance

**Execution:**

- [ ] `AnalyticsPort.cls`: the three endpoints, the pairs, the criteria, and the `Collect` and `Rows` branches.
- [ ] The three descriptors, the entity types, `strings.ts` (once ruled), the regenerated mirror and titles, and the EXPERIENCE.md row.
- [ ] Tests:
  - `Test/AnalyticsProbe.cls`: the fixture methods (the five states in the matrix).
  - New `Test/AnalyticsQualityMeasureRead.cls`, modeled on `AnalyticsListingGroupRead.cls` and armed by `OCUPILOT_ALLOW_PRINCIPALS`: the matrix at the port and over `GET /screens/<id>/read`, the journal scan, and the leftover check.
  - `ui/browser/analytics.browser-spec.mjs`: open Quality measures, then a measure's Groups and elements and its Documentation.
  - Every roster under Code Map.

**Acceptance Criteria:**

- **AC1 (round trip over the backing class).** Given the marker measures. When the three screens are read. Then every field equals what `%DeepSee.QualityMeasure.Utils.%GetModel(name, , 1)` reads from the class.
- **AC2 (Integration, Rule 1).** Given the same measures. When `GET /screens/<id>/read` and the agent's read tool run for each screen. Then both answer the same rows.
- **AC3 (browser).** Given the probe. When a person opens Analytics › Quality measures and selects a measure whose name holds `/`. Then its Groups and elements and its Documentation screens show its rows.
- **AC4 (writes nothing).** Given the marker measures. When any read in the matrix runs, on a fresh instance's first call. Then a journal scan of the calling process records no global write beyond the SQL engine records 24.11 excludes by name.
- **AC5 (declared and rostered).** Given the three descriptors. When the roster tests run. Then each holds their rows and the classic page, and removing one row reddens that test alone.
- **AC6 (leaves USER as found).** Given any new or changed test, in either order. When it ends. Then no marker class and no marker `^DeepSee.QMsrs` node remains.

### Review Findings

Code review 2026-11-18 (Batch 1), tier `full-opus`, four layers (blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor). 0 decision-needed, 10 patch, 4 ledgered, 7 rejected.

- [x] [Review][Patch] (med) The twin test could pass with no twin: `CreateTwinQualityMeasure` dropped its compile status and nothing checked the vendor listed the name twice; the status is returned and the test asserts `Listed` = 2 first [src/OcuPilot/Test/AnalyticsProbe.cls, src/OcuPilot/Test/AnalyticsQualityMeasureRead.cls]
- [x] [Review][Patch] (med) Rule 30: the measures reads of the Read, Edge and Gate classes asserted on every measure in USER; they now judge the probe's rows by catalog (`ProbeNames`, `ProbeCount`, `RowsOf` prefix) [src/OcuPilot/Test/AnalyticsQualityMeasureRead.cls, src/OcuPilot/Test/AnalyticsQualityMeasureEdge.cls, src/OcuPilot/Test/AnalyticsQualityMeasureGate.cls]
- [x] [Review][Patch] (low) The removal test ran mid-class and later tests used its re-create; renamed `TestZRemovingTheQualityMeasuresLeavesNothing` so it sorts last [src/OcuPilot/Test/AnalyticsQualityMeasureRead.cls]
- [x] [Review][Patch] (low) AC4's scan covered no capped read; `ReadEverything` adds a measures and an elements read under a cap of one [src/OcuPilot/Test/AnalyticsQualityMeasureRead.cls]
- [x] [Review][Patch] (low) Two descriptor comments and the EXPERIENCE.md row said a measure's name opens Documentation; they now say it is reached by its route or the agent [src/OcuPilot/Screen/Descriptor/AnalyticsQualityMeasureList.cls, AnalyticsQualityMeasureMetaList.cls, EXPERIENCE.md:614]
- [x] [Review][Patch] (low) "A linked measure shows its master's groups" now says when both classes are compiled, as `%GetModel` merges [src/OcuPilot/Screen/Descriptor/AnalyticsQualityMeasureElementList.cls, AnalyticsQualityMeasureMetaList.cls]
- [x] [Review][Patch] (low) No probe state set a group's or an item's `disabled` or a model's `published` false, so a constant would pass; the refused measure is unpublished with a disabled empty group and a disabled item [src/OcuPilot/Test/AnalyticsProbe.cls]
- [x] [Review][Patch] (low) The empty-state browser test read an unreadable vendor list as empty; the precondition now answers `unreadable` on an error status [ui/browser/analytics.browser-spec.mjs]
- [x] [Review][Patch] (low) The Story 24.12 source guard missed `##class(%SYSTEM.OBJ)`; it is now refused [ui/tools/analytics.test.mjs]
- [x] [Review][Patch] (low) Stale probe prose: the class header's method list, `QualityMeasureText`'s nine values, "Both compile", and a twin that "registers" [src/OcuPilot/Test/AnalyticsProbe.cls]
- [x] [Review][Defer] (low) AC4's first-call clause holds only when the scan class runs before the other 24.12 classes on its throwaway -- DW-2735 wontfix-accepted
- [x] [Review][Defer] (low) The empty-state browser test needs USER to hold no quality measure, which it asserts first but did not make -- DW-2736 wontfix-accepted
- [x] [Review][Defer] (low) Rule 2: `RowNamed` and `AssertSameFields` are copied across the 24.11 and 24.12 read classes and Edge -- DW-2737 wontfix-accepted
- [x] [Review][Defer] (low) A name the vendor lists through an unregistered class is no row, and no test reaches that branch -- DW-2738 wontfix-accepted

Rejected:

- (low) A twin's row takes the first-listed class's spelling of the name: the registry keys names without case, and the model's name can differ from the registered one when an edited XData's compile is refused, so the listed name is the safer key.
- (low) A model the vendor cannot read is silent: its row's `Published` 0 and `Groups` 0, the sub-screens' empty sentences for a dangling link, and an unread `tModelStatus` are Decided in-stage 3, pinned by the edge class; the master-not-a-measure branch needs a corrupt registry.
- (med, duplicate) Documentation has no UI path from a measure: DW-2734, owned by Batch 3.
- (low) The commit message counts one test class: QA's two classes are uncommitted, and a pushed message is not rewritten.
- (low) Documentation's title reuses `linksDocumentation`: Decided in-stage 1 (implement), since strings are unique by value and the label was ruled (U-111).
- (low) No `LinkedTo` or `Expression` column: the columns are the ruled proposal (U-111); the agent reads both fields.
- (low) The empty sentence is shown when USER holds only disabled measures: the matrix's Nameless row makes them no row, and the sentence is ruled.

## Spec Change Log

- 2026-11-18, spec gate: blocked -> ready-for-dev on the runner's rulings (U-111); this spec is Batch 1.

## Review Triage Log

### 2026-11-18 -- Review pass

- verdicts: 9 findings -- high 0, medium 3, low 6, false 0, maybe-false 0
- findings:
  - `[medium]` `[defer]` Documentation is not reachable from a measure through the UI (intent-alignment) -- real; the spec's routes fix two parent-scoped children and `childListFor` opens the first; the fix changes routes or adds strings, so deferred in frontmatter for the owner.
  - `[medium]` `[patch]` AC4 journal test was not the first reader in its class (verification-gap) -- renamed `TestAAReadsMakeNoJournaledWrite`, which the runner runs first (checked in the run's method order).
  - `[medium]` `[patch]` An empty group's row was asserted at the port only (verification-gap) -- the Groups and elements screen read of the refused measure now asserts two rows including the empty-group row.
  - `[low]` `[patch]` Two Documentation legs could compare two failed or empty reads (verification-gap) -- `Facts.error` is asserted per measure, and the linked measure's Documentation names equal `Purpose`.
  - `[low]` `[patch]` `Scope` not cleared if an assertion aborts a test (verification-gap, other) -- `OnAfterOneTest` clears it.
  - `[low]` `[reject]` AC5's mutation line proves three of the rosters (verification-gap) -- Rule 19 asks one demonstrated mutation per AC.
  - `[low]` `[reject]` `TestRemovingTheQualityMeasuresLeavesNothing` and the whole-USER name list are order- and environment-sensitive (verification-gap, other) -- the class creates and removes its own state and the throwaway holds no other measure; a later test's failure names the create that failed.
  - `[low]` `[reject]` The `analytics.test.mjs` Story 24.12 check is a source regex (verification-gap, other) -- the journal scan is the behavioral guard; the regex pins the vendor-call list only.
  - `[low]` `[reject]` Extra scope in the diff: unreadable-model fallback row, case-insensitive criterion (intent-alignment) -- inside the pure-reads boundary, recorded under Decided in-stage 3.

## Design Notes

**Ruled at the spec gate (runner, veto item U-111).** Three batches inside the story: this spec is Batch 1 (the three read screens); Batch 2 (the four measure writes) and Batch 3 (the element and documentation writes) are planned in further specs for this story key, each after the previous batch's code head is committed; the story reaches `done` only when all three have. The proposed strings are kept. The proposed AD-65 line stays here for the owner's attended update; the code complies without a spine edit.

**Questions for the runner (intent gap).**

1. **Batches (Rule 5 tier 2; Story 21.8's lineage is at `split_children`).** The editor reads a measure's header, its groups of MDX elements and its documentation items, and writes all three; each write saves and compiles a class. Recommended, three batches inside this story, each planned in its own spec after the previous code head is committed, the story `done` when all three are:
   - **Batch 1 (this spec):** the read surface.
   - **Batch 2:** the measure writes: `analytics.qualitymeasures.add`, `.update` (header and expression), `.copy` (classic Save As) ship `true`; `.delete` is `DESTRUCTIVE`, ships `false`, typed-name confirm.
   - **Batch 3:** the element and documentation writes (add, change, remove of each; the group fields ride on the element writes).
   - Alternative: two batches, Batch 2 taking every write. Rejected for size: 24.11's seven writes ran oversized and took a rework.
2. **Proposed strings (veto).**
   - Labels: "Quality measures", "Groups and elements", "Documentation", "Quality measure" (criterion), "Published", "Group", "MDX", "Content". Reused keys: Name, Caption, Description, "Subject area" (`analyticsTermListSubjectArea`), "Compiled" (`analyticsColumnCompiled`).
   - Columns: Quality measures — Name, Caption, Subject area, Published, Compiled; Groups and elements — Group, Name, Caption, MDX; Documentation — Name, Caption, Content.
   - Empty states: "No quality measure is defined in this namespace." · "This quality measure no longer exists, or it has no groups." · "This quality measure no longer exists, or it has no documentation."
   - Prompts, Quality measures: "Summarize the quality measures in this namespace." · "Which quality measures are not compiled?" · "Which quality measures are linked to another measure?"
   - Prompts, Groups and elements: "Summarize the groups of this quality measure." · "Which elements are disabled?" · "Explain what each element's MDX selects."
   - Prompts, Documentation: "Summarize this quality measure's documentation." · "Which documentation items are disabled?" · "What does the documentation say this measure is for?"
   - Agent empty-state phrases the registry will require once Batches 2 and 3 make the screens write: "create a quality measure" · "add an element to this quality measure" · "add documentation to this quality measure".

**Batches 2 and 3 preview (not planned here).** U-108's path: `Kernel/SourceDocument` through an `AtelierPortClass()` seam, as listing groups do, under `%Development:USE` and `AtelierPort.WritePairs`; the class text by extending `Kernel/ListingGroupText` (its XData name, superclass and namespace made parameters; a measure has no `DependsOn`). Pre-checks from the measured compile refusals; a create whose compile is refused deletes its class, because the name is registered anyway (measured). A name two classes declare is refused (`AMBIGUOUS`): the vendor's duplicate check reads `^DeepSee.Cubes("qmsrNames")`, which its projection never writes, so a twin compiles (measured). Every write refuses an `OcuPilot*` class with `PROHIBITED.OCUPILOTCODE`. Element and documentation writes on a linked measure are refused, as the classic page makes them read-only (:1687). U-34 stays untouched: a measure's compile touches no cube (measured).

**Measured** (plan, 2026-11-18, `ocupilot-b-ci`, USER, scratch package `OcuProbe2412` removed afterwards; `^DeepSee.QMsrs` empty before and after):

- **Compile.** A measure over a missing subject area compiled and registered `qmsrNames`, `qmsrClasses` and `cubes` nodes. An expression naming an unknown group, a missing catalog, and a duplicate group name each refused the compile (#5001, the vendor's sentence), left the compiled class present and `IsUpToDate` 0; the unknown-group one was still registered and listed with its name.
- **Twin.** A second class declaring the same name compiled OK, was listed, and was not registered. Deleting it left the registered class's nodes; deleting the registered class removed them all.
- **Disabled.** It compiled, was listed with an empty name, and its class's `%GetModel` threw `<UNDEFINED> tQMSR1`.
- **Linked.** `%GetModel(name, , 1)` answered the master's two groups and the linked measure's own caption; with 0, no groups and an empty expression.
- **Model.** Groups, elements (a disabled one included) and items read back as written; an item's `content` reads as its stored markup.
- **Journal.** `%GetQualityMeasureList`, `%GetModel(name, , 1)` twice and `%GetQualityMeasureClass` recorded no set or kill of this process, in two passes; a control `Set` was the one record found.

**Decided in-stage (plan).**

1. The read pairs equal the classic page's; `QUALITYMEASUREPAIRS` is its own parameter, because Batch 2's write pairs diverge from the term list's.
2. One row per name, answered by the registered class (the vendor's by-name read); a name the registry does not hold is no row, as the classic page cannot open it either.
3. Links are followed as the classic page shows them; `LinkedTo` says so on the row.
4. `Compiled` is `IsUpToDate`, the vendor's own test in `Utils.%GetModel`.
5. An empty group is one row with empty element fields, so every group reads.
6. The read tools come from the registry's `<toolIdentifier>.read`; no tool classes.
7. No gate test class: no field is privilege-bound and every measure is visible, so `PortGate`'s endpoint roster pins the pair refusal and the read class pins the namespace refusal.
8. A measure's name holds `/`; AD-13's one-segment encoding carries it, which AC3 pins.

**Decided in-stage (implement).**

1. The Documentation screen's label is the existing `linksDocumentation` (strings are unique by value), so no `analyticsQualityMeasureMetasLabel` key exists; the EXPERIENCE.md row names Documentation among the reused words.
2. The Fixed strings row is appended after the table's last row (613), not after :612, so Epic 21's row and the twenty citations of it keep their line.
3. A registered name whose model the vendor cannot read is a row from the list's data (empty model fields, `Compiled` from `IsUpToDate`); an elements or documentation read answers only when the model's name equals the criterion without regard to case, so a longer path names no measure.
4. The linked probe measure's expression is `1`: a linked class naming groups it does not hold is refused at compile, and `%GetModel` follows a link only from a compiled class.
5. Both child screens declare `parentScope` `analytics/quality-measures`, as the spec routes; `childListFor` answers the first, so the name cell opens Groups and elements and Documentation is reached by its route or the agent's navigate tool.
6. The two existing analytics tests that forbid `$System.OBJ.` in the port now allow `IsUpToDate(` only, and a Story 24.12 test pins the three Utils reads and that one call.
7. A tool answers rows in its descriptor's sort order and a screen in the port's, so the AC2 test compares the two sorted.

**Governing ADs (Rule 6):** AD-65 (the port and its pure reads), AD-29 and AD-8 (the gate), AD-16 (the switch), AD-36 (the capped read), AD-5, AD-44 and AD-24 (descriptors, classic page, context), AD-11 and AD-60 (XData text is untrusted), AD-13 (entity ids), AD-21 (the vendor's list query takes no caller value).

**Proposed spine line (the owner's attended update; never written here).** AD-65: "`%DeepSee.QualityMeasure.Utils` `%GetQualityMeasureList`, `%GetQualityMeasureClass` and `%GetModel`, and `$System.OBJ.IsUpToDate`, join the measured pure reads (Story 24.12)."

**Integration and linkage (Rules 1, 2).**

- `Consumes:` `AnalyticsPort`'s gate; `Screen/Read.cls` (serves any analytics source unchanged); the registry's derived read tools; `Test/AnalyticsProbe`.
- `Consumed-by:` Story 24.12 Batches 2 and 3, whose writes compose their fresh read from these endpoints.
- AC2 is the Integration AC.
- Siblings extended: `Collect`, `Rows` and `Pairs`; the two listing-group descriptors at `f13e912a8`; `AnalyticsListingGroupRead` as the test's shape; `AnalyticsProbe` for the fixture.

**Ledger inbox:** none.

## Verification

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.AnalyticsQualityMeasureRead`, then the same, one call per message, for `AnalyticsDescriptor`, `ReadTool`, `PortGate`, `Descriptor`, `Navigation`, `StageTwoTools`, `SurfaceCoverage`, `ToolNavigateContract`, `ToolRoundTrip`, `AnalyticsListingGroupRead` and every class the shared-surface sweep changes. Expected: green.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`. Expected: green.
- `(loop)` `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/analytics.browser-spec.mjs browser/analytics-links.browser-spec.mjs`. Expected: green.
- `(once)` the full ObjectScript sweep: `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17`, one call per shard, k = 1 to 17. Expected: green.
- `uv run scripts/check-objectscript.py`, `bash scripts/lint-docs.sh`. Expected: clean.
- The full browser suite is left to CI.

**Shared surfaces:** the analytics side bar (`analytics.browser-spec.mjs` :230, `analytics-links`), `ReadTool`'s count and names, the entity-type count, `AnalyticsDescriptor` `SCREENS`, the descriptor and endpoint rosters in `screen-mirror.test.mjs`, `StageTwoTools`, `SurfaceCoverage`, `ToolNavigateContract`, `Navigation`, `structural-walk.mjs`, the arming roster in `ci-throwaway.sh` and `ci.test.mjs`, and `ci-timings.json` (no row for the new class).

**Hermeticity:** every test added or changed passes on its first run on a fresh instance, in either order.

**Mutations:** each applied to a copy on `ocupilot-b-ci`, observed red alone, and reverted byte-identical.

- mutation: AC1 `AnalyticsPort.Collect` sets `tIsCompiled = 1` -> `TestTheMeasuresAreTheModelsOfTheirClasses` red on the refused leg; `%GetModel(..., 0)` -> the linked legs of it and of `TestAMeasuresElementsAndDocumentationAreTheModels` red; the empty-group row skipped -> the refused elements leg red; the already-listed name not skipped -> `TestTheRegisteredClassAnswersWhenTwoClassesDeclareOneName` red.
- mutation: AC2 `Screen.Tool.Read.View` takes no criterion -> `TestTheScreensAndTheAgentsToolsAnswerTheSameRows` red (400 `READ.CRITERION`).
- mutation: AC3 the elements branch pushes `""` for `mdx` -> the Story 24.12 browser test red on the Groups and elements leg (class reloaded).
- mutation: AC4 the measures branch sets `^OcuPilotProbeQmMutation` -> `TestAAReadsMakeNoJournaledWrite` red, naming the record.
- mutation: AC5 the `AnalyticsQualityMeasureMetaList` row removed from `StageTwoTools` -> `TestTheRosterAndElsewhereAreEveryRegisteredScreen` red alone; `QUALITYMEASUREPAIRS` without the edit pair -> `PortGate` red on the three endpoints; a `%SaveQMsrDefinition` call in the port -> the Story 24.12 `analytics.test.mjs` test red.
- mutation: AC6 `RemoveQualityMeasures` deletes no class -> `TestZRemovingTheQualityMeasuresLeavesNothing` red, naming the four classes.
- (review) mutation: AC1 `CreateTwinQualityMeasure` saves without compiling -> `TestTheRegisteredClassAnswersWhenTwoClassesDeclareOneName` red on both `Listed` legs alone (run 7); the empty group's `GroupDisabled` read as 0 -> `TestAMeasuresElementsAndDocumentationAreTheModels` red on the refused row 2 (run 10); AC5 a `##class(%SYSTEM.OBJ).Load` call in the port -> the Story 24.12 `analytics.test.mjs` test red. Each restored (`diff -rq` / `cmp` identical, reloaded); `AnalyticsQualityMeasureRead` (run 11), `Edge` (run 8), `Gate` (run 9) and the two Story 24.12 browser tests green after.
- mutation: Gate `AdmitNamespace` without its analytics check -> `TestANamespaceWithoutAnalyticsIsRefusedBeforeAnyVendorCall` red on all three endpoints.
- (QA) `src/OcuPilot/Test/AnalyticsQualityMeasureEdge.cls` (armed, `OCUPILOT_ALLOW_PRINCIPALS`): the dangling link, the missing subject area, odd criteria, the journal scan of those reads, the leftover check. `src/OcuPilot/Test/AnalyticsQualityMeasureGate.cls` (armed): the privilege pair as real principals (screens, the agent's tools in a child process) and in process. `src/OcuPilot/Test/AnalyticsProbe.cls` (`CreateEdgeQualityMeasures`, cleanup and `Left`), `scripts/ci-throwaway.sh` (arming roster, add-only) and `ui/browser/analytics.browser-spec.mjs` (empty sentences).
- (QA) mutation: AC1 the unreadable-model branch of the measures read answers no row -> `TestADanglingLinkIsOneRowFromTheListAndHoldsNoGroups` red (with the recount in `TestZRemovingTheEdgeMeasuresLeavesNothing`); the subject area read as empty for a cube the registry does not hold -> `TestAMeasureOverAMissingSubjectAreaReadsLikeAnyOther` red alone; the model-name check dropped from the elements and documentation branches -> `TestAnOddCriterionNamesNoMeasure` red alone, on the name followed by a slash.
- (QA) mutation: AC4 the unreadable-model branch sets `^OcuPilotProbeQmEdgeMutation` -> `TestAAEdgeReadsMakeNoJournaledWrite` red alone, naming the record.
- (QA) mutation: AC6 `RemoveQualityMeasures` leaves out the no-area class -> `TestZRemovingTheEdgeMeasuresLeavesNothing` and the class's `OnAfterAllTests` red, naming the class and its node.
- (QA) mutation: Gate `QUALITYMEASUREPAIRS` the portal's pair alone -> the reader's three tool legs and the portal-alone port legs of `AnalyticsQualityMeasureGate` red; `%DeepSee_Admin:USE` in place of the edit pair -> the editor's tool legs red (403); the edit pair listed first -> the nothing-held leg red alone.
- (QA) mutation: AC3 the Documentation screen's `emptyStateKey` pointed at the Groups and elements sentence in the generated mirror (bundle rebuilt and copied in) -> the empty-sentence browser test red on the Documentation leg; restored (`cmp` equal), rebuilt, green.
- (QA) Each server mutation was applied to `ocupilot-b-ci`'s copy of the source only, restored by syncing the tree (`diff -rq` identical) and reloaded. After the last one `ocupilot-b-ci` was rebuilt fresh: `AnalyticsQualityMeasureRead` (run 1, journal scan first on a fresh instance), `AnalyticsQualityMeasureEdge` (run 2) and `AnalyticsQualityMeasureGate` (run 3) each passed on their first run; `AnalyticsQualityMeasureRead` again (run 4) and `AnalyticsListingGroupRead` (run 5) green after them; the two Story 24.12 browser tests green.

## Auto Run Result

Status: done
Blocking condition: none

- **Implemented:** the read surface of Quality measures: three `AnalyticsPort` LIST endpoints (`QualityMeasures`, `QualityMeasureElements`, `QualityMeasureMetas`) behind the `%DeepSee_Portal:USE,%DeepSee_PortalEdit:USE` gate, three descriptors with derived read tools, entity types, strings, the regenerated mirror and titles, one EXPERIENCE.md row, the probe fixtures, every roster, the new `AnalyticsQualityMeasureRead` class (8 tests) and one browser test.
- **Review:** 9 findings (high 0, medium 3, low 6): 4 patched in-pass (journal test first in its class, screen-level empty-group row, `Facts.error` and linked-documentation assertions, `Scope` cleared after each test), 1 deferred (Documentation is reachable by route and the agent only, medium; the owner chooses a tab group or a link), 4 rejected with reasons in the triage log. Follow-up review recommended: false (no high patched; one medium patched pair, both test-only).
- **Verification:** `AnalyticsQualityMeasureRead` green on its first run on a rebuilt `ocupilot-b-ci` (run 1); the full ObjectScript sweep, shards 1 to 17 of 17, green on that instance; `check-objectscript` 0 problems; `lint-docs` clean; the implement pass ran `npm run build` (initial bundle 2.13 MB, under the 2,500 kB warning), `test:tools` 2316/2316, `test:components` 3578/3578, and the two analytics browser specs (9/9 and 6/6). The full browser suite is left to CI.
- **Contended (add-only):** `Test/ReadTool.cls`, `Test/SurfaceCoverage.cls`, `Test/ToolRoundTrip.cls`, `strings.ts`, `screens.generated.ts`.
- **Residual risk:** the Documentation screen has no in-app link (deferred above); `AnalyticsPort` is the only vendor-call site, and the one new vendor write-adjacent call, `$System.OBJ.IsUpToDate`, is a read.
