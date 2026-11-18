---
title: 'Story 24.12: Quality measures (Batch 1: the read surface)'
type: 'feature'
created: '2026-11-18'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-11-listing-groups.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-11-listing-groups-2.md'
warnings: ['oversized']
deferred: []
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
- **Rosters (Rule 30; the grep for `ListingGroupListingList` and `listinggrouplistings` finds them):** `Test/ReadTool.cls` :93-94 and :112; `PortGate.cls` :302; `Descriptor.cls` :95-96; `AnalyticsDescriptor.cls` `SCREENS` :18, :142-144, :156, :202; `Navigation.cls` :600; `StageTwoTools.cls` :156-157; `SurfaceCoverage.cls` :335-336; `ToolNavigateContract.cls` :16; `ToolRoundTrip.cls` :107; `ui/tools/screen-mirror.test.mjs` :1562, :2756-2757, :3547-3548; `navigation.test.mjs` :464-478, :963-969; `analytics.test.mjs` :423; `ui/browser/structural-walk.mjs` :147; `analytics-links.browser-spec.mjs`; `scripts/ci-throwaway.sh` :620 (the arming roster comment) with `ui/tools/ci.test.mjs`.
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

## Spec Change Log

- 2026-11-18, spec gate: blocked -> ready-for-dev on the runner's rulings (U-111); this spec is Batch 1.

## Review Triage Log

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

**Mutations:** one `mutation:` line per AC, written by the implement stage.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none (the batch boundary and the strings were ruled at the spec gate, U-111)
