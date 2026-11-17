---
title: "Story 21.33: OcuPilot's other guarded stores refuse a caller who may not write them"
type: 'bugfix'
created: '2026-11-16'
status: 'done'
baseline_revision: '06e2aec10a5b112cfae70cc1d2f18a0ac552b8f3'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
deferred:
  - summary: "The install-owned stores (WebApp, Stamp, Version, Demo) and the screen-access store (Access) still take any caller's public guarded write. WebApp.GuardedRecord is what Installer.Uninstall deletes an application on the strength of, so a %Development holder's row naming another application is deleted by an administrator's uninstall (inference: not reproduced)."
    evidence: "WebApp.cls doc comment: the record is 'the only thing Uninstall will remove an application on the strength of'; GuardedRecord, GuardedMarkGatewayReported, DeleteByPath, Stamp/Version/Demo DeleteByProfile and Access.GuardedPut/GuardedRemove are public and check no caller (plan read, 2026-11-16)."
    location: 'src/OcuPilot/Kernel/State/WebApp.cls; Stamp.cls; Version.cls; Demo.cls; Access.cls'
    severity: high
  - summary: "Base's public reads (GuardedOpenId, GuardedExistsId, GuardedStoredValue) and the stores' key-addressed reads let a %Development holder read another user's turns, conversations, proposals and ledger rows (AD-33, AD-46 say per-user)."
    evidence: "GuardedOpenId is public and opens any row of the class it is called on through the escalated frame; this story gates writes only (plan read)."
    location: 'src/OcuPilot/Kernel/State/Base.cls:424'
    severity: medium
  - summary: "A caller's own turn reserve still reads the turns-an-hour window and the queued limit for its own turns from the limits class it passes, so a developer who calls the store directly can lift its own hourly bound."
    evidence: "Turn.GuardedReserve reads TURNLIMITWINDOWSECONDS and ReconcileHeld reads QUEUEDSECONDS from pLimitsClass; both act only on the caller's own rows and start records (inference: not reproduced)."
    location: 'src/OcuPilot/Kernel/State/Turn.cls GuardedReserve, ReconcileHeld'
    severity: low
---

<intent-contract>

## Intent

**Problem:** Story 21.30 closed four administrator-owned stores. Every other store still escalates for any caller (DW-2638). A `%Development` holder who is not an OcuPilot administrator can rewrite an agent definition (instructions, provider, credential name), which every user's turns run with. That holder can also forge or rewrite another user's proposal, ledger, turn, conversation or preference row. A rewritten live proposal is then confirmed and run with the owner's privileges.

**Approach:** First reproduce the writes end to end as a real non-administrator principal. Then extend 21.30's store gate. Agent definitions become administrator-owned, and one narrow writer keeps a turn's credential finding open. The per-user stores refuse a write to a row whose stored owner is not the caller, unless the caller is an administrator. The work lands in three batches, highest risk first.

## Boundaries & Constraints

**Always:**

- A refused call changes nothing and returns `$$$ERROR($$$AccessDenied)` (vendor `ERROR #822`). The story adds no user-facing string.
- The administrator predicate is `Base.CallerIsAdministrator`, evaluated in the caller's process before any escalation.
- A row's owner is read from storage, never from the object a caller hands in. A save never changes it.
- Every product path in the Code Map's inventory keeps its current behavior. That includes the turn job, confirm, screen actions, the routes, the retention task, the installer and the smoke.
- `New $ROLES` stays only in `Base.cls`, and AD-9's frame and ordering rules hold. No `Kernel/State` file names `OcuPilot.Api`, `OcuPilot.Port` or `OcuPilot.Screen`.

**Never:**

- Do not gate reads; that is the second `deferred:` item.
- Do not change the install-owned stores or `Access`; that is the first `deferred:` item.
- Do not change a non-admin, non-owner product path. Each one keeps working through a named open writer and is listed under Design Notes.
- Do not edit the spine; the AD text is under Design Notes.
- Do not reference `..#OWNERWRITE` or `..#ADMINWRITE` inside an escalating `Base` method. Read them with `$Parameter`.
- Run nothing on `ocupilot`, and add no second throwaway.

## I/O & Edge-Case Matrix

Each row runs in a child process logged in as a real principal, through `AdminStateWrite.RunAs`. The developer principal holds `%Development:USE` and no `OcuPilotAdmin`. The victim is a user name that owns rows the suite seeded.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Agent definition | Developer: `Agent.GuardedCreate`, `GuardedUpdate` (instructions changed), `GuardedDeleteId`, `SetDefaultGuarded`, `GuardedSetVerification`, `GuardedMarkCredentialCreated`, `GuardedRebalanceDefault`, and the public `Base.GuardedSave`/`GuardedSaveIfCurrent` of an opened row | Each refused; the definition reads back unchanged | 822 |
| Credential finding | Developer holds the definition row edited in memory, then calls `Agent.GuardedClearVerification` | `ConnectionVerified` and `Enabled` are 0 and the default marker is rebalanced. No other field changes; the held edit is not stored | No error expected |
| Victim's rows | Developer: `Propose.GuardedMint` with `user` = victim; a victim proposal opened and its arguments changed, then saved through both public saves; `GuardedClose`/`GuardedClaimAndClose` on it; `Ledger.GuardedAppend` as victim, `GuardedFinalize` of a victim row, `GuardedDeleteForUser(victim)` | Each refused; the victim's rows unchanged | 822 |
| Victim's transcript (batch 2) | Developer: `Turn.GuardedFinish`/`GuardedRequestStop`/`GuardedDelete` on a victim turn, `Step.GuardedAppend` to it, `Convo.LoadOrCreate(victimKey)` and `AppendEntry` | Each refused; unchanged | 822 |
| Victim's settings (batch 3) | Developer: `Pref.GuardedSetValue(victim, ...)`, `Sharing.GuardedSetForUser(victim, ...)`, `SqlRun.GuardedCancel` of a victim run | Each refused; unchanged | 822 |
| Forged owner | Developer holds its own row with `UserName` set to the victim in memory, then calls that row's writer (`Pref.GuardedSetValue` on its own key; one per batch's store) | Refused; the stored owner is still the developer | 822 |
| Owner path | Developer writes its own rows through every owner writer the plan uses | Stored | No error expected |
| Administrator | Administrator principal (no `%All`) closes a victim proposal and sets a victim preference | Stored | No error expected |
| Open sweep | A victim's expired terminal turn exists; the developer reserves a turn | The reserve succeeds and the expired turn is swept, as today | No error expected |

</intent-contract>

## Code Map

- `src/OcuPilot/Kernel/State/Base.cls` -- 21.30's gate. `CallerIsAdministrator:196`, `AdminWriteRefused:206`, the public saves `GuardedSave:217` and `GuardedSaveIfCurrent:257`, and the private `GuardedSaveIfCurrentAnyCaller:272`. `GuardedStoredValue:495` reads one stored property through a unique index's `Exists` with global reads, not by opening the object, which is what a stored-owner lookup needs. The unique key indexes are `TurnKeyIdx`, `ProposalKeyIdx`, `LedgerKeyIdx`, `ConvKeyIdx`, `RunKeyIdx`, `SharingUserNameIdx` and `NavTurnKeyIdx`.
- `src/OcuPilot/Kernel/State/Agent.cls` -- the writers are `GuardedCreate:207`, `GuardedUpdate:239`, `GuardedSetVerification:321`, `GuardedMarkCredentialCreated:351`, `GuardedDeleteId:378`, `SetDefaultGuarded:579` and `GuardedRebalanceDefault:695`. `GuardedClearVerification:282` goes through `GuardedUpdate`, and `MarkRow` re-opens rows by `%OpenId`. A caller's held, edited copy is therefore what gets saved; 21.30's review found the same trap in `Switch`.
- `src/OcuPilot/Kernel/State/Propose.cls` -- the writers are `GuardedMint:276` (owner `pValues("user")`), `GuardedRecordReadBack:379`, `GuardedClaimAndClose:523`, `GuardedRebuildTargetKeys:598`, `GuardedClose:633`, `GuardedCloseLiveForConvo:651`, `GuardedCloseLiveForUser:668`, `GuardedExpireStale:688`, `GuardedDeleteForTurn:808` and `GuardedDeleteForUser:815`. The three close writers call `GuardedExpireStale("")`, which expires every user's lapsed proposals. `GuardedTargetHold` and `GuardedTargetRelease` take and release a lock and write no row.
- `src/OcuPilot/Kernel/State/Ledger.cls` -- the writers are `GuardedAppend:234`, `GuardedFinalize:293`, `GuardedCountOverflow:323`, `GuardedDeleteForTurn:491`, `GuardedDeleteForUser:498` and `GuardedPurgeBefore:506`.
- `src/OcuPilot/Kernel/State/Turn.cls` -- `GuardedReserve:192` calls the all-users `GuardedSweep:691` at its end. `GuardedSweep` calls the public `GuardedDelete:713`, which cascades through `Step`, `Nav` and `Propose` `GuardedDeleteForTurn`. The other writers are `GuardedForgetStarts`, `GuardedSweepStarts`, `GuardedReconcile`, `GuardedBegin`, `GuardedProgress`, `GuardedAddDropped`, `GuardedFinish`, `GuardedRenew`, `GuardedRequestStop` and `GuardedAbandonForUser`.
- `src/OcuPilot/Kernel/State/Step.cls`, `Nav.cls` -- the owner is the owner of the turn named by `TurnKey`. `Entry.cls`'s owner is the owner of the conversation named by `ConvoKey`.
- `src/OcuPilot/Kernel/State/Convo.cls` -- `LoadOrCreate:53` loads an existing key without checking its owner. `AppendEntry:116` and `GuardedDelete:304`, which cascades to `Entry.GuardedDeleteForConvo`, are further writers.
- `src/OcuPilot/Kernel/State/Pref.cls`, `Sharing.cls`, `SqlRun.cls` -- user-argument writers. `SqlRun.GuardedReserve` calls the all-users `GuardedSweep`.
- **Caller inventory** (grep over `src/` with `$ClassMethod` and `StoreClass()` forms included, tests excluded). Each path is one of three kinds:
  - **Administrator.** `Api/Definitions` (every Agent writer behind `IsAdministrator`) and `Kernel/Retention`, whose task runs as `_SYSTEM` on slot A: `Turn.GuardedSweep`/`GuardedSweepStarts`, `SqlRun.GuardedSweep`, `Convo.GuardedPurgeEmpty`, `Entry.GuardedPurge`, `Ledger.GuardedPurgeBefore` and `Pref`/`Sharing` `GuardedDeleteForUser`. Also `Install/Installer` (`Propose.GuardedRebuildTargetKeys`, `Base.GuardedSave`), `Install/Fixture` and `Install/Smoke`.
  - **Owner.** The turn job (`Kernel/Agent/Job`, `Loop`, `StreamStep`, `Kernel/Audit/Ledger` provider and tool rows, `Kernel/Proposal/Mint`) runs as the turn's user (AD-7). Confirm, cancel and draft (`Kernel/Proposal/Confirm`, `Write`, `Draft`, `Operation`) pass `pUser` = `$Username`, and `Audit/Ledger.OpenConfirmedWrite`/`FinalizeConfirmedWrite` record the owner. `RecordTranscriptAccess` writes under the reader's own name. The routes `Api/Turn`, `Api/Conversation`, `Api/Preferences`, `Api/Context:72`, `Api/Switches:563` and `Kernel/Shell/BackgroundRun` pass `CallerUsername()` = `$Username`.
  - **Named open writers.** `Port/ProviderPort:187` calls `Agent.GuardedClearVerification` from any user's turn. `Screen/Tool/UserDelete:137` calls `Turn.GuardedAbandonForUser` for a deleted account, as a security administrator who may lack `OcuPilotAdmin`. Every user's `Turn.GuardedReserve` and `SqlRun.GuardedReserve` sweep, and every close's `GuardedExpireStale("")`, write other users' rows by the instance's own rule.
  - No product caller exists for `Step`/`Nav`/`Propose`/`Ledger` `GuardedDeleteForTurn`, `Propose`/`Ledger` `GuardedDeleteForUser`, `Turn.GuardedForgetStarts`, `SqlRun.GuardedForgetUser`, `Convo.GuardedDelete`, or `Pref`/`Sharing` `DeleteAllGuarded` outside the cascades named above.
