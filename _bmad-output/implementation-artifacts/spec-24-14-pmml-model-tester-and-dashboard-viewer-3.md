---
title: 'Story 24.14: PMML model tester and dashboard viewer (Batch 3: PMML New)'
type: 'feature'
created: '2026-11-20'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-14-pmml-model-tester-and-dashboard-viewer-2.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-11-listing-groups.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The classic `%DeepSee.PMML.UI.ModelTester` has two writes OcuPilot lacks (veto item U-120, Batch 1 Design Notes › Questions 4). **New** makes a PMML definition class from PMML text and compiles it. **Export** copies a test's results into a new class and a new cube. Batches 1 and 2 shipped the viewer and the tester, which only read.

**Approach:** This batch is **New** only. Export to cube becomes Batch 4 (Design Notes › Questions 1). New is a confirmed create with two callers, like Story 24.11's listing group add:

- the person's New dialog on PMML models;
- the agent's `analytics.pmmlmodels.add`.

It saves the class through the class-write path that Stories 24.11 and 24.12 lifted into `AnalyticsPort` (`AdmitClassWrite`, `WriteClass`, `RestoreClass`, `ClassWriteSnippet`), compiles it, and puts it back when the compile is refused. "Round-trips over its backing class" means two things here. First, the class's `PMML` XData equals the text sent. Second, PMML models lists every model `%GetModels` reports for the new class.

## Boundaries & Constraints

**Always:**

- **The class (AD-54, AD-10).** The new class is `Class <C> Extends %DeepSee.PMML.Definition [ ProcedureBlock ]`, holding one `XData PMML [ XMLNamespace = "http://www.intersystems.com/deepsee/pmml" ]` with the text. This is the shape the vendor's `CreateFromStream` makes. The body is `{Class, PMML}`. Refusals are checked in this order, before anything is saved:
  1. A class that `Prohibited.IsOcuPilotCode` names is refused 403 `PROHIBITED.OCUPILOTCODE` (`OwnCodeRefusal`).
  2. A class name `ListingClassShaped` refuses, which includes a `%` name, is refused 422 `ANALYTICS.PMML.CLASS`.
  3. A name that is held is refused 409 `ANALYTICS.PMML.TAKEN`. Held means a class `<C>` exists, or any class in package `<C>.` exists, compared without case. The second test is there because the vendor's compile deletes and regenerates `<C>.Data`, `<C>.<model>`, `<model>Input` and `<model>Output` without asking (`%DeepSee.PMML.Generator` :54-58, :546, :769, :1293). That rule also covers a name that differs from a held one only in case, so no separate ambiguity refusal exists.
- **The text is untrusted (AD-11, AD-60).** The vendor parses it, in the compile, and nothing else of OcuPilot's reads it as code. It is refused 422 `ANALYTICS.PMML.TEXT` in any of these cases:
  - it is empty;
  - it is longer than `AtelierPort.MAXIMPORTCHARACTERS` (3,000,000);
  - it holds `<!DOCTYPE` or `<!ENTITY`, compared without case. This is stricter than classic, and it keeps external-entity resolution out of the vendor's parse;
  - it holds a line whose first character, after leading blanks, is `}`, which would end the XData block (Task 0).
- **The gate (AD-8, AD-29, AD-61, AD-65).** The gate runs `AdmitNamespace`, then `AdmitClassWrite`, with:
  - `PMMLPAIRS` as the extra pairs;
  - the global `^oddDEF`, which is the routines database where class definitions are stored (Task 0);
  - 409 `ANALYTICS.PMML.READONLY` for a read-only database.
- **The write.** It runs `WriteClass` as `TYPEADD`, with `pWhat` set to `PMML definition`. A compile the instance refuses has three effects:
  - `RestoreClass` deletes the class, and also every class generated in `<C>.` if the delete leaves any (Task 0);
  - the answer is 422 `ANALYTICS.PMML.COMPILE`;
  - the vendor's compile text is logged and never shown.
- **Fresh read and read-back (AD-54, AD-58).** The new read type `PMMLDEFINITION` answers one of three things for `<C>`:
  - `{Class, PMML, Models, Namespace}` when the class exists, where `Models` is the count `%GetModels` reports;
  - 409 `ANALYTICS.PMML.TAKEN` when only its package is held;
  - 404 when both are free.

  The tool declares `READBACKFIELDS` `Class,PMML`.
