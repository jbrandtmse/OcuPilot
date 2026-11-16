---
title: "Story 21.33: OcuPilot's other guarded stores refuse a caller who may not write them"
type: 'bugfix'
created: '2026-11-16'
status: 'in-progress'
baseline_revision: '49e9b7e439afe8f1eba1404c7964495291f69c38'
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
  - summary: >-
      A developer can append ledger rows under its own name onto another user's turn key (Ledger.GuardedAppend and GuardedCountOverflow check pUser against the caller, not the turn's owner), consuming that turn's per-turn row cap and creating a developer-owned overflow row that blocks the victim's own overflow count.
    evidence: |-
      Found at review (verification-gap, inference): both writers count and number rows by TurnKey with no owner filter, and the batch 1 gate checks only the user argument. Pre-existing and outside DW-2638's rewrite-another-user's-row scope; the fix needs the turn's stored owner read through TurnKeyIdx, which Batch 2 makes available once Turn is an owner store. Recipe: GuardedAppend(victimTurnKey, caller, ...) as a non-administrator, then read the victim turn's row count.
    location: >-
      src/OcuPilot/Kernel/State/Ledger.cls (GuardedAppend, GuardedCountOverflow)
    severity: medium
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

This dispatch covers Task 0 and Batch 1 only (the `Base` mechanism, Agent, Propose, Ledger). Batches 2 and 3 are a later pass: write nothing for them, add no `OWNERWRITE` to Turn, Convo, Step, Nav, Entry, Pref, Sharing or SqlRun, and leave `TranscriptOwnerWrite` and `PrefOwnerWrite` unwritten. Task 0 covers the agent definition, one proposal (lead leg: an administrator's live proposal edited by the developer, then confirmed by the administrator, which runs the edited arguments) and one ledger row; its turn, conversation and preference legs belong to the later pass. Finalize with `status: in-progress`. The orchestrator's condition: the five non-owner product paths in Design Notes keep their behavior exactly, each shown by a test that still passes; an edit that would change one stops the run as `blocked`.

Batch 1 carve-out: `Turn.GuardedDelete` (reached by every user's turn reserve sweep) calls `Propose.GuardedDeleteForTurn`, and batch 1 does not touch `Turn`. So in this pass `Propose.GuardedDeleteForTurn` stays open and unchanged, and batch 2 gates it together with the private reserve cascade. `Ledger.GuardedDeleteForTurn` has no product caller and is gated now. Any other Batch 1 gate that would break one of the five paths through an untouched class stays open the same way, listed here; if none can, the run stops `blocked`.

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

**Acceptance Criteria:**

- Given the unfixed tree on `ocupilot-ci`, when Task 0 runs, then the developer's writes of an agent definition and of the victim's proposal, ledger, turn, conversation and preference rows land, and the read-backs are recorded.
- Given each batch, when its owner test class runs, then every refusal row answers 822 with the rows unchanged. The owner, administrator, credential-finding and open-sweep rows store, and the roster test is green.
- Given each batch, when the existing real-principal turn suites run (`DeveloperFloorTurn`, `TurnWire`, `TurnProviderFault`, `ExplorerSaveTurn`, `LedgerWire`, `TurnConversation`), then they stay green. This is the turn's own writes as a non-administrator.
- Given `OwnerWriteRefused` mutated to answer `$$$OK`, when the owner test classes run, then only their refusal tests go red.

### Review Findings

Code review, Batch 1 (2026-11-16, HEAD `be4f8d61f`, full-opus tier: blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor).

- [ ] [Review][Decision] A confirm's claim cancels other users' live proposals, and AD-9's list of open writes leaves that out (high). Measured on `ocupilot-ci` as a `%Development` principal. Minting its own proposal on a victim's target and claiming it left the victim's proposal `canceled`/`sibling`. The code follows AD-34, so the gap is the AD text: add "a confirm's claim canceling every user's live proposals on its own proposal's target (AD-34)" to the open writes, or rule otherwise. DW-2662, for the orchestrator.
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

- `(loop)` `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/4667058b-f052-49c9-b08a-221f7f41dfab/scratchpad/e21u/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` -- expected: `LOADERRORS=0`.
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
mutation: an administrator gate added to `Propose.GuardedDeleteForTurn` -> `TestTheOpenPathsStillWork` red alone, the turn reserve's sweep (code review, run 96); reverted, `Propose.cls` byte-identical, reloaded.

**Code review re-run** (2026-11-16, after the review patches, `ocupilot-ci`, one class per call, `LOADERRORS=0`): StoreOwnerWrite 14 (run 97), AdminStateWrite 7 (98), AgentState 13 (99), AgentWire 18 (77), AgentCredential 17 (79), ProposalConfirm 24 (80), ProposalRace 6 (81), ProposalWire 17 (82), DeveloperFloorTurn 1 (83), LedgerWire 6 (84), Ledger 11 (85), State 12 (86), ProposalClose 7 (87), Installer 27 (88), all green; `check-objectscript` 0 problems, its harness OK, `ci.test.mjs` 103 pass.

**DW-2664** (2026-11-16, fresh `ocupilot-ci`, `LOADERRORS=0`): new `AdminPathWrite` (3 tests, probe `AdminPathProbe`) green (runs 1, 5); StoreOwnerWrite 14 (run 9), AdminStateWrite 7 (10), Retention 10 (11), Ledger 11 (12), Installer 27 (13), PortGate 4 (14), ProposalTargetKey 7 (15), all green; `check-objectscript` 0 problems, its harness OK, `ci.test.mjs` 103 pass.
mutation: `GuardedRebuildTargetKeys` checks the administrator before it reads (Batch 1's order) -> `TestAFirstInstallWithoutAllPassesTheTargetKeyStep` red alone (run 2); reverted, `Propose.cls` byte-identical (md5 `1b6c8967...`), reloaded.
mutation: `Ledger.GuardedPurgeBefore` also requires `%All` -> `TestAnAdministratorWithoutAllKeysProposalsAndPurgesTheLedger` red alone (run 3); reverted, `Ledger.cls` byte-identical (md5 `a0519a84...`), reloaded.
mutation: `Ledger.GuardedPurgeBefore` refuses every caller -> `TestTheRetentionTaskPurgesTheLedgerAsItsOwnUser` and the administrator test red (run 4); reverted, byte-identical, reloaded.
mutation: `GuardedRebuildTargetKeys` drops its administrator check -> `StoreOwnerWrite.TestADeveloperIsRefusedAVictimsLedgerAndProposalRows` red alone, the rebuild leg (run 8); reverted, `Propose.cls` byte-identical, reloaded.

## Auto Run Result

Status: in-progress
Blocking condition: none (batches 2 and 3 remain)

**Task 0.** Reproduced on the unchanged product, `ocupilot-ci`, as a real `%Development` principal with no `OcuPilotAdmin`: the developer rewrote an administrator's live proposal through `Base.GuardedSave` and `GuardedSaveIfCurrent`, and the administrator's confirm then sent the edited arguments (Description `EVIL`). The agent definition was rewritten, created, deleted, marked and set default; a victim's proposal and ledger row were minted, closed, finalized and deleted. Before and after are under "Task 0 (pre-fix)". The turn, conversation and preference legs are Batches 2 and 3.

**Batch 1 done; Batches 2 and 3 open.**

- Summary: `Base` gains `OWNERWRITE`, `OWNERPARENT`, `OWNERPARENTINDEX`, `CallerOwns`, `OwnerWriteRefused`, and private `GuardedSaveOwned` and key and stored-owner helpers; the public saves serve an administrator only for an owner store. Agent is administrator-owned with `GuardedClearVerification` open by one `UPDATE` plus a SQL-only rebalance. Propose and Ledger are owner stores; cross-user deletes, purge, rebuild and the all-users expiry serve an administrator; the close writers expire lapsed proposals through a private any-caller expiry. `Propose.GuardedDeleteForTurn` stays open until Batch 2 (Pass Scope carve-out).
- Files: `src/OcuPilot/Kernel/State/Base.cls`, `Agent.cls`, `Propose.cls`, `Ledger.cls`; `src/OcuPilot/Test/AdminStateWrite.cls`, `AdminStateWriteProbe.cls`, `OwnerStateWriteProbe.cls` (new), `StoreOwnerWrite.cls` (new, 13 tests); `scripts/ci-throwaway.sh` (roster union).
- The five non-owner product paths are unchanged; `TestTheOpenPathsStillWork` runs all five as the developer principal and also passes on the unfixed tree.
- Review: 12 findings - 5 patched (tests and mutation lines only, none changed product code), 1 deferred (ledger rows onto another user's turn key), 6 rejected with reasons in the triage log. Patched by verdict: medium 3, low 2. Follow-up review recommended: false (the patches added tests and mutation runs, and the product diff did not change after review).
- Verification: reload `LOADERRORS=0`; every Batch 1 class in the Verification table green (final runs), re-run by the lead after the patches: StoreOwnerWrite 13 (run 65), AdminStateWrite 7, DeveloperFloorTurn 1, TurnWire 15, AgentCredential 17, Retention 10, ProposalConfirm 24; `check-objectscript` 0 problems; `ci.test.mjs` 103 pass; `lint-docs` 0 issues. Mutations: see `## Verification`; the fifth (public sweep in the turn reserve) belongs to Batch 2.
- Residual risks: the confirm leg of Task 0 runs under the suite's own identity because confirm needs the proposal's owner; `RefreshMark`'s version copy is pinned by `AgentCredential` only; `StoreOwnerWrite.cls` is 914 lines against the 500-line guideline.
