---
title: 'Story 24.12: Quality measures (Batch 2: the four measure writes)'
type: 'feature'
created: '2026-11-18'
status: 'ready-for-dev'
baseline_revision: '18d6eecbbc05920765b2fb417e76d6e8543853db'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-12-quality-measures.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-11-listing-groups-2.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Batch 1 (`spec-24-12-quality-measures.md`, `done`, code head `1e2e176d2`) lets a person and the agent read quality measures, but nobody can create, change, copy or delete one from OcuPilot. The story's criterion is a round trip over the backing class, a class extending `%DeepSee.QualityMeasure.QualityMeasure` whose `QualityMeasure` XData holds the measure.

**Approach:** The four measure writes of U-111 (Batch 1 Design Notes › Questions 1), each one confirmed proposal with two callers, built on 24.11 Batch 2's class-write path exactly (U-108, U-110): `AnalyticsPort` composes the class from the measure's own model read at the write and saves, compiles and deletes it through `AtelierPort` via `Kernel/SourceDocument`, as `DevToolPort.Promote` does. A refused compile restores the prior text or deletes a new class. Element and documentation writes are Batch 3.

## Boundaries & Constraints

**Always:**

- **Tools and keys (AD-22).** `analytics.qualitymeasures.add`, `.update` and `.copy` ship `true`; `analytics.qualitymeasures.delete` is `DESTRUCTIVE`, ships `false`, and confirms with the typed name and its consequence, as `analytics.listinggroups.delete` does.
- **Gate, refused by name before any write (AD-8, AD-29, AD-61, AD-65):** `QUALITYMEASUREPAIRS`, then `AtelierPort.Pairs()` (`%Development:USE`) and `AtelierPort.WritePairs(namespace)`, then WRITE on the database `^DeepSee.QMsrs` maps to, mounted read-write. Stricter than the classic page, as U-108 ruled for listing groups.
- **Own code (AD-10).** Every write refuses 403 `PROHIBITED.OCUPILOTCODE` with its published sentence, from both callers, the script form and the mint, whenever `Prohibited.IsOcuPilotCode` holds for the class written (any case, any depth): the new class of an add or copy, the registered class for update and delete. A copy out of an `OcuPilot*` class into another class is allowed, as 24.11's is.
- **Identity.** A measure is keyed by its full name `catalog/set/id` (the Batch 1 row id, AD-13); every write refuses a name two classes declare (409 `ANALYTICS.QUALITYMEASURE.AMBIGUOUS`). Catalog, set, id and class change only through copy.
- **The single-object read.** `QUALITYMEASURE` (the mint's and a screen action's fresh read, the Edit dialog's form read and the read-back) answers the class's own model as `{Name, Catalog, Set, Id, Class, Caption, Description, SubjectArea, Expression, LinkedTo, Published, Format, Href, Compiled, Groups, Version, Namespace}`, `Version` the class's, which the fingerprint covers; `COPYTARGET` is 24.11's shape without cubes.
- **Composition.** Every write but add composes from `%DeepSee.QualityMeasure.Utils.%GetModel(name, .sc, 0)` (the class's own model, not the link-merged one Batch 1 shows), serialized by `%XML.Writer` (`NoXMLDeclaration`, `Indent`) as measured; an update replaces only the `QualityMeasure` XData body and keeps every other line.
- **Pre-checks before any save (the vendor compile's, measured in Batch 1):** name parts shaped; name taken on add or copy (listed, registered in `^DeepSee.QMsrs("qmsrNames")`, or class defined: 409 `TAKEN`); the composed model's own `%Validate()` (422 `COMPILE`, nothing written); every `[group]` in the expression names an enabled group holding an enabled element, brackets matched (422 `EXPRESSION`); on a measure linked after the update, an `Expression`, `Format` or `Href` that differs from the stored one (409 `LINKED`).
- **Codes** (`Api/AnalyticsError.cls`, each with its proposed sentence under Design Notes, in this order): `ANALYTICS.QUALITYMEASURE.TAKEN`, `.AMBIGUOUS`, `.COMPILE`, `.ABSENT`, `.READONLY`, `.EXPRESSION`, `.LINKED`, and `.CLASS` with the listing groups' class sentence; consequences `.DELETE` and `.SAVE`.
- **Refused compile.** Add and copy delete the class (its name is registered anyway, measured); update saves the prior text back and recompiles it when the fresh read had `Compiled` true. 422 `ANALYTICS.QUALITYMEASURE.COMPILE`; the compiler's text is logged, never sent (AD-39).
- **Audit, script form, read-back.** `ConfigChange` from either caller, a restored write with its outcome (AD-15); a script form gated as 24.11's, add and copy behind a one-line free-name check (AD-59); read-back per AD-58 with `READBACKFIELDS`, a correct add or update reading `matches`, delete `notFound`, copy action-style as its siblings.

**Never:**

- `%SaveQMsrDefinition`, `DeleteQMeasure`, `$System.OBJ.*` beyond Batch 1's `IsUpToDate`, `/api/deepsee` or `/api/atelier` over HTTP; `AnalyticsPort` names no `%Api.Atelier.*` class (AD-61).
- Writing `disabled` (a disabled measure is no row, so nothing could reach it again), groups, elements or documentation items (Batch 3), or touching U-34.
- A spine edit; a contended-file edit other than Design Notes › Contention allows.

## I/O & Edge-Case Matrix

Rows run in USER on `ocupilot-b-ci`; each test makes and removes its own measures, classes `OcuProbeQMW.Analytics.*`, catalog `OcuProbeQMW` (AC6).

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Add | New `C/S/I`, class, caption, subject area | Compiled measure with the classic starter groups; read-back `matches` | - |
| Add refused | Name or class taken; malformed part (`.` or `/`, empty); `%` or no-package class | Nothing written | 409 `TAKEN`; 400 `PORT.FIELD.SHAPE`; 422 `ANALYTICS.LISTINGGROUP.CLASS`'s sentence as `ANALYTICS.QUALITYMEASURE.CLASS` |
| Update | Caption, expression, published, format, href on a measure with an extra class member | Fields change; groups, items and the member unchanged | - |
| Update refused | Expression naming a missing group; unmatched `[` | Nothing written | 422 `EXPRESSION` |
| Linked | Update sets `LinkedTo` and changes `Format` | Nothing written | 409 `LINKED` |
| Copy | New name and class | New compiled measure with the source's groups and items; source unchanged | - |
| Delete | Typed name; key turned on by the test | Class and its `^DeepSee.QMsrs` nodes gone | - |
| Twin | Two classes declare the name | Every write refused before any write | 409 `AMBIGUOUS` |
| Own code | Batch 1's `OcuPilotProbe.Analytics.QMCompiled`; a new class `ocupilotqmw.analytics.deep.new` | Refused, one leg per write shape | 403 `PROHIBITED.OCUPILOTCODE` |
| Compile fails | 24.11's seam fails the compile after the pre-checks | Prior text back, or new class gone | 422 `COMPILE` |
| Stale | Class changes between mint and confirm | Proposal closes as target-changed | 409 |
| Key off | Delete at its shipped `false` | Governance refuses | 403 |
| Gate | No `%Development:USE`; no `%DeepSee_PortalEdit:USE` | Refused before any write | 403 naming the pair |

</intent-contract>

## Code Map

Paths under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-24` (HEAD `18d6eecbb`). **Follow 24.11 Batch 2 file for file** (`055317df8`, its QA `0f0f181be`, rework `730e56bb8`, `c7f186888`); its Code Map gives the anchors this batch extends. **(contended: add-only)** marks a file Epic 21 has changed beyond feature (`git log --no-merges origin/OCU-1-epic21 ^origin/feature/OCU-1_ocupilot-mvp`, 2026-11-18; the implement stage re-runs it).

- **`src/OcuPilot/Port/AnalyticsPort.cls`** (5,277 lines). Siblings it extends (Rule 2):
  - `Serves` :530 and `Invoke` :619: a `QualityMeasures` branch for `QUALITYMEASURE`, `COPYTARGET`, `ADD`, `UPDATE`, `COPY`, `DELETE`, routed before `IsTermListType` (which also matches `ADD`); `tChanges` and `Admit` :715 gain an `IsQualityMeasureEndpoint` branch.
  - Lift `AdmitListingGroup` :4561 into `AdmitClassWrite(namespace, extraPairs, global, readOnlyCode)` used by both; the measures pass no extra pairs, `^DeepSee.QMsrs`, `QUALITYMEASUREREADONLY`.
  - New `InvokeQualityMeasure`, `ReadQualityMeasure`, `PlanQualityMeasure`, `QualityMeasureProblem`, `PerformQualityMeasure`, `VendorQualityMeasureCompose`, `QualityMeasureViolations`, `QualityMeasureSnippet`, shaped as `InvokeListingGroup` :4967 through `ListingGroupSnippet` :5247 (no resource, no SQL pair, no listings). `ReadQualityMeasureData` reads `%GetQualityMeasureList` (listed count), `%GetQualityMeasureClass`, `%GetModel(name, , 0)` and `IsUpToDate`, as Batch 1's `Collect` branch does.
  - Lift `PerformListingGroup`'s save, compile, log and restore core (:5155-5177) and `RestoreListingGroup` :5217 into one `WriteClass`/`RestoreClass` pair both writes call, and `ListingGroupSnippet`'s save, compile and undo lines :5258-5271 into one `ClassWriteSnippet` that takes the free-name condition; `OwnCodeRefusal` :5049 and `AtelierPortClass` :4573 are reused as they are.
- **`src/OcuPilot/Kernel/ListingGroupText.cls`**: make the XData name a parameter (`XDATANAME`, `Listings`) and the `DependsOn` rewrite one (`DEPENDSON`, 1), behavior unchanged. New **`Kernel/QualityMeasureText.cls`** extends it: `SUPERCLASS` `%DeepSee.QualityMeasure.QualityMeasure`, `XMLNAMESPACE` `http://www.intersystems.com/deepsee/qualityMeasure`, `XDATANAME` `QualityMeasure`, `DEPENDSON` 0.
- **`src/OcuPilot/Kernel/SourceDocument.cls`**: used unchanged (`Read`, `Version`, `Save`, `Compile`, `Remove`).
- **Tools (new, `src/OcuPilot/Screen/Tool/`):** `AnalyticsQualityMeasureAction` extends `AnalyticsListingGroupAction` (descriptor, `DESTINATIONGLOBAL` `^DeepSee.QMsrs`, `CLASSICPAGES` `%DeepSee.UI.QualityMeasures`, `READTYPE` `QUALITYMEASURE`, `CONSEQUENCECODE` `ANALYTICS.QUALITYMEASURE.SAVE`); give that base parameters for the edit pairs and the two port method names `RuleProblem` :131 calls, so the subclass overrides parameters, not methods. `AnalyticsQualityMeasure{Add,Update,Copy,Delete}` take the shapes of `AnalyticsListingGroup{Add,Update,Copy,Delete}`.
- **Descriptor:** `AnalyticsQualityMeasureList.cls` gains `primaryAction` `add`, `rowActions` `update`, `copy`, `delete`, and `table.emptyAgentKey` in place of `emptyNextKey` (:29-30, :57-58); its "offers no action" sentence is replaced. The two child descriptors stay read-only (Batch 3).
- **Screens' own Saves (AD-55):** new `Area/Analytics/QualityMeasureSave.cls` (as `ListingGroupSave.cls`) and `QualityMeasureForm.cls` extending `ListingGroupForm.cls` (descriptor and read type as parameters); routes in `Api/Router.cls` beside :279-280.
- **Kernel and API:** `Kernel/Governance/Baseline.cls` after :283 **(contended: add-only)**; `Api/AnalyticsError.cls` beside :205-251 and its two rosters :301-353; `Kernel/Proposal/Prohibited.cls` **(contended: add-only)**, Design Notes › Contention.
- **Client (`ui/src/app/areas/analytics/`):** new `quality-measure-list.page.ts` (+ `.spec.ts`) and `quality-measure-dialog.ts` (New draws Catalog, Set, ID, Class, Caption, Description and Subject area and sends `Name` as `catalog/set/id`; Edit draws the eight update fields from the form read), modeled on `listing-group-list.page.ts` and the group half of `listing-group-dialog.ts` (copy reason: a measure has none of a group's cube, resource or listing fields); Copy extends `listing-group-copy-dialog.ts` with the descriptor and drawn fields as inputs (listing groups' behavior unchanged); the store extends `listing-group.store.ts` with the form path as a parameter. Maps, each **(contended: add-only)**: `shell/screen-outlet.ts` `DESCRIPTOR_PAGES`; `shell/screen-action-handler.ts` `SCREEN_ACTION_DESCRIPTORS`, `UNDRAWN_ACTIONS`, `DESTRUCTIVE_CONSEQUENCES`, `TYPED_NAME_ROWS`; `core/screen-actions.ts` `DESCRIPTOR_ACTION_LABELS`; `core/strings.ts` (once ruled); `core/proposal-view.ts`; `core/screens.generated.ts` (regenerated).
- **Rosters (Rule 30):** the files 24.11 Batch 2's Verification roster names, re-grepped for `analytics.listinggroups.copy` and `AnalyticsListingGroupAdd`: `ReadTool`, `SurfaceCoverage`, `Governance`, `GovernanceBaseline`, `ClassicPageGate`, `MappingDescriptor`, `ToolRoundTrip`, `ToolWrite`, `Prohibited` (all **(contended: add-only)**), `ToolDispatch`, `ToolEmit`, `EndpointCoverage`, `AnalyticsDescriptor`, `SaveHoldCoverage`, `ui/tools/screen-mirror.test.mjs`, `ui/tools/analytics.test.mjs` (the Story 24.12 Batch 1 vendor-call pin is rewritten to allow the model's `%Validate()` and still forbid `%SaveQMsrDefinition`, `DeleteQMeasure` and `$System.OBJ.` beyond `IsUpToDate(`).
- **Fixture:** `Test/AnalyticsProbe.cls`: `RemoveQualityMeasures` :945 and `Left` cover the `OcuProbeQMW` and `ocupilotqmw` prefixes and their `^DeepSee.QMsrs` nodes.
- **EXPERIENCE.md:** one Fixed strings row appended after :614 **(contended: add-only)**, in the form of :612; :614's sentence that the screens offer no action is replaced for Quality measures only.
- **Vendor (read only):** `irislib/%DeepSee/QualityMeasure/Utils.cls` (`%GetModel` :152, `%GetQualityMeasureList` :285, `%SaveQMsrDefinition` :357), `QualityMeasure.cls` (the compile's name check :70-74, `%Validate`, expression resolution :265-300), `Model/QualityMeasure/qualityMeasure.cls` (`%Validate` :57), `UI/QualityMeasures.cls` (`newMeasure` :1166 and the starter model :941-985, linked fields :1686-1688, `DeleteQMeasure` :1225), `UI/Dialog/QualityMeasureSave.cls` (name rules :64-125).

## Tasks & Acceptance

**Execution:**

- [ ] **Task 0** (`ocupilot-b-ci`, USER, marked classes removed after): measure and record under Design Notes › Measured that `AtelierPort` `TYPEDELETE` of a compiled measure removes its `^DeepSee.QMsrs` nodes (inference: as `$System.OBJ.DeletePackage` did below); what a refused update leaves and that the restore re-registers the prior measure; that the model's `%Validate()` and the writer journal nothing; that each `READBACKFIELDS` reads `matches` after a correct write (where the vendor stores another form, both callers send the port's normalized form, as `NormalizedCubes` does).
- [ ] `AnalyticsPort.cls`, `ListingGroupText.cls`, `QualityMeasureText.cls`: the reads, writes, pre-checks, restore, audit and script forms, and the lifted helpers.
- [ ] The action base's parameters, the five tool classes, the descriptor, the two `Area` classes and routes, `Baseline.cls`, `AnalyticsError.cls`, `Prohibited.cls`, the client, the strings (once ruled), the regenerated mirror and the EXPERIENCE.md row.
- [ ] Tests (each class at most about 500 lines, armed by `OCUPILOT_ALLOW_PRINCIPALS`, rostered add-only in `scripts/ci-throwaway.sh` with `ui/tools/ci.test.mjs` **(contended: add-only)**):
  - new `Test/AnalyticsQualityMeasureBase.cls` extending `Test/AnalyticsListingGroupBase.cls` (its per-test cleanup made a hook it overrides), with `Test/AnalyticsListingGroupSeam.cls` and `AnalyticsListingGroupAtelier.cls` reused as the compile-fails seam;
  - new `Test/AnalyticsQualityMeasureWrite.cls` (the four writes by both callers, read-backs, refusals, own code, script forms) and `Test/AnalyticsQualityMeasureWriteEdge.cls` (twin, compile fails, stale, key off, gate as principals);
  - `ui/browser/analytics.browser-spec.mjs`: create a measure, edit it, copy it, then a typed-name delete; the page spec; every roster above.

**Acceptance Criteria:**

- **AC1 (round trip, both callers).** Given a measure made by each write, through the screen action and the agent's confirmed proposal. When Batch 1's reads and `%GetModel(name, , 0)` read it. Then they hold exactly what was sent, and every class line outside the `QualityMeasure` XData is unchanged.
- **AC2 (Integration, Rule 1).** Given each write. When it is confirmed. Then `GET /screens/analytics.qualitymeasures/read` and the agent's `analytics.qualitymeasures.read` answer the new state, and the read-back verdict is `matches` (`notFound` for delete, `nothingSent` for copy, as its siblings).
- **AC3 (nothing half-applied).** Given the compile-fails seam on each write. When it runs. Then the class text, `^DeepSee.QMsrs` and the listed measures equal their state before it.
- **AC4 (browser).** Given the probe. When a person creates a measure, edits it, copies it and deletes the copy by typing its name. Then the Quality measures screen shows each change.
- **AC5 (governed, audited, declared).** Given the four tools. When the roster tests run. Then each declares `write`, `AnalyticsPort` and `%DeepSee.UI.QualityMeasures`; the baseline holds three keys `true` and one `false`; each write records `ConfigChange`; removing any one roster row reddens that test alone.
- **AC6 (leaves USER as found).** Given any new or changed test, in either order, on a fresh instance. When it ends. Then no marked class and no marked `^DeepSee.QMsrs` node remains.

## Spec Change Log

- 2026-11-18, spec gate: the runner kept the starter model, the linked-measure refusal, the key states, the proposed strings and the proposed spine lines (veto item U-112); the one Prohibited.cls condition term is the carve-out the orchestrator allows.

## Review Triage Log

## Design Notes

**Ruled (not re-opened).** U-111: three batches; this is Batch 2; Batch 1's strings, including the agent phrase "create a quality measure", are kept. U-108/U-110: the class-write path, a restoring compile, a typed-name delete. 24.11 rework: the own-code refusal from both callers and the mint, the fixtures outside the `OcuPilot` stem, normalized fields for the read-back.

**Decided in-stage (plan).**

1. An add's id is the new full name, split by the port into catalog, set and id; it starts from the classic page's New model (`UI/QualityMeasures.cls` :941-985: groups `Numerator` and `Denominator`, one element each with MDX `100`, expression `[Numerator]/[Denominator]`), because Batch 2 writes no group and a measure's expression must name one to compile. Its caller sets `Class`, `Caption`, `Description` and `SubjectArea`; `Published` defaults true.
2. Update moves `Caption`, `Description`, `SubjectArea`, `Expression`, `LinkedTo`, `Published`, `Format` and `Href`. `%GetModel(name, , 1)` takes a linked measure's expression, format and href from its master, so such a change would read back `differs`; it is refused, judged on the `LinkedTo` the update leaves. `LinkedTo` naming the measure itself is a shape violation; otherwise it is not checked, as the vendor's compile does not check it.
3. `%Validate()` is the model's own pure rule (catalog, set, id, unique enabled group, element and item names); it joins Batch 1's measured reads once Task 0 shows it journals nothing. Its sentence is never sent; a failure answers `COMPILE` with nothing written.
4. The prompts and empty sentences are Batch 1's; no prompt is added. DW-2725 (copy reads `nothingSent`) gains an occurrence at harvest; nothing here decides it.
5. **Contention.** In `Kernel/Proposal/Prohibited.cls`: added lines only (a `TYPEQUALITYMEASURE` parameter `quality-measure`, a new `IsQualityMeasureType` naming it, the change list `Caption,Description,SubjectArea,Expression,LinkedTo,Published,Format,Href`, the create list adding `Name,Class`, and create and reviewed-few branches beside :1760 and :1983), the `COVEREDTYPES` :311 list entry (a roster union), and **one** condition term on :1589, `'..IsQualityMeasureType(tType)` after `'..IsListingGroupType(tType)`, its before and after recorded here by the implement stage. Batch 3 widens `IsQualityMeasureType`'s body, so :1589 is not edited again. Every other contended file takes roster-union edits only; `ui/angular.json`, `ui/vitest-base.config.mjs` and `ci-throwaway.sh`'s bring-up retry block are not touched.

**Measured** (plan, 2026-11-18, `ocupilot-b-ci`, USER, package `OcuProbe2412b` removed after, `^DeepSee.QMsrs` empty after):

- `%XML.Writer` over `%GetModel(name, , 0)` wrote the measure with a derived `name` attribute and `disabled`, `published` defaults; that XML saved as a new class compiled, and its model read back with the change applied and every field, group, element and item equal (`content` as its stored markup). `%Validate()` on it answered OK.
- `$System.OBJ.DeletePackage` removed both classes and every `qmsrNames`, `qmsrClasses` and `cubes` node.

**Proposed strings (veto; added to EXPERIENCE.md only once ruled).** Reused verbatim: "Edit", "Copy", "Delete", "Class", "New name", "New class", "Name", "Caption", "Description", "Subject area", "Published", "Expression", "URL", "ID", and "Name the class with letters, digits and dots, outside the % and OcuPilot packages."

- Action and labels: "New quality measure" · "Catalog" · "Set" · "Format" · "Linked to".
- Consequences: delete, "Deleting this quality measure deletes its class. This cannot be undone from OcuPilot."; every write, "The quality measure's class is saved and compiled."
- Refusals: "This namespace already holds a quality measure or class with that name." · "Two classes define this quality measure. Change it in its class instead." · "The instance refused to compile the quality measure, so nothing was changed." · "This quality measure no longer exists." · "The database that holds quality measures is read-only." · "The expression names a group this quality measure does not hold, or its brackets do not match." · "This quality measure is linked to another measure, which defines its expression, format and URL."
- Agent empty-state phrase: "create a quality measure" (Batch 1, ruled). The starter groups' names in item 1 are the vendor's own data, not product strings.

**Governing ADs (Rule 6).** The write set AD-3, AD-4, AD-6, AD-14, AD-15, AD-22, AD-34, AD-40, AD-51, AD-52, AD-53, AD-54 (add, copy), AD-55, AD-58, AD-59; the gate and namespace AD-8, AD-16, AD-29, AD-61, AD-65; AD-13 (ids holding `/`); AD-39 (compiler text); AD-10 (own code); AD-11 and AD-60 (model text is untrusted).

**Proposed spine lines (the owner's attended update; never written here).** AD-65: "Quality measure writes compose the class from `%GetModel(name, , 0)` and save, compile and delete it through `AtelierPort` (AD-61), under the screen's pairs and `AtelierPort.WritePairs`; a refused compile restores the prior definition. The model's `%Validate()` joins the measured pure reads." AD-22: "`analytics.qualitymeasures.delete` ships `false`."

**Integration and linkage (Rules 1, 2).** `Consumes:` Batch 1's `QualityMeasures` read; `Kernel/SourceDocument`; `Kernel/ListingGroupText`; `AtelierPort`; `AnalyticsListingGroupAction`; `Area/Interop/ItemSave`; `ListingGroupForm`; the listing-group copy dialog and store. `Consumed-by:` Batch 3, whose element and documentation writes plan, compose, write and restore through this batch's `PlanQualityMeasure` and the lifted `WriteClass`/`RestoreClass`. AC2 is the Integration AC.

**Ledger inbox.** Declined DW-2734: Batch 3.

## Verification

**Commands** (one `ci-runner` call per message; the throwaway is `ocupilot-b-ci`):

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.AnalyticsQualityMeasureWrite`, then the same for `AnalyticsQualityMeasureWriteEdge`, `AnalyticsQualityMeasureRead`, `AnalyticsQualityMeasureEdge`, `AnalyticsQualityMeasureGate`, `AnalyticsListingGroupWrite`, `AnalyticsListingWrite`, `AnalyticsListingGroupWriteEdge` (the lifted helpers), each roster class under Code Map and every class the shared-surface sweep changes. Expected: green.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`. Expected: green.
- `(loop)` `cd ui && npm run build`, `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/analytics.browser-spec.mjs`. Expected: green.
- `(once)` the full ObjectScript sweep: `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17`, one call per shard, k = 1 to 17. Expected: green.
- `uv run scripts/check-objectscript.py`, `bash scripts/lint-docs.sh`. Expected: clean. The full browser suite is left to CI.

**Shared surfaces:** the Quality measures descriptor's actions and empty state, the governance baseline, the write-tool rosters under Code Map, `Router.cls`'s routes, `AnalyticsError`'s code rosters, `Prohibited`'s covered types, the arming roster in `ci-throwaway.sh` and `ci.test.mjs`, and `ci-timings.json` (no rows for the new classes).

**Hermeticity:** every test added or changed passes on its first run on a fresh instance, in either order; no test counts journal records without Batch 1's engine exclusions.

**Mutations:** one per AC, recorded here by whoever writes the pinning test (Rule 19).

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

- **Planned:** Batch 2 of three (U-111), the four measure writes, on 24.11 Batch 2's class-write path with its helpers lifted rather than copied (`AdmitClassWrite`, `WriteClass`/`RestoreClass`, `ClassWriteSnippet`, `ListingGroupText` parameterized, the listing-group action base, test base, seam, form, copy dialog and store extended). One pass is judged enough: four writes against 24.11's seven, most of the path reused.
- **For the spec gate (veto):** the proposed strings, the two proposed spine lines, Decided in-stage 1 (the classic starter model on add) and 2 (the linked-measure refusal), and the one contended logic term in `Prohibited.cls`.
- **Measured in planning:** the writer's XML of `%GetModel(name, , 0)` compiles as a new class and reads back equal; `DeletePackage` clears every `^DeepSee.QMsrs` node (throwaway left as found). The `AtelierPort` delete, the restore and the journal scans are Task 0.
- **Ledger:** Declined DW-2734: Batch 3. DW-2725 gains an occurrence at harvest (copy read-back).
