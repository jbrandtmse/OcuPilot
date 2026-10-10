---
title: 'Story 20.22: Production item settings'
type: 'feature'
created: '2026-10-10'
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

**Problem:** A production item's settings can be read and changed only in the classic production configuration page. OcuPilot lists a production's items (Story 20.3) but none of their Core, Host or Adapter settings, and it cannot set or reset one.

**Approach:** Extend `Port/InteropPort` (AD-62) with a `Settings` endpoint. A grandchild list, Item settings, opens from a Production items row and reads through the port. Two confirmed writes, set and reset, are item writes: they change the stored configuration and the production class (`SaveToClass`), and nothing else. The owner's Q1 ruling ("A: hide secrets, allow paths (Recommended)") decides secrets and server paths. DW-2268's shared parent lands here.

## Boundaries & Constraints

**Always:**

- **Path settings keep PathPort's self-protection refusals** (orchestrator ruling under its grant, 2026-10-09, feature dbaee68c; AD-10's self-protection family; the owner's "keep only self-protection" and 09-29 "nothing writes into the manager directory"), from either caller, evaluated at the mint and again at the write: a directory setting is refused for the manager directory itself (`PATH.MANAGERDIR`) and for the served directory or anything under it (`PATH.SERVED`); a file setting is refused for a file directly in the manager directory (`PATH.MANAGER`) or under the served directory (`PATH.SERVED`). The predicates and codes are PathPort's own (`IsManagerDirectory`, `InServedDirectory`, `DirectlyInManagerDirectory`), reused, never copied (Rule 31). Every other path is accepted as its declaring class validates it. The plan measures whether an accepted ancestor directory whose item descends into subdirectories (an inbound adapter's subdirectory levels) can reach a protected directory, and either refuses that case or names it as a limit in AD-21's ninth case.
- A setting whose name the Conventions › Secrets pattern matches (`Kernel/Audit/Log.IsCredentialName`) has its value and default answered empty by the port, with `Secret` true. So neither ever reaches the screen, a tool, the context or the ledger. Its set and reset are refused `INTEROP.SETTING.SECRET` from both callers, before any vendor call.
- Every other setting is shown, reaches the model through AD-60, and is settable by both callers. Its value is validated by the class that declares it: Core by `Ens.Config.Item.<Name>IsValid`, Host by the item's class, Adapter by `AdapterClassName()`.
- A server-path setting (editor context `directorySelector` or `fileSelector`) is set as its class validates it, under AD-21's new named case, and the card names it a location on the server (`INTEROP.SETTING.LOCATION`).
- A setting write takes an item write's gate, pairs, source-control refusal and concurrency-4 open, and always calls `SaveToClass` (AD-62 as amended at 20.3). It records `%Ensemble/%Production/ModifyConfiguration` through `Ens.Util.Auditing.AuditModifyProductionConfig`, naming the setting and never a value.
- A running production reads update pending afterwards, and 20.2's confirmed Update applies the change (Q2).
- FR-80 applies: one descriptor, one port, derived read tool. Both callers run one operation (AD-53, AD-55), and the screen action route takes the per-target hold (DW-1882). Both governance keys ship `true`; neither write is destructive (AD-22).
- Edits to shared files are add-only, except the in-place edits Design Notes › Contended files lists.

**Never:**

- Never call `Ens.Director.SetItemSettingValue` (it validates nothing and saves through the Hidden `prodConfigSCPage`), `UpdateProduction`, start, stop, restart, recover, `CleanProduction` or `%Api.InteropEditors.*`.
- No production-level settings, System Default Settings edits, `Enabled` (20.3's enable and disable), read-only Core rows (`Classname`, `Description`, `AdapterClassname`, `AdapterDescription`, URLs), per-host tabs (20.4), or credentials editing (Epic 21).
- Never route a path setting through `PathPort`, and never read a secret value in order to compare, mask or log it.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| List | An item row opened (`?ns=USER`) | One row per Core (settable), Host and Adapter setting: `Production, Item, Target, Name, Value, Source, Default, DefaultSource, Type, Category, Location, Secret`. `Source` is one of `production`, `systemDefault`, `classDefault`, `registry`. The read tool answers the same rows. | 404 `PORT.NOTFOUND` for an unknown production or item; 409 `INTEROP.ITEM.AMBIGUOUS` |
| Set a Host or Adapter setting | `InitSeconds` = `7` | The production's own element is stored, and the class XData carries it after a recompile | 422 `INTEROP.SETTING.VALUE` (`abc`); 409 `.SAME` at the write when the production already holds that value (the mint's own "nothing would change" refuses an equal value first) |
| Set a Core setting | `Comment`, `PoolSize` | The item property is stored, and the XData carries it | 422 `.VALUE`; 409 `.SUPPLIED` when a system default decides it (`PoolSize`, `Schedule`, `LogTraceEvents`) |
| Reset | The production holds its own value | The element is removed; the system or class default applies | 409 `.DEFAULTED` when it holds none; `.CORE` for a Core setting |
| Secret-named | `ApiToken` with a production value and a system default | `Value` and `Default` read `""`, `Secret` true, everywhere | 409 `.SECRET` on set and reset, both callers, before any vendor call |
| Registry-supplied | The value comes from a service registry entry | Listed, with `Source` `registry` | 409 `.SUPPLIED` on set and reset |
| Server path | An Adapter `FilePath` (`directorySelector`) | `Location` true; set accepted as validated; the card carries `.LOCATION` | 422 `.VALUE` |
| White space | A Host or Adapter value with a leading or trailing space or a control character | Not stored (the vendor would store it trimmed, measured) | 422 `.VALUE` |
| Unknown setting | A name the item's classes do not declare, or `Enabled` | — | 404 `PORT.NOTFOUND`, unlogged |
| Source control, gates | As 20.3 | Refused before any vendor call | 409 `INTEROP.ITEM.SOURCECONTROL`; 403 naming the failed pair |

</intent-contract>

## Code Map

### Port and errors

- `src/OcuPilot/Port/InteropPort.cls`, 20.3's shape to extend:
  - `ENDPOINTS` :51 (read by `ui/tools/screen-mirror.mjs`:1081-1090); `IsItemWrite` :224; `Pairs` :234; `Serves` :249
  - `Invoke` :338 and `Admit` :413 (the routines WRITE for an item write, :426-430)
  - `InvokeItems` :680, the sibling `InvokeSettings` copies (Rule 31: a separate row shape and criterion)
  - `AddViolations` :753, the sibling `SettingViolations` follows (gated by `Admit`, vendor classes only while switched)
  - `ItemRefusalToken` :851; `GatherItems` :906; `ReadItem` :997
  - `PerformItem` :1058: the open at concurrency 4, the refusal, the act, `SaveToClass`, the audit and the after-read. The SET and RESET branches extend it, so there is no second open-lock-save skeleton.
  - `Statused` :1194; `SnippetForm` :1294; `Snippet` :1312; `ItemSnippet` :1340; `Literal` :1377
- `src/OcuPilot/Api/InteropError.cls` (227 lines):
  - `ITEMVALUE` :134 with its reason :136 is the shape
  - `ConsequenceCodes` :165, `ItemPreconditionCodes` :179, `PreconditionCodes` :187, `ReasonFor` :194-225
  - `Api/Error.cls` routes `INTEROP.*` through `ReasonForViolation` :1275/:1444 and is at the 1,000-parameter limit, so it is not edited.
- `src/OcuPilot/Kernel/Audit/Log.cls` `IsCredentialName` :180. `Port/OAuthResourceServerPort.cls` `SettingsOf` :249-265 is the port-side precedent: it drops a row the pattern matches.
- Vendor, through the worktree's `irislib` link:
  - `Ens/Config/Item.cls`: `PopulateVirtualSettings` :642-727, whose 18-element row begins at :709; `GetStaticSettings` :488 (Core rows; system default precedence :529-538); `FindSettingByName` :345; `Settings` :77
  - `Ens/Config/Setting.cls` `ValueSet` :18 trims
  - `EnsConstants.inc` :167-171 source codes: 0 ReadOnly, 1 Production, 2 System, 3 Property, 4 Registry
  - `EnsPortal/ProductionConfig.cls` `SaveSettingsToServer` :6306-6591 is the classic save:
    - Core values are validated through `Ens.Config.Item.<Prop>IsValid` (:6471), Host and Adapter values through the class's own `<Name>IsValid` (:6495)
    - a reset is `RemoveSettingByName` (:6602)
    - it saves with `item.%Save()` then `SaveToClass(item)`, and audits `old>>new` values (:6588)
  - `Ens/Util/Auditing.cls` `AuditModifyProductionConfig` :182 joins `pActions` and its subscripts into `EventData`
  - `EnsPortal/Dialog/ProductionItemSettings.cls` (RESOURCE `%Ens_ProductionConfig:READ`) is the classic dialog where a reset is chosen

### Tools

- `Screen/Tool/InteropProductionAction.cls` (188 lines) and `InteropItemAction.cls` (192) hold the DW-2268 copy:
  - `IdArgument`, `IdParam`, `SettableFields`, `Consequence`, `PrivilegePairs` and `PortQuery` differ only in values
  - the production tools' marker is `State` (string); the item tools' is `Enabled` (boolean); the production tools ask for no routines WRITE
- `Screen/Tool/InteropItemMint.cls` extends `MappingMint.cls`, which hard-codes two parts (:39-54).
- `Screen/Tool/InteropItemAdd.cls` is the precedent for `SENDSBODY` 1 over this port: `FieldRows` :57, `SettableFields` :50, `ArgumentProblem` and `ConfirmProblem` over a public port helper.
- `Screen/Tool/ScreenAccessAddPair.cls` is the one-declared-value precedent: `SCREENVALUES`, and `ScreenActionDelta` passing the value through.
- `Screen/Tool/Write.cls`:
  - `SCREENVALUES` :226, `SCREENOPTIONAL` :232
  - `ScreenActionValueNames` :683 and `ScreenActionOptionalNames` :701 parse one grammar
  - `READBACKFIELDS` :969
- `Kernel/Proposal/ReadBack.cls` :147-149: an action-kind write's read-back is `nothingSent`; a merge compares.
- `Api/ScreenAction.cls` `Values` :521-581 refuses an empty value (:547). The route takes the target hold (:279-289).
- Ledger and step redaction:
  - `Kernel/Agent/Dispatch.cls` :221-227 reads the tool's `SecretArguments` and feeds `StepArguments`, `StepTarget` and `RecordLedger`
  - `Kernel/Audit/Ledger.cls` `RedactArguments` :405
  - `Screen/Tool/Registry.cls` `SecretArguments` :499

### Screens, registry, entity types

- `Screen/Descriptor/InteropItemList.cls` (84 lines) is the shape the new descriptor copies. Its criterion `production` (:64) has `maxLength` 128 and a `hint`.
- `Screen/Read.cls` :547-569 is the interop branch: it requires the route criterion and calls `SeedCriteria` (:1098).
- `Screen/Registry.cls`:
  - :1278-1298 the interop source rules
  - :1683-1687 interop criteria only when the read is parent-scoped
  - :1695-1698 exactly one criterion
  - `ParentScopeResolutionProblem` :3830-3860 refuses no grandchild; the mirror's copy is at `screen-mirror.mjs`:2637-2660
  - No registry edit is needed.
- `Kernel/EntityType.cls` `TYPES` :104, 64 entries, `production-item` last. `--check` reads "64 entity type(s)".
- `Kernel/Proposal/Prohibited.cls`:
  - `COVEREDTYPES` :259; `TYPEPRODUCTIONITEM` :637
  - the `UNCOVERED` chain :1319-1323
  - `PermittedChangeFields` :1072-1117; `ReviewedFewOnly` :4075; the item change branch :1597-1600
- `Kernel/Governance/Baseline.cls` :216-219, the `interop.items.*` keys.

### Client

- `ui/src/app/shell/screen-outlet.ts`:266 maps a descriptor to its page.
- `ui/src/app/areas/interoperability/interop-item-list.page.ts` (84 lines) is the wrapper page; `os-management/ecp-data-server-list.page.ts`:117/:171-188 and `ecp-data-server-status-dialog.ts` (242 lines) are the page-registered one-value action and dialog.
- `ui/src/app/shell/screen-action-handler.ts`:
  - `SCREEN_ACTION_DESCRIPTORS` :67-123 (`InteropItemList` :122)
  - `UNDRAWN_ACTIONS` :358-382
  - `WARNING_CONSEQUENCES` :589-630 (`InteropItemList` :626-629)
- `ui/src/app/core/screen-actions.ts` `DESCRIPTOR_ACTION_LABELS` :155+; global `reset` reads "Reset counters" (:135).
- `ui/src/app/core/proposal-view.ts` :369-370 and :494-496 (`INTEROP.ITEM.PENDING`); `journalSentence` :392 fills a value from a diff row.
- `ui/src/app/core/navigation.ts`:
  - `routeIdFor` :621-625 compares the first part's name with the criterion's, so `Production` against `production` misses for Production items (inference)
  - `childListFor` :329; `parentCriteria` :427-437
  - `shell/data-table.ts`:654-679 links a name cell to the child list
- `ui/src/app/core/strings.ts` interop block :6167-6309.
  - These values exist already: 'Value' `errorLogColumnValue`, 'Default' `tableColumnDefault`, 'Source' `auditEventFieldSource`, 'Target' `agentLedgerColumnTarget`, 'Name' `tableColumnName`.
  - `ui/tools/strings.test.mjs` bounds the table at 3400 (:606-611); it holds about 3,013 literals (inference).
  - EXPERIENCE.md's last Fixed-strings row is :604; dialogs are at :173.
- `ui/browser/interop-items.browser-spec.mjs` (342 lines) is the probe pattern (`before` :180, `openItems` :164). `browser/structural-walk.mjs` holds `SKIP` (:105).

### Tests and fixtures

- `Test/ProductionProbe.cls`:
  - the op class's `SETTINGS` is `HangSeconds:Probe,InitSeconds:Probe` (both `%Integer`, no adapter)
  - helpers: `SetSetting` :257, `AddItem` :175, `Create` :136, `Remove` :404
- Story 20.3's fixtures:
  - `InteropItemControl` (533 lines): `IdOf` :113, `Items` :142, `ConfirmHttp` :293, the governance snapshot :413-436
  - `InteropItemGate` (477 lines): its principals :49/:440
  - `InteropItemRefusals` `PutDefault` and `RemoveDefault` :75/:101
  - `InteropItemSeam` `Arm` :14
  - `InteropItemGateSplit` `CreateSplit` :66

## Tasks & Acceptance

**Execution:**

- [ ] **Task 0 (`ocupilot-b-ci` only, through `docker exec`; record each as a `Task 0:` line under Verification; a cell that disagrees with Design Notes › Measured is HALT `intent gap`):**
  - On the running probe production, a setting set and a reset leave the production reading update pending, and `UpdateProduction(10,0)` applies each.
  - A principal holding only `%Ens_Portal:U`, `%Ens_ProductionConfig:RW` and `%DB_USER:RW` lists, sets and resets, the audit call included. With `%DB_USER:R`, the write is refused `<PROTECT>`.
  - An item of `EnsLib.File.PassthroughOperation` lists its Adapter rows, with `FilePath`'s editor context.
  - `NormalizePage` spells `EnsPortal.Dialog.ProductionItemSettings` as written.
  - One HTTP confirm per new tool answers exactly one envelope.
- [ ] `src/OcuPilot/Screen/Tool/InteropAction.cls` (new, abstract; DW-2268). This is the shared parent of the production, item and setting tools.
  - It holds `PORTCLASS`, `SENDSBODY` 0, `DESTRUCTIVE` 0, `READSVALUES` 1, `NAMESPACEFIELD`, `WRITERESOURCE`, `WRITEPERMISSION`, `DATABASEPERMISSION`, `CONSEQUENCECODE`, and two new parameters:
    - `ROUTINESDATABASE` (0): whether the pairs add WRITE on the namespace's routines database
    - `STATEMARKER`: the field whose absence marks a call's arguments rather than a stored payload
  - Methods:
    - `IdArgument` returns `Name`; `IdParam` returns the port's `IDKEY`; `SettableFields` returns `AdmittedFields`; `Consequence` returns `CONSEQUENCECODE`
    - `PrivilegePairs`: the screen's pairs, then the own pair, then globals WRITE (and routines WRITE when `ROUTINESDATABASE` is set), then `WithClassicPages`
    - `PortQuery`: the action key when the marker is absent, then the payload's namespace
  - `InteropProductionAction` (marker `State`) and `InteropItemAction` (marker `Enabled`, `ROUTINESDATABASE` 1) extend it and keep only what differs. Their behavior is unchanged.
- [ ] `src/OcuPilot/Screen/Tool/MappingMint.cls`: add `PARTARGUMENTS`, the comma-separated arguments joined before the id. When empty it is `NAMESPACEARGUMENT`, so every mapping tool is unchanged. Each part must be non-empty and free of U+0001, with the same sentences. `src/OcuPilot/Screen/Tool/InteropSettingMint.cls` (new) extends `InteropItemMint` with `PARTARGUMENTS` `Production,Item,Target`.
- [ ] `src/OcuPilot/Port/InteropPort.cls` (extend):
  - **Endpoint, types and pairs.**
    - `ENDPOINTS` gains `Settings`, with types `LIST` (criterion `item`), `SETTING`, `SET` and `RESET`.
    - `IsSettingWrite` is added. In `Pairs` and `Admit`, a setting write is an item write: `ITEMWRITEPAIRS`, plus WRITE on the globals and routines databases.
  - **The id and the criterion.**
    - The id is the composite `[Production, Item, Target, Name]`.
    - `item` takes the item's composite, which is what the screen's route carries, or the vendor's config name `Production||Item`, which the read tool's hint asks for. Neither name can hold `|` (Design Notes).
    - `Target` is one of `Core`, `Host` or `Adapter`.
  - **Rows.** `GatherSettings` is a sibling of `GatherItems`. In the item's namespace, on the one item of that name, it reads `PopulateVirtualSettings` and `GetStaticSettings`:
    - It skips Core rows whose source is ReadOnly, and `Enabled`.
    - It maps the source codes to words.
    - `Location` is true when the editor context's component (the part before `?`) is `directorySelector` or `fileSelector`.
    - After the namespace is restored, a name `IsCredentialName` matches gets `Value` and `Default` set to `""` and `Secret` true.
  - **`SETTING`** answers the row plus `Namespace` and `Count`.
    - With the action key, `SettingRefusalToken` (pure) refuses `SUPPLIED` (a Core row at source 2, or source 4), and for reset `CORE` then `DEFAULTED`.
    - `AMBIGUOUS` and `SOURCECONTROL` come first, as on an item.
    - `SAME` needs the requested value, which an action-composed read does not carry. So it is judged at the write: the mint's own "nothing would change" refuses an equal value before then.
  - **`SECRET`** is refused first, on the name alone, for `SET`, `RESET` and an action-composed `SETTING`, before the namespace is switched.
  - **`SettingViolations`** (public, gated by `Admit`):
    - `Value` must be a JSON string.
    - The declaring class's `<Name>IsValid` must answer OK. It answers a `%Status` (measured), which is refused 422 `.VALUE` on field `Value`.
    - A Host or Adapter value must have no space or control character at either end.
  - **`PerformItem` gains SET and RESET**, under the same concurrency-4 open:
    - re-judge with `SettingRefusalToken`, and for set refuse `SAME` when the production's own value already equals the body's `Value`
    - Core: set the item property
    - Host or Adapter: update or insert the `Ens.Config.Setting` (`Target`, `Name`, `Value`); a reset removes it
    - then `tItem.%Save()`, then `AuditModifyProductionConfig` with `pActions` `"setting set by OcuPilot"` or `"setting reset by OcuPilot"`, subscripted by `<Target>:<Name>` and never a value
    - then `SaveToClass(tItem)`; the after-read is the setting's row
  - **Scripts.** `SnippetForm` and `Snippet` gain one objectscript branch per SET and RESET, each line closed (AD-59), the value rendered through `Literal`, with the production dropped on the last line.
- [ ] `src/OcuPilot/Api/InteropError.cls`: add the codes and sentences in Design Notes, and extend `ConsequenceCodes`, `PreconditionCodes` and `ReasonFor`.
- [ ] `src/OcuPilot/Screen/Tool/Write.cls` (add-only methods; one in-place call):
  - `SCREENEMPTY` (the `SCREENOPTIONAL` grammar) and `ScreenActionEmptyNames` share one parsing helper with `ScreenActionOptionalNames`.
  - `CallSecretNames(pInput)` returns `""` by default.
- [ ] `src/OcuPilot/Api/ScreenAction.cls` :547: an empty value passes when `ScreenActionEmptyNames` names it.
- [ ] `src/OcuPilot/Screen/Tool/Registry.cls` (add `CallSecretNames(pTool, pInput)`) and `Kernel/Agent/Dispatch.cls` :221: union the call's names into `tSecretNames`, so the step and the ledger row redact them (AD-3's layer 1).
- [ ] Tools (new):
  - `InteropSettingAction` (abstract), extending `InteropItemAction`:
    - `DESCRIPTORCLASS` `InteropItemSettingList`, `READTYPE` `SETTING`, `READANSWERS` the row with `Namespace` and `Count`, `STATEMARKER` `Source`, `Endpoint` `Settings`, the setting mint
    - `InputSchema` adds `Item` and `Target` (an enum), both required
    - `Consequence`: `.LOCATION` when the payload's `Location` is true, else `INTEROP.ITEM.PENDING`
    - `ArgumentProblem` and `ConfirmProblem`: `SECRET` on the name, then the port's `SettingViolations` for set
    - `CallSecretNames`: `Value` when the call's `Name` matches the pattern
  - `InteropSettingSet` (`interop.itemsettings.set`), a merge (`SENDSBODY` 1, so its read-back compares `Value`):
    - `SettableFields` `Value`; `FieldRows` one string row
    - `SCREENACTIONS` `set`, `SCREENVALUES` and `SCREENEMPTY` `set=Value`, `ScreenActionDelta` as `ScreenAccessAddPair`'s
    - `CHANGEACTION` `updated`; `PRECONDITIONCODES` `SECRET`, `SUPPLIED`, `ITEM.AMBIGUOUS`, `ITEM.SOURCECONTROL`, `NAMESPACE`
  - `InteropSettingReset` (`interop.itemsettings.reset`), action-style:
    - `FINGERPRINTSUBJECT` `Value,Source,Default,Namespace`; `STATEFIELD` and `PRECONDITIONFIELD` `Source`
    - `StateDiff`: `Value` moving from the current value to `Default`
    - `CLASSICPAGES` `EnsPortal.Dialog.ProductionItemSettings`
    - `PRECONDITIONCODES` `SECRET`, `CORE`, `DEFAULTED`, `SUPPLIED`, `ITEM.AMBIGUOUS`, `ITEM.SOURCECONTROL`, `NAMESPACE`
