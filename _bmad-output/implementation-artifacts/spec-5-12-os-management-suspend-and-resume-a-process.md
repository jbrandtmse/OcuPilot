---
title: 'Story 5.12: OS management - suspend and resume a process'
type: 'feature'
created: '2026-09-21'
status: 'done'
baseline_revision: 'c904efbb09cb2218e561e2130dc49c9ed1d5b93f'
baseline_commit: 'c904efbb09cb2218e561e2130dc49c9ed1d5b93f'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
deferred:
  - 'WireSecurityRead.TestTaskHistoryPairSetsAreEnforcedForARealPrincipal fails on a reused throwaway once %SYS_Task.History passes the tasks.history read 1000-row cap (1032 rows on ocupilot-ci). Environmental, not this story: a fresh throwaway starts that table empty. Bound the leg to the probe task own rows, or let it tolerate a truncated view.'
  - summary: >-
      Several acceptance criteria carry their Rule 19 mutation only in the test method's own doc
      comment, not as a `mutation:` line in this spec's `## Verification` list.
    evidence: |-
      The list records eleven mutations. AC1's write half, AC2's two wrong-state refusals, AC4's
      absent-request-type half, AC5, AC6, AC7, AC8 and AC9 name theirs in the class doc comment
      instead (ProcessControl.cls:206-210, ToolWrite.cls:706-716, ProhibitedRoute.cls:2118-2121).
      Settled by re-applying each and writing the line, which is eight container round trips.
    location: >-
      _bmad-output/implementation-artifacts/spec-5-12-os-management-suspend-and-resume-a-process.md
    severity: low
  - summary: >-
      OcuPilot.Test.ProhibitedFixture.Digest still computes the confirm digest with the
      three-argument Fingerprint.Of, so a seeded action-style proposal would carry a digest no
      confirm can match.
    evidence: |-
      ProhibitedRoute.Minted was updated in this story to project and pass the declared subject;
      Digest was not. Both current callers (ProhibitedRoute.cls:247, ProhibitedByEffect.cls:487)
      pass merge-write tools, so nothing is wrong today. Story 5.13 is the first caller that would
      seed an action write through it.
    location: >-
      src/OcuPilot/Test/ProhibitedFixture.cls:176
    severity: low
  - summary: >-
      AC7's Process-details half has no browser leg -- only the Processes list is driven for the
      AD-43 auto-refresh pause.
    evidence: |-
      process-control.browser-spec.mjs has two tests, both on /ocupilot/os-management/processes.
      ProcessDetails declares refreshes: true and is changed in this story (JobType added to
      read.fields), but gains no pause leg; the generic pause is pinned by
      task-resume.browser-spec.mjs:483.
    location: >-
      ui/browser/process-control.browser-spec.mjs
    severity: low
  - summary: >-
      AC2's orchestrator-decided broad ownership reading leaves almost nothing proposable on a
      single-user instance -- a product consequence for the decision sheet, not a defect.
    evidence: |-
      Prohibited.OwnedByCaller refuses any process whose UserName is the confirming user. Measured
      on ocupilot-ci: 40 empty-owner daemons, 4 CSPSYSTEM, 1 TASKMGR, 1 IRISOWNER -- so the suite
      had to create a second principal to have any proposable target at all. Spec-bound: the broad
      reading was decided at planning, so it reopens only through an amendment.
    severity: medium
---

<intent-contract>

## Intent

**Problem:** The Processes list is the last read-only area with a Release 1 write behind it. The
vendor exposes suspend, resume and terminate on `%Api.Admin.Endpoints.Process` as bodyless v2
request types, so the tool is action-style (AD-51) and the seam Story 5.11 built carries it. Two of
the five acceptance criteria are refusals - the user's own process and an IRIS system process - and
AD-10 names "Terminating IRIS system processes" in the prohibited set explicitly, by effect.

**Approach:** Ship `osmgmt.processes.suspend` and `osmgmt.processes.resume` as action-style writes
consuming 5.11's `ReadType`/`WriteType`/`SendsBody`/`StateField`/`StateDiff` declarations, add the
`process` type to the prohibited set with its two target predicates and its AD-13 canonicalization
rule, scope `AdminPort`'s bodyless exemption to an `(endpoint, type)` pair (DW-1464), and arm the
two state-changing test classes with an environment variable so neither can run against a live
instance (DW-1458).

**This story is blocked at planning on one intent gap.** AD-6's fingerprint rule is unsatisfiable
for this endpoint: see `## Blocking Condition` below. Everything else is planned and measured, so a
re-dispatch after the spine is amended starts from this file rather than from scratch.

## Boundaries & Constraints

**Always:**

- The writes are `Process` `SUSPEND` and `RESUME`. Measured on the instance 2026-09-21:
  `TYPEBROADCAST = 10`, `TYPERESUME = 11`, `TYPESUSPEND = 12`, `TYPETERMINATE = 13`, each commented
  "introduced in v2"; `Run` dispatches all four and falls through to `##super` otherwise;
  `NeedsRequestBody()` is `..IsTypePatch() || (..Type = ..#TYPEBROADCAST)`, so **SUSPEND, RESUME and
  TERMINATE all carry no body**; `ResourcesOR()` answers `$LISTBUILD("%Admin_Operate")` for **every**
  type with no per-type branching; `ValidateQueryParams()` returns early only for LIST and BROADCAST,
  so every other type takes `..Id = ..GetRequiredQueryParam("id")`; `ShouldRunAsync()` is not
  overridden; and none of `RequestBodySchema`, `PutRequestBodySchema`, `PutAndPostSchema`, `Schema`
  is defined or inherited - AD-3's "publishes no template" is confirmed on the instance, so AC4 is a
  fact about the endpoint rather than a choice.
- The pair set is the screen's own - `%Admin_Operate:USE`, `%Admin_Manage:USE`, `%DB_IRISSYS:READ`,
  exactly what `ProcessList` already declares - at `USE`, never `WRITE` (AD-8 as amended
  2026-09-21). `PrivilegePairs()` adds nothing new, as in 5.11.
- The entity type is `process`, already a member of `EntityType.TYPES`. No enum change; `Count()`
  stays 29.
- Every state-changing check runs on the throwaway `ocupilot-ci` (`http://localhost:52776`) against
  a probe process the test **created itself**. Never suspend a process on `ocupilot` or any
  `ocupilot-slot-*` container, and never target a daemon, the Task Manager, a Work Queue worker, or
  `WRTDMN` (which `ui/browser/processes.browser-spec.mjs` uses as its selection anchor).
- Tests run one class or suite per invocation, waiting for each to land in `%UnitTest_Result`.

**Never:**

- **No terminate tool.** AC3 is satisfied by absence plus refusal, not by shipping one.
  `AdminPort.MUTATINGTYPES` admits neither `TERMINATE` nor `DELETE` and this story does not add
  them, so "never advertised as a tool" stays true by construction.
- No new screen descriptor, no Angular page, no side-bar entry. Both Processes screens exist and
  both are built.
- No row action and no primary action on either descriptor. `epics.md:3935`'s amendment forbids an
  inert control shipping ahead of its handler; the Processes row actions are Stories 7.8 and 16.6,
  which `ProcessList.cls:19-26` already records.
- No second composite grammar, no new id-rule name - `process` reuses 5.11's existing `integer`
  rule.
- No `docker compose up`/`down`/`restart` against `ocupilot` or any `ocupilot-slot-*` container; no
  teardown of a throwaway this session did not start. `ocupilot-ci` is up, is not pristine, and no
  session here brought it up.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Suspend proposed | agent calls `osmgmt.processes.suspend` with a running process's pid | proposal minted from a fresh `Process` `GET`; **one** diff row `State: Running -> Suspended`; no unchanged-fields caption; `destructive` false | No error expected |
| Target already suspended | the same call against a process whose `State` contains `SUSP` | **refused at the mint**, naming that the process is already suspended; no proposal row, no card | `PROPOSAL.*` refusal reason |
| Resume proposed | `osmgmt.processes.resume` against a suspended process | one diff row `State: Suspended -> Running`; refused at the mint when the target is not suspended | `PROPOSAL.*` refusal reason. `RunResume` has **no** `CanBeResumed` guard of its own (measured), so the mint refusal is the only one |
| The caller's own process | the target pid is the confirming caller's | refused with an explanation naming that it is the user's own process | `PROHIBITED.*`; the write never reaches the port |
| An IRIS system process | the target's `JobType` is outside the allow-list of interactive and client job types | refused with an explanation naming that it is an IRIS system process | `PROHIBITED.*`, fail-closed on an unknown `JobType` |
| Terminate | any caller, any target | there is no terminate tool to call, and `TERMINATE`/`DELETE` are absent from `AdminPort.MUTATINGTYPES`, so the port refuses the request type outright | `EndpointType` answers `""` for a suffix in neither list (`AdminPort.cls:791`) |
| Suspend confirmed | user presses Confirm | `Process` `SUSPEND` issued with the `id` query parameter and **no body**; the `GET` then answers a suspended `State`; one `changed` event `(process, instance, <pid>)` with action `updated`; marker emitted and the ledger row reads marked | a port fault passes through as its own envelope; the ledger row closes `error` and claims no marking |
| Vendor refuses the suspend | `CanBeSuspended` is false for a reason of the vendor's own | the port surfaces the vendor's 409 as OcuPilot's envelope; the proposal row closes | `RunSuspend` answers `HTTP409CONFLICT` with `$$$CannotSuspendProcess` (measured) |
| Two spellings of one pid | agent sends `"0837"`, then `"837"`, for the same process | both canonicalize to one key, so the second proposal is the first's sibling: one lock, one cancel (AD-13, AD-34) | the loser is refused with the terminal state, never retried |
| A field on a bodyless write | a proposal for a `process` target carries any changed field | refused - `PermittedChangeFields("process")` is empty, so no field is permitted | `PROHIBITED.UNCOVEREDFIELD` |
| Target gone between mint and confirm | the process has ended | the fresh re-read answers 404 | the confirm refuses; the row closes |
| Least-privileged confirm | caller holds none of the three declared pairs | 403 naming the failed pair; the process keeps running | `AUTH.NOPRIVILEGE` with `detail.failedPair` |
| A live proposal against a process | a `process` proposal is open while Processes or Process details is showing | both screens' auto-refresh pauses with the chip and resumes on close (AD-43) | none |

