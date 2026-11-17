---
title: "Story 21.30: OcuPilot's guarded storage refuses a caller that is not an administrator"
type: 'bugfix'
created: '2026-11-16'
status: 'done'
baseline_revision: '292fd716c7d97db50be9b1c99507603344f051e1'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
deferred:
  - summary: "Kernel.State stores outside this story's four still escalate any caller's public guarded write: Agent definitions (instructions, provider, credential name), and other users' Ledger, Propose, Turn, Convo and Pref rows."
    evidence: "Base.GuardedSave and GuardedSaveIfCurrent escalate whatever object they are handed; Api/Definitions checks IsAdministrator above Agent.GuardedCreate/GuardedUpdate/GuardedDeleteId, but ProviderPort.cls:187 writes Agent.GuardedClearVerification during a turn, so ADMINWRITE cannot simply be set on Agent."
    location: 'src/OcuPilot/Kernel/State/Agent.cls; src/OcuPilot/Kernel/State/Base.cls:183'
    severity: high
  - summary: "Switch.GuardedRecordWritesMarked admits any caller, so a %Development holder can set the observed marking fact and hide or show the unmarked-writes banner (AD-15)."
    evidence: "The confirm executor, screen actions and the restraint read record the observation as the calling user, who is usually not an administrator; the banner makes no positive claim either way."
    location: 'src/OcuPilot/Kernel/State/Switch.cls'
    severity: low
---

<intent-contract>

## Intent

**Problem:** `Switch.SetGuarded`, `Egress.SetGuarded`, `Hold`'s writers and `Policy.GuardedApply` escalate through the `OcuPilotState` privileged routine application for any caller, and `Base`'s public `GuardedSave` and `GuardedSaveIfCurrent` save any object handed to them. Code a `%Development` holder runs directly can therefore rewrite the kill switch, a per-user hold, the outbound settings or a governance key without holding `OcuPilotAdmin` (DW-2634). Only the API routes check `IsAdministrator`.

**Approach:** First reproduce the rewrite end to end as a real non-administrator principal. Then make the four administrator-owned stores refuse a non-administrator write in the store itself, in the caller's own process, before any escalation. The check is the same predicate the routes use. One narrow writer keeps the observed marking fact open to every caller.

## Boundaries & Constraints

**Always:**

- The check runs unescalated, before `New $ROLES` and `AddRoles`, and reads `$System.Security.Check("OcuPilotAdmin", "USE")`, which is the same predicate as `Api.Definitions.IsAdministrator`.
- A refused call changes nothing and returns `$$$ERROR($$$AccessDenied)` (vendor `ERROR #822: Access Denied`). No new OcuPilot string.
- Every legitimate caller in the Code Map's inventory still works.
- `New $ROLES` stays only in `Base.cls`. AD-9's frame and ordering rules hold.

**Never:**

- Do not edit the spine. The AD-9 text goes under Design Notes for the spec gate.
- Do not gate reads, `GuardedProbeSet` or the per-user stores.
- Do not let a `Kernel/State` file reference `OcuPilot.Api` or `OcuPilot.Screen`.
- Do not use a `..#ADMINWRITE` reference inside an escalating `Base` method. Read it with `$Parameter(<class>, "ADMINWRITE")`, so the inherited code stays in `Base`'s routine, which is the one the application admits (inference).
- Do not run anything on `ocupilot`. Do not add a second throwaway.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Developer, entry points | Child process as a principal holding `%Development:USE` and code read, without `OcuPilotAdmin` | `Switch.SetGuarded`/`DeleteGuarded`, `Hold.GuardedCreate`/`GuardedDeleteId`/`DeleteAllGuarded`, `Egress.SetGuarded`/`DeleteGuarded`, `Policy.GuardedApply`/`DeleteAllGuarded` each refuse, and the stored state is unchanged | Status code 822 |
| Developer, bypass | Same child opens the row with the public `GuardedOpenId`, edits it, then calls `Base.GuardedSave` and `Base.GuardedSaveIfCurrent` | Both refuse; the row is unchanged | Status code 822 |
| Administrator | Child as a principal holding `OcuPilotAdmin:USE` and code read only, no `%All` | Kill switch and one governance key written | No error expected |
| Marking observation | Developer child, `Event.RecordMarking(<not the stored value>)` | `writesMarked` changes; every other switch field and the version of the rest stay as they were | No error expected |
| Routes | Existing route tests (`SwitchesWire`, `GovernanceWire`, `EgressSettingsWire`, `ConfigGate`) | Unchanged behavior | Existing |

