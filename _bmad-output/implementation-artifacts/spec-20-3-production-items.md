---
title: 'Story 20.3: Production items'
type: 'feature'
created: '2026-10-09'
status: 'done'
baseline_revision: '75ea4c139e052dbcc0c475cb3ad4f1e83f89e24b'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
warnings: [oversized]
deferred:
  - summary: >-
      Production items draws its Production criterion label and Comment column with `systemInfoProduction` and `userFieldComment`, because `strings.ts` values must be unique and no generic key held either word.
    evidence: |-
      `Descriptor/InteropItemList.cls` names both keys; `ui/tools/strings.test.mjs` "every value is unique" refused a new key of either value.
    location: >-
      src/OcuPilot/Screen/Descriptor/InteropItemList.cls
    severity: low
---

<intent-contract>

## Intent

**Problem:** A production's hosts can be seen and changed only in the classic configuration page: OcuPilot cannot list a production's items, enable or disable one, or add or remove one (an item's settings are Story 20.22). Two of Story 20.2's stop outcomes also answer wrongly (DW-2157, DW-2162).

**Approach:** Extend `Port/InteropPort` (AD-62) with an `Items` endpoint. A child list, Production items, opens from the Productions row and reads through the port. Four confirmed writes (enable, disable, add, remove) reach the stored production configuration through the documented `Ens.Director` and `Ens.Config.Production`/`Item` calls, and save it to the production class every time. None of them touches a running production's jobs; 20.2's Update applies a pending change (Design Notes, Q2).

## Boundaries & Constraints

**Always:**

- Every write goes through the port's gate before any vendor call, naming the failed pair (AD-29). The namespace is switched by explicit save and restore (AD-16).
- An item write saves the configuration and then the production class (`SaveToClass`). `EnableConfigItem` alone leaves the class stale, and a recompile reverts it (measured).
- Every refusal is by code, decided before any vendor call: a taken, duplicated or illegal name, a class that is not a business host, a value the host class refuses, a no-op, and a namespace under source control.
- One descriptor per screen, one port, read tools derived (FR-80). Both callers share one operation (AD-53, AD-55). The add Save takes the per-target hold (DW-1882).
- `interop.items.remove` is destructive: typed-name dialog, governance key `false` (AD-22). The other three keys are `true`.
- Item names, comments and class names are untrusted content (AD-11, AD-60).
- Edits to contended files follow Design Notes › Contended files.

**Never:**

- Never call `UpdateProduction`, start, stop, restart or recover from an item write (Q2).
- Never call `%Api.InteropEditors.*`, `EnsPortal.Template.prodConfigSCPage` (Hidden, Internal) or `CleanProduction`.
- Never read item ids as the vendor's integer ids: a recompile renumbers them (measured).
- No class change of an existing item, no copy, no item tabs or monitor (20.4), no System Default Settings edit, no production create or delete.
- No item-settings list, set or reset: Story 20.22 consumes this story for those (orchestrator split, 2026-10-09).
- No new spawn site, no frame and no copied vendor bundle.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| List items | Production row opened, `?ns=USER` | One row per `Ens.Config.Item`: `Production, Name, ClassName, Type, Enabled, EnabledSource, PoolSize, Category, Comment`. The read tool returns the same rows. | 404 `PORT.NOTFOUND` for an unknown production |
| Disable / enable | Item enabled / disabled | Stored, and the class XData carries it. A running production reads update pending, and the card says so. | `INTEROP.ITEM.DISABLED` / `.ENABLED` (409) |
| Enable/disable refused | A system default supplies `Enabled`; or a business process with pool size 0 | No vendor call | 409 `INTEROP.ITEM.DEFAULTSETTING` / `.POOLZERO` |
| Add | Free legal name, business host class | The item is stored (disabled unless `Enabled` is true), and the class XData carries it | 409 `.TAKEN`, 422 `.NAME`/`.CLASS` (field violations) |
| Remove | A disabled item | Deleted from the configuration and the class | 409 `.ENABLEDREMOVE` while enabled |
| Duplicate name | Two items share the name | Every write on that name is refused | 409 `INTEROP.ITEM.AMBIGUOUS` |
| Source control | `%CSP.Portal.SourceControl.Util.IsEnabled(ns)` | Every item write is refused | 409 `INTEROP.ITEM.SOURCECONTROL` |
| Gates | Missing `%Ens_ProductionConfig:READ`/`:WRITE`, or WRITE on the namespace's globals or routines database | Refused by name before any vendor call | 403 naming the pair |
| Stop ends Suspended (DW-2157) | Stop from Running with messages still queued | The vendor answers OK in 5.5 s and the production reads Suspended (measured) | 409 `INTEROP.PRODUCTION.SUSPENDED`, applied and marked |
| Partial stop (DW-2162) | A job outlasts the cap after quiescing | The vendor's `<Ens>ErrJobsNotStopped`; the production reads Running with no jobs (measured) | 409 `INTEROP.PRODUCTION.PARTSTOPPED`, unlogged |

</intent-contract>

## Code Map

### Port and errors

- `src/OcuPilot/Port/InteropPort.cls`:
  - `ENDPOINTS` :49, `PRODUCTIONPAIRS` :62, `WRITEPAIRS` :72, `CODEJOBNOTSTOPPED` :122
  - `IsWrite` :176; `Pairs` :185 maps every non-Productions endpoint to `CODEPAIRS`, so `Items` must map to `PRODUCTIONPAIRS`; `Serves` :199
  - `Refusal` :221 is the pure precondition shape the item refusals copy
  - `Invoke` :287, gate :298-325 (the globals pair :320); `ReadState` :486, `StateRow` :543, `Perform` :559
  - `Statused` :620 maps only the singular `ErrJobNotStopped` (DW-2162); `Snippet` :734
- `src/OcuPilot/Api/InteropError.cls` (119 lines): `REASONSTOP` :64 and `REASONRESTART` :68 are the two reworded sentences; `ConsequenceCodes` :86, `PreconditionCodes` :94. `Api/Error.cls`'s `INTEROP.` prefix branch already routes new codes, so `Error.cls` is not edited.
- `src/OcuPilot/Kernel/Shell/Namespaces.cls`: `GlobalDatabase` :84 reads `NamespaceInfo` :75. `AtelierPort.DatabaseResources` :693 is the routines-database precedent.
- `src/OcuPilot/Kernel/EntityId.cls` `JoinComposite`/`SplitComposite` :74/:81. `Screen/Tool/MappingMint.cls` is the composite-id mint the item tools copy.
- Vendor, read through the worktree's `irislib` link:
  - `Ens.Director.EnableConfigItem` :1562
  - `Ens.Config.Production`: `SaveToClass(pItem)` :123, `RemoveItem` :195
  - `Ens.Config.Item`: `Name` :20 (MAXLEN 128), `PoolSize` :41 (MINVAL 0), `Enabled` :47 (InitialExpression 1), `GetBusinessType` :218
  - `Ens.Util.Auditing.AuditModifyProductionConfig` :182; `%CSP.Portal.SourceControl.Util.IsEnabled` :53

### Tools

- `Screen/Tool/InteropProductionAction.cls`: `PrivilegePairs` :120, `PortQuery` :144, `StateDiff` :158, `READSVALUES`/`READANSWERS` :31-34.
- `Screen/Tool/InteropProductionStop.cls` gains `AfterWrite`. `Write.AfterWrite` is at :282, and `Operation.ApplyAt` (`Kernel/Proposal/Operation.cls`:473) marks a write applied before `AfterWrite` runs.
- `Screen/Tool/Write.cls`: `CREATES` :151, `SCREENACTIONS` :167, `READSVALUES` :176, `SCREENVALUES` :226, `PRECONDITIONCODES` :508, `READBACKFIELDS` :958; `ReadBackGone` :294, `ComposeCreate` :352, `ArgumentProblem` :920.
- Precedents: create `ExplorerDocDbCreate.cls` :23-77; destructive action `ExplorerDocDbDelete.cls` :21-72; composite-id tools `MappingCreate` and `MappingDelete` over `MappingMint`.
- AD-55 Save: `Area/Security/MftConnectionSave.cls` takes `Operation.HoldTool` at :73 and runs `Unexpected` :224 and `Prohibited` :246. Routes are at `Api/Router.cls`:253-255.

### Screens and registry

- `Screen/Descriptor/InteropProductionList.cls`:23-67 is the shape. `WalletSecretList.cls`:37-83 is a child list (`parentScope`, one criterion with `hint`), opened from its parent's name cell by `ui/src/app/core/navigation.ts` `childListFor` :329.
- `Screen/Read.cls`: the interop branch :547-556 sends no criteria; the encryption branch :523-530 is the `SeedCriteria` precedent; the route-criterion requirement is :655-668.
- `Screen/Registry.cls`: the interop source rules :1282-1297; the criteria port list :1683-1684, which refuses `interop`; the one-criterion rule for a parented read :1694-1697.
- `ui/tools/screen-mirror.mjs`: the same rules at :1405-1418 and :1885-1887; `interopEndpoints` :1095. Regenerate `ui/src/app/core/screens.generated.ts`.
- `Kernel/EntityType.cls`:98 `TYPES` (62 entries).
- `Kernel/Proposal/Prohibited.cls`: `COVEREDTYPES` :250, `TYPEPRODUCTION` :618, the chain :1295, the production branch :1550-1555, `PermittedCreateFields` :1186.
- `Kernel/Governance/Baseline.cls`:209-213, the interop keys.

### Client

- `ui/src/app/shell/screen-action-handler.ts`:
  - `SCREEN_ACTION_DESCRIPTORS` :64 (interop :113)
  - `UNDRAWN_ACTIONS` :352; Locks' page-registered `remove` is at :369
  - `DESTRUCTIVE_ACTIONS` :424, `DESTRUCTIVE_CONSEQUENCES` :452
  - `TYPED_NAME_ROWS` :532; the mapping lists type `Name` for a composite key
  - `WARNING_CONSEQUENCES` :575 (interop :603-608)
- `ui/src/app/core/screen-actions.ts` `ACTION_LABELS` :112-145; `ui/src/app/core/proposal-view.ts` `INTEROP` consequences :364-367 and :481-484.
- `ui/src/app/core/strings.ts`: the interop block :6149-6233, each key citing `EXPERIENCE.md:604`.
- `ui/tools/interop.test.mjs`: `SENTENCES` :29-43, the 15 s pin :71. `ui/tools/strings.test.mjs`: the bound :602-608.
- `ui/browser/interop-productions.browser-spec.mjs`: probe hooks :51-55 and :151-174. `waitForMapAnswered` is in `browser/namespace-features.mjs`:62.

### Tests and fixtures

- `Test/ProductionProbe.cls`:
  - `CheckOwn` :112, `Create` :120, `Send` :154, `Settle` :247, `Remove` :322
  - the probe op class text :42-84
- `Test/InteropControl.cls`; `Test/InteropGate.cls` (the job-and-`Login` probe :197-265); `Test/InteropGateSeam.cls` is the seam precedent.
- Classic pages: `EnsPortal.ProductionConfig` sets RESOURCE `%Ens_ProductionConfig:READ` and EDITRESOURCE `:WRITE`. `EnsPortal.Dialog.ProductionAddService`, `…AddProcess` and `…AddOperation` have base `ProductionAddHost` and RESOURCE `:WRITE`.

## Tasks & Acceptance

**Execution:**

- [ ] **Task 0 (`ocupilot-b-ci` only, through `docker exec`).** Measure only the open cells, and record each as a `Task 0:` line under Verification:
  - that `Ens.Config.Production` opened at concurrency 4 makes a second writer's open wait;
  - the `NormalizePage` spellings of the three add-host dialogs;
  - what `EnableConfigItem` answers when a system default supplies `Enabled`;
  - whether a partial stop (DW-2162) records `%Ensemble/%Production/StartStop`;
  - that one HTTP confirm per new tool answers exactly one envelope.
  - A cell that disagrees with Design Notes › Measured: HALT `intent gap`.
- [ ] `src/OcuPilot/Port/InteropPort.cls` (extend):
  - **Endpoint, types and pairs.**
    - `ENDPOINTS` gains `Items`, with types `LIST` (criterion `production`), `ITEM`, `ENABLE`, `DISABLE`, `ADD` and `REMOVE`.
    - `Pairs` maps `Items` to `PRODUCTIONPAIRS`, plus a new `ITEMWRITEPAIRS = "%Ens_ProductionConfig:WRITE"` for its writes.
    - An item write's gate also requires WRITE on the namespace's routines database, after the globals one (measured: `<PROTECT>` on `^Ens.Config.ItemD` and `^oddDEF`). It does not require `%Ens_ProductionRun:USE`.
    - `IsWrite` stays the production writes'. An `IsItemWrite` serves the gate.
  - **LIST.** One row per `Ens.Config.Item` of the named production: `Production, Name, ClassName, Type, Enabled, EnabledSource, PoolSize, Category, Comment`. An unknown production is 404 `PORT.NOTFOUND`.
    - `Type` is `service`, `process` or `operation`, from `GetBusinessType`.
    - `Enabled` is the effective value. `EnabledSource` is `default` when `Ens.Config.DefaultSettings.%GetSetting(prod, item, class, "", "Enabled", .v)` supplies it (the vendor's own check, `Ens.Config.Item`:248), else `production`.
  - **ITEM, the fresh read.**
    - The id is the composite `[Production, Name]`. It answers the row plus `Namespace` and `Count`.
    - An absent item is 404 `PORT.NOTFOUND`, unlogged. `Count > 1` is `.AMBIGUOUS`.
    - Source control enabled is `.SOURCECONTROL`, read through an overridable `SourceControlled(ns)` seam.
    - With `ACTIONKEY` it refuses by code, as `Refusal` does: `.ENABLED`, `.DISABLED`, `.DEFAULTSETTING`, `.POOLZERO`, `.ENABLEDREMOVE`. For `add` it inverts (AD-54): absent is the 404 the create expects, and present is `.TAKEN`.
  - **Writes, in one switched block.**
    - Validate first: the name rule (Design Notes), the class through `GetBusinessType` ∈ 1, 2, 3, and add's fields through `Ens.Config.Item`'s own `<Prop>IsValid`.
    - Open the production at concurrency 4, so writers on one production serialize on the vendor's row lock.
    - Enable and disable: `Ens.Director.EnableConfigItem("<prod>||<name>", x, 0)`.
    - Add: a new `Ens.Config.Item` (`Enabled` 0 unless sent true), then `Items.Insert` and `%Save`.
    - Remove: `RemoveItem`, then `%Save`.
    - Then `SaveToClass` every time (with no item for a remove). Drop every reference, then restore the namespace.
    - Add and remove record `%Ensemble/%Production/ModifyConfiguration` through `Ens.Util.Auditing.AuditModifyProductionConfig`. The record names the operation and the item, never a value.
    - A `SaveToClass` failure after the configuration saved is a logged 500.
  - **DW-2162:** `Statused` maps `<Ens>ErrJobsNotStopped` to 409 `INTEROP.PRODUCTION.PARTSTOPPED`, unlogged.
  - **Scripts:** `Snippet` gains one objectscript branch per new write type, each block closed on its line (AD-59).
- [ ] `src/OcuPilot/Api/InteropError.cls`: the codes and sentences in Design Notes; `PreconditionCodes` and `ConsequenceCodes` extended; `REASONSTOP` and `REASONRESTART` reworded (Q3).
- [ ] `src/OcuPilot/Kernel/Shell/Namespaces.cls`: append `RoutineDatabase(ns, .resource, .readOnly)`, mirroring `GlobalDatabase`.
- [ ] `src/OcuPilot/Kernel/EntityType.cls`: append `production-item` (composite `[Production, Name]`, kept exactly, with no `IDRULES` row). The count 62 → 63 in `Test/Descriptor.cls`:1761, `Test/SuperserverDescriptor.cls`:130 and `Test/MftConnectionDescriptor.cls`:141 (Design Notes › Contended files).
- [ ] `src/OcuPilot/Kernel/Proposal/Prohibited.cls`: cover `production-item` (`COVEREDTYPES`, a `TYPEPRODUCTIONITEM`, the chain, and a `ReviewedFewOnly` branch like `production`'s), with `PermittedCreateFields(production-item)` = `Name, ClassName, PoolSize, Enabled, Category, Comment`. AD-10 gains no arm.
- [ ] `src/OcuPilot/Screen/Read.cls`: the interop branch seeds its criteria with `SeedCriteria`, as the encryption branch does, and requires a parent-scoped list's route criterion.
- [ ] `src/OcuPilot/Screen/Registry.cls` :1683-1684 and `ui/tools/screen-mirror.mjs` :1885-1887: admit `interop` criteria on a parent-scoped read only. These two edits are in place (Q3). Regenerate `screens.generated.ts`.
- [ ] `src/OcuPilot/Screen/Descriptor/InteropItemList.cls` (new):
  - `route` `interoperability/productions/items`, `parentScope` `interoperability/productions`, `sideBarPosition` 0, archetype `list`
  - entity type `production-item`, composite id `[Production, Name]`
  - read `{interop, Items, LIST}`, with criterion `production` (with a `hint`)
  - `privileges` `[%Ens_Portal:USE, %Ens_ProductionConfig:READ]`, own `%Ens_ProductionConfig:READ`
  - `classicPage` `EnsPortal.ProductionConfig`
  - `primaryAction` `add`; `rowActions` `enable, disable, remove`
  - context fields `Name, ClassName, Type, Enabled, PoolSize`
  - three prompts; `toolIdentifier` `interop.items`
- [ ] Tools (new):
  - `Screen/Tool/InteropItemMint.cls`: `MappingMint`'s shape for `[Production, Name]`.
  - `Screen/Tool/InteropItemAction.cls`, abstract:
    - `PORTCLASS` `InteropPort`, `READTYPE` `ITEM`, `READSVALUES` 1, `SENDSBODY` 0, `NAMESPACEFIELD`, and the item mint
    - `PrivilegePairs` = the screen's pairs + `%Ens_ProductionConfig:WRITE` + WRITE on the namespace's globals and routines databases + `WithClassicPages`, each refused by name before any port call
    - `CONSEQUENCECODE` `INTEROP.ITEM.PENDING`
  - Each tool declares its `SCREENACTIONS` id and, in `PRECONDITIONCODES`, the `ITEM` refusals its action can meet.
  - `InteropItemEnable` and `InteropItemDisable`: `STATEFIELD` `Enabled`, subject `Enabled, EnabledSource, Namespace`.
  - `InteropItemRemove`: `DESTRUCTIVE` 1, `CHANGEACTION` deleted, `CONSEQUENCECODE` `INTEROP.ITEM.REMOVE`, subject `Enabled, ClassName, Namespace`.
  - `InteropItemAdd`:
    - `CREATES` 1, `CONSEQUENCECODE` `INTEROP.ITEM.PENDING`
    - arguments `Production, Name, ClassName, PoolSize, Enabled, Category, Comment`
    - `READBACKFIELDS` the six fields after `Production`
    - `CLASSICPAGES` the three add-host dialogs (Task 0 spellings)
- [ ] `src/OcuPilot/Screen/Tool/InteropProductionStop.cls` (DW-2157): `AfterWrite` re-reads `STATE`. Suspended answers 409 `INTEROP.PRODUCTION.SUSPENDED` with `detail.state`, so the write stays applied and marked.
- [ ] `src/OcuPilot/Area/Interop/ItemSave.cls` (new) and an add-only route `POST /interop/items` in `Api/Router.cls`: the person's Add, in `MftConnectionSave`'s order (the hold (DW-1882), `Unexpected`, the rules, the absence read, `ComposeCreate`, `Prohibited`, the port's `ADD`, the read-back).
- [ ] `src/OcuPilot/Kernel/Governance/Baseline.cls`: append `interop.items.enable`, `interop.items.disable` and `interop.items.add` as `true`, and `interop.items.remove` as `false`.
- [ ] `src/OcuPilot/Test/ProductionProbe.cls` (add-only): a second op class whose `OnTearDown` waits `TearDownSeconds`, for DW-2162. `Remove` removes it.
- [ ] Tests (new). Each is armed under `OCUPILOT_ALLOW_PRINCIPALS`, run one class per call, creates its own probe production and removes it, and splits beyond about 500 lines.
  - `Test/InteropItemControl.cls`: every item row of the matrix but Gates and Source control, through mint and HTTP confirm and through the screen caller. After each write it asserts:
    - the stored row;
    - the class XData, after a recompile;
    - on a running production, that no job started or stopped and that the production reads update pending, and then that 20.2's Update applies the change (AC5);
    - the change event, the marker, the vendor audit row (names, no values) and the snippet.
  - `Test/InteropItemGate.cls`: one principal per declared pair, each missing that one pair, refused naming it on the port, the read, the tool and the Save, before any vendor call. The routines-database leg and `.SOURCECONTROL` run through `Test/InteropItemSeam.cls`, the `InteropGateSeam` pattern.
  - `Test/InteropStopOutcome.cls`: the DW-2157 and DW-2162 legs, through confirm and the row action.
  - `Test/InteropItemDescriptor.cls`: the declarations, the registry rules on synthetic sources, screen-and-tool row equality, and every new code resolving through `ReasonFor`.
  - A leg that confirms `interop.items.remove` sets its governance key from a snapshot and restores it. A test asserts only on its own probe rows.
- [ ] Roster sweep (Rule 30; Design Notes › Contended files):
  - `ReadTool` :93-94, `SurfaceCoverage`, `Navigation` :526-530, `navigation.test.mjs` :344
  - `ClassicPageGate` :75 and :154, `MappingDescriptor` :24, `PortGate` :29, `Prohibited` :232
  - `ToolEmit` :226, `ToolRoundTrip` :84, `ToolWrite` :1338, `DraftRegistry`, `GovernanceBaseline` :15
  - `InteropFloor` :357, which asserts that no floor kind holds a write tool: a kind that now holds an item write moves to the set read from the instance
  - `InteropFloorRoutes`, `InteropFloorOwnPairs`, `SaveHoldCoverage`, `EndpointCoverage`
  - `screen-mirror.test.mjs` :2387 and :2877, `interop.test.mjs`
  - `ci-throwaway.sh` :402, a new `# classes:` line, with `ci.test.mjs`
- [ ] Client:
  - `screen-action-handler.ts`:
    - add `InteropItemList` to `SCREEN_ACTION_DESCRIPTORS`;
    - append `remove` to `DESTRUCTIVE_ACTIONS` (Locks' `remove` is page-registered, so the handler never draws it);
    - add `WARNING_CONSEQUENCES` entries for `enable` and `disable` with the PENDING sentence;
    - add a `DESTRUCTIVE_CONSEQUENCES` entry, and a `TYPED_NAME_ROWS` row with `name: 'Name'`, as the mapping lists have;
    - on `INTEROP.PRODUCTION.SUSPENDED` or `.PARTSTOPPED`, re-read the Productions list.
  - `ui/src/app/areas/interoperability/interop-item-add-dialog.ts` (new): opened by the list's `add`, stating the PENDING sentence and posting to `/api/ocupilot/interop/items`.
  - `screen-actions.ts` labels; `proposal-view.ts` consequences for `INTEROP.ITEM.PENDING` and `.REMOVE`.
  - `strings.ts`: add-only keys, plus the two reworded stop and restart values (Q3).
- [ ] `EXPERIENCE.md`: `:604` gains every new literal and a Story 20.3 Where clause, with the stop and restart literals reworded (Q3), and `:173` names the Add item dialog. `ui/tools/strings.test.mjs`'s bound moves 3000 → 3400 with one comment line; then `cd ui && npm run test:tools`.
- [ ] `ui/browser/interop-items.browser-spec.mjs` (new). `before` creates the probe production, removing any leftover first, and `after` removes it. Every step waits for `waitForMapAnswered` and the list's rows. In USER:
  - open the probe production's items from its name cell;
  - disable and enable `OcuPilotProbeOp`;
  - add an item, then remove it through the typed-name dialog.

- [ ] **Review patches (first pass; Review Triage Log).** Each is the smallest change, with its own test or mutation line under Verification:
  - **P1:** `ui/src/app/shell/proposal-card.spec.ts`: the Story 20.2 `INTEROP.*` consequence loop (:872) gains `INTEROP.ITEM.PENDING` and `.REMOVE`, each expecting its published sentence, with a `Mutation (Rule 19)` line (delete the two `proposal-view.ts` branches).
  - **P2:** `ui/src/app/core/turn.ts` `decideProposal`'s error branch publishes the `changed` event (type, scope and id of the proposal's target, action `updated`, the tool) when the code is `INTEROP.PRODUCTION.SUSPENDED` or `.PARTSTOPPED` and the target is known. Move the code list out of `screen-action-handler.ts` into `core/` (beside the other interop constants in `proposal-view.ts`) so both import one list. Add a turn-store spec leg per code, and a mutation line.
  - **P3:** `Test/InteropItemControl.cls`: after the agent's remove and the person's Remove, assert the vendor audit row names the item and no value, and `auditMarked` for add and remove; assert enable's captured audit row too. Mutation: delete the remove branch's `AuditModifyProductionConfig` call.
  - **P4:** `Test/SaveHoldCoverage.cls`: `HeldLeg("/interop/items", "OcuPilot.Screen.Tool.InteropItemAdd", <composite id>, <a body a post-hold rule refuses>)` in `TestACreateSaveHoldsTheKeyItsMintComputes`. Mutation: hold `ItemSave`'s name alone.
  - **P5:** `Test/InteropItemRefusals.cls`: through the port's `ADD` directly, `PoolSize` `"many"` answers 422 `PORT.FIELD.SHAPE` naming `PoolSize`; a `Comment` over the property's length and a `Category` it refuses answer 422 `INTEROP.ITEM.VALUE`; a bad name reaches the port's own violation branch. Mutation: delete the shape arms of `AddViolations`.
  - **P6:** `Test/InteropItemSeam.cls` and its two users (`InteropStopOutcome` partial-stop leg, `InteropItemGate` source-control leg): a positive control showing the capture is engaged (a fault through the seam that must log reads `Logged() = 1`), or a recorded mutation that keeps the 409 and adds a `LogFault` call and reddens the `Logged() = 0` assertion.
  - **P7:** `Port/InteropPort.cls` `PerformItem`: a failed `AuditModifyProductionConfig` is carried out of the switched block and written with `LogFault` after the namespace is restored; it never fails the write.
  - **P8:** `Test/InteropStopOutcome.cls` `TestTheStopAndRestartConsequencesNameAPartialStop`: correct the doc comment to what it asserts, and record the mutation (reword `REASONSTOP` without the partial-stop clause) under Verification.
  - **P9:** `Test/InteropItemGate.cls`: use `InteropItemControl`'s `Items` and `IdOf` through `..#CONTROL`, as the other legs do, if the probe production is the same; otherwise keep them and say why in the class header.
  - **P10:** `Port/InteropPort.cls` `NameProblem` doc comment: state that it mirrors `Ens.Config.Item.CheckForIllegalCharacters` (which the vendor runs at `%Save`), adds the 128-character limit, refuses a control character and a space at either end, and is pure so it can run before the switch.

**Acceptance Criteria:**

- **AC1 (list, integration):** Given the probe production in USER on `ocupilot-b-ci`, when its Productions row's name is opened, then Production items lists its items through `InteropPort`, and `interop.items.read` returns the same rows.
- **AC2 (confirmed item writes, integration):** Given each of enable, disable, add and remove, when the agent proposes it and the person confirms it over HTTP, or the person acts on the screen, then the change is in the stored configuration and in the production class after a recompile. On a running production no job starts or stops, and the production reads update pending, which the enable, disable and add cards say. Remove asks for the item's name typed, and its governance key ships `false`.
- **AC3 (refusals):** Given any refusal row of the matrix, when it is proposed or acted on, then it is refused by its code before any vendor call.
- **AC4 (gates):** Given a principal lacking one declared pair, when it reads, proposes, acts or saves, then it is refused naming that pair before any vendor call. Every declared pair has its own leg.
- **AC5 (Update applies it, integration):** Given a running production with an item disabled, or added enabled, through OcuPilot, when 20.2's Update is confirmed, then the disabled item's job stops, or the added item's starts, and the production reads up to date.
- **AC6 (DW-2157, DW-2162):** Given a stop that ends Suspended, or jobs that outlast the cap, when stop or restart runs, then it answers its own code and sentence. The row shows the state the production was left in, and the stop and restart consequences name a partial stop.

## Spec Change Log

- 2026-10-09, runner, orchestrator rulings (by=merge_gate, feature 67e70c72): split approved, so item settings (the Item settings list, set, reset, the setting entity type, secret-named settings) move to Story 20.22, which reads the first plan at `git show 6def26fa:_bmad-output/implementation-artifacts/spec-20-3-production-items.md`; Q2 A (configuration and class only; 20.2's Update applies; remove refused while enabled); Q3 cleared on union terms. Status reset to draft for a re-plan.

## Review Triage Log

### 2026-10-09 — Review pass

- verdicts: 28 findings — high 0, medium 6, low 20, false 2, maybe-false 0
- findings:
  - `[medium]` `[patch]` Agent card's mapping of `INTEROP.ITEM.PENDING` and `.REMOVE` has no test — only the handler's dialog path and a literal-equality tool cover them; the `proposal-card.spec.ts` loop holds four `INTEROP.*` codes. Fix: P1.
  - `[medium]` `[patch]` Agent confirm never re-reads Productions after a stop that ended Suspended or partly stopped — `turn.ts` `decideProposal` publishes `changed` on `ok` only (read at :1411-1486) while the row action publishes it. Fix: P2.
  - `[medium]` `[patch]` Remove asserts no audit row or marker; add/enable assertions are thinner than disable's — `InteropItemControl` remove legs assert `action = deleted` only. Fix: P3.
  - `[low]` `[reject]` Concurrency-4 serialization and the 503 branch have no test — no AC pins it, a test needs a second process holding the row lock past the 10 s wait; `wontfix-accepted`, `reopen_if=PerformItem's open or Unavailable branch changes`.
  - `[low]` `[reject]` Tool-level routines-database pair not distinguishable in USER — the port's own routines gate has its leg and still refuses by name before any vendor call, so a missing tool-level pair costs a late refusal; `wontfix-accepted`, `reopen_if=a fixture gives a namespace's routines database its own resource`.
  - `[medium]` `[patch]` No held-key leg for the item add Save (DW-1882) — `SaveHoldCoverage` untouched; the static check passes any `.HoldTool(` call, a wrong key would pass. Fix: P4.
  - `[medium]` `[patch]` `AddViolations`' shape arms and the Category and Comment value arms are untested — a body of `{"PoolSize": "many"}` would be silently ignored; also the port's own inner violation branch is reached by no test (folds the intent-alignment finding on the same branch). Fix: P5.
  - `[medium]` `[patch]` The `Logged() = 0` legs have no positive control — nothing shows the `InteropItemSeam` capture is engaged. Fix: P6.
  - `[low]` `[reject]` Restart's partial stop is not exercised — it shares `Statused`, whose plural mapping the stop leg pins.
  - `[low]` `[reject]` A `SaveToClass` failure after the configuration saved (logged 500) has no test — needs a seam for a theoretical failure.
  - `[low]` `[patch]` `tAuditSC` is assigned and never read in `PerformItem` — a failed audit write is dropped silently. Fix: P7.
  - `[low]` `[reject]` Handler-spec `store.refusal()` assertions echo the reason the test fed in — the adjacent `events` assertions are the load-bearing ones.
  - `[low]` `[patch]` `TestTheStopAndRestartConsequencesNameAPartialStop` has no mutation line and its doc comment claims a minted stop is checked — Rule 19 closes this in the pass. Fix: P8.
  - `[low]` `[reject]` AC3's `POOLZERO`, `AMBIGUOUS`, `ITEM.CLASS` and not-found rows, AC6's wording and the browser click-through have no mutation line of their own — Rule 19 asks one demonstrated mutation per AC and each of AC1, AC3 and AC6 has several recorded.
  - `[low]` `[reject]` Rule 31: `structural()` and `frames()` in `interop-items.browser-spec.mjs` copy `interop-productions.browser-spec.mjs` — ten other browser specs carry their own copy of `frames()`, so the convention is one per spec; `wontfix-accepted`, `reopen_if=a shared browser helper module is introduced`.
  - `[low]` `[patch]` Rule 31: `InteropItemGate.Items()` and `.IdOf()` copy `InteropItemControl`'s. Fix: P9.
  - `[low]` `[reject]` Rule 31: `ItemSave`'s `Body`, `Gate`, `Prohibited`, `Answer` and `Unexpected` follow `DocDbSave` and `MftConnectionSave` — the reason (a person's Save over a create tool of a different shape) is in the class header and the Auto Run Result, and goes in the commit message.
  - `[false]` `[reject]` Rule 30: the browser spec calls `waitForMapAnswered` once, not on the Items list — that helper waits on the rail's map; the Items list waits for its rows (`waitForRows`, `rowPresent`), the list's own answered signal, and `interop-productions` does the same.
  - `[low]` `[reject]` `interop-item-list.page.ts` has no vitest host — the browser spec drives it and its recorded Add mutation reddens it.
  - `[low]` `[reject]` DW-2157 is answered by the stop tool's `AfterWrite`, not at the port, so the port's `STOP` still reads OK — the Task prescribes exactly this and the matrix row says applied and marked; the panel drawing a refused step for an applied row is the confirm's existing handling of an applied write whose follow-up failed.
  - `[false]` `[reject]` "Unlogged" is tested as no `LogFault` call only — Design Notes name the limit that a partial stop records no vendor marker, and the spec's `unlogged` is the fault log.
  - `[low]` `[reject]` The agent's mint answers add violations as 400 `TOOL.ARGUMENTS` while the Save answers 422 — the sibling create tools do the same through `Write.ArgumentProblem`; the sentences are in the problem text.
  - `[low]` `[reject]` Source control and the routines pair run through a seam only, the `ITEM` read is refused under source control, and `IsEnabled` reads 0 on a fault — the seam pattern and the `ITEM` refusal are in the Tasks, and the last is the vendor's answer.
  - `[low]` `[reject]` Default-setting precedence: `ENABLED` and `DISABLED` come before `DEFAULTSETTING` — both refuse before any vendor call, and "already enabled" is the truer sentence for a same-state request.
  - `[low]` `[reject]` Names match without regard to letter case for `TAKEN` and `AMBIGUOUS` — refuses more, never less; the Auto Run Result records the reading.
  - `[low]` `[patch]` `NameProblem` re-implements the vendor's `CheckForIllegalCharacters` and its comment says the classic client refuses the characters the vendor refuses (`irislib/Ens/Config/Item.cls`:369-410 shows the vendor refuses all of them at `%Save`). The rule is the spec's Design Notes decision; the comment is wrong. Fix: P10.
  - `[low]` `[reject]` `ProductionHeld` and `AddViolations` are public port methods outside `Invoke`'s gate — in-process only, reached behind `ItemSave.Gate` and the tools' pairs, with no route of their own.
  - `[low]` `[reject]` "The card says so" is one static sentence and no UI test runs a running production — Design Notes make `INTEROP.ITEM.PENDING` static; the running-production leg is `InteropItemControl`'s.

## Design Notes

**Governing ADs:** AD-1, AD-3, AD-5, AD-6, AD-7, AD-8, AD-10, AD-11, AD-13, AD-14, AD-15, AD-16, AD-22, AD-24, AD-29, AD-34, AD-36, AD-39, AD-44, AD-51, AD-52, AD-53, AD-54, AD-55, AD-56, AD-58, AD-59, AD-60, AD-62.

**Rulings** (orchestrator, by=merge_gate, 2026-10-09, feature 67e70c72): the split (settings are 20.22's), Q2 A and Q3 on union terms, as the Spec Change Log records. No further security-posture question remains for this story.

**Reading of the intent:** in this story, "a value the host class refuses" is an add field that `Ens.Config.Item` refuses (`INTEROP.ITEM.VALUE`). Setting values are 20.22's.

**Measured at the first plan on `ocupilot-b-ci`** (USER, `ProductionProbe` plus a scratch class, removed afterwards; reused here, not re-probed):

- **Stopped production.**
  - `EnableConfigItem(…,0,0)` answers OK and records `%Ensemble/%Production/ModifyConfiguration` ("item disabled by <caller>"). It does not touch the class XData. Compiling the class then reloaded it with the item enabled again and every item id renumbered.
  - Repeating it answers `<Ens>ErrGeneral` "already disabled". An unknown item answers `ErrConfigItemNotFound`, and an unknown production `ErrProductionNotRegistered`.
- **Class, add and remove.**
  - Item `%Save` then `SaveToClass(item)` answers OK, and the XData carries the change. The class then reads not up to date, as on the vendor's own path.
  - `PoolSize` -1 is refused #7204. `Bad|Name` and `_Bad` are refused at `%Save`.
  - Add stored a duplicate enabled name, and a non-host class. A missing class saved the table row and then failed `SaveToClass` with `<CLASS DOES NOT EXIST>`.
  - Remove answers OK. The vendor records no audit event for add, remove or the composed save.
- **Running production.**
  - Each item write leaves `NeedsUpdate` 1 with the vendor's reason. `UpdateProduction(10,0)` applied each one.
  - With the item busy past a 3 s cap, `UpdateProduction` answers `<Ens>ErrJobNotStopped` in 3.01 s. The disable stays stored.
  - `EnableConfigItem(…,1)` runs that update itself, uncapped.
- **Privilege.**
  - A principal holding only `%Ens_Portal:U` and `%DB_USER:RW` performed every item write and the audit call.
  - With `%DB_USER:R` it got `<PROTECT>` on `^Ens.Config.ItemD` and `^oddDEF`.
  - Stock roles: `%EnsRole_Administrator` and `_WebDeveloper` hold `%Ens_ProductionConfig:W`. `_Operator` holds `:R` plus `%Ens_ConfigItemRun:U` and `%Ens_ProductionRun:U`.
- **DW-2157:** stop(15) with three messages queued behind a 3 s handler answered OK in 5.50 s, and the production reads Suspended.
- **DW-2162:** an op whose `OnTearDown` waits 20 s made stop(3) answer `<Ens>ErrJobsNotStopped` in 3.02 s. The production reads Running with `NeedsUpdate` 1 and only the stuck job, and after 22 s it reads Running with no jobs.
- **Source control:** off in USER. The classic save goes through the Hidden `prodConfigSCPage`, which calls the source-control hooks around `%Save` and `SaveToClass`.

**Decisions this plan takes:**

- **Name rule** (the vendor's `CheckForIllegalCharacters` plus the classic client's checks): 1-128 characters with no leading or trailing space; none of `| ; , [`; not starting with `-` or `_`; not ending with `-`, `!` or `$`; not `*`.
- **Identity:** an item is `[Production, Name]`. A duplicate name is refused, never guessed.
- **Classic pages:** enable, disable and remove are performed on the list's own page, so they declare no `CLASSICPAGES`. Named limits: a holder of only `%Ens_ConfigItemRun:USE`, which the classic page admits for enable and disable, is refused; an item's own class is not checked for a mapped package (inference).
- **AD-10:** OcuPilot runs no production of its own, so no item is self-protection.
- **Audit (AD-15, AD-53):** enable and disable carry the vendor's own event, and add and remove record it through `Ens.Util.Auditing`, as the classic server methods do. Named limit: a partial stop (DW-2162) records no marker.
- **Pending update:** `INTEROP.ITEM.PENDING` is static, so it holds for a stopped and a running production alike. Enable, disable and add carry it on their cards, and enable and disable warn with it first, since an action's warning is its card's consequence. Remove carries `INTEROP.ITEM.REMOVE` instead: it is refused while the item is enabled, so no job is affected.
- **Codes and sentences** (in `InteropError`, `strings.ts` and `EXPERIENCE.md:604`):
  - `INTEROP.ITEM.ENABLED`: "This item is already enabled."
  - `INTEROP.ITEM.DISABLED`: "This item is already disabled."
  - `INTEROP.ITEM.DEFAULTSETTING`: "A system default setting decides whether this item is enabled, so change it in System Default Settings."
  - `INTEROP.ITEM.POOLZERO`: "This business process runs in the production's shared actor pool, so it cannot be disabled."
  - `INTEROP.ITEM.TAKEN`: "This production already holds an item of that name."
  - `INTEROP.ITEM.AMBIGUOUS`: "This production holds more than one item of that name, so change it in the classic production configuration page."
  - `INTEROP.ITEM.CLASS`: "Name a business service, business process or business operation class compiled in this namespace."
  - `INTEROP.ITEM.NAME`: the name rule above, as one sentence.
  - `INTEROP.ITEM.VALUE`: "A production item does not accept this value for that field."
  - `INTEROP.ITEM.ENABLEDREMOVE`: "Disable this item before removing it."
  - `INTEROP.ITEM.SOURCECONTROL`: "This namespace uses source control, so change this production's items in the classic production configuration page."
  - consequence `INTEROP.ITEM.PENDING`: "The change takes effect when this production next starts or, while it runs, when it is updated on Productions."
  - consequence `INTEROP.ITEM.REMOVE`: "Removing this item deletes it and every setting it holds from the production."
  - `INTEROP.PRODUCTION.SUSPENDED`: "The production stopped, but messages still queued left it Suspended rather than Stopped. Start it to process them."
  - `INTEROP.PRODUCTION.PARTSTOPPED`: "Some of the production's jobs did not stop within 15 seconds, so it is left partly stopped and still reads Running. Stop it again to finish, or update it to start its jobs again."
  - Stop's consequence ends "…nothing is stopped; if a job then takes longer than 15 seconds to stop, the production is left partly stopped." Restart's is reworded the same way.
- **Fixed strings:** about 40 literals in all, with the title, empty states, prompts, columns, type words, labels and the add dialog. The table moves from 2,967 (measured) to about 3,007, so the bound moves 3000 → 3400.
- **Client weight:** one dialog, handler entries and strings, about 10-20 kB (inference), against 3,178,307 bytes and the 3326 kB warning. Implement measures it and states it in the Auto Run Result.

**Spine drafts (Rule 20, one line each, applied at the spec gate):**

- **AD-62:** `InteropPort` gains `Items` (`LIST` with one `production` criterion, `ITEM`, `ENABLE`, `DISABLE`, `ADD`, `REMOVE`); an item write changes the stored configuration and the production class only, and a running production reads update pending until 20.2's confirmed Update applies it (rule 6 holds; a remove is refused while the item is enabled); measured, `Ens.Director.EnableConfigItem` alone leaves the production class stale, and a recompile re-enables the item and renumbers every item id, so every item write also calls `SaveToClass` and an item is identified by `[Production, Name]`, never by the vendor's integer id; a namespace under source control refuses every item write (`INTEROP.ITEM.SOURCECONTROL`); enable and disable carry the vendor's `ModifyConfiguration` event, and the vendor records none for add and remove, so the port records it through `Ens.Util.Auditing.AuditModifyProductionConfig`, never with a value; an item write's pairs are `%Ens_ProductionConfig:WRITE` and WRITE on the namespace's globals and routines databases, and never `%Ens_ProductionRun:USE`.
- **AD-8:** measured at Story 20.3's plan, the vendor's item writes check no privilege of their own (a principal holding only `%Ens_Portal:U` and `%DB_USER:RW` did every item write), so OcuPilot's declared pairs are the only gate; 20.3's write tools declare their pairs, each pinned by a Rule 19 test that removes one pair and observes the refusal.
- **AD-36:** a parent-scoped `interop` list takes its parent's route id as its one criterion (Production items, `production`), required as a single-object read's is; the port answers the parent key on each row, so nothing is seeded.
- **AD-13:** a `production-item` id is the composite `[Production, Name]`, each part kept exactly.
- **AD-44:** Story 20.3's add declares `EnsPortal.Dialog.ProductionAddService`, `…AddProcess` and `…AddOperation` (Task 0 spellings); enable, disable and remove are performed on the list's own page and declare none.

**Integration ACs, Consumed-by and Consumes:**

- Integration: AC1, AC2 and AC5 run against a real instance (`ocupilot-b-ci`, HTTP confirm and the screen route). AC5's consumer is 20.2's Update.
- Consumed-by: 20.22 (Item settings opens from an item row and reuses `production-item`, the `ITEM` read, the item tools' pairs and the always-`SaveToClass` rule), 20.4 (per-host tabs from an item row), 20.6 (a host test names its item), 20.8 (the configuration diagram's items), 20.12 (a guided disable, then Update).
- Consumes: 20.2 (`InteropPort`, `production`, the Productions list and Update), 18.14's and 6.6's child-list pattern, and `Test/ProductionProbe`.

**Ledger inbox (Rule 17):** AC6 addresses DW-2157 (stop's `AfterWrite`, `SUSPENDED`) and DW-2162 (`PARTSTOPPED` and the reworded consequences).

**Contended files (Rule 11),** checked against `.worktrees/epic-18` at `ba8df993` on 2026-10-09:

- Single-line rosters both epics append to, with the union taken at merge, as 20.2 did: `EntityType.cls`:98; `Prohibited.cls`:250 and :1295; in `Test/`, `PortGate`:29, `ClassicPageGate`:75 and :154, `MappingDescriptor`:24, `ReadTool`:93-94, `Prohibited`:232, `ToolRoundTrip`:84, and the entity-type count in `Descriptor`:1761, `SuperserverDescriptor`:130 and `MftConnectionDescriptor`:141.
- Story 18.10 also raises that count 62 → 63, so an identical `63` from both epics merges clean and reads wrong. Whichever merge brings both sets all three to the union (64).
- Add-only: `Baseline.cls`, `Router.cls`, `SurfaceCoverage`, `SaveHoldCoverage`, `EndpointCoverage`, `DraftRegistry`, `screen-action-handler.ts` (`DESTRUCTIVE_ACTIONS` :424 is a one-line array, appended), `strings.ts` (new keys), `screen-mirror.test.mjs`, `navigation.test.mjs`, `ci-throwaway.sh`, and `screens.generated.ts` (regenerated).
- In place, cleared (Q3): `Registry.cls`:1683-1684, `screen-mirror.mjs`:1885-1887, and the stop and restart literals in `strings.ts` and `EXPERIENCE.md`:604. Epic 18's hunks there are at :2958-2967, :315, :471 and :475, so all four are line-clean.
- Untouched: `Mint.cls`, `ScreenAction.cls`, `EntityRef.cls`, `AdminPort.cls`, `Api/Error.cls`, `angular.json`, and 23.6's `Explorer*` and `proposal-card.ts`.

## Verification

**Shared surfaces:** the Productions list (its name cell now opens Production items), the entity types, the interop source kind's criteria, the Interoperability area's screens, the write-tool rosters and governance baseline, the stop and restart consequences, and the Fixed-strings table.

*Existing tests that assert a surface this story changes are updated in this story, and every test the story adds or changes passes on a freshly built instance and in either order.*

**Setup (slot B):**

- `rsync -a --checksum --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-20/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`
- then, in `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`, run `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)`
- Before a browser run: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`.
- Never the dev instance `ocupilot-slot-b`.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one class per call, each read from `%UnitTest_Result`. Classes:
  - new: `InteropItemControl`, `InteropItemGate`, `InteropStopOutcome`, `InteropItemDescriptor`
  - existing: `InteropControl`, `InteropDescriptor`, `InteropGate`
  - each sweep class touched: `ReadTool`, `SurfaceCoverage`, `Navigation`, `ClassicPageGate`, `MappingDescriptor`, `ToolEmit`, `ToolRoundTrip`, `ToolWrite`, `DraftRegistry`, `PortGate`, `Prohibited`, `Descriptor`, `SuperserverDescriptor`, `MftConnectionDescriptor`, `GovernanceBaseline`, `InteropFloor`, `InteropFloorRoutes`, `InteropFloorOwnPairs`, `SaveHoldCoverage`, `EndpointCoverage`
- `(loop)` `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/<file>`, one file per call: `interop-items.browser-spec.mjs`, `interop-productions.browser-spec.mjs`, and `a11y-structural-invariants.browser-spec.mjs` (DW-1337, both themes).
- `(loop)` Expected clean:
  - `cd ui && npm run test:tools && npm run test:components`
  - `uv run scripts/check-objectscript.py <changed .cls>`
  - `bash scripts/lint-docs.sh`
- `(once, before dev_complete, runner-side in foreground batches)`:
  - the full ObjectScript sweep on `ocupilot-b-ci`, one class at a time;
  - then `cd ui && npm test && npm run build`, under 3326 kB;
  - then `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`.
- `(CI)` The full browser suite.

**Planned pinning mutations (Rule 19):**

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | Drop `SeedCriteria` from the interop branch in `Read.cls` | `InteropItemDescriptor`'s screen-and-tool rows leg |
| AC2 | Skip `SaveToClass` after `EnableConfigItem` | `InteropItemControl`'s after-recompile leg |
| AC2 | Pass `pDoUpdate` 1 to `EnableConfigItem` | `InteropItemControl`'s no-job-change leg |
| AC3 | Drop the `TAKEN` check | `InteropItemControl`'s duplicate-add leg |
| AC3 | Drop the `ENABLEDREMOVE` check | `InteropItemControl`'s remove-while-enabled leg |
| AC4 | Drop each declared pair in turn: `%Ens_Portal:USE`, `%Ens_ProductionConfig:READ`, `%Ens_ProductionConfig:WRITE`, globals WRITE, routines WRITE | that pair's `InteropItemGate` leg |
| AC5 | Save only the class, not the configuration, on a disable | `InteropItemControl`'s pending-then-Update leg |
| AC6 | Remove stop's `AfterWrite` | `InteropStopOutcome`'s Suspended leg |
| AC6 | Drop the plural mapping in `Statused` | `InteropStopOutcome`'s partial-stop leg |

**Task 0 (ocupilot-b-ci, 2026-10-09; the five open cells, each agreeing with Design Notes).**

- Task 0: `Ens.Config.Production` opened at concurrency 4 makes a second writer's open wait. `%OpenId(...,4)` against a holder with 1.7 s left waited 1.69 s and opened; against a holder kept 25 s it failed after 10.00 s with `#5803 Failed to acquire exclusive lock on instance of 'Ens.Config.Production'`, which the port answers 503 `PORT.UNAVAILABLE`.
- Task 0: `NormalizePage` answers `EnsPortal.Dialog.ProductionAddService`, `...AddProcess` and `...AddOperation` exactly as typed. Each is a compiled class with RESOURCE `%Ens_ProductionConfig:WRITE`, and `InteropItemAdd.CLASSICPAGES` carries them.
- Task 0: with a system default supplying `Enabled`, `EnableConfigItem(...,1,0)` and `(...,0,0)` each answered OK, left the stored item's `Enabled` at 1, and set the default row's value to 1, then 0. The port refuses both by `DEFAULTSETTING` before any vendor call.
- Task 0: a partial stop (`StopProduction(3,0)` over the 20 s teardown item, `ErrJobsNotStopped` in 3.00 s) recorded 0 `%Ensemble/%Production/StartStop` rows. A control stop of the same production recorded 1.
- Task 0: one HTTP confirm per new tool answered one envelope. `interop.items.disable`, `.enable`, `.add` and `.remove` each answered 200 with a body that parses as one JSON document and holds no `}{` (`InteropItemControl`).

**Rule 19 results (ocupilot-b-ci, 2026-10-09; each reverted byte-identical, the tree recompiled after each).**

- mutation: AC1, `SeedCriteria` dropped from the interop branch of `Read.cls` -> red: `InteropItemControl.TestTheListAnswersTheProbesItems` (1 of 6, run 85) and `InteropItemDescriptor.TestTheScreenAndItsReadToolReadTheSameRows` (1 of 9, run 111).
- mutation: AC2, `SaveToClass` skipped after `EnableConfigItem` -> red: `InteropItemControl`'s disable/enable leg and its person's-actions leg (2 of 6, run 86).
- mutation: AC2, `EnableConfigItem`'s `pDoUpdate` 1 -> red: `InteropItemControl.TestAWriteOnARunningProductionChangesNoJobAndTheUpdateAppliesIt` alone (1 of 6, run 87).
- mutation: AC2, `SaveToClass(tNew)` skipped on an add -> red: `InteropItemControl`'s add/remove leg and its person's-actions leg (2 of 6, run 108).
- mutation: AC2, `ItemSave.Create` skips the port's add -> red: the person's-actions leg and the running-production leg (2 of 6, run 89).
- mutation: AC3, `TAKEN` dropped from `ReadItem` -> red: `InteropItemRefusals.TestATakenNameAndADuplicatedNameAreRefused` (1 of 5, run 90).
- mutation: AC3, `ENABLEDREMOVE` dropped -> red: `InteropItemRefusals`' state leg and mint leg (2 of 5, run 114).
- mutation: AC3, both `DEFAULTSETTING` refusals dropped -> red: `InteropItemRefusals.TestADefaultSettingAndAPoolZeroProcessAreRefused` (1 of 5, run 93) and `InteropItemDescriptor.TestTheItemRefusalMatrix` (1 of 9, run 106).
- mutation: AC3, `NameProblem` answering `""` -> red: `InteropItemRefusals.TestAnAddTheRulesRefuseIsRefusedWithItsViolations` (1 of 5, run 109); without its trailing-character rule -> `InteropItemDescriptor.TestTheItemNameRule` (run 107).
- mutation: AC3, `SourceControlled` refusal dropped from `PerformItem` -> red: `InteropItemGate.TestAnItemWriteInASourceControlledNamespaceIsRefused` (1 of 5, run 112).
- mutation: AC4, `PRODUCTIONPAIRS` without `%Ens_Portal:USE`, then without `%Ens_ProductionConfig:READ`, `ITEMWRITEPAIRS` without `%Ens_ProductionConfig:WRITE`, and an item write asking READ on the globals database -> red: `InteropItemGate.TestEachMissingPairIsRefusedByNameThroughThePort` alone each time (1 of 5, runs 94, 95, 96, 97).
- mutation: AC4, the routines-database pair dropped from `Invoke` -> red: `InteropItemGate.TestAnItemWriteNeedsTheRoutinesDatabaseToo` (1 of 5, run 98).
- mutation: AC4 tools, `InteropItemAction.PrivilegePairs` without its own WRITE pair -> red: `InteropItemGate.TestEachMissingPairIsRefusedByNameOnEachTool` (1 of 5, run 99) and `InteropItemDescriptor.TestTheToolPairsAddTheConfigurationWriteAndTheDatabaseWrites` (1 of 9, run 100).
- mutation: AC5, `EnableConfigItem` skipped so the class is saved and the configuration is not -> red: the running-production leg, the disable/enable leg and the person's-actions leg (3 of 6, run 88).
- mutation: AC6, `InteropProductionStop.AfterWrite` no longer overrides -> red: `InteropStopOutcome.TestAStopThatEndsSuspendedAnswersItsCode` (1 of 4, run 101).
- mutation: AC6, `Statused` without the `ErrJobsNotStopped` mapping -> red: `TestAStopWhoseJobOutlastsTheCapAnswersPartStopped` and `TestAPartialStopIsNotLogged` (2 of 4, run 102).
- mutation: declarations, `parentScope` `interoperability/processes` -> red: `InteropItemDescriptor`'s declaration and criteria legs (2 of 9, run 103); `CriteriaProblem` without the parented arm -> its criteria leg (run 105); `interop.items.remove` true in the baseline -> `TestTheToolShapes` (run 104).
- mutation: client, each of the list's `WARNING_CONSEQUENCES`, `TYPED_NAME_ROWS`, `DESTRUCTIVE_CONSEQUENCES` and `SCREEN_ACTION_DESCRIPTORS` entries and the `PRODUCTION_STATE_MOVED` branch removed in turn -> red: one or two legs of the handler spec's Production items block each; the store's `scope`, the dialog's class gate and the dialog's production dropped in turn -> red: one leg each of the store (5) and dialog (4) specs.
- mutation: browser, the list page's Add returning at once (bundle rebuilt and redeployed, then restored and redeployed) -> red: `interop-items.browser-spec.mjs`' Add leg (2 of 3 passed).
- mutation: P1, the `INTEROP.ITEM.PENDING` and `INTEROP.ITEM.REMOVE` branches deleted from `consequenceSentence` in `proposal-view.ts` -> red: `proposal-card.spec.ts`' production consequence loop (1 of 69).
- mutation: P2, the `PRODUCTION_STATE_MOVED` publication skipped in `TurnStore.decideProposal`'s error branch -> red: `turn.test.mjs`' Suspended-and-partly-stopped leg (1 of 86); publishing on any refusal instead -> red: that leg's other-refusal control and `a confirm the instance refused publishes no change` (2 of 86). `turn.ts`, `proposal-view.ts` and `screen-action-handler.ts` are in the bundle the browser specs load; no browser spec was run for this pass.
- mutation: P3, the `AuditModifyProductionConfig` call deleted from the remove branch of `PerformItem` -> red: `InteropItemControl.TestTheAgentsAddAndRemoveConfirmOverHttp` and `TestThePersonsRowActionsAndSaveWriteTheSameWay` (2 of 6, run 132).
- mutation: P4, `ItemSave.HandleCreate` holding the item's name alone -> red: `SaveHoldCoverage.TestACreateSaveHoldsTheKeyItsMintComputes`, the `/interop/items?ns=USER` leg alone (1 of 2, run 134).
- mutation: P5, the four `PORT.FIELD.SHAPE` arms deleted from `AddViolations` -> red: `InteropItemRefusals.TestThePortsOwnAddJudgesTheFieldsItself` (1 of 6, run 129).
- mutation: P6, a `LogFault` call added beside the `PARTSTOPPED` 409 in `Statused` -> red: `InteropStopOutcome.TestAPartialStopIsNotLogged`, its `Logged() = 0` assertion alone (1 of 4, run 136); a `LogFault` call added beside the `SOURCECONTROL` 409 in `PerformItem` -> red: `InteropItemGate.TestAnItemWriteInASourceControlledNamespaceIsRefused`, its `Logged() = 0` assertion alone (1 of 5, run 138).
- mutation: P8, `REASONSTOP` reworded without its partial-stop clause -> red: `InteropStopOutcome.TestTheStopAndRestartConsequencesNameAPartialStop` (1 of 4, run 139).

**Results (ocupilot-b-ci, 2026-10-09).**

- ObjectScript, latest run of each class read from `%UnitTest_Result` with the per-class SQL: 35 classes, 366 tests, 0 failed. The five new classes ran 6 (`InteropItemControl`), 6 (`InteropItemRefusals`), 5 (`InteropItemGate`), 9 (`InteropItemDescriptor`) and 4 (`InteropStopOutcome`) tests.
- Client: `npm run test:tools` 1,905 of 1,905; `npm run test:components` 2,778 of 2,778; the production build's initial total is 3,209,276 bytes (3,190,503 before), under `maximumWarning` 3326kB, so `angular.json` is unchanged.
- Browser, each file run alone against a redeployed bundle: `interop-items` 3 of 3, `interop-productions` 5 of 5, `a11y-structural-invariants` 13 of 13 with `interoperability/productions/items` in `SKIP`, since HSCUSTOM holds no production.
- `check-objectscript.py` over the 44 changed or new classes: 0 problems. `lint-docs.sh`: 0 issues in 264 files.

## Auto Run Result

Status: done
Blocking condition: none

**Summary.** `InteropPort` gains the `Items` endpoint (`LIST` on the `production` criterion, `ITEM`, `ENABLE`, `DISABLE`, `ADD`, `REMOVE`) behind its own gate, which adds WRITE on the namespace's routines database. Each item write saves the stored configuration and then the production class, and touches no job. New: the `production-item` entity type and its prohibited-set coverage, the `InteropItemList` descriptor, the item tools over `InteropItemMint`, `Area/Interop/ItemSave` with `POST /interop/items`, the four governance keys, the Add dialog, store and page, and the client, `strings.ts` and `EXPERIENCE.md` entries. DW-2157 and DW-2162 close in `InteropProductionStop.AfterWrite`, `Statused` and the reworded stop and restart sentences. Five new test classes (`InteropItemControl`, `InteropItemRefusals`, `InteropItemGate`, `InteropItemDescriptor`, `InteropStopOutcome`), the `InteropItemSeam` helper, and `interop-items.browser-spec.mjs`; the roster sweep updated 18 existing test classes and four client test files.

**Review.** The triage log holds 28 findings: high 0, medium 6, low 20, false 2. Ten were patched (P1 to P10, each with its test or mutation line under Verification) and 18 rejected with their reasons in the log; none is deferred beyond the one `deferred:` entry the implementer filed. Three rejected rows carry a `reopen_if` for the runner's ledger: the concurrency-4 and 503 test, the tool-level routines pair, and the shared browser helper.

**Verification (Rule 29: targeted; the full ObjectScript sweep, `npm test` as a whole and `smoke.sh` are left to the runner).**

- Task 0: all five cells agree with Design Notes (`Task 0:` lines under Verification).
- ObjectScript on `ocupilot-b-ci`, re-run by the lead on the patched tree: `InteropItemControl` 6, `InteropItemRefusals` 6, `InteropItemGate` 5, `InteropItemDescriptor` 9, `InteropStopOutcome` 4, `SaveHoldCoverage` 2, `InteropControl` 11, `InteropGate` 4, all green. The implementer's sweep of the roster classes is under Verification (35 classes, 366 tests, 0 failed).
- `check-objectscript.py` over the 44 changed or new classes: 0 problems. `lint-docs.sh`: 0 issues. `test:tools` 1,905 of 1,905. `test:components` 2,778 of 2,778 (218 files).
- Bundle: initial total 3,209,276 bytes, under `maximumWarning` 3326kB; `angular.json` unchanged.
- Browser, one file per call on the rebuilt and redeployed bundle: `interop-items` 3 of 3, `interop-productions` 5 of 5, `a11y-structural-invariants` 13 of 13.
- Every Rule 19 mutation line is under Verification (AC1 to AC6, the declarations, the client, the browser, P1 to P6 and P8).

**Residual risks.**

- Follow-up review recommended (`followup_review_recommended: true`, six medium patches): the agent-confirm refresh after a stop that ends Suspended or partly stopped (P2) is covered by a store test with a fake bus. No browser spec or live run drives an agent stop to its 409.
- The handoff subagent read only the ADs this story governs, not all 64 (CLAUDE.md asks for all of them); the later code-review stage's AD cross-check (Rule 6) is the backstop.
- P7's failed-audit log line has no test (no way found to make the audit call fail through `PerformItem`).
- P6 is a recorded mutation, not a positive control in the seam.
- Rule 31: `ItemSave` follows `DocDbSave` and `MftConnectionSave` without extending them, because a person's Save over a create tool has its own order of hold, rules, absence read and read-back. `InteropItemMint` extends `MappingMint`.
- A shared scratch `load.sh` in the common scratchpad was overwritten by another agent during the handoff, and one load ran that agent's Epic 23 source into `ocupilot-ci`. The handoff then used a private subdirectory. Separately, the lead launched `SaveHoldCoverage` and `InteropControl` plus `InteropGate` in one message once; `ci-runner` reported 0 overlaps and 0 foreign runs, and both were re-run singly and green.
