---
title: 'Story 23.10: The range-end cleanup, part 9: two sweeps'
type: 'bugfix'
created: '2026-11-12'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['multiple-goals', 'oversized']
deferred:
  - summary: >-
      A person paging Journal records Newest first with a match filter whose matches end exactly at the page cap
      pays a backward scan to the start of the journal file, which can answer PORT.TIMEOUT after 30 s.
    evidence: |-
      The vendor's hidden %Api.Admin.Endpoints.Journal.ListTask.RunTask loops `While rset.%Next(.sc) && (rowNum <= ..MaxRows)`,
      so it always looks for one more match after the cap (read on ocupilot-slot-a); the timeout itself is unmeasured (inference).
    location: >-
      src/OcuPilot/Port/AdminPort.cls AwaitTask (:3610), ASYNCTIMEOUT (:1080), HALVEDROWTYPES (:956)
    severity: low (unverified)
---

<intent-contract>

## Intent

**Problem:** This story owns ten ledger entries, each checked at `9546204ad`; the verdicts are under Design Notes › Dispositions. Four are CI flakes that cost release-path reruns (DW-2513, DW-2517, DW-2522, DW-2524, which also closes DW-2493). Two are sweeps: a request body holding a number or string the instance cannot hold answers 500 instead of a field refusal (DW-2417), and 51 test classes delete shared policy or egress rows when their `OnBeforeAllTests` refused (DW-2426). The rest are two AD-10 classifier edges (DW-2431, DW-2432), sixteen copies of one removal-row loop (DW-2525), and a Newest first that draws oldest first (DW-1979).

**Approach:** Six area batches, in this order: 1 CI flakes, 2 request bodies (DW-2417), 3 test teardowns (DW-2426), 4 AD-10 arms, 5 removal rows, 6 journal order. Each batch is one implement pass and one code commit with CI green on its own head. Each fix gets a test that reddens before it, or the entry says why none can (Rule 19). Each sweep also gets a check that fails on a new site written the old way. Every entry ends `resolved-by`, `wontfix-accepted` (with `reopen_if`) or `by-design`, as Design Notes › Dispositions says.

## Boundaries & Constraints

**Always:**

- **Where to work.** `/Users/jbrandt/git/OcuPilot/.worktrees/epic-23` on `OCU-1-epic23`; check `git rev-parse --show-toplevel` first. Every IRIS MCP call carries `server: "ocupilot-slot-a"`.
- **Where tests run.** Tests, probes and mutations run only on `ocupilot-ci` (slot block under Verification), once `docker inspect -f '{{.State.Health.Status}}' ocupilot-ci` reads `healthy`. One test run in flight; wait for each to land in `%UnitTest_Result`; never re-submit after a client-side timeout. Every command runs in the foreground with `timeout: 600000`.
- **Batches.** One implement pass per batch, scoped to the items the lead names. Before each batch, re-run the two read-only Epic 20 checks under Design Notes › Contended.
- **Locating code.** Find code by symbol; line numbers are at `9546204ad`.
- **Writing code.** Wire codes, HTTP statuses and response bodies stay byte-identical except where the I/O matrix says CHANGED. Extend the sibling named under Design Notes › Siblings (Rule 31). Comments state the contract (Rule 14); non-ASCII in source is `$Char(n)` or `\uXXXX`.
- **A test class's teardown only undoes what its own setup did** (DW-2426), and every test added or changed creates and removes its own state.

**Never:**