</intent-contract>

## Code Map

- `src/OcuPilot/Kernel/State/Base.cls` -- the one escalation point. `GuardedSave:183` and `GuardedSaveIfCurrent:218` are public and escalate whatever object they receive. `ADMINRESOURCE:108`. Other public methods (`GuardedOpenId`, `GuardedExistsId`, `GuardedStoredValue`, `GuardedProbeSet`/`Get`, the identity and SSL reads, `GuardedRolesSnapshot*`) write no store row.
- `src/OcuPilot/Kernel/State/Switch.cls` -- `SetGuarded:165`, `DeleteGuarded`. `WritesMarked` is an observed fact, not set by an operator.
- `src/OcuPilot/Kernel/State/Hold.cls` -- the per-user kill switch (FR-20). `GuardedCreate:80` goes through `GuardedSaveIfCurrent`; `GuardedDeleteId:105` and `DeleteAllGuarded:153` go through the private executes.
- `src/OcuPilot/Kernel/State/Egress.cls` -- `SetGuarded:116`, `DeleteGuarded`.
- `src/OcuPilot/Kernel/State/Policy.cls` -- `GuardedApply:73`, which deletes inherited keys through `GuardedExecuteOneParam`; `DeleteAllGuarded`.
- `src/OcuPilot/Kernel/Audit/Event.cls:324` -- `RecordMarking` calls `Switch.SetGuarded` with `writesMarked`.
- `src/OcuPilot/Api/Definitions.cls:1337` -- `IsAdministrator` is `$System.Security.Check` via `Screen.Gate.HoldsPrivilege:570`. `ADMINPERMISSION:34`.
- **Caller inventory.** Measured by grep over `src/`, tests excluded:
  - `Api/Switches` reaches `HandleUpdate:130` (Switch), `HandleHoldCreate:213` and `HandleHoldDelete:265` (Hold), and `HandleEgressUpdate:345` (Egress). Each sits behind `IsAdministrator`, so an administrator passes the store check.
  - `Api/Governance:43,71` (Policy) sits behind `IsAdministrator`.
  - `RecordMarking`'s callers: `Install/Installer:3622`, `Area/Security/AuditEventSave:315`, `Api/Switches:613` (the restraint read every user makes), `Api/ScreenAction:479`, and `Kernel/Proposal/Confirm:480,503`. They usually run as a non-administrator. They move to the narrow writer.
  - The turn, agent and context paths (`Kernel/Restraint`, `Api/Context`, `Api/Turn`, `Kernel/Governance/Policy:150`) only read. No `Screen/Tool` or `Area` class writes these stores.
  - The installer and start path write only through `RecordMarking`.
  - Epic 24's consoles (24.6, 24.7) are not on any branch yet. They will run code with the person's rights, so a non-administrator's call is refused with 822.
  - About 30 test classes write these stores directly, for example `SwitchFixture`, `GovernanceFixture`, `SwitchState`, `State`, `Egress*`, `TurnContext` and `ProposalConfirm`. All of them run as the suite identity, which holds `%All` and passes. No test writes them as an impersonated principal: grep of `Login` frames finds only `State` and `InteropEditorSaveGate`, and neither writes inside the frame.
- `src/OcuPilot/Test/State.cls:616` -- `TestEscalationIsWhatGrantsTheDeniedUserAccess` escalates through `GuardedProbeSet`, which is not an administrator-owned store.
- `src/OcuPilot/Test/DeviceWriteGate.cls:244` and `JournalProbe.cls:209,597` -- the sibling run-as pattern: a `JOB` child that calls `$SYSTEM.Security.Login(user)` and signals JSON, plus `SeedPrincipal`. `scripts/check-objectscript.py` rule 6 bans `New $ROLES` outside `Base` and `Test/State`, so impersonation goes through a child process.
- **Contention.** `git log origin/OCU-1-epic24 ^origin/feature/OCU-1_ocupilot-mvp` is empty for every file this story edits: `Base`, `Switch`, `Hold`, `Egress`, `Policy`, `Audit/Event`, `Api/Definitions` and `Test/State`. The `epic-24` worktree's uncommitted files touch none of them. Epic 22 has no branch or worktree.

