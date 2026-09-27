---
title: 'Story 14.6: Per-user turn limits, and the banner they need'
type: 'feature'
created: '2026-09-27'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-14-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** A user can start as many turns as they like, so an operator has no ceiling on one person's token spend. The concurrent bound (one turn, AD-41) exists but is not shown on Switches, and the published UX has no banner or transcript line for a turn refused by a limit.

**Approach:** Add an instance-wide `turnsPerHour` switch, applied to each user separately, with 0 (the default) meaning no limit. Show the fixed concurrent bound beside it as a read-only field with its reason. Count each user's started turns on the instance inside the existing reserve, under the slot lock that already enforces one turn at a time. When the count is at the limit, refuse with a structured envelope that the panel renders as the published banner and a transcript line.

## Boundaries & Constraints

**Always:**

- **What counts.** A turn counts when `Turn.GuardedReserve` reserves it: the 202 answer, and also a reserve whose job then failed to spawn (503). A start refused for any reason (validation, kill switch, no definition, busy, this limit) records nothing.
- **Window and store.** Count the turns the instance reserved for that user in the trailing 3,600 s, measured by the instance clock (`$ZTimeStamp`, UTC). Turn rows cannot serve as the count, because they are swept 900 s after a turn ends (`Limits.RETENTIONSECONDS`). Each reserve therefore records `^OcuPilotTurnStarts(user, seconds, turnKey)` under the slot lock, whatever the limit, after pruning that user's nodes older than the window. This global is OcuPilot's own state: the `OcuPilot*` mapping puts it in the protected database (AD-9), and it is read and written only through new `Kernel.State.Base` guarded methods.
- **Order in `HandleStart`** (unchanged up to the reserve): body and conversation checks, then the kill switch (403), then no definition (503). Inside the reserve, busy comes first (409 `TURN.BUSY`, the existing lock banner), then this limit.
- **The refusal.** When the count is at or above `n`, answer 403 `forbidden` with code `TURN.LIMITHOUR` and `detail` `{limit: n, retryAt}`. `retryAt` is ISO-8601 UTC: the time the (count − n + 1)-th oldest counted start turns 3,600 s old, rounded up to the next whole minute. The `reason` is the banner sentence with `<n>` filled and `<hh:mm>` given as `HH:MM UTC`. The refused start reserves and records nothing.
- **Time shown.** The panel renders `retryAt` as zero-padded 24-hour `hh:mm` in the browser's local time. The instance decides, and the browser only displays (Conventions › Dates).
- **The setting.** `Kernel.State.Switch.TurnsPerHour`: a whole number from 0 to 10,000, where 0 means no limit. An empty or out-of-range stored value reads as 0. It goes through `PUT /agent/switches` (administrator only, conditional save, `LogChange`-audited like every other switch field) and is refused 422 `AGENT.SWITCH.TURNSPERHOUR` otherwise. `GET /agent/switches` also answers `concurrentTurns: 1`, taken from the new `Limits.CONCURRENTTURNS`. A `PUT` carrying `concurrentTurns` as anything but the number 1 is refused 422 `AGENT.SWITCH.CONCURRENTTURNS`, and the value is never stored.
- **Strings.** Add strings add-only in `strings.ts`, published in place in EXPERIENCE.md (the line count stays 981):
  - `:281`: the two AC sentences.
  - `:349`: the four Switches strings in the Tasks.
  - `:756`: the note, resolved.
  - `:900` and `:909`: the index text and row, resolved.

**Never:**

- No per-user override row (the AC asks for one limit applied per user). No change to AD-31's per-turn constants, the conversation lock, governance (`Gate.cls`) or `Kernel.Restraint`.
- No client-side enforcement. The client never counts turns and never withholds a Send.
- Do not persist the refused turn. The transcript line is local to the tab's entries, and a reload drops it, because the instance stores nothing for a turn it did not start (inference).
- Stay off Epic 16's hunks (re-check them with `git diff $(git merge-base HEAD origin/OCU-1-epic16) origin/OCU-1-epic16 -- <file>` before editing):
  - `Error.cls` ~:373
  - `turn.ts`: `ProposalOutcome`'s tail and `TurnStore` from ~:1174 on
  - `panel.ts`: its nine insertions
  - `strings.ts`: :1819, :1957 and the tail from :2857
  - EXPERIENCE.md: :83, :85, :152, :169, :226, :313, :479, :573 on, :591, :615, :640, :661 and :833
