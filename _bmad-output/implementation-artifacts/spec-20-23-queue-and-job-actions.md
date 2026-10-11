---
title: 'Story 20.23: Queue and job actions'
type: 'feature'
created: '2026-10-11'
status: 'done'
review_loop_iteration: 0
baseline_revision: '31c995977f969a043d44e340b61c5e2742c0a360'
baseline_commit: '31c995977f969a043d44e340b61c5e2742c0a360'
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
warnings: [oversized, multiple-goals]
deferred: []
---

<intent-contract>

## Intent

**Problem:** Story 20.4 shipped the Queues, Queue messages, Jobs screens and an item's Queue and Jobs tabs as reads only. Unblocking a stuck production (aborting a queued message, a whole queue or a job's retried message, suspending that message, stopping a job) still means the classic portal. The vendor's methods check little, audit nothing, and two of them answer OK on a target where they do nothing (DW-2297).

**Approach:** Extend `Port/InteropPort` (AD-62) with three port-composed fresh reads (`QUEUE`, `ENTRY`, `JOB`) and five action-style writes. Each write is one tool reached by two callers (AD-53): a row action on its screen and the agent's confirmed proposal. The port refuses by name, before any vendor call, every target the vendor would answer as a silent success, and records OcuPilot's own audit row from either caller, because the vendor records none.

## Boundaries & Constraints

**Always:**

- Every action goes through `InteropPort.Invoke` behind the port's gate (AD-29, AD-62 (2)): the endpoint's pairs, then the action's own pair (the vendor's own check), then WRITE on the namespace's globals database. Each refusal names its pair. The tool declares the same pairs, each refused by name before any port call (AD-8).
- Each write is action-style (AD-51) over its port-composed read, composed for the action at the mint and at a screen action (`READSVALUES`, `PortQuery`). The write re-reads and re-judges under the caller's per-target hold before the vendor call (AD-34, AD-62 (5)).
- The three aborts are destructive: `DESTRUCTIVE` 1, their governance keys ship `false`, and a person's abort uses the typed-name confirm dialog. Suspend and stop are not destructive: keys ship `true`, and each warns first (AD-22, EXPERIENCE `confirm-dialog`).
- After every vendor call that read OK, the port records `OcuPilot/<Type>/ConfigChange` through `Kernel/Audit/Event.Record`, from either caller. The row names the action, the target and the namespace, and never message content. A failed record never fails the write (AD-15).
- A stop passes the running production's update timeout, capped at `StopSeconds()` (15 s, AD-62 (6)), and forces, as the classic Jobs page does.
- FR-80 holds: one descriptor and one port per screen, derived read tools unchanged, and every write a confirmed proposal for the agent. Edits to shared files are add-only (Design Notes › Contended files).

**Never:**