## Tasks & Acceptance

**Execution:**

- Task 0, the reproduction (DW-2634). Run it before any product edit.
  - Write the two test classes below with no product change. Reload them into `ocupilot-ci` and run `OcuPilot.Test.AdminStateWrite`.
  - Expected: the developer tests go red because the writes landed. The child reports `$Username`, `$Roles`, `$System.Security.Check("OcuPilotAdmin","USE")=0` and a control direct `UPDATE OcuPilot_Kernel_State.SwitchState` with a negative `SQLCODE`. Each guarded call answers OK, and the parent reads the changed kill switch, hold, proxy and key.
  - Record that evidence under `## Verification` as "Task 0 (pre-fix)".
  - If the writes do not land end to end, HALT `blocked`: `Task 0: attack did not reproduce: <evidence>`. Build nothing. A failed `Login` is a harness fault, so fix that instead.
- `src/OcuPilot/Test/AdminStateWriteProbe.cls` (new, extends `%RegisteredObject`) -- the child entry `Run(pParent, pUser, pPlan)`. It works like `DeviceWriteGateProbe`. It logs in, runs the plan's named calls (including the bypass legs), and signals each status code, `$Username` and `$Roles`.
- `src/OcuPilot/Test/AdminStateWrite.cls` (new). It is armed by `OCUPILOT_ALLOW_PRINCIPALS` and uses `RunAs` as in `DeviceWriteGate`. It has two principals, each holding the install namespace's routines and globals database read: `OcuPilotAdminWriteDev` with `%Development:USE`, and `OcuPilotAdminWriteAdmin` with `OcuPilotAdmin:USE`. Setup reads each grant back with `CheckUserPermission`, and teardown deletes them. Each test snapshots the switch row, holds, egress row and policy (`GovernanceFixture`) and restores them, asserting the restore. Tests: one per matrix row, plus `TestTheAdministratorStoresAreDeclared`. That test checks two rosters: the classes whose compiled `ADMINWRITE` is 1 equal `{Switch, Hold, Egress, Policy}`, and each one's own public class methods equal a declared reads/writes split. Every write in that split is called by a refusal test.
- `src/OcuPilot/Kernel/State/Base.cls` -- add `Parameter ADMINWRITE As %Boolean = 0`, `Parameter ADMINPERMISSION = "USE"`, `CallerIsAdministrator()` and `AdminWriteRefused(pClassName) As %Status`. The last one checks `$Parameter(pClassName,"ADMINWRITE")`, then the caller, and returns `$$$AccessDenied`. Call it first in `GuardedSave` and `GuardedSaveIfCurrent`, on `pObject.%ClassName(1)`. Move `GuardedSaveIfCurrent`'s escalated body to a `[ Private ]` `GuardedSaveIfCurrentAnyCaller`, which the public method calls after its check.
- `src/OcuPilot/Kernel/State/Switch.cls`, `Hold.cls`, `Egress.cls`, `Policy.cls` -- set `Parameter ADMINWRITE = 1`. Call `AdminWriteRefused` first in every public writer: `SetGuarded`, `DeleteGuarded`, `GuardedCreate`, `GuardedDeleteId`, `DeleteAllGuarded` and `GuardedApply` (before `TSTART`). Add `Switch.GuardedRecordWritesMarked(pMarked)`, which writes `WritesMarked` and `UpdatedAt` only, through `GuardedSaveIfCurrentAnyCaller`. Its doc comment says that any caller may write it.
- `src/OcuPilot/Kernel/Audit/Event.cls` -- `RecordMarking` calls `Switch.GuardedRecordWritesMarked`. Its write-nothing-when-unchanged rule and its never-propagates rule stay.
- `src/OcuPilot/Api/Definitions.cls` -- `IsAdministrator` returns `##class(OcuPilot.Kernel.State.Base).CallerIsAdministrator()`. `RenderForbidden` reads `Base`'s `ADMINPERMISSION`, and Definitions' own parameter is deleted.
- `src/OcuPilot/Test/State.cls` -- keep `TestEscalationIsWhatGrantsTheDeniedUserAccess`'s assertions. Add one doc sentence: the four administrator-owned stores are the exception, pinned by `AdminStateWrite`.