- Do not edit `panel.spec.ts`, `turn.test.mjs` or `_components.scss`.

## I/O & Edge-Case Matrix

| Scenario | State / Input | Expected | Error |
|---|---|---|---|
| Default | no switch row, or 0 | every start reserved as today; the start is still recorded | none |
| Under limit | n=3, 2 counted in window | 202, a third node recorded | none |
| At limit | n=3, 3 counted | 403 `TURN.LIMITHOUR`, `detail.limit` 3, `retryAt` = oldest+3600 rounded up to the minute; no row, no node | none |
| Lowered limit | n=2, 5 counted | refused; `retryAt` from the 4th-oldest start | none |
| Aged out | a node older than 3,600 s | pruned at the reserve, not counted | none |
| Busy and at limit | live turn + at limit | 409 `TURN.BUSY` (lock banner) | none |
| Bad setting | `turnsPerHour` -1, 10001, 1.5, "5" | 422 on `turnsPerHour`, nothing written | none |
| Concurrent | `PUT {concurrentTurns:2}` | 422 `AGENT.SWITCH.CONCURRENTTURNS` | none |

</intent-contract>

## Code Map

- `src/OcuPilot/Api/Turn.cls` `HandleStart` :36-172: reads switches at :96, reserves at :121, and answers 409 on busy at :127. It passes `tSwitchValues("turnsPerHour")` to the reserve and renders the refusal.
- `src/OcuPilot/Kernel/State/Turn.cls` `GuardedReserve` :159-195, under slot lock (`ReconcileHeld` busy check :169). `NowSeconds` :115 and `Timestamp` :108. The retention sweep :565 is why rows cannot serve as the count.
- `src/OcuPilot/Kernel/State/Base.cls`: the `GuardedTurnSignalSet`/`Get`/`Kill` :519-560 pattern (`New $ROLES` + `AddRoles`) for the new start-record methods. `MAPPINGPATTERN` :86.
- `src/OcuPilot/Kernel/State/Switch.cls`: parameters and properties :20-80, `Resolve` :95 (the row-cap range pattern) and `SetGuarded` :137.
- `src/OcuPilot/Api/Switches.cls`:
  - `Fields` :59, `Projection` :424 and `MergeBody` :500 (the integer takes a JSON number only)
  - `HandleUpdate` :119, `LogChange` :579
- `src/OcuPilot/Kernel/SwitchRules.cls` `ValidateSwitches` :40 (row-cap rule :47).
- `src/OcuPilot/Kernel/Agent/Limits.cls`: named constants (AD-31).
- `src/OcuPilot/Api/Error.cls`:
  - `TURNBUSY` :722, `REASONTURNBUSY` :879, `TurnCodes` :1028 and `ReasonForTurn` :1035
  - `AGENTSWITCHCONTEXTROWCAP` :587, its reason :1448, the agent-code list :1347 and the reason lookup :1161
  - `Render(status, slug, reason, code, detail)` :1586
- `ui/src/app/core/turn.ts`:
  - `TurnErrorInfo` :145, `TurnEntry` :290, `SendRefusal` :375, `turnErrorBanner` :770
  - `send()` :1023-1100 (409 → locked :1059; other refusals → `sendErrorValue` :1071)
