---
title: 'Story 24.12: Quality measures (Batch 3: the element and documentation writes)'
type: 'feature'
created: '2026-11-18'
status: 'done'
baseline_revision: 'e8257a0f20e34e0603193f17e6d1adf8470e903f'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-12-quality-measures-2.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-12-quality-measures.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-11-listing-groups-2.md'
warnings: ['oversized']
deferred:
  - summary: 'An element add naming a group that differs only in letter case from an existing one creates a second group'
    evidence: 'ApplyQualityMeasurePart matches the group exactly; the vendor %Validate refuses an enabled case twin (422 COMPILE, misleading) and keeps a disabled one, so a later enable of either is refused. A refusal needs a ruled sentence.'
    location: 'src/OcuPilot/Port/AnalyticsPort.cls ApplyQualityMeasurePart'
    severity: low
  - summary: 'The EXPRESSION refusal sentence names a missing group or brackets, not a group left with no enabled element'
    evidence: 'Removing or disabling the only enabled element, or disabling a group, answers REASONQUALITYMEASUREEXPRESSION, whose words describe neither case. A truer sentence needs ruling (EXPERIENCE.md).'
    location: 'src/OcuPilot/Api/AnalyticsError.cls REASONQUALITYMEASUREEXPRESSION'
    severity: low
  - summary: 'The group, element and item field captures repeat Collect''s field lists (Rule 2)'
    evidence: 'ReadQualityMeasureData''s g and m nodes and QualityMeasureElementRow/MetaRow repeat the $ListBuild fields of Collect''s part rows; a field added to one and not the other splits the list from the single read.'
    location: 'src/OcuPilot/Port/AnalyticsPort.cls ReadQualityMeasureData, Collect'
    severity: low
---

<intent-contract>

## Intent

**Problem:** Batches 1 and 2 (`spec-24-12-quality-measures.md`, `-2.md`, both `done`, code head `ae36e9ddc`) read quality measures and write a measure's header, but nobody can add, change or remove a measure's groups, elements or documentation items from OcuPilot, and the Documentation screen cannot be reached from a measure in the UI (DW-2734).

**Approach:** The element and documentation writes of U-111 (add, change, remove of each, the group fields riding on the element writes), each one confirmed proposal with two callers, on Batch 2's class-write path unchanged in kind: `PlanQualityMeasure` composes from `%GetModel(name, , 0)` read at the write, `WriteClass`/`RestoreClass` save, compile and restore, `ClassWriteSnippet` renders the script. The two sub-screens become one tab group, as the cube tabs are.

## Boundaries & Constraints

**Always:**