**Acceptance Criteria:**

- Given the unfixed tree on `ocupilot-ci`, when Task 0 runs, then the developer principal's guarded rewrite of the kill switch and of a governance key lands, and the evidence is recorded.
- Given the fix, when the developer principal makes the same calls and the bypass calls, then each returns code 822 and the stored switches, holds, egress row, policy and their versions are unchanged.
- Given the fix, when the administrator principal (no `%All`) writes the kill switch and a key, then both are stored.
- Given a non-administrator confirm, screen action or restraint read, when it records the marking observation, then `writesMarked` is stored.
- Given `AdminWriteRefused` mutated to return `$$$OK`, when `AdminStateWrite` runs, then only its refusal tests go red.

### Review Findings

Code review of `3df69e648` (2026-11-16). Every write was measured as the developer principal on `ocupilot-ci`.

- [x] [Review][Patch] (high) `Base.GuardedStoredValue` is public and ran the caller's `pExistsMethod` by `$ClassMethod` inside the escalated frame, private methods included. The developer principal rewrote the kill switch through `GuardedStoredValue("GuardedExecuteOneParam", "UPDATE ...SwitchState SET KillSwitch = 1 ...")`, version unchanged (run 87, both legs `ok=1`). It now answers `$$$AccessDenied` before escalating unless the names are `<index>Exists` for a compiled index of the class and a compiled property. The kill-switch test carries two bypass legs. [src/OcuPilot/Kernel/State/Base.cls:492]
- [x] [Review][Patch] (high) `Switch.GuardedRecordWritesMarked` saved the whole row object, and `%OpenId` hands back the caller's held, edited copy. The developer principal held the row with its kill switch changed and called `Event.RecordMarking`, which stored the kill switch (run 88). An existing row is now written by one `UPDATE` of `WritesMarked`, `UpdatedAt` and `RowVersion`. The marking test holds an edited row across the call. This also closes the Rule 31 near-copy of `SetGuarded`. [src/OcuPilot/Kernel/State/Switch.cls:224]
- [x] [Review][Patch] (medium) The roster test read each store's own methods only, so a public method inherited from `Base` went unseen; that is how the first finding passed. `Base`'s public class methods now equal `BaseSurface`'s declared reads and refused saves. [src/OcuPilot/Test/AdminStateWrite.cls:276]
- [x] [Review][Patch] (low) The kill-switch test took `PlanKinds("switch")` by index; it now loops like the other two. [src/OcuPilot/Test/AdminStateWrite.cls:145]
- [x] [Review][Patch] (low) The probe ran its plan after a failed login, as the suite's `%All` identity. It now signals `error` and runs no step. [src/OcuPilot/Test/AdminStateWriteProbe.cls:15]
- [x] [Review][Patch] (low) `OnAfterOneTest` discarded the status of the per-user row's delete; it is asserted now. [src/OcuPilot/Test/AdminStateWrite.cls:124]
- [x] [Review][Patch] (low) AC5's mutation line predated the seventh test; re-run as run 90 and rewritten under Verification.
- Correction: the Code Map's "Other public methods (... `GuardedStoredValue` ...) write no store row" and the earlier triage's "Private helpers ... reachable only from Base or a subclass" were false before this pass (run 87). Both are true of the patched tree.

Rejected:

- (low) `GuardedRecordWritesMarked` stores any value, so a developer can hide the unmarked-writes banner. This is the spec's named exception, ledgered as DW-2639; narrowing it edits the intent.
- (low) `SetGuarded` still accepts a `writesMarked` value. Only an administrator reaches it now, and the route writes back the value it read.
- (low) `Convo.cls:169`, `Audit/Ledger.cls` and `Screen/Gate.cls` keep their own `OcuPilotAdmin:USE` checks. Their predicate is the same; nobody meets a divergence unless the permission changes.
- (low) `RunAs` copies the run-as harness of about 20 sibling classes. The stated reason (a different probe class) is weak, but unifying them is not a direct correction.
- (low) The class is 683 lines against the roughly 500-line guideline; unchanged from the earlier triage.
- (low) The real administrator drives 2 of the 11 refused writes. Every writer makes the same `AdminWriteRefused($ClassName())` call, so a writer-specific false refusal is theoretical.
- (low) A timed-out probe child can signal late into the next test's wait. It needs a run over 120 seconds; the fix adds a branch.
- (low) `OnBeforeOneTest` or `EnsurePrincipals` failing midway skips the restore or leaves the two principals. It is unlikely on a throwaway, and the fix adds branches.
- (low) The early check in `Switch.SetGuarded`, `Egress.SetGuarded`, `Hold.GuardedCreate` and `Policy.GuardedApply` cannot be told apart by a test, because their saves refuse too. The spec requires them, and they keep the read escalation behind the check.
- (low) AC4's callers are not driven as non-administrators. Every one reaches the writer through `RecordMarking`, which the matrix row names and the test drives.

