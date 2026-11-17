---
title: "Story 21.35: OcuPilot's install records and other users' state answer only to their callers"
type: 'bugfix'
created: '2026-11-16'
status: 'done'
baseline_revision: 'b4046f5046c97f780e11295c883bb5efc6f7cc20'
baseline_commit: '355d924387986fbd9206839113c11a4af450579c'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-21-33-ocupilot-s-other-guarded-stores-refuse-a-caller-who-may-not.md'
warnings: ['oversized']
deferred:
  - summary: >-
      The `demoRemove` step of `AsAdministrator` has no test leg that seeds a probe Demo row and uninstalls as the installer.
    evidence: |-
      `InstallAsAdministrator` never creates a probe Demo row, so a regression of the step would stay green. A seeded row and an uninstall as the installer would settle it.
    location: >-
      src/OcuPilot/Test/InstallAsAdministrator.cls
    severity: low
  - summary: >-
      `Base.GuardedProbeSet` is a public writer inherited by every store and is not guarded.
    evidence: |-
      It sets one probe global for any caller; `AdminStateWrite.BaseSurface` lists it with the reads and helpers. Pre-existing.
    location: >-
      src/OcuPilot/Kernel/State/Base.cls:723
    severity: low
  - summary: >-
      A caller-defined subclass of a guarded store with `ADMINWRITE` = 0 may pass `Base`'s guard, which reads the parameter from the object's class.
    evidence: |-
      Inferred from reading `GuardedSave`; pre-existing in every guarded store. A probe that compiles such a subclass as a `%Development` holder would settle it.
    location: >-
      src/OcuPilot/Kernel/State/Base.cls
    severity: medium (unverified)
  - summary: >-
      `Access.GuardedPut` does not check the screen name, duplicate pairs or the length of `pDeclared`.
    evidence: |-
      A direct adjuster can add rows for unregistered screens and shape the audit's before-set; the actor and the stored set stay true.
    location: >-
      src/OcuPilot/Kernel/State/Access.cls:117
    severity: low
  - summary: >-
      `Propose.GuardedCountForTurn` and `Ledger.GuardedCountForTurn` answer a count for a key that names no turn (or, for the ledger, no conversation) to any caller.
    evidence: |-
      Both refuse a key whose turn or conversation another user owns. A key naming no row passes the check and counts whatever rows carry it (orphans). Keys are 32 random hex characters, and no product caller asks for a key it does not own.
    location: >-
      src/OcuPilot/Kernel/State/Propose.cls:873
    severity: low
  - summary: >-
      `Base.GuardedProbeGet` reads any subscript of the probe global for any caller.
    evidence: |-
      No code outside `Test/` writes `^OcuPilotKernelStateProbe` (grep over `src/`), and `GuardedProbeSet` is an administrator's, so the read answers test values only. Pre-existing; it is `BaseSurface`'s open read.
    location: >-
      src/OcuPilot/Kernel/State/Base.cls:777
    severity: low
  - summary: >-
      A read of a step or entry row by a non-administrator now costs one more escalated read for its parent's owner (inference).
    evidence: |-
      `OwnerWriteRefused` reads the parent turn's or conversation's owner through the any-caller stored-value read, once per opened row. Unmeasured; a timed `Entry.GuardedRows` over a long conversation as the owner would settle it.
    location: >-
      src/OcuPilot/Kernel/State/Base.cls:253
    severity: low
  - summary: >-
      A held own row whose owner or key is edited in memory before a store's reserve, abandon or sweep is no longer covered by a test.
    evidence: |-
      The held-victim-row legs of `ReserveSweepWrite` now meet 822 at the open, which proves the attack unreachable. `StoreOwnerWrite` and `OwnerStateWriteProbe` still open a victim row first, so their held-row saves are refused at the open and no longer prove the save refuses a forged held row. A leg that holds the developer's own row and edits its owner would settle it.
    location: >-
      src/OcuPilot/Test/OwnerStateWriteProbe.cls
    severity: low
  - summary: >-
      `Api/Transcripts.HandleRead`'s mapping of a refused `Entry.GuardedTurnKeys` to its 404 has no test leg.
    evidence: |-
      The call follows a `GuardedOwnerOf` answer for the same key, which is the owner's or an administrator's, so only a race (the conversation changes owner between the two) reaches the refusal. The owner-lookup mapping is pinned by `UserStateRead`.
    location: >-
      src/OcuPilot/Api/Transcripts.cls
    severity: low
  - summary: >-
      A non-administrator's `Turn.GuardedSignals`, `Step.GuardedRows`, `Nav.GuardedPending` and `Entry.GuardedRows` each cost one more escalated read for the parent's owner (inference).
    evidence: |-
      `NamedOwnerRefused` reads the parent turn's or conversation's stored owner once per call; the loop polls `GuardedSignals` at every step boundary. Unmeasured; a timed turn as a developer-held principal against the parent would settle it.
    location: >-
      src/OcuPilot/Kernel/State/Turn.cls
    severity: low
  - summary: >-
      `Entry.GuardedTurnKeys` answers the turn keys of an orphaned conversation to any caller.
    evidence: |-
      Its key check passes for a key that names no conversation, and it reads by SQL with no per-row open. Keys only, no content; no product path leaves an entry whose conversation is gone (inference). A leg that deletes a conversation row and reads as the developer would settle it.
    location: >-
      src/OcuPilot/Kernel/State/Entry.cls
    severity: low
  - summary: >-
      `Convo.GuardedScreenRows`'s SQL scope and its per-row open are not pinned one at a time.
    evidence: |-
      Removing either alone leaves `TestTheTranscriptListIsScopedToTheCaller` green because each hides the other's rows; both together turn it red. A held-row probe that bypasses the SQL scope would pin the open alone.
    location: >-
      src/OcuPilot/Kernel/State/Convo.cls
    severity: low
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
  - **Batch 2 pass (runner, 2026-11-16).** Task 0 for Batch 2 runs first on `ocupilot-ci`: reproduce a developer's read of another user's proposal, ledger and other `OWNERWRITE` rows through `Base`'s public reads and each store's key, token, id and user reads, and record each under `## Verification` as "Task 0 (pre-fix), Batch 2".
    - Inventory every public reader and writer on `Propose`, `Ledger` and `Base`, including each one inherited from `Base`, and record the list. Check reads through a held object, `%OpenId` paths, SQL projections a developer can query directly, and any `Base` method that returns rows by key or id. Measure; do not infer.
    - Extend `AdminStateWrite.EnsurePrincipals` and `AdminPathWrite.EnsurePrincipals` (Rule 31) so `InstallRecordWrite` and `InstallAsAdministrator` stop copying them; where sharing is impossible, state the reason at each copy.
    - Confirm, cancel, draft, claim-by-token and the transcript route keep their answers to a non-owner (NOTYOURS, UNKNOWN, 404); the store refuses the read beneath them with 822 and each caller maps it. Pin each route answer. `Turn.GuardedLiveUsers` and `Turn.GuardedIsTurnJob` stay open. If an edit would change any other product path beyond this spec, stop and set `blocked`.
    - Register each new armed class in `scripts/ci-throwaway.sh` as an add-only edit. Do not start Batch 3.
  - **Batch 3 pass (runner, 2026-11-17).** Batch 2 is reviewed: its review added `Base.GuardedRowClass` (a read checks the stored row's own class), `GuardedStreamText` reading only the row's stored stream, and `StreamChangeRefused` in both guarded saves (a saved row may not name another row's stream). Batch 3 builds on them, and changes none of them without a reason recorded here.
    - Task 0 for Batch 3 runs first on `ocupilot-ci`: reproduce a developer's read of another user's `Turn`, `Step`, `Nav`, `Convo`, `Entry`, `Pref`, `Sharing` and `SqlRun` rows through each store's key, id, user and all-users reads and `Convo.LoadOrCreate`'s load branch, and record each under `## Verification` as "Task 0 (pre-fix), Batch 3".
    - Inventory every public reader on those eight stores from the compiled classes (`%Dictionary.CompiledMethod`, public, including what each inherits from `Base`) and record the list split into owner, administrator and open reads. A method that returns a value, an id list, a count, an existence answer or a held row is a reader. Check reads through a held object (the developer's own row edited in memory), stream properties (`Entry`, `SqlRun` and any other stream the stores keep: each read goes through `GuardedStreamText`), `%OpenId` and SQL as the developer. Measure; do not infer.
    - Product paths that read their own rows keep working: the turn job and the background job run as the row's user, `Api/Turn`, `Api/Context`, `Api/Preferences`, `Api/Conversation`, the retention task, the ledger viewer's administrator reads and `Screen/Read`'s `GuardedScreenRows`. Store-internal reads that serve an open write (sweeps, reconcile, abandon, reserve, expiry) use the twins.
    - `Turn.GuardedLiveUsers` and `Turn.GuardedIsTurnJob` stay open. `Api/Transcripts` answers `NotFound` for a refused `GuardedOwnerOf` or `GuardedTurnKeys`, as a non-administrator non-owner gets today; pin it. If an edit would change any other product path beyond this spec, stop and set `blocked`.
    - Register `UserStateRead` in `scripts/ci-throwaway.sh` as an add-only edit.
    - This is the last batch: finalize with `status: done`. The `## Auto Run Result` covers this pass only (the spec is `oversized`): Batch 1 and 2 are one line each, naming where they closed. The `(once)` sweep, smoke and fresh check are the runner's.
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

### Review Findings

Code review of Batch 1 (`1472e282d` against `6e62e114f`, HEAD `3e32ded2d`), 2026-11-16. Measured on `ocupilot-ci`.

- [x] [Review][Patch] HIGH: `Base.GuardedProbeSet` let a non-administrator write any subscript and any size into the protected database. It now refuses a caller without `OcuPilotAdmin:USE` with 822. Pinned by `InstallRecordWrite.TestOnlyAnAdministratorWritesTheProbeGlobal`. `State.TestEscalationIsWhatGrantsTheDeniedUserAccess` now proves the escalation through the guarded read [src/OcuPilot/Kernel/State/Base.cls]
- [x] [Review][Patch] HIGH (Rule 6), owner: runner (closed: spine `046388151`, Design Notes AD text). AD-9's 21.35 paragraph says the screen-access store refuses "a set its port would refuse". The store refuses an empty set, more than 8 pairs, a malformed pair and, since this pass, a duplicate pair. It does not refuse an undefined resource or a non-adjustable screen, as the Decided note intends. Narrow the AD sentence to "a set whose shape, size or emptiness, or a pair named twice, its port would refuse". In the same edit, update two stale spine sentences: AD-9's 21.33 paragraph (the frame is now `AsAdministrator`) and AD-64 item 4 (the store records `SecurityChange`). The Decided note's reason "that check needs `%SYS`" is wrong: `$System.Security.ResourceExists` runs in the caller's process. Adding the check could refuse a port write whose declared set names a resource another edition lacks (inference) [_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md]
- [x] [Review][Patch] MED (Rule 31), rework: closed in the Batch 2 pass. `AdminStateWrite.EnsurePrincipals` takes the databases' permission and a fifth `holdsAdjuster` case element, `AdminPathWrite.EnsurePrincipals` takes the cases, and the two new classes call them; `InstallAsAdministrator` keeps only its SQL grants, which name the install's own schemas [src/OcuPilot/Test/InstallRecordWrite.cls, src/OcuPilot/Test/InstallAsAdministrator.cls]
- [x] [Review][Patch] LOW, rework: the Auto Run Result's Residual ("can no longer write its `failed` version row") is wrong. Measured: the parent and this commit both write the row. Replace the sentence.
- [x] [Review][Patch] MED: the `demoRemove` step had no test. `InstallAsAdministrator` now seeds a probe demo row and asserts the installer's uninstall removes it [src/OcuPilot/Test/InstallAsAdministrator.cls]
- [x] [Review][Patch] MED: nothing pinned that a refused or stale screen-access write records no audit row. Pinned by the developer-actor zero-row assertions and the two stale legs [src/OcuPilot/Test/InstallRecordWrite.cls]
- [x] [Review][Patch] MED: nothing pinned that an update's audit records the stored set as the set before, whatever the caller sends. Pinned by a forged `declared` on an update [src/OcuPilot/Test/InstallRecordWrite.cls]
- [x] [Review][Patch] MED: `SetRefused`'s resource-pattern clause had no leg. Added the `bad name:USE` leg [src/OcuPilot/Test/InstallRecordWrite.cls]
- [x] [Review][Patch] MED: the store accepted a set naming one pair twice, which the port refuses. `SetRefused` now refuses it, compared without regard to case. Measured: all 222 adjustable screens' declared sets and every stored row pass, so the port's answers are unchanged [src/OcuPilot/Kernel/State/Access.cls]
- [x] [Review][Patch] LOW: `Access.PERMISSIONS` and `RESOURCEPATTERN` are now held equal to the port's; `InstallAsAdministrator.Stored` delegates to `InstallRecordWrite.Stored`; the upgrade and uninstall legs assert the installer holds no role; `OnAfterAllTests` revokes in the install namespace; the dead `tUnescalated` is gone; six comments with wrong counts or callers are corrected.
- [x] [Review][Defer] LOW and theoretical items are filed in the ledger (see Decisions in the stage report).

Code review of Batch 2 (`4529a120a` against `355d92438`), 2026-11-17. Measured on `ocupilot-ci` as the developer principal (`%Development:USE`, no `OcuPilotAdmin`, no `%All`) against seeded victim rows.

- [x] [Review][Patch] HIGH: every store shares `Base`'s extent (`^OcuPilot.Kernel.State.BaseD`), and `GuardedOpenId` and `GuardedExistsId` read `OWNERWRITE` from the class called. `##class(OcuPilot.Kernel.State.Base).GuardedOpenId(<victim id>)` returned the victim's proposal (tool, target), ledger row (arguments), turn and conversation. Both now gate on the row's own class (`GuardedRowClass`). Pinned by `Base` legs in `OwnerStateRead`'s proposal, ledger and other-store reads [src/OcuPilot/Kernel/State/Base.cls]
- [x] [Review][Patch] HIGH: an open returns the object the caller holds. A developer holding its own proposal with `ArgumentsSetObjectId(<victim stream id>)` read the victim's arguments through `GuardedByKey` on its own key. `GuardedStreamText` now reads only the stream the row stores (id, class and location), and `RowValues` hands back nothing on a refusal. Pinned by `OwnerStateRead.TestAHeldRowCannotReadAnotherRowsStream` [src/OcuPilot/Kernel/State/Base.cls, src/OcuPilot/Kernel/State/Propose.cls]
- [x] [Review][Patch] HIGH: a held own run saved through `SqlRun.GuardedFinish` persisted a re-pointed answer, and its view then served the victim's proposal arguments; a new answer stream given the victim's stream id overwrote the victim's proposal arguments (measured on the tree without the check). The two saves every write funnels through now refuse a stream whose class or location is not the property's own, or whose id is neither the stored one nor one this process is writing anew (`StreamChangeRefused`). Pinned by `ReserveSweepWrite.TestAHeldRunCannotTakeAnotherRowsStream` [src/OcuPilot/Kernel/State/Base.cls]
- [x] [Review][Patch] MED: `Ledger.GuardedCountOverflow` handed back the victim's dropped count in `pDropped` when its save was refused (a turn key whose turn is gone). It now answers 0 on any failure. Pinned by `OwnerStateRead.TestACountOnAnotherUsersOrphanedLedgerAnswersNothing` [src/OcuPilot/Kernel/State/Ledger.cls]
- [x] [Review][Patch] MED (DW-2689): the held-row legs stopped at the refused open. `ReserveSweepWrite.TestAHeldOwnRowNamingAnotherUserIsRefused` holds the developer's own turn and run with the owner edited to the victim's: the turn reserve, finish and cancel are refused 822, the abandon marks only its own turn, and the victim's rows are unchanged [src/OcuPilot/Test/ReserveSweepWrite.cls]
- [x] [Review][Patch] MED (Rule 19): `Base.PublicSaveRefused`'s owner-store branch had no leg that reaches the save. `OwnerStateRead.TestADeveloperCannotSaveItsOwnProposalThroughBase` saves the developer's own proposal through both public saves (822); `StoreOwnerWrite`'s mutation line is corrected [src/OcuPilot/Test/OwnerStateRead.cls, src/OcuPilot/Test/StoreOwnerWrite.cls]
- [x] [Review][Patch] MED (Rule 19): the `Held.Stream` control passed when the open failed, and the roster checked only public class methods. The control asserts the open; the roster asserts no public instance method or query on either store, and its two literal-only assertions are gone [src/OcuPilot/Test/OwnerStateRead.cls, src/OcuPilot/Test/OwnerStateReadProbe.cls]
- [x] [Review][Patch] LOW: `LeftOver` counts the seeded steps and entries; four doc comments with a wrong mutation, check or outcome are corrected (`OwnerStateRead` twice, `ReserveSweepWrite.TestAnAbandonIgnoresAHeldKey`, `Ledger.GuardedIdsForWindow`); the triage reason for cancel is corrected.
- [x] [Review][Defer] LOW: DW-2686 gains an occurrence (`GuardedAppend`'s `pSeq`, transcript-access rows); DW-2690 to DW-2693 are filed.

## Spec Change Log


## Review Triage Log

### 2026-11-16 — Review pass

- verdicts: 15 findings — high 0, medium 3, low 8, false 3, maybe-false 1
- findings:
  - `[false]` `[reject]` Demo fixture creation is not routed through the frame — `Fixture.Create` runs from `StartPathLocked` as the container's own account (`%All`), which the gate admits; the spec's Design Notes decide this path.
  - `[false]` `[reject]` The retention sweep is not routed through the frame — the task runs as its saving account (`%All`), as 21.33 measured; `Retention` and `RetentionTask` stay green.
  - `[low]` `[reject]` The new tests do not drive the port as a principal — `ScreenAccessWire.TestEachAcceptedWriteIsOneSecurityChangeRow` drives the port and counts the audit rows, green after the change; not worth a second test.
  - `[false]` `[reject]` `GuardedPut` and `GuardedRemove` gained a `pDeclared` argument and the store refuses a changer that is not the caller — both are the spec's own requirements (option b, the `pBy` check).
  - `[medium]` `[patch]` `GuardedRecord` and `GuardedMarkGatewayReported` carry a refusal line no test leg isolates — the legs now send a recorded path and a path with no row; the removed line turns each red.
  - `[medium]` `[patch]` The gateway-mark step is unpinned under the installer principal — `InstallAsAdministrator` asserts no unreported application remains; skipping the role for `gatewayMark` alone turns it red.
  - `[medium]` `[patch]` The mutation record covers `WebApp` and `Access` only — `ADMINWRITE` = 0 on `Stamp`, `Version` and `Demo`, and the two refusal lines, are recorded above. The `demoRemove` step still has no seeded-row leg (deferred).
  - `[low]` `[defer]` `Base.GuardedProbeSet` is a public writer every store inherits, listed under reads and helpers by `BaseSurface` — pre-existing, writes a probe global only; whether to gate it is `Base`'s decision.
  - `[maybe-false]` `[defer]` A caller-defined subclass with `ADMINWRITE` = 0 would pass `Base`'s guard, which reads the parameter from the object's own class — pre-existing in every `ADMINWRITE` and `OWNERWRITE` store; it needs a compile right in the install namespace (inference), which a probe would settle.
  - `[low]` `[defer]` `Access.GuardedPut` does not check the screen name, a duplicate pair or the length of `pDeclared`, so a direct adjuster can add rows and shape the audit's before-set — the actor and the stored set stay true; the spec's Design Notes limit the store's checks to shape, count and the empty set.
  - `[low]` `[patch]` The `Access` class comment claimed every write is audited once — now says `GuardedPut` and `GuardedRemove` audit, so a write through the port is audited once.
  - `[low]` `[reject]` A failed audit write is now silent where the port logged it — the store has no logging seam it may call (`Kernel/State` may not name `Port`); the audit seam is `Event.Record` (inference).
  - `[low]` `[patch]` `ScreenAccessWire`'s mutation recipe names the deleted `ScreenAccessPort.Audit` — now names `Access.Audit`.
  - `[low]` `[patch]` The `Demo` comment said the installer writes the store — now says it removes rows, and the fixture creates them as the container's account.
  - `[low]` `[reject]` `saveRow`'s class restriction, the unknown-step refusal and the refused role-addition branch have no test — a private method with no other caller; the closed list is its own pin.

### 2026-11-16 — Review pass (Batch 2)

- verdicts: 14 findings — high 0, medium 2, low 5, false 2, maybe-false 0, not-a-finding 5 (the intent auditor's descriptive items, graded below)
- findings:
  - `[medium]` `[patch]` `ReserveSweepWrite`'s five held-row legs asserted outcomes that hold whatever the sweep does, because the reserve or abandon never ran once the open was refused — the probe now records the open's code as `openCode` and runs the reserve, abandon and view regardless; the legs assert the 822, the accepted call and the kept rows. Open-check mutation: five legs red, reverted.
  - `[medium]` `[patch]` `Write.IsRefusedRead` was untested against a non-822 failure — `OwnerStateRead.TestOnlyAnAccessDeniedIsARefusedRead`; answering 1 for any error turns it red.
  - `[low]` `[patch]` Four Batch 2 pins had no mutation line — recorded below for the missing-row, conversation-user and `IsRefusedRead` pins and the shared `EnsurePrincipals` access argument; the direct-path control is stated as the control the gate is measured against.
  - `[low]` `[patch]` The direct-path control passed for any refusal on an empty id — it now asserts the three seeded ids are non-empty first.
  - `[low]` `[patch]` `AssertAllRefused` and `AssertAllAnswered` checked only a non-empty leg list — they take the plan and compare its size.
  - `[low]` `[reject]` The roster's `Handles` check reads the same static list that declares the kinds — the split test pins the method sets of both stores in both directions; a stronger "some test plans it" proof is not worth a registry.
  - `[low]` `[reject]` `OwnerStateRead` is over 500 lines — a new class at 580; the 12 tests share one probe, and splitting costs a second armed class and probe for no behavior.
  - `[low]` `[reject]` A non-owner now meets 822 for an existing id where a missing id answers not found — the spec decides "a row that does not exist answers as today"; the keys are 32 random hex characters.
  - `[low]` `[reject]` The route answers are pinned at the kernel methods, not over HTTP — `ProposalWire`, `TranscriptsWire`, `LedgerWire` and `ProposalConfirm` are green, and the Api layer renders each method's status and code unchanged.
  - `[false]` `[reject]` The transcript leg pins a pre-existing gate, not the 822 mapping — `Convo.GuardedOwnerOf` and `Entry.GuardedTurnKeys` are Batch 3's reads, so no Batch 2 change reaches that route; the leg holds its answer.
  - `[false]` `[reject]` Cancel has no mapping of its own — it closes through `Propose.GuardedClose`, an update filtered by the caller's user that reads no gated row; the cancel leg pins its answer.
  - `[low]` `[reject]` Two private wrappers (`Propose.RowReadRefused`, `Ledger.WindowReadRefused`) and the twins read like new predicates — each delegates to `OwnerWriteRefused` or `CallerIsAdministrator`; the twins exist so the predicates do not recurse into the gated read.
  - `[low]` `[reject]` No ledger caller maps 822 — every product caller of the windowed reads is `Audit.Ledger.ViewForUser` and `GateTurns`, which check the administrator's privilege first; `Ledger`, `LedgerWire` and `AuditEvent` are green.
  - `[low]` `[reject]` The AD-9 narrowing is a spine edit — the spine was edited by the runner (`046388151`); this build edits only the spec's Design Notes text.

### 2026-11-17 — Review pass (Batch 3)

- verdicts: 13 findings — high 0, medium 2, low 7, false 0, maybe-false 0, not-a-finding 4 (the intent auditor's descriptive items, graded below)
- findings:
  - `[medium]` `[patch]` The owner of a step, directive or entry whose parent row is gone was unpinned — measured: `Nav.GuardedPending` handed the directive to a non-owner (a real gap, since its open is by key and its check names a parent that no longer exists); `Nav.GuardedPending` now asks `OwnerWriteRefused` of the opened row, and `TestAnOrphanedChildRowOfAnotherUserIsNotHandedBack` pins all three reads (mutations recorded).
  - `[medium]` `[patch]` `Convo.GuardedScreenRows` had no assertion that another user's title never reaches an administrator's list — the list test asserts the administrator's rows carry no `victim-message`; the mutation is recorded.
  - `[low]` `[patch]` The owner leg of the transcript route test passed for any answer but 404 — it now also asserts the answer is neither 403 nor 500.
  - `[low]` `[patch]` The `UserStateRead` arming line had no mutation record — removed in turn, `ci.test.mjs` goes red (recorded).
  - `[low]` `[defer]` The mapping of a refused `Entry.GuardedTurnKeys` to 404 has no test leg — carried: already in the deferred list; only a race between two calls reaches it.
  - `[low]` `[defer]` `Convo.GuardedScreenRows`'s two defences (the SQL scope and the per-row open) are not pinned one at a time — the code is unchanged in Batch 3 and either layer alone is enough; a per-layer leg would need a held-row probe.
  - `[low]` `[defer]` `Entry.GuardedTurnKeys` hands the turn keys of an orphaned conversation to any caller — measured by reading: its check passes for a key that names no conversation and it reads by SQL; keys only, no content, and no product path leaves an orphaned entry (inference).
  - `[low]` `[reject]` A key that names no row answers OK-empty while another user's key answers 822, so a non-owner can tell the two apart — the spec decides "a row that does not exist answers as today", `TestARowThatDoesNotExistAnswersAsItDid` pins it, and keys are 32 random hex characters.
  - `[low]` `[reject]` `UserStateRead` is 722 lines against a roughly 500-line guide — Batch 2's `OwnerStateRead` was accepted at 654 for the same reason: one probe, shared seeding.
  - `[not-a-finding]` `[reject]` The route row is exercised by calling `HandleRead` with a stubbed request and response, and asserts the status but not the error code — the 404 renders through the one `NotFound` that an unknown id also uses; the status is the pinned contract.
  - `[not-a-finding]` `[reject]` The `(loop)` suites run as `%All`, so a non-administrator owner's product path is not driven over HTTP — `DeveloperFloorTurn` and `UserStateRead`'s owner legs run as the developer principal, and the turn and background jobs run as the row's owner (spine AD-33); a wire suite as a non-administrator is outside this batch.
  - `[not-a-finding]` `[reject]` Key reads refuse when a row exists and answer empty when none does, while user reads refuse the name — descriptive; the spec's "Decided in-stage" note settles both.
  - `[not-a-finding]` `[reject]` `Turn.GuardedLiveUsers` and `GuardedIsTurnJob` stay open to any caller — by the spec's own rule, pinned by `TestTheOpenReadsStayOpen`.

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

> **Install records answer to the install, screen access to its adjusters, and each user's state is read by that user** [AMENDED 2026-11-16, Story 21.35, owner answer U-90, DW-2651, DW-2652]. The install-owned stores (application provenance, install stamps, version rows and demo inventory) join the `ADMINWRITE` stores. The install writes them, and the target keys, through one private `Installer` method. That method adds the administrative role to its own process inside a `New $ROLES` frame around one step from a closed list. The admission rule and fallback are the target-key frame's: IRIS admits the addition only to a process that can write the system database, and a process that cannot add the role runs the step unescalated, where the store decides. The screen-access store refuses a caller who holds neither `OcuPilotAdmin:USE` nor AD-64's adjuster pair, and a set whose shape, size or emptiness its port would refuse, or one that names a pair twice, with `ERROR #822`. It records the calling account as the changer, and `Base`'s public saves serve an administrator only for it. The `OWNERWRITE` stores refuse a read of a row whose owner is not the caller with `ERROR #822`, unless the caller holds `OcuPilotAdmin:USE`. That covers `Base`'s public reads and each store's key, token, id and user reads. A read across every user is an administrator's. Two reads stay open because a product path makes them for another user by the instance's own rule: the names of users with live turns, and whether a process is a turn job.

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
- `Access`'s set checks repeat only the shape, the count and the empty set. They do not repeat `Apply`'s resource-defined check: a declared set may name a resource another IRIS edition lacks (inference), and the AD text claims only the shape, size, emptiness and duplicate checks.
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
- Batch 3 (implement, 2026-11-17):
  - A read that names another user, or another user's key, is refused 822 whether or not that user holds a row. A key that names no row, and a caller who names itself with another user's key, answer as before (nothing found), so the owner compares upstream of the routes keep their answers.
  - `Step.GuardedRows`, `Nav.GuardedPending`, `Entry.GuardedRows` and `GuardedTurnKeys` check the key through `NamedOwnerRefused`, naming the parent class and index from their `OWNERPARENT` parameters; `Turn.GuardedDropped`, `GuardedSignals`, `Convo.GuardedOwnerOf` and `SqlRun.GuardedCancelRequested` check their own key the same way.
  - `Turn.GuardedDefinitionOf` and `GuardedWorkflowOf` take no check of their own: their open is Batch 2's `GuardedOpenId`, which refuses the row with 822. A mutation that makes it the any-caller open turns the turn test red.
  - `Step.GuardedRows`, `Entry.GuardedRows` and `Pref.GuardedListForUser` keep their per-row `GuardedOpenId`, so a row whose parent is gone stays unreadable to a non-administrator. `Nav.GuardedPending` opens by key through a private open, so it asks `OwnerWriteRefused` of the row it opened.
  - Pinned by test rather than changed: `Convo.LoadOrCreate`'s load branch (21.33's check), `Convo.GuardedScreenRows` (scoped to the caller by its SQL and again by its per-row open), and the two open reads.
  - `SqlRun.GuardedViewForOwner` checks `pUser` at the top, so the conditional around its reconcile is gone.
  - `UserStateRead` carries its own three assertion helpers: an assertion macro binds to the test case that runs it, so `OwnerStateRead`'s cannot be shared.
  - Opening one store's row through another store's class name fails ("not an instance", ERROR #5825) before any gate; `UserStateRead` pins it as a control.

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

- `(loop)` `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/b708a79b-b765-42ec-adea-dbc87acf6251/scratchpad/e21u/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` -- expected: `LOADERRORS=0`.
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

**Runner ruling at the spec gate (2026-11-16):** validated. Implementation waits for Story 21.33 to be done. The AD-9 text above is written into the spine at that start, after 21.33's DW-2665 text it builds on, complying first under U7. Screen access: option (b), orchestrator ruling (veto item): the store records the audit event itself, and a write through the port is audited exactly once, pinned by a test.

**Task 0 (pre-fix), Batch 1 (2026-11-16, `ocupilot-ci`).** Run on the baseline product files (`Access`, `WebApp`, `Stamp`, `Version`, `Demo`, `Installer`, `ScreenAccessPort` as at `6e62e114f`) under the final test classes. The read legs (DW-2652) belong to Batches 2 and 3 and were not run.

- `InstallRecordWrite`: 7 of 8 tests red; the administrator test is green. As a real principal holding `%Development:USE` and no `OcuPilotAdmin` or `%All`, every write landed (ok, no 822):
  - all 23 install-record legs: `WebApp.GuardedRecord`, `GuardedMarkGatewayReported`, `DeleteByPath`, `Stamp.DeleteByProfile`, `GuardedSweep`, `Version.DeleteByProfile`, `Demo.DeleteByProfile`, and a new and an opened `WebApp`, `Stamp`, `Version` and `Demo` row saved through both of `Base`'s public saves; the rows read differently afterwards.
  - Provenance steering: a foreign application replaced one probe application, the developer's `GuardedRecord("probe", <path>, "created")` landed, and `Uninstall("probe", 1)` deleted the foreign application.
  - Screen access: a principal with no adjuster pair and no `OcuPilotAdmin` landed `GuardedPut`, `GuardedRemove`, `DeleteAllGuarded` and both `Base` saves of a new and an opened `Access` row (7 of 7 legs). The developer landed an empty set, nine pairs, a malformed pair, an unmalformed pair under a changer that is not itself, and `DeleteAllGuarded`. A held row whose screen was changed in memory renamed the stored row through `GuardedPut`.
  - A put and a remove through the store wrote no audit row (0 of 4).
  - `Base.GuardedProbeSet` (measured at review as the developer principal, unfixed tree): a direct set of `^OcuPilotKernelStateProbe` raises `<PROTECT>`, but through `GuardedProbeSet` on `Base` or any store the developer wrote any subscript and a 3,000,000-character value, and overwrote `migrationStepV2` in `/durable/iris/mgr/ocupilot/`. After the fix every call is refused 822 and nothing is written (`InstallRecordWrite.TestOnlyAnAdministratorWritesTheProbeGlobal`; callers `Test/State` and `Test/MigrateFault` stay green).
- `InstallAsAdministrator`: green. Installer role, measured by removing each grant in turn on a scratch principal (probe install and uninstall, then deleted):
  - `%Admin_Secure:USE` (without it: `EnsureDatabaseResource` fails), `%Admin_Manage:USE` (`EnsureDatabase`), `%DB_IRISSYS:RW` (`EnsureDatabase`, and `<PROTECT>` in `LockInstall` without any `%DB_IRISSYS`), `%DB_<install databases>:RW`.
  - SQL: `SELECT` on `%Dictionary.CompiledClass` (the install's class-dictionary read, `-99` without it) and `SELECT, INSERT, UPDATE, DELETE` on `OcuPilot_Kernel_State` with the grant option (`EnsureSqlPrivileges` fails without it).
  - Not needed: `%Admin_Operate:USE`, `%Development:USE`. Read-only `%DB_IRISSYS` or `%DB_<install>` fails at `EnsureDatabase` and leaves a database with no configuration entry that `Uninstall` cannot remove (cleaned by hand on `ocupilot-ci`).

**Batch 1 after.** `InstallRecordWrite` 8 of 8, `InstallAsAdministrator` 1 of 1 (probe install, upgrade over a keyless proposal and uninstall as the installer, no `%All`, no `OcuPilotAdmin`; its process is without the role after each step), `AdminStateWrite` 7 of 7 (ten stores), `AdminPathWrite` 5 of 5. The Batch 1 `(loop)` classes are green: `StoreOwnerWrite`, `State`, `Installer`, `InstallLock`, `InstallMark`, `Version`, `Provenance`, `WebApp`, `GatewayGapIpmPath`, `UninstallGuard`, `UninstallResidue`, `UninstallSurvival`, `Escalation`, `IdentityInstall`, `SslReadInstall`, `ProposalTargetKey`, `RetentionTask`, `StampRetention`, `DemoOptIn`, `Demo`, `FixtureNamespace`, `ScreenAccessWire`, `ScreenAccessRefusals`, `ScreenAccessTurn`, `ScreenAccessGate`, `ScreenAccessAgent`, with `Retention`, `InteropUsageGate`, `ScreenRefusal` and `AnalyticsMdxReadGate` (they call `Access`). `MigrateFault`, `UninstallFault`, `EscalationGap`, `FixtureFault` and `ProbeApps` are fixtures that carry no test method. `uv run scripts/check-objectscript.py` 0 problems; `uv run scripts/test_check_objectscript.py` 160 tests OK; `node --test tools/ci.test.mjs` 103 pass.

**Mutations, Batch 1 (Rule 19; each applied, observed red, reverted, tree byte-identical, reloaded).**

- mutation: `WebApp` `ADMINWRITE` = 0 -> `InstallRecordWrite` `TestADeveloperIsRefusedEveryInstallRecordWrite`, `TestAForgedProvenanceRowDoesNotSteerAnUninstall` and `TestTheInstallRecordStoresAreDeclared` red; `AdminStateWrite` `TestTheAdministratorStoresAreDeclared` red.
- mutation: the `AdminWriteRefused` line removed from `Stamp.DeleteByProfile`, `Stamp.GuardedSweep`, `Version.DeleteByProfile`, `Demo.DeleteByProfile` or `WebApp.DeleteByPath`, one at a time -> `TestADeveloperIsRefusedEveryInstallRecordWrite` red each time. The same line removed from `WebApp.GuardedRecord` (a recorded path is sent) or from `GuardedMarkGatewayReported` (a path with no row is sent) -> `TestADeveloperIsRefusedEveryInstallRecordWrite` red each time. `ADMINWRITE` = 0 on `Stamp`, `Version` or `Demo`, one at a time -> `TestADeveloperIsRefusedEveryInstallRecordWrite` and `TestTheInstallRecordStoresAreDeclared` red each time.
- mutation: `AsAdministrator` skips its role addition -> `InstallAsAdministrator` and `AdminPathWrite.TestAnUpgradeByAnAccountGrantedTheRoleInTheSameInstallKeysTheProposals` red. Skipped for `deleteStamps` alone -> `InstallAsAdministrator` red on the records after uninstall. Skipped for `gatewayMark` alone -> `InstallAsAdministrator` red on the gateway-report assertion.
- mutation: `Access.WriterRefused` answers OK -> `TestAPrincipalWithoutAnAdjusterPairIsRefusedEveryScreenAccessWrite` red at `GuardedPut` and `GuardedRemove`. `Access.SetRefused` answers OK -> `TestAnAdjusterIsRefusedWhatThePortWouldRefuse` red at the empty, nine-pair, malformed and unknown-permission legs. The `CallerOwns(pBy)` test replaced by 0 -> the forged-changer legs red. The held-screen comparison removed -> `TestAHeldScreenAccessRowCannotBeRenamed` red. `Access` `ADMINWRITE` = 0 -> the `Base` save legs, `DeleteAllGuarded` and the roster red. The check removed from `DeleteAllGuarded` -> that leg red.
- mutation: the store's `Audit` call made a no-op -> `TestAnAdjusterStoresAndTheStoreAuditsOnce` and `ScreenAccessWire.TestEachAcceptedWriteIsOneSecurityChangeRow` red (no row). A second `Audit` call after the put -> both red (two rows).
- `scripts/test_check_objectscript.py`: `New $ROLES` in `AsAdministrator` accepted; in `EnsureProposalTargetKeys`, or in a later method, refused.

**Code review, Batch 1 (2026-11-16, `ocupilot-ci`).**

- Version row: a first probe install by an installer without `%All`, `OcuPilotAdmin` or `%Admin_Secure:USE` fails at `EnsureDatabaseResource`. On the parent's product files and on this commit alike, it writes a `failed` row (`FailingStep` `EnsureDatabaseResource`). The process holds no role before or after. No change. Unchanged on both trees: `Uninstall("probe", 1)` leaves that `failed` row behind.
- Frame reachability: four non-installer principals (`%Development`; `%Admin_Secure`; `%Development` with `%DB_IRISSYS:R` and the install databases read-write; `%Development` with `%Admin_Manage` and `%Admin_Operate`) called `AsAdministrator` directly (`<PRIVATE METHOD>`), `ReportGatewayGap`, `EnsureProposalTargetKeys`, `MarkInstalling` for both profiles, `Install`, `Uninstall`, `StartPath` and `Set $ROLES` (`<PROTECT>`). None held `OcuPilotAdmin` after any step, and the probe's records and production's phase were unchanged.
- Port sets: all 222 adjustable screens' declared sets (of 232 descriptors) and every stored row pass the store's shape, count and duplicate checks.
- Green after the patches: `InstallRecordWrite` 9 of 9, `InstallAsAdministrator` 1, `AdminStateWrite` 7, `State` 12, `Version` 19, `InstallMark` 6, `ScreenAccessGate` 9, `ScreenAccessWire` 8, `ScreenAccessRefusals` 5, `ScreenAccessTurn` 2, `AdminPathWrite` 5.
- mutation: the caller check removed from `Base.GuardedProbeSet` -> `InstallRecordWrite.TestOnlyAnAdministratorWritesTheProbeGlobal` and `State.TestEscalationIsWhatGrantsTheDeniedUserAccess` red.
- mutation: `AsAdministrator` skips its role addition for `demoRemove` alone -> `InstallAsAdministrator` red (the uninstall stops with the demo row left).
- mutation: the duplicate clause, then the resource-pattern clause, removed from `Access.SetRefused` -> `TestAnAdjusterIsRefusedWhatThePortWouldRefuse` red at the `twice` and `badname` legs.
- mutation: `GuardedPut`'s audit made unconditional -> the seed-screen zero-audit pin and the put count red; `GuardedRemove`'s audit moved above its stale check -> the reset count red; the update's stored read removed -> the before-set assertion red (`TestAnAdjusterStoresAndTheStoreAuditsOnce`).

**Task 0 (pre-fix), Batch 2 (2026-11-16, `ocupilot-ci`).** Run on the Batch 1 tree under the final `OwnerStateRead`: the four refusal tests red, and the owner, administrator, missing-row, direct-path and route tests green. As a real principal holding `%Development:USE` and no `OcuPilotAdmin` or `%All`, every call below answered ok with the victim's values (no 822):

- Proposal, 10 of 10 legs: `GuardedByKey` and `GuardedByToken` (id, user, tool, target, arguments), `GuardedRowVersion` (version 1), `GuardedRowsForTurn` and `GuardedRowsForConvo` (one row), `GuardedCountForTurn` (1), and `Base`'s open, exists and two stored-value reads (`TargetRef`, `UserName`).
- Ledger, 9 of 9: `GuardedRow` (user, name and the stored arguments), `GuardedIdsForWindow` by turn and by window, `GuardedDroppedFor` both ways, `GuardedCountForTurn` (2), and `Base`'s three reads.
- Other stores through `Base`, 10 of 10: turn, step (owner through its turn), conversation and entry (owner through its conversation), each opened and existence-checked, and a turn's `State` and a conversation's `UserName`.
- Across users: `GuardedIdsForWindow` and `GuardedDroppedFor` with `pAllUsers` 1 answered the victim's and the developer's rows together (2 ids, a dropped count of 2).
- Controls, refused before and after: a direct `%OpenId` (`ERROR #939`), a direct `SELECT COUNT(*)` of the proposal table (SQLCODE -99, the ledger's by the test) and the stream of the developer's own opened row read outside the frame (`<PROTECT>%LockStream`).
- Route answers, measured before and pinned after: confirm 403 `PROPOSAL.NOTYOURS`; cancel and draft 404 `PROPOSAL.UNKNOWN`; claim by token and by id `PROPOSAL.NOTYOURS`; a claim of an id no row carries `PROPOSAL.UNKNOWN`; the transcript gate withholds with `AUTH.NOPRIVILEGE`, which the route renders as its 404. `Convo.GuardedOwnerOf` and `Entry.GuardedTurnKeys` are SQL reads Batch 3 gates, so the route's answer is untouched here (`TranscriptGate`, `TranscriptsWire` green). One answer moves, on a path no route sends (the id and the token come from one row): a claim naming a victim's token with an id that is not that row's answered UNKNOWN and now answers NOTYOURS.

**Inventory, Batch 2 (measured from the compiled classes).** `Propose` has 22 public class methods of its own and `Ledger` 10, none public instance methods or queries; both inherit `Base`'s 21.

- Reads, gated: `Propose.GuardedByToken`, `GuardedByKey`, `GuardedRowVersion`, `GuardedRowsForTurn`, `GuardedRowsForConvo`, `GuardedCountForTurn`; `Ledger.GuardedRow`, `GuardedIdsForWindow`, `GuardedDroppedFor`, `GuardedCountForTurn`; `Base.GuardedOpenId`, `GuardedExistsId`, `GuardedStoredValue`.
- Reads, open: `Propose.TargetLockKey`, `TargetHoldKey`, `GuardedTargetHold`, `GuardedTargetRelease`, `ProjectedState`, `NowSeconds`, `SecondsOf` (lock keys, a lock and the clock); `Base.GuardedProbeGet`, `GuardedRolesSnapshot`, `GuardedSslConfigRead`, `GuardedUserAbsent`, `GuardedUserEnabled` (the test probe global, the caller's own roles, identity and TLS configuration).
- Writers, already gated by 21.30 and 21.33: `Propose.GuardedMint`, `GuardedRecordReadBack`, `GuardedClaimAndClose`, `GuardedClose`, `GuardedCloseLiveForConvo`, `GuardedCloseLiveForUser`, `GuardedExpireStale`, `GuardedRebuildTargetKeys`, `GuardedDeleteForTurn`, `GuardedDeleteForUser`; `Ledger.GuardedAppend`, `GuardedFinalize`, `GuardedCountOverflow`, `GuardedDeleteForTurn`, `GuardedDeleteForUser`, `GuardedPurgeBefore`; `Base.GuardedSave`, `GuardedSaveIfCurrent`, `GuardedProbeSet`. The values a writer answers (`GuardedClaimAndClose`'s terminal state, a count, a sequence) follow its own gate.
- Other paths to a row: the inherited `%OpenId` and a direct query are refused by the database (controls above), a stream of an opened row cannot be read outside `Base`'s frame, and no store method returns an object it opened for a caller other than `Base.GuardedOpenId`.
- Store-internal opens keep the public open when the caller is the owner or the open follows the store's own user check (`Turn`, `Step`, `Entry`, `Convo`, `Pref`, `SqlRun`); the proposal row loops use `GuardedOpenIdAnyCaller` after their user and key checks. No sweep, reconcile, abandon, expiry or claim sibling opens a row through `GuardedOpenId`: they run by SQL.

**Batch 2 after.** `OwnerStateRead` 11 of 11. Green with no change to the class: `StoreOwnerWrite` 14, `AdminStateWrite` 7, `AdminPathWrite` 5, `InstallRecordWrite` 9, `InstallAsAdministrator` 1, `State` 12, `ProposalConfirm` 24, `ProposalClose` 7, `ProposalRace` 6, `ProposalWire` 17, `ProposalCreate` 11, `Proposal` 15, `DraftExecute` 2, `Ledger` 11, `LedgerWire` 6, `LedgerSearch` 10, `LedgerPairs` 9, `LedgerEmptyPairs` 4, `LedgerSense` 8, `AuditEvent` 9, `TranscriptGate` 8, `Retention` 10, `DeveloperFloorTurn` 1. The gate also reaches every `OWNERWRITE` store, so these Batch 3 classes were run and are green: `TranscriptOwnerWrite` 9, `PrefOwnerWrite` 6, `TurnStore` 11, `TranscriptStore` 5, `TranscriptsWire` 7, `ConversationRestore` 4, `Convo` 7, `TurnWire` 15, `TurnConversation` 11, `TurnNavigate` 15, `TurnLoop` 11, `PrefState` 17, `PreferencesWire` 12, `SqlRunStore` 14, `SqlBackgroundRoutes` 9, `ContextBound` 15, `RemovalRowsSweep` 7, `ProcessControl` 15, `AgentPickTurn` 3 (`NavSettleJob` is a fixture with no test method). `ReserveSweepWrite` ran 5 of 16 red: five legs held another user's row opened with the public `GuardedOpenId`, which a non-owner can no longer do. Each now asserts the open is refused 822 and the rows are unchanged, 16 of 16 green. `uv run scripts/check-objectscript.py` 0 problems; harness 162 tests OK; `node --test tools/ci.test.mjs` 103 pass.

**Mutations, Batch 2 (Rule 19; each applied, observed red, reverted, `git diff --stat` unchanged, reloaded).**

- mutation: the owner check removed from `Base.GuardedOpenId` -> `OwnerStateRead` red at the open legs of the proposal, ledger and other-store tests.
- mutation: the owner check removed from `Base.GuardedExistsId` -> the exists legs of the same three tests red.
- mutation: the owner check removed from `Base.GuardedStoredValue` -> the stored-value legs red.
- mutation: `OwnerWriteRefused`'s parent lookup disabled -> `TestAnOwnerReadsItsOwnRows` red at the step and entry legs.
- mutation: `RowReadRefused` removed from `Propose.GuardedByKey`, `GuardedByToken` or `GuardedRowVersion`, one at a time -> `TestADeveloperIsRefusedEveryReadOfAnotherUsersProposal` red at that leg alone.
- mutation: the user check removed from `Propose.GuardedRowsForTurn` -> `TestADeveloperIsRefusedAReadNamingAnotherUsersKey` red at its victim legs; the turn owner check removed -> its developer-user leg red; the conversation owner check removed from `GuardedRowsForConvo` -> its leg red; the turn owner check removed from `GuardedCountForTurn` -> `TestADeveloperIsRefusedEveryReadOfAnotherUsersProposal` red at the count leg.
- mutation: `Ledger.WindowReadRefused` serves `pAllUsers` to any caller -> `TestADeveloperIsRefusedTheLedgerAcrossEveryUser` red at all five legs; its user check removed -> the ledger window and dropped legs red; the check removed from `GuardedDroppedFor` alone -> its two legs red in two tests.
- mutation: the turn and conversation checks removed from `Ledger.GuardedCountForTurn` -> `TestADeveloperIsRefusedEveryReadOfAnotherUsersLedgerRows` red at the count leg; the conversation check alone -> the conversation-key leg red.
- mutation: the confirm peek maps 822 to an error -> `TestTheRouteAnswersAreUnchangedForANonOwner` red at the confirm leg; `Write.Claim` or `ClaimById` without the mapping -> the claim legs red (and confirm, for `ClaimById`); `Draft.Take` without it -> the draft leg red.
- mutation: the administrator exemption removed from `Base.OwnerWriteRefused` -> every `OwnerStateRead` test red at its seeding, which the suite's own `%All` identity can no longer do.
- mutation: a public class method added to `Ledger` -> `TestTheReadsAreSplitIntoOwnerAdministratorAndOpen` red.
- mutation: `Write.IsRefusedRead` answers 1 for any error status -> `TestOnlyAnAccessDeniedIsARefusedRead` red alone.
- mutation: `Base.GuardedExistsId` refuses a missing row 822 -> `TestARowThatDoesNotExistAnswersAsItDid` red alone.
- mutation: the user check removed from `Propose.GuardedRowsForConvo` -> `TestADeveloperIsRefusedAReadNamingAnotherUsersKey` red alone.
- mutation: `AdminStateWrite.EnsurePrincipals` ignores its access argument (always `R`) -> `AdminPathWrite` red at two tests.
- mutation: the owner check removed from `Base.GuardedOpenId` -> `ReserveSweepWrite` red at the open leg of five tests (`openCode`, and the view's refusal); the sweep, reserve and abandon legs stay green, which shows the sweeps read stored rows whether or not a row can be held.

**Code review, Batch 2 (2026-11-17, `ocupilot-ci`).**

- Reads, measured as the developer: a direct `%OpenId`, `%ExistsId`, `UserNameGetStored` and `<index>Open` fail on the protected database, `<index>Exists` and the `Extent` query answer nothing, and SQL on either table is -99. The developer cannot swizzle a stored stream outside the frame (`<PROTECT>%LockStream`), so a forged stream location is not reachable; `GuardedStreamText` checks it anyway. Opens through `Switch`, `Agent`, `Hold`, `Access`, `WebApp`, `Stamp` and `Ledger` of a proposal id fail with 5825. An administrator without `%All` still reads every victim row through `Base`.
- Green after the patches: `OwnerStateRead` 15, `ReserveSweepWrite` 18, `State` 12, `StoreOwnerWrite` 14, `AdminStateWrite` 7, `AdminPathWrite` 5, `InstallRecordWrite` 9, `PrefOwnerWrite` 6, `TranscriptOwnerWrite` 9, `PrefState` 17, `SqlRunStore` 14, `SqlBackgroundJob` 12, `SqlBackgroundRoutes` 9, `TranscriptStore` 5, `TranscriptsWire` 7, `TranscriptGate` 8, `ConversationRestore` 4, `Convo` 7, `TurnStore` 11, `TurnLoop` 11, `TurnWire` 15, `ProposalCreate` 11, `ProposalConfirm` 24, `ProposalWire` 17, `Proposal` 15, `ProposalClose` 7, `ProposalRace` 6, `DraftExecute` 2, `Ledger` 11, `LedgerWire` 6, `Retention` 10, `DeveloperFloorTurn` 1, `AgentPick` 5, `AgentWire` 18, `SwitchesWire` 24, `ProviderPortOwner` 4. `check-objectscript.py` 0 problems; harness 162 tests OK.
- mutation: `GuardedOpenId` reads `OWNERWRITE` from the class called -> `OwnerStateRead` red at the `Base` open legs of the proposal, ledger and other-store refusal tests.
- mutation: `GuardedExistsId` skips the row-class check -> the `Base` existence leg of the proposal refusal test red.
- mutation: `GuardedStreamText` skips the stored-id comparison -> `TestAHeldRowCannotReadAnotherRowsStream` red.
- mutation: `StreamChangeRefused` admits a stream id already saved -> `TestAHeldRunCannotTakeAnotherRowsStream` red.
- mutation: `OwnedSaveRefused` answers OK -> `TestAHeldOwnRowNamingAnotherUserIsRefused` red at the finish leg.
- mutation: `PublicSaveRefused` admits an owner store's save -> `TestADeveloperCannotSaveItsOwnProposalThroughBase` red.
- mutation: `GuardedCountOverflow` keeps its count on a refusal -> `TestACountOnAnotherUsersOrphanedLedgerAnswersNothing` red.
- mutation: `Ledger.WindowReadRefused` refuses an administrator's all-users read -> `TestAnAdministratorReadsAnotherUsersRows` red at its two all-users legs.
- mutation: the turn check removed alone from `Ledger.GuardedCountForTurn` -> the ledger refusal test red at its count leg.

**Task 0 (pre-fix), Batch 3 (2026-11-17, `ocupilot-ci`).** Run on the Batch 2 tree: the eight stores and `Api/Transcripts` loaded from `HEAD` into the throwaway, under the final `UserStateRead` (run 231). 5 of 15 tests red; the owner, administrator, open-read, missing-row, list-scope, route, control and roster tests green. As the developer principal (`%Development:USE`, no `OcuPilotAdmin`, no `%All`) against the victim's seeded rows, each output argument read after the call:

- Handed back a value of the victim, with no refusal (13 legs): `Turn.GuardedDropped`, `GuardedSignals`, `Nav.GuardedPending`, `Convo.GuardedOwner`, `GuardedOwnerOf`, `GuardedView` (the id and an empty turn list), `Entry.GuardedTurnKeys`, `Pref.GuardedValue`, `GuardedCountForUser`, `Sharing.GuardedForUser`, `SqlRun.GuardedCancelRequested`, and `Pref.GuardedUsers` and `Sharing.GuardedUsers` across every user. What each handed back is read from the seeded values and the code, not printed (inference).
- Answered OK and handed back nothing, because Batch 2's per-row open hides the row (7 legs): `Step.GuardedRows`, `Entry.GuardedRows` with and without context, `Convo.HistoryMessages`, `Pref.GuardedListForUser` for two kinds, and the history of the developer's own held conversation with its key edited to the victim's.
- Already refused 822: `Turn.GuardedDefinitionOf`, `GuardedWorkflowOf`, `GuardedForOwner` and `GuardedView` naming the victim, `Convo.LoadOrCreate`'s load branch, `SqlRun.GuardedViewForOwner` naming the victim, `Base`'s opens and existence checks of all eight stores' rows and four stored values, and the three held-stream legs (an own entry's two streams, an own run's answer), which handed back none of the victim's content.
- A read naming another user who holds no row (turn, view, conversation owner and view, preferences three ways, sharing, run view): 9 of 9 answered OK, none refused.
- Controls, the same before and after: for each of the eight stores a direct `%OpenId`, `%ExistsId`, read of one stored property, count over the table and extent query hand back nothing (40 legs); an open through another store's class name fails with ERROR #5825 and its existence check answers no.
- The transcript route answers a non-owner and an unknown id 404 before the change (its `GuardedOwnerOf` handed the owner's name back and the ledger gate then withheld it), and the owner a non-404 answer.

**Inventory, Batch 3 (measured from the compiled classes, public class methods, `%` methods and Base's excluded).** Each store defines no public instance method and no class query of its own; `Extent` is the only query, and the three stream properties are `Entry.ContextJson`, `Entry.StepsJson` and `SqlRun.Answer`, each read through `GuardedStreamText`. Each store also inherits `Base`'s 21 public methods, whose reads Batch 2 split.

- `Turn` (30): owner reads `GuardedDropped`, `GuardedSignals`, `GuardedDefinitionOf`, `GuardedWorkflowOf`, `GuardedForOwner`, `GuardedView`; open reads `GuardedLiveUsers`, `GuardedIsTurnJob`, and the helpers `Cap`, `CitationsArray`, `EgressObject`, `IsTerminal`, `IsoOfSeconds`, `MinuteCeiling`, `NowSeconds`, `SecondsOf`, `Timestamp`; 13 writers.
- `Step` (6): owner read `GuardedRows`; 5 writers. `Nav` (4): owner read `GuardedPending`; 3 writers. `Convo` (9): owner reads `GuardedOwner`, `GuardedOwnerOf`, `GuardedView`, `GuardedScreenRows`, `HistoryMessages`, `LoadOrCreate`; 3 writers. `Entry` (5): owner reads `GuardedRows`, `GuardedTurnKeys`; 3 writers.
- `Pref` (14): owner reads `GuardedListForUser`, `GuardedValue`, `GuardedCountForUser`; administrator read `GuardedUsers`; open helpers `IsShellMember`, `IsThemeValue`; 8 writers. `Sharing` (5): owner read `GuardedForUser`; administrator read `GuardedUsers`; 3 writers. `SqlRun` (9): owner reads `GuardedViewForOwner`, `GuardedCancelRequested`; open helper `IsTerminal`; 6 writers.
- 22 owner reads, 2 administrator reads, 14 open methods (2 reads and 12 helpers) and 44 writers: 82 methods, equal to the compiled set. `UserStateRead.TestTheReadsAreSplitIntoOwnerAdministratorAndOpen` pins the split in both directions and that each read is a probe step.

**Batch 3 after.** `UserStateRead` 16 of 16 (run 272 after the review patches). Product: `Turn.GuardedDropped`, `GuardedSignals`, `GuardedForOwner`; `Step.GuardedRows`; `Nav.GuardedPending`; `Convo.GuardedOwner`, `GuardedOwnerOf`; `Entry.GuardedRows`, `GuardedTurnKeys`; `Pref.GuardedListForUser`, `GuardedValue`, `GuardedCountForUser`, `GuardedUsers`; `Sharing.GuardedForUser`, `GuardedUsers`; `SqlRun.GuardedViewForOwner`, `GuardedCancelRequested` check the caller; `Api/Transcripts.HandleRead` maps a refused `GuardedOwnerOf` or `GuardedTurnKeys` to its 404. The Batch 3 `(loop)` classes are green, each its own run: `TranscriptOwnerWrite` 9, `PrefOwnerWrite` 6, `TranscriptsWire` 7, `TranscriptStore` 5, `TranscriptGate` 8, `ConversationRestore` 4, `Convo` 7, `TurnStore` 11, `TurnWire` 15, `TurnConversation` 11, `TurnNavigate` 15, `TurnLoop` 11, `TurnProviderFault` 6, `PrefState` 17, `PreferencesWire` 12, `AgentPick` 5, `AgentPickTurn` 3, `SqlRunStore` 14, `SqlBackgroundJob` 12, `SqlBackgroundRoutes` 9, `ContextBound` 15, `RemovalRowsSweep` 7, `ProcessControl` 15, `Retention` 10, `DeveloperFloorTurn` 1 (`NavSettleJob` is a fixture with no test method). Also green after the change: `OwnerStateRead` 15, `ReserveSweepWrite` 18, `StoreOwnerWrite` 14, `ProposalConfirm` 24, `ProposalWire` 17, `ProposalCreate` 11, `AnalyticsMdxRead` 15, `AnalyticsMdxJob` 13, `TurnTools` 13, `Restraint` 15, `WorkflowLoop` 10, `ToolDispatch` 19. The turn, tool and proposal classes were re-run after the last product edit, and `ToolDispatch` and `ProposalCreate` once more because their first two runs were sent in one message. `uv run scripts/check-objectscript.py` 0 problems; `uv run scripts/test_check_objectscript.py` 162 tests OK; `node --test tools/ci.test.mjs` 103 pass.

**Mutations, Batch 3 (Rule 19; each applied, observed red in `UserStateRead`, reverted, `git diff` of the file unchanged, reloaded).**

- mutation: the key check removed from `Turn.GuardedDropped` -> `TestADeveloperIsRefusedEveryReadOfAnotherUsersTurn` red at leg 1; from `GuardedSignals` -> leg 2 red.
- mutation: `Turn.GuardedDefinitionOf` or `GuardedWorkflowOf` opens with `GuardedOpenIdAnyCaller` -> the turn test red at leg 3 or leg 4.
- mutation: the user check removed from `Turn.GuardedForOwner` -> `TestADeveloperIsRefusedAReadNamingAnotherUserWhoHoldsNoRow` red at legs 1 and 2 (the turn test stays green, because the open refuses a row that exists). Refusing the developer's own name instead -> `TestARowThatDoesNotExistAnswersAsItDid`, `TestAnOwnerReadsItsOwnRows` and `TestAnAdministratorReadsAnotherUsersRows` red.
- mutation: the key check removed from `Step.GuardedRows` -> the turn test red at leg 7; from `Nav.GuardedPending` -> leg 8 red.
- mutation: the key check removed from `Entry.GuardedRows` -> the conversation test red at legs 5 to 7 and `TestAHeldRowCannotReadAnotherRowsStreamOrConversation` red at leg 4; from `GuardedTurnKeys` -> leg 8 red.
- mutation: the user check removed from `Convo.GuardedOwner` -> the conversation test red at leg 1 and the no-row test red at legs 3 and 4; the key check removed from `GuardedOwnerOf` -> leg 2 red; `GuardedOwnerOf` refusing a key that names no conversation -> `TestARowThatDoesNotExistAnswersAsItDid` red at leg 7.
- mutation: `Convo.LoadOrCreate`'s load branch unchecked -> the conversation test red at leg 4.
- mutation: the user check removed from `Pref.GuardedListForUser` -> the settings test red at legs 1 and 2 and the no-row test at leg 5; from `GuardedValue` -> leg 3 and no-row leg 6; from `GuardedCountForUser` -> leg 4 and no-row leg 7; the administrator check removed from `Pref.GuardedUsers` -> leg 8 red.
- mutation: the user check removed from `Sharing.GuardedForUser` -> the settings test red at leg 5 and the no-row test at leg 8; the administrator check removed from `Sharing.GuardedUsers` -> leg 9 red.
- mutation: the user check removed from `SqlRun.GuardedViewForOwner` -> the no-row test red at leg 9; the key check removed from `GuardedCancelRequested` -> the settings test red at leg 7.
- mutation: `Turn.GuardedLiveUsers` or `GuardedIsTurnJob` refuses a non-administrator -> `TestTheOpenReadsStayOpen` red.
- mutation: `Api/Transcripts.HandleRead` stops mapping a refused `GuardedOwnerOf` -> `TestTheTranscriptRouteAnswersANonOwnerItsNotFound` red (500 for 404). Its mapping of a refused `GuardedTurnKeys` has no leg: that call follows an owner or administrator answer for the same key, so only a race reaches it (deferred).
- mutation: `Convo.GuardedScreenRows` selects every user's rows and opens them without the caller check -> `TestTheTranscriptListIsScopedToTheCaller` red. Either change alone stays green.
- mutation: `Base.GuardedOpenId` reads `OWNERWRITE` from the class called -> `TestADeveloperIsRefusedEveryOpenOfAnotherUsersRowThroughBase` red at its open legs.
- mutation: the stored-stream comparison removed from `Base.GuardedStreamText` -> `TestAHeldRowCannotReadAnotherRowsStreamOrConversation` red, handing back the victim's step and answer.
- mutation: a public method added to `Pref` that no list names -> `TestTheReadsAreSplitIntoOwnerAdministratorAndOpen` red.
- mutation: the administrator exemption removed from `Base.OwnerWriteRefused` -> all 15 tests red at their seeding.

**Code review, Batch 3 (2026-11-17, `ocupilot-ci`).**

- Measured as the developer principal: a directive whose turn row was gone (`Nav.GuardedPending` on the key) was handed back to a non-owner; a step or entry whose parent was gone was not. `Nav.GuardedPending` now asks `OwnerWriteRefused` of the row it opened. `UserStateRead` 16 of 16; `TurnNavigate` 15, `TurnStore` 11, `TurnWire` 15, `TurnConversation` 11, `TurnLoop` 11, `DeveloperFloorTurn` 1, `TranscriptOwnerWrite` 9, `ReserveSweepWrite` 18 and `OwnerStateRead` 15 green; `check-objectscript.py` 0 problems.
- mutation: the owner check removed from `Nav.GuardedPending` (the tree before the patch) -> `TestAnOrphanedChildRowOfAnotherUserIsNotHandedBack` red at leg 2.
- mutation: the per-row open of `Step.GuardedRows` or `Entry.GuardedRows` made through `GuardedOpenIdAnyCaller` -> the same test red at leg 1, or at legs 3 and 4.
- mutation: `Convo.GuardedScreenRows` gives every row a title (`If tUser = tCaller` replaced by `If 1`) -> `TestTheTranscriptListIsScopedToTheCaller` red at its no-victim-title assertion.
- mutation: the `UserStateRead` line removed from `scripts/ci-throwaway.sh` -> `ui/tools/ci.test.mjs` "each arming roster names exactly the classes that declare that variable" red (102 of 103 pass).

## Auto Run Result

Status: done
Blocking condition: none

This pass built Batch 3 (DW-2652: transcripts and settings). Batch 1 (DW-2651) closed in its own pass (Code review, Batch 1 under Verification); Batch 2 (proposals, ledger, `Base`'s reads) closed in its pass (Code review, Batch 2 under Verification).

- **Change.** `Turn.GuardedDropped`, `GuardedSignals`, `GuardedForOwner`; `Step.GuardedRows`; `Nav.GuardedPending`; `Convo.GuardedOwner`, `GuardedOwnerOf`; `Entry.GuardedRows`, `GuardedTurnKeys`; `Pref.GuardedListForUser`, `GuardedValue`, `GuardedCountForUser`; `Sharing.GuardedForUser`; `SqlRun.GuardedViewForOwner`, `GuardedCancelRequested` refuse a caller who is neither the owner nor an administrator with 822. `Pref.GuardedUsers` and `Sharing.GuardedUsers` serve an administrator only. `Turn.GuardedLiveUsers` and `GuardedIsTurnJob` stay open. `Api/Transcripts.HandleRead` answers its 404 for a refused `GuardedOwnerOf` or `GuardedTurnKeys`.
- **Files.** `src/OcuPilot/Kernel/State/{Turn,Step,Nav,Convo,Entry,Pref,Sharing,SqlRun}.cls`, `Api/Transcripts.cls`, `scripts/ci-throwaway.sh` (add-only), new `Test/UserStateRead` and `Test/UserStateReadProbe`.
- **Review (Batch 3).** 13 findings: 2 medium and 2 low patched, 3 low deferred, 2 low and 4 descriptive items rejected. Details in the triage log. The patched medium finding that mattered: a directive whose turn row was gone was handed to a non-owner by `Nav.GuardedPending`.
- **Follow-up review recommended: true.** Two medium entries were patched. The unverified risk: another read among the eight stores that opens its row through a private by-key open after a parent-key check, as `Nav` did. `Turn`, `Pref`, `Sharing` and `SqlRun` check the user or the key themselves, and `Step` and `Entry` open each row through the gated open; no leg opens a held or orphaned row of the other stores.
- **Verification.** `LOADERRORS=0`; `UserStateRead` 16 of 16; the Batch 3 `(loop)` list green, each class its own run (run again after the last product edit: `UserStateRead`, `TurnNavigate`, `TurnStore`, `TurnWire`, `TurnConversation`, `TurnLoop`, `DeveloperFloorTurn`, `TranscriptOwnerWrite`, `ReserveSweepWrite`, `OwnerStateRead`); `check-objectscript.py` 0 problems; harness 162 tests; `ci.test.mjs` 103 pass; `lint-docs.sh` 0 issues. Task 0, the inventory and the mutations are under Verification.
- **Residual.** Three low items are deferred (the `GuardedTurnKeys` 404 mapping, the orphaned-conversation turn keys, the one-at-a-time pin of the transcript list's two defences), and one inference: the extra escalated read on a non-administrator's `GuardedSignals`. The `(once)` sweep, smoke and fresh check are the runner's.
