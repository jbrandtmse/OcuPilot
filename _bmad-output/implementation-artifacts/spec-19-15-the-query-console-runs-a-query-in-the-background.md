---
title: 'Story 19.15: The query console runs a query in the background'
type: 'feature'
created: '2026-10-03'
status: 'done'
baseline_revision: '505056dfad7968f2195a7d37acccaea2caecb15a'
baseline_commit: '505056dfad7968f2195a7d37acccaea2caecb15a'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-19-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-19-6-the-query-console-and-its-dml-and-ddl-guard.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** SQL query (Story 19.6) runs a statement inside the request, so a long query holds the console until it answers or reaches the 50 s bound. The classic Execute Query page can run a query in the background.

**Approach:** Add Run in background to the console. It starts the query in a job, as the signed-in user, under 19.6's guard, alarm bound and Max rows, then answers a run id at once. The page polls the run and can cancel it. While it runs, the console's own Run and Explain plan stay usable. The run's answer is kept in OcuPilot's protected state for its owner alone until a sweep removes it. A statement of any kind but a query is refused.

## Boundaries & Constraints

**Always:**

- A background run reuses `Port/SqlPort` unchanged: its gate, input bounds, password refusal, refused kinds, `%Prepare(text, 1)`, the alarm at `SqlPort.BoundSeconds()`, the `$TLevel` rollback, and the cell and answer cuts (Max rows 1 to 1,000, 1,000 characters a cell, 1,000,000 in all).
- Only the `query` kind (statement types 1, 28, 32, 79) runs. The start route checks it, and so does the job, which also repeats the gate, the classify step and `Prohibited.SqlStatement` in its own process before it runs.
- The start route keeps 19.6's run-route order: screen gate (classic page included), body, bounds, classify, self-protection, value count. Then it reserves the run, then spawns the job. Nothing is spawned before every check has passed.
- The job is spawned from no escalated frame (AD-9). It runs as the caller. It refuses to run, ending the run `failed`, when its `$USERNAME` is not the run's owner.
- The statement, values and Max rows reach the job as one `JOB` argument, `$ListBuild(statement, $ListBuild(values...), maxRows)`, and are never stored.
- The run row lives in `Kernel/State/SqlRun`, keyed by a server-minted id and its owner. Every route checks the owner, and another user's run, an unknown id or a swept run each answer the same 404.
- Caps: one running run per user and five per instance. A user's new run replaces that user's ended one. A run is kept 900 s after it ends. Expired rows are swept at every start and by the retention task.
- Cancel is `$SYSTEM.SQL.CancelQuery(jobId, , 3)`, called in the owner's request process and only while the job holds its run lock.

**Never:**

- A mutating kind in the background.
- A turn, a tool, a governance key or screen context reaching a background run (no agent reach in this story).
- A run's statement, values, rows, SQLCODE or message in a log line, a ledger row, an audit payload or a tool result.
- Caller SQL through `action/query` or `AtelierPort`.
- A statement that sets a password prepared, even in a test.
- A poll lease, a dismiss route, a route listing the caller's runs, a bound longer than 19.6's, a third-party library, or an edit to `Api/Error.cls`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Background query | `SELECT Name FROM OcuProbe196.Granted`, Max rows 5 | 202 `{id, status: running}` at once; the poll then answers `ended` with `result` `{outcome: rows, 5 rows, truncated: true}` | Cap notice |
| Values asked | `?` count differs from the values sent | `{outcome: parameters, count}`; nothing spawned | None |
| Not prepared | syntax error, or a table the caller holds no SELECT on | `{outcome: error, sqlcode}`; nothing spawned | Shown as text |
| Mutating | UPDATE, DELETE, CREATE TABLE, CALL, an unclassified type | 422 `EXPLORER.SQL.BACKGROUND.QUERYONLY`; nothing spawned; table unchanged | Banner |
| 19.6 refusals | session, administration, server-file, password, bad input | 19.6's 422 or 400 code; nothing spawned | Banner |
| OcuPilot's own | `%All` in the install namespace: `SELECT ID FROM OcuPilot_Kernel_State.Proposal` | 403 `PROHIBITED.OCUPILOTSQL` | Banner |
| As the caller | a least-privileged principal's job reads its ungranted table, alone and while `%All` holds the text prepared | the run ends with `result` error -99, no row | None |
| Wrong process | the job entry started for user X by a process of user Y | run `failed`; nothing runs | Alert |
| Past the bound | a 5-way cross-join COUNT, fixture bound 2 s | `ended`, `result` `{outcome: stopped, seconds: 2}` | Status line |
| Cancel | the owner cancels a running COUNT | 200; the run reads `canceled` within 3 s | Status line |
| Cancel an ended run | the owner cancels an ended run | 200 with the run as it is | None |
| Another user | principal B polls or cancels A's id | 404 `EXPLORER.SQL.BACKGROUND.NOTFOUND`; A's run unaffected | None |
| Busy | A starts while A's run is running | 409 `EXPLORER.SQL.BACKGROUND.BUSY`, `detail.runId` = the running id; the page attaches to it | Banner |
| Full | instance at its cap (fixture cap 1), another user starts | 503 `EXPLORER.SQL.BACKGROUND.FULL`; nothing spawned | Banner |
| Lost job | the job's run lock is free while the row reads queued (past 10 s) or running | next poll, start or sweep: `failed`, `refusal.code` `EXPLORER.SQL.BACKGROUND.LOST` | Alert |
| Expired / replaced | ended more than 900 s ago, or its owner started another run | the row is gone; a poll answers 404; the page clears the section | None |
| Gate | no `%Development:USE`, or the classic page's custom resource missing | 403 `AUTH.NOPRIVILEGE` naming the pair, on all three routes | Banner |
| Bad id | `:id` not 32 lowercase hex | 404 `EXPLORER.SQL.BACKGROUND.NOTFOUND` before any store read | None |

</intent-contract>

## Code Map

**Reused unchanged:**

- `src/OcuPilot/Port/SqlPort.cls`:
  - `Classify` :273, `Run` :360 in `query` mode, `Gate` :577.
  - `BoundSeconds` :164, `Bounded` :210.
  - `MAXROWS` :66, `OUTCOME*` :135-145.
  - A canceled query answers `{outcome: error, kind: query, sqlcode: -456, message}` (measured).

**SQL query routes:**

- `src/OcuPilot/Area/Explorer/SqlConsole.cls`:
  - `Prepare` :103-137: gate, body, bounds, classify, `Prohibited.SqlStatement` :125, then the error outcome.
  - `Body` :142, `Gate` :174, `RenderInput` :184, `RenderFault` :191.
  - `HandleRun` :34-71 answers `parameters` and the error outcome, which start answers alike.

**Spawn models:**

