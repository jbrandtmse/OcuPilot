---
title: 'Story 20.3: Production items'
type: 'feature'
created: '2026-10-09'
status: 'draft'
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
  - `ENDPOINTS` :49
  - `Pairs` :185 maps every non-Productions endpoint to `CODEPAIRS`; Items and Settings must map to the production pairs.
  - `Serves` :199, `Invoke` :287 (gate order :294-325), `ReadState` :486, `Perform` :559
  - `Statused` :620 maps only the singular `ErrJobNotStopped` (DW-2162)
  - `SnippetForm`/`Snippet` :719/:734, `Literal` :759
- `src/OcuPilot/Api/InteropError.cls` (119 lines): add the codes. `Api/Error.cls`'s `INTEROP.` prefix branch already routes them, so no Error.cls edit is needed.
- `src/OcuPilot/Kernel/Shell/Namespaces.cls`: `GlobalDatabase` :84 reads `NamespaceInfo` :75. Add a sibling `RoutineDatabase` at the end of the class. `AtelierPort.DatabaseResources` :693 is the precedent.
- `src/OcuPilot/Kernel/EntityId.cls`: `JoinComposite`/`SplitComposite` :74/:81. `Screen/Tool/MappingMint.cls`:22-54 composes a two-part id at a mint.

### Tools (20.2's are the template)

- `Screen/Tool/InteropProductionAction.cls`: `PrivilegePairs` :120, `PortQuery` :144, `StateDiff` :158, `READSVALUES`/`READANSWERS` :31-34.
- `Screen/Tool/InteropProductionStop.cls`: add `AfterWrite`. `Write.AfterWrite` is at :282; `Operation.ApplyAt` (`Kernel/Proposal/Operation.cls`:473) marks a write applied before `AfterWrite` runs.
- `Screen/Tool/Write.cls` parameters:
  - `CREATES` :151, `SCREENACTIONS` :167, `READSVALUES` :176, `SCREENVALUES` :226, `SCREENOPTIONAL` :232, `PRECONDITIONCODES` :508, `READBACKFIELDS` :958
  - `ReadBackGone` :294, `ComposeCreate` :352, `ArgumentProblem` :920
- Precedents:
  - create: `ExplorerDocDbCreate.cls` :23-77, `ExplorerCreate.cls` :31-45, :112, :131
  - destructive action: `ExplorerDocDbDelete.cls` :21-72
  - declared-value action: `ScreenAccessAddPair.cls` :18-48, `EncryptionKeyFileAddKey.cls`
- AD-55 Save route: `Area/Security/MftConnectionSave.cls`, which takes `Operation.HoldTool` at :73 and runs `Unexpected` :224 and `Prohibited` :246. Routes are at `Api/Router.cls`:253-255.

### Screens and registry

- `Screen/Descriptor/InteropProductionList.cls`:23-67 is the shape. `WalletSecretList.cls`:37-83 is a child list (`parentScope`, one criterion), opened from its parent's name cell by `ui/src/app/core/navigation.ts` `childListFor` :329.
- `Screen/Registry.cls`: the interop source rules :1282-1297; the criteria port list :1683-1684, which refuses `interop`; the one-criterion rule for a parent-scoped read :1694-1697.
- `ui/tools/screen-mirror.mjs`: the same rules at :1405-1418 and :1885-1887; `interopEndpoints` :1095. Regenerate `ui/src/app/core/screens.generated.ts`.
- `Kernel/EntityType.cls`:98 `TYPES` (62 entries); `Kernel/Proposal/Prohibited.cls`:
  - `COVEREDTYPES` :250, `TYPEPRODUCTION` :616, the chain :1295, the branch :1550-1555
  - `PermittedChangeFields` :1052, `PermittedCreateFields` :1186
- `Kernel/Governance/Baseline.cls`:209-213, the interop keys.

### Client

- `ui/src/app/shell/screen-action-handler.ts`:
  - `SCREEN_ACTION_DESCRIPTORS` :64 (interop :113)
  - `VALUE_ACTIONS` :347, `UNDRAWN_ACTIONS` :352
  - `DESTRUCTIVE_ACTIONS` :424, which already holds no `remove`; `LockList` uses `remove` for its own destructive dialog
  - `DESTRUCTIVE_CONSEQUENCES` :452, `WARNING_CONSEQUENCES` :575 (interop :603-608), `startFor` :1009