## Spec Change Log

## Review Triage Log

### 2026-11-16 -- Review pass

- verdicts: 11 findings -- high 0, medium 1, low 4, false 6, maybe-false 0
- findings:
  - `[low]` `[patch]` AC3's pinning test had no `mutation:` line -- added the `%All:USE` mutation, red alone on `TestAnAdministratorWritesTheKillSwitchAndAKey` (run 83), line written under Verification and in the test's doc comment.
  - `[medium]` `[patch]` No test showed a non-administrator still saving a store that is not administrator-owned, so an over-broad refusal in `Base` would ship green -- added `TestADeveloperStillWritesAStoreThatIsNotAdministratorOwned` (a `Pref` row created and updated through both public saves) and its mutation (run 84 red alone).
  - `[low]` `[patch]` Read legs compared state without asserting the read succeeded, and a failed fingerprint read compared equal to itself -- `AssertDeveloperLegs` asserts each read's `ok`, and `AssertStoresUnchanged` refuses a `failed]` reading.
  - `[low]` `[reject]` `AdminStateWrite.cls` is about 625 lines against the roughly 500 guideline -- a split is more than a direct correction and nobody meets it in everyday use.
  - `[false]` `[reject]` `## Auto Run Result` reads `ready-for-dev` while the frontmatter says `in-review` -- finalize writes both, and does here.
  - `[false]` `[reject]` Routes are not exercised over HTTP by the new tests -- the existing `SwitchesWire` (run 71), `GovernanceWire` (74), `EgressSettingsWire` (77) and `ConfigGate` (75) run green against the changed stores.
  - `[false]` `[reject]` The open writer's callers are not driven as developers -- `MarkingRestraint` (73), `ProposalConfirm` (76), `Installer` and `Demo` run green; only the gate's own surface is new.
  - `[false]` `[reject]` `IsAdministrator` no longer goes through the overridable `Gate.HoldsPrivilege` -- grep finds no test overriding it to drive `IsAdministrator`; `ConfigGate` and `AgentWireSecurity` only mention it in comments.
  - `[false]` `[reject]` `Installer` and `Fixture` call `Base.GuardedSave` on other classes -- those declare no `ADMINWRITE`, so they pass through; `Installer`, `Demo` and `PrefState` run green.
  - `[low]` `[reject]` Private helpers in `Base` carry no check -- reachable only from `Base` or a subclass, and the Design Notes put code that can change the install namespace's classes outside this rule.
  - `[false]` `[reject]` Task 0's evidence is not in the diff -- it is recorded under `## Verification`.

## Design Notes

**Governing ADs:** AD-9 (escalation and its ordering rules), AD-8 (privilege checked at call time, in the caller's process), AD-30 (kill switch and read-only at the point of effect), AD-22 (governance policy store), AD-32 (egress settings), AD-15 (the marking fact), AD-10 (24.6's proposed console sentence relies on this fix).

**AD amendment for the spec gate.** This amends AD-9. Proposed text, appended to AD-9's Rule after the third purpose:

> **The privileged routine application admits any caller of `Base`'s code, so a store, not a route, is its state's last gate** [AMENDED 2026-11-16, Story 21.30, owner answer U-79, DW-2634]. The stores holding OcuPilot's administrative state are the agent switches, the per-user holds, the outbound settings and the governance policy (`ADMINWRITE`). They refuse a write from a caller who does not hold `OcuPilotAdmin:USE` with `ERROR #822` and change nothing. The check is made in the caller's process before any escalation, and it covers every public writer of those stores and `Base`'s public object saves. It is the predicate `Api.Definitions.IsAdministrator` reads, held once in `Base.CallerIsAdministrator`. One named exception: the observed `writesMarked` fact (AD-15) is recorded by any caller through `Switch.GuardedRecordWritesMarked`. Code that can write the install namespace's code database can change these classes, which is outside this rule.

