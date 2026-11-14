---
title: 'Story 20.41: Item change of class'
type: 'feature'
created: '2026-11-12'
status: 'done'
baseline_revision: '906b7b292fa7fa3cd257964abf9c861359ea15c6'
baseline_commit: '906b7b292fa7fa3cd257964abf9c861359ea15c6'
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

**Problem:** Changing a production item's class still needs the classic per-host Actions tab. The vendor's `HostChangeClass` (`EnsPortal/ProductionConfig.cls` :7702-7760) sets `ClassName`, then removes every stored setting the new class does not take, which cannot be undone. A Host setting is removed unless the new class declares it in `GetSettings` and its `<Name>IsValid` accepts the value. An Adapter setting is judged the same way against the new class's adapter. Any other target is removed. It then saves the item, saves the production class and audits the change. Its dialog, `EnsPortal.Dialog.ChangeClass`, offers the classes `Ens.ContextSearch` lists for the item's kind.

**Approach:** Add an action-style `CHANGECLASS` item write to `Port/InteropPort` (AD-51, AD-62), whose `ITEM` read is composed from the chosen class and answers the settings it would drop. Add one destructive tool, `interop.items.changeclass`, reached by two callers (AD-53). The first is a Change class row action on Production items: a class picker, then a dry run listing what is dropped, then the typed-name confirmation. The second is the agent's confirmed proposal, whose card lists each dropped setting as a removed row. Add a new read endpoint, `ItemClasses`, and an item tab over it, Classes, which the picker reads and which gives the agent its read tool.

## Boundaries & Constraints

**Always:**

- The change is an item write, so it keeps every rule of one:
  - it goes through `InteropPort.Invoke` behind the port's gate (AD-29);
  - its pairs are `%Ens_ProductionConfig:WRITE` and WRITE on the namespace's globals and routines databases, then the custom resource of `EnsPortal.Dialog.ChangeClass` (AD-44), and each refusal names its pair (AD-8);
  - a namespace under source control is refused `INTEROP.ITEM.SOURCECONTROL`;
  - the production is opened at concurrency 4, and the production class is saved (`SaveToClass`).
- **The candidate classes** are the vendor dialog's.
  - For a service, a process or an operation, they are the compiled, non-abstract subclasses of `Ens.BusinessService`, `Ens.BusinessProcess` or `Ens.BusinessOperation` (`Ens/ContextSearch.cls` :842-1010), read through `%Dictionary.ClassDefinition:SubclassOf`, which writes nothing.
  - For an item whose class reads as no business host (Type `unknown`), they are all three lists, as `AllBusinessHosts` gives them.
  - The write accepts only a class on that list, and only one other than the item's own.
- **The dropped set** is the vendor's rule, unchanged. One port method computes it (`DroppedSettings`), and both the read and the write call it. The write calls it again under the open lock.
- **It is destructive.** Its key, `interop.items.changeclass`, ships `false` (AD-22). Its card and its dialog draw the destructive treatment, and the person types the item's name.
- **A secret-named dropped setting** is named on the card with no value (AD-35). Its value takes no part in the digest.
- **The reviewed set is the written set.**
  - The read answers `Digest`, a SHA-256 over the class change and the dropped set.
  - A person's action carries back the digest it was reviewed at, as `Reviewed`. The agent's payload carries its own `Digest`.
  - The write recomputes the digest under the lock and refuses `INTEROP.ITEM.REVIEWCHANGED` when it moved, before anything is written.
- **The audit** is `Ens.Util.Auditing.AuditModifyProductionConfig` with `item class changed by OcuPilot from <old> to <new>`, plus the dropped settings' `Target.Name` list. It never carries a value. An agent write also carries the AD-15 marker.
- A running production is never updated, started or stopped by the change. A running production then reads update pending, as after an enable (Task 0 (b)).
- Edits to shared rosters are add-only.

**Never:**

- No copy, temporary stop, start or restart (Stories 20.40 and 20.25).
- Never call `HostChangeClass`, any `EnsPortal.*` method or `%Api.InteropEditors.*`, and never write a vendor global directly. A macro that reads `^oddDEF` is not used: the dictionary classes are.
- No `Ensemble` include and no `Ens.*` type in a signature (AD-62 (12)).
- No new `Api/Router.cls` route: the action and the dry run use the screen action routes, and the picker uses the screen read route.
- No edit to `Screen/Tool/Write.cls`, `Screen/Tool/InteropItemRemove.cls`, `Api/Error.cls`, `Screen/Registry.cls`, `ui/src/app/core/navigation.ts`, `epics.md`, `.github/workflows/ci.yml`, `ui/tools/ci-*.mjs` or `ui/tools/ci-timings.json`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Change | A probe item of class `Op` holding Host `HangSeconds`, changed to `TearOp` | `ClassName` reads `TearOp`. `HangSeconds` is gone, and a setting `TearOp` takes is kept. One `ModifyConfiguration` row names the item. The class keeps the change through a recompile. | — |
| Card | The same item, proposed | A `ClassName` row (old → new), then one removed row per dropped setting, `Host.HangSeconds` showing `5` | — |
| Secret | The item also holds Host `ApiToken` | Its removed row has an empty value. The read, the card, the ledger and the audit carry no value for it. | — |
| Nothing dropped | Every stored setting is taken by the new class | Only the `ClassName` row. It is still a destructive card. | — |
| Unknown kind | The item's class is not compiled | The Classes tab lists services, processes and operations. Any of them is accepted. | — |
| Moved since review | A setting is added or changed between a person's dry run and the action | Nothing written | 409 `INTEROP.ITEM.REVIEWCHANGED` |
| Moved since mint | The same between the agent's mint and its confirm | Nothing written | The confirm's re-read closes the proposal target-changed (AD-51) |
| Not a candidate | `NewClass` is not compiled, is abstract, or is of another kind | — | 409 `INTEROP.ITEM.NEWCLASS`, at the composed read and again at the write |
| Same class | `NewClass` is the item's own class | — | 409 `INTEROP.ITEM.SAMECLASS` |
| Bad argument | `NewClass` is empty, not a string, longer than 128 characters, or not class-name shaped | — | The tool's argument refusal (`TOOL.ARGUMENTS`), or the screen's value refusal, before any read |
| Name twice | Two items share the name | — | 409 `INTEROP.ITEM.AMBIGUOUS`, on the picker read too |
| Source control | The namespace uses source control | — | 409 `INTEROP.ITEM.SOURCECONTROL`, before anything is read |
| Absent | The item or the production is not there | — | 404 `PORT.NOTFOUND`, on the picker read too |
| Gates | A caller missing one declared pair | Refused before any vendor call | 403 naming the pair |
| Namespace | No interoperability | — | 409 `INTEROP.NAMESPACE` |

</intent-contract>

## Code Map

Line numbers are on `a6c49d6d`. Stories 20.25, 20.26 and 20.40 land first and shift them, so Task 0 re-anchors. Symbols marked "(20.N, planned)" do not exist yet.

### Port and errors

