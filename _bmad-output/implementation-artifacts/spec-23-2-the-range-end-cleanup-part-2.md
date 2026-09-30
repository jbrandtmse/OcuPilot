---
title: 'Story 23.2: The range-end cleanup, part 2'
type: 'bugfix'
created: '2026-09-30'
status: 'in-progress'
baseline_revision: 'f8e55fb2622353b7ce4024e9888cbc1a776d440a'
baseline_commit: 'f8e55fb2622353b7ce4024e9888cbc1a776d440a'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['multiple-goals', 'oversized']
deferred:
  - summary: >-
      A service's ClientSystems role grant is judged by the role's name alone, so adding %Manager, or any role whose closure holds an %Admin_ resource, to an allowed address is minted without the destructive treatment.
    evidence: |-
      Prohibited.AddressGrantsPrivilege tests each added role with IsPrivilegedRole, the name-only check that batch c replaced with RoleGrantsAdministrativePrivilege for the customization roles; %Manager carries %Admin_*:U resources (measured on slot B for DW-1663). Pre-existing, and outside batch c's tasks.
    location: >-
      src/OcuPilot/Kernel/Proposal/Prohibited.cls:4021
    severity: medium
---

<intent-contract>

## Intent

**Problem:** Twelve owner-approved ledger entries are still open: two CI flakes that cost reruns in every lane, three security gaps, and seven defects in the password, progress, proposal, installer, lock and checker paths. Each is real on the current tree.

**Approach:** Fix all twelve in five batches, one implement pass and one commit per batch, merged to the feature branch as soon as its CI is green: (a) flakes, (b) user-visible defects, (c) security, (e) the rest, and (d) DW-48 last. Each fix has a test that goes red on the defect; for a flake, the red is its reproducing condition. No entry is declined.

## Boundaries & Constraints

**Always:**

- Work in `/Users/jbrandt/git/OcuPilot/.worktrees/epic-23` on `OCU-1-epic23`. Every IRIS MCP call carries `server: "ocupilot-slot-b"`. Tests and state-changing probes run on the throwaway `ocupilot-b-ci`, one class per call, and each result is awaited in `%UnitTest_Result`.
- One implement pass per batch, in the order a, b, c, e, d. A red batch is re-opened alone. A batch that touches `Kernel/Proposal/**`, `Screen/**`, `ui/src/app/core/**` or `ui/src/app/shell/**` starts from the feature branch after integrating forward, and keeps its hunks apart from Epic 16's.
- Every behavior fix has a pinning test and a `mutation:` line in its batch's Verification (Rule 19). Vendor behavior a fix depends on is measured on `ocupilot-b-ci`, never recalled. Measured facts below say where they were measured; everything else is marked `(inference)`.
- Append-only files: `src/OcuPilot/Api/Error.cls` (new parameters go at the end) and `ui/src/app/core/strings.ts`. EXPERIENCE.md keeps its line count (993): record `wc -l` before and after any edit. Write non-ASCII in source as `\uXXXX`. Prose discipline (CLAUDE.md) applies to every comment.
- A probe cleans up exactly what it created and reads the cleanup back.

**Never:**

- Implement passes do not edit the spine, `CLAUDE.md`, `.claude/rules/`, `_bmad/custom/`, `epics.md`, or another story's spec. The lead applies those under Rule 20 (`### Proposed amendments`, `### Document corrections at origin`).
- No implement pass writes the ledger, touches a release branch, or pushes a `[skip ci]` commit together with a batch commit.
- Do not stop, remove, recreate or `down` any container. The one exception is the DW-48 runner step, which restarts `ocupilot-b-ci`.
- Do not move `src/OcuPilot/Test/`. Do not widen a fix beyond its task. The 21 per-entity Save handlers stay out of DW-1497.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Validation-routine refusal (DW-1289) | A `PasswordValidationRoutine` refuses the new password | 422 `ACCOUNT.VALIDATION`, one `newPassword` violation whose reason is the routine's own sentence | If the sentence is empty or contains either password, the published fallback sentence is shown |
| Wrong current password and a refused new one (DW-1289) | Both wrong | `currentPassword` violation (the vendor checks 952 first, measured) | No error expected |
| Unconfirmed 5001 (DW-1289) | The change fails with `1446,5001` and `ValidatePassword` answers OK | 500, detail logged only | 838 also stays 500 (opaque) |
| Long tool results (DW-1210) | 60 tool steps of 65,536 characters each | Poll answers 200; each tool step's text is 4,096 characters ending in U+2026 | The model still receives the full result |
| Revoked after the turn ended (DW-1669) | Turn terminal, proposal live, pair revoked | Within about 15 s the privilege line warns and names the pair | Confirm still refuses by name, as today |
| Busy target (DW-1497) | A confirm or row action on a target whose lock is held | After up to 10 s: 409 `WRITE.TARGETBUSY`, nothing written, proposal still live | Retrying once the lock is free succeeds |
| Closed channel (DW-1450) | Confirming `permissions.users.update` with a `Password` key | Refused on the closed channel; the password is unchanged | No error expected |
| Unreadable role (DW-1663) | The customization-role read fails | The role counts as privileged: destructive, `OAUTH.CUSTOMIZATIONPRIVILEGED` | Never a 500 |
| Product start (DW-48) | The compose start hook runs without `OCUPILOT_LOAD_TESTS=1` | No `OcuPilot.Test.*` class is compiled | A load error still exits 1 |
| Throwaway or CI start (DW-48) | `OCUPILOT_LOAD_TESTS=1` | The whole tree is compiled, as today | No error expected |

</intent-contract>

## Code Map

- **a:**
  - `Test/BackgroundSeed.cls` (`PausedCompact`, `Remove`) and `Test/BackgroundTasksLive.cls`:
    - agent leg `TestTheAgentsConfirmPausesACompact`, with `ProposeAndConfirmPause` at :337-346 and retries at :304-310 and :354-358;
    - screen leg at :190-195;
    - admin-API leg at :227-245.
  - Vendor: `irissys/%SYS/BackgroundTask.cls` — `End()` at :622-643, `Request()` at :675-704 (takes the task lock at :687), Paused only in process state 18 at :567-569.
  - `Port/BackgroundTaskPort.cls:318-324` and `PortalControl` at :626-650.
  - `Test/OAuthIssuerFixture.cls` `Serve` at :101-170 (listens at :109, closes at :162).
  - `Port/OAuthServerPort.cls` `DiscoveryCause` at :412-443, and the vendor's `irissys/OAuth2/ServerDefinition.cls:264`.
  - Other users of the fixture: `Test/{OAuthServerDiscover,OAuthServerJwks,OAuthServerWire,OAuthClientRegister,OAuthClientUpdate,OAuthClientWire,InjectionEgress}.cls`, `ui/browser/oauth-server-description-editor.browser-spec.mjs` and `ui/browser/oauth-client-editor.browser-spec.mjs`.
- **b:**
  - `Api/Account.cls`: `WRONGPASSWORDCODE` at :32, `POLICYCODES` at :38, the passwords cleared at :86-87, `RenderChangeRefusal` at :133-148 (its 500 arm at :147), `PolicyText` at :160-172.
  - `Test/AccountPasswordWire.cls:207-230`. The pattern for tearing down system settings is `Test/AuditingUpdate.cls:60-126`.
  - `Kernel/State/Step.cls`: `GuardedFinishTool` at :164-180, `ApplyContent` at :236-244, `GuardedRows` at :201. `Kernel/Agent/Limits.cls`. `Kernel/Agent/Loop.cls`: :568, and the announce steps at :656 and :755.
  - `Test/LedgerStep.cls:118-129`. `ui/src/app/shell/tool-call-card.ts:58-60,144-150`.
  - `ui/src/app/core/turn.ts`: `pollUntilTerminal` at :1514-1528, `pollOnce` at :1530-1573, `recordProposalMissingPair` at :1361-1388, restore at :632-636.
  - `Api/Turn.cls:232-240` and `Kernel/State/Propose.cls` `WireRow` (about :755-763).
  - `ui/src/app/shell/proposal-card.ts:318-331,694-696`, `ui/tools/turn.test.mjs` and `ui/browser/proposal-privilege.browser-spec.mjs`.
  - `Install/Installer.cls`: `CodeDatabaseResource` at :2254, `EnsureApplicationRoles` at :2306, the drift check at :2321.
  - Vendor: `irislib/%CSP/REST.cls:180-193,334`. `Test/WebApp.cls`.
- **c:**
  - `Kernel/Proposal/Prohibited.cls`: `AddsPrivilegedCustomizationRole` at :2448, `IsPrivilegedRole` at :3017, `RoleEscalates` at :2744, `RoleGrantsPrivilege` at :2815 (fails open at :2824-2826), and `GrantsPrivilegeByEffect` at :2934-2962.
  - `Area/Security/OAuthAuthorizationServerRules.cls`: `CustomizationViolations` at :393-403, `HandleForm` at :644, the create defaults at :152.
  - Reference implementations: the mark in `Area/WebApp/FormRules.cls:422`, and the missing-mark default in `ui/src/app/areas/permissions/user-editor.store.ts:604-605`.
  - `ui/src/app/areas/security/oauth-server-form.store.ts`: :299-302, :461-464 and :818.
  - `Screen/Registry.cls`: `ConfirmChannelProblem` at :2484 (sources at :2512-2518) and `SecretRowNames` at :3046. `ui/tools/screen-mirror.mjs:542-562`.
  - `Kernel/Proposal/Confirm.cls`: `ChannelProblem` at :494, `WithSecrets` at :710 (applied at :398), and the gate at :279. `Api/ScreenAction.cls:464`. `Screen/Tool/WebAppUpdate.cls:51`.
- **e:**
  - `Api/ScreenAction.cls` `Run`: begins at :217, reads at :255, gates at :312, writes at :327.
  - `Kernel/Proposal/Confirm.cls` `Transition`: :244, :279, :354, :377 and :421 (`ApplyAt`).
  - `Kernel/State/Propose.cls`: `GuardedClaimAndClose` at :441-477 and `CLAIMLOCKSECONDS` (doc at :375-376). `Kernel/State/Base.cls:482-503`. `Kernel/Proposal/Operation.cls:9-12`.
  - Tests: `Test/ReadBackRoute.cls`, `Test/ProposalSpelling.cls:497-499`, `Test/ProposalFixture.cls`.
  - `scripts/check-objectscript.py`: the stated limit at :1287-1296, `DESTRUCTIVE_TEST_RE` at :1353, `guarded_before_all_tests` at :1412, `check_destructive_test_guard` at :1453. Harness `TestDestructiveTestGuardRule` in `scripts/test_check_objectscript.py:1768`.
