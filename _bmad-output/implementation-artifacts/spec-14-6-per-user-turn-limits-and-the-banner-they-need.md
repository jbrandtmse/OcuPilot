---
title: 'Story 14.6: Per-user turn limits, and the banner they need'
type: 'feature'
created: '2026-09-27'
status: 'done'
baseline_revision: 'b125676477d2eeb8dc16afa4c4e98c8ea1d15506'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-14-context.md'
warnings: ['oversized']
deferred:
  - summary: >-
      Epic 16's Guardrails page reports its limits without the new turns-an-hour setting once the branches merge.
    evidence: |-
      origin/OCU-1-epic16 src/OcuPilot/Kernel/Shell/Guardrails.cls:103-110 lists contextRowCap and two character caps as limits; turnsPerHour is not on this branch's copy (inference until merged).
    location: >-
      src/OcuPilot/Kernel/Shell/Guardrails.cls:103
    severity: medium (unverified)
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

### 2026-09-27 — Review pass

- verdicts: 20 findings — high 0, medium 3, low 9, false 8, maybe-false 0
- findings:
  - `[medium]` `[patch]` No tool test pins `resetRememberedState`'s turns-an-hour reset — added the set and leave-alone cases to `ui/tools/preferences-reset.test.mjs`, both mutations observed red.
  - `[low]` `[reject]` No mutation for AC3's busy-before-limit clause — Rule 19 scopes one demonstrated mutation per AC; AC3 carries five.
  - `[low]` `[reject]` No mutation for AC3's "reserves nothing" clause — same: AC3 already carries demonstrated mutations.
  - `[low]` `[patch]` No mutation for the panel banner — demonstrated (`@if (false)` → `panel-turn-limit.spec.ts` red) and recorded.
  - `[low]` `[reject]` No mutation for AC1's reload-and-audit clause — AC1 carries three demonstrated mutations.
  - `[low]` `[reject]` No mutation for the integration AC's browser half — the integration AC carries the `TurnWire` mutation; the browser spec was re-run green after its patch.
  - `[low]` `[patch]` `turn-limit.test.mjs` header names two unrecorded mutations — both demonstrated red and recorded.
  - `[low]` `[patch]` `assert.notEqual(local, utc)` in the browser spec cannot fail — replaced with the page's own `getTimezoneOffset()` equal to -330.
  - `[low]` `[patch]` `panel-turn-limit.spec.ts` claims "in local time" in an unpinned zone — title corrected; the local-time property is pinned by `turn-limit.test.mjs` and the browser spec.
  - `[low]` `[reject]` Start records of a user who stops sending stay until that user's next reserve — bounded to one window per user; a sweep adds a new code path for no reachable harm.
  - `[medium]` `[defer]` Epic 16's Guardrails page lists limits without `turnsPerHour` after the merge (inference) — the page is not on this branch.
  - `[medium]` `[patch]` Browser spec's refusal captured in an async `response` handler can resolve after the banner assert — replaced with `page.waitForResponse` awaited before the asserts.
  - `[false]` `[reject]` A reserve whose job fails to spawn is not shown to count — the start is recorded inside `GuardedReserve` before it returns, ahead of the spawn.
  - `[false]` `[reject]` Validation, kill-switch or no-definition refusals might record — each answers before `GuardedReserve` is called.
  - `[false]` `[reject]` Busy-before-limit untested over HTTP — `HandleStart` renders `tBusy` before `tLimited`, and the reserve returns before the prune when busy (`TestABusyUserAtTheLimitIsRefusedBusy`).
  - `[false]` `[reject]` The HTTP `retryAt` check is self-referential — the exact value is pinned at the reserve (`TestAtTheLimitIsRefusedWithTheRetryRoundedUp`, `TestALoweredLimitRetriesFromTheFourthOldest`).
  - `[false]` `[reject]` "Applied to each user separately" untested — every read and write is subscripted by the user, so no other user's records are reachable.
  - `[false]` `[reject]` The reload-drops-the-line property untested — the entry exists only in `entriesValue`; a reload rebuilds entries from the instance, which stores nothing for a refused start.
  - `[false]` `[reject]` Nothing pins the Switches strings to EXPERIENCE.md — `strings.test.mjs` checks every `/** EXPERIENCE.md:n */` string on its line (the `:282` mutation reddens it).
  - `[false]` `[reject]` The index at :900 still says nine markers — the sentence adds that one is resolved and marked in its row, as the spec asks.

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