**Decided in-stage:**

- Scope covers four stores: Switch, Hold (FR-20's per-user kill switch), Egress (the DW's "SetGuarded" also names `Egress.SetGuarded`; same administrator route) and Policy. Agent definitions have a non-administrator writer (`ProviderPort:187`), so they go to the frontmatter `deferred:` list rather than into this story.
- The refusal is the vendor's `$$$AccessDenied`, so the story adds no user-facing string.
- Impersonation runs in a `JOB` child, as in `DeviceWriteGate`, because rule 6 confines `New $ROLES` to `Base` and `Test/State` and keeps `Test/State` near its size. The child is a fresh process logged in as the principal, the same shape as a terminal process after login (inference).
- `IsAdministrator` delegates to `Base`, so the route and the store read one predicate (Rule 2: extend the existing predicate rather than copy it).
- `TestEscalationIsWhatGrantsTheDeniedUserAccess` keeps its meaning: the escalation still opens state for any caller of a non-administrator store.
- The plan stage found `spec-21-13-ddl-mappings.md`, `Test/DdlMappingRules.cls` and `Test/DdlMappingWrite.cls` modified in this worktree. They belong to Story 21.13's concurrent review. This stage wrote only this spec and touched nothing else.

**Integration ACs:** the consumers are `Api/Switches`, `Api/Governance` and `Kernel/Proposal/Confirm` (through `RecordMarking`), each still covered by its own wire suite. `Consumes:` `Kernel/State/Base`. `Consumed-by:` Stories 24.6 and 24.7. Their consoles rely on the store refusing a non-administrator.

## Verification

**Shared surfaces:** `Base`'s public write primitives (their behavior for a non-administrator), the writer of `Switch.WritesMarked` (`MarkingRestraint`, `SwitchesWire`), `Api.Definitions.IsAdministrator` (`ConfigGate`, `AgentWireSecurity`), and the `ADMINWRITE` store roster. *Every test added or changed passes on a fresh environment, in either order.*

**Commands.** Run one command per foreground call, with `timeout: 600000`, against `ocupilot-ci` only. Never put two test calls in one message.