- **d:**
  - `scripts/container-start.sh`: the `OCUPILOT_DEMO` read at :264-273, `LoadDir` at :310, and the comment at :163.
  - `scripts/ci-throwaway.sh` env block at :169. `docker-compose.yml:39-43`. `Install/Roster.cls:98` (the `OcuPilot.Test.PKG` `scope: test` resource), which produces `module.xml`'s `Scope="test"`.
  - `.github/workflows/ci.yml` (`images` job). `ui/tools/compose.test.mjs` and `ui/tools/ci.test.mjs` (which pins the workflow's `run:` steps).

## Tasks & Acceptance

**Execution:**

- One implement pass per batch. Each pass leaves the tree for one commit, `fix(23.2): batch <x> - <area>`.
- Every entry below gives its defect, how it goes red, its fix and files, and its ADs.
- The lead writes each entry's `resolved-by` trailer when its batch's commit is green.

### Batch a: CI flakes (merge first)

- [x] **DW-1829** — `BackgroundTasksLive`'s agent leg resumes a seeded compact, then mints and confirms a pause. The compact can reach `End()` in between, and the confirm is refused (409 `TASK.BACKGROUND.STATE`). The trailer's 30 s half is void (DW-1819, fixed by 6bcc6d3b); the open cause is the DW-1802 race.
  - **Reproduced** (measured on `ocupilot-b-ci`): a seeded compact reads Done 1.90 s after resume (2/2). Resume, wait 3 s, then pause through the port answers 409 (2/2).
  - **Fix:** `Test/BackgroundSeed.cls` gains an opt-in `Hold(pTaskId)`. In `%SYS` it takes `%SYS.BackgroundTask.%LockId(task)` before the resume, which blocks `End()`. The task then reads Running, and an in-process pause answers 200 (measured 3/3).
  - **Teardown:** `Remove()` cancels under the hold, then calls `%UnlockId` (measured clean 2/2). Releasing first strands the task.
  - **The agent leg becomes:** seed, `Hold`, resume, a fixed 3 s wait (the reproducing condition, kept in the test), mint, confirm.
    - It asserts that the confirm applied and that the vendor's pause `Request` reads 1. A held compact whose work has finished reads Running, not Paused (measured 4/4).
    - The retry loops are deleted.
  - `PausedCompact` is unchanged; the background-tasks and local-databases specs never resume.
  - Files: `Test/BackgroundSeed.cls`, `Test/BackgroundTasksLive.cls`. ADs: Conventions › Tests, AD-27 (the Story 16.5 case).
  - AC: Given a held seeded compact and a 3 s wait between resume and mint, when the agent's pause is minted and confirmed, then the confirm applies and the vendor records the pause request.
- [x] **DW-1831** — `OAuthIssuerFixture.Serve` opens its listening socket for each connection and closes it after answering. A client that reconnects before that close is reset. The vendor's `GetServerMetadata` then fails with #6097 `<READ>`, and `DiscoveryCause` answers "unreachable" instead of 422 `OAUTH.DISCOVERY.CONTENT`.
  - **Reproduced** (measured on `ocupilot-b-ci`, using a stand-in fixture that lingers 0.3 s before closing): 10/20 raw GETs failed with #6097, and the case after `/status` answered "unreachable" 5/5.
    - The unmodified fixture held up locally for 300 GETs and 200 discoveries.
    - That a CI runner delays the close enough to open the window is `(inference)`.
  - **Fix:** open the listening socket once. Hand each accepted connection to its own device (`$SYSTEM.Socket.Select` and `Fork`), flush the answer (`%IO.DeviceStream.Flush()`), wait the linger, and close that device; close the listening socket only on stop. `check-objectscript.py` refuses a bare `Write *-3`/`Write *-2` outside the response writer. Measured on `ocupilot-b-ci`: 20/20 raw GETs and 20/20 discoveries with the 0.3 s linger, the first answer arriving in 2 ms. Add a `Linger` setting (seconds to wait after answering, default 0).
  - Files: `Test/OAuthIssuerFixture.cls`, and `Test/OAuthServerDiscover.cls` (a new method that runs the four cases back to back with linger 0.3). ADs: Conventions › Tests, AD-27 (the Story 12.4 case).
  - AC: Given the fixture lingering 0.3 s after each answer, when the four discovery cases run back to back, then each answers 422 with its own cause code.

### Batch b: user-visible defects

- [x] **DW-1289** — A refusal by a `PasswordValidationRoutine` answers 500.
  - **Measured on `ocupilot-b-ci`** (plan stage; the probe was removed):
    - `ChangePassword` answers `1446,5001`, where the second text is the routine's sentence. A wrong current password answers `1446,952` first; a pattern failure answers `1446,845`.
    - `$SYSTEM.Security.ValidatePassword(new, user)`, called by a principal holding only `%DB_HSCUSTOM:RW`, answers `5001` with the routine's sentence, `845` for a pattern failure, and OK otherwise.
  - **Fix:** in the arm that renders 500 today (codes carry none of 952, 845, 958 or 838), call `ValidatePassword(<new>, $Username)` in the caller's process (AD-49).
    - If its first error is 5001, 845 or 958, answer 422 `ACCOUNT.VALIDATION` with one `newPassword` violation (`ACCOUNTPASSWORDPOLICY`). Its reason is that error's text; an empty text, or one containing either password, is replaced by `REASONACCOUNTPASSWORDPOLICY`. Any other validator answer stays 500.
    - If the validator answers OK, the 500 stays. No text from the change's own 5001 is ever rendered.
    - Clear the passwords after classification. Move the classification into a class method that can be tested on constructed statuses.
  - **Red:** a new `AccountPasswordWire` leg, under the class's existing `OCUPILOT_ALLOW_PRINCIPALS` arming.
    - It creates a `%SYS` routine through `%Routine` that refuses a marked password with a literal sentence, then sets `Security.System.PasswordValidationRoutine` (`Tag^Routine`).
    - POST `/account/password` as the probe account: today 500; after the fix, 422 carrying that literal (the literal is the oracle).
    - A second routine quotes the password and expects the fallback sentence.
    - Classifier legs: `1446,5001` with the validator answering OK gives 500; `1446,838` gives 500.
    - Teardown restores the setting, deletes the routine, and reads both back.
  - Files: `Api/Account.cls` (its doc comments at :34-37 and :44-48), `Test/AccountPasswordWire.cls`. ADs: AD-39 (amended below), AD-49, AD-35, AD-12, AD-8.
  - AC: Given a configured routine that refuses the new password, when users change their own password, then New password shows the routine's sentence with a 422. Given a refusal the validator does not confirm, when the change is refused, then the answer stays 500.
- [x] **DW-1210** — `GuardedFinishTool` stores each tool result up to 131,072 characters, and `GuardedRows` projects every step's text on every 1 s poll.
  - **Measured:** `%ToJSON()` over 60 steps of 65,536 characters each raises `<MAXSTRING>` (`MaxLocalLength` is 3,641,144), so a long turn's poll fails.
  - **Fix:** add `Limits.TOOLSTEPTEXTMAXLENGTH = 4096`. `GuardedFinishTool` cuts a tool step's text to that length, ending in U+2026, and sets `Truncated`.
    - No wire key is added, and the announce steps are not cut.
    - The model's `tool_result` is unchanged, since the provider history takes the result, not the step.
  - **After the fix:**
    - A poll carries at most 4,096 characters per tool step (409,600 over 100 steps).
    - Model-step text stays bounded by AD-31's 500,000 provider tokens (inference: about 2 MB).
    - An expanded tool-call card shows the first 4,095 characters and "…"; its rows line is unchanged.
  - **Red:** in `Test/LedgerStep.cls`:
    - a tool step finished with 65,536 characters reads back as 4,096 characters ending in U+2026;
    - 60 such steps serialize through `GuardedView` (today they raise `<MAXSTRING>`);
    - the cap leg at :118-129 moves to the new parameter.
  - Files: `Kernel/Agent/Limits.cls`, `Kernel/State/Step.cls` (comments at :160-163), `Kernel/Agent/Loop.cls` (comment at :562-565), `Test/LedgerStep.cls` (comment at :85-88), and EXPERIENCE.md :612 (in place). ADs: AD-33 (amended below), AD-31, AD-24, AD-11, AD-36.
  - AC: Given a turn of 60 tool steps each returning 65,536 characters, when the panel polls progress, then the poll answers 200 and each tool step's text is 4,096 characters ending in "…".
- [x] **DW-1669** — `pollUntilTerminal` stops when the turn ends, so a live card's privilege line keeps its last answer. `WireRow` evaluates the line on each read, but only the progress poll and conversation restore carry it.
  - **Fix, in `ui/src/app/core/turn.ts`:**
    - Once the turn has ended, re-read `GET /turn/:id/progress` every 15 s (an injectable `rereadMs`, default 15,000) while at least one of its proposals is live and unexpired on the panel.
    - Keep a proposal-id-to-turn-id map, filled in `pollOnce`.
    - Stop when none is live, on a 404 or another refusal, on an accepted send, and at `endSession` or `newConversation`. Skip a tick while the document is hidden; the probe is injectable, so `core/` stays framework-free (AD-19).
    - Merge only `privilege`, and only into rows that are still live locally with no confirm, cancel or draft in flight.
  - Why this is safe: a terminal turn's poll renews no lease (`Api/Turn.cls:232-235`), and its row outlives the proposal (15 min against 10). The server does not change.
  - **Red:**
    - New `ui/tools/turn.test.mjs` cases on `fakeSchedule`: the re-read is armed at 15,000 ms and sets `missing`; nothing is armed without a live proposal; an in-flight confirm is left alone; the re-read stops at expiry.
    - A new case (c) in `ui/browser/proposal-privilege.browser-spec.mjs`: the turn completes, the pair is revoked, and the line warns.
  - Files: `ui/src/app/core/turn.ts` (comments at :1356-1360 and :1575-1590), `ui/tools/turn.test.mjs`, `ui/browser/proposal-privilege.browser-spec.mjs`. ADs: AD-8, AD-6, AD-7, AD-19, AD-33, AD-43.
  - AC: Given a turn that has ended with a live proposal whose pair is then revoked, when 15 s pass, then the card's privilege line warns and names the pair.
- [x] **DW-1440** — `CodeDatabaseResource` derives the floor role's grant from the routines database. `%CSP.REST` `AccessCheck` tests the default globals database's resource, `$Piece($zu(90,21,$namespace),"^",4)`, and answers a bodyless 403 when it fails.
  - **Reproduce first** (implement stage, on `ocupilot-b-ci`, removed afterwards):
    - Create namespace `OCUPSPLIT` with Routines `HSCUSTOM` and Globals set to a database whose resource carries no public permission. If `%DB_USER` is public, create `OCUPSPLITG` in its own directory, `/durable/iris/mgr/ocupsplitg/`.
    - Create an unauthenticated app `/ocupsplit` that dispatches to `OcuPilot.Api.Readiness`.
    - Curl it twice, recording status and body: once with the application role granting `%DB_HSCUSTOM:R` only (expected 403), once with both databases' resources (expected not 403) `(inference until measured)`.
  - **Fix:**
    - `CodeDatabaseResource` returns both resources, deduplicated: the routines database's and the default globals database's.
    - `EnsureApplicationRoles` grants `:R` on each to `OcuPilotShell` and `OcuPilotReadiness`, listed in the order `Security.Roles` stores them, so the drift check does not repair on every install (inference).
  - **Red:** in `Test/WebApp.cls`, create a namespace configuration over two existing databases (Globals `USER`, Routines `HSCUSTOM`). Its derivation must include the vendor's own `$Piece($zu(90,21,ns),"^",4)`; today it returns only `%DB_HSCUSTOM`. Remove the namespace afterwards.
  - Files: `Install/Installer.cls` (comments at :2248-2253, :2285-2305 and :2333), `Install/Roster.cls:30`, `Test/WebApp.cls` (:77, :536, :563), `docs/DEVELOPMENT.md:293-294`. ADs: AD-21 (amended below), AD-9, AD-17, AD-45.
  - AC: Given a namespace whose globals and routines databases differ, when the installer derives the anonymous floor, then it grants read on both resources and the anonymous request is not refused 403.

- [x] [CI] browser shard 1/3 (run 36720188412, job 109903017094): `seeded-injection.browser-spec.mjs:212` "channels" leg is red on 323948ad. It expands the roles read's tool card and requires the seeded role's marker in the card text; DW-1210 now cuts that text at 4,095 characters and the seed's row lies past the cut. Keep the spec's intent (the seed reaches the model only as tool-result text: no proposal, no navigation, nothing off the origin) and DW-1210's cut; make the leg read the seed within the cut (for example by narrowing the scripted read to the seeded role with the read's own criteria) or assert on what the model received, and sweep every other browser spec that asserts on a tool card's result text for the same dependency — https://github.com/jbrandtmse/OcuPilot/actions/runs/36720188412/job/109903017094

### Batch c: security

- [x] **DW-1663** — `AddsPrivilegedCustomizationRole` judges by name only. `%Manager`, `%Operator` and `%SecurityAdministrator` carry `%Admin_*:U` resources (measured on slot B), yet are minted non-destructive. `RoleGrantsPrivilege` reads a failed `Security.Roles.Get` as "no resources", which fails open.
  - **Fix:**
    - Judge each added role with `RoleEscalates`, the web-application arm's predicate: a role is privileged when its closure holds `%All`, or any `%All` or `%Admin_*` resource.
    - Fail closed: `Security.Roles.Exists` separates an absent role, which grants nothing, from a failed read or a failed `GetRecursedRoleSet`. A failed read counts as privileged and is minted destructive with `OAUTH.CUSTOMIZATIONPRIVILEGED`, never a 500. The web-application arm fails closed the same way.
  - **Server-computed mark:**
    - `HandleForm` answers `roles:[{name, privileged}]` from `RoleGrantsAdministrativePrivilege`, as `FormRules.cls:422` does.
    - In the store, `isPrivilegedRole` is deleted and `addsPrivilegedRole` reads the mark; a missing mark counts as privileged.
  - **Unreadable role:** a caller holding only the tab's two pairs cannot add a role outside the stored set; `CustomizationViolations` refuses it `OAUTH.CUSTOMIZATIONROLES.ABSENT` without `%Admin_Secure:USE` (inference from source). The fail-closed arm is therefore defensive. Its leg runs the classifier in a job signed in as a principal that lacks `%Admin_Secure:USE`.
  - **Red:**
    - `Test/OAuthAuthorizationServerUpdate.cls:210`: `%Manager → 0 ""` flips to `1 OAUTH.CUSTOMIZATIONPRIVILEGED`. Add `%Developer → 0` and the fail-closed leg.
    - `Test/OAuthAuthorizationServerClients.cls:70`: assert the mark in the form body.
    - `oauth-server-form.store.spec.ts:243-252` flips.
  - Files: `Kernel/Proposal/Prohibited.cls` (comment at :2444-2447), `Area/Security/OAuthAuthorizationServerRules.cls`, `Screen/Tool/OAuthAuthorizationServerCreate.cls` (text at :86 and :181-183), and `ui/src/app/areas/security/oauth-server-form.store.ts` with its spec. ADs: AD-10, AD-8, AD-5, AD-39, AD-16.
  - AC: Given an agent proposal that adds `%Manager` to the customization roles, when it is minted, then it takes the destructive treatment and its diff names the privilege. Given a role whose read fails, when a proposal adding it is minted, then it is treated as privileged.
