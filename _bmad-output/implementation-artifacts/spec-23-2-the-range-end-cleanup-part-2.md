---
title: 'Story 23.2: The range-end cleanup, part 2'
type: 'bugfix'
created: '2026-09-30'
status: 'done'
baseline_revision: '1a409d00a3083e6a604087af7dfd371e6dd4aa03'
baseline_commit: '1a409d00a3083e6a604087af7dfd371e6dd4aa03'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['multiple-goals', 'oversized']
deferred: []
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

- [ ] **DW-1289** — A refusal by a `PasswordValidationRoutine` answers 500.
  - **Measured on `ocupilot-b-ci`** (plan stage; the probe was removed):
    - `ChangePassword` answers `1446,5001`, where the second text is the routine's sentence. A wrong current password answers `1446,952` first; a pattern failure answers `1446,845`.
    - `$SYSTEM.Security.ValidatePassword(new, user)`, called by a principal holding only `%DB_HSCUSTOM:RW`, answers `5001` with the routine's sentence, `845` for a pattern failure, and OK otherwise.
  - **Fix:** in the arm that renders 500 today (codes carry none of 952, 845, 958 or 838), call `ValidatePassword(<new>, $Username)` in the caller's process (AD-49).
    - If it refuses, answer 422 `ACCOUNT.VALIDATION` with one `newPassword` violation (`ACCOUNTPASSWORDPOLICY`). Its reason is the validator status's first error text; an empty text, or one containing either password, is replaced by `REASONACCOUNTPASSWORDPOLICY`.
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
- [ ] **DW-1210** — `GuardedFinishTool` stores each tool result up to 131,072 characters, and `GuardedRows` projects every step's text on every 1 s poll.
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
- [ ] **DW-1669** — `pollUntilTerminal` stops when the turn ends, so a live card's privilege line keeps its last answer. `WireRow` evaluates the line on each read, but only the progress poll and conversation restore carry it.
  - **Fix, in `ui/src/app/core/turn.ts`:**
    - Once the turn has ended, re-read `GET /turn/:id/progress` every 15 s (an injectable `rereadMs`, default 15,000) while at least one of its proposals is live and unexpired on the panel.
    - Keep a proposal-id-to-turn-id map, filled in `pollOnce`.
    - Stop when none is live, on a 404, on a new send, and at `endSession` or `newConversation`. Skip a tick while the document is hidden; the probe is injectable, so `core/` stays framework-free (AD-19).
    - Merge only `privilege`, and only into rows that are still live locally with no confirm, cancel or draft in flight.
  - Why this is safe: a terminal turn's poll renews no lease (`Api/Turn.cls:232-235`), and its row outlives the proposal (15 min against 10). The server does not change.
  - **Red:**
    - New `ui/tools/turn.test.mjs` cases on `fakeSchedule`: the re-read is armed at 15,000 ms and sets `missing`; nothing is armed without a live proposal; an in-flight confirm is left alone; the re-read stops at expiry.
    - A new case (c) in `ui/browser/proposal-privilege.browser-spec.mjs`: the turn completes, the pair is revoked, and the line warns.
  - Files: `ui/src/app/core/turn.ts` (comments at :1356-1360 and :1575-1590), `ui/tools/turn.test.mjs`, `ui/browser/proposal-privilege.browser-spec.mjs`. ADs: AD-8, AD-6, AD-7, AD-19, AD-33, AD-43.
  - AC: Given a turn that has ended with a live proposal whose pair is then revoked, when 15 s pass, then the card's privilege line warns and names the pair.
- [ ] **DW-1440** — `CodeDatabaseResource` derives the floor role's grant from the routines database. `%CSP.REST` `AccessCheck` tests the default globals database's resource, `$Piece($zu(90,21,$namespace),"^",4)`, and answers a bodyless 403 when it fails.
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

### Batch c: security

- [ ] **DW-1663** — `AddsPrivilegedCustomizationRole` judges by name only. `%Manager`, `%Operator` and `%SecurityAdministrator` carry `%Admin_*:U` resources (measured on slot B), yet are minted non-destructive. `RoleGrantsPrivilege` reads a failed `Security.Roles.Get` as "no resources", which fails open.
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
- [ ] **DW-1450** — `ConfirmChannelProblem` and the mirror accept a `secretArguments` name that is any ordinary field or read field of the identifier's tools. At confirm, `ChannelProblem` admits the descriptor's whole list for every tool, and `WithSecrets` sets it into the body after the AD-10 gate has run.
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

