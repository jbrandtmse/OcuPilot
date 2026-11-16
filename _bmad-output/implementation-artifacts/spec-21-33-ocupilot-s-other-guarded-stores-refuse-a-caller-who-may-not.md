---
title: "Story 21.33: OcuPilot's other guarded stores refuse a caller who may not write them"
type: 'bugfix'
created: '2026-11-16'
status: 'ready-for-dev'
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

**Acceptance Criteria:**

- Given the unfixed tree on `ocupilot-ci`, when Task 0 runs, then the developer's writes of an agent definition and of the victim's proposal, ledger, turn, conversation and preference rows land, and the read-backs are recorded.
- Given each batch, when its owner test class runs, then every refusal row answers 822 with the rows unchanged. The owner, administrator, credential-finding and open-sweep rows store, and the roster test is green.
- Given each batch, when the existing real-principal turn suites run (`DeveloperFloorTurn`, `TurnWire`, `TurnProviderFault`, `ExplorerSaveTurn`, `LedgerWire`, `TurnConversation`), then they stay green. This is the turn's own writes as a non-administrator.
- Given `OwnerWriteRefused` mutated to answer `$$$OK`, when the owner test classes run, then only their refusal tests go red.

## Spec Change Log

## Review Triage Log

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

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