- [x] **DW-1450** — `ConfirmChannelProblem` and the mirror accept a `secretArguments` name that is any ordinary field or read field of the identifier's tools. At confirm, `ChannelProblem` admits the descriptor's whole list for every tool, and `WithSecrets` sets it into the body after the AD-10 gate has run.
  - **The ledger's probe is wrong as written:** `Timeout` is permitted by `WebAppUpdate` (:51). The red probe is `Path` instead: ordinary on both web-application tools, permitted by neither, and never caller-nameable (AD-21).
  - **Measured:** `UserUpdate`'s screen admits `Password` at confirm, although the update tool writes no `Password`.
  - **Fix:**
    - A `secretArguments` name is valid only if it is a top-level secret row of one of the identifier's tools (`ToolFields.cls`). The ordinary and read sources are dropped for `secretArguments` but kept for `fingerprintExcludes`, identically in `Registry.cls` and `screen-mirror.mjs` (AD-5).
    - `ChannelProblem` and `ScreenAction.cls:464` admit the descriptor's list intersected with the confirmed tool's own secret rows and its `SECRETBODY` names (AD-6: "for that tool").
    - All 15 shipped entries are secret rows (measured), so no shipped screen changes.
  - **Red:**
    - `Test/Descriptor.cls:319-330`: `secretArguments ["Path"]` is refused (today it answers `""`). The `Timeout`, read-field, `AutoCompile` and `CorsAllowlist` acceptances there and at `Test/UserCreate.cls:382-383` flip.
    - `ui/tools/screen-mirror.test.mjs`: the same flips at :2303-2320 and :2523-2525.
    - `Test/ProposalConfirm.cls`: confirming `permissions.users.update` with `{"Password":…}` is refused on the closed channel, and `Security.Users.CheckPassword` shows the password unchanged.
  - Files: `Screen/Registry.cls`, `ui/tools/screen-mirror.mjs`, `Kernel/Proposal/Confirm.cls`, `Api/ScreenAction.cls`, and the tests above. ADs: AD-6, AD-56, AD-3, AD-5, AD-10, AD-21, AD-35.
  - AC: Given a descriptor declaring a secret that its tools do not write as a secret, when the registry loads or `npm run build` runs, then both refuse it with one sentence. Given a confirm carrying a key its tool does not write as a secret, when it is sent, then it is refused on the closed channel.

### DW-1870 (owner-approved for 1.0.4, before batch e)

- [ ] **DW-1870** (high; owner-routed to this story outside the cap of 12) — a Windows clone with `core.autocrlf=true` checks `scripts/*.sh` out with CRLF, so `durable-init` dies at once (`set: Illegal option -`) and `docker compose up --wait` fails in 1 s. The index is already LF; the `.cls` files are unaffected.
  - **Fix:** add `*.sh text eol=lf` to `.gitattributes`. No renormalize.
  - **Red:** a roster-style test in `ui/tools/` that asks `git check-attr eol` for every tracked `*.sh` (`git ls-files '*.sh'`) and requires `lf` for each; it reddens without the rule. Where possible, also a fresh `git -c core.autocrlf=true clone` of the working tree showing every `*.sh` checked out without CR.
  - Files: `.gitattributes`, one new `ui/tools/*.test.mjs`. ADs: AD-17, AD-45 (the start path must run on every supported host).
  - AC: Given a clone made with `core.autocrlf=true`, when it is checked out, then every tracked `*.sh` has LF line endings.

### Batch e: the rest

