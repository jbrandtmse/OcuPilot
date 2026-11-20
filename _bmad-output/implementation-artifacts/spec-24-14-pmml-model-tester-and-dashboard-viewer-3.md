---
title: 'Story 24.14: PMML model tester and dashboard viewer (Batch 3: PMML New)'
type: 'feature'
created: '2026-11-20'
status: 'done'
baseline_revision: '7b934c53235dba93410ef9f0f6aea0f333b3c48f'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-14-pmml-model-tester-and-dashboard-viewer-2.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-11-listing-groups.md'
warnings: ['oversized']
deferred:
  - 'low: the mint absence read (PMMLDEFINITION with action ADD, ChangesPmmlDefinition) is write-gated but no test arms the database seam on it; the confirm write is gated and pinned, so only the early mint refusal is unpinned'
  - 'low: Rule 2 near-copies left as found: PmmlDefinitionProblem beside ListingGroupProblem and QualityMeasureProblem, the copy-the-body-and-set-Class lines (four sites), and the dialog FileReader block copied from x509-form.page.ts'
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
  - it holds a `}` character anywhere, since an unmatched `}` ends the XData block and what follows is read as class members (Task 0, items 1 and 2).
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
| Untrusted text | Empty; 3,000,001 characters; a `<!DOCTYPE`; a `}` at a line's start, at a line's end, before a member keyword, or inside an element, each followed by a method | Nothing saved | 422 `ANALYTICS.PMML.TEXT` |
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
  - a new pure `IsPmmlDefinitionType(pType)` predicate; `IsQualityMeasureType`'s body and doc line stay exactly as they are. Each of the three call sites that predicate gates (:1684, :1888, :2116) gets one appended term, `|| ..IsPmmlDefinitionType(tType)` (or `'..IsPmmlDefinitionType(tType) && ` where the site is in the `'..Is...Type(tType) &&` form), and nothing else in those conditions changes. Review confirms by word-diff against the file at the start of this batch that the only removal is the `COVEREDTYPES` string.
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

- [x] **Task 0** (done; Design Notes › Measured; `ocupilot-b-ci`, USER, every probe class removed afterwards). Record each answer under Design Notes › Measured:
  1. Whether a text holding a line `}` followed by a `ClassMethod`, saved through `SourceDocument.Save`, adds a member, and whether any other shape (a `}` inside a line, unbalanced `{`) does.
  2. The generated class names after the probe compiles.
  3. What is left after a refused compile and `RestoreClass`'s delete.
  4. Whether deleting `<C>` deletes the classes it generated.
  5. `Save`'s answer for a case variant of an existing class.
  6. That `DestinationDatabase(USER, "^oddDEF")` names the routines database.
  7. That with auditing on the save and compile record no vendor event.
  8. That the XData round-trips byte for byte, apart from line endings.

  HALT if any shape other than the guard's `}` line changes the class's members, or if a refused compile leaves a class that no sweep of `<C>.` removes.
- [x] `AnalyticsPort.cls`, `AnalyticsError.cls`, `Prohibited.cls`, `EntityType.cls`, `Baseline.cls`, the tool, the save class and the route.
- [x] The descriptor, the client page, dialog and store, the outlet and handler, the strings (once ruled), the regenerated mirror and titles, and the EXPERIENCE.md row.
- [x] Tests: the matrix in the two new classes, the probe change, the component and browser tests, and every roster.
- [x] **Text-guard pins (orchestrator conditions on U-127; review confirms both).** `AnalyticsPmmlCreateEdge` submits each Task 0 shape through both callers' shared path and asserts 422 `ANALYTICS.PMML.TEXT` before anything is written or compiled, then that class `<C>` and package `<C>.` do not exist: the plain line-start `}`; `}` at a line's end after text; `}` before a member keyword on the same line; and, for each of NBSP `$Char(160)`, VT `$Char(11)`, FF `$Char(12)`, ZWSP `$Char(8203)`, BOM `$Char(65279)`, CR `$Char(13)`, NEL `$Char(133)`, LS `$Char(8232)`, that character before a line-start `}`. A lone `{` with no `}` is submitted too: it is not refused as TEXT, the compile is refused (422 `ANALYTICS.PMML.COMPILE`), and no class `<C>` and no package `<C>.` remain. Each pinning test gets its `mutation:` line.

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
  - **Given** an empty text, an oversized text, a document type declaration or a `}` character,
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