</intent-contract>

## Blocking Condition - RESOLVED 2026-09-22

**Resolved by a spine amendment, orchestrator-approved; the measurement below stands and is what
carried it.** AD-51 now gives an action-style write a **declared fingerprint subject**, and AD-6's
selection sentence was corrected at its origin in the same commit so the two do not disagree. The
approved ground is sharper than "AD-6 is unsatisfiable here": its mechanism answers the **wrong
question** for an action write. A digest over the whole of a live process's read refuses the confirm
whenever the target has executed a command between mint and confirm, so it fires hardest for exactly
the processes this story exists to suspend and never for an idle one nobody wants to touch. AD-6's
purpose survives intact, because what it prevents is a write against state that *moved under the
diff*, and for an action write there is no payload - the reviewed intent is this target, in this
state, with this verb, and a counter advancing is the process doing its job.

**Adequacy is structural, not a review convention.** The subject must carry the scoped target
identity (AD-13) **and every field the action's own precondition reads** - `State` here - because a
subject of `{Pid}` alone would let a confirm succeed against a process somebody else had already
suspended. An empty subject is refused, and that is necessary but nowhere near sufficient. The
subject is validated by the **same builder** that validates `fingerprintExcludes`, through one
extraction consumed by both: a second validator beside the first is DW-1206's defect in new
clothing.

**AC2's "the user's own process" takes the broad reading** (orchestrator-decided): any process
owned by the confirming user, not merely `$JOB`. AD-10 defines the prohibited set by **effect, not
verb**, and `$JOB` alone would catch the confirm request's own job while missing the user's
interactive portal session, whose suspension locks them out just as completely.

### The measurement

1. The fingerprint's subject is the tool's fresh read, **whole**. `Mint.cls:170` calls
   `Fingerprint.Of(tPayload, $ClassMethod(pDescriptor, "FingerprintExcludes"), .tFingerprint)`, and
   `tPayload` is `%FromJSON(pFresh.%ToJSON())` - a byte copy of the fresh read (`Mint.Merge`).
   `Fingerprint.cls:4-7` states the invariant in its own words: *"It covers the complete property
   set, and the exclusions are the descriptor's. A slice never chooses which fields the fingerprint
   covers -- only which ones it does not -- so the default is everything else."* That is AD-6's Rule
   written into the kernel.
2. `Process` has exactly **one** single-object read: `GET`. There is no `TYPEINFO` on the class
   (measured), `LIST` ignores `id` and answers an array - which `Mint.cls:129` refuses as "not
   present on this instance" - and AD-2 forbids OcuPilot reaching the object any other way.
3. That `GET` answers **50 keys** (measured, enumerated in the Code Map). Between two reads three
   seconds apart on a working process, **nine** moved: `CommandsExecuted`, `GlobalReferences`,
   `GlobalUpdates`, `GlobalBlocks`, `DataBlockWrites`, `MemoryUsed`, `PrivateGlobalBlockCount`,
   `PrivateGlobalReferences`, `PrivateGlobalUpdates`. The **idle** `CONTROL` daemon, by contrast, held
   still: the lead re-measured `CommandsExecuted`, `CPUTime` and `GlobalReferences` over twenty
   seconds and none moved. So the digest is unstable for a **working** process specifically - which
   is the whole target population this story exists to act on, since a runaway process is the one
   whose counters move fastest.
4. An exclusion must be a name the screen already knows. `Registry.cls:2007` refuses any other:
   *"fingerprintExcludes names '<path>', which is neither a field of this screen's write tool nor
   one its read declares (AD-6)"*, where the read half is `read.fields`, the `rowGet` detail fields,
   the derived names and the declared criteria. A bodyless tool has no settable fields, so the read
   half is all there is.
5. **The set that must be excluded is not a subset of the set either descriptor can declare.**
   `ProcessList.read.fields` is the seven LIST keys (`Pid, Username, Nspace, Routine, State,
   Commands, Globals`) - the LIST spellings, so **none** of the ten measured movers is nameable
   there. `ProcessDetails.read.fields` is 27 of the 50 GET keys and covers six of the ten movers;
   `GlobalUpdates`, `GlobalBlocks`, `DataBlockWrites` and `PrivateGlobalUpdates` are not among them.
6. **The only way to make the remainder declarable is to declare `Variables`** - the process's whole
   local-variable table, one of the 50 GET keys - in a screen's read, because an honest exclusion
   list for a live process is "everything but `Pid` and `State`". AD-24 then projects a declared read
   field into screen context and into the read tool's view, and AD-48 treats the directly analogous
   `^ERRORS` variable capture as secret-by-default precisely because on an IRIS for Health instance
   those tables can hold patient data. So route 6 buys a working fingerprint by breaking AD-24 and
   AD-35.

Four in-story routes were checked and all four are closed: a `LIST` read type (refused as a
non-object), a narrower vendor request type (none exists), a third descriptor declaring all 50 keys
(same `Variables` problem), and an exclusion list of the non-movers only (the mechanism excludes,
it does not include, and "non-mover" is not a stable property of a running process - `State`,
`Routine`, `NameSpace`, `Location`, `CurrentLineAndRoutine`, `OpenDevices`, `InTransaction` and
`MemoryAllocated` all move on a real target).

### Recommended amendment

**Extend AD-51's per-tool seam with a declared fingerprint subject for an action-style write: the
tool names the fields of its fresh read the fingerprint covers, instead of the descriptor naming
what it excludes.** Here that is `Pid` and `State`.

- It changes nothing for a merge write. AD-4 makes the body a copy of the fresh read, the two sets
  coincide, and "everything else" stays the right default - AD-6's exclusion list is untouched.
- It preserves what AD-6 protects. The invariant is "a write against state that moved under the diff
  is refused"; the diff of an action write is one row over one field, and naming that field
  positively is what makes the refusal reachable at all. Under the current rule the refusal fires on
  every confirm, which is not protection but a dead path.
- It keeps the typo protection `Registry.ConfirmChannelProblem` exists for, in the safer direction:
  a named subject field must be a live key of the tool's own read, checked the same way, and an
  **empty** subject is refused - where an exclusion that covers nothing is the failure mode the
  current rule can only catch by name.
- AD-51 is the natural home. It already re-read AD-6's fingerprint clause once for the bodyless case
  ("the fresh read is the set"); this is the second half of the same reading, and Stories 5.13 and
  7.6 are the next callers.

### A second, smaller decision for the same sitting

AC2's "the user's **own** process" has two readings with observably different outcomes, and nothing
in the epic block or EXPERIENCE.md selects between them:

- **(A) the job serving the request** (`$JOB`). Measured: the read's `Pid` is directly comparable to
  `$JOB`, and the vendor already self-protects here - the retrieval code for `CanBeExamined`,
  `CanBeSuspended` and `CanBeTerminated` each opens `if $zu(61,17,{1D1})=$j q`, and a GET on `$JOB`
  answered `CanBeSuspended=0 CanBeTerminated=0`.
- **(B) any process whose `UserName` is the confirming user** - the operator's other terminal
  sessions, which (A) leaves suspendable.

**Recommendation: (B)**, with (A) as its strict subset. AD-10 defines the set by effect, and the
effect being prevented is the agent stopping the person driving it from working; suspending the
operator's other session is that harm, and (A) does not cover it. (A) alone is defensible, which is
why this is asked rather than picked.

## Code Map

Line anchors read in this checkout on 2026-09-21. Vendor facts carry the probe that produced them.

### Measured on the live instance, 2026-09-21 (read-only probes, `server: "ocupilot-slot-a"`)

`%Api.Admin.Endpoints.Process` is `[ Hidden ]` and **absent from `irissys/`**, so it was fetched with
`%Compiler.UDL.TextServices.GetTextAsString("%SYS", "%Api.Admin.Endpoints.Process.cls", .s)` -
265 lines - exactly as 5.11 measured `Task.CRUD`.

- Request types, `Run` dispatch, `NeedsRequestBody()`, `ResourcesOR()`, `ValidateQueryParams()`,
  `ShouldRunAsync()` and the absent body template: as **Boundaries** records them above.
