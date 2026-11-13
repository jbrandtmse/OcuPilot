---
title: 'Story 23.13: The range-end cleanup, part 11'
type: 'bugfix'
created: '2026-11-13'
status: 'done'
baseline_revision: 'df38df2d0caecc13074b30cad4933fb56428068b'
baseline_commit: 'df38df2d0caecc13074b30cad4933fb56428068b'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-23-10-the-range-end-cleanup-part-9-two-sweeps.md'
warnings: ['multiple-goals', 'oversized']
deferred:
  - summary: >-
      Journal records' Refresh action and refresh timer read the form's current criteria without going through open(), so an order picked but not yet searched reads in the new order while the table direction still follows the last search.
    evidence: |-
      journal-records.page.ts registers REFRESH_ACTION_ID with refresh.readNow() directly, and boundRead's cached RefreshRead reads search.criteria() (every held value); followOrder() runs only in open(). The Code Map's "every read goes through open()" does not hold for these two paths.
    location: >-
      ui/src/app/areas/os-management/journal-records.page.ts:377
    severity: low
  - summary: >-
      journal-records.browser-spec.mjs has no order 1 leg, so Newest first drawing newest first is pinned only in the component spec.
    evidence: |-
      The browser spec asserts the first ten seeded records ascending for order 0 only. ui/browser/** is Epic 20's contended footprint, so a leg is a lead decision.
    location: >-
      ui/browser/journal-records.browser-spec.mjs
    severity: low
---

<intent-contract>

## Intent

**Problem:** This story owns six ledger entries, each checked at `118158177`; the verdicts are under Design Notes › Dispositions. One is a CI flake that Story 23.9's fix did not close: the a11y walk's retried pass reran on the same stalled browser (DW-1822). Two are AD-10 classifier edges: KMIP start mode with journal encryption is never judged (DW-2431), and a resource edit that opens a privileged application to everyone mints ordinary (DW-2432). The rest are sixteen copies of one removal-row loop (DW-2525), a Newest first that draws its rows oldest first (DW-1979), and a paging edge in the same order (DW-2527).

**Approach:** Four area batches: 1 the a11y flake, 2 AD-10 arms, 3 removal rows, 4 journal order. Each batch is one implement pass and one code commit with CI green on its own head. Each fix gets a test that reddens before it, or the entry says why none can (Rule 19). The batches are independent, and batch 2 waits on the rulings under Escalations, so the lead may run 3 and 4 before it. Story 23.10's spec holds the earlier investigation; this spec restates what was re-checked at head.

## Boundaries & Constraints

**Always:**

- **Where to work.** `/Users/jbrandt/git/OcuPilot/.worktrees/epic-23` on `OCU-1-epic23`; check `git rev-parse --show-toplevel` first. Every IRIS MCP call carries `server: "ocupilot-slot-a"`.
- **Where tests run.** Tests, probes and mutations run only on `ocupilot-ci` (slot block under Verification), once `docker inspect -f '{{.State.Health.Status}}' ocupilot-ci` reads `healthy`. One test run in flight; wait for each to land in `%UnitTest_Result`; never re-submit after a client-side timeout. Every command runs in the foreground with `timeout: 600000`; a call moved to the background is waited on with polls under 170 s.
- **Batches.** One implement pass per batch, scoped to the items the lead names. Before each batch, re-run the two read-only Epic 20 checks under Design Notes › Contended.
- **Locating code.** Find code by symbol; line numbers are at `118158177`.
- **Writing code.** Wire codes, HTTP statuses and response bodies stay byte-identical except where the I/O matrix says CHANGED. Extend the sibling named under Design Notes › Siblings (Rule 31). Comments state the contract (Rule 14); non-ASCII in source is `$Char(n)` or `\uXXXX`.
- Every test added or changed creates and removes its own state.

**Never:**

- Any edit to `CLAUDE.md`, `.claude/**`, `_bmad/**`, `.github/workflows/ci.yml`, `ui/angular.json`, `ui/tools/ci-timings.json`, or the architecture spine (AD amendments are the lead's).
- A 22nd `scripts/check-objectscript.py` rule.
- An edit to a file Epic 20 has changed (Design Notes › Contended), beyond add-only, before the orchestrator's ruling; any Epic 20 worktree file.
- Raising a product bound (`AdminPort.ASYNCTIMEOUT`, the MDX bounds) or `navigationTimeoutMs` in `ui/browser/browser.config.mjs`. The a11y fix stays in the harness.
- A new error code, a new on-screen string, or a stored-schema change, except where an escalation is answered first.
- A write, load or compile on `ocupilot`; a stop, restart, recreate or `down` of any container (Task 0's one `docker restart` needs the lead's grant); any docker command against a container not named `ocupilot-ci`.
- The full browser suite (CI's) or the full ObjectScript sweep (the lead's).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| CHANGED: a stalled browser during the walk (DW-1822) | A pass's page call goes unanswered past `WALKCALLDEADLINE` on browser 1 | The pass reruns once on a newly launched browser; browser 1 is closed under `CLOSEDEADLINE`; the report names the retried pass | Today the rerun uses browser 1 and hangs again |
| CHANGED: the retry also fails (DW-1822) | The rerun fails too | The walk throws, and the error carries the `retried` lines | Today a failed walk does not say whether the retry ran |
| CHANGED: public USE on a privileged application's resource (DW-2432) | A resource create or update adding `U` to the public permission of a resource that an enabled web or privileged routine application uses as `Resource`, while its `MatchRoles` grant `%All` or an `%Admin_*` role | Minted `GRANT.PRIVILEGED` at the destructive treatment, both callers; a failed list or read counts | Today ordinary |
| Unchanged: the same edit otherwise | Only `R` or `W` added; the application disabled; it grants only `%DB_HSCUSTOM`; the resource guards nothing | Ordinary | — |
| CONDITIONAL: KMIP with journal encryption (DW-2431) | KMIP startup with `DBEncJournal` on and none of the three databases encrypted | Refused before any write if Task 0's start does not finish; else unchanged | Code and sentence: escalation 1 |
| Unchanged: delete cards (DW-2525) | Each of the 16 delete bodies' proposal | Same removal rows, field order and values as today | — |
| CHANGED: Newest first (DW-1979) | Order 1 under the declared Address sort | Rows drawn newest first; the remembered direction is desc | Today oldest first |
| Unchanged: Oldest first | Order 0 | Rows drawn ascending | — |
| Unchanged: a person's own sort | Sort set to another column | The order does not touch the direction | — |

</intent-contract>

## Code Map

### Batch 1: the a11y flake (DW-1822)

- **CI evidence** (run 43379465200 attempt 1, browser shard 1/5, `64e58441`; log in `scratchpad/e23u/23-13/plan/a11y/`): `before` failed with "720px light: settle /ocupilot/agent/governance?ns=HSCUSTOM timed out ... abandoned by withDeadline after 60000 ms" at `protocol-retry.mjs:48`; all 13 tests failed on the hook (652.7 s); the unbounded `after` close took about 158 s. Attempt 2 was green (walk 393.5 s, no retry). The 652.7 s fits a retried pass that hung again (inference, from visit 152 of 213 and the two passes' durations). This is the only a11y failure in the CI runs since 23.9 merged.
- `ui/browser/structural-walk.mjs`: `bounded` (:190) wraps each walk call in `WALKCALLDEADLINE` (60 s); `settle` (:683) reads `fonts.status` and `aria-busy` through it; `passRetrier(report, entries)` (:820) reruns a whole pass through `retryOnce` with a synchronous `reset`; `walk(browser, config)` (:857) runs both passes through `signedInAt(browser, ...)` (`panel-spec.mjs` :101), so a rerun opens a new context on the **same** browser.
- `ui/browser/protocol-retry.mjs`: `withDeadline` (:44), `retryOnce(create, reset)` (:70; `reset()` at :75 is not awaited), `CLOSEDEADLINE` (:86), `relaunchOnce(open, relaunch, browser, closeDeadline)` (:103; closes under `withDeadline` :109; fires only on `isNavigationTimeout`). Its one user: `data-table-columns.browser-spec.mjs` :116.
- `ui/browser/a11y-structural-invariants.browser-spec.mjs`: `before` (:46) launches one browser and calls `walk`; `after` (:53) closes it with no bound.
- Tests: `ui/tools/structural-walk.test.mjs` "a pass whose call hangs is re-run once" (:185), the `passRetrier` report case (:214), "the walk's report names each retried pass" (:242). `ui/tools/protocol-retry.test.mjs` holds `relaunchOnce`'s fake-launcher pin.

### Batch 2: AD-10 arms (DW-2431, DW-2432)

- `src/OcuPilot/Kernel/Proposal/Prohibited.cls`:
  - `EncryptionStartup` (:3133) judges the journal (:3150-3157) only `If tMode = "Interactive"`; KMIP goes through `LeavesKmipRequired` (:3181), which reads `STARTUPREQUIREDFLAGS` (:545: audit, IRISSECURITY, IRISTEMP) and the on-disk read. Siblings: `LeavesModeRequired(pMode, pPayload, pTarget, pEncryptedOnDisk)` (:3189), `SetsJournalEncryption` (:3205), `LeavesInteractiveJournal` (:3216), `StartupJournalRefused(pPort)` (:3227), `ReadMember` (:3246). Reasons: `STARTUPJOURNALREASON` (:563), `STARTUPKMIPREASON` (:573), which names only the three databases.
  - `GrantsPrivilegeByEffect` (:4713), resource arm (:4730-4733): `pGrants = ResourceGrantsAdministrativePrivilege(pId) && AddsPublicLetter(pPayload, tTarget)`. Helpers: `ResourceGrantsAdministrativePrivilege` (:4644), `AddsPublicLetter` (:2438), `IsPrivilegedRole` (:4854), `ApplicationRolesEscalate(pPayload, pTarget, .pEscalates)` (:6111), `WidensPrivilegedReach` (:6138), `ResourcePublicUse` (:6159; a `Security.Resource GET` through `PortClass()`, a failed read counts), `EnabledOn` (:6167), `PortClass()` (:1391). No helper lists applications by `Resource` today.
- Port reads (`AdminPort.Invoke`): `WebApp.App LIST` and `Security.PrivilegedRoutine LIST` rows carry `Enabled`, `Resource`, `Type`, but no `MatchRoles`; routine rows read `Enabled` false, so one `GET` per matching application is needed (read-only probe on `ocupilot-slot-a`, raw output in `scratchpad/e23u/23-13/plan/ad10/`). Both lists need the same privileges as the resource list (inference).
- `src/OcuPilot/Test/ProhibitedFixture.cls` `PortClass` (:29) answers through `ProposalFixture.Invoke` (:275), which cannot answer a LIST, so every fixture-minted lookup reads as failed and counts.
- Tests: `EncryptionStartupWrite` (armed, 3.4 s) :357 and :393; `EncryptionStartupDescriptor` (2.4 s) :149, :218; `WebAppWeakening` (armed, 27.5 s) :244; `RoutineAppGrant` (armed, 3.1 s) :217; `ResourceUpdate` (1 s) :169; `ResourceCreate` (3 s; case 3 mints a non-privileged create with "RU" and expects ordinary, so it starts reading the live lists); `ProhibitedByEffect` (3.5 s); `Prohibited` (11.5 s).
- Strings: `privilegedGrantEffect` (`ui/src/app/core/strings.ts` :1715, EXPERIENCE.md :403); `encryptionStartupKmipRefusal` (:6107, EXPERIENCE.md :364), pinned at `ui/tools/self-protection.test.mjs` :311. `Area/Permissions/ResourceRules.cls` :202, :239 sets the field line from the resource name only.
- Task 0 reference: Story 18.48's M2b (`spec-18-48-epic-18-burn-down-part-2.md` :61-75, :203-215): a KMIP server configured for startup at an unreachable host was accepted, and its start read `exited unhealthy 3` by +184 s. Do not run or copy 18.48's scripts.

### Batch 3: removal rows (DW-2525)

- `src/OcuPilot/Screen/Tool/Write.cls`: `REMOVALROWS` (:560), `RemovalRows(pFresh, pSkipUnassigned = 0)` (:571; doc :562-570) iterates `$ListFromString(..#REMOVALROWS)`. `ReadAnswers()` (:458) and `FingerprintSubject()` (:504) already return a `$List`, so no conversion is needed. 16 classes call it today.
- The 16 bodies, all in `StateDiff`, each identical to `RemovalRows`'s loop, each after a precondition that refuses a non-object `pFresh` (recounted at head):
  - Over `..FingerprintSubject()`, no skip (11): OAuthServerDescriptionDelete, AuditUserEventDelete, TaskDelete, WebAppDelete, SslDelete, OAuthServerClientDelete, OAuthClientDelete, LdapDelete, ResourceDelete, RoleDelete, UserDelete.
  - Over `..ReadAnswers()`, with the unassigned skip (4): SuperserverDelete, DocDbAppDelete (RoutineAppDelete inherits it), WalletSecretDelete, WebAppPctAccessDelete.
  - Over `..ReadAnswers()`, no skip (1): MappingDelete (abstract; Global, Package and Routine subclasses).
- Readers of those rows (CI seconds): `ResourceDelete` 2.9, `RoleDelete` 3.0, `TaskScheduleActions` 2.5, `TaskResume` 106.6, `WalletSecretDelete` 5.7, `DocDbAppDescriptor` 2.1, `RoutineAppDescriptor` 0.8, `OAuthServerDelete` 9.5, `OAuthDelete` 2, `LdapCreate` 3.7, `AuditEventTools` 2.1, `WebAppPctAccess` 4.4, `ProhibitedRoute` 22.6. None found for SslDelete, UserDelete, SuperserverDelete, MappingDelete (a failed lookup, not proof).
- Other `"removed"` shapes, each different: ErrorDelete, LockRemove (arrays); MftConnectionRevoke, UserTokenRevoke, ExplorerDelete (one state row); OAuthResourceServerDelete, OAuthAuthorizationServerDelete (raw `%Get`); the four key tools' `MergeUpdate` (rows from arguments); `Area/Security/OAuthAuthorizationServerRules` :582.
- Sweep sibling: `OcuPilot.Test.CompositeMintSweep` `TestNoShippedMintBypassesTheBasePass` (:180) reads each class's own method source from `%Dictionary.MethodDefinition` (`OwnMintSource` :243) with a floor.

### Batch 4: journal order (DW-1979, DW-2527)

- `src/OcuPilot/Screen/Descriptor/JournalRecordList.cls` :55: default sort `Address`, direction `asc`; criterion `order` 0 or 1 (:61, the vendor's `reverse`).
- `ui/src/app/core/screen-store.ts`: `sort()` (:478), `setSort` (:482), `direction()` (:488), `setDirection` (:492; `SortDirection` is `'' | 'asc' | 'desc'`, `''` takes the declared one, :39), `rememberView` (:577, AD-50). Its sibling caller: `ui/src/app/shell/command-bar.ts` `onChooseDirection` (:1031).
- `ui/src/app/areas/os-management/journal-records.page.ts`: every read goes through `open()` (:427): cold open (:371), arrival (:370, :385), Search (`onSearch` :527), Next records (`onNext` :537). `nextOffset` (:105) reads the read's own rows, not the sorted view.
- Spec: `journal-records.page.spec.ts` (`mount()`, `choose`, `next`; AC2 at :268; the PORT.TIMEOUT fault at :313).
- DW-2527, read on `ocupilot-slot-a`: the vendor's hidden `%Api.Admin.Endpoints.Journal.ListTask.RunTask` loops `While rset.%Next(.sc) && (rowNum <= ..MaxRows)`, so `%Next` runs before the cap check and always seeks one more match.

## Tasks & Acceptance

**Execution:**

- One implement pass per batch leaves the tree for one commit: `fix(23.13): batch <n> - <area>`.
- Each task names its pinning test; its `mutation:` line goes under Verification with the observed run.
- In the same pass, update every test that asserts a shared surface's old shape (Verification › Shared surfaces).
- The lead writes the ledger trailers once the batch's commit is green.

### Batch 1: the a11y flake (DW-1822)

- [x] `ui/browser/protocol-retry.mjs`: `retryOnce` awaits `reset()`, so a reset may be async. The existing synchronous resets are unaffected.
- [x] `ui/browser/structural-walk.mjs`: `walk(browser, config, relaunch)` holds the current browser. `passRetrier` takes an async reset that, before the rerun, closes the current browser under `withDeadline(..., CLOSEDEADLINE)` and replaces it with `await relaunch()`, as `relaunchOnce` does. Both passes open through the current browser. `walk` answers `{entries, report, browser}`. When the walk throws, the error carries the report's `retried` lines. Without `relaunch`, a rerun keeps today's behavior. The doc states the contract.
- [x] `ui/browser/a11y-structural-invariants.browser-spec.mjs`: `before` passes a `relaunch` that launches with the same options and keeps the browser `walk` answers; `after` closes under `CLOSEDEADLINE`.
- [x] **Pin**, in `ui/tools/structural-walk.test.mjs`, beside :185, with fakes and `mock.timers`: a launcher whose browser 1 never answers `evaluate` in any context and whose browser 2 answers. The pass completes on browser 2, one relaunch happened, browser 1's `close` was called (and abandoned after `CLOSEDEADLINE` when it never resolves), and `report.retried` names the pass. A second case: both browsers stall, and the thrown error carries the `retried` line. Red before. Mutations: rerun on the original browser (red: hangs twice); drop the `await` on reset (red); drop the `retried` lines from the error (second case red).
- [x] Run the real spec once on `ocupilot-ci` after the bundle is redeployed (Verification). No real-browser reproduction of the stall is attempted: an endless `evaluate` stalls one renderer, which a fresh context already escapes, so it would not model CI's stall (Design Notes).

### Batch 2: AD-10 arms (DW-2431, DW-2432)

Waits for escalation 5 (contention) before any `Prohibited.cls` edit. Task 0 needs escalation 4. DW-2432 needs no new string; the lead writes its AD-10 clause (escalation 2) before the batch's code commit (Rule 20). The DW-2431 widening needs escalation 1.

- [ ] **Task 0 (DW-2431), on `ocupilot-ci` after `LOAD-OK`, in the implement stage's own probe class (removed afterwards).**
  1. Read S0: start mode None, no active keys, all four flags off, no KMIP server.
  2. Through `EncryptionPort` with a path seam rooted at `/durable/t0-2313/`: create key file F1 with K1, list it, then `ActivateDB` (this sets Interactive, as 18.48's M3 measured).
  3. `Settings PUT {"DBEncJournal": true}`.
  4. In `%SYS`, through the vendor classes: a TLS configuration and a KMIP server at 192.0.2.1:5696, timeout 10, `DBEncStartKeyList` = K1's id.
  5. `PUT {"DBEncStartMode": "KMIP", "DBEncStartKMIPServer": <it>}`. Record each answer and code.
  6. Record: start mode, `DBEncJournal`, `DBEncStartRequired`, `OKNoDBEncKeyAtStartup`, the three databases' `EncryptedDB`, and the `messages.log` line count.
  7. Check that `docker ps --filter name=^ocupilot-ci$` shows only 1975->1972 and 52776->52773.
  8. Only with the lead's grant: `docker restart -t 120 ocupilot-ci`, then poll health for 10 minutes in foreground steps under 170 s, and read `messages.log` for KMIP and key-activation failures. Without the grant, HALT `blocked: Task 0 ready for restart`.
  9. After step 8, HALT `blocked: Task 0 complete; throwaway rebuild needed: <state>`.
  - **Decision rule.** The start does not finish: widen (next item), once escalation 1 is answered. A vendor refusal at step 4 or 5, or a start that finishes: keep the arm and record the evidence. Anything else (a half-applied write, a refusal that moved a fact): an `intent gap` HALT.
- [ ] **DW-2431, only if Task 0 widens.** `Prohibited.cls`: `LeavesInteractiveJournal` becomes `LeavesModeJournal(pMode, ...)`, as `LeavesModeRequired` is; `EncryptionStartup` runs the journal arm for Interactive or KMIP, and KMIP refuses with escalation 1's code and sentence, before any write, from either caller. Add `Codes()`/`ReasonFor`, the add-only `strings.ts` key, a `self-protection.test.mjs` pair and the EXPERIENCE.md row as the answer says. Pin: new `EncryptionStartupWrite` legs, KMIP with `DBEncJournal` on, both callers; red before. Mutation: drop KMIP from the widened branch.
- [ ] **DW-2432.** `Prohibited.cls`:
  - Add `AddsPublicUse(pPayload, pTarget)`: the payload adds `U` to the public permission, as `AddsPublicLetter` reads letters.
  - Add `GuardsPrivilegedApplication(pName) As %Boolean`. It lists web and privileged routine applications through `PortClass()`, keeps those whose `Resource` equals `pName` without regard to case, and reads each with a `GET`. It answers 1 when a read application is enabled (`EnabledOn`) and its roles escalate (`ApplicationRolesEscalate` over the read object). A failed list or read answers 1.
  - The resource arm becomes: `AddsPublicLetter` and either `ResourceGrantsAdministrativePrivilege(pId)`, or `AddsPublicUse` and `GuardsPrivilegedApplication(pId)`. The lookup runs only when `U` is added.
  - Treatment: `GRANT.PRIVILEGED` at the destructive treatment with the existing `privilegedGrantEffect` line. No new string, no field line (escalation 3).
  - Pins, red before: in `WebAppWeakening`, a probe web application granting `%All`, enabled, over a probe resource with public `""`: a resource update adding `U` mints `GRANT.PRIVILEGED`; adding only `R`, a disabled application, an application granting only `%DB_HSCUSTOM`, and a resource guarding nothing each stay ordinary. The routine-application twin goes in `RoutineAppGrant`. A failed lookup counts: a `ProhibitedFixture` leg (its LIST always fails). `ResourceCreate` stays green unchanged.
  - Mutations: drop the new clause; answer a failed read as 0; read `Enabled` from a routine application's list row.

### Batch 3: removal rows (DW-2525)

- [ ] `src/OcuPilot/Screen/Tool/Write.cls` `RemovalRows` gains a trailing `pNames As %List = ""`: when non-empty, the rows follow those names in that order; else `REMOVALROWS` as today. The doc states the contract.
- [ ] The 16 bodies keep their preconditions, messages and `Try`, and set `pRows = ..RemovalRows(pFresh, <0, or 1 for the four with the skip>, ..FingerprintSubject())` (or `..ReadAnswers()`).
- [ ] **New-site catch and pin**, new `src/OcuPilot/Test/RemovalRowsSweep.cls` (unarmed), following `CompositeMintSweep`:
  - For every `OcuPilot.Screen.Tool` class whose own `StateDiff` source sets `"removed"`, the body calls `RemovalRows`, or the class is on an allow-list naming each other shape (Code Map). The checked count is asserted `> 0`. Red before, naming the 16. Mutation: put one body's loop back.
  - `RemovalRows` with a names list answers rows in that order with each value's `Mint.Display`; with the skip it omits an unassigned name; with no names it reads `REMOVALROWS`. Red before (no argument).
- [ ] **Equal behavior.** The 13 readers' per-class totals are equal before and after; Story 23.9's mutation (drop `removed` in `RemovalRows`) reddens each of `ResourceDelete`, `RoleDelete`, `TaskScheduleActions`, `DocDbAppDescriptor`, `WalletSecretDelete` after the lift.

### Batch 4: journal order (DW-1979, DW-2527)

- [x] `ui/src/app/areas/os-management/journal-records.page.ts` `open()`: before the read, when the store's sort is the declared default (`''` or `Address`), order 1 calls `setDirection('desc')` unless it is already desc, and order 0 calls `setDirection('')` when it is desc. Any other sort is left alone.
- [x] **Pin** in `journal-records.page.spec.ts`: rows at Addresses 300, 200, 100. Order 1 draws 300, 200, 100 and leaves the store's direction desc; order 0 draws 100, 200, 300; with sort `TimeStamp`, order 1 leaves the direction as it was. Red before. Mutations: remove the call; map order 1 to asc.
- [ ] `cd ui && npm run build`; record the journal records chunk and the initial total against the 2500 kB warning. Run `journal-records.browser-spec.mjs` after redeploy.
- [x] DW-2527: no code (Declined DW-2527 under Design Notes).

**Acceptance Criteria:**

- **Dispositions.** Given the six entries, when the story completes, then each is closed as Design Notes › Dispositions says, with its batch commit.
- **Red first.** Given each fix above, when its pinning test runs before the fix, then it is red, and after the fix green. DW-1822's stalled browser is shown through a fake launcher, and DW-2525's lift by equal reader totals plus a reddening mutation, each recorded under Verification.
- **Flake, at the surface.** Given the batch-1 commit, when `a11y-structural-invariants.browser-spec.mjs` runs on `ocupilot-ci` with the bundle redeployed, then it passes 13/13 and prints the walk report.
- **Grant at the surface.** Given a probe web application that grants `%All` over a probe resource, when the agent proposes adding public `U` to that resource on `ocupilot-ci`, then the card carries the privileged-grant line and the destructive confirmation (`WebAppWeakening`).
- **Order at the surface.** Given Journal records with Newest first, when a search runs, then the grid draws the newest record first (component spec, then the browser spec).
- **Integration (Rule 1).** Given `Write.RemovalRows`' names argument, when the 16 deletes mint their proposals, then each card's removal rows equal today's, as the 13 readers observe.
- **Batches.** Given the four batches, when each lands, then it is its own commit with CI green on its own head.

### Review Findings

#### Batch 1 (2026-11-13)

- [x] [Review][Patch] (med, fix-risk low, in-story) The bounded close was copied from `relaunchOnce` into `passRetrier`'s reset and the a11y spec's `after` (Rule 2): now one helper, `closeOrAbandon`, used by all three [ui/browser/protocol-retry.mjs:93]
- [x] [Review][Patch] (med, fix-risk low, in-story) No test pinned that `walk` hands `relaunch` to `passRetrier`; dropping it stayed green (Rule 19): the held-browser case now asserts the call [ui/tools/structural-walk.test.mjs:105]
- [x] [Review][Patch] (low) The `passRetrier` and `walk` doc comments said only a retried pass's error is annotated; the code annotates once any pass was retried (the spec's own wording) [ui/browser/structural-walk.mjs:822]
- [x] [Review][Patch] (low) The reset-error case's "unmarked" clause could not fail; it now reads the retried mark [ui/tools/protocol-retry.test.mjs:128]
- [x] [Review][Patch] (low) The test-file mutation headers lacked QA's mutations [ui/tools/structural-walk.test.mjs:29]

Rejected:

- Spec `status: done` with batches 2-4 open: build-auto's per-pass state, which the lead owns; editing it edits the spec under review.
- The pass body's bounded `context.close()` on a stalled browser replaces the stalled call's error (pre-existing): false for the observed stall, where the surfaced error named `settle`.
- A stall inside the wrapped `createBrowserContext` is marked by its inner retry and is not relaunched: outside the matrix row (a page call past `WALKCALLDEADLINE`) and not observed.
- An abandoned browser is not killed: a rare path, and a kill adds a branch to `relaunchOnce` too; reopen if a relaunched rerun also stalls in CI.
- `relaunch()` answering null or rejecting, a read-only `message`, a non-object throw: no caller or error type here does that.
- The `--write` path's error now carries retried lines: the spec asks it of every walk failure; the rerun itself is unchanged.
- "Flake, at the surface" has no `mutation:` line: the spec runs it as a non-regression check, and the stall is pinned through fakes (Design Notes).
- Auto Run Result counts, cycle-log fields, Verification nesting, red-before shown by mutation: bookkeeping, not code; the spec is oversized.

## Spec Change Log

## Review Triage Log

### 2026-11-13 — Review pass (batch 4)

- verdicts: 7 findings — high 0, medium 1, low 5, false 0, maybe-false 0 (one intent-alignment report, descriptive)
- findings:
  - `[medium]` `[patch]` verification-gap: the guard around a sort the person chose and the explicit `Address` branch had no pin and no mutation line — patched: an explicit-Address case added, three guard mutations applied, observed red, reverted, lines written under Verification.
  - `[low]` `[defer]` verification-gap: `journal-records.browser-spec.mjs` has no order 1 leg — `ui/browser/**` is contended and the spec asks only to run it; deferred (frontmatter).
  - `[low]` `[reject]` verification-gap: the test title says "remembers the direction" while only `store.direction()` is read — that store state is what `rememberView` stores; a persistence assertion would add a seam.
  - `[low]` `[reject]` verification-gap: a header-toggled direction is reset by the next search — the spec's Decided in-stage item 2.
  - `[low]` `[defer]` intent-alignment: the Refresh action and the refresh timer read without `open()`, so the direction follows only at Search, Next and arrivals — deferred (frontmatter); the fix moves the call into the cached read.
  - `[n/a]` `[reject]` intent-alignment: readings B (server order) and F (persistence across sessions) — the intent's row is the table direction; the lead's browser run is the real-bundle check.
  - `[n/a]` `[reject]` intent-alignment: `''` counts as the declared sort — the spec's own wording.

### 2026-11-13 — Review pass

- verdicts: 7 findings — high 0, medium 1, low 4, false 0, maybe-false 0 (two intent-alignment observations are descriptive, not findings)
- findings:
  - `[medium]` `[patch]` verification-gap: no test shows `walk` opens both passes through the held browser; reverting a `signedInAt(held` to `browser` stays green — patched: source-structure case in `structural-walk.test.mjs`, mutation observed red and reverted.
  - `[low]` `[reject]` the a11y spec's relaunch wiring and `after` close have no executed check — a real stall cannot be reproduced (Design Notes); the first launch and the relaunch share one `launch` closure, and the real spec ran 13/13; a test would need a new seam.
  - `[low]` `[patch]` three pins lacked an observed `mutation:` line (no-relaunch keeps the browser, close under `CLOSEDEADLINE`, held browser) — closed in-pass: mutations applied, red observed, reverted, lines written under Verification.
  - `[low]` `[reject]` the failure message carries earlier passes' retried lines — each line names its own pass, so the text stays accurate; changing it adds branching.
  - `[low]` `[reject]` a failed `relaunch()` propagating with the closed browser held is not pinned — the walk throws either way, and `after` closes under a deadline.
  - `[n/a]` `[reject]` intent-alignment: `retryOnce`'s awaited reset reaches every caller — all other callers pass synchronous resets, and the awaited form is the spec's own task.
  - `[n/a]` `[reject]` intent-alignment: the `--write` CLI path passes no `relaunch` — the spec scopes the relaunch to the a11y spec, and without it a rerun keeps today's behavior.

## Design Notes

**Dispositions** (lead writes them through `ledger.sh` after each green batch):

| Entry | Batch | Disposition |
|---|---|---|
| DW-1822 | 1 | `resolved-by` its commit, `reopen_if=a11y-structural-invariants fails with a retried line naming a relaunched pass` (that would point at the product, not the browser). The routing comes from the epics file and the orchestrator's trailer on feature; this worktree's copy still reads resolved by 23.9. |
| DW-2431 | 2 | Widened: `resolved-by`. Kept: `wontfix-accepted`, `reopen_if=a KMIP start with journal encryption on and none of the three databases encrypted does not finish`, citing Task 0. |
| DW-2432 | 2 | `resolved-by` |
| DW-2525 | 3 | `resolved-by` |
| DW-1979 | 4 | `resolved-by` |
| DW-2527 | 4 | `wontfix-accepted`, `reopen_if=a person reports a Journal records search answering PORT.TIMEOUT` (Declined DW-2527). |

**Declined DW-2527:** no port or page change can stop the vendor's extra `%Next` (Code Map › Batch 4), and the scan it pays is the one every filtered read with fewer matches than the cap already pays to the start or end of the file. The page already shows `PORT.TIMEOUT` as the screen's fault (spec :313), and the 30 s bound is product behavior (Never).

**Governing ADs:** AD-10 (DW-2431, DW-2432); AD-55 (a Save resolves through the tool, so DW-2432's treatment covers both callers); AD-3 and AD-51 (DW-2525: the diff a delete's card shows); AD-19 and AD-50 (DW-1979: store state, the remembered view); AD-26 and AD-36 (DW-2527: the async bound and the bounded read). No AC contradicts an AD's Rule; DW-2432 and a widened DW-2431 each need an AD-10 clause (escalations 1 and 2).

**Siblings (Rule 31):**

- The walk's relaunch extends `relaunchOnce`'s close-and-relaunch to `passRetrier`'s rerun; `relaunchOnce` itself retries one `open` on a navigation timeout and cannot hold a pass.
- `LeavesModeJournal` follows `LeavesModeRequired`. `GuardsPrivilegedApplication` reuses `ApplicationRolesEscalate`, `EnabledOn` and `PortClass()`; `AddsPublicUse` follows `AddsPublicLetter`.
- `RemovalRows` takes a names argument rather than reading `FingerprintSubject()`, which would tie `Write` to two parameters. `RemovalRowsSweep` follows `CompositeMintSweep`.
- DW-1979 calls the store's existing `setDirection`, as `command-bar.ts` `onChooseDirection` does.

**Integration ACs and linkage (Rules 1, 2):**

- `Write.RemovalRows(pFresh, pSkip, pNames)`. Consumed-by: the 16 delete bodies (Integration AC).
- `walk(browser, config, relaunch)`. Consumed-by: `a11y-structural-invariants.browser-spec.mjs`.
- `GuardsPrivilegedApplication` and `AddsPublicUse` are private to `Prohibited`. Consumed-by: `GrantsPrivilegeByEffect`.
- Consumes: none.

**Decided in-stage:**

1. DW-1822 is fixed in the harness by relaunching the browser for the rerun; no product bound changes. The rerun is the one CI already allows; this only moves it off a stalled browser.
2. DW-1979: order 0 restores the declared direction (`''`) rather than writing `asc`, so the remembered view goes back to the default. A person who picks desc under Oldest first is set back at the next search; a person's sort on another column is left alone.
3. DW-2525 keeps OAuthAuthorizationServerDelete on the allow-list: it reads its one row with a raw `%Get`, and moving it is outside the entry.
4. DW-2432's lookup also runs on a resource create that adds `U`, since an application can name a resource before it exists.
5. Batch order is the lead's; batches 3 and 4 need no answer and may run before batch 2.

**Escalations for the lead's spec gate:**

1. **Wording (DW-2431, only if Task 0 widens).** Recommended: a new code `PROHIBITED.STARTUPKMIPJOURNAL`, its reason, a `strings.ts` key (add-only) and an EXPERIENCE.md row. Proposed text: "Journal encryption is on, or a journal file the instance still needs is encrypted, and OcuPilot cannot check that the KMIP server is reachable and holds its key, so a start that cannot activate it does not finish. Keep Unattended, or make this change on the classic Database Encryption page." Rewriting `STARTUPKMIPREASON` instead changes a published string. AD-10's KMIP bullet (spine :383) gains: "or while journal encryption is on, or a journal file the instance still needs is encrypted, refused `PROHIBITED.STARTUPKMIPJOURNAL` (DW-2431)". Both are veto-window items: stricter than the classic portal, and an AD amendment.
2. **DW-2432's AD-10 clause.** The treatment was ruled by the orchestrator (2026-10-14). The spine has no DW-2425 sentence; the closest is :425 (DW-2322). Proposed, after it: "so is adding public `U` to a resource that an enabled web or privileged routine application uses as its `Resource` while its roles grant a privileged role (read at the write; a failed read counts) (DW-2432)". The lead may want DW-2425's own clause (an application's enabling or public-resource repoint) in the same amendment, since the spine lacks it too.
3. **Optional field line (DW-2432).** `ResourceRules` (:202, :239) marks the field only for a privileged resource name, so a person's Save gets the card's line and no field line. The plan keeps parity with DW-2425 (none). If wanted: "Every user may now use this resource, and an enabled application it guards runs with %All or an administrative privilege."
4. **Task 0's restart.** One `docker restart -t 120 ocupilot-ci`; the lead grants it at batch 2 or runs the step itself. A rebuild follows, because the encryption state stays in the volume (inference).
5. **Contention, `Prohibited.cls`.** Epic 20 has changed it (Story 20.40: `ITEMCOPYFIELDS` :307, `PermittedCreateFields` :1357, `Prohibits` :1567, new `ItemCopied` after `Copied`), and 20.26 and 20.41 plan it. Batch 2 edits other regions (:545-579, :2438, :3133-3260, :4644, :4713-4800, :6111-6172) but changes existing methods, so the orchestrator rules before the edit. Recommended: allow, separate regions.

**Orchestrator rulings at the spec gate (2026-11-13; these replace escalations 1, 2 and 5):**

1. **DW-2432: comply under the existing AD-10 arm.** The spine already carries DW-2425 (ARCHITECTURE-SPINE.md :427: a web or privileged routine application's `Resource` changed to one whose public permission holds `U`, read at the write, a failed read counts). Adding public `U` to the resource such an application already uses is the same effect reached from the resource side, and AD-10 is defined by effect. Implement it with DW-2425's treatment and no new field line. Do not edit the spine (AD-10 is cited by in-flight Epic 20 specs). Escalation 2's clause stays here as proposed for the owner's architecture Update (veto item U-29).
2. **DW-2431: Task 0 first.** If the KMIP start with journal encryption finishes, DW-2431 closes on that evidence with no code. If it does not finish, the widening stops for this run (it needs a new refusal code, an AD-10 amendment): the implement stage HALTs `blocked` with `Task 0 measured: start does not finish` and the evidence, adds no code, no string and no row, and the lead records it for the owner. Escalation 1's text waits with it.
3. **Prohibited.cls contention: allowed.** Batch 2's regions are disjoint from Epic 20's; whichever epic integrates second resolves the plain union.
4. Decided by the lead: no new field line for DW-2432; Task 0's one `docker restart -t 120 ocupilot-ci` is granted (the throwaway this run started); DW-2527 `wontfix-accepted`.

**Contended** (Epic 20 at `f57371d1e`; re-check before each batch with `git -C /Users/jbrandt/git/OcuPilot/.worktrees/epic-20 diff --stat origin/feature/OCU-1_ocupilot-mvp...HEAD` and `status -s`):

- `src/OcuPilot/Kernel/Proposal/Prohibited.cls`: changed; escalation 5.
- `ui/src/app/core/strings.ts` and EXPERIENCE.md: changed; touched only add-only, and only if escalation 1 asks.
- Not changed by Epic 20: the batch 1 files, `Screen/Tool/Write.cls`, the 16 delete tools and their subclasses, the test classes named here, `journal-records.page.ts` and its spec. `RemovalRowsSweep` is a new file.

**Release-upgrade triggers:** none. No `Kernel/State`, `Install`, `module.xml`, compose or start-script file, and no `Kernel/Governance/Baseline.cls` key.

**Size.** Six entries in four batches, about 250 changed lines (inference). Batch 2 carries a restart, a rebuild, three escalations and a contended file, any of which can hold the story open. If escalation 1 is still open once the other batches and DW-2432 are green, the recommendation is to move the DW-2431 widening to the next standing cleanup rather than hold this story.

## Verification

**Slot A, every batch:** IRIS MCP `server: "ocupilot-slot-a"`; throwaway `ocupilot-ci` (`--dir /Users/jbrandt/.ocupilot-throwaways/ocupilot-ci`, `--project ocupilot-ci`, `--web 52776`, `--super 1975`); `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776`, `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`. Never `ocupilot`. Each command is one foreground call with `timeout: 600000`.

**Commands** (`(loop)` the story's own tests; `(once)` before the batch's commit). The full ObjectScript sweep is the lead's; the full browser suite is CI's.

- `(loop)` Load: `rsync -a --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-23/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-ci/src/`, then `$System.OBJ.LoadDir("/opt/ocupilot/src","ck-d",.e,1)` through `docker exec -i ocupilot-ci iris session iris -U HSCUSTOM`. Expected: no compile error.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one class per call, totals from `%UnitTest_Result`:
  - batch 2: `EncryptionStartupWrite` 3.4, `EncryptionStartupDescriptor` 2.4, `Prohibited` 11.5, `ProhibitedByEffect` 3.5, `WebAppWeakening` 27.5, `RoutineAppGrant` 3.1, `ResourceUpdate` 1, `ResourceCreate` 3;
  - batch 3: `RemovalRowsSweep`, then the 13 readers (Code Map; about 168 s summed, `TaskResume` 106.6 alone).
- `(loop)` Client tests: `cd ui && node --test tools/structural-walk.test.mjs tools/protocol-retry.test.mjs` (batch 1); `node --test tools/self-protection.test.mjs` (batch 2, if widened); `npm run test:components` (batch 4).
- `(loop)` Browser specs, one file per call, after `cd ui && npm run build` and `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`: `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/<file>`; batch 1 `a11y-structural-invariants.browser-spec.mjs` (416.3 s), batch 4 `journal-records.browser-spec.mjs` (19.8 s).
- `(once)` `cd ui && npm run test:tools`; `uv run scripts/check-objectscript.py`; `bash scripts/lint-docs.sh` when a doc or EXPERIENCE.md changed.

**Shared surfaces:**

- Batch 1: `walk`'s signature and answer (one caller); `retryOnce`'s reset (now awaited; every `wrapBrowser` user).
- Batch 2: the `GRANT.PRIVILEGED` effect on resource creates and updates that add `U`; `Prohibited.Codes()` and `self-protection.test.mjs` if the arm widens. Sweep `src/OcuPilot/Test` for resource mints through `ProhibitedFixture` that add `U` and expect ordinary.
- Batch 3: the test-class roster (`RemovalRowsSweep` joins it); the delete cards' removal rows (unchanged in value).
- Batch 4: the journal records grid order and the person's remembered view.
- Sweep `ui/browser`, `ui/tools`, the `ui/src` specs and `src/OcuPilot/Test` for each old shape; every file changed joins that batch's `(loop)` set.

**Standing criterion:** every test added or changed passes on a fresh environment, in either order (Rule 30; the lead's `fresh_check`).

**Mutation lines** (filled per batch with the observed run): one per task's pin, as each task names.

- Batch 1 (DW-1822), pin `structural-walk.test.mjs` (stalled-browser relaunch, both-stall, no-relaunch cases) and `protocol-retry.test.mjs` (async reset); each applied, observed red, reverted, `git diff` equal to the pre-mutation diff:
  - mutation: drop `current = await relaunch()` in `passRetrier`'s reset (rerun on the original browser) -> the relaunch case and the both-stall case red (no second browser launched).
  - mutation: drop the `await` on `reset()` in `retryOnce` -> the relaunch case red in `structural-walk.test.mjs` and the async-reset case red in `protocol-retry.test.mjs`.
  - mutation: skip the `error.retried` and message lines in `passRetrier`'s failure path -> the both-stall case red alone.
  - mutation: open a pass's context through `browser` instead of `held` in `walk` -> the held-browser source case red.
  - mutation: drop the `relaunch === null` return in `passRetrier`'s reset -> the no-relaunch case and the retried-pass report case red.
  - mutation: drop the `withDeadline` in `closeOrAbandon` (`await browser.close()`) -> the relaunch case and `protocol-retry.test.mjs`'s wedged-browser case red (code review, observed).
  - Real spec on `ocupilot-ci` after `npm run build` and the redeploy: `a11y-structural-invariants.browser-spec.mjs` 13/13 in 459 s, the walk report printed (191 walked, 22 skipped, 0 unsettled), no retried line. The stall itself is shown through fakes only. `npm run test:tools` 2216/2216 after the last edit; `structural-walk` and `protocol-retry` tests 33/33.
  - (QA) added to `ui/tools/structural-walk.test.mjs` (a11y spec wiring pin; no-retry failure case) and `ui/tools/protocol-retry.test.mjs` (reset-error case); `structural-walk` and `protocol-retry` tests 36/36; each applied, observed red, reverted, `git diff` identical to the pre-mutation diff:
  - mutation: drop `browser = result.browser;` in the a11y spec -> the a11y spec wiring case red.
  - mutation: replace the spec's bounded close with `await closing.close()` -> the a11y spec wiring case red.
  - mutation: `walk` answers `browser` instead of `withRetry.held()` -> the a11y spec wiring case red.
  - mutation: annotate every failing pass's error, retried or not -> the no-retry failure case red alone.
  - mutation: swallow the error `reset` throws in `retryOnce` -> the reset-error case red alone.
  - (code review, observed, tree identical after) mutation: drop `relaunch` from `walk`'s `passRetrier` call -> the held-browser case red alone. Call `reset` inside the second attempt's `try` -> the reset-error case red alone. The a11y spec's `after` calls `closing.close()` instead of `closeOrAbandon` -> the a11y spec wiring case red alone. `test:tools` 2219/2219; after a rebuild and redeploy, `a11y-structural-invariants.browser-spec.mjs` 13/13 on `ocupilot-ci` in 535 s, no retried line.
- Batch 4 (DW-1979), pin `journal-records.page.spec.ts` (Newest first draws newest first and remembers desc; Oldest first restores the declared direction; another column's sort left alone); each applied, observed red, reverted, `git diff` identical to the pre-mutation diff:
  - mutation: remove the `followOrder()` call in `open()` -> the Newest first case red alone (this is also the red-before state).
  - mutation: map order 1 to `asc` -> the Newest first case red alone.
  - mutation: drop the declared-sort half of the guard (`sort !== ''` only) -> the explicit Address case red alone (review, observed).
  - mutation: remove the guard's early return -> the other-column case red alone (review, observed).
  - mutation: drop the `setDirection('')` restore in the order 0 branch -> the Newest first case red alone (review, observed).
  - Component spec 16/16; `npm run test:components` 3362/3362 (261 files); `npm run test:tools` 2219/2219; `npm run build` clean, no budget warning: journal records chunk 11.93 kB raw, initial total 2.02 MB against the 2500 kB warning.
  - `journal-records.browser-spec.mjs` after redeploy: lead, fresh check (not run in this pass).

## Auto Run Result

Status: done
Blocking condition: none

Batch 4 (DW-1979) pass: the journal records page now follows the order select with the table direction; DW-2527 is declined, no code. Batch 1 closed in its own pass; batches 2 and 3 are untouched and their checkboxes stay open.

- **Change:** `open()` calls `followOrder()` before the read: under `''` or the declared sort, order 1 sets direction `desc` and order 0 restores `''`; another column's sort is left alone.
- **Files:** `ui/src/app/areas/os-management/journal-records.page.ts` (`followOrder`); `ui/src/app/areas/os-management/journal-records.page.spec.ts` (three cases).
- **Review:** 1 medium patched (guard pin and mutations), 2 deferred (browser order 1 leg; Refresh path), 4 rejected with reasons in the triage log. Follow-up review recommended: false.
- **Verification:** component spec 16/16; `npm run test:components` 3362/3362; `npm run test:tools` 2219/2219; `npm run build` clean (chunk 11.93 kB, initial 2.02 MB of 2500 kB). `journal-records.browser-spec.mjs`: lead, fresh check (not run here); the build item's box stays open for it.
- **Residual risk:** the draw order is shown through the component spec only until the lead's browser run; a Refresh with an unsearched order change reads the new order under the old direction (deferred).
