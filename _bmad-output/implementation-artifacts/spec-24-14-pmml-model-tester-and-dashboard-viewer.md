---
title: 'Story 24.14: PMML model tester and dashboard viewer (Batch 1: the dashboard and pivot viewer)'
type: 'feature'
created: '2026-11-19'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-13-analytics-settings.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-13-analytics-settings-3.md'
warnings: ['oversized', 'multiple-goals']
deferred: []
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
- **Descriptors (new):** `AnalyticsFolderItemDefinitionTab` and `AnalyticsDashboardWidgetsTab`, built in the cube tab group's form (`AnalyticsCubeDimensionsTab.cls`): group `analytics/folder-items/view`, `parentScope` `analytics/folder-items`, criterion `item`, `classicPage` `%DeepSee.UserPortal.DashboardViewer`. The Widgets `rowTarget` follows `InteropJobList.cls` :67. A new entity type is `dashboard-widget`.
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

- [ ] **Task 0** (`ocupilot-b-ci`, USER, probe items removed after): journal-scan `%FolderItemExists`, `%OpenFolderItem`, the property reads and `%GetBaseMDX()` on the matrix's pivot and dashboard. Record under Design Notes › Measured whether each wrote anything, and HALT if a read does.
- [ ] `AnalyticsPort.cls`, `AnalyticsError.cls`, `PivotRun.cls` and the routes: endpoints, `PivotStatement` and the run kind.
- [ ] `AnalyticsMdxRead.cls`: `pivot`.
- [ ] The two descriptors, the entity type, the client page and store change, strings (once ruled), the regenerated mirror and titles, and the EXPERIENCE.md row.
- [ ] Tests: the matrix in the two new classes, component and browser tests (`ui/browser/analytics.browser-spec.mjs`), and every roster.

**Acceptance Criteria:**

- **AC1 (round trip, definitions).** Given the matrix's pivot and dashboard saved through their vendor classes, when Definition and Widgets are read by the screen and by their derived tools, then each field equals the stored property.
- **AC2 (round trip, run; Integration, Rule 1).** Given the pivot, when a person runs it on Definition and the agent calls `analytics.mdxquery.read` with `pivot`, then both answer the cells `%DeepSee.ResultSet` answers for its `%GetBaseMDX()`.
- **AC3 (nothing written by viewing).** Given both items, when every read runs, then the journal holds no write by those reads, and recent items and `lastAccessed` are unchanged.
- **AC4 (code and SQL).** Given a pivot whose stored restriction makes its MDX run SQL, when the person runs it, then they confirm first. When the agent runs it, then it is refused with `ANALYTICS.MDX.SQL`. A non-cube pivot is refused with `ANALYTICS.PIVOT.CUBE` before anything is composed.
- **AC5 (browser).** Given the probe dashboard, when a person opens it from Folder items, opens its pivot widget and runs it, then Widgets lists three rows, only the pivot row links, and the grid shows the pivot's cells.
- **AC6 (fresh, either order).** Given any new or changed test, run first on a fresh instance in either order, when it ends, then the probe folder holds only `AnalyticsProbe`'s items.

## Spec Change Log

- 2026-11-20, spec gate (runner): Questions 1-6 ruled (veto item U-120): three batches (this spec Batch 1; Batch 2 the PMML tester; Batch 3 PMML New and Export to cube as confirmed writes with keys, so no scope is dropped); viewer pairs `%DeepSee_Portal:USE,%Development:USE` plus MdxAdmit; the agent's pivot argument; Batch 2's run as a person's read-kind run with the agent's models read only; the proposed strings; the AD-65 line left proposed.

## Review Triage Log

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

1. **One viewer, two tabs.** A row target names one route (`Registry.cls`, contended), so Folder items' name opens one tab group for both types, as Cubes' name opens the cube tabs.
2. Composition happens in the run, so a read stays pure whatever `%GetBaseMDX` measures.
3. `pivot` extends the existing agent tool and `MdxQuery` rather than adding a tool or a copy of the run (Rule 2).

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

**Mutations:** the implement stage records one per AC here, as `mutation: <change> -> <test red>`.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none (intent gap ruled at the spec gate, U-120)