- `RunSuspend` opens `SYS.Process.%OpenId(..Id)`, answers 404 when it cannot, answers
  `HTTP409CONFLICT` with `$$$ERROR($$$CannotSuspendProcess, ..Id)` when `'obj.CanBeSuspended`, then
  `Set sc = obj.Suspend()`. `RunTerminate` is the same shape on `CanBeTerminated` /
  `$$$UnableToKill` / `obj.Terminate()`. **`RunResume` has no guard at all** - it opens and calls
  `obj.Resume()` - so the not-suspended refusal is OcuPilot's alone.
- **`RunDelete` is a one-line delegate to `RunTerminate`**, so the vendor exposes terminate through
  two doors. Neither `TERMINATE` nor `DELETE` is in `AdminPort.MUTATINGTYPES`, which is what makes
  AC3's "never advertised as a tool" true of OcuPilot rather than of the instance - AC3 is worth
  wording that way.
- **The `GET`'s 50 keys**, in the order the instance answered them: `CanBeSuspended`,
  `CanBeTerminated`, `CanReceiveBroadcast`, `ClientExecutableName`, `ClientIPAddress`,
  `ClientNodeName`, `CommandsExecuted`, `CSPSessionID`, `CurrentDevice`, `CurrentLineAndRoutine`,
  `CurrentSrcLine`, `EscalatedRoles`, `GlobalReferences`, `GlobalUpdates`, `GlobalDiskReads`,
  `GlobalBlocks`, `DataBlockWrites`, `InTransaction`, `IsGhost`, `JobNumber`, `JobType`,
  `JournalEntries`, `LastGlobalReference`, `LicenseUserId`, `Location`, `LoginRoles`,
  `MemoryAllocated`, `MemoryUsed`, `MemoryPeak`, `NameSpace`, `OpenDevices`, `OSUserName`,
  `CPUTime`, `ParentPid`, `Pid`, `PrivateGlobalBlockCount`, `PrivateGlobalReferences`,
  `PrivateGlobalUpdates`, `PidExternal`, `PrincipalDevice`, `Priority`, `Roles`, `Routine`,
  `StartTimeUTC`, `StartupClientIPAddress`, `StartupClientNodeName`, `State`, `UserInfo`,
  `UserName`, `Variables`.
- **No boolean reports suspension.** `State` is a JSON string; `%SYS.ProcessQuery.State`'s doc lists
  `SUSP - Process is suspended` and `S - Suspension requested`. `CanBeSuspended` is **not** the
  discriminator: its retrieval code ends `i State'["SUSP" s {*}=1`, so an already-suspended process
  reports it false, conflating "already suspended" with "cannot be suspended".
- **The pid spelling.** `Property Id As %Integer` takes `GetRequiredQueryParam("id")` verbatim and
  hands it to `%OpenId`. Probed through `AdminPort.Invoke("Process","GET",...)` against pid 837:
  `"837"`, `"0837"`, `"+837"` and `"837 "` all answered 200 with `Pid` 837; `" 837"` and `"837.0"`
  answered 404. Four spellings, one process - `process` needs AD-13's `integer` rule.
- **Identifying a system process.** The authoritative key is **`JobType`**, a JSON integer,
  `GET`-only - the `CONTROLPANEL` ROWSPEC behind `LIST` has no such column (confirmed against a real
  LIST row). `%SYS.ProcessQuery.JobType`'s own doc says to use the macros in `%syPidtab.inc`, which
  name `FOREJOB=1`, `APPMODE=2`, `FORAPPJOB=3`, `CPTYPE=4`, `WDTYPE=5`, `GCTYPE=6`, `JDTYPE=7`,
  `AUXWDTYPE=10`, `LICENSESRV=13`, `RCVDMNTYPE=21`, `CMTMASTSRV=24`, `CSPSRV=27`, `ODBCSRV=28`,
  `DBXDMNTYPE=30`, `TASKTYPE=36`, `CLNDTYPE=38`, `MONITORTYPE=41`, `MONAPPTYPE=42`,
  `WORKQUEUESRV=59` and more.
- **`CanBeTerminated` is not a system-process test**, measured over the whole population
  (`SELECT JobType, COUNT(*), SUM(CanBeTerminated), SUM(CanBeSuspended) FROM %SYS.ProcessQuery GROUP
  BY JobType`, 31 rows): the 17 core daemons answer 0/0, but **`TASKTYPE` (the Task Manager) answers
  1/1 and all nine `WORKQUEUESRV` workers answer 1/1**. The vendor will suspend or kill the Task
  Manager. Confirmed individually through OcuPilot's own port: GET `id=1053` answered `JobType=36,
  Routine=%SYS.TaskSuper.1, UserName=TASKMGR, CanBeSuspended=1, CanBeTerminated=1`. `NameSpace` is
  not usable either (the six core daemons answer `""`, and `%SYS` is also where an operator's own
  session may sit); `UserName` and `Routine` are corroboration, not tests; `$$$INTERACTIVEJOB` /
  `$$$BACKGROUNDJOB` are a trap, since `BACKGROUNDJOB` includes the Work Queue workers and
  `TASKTYPE` is in neither.
- **`%SYS.ProcessQuery`'s own gates** (read in `irislib/`, re-fetched from the instance to confirm
  the line numbers still hold - 2483 lines, 418-427 byte-identical to the export). `AllowToOpen`,
  line 425, is an OR of four:
  `i $SYSTEM.Security.Check($$$AdminManageResourceName,$$$PermUseName)||$$$IOwnSYSDBWrite||$$$IOwnSYSDBRead||(+Pid=+$j) q $$$OK`.
  **AD-29's citation of `ProcessQuery.cls:425` is correct as written.** It is reached from `%OnOpen`
  (line 939), so it gates `RunGet`, `RunSuspend`, `RunResume` and `RunTerminate` alike.
  `VariableByPidExecute` line 1494 is **narrower** - no IRISSYS-read arm - and `ObjToJson` `Throw`s
  on its error, so a caller with IRISSYS read but not `%Admin_Manage:USE` passes `AllowToOpen` and
  then dies inside the GET. `CONTROLPANELExecute` line 994 carries the same narrower check, which is
  what `AdminPort.cls:182` `QUERYPAIRS` already records for `Process/LIST`. The screen declares all
  three pairs, so the declared set covers both; **AD-29's second half - running it as a real
  least-privileged principal on a throwaway - is owed by the implement stage**, not by this plan.

### The action-style seam, as 5.11 left it

- `src/OcuPilot/Screen/Tool/Write.cls`: `READTYPE` `:55` (`"GET"`), `WRITETYPE` `:60` (`"PUT"`),
  `SENDSBODY` `:65` (1), `STATEFIELD` `:73` (`""`), `ReadType()` `:90`, `WriteType()` `:96`,
  `SendsBody()` `:102`, `StateField()` `:109`, `StateDiff()` `:124` -
  `ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status`,
  whose contract (doc `:114-119`) is that Mint calls it once after the fresh read and **refuses the
  mint when `pProblem` is non-empty**. `FieldRows()` `:214` exits at `:224` when `SendsBody()` is 0.
  `View()` `:338` is `[ Final ]`. `PrivilegePairs()` is **not** here - it is `Base.cls:71` and each
  write tool overrides it; `WRITERESOURCE`/`WRITEPERMISSION` are likewise per-tool.
- `src/OcuPilot/Screen/Tool/TaskResume.cls` is the worked example to copy: `READTYPE = "INFO"` `:35`,
  `WRITETYPE = "RESUME"` `:41`, `SENDSBODY = 0` `:46`, `WRITERESOURCE`/`WRITEPERMISSION` `:53`/`:55`,
  `STATEFIELD`/`STATEBEFORE`/`STATEAFTER` `:63`/`:65`/`:67`, `SettableFields()` `:90` returning
  `..AdmittedFields()`, `PrivilegePairs()` `:114`, `StateDiff()` `:132-157`.
- `Mint.cls`: read at `:118` via `ReadTypeOf(pToolClass)` (`:396`); `StateDiff` at `:149` with the
  refusal at `:155`; `If '$ClassMethod(pToolClass, "SendsBody") Set tUnchanged = 0` at `:166`;
  fingerprint at `:170`.
- `Confirm.cls`: `ToolSendsBody` at `:373`, body built only when it sends one `:375`, write issued
  with `ToolWriteType` at `:391`, fingerprint re-read with `ToolReadType` at `:586`; resolvers
  `:646`, `:660`, `:674`.
- `Disclosure.cls`: `Rows()` `:46`, bodyless exit `:50`, `SendsBody()` `:84` (fails **open**,
  defaults 1).
- `src/OcuPilot/Kernel/Proposal/Fingerprint.cls`: `Of()` `:27`, `Canonical()` `:54`; the
  complete-property-set invariant is stated at `:4-7`.

### The port

- `AdminPort.cls`: `TYPESUFFIXES` `:118`, `MUTATINGTYPES = "PUT,RESUME"` `:144`,
  `BODYLESSTYPES = "RESUME"` `:153`, `QUERYPAIRS` `:182` (already carries
  `Process/LIST=%Admin_Manage:USE|%DB_IRISSYS:WRITE`), `BARETYPES` `:193` (keyed
  `<endpoint>/<suffix>` at `:786` - the precedent DW-1464 asks for). `Invoke()` `:385`; the
  object-body refusal is `:422`,
  `If $ListFind($ListFromString(..#MUTATINGTYPES), pType) && '$ListFind($ListFromString(..#BODYLESSTYPES), pType) && '$IsObject(pBody)`
  - **suffix-only, with no endpoint qualification**, which is DW-1464 at its origin.
  `HttpMethodFor` `:771`, `EndpointType` `:783` (unknown suffix answers `""` at `:791`),
  `ImplementsRead` `:805` (an overridden `Run` is trusted at `:807` - `Process` overrides `Run`),
  `Sequence`'s mutating-and-async refusal `:913-924`.

