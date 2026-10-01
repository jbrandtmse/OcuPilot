---
title: 'Story 18.15: Enable interoperability on a namespace'
type: 'feature'
created: '2026-09-30'
status: 'done'
baseline_revision: '337bfe9bf3bb26e712affd1fc6071932bfc499f0'
baseline_commit: '575c65eecac99899324fd15d67a3cf5503a82108'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred:
  - summary: >-
      A user whose own role only grants the %All role is refused the enable naming %All:USE, though it holds every resource.
    evidence: |-
      NamespaceInteropGate.TestNoResourceIsNamedAll and TestACallerWithoutAllIsRefusedBeforeAnyPortCall (runs 1345, 1562): CheckUserPermission(u, "%All", "USE") reads 0 for a user whose role's GrantedRoles is %All and 1 for a direct %All holder, and the gates evaluate pairs through it. AD-8's 2026-10-01 sentence (spine :225), this spec's Design Notes :349, its proposed amendment 1 (:367) and Tasks :272-273 say a granted-role holder passes; replace those at origin. Admitting such users needs the role check the Design Notes rejected (Operation.Holds and the gates, contended kernel files): a product decision.
    location: >-
      src/OcuPilot/Screen/Tool/NamespaceEnableInterop.cls PrivilegePairs; ARCHITECTURE-SPINE.md:225
    severity: medium
  - summary: >-
      The two started legs raise the instance's alert state: AwaitTask logs the bound (AdminPort :2641) before NamespacePort answers the enable as started.
    evidence: |-
      The Design Notes' "Read once" bullet asks for this entry if it happened. The handoff measured the monitor state 1 -> 2 across its NamespaceInterop runs on ocupilot-b-ci (18.14's known behavior on the copy). AdminPort was not changed, per the spec.
    location: >-
      src/OcuPilot/Port/AdminPort.cls AwaitTask; src/OcuPilot/Test/NamespaceInterop.cls started legs
    severity: medium
  - summary: >-
      A gate-probe child that runs a screen action later fails an AsyncResult call with <FUNCTION>BeginCapture+4^%SYS.Capture, logging three alerts per NamespaceInteropGate run.
    evidence: |-
      Reported by the handoff on ocupilot-b-ci; the same fault came from ClassicPageGate run 1099 before this story, so it is pre-existing harness behavior (MappingWriteGateProbe.QueuedCopies).
    location: >-
      src/OcuPilot/Test/MappingWriteGateProbe.cls QueuedCopies
    severity: low
  - summary: >-
      Retention.TestAnEntryAgesByItsOwnDefinitionAndTheLedgerByTheLongest fails on a reused throwaway once another suite's conversation entries are a day old.
    evidence: |-
      Full sweep run 1437 on ocupilot-b-ci: ForeignExpired found _SYSTEM conversation entries from 2026-09-30T13:08Z, before this story's dispatch, older than the test's one-day probe definition. CI's fresh throwaways start empty; reused-throwaway noise like DW-1554, not caused by this story.
    location: >-
      src/OcuPilot/Test/Retention.cls:189
    severity: low
---

<intent-contract>

## Intent

**Problem:** OcuPilot cannot enable interoperability on a namespace (catalog SA-13's `POST /namespace/enable-interop`, DW-1776). The classic New Namespace page offers the step. The admin API route takes no body and queues through `ShouldRunAsync`. On InterSystems IRIS for Health, the image this project ships on, the vendor's enable also runs the HealthShare Foundation install, whose effects reach across the instance (measured at Task 0 on `ocupilot-b-ci`, 2026-10-01; Design Notes › Measured at implement):

- the existing user `Admin` is granted `%HS_BFC_Administrator`, a role holding `%Admin_Manage`, `%Admin_Secure`, `%Admin_Task` and `%Admin_OAuth2_Client` at USE;
- 13 resources and six `%HS_BFC_*` roles are created, and `%HS_Administrator`'s resources change;
- the HSSYS task "FHIR Purge Expired Search Results Task" is scheduled, and the `FHIR_Validation_Server` Java language server is started;
- about 235 HealthShare SystemConfig records are written;
- the namespace's new applications match `%DB_HSCUSTOM` (the install database), and `/bulkfhir/api` also matches `%DB_IRISSYS` and `%HS_ImpersonateUser`.

Every narrower principal measured either failed `<PROTECT>`, leaving the namespace half-enabled, or silently skipped the HealthShare half. Only `%All` reproduced the reference. OcuPilot cannot undo the enable. OcuPilot's own objects are unchanged by it.

**Approach (orchestrator merge-gate decision 2026-10-01, option 2, following the owner's developer-tool-first direction):**

- One tool, `osmgmt.namespaces.enableinterop`, reached by a page-owned **Enable interoperability** row action on the Namespaces list and by the agent (AD-53, AD-55), through `NamespacePort` and `AdminPort`'s async path. `AwaitTask` is the one poller and reads the finished result once.
- **`%All` only (AD-8).** A caller who does not hold `%All` is refused by name before anything is queued, on both callers, so OcuPilot never leaves a half-enabled namespace. The poll's `%Admin_Operate:USE` is declared too.
- **The strongest confirmation each caller has:** the typed-name dialog on the screen, and on the agent's card the destructive treatment a delete gets, with no typed name (the owner's UX-DR56 ruling of 2026-09-25 stands); each states the consequence sentence before anything is sent. [AMENDED 2026-10-01, orchestrator merge gate, option A]
- **The consequence sentence names every instance-wide effect measured:** the HealthShare Foundation install; the `Admin` user granted `%HS_BFC_Administrator`; the new roles and resources; the FHIR purge task and the FHIR_Validation_Server Java server; applications gaining access to the install database; and that it cannot be undone.
- **Governance:** the key is disabled by default (`"osmgmt.namespaces.enableinterop": false`), like the other irreversible instance-wide actions; the screen action still works behind its confirmation.

## Boundaries & Constraints

**Always:**

- **The enable is an AD-51 action:** `READTYPE` `GET`, `WRITETYPE` `INTEROP`, `SENDSBODY` 0, `FINGERPRINTSUBJECT` `Globals,Routines`, `DESTRUCTIVE` 1 with consequence code `NAMESPACE.INTEROP`.
- **Queued write (AD-26, written):** `Namespace.Namespace/INTEROP` joins `AdminPort`'s `MUTATINGTYPES`, `BODYLESSTYPES` and `QUEUEDWRITES`. Past `AsyncTimeout` it has started: HTTP 202, recorded applied and marked, and both callers say it is still running. Nothing reads a finished task twice.
- **`%SYS` and `%ALL` are refused by the tool** on both callers, before any task is queued, with "Interoperability cannot be enabled in %SYS or %ALL."
- **`CLASSICPAGES` `%CSP.UI.Portal.Namespace`** (AD-44, written).
- **Tests run on `ocupilot-b-ci` only, over probe namespaces and databases named `OCUPROBE1815*`, and remove every instance-wide object the vendor's enable created** (Task 0's test-only restore, kept in `_bmad-output/implementation-artifacts/spec-18-15-task0-interopprobe.patch` as `Test/InteropProbe.cls`): the probe's snapshot after cleanup equals the one before, `Admin`'s roles included. No test settles a task by reading it twice.
- **Contended files** (Epic 16) are edited add-only; EXPERIENCE.md keeps its line count; `screens.generated.ts` and `ToolFields.cls` are regenerated; no new parameter in `Api/Error.cls`.

**Never:**

- No `%Api.Admin.*` name outside `AdminPort` or a port extending it; no product call to `%Library.EnsembleMgr`, `%ZHSLIB` or `HS.*` (test cleanup excepted).
- No parsing of the vendor task's `Console`, and no second read of a finished task's result.
- No pair set narrower than `%All` for the enable; no disable-interop; no New Namespace checkbox; no interoperability column.
- No test enables `USER`, `HSCUSTOM`, `%SYS`, `%ALL` or any namespace over the `USER` or `HSCUSTOM` databases.
- No stop, restart, recreate, `up` or `down` of `ocupilot-b-ci` or any other container.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
| --- | --- | --- | --- |
| Enable (screen) | `OCUPROBE1815A` over a probe database, not enabled; a `%All` holder chooses Enable interoperability, types the name, then Proceeds | The dialog states the consequence before anything is sent. The route sends `enable-interop` once. The list shows the running line, then the done line or the still-running sentence, and re-fetches. The namespace is enabled afterwards | none |
| Enable (agent) | `osmgmt.namespaces.enableinterop` with `Name` `OCUPROBE1815B`, governance key enabled for the test | The card is destructive, with no typed name, and states the consequence. The confirm applies and marks the write | none |
| Governance default | The key at its baseline value | The agent's tool is disabled by governance; the screen action still works behind its confirmation | governance refusal |
| Not `%All` | A principal holding every other declared pair but not `%All`, on either caller | 403 naming `%All`, with zero port calls and no task queued | `AUTH.NOPRIVILEGE` |
| Past the bound | The task outlasts `AsyncTimeout` | 202 started, recorded applied and marked; both callers say "Still running on the instance. It finishes in the background." | none |
| System namespace | `%SYS` or `%ALL` | Refused before any task is queued, with the sentence | tool refusal |
| Deleted since the read | The namespace is deleted between mint and confirm, or before Proceed | Refused as target changed, or 404 from the fresh read; no task is queued | fingerprint / `PORT.NOTFOUND` |
| Integration | The Namespaces page and the agent call the tool; the mapping lists declare `secondaryEntityTypes` `["namespace"]` | An enable's change event re-fetches the Namespaces list and any open mapping list | the tool's gate |

</intent-contract>

## Code Map

