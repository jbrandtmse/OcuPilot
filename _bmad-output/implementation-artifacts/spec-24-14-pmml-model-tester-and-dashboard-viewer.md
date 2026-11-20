---
title: 'Story 24.14: PMML model tester and dashboard viewer (Batch 1: the dashboard and pivot viewer)'
type: 'feature'
created: '2026-11-19'
status: 'in-progress'
baseline_revision: 'd459004502a425e9ee31dfdaecc078854d490613'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-13-analytics-settings.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-13-analytics-settings-3.md'
warnings: ['oversized', 'multiple-goals']
deferred:
  - summary: 'Definition shows each level''s spec only: a filter''s chosen members (key, value), nested childLevels, disabled levels, calculated members'' expressions, and a userMDX stored with manualMode 0 (which the vendor''s composition still runs) are not shown'
    evidence: 'ReadFolderItem reads PivotLevel.spec and memberName only; %DeepSee.Component.pivotTable.SynthesizeMDX reads key, childLevels and a non-empty userMDX whatever manualMode says (:12922). The field contents are the spec''s, so widening them is a spec change'
    location: 'src/OcuPilot/Port/AnalyticsPort.cls ReadFolderItem (detail block), FolderItemDefinitionRow'
    severity: med
  - summary: 'A pivot run''s confirmation is bound to the item''s name, not to the composed text: the confirmed start, its job and a confirmed drill each compose again, so an edit of the pivot after the confirm answer runs text the person did not confirm; the confirm answer and the screen never show the composed statement'
    evidence: 'MdxQuery.Admit and Process each call PivotRun.Resolve; the client re-sends {item, confirmed: true}; mdx-answer.ts does not read statement. Needs a concurrent edit by a holder of write on the item. Binding needs a body or answer shape the spec does not have (inference: a digest of the statement)'
    location: 'src/OcuPilot/Area/Analytics/MdxQuery.cls Admit, Process; src/OcuPilot/Area/Analytics/PivotRun.cls Resolve; ui/src/app/areas/analytics/mdx-query.store.ts confirm'
    severity: med
  - summary: 'Widgets rows carry no widget name, so LinkedTo (a widget name) cannot be matched to a row, and the [Dashboard, Position] id shifts when widgets are reordered'
    evidence: 'dataLink holds the source widget''s name (fixture: "Sales"); the row has Title, Position and no Name. The field list is the spec''s'
    location: 'src/OcuPilot/Port/AnalyticsPort.cls ReadFolderItemView; src/OcuPilot/Screen/Descriptor/AnalyticsDashboardWidgetsTab.cls'
    severity: low
  - summary: 'The KPI-backed pivot refusal (409 ANALYTICS.PIVOT.CUBE) is pinned only with a KPI name nothing defines; no test pivots over a compiled KPI'
    evidence: 'VIEWKPICUBE is OcuPilotProbeNoSuch.kpi and src/OcuPilot defines no %DeepSee.KPI subclass; %CubeExists reads the cube registry only (inference: it refuses a real KPI too)'
    location: 'src/OcuPilot/Test/AnalyticsPivotRun.cls TestAbsentAndNonPivotItemsAreRefusedBeforeAnythingRuns; src/OcuPilot/Test/AnalyticsProbe.cls CreateViewerItems'
    severity: low
---

<intent-contract>

## Intent

**Problem:** OcuPilot can list a namespace's folder items (Story 20.11) and export, import and delete them (Story 24.10), but it cannot open a saved pivot or dashboard to see what it holds or what it answers. The classic `%DeepSee.UserPortal.DashboardViewer` can. The PMML model tester (`%DeepSee.PMML.UI.ModelTester`) has no OcuPilot screen either.

**Approach:** The work is split into batches inside this story (Design Notes › Questions 1), and this spec is Batch 1. A folder item's name opens a viewer: a tab group under Folder items with two tabs, **Definition** and **Widgets**. Each tab is a declared read whose agent read tool the registry derives. Definition runs a pivot through MDX query's own run, extended so the vendor composes the pivot's MDX inside that run, and the agent's MDX read gains `pivot`. Nothing is written. "Round-trips over its backing class" means two things for this batch. First, what the screen and the tool read equals what `%DeepSee.Dashboard.Pivot` and `%DeepSee.Dashboard.Definition` hold for an item saved through them. Second, a pivot's run answers the cells the vendor's own `%DeepSee.ResultSet` answers for that pivot's `%GetBaseMDX()`.

## Boundaries & Constraints

**Always:**

- **Reads are pure (AD-65).**
  - Definitions are read with `%DeepSee.UserLibrary.Utils` `%FolderItemExists` and `%OpenFolderItem` and property reads, measured to write nothing (Task 0).
  - An item the vendor's `%CheckResource("USE")` refuses reads as no rows. This includes a locked item, which the vendor itself opens without that check, so OcuPilot is stricter than classic.
  - A pivot's MDX is composed only inside a run, never in a read.
  - The id is the item's full name, kept exactly (AD-13); the shape rule is `FolderItemShaped`.