- `src/OcuPilot/Port/InteropPort.cls`:
  - Endpoints: `ENDPOINTS` :98, `ENDPOINTITEMTEST` :158 (the model for a new `ENDPOINTITEMCLASSES`), `Pairs` :851, `Serves` :901, the `Invoke` dispatch (:1017-1030).
  - Pairs: `PRODUCTIONPAIRS` :189 and `ITEMWRITEPAIRS` :256. Keys: `DIGESTKEY` :606, `ITEMKEY` :599, `IDKEY` :672, `ACTIONKEY` :676.
  - Types: `TYPEITEM` :308, `TYPEREMOVE` :316. `IsItemWrite` :780 drives `Serves`, `Pairs` and `Admit`'s routines WRITE (:1109). `TYPECOPY` is 20.40's (planned); `IsItemRunWrite` is 20.25's (planned).
  - The class list: `ListClasses` :1175, the `SubclassOf` reader to extend or follow.
  - Items: `InvokeItems` :1429, `AddViolations` :1502 (the switched-judging model), `ItemRefusalToken` :1600, `GatherItems` :1655, `ItemRow` :1702, `ReadItem` :1746, `ItemObject` :1773.
  - `PerformItem` :1809: the enable branch :1868-1870 (`EnableConfigItem`, then `SaveToClass(item)`), the remove branch's audit :1899, the after-read :1905.
  - The item-criterion list model: `InvokeItemTest` :6209 and `ItemParts` :2017.
  - The settings: `GatherSettings` :2211, and `SettingRow`'s redaction :2380 (`IsCredentialName`).
  - The digest: `Sha256Hex` :3796. The review-digest model is the resend: `ReadResend` :3942 and `PerformResend` :3993.
  - The AD-59 draft: `ItemSnippet` :5140.
- `src/OcuPilot/Api/InteropError.cls`:
  - item codes: `ITEMAMBIGUOUS` :117, `ITEMREMOVE` :153;
  - lists: `Codes` :466, `ConsequenceCodes` :472, `ItemCodes` :478 and the second item list :488;
  - `RESENDCHANGED` :407 and its list :558 (the model for `REVIEWCHANGED`), and `ReasonFor`.
  - `Api/Error.ReasonForViolation` routes `INTEROP.*` here, so `Error.cls` needs no edit.

### Tools, descriptors and kernel

- `src/OcuPilot/Screen/Tool/InteropItemAction.cls`: the parent (`READANSWERS`, `STATEMARKER`, `TargetName`, `InputSchema`).
- The siblings this tool takes its parts from:
  - `Screen/Tool/InteropMessageAction.cls` and `InteropMessageResend.cls`: `DRYRUN`, `DryRunReview`, `PortQuery` with `Reviewed` or `Digest`, the fresh read as payload in `MergeUpdate`, `SCREENVALUES` and `SCREENOPTIONAL`, and a subject that carries what the port query needs.
  - `Screen/Tool/InteropTransformTest.cls`: an argument composed into the read (`PortQuery`), `ArgumentProblem` and `ConfirmProblem`.
  - `Screen/Tool/InteropItemRemove.cls`: the removed-row shape. Epic 23's `Write.RemovalRows` (not on this branch) builds fixed-name rows only.
- `src/OcuPilot/Screen/Descriptor/InteropItemTestTab.cls`: the item-group tab to copy the shape of (position 7, `item` criterion, `parentScope`). Also `InteropItemSettingList.cls`. `InteropItemList.cls`: `rowActions` :46.
- `src/OcuPilot/Kernel/Governance/Baseline.cls`: items :225-228.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` :1749-1754: the production-item branch is `ReviewedFewOnly`. For an action-style write the payload equals the re-read, so no field reads changed, and no edit is planned (inference; the confirm leg pins it).

### Client

- `ui/src/app/areas/interoperability/interop-item-list.page.ts`: registers `add` :79-80, with copy beside it (20.40, planned). Precedent for a page-run row action: `areas/os-management/namespace-list.page.ts` :137 and :192.
- A store reading another screen's read: `areas/security/ldap-editor.store.ts` :24 and `areas/permissions/user-create-form.store.ts` :25. A dialog's markup: `interop-item-add-dialog.ts`.
- `ui/src/app/shell/screen-action-handler.ts`:
  - `DRY_RUN_ACTIONS` :380, `dryRunFor` :1488, `startDryRun` :1521, `openReview` :1533 (its typed name is `id` today), `reviewLinesOf` :1870 (first row only);
  - the destructive consequences :615, `TYPED_NAME_ROWS` :697. The message header page is the dry-run caller: `interop-message-header.page.ts` :191-250.
- `ui/src/app/core/screen-actions.ts` :162; `core/proposal-view.ts` (`CONSEQUENCE_*`, `consequenceSentence`); `core/strings.ts`, the item block :6709-6871.
- EXPERIENCE.md :173 is the Dialogs line, and :604 is the item strings' Fixed-strings row.

### Tests and rosters

- `Test/InteropItemControl.cls` (armed): `MintAs`, `ConfirmHttp`, `Save`, `Items`, `Recompile`, `Audited`.
- `Test/ProductionProbe.cls`: `AddItem` :203 adds a setting. Probe classes: `Op` holds Host `HangSeconds` and `ApiToken`, and `TearOp` holds only `TearDownSeconds` (:62-92).
- `Test/InteropItemGate.cls`: the principal generator. `scripts/ci-throwaway.sh`: the item `# classes:` line.
- Rosters this story moves (Rule 30):

