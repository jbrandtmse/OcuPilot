---
title: 'Story 24.12: Quality measures (Batch 2: the four measure writes)'
type: 'feature'
created: '2026-11-18'
status: 'done'
baseline_revision: 'ec96af82d7c49cd4e1ab47a0d3795bad260fcef8'
baseline_commit: 'ec96af82d7c49cd4e1ab47a0d3795bad260fcef8'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-12-quality-measures.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-11-listing-groups-2.md'
warnings: ['oversized']
deferred:
  - summary: >-
      A refused create's registry nodes and listed measures are compared with their prior state only through a seam that compiles nothing.
    evidence: |-
      AnalyticsListingGroupAtelier answers errors without compiling, so the vendor never registers the name; the delete test pins node removal for a compiled class only.
    location: >-
      src/OcuPilot/Test/AnalyticsQualityMeasureWriteEdge.cls
    severity: low (unverified)
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

**Review patches (open items; the review pass, 2026-11-18):**

- [x] P1 `Test/AnalyticsProbe.cls`, `Test/AnalyticsQualityMeasureBase.cls`, `Test/AnalyticsQualityMeasureWrite.cls`: the own-code fixture `ocupilotqmw.analytics.deep.new` is outside the `OcuProbeQMW.`/`OcuPilotQMW.` sweeps (`%STARTSWITH` is case-sensitive), so a failed own-code guard leaves a compiled class in USER. Rename the fixture to start with the lower-case `QMWRITEOWNCLASS` stem and make `RemoveQualityMeasures`, `Left` and `Snapshot` match the prefixes case-insensitively.
- [x] P2 `Test/AnalyticsQualityMeasureWriteEdge.cls` (`TestARefusedCompileUndoesEachWrite`, `UndoOff` leg): assert the `ConfigChange` row's outcome is `restored` for the not-compiled leg (a restore that compiles anyway must redden it).
- [x] P3 `Test/AnalyticsQualityMeasureWriteEdge.cls`: stale legs for delete and copy (mint, change the class, confirm, `409 PROPOSAL.TARGETCHANGED`), beside the update leg; record the mutation (drop `Version` from each fingerprint) in `## Verification`.
- [x] P4 `Test/AnalyticsQualityMeasureBase.cls`, the Write or Edge class: an `EXPRESSION` case naming a disabled group or a group whose elements are all disabled (`422 ANALYTICS.QUALITYMEASURE.EXPRESSION`, nothing written); add the group to the measure text only if the existing tests stay equal.
- [x] P5 `Test/AnalyticsQualityMeasureWrite.cls`: after update, copy and delete also read through `ScreenRows` / `ToolHas` (the row's caption after update, the copy present, the deleted name absent).
- [x] P6 `Test/AnalyticsQualityMeasureWriteEdge.cls` (`TestAChangedClassCloses...`): call `EnableKey` before `GovernanceFixture.Clear()` as the delete test does, so `OnAfterOneTest` restores the policy.
- [x] P7 `EXPERIENCE.md` row 615: "The seven refusals" lists eight; say "eight".

**Acceptance Criteria:**

- **AC1 (round trip, both callers).** Given a measure made by each write, through the screen action and the agent's confirmed proposal. When Batch 1's reads and `%GetModel(name, , 0)` read it. Then they hold exactly what was sent, and every class line outside the `QualityMeasure` XData is unchanged.
- **AC2 (Integration, Rule 1).** Given each write. When it is confirmed. Then `GET /screens/analytics.qualitymeasures/read` and the agent's `analytics.qualitymeasures.read` answer the new state, and the read-back verdict is `matches` (`notFound` for delete, `nothingSent` for copy, as its siblings).
- **AC3 (nothing half-applied).** Given the compile-fails seam on each write. When it runs. Then the class text, `^DeepSee.QMsrs` and the listed measures equal their state before it.
- **AC4 (browser).** Given the probe. When a person creates a measure, edits it, copies it and deletes the copy by typing its name. Then the Quality measures screen shows each change.
- **AC5 (governed, audited, declared).** Given the four tools. When the roster tests run. Then each declares `write`, `AnalyticsPort` and `%DeepSee.UI.QualityMeasures`; the baseline holds three keys `true` and one `false`; each write records `ConfigChange`; removing any one roster row reddens that test alone.
- **AC6 (leaves USER as found).** Given any new or changed test, in either order, on a fresh instance. When it ends. Then no marked class and no marked `^DeepSee.QMsrs` node remains.

### Review Findings

Code review of Batch 2 (2026-11-18, `full-opus`; blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor): 0 decision-needed, 11 patch (all applied), 3 defer (ledgered `wontfix-accepted`), 15 rejected.

- [x] [Review][Patch] (medium) Test helpers copied from 24.11's tests instead of shared: `Compiling`, `Script`, `RunScript`, `HoldEverythingBut` and `Recorded` repeated in `AnalyticsQualityMeasureBase`/`WriteEdge`/`WriteReal` and `AnalyticsListingGroupWrite`/`WriteEdge` [src/OcuPilot/Test/AnalyticsListingGroupBase.cls] — lifted into `AnalyticsListingGroupBase` (`COMPILESEAM`, `WRITEENDPOINT`, `HeldPairSpec`) and `AnalyticsQualityMeasureBase` (`Recorded`).
- [x] [Review][Patch] (medium) The script form's free-name check lacked the vendor-list half 24.11's has, so a name listed through an unregistered class could get a second twin [src/OcuPilot/Port/AnalyticsPort.cls:QualityMeasureSnippet] — prelude reads `%GetQualityMeasureList`; new listed and other-class legs in `TestEachWritesScriptFormMakesTheSameChange`.
- [x] [Review][Patch] (medium) `QualityMeasureViolations`' length and type rules had no test [src/OcuPilot/Test/AnalyticsQualityMeasureWrite.cls:TestEachRefusalWritesNothing] — legs for a 251-character name part, a 2,001-character caption, a 256-character format and a non-string caption.
- [x] [Review][Patch] (medium) `Snapshot` read only `qmsrNames`, so AC3's "`^DeepSee.QMsrs` equal before" missed class and subject-area nodes [src/OcuPilot/Test/AnalyticsQualityMeasureBase.cls:Snapshot] — walks every marked node; `QGone` checks every subject area.
- [x] [Review][Patch] `RunScript` read a thrown line as success [src/OcuPilot/Test/AnalyticsListingGroupBase.cls:RunScript]
- [x] [Review][Patch] `WriteReal` relied on `^OcuProbeQMWFail` being absent at start [src/OcuPilot/Test/AnalyticsQualityMeasureWriteReal.cls:OnBeforeOneTest]
- [x] [Review][Patch] Mutation notes naming renamed or wrong methods (`RestoreListingGroup`, `AdmitListingGroup`'s `tWritePairs`, "every leg") [AnalyticsListingGroupWriteEdge.cls, AnalyticsListingGroupDatabase.cls, AnalyticsQualityMeasureWriteEdge.cls, AnalyticsQualityMeasureWriteReal.cls]
- [x] [Review][Patch] Save doc comments called `Class` optional [src/OcuPilot/Area/Analytics/QualityMeasureSave.cls, ListingGroupSave.cls]
- [x] [Review][Patch] `QUALITYMEASURETEXTMAX` claimed to be the model's own limit for a URL [src/OcuPilot/Port/AnalyticsPort.cls:505]
- [x] [Review][Patch] The dialog's `required` comment claimed the server refuses an empty value [ui/src/app/areas/analytics/quality-measure-dialog.ts:28]
- [x] [Review][Patch] `ci-throwaway.sh`'s arming comment omitted the real-compiler class (one added line); `test:tools` re-run after P7's EXPERIENCE.md edit, 2,317 of 2,317 [scripts/ci-throwaway.sh]
- [x] [Review][Defer] Page and copy-tool bodies repeat the listing groups' with renamed fields [ui/src/app/areas/analytics/quality-measure-list.page.ts] — deferred: DW-2744, `wontfix-accepted`.
- [x] [Review][Defer] A `restorefailed` refused compile still answers "nothing was changed" [src/OcuPilot/Port/AnalyticsPort.cls:PerformQualityMeasure] — deferred: DW-2745, `wontfix-accepted` (needs a new sentence).
- [x] [Review][Defer] Edit dialog dead-ends on a failed form read, as the listing groups' does [ui/src/app/areas/analytics/quality-measure-dialog.ts:load] — deferred: DW-2746, `wontfix-accepted` (needs a new string).

Rejected:

- Linked target missing or circular: spec-ruled (Decided in-stage 2, as the vendor's compile).
- Deleting a master leaves followers dangling: the classic page's behavior; a guard adds a scan and a code.
- Empty `Expression` or `SubjectArea` from the agent: low; the screen cannot send one, and a guard is new rules.
- EXPRESSION sentence names a missing group for a disabled one: the sentence is ruled (U-112).
- No assertion that an update moves the subject-area node: vendor projection, covered by the model read.
- Linked fields editable in Edit: low; the server refuses with its sentence.
- `%GetQualityMeasureList` error reads as zero listed: no reachable trigger shown.
- A class with an inherited XData answers ABSENT: such a subclass is a twin first (AMBIGUOUS).
- `Splice` matches an XData name by prefix; 3,000,000-character XML read: theoretical.
- `COPYTARGET` composed for a non-copy action: no tool does.
- Dialog sends an empty `Class`: the server's sentence answers it.
- `Recorded` passes if any of three rows reads `restored`: each caller's text and registered legs pin the restore.
- Matrix says 400 for a malformed part, code answers 422: the code follows 24.11; the fix is a spec edit.
- Auto Run Result's file count: spec narration.

## Spec Change Log

- 2026-11-18, spec gate: the runner kept the starter model, the linked-measure refusal, the key states, the proposed strings and the proposed spine lines (veto item U-112); the one Prohibited.cls condition term is the carve-out the orchestrator allows.

## Review Triage Log

### 2026-11-18 — Review pass

- verdicts: 9 findings — high 0, medium 4, low 4, false 1, maybe-false 0
- findings:
  - `[low]` `[patch]` lower-case own-code fixture is outside every sweep (verification-gap 1) — P1.
  - `[medium]` `[patch]` the not-compiled restore leg cannot fail if the restore ignores `pCompiled` (verification-gap 2) — P2.
  - `[low]` `[defer]` AC3's registry half is empty for add and copy because the seam compiles nothing (verification-gap 3) — real refusal needs a seam that compiles then fails; deleting a compiled class clearing its nodes is pinned by the delete test; deferred, unverified for the refused-create path.
  - `[medium]` `[patch]` stale closure is pinned for update only (verification-gap 4) — P3.
  - `[medium]` `[patch]` expression pre-check's disabled-group half unexercised (verification-gap 5) — P4.
  - `[medium]` `[patch]` read tool and screen read asserted after add only (verification-gap 6) — P5.
  - `[low]` `[patch]` `Clear()` without `EnableKey` leaves policy rows (verification-gap, hermeticity) — P6.
  - `[low]` `[reject]` `QualityMeasureDialog` has no component spec (verification-gap, client) — the browser spec drives create, edit, copy and delete through it; a dialog spec is more than a direct correction.
  - `[low]` `[patch]` EXPERIENCE.md row says seven refusals and lists eight (intent-alignment) — P7. Intent-alignment's other divergences (starter groups on add, class header not compared, database read-only leg exercised through the shared helper only, twin on the screen leg) are spec-ruled or low and not worth a guard: rejected, `reopen_if=` a write path that bypasses `AdmitClassWrite`.

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
- **Task 0** (implement, 2026-11-18, `ocupilot-b-ci`, USER, package `OcuProbeQMW` removed after, `^DeepSee.QMsrs` empty after):
  - `AtelierPort` `TYPEDELETE` of a compiled measure answered `deleted` and removed its `qmsrNames`, `qmsrClasses` and `cubes` nodes (each `$Data` 1 before, 0 after); so did the delete of a class whose create the compile refused.
  - A refused compile of a changed class (`TYPESAVE`, then `TYPECOMPILE`: `errors` true, "Unable to find group in measure expression") leaves the three nodes and the name in the vendor's list, `IsUpToDate` 0; saving the prior text back and compiling it made `IsUpToDate` 1 and the model readable again, the nodes as before.
  - `%GetModel(name, , 0)`, the model's `%Validate()` (OK) and `%XML.Writer` (`NoXMLDeclaration`, `Indent`) over it recorded no set or kill in the journal scan of the process (0 records).
  - The writer's XML carries `name`, `disabled="false"` and an `<element ...></element>` pair where the source had `<element .../>`; the model reads equal. The class text the source API returns differs in length from the text sent (canonical UDL), so a restore saves the text read, never the text composed.
  - Read-back, from `AnalyticsQualityMeasureWrite`: a correct add (`Class`, `Caption`, `Description`, `SubjectArea`) and a correct update (the eight fields) read `matches` for both callers with the strings as sent, so no normalized form is needed; a delete reads `notFound`; a copy reads `nothingSent`, as its siblings do (DW-2725).

**Proposed strings (veto; added to EXPERIENCE.md only once ruled).** Reused verbatim: "Edit", "Copy", "Delete", "Class", "New name", "New class", "Name", "Caption", "Description", "Subject area", "Published", "Expression", "URL", "ID", and "Name the class with letters, digits and dots, outside the % and OcuPilot packages."

- Action and labels: "New quality measure" · "Catalog" · "Set" · "Format" · "Linked to".
- Consequences: delete, "Deleting this quality measure deletes its class. This cannot be undone from OcuPilot."; every write, "The quality measure's class is saved and compiled."
- Refusals: "This namespace already holds a quality measure or class with that name." · "Two classes define this quality measure. Change it in its class instead." · "The instance refused to compile the quality measure, so nothing was changed." · "This quality measure no longer exists." · "The database that holds quality measures is read-only." · "The expression names a group this quality measure does not hold, or its brackets do not match." · "This quality measure is linked to another measure, which defines its expression, format and URL."
- Agent empty-state phrase: "create a quality measure" (Batch 1, ruled). The starter groups' names in item 1 are the vendor's own data, not product strings.

**Contended logic edit.** `Kernel/Proposal/Prohibited.cls` line 1603 (originally 1589, the one-line type condition of `Prohibits`) gained one term and nothing else on it changed:

- before: `... && '..IsListingGroupType(tType) && (tType '= ..#TYPESTARTUPSETTING) && ...`
- after: `... && '..IsListingGroupType(tType) && '..IsQualityMeasureType(tType) && (tType '= ..#TYPESTARTUPSETTING) && ...`

Everything else in that file is added lines: `TYPEQUALITYMEASURE`, `IsQualityMeasureType`, the `COVEREDTYPES` entry, the change list (the eight update fields), the create list (`Name,Class,Caption,Description,SubjectArea`), and the create and reviewed-few branches. `git log --no-merges origin/OCU-1-epic21 ^origin/feature/OCU-1_ocupilot-mvp` (re-run at implement) lists only `scripts/ci-throwaway.sh` and `ui/tools/ci.test.mjs` of the files this batch touches; `ci-throwaway.sh` gained two comment lines, `ci.test.mjs` nothing, and `angular.json`, `vitest-base.config.mjs` and the bring-up retry block are untouched.

**Decided in-stage (implement).**

1. **Copies, with reasons (Rule 2).** The four tools follow `AnalyticsListingGroup{Add,Update,Copy,Delete}` through `AnalyticsQualityMeasureAction`, which extends the group base and overrides parameters only (`DESCRIPTORCLASS`, `DESTINATIONGLOBAL`, `CLASSICPAGES`, `READTYPE`, `READANSWERS`, `CONSEQUENCECODE`, and the new `EDITPAIRS`, `VIOLATIONSMETHOD`, `PROBLEMMETHOD`). The tool classes themselves repeat the siblings' shape because a measure's fields, fingerprint subject, schema text and copy state rows differ and one base cannot hold both; `QualityMeasureDialog` is not an extension of `ListingGroupDialog` because it shares none of a group's members; the page repeats `ListingGroupListPage`'s wiring over another descriptor. Everything that was the same is lifted: `AdmitClassWrite`, `WriteClass`, `RestoreClass`, `ClassWriteSnippet`, `CarryBoolean`, the form and save areas' parameters, the copy dialog's inputs and the store's form path.
2. `QualityMeasureViolations` and `QualityMeasureProblem` take a `pPart` argument that nothing uses yet, so the shared tool base calls them with the group methods' signature; Batch 3's element and documentation writes fill it.
3. An empty or malformed id (three non-empty parts, no control character) is a `PORT.FIELD.SHAPE` violation on `Name`, so no sentence beyond the ruled ones was needed; the form route's 400 reuses `PORT.FIELD.SHAPE`'s sentence.
4. The add and edit dialogs send the strings as typed; the Edit dialog sends every field the form held, a required one (`SubjectArea`, `Expression`) only when it holds text. A linked measure's unchanged expression, format and URL are equal to the stored ones, so Edit does not trip `LINKED`.
5. A new measure's name is typed as three parts (Catalog, Set, ID) and sent joined by a slash; a violation on `Name` is drawn under ID.
6. The probe's `KillQualityMeasureWriteNodes` compares registry keys without regard to case, so a lower-case own-code class a guard failure left is found.
7. `EXPERIENCE.md` gained row 615; `strings.ts`' one reference past it (`taskCreate`) moved from :656 to :657.

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

**Mutations** (Rule 19; each server mutation applied to the throwaway's `src` copy, the class and its subclasses recompiled, observed red, then the tree synced back from the worktree (`diff -rq` identical) and reloaded; client ones reverted by `cmp`, rebuilt and redeployed):

- mutation (AC1): an update's compose in `VendorQualityMeasureCompose` made to skip the caption -> `AnalyticsQualityMeasureWrite` `TestAnUpdateChangesTheHeaderAndKeepsEverythingElse` went red on its two header legs and two read-back legs, and the script test's update leg with it.
- mutation (AC2): `QualityMeasureRow` made to answer an empty `Caption` -> `TestAMeasureIsAddedByEachCallerAndReadsBack` and the update test went red on their four read-back legs, and the copy test stayed green.
- mutation (AC3): `RestoreClass` made to return before doing anything -> `AnalyticsQualityMeasureWriteEdge` `TestARefusedCompileUndoesEachWrite` went red on its text, model, registered, unregistered and snapshot legs.
- mutation (AC4): `QUALITY_MEASURE_PATH` made the listing groups' route (bundle rebuilt and redeployed) -> the browser test went red at its first row; reverted by `cmp`, rebuilt, green.
- mutation (AC5): the delete's line of `Baseline.cls` made `true` -> `TestADeleteRemovesTheClassAndItsNodesAndShipsOff` went red on its refusal and still-there legs, and `TestAChangedClassClosesTheProposalAndTheBaselineShipsOneKeyOff` on its key leg; the `analytics.qualitymeasures.copy` row removed from `SurfaceCoverage` -> its write-tool test went red alone.
- mutation (AC6): the write sweep removed from `AnalyticsProbe.RemoveQualityMeasures` -> `AnalyticsQualityMeasureWrite` went red at `OnAfterAllTests`, naming the leftover classes.
- mutation (own code): the four own-code checks in `PlanQualityMeasure` and `ReadQualityMeasure` made `0 &&` -> `TestOwnCodeIsRefusedByEveryMeasureWrite` went red on every refusal leg, and the own-code legs of the two refusal tests.
- mutation (expression, class shape): `ExpressionHolds` made to answer 1 -> the three expression legs and the mint leg of `TestEachRefusalWritesNothing` went red; the class shape check in `PlanQualityMeasure` made `0 &&` -> the `%` and no-package legs of it and of `TestEachCopyRefusalWritesNothing` went red.
- mutation (copy class): the class-defined half of the TAKEN check made to apply to an add only -> `TestEachCopyRefusalWritesNothing` went red on its class leg alone.
- mutation (twin): the ambiguity check in `PlanQualityMeasure` made `0 &&` -> `TestTwoClassesThatDeclareAMeasureRefuseEveryWrite` went red on its update, copy and delete legs.
- mutation (gate): `AtelierPort.Pairs()` dropped from `AdmitClassWrite` -> `TestAWriteIsRefusedWithoutItsPairsBeforeAnyWrite` went red on its four `%Development:USE` legs and the read leg.
- mutation (stale): `Version` blanked in `QualityMeasureRow` -> `TestAChangedClassClosesTheProposalAndTheBaselineShipsOneKeyOff` went red on the confirm leg; its first form changed the expression too, which the row covers, so the test now saves a class parameter only.
- mutation (review P2): `RestoreClass`'s `&& pCompiled` dropped -> `TestARefusedCompileUndoesEachWrite` went red on its new `restored` outcome leg alone.
- mutation (review P3): `QualityMeasureRow` made to answer an empty `Version` -> `TestAChangedClassClosesTheProposalAndTheBaselineShipsOneKeyOff` went red on the update's and the delete's stale legs (confirm and nothing-written); the copy target answer in `ReadQualityMeasure` made to carry an empty `Version` -> the copy's two stale legs went red alone. Dropping `Version` from a `FINGERPRINTSUBJECT` is refused by the tool framework's own AD-51 check and is not a usable mutation.
- mutation (review P4): `PlanQualityMeasure`'s skip of a disabled group removed -> `TestAnExpressionNamingAGroupThatCannotCountIsRefused` went red on its disabled-group legs; its test of an element's `disabled` made always true -> the same test went red on its all-disabled-elements legs.
- mutation (script): a create's compile line in `ClassWriteSnippet` made `Set tSC = 1` -> the script test went red from its registered leg on; that create line made to ignore its free-name condition -> its two late-script legs went red.
- mutation (client): the page's `copy` registration dropped -> `quality-measure-list.page.spec.ts` went red on its registration and Copy tests; the Quality measures' `UNDRAWN_ACTIONS` and `TYPED_NAME_ROWS` entries dropped -> `screen-action-handler-qualitymeasure.spec.ts` went red on both tests.

- (QA) `src/OcuPilot/Test/AnalyticsQualityMeasureWriteReal.cls`: the vendor's real compiler refusing an update (a one-shot failing class generator) at the person's Edit, the agent's confirm and the port, the restore of a not-compiled class, a linked measure's changed fields at both callers, a twin at the person's call and the agent's copy and delete mints (4 tests, green; inherits the arming through `AnalyticsQualityMeasureBase`).
- mutation (QA, AC3): `RestoreClass`'s recompile made `&& 0` -> `TestARefusedCompileOfAnUpdateIsUndoneAtEveryCaller` went red on its three registered-and-compiled legs alone; the recompile made unconditional -> `TestARefusedCompileOfAStaleMeasureIsUndoneAndLeftStale` went red on its still-not-compiled leg alone.
- mutation (QA, linked): the linked check of `VendorQualityMeasureCompose` made `0 &&` -> `TestALinkedMeasureRefusesAChangedFieldAtBothCallers` went red on the person's three refusal legs, the mint's three sentence legs and the nothing-written leg.
- mutation (QA, twin): the ambiguity check of `ReadQualityMeasure` made `0 &&` -> `TestATwinIsRefusedAtThePersonsCallAndTheAgentsMint` went red on a mint leg; the same mutation in `PlanQualityMeasure` leaves it green, because the read refuses first (the port's check is pinned by `AnalyticsQualityMeasureWriteEdge`).
- mutation (review 2, script list half): `'tListed` dropped from `QualityMeasureSnippet`'s free-name check -> `TestEachWritesScriptFormMakesTheSameChange` went red on its listed leg alone.
- mutation (review 2, shape rules): the length and type clause of `QualityMeasureViolations` made `If 0` -> `TestEachRefusalWritesNothing` went red on its three text legs and the nothing-written leg after them.

**Verification roster** (the Rule 30 grep for `analytics.listinggroups.copy` and `AnalyticsListingGroupAdd`, re-run): `ReadTool` (508 tools, five names), `SurfaceCoverage` (four rows), `Governance` and `ToolDispatch` (`QUALITYMEASUREDISABLED`), `GovernanceBaseline`, `ClassicPageGate` (`OWNPAIRS`, the delete key), `MappingDescriptor`, `ToolRoundTrip`, `ToolWrite` (other-port count 113), `Prohibited` (covered types, the copy's two values), `ToolEmit` (a quality measure branch), `EndpointCoverage` (two probes), `AnalyticsDescriptor`, `SaveHoldCoverage`, `ui/tools/analytics.test.mjs` (a Batch 2 test; the Batch 1 pin already allowed the model's `%Validate()`), `strings.ts`, `proposal-view.ts`, `screens.generated.ts`, `ci-throwaway.sh` (two comment lines; the new classes inherit the arming variable through `AnalyticsListingGroupBase`). `CompositeMintSweep` needed nothing: a measure has no composite id. Green after: those classes, `AnalyticsListingGroupWrite`, `AnalyticsListingWrite`, `AnalyticsListingGroupWriteEdge`, `AnalyticsListingGroupDatabase`, `AnalyticsQualityMeasureRead`, `Edge`, `Gate`, `PortGate`, `StageTwoTools`, `Descriptor`.

## Auto Run Result

Status: done
Blocking condition: none

- **Implemented:** the four measure writes (add, update, copy, delete) at both callers on 24.11's class-write path, its helpers lifted rather than copied (`AdmitClassWrite`, `WriteClass`, `RestoreClass`, `ClassWriteSnippet`; `ListingGroupText`, the tool base, form and save areas, test base, copy dialog and store parameterized); `QualityMeasureText`; the single-object read, `COPYTARGET`, pre-checks, audit and script forms in `AnalyticsPort`; five tool classes; the descriptor's actions and agent key; routes, baseline, error codes, the prohibited-set type; the client (page, dialog, store, maps, strings, mirror); the EXPERIENCE.md row; every roster.
- **Files:** 39 changed or added under `src/OcuPilot` (port, kernel, tools, areas, descriptor, tests), `ui/src/app` and `ui/browser`, `ui/tools/analytics.test.mjs`, `scripts/ci-throwaway.sh` (two comment lines) and EXPERIENCE.md (one row, one sentence).
- **Review:** 9 findings: patched 7 (P1 to P7: the lower-case own-code fixture outside every sweep, the not-compiled restore leg, stale legs for copy and delete, the disabled-group expression case, the read tool and screen reads after each write, the governance policy restore, "seven" refusals to "eight"), deferred 1 (a refused create's registry nodes need a seam that compiles then fails), rejected 1 (dialog component spec, covered by the browser spec); patched by verdict: medium 4, low 3. The intent audit's other divergences are spec-ruled or low, closed in the triage log.
- **Sweep catch:** shard 13 reddened `CompileWithoutInterop`: code-generated parameters on `ListingGroupForm` and the action base named `AnalyticsPort`, which the interoperability-free probe copy does not have while those classes compile. They are class methods now (`Endpoint`, `ReadType`, `RequiredReason`, `EditPairs`); the class and the 11 Analytics listing-group and quality-measure classes were re-run green afterward.
- **Verification:** the throwaway was rebuilt fresh before the final pass; `AnalyticsQualityMeasureWrite` (9) and `WriteEdge` (5) green on their first run on it. The (once) sweep, shards 1 to 17 of 17, green (shard 13 re-run after the catch above); shards 1 to 12 ran before that four-class change, so the 11 affected classes were re-run after it. `analytics.browser-spec.mjs` 11 of 11 after the change; `npm run build` clean (initial bundle 2.13 MB, under the 2,500 kB warning); `test:tools` 2,317 of 2,317 and `test:components` 3,584 of 3,584 (before the review patches, which changed no client code); `check-objectscript` 0 problems; `lint-docs` clean. Mutation lines are under Verification.
- **Follow-up review recommended: true.** Four medium findings were patched; the unverified risk is the post-review test legs (stale copy and delete, disabled-group expression) and the `Endpoint`/`ReadType` method change, run green but not re-reviewed.
- **Contended:** `Prohibited.cls` (one condition term, before and after recorded above), the roster test classes (add-only unions), `strings.ts`, `proposal-view.ts`, `screens.generated.ts`, EXPERIENCE.md, `ci-throwaway.sh` (comments only).
- **Risks:** `Splice` stops at the first line that is exactly `}` after the XData's opening brace, so a documentation item with such a line would be spliced short; the refused compile restores, so nothing is half-applied. A script form's free-name check reads the registry and the class, so it does not see an unregistered twin.
- **Ledger:** Declined DW-2734: Batch 3. DW-2725 gains an occurrence at harvest (copy read-back). The one `deferred:` item is for the harvest.