- `(loop)` `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/b708a79b-b765-42ec-adea-dbc87acf6251/scratchpad/e21u/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` -- expected: `LOADERRORS=0`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.AdminStateWrite` -- expected: red at Task 0, green after the fix.
- `(loop)` The same command, one class per call, for `State`, `SwitchState`, `MarkingRestraint`, `SwitchesWire`, `Governance`, `GovernanceWire`, `EgressSettingsWire`, `Egress`, `ConfigGate`, `AgentWireSecurity` and `ProposalConfirm` -- expected: green.
- `(loop)` `uv run scripts/check-objectscript.py`, `uv run scripts/test_check_objectscript.py`, and `bash scripts/lint-docs.sh _bmad-output/implementation-artifacts/spec-21-30-ocupilot-s-guarded-storage-refuses-a-caller-that-is-not-an-a.md` -- expected: 0 problems.
- `(once)`, owned by the runner: the full ObjectScript sweep, one class per call; `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS`; and Rule 30's fresh check. No browser spec is touched, so the browser suite is left to CI.

**Task 0 (pre-fix), `ocupilot-ci`, unchanged product, run 25 of `OcuPilot.Test.AdminStateWrite`: the attack landed.** The child ran as `OcuPilotAdminWriteDev` (login 1), `$Roles` = `OcuPilotAdminWriteDevRole`, `OcuPilotAdmin:USE` = 0, `%Development:USE` = 1, no `%All`. The control, a direct `UPDATE OcuPilot_Kernel_State.SwitchState`, answered `SQLCODE=-99`. Each guarded call then answered OK (`ok=1`, no code), and the principal's own read-back moved:

- Kill switch: `0||0|1|v1` -> `SetGuarded` -> `1|rewritten by a developer|0|1|v2` -> public `GuardedOpenId` + `Base.GuardedSave` -> `1|saved through Base.GuardedSave|0|1|v2` -> `Base.GuardedSaveIfCurrent` -> `...|v3` -> `DeleteGuarded` -> `0||0|1|v0` (row gone).
- Holds: `ids 671` -> `GuardedCreate` -> `ids 671,672` -> `GuardedDeleteId` -> `ids 672` -> `DeleteAllGuarded` -> no ids.
- Egress: `kept.example.invalid|8080|v1` -> `SetGuarded` -> `proxy.invalid|3128|v2` -> `DeleteGuarded` -> `|0|v0`.
- Policy: `OcuPilotProbeKeyA=enabled;preset=full;v1` -> `GuardedApply` -> `...KeyB=disabled;preset=read-only;v2` -> `DeleteAllGuarded` -> `v0`.
- The parent's SQL read of the four tables after each test showed the switch row, holds, settings and policy gone or rewritten. The administrator and marking tests were green; the roster test was red (no `ADMINWRITE`).

**Mutations (Rule 19).** Apply each one, observe red, revert, confirm the tree is identical with `git status --short` and `git diff --stat`, then reload.

- `AdminWriteRefused` returns `$$$OK` -> the three developer tests go red; the administrator, marking and roster tests stay green.
  - mutation: `AdminWriteRefused` answers `$$$OK` first -> run 90: 3 of 7 red (the kill-switch, hold and egress-and-policy developer tests); the administrator, marking, roster and per-user tests green; reverted (md5 identical), reloaded.
- The check is removed from the public `GuardedSaveIfCurrent` alone -> the bypass legs of the kill-switch test go red alone.
  - mutation: `GuardedSaveIfCurrent`'s `AdminWriteRefused` line replaced by `Set tSC = $$$OK` -> 1 of 6 red, `TestADeveloperIsRefusedTheKillSwitchAndTheBypass`, on the `Base.GuardedSaveIfCurrent` leg; reverted, reloaded.
- The check is removed from `Hold.GuardedDeleteId` alone -> the hold-delete leg goes red alone.
  - mutation: `Hold.GuardedDeleteId`'s check line deleted -> 1 of 6 red, `TestADeveloperIsRefusedTheHoldWrites`, on the `Hold.GuardedDeleteId` leg; reverted, reloaded.
- `RecordMarking` goes back to `Switch.SetGuarded` -> the marking test goes red alone.
  - mutation: `RecordMarking` calls `Switch.SetGuarded` with `writesMarked` -> 1 of 6 red, `TestAnyCallerRecordsTheMarkingObservation`; reverted, reloaded.
- `Parameter ADMINWRITE = 1` set to 0 on `Policy` (the roster test's own mutation).
  - mutation: `Policy` `ADMINWRITE` = 0 -> 2 of 6 red, `TestTheAdministratorStoresAreDeclared` and the egress-and-policy developer test; reverted, reloaded.
- `CallerIsAdministrator` checks `%All:USE` instead (AC3).
  - mutation: `CallerIsAdministrator` reads `$System.Security.Check("%All", "USE")` -> run 83: 1 of 7 red, `TestAnAdministratorWritesTheKillSwitchAndAKey`, alone; reverted from a saved copy (md5 identical), reloaded.
- `AdminWriteRefused` refuses a class that does not declare `ADMINWRITE`.
  - mutation: the not-`ADMINWRITE` branch answers `$$$AccessDenied` -> run 84: 1 of 7 red, `TestADeveloperStillWritesAStoreThatIsNotAdministratorOwned`, alone; reverted (md5 identical), reloaded, run 85 green.

- `GuardedStoredValue` runs the caller's method name unchecked (the pre-review `Base`).
  - mutation: the two name checks absent -> run 87: 1 of 7 red, `TestADeveloperIsRefusedTheKillSwitchAndTheBypass`, on both `Base.GuardedStoredValue` legs and the switch reads; patched, run 89 green.
- `GuardedRecordWritesMarked` saves the row object (the pre-review `Switch`).
  - mutation: the pre-review writer restored -> run 88: 1 of 7 red, `TestAnyCallerRecordsTheMarkingObservation` ("every other switch field is as it was"); restored, reloaded, run 89 green.
- A public class method added to `Base` and not declared.
  - mutation: `GuardedMutationProbe()` added -> run 92: 1 of 7 red, `TestTheAdministratorStoresAreDeclared`, alone; reverted (md5 and diff stat identical), reloaded, run 93 green.

Each mutation was reverted by restoring the saved copy; `git status --short` and `git diff` hashes matched the pre-mutation values, and `LOADERRORS=0` followed each reload.

**After the fix, `ocupilot-ci`:** `AdminStateWrite` 6 of 6 green (run 69), then 7 of 7 (run 85) after the review pass added a seventh test. The `(loop)` classes `State`, `SwitchState`, `MarkingRestraint`, `SwitchesWire`, `Governance`, `GovernanceWire`, `EgressSettingsWire`, `Egress`, `ConfigGate`, `AgentWireSecurity` and `ProposalConfirm` are green, one class per call, as are the classes that call the changed writers or `Base`'s saves: `AgentState`, `ContextBound`, `TurnContext`, `Guardrails`, `EgressLine`, `EgressLocal`, `ProviderSslNamed`, `ProviderSslCallTime`, `ProviderSslCallers`, `ProviderPort`, `ProviderProxy`, `TurnWire`, `TurnHourLimit`, `TurnGrounding`, `TurnProviderFault`, `Version`, `UninstallGuard`, `UninstallResidue`, `Installer`, `Demo`, `DemoFaults`, `AuditEventEditor`, `AuditingScreen`, `AuditingUpdate`, `StampRetention` and `PrefState`. `uv run scripts/check-objectscript.py`: 0 problems over 2342 files; `uv run scripts/test_check_objectscript.py`: 152 tests OK; `ui/tools/ci.test.mjs` (103) and `ci-shards.test.mjs` (33) green after `AdminStateWrite` joined the `OCUPILOT_ALLOW_PRINCIPALS` roster in `scripts/ci-throwaway.sh`. Both probe users and roles read absent after the last run.

**Runner ruling at the spec gate (2026-11-16):** the AD-9 amendment above is written into the spine (comply first under U7; the orchestrator is asked). Scope stays the four stores; the frontmatter deferrals are ledgered as DW-2638 (high, decision-pending for the orchestrator) and DW-2639 (low, the named exception). DW-2634 (Epic 24's ledger) is the source.

## Auto Run Result

Status: done
Blocking condition: none

**Task 0 result: the attack landed** on the unchanged product (evidence under `## Verification`, run 25).

