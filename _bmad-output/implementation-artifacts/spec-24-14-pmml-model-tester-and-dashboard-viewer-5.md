---
title: 'Story 24.14: PMML model tester and dashboard viewer (Batch 4: Export a PMML test''s results to a cube)'
type: 'feature'
created: '2026-11-20'
status: 'ready-for-dev'
baseline_revision: 'a40b3789e08a4dea700910680b5b9f002c214c49'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-14-pmml-model-tester-and-dashboard-viewer-3.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-14-pmml-model-tester-and-dashboard-viewer-2.md'
warnings: ['oversized']
deferred:
  - 'med, in-story: the script form copies and drops the test rows with dynamic SQL, so for a person without SQL privileges on %DeepSee_PMML_Utils.TempResult its copy is refused and the drop leaves the rows in IRISTEMP; saying so in the script needs a ruled sentence (the write uses embedded SQL and is unaffected).'
  - 'med, in-story: the write and the script kill the new result class extent before the copy, which also erases data an unrelated writer left under a free class name global; refusing such a name instead is stricter and changes Measured 1, so it needs a product ruling.'
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
  - `SnippetForm` :3416 answers `objectscript` for the PMML model endpoint's `TOCUBE`, and `Snippet` :3433 renders the export's draft through a new private `PmmlExportSnippet`, whose sibling is `PmmlDefinitionSnippet` :7588 and which builds its steps with `ClassWriteSnippet` :6385 where they fit (Spec Change Log, 2026-11-21 re-open).
    - It reads the stored proposal's arguments, the query's namespace and model id and the body's names and source, and it runs no write.
    - It mirrors every branch `PerformPmmlExport` takes: `PlanPmmlExport`'s refusals as a script that only sets the refusal's sentence, the result class saved and compiled, the export's own test and copy, the cube class saved and compiled, and, when a later step fails, the delete of every class the script saved.
    - It carries no secret. A draft whose text would pass `OcuPilot.Port.AtelierPort.SNIPPETMAXCHARACTERS` answers no step, as the siblings do.
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
- [ ] Script form (re-open, veto item U-133): `SnippetForm` and `Snippet` for `TOCUBE` as the Code Map says. In `AnalyticsPmmlExportEdge` (or the class that held it), replace `TestTheExportHasNoScriptForm` with a test that pins the rendered draft: it mirrors the branches and renders from the stored arguments, with no write run and no secret. `OcuPilot.Test.DraftRegistry` is green. Its `mutation:` line is written in `## Verification`.
  - Two conditions ride on the draft (orchestrator, U-133, relayed by the lead). First: `PmmlExportSnippet` validates every name it interpolates before it renders (the result class, the cube class, the package, the model and the source) with the shape checks `Invoke` uses, and quotes each with `Literal` as the cube Build's draft does. A name that fails renders no draft at all (`Snippet` answers `[]`), never a draft holding the raw value. One further test uses a hostile class name holding a quote, a newline, `_` and `$$$` and asserts that no draft is rendered; it has its own `mutation:` line. Second: the draft states its one-way step in one script comment line, using only the ruled consequence sentence's words "OcuPilot cannot undo an export" (Proposed strings). Any new user-facing sentence HALTs `blocked` with `intent gap: new string <text>`.
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
- 2026-11-21, re-open (runner, intent gap resolved toward the spine): Decided 3 is reversed, because AD-59 binds every write tool and its registry test fails a tool with no script form. `TOCUBE` gets a script form: `AnalyticsPort.SnippetForm` answers a form for `TOCUBE`, and `Snippet` renders an ObjectScript draft that mirrors every branch `Invoke` takes for the export (its own test, the two class saves and compiles, the copy, and the delete on a later failure) from the stored proposal's arguments, as the cube Build's draft does, and runs no write. The draft carries no secret. `TestTheExportHasNoScriptForm` is replaced by a test that pins the rendered draft. AD-59 is unchanged.
- 2026-11-21, re-open (runner, orchestrator rulings on the review's two deferrals): DW-2819 (a): after the result class compiles and before any extent kill, the write reads the compiled storage's data, index and stream locations (never `^<class>D` guessed from the name) and refuses with `ANALYTICS.PMML.DATAHELD` when any holds data, through the existing delete-everything-saved path. The script form makes the same check in the same order. DW-2818 (b): the script gains the comment "This script needs SQL SELECT and DELETE privileges on %DeepSee_PMML_Utils.TempResult." Orchestrator-approved strings: the DATAHELD reason "This namespace already holds data stored under this class name. Choose another name.", the DW-2818 comment, the script's no-bound comment, and the tool's `StateDiff` problem sentence.

## Review Triage Log

### 2026-11-20 — Review pass

- verdicts: 10 findings — high 1, medium 1, low 8, false 0, maybe-false 0 (3 patched, 6 rejected, 1 intent_gap); `src/OcuPilot/Api/Error.cls` is not in the diff (both layers confirmed; every new code is in `AnalyticsError.cls`)
- findings:
  - `[medium]` `[patch]` The short-bound leg armed 0.5 s over a 20,736-row run measured at 0.84 s, so a faster runner finishes in time and the leg reads 200 — `AnalyticsPmmlExportEdge`: the bound is now 0.01 s, which any run exceeds (the stop test is `elapsed >= bound`); the doc comment says so.
  - `[low]` `[patch]` The component spec's field-violation path was not exercised though its title claims it — `pmml-model-test.page.spec.ts`: a third route answers `AGENT.VALIDATION` with a `Cube` violation, and the test asserts the text under the cube field, none under the result class field and no banner.
  - `[low]` `[patch]` A doc comment still said a 250-character cube name is made — `AnalyticsPmmlExportEdge`: the clause removed (the real compile refuses it, Measured 10).
  - `[low]` `[reject]` `Gone()` does not read a surviving result-class data global — the test helper's own `ExportLeft` and the write's pre-run extent kill cover it; no user-reachable failure.
  - `[low]` `[reject]` The `PmmlProbe` seam state (`^||`, process private) is reset by each leg before it arms and after it ends, not by a hook — an exception between the two is theoretical.
  - `[low]` `[reject]` `Prohibited.cls` takes its `pmml-model` line among the analytics lines, not at the end — add-only, a per-type line, no shared condition touched, and the chain has no order; `git log` shows Epic 21 has not changed the file.
  - `[low]` `[reject]` The `pCubeSaved = 1` restore branch is unreachable today — a defensive restore of the one class that would need it if a step is added after the cube's save.
  - `[low]` `[reject]` The agent card test supplies no `SourceClass`, so the card shows three names for it — the field is optional with no prefill (Decided 5), and the fifth leg of the other-sources test links one.
  - `[low]` `[reject]` `TestTheExportHasNoScriptForm` passes without a code change — an intended tripwire for the Decided 3 default.
  - `[high]` `[intent_gap]` (found by the lead's full sweep, shard 16, not by a layer) `OcuPilot.Test.DraftRegistry.TestEveryWriteToolHasAScriptForm` and `TestNoSecretReachesAnyRenderedScript` are red: `analytics.pmmlmodel.export` is a registered write tool whose `SnippetForm` is `""` (Decided 3), and AD-59's Rule fails the registry test "when any registered write tool's port or request type has no script form, so a new write tool cannot ship without one". Decided 3 and AD-59 cannot both hold. The test is not in the spec's `(loop)` list and `DraftRegistry.cls` was not changed, so the implement pass never ran it. Two resolutions need a ruling: (a) amend AD-59 and the two registry legs with an exemption for this tool, or (b) a script form for `TOCUBE` (a model test, the two classes and the copy as a draft that runs no write), reversing Decided 3. The work is left uncommitted in the tree; the full diff is saved at `.../scratchpad/e24u/24-14/b4/lead/b4-attempt.patch`.
  - Intent-alignment layer: no divergence found. It lists three additions beyond the contract's text (the pre-run extent kill, the plan's preparation refusal, `Held` and a `Prohibited` field line), each recorded under Decided in-stage or Measured.

### 2026-11-21 — Review pass (script form re-open)

- verdicts: 11 findings — high 0, medium 2, low 9, false 0, maybe-false 0 (2 patched with a test leg each, 4 patched as code or doc lines, 5 rejected; the intent-alignment layer found no divergence on the write path)
- findings:
  - `[medium]` `[patch]` The script's pre-run `%KillExtent` was unpinned: the only assertion was a text match that the failure-path kill also satisfies — `AnalyticsPmmlExportEdge`: a leg leaves a row in the result class's data global, runs the script and asserts the result class holds only the run's rows; its mutation is recorded. The first draft of the leg used a name whose data global is hashed, so it passed under the mutation; the marker is now short enough that the global is the name and `D`.
  - `[medium]` `[patch]` The script's run-failure branch had no test (only the cube compile failed) — `AnalyticsPmmlExportEdge`: a custom export whose statement is swapped for a missing table runs to a failure and leaves nothing; its mutation is recorded. The script's copy-failure branch shares the failure lines, which the cube compile leg and this leg exercise.
  - `[low]` `[patch]` The `SnippetForm` doc comment listed three writes — `AnalyticsPort`: it names the others.
  - `[low]` `[patch]` The `PmmlExportSnippet` comment did not say the script runs the test without the write's bound — `AnalyticsPort`: stated.
  - `[low]` `[reject]` `DraftRegistry`'s synthetic proposal reaches only the refusal step — the registry's per-tool legs pin that a form exists and no secret reaches a draft; the draft body is pinned by the Edge test, which renders from the stored query and body through `Snippet`, the call the draft route makes.
  - `[low]` `[reject]` The `DraftRegistry` roster rows have no removal mutation of their own — they are shape data for a synthetic row, not an acceptance pin; the `SnippetForm` mutation reddens the registry.
  - `[low]` `[reject]` No test renders from a minted proposal through `Draft.Render` — the registry's round-trip leg renders every write tool's draft from its stored proposal and compares its steps with `Snippet`'s.
  - `[low]` `[reject]` Mutation lines missing for the three refusal-only legs and the model-id and namespace legs — each is a leg of a test whose pinning mutation is recorded; one demonstrated mutation per AC is the bar.
  - `[low]` `[patch]` A name that is both OcuPilot's own and malformed rendered the refusal sentence, not no draft, which U-133's first condition forbids as written — `AnalyticsPort`: the shape check now runs before the plan for every name, with `PmmlDraftClassShaped` (`ListingClassShaped`'s pattern, which also admits an `OcuPilot` package so a well-formed own-code name is still the write's 403 sentence). A test leg and its mutation are recorded.
  - `[low]` `[patch]` The script has no 120-second bound — `AnalyticsPort`: the script says so in one comment line, as the orchestrator's later condition asked; no bound is added.
  - Mutation coverage for the legs the verification-gap layer listed as unproven is added: the refusal steps, the three run calls, the model-id and namespace legs, the bound comment and the registry row; the dataset call's data source cannot be mutated alone (recorded in `## Verification`).
  - `[low]` `[reject]` Intent-alignment layer: the draft runs the vendor's calls directly, with no bound, no audit row and no answer — inherent to a script form a person runs; the contract's branches are mirrored and the write is unchanged.
  - Intent-alignment layer: no divergence between the contract and the diff on the write path; the script form is the one addition and is recorded in the Spec Change Log.
  - A second verification-gap layer launched first did not return (its shell call hung for over fifteen minutes and the lead could not stop it); its work is superseded by the layer above and nothing it did touched the tree.

### 2026-11-21 — Code review (Batch 4, four layers)

- verdicts: 25 findings — high 0, medium 8, low 17 (11 patched, 2 deferred, 12 rejected); layers: adversarial, edge cases, verification gaps, security and rights
- findings:
  - `[medium]` `[patch]` The write's extent kill before the test was unpinned — `AnalyticsPmmlExportEdge.TestAnExportOverDataAnEarlierClassLeftHoldsOnlyItsRows`, mutation recorded.
  - `[medium]` `[patch]` `DataLeft` sees nothing for a class name over 29 characters (measured), so the `BadCube`, `BadCopy` and `ScriptLong` data legs proved nothing and the script's failure-line extent kill was unpinned — markers `BCube`, `BCopy`, `SLong`; `DataLeft`'s comment states the limit; the QA line above corrected; mutations recorded.
  - `[medium]` `[patch]` An export applied after its dialog was canceled left no line, and the dialog could reopen during a send — `pmml-model-test.page.ts`; a component test with two mutations.
  - `[medium]` `[patch]` Rule 31: `PmmlExportSourceShaped` repeated `PmmlTest.Body`'s source rule — `Body` now checks the keys and calls the port's rule.
  - `[medium]` `[patch]` Rule 31: `PmmlDraftClassShaped` repeated `ListingClassShaped`'s pattern — `ListingClassShaped` calls it and adds the `OcuPilot` exclusion.
  - `[medium]` `[patch]` The script could replace a cube class another writer made during its unbounded test (the write's save is create-only) — the script asks the cube class's names again before the save; the `SRace` leg and its mutation.
  - `[medium]` `[defer]` The script copies and drops with dynamic SQL, which a person without SQL privileges on `TempResult` is refused, leaving the test rows (frontmatter `deferred`).
  - `[medium]` `[defer]` The extent kill also erases data an unrelated writer left under a free name's globals; refusing is stricter and changes Measured 1 (frontmatter `deferred`).
  - `[low]` `[patch]` The vendor's text was not logged when the export's test failed — `PerformPmmlExport` logs it.
  - `[low]` `[patch]` A cube name past 250 characters was looked up before it was refused — the plan and the read look up only a name within the bound.
  - `[low]` `[patch]` The script's copy ignored `%Next`'s status — it ends the copy as a failed row save does.
  - `[low]` `[patch]` `RemoveFixtures` left vendor rows after a failed leg — it drops them.
  - `[low]` `[patch]` The stale-data legs did not check their setup — each asserts the planted row.
  - `[low]` `[reject]` `Gone()` and `Left()` read no data global — the write's and the script's extent kills are now pinned, so an orphan cannot change a later result; reopen if a test reads rows it did not make.
  - `[low]` `[reject]` `%CubeExists` answers 0 for a disabled or unreadable cube, so the export ends `EXPORTCOMPILE` after the run with nothing changed (Measured 3) — reading `^DeepSee.Cubes` is outside AD-65's reads and would reveal a cube the person cannot see.
  - `[low]` `[reject]` The cube-name rule admits names the vendor's compile refuses — the ruled `CUBENAME` rule (Measured 10); by design.
  - `[low]` `[reject]` A failed restore is answered with the refusal's sentence — as Batch 3's class writes do; the outcome is in the audit row and the log.
  - `[low]` `[reject]` A request past the Web Gateway's timeout shows no sentence — the shell's behavior for an answer with no envelope; named limit (Decided 4).
  - `[low]` `[reject]` The default names can be malformed for some model names — the classic's own defaults (`GetExportPackageName`); the plan answers `CLASS`.
  - `[low]` `[reject]` An exception after the result class's save skips the restore — the steps return statuses; real only if one raises.
  - `[low]` `[reject]` The gate checks only the `^oddDEF` and `^DeepSee.Fact` databases — a result class whose data maps to a read-only database fails the copy and logs `restorefailed`; reopen if a package mapping is reported.
  - `[low]` `[reject]` The tool's `PrivilegePairs` repeats the listing group tool's — the Code Map named that shape; reopen if a third tool repeats it.
  - `[low]` `[reject]` The `StateDiff` problem sentence is not a Proposed string — an agent-facing tool problem in the siblings' form.
  - `[low]` `[reject]` The script's no-bound comment is not a Proposed string — U-133's fourth condition asks for it.
  - `[low]` `[reject]` `Prohibited.cls`'s line sits inside the chain — closed 2026-11-20.
- checklists:
  - A (U-133): 1 pass, every name, the source, the model id and the namespace are shape-checked before the plan and a failure renders no step (`AnalyticsPort.PmmlExportSnippet`, `PmmlExportDraftShaped`, `PmmlDraftClassShaped`); 2 pass, every interpolation through `Literal`; 3 pass, " ; OcuPilot cannot undo an export."; 4 pass, one no-bound comment and no bound; 5 pass, the `SnippetForm` comment lists the export; 6 pass, each earlier leg has a `mutation:` line or a reason, and the failure-line kill is now pinned.
  - B: every added string equals a Proposed string or `EXPERIENCE.md:623`, except the no-bound script comment (U-133 condition 4) and the agent-facing `StateDiff` problem.
  - C: `git diff 8f5ead53b 354796f5d -- src/OcuPilot/Api/Error.cls` is empty.
  - D: the three files are ASCII with no BOM, CR, tab or trailing whitespace, each ends in one line feed, and their code reads correct.
  - E: a failed write deletes the cube class it saved, kills the result class's extent and deletes it, and no cube stays registered (Measured 2, 3); the script's failure lines do the same; `Prohibited.cls` gains two lines and loses none.
  - F: no marker was safe beyond six characters (29-character class name); the data-relevant legs now use `BCube`, `BCopy`, `SLong`, `Stale`, `WStale`, `SRace` and `Quoted`.

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
3. **A script form** (`SnippetForm` `objectscript`; reversed at the 2026-11-21 re-open, because AD-59 binds every write tool). The draft is the export's steps as ObjectScript built from the stored proposal's arguments, and it runs no write when rendered.
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

**Measured (Task 0, implement, 2026-11-20, `ocupilot-b-ci`, USER; every probe class, cube, row and principal removed after).**

1. **Deleting a compiled `%Persistent` class leaves its data global.** `SourceDocument.Remove` of `ProbePmml.ExportT1.Result` with five rows left `^ProbePmml.ExportT1.ResultD` (11 nodes, counter 10), and a class of the same name made later would inherit the rows. `%KillExtent` before the delete leaves nothing, so `RestoreClass` gains `pKillExtent`, and the write kills a new result class's extent once it compiles, before the copy.
2. **A cube class's compile generates four classes**, `<K>.Fact`, `<K>.Listing`, `<K>.StarActualValue` and `<K>.StarPredictedValue`, and 11 nodes of `^DeepSee.Cubes`. Deleting `<K>` removed all of it: no class under `<K>.`, `%CubeExists` false, no `^DeepSee.Cubes` node.
3. **A refused cube compile leaves only `<K>`**: a level over a property the result class lacks, and a second class naming a held cube, each left the saved class and nothing else, no cube registered. Deleting it removed it; a held cube of the same name stayed intact.
4. **The databases:** `^DeepSee.Cubes`, `^DeepSee.Fact`, `^DeepSee.CubeVersion`, `^oddDEF` and the result class's data global all map to `%DB_USER` (read-write, mounted) in USER.
5. **Auditing (enabled) recorded nothing for either save, the result class's compile and delete, the rows, or the extent kill.** The cube class's compile and its delete each recorded one `%System/%Security/RoleChange` event, a process role change, and no event naming a class or a cube (inference: the vendor's cube code raises roles). OcuPilot's own row is still the only record of the change.
6. **`TempResult`'s strings are `%String(MAXLEN = 2000)` and its `Probability` is `%Double`; the vendor's export class declares `%String` (MAXLEN 50) and `%Numeric` (scale 2).** A 300-character value failed the copy ("length longer than MAXLEN allowed of 50") after one row, and `Probability` 0.123456789 stored as 0.12. The result class takes `MAXLEN = 2000` on its three strings and keeps `%Numeric`, as the classic's does.
7. **The object copy** (embedded SQL cursor bound to the id, one `%New` and `%Save` a row) copied 20,736 rows in 0.15 s, about 140,000 rows a second, after a vendor run of 0.84 s. The run's 120-second bound does not cover the copy, which adds about a sixth of a run's own time (inference: linear in rows).
8. **The cube class's XData composed here equals `XMLExportToStream`'s for the same model byte for byte,** for the names `ModelTestResults`, `A"B&C<D'E>F` and `x`: the vendor escapes `&`, `<`, `>`, `"` and `'`, writes one line and spells every default attribute.
9. **A principal holding `%Development:USE`, `%DeepSee_Portal:USE` and `%DB_USER:RW`** (and read of the system databases) saved and compiled both classes, saved rows, found `%CubeExists` true, killed the extent and deleted both classes, in a child process. Nothing was left.

10. **The real compile refuses a cube name of 250 characters, and one with `&`, `"`, `<` or `'`, as a cube class that does not compile** (the limit lies between 204 and 250 characters), so `EXPORTCOMPILE` restores both classes; the plan's own bound is `PMMLCUBENAMEMAX`.
11. **The vendor's run is lenient about a statement that fails per row.** A division by zero, an out-of-range expression and a missing column all ran with 0 records, so the tests seed an unpreparable statement (a missing table, `EXPORTRUN` at the plan) and the `vendor=error` seam for the run's own failure.

The class text service needs carriage return and line feed between lines; `SourceDocument.Save` converts, so the plans compose line feeds.

**Decided in-stage (implement).**

1. **The result class's three strings take `MAXLEN = 2000`** (Measured 6): a category over 50 characters would otherwise fail the copy. `Probability` stays the classic's `%Numeric`, so it keeps two decimals.
2. **The read answers `Held`**, the names (`ResultClass`, `CubeClass`, `Cube`) whose class, package or cube is held, beside the names themselves. The confirm's fingerprint is the merged payload, in which the person's names overwrite the read's, so a name taken since the review changed nothing the digest covers; `Held` is the field no argument overwrites, and the tool names it as its `STATEMARKER`. It is empty at the review, because a held name is refused there, and names the taken ones at the confirm.
3. **The refusals are made by the read composed for the write** (`PMMLEXPORT` with the action), so the screen's action route, which asks no tool for its field rules, and the agent's mint both refuse with the write's own codes before anything is proposed.
4. **The test's own SQL check (`SqlConsole.Check`, classification and self-protection) runs in the plan**, as `PmmlTest.Check` does it, so a seam port's gate applies; a statement the instance would not prepare is `EXPORTRUN` before anything is saved.
5. **The class to link to is held by `PmmlDefinitionFacts`' rule**, so a class with no package (which a result class could not be named either) reads as not held. The result class's text uses the class's stored name.

## Verification

**Commands** (one `ci-runner` call per message; `ocupilot-b-ci` only; changed classes loaded with their subclasses recompiled):

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.AnalyticsPmmlExport`, then the same for `AnalyticsPmmlExportEdge`, `AnalyticsPmmlRun`, `AnalyticsPmmlRunEdge`, `AnalyticsPmmlRunCancel`, `AnalyticsPmmlCreate`, `AnalyticsPmmlModels`, `DraftRegistry` and every roster class changed. Expected: green, each new class on its first run.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`. Expected: green, `exclusion-register.test.mjs` included.
- `(loop)` `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/analytics.browser-spec.mjs`. Expected: green.
- `(once)` The same environment for `browser/a11y-structural-invariants.browser-spec.mjs`. Expected: green.
- `(once)` The full ObjectScript sweep: `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17` for k = 1 to 17, one call each. Expected: green. The full browser suite is left to CI.
- `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh`. Expected: clean.

**Mutations (Rule 19):** one per AC, recorded here by the implement stage:

Each was applied on `ocupilot-b-ci` (loaded with its subclasses), run, and reverted to a byte-identical file (`shasum` equal).

- mutation: AC1, `PmmlCopy` quits before the cursor opens -> `AnalyticsPmmlExport.TestAnExportIsMadeByEachCallerAndReadsBack` and `TestTheOtherSourcesAndALinkToTheSourceClassExportToo` red.
- mutation: AC2, the `CUBETAKEN` refusal in `PlanPmmlExport` removed -> `AnalyticsPmmlExportEdge.TestAHeldClassPackageOrCubeIsRefusedAndNothingIsTouched` red.
- mutation: AC3, `PmmlExportRestore` skips the result class -> `AnalyticsPmmlExportEdge.TestAStepThatFailsRestoresEverything` and `TestATestThatDoesNotFinishLeavesNothing` red.
- mutation: AC4, `PmmlExportAudit` skips `AuditWrite` -> `AnalyticsPmmlExport.TestAnExportIsMadeByEachCallerAndReadsBack` red (audit row, outcome and agent marker).
- mutation: AC5, the AN-26 row removed from `docs/exclusion-register.md` -> `exclusion-register.test.mjs` red (missing P4 row AN-26; extract-only AN-26).
- mutation: AD-59 script form, the free-name condition of `PmmlExportSnippet` made `1` -> `AnalyticsPmmlExportEdge.TestTheScriptFormMakesTheExportAndRestoresWhenAStepFails` red on the run-again and class-taken legs; the result class's delete in its failure lines made never-run -> the same test red on the refused-compile leg. Each reverted to a byte-identical file (`shasum` equal) and reloaded.
- mutation: AD-59 script form, `SnippetForm` made to answer `""` for `TOCUBE` -> `DraftRegistry.TestEveryWriteToolHasAScriptForm` and `TestNoSecretReachesAnyRenderedScript` red naming `analytics.pmmlmodel.export`; reverted byte-identical.
- mutation: AD-59 hostile names, `PmmlExportDraftShaped` made to answer `1` -> `AnalyticsPmmlExportEdge.TestAHostileNameOrSourceRendersNoScript` red on all five field legs; reverted byte-identical.
- mutation: AD-59 stale data, the script's `%KillExtent` of the result class before the test removed -> `AnalyticsPmmlExportEdge.TestTheScriptFormMakesTheExportAndRestoresWhenAStepFails` red on the stale-data leg (the result class holds `stale=1` beside the run's rows); reverted byte-identical (`shasum` equal) and reloaded.
- mutation: AD-59 unfinished test, the script's `EXPORTRUN` failure after the test's run removed -> the same test red on the unfinished-test leg (runs to a success, a class is left); reverted byte-identical and reloaded.
- mutation: AD-59 one-way comment, the script's "OcuPilot cannot undo an export." comment removed -> the same test red on the comment assertion of all three sources; reverted byte-identical and reloaded.
- mutation: AD-59 own-package names, `PmmlDraftClassShaped` made to accept every name in an `OcuPilot` package -> `AnalyticsPmmlExportEdge.TestAHostileNameOrSourceRendersNoScript` red on its three own-package legs; a model id check and a namespace check removed from `PmmlExportSnippet` -> the same test red on its model-id and namespace legs. Each reverted byte-identical and reloaded.
- mutation: AD-59 refusal steps, the refusal's sentence step of `PmmlExportSnippet` made to answer no step -> `TestTheScriptFormMakesTheExportAndRestoresWhenAStepFails` red on its held, own-class and absent-source-class legs.
- mutation: AD-59 run calls, the verification and custom branches of the script's run call removed and the dataset call given no data source -> the same test red on the verification and custom legs. The dataset leg stays green: the vendor's `%RunModel` with no data source runs the model's own dataset, so the data source argument cannot be mutated on its own (recorded, not pinned).
- mutation: AD-59 the bound comment, the script's second comment (the test runs here without the write's limit) removed -> the same test red on the comment assertion of all three sources; reverted byte-identical and reloaded.
- mutation: AD-59 draft registry rows, the `Source:dataset` row of `ARGUMENTVALUES` for the export removed -> `DraftRegistry.TestNoSecretReachesAnyRenderedScript` red (no step rendered for `analytics.pmmlmodel.export`); reverted byte-identical.
- mutation: AC6, `PmmlProbe.RemoveExport` removes nothing -> `AnalyticsPmmlExport.TestAnExportIsMadeByEachCallerAndReadsBack` red (its audit assertions, on two consecutive runs). `Gone()` reads the classes, cubes and result rows only, so a surviving data global is seen by the tests' own `ExportLeft` and not by `Gone()` (inference: the run's red is the leftover state of the removal that did not run).