- [ ] `src/OcuPilot/Screen/Descriptor/InteropItemSettingList.cls` (new):
  - `route` `interoperability/productions/items/settings`, `parentScope` the items route, `sideBarPosition` 0, archetype `list`
  - entity type `production-item-setting`, id composite `[Production, Item, Target, Name]`
  - read `{interop, Settings, LIST}`, criterion `item`: text, `maxLength` 352, with a `hint` asking for `<production>||<item>` as `interop.items.read` answers them
  - `InteropItemList`'s privileges and own pair; `classicPage` `EnsPortal.ProductionConfig`
  - `rowActions` `set`, `reset`; columns `Name, Target, Value, Source, Default`
  - context fields `Target, Name, Value, Source`, `secretFields` `[]` (the port answers no secret)
  - three prompts; `toolIdentifier` `interop.itemsettings`
- [ ] `Kernel/EntityType.cls`: append `production-item-setting` (no `IDRULES` row). `Kernel/Proposal/Prohibited.cls`, add-only: `COVEREDTYPES`, `TYPEPRODUCTIONITEMSETTING`, a clause appended to the :1319 chain, a `ReviewedFewOnly` branch, and `PermittedChangeFields(production-item-setting)` = `Value`. `Kernel/Governance/Baseline.cls`: append both keys `true`.
- [ ] Client:
  - `areas/interoperability/interop-item-setting-list.page.ts` (new; mapped in `screen-outlet.ts`). It registers `set` and opens `interop-item-setting-dialog.ts` (new), following ECP's page and dialog.
    - The dialog shows a text field, or a checkbox for `%Library.Boolean` that sends `1` or `0`; the current value and the default; the PENDING sentence, or the LOCATION sentence for a location row.
    - It sends through `sendFor` with `{Value}`, an empty value allowed, and shows a refusal on its field.
    - On a `Secret` row, Set shows the `SECRET` sentence and opens no dialog.
  - `screen-action-handler.ts` (add-only): the descriptor; `set` undrawn; `reset` with the PENDING warning.
  - `screen-actions.ts`: labels "Set value" and "Reset to default".
  - `proposal-view.ts`: `.LOCATION` composed with the diff row's `after`, as `journalSentence` does.
  - `navigation.ts` `routeIdFor`: a parent-scoped composite list opens on the leading parts that form its parent screen's id (1 for a simple id, the part count for a composite one). This also corrects Production items' toast (inference until its leg reddens).
  - `strings.ts` (add-only), and regenerate `screens.generated.ts`.