- 2026-11-20, implement Task 0 intent gap ruled (runner, veto item U-127): the text guard refuses any `}` anywhere in the PMML text (422 `ANALYTICS.PMML.TEXT`), replacing "a line whose first character is `}`"; the TEXT reason string is "Paste one PMML document of at most 3,000,000 characters, with no document type declaration and no } character." The implement stage applies this to Always, the I/O matrix, AC3 and the TEXT reason row in the same pass (Rule 5, apply and record).

- 2026-11-20, spec gate (runner, veto item U-125): Questions 1-4 ruled as recommended: this spec is Batch 3 (New); Export to cube is Batch 4 inside Story 24.14 (its own test inside the confirmed write, rows copied before Batch 2's drop); `analytics.pmmlmodels.add` ships `true`; the stricter name and text refusals; the proposed strings; the AD-65/AD-22 lines left proposed.

- 2026-11-20, implement stage: orchestrator ruling: separate predicate IsPmmlDefinitionType, one appended term at each of the three call sites (replaces the Code Map's widening of `IsQualityMeasureType`).

## Review Triage Log

### 2026-11-20 — Review pass

- verdicts: 16 findings — high 0, medium 4, low 8, false 4, maybe-false 0
- findings:
  - `[medium]` `patch` The "no class, no package" legs read a failed lookup as free (`CountOf` caught to 0, no positive control) — `CountOf` answers -1 on failure, `Free` needs both lookups to read 0, `Snapshot`'s failure text differs per call, and the held-class test asserts the lookups read a held class, a held package and a free name; mutation recorded.
  - `[medium]` `patch` `ANALYTICS.PMML.READONLY` has no runtime test — `AnalyticsListingGroupDatabaseSeam` gains a `pmmldatabase` arm and `AnalyticsPmmlCreateEdge` a read-only and unmounted leg; mutation recorded.
  - `[low]` `patch` The `ANALYTICS.PMML.TAKEN` sentence is never asserted — the held-name route legs now compare the published sentence; mutation recorded.
  - `[medium]` `patch` The lone `{` leg (binding condition 2) is also unclosed XML, so it does not isolate the `{` — the leg now inserts the `{` at a line's end of the probe text, and a control of the unchanged text compiles; mutation recorded.
  - `[low]` `patch` AC7 has no `mutation:` line — written (the after-all removal removed, class-level error observed).
  - `[low]` `reject` `analytics.test.mjs` pins source text of the guard — it is the spec's own guard against the vendor's `CreateFrom*` calls and claims nothing about the guard's behavior, which the Edge tests pin.
  - `[low]` `patch` The component spec waits a fixed 20 ms for the file reader — it polls the field, bounded.
  - `[low]` `reject` The browser spec starts by asserting `PmmlProbe.Left()` is empty — a failed precondition fails loudly and the test removes its own class.
  - `[low]` `reject` The agent's mint reports malformed names and texts as `TOOL.ARGUMENTS` — the mint's problem method is how every class-write tool refuses at the mint; the port and route legs assert the codes.
  - `[false]` `reject` The refusal order is not exercised with two refusals at once — each refusal is its own guard in the spec's order; no state is reachable that one test could not show with one input.
  - `[low]` `reject` The round trip reads through the port and ignores line endings — Task 0 item 9 rules the equality as modulo carriage returns, and the browser spec reads the compiled class.
  - `[false]` `reject` The list is read at two layers and the component spec stubs the API — descriptive; each layer is pinned by its own test.
  - `[low]` `reject` The browser spec's text differs from the probe text — the same two models; the spec asserts both rows.
  - `[medium]` `reject` The create's target type is `pmml-model`, not the plan's `pmml-definition` — recorded as Decided in-stage 1 (a write tool's target type is its descriptor's primary entity type); both types are covered and the audit entity is `pmml-definition`.
  - `[false]` `reject` The free checks are SQL over `%Dictionary` only — the class catalog is what a class and its package are; a delete removes the compiled remnants with the class.
  - `[false]` `reject` The new test classes need an arming roster line — they inherit the declaring class's variable, which the roster lists; `ci.test.mjs` passes.

### 2026-11-20 — Follow-up review (Batch 3 implement + QA; four layers)

- verdicts: 38 findings after folding duplicate sightings across layers — high 0, medium 3, low 35; patch 13, defer 2, reject 23, intent_gap 0
- findings:
  - `[medium]` `patch` A text in the last ~200 characters of the bound passed the guard and failed the save 400 `EXPLORER.SAVE.TOOLARGE` — `PlanPmmlDefinition` refuses a class text over `MAXIMPORTCHARACTERS` as 422 TEXT with the ruled sentence, before any lookup, for every caller; Gap pins the exact bound; mutation recorded.
  - `[low]` `reject` The ruled TEXT sentence and the tool description say "at most 3,000,000" though the class text's wrapper makes the last ~200 characters refused — orchestrator ruling: reuse the ruled sentence; a precise one is a new string.
  - `[low]` `patch` `PerformPmmlDefinition`'s doc and Measured 5's heading said a refused compile generates nothing — both now say deleting `<C>` removes what any compile generated (Gap's two-model test).
  - `[low]` `patch` The script's free-name lookup read a failed query as free — it starts at held and reads the count only on `%SQLCODE` 0; mutation recorded.
  - `[low]` `patch` A long text dense with control characters raised `<MAXSTRING>` composing the script, failing the copy-out draft — a text over `SNIPPETMAXCHARACTERS` answers no step first; mutation recorded.
  - `[medium]` `patch` Every held-class leg also held a package, so the class test was unpinned and the doc's case mutation could not redden — Edge adds a class held alone and its case variant; mutation recorded.
  - `[medium]` `patch` The own and malformed names were outside `Snapshot` — Edge asserts `Free` for each.
  - `[low]` `patch` `Snapshot` read a failed query as empty — it answers a per-call value.
  - `[low]` `patch` The gate's "before any lookup" used a free name only — the legs repeat on a held class.
  - `[low]` `defer` The mint's write-gated absence read has no database-seam test (frontmatter).
  - `[low]` `reject` The oversized text skips the route — the bound test posts a 3,000,000-character text through the route and the mint.
  - `[low]` `patch` Gap's carriage-return precondition could not fail — it counts pairs and a lone carriage return.
  - `[low]` `patch` Gap's two mutation notes disagreed with `## Verification` — aligned.
  - `[low]` `patch` The tool's doc said its fresh read carries no action — it states `PortQuery`'s two reads.
  - `[low]` `patch` The descriptor's doc read "It It writes" — fixed.
  - `[low]` `patch` The EXPERIENCE.md row said an OcuPilot name gets the CLASS sentence — it gets the own-code refusal; the row says so.
  - `[low]` `reject` `pmml-model` targets carry a one-part id against a composite key, and the predicate covers later `pmml-model` writes — Decided in-stage 1; the add is the only such write.
  - `[low]` `reject` The store's change event is `pmml-definition` while the proposal's is `pmml-model` — the list follows both; the audit entity is one.
  - `[low]` `defer` Rule 2 near-copies (Problem methods, body-copy lines, FileReader block) — `TextNormalized` now reuses `PmmlLineFeeds`; the rest in frontmatter.
  - `[low]` `reject` The mint answers `TOOL.ARGUMENTS` — ruled in the first pass.
  - `[low]` `reject` The route answers TAKEN before TEXT for a held name with a bad text — the route's absence read is the save's fresh read (Decided in-stage 2).
  - `[low]` `reject` AC1's models are compared with `CREATEDMODELS` — the read leg asserts `%GetModels`' count of 2.
  - `[low]` `reject` A package held after the mint is untested — the confirm closes any non-404 re-read (inference); the class leg pins the branch.
  - `[low]` `reject` Teardown misses classes only a mutation could make — the new `Free` legs report them.
  - `[low]` `reject` No text with an XML declaration — the text is kept verbatim as classic does; measured: the vendor's own `CreateFromStream` refuses a UTF-8-declared text with a non-ASCII character too.
  - `[low]` `reject` `^oddDEF` routines-versus-globals measured only in USER (inference) — the shared class-write path of 24.11 and 24.12.
  - `[low]` `reject` The Auto Run Result predates QA, and Decided in-stage numbering is out of order — oversized spec; QA's record is under Verification.
  - `[low]` `reject` The spec is done while Batch 2's cancel run was red — out of scope (Batch 2 rework).
  - `[low]` `reject` A class created inside another definition's generated package — the generator replaces only names it generates; theoretical.
  - `[low]` `reject` A package mapped to another database is gated on the wrong one — the save still refuses with its own code; shared path.
  - `[low]` `reject` `restorefailed` answers COMPILE — the siblings' form, logged for an operator.
  - `[low]` `reject` A held class whose XData passes the maximum string answers 500 — theoretical.
  - `[low]` `reject` A whitespace-only text answers COMPILE, not TEXT — the spec refuses an empty text; the compile refuses and restores.
  - `[low]` `reject` Concurrent case-variant or nested creates — the vendor refuses a case variant 409 (Measured 6); nested is theoretical.
  - `[low]` `reject` A throw in the plan reads as no problem at the mint — the siblings' form; the confirm re-plans.
  - `[low]` `reject` A schema without `Class` or `PMML` — the fields are declared; theoretical.
  - `[low]` `reject` The dialog's FileReader has no error handler — the sibling's form; a message would be a new string.
  - `[low]` `reject` The predicate is used at a fourth site — the Code Map's `PermittedCreateFields` line; the word-diff shows only the three appended terms in conditions.

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
3. **Stricter than classic (veto).** A held package, a document type declaration and a `}` character are refused. Classic refuses only a held class (`pOverwrite` 0) and validates nothing else.
4. **Proposed strings (veto; none in EXPERIENCE.md).**
   - **Labels:** "New PMML definition" (action and dialog title) · "PMML" (text area). Reused: Class, "Load from file", Cancel.
   - **Consequence (SAVE):** "The class is saved and compiled, and the classes it generates are made in its package."
   - **Reasons:**
     - CLASS reuses the listing groups' sentence.
     - TAKEN: "This namespace already holds this class, or classes in its package."
     - TEXT: "Paste one PMML document of at most 3,000,000 characters, with no document type declaration and no } character."
     - COMPILE: "The instance refused to compile the PMML definition, so nothing was changed."
     - READONLY: "The database that holds this namespace's classes is read-only."
   - **Agent phrase:** "create a PMML definition".

**Proposed spine lines (the owner's attended update; never written here).**

- **AD-65:** "PMML New (Story 24.14) saves and compiles a `%DeepSee.PMML.Definition` class from a person's or the agent's PMML text through the class-write path. The class and its package must be free, because the vendor's compile replaces the classes it generates there. The text is refused with a document type declaration or a `}` character."
- **AD-22:** the key's ruled state.

**Decided in-stage (plan).**

1. **Target type `pmml-definition`.** The create makes a class, not a model, so the composite `pmml-model` id does not name it.
2. **Saved through `AtelierPort`,** not the vendor's `CreateFromString`, so the routines-database check and the restore are the class-write path's. The vendor's `%Dictionary` save is what the guard in Always replaces.
3. **No new numbers:** the text bound is `MAXIMPORTCHARACTERS`.

**Measured (Task 0, implement, 2026-11-20, `ocupilot-b-ci`, USER; every probe class removed after, `ProbePmml.%` and the scratch package empty).** The save is `SourceDocument.Save` over `AtelierPort`, the compile `SourceDocument.Compile`, the text `ClassText`'s form (`Class C Extends %DeepSee.PMML.Definition [ ProcedureBlock ]`, one `PMML` XData).

1. **The guard's `}` line is not the only shape that adds a member (contradicts the plan; HALT).** A `}` ends the XData block, and the text after it is read as class members, when it is unmatched by a `{` and:
   - starts a line, after any of space, tab, `$Char(160)`, `$Char(12)`, `$Char(11)`, `$Char(8203)`, `$Char(65279)`, or after `$Char(13)`, `$Char(133)` or `$Char(8232)` read as line breaks;
   - ends a line after text (`x}` or `x }` then a `ClassMethod` line, or `<x>}`);
   - or is followed on its line by a member keyword (`a} ClassMethod Evil() ...`).

   Each of those added a `ClassMethod` (and a second `XData`) to the saved class. A `}` that is not at either edge and not before a keyword adds nothing: `x}y`, `x }y`, `x} y`, `x}<y>`, `<b>}</b>`, `x}}y`; neither does a `}` inside an attribute quoted with `'` or `"`, a comment or a CDATA section, nor a `}` balanced by an earlier unquoted `{` (`<b>{` ... `<c>}`). So the vendor's rule is not positional, and no line-start test is sufficient.
2. **An unbalanced `{`** (`{` at a line's end, with no `}`) adds no member: the class is not parsable, the XData is not kept (xdatas 0) and the compile is refused (`ERROR #5559`). A `{` inside a quoted attribute changes nothing.
3. **Generated classes after a valid two-model compile** (`ProbePmml.NewT2`): `<C>.Data`, and for each model `<C>.<model>`, `<C>.<model>Input` and `<C>.<model>Output`, seven in all, every one in package `<C>.`.
4. **Deleting `<C>`** (`SourceDocument.Remove`) deleted all seven generated classes; the namespace's class list then differed from the start only by an SQL cached-query class the probe's own query made.
5. **Deleting `<C>` after a refused compile leaves nothing.** An unknown field (`Nope`), an unexpected tag (`<Bogus/>`), and a second model that fails after a valid first each left only the saved class, and `RestoreClass`'s delete removed it; a package sweep of `<C>.` afterwards found nothing. No sweep is needed.
6. **A case variant of an existing class**, saved as a create: 409 `EXPLORER.DOCUMENT.CONFLICT`, nothing saved, the original intact.
7. **`DestinationDatabase("USER", "^oddDEF")`** answers resource `%DB_USER`, read-write, mounted; `Config.Namespaces` names USER's routines database `USER`. The same call for `^DeepSee.ListingGroups` and `^DeepSee.QMsrs` names `%DB_USER`.
8. **With auditing enabled** (`Security.System` `AuditEnabled` 1), a save, a compile and a delete wrote no `%SYS.Audit` row after the mark.
9. **The XData round-trips** apart from line endings: the stored text equals the sent text once carriage returns are removed (1,084 characters sent, 1,100 stored, a carriage return per line), including tabs, a trailing line feed and `$Char(233)`; the compiled XData equals it too. The text's own trailing line feed is kept only if the composer keeps it (`ClassText.Body` strips it), so the read-back compares with both ends trimmed of line breaks.

**Ruled (U-127).** A text that holds a `}` anywhere is refused 422 `ANALYTICS.PMML.TEXT`. A `{` needs no refusal, since without a `}` the class cannot be balanced and the compile is refused (item 2). The cost is that a document whose quoted attribute holds a `}` is refused; the vendor's own `CreateFromString` has no such limit, because it saves through `%Dictionary`.

**Decided in-stage (implement).**

1. **The create's proposal target is the screen's own type.** A write tool's target type is its descriptor's primary entity type, so the add's target is `pmml-model` with the class as its id; `Prohibited.IsPmmlDefinitionType` answers true for `pmml-definition` and `pmml-model`, and both are covered types. `pmml-definition` names the audit row's entity and is the list's secondary type.
2. **The fresh read carries the add's action only before the payload is composed.** The mint's and the save's absence read (arguments with no namespace) asks `ACTION=ADD`: a held class or package is 409 `ANALYTICS.PMML.TAKEN`, a free name 404. The composed payload's read, the confirm's re-read and the read-back carry no action and answer a held class as its row, so no `READBACKTOOL` is declared and the read-back compares `Class` and `PMML`.
3. **The read refuses a class of OcuPilot's own, 403,** so the agent's mint is refused 403 as the person's route is.
4. **`RestoreClass` gains no package sweep:** Task 0 item 5 shows a refused compile leaves only `<C>`, and deleting `<C>` deletes what its compile generated.
5. **Line endings:** the tool's `ComposeCreate` and the port's plan turn carriage returns into line feeds, so the payload both callers send is the text the class stores.
7. **Rosters the full sweep found:** `ToolWrite`'s other-port count 144 to 145 (contended: Epic 21 also edits that file's count), and a `ToolEmit` branch for the create's pairs (WRITE on the database `^oddDEF` maps to, READ on the routines database, `PMMLPAIRS`, the source code API's pairs and its write pairs).
6. **Arming:** both new test classes extend `AnalyticsListingGroupBase`, which declares `OCUPILOT_ALLOW_PRINCIPALS`; the arming rosters list declaring classes only, so no roster line was added.

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

**Mutations (Rule 19; each applied on `ocupilot-b-ci`, the class reloaded and compiled with its subclasses, observed red, reverted byte-identical, reloaded):**

- `mutation: PmmlDefinitionRow answers an empty PMML -> AnalyticsPmmlCreate.TestADefinitionIsCreatedByEachCallerAndReadsBack red (read-back, XData and agent-record legs); AnalyticsPmmlCreateEdge.TestAHeldClassOrPackageIsRefusedAndNothingIsTouched row leg red` (AC1).
- `mutation: PlanPmmlDefinition without the own-code test -> TestAnOwnClassAndAMalformedNameAreRefused red (the port leg of AssertOwnCodeRefused)`; `mutation: ListingClassShaped accepts a leading % -> the same test red (port, route and mint legs of the % name)` (AC2).
- `mutation: PlanPmmlDefinition without the held-package test -> TestAHeldClassOrPackageIsRefusedAndNothingIsTouched red (the package's port leg, the snapshot leg)`; `mutation: the read answers 404 for a held class -> TestANameTakenAfterTheMintClosesTheProposal and the held-mint legs red` (AC2).
- `mutation: PmmlTextRefused tests }}} in place of } -> TestEachShapeOfABraceIsRefusedBeforeAnythingIsSaved red in every shape and in the route and mint legs; tests <!DOCTYPX -> the lower-case document type legs of TestAnUntrustedTextIsRefusedBeforeAnythingIsSaved red; bound plus one -> its oversized leg red`; `mutation: PmmlTextRefused refuses only a } after a line feed -> every shape but the line-start one red (line end, line end after a space, before a member keyword, inside an attribute, and the eight characters)` (AC3, the text-guard pins).
- `mutation: RestoreClass quits at its first line -> TestARefusedCompileLeavesNothingAndRecordsItsOutcome red (the no-class and snapshot legs)` (AC4).
- `mutation: the baseline's analytics.pmmlmodels.add false -> TestTheBaselineShipsTheCreateOn red and every agent confirm answers GOVERNANCE.DISABLED`; `mutation: the script's free-name condition is 1 -> TestTheScriptFormMakesTheClassAndChangesNothingOnceTheNameIsTaken red (run-again leg)`; `mutation: AdmitPmmlDefinition admits every caller -> TestTheCreateIsRefusedWithoutItsPairsOrItsDatabase red (the routines database leg)`; `mutation: PMMLPAIRS without %Development:USE -> the same test red (the %Development:USE leg)` (AC5).
- `mutation: the free-name lookup CountOf answers 0 for every query -> TestAHeldClassOrPackageIsRefusedAndNothingIsTouched red (the held-class and held-package positive controls); CountOf fails with -1, which Free never reads as free` (AC3 and AC4's "nothing remains" legs).
- `mutation: PmmlTextRefused also refuses { -> TestARefusedCompileLeavesNothingAndRecordsItsOutcome red (the lone { leg answers 422 ANALYTICS.PMML.TEXT, not COMPILE); the leg's control text without the { compiles` (AC3 and AC4, binding condition 2).
- `mutation: ReasonFor answers an empty sentence for ANALYTICS.PMML.TAKEN -> TestAHeldClassOrPackageIsRefusedAndNothingIsTouched red (every held-name route leg)`; `mutation: AdmitPmmlDefinition passes the quality measures' read-only code -> TestADatabaseThatIsReadOnlyOrNotMountedRefusesTheCreate red (both modes)` (AC5).
- `mutation: OnAfterAllTests and RemoveFixtures of AnalyticsPmmlCreateBase remove nothing -> every test of AnalyticsPmmlCreateEdge still passes, and the class is red with a class-level OnAfterAllTests error (PmmlProbe.Gone false)` (AC7).
- `mutation: PMML_DEFINITION_PATH is the listing groups' route -> pmml-model-list.page.spec.ts red (the path and body legs) and, with the bundle rebuilt and redeployed, the Batch 3 browser test red (timeout waiting for the new class's rows)` (AC6).
- `mutation: one word of REASONPMMLCOMPILE changed -> analytics.test.mjs red naming the pair` (the sentences on both surfaces).
- The nine roster rows (SurfaceCoverage, EndpointCoverage, ToolRoundTrip, AnalyticsDescriptor, Descriptor, MappingDescriptor, ClassicPageGate, ReadTool, Prohibited) were each observed red before the row was added; SaveHoldCoverage's held leg is new.
- `mutation: Gate.Decide answers allowed for every tool -> AnalyticsPmmlCreateGap.TestTheAgentsAddIsRefusedWithItsKeyOffAndThePersonsIsNot red (the refusal, free-name, snapshot and audit legs)` (AC5, the key off).
- `mutation: PmmlDefinitionSnippet ignores the plan's refusal -> TestTheScriptFormRefusesWhatTheWriteRefusesAndRunsNoOtherPath raises on the first refusal leg` (AC3, AD-59).
- `mutation: AnalyticsPmmlModelAdd.TextNormalized answers its arguments unchanged -> TestAPastedTextIsStoredAsSentByEveryCaller red (the person's and the agent's read-back verdict legs)` (AC1, AD-58).
- `mutation: PmmlTextRefused refuses a text over 2,000,000 characters -> TestALargeLegalTextIsStoredWhole red (create, length, equality and models legs)` (AC1).
- `mutation: RestoreClass quits at its first line -> TestACompileRefusedAfterItsClassesWereGeneratedLeavesNone red (the port, person, agent and snapshot legs)` (AC4).
- `mutation: PlanPmmlDefinition without the own-code test -> TestOwnNamesInOtherCasesAndWithAPrefixAreRefused red (every name's port leg and the prefix name's free leg) and the script test's own-code leg red` (AC2).
- Decided in QA: the large legal text is 2,999,000 characters, below the bound by what the class text adds; the bound itself is the class text's (code review), pinned below.
- `mutation: PlanPmmlDefinition without the class-text length test -> AnalyticsPmmlCreateGap.TestATextIsBoundedByItsClassTextAndRefusedAsText red (port, route, mint and sentence legs of both the one-over and the 3,000,000-character texts); the test compared with >= -> the same test red (the exact-bound stored legs)` (AC3, the exact bound).
- `mutation: PmmlDefinitionSnippet starts its lookup answer at free -> TestTheScriptFormFailsClosedAndAnswersNoStepForALongText red (failed-lookup and saves-nothing legs); without its length test -> the same test red (the long-text leg, MAXSTRING)` (AD-59).
- `mutation: PlanPmmlDefinition refuses only a held package -> AnalyticsPmmlCreateEdge.TestAHeldClassOrPackageIsRefusedAndNothingIsTouched red (the class held alone and its case variant, port legs)` (AC2).

**Shared surfaces:** PMML models' actions and empty state, the entity-type vocabulary, the write-tool, coverage, endpoint and route rosters, the governance baseline, the prohibited set's covered types, `screen-mirror.test.mjs`, the `analytics.test.mjs` guard and the arming roster.

**Hermeticity:** every test added or changed passes on its first run on a fresh instance, in either order, and removes every `ProbePmml.New*` class it makes.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** PMML New: `POST /analytics/pmml-models` and the agent's `analytics.pmmlmodels.add` save and compile a `%DeepSee.PMML.Definition` class from PMML text through the class-write path, refuse a held class or package, an OcuPilot name, a bad name and an untrusted text (`}` anywhere, a document type or entity declaration, empty, oversized), and put the class back when the compile is refused. The read type `PMMLDEFINITION`, the descriptor's New action, the dialog with Load from file, the store, the baseline key (true), the audit row and the script form ship with it. The text guard is the U-127 ruling: any `}`.

**Files.** Server: `Port/AnalyticsPort.cls` (plan, perform, read, snippet, gate), `Api/AnalyticsError.cls` and `Api/Router.cls`, `Area/Analytics/PmmlDefinitionSave.cls` and `Screen/Tool/AnalyticsPmmlModelAdd.cls` (new), `Screen/Descriptor/AnalyticsPmmlModelList.cls`, `Kernel/EntityType.cls`, `Kernel/Governance/Baseline.cls`, `Kernel/Proposal/Prohibited.cls` (a new predicate, one appended term at each of the three sites, add-only lines; the word-diff against the batch base removes only the `COVEREDTYPES` string). Client: the list page, dialog and store, the outlet, handler, actions, strings, proposal view and mirror. Tests: `AnalyticsPmmlCreate`, `AnalyticsPmmlCreateEdge` and `AnalyticsPmmlCreateBase` (new), the probe, the seam, the roster classes, the component spec, the browser spec and `analytics.test.mjs`. EXPERIENCE.md has one add-only strings row.

**Review.** Two layers; 16 findings, none high. Patched: 3 medium (failed lookup read as free, no read-only test, the lone `{` leg) and 3 low (the TAKEN sentence, the AC7 mutation line, the component spec's wait); the rest are rejected with reasons in the triage log. Follow-up review recommended: true, for the risk that the three patched medium legs (the read-only seam arm, the failed-lookup guard and the lone-`{` control) were added after the review and have had no second reader; each has a mutation observed red.

**Verification.** Both new classes and 16 changed or rostered classes passed first on a fresh `ocupilot-b-ci` (rebuilt), forward (218 tests) and in reverse; the full ObjectScript sweep ran as 17 shards, green after two roster fixes the sweep found (`ToolWrite` count, `ToolEmit` branch), each re-run green; `check-objectscript` 0 problems; `field-lists --check` clean; `npm run test:tools` 2355 and `test:components` 3723 pass; the build is clean (2.19 MB initial against 2,500 kB); `analytics.browser-spec` 19/19 and `a11y-structural-invariants` 13/13 on the rebuilt bundle; `lint-docs` clean. Mutations are in `## Verification`, each applied, observed red and reverted byte-identical.

**For the lead.** (1) The create's proposal target is `pmml-model`, not the plan's `pmml-definition` (Decided in-stage 1). (2) `ToolWrite.cls` is contended with Epic 21 (21.20): the count literal and its sentence are the edit to union at integrate. (3) The three Prohibited terms, `EntityType` and `Baseline` edits are add-only as ruled. (4) The agent's refusals at the mint read `TOOL.ARGUMENTS`, as the listing groups' do.