**Shared surfaces:** the Test screen's actions; the write-tool, coverage, endpoint and route rosters; the governance baseline; `PmmlRun`'s signature (every PMML class); `PmmlProbe.Gone`/`Left`; `screen-mirror.test.mjs`; the `analytics.test.mjs` guards; the exclusion register and its counts.

**Hermeticity:** every test added or changed passes on its first run on a fresh instance, in either order. It removes every `ProbePmml.Export*` class, `ProbePmmlExport*` cube and row it makes.

### QA

Batch 4 QA added, all passing on their first run on a rebuilt `ocupilot-b-ci`: `AnalyticsPmmlExportEdge` 12 tests green forward and again after `AnalyticsPmmlExport`; `AnalyticsPmmlCreate`, `CreateEdge` and `CreateGap` (the other subclasses of the changed base) green; the browser spec's two Batch 4 tests green.

- Cube-taken leg: `AnalyticsPmmlExportBase.ScriptOutcome` runs a script as `RunScript` does and returns the text of the error it ends on. `TestTheScriptFormMakesTheExportAndRestoresWhenAStepFails` now asserts the script ends on the published `CUBETAKEN` sentence. The old assertions (a failed run, an unchanged snapshot, the sentence in the rendered text) all stayed green with the cube term dropped.
  - mutation: the `'tCubeHeld` term dropped from `PmmlExportSnippet`'s free-name condition -> only the new cube-taken assertion red (the old ones stayed green); reverted byte-identical (`git diff` empty) and reloaded.