Anchors are on `45d320fe` (after Story 18.17's merge at `c8dedb69`).

**Vendor** (read-only; Design Notes › Measured at implement holds Task 0's observations):

- `%Api.Admin.Endpoints.Namespace.Namespace` (`[Hidden]`): `INTEROP` takes no body, `ShouldRunAsync` is true, and `RunInterop` calls `%EnsembleMgr.EnableNamespace(name, 1)`. A step failure reaches only the task's `Console`.
- `irislib/%Library/EnsembleMgr.cls`: `EnableNamespace` :1738-1889, `IsEnsembleNamespace` :79, `validateNamespace` :2102 (refuses `""` and `%SYS`). On IRIS for Health it runs `%ZHSLIB.HealthShareMgr.EnableHealthShareNamespace`, which runs `HS.Util.Installer.Foundation.Install` (`irislib/HS/Util/Installer/Foundation.cls:35-150`). That install is the source of the instance-wide effects.
- Read on slot B's dev instance at this plan (read-only):
  - `Config.Namespaces.Exists("%ALL")` is 1, and no resource is named `%All`.
  - `$SYSTEM.Security.CheckUserPermission(u, "%All", "USE")` is 1 for `_SYSTEM` and 0 for `Admin`. `Admin` holds `%Manager` and is Task 0's grant target.

**Port** (`src/OcuPilot/Port/`):

- `AdminPort.cls`:
  - Parameters:
    - `MUTATINGTYPES` :408 (doc :125-407) and `BODYLESSTYPES` :424 (doc :410-423) are single-line comma lists of `Endpoint/TYPE`.
    - `QUEUEDWRITES` :650 (doc :633-649; the MAPPINGS paragraph is :640-643).
    - `SELFQUEUEDTYPES` :659 and `ASYNCTIMEOUT` 30 :755.
  - Behavior:
    - A mutating type with no body is refused at :1006-1010.
    - The async handoff is at :1040-1045. `Sequence` :2514-2603 refuses a queued write that is not named (:2573-2576).
    - `AwaitTask` :2612-2648 calls `LogFault` at the bound (:2641) before any caller converts the timeout to "started".
    - `PollTask` :1373, `ForgetTask` :1391.
- `AdminRoutes.cls:133` already maps `Namespace.Namespace` `INTEROP` to `POST /namespace/enable-interop`.
- `NamespacePort.cls` (211 lines): doc :1-30, `COMPOSEDTYPES` :44, `STARTEDHTTP` 202 :63. `Invoke` :79-118:
  - the mapping branch :81-89;
  - the `GET` branch :90-94, which adds `SourceNamespace` `""` to every `Namespace.Namespace` `GET`, an INTEROP fresh read included;
  - the MAPPINGS branch :95-116, with the caller-body refusal :99-103 and the started conversion :108-114 (202, with an empty result and fault; `continues` is set downstream at `Api/ScreenAction.cls:375` and `Kernel/Proposal/Confirm.cls:524`);
  - the super call :117, and `Snippet` :196-209.
- `DatabasePort.cls:458-464` keeps its own copy of the conversion and is not touched.

**Tool and kernel:**

- `Screen/Tool/NamespaceCopyMappings.cls` is the model.
  - Parameters :29-86: `DESTRUCTIVE` :50, `SCREENACTIONS` :54, `READANSWERS` :59, `PRECONDITIONFIELD` :61, `FINGERPRINTSUBJECT` :66, `POLLRESOURCE` and `POLLPERMISSION` :73/:75, `CLASSICPAGES` :83, `CONSEQUENCE` :86.
  - Methods: `InputSchema` :102-114, `StateDiff` :117-122, `ArgumentProblem` :164-170, `ScreenActionDelta` :175-188, `Consequence` :192-195, `PrivilegePairs` :201-209.
- `Screen/Tool/AuditCopy.cls:121-150` is the precedent for a tool-level `%SYS` sentence. `NamespaceProblem` is applied by both `ArgumentProblem` and `ScreenActionDelta`; the screen route calls only the delta (`Api/ScreenAction.cls:291`).
- `Kernel/Shell/Effective.cls:19` declares `ALLROLE` `"%All"`.
- **Pair gates.** Every gate evaluates `$ListBuild(resource, permission)` pairs, refuses 403 `AUTH.NOPRIVILEGE` with `detail.failedPair` (`Kernel/Denial.cls:47-67`), and none reads `$ROLES`:
  - the agent's dispatch: `Kernel/Agent/Dispatch.cls:257-268`, before `InvokeTool` :295 and so before the mint's port read;
  - the confirm: `Kernel/Proposal/Confirm.cls:299` (`Operation.Gate`), before the write at :459; governance is at :313-322;
  - the screen route: `Api/ScreenAction.cls:249`, before the read at :274. It never asks governance.
  - `Operation.Holds` (`Kernel/Proposal/Operation.cls:490-506`) uses `$SYSTEM.Security.CheckUserPermission`. `Gate.ParsePairSpec` (`Screen/Gate.cls:316-337`) needs both halves of a pair.
- `Kernel/Proposal/Mint.cls`:
  - the fresh read :167, then `ArgumentProblem` :216-228, then `consequence` and `destructive` :337-338;
  - `DestructiveTool` :511-523, and `ConsequenceOf` :758-767, which calls the tool's `Consequence` method (a parameter alone does nothing).
- `Kernel/Proposal/Prohibited.cls` `Namespace` :1956-1990 refuses no INTEROP write: it reads only a delete or a Globals or Routines change.
- `Kernel/Governance/Baseline.cls:39-42` holds the namespace keys; `delete` is `false` at :41.

**Screens and client:**

- `Screen/Descriptor/NamespaceList.cls:40` `rowActions` (`delete`, `copy-mappings`). The three mapping lists declare `secondaryEntityTypes ["namespace"]` (`GlobalMappingList.cls:35`, `RoutineMappingList.cls:35`, `PackageMappingList.cls:35`).
- `ui/src/app/areas/os-management/namespace-list.page.ts` (175 lines):
  - the status line :62, the copy dialog :64-70, `handler` :80 and the signals :89-98;
  - the registration :105, `operationLine` :129-137, `onOpenCopy` :143-148 with its no-stacking guard :144;
  - `onCopy` :159-174, where `continued()` is read at :167-168.
  - Its spec is `namespace-list.page.spec.ts`.
- `ui/src/app/shell/typed-name-dialog.ts` (`app-typed-name-dialog`): inputs `verb`, `target`, `consequence` and `advisory`; outputs `confirmed` and `cancelled`; an exact, case-sensitive match.
- `ui/src/app/shell/screen-action-handler.ts`: `NAMESPACE_LIST` :128, `COPY_MAPPINGS` :135, `UNDRAWN_ACTIONS` :246-263 (the NamespaceList entry :255), `sendFor` :1117, `lastRefusal` :1129, `continued` :1137.
- `ui/src/app/core/screen-actions.ts:174-175`.
- `ui/src/app/core/proposal-view.ts`: the codes :141-211 and `consequenceSentence` :217-250.
- `ui/src/app/core/strings.ts`: the Story 18.14 block :3513-3610, `auditDatabaseStillRunning` :2674, `formTypedNameConfirm` and `formTypedNameMismatch`.
- `ui/src/app/shell/proposal-card.ts`: `destructive` :110, :336-337 (the card's destructive treatment, unchanged by this story).
- EXPERIENCE.md (993 lines): :164 OS management's side bar, :173 Dialogs, :378 the Namespaces fixed strings, :728 the confirmation dialogs.

**Test models and rosters:**

- Probes:
  - `_bmad-output/implementation-artifacts/spec-18-15-task0-interopprobe.patch` holds `Test/InteropProbe.cls`: `Add` :94, `Snapshot` :346, `Diff` :375, `EffectClasses` :409, `OwnObjects` :449, `RemoveAll` :474, `RemoveSystemRecords` :514, `RestoreEditorsApp` :624, `SnapSystem` :762 (patch lines).
  - `DatabaseActionProbe.cls`: `SettleOwnTasks` :314, `OwnTaskCount` :331, `SecondReads` :348.
  - `MappingWrite.cls`: `Marked` :472-477.
- Copy-mappings test models:
  - `NamespaceCopy.cls` (arming :40-48, `TaskCount` :300-306) and `SeamNamespaceCopyMappings.cls`;
  - `NamespaceStartedPort.cls` (`AsyncTimeout` 0, `Settle` :42) and `NamespaceStartedAction.cls` (`Copy` :23);
  - `NamespaceStartedConfirm.cls`;
  - `MappingAcceptPort.cls`, whose `Writes` filter is at :26.
- Write-gate test models:
  - `MappingWriteGate.cls` (`RunAs` :216-244) and `MappingWriteGateProbe.cls` (the `dispatch`, `action` and `confirm` steps :87-93, which record through `DeviceRecordPort`);
  - `NamespaceWrite.cls:281-295`, the governance model: the agent's call is refused, and the screen's proceeds.
- Rosters a new tool trips (re-derive each from its class's red, never by hand count):
  - `AdminPortAsync.cls:79-91` (9 pairs) and `PortFixture.cls:21`;
  - `ReadTool.cls:93-94` (191 tools, 122 writes);
  - `SurfaceCoverage.cls` XData (the copy row :172) and `ToolRoundTrip.cls:51`;
  - `ProposalPrivilege.cls:95-111` and `MappingDescriptor.cls:20,115` (34, "thirty-four");
  - `ClassicPageGate.cls` (`OWNPAIRS` :62, the count :131, the holding-user agent leg :171-194, `EnableDelete` :398-410);
  - `NamespaceDescriptor.cls:35`;
  - `GovernanceBaseline.cls:11,67`, `Governance.cls:17-29,110,114` and `ToolDispatch.cls:152`.
- Throwaway rosters:
  - `scripts/ci-throwaway.sh`: the NAMESPACE_CONFIG `# classes:` lines :416-417, and the PRINCIPALS lines :217-279, where `NamespaceWriteGate` is at :254.
  - `ui/tools/ci.test.mjs:2086-2207` derives both.
- Client tests:
  - `screen-action-handler.spec.ts:1576-1583`, `proposal-view.test.mjs:31-52,238-247`;
  - `namespace-list.page.spec.ts` and `strings.test.mjs`.
- `ui/browser/namespace-mappings.browser-spec.mjs`: `irisSys` :90-103, `before` and `after` :129-158, `recordOperationLine` :225-232, `assertStructure` :247-278.

## Tasks & Acceptance

**Task 1: restore the probe and prove the cleanup.** It runs first, on `ocupilot-b-ci` only. No tool, port branch, descriptor or client code is written before it passes.

1. Run `git apply _bmad-output/implementation-artifacts/spec-18-15-task1-interopprobe.patch` (it supersedes the Task 0 patch): it restores the extended `src/OcuPilot/Test/InteropProbe.cls` and steps 2-3's `AdminPort` and `PortFixture:21` appends, cut against `6bcbea1d`. Update `AdminPortAsync`'s pair count with it. Then add the residue patterns of step 3's amendment and re-run the proof.
2. `src/OcuPilot/Port/AdminPort.cls`:
   - Append `,Namespace.Namespace/INTEROP` to `MUTATINGTYPES`, `BODYLESSTYPES` and `QUEUEDWRITES`.
   - Under `QUEUEDWRITES`' doc, add one line naming INTEROP as Story 18.15's: it has no body, is queued through `ShouldRunAsync`, and is read once.
   - Mirror the `MUTATINGTYPES` change in `Test/PortFixture.cls:21`.
3. Extend `InteropProbe.cls` to every instance-wide object Task 0 listed:
   - **`Snapshot()`** also lists:
     - every user with its roles, as `user|<name>|<roles>`;
     - every external language server and whether it runs, as `languageserver|<name>|<0|1>`;
     - every `^%SYS("HealthShare", …)` node whose second subscript begins `SystemConfig`, not only the probe-named ones.

     Resources, roles with their resources and granted roles, applications with their matching roles, and tasks are listed already.
   - **`RecordInstance()`** stores those instance-wide lines under `RECORD`. `Add` calls it beside `RecordEditorsApp`, under the same condition: no probe namespace exists and nothing is recorded.
   - **`RestoreInstance()`**, called by `RemoveAll` after the namespace deletes, works against the record:
     - it deletes each resource, role and task the record lacks;
     - it puts back each role's resources and granted roles, each user's roles and each application's matching roles that differ from the record (`%HS_Administrator` and `Admin` among them);
     - it stops each language server that runs now but was stopped in the record, through `AdminPort` `LanguageServer` `STOP`;
     - it kills each `SystemConfig*` node the record lacks;
     - and it forgets the record once no probe namespace remains.

     Every removal uses an exact name taken from the diff, and nothing the record holds is removed.
   - **`RESIDUE`** is a closed list of node patterns: the counter, edit-stamp and HSSYS index nodes that the measurement in step 5 shows may differ after a restore, each one named. The edit stamps are exactly the five Task 1 measured (Design Notes › Restore proof): the web-application `^%SYS("CSP","LastUpdate")` node and the four `SQLStatsSettings` rows' edit date, job, namespace and user, whose settings are unchanged [AMENDED 2026-10-01, runner, spec gate after the Task 1 halt]. **`BroadResidue(pBefore, pAfter)`** answers the lines of the broad diff outside it.
4. Load the code with `/tmp/epic-18-d4/load-throwaway.sh`. Then read through `NamespacePort` `GET` that `%SYS` answers on the throwaway, and record whether `%ALL` exists there (`ocupilot-b-ci` has none; slot B's dev instance has one).
5. Run the proof through `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`, as the test process, which holds `%All`:
   1. `RemoveAll`.
   2. Take S0 = `Snapshot()` and B0 = `Snapshot(1)`, and read `SecondReads()` and `$SYSTEM.Monitor.State()`.
   3. `Add("A")`.
   4. `AdminPort.Invoke("Namespace.Namespace", "INTEROP", {name})`.
   5. `SettleOwnTasks`, which reads the result once.
   6. Take S1, and find each clause of the consequence sentence (published below, at EXPERIENCE.md :378) in `Diff(S0, S1)`.
   7. `RemoveAll`, then take S2 and B2.
6. **Pass** when all of these hold. Record the result in a new `### Restore proof` subsection after Design Notes › Measured at implement, leaving that block as it is: the duration, each residue pattern with its lines, and each clause found.
   - S2 equals S0 line for line, `Admin`'s roles included.
   - `BroadResidue(B0, B2)` is empty.
   - `SecondReads()` and the monitor state are unchanged.
7. **HALT** `blocked`, with blocking condition `intent gap: the throwaway cannot be restored: <what>` and nothing else built, if any of these hold:
   - S2 differs from S0.
   - A broad residue line is not a counter, one of the five named edit stamps, or an HSSYS index node.
   - `SecondReads()` grows, or the monitor state rises.
   - A clause of the consequence sentence is false on the throwaway.
   - `%SYS` does not answer the `GET`, so the tool's sentence could not be reached.
   - The enable ends other than `Finished`, or with a non-empty `Console`.

**Execution: the enable.**

- **`src/OcuPilot/Port/NamespacePort.cls`.** Add an `INTEROP` branch before the final super call:
  - It refuses a caller body, as :99-103 do.
  - It sends `name` upper-cased.
  - Move the started conversion :108-114 into one private method that both branches call.
  - `Snippet` gains the mirroring branch with the upper-cased query (AD-59).
  - Add one class-doc paragraph.
- **`src/OcuPilot/Screen/Tool/NamespaceEnableInterop.cls`** (new, `osmgmt.namespaces.enableinterop`), extending `Write` on the `NamespaceCopyMappings` model:
  - Parameters:
    - `DESCRIPTORCLASS` `NamespaceList`, `PORTCLASS` `NamespacePort`, `READTYPE` `GET`, `WRITETYPE` `INTEROP`, `SENDSBODY` 0.
    - `CHANGEACTION` `updated`, `DESTRUCTIVE` 1, `SCREENACTIONS` `enable-interop`, and no `SCREENVALUES`.
    - `READANSWERS` `Globals,Routines,TempGlobals,SourceNamespace`, `FINGERPRINTSUBJECT` `Globals,Routines`, `PRECONDITIONFIELD` `Globals`.
    - `CLASSICPAGES` `%CSP.UI.Portal.Namespace`, `CONSEQUENCE` `NAMESPACE.INTEROP`, the poll pair `%Admin_Operate:USE`, and `SYSTEMREASON` "Interoperability cannot be enabled in %SYS or %ALL."
  - `Endpoint` answers `Namespace.Namespace`. `SettableFields` is empty, and `StateDiff` answers no rows.
  - `InputSchema` describes the id as "the namespace to enable, as this instance's namespaces list reports it; %SYS and %ALL are refused".
  - `SystemProblem(pName)` answers `SYSTEMREASON` for `%SYS` or `%ALL`, ignoring case, and `""` otherwise. `ArgumentProblem` and `ScreenActionDelta` both apply it.
  - `Consequence()` answers `CONSEQUENCE`.
  - `PrivilegePairs`, in this order, each pair once: the list's pairs (`Gate.RequiredPairs`), then `$ListBuild(##class(OcuPilot.Kernel.Shell.Effective).#ALLROLE, "USE")`, then `%Admin_Operate:USE`, then `Gate.WithClassicPages`. It declares no `ArgumentPairs`.
- **`src/OcuPilot/Screen/Descriptor/NamespaceList.cls`.** `rowActions` gains `{"id": "enable-interop", "selfProtection": ""}`. Regenerate with `cd ui && node tools/screen-mirror.mjs`, then `node tools/field-lists.mjs`, and never hand-merge the output.
- **`src/OcuPilot/Kernel/Governance/Baseline.cls`.** Insert `  "osmgmt.namespaces.enableinterop": false,` between :41 and :42.
- **`ui/src/app/areas/os-management/namespace-list.page.ts`.**
  - Register `ENABLE_INTEROP` beside copy-mappings, and unregister it on destroy.
  - Its row opens `<app-typed-name-dialog>` with `verb` `namespaceEnableInteropVerb`, `target` the namespace and `consequence` `namespaceEnableInteropConsequence`. `confirmed` calls `sendFor(NAMESPACE_LIST, ENABLE_INTEROP, name, {})`.
  - One operation runs at a time: the :144 guard covers both actions, so neither dialog opens while either action runs. One status line serves both.
  - The status line shows `namespaceEnableInteropRunning`, then `namespaceEnableInteropDone`, or `auditDatabaseStillRunning` when `continued()`. A refusal leaves the handler's refusal on the list.
- **`ui/src/app/shell/screen-action-handler.ts`.** Add an `ENABLE_INTEROP` constant beside :135, and add it to `UNDRAWN_ACTIONS[NAMESPACE_LIST]`.
- **`ui/src/app/core/screen-actions.ts:175`** gains `'enable-interop': STRINGS.namespaceEnableInteropAction`.
- **`ui/src/app/core/proposal-view.ts`.** Add `CONSEQUENCE_NAMESPACEINTEROP = 'NAMESPACE.INTEROP'` after :211, and its `if` before :249, answering `namespaceEnableInteropConsequence`.

**EXPERIENCE.md and `strings.ts`.** Write these before the client edits above that read the keys, and set the tool's `SYSTEMREASON` from the same sentence. EXPERIENCE.md is edited in place and stays 993 lines. `strings.ts` gets a Story 18.15 block inserted after :3610, each key citing its EXPERIENCE line.

- **:164.** The Namespaces entry becomes "Stories 18.2, 18.14 and 18.15: its editor links a namespace's global, routine and package mappings, and its list enables interoperability".
- **:173.** "enable interoperability (Story 18.15, the typed-name confirmation)" follows "copy mappings (Story 18.14)".
- **:728.** "enable interoperability" joins the list.
- **:378.** Its tail gains these strings and ends `[ADDED 2026-10-01 - Story 18.15]`:
  - "Enable interoperability" (`namespaceEnableInteropAction`)
  - "Enable interoperability in" (`namespaceEnableInteropVerb`)
  - the consequence (`namespaceEnableInteropConsequence`): "Enabling interoperability maps the interoperability code into this namespace, creates its portal applications and gives the interoperability roles access to its databases. On InterSystems IRIS for Health it also runs the HealthShare Foundation install, which changes the whole instance: it maps the HealthShare libraries into this namespace; grants the Admin user the %HS_BFC_Administrator role, which holds %Admin_Manage, %Admin_Secure, %Admin_Task and %Admin_OAuth2_Client; creates HealthShare roles and resources and changes %HS_Administrator's resources; schedules the FHIR purge task and starts the FHIR_Validation_Server Java language server; and gives the new applications access to the HSCUSTOM database, and /bulkfhir/api access to IRISSYS and %HS_ImpersonateUser. Elsewhere it creates two databases, ENSTEMP and SECONDARY, beside this namespace's globals database. This cannot be undone."
  - "Enabling interoperability in <namespace> on the instance since <time>" (`namespaceEnableInteropRunning`)
  - "Enabled interoperability in <namespace>." (`namespaceEnableInteropDone`)
  - "Interoperability cannot be enabled in %SYS or %ALL." (`namespaceEnableInteropSystem`, equal to the tool's `SYSTEMREASON`)

**Tests.**

- **`src/OcuPilot/Test/NamespaceInterop.cls`** (new; armed by `OCUPILOT_ALLOW_NAMESPACE_CONFIG`). It takes a snapshot before all tests, runs `InteropProbe.RemoveAll` after each test and after all tests, and fails if the after-all snapshot differs. Each test adds its own probe.
  - **Declarations:** the three port lists, the tool's parameters, `PrivilegePairs` holding `%All:USE` and `%Admin_Operate:USE`, the row action, and the baseline key `false`.
  - **Screen round trip on `A`,** with the key at its baseline: the route answers done or continues. Then `IsEnabled` and `HasPortal` hold, `SecondReads` is unchanged, and `OwnObjects` is unchanged.
  - **Agent round trip on `B`,** with the key enabled for this leg and restored afterwards:
    - `Marked` reads `"1|NAMESPACE.INTEROP"`;
    - the confirm is applied and marked.
  - **Governance:** at the baseline, the agent's call answers `GOVERNANCE.DISABLED`, with no proposal and no task.
  - **`%SYS` and `%ALL` on both callers,** through `MappingAcceptPort` (its `Writes` :26 gains `INTEROP`) and a new seam `Test/SeamNamespaceEnableInterop.cls` on the `SeamNamespaceCopyMappings` pattern: each is refused with `SYSTEMREASON`, with zero recorded writes, and `OwnTaskCount` is unchanged.
  - **Deleted since the read, on `C`:** the confirm is refused as target changed, and a route call after the delete is answered 404. No task is queued.
  - **The started legs, on `A` and `B`,** through `NamespaceStartedPort`, a new `NamespaceStartedAction.Enable` (over the seam) and `NamespaceStartedConfirm`: the confirm answers continues, the route answers `continues: true`, and each task is settled once.
- **`src/OcuPilot/Test/NamespaceInteropGate.cls`** (new; armed by `OCUPILOT_ALLOW_PRINCIPALS` and `OCUPILOT_ALLOW_NAMESPACE_CONFIG`). It runs on the `MappingWriteGate` model, through `MappingWriteGateProbe`'s `dispatch`, `action` and `confirm` steps; a probe class of its own is added only if those steps cannot carry the enable.
  - It asserts `Security.Resources.Exists("%All")` is 0.
  - A principal holding the list's pairs, `%Admin_Operate:USE` and every other resource, but not the `%All` role, is refused 403 `AUTH.NOPRIVILEGE` with `failedPair` `%All:USE` on the dispatch and on the route, the route's port asked nothing and no proposal minted.
  - So is a principal whose own role only grants `%All` (DW-1897).
  - On the confirm, a principal mints while it holds the `%All` role, loses that role, and is then refused the same way, its port asked nothing.
  - A principal holding the `%All` role is admitted on the dispatch and on the route; the route's recording port receives exactly one `INTEROP` call and answers it done, and the namespace is enabled with its HealthShare half.
- **Rosters**, each updated from its class's red:
  - `AdminPortAsync` (10 pairs and its message) and `PortFixture:21`;
  - `ReadTool:93-94`;
  - `SurfaceCoverage`: a row naming `NamespaceInterop`;
  - `ToolRoundTrip:51`;
  - `ProposalPrivilege`: a block for `%All:USE` and `%Admin_Operate:USE`;
  - `MappingDescriptor:20,115`: 35 and "thirty-five";
  - `ClassicPageGate`:
    - `OWNPAIRS` gains `osmgmt.namespaces.enableinterop=%All:USE|%Admin_Operate:USE`, and the count becomes thirty-five;
    - the holding user's agent leg and its custom-resource leg exempt this tool, with the reason in one doc line, and a `%All:USE` refusal leg takes their place;
    - `EnableDelete` enables the key;
  - `NamespaceDescriptor:35`: three row actions;
  - `GovernanceBaseline:11,67`, `Governance:17-29,110,114` and `ToolDispatch:152`.
- **`scripts/ci-throwaway.sh`** (add-only):
  - a new line `# classes: NamespaceInterop, NamespaceInteropGate` after :417;
  - a new line `# classes: NamespaceInteropGate` after :255, away from Epic 16's insertion at the end of the PRINCIPALS block.
- **Client specs:**
  - `namespace-list.page.spec.ts`: the registration; the dialog's consequence and target; Proceed unavailable until the name matches; running, then done; the list read again after the enable; continued; refusal; cancel; and one operation at a time.
  - `screen-action-handler.spec.ts`: enable-interop is undrawn.
  - `proposal-view.test.mjs` for the code.
  - `strings.test.mjs`.
- **`ui/browser/namespace-interop.browser-spec.mjs`** (new, on the `namespace-mappings` model):
  - `before` runs `InteropProbe.Add("A")` through `docker exec ocupilot-b-ci iris session`. `after` runs `SettleOwnTasks` and `RemoveAll`, and asserts `Remaining()` is 0.
  - The row menu's Enable interoperability opens the typed-name dialog with the consequence, and its button stays unavailable until the name is typed.
  - Proceed shows the running line, then the done line or the still-running line. Exactly one `enable-interop` POST is sent, and the list is read again afterwards.
  - The DW-1337 walk runs in both themes, with the dialog open and with the status line holding text.

**Rework iteration 1 (trigger: CI run 36869954798 on `be4b1baf`):**

- [x] [CI] instance shard 1/3, instance shard 2/3, browser shard 3/3: on CI's fresh throwaway the enable creates and starts the language server `FHIR_Validation_Server`, which the record lacks; `RestoreInstance` only stops a server the record holds stopped, so `NamespaceInterop` and `NamespaceInteropGate` (`OnAfterAllTests`) and `namespace-interop.browser-spec.mjs:118` report `added ["languageserver|FHIR_Validation_Server|1"]`. Fix: `RestoreInstance` stops, then deletes, every language server the record lacks (exact name from the diff), and a mutation pins it. Reproduce first on `ocupilot-b-ci` by removing the `FHIR_Validation_Server` definition the earlier probe enables left there (stopped), since a fresh instance has none.
- [x] [CI] Throwaway hygiene: remove, as objects (`%DeleteId`, never an SQL `DELETE`, DW-1859), the two vendor async task rows QA's mutation runs left on `ocupilot-b-ci` for the deleted principal `OcuGate1815All` (one stuck `Running`, one `Failed` naming `OCUPROBE1815G`).
- [x] [Review] Stale spec text the code review named (Tasks :301-302, the `angular.json` statements, the Auto Run Result tally): state the delivered values.

**Acceptance Criteria:**

- **AC1:** Given `ocupilot-b-ci`, when the implement stage starts, then Task 1's proof shows that the throwaway's snapshot after `RemoveAll` equals the one before it, before any tool exists. That snapshot includes `Admin`'s roles, `%HS_Administrator`'s resources, the HealthShare roles, resources, task, language server and `SystemConfig` records. If the proof fails, the story halts.
- **AC2:** Given probe `OCUPROBE1815A`, not enabled, and a `%All` holder with the key at its baseline `false`, when they choose Enable interoperability, type the namespace's name and confirm, then:
  - the dialog stated the consequence before anything was sent, and its button stayed unavailable until the exact name was typed;
  - exactly one `enable-interop` request was sent;
  - the list showed "Enabling interoperability in OCUPROBE1815A on the instance since <time>", then "Enabled interoperability in OCUPROBE1815A." or "Still running on the instance. It finishes in the background.", and then read the list again;
  - once the task ends, `IsEnsembleNamespace` answers 1 and an application serves the namespace.
- **AC3:** Given another probe namespace and the key enabled, when the agent proposes `osmgmt.namespaces.enableinterop` and the person confirms, then:
  - the card is destructive, with no typed name, and states the consequence;
  - the write took `AdminPort`'s async path, admitted by `QUEUEDWRITES`;
  - its finished result was read once, and `messages.log` gained no `ERROR #7846`;
  - a write still running at the bound is recorded applied and marked, and both callers say it is still running;
  - at the baseline, the agent's call is refused `GOVERNANCE.DISABLED`.
- **AC4:** Given `%SYS`, `%ALL`, or a caller who does not hold `%All`, when either caller enables, then nothing is queued. The answer is "Interoperability cannot be enabled in %SYS or %ALL." for the namespaces (for `%ALL` where the instance defines it; where it does not, the fresh read's 404 `PORT.NOTFOUND`, and the sentence is pinned through the recording seam), or 403 `AUTH.NOPRIVILEGE` naming `%All:USE` with zero port calls, on the mint, the confirm and the route.
- **AC5:** Given the typed-name dialog and the status line, when the DW-1337 structural walk runs in both themes, then no violation outside the baseline appears. The production build stays below 3,800 kB.

### Review Findings

Code review 2026-10-01, `review_tier: full-opus`, four layers (blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor), none failed. 51 raw findings: 15 grouped into 8 patch and 2 defer entries, 36 rejected (below).

- [x] [Review][Patch] (medium; fix-risk low, test-only) The completion checks read `IsEnsembleNamespace`, which the vendor sets once `createMappings` runs, early in `EnableNamespace`. The gate's admitted leg passes on an enable that has only started. The browser spec's still-running path waits on that check, then settles irisowner's tasks instead of the browser user's, so `RemoveAll` can delete the probe namespace mid-install. Evidence on `ocupilot-b-ci`: vendor task `8177754…` for `OcuGate1815All` has been `Running` since 13:50:33 (QA run 1568), and `5445061…` is `Failed`, "Namespace 'OCUPROBE1815G' does not exist" (run 1569) [src/OcuPilot/Test/NamespaceInteropGate.cls:223, ui/browser/namespace-interop.browser-spec.mjs:272]
- [x] [Review][Patch] (medium; fix-risk low) No test checks that an allowed enable ran its HealthShare half, which is why the enable requires `%All` (Task 0: a narrower principal's enable skips it) [src/OcuPilot/Test/NamespaceInterop.cls:164]
- [x] [Review][Patch] (medium; fix-risk low, add-only in a contended file) Nothing pins that the enable's pairs carry the classic page's custom resource (AD-44), because `%All:USE` fails first for every principal [src/OcuPilot/Test/ClassicPageGate.cls:199]
- [x] [Review][Patch] (medium; fix-risk low) Any later `RemoveAll` applies a restore record a failed run left behind, deleting every role, resource and task created since [src/OcuPilot/Test/InteropProbe.cls:709]
- [x] [Review][Patch] (low, two-way door) `RemoveAll` drops its settle status and does not report a task still unfinished [src/OcuPilot/Test/InteropProbe.cls:504]
- [x] [Review][Patch] (low) The agent-facing description says a user "holding %All may confirm it", but only a direct `%All` holder may propose or confirm (DW-1897) [src/OcuPilot/Screen/Tool/NamespaceEnableInterop.cls:32]
- [x] [Review][Patch] (low) The gate class header says it creates three users and three roles; it creates four of each and a scratch role [src/OcuPilot/Test/NamespaceInteropGate.cls:22]
- [x] [Review][Patch] (low) This story's `NAMESPACE_CONFIG` comment lines do not say that the classes write `%SYS` objects directly and create their own probe database [scripts/ci-throwaway.sh:420]
- [x] [Review][Defer] `AdminPort.AwaitTask` does not treat `Canceled` as terminal, so an enable canceled from Background tasks during the wait would be answered started and recorded applied [src/OcuPilot/Port/AdminPort.cls:2630] — deferred: pre-existing; DW-1805 occurrence appended (and DW-1897 for the granted-role wording the layers raised)
- [x] [Review][Defer] A second enable can be sent on a namespace whose first is still running in the background, because the screen clears its one-operation guard on a still-running answer and reads no task [ui/src/app/areas/os-management/namespace-list.page.ts:216] — deferred: low and deliberate (typed name twice); DW-1902, wontfix-accepted with `reopen_if`

**Rejected:**

- Spec text (a review does not edit the spec under review; the lead owns it): the granted-role wording in Tasks :301-302; deferred item 1's stale line numbers; the `angular.json` statements at :422 and :457; the triage tally at :582; `followup_review_recommended`; the gap audit at :573; the garbled Restore proof clause; AC4's 404 wording against the mint's 400 "not present"; the Integration ACs' claim that the page spec observes the re-read (the browser spec does). The QA `BOUNDSECONDS` inference is corrected in `## Verification`, under the first patch.
- by-design (spec-bound): the consequence sentence's ENSTEMP/SECONDARY naming, the USER exception and the `%SYS` mapping (prescribed text, EXPERIENCE.md :378); re-running the enable on a namespace already enabled, `HSCUSTOM` included (Design Notes: a re-run is the vendor's own path, and the install namespace is not refused); `%SYS`/`%ALL` not foreseen in the dialog (the spec prescribes `"selfProtection": ""` and no advisory); a `Finished` task whose `Console` reports a step failure, read as done (Never: no `Console` parsing); `BroadResidue` run only by the Task 1 proof (the suites compare `Snapshot()`).
- false: the parked `.patch` files (the spec cites them as its record); `InteropProbe` with no arming (callers are armed, and `browserConfig` refuses `ocupilot` and `ocupilot-slot-*`); the `SETTLESECONDS` derivation (max(3 × 13 s, 300) is 300); a `Failed` enable reported done (`AwaitTask` answers it 500); CI timings (`ci-shards.mjs` assigns an unrecorded class, and the timings refresh from a green run); the granted-role legs pinning a defect (they pin AD-8's current rule); unauthenticated privileged applications (vendor source: `/bulkfhir/api` is password plus JWT, and `/bulkfhir` carries no role; `HS.BulkFHIR.Installer.CreateWebApp` runs only from a BFC configuration).
- wontfix-theoretical: the port queues a nameless enable (the tool always sends its target, the fresh read precedes the write, and the vendor's `validateNamespace` refuses `""`); a resource named `%All` (creating one needs `%Admin_Secure`, whose holder may already grant itself the `%All` role, AD-10).
- low, not worth the change: `ProbeNamespaces` reading a failed list as none, and a snapshot read error in `RestoreInstance` (each fails loudly through the after-all snapshot); the unguarded `%SYS` switch around `Security.Resources.Exists`; the page spec's `HSCUSTOM` target in the AC4 stub leg; the copy-named status-line hooks; `InteropProbe`'s length (a helper, not a test class); the 120-character snapshot cut and the restore's partial repair (both fail loudly); the two wide `RESIDUE` patterns (used by the Task 1 proof only).

## Spec Change Log

- 2026-10-01, spec gate (runner): spine amendments 1-5 under Design Notes were written at the gate (AD-26, AD-44, AD-10 for DW-1813, AD-21, and AD-8's poll pair); Task 0 completes AD-8 with its measured pairs. AD-21's reading (vendor-derived ENSTEMP/SECONDARY directories accepted) is with the orchestrator for confirmation; if it is overruled, the change is a refusal leg on this tool.
- 2026-10-01, implement (Task 0): halted, `intent gap: observation contradicts the plan` (Design Notes › Measured at implement). No AD-8 sentence: the candidate pairs do not reproduce the reference. No AD-15/AD-53 case: the vendor audits the enable. AD-21's amendment holds on IRIS for Health: no database was created. Task 0's port plumbing was reverted; `Test/InteropProbe.cls` is kept.

- 2026-10-01, orchestrator merge gate (by=merge_gate): the story is split for scope (Rule 5). DW-1813, DW-1824 and DW-1858 move to Story 18.17, which runs first; this story keeps the enable (DW-1776) and runs after release 1.0.5. The enable takes option 2: `%All` only (AD-8, written), the strongest typed-name confirmation, a consequence naming every instance-wide effect Task 0 measured, a refusal before anything is queued for a caller without `%All`, and its governance key disabled by default. On resume the runner rewrites the intent contract to that scope, sets `status: draft` and re-plans.

- 2026-10-01, re-plan (runner, re-dispatch protocol): the intent contract is rewritten to the merge-gate decision (option 2: `%All` only, typed-name confirm, the measured consequence, governance disabled) and the split (DW-1813, DW-1824 and DW-1858 shipped in Story 18.17); status reset to `draft`. Design Notes › Measured at implement and this log are kept.

- 2026-10-01, spec gate (runner): orchestrator ruling option A (by=merge_gate) -- the agent card takes the destructive treatment with no typed name (UX-DR56 stands); the screen keeps the typed-name dialog. The card's typed-name tasks, the `typedName` wire field and its tests, the EXPERIENCE.md :618/:672/:755 edits, the `TYPEDNAME` parameter and AD-53 amendment 2 are removed; the intent's Approach bullet and "Enable (agent)" row are amended. AD-8 amendment 1 (`%All:USE`) was written at the gate.

- 2026-10-01, implement (Task 1): halted, `intent gap: the throwaway cannot be restored` (Design Notes › Restore proof): `%ALL` answers 404 on `ocupilot-b-ci`, and five broad residue lines are edit stamps. Task 1's code is parked as `spec-18-15-task1-interopprobe.patch` (it supersedes the Task 0 patch); nothing else was built.

- 2026-10-01, spec gate after the Task 1 halt (runner, intent-preserving test approach, Rule 5 tier 1): (1) `%ALL` -- the tool's refusal is unchanged; where the instance has no `%ALL` namespace the fresh read's 404 already queues nothing, so the real-port leg accepts either answer and the sentence is pinned through the recording seam (Design Notes, the order bullet); Task 1's `%ALL` halt condition is dropped. (2) Residue -- the five measured edit stamps (web-application `LastUpdate`, four `SQLStatsSettings` edit stamps with unchanged settings) join `RESIDUE` by exact name. Task 1 resumes from `spec-18-15-task1-interopprobe.patch`. Status reset to `in-progress`.

- 2026-10-01, rework iteration 1 (runner, trigger=ci): CI run 36869954798 on `be4b1baf` failed three legs on the restore's language-server gap on a fresh instance; the code review's patches are committed with this re-open; the open items are the `[CI]` and `[Review]` tasks under Tasks & Acceptance.

## Review Triage Log

### 2026-10-01 — Review pass

- verdicts: 25 findings — high 0, medium 7, low 10, false 8, maybe-false 0
- findings:
  - `[low]` `[patch]` (verification-gap) The gate class's dispatch legs assert `calls=0`, which a dispatch through the shipped port can never break — the dispatch legs now compare only status, code and pair; route and confirm legs keep `calls=0`.
  - `[medium]` `[patch]` (verification-gap) "No task queued", "not enabled" and `SecondReads` assertions cannot fail where they stand — removed the constant ones (seam, governance, gate refusal legs); the shipped-port and deleted-since-read legs now run through `MappingRecordPort` and assert no enable was sent (`WriteCount` 0); both round trips assert `SecondReads() >= 0`. Runs 1561, 1562 green.
  - `[low]` `[reject]` (verification-gap) `NamespacePort`'s INTEROP caller-body refusal has no test — no shipped caller sends a body (`SENDSBODY` 0), and a test would log an error and raise the instance's alerts; MAPPINGS' twin is untested alike.
  - `[medium]` `[patch]` (verification-gap) The gate class and the browser spec enable without comparing the instance snapshot afterwards — `NamespaceInteropGate` takes the snapshot before its principals exist and fails `OnAfterAllTests` on any difference (run 1562); the browser spec keeps the snapshot in `^OCUPROBE1815("browser")` and asserts an empty diff in `after` (1/1 pass).
  - `[low]` `[reject]` (verification-gap) AC1's planned users-roles mutation stayed green (run 1164) — deleting `%HS_BFC_Administrator` removes it from `Admin`, so that branch is defense in depth; AC1's pin is falsified by the language-server mutation (run 1165).
  - `[low]` `[reject]` (verification-gap) AC2's browser typed-name leg was not run under its mutation — Rule 19 needs one demonstrated mutation per AC, and AC2 has the page spec's and the browser registration's.
  - `[medium]` `[patch]` (verification-gap) AC3's read-once clause compares `SecondReads` with no floor — same root cause as the second row; floor added.
  - `[medium]` `[patch]` (verification-gap) AC4's "nothing is queued" and "zero port calls on the mint" are not observed — same root cause as the first two rows; the route and confirm legs observe it, and the dispatch gate's order before `InvokeTool` is kernel structure pinned by earlier stories.
  - `[false]` `[reject]` (verification-gap) AC5's 3,800 kB clause has no test — DW-371 pins `maximumWarning` (2388kB) and `build-output.test.mjs` measures the emitted total against it.
  - `[medium]` `[defer]` (verification-gap) The spine's AD-8 says a granted-role `%All` holder passes `%All:USE`; the code and its pin refuse one — frontmatter `deferred` item 1 (with the intent layer's R1 row).
  - `[false]` `[reject]` (verification-gap) The diff edits `ui/angular.json` against the spec's Design Notes — the runner's binding dispatch direction re-bases `maximumWarning` when crossed (2,387,861 bytes, re-based to 2388kB); the Auto Run Result below records it.
  - `[medium]` `[patch]` (verification-gap) The gate class's admitted leg reads `IsEnabled` without handling an enable that outlasts the 30 s bound — the leg's route now runs through `NamespaceInteropRecordPort`, which waits 150 s (under `RunAs`'s 180 s), so it never answers started (run 1562).
  - `[medium]` `[defer]` (intent) R1: "holds `%All`" read as an effective holder; the diff admits only a direct one — grouped with the AD-8 row, `deferred` item 1.
  - `[false]` `[reject]` (intent) R2: `%ALL` gets the sentence only through the seam — AC4 was amended at the spec gate to accept 404 where the instance has no `%ALL` namespace; the seam pins the sentence.
  - `[false]` `[reject]` (intent) R3: 202 is internal and the client sees 200 with `continues` — that is 18.14's shipped contract for the started answer (`Api/ScreenAction.cls:375`, `Confirm.cls:524`).
  - `[false]` `[reject]` (intent) R4: the suites run in CI too — the Design Notes name CI's fresh throwaways, and the Tasks add the ci-throwaway rosters.
  - `[low]` `[reject]` (intent) R5: a regressed guard would send a `%SYS` or `%ALL` enable from the shipped-port leg — the vendor refuses `%SYS`, throwaways hold no `%ALL` namespace, and the seam leg pins the guard; a read-through, write-refusing port would be new test surface.
  - `[false]` `[reject]` (intent) R6: the consequence omits the SystemConfig records and adds an unmeasured "Elsewhere" clause — the sentence is the spec's prescribed text, names every effect the Approach lists, and "Elsewhere" is AD-21's amended reading of editions without the HealthShare libraries.
  - `[false]` `[reject]` (intent) R7: the typed name is checked only in the browser — AD-53: a screen action's review is its dialog and typed name, and the route is the person's own write.
  - `[low]` `[reject]` (intent) No card rendering is tested for this tool — the destructive treatment is the unchanged generic card, and the code-to-sentence map is pinned by `proposal-view.test.mjs`.
  - `[low]` `[reject]` (intent) The agent's still-running sentence is not exercised for this tool — the panel's `continues` path is unchanged; the confirm's `continues` is asserted.
  - `[false]` `[reject]` (intent) The screen's started leg asserts no marking — AD-53: a screen action emits no marker; the agent's leg asserts `200 confirmed 1 1`.
  - `[low]` `[reject]` (intent) No test re-fetches a mapping list or the list after an agent-confirmed enable — 18.14 pins the `secondaryEntityTypes` routing; this story pins that the enable emits the event.
  - `[low]` `[reject]` (intent) `RestoreInstance`'s users branch is untested — duplicate of the AC1 row above.
  - `[low]` `[defer]` (intent) The change's records disagree (Auto Run Result said `angular.json` untouched; Tasks :272-273 admit a granted-role holder) — the Auto Run Result is rewritten below; the Tasks text goes with `deferred` item 1.

### 2026-10-01 — Review pass (rework iteration 1)

- verdicts: 17 findings — high 0, medium 1, low 13, false 3, maybe-false 0
- findings:
  - `[low]` `[reject]` (verification-gap) Nothing fails if the STOP before an unrecorded server's DELETE is dropped, which would leave its process listening — the code stops first and no Java process or listener remained on `ocupilot-b-ci` after this pass's enables (`ps`, `ss`); a post-STOP re-read is a new branch against an unlikely edit.
  - `[low]` `[reject]` (verification-gap) The empty-record guard has no test — it is reached only when the record-time `LIST` fails, which is red through the after-all snapshot either way; a seam to reach it is new test surface.
  - `[low]` `[reject]` (verification-gap) The language-server half of the snapshot comparison has no floor if `LIST` fails on every call — that read is the shipped Language Servers read, pinned by `LanguageServer` and `LanguageServerWire`, so it cannot fail silently; the floor would add assertions to three files.
  - `[low]` `[reject]` (verification-gap) A server whose `ACTIVITY` read fails at record time is left out of the record and later deleted — unlikely for the vendor's local stopped `%` servers, and red through the after-all snapshot, whose `PreparedSnapshot` is taken apart from the record; the fix is a new guard.
  - `[low]` `[reject]` (verification-gap) The Auto Run Result still says `FHIR_Validation_Server` stopped and has no line for this rework — spec text; finalize rewrites the Auto Run Result for this pass.
  - `[low]` `[reject]` (verification-gap) Task 1's `RestoreInstance` text (:216) describes stop-only — spec text; it is Task 1's plan, and the rework item at :333 states the extension.
  - `[low]` `[reject]` (verification-gap) Frontmatter `deferred` item 1 keeps stale line numbers though the `[Review]` item is ticked — spec text outside that item's three named targets; the claim lives in DW-1897.
  - `[false]` `[reject]` (intent) No CI run on the rework is recorded — CI runs on the runner's push of this commit, as for every pass.
  - `[false]` `[reject]` (intent) The pin bites only when the definition is absent at record time — by design: a definition the record holds is not deleted; the delete path runs on CI's fresh throwaways and on `ocupilot-b-ci`, which now has no definition.
  - `[low]` `[reject]` (intent) The empty-record carve-out has no test — same root cause and reason as the second row.
  - `[low]` `[reject]` (intent) Stop-then-delete is not separately falsified — same root cause and reason as the first row.
  - `[low]` `[reject]` (intent) A failed per-server `ACTIVITY` read at record time leads to a deletion — same root cause and reason as the fourth row.
  - `[low]` `[reject]` (intent) Tasks :216 is stale — same as the sixth row.
  - `[low]` `[reject]` (intent) Auto Run Result :631 is stale — same as the fifth row.
  - `[low]` `[reject]` (intent) The hygiene item has no evidence in the spec — spec text; the Auto Run Result for this pass records it.
  - `[medium]` `[defer]` (intent) carried — the "Not `%All`" row admits only a direct `%All` holder; `deferred` item 1 (DW-1897).
  - `[false]` `[reject]` (intent) carried — `ui/angular.json`'s re-base is an edit to a contended line; the runner's dispatch direction, landed in `be4b1baf`.

## Design Notes

**Governing ADs:**

- AD-8's 2026-10-01 sentence binds the pairs: `%All` and the poll's `%Admin_Operate:USE`. AD-29 adds that the vendor's check is only a lower bound. AD-44 binds `CLASSICPAGES`.
- AD-26 (written) binds the queued write: it is read once by the one poller, and past the bound it has started. AD-51 makes it an action write with a declared subject and no body.
- AD-2, AD-27 and AD-52: `NamespacePort` extends `AdminPort`, and nothing else names the admin API. AD-59 binds `Snippet`.
- AD-6, AD-34 and AD-40: the proposal, the confirm and the gates at the write. AD-53 and AD-55 make the screen and the agent two callers of one tool. AD-58 binds the read-back (`unchecked` when the write has started).
- AD-14: the change event, with the mapping lists re-reading through `secondaryEntityTypes`. AD-15: the marker; the vendor audits the enable, so no named case is needed. AD-22: the baseline line, `false`.
- AD-10: no predicate applies. AD-21 (confirmed by the orchestrator): the enable names no directory. AD-5, AD-13 and AD-19: the row action, the namespace id and the router.

**Decisions:**

- **`%All` is declared as the pair `%All:USE`.** Every gate already evaluates pairs before any port call: the dispatch at :257, the confirm at :299 and the route at :249. The same pair set reaches the card's "requires" line and the ledger's row release, so nothing in the kernel, API or client changes.
  - No resource is named `%All`. A pair naming an absent resource is passed only by a user assigned the `%All` role directly; a user whose role only grants `%All` is refused (measured on `ocupilot-b-ci`: `CheckUserPermission` reads 1 for a direct holder, 0 for a granted-role holder; ledger DW-1897).
  - The refusal therefore names `%All:USE`.
  - A dedicated role check was rejected. It would touch `Base`, `Operation.Gate`, `Dispatch`, `Confirm`, `Disclosure`, `Read.BannerRequires` and the ledger. `$ROLES` was rejected too, since no gate infers authorization from roles alone (AD-21).
  - The pair order is list pairs, `%All:USE`, the poll pair, then the classic page, so a principal without `%All` is refused naming it.
  - Known limit (inference; not measured whether IRIS allows it): an administrator who creates a resource named `%All` and grants it would pass the pair. `NamespaceInteropGate` asserts no such resource exists.
- **`CLASSICPAGES` is declared but cannot gate on its own.** A `%All` holder holds every custom resource, so the page's resource can never be the pair that fails. It is declared for AD-44's roster and for the card's "requires" line. `ClassicPageGate`'s custom-resource leg exempts this tool and tests its `%All:USE` refusal instead.
- **The agent card takes a delete's destructive treatment, with no typed name** (orchestrator merge gate 2026-10-01, option A). The owner's UX-DR56 ruling of 2026-09-25 (EXPERIENCE.md :618, :672, :755; AD-10) stands: a destructive agent proposal carries no typed-name field. The screen keeps the typed-name dialog. No AD-10, AD-53 or EXPERIENCE.md :618/:672/:755 change.
- **Placement.** The enable is a page-owned row action on the Namespaces list, not a New Namespace checkbox. One Save carries one write (AD-55), and the lazily built handler overwrites registrations, so the page owns the action, as with 18.14's copy-mappings.
- **The install namespace is not refused.** AD-10's install-namespace rule covers a delete and a Globals or Routines change, and `Prohibited.Namespace` reads only those. The enable's mappings name no OcuPilot package, routine or global (inference, from the source and Task 0's E1). No test enables the install namespace.
- **No interoperability state on the list.** The admin API's read answers no enabled flag, and composing one would be a new AD-27 case. A re-run is the vendor's own path.
- **The `%SYS`/`%ALL` refusal is the tool's own sentence** (`SYSTEMREASON`, the `AuditCopy` precedent), because `Api/Error.cls` holds 989 of its 1,000 parameters. The sentence is published at EXPERIENCE.md :378, and `NamespaceInterop` asserts both callers answer exactly it.
  - Order on both callers: the fresh read, then the sentence, then any write. On an instance with no `%ALL` namespace (`ocupilot-b-ci`, and likely CI's fresh throwaways) the fresh read answers 404 `PORT.NOTFOUND` first and nothing is queued, which meets AC4's "nothing is queued"; the `%ALL` sentence is pinned through the recording seam (`SeamNamespaceEnableInterop` over `MappingAcceptPort`, the 18.14 `MappingAllTargetFixture` precedent), whose fresh read answers for `%ALL`. The real-port `%ALL` leg asserts either the sentence (where `%ALL` exists) or 404 (where it does not), and no task either way [AMENDED 2026-10-01, runner, spec gate after the Task 1 halt].
- **Read once.** `AwaitTask` and the tests' `Settle` are the only readers of a finished task. The started legs inherit 18.14's known behavior: `AwaitTask` logs the bound (:2641) before `NamespacePort` converts it to started. If that raises the monitor state, the implement stage lists it under `deferred:`; `AdminPort` is not changed.
- **The restore is test-only.** It works by diff against a record taken before the first probe namespace exists, on `ocupilot-b-ci` and CI's fresh throwaways, never on a dev instance. No test enables `USER`, `HSCUSTOM`, `%SYS`, `%ALL`, or a namespace over their databases.
- **Bundle.** The build measured 2,387,861 bytes, over `maximumWarning` (2386kB), so `ui/angular.json` and `angular-json.test.mjs` re-base it to 2388kB, per the runner's dispatch direction. Epic 16's 16.15 changes the same line; the integrate-forward takes the larger measured figure. Above 3,800 kB the story stops and asks.

**Proposed spine amendments.** Under Rule 20 the runner writes these at the spec gate; this stage does not edit the spine.

1. **AD-8**, appended to its 2026-10-01 Story 18.15 sentence: "It is declared as the pair `%All:USE`: no resource is named `%All`, so only a user assigned the `%All` role directly passes it, and a user whose role only grants `%All` is refused (measured on `ocupilot-b-ci`; ledger DW-1897), and its refusal names that pair; the classic page's custom resource it also declares is held by every such caller."
2. (Withdrawn at the gate, option A: no AD-53 change.)

**Integration ACs:**

- AC2 is pinned by `NamespaceInterop`, `namespace-list.page.spec.ts` and the browser spec: the Namespaces page consumes the tool through the screen-action route.
- AC3 is pinned by `NamespaceInterop`: the proposal and the confirm consume the tool and `NamespacePort`.
- The mapping lists consume the `namespace` `updated` event through `secondaryEntityTypes`, the same event copy-mappings emits, routed as Story 18.14 pinned it. This story pins that the enable emits it: `namespace-list.page.spec.ts` asserts the list reads again after the enable, and so does the browser spec.

**Consumes:**

- 18.14: `NamespacePort`'s started conversion, the `namespace-list.page.ts` wrapper and its status line, `NamespaceStarted*`, `MappingAcceptPort`, `MappingWriteGate` and `ClassicPageGate`.
- 18.2: `NamespaceList` and `NamespaceWriteGate`. 18.4: `DatabaseActionProbe`'s settle and `SecondReads`.
- 16.17's read-back, 14.1's `Snippet`, 14.2's baseline, and Task 0's `InteropProbe`.

**Consumed-by:**

- 18.12: the agent's grown tool set.
- 18.13: multi-namespace install, which may enable a target namespace through this tool.
- No other consumer in this epic.

**Ledger inbox:**

- DW-1776 is addressed by Task 1, the enable tasks, and AC1-AC4.
- DW-1813, DW-1824 and DW-1858 shipped in Story 18.17 (`3cc32b04`) and are not this story's.

**Footprint (Rule 11).** Epic 16's in-flight 16.15 changes EXPERIENCE.md (:261, :335, :609), `scripts/ci-throwaway.sh` (one `# classes:` line at the end of the PRINCIPALS block and one in the test-provider block), `strings.ts` and `ui/angular.json`.

- EXPERIENCE.md is edited in place at :164, :173, :378 and :728.
- `ci-throwaway.sh` takes two new lines, at :417 and :255, away from Epic 16's.
- `strings.ts` takes a block after :3610.
- `ui/angular.json` takes the re-based `maximumWarning`, 2388kB, on the line 16.15 also changes.
- These are one-element appends to one-line lists, which the integrate-forward merge resolves by union: `AdminPort` (`MUTATINGTYPES`, `BODYLESSTYPES`, `QUEUEDWRITES`), `PortFixture:21`, `ReadTool:93-94`, `ToolRoundTrip:51`, `MappingDescriptor:20`, `ClassicPageGate:62`, `GovernanceBaseline:11` and `screen-action-handler.ts:255`.
- Kernel files take inserted lines only: `Baseline.cls`. `Write.cls`, `Mint.cls` and `Propose.cls` are untouched.
- `Error.cls`, `Router.cls`, `Prohibited.cls`, `Registry.cls` and `Classification.cls` are untouched.

### Measured at implement

Task 0, 2026-10-01, on `ocupilot-b-ci` (IRIS for Health). The enable went through `AdminPort` with a test port whose bound is 0 and whose poll never reads; `InteropProbe.SettleOwnTasks` read each finished task once.

- **Payload and queue (as planned).** `INTEROP` sends no body and is queued through `ShouldRunAsync`. The port answered 503 at once, and the vendor's worker then ran the task. `IsHealthShareInstalled` reads 1. The install namespace `HSCUSTOM` already reads `IsEnsembleNamespace` 1, and `/api/interop-editors` already matches `%EnsRole_InteropEditorsAPI`.
- **Reference run** (the test process, `%All`, `OCUPROBE1815A` over `OCUPROBE1815D`):
  - The task ended `Finished` in 13 s, with an empty `FailureReason` and an empty `Console`.
  - `IsEnsembleNamespace` went from 0 to 1, and a portal application serves the namespace. The probe database grew from 1 MB to 114 MB, and no database was created.
  - `SecondReads()` stayed 0 and the monitor state stayed 0. OcuPilot's own objects (145 snapshot lines) were unchanged.
- **Inside E1-E6:**
  - E1: 184 mappings, to ENSLIB, HSLIB and HSSYS, plus `%SYS` to IRISSYS, `HS.Local` to HSCUSTOM and 11 to the namespace's own database.
  - E2: four applications, `/csp/healthshare/<ns>`, `/services`, `/bulkfhir` and `/bulkfhir/api`, and their CSP directory.
  - E3: `%EnsRole_ProdPrivs_<NS>`, `%HS_DB_<NS>` and 20,479 SQL privilege rows.
  - E4: the vendor's `^%SYS` markers, the HSSYS configuration item, activation-log rows, and `<mgr>HS.Util.Installer.<NS>-1.log`.
  - E5 was unchanged. E6: `[Map.<NS>]`.
- **Outside E1-E6 (the halt).** These are instance-wide changes from the HealthShare branch's FHIR and BulkFHIR setup, and `RemoveAll` cannot remove them by probe name:
  - 13 resources created: `%HS_BFC_*`, `%HSAdmin_ServiceRegistry`, `%HSAdmin_XUAConfigRegistry` and `%HS_FHIRServer_Validator`.
  - Six `%HS_BFC_*` roles created, and `%HS_Administrator`'s resources changed.
  - User `Admin` granted `%HS_BFC_Administrator`, a role that holds `%Admin_Manage`, `%Admin_Secure`, `%Admin_Task` and `%Admin_OAuth2_Client` at USE.
  - The task "FHIR Purge Expired Search Results Task" scheduled in HSSYS.
  - The `FHIR_Validation_Server` Java language server started.
  - About 235 `^%SYS("HealthShare","SystemConfig*")` records keyed by integer id.
  - The new applications also match `%DB_HSCUSTOM`, the install namespace's database, and `/bulkfhir/api` matches `%DB_IRISSYS` and `%HS_ImpersonateUser`.
- **Audit.** The vendor wrote 20,592 events: 20,346 `RoleChange` "Object Privilege Granted", 206 `ConfigurationChange`, 13 `ResourceChange`, 10 `ApplicationChange`, 3 `OSCommand`, one `UserChange` "Modify User Admin" and one production change.
- **Pairs** (a child process logged in as the principal):
  - With the list's two pairs, `%Admin_Operate:USE`, `%DB_IRISSYS:WRITE` and `%Admin_Secure:USE`, the task `Failed` with `<PROTECT>validateInstallation+5^%Library.EnsembleMgr.1` on the probe database. It left 122 mappings and `IsEnsembleNamespace` 1, and the vendor posted an alert (`Error rebuilding Extent index`).
  - With `%DB_OCUPROBE1815D:RW` added, the task `Finished`, but the HealthShare half was skipped silently (audit "Attempt to access a protected resource"). The run made no `%HS_DB` role, no HS mapping and only one application, so the candidates do not reproduce the reference.
  - The two drop-one runs were not made.
- **Cleanup.** After `RemoveAll` alone, S2 differs from S0 by every change outside E1-E6. A test-only restore deleted those resources, roles and the task, restored `%HS_Administrator` and `Admin`, removed the SystemConfig records and stopped the language server. S2 then equals S0, apart from counters and HSSYS index nodes.
- **One incident.** The harness read an already-ended task a second time: the principal had not been able to delete its row. That read logged one `ERROR #7846`. `SettleOwnTasks` now deletes a task the list already shows ended without reading it. The monitor state, which that line and the vendor's own alert raised to 2, was set back to 0, and the two task rows were deleted as objects.

### Restore proof

Task 1 re-run, 2026-10-01, on `ocupilot-b-ci`, as the test process (`irisowner`, `%All`), from `spec-18-15-task1-interopprobe.patch` with the five edit stamps in `RESIDUE`. The enable went through an `AdminPort` subclass with a 300 s bound whose poll recorded each answer, so `AwaitTask` read the finished result once; `SettleOwnTasks` then found no task. **Pass.**

- **The enable.** `OCUPROBE1815A` over `OCUPROBE1815D` ended `Finished` in 12.4 s (11:03:26 to 11:03:38), HTTP 200, with an empty `FailureReason` and `Console`. `IsEnabled` and `HasPortal` read 1. `RemoveAll` took 2.6 s, the whole proof 15.9 s.
- **S2 equals S0:** 495 lines each, none differing, `Admin`'s roles included. The record held 344 instance lines and no `SystemConfig` node, and was forgotten after `RemoveAll`.
- **Each clause, in `Diff(S0, S1)`:**
  - 112 ENSLIB, 52 HSLIB and 7 HSSYS mappings, beside IRISSYS, HSCUSTOM and 11 to the probe database; four applications; `%EnsRole_ProdPrivs_OCUPROBE1815A` and `%HS_DB_OCUPROBE1815A`; 236 `SystemConfig*` nodes, the configuration item and 29 activation-log rows;
  - `Admin` gains `%HS_BFC_Administrator`, which holds `%Admin_Manage`, `%Admin_OAuth2_Client`, `%Admin_Secure` and `%Admin_Task` at `U`;
  - 13 HealthShare resources and six `%HS_BFC_*` roles created, and `%HS_Administrator` gains `%HSAdmin_ServiceRegistry` and `%HSAdmin_XUAConfigRegistry`;
  - task 1151 "FHIR Purge Expired Search Results Task" in HSSYS, and `FHIR_Validation_Server` from stopped to running;
  - `/services`, the namespace's own application and `/bulkfhir/api` match `%DB_HSCUSTOM`, and `/bulkfhir/api` also `%DB_IRISSYS` and `%HS_ImpersonateUser`;
  - no database created beyond the probe's.
- **Unchanged:** `SecondReads()` 0, the monitor state 1, `$SYSTEM.Monitor.Alerts()` 410.
- **Broad residue:** `B0` and `B2` hold 1,669 lines each and nine differ, all inside `RESIDUE`, so `BroadResidue(B0, B2)` is empty:
  - the SQL `cursor counter` (3365 to 3368) and `statement id` (25270 to 25302);
  - `^%SYS("CSP","LastUpdate")` (67844,38894 to 67844,39813);
  - the four `SQLStatsSettings` rows, whose edit date and job moved and whose settings, from the fifth `$List` position, are equal (`STAMPEDROWS`);
  - `HS.HC.Util.Installer.LogD` and `LogI`, node counts unchanged at 18 and 7. `^%SYS("WQM","Repeat")` did not move this run.
- **The `GET`s:** `%SYS` answers 200; `%ALL` answers 404 `PORT.NOTFOUND` (`Config.Namespaces.Exists("%ALL")` 0).
- **After:** no probe namespace, database, directory or record, no `%HS_BFC_*` role or resource, no FHIR purge task and no `SystemConfig*` node; `Admin`'s roles as before; `FHIR_Validation_Server` stopped. The proof's scratch classes were deleted.

## Verification

**Setup (slot B):**

- Load code with `/tmp/epic-18-d4/load-throwaway.sh`, never with the MCP loader, which reaches the dev instance. Every MCP call carries `server: "ocupilot-slot-b"`.
- Every enable, probe and principal stays on `ocupilot-b-ci`. Never restart it.
- If a class's arming variable reads unset in the container, arm it per call with `docker exec -e OCUPILOT_ALLOW_NAMESPACE_CONFIG=1`. Add `-e OCUPILOT_ALLOW_PRINCIPALS=1` for the gate class.
- Run one test class per call, and wait until each run has landed in `%UnitTest_Result`.
- Before any browser run: `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci` exported.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one call at a time. Expect 0 failures each, with totals checked against `%UnitTest_Result`. The classes:
  - `NamespaceInterop`, `NamespaceInteropGate`, `NamespaceCopy`, `NamespaceWrite`, `NamespaceWriteGate`, `MappingWriteGate`, `ClassicPageGate`;
  - `AdminPortAsync`, `ToolWrite`, `ReadTool`, `SurfaceCoverage`, `EndpointCoverage`, `ToolRoundTrip`, `ProposalPrivilege`, `DraftRegistry`, `ToolEmit`;
  - `MappingDescriptor`, `NamespaceDescriptor`, `GovernanceBaseline`, `Governance`, `ToolDispatch`.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/namespace-interop.browser-spec.mjs browser/namespaces.browser-spec.mjs browser/namespace-mappings.browser-spec.mjs`. Expect a pass.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`, then `uv run scripts/check-objectscript.py <changed .cls>` and `bash scripts/lint-docs.sh`. Expect clean, with `wc -l` on EXPERIENCE.md reading 993.
- `(once, before dev_complete)`:
  - the full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci`, one class at a time;
  - then `cd ui && npm test && npm run build`;
  - then `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`.
  - Expect green, with a non-zero count.
- `(CI)` The full browser suite runs in CI's three browser shards (Rule 29), not locally.

**Planned pinning mutations (Rule 19).** Apply each to the throwaway's source copy, or to a rebuilt and redeployed bundle. Observe red, revert byte-identical, and record a `mutation:` line here. Refusal mutations run only through the recording port.

| AC | Mutation | Expected red |
| --- | --- | --- |
| AC1 | `RestoreInstance` skips users' roles | the proof's S2 differs on `Admin`'s line; `NamespaceInterop`'s after-all snapshot |
| AC2 | `namespace-list.page.ts` drops the `enable-interop` registration | `namespace-list.page.spec`'s AC2 legs; the browser spec |
| AC2 | the page sends on `confirmed` without the dialog (no typed name) | `namespace-list.page.spec`'s dialog leg; the browser spec's typed-name leg |
| AC2/AC3 | `Namespace.Namespace/INTEROP` removed from `QUEUEDWRITES` | `NamespaceInterop`'s round trips (refused, no task); `AdminPortAsync` |
| AC3 | `NamespaceEnableInterop.Consequence` answers `""` | `NamespaceInterop`'s agent leg (`"1\|"`); dropping the client map line reddens `proposal-view.test.mjs` |
| AC3 | `NamespacePort`'s INTEROP branch skips the started conversion | `NamespaceInterop`'s started legs (503 `PORT.TIMEOUT`) |
| AC3 | the baseline key set to `true` | `GovernanceBaseline`; `NamespaceInterop`'s governance leg |
| AC4 | `SystemProblem` answers `""` | `NamespaceInterop`'s `%SYS` and `%ALL` legs (a recorded write) |
| AC4 | `PrivilegePairs` drops `%All:USE` | `NamespaceInteropGate` (the non-`%All` principal is admitted, and the port is called); `ProposalPrivilege` |
| AC5 | the dialog's consequence drawn in `--ocu-surface` | the interop browser spec's DW-1337 legs, in both themes |

- mutation: `NamespaceEnableInterop.PrivilegePairs` drops `%All:USE` → `NamespaceInteropGate`'s refusal and lost-grant legs red, both principals admitted and the route's write recorded by `MappingAcceptPort` (run 1155); `ProposalPrivilege` red (run 1156).
- mutation: `NamespaceEnableInterop.SystemProblem` answers `""` → `NamespaceInterop`'s seam leg (an `INTEROP` recorded, the mint answering 200) and its shipped-port `%SYS` leg red (run 1157); the vendor refused the shipped `%SYS` enable as not valid.
- mutation: `Namespace.Namespace/INTEROP` removed from `AdminPort.QUEUEDWRITES`, the port tree recompiled → five `NamespaceInterop` legs red (run 1158), and `AdminPortAsync` (run 1159).
- mutation: `NamespaceEnableInterop.Consequence` answers `""` → `NamespaceInterop.TestTheAgentsEnableRoundTrips` alone red, `"1|"` (run 1160).
- mutation: `NamespacePort.Invoke`'s `INTEROP` branch skips `Started` → both started legs red, 503 `PORT.TIMEOUT` (run 1161).
- mutation: the baseline's `osmgmt.namespaces.enableinterop` line `true` → `GovernanceBaseline` (run 1162) and `NamespaceInterop`'s governance leg and declarations (run 1163) red.
- mutation: `InteropProbe.RestoreInstance` skips users' roles → stayed green (run 1164): deleting `%HS_BFC_Administrator` removes it from `Admin` (measured), so that branch is defense in depth. `RestoreInstance` stops no language server instead → `NamespaceInterop`'s after-all snapshot red on `FHIR_Validation_Server` (run 1165); the server was stopped by hand after the revert.
- mutation: the Namespaces list page drops its `enable-interop` registration → six `namespace-list.page.spec` legs red; rebuilt and redeployed, `namespace-interop.browser-spec` red, no menu item.
- mutation: the page's `onOpenEnable` sends at once → six `namespace-list.page.spec` legs red. The browser spec was not run under it, since it would enable the probe while `after` removes it.
- mutation: `.ocu-typed-name-consequence` drawn in `--ocu-surface`, rebuilt and redeployed → `namespace-interop.browser-spec`'s dialog walk red in both themes (1.04:1 light, 1.08:1 dark).
- mutation: the `NAMESPACE.INTEROP` branch dropped from `consequenceSentence` → `proposal-view.test.mjs` red; one word of `SYSTEMREASON` changed → `self-protection.test.mjs`'s Story 18.15 pin red; `ENABLE_INTEROP` dropped from `UNDRAWN_ACTIONS` → `screen-action-handler.spec`'s undrawn leg red.

**QA pass, 2026-10-01 (the three review-patched assertions the implement stage never falsified):**

- mutation: `NamespaceEnableInterop.SystemProblem` answers `""` (re-run, isolating the `WriteCount` guard) → `NamespaceInterop.TestSysAndAllAreRefusedThroughTheShippedPort` red on "no enable was sent, so nothing was queued" (`RECORDPORT.WriteCount` reads 1, not 0) alongside the sentence legs, and `TestSysAndAllAreRefusedThroughTheSeam` red the same way (run 1564); reverted byte-identical, `NamespaceInterop` 9/9 clean (run 1565).
- mutation: `InteropProbe.RestoreInstance`'s language-server loop forced to `Continue` unconditionally (stops none) → `NamespaceInteropGate.OnAfterAllTests` red, `ERROR #5001`: `added ["languageserver|FHIR_Validation_Server|1"] removed ["languageserver|FHIR_Validation_Server|0"]` (run 1566); `FHIR_Validation_Server` stopped by hand (the record had already been forgotten by the mutated restore), reverted byte-identical, `NamespaceInteropGate` 4/4 clean (run 1567).
- mutation: `NamespaceInteropRecordPort.BOUNDSECONDS` 150 → 0 → `NamespaceInteropGate.TestAnAllHolderIsAdmittedOnBothCallers` red on "and the namespace is enabled" (the route answered started before the vendor's worker finished; run 1569); reverted byte-identical, `NamespaceInteropGate` 4/4 clean (run 1570). At `BOUNDSECONDS` 3 (run 1568) the leg stayed green on an enable that had only started. `IsEnsembleNamespace` reads 1 once the vendor's mappings exist, early in the run. The cleanup then deleted the namespace mid-install, which left vendor task `8177754…` `Running`. The code review added the `continues` assertion below.

Gap audit against AC1-AC5 and the I/O & Edge-Case Matrix found no row without a pinning test and no pinning assertion that cannot fail; no test was added.

**Code review, 2026-10-01 (the patched assertions):**

- mutation: `NamespacePort.Started` also answers a finished `INTEROP` as started → `NamespaceInteropGate.TestAnAllHolderIsAdmittedOnBothCallers` red on "the route answers the enable done" alone (run 1577); reverted byte-identical, the port tree recompiled.
- mutation: `InteropProbe.HasHealthShareHalf` reads `%HS_DBX_` → the same leg red on "its HealthShare half included" alone (run 1578); reverted byte-identical.
- mutation: `NamespaceEnableInterop.PrivilegePairs` skips `Gate.WithClassicPages` → `ClassicPageGate.TestAnAssignedPageGatesEveryDeclaringToolOnTheAgentsCaller` red on the enable's page-resource read alone (run 1579); reverted byte-identical, `ClassicPageGate` 5/5 (run 1580) and `NamespaceInteropGate` 4/4 (run 1581).
- The stale-record guard, run directly on `ocupilot-b-ci`: a fresh record was applied and forgotten; a record taken a day earlier was discarded unapplied, with its error, and nothing was left.
- The browser spec's still-running branch, with `NamespacePort`'s bound set to 2 s on the throwaway: the enable's task was left `Running` at the bound (14:31:24), the spec settled it as `_SYSTEM`, and `after`'s diff was empty (1/1); the bound was reverted byte-identical.
- Green after the patches: `NamespaceInteropGate` 4/4 (1571), `NamespaceInterop` 9/9 (1572), `ClassicPageGate` 5/5 (1573), `MappingWriteGate` 4/4 (1574), `ToolEmit` 11/11 (1575), `ToolRoundTrip` 2/2 (1576); `namespace-interop.browser-spec` 1/1 on the rebuilt bundle; `npm run test:tools` 1,759; `check-objectscript` 0; `lint-docs` 0.

**Rework iteration 1, 2026-10-01 (the language-server restore):**

- mutation: `InteropProbe.RestoreInstance` stops but no longer deletes a language server the record lacks, loaded on `ocupilot-b-ci` with `FHIR_Validation_Server` absent beforehand → `NamespaceInterop.OnAfterAllTests` red, `ERROR #5001`: `added ["languageserver|FHIR_Validation_Server|0"]` (run 1584); reverted byte-identical and reloaded, the server deleted by hand. Before the fix, with the definition removed, run 1582 reddened as CI did (`|1`). Green with the definition absent before each run: `NamespaceInterop` 9/9 (runs 1583, 1586), `NamespaceInteropGate` 4/4 (run 1585), `namespace-interop.browser-spec` 1/1.

## Auto Run Result

Status: done
Blocking condition: none

Rework iteration 1 (CI run 36869954798 on `be4b1baf`); the first pass's record is this section at `6500f96c`.

- **Changed:** `src/OcuPilot/Test/InteropProbe.cls` `RestoreInstance` stops, when it runs, and then deletes through `AdminPort` `LanguageServer` `DELETE` each language server the record lacks, by the exact name from the difference; a server the record holds is never deleted, and a record with no language-server line deletes none. The spec's stale Tasks text (:300-303), the two `angular.json` statements and the earlier review tally now state the delivered values. No product file changed.
- **Reproduced:** with the probe-left `FHIR_Validation_Server` definition (stopped) removed from `ocupilot-b-ci`, `NamespaceInterop` run 1582 reddened as CI did, `OnAfterAllTests` `added ["languageserver|FHIR_Validation_Server|1"] removed []`.
- **Verified, the definition absent before each run:** `NamespaceInterop` 9/9 (runs 1583, 1586), `NamespaceInteropGate` 4/4 (run 1585), `namespace-interop.browser-spec` 1/1 on a rebuilt, redeployed bundle; the mutation (DELETE dropped) red in run 1584, in `## Verification`; results read back from `^UnitTest.Result`; the loaded source equals the worktree's; `check-objectscript` 0, `lint-docs` 0. The full sweep was not re-run (Rule 29: no product file changed).
- **Review:** 17 findings, none patched, none newly deferred (one carried, `deferred` item 1), 16 rejected with reasons in the triage log.
- **Follow-up review recommended:** no (follow-up pass, no `high` patched).
- **Throwaway hygiene:** the two vendor async rows for `OcuGate1815All` (`817775471414144648964609` `Running`, `544506135165721633348099` `Failed`) deleted with `%Api.Admin.Util.AsyncTask.%DeleteId`; none remains for `OcuGate1815*`.
- **Throwaway at the end:** no `FHIR_Validation_Server` definition (`Config.Gateways.Exists` 0) and no Java process or listener; no `OCUPROBE1815*` namespace, gate user, `%HS_BFC_*` role, FHIR purge task or `SystemConfig*` node; `Admin`'s roles as before.
- **Residual risk:** stop-then-delete on a CI runner is measured only on `ocupilot-b-ci`.
