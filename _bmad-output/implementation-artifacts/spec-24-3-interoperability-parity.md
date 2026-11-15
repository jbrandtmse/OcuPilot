---
title: 'Story 24.3: Interoperability parity (first slice: auto-start, shutdown groups and the Epic 20 cleanup)'
type: 'feature'
created: '2026-11-15'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized', 'multiple-goals']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Two production settings still need the classic portal: which production of a namespace starts when the instance starts, at what startup priority (`EnsPortal.AutoStartProduction`), and in which shutdown group a production stops when the instance stops (`EnsPortal.ProductionShutdownGroup`). The agent cannot propose either. Eight routed ledger entries also sit on Epic 20's interoperability screens.

**Approach:** This is the first slice of the story; Design Notes › Proposed split charters the rest. Productions gains three read fields and two write tools through `InteropPort` (AD-62), each reached by the person's row action and the agent's confirmed proposal (AD-53):

- `interop.productions.autostart`: start this production with the instance, at a startup priority, or stop doing so;
- `interop.productions.shutdowngroup`: set the production's shutdown group.

The eight ledger entries are fixed, or closed with the reason Design Notes › Ledger inbox gives.

## Boundaries & Constraints

**Always:**

- **Gate first (AD-29, AD-62 rule 2).** Before any vendor call, in this order:
  1. the Productions endpoint's pairs (`PRODUCTIONPAIRS`);
  2. the namespace's shape, and that it reports interoperability, else 409 `INTEROP.NAMESPACE`;
  3. the write's own pairs: auto-start `%Ens_ProductionConfig:WRITE` (the classic page's `EDITRESOURCE`), shutdown group `%Admin_Manage:USE` (its classic page's `EDITRESOURCE`), each plus WRITE on the namespace's globals database, and any pair Task 0 (b) finds the vendor needs;
  4. a shutdown-group change, or a startup-priority change, requires the vendor's own all-namespaces read to answer OK (`%Library.EnsembleMgr` `GetNamespacesByShutdownGroup` and `GetNamespacesByStartupPriority`), as the classic pages require before they offer the value, else 403 `INTEROP.STARTUP.ALLNAMESPACES`. Turning auto-start on or off with the priority the read answered does not ask it, as the classic page does not;
  5. a namespace whose default database is mounted read-only is refused 409 `INTEROP.STARTUP.READONLY`, read as the classic pages read it (`%SYS.Namespace.GetNSInfo` `ReadOnly`).

  A refusal names the failed pair (`detail.failedPair`).
- **Vendor calls only (AD-62 rule 1).**
  - Writes: `Ens.Director.SetAutoStart(name, priority)`, `SetAutoStart("")` to stop, and `Ens.Director.SetProductionShutdownGroup(name, group)` (`[Internal]`, as the classic page calls it).
  - Reads: `$Get(^Ens.AutoStart)` and `^Ens.AutoStart("StartupPriority")` as the classic page reads them, `GetAutoStartRecommendedPriority(name)` and `GetProductionShutdownGroup(name,,0)` (both `[Internal]`, as the classic pages call them).
  - OcuPilot never sets a vendor global itself.
- **Refused by name what the vendor would answer as a silent success (AD-62 rule 5):** a value equal to the read's (`INTEROP.STARTUP.SAME`), and stopping auto-start for a production that does not start with the instance (`SAME`). A production the namespace does not hold reads absent (404).
- **Shape, before any vendor call (422 naming the rule):** `AutoStart` is `"1"` or `"0"`; a priority or group is an optional minus sign and 1 to 9 digits (`INTEROP.STARTUP.PRIORITY`, `INTEROP.STARTUP.GROUP`); a priority with `AutoStart` `"0"` is refused (`INTEROP.STARTUP.NOPRIORITY`).
- **Write model.**
  - A merge with declared screen values over a port-composed `STARTUP` read `{Name, Namespace, AutoStart, StartupPriority, ShutdownGroup, AutoStartOther}` (AD-4, AD-51, AD-56), where `AutoStartOther` names the namespace's other auto-start production or is empty.
  - The fingerprint covers the whole read, so a change made elsewhere between mint and confirm refuses the confirm (AD-6, AD-34).
  - Read-back compares the fields sent (AD-58). One `production` change event `updated` (AD-14). Prohibited review (AD-10). The agent's marker (AD-15).
  - Each write from either caller also records OcuPilot's own `ConfigChange` (`AuditRuntime`), unless Task 0 (a) finds a vendor audit row.
  - A script form for each write (AD-59, `DraftRegistry`).
- **Governance (AD-22).** `interop.productions.autostart` and `interop.productions.shutdowngroup` join `Baseline.cls` at `true`. Neither is destructive: each is undone by setting the old value back, which the card's before row shows.
- **Untrusted content (AD-11, AD-60).** Production names reach the screen only as interpolated text.
- **Contended files take add-only edits, except those named in Design Notes › Contended files.**

**Never:**

- A harvested body: the MCP suite's `AutoStart` handler passes no priority, and no handler exists for shutdown groups (Design Notes › Extend, don't copy).
- `%Api.InteropEditors`, `SetAutoStartRecommendedPriority`, a direct `%SYS.Ensemble` call, or a `Set` or `Kill` of `^Ens.AutoStart`, `^Ens.Configuration` or `^%SYS`.
- The instance-wide startup-order and shutdown-group tables of the classic pages (Design Notes › Named limits).
- Reading, posting into, or listening to a vendor editor frame (AD-63 rule 3); DW-2388 is measured, never wired.
- Any surface Design Notes › Proposed split moves to Stories 24.15 to 24.19.
- Edits to `Screen/Registry.cls`, `ui/tools/screen-mirror.mjs`, `Test/PortGate.cls`, `Kernel/EntityType.cls`, `app.routes.ts`, `angular.json` or the CI files.

## I/O & Edge-Case Matrix

