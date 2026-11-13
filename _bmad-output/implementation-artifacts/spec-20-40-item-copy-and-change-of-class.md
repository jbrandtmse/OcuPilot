---
title: 'Story 20.40: Item copy and change of class'
type: 'feature'
created: '2026-11-12'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** A production item can be added, enabled, disabled and removed in OcuPilot (Story 20.3), but copying one still needs the classic per-host Actions tab. The vendor's `CopyConfigItem` (`EnsPortal/ProductionConfig.cls` :6265-6302) clones the item, renames it, stores it disabled, gives a business process with pool size 0 a pool size of 1, saves the production class and audits the add. Its own name check only refuses a name held with the same class.

**Approach:** Add a `COPY` item write to `Port/InteropPort`'s Items endpoint (AD-62) and one create tool, `interop.items.copy`, that extends the item add (AD-54). Two callers reach it (AD-53, AD-55): a Copy row action on Production items that opens a new-name dialog and posts to a new `POST /interop/items/copy` Save, and the agent's confirmed proposal. Change of class moves to a split child (Design Notes › Split).

## Boundaries & Constraints

**Always:**

- The copy is an item write, so it keeps every rule of one:
  - it goes through `InteropPort.Invoke` behind the port's gate (AD-29);
  - its pairs are `%Ens_ProductionConfig:WRITE` and WRITE on the namespace's globals and routines databases, as the add's are, and each refusal names its pair (AD-8);
  - a namespace under source control is refused `INTEROP.ITEM.SOURCECONTROL`;
  - the production is opened at concurrency 4 and the production class is saved (`SaveToClass`).
- It is a create (AD-54). Its id is the new item's composite `[Production, Name]`, and its fresh read must find no item of that name in any letter case. It is stricter than the vendor here, because OcuPilot names an item by name alone.
- Its one argument beyond the id is `CopyFrom`, the source item's name in the same production. The payload is `CopyFrom`, `Enabled` false and the composed `Namespace`. The port reads the source under the write's open lock and copies it as it stands then.
- The vendor shape is `%ConstructClone(1)`, then the new `Name`, `Enabled` 0, `PoolSize` 1 for a business process whose pool size is 0, `Items.Insert`, `%Save`, `AuditModifyProductionConfig` and `SaveToClass` on the copy.
  - `Ens.Config.Production.%OnAddToSaveSet` re-points the clone's `Production` at the saved production (:633-645).
  - The audit text names the operation and the two items, never a value: `item added by OcuPilot as a copy of <source>`. An agent write also carries the AD-15 marker.
- The copy is not destructive: the copy is created disabled, and Remove undoes it. Its key `interop.items.copy` ships `true` (AD-22).
- A running production is never updated, started or stopped by a copy. The copy is disabled, so a production that reads update pending does so as after an add (Task 0 (b)).
- Edits to shared rosters are add-only. FR-80 holds: no new descriptor, port endpoint, entity type or declared read; the one new route is the copy's Save.

**Never:**

