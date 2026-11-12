---
title: 'Story 20.25: Item runtime and configuration actions'
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

**Problem:** One item of a running production can be enabled, disabled and removed in OcuPilot (Story 20.3), but stopping it for a while, starting it again or restarting it still needs the classic per-host Actions tab. The vendor's `Ens.Director.TempStopConfigItem` checks no privilege, and it answers OK while doing nothing for a stopped production, a disabled item, and a start of an item that was never stopped (read in source, `Ens/Director.cls` :2468-2552).

**Approach:** Extend `Port/InteropPort` (AD-62) with a port-composed `ITEMRUN` read and three action-style writes on the Items endpoint: `STOPITEM`, `STARTITEM` and `RESTARTITEM`. Each is one tool reached by two callers (AD-53): a Production items row action and the agent's confirmed proposal. Each runs the vendor's temporary stop or start, then the capped production update the vendor requires, as the classic page does. The port refuses by name, before any vendor call, every target the vendor would answer as a silent success. Copy and change of class move to a split child (Design Notes › Split).

## Boundaries & Constraints

**Always:**

- Every action goes through `InteropPort.Invoke` behind the port's gate (AD-29, AD-62 (2)). The gate checks the Items endpoint's pairs, then `%Ens_ConfigItemRun:USE` (the classic `DoTempStopOneItem` check, `EnsPortal/ProductionConfig.cls` :6027-6045), then WRITE on the namespace's globals database. A refusal names its pair. The tools declare the same pairs, each refused by name before any port call (AD-8).
- They do not declare `%Ens_ProductionConfig:WRITE`, `%Ens_ProductionRun:USE` or routines WRITE: the production definition and class are not changed.
- Each write is action-style (AD-51) over `ITEMRUN`. Under the caller's per-target hold, the write re-reads and re-judges before any vendor call (AD-34, AD-62 (5)).
- The vendor calls are as follows. `ConfigName` is the vendor's `Production||Name`.
  - Stop: `TempStopConfigItem(ConfigName, 1, 0)`, then `UpdateProduction(min(update timeout, StopSeconds()), 0)`.
  - Start: the same, with `0` in place of `1`.
  - Restart: a stop and its update, then a start and its update, as the classic `restartMultiItems` and `restartMultiItemsPart2` do (:5925-6000).
- The update is the production's own update. It also applies any other change waiting for the production, and the consequence sentence says so.
- None of the three is destructive: each is undone by its inverse. Their keys ship `true` (AD-22), and a person's action shows its warning before it is sent (EXPERIENCE `confirm-dialog`).
- Audit is the vendor's own. `TempStopConfigItem` records `%Ensemble/%Production/ModifyConfiguration` (:2540-2550), and an agent write also carries the AD-15 marker. The port records no `ConfigChange` row of its own (Task 0 confirms).
- FR-80 holds: one descriptor and one port per screen, no new declared read, and every write a confirmed proposal for the agent. Edits to shared rosters are add-only.

**Never:**