**Change.** The four administrator-owned stores (`Switch`, `Hold`, `Egress`, `Policy`) declare `ADMINWRITE = 1`. `Base.AdminWriteRefused` runs first, in the caller's process, in every public writer and in `Base`'s public `GuardedSave` and `GuardedSaveIfCurrent`, and answers `$$$AccessDenied` (822) to a caller without `OcuPilotAdmin:USE`. `Switch.GuardedRecordWritesMarked` stays open to every caller, and `Event.RecordMarking` uses it. `Api.Definitions.IsAdministrator` answers from `Base.CallerIsAdministrator`.

**Files.**

- `src/OcuPilot/Kernel/State/Base.cls`: the predicate, the refusal, and the private any-caller save.
- `src/OcuPilot/Kernel/State/Switch.cls`, `Hold.cls`, `Egress.cls`, `Policy.cls`: the parameter and the check in each writer.
- `src/OcuPilot/Kernel/Audit/Event.cls`, `src/OcuPilot/Api/Definitions.cls`, `src/OcuPilot/Test/State.cls`: the narrow writer, the shared predicate, one doc sentence.
- `src/OcuPilot/Test/AdminStateWrite.cls`, `AdminStateWriteProbe.cls` (new): the real-principal suite, 7 tests.
- `scripts/ci-throwaway.sh`: the arming roster lists the new class.

**Review.** 11 findings: 3 patched (1 medium, 2 low), 8 rejected with reasons in the triage log, none deferred. Follow-up review recommended: false (one medium patched, no high).

**Verification.** `AdminStateWrite` 7 of 7 (run 85); every `(loop)` class and 26 further callers green; `check-objectscript` 0 problems; `test_check_objectscript` 152 OK; `ci.test.mjs` 103 and `ci-shards.test.mjs` 33 green; `lint-docs` 0 problems; five mutations plus two review-pass mutations observed red and reverted. The `(once)` items (full sweep, smoke, fresh check) are the runner's.

**Residual risk.** Code that can write the install namespace's code database can alter these classes, which the AD-9 amendment names as outside the rule.