- No change of class (split child), no copy across productions, and no caller-supplied class, pool size, category, comment or enabled flag on a copy.
- Never call `CopyConfigItem` or any `EnsPortal.*` method, never call `%Api.InteropEditors.*`, and never write a vendor global directly.
- No `Ensemble` include and no `Ens.*` type in a signature (AD-62 (12)).
- No edit to `Screen/Tool/Write.cls`, `Screen/Tool/InteropItemRemove.cls`, `Api/Error.cls`, `Screen/Registry.cls`, `ui/src/app/core/navigation.ts`, `.github/workflows/ci.yml`, `ui/tools/ci-*.mjs` or `ui/tools/ci-timings.json`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Copy | `Name` free in any case, `CopyFrom` held once | A new item with the source's class, settings, category and comment, `Enabled` false, read back (AD-58); the vendor's `ModifyConfiguration` row names it; the class keeps it through a recompile | — |
| Pool-size-0 process | The source is a business process with `PoolSize` 0 | The copy reads `PoolSize` 1; the source is unchanged | — |
| Name taken | Any item holds `Name` in any case | — | 409 `INTEROP.ITEM.TAKEN` at the Save's absence read and at the mint; 409 again at the write |
| Taken since mint | Another item takes `Name` between mint and confirm | — | The confirm's re-read closes the proposal target-changed (AD-54) |
| Bad name | `Name` fails `NameProblem` | — | 422 `INTEROP.ITEM.NAME` on `Name` |
| No source | `CopyFrom` empty or naming no item (a wrong JSON type is 422 `PORT.FIELD.SHAPE`) | — | 422 `INTEROP.ITEM.COPYSOURCE` on `CopyFrom`; a source removed after the mint is 409 `COPYSOURCE` at the write, nothing written |
| Source twice | Two items share `CopyFrom`'s name | — | 422 `INTEROP.ITEM.AMBIGUOUS` on `CopyFrom`; 409 at the write |
| Source control | The namespace uses source control | — | 409 `INTEROP.ITEM.SOURCECONTROL`, before anything is read |
| Unknown production | — | — | 404 `PORT.NOTFOUND` |
| Gates | A caller missing one declared pair | Refused before any vendor call | 403 naming the pair |
| Namespace | No interoperability | — | 409 `INTEROP.NAMESPACE` |

</intent-contract>

## Code Map

Line numbers are on `ac902dcd`. Stories 20.25 and 20.26 land first and shift them, so Task 0 re-anchors. Symbols marked "(20.25, planned)" do not exist yet.

### Port and errors

- `src/OcuPilot/Port/InteropPort.cls`:
  - Types: `TYPEADD` :314. `IsItemWrite` :780, which drives `Serves` :905 and `Admit`'s routines WRITE (:1097).
  - Rules: `NameProblem` :1478, `AddViolations` :1502 (the shape and switched-judging model for the new `CopyViolations`), `ProductionHeld` :1556.
  - `ItemRefusalToken` :1600 (ADD → `TAKEN`), `ReadItem` :1746 (the ADD inversion :1752), `ItemObject` :1773.
  - `PerformItem` :1809: the ADD body check :1820, the ADD branch :1878-1891 (insert, `%Save`, audit, `SaveToClass`), the after-read :1905.
  - `ItemSnippet` :5140 (ADD :5151), the AD-59 draft.
  - `IsItemRunWrite` (20.25, planned) and its types stay apart from `COPY`.
- `src/OcuPilot/Api/InteropError.cls`: `ITEMTAKEN` :112, `ITEMAMBIGUOUS` :117, `ITEMPENDING` :149, `Codes` :466, `ConsequenceCodes` :472, `ItemCodes` :478, the second item list :488, `ReasonFor`. `Api/Error.ReasonForViolation` routes `INTEROP.*` here (:1237, :1454), so `Error.cls` needs no edit.

### Tools, route and kernel