Rows run in USER on `ocupilot-b-ci` with `ProductionProbe`'s two productions, `PRODUCTION` (P) and `OTHER` (O). The fixture records USER's auto-start and both productions' shutdown groups first and puts them back after.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Read | O starts with the instance at priority 5; P in group 3 | Productions answers O `AutoStart` Yes, `StartupPriority` 5, `ShutdownGroup` 2; P No, empty, 3 | - |
| Turn on | P `AutoStart` 1, priority 4, while O starts with the instance | `^Ens.AutoStart` reads P, priority 4. The card's rows show O's Yes → No. Read-back holds; one change event | - |
| Turn off | P starts with the instance; `AutoStart` 0 | No production of USER starts with the instance | - |
| Group | P group 3, then group 2 | Reads 3, then 2 with the vendor's node removed | - |
| Running | P running; group 4 | `GetProductionShutdownGroup` reads 4, and the vendor's running-namespace value too (Task 0 (b)) | - |
| Same | Values equal to the read; or `AutoStart` 0 on a production that does not start with the instance | Nothing called | 409 `INTEROP.STARTUP.SAME` |
| Shape | Priority `1.5`, `-`, `1234567890`; group `abc`; priority with `AutoStart` 0 | Nothing called | 422 `PRIORITY` / `GROUP` / `NOPRIORITY` |
| Pair missing | No `%Ens_ProductionConfig:WRITE` (auto-start) or `%Admin_Manage:USE` (group) | Before any vendor call | 403 `AUTH.NOPRIVILEGE`, `detail.failedPair` |
| All namespaces | A principal that cannot read another interoperability namespace's settings changes a group or a priority | Before any vendor call. Turning auto-start on at the read's priority is admitted | 403 `INTEROP.STARTUP.ALLNAMESPACES` |
| Read-only | The default database reads `ReadOnly` (port seam) | Before any vendor call | 409 `INTEROP.STARTUP.READONLY` |
| Stale | O's auto-start set elsewhere between mint and confirm | Nothing written | The confirm's fingerprint refusal (AD-34) |
| DW-2378 | Pasted HL7 whose PID-5 holds U+0151, in the host test and the transformation test | The parsed document holds U+0151, not `?` | - |
| DW-2433 | A message body longer than 1,000,000 characters | Contents and `interop.messagecontents` answer `truncated` true | - |
| DW-2554 | Partner Edit changes only Description after PrimaryEmail was changed elsewhere | Only Description is written; PrimaryEmail keeps the other change | - |

</intent-contract>

## Code Map

Paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-24` (branch `OCU-1-epic24`). Line anchors were read at this plan.

**The port: `src/OcuPilot/Port/InteropPort.cls` (8,861 lines).** No auto-start or shutdown-group code exists yet.

- Pairs and types: `PRODUCTIONPAIRS` :208, `PARTNERWRITEPAIR` :235, `WRITEPAIRS` :273, `ITEMWRITEPAIRS` :279; `TYPESTATE` :321, `TYPESTART`-`TYPERECOVER` :323-:331.
- Classifiers: `IsWrite` :863 (the five actions only), `IsAnyWrite` :926, `Pairs` :956 (write pairs appended at :991, :992, :998), `Serves` :1011 (Productions :1026-:1027).
- `Invoke` :1111: dispatch to `ListProductions` :1169, then the production path (`id` :1179, `IsWrite` :1185, `ReadState` :1189, `Refusal` :1191, `StateRow` :1199, `Perform` :1203).
- `Admit` :1216: pairs :1223, namespace shape :1224, `NamespaceFeatures` :1225, database READ or WRITE :1227-:1228.
- `ListProductions` :1241: `Ens.Config.Production:ProductionStatus` :1251, cap :1255, rows built after the restore :1271-:1279. Add the three fields here, read while switched.
- `ReadState` :1414, `StateRow` :1471, `Perform` :1487.
- **The merge template is the partner family:** `InvokePartner` :7198, `ReadPartner` :7174, `PartnerViolations` :6973, `PerformPartner` :7239 (fresh re-read, concurrency-4 open, sets only what differs :7284-:7298, `AuditRuntime` after the restore :7320-:7325).
- `AuditRuntime` :5764, `LogFault` :3415, refusal helpers :3421-:3466.
- Script forms: `SnippetForm` (about :5790; a Productions write answers `objectscript` only through `IsWrite`) and `Snippet` :5802.
- Ledger sites:
  - DW-2378: `BuildTestRequestHere` :7997 calls `ImportFromString` at :8010; `ParseSourceHere` :8455 at :8468. The stream form to reuse is `ParseEditDocumentHere` :4853-:4860. The script texts are at :8749 and :8814. HL7 is told apart with `%Extends("EnsLib.HL7.Message")`, as at :4806.
  - DW-2433: `ReadMessageContents` :4495 cuts at `TESTOUTPUTMAX` :4513 before the line split. It is reached from `InvokeRuntime` :3488 (call :3543).
- **Errors:** `src/OcuPilot/Api/InteropError.cls`. Code and sentence pairs follow the partner block :400-:430. The code lists are `Codes` :567, `PartnerCodes` :635 and their siblings.

**Tools: `src/OcuPilot/Screen/Tool/`.**

- `InteropAction.cls`: `PORTCLASS` :26, `WRITERESOURCE` :41, `WRITEPERMISSION` :43, `PrivilegePairs` :89.
- `InteropProductionAction.cls`: `READTYPE` STATE :24, `READANSWERS` :27, `WRITERESOURCE` `%Ens_ProductionRun` :36, `CLASSICPAGES` :41, `StateDiff` :80.
- The value-action merge templates:
  - `InteropSettingSet.cls`: `SENDSBODY` :21, `SCREENACTIONS` :25, `SCREENVALUES` :28, `READBACKFIELDS` :33, `FieldRows` :46, `StateDiff` :69, `ScreenActionDelta` :77.
  - `InteropPartnerUpdate.cls`: `SCREENVALUES` :32, `SCREENEMPTY` :34, `MergeUpdate` :72, `ScreenActionDelta` :84.
- `Write.cls` `SCREENOPTIONAL` :244 and its reader :765. `Api/ScreenAction.cls` :69-:71 and :550-:553 refuse a declared value left out unless the tool lists it there.

**Descriptor and mirror.**

- `src/OcuPilot/Screen/Descriptor/InteropProductionList.cls`: `rowActions` :39, `context.fields` :40, read fields :54, columns :64, `emptyAgentKey` :67.
- The generated mirror is `ui/src/app/core/screens.generated.ts` (Productions from :18185). It is regenerated by the build's `screen-mirror.mjs`; never hand-edit it.

**Client.**

- Productions has no page of its own. It renders through `ui/src/app/shell/list-page.ts`, picked by archetype at `screen-outlet.ts` :54.
- The page to follow is `ui/src/app/areas/interoperability/interop-item-setting-list.page.ts` (165 lines), with `interop-item-setting-dialog.ts`: a list page that opens its own dialog for a value action and sends it through `ScreenActionHandler.sendFor`. Interop pages are registered in `ui/src/app/shell/screen-outlet.ts` :228-:239.
- `ui/src/app/shell/screen-action-handler.ts`: `SCREEN_ACTION_DESCRIPTORS` :70 (Productions :127), `UNDRAWN_ACTIONS` :450 (partners :494), `WARNING_CONSEQUENCES` :784 (Productions :815-:820), `PRODUCTION_ENTITY` :916.
- `ui/src/app/core/screen-actions.ts`: `ACTION_LABELS` :120, `DESCRIPTOR_ACTION_LABELS` :170. `ui/src/app/core/proposal-view.ts`: consequences :378-:381, mapping :556-:559.
- `ui/src/app/core/strings.ts`: Productions keys :6678-:6761, partner keys :7117-:7152, `tableWriteCapableEmptyState` :405, and the pattern `userListEmptyAgent` :1663.
- Ledger sites:
  - DW-2379: `interop-item-test-dialog.ts` has no `role="status"`. Its status shows only inside `@if (hasAnswer)` :195-:197, with `statusLine` :373 and the alert at :112. The model is `interop-transform-test-dialog.ts` :41 and its spec :128.
  - DW-2433: `interop-message-contents.ts` :40-:50 already shows `interopMessageContentsCut` (`strings.ts` :7541) when `truncated` is true.
  - DW-2452: the eleven sentence keys, all on write-capable descriptors. `table-model.ts` :287-:296 renders them.
    - `interopProductionsEmptyAgent` :6698, `interopItemsEmptyAgent` :6773, `interopItemSettingsEmptyAgent` :6878;
    - `interopQueuesEmptyAgent` :7032, `interopQueueMessagesEmptyAgent` :7034, `interopJobsEmptyAgent` :7036;
    - `interopBusinessPartnersEmptyAgent` :7089, `interopLookupTablesEmptyAgent` :7091, `interopLookupEntriesEmptyAgent` :7093;
    - `interopItemTestEmptyAgent` :7369, `interopTransformsEmptyAgent` :7427.
  - DW-2554: `interop-business-partner-list.page.ts` `onOpenEdit` :120 and `onEdit` :143-:149, and the doc comment :40. The component spec that flips is `interop-business-partner-list.page.spec.ts` :190.

**Kernel and rosters (`src/OcuPilot/`).** Each is a single line or literal:

- `Kernel/Governance/Baseline.cls`: production keys :220-:224.
- `Kernel/Proposal/Prohibited.cls`: `PermittedChangeFields` :1212 has no `production` entry. The production branch :1786-:1790 sends it through `ReviewedFewOnly` :4441, which refuses any changed field not listed.
- `Test/SurfaceCoverage.cls`: screen :235, tools :438-:442. `Test/ClassicPageGate.cls` `OWNPAIRS` :76. `Test/MappingDescriptor.cls` `CLASSICROSTER` :24.
- `Test/ReadTool.cls` :93-:94. `Test/ToolRoundTrip.cls` `REFUSEEMPTY` :102. `Test/ToolWrite.cls` :1326. `Test/GovernanceBaseline.cls` `DISABLED` :15 (unchanged: both keys are `true`).
- `Test/EndpointCoverage.cls` and `Test/SaveHoldCoverage.cls`: no row, because no route is added.

**Tests and fixtures.**

- Production writes are tested by `Test/InteropControl.cls` (445 lines; both callers, `auditMarked` :226) and `Test/InteropGate.cls` (327). `Test/InteropDescriptor.cls` holds the screen declarations, with the empty-agent key at :168.
- `Test/ProductionProbe.cls` (807 lines, armed users only): `PRODUCTION` :27, `OTHER` :30, `CheckOwn` :155, `Create` :163, `Settle` :465, `Gone` :759, `Remove` :779. `Remove` does not touch auto-start or shutdown-group state.
- DW-2361: `Test/CompileWithoutInterop.cls` `TestItServesAnInteroperabilityNamespace` :308-:351 drives nine LIST reads from `OCUPROBE2028N` (`CompileWithoutInteropProbe.cls`). It is armed by `OCUPILOT_ALLOW_DATABASE_CONFIG` (`scripts/ci-throwaway.sh` :805-:806). Paths it never reaches: `GatherItems` :2196, `GatherSettings` :2955, `PerformItem` :2513, `ListQueues` :3817, `ListJobs` :3799 and `AwaitTestHere` :8078.
- DW-2378 tests:
  - `Test/InteropHostTest.cls` :445 and :499;
  - `Test/InteropTransformTest.cls` :179;
  - `Test/InteropTestDescriptor.cls` :222, which asserts that the host script says `ImportFromString` and flips.
- DW-2433: `Test/InteropMessageContents.cls` :256 and :289.
- DW-2554: `Test/InteropPartnerControl.cls` :195 and :262, and `ui/browser/interop-business-partners.browser-spec.mjs` :280.
- DW-2421:
  - The shared `ui/browser/interop-editor-spec.mjs` (431 lines) exports `answered` :88, `editorFrame` :99, `editorShows` :105 and `armMessageCounters` :176, among others.
  - It lacks `shellAt`, `decodedPath`, `boxes` and `assertFillsHost`.
  - Private copies:
    - `interop-viewers.browser-spec.mjs`: :234-:298 (`shellAt`, `answered`, `appFrame`, `appShows`, `decodedPath`, `boxes`, `assertFillsHost`);
    - `interop-editors.browser-spec.mjs`: :269, :320, :323;
    - `agent-editor-save.browser-spec.mjs`: `shellAtEditor` :220, `answered` :244, `editorShows` :255;
    - `interop-editor-source-control.browser-spec.mjs`: `shellAt` :239.
- DW-2388: `interop-editors.browser-spec.mjs` already asserts that no message is sent at sign-in (:417) and at DTL save and compile (:491, :508), through `armMessageCounters`. No leg types an unsaved edit.

**Vendor (read only).**

- `irislib/Ens/Director.cls`: `SetAutoStart` :1913, `GetAutoStartRecommendedPriority` :1939, `GetProductionShutdownGroup` :2382, `SetProductionShutdownGroup` :2415 (for the running production it also calls `%SYS.Ensemble.SetSYSShutdownGroup`, which sets `^%SYS("Ensemble","RunningNamespace",ns,"SystemShutdownGroup")`).
- `irislib/EnsPortal/AutoStartProduction.cls`: `RESOURCE` :15, `EDITRESOURCE` :18, the apply :101-:160, the all-namespaces check :172-:200.
- `irislib/EnsPortal/ProductionShutdownGroup.cls`: `EDITRESOURCE` `%Admin_Manage:USE` :24, the apply and its integer rule :112-:170, the all-namespaces check :200-:230.
- `irislib/%Library/EnsembleMgr.cls`: `GetNamespacesByStartupPriority` :6229 and `GetNamespacesByShutdownGroup` :6403. The default group is `ensDefaultShutdownGroup` 2 (`EnsConstants.inc` :244).
- The harvest body that is not used: `/Users/jbrandt/git/iris-execute-mcp-v2/src/ExecuteMCPv2/REST/Interop.cls` `AutoStart` :1123, which calls `SetAutoStart(name)` with no priority.

## Tasks & Acceptance

**Execution:**

- [ ] **Task 0: measure, on `ocupilot-b-ci` only.** Use USER and `ProductionProbe`, put back everything changed, and record each result under Design Notes › Measured.
  - (a) With auditing on, check whether `SetAutoStart` or `SetProductionShutdownGroup` writes a vendor audit row. None is expected, so OcuPilot records `ConfigChange`.
  - (b) As a principal holding only the classic pairs (`%Ens_Portal:USE`, `%Ens_ProductionConfig:READ` and `WRITE`, `%Admin_Manage:USE`, `%DB_USER:RW`), set auto-start, then set the shutdown group of the running probe production. Record whether the vendor's `^%SYS` write succeeds. If it fails, the shutdown-group write's pairs gain the pair the failure names (stricter than the classic page, which is allowed).
  - (c) As a principal without READ on another interoperability namespace's database, check that both `GetNamespacesByStartupPriority` and `GetNamespacesByShutdownGroup` answer an error status. Check also that each leaves `$NAMESPACE` as it found it and writes nothing.
  - (d) DW-2388, in the browser harness: arm `armMessageCounters`, type an unsaved change into the rule, BPL and DTL editors, and count the messages that reach the shell.
  - A result that would make a pair looser than the classic page's, or make either key destructive, is a `blocked` halt, not a decision.
- [ ] `src/OcuPilot/Port/InteropPort.cls`:
  - Productions `LIST` answers `AutoStart` (`Yes` or `No`), `StartupPriority` (empty unless Yes) and `ShutdownGroup`, read while switched.
  - New types: the `STARTUP` read and the writes `AUTOSTART` and `SHUTDOWNGROUP`, served on Productions, through a new `IsStartupWrite` that `IsAnyWrite`, `Pairs`, `Serves` and `SnippetForm` consult. Each write's pairs are as Boundaries › Gate first states.
  - New methods:
    - `ReadStartup`, the composed read;
    - `StartupViolations`, pure;
    - `StartupRefusal`, pure, giving `SAME` and `NOPRIORITY`;
    - `PerformStartup`: the gate, the all-namespaces and read-only checks through overridable seams `AllNamespacesReadable` and `DefaultReadOnly`, the vendor call through the seams `VendorSetAutoStart` and `VendorSetShutdownGroup`, the restore, `AuditRuntime`, then `ReadStartup` as the answer;
    - `StartupSnippet`, the script form.
  - DW-2378: an `EnsLib.HL7.Message` document is parsed through a `%Stream.TmpCharacter` and `ImportFromLibraryStream`, at :8010, :8468 and both script texts. Every other document class keeps `ImportFromString`. Extract a one-method helper from `ParseEditDocumentHere` rather than a third copy.
  - DW-2433: add an optional trailing `Output pCut` to `Invoke`, passed through `InvokeRuntime` to `ReadMessageContents`. It is set when the 1,000,000-character cap cut the text. Existing callers are unchanged.
  - The class doc: add the startup writes. Replace the partner sentence at :57 ("an update's body carries the other thirteen fields") with "an update's body carries the fields it changes" (DW-2554).
- [ ] `src/OcuPilot/Screen/Read.cls`, interop branch :624: pass `.tPortCut` and set `tTruncated` when it is set, as the log-source branch :490-:496 does (DW-2433).
- [ ] `src/OcuPilot/Api/InteropError.cls`: add the codes `INTEROP.STARTUP.SAME`, `PRIORITY`, `GROUP`, `NOPRIORITY`, `ALLNAMESPACES` and `READONLY`, and the consequences `INTEROP.AUTOSTART` and `INTEROP.SHUTDOWNGROUP`. Each takes Design Notes › Proposed strings' sentence, joins the code lists, and has a pair in `ui/tools/interop.test.mjs`.
- [ ] `src/OcuPilot/Screen/Tool/`:
  - an abstract `InteropStartupAction` extending `InteropProductionAction`: read type `STARTUP`, its answers, `CLASSICPAGES` `EnsPortal.AutoStartProduction` or `EnsPortal.ProductionShutdownGroup` per tool, write pair per tool, and a fingerprint over the whole read;
  - `InteropProductionAutoStart` (`interop.productions.autostart`): `SCREENACTIONS` `autostart`, `SCREENVALUES` `autostart=AutoStart,StartupPriority`, `SCREENOPTIONAL` `autostart=StartupPriority`, `READBACKFIELDS` `AutoStart,StartupPriority`, `CONSEQUENCECODE` `INTEROP.AUTOSTART`. Its `StateDiff` shows `AutoStartOther`'s Yes → No row when it replaces one;
  - `InteropProductionShutdownGroup` (`interop.productions.shutdowngroup`): `shutdowngroup=ShutdownGroup`, `READBACKFIELDS` `ShutdownGroup`, `CONSEQUENCECODE` `INTEROP.SHUTDOWNGROUP`;
  - DW-2554: `InteropPartnerUpdate.cls` lists all thirteen fields in `SCREENOPTIONAL` for `edit`.
- [ ] `src/OcuPilot/Screen/Descriptor/InteropProductionList.cls`:
  - add the three fields to `read.fields` and `context.fields`, and three columns;
  - add the row actions `autostart` and `shutdowngroup` after `recover`;
  - `classicPage` stays `EnsPortal.Productions`. The two replaced pages are named by the tools' `CLASSICPAGES` (AD-44), as Items' tools name their dialogs.
- [ ] `src/OcuPilot/Kernel/Governance/Baseline.cls`: add the two keys after :224, at `true`. In `src/OcuPilot/Kernel/Proposal/Prohibited.cls`, add a `production` entry to `PermittedChangeFields` (`AutoStart`, `StartupPriority`, `ShutdownGroup`, `AutoStartOther`) and correct the branch comment at :1786.
- [ ] Client:
  - new `ui/src/app/areas/interoperability/interop-production-list.page.ts` and `interop-production-startup-dialog.ts`, with specs. They keep the five existing actions exactly as the generic list sent them, and open the dialog for the two new ones. Register the page add-only in `screen-outlet.ts` near :228;
  - add `autostart` and `shutdowngroup` to `UNDRAWN_ACTIONS`, the label maps and the proposal-view consequences;
  - strings in `strings.ts`, each citing the new EXPERIENCE.md row.
- [ ] Ledger fixes, client:
  - DW-2379: give `interop-item-test-dialog.ts` an always-mounted `ocu-visually-hidden` `role="status"` region carrying `statusLine`, as the transform dialog has, and add a spec leg like `interop-transform-test-dialog.spec.ts` :128;
  - DW-2452: the eleven keys become the phrases in Design Notes › Proposed strings. Add a `ui/tools` assertion, in an existing interop test file, that the empty-agent text of every write-capable interop descriptor starts with a lowercase letter and ends without a period;
  - DW-2554: `onEdit` sends only the values that differ from those the dialog opened with. A dialog that changes nothing closes without sending. Flip spec :190, and add a browser leg in `interop-business-partners.browser-spec.mjs`: change a field over HTTP after the list loads, then Edit another field, and the first change survives.
- [ ] DW-2421: move `shellAt`, `decodedPath`, `boxes`, `assertFillsHost` and an `editorShows` that takes an array into `ui/browser/interop-editor-spec.mjs`, parameterized by frame selector and app. Replace the private copies in the four specs; keep `shellAtEditor`'s extra listener as a wrapper over the shared `shellAt`.
- [ ] DW-2388: if Task 0 (d) counts zero, assert it in `interop-editors.browser-spec.mjs`'s AC2 leg. If it counts any, record it and change nothing in the product (AD-63 rule 3).
- [ ] Tests, ObjectScript:
  - extend `ProductionProbe` with `SaveStartup` and `RestoreStartup` (USER's auto-start and priority, and both probe productions' groups, through the vendor calls), and make `Remove` clear the probe productions' auto-start and groups before deleting them;
  - new `Test/InteropStartupControl.cls` (both callers over HTTP, read-back, change event, marker, `ConfigChange`, AC5) and `Test/InteropStartupRefusals.cls` (the matrix's refusals, with the vendor globals snapshotted around each);
  - new `Test/InteropStartupGate.cls` (pairs and all-namespaces principals), armed by `OCUPILOT_ALLOW_PRINCIPALS`, with a `# classes:` line in `scripts/ci-throwaway.sh` beside :600;
  - DW-2361: a new leg in `CompileWithoutInterop` with the probe production running in USER. From `OCUPROBE2028N` it drives Items `LIST` and `ITEM`, Settings `LIST`, `Queues` and `Jobs` rows, and the `AUTOSTART` write and its undo. Each must answer a non-zero row count, or holds. The class also declares `OCUPILOT_ALLOW_PRINCIPALS` if `ProductionProbe` needs it;
  - DW-2378 legs in `InteropHostTest` and `InteropTransformTest` (PID-5 with U+0151 round-trips as code 337), and `InteropTestDescriptor` :222 updated;
  - DW-2433: a leg in `InteropMessageContents` (a body over the cap answers `truncated` true through `GET /screens/interop.messagecontents/read` and the read tool, and one at the cap answers false);
  - DW-2554: a leg in `InteropPartnerControl` (a screen Edit carrying one value keeps the others).
