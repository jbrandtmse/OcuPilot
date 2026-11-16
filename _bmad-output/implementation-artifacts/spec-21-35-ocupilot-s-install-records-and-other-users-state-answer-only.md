---
title: "Story 21.35: OcuPilot's install records and other users' state answer only to their callers"
type: 'bugfix'
created: '2026-11-16'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-21-33-ocupilot-s-other-guarded-stores-refuse-a-caller-who-may-not.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The install-owned stores (`WebApp`, `Stamp`, `Version`, `Demo`) and the screen-access store (`Access`) still take any caller's public guarded write (DW-2651). `WebApp`'s provenance row is what `Installer.Uninstall` deletes an application on the strength of, so a forged row steers an administrator's uninstall. `Base`'s public reads and the per-user stores' own reads let a `%Development` holder read another user's turns, conversations, proposals and ledger rows (DW-2652).

**Approach:** First reproduce each write and read end to end as a real non-administrator principal. Then the install-owned stores join 21.30's `ADMINWRITE` gate, and the install reaches them through the `New $ROLES` frame 21.33 Batch 2 adds for the target-key step, widened to the install's record steps. `Access` refuses a caller its port would refuse. The `OWNERWRITE` stores answer a read only to the row's owner or an administrator. Three batches, highest risk first.

## Boundaries & Constraints

**Always:**

- **Precondition.** Story 21.33 is `done` (Batches 2 and 3 landed), so every per-user store declares `OWNERWRITE` or `OWNERPARENT`, and `Installer` holds the DW-2665 frame. If either is missing at dispatch, HALT `blocked`: `21.33 not done`.
- A refused call changes nothing and returns `$$$ERROR($$$AccessDenied)` (vendor `ERROR #822`). The story adds no user-facing string.
- The predicates are 21.30's and 21.33's: `Base.CallerIsAdministrator`, `CallerOwns`, `OwnerWriteRefused` and `KeyOwnerRefused`, evaluated in the caller's process before any escalation (AD-8). Reads reuse them; no second owner predicate is written.
- Every product path in the Code Map's inventory keeps its behavior and its HTTP answer: the install, upgrade, uninstall and start path, the demo fixture, the smoke, the retention task, the screen-access port, the turn and context paths, confirm, cancel, draft, transcripts and the agent's tools.
- `New $ROLES` stays in `Base.cls` and one `Installer` method. AD-9's ordering rules hold: no `JOB` and no tool, port or route call inside a frame.

**Never:**

- Do not change a non-admin, non-owner product path. Each one is kept and listed under Design Notes, "Behavior changes for the orchestrator".
- Do not write a second escalation design. The installer's frame is 21.33 Batch 2's, made into one method.
- Do not edit the spine. The AD text is under Design Notes.
- Do not reference `..#ADMINWRITE` or `..#OWNERWRITE` inside an escalating `Base` method; read them with `$Parameter`.
- Run nothing on `ocupilot`, and add no second throwaway.

## I/O & Edge-Case Matrix