| File | What |
|---|---|
| `Test/ReadTool.cls` :94 | registry +2 (the tab's read and the write) and the sorted names |
| `Test/ToolWrite.cls` :1326 | other-port writes +1 |
| `Test/ToolRoundTrip.cls`, `Test/ToolEmit.cls` | the write's rows (`REFUSEEMPTY` among them) |
| `Test/SurfaceCoverage.cls` :248, :443 | a screen row and a tool row |
| `Test/Descriptor.cls` :223, `Test/StageTwoTools.cls` :199 | the tab's screen line |
| `Test/MappingDescriptor.cls` :24, `Test/ClassicPageGate.cls` :75 | `interop.items.changeclass`'s classic page and own pairs |
| `Test/InteropFloor.cls` :81-84, `InteropFloorOwnPairs`, `InteropFloorRoutes` | the tab, in the roster of the role Task 0 (c) measures |
| `Test/GovernanceBaseline.cls` | the baseline line order |
| `Test/InteropItemDescriptor.cls` | row actions and the card (contended: append only) |
| `ui/tools/screen-mirror.test.mjs`, `ui/tools/navigation.test.mjs` | the new screen and tab |
| `ui/browser/interop-host-tabs.browser-spec.mjs` :47-53, :234 | the strip gains Classes |
| `ui/browser/interop-items.browser-spec.mjs`, `ui/tools/interop.test.mjs` | the Change class leg; `SENTENCES` |

## Tasks & Acceptance

**Execution:**

- [x] **Task 0, on `ocupilot-b-ci` (USER, auditing on, the probe production).** Record each result under Design Notes › Measured.
  - (a) Re-anchor the Code Map on the branch head, where 20.25, 20.26 and 20.40 have landed. Read `ToolWrite`'s other-port count and `ReadTool`'s registry count; this story's pins are one and two above them.
  - (b) On a probe item changed `Op` → `TearOp` through the port's write, record:
    - the item's stored `Settings` before and after;
    - one `ModifyConfiguration` row;
    - the class through a recompile;
    - whether a running production then reads `NeedsUpdate` true.
  - (c) Which stock roles hold `%Ens_ProductionConfig:WRITE` (`Security.Roles` resources, read in `%SYS`), to place the tab in `InteropFloor`'s rosters.
  - (d) The picker's rows equal `Ens.ContextSearch.BusinessServices`, `BusinessProcesses` and `BusinessOperations` for each kind, as sets.
  - A result that changes destructiveness, the key default, the audit choice, the dropped rule or the pairs is `## Clarification Needed`.
- [x] `src/OcuPilot/Port/InteropPort.cls`:
  - **The endpoint.** Add `ENDPOINTITEMCLASSES` `ItemClasses` to `ENDPOINTS`. Its pairs are `PRODUCTIONPAIRS` plus `ITEMWRITEPAIRS`, so the read takes the classic dialog's `RESOURCE`. It serves `LIST` only, dispatched to a new `InvokeItemClasses` modeled on `InvokeItemTest`'s `LIST` branch.
  - **The list.** `ListItemClasses` gathers the item first: absent is 404, and a name held twice is `AMBIGUOUS`. It lists each candidate as a row `{Production, Item, ClassName, Type, Current}`, `Current` true for the item's own class. One `CandidateClasses(pType, .pFound)` helper, extended from `ListClasses`' reader, serves this read and the write's check.
  - **The write type.** Add `TYPECHANGECLASS` `CHANGECLASS` to `IsItemWrite`, and `NEWCLASSKEY` `newClass`.
  - **`DroppedSettings(pItem, pNewClass, .pDropped)`**, called switched, running vendor classes only. It applies the vendor rule of Problem over `pItem.Settings`, using a transient `Ens.Config.Item.%New(pNewClass)` for the adapter, as `AddViolations` does. Each element is `$ListBuild(Target, Name, Value)`.
  - **The read.** `ReadItem` answers `NewClass`, `Dropped` and `Digest` whenever the query names `NEWCLASSKEY`, with `ACTIONKEY` or without it:
    - `Dropped` is `[{Target, Name, Value, Secret}]`, with `Value` empty for a secret name.
    - Before computing them it refuses `NEWCLASS` or `SAMECLASS`, 409.
    - `IsCredentialName` is asked after the namespace is restored, as `SettingRow` does.
  - **`PerformItem`, `CHANGECLASS`**, under the open lock, in this order:
    - re-gather the item (`AMBIGUOUS`, absent), re-judge the class (409), and recompute the dropped set and the digest;
    - refuse `REVIEWCHANGED` when the query's `DIGESTKEY` differs;
    - set `ClassName`, remove the dropped settings, `%Save` the production, audit as Boundaries says, `SaveToClass(item)`, then read the item back.
  - `InvokeItems` hands both keys through. Add an `ItemSnippet` `CHANGECLASS` branch (AD-59). Refresh the header and `PerformItem`'s doc.
- [x] `src/OcuPilot/Api/InteropError.cls`:
  - `ITEMNEWCLASS`, `ITEMSAMECLASS` and `ITEMREVIEWCHANGED` go to `Codes`, the item lists and `ReasonFor`, the last also to `RESENDCHANGED`'s list;
  - consequence `ITEMCHANGECLASS` `INTEROP.ITEM.CHANGECLASS` goes to `Codes`, `ConsequenceCodes` and `ReasonFor`.
- [x] `src/OcuPilot/Screen/Tool/InteropItemChangeClass.cls` (new, extends `InteropItemAction`):
  - `TOOLNAME` `interop.items.changeclass`, `WRITETYPE` `CHANGECLASS`, `DESTRUCTIVE` 1, `DRYRUN` 1, `SCREENACTIONS` `changeclass`;
  - `SCREENVALUES` `changeclass=NewClass:Reviewed`, `SCREENOPTIONAL` `changeclass=Reviewed`;
  - `CLASSICPAGES` `EnsPortal.Dialog.ChangeClass`, `CONSEQUENCECODE` `INTEROP.ITEM.CHANGECLASS`;
  - `READANSWERS`: the parent's plus `NewClass,Dropped,Digest,Reviewed`. `STATEMARKER` and `PRECONDITIONFIELD`: `Dropped`.
  - `FINGERPRINTSUBJECT` `ClassName,NewClass,Dropped,Digest,Reviewed,Namespace`, because the stored payload is narrowed to the subject and the port query reads it.
  - `PRECONDITIONCODES`: `NEWCLASS`, `SAMECLASS`, `AMBIGUOUS`, `SOURCECONTROL` and `INTEROP.NAMESPACE`.
  - `PortQuery`: the parent's, then `NewClass` under `NEWCLASSKEY` and `Reviewed`, else `Digest`, under `DIGESTKEY`, as the resend does. `MergeUpdate`: the fresh read as the payload. `DryRunReview`: `{Digest}`.
  - `StateDiff`: a `ClassName` row from `ClassName` to `NewClass`, then one removed row per `Dropped` element, its `field` `<Target>.<Name>` and `before` its `Value`. A read without `Dropped` is `pProblem`.
  - `ArgumentProblem`, `ConfirmProblem` and `ScreenActionDelta` apply `NewClass`'s shape rule of the Matrix.
  - `InputSchema`: `NewClass` described ("as the item's Classes tab lists it") and required; `Reviewed` is not offered.
  - `DESCRIPTION` in the siblings' plain words. It is agent-facing and decided at implement.
- [x] `src/OcuPilot/Screen/Descriptor/InteropItemClassTab.cls` (new), on `InteropItemTestTab`'s shape:
  - route `interoperability/productions/items/classes`, `archetype` `detail`;
  - privileges `%Ens_Portal:USE` and `%Ens_ProductionConfig:WRITE`, the latter as `ownPrivileges`;
  - `classicPage` `EnsPortal.ProductionConfig` (AD-44's item tabs), `entityType` `production-item`, id composite `[Item, ClassName]`;
  - no actions; `context` fields `ClassName`, `Type` and `Current`;
  - read row "class this item can change to", source `interop`/`ItemClasses`/`LIST`, fields `Production, Item, ClassName, Type, Current`, one `item` criterion as the Test tab's;
  - columns `ClassName` (`interopItemColumnClass`, `name`), `Type` and `Current`;
  - tab position 8, label `explorerClassListLabel`; `toolIdentifier` `interop.itemclasses`.
- [x] `src/OcuPilot/Screen/Descriptor/InteropItemList.cls`: add `changeclass` to `rowActions` immediately before `remove`, which stays last. Refresh the doc.
- [x] `src/OcuPilot/Kernel/Governance/Baseline.cls`: append `"interop.items.changeclass": false`.
- [x] Client:
  - `interop-item-change-class.store.ts` (new): reads `/api/ocupilot/screens/interop.itemclasses/read?maxRows=1000&item=<Production||Name>` through `ApiService`, holding the rows, loading and refusal.
  - `interop-item-change-class-dialog.ts` (new), on the add dialog's model:
    - the consequence banner and a refusal alert;
    - one select labeled `interopItemColumnClass`, listing every row but `Current`, or the empty sentence;
    - a primary `interopEditResendReview`, `aria-disabled` until a class is chosen;
    - only the add dialog's classes (client-lint family 7).
  - `interop-item-list.page.ts`: register `changeclass` for the selected row. The dialog's choice closes it, then `startDryRun(INTEROP_ITEM_LIST, 'changeclass', id, {NewClass}, sink, <row Name>)`. Never over another dialog.
  - `screen-action-handler.ts`:
    - `DRY_RUN_ACTIONS` gains InteropItemList `changeclass`, and the destructive consequences map gains it;
    - `startDryRun` and `openReview` take an optional typed name, defaulting to today's;
    - `reviewLinesOf` renders a review of several rows: each row as `- <field>: <before>`, then `+ <field>: <after>` unless it is removed. A one-row review renders as today.
  - `screen-actions.ts`, `proposal-view.ts`, `strings.ts`: the label, the consequence and the ruled strings, appended. Specs for the store, the dialog and the handler's change.
- [x] `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`: add the ruled strings to :604's row, and to :173's Dialogs line: "change an item's class (Production items, Story 20.41: the class from the item's Classes tab, then the dry run's removed settings, then the destructive treatment, typed name the item's name)". Then run `npm run test:tools`.
- [x] `src/OcuPilot/Test/InteropItemChangeClass.cls` (new, armed by `OCUPILOT_ALLOW_PRINCIPALS`): one leg per Matrix row, each on its own probe items, created and removed in the test, using `InteropItemControl`'s class methods.
  - The agent's leg: mint, HTTP confirm, the class read back, the audit row and the recompile.
  - The person's leg: the dry run, then the action with `Reviewed`.
  - The Gates leg uses `InteropItemGate`'s generator.
  - Split at about 500 lines (`InteropItemChangeClassRefusals`).
- [x] `src/OcuPilot/Test/InteropItemClasses.cls` (new, armed): Task 0 (d)'s set equality for each kind, the unknown kind, `Current`, 404, `AMBIGUOUS` and the WRITE pair's 403.
- [x] `src/OcuPilot/Test/InteropItemDescriptor.cls` (append only): the row actions in order, and `StateDiff` over a fixed read, the secret row's value empty.
- [x] `scripts/ci-throwaway.sh`: both new classes on the item `# classes:` line.
- [x] The Code Map's rosters, then sweep `src/OcuPilot/Test`, `ui/browser`, `ui/tools` and the `ui/src` specs for the old shape of each (Rule 30).
- [x] `ui/browser/interop-items.browser-spec.mjs`, on the deployed bundle:
  - a Change class leg changes a probe item `Op` → `TearOp` through the row action;
  - it asserts the review lists `Host.HangSeconds` and the typed name;
  - it sees the row's class change, then removes the item.
- [x] `ui/browser/interop-host-tabs.browser-spec.mjs`: the strip's labels with Classes last.
- [x] DW-2298 (owned by 20.25 until its adjudication re-owns it): AC1-AC4 close its change-of-class residual.

**Acceptance Criteria:**

- AC1: Given an item, when a change of class is proposed by the agent and confirmed, or chosen as the Change class row action, reviewed and confirmed, then it runs through `InteropPort` as the classic page does. The item reads back with the new class, the dropped settings are gone, and the vendor's `ModifyConfiguration` row names the item.
- AC2 (Integration): given a changed probe item, when its Item settings tab (Story 20.22's `interop.itemsettings` read) is read, then it holds no production value for the dropped setting. And when the Change class dialog opens on Production items, it lists the Classes tab's rows.
- AC3: Given each Matrix refusal, when the change is reviewed, saved or confirmed, then it is refused by its code before any vendor write, and the production is unchanged.
- AC4: Given the change, when its tool, its governance key and the audit after a confirmed run are inspected, then they match Design Notes (AD-22). It is destructive, the key's default is `false`, the card lists each dropped setting as a removed row, and the audit record is the vendor's event plus the marker for an agent write.
- AC5: Given a caller missing one declared pair, when it changes a class by either caller or reads the Classes tab, then it is refused 403 naming that pair.
- AC6: Given the two new tools, when `Test/ToolWrite` and `Test/ReadTool` run, then the other-port count reads one above, and the registry count two above, the branch's values before this story.
- AC7: Given the Classes tab's read tool, when `Test/ReadDescriptions` runs, then it passes with the tool's title, row phrase and fields, and the tool is in no confusable group.

### Review Findings

Code review 2026-11-14 (first review, `389e9e2d..3c459376` plus QA's tree).

- [x] [Review][Patch] AC2's Item settings clause cannot fail: `HeldSettings()` lists only settings the new class declares, so a kept `HangSeconds` never shows [src/OcuPilot/Test/InteropItemChangeClass.cls:311]
- [x] [Review][Patch] The drop rule's Adapter keep branch is never run: the one Adapter case changes to a class with no adapter [src/OcuPilot/Port/InteropPort.cls:DroppedSettings]
- [x] [Review][Patch] The gate's change-of-class leg leaves state its reset cannot see: the change-back is unchecked and `Items()` compares names and enabled flags only [src/OcuPilot/Test/InteropItemGate.cls:419]
- [x] [Review][Patch] The class picker shows an empty select and no sentence when its read fails without one (status 0, installing) [ui/src/app/areas/interoperability/interop-item-change-class.store.ts:load]
- [x] [Review][Patch] Stale doc comments: `Snippet` and `ItemSnippet` omit the change of class, and the page comment says the dialogs add an item [src/OcuPilot/Port/InteropPort.cls:5732, ui/src/app/areas/interoperability/interop-item-list.page.ts:41]
- [x] [Review][Patch] AC4's audit and key-default clauses and AC5's write clause have pinning tests but no `mutation:` line [spec ## Verification]
- [x] [Review][Defer] `InteropItemChangeClassMint.Mint` repeats `InteropTransformMint.Mint`'s pre-read `ArgumentProblem` guard under another parent [src/OcuPilot/Screen/Tool/InteropItemChangeClassMint.cls:9] — deferred: LOW, a hook in the kernel mint would serve both, outside this story's files; ledgered DW-2546, wontfix-accepted.

Rejected:

- `false` the candidate scan holds the production's lock too long: the three-kind scan measured 0.078 s for 197 classes on `ocupilot-b-ci`.
- `false` a multi-line value breaks the review's layout: `.ocu-dialog-review > li` is `white-space: pre-wrap`.
- `false` the AD-59 script drops nothing without a context: its one caller, `Kernel/Proposal/Draft.cls:217`, always passes the stored payload, and `FINGERPRINTSUBJECT` keeps `Dropped` in it.
- `low` the picker can be cut at 1,000 rows and does not show each class's kind: 198 classes in `USER`, and the kinds mix only for an item whose class is not compiled.
- `low` by-design: a change that drops nothing reviews as bare `- old` / `+ new` lines; Tasks keeps a one-row review rendering as today.
- `low` the dialog's empty sentence would be untrue when the item's class is the only one of its kind: every interoperability namespace ships dozens of vendor classes of each kind, and a fix needs a new string.
- `low` suggested prompt 2 has no read that answers it: the strings are ruled (U-26), and the agent answers it with a proposal, which writes nothing.
- `low` the class-shape rule admits underscores and an interior `%`: the agent copies names from the Classes tab, the port refuses any class not listed, and a tighter pattern risks refusing a valid name.
- `low` a class of two kinds reads Type `service` on an unknown-kind item's tab: cosmetic, on a rare item, and the write's check is per kind.
- `low` the write saves the item rather than the production: Intent and the vendor save the item, and the stored settings read correct.
- `low` `Test/InteropItemDescriptor.cls` is edited in place: the edits are the roster's required rows, and Epic 23's branch does not touch the file.
- `low` DW-2545 still reads open: its adjudication is the runner's ledger gate.
- `low` the spec lost its frontmatter `deferred:` key: the fix edits the spec under review; the runner's harvest is the place to restore it.

- [x] [Smoke] Full sweep on ddae7dc1 (fresh `ocupilot-b-ci`, 20 shards, 710 classes): four roster assertions the story's change missed -- (1) `OcuPilot.Test.ToolDispatch.TestTheShippedGateAllowsEveryLiveToolButTheBaselineDisabled` +24: "interop.items.changeclass: 1|" and "interop.items.remove: 1|"; (2) `OcuPilot.Test.CompositeMintSweep.TestTheRosterIsEveryCompositeIdMint` +34: "every composite-id mint has a row: OcuPilot.Screen.Tool.InteropItemChangeClassMint"; (3) `OcuPilot.Test.InteropHostDescriptor.TestTheItemTabsFormOneGroupInOrder` +18: "and the group has seven members" (the Classes tab joins the group); (4) `OcuPilot.Test.InteropHostDescriptor.TestThePortServesTheRuntimeEndpointsAndTheirPairs` +1: "the port's endpoint roster". Update each roster to the delivered shape (read every name from the instance, never recall it), find out why `interop.items.remove` now reads differently in ToolDispatch and fix the cause, not the symptom; add the three classes to `Shared surfaces:` and the `(loop)` class list; demonstrate one mutation per roster row added and record its `mutation:` line under `## Verification`.

Code review 2026-11-14, rework re-review (`906b7b29..8721fd22`): clean. The four `[Smoke]` reds are fixed: `ToolDispatch` 19, `CompositeMintSweep` 5 and `InteropHostDescriptor` 8 green on `ocupilot-b-ci` (runs 762-764, source identical to the tree). The probe's `ArgumentProblem` stub and `REVIEWEDARGUMENT` reach no other row: `Mint.Mint` asks `ArgumentProblem` only after the read, where every sweep mode has already refused, and only `InteropItemChangeClassMint` reads the parameter.

Rejected:

- `low` the Classes-tab mutation line omits `TestTheNineDeclarationsRegister`, also red in run 754: the line is true and claims no "alone"; the fix edits this spec.
- `low` the endpoint mutation changes the test's literal: the test pins the port's parameter against that literal, and a product-side drop reddens it too; already rejected in the rework's triage.
- `low` the `ToolDispatch` mutation only reverts the fix: it reddens both names, which shows the test reads each verdict from the gate; a baseline set `true` reddens it the same way.
- `low` `Governance.INTEROPITEMREMOVE` now also holds the change of class: both readers use `$ListFind` and both doc comments name the two tools; the parameter is round-1 code, outside this range.
- `false` the probe's `REVIEWEDARGUMENT` is dead and could go stale: it keeps the stand-in faithful to the tool interface the mint reads, and no sweep row observes it, so a stale value changes no result.
- `false` the probe's `ArgumentProblem` ignores `NewClass`: the sweep pins the readable-id pass, not argument rules, which `InteropItemChangeClass`'s own tests pin.
- `low` a duplicate tab position would pass the eight-member count: the loop is unchanged apart from 7 to 8, and the registry's own roster check reddened on a position change in run 754.
- `low` the Code Map table, `Shared surfaces:` grouping, the rework paragraph's wording and the triage heading's date: each fix edits this spec.
- `false` the frontmatter reads `done` while tracking reads `review`: this is the rework convention, and the review does not set the frontmatter.
- `low` `InteropItemChangeClassMint` drops an error status from `ArgumentProblem`: round-1 code outside this range, and the shipped `ArgumentProblem` always returns `$$$OK`.

## Spec Change Log

- 2026-11-14, rework iteration 1 (runner): the full sweep found four roster assertions the story missed.

- 2026-11-12, spec gate (runner): the privileges and the twelve new strings are veto item U-26; the AD lines stay for the owner's Update, not written.

## Review Triage Log

### 2026-11-13 — Review pass

- verdicts: 12 findings — high 0, medium 2, low 10, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` the dropped-set rule is pinned only for a Host setting the new class does not declare — added `TestTheDropRuleIsAppliedPerTargetAndPerValue` (invalid Host value, Adapter, other target); two mutations recorded.
  - `[medium]` `[patch]` a changed value of a non-secret dropped setting is not covered by the moved-since-review tests — added `TestAValueThatMovedAfterTheReviewIsRefusedAndNothingIsWritten`; mutation recorded.
  - `[low]` `[patch]` the class-shape rule on the person's route and `ConfirmProblem` are undiscriminated — the route assertion now excludes the port's own code, and a `ConfirmProblem` leg was added; mutation recorded.
  - `[low]` `[defer]` the Change class dialog's dismissal path is not tested — the add and copy dialogs share the shape; closed in QA (DW-2545), see Verification.
  - `[low]` `[patch]` AC6 and AC7 have no `mutation:` line — two mutations run and recorded.
  - `[low]` `[reject]` the unknown-kind write is tested only to the operation class — the list leg pins all three kinds and both reads derive the kind through the same `GetBusinessType`; a service or process leg adds nothing the write's own judging does not.
  - `[low]` `[reject]` `Hang 2` before the no-job assertion — the polled `Running|1` leg is the one that discriminates, and the sleep only lengthens the window.
  - `[low]` `[reject]` an action without `Reviewed` skips the digest compare — by design: `Reviewed` is optional in `SCREENOPTIONAL` as the resend's is (AD-56), the client always sends it, and a direct caller can send the digest as well.
  - `[low]` `[reject]` the handler's no-outcome-dialog rule applies to any applied action that answers no lines — the resend actions answer lines when applied, and their specs stay green.
  - `[low]` `[reject]` digest enforcement lives at the callers as well as the port (intent audit) — same as the row on `Reviewed`.
  - `[low]` `[reject]` the picker and the write derive the item's kind separately (intent audit) — both call `Ens.Config.Item:GetBusinessType` (`InteropPort.cls` 1769, 2166).
  - `[low]` `[reject]` the nothing-dropped review is not pinned in the browser (intent audit) — it takes the existing one-row render path, and the agent's card for it is pinned.

### 2026-11-13 — Review pass (rework 1, the `[Smoke]` roster item)

- verdicts: 4 findings — high 0, medium 0, low 4, false 0, maybe-false 0
- findings:
  - `[low]` `[reject]` mutation line 4 mutates the test's own `ENDPOINTS` literal, not the product — the line says so ("the test's ENDPOINTS"), and the assertion compares the port's parameter to that literal, so removing a name from it is the discriminating mutation; the product-side drop also reddens `InteropDescriptor` and `InteropItemClasses`, which a line claiming "alone red" does not assert.
  - `[low]` `[reject]` the probe's new `ArgumentProblem` stub has no mutation line of its own — the new roster row's mutation (row removed) is the line that pins the stub's need, and without the stub the row errors rather than passes.
  - `[low]` `[reject]` the mutation runs are not visible in the diff — the tree after the pass is byte-identical to the diff (no mutated source), and the three classes were re-run green on `ocupilot-b-ci` after reload (runs 759-761).
  - `[low]` `[reject]` the `ToolDispatch` comparison was rewritten rather than appended (intent audit) — a minimal in-place roster edit the dispatch allowed, and `Governance.cls` reads the same parameter with `$ListFind`.

## Design Notes

**Governing ADs:** AD-3, AD-5, AD-8, AD-10, AD-13, AD-15, AD-16, AD-22, AD-24, AD-29, AD-35, AD-36, AD-44, AD-51, AD-52, AD-53, AD-56, AD-58, AD-59, AD-62. Checked with nothing to add:

- AD-54: nothing is created.
- AD-55: there is no Save route; the person's caller is the screen action.
- AD-21 and AD-27: no path and no `%Api.*`.
- AD-58: an action-style write's read-back reads `nothingSent`, as enable's does. The tests assert the class directly.

The story complies with every AD as it stands.

**Read at this plan** (source, plus read-only SQL on `ocupilot-slot-b`; the throwaway was not used):

- `HostChangeClass` is described under Problem.
  - It names no item but by its integer id, and validates no class. It judges `item.AdapterClassName()` after setting `ClassName`, so the adapter is the new class's.
  - A setting whose `IsValid` call throws is removed. OcuPilot keeps that rule, although 20.22's `ValueAccepted` treats a missing method as accepting.
- The classic client checks edit permission and edit database first, and warns "settings not available in the new class will be lost" (:3506-3527). After the change it refreshes and shows the settings tab (:7034-7047).
- `GetHyperEventResources` gives `HostChangeClass` the page's `EDITRESOURCE`, `%Ens_ProductionConfig:WRITE` (:7911), and the dialog's `RESOURCE` is the same pair. So the change's posture equals the classic portal's.
- `HSCUSTOM` on `ocupilot-slot-b` holds 90 non-abstract compiled service classes, 67 process classes and 120 operation classes (`%Dictionary.CompiledClass.PrimarySuper`; an approximation of `SubclassOf`, inference). The picker's 1,000-row cap holds all three together.

**Measured** (Task 0, `ocupilot-b-ci`, 2026-11-13, auditing on, the probe production in `USER`):

- (a) At the branch head `389e9e2d` (Stories 20.25 and 20.40 landed): `ToolWrite`'s other-port count read 57 and `ReadTool`'s registry 410, so this story's pins are 58 and 412. `ReadTool`'s criteria-descriptor count read 72 and is 73 with the Classes tab.
- (b) A probe operation item holding Host `HangSeconds`, `ApiToken` and `TearDownSeconds`, changed `Op` to `TearOp` through the port's write: its stored `Settings` read `Host.HangSeconds=5, Host.ApiToken=..., Host.TearDownSeconds=7` before and `Host.TearDownSeconds=7` after. The vendor's audit holds one `ModifyConfiguration` row, `item <name> of <production>: item class changed by OcuPilot from <old> to <new>, Host.ApiToken, Host.HangSeconds`. The class reads `TearOp` after a recompile of the production class. On a running production at `Running|0`, the change of a disabled item moved the state to `Running|1`, and so did the change of an enabled one: update pending.
- (c) `%Ens_ProductionConfig:W` is held by `%EnsRole_Administrator` and `%EnsRole_WebDeveloper`; `%EnsRole_Operator` holds `R` and `%EnsRole_Monitor` none. The tab is in `InteropFloor`'s Administrator rosters.
- (d) For an operation, a business process, a business service and an item whose class is not compiled, the `ItemClasses` rows equal `Ens.ContextSearch.BusinessOperations`, `BusinessProcesses`, `BusinessServices` and `AllBusinessHosts` as sets (84, 29, 88 and 198 classes in `USER`, none missing, none extra).

**Decisions (AD-22):**

| Action | Tool and key | Destructive | Audit record |
|---|---|---|---|
| Change one item's class | `interop.items.changeclass`, `false` | yes: each dropped setting's value is lost, and changing back does not restore it | `%Ensemble/%Production/ModifyConfiguration` through `AuditModifyProductionConfig`, "item class changed by OcuPilot from … to …" and the dropped setting names, plus the AD-15 marker |
| Read the Classes tab | `interop.itemclasses.read` | read | none: a read of the class dictionary |

**Decided in-stage:**

- The dispatch said to reuse the epic context, so it was not recompiled. This plan read the ADs it cites directly.
- **Action-style, not a merge.** The dropped set depends on the chosen class, so the read must be composed from it. The transform test and the resend show the shape.
- **The person reviews before sending.** A dry run shows the person what is dropped, and the digest makes the reviewed set the written set (the resend's shape). An impact line could not carry the chosen class.
- **NEWCLASS and SAMECLASS are 409 everywhere.** The class comes from a select, so a field error adds nothing, and a 409 lets the confirm's re-read close a proposal whose class has gone.
- **The change is allowed on an enabled item,** as the classic page allows it. A running production applies it at its next update.
- **The picker is an item tab.** A tab is a screen a person can open (AD-5), and it gives the agent a read with one `item` criterion, as the Settings and Test tabs do. The tab is in no confusable group: its read needs an item, and no other list holds an item's candidate classes.
- **The tab's screen title is new.** Reusing "Classes" as the title would give the model two read tools titled alike; the tab label stays "Classes".
- Reused strings: the tab label `explorerClassListLabel` ("Classes"), the column and the select label `interopItemColumnClass` ("Host class"), the button `interopEditResendReview` ("Review"), the criterion label `interopItemSettingsCriterionItem` and `tableColumnType`.

**Decided in-stage (implement):**

- The Classes tab declares `%Ens_ProductionConfig:READ` as well as `WRITE`, both as its own pairs. `InteropFloor`'s derived leg needs a declared pair from the classic page's `RESOURCE` (`EnsPortal.ProductionConfig`, `READ`), and the port's `ItemClasses` pairs already include READ, so the effective gate is unchanged. Veto item U-26 (privileges) carries this.
- `interopItemClassesEmptyAgent` is not shipped: the screen mirror refuses an `emptyAgentKey` on a descriptor with no action, so the tab's empty state is the existing `tableReadOnlyEmptyNext`. Eleven new strings, not twelve.
- `INTEROP.ITEM.REVIEWCHANGED` is in `ItemCodes` once and not also in `MessageCodes`: `Codes()` would list it twice, and the roster test counts them. `NEWCLASS` and `SAMECLASS` are in `ItemPreconditionCodes`.
- The agent's mint is `InteropItemChangeClassMint` (extends `InteropItemMint`), so a class that is empty, not a string, too long or not class-shaped, and a `Reviewed` argument, are refused before the instance is read.
- The composed read answers `Reviewed` only when it is composed for an action. The agent's confirm re-read carries the stored `Digest` and no action, and would otherwise answer a different `Reviewed` than its mint did and close every proposal target-changed.
- `DroppedSettings` answers each setting's position in `pPositions` as well, so the write removes by index in descending order. A review of several rows renders `- field: before` and `+ field: after` lines, trimmed of trailing blanks; a review whose action answers no line (this one) ends with the change event and opens no outcome dialog.
- The principals' legs are `InteropItemGate`'s own: its `LEGS` gained `Items|CHANGECLASS` and its `TOOLS` this tool, and its probe changes the class back when admitted.
- The agent's confirm of a destructive key that ships `false` needs the key on in the tests that confirm (`InteropItemChangeClass.KeyOn`); `ClassicPageGate`'s and `Governance`'s rosters name the key.

**For the runner (veto window, privileges):**

- The Classes tab's read takes `%Ens_ProductionConfig:WRITE`. That is the classic dialog's `RESOURCE`, so the list is never shown to someone the classic portal would not show it to. A holder of only READ sees the tab drawn gated, naming the pair. Recommendation: keep it so. READ would be looser than the classic dialog.
- The write declares `EnsPortal.Dialog.ChangeClass` in `CLASSICPAGES`, so an operator's custom resource on that dialog gates OcuPilot's change too. This is equal to or stricter than the classic portal. Recommendation: keep it.

**Split and budget:** this story alone is past the template's budget, with a port read, a write, a tab and a dry-run client path. It stays one story, as the dispatch directs.

**Rule 31 (extend, don't copy):**

- The tool extends `InteropItemAction`, and takes its dry-run parts from the resend and its composed read from the transform test.
- The port extends `ReadItem`, `PerformItem`, `ListClasses`' reader, `ItemParts` and `Sha256Hex`.
- The tab copies the Test tab's declaration shape, which is data.
- The removed rows are built in the tool, because `Write.RemovalRows` builds fixed-name rows and is not on this branch.
- The handler's review extends `openReview` and `reviewLinesOf`, and is not a second path.

**New strings for the runner** (proposed wording; the runner rules on each):

- `interopItemChangeClassAction`, the row action and the dialog title: "Change class".
- `interopItemClassesLabel`, the tab's screen title: "Host classes".
- `interopItemClassesEmpty`: "No compiled class of this item's kind is in this namespace."
- `interopItemClassesEmptyAgent`: "Ask the agent which classes this item can change to."
- `interopItemClassesPrompt1-3`:
  - "Which classes can this item change to?"
  - "Which of this item's settings would a change of class remove?"
  - "What does each class this item could take do?"
- `interopItemClassesColumnCurrent`, the column: "Current".
- `INTEROP.ITEM.CHANGECLASS`, the dialog's banner and the card: "Changing this item's class removes every setting the new class does not take, and they cannot be restored. The change takes effect when this production next starts or, while it runs, when it is updated on Productions."
- `INTEROP.ITEM.NEWCLASS`: "Choose a compiled class of this item's kind, as its Classes tab lists them."
- `INTEROP.ITEM.SAMECLASS`: "This item already uses that class."
- `INTEROP.ITEM.REVIEWCHANGED`: "This item's settings changed after they were reviewed, so its class was not changed. Review it again."

**For the owner's attended Update** (the story complies without them):

- AD-62 would gain "Story 20.41: `Items` gains `CHANGECLASS`, action-style over `ITEM` composed from the chosen class, applying `HostChangeClass`'s setting rule and refusing a reviewed set that moved; `ItemClasses` (`LIST`, one `item` criterion) lists the candidates as `Ens.ContextSearch` does, behind the classic dialog's pair."
- AD-51 would gain a named case: "`InteropPort` composes `ITEM` from the change of class's declared `NewClass` and takes the reviewed digest from `Reviewed` or the stored `Digest`."
- AD-44 would gain "the change of class declares `EnsPortal.Dialog.ChangeClass`, and the Classes tab maps to `EnsPortal.ProductionConfig`."
- AD-22 would gain "`interop.items.changeclass` ships `false`."

**Integration ACs, Consumes, Consumed-by:**

- Integration: AC2. The consumers are 20.22's `InteropItemSettingList` and this story's Change class dialog over the new tab's read, against `ocupilot-b-ci`.
- Consumes:
  - 20.3's `InteropItemAction` and the item write path;
  - 20.22's settings read and its redaction;
  - 20.31's dry-run route and handler path;
  - 20.6's tab shape and `ItemParts`;
  - `Test/ProductionProbe`.
- Consumed-by: the 20.12 and 20.36 workflows (inference). No story is waiting on the tab's read.

**Ledger inbox (Rule 17):** none of the story's own. DW-2298 is cited in Tasks.

**Contended (Epic 23, checked 2026-11-12 at `98dce68a`, tree clean):**

- Of this story's files, Epic 23 changes only `Test/InteropItemDescriptor.cls`, appending one method at the end, so this story only appends there.
- Epic 23 also changes `Write.cls`, `InteropItemRemove.cls`, `Api/Error.cls`, `epics.md`, `ui/tools/ci-runner.mjs`, `ci-shards.mjs` and `ci.test.mjs`. This story edits none of them.
- Its new `ui/tools/client-paths.test.mjs` pins only the users paths.

## Verification

**Shared surfaces:**

- the Production items row actions;
- an item's tab strip;
- the write-tool and read-tool rosters (`ToolDispatch`, `CompositeMintSweep`, `InteropHostDescriptor`, `ReadTool` +2, `ToolWrite`'s other-port count +1, `ToolRoundTrip`, `ToolEmit`, `SurfaceCoverage`);
- the screen rosters (`Descriptor`, `StageTwoTools`, the screen mirror, `InteropFloor`);
- the classic-page rosters (`MappingDescriptor`, `ClassicPageGate`);
- the governance baseline;
- `InteropPort`'s `ENDPOINTS` and `Serves`;
- the handler's dry-run review;
- the probe production;
- the Fixed-strings row and the Dialogs line.

*Every test added or changed passes on a fresh environment, in either order.*

**Setup (the implement stage only):** common.md's load and redeploy recipes, targeting `ocupilot-b-ci`. `ocupilot-slot-b` is for read-only SQL only.

**Commands** (each sized to about 150 s, one class or spec file per call, `timeout: 600000`; totals read from `%UnitTest_Result`):

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one class per call:
  - `InteropItemChangeClass` (and its split), `InteropItemClasses`, `InteropItemControl`, `InteropItemGate`, `InteropItemRefusals`, `InteropItemDescriptor`;
  - `ReadTool`, `ToolWrite`, `ToolRoundTrip`, `ToolEmit`, `SurfaceCoverage`, `EndpointCoverage`, `GovernanceBaseline`, `Governance`, `Prohibited`, `ReadDescriptions`, `Descriptor`, `StageTwoTools`, `MappingDescriptor`, `ClassicPageGate`, `InteropFloor`, `CompileWithoutInterop`;
  - `ToolDispatch`, `CompositeMintSweep`, `InteropHostDescriptor`;
  - and every class the sweep changes.
- `(loop)` `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/<file>`, on the redeployed bundle, one call each for `interop-items.browser-spec.mjs` and `interop-host-tabs.browser-spec.mjs`.
- `(loop)` `cd ui && npm run test:tools`, and as a separate call `cd ui && npm run test:components`. Both pass, `name-links.test.mjs` included.
- `(loop)` `cd ui && npm run build`: it passes, with client-lint family 7 clean and the bundle under the fixed 2,500 kB warning.
- `(loop)` `uv run scripts/check-objectscript.py <changed .cls>` and `bash scripts/lint-docs.sh`, both clean.
- The full ObjectScript sweep, `npm test`, the smoke and Rule 30's fresh check are the runner's. The full browser suite is CI's.

**Mutations run** (`ocupilot-b-ci`, each tree restored byte-identical, the class reloaded after):

- mutation: `ChangeStep` stores `SaveToClass` as `$$$OK` -> `InteropItemChangeClass.TestTheAgentsChangeOfClassConfirmsOverHttp` red on the recompile leg (AC1).
- mutation: `DroppedSettings` drops no setting (`If tRemove && 0`) -> `InteropItemChangeClass` red on the card and the stored-settings legs (AC1).
- mutation: the dialog's store reads `interop.items` for `interop.itemclasses` -> `interop-item-change-class.store.spec.ts` and `interop-item-change-class-dialog.spec.ts` red on the path and the option list, and the browser Change class leg red (AC2).
- mutation: `ChangeStep` skips the digest compare (`If 0 && ...`) -> `InteropItemChangeClassRefusals.TestASettingThatMovedAfterTheReviewIsRefusedAndNothingIsWritten` red on the write leg (AC3).
- mutation: `CandidateClasses` admits an abstract class (`If tAbstract && 0 Continue`) -> `InteropItemChangeClassRefusals.TestAClassTheTabDoesNotListAndTheItemsOwnClassAreRefused` red on the abstract-class rows (AC3).
- mutation: `InteropItemChangeClass.StateDiff` returns a credential-named setting's `Value` -> `InteropItemDescriptor.TestTheChangeOfClassToolAndItsCard` red (AC4).
- mutation: the `ItemClasses` branch of `Pairs` drops `ITEMWRITEPAIRS` -> `InteropItemClasses.TestACallerMissingAPairIsRefusedNamingIt` red on the missing-write leg (AC5).
- mutation: the page's `startDryRun` call drops the item's name (`target.name`) -> the browser Change class leg red on the typed name (AC1).
- mutation: `DroppedSettings` ignores the status of the Host `IsValid` call, and again keeps a setting of any target but Host -> `InteropItemChangeClass.TestTheDropRuleIsAppliedPerTargetAndPerValue` red on the dropped list and the stored settings (AC1).
- mutation: `ChangeDigest` leaves a dropped setting's value out -> `InteropItemChangeClassRefusals.TestAValueThatMovedAfterTheReviewIsRefusedAndNothingIsWritten` red (AC3).
- mutation: `ScreenActionDelta` skips the class rule, and `ConfirmProblem` answers no problem -> `InteropItemChangeClassRefusals.TestABadClassArgumentIsRefusedBeforeAnyRead` red on the person's route and on the confirm check (AC3).
- mutation: the tool class `InteropItemChangeClass` deleted from the instance -> `ToolWrite` red on the write roster; the tab class `InteropItemClassTab` deleted -> `ReadTool` red on the registry and the criteria corpus (AC6).
- mutation: the tab's read declares a `label` -> `ReadDescriptions.TestEveryConfusableToolCarriesItsLabel` and `TestEveryReadDescriptionIsExactlyItsDeclaredParts` red, so the tool stays in no confusable group and its description is its declared parts (AC7).
- mutation: (QA) the Change class dialog's template drops `(closed)="cancelled.emit()"` -> `interop-item-change-class-dialog.spec.ts` red on the Cancel, scrim and Escape legs, and the browser leg `the Change class dialog closes on Escape, Cancel and the scrim` red on the bundle rebuilt and redeployed with it (30 s wait for the dialog to go; AC1, DW-2545).
- mutation: (QA) the page's template drops `(cancelled)="onCloseClass()"` -> `interop-item-list.page.spec.ts` `dismissing the class dialog closes it without starting a review` red (AC1, DW-2545).
- mutation: (review) `DroppedSettings` keeps every setting (`If tRemove && 0`) -> `InteropItemChangeClass.TestTheDropRuleIsAppliedPerTargetAndPerValue` red on its `(AC2)` Item settings assertion (AC2).
- mutation: (review) `DroppedSettings`' Adapter branch removes every Adapter setting (`Set tRemove = 1`) -> `InteropItemChangeClass.TestAnAdapterSettingTheSharedAdapterTakesIsKept` alone red (AC1, AC2).
- mutation: (review) `InteropItemGate.Probe`'s change back names `TearOp` (refused `SAMECLASS`) -> `TestEachMissingPairIsRefusedByNameThroughThePort` red on `OcuP203Exact: Items|CHANGECLASS` alone.
- mutation: (review) `ChangeStep`'s audit text leaves out `from <old>` -> `InteropItemChangeClass.TestTheAgentsChangeOfClassConfirmsOverHttp` and `TestThePersonsDryRunThenActionChangesTheClass` red on the audit row (AC4).
- mutation: (review) the baseline sets `interop.items.changeclass` `true` -> `InteropItemDescriptor.TestTheChangeOfClassToolAndItsCard` red on "listed in the governance baseline, disabled" (AC4).
- mutation: (review) `Pairs` adds `ITEMWRITEPAIRS` for every item write but `CHANGECLASS` -> `InteropItemGate.TestEachMissingPairIsRefusedByNameThroughThePort` red on `OcuP203NoCfgWrite: Items|CHANGECLASS` (AC5).
- mutation: (review) the picker store keeps `result.reason ?? ''` for an error and ignores every other kind -> `interop-item-change-class.store.spec.ts` `reports the server-fault sentence ...` red.
- mutation: (smoke) `ToolDispatch` compares the tool name to the whole `INTEROPITEMREMOVE` list again -> `TestTheShippedGateAllowsEveryLiveToolButTheBaselineDisabled` red on `interop.items.remove` and `interop.items.changeclass`.
- mutation: (smoke) the `InteropItemChangeClassMint` row removed from `CompositeMintSweep.Roster` -> `TestTheRosterIsEveryCompositeIdMint` alone red.
- mutation: (smoke) the Classes tab at position 9 -> `InteropHostDescriptor.TestTheItemTabsFormOneGroupInOrder` red on position 8 and the eight members.
- mutation: (smoke) `ItemClasses` left out of the test's `ENDPOINTS` -> `TestThePortServesTheRuntimeEndpointsAndTheirPairs` alone red.

**Tests added or changed by QA:**

- `ui/src/app/areas/interoperability/interop-item-change-class-dialog.spec.ts` (QA): three dismissal legs (Cancel, scrim, Escape through the overlay stack).
- `ui/src/app/areas/interoperability/interop-item-list.page.spec.ts` (QA): dismissal closes the dialog, starts no review and lets the action reopen it.
- `ui/browser/interop-items.browser-spec.mjs` (QA): the dialog closes on Escape, Cancel and the scrim in a real browser, with nothing reviewed or sent and the item unchanged.

**Planned pinning mutations (Rule 19):**

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | The `CHANGECLASS` branch skips `SaveToClass` | the recompile assertion |
| AC1 | `DroppedSettings` keeps every setting | the agent leg's "`HangSeconds` gone" |
| AC2 | The dialog reads `interop.items.read` instead of `interop.itemclasses.read` | the dialog spec's option list and the browser leg |
| AC3 | The write skips the digest compare | the moved-since-review leg |
| AC3 | `CandidateClasses` admits an abstract class | the not-a-candidate leg |
| AC4 | `StateDiff` returns the `Value` of a secret-named setting | `InteropItemDescriptor`'s card test |
| AC5 | `Pairs` drops `ITEMWRITEPAIRS` for `ItemClasses` | `InteropItemClasses`' 403 leg |
| AC1 | The browser review's typed name is the composite id | the browser Change class leg |

## Auto Run Result

Status: done
Blocking condition: none

**Change.** A destructive `interop.items.changeclass` item write (key `false`) and an `ItemClasses` read with its Classes tab; a Change class row action on Production items with a class picker, a dry run listing each dropped setting and the typed item name; the agent's card lists each dropped setting as a removed row. The port composes the read from the chosen class, recomputes its digest under the lock and refuses a moved reviewed set before anything is written.

**Files.** Port and errors: `Port/InteropPort.cls`, `Api/InteropError.cls`. Tool and tab: `Screen/Tool/InteropItemChangeClass.cls`, `InteropItemChangeClassMint.cls`, `Screen/Descriptor/InteropItemClassTab.cls`, `InteropItemList.cls`, `Screen/Titles.cls`, the governance baseline. Client: the picker store and dialog, the page, the action handler, `strings.ts`, `screens.generated.ts`, `proposal-view.ts`, `screen-actions.ts`. Tests: three new classes (`InteropItemChangeClass`, `InteropItemChangeClassRefusals`, `InteropItemClasses`), appended or moved rosters, client specs, two browser specs; `scripts/ci-throwaway.sh`; `EXPERIENCE.md`.

**Review.** Patches applied: 2 medium, 2 low (tests and mutation lines, listed in the triage log). Deferred: 1 low (dialog dismissal). Rejected: 7 low, each with its reason in the triage log. Follow-up review: not recommended.

**Verified** on `ocupilot-b-ci` after the patches: the classes of the spec's loop list, run one at a time, all green (the two patched classes again after the patch); `npm run test:tools` 2211 pass; `npm run test:components` 3388 pass; `npm run build` passes with the initial bundle at 2.02 MB; `interop-items` (6) and `interop-host-tabs` (4) browser specs green on the redeployed bundle; `check-objectscript.py` and `lint-docs.sh` clean. Not run here: the full ObjectScript sweep, the smoke, Rule 30's fresh check and the full browser suite (the runner's and CI's).

**Residual.** The veto-window items are in Design Notes (the tab also declares `%Ens_ProductionConfig:READ` as an own pair, and 11 new strings, not 12). DW-2298's change-of-class residual is the runner's to close.

**Rework 1 (the `[Smoke]` roster item).** `ToolDispatch` compared a tool name to the whole two-name `INTEROPITEMREMOVE` list, so neither name matched; it now tests list membership. `CompositeMintSweep` gained the `InteropItemChangeClassMint` row and `CompositeMintProbe` the argument stand-ins it needs. `InteropHostDescriptor` pins the Classes tab at position 8 and `ItemClasses` in `ENDPOINTS`. `Write.RemovalRows` was not used (no rows built); `ToolDispatch` is a minimal in-place edit. Review: 4 low rejected (triage log), 0 patched; follow-up review not recommended. Verified on `ocupilot-b-ci`: `ToolDispatch` 19, `CompositeMintSweep` 5 and `InteropHostDescriptor` 8 tests green, one class per call after loading `src`; `check-objectscript.py` 0 problems; `lint-docs.sh` clean.