- **Definition** has one row, or none when the item is missing or is not a pivot or a dashboard. Its fields are Name, Type, Title, Description, Owner and Modified. A pivot also fills the following, and they are empty for a dashboard:
  - Cube;
  - Rows, Columns, Measures and Filters (each level's `spec`, one per line);
  - Calculated (each calculated member's name);
  - MDX (`userMDX`, filled only when `manualMode` is set);
  - Restriction (`sqlRestriction`).
- **Widgets** has one row per widget of a dashboard, in the stored order. Its fields are Dashboard, Position (1-based), Title, Type, DataSource, LinkedTo (`dataLink`) and NotPivot. NotPivot is true unless the data source is a saved pivot, which `pivot.cls` :1259-1281 decides by extension (`.kpi`, `.metric` and `.worksheet` are not pivots).
  - A row whose NotPivot is false links to its pivot's Definition tab (`rowTarget` on DataSource, `unless` NotPivot).
  - A KPI, metric or worksheet runs nothing (named limit; catalog row AN-17 names `PivotExecute` only (inference)).
- **A pivot's run is MDX query's run (AD-7, AD-41, AD-42, AD-65).** A new `pivot` kind of `MdxQuery` takes the body `{item, drill?, confirmed?}`. Its start and its job each do the following, in order:
  1. open the item through the port; a missing item, a refused item, or a name that fails `FolderItemShaped` is 404 `ANALYTICS.FOLDERITEM.ABSENT` (reused);
  2. refuse an item that is not a pivot, or a pivot whose `cubeName` `%CubeExists` does not hold, with 409 `ANALYTICS.PIVOT.CUBE`; a KPI-backed pivot falls here;
  3. compose the statement with `%GetBaseMDX()`;
  4. continue with MDX query's `Check`: `MdxAdmit`, `MdxConstructs` (so a `%SQLRESTRICT` restriction asks first), `MdxPrepare` and `MdxRun`, under the same caps and bound.

  The answer adds `statement`, the composed MDX, cut at `MDXMAXCELL`. No pivot variable is handed to the prepare (MDX query's `Variables`; named limit).
- **The agent (AD-60, AD-11).** `analytics.mdxquery.read` takes exactly one of `statement` and `pivot`. For `pivot` it composes the statement through the same port call, makes the same refusals and refuses constructs with `ANALYTICS.MDX.SQL`. The two derived read tools return what the tabs show.
- **Gate (AD-8, AD-29, AD-65).** Both tabs take Folder items' pairs (`FOLDERPAIRS`). The run also takes `MdxAdmit`, which checks `MDXPAIRS` and WRITE on the database of `^DeepSee.Cache.Results`.

**Never:**

- `%RegisterRecentItem`, the classic `DashboardViewer`'s open path, `%CreateResultSet`, `%DrawKPITable`, any KPI's `%OnLoadKPI`, `%ExecuteMDX`, `%ExecuteSQL` or `%GetKPIValueArray`, and any update of `lastAccessed`, `timeModified` or `^DeepSee.UserPreferences`.
- `/api/deepsee` and `%DeepSee.REST.*`.
- A client-sent MDX statement for a pivot.
- Any write tool, governance key or proposal.
- PMML (Batch 2).
- A spine edit. Edits to `ui/angular.json`, `ui/vitest-base.config.mjs`, or `scripts/ci-throwaway.sh` beyond add-only roster lines.

## I/O & Edge-Case Matrix

Rows run in USER on `ocupilot-b-ci`. The test creates its own pivot and dashboard in the probe folder through the vendor classes, on `AnalyticsProbe`'s Visits cube, and deletes them after.

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Pivot read | Pivot with a row level, a column level, a measure, a filter, a calculated member and a restriction | Definition's row equals each property; Widgets has no rows | - |
| Dashboard read | Three widgets: one on the pivot, one on `X.kpi`, one linked to the first | Three rows in order; NotPivot false, true, true; LinkedTo kept | - |
| Manual pivot | `manualMode` 1 with `userMDX` | MDX shows `userMDX` | - |
| Run | The pivot with no restriction, from the screen and through the agent's `pivot` | Cells equal `%DeepSee.ResultSet` over `%GetBaseMDX()`; `statement` is that text | - |
| Restriction | The pivot with a restriction | Screen: `confirm`, then the run with `confirmed`; agent: refused | 422 `ANALYTICS.MDX.SQL` |
| Absent or refused | A missing name; a name of 601 characters; an item guarded by a resource the caller lacks; a locked guarded item | No rows; the run is refused | 404 `ANALYTICS.FOLDERITEM.ABSENT` |
| Not a cube pivot | The dashboard's name; a pivot whose `cubeName` is a `.kpi` | Refused before composing | 409 `ANALYTICS.PIVOT.CUBE` |
| Shape | A body key other than `item`, `drill`, `confirmed`; the agent's `statement` and `pivot` together | Refused | 400 `ANALYTICS.MDX.INPUT`; 400 `TOOL.ARGUMENTS` |
| Gate | No `%Development:USE`; analytics off | Refused before any vendor call | 403; 409 `ANALYTICS.NAMESPACE` |

</intent-contract>

## Code Map

Paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-24` (HEAD `42b21cde2`).

**Contention.** These files are changed on `origin/OCU-1-epic21` beyond feature and take add-only roster lines only: `Api/Router.cls`, `Kernel/EntityType.cls`, `Screen/Titles.cls`, `ui/src/app/core/{strings.ts,screens.generated.ts}`, `ui/src/app/shell/screen-outlet.ts`, `ui/tools/{screen-mirror.test.mjs,navigation.test.mjs,strings.test.mjs}`, `Test/{SurfaceCoverage,EndpointCoverage,Descriptor,ReadTool,ToolRoundTrip,StageTwoTools,PortGate,ClassicPageGate}.cls` and `scripts/ci-throwaway.sh`. Each is (contended: add-only). The implement stage re-runs `git log --no-merges origin/OCU-1-epic21 ^origin/feature/OCU-1_ocupilot-mvp -- <path>`.

- **`Port/AnalyticsPort.cls`:**
  - New `LIST` endpoints `FolderItemDefinition` and `DashboardWidgets`, each with criterion `item`. They join `ENDPOINTS` :133, `Pairs` :657 (`FOLDERPAIRS`), `Serves` :682 and `Collect` :1005, beside the folder-item branch :1278-1291 and reusing `ReadFolderItem` :4321 and `FolderItemShaped` :4298.
  - New `PivotStatement(namespace, item, Output statement, Output http, Output fault)`. It opens, refuses and composes, with `%GetBaseMDX` called from one seam. `MdxAnswer` :1934 is untouched; the kind adds `statement`.
- **`Area/Analytics/PivotRun.cls` (new)** extends `MdxQuery` (Rule 2), modeled on its `Admit` :68, `Body` :145 and `Check` :117. It sets `RUNKIND` `pivot` and `DESCRIPTORCLASS` Definition, and its body reads `item` in place of `statement`.
  - Routes in `Api/Router.cls` beside :248-250 and the three thin calls beside :1864-1883: `POST /analytics/pivot/background`, `GET .../:id` and `POST .../:id/cancel`.
- **`Screen/Tool/AnalyticsMdxRead.cls`:** `InputSchema` :50 makes `statement` and `pivot` exactly one (`oneOf`); `View` :146 calls `PivotStatement` first.
- **Descriptors (new):** `AnalyticsFolderItemDefinitionTab` and `AnalyticsDashboardWidgetsTab`, built in the cube tab group's form (`AnalyticsCubeDimensionsTab.cls`): group `analytics/folder-items/document`, `parentScope` `analytics/folder-items`, criterion `item`, `classicPage` `%DeepSee.UserPortal.DashboardViewer`. The Widgets `rowTarget` follows `InteropJobList.cls` :67. A new entity type is `dashboard-widget`.
- **`Api/AnalyticsError.cls`:** the code `PIVOTCUBE` beside `FOLDERITEMABSENT` :170, and in its roster :514.
- **Client (`ui/src/app/`):**
  - New `areas/analytics/folder-item-definition.page.ts` renders the row over `<app-detail-page />`. For a pivot it adds Run, the confirm (reusing `analyticsMdxConfirm*`) and the grid. It extends `mdx-query.store.ts`'s run (`MDX_BACKGROUND_PATH` :40, confirm :281) by parameterizing the path and body rather than copying, and draws with `core/mdx-answer.ts` and `core/background-run.ts`.
  - Widgets uses the shared list page.
  - Maps: `shell/screen-outlet.ts` `DESCRIPTOR_PAGES` (:288, :303); `core/strings.ts` (once ruled); `core/screens.generated.ts` and `Screen/Titles.cls`, regenerated.
- **Tests:**
  - New `Test/AnalyticsFolderItemView.cls`: both reads, as the screen read and as each derived tool; journal-clean reads (`AnalyticsProbe` `JournalMark`/`JournalWrites`); `^DeepSee.UserPreferences(user,"recent")` and `lastAccessed` unchanged; refusals; gate as principals.
  - New `Test/AnalyticsPivotRun.cls`: the routes, confirm, cells equal the vendor's, absent and cube refusals, the agent's `pivot` leg. It is modeled on `AnalyticsMdxRoutes` and `AnalyticsMdxRead` with their fixtures.
  - Both are armed beside the MDX lines in `scripts/ci-throwaway.sh` (:592-596) and `ui/tools/ci.test.mjs`.
  - Fixtures are probe items created by the test, beside `AnalyticsProbe` :244-251 and :1115.
- **Rosters (Rule 30):** re-grep `analytics/cubes/dimensions`, `AnalyticsCubeDimensionsTab`, `analytics.mdxquery.read` and `folder-item`. Expect hits in `Test/{Descriptor,ReadTool,SurfaceCoverage,StageTwoTools,ToolRoundTrip,DeveloperFloor,AnalyticsDescriptor,AnalyticsMdxRead}.cls`, `ui/tools/{screen-mirror,navigation,analytics}.test.mjs`, `ui/browser/{analytics,agent-mdx}.browser-spec.mjs` and `Kernel/EntityType.cls` with `Test/Descriptor.cls`'s vocabulary count. `ui/tools/analytics.test.mjs` forbids every call in Never and admits `%GetBaseMDX` only in its seam.
- **EXPERIENCE.md:** one Fixed strings row after :619.

## Tasks & Acceptance

**Execution:**

- [x] **Task 0** (`ocupilot-b-ci`, USER, probe items removed after): journal-scan `%FolderItemExists`, `%OpenFolderItem`, the property reads and `%GetBaseMDX()` on the matrix's pivot and dashboard. Record under Design Notes › Measured whether each wrote anything, and HALT if a read does.
- [x] `AnalyticsPort.cls`, `AnalyticsError.cls`, `PivotRun.cls` and the routes: endpoints, `PivotStatement` and the run kind.
- [x] `AnalyticsMdxRead.cls`: `pivot`.
- [x] The two descriptors, the entity type, the client page and store change, strings (once ruled), the regenerated mirror and titles, and the EXPERIENCE.md row.
- [x] Tests: the matrix in the two new classes, component and browser tests (`ui/browser/analytics.browser-spec.mjs`), and every roster.

- [ ] [Smoke] `ui/browser/a11y-structural-invariants.browser-spec.mjs` AC5 fails on the fresh throwaway (tree d45900450): "these screens need an id the walk could not resolve and are not in SKIP: analytics/folder-items/widgets, analytics/folder-items/document". HSCUSTOM is not analytics-enabled, so the walk cannot open a folder item there. Follow the 24.11/24.12 pattern: add both routes to `ui/browser/structural-walk.mjs`'s SKIP (add-only, one comment line naming Story 24.14), and make the SKIP reason true by having the Story 24.14 test in `ui/browser/analytics.browser-spec.mjs` run the structural and contrast checks (`structural(page, route)` at the same viewports as its siblings) on both screens in USER on its probe. Re-run both browser specs on the rebuilt bundle, first run green.

**Acceptance Criteria:**

- **AC1 (round trip, definitions).** Given the matrix's pivot and dashboard saved through their vendor classes, when Definition and Widgets are read by the screen and by their derived tools, then each field equals the stored property.
- **AC2 (round trip, run; Integration, Rule 1).** Given the pivot, when a person runs it on Definition and the agent calls `analytics.mdxquery.read` with `pivot`, then both answer the cells `%DeepSee.ResultSet` answers for its `%GetBaseMDX()`.
- **AC3 (nothing written by viewing).** Given both items, when every read runs, then the journal holds no write by those reads, and recent items and `lastAccessed` are unchanged.
- **AC4 (code and SQL).** Given a pivot whose stored restriction makes its MDX run SQL, when the person runs it, then they confirm first. When the agent runs it, then it is refused with `ANALYTICS.MDX.SQL`. A non-cube pivot is refused with `ANALYTICS.PIVOT.CUBE` before anything is composed.
- **AC5 (browser).** Given the probe dashboard, when a person opens it from Folder items, opens its pivot widget and runs it, then Widgets lists three rows, only the pivot row links, and the grid shows the pivot's cells.
- **AC6 (fresh, either order).** Given any new or changed test, run first on a fresh instance in either order, when it ends, then the probe folder holds only `AnalyticsProbe`'s items.

## Spec Change Log

- 2026-11-20, fresh check: re-opened for rework iteration 1 (one [Smoke] item: the structural walk has no SKIP or walk for the two new screens).

- 2026-11-20, spec gate (runner): Questions 1-6 ruled (veto item U-120): three batches (this spec Batch 1; Batch 2 the PMML tester; Batch 3 PMML New and Export to cube as confirmed writes with keys, so no scope is dropped); viewer pairs `%DeepSee_Portal:USE,%Development:USE` plus MdxAdmit; the agent's pivot argument; Batch 2's run as a person's read-kind run with the agent's models read only; the proposed strings; the AD-65 line left proposed.

## Review Triage Log

### 2026-11-20 — Review pass

- verdicts: 17 findings — high 0, medium 3, low 13, false 1, maybe-false 0
- findings:
  - `[medium]` `[patch]` A pivot grid's drill (Definition tab) is untested on both sides — a server drill leg (`AnalyticsPivotRun`) and a page spec drill case added; both mutations red.
  - `[medium]` `[patch]` NotPivot for `.metric` and `.worksheet` has no test — `AnalyticsFolderItemView` tests `WidgetNotPivot` over seven names; the `metric` mutation is red.
  - `[medium]` `[patch]` The pivot start's 403 leg does not isolate `%Development` — the principal now holds `%Ens_Portal`, `%DeepSee_Portal` and write on the database, so only the developer pair refuses it; asserts `failedPair`; mutation red.
  - `[low]` `[reject]` AC6's clause has no mutation line — the clause is hermeticity, no code change violates it, and the spec says so.
  - `[low]` `[reject]` Some mutation lines sit only in test headers — each AC has its line in `## Verification`; the headers add detail.
  - `[low]` `[reject]` AC3's recent-items oracle only sees a node's existence — the journal scan is the pinning check and its mutation (a `SET` of the node) went red.
  - `[low]` `[reject]` `Rows() = 0` takes no baseline — each test's `Settle` removes the account's rows and the sibling MDX route classes assert the same way.
  - `[low]` `[reject]` The composed-statement cap branch is untested — a guard of one comparison that no probe pivot can reach.
  - `[low]` `[reject]` The widget row cap is untested — the cap is the list's own `pMax` loop, shared with every read.
  - `[low]` `[reject]` The pivot run is a sibling route, not the MDX route with an `item` body (reading A1) — the Code Map names `/analytics/pivot/background`; the diff matches the spec.
  - `[low]` `[reject]` A confirmed restriction run ends in the vendor's own error, not cells — the Visits cube does not allow the `%SQLRESTRICT` dimension (Design Notes › Measured); the ask-first path and the reach to the vendor are pinned.
  - `[low]` `[reject]` Guarded and locked items are tested through the hidden-item seam, not as real principals — the code mapping is the shared `ReadFolderItem` that Story 24.10's list already pins; `PortGate` pins the pairs.
  - `[low]` `[reject]` NotPivot is checked against a reimplementation of the rule — the new direct test names each extension, which is the oracle the matrix needs.
  - `[low]` `[reject]` The round-trip oracle mirrors the port's property list — a property both sides misread together is not a realistic regression; the fixture sets every property to a distinct value.
  - `[low]` `[reject]` The Run button shows from the row's cube, so a KPI pivot shows Run and gets the refusal — by design, the refusal sentence is the answer and a jsdom spec pins it.
  - `[low]` `[reject]` The browser spec covers the dashboard-to-grid walk only — it is AC5; confirmation and refusals are pinned by the server classes and the page spec.
  - `[false]` `[reject]` The mutation line naming `FOLDERPAIRS` applies to the pivot start's gate — it does not, so the line now names the descriptor's privileges as well (corrected in `## Verification`).

### 2026-11-20 — Follow-up review pass (full-opus, four layers)

- verdicts: 22 findings — high 0, medium 4, low 17, false 1; 5 patched, 4 deferred, 13 rejected, no intent gap
- findings:
  - `[medium]` `[patch]` The agent's `pivot` read checked MDX query's pairs only, so an adjustment or a classic custom resource on the Definition tab did not reach it — `AnalyticsMdxRead.View` also evaluates `PIVOTDESCRIPTORCLASS`; `AnalyticsMdxReadGate.TestAPivotReadFollowsTheDefinitionTabsPairs`; mutation red.
  - `[medium]` `[patch]` "No row for an item that is neither a pivot nor a dashboard" had no test, and the test header claimed a mutation that stays green — a link fixture and its two legs in `TestAbsentHiddenAndOtherItemsReadNoRow`, header corrected; mutation red.
  - `[medium]` `[defer]` Definition omits filter selections, nested and disabled levels, calculated expressions and a userMDX stored without manual mode — spec-bound field contents (frontmatter `deferred:`).
  - `[medium]` `[defer]` A pivot run's confirmation is bound to the name, not to the composed text — needs a body or answer shape the spec does not have (frontmatter `deferred:`).
  - `[low]` `[patch]` The start's own error answer lacked `statement` — `MdxQuery.Admit` annotates every immediate answer but a confirm; asserted in `TestARestrictionAsksFirstAndTheAgentIsRefused`; mutation red.
  - `[low]` `[patch]` The Definition tab's Cancel was untested — a page spec case; mutation red.
  - `[low]` `[patch]` The arming comment in `scripts/ci-throwaway.sh` said one probe principal — three.
  - `[low]` `[defer]` Widgets rows carry no widget name, so LinkedTo cannot be matched to a row — spec-bound fields (frontmatter `deferred:`).
  - `[low]` `[defer]` The KPI-pivot refusal is pinned with a KPI nothing defines — a compiled probe KPI is outside this batch's fixtures (frontmatter `deferred:`).
  - `[low]` `[reject]` Every folder item's name opens the viewer, and a pivot's Widgets tab is empty — by design (Decided in-stage (plan) 1; the tabs' empty states).
  - `[low]` `[reject]` The pivot path reuses MDX query's input and SQL refusal sentences — the spec reuses the codes, and a new sentence would be a new string.
  - `[low]` `[reject]` An item deleted between `ReadFolderItem` and `VendorPivotMdx` composes `""` — the window is two opens in one call, and the answer is the vendor's own error outcome.
  - `[low]` `[reject]` `pivot` carries no `maxLength` — an over-long name is the explicit 404 absent refusal.
  - `[low]` `[reject]` The `Stored()` oracle's NotPivot knows `kpi` only — no fixture widget uses another extension, and `WidgetNotPivot` has its own test over seven names.
  - `[low]` `[reject]` `AnalyticsPivotRun`'s `Code`, `PasswordOf`, `Send`, `RunToEnd` and `Settle` resemble `AnalyticsMdxRoutes`' — test-only helpers that differ in kind filter, owners and type capture; a shared base would couple two classes' principals.
  - `[low]` `[reject]` Each run kind has its own busy slot — `BackgroundRun` reserves by `RUNKIND` for every kind, and `MaxRunning` caps them together; "the same caps" are MDX query's row, cell and time bounds.
  - `[low]` `[reject]` AC3's journal scan does not cover the screen's HTTP reads — the screen and the tool reach the same port read, which is scanned in process; `Touched()` covers the HTTP legs.
  - `[low]` `[reject]` The "601 characters" case is 607 — a name over the bound is also a name no item holds, so the bound is not observable at this surface.
  - `[low]` `[reject]` AD-65 does not describe the `pivot` kind — the line is proposed for the owner's attended update (Design Notes, Residual).
  - `[low]` `[reject]` Composing at the start also writes the session counter — the spec has the start and the job each compose; both are inside the run and `MdxAdmit` requires WRITE there.
  - `[low]` `[reject]` `AnalyticsPivotRun.cls` (510 lines) and `AnalyticsFolderItemView.cls` (517) exceed the 500-line guide — a split class declares the arming variable and needs a new roster line in `scripts/ci-throwaway.sh` and `ui/tools/ci.test.mjs`.
  - `[false]` `[reject]` Attaching to another pivot's busy run shows its cells under this item — `settle` clears `attempt` on a busy refusal and `adopt` requires one, so no grid is adopted and no drill can be sent.

## Design Notes

**Questions for the runner (intent gap).**

1. **Batches (Rule 5 tier 2).** The two catalog rows are a viewer (AN-17) and a console (AN-16), each the size of 24.13's batches. Recommended: two batches, each planned after the previous code head lands.
   - **Batch 1 (this spec):** the viewer.
   - **Batch 2:** the PMML model tester.
     - A side-bar list, "PMML models": class, model, type, target and the definition's data sources. It is read by the vendor's own finder list of `%DeepSee.PMML.Definition` subclasses and `%GetModels`, measured pure.
     - A test sub-screen whose run is a third kind of `Kernel/Shell/BackgroundRun`. It calls `%DeepSee.PMML.Utils` `%RunModel`, `%RunModelFromPMMLRows` or `%RunModelFromSQL` inside the run's time bound and cancel.
     - The answer gives record count, precision, recall and F-measure (micro and macro) and per-actual-value counts, or for a continuous target sigma, RSE and R², plus capped row details. Charts are not drawn.
     - After reading, the run drops the vendor's shared `^IRIS.Temp.DeepSee.PMML.Result*` rows with `%DropResults`.
     - The probe definition is compiled by the test and deleted after. None exists on `ocupilot-b-ci` (measured).
2. **Pairs (veto: stricter than classic).** `DashboardViewer` admits `%DeepSee_Portal` or `%DeepSee_PortalEdit`. Recommended: Folder items' `%DeepSee_Portal:USE,%Development:USE` plus `MdxAdmit`, because the viewer is Folder items' sub-screen and its run is MDX query's. Alternative: `PORTALPAIRS`, which would also need the run's own pair set.
3. **The agent runs a pivot.** Recommended: `pivot` on `analytics.mdxquery.read`, as above. Alternative: the two definition reads only.
4. **PMML New and Export (scope, owner-only).** The classic tester's "New" imports a PMML file into a compiled class. Its "Export test results to cube" creates, drops and compiles classes. Both are writes beyond a test run. Recommended: a Batch 3 adds them as confirmed writes with keys. Alternative: leave them to the classic page with an exclusion-register row; that drops scope, which is the owner's call.
5. **Batch 2's run classification (decided now so Batch 2 plans on it).**
   - Recommended: a person's read-kind run, the precedent being MDX and SQL query.
     - No key and no proposal.
     - A custom data source must classify as a query through `SqlPort.Classify`, else it is refused. A function the query calls can still change state (named limit, as on SQL query).
     - The model's generated code runs with the person's rights (named limit, as a cube build).
     - The agent gets the models read only, because an agent read never executes code and a test runs the model's code and SQL.
   - Alternative A: the run-code exception (`PERSONGATE`, key `false`).
   - Alternative B: also an agent run over the definition's own data sources.
6. **Proposed strings (veto).**
   - Tabs: "Definition" · "Widgets".
   - Labels: "Data source" · "Filters" · "Calculated members" · "SQL restriction".
   - Reused: Name, Type, Title, Description, Owner, Modified, Cube, Rows, Columns, Measures, MDX, Linked to, Run, "Run this query?" and its consequence, and the MDX grid's strings.
   - Empty states: "This folder item is not a pivot or a dashboard, or it no longer exists." · "This folder item is not a dashboard, or it has no widgets."
   - Refusal: "This folder item is not a pivot on a cube this namespace holds, so it runs only in the classic portal." The absent refusal reuses "This folder item no longer exists."
   - Prompts, Definition: "Explain what this pivot shows." · "Which cube and filters does this pivot use?" · "Run this pivot and summarize its answer."
   - Prompts, Widgets: "Summarize the widgets on this dashboard." · "Which widgets show a pivot, and which a KPI?" · "Which widget takes its data from another widget?"
   - No agent empty-state phrase, since the tabs offer no action.

**Proposed spine line (the owner's attended update; never written here).** AD-65: "The dashboard and pivot viewer (Story 24.14) reads stored definitions with `%FolderItemExists`, `%OpenFolderItem` and property reads, measured to write nothing, and never calls `%RegisterRecentItem`. A pivot runs as MDX query's run, its statement composed inside the run by the vendor's `%GetBaseMDX()`, so a stored restriction asks first on the screen and is refused to the agent. A KPI, metric or worksheet data source runs nothing."

**Decided in-stage (plan).**

1. **One viewer, two tabs.** Folder items' name opens one tab group for both types through the `<list>/document` convention, as Cubes' name opens the cube tabs.
2. Composition happens in the run, so a read stays pure whatever `%GetBaseMDX` measures.
3. `pivot` extends the existing agent tool and `MdxQuery` rather than adding a tool or a copy of the run (Rule 2).

**Measured (Task 0, implement, 2026-11-20, `ocupilot-b-ci`, USER; the probe, a full pivot, a manual pivot and a three-widget dashboard saved through the vendor's classes first, all removed after).** A journal scan of this process from `JournalMark` found no set or kill from `%FolderItemExists`, `%OpenFolderItem`, the reads of `title`, `description`, `owner`, `timeModified`, `lastAccessed`, `cubeName`, the four level lists' `spec`, the calculated members, `sqlRestriction`, `manualMode`, `userMDX` and a dashboard's `widgets` (name, type, title, `dataSource`, `dataLink`, `%GetDataSource()`); `lastAccessed` read empty and `^DeepSee.UserPreferences` held no `recent` node before or after. Two calls of `%GetBaseMDX()` wrote exactly two records, `SET ^DeepSee.Cache.LocalResults("session")` (the vendor's session counter, in the database `MdxAdmit` already requires WRITE on), so composition stays inside a run. Its text for the full pivot ended `%FILTER %SQLRESTRICT.&[Amount > 0]`, which `MdxConstructs` finds; a manual pivot composes its `userMDX` unchanged. The probe Visits cube does not allow the `%SQLRESTRICT` dimension, so a confirmed run of a restricted pivot over it reaches the vendor, whose prepare answers `Invalid Member spec: ...%SQLRESTRICT...` as the run's error outcome.

**Decided in-stage (implement).**

1. **The tab group is `analytics/folder-items/document`, not `.../view`.** `screen-mirror.mjs` refuses any other id for a parent-scoped group ("a parent-scoped group is its parent list's `/document`"), and that convention is what makes the list's name cell link to it (`documentScreenFor`), so the Folder items list declares no `rowTarget`. Widgets keeps its `rowTarget` on DataSource to the Definition route. The Definition tab's label is the existing `agentDefinitionFormLabel` ("Definition"), because the string source holds each value once.
2. **No per-widget lookup.** `NotPivot` is the extension rule of the classic pivot widget alone (empty, `.kpi`, `.metric` or `.worksheet`); the widget's item is not opened to check that it is a pivot.
3. **The reads are `ReadFolderItem` with a detail flag.** The pivot and dashboard properties are read inside the one switched block, so no OcuPilot class is named there; the endpoints are served by `Invoke` before `Collect`, as rows built after the restore. The hidden-item test seam gained the flag.
4. **`MdxQuery` gained four hooks** (`TEXTKEY`, `TextValid`, `Resolve`, `Annotate`), which `PivotRun` overrides; the request list carries the item's name and the job composes the statement again. `AnalyticsPort.Cut` is public so the run and the agent cut `statement` the same way.
5. **The client run is `MdxQueryState` over a `MdxRunKind`** (`{path, textKey, cubes}`), and the answer area is the new `MdxRunView`, drawn by MDX query and by the Definition tab; a drill-through is offered on the Definition tab's grid as on MDX query's. A run's state belongs to the page and its item.
6. **The agent's `pivot` schema is optional for both properties** (`oneOf` is not in the emitted subset); `View` refuses both or neither with 400 `TOOL.ARGUMENTS`.
7. **`PivotStatement` makes `MdxAdmit` its first step**, so a pair or a namespace refusal precedes any vendor call, and a name that fails `FolderItemShaped`, including an empty one, is 404 absent, so the run's `TextValid` accepts any string.

**Governing ADs (Rule 6):** AD-5, AD-7, AD-8, AD-11, AD-13, AD-16, AD-24, AD-29, AD-36, AD-39, AD-41, AD-42, AD-43, AD-44, AD-60, AD-65. AD-22: no key, because every call here is a read.

**Integration and linkage (Rules 1, 2).**

- **Consumes:** `AnalyticsPort`'s folder-item reads and `Mdx*` calls, `MdxQuery`, `BackgroundRun`, `AnalyticsMdxRead` and `AnalyticsProbe`.
- **Consumed-by:** Batch 2 reuses `PivotRun`'s kind pattern. AC2 is the Integration AC.

**Ledger inbox (Rule 17):** none (`LEDGER slice` is empty). DW-2451, stored definitions not inspected, still applies to a pivot's named filters and shared members.

## Verification

**Commands** (one `ci-runner` call per message; `ocupilot-b-ci` only):

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.AnalyticsFolderItemView`, then likewise `AnalyticsPivotRun`, `AnalyticsMdxRead`, `AnalyticsMdxRoutes`, `AnalyticsDescriptor`, `PortGate` and every class the roster sweep changes. Expected: green, with new classes green on their first run.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`. Expected: green.
- `(loop)` `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/analytics.browser-spec.mjs browser/agent-mdx.browser-spec.mjs`. Expected: green.
- `(once)` The full ObjectScript sweep: `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17`, for k = 1 to 17, one call each. Expected: green.
- `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh`. Expected: clean. The full browser suite is left to CI.

**Shared surfaces:**

- Folder items' name cell, which now links;
- the entity-type vocabulary;
- the read-tool and coverage rosters;
- `analytics.mdxquery.read`'s input schema;
- the background-run kinds;
- `screen-mirror.test.mjs`;
- `DeveloperFloor`'s screens and tools;
- the arming roster;
- the `analytics.test.mjs` guard.

**Hermeticity:** every test added or changed passes on its first run on a fresh instance, in either order, and removes the folder items it creates.

**Mutations:** each applied to `ocupilot-b-ci`'s copy (synced, loaded and compiled; the client one with the bundle rebuilt and copied in), observed red, reverted (`shasum` of the four mutated files equal before and after) and reloaded.

- mutation: AC1 `AnalyticsPort.ReadFolderItem` reads `Filters` from `rowLevels` -> `TestAPivotsDefinitionIsWhatItsClassHolds` red alone on its port and screen legs (`AnalyticsFolderItemView` run 61).
- mutation: AC1 `AnalyticsPort.ReadFolderItemView` reads `LinkedTo` from the data source -> `TestADashboardsWidgetsAreInTheOrderTheyAreStored` red alone (run 61).
- mutation: AC3 `ReadFolderItem` sets `^DeepSee.UserPreferences(user,"recent",...)` -> `TestAAReadsWriteNothingAndTouchNoRecentItem` red naming the `SET` records (run 61); the node it left was killed by hand afterwards.
- mutation: AC2 `PivotRun.Resolve` answers the item's name as the statement -> `TestARunAnswersTheCellsTheVendorAnswersForThePivotsMdx`, `TestTheAgentRunsTheSamePivotToTheSameCells`, `TestAbsentAndNonPivotItemsAreRefusedBeforeAnythingRuns` and the restriction test red (`AnalyticsPivotRun` run 63).
- mutation: AC4 `MdxQuery.Check` skips the construct detection -> `TestARestrictionAsksFirstAndTheAgentIsRefused` red (run 62); `AnalyticsPort.PivotStatement` without its `cubeExists` test -> `TestAbsentAndNonPivotItemsAreRefusedBeforeAnythingRuns` red on the KPI pivot, screen and agent legs (run 62).
- mutation: AC5 `FolderItemDefinitionPage.isPivot` answers false for a pivot (bundle rebuilt and redeployed) -> the Story 24.14 browser test red, waiting 30 s for Run.
- mutation: AC1 `AnalyticsPort.WidgetNotPivot` drops `metric` -> `TestAWidgetsDataSourceIsAPivotUnlessItsExtensionSaysOtherwise` red alone (`AnalyticsFolderItemView` run 75).
- mutation: AC2 `MdxQuery.Process` drops the drill's row -> `TestADrillOfAPivotsCellAnswersThatCellsListing` red alone (`AnalyticsPivotRun` run 76); the Definition page's drill sends `statement` in place of `item` -> its drill spec red.
- mutation: AC4 the gate: `%Development:USE` dropped from `MDXPAIRS` and from the Definition tab's privileges -> `TestTheGateRefusesBeforeAnyLookup` red alone (`AnalyticsPivotRun` run 73; dropping `FOLDERPAIRS` and `MDXPAIRS` alone stays green because the descriptor's privileges also refuse).
- mutation: QA AC1 `AnalyticsPort.ReadFolderItemView` without its `pMax` test -> `TestTheWidgetsReadIsCutAtTheCapAndSaysSo` red alone on its port leg (`AnalyticsFolderItemView` run 19).
- mutation: QA AC4 `AnalyticsPort.PivotStatement` without its `FolderItemVisible` test -> `TestAWidgetOnAMissingPivotReadsAsStoredAndItsLinkEndsInTheAbsentRefusal` red alone (run 20).
- mutation: QA AD-60 `Sanitize.Neutralize` answers its text unchanged -> `TestStoredTextReachesTheModelOnlyThroughTheSanitizer` red alone, on both tools' delimiter and value legs (run 21).
- mutation: QA AC4 `MdxQuery.Check` and `AnalyticsMdxRead.View` skip both construct detections -> `TestAPivotWhoseStoredMdxRunsCodeAsksFirstAndTheAgentIsRefused` red, with the restriction test (`AnalyticsPivotRun` run 22).
- mutation: QA AC4 `AnalyticsPort.ReadFolderItem` without its `%CheckResource` test for a locked item -> `TestAGuardedOrLockedPivotIsAbsentToAPrincipalWhoLacksItsResource` red alone on the locked leg (run 23).
- mutation: QA AC4 `AnalyticsPort.MdxAdmit` without its destination check -> `TestTheRunNeedsWriteOnTheCacheDatabaseAndTheReadsDoNot` red alone (run 24). Each QA mutation was made on the throwaway's copy, loaded with its subclasses recompiled, and reverted by copying the tree's file back (`diff -rq` of the tree and the copy empty afterward).
- mutation: review AC2 `MdxQuery.Admit` without its `Annotate` of an immediate answer -> `TestARestrictionAsksFirstAndTheAgentIsRefused` red alone on the start's error answer (`AnalyticsPivotRun` run 30).
- mutation: review AC1 `AnalyticsPort.ReadFolderItemView` without its test of the item's kind -> `TestAbsentHiddenAndOtherItemsReadNoRow` red alone on the link leg (`AnalyticsFolderItemView` run 31); without its `FolderItemVisible` test it stays green (run 33), since a hidden item reads no kind.
- mutation: review gate `AnalyticsMdxRead.View` without its evaluation of `PIVOTDESCRIPTORCLASS` -> `TestAPivotReadFollowsTheDefinitionTabsPairs` red alone (`AnalyticsMdxReadGate` run 32).
- mutation: review client `FolderItemDefinitionPage.onCancelRun` sends nothing -> the page spec's Cancel case red alone; dropping `state.busy()` from `blocked` stays green, since the run state refuses a second start itself. The server mutations of runs 30 to 32 were made on the throwaway's copy together and run 33's alone, each with the port's, the run's and the tool's subclasses recompiled, and reverted by `rsync` of the tree (`diff -rq` empty); the client one with `shasum` equal before and after.
- Not run against a mutation: AC6's fresh-instance clause (`ci-runner` has no order option; each new class was green on its first run on `ocupilot-b-ci`, which held no probe state, and left `Gone()` true); the component spec's `Mutation (Rule 19)` lines name their changes in its comments.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** Batch 1, the dashboard and pivot viewer: a folder item's name opens `analytics/folder-items/document` with a Definition tab (one row; Run, confirm and the grid for a pivot) and a Widgets tab. `AnalyticsPort` gains the `FolderItemDefinition` and `DashboardWidgets` reads and `PivotStatement` (the one `%GetBaseMDX` seam); `MdxQuery` gains four hooks and `PivotRun` is its `pivot` kind on `/analytics/pivot/background`; `analytics.mdxquery.read` takes exactly one of `statement` and `pivot`. Nothing is written by viewing (Task 0, Design Notes › Measured).

**Files.** Server: `Port/AnalyticsPort.cls`, `Api/{AnalyticsError,Router}.cls`, `Area/Analytics/{MdxQuery,PivotRun}.cls`, `Screen/Descriptor/{AnalyticsFolderItemDefinitionTab,AnalyticsDashboardWidgetsTab,AnalyticsFolderItemList}.cls`, `Screen/Tool/AnalyticsMdxRead.cls`, `Screen/Titles.cls`, `Kernel/EntityType.cls`. Client: `folder-item-definition.page.ts`, `mdx-run-view.ts`, `mdx-query.{page,store}.ts`, `screen-outlet.ts`, `strings.ts`, `screens.generated.ts`. Tests: `Test/{AnalyticsFolderItemView,AnalyticsPivotRun}.cls`, `analytics.browser-spec.mjs`, `folder-item-definition.page.spec.ts`, the rosters (`SurfaceCoverage`, `EndpointCoverage`, `ReadTool`, `StageTwoTools`, `ToolRoundTrip`, `Descriptor`, `DeveloperFloor`, `Navigation`, `PortGate`, `AnalyticsDescriptor`, `SaveHoldCoverage`, `DeveloperFloorRoutes`, the `ui/tools` tests, `ci-throwaway.sh` arming line) and one EXPERIENCE.md row.

**Review.** 17 findings: 3 medium patched (a pivot drill leg and page spec, `WidgetNotPivot` extensions, the start's `%Development` gate leg), 13 low and 1 false rejected, none deferred (see the triage log).

**Verification.** On a rebuilt `ocupilot-b-ci`: both new classes green on their first run, forward and reverse (runs 1 to 4); the 17-shard sweep green after two roster rows each for `SaveHoldCoverage` and `DeveloperFloorRoutes` (both rerun green); `test:tools` 2337 of 2337; the Definition page spec 6 of 6; `analytics.browser-spec.mjs` 17 of 17; `check-objectscript` and `lint-docs` clean; initial bundle 2.16 MB, under the warning. The rebuild also showed that a first compile of the whole tree failed on the two new test classes reading `AnalyticsProbe`'s constants, so each now declares `DependsOn = OcuPilot.Test.AnalyticsProbe`.

**Follow-up review recommended: true.** Three medium patches landed with no second review; each has its mutation line, and the gate leg is the one most likely to hide a second layer.

**Residual.** A confirmed restriction run reaches the vendor's own error on the probe cube (named limit); the AD-65 line stays proposed.