## Spec Change Log

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
  - An expanded tool-call card shows a long result's first 4,096 characters, ending in "…".
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
- Observed: all eight classes green on the reverted tree (runs 90-97, 99), and the four specs pass on a rebuilt and redeployed bundle.

**Batch b (loop):**

- Classes: `AccountPasswordWire`, `LedgerStep`, `TurnStream`, `WebApp`, `Smoke`.
- Tiers: `npm run test:tools` (`turn.test.mjs` and EXPERIENCE.md's citations), `npm run test:components`. Spec: `proposal-privilege`.
- Before the fix: the DW-1440 reproduction output is recorded.
- `mutation:` delete the `ValidatePassword` arm → the routine leg answers 500 (red).
- `mutation:` cut at `TEXTMAXLENGTH` again → the `LedgerStep` cap and `<MAXSTRING>` legs go red.
- `mutation:` never arm the re-read → the `turn.test.mjs` re-read case goes red.
- `mutation:` derive the routines database only → the `WebApp` split-namespace leg goes red.

**Batch c (loop):**

- Classes: `OAuthAuthorizationServerUpdate`, `OAuthAuthorizationServerClients`, `OAuthAuthorizationServerWire`, `UserCreate`, `UserCreateWire`, `UserUpdate`, `Descriptor`, `ProposalConfirm`, `ConfirmRoute`.
- Tiers: `npm run test:tools` (screen-mirror), `npm run test:components` (the oauth-server-form store), `npm run build`. Spec: `oauth-server-editor`.
- `mutation:` restore name-only `IsPrivilegedRole` → the `%Manager` leg goes red.
- `mutation:` read a failed role read as "no resources" → the fail-closed leg goes red.
- `mutation:` re-admit the ordinary source → the `Path` legs go red in both `Descriptor` and `screen-mirror.test.mjs`.
- `mutation:` drop the per-tool intersection → the `ProposalConfirm` `Password` leg goes red.

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

**Batch a pass (DW-1829, DW-1831).** Batches b, c, e and d are untouched and stay unchecked.

- **Change:**
  - DW-1829: the agent leg holds its seeded compact's lock before the resume, waits 3 s, then mints and confirms. It asserts the confirm applies, the vendor records the pause request, and the ledger row and marker land. The retry loop is gone.
  - DW-1831: the issuer fixture listens once and answers each connection on a forked device, flushed, lingering, then closed. The new leg runs the four document cases back to back at a 0.3 s linger and asserts the linger was in effect.
- **Files:**
  - `src/OcuPilot/Test/BackgroundSeed.cls`: `Hold`, `RequestOf`, a shared `Read`; `Remove` cancels a held task before releasing it.
  - `src/OcuPilot/Test/BackgroundTasksLive.cls`: the held agent leg; `AGENTATTEMPTS` and its helpers deleted.
  - `src/OcuPilot/Test/OAuthIssuerFixture.cls`: one listening port, `Select`/`Fork` per connection, `Converse`, a `pLinger` argument on `Start`.
  - `src/OcuPilot/Test/OAuthServerDiscover.cls`: `TestTheDocumentCasesHoldAgainstALingeringIssuer`, with shared `DocumentCases` and `AssertCauses`.
- **Review:** 10 findings. Three were patched (1 medium, 2 low): the linger timing assertion, `Hold`'s lock-timeout bound, and the class header. Seven were rejected, each with its reason in the triage log. Nothing was deferred.
- **Follow-up review:** not recommended; no high was patched, and only one medium.
- **Verification on `ocupilot-b-ci`:**
  - The loader printed `OCUPILOT-LOAD:OK:errors=0` after the last edit.
  - The eight batch a classes read 0 failed in `%UnitTest_Result`: runs 100-107, then 110 (`OAuthServerDiscover`) and 111 (`BackgroundTasksLive`) on the patched tree.
  - The four browser specs passed against the bundle rebuilt from this tree (`index.html` checksum equal in `dist/` and in the container): background-tasks 2/2, local-databases 6/6, oauth-server-description-editor 4/4, oauth-client-editor 5/5.
  - `check-objectscript.py` reported 0 problems, and `lint-docs.sh` reported 0 issues.
  - Mutations: runs 98/99 and 89/90 (implement) and 109/110 (review), as listed under Verification.
- **Residual risks:**
  - The screen and admin-API legs keep the resume-then-pause window (spec residual).
  - The hold outlasts the compact's work only by the 10 s lock timeout.

Status: done
Blocking condition: none