- **Audit (AD-15).** The vendor records no event for a class save or compile (AD-15 named case 10). Each write that reaches the class records OcuPilot's own `ConfigChange` row through `AuditWrite`, with `{namespace, class, outcome}` and never the text. An agent write also emits its marker.
- **Script form (AD-59).** `ClassWriteSnippet` is used with a one-line free-name condition that applies rule 3. A script longer than `SNIPPETMAXCHARACTERS` answers no step, as for every class write.

**Never:**

- Calling `%DeepSee.PMML.Utils` `CreateFromFile`, `CreateFromStream` or `CreateFromString`, or `%OnSubmit`, or saving through `%Dictionary`.
- Overwriting or deleting a class the person did not name.
- An endpoint that takes a file path; the dialog reads the file in the browser.
- Export to cube (Batch 4), Update, Delete or Copy.
- A spine edit.
- Edits to `ui/angular.json` or `ui/vitest-base.config.mjs`.
- Edits to `scripts/ci-throwaway.sh` beyond add-only roster lines.

## I/O & Edge-Case Matrix

Every row runs in USER on `ocupilot-b-ci`. The test names classes `ProbePmml.New<marker>`, which is outside the `OcuPilot` names, and removes them afterwards.

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Create, both callers | The probe PMML text (two models), from `POST /analytics/pmml-models` and from a confirmed proposal | Class compiled; XData equals text; PMML models lists both models; read-back `matches`; one `ConfigChange` row each | - |
| Own code, shape | `OcuPilot.X`; `%X`; `NoPackage` | Nothing saved | 403 `PROHIBITED.OCUPILOTCODE`; 422 `ANALYTICS.PMML.CLASS` |
| Taken | An existing class; a class in `<C>.`; a case variant; a name taken between the mint and the confirm | Nothing saved or deleted | 409 `ANALYTICS.PMML.TAKEN`; the confirm closes the proposal as target-changed |
| Untrusted text | Empty; 3,000,001 characters; a `<!DOCTYPE`; a `}` line followed by a method | Nothing saved | 422 `ANALYTICS.PMML.TEXT` |
| Refused compile | Well-formed XML that is not valid PMML | No class `<C>` or `<C>.*` is left; a `ConfigChange` row with outcome `restored` | 422 `ANALYTICS.PMML.COMPILE` |
| Gate | No `%Development:USE`; no WRITE on USER's routines database; analytics off | Refused before any lookup | 403; 403; 409 `ANALYTICS.NAMESPACE` |

</intent-contract>

## Code Map

Paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-24` (HEAD `4aeeab5a4`). No file in this map is changed on `origin/OCU-1-epic21` beyond feature today. The implement stage re-runs `git log --no-merges origin/OCU-1-epic21 ^origin/feature/OCU-1_ocupilot-mvp -- <path>` and treats any hit as (contended: add-only). `Prohibited.cls` is always (contended: add-only).

**Vendor (read-only):**

- `irislib/%DeepSee/PMML/Utils.cls` `CreateFromStream` :24 (the class shape).
- `irislib/%DeepSee/PMML/UI/ModelTester.cls` New :29, :404 and `%OnSubmit` :446 (classic passes `pOverwrite` 0).
- `irislib/%DeepSee/PMML/Definition.cls` :40-110.
- The hidden `%DeepSee.PMML.Generator`, exported to `.../scratchpad/e24u/24-14/Generator.txt`. Its `%CreateClasses` :19 generates the package classes and deletes any already there.

**Server:**

- **`Port/AnalyticsPort.cls`.** Extend the listing groups' path (Rule 2), don't copy it:
  - `Serves` :723 and the `Invoke` dispatch :877/:900 gain the `PmmlModels` endpoint's `TYPEADD` and `PMMLDEFINITION`.
  - New `AdmitPmmlDefinition` delegates to `AdmitClassWrite` :5542.
  - New `PlanPmmlDefinition` makes the refusals and composes the class text. It returns `tPlan` with the keys `class`, `text`, `prior` (empty), `version` (empty) and `compiled` (0), as `PlanListingGroup` :6076-6101 does.
  - New `PerformPmmlDefinition` calls `WriteClass` :6175, then `AuditWrite` :3272, as :6142 does.
  - New `PmmlDefinitionSnippet` calls `ClassWriteSnippet` :6239 and joins `Snippet`'s `$Select` :3313.
  - `RestoreClass` :6210 gains an optional package sweep. It is a parameter, not a copy, and runs only if Task 0 shows the delete leaves generated classes.
  - Also reuse `ListingClassShaped` :5676, `OwnCodeRefusal` :6030 and `DestinationDatabase`.
- **`Api/AnalyticsError.cls`:** the codes `PMML{CLASS,TAKEN,TEXT,COMPILE,READONLY,SAVE}`, their reasons, `ReasonFor`, the roster and `PmmlCodes()`.
- **`Screen/Tool/AnalyticsPmmlModelAdd.cls` (new):** it extends `AnalyticsListingGroupAction` as `AnalyticsQualityMeasureAction` does, with no intermediate class, since this is the only PMML write.
  - `CREATES` 1, `WRITETYPE` `ADD`, `SENDSBODY` 1, `FIELDS` `Class,PMML`, `READTYPE` `PMMLDEFINITION`, `READBACKFIELDS` `Class,PMML` and no `READBACKTOOL`.
  - `DESTINATIONGLOBAL` `^oddDEF`, `DESCRIPTORCLASS` `AnalyticsPmmlModelList`, `CLASSICPAGES` `%DeepSee.PMML.UI.ModelTester`.
  - `IdArgument` `Class`, `EditPairs` returning `PMMLPAIRS`, `VIOLATIONSMETHOD` and `PROBLEMMETHOD` naming the port's new pair, `CONSEQUENCECODE` `ANALYTICS.PMML.SAVE`, and the `PRECONDITIONCODES`.
- **`Area/Analytics/PmmlDefinitionSave.cls` (new):** it extends `ListingGroupSave`, as `QualityMeasureSave` does, with `CREATETOOL`, `DESCRIPTORCLASS`, `TAKENCODE`, `TAKENREASON` and `VIOLATIONSMETHOD`. Its route `POST /analytics/pmml-models` goes in `Api/Router.cls` beside :289 and :2044.
- **`Screen/Descriptor/AnalyticsPmmlModelList.cls`:**
  - `primaryAction` `{"id":"add"}`;
  - `secondaryEntityTypes` `["pmml-definition"]`;
  - `emptyAgentKey`;
  - the doc comment's "offers no action" corrected.
- **`Kernel/EntityType.cls`:** `pmml-definition`, keyed by the class name kept exactly (contended: add-only).
- **`Kernel/Proposal/Prohibited.cls`** (contended: add-only):
  - `TYPEPMMLDEFINITION` and a `COVEREDTYPES` entry;
  - a `PermittedCreateFields` line `Class,PMML` beside :1589;
  - **widen `IsQualityMeasureType`'s body** (:1291) and its doc line to include it, so the type takes the class-backed branches :1684, :1888 and :2116 with no added condition term.
- **`Kernel/Governance/Baseline.cls`:** `analytics.pmmlmodels.add`, in the state ruled under Questions 2.

**Client (`ui/src/app/`):**

- New `areas/analytics/pmml-model-list.page.ts`, modeled on `quality-measure-list.page.ts`, with `pmml-definition-dialog.ts`, modeled on `quality-measure-dialog.ts`. The dialog has a Class field, a PMML text area and "Load from file", the existing `x509LoadFromFile`. "Load from file" reads a `.xml` or `.pmml` file into the text area as `x509-form.page.ts` `pickFile` does.
- A store, `pmml-model.store.ts`, modeled on `quality-measure.store.ts`.
- `shell/screen-outlet.ts` gets `DESCRIPTOR_PAGES` for the list, and `shell/screen-action-handler.ts` gets the registration beside :163.
- `core/strings.ts` gets the strings once ruled. `core/screens.generated.ts` and `Screen/Titles.cls` are regenerated.

**Tests:**

- **`Test/PmmlProbe.cls`:** `CreatedText()` returns the probe text (two models), and `Gone()` also requires no `ProbePmml.New*` class.
- **New `Test/AnalyticsPmmlCreate.cls`:** both callers and their round trip. It counts audit rows with `InteropQueueActions` `Count` :196 and `Added` :203 from `AuditEvent.Now()`, and covers the script form, run after the name is taken, which changes nothing.
- **New `Test/AnalyticsPmmlCreateEdge.cls`:** the refusals and the restore, using the real compiler on invalid PMML, plus the gate as principals and the confirm closed as target-changed.
- Both new test classes declare `DependsOn = OcuPilot.Test.PmmlProbe` and are armed beside `scripts/ci-throwaway.sh` :659 and in `ui/tools/ci.test.mjs` (add-only).
- **Rosters (Rule 30).** Re-grep `analytics.qualitymeasures.add`, `AnalyticsQualityMeasureAdd`, `quality-measures` (route) and `pmml-model`. Expect hits in:
  - `Test/{SurfaceCoverage,EndpointCoverage,ToolRoundTrip,StageTwoTools,Descriptor,GovernanceBaseline,Governance,SaveHoldCoverage,DeveloperFloorRoutes,PortGate,AnalyticsDescriptor}.cls`;
  - `ui/tools/{screen-mirror,navigation,analytics}.test.mjs`.

  `analytics.test.mjs` forbids the three `CreateFrom*` calls.
- **Component and browser tests:** `pmml-model-list.page.spec.ts`, and a Batch 3 test in `ui/browser/analytics.browser-spec.mjs`.
- **EXPERIENCE.md:** one Fixed strings row.

## Tasks & Acceptance

**Execution:**

- [ ] **Task 0** (`ocupilot-b-ci`, USER, every probe class removed afterwards). Record each answer under Design Notes › Measured:
  1. Whether a text holding a line `}` followed by a `ClassMethod`, saved through `SourceDocument.Save`, adds a member, and whether any other shape (a `}` inside a line, unbalanced `{`) does.
  2. The generated class names after the probe compiles.
  3. What is left after a refused compile and `RestoreClass`'s delete.
  4. Whether deleting `<C>` deletes the classes it generated.
  5. `Save`'s answer for a case variant of an existing class.
  6. That `DestinationDatabase(USER, "^oddDEF")` names the routines database.
  7. That with auditing on the save and compile record no vendor event.
  8. That the XData round-trips byte for byte, apart from line endings.

  HALT if any shape other than the guard's `}` line changes the class's members, or if a refused compile leaves a class that no sweep of `<C>.` removes.
- [ ] `AnalyticsPort.cls`, `AnalyticsError.cls`, `Prohibited.cls`, `EntityType.cls`, `Baseline.cls`, the tool, the save class and the route.
- [ ] The descriptor, the client page, dialog and store, the outlet and handler, the strings (once ruled), the regenerated mirror and titles, and the EXPERIENCE.md row.
- [ ] Tests: the matrix in the two new classes, the probe change, the component and browser tests, and every roster.

**Acceptance Criteria:**

- **AC1 (round trip, both callers; Integration, Rule 1).**
  - **Given** the probe text,
  - **When** a person creates `ProbePmml.New<m>` from New, and the agent proposes the same for another marker and the person confirms,
  - **Then** each class compiles, its `PMML` XData equals the text, PMML models lists each model `%GetModels` reports for it, and each read-back reads `matches`.
- **AC2 (names).**
  - **Given** an OcuPilot class name, a `%` name, a held class, a held package or a case variant,
  - **When** either caller creates it,
  - **Then** it is refused with the matrix's code and nothing is saved or deleted.
- **AC3 (untrusted text).**
  - **Given** an empty text, an oversized text, a document type declaration or a block-ending line,
  - **When** either caller sends it,
  - **Then** it is refused 422 `ANALYTICS.PMML.TEXT` before anything is saved.
- **AC4 (refused compile).**
  - **Given** a text the compile refuses,
  - **When** either caller creates it,
  - **Then** the answer is 422 `ANALYTICS.PMML.COMPILE`, and no class named `<C>` or in `<C>.` remains.
- **AC5 (governance, audit, script).**
  - **Given** a confirmed agent create and a screen create,
  - **When** each reads OK,
  - **Then** each adds one `ConfigChange` row, the agent's also carries its marker, the baseline holds the key in its ruled state, and the script form makes the same class, and, run once the name is taken, changes nothing.
- **AC6 (browser).**
  - **Given** PMML models in USER,
  - **When** a person opens New, loads the probe text, enters a class and confirms,
  - **Then** the list shows its two models and the screen passes `structural`.
- **AC7 (fresh, either order).**
  - **Given** any new or changed test, run first on a fresh instance in either order,
  - **When** it ends,
  - **Then** `PmmlProbe.Gone()` is true.

## Spec Change Log

- 2026-11-20, spec gate (runner, veto item U-125): Questions 1-4 ruled as recommended: this spec is Batch 3 (New); Export to cube is Batch 4 inside Story 24.14 (its own test inside the confirmed write, rows copied before Batch 2's drop); `analytics.pmmlmodels.add` ships `true`; the stricter name and text refusals; the proposed strings; the AD-65/AD-22 lines left proposed.

## Review Triage Log

## Design Notes

**Questions for the runner (intent gap; veto item U-120 continues).**

1. **The batch boundary (Rule 5 tier 2): split Export to cube into a Batch 4.** Recommended. Export is a second write of at least this batch's size:
   - it creates and compiles two classes (a `%Persistent` result class and a cube class whose `buildRestriction` names one test id);
   - it copies that test's rows;
   - it leaves a cube that is unbuilt until Cubes' Build runs.

   It also needs a decision this batch does not. Its rows come from a test, and Batch 2 drops every test's rows on every path (Batch 2 AC3).
   - **Recommended for Batch 4:** the write runs its own test of the chosen source inside the confirm request through `PmmlRun`, copies the rows bound to that id, then drops them. It refuses held names, as here, with no Overwrite.
   - **Alternative:** keep a run's rows while its record is kept (15 minutes). That weakens Batch 2's guarantee, so it needs a veto.
   - **Owner-only either way:** the classic's "data only" (which can erase a class's rows), "Overwrite classes" and the iKnow measure. Recommended: leave them out with an exclusion-register row each. That drops scope.
2. **The key `analytics.pmmlmodels.add` (veto).**
   - **Recommended: `true`.** It creates new code as `explorer.classes.create` and `analytics.listinggroups.add` do (both `true`). It refuses every held name, runs nothing but the vendor's compile, and the models it generates run only when a person tests them.
   - **Alternative: `false`,** as `explorer.classes.import` ships, since the text is outside material.
3. **Stricter than classic (veto).** A held package, a document type declaration and a block-ending line are refused. Classic refuses only a held class (`pOverwrite` 0) and validates nothing else.
4. **Proposed strings (veto; none in EXPERIENCE.md).**
   - **Labels:** "New PMML definition" (action and dialog title) · "PMML" (text area). Reused: Class, "Load from file", Cancel.
   - **Consequence (SAVE):** "The class is saved and compiled, and the classes it generates are made in its package."
   - **Reasons:**
     - CLASS reuses the listing groups' sentence.
     - TAKEN: "This namespace already holds this class, or classes in its package."
     - TEXT: "Paste one PMML document of at most 3,000,000 characters, with no document type declaration and no line that starts with }."
     - COMPILE: "The instance refused to compile the PMML definition, so nothing was changed."
     - READONLY: "The database that holds this namespace's classes is read-only."
   - **Agent phrase:** "create a PMML definition".

**Proposed spine lines (the owner's attended update; never written here).**

- **AD-65:** "PMML New (Story 24.14) saves and compiles a `%DeepSee.PMML.Definition` class from a person's or the agent's PMML text through the class-write path. The class and its package must be free, because the vendor's compile replaces the classes it generates there. The text is refused with a document type declaration or a line that would end its XData block."
- **AD-22:** the key's ruled state.

**Decided in-stage (plan).**

1. **Target type `pmml-definition`.** The create makes a class, not a model, so the composite `pmml-model` id does not name it.
2. **Saved through `AtelierPort`,** not the vendor's `CreateFromString`, so the routines-database check and the restore are the class-write path's. The vendor's `%Dictionary` save is what the guard in Always replaces.
3. **No new numbers:** the text bound is `MAXIMPORTCHARACTERS`.

**Governing ADs (Rule 6):** AD-3, AD-6, AD-8, AD-10, AD-11, AD-13, AD-14, AD-15, AD-16, AD-22, AD-29, AD-34, AD-36, AD-44, AD-53, AD-54, AD-55, AD-58, AD-59, AD-60, AD-61, AD-65.

**Integration and linkage (Rules 1, 2).**

- **Consumes:** the class-write path, `ListingGroupSave`/`ItemSave`, `AnalyticsListingGroupAction`, the PMML reads (Batch 2) and `PmmlProbe`.
- **Consumed-by:** Batch 4 reuses the free-name rule and the restore.
- AC1 is the Integration AC.

**Ledger inbox (Rule 17):** none.

## Verification

**Commands** (one `ci-runner` call per message; `ocupilot-b-ci` only):

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.AnalyticsPmmlCreate`, then the same for `AnalyticsPmmlCreateEdge`, `AnalyticsPmmlModels` and every class the roster sweep changes. Expected: green, each new class on its first run.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`. Expected: green.
- `(loop)` `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/analytics.browser-spec.mjs`. Expected: green.
- `(once)` The same environment for `browser/a11y-structural-invariants.browser-spec.mjs`. Expected: green.
- `(once)` The full ObjectScript sweep: `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17` for k = 1 to 17, one call each. Expected: green.
- `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh`. Expected: clean. The full browser suite is left to CI.

**Shared surfaces:** PMML models' actions and empty state, the entity-type vocabulary, the write-tool, coverage, endpoint and route rosters, the governance baseline, the prohibited set's covered types, `screen-mirror.test.mjs`, the `analytics.test.mjs` guard and the arming roster.

**Hermeticity:** every test added or changed passes on its first run on a fresh instance, in either order, and removes every `ProbePmml.New*` class it makes.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none (intent gap ruled at the spec gate, U-125)