- **Tools and keys (AD-22).** `analytics.qualitymeasureelements.add`, `.set` and `analytics.qualitymeasuremetas.add`, `.set` ship `true`; `analytics.qualitymeasureelements.remove` and `analytics.qualitymeasuremetas.remove` are `DESTRUCTIVE`, ship `false`, and confirm with a typed name and the one removal consequence.
- **Targets (AD-13).** An element is `[QualityMeasure, Group, Name]` and an item `[QualityMeasure, Name]`, as Batch 1's rows carry them. An empty element `Name` names the group itself (the screen's empty-group row): `set` then changes only the group's fields and `remove` removes the group with every element in it; `add` needs a name. Names are kept exactly and never changed here.
- **Fields.** Element add: `Name`, `Caption`, `MDX`, `Disabled`, plus `GroupCaption`, `GroupDescription`, `GroupDisabled` (an add naming a group the measure lacks creates it at the end; on an existing group they change it, as set does). Element set: the same less `Name`; on a group target an element field is a shape violation. Item add: `Name`, `Caption`, `Content`, `Disabled`; item set: the same less `Name`. `Section` and part order are kept as stored. Lengths are the model's (`name` 250, `caption` and group `description` 2,000, `mdx` 32,000); `Content` is checked by Task 0's rule.
- **Gate and refusals, before any write, from both callers and the mint** (Batch 2's order and helpers, AD-8, AD-10, AD-29, AD-61, AD-65): `AdmitClassWrite` with `QUALITYMEASUREPAIRS`, `AtelierPort.Pairs()`/`WritePairs` and `^DeepSee.QMsrs`'s database; shape (`PORT.FIELD.SHAPE`); a measure not there (404 `ABSENT`), declared by two classes (409 `AMBIGUOUS`), or whose class `Prohibited.IsOcuPilotCode` holds (403 `PROHIBITED.OCUPILOTCODE`); a measure whose own model is linked (409 `LINKEDPARTS`, as the classic page makes them read-only, `UI/QualityMeasures.cls` :1686-1688); an element or item the target names that is not there (404 `PARTABSENT`); on add, a name the group or measure already holds, enabled or not, without regard to case (409 `ELEMENTTAKEN`, `METATAKEN`); then the composed model's `%Validate()` (422 `COMPILE`) and the expression check (422 `EXPRESSION`: removing or disabling a group or element the expression needs).
- **Refused compile** restores the prior text and recompiles it when it was compiled (422 `COMPILE`, compiler text logged, AD-39). **Audit, script form, read-back:** `ConfigChange` from either caller, a restored write with its outcome (AD-15); a script form per AD-59; read-back per AD-58 with `READBACKFIELDS`, a correct add or set reading `matches`, a remove `notFound`.
- **DW-2734.** Groups and elements (`tab.position` 1, the group's own route) and Documentation (2) declare `tab` group `analytics/quality-measures/elements` with their existing label keys, so a measure's name opens the pair and Documentation is its second tab; no new string.

**Never:**

- `%SaveQMsrDefinition`, `DeleteQMeasure`, `$System.OBJ.*` beyond `IsUpToDate`, `/api/deepsee` or `/api/atelier` over HTTP; `AnalyticsPort` names no `%Api.Atelier.*` class (AD-61).
- Renaming a group, element or item, or moving one (Design Notes › Veto items 2); writing `Section`; touching a measure's header (Batch 2) or U-34.
- A spine edit; an edit to `ui/angular.json`, `ui/vitest-base.config.mjs` or `scripts/ci-throwaway.sh`'s bring-up retry block; any edit to `Prohibited.cls`'s `Prohibits` condition line.

## I/O & Edge-Case Matrix

Rows run in USER on `ocupilot-b-ci`; each test makes and removes its own measures, classes `OcuProbeQMP.Analytics.*`, catalog `OcuProbeQMP` (AC6).

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Element add | New element in an existing group; in a new group with group fields | Element (and group) present; other groups, items, header and class members unchanged; read-back `matches` | - |
| Element set | Caption, MDX, Disabled and the three group fields | Element and its group changed, siblings unchanged | - |
| Group set | Target `[M, G, ""]`, group fields | Group changed, its elements unchanged | - |
| Element remove | Typed name; key turned on by the test | Element gone, group kept (an emptied group reads as its empty row) | - |
| Group remove | `[M, G, ""]`, the person's Remove group | Group and all its elements gone | - |
| Item add, set, remove | Name, Caption, Content (plain, `&`, markup), Disabled | Item as sent (Task 0's form); removed item gone | - |
| Taken | Add an element name the group holds (other case, or disabled); an item name the measure holds | Nothing written | 409 `ELEMENTTAKEN`; 409 `METATAKEN` |
| Absent | Set or remove of a missing element, group or item | Nothing written | 404 `PARTABSENT` |
| Expression | Remove or disable the only enabled element of `[Numerator]`; remove `Numerator` | Nothing written | 422 `EXPRESSION` |
| Linked | Any of the six writes on a linked measure | Nothing written | 409 `LINKEDPARTS` |
| Twin, own code, gate | As Batch 2's rows | Refused before any write, one leg per tool | 409 `AMBIGUOUS`; 403 `PROHIBITED.OCUPILOTCODE`; 403 naming the pair |
| Compile fails | 24.11's seam after the pre-checks | Prior text back, recompiled when it was | 422 `COMPILE` |
| Stale, key off | Class changed between mint and confirm; a remove at its shipped `false` | Target-changed; governance refuses | 409; 403 |

</intent-contract>

## Code Map

Paths under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-24` (HEAD `1a5988b06`). **Extend Batch 2 (`1b92f5a8a`, QA and review `d59b5bda0`) and 24.11's listing writes (`055317df8`) file for file.** Epic 21 has no commit beyond feature (`git log --no-merges origin/OCU-1-epic21 ^origin/feature/OCU-1_ocupilot-mvp`, empty on 2026-11-18), so no file is contended now; the implement stage re-runs it and marks any hit "(contended: add-only)".

- **`src/OcuPilot/Port/AnalyticsPort.cls`** (5,838 lines):
  - `Serves` :554 gains branches for `ENDPOINTQUALITYMEASUREELEMENTS` and `ENDPOINTQUALITYMEASUREMETAS` (new single reads `QUALITYMEASUREELEMENT`, `QUALITYMEASUREMETA`; writes `ENTRYADD`, `ENTRYSET`, `ENTRYREMOVE`); `IsQualityMeasureEndpoint` :5340 widened to the three endpoints, `ChangesQualityMeasures` :5353 to the part types; `Invoke`'s dispatch routes both to `InvokeQualityMeasure` :5654 with the endpoint, splitting the composite id as `InvokeListingGroup` :5005 does.
  - `ReadQualityMeasure` :5675, `PlanQualityMeasure` :5720, `QualityMeasureProblem` :5773, `PerformQualityMeasure` :5791, `QualityMeasureSnippet` :5826 and `QualityMeasureViolations` :5521 take the endpoint and the part (Batch 2 reserved `pPart`, Decided in-stage (implement) 2); `VendorQualityMeasureCompose` :5551 gains the six part operations on the model it already reads, and the linked and taken checks. Row builders beside `QualityMeasureRow` :5492 answer the element (`{QualityMeasure, Group, GroupCaption, GroupDescription, GroupDisabled, Name, Caption, MDX, Disabled, Version, Namespace}`) and item (`{QualityMeasure, Name, Caption, Section, Content, Disabled, Version, Namespace}`) rows, reusing `Collect`'s element and meta field reads. `WriteClass` :5232, `RestoreClass` :5267, `ClassWriteSnippet` :5296, `AdmitClassWrite` :4599, `OwnCodeRefusal` :5087 unchanged; audit verbs and entity parameters beside :492-500.
- **Tools (`src/OcuPilot/Screen/Tool/`, new):** `AnalyticsQualityMeasureElementAction` and `AnalyticsQualityMeasureMetaAction` extend `AnalyticsQualityMeasureAction` as `AnalyticsListingAction` extends the group base (descriptor, `READTYPE`, `READANSWERS`, `Endpoint`, `MintClass`, `IdArgument`, `InputSchema`, `TargetParts`, `ScreenActionDelta`); `AnalyticsQualityMeasureElement{Add,Set,Remove}` and `AnalyticsQualityMeasureMeta{Add,Set,Remove}` take the shapes of `AnalyticsListing{Add,Set,Remove}`. The element `remove` declares `SCREENACTIONS = "remove,remove-group"`, as `AnalyticsTermListImport` declares two. Mints: `AnalyticsQualityMeasureElementMint` as `InteropSettingMint` (`PARTARGUMENTS` `QualityMeasure,Group`), with a new `MappingMint` parameter (default off) that lets the last part be empty instead of refusing it at :76; `AnalyticsQualityMeasureMetaMint` as `AnalyticsListingMint`.
- **Descriptors:** `AnalyticsQualityMeasureElementList.cls` gains `primaryAction` `add`, `rowActions` `set`, `remove`, `remove-group`, `table.emptyAgentKey` in place of `emptyNextKey`, and `tab`; `AnalyticsQualityMeasureMetaList.cls` gains `add`, `set`, `remove`, the agent key and `tab`; both doc comments' "offers no action" and reach sentences replaced.
- **Saves (AD-55):** new `Area/Analytics/QualityMeasureElementSave.cls` and `QualityMeasureMetaSave.cls` extend `ListingSave.cls` (parent member `QualityMeasure`; the element's create id also joins `Group`, through a hook in the base if it has none); routes in `Api/Router.cls` beside :1998.
- **Kernel and API:** `Kernel/Governance/Baseline.cls` (six keys); `Api/AnalyticsError.cls` beside :254-296 and its rosters :412, :418; `Kernel/Proposal/Prohibited.cls`: `TYPEQUALITYMEASUREELEMENT` and `TYPEQUALITYMEASUREMETA` beside :802, `IsQualityMeasureType` :1242 body widened to the three types, `COVEREDTYPES` :311, the change lists beside :1347 and create lists beside :1521; the existing create and reviewed-few branches (:1795, :2023) serve the new types once the body is widened, so none is added. Line :1604 is not edited.
- **Client (`ui/src/app/`):** new `areas/analytics/quality-measure-element-list.page.ts` and `quality-measure-meta-list.page.ts` (+ specs) modeled on `listing-group-listing-list.page.ts`; the element page registers Remove group, starting `remove-group` on the row's id with its name part empty and the row's `Name` blanked; `quality-measure-dialog.ts` gains `kind` `element` and `documentation`, as `listing-group-dialog.ts` has `group` and `listing` (the element form's two fieldsets are legended Group and Element). Maps: `shell/screen-outlet.ts` `DESCRIPTOR_PAGES` :292; `shell/screen-action-handler.ts` `SCREEN_ACTION_DESCRIPTORS` :164, `UNDRAWN_ACTIONS` :548, `DESTRUCTIVE_CONSEQUENCES` :767, `TYPED_NAME_ROWS` :867, whose entry type gains an optional `fallback` field read when the `name` field is empty (used at :1480); `core/screen-actions.ts` :219; `core/proposal-view.ts` :422, :639; `core/strings.ts` (once ruled); `core/screens.generated.ts` (regenerated).
- **Rosters (Rule 30):** re-grep for `analytics.qualitymeasures.copy`, `AnalyticsListingAdd` and `analytics.listinggrouplistings.remove`; Batch 2's Verification roster names them (`ReadTool`, `SurfaceCoverage`, `Governance`, `GovernanceBaseline`, `ClassicPageGate`, `MappingDescriptor`, `ToolRoundTrip`, `ToolWrite`, `Prohibited`, `ToolDispatch`, `ToolEmit`, `EndpointCoverage`, `AnalyticsDescriptor`, `SaveHoldCoverage`, `CompositeMintSweep`, `screen-mirror.test.mjs`, `analytics.test.mjs`, `navigation.test.mjs`, `structural-walk.mjs`).
- **Fixture:** `Test/AnalyticsProbe.cls` `RemoveQualityMeasures`, `Left` and the base's `Snapshot` cover `OcuProbeQMP` (case-insensitive, as Batch 2's P1).
- **EXPERIENCE.md:** rows 614 and 615's "its two sub-screens offer no action" and 614's reach sentence replaced; one Fixed strings row appended after 615 once the strings are ruled.
- **Vendor (read only):** `irislib/%DeepSee/Model/QualityMeasure/{qualityMeasure,group,element,meta,node}.cls` (`%Validate`, lengths), `QualityMeasure/QualityMeasure.cls` :102-121 (enabled parts) and :250-300 (expression resolution), `UI/QualityMeasures.cls` (`editValue` :1284, `deleteItem` :1372, `addItem` :1484, linked read-only :1686-1688).

## Tasks & Acceptance

**Execution:**

- [x] **Task 0** (`ocupilot-b-ci`, USER, marked classes removed after): record under Design Notes › Measured: an item `Content` of plain text, text with `&` and `<`, and `<b>x</b>` written through `%XML.Writer` and read back by `%GetModel`; from that, the form both callers send so the read-back reads `matches`, and whether a content the class cannot hold is caught by reading the composed XML back with `%XML.Reader` before any save (then 422 `COMPILE`, nothing written, and that read journals nothing) or only by the compile's restore; that removing a group, an element and an item from the model and composing writes nothing; each `READBACKFIELDS` reading `matches` after a correct write.
- [x] `AnalyticsPort.cls`: the endpoints' reads, writes, pre-checks, audit and script forms.
- [x] The two action bases, six tools, two mints and the `MappingMint` parameter; the descriptors; the two Save areas and routes; `Baseline.cls`, `AnalyticsError.cls`, `Prohibited.cls`; the client pages, dialog kinds, maps and typed-name fallback; strings (once ruled), the regenerated mirror and the EXPERIENCE.md edits.
- [x] Tests (each class at most about 500 lines, extending `Test/AnalyticsQualityMeasureBase.cls`, so armed by `OCUPILOT_ALLOW_PRINCIPALS`; arming roster comment add-only in `scripts/ci-throwaway.sh` with `ui/tools/ci.test.mjs`):
  - new `Test/AnalyticsQualityMeasurePartWrite.cls`: the six writes by both callers, group set and remove, read-backs through `GET /screens/<id>/read` and the read tools, refusals (taken, absent, expression, shape), script forms;
  - new `Test/AnalyticsQualityMeasurePartWriteEdge.cls`: linked, twin, own code, compile fails, stale, key off, gate as principals;
  - `ui/browser/analytics.browser-spec.mjs`: open a measure, add an element in a new group, change it, remove it, remove the group; open the Documentation tab, add an item, change it, remove it; the two page specs; every roster above.

**Acceptance Criteria:**

- **AC1 (round trip, both callers).** Given each write through the screen action and the agent's confirmed proposal. When `%GetModel(name, , 0)` reads the class. Then the part holds exactly what was sent, every other group, element, item and header field is unchanged, and every class line outside the `QualityMeasure` XData is unchanged.
- **AC2 (Integration, Rule 1).** Given each write. When it is confirmed. Then `GET /screens/analytics.qualitymeasureelements/read` (or `.qualitymeasuremetas`) and the agent's read tool answer the new state, and the read-back verdict is `matches` (`notFound` for a remove).
- **AC3 (nothing half-applied).** Given the compile-fails seam on each write. When it runs. Then the class text, `^DeepSee.QMsrs` and the model equal their state before it.
- **AC4 (browser, DW-2734).** Given the probe. When a person opens a measure from Quality measures. Then Groups and elements and Documentation are its two tabs, and adding, changing and removing an element, a group and an item each show on the screen.
- **AC5 (governed, audited, declared).** Given the six tools. When the roster tests run. Then each declares `write`, `AnalyticsPort` and `%DeepSee.UI.QualityMeasures`; the baseline holds four keys `true` and two `false`; each write records `ConfigChange`; removing any one roster row reddens that test alone.
- **AC6 (leaves USER as found).** Given any new or changed test, in either order, on a fresh instance. When it ends. Then no marked class and no marked `^DeepSee.QMsrs` node remains.

## Spec Change Log

- 2026-11-18, spec gate: the runner kept the key states, the group-through-element model, no rename or reorder, the tab group for DW-2734, the proposed strings and the proposed spine lines (veto item U-113).
- 2026-11-18, implement (apply and report, Rule 5): the Boundaries' tab group `analytics/quality-measures/elements` cannot be declared (AD-5's registry accepts only `<parent>/document` for a parent-scoped group, with the head's route equal to it). Original: "declare `tab` group `analytics/quality-measures/elements`". Amended: the group is `analytics/quality-measures/document`, Groups and elements' route becomes that route, both screens are `detail` archetype (the one that draws the strip); the person-visible intent is unchanged. See Decided in-stage (implement) 1.

## Review Triage Log

### 2026-11-18 — Review pass

- verdicts: 14 findings — high 0, medium 4, low 8, false 0, maybe-false 2
- findings:
  - `[medium]` `[patch]` The four new refusal sentences and the removal consequence were not pinned across `AnalyticsError`, `strings.ts`, `proposal-view.ts` and EXPERIENCE.md — added the four rows, the `REMOVE` consequence pair and the two remove tools' `CONSEQUENCECODE` to `ui/tools/analytics.test.mjs` (green).
  - `[medium]` `[patch]` No audit-row assertion for the documentation item's change and removal or the group's removal, at either caller — added `Rows` and `AssertAgentRecords` legs in `AnalyticsQualityMeasurePartWrite` (green on first run).
  - `[maybe-false]` `[defer]` The pre-save XML read has no test reaching it with already-stored content — deferred, unverified medium; the recipe is in the frontmatter item.
  - `[low]` `[patch]` The AC2 mutation line named no mutation — replaced by the `Content` of `QualityMeasureMetaRow` made empty (red, reverted).
  - `[low]` `[patch]` No recorded mutation of the tab group — the Documentation `tab.position` made 1 reddens `AnalyticsDescriptor` (recorded).
  - `[low]` `[patch]` AC5 mutation covered one key only — the documentation remove key made `true` reddens `GovernanceBaseline` (recorded).
  - `[low]` `[reject]` The page specs' `Mutation (Rule 19)` comments are not recorded runs — the pinned behaviors have a recorded or applied mutation (the new group-only and add tests were observed red); no harm in the comments.
  - `[maybe-false]` `[reject]` The browser test asserts the probe's creation before its `try`, so a partial `SaveMeasure` skips cleanup — `SaveMeasure` is one atomic save and compile that restores on refusal; the harm is unlikely and the fix adds a branch.
  - `[medium]` `[patch]` No test confirms the dialog's group-only change or sends what the dialog builds — added a component test that confirms Change element on a group row and asserts the posted values are the three group fields.
  - `[medium]` `[patch]` An add into an existing disabled group re-enabled it, because the dialog always sent `GroupDisabled` — `addBody` now sends `GroupDisabled` only when set; a component test pins it and went red under the mutation.
  - `[low]` `[reject]` Line feeds in documentation content are dropped, so AC1's "exactly what was sent" does not hold for multi-line content — this is the model's stored form, measured in Task 0 and the form the intent's Task 0 rule asked for; the Auto Run Result lists it as a risk.
  - `[low]` `[reject]` `analytics.test.mjs` checks `.OpenString(` against `%XML.Reader` counts as source text — a guard against file, stream and URL readers, which is what it states.
  - `[low]` `[reject]` Intent alignment: the tab group is `analytics/quality-measures/document`, not `.../elements` — the registry (AD-5) allows only `<parent>/document` for a parent-scoped group, so the named spelling cannot be declared; the person-visible result (two tabs under a measure's name) is the intent's. Recorded in the Spec Change Log as an apply-and-report amendment.
  - `[low]` `[reject]` Intent alignment: no alias for the old Groups and elements route — the route has not left this branch (inference: no persisted link to it exists outside the branch); not worth a redirect.

### 2026-11-18 — Code review (Batch 3, four layers on Opus)

- verdicts: 33 findings — high 0, medium 7, low 22, false 1, maybe-false 3; patch 12, defer 3, reject 18, intent_gap 0
- findings:
  - `[medium]` `[patch]` `QualityMeasureTarget` raised `<NULL VALUE>` on an empty id (probed), so a part endpoint answered an internal error, not 422 — `$ListGet`; `PartWriteGaps` `TestAnEmptyOrPartlessTargetIsAShapeRefusal`.
  - `[medium]` `[patch]` The own-code test's nothing-written check could not see Batch 1's probe class — class text and model legs, plus an element removal and a group change leg (`PartWriteEdge`).
  - `[medium]` `[patch]` `AMBIGUOUS` was pinned at the port only and two mints — the person's call for eight write shapes and all six mints (`PartWriteEdge`).
  - `[medium]` `[patch]` The refused-compile test summed two audit rows of seven writes — one row with the outcome restored per write.
  - `[medium]` `[patch]` The routes' 404 for a missing measure was not pinned to its code and sentence — both routes now assert `ANALYTICS.QUALITYMEASURE.ABSENT` and `ReasonFor`'s sentence.
  - `[medium]` `[patch]` A script-form refusal could not be told from a script that threw — `PartBase.ScriptRefusal` and the two sentence legs.
  - `[medium]` `[patch]` AC4's group change had no browser leg — the Batch 3 browser test changes the emptied group and reads it back.
  - `[low]` `[patch]` Ticking the group's Disabled on Add element was never shown to be sent — element page spec test.
  - `[low]` `[patch]` The pre-save reader also refuses Batch 2's update of a measure with stored content, untested — an update leg in `PartWriteGaps`.
  - `[low]` `[patch]` Stale doc comments (`IsQualityMeasureEndpoint`, `QualityMeasureViolations`, `QualityMeasureProblem`, `VendorQualityMeasureCompose`, `ReadQualityMeasure`, the element mint's superclass) — replaced.
  - `[low]` `[patch]` `PartWriteGaps` was missing from the arming comment and `PartBase`'s header — one add-only comment line, header widened.
  - `[low]` `[patch]` `TestEachRefusalWritesNothing`'s comment claimed every content leg reddens — corrected to the one leg the recorded mutation reddens.
  - `[false]` `[reject]` "Making `ContentNormalized` the identity reddens nothing" — applied: the quote and line-break read-back legs went red; mutation line added.
  - `[low]` `[defer]` A case-variant group name on an element add creates a twin group — needs a ruled sentence (frontmatter).
  - `[low]` `[defer]` The `EXPRESSION` sentence does not describe a group left with no enabled element — needs a ruled sentence (frontmatter).
  - `[low]` `[defer]` The part field captures repeat `Collect`'s field lists (Rule 2) — frontmatter.
  - `[maybe-false]` `[reject]` A plain single read of a linked measure's part reads its own model while the list shows the master's — would be low; settle by reading one listed row of a linked measure through `QUALITYMEASUREELEMENT`.
  - `[low]` `[reject]` The mint's add read matches exactly while the write's taken check ignores case — both refuse with the taken sentence before any write, and the class `Version` closes a stale proposal.
  - `[low]` `[reject]` Content the model cannot hold is refused with the compile sentence — Task 0 rules 422 `COMPILE`.
  - `[maybe-false]` `[reject]` `LINKEDPARTS` is not a precondition code, so a measure linked after a mint may not close target-changed — the confirm still refuses before any write; Batch 2's update omits `LINKED` alike.
  - `[low]` `[reject]` Remove element on an emptied group's row removes the group — the same write as Remove group, typed with the group's name under the one consequence.
  - `[maybe-false]` `[reject]` An agent remove that omits `Name` becomes a group removal — the card and the typed group name confirm it, and the key ships off.
  - `[low]` `[reject]` Change element opens on the list row's values — Decided in-stage (plan) 4, as Change listing.
  - `[low]` `[reject]` Normalized content can outgrow its length after the Save's check — the port refuses it before any write.
  - `[low]` `[reject]` A group carrying the separator is refused under `Name` — refused before any write; label only.
  - `[low]` `[reject]` The XML reader guard in `analytics.test.mjs` is weaker — adjudicated in the review pass above.
  - `[low]` `[reject]` AD-65 does not yet name the pre-save `%XML.Reader` — no spine edit here; the Proposed spine lines carry it to the owner.
  - `[low]` `[reject]` The Boundaries still name `.../elements`, and the pass above said the old route had not left this branch — it is on the feature branch, not on main, so no released link breaks; the Change Log records the amendment.
  - `[low]` `[reject]` Two departures are recorded under Design Notes, not the Change Log — spec edit; Decided in-stage (implement) 3 and 6 record them.
  - `[low]` `[reject]` `Prohibited.cls` changed `COVEREDTYPES` in place and `IsQualityMeasureType`'s doc line — a roster union (Decided in-stage (plan) 7) and no logic.
  - `[low]` `[reject]` Short Rule 2 copies (the Saves' parent hooks, `TargetParts`, `ArgumentProblem`, `ComposeCreate`, the three `At` loops) — one to six lines each; a shared base would couple the listing and quality measure tools or read worse.
  - `[low]` `[reject]` The Auto Run Result's counts and risk lines disagree with the tests — spec edit; this log and Verification hold the current state.
  - `[low]` `[reject]` Two `MintRefused` legs accept any `TOOL.ARGUMENTS` sentence — `PartWriteGaps` pins the sentences for the taken and expression cases.

## Design Notes

**Ruled (not re-opened).** U-111: this is Batch 3, the last; the story is `done` when it is. Batch 1's agent phrases "add an element to this quality measure" and "add documentation to this quality measure" are ruled and become the two descriptors' `emptyAgentKey` strings. U-108/U-110/U-112 and every Batch 2 rule carry over.

**Decided in-stage (plan).**

1. **Groups ride on elements (U-111).** No group tool: an element add names a group (created when new), element set carries the three group fields, and `[M, G, ""]` names the group. The person's Remove group is a second screen action id of the element `remove` tool (`remove-group`, as `import-local` is of `import`), so one key governs both; the page starts it on the row's id with its name part empty.
2. **A taken name is refused enabled or not, without regard to case.** `%Validate` skips disabled parts, but the composite ids key by name, so a disabled twin would make one id name two parts.
3. **The removal consequence is one sentence** for an element, a group and an item; a typed name is the element's or item's `Name`, and the group's name through `TYPED_NAME_ROWS`' new `fallback` when the row's name is empty.
4. **Change dialogs open on the row's values** (as Change listing does); no form route is added.
5. **DW-2734** is addressed by the tab group (Boundaries), which needs no new string; the name cell already opens the group's first tab.
6. **Size.** One pass: six tools on Batch 2's lifted path. If the implement stage finds it too large, the boundary is 3a (Groups and elements, DW-2734) and 3b (Documentation).
7. **Contention.** In `Prohibited.cls` only added lines and the one widened `IsQualityMeasureType` body; the `COVEREDTYPES` entries are a roster union.

**Measured** (implement, 2026-11-18, `ocupilot-b-ci`, USER; `OcuProbeQMP*` classes removed after, `^DeepSee.QMsrs` empty after):

- **Item `Content`** (the model's `content`: `%ZEN.Datatype.html`, `CONTENT=MIXED`, `ESCAPE=HTML`), written by `%XML.Writer` and read back by `%GetModel`: plain text, `<b>x</b>`, entities such as `&amp; &lt;` and a tab read back as sent; a quote reads back as `&quot;`, an apostrophe as `&#39;`, `€` as `&euro;` and a no-break space as `&nbsp;` (the last two are XML entities the format does not define), and line feeds are dropped (`one`, LF, `two` reads `onetwo`). A bare `&` or `<`, `]]>` and a control character wrote XML the compile refused (`ERROR #6301`), after the class was saved.
- **`%XML.Reader.OpenString` over the composed text** refused each of those before any save; with `%GetModel`, `%Validate`, the writer and the removals it recorded no set or kill in the process's journal (0 records). So a content the class cannot hold is caught before any save (422 `COMPILE`, nothing written), and the compile's restore is the second line.
- **The form both callers send** is the model's (`NormalizedContent`: written, read back, line feeds dropped), which reads back as sent; a content whose form does not survive a second write unchanged (`€`, a no-break space) is refused 422 `COMPILE`, because writing its stored form again would refuse every later write of the measure.
- **Removing a group, an element and an item** from the model composes and writes nothing; `RemoveAt` of a member that is not the last leaves a gap in the relationship and the model's own `%Validate` threw `<INVALID OREF>`, so the port clears the relationship and puts the rest back in order (`RemoveFromRelationship`).
- **Read-back:** each `READBACKFIELDS` read `matches` after a correct write at both callers (`AnalyticsQualityMeasurePartWrite`); a remove reads `notFound`.

**Decided in-stage (implement).**

1. **The tab group's route.** AD-5's registry rule makes a parent-scoped group its parent list's `<route>/document` with the head's route equal to it, so Groups and elements' route is `analytics/quality-measures/document` (not `.../elements`) and Documentation keeps `.../documentation` as position 2. Both are `detail` archetype, the one whose page draws the strip (`DetailPage`, as the cube tabs and Item settings are); their pages wrap `<app-detail-page />`, and a measure's name cell opens the document route (`documentScreenFor`).
2. **One dialog.** `QualityMeasureDialog` gained `kind` (`measure`, `element`, `documentation`); a group's row with no element opens Change element on the group's fields alone.
3. **A group target takes no element field.** A merged payload repeats the group row's empty element fields, so an element field on a group target is a shape violation only when it holds text or `true`.
4. **Shared code.** `ItemSave.IdOf` takes the body, so `QualityMeasureElementSave` joins `Group` into the id; `ListingSave` lifted `ParentEndpoint`, `ParentReadType` and `ParentAbsentCode`; the port's four wrappers (`QualityMeasureElement`/`Meta` `Violations`/`Problem`) carry the endpoint to the tool base's signatures; `AnalyticsQualityMeasureBase` gained `AssertStale` (lifted from the edge class) and `Recorded`'s type; `AnalyticsQualityMeasurePartBase` holds the part tests' fixtures.
5. **Namespace.** The composing code runs in the analytics namespace, where this product's classes are not mapped, so the composite separator is a literal port parameter (`PARTSEPARATOR`, pinned equal to `EntityId`'s by `AnalyticsQualityMeasurePartWriteEdge`).
6. **Linked and absent order.** A write's read refuses a linked measure first (409 `LINKEDPARTS`), so a mint on a linked measure answers it before looking for the part; a missing part at the mint is the generic mint's `TOOL.ARGUMENTS`, and its own `PARTABSENT` is the port's and the person's.
7. **`MappingMint.EMPTYNAMEALLOWED`** is the new parameter's name; `ui/tools/analytics.test.mjs`'s guard now allows an XML reader that opens a string.
8. **Size.** One pass; the 3a and 3b split was not needed.

**Veto items for the spec gate (recommended defaults, planned as written).**

1. **Proposed strings** (added to `strings.ts` and EXPERIENCE.md only once ruled). Reused: "Group", "Name", "Caption", "Description", "Disabled", "MDX", "Content", "Groups and elements", "Documentation", and the save consequence "The quality measure's class is saved and compiled."
   - Actions: "Add element" · "Change element" · "Remove element" · "Remove group" · "Add documentation item" · "Change documentation item" · "Remove documentation item".
   - The element form's second fieldset legend: "Element".
   - Consequence (every removal): "Removing a group removes every element in it. A removed group, element or documentation item cannot be restored from OcuPilot."
   - Refusals: "This group already holds an element with that name." · "This quality measure already holds a documentation item with that name." · "This group, element or documentation item no longer exists." · "This quality measure is linked to another measure, which defines its groups and documentation."
   - Codes: `ANALYTICS.QUALITYMEASURE.ELEMENTTAKEN`, `.METATAKEN`, `.PARTABSENT`, `.LINKEDPARTS`; consequence `ANALYTICS.QUALITYMEASURE.REMOVE`. No suggested prompt is added: the registry requires none per action, and Batch 1's three per screen stay.
2. **No rename, no reorder.** The classic editor renames a group, element or item and moves one up or down. A rename is a remove and an add here, as 24.11 refused a listing rename, because names key the ids. Order changes no value: the vendor collects a group's elements by name with `$Order` and resolves groups by name (`QualityMeasure.cls` :102-121, :250-300), and the screen sorts by group and name; added parts append.
3. **Section and the item's order are kept as stored**; the classic editor writes neither, and a Section field would need a new label.

**Governing ADs (Rule 6).** AD-3, AD-4, AD-6, AD-14, AD-15, AD-22, AD-34, AD-40, AD-51, AD-52, AD-53, AD-54 (adds), AD-55, AD-56, AD-58, AD-59 (the write set); AD-8, AD-16, AD-29, AD-61, AD-65 (gate and namespace); AD-5 and AD-44 (tabs, actions, classic page); AD-13 (composite ids); AD-10 (own code); AD-39 (compiler text); AD-11 and AD-60 (MDX and content are untrusted text).

**Proposed spine lines (the owner's attended update; never written here).** AD-65: "Story 24.12's element and documentation writes compose from `%GetModel(name, , 0)` on the same class-write path; a linked measure's groups and documentation are refused." AD-22: "`analytics.qualitymeasureelements.remove` and `analytics.qualitymeasuremetas.remove` ship `false`." If Task 0 adopts the pre-save XML read: AD-65's pure reads gain `%XML.Reader` over the composed text.

**Integration and linkage (Rules 1, 2).** `Consumes:` Batch 1's `QualityMeasureElements` and `QualityMeasureMetas` reads; Batch 2's `PlanQualityMeasure`, `VendorQualityMeasureCompose`, `WriteClass`, `RestoreClass`, `ClassWriteSnippet`, `AdmitClassWrite`, `AnalyticsQualityMeasureAction`, `QualityMeasureDialog`; 24.11's `AnalyticsListing*` tools, `ListingSave`, `listing-group-listing-list.page.ts`; `InteropSettingMint`/`MappingMint`. `Consumed-by:` no story consumes these tools; Story 24.20's undo applies to the write path as a whole. AC2 is the Integration AC. Sibling copies with reasons: the two pages repeat the listings page's wiring over other descriptors and dialogs (DW-2744 accepted the same for Batch 2).

**Ledger inbox.** DW-2734: addressed (Boundaries, AC4).

## Verification

**Commands** (one `ci-runner` call per message; the throwaway is `ocupilot-b-ci`):

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.AnalyticsQualityMeasurePartWrite`, then the same for `AnalyticsQualityMeasurePartWriteEdge`, `AnalyticsQualityMeasureWrite`, `AnalyticsQualityMeasureWriteEdge`, `AnalyticsQualityMeasureWriteReal`, `AnalyticsQualityMeasureRead`, `AnalyticsQualityMeasureEdge`, `AnalyticsQualityMeasureGate`, `AnalyticsListingGroupWrite` (the `MappingMint` and `ListingSave` hooks), each roster class under Code Map and every class the shared-surface sweep changes. Expected: green.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`. Expected: green.
- `(loop)` `cd ui && npm run build`, `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/analytics.browser-spec.mjs browser/analytics-links.browser-spec.mjs`. Expected: green.
- `(once)` the full ObjectScript sweep: `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17`, one call per shard, k = 1 to 17. Expected: green.
- `uv run scripts/check-objectscript.py`, `bash scripts/lint-docs.sh`. Expected: clean. The full browser suite is left to CI.

**Shared surfaces:** the two sub-screens' actions, empty states and tab group, the governance baseline, the write-tool rosters under Code Map, `Router.cls`'s routes, `AnalyticsError`'s code rosters, `Prohibited`'s covered types, `MappingMint`'s mints, `ListingSave`'s subclasses, `TYPED_NAME_ROWS`, the arming roster in `ci-throwaway.sh` and `ci.test.mjs`, and `ci-timings.json` (no rows for the new classes).

**Hermeticity:** every test added or changed passes on its first run on a fresh instance, in either order.

**Mutations** (Rule 19; each server mutation applied to the throwaway's `src` copy, the class and its subclasses recompiled, observed red, then the tree synced back from the worktree (`diff -rq` identical) and reloaded; the client one reverted, rebuilt and redeployed):

- mutation (AC1): the MDX line of an element add in `ApplyQualityMeasurePart` made `0 &&` -> `AnalyticsQualityMeasurePartWrite` `TestAnElementIsAddedByEachCallerAndReadsBack` went red on its model and read-back legs, `TestAnElementAndItsGroupAreChangedByEachCaller` on its read-back and model legs.
- mutation (AC2): the `Content` of `QualityMeasureMetaRow` made `""` -> `AnalyticsQualityMeasurePartWrite` `TestADocumentationItemIsAddedChangedAndRemovedByEachCaller` went red on its read-back legs.
- mutation (AC3): `RestoreClass` made to return at once -> `AnalyticsQualityMeasurePartWriteEdge` `TestARefusedCompileUndoesEachPartWrite` went red on the class text and model legs of all seven writes.
- mutation (AC4): the add element store call made to post to the documentation items' route (bundle rebuilt and redeployed) -> the browser test timed out waiting for the new element row; `fallback` dropped from the Groups and elements' `TYPED_NAME_ROWS` entry -> the typed-name test in `screen-action-handler-qualitymeasure.spec.ts` and the Remove group test in the element page's spec went red; both reverted, rebuilt and green.
- mutation (AC4, tab group): the Documentation descriptor's `tab.position` made `1` -> `AnalyticsDescriptor` `TestTheSevenDeclarationsRegister` and `TestTheCubeManagerDeclaration` went red.
- mutation (AC5, documentation key): the `analytics.qualitymeasuremetas.remove` line of `Baseline.cls` made `true` -> `GovernanceBaseline` `TestThePurgeIsTheOneDisabledLine` went red.
- mutation (AC5): the element remove line of `Baseline.cls` made `true` -> `TestAnElementAndAGroupAreRemovedAndTheKeyShipsOff` went red on its refusal and still-there legs; the `analytics.qualitymeasureelements.set` row removed from `SurfaceCoverage` -> `TestEveryWriteToolHasACoverageRowAndBack` went red alone.
- mutation (AC6): the part markers left out of `AnalyticsProbe.RemoveQualityMeasures` -> `AnalyticsQualityMeasurePartWriteEdge` went red at `OnAfterAllTests`, naming the leftover classes.
- mutation (separator): `PARTSEPARATOR` made `2` -> `AnalyticsQualityMeasurePartWriteEdge` `TestThePartSeparatorIsTheCompositeSeparator` (and the stale-class test) went red.
- mutation (linked): the linked checks of `VendorQualityMeasureCompose` and `ReadQualityMeasure` made `0 &&` -> `TestALinkedMeasureRefusesEverySixPartWrites` went red on its six port legs, three person legs and mint legs.
- mutation (content): the `NormalizedContent` refusal in `ApplyMetaPart` made `0 &&` -> `TestEachRefusalWritesNothing` went red on its `&euro;` leg (the legs whose XML is invalid stay green, because the reader refuses them first).
- mutation (QA, pre-save reader): the `%XML.Reader` check in `VendorQualityMeasureCompose` made `0 &&` -> `AnalyticsQualityMeasurePartWriteGaps` `TestStoredDocumentationThatCannotBeWrittenAgainIsRefusedBeforeAnySave` went red alone, on its audit-row legs and the mint leg (the compile's restore still answers 422 and leaves the text unchanged, so only the audit row and the mint tell the two refusals apart); reverted, the deferred item above is closed by this test.
- mutation (QA, person's refusals): the element add's taken check made `tHeld && tElementAt` -> `TestThePersonsRoutesRefuseTakenAbsentAndExpressionWrites` went red on its case and disabled legs and `TestTheAgentsMintsAreRefusedWithTheWritesOwnSentence` on its disabled-element leg.
- mutation (QA, agent's sentences): `QualityMeasureProblem` made to answer the fault's code instead of its sentence -> `TestTheAgentsMintsAreRefusedWithTheWritesOwnSentence` went red alone, on its six sentence legs.
- mutation (QA, emptied group): the `GroupCaption` line of `ApplyQualityMeasurePart` made to need an element name -> `TestAnEmptiedGroupIsChangedAndFilledAgain` went red alone.
- mutation (QA, mended measure): the element `Disabled` line of `ApplyQualityMeasurePart` made to apply only to an add -> `TestAWriteThatMakesTheExpressionHoldCompilesARegisteredMeasure` went red on all five legs and `TestThePersonsRoutesRefuseTakenAbsentAndExpressionWrites` on its disabling legs.
- mutation (review, empty target): `QualityMeasureTarget` reading the measure with `$List` -> `AnalyticsQualityMeasurePartWriteGaps` `TestAnEmptyOrPartlessTargetIsAShapeRefusal` went red on its eight empty-id legs.
- mutation (review, Batch 2 update on stored content): the `%XML.Reader` check of `VendorQualityMeasureCompose` made `0 &&` -> `TestStoredDocumentationThatCannotBeWrittenAgainIsRefusedBeforeAnySave` went red on the update's audit leg with the part legs.
- mutation (review, ambiguous): the `listed > 1` check of `ReadQualityMeasure` made `0 &&` -> `TestTwoClassesThatDeclareAMeasureRefuseEveryPartWrite` went red on its six mint legs.
- mutation (review, own code): the plan's own-code check made `0 &&` and a refusal added after `WriteClass` -> `TestOwnCodeIsRefusedByEveryPartWrite` went red on its class text and model legs.
- mutation (review, restored audit rows): the element set's verb in `PerformQualityMeasure` made the add's -> `TestARefusedCompileUndoesEachPartWrite` went red on the set's row and outcome legs alone.
- mutation (review, route 404): `QualityMeasureElementSave.ParentAbsentCode` removed -> `TestTheRoutesAnswerJsonEnvelopesOfTheDeclaredShape` went red on the elements route's 404 leg.
- mutation (review, script refusal): the refusal line of `QualityMeasureSnippet` made to also throw -> `TestEachWritesScriptFormMakesTheSameChange` went red on its two sentence legs.
- mutation (review, normalized content): `AnalyticsQualityMeasureMetaAction.ContentNormalized` made to return its argument -> `TestADocumentationItemIsAddedChangedAndRemovedByEachCaller` went red on the quote and line-break read-back legs.
- mutation (review, ticked group flag): `addBody` made to skip `GroupDisabled` always -> the element page spec's "sends GroupDisabled true ... when the group's Disabled is ticked" went red alone.
- mutation (review, AC4 group change): the dialog's change made to skip `GroupCaption` (bundle rebuilt and redeployed) -> the Batch 3 browser test went red on its group change leg; reverted, rebuilt, redeployed and green.

**Verification roster** (the Rule 30 grep for `analytics.qualitymeasures.copy`, `AnalyticsListingAdd` and `analytics.listinggrouplistings.remove`, re-run): `ReadTool` (516 tools), `SurfaceCoverage` (six rows), `Governance` and `GovernanceBaseline`, `ClassicPageGate`, `MappingDescriptor`, `ToolRoundTrip`, `ToolWrite` (other-port count 121), `Prohibited` (covered types), `EndpointCoverage` (two probes), `AnalyticsDescriptor` (routes, tab positions, actions, archetype), `SaveHoldCoverage`, `CompositeMintSweep` (two mints), `Navigation`, `ToolNavigateContract`, `ui/tools/screen-mirror.test.mjs`, `ui/tools/navigation.test.mjs`, `ui/tools/analytics.test.mjs`, `ui/browser/structural-walk.mjs`, `strings.ts` (one line reference moved), `proposal-view.ts`, `screens.generated.ts`. **Contended with Epic 21 (add-only or generated):** `EXPERIENCE.md`, `Baseline.cls`, `Prohibited.cls` (the widened `IsQualityMeasureType` body and added lines only), `ReadTool`, `ToolWrite` (the tool counts), `strings.ts`, `screens.generated.ts` (regenerate at merge) and the roster tests above. Green on the throwaway after: the two new classes, those roster classes, `AnalyticsQualityMeasure{Write,WriteEdge,WriteReal,Read,Edge,Gate}`, `AnalyticsListingWrite`, `AnalyticsListingGroupWrite`, `AnalyticsListingGroupWriteEdge`, `Descriptor`, `PortGate`, `StageTwoTools`; `test:tools` 2,330 of 2,330; `test:components` 3,595 of 3,595 (run in directory slices); the two analytics browser specs 18 of 18; the initial bundle 2.14 MB.

## Auto Run Result

Status: done
Blocking condition: none

- **Review:** 14 findings (medium 4, low 8, maybe-false 2); patches applied: four medium (sentence roster, audit-row legs, group-only change test, add into a disabled group no longer enables it) and three mutation lines; one item deferred (unverified medium); the rest rejected with reasons in the Review Triage Log. Follow-up review recommended: the client dialog's payload change and the deferred pre-save reader are the unverified risks; the verification pass also fixed `PARTSEPARATOR` (a literal now, because the probe namespace compiles the port without this product's classes).
- **Verification (lead, final tree):** both new classes green on their first run on a rebuilt `ocupilot-b-ci` (7 and 7 tests); full ObjectScript sweep 17 of 17 shards green on the final code; `test:tools` 2,330; component slices (analytics 69, shell 1,264) green; both analytics browser specs 18 of 18 after the final bundle; `check-objectscript` and `lint-docs` clean.
- **Implemented:** the six element and documentation writes at both callers on Batch 2's class-write path (the port's reads, plan, compose, restore, audit and script forms; six tools, two bases, two mints and two Saves with routes; descriptors, baseline, error codes, the prohibited-set types), the tab group for DW-2734 (Decided in-stage 1), the client (two pages, the dialog's two kinds, maps, strings, mirror) and the EXPERIENCE.md row.
- **Verification:** under Verification (the loop commands; the full `(once)` sweep is the lead's). `AnalyticsQualityMeasurePartWrite` (7) and `PartWriteEdge` (6) green on their first run; `check-objectscript` 0 problems; `lint-docs` clean.
- **Risks:** a measure whose stored documentation holds `&euro;` or `&nbsp;` refuses every write until its class is edited; line feeds in an item's content are not kept (the vendor's read drops them), and any write that composes the class rewrites an existing item's content the same way. The contended files are listed under Verification.