- `src/OcuPilot/Screen/Tool/InteropItemAdd.cls`: the parent. `CREATES`, `READBACKTOOL` (`InteropItemEnable`), `ComposeCreate` (Namespace and `Enabled` false), `PortQuery` (`ACTIONKEY` = `WRITETYPE`), `ArgumentProblem` and `ConfirmProblem`. `InputSchema` pushes `ClassName` to `required` unconditionally.
- Precedent: `Screen/Tool/UserCopy.cls` extends `UserCreate` with `CopyFrom`, `SOURCEARGUMENT` and an `InputSchema` override.
- `src/OcuPilot/Area/Interop/ItemSave.cls`: `POST /interop/items`. Subclass seams: `CREATETOOL`, `Violations`, `ParentHeld`, `TAKEN*`. `Create` passes the body minus `Production` and `Name`, plus the id argument. Precedent: `Area/Permissions/UserCopy.cls` extends `UserCreate` over `POST /users/copy`.
- `src/OcuPilot/Api/Router.cls`: `/interop/items` :272 and its `Call=` target `InteropItemCreate` :1921.
- `src/OcuPilot/Screen/Descriptor/InteropItemList.cls`: `rowActions` :46 (20.25, planned, adds stop, start and restart after disable).
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls`: the production-item create list :1361 and its create branch :1567. Story 18.29's user-copy branch :1560 is the model.
- `src/OcuPilot/Kernel/Governance/Baseline.cls`: items :225-228.

### Client

- `ui/src/app/areas/interoperability/interop-item-list.page.ts`: registers `add` (:84); the copy registration and dialog go beside it.
- `interop-item-add-dialog.ts` and `interop-item-add.store.ts`: the dialog's field markup and its store's refusal handling. `interop-create.ts`'s `postInteropCreate` is the shared poster.
- Row-action precedent: `areas/os-management/namespace-list.page.ts` :137, :192 (a page-run row action reads `selection()[0]`). `core/entity-id.ts` `splitCompositeId`.
- `ui/src/app/core/screen-actions.ts`: `DESCRIPTOR_ACTION_LABELS` InteropItemList :162.
- `ui/src/app/core/proposal-view.ts`: `CONSEQUENCE_INTEROPITEMPENDING` :383, `consequenceSentence` :545.
- `ui/src/app/core/strings.ts`: the item block :6709-6871. EXPERIENCE.md :173 is the Dialogs line; :604 is the Fixed-strings row, where clauses are appended.

### Tests

- `Test/InteropItemControl.cls`, armed by `OCUPILOT_ALLOW_PRINCIPALS`: its class-method helpers `MintAs`, `ConfirmHttp`, `Save`, `Items`, `StoredEnabled`, `ClassEnabled`, `Recompile`, `Audited`. The add leg is at :387.
- `Test/ProductionProbe.cls`: `AddItem` :203 can hold a name twice and add a setting. `scripts/ci-throwaway.sh`: the item `# classes:` line :480.
- Rosters this story moves (Rule 30):

| File | What |
|---|---|
| `Test/ReadTool.cls` :93 | registry count +1 and the sorted names |
| `Test/ToolWrite.cls` :1326 | other-port writes +1 |
| `Test/ToolRoundTrip.cls` :100 | `interop.items.copy:TOOL.ARGUMENTS` in `REFUSEEMPTY` |
| `Test/SurfaceCoverage.cls` :428 | a coverage row |
| `Test/EndpointCoverage.cls` :286 | a probe row for `POST /interop/items/copy` |
| `Test/GovernanceBaseline.cls` | the baseline line order |
| `Test/InteropItemDescriptor.cls` | the row actions (contended: append only) |
| `ui/browser/interop-items.browser-spec.mjs` | the Copy leg |
| `ui/tools/interop.test.mjs` | `SENTENCES` |

## Tasks & Acceptance

**Execution:**

- [ ] **Task 0, on `ocupilot-b-ci` (USER, auditing on, the probe production).** Record each result under Design Notes › Measured.
  - (a) Re-anchor the Code Map on the branch head, where 20.25 and 20.26 have landed. Read `ToolWrite`'s other-port count and `ReadTool`'s registry count; this story's pins are each one above them.
  - (b) A copy through the port's vendor shape leaves:
    - one production row;
    - the item count up by one;
    - the copy's settings equal to the source's;
    - the source unchanged;
    - one `ModifyConfiguration` row.
    Also record whether a running production then reads `NeedsUpdate` true.
  - (c) A principal holding only the add's pairs can copy.
  - (d) Grep `src/OcuPilot/Test` and `ui/tools` for a check that every declared row action resolves a tool with `SCREENACTIONS`. If one exists, the page-run `copy` joins its exemption, as `add` is exempt as a primary action. A check with no exemption mechanism is `## Clarification Needed`.
  - A result that changes destructiveness, the key default, the audit choice or the pairs is `## Clarification Needed`.