### Identity, the prohibited set and coverage

- `EntityType.cls:34` `TYPES` already contains **`process`** (20th value). `Count()` `:60` is 29,
  asserted at `src/OcuPilot/Test/Descriptor.cls:1287`. **No enum change.**
- `EntityRef.cls:59`
  `IDRULES = "web-application:foldcase-striptrailingslash,user:foldcase,auditing-configuration:singleton,task:integer"`;
  `:64` `IDRULENAMES`; `RULEINTEGER` `:87`; `NormalizedId()` `:231-244` with the verbatim fallback at
  `:234`; `PlainInteger()` `:254-266`. `process` has **no** rule today. The client twin
  `ui/src/app/core/entity-ref.ts:83` already implements `integer`, and
  `ui/tools/screen-mirror.mjs:161` `IMPLEMENTED_ID_RULES` already lists it - so adding
  `process:integer` is **one roster entry** with no new rule name and no client change.
- `Prohibited.cls:88` `COVEREDTYPES = "web-application,user,auditing-configuration,task"`; type
  constants `:91`/`:93`/`:95`/`:97`; `CoveredTypes()` `:159`; `PermittedChangeFields()` `:198-204`
  (task falls through to `Quit ""` at `:203`); `AlwaysProhibitedFields()` `:214-219`; the
  fail-closed arm for a listed type with no branch `:259-263`; dispatch `:283-295`. Branches:
  `WebApplication()` `:345-390`, `User()` `:409-460`, `Auditing()` `:475-478`, `Task()` `:493-496`.
  `Task()` is a one-line delegation to `ReviewedFewOnly()` `:503-525` - the shape to start from,
  extended with the two target predicates. `UncoveredWriteTools()` `:313-335`. **5.11's fix**, which
  5.12 depends on: `Changed()` `:858`, skip at `:870`
  `If (pStateField '= "") && (tField = pStateField) Continue`, fed by `StateFieldOf()` `:954`.
- `src/OcuPilot/Test/Prohibited.cls`: the `CoveredTypes()` literal at `:179`, and **`process` is the
  first entry of the uncovered-example list at `:167`** and is re-used at `:182` to seed a row
  confirmed 403. Covering `process` reddens all three sites; the three edits are inseparable.
  `UncoveredWriteTools()` assertion `:391-406`.
- `src/OcuPilot/Test/ToolWrite.cls`:
  `TestEveryWriteToolsRequestTypeAgreesWithThePortsBodylessRoster()` `:540` - `:563` asserts the
  tool's `WriteType()` is a `MUTATINGTYPES` member and `:565` asserts
  `$$$AssertEquals(tExempt, 'tSends, ...)`, i.e. a `BODYLESSTYPES` member **exactly when**
  `SendsBody()` is 0. It loops every registry `write` entry, so a new tool is covered automatically
  **only if both halves land together**. Registration row: `:77`; the per-tool analogue to copy is
  `:468-523`.
- `src/OcuPilot/Test/SurfaceCoverage.cls`: `XData Coverage` `:56`, `<screen>` rows `:59-99`,
  `<tool>` rows `:100-103` alphabetical (`permissions.users.update`, `security.auditing.update`,
  `tasks.schedule.resume`, `webapp.list.update`). `osmgmt.processes.*` sorts first.
- `src/OcuPilot/Screen/Tool/FieldLists.cls:147` **already carries the `Process` entry** in the
  admits-nothing shape - `{"endpoint":"Process","source":"none","method":"","class":"","type":"","envelope":"","rows":[]}`
  - the same shape as `Task.Manager` `:466` and `Lock` `:130`. `ui/tools/field-lists.mjs` builds
  `ToolFields.cls` only from `Classification.cls` and never reads the tool classes, so **a bodyless
  tool needs no Classification entry, no `ToolFields` row and no `FieldLists` change**.

### The descriptors

- `src/OcuPilot/Screen/Descriptor/ProcessList.cls` (125 lines): route `os-management/processes`
  `:80`, `built: true` `:85`, archetype `list` `:84`, `refreshes: true` at 5/10/30/60 `:86-87`,
  privileges `%Admin_Operate:USE`, `%Admin_Manage:USE`, `%DB_IRISSYS:READ` `:88`, entity `process`
  scope `instance` `:89-92`, `"id": {"kind": "single", "parts": []}` `:93`, no `primaryAction` `:94`,
  no `rowActions` `:95`, `toolIdentifier "osmgmt.processes"` `:121`, classic page
  `%CSP.UI.Portal.Processes` `:99`. Read source `{"port": "admin", "endpoint": "Process", "type":
  "LIST"}` `:102`; `read.fields` `:103` is
  `["Pid", "Username", "Nspace", "Routine", "State", "Commands", "Globals"]`; `context.fields` `:96`
  is the same seven. Seven table columns `:109-117`. **No `rowGet`, no `fingerprintExcludes`, no
  banner.** Its doc `:19-26` names 5.12 as the owner of suspend and resume and records that
  `CanBeSuspended`/`CanBeResumed` are deliberately withheld while no control gates on them.
- `src/OcuPilot/Screen/Descriptor/ProcessDetails.cls` (123 lines): route
  `os-management/processes/details` `:42`, `sideBarPosition: 0` `:45`, archetype `detail` `:46`,
  `built: true` `:47`, `refreshes: true` `:48-49`, the same three pairs `:50`, entity `process`
  `:51`, `parentScope` `os-management/processes` `:54`,
  `"id": {"kind": "composite", "parts": ["Pid"]}` `:55`, `toolIdentifier "osmgmt.processdetails"`
  `:119`. Read source `{"port": "admin", "endpoint": "Process", "type": "GET"}` `:67-71`; one
  criterion `{"param": "pid", ..., "maxLength": 10, "vendorParam": "id"}` `:80-84`; `read.fields`
  `:72` is 27 of the 50 GET keys. **`JobType` is not among them**, so a refusal resting on `JobType`
  reads a field the operator is not shown - declaring it is a one-line fix this story should make.
- **Spelling split, load-bearing:** the list says `Username`/`Nspace` (LIST keys), the details say
  `UserName`/`NameSpace` (GET keys). `ScreenRead`'s drift guard holds each to a live key, which is
  part of why the list cannot name GET-only fields.

### The AD-43 roster

Both Processes screens declare `refreshes: true`, so both pause on a live `process` proposal.
Enforcement: `Registry.cls:412` `RefreshProblem()` from the loop at `:260`; mirror
`ui/tools/screen-mirror.mjs:679-717`; generated field `ui/src/app/core/screens.generated.ts:333`.
EXPERIENCE.md's roster bullet is `:652` (seven names), the pause rule `:653`, the chip strings
`:290`, the per-screen rows `:91`-`:92`. **Observation for the lead, not this story's to fix:**
eight descriptors declare `refreshes: true` (the seven EXPERIENCE.md names plus
`DatabaseFreeSpace`) while AD-43 says the set is seven and that a screen joins "by declaring it in
its descriptor **and** appearing in that roster, never by either alone".

### Test arming, the fixture and the browser precedents

- `src/OcuPilot/Test/ProhibitedRoute.cls` is the pattern: `ARMINGVARIABLE` `:28`
  (`OCUPILOT_ALLOW_PRINCIPALS`), `AUDITVARIABLE` `:36` (`OCUPILOT_ALLOW_AUDIT_TOGGLE`), read in
  `OnBeforeAllTests` `:111` with `If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1` `:113` quitting
  `$$$ERROR` `:114`. A **real process-environment read**, and a hard `%Status` error that reddens the
  class - not a skip.
- `scripts/ci-throwaway.sh:180-252` sets eight arming variables, each preceded by its `# classes:`
  comment block (`OCUPILOT_ALLOW_AUDIT_TOGGLE` `:245` with `# classes: AuditingUpdate,
  ProhibitedRoute` at `:244`).
- `ui/tools/ci.test.mjs:1648-1798` pins the two sides against each other: `declaredArmingRosters`
  `:1658-1677` parses the shell file (a non-comment line **resets** the pending class list at
  `:1673`, so the comment must sit immediately above its variable), `armedClasses` `:1721-1737`
  derives from any `Parameter <Name> = "<matching value>"` or any `GetEnviron("...")` under
  `src/OcuPilot/Test/`, and the test at `:1739` `deepEqual`s the sets with a floor of seven at
  `:1757`. **Both sides are derived, so a new arming variable needs no edit to `ci.test.mjs`** - one
  comment block plus one setting in the shell script, and one class declaring it. The class list is
  order-sensitive (`deepEqual` over a sorted derivation).
- `src/OcuPilot/Test/TaskResume.cls` (633 lines, nine Test methods) has **no arming check** -
  confirmed: no `GetEnviron` anywhere in the file and no parameter whose value matches
  `OCUPILOT_ALLOW_*`. That is DW-1458.
