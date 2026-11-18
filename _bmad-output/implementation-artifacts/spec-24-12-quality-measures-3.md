---
title: 'Story 24.12: Quality measures (Batch 3: the element and documentation writes)'
type: 'feature'
created: '2026-11-18'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-12-quality-measures-2.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-12-quality-measures.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-11-listing-groups-2.md'
warnings: ['oversized']
deferred: []
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

- [ ] **Task 0** (`ocupilot-b-ci`, USER, marked classes removed after): record under Design Notes › Measured: an item `Content` of plain text, text with `&` and `<`, and `<b>x</b>` written through `%XML.Writer` and read back by `%GetModel`; from that, the form both callers send so the read-back reads `matches`, and whether a content the class cannot hold is caught by reading the composed XML back with `%XML.Reader` before any save (then 422 `COMPILE`, nothing written, and that read journals nothing) or only by the compile's restore; that removing a group, an element and an item from the model and composing writes nothing; each `READBACKFIELDS` reading `matches` after a correct write.
- [ ] `AnalyticsPort.cls`: the endpoints' reads, writes, pre-checks, audit and script forms.
- [ ] The two action bases, six tools, two mints and the `MappingMint` parameter; the descriptors; the two Save areas and routes; `Baseline.cls`, `AnalyticsError.cls`, `Prohibited.cls`; the client pages, dialog kinds, maps and typed-name fallback; strings (once ruled), the regenerated mirror and the EXPERIENCE.md edits.
- [ ] Tests (each class at most about 500 lines, extending `Test/AnalyticsQualityMeasureBase.cls`, so armed by `OCUPILOT_ALLOW_PRINCIPALS`; arming roster comment add-only in `scripts/ci-throwaway.sh` with `ui/tools/ci.test.mjs`):
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

## Review Triage Log

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

**Mutations** (Rule 19; one per AC, recorded here by the implement stage as `mutation: <change> -> <test went red>`).

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

- Planned Batch 3 (six tools on Batch 2's class-write path, the tab group for DW-2734), halted after planning as directed. Nothing was implemented, and no instance was touched at plan.
- For the spec gate: three veto items under Design Notes (proposed strings and codes; no rename or reorder; Section kept as stored) and two proposed spine lines. The size fallback (3a/3b) is Decided in-stage 6.