- Never call `Ens.Queue.AbortQueue` (Design Notes › Abort all), `Ens.Job.Enumerate`, `MarkDeadJobs`, `StopJobs`, `StopAll`, `%Api.InteropEditors.*`, or `CleanProduction`. Never write `^Ens.JobRequest` or any other vendor global directly.
- No temporary stop, start, restart, change class or copy of an item (DW-2298, declined). No message body, contents or resend (Story 20.9). No Abort all on an item's Queue tab.
- No new route, port, entity type, read endpoint, side-bar entry or navigation rule. No edit to `Screen/Registry.cls`, `ui/src/app/core/navigation.ts`, `.github/workflows/ci.yml`, `ui/tools/ci-shards.mjs`, `ui/tools/ci-timings.json` or `ui/tools/ci.test.mjs`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Abort one message | `MessageId` of a message waiting in a queue | Its entry leaves the queue and its header reads Aborted. The queue's other entries stay. A synchronous caller waiting on it is answered with an error (vendor) | 404 `PORT.NOTFOUND`, unlogged, for a header that is gone or no longer waiting in the queue its header names |
| Abort one, shared actor queue | A message to a pool-size-0 business process, waiting in `Ens.Actor` | Found and aborted in `Ens.Actor` (its header's `TargetQueueName`) | as above |
| Abort all | Queue `Name` with N waiting entries | Exactly the entries its read enumerated (at most `ABORTMAX`) are aborted, one `AbortItem` each. A message a job is already working on, and one enqueued after the read, stay | 409 `INTEROP.QUEUE.EMPTY` when none waits; 409 `INTEROP.QUEUE.CHANGED` at the write when the entries differ from the reviewed digest, nothing aborted; 404 for an unknown queue |
| Abort or suspend a job's message | `Job` (pid) of a live job reading `Status` `Retry` with an `ActiveMessage` | The request is set. The message reads Aborted or Suspended when the job's current retry wait ends | 409 `INTEROP.JOB.NOTRETRYING` otherwise; 409 `INTEROP.JOB.DEAD` for a job no process holds. No request is left for the job |
| Stop a job | `Job` of a live job of the running production | `Ens.Job.Stop(pid, min(update timeout, 15), 1)`. The job's row leaves Jobs and the production reads update pending. If the job had to be forced, its active message is back on its queue and its host reads Error | 409 `INTEROP.JOB.DEAD`; 409 `INTEROP.JOB.NOTSTOPPED` for the vendor's `ErrJobNotStopped`; 503 `PORT.UNAVAILABLE` for the vendor's job locks |
| Not a job | A pid that no job of the running production holds | — | 404 `PORT.NOTFOUND`, unlogged; 409 `INTEROP.PRODUCTION.NOTRUNNING` when the namespace has no running or troubled production |
| Gates | A caller missing one declared pair | Refused before any vendor call | 403 naming the pair |
| Namespace | A namespace that does not report interoperability | Refused | 409 `INTEROP.NAMESPACE` |

</intent-contract>

## Code Map

### Port and errors

- `src/OcuPilot/Port/InteropPort.cls` (2884 lines):
  - The header doc (:1-42, which says the port calls no queue or job action, :5) and `InvokeRuntime`'s doc (:2133-2141) change with the contract.
  - `ENDPOINTS` :52 stays unchanged, so the screen mirror needs no edit. `QUEUEPAIRS` :113, `JOBPAIRS` :116, `WRITEPAIRS` :131, `STOPSECONDS` :152, `QUEUESCANMAX` :217.
  - Type predicates: `IsWrite` :328, `IsItemWrite` :334, `IsSettingWrite` :341. `IsWrite` is endpoint-agnostic and `Pairs` :388 adds `%Ens_ProductionRun:USE` for its types, so the new write types must not reuse `STOP` or any other production type.
  - `RuntimeEndpoints` :347, `Pairs` :365, `Serves` :394 (runtime endpoints serve `LIST` only today, :400), `Invoke` :484 (runtime dispatch :509; the action-key check :535-539 is the production path's), `Admit` :567 (`tWrite` :571).
  - `Perform` :773: the timeout-cap shape for update, :787-789.
  - `Statused` :2027 maps `ErrJobNotStopped` to the production's `BUSY` (:2029). The job path maps that code itself and does not change this method.
  - Refusal helpers: `Mapped` :2054, `Conflict` :2097, `Absent` :2110, `Unavailable` :2119, `Fail` :2125.
  - Runtime reads: `InvokeRuntime` :2142, `LiveCurrent` :2218, `GatherJobs` :2346 (host loop :2373), `JobRow` :2399 (`Dead` = `'$Data(^$JOB(pid))`), `ListQueues` :2440, `GatherQueueEntries` :2541, `QueueEntryRow` :2594.
  - Scripts: `SnippetForm` :2756, `Snippet` :2775, `Literal` :2875.
- `src/OcuPilot/Api/InteropError.cls` (293 lines): `Codes` :202, `ConsequenceCodes` :208, `PreconditionCodes` :245, `ReasonFor` :252. `Api/Error.cls` is at the parameter limit and is not edited.
- `src/OcuPilot/Kernel/Audit/Event.cls`:
  - `Record(pVerb, pType, pId, pChanges, pSecurityChange, pEffects)` :194 writes `OcuPilot/<Type>/ConfigChange` from the install namespace and never throws.
  - `Port/ScreenAccessPort.cls` `Audit` :386-399 is the precedent for a port recording its own row.
- `src/OcuPilot/Kernel/Proposal/Operation.cls` `Query` :257 composes the port's query through the tool's `PortQuery` for the read and for the write (`ApplyAt` :476-480). That is how the queue abort's write receives the reviewed digest.

### Tools

- `Screen/Tool/InteropAction.cls` (139 lines) is the parent. It holds `PORTCLASS`, `READSVALUES` 1, `SENDSBODY` 0, `NAMESPACEFIELD`, `WRITERESOURCE`/`WRITEPERMISSION`, `DATABASEPERMISSION`, `STATEMARKER`, `CONSEQUENCECODE`, `IdArgument`, `PrivilegePairs` (screen pairs, own pair, globals WRITE, `WithClassicPages`) and `PortQuery` (the action key when the marker is absent, then the namespace).
- `InteropProductionAction.cls`/`InteropProductionStop.cls` are the action-style precedent: `READTYPE`, `READANSWERS`, `STATEFIELD`, `PRECONDITIONFIELD`, `FINGERPRINTSUBJECT`, `AFTERWORD`, `StateDiff`, `InputSchema`. `InteropItemRemove.cls` is the destructive precedent (`DESTRUCTIVE` 1, literal `PRECONDITIONCODES`).
- `Screen/Tool/Write.cls` parameters: `DESTRUCTIVE` :52, `READTYPE` :57, `WRITETYPE` :62, `STATEFIELD` :75, `FINGERPRINTSUBJECT` :97 (validated by `Screen/Registry.FingerprintSubjectProblem` at listing), `PRECONDITIONFIELD` :105, `CLASSICPAGES` :124, `CHANGEACTION` :134, `SCREENACTIONS` :167, `READSVALUES` :176, `READANSWERS` :189, `PRECONDITIONCODES` :508.
- `Api/ScreenAction.cls`:
  - `Resolve` :140 needs the action among the descriptor's `RowActionIds` and a tool.
  - `ToolFor` :588 matches one tool per descriptor (`DESCRIPTORCLASS`). That is why each tab posts to its list's route.
  - `Run` :221 holds the target, reads, gates and writes.

### Screens and kernel

- Descriptors (20.4's), each `rowActions: []` with the read-only empty state today:
  - `InteropQueueList.cls` (:28, :53-54)
  - `InteropQueueMessageList.cls` (id = `MessageId`, its `name` column)
  - `InteropItemQueueTab.cls` (:30, :62-63)
  - `InteropJobList.cls` (id = `Job`; `rowTarget` to Process details)
  - `InteropItemJobTab.cls` (:30, :61-62)
  - The row key is the `name` column's field (`ui/src/app/core/table-model.ts` `rowKey` :40).
  - `Screen/Registry.cls` `TableProblem` :2690-2700: a screen with a row action needs `emptyAgentKey` set and `emptyNextKey` empty. `ProcessDetails.cls` :68/:133 shows a detail screen re-declaring its list's actions and reusing the list's agent empty state.
- `Kernel/EntityType.cls` `TYPES` :115 already holds `interop-queue`, `interop-message` and `interop-job`, so it is not edited.
- `Kernel/Proposal/Prohibited.cls`:
  - `COVEREDTYPES` :259 lacks the three types, so any write to them is `UNCOVERED` today.
  - Type constants :649-659, the branch chain :1344, the production branches :1621-1636, `ReviewedFewOnly` :4121.
- `Kernel/Governance/Baseline.cls` :217-227 holds the `interop.*` keys; the last line has no trailing comma.

### Client

- `ui/src/app/shell/screen-action-handler.ts`:
  - `SCREEN_ACTION_DESCRIPTORS` :67-129 and `ACTION_ADDRESS` :426 (`ProcessDetails` → `ProcessList`).
  - `DESTRUCTIVE_ACTIONS` :438 is verb-keyed, and `abort` is not in it.
  - `DESTRUCTIVE_CONSEQUENCES` :466, `TYPED_NAME_ROWS` :552, `WARNING_CONSEQUENCES` :606-649.
  - `send` :1306-1330 posts to `ACTION_ADDRESS`'s route.
- `ui/src/app/core/screen-actions.ts`: `ACTION_LABELS` :112-145 has `suspend` and `stop` but no `abort`. `DESCRIPTOR_ACTION_LABELS` is at :155.
- `ui/src/app/core/proposal-view.ts`: consequence codes :364-372, code-to-sentence map :501-507.
- `ui/src/app/core/strings.ts`: interop block B ends at `interopItemJobsPrompt3` :6545. The five screens use the generic `ListPage`/`DetailPage` (`shell/screen-outlet.ts` :272-275), so no page or dialog component is added.
- `EXPERIENCE.md`:
  - :173 is the Dialogs line: its warning list and "every delete confirmation".
  - :604 is the last Fixed-strings row, a single line that about 90 `strings.ts` citations point at, so no line is inserted above it.
  - :636 is the `confirm-dialog` rule.

### Tests and fixture

- `Test/ProductionProbe.cls` (576 lines):
  - `ClassText` :56 (Op :59-75, Svc :95-99, which forwards to `OPNAME` only); `Create` :150 (class list :154).
  - `AddItem` :190, `PutItemSetting` :241, `Send` :335, `SetHang` :390.
  - `Settle` :428, `Release` :468, `AbortQueues` :509, `Remove` :548.
  - The probe has no failing or retrying operation.
- `Test/InteropGateSeam.cls` `StopSeconds` :34 shortens the cap. `InteropItemSeam`/`InteropSettingSeam` show the seam shape.
- 20.4's classes:
  - `InteropHostDescriptor` (:89 asserts each of the nine screens "declares no action"; :157 the runtime endpoints).
  - `InteropHostRead`, `InteropHostEdges`, `InteropHostGate` (principal generator over `UNIVERSE` :51, `ProbeAs` :271).
  - `InteropHostRead.ArmProbe` (:99-128) hangs the op and queues three messages.
  - The pool-size-0 actor-queue arrangement is in `InteropHostEdges`.
- HTTP confirm precedent: `InteropItemControl` `MintAs` :269, `ConfirmHttp` :293. Gate reuse precedent: `InteropSettingGate` calls `InteropItemGate` through a parameter.
- Rosters this story moves (Rule 30):

| File | Anchor | What |
|---|---|---|
| `Test/ReadTool.cls` | :93-94 | registry tool count 348 → 353, and the sorted names |
| `Test/ToolWrite.cls` | :1338 | non-admin-port writes 31 → 36 |
| `Test/ToolRoundTrip.cls` | :88 | `REFUSEEMPTY` rows |
| `Test/SurfaceCoverage.cls` | :380-390, :614-623 | one coverage row per write tool |
| `Test/ToolEmit.cls` | :226/:237/:248 | per-base pair expectations |
| `Test/ClassicPageGate.cls` | :75/:154 | `OWNPAIRS` 75 → 80 |
| `Test/MappingDescriptor.cls` | :24/:156 | `CLASSICROSTER` 75 → 80 |
| `Test/GovernanceBaseline.cls` | :15/:71 | `DISABLED`, baseline line order |
| `Test/Governance.cls` | :42/:155/:158 | disabled-key constants |
| `Test/ToolDispatch.cls` | :173/:180 | disabled-key expectations |
| `Test/Prohibited.cls` | :232 | the `CoveredTypes()` string |
| `Test/InteropHostDescriptor.cls` | :89 | the five screens' actions |
| `ui/browser/interop-host-tabs.browser-spec.mjs` | :318 | "Queues offers no action" |
| `ui/tools/interop.test.mjs` | :29-66, :94-99 | `SENTENCES`; the `STOPSECONDS` pin list |
| `scripts/ci-throwaway.sh` | after :433 | a `# classes:` line for the new armed classes |

### Vendor (read only, through the worktree's `irislib` link)

- `Ens/Queue.cls`:
  - Entries are `^Ens.Queue(q,priority,index)` = header id; the active message is not in the queue (:265, :317-318).
  - `EnQueue` :145 enqueues into the header's `TargetQueueName` (:155). `EnumerateItem` :910 answers Priority, Index, MessageId.
  - `AbortItem(q,prio,idx)` :757-797: `%Ens_Queues:WRITE` (#940 otherwise); a missing entry is an error; it kills the node, sets the header Aborted, and answers a waiting synchronous caller with an error on a live queue (:785-788).
  - `AbortQueue` :735-755 loops `AbortItem` and answers OK on an empty queue.
- `Ens/Job.cls`:
  - `Stop(pJob,pTimeout,pForce)` :405-467: `%Ens_Jobs:WRITE`. It always logs "Stopping job". It takes a 2 s request lock and waits `pTimeout` for the job lock. Forced, it takes a 10 s status lock, calls `EnsJobForce`, waits up to 10 s more, puts the active message back on its queue, sets the host Error and unregisters the job.
  - `AbortOperation` :796 (`%Ens_Jobs:WRITE`) and `SuspendOperation` :816 (`%Ens_MessageSuspend:USE`) set `^Ens.JobRequest(sys,pid)` for any pid.
  - `ShouldAbort`/`ShouldSuspend` :386-402 consume the request. `ShouldBeQuiescent`/`ShouldTerminate` :370-384 read the job node before the system node.
- `Ens/BusinessOperation.cls` :162-337: the retry loop. The job-level `%Status` reads `Retry` only for `INVOCATION="Queue"` (:277-280). An abort or suspend is taken after a retry wait ends (:322-331).
- `Ens/Util/Statistics.cls` `EnumerateJobStatus` :182-223 has nine columns: Name, Job, Status, AdapterState, LastActivity, Count, Method, Retry, ActiveMessage.
- Classic pages:
  - `EnsPortal/Jobs.cls` `Stop(pJob, UpdateTimeout or 10, 1)` :181 (force 1).
  - `EnsPortal/Queues.cls` abort via `AbortItem` :1347-1362; abort all :1396-1405; active-message abort and suspend :1145/:1227.
  - `EnsPortal/ProductionConfig.cls` Queue tab :4526-4603 and Jobs tab :4644/:4683/:4726.
- `Ens/Util/Auditing.cls` has no audit method for an abort, a suspend or a job stop.

## Tasks & Acceptance

**Execution:**

- [x] **Task 0** runs on `ocupilot-b-ci` only, through `docker exec ocupilot-b-ci iris session iris -U HSCUSTOM`. Record each result as a `Task 0:` line under Verification. A result that disagrees with Design Notes › Measured is HALT `intent gap`. The vendor bullets run first; the three marked *(after code)* run once the `ProductionProbe` task, or this story's code, compiles.
  - A message to a pool-size-0 business process (`InteropHostEdges`' arrangement) has a header `TargetQueueName` that reads `Ens.Actor`, and `Ens.Queue:EnumerateItem("Ens.Actor")` holds its entry.
  - *(after code)* A principal holding exactly one tool's pairs (the screen's pairs, the own pair and `%DB_USER:RW`) completes that tool's action through the port, the forced stop included. With `%DB_USER:R` instead, record the vendor's answer past the gate.
  - `NormalizePage` spells `EnsPortal.ProductionConfig` and `EnsPortal.Queues` as written.
  - `AbortItem` over 1,000 waiting probe entries takes N seconds. If N × 10 exceeds 30, set `ABORTMAX` to the largest whole thousand that fits in 30 s, and the abort-all sentence states that number.
  - *(after code)* The probe's retry operation (`RetryInterval` 2, `FailureTimeout` 300) reads `Status` `Retry` with an `ActiveMessage`. `Settle` and then `Remove` leave `Gone()` reading 1.
  - A job whose process `$System.Process.Terminate` ended still reads `Dead` in the Jobs read for at least 5 s.
  - `Ens.Job.Stop(<hung op job>, 2, 1)` puts its message back on the queue, leaves its host reading Error and the production update pending, and Update starts a job again. Record the wall clock.
  - *(after code)* One HTTP confirm per new tool answers exactly one envelope.
- [x] `src/OcuPilot/Port/InteropPort.cls`, extended (DW-2297):
  - **Types and pairs.**
    - Read types `QUEUE` (Queues), `ENTRY` (QueueItems) and `JOB` (Jobs).
    - Write types `ABORTQUEUE`, `ABORTMESSAGE`, `ABORTJOB`, `SUSPENDJOB` and `STOPJOB`, with `IsRuntimeWrite`.
    - Own pairs: `QUEUEWRITEPAIR` `%Ens_Queues:WRITE` for both queue aborts, `JOBWRITEPAIR` `%Ens_Jobs:WRITE` for job abort and stop, `SUSPENDPAIR` `%Ens_MessageSuspend:USE` for suspend.
    - `Pairs` appends the type's own pair after the endpoint's. `Serves` admits each endpoint's read and writes. `Invoke` and `Admit` count `IsRuntimeWrite` as a write: globals WRITE, no routines database.
  - **`InvokeRuntime` gains `pType`.** `LIST` is unchanged. A typed call needs `IDKEY`: 400 with `REASONQUEUEREQUIRED`, or the new `REASONMESSAGEREQUIRED` ("Name the message.") or `REASONJOBREQUIRED` ("Name the job."). An `ACTIONKEY` that is not one of this endpoint's runtime writes is 501.
  - **Reads.** Each answers its row plus `Namespace`; a write's answer is its row as read after the write.
    - `ENTRY`: the header's `TargetQueueName` (404 for no header), then that queue's entry holding the id. It reads through `GatherQueueEntries`, which gains an optional message id that keeps only that entry and stops at it. Answers `QueueEntryRow`'s fields.
    - `QUEUE`: the `Ens.Queue:Enumerate` row (404 when absent), plus `Entries` (the count enumerated, at most `ABORTMAX`) and `Digest`. `Digest` is `QueueDigest`: a pure SHA-256 hex over the ordered `priority:index:messageId` lines. The enumeration is `GatherQueueEntries` with a new flag that skips opening headers.
    - `JOB`: `LiveCurrent("")` (409 `INTEROP.PRODUCTION.NOTRUNNING` when empty), then `GatherJobs`, which gains an optional pid that keeps only that job, across every host. A pid not found is 404. The row is `JobRow` with `Production`, `Item` and `Namespace`.
  - **`RuntimeRefusal(pType, pDead, pStatus, pActive, pEntries)`** is pure.
    - `ABORTQUEUE` with `pEntries` 0 → `QUEUEEMPTY`.
    - Any job type with `pDead` → `JOBDEAD`.
    - `ABORTJOB`/`SUSPENDJOB` unless `pStatus` = `Retry` and `pActive` '= "" → `JOBNOTRETRYING`.
    - The action-composed read and the write both use it.
  - **`PerformRuntime`**, in the target namespace with explicit save and restore and no `OcuPilot.*` call while switched:
    - Re-read and re-judge first.
    - `ABORTMESSAGE`: `AbortItem(queue, priority, index)`. A vendor error whose entry is gone on a re-check is 404.
    - `ABORTQUEUE`: when the query holds `DIGESTKEY` and it differs from the current digest, refuse 409 `QUEUECHANGED` with nothing aborted. Otherwise `AbortItem` each enumerated entry; one that left the queue meanwhile counts `Skipped`. The answer is `{Name, Count, Aborted, Skipped, Namespace}`.
    - `ABORTJOB`/`SUSPENDJOB`: `AbortOperation`/`SuspendOperation(pid)`, answered by the `JOB` row read right after.
    - `STOPJOB`: `Stop(pid, tTimeout, 1)` with `tTimeout` = `GetRunningProductionUpdateTimeout()` capped at `StopSeconds()`. `<Ens>ErrJobNotStopped` → 409 `JOBNOTSTOPPED`; `<Ens>ErrCanNotAcquireJobLock` and `<Ens>ErrJobStatusLocked` → 503; anything else goes to `Statused`. The answer is `{Job, Host, Stopped: true, Namespace}`.
    - After the restore, `AuditRuntime` records `Kernel/Audit/Event.Record(<abort|abortall|suspend|stop>, <type>, <id>, {}, 0, {namespace, plus queue/aborted/skipped or host})` inside a `Try`. It is a seam a test can read (Design Notes › Audit).
  - **Scripts.** `SnippetForm`/`Snippet` gain one objectscript branch per write. Each renders the reviewed values from `pContext.payload` through `Literal` with every line closed (AD-59): `AbortItem(<Queue>, <Priority>, <Index>)`; an `EnumerateItem` loop calling `AbortItem`; `AbortOperation`/`SuspendOperation(<Job>)`; and the capped timeout, then `Stop(<Job>, tTimeout, 1)`.
- [x] `src/OcuPilot/Api/InteropError.cls`: add the ten codes and sentences in Design Notes › Codes. Add `RuntimeCodes()`, and extend `Codes()`, `ConsequenceCodes()` and `ReasonFor`.
- [x] Tools (new), each with an agent-facing `DESCRIPTION` stating that it only proposes, how to name the target, and what is refused:
  - `Screen/Tool/InteropJobAction.cls` (abstract, extends `InteropAction`):
    - `DESCRIPTORCLASS` `InteropJobList`, `READTYPE` `JOB`, `READANSWERS` (the `JOB` fields), `STATEMARKER` `Status`, `CLASSICPAGES` `EnsPortal.ProductionConfig`, `Endpoint` Jobs, `IdArgument` `Job`
    - `InputSchema` describes `Job` as the pid the Jobs list or an item's Jobs tab reports
    - `StateDiff` answers one row and refuses by `RuntimeRefusal`'s sentence when the read reached it unrefused
  - `InteropJobAbort` (`interop.jobs.abort`):
    - `WRITETYPE` `ABORTJOB`, `SCREENACTIONS` `abort`, `DESTRUCTIVE` 1, `WRITERESOURCE` `%Ens_Jobs` at `WRITEPERMISSION` `WRITE`
    - `CLASSICPAGES` `EnsPortal.ProductionConfig,EnsPortal.Queues`
    - `FINGERPRINTSUBJECT` `Host,Status,ActiveMessage,Dead,Namespace`, `PRECONDITIONFIELD` `Status`, `STATEFIELD` `ActiveMessage` (row: the message id → `Aborted`)
    - `PRECONDITIONCODES` `INTEROP.JOB.DEAD,INTEROP.JOB.NOTRETRYING,INTEROP.PRODUCTION.NOTRUNNING,INTEROP.NAMESPACE`, `CONSEQUENCECODE` `INTEROP.JOB.ABORT`
  - `InteropJobSuspend` (`interop.jobs.suspend`): as abort, except `SUSPENDJOB`, `suspend`, `DESTRUCTIVE` 0, `%Ens_MessageSuspend` at `USE`, row after `Suspended`, `INTEROP.JOB.SUSPEND`.
  - `InteropJobStop` (`interop.jobs.stop`):
    - `STOPJOB`, `stop`, `DESTRUCTIVE` 0, `%Ens_Jobs` at `WRITE`, `CHANGEACTION` `deleted`
    - `FINGERPRINTSUBJECT` `Host,Dead,Namespace`, `PRECONDITIONFIELD` `Dead`, `STATEFIELD` `Status` (row: the job's status → `Stopped`)
    - `PRECONDITIONCODES` `INTEROP.JOB.DEAD,INTEROP.PRODUCTION.NOTRUNNING,INTEROP.NAMESPACE`, `INTEROP.JOB.STOP`
  - `InteropQueueMessageAbort` (`interop.queuemessages.abort`, extends `InteropAction`):
    - `DESCRIPTORCLASS` `InteropQueueMessageList`, `READTYPE` `ENTRY`, `WRITETYPE` `ABORTMESSAGE`, `SCREENACTIONS` `abort`, `DESTRUCTIVE` 1
    - `WRITERESOURCE` `%Ens_Queues` at `WRITE`, `CLASSICPAGES` `EnsPortal.ProductionConfig`, `IdArgument` `MessageId`, `STATEMARKER` `Status`
    - `FINGERPRINTSUBJECT` `Queue,Priority,Index,Namespace`, `PRECONDITIONFIELD` `Index`, `STATEFIELD` `Status` (row: Queued → `Aborted`)
    - `PRECONDITIONCODES` `INTEROP.NAMESPACE`, `INTEROP.MESSAGE.ABORT`
  - `InteropQueueAbort` (`interop.queues.abort`, extends `InteropAction`):
    - `DESCRIPTORCLASS` `InteropQueueList`, `READTYPE` `QUEUE`, `WRITETYPE` `ABORTQUEUE`, `SCREENACTIONS` `abort`, `DESTRUCTIVE` 1
    - `WRITERESOURCE` `%Ens_Queues` at `WRITE`, `CLASSICPAGES` `EnsPortal.ProductionConfig`, `IdArgument` `Name`, `STATEMARKER` `Entries`
    - `FINGERPRINTSUBJECT` `Entries,Digest,Namespace`, `PRECONDITIONFIELD` `Entries`, `STATEFIELD` `Count` (row: `Count` → `Count - Entries`)
    - `PRECONDITIONCODES` `INTEROP.QUEUE.EMPTY,INTEROP.NAMESPACE`, `INTEROP.QUEUE.ABORT`
    - `PortQuery` adds the stored payload's `Digest` as `DIGESTKEY` after `##super`
- [x] Descriptors, in place (Epic 20's own):
  - `InteropQueueList`: `rowActions` `abort`.
  - `InteropQueueMessageList` and `InteropItemQueueTab`: `abort`.
  - `InteropJobList` and `InteropItemJobTab`: `abort`, `suspend`, `stop`.
  - Each sets `emptyNextKey` `""` and `emptyAgentKey` to the new `interopQueuesEmptyAgent`, `interopQueueMessagesEmptyAgent` or `interopJobsEmptyAgent`; each tab uses its list's key, as `ProcessDetails` does.
  - Each doc comment's "offers no action" sentence is replaced with the actions it offers.
- [x] `Kernel/Proposal/Prohibited.cls`, add-only:
  - Append `interop-queue,interop-message,interop-job` to `COVEREDTYPES`.
  - Add `TYPEINTEROPQUEUE`, `TYPEINTEROPMESSAGE` and `TYPEINTEROPJOB`, three clauses appended to the :1344 chain, and three `ReviewedFewOnly` branches beside the production ones, each with its reason (Design Notes).
- [x] `Kernel/Governance/Baseline.cls`: append `interop.queuemessages.abort: false`, `interop.queues.abort: false`, `interop.jobs.abort: false`, `interop.jobs.suspend: true` and `interop.jobs.stop: true`.
- [x] Client:
  - `screen-action-handler.ts`, add-only:
    - `SCREEN_ACTION_DESCRIPTORS` gains the five descriptors.
    - `ACTION_ADDRESS` maps `InteropItemQueueTab` → `InteropQueueMessageList` and `InteropItemJobTab` → `InteropJobList`.
    - `DESTRUCTIVE_ACTIONS` gains `abort`.
    - `DESTRUCTIVE_CONSEQUENCES` maps the five descriptors' `abort` to their sentence.
    - `TYPED_NAME_ROWS`: Queues `Name`, Queue messages and the Queue tab `MessageId`, Jobs and the Jobs tab `Job`.
    - `WARNING_CONSEQUENCES`: Jobs and the Jobs tab `suspend` and `stop`.
  - `screen-actions.ts`: an `abort` label "Abort". `DESCRIPTOR_ACTION_LABELS`: Queues `abort` "Abort all"; Jobs and the Jobs tab `abort` "Abort message", `suspend` "Suspend message" and `stop` "Stop job".
  - `proposal-view.ts`: the five consequence codes map to their sentences.
  - `strings.ts`: append after :6545. Then regenerate `screens.generated.ts`.
- [x] `EXPERIENCE.md`, appending to existing lines only:
  - :173: add "suspend a job's message or stop a job (Jobs and an item's Jobs tab, Story 20.23)" to the warning list before its closing parenthesis.
  - :173: add a `·` entry: "abort a queued message, every message of a queue, or a job's retried message (Queue messages, an item's Queue tab, Queues, Jobs and an item's Jobs tab, Story 20.23: the destructive treatment, typed name the message id, the queue's name or the job's process id)".
  - :604: add a Story 20.23 Where clause carrying every new literal.
  - Each addition carries `[ADDED 2026-10-11 - Story 20.23]`.
  - Then `cd ui && npm run test:tools`.
- [x] `Test/ProductionProbe.cls`, add-only:
  - A `RetryOp` class text (`INVOCATION` Queue; its method sets `..Retry = 1` and returns an error), joining `Create`'s list.
  - The `Svc` forwards to `pHint` when it is given, else to `OPNAME`. `Send(pTarget = "")` passes it.
  - `AddRetryItem(pName, pInterval = 2, pTimeout = 300)` extends `AddItem` with `PutItemSetting` for `RetryInterval` and `FailureTimeout`.
  - `Settle` and `Remove` keep leaving `Gone()` 1 (Task 0).
- [x] Tests (new). Each class creates and removes its own probe and principals and restores governance, runs one class per call, stays under about 500 lines, and declares `ARMINGVARIABLE` `OCUPILOT_ALLOW_PRINCIPALS` as the InteropHost* classes do, with one `# classes:` line in `scripts/ci-throwaway.sh`:
  - `Test/InteropRuntimeDescriptor.cls`:
    - the five screens' actions and empty states, and the tool shapes (names, types, destructiveness, each key's baseline value, pairs, `CLASSICPAGES`, subjects, codes)
    - `Serves` and `Pairs` per type, the `RuntimeRefusal` matrix, `QueueDigest`'s order sensitivity, every new code through `InteropError.ReasonFor` and `Api/Error.ReasonForViolation`, and the script forms
    - `%Dictionary.MethodDefinition` holding the shared members on `InteropJobAction`, not its leaves
  - `Test/InteropQueueActions.cls`, integration:
    - Abort one through mint and HTTP confirm, through Queue messages' route, and for an item Queue tab row through that same route. Each asserts: the entry is gone, the header reads Aborted, the other entries stay, the change event, one audit row (verb, target, namespace, no content), the agent's marker, the snippet and `readBack` `nothingSent`.
    - The actor-queue case.
    - Abort all aborts exactly the enumerated entries and leaves the active message. A message sent after the mint closes the agent's proposal target-changed. A direct port call with a stale `DIGESTKEY` answers `QUEUECHANGED` with every entry still there.
    - `QUEUEEMPTY` and the 404s, each with the queue unchanged.
  - `Test/InteropJobActions.cls`, integration, on the retry item:
    - Abort and suspend, through both callers, leave the message Aborted or Suspended within two retry intervals.
    - `NOTRETRYING` on the idle op's job and `DEAD` on a terminated job, each with no `^Ens.JobRequest` node afterwards.
    - 404 for a pid that is not a job, and `NOTRUNNING` with no production.
    - The audit rows.
  - `Test/InteropJobStop.cls`, integration:
    - Stopping the idle op job: its row leaves, the production reads update pending, and 20.2's confirmed Update starts a job.
    - The hung job with `StopSeconds` 2 through `InteropGateSeam`: its message is back on its queue and its host reads Error.
    - `DEAD`, and the 404, each leaving no "Stopping job" event-log row.
    - The audit row.
  - `Test/InteropRuntimeGate.cls`:
    - Each missing pair is refused by name through the port, the mint and confirm, and the screen routes. A principal holding exactly each tool's pairs completes it.
    - It reuses `InteropItemGate`'s helpers through a parameter, as `InteropSettingGate` does, and `InteropHostGate`'s principal generator where its `UNIVERSE` can be supplied.
- [x] Roster sweep (Rule 30): every row of Code Map › Rosters. Grep `src/OcuPilot/Test`, `ui/tools`, `ui/browser` and the `ui/src` specs for the five screens and the five tools, and update each existing assertion of the old shape.
- [x] `ui/browser/interop-queue-job-actions.browser-spec.mjs` (new). `beforeEach` removes any leftover probe and creates one, armed as `InteropHostRead.ArmProbe` does, so each test starts fresh and passes alone; `after` removes it. Every step waits for the screen's answered signal. In USER:
  - Abort all on `OcuPilotProbeOp` through the typed-name dialog: the queue's `Count` reads 0.
  - Send two messages, then abort one from Queue messages.
  - Stop the hung job from Jobs through its warning: the row leaves.
  - Abort message on a job that is not retrying shows the `NOTRETRYING` sentence.
- [x] Update `ui/browser/interop-host-tabs.browser-spec.mjs` :318 so it asserts the Abort all action Queues now offers.

**Acceptance Criteria:**

- **AC1 (abort one, integration):** Given a message waiting in the probe operation's queue in USER on `ocupilot-b-ci`, when the agent proposes `interop.queuemessages.abort` and the person confirms over HTTP, or the person aborts it from Queue messages or from the item's Queue tab, then its entry leaves the queue, its header reads Aborted, and the queue's other messages stay; the change event and one OcuPilot audit row are recorded, and the agent's marker for the proposal.
- **AC2 (abort all, integration):** Given a queue holding waiting messages, when abort all is proposed and confirmed, or acted on, then exactly the messages its read enumerated are aborted and the message a job is working on stays. Given an empty queue, it is refused `INTEROP.QUEUE.EMPTY` before any vendor call. Given a write whose entries differ from the reviewed digest, it is refused `INTEROP.QUEUE.CHANGED` with nothing aborted.
- **AC3 (a job's message, integration):** Given a job retrying its active message, when abort or suspend is proposed and confirmed, or acted on, then the message reads Aborted or Suspended once the job's retry wait ends. Given a job not retrying, or one whose process has ended, it is refused `INTEROP.JOB.NOTRETRYING` or `INTEROP.JOB.DEAD` before any vendor call, and no request is left for that job.
- **AC4 (stop, integration; consumer 20.2's Update):** Given a job of the running production, when stop is proposed and confirmed, or acted on, then the job ends, a job that had to be forced has its message back on its queue, the production reads update pending, and 20.2's confirmed Update starts a job again. Given a pid that no job of the running production holds, it reads 404, with no vendor call.
- **AC5 (destructiveness, keys, audit; the story's second criterion):** Given the five tools, when registered, then the three aborts are destructive and their keys ship `false`, suspend and stop are not and ship `true`, each stop passes at most 15 s, and each write from either caller leaves exactly one OcuPilot `ConfigChange` row naming the action, the target and the namespace and no message content.
- **AC6 (gates):** Given a principal lacking one declared pair, when it reads, proposes, confirms or acts, then it is refused naming that pair before any vendor call; and a principal holding exactly a tool's pairs completes it.
- **AC7 (screens):** Given Queues, Queue messages, Jobs and an item's Queue and Jobs tabs, when they render, then each row draws its actions: each abort through the typed-name dialog stating its consequence, suspend and stop through a warning, and a refusal showing its published sentence. The DW-1337 structural invariants hold in both themes.

## Spec Change Log

- 2026-10-11, spec gate (lead): DW-2298 returned to this story by the orchestrator (a merged trailer had moved it to 23-7), then re-owned to the chartered Story 20.25 (Item runtime and configuration actions) as this plan's decline names; the five spine drafts written (AD-62 item 9, AD-15, AD-8, AD-44, AD-51), AD-8's pairs as read in the vendor source.

## Review Triage Log

### 2026-10-11 - Review pass

- verdicts: 18 findings - high 0, medium 4, low 14, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` The queue abort's reviewed digest reaches the write through `InteropQueueAbort.PortQuery` and no test calls it; the stale-digest test's "current digest" leg passed `pHasDigest` 0 - added `InteropRuntimeDescriptor.TestTheQueueAbortWriteIsGivenTheReviewedDigest` (through `Operation.Query`), made the leg send the digest, and wrote the mutation line.
  - `[medium]` `[patch]` The partial-failure branches of `PerformAbortQueue` and `PerformAbortMessage` (an entry that left the queue, an entry still queued that the vendor refuses) run in no test - added the `InteropItemSeam` modes `AbortItemGoneOnce` and `AbortItemRefused` and two `InteropQueueActions` tests, with mutation lines.
  - `[medium]` `[patch]` Nothing proves a live process that is no job of the production is refused by stop, abort or suspend; every not-a-job leg used a pid that names no process - added `InteropJobActions.TestALiveProcessThatIsNoJobOfTheProductionIsNotFound`, which starts an idle process and ends it in `OnAfterOneTest`, with its mutation line.
  - `[medium]` `[patch]` Browser tests 2 to 4 relied on the queue state the test before left - `beforeEach` now arms a fresh probe, test 2 uses the armed waiting messages, tests 3 and 4 compare counts read at their own start, and each test passes alone.
  - `[low]` `[patch]` The Suspend message label and the Jobs tab's labels are pinned by no test - added the label table to the handler spec's Story 20.23 block, with its mutation line.
  - `[low]` `[patch]` The 501 for an action key the endpoint does not serve is untested (filed as defer) - a ten-line test closes it under Rule 15's two-way-door row, so it is patched, not deferred: `InteropRuntimeDescriptor.TestAnActionKeyTheEndpointDoesNotServeIsNotImplemented`.
  - `[low]` `[patch]` `TestAStopTheVendorRefusesIsAnsweredInThePortsOwnWords` asserted `Listed` and `StoppingRows`, which the seam makes unable to fail - removed both; the audit leg stays.
  - `[low]` `[reject]` Browser test 3 keeps two assertions that hold with `NOTRETRYING` dropped - the banner-sentence assertion in the same leg goes red without it, so the leg is falsifiable.
  - `[low]` `[reject]` The handler spec's "published sentence from the envelope" echoes the injected reason - it pins the client's generic path for these codes, and the sentences themselves are pinned by `interop.test.mjs` and the browser spec.
  - `[low]` `[patch]` `TestAPrincipalHoldingExactlyTheSuspendPairsSuspends` discarded the start status - asserted it. The `Hang 3` after a start is redundant beside the poll that follows it, not a defect, and stays.
  - `[low]` `[reject]` `INTEROP.QUEUE.CHANGED` is reached end to end only through the fingerprint (`PROPOSAL.TARGETCHANGED`) - by design (Design Notes: a draining queue closes the proposal target-changed); the write's own digest check is pinned by a direct port call and by the `PortQuery` test above.
  - `[low]` `[reject]` The item Queue and Jobs tabs are not driven in a browser - the spec's browser list names Queues, Queue messages and Jobs, and the tabs' rows are posted to the lists' routes over HTTP and in the handler spec.
  - `[low]` `[reject]` `INTEROP.NAMESPACE` is tested at the port only - the tool and the route take the port's answer; `TestATypedCallInANamespaceWithoutInteroperabilityIsRefused` covers all eight types.
  - `[low]` `[reject]` The 15 s cap is exercised through a 2 s seam - by design (Verification); the seam leg shows the cap binds against a 10 s production.
  - `[low]` `[reject]` `ABORTMAX` was measured at 1,000 entries - Task 0's rule (N x 10 within 30 s) is met at 0.036 s per 1,000.
  - `[low]` `[reject]` `ReadEntry` examines at most `QUEUESCANMAX` entries, so a message deeper than 10,000 reads absent - a documented limit of the read (reopen_if: a queue holds more than 10,000 waiting entries and a per-message abort is needed); the fix adds a second enumeration path.
  - `[low]` `[reject]` A failed audit record is not forced in a test - `AuditRuntime` is one `Try`/`Catch`, and an unreachable failure is not worth a hook.
  - `[low]` `[reject]` Abort all on a queue and Abort on a message in it take different holds - the `Skipped` accounting covers the overlap, and the partial-failure legs above pin it.

## Design Notes

**Governing ADs:** AD-8, AD-10, AD-13, AD-14, AD-15, AD-16, AD-22, AD-29, AD-34, AD-44, AD-48, AD-51, AD-52, AD-53, AD-58, AD-59, AD-62. Checked with nothing to add:

- AD-21: no path.
- AD-26: no queued endpoint; each write finishes in its request.
- AD-27: no `%Api.*` call.
- AD-47: values render as text.
- AD-57: not the try-it console.

**Measured at this plan on `ocupilot-b-ci`** (USER; the probe was created and removed, with a temporary retrying operation in its package; `Gone()` read 1 afterwards and `^Ens.JobRequest` was empty):

- A failing operation with `INVOCATION` Queue (`RetryInterval` 3) read job `Status` `Retry`, `ActiveMessage` 124 and `Retry` `""` during its first wait, and `Retry` 2 after it. Its header's `TargetQueueName` read the item's name.
- `AbortOperation` on that job left the message Aborted (status 7) after 2.05 s and consumed the request. `SuspendOperation` on the next message left it Suspended (5) after 2.06 s.
- `AbortOperation` on a job not retrying answered OK, and the request stayed set. With such a request on the probe op's idle job, `StopProduction(5,0)` answered `ErrProductionNotQuiescent` after 5.04 s and left the production running. The request was gone afterwards, and the next stop answered OK.
- `AbortQueue` on an existing empty queue answered OK. `Ens.Job.Stop(999999,5,1)` answered OK in 0.4 ms.
- The production's job read `JobType` 2, user `_Ensemble`, `CanBeTerminated` 1.
- A stop of the idle op job took 1 ms. `ProductionNeedsUpdate` then read 1 ("1 new job for config item 'OcuPilotProbeOp' needs to be started"), and `UpdateProduction(10,0)` answered OK and left it reading 0.
- From 20.4's plan: `AbortItem` needs `%Ens_Queues:WRITE` and raises `<PROTECT>` without globals WRITE. A forced stop took its 10 s timeout, put the message back on its queue and left Update pending.

**Decisions:**

| Action | Tool and key | Destructive | Audit record |
|---|---|---|---|
| Abort one queued message | `interop.queuemessages.abort`, `false` | yes: the message is never delivered | OcuPilot `ConfigChange`, verb `abort` |
| Abort a queue's messages | `interop.queues.abort`, `false` | yes | `ConfigChange`, `abortall`, with the counts |
| Abort a job's retried message | `interop.jobs.abort`, `false` | yes | `ConfigChange`, `abort` |
| Suspend a job's retried message | `interop.jobs.suspend`, `true` | no: a suspended message can be resent | `ConfigChange`, `suspend` |
| Stop a job | `interop.jobs.stop`, `true` | no: Update starts it again (measured) | `ConfigChange`, `stop` |

- **Audit.** The vendor records nothing for any of the five, and `Ens.Util.Auditing` has no fitting event. So the port records OcuPilot's own row after the restore, from either caller, as `ScreenAccessPort` does. An agent write also carries the AD-15 marker, and the two rows share target, user and time. AD-53 gains no named gap.
- **A message is found through its header.** `EnQueue` files an entry under the header's `TargetQueueName`, which for a pool-size-0 process is `Ens.Actor` (Task 0 confirms). So the tool takes only the header id, which is AD-13's `interop-message` id.
  - The item's Queue and Jobs tabs post to their lists' routes (`ACTION_ADDRESS`, Process details' precedent), because `ToolFor` matches one tool per descriptor.
  - Abort all is not offered on the Queue tab: a pool-size-0 process's queue is the shared `Ens.Actor`.
- **Abort all aborts exactly what was reviewed** (AD-48's enumerated-set rule; 20.4's charter set its fingerprint to the entries).
  - The `QUEUE` read enumerates up to `ABORTMAX` entries, and `Digest` stands for them in the fingerprint.
  - The write takes the reviewed digest through `PortQuery`, refuses a queue that moved, and calls `AbortItem` per entry, the classic Abort selected.
  - `AbortQueue` is never called: it also aborts what arrived after the review.
  - A draining queue closes the agent's proposal target-changed. That is correct, and the person re-acts on a fresh read.
- **A job's message is aborted or suspended only while it is retried.** The vendor answers OK for any pid and leaves the request set. Measured, a request left on an idle job kept the next production stop from quiescing. Named limits:
  - A business process's job never reads `Retry` at job level (`Ens.Actor` sets it on the host only), so it is refused.
  - A request set in the instant a retry succeeds stays pending until that job next retries or the production stops (read in source; a millisecond window under the hold).
- **Stop forces, as the classic Jobs page does,** with the production's update timeout capped at 15 s, the cap AD-62 (6) applies to the timeout argument. The vendor's forced path adds at most its own 2 s, 10 s and 10 s lock waits, so a request lasts at most 37 s, under the gateway's 60 s (read in source). Stop ends only a job the port reads as the running production's, never an IRIS system process (AD-10).
- **Prohibited.** The three types pass `ReviewedFewOnly` and nothing else: AD-10 names no effect on them.
  - OcuPilot runs no production. A job is the running production's (JobType 2, `_Ensemble`, measured), never OcuPilot's own process or a system process, and the process arm's allow-list would admit it anyway.
- **Classic pages (AD-44).** Every tool declares `EnsPortal.ProductionConfig`, whose Queue and Jobs tabs perform the same operations. Job abort and suspend also declare `EnsPortal.Queues`, whose active-message table does. Each list's own page is not redeclared.
- **Change events.** The two queue aborts and the job abort and suspend are `updated`: the header and the queue remain. Stop is `deleted`: the job ends.
- **Posture.** No question remains for the orchestrator:
  - The keys follow AD-22.
  - The forced stop is the classic page's own, and Processes' terminate already admits JobType 2.
  - The audit is added, not withheld.
  - OcuPilot's own processes cannot be reached, because a target must be a job of the running production.

**Codes** (`InteropError`, `strings.ts`, `EXPERIENCE.md` :604):

- `INTEROP.MESSAGE.ABORT`: "Aborting this message takes it off its queue and marks it Aborted, so it is never delivered, and a caller waiting for its reply receives an error instead. It cannot be undone."
- `INTEROP.QUEUE.ABORT`: "Aborting all messages takes the messages waiting in this queue now, up to the first 10,000, off it and marks each Aborted, so none is delivered. A message that arrives later stays, and so does one a job is already working on. It cannot be undone."
- `INTEROP.JOB.ABORT`: "Aborting this job's message marks the message it keeps retrying Aborted when its current retry wait ends, so it is never delivered, and the job moves on to its next message. It cannot be undone."
- `INTEROP.JOB.SUSPEND`: "Suspending this job's message sets the message it keeps retrying aside as Suspended when its current retry wait ends, and the job moves on to its next message. A suspended message can be resent later."
- `INTEROP.JOB.STOP`: "Stopping this job asks it to finish its current message within 15 seconds, or sooner when the production's update timeout is shorter. A job that does not is ended, and its message goes back on its queue. The item runs a job short until the production is updated on Productions."
- `INTEROP.QUEUE.EMPTY`: "This queue holds no messages, so there is nothing to abort."
- `INTEROP.QUEUE.CHANGED`: "The messages in this queue changed after they were reviewed, so nothing was aborted. Review the queue again."
- `INTEROP.JOB.DEAD`: "This job's process has already ended, so there is nothing to act on. Update the production on Productions to start its jobs again."
- `INTEROP.JOB.NOTRETRYING`: "This job is not retrying a message now, so there is no message to abort or suspend. Its message can be aborted or suspended only while the job waits to retry it."
- `INTEROP.JOB.NOTSTOPPED`: "The job did not stop within the wait, even after it was ended. Look at Jobs again, and update the production on Productions to start its jobs again."
- The abort-all sentence carries `ABORTMAX`. `interop.test.mjs` pins it the way it pins `STOPSECONDS`, and `interopJobStopConsequence` joins the `STOPSECONDS` pin list.

**Rule 31.**

- The three job tools extend `InteropJobAction`, and every tool extends `InteropAction`. The two queue tools extend `InteropAction` directly: they share no descriptor, read or id.
- `GatherQueueEntries` and `GatherJobs` gain filters, `InvokeRuntime` gains the type, and `Perform`'s cap shape and `Statused` are reused. `RuntimeRefusal` sits beside `Refusal` and `ItemRefusalToken`, because its inputs differ.
- The probe's retry item extends `AddItem`, and `Send` gains a target.
- The gate class reuses `InteropItemGate` and `InteropHostGate`. The seam is `InteropGateSeam`, unchanged.
- No page, dialog, store or loader is added.

**Spine drafts (Rule 20; the runner writes them at the spec gate):**

- **AD-62:** "Story 20.23: `InteropPort` gains the queue and job actions: `QUEUE`/`ABORTQUEUE` on Queues, `ENTRY`/`ABORTMESSAGE` on QueueItems, and `JOB`/`ABORTJOB`/`SUSPENDJOB`/`STOPJOB` on Jobs.
  - Each is action-style over its port-composed read. Before any vendor call it refuses by name an empty queue, a job whose process has ended, and an abort or suspend of a job not retrying its message. Measured, the vendor answers OK for any pid and leaves the request set, and a request left on an idle job kept the next production stop from quiescing.
  - A pid that no job of the running production holds reads absent.
  - The queue abort aborts exactly the entries its read enumerated, through `Ens.Queue.AbortItem`, and refuses a queue whose entries moved. `AbortQueue` is never called.
  - A stop passes the production's update timeout capped at 15 s and forces, as the classic Jobs page does, and ends only a job of the running production, never a system process (AD-10).
  - The three aborts are destructive, and suspend and stop are not."
- **AD-15:** a named case: "Story 20.23: the queue and job actions, which the vendor does not audit, record OcuPilot's own `ConfigChange` from either caller, beside the marker for an agent write."
- **AD-8:** "Story 20.23: the queue and job tools declare the vendor's own check (`%Ens_Queues:WRITE`, `%Ens_Jobs:WRITE`, `%Ens_MessageSuspend:USE`) and WRITE on the namespace's globals database, as measured at Task 0."
- **AD-44:** "Story 20.23: the five tools declare `EnsPortal.ProductionConfig`, and job abort and suspend `EnsPortal.Queues` too."
- **AD-51:** "Story 20.23's case: `InteropPort` answers the five actions' fresh reads through port-composed `QUEUE`, `ENTRY` and `JOB` types, and the queue abort's write takes its reviewed digest from the stored payload."

**Integration ACs, Consumes, Consumed-by:**

- Integration: AC1-AC4 run against `ocupilot-b-ci` through HTTP confirm and the screen action route. AC4's consumer is 20.2's Update, which reads the update the stop leaves pending and starts the job.
- Consumes: 20.4 (the five screens, the runtime reads, the three entity types), 20.2 (Update, `InteropGateSeam`), 20.3 and 20.22 (`InteropAction`), `Test/ProductionProbe`.
- Consumed-by: 20.9 (resending a suspended message; inference) and 20.12 (a guided unblock followed by Update; inference).

**Ledger inbox (Rule 17):**

- DW-2297 is addressed by this story: the port task and AC1-AC5.
- Declined DW-2298: the classic Actions tab's temporary stop, start and restart of one item, change class and copy are item operations, not queue or job actions. Carrying them would add five more tools to a story already oversized. The further story it needs, "Item runtime and configuration actions" in Epic 20 (number the lead's), would start from this charter (read in source):
  - temporary stop and start: `Ens.Director.TempStopConfigItem(name, 1|0, 0)` then Update, needing a running production and `%Ens_ConfigItemRun:USE`. The vendor answers a stopped production and a disabled item with a silent OK.
  - restart: a temporary stop, an Update, a start and an Update.
  - copy: the classic `CopyConfigItem`, a disabled clone.
  - change class: `HostChangeClass`.
  - Copy and change class need `%Ens_ProductionConfig:WRITE` and are audited by the vendor (`ProductionConfig.cls` :6027, :6225, :7702; `Director.cls` :2468).

**Contended files (Rule 11).**

- `origin/OCU-1-epic18` is ahead of the merge base on the spine alone. 18.32 and 18.33 are in flight.
- This story's edits to the shared files are appended entries and the count pins that move with them:
  - `Prohibited.cls` `COVEREDTYPES`, the chain and the branches; the `Baseline.cls` keys
  - `ReadTool`, `SurfaceCoverage`, `strings.ts`, `screens.generated.ts`, `screen-action-handler.ts` maps
  - `EXPERIENCE.md` :173 and :604, the spine
- In place, and Epic 20's own: `InteropPort`, `InteropError`, the five descriptors, `ProductionProbe`, `InteropHostDescriptor` and the 20.4 browser spec.
- No class needs a `ci.test.mjs` edit: the arming roster is parsed from the `# classes:` line.

**Split (`multiple-goals`).** If the runner wants the story smaller, the seam is the job actions: `InteropJobAction` and its three leaves, `JOB`, the job codes, `InteropJobActions`, `InteropJobStop`, the Jobs tab and the retry probe. They would move to a following story, and this one would keep the queue actions and the shared plumbing (the runtime write path, the audit, the client maps). The recommendation is not to split, because the plumbing is most of the work.

**Strings and weight.** About 18 literals: ten sentences, five labels and three empty states. That takes the table to about 3,130, under 3400. The client weight is about 5 kB of strings and mirror on about 3,221,700 bytes, under 3326 kB (inference). Implement measures and states it.

## Verification

**Shared surfaces:**

- the five 20.4 screens' row actions and empty states
- the write-tool rosters (`ReadTool` 348 → 353, `ToolWrite` 31 → 36, `ToolRoundTrip`, `SurfaceCoverage`, `ToolEmit`, `ClassicPageGate` 75 → 80, `MappingDescriptor` 75 → 80)
- the governance baseline and the disabled-key rosters (`GovernanceBaseline`, `Governance`, `ToolDispatch`, three more disabled)
- the prohibited set's covered types
- `InteropPort`'s `Serves`/`Pairs`
- the probe production (its `RetryOp`, the service's target, `AddRetryItem`)
- `DESTRUCTIVE_ACTIONS` gaining `abort`, the Fixed-strings table and the Dialogs line

*Every test added or changed passes on a fresh environment, in either order.*

**Setup (slot B):**

1. `rsync -a --checksum --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-20/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`
2. In `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`, run `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)`.
3. Before any browser run: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`.

Never use the dev instance `ocupilot-slot-b`.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one class per call (`timeout: 600000`), each read from `%UnitTest_Result`:
  - new: `InteropRuntimeDescriptor`, `InteropQueueActions`, `InteropJobActions`, `InteropJobStop`, `InteropRuntimeGate`
  - the port's other callers: `InteropHostDescriptor`, `InteropHostRead`, `InteropHostEdges`, `InteropHostGate`, `InteropControl`, `InteropStopOutcome`, `InteropItemControl`, `InteropSettingControl`
  - the rosters: `Prohibited`, `ReadTool`, `ToolWrite`, `ToolRoundTrip`, `ToolEmit`, `SurfaceCoverage`, `EndpointCoverage`, `ClassicPageGate`, `MappingDescriptor`, `GovernanceBaseline`, `Governance`, `ToolDispatch`, `InteropFloor`, `InteropFloorTurn`, `Descriptor`, and every other class the sweep changes
- `(loop)` `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/<file>`, one file per call, on the redeployed bundle: `interop-queue-job-actions.browser-spec.mjs`, `interop-host-tabs.browser-spec.mjs` and `a11y-structural-invariants.browser-spec.mjs` (DW-1337, both themes).
- `(loop)` Each of these should run clean:
  - `cd ui && npm run test:tools && npm run test:components`
  - `cd ui && npm run build` (the bundle stays under 3326 kB)
  - `uv run scripts/check-objectscript.py <changed .cls>`
  - `bash scripts/lint-docs.sh`
- Lead-owned, after code review: the full ObjectScript sweep on `ocupilot-b-ci`, one class per call; `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`; and Rule 30's fresh check.
- Left to CI: the full browser suite.

**Planned pinning mutations (Rule 19):**

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | `ENTRY` ignores the header and scans the item's own queue | the actor-queue leg |
| AC1 | `ABORTMESSAGE` skips `AbortItem` | every abort-one leg (the header still reads Queued) |
| AC2 | `ABORTQUEUE` calls `AbortQueue` | the leg where a message joins the queue while the abort runs (`InteropItemSeam.SendAfterNextAbort`) |
| AC2 | The write skips the digest check | the stale-digest port leg |
| AC2 | `RuntimeRefusal` drops `QUEUEEMPTY` | the empty-queue legs, and the descriptor matrix |
| AC3 | `RuntimeRefusal` drops `NOTRETRYING` | the idle-job legs (a request node appears), and the matrix |
| AC3 | `RuntimeRefusal` drops `DEAD` | the terminated-job legs |
| AC4 | `STOPJOB` passes force 0 | the hung-job leg (`NOTSTOPPED`, message not requeued) |
| AC4 | `JOB` answers a pid not found | the not-a-job leg (a "Stopping job" row appears) |
| AC5 | `AuditRuntime` skips the record | each audit leg |
| AC5 | `interop.jobs.abort` ships `true` in the baseline | `InteropRuntimeDescriptor`'s key leg, and `GovernanceBaseline` |
| AC5 | `STOPJOB` ignores `StopSeconds()` | the seam leg's wall clock |
| AC6 | Drop each own pair in turn from `Pairs` and from the tool | that pair's gate legs |
| AC7 | `DESTRUCTIVE_ACTIONS` drops `abort` | the browser abort-all leg and the handler spec |
| AC7 | `ACTION_ADDRESS` drops the Queue tab | the handler spec's tab leg, and `InteropQueueActions`' tab leg if driven over HTTP |

**Results (implement pass):**

Task 0 (on `ocupilot-b-ci`, USER; every result agrees with Design Notes › Measured, so there is no halt):

- Task 0: a message to a pool-size-0 business process has `TargetQueueName` `Ens.Actor`, and `Ens.Queue:EnumerateItem("Ens.Actor")` holds its entry.
- Task 0: a principal holding exactly one tool's pairs (the screen's pairs, the own pair and `%DB_USER:RW`) completes that tool's action through the port, the forced stop included. With `%DB_USER:R` instead, the gate passes and the write is refused 403 `PORT.ACCESSDENIED` with nothing changed.
- Task 0: `NormalizePage` spells `EnsPortal.ProductionConfig` and `EnsPortal.Queues` as written.
- Task 0: `AbortItem` over 1,000 waiting entries took 0.036 s, so 10,000 would take about 0.4 s (inference) and `ABORTMAX` stays 10,000.
- Task 0: the retry operation (`RetryInterval` 2, `FailureTimeout` 300) reads `Status` `Retry` with an `ActiveMessage`; after `Settle` and after `Remove`, `Gone()` reads 1.
- Task 0: a job whose process `$System.Process.Terminate` ended read `Dead` for at least 19.8 s, its id renamed to a `Z<pid>_<n>` ghost id about 1 s after the termination.
- Task 0: a forced stop of the hung operation's job at the stock 10 s production timeout took 10.00 s; its message went back on the queue (three waiting), its host read Error, the production read update pending, and Update started a job again. At the seam's 2 s cap the same stop took 2.01 s (`InteropJobStop`'s wall-clock assertion).
- Task 0: one HTTP confirm of each new tool answers exactly one envelope.

Loop, each class on its own call and read from `%UnitTest_Result` (0 failed in every one):

- new: `InteropRuntimeDescriptor` 14, `InteropQueueActions` 10, `InteropJobActions` 7, `InteropJobStop` 5, `InteropRuntimeGate` 6
- port callers: `InteropHostDescriptor` 8, `InteropHostRead` 7, `InteropHostEdges` 8, `InteropHostGate` 3, `InteropControl` 11, `InteropStopOutcome` 4, `InteropItemControl` 6, `InteropSettingControl` 7, `InteropItemGate` 5, `InteropSettingGate` 5
- rosters: `Prohibited` 15, `ReadTool` 28, `ToolWrite` 34, `ToolRoundTrip` 2, `ToolEmit` 11, `SurfaceCoverage` 4, `EndpointCoverage` 2, `ClassicPageGate` 8, `MappingDescriptor` 6, `GovernanceBaseline` 3, `Governance` 14, `ToolDispatch` 18, `InteropDescriptor` 12, `InteropFloor` 7, `InteropFloorTurn` 1, `Descriptor` 60
- browser, on the redeployed bundle: `interop-queue-job-actions` 4 of 4 (each test arms its own probe, and each passes alone), `interop-host-tabs` 4 of 4, `a11y-structural-invariants` 13 of 13 (174 declared screens, 163 walked, 11 skipped, 0 entries beyond the baseline, both themes)
- `npm run test:tools` 1909 passed; `npm run test:components` 2851 passed in 226 files; `npm run build` initial total 3,295,800 bytes (warning at 3326 kB, error at 4000 kB)
- `uv run scripts/check-objectscript.py` 0 problems over 1915 files; `bash scripts/lint-docs.sh` 0 issues

Rule 19, each applied on the throwaway with the class (and every descendant) recompiled or the bundle rebuilt and redeployed, observed red, then reverted; the tree matched its pre-mutation fingerprint afterwards:

- mutation: `ReadEntry` reads the header's `TargetConfigName` in place of `TargetQueueName` -> `InteropQueueActions.TestAnAbortFindsAMessageToAPoolSizeZeroProcessInTheActorQueue`
- mutation: `PerformAbortMessage` skips `AbortItem` -> `InteropQueueActions` `TestTheAgentsAbortOfOneMessageTakesItOffTheQueue`, `TestThePersonsAbortFromQueueMessagesAndFromTheItemsQueueTab` and the actor-queue test
- mutation: `PerformAbortQueue` calls `Ens.Queue.AbortQueue` in place of the per-entry loop -> `InteropQueueActions.TestAQueueAbortLeavesAMessageThatJoinsWhileItRuns`
- mutation: `PerformAbortQueue` skips the digest comparison -> `InteropQueueActions.TestAStaleDigestAbortsNothingAndThePersonsAbortAllTakesTheWaitingMessages`
- mutation: `RuntimeRefusal` drops `QUEUEEMPTY` -> `InteropQueueActions.TestAnEmptyQueueAndAGoneTargetAreRefusedWithNothingChanged` and `InteropRuntimeDescriptor.TestTheRuntimeRefusalMatrix`
- mutation: `RuntimeRefusal` drops `JOBNOTRETRYING` -> `InteropJobActions.TestAnAbortOrSuspendOfAnIdleJobIsRefusedAndLeavesNoRequest` and the matrix
- mutation: `RuntimeRefusal` drops `JOBDEAD` -> `InteropJobActions.TestAnAbortOrSuspendOfAJobWhoseProcessEndedIsRefusedAndLeavesNoRequest` and `InteropJobStop.TestADeadOrAbsentJobIsRefusedBeforeTheVendorIsCalled`
- mutation: `VendorJob` passes force 0 to `Ens.Job.Stop` -> `InteropJobStop.TestAStopOfAHungJobIsForcedAndPutsItsMessageBack` (the answer is 409 `INTEROP.JOB.NOTSTOPPED`)
- mutation: `VendorJob` ignores the `StopSeconds()` cap -> the same test's wall-clock assertion (10.02 s against the shortened 2 s)
- mutation: `JobStatused` drops its `NOTSTOPPED` line (the status falls to `Statused`, a busy production), or drops its job-lock line, each with the class and its descendants recompiled -> `InteropJobStop.TestAStopTheVendorRefusesIsAnsweredInThePortsOwnWords`, which answers the three vendor codes through `InteropItemSeam.RefuseJobWith`
- mutation: `Admit` drops its `INTEROP.NAMESPACE` refusal, with the port and its descendants recompiled -> `InteropRuntimeDescriptor.TestATypedCallInANamespaceWithoutInteroperabilityIsRefused`
- mutation: `InteropQueueAbort.PortQuery` drops the digest line -> `InteropRuntimeDescriptor.TestTheQueueAbortWriteIsGivenTheReviewedDigest`
- mutation: `InvokeTyped` drops the 501 refusal -> `InteropRuntimeDescriptor.TestAnActionKeyTheEndpointDoesNotServeIsNotImplemented`
- mutation: `PerformAbortQueue` inverts its `$Data(tStillQueued(...))` test -> `InteropQueueActions.TestAnAbortAllCountsAnEntryThatLeftTheQueueAndFailsOnOneStillQueued`
- mutation: `PerformAbortMessage` drops the 404 re-read -> `InteropQueueActions.TestAnAbortOfOneMessageWhoseVendorCallFailsIsJudgedByTheEntry`
- mutation: `ReadJob` answers a live process id that no host holds as a job of its own -> `InteropJobActions.TestALiveProcessThatIsNoJobOfTheProductionIsNotFound`
- mutation: `DESCRIPTOR_ACTION_LABELS` drops the Jobs tab's entry, or the Jobs list's `suspend` -> the handler spec's label test
- mutation: `ReadJob` answers a pid it did not find -> `InteropJobActions.TestAPidNoJobHoldsIsNotFoundAndAStoppedProductionIsNotRunning`, `InteropJobStop.TestADeadOrAbsentJobIsRefusedBeforeTheVendorIsCalled` and the two stop tests that read the deleted event
- mutation: `AuditRuntime` skips `Event.Record` -> six `InteropQueueActions`, three `InteropJobActions` and three `InteropJobStop` tests
- mutation: `interop.jobs.abort` ships `true` in `Baseline.cls` -> `InteropRuntimeDescriptor.TestTheFiveToolsDeclareWhatTheSpecNames` and `GovernanceBaseline.TestThePurgeIsTheOneDisabledLine`
- mutation: `Pairs` drops `QUEUEWRITEPAIR`, `JOBWRITEPAIR` and `SUSPENDPAIR` in turn -> `InteropRuntimeGate.TestEachMissingPairIsRefusedByNameThroughThePortTheToolsAndTheMint` each time (the job pair also reddens `TestAPrincipalHoldingExactlyTheSuspendPairsSuspends`)
- mutation: the queue tools, `InteropJobAction` and `InteropJobSuspend` each declare no `WRITERESOURCE` -> `InteropRuntimeGate`'s three tests naming the pair (`TestAPrincipalHoldingExactly...`, `...OnTheScreenRoutes`, `...ThroughThePortTheToolsAndTheMint`)
- mutation: `DESTRUCTIVE_ACTIONS` drops `abort` -> the handler spec's abort test, and in the browser the three abort legs (the typed-name dialog never opens)
- mutation: `ACTION_ADDRESS` drops the Queue tab -> the handler spec's abort test (the tab posts to its own route)
- mutation: `proposal-view.ts` drops `INTEROP.JOB.STOP` -> `proposal-card.spec.ts`'s Story 20.23 test
- mutation: `WARNING_CONSEQUENCES` drops the Jobs entry -> the handler spec's warning test
- mutation: `TYPED_NAME_ROWS` drops the Jobs entry -> the handler spec's abort test (its name assertion)
- mutation: `SCREEN_ACTION_DESCRIPTORS` drops the Queues list -> the handler spec's registration test
- mutation: `DESTRUCTIVE_CONSEQUENCES` drops the Queue tab's entry -> the handler spec's registration and abort tests
- mutation: `DESCRIPTOR_ACTION_LABELS` drops the Queues entry -> the browser spec's four tests, the abort-all leg first (no menu entry reads Abort all)

## Auto Run Result

Status: done
Blocking condition: none

**Summary.** `InteropPort` carries the queue and job actions (AD-62): the `QUEUE`, `ENTRY` and `JOB` reads, `RuntimeRefusal` (an empty queue, a dead job, an abort or suspend of a job not retrying), and the five writes (`ABORTQUEUE` by `AbortItem` per enumerated entry, `ABORTMESSAGE`, `ABORTJOB`, `SUSPENDJOB`, `STOPJOB` with the production's timeout capped at `StopSeconds()` and force on). The port records OcuPilot's `ConfigChange` row for each. Five tools, five descriptors' row actions, the prohibited-set, baseline, error, client and EXPERIENCE.md additions, the probe's retry operation, five new test classes and one browser spec follow the spec.

**Files changed.**

- `src/OcuPilot/Port/InteropPort.cls`, `Api/InteropError.cls`: the port work and ten codes.
- `src/OcuPilot/Screen/Tool/InteropJobAction.cls`, `InteropJobAbort.cls`, `InteropJobSuspend.cls`, `InteropJobStop.cls`, `InteropQueueAbort.cls`, `InteropQueueMessageAbort.cls`: the tools.
- Five descriptors under `Screen/Descriptor/`, `Kernel/Proposal/Prohibited.cls`, `Kernel/Governance/Baseline.cls`: row actions, covered types, keys.
- `ui/src/app/core/{strings,screen-actions,proposal-view,screens.generated}.ts`, `ui/src/app/shell/screen-action-handler.ts` and its two specs, `ui/tools/interop.test.mjs`, `EXPERIENCE.md`: the client, copy and pins.
- `src/OcuPilot/Test/`: `InteropRuntimeDescriptor`, `InteropQueueActions`, `InteropJobActions`, `InteropJobStop`, `InteropRuntimeGate` (new); `ProductionProbe`, `InteropItemSeam` and the roster classes (changed); `scripts/ci-throwaway.sh` (one `# classes:` line).
- `ui/browser/interop-queue-job-actions.browser-spec.mjs` (new), `interop-host-tabs.browser-spec.mjs` (changed).

**Review.** Two layers reported 18 findings: patches applied 8 (medium 4, low 4), deferred 0, rejected 10 (each with its reason in the Review Triage Log). Follow-up review recommended: `true`, for the four medium patches. The patch pass added seam overrides (`VendorJob`, `VendorAbortItem` on `InteropItemSeam`), an idle-process test and a per-test arming of the browser spec, which no independent reviewer has read.

**Verification.** Every `(loop)` line ran green on `ocupilot-b-ci`, before and after the patches: the new classes (14, 10, 7, 5 and 6 tests), the port's other callers, the roster and probe-user classes, the three browser specs, `npm run test:tools` (1909), `npm run test:components` (2852), `npm run build` (initial total 3,295,800 bytes, under the 3326 kB warning), `check-objectscript.py` and `lint-docs.sh`. Rule 19: 30 mutation lines in `## Verification`, each observed red and reverted. The full ObjectScript sweep, the smoke, Rule 30's fresh check and the full browser suite are the lead's and CI's.

**Residual risks.** A message deeper than 10,000 entries in a queue reads absent to the per-message abort (documented in `ReadEntry`). The Queue and Jobs tabs' rows are covered over HTTP and in the handler spec, not in a browser.