- [ ] `src/OcuPilot/Port/InteropPort.cls`:
  - Add `TYPECOPY` `COPY` to `IsItemWrite`, so `Serves` and the routines WRITE follow.
  - `ItemRefusalToken`: `COPY` refuses `TAKEN` as `ADD` does. `ReadItem` inverts for `COPY` as for `ADD`.
  - Add `CopyViolations(pNamespace, pProduction, pName, pBody, .pViolations)`. It checks `NameProblem`; then `CopyFrom`, refused `PORT.FIELD.SHAPE` for a wrong JSON type and `COPYSOURCE` for an empty string; then, admitted and switched as `AddViolations` is, the source's count: 0 is `COPYSOURCE`, more than one is `AMBIGUOUS`.
  - `PerformItem`, `COPY`: `CopyViolations` first (422). Then, under the open lock: `TAKEN` for the new name, `COPYSOURCE` or `AMBIGUOUS` for the source (409), the vendor shape of Boundaries, and the new item read back.
  - Add an `ItemSnippet` `COPY` branch (AD-59), and refresh the header doc and `PerformItem`'s doc.
  - Rule 31: `COPY` extends the `ADD` branch and `AddViolations`' model. It is not a second path.
- [ ] `src/OcuPilot/Api/InteropError.cls`:
  - add `ITEMCOPYSOURCE` `INTEROP.ITEM.COPYSOURCE` to `Codes`, `ItemCodes`, the second item list and `ReasonFor`;
  - add consequence `ITEMCOPY` `INTEROP.ITEM.COPY` to `Codes`, `ConsequenceCodes` and `ReasonFor`.
- [ ] `src/OcuPilot/Screen/Tool/InteropItemAdd.cls`: `InputSchema` pushes `ClassName` to `required` only when `SettableFields` lists it (a hook, so the copy inherits cleanly).
- [ ] `src/OcuPilot/Screen/Tool/InteropItemCopy.cls` (new, extends `InteropItemAdd`):
  - `TOOLNAME` `interop.items.copy`; `WRITETYPE` `COPY`; `FIELDS` `CopyFrom`; `FieldRows` of `CopyFrom`, a string.
  - `READBACKFIELDS` `Name,Enabled`; `CLASSICPAGES` `""`, as the item siblings on the same page declare none (AD-44).
  - `CONSEQUENCECODE` `INTEROP.ITEM.COPY`; `PRECONDITIONCODES` `TAKEN`, `COPYSOURCE`, `AMBIGUOUS`, `SOURCECONTROL` and `INTEROP.NAMESPACE`.
  - `InputSchema`: `CopyFrom` described and required.
  - `ArgumentProblem` uses the port's `CopyViolations` over the id's production.
  - `DESCRIPTION` in the siblings' plain words. It is agent-facing and decided at implement.
- [ ] `src/OcuPilot/Area/Interop/ItemCopy.cls` (new, extends `ItemSave`): `CREATETOOL` `InteropItemCopy`, and `Violations` → `CopyViolations`. The order of the Save is unchanged.
- [ ] `src/OcuPilot/Api/Router.cls`: `POST /interop/items/copy` → `InteropItemCopy` → `ItemCopy.HandleCreate`, beside :272.
- [ ] `src/OcuPilot/Kernel/Proposal/Prohibited.cls`: the production-item create branch admits `CopyFrom` for a `COPY` write only. Model it on Story 18.29's user-copy branch.
- [ ] `src/OcuPilot/Kernel/Governance/Baseline.cls`: append `"interop.items.copy": true`.
- [ ] `src/OcuPilot/Screen/Descriptor/InteropItemList.cls`: add `copy` to `rowActions` before `remove`, which stays last. Refresh the doc.
- [ ] Client:
  - `ui/src/app/areas/interoperability/interop-item-copy.store.ts` (new): the name, the busy flag and refusals, posting `{Production, Name, CopyFrom}` through `postInteropCreate` with tool `interop.items.copy`. It is a new store, not a subclass of the add store, whose six-field state the copy never uses (Rule 31).
  - `interop-item-copy-dialog.ts` (new), on the add dialog's model: the copy consequence as a banner, the reason alert, one Name field with `interopItemAddNameHint`, and a primary Copy that is `aria-disabled` while the name is blank or a copy is in flight. It uses only classes the add dialog uses (client-lint family 7).
  - `interop-item-list.page.ts`: register `copy`. It opens the dialog with the selected row's name, never over another dialog.
  - Specs for the store and the dialog.
