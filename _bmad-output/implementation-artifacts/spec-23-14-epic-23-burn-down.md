---
title: 'Story 23.14: Epic 23 burn-down'
type: 'bugfix'
created: '2026-11-13'
status: 'done'
baseline_revision: 'c92cdb4027ffe5af4adf802666504688e92797c2'
baseline_commit: 'c92cdb4027ffe5af4adf802666504688e92797c2'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-23-13-the-range-end-cleanup-part-11.md'
warnings: ['multiple-goals', 'oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** This story owns 12 ledger entries, each re-checked at `939b898a9`; all 12 still reproduce or are still unguarded (Design Notes › Dispositions). Seven are CI or local flakes. Each one's test reads before the system has settled, reads a row it did not make, or loses the bring-up port. The rest:

- a Confirm gated on the wrong namespace (DW-2253);
- test leftovers in the ledger and in USER (DW-2403, DW-2408);
- no check on stored-property order (DW-2501);
- a Journal records cold open that can overwrite the remembered view (DW-2543).

**Approach:** Six area batches, flakes first:

1. instance-test flakes;
2. browser-spec flakes;
3. CI tooling;
4. test hygiene;
5. the Explorer namespace gate;
6. Journal records.

Each batch is one implement pass and one code commit with CI green on its own head. Each fix gets a test that reddens before it, or the entry says why none can (Rule 19). Every flake is fixed in the test or the harness, never by raising a product bound.

## Boundaries & Constraints

**Always:**

- **Where to work.** `/Users/jbrandt/git/OcuPilot/.worktrees/epic-23` on `OCU-1-epic23`. Check `git rev-parse --show-toplevel` first. Every IRIS MCP call carries `server: "ocupilot-slot-a"`.
- **Where tests run.** Tests, probes and mutations run only on `ocupilot-ci` (Verification), once `docker inspect -f '{{.State.Health.Status}}' ocupilot-ci` reads `healthy`. Keep one test run in flight and wait for each to land in `%UnitTest_Result`. Never re-submit after a client-side timeout. Every command runs in the foreground with `timeout: 600000`.
- **Batches.** One implement pass per batch, scoped to the items the lead names. Before each batch, re-run the two read-only Epic 20 checks under Design Notes › Contended.
- **Locating code.** Find code by symbol; line numbers are at `939b898a9`.
- **Wire stays unchanged.** Wire codes, HTTP statuses and response bodies stay byte-identical.
- **Writing code.** Extend the sibling named under Design Notes › Siblings. Comments state the contract (Rule 14). Non-ASCII in source is `$Char(n)` or `\uXXXX`.
- **Hermetic tests.** Every test added or changed creates and removes its own state. Every test seed (an error, a header, a ledger row) is removed by the test that made it.

**Never:**

- Edits to `CLAUDE.md`, `.claude/**`, `_bmad/**`, `.github/workflows/ci.yml`, `ui/tools/ci-timings.json`, `ui/angular.json`, `ui/package.json` or the architecture spine. AD amendments belong to the lead.
- A 22nd `scripts/check-objectscript.py` rule, or a new `prebuild` checker.
- A non-add-only edit to a file Epic 20 has changed (Design Notes › Contended) before the orchestrator's ruling. Any edit to a file in the Epic 20 worktree.
- Raising a product bound, `navigationTimeoutMs`, `SETTLE_TIMEOUT_MS` or `QUIET_MS`.
- A new error code, a new on-screen string, or a stored-schema change.
- A write, load or compile on `ocupilot`. A stop, restart, recreate or `down` of any container. Any docker command against a container other than `ocupilot-ci`.
- The full browser suite (CI runs it) or the full ObjectScript sweep (the lead runs it).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| CHANGED: Explorer compile, delete or import confirmed across namespaces (DW-2253) | Minted in USER by a holder of `%DB_USER:WRITE` and not HSCUSTOM's code WRITE; confirmed with the request at `?ns=HSCUSTOM` | The gate requires USER's code WRITE, and the write lands in USER. Both callers behave the same. | Today it is refused 403, naming HSCUSTOM's pair. |
| Unchanged: no stored namespace (DW-2253) | A screen action, or a proposal minted before this change | WRITE is resolved on the request's namespace, as today | — |
| Unchanged: caller lacks the target's WRITE (DW-2253) | Minted in HSCUSTOM, confirmed at USER, without HSCUSTOM's WRITE | Refused, naming HSCUSTOM's code WRITE | — |
| CHANGED: cold open with Newest first before the account read (DW-2543) | Remembered view: filter, row limit and widths. An arrival with `order=1` before `GET /account/preferences` answers | The grid draws descending. No view write is sent before adoption. After adoption, the remembered filter, row limit and widths are kept, and the direction is `desc`. | Today the default view is posted first and replaces the remembered one. |
| Unchanged: a person's own direction choice (DW-2543) | The command bar's direction, after adoption | Remembered as today | — |
| CHANGED: throwaway bring-up with the web port briefly held (DW-2123) | Host 52776 is held when `up` starts and freed within the budget | `up` waits with backoff and succeeds. Each bind failure prints the holder line when `ss` exists. | Past the budget, it exits 1 as today, naming the port. |

</intent-contract>

## Code Map

### Batch 1: instance-test flakes (DW-2236, DW-2526)

- `src/OcuPilot/Test/BackgroundTasksLive.cls`, armed by `OCUPILOT_ALLOW_PRINCIPALS`, CI 111 s:
  - `TestTheScreensActionsResumePauseAndCancelACompact`. After a 200 Pause, :218 re-reads `Paused` with no settle.
  - `SYS.Database.BackgroundFileCompact`'s `PAUSEDISPOSITION = -1` suspends by signal and answers at once.
  - "Paused" is computed from the process state (`irissys/%SYS/BackgroundTask.cls:563-567`, :695-721). So the re-read can read Running, or Done if the work finished first.
  - :207 (after Resume, accepts Running or Done) has the same exposure (inference).
  - :210-216 hold 31babb36's ended-compact branch: a non-200 Pause answers 409 `TASK.BACKGROUND.STATE`.
  - :268, in `TestAnAdminApiCompactIsListedAndPausedThroughAsyncResult`, re-reads Paused directly too.
  - Helpers in `src/OcuPilot/Test/BackgroundSeed.cls`: `Settled(pTaskId, pFrom)` (bounded 30 s; `PausedCompact` uses it at :165, doc :179-182) and `Stall(pJob, pSeconds)` (:276, SIGSTOP/SIGCONT; the vendor's Cancel of a stopped job blocks about 18 s, doc :34-37).
- `src/OcuPilot/Test/LogHubErrors.cls`, `TestASeededErrorReadsInTheHubsForm`, armed by `OCUPILOT_ALLOW_ERROR_SEED`, CI 0.9 s:
  - :86-97 takes `tNewest` from a full `RecentErrors` read.
  - :98-100 asserts that a later `RecentErrors(1)` answers exactly that time.
  - `LogSourcePort.RecentErrors` merges every namespace (:1940) at one-second resolution (:1931).
  - Any later error in any namespace takes the row. In CI, that was the adminport `REFRESHJWKS` error.
  - The other legs match by `errorNumber` (:53, :66, :111).
  - `ErrorLogSeed.SeedInto(pNamespace, .pDay, .pNumber)` (:61) and `CountFor` (:105).

### Batch 2: browser-spec flakes (DW-2461, DW-2397, DW-2111, DW-2301)

Job logs for DW-2461 and DW-2111 are saved in `scratchpad/e23u/23-14/plan/browser/`.

**DW-2461.** `ui/browser/encryption-startup.browser-spec.mjs` (CI 23.2 s), C1 at :191-197:

- C1 waits for `[data-encryption-keys="startup"]`, clicks it, then waits for `#ocu-encryption-startup-DBEncStartMode-None`. Only C1 fails, in all three CI logs.
- On the keys page (`encryption-keys.page.ts:109-116`, :247-250), the startup link renders before the keys read answers. The "no database key" paragraph is then inserted above it, so the click can land on the paragraph (inference).
- The radios render only under `@if (heldFlag)` (`encryption-startup.page.ts:155`), after three reads succeed (`encryption-startup.store.ts:342-382`). A failed read shows an alert instead.

**DW-2397.** `ui/browser/turn.browser-spec.mjs` (CI 183.1 s), :405-411:

- The test waits for the first non-empty `.ocu-panel-message-agent-text`.
- While a reply streams, `panel.ts:563-569` renders it in `.ocu-panel-message-streamed` with the same class, until `turn.reply !== null` (:548).
- Settled signal: `waitForReplies(page, n, config, label)` (`panel-spec.mjs:315`). The Send button reads 'Send' again once the turn has ended.
- `scriptStreamReply(probe, tag, 0, reply, slices)` (`turnprobe-spec.mjs:204`) scripts a reply in slices.

**DW-2111.** `ui/browser/error-log.browser-spec.mjs` (CI 27.9 s):

- Recurred 2026-11-13: run 43371448555, attempt 1, browser shard 4/5. All five tests failed on their first `page.goto`, in `signedInAtScreen` :233 and `signedInAtScreenIntercepting` :277.
- The first failing test seeds nothing, and messages.log was silent. The spec's own browser wedged, not the instance (inference).
- The ledger's "same shape in run 36483764167" is wrong: that run timed out in `explain-screen.browser-spec.mjs:204`.
- Siblings to reuse:
  - `relaunchOnce` (`protocol-retry.mjs:116`), used by `data-table-columns.browser-spec.mjs:111-125`;
  - `trackInflightRequests` and `gotoNamingInflight` (`panel-spec.mjs:68`, :82).

**DW-2301.** `ui/browser/structural-walk.mjs`, used by `a11y-structural-invariants.browser-spec.mjs` (CI 665.3 s; 459 s locally in 23.13):

- `SETTLE_TIMEOUT_MS = 20000` (:181) and `QUIET_MS = 500` (:184) are used in `settle` (:683-697), which returns a bare boolean.
- `walkPass` records only the route string (:799-800). `reportLines` (:936) prints counts, with no per-visit time or reason.
- `passRetrier` (:825-865) retries only through `retryOnce`, which retries only on `isProtocolTimeout` (`protocol-retry.mjs:35`, :71). So "Connection closed", "Target closed", "Session closed" and "frame detached" fail `before` outright.
- Pins live in `ui/tools/structural-walk.test.mjs` (it imports `settle`, `goInApp`, `passRetrier`, `reportLines`) and `ui/tools/protocol-retry.test.mjs`.

### Batch 3: CI tooling (DW-2123, DW-2501)

**DW-2123.** `scripts/ci-throwaway.sh`:

- `BIND_ATTEMPTS=3` and `BIND_RETRY_SECONDS` (:148-155). The retry loop (:856-904) sleeps `BIND_RETRY_SECONDS * ATTEMPT`, about 8 s in all.
- The compose ports are `"$SUPER_PORT:1972"` and `"$WEB_PORT:52773"` (:236-238).
- Two CI failures had all three attempts inside 8 s:
  - run 37492247584, shard 3/5;
  - run 43290470415, shard 2/8, job 131435049788.
- `ci.yml:172-173` reserves the port before `up`. Its comment (:164-171) says that removes the race; both failures happened with the reservation in place.
- The holder is probably an earlier outbound socket whose local port is 52776 (inference; never captured).
- Pins: `ui/tools/ci.test.mjs` :2721-2880. `runThrowawayUp({fails})` stubs docker. :2796-2804 asserts `ups === 3`. :2812-2813 hold source-text regexes on the backoff. The helper deletes its directory afterwards.

**DW-2501.**

- The convention row is at `ARCHITECTURE-SPINE.md:1452`.
- There are 21 persistent classes, all in `src/OcuPilot/Kernel/State/`, and none has a source Storage section.
  - `Base` extends `%Persistent` and declares `RowVersion`. The other 20 extend `Base`.
  - None declares a Calculated, Transient or MultiDimensional property, or a many-side relationship.
  - The 21 were counted by Extends chain and match `%Dictionary.CompiledClass` on `ocupilot-slot-a`.
- There are no release tags. Releases are `origin/release/1.0.0` through `origin/release/1.0.14`.
- A prototype (scratch `harness/order.py`, evidence only; do not run it) found:
  - HEAD against `release/1.0.14`: clean;
  - `release/1.0.12` against `dd2d53f22` (Story 20.33's tree): SqlRun's `Kind` inserted at slot 4.
- The `gates` job checks out with no `fetch-depth` (`ci.yml:92`), so CI's clone is shallow and has no release refs.
- `npm run test:tools` runs every `tools/*.test.mjs` (`ui/package.json:14-15`). No test pins the prebuild list.

### Batch 4: test hygiene (DW-2403, DW-2408)

**DW-2403.** `src/OcuPilot/Test/TurnWireFixture.cls`:

- `SweepSince` :511 runs `SELECT DISTINCT TurnKey`. It returns the collated uppercase key, measured on slot A. `Ledger.GuardedDeleteForTurn` (`Kernel/State/Ledger.cls:491`) matches `%EXACT`, so it deletes nothing.
- :471 has the same bug: `DISTINCT UserName` feeds `Turn.GuardedAbandonForUser` (`Turn.cls:469`, exact match) (inference).
- `Sweep` (:417-450) and `TurnFixture.RemoveTurns` (`TurnFixture.cls:31`) delete no ledger rows, and Sweep's report does not count them.
- Ledger helpers: `Ledger.GuardedDeleteForUser` (:498) and `GuardedCountForTurn` (:515). The precedent is `LedgerWire.ClearRows` and `RowCount` (:131-143).
- `src/OcuPilot/Test/TurnNavigate.cls` (unarmed, 13.4 s):
  - `OnAfterOneTest` (:52-70) deletes turns only (:60).
  - `TestDeletingATurnRemovesItsDirective` (:548) drops its key from `PreparedKeys` (around :559).
- 25 armed classes assert `Sweep(...) = ""`. The heaviest are `TurnLong` 203.9 s and `TurnWire` 88.8 s.
- `InteropEditorSaveTurn` (21.5 s) is the only `SweepSince` user.

**DW-2408.** `ui/browser/interop-item-test.browser-spec.mjs` (CI 30.8 s):

- `after` (:171-181) runs `ProductionProbe.Settle`, `InteropTestFixture.Remove`, `ProductionProbe.Remove`, then `Gone`.
- `ProductionProbe.Remove` (:779-805) deletes only `OcuPilotProbe*` config names, and `InteropTestFixture.Remove` (:305-331) deletes headers sourced from `EnsLib.Testing.Service`. The testing process's headers and the production's log rows remain (measured by 20.30's plan).
- AC2's send (:199) is never cleared.
- Sibling: `interop-message-resend.browser-spec.mjs:229-245`. It records `ProductionProbe.HighWater()` (:617) first, then its cleanup runs `Settle`, `SweepSince(mark)` (:641), `Remove`, `Gone`, and asserts `1|0|0|1|1`. Do not widen the shared helpers.

### Batch 5: Explorer namespace gate (DW-2253)

- `src/OcuPilot/Screen/Tool/ExplorerWrite.cls`:
  - `PrivilegePairs` reads `Scope.Current()` at :106. Compile, delete and import inherit it; export, save and create override it.
  - `PortQuery` (:120-126) already writes to the payload's namespace.
  - Docs at :1-21 and :98-101.
- `ExplorerSave.CodeWritePairs(pArgs)` resolves the stored `Namespace`, else the request's. This is Story 20.20's pattern for saves and creates.
- `ExplorerMint.cls:39-41` copies the agent's arguments plus names. `ExplorerImportMint.cls:42-45` adds names and documents, and its preview uses `Scope.Current()` (:35). The input schema's `additionalProperties: false` keeps `Namespace` out of agent input.
- `ExplorerImport.ArgumentPairs` (:100-103) returns `FilePairs` only.
- At Confirm, `Operation.RequiredPairsOf` (`Kernel/Proposal/Operation.cls:505-519`, from `Confirm.cls:299`) unions the declared pairs and the argument pairs.
- Callers:
  - agent propose, at `Dispatch.cls:317`;
  - screen actions, at `ScreenAction.cls:284-302`.
  - Neither caller passes `Namespace`, so both fall back to the request's namespace.
- `FINGERPRINTSUBJECT` reads only the fresh read, so fingerprints, payload and card are unchanged.
- Tests that pin the old shape:

| Test | CI s | Armed |
|---|---|---|
| `AtelierPortWriteDenial.cls:218-246` (the save/create loop; screen-action legs :139, :159 guard continuity) | 34.3 | `PRINCIPALS` |
| `ToolEmit.cls:206-221` | 5.7 | no |
| `DeveloperFloor.cls:45,52,503-504` (`TOOLS`, `HELDWRITES`, the "fifty-six" message) | 24.1 | `PRINCIPALS` |
| `ClassicPageGate.cls:75` (`OWNPAIRS`) | 22.7 | `PRINCIPALS` |
| `ExplorerWrite` (`TestTheAgentCompilesThroughConfirm`) | 41.4 | no |

- Visible effect: `Screen/Context.cls:263-296` (`Unavailable`) and `DeveloperFloor` read declared pairs only. A principal without WRITE will see compile, delete and import offered to the agent and refused by name at dispatch, as save and create are today.

### Batch 6: Journal records (DW-2543)

- The premature write happens in this order:
  1. `journal-records.page.ts` `open()` (:439-441) calls `followOrder()` (:445-457).
  2. `followOrder()` calls `ScreenStore.setDirection` (`screen-store.ts:517-521`), which calls `rememberView()` (:602-614).
  3. `rememberView()` posts the default view (no filter, the default row limit, no widths).
- The write settles the pending read (`account-preferences.ts:484-536`), so `adoptRemembered` (:168-196) adopts the overwritten view.
- Reachable when an arrival beats the boot read (`app.ts:838`), for example when that read is slow or failed (inference).
- The page already re-runs `followOrder` after adoption when a view was restored (subscriber :389-394; `remembered()` and `restoredView()` came with 23.13).
- No other programmatic setter writes before adoption.
- Pins: `journal-records.page.spec.ts` (beside "Newest first follows an arrival…" :333; `stubAccountPreferences`, `lastRemembered`) and `ui/tools/screen-store.test.mjs`.

## Tasks & Acceptance

**Execution:**

- One implement pass per batch leaves the tree ready for one commit: `fix(23.14): batch <n> - <area>`.
- Each task names its pinning test. Its `mutation:` line goes under Verification with the observed run.
- In the same pass, update every test that asserts a shared surface's old shape (Verification › Shared surfaces).
- The lead writes the ledger trailers once the batch is green.

### Batch 1: instance-test flakes

- [x] **DW-2236.** `src/OcuPilot/Test/BackgroundTasksLive.cls`:
  - After a Pause that answers 200, call `BackgroundSeed.Settled(tTaskId, "Running")`.
    - If it settles to Paused, assert the Paused re-read and continue to Cancel.
    - If it settles to Done, take the existing ended-compact branch (Cancel answers 409 `TASK.BACKGROUND.STATE`, asserted).
    - Anything else fails, naming the state.
  - Settle after Resume at :207 (`Settled(.., "Paused")`), and before the Paused re-read at :268.
  - **Red first.** Add a temporary, uncommitted leg that calls `BackgroundSeed.Stall(job, 3)` between Resume and Pause. Measure whether Pause still answers 200. If it does, :218 reads Running at head, which is red, and the fixed test is green.
    - If the stall blocks or refuses the Pause, record that, and record "no deterministic red: the race is the vendor's checkpoint timing; the settle is the seed's established contract".
    - Mutation: drop the `Settled` call (red under the stall leg).
- [x] **DW-2526.** `src/OcuPilot/Test/LogHubErrors.cls`:
  - `Hang 1` before the second seed (:86).
  - Take the second seed's time from its own row, matched by `errorNumber`.
  - Assert that the cap-of-one read answers one row, `truncated` 1, and a time no older than that seed's.
  - Keep the stand-in in the test permanently: after the full read, `Hang 1.1` and seed one more error with `ErrorLogSeed.SeedInto("USER", ...)`, then remove it in the test's own teardown. This stand-in makes today's assertion red deterministically.
  - Mutation: make `LogSourcePort.RecentErrors`' cap keep the oldest row instead of the newest. The leg goes red, because the second seed is a second newer than the first.

### Batch 2: browser-spec flakes

- [ ] **DW-2461.** `ui/browser/encryption-startup.browser-spec.mjs` C1:
  - Before clicking, wait for `section.ocu-form-page[aria-busy="false"]` and for either `[data-encryption-keys="empty"]` or `[data-encryption-keys="keys"]`.
  - After clicking, wait for the startup path.
  - Then wait for the None radio or `[role="alert"]`, and assert which one came.
  - No deterministic red: the miss depends on layout timing (Design Notes). Mutation: drop the new path wait; a forced miss (click the paragraph instead of the link) then fails on the radio and not on the path.
- [ ] **DW-2397.** `ui/browser/turn.browser-spec.mjs` 'Markup in a reply renders as literal text':
  - Script the markup reply through `scriptStreamReply(..., 2)`, so it arrives in slices.
  - Replace the wait at :405-409 with `waitForReplies(page, 1, config, 'Send')`, plus the condition that no `.ocu-panel-message-streamed` remains.
  - Red first: the sliced reply with the old wait reads a partial text. Mutation: restore the old wait.
- [ ] **DW-2111.** `ui/browser/error-log.browser-spec.mjs`:
  - Route `signedInAtScreen` and `signedInAtScreenIntercepting` through `relaunchOnce`, with an open that closes its context on error and a relaunch that reassigns the module's `browser`, as `data-table-columns.browser-spec.mjs:111-125` does.
  - Navigate with `trackInflightRequests` and `gotoNamingInflight`.
  - No real-browser red is possible. The helper's wedged-browser pin is `protocol-retry.test.mjs:256-277`.
  - Mutation: pass the shared browser straight to the open. A new `ui/tools` source-text case asserts that both helpers go through `relaunchOnce`, and it reddens.
- [ ] **DW-2301.** `ui/browser/structural-walk.mjs` and `ui/browser/protocol-retry.mjs`. Waits for escalation 2.
  - `settle` answers `{settled, ms, why}`, where `why` names the in-flight URLs, the busy element or the font status.
  - `walkPass` records each visit's settle time. `reportLines` prints the five slowest visits and every unsettled visit with its `why`.
  - Add an `isConnectionLoss` predicate (`/Connection closed|Target closed|Session closed|frame (got )?detached/`) in `protocol-retry.mjs`.
  - `retryOnce` takes an optional predicate, defaulting to `isProtocolTimeout`. `passRetrier` passes `isProtocolTimeout || isConnectionLoss` only when `relaunch` is given, so other users keep today's behavior.
  - Constants unchanged.
  - Pins in `ui/tools/structural-walk.test.mjs`, with fake pages:
    - a request that never ends reports the visit unsettled, with its URL in `why`;
    - a pass that throws "Connection closed" with a relaunch is rerun on browser 2;
    - without a relaunch, it throws as today.
    - All are red before.
  - Mutations: drop the predicate; drop `why`.

### Batch 3: CI tooling

- [ ] **DW-2123.** `scripts/ci-throwaway.sh` (escalations 1 and 5):
  - Replace the three attempts with a time budget, `OCUPILOT_BIND_WAIT_SECONDS` (default 120). Back off 2, 4, 8, 16, then 30 s, and still retry only bind failures.
  - On each bind failure, print `ss -Htan "( sport = :$WEB_PORT )"` when `command -v ss` succeeds.
  - Publish both ports on `127.0.0.1:` (:236-238).
  - Update the script's doc lines.
  - Pins in `ui/tools/ci.test.mjs`:
    - `runThrowawayUp({fails: 4})` exits 0 (red before);
    - the `ups === 3` case becomes a budget case with a small override;
    - the backoff regexes follow the new form;
    - a new case keeps the written `compose.yml` and asserts both `127.0.0.1:` port lines.
  - Mutations: restore a 3-attempt cap; drop the `127.0.0.1:` prefix.
- [ ] **DW-2501.** New `ui/tools/stored-order.mjs` (a pure `compareStoredOrder(baseline, current)` plus a git reader) and `ui/tools/stored-order.test.mjs`:
  - **Scope.** Every `src/OcuPilot/**/*.cls` that is persistent by its in-tree Extends chain (to `%Persistent`, `Ens.Request` or `Ens.Response`) and has no `Storage` section.
  - **Stored members.** `Property` and `Relationship` declarations, excluding Calculated, Transient, MultiDimensional and many- or children-side relationships.
  - **Rule.** Each class's own stored members at the baseline, in declaration order, must be a prefix of its current list. A removed class fails. A changed primary superclass fails. A class absent at the baseline passes.
  - **Exceptions.** An allow-list in the tool, empty to begin with, takes one entry per class with a reason.
  - **Baseline.** The highest `refs/remotes/origin/release/*` by version (escalation 6).
  - **Shallow clone.** In a shallow clone, the git leg calls `t.skip` with a printed reason. In a full clone with no release ref, it fails.
  - Fixture legs run everywhere:
    - an append passes;
    - an insert, a rename, a removal and a changed superclass each fail, naming the class and slot;
    - Calculated and Transient members are ignored.
  - Git legs (local only):
    - HEAD against the baseline is clean;
    - `origin/release/1.0.12` against `dd2d53f22` reports SqlRun. This is the red-first leg: the defect only the manual upgrade check caught.
  - Mutations: compare as sets instead of as a prefix; drop the Calculated filter.

### Batch 4: test hygiene

- [ ] **DW-2403.**
  - `src/OcuPilot/Test/TurnWireFixture.cls`:
    - `SweepSince` selects `%EXACT(TurnKey)` at :511 and `%EXACT(UserName)` at :471.
    - `Sweep` calls `Ledger.GuardedDeleteForUser` for USERA and USERB, and adds `ledger rows (n)` to its report when a `%EXACT(UserName)` count is not 0.
  - `src/OcuPilot/Test/TurnNavigate.cls`:
    - Its teardown, and `TestDeletingATurnRemovesItsDirective`, call `GuardedDeleteForTurn` for each key they made.
    - The teardown asserts `GuardedCountForTurn` = 0 for each key.
  - Red first: with the count added before the delete, `ExplorerSaveTurn` and `TurnWire` fail on `Sweep(...) = ""`. A `SweepSince` leg (a USERA ledger row above the mark with no turn) reports it, and `TurnNavigate`'s count is non-zero.
  - Before relying on the new delete, check that no class calls `Sweep` mid-test while it still needs ledger rows.
  - Mutations: drop the `GuardedDeleteForUser` call; restore the bare `TurnKey` at :511.
- [ ] **DW-2408.** `ui/browser/interop-item-test.browser-spec.mjs`:
  - `before` records `ProductionProbe.HighWater()` before `Create`.
  - `after` runs `Settle`, `SweepSince(mark)`, `InteropTestFixture.Remove`, `ProductionProbe.Remove`, then `Gone`, and asserts that `HighWater()` is at the mark.
  - No ObjectScript change.
  - Red first: the `HighWater()` assertion without the sweep. Mutation: drop `SweepSince`.

### Batch 5: Explorer namespace gate (waits for escalations 3 and 4)

- [ ] **DW-2253.**
  - `src/OcuPilot/Screen/Tool/ExplorerWrite.cls`:
    - `PrivilegePairs` drops the code WRITE pair, as save and create do.
    - Add `ArgumentPairs`, returning `ExplorerSave.CodeWritePairs(pArgs)`.
    - Update the docs.
  - `ExplorerImport.ArgumentPairs` returns `CodeWritePairs(pArgs)` and then `FilePairs(pArgs)`.
  - `ExplorerMint.cls` and `ExplorerImportMint.cls` set `Namespace` = `Scope.Current()` after copying the arguments.
- [ ] Update the old-shape tests:
  - `AtelierPortWriteDenial`: move compile, delete and both imports into the save/create loop;
  - `ToolEmit`: widen the save/create branch;
  - `DeveloperFloor`: add the tools to `TOOLS` and `HELDWRITES`. Read the count from the instance, and update the count message;
  - `ClassicPageGate` `OWNPAIRS`: empty compile and import, once ruled.
- [ ] Pins, red before:
  - `ExplorerWrite.TestTheAgentCompilesThroughConfirm`:
    - after the USER dispatch, the stored arguments hold `"Namespace":"USER"`;
    - with scope HSCUSTOM, `RequiredPairsOf` holds `%DB_USER:WRITE` and not HSCUSTOM's code WRITE;
    - `ConfirmIn("HSCUSTOM")` compiles in USER.
  - In `AtelierPortWriteDenial`, `OcuP192ReadWrite` mints a compile in USER and confirms it at HSCUSTOM. Today this is 403; afterwards it is confirmed. The converse stays refused as a guard.
  - Mutations:
    - `ArgumentPairs` reads `Scope.Current()`;
    - omit `Namespace` in either mint;
    - restore WRITE in `PrivilegePairs`.

### Batch 6: Journal records

- [ ] **DW-2543.**
  - `ui/src/app/core/screen-store.ts`: `setDirection(direction, remember = true)`. It always sets the direction and notifies, and calls `rememberView()` only when `remember` is true.
  - `ui/src/app/areas/os-management/journal-records.page.ts`: `followOrder()` passes `view.store.remembered()`.
  - The `command-bar.ts` caller is unchanged.
  - Pins:
    - `journal-records.page.spec.ts`: seed a remembered view (filter `^OcuProbe`, row limit 500, `Address` width 180) while the account is unloaded, and mount with arrival `order: '1'`. Expect `desc`, and no view POST before the GET. After `account.load()`, expect the filter, row limit and width kept, the direction `desc`, and `lastRemembered` holding all three. Red before.
    - `screen-store.test.mjs`: `setDirection('desc', false)` changes the direction, notifies and posts nothing.
  - Mutations:
    - `followOrder` passes `true`;
    - the store ignores `remember`;
    - drop the subscriber's `followOrder`.

### Review Findings

#### Batch 1 (2026-11-14)

- [x] [Review][Patch] The admin API Resume re-read had no settle (med, fix-risk low) [src/OcuPilot/Test/BackgroundTasksLive.cls:TestAnAdminApiCompactIsListedAndPausedThroughAsyncResult] -- now `SettledRow(.., "Paused")`; run 33 green.
- [x] [Review][Patch] No recorded red for DW-2526's old exact-newest assertion against the stand-in (low) [Verification] -- run 31, mutation line added.
- [x] [Review][Patch] Nothing stood in for DW-2236's missing red (low) [Verification] -- forced-ended-branch mutation, run 32, mutation line added.
- [x] [Review][Patch] `LogHubErrors` header still said `^ERRORS` cannot be un-logged and named two seeds (low) [src/OcuPilot/Test/LogHubErrors.cls:1-11]
- [x] [Review][Patch] `OnAfterOneTest` discarded `DeleteByError`'s status (low) [src/OcuPilot/Test/LogHubErrors.cls:OnAfterOneTest] -- statuses folded with `$$$ADDSC` and asserted.
- [x] [Review][Patch] The Resume/Pause test doc appended a paragraph that contradicted its first (low) [src/OcuPilot/Test/BackgroundTasksLive.cls:TestTheScreensActionsResumePauseAndCancelACompact] -- rewritten as one contract.
- [x] [Review][Patch] Comments and the DW-2236 mutation line stated an unmeasured vendor cause ("next checkpoint", "Pause waits for the stopped job") as fact (low) -- comments say the effect is asynchronous; the mutation line marks `(inference)`.
- [x] [Review][Patch] `SettledRow`'s doc said "at most 30 s" though each read is an HTTP list (low) -- states 150 reads, 200 ms apart.
- [x] [Review][Patch] `SettledRow` repeats `BackgroundSeed.Settled`'s poll (low, Rule 31) -- reason: the admin API row has only a GUID and is read through the screen, while `Settled` reads the vendor task by id.
- [x] [Review][Defer] A 200 Pause that settles to Done takes the Cancel-409 branch, so a Pause with no effect on the short compact reads green in the live leg [src/OcuPilot/Test/BackgroundTasksLive.cls] -- deferred: DW-2547 `by-design` (the batch 1 task specifies the branch; `BackgroundTaskPortSeam` pins the vendor call; the least-privilege 403 leg still reddens).

Rejected (batch 1):

- `false` Spec frontmatter reads `done` with five batches open -- build-auto's per-batch machine state, which this stage must not change.
- `false` The read-back's 404 can pass a delete that never happened -- both namespaces exist, and an undeleted seed reads 200 with its row, which fails "is gone".
- `low` Code Map's "answers at once" contradicts the stall measurement; a green run lacks its run number -- fixes edit the spec; the final runs are 33 and 34.
- `low` One `DeleteByError` throw skips the later seeds; midnight inside the 2 s of hangs; a transient empty read ends `SettledRow`; an admin intermediate state -- unlikely, and each fix adds guards; each fails loudly.
- `low` The cap-of-one assertion accepts a newer row that is not the newest -- spec-bound ("no older than that seed's"); the keep-oldest mutation pins the cap.
- `low` The commit message says the stand-in keeps a later error from taking the row -- needs a history rewrite.

**Acceptance Criteria:**

- **Dispositions.** Given the 12 entries, when the story completes, then each is closed as Design Notes › Dispositions says, with its batch commit.
- **Red first.** Given each fix, when its pinning test runs before the fix, then it is red, and after the fix it is green. Where no test can force the red (DW-2461; DW-2111 in a real browser; DW-2236 if the stall measurement says so), the entry records why, and the helper-level pin or mutation stands in. All of this is recorded under Verification.
- **Flakes at the surface.** Given batches 1 and 2, when `BackgroundTasksLive`, `LogHubErrors` and the four changed spec files run on `ocupilot-ci` with the bundle redeployed, then each passes. The a11y spec also prints the per-visit settle report.
- **Gate at the surface.** Given a principal holding only USER's code WRITE, when it confirms a USER compile at `?ns=HSCUSTOM` on `ocupilot-ci`, then the class compiles in USER (`AtelierPortWriteDenial`).
- **Remembered view at the surface.** Given a remembered journal-records view, when a cold arrival with Newest first opens before the account read answers, then the view is kept (component spec).
- **No leftovers.** Given batch 4, when `ExplorerSaveTurn`, `InteropEditorSaveTurn`, `TurnNavigate` and `interop-item-test.browser-spec.mjs` finish, then the probe users hold no ledger rows, and USER's headers and log rows are back at the mark.
- **Integration (Rule 1).** Given `stored-order.mjs`, when `npm run test:tools` runs in a full clone, then it reports SqlRun for `release/1.0.12` against `dd2d53f22`, and nothing for HEAD.
- **Batches.** Given the six batches, when each lands, then it is its own commit with CI green on its own head.

## Spec Change Log

## Review Triage Log

### 2026-11-13 — Review pass

- verdicts: 5 findings — high 0, medium 0, low 3, false 2, maybe-false 0
- findings:
  - `[low]` `[reject]` DW-2526 stand-in is not pinned by an assertion — the spec fixes the cap-of-one assertion as "no older than the second seed's"; the stand-in's job is to make the old exact-newest assertion red, and the cap-keeps-oldest mutation pins the AC. Closed by-design.
  - `[low]` `[patch]` DW-2526 teardown read-back passes when the read fails, and has no mutation line — added a status assertion (200, or 404 for a day with no errors left) and demonstrated the skipped-delete mutation red (run 25).
  - `[low]` `[patch]` DW-2236 Resume and admin API settle sites have no recorded red — the DW-2236 mutation line now says neither has a deterministic red; same vendor-checkpoint cause.
  - `[false]` `[reject]` DW-2526 `Hang` sleeps are not a readiness signal — they separate two one-second-resolution timestamps, which the assertion needs; the assertion holds either way.
  - `[false]` `[reject]` Pause-200 branch final `StatusOf` read is a single read — it follows the seed's settle on the same process-state source; no defect shown.

## Design Notes

**Dispositions** (the lead writes them through `ledger.sh` after each green batch):

| Entry | Batch | Disposition |
|---|---|---|
| DW-2236 | 1 | `resolved-by`, `reopen_if=BackgroundTasksLive reds on a Pause, Resume or Cancel after the settle` |
| DW-2526 | 1 | `resolved-by` |
| DW-2461 | 2 | `resolved-by`, `reopen_if=C1 fails on the startup-path wait or names an alert` |
| DW-2397 | 2 | `resolved-by` |
| DW-2111 | 2 | `resolved-by`, `reopen_if=an error-log navigation times out after the relaunch, or gotoNamingInflight names a request`. The trailer also corrects the 2026-10-06 note: run 36483764167's timeout was explain-screen's. |
| DW-2301 | 2 | `resolved-by` (the connection-loss form), `reopen_if=the walk report names an unsettled visit` (the `why` then says which constant, if any, to change) |
| DW-2123 | 3 | `resolved-by`, `reopen_if=a bind failure outlasts the budget` (the `ss` line names the holder) |
| DW-2501 | 3 | `resolved-by` |
| DW-2403 | 4 | `resolved-by` |
| DW-2408 | 4 | `resolved-by` |
| DW-2253 | 5 | `resolved-by` |
| DW-2543 | 6 | `resolved-by` |

**Governing ADs:**

- DW-2253: AD-8 (the target namespace's code WRITE, :282), AD-40 (the gate is on the write), AD-44 (namespace is data scope), AD-53 and AD-55 (two callers).
- DW-2543: AD-19 and AD-50.
- DW-2403: AD-41 (ledger rows are bounded audit records).
- Test classes compile only on a throwaway: AD-17.
- DW-2408: AD-62.
- DW-2501: Conventions › New properties on a stored class.

No AC contradicts an AD's Rule. DW-2253 raises escalation 4.

**Siblings (Rule 31):**

- DW-2236 reuses `BackgroundSeed.Settled`.
- DW-2526 follows the other legs' `errorNumber` match.
- DW-2397 uses `waitForReplies` and `scriptStreamReply`.
- DW-2111 uses `relaunchOnce`, `trackInflightRequests` and `gotoNamingInflight`, as `data-table-columns` does.
- DW-2301 extends `settle`, `passRetrier` and `retryOnce` (with an optional predicate).
- DW-2123 extends the existing bind loop.
- DW-2501 follows the `ui/tools` checker-plus-test pattern. No sibling reads git history, and the prototype is evidence only.
- DW-2403 reuses `Ledger.GuardedDeleteForUser` and `GuardedCountForTurn`, as `LedgerWire.ClearRows` does.
- DW-2408 copies the resend spec's high-water cleanup, because the shared helpers must not widen.
- DW-2253 reuses `ExplorerSave.CodeWritePairs` (Story 20.20).
- DW-2543 extends `setDirection` with a parameter, so `command-bar.ts` is untouched.

**Integration ACs and linkage (Rules 1, 2):**

- `stored-order.mjs` — Consumed-by: `stored-order.test.mjs` under `npm run test:tools` (Integration AC). No other consumers in this story; a later prebuild wiring needs the Planner (CLAUDE.md counts the checkers).
- `setDirection(direction, remember)` — Consumed-by: `journal-records.page.ts`.
- `isConnectionLoss` — Consumed-by: `passRetrier`.
- `ExplorerWrite.ArgumentPairs` — Consumed-by: `Operation.RequiredPairsOf` (Confirm and the screen's action).
- Consumes: none.

**Decided in-stage:**

1. Every flake is fixed in its test or harness; no product bound moves.
2. DW-2526's stand-in error goes to USER, not `%SYS`, and its own teardown removes it.
3. DW-2301 keeps both constants. It adds per-visit timing and a reason, as the ledger asks, before any constant change. It does not add a second settle window, which would be a hidden timeout raise.
4. DW-2543 is fixed in the page with one additive store parameter, not by deferring every screen's write in the store. Store-wide deferral would silence the table harness's width persistence, which never loads its account.
5. DW-2403's ledger delete sits in the fixture's `Sweep`, so all 25 users get it without per-class edits.
6. Batch order belongs to the lead. Batches 1, 2 (less DW-2301), 4 and 6 need no ruling.

**Escalations for the lead's spec gate:**

1. **Contended: `scripts/ci-throwaway.sh` (DW-2123).**
   - Epic 20 changed it add-only, at :488-490 inside the compose comment roster.
   - Batch 3 edits :148-155, :236-238 and :856-904, which are separate regions but not add-only.
   - Recommended: allow. Whichever epic integrates second resolves a plain union.
2. **Contended: `ui/browser/structural-walk.mjs` (DW-2301).**
   - Epic 20 changed it add-only: a `SKIP` entry at about :122.
   - Batch 2 edits `settle` (:683-697), `walkPass` (:799), `passRetrier` (:825-865) and `reportLines` (:936).
   - Recommended: allow. If it is held, batch 2 ships without DW-2301 and DW-2301 follows in its own pass.
3. **Contended: `src/OcuPilot/Test/ClassicPageGate.cls` :75 (DW-2253).**
   - Epic 20 (Story 20.41) edited the same one-line `OWNPAIRS` parameter, adding `interop.items.changeclass`.
   - This story empties the compile and import entries.
   - Recommended: allow, with a plain union at integration.
4. **AD-8 (DW-2253).**
   - AD-8 :282 already requires WRITE "on the target namespace's routines-database resource, resolved per namespace at the call". Its last sentence names only saves and creates as argument pairs.
   - Recommended: comply under the first clause. The sentence's extension ("…and a compile's, delete's and import's (DW-2253)") is the lead's Rule 20 bookkeeping, and no Epic 20 spec relies on the narrower reading.
   - Stated effect: a principal without WRITE sees compile, delete and import offered to the agent and refused by name at dispatch, exactly as save and create since 20.20. Nothing is allowed that the port's own check refuses.
5. **Loopback publishing (DW-2123).**
   - Publishing the throwaway on `127.0.0.1` is stricter than today, but it changes how the runtime is reached.
   - IPv4 fallback for `localhost` is an inference. Only the lead's fresh-check `down`/`up` and CI can verify it, because the stage may not recreate `ocupilot-ci`.
   - Recommended: yes. If declined, the time budget alone ships.
6. **DW-2501 baseline and CI enforcement.**
   - The owner asked for "the previous release tag", but no tags exist. Recommended: the newest `origin/release/*` branch, which equals `main`.
   - CI's `gates` checkout is shallow (`ci.yml:92`), so CI skips the git leg and enforcement is local (stage and lead runs). Making CI enforce it needs `fetch-depth: 0` (or a fetch of `release/*`) in `ci.yml`, which is forbidden here.
   - Recommended: accept local enforcement now. The lead routes a one-line `ci.yml` change with its own CI evidence.
7. **`ci.yml` comment (DW-2123).** `ci.yml:164-171` says the port reservation removes the race, and both failures disprove that. Correcting it needs a `ci.yml` edit, so it is the lead's call: ride escalation 6's `ci.yml` change, or ledger it.

No new on-screen string, product timeout, guarantee change or stored-schema change.

**Lead rulings at the spec gate (2026-11-14):**

- Escalation 4 (AD-8, DW-2253): comply under AD-8's first clause (WRITE on the target namespace's routines-database resource, resolved at the call). No spine edit in this run; the sentence extension ("...and a compile's, delete's and import's (DW-2253)") stays a proposal for the owner's architecture Update. Decided.
- Escalation 6 (DW-2501): the baseline is the newest `origin/release/*` branch, since no release tags exist (veto item U-31). Enforcement is local (stage and lead runs) unless the orchestrator rules a `ci.yml` fetch for the gates leg.
- Orchestrator rulings (2026-11-14): escalations 1 (`scripts/ci-throwaway.sh`), 2 (`ui/browser/structural-walk.mjs`) and 3 (`Test/ClassicPageGate.cls` :75 `OWNPAIRS`; whoever integrates second keeps 20.41's `interop.items.changeclass` and removes the compile and import entries) are allowed. Escalation 5 (publish on 127.0.0.1) is allowed as veto item U-32, on condition that CI's browser shards, which reach the throwaway from inside the `ocupilot-browser-ci` container, stay green on the exact head: check how that container reaches the throwaway's port before the push (through the host's published port from another network namespace, 127.0.0.1 breaks it); a red that traces to the bind is a story red — revert to all interfaces and ledger the idea. Escalations 6 and 7 (`ci.yml`): allowed as a footprint extension — fetch `origin/release/*` for the gates leg only (only the refs needed, never deepening the whole checkout), and correct the port-reservation comment to say what the reservation does, without incident history; check `git log origin/OCU-1-epic20 -- .github` before editing.

**Contended** (Epic 20 at `ddae7dc1d`, worktree clean). Re-check before each batch with `git -C /Users/jbrandt/git/OcuPilot/.worktrees/epic-20 diff --stat origin/feature/OCU-1_ocupilot-mvp...HEAD` and `status -s`.

- Changed by Epic 20: `scripts/ci-throwaway.sh`, `ui/browser/structural-walk.mjs` and `src/OcuPilot/Test/ClassicPageGate.cls` (escalations 1-3).
- Not changed by Epic 20:
  - every other file this plan edits;
  - `stored-order.mjs` and its test (new);
  - `ci.test.mjs`, `structural-walk.test.mjs`, `protocol-retry.mjs`/`.test.mjs`;
  - the five spec files;
  - `BackgroundTasksLive`, `LogHubErrors`, `TurnWireFixture`, `TurnNavigate`;
  - the Explorer tools and mints, `AtelierPortWriteDenial`, `ToolEmit`, `DeveloperFloor`, `ExplorerWrite` (test);
  - `screen-store.ts`, `journal-records.page.ts` and their specs.

**Release-upgrade triggers:** none. No `Kernel/State`, `Install`, `module.xml`, `docker-compose.yml` or start-script change, and no `Baseline.cls` key.

**Size.** 12 entries in six batches, about 700 changed lines (inference). This is one chartered story. Batches 2 (DW-2301 only), 3 and 5 wait on rulings, and the rest can run first. If escalation 4 is vetoed, the recommendation is to move DW-2253 to the next standing cleanup rather than hold the epic open.

## Verification

**Slot A, every batch:**

- IRIS MCP `server: "ocupilot-slot-a"`.
- Throwaway `ocupilot-ci`: `--dir /Users/jbrandt/.ocupilot-throwaways/ocupilot-ci`, `--project ocupilot-ci`, `--web 52776`, `--super 1975`.
- Browser variables: `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776`, `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`.
- `ocupilot-ci` is armed; never `ocupilot`.
- Each command is one foreground call with `timeout: 600000`. A call moved to the background is waited on with polls under 170 s.

**Commands.** `(loop)` marks the story's own tests; `(once)` runs before each batch's commit. The full ObjectScript sweep is the lead's, and the full browser suite is CI's.

- `(loop)` **Load:** `rsync -a --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-23/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-ci/src/`, then `$System.OBJ.LoadDir("/opt/ocupilot/src","ck-d",.e,1)` through `docker exec -i ocupilot-ci iris session iris -U HSCUSTOM`. Expected: no compile error.
- `(loop)` **ObjectScript classes:** `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one class per call, with totals from `%UnitTest_Result`. CI seconds:
  - batch 1: `BackgroundTasksLive` 111, `LogHubErrors` 0.9 (plus about 2 s of hangs);
  - batch 4: `ExplorerSaveTurn` 13.4, `InteropEditorSaveTurn` 21.5, `TurnNavigate` 13.4, `LedgerWire` 31.9, `TurnWire` 88.8, `Retention` 4.3;
  - batch 5: `ExplorerWrite` 41.4, `AtelierPortWriteDenial` 34.3, `ToolEmit` 5.7, `DeveloperFloor` 24.1, `ClassicPageGate` 22.7.
- `(loop)` **Client tests:**
  - batch 2: `cd ui && node --test tools/structural-walk.test.mjs tools/protocol-retry.test.mjs`;
  - batch 3: `cd ui && node --test tools/ci.test.mjs tools/stored-order.test.mjs`;
  - batch 6: `cd ui && node --test tools/screen-store.test.mjs`, then `npm run test:components`.
- `(loop)` **Browser specs**, one file per call:
  - First build and redeploy: `cd ui && npm run build` and `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`.
  - Then run: `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/<file>`.
  - Batch 2: `encryption-startup` (23.2 s), `turn` (183.1 s), `error-log` (27.9 s), `a11y-structural-invariants` (459 s locally, near the cap).
  - Batch 4: `interop-item-test` (30.8 s).
  - Batch 6: `journal-records` (23.9 s).
- `(once)` `cd ui && npm run test:tools`, `uv run scripts/check-objectscript.py`, and `bash scripts/lint-docs.sh` when a doc changed.

**Shared surfaces:**

- `TurnWireFixture.Sweep`'s report, which 25 classes assert empty;
- `DeveloperFloor` `TOOLS`/`HELDWRITES`, `ClassicPageGate` `OWNPAIRS`, `ToolEmit`'s added pairs;
- the agent's availability of the six Explorer compile, delete and import tools (`Screen/Context` `Unavailable`);
- `ci-throwaway.sh`'s published ports and bind loop (`ci.test.mjs`);
- the structural walk's report lines and `settle`'s answer (`structural-walk.test.mjs`);
- `retryOnce`'s signature (every `wrapBrowser` user);
- `ScreenStore.setDirection` (additive).

Sweep `ui/browser`, `ui/tools`, the `ui/src` specs and `src/OcuPilot/Test` for each old shape. Every file that changes joins that batch's `(loop)` set.

**Standing criterion:** every test added or changed passes on a fresh environment, in either order (Rule 30; the lead's `fresh_check`).

**Mutation lines:** filled per batch with the observed run, one for each task's pin, as each task names.

Batch 1:

- mutation: DW-2236 -- no deterministic red. A temporary leg (removed, uncommitted) resumed a seeded compact, called `BackgroundSeed.Stall(job, 3)`, then sent the screen's Pause: it answered 200 after 3.0 s (the vendor's Pause waits for the stopped job (inference)), and the row and the vendor state both read Paused at once, so the pre-fix immediate re-read stayed green (`ocupilot-ci`, run 15, 10 tests, 0 failed). The race is the vendor's checkpoint timing; the settle is the seed's established contract (`BackgroundSeed.PausedCompact`). The Resume settles and the admin API `SettledRow` reads wait on the same asynchronous effect, and no stall was tried that forces either to read the old state (inference), so none has a recorded red. Final class: run 20, 9 tests, 0 failed.
- mutation: DW-2526 -- `LogSourcePort.RecentErrors` iterating `tHeld` oldest first (cap keeps the oldest row): `LogHubErrors` run 18 red, "one row, no older than the second seed's ... 2026-11-14T01:27:14.000 against 2026-11-14T01:27:16.000". Reverted (`git status` shows no `Port/` change); run 19, 1 test, 0 failed.
- mutation: DW-2526 teardown -- the `DeleteByError` call in `LogHubErrors.OnAfterOneTest` commented out: `LogHubErrors` run 25 red on the three "is gone" assertions (HSCUSTOM #19, #20, USER #1). Reverted (byte-identical copy); final run green, 1 test, 0 failed.
- (QA) mutation: DW-2526 cap -- `LogSourcePort.RecentErrors` reading `tHeld` ascending, applied again on `ocupilot-ci` → `LogHubErrors` run 29 red; reverted byte-identical (shasum, `git status` clean), reloaded, run 30 green. No test file created or changed by QA; `BackgroundTasksLive` run 28 green (9 tests). DW-2236: no helper-level pin added, since `Settled` and `SettledRow` read live vendor state that no test can hold in the old state.
- (review) mutation: DW-2526 red first -- the old exact-newest assertion (`"1|1|" _ tNewest`, newest of the full read) restored with the USER stand-in in place, throwaway copy only: `LogHubErrors` run 31 red on that assertion alone. Restored (`cmp` identical); run 34 green.
- (review) mutation: DW-2236 stand-in -- `Set tEnded = 1` after the Pause-200 settle, throwaway copy only: `BackgroundTasksLive` run 32 red, the Cancel of the paused compact answered 200, not 409. Restored (`cmp` identical); run 33 green, 9 tests.

## Auto Run Result

Status: done
Blocking condition: none

Batch 1 (DW-2236, DW-2526), this pass only.

- **Changed:**
  - `src/OcuPilot/Test/BackgroundTasksLive.cls`: settles after Resume and after a 200 Pause through `BackgroundSeed.Settled` (Paused continues to Cancel, Done takes the ended-compact Cancel 409 branch, other states fail naming the state); `SettledRow` settles the admin API row's Paused re-read.
  - `src/OcuPilot/Test/LogHubErrors.cls`: the second seed's time comes from its own row by namespace, day and `errorNumber`; a stand-in error seeded in USER after the full read; `OnAfterOneTest` deletes all three seeds and checks they are gone.
  - This spec: boxes checked, mutation lines, triage log.
- **Review:** 5 findings: 2 patched (teardown read-back status plus mutation, DW-2236 mutation line), 3 rejected (reasons in the log); none deferred. Follow-up review recommended: false (patched low 2, medium 0, high 0).
- **Verified on `ocupilot-ci`, one class per call:** `BackgroundTasksLive` run 20 green (9 tests); `LogHubErrors` green on the final code; DW-2526 mutations red (runs 18, 25); `uv run scripts/check-objectscript.py` 0 problems; `npm run test:tools` 2221 pass, 0 fail. DW-2236 has no deterministic red (stall measurement, Verification).
- **Residual:** the DW-2236 settles are unfalsified by a red; the mutation line says why.