- **Real-principal suites** already run turns as a non-administrator: `DeveloperFloorTurn` (`%Development`, no admin) and every `TurnWireFixture` class (`TurnWire`, `TurnConversation`, `TurnNavigate`, `TurnProviderFault`, `LedgerWire`, `TranscriptsWire`, `ExplorerSaveTurn`, `AgentPickTurn`, and others). They are this story's integration net.
- `src/OcuPilot/Test/AdminStateWrite.cls` -- `RunAs:599` hard-codes the probe class, and `EnsurePrincipals:645` is an instance method. `TestTheAdministratorStoresAreDeclared:282` pins the `ADMINWRITE` roster at four stores and `BaseSurface:335` pins `Base`'s public methods. Both change here.
- **Contention.** `git log origin/OCU-1-epic24 ^origin/feature/OCU-1_ocupilot-mvp` is empty for every file above. No `OCU-1-epic22` branch exists. Feature carries 13 more lines in `scripts/ci-throwaway.sh` (Epic 24's arming rosters), so add this story's classes as a union.

## Pass Scope

This dispatch (pass 3) covers Batch 3 and DW-2666, and finishes the story. Batches 1 and 2 are done and reviewed. Finalize with `status: done`, `Status: done` and `Blocking condition: none`.

Pass 3 builds:

1. **Task 0 for Pref, Sharing and SqlRun first.** Before any product change, reproduce a developer's write to another user's preference, sharing choice and SQL run on the unfixed tree. Record before and after under `## Verification` as "Task 0 (batch 3, pre-fix)". If no write lands, HALT `blocked`: `Task 0: attack did not reproduce: <evidence>`.
2. **Batch 3 as planned below.** `Pref`, `Sharing` and `SqlRun` become owner stores. `SqlRun.GuardedReserve` sweeps through a private any-caller form. `DeleteAllGuarded`, `GuardedDeleteForUser`, `SqlRun.GuardedSweep` and `GuardedForgetUser` serve an administrator only. Tests go in a new class `PrefOwnerWrite` (do not grow the Batch 1 or 2 classes beyond what their rosters need).
3. **DW-2666, orchestrator ruling option A, for the turn reserve sweep (`Turn.SweepAnyCaller`) and for SqlRun's reserve sweep.**
   - For a non-administrator caller, the retention cutoff comes from the instance's own limits class, never from the caller-passed one: `OcuPilot.Kernel.Agent.Loop.LimitsClass()` for turns and `OcuPilot.Kernel.Shell.BackgroundRun.LimitsClass()` for runs. Resolve each by `$ClassMethod` on a class name held in one place; no `Kernel/State` file may name `OcuPilot.Api`, `OcuPilot.Port` or `OcuPilot.Screen`.
   - A sweep reads each row's `State` and `EndedAt` (and the run's equivalents) from storage by SQL, never from an object the caller may hold, and its delete statement repeats the state condition. An administrator's call (the retention task) keeps the limits class it is given.
   - Measured, code review runs 87 and 91: a limits class with no `RETENTIONSECONDS` deleted another user's just-ended turn, and a reserve with the product limits class did the same while the caller held that turn with `EndedAt` back-dated. Turn both into tests with SqlRun twins, in a new class `ReserveSweepWrite`. Each must be observed red on the unfixed tree and green after, with a Rule 19 `mutation:` line.
   - A test that another user's genuinely expired turn (and run) is still swept by an ordinary user's reserve. `TestTheOpenPathsStillWork` stays green in both owner-write classes.
   - Audit every other private helper reachable from an open path (the reserves, the close-time expiry `Propose.ExpireStaleAnyCaller`, `Turn.ReconcileHeld`, `SqlRun.Reconcile`, `GuardedAbandonForUser`, the credential finding's rebalance) for caller-controlled limits or a held object that decides what it writes on another user's row. Give each the same treatment, with a test and a mutation line, and list each helper examined, changed or not, with the reason, in the `## Auto Run Result`. `SqlRun.Reconcile` ends other users' lost runs with the caller's queued limit: that is one.
4. **Finalize.** Spec `status: done`, `## Auto Run Result` with `Status: done` and `Blocking condition: none`, the Batch 3 and DW-2666 records under `## Verification`, and the new classes in `scripts/ci-throwaway.sh` as add-only edits.

Orchestrator condition (U-89): the five non-owner product paths and the claim's own-target sibling cancel keep their behavior: `Turn.GuardedAbandonForUser`, the turn reserve sweep, the background-run reserve sweep, proposal-close expiry, `Agent.GuardedClearVerification`, and AD-9's confirm claim canceling its own stored target's siblings. DW-2666's ruled scope is the only change allowed to the two reserve sweeps: a product caller passes the instance's own limits class and keeps its behavior. An edit that would change one beyond that stops the run as `blocked` with this condition.

The integration net of real non-admin turns and runs stays green: the turn classes, `SqlRun`-related classes, the preference and sharing classes, `TestTheOpenPathsStillWork` in both owner-write classes, and `AdminPathWrite`.

## Tasks & Acceptance

**Execution.** Task 0 runs first. Each batch after it is independently verifiable and committable, and each one adds `OWNERWRITE` only to its own stores.

- **Task 0, the reproduction (DW-2638).** Write `OwnerStateWriteProbe` and batch 1's test class with no product change. Run on `ocupilot-ci`.
  - Expected: the developer legs answer OK. The read-backs show a rewritten agent definition and a forged or rewritten victim proposal and ledger row.
  - Add the turn, conversation and preference legs (batch 2 and 3 classes) in the same pass, and run them too.
  - Record each leg's before/after under `## Verification` as "Task 0 (pre-fix)".
  - If no write lands, HALT `blocked`: `Task 0: attack did not reproduce: <evidence>`.
- `src/OcuPilot/Test/AdminStateWrite.cls` -- `RunAs` takes the probe class as an argument, defaulting to its own. `EnsurePrincipals` becomes a class method taking the user/role/grant cases, so the new classes reuse it. Agent joins the `ADMINWRITE` roster with its reads/writes/open-write split. `BaseSurface` lists `Base`'s new public methods.
- `src/OcuPilot/Test/OwnerStateWriteProbe.cls` (new) -- extends `AdminStateWriteProbe`. It adds the matrix's step kinds and passes every other kind to `##super`.
- **Batch 1 (highest risk: confirm-time privilege escalation, every user's agent, the audit record).**
  - `Base.cls`:
    - Add `Parameter OWNERWRITE As %String = ""`, which names the owner-carrying property.
    - Add `Parameter OWNERPARENT As %String = ""` and `OWNERPARENTINDEX`, for stores owned through a parent key.
    - Add `CallerOwns(pUser)`, a case-insensitive comparison with `$Username` that is false for `""`.
    - Add `OwnerWriteRefused(pClassName, pOwnerValue) As %Status`. It answers OK for an administrator. Otherwise it resolves the owner (through the parent's `GuardedStoredValue` when `OWNERPARENT` is set) and refuses an unresolved owner or one the caller does not own.
    - The public saves refuse a non-administrator for an `OWNERWRITE` class too.
    - Add private `GuardedSaveOwned(pObject, pExpected)`. For a non-administrator, an existing row's owner-carrying value must equal its stored value, and the owner must pass `OwnerWriteRefused`. It then saves through the any-caller conditional save, or a plain-save twin where the writer used `GuardedSave`.
  - `Agent.cls`:
    - Set `ADMINWRITE = 1` and call `AdminWriteRefused` first in each writer.
    - `GuardedClearVerification` stays open. It writes `ConnectionVerified`, `Enabled`, `UpdatedAt` and `RowVersion` by one `UPDATE`, then runs a private SQL-only rebalance. `GuardedRebalanceDefault` uses that same private rebalance after its check.
    - A cleared marker must read back `""` through the object layer.
  - `Propose.cls`:
    - Set `OWNERWRITE = "UserName"`.
    - User-argument writers check `pUser`, and `GuardedMint` checks `pValues("user")`. Key writers check the stored owner by `ProposalKeyIdx`.
    - Internal saves go through `GuardedSaveOwned`.
    - `GuardedExpireStale("")`, `GuardedDeleteForTurn`, `GuardedDeleteForUser` and `GuardedRebuildTargetKeys` serve an administrator only. The close writers call a private any-caller expiry.
  - `Ledger.cls`:
    - Set `OWNERWRITE = "UserName"`.
    - `GuardedAppend` and `GuardedCountOverflow` check `pUser`. `GuardedFinalize` checks the stored owner by `LedgerKeyIdx`.
    - The deletes and `GuardedPurgeBefore` serve an administrator only.
  - `src/OcuPilot/Test/StoreOwnerWrite.cls` (new) -- armed by `OCUPILOT_ALLOW_PRINCIPALS`, with its own developer and administrator principals. It runs batch 1's matrix rows and seeds the victim's rows and a probe definition as the suite identity. Each test restores what it changed and asserts the restore. It also runs `TestTheOwnerStoresAreDeclared`: the classes whose compiled `OWNERWRITE` is non-empty equal the declared set. Each one's public class methods equal a declared split of reads, owner writes, administrator writes and open writes, and every write in that split is a step some test calls.
  - `scripts/ci-throwaway.sh` -- list each new armed class.
- **Batch 2 (transcripts: another user's model history and turn control).**
  - `Turn`, `Convo`: `OWNERWRITE = "UserName"`.
  - `Step`, `Nav`: owned through `Turn`/`TurnKeyIdx`. `Entry`: owned through `Convo`/`ConvKeyIdx`.
  - Owner checks follow batch 1's pattern. `Convo.LoadOrCreate`'s load branch checks the stored owner.
  - `Turn.GuardedReserve` calls a private any-caller sweep, whose cascade deletes the turn's steps, directive, proposals, signals and row by its own SQL. Public `GuardedSweep`, `GuardedSweepStarts`, `GuardedForgetStarts`, the children's `GuardedDeleteForTurn`, `Entry.GuardedDeleteForConvo`/`GuardedPurge` and `Convo.GuardedPurgeEmpty` serve an administrator only.
  - `Turn.GuardedDelete` and `Convo.GuardedDelete` check the owner, then use the private cascade.
  - `Turn.GuardedAbandonForUser` stays open.
  - New `src/OcuPilot/Test/TranscriptOwnerWrite.cls` covers this batch's rows, including the open sweep.
- **Batch 3.**
  - `Pref`, `Sharing`, `SqlRun`: `OWNERWRITE = "UserName"`, with the same checks.
  - `SqlRun.GuardedReserve` calls a private any-caller sweep. `DeleteAllGuarded`, `GuardedDeleteForUser`, `SqlRun.GuardedSweep` and `GuardedForgetUser` serve an administrator only.
  - New `src/OcuPilot/Test/PrefOwnerWrite.cls`.

**Review patches (pass 1, Batch 1 tests only; no product change expected).** Open items, each a test or a recorded mutation in `StoreOwnerWrite` (and `OwnerStateWriteProbe`):

- `Ledger.GuardedCountOverflow` leg: the developer calls it with `user` = itself and the turn key of a seeded victim overflow row, nothing held. It answers 822 and the victim's overflow row is unchanged. Mutation: delete the held-owner `OwnerWriteRefused` line in `GuardedSaveOwned` -> only this leg goes red.
- The owner and administrator plans are built from `OwnerKinds()` and `AdministratorKinds()` (as the refusal tests are from `VictimKinds()`), so `TestTheOwnerStoresAreDeclared` compares what the plans ran, not one literal list against another.
- `CallerOwns` legs: an owner write with the developer's name in a different case is accepted; an owner write with `""` as the user is refused 822. Mutation: `CallerOwns` compares with `=` -> the case leg goes red.
- `Ledger.GuardedFinalize` on a key that names no row: 822 for the developer, OK for the administrator.
- Four more `mutation:` lines, each observed red alone and reverted (byte-identical, reloaded): remove the administrator gate in `Ledger.GuardedPurgeBefore`; `CallerOwns` always 0; a close writer calls the public `GuardedExpireStale("")` instead of the private any-caller expiry; `RefreshMark` drops the `RowVersion` copy.

**Review patches (pass 2, Batch 2 tests and mutation lines; no product change expected).** Open items:

- `Turn.GuardedFinish` refusal: add a leg to `TranscriptOwnerWrite` (with a probe step reporting whether the owner's turn slot lock is held, as `TurnFixture` reads held locks). The developer reserves and begins its own turn, the suite deletes that turn row, the developer calls `GuardedFinish(key, itself)`: it answers 822 and the slot is no longer held. Also assert that an owner's turn writer on a key that names no turn is refused. Mutations: delete the unlock on refusal (or `CallerOwns(pUser)` to `0`) -> that leg alone red; `KeyOwnerRefused` accepting a missing row -> the missing-key leg red.
- `TranscriptOwnerWrite.VictimState`'s proposal query must also read proposals by the victim conversation key (`OR %EXACT(ConvKey) = <the conversation>`), so the conversation-key mint leg's unchanged-rows assertion can observe a write.
- Mutation lines to record (apply, observe red, revert byte-identical, reload): the administrator bypass removed from `OwnerWriteRefused` -> `TestAnAdministratorWritesAVictimsTranscriptAndSweeps` red; the `NamedOwnerRefused` call removed from `Ledger.GuardedCountOverflow`; the turn-key `NamedOwnerRefused` call removed from `Propose.GuardedMint`. Each must redden a DW-2663 leg alone, or the leg is added.
- The Batch 1 `mutation:` line for `GuardedRebuildTargetKeys` checking the administrator before it reads names a test the install-step frame now keeps green. Replace that line at its origin with what is observed today (which test goes red alone for the mutation, and the combined mutation `AdminPathWrite`'s doc comment names, run once).

**Acceptance Criteria:**

- Given the unfixed tree on `ocupilot-ci`, when Task 0 runs, then the developer's writes of an agent definition and of the victim's proposal, ledger, turn, conversation and preference rows land, and the read-backs are recorded.
- Given each batch, when its owner test class runs, then every refusal row answers 822 with the rows unchanged. The owner, administrator, credential-finding and open-sweep rows store, and the roster test is green.
- Given each batch, when the existing real-principal turn suites run (`DeveloperFloorTurn`, `TurnWire`, `TurnProviderFault`, `ExplorerSaveTurn`, `LedgerWire`, `TurnConversation`), then they stay green. This is the turn's own writes as a non-administrator.
- Given `OwnerWriteRefused` mutated to answer `$$$OK`, when the owner test classes run, then only their refusal tests go red.

### Review Findings

Code review, Batch 1 (2026-11-16, HEAD `be4f8d61f`, full-opus tier: blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor).

- [x] [Review][Decision] A confirm's claim cancels other users' live proposals, and AD-9's list of open writes leaves that out (high). Closed: AD-9 names it (DW-2662). Measured on `ocupilot-ci` as a `%Development` principal. Minting its own proposal on a victim's target and claiming it left the victim's proposal `canceled`/`sibling`. The code follows AD-34, so the gap is the AD text: add "a confirm's claim canceling every user's live proposals on its own proposal's target (AD-34)" to the open writes, or rule otherwise. DW-2662, for the orchestrator.
- [x] [Review][Patch] A claim canceled siblings of whatever target the caller passed, not its own row's (high, measured) [Propose.cls GuardedClaimAndClose]. A non-administrator's target must now equal the stored `TargetRef`; `TestAClaimCancelsOnlyItsOwnTargetsSiblings`.
- [x] [Review][Patch] An administrator's save could change a row's owner, against AD-9's "a save cannot change it" (high) [Base.cls GuardedSaveOwned, GuardedSave, GuardedSaveIfCurrent]. Every caller now goes through `OwnerChangeRefused`; administrator legs added to the forged-owner test.
- [x] [Review][Patch] Three victim legs could not fail on "rows unchanged" because nothing they would write was seeded (medium) [StoreOwnerWrite.cls]. The tests now seed a lapsed proposal and a keyless targeted one.
- [x] [Review][Patch] The cleared-verification test expected the marker on the suite's own definition, not on the instance's lowest-id enabled one (medium, hermeticity) [StoreOwnerWrite.cls].
- [x] [Review][Patch] `StoreOwnerWrite.OnAfterAllTests` copied `AdminStateWrite`'s (medium, Rule 31) [AdminStateWrite.cls]. Both now use `RemovePrincipals`.
- [x] [Review][Patch] Stale or missing mutation lines (low). The `OwnerWriteRefused`, forged-owner and clear-verification lines were corrected; five were added.
- [x] [Review][Patch] Doc comments that said something false (low): `GuardedExpireStale`, `Propose`'s `OWNERWRITE`, `GuardedSetVerification`, `GuardedDeleteForTurn`.
- [x] [Review][Patch] `SetDefaultGuarded` and the SQL rebalance write the marker two ways (low, Rule 31). Converting `SetDefaultGuarded` to SQL broke `AgentWire` (run 75), because the default route projects the row it holds. The reason is now stated at `RebalanceDefaultSql`.
- [x] [Review][Defer] A developer's own proposals and ledger rows on another user's turn or conversation key use up that turn's caps (medium, inference). DW-2663, Batch 2.
- [x] [Review][Defer] The ledger purge and the target-key rebuild need `OcuPilotAdmin` in-process. Neither the retention task's run-as user nor a first install by a non-`%All` administrator is pinned to hold it (medium, inference). DW-2664, Batch 2.
- [x] [Review][Defer] `Propose.GuardedDeleteForTurn` lets any caller delete any user's proposals (medium, measured). By design under the Pass Scope carve-out; Batch 2 gates it before merge.

Rejected or closed at emission:

- low, wontfix-accepted: `StoreOwnerWrite` is 932 lines. The split is not mechanical, because a helper parent with no tests changes the runner's class roster (inference). reopen_if=Batch 2's `TranscriptOwnerWrite` needs the same helpers.
- low, wontfix-accepted: `GuardedStoredOwnerById` reads by id beside `GuardedStoredValue` by key. It is private, and its class and property come from `OWNERWRITE`. reopen_if=a third stored-value reader appears.
- low, wontfix-accepted: an owner name in another letter case stores rows that `%EXACT` reads miss. They are only the caller's own rows. reopen_if=a product caller passes a name other than `$Username`.
- low, wontfix-accepted: `OpenKinds` is a literal roster. reopen_if=Batch 2 leaves an open write that `TestTheOpenPathsStillWork` does not reach.
- low, wontfix-theoretical: a claim or read-back on a vanished key now fails 822, and the confirm turns that into a 500. Real only if a live proposal is deleted between the confirm's read and its claim.
- low, wontfix-theoretical: `GuardedTargetHold` lets any caller hold a target's lock. A plain `LOCK` on that name needs no database privilege (inference).
- low, wontfix-theoretical: a caller-compiled subclass, or any object's save set, runs inside `Base`'s escalated save. This needs code-write in the install namespace, which already allows editing `Base`.
- low, wontfix-theoretical: `RefreshMark` can adopt the version a concurrent credential finding wrote. Real only if a finding on that definition lands between an administrator's save and the refresh, and the object is then saved again.
- low, wontfix-theoretical: the credential finding's flags commit before its rebalance. The baseline saved before rebalancing too.
- low: five Agent writers' own `AdminWriteRefused` line is shadowed by the public save's. The behavior is pinned.
- low: `AgentFields` omits columns the probe never edits.
- low: the open-path and administrator tests change other users' rows by the product's own rule, on a throwaway.
- low: commit `4334486d8`'s message claims more than the code did. The message is history.
- false: "the credential finding writes more than the flags and marker". `UpdatedAt` and `RowVersion` are stated in the spec's Batch 1 text.

Code review, Batch 2 (2026-11-16, commit `d30e55097` against `06e2aec10`, HEAD `90431b452`, full-opus tier: blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor). QA folded in.

- [x] [Review][Decision] A non-administrator's turn reserve still runs the cross-user sweep on a retention it controls (high, measured; DW-2666). Closed by Batch 3. [Turn.cls GuardedReserve, SweepAnyCaller]. As `%Development` without `OcuPilotAdmin` or `%All`, a reserve that passes a limits class with no `RETENTIONSECONDS` deleted another user's turn that had just ended (run 87). A reserve with the product limits class did the same while the caller held that turn with `EndedAt` back-dated, because `GuardedOpenId` answers the held object (run 91). This is the `GuardedSweep` capability the batch closed, one hop away, which breaks AD-9 ("deletes and purges across users are an administrator's"). Proposed fix: for a non-administrator, take the cutoff from the instance's limits class (`Loop.LimitsClass()`), and read `State` and `EndedAt` by SQL. Product callers are unchanged. The fix still edits the reserve sweep that U-89 froze, so it is unpatched and goes to the orchestrator. `SqlRun`'s reserve sweep has the same shape (Batch 3).
- [x] [Review][Patch] DW-2663 left ledger rows on another user's conversation key, which spend that conversation's access-row cap (medium) [Ledger.cls GuardedAppend, GuardedCountOverflow]. Both writers now refuse that key through `NamedOwnerRefused` on `Convo`. Two `.Convo` legs were added to `TestADeveloperCannotSpendAVictimsTurnCaps`, and `VictimState` now reads ledger rows by that key.
- [x] [Review][Patch] No test showed that `Convo.GuardedDelete` removes the conversation's entries (medium) [TranscriptOwnerWrite.cls TestADeveloperWritesItsOwnTurnAndConversation].
- [x] [Review][Patch] Five helpers were copied from `StoreOwnerWrite` (medium, Rule 31; Batch 1's `reopen_if` fired) [TranscriptOwnerWrite.cls]. `DetailOf`, `Detail` and `KindsOf` (was `PlanKinds`) now live in `AdminStateWrite`, and both classes call them. `AssertCalled` and `AssertPrincipal` stay as copies: they are instance assertion helpers, and sharing them needs a parent class with no tests, which the runner fails.
- [x] [Review][Patch] Creating a conversation in another user's name was pinned by no leg (low) [TranscriptOwnerWrite.cls TestADeveloperIsRefusedAVictimsTranscript].
- [x] [Review][Patch] No harness case had `New $ROLES` in a method after `EnsureProposalTargetKeys` (low) [test_check_objectscript.py].
- [x] [Review][Patch] No mutation removed `New $ROLES` alone from the target-key step (low): its `mutation:` line is added.
- [x] [Review][Patch] Two doc comments named callers that no longer call them, and `Convo.GuardedDelete` did not say why it deletes entries itself (low) [Nav.cls, Entry.cls, Convo.cls].
- [x] [Review][Patch] The Batch 1 `mutation:` line about an administrator gate on `Propose.GuardedDeleteForTurn` describes code that now ships (low). It is removed; the Batch 2 line pins that gate.
- [x] [Review][Patch] The installer's own addition of the role asserted only `ok`, not that the role was held (low) [AdminPathWrite.cls].
- [x] [Review][Patch] `EnsureProposalTargetKeys` re-implemented `Base.CallerIsAdministrator` (low) [Installer.cls].

U-89: the five open paths and the claim's cancel of its own target's siblings are unchanged by `d30e55097`. `Turn.GuardedAbandonForUser`, `SqlRun`, the close-time expiry, `Agent.GuardedClearVerification` and `GuardedClaimAndClose` are untouched. The reserve sweep issues the same statements in the same order, and `TestTheOpenPathsStillWork` is green (runs 88, 92). Re-parenting a held `Step` onto another user's turn, or another user's step onto the caller's own, is refused 822 in both directions (run 91). DW-2665: a developer's `Set $ROLES` is refused `<PROTECT>`, and the step answers 822 (`AdminPathWrite`, runs 89, 95).

Rejected or closed at emission (Batch 2):

- low, wontfix-accepted: rule 6 matches `New $ROLES` and `AddRoles` but not `Set $ROLES`, and the checker file carries Epic 24's uncommitted edits. reopen_if=a `Set $ROLES` appears in `src/` outside `Base`, the two test probes and `EnsureProposalTargetKeys`.
- low, wontfix-accepted: `NEW_ROLES_RE` and `ADD_ROLES_RE` repeat `ESCALATION_RE`'s two patterns, in the same contended file. reopen_if=`ESCALATION_RE` gains a spelling the two lack.
- low, wontfix-accepted: the top-of-method owner checks in `GuardedBegin`, `GuardedReserve` and `GuardedReconcile` are shadowed by `GuardedSaveOwned`, so no test separates them; without them a stranger would hold another user's slot briefly. reopen_if=a test observes another user's slot held during a refused call.
- low, wontfix-accepted: `RunAsWatched` is `RunAs` plus a loop that answers questions about the slot. reopen_if=a third `RunAs` variant appears.
- low, wontfix-theoretical: `Job.Run`'s "did not start as its caller" branch now gets 822 from `GuardedFinish`. Real only if a turn job's `$Username` differs from its turn's owner, which AD-7's inheritance rules out.
- low, by-design: a refused role addition writes no install report line. AD-9 says the step then runs unescalated and the store decides, and a report line would be new user-facing text.
- low, by-design: a turn writer on a key whose row was deleted answers 822 (Decided in-stage).
- low: an administrator without `%All` is not run through the four new administrator-only retention calls; they use the predicate the ledger purge leg pins.
- low: the frame covers the report building after the call; it holds only local reports and unwinds before the next step.
- low: unguarded `Leg(...).%Get` in two tests errors on a broken run instead of failing an assertion; the test is red either way.
- low: legs passing the developer's own name with another user's key: `GuardedFinish` is refused by the key check its leg pins, and `GuardedBegin` and `GuardedRequestStop` by their existing exact-owner comparisons.
- low: a second escalated read of the parent owner per child save. The cost is negligible, and removing it adds a branch.
- false: the probe profile's suffixed role. The store gate reads the unsuffixed `ADMINRESOURCE` that the step adds.
- rejected, spec edit: frontmatter `deferred:` item 3, the residual-risk count, and the Auto Run Result's removed Batch 1 lines.

Code review, Batch 3 and DW-2666 (2026-11-16, commit `2ba8d0051` against its parent, HEAD `e0a7cf528`, full-opus tier: blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor). Measured on `ocupilot-ci` as the developer principal.

- [x] [Review][Patch] `SqlRun.GuardedViewForOwner` ended another user's lost run for any caller who named that user (medium, measured run 121) [SqlRun.cls]. It reconciles only for the run's owner or an administrator; the view itself is a read (DW-2652). `TestAViewOfAnotherUsersRunEndsNothing`.
- [x] [Review][Patch] `SqlRun.GuardedBegin` took another user's run lock before checking the key's owner, so a caller looping on it could keep that run from beginning (medium, inference) [SqlRun.cls]. The stored owner is checked first; a new leg in `TestADeveloperIsRefusedAVictimsSettings`.
- [x] [Review][Patch] The three residuals had no test (medium, Rule 19) [ReserveSweepWrite.cls]. `TestATurnSweepDeletesOnlyATurnStillExpiredAsRead` and its run twin hold the first row so the delete waits, and change the next two meanwhile; `TestATurnSweepThatFailsLeavesTheTurnWhole` holds the proposal row past the lock timeout; `TestARefusedRunFinishReleasesTheRunLock` asks the suite whether the lock is held. The probe's `Ask`, `Value` and `Run` moved to `OwnerStateWriteProbe`, and `RunAsWatched` takes a probe and two more questions, rather than a third `RunAs`.
- [x] [Review][Patch] `TestAnAdministratorsSweepKeepsTheLimitsClassItIsGiven` swept every user's rows with a one-second retention and queued limit (medium, hermeticity). It now passes a one-day class and keeps rows past the instance's retention.
- [x] [Review][Patch] Five tests that keep another user's row passed even if the sweep stopped early (low): each asserts `sweepOk`.
- [x] [Review][Patch] `SqlRun.GuardedReserve`'s doc named the administrator's sweep (low); false triage and Residual reasons replaced at origin (low); the two Decision items above closed (low).
- [x] [Review][Defer] A direct caller of the reserve stores chooses its own caps: the run cap counted over every user, a free-text kind, an exact-match busy check, and the turn hour limit and window (medium, inference). DW-2667, escalated: changing a reserve beyond DW-2666's ruling is U-89's call. The run answers, preferences and sharing reads join DW-2652.

U-89: the five open paths and the claim's own-target cancel keep their behavior. `TestTheOpenPathsStillWork` (runs 107, 108) and `TestTheOpenSweepStillWorks` (run 129) are green. The turn sweep deleting the turn row first, inside a transaction, is how its delete repeats the state condition: the end state is the same, and a failed child delete now rolls the turn back whole (measured, run 118). `GuardedAbandonForUser` and `SqlRun.Reconcile` are Pass Scope audit items with unchanged product effect. Nothing changed beyond the ruled scope.

Rejected or closed at emission (Batch 3):

- low, by-design: `SqlRun.GuardedBegin` or `GuardedFinish` on a key whose row is gone answers 822 to its owner, as Batch 2 ruled for turns.
- low, wontfix-accepted: `Base.GuardedRowsWhere` sits beside `GuardedRowsNoParam`, as the per-arity `GuardedIdsWhere` family does. reopen_if=a third rows reader appears.
- low, wontfix-accepted: `ReserveSweepWrite` is 537 lines. reopen_if=another test is added to it.
- low, wontfix-accepted: two `PrefOwnerWrite` legs rely on the child reaching its sweep within the 10-second queued limit. reopen_if=either is seen red on CI.
- low, wontfix-accepted: pass 3's Auto Run Result replaced pass 2's, as the template keeps only the current pass. reopen_if=a Batch 2 decision is needed and is not in Design Notes or the triage log.
- low, wontfix-theoretical: `InstanceLimits.ForRuns` reads the base `BackgroundRun`, not a run kind's subclass. Real if a run kind overrides `LimitsClass`.
- low, wontfix-theoretical: `InstanceLimitsClass`'s `$ClassMethod` and the `TROLLBACK` sit outside a `Try`. Real only if `InstanceLimits` is not compiled or a rollback throws.
- low, wontfix-theoretical: the sweep transaction holds row locks until it commits, and could escalate on a turn with over about 1,000 steps (inference). Real if a turn carries that many steps.

## Spec Change Log

## Review Triage Log

### 2026-11-16 - Review pass (Batch 1)

- verdicts: 12 findings - high 0, medium 4, low 6, false 2, maybe-false 0
- findings:
  - `[medium]` `[patch]` GuardedSaveOwned's held-owner check (GuardedCountOverflow against a victim's overflow row) is pinned by no test - added `TestADeveloperIsRefusedACountOntoAVictimsOverflowRow`; mutation recorded (line removed -> that leg alone red).
  - `[medium]` `[patch]` Owner and administrator rosters compare a declared list to another declared list - the plans are now built from `OwnerKinds()` and `AdministratorKinds()` and the roster test compares what the plans ran.
  - `[low]` `[patch]` CallerOwns case-insensitivity and empty-owner refusal untested - added `TestTheOwnerComparisonIgnoresCaseAndRefusesAnEmptyName`; mutation (`=` compare) reddens it alone.
  - `[low]` `[patch]` GuardedFinalize on a key naming no row changed from OK to 822 for a non-administrator, unpinned - added `TestAFinalizeOfAKeyThatNamesNoRowIsRefusedForAStranger`; mutation recorded.
  - `[medium]` `[patch]` Several ACs have no `mutation:` line - seven lines added (purge gate, CallerOwns always 0, public expiry in a close, RefreshMark RowVersion, key-owner OK, and the two above); two of them redden several owner-path tests together because the mutation refuses every owner path, recorded as such.
  - `[medium]` `[defer]` A developer appends ledger rows under its own name onto another user's turn key - pre-existing, outside the rewrite-another-user's-row scope; moved to `deferred:` with the recipe.
  - `[low]` `[reject]` OWNERPARENT branch and the property-name guard have no executed test in this batch - the branch has no Batch 1 user and Batch 2 pins it; the guard takes its name from the class dictionary, not a caller.
  - `[false]` `[reject]` AssertPrincipal runs for the first iteration only - a child that ran as the wrong user would answer ok=1 and fail the 822 assertion on every later iteration.
  - `[low]` `[reject]` (intent-alignment) Expectations live at the product surface, tests at the store surface - the real-principal integration net (DeveloperFloorTurn, TurnWire, ProposalWire, AgentWire, LedgerWire, Retention, Installer and others in the Batch 1 table) ran green through those surfaces, and the callers named (Retention, Installer, Definitions) run as administrators by the Code Map's inventory.
  - `[low]` `[reject]` (intent-alignment) Owner-from-storage is applied unevenly: GuardedMint and GuardedAppend compare the user argument - by the spec's own Batch 1 text ("User-argument writers check pUser"); the turn-key residual is the deferred row above.
  - `[false]` `[reject]` (intent-alignment) Public saves are stricter than the owner reading - the spec and the AD-9 amendment say the public saves serve an administrator only for every OWNERWRITE store; an owner uses its store's writers.
  - `[low]` `[reject]` (intent-alignment) Turn, Conversation and Preference are not in this diff - the Pass Scope assigns them to Batches 2 and 3.

### 2026-11-16 - DW-2664 (Batch 1 rework)

- closed: DW-2664. Measured on `ocupilot-ci`. The retention task runs as the account that saved it, `irisowner` on the throwaway (`_SYSTEM` on `ocupilot`, read-only `SELECT`), which holds `%All`; a forced run succeeded and purged an aged ledger row. An administrator holding `OcuPilotAdmin` without `%All` passes the target-key step and the purge. A first install by a non-`%All` account failed: the grant leaves its process without the role, and `GuardedRebuildTargetKeys` refused `822` before reading, on a store with nothing to key.
- fix: `GuardedRebuildTargetKeys` reads the keyless rows first and checks the administrator only when one needs a key. A run that writes still serves an administrator only, so no AD text changes. Decided in-stage: the escalated read now precedes the check; reads are ungated in this story.
- residual (inference): an upgrade from a release before the target key (1.0.13 or earlier) by an account granted the role in that same install still refuses at that step; a second install passes.
- `StoreOwnerWrite`'s rebuild leg seeded no keyless row (the `TargetRef` change recomputed the key), so it now nulls the key in a second statement and asserts it.

### 2026-11-16 - Review pass (Batch 2)

- verdicts: 13 findings - high 0, medium 1, low 12, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` `Turn.GuardedFinish`'s refusal and the unlock on it, and the missing-key refusal of the turn writers, were run by no test - added `TestARefusedFinishReleasesTheOwnersSlot` and `TestAnOwnerWriterOnAKeyThatNamesNoTurnIsRefused`; mutations recorded (unlock removed, `CallerOwns` to 0, missing row accepted).
  - `[low]` `[patch]` `VictimState` could not see a proposal minted on a victim conversation key, so that leg's unchanged-rows assertion could not fail - the query now reads by `ConvKey`; the leg alone reddens when the conversation-key check is removed.
  - `[low]` `[patch]` The Batch 1 mutation line for `GuardedRebuildTargetKeys` named a test the install-step frame now keeps green - replaced at its origin with the observed result and the combined mutation.
  - `[low]` `[patch]` No `mutation:` line for the administrator row of `TranscriptOwnerWrite` or the DW-2663 checks in `GuardedCountOverflow` and `GuardedMint` - five lines added, each observed red and reverted.
  - `[low]` `[reject]` The `Convo.LoadOrCreate` leg's rows-unchanged assertion cannot fail (the load branch writes no row) - the 822 assertion pins it, and it has its own mutation line.
  - `[low]` `[reject]` `TestTheOpenPathsStillWork` and the administrator test depend on the instance-wide sweep - one class at a time on a throwaway, as the open sweep must be tested on the instance's own rows.
  - `[low]` `[reject]` `tUnescalated` is set and never read - removing it leaves an empty Catch; a direct correction with no everyday harm.
  - `[low]` `[reject]` Rule 6's method allowance could outlast the method into a following non-method member - needs a new member added after `EnsureProposalTargetKeys` that also uses `New $ROLES`; the fix adds a guard.
  - `[low]` `[reject]` The Code Map says no product code calls `Propose.GuardedDeleteForTurn`, but `Install/Smoke` does - its status is ignored and the next call deletes the proposals itself; the fix edits the spec.
  - `[low]` `[reject]` (intent-alignment) The forged-owner leg covers `Turn` and not `Convo` - the matrix asks one store per batch, and `OwnerChangeRefused` is the one shared check.
  - `[low]` `[reject]` (intent-alignment) The Always line says `New $ROLES` stays in `Base.cls` - AD-9 was amended for this one method (U-82) before this pass.
  - `[low]` `[reject]` (intent-alignment) Preservation of the turn job, routes and retention is asserted by existing suites, not new tests - those suites ran green (see Verification), and the new tests pin the store surface the matrix names.
  - `[low]` `[reject]` (intent-alignment) DW-2663 and DW-2665 go beyond the intent text - they are this pass's named scope.

### 2026-11-16 - Review pass (Batch 3 and DW-2666)

- verdicts: 13 findings - high 0, medium 0, low 11, false 2, maybe-false 0
- findings:
  - `[low]` `[reject]` The sweep deletes' repeat of state and end time is pinned by no test. Code review pinned it (`ReserveSweepWrite`).
  - `[low]` `[reject]` `Turn.DeleteExpired`'s transaction and rollback are untested. Code review pinned it (`ReserveSweepWrite`).
  - `[low]` `[reject]` The unlock on a refused `SqlRun.GuardedFinish` is unpinned. Code review pinned it (`ReserveSweepWrite`).
  - `[low]` `[reject]` `GuardedViewForOwner`'s instance limit is invisible to every test. Code review found the view reconciled any named user's run and closed it.
  - `[low]` `[reject]` `SqlRun.Reconcile`'s lost-race branch (the conditional update matching no row) has no test - it needs a seam between read and update, and the branch only re-reads the state.
  - `[low]` `[patch]` Several Batch 3 gates have no mutation line of their own - three more observed and recorded: the three administrator gates `Pref.GuardedDeleteForUser`, `Sharing.GuardedDeleteForUser` and `SqlRun.GuardedSweep` each red alone; the owner check at the top of `Sharing.GuardedSetForUser` is shadowed by `GuardedSaveOwned` (stays green), recorded as such.
  - `[low]` `[reject]` `PrefOwnerWrite`'s administrator leg empties the preference and sharing stores - the class is armed for a throwaway and runs one class at a time, and every test creates the rows it reads.
  - `[low]` `[reject]` The queued-run leg seeds 3 seconds back against a 10 second limit - 7 seconds of slack, and the leg runs in about one.
  - `[low]` `[reject]` The probe's `sweepOk` defaults to OK - the legs also assert `ok` and the stored effect, so nothing relies on it alone.
  - `[low]` `[reject]` (intent-alignment) No test reaches a route, the Task Manager or `UserDelete` as a non-administrator - the retention, wire and real-principal turn suites that do ran green on this tree (see Verification), and the new classes pin the store surface the matrix names.
  - `[false]` `[reject]` (intent-alignment) `SqlRun.Reconcile` is outside the five open writers - it is the run reserve's own sweep path and the Pass Scope names it.
  - `[low]` `[reject]` (intent-alignment) The turn sweep deletes the turn row before its children, inside a transaction - the end state and the statements are the same, and it is recorded under Auto Run Result.
  - `[false]` `[reject]` (intent-alignment) `InstanceLimits` is a constant wrapper, not configuration - the ruling names `Loop.LimitsClass()`, which is that constant.

## Design Notes

**Governing ADs:**

- AD-9: escalation and 21.30's store gate.
- AD-7: the turn job writes OcuPilot's own state as its user, and the definition-clearing write.
- AD-8: privilege checked in the caller's process.
- AD-6 and AD-34: a proposal confirmed from its stored arguments.
- AD-33: progress owned by the turn's user.
- AD-37: retention and deleted principals.
- AD-41: per-user bounds.
- AD-46: the per-user ledger.
- AD-50: one per-user preference store.
- AD-15: the marking fact stays as 21.30 left it.

**Rule per store.**

- Agent definitions are administrative configuration (`ADMINWRITE`).
- The other stores hold one user's records (`OWNERWRITE`): the owner, or an administrator, writes them.
- Cross-user deletes and purges are an administrator's: the retention task's, the installer's and the smoke's.
- The open writers are `Agent.GuardedClearVerification`, `Turn.GuardedAbandonForUser`, the two reserve-time sweeps and the close-time expiry. Each writes only what the instance's own rule decides.

**AD amendment for the spec gate.** This amends AD-9. Append to its Rule after 21.30's paragraph:

> **Per-user state answers to its owner, and agent definitions to an administrator** [AMENDED 2026-11-16, Story 21.33, owner answer U-82, DW-2638]. The agent definitions join the `ADMINWRITE` stores. A turn's finding that a definition's credential no longer resolves is recorded by any caller through `Agent.GuardedClearVerification`, which writes the verification and enabled flags and the default marker and nothing else (AD-7). The stores holding one user's records (`OWNERWRITE`) refuse a write to a row whose owner is not the caller with `ERROR #822` and change nothing, unless the caller holds `OcuPilotAdmin:USE`. Those stores are turns with their steps and directives, conversations with their entries, proposals, the ledger, preferences, the sharing choice and background runs. A row's owner is read from storage, never from the object handed in, and a save cannot change it. `Base`'s public object saves serve an administrator only for every `ADMINWRITE` or `OWNERWRITE` store. Deletes and purges across users are an administrator's. Four writes stay open because a product path makes them on another user's behalf by the instance's own rule: a turn reserve's sweep of expired turns, a background run reserve's sweep of ended runs, a proposal close's expiry of lapsed proposals, and `Turn.GuardedAbandonForUser`.

**AD amendment for the spec gate (DW-2665).** Open: no code changed. Measured on `ocupilot-ci` (2026-11-16):

- Red before the fix. A probe proposal was seeded with no key. `OcuPilotAdminPathInstaller` (`%Admin_Secure:U`, `%DB_IRISSYS:RW` and the install namespace's databases, no `%All`) then ran `EnsureGrant` and `EnsureProposalTargetKeys` in one child process. The grant succeeded, `holdsAdmin` stayed 0, the step returned `822`, and the row kept no key.
- A non-`%All` process can add `OcuPilotAdmin` to itself with `New $ROLES` and `Set $ROLES` only when it can write the system database. `%DB_IRISSYS:RW` alone was admitted; `%Admin_Secure:U` alone and `%Development:U` alone were refused `<PROTECT>`. A process that can write `IRISSYS` can already grant itself any role.
- `Base`'s privileged application grants only `%DB_OCUPILOT`. Running the step under that application's role skips the store gate only if a new installer-only entry point checks no caller. ObjectScript cannot make a `Propose` method private to `Installer`. Every route therefore changes AD-9's text, and `scripts/check-objectscript.py` rule 6 confines `New $ROLES` to `Base.cls`.

Proposed design: `Installer.EnsureProposalTargetKeys` (the step `Install` and the start path run) adds the administrative role (`pNames`-style name from `Base.#ADMINRESOURCE`) to its process in a `New $ROLES` frame around the one rebuild call. When IRIS refuses the addition, the step runs unescalated and the store gate decides. `Propose.GuardedRebuildTargetKeys` stays administrator-only for a row that needs a key. A developer is refused in two ways. IRIS refuses its `Set $ROLES` with `<PROTECT>`, and the store then answers `822`. Rule 6 admits `Installer.cls` for `New $ROLES` only, with a harness case. `AdminPathWrite` gains the keyless-row test, and its Rule 19 mutation removes the frame. The empty-store test's mutation becomes "frame removed and check before read". `StoreOwnerWrite` re-proves the developer's `822`.

Proposed AD-9 text, appended after 21.33's paragraph:

> **The install's target-key step holds the administrative role the install grants** [AMENDED 2026-11-16, Story 21.33, DW-2665]. An install grants `OcuPilotAdmin` to the installing account, and the grant does not reach the running process. An upgrade from a release whose proposals carry no target key (1.0.13 or earlier) then writes other users' proposal rows. `Installer.EnsureProposalTargetKeys` therefore adds the administrative role to its own process with `Set $ROLES`, inside a `New $ROLES` frame around that one call, and the frame unwinds before the next step. IRIS admits the addition only to a process that can write the system database, and such a process can already grant itself any role, so the addition widens nothing. The store gate still reads `OcuPilotAdmin:USE` in the calling process at the call (AD-8). A process that cannot add the role runs the step unescalated, and the store's own gate decides. This is the one `New $ROLES` outside `Base`, and it acquires no privileged application's role.

**Behavior changes for the orchestrator.** These non-admin, non-owner product paths are kept working unchanged; each is a proposal only:

1. `Screen/Tool/UserDelete.AfterWrite` abandons a deleted account's turns as a security administrator without `OcuPilotAdmin`. `AbandonForUser` stays open, so a developer can abandon any user's running turns. Proposed: admit a non-owner only when the identity read answers the account absent.
2. Every user's turn reserve deletes other users' terminal turns past retention. Kept; the daily retention task already does the same.
3. Every user's background-run reserve sweeps ended runs. Kept likewise.
4. Every proposal close expires every user's lapsed proposals. Kept likewise.
5. Any user's turn disables a definition whose credential no longer resolves (AD-7). Kept, so a developer can disable any definition.

**Decided in-stage:**

- Owner comparison is case-insensitive. IRIS user names are, and `UserDelete` already matches that way.
- An unresolved owner refuses a non-administrator.
- Sharing and background runs join, as the same defect class in the story's intent. The install-owned stores and `Access` do not: their rule differs and a wrong gate risks the install path. They go to `deferred:`.
- An owner can still rewrite its own ledger rows through `GuardedFinalize`. That is a named limit; DW-2638 is about other users' rows.
- Batch 1 helpers on `Base`, all private: `GuardedSaveOwned`, `GuardedStoredOwnerById` (the stored owner of a row by id), `KeyOwnerRefused` (the stored owner by a unique key) and `PublicSaveRefused` (the public saves' check for `ADMINWRITE` or `OWNERWRITE` stores). The plain-save twin is not written: no batch 1 writer saves through `GuardedSave`.
- A key writer on a key that names no row is refused for a non-administrator, as an unresolved owner is. `Ledger.GuardedFinalize` on a purged row therefore answers 822 for its owner instead of OK.
- `GuardedExpireStale` with a user is an owner write; with `""` it is an administrator's. Only the close by key and the close by conversation expired every user's lapsed rows (`GuardedExpireStale("")`); the close by user passes its own user. The private expiry keeps each one's argument, so the close by user is unchanged.
- `Agent.RebalanceDefaultSql` clears the marker with `NULL`, which the object layer reads back as `""`. It raises the `RowVersion` of a row it marks or unmarks, as the object-layer write did, so `RefreshMark` now also copies the stored version into the object `GuardedCreate` and `GuardedUpdate` were given (a caller that saves the same object again was refused as stale without it).
- `OwnerWriteRefused` resolves `OWNERPARENT` through the parent's `GuardedStoredValue`. No batch 1 store sets `OWNERPARENT`, so that branch has no test before batch 2.
- Each copy is the stated choice:
  - The reserve-time cascade repeats the three one-line child `DELETE`s, because the children's public deletes are now administrator-only and a cross-class private call does not exist.
  - The tests reuse 21.30's harness by parameterizing it rather than copying it.
  - Three test classes, one per batch, each stay near the 500-line guideline.
- The epic context cache is older than `epics.md`. Per the runner's rule it was reused, not recompiled; the 21.33 block was read from `epics.md` directly.

**Integration ACs.** Consumers are the turn job, confirm and draft, the routes, `ProviderPort` and the retention task, each through its existing real-principal or wire suite. `Consumes:` `Kernel/State/Base`. `Consumed-by:` Stories 24.6 and 24.7, whose consoles run code with the person's rights.

## Verification

**Shared surfaces:**

- `Base`'s public surface: `BaseSurface`, `TestTheAdministratorStoresAreDeclared`.
- The `ADMINWRITE` roster, which Agent joins.
- The `OCUPILOT_ALLOW_PRINCIPALS` roster in `scripts/ci-throwaway.sh`, which `ui/tools/ci.test.mjs` checks.
- The non-administrator behavior of every per-user writer.

*Every test added or changed passes on a fresh environment, in either order.*

**Commands.** Run one command per foreground call with `timeout: 600000`, against `ocupilot-ci` only, and never put two test calls in one message.

- `(loop)` `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/b708a79b-b765-42ec-adea-dbc87acf6251/scratchpad/e21u/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` -- expected: `LOADERRORS=0`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<Class>`, one class per call -- expected: green after the fix (red legs at Task 0).
  - Batch 1: `StoreOwnerWrite`, `AdminStateWrite`, `State`, `AgentState`, `AgentWire`, `AgentWireSecurity`, `AgentConnectionWire`, `AgentCredential`, `TurnProviderFault`, `ProposalMint`, `ProposalConfirm`, `ProposalClose`, `ProposalRace`, `ProposalWire`, `DraftExecute`, `Ledger`, `LedgerWire`, `TranscriptsWire`, `DeveloperFloorTurn`, `ExplorerSaveTurn`, `Retention`, `Installer`, `Demo`.
  - Batch 2: `TranscriptOwnerWrite`, `TurnStore`, `TurnWire`, `TurnConversation`, `TurnNavigate`, `NavSettleJob`, `TurnHourLimit`, `TurnLoop`, `Convo`, `TranscriptStore`, `ConversationRestore`, `DeveloperFloorTurn`, `Retention`.
  - Batch 3: `PrefOwnerWrite`, `PrefState`, `PreferencesWire`, `AgentPick`, `AgentPickTurn`, `SqlRunStore`, `SqlBackgroundJob`, `SqlBackgroundRoutes`, `ContextBound`, `AdminStateWrite`, `Retention`.
- `(loop)` `uv run scripts/check-objectscript.py`; `uv run scripts/test_check_objectscript.py`; `cd ui && node --test tools/ci.test.mjs`; `bash scripts/lint-docs.sh _bmad-output/implementation-artifacts/spec-21-33-ocupilot-s-other-guarded-stores-refuse-a-caller-who-may-not.md` -- expected: 0 problems.
- `(once)`, the runner's: the full ObjectScript sweep, one class per call; `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS`; and Rule 30's fresh check. No browser spec is touched, so the browser suite is left to CI.

**Mutations (Rule 19).** Apply each, observe red, revert, confirm `git status --short` and `git diff --stat` are unchanged, then reload.

- `OwnerWriteRefused` answers `$$$OK` first -> only the refusal tests go red.
- `Agent` `ADMINWRITE` = 0 -> the agent refusal test and the roster test go red.
- `GuardedClearVerification` goes back through `GuardedUpdate` -> the credential-finding test (held edit stored) goes red.
- `GuardedSaveOwned` skips the stored-versus-held owner comparison -> the forged-owner test goes red.
- `Turn.GuardedReserve` calls the public `GuardedSweep` -> the open-sweep test goes red.

**Runner ruling at the spec gate (2026-11-16):** validated. The AD-9 amendment above is written into the spine (comply first under U7; the orchestrator is told). The five non-admin, non-owner paths stay unchanged, as listed, for the orchestrator. The frontmatter deferrals are ledgered as DW-2651 (high) and DW-2652 (medium), decision-pending for the orchestrator.

### Task 0 (pre-fix)

Run 2026-11-16 on `ocupilot-ci` against the unchanged product (`OcuPilot.Test.StoreOwnerWrite`, run 3; raw output in the stage scratch directory, `21-33/run3.txt`). The principal is `OcuPilotOwnerWriteDev`: `%Development:USE` and the code read, no `OcuPilotAdmin`, no `%All`. Every call answered OK and landed. The administrator in the lead leg is the suite's own `%All` identity, which owns the proposal and confirms it through `ConfirmFixture`; its port is the fixture, so nothing reached the instance. Other-user rows belong to a name no account has. Teardown left 0 definitions, proposals, ledger rows, users and roles of the suite's.

| Leg (developer call) | Before | After |
|----------|--------|-------|
| Open an administrator's live proposal, replace arguments, payload, diff and fingerprint with a mint's values for another description, save through `Base.GuardedSave` | stored Description `after` | stored Description `EVIL`; the administrator's confirm sent `{"Name":"/csp/ocupilotprobeconfirm","Description":"EVIL","Enabled":true}` |
| The same through `Base.GuardedSaveIfCurrent` | stored Description `after` | stored Description `EVIL`; the confirm sent the same body |
| `Agent.GuardedUpdate`, instructions | `instructions as an administrator wrote them`, version 0 | `instructions as a developer rewrote them`, version 1 |
| `Base.GuardedSave` and `GuardedSaveIfCurrent` of an opened definition | same | same rewrite, each |
| `Agent.GuardedCreate` | 2 definitions | 3, the new one enabled and verified |
| `Agent.GuardedDeleteId` | 2 definitions | 1 |
| `Agent.GuardedMarkCredentialCreated` | `CredentialCreated` 0 | 1 |
| `Agent.GuardedSetVerification` | `ConnectionVerified` 0 | 1 |
| `Agent.SetDefaultGuarded` | marker on the other definition | marker on the target |
| `Agent.GuardedRebalanceDefault` (marked definition disabled) | marker on the disabled definition | marker on the target |
| `Agent.GuardedClearVerification` holding the edited row | `Enabled` 1, instructions original | `Enabled` 0, and the held instructions stored, version 1 |
| `Ledger.GuardedAppend` as the victim | 1 row | 2, the new one `probe.forged` |
| `Ledger.GuardedFinalize` of a victim row | status `ok`, version 1 | status and code `forged`, version 2 |
| `Propose.GuardedMint` with user = victim | 1 proposal | 2 |
| `Propose.GuardedClose` of a victim proposal | `live` | `canceled`, reason `you` |
| `Propose.GuardedClaimAndClose` of a victim proposal | `live`, burned 0, version 1 | `confirmed`, burned 1, version 2 |
| `Ledger.GuardedDeleteForUser(victim)`, `Propose.GuardedDeleteForUser(victim)` | 1 row each | 0 each |

### Batch 1 (post-fix)

Run 2026-11-16 on `ocupilot-ci`, one class per call, after `reload.sh` (`LOADERRORS=0`). Run ids are the instance's `%UnitTest` indexes. Classes that touch the agent store were re-run after the last product edit (`RefreshMark`); the ids below are those runs.

| Class | Tests | Result | Run |
|-------|-------|--------|-----|
| StoreOwnerWrite | 13 | pass | 63 |
| AdminStateWrite | 7 | pass | 64 |
| State | 12 | pass | 53 |
| AgentState | 13 | pass | 34 |
| AgentWire | 18 | pass | 35 |
| AgentWireSecurity | 5 | pass | 36 |
| AgentConnectionWire | 1 | pass | 37 |
| AgentCredential | 17 | pass | 14 |
| TurnProviderFault | 6 | pass | 15 |
| ProposalMint | 0 | not a test class (the mint fixture `Mint` subclass) | 16 |
| ProposalConfirm | 24 | pass | 17 |
| ProposalClose | 7 | pass | 18 |
| ProposalRace | 6 | pass | 19 |
| ProposalWire | 17 | pass | 20 |
| DraftExecute | 2 | pass | 21 |
| Ledger | 11 | pass | 22 |
| LedgerWire | 6 | pass | 23 |
| TranscriptsWire | 7 | pass | 24 |
| DeveloperFloorTurn | 1 | pass | 25 |
| ExplorerSaveTurn | 1 | pass | 26 |
| Retention | 10 | pass | 27 |
| Installer | 27 | pass | 28 |
| Demo | 12 | pass | 29 |
| TurnWire | 15 | pass | 30 |
| TurnConversation | 11 | pass | 31 |
| DefinitionDefaults | 5 | pass | 38 |
| ProposalCreate | 11 | pass | 40 |
| Proposal | 15 | pass | 41 |

`AgentCredential` failed once (run 13) when the SQL rebalance left a held definition at a stale version; `RefreshMark` was fixed and the class passed (run 14). `uv run scripts/check-objectscript.py` 0 problems; `uv run scripts/test_check_objectscript.py` 152 tests OK; `node --test tools/ci.test.mjs` 103 pass.

**The five open paths** (`TestTheOpenPathsStillWork`, run as `OcuPilotOwnerWriteDev`: `%Development:USE`, no `OcuPilotAdmin`, no `%All`). The test passes on the unfixed tree: with `HEAD`'s `Base`, `Agent`, `Propose` and `Ledger` loaded into `ocupilot-ci` (run 42), seven tests of the class are red and `TestTheOpenPathsStillWork` and the owner and administrator path tests are green. The worktree source was loaded back (`LOADERRORS=0`) and the class passed (run 43).

| Path | Effect asserted |
|------|-----------------|
| `Turn.GuardedAbandonForUser(victim)` | count 1 and the abandon signal set on the victim's running turn |
| `Turn.GuardedReserve` | the developer's turn stored, the sweep succeeds, the victim's day-old completed turn and the proposal minted on it are gone |
| `SqlRun.GuardedReserve` | the developer's run stored, the victim's ended run is gone |
| `Propose.GuardedClose` and `GuardedCloseLiveForConvo` | the developer's proposal canceled and the victim's lapsed one `expired` |
| `Agent.GuardedClearVerification` | `Enabled` 0, `ConnectionVerified` 0, the marker moved off the cleared default |

mutation: `OwnerWriteRefused` answers `$$$OK` first -> `TestADeveloperIsRefusedAVictimsLedgerAndProposalRows` (every ledger and proposal owner leg, the lapsed-proposal expiry included), `TestADeveloperIsRefusedACountOntoAVictimsOverflowRow` and the empty-name leg of `TestTheOwnerComparisonIgnoresCaseAndRefusesAnEmptyName` red, each a refusal test (code review, run 91); reverted, `Base.cls` byte-identical, reloaded.
mutation: `Agent` `ADMINWRITE` = 0 -> `StoreOwnerWrite.TestADeveloperIsRefusedTheAgentDefinitionWrites` red alone (run 46) and `AdminStateWrite.TestTheAdministratorStoresAreDeclared` red alone (run 47); reverted, `Agent.cls` byte-identical (md5 `45757393...`), reloaded.
mutation: `GuardedClearVerification` opens the row, clears the flags and saves it through `GuardedSaveIfCurrentAnyCaller` -> `TestAClearedVerificationStoresNoHeldEdit` red alone, on the held edit (code review, run 93); reverted, `Agent.cls` byte-identical, reloaded.
mutation: `OwnerChangeRefused` skips the stored-versus-held comparison -> `TestAForgedOwnerIsRefusedAndTheStoredOwnerStands` red alone, developer and administrator legs (code review, run 90); reverted, `Base.cls` byte-identical, reloaded.
mutation: `PublicSaveRefused` answers `$$$OK` -> the two live-proposal tests and the agent definition test red (run 50); reverted, byte-identical, reloaded.
mutation: `Ledger` `OWNERWRITE` emptied -> `TestTheOwnerStoresAreDeclared`, the victim rows test and the forged-owner test red (run 51); reverted, `Ledger.cls` byte-identical (md5 `a0519a84...`), reloaded.
mutation: the held-owner `OwnerWriteRefused` call removed from `GuardedSaveOwned` -> `TestADeveloperIsRefusedACountOntoAVictimsOverflowRow` red alone (run 55); reverted, `Base.cls` byte-identical (md5 `d1976db3...`), reloaded.
mutation: `CallerOwns` compares with `=` -> `TestTheOwnerComparisonIgnoresCaseAndRefusesAnEmptyName` red alone (run 56); reverted, `Base.cls` byte-identical, reloaded.
mutation: `CallerOwns` answers 0 always -> `TestADeveloperWritesItsOwnProposalAndLedgerRows`, `TestTheOpenPathsStillWork` and `TestTheOwnerComparisonIgnoresCaseAndRefusesAnEmptyName` red (run 57), each an owner or open path that the mutation refuses; reverted, `Base.cls` byte-identical, reloaded.
mutation: the administrator gate removed from `Ledger.GuardedPurgeBefore` -> `TestADeveloperIsRefusedAVictimsLedgerAndProposalRows` red alone (run 58); reverted, `Ledger.cls` byte-identical (md5 `a0519a84...`), reloaded.
mutation: `Propose.GuardedClose` calls the public `GuardedExpireStale("")` instead of `ExpireStaleAnyCaller` -> `TestADeveloperWritesItsOwnProposalAndLedgerRows` and `TestTheOpenPathsStillWork` red (run 59), the two tests that close as a non-administrator; reverted, `Propose.cls` byte-identical (md5 `cd2739bc...`), reloaded.
mutation: `RefreshMark` drops the `RowVersion` copy -> `StoreOwnerWrite` stays green (run 60); `AgentCredential.TestAnUnreachableRungIsRefusedBeforeTheShapeCheck` red alone (run 61); reverted, `Agent.cls` byte-identical (md5 `45757393...`), reloaded.
mutation: `KeyOwnerRefused` answers `$$$OK` for a key that names no row -> `TestAFinalizeOfAKeyThatNamesNoRowIsRefusedForAStranger` red alone (run 62); reverted, `Base.cls` byte-identical, reloaded.
mutation: the stored-target check removed from `Propose.GuardedClaimAndClose` -> `TestAClaimCancelsOnlyItsOwnTargetsSiblings` red alone (code review, run 89); reverted, `Propose.cls` byte-identical, reloaded.
mutation: `RebalanceDefaultSql` clears the marker with `''` -> `TestAClearedVerificationStoresNoHeldEdit` red alone, on the object-layer read of the cleared marker (code review, run 92); reverted, `Agent.cls` byte-identical, reloaded.
mutation: `Propose.GuardedClose` expires only the caller's lapsed proposals (`ExpireStaleAnyCaller(pUser)`) -> `TestTheOpenPathsStillWork` red alone, path 4 (code review, run 94); reverted, `Propose.cls` byte-identical, reloaded.
mutation: the administrator bypass removed from `OwnerWriteRefused` -> seven tests red, `TestAnAdministratorWritesAVictimsRowsAndTheDefinitions` among them, each at the suite identity's own seeding mint, which is an administrator's write (code review, run 95); reverted, `Base.cls` byte-identical, reloaded.

**Code review re-run** (2026-11-16, after the review patches, `ocupilot-ci`, one class per call, `LOADERRORS=0`): StoreOwnerWrite 14 (run 97), AdminStateWrite 7 (98), AgentState 13 (99), AgentWire 18 (77), AgentCredential 17 (79), ProposalConfirm 24 (80), ProposalRace 6 (81), ProposalWire 17 (82), DeveloperFloorTurn 1 (83), LedgerWire 6 (84), Ledger 11 (85), State 12 (86), ProposalClose 7 (87), Installer 27 (88), all green; `check-objectscript` 0 problems, its harness OK, `ci.test.mjs` 103 pass.

**DW-2664** (2026-11-16, fresh `ocupilot-ci`, `LOADERRORS=0`): new `AdminPathWrite` (3 tests, probe `AdminPathProbe`) green (runs 1, 5); StoreOwnerWrite 14 (run 9), AdminStateWrite 7 (10), Retention 10 (11), Ledger 11 (12), Installer 27 (13), PortGate 4 (14), ProposalTargetKey 7 (15), all green; `check-objectscript` 0 problems, its harness OK, `ci.test.mjs` 103 pass.
mutation: `GuardedRebuildTargetKeys` checks the administrator before it reads -> `AdminPathWrite.TestADeveloperCallingTheTargetKeyStepIsRefused` red alone, on its empty-store leg, because the install-step frame keeps the first-install and upgrade tests green (run 81); reverted, `Propose.cls` byte-identical (md5 `3357c68c...`), reloaded.
mutation: that check made before the read and the frame removed from `Installer.EnsureProposalTargetKeys` together -> `TestAFirstInstallWithoutAllPassesTheTargetKeyStep`, `TestAnUpgradeByAnAccountGrantedTheRoleInTheSameInstallKeysTheProposals` and the developer's empty-store leg red (run 82); reverted, `Propose.cls` and `Installer.cls` byte-identical (md5 `3357c68c...`, `183d1f52...`), reloaded.
mutation: `Ledger.GuardedPurgeBefore` also requires `%All` -> `TestAnAdministratorWithoutAllKeysProposalsAndPurgesTheLedger` red alone (run 3); reverted, `Ledger.cls` byte-identical (md5 `a0519a84...`), reloaded.
mutation: `Ledger.GuardedPurgeBefore` refuses every caller -> `TestTheRetentionTaskPurgesTheLedgerAsItsOwnUser` and the administrator test red (run 4); reverted, byte-identical, reloaded.
mutation: `GuardedRebuildTargetKeys` drops its administrator check -> `StoreOwnerWrite.TestADeveloperIsRefusedAVictimsLedgerAndProposalRows` red alone, the rebuild leg (run 8); reverted, `Propose.cls` byte-identical, reloaded.

### Task 0 (batch 2, pre-fix)

Run 2026-11-16 on `ocupilot-ci` against the product before any Batch 2 change (`OcuPilot.Test.TranscriptOwnerWrite`, run 2; raw output in the stage scratch directory, `21-33/impl2/task0-run2.txt`). The principal is `OcuPilotTranscriptDev`: `%Development:USE` and the code read, no `OcuPilotAdmin`, no `%All`. Every call answered OK and the victim's rows changed as listed; the victim is a name no account has, and its rows were seeded as the suite identity. Teardown left 0 turns, conversations, proposals and ledger rows of the suite's.

| Leg (developer call, one child process each) | Before | After |
|----------|--------|-------|
| `Turn.GuardedFinish` | running, reply empty, version 1 | completed, reply `a reply`, version 2 |
| `Turn.GuardedBegin` of a queued turn, `GuardedReconcile`, `GuardedProgress`, `GuardedAddDropped` | turn row as seeded | turn row changed (state, counts, version) |
| `Turn.GuardedRequestStop`, `GuardedRenew` | no stop signal, renewed 1 | stop signal 1, renewed raised |
| `Turn.GuardedReserve` for the victim | 3 victim turns | a fourth queued turn |
| `Turn.GuardedForgetStarts`, `GuardedSweepStarts` | one old start record | none |
| `Turn.GuardedSweep` | an expired turn with a step, a directive and a proposal | all removed |
| `Turn.GuardedDelete` of the running turn | turn, 2 steps, a directive, a proposal, signals | all removed |
| `Step.GuardedUpdate` | step 2 `running`, version 1 | `ok`, summary `updated`, version 2 |
| `Step.GuardedAppend`, `GuardedSnapshotText`, `GuardedFinishTool`, `GuardedDeleteForTurn` | steps as seeded | a step added, rewritten or removed |
| `Nav.GuardedRequest`, `GuardedSettle`, `GuardedDeleteForTurn` | directive unsettled | rewritten, settled `opened`, or removed |
| `Convo.AppendEntry` through the victim's conversation opened by id | 1 entry | 2 entries |
| `Convo.LoadOrCreate` of the victim's conversation | not loaded | loaded, exclusively locked (no row changed) |
| `Convo.GuardedDelete` | conversation and entry | both removed |
| `Convo.GuardedPurgeEmpty`, `Entry.GuardedAppend`, `GuardedDeleteForConvo`, `GuardedPurge` | rows as seeded | removed or added |
| `Propose.GuardedDeleteForTurn` | the running turn's proposal | removed |
| `Turn.ForgedProgress` and `Turn.ForgedSave`: the developer's own turn held with its `UserName` set to the victim | stored owner the developer | stored owner the victim |
| Ledger row appended, overflow row counted and proposal minted by the developer on the victim's turn key; proposal minted on the victim's conversation key | no row | each stored (the turn's caps spent) |

### Batch 2 (post-fix)

Run 2026-11-16 on `ocupilot-ci`, one class per call, after `reload.sh` (`LOADERRORS=0`). Run ids are the instance's `%UnitTest` indexes of the final run of each class after the last product edit.

| Class | Tests | Result | Run |
|-------|-------|--------|-----|
| TranscriptOwnerWrite | 9 | pass | 83 |
| StoreOwnerWrite | 14 | pass | 84 |
| AdminPathWrite | 5 | pass | 85 |
| AdminStateWrite | 7 | pass | 25 |
| TurnStore | 11 | pass | 7 |
| TurnWire | 15 | pass | 6 |
| TurnConversation | 11 | pass | 8 |
| TurnNavigate | 15 | pass | 9 |
| TurnHourLimit | 9 | pass | 11 |
| TurnLoop | 11 | pass | 12 |
| TurnStream | 7 | pass | 29 |
| Convo | 7 | pass | 13 |
| TranscriptStore | 5 | pass | 14 |
| ConversationRestore | 4 | pass | 15 |
| DeveloperFloorTurn | 1 | pass | 5 |
| Retention | 10 | pass | 16 |
| TurnProviderFault | 6 | pass | 17 |
| ExplorerSaveTurn | 1 | pass | 18 |
| TurnContext | 16 | pass | 19 |
| ProposalConfirm | 24 | pass | 20 |
| ProposalClose | 7 | pass | 30 |
| ProposalWire | 17 | pass | 28 |
| Ledger | 11 | pass | 27 |
| LedgerWire | 6 | pass | 21 |
| TranscriptsWire | 7 | pass | 22 |
| Installer | 27 | pass | 26 |

`NavSettleJob` is the job helper `TurnNavigate` starts, not a test class: the runner reports it as ran 0 test methods. `uv run scripts/check-objectscript.py` 0 problems; `uv run scripts/test_check_objectscript.py` 158 tests OK; `node --test tools/ci.test.mjs` 103 pass.

**DW-2665.** Red before, green after (`AdminPathWrite`): the frame removed from `Installer.EnsureProposalTargetKeys` (run 40) -> `TestAnUpgradeByAnAccountGrantedTheRoleInTheSameInstallKeysTheProposals` red alone, the step refused 822 and the proposal keyless; with the frame, green (runs 24, 47). The developer's public call is refused: IRIS answers its own `Set $ROLES` with `<PROTECT>` and the store answers 822 (`TestADeveloperCallingTheTargetKeyStepIsRefused`); an account holding `%DB_IRISSYS:RW` is admitted the same addition. DW-2664's three tests stay green.

mutation: `OwnerWriteRefused` answers `$$$OK` first -> `TestADeveloperIsRefusedAVictimsTranscript` red alone, 18 owner-write legs (run 31); reverted, `Base.cls` byte-identical (md5 `a02d5f6b...`), reloaded.
mutation: `OwnerChangeRefused` skips the stored-versus-held owner comparison -> `TestAForgedOwnerIsRefusedAndTheStoredOwnerStands` red alone, the administrator legs (run 32); reverted, `Base.cls` byte-identical, reloaded.
mutation: `Turn.GuardedReserve` calls the public `GuardedSweep` -> `TestTheOpenPathsStillWork` red alone (run 33); reverted, `Turn.cls` byte-identical (md5 `6b66f554...`), reloaded.
mutation: `Parameter OWNERWRITE` emptied on `Step` -> `TestADeveloperIsRefusedAVictimsTranscript` and `TestTheOwnerStoresAreDeclared` red (run 34); reverted, `Step.cls` byte-identical (md5 `aa0935d9...`), reloaded.
mutation: the turn-owner check removed from `Ledger.GuardedAppend` -> `TestADeveloperCannotSpendAVictimsTurnCaps` red on its append leg alone (run 35); reverted, `Ledger.cls` byte-identical (md5 `6a6e1a01...`), reloaded.
mutation: the conversation-owner check removed from `Propose.GuardedMint` -> `TestADeveloperCannotSpendAVictimsTurnCaps` red on its conversation-key leg alone (run 36); reverted, `Propose.cls` byte-identical (md5 `3357c68c...`), reloaded.
mutation: the owner check removed from the load branch of `Convo.LoadOrCreate` -> `TestADeveloperIsRefusedAVictimsTranscript` red on its `Convo.LoadOrCreate` leg alone (run 37); reverted, `Convo.cls` byte-identical (md5 `5f3fd930...`), reloaded.
mutation: the administrator gate removed from `Propose.GuardedDeleteForTurn` -> `TranscriptOwnerWrite.TestADeveloperIsRefusedAVictimsTranscript` (run 38) and `StoreOwnerWrite.TestADeveloperIsRefusedAVictimsLedgerAndProposalRows` (run 39) red, each on that leg alone; reverted, `Propose.cls` byte-identical, reloaded.
mutation: an administrator gate added to `Turn.GuardedAbandonForUser` -> `TestTheOpenPathsStillWork` red alone (run 43); reverted, `Turn.cls` byte-identical, reloaded.
mutation: `CallerOwns` answers 0 always -> `TestADeveloperWritesItsOwnTurnAndConversation`, `TestTheOpenPathsStillWork` and `TestADeveloperCannotSpendAVictimsTurnCaps` red (run 44), each an owner or open path that the mutation refuses; reverted, `Base.cls` byte-identical, reloaded.
mutation: the `New $ROLES` frame and its `Set $ROLES` removed from `Installer.EnsureProposalTargetKeys` -> `TestAnUpgradeByAnAccountGrantedTheRoleInTheSameInstallKeysTheProposals` red alone (run 40); reverted, `Installer.cls` byte-identical (md5 `183d1f52...`), reloaded.
mutation: `Propose.GuardedRebuildTargetKeys` drops its administrator check -> `TestADeveloperCallingTheTargetKeyStepIsRefused` red alone (run 41); reverted, `Propose.cls` byte-identical, reloaded.
mutation: the slot release removed from `Turn.GuardedFinish`'s refusal, and separately `CallerOwns(pUser)` there made `0` -> `TestARefusedFinishReleasesTheOwnersSlot` red alone, on the held leg (runs 74, 75); reverted, `Turn.cls` byte-identical (md5 `6b66f554...`), reloaded.
mutation: `KeyOwnerRefused` answers `$$$OK` for a key that names no row -> `TestAnOwnerWriterOnAKeyThatNamesNoTurnIsRefused` (three legs) and the finish leg of `TestARefusedFinishReleasesTheOwnersSlot` red, which deletes its turn row first (run 76); reverted, `Base.cls` byte-identical (md5 `a02d5f6b...`), reloaded.
mutation: the administrator bypass removed from `OwnerWriteRefused` -> five tests red at `SeedVictim`, whose mint as the suite's `%All` identity is an administrator's write, `TestAnAdministratorWritesAVictimsTranscriptAndSweeps` among them (run 77); reverted, `Base.cls` byte-identical (md5 `a02d5f6b...`), reloaded.
mutation: the `NamedOwnerRefused` call removed from `Ledger.GuardedCountOverflow` -> `TestADeveloperCannotSpendAVictimsTurnCaps` red on its overflow leg alone, the 822 and the unchanged-rows assertions (run 78); reverted, `Ledger.cls` byte-identical (md5 `6a6e1a01...`), reloaded.
mutation: the turn-key `NamedOwnerRefused` call removed from `Propose.GuardedMint` -> `TestADeveloperCannotSpendAVictimsTurnCaps` red on its turn-key mint leg alone (run 79); with the conversation-key call removed instead, red on its conversation-key leg alone, the unchanged-rows assertion included, because `VictimState` now reads proposals by the conversation key (run 80); each reverted, `Propose.cls` byte-identical (md5 `3357c68c...`), reloaded.
mutation: rule 6 admits `New $ROLES` in every method of `Installer.cls` -> `test_new_roles_in_another_installer_method_is_refused` red alone; reverted, `check-objectscript.py` byte-identical (md5 `f773d659...`).
mutation: the conversation-owner check removed from `Ledger.GuardedAppend` -> `TestADeveloperCannotSpendAVictimsTurnCaps` red on its `Ledger.GuardedAppend.Convo` leg alone (code review, run 105); and from `GuardedCountOverflow` -> red on its `.Convo` overflow leg alone (run 106); each reverted, `Ledger.cls` byte-identical (md5 `12af369c...`), reloaded.
mutation: the entry `DELETE` removed from `Convo.GuardedDelete` -> `TestADeveloperWritesItsOwnTurnAndConversation` red alone, on the entries assertion (code review, run 107); reverted, `Convo.cls` byte-identical (md5 `209adec7...`), reloaded, and the run's orphan entries removed.
mutation: `Convo.LoadOrCreate`'s create branch without its caller check and saving through `GuardedSaveIfCurrentAnyCaller` -> `TestADeveloperIsRefusedAVictimsTranscript` red alone, on its create-in-the-victim's-name leg (code review, run 108); reverted, `Convo.cls` byte-identical, reloaded.
mutation: `New $ROLES` alone removed from `Installer.EnsureProposalTargetKeys` -> `TestAnUpgradeByAnAccountGrantedTheRoleInTheSameInstallKeysTheProposals` red alone, on the role still held when the step returns (code review, run 109); reverted, `Installer.cls` byte-identical (md5 `8e24d0f6...`), reloaded.
mutation: rule 6's method tracking made sticky once `EnsureProposalTargetKeys` is entered -> `test_new_roles_in_a_method_after_the_target_key_step_is_refused` red alone; reverted, `check-objectscript.py` byte-identical (md5 `f773d659...`).

### Task 0 (batch 3, pre-fix)

Run 2026-11-16 on `ocupilot-ci` against the product before any Batch 3 change (`OcuPilot.Test.PrefOwnerWrite`, run 2; raw output in the stage scratch directory, `21-33/impl3/task0-pref2.txt`). The principal is `OcuPilotPrefDev`: `%Development:USE` and the code read, no `OcuPilotAdmin`, no `%All`. Every call answered OK and the victim's rows changed as listed; the victim is a name no account has, and its rows were seeded as the suite identity. Teardown left 0 preferences, sharing rows and runs of the suite's.

| Leg (developer call, one child process each) | Before | After |
|----------|--------|-------|
| `Pref.GuardedAdd`, `GuardedRemove`, `GuardedClear` | two favorites | one more, one fewer, none |
| `Pref.GuardedTouch`, `GuardedTrim` | a recent screen, version 0 | version 1; removed |
| `Pref.GuardedSetValue` | view `sort=Name`, version 0 | `evil`, version 1 |
| `Base.GuardedSave`, `GuardedSaveIfCurrent` of a victim preference row | `sort=Name` | `evil` through each |
| `Pref.DeleteAllGuarded`, `GuardedDeleteForUser` | four rows | none |
| `Sharing.GuardedSetForUser` | share 0, version 1 | share 1, version 2 |
| `Sharing.DeleteAllGuarded`, `GuardedDeleteForUser` | one row | none |
| `SqlRun.GuardedBegin`, `GuardedFinish`, `GuardedCancel` of the victim's queued run | `queued` | `running`; `failed`; cancel flag 1 |
| `SqlRun.GuardedReserve` for the victim, `GuardedSweep`, `GuardedForgetUser` | the victim's ended run | removed |
| `Pref.ForgedSetValue`, `SqlRun.ForgedCancel`, and an administrator's `Pref.ForgedSetValue`: a row held with its `UserName` set to another user | stored owner the holder | stored owner the other user |

### Task 0 and red-before for DW-2666

Run 2026-11-16 on `ocupilot-ci` against the product before any change to the reserve sweeps (`OcuPilot.Test.ReserveSweepWrite`, run 3; raw output `21-33/impl3/dw2666-red.txt`): 7 of 11 tests red, the four control tests green.

| Leg (developer's reserve) | Before | After |
|----------|--------|-------|
| `Turn`, limits class naming no retention | another user's turn that ended a moment ago, with its proposal | both deleted |
| `Turn`, holding that turn with `EndedAt` back-dated, product limits class | the turn | deleted, its stored end time unchanged |
| `SqlRun`, limits class naming no retention | a run that ended 5 seconds ago | deleted |
| `SqlRun`, holding that run with `EndedAt` back-dated | the run | deleted |
| `SqlRun`, limits class naming no queued limit | a run queued 3 seconds ago | `failed` |
| `SqlRun`, holding a lost run with `Namespace` edited | stored namespace | the held edit stored |
| `Turn.GuardedAbandonForUser` holding the victim's turn with its key set to a bystander's | no signal | abandon signal on the bystander's turn, none on the victim's |

### Batch 3 and DW-2666 (post-fix)

Run 2026-11-16 on `ocupilot-ci`, one class per call, after `reload.sh` (`LOADERRORS=0`). Run ids are the instance's `%UnitTest` indexes of the last run of each class after the last product edit.

| Class | Tests | Result | Run |
|-------|-------|--------|-----|
| PrefOwnerWrite | 6 | pass | 89 |
| ReserveSweepWrite | 11 | pass | 86 |
| StoreOwnerWrite | 14 | pass | 87 |
| AdminStateWrite | 7 | pass | 88 |
| TranscriptOwnerWrite | 9 | pass | 17 |
| AdminPathWrite | 5 | pass | 18 |
| PrefState | 17 | pass | 7 |
| PreferencesWire | 12 | pass | 8 |
| AgentPick | 5 | pass | 9 |
| AgentPickTurn | 3 | pass | 10 |
| SqlRunStore | 14 | pass | 11 |
| SqlBackgroundJob | 12 | pass | 12 |
| SqlBackgroundRoutes | 9 | pass | 13 |
| ContextBound | 15 | pass | 14 |
| Retention | 10 | pass | 16 |
| DeveloperFloorTurn | 1 | pass | 19 |
| TurnWire | 15 | pass | 20 |
| TurnProviderFault | 6 | pass | 21 |
| ExplorerSaveTurn | 1 | pass | 22 |
| LedgerWire | 6 | pass | 23 |
| TurnConversation | 11 | pass | 24 |
| TurnStore | 11 | pass | 25 |
| TurnNavigate | 15 | pass | 26 |
| TurnHourLimit | 9 | pass | 27 |
| TurnLoop | 11 | pass | 28 |
| TurnStream | 7 | pass | 29 |
| TurnContext | 16 | pass | 30 |
| State | 12 | pass | 37 |
| AnalyticsMdxJob | 13 | pass | 38 |
| AnalyticsMdxRoutes | 9 | pass | 39 |
| TurnSanitize | 2 | pass | 40 |
| TurnGrounding | 13 | pass | 41 |
| SqlAgentRead | 7 | pass | 42 |
| SqlConsoleWrite | 6 | pass | 43 |
| Installer | 27 | pass | 81 |
| AgentState | 13 | pass | 82 |
| Ledger | 11 | pass | 83 |
| ProposalConfirm | 24 | pass | 84 |

`SqlBackgroundDelayed`, `SqlBackgroundUnindexed` and `SqlBackgroundUnspawned` are job helpers: the runner reports them as ran 0 test methods. `uv run scripts/check-objectscript.py` 0 problems; `uv run scripts/test_check_objectscript.py` 159 tests OK; `node --test tools/ci.test.mjs` 103 pass; `node --test tools/ci-shards.test.mjs` 33 pass.

mutation: `OwnerWriteRefused` answers `$$$OK` first -> `PrefOwnerWrite.TestADeveloperIsRefusedAVictimsSettings` red alone, `ReserveSweepWrite` green (runs 44, 45); reverted, `Base.cls` byte-identical (md5 `2cdc5318...`), reloaded.
mutation: `OwnerChangeRefused` skips the stored-versus-held owner comparison -> `PrefOwnerWrite.TestAForgedOwnerIsRefusedAndTheStoredOwnerStands` red alone (run 46); reverted, byte-identical, reloaded.
mutation: `CallerOwns` answers 0 always -> `PrefOwnerWrite.TestADeveloperWritesItsOwnSettings` and `TestTheOpenSweepStillWorks` red (run 49), and seven `ReserveSweepWrite` run tests, each an owner path the mutation refuses; reverted, byte-identical, reloaded.
mutation: the administrator bypass removed from `OwnerWriteRefused` -> five `PrefOwnerWrite` tests red, the suite's own `%All` seeding mint being an administrator's write (run 50); reverted, byte-identical, reloaded.
mutation: `Parameter OWNERWRITE` emptied on `Sharing` -> `TestTheOwnerStoresAreDeclared`, `TestADeveloperIsRefusedAVictimsSettings` and `TestAForgedOwnerIsRefusedAndTheStoredOwnerStands` red (run 51); reverted, `Sharing.cls` byte-identical (md5 `6d3f02e9...`), reloaded.
mutation: `SqlRun.GuardedReserve` calls the public `GuardedSweep` -> `PrefOwnerWrite.TestTheOpenSweepStillWorks` and `ReserveSweepWrite.TestARunReserveStillSweepsAnotherUsersExpiredRun` red, each alone in its class (runs 52, 53); reverted, `SqlRun.cls` byte-identical (md5 `feef1665...`), reloaded.
mutation: the administrator gate removed from `Pref.DeleteAllGuarded` -> `TestADeveloperIsRefusedAVictimsSettings` red on that leg alone (run 63); the same from `SqlRun.GuardedForgetUser` -> red on that leg alone (run 64); `Pref.GuardedClear`'s owner check removed -> red on that leg alone (run 65); `Pref.GuardedAdd`'s owner check removed -> red on that leg alone (run 80); each reverted, byte-identical, reloaded.
mutation: `Turn.SweepAnyCaller` uses the limits class a non-administrator passes -> `ReserveSweepWrite.TestAReserveWithNoRetentionLimitKeepsAnotherUsersEndedTurn` red alone (run 66); reverted, `Turn.cls` byte-identical (md5 `96a080b4...`), reloaded.
mutation: `SqlRun.SweepAnyCaller` uses the passed limits class -> `TestARunReserveWithNoRetentionLimitKeepsAnotherUsersEndedRun` and `TestARunReserveWithNoQueuedLimitKeepsAnotherUsersQueuedRun` red (run 67); `SqlRun.GuardedReserve` uses it for its own reconcile -> the queued-limit test red alone (run 68); each reverted, byte-identical, reloaded.
mutation: `Turn.SweepAnyCaller` reads each end time from the opened row -> `TestAReserveHoldingAnotherUsersTurnKeepsIt` red alone (run 69); `SqlRun.SweepAnyCaller` the same -> `TestARunReserveHoldingAnotherUsersRunKeepsIt` red alone (run 70); each reverted, byte-identical, reloaded.
mutation: `Turn.GuardedReserve` makes no sweep -> `TestAReserveStillSweepsAnotherUsersExpiredTurn` red alone (run 71); `SqlRun.GuardedReserve` makes none -> `TestARunReserveStillSweepsAnotherUsersExpiredRun` and `PrefOwnerWrite.TestTheOpenSweepStillWorks` red (runs 72, 73); `Turn.DeleteExpired` leaves the turn's children -> the proposal assertion of the turn sweep test red alone (run 78); each reverted, byte-identical, reloaded.
mutation: `SqlRun.Reconcile` saves the opened row instead of updating by SQL -> `TestARunReserveStoresNoEditFromAHeldLostRun` red alone (run 74); `Reconcile` suspects only a queued row -> `TestARunReserveStillEndsAnotherUsersLostRuns` and the held-edit test red (run 79); each reverted, byte-identical, reloaded.
mutation: `Base.InstanceLimitsClass` ignores the administrator -> `TestAnAdministratorsSweepKeepsTheLimitsClassItIsGiven` (now a one-day class that keeps rows past the instance's retention) red alone (code review, run 122); reverted, `Base.cls` byte-identical (md5 `2cdc5318...`), reloaded.
mutation: `Turn.GuardedAbandonForUser` reads each key from the opened row -> `TestAnAbandonIgnoresAHeldKey` red alone (run 77); reverted, `Turn.cls` byte-identical, reloaded.

mutation: the owner check removed from the top of `Sharing.GuardedSetForUser` -> `PrefOwnerWrite` stays green (run 95), because `GuardedSaveOwned` makes the same check before it saves; the writer's own line is the earlier refusal, as in Batches 1 and 2 (code review); reverted, `Sharing.cls` byte-identical (md5 `6d3f02e9...`), reloaded.
mutation: the administrator gate removed from `Pref.GuardedDeleteForUser`, `Sharing.GuardedDeleteForUser` and `SqlRun.GuardedSweep` -> `PrefOwnerWrite.TestADeveloperIsRefusedAVictimsSettings` red alone, on each of the three legs (the 822 and the unchanged-rows assertions; code review, run 96); reverted, `Pref.cls`, `Sharing.cls` and `SqlRun.cls` byte-identical (md5 `03d9264c...`, `6d3f02e9...`, `feef1665...`), reloaded.

Code review (2026-11-16, `ocupilot-ci`, real developer principal; `ReserveSweepWrite` 16 tests run 124, `PrefOwnerWrite` 6 run 129, `TranscriptOwnerWrite` 9 run 107, `StoreOwnerWrite` 14 run 108, `SqlRunStore` 109, `SqlBackgroundJob` 110, `SqlBackgroundRoutes` 111, `AnalyticsMdxJob` 112, `AnalyticsMdxRoutes` 113, `Retention` 114, all green). Each mutation below was applied alone, observed red, reverted byte-identical and reloaded:

mutation: `Turn.DeleteExpired`'s delete drops its state and end-time conditions -> `ReserveSweepWrite.TestATurnSweepDeletesOnlyATurnStillExpiredAsRead` red alone (run 115).
mutation: `SqlRun.SweepAnyCaller`'s delete drops them -> `TestARunSweepDeletesOnlyARunStillExpiredAsRead` red alone (run 116).
mutation: `Turn.DeleteExpired` deletes with no transaction -> `TestATurnSweepThatFailsLeavesTheTurnWhole` red alone (run 118); with `TROLLBACK` alone removed, the same test red alone (run 119). Green on the product: a rollback outside the escalated frame restores the turn row.
mutation: `SqlRun.GuardedFinish`'s refusal returns without the unlock -> `TestARefusedRunFinishReleasesTheRunLock` red alone (run 120).
mutation: `SqlRun.GuardedViewForOwner` reconciles for any caller (the pass 3 code) -> `TestAViewOfAnotherUsersRunEndsNothing` red alone (run 121).
mutation: `SqlRun.GuardedBegin`'s key-owner check removed -> `PrefOwnerWrite.TestADeveloperIsRefusedAVictimsSettings` red on its begin-under-own-name leg alone (run 123).
mutation: the owner check removed from `Pref.GuardedRemove` and `Pref.GuardedTrim` -> that test red on those two legs alone (run 126); `Sharing.DeleteAllGuarded`'s administrator gate removed -> red on that leg alone (run 127); `SqlRun.GuardedReserve`'s owner check removed -> red on that leg alone (run 128).

## Auto Run Result

Status: done
Blocking condition: none

**Pass 3 (Batch 3, DW-2666).** Task 0 reproduced on the unchanged product: a developer added, removed, cleared, touched, set, trimmed and deleted another user's preferences, set another user's sharing choice, and began, finished, canceled and swept another user's runs; held copies of its own rows with another owner stored that owner. Before and after are under "Task 0 (batch 3, pre-fix)". DW-2666 is red-before, green-after in the new `ReserveSweepWrite`, 7 of 11 red on the unchanged sweeps.

- Summary: `Pref`, `Sharing` and `SqlRun` are owner stores. Every public writer checks the caller before it escalates; `DeleteAllGuarded`, `GuardedDeleteForUser`, `SqlRun.GuardedSweep` and `GuardedForgetUser` serve an administrator only. `SqlRun.GuardedReserve` sweeps through a private any-caller form. `Base` gained `GuardedSaveOwnedPlain` (the owner checks, then the unconditional save, for `Pref`'s two create paths), `InstanceLimitsClass` and `GuardedRowsWhere`, all private.
- DW-2666: for a caller who does not hold `OcuPilotAdmin`, the turn and run reserve sweeps and the run reconcile read the limits class the instance names (`OcuPilot.Kernel.InstanceLimits.ForTurns`/`ForRuns`, which answer `Loop.LimitsClass()` and `BackgroundRun.LimitsClass()`), never the one passed; an administrator's call keeps the class it is given. Each sweep reads state and end time by SQL, and its delete repeats both.
- Decided in-stage: `scripts/check-objectscript.py`'s re-entry rule refuses the name `OcuPilot.Kernel.Agent` under `Kernel/State`, which `Loop` carries, so the two class names live in the new `OcuPilot.Kernel.InstanceLimits` and `Kernel/State` names that class; the checker is untouched. A refused `SqlRun.GuardedFinish` still releases the run lock, as every earlier path did.
- Helpers examined for a caller-controlled limit or a held object that decides what is written to another user's row:
  - `Turn.SweepAnyCaller`: changed (above).
  - `SqlRun.GuardedReserve`'s sweep and `SqlRun.Reconcile`: changed. Reconcile read the caller's queued limit and saved the opened row; it now reads the instance's limit for a non-administrator and ends the run by one conditional `UPDATE` of state, end time and version.
  - `SqlRun.GuardedViewForOwner`: its reconcile takes the instance's limit for a non-administrator, and (code review) runs only for the run's owner or an administrator.
  - `Turn.GuardedAbandonForUser`: changed behavior-neutrally. It took each turn key from the opened row, which a caller may hold; it now reads the key by SQL. Its ids, signal and count are as before.
  - `Turn.ReconcileHeld`: unchanged. It is reached only through `GuardedReserve` and `GuardedReconcile`, both owner-checked, and writes only the caller's own rows by SQL-selected ids.
  - `Propose.ExpireStaleAnyCaller`: unchanged. It compares each row's stored `ExpiresAt` with the clock by one `UPDATE` and reads no limit and no object.
  - `Agent.GuardedClearVerification` and `RebalanceDefaultSql`: unchanged. Both are SQL-only and take no value from a row object.
  - `Propose.GuardedClaimAndClose`'s cancel of its own target's siblings: unchanged (Batch 1).
- The five non-owner product paths are unchanged in effect: `TestTheOpenPathsStillWork` in `StoreOwnerWrite` and `TranscriptOwnerWrite` pass, and `PrefOwnerWrite.TestTheOpenSweepStillWorks` pins the run reserve's sweep.
- Residual: none open; code review pinned the sweep deletes' repeat, the rollback and the refused finish's unlock. `TurnLoop` and the other turn classes in the net are green.
- Files: `src/OcuPilot/Kernel/State/Base.cls`, `Turn.cls`, `Pref.cls`, `Sharing.cls`, `SqlRun.cls`; `src/OcuPilot/Kernel/InstanceLimits.cls` (new); `src/OcuPilot/Test/PrefOwnerWrite.cls`, `ReserveSweepWrite.cls` and `PrefStateWriteProbe.cls` (new), `StoreOwnerWrite.cls`; `scripts/ci-throwaway.sh`.
- Verification: reload `LOADERRORS=0`; every Batch 3 and net class in the table above green; mutations under `## Verification`; `check-objectscript` 0 problems, its harness 159 tests OK, `ci.test.mjs` 103 pass.
- Review: 13 findings - 1 patched (low: three mutation lines), 0 deferred, 12 rejected with reasons in the triage log. The turn sweep's turn-first delete order inside a transaction is the only change of shape to an open path; its end state is as before. Follow-up review recommended: false (no high or medium patched).
- Verification after review: reload `LOADERRORS=0`; `ReserveSweepWrite` 11 (run 90), `PrefOwnerWrite` 6 (91), `StoreOwnerWrite` 14 (92), `TranscriptOwnerWrite` 9 (93), `AdminPathWrite` 5 (94) green on a fresh `ocupilot-ci`; `check-objectscript` 0 problems, its harness 159 tests OK, `ci.test.mjs` 103 pass, `lint-docs` 0 problems.