- Never call `EnableConfigItem`, `RestartProduction`, `%Api.InteropEditors.*` or `TempStopConfigItem` with `pDoUpdate` 1. The last runs an uncapped update.
- Never write `^Ens.Runtime` or any other vendor global directly. The port only reads `^Ens.Runtime("ConfigItem",<name>,…)`, the expansion of `$$$ConfigTempStop`, `$$$ConfigRunAsJob` and `$$$ConfigPoolSize` (`Ensemble.inc` :146-151), because AD-62 (12) forbids the include.
- No copy, no change of class (split child), no multi-item restart, no new route, endpoint, entity type, declared read, page, dialog or navigation rule.
- No edit to `Screen/Tool/Write.cls`, `Screen/Tool/InteropItemRemove.cls`, `Api/Error.cls`, `Screen/Registry.cls`, `ui/src/app/core/navigation.ts`, `.github/workflows/ci.yml`, `ui/tools/ci-*.mjs` or `ui/tools/ci-timings.json`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Stop | `[Production, Name]` of an enabled item of the running production that runs jobs of its own | Its jobs end, `TemporarilyStopped` reads true and `NeedsUpdate` false. The item stays enabled | 409 `INTEROP.PRODUCTION.BUSY` when the update does not quiesce within the cap; the port then calls `TempStopConfigItem(…,0,0)` so nothing is left changed |
| Start | An item stopped with Stop | Its jobs run again, and `TemporarilyStopped` reads false | 409 `INTEROP.ITEM.STARTPENDING` when the update does not finish; the flag is cleared and the next update starts it |
| Restart | An enabled, running item | Its jobs end and start again, and `TemporarilyStopped` reads false | First half fails: `BUSY`, the flag is restored, nothing changed. Second half fails: `STARTPENDING` |
| Not running | The item's production is not the namespace's running one, or it is troubled | — | 409 `INTEROP.PRODUCTION.NOTRUNNING`, no vendor call |
| Disabled | An item whose effective `Enabled` is false (a system default included) | — | 409 `INTEROP.ITEM.NOTENABLED` |
| Already stopped | A stop or restart of an item whose flag is set | — | 409 `INTEROP.ITEM.TEMPSTOPPED` |
| Not stopped | A start of an item whose flag is not set | — | 409 `INTEROP.ITEM.NOTTEMPSTOPPED` |
| No jobs of its own | A stop or restart of an item for which `RunAsJob` or `PoolSize` reads 0: a pool-size-0 process, an in-process host, an adapterless service, an item its schedule stopped | — | 409 `INTEROP.ITEM.NOJOBS` |
| Name held twice | More than one item of the name | — | 409 `INTEROP.ITEM.AMBIGUOUS` |
| Unknown | No item of the name, or no such production | — | 404 `PORT.NOTFOUND`, unlogged |
| Gates | A caller missing one declared pair | Refused before any vendor call, flag untouched | 403 naming the pair |
| Namespace | A namespace that does not report interoperability | — | 409 `INTEROP.NAMESPACE` |

</intent-contract>

## Code Map

### Port and errors

- `src/OcuPilot/Port/InteropPort.cls` (7,655 lines):
  - Types :287-450 (`TYPEITEM` :308, item writes :310-316, `TYPESTOPJOB` :361). The new types must not reuse `STOP`, `START` or `RESTART`, because `IsWrite` :774 adds `%Ens_ProductionRun:USE` for those.
  - `ITEMCODEPREFIX` :666, `ENTITYITEM` :521, `STOPSECONDS` :283.
  - Pairs: `WRITEPAIRS` :250, `ITEMWRITEPAIRS` :256, `Pairs` :851 (:884-885 add the item pairs). The run pair joins as its own parameter.
  - Classifiers: `IsItemWrite` :780 (the new types stay out of it, so `Admit` :1097 asks no routines WRITE, :1110-1114), `IsRuntimeWrite` :795, `IsAnyWrite` :821.
  - `Serves` :901 (Items line :905), `Invoke` :1000 (Items → `InvokeItems` :1017-1019).
  - Item path: `InvokeItems` :1429 (composite split :1448, the 501 for a non-item action :1455-1458, `PerformItem` :1460).
    - `ItemRefusal` :1592 and `ItemRefusalToken` :1600, `ItemCode` :1640.
    - `GatherItems` :1655 (element: Name, ClassName, Type, Enabled, EnabledSource, PoolSize, …), `ItemRow` :1702, `ReadItem` :1746, `ResolveItem` :2832.
  - Production state: `ReadState` :1295 (facts `word`, `current`, `needsUpdate`, quick-lock retry :1324-1331), `Perform` :1368 (the capped update :1381-1384), `LiveCurrent` :2847, `RunningProduction` :3870.
  - Jobs: `GatherJobs` (host-scoped job rows, beside `ReadItemStatus`).
  - Mappers: `Statused` :2624 (BUSY), `Mapped` :2651, `LogFault` :2671, `Conflict` :2694, `Absent` :2707, `Unavailable` :2716.
  - Action template: `PerformJobAction` :4984 (read, refuse, vendor call, read again). Item writes call no `AuditRuntime` :5020.
  - Copy-out draft (AD-59): `Snippet` :5057 (items :5062), `ItemSnippet` :5140 (the enable branch :5148).