- Any edit to `CLAUDE.md`, `.claude/**`, `_bmad/**`, `.github/workflows/ci.yml`, `ui/angular.json` or `ui/tools/ci-timings.json` (generated).
- A 22nd `scripts/check-objectscript.py` rule (CLAUDE.md pins 21; that line is the Planner's).
- An edit to a file Epic 20 has changed (Design Notes › Contended), beyond add-only; any Epic 20 worktree file.
- Raising a product timeout (`AdminPort.ASYNCTIMEOUT`, the MDX bounds) or `navigationTimeoutMs` in `ui/browser/browser.config.mjs`.
- A new error code, a new on-screen string, or a stored-schema change, except where an escalation under Design Notes is answered first.
- A write, load or compile on `ocupilot`; a stop, restart, recreate or `down` of any container (Task 0's one `docker restart` needs the lead's grant); any docker command against a container not named `ocupilot-ci`.
- Guarding inside `GovernanceFixture.Restore` (`AllowedDirectorySave` clears the policy through it on purpose).
- The full browser suite (CI's) or the full ObjectScript sweep (the lead's).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| CHANGED: oversized number in a body (DW-2417) | `POST` to an Area save with `{"Extra": 1e400}` (or nested `[1, -1e400]`) | 400 `PORT.FIELD.SHAPE`, `detail.violations[{field: "Extra", code: "PORT.FIELD.SHAPE", reason: <its published sentence>}]`, nothing written | Today 500 |
| CHANGED: oversized string or key (DW-2417) | A 4,000,000-character value (field named) or key (field `*`) | The same refusal | Today 500 |
| Unchanged: large but holdable values | `1e308`, `1e146`, a 1,000,000-character string | Read as today | — |
| Unchanged: malformed JSON | `{"a":` | Today's 400 `AGENT.BADBODY` | — |
| CHANGED: oversized tool argument (DW-2417) | A model tool call whose argument holds `1e400` | `ValidateArguments` answers the tool-arguments refusal it gives a wrong type | Today raises (inference) |
| CHANGED: refused setup (DW-2426) | `OnBeforeAllTests` refused (unarmed, or failed before its snapshot); a policy or egress row present | `OnAfterAllTests` changes nothing | Today every policy row, or the egress row, is deleted |
| Unchanged: armed run | Setup took its snapshot | Teardown restores it | — |
| CHANGED: public USE on a privileged application's resource (DW-2432) | Resource edit adding `U` to the public permission of a resource that an enabled web or privileged routine application uses as `Resource` while its `MatchRoles` grant `%All` or an `%Admin_*` role | Minted `GRANT.PRIVILEGED` at the destructive treatment; a failed lookup counts | Today ordinary |
| Unchanged: the same edit otherwise | Only `R` added; the application disabled; it grants only `%DB_HSCUSTOM`; the resource guards nothing | Ordinary | — |
| CONDITIONAL: KMIP with journal encryption (DW-2431) | KMIP startup with `DBEncJournal` on and none of the three databases encrypted | Refused before any write if Task 0's start does not finish; else unchanged | Code and sentence: escalation 1 |
| Unchanged: delete cards (DW-2525) | Each of the 16 delete bodies' proposal | Same removal rows, field order and values as today | — |
| CHANGED: Newest first (DW-1979) | Order 1 (Newest first) under the default Address sort | Rows drawn newest first; the remembered direction is desc | Today oldest first |
| Unchanged: Oldest first | Order 0 | Rows drawn ascending | — |

</intent-contract>

## Code Map

### Batch 1: CI flakes

- **Recurrence, measured** over the last 200 CI runs (2026-10-07 to 11-12; logs in `scratchpad/e23u/23-10/plan/a-logs/`): data-table-columns failed once, analytics-mdx twice (43292059964, 43290470415), context-chip twice (39654904051, 43316537748).
- **DW-2513** (run 40026736561 attempt 1): the 17 failures are `openHarness`'s `page.goto` (`ui/browser/data-table-columns.browser-spec.mjs` :115) timing out at 32.2-32.5 s from test 1. The spec's own server listens on port 0 (:98), and `ui/tools/ci-browser.mjs` runs one file per process, so a port clash is ruled out. Test 9 (painted scrollbars), the one test that launches its own browser (:441), passed in 4.3 s between failures against the same server. The shared `browser` from `before` was wedged (inference: its navigation stack; Chrome's stderr is not captured). `openHarness` leaks its context when `goto` throws.
- `ui/browser/protocol-retry.mjs`: `PROTOCOL_TIMEOUT`, `isProtocolTimeout`, `retryOnce`, `withDeadline` (Story 23.9). Tests: `ui/tools/protocol-retry.test.mjs` (fakes, no browser).
- **DW-2522**: AC1 waits for `[data-ocu-mdx="grid"]` at `ui/browser/analytics-mdx.browser-spec.mjs` :258 under `navigationTimeoutMs` (30 s). The product allows `Port/AnalyticsPort.cls` `MDXSECONDS` 120 (:198) plus `MDXSETTLESECONDS` 10 (:201); the client polls every 1 s. AC1 took 37.6 s and 41.2 s on the two failures, 9.1 s on a green run; AC2 took 5.6-6.4 s each time. A cold first `%ExecuteAsynch` in `USER` on a fresh leg is the likeliest cost (inference). Of the file's 13 Run sites, 6 wait on an answer (:258, :285, :389, :416, :440, :495), 4 on the confirm dialog, 2 on a refusal banner, 1 on the Running line (AC3).
- **DW-2524** (folds DW-2493; both red at `ui/browser/context-chip.browser-spec.mjs` :535, the second reply never drawn, 8 of 9 green): the stub streams, and `ui/src/app/shell/panel.ts` :561 draws streamed text in `.ocu-panel-message-agent-text` while the turn runs, so the first wait (:506) can pass while `TurnStore.busy()` is true. While busy, Send is Stop (`onSendOrStop`, :2032); the composer still types, so the click at :532 can stop turn 1 instead of sending turn 2. A second gap (inference): `Job.Run` holds the turn slot (`^OcuPilotTurnSlot`) until after `AppendConvoEntry`, so a Send there meets a 409. Siblings: `waitForReplies` in `panel-collapse.browser-spec.mjs` :148 and `transcript-follow.browser-spec.mjs` :110 (reply drawn and Send label `STRINGS.actionSend`); `slotOwner` in `ui/browser/turnprobe-spec.mjs`; `namedWaitForFunction` in context-chip. `TurnProvider.ScriptStream(tag, delay, texts, slices)` paces a stream.
- **DW-2517**: `src/OcuPilot/Test/JournalRecords.cls` `TestTheToolInReverseOrderKeepsTheNewestRowsUnderTheContextCap` (:218): the first call (:224) is order 1, desc, `maxRows` 20, cap 10; the second (:230) the same with offset = lowest kept Address - 1; +14 is :232. `Port/AdminPort.cls` doubles `maxRows` for this type (`HALVEDROWTYPES` :956), and `AwaitTask` (:3610) answers 503 `PORT.TIMEOUT` past `ASYNCTIMEOUT` 30 s (:1080). The vendor task always reads one record past the cap. With 30 probe records, the second page keeps records 20..1, which uses the 40 counts exactly. Its extra read then scans backward to the start of the journal file, which a sweep's earlier classes have made long (inference, not timed). `OcuPilot.Test.JournalProbe.SwitchFile()` (:543) exists.

### Batch 2: request bodies (DW-2417)

- **Measured on `ocupilot-slot-a`** (string limit 3,641,144): two-argument `%GetNext`, untyped `%Get(k)` and `o.k` each raise `<MAXNUMBER>` on `1e400`, `-1e400` or `1.8e308`, and `<MAXSTRING>` on a 4,000,000-character string; `1e146` and `1E308` read fine. Three-argument `%GetNext` returns the number's JSON text (type `number`) and a long string as a stream. A 4,000,000-character key raises in every form. `$IsValidNum` answers 0 for `1e146` and `1E308`, so it is the wrong test. Source: `irislib/%Iterator/Object.cls` :46-86.
- **Recount** (`scratchpad/e23u/23-10/plan/c/getnext.py`; parses each call's arguments and traces each iterator to its data): 1,802 two-argument sites in 625 files; 141 in 79 files iterate caller data (Area 88 in 49 files, Api 11, Kernel 26 (19 of them over a payload), Port 5, Screen 9, Test 2), plus 251 untyped reads of request-body data in 61 files. The 18.47 audit's 109/54 is not reproduced (inference: it counted Rules methods the script does not reach).
- `src/OcuPilot/Kernel/Utils.cls` `ReadRequestBody(Output pBody, Output pStage)` (:369; doc :355-368) is the only non-test reader of `%request.Content` / `GetMimeData`; its `parse` stage already reports malformed JSON. 64 call lines in 57 files.
- Area handlers wrap it in a private `Body(Output pBody) As %Boolean`, e.g. `Area/WebApp/PctAccessSave.cls` :185-191, and render `AGENT.BADBODY` (`Api/Error.cls` `AGENTBADBODY` :494) on 0. That is 51 `If '..Body(` call sites in 31 files, and about 16 handlers call `ReadRequestBody` directly.
- The field-refusal shape exists: `PORT.FIELD.SHAPE` (`Api/Error.cls` :3547) with `detail.violations[{field, code, reason}]` (AD-39), as `Area/RestService/Save` answers. `Test/RestServiceSave.cls` :217-231 already pins `1e999` for its own loop.
- Representative site: `Area/WebApp/PctAccessSave.cls` `UnexpectedKey` (:165-175), a two-argument loop over the body whose handler `Catch` renders 500. Wire test `Test/PctAccessSaveWire.cls` (armed, 1.5 s). `Test/Utils.cls` (0.1 s) has the `Test.BodyRequest` stand-in for `%request`.
- Tool arguments: `Screen/Tool/Registry.cls` `ValidateArguments` (:776), called from `Kernel/Agent/Dispatch.cls` :308 and :552. Test: `Test/ToolDispatch.cls` (4.1 s).

### Batch 3: test teardowns (DW-2426)

- `irislib/%UnitTest/Manager.cls`: OnBeforeAllTests at :1193 throws on error (:1199-1201); at `exit` (:1296) `:1298-1300` calls OnAfterAllTests when it erred. A failing normal-path teardown (:1282) is called again there (inference), so every teardown must be safe to repeat. OnAfterOneTest does not run after a failed OnBeforeOneTest.
- `Test/GovernanceFixture.cls` `Restore` (:17-33) deletes every row, then returns if `'$Data(pRows)`. `AllowedDirectorySave.NoSettings` (:156-160) clears through `Restore(.tNone)` on purpose.
- **Recount** (`scratchpad/e23u/23-10/plan/d/`, `class-list.tsv` lists each class with its file:line, arming variables and seconds): of 316 test classes with an OnAfterAllTests, 73 reach a shared-state call. The unguarded ones:
  - 47 classes (46 edit sites; `RoutineAppGate` inherits `DocDbAppGate` :119) call `GovernanceFixture.Restore` with a snapshot taken after the arming check. Three of them (`ClassicPageGate`, `NamespaceWriteGate`, `TaskTransferLive`) can also exit between the check and the snapshot.
  - `EgressSettingsWire` :48 calls `Egress.DeleteGuarded()`.
  - Three beyond the ledger's 48: `AuditEvent` :80 and `AuditMarker` :67 run `Installer.Install("")` unarmed; `SuperserverProhibited` :81 has no arming check and restores over no snapshot when its snapshot fails.
- **The 51** (in `src/OcuPilot/Test/`): EgressSettingsWire, AuthOptionsGate, AuthOptionsWrite, ClassicPageGate, DatabaseActions, DatabaseActionsGate, DatabaseActionsProhibited, DatabaseGrowExpand, DatabaseIntegrity, DatabaseWrite, DatabaseWriteDetail, DatabaseWriteGate, DocDbAppGate, DocDbAppWrite, EcpDataServerStatus, EcpSettingsGate, EcpSettingsWrite, EcpSslConnectionWrite, EcpWriteGate, EncryptionKeyFileWrite, EncryptionKeyGate, EncryptionKeyWrite, EncryptionStartupGate, EncryptionStartupWrite, EncryptionWriteGate, LicenseServerWrite, LicenseWriteGate, MappingWrite, MftConnectionGate, NamespaceInterop, NamespaceInteropGate, NamespaceWrite, NamespaceWriteGate, RemoteDatabaseListing, RemoteDatabaseWrite, RemoteDatabaseWriteGate, RoutineAppGate (inherits DocDbAppGate's teardown; no edit), RoutineAppListsRead, RoutineAppMembers, RoutineAppWebAppGuard, RoutineAppWrite, SqlAdminPrivilegeWrite, SqlColumnPrivilegeWrite, SqlPrivilegeGate, SqlPrivilegeWrite, SuperserverGate, SuperserverProhibited, SuperserverWrite, TaskTransferLive, AuditEvent, AuditMarker. Every one but SuperserverProhibited is armed-only, so it runs on the throwaway only. The longest are NamespaceInterop 118.3 s, RoutineAppMembers 117.3 s and SqlColumnPrivilegeWrite 84.6 s.
- Already guarded (9): `WebAppRolesRead`, `EcpDataServerWrite`, `MftConnectionWrite`, `ProviderSslCallers`, `ProviderSslNamed`, `RestServiceGate`, `RoutineAppGrant` (Story 18.47), `ProviderSslCallTime` (:38-45, `If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 Quit $$$OK`), `ScreenAccessTurn`. Safe without one: teardowns touching only probe-named or process-private state (`Scope.Clear`, `InteropLookupFixture.Clear`, `GovernanceFixture.PutBack`, probe users, roles and applications).
- The flag sibling: `PreparedPolicyTaken` per test in `AnalyticsCubeActions` :42, :99-104, and `InteropResendCase` :44.
- `Test/AuthOptionsWrite.cls` (14.8 s) has a teardown of only a `^||` kill plus `Restore` (:83), so it is the representative.

### Batch 4: AD-10 arms (DW-2431, DW-2432)

- `src/OcuPilot/Kernel/Proposal/Prohibited.cls`:
  - `EncryptionStartup` (:3133) runs the journal arm only inside `If tMode = "Interactive"`. The journal arm is `SetsJournalEncryption` (:3205), `LeavesInteractiveJournal` (:3216) and `StartupJournalRefused` (:3227). `LeavesKmipRequired` (:3181) reads only `STARTUPREQUIREDFLAGS` and the three databases on disk. `LeavesModeRequired` is the mode-parameterised sibling. Reasons: `STARTUPJOURNALREASON` (:563), `STARTUPKMIPREASON` (:573).
  - `GrantsPrivilegeByEffect` (:4713), resource arm: a grant only when `ResourceGrantsAdministrativePrivilege(pId)` and `AddsPublicLetter`. DW-2425's arm, from the application side: `WidensPrivilegedReach` (:6138), then `RepointsToPublicResource` (:6147), `ResourcePublicUse` (:6159; a failed read counts) and `ApplicationRolesEscalate` (:6111). Nothing looks up the applications a resource guards.
  - Probe: `WebApp.App LIST` gives 46 rows with `Enabled`, `Type` and `Resource` but no `MatchRoles`; `Security.PrivilegedRoutine LIST` gives 3 rows, each with `Enabled` false. A single `GET` carries `Enabled`, `Resource` and `MatchRoles`.
- Tests: `EncryptionStartupWrite` (7.1 s) `TestKmipIsRefusedWhileADatabaseNeedsItsKeyOnBothCallers` (:388) and `TestInteractiveIsRefusedWhileTheJournalNeedsItsKeyOnBothCallers` (:352); `EncryptionStartupDescriptor` (2.5 s) :149, :218. DW-2425's pins: `WebAppWeakening` (24.7 s) `TestEnablingAndAPublicResourceAreGrantsWhileAPrivilegedRoleIsGranted` (:243); `RoutineAppGrant` (2 s) :213. The resource side: `ResourceUpdate` (1.9 s) :169; `ProhibitedByEffect` (2.8 s); `Prohibited` (6.2 s). `ProhibitedFixture`'s `PortClass` override (:29) fakes a failed read.
- Strings: `privilegedGrantEffect` (`ui/src/app/core/strings.ts` :1715, EXPERIENCE.md :403); `encryptionStartupKmipRefusal` (:6107), pinned at `ui/tools/self-protection.test.mjs` :311.
- Task 0 reference: Story 18.48's M3 and M2b (`spec-18-48-epic-18-burn-down-part-2.md` :61-75, :203-215). M2 (an empty startup key list) drew #1231. M2b (a KMIP server configured for startup at an unreachable host) was accepted, and its start read `exited unhealthy 3` by +184 s. Do not run or copy 18.48's scripts.

### Batch 5: removal rows (DW-2525)

- `src/OcuPilot/Screen/Tool/Write.cls` `REMOVALROWS` (:560), `RemovalRows(pFresh, pSkipUnassigned = 0)` (:571; doc :562-570).
- 16 `StateDiff` bodies (20 classes) repeat its loop with the same `Mint.Display`, each after a precondition that makes `pFresh` an object (`scratchpad/e23u/23-10/plan/e-tools/bodies.txt`):
  - Over `..FingerprintSubject()`, no skip (11): AuditUserEventDelete, LdapDelete, OAuthClientDelete, OAuthServerClientDelete, OAuthServerDescriptionDelete, ResourceDelete, RoleDelete, SslDelete, TaskDelete, UserDelete, WebAppDelete.
  - Over `..ReadAnswers()`, with the unassigned skip (4): DocDbAppDelete (RoutineAppDelete inherits it), SuperserverDelete, WalletSecretDelete, WebAppPctAccessDelete.
  - Over `..ReadAnswers()`, no skip (1): MappingDelete (abstract; Global, Routine and Package subclasses).
- Readers: `ResourceDelete` 2.5 s, `RoleDelete` 1.2, `TaskScheduleActions` 0.7, `WalletSecretDelete` 2.8, `DocDbAppDescriptor` 1.0, `RoutineAppDescriptor` 2.2, `OAuthServerDelete` 7.8. A grep found no reader for the other ten bodies; that is a failed lookup, not proof that none exists.
- Other `"removed"` shapes, not examined: ErrorDelete, LockRemove, MftConnectionRevoke, OAuthAuthorizationServerDelete, OAuthResourceServerDelete, UserTokenRevoke, ExplorerDelete, and four key tools' `MergeUpdate`.

### Batch 6: journal order (DW-1979)

- `src/OcuPilot/Screen/Descriptor/JournalRecordList.cls`: default sort Address ascending; criterion `order` 0 or 1 (the vendor's `reverse`), default 0.
- `ui/src/app/core/screen-read.ts` `applyView` (:108) re-sorts every read by the store's sort and direction, or the declared default.
- `ui/src/app/core/screen-store.ts` `setSort` (:482) and `setDirection` (:492) call `rememberView()` (:576), which saves the person's view (AD-50). Its only caller is `ui/src/app/shell/command-bar.ts` `onChooseDirection` (:1031).
- `ui/src/app/areas/os-management/journal-records.page.ts` keeps the order in its search state (:121); every search goes through `open()` (:427). Its spec, `journal-records.page.spec.ts`, renders rows. "Oldest first" and "Newest first" already exist (`strings.ts` :5290, :5292).

## Tasks & Acceptance

**Execution:**

- One implement pass per batch leaves the tree for one commit: `fix(23.10): batch <n> - <area>`.
- Each task names its pinning test; its `mutation:` line goes under Verification with the observed run.
- In the same pass, update every test that asserts a shared surface's old shape (Verification › Shared surfaces).
- The lead writes the ledger trailers once the batch's commit is green.
- **Pass order:** batches 1 to 3. **Split (lead ruling at the spec gate, per Design Notes › Size):** batches 4 to 6 (DW-2431, DW-2432, DW-2525, DW-1979) moved to Story 23.13, which is planned on its own and may reuse this spec's Code Map, Tasks and Design Notes for them; they are not part of this story and stay unchecked here. The lead opens one pass at a time; a pass works only the items the lead names and leaves every other item unchecked.

### Batch 1: CI flakes

- [ ] **DW-2513.** `ui/browser/protocol-retry.mjs`: add `isNavigationTimeout(error)` and `relaunchOnce(open, relaunch)`. On a navigation timeout, `relaunchOnce` closes the browser, launches a new one through `relaunch`, and retries `open` once; a second timeout propagates.
  - `data-table-columns.browser-spec.mjs`: hold `browser` so the relaunch can replace it; `openHarness` closes its context on any throw and opens through `relaunchOnce`.
  - Pin in `ui/tools/protocol-retry.test.mjs`, with a fake launcher whose browser 1 `goto` always times out and whose browser 2 resolves: `relaunchOnce` answers browser 2's page and closed browser 1. Red before (the helper does not exist).
  - A wedged Chrome cannot be imposed locally (Design Notes).
- [ ] **DW-2522.** `analytics-mdx.browser-spec.mjs`: add `answered(page)`. It waits until `section.ocu-mdx-query` has `aria-busy="false"` and the status line is non-empty and no longer reads `STRINGS.explorerSqlBackgroundRunning`.
  - The bound is one constant equal to `(MDXSECONDS + MDXSETTLESECONDS) * 1000` plus 15 s, its comment naming the two `AnalyticsPort` parameters. A timeout names the status line, the error text and the banner.
  - Use it at the six answer waits (:258, :285, :389, :416, :440, :495), then assert the grid, so an error answer fails by name. Raise those tests' own timeouts above the bound.
  - Condition and pin: request interception holds the first answering `GET .../analytics/mdx/background/<id>` for 35 s. It is red at :258 before the fix and green after. Record it as the mutation; it is not kept.
- [ ] **DW-2524 (closes DW-2493).** Hoist `waitForReplies` into `ui/browser/panel-spec.mjs` as an add-only export: the reply count is reached and the Send label reads `STRINGS.actionSend`.
  - `panel-collapse` and `transcript-follow` import it in place of their copies.
  - Context-chip test 7 waits on it after each turn. Before the second Send it polls `slotOwner(config)` until empty, never `requireFreeSlot`. The wait at :535 becomes a `namedWaitForFunction` whose diagnosis names the Send label, the lock banner, the draft and the reply count.
  - Pin, kept: turn 1 is scripted `TurnProvider.ScriptStream(tag, 0, <'first'>, 4)`, so 'first' is drawn while the turn still runs. It is red at :535 before the fix, every run (inference until observed; record it), and green after.
- [ ] **DW-2517.** `src/OcuPilot/Test/JournalRecords.cls`: the second page of `TestTheToolInReverseOrderKeepsTheNewestRowsUnderTheContextCap` sends `maxRows` 10 (`tArgs.%Set("maxRows", 10, "number")` before :230). It then keeps records 20..11, and its extra read finds record 10 straight away. Its assertions are unchanged; one doc clause says why.
  - Condition, at most three calls, on `ocupilot-ci`, in a temporary helper class that is removed afterwards: switch the journal file (`JournalProbe.SwitchFile()`), then journal sets and kills to a scratch global until a reverse non-matching `%SYS.Journal.Record:List` takes over 30 s.
  - Then run `JournalRecords` alone: red at +14 before the fix (`PORT.TIMEOUT`), green after. Mutation: `maxRows` back to 20.
  - If the condition cannot be built in three calls, record why. The fix then stands on the structural reading, since the second page no longer scans past this run's records.

### Batch 2: request bodies (DW-2417)

- [ ] `src/OcuPilot/Kernel/Utils.cls`: add `OversizedMember(pValue) As %String` beside `ReadRequestBody`. It walks objects and arrays with three-argument `%GetNext`, inside a `Try`.
  - It answers the top-level key of the first value the instance cannot hold: a string that came back as a stream, or a number whose untyped read raises (decided by attempting the read, never by `$IsValidNum`).
  - It answers `*` when the walk itself raises (an oversized key, or very deep nesting), and `""` when every value can be held.
- [ ] `ReadRequestBody` gains a trailing `Output pField`. After a successful parse it calls `OversizedMember`; on a hit it answers an error at stage `parse`, with `pField` set. The doc states the new outcome.
- [ ] `src/OcuPilot/Api/Error.cls`: add `RenderBodyRefusal(pField)`. With a field it answers 400 `PORT.FIELD.SHAPE` with `detail.violations[{field, code: "PORT.FIELD.SHAPE", reason}]`, the reason being that code's existing published sentence (AD-39); without one it answers today's `AGENT.BADBODY`.
- [ ] Every Area `Body()` wrapper gains `, Output pField`, and each `If '..Body(` branch renders through `RenderBodyRefusal`. Do the same for each handler that calls `ReadRequestBody` directly and answers a bad body.
  - Where a handler already answers an oversized value with its own field refusal (`RestService/Save`), its wire answer stays as it is, and `RestServiceSave` stays green unchanged.
  - Api routes keep their own bad-body answers.
  - `Area/Interop/ItemSave.cls`: edit it only if Epic 20's diff still omits it; otherwise leave it, since it answers 400 `AGENT.BADBODY` through the guard, and record the residual under Verification.
- [ ] `src/OcuPilot/Screen/Tool/Registry.cls` `ValidateArguments`: before type checks, an argument object for which `OversizedMember` answers non-empty gets the same `pProblem` and error status a wrong-typed argument gets, naming the key.
- [ ] **Pins**, red before:
  - `Test/Utils.cls`: legs for `1e400`, nested `[1, -1e400]`, a 4,000,000-character value and a 4,000,000-character key (each answers its key or `*`), and pass legs for `1e308` and a 1,000,000-character string. Mutations: remove the guard call (error legs red); judge numbers by `$IsValidNum` (the `1e308` leg red).
  - `Test/PctAccessSaveWire.cls`: a raw body with `"Extra":1e400` answers 400 `PORT.FIELD.SHAPE` on `Extra`, and nothing is written; red today with a 500.
  - `Test/ToolDispatch.cls`: a tool call with an argument holding `1e400` answers the tool-arguments refusal.
- [ ] **New-site catch.** New `ui/tools/request-body.test.mjs`: it fails if `%request.Content` or `GetMimeData(` appears in non-test `src/OcuPilot` outside `Kernel/Utils.cls`. Prove it by adding such a read to one Area file and watching it go red.

### Batch 3: test teardowns (DW-2426)

- [ ] The 46 policy-restore edit sites (Code Map › The 51, less the four below and RoutineAppGate) each gain `Property PreparedPolicyTaken As %Boolean [ InitialExpression = 0 ];`. `Set ..PreparedPolicyTaken = 1` goes right after the snapshot is merged into `..PreparedPolicy`. The first line of `OnAfterAllTests` is `If '..PreparedPolicyTaken Quit $$$OK`. Anything that teardown undoes before its restore is guarded by the flag of the setup step that made it.
- [ ] `EgressSettingsWire`, `AuditEvent`, `AuditMarker`: first line of `OnAfterAllTests` is ProviderSslCallTime's arming line over their own variable(s). `SuperserverProhibited` gets the flag.
- [ ] **Pin**, new `src/OcuPilot/Test/TeardownGuard.cls`, which is unarmed and safe on any instance:
  - **The representative.** Around each test, `GovernanceFixture.SetAside()` and `PutBack()`. `Apply` one policy row, then call `##class(OcuPilot.Test.AuthOptionsWrite).%New("").OnAfterAllTests()` without its setup, and assert `GovernanceFixture.Matches` the seeded row. It is red at head. Mutation: drop AuthOptionsWrite's guard line.
  - **New-site catch.** Read `%Dictionary.CompiledMethod` for every `OcuPilot.Test` test case whose `OnAfterAllTests` calls `GovernanceFixture).Restore(`, `Egress).Delete` or `Installer).Install(`, and require a guard as the first executable line, naming each class that has none. The derived count is asserted `> 0`, never a literal. Red at head, naming every unguarded class (the 51 expected; a different set is recorded and reconciled against Code Map). Mutation: drop one class's guard.

### Batch 4: AD-10 arms (DW-2431, DW-2432)

- [ ] **Task 0 (DW-2431), on `ocupilot-ci` after `LOAD-OK`, in the implement stage's own probe class (removed afterwards; nothing from 18.48's folder is run or copied).**
  1. Read S0: start mode None, no active keys, all four flags off, no KMIP server.
  2. Through `EncryptionPort` with a path seam rooted at `/durable/t0-2310/`: create key file F1 with K1, list it, then `ActivateDB`. M3 measured that this sets Interactive.
  3. `Settings PUT {"DBEncJournal": true}`.
  4. In `%SYS`, through the vendor classes: a TLS configuration and a KMIP server at 192.0.2.1:5696, timeout 10, `DBEncStartKeyList` = K1's id.
  5. `PUT {"DBEncStartMode": "KMIP", "DBEncStartKMIPServer": <it>}`. Record each answer and code.
  6. Record: start mode, `DBEncJournal`, `DBEncStartRequired`, `OKNoDBEncKeyAtStartup`, the three databases' `EncryptedDB`, and the `messages.log` line count.
  7. Check that `docker ps --filter name=^ocupilot-ci$` shows only 1975->1972 and 52776->52773.
  8. Only if the lead's batch-4 dispatch grants it: `docker restart -t 120 ocupilot-ci`, then poll health for 10 minutes in foreground steps under 170 s, and read `messages.log` for KMIP and key-activation failures. Without the grant, HALT `blocked: Task 0 ready for restart`.
  9. After step 8, HALT `blocked: Task 0 complete; throwaway rebuild needed: <state>`. The lead rebuilds and re-dispatches at the next item.
  - **Decision rule.**
    - The start does not finish: widen (the next item), once escalation 1 is answered.
    - A vendor refusal at step 4 or 5, or a start that finishes: keep the arm and record the evidence.
    - Anything else (a half-applied write, a refusal that moved a fact): an `intent gap` HALT.
- [ ] **DW-2431, only if Task 0 widens.**
  - `Prohibited.cls`: turn `LeavesInteractiveJournal` into `LeavesModeJournal(pMode, ...)` as `LeavesModeRequired` is. `EncryptionStartup` runs the journal arm for Interactive or KMIP, and KMIP refuses with the code and sentence escalation 1 settles, before any write, from either caller.
  - Add `Codes()`/`ReasonFor`, the `strings.ts` key, a `self-protection.test.mjs` pair and the EXPERIENCE.md row as the answer says.
  - Pin: new `EncryptionStartupWrite` legs, KMIP with `DBEncJournal` on, on both callers. Red before. Mutation: drop KMIP from the widened branch.
- [ ] **DW-2432.** `Prohibited.cls`:
  - Add `AddsPublicUse` (the payload adds `U` to the public permission).
  - Add `GuardsPrivilegedApplication(pName, .pGrants)`. It lists web and privileged routine applications through `PortClass()` as the caller, keeps those whose `Resource` equals the resource without regard to case, and reads each with a `GET` (for `MatchRoles` and a routine application's real `Enabled`). It answers 1 when an enabled one's roles escalate (`ApplicationRolesEscalate`); a failed list or read answers 1.
  - The resource arm of `GrantsPrivilegeByEffect` becomes: a letter is added, and either the resource is privileged by name or `AddsPublicUse` and `GuardsPrivilegedApplication` hold. The lookup runs only when `U` is added.
  - Treatment is `GRANT.PRIVILEGED` at the destructive treatment, with the existing `privilegedGrantEffect` line; no new string.
  - Pins, red before, in `WebAppWeakening` (a probe application granting `%All` that is enabled, over a probe resource with public `""`):
    - A resource update adding `U` mints `GRANT.PRIVILEGED`.
    - Adding only `R`, a disabled application, an application granting only `%DB_HSCUSTOM`, and a resource guarding nothing each stay ordinary.
    - The routine-application twin goes in `RoutineAppGrant`. A failed lookup counts, through `ProhibitedFixture`'s `PortClass`.
  - Mutations: drop the new clause; answer a failed read as 0; read `Enabled` from a routine application's list row.

### Batch 5: removal rows (DW-2525)

- [ ] `Screen/Tool/Write.cls` `RemovalRows` gains a trailing `pNames = ""`: when non-empty, the rows follow those names in that order, else `REMOVALROWS`. It accepts the form `FingerprintSubject()` and `ReadAnswers()` return; check which before writing. The doc states the contract.
- [ ] The 16 bodies keep their preconditions, messages and `Try`, and set `pRows = ..RemovalRows(pFresh, <0, or 1 for the four with the skip>, ..FingerprintSubject())` (or `..ReadAnswers()`).
- [ ] **New-site catch**, new `src/OcuPilot/Test/RemovalRowsSweep.cls`. For every `OcuPilot.Screen.Tool` class's `StateDiff` in `%Dictionary.MethodDefinition` that sets `"removed"`, it asserts the body calls `RemovalRows`, with an allow-list naming each other shape (Code Map). Red before, since it names the 16. If one of the other shapes is the same loop, it moves onto `RemovalRows` in this pass and stays off the allow-list.
- [ ] **Pins.** The lift is behavior-preserving, so it is pinned by equal per-class totals on the seven readers before and after, plus Story 23.9's mutation (drop `removed` in `RemovalRows`), which reddens each reader.

### Batch 6: journal order (DW-1979)

- [ ] `ui/src/app/areas/os-management/journal-records.page.ts` `open()`: before the read, if the sort in force is the declared Address default, call the store's `setDirection` with desc for order 1 and asc for order 0, only when it differs.
- [ ] **Pin** in `journal-records.page.spec.ts`: rows at Addresses 300, 200, 100. Order 1 draws 300, 200, 100 and leaves the store's direction desc; order 0 draws 100, 200, 300. Red before. Mutation: remove the call, or map order 1 to asc.
- [ ] `npm run build`; record the journal records chunk and the initial total against the 2500 kB warning.

**Acceptance Criteria:**

- **Dispositions.** Given the ten entries, when the story completes, then each is closed as Design Notes › Dispositions says, with its batch commit, and any evidence correction goes in its note.
- **Red first.** Given each fix above, when its pinning test runs before the fix, then it is red, and after the fix green. Two show the defect another way, each recorded under Verification: DW-2525's behavior-preserving lift (equal totals plus a reddening mutation), and DW-2513's wedged browser, shown through a fake launcher.
- **Flakes, under their condition.** Given each flake's condition (a held MDX answer, a paced first stream, a long journal, a launcher whose first browser never navigates), when its test runs with the fix, then it is green. And given the batch-1 commit, when the four files run on `ocupilot-ci` one at a time, then each passes.
- **Sweeps.** Given each sweep, when its batch lands, then its representative test reddened before the fix, and its new-site check fails on a site written the old way. That check is `request-body.test.mjs` with `Test.Utils` for DW-2417, and `TeardownGuard`'s dictionary test for DW-2426.
- **Field refusal at the surface.** Given an oversized value in a body sent over HTTP to a guarded Area route, when it is posted on `ocupilot-ci`, then the response is 400 `PORT.FIELD.SHAPE` naming the field, never 500.
- **No shared state lost.** Given an unarmed or refused setup, when any of the 51 classes' `OnAfterAllTests` runs, then no policy, egress or install state changes.
- **Integration (Rule 1).** Given `Kernel.Utils.OversizedMember`, when the Area routes and `ValidateArguments` read bodies and tool arguments through it, then an oversized value answers the field refusal over HTTP (`PctAccessSaveWire`) and the tool-arguments refusal in a turn (`ToolDispatch`). And given `Write.RemovalRows`' names argument, when the 16 deletes mint their proposals, then each card's removal rows equal today's, as observed by the seven readers.
- **Batches.** Given the six batches, when each lands, then it is its own commit with CI green on its own head.

## Spec Change Log

## Review Triage Log

## Design Notes

**Dispositions** (lead writes them through `ledger.sh` after each green batch):

| Entry | Batch | Disposition |
|---|---|---|
| DW-2513 | 1 | `resolved-by` its commit |
| DW-2517 | 1 | `resolved-by` its commit |
| DW-2522 | 1 | `resolved-by` its commit (DW-2523, already dropped as its duplicate) |
| DW-2524 | 1 | `resolved-by` its commit. DW-2493 is already `dropped` on feature as its duplicate (`48ce6487c`), so no second trailer. |
| DW-2417 | 2 | `resolved-by`. The note corrects the evidence: 141 caller sites in 79 files, not 109 in 54, closed by one guard rather than per-loop rewrites. |
| DW-2426 | 3 | `resolved-by`. The note: 51 classes, the 48 plus `AuditEvent`, `AuditMarker` and `SuperserverProhibited`, guarded by a setup flag. |
| DW-2431 | 4 | Widened: `resolved-by`. Kept: `wontfix-accepted`, `reopen_if=a KMIP start with journal encryption on and none of the three databases encrypted does not finish`, citing Task 0. |
| DW-2432 | 4 | `resolved-by` |
| DW-2525 | 5 | `resolved-by` |
| DW-1979 | 6 | `resolved-by` |

**Governing ADs:** AD-10 (DW-2431, DW-2432); AD-12 and AD-39 (DW-2417: one envelope, `detail.violations[{field, code, reason}]`); AD-55 (a Save resolves through the tool, so DW-2432's treatment covers both callers); AD-41 (DW-2524: the single turn slot); AD-26 and AD-36 (DW-2517: the async bound and the bounded read); AD-65 (DW-2522: the MDX bounds); AD-19 and AD-50 (DW-1979: store state, the remembered view); AD-3 and AD-51 (DW-2525: the diff a delete's card shows). No AC contradicts an AD's Rule.

**Siblings (Rule 31):**

- `relaunchOnce` extends `protocol-retry.mjs`'s `retryOnce`.
- `waitForReplies` is hoisted from two specs into `panel-spec.mjs`.
- `OversizedMember` sits beside `ReadRequestBody`; `RenderBodyRefusal` reuses `PORT.FIELD.SHAPE`.
- `PreparedPolicyTaken` is `AnalyticsCubeActions`' flag. The arming line is copied from `ProviderSslCallTime`, because an arming guard cannot fail in CI, where every variable is armed; the flag can, and it also covers the three exits that are not arming refusals.
- `LeavesModeJournal` follows `LeavesModeRequired`; `GuardsPrivilegedApplication` reuses DW-2425's `ApplicationRolesEscalate`, `EnabledOn` and `ReadMember`.
- `RemovalRows` takes a names argument rather than reading `FingerprintSubject()`, which would tie `Write` to two parameters.
- DW-1979 calls the store's existing `setDirection`, as the command bar does.

**Integration ACs and linkage (Rules 1, 2):**

- `Kernel.Utils.OversizedMember` and the `ReadRequestBody` field output. Consumed-by: this story's Area handlers and `Screen.Tool.Registry.ValidateArguments`; every later route that reads a body.
- `Api.Error.RenderBodyRefusal`. Consumed-by: the Area `Body()` callers.
- `Write.RemovalRows(pFresh, pSkip, pNames)`. Consumed-by: the 16 delete bodies.
- `relaunchOnce` and `panel-spec.mjs` `waitForReplies`. Consumed-by: data-table-columns; context-chip, panel-collapse and transcript-follow.
- No shared test-teardown helper is introduced: each guard is one line on its own class.
- Consumes: none.

**Decided in-stage:**

1. DW-2417 is fixed at the one body reader, not per loop. It closes all 141 caller sites and the 251 untyped reads, including those in contended files. The refusal's `field` is the top-level key; `*` means an oversized key or very deep nesting. A tool argument gets the existing tool-arguments refusal.
2. DW-2426 uses a setup flag, not the trailer's arming line (see Siblings), and takes in the three classes beyond the ledger's 48. That stays within the entry's stated intent: a test run never deletes shared state it did not set up.
3. DW-2517 is fixed in the test, not the port: the 30 s bound is product behavior (Never). The product edge it exposed is under `deferred:`.
4. DW-1979 steers the remembered direction through `setDirection`. That writes the same preference row the command bar's control writes, in the same format. A person who picks desc under Oldest first is set back to asc at the next search.
5. DW-2432's treatment is DW-2425's (orchestrator ruling 2026-10-14), with the existing `privilegedGrantEffect` sentence on the agent's card.
6. DW-2522's answer wait is bounded by the product's own MDX bound, not a longer arbitrary timeout. No pre-warm, which would hide the cold first query.

**Escalations for the lead's spec gate:**

1. **Wording needed (DW-2431, only if Task 0 widens):** the KMIP-and-journal refusal.
   - The recommendation is a new code `PROHIBITED.STARTUPKMIPJOURNAL`, its reason, a `strings.ts` key and an EXPERIENCE.md row. Proposed text: "Journal encryption is on, or a journal file the instance still needs is encrypted, and OcuPilot cannot check that the KMIP server is reachable and holds its key, so a start that cannot activate it does not finish. Keep the current start mode, or make this change on the classic Database Encryption page."
   - The alternative, rewriting `STARTUPKMIPREASON`, changes a published string.
   - Both are veto-window items: a posture stricter than the classic portal, and an AD-10 amendment to its KMIP bullet (Rule 20, lead).
2. **DW-2432 posture and spine.** The privileged-grant treatment for this edit is stricter than the classic portal, which asks for no extra confirmation: a veto-window item, already decided by the orchestrator. Proposed AD-10 text after DW-2425's sentence: "so is adding public `U` to a resource that an enabled web or privileged routine application uses as its `Resource` while its roles grant a privileged role (read at the write; a failed read counts) (DW-2432)."
3. **Wording needed (optional, DW-2432):** a person's Save on the Resources editor shows its field line only for a privileged resource name (`Area/Permissions/ResourceRules.cls` :202, :239), so this case would show none at the field. DW-2425's web-application field is not known to show one either (inference). This plan keeps parity with DW-2425 (no field line). If the lead wants one, proposed text: "Every user may now use this resource, and an enabled application it guards runs with %All or an administrative privilege."
4. **Task 0's restart.** One `docker restart -t 120 ocupilot-ci`, which the common block reserves; the lead grants it at batch 4 or runs the step itself (as at Story 18.48). A rebuild follows either way, because the encryption state stays in the volume (inference).

**Contended** (Epic 20 at `3db990a90`; re-check before each batch with `git -C /Users/jbrandt/git/OcuPilot/.worktrees/epic-20 diff --stat origin/feature/OCU-1_ocupilot-mvp...HEAD` and `status -s`):

- Contended: `src/OcuPilot/Kernel/Proposal/Prohibited.cls`. It is not changed yet, but Stories 20.26, 20.40 and 20.41 plan it. Batch 4's edits are not add-only, so land batch 4 before 20.26's implement, or after those stories merge, with a Rule 11 ask (as Story 18.48 made).
- Contended: `src/OcuPilot/Area/Interop/ItemSave.cls`. Planned by 20.26 and 20.40. Batch 2's task rule applies.
- No other file this plan edits is changed or planned by Epic 20. `ui/tools/ci.test.mjs` (20.36) is avoided on purpose. `strings.ts` (20.25, 20.26, 20.36, 20.40) takes an add-only key only if escalation 1 asks for one.

**Release-upgrade triggers:** none. The plan touches no `Kernel/State`, `Install`, `module.xml`, compose or start-script file, and adds no `Kernel/Governance/Baseline.cls` key.

**New-site catches:**

- DW-2417: `request-body.test.mjs` pins the one reader, so a new two-argument loop after it is harmless.
- DW-2426: `TeardownGuard`'s dictionary test.
- DW-2525: `RemovalRowsSweep`.
- DW-2517: none can catch a new site. The failure exists only under a long journal, and the test reads what it wrote.

**Size.** Ten entries in six batches. The sweeps are about 50 files each, and each still fits one implement pass (about 330 and 300 lines). The batches are independent.

- Batch 4 carries a restart, a rebuild, an escalation and a contended file, any of which can hold the story open.
- Recommended split: 23.10 keeps batches 1-3 (its charter: the flakes and the two sweeps). A sibling, the next free number in Epic 23 (23.13, if the tracker still has none), takes batches 4-6 (DW-2431, DW-2432, DW-2525, DW-1979), with this spec's text.
- Without the split, this spec runs as written.

## Verification

**Slot A, every batch:** IRIS MCP `server: "ocupilot-slot-a"`; throwaway `ocupilot-ci` (`--dir /Users/jbrandt/.ocupilot-throwaways/ocupilot-ci`, `--project ocupilot-ci`, `--web 52776`, `--super 1975`); `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776`, `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`. Never `ocupilot`. Each command is one foreground call with `timeout: 600000`.

**Commands** (`(loop)` the story's own tests; `(once)` before the batch's commit). The full ObjectScript sweep is the lead's; the full browser suite is CI's.

- `(loop)` Load: `rsync -a --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-23/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-ci/src/`, then `$System.OBJ.LoadDir("/opt/ocupilot/src","ck-d",.e,1)` through `docker exec -i ocupilot-ci iris session iris -U HSCUSTOM`. Expected: no compile error.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one class per call, totals from `%UnitTest_Result`:
  - batch 1: `JournalRecords` (3.8 s);
  - batch 2: `Utils` 0.1, `PctAccessSaveWire` 1.5, `ToolDispatch` 4.1, `RestServiceSave` 7.9, plus each Area class whose wire test asserts a bad-body answer;
  - batch 3: `TeardownGuard`, then each of the 51 (Code Map; 51 calls, 1,269.8 s summed);
  - batch 4: `EncryptionStartupWrite` 7.1, `EncryptionStartupDescriptor` 2.5, `Prohibited` 6.2, `ProhibitedByEffect` 2.8, `WebAppWeakening` 24.7, `RoutineAppGrant` 2, `ResourceUpdate` 1.9;
  - batch 5: `RemovalRowsSweep` and the seven readers (about 18 s).
- `(loop)` Browser specs, one file per call:
  - command: `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/<file>`;
  - batch 1: `data-table-columns` 45.3 s, `analytics-mdx` 42.8, `context-chip` 140.4, `panel-collapse` 92.3, `transcript-follow` 71.5;
  - batch 6: `journal-records` 15.4.
- `(loop)` `cd ui && node --test tools/protocol-retry.test.mjs` (batch 1), `tools/request-body.test.mjs` (batch 2); `npm run test:components` (batch 6).
- `(once)` `cd ui && npm run test:tools`; `uv run scripts/check-objectscript.py`; `bash scripts/lint-docs.sh` when a doc or EXPERIENCE.md changed.
- `(once)` batch 6: `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/` before `journal-records`.

**Shared surfaces:**

- Batch 2: the bad-body answer of every Area route, for oversized values only.
- Batch 3: the test-class roster (`TeardownGuard` joins it); batch 5 adds `RemovalRowsSweep`.
- Batch 4: `Prohibited.Codes()` and `self-protection.test.mjs` if the arm widens; the `GRANT.PRIVILEGED` effect set on resource edits.
- Batch 5: the delete cards' removal rows (unchanged in value).
- Batch 6: the journal records grid order and the person's remembered view.
- Sweep `ui/browser`, `ui/tools`, the `ui/src` specs and `src/OcuPilot/Test` for each old shape; every file changed joins that batch's `(loop)` set.

**Standing criterion:** every test added or changed passes on a fresh environment, in either order (Rule 30; the lead's `fresh_check`).

**Mutation lines** (filled per batch with the observed run): one per task's pin, as each task names.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
