---
title: 'Story 24.14: PMML model tester and dashboard viewer (Batch 2: the PMML model tester)'
type: 'feature'
created: '2026-11-20'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-14-pmml-model-tester-and-dashboard-viewer.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The classic `%DeepSee.PMML.UI.ModelTester` lists a namespace's PMML models and tests one against a data source. OcuPilot has no screen for either (catalog AN-16).

**Approach:** This is Batch 2 of the three ruled in Batch 1 (Design Notes › Questions 1, 4 and 5, veto item U-120). A side-bar list, **PMML models**, has one row per model, and its derived read is the agent's. A model's name opens **Test**, a detail sub-screen that shows the model's row and runs a test. The run is a third background-run kind, a person's read-kind run like SQL query's and MDX query's. It reads its answer from the vendor's shared result rows and then drops them. "Round-trips over its backing class" means two things here. First, the rows equal what the definition class's own methods report. Second, a run's answer equals the vendor's own metrics for the same model and data source.

## Boundaries & Constraints

**Always:**

- **Reads are pure (AD-65).** They call the vendor's finder list of `%DeepSee.PMML.Definition` subclasses (`%ZEN.FinderUtils.%GetClassListArray`, `sub`), `%GetModels`, `%GetModelClassName`, the model class's `%GetPredictedFieldInfo` and `%GetDefinition`, and the definition's `%GetDefinition`. Task 0 measures each one to write nothing.
  - Row fields: `{Class, Model, Type, Target, TargetType, DataSources, Verification}`.
  - `DataSources` is each `isc:datasource` extension's name, one per line, as `ModelTester.OnSelectModel` :225-253 enumerates them. `Verification` is true when the model has a `ModelVerification` element.
  - The id is composite `[Class, Model]`, written as the vendor's form `Class||Model`, kept exactly (AD-13).
- **The run (AD-7, AD-41, AD-42).** It lives in a new `PmmlTest` class that extends `Kernel/Shell/BackgroundRun` with `RUNKIND` `pmml`. Its routes are `POST /analytics/pmml/background`, `GET .../:id` and `POST .../:id/cancel`.
  - The body is `{model, source, dataSource?, sql?}`. `source` is `dataset`, `verification` or `custom`. `dataSource` is required for `dataset`, `sql` for `custom`, and neither is allowed with any other source.
  - The start and the job each resolve the run in order:
    1. The definition is a compiled subclass and the model is among its `%GetModels`.
    2. A `dataset` is one the definition declares, and `verification` needs `Verification`.
    3. An SQL source, the custom text or a declared `X-SQLDataSource`'s SQL, passes SQL query's own `SqlConsole.Check` (classification and self-protection) and must classify as `query`.
    4. A cube source's cube must be one `%CubeExists` holds and `%CheckPrivilege` admits.
  - A prepare error answers `{outcome: error, message}` at once, and nothing is spawned.
  - The job allocates the test id with `TempResult.GetNewTestId()`. It calls `%RunModel`, `%RunModelFromPMMLRows` or `%RunModelFromSQL` with `pTracking` 0, under an alarm of `MDXSECONDS`. It reads the answer, then drops the id's rows on every path: answered, error, stopped, canceled or fault.
- **The answer.** It is one of these:
  - `{outcome: ran, mode, records, values[], rows[], truncated}`;
  - `{outcome: error, message}`, where the message is `ErrorAnswer`'s and cut at `MDXMAXCELL`;
  - `{outcome: stopped, seconds}`.

  Its parts:
  - **A categorical model** adds `precision`, `recall` and `fMeasure`, each `{micro, macro}` from `TempResult.GetAggregatePrecisionMetrics`.
  - **A continuous model** adds `sigma`, `rse` and `rSquared`, computed as `AbstractTester.GetTestResults` computes them.
  - **`values`** has one entry per actual value: `{actual, records, correct, incorrect}`.
  - **`rows`** is each record's `{record, actual, predicted, probability}` in ID order.
  - **Caps:** `values` and `rows` are cut at `MDXMAXROWS`, and `truncated` says so.

  The results are read with embedded SQL bound to the test id.
- **Gate (AD-8, AD-29, AD-44).** Both screens and the run take the new `PMMLPAIRS` pairs, `%DeepSee_Portal:USE,%Development:USE` (the classic page's `%Development` plus the analytics pages' portal pair). They also pass `AdmitNamespace`.
- **The agent (AD-60, AD-11).** It gets the two derived reads and no run.

**Never:**