- [ ] **DW-1497** — `ScreenAction.Run` reads, gates and writes with no lock. The confirm holds `^OcuPilotProposalTarget(key)` only across its claim; its re-read and its port write (`ApplyAt`) happen outside the lock. So a row action that lands between them is silently reverted by the confirm's complete body.
  - **Fix:**
    - `Propose` gains `GuardedTargetHold` and `GuardedTargetRelease` (AD-13 canonical key, `TargetLockKey`, through `Base`'s lock), outliving the escalated frame as `GuardedTurnSlotLock` does. `Operation` exposes them as `Hold` and `Release`.
    - `Confirm.Transition` holds from before its gate (:279) until after the read-back. `ScreenAction.Run` holds from before its fresh read (:255; not for a preview) until its end. The claim's inner lock re-enters.
    - The wait is `CLAIMLOCKSECONDS` (10 s). A caller that times out is refused 409 with a code appended to `Error.cls`, `WRITE.TARGETBUSY`, reason "Another change to this target is being applied. Try again in a moment." It writes nothing, and the proposal stays live.
    - First probe, and record: whether `Lock` on that global needs a database privilege. The design escalates either way.
  - **Red:**
    - `Test/ReadBackRoute.cls`: the test process holds the lock on `/csp/ocupilotprobereadback`'s key, and a POST `disable` answers 409 with the application still enabled. Once released, a retry answers 200. Today the POST answers 200 and disables it.
    - A new `Test/ProposalConfirm.cls` leg over `ConfirmFixture`: its `ProposalFixture` port records whether a JOBbed child can take the lock at write time — 1 today, 0 after the fix.
    - `Test/ProposalSpelling.cls:497-499` changes from 500 INTERNAL to 409, with the row still live.
  - Files: `Kernel/State/Propose.cls` (doc at :375-376), `Kernel/State/Base.cls` (doc at :482-484), `Kernel/Proposal/Operation.cls` (doc at :9-12), `Kernel/Proposal/Confirm.cls`, `Api/ScreenAction.cls`, `Api/Error.cls` (appended), and the tests above. ADs: AD-34 and AD-53 (amended below), AD-13, AD-9, AD-39, AD-58.
  - AC: Given a target whose lock another write holds, when a row action or a confirm reaches it, then after at most 10 s it answers 409 `WRITE.TARGETBUSY` and nothing is written.
- [ ] **DW-1451** — `check_destructive_test_guard` matches call shapes within one file, so a Test class that mints and confirms an auditing proposal is invisible to it.
  - **Fix:**
    - The checker derives the marking tools from the tree: the classes declaring `Parameter MOVESMARKING = 1`, with their class and wire names.
    - It arms a TestCase that names one of them and also calls a write entry point: `Kernel.Proposal.Confirm).Confirm(`, a `/confirm"` route, `ScreenAction).Handle(`, an `/action"` route, or `Operation).Apply(`/`ApplyAt(`. An `Apply` through a literal `OcuPilot.Test.*` port does not arm it. The required refusal is unchanged.
    - **Measured over the shipped tree:** it arms exactly `AuditEventEditor`, `AuditingUpdate` and `ProhibitedRoute`, all guarded, so the tree stays green.
    - Replace the stated limit at :1287-1296 with the narrower limit that remains: a helper in another class, or a computed tool name.
  - **Red:** harness cases in `TestDestructiveTestGuardRule`:
    - an unguarded class that mints and confirms `security.auditing.update` is refused (the ledger's probe);
    - the same class guarded passes;
    - a fixture-port `ApplyAt` passes;
    - a wire name that appears only in a comment passes.
  - Files: `scripts/check-objectscript.py`, `scripts/test_check_objectscript.py`. ADs: AD-15, AD-53.
  - AC: Given a Test class that confirms a `MOVESMARKING` tool with no `OnBeforeAllTests` refusal, when the checker runs, then it is refused by name.
- [ ] **DW-1290** — `TestAPolicyRefusalCarriesTheInstancesOwnText` derives its expected sentence from a privileged `ChangePassword` probe read at index 2 (:225-227). That is the layout `PolicyText` assumes, so the test and the code move together. The probe is also a live write on any build whose pattern admits two characters.
  - **Fix:** build the expected sentence from the code alone: `$System.Status.GetOneStatusText($System.Status.Error(845),1)`. Measured: it reads "Password does not match length or pattern requirements", the text `ChangePassword` embeds.
    - Delete the privileged probe.
    - Before the POST, read `PasswordPattern` in `%SYS` and fail the leg if "ab" matches it.
    - DW-1289's leg already uses its routine's literal.
  - **Red:** mutate `PolicyText` to read index 1 → the leg goes red.
  - Files: `Test/AccountPasswordWire.cls`. ADs: AD-39, AD-49.
  - AC: Given the policy leg, when `PolicyText`'s index derivation changes, then the expected sentence does not change with it and the leg goes red.

### Batch d: DW-48 (merge last)

- [ ] **DW-48** — `container-start.sh:310` runs `LoadDir` over the whole tree. Every start of the repository's compose file therefore compiles every `OcuPilot.Test.*` class (measured: 827 of 1,255 on `ocupilot-b-ci`), fault-injection fixtures included, and a compile error in any test class fails every start. IPM already ships none (`Scope="test"`).
  - **Fix (no tree move):**
    - The hook reads `OCUPILOT_LOAD_TESTS` from `/proc/1/environ`, as it reads `OCUPILOT_DEMO`. Unless the value is 1, it loads the tree without the Roster's test-scope folder (`OcuPilot/Test`), for example by running `LoadDir` over a copy that omits it. The load is silenced and exits 1 on failure.
    - `ci-throwaway.sh` sets `OCUPILOT_LOAD_TESTS: "1"`, and a new `--product` flag starts a throwaway without it. `docker-compose.yml` does not set it.
    - The excluded folder is read from the Roster, AD-17's one source.
  - **Non-Test code needs no Test class** (measured). Its references are strings only: the Roster JSON, `Registry.cls:27`, and `Catalog.cls:86` (resolved only under `OCUPILOT_ALLOW_TEST_PROVIDER`). Smoke on a Test-free archive read executed=42 passed=42 (run 36684985324).
  - **Red:**
    - `ui/tools/compose.test.mjs` asserts that the hook excludes the Roster's test folder when the flag is unset, that compose leaves it unset, and that `ci-throwaway.sh` sets it.
    - CI's `images` job starts its throwaway with `--product` and asserts `SELECT COUNT(*) FROM %Dictionary.CompiledClass WHERE %EXACT(ID) %STARTSWITH 'OcuPilot.Test.'` is 0 (827 today). `ci.test.mjs` pins the new step.
  - **Runner step:** the runner restarts `ocupilot-b-ci` in product mode, counts the compiled `OcuPilot.Test.*` classes (expected 0), runs smoke, and then restores test mode.
  - Files: `scripts/container-start.sh` (comment at :163), `scripts/ci-throwaway.sh`, `docker-compose.yml:39-43` (comment), `.github/workflows/ci.yml`, `ui/tools/compose.test.mjs`, `ui/tools/ci.test.mjs`. ADs: AD-17 (amended below), AD-18, AD-38, AD-45, AD-25.
  - AC: Given the repository's compose start, when install completes, then no `OcuPilot.Test.*` class is compiled, while every throwaway and the CI instance and browser legs still load them.

### Review Findings (batch a)

- [x] [Review][Patch] The linger leg did not pin the fixture's flush: without it each answer arrives only at its close, the next case never connects during a linger, and the close-and-reopen mutation loses its red. Added a first-case assertion [src/OcuPilot/Test/OAuthServerDiscover.cls:190]
- [x] [Review][Patch] The pause-request assertion had only been seen red together with a refused confirm; its own mutation is now recorded under Verification [src/OcuPilot/Test/BackgroundTasksLive.cls:327]
- [x] [Review][Patch] Dead midnight-wrap line on a `$ZHorolog` difference (seconds since startup, never wraps) [src/OcuPilot/Test/OAuthServerDiscover.cls:184]
- [x] [Review][Patch] The not-OK assertion named the cause, so `/not-json` and `/bad-json` read alike; it names the URL [src/OcuPilot/Test/OAuthServerDiscover.cls:216]
- [x] [Review][Patch] `Hold`'s doc said a pause from the holding process "still acts on it" (a held compact reads Running after one) and labeled its inference at length; it now says the lock does not hold such a request up, and that one from another process fails at the lock timeout [src/OcuPilot/Test/BackgroundSeed.cls:222]
- [x] [Review][Patch] The class header said every method refuses unarmed (`Directory`, `State`, `Settled`, `Tasks` and `RequestOf` do not) and that only `Remove` releases a hold (so does the holder's exit) [src/OcuPilot/Test/BackgroundSeed.cls:6]

Rejected:

- low, by-design: `End()` gives up about 10 s after the work ends, leaving about 9 s for mint and confirm after the 3 s wait. The spec deletes the retries; the bound is in `Hold`'s doc and the Auto Run Result, and the lead names it in the DW-1829 trailer.
- low, by-design: the fixed 3 s wait reproduces the race only where a resumed compact finishes within it, and nothing asserts it. The spec fixes the wait, and an elapsed floor after a literal `Hang` can only fail on an edit to the test itself.
- low, wontfix-theoretical: `Remove` releases holds inside its main `Try`. No call there raises on a measured path, an exception fails the teardown assertion, and the lock ends with the process.
- low, wontfix-theoretical: `Remove` discards `Cancel()`'s status (pre-existing). A task left running is reported by its still-runs check, and teardown after a pause was clean in runs 99, 111 and 115.
- false: `Hold("")` raises `<SUBSCRIPT>`. The one caller passes an id `PausedCompact` refuses to leave empty.
- low, wontfix-theoretical: `Stop`'s timeout kills the stop flag and orphans the responder (pre-existing). The loop sees stop within about 1.3 s in the suite; it becomes real with a linger of 4 s or more, or a silent client.
- low, rejected: the serve loop swallows errors, and an open failure's reason is killed before `Start` reads it (both pre-existing). `Start` and the legs still fail loudly, and the fix adds an error channel.
- low, wontfix-theoretical: `Fork` answering 0 leaves a client unanswered. That needs device exhaustion.
- low, by-design: the flush goes through `%IO.DeviceStream`, which the write checker does not see, and its status is discarded. The spec names that flush, and AD-12 binds the response device of a handler, not a JOBbed TCP fixture.
- false: the ungated resume "fails with a message that never mentions the resume". Its own `AssertStatusOK` records that failure first.
- low, rejected: the method name says "pauses" where the leg pins the request, and `Remove`'s doc omits that the vendor's cancel terminates. The docs state what is pinned; a rename would churn the spec's Code Map.
- low, by-design: the screen and admin-API legs keep the resume-then-pause window. This is the spec residual the lead names in the trailer.
- low, rejected (lead-owned): frontmatter `status: done` while batches remain, the Fix line's "`Linger` setting" where the code takes an argument, and the cycle-log `dev_complete` line counts (`git diff --numstat 1a409d00 840ab37f -- src` reads +246/-142).
- false: two lingers do not tell a lingering issuer from a slow host. Unlingered, the four cases took 0.011 s (run 109) against the 0.6 s floor.

### Review Findings (batch b)

- [x] [Review][Patch] high: a validator refusal counted wherever 5001, 845 or 958 sat in the status, and the reason was error 1's text, so a routine's composed status put its 5002 text on the wire (measured: it passes through whole). A refusal now counts only when the validator's first error is one of the three [src/OcuPilot/Api/Account.cls:185]
- [x] [Review][Patch] high: the policy arm rendered an allow-listed 958 without the quote check, and a routine's `Error(958,Password)` reaches the change as `1446,958` "Invalid password pattern '<new password>'" (measured). The quote check now covers the policy arm too (AD-35) [src/OcuPilot/Api/Account.cls:179]
- [x] [Review][Patch] medium: DW-1440's "not refused 403" half had no automated real-runtime test (Rules 3 and 19). The split leg now creates an anonymous application over the namespace with the derived grants and asserts a 200 [src/OcuPilot/Test/WebApp.cls:735]
- [x] [Review][Patch] medium: the account name handed to the validator was unpinned, and the vendor passes routines the lower-case name (measured, both calls). Added a `User` leg [src/OcuPilot/Test/AccountPasswordWire.cls:460]
- [x] [Review][Patch] The split leg stayed in `%SYS` after an early `Quit`, and its cleanup saved `%SYS` as the namespace to return to [src/OcuPilot/Test/WebApp.cls:740]
- [x] [Review][Patch] "Lacking either grant, 403" was half unmeasured. Measured: without the routine grant, a server error page. Corrected at origin, together with a clause saying the floor reads a split namespace's data database [docs/DEVELOPMENT.md:293, src/OcuPilot/Install/Installer.cls:2319]
- [x] [Review][Patch] The 4,096/4,097 edge of the tool-step cut was unpinned [src/OcuPilot/Test/LedgerStep.cls:133]
- [x] [Review][Patch] The re-read's scope to the ended turn's own proposals was unpinned [ui/tools/turn.test.mjs:2112]
- [x] [Review][Patch] The re-read kept polling every 15 s on a 401 or 403 that ends a poll. It now tells a refusal from a transient fault as `pollOnce` does [ui/src/app/core/turn.ts:1659]
- [x] [Review][Patch] A probe left by an interrupted run was detected and not removed, so the first method's teardown failed for it [src/OcuPilot/Test/AccountPasswordWire.cls:129]
- [x] [Review][Patch] ×7 doc corrections: `Account`'s header said no `%Status` carries a password; `ROUTINEREFUSALCODE`'s doc said 5001 is what routines return; the routine's second run was undocumented; "keeps its first 4,096 characters" (4,095 plus U+2026) in three places; `TEXTMAXLENGTH` and `Step`'s header named one cap; a stale mutation note ("the last leg"); and a garbled clause in DEVELOPMENT.md :310

Rejected:

- false: the routine's lower-case name makes the validator answer differently for a mixed-case account. `ValidatePassword` lower-cases it too (measured on `ocupilot-b-ci`).
- low, by-design: the validator is consulted when a change failed with no 5001, so a history-keeping routine (the vendor's documented example) runs outside a change. The spec's Fix defines the arm and chooses provenance over the code 5001.
- low, by-design: a routine refusing with a code other than 5001, 845 or 958 answers 500. AD-39's closed allow-list; the lead's AD-39 amendment names the codes.
- low, wontfix-theoretical: a routine sentence that quotes a password in another case, or in part, passes the quote check. It becomes real with a routine that transforms the password before quoting it.
- medium, escalated DW-1864 (owner burndown): `GET /conversation/:id` writes every entry's steps as one `%ToJSON()` string. DW-1210 bounds the poll, not the restore.
- low, wontfix-theoretical: `CodeDatabaseResource` opens the globals database through `SYS.Database`, which a remote (ECP) globals database may refuse. It becomes real when OcuPilot installs into such a namespace; before this change that namespace's anonymous applications answered 403 anyway.
- low, wontfix-theoretical: the drift check compares the grant string in order. `%DB_` resources are upper case by rule (Conventions › IRIS security objects), and the collation order was measured.
- low, rejected: a split namespace's first start after upgrading reports a repair, and the role keeps its old description. One time only, on a namespace whose floor did not work before.
- low, rejected: `CodeDatabaseResource`, `tCodeResources` and the two `…OnTheCodeDatabase` test names now describe less than they do. Renaming churns the spec's Code Map and DEVELOPMENT.md; the doc comments state both databases.
- low, rejected: `AccountPasswordWire` exceeds the 500-line guideline. Splitting would move the probe helpers for no behavior.
- low, wontfix-theoretical: a re-read in flight across a confirm refusal can restore "held" for one tick. It needs a revocation inside one request's flight.
- low, by-design: the re-read does not move a row the instance closed elsewhere. The spec merges `privilege` only.
- low, wontfix-theoretical: a proposal with no parseable `expiresAt` arms no re-read. The server always sends it.
- low, rejected: an unexpected 200 in the routine leg leaves the stored password stale, and a failed `GuardedView` in `TurnTools` errors rather than asserting. Both occur only in a run that is already red, and the fix adds branches.
- low, rejected: a cut inside a surrogate pair keeps 4,094 characters plus U+2026 (the implement triage's reason).
- low, wontfix-theoretical: a refused send after the conversation was re-minted leaves the re-read on proposals the mint closed. It needs a 404 on the conversation, then a refused turn.
- low, wontfix-accepted (`reopen_if=` a hidden tab is observed re-reading every 15 s): `main.ts`'s hidden probe has no executed test host, by design (`ui/tools/scope.test.mjs:489`).
- low, rejected: no test for the stops at New conversation and sign-out, or for a draft in flight. Both stops clear `entriesValue`, which `hasLiveProposal` reads before every tick; a draft closes its row.
- low, wontfix-accepted (`reopen_if=` `EnsureApplicationRoles` transforms the grants `CodeDatabaseResource` answers): the role step is not run on a split namespace. It passes the derived grants through unchanged, and the split leg pins those.
- rejected (lead-owned, spec text): DW-1289's Fix "If it refuses" (now: first error 5001, 845 or 958); DW-1669's "on a new send" (an accepted send); User-visible changes DW-1210 "first 4,096 characters" (4,095 plus "…").

### Review Findings (batch b rework 1)

- [x] [Review][Patch] low: the `seeded-injection` `mutation:` line read both as the pre-edit red and as a reverted mutation. The mutation was applied to the fixed spec, seen red on `channels` alone, reverted byte-identical, and the line rewritten [spec `## Verification` › Batch b]

Rejected:

- low, rejected (lead-owned, cycle log): line 105's `dev_complete` carries `spawn_at=` in the timestamp column and the event time unkeyed among its fields; line 93 carries `1058` in that column.
- low, rejected (lead-owned, spec text): the Auto Run Result's "6 rejected" (its triage entry has seven `[reject]` rows) and its "no `ui/tools` file changed" reason for skipping `test:tools` (several tools suites read `ui/browser/`; the tier ran 1,731/1,731 in this review); the loop list's "Spec: `proposal-privilege`" omits `seeded-injection`; no `## Spec Change Log` line for the rework; the batch b triage row "993 … is in the Auto Run Result" now points at a replaced section (EXPERIENCE.md reads 993 lines); the triage citation `Read.cls:222-224` (the cap is applied at :221); wording ("the spec 2/2", "a follow-up pass that patched no high", "Epic 16's three browser specs").
- low, rejected: a filter miss fails with the same "marker" message. The message prints the card's first 400 characters, which show the rows that came back, and a miss needs more than 1,000 roles or another role whose name contains the probe's.
- low, rejected (outside the rework, not high): the pinning assertion's `elements === 0` half has no mutation of its own. Rule 19 asks one per AC, and the recorded one reddens this assertion.
- false: the residual risk implies the filter introduced the 1,000-row miss. It states the fact and claims no cause.
- false: the sweep misdescribes `auditing-write` and `task-resume`, which read whole-card text. They look for status words and a tool name, which a card shows expanded or not, so the cut cannot remove them.
- false: the `anywhere` leg does not show the filtered read returned the row. That leg pins what a compliant model can do; the `channels` card assertion pins the row.

### Review Findings (batch c)

- [x] [Review][Patch] medium: a screen action's value that the screen declares secret and its tool does not send went to the ordinary values, where the confirm channel refuses the same key; it is refused now, and so is every value when the secret declaration cannot be read (AD-6, AD-56) [src/OcuPilot/Api/ScreenAction.cls:478]
- [x] [Review][Patch] medium: no real browser observed the privilege line; the create leg now asserts the default `%Manager` shows it and unticking it removes it (Rule 3) [ui/browser/oauth-server-editor.browser-spec.mjs:268]
- [x] [Review][Patch] The name-only rule stayed at its origin: the customization effect's doc and EXPERIENCE.md :520, corrected in place (993 lines) [src/OcuPilot/Kernel/Proposal/Prohibited.cls:320]
- [x] [Review][Patch] ×5 doc corrections: `SecretFieldNames` said "the secrets its write sends" (a tool's own `SecretArguments` still closes them); `ChannelProblem` said an empty body is always sound; `ProposalConfirm`'s header said the probe leg is refused before any port call (its mint reads through the shipped port); `SecretSpelling` claimed the X.509 tools' schema where it reads the edit's; a mirror-test comment said both confirm-channel keys read `declaredNames`
- [x] [Review][Patch] `EnsureUnreadPrincipal`'s `Catch` did not restore `$NAMESPACE` first (AD-16) [src/OcuPilot/Test/OAuthAuthorizationServerUpdate.cls:324]
- [x] [Review][Patch] ×2 verification: the loop ran none of the shipped secret-confirm suites, and runs 223-225 went out in one message; the review probed every write tool's channel and ran 18 classes one at a time (runs 229-246)
- [x] [Review][Defer] A service's `ClientSystems` role grant is judged by name [src/OcuPilot/Kernel/Proposal/Prohibited.cls:4046] — deferred: pre-existing, DW-1869 (owner burndown), occurrence appended

Rejected:

- low, wontfix-accepted (`reopen_if=` two tools under one `toolIdentifier` classify one top-level path differently in `ToolFields.cls`): `Registry.ToolFieldRows` keeps the last tool's row for a path while the mirror takes the union; none today, and the Descriptor test's shipped-descriptor leg reddens on the first.
- low, wontfix-accepted (`reopen_if=` `DECLAREDNAMEKINDS` is next edited): the `settable` projection has no reader left in either engine; removing it moves the pinned roster in three files.
- low, wontfix-accepted (`reopen_if=` `ProposalConfirm` reads red where `OCUPILOT_ALLOW_PRINCIPALS` is unset): the password leg fails rather than skips unarmed; throwaways and CI arm it, and a skip adds a roster member in `ci-throwaway.sh`.
- low, wontfix-accepted (`reopen_if=` a tool's payload or diff names a declared secret outside its own secret rows): the draft and the card read the screen's whole list, as in the implement triage; `proposal-view.ts:170`'s name-only comment is in Epic 16's contended file.
- low, wontfix-theoretical: an exception raised inside `RoleEscalates` itself still answers an error, and the mint a 500 that refuses it; `RoleGrantsPrivilege` catches its own, and no measured path raises one.
- low, wontfix-theoretical: the line and the card say "%All or an administrative role" for a role that merely could not be read; only a caller without `%Admin_Secure:USE` meets it, `CustomizationViolations` refuses that caller's new role, and `strings.ts` is append-only.
- low, wontfix-theoretical: `EnsureUnreadPrincipal` deletes an account of its own test-only name without a marker; the class is armed.
- low, by-design: the shared predicate also moves the user and role arms and every form mark to privileged on a failed read; fail-closed, and those screens require `%Admin_Secure:USE`, which reads roles.
- low, rejected: `ROLEABSENTCODE` names a vendor code as a parameter, the project's idiom (`Account.cls` `WRONGPASSWORDCODE`, `POLICYCODES`).
- low, rejected: the top-level secret rule has three readers, and `SecretFieldNames` parses the field lists per call as `FieldRows` does; merging them is a refactor.
- low, rejected: a write tool on `Screen.Tool.Base` has a closed channel now; all 116 shipped write tools extend `Write` (probe), and closed is the safe side.
- low, rejected: `TestADeclaredSecretIsAcceptedFromTheScreensOwnDeclaration` cannot tell the intersection from the whole list; the update-password leg pins the intersection (run 206).
- low, rejected: `X509SecretProbe`'s `Declare` seam is only reset now; `X509Update`'s own `SecretArguments` answers `""` either way.
- low, rejected: `CredentialNameProblem`'s exemption no longer fires for a settable field; the doc's condition is what the code checks, and the sentence names the remedy.
- low, rejected: `FieldRows`' declared-secret filter no longer fires for a validated descriptor; it is a second layer that can only hide a field.
- low, rejected: `MarkedRoles` repeats two other slices' loop, and a shared helper would cross slices. false: its cost, 10 ms for 71 roles on `ocupilot-b-ci`.
- low, rejected: test prose (a mutation description, a method name, two long comment lines); the description still reads as removing the secret-row source.
- low, rejected: no HTTP request carries the per-tool refusal; the route passes the body whole (`Api/Confirm.cls:43`) and `ConfirmRoute` pins the route-to-refusal wiring.
- low, rejected: a role entry with a name and no mark is untested; `OAuthAuthorizationServerClients` pins the server's mark as a boolean.
- low, rejected: the password-unchanged assertion cannot redden under the defect, since the vendor refuses the body; as in the implement triage.
- rejected (lead-owned, spec text): "All 15 shipped entries" is 13, in nine descriptors (probe on `ocupilot-b-ci`).
- false: `EnsureUnreadPrincipal` creates principals ungated. The class's `ARMINGVARIABLE` is `OCUPILOT_ALLOW_PRINCIPALS`, `OnBeforeAllTests` refuses unarmed, and `ci-throwaway.sh` lists it (:213).

## Spec Change Log

- 2026-09-30 batch b rework 1 (lead): CI run 36720188412 was red on `seeded-injection` (DW-1210's cut hid the seed's row); the leg now filters its scripted read to the probe role (47e15e2b).
- 2026-09-30 spec gate (lead): the six proposed amendments are applied to the spine by the lead with the batch that ships each (AD-39, AD-33, AD-21 with b; AD-34, AD-53 with e; AD-17 with d), so the spine on the feature branch never describes behavior that has not merged.

## Review Triage Log

### 2026-09-30 — Review pass (batch a)

- verdicts: 10 findings — high 0, medium 1, low 5, false 4, maybe-false 0
- findings:
  - `[medium]` `[patch]` The linger leg never checked that the issuer lingered, so losing the linger on its way to `Serve` left the DW-1831 pin vacuous (verification-gap) — added an elapsed-time assertion (at least two lingers; 0.919 s in run 108); dropping the linger turned it red alone (run 109, 0.011 s); reverted, run 110 6/6.
  - `[low]` `[patch]` `BackgroundSeed.Hold`'s doc comment did not state that the vendor's `End()` waits only the lock timeout (`$zu(115,4)`, 10 s, read on `ocupilot-b-ci`; the timeout is caught at `irissys/%SYS/BackgroundTask.cls:631`) (verification-gap) — the bound is now in the comment; the leg releases at about 5 s after the work ends at 1.9 s.
  - `[low]` `[patch]` The `BackgroundTasksLive` header said the agent's confirm pauses a compact, while the leg asserts the vendor's pause request (verification-gap) — reworded to "the agent's confirmed pause of a compact, as the request the vendor records".
  - `[low]` `[reject]` The screen and admin-API legs still resume and pause back to back over HTTP (intent-alignment, S2 reading) — pre-existing DW-1802 window, not DW-1829's mint-and-confirm race; no CI sighting, and the hold cannot reach an HTTP pause, so the fix is more than a direct correction; the spec's residual has the lead name it in the trailer.
  - `[false]` `[reject]` The agent leg proves the vendor's request field, not Paused, under a same-process lock (intent-alignment) — the leg asserts the AC as worded; `RequestOf` reads 0 after the resume, so it fails without a pause; Confirm reaches the production `PortalControl` path, and the screen leg still pins Paused through it.
  - `[false]` `[reject]` The reds come from undoing the new code, with a delay the fix adds (intent-alignment) — the intent defines a flake's red as its reproducing condition, which both legs carry; the CI mechanism is marked `(inference)` in the task.
  - `[low]` `[reject]` The planned `Write *-3`/`Write *-2` became `Select`/`Fork`, recorded only in the rewritten Fix line (intent-alignment) — the planned form fails `check_write_discipline` (`scripts/check-objectscript.py:585-599`, verified), which the spec requires clean; this row records the deviation, and the only fix left is a spec edit.
  - `[false]` `[reject]` `TestEachCauseIsRefusedByName` was refactored and its message now names the URL (intent-alignment) — the shared helpers serve the new leg, and the URL tells `/not-json` from `/bad-json`, which the shared cause "content" could not.
  - `[low]` `[reject]` A connected client that stays silent holds the fixture 5 s, which can outlast `Stop`'s 5 s wait (intent-alignment) — no caller in the suite connects without sending a request line, and a closed connection ends the read; the fix adds a branch.
  - `[false]` `[reject]` Frontmatter and `## Auto Run Result` disagree, and the checkboxes are ticked before CI (intent-alignment) — the result is written at finalize, and the Execution section has the lead write `resolved-by` once CI is green.

### 2026-09-30 — Code review (batch a)

- layers: blind-hunter, edge-case-hunter, verification-gap and acceptance-auditor, all Opus; none failed. 33 raw rows grouped into 23 entries: high 0, medium 1, low 19, false 3. 6 patched, 0 deferred, 17 rejected; see `### Review Findings (batch a)`.
- `[medium]` `[patch]` The linger leg did not pin the fixture's flush (verification-gap). A first-case assertion was added: 0.001 s in run 113, and 0.311 s red alone in run 112 without the flush.
- `[low]` `[patch]` The pause-request clause's own mutation is recorded (verification-gap): runs 114 and 115.
- `[low]` `[patch]` ×4, mechanical (blind-hunter): a dead wrap line, a message twin, and the `Hold` and class-header docs.
- Rules: no AD mismatch (Conventions › Tests, AD-27, and AD-12 for the fixture). Rule 3 exempt: test-only flake fixes, run under their reproducing conditions on `ocupilot-b-ci`. No NFR touched.

### 2026-09-30 — Review pass (batch b)

- verdicts: 27 findings — high 1, medium 7, low 15, false 4, maybe-false 0
- findings:
  - `[medium]` `[patch]` The grants the installer builds for a split namespace, and their stored order, were unpinned (verification-gap) — `CodeDatabaseResource` now answers the grants too; the split leg asserts `%DB_HSCUSTOM:R,%DB_USER:R` and a probe role reads it back unchanged (run 145; red alone in run 143).
  - `[medium]` `[patch]` No test took a warning line back to held (verification-gap) — added the `turn.test.mjs` clearing case; red under a warn-only merge.
  - `[low]` `[patch]` The validator-OK leg of DW-1289's second AC had no `mutation:` line (verification-gap) — recorded (run 141).
  - `[medium]` `[patch]` DW-1440's "grants read on both" half had no pin (verification-gap, Rule 19) — same root as the first row.
  - `[low]` `[patch]` The fallback row's Quote and Empty legs had no `mutation:` line (verification-gap) — recorded (run 142).
  - `[low]` `[patch]` The current-password half of the fallback had no assertion (verification-gap) — added a classifier leg; red alone in run 140.
  - `[low]` `[reject]` `AccountPasswordWire` asserts a constructed status's codes (verification-gap) — a fixture precondition that reddens if the vendor's status encoding moves; the AC's pins are the assertions after it.
  - `[medium]` `[patch]` A refused send (409, the hourly limit) stopped the ended turn's re-read though the instance closed nothing (verification-gap) — the re-read now stops only once the turn request is accepted; the new case goes red when the stop moves back before the request.
  - `[low]` `[reject]` The unconfirmed and 838 legs run on the classifier, not the wire (intent-alignment) — the spec's Red names classifier legs over constructed statuses; the 500 renders through the unchanged `RenderInternal`, and the raising-routine leg now drives a wire 500.
  - `[false]` `[reject]` The reason is the validator's re-derived text, not the change's (intent-alignment) — the spec's Fix chooses it ("No text from the change's own 5001 is ever rendered"), as the AD-39 amendment words it.
  - `[high]` `[patch]` Any validator error counted as a refusal, so a routine that raised showed its error text (intent-alignment) — measured on `ocupilot-b-ci`: `ValidatePassword` answers 5002 "ObjectScript error: <DIVIDE>Boom+1^..." and the wire answered 422 with it (run 139, AD-39); only 5001, 845 and 958 now count, and a raising-routine leg pins the 500.
  - `[low]` `[reject]` The validator is consulted for every code outside 952/845/958/838, wider than the matrix's 5001 (intent-alignment) — the spec's Fix names exactly that arm.
  - `[low]` `[patch]` The current-password half of the fallback is untested (intent-alignment) — same root as the classifier-leg row.
  - `[low]` `[reject]` The password match is case-sensitive and whole-password (intent-alignment) — a sentence that quotes a password quotes it as given; a looser match adds a branch for no reachable leak.
  - `[false]` `[reject]` The logged-status redaction goes beyond the plan (intent-alignment) — AD-35 keeps a password out of every log line, and a routine sentence quoting it is the case this batch adds.
  - `[low]` `[reject]` "Poll answers 200" is observed on `GuardedView` and `%ToJSON()`, not the handler (intent-alignment) — the spec's Red names `GuardedView`, which `Api/Turn.cls` serializes.
  - `[low]` `[reject]` A cut inside a surrogate pair stores 4,095 characters (intent-alignment) — cosmetic; the surrogate-safe cut is correct.
  - `[low]` `[reject]` Only the tool step's text takes the new bound (intent-alignment) — the spec leaves model-step text to AD-31 and names the announce steps out of the cut.
  - `[low]` `[reject]` "Confirm still refuses by name" is pinned only while the turn runs (intent-alignment) — no server path changed; case (b) pins the refusal.
  - `[medium]` `[patch]` The clearing direction is untested (intent-alignment) — same root as the clearing-case row.
  - `[low]` `[patch]` `core/turn.ts` read `globalThis.document` for its hidden default (intent-alignment, AD-19) — `main.ts` now passes the probe, as it passes the document to `theme.ts` and `csv.ts`; the default is never hidden.
  - `[medium]` `[patch]` DW-1440's AC is checked only at the derivation (intent-alignment) — same root as the first row; the 403 half rests on the reproduction (200 with both grants).
  - `[medium]` `[patch]` No test covers a two-resource role (intent-alignment) — same root as the first row.
  - `[false]` `[reject]` Two sources for the globals database (intent-alignment) — both read the same configuration, and the split leg asserts they agree.
  - `[low]` `[patch]` "No data privilege beyond it" is untrue on a split namespace (intent-alignment) — corrected in place in `Installer.cls` and `docs/DEVELOPMENT.md`; the spine's AD-21 carries the sentence too (lead's).
  - `[low]` `[reject]` Batch b's Verification does not record EXPERIENCE.md's `wc -l` (intent-alignment) — the fix is a spec edit; 993 before and after is in the Auto Run Result.
  - `[false]` `[reject]` `## Auto Run Result` describes only batch a (intent-alignment) — it is written at finalize.

### 2026-09-30 — Code review (batch b)

- layers: blind-hunter, edge-case-hunter, verification-gap and acceptance-auditor, all Opus; none failed. 47 raw rows grouped into 38 entries: high 2, medium 3, low 32, false 1. 18 patched, 1 escalated (DW-1864), 19 closed; see `### Review Findings (batch b)`.
- `[high]` `[patch]` A composed validator status leaked its first error's text (blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor). Measured: `5002,5001` passes through `ValidatePassword` whole. Red in run 149; green in run 157.
- `[high]` `[patch]` An allow-listed 958 quoting the new password reached the 422 (acceptance-auditor). Measured: `1446,958` "Invalid password pattern '<password>'". Red in run 150.
- `[medium]` `[patch]` DW-1440's 403 half had no automated test (verification-gap, Rule 3). The anonymous request answered 200 in run 158, and was refused with an empty body in run 154.
- `[medium]` `[patch]` The validator's account name was unpinned (verification-gap). Red in run 151.
- `[medium]` `[escalated]` DW-1864, conversation restore past the string limit (blind-hunter, verification-gap, acceptance-auditor): out of footprint.
- Measured on `ocupilot-b-ci`: with a split namespace's globals grant and no routine grant, `/ocupsplitm` answered a server error page (`#5924`), not a 403. The probe objects read back absent.
- Rules: AD-39, AD-35, AD-49, AD-12, AD-33, AD-19, AD-8 and AD-21 (as the proposed amendments word them) match after the patches; the lead's amendment wording is in the stage report. Rule 3 is met: wire legs cover DW-1289, the new anonymous-request leg DW-1440, and `proposal-privilege` (c) DW-1669. No NFR touched.

### 2026-09-30 — Review pass (batch b, CI rework)

- verdicts: 9 findings — high 0, medium 0, low 6, false 3, maybe-false 0
- findings:
  - `[low]` `[patch]` The `seeded-injection` header said the filtered read carries the seed "whatever roles the instance has", but `View` filters the rows fetched at the read cap, by substring (verification-gap; `Screen/Tool/Read.cls:222-224`) — reworded to "the rows that name matches rather than every role"; the spec 2/2 after.
  - `[low]` `[reject]` The sweep's outcome is not recorded (verification-gap) — the fix is a spec edit; `## Auto Run Result` records the sweep's method and result.
  - `[false]` `[reject]` The leg ties the seed to the model only through the card text (intent-alignment) — the `[CI]` item names this narrowing; a one-row result is under the cut, so the card shows the result the dispatcher handed the model, and `InjectionChannels.TestEntityComment` pins the provider request.
  - `[low]` `[reject]` No browser leg now shows the model receiving a result longer than the card's cut (intent-alignment) — that was the `anywhere` leg's incidental coverage; DW-1210's "the model still receives the full result" is pinned by `TurnTools.TestALongToolResultReachesTheModelWhole` and the unfiltered `InjectionChannels.TestEntityComment` in CI's instance shards, and keeping `anywhere` unfiltered adds a branch to `scriptTurn`.
  - `[low]` `[reject]` The filter sits in the shared `scriptTurn`, so the `anywhere` leg's input changed too (intent-alignment) — same root as the previous row; `anywhere` asserts nothing on the tool card and passed.
  - `[false]` `[reject]` The seed now arrives through a read narrowed by name (intent-alignment) — it still enters only as that read's tool result, which is what AD-11 rule 5 pins.
  - `[low]` `[patch]` The header overstates, since the filter is a substring match (intent-alignment) — same root and patch as the first row.
  - `[low]` `[reject]` The sweep's result is not recorded (intent-alignment) — same root as the second row.
  - `[false]` `[reject]` The green result rests on the implementer's report (intent-alignment) — the stage agent re-ran the spec on `ocupilot-b-ci` before and after the patch: 2/2 both times, the deployed `index.html` equal to the build's.

### 2026-09-30 — Code review (batch b, CI rework)

- layers: blind-hunter, edge-case-hunter, verification-gap and acceptance-auditor, all Opus; none failed. 21 raw rows grouped into 15 entries: high 0, medium 0, low 12, false 3. 1 patched, 14 closed; see `### Review Findings (batch b rework 1)`.
- The `[CI]` item is fixed. (1) Every AD-11 rule 5 assertion of the `channels` leg is unchanged: no proposal card, URL and announcements unchanged, the card's result text has no child elements, no reply image requested, nothing off the origin, no CSP refusal. (2) No product file changed (`git diff 1617332d -- src ui/src` is empty), and `TOOLSTEPTEXTMAXLENGTH` is 4,096. (3) `filter` is declared in `Screen/Tool/Read.cls` `InputSchema` and reaches the screen's own `ApplyView` (AD-36); the name comes from `InjectionSeed.Target()`. (4) The sweep holds: only `seeded-injection` asserts on `.ocu-tool-call-result` text, `turn` reads the rows line (from `step.result`), and the rest read status words, tool names or failure diagnostics.
- Measured on `ocupilot-b-ci` (deployed `index.html` equal to the build's): the mutation red and the green re-run under Verification; the probe role reads back absent. `npm run test:tools` 1,731/1,731. CI run 36727128251 on 47e15e2b was queued at review time.

### 2026-09-30 — Review pass (batch c)

- verdicts: 20 findings — high 0, medium 3, low 12, false 5, maybe-false 0
- findings:
  - `[medium]` `[patch]` `RoleGrantsPrivilege`'s fail-closed branch (an `Exists` failure other than 883, or a failed `Get`) and `RoleEscalates`' handling of it ran under no test, since the unread principal fails `GetRecursedRoleSet` first (verification-gap) — `ProhibitedFixture` gains an armed role-read fault and a `RoleRead` accessor; the unreadable-role leg asserts the principal's role read answers an error (red alone in run 219) and that an armed per-role read failure counts as privileged for a caller who may read roles (red alone in run 220); run 224 8/8.
  - `[low]` `[patch]` `SecretSpelling`'s per-name assertion could not fail: an admitted name is a secret row, and `FieldRows` keeps ordinary rows only (verification-gap) — it now asserts no admitted name is among the field rows or the schema offered with nothing declared; red in run 222 when `FieldRows` keeps `secret` rows, run 223 2/2. The Story 8.5 spec's AC7 mutation record (`spec-8-5-x-509-import-edit-and-delete.md:501`, `:514`) is stale; that correction is the lead's.
  - `[low]` `[reject]` `Draft.Render` and the card's `payloadSecrets` still read the screen's whole secret list (verification-gap) — no shipped tool's payload or diff carries a declared secret it does not send (the layer's inference); the card is Epic 16's contended `core/proposal-view.ts` and the client holds no per-tool list, so the fix adds a mirrored field. wontfix-accepted, reopen_if a tool's payload or diff names a declared secret outside its own secret rows.
  - `[low]` `[reject]` `ProposalConfirm`'s password-unchanged assertion cannot move under the defect, since the vendor refuses the merged body (verification-gap) — the refusal and the live, unspent row are the pins (run 206), and the batch c mutation line records the vendor's 400; the password half is the matrix row's postcondition.
  - `[low]` `[reject]` `ScreenAction.Values`' per-tool narrowing has no pinning test (verification-gap) — Rule 19 binds one pin per AC and this bullet is not one; on shipped tools the two lists coincide (the one secret-valued action's `Password` is its own `SECRETBODY` name), so only a new fixture could tell them apart.
  - `[low]` `[patch]` The credential-name sentence told an author to declare the name, which `secretArguments` now refuses (verification-gap) — reworded in `Registry.cls` and `screen-mirror.mjs` to "which is not a declared secret of this screen's write tools (AD-3)", both pinned literals updated; `Descriptor` run 225 60/60, `npm run test:tools` 1,738/1,738.
  - `[false]` `[reject]` `OcuPilot.Test.Proposal` was edited but not run (verification-gap) — the implement stage ran it (run 171, 15/15) and the layer re-ran it (run 217, 15/15).
  - `[low]` `[reject]` The unreadable-role row is checked at the predicate, not at a mint (intent-alignment) — the spec's Red names the classifier leg for this defensive arm, since `CustomizationViolations` refuses such a caller's new role first (the spec's inference); the mint's privileged-to-destructive step is pinned by the `%Manager` leg through `Mint`.
  - `[medium]` `[patch]` The failure site the ledger names, `RoleGrantsPrivilege`, is fixed but never exercised (intent-alignment) — same root and patch as the first row.
  - `[false]` `[reject]` "Never a 500" holds on the authorization server arm only (intent-alignment) — a failed read answers OK and privileged on every arm (the web-application arm in run 208); only an exception raised inside `RoleEscalates` itself answers an error, as before this change, and no measured path raises one.
  - `[false]` `[reject]` The shared predicate changed the user and role arms, which the task does not name (intent-alignment) — there a failed read now counts as privileged instead of answering 500; those arms' screens require `%Admin_Secure:USE`, which reads roles (inference), so no outcome is worse.
  - `[medium]` `[defer]` `AddressGrantsPrivilege` (a service's `ClientSystems` roles) still judges a role by name, so `%Manager` there is minted non-destructive (intent-alignment) — pre-existing, the same defect class as DW-1663 in an arm batch c does not name; recorded in `deferred:`.
  - `[low]` `[reject]` The password-unchanged assertion cannot go red (intent-alignment) — same root as the fourth row.
  - `[low]` `[reject]` `ScreenAction.Values` routes a descriptor secret the tool does not send into the ordinary values (intent-alignment) — no shipped action declares such a value (the layer's own read of every `SCREENVALUES`); wontfix-theoretical, real when an action's value names a descriptor secret outside its tool's secret rows and `SECRETBODY`.
  - `[low]` `[reject]` The `ScreenAction.Values` change has no test or `mutation:` line (intent-alignment) — same root as the fifth row.
  - `[low]` `[patch]` `Confirm.cls:255-256` said the merge and the channel check read one declaration (intent-alignment) — the comment now says the merge sets only the keys the check admitted and the ledger's field list leaves out every declared name.
  - `[false]` `[reject]` The screen action's `SecretBody` and the confirm's merge still read the whole list (intent-alignment) — only admitted keys reach either, and `FieldNames` needs the whole list to keep every declared name out of the ledger.
  - `[low]` `[reject]` The accept arm runs against `SecretTool.Probe`'s authored secret, `ProposalScreen`'s declaration is now refused, and the registry and build AC is tested by direct calls (intent-alignment) — those calls are the functions load and build run, the shipped field-list reader is driven both ways (`UserCreate` run 214 accepts `Password`, the new `ProposalConfirm` leg refuses it), and no `SECRETBODY` name lies outside its tool's secret rows.
  - `[false]` `[reject]` The form change goes beyond the matrix, and no `oauth-server-editor` run is recorded (intent-alignment) — the spec's User-visible changes name the create default's line, and the spec ran 4/4 on the rebuilt bundle (Auto Run Result).
  - `[low]` `[patch]` New comments in `Test/Descriptor.cls` and `screen-mirror.test.mjs` named ledger ids (intent-alignment, prose discipline) — removed.

### 2026-09-30 — Code review (batch c)

- layers: blind-hunter, edge-case-hunter, verification-gap and acceptance-auditor, all Opus; none failed. 39 raw rows grouped into 34 entries: high 0, medium 3, low 30, false 1. 11 patched, 1 deferred (DW-1869, occurrence), 22 closed; see `### Review Findings (batch c)`.
- `[medium]` `[patch]` The screen-action channel did not apply the confirm channel's rule (blind-hunter, edge-case-hunter, acceptance-auditor): a value the screen declares secret and its tool does not send went to the ordinary values, the delta and the preview payload, where the confirm refuses it. Red in run 228; green in run 229.
- `[medium]` `[patch]` No real browser observed the privilege line DW-1663 moves (verification-gap, Rule 3). Red at `oauth-server-editor.browser-spec.mjs:278` under a mark-less form read; 4/4 after.
- `[medium]` `[defer]` DW-1869, the service `ClientSystems` arm's name-only judge (edge-case-hunter): pre-existing, outside batch c's tasks; occurrence appended.
- Focus (1), measured on `ocupilot-b-ci`: the 13 declared entries (nine descriptors) are each a top-level secret row, and every write tool's channel opens to exactly the declared secrets it sends; the secret and value suites ran green (runs 232-246). Focus (2): `RoleGrantsPrivilege` restores the namespace on every path, a failed `Exists`, `Get` or `GetRecursedRoleSet` answers privileged with an OK status, 883 alone reads as absent, and `RoleGrantsAdministrativePrivilege` cannot answer an error.
- Rules: AD-3, AD-5, AD-6, AD-8, AD-10, AD-16, AD-21, AD-35, AD-39, AD-53, AD-55 and AD-56 match after the patches. Rule 3 is met: the form read's marks over HTTP (`OAuthAuthorizationServerClients`), the line in a real browser, and the screen actions over HTTP (`UserUpdate`). No NFR touched.

## Design Notes

**Integration ACs (Rules 1 and 2):** No consumers in this story: it is a defect-fix story and introduces no service, module or shared component. `BackgroundSeed.Hold`, the fixture's `Linger`, and `Operation.Hold`/`Release` each have their consumer in the same batch. Consumes: none.

**Governing ADs (Rule 6), by batch:**

| Batch | ADs |
| --- | --- |
| a | Conventions › Tests, AD-27 |
| b | AD-39, AD-49, AD-35, AD-12, AD-33, AD-31, AD-8, AD-6, AD-19, AD-21, AD-9 |
| c | AD-10, AD-8, AD-5, AD-6, AD-56, AD-3, AD-21 |
| e | AD-34, AD-53, AD-13, AD-9, AD-39, AD-15 |
| d | AD-17, AD-18, AD-38, AD-45, AD-25 |

No AC contradicts an AD.

**Declined:** none.

**Why the fixes take these shapes:**

- **DW-1289:** routing through the validator scopes the channel by provenance (the documented policy check's verdict on the same password), not by the code 5001.
- **DW-1450:** `PermittedFields` filters ordinary rows only, and no shipped secret appears in any `PERMITTEDFIELDS` (measured). The tool's own secret rows are therefore the settable set that honours what the tool writes.
- **DW-48:** no tree move is needed, so Epic 16's new test classes cannot collide.

### Proposed amendments

The lead applies these at spec validation (Rule 20).

- **AD-39 (after "A second named exception…"):**
  - Add: "**A third: a refused self-service password change** (AD-49) carries the instance's policy verdict as the `newPassword` reason. That is the embedded 845 or 958, or the text `$SYSTEM.Security.ValidatePassword` returns when it refuses the same password. A refusal the validator does not confirm stays 500 [AMENDED 2026-09-30, Story 23.2, DW-1289]."
- **AD-33 (end of Rule):**
  - Add: "A tool step's `text` is its result cut to `Limits.TOOLSTEPTEXTMAXLENGTH` (4,096) characters, ending in U+2026 when cut; the model receives the whole result [AMENDED 2026-09-30, Story 23.2, DW-1210]."
- **AD-21 (:363):**
  - Replace "read-only on the install namespace's database and nothing else".
  - With "read-only on the install namespace's default globals database, which `%CSP.REST`'s access check tests, and on its routines database, which holds OcuPilot's code (one grant where they coincide), and nothing else [AMENDED 2026-09-30, Story 23.2, DW-1440]".
- **AD-34 (:505):**
  - Replace "the token is claimed under a lock or a conditional update that exactly one caller can win".
  - With "the token is claimed by a conditional update exactly one caller can win, and every write to one scoped target, a confirm or a screen row action, holds that target's lock from its fresh read through its port write; a caller that cannot take it within the wait is refused 409 and changes nothing [AMENDED 2026-09-30, Story 23.2, DW-1497]".
- **AD-53 (:739):**
  - Replace "inside the single atomic transition (AD-10, AD-34)".
  - With "(AD-10), and AD-34's per-target lock held from the fresh read through the port write, so a row action and a confirm on one target are ordered by OcuPilot, not by the vendor endpoint [AMENDED 2026-09-30, Story 23.2, DW-1497]".
- **AD-17 (after "…never maintained separately."):**
  - Add: "The container start path compiles the roster's test-scope package only when the throwaway's `OCUPILOT_LOAD_TESTS` is 1, so a product start compiles no `OcuPilot.Test.*` class [AMENDED 2026-09-30, Story 23.2, DW-48]."

### User-visible changes

- **DW-1289 (b):** with a validation routine configured, Account › Change password shows the routine's sentence under New password instead of "An internal error occurred".
- **DW-1210 (b):**
  - An expanded tool-call card shows a long result's first 4,095 characters, then "…".
  - A turn with many long results no longer fails its poll.
- **DW-1669 (b):** after a turn ends, a live proposal card's privilege line warns within about 15 s of a revocation, and clears again if the privilege is restored.
- **DW-1440 (b):**
  - No change on this image.
  - On a namespace whose two databases differ, the shell and readiness load instead of answering a bodyless 403.
- **DW-1663 (c):** an agent proposal that adds `%Manager`, `%Operator`, `%SecurityAdministrator`, or any role reaching `%All` or an `%Admin_*` resource, to the authorization server's customization roles:
  - takes the destructive treatment, and names the privilege;
  - is shown by the OAuth 2.0 authorization server form with its privilege line. That includes the create form's defaults, which carry `%Manager`.
- **DW-1497 (e):** a row action or a confirm against a target that another write holds waits up to 10 s, then answers "Another change to this target is being applied. Try again in a moment."
- **DW-48 (d):** a container started from the repository's compose file compiles no `OcuPilot.Test` class.

### Document corrections at origin

- **Implement passes:**
  - EXPERIENCE.md:612, in place (DW-1210).
  - `docs/DEVELOPMENT.md:293-294` (DW-1440).
  - The code comments named in each task.
- **Lead:**
  - The six amendments above.
  - `spec-15-1-change-your-own-password.md:170`, "only for 845 and 958" (DW-1289).

### Residuals and owner actions

**Residuals:**

- **DW-1829:** the screen and admin-API legs pause a live compact over HTTP, where the hold cannot be used, because the CSP worker's `Request()` takes the same lock. They pause back to back, answered 200 when measured, and have no CI sighting. The lead names them in the trailer.
- **DW-1497:** the 21 per-entity Save handlers (AD-55) take no hold. Sixteen call their port directly, and Epic 16's 16.13 and 16.14 edit two of them. The lead files one new entry (owner `burndown`) for the Save route.
- **DW-1366** (not one of the twelve) closes as a side effect of DW-1497 (`ProposalSpelling` 500 → 409). The lead records it.
- **DW-48:** a volume that compiled `OcuPilot.Test.*` before this change keeps those classes until `$System.OBJ.DeletePackage("OcuPilot.Test")` is run. The product path does not delete them. `Install.DemoTask` is not a Test class and is outside this AC.

**Owner action:**

- `../OcuPilot-slot-b/compose.yml` needs `OCUPILOT_LOAD_TESTS: "1"` before its next refresh.
- The slot-C file, if revived, needs the same.

## Verification

Slot B (`_bmad/custom/parallel.yaml`, `slots: b`). MCP profile `ocupilot-slot-b`. The throwaway is `ocupilot-b-ci`: dir `/tmp/ocupilot-b-ci`, project `ocupilot-b-ci`, web 52777, super 1976, `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777`, `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci`. Never send two test calls in one message.

**Shared loop steps:**

- **Load source (loop):** `rsync -a --delete src/ /tmp/ocupilot-b-ci/src/`, then `Do $System.OBJ.LoadDir("/opt/ocupilot/src","ck-d",.e,1)` in `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`. Expected: 0 errors. Recompile the affected package before reading any mutation.
- **One class (loop):** `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`. Expected: 0 failed, confirmed in `%UnitTest_Result`.
- **One browser spec (loop):** `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/<name>.browser-spec.mjs`. Expected: every leg passes.
- **Checks (loop):** `uv run scripts/check-objectscript.py <changed files>` is clean. When Markdown changed: `bash scripts/lint-docs.sh` is clean, and `wc -l` on EXPERIENCE.md is unchanged.

**Batch a (loop):**

- Classes: `BackgroundTasksLive`, `OAuthServerDiscover`, `OAuthServerJwks`, `OAuthServerWire`, `OAuthClientRegister`, `OAuthClientUpdate`, `OAuthClientWire`, `InjectionEgress`.
- Specs: `background-tasks`, `local-databases`, `oauth-server-description-editor`, `oauth-client-editor`.
- `mutation:` drop the `Hold` call → the agent leg goes red (the compact is Done at about 1.9 s and the confirm is refused). Observed: run 98 red on `TestTheAgentsConfirmPausesACompact` alone (the mint read Done, the confirm answered 409 `TASK.BACKGROUND.STATE`, no pause request recorded); reverted, run 99 7/7.
- `mutation:` restore close-and-reopen per connection → the linger leg goes red (two cases answer "unreachable"). Observed: run 89 red on `TestTheDocumentCasesHoldAgainstALingeringIssuer` alone (`/not-json` and `/wrong-issuer` answered 422 `OAUTH.DISCOVERY.UNREACHABLE`); reverted, run 90 6/6.
- `mutation:` drop the linger `Start` passes to `Serve` → the linger leg's elapsed-time assertion goes red alone. Observed: run 109 red (the four cases took 0.011 s, against 0.919 s in run 108); reverted byte-identical, run 110 6/6.
- `mutation:` drop the flush in `Converse` → the linger leg's first-case assertion goes red alone. Observed: run 112 red (the first case took 0.311 s, against 0.001 s in run 113); reverted byte-identical, run 113 6/6.
- `mutation:` have `PortalControl` answer OK in place of the vendor's `Pause()` → the agent leg's pause-request assertion goes red while its confirm applies (the screen leg's Paused re-read also goes red). Observed: run 114; reverted byte-identical, run 115 7/7.
- Observed: all eight classes green on the reverted tree (runs 90-97, 99), and the four specs pass on a rebuilt and redeployed bundle.

**Batch b (loop):**

- Classes: `AccountPasswordWire`, `LedgerStep`, `TurnStream`, `TurnTools`, `WebApp`, `Smoke`.
- Tiers: `npm run test:tools` (`turn.test.mjs` and EXPERIENCE.md's citations), `npm run test:components`. Specs: `proposal-privilege`, `seeded-injection`.
- DW-1440 reproduction, before the fix (measured on `ocupilot-b-ci`, then removed):
  - `%DB_USER` carries no public permission, so namespace `OCUPSPLIT` took Globals `USER` and Routines `HSCUSTOM`, and no database was created. `$zu(90,21,"OCUPSPLIT")` read `11^^/durable/iris/mgr/user/^%DB_USER^8194`.
  - Unauthenticated `/ocupsplit` dispatching to `OcuPilot.Api.Readiness`, `MatchRoles` `:OcuPilotSplitProbe`. With the role granting `%DB_HSCUSTOM:R` only: `HTTP/1.1 403 Forbidden`, `CONTENT-LENGTH: 0`, no body. With `%DB_HSCUSTOM:R,%DB_USER:R`: `HTTP/1.1 200 OK`, `{"installed":false,"version":"","state":"unreadable"}`.
  - `Security.Roles` stored `%DB_USER:R,%DB_HSCUSTOM:R` as `%DB_HSCUSTOM:R,%DB_USER:R`, and a six-resource set in `$Order` collation order.
  - The application, the role and the namespace were deleted and each read back absent; `/ocupsplit` then answered 404.
- `mutation:` delete the `ValidatePassword` arm → run 122 red on `TestAValidationRoutineRefusalCarriesTheRoutinesSentence` alone (neither refusal answered 422; the setting and the routine still read back removed); reverted byte-identical, run 124 6/6.
- `mutation:` drop the `NOSUCHUSERCODE` test → run 123 red on `TestAnUnconfirmedRefusalStaysAnInternalError` alone (the `1446,838` leg answered 422); reverted byte-identical, run 124 6/6.
- `mutation:` cut at `TEXTMAXLENGTH` again → run 119 red on `TestALongTurnsProgressStillSerializes` (`<MAXSTRING>` from `%ToJSON()`) and on the cap leg of `TestAToolStepStoresTheResultContentTheModelWasHanded`; reverted byte-identical, run 120 4/4.
- `mutation:` hand the model the step's cut text in `Loop.AnswerTools` → run 135 red on `TurnTools.TestALongToolResultReachesTheModelWhole` (and on `TestAReplysToolResultsShareOneBudget`); reverted byte-identical, run 136 13/13.
- `mutation:` never arm the re-read → `turn.test.mjs` 72/76, four re-read cases red (the nothing-armed case asserts absence and stays green), and on the rebuilt bundle `proposal-privilege` (c) red at its 20 s re-read wait while (a) and (b) passed; reverted byte-identical, `turn.test.mjs` 76/76 and the rebuilt bundle's spec 3/3.
- `mutation:` derive the routines database only → run 126 red on `TestTheFloorCoversASplitNamespacesTwoDatabases` alone (derived `%DB_HSCUSTOM` only); reverted byte-identical, run 127 26/26.
- `mutation:` grant only the first floor resource → run 143 red on `TestTheFloorCoversASplitNamespacesTwoDatabases` alone ("granted read on both, in collation order"); reverted byte-identical, run 145 26/26.
- `mutation:` count any validator error as a refusal → run 139 red on the routine leg's raising-routine assertions (the wire answered 422 carrying `<DIVIDE>Boom+1^OcuPilotPwProbe`); reverted byte-identical, run 144 6/6.
- `mutation:` answer 422 whenever the validator is consulted → run 141 red on `TestAnUnconfirmedRefusalStaysAnInternalError` ("a 5001 the validator does not confirm stays a 500") and the raising-routine assertions; reverted byte-identical, run 144 6/6.
- `mutation:` drop the quoted-sentence fallback → run 142 red on the Quote leg and the current-password leg; reverted byte-identical, run 144 6/6.
- `mutation:` ignore the current password in `QuotesPassword` → run 140 red on the current-password leg alone; reverted byte-identical, run 144 6/6.
- `mutation:` merge a re-read's line only when it warns → `turn.test.mjs` 77/78, the clearing case red; reverted byte-identical, 78/78.
- `mutation:` stop the re-read before the turn request → `turn.test.mjs` 77/78, the refused-send case red; reverted byte-identical, 78/78.
- `mutation:` accept a validator refusal code anywhere in its status (the pre-review form) → run 149 red on the composed-status leg alone (the 422 carried "ObjectScript error: OcuProbeInternal"); reverted byte-identical, run 157 6/6.
- `mutation:` drop the policy arm's quote check → run 150 red on the pattern leg alone (the 422 carried the new password); reverted byte-identical, run 157 6/6.
- `mutation:` call `ValidatePassword` without the account name → run 151 red on the account-name leg alone (500); reverted byte-identical, run 157 6/6.
- `mutation:` derive the routine database only → run 154 red, and the anonymous request was refused with an empty body; reverted byte-identical, run 158 26/26.
- `mutation:` cut at `>=` the cap → run 156 red on the edge leg alone; reverted byte-identical, run 159 4/4.
- `mutation:` stop the re-read on a 404 only → `turn.test.mjs` 79/80, the refusal case red; reverted byte-identical, 80/80.
- `mutation:` drop the turn check from `hasLiveProposal` → `turn.test.mjs` 79/80, the later-turn case red; reverted byte-identical, 80/80.
- `mutation:` send `seeded-injection`'s scripted roles read with no `filter` → the `channels` leg alone red at "the tool card shows the seed's marker as text" (the card held the unfiltered roles result, without the marker), `anywhere` green; reverted byte-identical, the browser spec 2/2.
- Code review pass: green on the reloaded tree (`OCUPILOT-LOAD:OK:errors=0`): `AccountPasswordWire` run 157 (6/6), `WebApp` 158 (26/26), `LedgerStep` 159 (4/4), `TurnTools` 160 (13/13) and `Smoke` 161 (40/40). Also `npm run test:tools` 1,731/1,731, `npm run test:components` 1,958 tests in 145 files, and `proposal-privilege` 3/3 on a rebuilt, redeployed bundle (initial total 2.31 MB). `check-objectscript.py` and `lint-docs.sh` report no problems.

**Batch c (loop):**

- Classes: `OAuthAuthorizationServerUpdate`, `OAuthAuthorizationServerClients`, `OAuthAuthorizationServerWire`, `UserCreate`, `UserCreateWire`, `UserUpdate`, `Descriptor`, `ProposalConfirm`, `ConfirmRoute`.
- Tiers: `npm run test:tools` (screen-mirror), `npm run test:components` (the oauth-server-form store), `npm run build`. Spec: `oauth-server-editor`.
- `mutation:` restore name-only `IsPrivilegedRole` in `AddsPrivilegedCustomizationRole` → run 192 red on `TestAPrivilegedCustomizationRoleIsMintedDestructive` (the `%Manager` leg) and on `TestAnUnreadableRoleCountsAsPrivileged`'s authorization server arm (a name-only judge reads `%Developer` as unprivileged whatever the read); reverted byte-identical, run 193 8/8.
- `mutation:` read a failed role read as "no resources" (`RoleEscalates` answers not privileged on a failed `GetRecursedRoleSet`) → run 194 red on `TestAnUnreadableRoleCountsAsPrivileged` alone, both its authorization server and web-application arms; reverted byte-identical, run 195 8/8.
- `mutation:` read an absent role (883) as a failed read in `RoleGrantsPrivilege` → run 196 red on that method's absent-role assertion alone; reverted byte-identical, run 197 8/8.
- `mutation:` `HandleForm` answers the role names without `MarkedRoles` → run 198 red on `OAuthAuthorizationServerClients.TestTheReadNamesTheRegisteredClients`'s mark assertion alone; reverted byte-identical, run 199 6/6.
- `mutation:` the store reads a missing mark as not privileged → `npm run test:components` 1,966/1,968, the two privilege cases red (the `%Admin_Secure` leg, the unread create); judging by name again → the same two red (the `%Manager` leg, the create default); each reverted byte-identical, 1,968/1,968.
- `mutation:` re-admit the ordinary source (a settable name) in `Registry.ConfirmChannelProblem` → run 200 red on the `Descriptor` confirm-channel test alone (its `Path`, `Timeout`, `AutoCompile` and `CorsAllowlist` legs), run 201 on both `SecretSpelling` methods, run 202 on `UserCreate`'s `Timeout` leg; the same in `screen-mirror.mjs` → `screen-mirror.test.mjs` 60/62, both confirm-channel tests red at the `Path` leg; reverted byte-identical, runs 203 (60/60), 204 (2/2) and 205 (9/9), `npm run test:tools` 1,738/1,738.
- `mutation:` drop the per-tool intersection (`ChannelProblem` reads the descriptor's whole list) → run 206 red on `TestAnUpdateConfirmCarryingAPasswordIsRefused` alone (the confirm admitted and the row claimed); its password assertion stayed green because the vendor refuses that body: measured under the same mutation, the claimed confirm answered 400 `PORT.VALIDATION` with the password and `FullName` unchanged; reverted byte-identical, run 207 21/21.
- `mutation:` answer OK in `RoleGrantsPrivilege` for a role it cannot read (`If 'tExists Quit`) → run 219 red on `TestAnUnreadableRoleCountsAsPrivileged`'s role-read assertion alone; reverted byte-identical, run 224 8/8.
- `mutation:` drop `$$$ISERR(tReadSC) ||` from both reads in `RoleEscalates` → run 220 red on that test's armed per-role read assertion alone; reverted byte-identical, run 224 8/8.
- `mutation:` let `Write.FieldRows` keep `secret` rows → run 222 red on `SecretSpelling.TestAnAdmittedSpellingIsNeverOffered` (`PrivateKeyFile` and `PrivateKeyPassword` offered); reverted byte-identical, run 223 2/2.
- `mutation:` drop the refusal of a declared secret the tool does not send from `ScreenAction.Values` → run 228 red on `ProposalConfirm.TestAScreenActionRefusesADeclaredSecretItsToolDoesNotSend` alone (the value reached the ordinary values); reverted byte-identical, run 229 22/22.
- `mutation:` `HandleForm` answers the role names without `MarkedRoles` → `oauth-server-editor` AC1 red alone at `:278` (the privilege line stayed once `%Manager` was unticked); reverted byte-identical, the spec 4/4.
- Code review pass: green on the reloaded tree (`OCUPILOT-LOAD:OK:errors=0`), one class at a time: `ProposalConfirm` run 229 (22/22), `OAuthAuthorizationServerUpdate` 230 (8/8), `SecretSpelling` 231 (2/2), and the shipped secret and value channels in runs 232-246 (`OAuthAuthorizationServerSecret`, `OAuthServerToken`, `SslSecret`, `WalletSecretUpdate`, `WalletSecretCreate`, `OAuthClientSecrets`, `OAuthRegisteredClientSecret`, `OAuthResourceServerSecret`, `X509Import`, `UserSignIn`, `UserUpdate`, `AuditPurge`, `RoleUpdate`, `RoleCreate`, `RoleSave`: 119 tests, 0 failed). A probe of all 116 write tools' `ChannelSecretNames` read every declaration and opened each to exactly the declared secrets its tool sends. `npm run test:tools` 1,738/1,738, `oauth-server-editor` 4/4 against the batch c bundle (deployed `index.html` equal to the build's), `check-objectscript.py` and `lint-docs.sh` 0 problems, EXPERIENCE.md 993 lines.

**Batch e (loop):**

- Classes: `ReadBackRoute`, `ProposalSpelling`, `ProposalConfirm`, `AccountPasswordWire`.
- `uv run scripts/test_check_objectscript.py`, then `uv run scripts/check-objectscript.py` over the whole tree. Expected: green, 0 problems.
- `mutation:` delete the hold in `ScreenAction.Run` → the `ReadBackRoute` busy leg goes red.
- `mutation:` release before `ApplyAt` → the confirm leg goes red.
- `mutation:` drop the marking-tool arm → the unguarded-probe harness case goes red.
- `mutation:` have `PolicyText` read index 1 → the `AccountPasswordWire` policy leg goes red.

**Batch d (loop):**

- Tiers: `npm run test:tools` (`compose.test.mjs`, `ci.test.mjs`).
- Runner step: restart in product mode, then check the Test.* count is 0 and `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` is green. Then restore test mode and confirm the count is back to 827 or more.
- `mutation:` set the flag in `docker-compose.yml` → the compose test goes red.
- CI's `images` job is the behavioral proof, and the `instance` job proves the test paths.

**Once, before the last batch's dev_complete:**

- Full ObjectScript sweep: `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci`, with totals checked in `%UnitTest_Result`. Expected: 0 failed, non-zero count.
- `cd ui && npm run build && npm test`, then smoke. Expected: green.
- The full browser suite is CI's (Rule 29).
- `bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md slice 23-2-the-range-end-cleanup-part-2` reads empty once the lead has written the trailers.

## Auto Run Result

**Batch c (security: DW-1663, DW-1450).** Batches e and d are untouched and stay unchecked.

- **DW-1663:** `AddsPrivilegedCustomizationRole` judges each added role with `RoleGrantsAdministrativePrivilege` (`%All`, or an `%All` or `%Admin_*` resource in its closure). `RoleEscalates` counts a failed `GetRecursedRoleSet` or per-role read as privileged with an OK status; `RoleGrantsPrivilege` tells an absent role (883, grants nothing) from one it cannot read (an error). The form read answers `roles:[{name, privileged}]` (`MarkedRoles`); the store drops `isPrivilegedRole` and counts a missing mark as privileged, so the create default `%Manager` shows the privilege line.
- **DW-1450:** a `secretArguments` name must be a top-level secret row of the screen's write tools, with one sentence in `Registry.cls` and `screen-mirror.mjs`; `fingerprintExcludes` keeps its sources. The confirm channel and a screen action's secret values open only to the declared secrets the tool itself sends (`Write.ChannelSecretNames`: its secret rows and `SECRETBODY` names).
- **Files:** `Kernel/Proposal/Prohibited.cls` (the classifier), `Area/Security/OAuthAuthorizationServerRules.cls` (`MarkedRoles`), `Screen/Tool/OAuthAuthorizationServerCreate.cls` (model text), `Screen/Registry.cls` and `ui/tools/screen-mirror.mjs` (the rule and the credential sentence), `Screen/Tool/Write.cls` and `Screen/Tool/Registry.cls` (`ChannelSecretNames`), `Kernel/Proposal/Confirm.cls` and `Api/ScreenAction.cls` (the narrowed channel), `ui/src/app/areas/security/oauth-server-form.store.ts` (the mark), and tests: `Test/{OAuthAuthorizationServerUpdate,OAuthAuthorizationServerClients,ProposalConfirm,Descriptor,UserCreate,SecretSpelling,Proposal,ProposalScreen,ProhibitedFixture,SecretTool/Probe}.cls`, `ui/tools/screen-mirror.test.mjs`, `oauth-server-form.store.spec.ts`, `oauth-server-form.page.spec.ts`.
- **Review:** 20 findings (medium 3, low 12, false 5). Patched: medium 1 (the unexercised role-read branch), low 4 (the `SecretSpelling` assertion, the credential sentence, a `Confirm.cls` comment, ledger ids in two comments). Deferred 1 (medium: the service `ClientSystems` name-only judge). Rejected, reasons in the batch c triage entry: the draft and card reading the whole list (theoretical), the password-unchanged assertion (the vendor refuses), the unpinned `ScreenAction` narrowing and its non-own secret routing (theoretical), the predicate-level unreadable leg (the spec's Red), the fixture and direct-call surfaces, and five false.
- **Follow-up review:** not recommended (a follow-up pass that patched no high; patched high 0, medium 1, low 4).
- **Verification on `ocupilot-b-ci`** (`OCUPILOT-LOAD:OK:errors=0` after the last edit):
  - Batch c's classes before review: runs 208-216 green (`OAuthAuthorizationServerUpdate` 8/8, `Clients` 6/6, `Wire` 7/7, `Descriptor` 60/60, `ProposalConfirm` 21/21, `ConfirmRoute` 6/6, `UserCreate` 9/9, `UserCreateWire` 5/5, `UserUpdate` 23/23). After the patches: `OAuthAuthorizationServerUpdate` run 224 8/8, `SecretSpelling` 223 2/2, `Descriptor` 225 60/60, and the fixture's other users `Prohibited` 226 13/13 and `ProhibitedByEffect` 227 8/8.
  - `npm run test:tools` 1,738/1,738 (after the patches); `npm run test:components` 1,968/1,968; `npm run build` passed its prebuild checks, initial total 2.31 MB, no generated file changed; `oauth-server-editor` 4/4 on the redeployed bundle (deployed `index.html` equal to the build's).
  - Mutations: as recorded under Batch c's Verification. `check-objectscript.py` 0 problems; no non-ASCII byte added. The probe principal reads back removed.
  - Three single-class runner calls (runs 223-225) went out in one message; their `%UnitTest_Result` times show them back to back, and the runner counted 0 overlaps.
- **Residual risks:** the deferred service `ClientSystems` judge; `ui/src/app/core/proposal-view.ts:170` and `ui/tools/proposal-view.test.mjs:312` still describe the old name rule in comments (Epic 16's contended file); the Story 8.5 spec's AC7 mutation record is stale (lead).

Status: done
Blocking condition: none