- `ui/src/app/core/screen-actions.ts` `ACTION_LABELS` :79-112; `ui/src/app/core/proposal-view.ts` `INTEROP` consequences :364-367 and :481-484.
- `ui/src/app/core/strings.ts`: the interop block :6149-6233, each key citing `EXPERIENCE.md:604`.
- `ui/tools/interop.test.mjs`: `SENTENCES` :29-43, the 15 s pin :71.
- `ui/browser/interop-productions.browser-spec.mjs` probe hooks :51-55 and :151-174; `waitForMapAnswered` (`browser/namespace-features.mjs`:62).

### Tests and fixtures

- `Test/ProductionProbe.cls`:
  - `CheckOwn` :112, `Create` :120, `Send` :154, `SetSetting` :175, `Settle` :247, `Remove` :322
  - the probe op class text :42-84
- `Test/InteropControl.cls` (445 lines) and `Test/InteropGate.cls`: the job-and-`Login` probe at :197-265.
- Classic pages: `EnsPortal.ProductionConfig` sets RESOURCE `%Ens_ProductionConfig:READ` and EDITRESOURCE `:WRITE` (PC:25, :29). `EnsPortal.Dialog.ProductionAddService`, `…AddProcess` and `…AddOperation` (base `ProductionAddHost`, RESOURCE `:WRITE`).

## Tasks & Acceptance

**Execution:**

- [ ] **Task 0 (`ocupilot-b-ci` only, through `docker exec`).** Re-measure only the cells the plan left open, and record them as `Task 0:` lines under Verification:
  - that `Ens.Config.Production` opened at concurrency 4 makes a second writer's open wait;
  - the `NormalizePage` spellings of the three add-host dialogs;
  - the SDS-supplied `Enabled` refusal;
  - one HTTP confirm per new tool answering exactly one envelope.
  - A cell that disagrees with the Design Notes vocabulary table: HALT `intent gap`.
