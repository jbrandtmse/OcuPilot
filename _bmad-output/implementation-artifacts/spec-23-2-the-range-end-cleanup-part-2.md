---
title: 'Story 23.2: The range-end cleanup, part 2'
type: 'bugfix'
created: '2026-09-30'
status: 'in-progress'
baseline_revision: '1d8b3cac2be77471d7408d32560e922a9cb9399b'
baseline_commit: '1d8b3cac2be77471d7408d32560e922a9cb9399b'
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
  - summary: >-
      A Windows clone made with core.autocrlf=true before the `*.sh text eol=lf` rule keeps its CRLF scripts after pulling the rule, and `git status` reads clean, so it still fails `docker compose up --wait` until its scripts are checked out again.
    evidence: |-
      Measured by the DW-1870 verification-gap layer in a scratch repo: a pre-rule clone fast-forwarded onto the rule kept 16 of 16 scripts with CR, and `git checkout -- .` left them so; deleting the scripts and checking them out again gave 0 of 16. The remedy is a user step (a release-note or README line), outside the task's Fix.
    location: >-
      .gitattributes:3
    severity: medium
  - summary: >-
      `.githooks/pre-commit` is a bash script with no `.sh` suffix, so the rule leaves its line endings unset and a Windows core.autocrlf=true clone checks it out with CRLF.
    evidence: |-
      `git check-attr eol text -- .githooks/pre-commit` answers `unspecified` for both. That Git for Windows' bash then fails on it is (inference). It is an opt-in host-side developer hook, not the container start path, and the task's Fix names `*.sh` only.
    location: >-
      .githooks/pre-commit:1
    severity: low
  - summary: >-
      The background seed writes about 1.2 GB each time a test fills it, and on a CI runner the instance suspended every update for 30 s for low WIJ free space while those fills ran, which stalls whatever else the shard is running.
    evidence: |-
      Run 36741141564 attempt 1, shard 2/3 `messages.log`: WIJ expansions during the seed fills, "Updates suspended due to low free space in the WIJ" at 16:12:17, "updates resumed" at 16:12:47. That the fills cause it is (inference). The DW-1829 follow-up makes the teardown tolerate the stall; it does not remove it.
    location: >-
      src/OcuPilot/Test/BackgroundSeed.cls:28
    severity: low
  - summary: >-
      The follow-up's stand-in for CI's stall is a stopped job, not a write suspension, so whether `ENDSECONDS` covers every stall a CI runner produces is unverified.
    evidence: |-
      The one observed incident fits: its compact acted on the cancel at 16:12:58.6, about 15 s into the teardown (inference from the log's timestamps), inside the new bound. It settles on a CI run where `BackgroundTasksLive`'s teardown fails again with this fix in place.
    location: >-
      src/OcuPilot/Test/BackgroundSeed.cls:43
    severity: medium (unverified)
  - summary: >-
      A screen's own Save takes no per-target hold, so a Save and an agent confirm on one target can still interleave between one's fresh read and the other's write.
    evidence: |-
      Five OAuth Save handlers (`OAuthClientSave`, `OAuthServerSave`, `OAuthResourceServerSave`, `OAuthAuthorizationServerSave`, `OAuthRegisteredClientSave`) reach `Operation.ApplyAt` with no `Operation.Hold` (batch e intent-alignment layer). The intent keeps the 21 per-entity Save handlers out of DW-1497; this is the Save-route entry the spec's Residuals already ask the lead to file, one entry, not two.
    location: >-
      src/OcuPilot/Area/Security/OAuthClientSave.cls
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

- [x] **DW-1870** (high; owner-routed to this story outside the cap of 12) — a Windows clone with `core.autocrlf=true` checks `scripts/*.sh` out with CRLF, so `durable-init` dies at once (`set: Illegal option -`) and `docker compose up --wait` fails in 1 s. The index is already LF; the `.cls` files are unaffected.
  - **Fix:** add `*.sh text eol=lf` to `.gitattributes`. No renormalize.
  - **Red:** a roster-style test in `ui/tools/` that asks `git check-attr eol` for every tracked `*.sh` (`git ls-files '*.sh'`) and requires `lf` for each; it reddens without the rule. Where possible, also a fresh `git -c core.autocrlf=true clone` of the working tree showing every `*.sh` checked out without CR.
  - Files: `.gitattributes`, one new `ui/tools/*.test.mjs`. ADs: AD-17, AD-45 (the start path must run on every supported host).
  - AC: Given a clone made with `core.autocrlf=true`, when it is checked out, then every tracked `*.sh` has LF line endings.

### DW-1829 follow-up (reopened)

- [x] **DW-1829 (reopened)** — staging run 36741141564, instance shard 2/3: `BackgroundTasksLive.TestTheAgentsConfirmPausesACompact`'s `OnAfterOneTest` failed "the seeded database and its tasks are removed" with ERROR #5001 "a background task still runs over the seed database, so the database is left in place", and the next test's seed failed "a background task still runs over the seed database, so it is not refilled". Intermittent: green in runs 36706426500, 36722327485 and 36735796060. The held compact, paused by the confirm, is still running when cleanup runs (inference).
  - **Reproduce first** on `ocupilot-b-ci`: find and record the condition under which `Remove` finds the held task still running, for example the pause landing just before `Remove`'s cancel, or the task ending or resuming after `%UnlockId`.
  - **Fix** in `Test/BackgroundSeed.cls`, touching `Test/BackgroundTasksLive.cls` only if needed: teardown waits, with a bound, for the held task to reach a terminal state before the database is removed, so the next test finds no task over the seed. The leg's assertions and the seed's refusal to remove a database a task still runs over are not weakened.
  - **Red:** the reproducing condition turns cleanup red before the fix and green after, with a `mutation:` line.
  - AC: Given the agent leg's held compact paused by the confirm, when `OnAfterOneTest` runs, then the seeded database and its tasks are removed and the next test's seed succeeds.

### Batch e: the rest

- [x] [Review] DW-1829 follow-up Fix Pack (comments only; land with batch e): `Test/BackgroundTasksLive.cls:345-347` the mutation note should say the removal answered #9501 and left the task over the seed; `:35-37` `STALLSECONDS` doc: the ten-second wait is the one the old teardown allowed; `Test/BackgroundSeed.cls:269-271`, `BackgroundTasksLive.cls:6` and `:341`: label the write-stall claim `(inference)`, and in `Stall`'s doc say the stop follows at once, well inside `pSeconds`, so the job runs again; `BackgroundSeed.cls:39-40` `ENDSECONDS` doc: the last read and the delete that follows can each wait out the 10 s lock timeout past the bound.
- [x] **DW-1497** — `ScreenAction.Run` reads, gates and writes with no lock. The confirm holds `^OcuPilotProposalTarget(key)` only across its claim; its re-read and its port write (`ApplyAt`) happen outside the lock. So a row action that lands between them is silently reverted by the confirm's complete body.
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
- [x] **DW-1451** — `check_destructive_test_guard` matches call shapes within one file, so a Test class that mints and confirms an auditing proposal is invisible to it.
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
- [x] **DW-1290** — `TestAPolicyRefusalCarriesTheInstancesOwnText` derives its expected sentence from a privileged `ChangePassword` probe read at index 2 (:225-227). That is the layout `PolicyText` assumes, so the test and the code move together. The probe is also a live write on any build whose pattern admits two characters.
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

### Review Findings (DW-1870)

- [x] [Review][Patch] low: `.githooks/pre-commit`, a bash script with no suffix, was outside the rule and outside the test's `*.sh` population; `.githooks/** text eol=lf` covers it (the index was already `i/lf`), and the population takes in `.githooks/` and must hold every tracked file with a `sh` or `bash` shebang [.gitattributes:4]
- [x] [Review][Patch] low: the checkout test read an empty or newline-less script (`i/none w/none`) as not LF; `none` is accepted [ui/tools/line-endings.test.mjs:73]
- [x] [Review][Patch] low: the header said every covered script runs in a container and stops at its first line; compose runs three with `sh`, and a CRLF copy stops at its first command [ui/tools/line-endings.test.mjs:8]
- [x] [Review][Defer] medium: a Windows clone made before the rule keeps its CRLF scripts after a pull, so the fix commit's "durable-init runs from a Windows clone" holds for a fresh clone only [.gitattributes:3] — deferred: DW-1875 (decision-pending), not re-filed

Rejected:

- low: the test reads attributes and `ls-files --eol`, not the bytes an `autocrlf=true` checkout writes; with `eol=lf` and an LF blob git writes LF, and two layers' fresh clones of `43362b1c` read 0 of 16 with CR.
- low: the `.githooks/pre-commit` deferral never reached the ledger; moot, patched in this pass.
- low: replacing the Auto Run Result dropped batch c's residual that `ui/tools/proposal-view.test.mjs:312` still describes the old name rule in a comment; recorded again here, and it stays batch c's. The Story 8.5 AC7 residual survives in the batch c review pass.
- low: `### User-visible changes` and `### Residuals and owner actions` carry no DW-1870 line; the fix edits the spec, and a pre-rule clone's release note is DW-1875's decision.
- low: the pre-rule clone's remedy is not written as a tested command; DW-1875's, chosen at the decision sheet.
- low: the clone evidence does not name where its throwaway commit was made; the worktree reflog holds no reset, so a scratch clone took it.
- low: the "after" clone ran `durable-init.sh` under host bash, not the image's `sh`; the DW-1870 ledger evidence measured the container start end to end.
- low: nothing keeps a working copy LF when a Windows editor saves a script with CRLF; an `.editorconfig` is new surface outside the task's Fix.
- low: the Auto Run Result repeats the loop's clone evidence; the fix edits the spec.
- low: commit 731bf63e's subject says "every tracked shell script"; with this pass's rule and shebang roster it holds, and history is not rewritten.
- low: a tracked `*.sh` symlink or deleted working copy reads a blank `i/` or `w/`; none is tracked, and the test fails loudly.
- low: a `*.sh` in merge conflict is listed once per stage and fails the key-equality assertion; mid-merge only, and loud.
- maybe-false: the test has run on macOS only; the three `gates` legs (ubuntu-24.04, one per Node band) settle it on the push, resolved under Rule 28.

### Review Findings (DW-1829 follow-up)

- [x] [Review][Patch] low: the loop block called the stall test the reproducing condition, while its red is #9501 with a task left, not CI's #5001 still-runs refusal; it is now named a stand-in, with the difference stated [spec `## Verification` › DW-1829 follow-up]
- [x] [Review][Patch] low: the Auto Run Result's residual called the red runs' leftover task "stopped" at the still-runs check, unverified, and read as a gap in the refusal; corrected to the labeled inference that the job had exited [spec `## Auto Run Result`]
- [x] [Review][Patch] low (Fix Pack): the Rule 19 note says both mutations make the removal answer "a task still runs"; runs 253 and 254 answered #9501 and left the task [src/OcuPilot/Test/BackgroundTasksLive.cls:345]
- [x] [Review][Patch] low (Fix Pack): `STALLSECONDS`'s doc names "a ten-second wait for its end" without saying it is the teardown's old wait [src/OcuPilot/Test/BackgroundTasksLive.cls:35]
- [x] [Review][Patch] low (Fix Pack): the stand-in is stated as fact in code ("as a host whose writes stall stops a compact"), while the spec labels it an inference [src/OcuPilot/Test/BackgroundSeed.cls:269, src/OcuPilot/Test/BackgroundTasksLive.cls:6,341]
- [x] [Review][Patch] low (Fix Pack): `Stall`'s "so it always runs again" rests on the ordering alone; what holds is that the stop follows the shell's start at once, well inside `pSeconds` [src/OcuPilot/Test/BackgroundSeed.cls:271]
- [x] [Review][Patch] low (Fix Pack): `ENDSECONDS`'s worst case leaves out the delete's own lock wait (`%OnDelete` opens at concurrency 4, up to 10 s) [src/OcuPilot/Test/BackgroundSeed.cls:39]
- [x] [Review][Defer] low: the new test adds a fifth 1.2 GB seed fill to the class, the load DW-1876 names [src/OcuPilot/Test/BackgroundTasksLive.cls:350] — deferred: DW-1876 (wontfix-accepted), occurrence appended, not re-filed

Rejected:

- false: `Remove` removes the database under a live compact once its wait expires; a task whose job and memory exist computes `Running` or `Paused` (`GetExternalState`, `JobIsRunning`, `irissys/%SYS/BackgroundTask.cls:547-556,737-744`), so `DatabaseList` lists it and the unchanged still-runs refusal fires. The same holds for `Remove`'s doc claim and the batch-a rejection at :331.
- false: `STALLSECONDS` 35 does not clear the `ENDSECONDS = 10` mutation's overrun, so its red is fragile; the first read waits out the whole 10 s lock timeout, so it always ends past a 10 s deadline.
- false: the teardown's `Remove` refuses too if the job stays stopped; the continuing shell runs whatever the test does, so the job runs again after `STALLSECONDS`.
- false: the test goes on to `Stall` after a failed resume or pause; the held job is alive either way, the stop ends by itself, and the test is already red.
- false: the iteration cap `ENDSECONDS * 50` duplicates the deadline; each pass takes at least 20 ms, so the cap is a backstop that never fires first.
- low, wontfix-accepted: on a host still mid-work 3 s after the resume the stop lands on a paused compact, the lock stays free, and the unopened-row arm goes unexercised, so dropping that arm would stay green there. Red was observed on `ocupilot-b-ci`, the agent leg's `Hold` mutation shares the same window, and an assertion on the path would add a flake. reopen_if: a CI shard's `messages.log` shows `gfilecomp caught error 55 ... Canceled` during this test.
- low: `Tasks()` fails open, so the final assertion would read a failed query as no task; `Remove`'s status is the primary pin and went red under both mutations, a failed vendor query on a healthy throwaway is unlikely, and `Tasks()` is unchanged.
- low: `Stall` takes any pid and does not re-check the job; its one caller passes the held job about 3 s after the resume, inside `End()`'s 10 s wait, and an exited job fails loudly at the stop.
- low: a continuing shell killed from outside leaves the job stopped; only a container stop does that, and it ends the job too (wontfix-theoretical).
- low: an open that fails for a reason other than the lock spins the full bound; no such failure is known on an existing row (wontfix-theoretical).
- low: the leg belongs in its own class, and the class is now 575 lines; the header names it, the guideline is approximate, and the class was 542 lines before.
- low: `ui/tools/ci-timings.json` still records 44.1 s for the class; about 40 s on a roughly seven-minute shard, taken up at the next routine refresh.
- low: the arming roster's reason in `scripts/ci-throwaway.sh` does not mention the stop; it is prose outside the footprint, and arming works the same.
- spec edit: the Design Notes lack `Stall`, and `lint-docs.sh` was not recorded; the spec is oversized, and this pass ran `lint-docs.sh`.
- out of scope: the frontmatter reads `done` while batches e and d are open; the lead's to set.

### Review Findings (batch e)

- [x] [Review][Patch] medium: the marking arm read only classes declaring `MOVESMARKING` themselves, so `AuditUserEventUpdate` (`security.audituserevents.update`), which inherits it, was not a marking tool to the checker (5 compiled classes read 1 on `ocupilot-b-ci`, 4 were derived), and nothing pinned the arm on the shipped tree [scripts/check-objectscript.py:1480]
- [x] [Review][Patch] medium: a row action's hold through its read-back, and its release, were unasserted (Rule 19) [src/OcuPilot/Test/ProposalConfirm.cls:290]
- [x] [Review][Patch] the prohibited set runs under the confirm's hold, as the Fix places it, but moving the hold to just above the fingerprint re-read stayed green [src/OcuPilot/Test/ProposalConfirm.cls:245]
- [x] [Review][Patch] `Operation).Apply(` had no harness leg, and its fixture-port exemption read `Apply`'s default port, which a tool declaring its own `PORTCLASS` bypasses [scripts/check-objectscript.py:1554]
- [x] [Review][Patch] the marking arm missed the provider spelling of a wire name, and its stated limit named less than it leaves out [scripts/check-objectscript.py:1294]
- [x] [Review][Patch] `TOOL_NAME_RE` did not accept parameter keywords, as `MOVES_MARKING_RE` does [scripts/check-objectscript.py:1382]
- [x] [Review][Patch] the row action's busy upper bound left 1.8 s for the round trip on a CI shard [src/OcuPilot/Test/ReadBackRoute.cls:133]
- [x] [Review][Patch] medium: `Operation`'s class doc says both callers hold the target, while AD-55's Saves take no hold [src/OcuPilot/Kernel/Proposal/Operation.cls:13]
- [x] [Review][Patch] `Hold`'s caller contract said to release after the port write, while both callers hold through the read-back (AD-58), and nothing said a write the port answers as started (AD-26) continues after the hold [src/OcuPilot/Kernel/Proposal/Operation.cls:53]
- [x] [Review][Patch] `GuardedTargetLock`'s doc said a principal "without read on" OcuPilot's database is refused, while the probe measured one with no privilege on it [src/OcuPilot/Kernel/State/Base.cls:486]
- [x] [Review][Patch] `ProposalFixture`'s header omitted that the lock probe sets and kills a node of `^OcuPilotProbeLockFree` [src/OcuPilot/Test/ProposalFixture.cls:16]
- [x] [Review][Patch] `ENDSECONDS`'s doc broke mid-sentence onto a short line [src/OcuPilot/Test/BackgroundSeed.cls:41]
- [x] [Review][Defer] medium: AD-55's Saves take no per-target hold, so the proposed AD-34 and AD-53 wording would make each a standing violation [src/OcuPilot/Area/Security/OAuthClientSave.cls:333] — deferred: DW-1882 (routed, burndown), occurrence appended, not re-filed; the wording is the lead's

Rejected:

- low, by-design: the confirm's hold precedes all its gates, so a confirm refused for good (a lost pair, governance, restraint, a moved conversation or definition) on a busy target first answers 409 after up to 10 s, while a row action checks its pairs before its hold. Only the proposal's own minting user inside its window reaches the hold (`ClaimById` runs first), and what they learn is that a write is in flight on a target they already know; nothing is written, the pair is named on the retry (AD-8), every gate stays at the write (AD-40), and the proposed AD-34 holds. The Fix places the hold before the gate.
- low, wontfix-theoretical: `Release`'s status is discarded in both callers. The unlock fails only if `AddRoles` fails after the same request's hold took it, and the kernel discards its turn-slot unlock the same way (`Turn.cls:218`, `:265`, `:341`, `:410`). Real when a target answers 409 with no live holder.
- low, wontfix-theoretical: the release after the `Catch` needs the install namespace and a `Catch` body that does not raise. A port returning in `%SYS` would already break the OcuPilot calls after it (AD-16). Real when a port is found returning with `$NAMESPACE` switched.
- low, by-design: a proposal whose window closes during the hold's wait is claimed up to 10 s late. `ClaimById` judged the token on arrival, as AD-6 words it, and the hold's wait replaces the claim's own 10 s lock wait.
- low, wontfix-theoretical: a lock-probe job answering after its 10 s wait leaves a `^OcuPilotProbeLockFree` node; the probe tries with a zero timeout.
- maybe-false, if true low: the claim's own `Canonical` call may have lost its pin now that the hold refuses first. It matters only for a row stored under a non-canonical spelling, which mint no longer writes (AD-13); settles by running "drop `Canonical` from `GuardedClaimAndClose`" against `ProposalSpelling`.
- low, rejected: `Error.cls`'s one line in `ReasonForToolCode` is a mid-file edit. The intent scopes append-only to new parameters, which are at the end, and Epic 16's hunks sit at 4107-4119; moving it into `Write.ReasonFor` edits another contended file.
- low, rejected: `ReasonForToolCode`'s doc does not list `WRITE.TARGETBUSY`; it already omits the navigation and lock families it resolves.
- low, rejected: `STALLSECONDS`'s "that the teardown allowed before" is the sentence the Fix Pack item asked for.
- low, rejected: `ProposalConfirm` is 776 lines against the approximate 500-line guideline; the row-action leg shares the confirm legs' fixture.
- low, by-design: "retrying once the lock is free succeeds" is pinned for the row action only. `ConfirmRoute` issues no confirmed write by design, and the busy legs assert the row live and unburned.
- low, wontfix-accepted (`reopen_if=` a Test class writes a marking tool, unguarded, through a subclass of the shipped confirm, `$ClassMethod`, an AD-55 Save route, or a row action named only by screen and action id): those paths stay outside the arm, and its stated limit now names them.
- rejected (lead-owned): the proposed AD-53 replacement drops "inside the transition" for the prohibited set, which both callers evaluate under the hold; AD-34's Binds line names the confirm path only; the pointers :505 and :739 read :514 and :753 in the spine. DW-1882 sits flush against DW-1879 (both parse); frontmatter `done` against the tracker's `review`.

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

### 2026-09-30 — Review pass (DW-1870)

- verdicts: 11 findings — high 0, medium 3, low 6, false 2, maybe-false 0
- findings:
  - `[medium]` `[patch]` The test read the `eol` attribute only, so a script stored with CRLF would keep it green and still check out with CRLF (verification-gap) — the checkout test now also requires `i/lf` and `w/lf` from `git ls-files --eol`; in a scratch clone it went red on a staged CRLF blob and on a CRLF working copy, each naming `scripts/durable-init.sh`; restored, 2/2.
  - `[medium]` `[defer]` A Windows clone made before the rule keeps its CRLF scripts after pulling it, with `git status` clean (verification-gap) — pre-existing state the rule does not rewrite; the remedy is a user step; recorded in `deferred:`.
  - `[low]` `[patch]` The header said the answer is the repository's own `.gitattributes`, but `info/attributes` is still read (verification-gap) — reworded to say a repository-local `info/attributes` still applies.
  - `[low]` `[defer]` `.githooks/pre-commit` is a bash script with no `.sh` suffix, so its line endings stay unset (verification-gap) — pre-existing, and the intent's "do not widen a fix beyond its task" keeps it out; recorded in `deferred:`.
  - `[medium]` `[patch]` The AC's surface is the files after an `autocrlf=true` clone, the tests read attributes only, and the clone check was neither run nor explained (intent-alignment) — same root and patch as the first row; the clone check ran after the handoff (16 of 16 with CR before, 0 of 16 after) and is recorded under `DW-1870 (loop)`.
  - `[low]` `[reject]` No CI job starts a container from a CRLF clone, so the start path is not exercised there (intent-alignment) — the scratch clone ran `durable-init.sh` past the `set` line that stopped it before; a Windows CI leg is new infrastructure, not a direct correction.
  - `[false]` `[reject]` The `.cls` files being unaffected was not checked (intent-alignment) — the DW-1870 ledger evidence measured it: with only the `.sh` files LF, the CRLF `.cls` files compiled and installed (healthy in 132 s, `STARTPATH-OK`).
  - `[low]` `[patch]` The test title said "every tracked shell script" but selects by the `.sh` suffix (intent-alignment) — renamed `every tracked *.sh checks out with LF line endings`.
  - `[low]` `[patch]` The test still reads `info/attributes` (intent-alignment) — same root and patch as the third row.
  - `[low]` `[patch]` The failure message read "scripts .gitattributes does not check out with LF" (intent-alignment) — now "these scripts would not check out with LF".
  - `[false]` `[reject]` The spec has no Auto Run Result for DW-1870 (intent-alignment) — finalize writes it after review, and the fix would edit this build's spec.

### 2026-09-30 — Code review (DW-1870)

- layers: blind-hunter, edge-case-hunter, verification-gap and acceptance-auditor, all Opus; none failed. 28 raw rows grouped into 17 entries: high 0, medium 1, low 15, maybe-false 1. 3 patched, 1 deferred (DW-1875, not re-filed), 13 closed; see `### Review Findings (DW-1870)`.
- `[low]` `[patch]` `.githooks/pre-commit` was outside the rule and the population (blind-hunter, edge-case-hunter; pre-flagged by the lead): a fresh `autocrlf=true` clone of `43362b1c` has CR on 230 of its lines. Each half went red alone under its mutation; restored byte-identical.
- `[low]` `[patch]` `i/none` read as not LF (blind-hunter, edge-case-hunter); `[low]` `[patch]` the header's claims (all four layers).
- `[medium]` `[defer]` A pre-rule clone keeps CRLF after a pull (edge-case-hunter): DW-1875.
- Rules: AD-17 and AD-45 match; compose's three start-path scripts are covered, and no start-path code changed. Rule 3: the real-runtime evidence is the fresh clones and the script runs under `DW-1870 (loop)`. No NFR touched. `npm run test:tools` 1,740/1,740; both changed files ASCII only.

### 2026-09-30 — Review pass (DW-1829 follow-up)

- verdicts: 14 findings — high 0, medium 3, low 7, false 3, maybe-false 1
- findings:
  - `[medium]` `[patch]` No committed test reproduces the stall, so reverting either change to `Remove` leaves the suite green (verification-gap) — added `BackgroundTasksLive.TestTheTeardownOutlastsAStalledCompact` and `BackgroundSeed.Stall` (Rule 19 patches a missing pin in-pass); red on the baseline wait (run 252) and under both mutations (253, 254), green in 251 and 255-257.
  - `[medium]` `[patch]` The AC is pinned only by a deleted probe (verification-gap, Rule 19) — same root and patch as the first row.
  - `[low]` `[patch]` The first `mutation:` line was seen on an intermediate tree, never applied to the final one and reverted (verification-gap) — both mutations re-run on the final tree against the committed test, each reverted byte-identical.
  - `[low]` `[patch]` `Remove`'s doc says a task that does not open has not ended, but only a task that opens is canceled (verification-gap) — the doc now says "canceled first when it opens and has not ended"; no measured path fails the first open (the holder opens its own task).
  - `[low]` `[patch]` The doc says the first failure is answered, while the still-runs refusal replaces it (verification-gap; the code is pre-existing, the paragraph was rewritten here) — the doc now says the refusal is answered in its place.
  - `[low]` `[patch]` The new deferred entry said the seed is filled by "three tests"; four fill it (verification-gap) — reworded to "each time a test fills it" in the entry this pass wrote, correcting the claim at its origin (CLAUDE.md).
  - `[medium]` `[patch]` Nothing committed would catch a regression (intent-alignment) — same root and patch as the first row.
  - `[low]` `[patch]` The `mutation:` lines ran against the deleted probe, and "red on the unfixed tree after 44.8 s" matched the intermediate tree's time (intent-alignment) — same root as the third row; the unfixed line is replaced by run 252's red on the baseline wait.
  - `[low]` `[patch]` The probe paused in-process rather than through the confirm, and recorded no following seed (intent-alignment) — the committed test pauses through the port (`PortalControl`, the call the confirm's apply reaches) and asserts no task is left over the seed, the condition the next seed refuses on.
  - `[maybe-false]` `[defer]` A stopped job stands in for a write suspension, so whether 60 s covers every CI stall is inferred (intent-alignment) — the observed incident fits inside the bound; settles on a CI recurrence; recorded in `deferred:` as medium (unverified).
  - `[false]` `[reject]` The bound widens for every task over the seed, not only the held one (intent-alignment) — it lengthens only a wait that ended in a failed teardown before; a cancel ends an answering task within 0.25 s (measured), so no leg's normal teardown changes.
  - `[low]` `[patch]` `ENDSECONDS` bounds new reads, not total time: the cancel blocks about 18 s before it and the last read can wait the lock timeout past it (intent-alignment) — its doc now says both.
  - `[false]` `[reject]` The stall's cause is deferred rather than removed (intent-alignment) — the auditor itself reads this as the task's Fix ("teardown waits, with a bound").
  - `[false]` `[reject]` The pause-just-before-cancel race was not reproduced on its own (intent-alignment) — a paused or held compact ends within 0.25 s of a cancel (measured), so that order alone does not leave a task running; the committed test pauses just before its stall.

### 2026-09-30 — Code review (DW-1829 follow-up)

- layers: blind-hunter, edge-case-hunter, verification-gap and acceptance-auditor, all Opus; none failed. 43 raw rows grouped into 23 entries: high 0, medium 0, low 16, false 5, spec-edit or out of scope 2. 2 patched in the spec, 5 in the Fix Pack (code comments, for the next batch), 1 deferred (DW-1876, occurrence), 15 closed; see `### Review Findings (DW-1829 follow-up)`. No `.cls` changed in this pass.
- `[low]` `[patch]` The stall test's red (#9501, a task left) is not CI's still-runs refusal (verification-gap, acceptance-auditor, which rated it medium): the pin went red on the baseline and under both mutations, and the fixed wait's path is the one CI needs (the job still stopped when the old wait ended), so only the spec's "reproducing" wording was wrong. Corrected there. DW-1877 stays the owner of CI fidelity.
- Focus: the wait and the stop cannot strand anything. The continuing shell starts before the stop and runs by itself. An exited job fails the stop loudly. A live job keeps the still-runs refusal armed (vendor source), and the fixed path's margin is 78 s against a 35 s stop. `ocupilot-b-ci` read back no stopped process and no seed directory. `$ZF(-100)` is test-only: no class outside `Test/` names `BackgroundSeed`, `Stall` refuses unarmed, and `ProcessBroadcastLive` and the X.509 classes already run `$ZF(-100)` in CI. The agent leg, `Hold`, and both still-runs refusals are unchanged.
- Rules: AD-27's Story 16.5 case matches: the leg resumes and pauses through `BackgroundTaskPort`, and cancel stays in the fixture. The Tests convention holds: the leg seeds and removes its own compact. Rule 3 is exempt (test code only). No NFR touched. Rule 19: the recorded `mutation:` lines are current; none were added. `check-objectscript.py` 0 problems; both classes ASCII only.

### 2026-09-30 — Review pass (batch e)

- verdicts: 16 findings — high 0, medium 4, low 6, false 5, maybe-false 1
- findings:
  - `[medium]` `[patch]` Nothing pinned that the hold starts before the fresh read, or lasts through the read-back, in either caller: moving the hold after `FingerprintMatches` or after `Operation.Read` stayed green (verification-gap) — `ProposalFixture`'s armed probe now also asks at the first read and at the read-back, and a new `ProposalConfirm` leg drives the X.509 list's Delete through `SslActionFixture`; red in runs 281-284, green in run 287 (24/24).
  - `[medium]` `[patch]` The confirm route's busy reason came only from the line inserted in `Error.ReasonForToolCode`, and deleting it left every test green (verification-gap) — new HTTP leg `ConfirmRoute.TestAConfirmOnAHeldTargetIsRefusedBusyOverTheWire` (409, code, published reason, row live); red in run 285, green in run 288 (7/7).
  - `[low]` `[patch]` Three of the marking arm's five write entry points had no harness case (verification-gap) — added one leg each for `/confirm"`, `/action"` and `ScreenAction).Handle(`; each alternate removed went red alone; 140/140.
  - `[low]` `[patch]` "At most 10 s" had no upper bound; `CLAIMLOCKSECONDS = 20` stayed green (verification-gap) — `ReadBackRoute`'s busy leg asserts a literal `< 12` s; red in run 286 (20.2 s), green in run 289 (10.2 s).
  - `[low]` `[reject]` The marking arm exempts any literal `OcuPilot.Test.*` port, including ones that forward writes to `AdminPort` (`MarkingPort`, the `*RecordPort` family) (verification-gap, other) — the spec's Fix names that exemption; the only shipped `Apply` through a literal test port is `ToolWrite`'s through `AcceptPort`; telling a recording port from a forwarding one needs a port-class analysis. Becomes real when a test applies a marking tool through a forwarding test port.
  - `[false]` `[reject]` The Fix Pack's `BackgroundTasksLive.cls:6` pointer was left unedited (intent-alignment) — that line carries no write-stall claim (read at HEAD); every stall claim in both classes carries `(inference)`.
  - `[medium]` `[patch]` The confirm's tests run below the route, so its wire reason was unpinned (intent-alignment) — same root and patch as the second row.
  - `[low]` `[patch]` The row-action leg asserted no upper bound on the wait (intent-alignment) — same root and patch as the fourth row.
  - `[false]` `[reject]` No test shows a confirm and a row action on one target take one lock (intent-alignment) — `ReadBackRoute` and the new `ConfirmRoute` leg each hold `TargetHoldKey` of `EntityRef.Key` for a web application and each caller waits on it (runs 289, 288); the `Canonical` mutation (run 267) pins the claim's key to the same function.
  - `[low]` `[reject]` "Not for a preview" is unpinned (intent-alignment) — a dropped condition makes a preview during another write wait up to 10 s and refuse, which needs a preview inside another write's window; pinning it needs a new preview leg.
  - `[medium]` `[defer]` Five OAuth Save handlers reach `ApplyAt` with no hold (intent-alignment) — pre-existing; the intent keeps the 21 per-entity Save handlers out of DW-1497; recorded in `deferred:` as the Save-route entry the spec's Residuals name.
  - `[false]` `[reject]` `Error.cls` got an insertion inside `ReasonForToolCode` (intent-alignment) — the intent's rule is "new parameters go at the end", which holds; the line is what the route's published reason needs (pinned, run 285), and Epic 16's worktree has no edit to `Error.cls` since its merge-base.
  - `[false]` `[reject]` Additions outside the listed API: a public `Propose.TargetHoldKey` and test helpers (intent-alignment) — no harm named; `TargetHoldKey` is the one key both callers and the claim share, and the helpers are test-only.
  - `[low]` `[reject]` The checker's refusal names the first marking tool a file mentions, which may not be the one it confirms (intent-alignment) — cosmetic; such a class is refused either way, and linking the name to the call adds branches.
  - `[false]` `[reject]` The pattern pre-check also fails on an empty or unreadable pattern (intent-alignment) — an empty pattern admits "ab", so the POST could change the password; failing closed is the Fix's purpose.
  - `[maybe-false]` `[reject]` The expected 845 sentence is resolved in the test process while the server resolves it in the CSP process (intent-alignment) — unchanged from the deleted probe, which also resolved in the test process; settles on an instance whose CSP process takes another message language; if true, low.

### 2026-09-30 — Code review (batch e)

- layers: blind-hunter, edge-case-hunter, verification-gap and acceptance-auditor, all Opus; none failed. 44 raw rows grouped into 26 entries: high 0, medium 4, low 20, maybe-false 1, lead-owned 1. 12 patched, 1 deferred (DW-1882, occurrence), 13 closed; see `### Review Findings (batch e)`.
- `[medium]` `[patch]` An inherited `MOVESMARKING` escaped the marking arm (all four layers). Measured on `ocupilot-b-ci`: `%Dictionary.CompiledParameter` reads 1 on five classes, and the checker derived four, missing `AuditUserEventUpdate`. It now walks the superclass graph, the nearest declaration deciding; a harness case and a shipped-tree floor pin it.
- `[medium]` `[patch]` A row action's hold through its read-back, and its release, were unasserted (verification-gap, blind-hunter, edge-case-hunter, acceptance-auditor). Red in runs 295 and 296.
- `[medium]` `[patch]` `Operation`'s class doc claimed both callers hold, while AD-55's Saves take none (acceptance-auditor, blind-hunter). DW-1882 carries the code gap, and the lead amends the AD-34 and AD-53 wording.
- `[low]` `[patch]` The prohibited set under the confirm's hold was unpinned (verification-gap): red in run 295 with the hold moved after the gates.
- Lock path, read in full: every exit of `Confirm.Transition` and `ScreenAction.Run` reaches the release after the `Catch` (no `Return` inside either `Try`); the escalated frame runs `Lock` alone (AD-9); nothing is spawned under the hold outside the test fixture's probe, which takes no lock the parent holds; the claim re-enters the one canonical key; the ledger's `^OcuPilotStateCap` lock is taken inside the hold and never waits on a target lock, so no cycle exists. The row action checks its pairs before its hold; the confirm holds before its gates (closed by-design, above).
- `Error.cls`: 989 declared and 992 compiled parameters on `ocupilot-b-ci` (3 inherited), against the 1,000 limit `spec-16-25-the-external-language-server-editor.md:602` states for ERROR #5290; it compiles. Epic 16's worktree adds no parameter to it.
- Rules: AD-8, AD-9, AD-10, AD-13, AD-15, AD-39, AD-40 and AD-58 match; AD-34 and AD-53 match the proposed wording except where the stage report asks the lead to amend it (the Saves, the read-back, a started write, the prohibited-set anchor). Rule 3 is met by `ReadBackRoute` and `ConfirmRoute`'s busy legs over HTTP; DW-1451 and DW-1290 are test tooling. No NFR touched.

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

**DW-1870 (loop):**

- Tier: `cd ui && npm run test:tools` (`line-endings.test.mjs`).
- `mutation:` delete the `*.sh text eol=lf` line from `.gitattributes` → `every tracked shell script checks out with LF line endings` red alone, naming all 16 tracked `*.sh` (`eol: unspecified, stored: lf, checkout: lf`); restored byte-identical (`shasum`, `git status --short` and `git diff --stat` unchanged), 2/2.
- `mutation:` delete the `.githooks/** text eol=lf` line → the same test red alone, naming `.githooks/pre-commit (eol: unspecified, stored: lf, checkout: lf)`; restored byte-identical, 2/2.
- `mutation:` drop `.githooks/` from `SCRIPT_PATHSPECS` → `the population is every tracked shell script` red alone, naming `.githooks/pre-commit` as a shebang script outside the pathspecs; restored byte-identical, 2/2.
- `mutation:` in a scratch clone carrying the fix, stage a CRLF blob as `scripts/durable-init.sh` (`git update-index --cacheinfo`, working copy LF) → the checkout test red alone, naming `scripts/durable-init.sh (eol: lf, stored: crlf, checkout: lf)`; with the working copy CRLF and the stored copy LF → red naming `checkout: crlf`; each restored, 2/2. The scratch clone was deleted.
- Fresh-clone evidence (`git clone --config core.autocrlf=true --no-local` of the worktree into the scratchpad, deleted afterwards): at `961d45c7`, without the rule, 16 of 16 `*.sh` carried CR and `bash scripts/durable-init.sh` stopped at line 17 (`set: -: invalid option`); after a throwaway commit of this `.gitattributes`, a second such clone had 0 of 16 with CR (`i/lf w/lf attr/text eol=lf`), `README.md` still CRLF as the control, and `durable-init.sh` ran to its own check (`/durable is not a directory`).
- `.githooks/pre-commit`, the same way: at `43362b1c` it checked out `w/crlf` with CR on 230 lines, and bash 3.2 failed its `set` line (`set: pipefail: invalid option name`); from a scratch commit of this `.gitattributes`, 0 lines with CR (`i/lf w/lf attr/text eol=lf`), `README.md` CRLF as the control. An empty tracked `.sh` (`i/none w/none`) passes this test and fails the one committed at `43362b1c`. Code review: `npm run test:tools` 1,740/1,740.

**DW-1829 follow-up (loop):**

- CI evidence (run 36741141564 attempt 1, shard 2/3, the instance's `messages.log`): updates were suspended for low WIJ free space from 16:12:17 to 16:12:47. The agent leg's compact started at 16:12:40.0 and logged `gfilecomp caught error 55 ... Canceled` only at 16:12:58.6, 35 ms before the next test's teardown dismounted the seed. The cause is that the stalled compact acted on the cancel after `Remove` had stopped waiting (inference).
- Vendor, measured on `ocupilot-b-ci`: a held compact whose work is done waits in `End()` (`LOCKW`, `LOCKSW` after the pause); a mid-work pause leaves it `SUSP`; a cancel ends either within 0.25 s. On a stopped job, `$zu(4)` (the vendor's cancel) blocks 17 to 18 s and answers -1, which `Request` accepts, and the job acts on it once it runs again. After `%UnlockId`, a job waiting in `End()` takes the task's lock, and `%OpenId` fails after 10.01 s with #5804 while `%ExistsId` reads 1. A write-daemon freeze (`ExternalFreeze`, `WDSuspendLimit` 30) did not slow the compact here (done in 1.9 s), so it was not used.
- Stand-in condition, committed as `BackgroundTasksLive.TestTheTeardownOutlastsAStalledCompact`: the agent leg's order (seed, `Hold`, resume through the port, 3 s, pause through the port, the pause request read 1), then the compact's job stopped for `STALLSECONDS` (35) by `BackgroundSeed.Stall` (`$ZF(-100)`: an asynchronous `sleep; kill -CONT` first, then `kill -STOP`), then `Remove` must answer OK with no task left over the seed. The stop stands in for CI's stall (inference). Its red is a delete that comes too early (#9501, a task left), not CI's still-runs refusal (#5001, the next seed refused), because the job resumes during the removal's delete (inference). A temporary probe (a 45 s stop, deleted) found it first; its mid-work variant (pause 0.3 s after the resume) was green on the fix in 46.3 s and logged CI's `gfilecomp caught error 55 ... Canceled`.
- Red before the fix: with `Remove`'s wait restored to the baseline's (500 reads 20 ms apart, a failed open counted as ended), run 252 red on the new test alone: `Remove` answered #9501 "Memory assigned to this background task is still in use" and a task was left over the seed.
- `mutation:` count a failed open as ended again (the `%ExistsId` arm dropped, `ENDSECONDS` 60) → run 253 red on `TestTheTeardownOutlastsAStalledCompact` alone (#9501, a task left); reverted byte-identical and reloaded.
- `mutation:` `ENDSECONDS = 10` → run 254 red on `TestTheTeardownOutlastsAStalledCompact` alone (#9501, a task left); reverted byte-identical (`shasum`, `git status --short`, `git diff --stat` unchanged) and reloaded.
- Green: runs 251, 255, 256 and 257, 8/8 each in `%UnitTest_Result`, the new test 40.0-40.1 s with its 35 s stop, the class about 60 s. The handoff's runs 247-249 (7/7) predate the new test. Afterwards: no background task over the seed, database, configuration, `%DB_OCUBGSEED`, directory or stopped process. `check-objectscript.py` 0 problems.

**Batch e (loop):**

- Classes: `ReadBackRoute`, `ProposalSpelling`, `ProposalConfirm`, `AccountPasswordWire`.
- `uv run scripts/test_check_objectscript.py`, then `uv run scripts/check-objectscript.py` over the whole tree. Expected: green, 0 problems.
- Probe (measured on `ocupilot-b-ci`, removed afterwards): a principal holding only `%DB_HSCUSTOM:RW`, `%DB_IRISSYS:R`, `%DB_IRISLIB:R` and `%Service_Terminal:U` was refused `<PROTECT>` by `Lock +^OcuPilotProposalTarget(...)` and by `$Data` on that global, while releasing a lock it did not hold answered OK. So `Lock` on the target global needs a privilege on OcuPilot's database, and the hold escalates through `Base`. The probe user, role and class read back absent.
- `mutation:` delete the hold in `ScreenAction.Run` → run 264 red on `ReadBackRoute.TestARowActionOnAHeldTargetIsRefusedBusy` alone (the held disable answered after 0.4 s, not 409, and disabled the application); reverted byte-identical, run 265 4/4.
- `mutation:` release the hold before `ApplyAt` in `Confirm.Transition` → run 260 red on `ProposalConfirm.TestTheTargetIsHeldThroughThePortWriteAndReleased` alone (a second process took the target lock during the write); reverted byte-identical, run 262 23/23.
- `mutation:` drop the release after `Transition`'s `Catch` → run 261 red on the same test alone (the lock still held after each confirm answered, and the class-level "A UnitTest left the following global locked"); reverted byte-identical, run 262 23/23.
- `mutation:` drop `Canonical` from `Propose.TargetHoldKey` → run 267 red on `ProposalSpelling.TestASecondSpellingCannotWriteWhileAnotherConfirmIsInFlight` alone (the claim's own lock refused instead, at 500); reverted byte-identical, run 268 5/5.
- `mutation:` drop the marking-tool arm → the harness red on the unguarded-confirm case and on the two non-fixture-port legs of the fixture-port case (3 of 139); reverted byte-identical, 139/139.
- `mutation:` drop the fixture-port exclusion → the harness red on the fixture-port leg and on the shipped-tree case (`ToolWrite`'s `ApplyAt` through `OcuPilot.Test.AcceptPort` armed); arm on a name alone → red on the read-only leg, the fixture-port leg and the shipped-tree case; read names on comment lines → red on the comment leg alone; each reverted byte-identical, 139/139.
- `mutation:` have `PolicyText` read index 1 → run 271 red on `AccountPasswordWire.TestAPolicyRefusalCarriesTheInstancesOwnText`'s sentence assertion (and on the routine leg's quoted-958 fallback assertion); reverted byte-identical, run 272 6/6.
- Observed on the reverted tree (`OCUPILOT-LOAD:OK:errors=0`): `ProposalConfirm` 262 (23/23), `ReadBackRoute` 265 (4/4), `ProposalSpelling` 268 (5/5), `ConfirmRoute` 269 (6/6), `AccountPasswordWire` 272 (6/6), `BackgroundTasksLive` 273 (8/8); the harness 139/139; the whole-tree checker 0 problems, its marking arm reaching exactly `AuditEventEditor`, `AuditingUpdate` and `ProhibitedRoute`, all guarded.
- `mutation:` take the hold in `Confirm.Transition` just before the claim, after `FingerprintMatches` → run 281 red on `ProposalConfirm.TestTheTargetIsHeldThroughThePortWriteAndReleased` alone (a second process took the target lock at the confirm's fresh read, through `ConfirmFixture.PortClass`); reverted byte-identical, run 287 24/24.
- `mutation:` release the hold before `Transition`'s read-back (`ReadBack.Of` reaches the fixture through `PortClassOf`) → run 282 red on the same test alone (a second process took the lock at the read-back); reverted byte-identical, run 287 24/24.
- `mutation:` take the hold in `ScreenAction.Run` after `Operation.Read` → run 283 red on `ProposalConfirm.TestARowActionHoldsItsTargetFromTheFreshReadThroughTheWrite` alone (the X.509 list's Delete through `SslActionFixture`; a second process took the lock at the fresh read); release it before `Operation.Apply` → run 284 red on the same test alone (at the write); each reverted byte-identical, run 287 24/24.
- `mutation:` delete the `WRITETARGETBUSY` line from `Error.ReasonForToolCode` → run 285 red on `ConfirmRoute.TestAConfirmOnAHeldTargetIsRefusedBusyOverTheWire` alone (409 `WRITE.TARGETBUSY` with "That tool could not be answered on this instance."); reverted byte-identical, run 288 7/7.
- `mutation:` drop `/confirm"`, `/action"` or `ScreenAction).Handle(` from `MARKING_WRITE_ENTRY_RE`, one at a time → the harness red on that entry's leg of `test_each_route_and_the_handler_arm_the_marking_arm_on_their_own` alone (1 of 140 each); each reverted byte-identical, 140/140.
- `mutation:` `CLAIMLOCKSECONDS = 20` → run 298 red on `ReadBackRoute.TestARowActionOnAHeldTargetIsRefusedBusy`'s upper bound alone (waited 20.2 s against `< 15`); reverted byte-identical, run 299 4/4.
- Observed on the reverted tree (`OCUPILOT-LOAD:OK:errors=0`): `ProposalConfirm` 287 (24/24), `ConfirmRoute` 288 (7/7), `ReadBackRoute` 289 (4/4); the harness 140/140; the whole-tree checker 0 problems.
- `mutation:` release the hold in `ScreenAction.Run` before `ReadBack.Of`, and, independently, take `Confirm.Transition`'s hold after its gates, just before `FingerprintMatches` → run 295 red on exactly two assertions, each alone in its leg: `TestARowActionHoldsItsTargetFromTheFreshReadThroughTheWrite` "nor at its read-back" and `TestTheTargetIsHeldThroughThePortWriteAndReleased` "at the prohibited-set check"; reverted byte-identical (`shasum`), run 297 24/24.
- `mutation:` drop the release after `ScreenAction.Run`'s `Catch` → run 296 red on the row-action leg's "once the action answers, it can" alone, and the class-level "A UnitTest left the following global locked"; reverted byte-identical, run 297 24/24.
- `mutation:` derive only the classes that declare `MOVESMARKING` themselves → the harness red on `test_a_tool_inheriting_the_marking_flag_is_a_marking_tool` (its inherited leg) and `test_the_marking_arm_reaches_the_shipped_marking_tools` (2 of 144); exempt `Apply(`'s fixture port as `ApplyAt(`'s is → red on `test_apply_arms_the_rule_whatever_its_default_port` alone; drop the provider spelling → red on `test_the_provider_spelling_of_a_wire_name_names_the_tool` alone; each reverted byte-identical, 144/144.
- Code review pass, on the reloaded tree (`OCUPILOT-LOAD:OK:errors=0`): `ProposalConfirm` run 297 (24/24), `ReadBackRoute` 299 (4/4), `ConfirmRoute` 300 (7/7); the harness 144/144; the whole-tree checker 0 problems, the marking arm deriving five tools and still reaching exactly `AuditEventEditor`, `AuditingUpdate` and `ProhibitedRoute`, all guarded. `ocupilot-b-ci` holds no `^OcuPilotProbeLockFree` node and no target lock.

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

**Batch e (DW-1497, DW-1451, DW-1290, and the DW-1829 follow-up's comment Fix Pack).** Batch d is untouched and stays unchecked.

- **Change:**
  - DW-1497: a write holds its scoped target (`Propose.GuardedTargetHold`/`GuardedTargetRelease` on the claim's key, `TargetHoldKey`, exposed as `Operation.Hold`/`Release`). A confirm holds it from before its gates through the read-back, and a screen row action from before its fresh read to its end; a preview holds nothing. The claim re-enters the lock, and both release after their `Catch`. A caller that cannot take it within `CLAIMLOCKSECONDS` (10 s) answers 409 `WRITE.TARGETBUSY`, writes nothing, and a proposal stays live. Measured first: `Lock` on the target global needs a privilege on OcuPilot's database, so the hold escalates through `Base`.
  - DW-1451: the checker reads the marking tools from the tree (`MOVESMARKING` 1, by class and wire name) and arms a TestCase that names one on a code line and calls a write entry point; an `Apply` through a literal `OcuPilot.Test.*` port does not arm it.
  - DW-1290: the policy leg derives its sentence from `$System.Status.Error(845)`; the privileged probe is gone, and the leg stops red where `PasswordPattern` admits "ab".
  - Fix Pack: five comment corrections in `BackgroundSeed` and `BackgroundTasksLive`.
- **Files:**
  - `src/OcuPilot/Kernel/State/Propose.cls`: the hold, its key and release; `CLAIMLOCKSECONDS` doc.
  - `src/OcuPilot/Kernel/State/Base.cls`: `GuardedTargetLock` doc (re-entry; escalation required).
  - `src/OcuPilot/Kernel/Proposal/Operation.cls`: `Hold`, `Release`, class doc.
  - `src/OcuPilot/Kernel/Proposal/Confirm.cls`: `Transition` holds and releases.
  - `src/OcuPilot/Api/ScreenAction.cls`: `Run` holds and releases.
  - `src/OcuPilot/Api/Error.cls`: `WRITETARGETBUSY` and its reason appended; one `ReasonForToolCode` line.
  - `scripts/check-objectscript.py`, `scripts/test_check_objectscript.py`: the marking arm and five harness cases.
  - `src/OcuPilot/Test/ReadBackRoute.cls`, `ConfirmRoute.cls`, `ProposalConfirm.cls`, `ProposalFixture.cls`, `ProposalSpelling.cls`: busy legs, the lock probe, 500 → 409.
  - `src/OcuPilot/Test/AccountPasswordWire.cls`: DW-1290.
  - `src/OcuPilot/Test/BackgroundSeed.cls`, `BackgroundTasksLive.cls`: Fix Pack comments.
- **Review:** 16 findings (medium 4, low 6, false 5, maybe-false 1), grouped into 4 patched entries, 1 deferred, 10 rejected rows. Patched: medium 2 (the hold's span at the fresh read and the read-back in both callers; the confirm route's busy reason, now over HTTP), low 2 (the checker's three unexercised entry points; the wait's upper bound). Deferred 1: the Save route takes no hold (medium, the spec's named residual). Rejected: the forwarding test-port exemption (low, spec-named, no shipped case), the preview's no-hold (low), the first-named tool in the checker's message (low), the 845 sentence's process (maybe-false), and five false (the `:6` pointer, one key for both callers, the `Error.cls` line, the added helpers, the stricter pattern check).
- **Follow-up review:** not recommended. Patched high 0, medium 2, low 2; the lead's pre-answer asks for one only when a high was patched.
- **Verification:** mutations and runs under `Batch e (loop)`. The stage agent re-ran on the final tree (`OCUPILOT-LOAD:OK:errors=0`): `ProposalConfirm` run 290 (24/24), `ConfirmRoute` 291 (7/7), `ReadBackRoute` 292 (4/4), `ProposalSpelling` 293 (5/5), `AccountPasswordWire` 294 (6/6), and before the patches `BackgroundTasksLive` 279 (8/8), whose files the patches did not touch. The harness 140/140; `check-objectscript.py` 0 problems over the tree. `ocupilot-b-ci` holds no `^OcuPilotProbeLockFree` node and no target lock. EXPERIENCE.md and `ui/` are untouched.
- **Residual risks:**
  - A confirm on a busy target now waits up to 10 s before any gate, so a caller who also lacks a pair sees 409 there, not 403.
  - The per-entity Saves take no hold (deferred).
  - The AD-34 and AD-53 amendments are the lead's to apply with this batch.
  - DW-1366 closes as a side effect (`ProposalSpelling` 500 → 409); the lead records it.

Status: done
Blocking condition: none
