---
title: 'Story 24.14: PMML model tester and dashboard viewer (Batch 4: Export a PMML test''s results to a cube)'
type: 'feature'
created: '2026-11-20'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-14-pmml-model-tester-and-dashboard-viewer-3.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-14-pmml-model-tester-and-dashboard-viewer-2.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The classic tester's last write, **Export test results to cube**, has no OcuPilot counterpart. Under U-120 and U-125 it is Batch 4 of this story. The classic (`%DeepSee.PMML.UI.AbstractTester.ExportToCubeDefinition`, Design Notes › Vendor) does four things:

- it saves and compiles a `%Persistent` result class;
- it copies the last test's rows into that class;
- it saves and compiles a `%DeepSee.CubeDefinition` class whose cube reads that class, restricted to that test id;
- it then offers a build in a separate dialog.

**Approach:** Export to cube becomes a confirmed write with two callers: the Test screen's **Export to cube** action, and the agent's `analytics.pmmlmodel.export`. Both reach the write through `AnalyticsPort`. The write runs its own test inside the confirm or action request, through `PmmlRun`. `PmmlRun` copies the test id's rows into the new result class before its drop, so Batch 2's drop on every ending holds. The write saves both classes through Batch 3's class-write path and puts back everything it saved when a later step fails. It never builds the cube. Data only, Overwrite classes and the iKnow measure are left out, each with an exclusion-register row (U-125).

## Boundaries & Constraints

**Always:**