- `src/OcuPilot/Api/InteropError.cls` (680 lines): item codes :91-155, `Codes` :466, `ConsequenceCodes` :472, `ItemCodes` :478, `PreconditionCodes` :583. Reused: `NOTRUNNING` :35, `BUSY` :51, `AMBIGUOUS`.

### Tools, screen and kernel

- `Screen/Tool/InteropItemAction.cls`:
  - `DESCRIPTORCLASS` `InteropItemList` :24, `READTYPE` `ITEM` :27, `ROUTINESDATABASE` 1 :33, `STATEMARKER` :36, `CONSEQUENCECODE` :42, `MintClass` `InteropItemMint` :50, `TargetName`.
  - Its parent `InteropAction` holds `WRITERESOURCE`/`WRITEPERMISSION` :41, `ROUTINESDATABASE` :51 and `PrivilegePairs` :89.
- Leaf precedents:
  - `InteropItemEnable.cls`: parameters :12-32.
  - `InteropJobStop.cls`: `AFTERWORD`, the consequence of a non-destructive runtime action.
  - `InteropProductionRestart.cls`: preconditions over a state word.
- `Screen/Descriptor/InteropItemList.cls`: route `interoperability/productions/items` :30, entity `production-item` :40, `rowActions` enable, disable, remove :46.
- `Kernel/Governance/Baseline.cls`: `interop.*` :220-248 (items :225-228). Add-only, keeping the last-line comma rule.
- `Kernel/Proposal/Prohibited.cls`: `production-item` is in `COVEREDTYPES` :282, and its change branch :1751-1754 (`ReviewedFewOnly`) carries the new write types unchanged (inference; the `Prohibited` class run confirms it).

### Client

- `ui/src/app/shell/screen-action-handler.ts`:
  - `SCREEN_ACTION_DESCRIPTORS` (InteropItemList :132), `WARNING_CONSEQUENCES` :730 (item enable and disable :767-770).
  - `DESTRUCTIVE_ACTIONS` :534 is verb-keyed and gains nothing.
- `ui/src/app/core/screen-actions.ts`: `ACTION_LABELS` already holds `start` :139, `stop` :140 and `restart` :142.
- `ui/src/app/core/proposal-view.ts`: consequence constants :378-390, `consequenceSentence` :452 (item pending :545).
- `ui/src/app/core/strings.ts`: item block :6709-6871 (refusals :6745-6765). New keys are appended to it.
- EXPERIENCE.md :173 is the Dialogs line's warning list. :604 is the Fixed-strings row; its clauses are appended, and no line is inserted above it.

### Tests and fixture

- Item classes, armed by `OCUPILOT_ALLOW_PRINCIPALS`:
  - `InteropItemControl`: HTTP confirm and screen-action precedent.
  - `InteropItemGate`, `InteropItemGateSplit`, `InteropItemRefusals`, `InteropItemDescriptor`.
  - `InteropItemSeam` (`Arm` :17, `Disarm` :25) extends `InteropGateSeam` (`StopSeconds`).
- Runtime siblings: `InteropJobStop`, `InteropControl`.
- `Test/ProductionProbe.cls`: `Create` :163, `AddItem` :203, `AddRetryItem` :236, `Send` :360, `Settle` :465, the hang helper, `Gone` :759, `Remove` :779.
- `scripts/ci-throwaway.sh`: the item `# classes:` lines :480/:484.
- Browser: `ui/browser/interop-items.browser-spec.mjs` (enable and disable :238-274).
- `ui/tools/interop.test.mjs`: `SENTENCES` and the `STOPSECONDS` pin list.
- Rosters this story moves (Rule 30):

| File | Anchor | What |
|---|---|---|
| `Test/ReadTool.cls` | :93 | registry count 406 → 409, sorted names |
| `Test/ToolWrite.cls` | :1326 | other-port writes 53 → 56 (DW-2407) |
| `Test/ToolRoundTrip.cls` | :100 | `REFUSEEMPTY` rows for the three tools |
| `Test/SurfaceCoverage.cls` | :421-449 | three coverage rows |
| `Test/ToolEmit.cls` | :243-253 | a run-action branch ahead of the `InteropItemAction` branch: run pair plus globals, no ConfigWRITE, no routines |
| `Test/GovernanceBaseline.cls` | :15/:71 | baseline line order (no disabled key added) |
| `Test/InteropItemDescriptor.cls` | — | the Production items row actions |