- `src/OcuPilot/Kernel/Provider/TestCall.cls`: `Spawn` :174-181 (`Job ##class(...).Child($Job, …):($Namespace):..#SPAWNTIMEOUT`, `$Test`, `$ZChild`) and `Child` :238 (refuses another `$Username`).
- `src/OcuPilot/Kernel/Agent/Job.cls` :48, `Run` :79-94.

**Store model:**

- `src/OcuPilot/Kernel/State/Base.cls`:
  - Only Base escalates (checker rules 6, 7, 21).
  - `GuardedTurnSlotLock`/`Unlock` :447-475, the pattern for the run lock.
  - `GuardedSaveIfCurrent` :193, `GuardedOpenOneWhere*` :890-978, `GuardedIdsWhere*` :1062-1144, `GuardedStreamText` :373, `CAPLOCKTIMEOUT`.
- `src/OcuPilot/Kernel/State/Turn.cls`:
  - `GuardedReserve` :180-235, `ReconcileHeld` :285, `GuardedBegin` :329.
  - `GuardedForOwner` :527, `GuardedSweep` :644, `NewKey` :686.
  - `Timestamp`, `NowSeconds`.
  - The name limit: `OcuPilot.Kernel.State.` leaves seven characters (`Test/AgentSchema.cls:135`, checker `MAX_CLASS_NAME_LENGTH`).
- `src/OcuPilot/Kernel/State/Entry.cls`: stream properties :43, :71, written before the save :115-126 and read :189.
- `src/OcuPilot/Api/Turn.cls`: `HandleProgress` :201-240 (owner read, 404 `RenderNotFound` :629), 202 on start :162.
- `src/OcuPilot/Kernel/Agent/Limits.cls`: `RETENTIONSECONDS` 900, `QUEUEDSECONDS` 10, read by name as `Turn` reads them.
- `src/OcuPilot/Kernel/Retention.cls`: `Sweep` :36-115 (one `Try` and `..Step` per store), `Step` :168.

**Routes and codes:**

- `src/OcuPilot/Api/Router.cls`: UrlMap tail :226-228, wrappers :1658-1670, ordering :56-71. A `:id` wrapper takes `(pId As %String)`, as :237 does.
- `src/OcuPilot/Api/AtelierError.cls`: the SQL code and reason pairs :103-143.
- `scripts/check-objectscript.py`: `JOB_ALLOWED` :861, rule 19's text :152-159, its message :888-893. Its harness, `scripts/test_check_objectscript.py`, :1015-1051.

**Test helpers:**

- `Test/SqlConsoleProbe.cls`:
  - `Make`/`Remove`, `EnsurePrincipals`/`RemovePrincipals`, `Armed`.
  - `ProbeAs`/`RunAs` :378-445, which use `$SYSTEM.Security.Login(user)` in a child.
  - `Hold`/`Release` :201-231.
  - `Granted` reads `"40 820"`.
- `Test/SqlConsoleRoutes.cls`: `Post` :53, `Code` :75.
- `Test/SqlPortFixture.cls`, with a 2 s bound.
- `Test/Http.cls`: `AbsoluteRequest` :207.
- `Test/DeveloperFloorFixture.cls`: `EnsurePrincipal` :87, `Call` :217.
- `Test/EndpointCoverage.cls`: `XData Probes` :73-243.
- `Test/DeveloperFloorRoutes.cls`: `Roster` :81-89, count words :5-6 and :78-80.
- `Test/State.cls` :329, :428, derived, so it covers the new class.
- `Test/Retention.cls`.

**Client:**

- `ui/src/app/areas/system-explorer/sql-query.page.ts`:
  - `HELD` :16, deps :189-194, destroy :197-200.
  - Controls :97-115 (Run :114), status :117, grid :125-158.
  - `blocked` :219.
- `sql-query.store.ts`:
  - Paths :25-26, `SqlQueryDeps` :72-77.
  - `answerOf` :99, `statusLineFor` :148, `refusalText` :170.
  - State fields :178-196, `post` :327-349.
- `sql-query.page.spec.ts`: the `api` stub :80-87 answers every path alike, and `settle` :49-55, so the poll needs an injected schedule.
- `ui/src/app/core/turn.ts`, the poll idiom: `schedule` seam :899 and :1011-1016, `pollUntilTerminal`/`pollOnce` :1642-1675.
- `core/api.ts`: `requestJson` :328, `scopedPath` :412.
- `core/strings.ts`: the 30 `EXPERIENCE.md:597` keys :4986-5044, `actionCancel` :109.

**Planning and client rosters:**

- EXPERIENCE.md :597, the SQL query Fixed-strings row and the table's last.
- `ui/tools/self-protection.test.mjs`: `ATELIER_REFUSALS` :505-539.
- `ui/angular.json` :51-57 (`maximumWarning` 2655kB) and `ui/tools/angular-json.test.mjs` :447-473.
- `ui/browser/system-explorer-sql-query.browser-spec.mjs`: helpers :34-120, tests :122 and :141.

**Vendor:**

- `irislib/%SYSTEM/SQL.cls:6072` `CancelQuery(pid, SQLStatementID, timeout)` → `SQLInterrupt^%apiSQL`, which is not exported, so its behavior is measured.

## Tasks & Acceptance

**Execution:**

- [x] Task 0 (`ocupilot-a2-ci`, before code; by=merge_gate): start five concurrent background runs (long probe queries) with ordinary sign-ins alongside; if `messages.log` shows any license-limit line or a sign-in is refused, lower the instance cap to the largest value that stays clean. Record the measurement in Design Notes for the lead's AD-42 note.

- [x] `src/OcuPilot/Kernel/State/Base.cls` -- add-only. Add Private `GuardedSqlRunLock(pKey, pTimeout, Output pHeld)` and `GuardedSqlRunUnlock(pKey)` on `^OcuPilotSqlRun(pKey)`, mirroring the turn-slot pair. The key `"reserve"` is the reserve section, and a run id is the lock its job holds for its life.
- [x] `src/OcuPilot/Kernel/State/SqlRun.cls` (new) -- the run store.
  - Properties:
    - `RunKey` (32 hex, unique, from `GenCryptRand`) and `UserName`, both indexed.
    - `Namespace`.
    - `State` (`queued | running | ended | canceled | failed`).
    - `JobId`, `CancelRequested`.
    - `QueuedAt`, `StartedAt`, `EndedAt` (ISO UTC).
    - `Answer` (`%Stream.GlobalCharacter`).
  - `GuardedReserve(pUser, pNamespace, pMaxRunning, pLimitsClass, Output pKey, Output pBusyKey, Output pFull)`, under the reserve lock:
    - reconcile every live row;
    - set `pBusyKey` when the user has a live row;
    - set `pFull` when live rows reach `pMaxRunning`;
    - otherwise delete the user's ended rows, insert a `queued` row, unlock and sweep.
  - `GuardedBegin(pKey, pUser, Output pBegun, Output pCancel)`: take the run lock with timeout 0, then move `queued` to `running` with `JobId = $Job`, only for the owner.
  - `GuardedFinish(pKey, pState, pAnswerJson)`:
    - `pAnswerJson` is SqlPort's run answer for `ended` and the refusal `{code, reason, detail?}` for `failed`;
    - write `Answer`, `State` and `EndedAt`, then release the run lock;
    - a row whose `CancelRequested` is set ends `canceled` with no answer.
  - `GuardedCancel(pKey, pUser, Output pFound, Output pJobId, Output pLive)`: set `CancelRequested` and answer `pLive` only while the run lock is held.
  - `GuardedViewForOwner(pKey, pUser, pLimitsClass, Output pFound, Output pView)`: owner in the literal SQL, reconcile first.
  - `GuardedSweep(pLimitsClass, pNowSeconds = "")`: delete rows ended more than `RETENTIONSECONDS` ago; reconcile lost rows.
  - Reconcile ends a `running` row whose lock is free, or a `queued` row past `QUEUEDSECONDS` whose lock is free, `failed` with `LOST`.
  - Rationale: AD-9, AD-33's model.