- `ui/browser/task-resume.browser-spec.mjs:73-86` is the guard to copy: `assert.notEqual(config.container, LIVE_CONTAINER, ...)`
  then `assert.match(config.container, /-ci$/, ...)`; the `after` hook `:103-107` repeats it as
  `if (!/-ci$/.test(config.container)) return;` before cleaning up.
- `ui/browser/processes.browser-spec.mjs` (709 lines) exists and is **read-only by charter** - its
  header `:7-10` says it never terminates, suspends, resumes or broadcasts, and names 5.12, 7.8 and
  16.6 as the owners. It has no `-ci` guard, consistent with that. Its AC3 leg `:410` uses `WRTDMN`
  as the auto-refresh selection anchor, so that pid is the one a suspend spec must **avoid**.
  Other precedents: `auditing-write` (5.10's confirm end-to-end), `change-highlight` (the two-second
  budget and scroll), `navigate` (announcement timing), `task-resume:483` (the AD-43 pause leg).
- `ui/src/app/shell/list-page.ts`: `selectFromRoute` doc `:144-157`, body `:158-168`, called on
  mount `:112` and on every `NavigationEnd` `:120`; `ownIdSegment` imported at `:5`. The Processes
  list is descriptor + generated mirror only (no `processes.page.ts`); **Process details has its own
  page and store** - `ui/src/app/areas/os-management/process-details.page.ts` (249 lines) and
  `.store.ts`, registered at `ui/src/app/shell/screen-outlet.ts:91`.
- `src/OcuPilot/Test/ProcessDetails.cls` (223 lines, six Test methods) is the only existing
  `*Process*` test class; there is **no** `Test/ProcessList.cls`. The list's privilege coverage sits
  in `src/OcuPilot/Test/WireSecurityRead.cls`: principal `OcuPilotWireProcess` `:96`,
  `TestTheProcessesListsPairSetIsEnforcedForARealPrincipal` `:537` with a literal of the whole
  os-management side-bar JSON at `:547`, and `TestTheProcessDetailsPairSetIsEnforcedForARealPrincipal`
  `:666`. **Any new privilege pair would redden `:547`** - this story adds none.

## Tasks & Acceptance