Each row runs in a child process logged in as a real principal (`AdminStateWrite.RunAs`). The developer holds `%Development:USE` and no `OcuPilotAdmin`; the installer holds the install privileges Task 0 measures, without `%All` and without `OcuPilotAdmin`. The victim owns rows the suite seeded.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Install records (B1) | Developer: `WebApp.GuardedRecord` naming another application, `GuardedMarkGatewayReported`, `DeleteByPath`; `Stamp.DeleteByProfile`, `GuardedSweep`; `Version.DeleteByProfile`; `Demo.DeleteByProfile`; `Base.GuardedSave` of a new or opened `Stamp`, `Version`, `Demo`, `WebApp` row | Each refused; rows unchanged; a probe uninstall afterwards deletes only what it recorded | 822 |
| Screen access (B1) | A principal with neither adjuster pair nor `OcuPilotAdmin`: `Access.GuardedPut`, `GuardedRemove`, `DeleteAllGuarded`. Developer: `GuardedPut` with an empty set, nine pairs, a malformed pair or a `pBy` that is not itself; `DeleteAllGuarded`; `Base.GuardedSave` of an `Access` row | Each refused; rows unchanged | 822 |
| Screen access port (B1) | Developer and security principal through `ScreenAccessPort.Invoke` (`ScreenAccessWire`, `ScreenAccessTurn`) | Stored and audited, as today | No error expected |
| Install as installer (B1, AC2) | Installer: `Install("probe")` (first), a keyless probe proposal seeded, `Install("probe")` again, `Uninstall("probe", 1)` | Each OK; version `installed`; provenance and stamp rows written; the proposal keyed; after uninstall the probe's rows and applications are gone | No error expected |
| Proposals and ledger (B2) | Developer: `Propose.GuardedByKey`, `GuardedByToken`, `GuardedRowVersion`, `GuardedRowsForTurn`/`ForConvo`/`CountForTurn` on a victim key or with `pUser` = victim; `Ledger.GuardedRow`, `GuardedIdsForWindow` (victim, and `pAllUsers` = 1), `GuardedDroppedFor`, `GuardedCountForTurn`; `Base.GuardedOpenId`, `GuardedExistsId`, `GuardedStoredValue` on a victim's proposal and ledger row | Each refused; no row value reaches the caller | 822 |
| Transcripts and settings (B3) | Developer: every public read of `Turn`, `Step`, `Nav`, `Convo`, `Entry`, `Pref`, `Sharing`, `SqlRun` on a victim key or user, `Convo.LoadOrCreate(victimKey)`'s load branch, the all-users reads except the open two | Each refused | 822 |
| Owner and administrator | Developer reads its own rows; an administrator without `%All` reads a victim's | Answered | No error expected |
| Open reads (B3) | Developer: `Turn.GuardedLiveUsers`, `Turn.GuardedIsTurnJob` | Answered, as today | No error expected |
| Route answers (B2, B3) | A non-owner, non-administrator confirms, cancels, drafts, claims by token and opens a transcript of a victim's row | The same status and code as today (NOTYOURS, UNKNOWN, 404) | Existing |

</intent-contract>

## Code Map