- [x] `src/OcuPilot/Api/AtelierError.cls` -- add-only. `EXPLORER.SQL.BACKGROUND.QUERYONLY`, `.BUSY`, `.FULL`, `.NOTFOUND` and `.LOST`, with the reasons in Design Notes › Strings.
- [x] `src/OcuPilot/Area/Explorer/SqlConsole.cls` -- extract a non-rendering check, the classify step and `Prohibited.SqlStatement` answering `(pGuard, pHttp, pFault)`, which `Prepare` and `SqlBackground` both call. 19.6's behavior is unchanged.
- [x] `src/OcuPilot/Area/Explorer/SqlBackground.cls` (new) -- the three routes and the job.
  - `HandleStart()`: the 19.6 order, then `Start` and the render.
    - Start answers 202 `{id, status: running}`.
    - Otherwise `parameters`, the error outcome, 422 `QUERYONLY`, 409 `BUSY` with `detail.runId`, 503 `FULL`, or 503 `LOST` when the spawn is not accepted (the row then ends `failed`).
  - `HandlePoll(pId)` and `HandleCancel(pId)`: the screen gate, the id shape, the owner view.
    - The answer is `{id, status: running | ended | canceled | failed, startedAt, endedAt, result?, refusal?, cancelRequested}`.
    - `result` is SqlPort's run answer, and `refusal` is `{code, reason, detail?}`.
    - Cancel calls `CancelQuery` only when `pLive`.
  - `Spawn`, the one `JOB`, passes `$ClassName()` so a fixture's seams apply in the job.
  - `Run(pKey, pUser, pNamespace, pRequest, pClass)`, the job:
    1. Refuse another `$USERNAME`.
    2. Begin, or finish `canceled` if cancel was requested.
    3. Repeat the screen's gate (`Screen.Gate.Evaluate`, the classic page included), then the classify, self-protection and query-only checks; a refusal is `failed` with its envelope.
    4. Run through `PortClass()`, then finish `ended`.
    5. Any fault is logged with no statement text and finishes `failed` `LOST`.
  - Seams: `PortClass()` (`SqlPort`), `MaxRunning()` (5), `LimitsClass()`.
- [x] `src/OcuPilot/Api/Router.cls` -- add-only at the tail, in prefix order:
  - `POST /explorer/sql/background/:id/cancel`;
  - `GET /explorer/sql/background/:id`;
  - `POST /explorer/sql/background`;
  - three thin wrappers at the class end.
