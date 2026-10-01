---
title: 'Story 18.15: Enable interoperability on a namespace'
type: 'feature'
created: '2026-09-30'
baseline_revision: '6dbcc472c787dce739b4da4f281e3aee499f18d8'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized', 'multiple-goals']
deferred: []
---

<intent-contract>

## Intent

**Problem:** OcuPilot cannot enable interoperability on a namespace (catalog SA-13's `POST /namespace/enable-interop`, DW-1776). The classic New Namespace page offers the step, and the admin API route is asynchronous, takes no body and changes far more than the namespace. Three routed items ride with it:

- DW-1813: a global mapping range or pattern that reaches the `%` globals (`:A`, `*`) carries no `MAPPING.SYSTEMGLOBAL` consequence.
- DW-1824: the New Namespace form's Create a database discards what was typed and never returns.
- DW-1858: the Integrity log has no side-bar position.

**Approach:** Task 0 observes the route's payload, effects, duration and required pairs on the throwaway before anything is built. Then:

- The Namespaces list gains a page-owned **Enable interoperability** row action. It shows a warning dialog that states the consequence, then the same running, done and still-running line as Copy mappings.
- Both callers reach one derived tool, `osmgmt.namespaces.enableinterop` (AD-53, AD-55), through `NamespacePort` and AdminPort's async path. AdminPort's `AwaitTask` is its one poller and reads the finished result once.
- DW-1813 widens the kernel's system-global predicate and its client mirror.
- DW-1824 carries the New Namespace form across the database wizard and back.
- DW-1858 lists the Integrity log right after Databases.

## Boundaries & Constraints

**Always:**

- **Task 0 runs first, on `ocupilot-b-ci` only**, against a probe namespace and probe database it creates and removes. It sets the tool's pairs to exactly what it measures, and it halts on any observation that contradicts this plan (Tasks › Task 0).
- **The enable is an AD-51 action:**
  - `READTYPE` `GET`, `WRITETYPE` `INTEROP`, `SENDSBODY` 0.
  - `FINGERPRINTSUBJECT` `Globals,Routines`, the databases the vendor's enable reads and grants on.
  - `DESTRUCTIVE` 1 with consequence code `NAMESPACE.INTEROP`, because OcuPilot cannot undo it.
  - Governance: `"osmgmt.namespaces.enableinterop": true` (AD-22 default; it removes nothing, and the agent's card takes the strongest confirmation).
- **Queued write (AD-26):** `Namespace.Namespace/INTEROP` joins `MUTATINGTYPES`, `BODYLESSTYPES` and `QUEUEDWRITES`.
  - Past `AsyncTimeout` it has *started*: HTTP 202, recorded applied and marked, and both callers say it is still running.
  - Nothing reads its task again. Only `AwaitTask`, or a test's `Settle`, ever reads a finished result, and only once.
- **Pairs (AD-8, AD-29):**
  - The Namespaces list's `%Admin_Manage:USE` and `%DB_IRISSYS:READ`, plus `%Admin_Operate:USE` (the poll).
  - Plus the pairs Task 0 measures from `{%DB_IRISSYS:WRITE, %Admin_Secure:USE}`, and, only if measured, WRITE on the namespace's own databases through `ArgumentPairs`.
  - Plus the custom resource on `%CSP.UI.Portal.Namespace` (`CLASSICPAGES`, AD-44).
  - A caller without one of them is refused by name before any port call.
- **`%SYS` and `%ALL` are refused by the tool**, on both callers and before any task is queued, with "Interoperability cannot be enabled in %SYS or %ALL." The vendor refuses `%SYS`, and the classic page refuses `%ALL`.
- **DW-1813:** a global mapping is a system-global mapping when its name part begins with `%`, or when its global part (the text before any `(`) begins with `:` or `*`. The vendor reads an empty low end as `%`, and a leading `*` as everything. The kernel and the form apply the one rule.
- **DW-1824:** the database wizard returns to the New Namespace form only when it was opened with the closed marker `returnTo=namespace`. The router carries the created name back, and neither page touches the other's store (AD-19).
- **DW-1858:** the Integrity log takes `sideBarPosition` 5, and Devices through Local databases shift up by one.
- **Probes:** every probe object carries the prefix `OCUPROBE1815` (`ocuprobe1815` for directories). A probe database's resource is created before the database, in its own directory under the manager directory, never the manager directory itself.
- **Contended files (Rule 11):**
  - Edits are add-only wherever a file's structure allows (Design Notes › Footprint). EXPERIENCE.md keeps 993 lines, and `strings.ts` is appended to.
  - `screens.generated.ts` and `ToolFields.cls` are regenerated, never hand-merged.

**Never:**

- No `%Api.Admin.*` name outside `AdminPort` or a port extending it. No product call to `%Library.EnsembleMgr`, `%ZHSLIB` or `HS.*` (test cleanup excepted).
- No parsing of the vendor task's `Console`, and no second read of a finished task's result.
- No new parameter in `Api/Error.cls`, and no new `Router.cls` route.
- No disable-interop, no New Namespace checkbox, and no interoperability column on the list.
- No test enables `USER`, `HSCUSTOM`, `%SYS`, `%ALL`, or any namespace over the `USER` or `HSCUSTOM` databases.
- No stop, restart, recreate, `up` or `down` of `ocupilot-b-ci` or any other container.
- No spine edit: the runner writes the amendments.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
| --- | --- | --- | --- |
| Enable (screen) | `OCUPROBE1815A` over probe database `OCUPROBE1815D`, not enabled. Enable interoperability on its row, then Proceed | The warning shows the consequence before anything is sent. The route sends `enable-interop` once. The list shows the running line, then the done line or the still-running sentence, and re-fetches. The namespace is enabled afterwards | none |
| Enable (agent) | `osmgmt.namespaces.enableinterop` with `Name` `OCUPROBE1815B` | The card is destructive and states the `NAMESPACE.INTEROP` consequence. The confirm applies and marks the write. The read-back reads `unchecked` when started, and "no value sent" otherwise (AD-58) | none |
| Past the bound | The vendor task outlasts `AsyncTimeout` (30 s) | 202 started: recorded applied and marked. Both callers say "Still running on the instance. It finishes in the background." The task row is never read again by the port | none |
| Already enabled | A namespace already enabled | Permitted. The vendor runs its enable again, skipping the steps it keeps for a new namespace (read in `EnableNamespace`). Same dialog and card | none |
| System namespace | `%SYS` or `%ALL`, on either caller | Refused before any task is queued. The agent gets `TOOL.ARGUMENTS`; the route gets 422. Both carry the sentence | tool refusal |
| Deleted since the read | The namespace is deleted between mint and confirm, or before Proceed | The confirm is refused as target changed. The route answers 404 from its fresh read. No task is queued | fingerprint / `PORT.NOTFOUND` |
| Missing pair | The caller lacks a declared pair, the custom resource assigned to `%CSP.UI.Portal.Namespace` included | 403 naming the pair, with zero port calls, on both callers | `AUTH.NOPRIVILEGE` |
| Caller body | A body reaches `NamespacePort` with `INTEROP` | 500 `INTERNAL`, logged. The vendor is not called | port refusal |
| `%` reach (DW-1813) | A global mapping create named `:A`, `:`, `*`, `*X`, `%X` or `%X("a")` | The agent's card is destructive with `MAPPING.SYSTEMGLOBAL`. The form shows the system-global line under Name | effect |
| No `%` reach (DW-1813) | `A:`, `A:Z`, `X*`, `G("%a")`, `G(":")`, a routine `:A`, or a delete | No effect. The card is not destructive for that reason, and no line shows | none |
| Create a database (DW-1824) | New Namespace with Name typed and Routines chosen, then Create a database, then the wizard's Create | No leave prompt. The person is back on New Namespace with Name and Routines as typed and the new database chosen as Globals | none |
| Wizard Cancel (DW-1824) | The same hand-off, then Cancel in the wizard | Back on New Namespace with what was typed. Globals is unchanged | none |
| Wizard elsewhere (DW-1824) | The wizard opened from Local databases, or with any other `returnTo` value | Unchanged: Create opens the new database's editor, and Cancel opens Local databases. New Namespace opened any other way starts empty | none |
| Side bar (DW-1858) | OS management's side bar, for a holder of `%Admin_Operate:USE` and `%DB_IRISSYS:READ` | Processes · Locks · System usage · Databases · Integrity log · Devices · Namespaces · License usage · Dashboard · External language servers · Local databases. Integrity log opens the log | none |
| Integration | The Namespaces page and the agent call the tool; the mapping lists declare `secondaryEntityTypes` `["namespace"]` | An enable's change event re-fetches the Namespaces list and any open mapping list | the tool's gate |

</intent-contract>

## Code Map

**Vendor.** Read-only: `iris_doc_get` and read-only commands on `ocupilot-slot-b` (2026-10-01), plus `irislib/` and `irissys/`. Everything here is from source until Task 0 observes it.

- **`%Api.Admin.Endpoints.Namespace.Namespace`** (`[Hidden]`, not exported):
  - `TYPEINTEROP` is 10. Query `name` is required, and `ValidateSemantics` answers 404 for an absent namespace.
  - `NeedsRequestBody` is false for INTEROP, `ValidateRequest` answers OK, and `ShouldRunAsync` is true.
  - `RunInterop` calls `%EnsembleMgr.EnableNamespace(name, 1)` and returns `{}`. A step failure is only displayed, so it lands in the task's `Console` and not in its status.
  - `RunDelete` calls `DisableNamespace`, then deletes every application whose namespace is the target.
- **`irislib/%Library/EnsembleMgr.cls`:**
  - `EnableNamespace` (:1738-1889) runs these steps in order:
    - `createMappings`, which maps Ens* to ENSLIB;
    - on an instance where HealthShare is installed, `%ZHSLIB.HealthShareMgr.EnableHealthShareNamespace`;
    - `createPortal`, which uses the `healthshare` prefix on such an instance;
    - `addEnsembleSQLPrivileges`;
    - `modifyInteropEditorsAPIApp` (:2825), which adds `:%EnsRole_InteropEditorsAPI` to `/api/interop-editors` once;
    - `setEnsembleDBNSPrivs` (:4236), whose `makeProdPrivs` creates the role `%EnsRole_ProdPrivs_<NS>` (`%sySecurity.inc:226`);
    - `dataUpgradeSteps` and `setConfigFlags`;
    - and, only on an instance without HealthShare and never for `USER`, `createNewDBForEnsTemp` (:5935) and `CreateNewDBForSecondary` (:5705). These create `<Globals>ENSTEMP` and `<Globals>SECONDARY` in subdirectories of the globals database's directory.
  - `validateNamespace` (:2102) refuses `""` and `%SYS`.
  - `IsEnsembleNamespace` (:79) is public and reads `^|ns|oddCOM("Ens.StudioManager")`.
  - `IsHealthShareInstalled` (:57) is `$D(^%SYS("HealthShare"))`. It reads 1 on slot B (`"0^IRISHealth^2026-06-26 18:00:35"`).
  - `DisableNamespace` (:1892) clears only the vendor's markers.
- **The HealthShare branch**, reached on IRIS for Health, the throwaway's image:
  - `irislib/%ZHSLIB/HealthShareMgr.cls:1229` runs `HS.Util.Installer.Foundation.Install` (`irislib/HS/Util/Installer/Foundation.cls:35-150`).
  - That install checks `%Admin_Manage:USE`, then escalates itself (`$$$AddAllRoleTemporary`).
  - For an existing namespace, `CreateDatabaseAndNamespace` only runs `DefineHSRole` (`ConfigItem.cls:856-900`), which creates `%HS_DB_<NS>`.
  - It maps HSSYS, `HS.Local` from HSCUSTOM, the HSLIB globals in `StandardGlobalMapping` (`irislib/HS/HC/Util/Installer.cls:619`: `IRIS.Msg` subscripts, `EnsHL7.*("HealthShare_2.5")`, `SchemaMap.*`), the packages `HS,HSMOD,SchemaMap,%pkg.isc`, and the matching INC routines.
  - It also compiles HSLIB's XML projections into the namespace, runs the FHIR setup, saves a `HS.Util.Installer.ConfigItem` row in HSSYS, and activates the configuration.
  - `ConfigItem.UnInstall` (:1104) is the vendor's own removal.
- **Slot B state, read-only:** `^%SYS("Ensemble","InstalledNamespace")` holds `USER` only, no namespace is a HealthShare instance, and `IsEnsembleNamespace("HSCUSTOM")` reads 1.
- **Classic `irissys/%CSP/UI/Portal/Namespace.cls`:**
  - The "Enable namespace for interoperability productions" checkbox (:89) is checked by default and requires `%Admin_Manage:USE` (:365-375).
  - The enable runs in the background, and never for `%ALL` (:341).
  - "Create New Database..." (:69, :80; `doNew` :181-192) opens the wizard as a popup. `onPopupAction` (:196-212) refreshes both selects and selects the new database.
- **`irissys/NSPMAP.int`:** `oneglob` :32-54. An empty low end becomes `%` (:54), and an empty upper end is open (:89, :137).

**Port** (`src/OcuPilot/Port/`):

- `AdminPort.cls`:
  - Parameters: `MUTATINGTYPES` :402, `BODYLESSTYPES` :418, `QUEUEDWRITES` :630 (doc :613-629), `SELFQUEUEDTYPES` :639, `ASYNCTIMEOUT` 30 (:735).
  - Behavior: a mutating type that is not bodyless and has no body is refused (:987-991). The `ShouldRunAsync` handoff and the queued-write refusal are in `Sequence` :2497-2518.
  - `AwaitTask` :2546-2581 reads once, then `ForgetTask`. At the bound it answers 503 `PORT.TIMEOUT` and `LogFault`s (:2573-2577).
  - `PollTask` :1351.
- `AdminRoutes.cls:133` already maps `Namespace.Namespace` `INTEROP` to `POST /namespace/enable-interop`.
- `NamespacePort.cls` (211 lines):
  - `Invoke` :79-118: the mapping branch, then the `GET` adding `SourceNamespace` (:90-94), then the composed MAPPINGS branch with its caller-body refusal (:99-103) and its started conversion (:109-114).
  - `Snippet` :196-209.
- `DatabasePort.cls:437-467` uses the same started conversion. `DatabaseAction.TargetResourcePair` is the model for argument pairs that read a database's resource.

**Tools** (`src/OcuPilot/Screen/Tool/`):

- `NamespaceCopyMappings.cls` is the model. Every parameter is at :29-86, and the methods are `StateDiff` :117, `ArgumentProblem` :164, `ScreenActionDelta` :175, `Consequence` :192 and `PrivilegePairs` :201.
- Other models: `NamespaceDelete.cls:94` for the pairs, `DatabaseCompact.cls:42` for `ArgumentPairs`, and `Base.cls:123`.
- `Mint.cls:758` (`ConsequenceOf`) calls a tool's `Consequence` when it exists, and the destructive flag is set at :338. A bodyless tool needs no `Classification.cls` entry.

**Kernel:**

- `Kernel/Proposal/Prohibited.cls`: `EFFECTSYSTEMGLOBAL` :506-509, `WeakensByEffect` :1383-1395, `IsSystemGlobalMapping` :2411-2418.
- In the same class, `Namespace` :1949-1984 lets a bodyless non-MAPPINGS write through `ReviewedFewOnly` (inference).
- `Mint.cls:330-338` asks `WeakensByEffect` on a global-mapping create.
- `Kernel/Governance/Baseline.cls:39-42` holds the namespace keys in name order.

**Screens:**

- `Screen/Descriptor/NamespaceList.cls`: `rowActions` :40, `classicPage` :49, read :51-57.
- `Screen/Descriptor/DatabaseIntegrityLog.cls`: `sideBarPosition` 0 :27, doc :14-15.
- Side-bar positions 5-10 are `DeviceList`, `NamespaceList`, `LicenseSummaryTab`, `Dashboard`, `LanguageServerList` and `LocalDatabaseList`. Positions must be whole numbers (`Registry.cls:508-528`, `screen-mirror.mjs:1123`).

**Client** (`ui/src/app/`):

- `areas/os-management/namespace-list.page.ts` (175 lines):
  - The status line is at :62 and the copy dialog at :64-71.
  - Registration is at :105, after the handler is injected (:80). `operationLine` :129-137, `onOpenCopy` :143-148, `onCopy` :159-174.
- `shell/warning-dialog.ts` (`app-warning-dialog`: `verb`, `consequence`, `confirmed`, `cancelled`). `areas/tasks/task-schedule.page.ts:155-196` shows a page using a warning.
- `shell/screen-action-handler.ts`: `NAMESPACE_LIST` :126, `COPY_MAPPINGS` :133, `UNDRAWN_ACTIONS` :253, `sendFor` :1114, `continued()` :1134.
- `core/screen-actions.ts:175` holds the NamespaceList labels.
- `core/proposal-view.ts`: the codes are at :196-199 and `consequenceSentence` at :217-250.
- `core/strings.ts` (4047 lines): the 18.14 block is at :3515-3564. `auditDatabaseStillRunning` :2676 and `actionProceed` :1726 are reused.
- `areas/os-management/namespace-form.page.ts`:
  - The Create a database link is at :176-180 and is drawn beside Globals only (:375). `createDatabaseLink` :380-385, `onCreateDatabase` :430-435.
  - The destroy hook :254-261 resets unless `retaining()`.
- `namespace-form.store.ts`: `retaining` :255, `retainAcrossRouteReplacement` :260, `reset` :267-288, `open` :295-312, and the databases read at :512.
- `database-wizard.page.ts`: `onCreate` :533-542 replaces the route with the editor (:541), `cancel` :555-557 goes to Local databases, and destroy resets (:294-298).
- `core/navigation.ts:696-704` (`withQuery`) carries only `ns`. `core/form-dirty.ts` (`setDirty`, `requestLeave`) and `app.routes.ts:24,73-76` hold the guard.
- `areas/os-management/mapping-form.store.ts:262-264` `systemGlobal()` is the client copy of the DW-1813 rule. The page uses it at :129-131, :147-149 and :293-296.

**EXPERIENCE.md** (993 lines): :164 is the OS management side bar and the Namespaces row, :173 the Dialogs line, and :378 the Namespaces fixed strings, including the `%` where-clause and Story 18.14's tail.

**Rosters to re-derive** (from the code and each class's red, never hand-counted):

- ObjectScript:
  - `AdminPortAsync.cls:91`, `PortFixture.cls:21`, `ToolWrite.cls:1250-1325`.
  - `ReadTool.cls:93-94` (188 tools, 119 writes), `SurfaceCoverage.cls` XData :54/:172, `ToolRoundTrip.cls:50`.
  - `ProposalPrivilege.cls:95-111`, `MappingDescriptor.cls:20,123` (35 entries), `ClassicPageGate.cls:62,131` (31, "thirty-one"), `NamespaceDescriptor.cls:26,35`.
  - DW-1858's pins: `Navigation.cls:459-480`, `Descriptor.cls:2288`, `DeviceWriteGate.cls:200`, `NamespaceWriteGate.cls:144`, `LicenseUsage.cls:110`, `Dashboard.cls:108`, `LanguageServer.cls:66`, `DatabaseDescriptor.cls:33,270-278`, `SurfaceCoverage.cls:136`, `Wire.cls:701`, `WireSecurityRead.cls:556,563,566`.
- Client:
  - `ui/tools/navigation.test.mjs:136-280`, `ui/tools/navigation-wire.test.mjs:129-135`, `ui/src/app/shell/rail-wire.spec.ts:126-132`.
  - `ui/browser/namespaces.browser-spec.mjs:378-385`, `license-usage.browser-spec.mjs:126-141`, `local-databases.browser-spec.mjs:485-496`.
  - `ui/tools/proposal-view.test.mjs:233-243`.

**Test models:**

- `Test/NamespaceCopy.cls`: arming :42, `TaskCount` :300.
- `NamespaceStartedPort` (`AsyncTimeout` 0, `Settle` :42 reads once), `NamespaceStartedAction` (`Copy` :23), `NamespaceStartedConfirm`, `SeamNamespaceCopyMappings`.
- `DatabaseActionProbe.cls`: `SettleOwnTasks` :314, `OwnTaskCount` :331, `SecondReads` :348.
- `DatabaseWriteProbe.cls` (`Add` :74, `DirectoryFor` :58) and `MappingProbe.cls` (`Add` :33, `RemoveAll` :155).
- `NamespaceWriteGate.cls` (`RunAs` :266) with `NamespaceWriteGateProbe.cls` (plan kinds :57-68), and `MappingWriteGate` with `DeviceRecordPort` for counting.
- `MappingWrite.cls:256-276` (`Marked` :472-477, `Names` :275).
- `ui/browser/namespace-mappings.browser-spec.mjs`: `irisSys` :90-103, `recordOperationLine` :225-232, `assertStructure` :251-278.
- `scripts/ci-throwaway.sh`: the NAMESPACE_CONFIG block :403-414 and the PRINCIPALS `# classes:` lines :207-277. The rosters are derived in `ui/tools/ci.test.mjs:2097-2177`.

## Tasks & Acceptance

**Task 0: the implement stage's first task. It runs before any form or tool is built, on `ocupilot-b-ci` only.** Record the results under Design Notes › Measured at implement, and every AD sentence in `## Spec Change Log` for the runner.

1. **Plumbing needed to observe the route through `AdminPort`:**
   - Append `Namespace.Namespace/INTEROP` to `AdminPort`'s `MUTATINGTYPES`, `BODYLESSTYPES` and `QUEUEDWRITES`, and mirror `MUTATINGTYPES` in `Test/PortFixture.cls:21`.
   - Write `src/OcuPilot/Test/InteropProbe.cls` (below), then run `/tmp/epic-18-d4/load-throwaway.sh`.
2. **Read-only checks:** record `%Library.EnsembleMgr.IsHealthShareInstalled()` (expected 1) and the install namespace's `IsEnsembleNamespace`. Enable nothing outside probes.
3. **Reference run, as the test process:**
   - Setup: `InteropProbe.Add("A")` creates resource `%DB_OCUPROBE1815D`, then the database `OCUPROBE1815D` in `<mgr>ocuprobe1815d/`, then namespace `OCUPROBE1815A` over it for both Globals and Routines. Take `Snapshot()` S0.
   - Call `AdminPort.Invoke("Namespace.Namespace","INTEROP",{name})`, and record its HTTP answer and the elapsed time.
   - Wait for the terminal state through `InteropProbe.SettleOwnTasks`, which reads the finished result once and records its `State`, `FailureReason` and `Console`.
   - Take S1 and classify `Diff(S0,S1)` into these effect classes:
     - **E1:** mappings added to the probe namespace;
     - **E2:** applications whose namespace is the probe namespace;
     - **E3:** roles named for it (`%EnsRole_ProdPrivs_<NS>`, `%HS_DB_<NS>`) and `Security.SQLPrivileges` rows for its namespace;
     - **E4:** the vendor's records keyed by it: `^%SYS("Ensemble",…)` and `^%SYS("HealthShare",…)` nodes, and HSSYS `ConfigItem` and activation-log rows;
     - **E5:** `/api/interop-editors` `MatchRoles` gaining `:%EnsRole_InteropEditorsAPI`;
     - **E6:** the configuration file's lines for it.
   - Also record:
     - `IsEnsembleNamespace` before and after;
     - the change in `DatabaseActionProbe.SecondReads()`;
     - `$SYSTEM.Monitor.State()` before and after;
     - the vendor audit events written during the run, with auditing on;
     - the probe database's size.
4. **Cleanup proof:**
   - `InteropProbe.RemoveAll()` deletes the namespace through `AdminPort` `DELETE`.
   - It then removes, by exact probe name, the E3 roles and SQL privilege rows, the E4 rows and nodes, and any task whose namespace is the probe. It restores E5 to its value in S0 if it changed. Last it removes the probe database, its directory and its resource.
   - S2 must equal S0.
5. **Pairs, each run followed by step 4:**
   - Use a principal holding the list's two pairs, `%Admin_Operate:USE`, `%DB_IRISSYS:WRITE` and `%Admin_Secure:USE`. Run the enable through `AdminPort` in a child process (the `NamespaceWriteGate.RunAs` idiom).
   - Compare its effect classes, and its task `Console`, with the reference run.
   - Then drop `%DB_IRISSYS:WRITE`, then `%Admin_Secure:USE`, one per run, and record what stops applying.
   - If the full set fails to reproduce the reference, add `%DB_OCUPROBE1815D:RW` and run again.
   - The tool declares exactly the pairs some effect needed.
6. **HALT** `blocked`, with blocking condition `intent gap: observation contradicts the plan: <what>` and no form or tool built, if any of these hold:
   - INTEROP needs a body.
   - INTEROP does not queue through the `ShouldRunAsync` handoff.
   - INTEROP cannot be reached through `AdminPort`.
   - Any OcuPilot object in S1 differs from S0: its three applications, its roles, `OcuPilotAdmin`, `%DB_OCUPILOT`, the `OCUPILOT` database, the install namespace's or `%ALL`'s mappings.
   - An effect falls outside E1-E6.
   - The enable creates a database on the throwaway.
   - A clause of the consequence sentence is false on the throwaway.
   - The full effect needs a pair outside the candidates in step 5 (a role such as `%All`, or WRITE on an administrative resource).
   - S2 differs from S0.
   - `SecondReads()` grows.
   - The reference run ends `Failed`, or its `Console` reports a step error.
7. **Otherwise:**
   - Set `PrivilegePairs`, and `ArgumentPairs` only if step 5 needed the namespace's own database, to the measured set.
   - Set `InteropProbe`'s settle bound to three times the measured duration, at least 300 s.
   - Write the AD-8 sentence, and the AD-15/AD-53 named case if the vendor wrote no audit event for the enable, into the Spec Change Log.

**Execution: the enable (AC2-AC5):**

- `src/OcuPilot/Port/AdminPort.cls` (Task 0): append to each list's string. In `QUEUEDWRITES`' doc comment, add a line naming INTEROP as Story 18.15's: no body, queued through `ShouldRunAsync`, read once.
- `src/OcuPilot/Port/NamespacePort.cls`, a branch for `Namespace.Namespace` `INTEROP` before the final super call:
  - A caller body is refused, as the composed branch refuses one (:99-103).
  - `name` is sent upper-cased, the spelling the instance stores (Story 18.2).
  - The started conversion (:109-114) becomes one private method that both branches call.
  - `Snippet` mirrors the upper-cased query (AD-59).
  - Add one class-doc paragraph.
- `src/OcuPilot/Screen/Tool/NamespaceEnableInterop.cls` (new, `osmgmt.namespaces.enableinterop`, on the `NamespaceCopyMappings` model):
  - `DESCRIPTORCLASS` `NamespaceList`, `PORTCLASS` `NamespacePort`, `READTYPE` `GET`, `WRITETYPE` `INTEROP`, `SENDSBODY` 0.
  - `CHANGEACTION` `updated`, `DESTRUCTIVE` 1, `SCREENACTIONS` `enable-interop`, no `SCREENVALUES`.
  - `READANSWERS` `Globals,Routines,TempGlobals`, `FINGERPRINTSUBJECT` `Globals,Routines`, `PRECONDITIONFIELD` `Globals`.
  - `CLASSICPAGES` `%CSP.UI.Portal.Namespace`, `CONSEQUENCE` `NAMESPACE.INTEROP`, and `SYSTEMREASON` "Interoperability cannot be enabled in %SYS or %ALL.".
  - `SettableFields` is empty, and `StateDiff` answers no rows.
  - `InputSchema` describes the id as "the namespace to enable, as this instance's namespaces list reports it; %SYS and %ALL are refused".
  - `SystemProblem(pName)` answers `SYSTEMREASON` for `%SYS` or `%ALL`, ignoring case. `ArgumentProblem` and `ScreenActionDelta` both apply it, before any read.
  - `Consequence` answers `CONSEQUENCE`. `PrivilegePairs` is the `NamespaceCopyMappings` shape with Task 0's set. `ArgumentPairs` is used only if Task 0 needed it, and then follows `DatabaseAction.TargetResourcePair`, unresolved refusing.
- `src/OcuPilot/Screen/Descriptor/NamespaceList.cls`: `rowActions` gains `{"id":"enable-interop"}`. Regenerate with `cd ui && node tools/screen-mirror.mjs`, then `node tools/field-lists.mjs`.
- `src/OcuPilot/Kernel/Governance/Baseline.cls`: insert `"osmgmt.namespaces.enableinterop": true,` after the delete line.
- `ui/src/app/areas/os-management/namespace-list.page.ts`:
  - Add `ENABLE_INTEROP = 'enable-interop'` and register it beside `copy-mappings`.
  - One operation runs at a time, and the status line serves both operations.
  - `<app-warning-dialog [verb]="namespaceEnableInteropAction" [consequence]="namespaceEnableInteropConsequence">` opens for the selected row. Proceed calls `sendFor(NAMESPACE_LIST, ENABLE_INTEROP, name, {})`.
  - The running line becomes the done line, or `auditDatabaseStillRunning` when `continued()`. A refusal leaves the handler's refusal on the list.
- `ui/src/app/shell/screen-action-handler.ts`: `ENABLE_INTEROP` joins `UNDRAWN_ACTIONS[NAMESPACE_LIST]`.
- `ui/src/app/core/screen-actions.ts:175` gains `'enable-interop': STRINGS.namespaceEnableInteropAction`.
- `ui/src/app/core/proposal-view.ts`: add `CONSEQUENCE_ENABLEINTEROP = 'NAMESPACE.INTEROP'`, mapped to `namespaceEnableInteropConsequence`.

**Execution: DW-1813 (AC6):**

- `Prohibited.cls`, add-only: in `IsSystemGlobalMapping`, insert before its last `Quit`:

  ```objectscript
      Set tGlobal = $Piece($ListGet(tParts, 2), "(")
      If ($Extract(tGlobal) = ":") || ($Extract(tGlobal) = "*") Quit 1
  ```

  Then insert one doc paragraph each after the doc comments of `IsSystemGlobalMapping`, `EFFECTSYSTEMGLOBAL` and `WeakensByEffect`, saying that a name whose global part begins with `:` or `*` reaches the `%` globals.
- `ui/src/app/areas/os-management/mapping-form.store.ts` `systemGlobal()`: kind `global`, and either the name begins with `%`, or the text before its first `(` begins with `:` or `*`.

**Execution: DW-1824 (AC7):**

- `namespace-form.page.ts`, `onCreateDatabase`:
  - Retain the store and clear the form-dirty flag, so no leave prompt is raised.
  - Navigate to the wizard's URL with `returnTo=namespace` added after `withQuery`'s `ns`.
  - On open in create mode, with the route carrying `kept=1`, the store restores the retained create buffer instead of resetting.
  - After its form read re-lists the databases, the store sets Globals to the route's `database` when the list holds it (ignoring case, in the list's spelling).
  - The page then replaces the URL without `kept` and `database`.
  - An open without `kept=1` resets as today.
- `namespace-form.store.ts`: add `retainForHandOff()`, plus a restore path in `open` keyed by an argument the page passes. The store reads no route itself.
- `database-wizard.page.ts`: read `returnTo`. Only the value `namespace` is honored.
  - Create navigates (`replaceUrl`) to the New Namespace route with `kept=1&database=<created name>`.
  - Cancel navigates to it with `kept=1`.
  - Without the marker, nothing changes.

**Execution: DW-1858 (AC8):**

- `DatabaseIntegrityLog.cls` takes `sideBarPosition` 5. Rewrite its doc sentence to say it is listed right after Databases and the Check integrity flow also opens it.
- `DeviceList`, `NamespaceList`, `LicenseSummaryTab`, `Dashboard`, `LanguageServerList` and `LocalDatabaseList` move 5-10 to 6-11.
- Regenerate the mirror, then update every pin the Code Map lists.

**EXPERIENCE.md (in place, still 993 lines) and `strings.ts` (appended, each key citing :378):**

- `:164`:
  - The second cell becomes "Processes · Locks · System usage · Databases · Integrity log (Story 18.15) · Devices".
  - The Namespaces entry reads "Stories 18.2, 18.14 and 18.15: its editor links a namespace's global, routine and package mappings, and its list enables interoperability".
- `:173`: "enable interoperability (Story 18.15)" joins the warnings that precede a non-delete write.
- `:378`:
  - The `%` where-clause becomes "a global mapping whose name, pattern or range reaches the % globals (its name begins with %, or its global part with : or *)".
  - The tail gains these strings, and ends `[ADDED 2026-09-30 - Story 18.15]`:
    - "Enable interoperability"
    - "Enabling interoperability maps the interoperability code into this namespace, creates its Interoperability portal application and gives the interoperability roles access to its databases. Where the HealthShare libraries are installed, as on InterSystems IRIS for Health, it also maps those libraries into the namespace; elsewhere it can create two databases beside its globals database. OcuPilot cannot undo it."
    - "Enabling interoperability in <namespace> on the instance since <time>"
    - "Enabled interoperability in <namespace>."
    - "Interoperability cannot be enabled in %SYS or %ALL."
  - The tail also states DW-1824's return: Create a database from New Namespace returns to the form with what was typed and the new database chosen as its globals database.
- `strings.ts` adds `namespaceEnableInteropAction`, `namespaceEnableInteropConsequence`, `namespaceEnableInteropRunning` and `namespaceEnableInteropDone`.

**Tests:**

- `src/OcuPilot/Test/InteropProbe.cls` (new, not a test case, on the `DatabaseWriteProbe` and `MappingProbe` model):
  - Methods: `Add(pSuffix)`, `Snapshot()`, `Diff(pBefore, pAfter)`, `IsEnabled(pNamespace)`, `HasPortal(pNamespace)` (an application whose namespace is it), `SettleOwnTasks()`, `RemoveAll()` and `OwnObjects()`.
  - `Snapshot()` is a canonical sorted list covering: namespaces; databases and their directories; applications with their namespace and `MatchRoles`; roles with their resources and granted roles; resources; `Security.SQLPrivileges` rows for a probe namespace; tasks with their namespace; the mappings of each probe namespace, of the install namespace and of `%ALL`; the `^%SYS("Ensemble")` and `^%SYS("HealthShare")` nodes subscripted by a probe; HSSYS `ConfigItem` ids; and probe directories.
- `src/OcuPilot/Test/NamespaceInterop.cls` (new; armed by `OCUPILOT_ALLOW_NAMESPACE_CONFIG`). It takes a snapshot before all tests, runs `RemoveAll` after each test and after all tests, and fails if the after-all snapshot differs.
  - The declarations: the three port lists, the tool's parameters, and the row action.
  - The screen round trip on `A`: the route answers done or continues. Then `IsEnabled` and `HasPortal`, `SecondReads` unchanged, and OcuPilot's objects unchanged.
  - The agent round trip on `B`: `Marked` reads `"1|NAMESPACE.INTEROP"`, and the confirm is applied and marked.
  - `%SYS` and `%ALL` on both callers, through `MappingAcceptPort` (it reads through and records writes) and a new seam tool `Test/SeamNamespaceEnableInterop.cls` (the `SeamNamespaceCopyMappings` pattern): refused with `SYSTEMREASON`, with zero recorded writes and `OwnTaskCount` unchanged.
  - Deleted since the read, on probe `C`: the confirm is refused as target changed, and no task is queued.
  - The started legs, as re-runs on `A` and `B` through `NamespaceStartedPort`, a new `NamespaceStartedAction.Enable` (over `SeamNamespaceEnableInterop`) and `NamespaceStartedConfirm`: the confirm answers continues, the route answers `continues: true`, and each task is settled once.
- `src/OcuPilot/Test/NamespaceInteropGate.cls` with `NamespaceInteropGateProbe.cls` (new, on the `MappingWriteGate` model; armed by `OCUPILOT_ALLOW_PRINCIPALS` and `OCUPILOT_ALLOW_NAMESPACE_CONFIG`):
  - A caller missing each declared extra pair, one leg per pair, is refused 403 naming it, with zero port calls, on the mint and on the route.
  - A holder of exactly the declared set enables probe `G` through the route. Its effect classes equal the reference.
- `src/OcuPilot/Test/MappingSystemGlobal.cls` (new, stateless): `IsSystemGlobalMapping` and `WeakensByEffect` over composite ids, covering every DW-1813 matrix name, with removal answering `""`.
- `MappingWrite.cls`: agent mints in the probe namespace for `:A` and `*` read `"1|MAPPING.SYSTEMGLOBAL"`, and for `A:` read `"0|"`. Each proposal is canceled, so no such mapping is ever created.
- Rosters: `ClassicPageGate` gains the tool with `%CSP.UI.Portal.Namespace` and adds a page-gate leg for the enable on both callers. Also update `MappingDescriptor`'s `CLASSICROSTER` and every roster in the Code Map.
- `scripts/ci-throwaway.sh`, add-only: a new `# classes: NamespaceInterop, NamespaceInteropGate` line in the NAMESPACE_CONFIG block, and a new `# classes: NamespaceInteropGate` line in the PRINCIPALS block.
- Client specs:
  - `namespace-list.page.spec.ts`: registration, dialog consequence, running then done, continued, refusal and cancel.
  - `proposal-view.test.mjs` for the code; `mapping-form.store.spec.ts` for the DW-1813 names.
  - `namespace-form.page.spec.ts` and `namespace-form.store.spec.ts` for the hand-off, kept values, the selected database, and an open without `kept` resetting; `database-wizard.page.spec.ts` for both returns and no marker.
  - `navigation.test.mjs`, `navigation-wire.test.mjs` and `rail-wire.spec.ts` for the position; `strings.test.mjs`.
- `ui/browser/namespace-interop.browser-spec.mjs` (new, on the `namespace-mappings` model):
  - `before` creates `OCUPROBE1815A` through `docker exec ocupilot-b-ci iris session` calling `InteropProbe.Add("A")`. `after` calls `SettleOwnTasks` then `RemoveAll`, and asserts no probe survives.
  - The row menu's Enable interoperability opens the warning with the consequence. Proceed shows the running line, then the done line or the still-running line. Exactly one `enable-interop` POST is sent.
  - The DW-1337 walk runs in both themes with the warning open and with the status line holding text.
- `namespaces.browser-spec.mjs`:
  - The DW-1824 leg types a Name, chooses Create a database, and creates probe database `OCUPROBE1815W` in the wizard. It is back on New Namespace with the Name kept and Globals `OCUPROBE1815W`, then cancels; cleanup is by `RemoveAll`.
  - The side-bar assertion reads Integrity log right after Databases.
- `license-usage` and `local-databases` browser specs: update the pinned side-bar lists.

**Acceptance Criteria:**

- **AC1:** Given SA-13's enable-interop on `ocupilot-b-ci`, when the implement stage starts, then Task 0's observations of the payload, effects, duration and pairs are recorded under Design Notes before any form or tool exists, and the throwaway's snapshot after the cleanup equals the one before. A contradiction halts the story.
- **AC2:** Given a probe namespace that is not enabled, when a holder of the declared pairs chooses Enable interoperability on its row and presses Proceed, then:
  - the warning stated the consequence sentence before anything was sent;
  - the list showed "Enabling interoperability in OCUPROBE1815A on the instance since <time>", then "Enabled interoperability in OCUPROBE1815A." or "Still running on the instance. It finishes in the background.";
  - once the task ends, `IsEnsembleNamespace` answers 1 and an application serves that namespace.
- **AC3:** Given another probe namespace, when the agent proposes `osmgmt.namespaces.enableinterop` and the person confirms, then:
  - the card is destructive and states the same consequence;
  - the write took `AdminPort`'s async path, admitted by `QUEUEDWRITES`;
  - its finished result was read once, and `messages.log` gained no `ERROR #7846`;
  - a write still running at the bound is recorded applied and marked, and both callers say it is still running.
- **AC4:** Given `%SYS`, `%ALL`, or a caller missing a declared pair, when either caller enables, then it is refused before any task is queued: with the sentence, or 403 naming the pair with zero port calls. A holder of exactly the declared pairs enables a probe namespace with the reference effects.
- **AC5:** Given a probe custom resource assigned to `%CSP.UI.Portal.Namespace`, when a principal holding every other declared pair enables through the mint or the route, then it is refused 403 naming `<resource>:USE`. A holder of it is admitted, and the page's assignment reads afterwards as before.
- **AC6 (DW-1813):** Given a global mapping named `:A`, `:`, `*` or `*X` in a probe namespace, when the agent proposes its create, then the card is destructive with `MAPPING.SYSTEMGLOBAL`. When a person types such a name in the global mapping form, then the system-global line shows under Name. `A:`, `A:Z`, `G("%a")` and a routine `:A` carry neither.
- **AC7 (DW-1824):** Given the New Namespace form with a typed Name, when the person chooses Create a database and creates a database in the wizard, then no leave prompt appears, and they return to New Namespace with the Name kept and the new database chosen as Globals. Cancel returns with the Name kept, and the wizard opened from Local databases behaves as before.
- **AC8 (DW-1858):** Given OS management's side bar, when a holder of the Integrity log's pairs views it, then Integrity log is listed right after Databases and opens the Integrity log, and every other listed screen keeps its relative order.
- **AC9:** Given the warning dialog and the status line, when the DW-1337 structural walk runs in both themes, then no violation outside the baseline appears. The production build stays below 3,800 kB, with `maximumWarning` (2,350 kB) re-based if crossed.

## Spec Change Log

- 2026-10-01, spec gate (runner): spine amendments 1-5 under Design Notes were written at the gate (AD-26, AD-44, AD-10 for DW-1813, AD-21, and AD-8's poll pair); Task 0 completes AD-8 with its measured pairs. AD-21's reading (vendor-derived ENSTEMP/SECONDARY directories accepted) is with the orchestrator for confirmation; if it is overruled, the change is a refusal leg on this tool.

## Review Triage Log

## Design Notes

**Governing ADs:**

- AD-2, AD-27, AD-52: `NamespacePort` extends `AdminPort`, and nothing else names the admin API.
- AD-26: the queued write, read once by the one poller, started past the bound. AD-51: the action, its declared subject, no body.
- AD-6, AD-34, AD-40: the proposal, the confirm, and the gates at the write.
- AD-8, AD-29: the pairs. AD-44: `CLASSICPAGES`.
- AD-53, AD-55: two callers of one tool. AD-58: the read-back. AD-59: the `Snippet` branch.
- AD-14: the change event, with mapping lists re-fetching through `secondaryEntityTypes`. AD-15: the marker. AD-22: the baseline line.
- AD-10: DW-1813's widening. AD-21: the database-directory rule, read below.
- AD-5, AD-13, AD-19: the row action, the namespace id, and the router hand-off.
- AD-36, AD-43: the Integrity log, listed.

**Decisions:**

- **Placement.** The enable is a row action on the Namespaces list, as 18.14's Consumed-by and the epic context direct, and not a New Namespace checkbox.
  - The classic checkbox also runs the enable as a separate background step after the create.
  - One Save carries one write (AD-55).
  - The page owns the action because the lazily built handler overwrites registrations and `ListPage` hosts no status line (18.14).
- **Not refused on the install namespace.** AD-10's install-namespace rule covers a delete and a Globals or Routines change, and the enable does neither.
  - Its mappings name no OcuPilot package, routine or global: Ens* to ENSLIB, and the HealthShare list in the Code Map.
  - Its roles and applications are the vendor's.
  - This is read in the source (inference). No test enables the install namespace.
- **AD-21's database-directory rule.** The owner's rule (DW-1820's origin: a database pointed at the manager directory lands among IRISSYS's files) is enforced by refusing an omitted directory and the manager directory.
  - The enable names no directory. Only on an instance without HealthShare does the vendor create `<Globals>ENSTEMP` and `<Globals>SECONDARY`.
  - Those are subdirectories of the namespace's globals database's directory: a fixed derivation, never the manager directory. So neither refusal is reached (read in the source; plain IRIS is not measured).
  - On the throwaway's IRIS for Health no database is created, and Task 0 halts if one is.
- **No interoperability state on the list.** The admin API's read answers no enabled flag, and composing one would be a new AD-27 case. A re-run is the vendor's own path, and the dialog and card state the consequence either way.
- **The refusal sentence lives on the tool** (`SYSTEMREASON`), because `Api/Error.cls` is at its parameter limit. It is published at EXPERIENCE `:378`, and `NamespaceInterop` asserts both callers answer exactly it.
- **Read once.** `AwaitTask` and the tests' `Settle` are the only readers of a finished task, and nothing reads a started task. Known: `AwaitTask` logs the bound before `NamespacePort` converts it to started (`AdminPort.cls:2574-2575`). Task 0 records whether that raises the instance state. This story leaves `AdminPort`'s log line unchanged, and the implement stage lists it under `deferred:` if the state rises.
- **DW-1824 through the router (AD-19).** The wizard never reads or writes the namespace form's store. `returnTo` takes one closed value and is never a URL (AD-47). The created name travels as a query value, and the form keeps its own buffer across the hand-off.
- **DW-1858.** Positions are whole numbers, so every listed OS management screen after Databases shifts by one.

**Proposed spine amendments (Rule 20; the runner writes them at the spec gate).** Task 0 adds its AD-8 and AD-15/AD-53 sentences through the Spec Change Log.

1. **AD-26, after Story 18.4's queued writes:** "**Story 18.15's queued write** [AMENDED 2026-09-30, Story 18.15 spec gate, Rule 20]: `QUEUEDWRITES` also names `Namespace.Namespace` `INTEROP` (enable interoperability), which takes no body and queues through `ShouldRunAsync()` (read on this build); its finished result is read once, by the port's one poller, and past the bound it has started."
2. **AD-44, after Story 16.13's `CLASSICPAGES`:** "**Story 18.15's `CLASSICPAGES`** [AMENDED 2026-09-30, Story 18.15 spec gate, Rule 20]: the enable-interop tool declares the classic New Namespace page `%CSP.UI.Portal.Namespace`, whose interoperability step it performs."
3. **AD-10, replacing the own-mappings bullet's last sentence (:250):** "A global mapping whose name, pattern or range reaches the `%` globals -- its name beginning with `%`, or its global part with `:` (an empty low end, which the vendor reads as `%`) or `*` -- shadows system globals for its namespace; it is **permitted at the strongest confirmation** (effect `MAPPING.SYSTEMGLOBAL`: the agent's proposal is minted destructive with the consequence, a person's Save shows it at the field), for a create as for a change, because the vendor creates a subscript mapping's base mapping too [AMENDED 2026-09-30, Story 18.15 spec gate, DW-1813, Rule 20]."
4. **AD-21, after the owner's database-directory rule:** "Story 18.15's enable-interop names no directory: only on an instance without the HealthShare libraries does the vendor create `<Globals>ENSTEMP` and `<Globals>SECONDARY`, in subdirectories of the namespace's globals database directory, a derivation it fixes and never the manager directory, so neither refusal is reached; on InterSystems IRIS for Health it creates no database (measured at Story 18.15's Task 0) [AMENDED 2026-09-30, Story 18.15 spec gate, Rule 20]."
5. **AD-8, the poll pair now; Task 0 completes it:** "**Story 18.15's enable-interop declares pairs beyond its screen's set** [AMENDED <date>, Story 18.15, Rule 20]: `osmgmt.namespaces.enableinterop` declares `%Admin_Operate:USE` under the endpoint clause, the `AsyncResult` gate the port polls the queued `Namespace.Namespace` `INTEROP` through, and <Task 0's measured pairs, each with its measured reason>. Each is refused by name before any port call."

**Integration ACs:**

- AC2 is pinned by `NamespaceInterop`, `namespace-list.page.spec.ts` and the browser spec: the Namespaces page consumes the tool through the screen-action route.
- AC3 is pinned by `NamespaceInterop`: the proposal and confirm consume the tool and `NamespacePort`.
- The mapping lists consume the namespace change event through `secondaryEntityTypes`, as copy-mappings did.
- AC7 is pinned by the browser leg: New Namespace consumes the wizard's return.

**Consumes:**

- 18.14: `NamespacePort`'s started conversion, the `namespace-list.page.ts` wrapper and its status line, `NamespaceStarted*` and `ClassicPageGate`.
- 18.2: `NamespaceList` and the New Namespace form.
- 18.3: the database wizard. 18.4: `DatabaseIntegrityLog`, and `DatabaseActionProbe`'s settle and `SecondReads`.
- 16.17's read-back, 14.1's `Snippet` and 14.2's baseline.

**Consumed-by:**

- 18.12: the agent's grown tool set.
- 18.13: multi-namespace install, which may enable a target namespace through this tool.
- No other consumer in this epic.

**Ledger inbox:**

- DW-1776 is addressed by Task 0, the enable tasks and AC1-AC5.
- DW-1813 by its tasks and AC6, DW-1824 by its tasks and AC7, and DW-1858 by its tasks and AC8.
- DW-1774 is met: the screen-adding obligation is the DW-1858 pins.

**Footprint (Rule 11), for the spec gate.** Epic 16's branch changes several files this story touches (checked 2026-09-30, its tree clean).

- **Add-only here:**
  - `Baseline.cls` and `Prohibited.cls` take inserted lines only.
  - `ci-throwaway.sh` takes new `# classes:` lines.
  - EXPERIENCE.md is edited in place at 993 lines.
  - `strings.ts`, `proposal-view.ts` and `SurfaceCoverage.cls` are appended to.
  - `Error.cls`, `Router.cls`, `Read.cls`, `Registry.cls`, `Write.cls`, `Classification.cls` and `Operation.cls` are untouched.
- **A one-element append to a one-line list, which the integrate-forward merge resolves by union:**
  - `AdminPort` `MUTATINGTYPES` and `BODYLESSTYPES` (Epic 16 also rewrote both), and `QUEUEDWRITES`;
  - `PortFixture.cls:21`, `ReadTool.cls:93-94`, `ToolRoundTrip.cls:50`;
  - `MappingDescriptor.cls:20`, `ClassicPageGate.cls:62,131`;
  - `screen-action-handler.ts:253`.
- **A non-add-only edit to a file Epic 16 changed:** DW-1858's move of `integrity-log` from the unlisted block (:155) to the listed block (:179-192) of `ui/tools/navigation.test.mjs`. Epic 16's two hunks there are in Security (:217-222 and :359-363). This edit needs the gate's approval.

## Verification

**Setup (slot B):**

- Load code with `/tmp/epic-18-d4/load-throwaway.sh`, never the MCP loader, which reaches the dev instance. MCP calls carry `server: "ocupilot-slot-b"`.
- Every enable, probe and principal stays on `ocupilot-b-ci`. Never restart it.
- If a class's arming variable reads unset in the container, arm it per call with `docker exec -e OCUPILOT_ALLOW_NAMESPACE_CONFIG=1`, adding `-e OCUPILOT_ALLOW_PRINCIPALS=1` for the gate class.
- Run one test class per call, and wait until each run has landed in `%UnitTest_Result`.
- Before any browser run: `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci` exported.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one call at a time. Expect 0 failures each, with totals checked against `%UnitTest_Result`. The classes:
  - `NamespaceInterop`, `NamespaceInteropGate`, `MappingSystemGlobal`, `MappingWrite`, `ClassicPageGate`;
  - `NamespaceCopy`, `MappingRefusals`, `NamespaceDescriptor`, `MappingDescriptor`, `ProposalPrivilege`;
  - `AdminPortAsync`, `ToolWrite`, `ReadTool`, `SurfaceCoverage`, `EndpointCoverage`, `ToolRoundTrip`, `DraftRegistry`, `ToolEmit`, `GovernanceBaseline`, `Governance`, `ToolDispatch`;
  - `Navigation`, `Descriptor`, `DatabaseDescriptor`, `Wire`, `WireSecurityRead`, `DeviceWriteGate`, `NamespaceWriteGate`, `LicenseUsage`, `Dashboard`, `LanguageServer`.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/namespace-interop.browser-spec.mjs browser/namespaces.browser-spec.mjs browser/namespace-mappings.browser-spec.mjs browser/license-usage.browser-spec.mjs browser/local-databases.browser-spec.mjs browser/language-servers.browser-spec.mjs`. Expect a pass.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`, then `uv run scripts/check-objectscript.py <changed .cls>` and `bash scripts/lint-docs.sh`. Expect clean, with `wc -l` on EXPERIENCE.md reading 993.
- `(once, before dev_complete)`:
  - the full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci`, one class at a time;
  - then `cd ui && npm test && npm run build`;
  - then `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`.
  - Expect green with a non-zero count.
- `(CI)` The full browser suite runs in CI's three browser shards (Rule 29), not locally.

**Planned pinning mutations (Rule 19).** Apply each to the throwaway's source copy, or to a rebuilt and redeployed bundle. Observe red, revert byte-identical, and record a `mutation:` line here. Refusal mutations run only through the recording port.

| AC | Mutation | Expected red |
| --- | --- | --- |
| AC2 | `namespace-list.page.ts` drops the `enable-interop` registration | `namespace-list.page.spec`'s AC2 legs; the browser spec |
| AC2/AC3 | `Namespace.Namespace/INTEROP` removed from `QUEUEDWRITES` | `NamespaceInterop`'s round trips (refused, no task); `AdminPortAsync` |
| AC3 | `NamespaceEnableInterop.Consequence` answers `""` | `NamespaceInterop`'s agent leg (`"1|"`); the client map drop reddens `proposal-view.test.mjs` |
| AC3 | `NamespacePort`'s started conversion skips INTEROP | `NamespaceInterop`'s started legs (503 `PORT.TIMEOUT`) |
| AC4 | `SystemProblem` answers `""` | `NamespaceInterop`'s `%SYS` and `%ALL` legs (a recorded write) |
| AC4 | `PrivilegePairs` drops `%Admin_Operate:USE` | `NamespaceInteropGate` (the port is called) |
| AC5 | `CLASSICPAGES` `""` | `ClassicPageGate`'s enable legs; `MappingDescriptor`'s roster |
| AC6 | The inserted `:`/`*` line removed | `MappingSystemGlobal`; `MappingWrite`'s `:A` and `*` legs |
| AC6 | `systemGlobal()` reverted to `startsWith('%')` | `mapping-form.store.spec`'s DW-1813 legs |
| AC7 | The store's restore path resets instead | `namespace-form.page.spec`'s hand-off legs; the browser leg |
| AC7 | The wizard ignores `returnTo` | `database-wizard.page.spec`'s return legs |
| AC8 | `DatabaseIntegrityLog` back at position 0 | `navigation.test.mjs`'s listed test; `Navigation`; the browser side-bar legs |
| AC9 | The warning's consequence drawn in `--ocu-surface` | the interop browser spec's DW-1337 legs, in both themes |

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