- `src/OcuPilot/Kernel/State/Base.cls` -- `CallerIsAdministrator:214`, `AdminWriteRefused:224`, `CallerOwns:233`, `OwnerWriteRefused:248`, `KeyOwnerRefused:268` (private), `PublicSaveRefused:281`, `GuardedSave:293`, `GuardedSaveIfCurrent:334`, private `GuardedSaveIfCurrentAnyCaller:350`. The public reads are `GuardedOpenId:571`, `GuardedExistsId:618` and `GuardedStoredValue:642`; `OwnerWriteRefused` and `KeyOwnerRefused` call `GuardedStoredValue` for the stored owner, so they need a private any-caller twin.
- `src/OcuPilot/Kernel/State/WebApp.cls` -- writers `GuardedRecord:127`, `GuardedMarkGatewayReported:144` (both through the public `GuardedSaveIfCurrent`), `DeleteByPath:156`. `Stamp.cls` -- `DeleteByProfile:107`, `GuardedSweep:125`. `Version.cls` -- `DeleteByProfile:78`. `Demo.cls` -- `DeleteByProfile:50`. Rows are also created through `Base.GuardedSave`.
- `src/OcuPilot/Kernel/State/Access.cls` -- `GuardedPut:73` (trusts `pBy`, validates nothing, saves through the public `GuardedSaveIfCurrent`), `GuardedRemove:103`, `DeleteAllGuarded:114` (no product caller).
- `src/OcuPilot/Port/ScreenAccessPort.cls` -- the one product writer of `Access` (`Invoke:246`, writes at 336 and 357). Its gate is `Gate.AdjusterSpec()`: `%Development:USE` or `%Admin_Secure:USE`, no `OcuPilotAdmin` (AD-64). `Apply:161` refuses a malformed pair, an undefined resource, a duplicate, more than `Api.AccessError.MAXPAIRS` (8) and an empty set. It audits at 387.
- `src/OcuPilot/Install/Installer.cls` -- `Install:904`: every `WebApp`, `Stamp` and `Version` write runs after `EnsureAdminRole` and `EnsureGrant` (`EnsureProposalTargetKeys:1818`, `RecordApplicationProvenance:1843`, `ReportGatewayGap` mark at 1890, `RecordStamp:4033`, `EnsureVersion` at 1193 and 1205). `MarkInstalling:1357` writes `Version` on the start path. `Uninstall:4394` deletes `Demo` rows through `RemoveDemoFixtures` (4539, before any role is removed) and, for the probe profile only, `WebApp`, `Stamp` and `Version` rows (4771, 4795, 4804). Production's rows go with its database. The probe profile's rows live in production's database, and its admin role is `OcuPilotAdminProbe`, so the frame always adds production's `OcuPilotAdmin` (`Base.#ADMINRESOURCE`).
- `src/OcuPilot/Install/Fixture.cls` -- `Create:192` saves `Demo` rows through `Base.GuardedSave` (start path and `Smoke.CheckAgentDelete`, both as `irisowner`, `%All`); `Remove:1001` is reached from `Uninstall`.
- `src/OcuPilot/Kernel/Retention.cls:69` -- `Stamp.GuardedSweep`, as the task's saving account (`irisowner` on the throwaway, measured in 21.33).
- **Per-user reads (DW-2652).** No public read of `Turn`, `Step`, `Nav`, `Convo`, `Entry`, `Propose`, `Ledger`, `Pref`, `Sharing` or `SqlRun` checks the caller, except `Convo.GuardedScreenRows:165`. They take a key, an id, a token or a `pUser`. Store-internal callers of the public `GuardedOpenId` are `Turn` 306, 472, 548, 563, 581, 697; `Step` 206; `Entry` 168; `Convo` 180; `Propose` 801, 832; `Ledger` 469 (and `GuardedExistsId` 470); `Pref` 178; `SqlRun` 261, 303, 355, 385, 411. `Propose` 551 calls `GuardedStoredValue`. Those that serve an open write (sweeps, reconcile, abandon, expiry, the claim's sibling cancel) move to a private any-caller open.
- **Product read callers.**
  - Own rows by `$Username`: `Api/Turn`, `Api/Context`, `Api/Preferences`, `Kernel/Shell/BackgroundRun`, `Install/Smoke`.
  - The turn job and the background job run as the row's user (`Job.cls:93`, `BackgroundRun.cls:268`). Its readers are `Loop`, `Dispatch`, `Mint`, `Screen/Tool/AnalyticsMdxRead:255` and `Area/Analytics/MdxQuery:291`.
  - Key from the route, owner checked upstream: `Api/Turn` 221/233/255, `Api/Conversation` 75/116/121, `Kernel/Proposal/Confirm` 410/588/595/885.
  - Administrator: `Kernel/Audit/Ledger.ViewForUser:619` and `GateTurns:781`, `Screen/Read:940` (`GuardedScreenRows`), `Kernel/Retention`.
  - Reads before an owner compare, which must keep their answer: `Confirm.cls:147` peek, `Draft.cls:73`, `Write.cls:136` (`GuardedByToken`) and `183` (`ClaimById`), `Api/Transcripts.cls:40` (`GuardedOwnerOf`) and 53 (`Entry.GuardedTurnKeys`, before `GateTurns`).
  - Open cross-user reads: `Screen/Tool/UserDelete:129` (`Turn.GuardedLiveUsers`, run as a `%Admin_Secure` holder) and `Kernel/Proposal/Prohibited:4440` (`Turn.GuardedIsTurnJob`, at mint and confirm).
- `src/OcuPilot/Test/AdminStateWrite.cls` -- `RunAs`, `EnsurePrincipals`, `RemovePrincipals`. `TestTheAdministratorStoresAreDeclared` pins the `ADMINWRITE` roster, which five stores join; `BaseSurface` pins `Base`'s public methods. `AdminPathWrite.cls` and `AdminPathProbe.cls` hold the installer principal (`%Admin_Secure:U`, `%DB_IRISSYS:RW`, the install namespace's databases). `OwnerStateWriteProbe.cls` opens victim rows with the public `GuardedOpenId` (104, 141, 148), so its legs fail at the open after Batch 2. `StoreOwnerWrite.cls` is 933 lines; add no test to it.
- **Contention.** `git log origin/OCU-1-epic24 ^origin/feature/OCU-1_ocupilot-mvp` is empty for every path above. `.worktrees/epic-24` has none of them modified. Feature carries 5 more lines in `scripts/ci-throwaway.sh` (Epic 24's rosters): add this story's classes as a union.

## Tasks & Acceptance

**Execution.** Task 0 runs first, on `ocupilot-ci`, with no product change. Each batch is independently verifiable and committable.

- **Task 0, the reproduction (DW-2651, DW-2652).** Write the batch test classes and probes below and run them on the unfixed tree. Record each leg's before and after under `## Verification` as "Task 0 (pre-fix)".
  - The developer writes a `WebApp` provenance row naming an application the probe install did not create. A probe `Uninstall` run by the suite then deletes that application.
  - It writes `Stamp`, `Version` and `Demo` rows, and an `Access` row through `GuardedPut` and through `Base.GuardedSave`.
  - It reads a victim's turn, conversation (entries included), proposal (arguments, payload) and ledger row through `Base.GuardedOpenId` and through the stores' key reads.
  - Measure the installer role: the smallest grant set without `%All` with which the installer principal completes `Install("probe")` and `Uninstall("probe", 1)` on the unfixed tree. Record it. If none completes, record the failing step and HALT `blocked`: `Task 0: no non-%All installer completes a probe install: <step>`.
  - If no write and no read lands, HALT `blocked`: `Task 0: attack did not reproduce: <evidence>`.
- **Batch 1 (DW-2651: uninstall steering, the install records, screen access).**
  - `Kernel/State/WebApp.cls`, `Stamp.cls`, `Version.cls`, `Demo.cls` -- `ADMINWRITE = 1`; every writer calls `AdminWriteRefused` first. Reads unchanged.
  - `Kernel/State/Access.cls`:
    - Add `Parameter WRITERPAIRS = "%Development:USE,%Admin_Secure:USE"`, the adjuster either-of.
    - `GuardedPut` and `GuardedRemove` refuse a caller who holds neither `OcuPilotAdmin:USE` nor any listed pair.
    - `GuardedPut` refuses a set that is empty, holds more than 8 pairs, or has a pair not shaped `resource:READ|WRITE|USE`. It refuses a `pBy` the caller does not own. It saves through the private any-caller conditional save.
    - Set `ADMINWRITE = 1`, so `Base`'s public saves serve an administrator only for `Access` with no change to `PublicSaveRefused`. `DeleteAllGuarded` calls `AdminWriteRefused`. `GuardedPut` and `GuardedRemove` check their own predicate instead; the `ADMINWRITE` roster lists them as the store's adjuster writes.
  - `Install/Installer.cls`:
    - Make 21.33 Batch 2's target-key frame one private method, `AsAdministrator(pStep, ...)`. It runs one step from a closed list inside `New $ROLES`, after adding `Base.#ADMINRESOURCE`'s role with `Set $ROLES`. When IRIS refuses the addition (`<PROTECT>`) or the role does not exist, the step runs unescalated and the store decides.
    - The steps: target keys, provenance, gateway marks, stamp, version (installed, failed, and `MarkInstalling`'s), demo removal (`RemoveDemoFixtures`) and the probe-only record deletes.
  - `scripts/check-objectscript.py` and its harness -- unchanged if 21.33 admits `Installer.cls` for `New $ROLES` and `Set $ROLES`. Otherwise add that admission with a harness case.
  - `src/OcuPilot/Test/InstallRecordWrite.cls` (new, armed `OCUPILOT_ALLOW_PRINCIPALS`) with `InstallRecordProbe.cls` (new, extends `OwnerStateWriteProbe`). Batch 1's refusal rows, the administrator rows, and the provenance-steering leg (refused after the fix). A roster test: the `ADMINWRITE` classes equal the declared set, each with a read, administrator-write and open split.
  - `src/OcuPilot/Test/InstallAsAdministrator.cls` (new, armed `OCUPILOT_ALLOW_PRINCIPALS` and `OCUPILOT_ALLOW_PRODUCTION_INSTALL`) -- AC2, the "Install as installer" row, through `AdminPathProbe` with two new kinds: probe install and probe uninstall. It primes production as `Test/Installer` does, and asserts the probe's rows and applications before and after.
  - `src/OcuPilot/Test/AdminStateWrite.cls` -- the `ADMINWRITE` roster gains the five stores.
  - `scripts/ci-throwaway.sh` -- the new armed classes, as a union.
- **Batch 2 (DW-2652: proposals, ledger, `Base`'s reads).**
  - `Base.cls`:
    - The public `GuardedOpenId`, `GuardedExistsId` and `GuardedStoredValue` refuse, for an `OWNERWRITE` class, a row whose stored owner the caller does not own, unless the caller is an administrator. The owner comes from `OwnerWriteRefused`, through `OWNERPARENT` where declared.
    - A refused open leaves `pObject` empty.
    - Add the private twins `GuardedOpenIdAnyCaller` and `GuardedStoredValueAnyCaller`. The gates and the open writes use them.
    - A row that does not exist answers as today.
  - `Propose.cls`, `Ledger.cls` -- key, token and id reads check the stored owner (`KeyOwnerRefused`, or the opened row's owner); `pUser` reads check `pUser`. `Ledger.GuardedIdsForWindow` with `pAllUsers` serves an administrator only. Store-internal opens that serve an open write use the twin.
  - `Kernel/Proposal/Confirm.cls`, `Draft.cls`, `Write.cls` -- map a read refused 822 to the answer a non-owner gets today. Confirm's peek: not peeked. Draft: `UNKNOWN` 404. `GuardedByToken` and `ClaimById`: `NOTYOURS`.
  - `src/OcuPilot/Test/OwnerStateRead.cls` (new, armed) with `OwnerStateReadProbe.cls` (new, extends `OwnerStateWriteProbe`). Batch 2's rows, owner and administrator reads, the route-answer row for confirm, cancel, draft and claim. A roster test: each owner store's public reads are split into owner reads, administrator reads and open reads, and every one is a step some test calls.
  - `OwnerStateWriteProbe.cls`, `StoreOwnerWrite.cls` -- legs that open a victim row now meet 822 at the open; keep each assertion's meaning (rows unchanged) and change only where it fails.
- **Batch 3 (DW-2652: transcripts and settings).**
  - `Turn`, `Step`, `Nav`, `Convo`, `Entry`, `Pref`, `Sharing`, `SqlRun` -- the same read gate. `Convo.LoadOrCreate`'s load branch checks the stored owner. `Convo.GuardedOwnerOf` serves the owner or an administrator. `Pref.GuardedUsers` and `Sharing.GuardedUsers` serve an administrator only. `Turn.GuardedLiveUsers` and `Turn.GuardedIsTurnJob` stay open. Sweep, reconcile, abandon and reserve paths use the twins.
  - `Api/Transcripts.cls` -- a refused `GuardedOwnerOf` or `GuardedTurnKeys` answers `NotFound`, as a non-administrator non-owner gets today.
  - `src/OcuPilot/Test/UserStateRead.cls` (new, armed) -- Batch 3's rows, the open reads, the transcript route answer.

**Acceptance Criteria:**

- Given the unfixed tree on `ocupilot-ci`, when Task 0 runs, then the developer's install-record, screen-access and victim-read legs land and are recorded, the steered probe uninstall deletes the foreign application, and the installer role is recorded.
- Given each batch, when its test class runs, then every refusal row answers 822 with the rows unchanged and no victim value returned, and the owner, administrator, open-read and route-answer rows hold.
- Given Batch 1, when `InstallAsAdministrator` runs, then a probe install, a probe upgrade over a keyless proposal and a probe uninstall complete as the installer principal (no `%All`, no `OcuPilotAdmin`) with their records written and removed.
- Given each batch, when the existing suites in its `(loop)` list run, then they stay green, including the installer, uninstall, retention, screen-access, turn, transcript and confirm suites.
- Given each check removed in turn (the five `ADMINWRITE` flags, `AsAdministrator`'s frame, `Access`'s caller and set checks, each read gate), when the owning test class runs, then its pinning test goes red.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs:**

- AD-9: escalation, 21.30's store gate and 21.33's owner gate and installer frame.
- AD-8: privilege checked in the caller's process.
- AD-17: one installer and its two entry points.
- AD-38: install completes before the first request, and the version row.
- AD-64: screen access, its one writer and the either-of gate.
- AD-46: the ledger, read by its owner or by an administrator through the per-row gate.
- AD-33: progress owned by the turn's user.
- AD-37: retention and deleted principals.
- AD-25: the demo fixture.
- AD-6 and AD-34: confirm and claim.

**Rule per store.**

- Install records are written by the install and by administrators (`ADMINWRITE`). The install writes them as an administrator through its frame.
- Screen access is written by the holders AD-64 names, in the shapes its port allows.
- Each user's state is read by that user or by an administrator. Two reads stay open by the instance's own rule.

**AD amendment for the spec gate.** Append to AD-9's Rule, after 21.33's paragraphs:

> **Install records answer to the install, screen access to its adjusters, and each user's state is read by that user** [AMENDED 2026-11-16, Story 21.35, owner answer U-90, DW-2651, DW-2652]. The install-owned stores (application provenance, install stamps, version rows and demo inventory) join the `ADMINWRITE` stores. The install writes them, and the target keys, through one private `Installer` method. That method adds the administrative role to its own process inside a `New $ROLES` frame around one step from a closed list. The admission rule and fallback are the target-key frame's: IRIS admits the addition only to a process that can write the system database, and a process that cannot add the role runs the step unescalated, where the store decides. The screen-access store refuses a caller who holds neither `OcuPilotAdmin:USE` nor AD-64's adjuster pair, and a set its port would refuse, with `ERROR #822`. It records the calling account as the changer, and `Base`'s public saves serve an administrator only for it. The `OWNERWRITE` stores refuse a read of a row whose owner is not the caller with `ERROR #822`, unless the caller holds `OcuPilotAdmin:USE`. That covers `Base`'s public reads and each store's key, token, id and user reads. A read across every user is an administrator's. Two reads stay open because a product path makes them for another user by the instance's own rule: the names of users with live turns, and whether a process is a turn job.

**Behavior changes for the orchestrator.** These non-admin, non-owner product paths are kept unchanged; each is a proposal only.

1. `ScreenAccessPort` admits a `%Development` or `%Admin_Secure` holder without `OcuPilotAdmin` (AD-64 item 4, owner decision 2026-10-08). The store cannot tell a call through the port from a direct one. So the AC's "a `%Development` holder's screen-access write is refused" holds for a set the port would refuse, a forged changer and a caller without either pair. A valid set that holder could store through the port, stored directly, lands without the port's `SecurityChange` audit. Options:
   - (a) Keep this.
   - (b) Recommended: the store records the audit itself, so a direct write is audited as the port's is (a stricter posture, veto window).
   - (c) Make `Access` administrator-only, which changes AD-64's either-of rule (owner-only).
2. `Screen/Tool/UserDelete.AfterWrite`, run by a `%Admin_Secure` holder, reads `Turn.GuardedLiveUsers`. That read stays open, so a developer can list the names of users with live turns.
3. `Prohibited` reads `Turn.GuardedIsTurnJob` at mint and confirm for any caller. It stays open: a yes or no for a process id.
4. Confirm, cancel, draft, claim-by-token and the transcript route keep their answers to a non-owner (NOTYOURS, UNKNOWN, 404). The store now refuses the read beneath them; the answer is unchanged.

**Decided in-stage:**

- The read refusal is 822, like the writes, and the four pre-compare callers map it to today's answer. A not-found answer for another user's row would turn today's NOTYOURS into UNKNOWN.
- `Access`'s set checks repeat only the shape, the count and the empty set. They do not repeat `Apply`'s resource-defined check. That check needs `%SYS` and AD-64 already has the port refuse it, and an undefined resource lowers nothing (inference).
- The frame adds production's role for a probe install too, because the probe's rows live in production's database and the store gate reads `OcuPilotAdmin`.
- `MarkInstalling` and `Fixture.Create` run as `irisowner` (`%All`), which the gate admits, as the retention task's purge showed in 21.33. `MarkInstalling`'s version write still goes through the frame, so a by-hand start is covered too.
- A first-install failure before `EnsureApplication` still writes no version row, as today. `EnsureAdminRole` runs before `EnsureApplication`, so whenever a row can be written the role exists.
- Extend, not copy:
  - The read gate reuses `OwnerWriteRefused` and `KeyOwnerRefused`.
  - The twins follow `GuardedSaveIfCurrentAnyCaller`.
  - The probes extend `OwnerStateWriteProbe` and `AdminPathProbe`.
  - The principals come from `AdminStateWrite.EnsurePrincipals`.
  - `Access.WRITERPAIRS` copies `Gate.AdjusterPairs()` because `Kernel/State` may not name `OcuPilot.Screen` (rule 7). `InstallRecordWrite` pins the two equal.
- The epic context cache is older than `epics.md`. Per the runner's rule it was reused, not recompiled; the 21.35 block was read from `epics.md` directly.

**Integration ACs.** The consumers are the installer, uninstall and start path, `ScreenAccessPort`, the turn job, confirm and draft, the routes, the ledger viewer and the retention task, each through its existing real-principal or wire suite and `InstallAsAdministrator`. `Consumes:` `Kernel/State/Base`, 21.33's frame. `Consumed-by:` Stories 24.6 and 24.7, whose consoles run code with the person's rights.

DW-2651 is addressed by Batch 1, and DW-2652 by Batches 2 and 3.

## Verification

**Shared surfaces:**

- The `ADMINWRITE` roster (`AdminStateWrite.TestTheAdministratorStoresAreDeclared`), which five stores join.
- `Base`'s public surface (`BaseSurface`), unchanged: the twins are private.
- `StoreOwnerWrite`'s owner-store split, whose read lists stay as they are; `OwnerStateRead`'s split of reads into owner, administrator and open is new.
- The `OCUPILOT_ALLOW_PRINCIPALS` and `OCUPILOT_ALLOW_PRODUCTION_INSTALL` rosters in `scripts/ci-throwaway.sh`, which `ui/tools/ci.test.mjs` checks.
- The non-owner behavior of every per-user read.

*Every test added or changed passes on a fresh environment, in either order.*

**Commands.** Run one command per foreground call with `timeout: 600000`, against `ocupilot-ci` only, and never put two test calls in one message.

- `(loop)` `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/4667058b-f052-49c9-b08a-221f7f41dfab/scratchpad/e21u/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` -- expected: `LOADERRORS=0`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<Class>`, one class per call -- expected: green after each batch (red legs at Task 0).
  - Batch 1: `InstallRecordWrite`, `InstallAsAdministrator`, `AdminStateWrite`, `AdminPathWrite`, `StoreOwnerWrite`, `State`, `Installer`, `InstallLock`, `InstallMark`, `Version`, `MigrateFault`, `Provenance`, `WebApp`, `GatewayGapIpmPath`, `UninstallGuard`, `UninstallResidue`, `UninstallSurvival`, `UninstallFault`, `Escalation`, `EscalationGap`, `IdentityInstall`, `SslReadInstall`, `ProposalTargetKey`, `RetentionTask`, `StampRetention`, `DemoOptIn`, `Demo`, `FixtureNamespace`, `FixtureFault`, `ProbeApps`, `ScreenAccessWire`, `ScreenAccessRefusals`, `ScreenAccessTurn`, `ScreenAccessGate`, `ScreenAccessAgent`.
  - Batch 2: `OwnerStateRead`, `StoreOwnerWrite`, `AdminStateWrite`, `State`, `ProposalConfirm`, `ProposalClose`, `ProposalRace`, `ProposalWire`, `ProposalCreate`, `Proposal`, `DraftExecute`, `Ledger`, `LedgerWire`, `LedgerSearch`, `LedgerPairs`, `LedgerEmptyPairs`, `LedgerSense`, `AuditEvent`, `TranscriptGate`, `Retention`, `AdminPathWrite`, `DeveloperFloorTurn`.
  - Batch 3: `UserStateRead`, `TranscriptOwnerWrite`, `PrefOwnerWrite`, `TranscriptsWire`, `TranscriptStore`, `TranscriptGate`, `ConversationRestore`, `Convo`, `TurnStore`, `TurnWire`, `TurnConversation`, `TurnNavigate`, `NavSettleJob`, `TurnLoop`, `TurnProviderFault`, `PrefState`, `PreferencesWire`, `AgentPick`, `AgentPickTurn`, `SqlRunStore`, `SqlBackgroundJob`, `SqlBackgroundRoutes`, `ContextBound`, `RemovalRowsSweep`, `ProcessControl`, `Retention`, `DeveloperFloorTurn`.
- `(loop)` `uv run scripts/check-objectscript.py`; `uv run scripts/test_check_objectscript.py`; `cd ui && node --test tools/ci.test.mjs`; `bash scripts/lint-docs.sh _bmad-output/implementation-artifacts/spec-21-35-ocupilot-s-install-records-and-other-users-state-answer-only.md` -- expected: 0 problems.
- `(once)`, the runner's: the full ObjectScript sweep, one class per call; `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS`; Rule 30's fresh check. No browser spec is touched, so the browser suite is left to CI.

**Mutations (Rule 19).** Apply each, observe red, revert, confirm `git status --short` and `git diff --stat` are unchanged, then reload. Record each as `mutation: <change> -> <test red>`.

- `WebApp` `ADMINWRITE` = 0 -> the provenance-steering leg and the roster test red.
- One `AdminWriteRefused` line removed from `Stamp`, `Version` or `Demo` -> that store's refusal leg red.
- `AsAdministrator` skips its role addition -> `InstallAsAdministrator`'s first install red at provenance.
- `Access` caller check answers `$$$OK` -> the no-pair leg red. The set check skipped -> the empty and nine-pair legs red.
- `GuardedOpenId`'s owner check removed -> `OwnerStateRead`'s `Base` leg red.
- `KeyOwnerRefused` dropped from `Propose.GuardedByKey` -> its leg red.
- `Ledger.GuardedIdsForWindow` serves `pAllUsers` to any caller -> its leg red.
- The confirm peek maps 822 to an error instead of "not peeked" -> the route-answer leg red.
- `Convo.LoadOrCreate`'s load branch unchecked -> its leg red.
- `Turn.GuardedLiveUsers` gated -> the open-read leg red.

**Runner ruling at the spec gate (2026-11-16):** validated. Implementation waits for Story 21.33 to be done. The AD-9 text above is written into the spine at that start, after 21.33's DW-2665 text it builds on, complying first under U7. The screen-access option (a), (b) or (c) is asked of the orchestrator; the plan's recommendation is (b).

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