- [ ] `ui/src/app/core/screen-actions.ts`: `copy: STRINGS.auditDatabaseCopyConfirm` ("Copy") in InteropItemList's labels.
- [ ] `ui/src/app/core/proposal-view.ts` and `ui/src/app/core/strings.ts`: the `INTEROP.ITEM.COPY` consequence and the ruled strings, appended to the item block.
- [ ] `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`: append the ruled strings as a clause to :604's row, and Copy item to :173's Dialogs line. Then run `npm run test:tools`.
- [ ] `src/OcuPilot/Test/InteropItemCopy.cls` (new, armed by `OCUPILOT_ALLOW_PRINCIPALS`): one leg per Matrix row, each on its own probe items, created and removed in the test, using `InteropItemControl`'s class methods.
  - The agent's leg is mint, HTTP confirm and read-back, and checks the audit row and the recompile. The Save leg is `POST /interop/items/copy`.
  - The Gates leg uses `InteropItemGate`'s principal generator. The `PORT.FIELD.SHAPE` sub-case is unit-tested on `CopyViolations`.
- [ ] `scripts/ci-throwaway.sh`: `InteropItemCopy` on a `# classes:` line.
- [ ] The Code Map's rosters, then sweep `src/OcuPilot/Test`, `ui/browser`, `ui/tools` and the `ui/src` specs for the old shape of each (Rule 30).
- [ ] `ui/browser/interop-items.browser-spec.mjs`: on the deployed bundle, a Copy leg. It copies a probe item through the row action, asserts the dialog's consequence, and sees the new row disabled with the source's class, then removes it.
- [ ] DW-2298 (owned by 20.25 until its adjudication re-owns it): the copy residual is closed by AC1-AC3, and the change-of-class residual goes to the split child.

**Acceptance Criteria:**

- AC1: Given an item, when a copy is proposed by the agent and confirmed, or chosen as the Copy row action and saved in its dialog, then it runs through `InteropPort` as an AD-54 create. The new item reads back disabled with the source's class, and the vendor's `ModifyConfiguration` row names it.
- AC2 (Integration): given a copy of a probe item that holds a setting, when the copy's Item settings tab (Story 20.22's `interop.itemsettings` read) is read, then it lists the source's value for that setting.
- AC3: Given each Matrix refusal, when the copy is saved or confirmed, then it is refused by its code before any vendor write, and the production is unchanged.
- AC4: Given the copy, when its tool, its governance key and the audit after a confirmed run are inspected, then they match Design Notes (AD-22). Destructiveness is none, the key's default is `true`, and the audit record is the vendor's event plus the marker for an agent write. Task 0's results are recorded there, and the change-of-class charter is stated under Split.
- AC5: Given a caller missing one declared pair, when it copies by either caller, then it is refused 403 naming that pair.
- AC6: Given the new tool, when `Test/ToolWrite` and `Test/ReadTool` run, then each count reads exactly one above the branch's value before this story.

## Spec Change Log

- 2026-11-12, spec gate (runner): change of class chartered as Story 20.41 (split); the three new strings and the secret-named settings choice are veto item U-25; the AD lines stay for the owner's Update, not written.

## Review Triage Log

## Design Notes

**Governing ADs:** AD-3, AD-8, AD-10, AD-13, AD-14, AD-15, AD-16, AD-22, AD-29, AD-34, AD-44, AD-52, AD-53, AD-54, AD-55, AD-58, AD-59, AD-62. Checked with nothing to add:

- AD-51: the copy is a create, not action-style.
- AD-36: no declared read.
- AD-21 and AD-27: no path and no `%Api.*`.
- AD-56: the Save carries no declared value of an action route.

The story complies with every AD as it stands.

**Read at this plan** (source only; no instance call was made):