- Long cube name: `ExportLeft` takes the cube name the export asked for (`ExportLeft(pMarker, pCube)`), used by the 250-character legs of `TestAStepThatFailsRestoresEverything` (person and agent) and the script test; with none it reads the marker's own cube, as before.
  - mutation: the script's delete of the cube class in its failure lines removed -> the long-name leg red with `cube class cube` (the cube is registered under the long name); with `ExportLeft` reading the marker's own cube name it read `cube class` only, so the old check missed it; both reverted byte-identical.
- Copy-failure branch: pinned by `TestAScriptWhoseCopyFailsRestoresEverything`, which swaps the value the script sets on each row (`tRow.Probability`) for one the result class refuses, so every row save fails; it asserts the `EXPORTCOMPILE` sentence, an unchanged snapshot and nothing left. A row save cannot be made to fail through data, since the result class's strings take the longest value the vendor's result table holds.
  - mutation: the script's delete of the result class in its failure lines removed -> the new test red (class left); reverted byte-identical.
  - mutation: the script's delete of the vendor's result rows removed -> the new test red (`test rows`); reverted byte-identical.
  - mutation: the script's check of the row save's status removed -> the new test red (the script threw instead of ending on the sentence); reverted byte-identical.
- Browser: a new test in `analytics.browser-spec.mjs` opens Export to cube on the Test screen, checks the consequence sentence and the five field labels against the published strings, exports, checks the result line against the published template with the run's record count, then exports again under the same names and sees the `TAKEN` sentence in the dialog, the dialog still open, and the first export's rows, cube and an empty vendor result table unchanged; it ends with every export and probe removed.
  - mutation: the consequence in `pmml-export-dialog.ts` drawn from `analyticsPmmlExportAction` -> the consequence leg red; reverted byte-identical, bundle rebuilt and redeployed.
  - mutation: the refusal in `pmml-export-dialog.ts` drawn from `actionCancel` -> the refusal leg red; reverted byte-identical, bundle rebuilt and redeployed.