ObjectScript mutations were applied to the throwaway's copies only, recompiled with subclasses (`cbk`), and reverted by copying the worktree file back (byte-identical, `diff -rq src /tmp/ocupilot-b-ci/src` empty). The first round carried four mutations at once; each reddened only its own leg, named below.

- mutation: dropped the `turnsPerHour` rule in `SwitchRules.ValidateSwitches` → `SwitchesWire` red (`TestTurnsPerHourValidatesItsRangeAndIsAudited`: -1, 10001, 1.5 answered 200) and `TurnHourLimit` red (`TestTheRulesRefuse...`)
- mutation: dropped the `concurrentTurns` rule → `SwitchesWire` red (`TestConcurrentTurnsIsFixedAtOne`: 2, 0 and "1" answered 200)
- mutation: dropped `readonly` from the concurrent input → `switches.page.spec.ts` red (the Story 14.6 read-only case: `readOnly` false)
- mutation: `DEFAULTTURNSPERHOUR = 1` → `TurnHourLimit` red (`TestNoLimitByDefaultRefusesNothingAndStillRecords`, and the clamp leg) and `SwitchesWire` red (the defaults roster)
- mutation: count check in `Turn.GuardedReserve` replaced by `If 0` → `TurnHourLimit` red (`TestAtTheLimit...`, `TestALoweredLimit...`) and `TurnWire` red (`TestAStartPastTheHourLimitIsRefusedWithItsRetryTime`: the second start answered 202)
- mutation: pruning loop in `Base.GuardedTurnStartsPrune` disabled → `TurnHourLimit` red (`TestAStartOlderThanTheWindowIsPrunedAndNotCounted` alone)
- mutation: `Turn.MinuteCeiling` answers its argument → `TurnHourLimit` red (`TestAtTheLimitIsRefusedWithTheRetryRoundedUp`: retry `...:35:01Z`)
- mutation: `getUTCHours`/`getUTCMinutes` in `turnLimitBanner` → `turn-limit.test.mjs` red (the local-time case)
- mutation: dropped the `TURN.LIMITHOUR` arm in `turnErrorBanner` → `panel-turn-limit.spec.ts` red (the line read "The turn stopped: This turn was not started...")
- mutation: `agentTurnLimitLine`'s ref moved to `EXPERIENCE.md:282` → `strings.test.mjs` red (the line-reference test)
- mutation: the panel's `@if (turnLimitText !== null)` block made `@if (false)` → `panel-turn-limit.spec.ts` red (the banner case)
- mutation: the `TURN.LIMITHOUR` arm in `TurnStore.send` made `null` → `turn-limit.test.mjs` red (the store refusal and fallback cases)
- mutation: `REASONTURNLIMITHOUR` reworded in `Error.cls` → `turn-limit.test.mjs` red (the byte-for-byte pin)
- mutation: `resetTurnLimit` call dropped from `resetRememberedState` → `preferences-reset.test.mjs` red (the Story 14.6 reset case); its early return dropped → red (the leave-alone case)

## Auto Run Result

Status: done
Blocking condition: none

**Change.** `Switch.TurnsPerHour` (0 to 10,000, 0 no limit, placed last so no stored slot moves) is counted at `Turn.GuardedReserve` under the slot lock from `^OcuPilotTurnStarts(user, seconds, key)`, pruned at each reserve and recorded whatever the limit; busy is refused first. `Api/Turn` renders 403 `TURN.LIMITHOUR` with `{limit, retryAt}`. `GET /agent/switches` answers `concurrentTurns` from `Limits.CONCURRENTTURNS`; a `PUT` carrying any other value is refused. The panel shows the banner in local time and a local refused entry. The `Limits` class comment that said Story 14.6 would make the per-turn constants settings now says what shipped.