- `CopyConfigItem` :6265-6302 is described under Problem and Boundaries.
- Its client checks edit permission and edit database (:6227-6231). It refuses a name with leading or trailing spaces, and offers `<name>2` only in its prompt text.
- After a copy into a running production, the client asks for an update. OcuPilot never updates on an item write (AD-62).
- `GetHyperEventResources` gives `CopyConfigItem` the page's `EDITRESOURCE`, `%Ens_ProductionConfig:WRITE` (:7909). That is the add's pair, so the posture equals the classic portal's.
- `Ens.Config.Item.Production` is a plain reference (:17), and `Settings` is a list of serial `Ens.Config.Setting`. The clone's settings are copies, and `%OnAddToSaveSet` re-points `Production`.

**Decisions (AD-22):**

| Action | Tool and key | Destructive | Audit record |
|---|---|---|---|
| Copy one item | `interop.items.copy`, `true` | no: the copy is created disabled, and Remove (a person's row action, or the agent's `interop.items.remove` once its key is on) deletes it | vendor `%Ensemble/%Production/ModifyConfiguration` through `AuditModifyProductionConfig`, "item added by OcuPilot as a copy of …", plus the AD-15 marker |

**Decided in-stage:**

- The dispatch said to reuse the epic context, which predates today's spine edit, so it was not recompiled. This plan read the ADs it cites directly.
- A held name in any case is refused, stricter than the vendor, because OcuPilot identifies items by name (AD-62).
- The source is copied as it stands at the write. The card shows `CopyFrom`, and a removed source is refused. A source that changed since the mint is copied as it now is, as the classic page copies it.
- The dialog's name field starts empty. The classic `<name>2` is only a prompt hint.
- The row-action label and the button reuse "Copy" (`auditDatabaseCopyConfirm`), and the field reuses Name and the add's name hint.

**For the runner (veto window, secrets handling):** the clone carries every setting of the source, a secret-named one included, server-side, as the classic copy does. No value is read, shown, logged or sent by OcuPilot, so AD-35 holds (inference). Recommendation: keep it so. A refusal would be stricter than the classic portal.

**Split (the runner charters it; it moves an AC, so the runner classifies it).** Copy alone already takes the spec past the template's budget. Change of class moves to a new Story 20.41, "Item change of class", planned after this one. The key and title of 20.40 stay as they are, as 20.25 kept its own. The charter, read in source:

- `HostChangeClass` (:7702-7760) sets `ClassName`. It removes every Host setting the new class does not declare or whose `<Name>IsValid` fails, and the same for every Adapter setting against the new class's adapter. Then it saves the item, calls `SaveToClass`, and audits "class changed … from X to Y". The pair is `%Ens_ProductionConfig:WRITE` (:7911).
- Destructive: the dropped settings cannot be restored. Key `interop.items.changeclass` ships `false` (recommendation). The card lists each setting that would be dropped, as removed rows (Epic 23's `Write.RemovalRows` if it has landed).
- The picker: `EnsPortal.Dialog.ChangeClass` lists `Ens.ContextSearch/BusinessServices`, `BusinessProcesses` or `BusinessOperations` by the item's host type, and `AllBusinessHosts` for an unrecognized type. Each is the compiled, non-abstract subclasses of `Ens.BusinessService`, `Ens.BusinessProcess` or `Ens.BusinessOperation` (`Ens/ContextSearch.cls` :842-1010). The port's `ListClasses` (:1180) already reads `SubclassOf` for Processes.
- The new read is a read tool, so it meets 23.12's `Test/ReadDescriptions` roster: title, row phrase and fields, plus a label if it joins the "Processes" group. Recommendation: an item-group tab or an unlisted descriptor with one `item` criterion. The child's plan decides.
- It carries the 20.40 AC "each runs through the port … and the vendor's own audit records it" for the change of class, and the destructiveness AC verbatim.

**New strings for the runner** (proposed wording; the runner rules on each):

- `interopItemCopyTitle`, the dialog title: "Copy item".
- `INTEROP.ITEM.COPY`, the dialog's banner and the card: "The copy is added to this production disabled, with this item's class and settings. A business process that runs in the shared actor pool is copied with a pool size of 1. Enable the copy to run it."
- `INTEROP.ITEM.COPYSOURCE`: "This production holds no item of that name to copy."

**For the owner's attended Update** (the story complies without them):

- AD-62's Story 20.3 sentence would read `ADD`, `COPY`, `REMOVE`, with a copy as a create over the new name's absence that clones the source disabled.
- AD-22 would gain "`interop.items.copy` ships `true`".

**Integration ACs, Consumes, Consumed-by:**

- Integration: AC2. The consumer is `InteropItemSettingList` (20.22), read against `ocupilot-b-ci`, together with the Production items list (20.3).
- Consumes: 20.3's `InteropItemAdd`, `ItemSave`, the `ADD` path and `postInteropCreate`; 20.22's settings read; `Test/ProductionProbe`.
- Consumed-by: Story 20.41, the split, which adds the next item write beside `COPY`; and 20.12/20.36 workflows (inference).

**Ledger inbox (Rule 17):** none of the story's own. DW-2298 is cited in Tasks: the copy residual is this story's, and change of class goes with the split.

**Contended (Epic 23, checked 2026-11-12 at `98dce68a`):** of this story's files, Epic 23 changes `Test/InteropItemDescriptor.cls`, appending one method at the end, so this story only appends there. Epic 23 also changes `Write.cls`, `InteropItemRemove.cls`, `Api/Error.cls` and `epics.md`, which this story does not edit; `epics.md` takes only the runner's split charter. Its new `ui/tools/client-paths.test.mjs` is not on this branch yet (inference: it pins client paths to router routes, and the new path has its route).

## Verification

**Shared surfaces:**

- the Production items row actions
- the write-tool rosters (`ReadTool` +1, `ToolWrite`'s other-port count +1, `ToolRoundTrip`, `SurfaceCoverage`, `ToolEmit`, `EndpointCoverage`)
- the governance baseline
- `InteropPort`'s `Serves`
- the production-item create list in `Prohibited`
- the probe production
- the Fixed-strings row and the Dialogs line

*Every test added or changed passes on a fresh environment, in either order.*

**Setup (the implement stage only):** common.md's load and redeploy recipes, targeting `ocupilot-b-ci`. `ocupilot-slot-b` is for read-only SQL only.

**Commands** (each sized to about 150 s, one class or spec file per call, `timeout: 600000`; totals read from `%UnitTest_Result`):

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one class per call:
  - `InteropItemCopy`, `InteropItemControl`, `InteropItemGate`, `InteropItemRefusals`, `InteropItemDescriptor`;
  - `ReadTool`, `ToolWrite`, `ToolRoundTrip`, `ToolEmit`, `SurfaceCoverage`, `EndpointCoverage`, `GovernanceBaseline`, `Governance`, `Prohibited`, `ReadDescriptions`, `Descriptor`, `CompileWithoutInterop`;
  - and every class the sweep changes.
- `(loop)` `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/interop-items.browser-spec.mjs`, on the redeployed bundle.
- `(loop)` `cd ui && npm run test:tools`, and as a separate call `cd ui && npm run test:components`. Both pass, `name-links.test.mjs` included.
- `(loop)` `cd ui && npm run build`: it passes, with client-lint family 7 clean and the bundle under the fixed 2,500 kB warning.
- `(loop)` `uv run scripts/check-objectscript.py <changed .cls>` and `bash scripts/lint-docs.sh`, both clean.
- The full ObjectScript sweep, `npm test`, the smoke and Rule 30's fresh check are the runner's. The full browser suite is CI's.

**Planned pinning mutations (Rule 19):**

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | The `COPY` branch keeps the source's `Enabled` | the agent leg's "disabled" read-back |
| AC1 | The `COPY` branch skips `SaveToClass` | the recompile assertion |
| AC2 | The clone becomes `%New(ClassName)` | the settings-tab leg |
| AC3 | `ReadItem` stops inverting for `COPY` | the name-taken leg |
| AC3 | `CopyViolations` drops the source count | the no-source leg |
| AC5 | `InteropItemCopy` sets `ROUTINESDATABASE` 0 | `InteropItemCopy`'s routines-pair leg |
| AC1 | The browser spec's dialog posts to `/interop/items` | the browser Copy leg |

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