- [x] `src/OcuPilot/Kernel/Retention.cls` -- add-only. One `Try`/`..Step` block calling `SqlRun.GuardedSweep(pLimitsClass)`.
- [x] `scripts/check-objectscript.py` and `scripts/test_check_objectscript.py`:
  - add `src/OcuPilot/Area/Explorer/SqlBackground.cls` to `JOB_ALLOWED`;
  - name it in rule 19's text and message;
  - add one harness test that it may spawn (AD-42's fourth site).
- [x] Tests (ObjectScript, new). Each gates principals on `SqlConsoleProbe.Armed()` and removes what it made:
  - `Test/SqlRunStore.cls`: reserve, busy, full, replace, begin, finish, cancel flag, the owner view, reconcile and sweep through the now seam.
  - `Test/SqlBackgroundJob.cls`, with `Test/SqlBackgroundFixture.cls` (`PortClass` → `SqlPortFixture`, `MaxRunning` 1). It covers:
    - the job as a principal, reserved and spawned through `SqlRun`/`Spawn` in a child signed in as the principal and read back through `GET /explorer/sql/background/:id` as that principal: granted rows, and the ungranted table refused -99, alone and while held open;
    - the wrong-process refusal;
    - stopped at the bound;
    - cancel → `canceled` within 3 s;
    - a lost job;
    - `FULL` through `Start`;
    - the log scan for the statement's mark.
  - `Test/SqlBackgroundRoutes.cls` (HTTP, checker rule 12's markers):
    - every route's refusals;
    - 202 at once;
    - poll to `ended`;
    - B's 404 on A's poll and cancel;
    - `BUSY` with `detail.runId`;
    - the classic page's custom resource gating all three routes (reuse `ClassicPageGate`'s assignment, add-only there if needed);
    - a `%Developer` start in USER.
- [x] Rosters:
  - `Test/EndpointCoverage.cls`: three probe rows, `ocupilot-coverage-probe`.
  - `Test/DeveloperFloorRoutes.cls`: the two POSTs and one GET in `Roster`, and the count words updated.
  - `Test/Retention.cls`: one leg that reddens when the sweep step is removed.
- [x] `ui/src/app/areas/system-explorer/sql-query.store.ts`:
  - add the background path and a `schedule` seam on `SqlQueryDeps` (1,000 ms, `setTimeout` by default);
  - add background state: id, status, answer, refusal, and its own generation;
  - `startBackground` (adopts `parameters`, the error outcome, and `BUSY`'s `detail.runId` by attaching), `pollBackground`, `cancelBackground` and `stopPolling`;
  - none of it touches `runningValue`.
- [x] `ui/src/app/areas/system-explorer/sql-query.page.ts`:
  - a Run in background button beside Run, `aria-disabled` while its run is running or the statement is empty;
  - a Background run section with its own `role="status"` line, Cancel while running, the refusal as `role="alert"`, and its rows through the page's existing grid as an `ng-template`, not a copy;
  - it stops polling on destroy and resumes on init when a held run reads `running`.
- [x] `ui/src/app/core/strings.ts` (keys at the end, each `/** EXPERIENCE.md:597 */`) and `ui/src/styles/_components.scss` (add-only, on tokens).
- [x] EXPERIENCE.md :597 -- in place. Append the new literals to the String cell and one `Story 19.15` clause to the Where cell, with `[ADDED 2026-10-03 - Story 19.15]`. Add no row, so no gated citation moves.
- [x] Client tests:
  - `sql-query.page.spec.ts`: per-path stub answers and a manual schedule;
  - `self-protection.test.mjs`: five `ATELIER_REFUSALS` rows;
  - `system-explorer-sql-query.browser-spec.mjs`: one test.
- [x] `ui/angular.json` and `ui/tools/angular-json.test.mjs` -- re-base `maximumWarning` to the measured build, with a history line. Stop and ask above 3,800 kB.

**Acceptance Criteria:**

- **AC1:**
  - Given SQL query in USER with a query, when Run in background is pressed, then the start route answers a run id within 1 s, without waiting for the query.
  - While it runs, Run and Explain plan work and show their own answers.
  - When it ends, the screen's Background run section shows its rows under 19.6's Max rows and cuts, with the cut announced.
- **AC2:**
  - Given a DML, DDL, CALL or unclassified statement, when it is run in the background, then it is refused 422 `EXPLORER.SQL.BACKGROUND.QUERYONLY` and nothing is spawned or changed.
  - 19.6's other refusals, the self-protection refusal, the value count and the error outcome answer exactly as the run route does.
- **AC3:**
  - Given a purpose-built least-privileged principal, when its background run reads a table it holds no SELECT on, then the run ends with SQLCODE -99 and no row, also while a `%All` account holds the same text prepared.
  - Its granted table answers rows.
  - A job whose process is not the run's owner refuses to run it.
- **AC4:** Given a query past the bound, when it runs in the background, then the run ends `stopped` with the bound's seconds.
- **AC5:**
  - Given a running background query, when its owner presses Cancel, then the query stops and the run reads Canceled within 3 s.
  - Canceling an ended run answers the run unchanged.
- **AC6:** Given principal A's run, when principal B polls or cancels it, then each answers 404 `EXPLORER.SQL.BACKGROUND.NOTFOUND`, the same answer as an unknown id, and A's run is unaffected.
- **AC7:**
  - Given a user whose run is running, when they start another, then it is refused 409 `EXPLORER.SQL.BACKGROUND.BUSY` naming the running run, and the page attaches to it.
  - Given the instance at its cap, another user's start is refused 503 `EXPLORER.SQL.BACKGROUND.FULL`.
  - Neither spawns.
- **AC8:**
  - Given an ended run, when 900 s have passed and a start or the retention task sweeps, then its row is gone and a poll answers 404.
  - A run whose job died reads `failed` `LOST` at the next poll.
  - A user's new run removes that user's ended run.
- **AC9:**
  - Given a background run, when it ends, then its rows, SQLCODE and message reach only its owner's poll.
  - No log line, ledger row, audit payload, tool result or screen context carries them.
  - No tool or governance key is added, the descriptor declares no read, and the statement and values are never stored.
- **AC10:** Given classic parity (AD-44, Story 19.12), when the three routes are called, then a custom resource on `%CSP.UI.Portal.SQL.Home` gates each, and a `%Developer` runs a background query in USER.
- **AC11 (Integration, Rule 1):** Given the console page on the real instance, when a person starts a background COUNT and then runs a foreground SELECT, then the foreground rows show at once, and the Background run section later shows the COUNT's row. Cancel on a second background COUNT shows Canceled.

## Spec Change Log

- 2026-10-03, lead (spec gate, by=merge_gate): caps ruled 1 running run per user and 5 per instance (409 BUSY, 503 FULL), subject to Task 0's license measurement; the spine carries the drafts (AD-42, AD-7, AD-31, AD-36, AD-39, AD-41, AD-61, the retention line). Contended edits: `Router.cls`, `strings.ts`, `_components.scss` add-only; EXPERIENCE.md :597 extended in place; the budget under the re-measure rule; `scripts/check-objectscript.py`'s JOB allow-list gains `Area/Explorer/SqlBackground.cls`.

## Review Triage Log

### 2026-10-03 — Review pass

- verdicts: 23 findings — high 0, medium 3, low 13, false 7, maybe-false 0
- findings:
  - `[medium]` `[patch]` The job's screen gate (the classic page's resource) had no test that fails without it: the no-pair leg is answered alike by `SqlPort.Gate`, and `ClassicPageGate`'s holding leg accepted `failed` — added a lacking-principal run past the route asserting the job's `AUTH.NOPRIVILEGE` naming `OcuProbe1814Page:USE`, and the holding run must end `ended` or `canceled`; red under the dropped gate (run 4436).
  - `[medium]` `[patch]` The cancel retry loop was untested (the only cancel waited until the query ran) — added `Test/SqlPortDelayed`, `Test/SqlBackgroundDelayed` and `TestAnEarlyCancelIsSentAgainUntilTheQueryRuns`; red at `CANCELTRIES` 1 (run 4437).
  - `[medium]` `[patch]` A reserve's reconcile of the owner's lost run was untested — added `SqlRunStore.TestAReserveEndsTheOwnersLostRunFirst`; red with a state read in place of `Reconcile` (run 4438).
  - `[low]` `[patch]` The start's 503 `LOST` for a spawn not accepted was untested — added `Test/SqlBackgroundUnspawned` and `TestAStartWhoseJobIsNotAcceptedAnswersLost`; red without the refused spawn's `GuardedFinish` (run 4437).
  - `[low]` `[patch]` The client's re-poll after a transient poll failure was untested — added a page-spec case; red without the transient branch.
  - `[false]` `[reject]` AC clauses lacking their own `mutation:` lines — Rule 19 asks one demonstrated mutation per AC, and AC1 to AC11 each carry one.
  - `[low]` `[reject]` An unclassified statement type is never sent to the start route — the refusal is the one predicate `Kind '= query`, which the four sent kinds exercise; a statement of types 16, 25, 27 or 99 would have to be found by probing for a leg that pins nothing new.
  - `[low]` `[reject]` The id-shape legs stay green without the `IDPATTERN` check — the store's owner lookup answers the identical 404 by design, so no caller can observe the difference.
  - `[low]` `[patch]` A poll or cancel refused with anything but 404 left the section reading running with Run in background unavailable — the refusal branch now ends the running state (`failed`, the refusal kept as the alert); page-spec case red when the status is left running.
  - `[low]` `[patch]` `SqlRunStore`'s sweep legs set the clock seam ahead of the instance's, deleting other owners' runs inside their retention — the legs now age their own row and never set the seam ahead (red under the skipped delete, run 4439).
  - `[low]` `[patch]` Explain plan during a background run was untested — the page spec now asserts it available, posts a plan and keeps the section running.
  - `[low]` `[reject]` The page's "Canceled." is waited for 15 s in the browser spec while AC5 says 3 s — the server poll pins under 3 s and the page adds at most one 1 s poll; a 3 s browser wait would add timing flake for no new pin.
  - `[false]` `[reject]` The least-privileged job is started from a signed-in child, not the route — the route refuses that statement before spawning, and the API application grants no application role, so a route-spawned job holds the same identity (exercised by the developer and AC1 legs).
  - `[low]` `[patch]` Production's cap of five was pinned by no test — `TestTheInstanceCapRefusesAnotherOwnersStart` asserts `MaxRunning()` is 5 (red at 4, run 4437); the FULL render shares BUSY's tested path.
  - `[false]` `[reject]` Past the bound runs on the fixture's 2 s, not 50 s — the matrix row names the fixture bound.
  - `[low]` `[patch]` Expired rows were swept only after a reserve that inserted, not at every start — `GuardedReserve` now sweeps after every reserve that held its section; `TestARefusedReserveStillSweeps` red under the old condition (run 4438).
  - `[low]` `[reject]` An unclassified type is not sent (the intent auditor's sighting) — the same root and reason as the row above.
  - `[low]` `[patch]` "Not prepared: syntax error" was not sent — `TestEveryKindButAQueryIsRefusedAndNothingIsSpawned` sends one and asserts the error outcome.
  - `[false]` `[reject]` A non-query with a `?` is asked its values before the 422 — the spec's start order lists `parameters` and the error outcome before `QUERYONLY`, as 19.6's run route orders them.
  - `[false]` `[reject]` AC9's log check rests on one fixture — every `Log` caller passes a fixed sentence, an exception name or a store status, and `SqlPort.Fail`'s status is a code and the default reason.
  - `[low]` `[patch]` The 900 s retention reads the turn's `RETENTIONSECONDS`, so the NOTFOUND sentence's "15 minutes" could drift — the sweep test asserts the sentence names the retention's minutes.
  - `[false]` `[reject]` "Never stored" against the statement index — OcuPilot stores neither; the index row is AD-7's fifth shape.
  - `[false]` `[reject]` Beyond the intent (public `Gate`/`RenderFault`, `core/poll-schedule.ts`, cancel retries) — a cross-class call needs them public, the poll timer lives in `core/` as the turn store's does (progress polling, not AD-43's refresh), and each retry re-checks the run lock.

## Design Notes

**ADs:** AD-5, AD-7, AD-8, AD-9, AD-10, AD-11, AD-12, AD-16, AD-19, AD-21, AD-22, AD-24, AD-29, AD-31, AD-33, AD-36, AD-37, AD-39, AD-41, AD-42, AD-44, AD-47, AD-53, AD-61.

**Decisions (for the spec gate):**

- *AD-7.* The background run is a person's own read, not the turn job.
  - It runs only SqlPort's `query` kind. The start route checks the kind, and the job checks it again.
  - A function a query calls stays AD-21's named limit (DW-2003), as on the foreground Run, which runs a query unconfirmed too.
  - It writes only its run row (AD-9), and its prepare records the fifth shape's statement-index row.
- *AD-42.* `Area/Explorer/SqlBackground` is the fourth spawn site.
  - It lives in the slice because `Kernel/Agent/` may name no port but `ProviderPort` and `Kernel/State/` may spawn nothing. Checker rule 19 is widened by one file.
- *As the caller.* A `JOB` inherits `$USERNAME` and `$ROLES` (measured below).
  - The job checks its identity, as `TestCall.Child` does.
  - It re-evaluates every gate once, before its one statement.
  - A privilege withdrawn mid-run is not seen until the run ends, which the alarm bounds (AD-31 draft).
- *Where the result lives.* `Kernel/State/SqlRun`, in the protected database, through Base's escalation only.
  - The bounds are 19.6's screen-only payload, unchanged (AD-36).
  - The row holds the answer and no statement or values.
  - It is kept 900 s after the run ends (AD-31's progress retention) and swept at every start (any user, as turns are) and by the retention task.
- *Owner-only.*
  - Every route reads the row with the owner in its literal SQL and answers 404 for anyone else (AD-33's model).
  - The vendor also refuses a cross-user cancel without `%CANCEL_QUERY` (measured).
  - Cancel is sent only while the run lock is held. A live job's pid is therefore never a reused one.
- *Caps (AD-41 draft).*
  - A user may have one run running and keeps at most one row, because a new run replaces the ended one.
  - The instance may have five running. That keeps at most five 50 s queries on an 8-license-unit Community key; whether a jobbed process takes a license unit is unmeasured (inference).
  - The answer at the per-user cap is 409 `BUSY` naming the running run, so a reloaded page re-attaches without a list route. The answer at the instance cap is 503 `FULL`.
- *No lease.* The alarm ends every run within the bound plus its fetch, so a run nobody polls ends by itself.
- *Unchanged.*
  - The descriptor gains no action, prompt or read, so `screens.generated.ts` and the tool and governance rosters do not move.
  - AD-53's gap fourteen already covers console runs.

**Spine amendments (draft, for the lead's gate):**

- **AD-42**, in "Test connection answers before the Web Gateway does": "one of three process spawn sites" becomes
  > one of four process spawn sites, with the turn job of AD-7, AD-21's remote-directory listing in `Port/RemoteDatabasePort`, which follows this model, and the SQL console's background run in `Area/Explorer/SqlBackground` (Story 19.15), which the request does not wait for: it is spawned from no escalated frame, takes its statement, values and Max rows as one `JOB` argument and stores none of them, holds its run's lock for its life and is bounded by `SqlPort`'s alarm [AMENDED 2026-10-03, Story 19.15 spec gate, Rule 20]
- **AD-7**, a paragraph after the fifth shape:
  > **The SQL console's background run is a second background job, and it never mutates** [AMENDED 2026-10-03, Story 19.15 spec gate, Rule 20]. A person's own run of one statement the instance types as a query (`SqlPort`'s `query` kind) runs in a job (AD-42) holding the person's `$USERNAME` and `$ROLES`. No turn starts it, it proposes nothing and it runs no other kind; a function the query calls is AD-21's named limit. It writes its own run row in OcuPilot's protected state (AD-9), keyed by run and owner, which a poll or cancel by anyone else answers 404 (AD-33's model), and its prepare records the fifth shape's statement-index row. Measured on `ocupilot-a2-ci`: a purpose-built principal's job read its granted table and was refused -99 on another, also while `%All` held that text prepared.
- **AD-31**, appended:
  > **A background SQL run checks once** [AMENDED 2026-10-03, Story 19.15 spec gate, Rule 20]: its one step is its statement, so the job evaluates the console's gates before it prepares and not again; a privilege withdrawn during the run is not seen until the run ends, which `SqlPort`'s alarm bounds. Nobody's polls keep it alive, so it has no lease.
- **AD-36**, appended to the console paragraph:
  > A background run's answer (Story 19.15) is the same payload, held in OcuPilot's protected state (AD-9) for its owner's poll alone: at most one run per user, kept 900 s after it ends, then swept. Its statement and values are never stored.
- **AD-39**, appended to the sixth exception:
  > A background run's answer is kept, owner-only, until it is swept (Story 19.15, AD-36), and still reaches no log line, ledger row, audit payload, tool result or screen context.
- **AD-41**, appended:
  > **Background SQL runs are bounded too** [AMENDED 2026-10-03, Story 19.15 spec gate, Rule 20]: a user has at most one running and the instance at most five; a start past the first is refused 409 `EXPLORER.SQL.BACKGROUND.BUSY` naming the caller's running run, past the second 503 `EXPLORER.SQL.BACKGROUND.FULL`, and nothing is spawned.
- **AD-61**, appended to the 19.6 case:
  > **Story 19.15 runs the same `Run` in a background job** (AD-7, AD-42): its gate, prepare with privilege checks on, alarm and rollback apply there as the signed-in user. Its cancel is `$SYSTEM.SQL.CancelQuery` on the run's own job, sent from the owner's request only while the job holds the run's lock (measured on `ocupilot-a2-ci`: a principal's call stopped its own job's query in about 1.5 s with SQLCODE -456; a second principal's call on it was refused -99, `%CANCEL_QUERY` required).
- **Operational Envelope › Retention**, appended: "A background SQL run's row is kept 900 s after it ends and swept at every start and by the retention task (Story 19.15)."

**Measured on `ocupilot-a2-ci`, 2026-10-03.**

- Probe setup:
  - Schema `OcuProbe1915` in USER.
  - Classes `OcuProbe1915.Probe` and `.Args` in HSCUSTOM.
  - Principals `OcuProbe1915U` and `OcuProbe1915Q`, each holding `%Development:U`, `%DB_USER:RW` and READ on HSCUSTOM's code database; U also holds SELECT on `Granted`.
  - All were removed and checked gone. Statement-index rows remain on the throwaway.
- *Inheritance:* a JOB of a process signed in as U ran as U with U's role alone. Its `%Prepare(text,1)` read `Granted`'s 40 rows and refused `Hidden` -99.
- *Cache independence:* while `irisowner` (`%All`) held `Hidden`'s SELECT text prepared, the job's prepare of that text still answered -99.
- *Cancel, own job:* U's `CancelQuery(childPid, , 3)` answered OK in 0.001 s, and the job's 5-way cross-join COUNT stopped at 1.53 s with SQLCODE -456. Through `SqlPort.Run` in the job, the answer was `{outcome: error, kind: query, sqlcode: -456}`.
- *Cancel, another user:* Q's call on U's job was refused (`#5521`, SQLCODE -99, "%CANCEL_QUERY required to cancel a query executed by another user"), and the COUNT ran to its end: 102,400,000 in 5.49 s.
- *Cancel, idle job:* a call on the caller's own job running no query answered `#6164` ("not running an SQL Query") at once.
- *Alarm in a job:* `SqlPortFixture.Run` (2 s) stopped the COUNT after 2.00 s, both as U in a job (twice) and as `irisowner` in a job and in the session. One earlier run in a probe sequence answered `stopped` only after 5.5 s (unexplained; contention from the probe before it (inference)).
- *JOB argument:* a 3,400,000-character argument reached its child whole. SqlPort's bounds cap the run's one argument at about 3,377,000 characters.
- *License:* the key carries 8 license units, 6 available at the probe.

**Task 0, measured on `ocupilot-a2-ci`, 2026-10-03.** Probe principals, tables and run rows were removed and checked gone.

- Through the route: five principals each started a six-way cross-join COUNT (`POST /explorer/sql/background`, 202 each). While the five ran, license units read 7 of 8 consumed, against 2 before and after: each running job held one unit for its user and released it when it ended.
- Alongside: API sign-ins of `_SYSTEM`, two of the five and two other principals, nine concurrent requests from three users, and the classic portal page each answered 200; a sixth start answered 503 `FULL`; `messages.log` carried no license line over the window. The five were canceled by their owners.
- Before code, five jobs spawned from session processes signed in as five principals, each running `SqlPort.Run`, left units at 2 and wrote no license line.
- Ruling: the instance cap stays 5. At five runs one unit of this 8-unit key remains for other users' held processes (inference).

**Strings.** All go into row :597, in place. Fixed strings measure 2,322 against the bound of 2,500, so the nine new ones need no raise; Epic 18's additions are unknown here (inference).

- Labels and status lines:
  - "Run in background"
  - "Background run"
  - "Running in the background."
  - "Canceled."
  - The ended status reuses 19.6's lines, and Cancel reuses `actionCancel`.
- Reasons:
  - QUERYONLY: "Only a query runs in the background; use Run for a statement that changes something."
  - BUSY: "A query you started is already running in the background; cancel it or wait for it to end."
  - FULL: "As many background queries as this instance allows are running; try again when one ends."
  - NOTFOUND: "No background run of yours has this id; an ended run is kept for 15 minutes."
  - LOST: "The background run ended without an answer; run it again."

**Rosters** (verify each at edit time):

- `EndpointCoverage` (three rows) and `DeveloperFloorRoutes` (three entries and its count words).
- Checker rules 12 and 19.
- `self-protection.test.mjs` `ATELIER_REFUSALS`.
- `angular-json.test.mjs`.
- Unchanged: `ConfigGate` and `State`/`GrantReadBack`, which are derived. Untouched: `GovernanceBaseline`, `ReadTool`, `ToolRoundTrip`, `ToolDispatch`, `SurfaceCoverage`, `Descriptor`, `DeveloperFloor` `SCREENS`/`TOOLS`, `screens.generated.ts`.

**Consumes:**

- `SqlPort.Classify`/`Run`/`BoundSeconds` and `SqlConsole`'s checks (19.6).
- `Prohibited.SqlStatement`, `Screen.Gate`.
- `Kernel.State.Base`, `Kernel.Retention`, `Limits.RETENTIONSECONDS`/`QUEUEDSECONDS`.
- The SQL query page and store (19.6), and `TurnStore`'s poll idiom.

**Consumed-by:** none beyond this story's page. 19.11's agent runs its SQL in its turn (AD-7) and never reaches a background run.

**Integration ACs:** AC11. The page is the consumer, on the real instance.

**Ledger inbox:** this story owns no ledger entry; `LEDGER slice` reads empty. It adds no read tool, so no DW-1001 occurrence.

**Footprint (Rule 11).** Checked 2026-10-03 against `.worktrees/epic-18` at `9acde1e7a17f5eefb529e401d95d4ca519999fc5`, committed and uncommitted (18.20 in progress).

- **Contended, add-only:**
  - `Api/Router.cls`: Epic 18 adds routes at the same tail and wrappers at the end, unioned at merge.
  - `core/strings.ts` (end), `_components.scss`.
- **Contended, not add-only (lead approval):**
  - EXPERIENCE.md :597, edited in place. Epic 18 edits :164, :173, :375, :479 and :577 in place and adds no row, so no line or citation moves.
  - The spine: the amendments above.
  - `ui/angular.json` and `angular-json.test.mjs`: not in Epic 18's diff yet, but 18.20 adds UI, so the literal will meet at merge under the re-measure rule.
- **Shared rosters, add-only:**
  - `Test/EndpointCoverage.cls`.
  - `ClassicPageGate`, only if AC10's leg lands there.
- **Not contended:**
  - `Kernel/State/Base.cls`, `Kernel/Retention.cls`, `Api/AtelierError.cls`, `Area/Explorer/SqlConsole.cls`.
  - `Test/DeveloperFloorRoutes.cls`, `Test/Retention.cls`, `self-protection.test.mjs`, the browser spec, the SQL query page, store and spec.
  - `scripts/check-objectscript.py` and its harness.
  - Every new class.

## Verification

Load into `ocupilot-a2-ci` and never restart it:

1. `rsync -a --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-19/src/ /tmp/ocupilot-a2-ci/src/`
2. In `docker exec -i ocupilot-a2-ci iris session iris -U HSCUSTOM`, run `$System.OBJ.LoadDir("/opt/ocupilot/src","ck",.tErrors,1)`, then check the status and `tErrors`.

**Run one test-runner call at a time, and wait for each.** Never re-submit after a client-side timeout. Every `OcuProbe196*` object and principal is removed after the run.

**Commands:**

- `uv run scripts/check-objectscript.py && uv run scripts/test_check_objectscript.py` (loop): expected green.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-a2-ci --class OcuPilot.Test.<Class>` (loop), one class per call: expected green. Run it for:
  - `SqlRunStore`, `SqlBackgroundJob`, `SqlBackgroundRoutes`;
  - `SqlConsoleRoutes`, `SqlConsoleWrite`, `SqlPortLive`, `SqlPort`;
  - `EndpointCoverage`, `DeveloperFloorRoutes`, `ConfigGate`;
  - `State`, `GrantReadBack`, `AgentSchema`, `Retention`;
  - `ClassicPageGate` if touched.
- `cd ui && npm run test:tools && npx ng test --include 'src/app/areas/system-explorer/**/*.spec.ts'` (loop): expected green.
- Browser (loop). Build and deploy first: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-a2-ci:/durable/iris/csp/ocupilot/`. Then run each file alone with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52780 OCUPILOT_BROWSER_CONTAINER=ocupilot-a2-ci node --test --test-concurrency=1 browser/<file>`, for `system-explorer-sql-query.browser-spec.mjs` and `a11y-structural-invariants.browser-spec.mjs`: expected green. The full browser suite is CI's.
- `bash scripts/lint-docs.sh && cd ui && npm run test:tools` (loop, after the EXPERIENCE.md edit): expected green.
- `cd ui && npm test` (once, before dev_complete): expected green, with the budget re-based.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-a2-ci`, the full ObjectScript sweep, one class at a time (once, before dev_complete): expected green apart from the known residue.

**Planned mutations (Rule 19)**, one per AC, each on `ocupilot-a2-ci` with the class and its descendants recompiled:

- AC1: `HandleStart` runs the query in the request → `SqlBackgroundRoutes`' answers-within-1-s leg.
- AC2: the start route's query-only check dropped → the UPDATE leg (202, not 422).
- AC3: the job's `$USERNAME` check dropped → `SqlBackgroundJob`'s wrong-process leg (the run executes).
- AC4: `SqlPort.Bounded` answering 0 for a query → the stopped leg (the COUNT ends `rows`).
- AC5: `HandleCancel` sets the flag without `CancelQuery` → the within-3-s leg.
- AC6: the owner dropped from `GuardedViewForOwner`'s SQL → B's poll leg (200).
- AC7: the per-user count skipped in `GuardedReserve` → the BUSY leg; the instance count skipped → the FULL leg.
- AC8: `GuardedSweep`'s delete skipped → the swept leg; reconcile skipped → the lost leg.
- AC9: the job's failure log line carries the statement → the log-scan leg.
- AC10: `HandleStart`'s screen gate dropped → the custom-resource start leg.
- AC11: the store never adopts the polled `result` → the browser leg.

- mutation: AC1, `HandleStart` runs the query in the request before `Start` → `SqlBackgroundRoutes.TestTheStartAnswersARunIdAtOnce`, its within-a-second leg (run 4414).
- mutation: AC2, the query-only check dropped from `HandleStart` → `SqlBackgroundRoutes.TestEveryKindButAQueryIsRefusedAndNothingIsSpawned`, its four `QUERYONLY` legs and "no answer spawned a run" (run 4413); the job's own check refused each, the table unchanged.
- mutation: AC3, the `$Username` check dropped from `SqlBackground.Run` → `SqlBackgroundJob.TestAJobOfAnotherUsersProcessRefusesToRun` (run 4410).
- mutation: AC4, `SqlPort.Bounded` answering 0 for a query, with its two fixtures recompiled → `SqlBackgroundJob.TestAQueryPastTheBoundIsStopped` (run 4424).
- mutation: AC5, `SqlBackground.Cancel` setting the flag without `CancelQuery` → `SqlBackgroundJob.TestTheOwnersCancelStopsTheQuery`, still running 10 s after the cancel (run 4412).
- mutation: AC6, the owner dropped from `SqlRun.IdForOwner`'s statement → `SqlBackgroundRoutes.TestAnotherUsersRunAnswersTheSameNotFound`, both 404 legs (run 4415).
- mutation: AC7, the per-owner check skipped in `SqlRun.GuardedReserve` → `SqlBackgroundRoutes.TestABusyOwnerIsNamedItsRunningRun` (run 4416) and `SqlRunStore.TestAReserveInsertsOneRowAndRefusesALiveOwner` (run 4417); the instance count skipped → `SqlBackgroundJob.TestTheInstanceCapRefusesAnotherOwnersStart` (run 4418) and `SqlRunStore.TestTheInstanceCapRefusesAnotherOwner` (run 4419).
- mutation: AC8, `SqlRun.GuardedSweep`'s delete skipped → `SqlBackgroundRoutes.TestASweptOrReplacedRunIsGone`, its swept leg (run 4420), and `SqlRunStore.TestTheSweepDeletesOnlyARunPastRetention`, whose clock seam is never set ahead of the instance's (run 4439); `SqlRun.Reconcile` ending nothing → `SqlBackgroundJob.TestARunWhoseJobDiedReadsLost` (run 4422) and `SqlRunStore`'s two lost legs (run 4423); the step removed from `Retention.Sweep` → `Retention.TestABackgroundRunPastRetentionIsSwept` (run 4425, beside the known DW-1929 residue).
- mutation: AC9, the statement handed to `FinishRefused` as its logged status → `SqlBackgroundJob.TestTheJobsFailureLineCarriesNoStatement`, its log leg (run 4411).
- mutation: AC10, the screen gate dropped from `SqlConsole.Read` → `ClassicPageGate.TestAnAssignedPageGatesTheBackgroundRun`, the lacking principal's start (run 4426; 19.6's run and plan legs too); the job's own gate refused that run.
- mutation: AC11, `SqlQueryState.readBackground` never adopting the polled answer, rebuilt and redeployed → `system-explorer-sql-query.browser-spec.mjs`, the AC11 test at the row-count wait.
- Each mutation was reverted byte-identical (sha256) and recompiled or rebuilt; then, after a full `LoadDir`, `SqlRunStore` 7/7 (run 4427), `SqlBackgroundJob` 8/8 (4428), `SqlBackgroundRoutes` 7/7 (4429), and the browser spec 3/3 on the rebuilt bundle.
- mutation: AC3 and AC10, the screen gate dropped from `SqlBackground.Run` → `ClassicPageGate.TestAnAssignedPageGatesTheBackgroundRun`, the lacking principal's run past the route no longer naming the page's resource (run 4436).
- mutation: AC5, `SqlBackground.CANCELTRIES` set to 1 → `SqlBackgroundJob.TestAnEarlyCancelIsSentAgainUntilTheQueryRuns`, still running 10.26 s after a cancel sent while `SqlPortDelayed` held the job before its statement (run 4437).
- mutation: the refused spawn's `GuardedFinish` dropped from `SqlBackground.Start` → `SqlBackgroundJob.TestAStartWhoseJobIsNotAcceptedAnswersLost`, the next start refused busy (run 4437).
- mutation: AC7, `SqlBackground.MaxRunning()` answering 4 → `SqlBackgroundJob.TestTheInstanceCapRefusesAnotherOwnersStart`, its cap pin (run 4437).
- mutation: AC7 and AC8, `GuardedReserve` reading each live row's state in place of `Reconcile` → `SqlRunStore.TestAReserveEndsTheOwnersLostRunFirst` (run 4438); sweeping only after an insert → `SqlRunStore.TestARefusedReserveStillSweeps` (run 4438).
- mutation: AC1, `readBackground`'s transient branch dropped → the page spec's "polls again after a transient poll failure"; the refusal branch leaving the status running → "ends the section running state when a poll is refused" (both red in one component run).
- Each was reverted byte-identical (sha256) and recompiled or rerun; after a full `LoadDir`, `SqlRunStore` 9/9 (run 4432), `SqlBackgroundJob` 10/10 (4433), `SqlBackgroundRoutes` 7/7 (4434) and `ClassicPageGate` 7/7 (4435); System Explorer component specs 109/109; on the rebuilt, redeployed bundle the SQL query browser spec 3/3 and the structural walk 12/12.

## Auto Run Result

Status: done
Blocking condition: none

**Implemented.** SQL query's Run in background: `Kernel/State/SqlRun` (owner-keyed run row, reserve under the caps, begin, finish, cancel flag, owner view, reconcile of lost runs, sweep at every reserve and in the retention task) and `Area/Explorer/SqlBackground` (start, poll and cancel routes; the job, AD-42's fourth spawn site, which refuses another `$USERNAME`, repeats the gate, classify, self-protection and query-only checks, and runs through `SqlPort` unchanged; `CancelQuery` only while the job holds its run lock, resent while the begun job runs no statement yet). The page's Background run section polls, cancels and re-attaches. Task 0 kept the instance cap at 5 (Design Notes).

**Files.**

- `src/OcuPilot/Kernel/State/SqlRun.cls`, `Base.cls` (run lock pair), `Kernel/Retention.cls` (sweep step): the store.
- `src/OcuPilot/Area/Explorer/SqlBackground.cls`, `SqlConsole.cls` (`Read`, `Check`, `ErrorOutcome` extracted), `Api/Router.cls` (three routes), `Api/AtelierError.cls` (five codes): the routes and job.
- `scripts/check-objectscript.py`, `scripts/test_check_objectscript.py`: the `JOB` allow-list and its harness test.
- Tests: `SqlRunStore`, `SqlBackgroundJob`, `SqlBackgroundRoutes`, fixtures `SqlBackgroundFixture`, `SqlBackgroundProbe`, `SqlBackgroundUnindexed`, `SqlBackgroundDelayed`, `SqlBackgroundUnspawned`, `SqlPortDelayed`; legs in `ClassicPageGate`, `Retention`; rows in `EndpointCoverage`, `DeveloperFloorRoutes`.
- Client: `sql-query.page.ts`, `sql-query.store.ts`, `sql-query.page.spec.ts`, `core/poll-schedule.ts` (the poll's default timer, kept in `core/` as the turn store's is), `core/strings.ts`, `_components.scss`, the browser spec's AC11 test, `self-protection.test.mjs` rows, `angular.json` and `angular-json.test.mjs` (`maximumWarning` 2704kB); EXPERIENCE.md :597 extended in place.

**Review.** 23 findings (two layers; blind and edge-case layers disabled by the project): 12 patched (3 medium, 9 low: the job's own gate, the cancel retry, the reserve's reconcile, the refused spawn's 503, the client's transient re-poll and refused-poll state, sweep at every reserve, a seam that deleted other owners' runs, Explain plan, the cap and retention pins, a syntax-error leg); 0 deferred; 11 rejected (7 false, 4 low), each with its reason in the triage log. The sweep also found a shipped doc comment spelling a `PROHIBITED.` code (`Prohibited.TestTheSetHasOneHomeAndOneSentencePerCode`), reworded.

**Follow-up review:** false. Three medium entries were patched, each a test added over code that already behaved, with its red observed under the named mutation; no unverified risk can be named. Patched by verdict: medium 3, low 9.

**Verification.** Checker 0 problems, harness OK; `npm test` green (1,782 tools, 2,286 components); `lint-docs` clean; build 2.70 MB under the 2704kB warning; browser specs on the redeployed bundle: SQL query 3/3, structural walk 12/12. Full ObjectScript sweep (441 classes, 3,590 tests, one class at a time) green for every class the story touches; `Prohibited` re-run green (4881) after the comment fix. Reds not caused by this story, all on the 2-day-old throwaway: `Retention.TestAnEntryAges…` (DW-1929 residue); `WireSecurityRead.TestTaskHistory…` (task history 2,889 rows past the 1,000 cut, red since run 2329); `MappingCodeGlobals.TestTheCodeGlobals…` (`^oddPKG("OCUPILOT")` with an `sqlname`, red since run 3907, before this stage); `JournalSettingsRules`, `JournalSettingsWrite`, `JournalWrite`, `JournalWriteGate`, `LicenseServerWrite`, `LicenseWriteGate`, `PathPortInstance` refused at class level because the container predates `OCUPILOT_ALLOW_JOURNAL` and `OCUPILOT_ALLOW_LICENSE_CONFIG`.

**Residual risks.** At the cap of five, one unit of the 8-unit Community key remains for other users (inference, Task 0). `Retention`'s foreign-row guard does not count expired background runs, so its sweep can remove another suite's expired run row. Epic 18's `maximumWarning` (2712kB) meets this one at merge under the re-measure rule; `Router.cls`, `strings.ts`, `_components.scss`, `ClassicPageGate.cls` and `EndpointCoverage.cls` union there.