## Tasks & Acceptance

**Execution:**

- [ ] **Task 0, measure on `ocupilot-b-ci` (USER, auditing on, a probe production).** Record each result under Design Notes › Measured.
  - (a) Stop and start each record `ModifyConfiguration`, and what `UpdateProduction` records beside it.
  - (b) What `RunAsJob`, `PoolSize` and the flag read for a Queue operation, the probe's service, a pool-size-0 process and an `InProc` host, before and after a stop with its update.
  - (c) A principal holding only the Items screen pairs, `%Ens_ConfigItemRun:USE` and globals WRITE can stop, start and update. A principal without the run pair can still call `TempStopConfigItem`, so the port's gate is the whole gate.
  - (d) With a probe job hung past the cap, the stop's update answers BUSY, and the restore leaves the jobs running and `NeedsUpdate` false.
  - (e) Whether the jobs run by the time a start's update returns.
  - (f) A restart's wall time (inference: under 40 s, below the gateway's 60 s).
  - A result that changes a destructiveness call, a key default, the audit choice or the pairs is `## Clarification Needed`. Anything else is adjusted within this intent and recorded.
- [ ] `src/OcuPilot/Port/InteropPort.cls`:
  - Add `TYPEITEMRUN` `ITEMRUN`, `TYPESTOPITEM`, `TYPESTARTITEM` and `TYPERESTARTITEM`, `IsItemRunWrite`, and `ITEMRUNPAIR` `%Ens_ConfigItemRun:USE`, joined in `Pairs`. Add them to `Serves`' Items line and `IsAnyWrite`, and keep them out of `IsItemWrite`.
  - In `InvokeItems`, route `ITEMRUN` and the three writes to `ReadItemRun` and `PerformItemRun` instead of the 501.
  - `ReadItemRun` answers `Production, Name, ClassName, Enabled, EnabledSource, Count, State, Current, TemporarilyStopped, OwnJobs, Jobs, NeedsUpdate, Namespace`. It uses `GatherItems`, `ReadState`'s facts, the read-only `^Ens.Runtime` nodes and `GatherJobs`' count.
  - Pure `ItemRunRefusal(pType, pCount, pRunning, pEnabled, pTempStopped, pOwnJobs)` answers tokens in the Matrix order: NOTRUNNING, AMBIGUOUS, NOTENABLED, then TEMPSTOPPED and NOJOBS for a stop or restart, or NOTTEMPSTOPPED for a start.
  - `PerformItemRun` re-reads and re-judges, then makes the vendor calls of Boundaries. It restores the flag or answers `STARTPENDING` as the Matrix says, maps the vendor's errors through `Statused` and `Mapped`, and reads `ITEMRUN` back (AD-58). Only vendor classes and this class run while switched.
  - Add `ItemSnippet` branches for the three types (AD-59), and refresh the header doc and the `InvokeItems` doc.
  - Rule 31: `ItemRunRefusal` sits beside `ItemRefusalToken` because its inputs are runtime facts. The update reuses `Perform`'s cap shape, and the action shape follows `PerformJobAction`.
- [ ] `src/OcuPilot/Api/InteropError.cls`: add item codes `NOTENABLED`, `TEMPSTOPPED`, `NOTTEMPSTOPPED`, `NOJOBS` and `STARTPENDING`, and consequence codes `INTEROP.ITEM.STOP`, `INTEROP.ITEM.START` and `INTEROP.ITEM.RESTART`, each in `Codes`, `ConsequenceCodes`, `ItemCodes` and `ReasonFor`.
- [ ] `src/OcuPilot/Screen/Tool/InteropItemRunAction.cls` (new, abstract, extends `InteropItemAction`):
  - `WRITERESOURCE` `%Ens_ConfigItemRun`, `WRITEPERMISSION` `USE`, `ROUTINESDATABASE` 0.
  - `READTYPE` `ITEMRUN`, `READANSWERS` as above, `STATEMARKER` and `STATEFIELD` `TemporarilyStopped`.
  - `FINGERPRINTSUBJECT` `State,Enabled,TemporarilyStopped,OwnJobs,NeedsUpdate,Namespace`, and `PRECONDITIONFIELD` `TemporarilyStopped`.
  - It declares no `CLASSICPAGES`, like its parent.