- [x] [Review] Matrix row 1's `destructive` clause: set `ProcessSuspend.DESTRUCTIVE` to `0` and
  correct the four assertions that mirror it (`ToolWrite.AssertActionWrite`, `ProcessControl:157`,
  `process-control.browser-spec.mjs:316`, and task 2's own pin) so the minted proposal's flag reads
  `false` for `osmgmt.processes.suspend`. The matrix and `EXPERIENCE.md` govern; do **not** edit the
  matrix to match the code. Terminate stays destructive — `EXPERIENCE.md` names "Terminate 4127" as
  the `button-destructive` example. Do not touch `AuditingUpdate.cls` (DW-1467, another story's).

These are planned against the **amended** AD-51. Task 3 is the only one the amendment changes; every
other task stands as written.

**Execution:**

1. `src/OcuPilot/Port/AdminPort.cls` -- admit `SUSPEND` as a bodyless mutating request type, and
   **scope the bodyless exemption to an `(endpoint, type)` pair** rather than a bare suffix
   (DW-1464): `:422`'s `$ListFind($ListFromString(..#BODYLESSTYPES), pType)` becomes a keyed lookup
   on `pEndpoint _ "/" _ pType`, on the `BARETYPES` precedent at `:786`. `RESUME` is already in both
   rosters for `Task.CRUD`; this story is the first to put a second endpoint behind the same
   suffix, which is what makes the coincidence real rather than hypothetical. Keep `Sequence`'s
   mutating-and-async refusal firing.
2. `src/OcuPilot/Screen/Tool/ProcessSuspend.cls` and `ProcessResume.cls` -- the two tools.
   `TOOLNAME` `osmgmt.processes.suspend` / `osmgmt.processes.resume`, `DESCRIPTORCLASS` the
   Processes list, `Endpoint()` `"Process"`, `IdArgument()` `"Pid"`, `IdParam()` `"id"`,
   `SettableFields()` empty, `READTYPE = "GET"`, `WRITETYPE` `"SUSPEND"` / `"RESUME"`,
   `SENDSBODY = 0`, `WRITERESOURCE "%Admin_Operate"`, `WRITEPERMISSION "USE"`, `PrivilegePairs()` on
   the `TaskResume` pattern, `STATEFIELD = "State"`, and a `StateDiff()` reading `State` for `SUSP`:
   suspend refuses an already-suspended target, resume refuses one that is not suspended. Suspend is
   `Destructive()` 0, as resume is: proposing the opposite reverses either (Spec Change Log,
   2026-09-22).
3. `src/OcuPilot/Screen/Tool/Write.cls` and `src/OcuPilot/Kernel/Proposal/Mint.cls` /
   `Confirm.cls` -- **the amended AD-51 seam**: a per-tool declared fingerprint subject, defaulting
   to empty, which means today's behavior (the descriptor's exclusions over the whole payload).
   Both process tools declare `Pid` and `State`. A declared subject field that is not a live key of
   the tool's own read is refused, and an empty declared subject on a tool that declares one at all
   is refused. Validation runs through the **same** builder and the **same** declared-names
   extraction that validates `fingerprintExcludes` (`Registry.cls:2005`), never a second
   validator (DW-1206), and a **build-time structural guard** fails when an action tool's
   declared subject omits its scoped target identity or its precondition field.
4. `src/OcuPilot/Kernel/Proposal/Prohibited.cls` -- add `process` to `COVEREDTYPES`, a `TYPEPROCESS`
   constant, and a `Process()` branch. `PermittedChangeFields("process")` is empty, so any changed
   field is refused. The branch adds AD-10's two target predicates, each reading the fresh read:
   **the caller's own process** (the decision in `## Blocking Condition`), and **an IRIS system
   process** -- an **allow-list** of `JobType` values the agent may act on (`FOREJOB` 1, `APPMODE` 2,
   `FORAPPJOB` 3, `IDIRECTSRV` 26, `CSPSRV` 27, `ODBCSRV` 28, `CALLINTYPE` 47), refusing every other
   value including one the table does not name. A deny-list is wrong: `%syPidtab.inc` grows, and
   `CanBeTerminated` is measurably true for the Task Manager and every Work Queue worker. Both
   refusals carry an explanation naming why. Evaluated inside AD-34's transition, as every other
   predicate is.
5. `src/OcuPilot/Kernel/EntityRef.cls` -- add `process:integer` to `IDRULES` `:59`. No new rule name,
   no `IDRULENAMES` change, no client change, no `IMPLEMENTED_ID_RULES` change: 5.11's `integer` rule
   already exists on both sides. Measured: `"837"`, `"0837"`, `"+837"` and `"837 "` are one process.
6. `src/OcuPilot/Screen/Descriptor/ProcessList.cls` -- declare the fingerprint subject's two names
   if the amended seam requires them read-declared (`State` already is; `Pid` already is). Leave the
   seven table columns, the absent row actions and the absent `rowGet` exactly as they are, and
   correct the doc comment's 5.12 paragraph at its origin rather than appending to it.
7. `src/OcuPilot/Screen/Descriptor/ProcessDetails.cls` -- add `JobType` to `read.fields` and
   `context.fields` so the screen shows the field the system-process refusal rests on. It is a live
   GET key (measured). No table column is required; no privilege pair changes, so
   `WireSecurityRead.cls:547`'s literal is untouched.
8. `src/OcuPilot/Test/Prohibited.cls` -- update the four-type literal at `:179` to five, replace
   `process` in the uncovered-example list at `:167` and at `:182` with a type that is still
   uncovered (`role`, `resource`, `service` or `database`), and keep `:391`'s empty
   `UncoveredWriteTools` assertion green.
9. `src/OcuPilot/Test/ProcessControl.cls` -- the story's own instance suite, **armed** (task 11):
   the two mints and their state rows, each direction's wrong-state refusal, the bodyless call
   reaching the port with the `id` parameter and no body, the fingerprint refusing a target moved in
   between, the two-spellings-one-key leg, the `Prohibited` field refusal, the own-process refusal,
   the system-process refusal with its allow-list floor, and the marker and ledger row. It `JOB`s
   its **own** probe process, captures its pid, and halts it on every exit path -- it never touches
   a daemon, the Task Manager, a Work Queue worker or `WRTDMN`.
10. `src/OcuPilot/Test/ProhibitedRoute.cls` -- one least-privileged leg over the wire for each tool:
    an account short of the declared pairs is refused 403 naming the pair, and the process keeps
    running. This is AD-29's second half, which `ResourcesOR()` alone cannot establish.
11. `scripts/ci-throwaway.sh` -- two new arming variables with their `# classes:` comment blocks
    immediately above each setting: `OCUPILOT_ALLOW_PROCESS_CONTROL` (`# classes: ProcessControl`)
    and `OCUPILOT_ALLOW_TASK_CONTROL` (`# classes: TaskResume`). No edit to `ui/tools/ci.test.mjs`:
    both sides of its roster are derived. (DW-1458)
12. `src/OcuPilot/Test/TaskResume.cls` -- read `OCUPILOT_ALLOW_TASK_CONTROL` in `OnBeforeAllTests`
    on the `ProhibitedRoute.cls:113` pattern, so 5.11's class can no longer create and resume a task
    on a live instance. (DW-1458)
13. `src/OcuPilot/Test/ToolWrite.cls` -- the two tools' registration and declaration rows: their
    pairs at `USE`, their empty settable sets, their `SUSPEND`/`RESUME` write types, their `GET` read
    type and their `Destructive()` values. `:540`'s roster equality covers them once both port halves
    land.
14. `src/OcuPilot/Test/SurfaceCoverage.cls` -- the two `<tool>` rows at the head of the alphabetical
    block `:100-103`.
15. `src/OcuPilot/Test/Descriptor.cls` -- the `ProcessDetails` read-field assertions for `JobType`,
    and any `ProcessList` assertion task 6 moves.
16. `ui/browser/process-control.browser-spec.mjs` -- the end-to-end leg against a probe process the
    spec creates: the card's one state row, Confirm, the list re-fetching in place and highlighting
    the row within two seconds, and the auto-refresh pause while the proposal is live. Refuses in
    **both** hooks unless `OCUPILOT_BROWSER_CONTAINER` names a `-ci` throwaway, on the
    `task-resume.browser-spec.mjs:73-86` pattern.
17. `ui/tools/screen-mirror.mjs` and the generated mirror -- regenerate after tasks 6 and 7; the
    `process:integer` roster entry needs no mirror change.

**Acceptance Criteria:**

- **Given** the Processes list with a row selected, **when** the user asks the agent to suspend that
  process, **then** a proposal is minted from a fresh `Process` `GET` naming the pid, with one diff
  row `State: Running -> Suspended` and no unchanged-fields caption; and **when** the user confirms,
  **then** `Process` `SUSPEND` is issued with the `id` query parameter and no body, as that user,
  through the same endpoint the screen reads.
- **Given** a suspended process, **when** the agent proposes a resume, **then** the same path runs in
  the other direction; and **given** a process that is not suspended, **then** the resume is refused
  at the mint - the vendor's `RunResume` has no guard of its own, so this refusal is OcuPilot's.
- **Given** the target is the user's own process, **when** the action is proposed, **then** it is
  refused with an explanation naming that, from the kernel's one prohibited-set home, evaluated
  inside the write transition.
- **Given** the target is an IRIS system process, **when** a terminate is proposed, **then** it is
  refused on the instance; and **given** the advertised tool set, **then** no terminate tool appears
  in it and `AdminPort` admits no `TERMINATE` or `DELETE` request type.
- **Given** `Process` publishes no body template - confirmed on the instance - **when** the tools are
  built, **then** they are action-style with no settable fields and no hand-typed field list, and
  `ToolFields.cls` carries no row for either.
- **Given** the write completes, **when** the list re-fetches, **then** the row highlights within two
  seconds and the audit database carries one marker with that proposal id, that tool, the scoped
  `(process, instance, <pid>)` target and that user, with the ledger row reading marked.
- **Given** a live `process` proposal, **when** Processes or Process details is open, **then** its
  auto-refresh pauses with the chip and resumes on close (AD-43).
- **Given** a caller holding none of the three declared pairs, **when** they confirm, **then** they
  are refused 403 naming the failed pair and the process keeps running.
- **Given** the surface floor, **when** the suite runs, **then** both tools have coverage rows,
  `UncoveredWriteTools` is empty, and every write tool's `WriteType()`/`SendsBody()` agrees with the
  port's two rosters.
- **Given** `iris_execute_tests` or `ci-runner` pointed at an instance with neither arming variable
  set, **when** `OcuPilot.Test.ProcessControl` or `OcuPilot.Test.TaskResume` runs, **then** the class
  refuses in `OnBeforeAllTests` naming the variable, so neither can suspend a process or resume a
  task on a live instance. (DW-1458)
- **Given** two endpoints declaring a request type of the same name, **when** one needs a body and
  the other does not, **then** the port's bodyless exemption applies to the `(endpoint, type)` pair
  and not to the name. (DW-1464)

## Spec Change Log

- **2026-09-22, lead — matrix ambiguity resolved, `destructive` is `false` for the suspend.** Not a
  product call: two planning artifacts had already decided it and the code disagreed with both.
  `EXPERIENCE.md`'s `confirm-dialog` row lists "Suspend Task Manager, disable auditing, disable
  OcuPilot's web service" as the **non-destructive warnings** that use `button-primary`, and
  reserves `button-destructive` for "Delete Nightly purge" and "Terminate 4127"; `epics.md` calls
  the same three cases warnings. So matrix row 1 is right, `ProcessSuspend.DESTRUCTIVE` is wrong,
  and the fix is the parameter plus the four assertions that mirror it. The sibling defect —
  Story 5.10's `security.auditing.update` declaring `DESTRUCTIVE 1` against the same clause — is
  **not** this story's to fix and is filed as **DW-1467**.

- **2026-09-22, lead, orchestrator-approved.** The `intent gap` is resolved by a spine amendment
  rather than by re-planning: AD-51 gains a declared **fingerprint subject** for action-style writes
  and AD-6's selection sentence is corrected at its origin so the two do not disagree. Five
  conditions bind the implementation - scope it to action writes only; correct AD-6 (done, in the
  same commit); the subject must carry the scoped target identity **and** the action's precondition
  field (`State`), enforced by a build-time guard rather than by review; validate it through the
  **same** builder that validates `fingerprintExcludes`, never a second one; and falsify **both**
  directions, a subject field moving must still refuse and a non-subject counter moving must not.
  AC2 takes the broad reading of "the user's own process": any process the confirming user owns.
  The measurement in `## Blocking Condition` stands, with its idle-daemon claim corrected there.

## Review Triage Log

### 2026-09-22 — Review pass

- verdicts: 17 findings — high 0, medium 4, low 9, false 4, maybe-false 0
- findings:
  - `[medium]` `[patch]` The two AD-10 refusals in `Prohibited.Process()` were never reached through
    the shipped `Prohibits()`, so deleting either refusing branch left the suite green — the tests
    asked the predicates through `ProcessControl.Verdict()`, which re-implements the dispatch order.
    Patched: `TestTheShippedProhibitsRefusesTheOwnJobAndASystemProcess` drives `Prohibits()` for the
    confirming job and a discovered system pid; deleting either branch now reddens only its half.
  - `[medium]` `[patch]` (grouped with the row above) The refusals were exercised at the predicate,
    not at the envelope the matrix states them at. Same root cause, same patch.
  - `[medium]` `[patch]` The registration-time fingerprint-subject guard in
    `Screen.Tool.Registry.ListTools` had no test — the five probes sit inside `EXCLUDEDPACKAGE`, so
    only the pure function was verified. Patched: `OcuPilot.Test.SubjectProbe.Registry` admits the
    probe package and `ToolWrite.TestAnInadequateFingerprintSubjectStopsTheToolListBuilding` asserts
    the list refuses to build, naming the class and its problem.
  - `[low]` `[patch]` The "read carrying no `State`" arm asserted only `AssertStatusNotOK`, so it
    could not tell the documented 400 from an internal failure later in the mint. Patched: both
    directions now assert the status and the problem sentence.
  - `[low]` `[reject]` `ProhibitedRoute` starts a process and a task without the two arming
    variables this story added. Rejected: that class already refuses unarmed under
    `OCUPILOT_ALLOW_PRINCIPALS` (`:28`, `:113`) and `OCUPILOT_ALLOW_AUDIT_TOGGLE`, so it cannot run
    on an unarmed instance at all; the only available fix adds two more guards and moves
    `ci.test.mjs`'s order-sensitive roster with them.
  - `[low]` `[defer]` Several ACs carry their mutation only in the test's doc comment, not as a
    `mutation:` line in `## Verification`. Deferred — eight container round trips, outside this
    rework's item.
  - `[low]` `[defer]` `ProhibitedFixture.Digest` still calls the three-argument `Fingerprint.Of`.
    Deferred — no current caller passes an action-style tool, so nothing is wrong today; Story 5.13
    is the first that would be.
  - `[low]` `[reject]` `Mint.cls:175-179`'s projection-failure branch has no test. Rejected as
    theoretical: `StateDiff` refuses a read missing `State` first and the registration guard refuses
    a subject naming an undeclared field, so no caller reaches it.
  - `[false]` `[reject]` The spine amendment authorising the declared subject is absent from the
    diff. Refuted: the amendment IS the baseline commit `c904efb`, cited by `## Blocking Condition -
    RESOLVED`, the `## Spec Change Log` and `## Design Notes`.
  - `[false]` `[reject]` The changed-field matrix row is tested at the set's API rather than at a
    proposal. Refuted: both tools admit no settable field, so no proposal can carry one;
    `ToolWrite:530` pins the refusal at the tool-argument surface and `ProcessControl:317` at the
    set's — together the outermost reachable surfaces.
  - `[low]` `[reject]` The `changed` event's cardinality and `action` verb are not pinned for this
    story. Rejected: AC6's observable — the row highlighted within two seconds of the confirm — is
    pinned end to end by the browser spec and cannot pass unless the event fired; the event's
    internals are Story 5.7 machinery pinned there.
  - `[low]` `[defer]` AC7's Process-details half has no browser leg. Deferred — a second browser
    test, more than a direct correction.
  - `[low]` `[reject]` Most legs run against fixture canned reads rather than the instance.
    Rejected as spec-bound: `## Design Notes` chooses arming the predicate's input deliberately, and
    a real suspend/resume leg plus the browser spec cover the instance side.
  - `[false]` `[reject]` Scope widened to the shared kernel surface and `ListTools` can now fail
    registration. Refuted: a build-time structural guard is condition three of the
    orchestrator-approved amendment; the actionable half was the missing test, patched above.
  - `[low]` `[reject]` (grouped with the arming row) Three arming mechanisms where the intent names
    one. Same root cause, same rejection.
  - `[medium]` `[defer]` The broad ownership reading leaves almost nothing proposable on a
    single-user instance. Deferred — spec-bound (AC2's broad reading was orchestrator-decided), so
    it is a decision-sheet question rather than a code fix.
  - `[false]` `[reject]` Two opposite readings of one `EXPERIENCE.md` clause remain in the tree.
    Refuted as not a new finding: the lead filed it as DW-1467 before this pass began.

- **Matrix ambiguity (`destructive` for `osmgmt.processes.suspend`) - closed 2026-09-22.** Resolved
  the way the Spec Change Log entry of the same date directs: the flag is `false`, the matrix and
  `EXPERIENCE.md` govern, and the code moved to them. `DW-1467` carries the sibling inconsistency in
  `security.auditing.update`, which this story did not touch.

## Design Notes

**Governing ADs (Rule 6).** AD-51 (action-style writes - and the AD this story's blocking condition
proposes amending), AD-1 (in-process, as the user), AD-2 (only `AdminPort` names an `%Api.Admin.*`
class, so admitting `SUSPEND` happens there), AD-3 (`Process` publishes no template and needs none;
the field list is empty by derivation, not hand-typed), AD-5 (one descriptor; tool identity
independent of the screen's name), AD-6 (minted, fingerprinted, single-use, closed confirm channel),
AD-8 **as amended 2026-09-21** (the screen's own pair set, administrative resources at `USE`, never
`WRITE`), AD-10 (the prohibited set has one home, is defined by effect, and names "Terminating IRIS
system processes" explicitly), AD-12/AD-39 (one envelope, two renderings), AD-13 **as amended** (the
scoped triple, and this story's own per-type canonicalization rule), AD-14 (one change event; screens
re-fetch, never patch), AD-15 (ordinary case - this write does not close the audit channel, so a
failed marker is "done · audit not marked"), AD-24 (a declared read field reaches screen context and
the tool's view - which is why `Variables` is not declarable), AD-26 (`ShouldRunAsync()` is not
overridden, so these are synchronous), AD-29 (the pair set established two ways together; this
endpoint is the AD's own worked example), AD-30, AD-34 (one atomic transition, one lock per canonical
target), AD-35 (the process variable table is the sensitive payload this story keeps off every
surface), AD-36, AD-40 (confirm is user-originated; every gate is at the write), AD-41, AD-43 (both
Processes screens pause), AD-44 (the classic keys, unchanged), AD-9, AD-31, AD-33, AD-37, AD-45,
AD-46 hold and this story changes nothing in them.

**Consumes:** 5.1-5.7 (mint, card, atomic confirm, execution as the user, the prohibited set, the
marker, the change bus, the toast and the highlight); 5.8 (the `USE` pair rule); 5.9 (the per-type id
rule and the per-type `Prohibited` block); 5.10 (the declared-names union and the arming-variable
pattern); 5.11 (**the whole action-style seam** - `ReadType`/`WriteType`/`SendsBody`/`StateField`/
`StateDiff`, the port's two rosters, `Prohibited.Changed`'s state-field skip, and `list-page`'s
own-id-segment selection); 2.9 (the Processes list); 6.8 (Process details). Epic 13's coverage gates.

**Consumed-by:** Story 5.13 is the third action-style write (`SYS.ApplicationError` deletes, AD-48)
and inherits whatever the blocking condition's amendment settles. Stories 7.8 and 16.6 add the
Processes row actions and the Terminate dialog over these tools; `ProcessList.cls:19-26` and
`EXPERIENCE.md:92-93` already record that split.

**No consumers in this story for the amended fingerprint-subject seam; the first consumer after these
two tools is Story 5.13.**

**Why the two refusals are armed at their input, not reached through a fixture seam.** Epic 5's
recurring defect is a safety predicate whose refusing branch never runs against the real body - five
instances in 5.9, three in 5.10, one in 5.11 on AD-51 itself. Both of this story's refusals are
reachable **directly**: `Prohibited.Process()` takes the fresh read as an argument, so a test calls
it with a fresh read whose `Pid` is `$JOB`, and with one whose `JobType` is 36, 59 and an unnamed
value - arming the predicate's input rather than replacing the predicate. The system-process leg
carries a non-vacuity floor (at least one allow-listed `JobType` passes) so a predicate that refuses
everything cannot read green. Nothing in this story stubs a safety method.

**Why the system-process test is an allow-list.** Measured over the whole 31-process population, not
one probe: `CanBeTerminated` and `CanBeSuspended` are **1** for the Task Manager (`JobType` 36) and
for all nine Work Queue workers (59), so a refusal resting on them would let the agent suspend the
Task Manager. `NameSpace` is empty for the six core daemons and `%SYS` for an operator's own session,
so it separates nothing. `JobType` with a closed allow-list fails closed on a value
`%syPidtab.inc` gains later, which a deny-list does not.

**DW-1464 is addressed, not declined** (task 1). The entry asks whether `BODYLESSTYPES` should key on
an `(endpoint, type)` pair. 5.12 is the first story where one suffix - `RESUME` - serves two
endpoints, so the global match stops being hypothetical. It is benign **today**, measured:
`Process.NeedsRequestBody()` and `Task.CRUD.NeedsRequestBody()` both exclude `RESUME`. The fix is
mechanical because `BARETYPES` at `AdminPort.cls:786` already keys that way in the same file, and
`Test/ToolWrite.cls:540`'s equality is what keeps the two halves honest afterwards.

**DW-1458 is addressed** (tasks 9, 11, 12), covering 5.11's class as the entry requires. The hazard
is worse here than in 5.11: an unarmed class pointed at a live instance would suspend a real process.
The measured cost is one comment block plus one setting per variable in `scripts/ci-throwaway.sh`,
and nothing in `ui/tools/ci.test.mjs` - both sides of that roster are derived. Note the failure mode
the pattern carries (DW-1452): a throwaway started **before** a variable existed refuses the whole
class, and the class silently does not run. The implement stage must confirm `ocupilot-ci` carries
both new variables before reading any result from either class.

**AC3 is satisfied by absence plus refusal.** The vendor exposes terminate twice - `TYPETERMINATE`
and `RunDelete` delegating to it - so "was never advertised as a tool" is a statement about
OcuPilot, not about the instance, and the spec words it that way. AD-10 requires the refusal be real
on the write path whatever the caller, which is why the `JobType` predicate exists even though no
terminate tool calls it: it is the predicate Stories 7.8 and 16.6 will call.

**Two measurements the implement stage owes before it declares anything.** Which `JobType` values the
throwaway actually presents for an ordinary user session, so the allow-list's floor is exercised
rather than assumed; and AD-29's second half - the three declared pairs run as a real
least-privileged principal against `SUSPEND` and `RESUME` on the throwaway, since `ResourcesOR()`
answers `%Admin_Operate` alone while `AllowToOpen` and `VariableByPidExecute` ask for more.

## Verification

**Targeted, inside the implement loop (loop):**

- `cd ui && node tools/screen-mirror.mjs` -- expected: regenerates cleanly; `git diff` touches only
  `screens.generated.ts`. `node tools/field-lists.mjs` is a no-op for these tools (bodyless).
- `uv run scripts/check-objectscript.py <changed paths>` -- expected: 21 rules pass.
- Load and compile the changed classes through the IRIS MCP tools with `server: "ocupilot-slot-a"`,
  reading the error text rather than assuming a clean compile. **Never suspend a process on
  `ocupilot`.**
- `cd ui && npm run test:tools` and `npm run test:components` -- expected: green (`ci.test.mjs`,
  `entity-ref.test.mjs`, `screen-mirror.test.mjs`, `list-page.spec.ts`, `data-table.spec.ts`,
  `proposal-card.spec.ts`).
- The throwaway `ocupilot-ci` is already up, is **not** pristine, and no session here brought it up
  -- do not tear it down. **Before any result on it means anything:** confirm it carries both new
  arming variables (a container started before they existed refuses the whole class and tests
  nothing -- DW-1452), sync the source to `/tmp/ocupilot-ci/src`, compile it, and run
  `OcuPilot.Install.Installer.Install` -- `ui/tools/ci-runner.mjs` does **not** load source, so a
  green under an unloaded mutation attributes nothing. Then
  `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`
  and re-run the installer -- a browser spec asserts the shipped bundle matches the stamp the
  **installer** recorded, so a `docker cp` alone reddens `about-help-links` for a reason that is not
  the code.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.ProcessControl`
  -- and the same, **one class per invocation, waiting for each to land in `%UnitTest_Result` before
  the next**, for `OcuPilot.Test.Prohibited`, `OcuPilot.Test.ProhibitedRoute`,
  `OcuPilot.Test.ToolWrite`, `OcuPilot.Test.Descriptor`, `OcuPilot.Test.ProcessDetails`,
  `OcuPilot.Test.TaskResume`, `OcuPilot.Test.Proposal`, `OcuPilot.Test.ProposalConfirm`,
  `OcuPilot.Test.SurfaceCoverage`, `OcuPilot.Test.EndpointCoverage`, `OcuPilot.Test.WireSecurityRead`,
  `OcuPilot.Test.AuditMarker`. Expected: each green, totals verified with the `%UnitTest_Result` SQL
  probe rather than the runner envelope. Never two test calls in one message. **After the sweep,
  read back that no probe process survives and that the demo task is suspended again.**
- `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci
  node --test --test-concurrency=1 browser/process-control.browser-spec.mjs
  browser/processes.browser-spec.mjs browser/change-highlight.browser-spec.mjs` -- expected: green.
  Clear `OcuPilot_Kernel_State.Pref` before trusting a local re-run (DW-1447, DW-1448).
- **Rule 19 -- demonstrated on `ocupilot-ci`, each reverted and the tree confirmed byte-identical
  (`git status --short`, `git diff --stat`) after each.** Every one below was applied, the whole
  `OcuPilot` package recompiled in the container, the named class run, and the mutation reverted.

  - `mutation:` drop `Do pRows.%Push(tRow)` from `ProcessSuspend.StateDiff` -> `ProcessControl`
    1/9 failed (the one-row assertion).
  - `mutation:` drop `process` from `Prohibited.COVEREDTYPES` -> `ProcessControl` 5/9 failed.
  - `mutation:` `Quit 0` first in `Prohibited.OwnedByCaller` -> `ProcessControl` 1/9 failed, naming
    the three own-process assertions and leaving the probe's own leg green.
  - `mutation:` add `36` to `Prohibited.ProcessJobTypes` -> `ProcessControl` 1/9 failed (the Task
    Manager leg); `mutation:` answer `""` from it -> 4/9 failed, the allow-list floor among them,
    which is the direction a predicate refusing everything would otherwise pass.
  - `mutation:` `ProcessSuspend.DESTRUCTIVE` back to `1` -> `ToolWrite` 1/18 failed (the
    `AssertActionWrite` flag assertion), `ProcessControl` 1/9 failed (the stored row's flag, which
    is what holds it to the tool's declaration rather than to the column's `0` default), and
    `process-control.browser-spec.mjs` 1/2 failed on the card's destructive treatment.
  - `mutation:` drop `Process/SUSPEND` from `AdminPort.BODYLESSTYPES` -> `ToolWrite` 1/18 failed.
  - `mutation:` drop `process:integer` from `EntityRef.IDRULES` -> `ProcessControl` 1/9 failed (the
    two-spellings leg).
  - `mutation:` empty `ProcessSuspend.FINGERPRINTSUBJECT` -> `ProcessControl` 2/9 failed: the
    counter-moved confirm is refused `PROPOSAL.TARGETCHANGED`, which is the dead path the amended
    AD-51 exists to remove, and the stored payload carries the whole read again.
  - `mutation:` delete the `OwnedByCaller` refusing branch from `Prohibited.Process` -> `ProcessControl`
    1/10 failed, on the own-process half of the dispatch leg alone; delete the `IsActionableJobType`
    branch -> 1/10 failed, on that leg's system-process half. The predicate-level legs, which ask the
    two predicates directly, stay green under both.
  - `mutation:` delete the write branch's `FingerprintSubjectProblem` call from
    `Registry.ListTools` -> `ToolWrite` 1/19 failed, on the registration leg only; the leg that asks
    the guard about the five probes directly stays green.
  - `mutation:` raise instead of refusing in `ProcessSuspend.StateDiff`'s no-State arm -> the new
    400 assertion in `ProcessControl`'s wrong-state leg failed while the pre-existing
    `AssertStatusNotOK` beside it stayed green; shorten `ProcessResume`'s problem sentence -> that
    leg's resume sentence assertion failed alone.
  - `mutation:` run `ProcessControl` with no `OCUPILOT_ALLOW_PROCESS_CONTROL` -> `OnBeforeAllTests`
    refuses naming the variable, 0 methods; the same for `TaskResume` and
    `OCUPILOT_ALLOW_TASK_CONTROL`.
  - The marker emission and `ui/src/app/core/refresh.ts`'s `proposal-open` subscription are pinned
    by `TaskResume` and `task-resume.browser-spec.mjs`, which this story did not change.

**Full runs, once, before `dev_complete` (once, before dev_complete):**

- `cd ui && npm run build && npm test` -- expected: the prebuild checkers pass and both client tiers
  are green. `npm test` does **not** run the browser suite.
- `cd ui && npm run test:browser` -- expected: the whole browser suite green against the redeployed
  bundle.
- The full ObjectScript sweep through `ci-runner.mjs` against `ocupilot-ci`, one class at a time,
  reconciled against `%UnitTest_Result`.
- `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` -- expected: zero
  checks `pending`, `fail = 0`, a non-zero executed count, and `agentwrite` and `auditmarker` both
  pass. Read the skip lines, not the number (DW-1402).
- `bash scripts/lint-docs.sh` -- expected: clean.

## Auto Run Result

Status: done
Blocking condition: none

**This pass closed the one open item and the review that followed it.** `osmgmt.processes.suspend`
declares `destructive` false: `ProcessSuspend.DESTRUCTIVE` is `0` -- declared rather than inherited,
because a reader expects the opposite -- and the four sites that mirrored it moved with it
(`ToolWrite.AssertActionWrite`'s argument, `ProcessControl`'s stored-row assertion, the browser
spec's card treatment, and the execution plan's own `Destructive() 1` line), each doc comment
corrected at its origin. `AuditingUpdate.cls` was left alone (DW-1467). The review then patched
three verification gaps: the two AD-10 refusals are now driven through the shipped
`Prohibited.Prohibits()` rather than through the predicates alone, AD-51's registration-time
fingerprint-subject guard is driven through `ListTools` over a fixture registry, and the no-State
mint refusal asserts its status and sentence instead of only "not OK".

**Files changed.** `src/OcuPilot/Screen/Tool/ProcessSuspend.cls` -- the flag and the two comments
that called the write destructive. `src/OcuPilot/Test/ToolWrite.cls` -- the suspend's
`AssertActionWrite` argument, and a leg driving the registration guard through `ListTools`.
`src/OcuPilot/Test/ProcessControl.cls` -- the stored-row assertion, the tightened no-State arm, a
leg driving both AD-10 refusals through `Prohibits()`, and the `SystemPid()` helper that discovers
its target rather than naming one. `src/OcuPilot/Test/SubjectProbe/Registry.cls` (new) -- the
fixture registry whose discovery admits the probe package. `ui/browser/process-control.browser-spec.mjs`
-- the card-treatment assertion.

**Review findings.** 17 findings: 0 high, 4 medium, 9 low, 4 false. Patched: 2 medium (the
prohibited-set dispatch, the registration guard) and 1 low (the no-State assertions). Deferred: 4
(the mutation lines recorded only in doc comments; `ProhibitedFixture.Digest`'s three-argument
`Fingerprint.Of`; AC7's Process-details browser leg; AC2's broad ownership reading as a
decision-sheet question). Rejected: 8, each with its reason in the triage log above -- the arming
roster (the class already refuses unarmed under two other variables), `Mint`'s unreachable
projection-failure branch, the change event's internals (its observable is pinned by the browser
spec), the fixture-read legs and the widened kernel scope (both spec-bound), the changed-field
surface and the absent spine hunk (both refuted), and DW-1467 (already filed).

**Follow-up review: false.** This pass patched no `high`.

**Verified against `ocupilot-ci`** with every changed class loaded and compiled in the container and
read back from it (`Destructive()` answers 0 for both process tools, 1 for
`security.auditing.update`; the fixture registry compiles): `check-objectscript` 21 rules over 609
files clean; `lint-docs.sh` clean; source in the container byte-identical to the worktree;
`npm run build` with its prebuild checkers; `npm test` 1302 + 817; `ProcessControl` 10/10 armed (run
5159), `ToolWrite` 19/19 (run 5161), `Prohibited` 11/11, `SurfaceCoverage` 4/4, `ToolSetFull` 2/2,
all reconciled against `%UnitTest_Result` rather than the runner envelope;
`process-control.browser-spec.mjs` 2/2 against the deployed bundle, which no change in this pass
touches. Rule 19 at the source: restoring `DESTRUCTIVE` to `1` reddened all three of its pins at the
named assertion and nothing else; deleting either refusing branch from `Prohibited.Process` reddened
only the matching half of the new dispatch leg while the predicate legs stayed green; deleting the
guard call from `Registry.ListTools` reddened only the new registration leg. Every mutation was
reverted and the tree confirmed byte-identical.

**Read back after the run:** no suspended process, no probe process and no probe principal on
`ocupilot-ci`; `OcuPilotDemo nightly purge` reads `Suspended=1`; the live `ocupilot` holds no
suspended process and was never written to.

**Residual risk.** The four deferred items above, and the `WireSecurityRead` row-cap failure, which
stays environmental. The rest of the story -- the AD-51 fingerprint-subject seam, the port's
`(endpoint, type)` bodyless key, the `process` prohibited-set branch, the id rule, the descriptors
and the arming variables -- landed and was verified at `58812ec`; this pass re-ran the classes the
change touches and the tool-roster classes a new fixture registry could reach (Rule 29).
