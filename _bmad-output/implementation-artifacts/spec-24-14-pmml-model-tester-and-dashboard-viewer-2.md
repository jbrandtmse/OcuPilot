---
title: 'Story 24.14: PMML model tester and dashboard viewer (Batch 2: the PMML model tester)'
type: 'feature'
created: '2026-11-20'
status: 'done'
baseline_revision: 'fa07e912661f1c32e64f3f8efb5fc51987fa8faa'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-14-pmml-model-tester-and-dashboard-viewer.md'
warnings: ['oversized']
deferred:
  - summary: >-
      Pressing Run while another model's PMML test is live answers BUSY and attaches that run, so its answer shows under the current model; the busy banner also stays after the attached run ends.
    evidence: |-
      BackgroundRun.start attaches the run a BUSY refusal names, a shared design MDX query uses too; PmmlModelTestPage builds a new state per model and never re-attaches (PmmlTestState.poll is unused).
    location: >-
      ui/src/app/core/background-run.ts, ui/src/app/areas/analytics/pmml-model-test.page.ts
    severity: low
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
  - The job allocates the test id with `TempResult.GetNewTestId()`. It calls `%RunModel`, `%RunModelFromPMMLRows` or `%RunModelFromSQL` with `pTracking` 0, under an alarm of `MDXSECONDS`, which stops a statement that is slow to start; a run that returns at or past the bound is answered `stopped`, its answer discarded (the vendor's model loop does not take the alarm), and Cancel ends the run's own job, the process its run row records while that process holds the run's lock, then drops that test id's rows itself (Batch 2b, spec `-4`). It reads the answer, then drops the id's rows with an embedded `DELETE` bound to the id on every path: answered, error, stopped, canceled or fault.
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

- [x] **Task 0** (`ocupilot-b-ci`, USER, the probe removed after). Record each result under Design Notes › Measured.
  - Compile the probe. If a definition naming an absent cube does not compile, point the cube source at `AnalyticsProbe`'s guarded cube and use a principal without its resource.
  - Journal-scan every read call in Always.
  - As a least-privileged principal (the pairs plus READ on USER's databases), run each source and record which globals it writes.
  - Check that `%DropResults` removes that id's rows. If it is refused, the drop is an embedded `DELETE` bound to the id.
  - HALT if a read writes anything, or if a run's rows cannot be dropped.
- [x] `AnalyticsPort.cls`, `AnalyticsError.cls`, `PmmlTest.cls`, the `BackgroundRun` hoist, `SqlRun.cls` and the routes.
- [x] The two descriptors, the entity type, the page, the store, the outlet, the strings (once ruled), the regenerated mirror and titles, and one EXPERIENCE.md Fixed strings row.
- [x] Tests: the matrix in the three new classes, the component and browser tests, the walk SKIP and every roster.

- [x] [CI] `AnalyticsPmmlRunEdge.TestACancelEndsARunAndLeavesNoRow` failed on CI run 44736623307 (instance shard 3/8, head fa07e9126) and passed in run 44729361774: "the run ends canceled", "and not when the join would end: 70.069863 seconds", "the run allocated its id, and the rows it wrote are gone". The cancel did not land on CI's runner, so the run ran to its end. Find why (candidates: the retry budget too short for a slower host; the interrupt sent before the statement is inside the SQL engine; the test firing cancel before the run has really started) and make the cancel deterministic, or make the test wait on an observable started state (e.g. the job inside its statement) rather than on time. Prove it with at least 5 consecutive runs of the class on a rebuilt throwaway and record each run's timings. If the vendor cannot cancel reliably, stop and report before changing the ruled behavior (U-123). Touch only Batch 2's files.
  - Closed (rework 1): the vendor's loop is inside the SQL engine, the only place an interrupt is accepted, for about 2% of a run over a fast cross join, so the cancel landed by chance (53 sends locally, none in 10 s on CI); the test now runs a statement the job spends all its time inside (`SLOWSCAN`) and sends the cancel once `INFORMATION_SCHEMA.CURRENT_STATEMENTS` lists the job, and 5 consecutive runs of the class on a rebuilt throwaway were green with the cancel test at 234-240 ms (794 ms on the first).

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

- 2026-11-20, Batch 2b plan (orchestrator ruling on U-123): Boundaries' "Cancel interrupts a run in progress" replaced, since a cancel reached the job only while it was inside the SQL engine (about 2% of a fast join, measured); the Cancel now ends the run's own job and drops its rows (spec `-4`, Design Notes › Measured).

- 2026-11-20, CI: re-opened for rework iteration 1 (one [CI] item: the cancel test did not land on CI's runner).

- 2026-11-20, implement intent gap ruled (runner, veto item U-123): Decided in-stage 3-5 accepted. Original: "under an alarm of `MDXSECONDS`" and "drops the id's rows" (with `%DropResults`). Amended: the alarm stops a slow start; a run past the bound is answered `stopped` and discarded when the vendor returns; Cancel interrupts; the drop is an embedded `DELETE` bound to the test id; the proposed AD-7 line reads the same.

- 2026-11-20, spec gate (runner): the models list and Test screen, the PmmlTest background run with its always-drop of result rows, stored SQL through SQL query's check, Batch 1's pairs, the proposed strings and the proposed AD-7/AD-65/AD-41 lines kept (veto item U-122).

## Review Triage Log

### 2026-11-20 — Review pass

- verdicts: 45 findings — high 0, medium 7, low 30, false 8, maybe-false 0
- findings:
  - verification-gap (11)
    - `[medium]` `[patch]` seven of the eight PMML refusal codes reach no test -- one table-driven component case now reads all eight (mutation: map CUBE to the busy sentence, red).
    - `[medium]` `[patch]` the `stopped` status line is never rendered -- a component case reads one second and two seconds (mutation: swap the singular and plural sentences, red).
    - `[low]` `[reject]` `FULL` and `LOST` run codes and the BUSY/NOTFOUND reasons are not compared -- the I/O matrix lists codes only and MDX's own classes pin the shared base; a test addition is not a correction.
    - `[medium]` `[patch]` the bound clause of `PmmlRun` has no mutation line -- the elapsed-time clause is named in `TestARunPastItsBoundIsStoppedAndLeavesNoRow`'s header and its mutation is run below.
    - `[low]` `[reject]` gate-before-lookup ordering is not pinned by an absent model with an unpaired caller -- `PmmlResolve` calls `PmmlAdmit` first (read at AnalyticsPort.cls:2575) and the legs refuse 403 and 409 before any lookup; the lookup writes nothing.
    - `[low]` `[reject]` the job's repeat of the start's checks is untested -- a TOCTOU defense the spec requires, not a matrix row; the fix is a new fixture.
    - `[low]` `[reject]` the `probability` number branch is never compared -- the probe's models store none; it needs a fixture model that does.
    - `[low]` `[reject]` the browser test asserts its create before the `try/finally` -- a failed create leaves classes the next `Create` or `Remove` clears.
    - `[low]` `[reject]` `AwaitRows` times out silently -- the later `canceled` and 60-second assertions fail loudly.
    - `[low]` `[reject]` the busy test's closing cancel is unchecked -- `Settle()` in `OnAfterOneTest` cancels and waits.
    - `[low]` `[reject]` `AnalyticsError.PmmlCodes()` has no caller -- `FolderItemCodes()` and `ListingGroupCodes()` are the same precedent.
  - intent-alignment (9)
    - `[low]` `[reject]` the alarm half (a statement slow to start) has no test -- the alarm is `Alarmed`, existing code the amendment keeps; only the after-the-fact path is pinned.
    - `[low]` `[patch]` `%DropResults` is named in `PmmlDrop`'s comment, against "named nowhere" -- the comment now says "the vendor's own drop method".
    - `[low]` `[reject]` the fault path of the drop has no test -- `PmmlVendor` catches vendor exceptions into a status, so only `PmmlAnswer` can reach it.
    - `[low]` `[reject]` the cancel test re-posts at retry 3 -- the retry loop is the documented mechanism (Decided in-stage 4).
    - `[false]` `[reject]` the oracle's own arithmetic is not the vendor's -- the production metrics call `GetAggregatePrecisionMetrics`, and the per-value and continuous SQL equal `AbstractTester` lines 264 and 493-494 (read from `ocupilot-b-ci`).
    - `[low]` `[reject]` the answer carries a `MDXMAXANSWER` character cap and ordinal takes the categorical branch -- both are bounds the intent's caps imply; `truncated` says so.
    - `[low]` `[reject]` a declared non-SQL, non-cube data source is refused 400 -- the vendor's `%RunModel` supports no other kind the probe can declare; the probe holds only SQL and cube.
    - `[false]` `[reject]` the cube check runs before the SQL check -- the two apply to different sources, so no input meets both.
    - `[false]` `[reject]` the `BackgroundRun` hoist is outside the batch -- the Code Map names it (Rule 2).
  - edge-case (10)
    - `[low]` `[defer]` a live run of model A attaches under model B through the BUSY refusal -- `BackgroundRun`'s attach-on-busy is the shared pre-existing design; the busy banner is on screen.
    - `[low]` `[reject]` the row going empty during a poll discards the run handle -- needs a namespace change mid-run; the run ends on its own.
    - `[low]` `[defer]` the busy banner stays after an attached run ends -- the same shared attach path as MDX query.
    - `[medium]` `[patch]` `CancelJob` can hold the request for minutes when no statement ever runs (verification source) -- bounded by `CANCELBUDGET` 10 seconds.
    - `[low]` `[reject]` a class name in another case passes the lookup and fails in the run -- the run then answers a vendor error; no wrong data.
    - `[low]` `[reject]` a cursor left open when `PmmlAnswer` throws -- the job's process ends after the run.
    - `[low]` `[reject]` `SQLCODE` is not checked after `COUNT` and `OPEN` -- a read of IRISTEMP rows the run just wrote; the window is a cancel landing mid-read.
    - `[medium]` `[patch]` the drop's `DELETE` is not retried when a statement fails -- `PmmlDrop` sends it again up to five times.
    - `[false]` `[reject]` the SQL checked is not the SQL the dataset runs -- Task 0 measured that `%CreateDataset` of a declared SQL source answers a dataset whose `SQL` is the extension's own text.
    - `[false]` `[reject]` an oversized model value is unbounded before `PmmlParts` -- `PmmlParts` caps the model at `MDXMAXCELL`, `Body` caps the others, and the request size is the transport's.
  - adversarial (15)
    - `[medium]` `[patch]` a cancel can land on the drop's `DELETE` and leave rows -- same fix as the retry above.
    - `[medium]` `[patch]` the cancel request can block for minutes -- same fix as `CANCELBUDGET`.
    - `[low]` `[reject]` an error while reading the answer reads as a normal result -- same as the unchecked `SQLCODE` row above.
    - `[false]` `[reject]` a NULL prediction counts as neither correct nor incorrect -- `AbstractTester` line 264 counts the same way, and the intent's oracle is the vendor's.
    - `[false]` `[reject]` the RSE divides by zero for equal actual values -- `AbstractTester` lines 493-494 are the same statement.
    - `[low]` `[reject]` the prepare-error answer carries `kind` and `sqlcode` and an uncut message -- it is SQL query's own `ErrorOutcome`, and the client reads `outcome` and `message` only.
    - `[low]` `[defer]` leaving mid-run then returning offers no re-attach and `PmmlTestState.poll` is unused -- Run answers BUSY and attaches the live run (shared path).
    - `[false]` `[reject]` the `PmmlRun` comment promises a rethrown fault -- `PmmlAnswer` and the stop hook can still throw, and the drop precedes the rethrow.
    - `[low]` `[patch]` `%DropResults` is named in a comment -- reworded (same row as above).
    - `[low]` `[reject]` comments narrate "measured" results and mutation recipes -- house style in the existing port comments, and the spec asks for the mutation lines.
    - `[low]` `[reject]` `Reply`, `CodeFor` and `PmmlAdmit` copy their MDX siblings -- the siblings already copy each other; a shared base would couple the kinds (Code Map).
    - `[low]` `[reject]` the "source rows unchanged" half of the footprint cannot fail -- the run-row and counter halves still catch an executed statement.
    - `[low]` `[reject]` probability and NULL paths are untested -- same as the verification-gap rows above.
    - `[low]` `[reject]` the fault path has no drop test -- same as the intent-alignment row above.
    - `[low]` `[patch]` British spelling `Colour` in the probe, three test classes, the browser and component specs -- renamed `Color` throughout.

### 2026-11-20 — Follow-up review

- scope: the review patches in `344608ed6` and QA's uncommitted tests and fixtures; four layers on Opus.
- verdicts: 28 findings after grouping — high 0, medium 2, low 24, false 2; patch 15, defer 0, reject 13, intent_gap 0.
- findings:
  - `[medium]` `[patch]` no test lands a cancel on the drop's `DELETE` -- measured on `ocupilot-b-ci`: a cancel landing there is accepted and the statement answers `SQLCODE` -456, so the retry sees it; `TestADropACancelInterruptsIsSentAgain` pins it.
  - `[medium]` `[patch]` the idle cancel test cancels once the row reads `running`, before the job's work begins -- `PmmlTestIdle` sets an `entered` node and the test waits for it.
  - `[false]` `[reject]` an interrupted `DELETE` throws past `PmmlRun`'s `Try` -- the same measurement: it answers `SQLCODE`, not an exception.
  - `[false]` `[reject]` the budget is tested only on a fixture with no rows -- a run whose cancel gave up takes the stop-after-the-vendor path, pinned by the "canceled once the vendor returned" leg.
  - `[low]` `[patch]` a cancel request can run one send's `CANCELSECONDS` past `CANCELBUDGET` -- `CancelJob`'s comment states that ceiling.
  - `[low]` `[patch]` the two retry comments say "again up to N" for N sends in all, and `PmmlDrop`'s omits that each try waits out the lock timeout -- reworded.
  - `[low]` `[patch]` the drop test has no upper bound, so a drop that spins passes -- it asserts under eight seconds.
  - `[low]` `[patch]` `PmmlDrop` hangs after its last failed try -- no hang after the fifth; retrying only lock codes is rejected, since a cancel answers -456.
  - `[low]` `[patch]` the idle test does not check the reservation's key -- asserted.
  - `[low]` `[patch]` `Seed` ignores the vendor's status -- answers `""` on an error.
  - `[low]` `[patch]` the drop test's cleanup sleeps instead of waiting for its job -- waits for `done`.
  - `[low]` `[patch]` "neither a model nor its absence is told" is unchecked -- an absent model's legs read the same 403.
  - `[low]` `[patch]` `PmmlTest`'s seam list omits `Work` and the `CANCEL*` parameters, and the port's omits `PmmlAnswer` -- added.
  - `[low]` `[patch]` the `maxRows` mutation names `BoundedMaxRows` in the header and `Read.View` here -- the header names `View`.
  - `[low]` `[patch]` the "Not run" line still lists the cancel's retries -- the mutation is run and recorded.
  - `[low]` `[patch]` a story tag in `mdx-query.store.ts`'s comment and measurement narration in `CancelJob`'s (Rule 14) -- removed.
  - `[low]` `[patch]` the Auto Run Result calls the budget and the retry untested -- corrected.
  - `[low]` `[reject]` the idle job is not released when the test raises -- no step raises; the job ends itself after 60 seconds.
  - `[low]` `[reject]` a cancel with no statement id can interrupt the job's own store SQL -- a window of milliseconds after the vendor returns; a `DELETE` it meets is retried; the fix needs a cross-process signal.
  - `[low]` `[reject]` "dropped on every path" against a drop that gives up -- the drop runs on every path; only a process holding that test's own rows can stop it, and it is logged once.
  - `[low]` `[reject]` production's `CANCELBUDGET` and `CANCELTRIES` are not run -- the loop is pinned; the values are constants.
  - `[low]` `[reject]` the routines-database branch of `AdmitNamespace` is unpinned in USER -- existing code outside this batch.
  - `[low]` `[reject]` Cancel does not interrupt a run that never enters a statement -- the amended Intent and Decided in-stage 4 record it; the run ends `canceled` when the vendor returns.
  - `[low]` `[reject]` `CancelJob` copies `SqlBackground`'s (Rule 2) -- the reason is Decided in-stage 4; sharing it edits the SQL console's class; reopen if a third retrying cancel appears.
  - `[low]` `[reject]` the matrix gives `QUERYONLY` where session and privilege statements get SQL query's codes -- the fix edits the frozen matrix; AC4 holds.
  - `[low]` `[reject]` the "no table or view" check races under its mutation -- the 422 and footprint legs pin it.
  - `[low]` `[reject]` AC4's 403 half and AC1's journal half carry no `mutation:` line -- one per AC, which both have.

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

- **AD-7:** "The PMML model tester's test (Story 24.14) is the background run's third kind, a person's read-kind run. It runs the vendor's `%RunModel`, `%RunModelFromPMMLRows` or `%RunModelFromSQL` in the job, which writes the vendor's result rows and test-id counter in IRISTEMP, and it drops its own rows with an embedded `DELETE` bound to its test id on every path. An SQL data source runs only once SQL query's classification types it a query. The model's generated code runs with the person's rights (named limit)."
- **AD-65:** "The PMML model reads call the vendor's finder list, `%GetModels`, `%GetModelClassName`, `%GetPredictedFieldInfo` and `%GetDefinition`, measured to write nothing. A cube data source runs only on a cube `%CubeExists` holds and `%CheckPrivilege` admits."
- **AD-41:** the kinds sentence gains the PMML tester.

**Measured (Task 0, implement, 2026-11-20, `ocupilot-b-ci`, USER; the probe and the throwaway principal removed after).**

- **A definition naming an absent cube does not compile** (`Cannot find Subject Area`), so the probe's cube data source names `AnalyticsProbe`'s guarded cube, and the cube refusal is a principal without `%DeepSee_Admin`.
- **The reads write nothing.** A journal scan of the finder list, `%GetModels`, `%GetModelClassName`, the model class's `%GetPredictedFieldInfo` and `%GetDefinition` and the definition's `%GetDefinition` found no set or kill by this process or by any process; the journal does not see IRISTEMP, so the vendor's `^IRIS.Temp.DeepSee.PMML.ResultD`, `ResultI`, `ResultS` and `BgrTask` nodes were counted before and after and did not change. `%CreateDataset` of a declared SQL source answers a dataset whose `SQL` is the extension's own text.
- **A run writes IRISTEMP, and the SQL engine's statement index.** Each of the three sources, for the categorical and the continuous model, wrote the vendor's result rows and advanced its test-id counter (`ResultI("TestIdx")`), and in USER's journaled database only the statement index (`rINDEXSQL`) and the SQL statistics of the prepares.
- **A least-privileged principal** (`%DB_USER:R`, `%DeepSee_Portal:U`, `%Development:U`) ran the verification source and wrote its rows; its SQL sources were refused -99 for lack of SELECT on the source table, which is the person's own SQL privilege. `%DropResults` is refused it as well (-99, its dynamic `DELETE` needs the privilege on the shared table), and an embedded `DELETE` bound to the test id, compiled in a class, ran as that principal and removed every row. So the drop is the spec's fallback, an embedded `DELETE`. The two counter nodes stay after a drop.
- **The alarm does not stop the vendor's loop (contradicts the plan).** A 5-way cross join of 12 rows (248,832 records) ran 8.9 s to its end under `$System.Alarm.Set(2)` with the vendor's status OK and every row written; an alarm set in a plain loop, or after one `%Save`, fires on time, so the vendor's own per-record work does not let it through (inference: not located). A statement's own `CancelQuery` is accepted only while the job is inside the SQL engine: one call with no wait answered "interrupt cannot be issued" and the run went to its end.
- **SQL query's self-protection refuses any statement whose text holds `ocupilot`**, so the probe's source table is `ProbePmml.Source`, outside the `OcuPilot` name.

**Decided in-stage (implement).**

1. **`TargetType` is the predicted field's operational type** (`categorical`, `ordinal` or `continuous`), which is the classic page's `mode`.
2. **A continuous model's `values` is empty**, since a per-actual-value count has no meaning there; a categorical model's groups by `%EXACT(ActualValue)`, so the value reads as the record holds it.
3. **The bound is enforced after the fact where the alarm cannot reach**: `PmmlRun` classifies a run that returns at or past the bound as `stopped` (seconds = the bound), discards its answer and drops its rows; the alarm still stops a start that is slow before its first row. **Recommended amendment to the spec and to the proposed AD-7 line:** the bound stops a statement that is slow to start; a run that outlasts it is answered `stopped` and discarded when the vendor returns, and Cancel is what interrupts it.
4. **`PmmlTest.CancelJob` is `SqlBackground`'s retrying form**, not `MdxQuery`'s one-line copy (measured above): the cancel is given three seconds to meet the job and is sent up to 100 times, 0.1 s apart, for no more than ten seconds in all (`CANCELBUDGET`), so one cancel request blocks up to ten seconds. It is copied, not shared, because a shared base would couple the SQL console and this run.
5. **The drop is an embedded `DELETE`** (`PmmlDrop`), not `%DropResults`, and `analytics.test.mjs` pins that `%DropResults` is named nowhere in the port or the run class. The proposed AD-7 line's "with `%DropResults`" should read "with an embedded `DELETE` bound to its test id".
6. **`BackgroundRun` gains `StopRequested` and `RenderPortFault`**, hoisted from `MdxQuery` (whose `MdxStopRequested` hook now calls the first); the model id is parsed in `Invoke`, where `OcuPilot.*` classes are visible, and handed to `Collect` as `Class||Model` (AD-16).
7. **The probe holds two more SQL data sources** (`Changes`, a statement that changes rows, and `Self`, a query over OcuPilot's state) and a third model without verification records, to pin the stored-SQL refusals and the missing-verification refusal.

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

**Mutations:** each applied to `ocupilot-b-ci`'s copy (synced, loaded with the port's and the run's subclasses recompiled; the client one with the bundle rebuilt and copied in), observed red, reverted (`shasum` of `PmmlTest.cls` and `pmml-test.store.ts` equal before and after; the port's compared by `diff -rq` of the tree and the copy, empty) and reloaded.

- mutation: AC1 `AnalyticsPort.PmmlClassRowsHere` reads `Target` from the model's `Type` -> `TestTheListAndTheTestRowAreWhatTheVendorHolds` red alone, on the port, screen and tool legs (`AnalyticsPmmlModels`).
- mutation: AC2 `AnalyticsPort.PmmlAnswer` reads each row's `predicted` from the actual value -> `TestEachModelRunsEachSourceToTheVendorsOwnAnswer` red on all seven runs (`AnalyticsPmmlRun`).
- mutation: AC3 `AnalyticsPort.PmmlRun` skips `PmmlDrop` -> the same test red on the rows left for every run, the verification, dataset and custom runs of both models (`AnalyticsPmmlRun`).
- mutation: AC4 `PmmlTest.Check` skips its kind test -> `TestASourceThatIsNotAQueryIsRefusedBeforeAnythingRuns` red alone, on both 422 legs and on what the refusal must leave unchanged (`AnalyticsPmmlRunEdge`).
- mutation: AC5 `pmml-test.store.ts` sends the model's name `Colors` in place of its composite id for the verification source (bundle rebuilt and redeployed) -> the Batch 2 browser test red (`analytics.browser-spec.mjs`, 1 of 2 with `--test-name-pattern`), and the Test page spec's verification case red.
- mutation: AC6 `AnalyticsPmmlRun.OnAfterAllTests` skips the probe's `PmmlProbe.Remove` (the throwaway's copy, loaded) -> the class ends red at class level, "left probe state in USER: classes:12", and the class reads green again once reverted and reloaded (`AnalyticsPmmlRun`).
- mutation: bound `AnalyticsPort.PmmlRun` drops the elapsed-time clause of its bound test (the throwaway's copy, loaded) -> `TestARunPastItsBoundIsStoppedAndLeavesNoRow` red alone, the run answering `ran` over 248,832 records (`AnalyticsPmmlRunEdge`); the port was reverted, the tree and the copy compared equal by `diff -rq`, and reloaded.
- mutation: refusal map `mdx-query.store.ts` maps `ANALYTICS.PMML.CUBE` to the busy sentence -> `reads each of the eight PMML refusal codes as its own sentence` red; and `pmml-test.store.ts` swaps the singular and plural stopped sentences -> `reads a run stopped at its bound as its status line` red (the Test page spec).
- Not run against a mutation: the gate (`PMMLPAIRS`), pinned by `TestTheGateRefusesBeforeAnyLookup`, whose `Mutation (Rule 19)` line names its change in the test's header.
- mutation: cancel retries `PmmlTest.CancelJob` sends its cancel once -> `TestACancelEndsARunAndLeavesNoRow` red (the run not canceled, 60.2 seconds) and `TestACancelThatMeetsNoStatementIsBoundedByItsBudget` red (0.11 seconds), with two later tests of the class red behind the live run (`AnalyticsPmmlRunEdge`, run 862); reverted, the class green again (run 863).
- mutation: cancel budget `PmmlTest.CancelJob` drops the budget clause from its loop (the throwaway's copy; `PmmlTestIdle` and `PmmlTestQuick` recompiled) -> `TestACancelThatMeetsNoStatementIsBoundedByItsBudget` red alone, the cancel taking 6.25 seconds against the fixture's two (`AnalyticsPmmlRunEdge`).
- mutation: non-query kinds `PmmlTest.Check` skips its kind test -> `TestAnSqlStatementOfAnyOtherKindIsRefusedBeforeAnythingRuns` red on the table, view, insert and delete legs and on the table made and the footprint, its session, privilege and second-statement legs green, and `TestASourceThatIsNotAQueryIsRefusedBeforeAnythingRuns` red beside it (`AnalyticsPmmlRunEdge`).
- mutation: drop retry `AnalyticsPort.PmmlDrop` sends its `DELETE` once (the port and its seam subclasses recompiled) -> `TestADropThatMeetsALockIsSentAgainAndGivenUp` red on both holds, the drop taking 1.2 seconds and the shorter hold leaving its rows (`AnalyticsPmmlRun`); the leftover rows reddened three other tests of the class until its `Settle` dropped them, which it now does.
- mutation: drop under cancel `AnalyticsPort.PmmlDrop` sends its `DELETE` again only after a lock timeout (`SQLCODE` -110) -> `TestADropACancelInterruptsIsSentAgain` red alone on the rows left and the failure logged, the five other tests green (`AnalyticsPmmlRun`, runs 858-859).
- mutation: drop cap `AnalyticsPort.PmmlDrop` tries 50 times, not five -> `TestADropThatMeetsALockIsSentAgainAndGivenUp` red alone, the drop taking 30.05 seconds against the bound of eight (`AnalyticsPmmlRun`, run 860). Each follow-up mutation was applied to the throwaway's copy, the port's subclasses recompiled, then reverted by copying the tree's file back; `diff -rq` of the tree and the copy is empty.
- mutation: neighbors `AnalyticsPort.PmmlDrop` reads `TestId >= :pTestId`, then `TestId <= :pTestId` -> `TestOtherTestsRowsSurviveEveryEnding` red alone on the other tests' rows in all five endings, each time (`AnalyticsPmmlRun`).
- mutation: fault ending `AnalyticsPort.PmmlRun` skips the drop when it caught an exception -> `TestOtherTestsRowsSurviveEveryEnding` red alone, on the faulted leg's own rows (`AnalyticsPmmlRun`).
- mutation: database read `AnalyticsPort.AdmitNamespace` skips its globals-database read test -> `TestACallerWhoCannotReadTheDatabaseSeesNoModel` red alone, on both reads and the resolution (`AnalyticsPmmlModels`).
- mutation: tool caps `Read.View` drops the context cap's cut, then ignores the `maxRows` argument (the throwaway's copy, `Read`'s subclasses recompiled) -> `TestTheListIsCutAtTheToolsCapAndSaysSo` red alone on the context-cap leg, then on the `maxRows` leg (`AnalyticsPmmlModels`). Each mutation was applied to the throwaway's copy only, reverted by copying the tree's file back and reloaded; `diff -rq` of the tree and the copy is empty.
- mutation: cancel landing (rework 1) `PmmlTest.CancelJob` never sends its `CancelQuery` (the throwaway's copy; `PmmlTestIdle` and `PmmlTestQuick` recompiled) -> `TestACancelEndsARunAndLeavesNoRow` red on the status (not `canceled`) and the time (40.05 seconds), with the idle and busy tests red behind the live run (`AnalyticsPmmlRunEdge`, run 11); reverted by copying the tree's file back, `diff -rq` of the tree and the copy empty, recompiled, `git status --short` and `git diff --stat` unchanged, and the class green again (run 12, cancel test 243 ms).

- mutation: cancel drop (rework 1) `PmmlRun` skips its `PmmlDrop(tId)` (the throwaway's copy; `PmmlRunSeam` recompiled) -> `TestACancelEndsARunAndLeavesNoRow` red on its rows-gone leg, with `TestARunPastItsBoundIsStoppedAndLeavesNoRow` red beside it (`AnalyticsPmmlRunEdge`, run 14); reverted by copying the tree's file back, `diff -rq` of the tree and the copy empty, recompiled.

**Rework 1 timings** (source: `^UnitTest.Result`, each method's duration read as seconds and shown in milliseconds; the runner prints none). Before the fix, one run on the old test: cancel 17,481.7, busy 10,206.1. After, on `ocupilot-b-ci` rebuilt from this tree, `AnalyticsPmmlRunEdge` (8 tests, 0 failed each time; run 1 is the first run on the rebuilt instance; `AnalyticsPmmlRun`, 6 tests, run 2 and `AnalyticsPmmlModels`, 6 tests, run 3 each green on their first run):

| Test | run 1 | run 4 | run 5 | run 6 | run 7 |
|---|---|---|---|---|---|
| ACancelEndsARunAndLeavesNoRow | 794.3 | 239.6 | 238.1 | 240.3 | 234.3 |
| ACancelThatMeetsNoStatementIsBoundedByItsBudget | 2,299.2 | 2,252.6 | 2,242.5 | 2,248.0 | 2,259.9 |
| ARunPastItsBoundIsStoppedAndLeavesNoRow | 10,428.0 | 10,236.4 | 10,222.8 | 10,290.8 | 10,240.8 |
| ASourceThatIsNotAQueryIsRefusedBeforeAnythingRuns | 524.6 | 439.2 | 434.2 | 449.2 | 442.6 |
| AnAbsentOrUndeclaredSourceIsRefusedBeforeTheVendorRuns | 403.8 | 396.9 | 397.1 | 395.8 | 396.4 |
| AnSqlStatementOfAnyOtherKindIsRefusedBeforeAnythingRuns | 622.3 | 594.4 | 590.1 | 592.2 | 597.4 |
| AnotherUsersPollIsNotFoundAndASecondStartIsBusy | 195.0 | 189.8 | 191.0 | 193.3 | 188.3 |
| AnyOtherShapeAndAnUnpairedCallerAreRefused | 94.2 | 105.8 | 77.1 | 102.4 | 109.0 |

`check-objectscript` and `lint-docs` clean.

## Auto Run Result

Status: done

**Rework 1 (the [CI] cancel flake).** Root cause: the vendor's model loop is inside the SQL engine, the only place `CancelQuery` is accepted, for about 2% of the time over a fast cross join (measured: 307 of 19,770 polls of `INFORMATION_SCHEMA.CURRENT_STATEMENTS`; 4 of 200 sends accepted), so the cancel landed by chance, after 53 sends locally and not at all in `CANCELBUDGET` on CI. Fix, in `AnalyticsPmmlRunEdge` only: the cancel and busy tests run `SLOWSCAN`, a nine-way self join the job spends all its time inside, and wait on `AwaitInStatement` (the job listed in `CURRENT_STATEMENTS`), the cancel test also on `AwaitRows` (a row to drop); the retry loop is gone and the time bound is 25 seconds. Verified by 5 consecutive green runs on the rebuilt throwaway, `AnalyticsPmmlRun` and `AnalyticsPmmlModels` green on their first run, and the two mutation lines (timings and mutations under Verification). One verification-gap layer ran; its row-written precondition finding was patched (`AwaitRows` restored, the drop mutation recorded); its other points (the `CURRENT_STATEMENTS` signal is per process, and no mutation removes the wait) are accepted: the wait is what makes the first send land. Residual: a cancel of a run over a fast statement is still probabilistic in production (about 2% per send, up to 100 sends in `CANCELBUDGET`); `CancelJob` is unchanged, as ruled.

**Change.** The PMML models list and its Test screen, the third background-run kind (`PmmlTest`, three routes) and the agent's two derived reads, built to the amended Intent (the alarm stops a slow start; a run past the bound is `stopped` and discarded; Cancel interrupts; the drop is an embedded `DELETE` bound to the test id; `%DropResults` is named in no product code or comment). The Design Notes hold Task 0's measurements and the decisions. The batch's new files are the two descriptors, `PmmlTest`, `PmmlProbe`, `PmmlTestQuick` (the two-second-bound fixture), the three test classes, the store, the page and its component spec.

**Review pass (one).** Four layers (verification gaps, intent alignment, edge cases, adversarial) reported 45 findings; the Review Triage Log holds every row. Patched, 10 rows in 6 fixes: `CancelJob` is bounded to ten seconds in all (`CANCELBUDGET`); `PmmlDrop` sends its `DELETE` again up to five times and its comment no longer names the vendor's drop method; the component spec reads all eight PMML refusal codes and the `stopped` status line; the bound's mutation is run; `Colour` is `Color` throughout the probe, tests and specs. Deferred, 1 entry covering 3 rows (the shared attach-on-busy behavior). Rejected, 24 low and 8 false, each with its reason in the log. Follow-up review recommended: the cancel budget and the drop's retry, on top of five patched medium entries; it ran, under Review Triage Log › Follow-up review.

**Verification.** On a throwaway rebuilt fresh (`down`, `up`, readiness installed): `AnalyticsPmmlModels` (4), `AnalyticsPmmlRun` (3) and `AnalyticsPmmlRunEdge` (6) green on their first run, then again in reverse order (run ids 1-6); the full ObjectScript sweep in 17 shards, 6,299 tests in 828 classes, with one failure in shard 16, `InteropItemRun.TestEachRefusalIsMadeByNameBeforeAnyVendorCall` ("the probe production's operation holds no job after the start", an interop start-timing failure in a class this batch does not touch), green on its single re-run. Mutations: the bound clause (`TestARunPastItsBoundIsStoppedAndLeavesNoRow` red alone), the AC6 cleanup (class red, then green again once reverted), and the two component mutations; each reverted and the tree equal to the copy. `analytics.browser-spec.mjs` 18 of 18 and `a11y-structural-invariants.browser-spec.mjs` 13 of 13 on the rebuilt, redeployed bundle; `test:tools` 2343 of 2343; component suite 3,689 of 3,689 (308 files); `npm run build` clean; `check-objectscript` and `lint-docs` clean. The proposed strings stay the owner's veto items; the literal drift bound in `strings.test.mjs` held.

**Residual risks.** The deferred attach-on-busy entry; the cancel budget is pinned through `PmmlTestIdle`'s two-second budget, not production's ten, and the drop's retry through a held row lock and a cancel landing on the `DELETE`; the continuous-model formulas equal `AbstractTester` lines 493-494 by reading, not by a vendor-run comparison of a continuous model beyond the probe's.