- [ ] `src/OcuPilot/Screen/Tool/InteropItemStop.cls`, `InteropItemStart.cls`, `InteropItemRestart.cls` (new):
  - `interop.items.stop`, `.start`, `.restart`; `SCREENACTIONS` `stop`, `start`, `restart`; `WRITETYPE` `STOPITEM`, `STARTITEM`, `RESTARTITEM`; their consequence codes.
  - `PRECONDITIONCODES` listing the Matrix codes each can answer.
  - A `DESCRIPTION` in the siblings' plain words. Agent-facing, decided at implement.
  - `AFTERWORD` and `CHANGEACTION` `updated` as `InteropJobStop` sets them.
- [ ] `src/OcuPilot/Screen/Descriptor/InteropItemList.cls`: `rowActions` gains stop, start and restart after disable, keeping remove last.
- [ ] `src/OcuPilot/Kernel/Governance/Baseline.cls`: append the three keys, `true`.
- [ ] `ui/src/app/shell/screen-action-handler.ts`, `ui/src/app/core/proposal-view.ts`, `ui/src/app/core/strings.ts`: `WARNING_CONSEQUENCES` entries for InteropItemList stop, start and restart; the three consequence constants and their sentences; and the eight new strings, appended.
- [ ] `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`: the strings the runner rules on, as a clause appended to :604's row. The three warnings join :173's warning list. Then run `npm run test:tools`.
- [ ] `src/OcuPilot/Test/ProductionProbe.cls`: if Task 0 (b) finds no probe item that reads `OwnJobs` 0, add one by extending `AddItem`.
- [ ] `src/OcuPilot/Test/InteropItemRun.cls` (new, armed): legs for every Matrix row through the HTTP confirm and the screen-action route, each on its own probe production created and removed in the test.
  - The vendor audit row of a stop names the item.
  - The BUSY leg uses the probe's hang, with `InteropItemSeam`/`InteropGateSeam` shortening the cap.
- [ ] `src/OcuPilot/Test/InteropItemRunGate.cls` (new, armed): reuses `InteropItemGate`'s principal generator and covers each declared pair's 403. A run-pair holder without `%Ens_ProductionRun` or `%Ens_ProductionConfig:WRITE` is admitted.
- [ ] `scripts/ci-throwaway.sh`: a `# classes:` line for the two new classes.
- [ ] The rosters in the Code Map table, plus `InteropItemDescriptor`. Then sweep `src/OcuPilot/Test`, `ui/browser`, `ui/tools` and the `ui/src` specs for the old shape of each.
- [ ] `ui/browser/interop-items.browser-spec.mjs`: on the deployed bundle, Stop and then Start one probe item through the row actions. Assert each warning's sentence, the confirm, and the item's Jobs tab reading no job and then a job.
- [ ] `ui/tools/interop.test.mjs`: the three consequence sentences and `STARTPENDING` join `SENTENCES` and the `STOPSECONDS` pin list.

**Acceptance Criteria:**

- AC1: Given an enabled item of the running production, when a stop, a start or a restart is proposed by the agent and confirmed, or chosen as a row action and confirmed, then it runs through `InteropPort` as a confirmed write over a fresh `ITEMRUN` read, followed by the capped production update, and the read-back reports the state the Matrix states.
- AC2: Given a target the vendor would answer as a silent success (a stopped production, a disabled item, a start of an item not stopped), or any other Matrix refusal, when the action is confirmed, then it is refused by its code before any vendor call, and the flag and the production are unchanged.
- AC3 (Integration): given a confirmed stop and then a start, when the item's Jobs tab (Story 20.4's `ItemJobs` read) is read through its screen, then it lists no job after the stop and at least one after the start.
- AC4: Given each action, when its tool, governance key and the audit after a confirmed run are inspected, then its destructiveness (none), its key's default (`true`) and its audit record (the vendor's `ModifyConfiguration`, plus the marker for an agent write) are as stated in Design Notes, and Task 0's measurements are recorded there (AD-22).
- AC5: Given a caller missing one declared pair, when it acts by either caller, then it is refused 403 naming that pair before any port or vendor call.
- AC6 (DW-2407): Given the three new tools, when `Test/ToolWrite` runs, then its other-port write count reads 56, exactly three above today's 53.