- [ ] `EXPERIENCE.md`: append a Story 20.22 Where clause to :604 with every new literal; :173 names the Set value dialog. Then `cd ui && npm run test:tools`.
- [ ] `Test/ProductionProbe.cls` (add-only): the op class gains `ApiToken` (`%String`, `ApiToken:Probe`). A helper adds an `EnsLib.File.PassthroughOperation` item and removes it.
- [ ] Tests (new). Each class is armed under `OCUPILOT_ALLOW_PRINCIPALS`, run one class per call, creates and removes its own probe, restores governance and any default setting it made, and stays under about 500 lines:
  - `Test/InteropSettingControl.cls`: list rows and sources, then set and reset of a Host setting (`InitSeconds`) and a Core one (`Comment`), through mint and HTTP confirm and through the screen action route, empty value included. After each it asserts:
    - the stored element or property
    - the XData after a recompile
    - on a running production, no job change, update pending, and Update applying it
    - the change event, the marker, the audit row (the setting's name and no value), the snippet and the read-back
  - `Test/InteropSettingRefusals.cls`: every refusal row of the matrix, through the port, the mint and the screen action route, each with no vendor call made (the stored configuration and the class unchanged).
  - `Test/InteropSettingSecrets.cls`: `ApiToken` with a production value and a system default.
    - The value appears in no list row, read-tool result, screen-context payload, ledger row or step.
    - Set and reset are refused `.SECRET` from both callers.
    - A value the agent sent under that name reads as the redaction mark in the ledger row and the step.
  - `Test/InteropSettingDescriptor.cls`: the declarations, screen-and-tool row equality, tool shapes and keys, the `SettingRefusalToken` matrix, the `item` criterion's two spellings, `Location`, the script forms, every code through `ReasonFor`, and the DW-2268 parent: `%Dictionary.MethodDefinition` holds none of the six methods on `InteropProductionAction` or `InteropItemAction`.
  - Gates: add the two tools to `InteropItemGate`'s per-tool roster if it stays under about 500 lines. Otherwise add `Test/InteropSettingGate.cls`, which reuses its principals through a parameter, as P9 did.
  - Kernel legs, each an added method:
    - `ScreenAccessRefusals`: an empty `Pair`, which no `SCREENEMPTY` names, is still refused 400.
    - `LedgerRedaction`: a tool's `CallSecretNames` redacts that argument in the ledger row and the step, and adds nothing when it answers `""`.
- [ ] Roster sweep (Rule 30):
  - the entity count 64 → 65 at `Descriptor`:1763, `SuperserverDescriptor`:130 and `MftConnectionDescriptor`:141
  - `ReadTool` :93-94 (328 → 329)
  - `SurfaceCoverage` :219/:371-374
  - `Navigation` :530-531
  - `Prohibited` (test) :232
  - `ToolRoundTrip` :85
  - `ToolWrite` :1338 (29 → 31)
  - `ToolEmit` :226-232
  - `ClassicPageGate` :75 and `MappingDescriptor` :24, for reset's classic page
  - `InteropFloor` :42/:45 and `InteropFloorTurn`, if the operator's derived set gains the screen or the read tool
  - `screen-mirror.test.mjs` :1382/:2394, `navigation.test.mjs` :347, `structural-walk.mjs` `SKIP`, `interop.test.mjs` `SENTENCES`
  - `ci-throwaway.sh`, a `# classes:` line, with `ci.test.mjs`
  - Governance, ToolDispatch and GovernanceBaseline's disabled rosters are unchanged.
- [ ] `ui/browser/interop-item-settings.browser-spec.mjs` (new). `before` removes any leftover probe and creates one; `after` removes it. Every step waits for the rows. In USER:
  - open the probe production, then `OcuPilotProbeOp`
  - set `InitSeconds` through the dialog, then reset it
  - on `ApiToken`, Set shows the secret sentence

**Acceptance Criteria:**

- **AC1 (list, integration):** Given the probe production in USER on `ocupilot-b-ci`, when `OcuPilotProbeOp` is opened from Production items, then Item settings lists its settable Core settings and its Host settings through `InteropPort`, each with its value, source and default, and `interop.itemsettings.read` returns the same rows.
- **AC2 (set and reset, integration):** Given a Host and a Core setting, when the agent proposes set or reset and the person confirms it over HTTP, or the person acts on the screen, then the stored configuration and the production class after a recompile hold the change. A reset leaves the default in force. On a running production no job starts or stops, the production reads update pending, and 20.2's confirmed Update applies the change. Each card carries `INTEROP.ITEM.PENDING`.
- **AC3 (secrets):** Given a secret-named setting with a production value and a system default, when it is listed, read by the tool, sent as context, or set or reset by either caller, then its value and default are never returned, the write is refused `INTEROP.SETTING.SECRET` before any vendor call, and a value the agent sent appears in no ledger row or step.
- **AC4 (refusals):** Given a value the declaring class refuses, or any other refusal row of the matrix, when it is proposed or acted on, then it is refused by its code before any vendor call.
- **AC5 (server path):** Given an Adapter `FilePath` setting, when it is set, then the value is stored as its class validates it, and the card and the dialog name it a location on the server.
- **AC6 (gates):** Given a principal lacking one declared pair, when it reads, proposes, confirms or acts, then it is refused naming that pair before any vendor call.
- **AC7 (DW-2268):** Given the production, item and setting tools, when compiled, then neither `InteropProductionAction` nor `InteropItemAction` declares `IdArgument`, `IdParam`, `SettableFields`, `Consequence`, `PortQuery` or `PrivilegePairs`: each is inherited from `InteropAction`, and 20.2's and 20.3's own test classes pass unchanged. A leaf tool may still override one where its behavior differs, as the add does.
- **AC8 (navigation):** Given a confirmed setting write, when its toast is opened, then Item settings opens on that item; and a Production items toast opens on its production.

## Spec Change Log

- 2026-10-10, runner, orchestrator ruling (feature dbaee68c): path settings keep PathPort's self-protection refusals (Always); status reset to draft for a re-plan that adds the refusals, their tests and the subdirectory-descent measurement.

## Review Triage Log

## Design Notes

**Governing ADs:** AD-3, AD-5, AD-6, AD-8, AD-10, AD-11, AD-13, AD-14, AD-15, AD-16, AD-21, AD-22, AD-24, AD-29, AD-34, AD-35, AD-36, AD-39, AD-41, AD-44, AD-51, AD-53, AD-54, AD-55, AD-56, AD-58, AD-59, AD-60, AD-62.

**Rulings** (orchestrator, by=merge_gate):

- Q1, 2026-10-09: the owner's words, "A: hide secrets, allow paths (Recommended)".
- Q2, from 20.3: a configuration and class change only.
- No security-posture question remains. Every non-secret-named setting is settable, `Credentials` (a reference, plural, unmatched by the pattern) among them, and that is what Q1 decided. A path's reach follows AD-21's third case, which Q1 extends, as the AD-21 draft names.

**Measured at this plan on `ocupilot-b-ci`** (USER, `ProductionProbe` created and removed, two system defaults created and deleted):

- `PopulateVirtualSettings` answered 17 Host rows for the probe op.
- `GetStaticSettings` answered 11 Core rows. The four read-only rows are at source 0, and `PoolSize` reads `def=""`.
- A system default on `PoolSize` read `val=3 vs=2 def=1 ds=1`: the default wins over the production's value.
- A system default on `InitSeconds` read `vs=2 def=9`.
- `InitSecondsIsValid("abc")` and `("")` answered error statuses; `(7)` answered OK.
- `Ens.Config.Setting.Value` stored `"  5 "_$C(9)` as `5`.
- Inserting an element, then item `%Save` and `SaveToClass(item)`, put `InitSeconds` in the XData, and a recompile kept it. `RemoveAt`, then `%Save` and `SaveToClass`, followed by a recompile, left none.
- Read in source, not measured: `EnsLib.File.PassthroughOperation`'s adapter `EnsLib.File.OutboundAdapter` declares `FilePath:Basic:directorySelector`, and also `RegistryID`. Task 0 lists those rows.

**Decisions this plan takes:**

- **Set is a merge and reset is an action.** A merge sends `{Value}` over the `SETTING` read, so its fingerprint covers the row, the mint refuses "nothing would change", and its read-back compares `Value` (AD-4, AD-58). A reset sends nothing (AD-51), so its read-back says nothing was sent.
- **"The diff row names it" (the story's path criterion).** The set's `Value` row carries the path. The card's `.LOCATION` consequence, composed from that row, names it a location on the server, as the card does under AD-21's third case.
- **Two spellings of the criterion.** A model cannot reliably type U+0001, and the vendor's own config name `Production||Item` is unambiguous: the item name rule and class names exclude `|`. The screen keeps AD-13's composite.
- **Empty values.** A person may clear a value. `SCREENEMPTY` admits only the names a tool declares, which here is only set's `Value`.
- **Ledger.** A secret-named setting's value an agent sends is redacted per call. The refusal alone would not keep it out of the ledger, because `Dispatch` records refused calls (AD-41).
- **AD-10** gains no arm: OcuPilot runs no production of its own.
- **Classic pages (AD-44):** set is performed on `EnsPortal.ProductionConfig` itself; reset is chosen in `EnsPortal.Dialog.ProductionItemSettings`.
- **Rule 31.** The siblings each new piece extends are named in the Code Map and Tasks:
  - `InteropAction` closes DW-2268.
  - `InteropSettingMint` extends `InteropItemMint` through `MappingMint`'s new hook.
  - `PerformItem` is extended, not copied.
  - Copies, with their reasons:
    - `InvokeSettings` and `GatherSettings` sit beside `InvokeItems` and `GatherItems`: another row shape and criterion.
    - The page and dialog follow ECP's: the slice rule forbids extending another area's dialog, and the shell's `VALUE_ACTIONS` kinds are specific to passwords and roles.
- **Codes and sentences** (`InteropError`, `strings.ts`, `EXPERIENCE.md`:604):
  - `INTEROP.SETTING.SECRET`: "This setting holds a secret, so OcuPilot neither shows nor sets it. Set it in the classic production configuration page, or point the item at a credentials entry."
  - `INTEROP.SETTING.SUPPLIED`: "A system default setting or a service registry entry decides this setting's value, so change it there."
  - `INTEROP.SETTING.SAME`: "This setting already holds that value."
  - `INTEROP.SETTING.DEFAULTED`: "This setting already takes its default value, so there is nothing to reset."
  - `INTEROP.SETTING.CORE`: "This is one of the item's own properties, which has no default to return to, so set the value you want instead."
  - `INTEROP.SETTING.VALUE`: "The item's class does not accept this value for this setting."
  - consequence `INTEROP.SETTING.LOCATION`: "<value> is a location on this server that the item reads or writes when it runs. The change takes effect when this production next starts or, while it runs, when it is updated on Productions."
  - Reused: `INTEROP.ITEM.PENDING`, `.AMBIGUOUS` and `.SOURCECONTROL`.
- **Fixed strings and weight.** About 30 literals in all, with the title, empty states, prompts, source and target words, labels and dialog text: the table moves from about 3,013 to about 3,043, under 3400. The client weight is a page, a dialog and strings, about 10-15 kB (inference) against 3,209,473 bytes and the 3326kB warning. Implement measures and states it.

**Spine drafts (Rule 20, one line each; the runner writes them at the spec gate):**

- **AD-21:**

  > **The ninth is a production item's own server-path setting** [AMENDED <date>, Story 20.22 spec gate, owner decision "A: hide secrets, allow paths (Recommended)", relayed by the orchestrator, by=merge_gate, Rule 20]: a Host or Adapter setting whose editor context is the classic page's `directorySelector` or `fileSelector` is set as its declaring class validates it (`<Name>IsValid`), as the third case permits a task type's location setting. OcuPilot neither resolves nor contains it (no `PathPort`), and the proposal card names it a location on the server. Named consequence: the item's jobs read or write there as the production runs them, and no directory is refused.
- **AD-36:**

  > **An item setting whose name matches the credential pattern is never answered** (Story 20.22) [AMENDED <date>, owner decision "A: hide secrets, allow paths (Recommended)", by=merge_gate, Rule 20]: Item settings and its read tool answer such a row with an empty value and default and `Secret` true, and every other setting's value and default as row fields through AD-60. Named limit: a secret stored under a name the pattern does not match (an `ExtraHeaders` value carrying a credential) is answered like any other value.
- **AD-62:** `InteropPort` gains `Settings`: `LIST` with one `item` criterion (the item's composite, or the vendor's `Production||Item`), `SETTING`, `SET` and `RESET`. A setting write is an item write (its pairs, the source-control refusal, the concurrency-4 open, `SaveToClass`, `AuditModifyProductionConfig` naming the setting and never its value). A secret-named setting is refused before any vendor call, and a value is validated by its declaring class's `<Name>IsValid`, because the vendor's `SetItemSettingValue` validates nothing (measured).
- **AD-13:** a `production-item-setting` id is the composite `[Production, Item, Target, Name]`, each part kept exactly.
- **AD-51:** `InteropPort` reads a set's value from the declared `Value` of its merged body (Story 20.22).
- **AD-56 (ii):** a declared value may be the empty string where the tool's `SCREENEMPTY` names it.
- **AD-41:** a tool may name, per call, the arguments its ledger row and step redact (`CallSecretNames`).
- **AD-8:** the setting tools declare the item writes' pairs, as measured at Task 0.
- **AD-44:** reset declares `EnsPortal.Dialog.ProductionItemSettings`; set declares no `CLASSICPAGES`.

**Integration ACs, Consumes, Consumed-by:**

- Integration: AC1, AC2 and AC5 run against a real instance (`ocupilot-b-ci`, HTTP confirm and the screen action route). AC2's consumer is 20.2's Update.
- Consumes: 20.3 (the `production-item` parent route id, the Production items list as parent, the item writes' pairs, the always-`SaveToClass` rule, `InteropItemMint`), 20.2 (Update, `InteropProductionAction`), and `Test/ProductionProbe`.
- Consumed-by: 20.4 (per-host tabs from an item, inference), 20.12 (a guided setting change followed by Update, inference).

**Ledger inbox (Rule 17):** DW-2268 is addressed by `InteropAction` (AC7).

**Contended files (Rule 11).** Checked 2026-10-10:

- Epic 18 is paused, with nothing ahead of the feature branch. `.worktrees/epic-23`'s diff touches:
  - `Prohibited.cls` at :283-291, :1404-1413 and :5687-5696
  - `strings.ts` at :391-432
  - `EXPERIENCE.md` at :468
  - `ci-throwaway.sh` at :261
  - `proposal-card.ts`
- This story's edits there are add-only and line-clean. `proposal-card.ts` is untouched.
- In place, in files no other epic is changing: `MappingMint.cls` (Epic 18's, the hook), `Write.cls`, `ScreenAction.cls` :547, `Dispatch.cls` :221, `navigation.ts` `routeIdFor`, and Epic 20's own `InteropProductionAction`, `InteropItemAction` and `InteropPort`. These are reported as footprint extensions.

**Split (`oversized`).** If a split is wanted, the seam is the person's Set and Reset on the screen: the page, the dialog, `SCREENEMPTY`, the handler entries and the browser spec go to a 20.23 that consumes this story. This story would keep the port, the list and its read tool, both agent tools, secrets, paths and DW-2268. The recommendation is not to split: AC3 and AC4 bind both callers.

## Verification

**Shared surfaces:**

- entity types: 64 → 65, from `node tools/screen-mirror.mjs --check`
- the Production items list: its name cell now opens Item settings
- the interop endpoint roster
- the toast route of a parent-scoped composite list (`routeIdFor`)
- the screen action route's values (`SCREENEMPTY`)
- the ledger and step redaction (`CallSecretNames`)
- the mapping tools' mint (`MappingMint`)
- the production and item tools (DW-2268's parent)
- the write-tool rosters
- the governance baseline, and the rosters of keys disabled by default (Governance, ToolDispatch, GovernanceBaseline), which are unchanged
- the Interoperability navigation count
- the Fixed-strings table

*Existing tests that assert a surface this story changes are updated in this story, and every test the story adds or changes passes on a freshly built instance and in either order.*

**Setup (slot B):**

- `rsync -a --checksum --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-20/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`
- then, in `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`, run `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)`
- Before a browser run: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`.
- Never the dev instance `ocupilot-slot-b`.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one class per call, each read from `%UnitTest_Result`:
  - new: `InteropSettingControl`, `InteropSettingRefusals`, `InteropSettingSecrets`, `InteropSettingDescriptor` (and `InteropSettingGate` if made)
  - DW-2268 and the hook: `InteropControl`, `InteropDescriptor`, `InteropGate`, `InteropStopOutcome`, `InteropItemControl`, `InteropItemDescriptor`, `InteropItemGate`, `InteropItemGateSplit`, `InteropItemRefusals`, `InteropItemIdentity`, `MappingWrite`, `MappingWriteGate`, `MappingDescriptor`
  - every sweep class changed, `ScreenAccessRefusals` and `LedgerRedaction`
- `(loop)` `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/<file>`, one file per call: `interop-item-settings.browser-spec.mjs`, `interop-items.browser-spec.mjs`, and `a11y-structural-invariants.browser-spec.mjs` (DW-1337, both themes).
- `(loop)` Expected clean:
  - `cd ui && npm run test:tools && npm run test:components`
  - `uv run scripts/check-objectscript.py <changed .cls>`
  - `bash scripts/lint-docs.sh`
- `(once, before dev_complete, runner-side in foreground batches)`:
  - the full ObjectScript sweep on `ocupilot-b-ci`, one class at a time
  - then `cd ui && npm test && npm run build`, under 3326 kB
  - then `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`
- `(CI)` The full browser suite.

**Planned pinning mutations (Rule 19):**

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | `GatherSettings` skips `GetStaticSettings` | `InteropSettingControl`'s list leg; `InteropSettingDescriptor`'s row-equality leg |
| AC2 | Skip `SaveToClass` after a set | `InteropSettingControl`'s after-recompile leg |
| AC2 | Reset leaves the element | `InteropSettingControl`'s reset leg |
| AC3 | Drop the post-restore secret blanking | `InteropSettingSecrets`' row, read-tool and context legs |
| AC3 | Drop `CallSecretNames`' union in `Dispatch` | `InteropSettingSecrets`' ledger leg |
| AC3 | Drop the port's `SECRET` refusal and the tool's | `InteropSettingSecrets`' screen and mint legs |
| AC4 | `SettingViolations` skips `<Name>IsValid` | `InteropSettingRefusals`' value leg |
| AC5 | `Location` always false | `InteropSettingDescriptor`'s location leg; the card leg in `proposal-card.spec.ts` |
| AC6 | Drop each declared pair in turn | that pair's gate leg |
| AC7 | Restore `PortQuery` in `InteropItemAction` with the marker read as `State` | `InteropItemControl`'s legs |
| AC8 | `routeIdFor` keeps the whole id | `navigation.test.mjs`'s settings and items legs |

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

**Plan only (the invocation halts after planning).**

- The design starts from Story 20.3's first plan (`6def26fa`), checked against 20.3's shipped code. The plan measured five vendor cells on `ocupilot-b-ci` (Design Notes › Measured); the probe and both system defaults were removed afterwards.
- The owner's Q1 ruling is applied, and the AD-21 and AD-36 lines are drafted for the spec gate.
- DW-2268 is planned as `InteropAction`.
- The spec is flagged `oversized`, with a split seam named under Design Notes; splitting is not recommended.