- [ ] `src/OcuPilot/Port/InteropPort.cls` (extend):
  - **Endpoints and pairs.**
    - `ENDPOINTS` gains `Items,Settings`. `Pairs` maps both to `PRODUCTIONPAIRS`, plus a new `ITEMWRITEPAIRS = "%Ens_ProductionConfig:WRITE"` for their writes. A write also needs WRITE on the namespace's globals and routines databases (measured: `<PROTECT>` on `^Ens.Config.ItemD` and `^oddDEF`).
    - Types: `Items` `LIST` (criterion `production`), `ITEM`, `ENABLE`, `DISABLE`, `ADD`, `REMOVE`; `Settings` `LIST` (criterion `item`, the item's composite id), `SETTING`, `SET`, `RESET`.
    - `IsWrite` stays the production writes'. An `IsItemWrite` serves the gate.
  - **Fresh reads.**
    - `ITEM` and `SETTING` answer the row plus `Namespace`, `ProductionState`, `Current` and `Count`. With `ACTIONKEY` they refuse by code, as `Refusal` does.
    - An absent item is 404 `PORT.NOTFOUND`, unlogged.
    - `Count > 1` is `.AMBIGUOUS`.
    - Source control enabled is `.SOURCECONTROL`, read through an overridable `SourceControlled(ns)` seam.
  - **Writes, in one switched block.**
    - Open the production at concurrency 4, so concurrent writers on one production are serialized by the vendor's row lock.
    - Then:
      - enable/disable: `Ens.Director.EnableConfigItem("<prod>||<name>", x, 0)`, which records the vendor's own event;
      - add: a new `Ens.Config.Item`, then `Items.Insert` and `%Save`;
      - remove: `RemoveItem` and `%Save`;
      - set/reset: `Settings` (Host/Adapter) or the Core property, then the item's `%Save`.
    - Then `SaveToClass(item)` every time, and drop every reference before the restore.
    - Add, remove, set and reset record `%Ensemble/%Production/ModifyConfiguration` through `Ens.Util.Auditing.AuditModifyProductionConfig`, naming the operation and setting names, never a value. The classic page's server methods record this event.
    - Validate before any vendor call. Values go through the class's own `<Name>IsValid`, Host target `ClassName`, Adapter target `AdapterClassName()`, Core `Ens.Config.Item`. A class must pass `Ens.Config.Item.GetBusinessType` ∈ 1, 2, 3. Name rules are in Design Notes.
  - **Reads and settings rows.**
    - Settings rows come from `PopulateVirtualSettings` plus the four Core rows: `{Production, Item, Target, Name, Value, Default, Source, Category, Type, Masked}`.
    - `Value` and `Default` read empty, with `Masked` true, when `Kernel/Audit/Log.IsCredentialName` matches the name.
  - **DW-2162:** `Statused` maps `<Ens>ErrJobsNotStopped` to 409 `INTEROP.PRODUCTION.PARTSTOPPED`, unlogged.
  - **Scripts:** `Snippet` gains one objectscript branch per new write type, each block closed on its line (AD-59).
- [ ] `src/OcuPilot/Api/InteropError.cls`: the codes and reasons in Design Notes; extend `PreconditionCodes` with the item and setting state codes.
- [ ] `src/OcuPilot/Kernel/Shell/Namespaces.cls`: append `RoutineDatabase(ns, .resource, .readOnly)`, mirroring `GlobalDatabase`.
- [ ] `src/OcuPilot/Kernel/EntityType.cls`:
  - append `production-item` (composite `[Production, Name]`) and `production-item-setting` (`[Production, Item, Target, Name]`), both kept exactly (no `IDRULES` row).
  - Counts in `Test/Descriptor.cls`:1761, `Test/SuperserverDescriptor.cls`:130 and `Test/MftConnectionDescriptor.cls`:141: 62 → 64.
- [ ] `src/OcuPilot/Kernel/Proposal/Prohibited.cls`: cover both types (`COVEREDTYPES`, two `TYPE*`, the chain, `ReviewedFewOnly` branches).
  - `PermittedCreateFields(production-item)` = `Name,ClassName,PoolSize,Enabled,Category,Comment`.
  - `PermittedChangeFields(production-item-setting)` = `Value`.
  - AD-10 gains no arm (Design Notes).
- [ ] `src/OcuPilot/Screen/Read.cls`: the interop branch passes one criterion through to the port's query.
- [ ] `src/OcuPilot/Screen/Registry.cls` :1683-1684 and `ui/tools/screen-mirror.mjs` :1885-1887: admit `interop` criteria only on a parent-scoped read. The edit is in place (Q3 clearance). Regenerate `screens.generated.ts`.
- [ ] `src/OcuPilot/Screen/Descriptor/InteropItemList.cls` (new):
  - `route` `interoperability/productions/items`, `parentScope` `interoperability/productions`, `sideBarPosition` 0, archetype `list`
  - entity type `production-item`, composite id `[Production, Name]`
  - read `{interop, Items, LIST}`, criterion `production`
  - `privileges` `[%Ens_Portal:USE, %Ens_ProductionConfig:READ]`, own `%Ens_ProductionConfig:READ`
  - `classicPage` `EnsPortal.ProductionConfig`
  - `primaryAction` `add`; `rowActions` `enable, disable, remove`
  - context fields `Name, ClassName, Type, Enabled, PoolSize`
  - three prompts; `toolIdentifier` `interop.items`
- [ ] `src/OcuPilot/Screen/Descriptor/InteropItemSettingList.cls` (new):
  - `route` `interoperability/productions/items/settings`, `parentScope` the items route
  - entity type `production-item-setting`, read `{interop, Settings, LIST}`, criterion `item`
  - the same pairs and classic page
  - `rowActions` `set, reset`
  - context `Target, Name, Value, Source`, with `Value` masked as read
  - three prompts; `toolIdentifier` `interop.itemsettings`
- [ ] Tools (new):
  - `Screen/Tool/InteropItemAction.cls` (abstract, `PORTCLASS` `InteropPort`, `READTYPE` `ITEM`, `READSVALUES` 1, `SENDSBODY` 0, `NAMESPACEFIELD`). `PrivilegePairs` = screen pairs + `%Ens_ProductionConfig:WRITE` + globals- and routines-database WRITE + `WithClassicPages`, each refused by name before any port call. `Consequence` answers `INTEROP.ITEM.PENDING` when the fresh read finds the production current and Running.
  - `InteropItemEnable`/`InteropItemDisable`: `STATEFIELD` `Enabled`, subject `Enabled,EnabledSource,Namespace`.
  - `InteropItemRemove`: `DESTRUCTIVE` 1, `CHANGEACTION` deleted, `CONSEQUENCECODE` `INTEROP.ITEM.REMOVE`, subject `Enabled,ClassName,Namespace`.
  - `InteropItemAdd`: `CREATES` 1; arguments `Production, Name, ClassName, PoolSize, Enabled, Category, Comment`; id composed as `MappingMint` does; `READBACKFIELDS` the six fields; `CLASSICPAGES` the three add-host dialogs (Task 0 spellings).
  - `InteropItemSettingAction` (abstract, `READTYPE` `SETTING`), with `InteropItemSettingSet` (`SCREENVALUES` `set=Value`) and `InteropItemSettingReset`, `STATEFIELD` `Value`.
- [ ] `src/OcuPilot/Screen/Tool/InteropProductionStop.cls` (DW-2157): `AfterWrite` re-reads `STATE`. Suspended answers 409 `INTEROP.PRODUCTION.SUSPENDED` with `detail.state`, so the write stays applied and marked.
- [ ] `src/OcuPilot/Area/Interop/ItemSave.cls` (new) and an add-only route `POST /interop/items` in `Api/Router.cls`: the person's Add, as `MftConnectionSave` does:
  - the hold;
  - `Unexpected`;
  - the rules;
  - the absence read;
  - `ComposeCreate`;
  - `Prohibited`;
  - the port's `ADD`;
  - the read-back.
- [ ] `src/OcuPilot/Kernel/Governance/Baseline.cls`: append six keys. `interop.items.remove` is `false`; the others are `true`.
- [ ] `src/OcuPilot/Test/ProductionProbe.cls` (add-only): a second op class whose `OnTearDown` waits `TearDownSeconds`, for DW-2162, removed by `Remove`.
- [ ] Tests (new; armed under `OCUPILOT_ALLOW_PRINCIPALS`, one class per run; each creates its probe production and removes it):
  - `Test/InteropItemControl.cls`: every matrix row through mint and confirm and through the screen caller. After each write it asserts:
    - the stored row;
    - the class XData, after a recompile;
    - no job started or stopped, with the production reading update pending when running;
    - the change event, the marker, the vendor audit row (names, no values) and the snippets.
  - `Test/InteropItemSettings.cls`: set, reset, refusals and masking, through both callers and the read tool.
  - `Test/InteropItemGate.cls`: each missing pair refused by name on the port, the route, the tool and the Save. The split-database routines leg uses `Test/InteropItemSeam.cls`, which also drives `.SOURCECONTROL`.
  - `Test/InteropStopOutcome.cls`: the DW-2157 and DW-2162 legs, through confirm and the row action.
  - `Test/InteropItemDescriptor.cls`: declarations, registry rules on synthetic sources, and every new code resolving through `ReasonFor`.
  - A leg that confirms `interop.items.remove` sets its governance key from a snapshot and restores it. A test asserts only on its own probe rows, never on an empty store.
- [ ] Roster sweep (Rule 30; Design Notes › Shared surfaces):
  - `ReadTool` :93-94
  - `SurfaceCoverage`
  - `Navigation` :529-530
  - `navigation.test.mjs` :344
  - `ClassicPageGate` :75 and :154
  - `MappingDescriptor` :24
  - `ToolEmit` :226
  - `ToolRoundTrip` :84
  - `ToolWrite` :1338
  - `PortGate` :29
  - `Prohibited` :232
  - `GovernanceBaseline` :15
  - the `InteropFloor*` rosters, including `InteropFloor` :357, which says no principal holds a write
  - `InteropFloorRoutes`, `SaveHoldCoverage`, `EndpointCoverage`
  - `screen-mirror.test.mjs` :2387, :2877
  - `interop.test.mjs`
  - `ci-throwaway.sh` :402 `# classes:` with `ci.test.mjs`
- [ ] Client:
  - `screen-action-handler.ts`:
    - add `InteropItemList` and `InteropItemSettingList` to `SCREEN_ACTION_DESCRIPTORS`
    - `DESTRUCTIVE_CONSEQUENCES` and typed name for `remove`
    - a `setting` kind in `VALUE_ACTIONS`: one text field, or a checkbox for a `%Library.Boolean` setting
    - on `INTEROP.PRODUCTION.SUSPENDED`/`.PARTSTOPPED`, re-read the Productions list
  - a new `ui/src/app/areas/interoperability/interop-item-add-dialog.ts` posting to `/api/ocupilot/interop/items`
  - `screen-actions.ts` labels; `proposal-view.ts` consequences
  - `strings.ts`: add-only keys, plus the two reworded stop and restart values (Q3)
- [ ] `EXPERIENCE.md`:
  - `:604` gains every new literal and a Story 20.3 Where clause, and the two stop/restart literals are reworded (Q3)
  - `:173` names the Add item and Set value dialogs
  - `ui/tools/strings.test.mjs` bound 3000 → 3400, with one comment line
  - then `cd ui && npm run test:tools`
- [ ] `ui/browser/interop-items.browser-spec.mjs` (new; `before`/`after` run `ProductionProbe.Remove`/`Create`; every step waits for `waitForMapAnswered` and the list's rows). In USER:
  - open the probe production's items from its name cell;
  - disable and enable `OcuPilotProbeOp`;
  - add and then remove (typed name) an item;
  - set and reset `HangSeconds` on the settings list.

**Acceptance Criteria:**

- **AC1 (lists, integration):** Given the probe production in USER on `ocupilot-b-ci`, when its Productions row's name is opened and then an item's name, then Production items and Item settings list its items and settings through `InteropPort`, and `interop.items.read` and `interop.itemsettings.read` return the same rows.
- **AC2 (confirmed item writes, integration):** Given each of enable, disable, add, remove, set and reset, when the agent proposes it and the person confirms it over HTTP, or the person acts on the screen, then the change shows in the stored configuration and in the production class after a recompile. A running production keeps its jobs and reads update pending, which its card says.
- **AC3 (refusals):** Given any refusal row of the matrix, when it is proposed or acted on, then it is refused by its code before any vendor call.
- **AC4 (gates):** Given a principal lacking one declared pair, when it reads, proposes, acts or saves, then it is refused naming that pair before any vendor call.
- **AC5 (secrets):** Given a setting whose name matches the credential pattern, when it is read, sent as context or set, then its value never leaves the instance and the write is refused.
- **AC6 (DW-2157, DW-2162):** Given a stop that ends Suspended, or jobs that outlast the cap, when stop or restart runs, then it answers its own code and sentence. The row shows the state the production was left in, and the stop and restart consequences name a partial stop.

## Spec Change Log

- 2026-10-09, runner, orchestrator rulings (by=merge_gate, feature 67e70c72): split approved, so item settings (the Item settings list, set, reset, the setting entity type, secret-named settings) move to Story 20.22, which reads the first plan at `git show 6def26fa:_bmad-output/implementation-artifacts/spec-20-3-production-items.md`; Q2 A (configuration and class only; 20.2's Update applies; remove refused while enabled); Q3 cleared on union terms. Status reset to draft for a re-plan.

## Review Triage Log

## Design Notes

**Governing ADs:** AD-1, AD-3, AD-5, AD-6, AD-7, AD-8, AD-10, AD-11, AD-13, AD-14, AD-15, AD-16, AD-21, AD-22, AD-24, AD-29, AD-34, AD-35, AD-36, AD-39, AD-44, AD-51, AD-52, AD-53, AD-54, AD-55, AD-56, AD-58, AD-59, AD-60, AD-62.

**Vocabulary, measured at this plan on `ocupilot-b-ci`** (USER, `ProductionProbe` plus a scratch class, all removed afterwards):

- **Stopped production.**
  - `EnableConfigItem(…,0,0)` answers OK and records `%Ensemble/%Production/ModifyConfiguration` ("item disabled by <caller>"). It does **not** touch the class XData (the runtime differs from the class), and compiling the class reloaded it, with the item enabled again and every item id renumbered.
  - Repeating it answers `<Ens>ErrGeneral` "already disabled". An unknown item answers `<Ens>ErrConfigItemNotFound`, and an unknown production `ErrProductionNotRegistered`.
- **Settings and classes.**
  - Item `%Save` followed by `SaveToClass(item)` answers OK, and the XData carries the change. The class is then not up to date, which is the vendor's own path.
  - `SetItemSettingValue` stored `"abc"` in an `%Integer` setting and an unknown setting name. The vendor validates neither, while the classic page calls `<Name>IsValid`. `PoolSize` -1 is refused #7204.
- **Add and remove.**
  - Add stored a duplicate enabled name, and also a non-host class.
  - A missing class saved the table row and then failed `SaveToClass` with `<CLASS DOES NOT EXIST>`, leaving the table and the class apart. `Bad|Name` and `_Bad` are refused at `%Save`.
  - Remove answers OK.
  - No vendor audit event records `SetItemSettingValue`, the composed save, add or remove.
- **Running production.**
  - Each item write leaves `NeedsUpdate` 1, with the vendor's reason ("Job … needs to be terminated", "1 new job … needs to be started", "Registration … needs to be deleted"). `UpdateProduction(10,0)` applied each one.
  - With the item busy past a 3 s cap, `UpdateProduction` answers `<Ens>ErrJobNotStopped` in 3.01 s. The disable stays stored and the job runs on until a later update.
  - `EnableConfigItem(…,1)` runs that update itself with the uncapped production timeout.
- **Privilege.**
  - A principal holding only `%Ens_Portal:U` and `%DB_USER:RW` performed every item write and the audit call, so the vendor checks nothing.
  - With `%DB_USER:R` it got `<PROTECT>` on `^Ens.Config.ItemD` (the item save) and on `^oddDEF` (`SaveToClass`). The audit call landed for both principals.
  - Stock roles: `%EnsRole_Administrator` and `_WebDeveloper` hold `%Ens_ProductionConfig:W`; `_Operator` holds `:R` plus `%Ens_ConfigItemRun:U` and `%Ens_ProductionRun:U`.
- **DW-2157:** stop(15) with three messages queued behind a 3 s handler answered OK in 5.50 s, and the production reads Suspended.
- **DW-2162:** an op whose `OnTearDown` waits 20 s made stop(3) answer `<Ens>ErrJobsNotStopped` in 3.02 s. The production reads Running with `NeedsUpdate` 1 and only the stuck job left, and after 22 s it still reads Running with no jobs.
- **Half-applied states the vendor can leave:**
  - A configuration change the running production has not yet taken (`NeedsUpdate`), which a busy update prolongs.
  - A class that is stale after `EnableConfigItem`, which a recompile reverts.
  - A table row whose `SaveToClass` failed.
  - The port's validation and its always-`SaveToClass` rule close the last two. Q2 decides the first.
- **Source control:** off in USER. The classic save goes through the Hidden `prodConfigSCPage.CallProductionUpdateAndSaveToClass`, read from the instance, which calls the source-control hooks around `%Save` and `SaveToClass`.

**Decisions this plan takes:**

- **Name rule:** the vendor's `CheckForIllegalCharacters` plus the classic client's checks:
  - 1-128 characters, with no leading or trailing space
  - none of `| ; , [`
  - not starting with `-` or `_`, not ending with `-`, `!` or `$`
  - not `*`
- **Identity:** an item is `[Production, Name]`, and a duplicate name is refused, never guessed.
- **Classic pages and pairs:** the four non-add writes are performed on `EnsPortal.ProductionConfig` itself, so they declare no `CLASSICPAGES`.
  - Named limits: a holder of only `%Ens_ConfigItemRun:USE`, which the classic page admits for enable, disable and Apply, is refused.
  - An item's own class is not checked for a mapped package (inference).
- **AD-10:** OcuPilot runs no production of its own, so no item is self-protection, and no arm is added.
- **Audit (AD-15, AD-53):**
  - Enable and disable carry the vendor's own event. Add, remove, set and reset record the same event through the documented `Ens.Util.Auditing`, as the classic server methods do, so no named gap is added.
  - Named limit: a partial stop (DW-2162) records neither the vendor's StartStop event nor a marker. Its ledger row carries the code.
- **New codes and sentences** (`InteropError`; each also in `strings.ts` and `EXPERIENCE.md:604`):
  - `INTEROP.ITEM.ENABLED`: "This item is already enabled."
  - `INTEROP.ITEM.DISABLED`: "This item is already disabled."
  - `INTEROP.ITEM.DEFAULTSETTING`: "A system default setting decides whether this item is enabled, so change it in System Default Settings."
  - `INTEROP.ITEM.POOLZERO`: "This business process runs in the production's shared actor pool, so it cannot be disabled."
  - `INTEROP.ITEM.TAKEN`: "This production already holds an item of that name."
  - `INTEROP.ITEM.AMBIGUOUS`: "This production holds more than one item of that name, so change it in the classic production configuration page."
  - `INTEROP.ITEM.CLASS`: "Name a business service, business process or business operation class compiled in this namespace."
  - `INTEROP.ITEM.NAME`: the name rule above, as one sentence.
  - `INTEROP.ITEM.ENABLEDREMOVE`: "Disable this item before removing it."
  - `INTEROP.ITEM.SOURCECONTROL`: "This namespace uses source control, so change this production's items in the classic production configuration page."
  - consequence `INTEROP.ITEM.PENDING`: "This production is running, so the change takes effect when the production is updated on Productions."
  - consequence `INTEROP.ITEM.REMOVE`: "Removing this item deletes it and every setting it holds from the production."
  - `INTEROP.SETTING.UNKNOWN`: "This item has no setting of that name."
  - `INTEROP.SETTING.VALUE`: "The item's class does not accept this value for that setting."
  - `INTEROP.SETTING.SAME`: "This setting already holds that value."
  - `INTEROP.SETTING.NODEFAULT`: "This setting holds no value of the production's own, so there is nothing to reset."
  - `INTEROP.SETTING.SECRET`: "This setting holds a secret, so set it in the classic production configuration page or point the item at a credentials entry."
  - `INTEROP.PRODUCTION.SUSPENDED`: "The production stopped, but messages still queued left it Suspended rather than Stopped. Start it to process them."
  - `INTEROP.PRODUCTION.PARTSTOPPED`: "Some of the production's jobs did not stop within 15 seconds, so it is left partly stopped and still reads Running. Stop it again to finish, or update it to start its jobs again."
  - Stop's reworded consequence ends "…nothing is stopped; if a job then takes longer than 15 seconds to stop, the production is left partly stopped." Restart's is reworded the same way.
  - About 55 literals in all, with the titles, columns, type and source words, prompts and dialog labels. The table reads 2,967 (measured), so it moves to about 3,022.
- **Client weight:** two small dialogs, handler entries and strings, about 15-25 kB (inference) against 3,178,307 bytes and a 3326 kB warning. Measure it at implement.

**Questions returned to the orchestrator (posture and contended edits; this spec is written to the recommended options):**

- **Q1 (settings that hold secrets or locations).**
  - Measured: the classic page shows every value in clear to `%Ens_ProductionConfig:READ` holders and audits `old>>new` values in clear. Most credentials are references (`Credentials` ids), but a host class may declare any property, a literal password included, as a setting. `ExtraHeaders` can carry an `Authorization` header, and file adapters' settings are server paths.
  - **(A, recommended)** A name matching the Conventions › Secrets pattern is secret. Its value and default are never returned (screen, tool, context, ledger) and never set through OcuPilot (`INTEROP.SETTING.SECRET`, both callers). Every other setting is shown, reaches the model through AD-60, and is settable by both callers, validated by its class. A location setting is permitted as its host's own validated value, extending AD-21's third case to item settings, with the diff row naming it. Named limit: a secret under a non-matching name.
  - **(B)** As A, but a person (never the agent) may replace a secret-named setting write-only, through a new per-row secret channel. That needs kernel work, because `secretArguments` is static.
  - **(C)** Mirror the classic page: show, send and set every value.
  - **(D)** As A, and also refuse every location-valued setting under AD-21's strict reading.
- **Q2 (a write that could stop a running production).**
  - **(A, recommended)** Item writes change only the stored configuration and the class. A running production reads update pending, and 20.2's confirmed Update applies the change. A remove is refused while the item is enabled. AD-62 rule 6 stays true, every write stays short, and every job stop stays a separately confirmed Update.
  - **(B)** Chain the capped update in the same request, as the classic page chains its Update dialog. A busy update then answers a new partial code (stored, not applied), and AD-62 rule 6 is amended.
- **Q3 (non-add-only edits in files Epic 18 is changing).** Clearance for:
  - `Screen/Registry.cls`:1683-1684 and `ui/tools/screen-mirror.mjs`:1885-1887 (the criteria port list). Epic 18's hunks are at :2958-2967 and :315.
  - the two stop and restart literals in `strings.ts` and `EXPERIENCE.md:604`. Epic 18's EXPERIENCE.md hunks are at :471 and :475; its strings.ts lines are add-only elsewhere.
  - All measured line-clean on 2026-10-09. Recommended: clear, as 20.2's count-word edits were.
- **Split (`oversized`).** Recommended seam: keep items here (the `Items` endpoint, the list, enable, disable, add and remove, DW-2157 and DW-2162). Move Item settings, `set`, `reset`, `production-item-setting` and Q1 to a new Story 20.22 that consumes this one. Q2 and Q3 stay with 20.3.

**Spine decisions for the runner (Rule 20), once ruled:**

- AD-62 gains `Items` and `Settings`, configuration-only item writes, the always-`SaveToClass` rule, the source-control refusal, the audit emission and the pairs.
- AD-36's interop clause takes one parent criterion.
- AD-13 adds the two composite ids, kept exactly.
- AD-44 adds the add tool's `CLASSICPAGES`.
- AD-8 adds the item writes' extra pairs.
- AD-21 extends its third case, per Q1.
- Conventions › Secrets names item settings.

**Integration ACs, Consumed-by and Consumes:**

- Integration: AC1 and AC2 run against a real instance (`ocupilot-b-ci`, HTTP confirm and the screen route).
- Consumed-by: 20.4 (per-host tabs opened from an item row), 20.6 (testing a host named by its item), 20.8 (the configuration diagram's items), 20.12 (guided workflows: disable, then Update).
- Consumes: 20.2 (`InteropPort`, `production`, Productions list, Update), 18.14's and 6.6's child-list pattern, and `Test/ProductionProbe`.

**Ledger inbox (Rule 17):** DW-2157 is addressed by AC6 (stop's `AfterWrite`, `SUSPENDED`), and DW-2162 by AC6 (`PARTSTOPPED` and the reworded consequences). Both follow the orchestrator's 2026-10-07 rulings.

**Contended files (Rule 11), checked against `.worktrees/epic-18` on 2026-10-09:**

- Single-line rosters both epics append to: `EntityType.cls`:98; `Prohibited.cls`:250 and :1295; `Test/` `PortGate`:29, `ClassicPageGate`:75 and :154, `MappingDescriptor`:24, `ReadTool`:93-94, `Descriptor`:1761, `Prohibited`:232 and `ToolRoundTrip`:84. The union is taken at merge, as 20.2 did.
- Add-only: `Baseline.cls`, `Router.cls`, `SurfaceCoverage`, `SaveHoldCoverage`, `EndpointCoverage`, `screen-action-handler.ts`, `strings.ts` (new keys), `screens.generated.ts` (regenerated).
- Clearance: Q3.
- Untouched: `Mint.cls`, `ScreenAction.cls`, `EntityRef.cls`, `AdminPort.cls`, `angular.json`, and 23.6's `Explorer*` and `proposal-card.ts`.

## Verification

**Shared surfaces:** the Productions list (its name cell now opens Production items), the entity types, the interop source kind's criteria, the Interoperability navigation count, the write-tool rosters, and the Fixed-strings table. *Existing tests that assert a surface this story changes are updated in this story, and every test the story adds or changes passes on a freshly built instance and in either order.*

**Setup (slot B):**

- `rsync -a --checksum --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-20/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`
- then in `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`, run `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)`
- Before a browser run: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`.
- Never the dev instance `ocupilot-slot-b`.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one class per call, each read from `%UnitTest_Result`. Classes:
  - `InteropItemControl`, `InteropItemSettings`, `InteropItemGate`, `InteropStopOutcome`, `InteropItemDescriptor`
  - `InteropControl`, `InteropDescriptor`, `InteropGate`
  - each sweep class touched: `ReadTool`, `SurfaceCoverage`, `Navigation`, `ClassicPageGate`, `MappingDescriptor`, `ToolEmit`, `ToolRoundTrip`, `ToolWrite`, `DraftRegistry`, `PortGate`, `Prohibited`, `Descriptor`, `SuperserverDescriptor`, `MftConnectionDescriptor`, `GovernanceBaseline`, `InteropFloor`, `InteropFloorRoutes`, `InteropFloorOwnPairs`, `SaveHoldCoverage`, `EndpointCoverage`
- `(loop)` `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/<file>`, one file per call: `interop-items.browser-spec.mjs`, `interop-productions.browser-spec.mjs`, `a11y-structural-invariants.browser-spec.mjs` (DW-1337, both themes).
- `(loop)` Expected clean:
  - `cd ui && npm run test:tools && npm run test:components`
  - `uv run scripts/check-objectscript.py <changed .cls>`
  - `bash scripts/lint-docs.sh`
- `(once, before dev_complete, runner-side in foreground batches)` The full ObjectScript sweep on `ocupilot-b-ci`, one class at a time. Then `cd ui && npm test && npm run build` (under 3326 kB) and `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`.
- `(CI)` The full browser suite.

**Planned pinning mutations (Rule 19):**

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | Drop the criterion from the interop branch in `Read.cls` | `InteropItemDescriptor`'s screen and tool equality |
| AC2 | Skip `SaveToClass` after `EnableConfigItem` | `InteropItemControl`'s after-recompile leg |
| AC2 | Call `UpdateProduction` after a disable | `InteropItemControl`'s no-job-change leg |
| AC3 | Drop the `TAKEN` check | `InteropItemControl`'s duplicate leg |
| AC4 | Drop the routines-database pair | `InteropItemGate`'s seam leg |
| AC5 | Unmask `Value` | `InteropItemSettings`'s masking leg |
| AC6 | Remove stop's `AfterWrite` | `InteropStopOutcome`'s Suspended leg |
| AC6 | Map the plural code to `$$$OK` | `InteropStopOutcome`'s partial-stop leg |

## Auto Run Result

Status: blocked
Blocking condition: intent gap: Q1 how item settings that hold secrets or server locations are shown, sent to the model and edited (recommended A: credential-pattern names never returned and never set through OcuPilot; others shown, sent and settable, location settings permitted under AD-21's third case); Q2 whether an item write on a running production also runs the update that stops or starts its jobs (recommended A: configuration-only, 20.2's confirmed Update applies it, remove refused while enabled); Q3 clearance for in-place edits in Epic 18's files (Registry.cls:1683-1684, screen-mirror.mjs:1885-1887, the stop and restart literals in strings.ts and EXPERIENCE.md:604; all line-clean). Split recommended: item settings to a new Story 20.22.