- `ui/src/app/shell/panel.ts`: lock banner slot :313-320, send-error banner :322-327, `sendErrorText` :908 and the `turns` mapping :944 (`errorBanner`).
- `ui/src/app/areas/agent/switches.store.ts`: `SWITCH_FIELDS` :30, `NUMBER_FIELDS` :42, `emptyBuffer` :88. `switches.page.ts` has the row-cap field at :145-168.
- `ui/src/app/core/strings.ts`: `agentTurnLockBanner` :192, the switch labels :620-640, and the `/** EXPERIENCE.md:n */` refs checked by `ui/tools/strings.test.mjs`.
- EXPERIENCE.md (`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/`): lock banner row :281, row-cap row :349, `[NOTE FOR PRD]` :756, index :900 and :909.
- Tests to copy:
  - `Test/TurnWire.cls` (armed principals, `Start`, `TestABusyCallerIsRefusedAndAConcurrentPairStartsOne` :294)
  - `Test/TurnWireFixture.cls` `Sweep` :346
  - `Test/SwitchFixture.Reset`
  - `Test/SwitchesWire.cls` (key roster :86, row-cap legs :589)
  - `ui/browser/reply.browser-spec.mjs` + `turnprobe-spec.mjs` (arming a scripted provider)
  - `ui/browser/preferences-reset.mjs` `resetGovernancePolicy` (read, then save at version)

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Kernel/Agent/Limits.cls`: add `CONCURRENTTURNS = 1` (structural: the slot lock admits one) and `TURNLIMITWINDOWSECONDS = 3600`.
- `src/OcuPilot/Kernel/State/Base.cls`: add private guarded methods over `^OcuPilotTurnStarts`:
  - prune a user's nodes at or before a cutoff and answer the remaining start seconds in ascending order;
  - record one start;
  - kill one user's nodes, exposed as a public `Turn.GuardedForgetStarts(pUser)` for tests and fixtures.
- `src/OcuPilot/Kernel/State/Turn.cls` `GuardedReserve`:
  - Add trailing optional `pHourLimit = 0`, `Output pLimited`, `Output pRetrySeconds`. Existing callers (`Api/Turn`, `Install/Smoke`, tests) stay valid.
  - After the busy check, prune and count. At the limit, set `pLimited` and the rounded retry seconds and insert nothing. Otherwise insert as today and record the start.
  - Add a seconds → ISO helper.
- `src/OcuPilot/Kernel/State/Switch.cls`:
  - Add `DEFAULTTURNSPERHOUR = 0`, `TurnsPerHour`, the `turnsPerHour` subscript in `Resolve`/`SetGuarded`.
  - The property doc records why `SCHEMAVERSION` does not move: an older row reads `""`, which is 0, the default.
- `src/OcuPilot/Kernel/SwitchRules.cls`: add the `turnsPerHour` range rule (0 to 10,000) and the `concurrentTurns` must-be-1 rule, applied only when present.
- `src/OcuPilot/Api/Switches.cls`:
  - Add a `turnsPerHour` `Fields` entry (integer, security 1: it bounds how often the agent acts).
  - `Projection` adds `concurrentTurns`.
  - `MergeBody` copies a present `concurrentTurns` (non-number → `""`) for the rule only.
- `src/OcuPilot/Api/Error.cls`, add-only near the anchors:
  - `TURNLIMITHOUR` with reason "You have reached this instance's limit of <n> agent turns an hour. You can send again at <hh:mm>.", in `TurnCodes`/`ReasonForTurn`.
  - `AGENTSWITCHTURNSPERHOUR`, reason "Agent turns per user an hour is a whole number from 0 to 10,000, where 0 means no limit."
  - `AGENTSWITCHCONCURRENTTURNS`, reason "Agent turns running at once per user is fixed at 1."
  - Both switch codes go in the agent-code list and the reason lookup.
- `src/OcuPilot/Api/Turn.cls`: pass the limit; on `pLimited`, `Render(403, FORBIDDEN, <filled reason>, TURNLIMITHOUR, {limit, retryAt})`.
- `ui/src/app/core/turn-limit.ts` (new, framework-free):
  - `TURN_LIMIT_CODE`
  - `turnLimitOf(detail)` → `{limit, retryAt} | null`
  - `turnLimitBanner(limit, retryAt)`: local `hh:mm` from `getHours`/`getMinutes`
  - `turnLimitLine(limit)`
- `ui/src/app/core/turn.ts`:
  - In `send()`, on an error with code `TURN.LIMITHOUR`, set `turnLimitValue` and append a local entry to the entries (`seq` -1, the message, state `failed`, `error` `{seq: 0, code, reason: turnLimitLine(n)}`, `live` false). Do not set `sendErrorValue`.
  - Add `turnLimit()`, cleared where `sendErrorValue` is cleared.
  - `turnErrorBanner` returns `error.reason` verbatim for that code.
- `ui/src/app/shell/panel.ts`: while `turn.turnLimit()` is set, a warning banner (`role="alert"`, `data-slot="turn-limit"`) beside the send-error banner reads `turnLimitBanner(...)`.
- `ui/src/app/areas/agent/switches.store.ts` and `switches.page.ts`:
  - `turnsPerHour` joins `SWITCH_FIELDS`/`NUMBER_FIELDS` (buffer default `'0'`).
  - The page adds a number input (min 0, max 10000) with the hint via `aria-describedby`, after the row cap.
  - The concurrent field is a read-only `<input readonly>` showing the stored `concurrentTurns`, described by its reason. Neither is sent on save.
- `ui/src/app/core/strings.ts`, add-only:
  - After :192, `agentTurnLimitBanner` and `agentTurnLimitLine` ("This turn was not started: you have used your <n> turns for this hour."), each `/** EXPERIENCE.md:281 */`.
  - After :640, each `/** EXPERIENCE.md:349 */`:
    - `agentSwitchesTurnsPerHour`: 'Agent turns per user an hour'
    - `agentSwitchesTurnsPerHourHint`: '0 means no limit.'
    - `agentSwitchesConcurrentTurns`: 'Agent turns running at once per user'
    - `agentSwitchesConcurrentTurnsReason`: 'Fixed at 1: the conversation lock and the panel\'s single transcript assume one turn at a time per user.'
- EXPERIENCE.md, in place:
  - `:281` gains the two sentences. Its Where cell names the turn-limit banner and the refused turn's transcript line (Story 14.6): `<n>` is the Switches limit and `<hh:mm>` the browser's local time of the instance's `retryAt`.
  - `:349` gains the four strings.
  - `:756` becomes a `[RESOLVED 2026-09-27, Story 14.6]` sentence pointing at `:281`.
  - `:909`'s row is marked resolved, and `:900`'s count sentence says one indexed marker is resolved.
- `ui/browser/preferences-reset.mjs`: `resetTurnLimit()`, called from `resetRememberedState`: read `GET /agent/switches`, and when `turnsPerHour` ≠ 0, `PUT {turnsPerHour:0,rowVersion}`, asserting 200.
- Tests (new):
  - `src/OcuPilot/Test/TurnHourLimit.cls` (unarmed): reserve legs for each matrix row with a probe user name (seeded nodes, default, window, `retryAt` rounding, refusal writes nothing) and `Switch.Resolve` legs. `OnAfterOneTest` deletes its turn rows and start nodes by exact key and runs `SwitchFixture.Reset`.
  - `ui/tools/turn-limit.test.mjs`: sets `process.env.TZ = 'Asia/Kolkata'` before any Date. It covers the formatters, the `TurnStore` refusal path with a fake API, and a pin that `Error.cls`'s `REASONTURNLIMITHOUR` equals `STRINGS.agentTurnLimitBanner`.
  - `ui/src/app/shell/panel-turn-limit.spec.ts`: the banner and the transcript line.
  - `ui/browser/turn-limit.browser-spec.mjs`: arms turnprobe; on Switches, sets 1 and saves, then a reload shows 1 and the concurrent field reads 1, read-only, with its reason. It calls `Turn.GuardedForgetStarts(<config.username>)` through `runIris`, sends twice and asserts the banner and line; `after` restores 0 and forgets the nodes.
- Tests (added legs):
  - `TurnWire.cls` gains one method (a new armed class would edit `scripts/ci-throwaway.sh`'s arming roster, which Epic 16 contends): set limit 1; a start is 202; after it ends, the next start is 403 with the code, the reason, `detail.limit`, `detail.retryAt` and a JSON content type, and no row is reserved. `TurnWireFixture.Sweep` also forgets `USERA`'s and `USERB`'s start nodes, and `OnAfterOneTest`'s `SwitchFixture.Reset` restores no limit.
  - `SwitchesWire`: the key roster gains `turnsPerHour` and `concurrentTurns`, plus range and concurrent refusals, and a `turnsPerHour` change's audit row names the field.
  - `switches.page.spec.ts`: the field and the read-only row.

**Acceptance Criteria:**

- **AC1.** Given Switches, when an administrator saves agent turns per user an hour as 3, then `GET /agent/switches` reads 3 after a reload and the change is audited. The concurrent field shows 1, read-only, with its reason, and a `PUT` of any other concurrent value is refused 422.
- **AC2.** Given no limit set, when a user starts turns, then none is refused for count (`TurnHourLimit` default leg).
- **AC3.** Given a limit of n with n turns reserved for that user in the trailing hour, when they send, then:
  - the instance answers 403 `TURN.LIMITHOUR` and reserves nothing;
  - the panel shows "You have reached this instance's limit of n agent turns an hour. You can send again at hh:mm." in browser-local time;
  - the transcript shows "This turn was not started: you have used your n turns for this hour.";
  - a busy user still gets the lock banner.
- **AC4.** Given this change, when `npm run test:tools` runs, then `strings.test.mjs` passes with the new strings on EXPERIENCE `:281`/`:349`, and EXPERIENCE.md still has 981 lines with the note and the index row resolved.
- **Integration (Rule 1).** Given a stored limit, when `POST /turn` is sent over HTTP (the `TurnWire` leg) and when the panel sends in a real browser (`turn-limit.browser-spec.mjs`), then each consumer observes the refusal from the instance.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs:** AD-41 (the count lives beside the concurrency bound, on the instance, at the reserve), AD-31, AD-30, AD-7, AD-9, AD-39, AD-12, AD-19, AD-15/FR-29 (switch audit), and Conventions › Concurrent writes, › Dates, › Error shape and › When `SCHEMAVERSION` moves.

**Spine amendment (Rule 20), written by the runner at the spec gate 2026-09-27 as AD-41's turns-an-hour paragraph and the Deferred row marked done.** Add to AD-41's Rule: "Where an administrator sets it on Switches, a user also has a bounded number of turns an hour (Story 14.6). These are the turns the instance reserved for that user in the trailing 3,600 s. They are counted from OcuPilot's own state under the slot lock at reserve and refused 403 `TURN.LIMITHOUR` with the minute the oldest counted turn ages out. There is no limit by default. The concurrent bound stays exactly 1 and is not a setting." Also mark the Deferred row "Per-user read-only and per-user turn limits" done (Stories 14.5 and 14.6). AD-31's per-turn constants are unchanged.

**Why a start global, not the Turn table.** Turn rows are deleted 900 s after they end, so a count over them undercounts after a quarter hour (measured at `Limits.RETENTIONSECONDS` and `GuardedSweep`). A per-user start record written inside the reserve is atomic with the busy check for free, because the slot lock already serializes one user's reserves.

**Consumes:** `Kernel.State.Switch`, `Kernel.State.Turn.GuardedReserve` (AD-41's slot lock). **Consumed-by:** `Api/Turn.HandleStart` and the panel. There are no later stories.

**Contended with Epic 16:** `Error.cls`, `turn.ts`, `panel.ts`, `strings.ts`, EXPERIENCE.md and the spine (the runner writes it). The new tests sit in their own files so that `panel.spec.ts` and `turn.test.mjs` stay untouched. Not touched: `scripts/ci-throwaway.sh` (no new armed class), `Router.cls`, `EndpointCoverage.cls` (no new route), `Pref.cls` and `_components.scss` (existing `ocu-banner` and `ocu-field` classes).

## Verification

Slot B. Copy each changed `.cls` into `/tmp/ocupilot-b-ci/src` and load it on `ocupilot-b-ci`. Run one test at a time. Before any browser run, rebuild and `docker cp ui/dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci`. Every test restores "no limit", on its failure path too.

**Commands:**

- `(loop)` Run `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>` for each of `TurnHourLimit`, `TurnWire`, `TurnStore`, `SwitchesWire`, `SwitchState` and `Envelope`, one call at a time. Expected: 0 failures each, with totals checked against `%UnitTest_Result`.
- `(loop)` Run `node --test --test-concurrency=1` over `browser/turn-limit`, `switches` and `panel` (each `.browser-spec.mjs`). Expected: pass.
- `(loop)` Run `cd ui && npm run test:tools && npm run test:components`, `uv run scripts/check-objectscript.py <changed .cls>` and `bash scripts/lint-docs.sh`. Expected: clean, and `wc -l` EXPERIENCE.md reads 981.
- `(once, before dev_complete)` Run the full ObjectScript sweep on `ocupilot-b-ci`, one class per call, then `cd ui && npm test && npm run build`, then `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`. Expected: green, with a non-zero count. CI runs the full browser suite (Rule 29).

**Pinning mutations (Rule 19; record each as `mutation: … → …`):**

- **AC1:** drop the `turnsPerHour` range rule. Expected: `SwitchesWire` goes red. Drop the concurrent rule. Expected: `SwitchesWire` goes red. Drop `readonly`. Expected: `switches.page.spec.ts` goes red.
- **AC2:** `DEFAULTTURNSPERHOUR = 1`. Expected: the `TurnHourLimit` default leg goes red.
- **AC3:**
  - Remove the count check in `GuardedReserve`. Expected: `TurnHourLimit` and `TurnWire`'s limit leg go red.
  - Stop pruning. Expected: the aged-out leg goes red.
  - Drop the minute round-up. Expected: the `retryAt` leg goes red.
  - Use `getUTCHours`. Expected: `turn-limit.test.mjs` goes red.
  - Drop the `turnErrorBanner` case. Expected: `panel-turn-limit.spec.ts` goes red.
- **AC4:** move a new ref to `EXPERIENCE.md:282`. Expected: `strings.test.mjs` goes red.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