## Spec Change Log

- 2026-11-12, spec gate (runner): copy and change of class chartered as Story 20.40 (split); the eight new strings are veto item U-22; the spine drafts are kept for the owner's Update, not written.

## Review Triage Log

## Design Notes

**Governing ADs:** AD-7, AD-8, AD-10, AD-13, AD-14, AD-15, AD-16, AD-22, AD-29, AD-34, AD-51, AD-52, AD-53, AD-58, AD-59, AD-62. Checked with nothing to add:

- AD-21 and AD-27: there is no path and no `%Api.*` call.
- AD-44: no `CLASSICPAGES`, as the item siblings declare none for the same page.
- AD-54: no create (that is the split child's).
- AD-36: no declared read.

**Measured or read at this plan** (read-only; this plan did not use the throwaway):

- On `ocupilot-slot-b`, `%Ensemble/%Production/ModifyConfiguration` and `StartStop` read `Enabled` 1. `%Ens_ConfigItemRun` exists, with public permission 0.
- From the source:
  - `TempStopConfigItem` answers OK for a production that is not running, and for a disabled item (:2476-2479, :2506-2509). A start of an item that was never stopped kills an absent node and answers OK.
  - It answers an error for a pool-size-0 process and for an item without `RunAsJob` and `PoolSize`. It audits through `AuditModifyProductionConfig`, and with `pDoUpdate` 1 it runs an uncapped update (:2552).
  - The classic page needs `%Ens_ConfigItemRun:USE` and globals WRITE for the stop and start (:6027-6045). Its follow-up update admits `RunItem` (:6146-6151). It checks no source control for them, unlike enable, so this story refuses no namespace under source control.
  - Classic restart is stop, update, start, update (:5925-6000, :6925-6930).

**Decisions (AD-22):**

| Action | Tool and key | Destructive | Audit record |
|---|---|---|---|
| Stop one item | `interop.items.stop`, `true` | no: Start undoes it, messages wait in the queue, and a production restart clears it | vendor `ModifyConfiguration` ("item temporary stop by …"), plus the marker |
| Start one item | `interop.items.start`, `true` | no | vendor `ModifyConfiguration` ("restarted after temporary stop"), plus the marker |
| Restart one item | `interop.items.restart`, `true` | no | two vendor rows, plus the marker |

- **Pairs.** The pairs are the classic page's own, so the posture is equal to the classic portal's, not looser (inference until Task 0 (c)). No question remains for the orchestrator.
- **A failed update.** A stop or a restart's first half calls `TempStopConfigItem(…,0,0)` to clear the flag it set, and the vendor records a second row. That is the honest record of the flag cleared. A failed start cannot be undone, since the vendor refuses a stop on an item not running, so it answers `STARTPENDING`.
- **Prohibited.** AD-10 names no effect on a production item, and OcuPilot runs no production. The existing `production-item` branch carries the three types.

**Decided in-stage:**

- The epic context predates today's epics.md and EXPERIENCE.md edits. The dispatch said not to recompile it, so this plan read the story block and the strings directly.
- Row actions go on Production items only, not on the Status tab. `ToolFor` matches one tool per descriptor, and the list is the item's actions home since Story 20.3.
- No declared read gains a "temporarily stopped" field, which keeps 23.12's `ReadDescriptions` roster unchanged. The Jobs tab's empty state shows a stopped item. This is a named limit.
- The labels Start, Stop and Restart are reused from `ACTION_LABELS`.

**Split (the runner charters it; it moves an AC, so the runner classifies it).** Copy and change of class move to a new Story 20.40, "Item copy and change of class", planned next in this epic. Each needs input the three runtime actions do not:

- **Copy** needs a new-name dialog. It is an AD-54 create.
- **Change of class** needs a class picker over the host type's classes (`Ens.ContextSearch/BusinessServices`, `BusinessProcesses` or `BusinessOperations`), which is a new read tool under `ReadDescriptions`. It also drops every setting the new class does not declare, which cannot be undone, so it is destructive and its key ships `false` (recommendation).

Together they would take this story past five actions, each with its own refusals. The charter, read in source:

- Copy: `CopyConfigItem` (:6265-6302) refuses a held name, `%ConstructClone(1)`, `Enabled` 0, a pool-size-0 process gets pool size 1, `InsertItem`, then `SaveToClass` and `AuditModifyProductionConfig` "added … via copy".
- Change class: `HostChangeClass` (:7702-7760) removes the host and adapter settings the new class does not declare or validate, saves the item, then `SaveToClass` and `AuditModifyProductionConfig` "class changed … from X to Y".
- Both take `%Ens_ProductionConfig:WRITE`, globals and routines WRITE and the source-control refusal, on `InteropItemAction`. The second AC carries over verbatim.

**New strings for the runner** (proposed wording; the runner rules on each):

- `INTEROP.ITEM.STOP`, the warning and card: "Stopping this item ends its jobs until it is started again, and updates the production now to apply it, along with any other change waiting for it. Messages sent to the item wait in its queue. The item stays enabled, and the stop ends when the production next restarts. If its jobs do not finish their current messages within 15 seconds, nothing is changed."
- `INTEROP.ITEM.START`: "Starting this item starts its jobs again, and updates the production now to apply it, along with any other change waiting for it."
- `INTEROP.ITEM.RESTART`: "Restarting this item stops its jobs and starts them again, updating the production twice, which also applies any other change waiting for it. If its jobs do not finish their current messages within 15 seconds, nothing is changed."
- `INTEROP.ITEM.NOTENABLED`: "This item is disabled, so it is not running. Enable it instead."
- `INTEROP.ITEM.TEMPSTOPPED`: "This item is already stopped. Start it to run it again."
- `INTEROP.ITEM.NOTTEMPSTOPPED`: "This item has not been stopped with Stop, so there is nothing to start."
- `INTEROP.ITEM.NOJOBS`: "This item runs no jobs of its own now, so it cannot be stopped by itself. That is so for an item that runs in its callers' jobs or in the shared actor pool, and for one its schedule has stopped."
- `INTEROP.ITEM.STARTPENDING`: "The production's work in progress did not finish within 15 seconds, so the item starts only when the production is next updated on Productions."

**Spine drafts (runner ruling at the spec gate, 2026-11-12):** both extend a Rule to a case it does not address, and both ADs are cited by done stories, so no AD is amended in this run (U7(c); the orchestrator's ruling on 20.36). The story complies as the ADs stand, and the two lines are kept here for the owner's attended `bmad-architecture` Update:

- **AD-62 (18):** "Story 20.25: `InteropPort` gains `ITEMRUN`, `STOPITEM`, `STARTITEM` and `RESTARTITEM` on Items. Each is action-style and calls `Ens.Director.TempStopConfigItem` with no update, then the production's update capped at 15 s; a restart does that twice, as the classic page does.
  - Before any vendor call, the port refuses by name a production that is not running, a disabled item, a start of an item not stopped, and a stop of an item running no jobs of its own (read in source: the vendor answers OK for the first three).
  - A stop whose update is refused clears its flag again.
  - The pairs are `%Ens_ConfigItemRun:USE` and globals WRITE, never `%Ens_ProductionRun:USE`. None is destructive, and the vendor audits each."
- **AD-22:** "Story 20.25's keys `interop.items.stop`, `.start` and `.restart` ship `true`."

**Integration ACs, Consumes, Consumed-by:**

- Integration: AC3. Consumer `InteropItemJobTab` (20.4) reads the change against `ocupilot-b-ci`.
- Consumes:
  - 20.3: `InteropItemAction`, `InteropItemMint`, Production items, `GatherItems`.
  - 20.2: `Perform`'s cap, `Statused`, `ReadState`.
  - 20.4: `GatherJobs` and the Jobs tab.
  - 20.23: the `PerformJobAction` shape.
  - `Test/ProductionProbe`.
- Consumed-by:
  - Story 20.40 (the split), which extends `InteropItemAction` beside `InteropItemRunAction`.
  - 20.12/20.36 workflows that unblock an item (inference).

**Ledger inbox (Rule 17):**

- DW-2298 is addressed in part: the temporary stop, start and restart are this story's (AC1-AC4). Copy and change class go with the split. The runner re-owns the residual to 20.40 when it charters it.
- DW-2407 is addressed: AC6, and the `Shared surfaces:` line names the count.

**Contended (Epic 23, checked 2026-11-12).** 23.9 changes `Screen/Tool/Write.cls` and `InteropItemRemove.cls`, uncommitted. Its committed diff also changes `Api/Error.cls`, `ui/tools/ci-runner.mjs`, `ci-shards.mjs`, `ci.test.mjs` and `epics.md`. This story edits none of them. `epics.md` takes only the runner's split charter, add-only. If 23.9 lands a shared state-diff in `Write.cls` first, the new tools use it rather than a copy (inference).

## Verification

**Shared surfaces:**

- the Production items row actions
- the write-tool rosters: `ReadTool` 406 → 409, `ToolWrite`'s other-port count 53 → 56 (DW-2407), `ToolRoundTrip`, `SurfaceCoverage`, `ToolEmit`
- the governance baseline
- `InteropPort`'s `Serves`/`Pairs`
- the probe production
- `WARNING_CONSEQUENCES`, the Fixed-strings row and the Dialogs line

*Every test added or changed passes on a fresh environment, in either order.*

**Setup (slot B, the implement stage only):** follow common.md's load and redeploy recipes, targeting `ocupilot-b-ci`. The dev instance `ocupilot-slot-b` is for read-only SQL only.

**Commands** (each sized to about 150 s, one class or spec file per call, `timeout: 600000`):

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one class per call, with totals read from `%UnitTest_Result`:
  - new: `InteropItemRun`, `InteropItemRunGate`
  - the item classes: `InteropItemControl`, `InteropItemGate`, `InteropItemGateSplit`, `InteropItemRefusals`, `InteropItemIdentity`, `InteropItemDescriptor`, `InteropHostRead`, `InteropJobStop`, `InteropControl`
  - the rosters: `ReadTool`, `ToolWrite`, `ToolRoundTrip`, `ToolEmit`, `SurfaceCoverage`, `EndpointCoverage`, `GovernanceBaseline`, `Governance`, `ToolDispatch`, `Prohibited`, `ReadDescriptions`, `Descriptor`, and every class the sweep changes
- `(loop)` `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/interop-items.browser-spec.mjs`, on the redeployed bundle.
- `(loop)` `cd ui && npm run test:tools` and, as a separate call, `cd ui && npm run test:components`. Both pass, `name-links.test.mjs` included.
- `(loop)` `cd ui && npm run build`: it passes, with client-lint family 7 clean (no new template class) and the bundle under the fixed 2,500 kB warning.
- `(loop)` `uv run scripts/check-objectscript.py <changed .cls>` and `bash scripts/lint-docs.sh`, both clean.
- Left to the runner: the full ObjectScript sweep, `npm test`, the smoke and Rule 30's fresh check. Left to CI: the full browser suite.

**Planned pinning mutations (Rule 19):**

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | `PerformItemRun` skips the update | the stop leg (jobs still running) |
| AC1 | Restart omits its second half | the restart leg (flag left set) |
| AC2 | `ItemRunRefusal` drops `NOTRUNNING` | the stopped-production leg (the vendor's silent OK) |
| AC2 | `ItemRunRefusal` drops `NOTTEMPSTOPPED` | the start-not-stopped leg |
| AC2 | The BUSY path skips the flag restore | the hung-job leg (`TemporarilyStopped` reads true) |
| AC5 | `Pairs` drops `ITEMRUNPAIR` | `InteropItemRunGate`'s run-pair leg |
| AC3 | The browser spec's Stop sends `start` | the Jobs-tab assertion |

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