- [ ] Tests, client: new `ui/browser/interop-production-startup.browser-spec.mjs` (both dialogs, columns, re-fetch, the replaced production's row), and `ui/tools/interop.test.mjs` pairs.
- [ ] Rosters: add the rows Design Notes › Contended files names, and every count the shared-surface sweep finds.
- [ ] `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`:
  - one new Fixed strings row after the table's last row (now :607), holding Design Notes › Proposed strings verbatim;
  - for DW-2452, replace the eleven sentences inside :604 (Design Notes › Contended files).

**Acceptance Criteria:**

- **AC1 (auto-start, both callers).**
  - **Given** USER with the probe productions, O starting with the instance.
  - **When** a person uses Start with the instance on P, then turns it off, and the agent's `interop.productions.autostart` proposals for the same two changes are confirmed.
  - **Then:**
    - `Ens.Director`'s reads answer each change (P and its priority, then none);
    - Productions re-fetches and shows it;
    - each write answers `readBack` `holds`;
    - the card for P shows O's Yes → No row and the replacement consequence.
- **AC2 (shutdown group, both callers).**
  - **Given** P, stopped and then running.
  - **When** each caller sets its group to 3 and then back to 2.
  - **Then:**
    - `GetProductionShutdownGroup` answers 3 and then 2;
    - for the running production, the vendor's running-namespace value matches;
    - the card carries the shutdown-group consequence.
- **AC3 (refusals before the vendor).**
  - **Given** each refusal row of the I/O matrix.
  - **When** it is attempted from either caller.
  - **Then** it answers that row's code and sentence, and `^Ens.AutoStart` and `^Ens.Configuration("ShutdownGroup")` read the same before and after.
- **AC4 (audit).**
  - **Given** auditing on.
  - **When** each write succeeds.
  - **Then:**
    - OcuPilot's `ConfigChange` names the tool, the namespace and the production, from either caller (unless Task 0 (a) found a vendor row);
    - an agent write carries the marker with its proposal id (AD-15).
- **AC5 (Integration, Rule 1).**
  - **Given** an auto-start and a group the agent's tools wrote.
  - **When** `GET /screens/interop.productions/read` and the read tool `interop.productions` run.
  - **Then** both answer the same `AutoStart`, `StartupPriority` and `ShutdownGroup` for P.
- **AC6 (declared, governed and rostered).**
  - **Given** the two tools.
  - **When** the instance validates them.
  - **Then:**
    - each declares `write`, its port and its classic page;
    - `Baseline.cls` holds both keys at `true`;
    - `SurfaceCoverage`, `ClassicPageGate`, `MappingDescriptor`, `ReadTool` and `ToolRoundTrip` hold their rows, and removing one row reddens that test alone;
    - each has a script form that `DraftRegistry` accepts.
- **AC7 (USER as found).**
  - **Given** a run of any new or changed test class, or of the new browser spec.
  - **When** it ends.
  - **Then** USER's auto-start, its priority and the probe productions' groups read as before, and `ProductionProbe.Gone()` is true.
- **AC8 (the ledger inbox).** **Given** the eight entries, **when** the story's tests run, **then** each holds as follows:
  - DW-2361: the probe-namespace leg drives every path listed, with non-zero counts;
  - DW-2378, DW-2433 and DW-2554: their matrix rows;
  - DW-2379: a screen reader's status region announces the end of a host test;
  - DW-2421: the four browser specs share the moved helpers and stay green;
  - DW-2452: no interop empty state reads "Or ask the agent: Ask the agent";
  - DW-2388: Task 0 (d)'s count is recorded, and asserted if it is zero.

## Spec Change Log

- 2026-11-15, runner spec gate (unattended rulings, one veto item): (1) the `Proposed split` is applied in `epics.md`: 24.3 keeps auto-start, shutdown groups and the eight ledger entries; Stories 24.15-24.19 are inserted after 24.14, the deployment criterion moved word for word to 24.19. (2) The `Proposed strings`, including the lowercase empty-state phrases for DW-2452, are kept as written. (3) Both new keys ship enabled (neither is destructive; AD-22). (4) The spine is not edited in this run: the AD-62 items 11, 15 and 18 lines, the AD-15 case and the AD-22 keys wait as proposed lines for the owner's attended architecture update; the business-partners clause is added to that update's pending text. (5) The edits that are more than an append in files Epic 21 has changed (`Screen/Read.cls` interop branch, `Prohibited.cls` comment, the eleven reworded sentences in EXPERIENCE.md's row and the matching `strings.ts` values) wait on the orchestrator's ruling before implement.

## Review Triage Log

## Design Notes

**Governing ADs (Rule 6).**

- AD-62 governs the port. It gains a clause at the spec gate (below).
- The gate is AD-29 and AD-8. Database WRITE is AD-9's check. The namespace switch is AD-16.
- The write path:
  - AD-4 (merge) and AD-56 (declared screen values, `SCREENOPTIONAL`);
  - AD-6 and AD-34 (proposal and confirm);
  - AD-51 and AD-52 (port declaration);
  - AD-53 and AD-55 (two callers);
  - AD-58 (read-back), AD-14 (change event), AD-10 (prohibited review);
  - AD-59 (script form).
- AD-15 is audit, with a named case added here. AD-22 is the keys.
- AD-3 is the derived field lists. AD-5 covers the descriptor's new fields and actions.
- AD-36 is the Productions read and DW-2433's truncation. AD-44 is the classic pages. AD-11 and AD-60 are untrusted text.
- AD-63 rule 3 decides DW-2388.

Checked and not engaged:

- AD-23: no harvested body fits (Extend, don't copy).
- AD-66: no workflow is added.
- AD-21: no path or caller SQL.
- AD-65: analytics only.

**Spine clauses for the spec gate (Rule 20; the runner writes them).**

- **AD-62, a new item 18, "Startup settings":** Productions' `STARTUP` read and its `AUTOSTART` and `SHUTDOWNGROUP` writes. It covers:
  - the classic pages' pairs, plus WRITE on the namespace's globals database;
  - the vendor's all-namespaces read for a priority or group change;
  - the read-only refusal;
  - the `[Internal]` `SetProductionShutdownGroup`, `GetProductionShutdownGroup` and `GetAutoStartRecommendedPriority` as named limits, as `GetMessageList` is.
- **AD-62 item 11:** replace "fixed in the Epic 20 burn-down" with "fixed in Story 24.3". The code still called `ImportFromString` at this plan.
- **AD-62 item 15:** "a text cut at the 1,000,000-character cap answers `truncated`" (DW-2433).
- **AD-15:** a named case, if Task 0 (a) finds no vendor row: startup-setting writes record OcuPilot's own `ConfigChange` from either caller.
- **AD-22:** the two keys, both `true`.

**Touches the pending business-partners AD update:** DW-2554. Partner Edit sends only the fields the person changed, and the port keeps every field the screen action leaves out. Today's port already keeps an omitted field (`PerformPartner` :7292). The change is the screen contract (`SCREENOPTIONAL`) and the client. The pending update's partner clause should say "an update's body carries the fields it changes", not "the other thirteen fields". The same sentence in `InteropPort`'s class doc :57 is corrected in this story.

**Extend, don't copy (Rules 2 and 31).**

- **The port.** The writes extend `InteropPort`, following the partner merge (`ReadPartner` / `PerformPartner`) and reusing `Admit`, `AuditRuntime` and the refusal helpers.
- **The harvest seam is not engaged.** The MCP suite's `AutoStart` body calls `SetAutoStart(name)` with no priority, so it cannot do what the classic page does, and a body is never edited (AD-23). No body exists for shutdown groups. This is `BackupPort`'s precedent: its freeze was not harvested because the body passed no limit.
- **The tools.** `InteropStartupAction` extends `InteropProductionAction`. The two tools follow `InteropSettingSet`'s value-action merge.
- **The page and dialog** follow `interop-item-setting-list.page.ts` and its dialog as new files. They are new because their fields differ (a checkbox and two whole numbers, against one free-text value), and the Productions page must keep the five existing actions.
- **The HL7 parse** reuses `ParseEditDocumentHere`'s stream form through one extracted helper.
- **The browser helpers** move into `interop-editor-spec.mjs` (DW-2421).
- **The tests** extend `ProductionProbe` and follow `InteropControl`, `InteropGate` and `InteropPartnerRefusals`.

**Integration, Consumes, Consumed-by (Rules 1 and 2).**

- **Integration:** AC5.
- **Consumes:**
  - Stories 20.2 and 20.3: `InteropPort`, the Productions descriptor, `ProductionProbe`, `InteropProductionAction`;
  - Story 20.22: the value-action write and `SCREENVALUES`;
  - Story 20.26: the partner merge;
  - the kernel's proposal, confirm, governance and audit.
- **Consumed-by:**
  - 24.4: undo snapshots and reverts these two writes;
  - 24.15: default settings and credentials reuse the startup tools' gate shape (inference).

**Ledger inbox (Rule 17; `owned_ledger=8`).** All eight are taken in this slice.

- **DW-2361:** fixed, by a production-backed leg in `CompileWithoutInterop` (Tasks).
- **DW-2378:** fixed, by HL7 as a character stream in both tests and both script forms. The AD text claimed it was already fixed; the spine clause above corrects that.
- **DW-2379:** fixed, by a mounted status region. EXPERIENCE.md :922 already lists both test results, so it is unchanged.
- **DW-2388:** measured, never wired. AD-63 rule 3 forbids OcuPilot reading the frame's messages, and Story 20.7 measured that the editors send none in normal mode. Task 0 (d) extends that measurement to an unsaved edit.
  - If none arrives, the runner closes the entry `by-design` with the measurement, and the leg pins it.
  - If one arrives, the runner records it as a `decision-pending` AD-63 question. The product is unchanged either way.
- **DW-2421:** fixed. The helpers move; `interop-editor-source-control.browser-spec.mjs` is the fourth copy, found at this plan.
- **DW-2433:** fixed, by the port cut flag through `Screen/Read`. The client already shows its cut note when `truncated` is true.
- **DW-2452:** fixed, by the eleven phrases (Proposed strings).
- **DW-2554:** fixed, by sending only the changed fields, as the Epic 20 decision sheet ruled.

**Contended files (not add-only; check each against `origin/OCU-1-epic21` before implementing).** Epic 21 has edited each since the merge base:

- `src/OcuPilot/Screen/Read.cls`: the interop branch :624 changes (DW-2433), and Epic 21 changed 22 lines;
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls`: a new `PermittedChangeFields` line and the production branch comment :1786;
- `EXPERIENCE.md` :604: eleven sentences reworded inside the 49 KB row (DW-2452);
- single-line literals and counts:
  - `Test/ReadTool.cls` :93-:94;
  - `Test/ToolRoundTrip.cls` `REFUSEEMPTY` :102;
  - `Test/ToolWrite.cls` :1326 (the other-port count, if it moves);
  - `Test/ClassicPageGate.cls` `OWNPAIRS` :76 and its count sentence :178;
  - `Test/MappingDescriptor.cls` `CLASSICROSTER` :24.

These edits are add-only, at clean positions:

- `Baseline.cls` after :224;
- `SurfaceCoverage.cls` after :442;
- `InteropError.cls` and its code lists;
- `screen-outlet.ts` and the client maps;
- `strings.ts`, in the interop block;
- the new EXPERIENCE.md row after the last row;
- `ci-throwaway.sh`'s `# classes:` lines beside :600 and, if needed, :805.

**Governance keys.**

- `interop.productions.autostart`: `true`. Not destructive: it is undone by setting it back.
- `interop.productions.shutdowngroup`: `true`. Not destructive.

**Proposed strings (veto item).** Plain language, sentences ending with a period.

- **Columns:** "Starts with the instance" (values "Yes" and "No"), "Startup priority", "Shutdown group".
- **Actions:** "Start with the instance", "Shutdown group".
- **Dialog titles:** "Start <production> with the instance", "Shutdown group for <production>".
- **Fields:** "Start this production when the instance starts", "Startup priority", "Shutdown group".
- **Help:**
  - "When the instance starts, it starts each namespace's chosen production in order of startup priority, highest first. Productions with the same priority start in order of namespace name."
  - "When the instance stops, it stops running productions one shutdown group at a time, and those in the same group together. The default group is 2."
- **Consequences:**
  - `INTEROP.AUTOSTART`: "A namespace starts at most one production with the instance, so this replaces any production set to start before."
  - `INTEROP.SHUTDOWNGROUP`: "A shutdown group other than 2 can make the instance take longer to stop, which matters where a failover must finish in time."
- **Refusals:**
  - `INTEROP.STARTUP.SAME`: "This production is already set that way, so there is nothing to change."
  - `INTEROP.STARTUP.PRIORITY`: "A startup priority is a whole number of at most nine digits, with a minus sign if it is negative."
  - `INTEROP.STARTUP.GROUP`: "A shutdown group is a whole number of at most nine digits, with a minus sign if it is negative."
  - `INTEROP.STARTUP.NOPRIORITY`: "A startup priority applies only to a production that starts with the instance."
  - `INTEROP.STARTUP.ALLNAMESPACES`: "Changing a startup priority or a shutdown group needs read access to the settings of every namespace that runs interoperability on this instance."
  - `INTEROP.STARTUP.READONLY`: "This namespace's database is mounted read-only, so this setting cannot be saved."
- **Empty-state agent phrases (DW-2452), replacing the sentences:**
  - Productions: "start a production"
  - Production items: "add an item to this production"
  - Item settings: "set one of this item's settings"
  - Queues: "abort the messages in a queue"
  - Queue messages: "abort a message in this queue"
  - Jobs: "stop a job"
  - Business partners: "add a business partner"
  - Lookup tables: "create a lookup table"
  - Lookup entries: "add an entry to this lookup table"
  - Item test: "send a test request to an item"
  - Data transformations: "test a data transformation"

**Decided in-stage (plan).**

- **The first slice is auto-start and shutdown groups**, the two sibling classic pages, plus all eight ledger entries. The other eighteen surfaces go to the proposed siblings.
- **Both surfaces live on Productions as row actions**, not as two new screens. They act on one production of the route's namespace, as the classic pages' Apply does.
- **The writes are value-action merges over one `STARTUP` read**, as Item settings' Set value is.
- **The priority and group rule** is the classic page's integer rule (`^-?[0-9]+$`), bounded at nine digits.
- **The all-namespaces gate** follows the classic pages: a priority or group change needs it, and a plain on or off does not.
- **The dialog's priority** opens at the stored priority, else the vendor's recommended one, else 0, as the classic page fills it.

**Named limits.**

- The classic pages' instance-wide tables (every namespace's auto-start production by priority, every running production by group) are not shown. OcuPilot's screens are namespace-scoped (AD-44), so each namespace's Productions screen shows its own rows.
- Three `[Internal]` vendor methods are called as the classic pages call them (spine clause above).

**Proposed split** (for the runner, Rule 5 tier 2; numbered from 24.15, after 24.14). The story's first criterion is: "**Given** credentials, default settings, purge and its settings, auto-start, managed alerts, rule and business-process logs, suspended messages, export, schedules, PEX, the registries, record maps, HL7 authoring, interface maps and references, port authority, the system monitor, the archive manager, workflow, deployment and shutdown groups **When** each runs **Then** it round-trips over its backing class." The list is cut, in its own order, as follows:

- **24.3 (this story), "Interoperability parity":** "**Given** auto-start and shutdown groups **When** each runs **Then** it round-trips over its backing class." It keeps the eight `DW-n` bullets.
- **24.15 "Credentials, default settings and schedules":** "**Given** credentials, default settings and schedules **When** each runs **Then** it round-trips over its backing class."
  - The MCP suite's `CredentialManage`, `CredentialList`, `DefaultSettingsList` and `DefaultSettingsManage` bodies exist (harvest candidates).
  - Credentials carry a secret (AD-35, AD-56).
- **24.16 "Purge, suspended messages, export and the archive manager":** "**Given** purge and its settings, suspended messages, export and the archive manager **When** each runs **Then** it round-trips over its backing class."
- **24.17 "Managed alerts, logs, the system monitor and workflow":** "**Given** managed alerts, rule and business-process logs, the system monitor and workflow **When** each runs **Then** it round-trips over its backing class."
- **24.18 "PEX, record maps and HL7 authoring":** "**Given** PEX, record maps and HL7 authoring **When** each runs **Then** it round-trips over its backing class."
- **24.19 "The registries, interface maps and references, port authority and deployment":**
  - "**Given** the registries, interface maps and references, port authority and deployment **When** each runs **Then** it round-trips over its backing class."
  - Plus, verbatim: "**Given** deployment **When** it runs **Then** it produces its log and rollback files, and the deployment history offers rollback and delete."
  - The hidden EnsPortal pages' backing classes are identified on the instance at its plan.

The twenty surfaces each appear exactly once across the six stories.

**Measured** (plan, 2026-11-15, read only):

- On `ocupilot-b-ci`, USER, `^Ens.Configuration` maps to `/durable/iris/mgr/user/`. The `^Ens.AutoStart` mapping was not read; Task 0 reads it.
- The vendor source was read (Code Map › Vendor). Everything else waits for Task 0.

## Verification

**Shared surfaces:**

- the Productions read's fields and row actions;
- the Productions page, which replaces the generic list for this screen;
- the governance baseline;
- `Prohibited`'s `PermittedChangeFields`;
- `SurfaceCoverage`, `ClassicPageGate`, `MappingDescriptor`, `ReadTool` and `ToolRoundTrip`;
- the `InteropError` code lists and `ui/tools/interop.test.mjs`;
- the client action maps;
- the strings table, EXPERIENCE.md :604 and the new row;
- the `ci-throwaway.sh` arming rosters, held by `ci.test.mjs`;
- `screen-outlet.ts`;
- `Screen/Read`'s interop branch;
- `InteropPort.Invoke`'s signature;
- the four browser specs DW-2421 touches.

The implement stage greps `ui/browser`, `ui/tools`, the `ui/src` specs and `src/OcuPilot/Test` for the old shape of each one, and each file it changes joins the `(loop)` set.

*Every test added or changed passes on a fresh environment, in either order.* Each test records and restores USER's startup settings through `ProductionProbe`, and makes and removes its own probe state.

**Setup (slot B, the throwaway `ocupilot-b-ci` only; never the dev instance `ocupilot-slot-b`).** Every destructive check (a production started, a setting written, principals created) runs there.

- `(loop)` **Load `src`:**
  1. `rsync -a --checksum --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-24/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`
  2. In `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`, run `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)`.
- `(loop)` **Before any browser run:** `cd ui && npm run build && docker exec ocupilot-b-ci sh -c 'cd /durable/iris/csp/ocupilot && rm -rf ./*' && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`

**Commands.** Run each in the foreground with `timeout: 600000`, one test run at a time, and keep one call under about 170 s. Read results from `%UnitTest_Result`.

- `(loop)` The new classes, one per call: `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.InteropStartupControl`, then `--class OcuPilot.Test.InteropStartupRefusals`, then `--class OcuPilot.Test.InteropStartupGate`. Expected: green.
- `(loop)` The changed classes, in batches sized from `ui/tools/ci-timings.json`:
  - `CompileWithoutInterop`, `InteropHostTest`, `InteropTransformTest`, `InteropTestDescriptor`, `InteropMessageContents` and `InteropPartnerControl`;
  - `InteropControl`, `InteropGate` and `InteropDescriptor`;
  - `SurfaceCoverage`, `ClassicPageGate`, `MappingDescriptor`, `ReadTool`, `ToolRoundTrip`, `ToolWrite`, `GovernanceBaseline`, `Prohibited`, `DraftRegistry` and `CompositeMintSweep`;
  - then every class the shared-surface sweep changes.

  Expected: green.
- `(loop)` `cd ui && npm run test:tools`, then `cd ui && npm run test:components`. Expected: green.
- `(loop)` `cd ui && npm run build`. Expected: green, with the new page in a lazy chunk and the initial total under the fixed 2,500 kB warning.
- `(loop)` `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh`. Expected: clean.
- `(loop)` After the redeploy, one file per call, each with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci`, as `cd ui && node --test --test-concurrency=1 browser/<file>`. Expected: green.
  - `interop-production-startup.browser-spec.mjs`
  - `interop-productions.browser-spec.mjs`
  - `interop-stop-confirm.browser-spec.mjs`
  - `interop-business-partners.browser-spec.mjs`
  - `interop-item-test.browser-spec.mjs`
  - `interop-messages.browser-spec.mjs`
  - `interop-viewers.browser-spec.mjs`
  - `interop-editors.browser-spec.mjs`
  - `agent-editor-save.browser-spec.mjs`
  - `interop-editor-source-control.browser-spec.mjs`
- `(once)` The full ObjectScript sweep: `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17` for k = 1 to 17, one per call. Expected: green.
- **Left to CI:** the full browser suite.

**Pinning mutations (Rule 19).** These are planned here. The implement stage applies each, observes red, reverts it byte-identically and recompiles (or rebuilds and redeploys), then records the line.

- AC1: `PerformStartup` passes no priority → `InteropStartupControl`'s priority read-back leg.
- AC1: `StateDiff` drops the `AutoStartOther` row → the replacement card leg.
- AC2: the group write skips the vendor call for group 2 → the back-to-2 leg.
- AC3: `StartupRefusal` admits an equal value → the `SAME` leg, through the globals snapshot.
- AC3: the all-namespaces seam is skipped → `InteropStartupGate`'s `ALLNAMESPACES` leg.
- AC4: `AuditRuntime` is dropped on the person's path → `InteropStartupControl`'s audit leg.
- AC5: the Productions read drops `ShutdownGroup` → the integration leg.
- AC6: one `SurfaceCoverage` row is removed → that test, alone.
- AC7: `RestoreStartup` is skipped → `OnAfterAllTests`' as-found assertion.
- DW-2361: an `OcuPilot.*` call inside `GatherItems`' switched loop → the probe-namespace leg.
- DW-2378: the HL7 branch reverts to `ImportFromString` → the U+0151 legs.
- DW-2379: the status region is removed → the dialog spec leg.
- DW-2433: `pCut` is never set → the over-the-cap leg.
- DW-2452: one phrase is restored to its sentence → a new `ui/tools` assertion that no interop empty-agent text begins with a capital.
- DW-2554: `onEdit` sends every field → the component leg and the browser leg.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Planned the first slice: auto-start and shutdown groups as two write tools on Productions through `InteropPort`, plus all eight routed ledger entries (DW-2361, DW-2378, DW-2379, DW-2388, DW-2421, DW-2433, DW-2452, DW-2554; `owned_ledger=8`). For the runner's spec gate:

- the veto items: the Proposed split (24.15 to 24.19), the Proposed strings, and the two keys at `true`;
- the Spine clauses for AD-62, AD-15 and AD-22, among them the correction of AD-62 item 11's "fixed in the Epic 20 burn-down";
- the contended non-append edits: `Screen/Read.cls`, `Prohibited.cls` and EXPERIENCE.md :604.