**Files.** Server: `Kernel/Agent/Limits.cls`, `Kernel/State/Base.cls`, `Kernel/State/Turn.cls`, `Kernel/State/Switch.cls`, `Kernel/SwitchRules.cls`, `Api/Switches.cls`, `Api/Error.cls`, `Api/Turn.cls`. Client: `core/turn-limit.ts` (new), `core/turn.ts`, `shell/panel.ts`, `areas/agent/switches.store.ts`, `switches.page.ts`, `core/strings.ts`; EXPERIENCE.md :281, :349, :756, :900, :909 in place (981 lines). Tests: `Test/TurnHourLimit.cls`, `tools/turn-limit.test.mjs`, `shell/panel-turn-limit.spec.ts`, `browser/turn-limit.browser-spec.mjs` (new); legs in `TurnWire`, `TurnWireFixture.Sweep`, `SwitchesWire`, `switches.page.spec.ts`; `AgentViolation`'s count 32 to 34; `browser/preferences-reset.mjs` `resetTurnLimit`.

Contended files: `Error.cls`, `turn.ts`, `panel.ts`, `strings.ts`, EXPERIENCE.md. Each merges with `origin/OCU-1-epic16` without conflict (`git merge-file` against the merge base).

**Verification.** On `ocupilot-b-ci`, one class per call, totals checked against `%UnitTest_Result`: `TurnHourLimit` 8/8, `TurnWire` 14/14, `TurnStore` 11/11, `SwitchesWire` 24/24, `SwitchState` 13/13, `Envelope` 15/15, `AgentViolation` 8/8. `npm run test:tools` 1,516 pass; `npm run test:components` 1,504 pass; `npm run build` clean (initial total 1,885,523 bytes); `check-objectscript` 0 problems; `lint-docs` clean. Browser, bundle rebuilt and redeployed: `turn-limit`, `switches`, `panel` and `a11y-structural-invariants` green. `smoke.sh --container ocupilot-b-ci` 49/49. The full sweep is the runner's (Rule 29).

**Review.** Two layers (verification-gap, intent-alignment), 20 findings: 7 patched (2 medium, 5 low), 1 deferred (Epic 16's Guardrails page omits the limit after the merge, inference), 12 rejected with reasons in the triage log. Patches: `preferences-reset.test.mjs` gains the set and leave-alone reset cases; the browser spec awaits the 403 with `page.waitForResponse` and checks the page's own zone offset instead of an assertion that could not fail; the panel spec's title no longer claims a time-zone check it cannot make; four more mutations recorded, the zone check's too (emulation dropped → red, 420 vs -330). Follow-up review: not recommended; both patched mediums are test-only and were verified red and green.

**Final verification.** Changed classes recompiled on `ocupilot-b-ci` with subclasses (`cbk`, 0 errors). Full ObjectScript sweep, one class at a time: 315 classes, 2,609 tests, 1 failed — `WireSecurityRead.TestTaskHistoryPairSetsAreEnforcedForARealPrincipal`, the known reused-throwaway residue (`%SYS_Task.History` over 1,000 rows). `npm run test:tools` 1,518 pass; `npm run test:components` 1,504 pass; `npm run build` clean (initial 1.89 MB, under the 1900kB warning); `turn-limit.browser-spec.mjs` 2/2 after redeploy; `smoke.sh --container ocupilot-b-ci` 48/48 with `agentswitches` skipped because browser specs wrote the switches on this reused instance. The limit reads 0 on the throwaway afterwards.

**Residual risk.** Start records of a user who stops sending stay until that user's next reserve (bounded to one window). The refused line is tab-local by design and a reload drops it.