- Nothing else probed needed a new test: a second export with the same names through the port is pinned by `TestAHeldClassPackageOrCubeIsRefusedAndNothingIsTouched`, and the leftover class, cube and vendor row after each test is pinned by `ExportLeft` in every test plus the per-test `RemoveFixtures`.
- QA finding: `AnalyticsPmmlCreateBase.DataLeft` reads the data global as `^<class>D`, which is the class's data global only for a class name of at most 29 characters; the compiler hashes a longer one's (measured on `ocupilot-b-ci`: `ProbePmml.ExportWStale.Result` keeps `^ProbePmml.ExportWStale.ResultD`, `ProbePmml.ExportBadCopy.Result` gets `^ProbePmml.ExportBad6971.ResultD`), and the read then sees nothing. A test whose data check matters uses a marker of at most six characters. Not a product defect.

### Code review (2026-11-21)

Each was applied on `ocupilot-b-ci` (the throwaway's copy of the port, loaded with its subclasses; the four port mutations together, each red on its own assertion), run, and reverted (the copy equal to the tree, `diff -rq` empty, reloaded, the class green again).

- mutation: AC1 stale data through the port, `PerformPmmlExport`'s extent kill before the test made never-run -> `AnalyticsPmmlExportEdge.TestAnExportOverDataAnEarlierClassLeftHoldsOnlyItsRows` red (`stale=1` beside the run's rows).
- mutation: AC3 data, `RestoreClass`'s extent kill made never-run -> `TestAStepThatFailsRestoresEverything` red on the `BCube`, `BCopy` and `Quoted` data legs (the `LongName` leg's global is hashed, so its data leg sees nothing).
- mutation: AD-59 failure lines, the script's kill of the result class's extent removed -> `TestTheScriptFormMakesTheExportAndRestoresWhenAStepFails` red on the `SLong` data leg.
- mutation: AD-59 race, the script's second ask of the cube class's names removed -> the same test red on the `SRace` leg (the script replaced the other writer's class).
- mutation: the page drops the answer of a send whose dialog was canceled -> `pmml-model-test.page.spec.ts` "keeps the line of an export applied after its dialog was canceled" red on the line; the page opens the dialog while a send is in flight -> the same test red on the reopen assertion. Each reverted byte-identical (`shasum` equal).

## Auto Run Result

Status: done
Blocking condition: none

Re-open pass (script form, U-133). `SnippetForm` answers `objectscript` for `TOCUBE`, and `AnalyticsPort.PmmlExportSnippet` renders the export's draft from the stored query and body: every name and the source are shape-checked first (`PmmlExportDraftShaped`, `PmmlDraftClassShaped`) and a failing one renders no draft; a refusal the write makes is one step that only sets the published sentence; the steps mirror `PerformPmmlExport` (free-name gate, result class, extent kill, test, copy, drop, cube class, delete of what was saved when a later step fails); the script carries two comments, one that the export cannot be undone and one that the test has no limit here. `TestTheExportHasNoScriptForm` is replaced by `TestTheScriptFormMakesTheExportAndRestoresWhenAStepFails` and `TestAHostileNameOrSourceRendersNoScript`; `DraftRegistry` gets the synthetic model id and export values. The three files written through Python in the earlier pass (`pmml-export-dialog.ts`, `AnalyticsPmmlExportEdge.cls`, `pmml-model-test.page.spec.ts`) were read line by line by both review layers and survive unchanged but for the Edge class's new tests.

Review: 11 findings, none high; 6 patched, 5 rejected (triage log, 2026-11-21). Follow-up review recommended: false.

Verification, all on a rebuilt `ocupilot-b-ci`: `AnalyticsPmmlExport` 3/3, `AnalyticsPmmlExportEdge` 11/11 and `DraftRegistry` 9/9, forward then reverse; `npm run test:tools` 2361/2361, `npm run test:components` 3727/3727, `browser/analytics.browser-spec.mjs` 20/20; `check-objectscript.py`, `lint-docs.sh` and `analytics.test.mjs` clean. Full ObjectScript sweep after the last patch: shards 1 to 17, 847 classes and 6433 tests, no red, no flake re-run. `Error.cls` is not in the diff. Mutations are in `## Verification`, each reverted byte-identical.

Residual risk: the script runs the vendor's calls in the person's own session with no bound and no audit row (stated in its comment), and a line that throws leaves the later lines unrun (the script is one statement a line).