- The vendor calls `CreateFromFile`, `CreateFromStream`, `CreateFromString`, `%OnSubmit`, `ExportToCubeDefinition`, `%DropAllResults` and `%GetModelInstance`, a model's `%ExecuteModel` outside the vendor's run, `pTracking` 1, and the record-details redraw.
- A score threshold, charts, a governance key, a proposal or a confirmation.
- PMML New and Export to cube (Batch 3).
- A spine edit; any edit of `ui/angular.json` or `ui/vitest-base.config.mjs`; a `scripts/ci-throwaway.sh` edit beyond add-only roster lines.

## I/O & Edge-Case Matrix

Every row runs in USER on `ocupilot-b-ci`. The probe is `OcuPilotProbe.Pmml`: a source table and a definition with a categorical model and a continuous model, each with an SQL data source and verification records, and a cube data source named for a cube nobody holds. The test compiles it and removes it after.

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| List and Test reads | The probe | One row per model, each field equal to the vendor call it comes from; the Test tab's one row equals the list's | - |
| Run, three sources | Each model × dataset, verification, custom SQL; the screen | Metrics, values and rows equal the vendor's own run over the same source; afterwards no result row is left for either id | - |
| Not a query | Custom `UPDATE ...`; custom SQL naming OcuPilot's state | Refused, nothing spawned | 422 `ANALYTICS.PMML.QUERYONLY`; 403 (self-protection) |
| Unpreparable | Custom SQL that does not prepare | `{outcome: error}` at once | - |
| Absent or undeclared | A missing class or model; a `dataSource` not declared; verification when there is none | Refused | 404 `ANALYTICS.PMML.ABSENT`; 400 `ANALYTICS.PMML.INPUT` |
| Cube | The cube source | Refused before the vendor runs | 409 `ANALYTICS.PMML.CUBE` |
| Bound, cancel, owner | A slow custom cross join with a short-bound fixture; a cancel; a poll by another user; a second start | `stopped`; `canceled`; 404; 409 busy; rows dropped in every case | `ANALYTICS.PMML.NOTFOUND`, `.BUSY` |
| Shape and gate | A stray body key; no `%Development:USE`; analytics off | Refused before any vendor call | 400 `.INPUT`; 403; 409 `ANALYTICS.NAMESPACE` |

</intent-contract>

## Code Map

Paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-24` (HEAD `cb997d156`).

**Contention.** These files are (contended: add-only):

- `Kernel/EntityType.cls`, `Screen/Titles.cls` and `scripts/ci-throwaway.sh`;
- `ui/src/app/core/{strings.ts,screens.generated.ts}` and `ui/src/app/shell/screen-outlet.ts`;
- `ui/tools/{screen-mirror,navigation}.test.mjs`;
- `Test/{SurfaceCoverage,Descriptor,ReadTool,ToolRoundTrip,StageTwoTools,PortGate,ClassicPageGate}.cls`;
- the EXPERIENCE.md folder.

The implement stage re-runs the `git log` check before editing.

**Vendor, read-only:**

- `irislib/%DeepSee/PMML/Utils.cls`: the three run calls (:139, :407, :456) and `%DropResults` (:573).
- `irislib/%DeepSee/PMML/Utils/TempResult.cls`: the shared result table in IRISTEMP.
- `irislib/%DeepSee/PMML/Definition.cls`: :40, :134 and :172.
- `irislib/%DeepSee/PMML/UI/ModelTester.cls`: `TestModelAsync` :150 and `OnSelectModel` :174.
- `%DeepSee.PMML.UI.AbstractTester`: `GetTestResults` :479 and the per-value SQL :259. It is `Hidden`, so read it from `ocupilot-b-ci` with `%Compiler.UDL.TextServices.GetTextAsString`, as `.claude/rules/reference-folders.md` describes. Its page `RESOURCE` is `%Development`.

**Server:**

- **`Port/AnalyticsPort.cls`:**
  - New `LIST` endpoints `PmmlModels` and `PmmlModel` (criterion `model`). They join `ENDPOINTS` :133, `Pairs` :666 (`PMMLPAIRS` beside `FOLDERPAIRS` :203), `Serves` :691, `Collect` :1022 and `Rows` :1320.
  - New `PmmlResolve` (the run's checks) and `PmmlRun` (allocate, vendor call, read, drop). `PmmlRun` is the one seam that names the run calls and `%DropResults`, and it reuses `Alarmed` :2264, `AlarmSeconds` :2281, `StoppedAnswer` :2289, `ErrorAnswer` :2310 and `Cut` :2322.
- **`Area/Analytics/PmmlTest.cls` (new).** It follows `Area/Explorer/SqlBackground.cls`'s `Admit` :51, `Work` and `QueryOnly` :183, and it calls `Area/Explorer/SqlConsole.cls` `Check` :151 and `ErrorOutcome` :180.
  - Hoist `MdxQuery.MdxStopRequested` :321 into `BackgroundRun.StopRequested`, which the MDX hook calls (Rule 2).
  - `CancelJob` is `MdxQuery`'s one-line `CancelQuery` :340. It is copied because a shared base would couple the two kinds.
- **`Kernel/State/SqlRun.cls`:** the class comment's kinds (:6-10) name `pmml`.
- **`Api/Router.cls`:** three routes beside :248-253 and three thin calls beside :1870-1907.
- **`Api/AnalyticsError.cls`:** the codes `PMML{INPUT,ABSENT,QUERYONLY,CUBE,BUSY,FULL,NOTFOUND,LOST}` beside :170-177, with `ReasonFor` :408-438 and the roster :520.
- **Descriptors (new):**
  - `AnalyticsPmmlModelList`, built in the form of `AnalyticsFolderItemList`: route `analytics/pmml-models`, `sideBarPosition` 12, id `composite [Class, Model]`, `classicPage` `%DeepSee.PMML.UI.ModelTester`.
  - `AnalyticsPmmlModelTest`: route `analytics/pmml-models/test`, archetype `detail`, `parentScope` `analytics/pmml-models`, not a tab (as `TaskDetails.cls`), with one criterion `model` in the form of `InteropItemTestTab.cls`.
  - The entity type `pmml-model`.

**Client (`ui/src/app/`):**

- New `areas/analytics/pmml-model-test.page.ts`: `<app-detail-page />`, then the data-source choice, the SQL box for a custom source, Run and Cancel, the status line and the answer tables, in the form of `folder-item-definition.page.ts`.
- New `pmml-test.store.ts`: it configures `core/background-run.ts`'s `BackgroundRun` (`BackgroundConfig` :45) with `mdxRefusalText` :87. The PMML codes join that function's `REFUSAL_SENTENCES` map (`mdx-query.store.ts` :72-84).
- `shell/screen-outlet.ts` gets an entry beside :307. `core/strings.ts` gets the strings once ruled. The mirror and the titles are regenerated.

**Tests:**

- **New `Test/PmmlProbe.cls`** (fixture, `DependsOn = OcuPilot.Test.AnalyticsProbe`): `Create`, `Remove` and `Gone`. It uses `AnalyticsProbe.Enable` :368 and `Remove`. `Gone` means no class under `OcuPilotProbe.Pmml` and no `TempResult` row whose `ModelClass` is the probe's.
- **New test classes** (each `DependsOn` the probe):
  - `Test/AnalyticsPmmlModels.cls`: the reads at the port, over HTTP and as the two tools; journal-clean (`AnalyticsProbe` `JournalMark`/`JournalWrites`); the gate as principals.
  - `Test/AnalyticsPmmlRun.cls`: the three sources and their oracles.
  - `Test/AnalyticsPmmlRunEdge.cls`: refusals, bound, cancel, owner and busy.
  - All three are armed beside `scripts/ci-throwaway.sh` :654-656.
- **Component spec:** `pmml-model-test.page.spec.ts`.
- **Browser:** a Story 24.14 Batch 2 test in `ui/browser/analytics.browser-spec.mjs`, with `structural(page, route)` on both screens. `ui/browser/structural-walk.mjs` SKIP gains `analytics/pmml-models/test` beside :152, with the same true reason.
- **Rosters (Rule 30):** re-grep `AnalyticsFolderItemList`, `analytics/mdx-query`, `analytics.folderitems.read`, `PivotRun`, `pivot/background` and `RUNKIND`. Expect hits in:
  - `Test/{SurfaceCoverage,EndpointCoverage,ReadTool,StageTwoTools,ToolRoundTrip,Descriptor,DeveloperFloor,DeveloperFloorRoutes,SaveHoldCoverage,Navigation,PortGate,ClassicPageGate,AnalyticsDescriptor}.cls`;
  - `ui/tools/{screen-mirror,navigation,analytics}.test.mjs`.

  `analytics.test.mjs` forbids every vendor call in Never, and admits the run calls and `%DropResults` only in `PmmlRun`.

## Tasks & Acceptance

**Execution:**

- [ ] **Task 0** (`ocupilot-b-ci`, USER, the probe removed after). Record each result under Design Notes › Measured.
  - Compile the probe. If a definition naming an absent cube does not compile, point the cube source at `AnalyticsProbe`'s guarded cube and use a principal without its resource.
  - Journal-scan every read call in Always.
  - As a least-privileged principal (the pairs plus READ on USER's databases), run each source and record which globals it writes.
  - Check that `%DropResults` removes that id's rows. If it is refused, the drop is an embedded `DELETE` bound to the id.
  - HALT if a read writes anything, or if a run's rows cannot be dropped.
- [ ] `AnalyticsPort.cls`, `AnalyticsError.cls`, `PmmlTest.cls`, the `BackgroundRun` hoist, `SqlRun.cls` and the routes.
- [ ] The two descriptors, the entity type, the page, the store, the outlet, the strings (once ruled), the regenerated mirror and titles, and one EXPERIENCE.md Fixed strings row.
- [ ] Tests: the matrix in the three new classes, the component and browser tests, the walk SKIP and every roster.

**Acceptance Criteria:**

- **AC1 (round trip, reads; Integration, Rule 1).**
  - **Given** the probe,
  - **When** the person opens PMML models and a model's Test screen, and the agent calls `analytics.pmmlmodels.read` and `analytics.pmmlmodel.read`,
  - **Then** each row's fields equal what `%GetModels`, `%GetPredictedFieldInfo` and `%GetDefinition` report, and the journal holds no write by those reads.
- **AC2 (round trip, run).**
  - **Given** each probe model and each of its three sources,
  - **When** the person runs a test,
  - **Then** its records, metrics, values and rows equal those the vendor's own run computes for the same source.
- **AC3 (rows dropped).**
  - **Given** any run, whether answered, error, stopped or canceled,
  - **When** it ends,
  - **Then** `%DeepSee_PMML_Utils.TempResult` holds no row for its test id.
- **AC4 (SQL is a query).**
  - **Given** a custom or stored SQL source that is not a query, or that names OcuPilot's state,
  - **When** the person runs it,
  - **Then** it is refused before anything is spawned, with SQL query's own classification.
- **AC5 (browser).**
  - **Given** the probe,
  - **When** a person opens PMML models in USER, opens a model and runs it against its verification records,
  - **Then** the answer shows the record count and the metrics, and both screens pass `structural`.
- **AC6 (fresh, either order).**
  - **Given** any new or changed test, run first on a fresh instance in either order,
  - **When** it ends,
  - **Then** `PmmlProbe.Gone()` is true.

## Spec Change Log

- 2026-11-20, spec gate (runner): the models list and Test screen, the PmmlTest background run with its always-drop of result rows, stored SQL through SQL query's check, Batch 1's pairs, the proposed strings and the proposed AD-7/AD-65/AD-41 lines kept (veto item U-122).

## Review Triage Log

## Design Notes

**Governing ADs (Rule 6):** AD-5, AD-7, AD-8, AD-9, AD-11, AD-13, AD-16, AD-21, AD-24, AD-29, AD-36, AD-39, AD-41, AD-42, AD-44, AD-60, AD-65. There is no governance key, because the run is a read-kind run (AD-22; Batch 1 Question 5).

**Integration and linkage (Rules 1, 2).**

- **Consumes:** `AnalyticsPort` (`AdmitNamespace`, the alarm and answer helpers), `BackgroundRun`, `SqlRun`, `SqlConsole.Check`, `core/background-run.ts` and `AnalyticsProbe`.
- **Consumed-by:** Batch 3 (PMML New, Export to cube) builds on the list and the run.
- AC1 is the Integration AC.

**Ledger inbox (Rule 17):** none.

**Decided in-stage (plan).**

1. **Test is a non-tab detail sub-screen**, as `tasks/schedule/details` is, because it has one view and not a tab group. Its read is the model's one row, so its derived tool repeats the list's row and executes nothing. It is in the spirit of "the agent gets only the models read".
2. **A stored SQL data source passes the same check as custom SQL.** The precedent is Batch 1, where a stored pivot's MDX passes the same detector as typed MDX. A cube source takes AD-65's `%CubeExists` and `%CheckPrivilege` before the vendor runs. Both are stricter than the classic page (veto: stricter posture).
3. **No new numbers.** The bound is `MDXSECONDS`, the caps are `MDXMAXROWS` and the cut is `MDXMAXCELL`.
4. **No destination check.** The vendor writes IRISTEMP. Task 0's least-privileged run settles that this needs no extra pair (inference until measured).
5. **`PMMLPAIRS` follows Batch 1 Question 2's ruling for the viewer:** the portal pair, not the classic page's `%DeepSee_PortalEdit` alternative.
6. **No confirmation.** The model's generated code runs with the person's rights, as a cube build's does. A function an SQL source calls is SQL query's named limit (AD-21).
7. **The cube data source is pinned on its refusal only.** A positive cube run is the vendor's same `%RunModel` call as a dataset's (inference), and it is a named limit.

**Proposed strings (veto; none are in EXPERIENCE.md).**

- **Labels:**
  - Screens: "PMML models".
  - Fields: "Target type", "Data sources", "Verification records".
  - Answer: "Records", "Recall", "F-measure", "Micro", "Macro", "Actual value", "Predicted value", "Probability", "Correct", "Incorrect", "Sigma", "RSE", "R²", "SQL".
  - Choices: "Model verification records", "Custom data source (SQL)".
  - Reused: Class, Model, Type, Target, Test, Run, Cancel, Data source, Precision, and MDX query's run status lines where they are generic.
- **Empty states:** "No PMML models are defined in this namespace." · "This PMML model no longer exists."
- **Reasons:**
  - INPUT: "Choose one of this model's data sources; a custom data source is one SQL query."
  - ABSENT: "This PMML model no longer exists."
  - QUERYONLY: "A model is tested here only against an SQL query; this data source is not one."
  - CUBE: "This data source's cube is not one this namespace holds, or you cannot read it."
  - BUSY: "A PMML test you started is still running; cancel it or wait for it to end."
  - FULL: "As many background runs as this instance allows are running; try again when one ends."
  - NOTFOUND: "No PMML test of yours has this id; an ended run is kept for 15 minutes."
  - LOST: "The PMML test ended without an answer; run it again."
- **Prompts, list:** "Which PMML models does this namespace hold?" · "What does each model predict?" · "Which models carry verification records?"
- **Prompts, Test:** "Explain what this model predicts." · "Which data sources can I test this model against?" · "How do I read precision and recall?"
- There is no agent empty-state phrase, because neither screen has an action.

**Proposed spine lines (the owner's attended update).**

- **AD-7:** "The PMML model tester's test (Story 24.14) is the background run's third kind, a person's read-kind run. It runs the vendor's `%RunModel`, `%RunModelFromPMMLRows` or `%RunModelFromSQL` in the job, which writes the vendor's result rows and test-id counter in IRISTEMP, and it drops its own rows with `%DropResults` on every path. An SQL data source runs only once SQL query's classification types it a query. The model's generated code runs with the person's rights (named limit)."
- **AD-65:** "The PMML model reads call the vendor's finder list, `%GetModels`, `%GetModelClassName`, `%GetPredictedFieldInfo` and `%GetDefinition`, measured to write nothing. A cube data source runs only on a cube `%CubeExists` holds and `%CheckPrivilege` admits."
- **AD-41:** the kinds sentence gains the PMML tester.

## Verification

**Commands** (one `ci-runner` call per message; `ocupilot-b-ci` only):

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.AnalyticsPmmlModels`, then the same for `AnalyticsPmmlRun`, `AnalyticsPmmlRunEdge`, `AnalyticsMdxRoutes`, `AnalyticsPivotRun` (because of the hoist) and every class the roster sweep changes. Expected: green, with each new class green on its first run.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`. Expected: green.
- `(loop)` `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/analytics.browser-spec.mjs`. Expected: green.
- `(once)` The same environment for `browser/a11y-structural-invariants.browser-spec.mjs`. Expected: green.
- `(once)` The full ObjectScript sweep: `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17` for k = 1 to 17, one call each. Expected: green.
- `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh`. Expected: clean. The full browser suite is left to CI.

**Shared surfaces:** the Analytics side bar, the entity-type vocabulary, the read-tool, coverage and endpoint rosters, the route rosters (`DeveloperFloorRoutes`, `SaveHoldCoverage`), the background-run kinds, `screen-mirror.test.mjs`, the `analytics.test.mjs` guard, the arming roster and the walk's SKIP.

**Hermeticity:** every test added or changed passes on its first run on a fresh instance, in either order. Each removes the probe and the result rows it made.

**Mutations:** one per AC, recorded here by the implement stage.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

**Plan.** This is Batch 2, planned from the epic context, Batch 1's spec, the spine's binding ADs, and the vendor's `ModelTester`, `AbstractTester` (`Hidden`, read from `ocupilot-b-ci`), `Utils`, `TempResult` and `Definition`. The plan halts after planning, and nothing is implemented. The spec gate has three sets of items to rule: the proposed strings, decisions 2 and 5 (each stricter than the classic page), and the proposed spine lines.