- **The input.** The input names a model `[Class, Model]` and the test's source, exactly as Batch 2's start body takes them (`source`, plus `dataSource` or `sql`). It also names `ResultClass`, `CubeClass` and `Cube`, and optionally `SourceClass`. The dialog's defaults are the classic's: `<Class>.<Model>.Result`, `<Class>.<Model>.ResultCube` and `ModelTestResults`.
- **Refusals, before anything is saved, in this order:**
  1. The gate: `AdmitNamespace`, then `AdmitClassWrite` with `PMMLPAIRS`, `^oddDEF` and `ANALYTICS.PMML.READONLY`, then WRITE on the database `^DeepSee.Fact` maps to, refused with the cube manager's `ANALYTICS.CUBE.READONLY` when read-only.
  2. Batch 2's model and source resolution and its query-only SQL check (`PmmlTest.Check`'s two calls).
  3. An OcuPilot class in any of the three class names: 403 `PROHIBITED.OCUPILOTCODE`.
  4. A malformed name (`ListingClassShaped`): 422 `ANALYTICS.PMML.CLASS`.
  5. Two classes that are equal or where one is in the other's package, compared without case: 422 `ANALYTICS.PMML.SAME`.
  6. A held class or package (Batch 3's free-name rule): 409 `ANALYTICS.PMML.TAKEN`.
  7. A cube name `%DeepSee.Utils.%CubeExists` holds: 409 `ANALYTICS.PMML.CUBETAKEN`.
  8. A cube name outside 1 to 250 characters (the vendor's `entityName` `MAXLEN`), or one with a control character or a `}`: 422 `ANALYTICS.PMML.CUBENAME`.
  9. A `SourceClass` the namespace does not hold: 422 `ANALYTICS.PMML.SOURCECLASS`.
- **The write (`PerformPmmlExport`), in order:**
  1. Save and compile `<R>`, the vendor's shape composed as text: `ActualValue`, `PredictedValue`, `TestRecordId` (`%String`), `Probability` (`%Numeric`), `TestId` (`%Integer`), and, with a `SourceClass`, the calculated `Record` (`SqlComputeCode` `set {Record} = {TestRecordId}`).
  2. Run the test: `PmmlRun` with no stop class, under its existing bound (`MDXSECONDS`), with a new optional copy target `<R>`. On `ran`, before the drop, it copies the id's rows into `<R>` through the object layer. It reads the rows with embedded SQL bound to the id, and composes no SQL (AD-21).
  3. Save and compile `<K>`, whose `XData Cube` OcuPilot composes in the vendor's shape (Task 0): `name`, `sourceClass` `<R>`, `buildRestriction` `TestId = <id>`, and the dimensions `ActualValueD` and `PredictedValueD`.
- **When a step fails, nothing remains.** A test that does not answer `ran` gives 422 `ANALYTICS.PMML.EXPORTRUN`. A compile the instance refuses, or a copy that fails, gives 422 `ANALYTICS.PMML.EXPORTCOMPILE`. In each case every class saved is deleted, with `<R>`'s rows, and the test's rows are dropped. Vendor text is logged, never shown.
- **Answer and read-back.**
  - The answer is `{ResultClass, CubeClass, Cube, Records}`, never the per-value table or the rows.
  - The read type `PMMLEXPORT` answers the model's row together with the three names. Each name is the held name, or `""` when it is free.
    - The mint's fresh read and a screen action carry the action: they answer 409 for a held class or cube.
    - The confirm's re-read and the read-back answer the row.
  - `READBACKFIELDS` is `ResultClass,CubeClass,Cube`.
- **Audit and governance (AD-15, AD-22).**
  - One OcuPilot `ConfigChange` row per write that reached a class. It holds `{namespace, model, resultClass, cubeClass, cube, records, outcome}`, and never the SQL.
  - An agent write emits its marker.
  - The baseline gains `analytics.pmmlmodel.export` in its ruled state (Design Notes › Veto).
- **Batch 2's guarantee holds.** Every ending, the export's included, leaves no `TempResult` row for its test id.

**Never:**

- The vendor's `ExportToCubeDefinition`, `%Dictionary` saves, `$$Delete^%apiOBJ` or `%DeleteExtent` on a class the person did not name in this write. Also never an `INSERT … SELECT` or any SQL composed from a caller value.
- Data only, Drop old data, Overwrite classes, the iKnow measure, or a build. Building stays the Cube manager's `analytics.cubemanager.build`.
- A background run or `JOB` for the export, and any reuse or extension of Batch 2b's supervisor, event or cancel mechanics (`Work`, `Await`, `Reap`, `CancelJob`, `SpawnChild`).
- A spine edit.
- Edits to `ui/angular.json`, `ui/vitest-base.config.mjs`, or `scripts/ci-throwaway.sh`'s bring-up retry block.
- In `Prohibited.cls`, anything but appended terms.

## I/O & Edge-Case Matrix

Every row runs in USER on `ocupilot-b-ci`. The names are `ProbePmml.Export<m>.*`, and the cube is `ProbePmmlExport<m>`. Each test removes all three.

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Export, both callers | Probe model `Colors` over `Rows`; from the Test screen's action and from a confirmed proposal | `<R>` and `<K>` compiled; `<R>` holds exactly the run's records (count and per-value counts equal the answer's); `<K>`'s XData names `<R>` and `TestId = <id>`; `%CubeExists` true and the cube unbuilt; no `TempResult` row for the id; read-back `matches`; one `ConfigChange` row each | - |
| Other sources | Verification records; custom SQL; with a `SourceClass` | As above; `Record` resolves to the source row | - |
| Names | An OcuPilot class; `%X`; `NoPackage`; `<R>` = `<K>`; `<K>` in `<R>.`; a held class, package or case variant; a held cube; a 251-character, control-character or `}` cube name; an absent `SourceClass` | Nothing saved | 403 own code; 422 `CLASS`, `SAME`, `CUBENAME`, `SOURCECLASS`; 409 `TAKEN`, `CUBETAKEN` |
| Taken after the mint | A name or cube taken between the mint and the confirm | Nothing saved; proposal closed as target-changed | 409 |
| The test fails | A vendor error; a run past a short bound (fixture) | No `<R>`, `<K>` or rows; no `TempResult` row | 422 `EXPORTRUN` |
| A step fails | `<K>` refused by the compiler (fixture seam); the copy fails (fixture seam) | No `<R>`, `<K>`, `<K>.*`, cube or rows; outcome `restored` | 422 `EXPORTCOMPILE` |
| Gate | No `%Development:USE`; no WRITE on the routines or the `^DeepSee.Fact` database; read-only; analytics off; a non-query SQL | Refused before any lookup | 403; 409 `READONLY`, `CUBE.READONLY`, `NAMESPACE`; 422 `QUERYONLY` |
| Key | Agent confirm with the key off | Refused; the person's action runs | `GOVERNANCE.DISABLED` |

</intent-contract>

## Code Map

Paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-24`, at HEAD `8524da6eb`. No file named here is changed on `origin/OCU-1-epic21` beyond feature (checked at plan time). The implement stage re-runs `git log --no-merges origin/OCU-1-epic21 ^origin/feature/OCU-1_ocupilot-mvp -- <path>`, and any hit becomes (contended: add-only). `Prohibited.cls` is always (contended: add-only).

**Vendor (read-only):** these are the calls the classic makes; OcuPilot calls only `%CubeExists`.

- `%DeepSee.PMML.UI.AbstractTester` (hidden) is exported to `.../scratchpad/e24u/24-14/b4/AbstractTester.cls`:
  - `launchExport` :617 sets the defaults;
  - `export` :663 opens `_DeepSee.UI.Dialog.CubeBuild.cls` afterwards;
  - `ExportToCubeDefinition` :687-878 makes these calls:
    - `$zname(…,4)`, `$$$defClassDefined`, `$$Delete^%apiOBJ(…,"c-de")` for overwrite, and `%DeepSee.Utils.%CubeExists`;
    - `$classmethod(R,"%DeleteExtent")` for data only, and `%Dictionary.ClassDefinition`/`PropertyDefinition` `%Save`;
    - `$system.OBJ.Compile(…,"c-d")` and `%DeepSee.Utils.%GetSQLTableName`;
    - a `%SQL.Statement` `INSERT INTO <table> … SELECT … FROM %DeepSee_PMML_Utils.TempResult WHERE TestId = ?`;
    - `%DeepSee.Model.cube`/`dimension`/`hierarchy`/`level` and `XMLExportToStream`.
- `irislib/%DeepSee/PMML/UI/ModelTester.cls`: the Export command :33 and `GetExportPackageName` :331.
- `irislib/%DeepSee/Datatype/entityName.cls`: `MAXLEN` 250.

**Server:**

- **`Port/AnalyticsPort.cls`.** Extend Batch 3's PMML path; do not copy it.
  - `PmmlRun` :2657 gains trailing optional `pCopyTo As %String = ""` and `Output pCopied`. A new private `PmmlCopy(pNamespace, pTestId, pClass, Output pCount)` runs before the drop at :2688 only when the outcome is `ran`. Callers today pass neither argument, so they are unchanged.
  - `Serves` :751 and the `Invoke` dispatch serve `PmmlModel`'s write `TOCUBE` and read `PMMLEXPORT`.
  - New `AdmitPmmlExport` sits beside `AdmitPmmlDefinition` :7253.
  - New `PlanPmmlExport` makes the refusals and composes both class texts. Its sibling is `PlanPmmlDefinition` :7410; `PmmlClassText` :7285 shows how to compose.
  - New `PerformPmmlExport` calls `WriteClass` :6214, `RestoreClass` :6249, `PmmlRun` and `AuditWrite` :3310.
  - `RestoreClass` gains an optional `pKillExtent` (a parameter, not a copy) only if Task 0 shows a delete leaves `<R>`'s data.
  - `SnippetForm` :3330 answers `""` for `TOCUBE` (Design Notes › Decided 3).
- **`Api/AnalyticsError.cls`:** the codes `PMML{SAME,CUBETAKEN,CUBENAME,SOURCECLASS,EXPORTRUN,EXPORTCOMPILE,EXPORT}`, with their reasons, `ReasonFor`, the roster and `PmmlCodes()`.
- **New `Screen/Tool/AnalyticsPmmlModelExport.cls`.** It extends `AnalyticsAction`, as `AnalyticsCubeBuild` does, with:
  - `TOOLNAME` `analytics.pmmlmodel.export`, `SCREENACTIONS` `export`, `WRITETYPE` `TOCUBE`, `READTYPE` `PMMLEXPORT` and `READBACKFIELDS`;
  - `DESCRIPTORCLASS` `AnalyticsPmmlModelTest`, `CLASSICPAGES` `%DeepSee.PMML.UI.ModelTester` and `CONSEQUENCECODE` `ANALYTICS.PMML.EXPORT`;
  - `SENDSBODY` 1, with its values declared through `SCREENVALUES` (AD-56; `ExplorerNamespacePromote` :57 is the sibling);
  - `IdArgument` set to the model's composite id;
  - `PrivilegePairs` adding WRITE on both databases (`AnalyticsListingGroupAction.PrivilegePairs` :64 is the shape);
  - `WriteOutput` set to the answer.
- **`Screen/Descriptor/AnalyticsPmmlModelTest.cls`:** `primaryAction` `{"id":"export"}`, an agent phrase if the registry asks for one, and the doc comment's "offers no action" corrected.
- **`Kernel/Governance/Baseline.cls`:** the key. **`Kernel/Proposal/Prohibited.cls`:** no edit expected, since the target type `pmml-model` is already covered and passes the three sites; if the sweep refuses `TOCUBE`, add one appended term only.

**Client (`ui/src/app/`):**

- `areas/analytics/pmml-model-test.page.ts` gets the Export to cube action and its result line.
- New `pmml-export-dialog.ts`, modeled on `pmml-definition-dialog.ts`. It shows the page's current source and four fields with the defaults.
- `pmml-test.store.ts` sends the action through the screen action path.
- `shell/screen-action-handler.ts` gets the registration, and `core/strings.ts` the ruled strings.
- `core/screens.generated.ts` and `Screen/Titles.cls` are regenerated.

**Tests:**

- `Test/PmmlProbe.cls`:
  - `Gone()` also requires no `ProbePmml.Export*` class and no `ProbePmmlExport*` cube;
  - `Left()` reports them;
  - a new `RemoveExport(pMarker)` kills the extent, then deletes `<K>` and then `<R>`.
- New `Test/AnalyticsPmmlExport.cls` and `Test/AnalyticsPmmlExportEdge.cls`. Each extends `AnalyticsPmmlCreateBase` (which declares `OCUPILOT_ALLOW_PRINCIPALS`, so no arming roster line is needed) with `DependsOn = OcuPilot.Test.PmmlProbe`. Fixture seams for a short bound and a failing compile or copy are subclasses of the port, as `PmmlPortSlowDrop` is.
- Rosters (Rule 30). Re-grep `analytics.pmmlmodels.add`, `AnalyticsPmmlModelAdd` and `analytics.cubemanager.build`. Expect hits in:
  - `Test/{SurfaceCoverage,EndpointCoverage,ToolRoundTrip,StageTwoTools,Descriptor,MappingDescriptor,GovernanceBaseline,ToolWrite,ToolEmit,ClassicPageGate,ReadTool,SaveHoldCoverage,AnalyticsDescriptor}.cls`;
  - `ui/tools/{screen-mirror,navigation,analytics}.test.mjs`.

  `analytics.test.mjs` also forbids `ExportToCubeDefinition`, `%DeleteExtent` and `INSERT INTO` in `AnalyticsPort.cls`.
- `pmml-model-test.page.spec.ts`, and a Batch 4 test in `ui/browser/analytics.browser-spec.mjs`.

**Planning and docs:**

- `docs/exclusion-register.md`: rows AN-25 (data only), AN-26 (overwrite classes) and AN-27 (iKnow measure).
- `feature-catalog.md` and `extract-stages.md`: as Story 24.8's spec :120-200 does for DT-11, with the counts re-derived by parsing.
- `EXPERIENCE.md`: one add-only Fixed strings row after :622.
- `README.md` :231: one add-only clause.

## Tasks & Acceptance

**Execution:**

- [ ] **Task 0 (implement, `ocupilot-b-ci`, USER; remove every probe class and cube afterwards).** Record each answer under Design Notes › Measured.
  1. Whether `SourceDocument.Remove` of a compiled `%Persistent` class that holds rows leaves its data global.
  2. The classes a cube class's compile generates, and whether deleting `<K>` removes them and makes `%CubeExists` false.
  3. What a refused cube compile leaves after `RestoreClass`.
  4. The database the compile writes `^DeepSee.Cubes` (and what else) to.
  5. That auditing records no vendor event for either save or compile.
  6. `TempResult`'s column types against `<R>`'s, with the value lengths the probe writes.
  7. Rows a second for the object copy over the probe's `SIXWAY` statement.
  8. The XData OcuPilot composes against the vendor's `XMLExportToStream` for the same model, with a cube name holding `"`, `&` and `<`.
  9. That a principal with only `PMMLPAIRS` and `%DB_USER:RW` completes all of it.

  HALT `blocked` with `intent gap` if any delete leaves a class, cube or row that no step removes, or if the principal cannot compile a cube class.
- [ ] `AnalyticsPort.cls`, `AnalyticsError.cls`, `Baseline.cls`, the new tool, the descriptor, and `Prohibited.cls` only if needed: as the Code Map says. This is the write, the refusals, the restore and the read.
- [ ] The client page, dialog, store, handler and strings, the regenerated mirror and titles, and the EXPERIENCE.md row.
- [ ] Tests: the matrix in the two new classes, the probe change, the component and browser tests, and every roster.
- [ ] The exclusion register, the catalog and the extract: three rows, with `exclusion-register.test.mjs` green.
- [ ] `README.md`: the clause under Design Notes › Proposed strings, inserted after "and runs a pivot;" in the Analytics sentence. Nothing else in the file changes.

**Acceptance Criteria:**

- **AC1 (round trip, both callers; Integration, Rule 1).**
  - **Given** the probe model,
  - **When** a person exports from the Test screen, and the agent proposes an export and the person confirms,
  - **Then** each read-back reads `matches`, `<R>` holds exactly the run's records, the Cubes list (`analytics.cubes`) lists the new cube unbuilt, and no `TempResult` row is left for the test id.
- **AC2 (refusals).**
  - **Given** each Names, Gate and Key row of the matrix,
  - **When** either caller sends it,
  - **Then** it is refused with that row's code, and no class, cube or row is made.
- **AC3 (nothing remains).**
  - **Given** a failing test, compile or copy,
  - **When** either caller exports,
  - **Then** the answer is the matrix's code, and no `<R>`, `<K>`, `<K>.*`, cube, `<R>` row or `TempResult` row remains.
- **AC4 (audit and card).**
  - **Given** a confirmed agent export,
  - **When** it reads OK,
  - **Then** one `ConfigChange` row and its marker are recorded, and the card showed the model, the source and the four names with the export's consequence.
- **AC5 (exclusions).**
  - **Given** the three classic options left out,
  - **When** this batch lands,
  - **Then** the register, the catalog and the extract hold AN-25 to AN-27, and `exclusion-register.test.mjs` passes.
- **AC6 (fresh, either order).**
  - **Given** any new or changed test, run first on a fresh instance in either order,
  - **When** it ends,
  - **Then** `PmmlProbe.Gone()` is true.

## Spec Change Log

- 2026-11-21, spec gate (runner, veto item U-132): every recommended veto item kept as proposed: the key ships true, Decided 1-6, the stricter refusals, the proposed strings and README clause, and the proposed AD-7/AD-65 wording (spine unedited).

## Review Triage Log

## Design Notes

**Governing ADs (Rule 6):** AD-3, AD-6, AD-7, AD-8, AD-10, AD-11, AD-13, AD-14, AD-15, AD-16, AD-21, AD-22, AD-29, AD-36, AD-51, AD-53, AD-56, AD-58, AD-59, AD-60, AD-61, AD-65. Nothing contradicts them. AD-7's "a short foreground request" is met as the cube build meets it, with a named limit, and the wording below is proposed for it.

**Integration and linkage (Rules 1, 2).**

- **Consumes:**
  - Batch 2's `PmmlRun`, `PmmlResolve` and `PmmlTest.Check`;
  - Batch 3's free-name rule, `WriteClass` and `RestoreClass`;
  - `AnalyticsAction`, `SCREENVALUES` and `PmmlProbe`.
- **Consumed-by:** the Test screen's Export to cube, and the Cube manager, whose Build builds the cube.
- AC1 is the Integration AC.
- **Extend, don't copy:** the tool extends `AnalyticsAction`; `PmmlRun` takes the copy as a parameter. The class text composer is new, since no sibling writes a `%Persistent` or cube class.

**Ledger inbox (Rule 17):** none. `LEDGER slice 24-14-…` is empty.

**Decided in-stage (plan).**

1. **The target is the model** (`pmml-model`, `[Class, Model]`, AD-13). It is an action-style write with declared values (AD-51, AD-56), not an AD-54 create: the model must exist, and the new names' absence is checked by the port and fingerprinted through `PMMLEXPORT`. So Batch 3's `PermittedCreateFields` line is untouched.
2. **The copy goes through the object layer.** A least-privileged person's dynamic SQL on `TempResult` is refused (measured, Batch 2 `PmmlDrop`), and the vendor's `INSERT` composes a table name (AD-21).
3. **No script form** (`SnippetForm` `""`). Its steps are a model test plus a copy, which the classic's own calls do not express as a draft that runs no write (veto).
4. **The bound is the test's own `MDXSECONDS` (120).** No new number. An export that outlasts the Web Gateway's response timeout (inference: 60 s by default) runs to its end and its answer is lost, as a cube build's is. An export cannot be canceled.
5. **`SourceClass` is kept** (parity), optional, with no prefill: the classic fills it from custom SQL only.
6. **The test is the export's own.** The page's last run is not reused, because Batch 2 drops its rows.

**Named limits.** These are stated, not fixed.

- The model's generated code and a custom query run with the person's rights.
- Default names sit inside the PMML definition's package, as the classic's do. A later recompile of the definition replaces only the names it generates (inference, Batch 3 review).
- Removing an export means deleting both classes in System Explorer. OcuPilot does not undo it.

**Veto items (unattended):**

- The key `analytics.pmmlmodel.export` ships **`true`**. It refuses every held name and builds nothing. If `false`, README's "Eighty-two" count and the release paragraph change.
- Decided 1-6.
- The stricter-than-classic refusals: SAME, the cube-name rule and an OcuPilot `SourceClass`.
- The README clause and the proposed strings.
- The proposed AD wording.

**Proposed AD wording** (the spine is unedited).

- **AD-7:** "A PMML model's Export to cube (Story 24.14) runs its own test in its confirm or action request through `AnalyticsPort.PmmlRun`, under the test's bound and never in a background run, and copies the test id's rows into its new result class before the run's drop, so every ending still drops them. An export that outlasts the Web Gateway's response timeout runs to its end in that request's process; its answer is lost (named limit)."
- **AD-65:** "Export to cube saves and compiles a `%Persistent` result class and a `%DeepSee.CubeDefinition` class through the class-write path, behind PMML's pairs and WRITE on the databases `^oddDEF` and `^DeepSee.Fact` map to, refusing a held class, package or cube; it copies rows through the object layer, composes no SQL, never builds the cube, and deletes every class it saved when a later step fails."
- **AD-22:** the key's ruled state.

**Proposed strings** (veto; none are in EXPERIENCE.md).

- **Action and dialog title:** "Export to cube".
- **Labels:** "Result class name", "Cube name", "Cube class name" and "Link to source class", as the classic labels them. Reused: Source, Data source, SQL, Cancel.
- **Consequence (`EXPORT`):** "The test runs again with your rights. Its results are copied into a new result class, and a new cube class reads them. The cube is not built until you build it in the Cube manager, and OcuPilot cannot undo an export."
- **Result line:** "Exported {count} records to {class}. Build the cube {cube} in the Cube manager."
- **Reasons:**
  - SAME: "The result class and the cube class must be two classes, neither in the other's package."
  - CUBETAKEN: "This namespace already holds a cube with this name."
  - CUBENAME: "A cube name is 1 to 250 characters, with no control character and no } character."
  - SOURCECLASS: "The class to link to is not one this namespace holds."
  - EXPORTRUN: "The test did not finish, so nothing was exported."
  - EXPORTCOMPILE: "The instance refused the export's classes or rows, so nothing was changed."
  - TAKEN, CLASS, READONLY and CUBE.READONLY are reused.
- **Agent phrase:** "export a test to a cube".
- **README** (add-only, after "and runs a pivot;"): "tests a PMML model against its data sources, its verification records or an SQL query, creates PMML definitions from PMML text, and exports a test's results to a new cube;". This is the last batch, so the story's README line belongs here.
- **Exclusion rows** (docs, not UI):
  - AN-25 "PMML export: data only". Gate kind `demand`. Reason: "It adds rows to, or erases, a class an earlier export made; the export makes new classes only."
  - AN-26 "PMML export: overwrite classes". Gate kind `demand`. Reason: "It deletes and replaces classes the person names."
  - AN-27 "PMML export: iKnow measure". Gate kind `deprecation`, in the text-analytics group. Reason: "iKnow Text Analytics is deprecated."

## Verification

**Commands** (one `ci-runner` call per message; `ocupilot-b-ci` only; changed classes loaded with their subclasses recompiled):

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.AnalyticsPmmlExport`, then the same for `AnalyticsPmmlExportEdge`, `AnalyticsPmmlRun`, `AnalyticsPmmlRunEdge`, `AnalyticsPmmlRunCancel`, `AnalyticsPmmlCreate`, `AnalyticsPmmlModels` and every roster class changed. Expected: green, each new class on its first run.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`. Expected: green, `exclusion-register.test.mjs` included.
- `(loop)` `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/analytics.browser-spec.mjs`. Expected: green.
- `(once)` The same environment for `browser/a11y-structural-invariants.browser-spec.mjs`. Expected: green.
- `(once)` The full ObjectScript sweep: `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17` for k = 1 to 17, one call each. Expected: green. The full browser suite is left to CI.
- `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh`. Expected: clean.

**Mutations (Rule 19):** one per AC, recorded here by the implement stage:

- AC1: `PmmlCopy` copies nothing.
- AC2: a refusal skipped.
- AC3: the restore of `<R>` skipped.
- AC4: `AuditWrite` skipped.
- AC5: the AN-26 row removed.
- AC6: the probe's export removal skipped.

**Shared surfaces:** the Test screen's actions; the write-tool, coverage, endpoint and route rosters; the governance baseline; `PmmlRun`'s signature (every PMML class); `PmmlProbe.Gone`/`Left`; `screen-mirror.test.mjs`; the `analytics.test.mjs` guards; the exclusion register and its counts.

**Hermeticity:** every test added or changed passes on its first run on a fresh instance, in either order. It removes every `ProbePmml.Export*` class, `ProbePmmlExport*` cube and row it makes.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
