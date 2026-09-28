---
title: 'Story 14.5: The per-user read-only toggle'
type: 'feature'
created: '2026-09-27'
status: 'done'
baseline_revision: 'c099443ce3ab7f8be8bef6adbfc20a2f0ce3e864'
baseline_commit: 'c099443ce3ab7f8be8bef6adbfc20a2f0ce3e864'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-14-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** A user cannot restrain the agent for themselves. Read-only exists only as the instance switch (Story 3.7) and as a per-definition flag, and the Definition form draws no control for that flag (DW-1621).

**Approach:** Store the user's own choice on the instance as one more AD-50 preference row. Make it the fourth source `Kernel.Restraint.Verdict` reads, so the gate that already blocks writes also blocks this user's. Add a caller-own `PUT /agent/restraint`, a switch beside the panel's footer line, and the Definition form's read-only checkbox.

## Boundaries & Constraints

**Always:**

- **One enforcement point (AD-30).** `Restraint.Verdict` reads the choice on every call. Precedence is: kill switch (instance, then user), then enforced, then **for you**, then by the definition. The new code is `AGENT.READONLY.USER` and the new footer key is `statusReadOnlyForYou`. Every existing caller picks the choice up through the verdict: `Dispatch`, `Loop.Boundary`, `Confirm`, `Turn`'s context `readOnly` and `GET /agent/restraint`.
- **Store (AD-50, AD-9).** `Kernel.State.Pref`: add Kind `restraint` with the name `readOnly`. The value is `"1"` or `"0"`, written with `GuardedSetValue`. With no row, or any other value, the toggle is off. It is written only through `PUT /agent/restraint` (`Api.Preferences` refuses the kind) and never appears in `GET /account/preferences`. `SCHEMAVERSION` does not move: this is a new Kind value, and older rows read the default.
- **Route.** `PUT /agent/restraint` accepts exactly `{readOnly: boolean}` and writes only `$Username`'s row. It answers the same body as `GET`, which gains `readOnlyForYou`, the stored choice. A write while enforced read-only is on is stored, and the verdict stays `AGENT.READONLY.ENFORCED`.
- **Panel switch.** Name: "Read-only for me". It is checked when `readOnlyForYou` or `enforcedReadOnly` is true. It carries `aria-describedby` pointing at the footer line and is drawn only once the status read has answered. Under enforced read-only it is `aria-disabled`, and a click changes nothing and sends nothing (AC2).
- Strings are published in place: EXPERIENCE.md :289 and :335 grow and its line count stays the same. `strings.ts` is add-only.

**Never:**

- No second check anywhere (tool, confirm, client). No change to `Dispatch.cls`, `Loop.cls`, `Confirm.cls`, `Turn.cls` or `Governance/Gate.cls`. No restraint code outside `Restraint.cls`, `Error.cls` or a test.
- It never gates a screen's own action or Save (AD-53, AD-55).
- No browser storage for the choice.
- Stay off Epic 16's hunks: `Error.cls` :373-381; `Router.cls` :113-143 and its methods from :655 on; `Pref.cls` :82; `panel.ts` :48, :175, :471, :1005 and :1573; `strings.ts` :1819, :1957 and the tail from :2857; `_components.scss` :4849, :6461 and :6576; EXPERIENCE.md :83, :85, :479, :573-578, :615, :661 and :833; `EndpointCoverage` :105, :112 and :132.

## I/O & Edge-Case Matrix

| Scenario | State / Input | Expected | Error |
|---|---|---|---|
| Default | no row | verdict unblocked, `readOnlyForYou` false, key `statusReadOnlyOff` | none |
| On | `PUT {readOnly:true}` | blocked, `AGENT.READONLY.USER`, key `statusReadOnlyForYou`; another user unchanged | none |
| Enforced wins | enforced on + for you on, or `PUT false` while enforced | `AGENT.READONLY.ENFORCED`, key `statusReadOnlyEnforced`; switch checked and `aria-disabled` | none |
| Over the definition | for you on + definition read-only | `AGENT.READONLY.USER`, key `statusReadOnlyForYou`; off again: key `statusReadOnlyByDefinition` | none |
| Kill switch | hold or global + for you on | the kill-switch code, as today | none |
| Bad body | `{}`, `{"readOnly":"yes"}`, an extra member, not JSON | 422 slug `validation_failed`, code `AGENT.RESTRAINT.BODY`, nothing written | an unreadable body gives 500 via `Switches.RenderBadBody` |
| Wrong route | `POST /account/preferences {kind:"restraint"}` | refused as an unknown kind | none |

</intent-contract>

## Code Map

- `src/OcuPilot/Kernel/Restraint.cls`: `Verdict` :79-133, with the footer parameters at :43-52 and the doc at :27-29 already naming this story. `DefinitionReadOnly` :151 is the pattern for a guarded read with the reference dropped.
- `src/OcuPilot/Api/Error.cls`: restraint codes :612-658 (`ReasonForRestraint` :637, `RestraintCodes` :649). `AGENTCONTEXTSHARE` :406-409 is the body-refusal pattern.
- `src/OcuPilot/Kernel/State/Pref.cls`: Kind parameters :64-103, `GuardedSetValue` :287, private `OpenByKey`. `Kernel/State/Sharing.cls` is the older per-user precedent; do not copy its separate store (AD-50).
- `src/OcuPilot/Api/Switches.cls`: `HandleRestraint` :301-326 builds the body. The header :19-22 says "every accepted write is audited"; scope that sentence to the switch and hold routes. `Api/Context.cls` `HandleUpdate` :41-87 is the caller-own PUT pattern.
- `src/OcuPilot/Api/Router.cls`: GET route :73, thin target `AgentRestraint` :212.
- `ui/src/app/core/agent-status.ts`: `Restraint` :105, `FOOTER_KEYS` :134, `UNRESTRAINED` :141, `restraintOf` :289, `sameRestraint` :312, class :326. The write pattern is `AgentContext.setShare`/`write` in `core/agent-context.ts` :218-260.
- `ui/src/app/shell/panel.ts`: footer line :524, `readOnlyLine` :833, `imports` :237. `shell/context-chip.ts` :66-76 and :203 is the switch pattern; its styles are at `_components.scss` :3671-3720, and the footer line's at :3505-3515.
- `ui/src/app/areas/agent/definition-form.page.ts`: Advanced holds retention at :439-455, the checkbox pattern is at :215-231, and `store.setFlag` is at :972. `readOnly` is already in `WRITABLE_FIELDS` and `BOOLEAN_FIELDS` (`definition-form.store.ts` :58-84), and the server's field list carries it (`Api/Definitions.cls` :113).
- Rosters to update:
  - `Test/AgentViolation.cls` :78 (envelope list)
  - `Test/Restraint.cls` :346 (footer keys)
  - `Test/SwitchesWire.cls` :410 (key list) and :578 (routes)
  - `Test/EndpointCoverage.cls` :82
  - `Test/ConfigGate.cls` `Exceptions` :279
  - `ui/tools/agent-status.test.mjs` :432
  - `scripts/check-objectscript.py` :768-773 (`RESTRAINT_CODE_RE` tails), with its harness `scripts/test_check_objectscript.py` :1216-1360
- Test patterns:
  - `Test/ToolWrite.cls` `TestAHeldUserIsDroppedByTheRealRestraintVerdict` :357
  - `Test/TurnGrounding.cls` `TestEnforcedReadOnlyReadsTrue` :151 (armed)
  - `Test/SwitchesWire.cls` `Call` :67 and `Test.Http.GetTestUsername()`
  - `ui/browser/switches.browser-spec.mjs` :73-133 (helpers) and `definitions.browser-spec.mjs` :96-160
  - `ui/src/app/testing/agent-status.ts` (`stubAgentStatus`)
- `ui/browser/preferences-reset.mjs` :55-66 `resetRememberedState`.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Kernel/State/Pref.cls`:
  - After :103, add `KINDRESTRAINT = "restraint"` and `RESTRAINTREADONLY = "readOnly"`.
  - After `GuardedSetValue`, add `GuardedValue(pUserName, pKind, pName, Output pValue) As %Status`, answering `""` for no row and dropping its reference.
- `src/OcuPilot/Api/Error.cls`:
  - After :409, add `AGENTRESTRAINTBODY = "AGENT.RESTRAINT.BODY"` and its reason, "The body must carry exactly one member, the boolean readOnly."
  - Beside :622, add `AGENTREADONLYUSER = "AGENT.READONLY.USER"`, its reason "Read-only is on for this user, so no write can be made through the agent.", and entries in `ReasonForRestraint` and `RestraintCodes`.
- `src/OcuPilot/Kernel/Restraint.cls`:
  - Add `FOOTERKEYFORYOU` and the fourth source, read through `Pref.GuardedValue`.
  - Answer the `readOnlyForYou` subscript (the stored choice).
  - Apply the precedence from Always. Update the doc at :27-29 and :70-73.
- `src/OcuPilot/Api/Switches.cls`:
  - Extract the `HandleRestraint` body into a private `RestraintBody(pUser, Output pBody)`, adding `readOnlyForYou`.
  - Add `HandleRestraintUpdate`, which validates as `Context.HandleUpdate` does, then `Pref.GuardedSetValue(..CallerUsername(), …, $Select(on:"1",1:"0"))`, then answers `RestraintBody`.
  - Scope the header's audit sentence (see Design Notes).
- `src/OcuPilot/Api/Router.cls`: add `<Route Url="/agent/restraint" Method="PUT" Call="AgentRestraintUpdate"/>` after :73, and add a thin target after `AgentRestraint`.
- `scripts/check-objectscript.py`: add `USER` to the `READONLY\.(…)` tail group. Add a harness case in `scripts/test_check_objectscript.py` in which a bare `"READONLY.USER"` outside the allowed files is refused.
- `ui/src/app/core/agent-status.ts`:
  - `Restraint.readOnlyForYou` (default false; narrowed in `restraintOf`; compared in `sameRestraint`).
  - Add `'statusReadOnlyForYou'` to `FOOTER_KEYS` and drop the "not here yet" sentence.
  - Add `setReadOnlyForYou(on): Promise<boolean>`: `PUT` `AGENT_RESTRAINT_PATH`, adopt the answered verdict and notify. On failure the previous verdict stands and it answers false.
- `ui/src/app/shell/read-only-toggle.ts` (new, standalone, OnPush): the switch described in Always, mirroring `AgentStatus` into a signal (AD-19).
- `ui/src/app/shell/panel.ts` and `ui/src/styles/_components.scss`:
  - Wrap the :524 line and `<app-read-only-toggle>` in `div.ocu-panel-read-only-row`, giving the line an id.
  - Add the row's rule after :3515.
  - Add the new switch selector to the context-chip switch rules (:3679-3720) rather than copying them.
- `ui/src/app/areas/agent/definition-form.page.ts`: in Advanced, before Retention, add a checkbox (`ocu-field-checkbox`, id `ocu-definition-read-only`) labeled `STRINGS.agentDefinitionFieldReadOnly`, bound to the buffer's `readOnly` via `store.setFlag` (DW-1621).
- `ui/src/app/core/strings.ts`, add-only:
  - After :230: `agentReadOnlyForYouLabel: 'Read-only for me'` with `/** EXPERIENCE.md:289 */`.
  - After :564: `agentDefinitionFieldReadOnly: 'Read-only'` with `/** EXPERIENCE.md:335 */`.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`, each edited in place:
  - :289 gains `· "Read-only for me"`, and its Where cell says it is the per-user switch beside the line (Story 14.5).
  - :335 gains `· "Read-only"`, and its Where cell says it is the read-only flag inside Advanced, before Retention.
- `ui/browser/preferences-reset.mjs`: `resetRememberedState` also sends `PUT /agent/restraint {readOnly:false}` and asserts 200. Otherwise one spec's leftover toggle would block every later write spec.
- Rosters: update each one in the Code Map. EndpointCoverage gets a `PUT /agent/restraint` row copied from the `PUT /agent/context` row. `ConfigGate` gets the reason "it stores only the calling user's own read-only choice (Story 14.5), which can only restrain further".
- Tests (new):
  - `src/OcuPilot/Test/ReadOnlyForYou.cls` (unarmed):
    - Verdict legs for every matrix row. Include a no-cache leg: set, verdict, clear, verdict in one process.
    - HTTP legs: `PUT`/`GET` round trip, the four bad bodies, `PUT false` under enforced, and the refused `/account/preferences` kind.
    - `OnAfterOneTest` removes, by exact key, every row it wrote (the probe users and `Http.GetTestUsername()`) and asserts none remains.
  - `ui/src/app/shell/read-only-toggle.spec.ts`
  - `ui/browser/read-only-for-you.browser-spec.mjs`
- Tests (added legs):
  - `ToolWrite`: a user with read-only for you is dropped by the real verdict with `AGENT.READONLY.USER`, and nothing is minted.
  - `TurnGrounding`: the context's `readOnly` reads true under read-only for you.
  - `definition-form.page.spec.ts`: the checkbox.
  - `definitions.browser-spec.mjs`: a DW-1621 leg.

**Acceptance Criteria:**

- **AC1.**
  - Given the panel with nothing restraining the agent, when the user turns "Read-only for me" on, then the instance stores the choice and the footer line reads "Read-only: on — for you".
  - Given that state, when a write tool is called for that user, then it returns the blocked result `AGENT.READONLY.USER` and no proposal is minted.
- **AC2.** Given enforced read-only on, when the user presses the switch or sends `PUT {readOnly:false}`, then the switch stays checked and `aria-disabled`, the footer reads "Read-only: on — enforced on this instance", and the verdict is `AGENT.READONLY.ENFORCED`.
- **AC3.**
  - Given the choice set in one browser context, when a fresh context signs in or a separate HTTP client reads `GET /agent/restraint`, then it reads on.
  - Given a user with no row, then it reads off.
  - Given two verdict calls in one process around a change, then each reflects the stored row.
- **AC4.** Given this story's diff, when it is inspected, then `Dispatch`, `Loop`, `Confirm`, `Turn` and `Gate` are unchanged, and `check-objectscript.py` passes with `Restraint.cls` as the only producer.
- **DW-1621.** Given the Definition form's Advanced section, when "Read-only" is checked and saved, then a reload shows it checked and `GET /agent/definitions/:id` reads `readOnly` true.
- **Integration (Rule 1).** Given read-only for you on, when a write tool is dispatched and when a turn is sent with screen context, then the consumers `Dispatch` (the `ToolWrite` leg) and `Turn`'s screen context (the `TurnGrounding` leg) each observe the blocked verdict against a real instance.

### Review Findings

Code review 2026-09-27 (full-opus; blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor). AC1-AC4, DW-1621 and the Integration AC hold; AC4's single check, AD-53/AD-55 and the no-browser-storage rule verified; Rule 3 met by `read-only-for-you.browser-spec.mjs` and the `ReadOnlyForYou` HTTP legs.

- [x] [Review][Patch] high (Rule 6, Conventions › Concurrent writes): a lost conditional save on `PUT /agent/restraint` answered 500, not 409 `STATE.CONFLICT` — now `IsStaleSave` → `RenderConflict`, as `HandleUpdate` does [src/OcuPilot/Api/Switches.cls:362]. No pinning test: the window lies inside `Pref.GuardedSetValue`, unreachable from a request without a production seam (as for `Api.Preferences`).
- [x] [Review][Patch] medium: the switch's redraw on an `AgentStatus` notification (first answer after creation; enforced turning on while open) was untested — two component cases added [ui/src/app/shell/read-only-toggle.spec.ts:85]
- [x] [Review][Patch] medium (Conventions › Tests): the new PUT's HTTP legs asserted no content type — asserted on the 200 and every 422 [src/OcuPilot/Test/ReadOnlyForYou.cls:210]
- [x] [Review][Patch] low (Rule 19): no `mutation:` line for AC1's client press or AC3's client read — both run, recorded under Verification
- [x] [Review][Patch] low: doc comments claimed the switch never shows a press before the answer, called the definition's flag the "fourth source", and credited `KINDRESTRAINT` to Story 15.5 — corrected [ui/src/app/core/agent-status.ts:477, ui/src/app/shell/read-only-toggle.ts:13, ui/src/app/areas/agent/definition-form.page.ts:976, src/OcuPilot/Kernel/State/Pref.cls:22]
- [x] [Review][Patch] low: `ToolWrite` cleared the account's read-only row only after a test, so a row an interrupted browser run left refused every mint — also cleared before [src/OcuPilot/Test/ToolWrite.cls:95]
- Ledgered terminal (by=cr): DW-1738, DW-1739, DW-1746 wontfix-accepted; DW-1740 to DW-1742, DW-1747 wontfix-theoretical; DW-1743 to DW-1745, DW-1748, DW-1749 by-design.
- Rejected: the Review summary's "four `mutation:` lines" count (fix edits this spec); the five-spec browser run (Rule 29: CI runs the full suite); AD-30 read as requiring a step-boundary abandon for the toggle (AD-30 names enforced read-only and the kill switch).

## Spec Change Log

## Review Triage Log

### 2026-09-27 — Review pass

- verdicts: 14 findings — high 0, medium 1, low 6, false 7, maybe-false 0
- findings:
  - `medium` `patch` A read racing a `setReadOnlyForYou` write is untested, so the `newest` assignment and the supersession guard are unpinned — added two interleaving cases to `ui/tools/agent-status.test.mjs`; each guard's removal reddens one.
  - `low` `patch` Integration (`TurnGrounding`), AC1 client footer and AC3 no-row legs had no `mutation:` line — applied each mutation, observed red, reverted, lines added under Verification.
  - `low` `reject` `angular.json` warning raised to 1900kB with a comment citing Story 16.1 — adopted byte-identical to Epic 16's hunk under the standing DW-1166 ruling so the merge is clean; this branch measures 1,857,424 bytes (Auto Run Result).
  - `low` `reject` A GET served before a concurrent PUT commits can leave the switch stale until the next read — needs a read issued inside the PUT's round trip; the next read corrects it, and a fix adds ordering state.
  - `false` `reject` Auto Run Result still reads `ready-for-dev` — finalize writes it.
  - `low` `reject` `angular.json` change not in the contract (intent-alignment) — same as the budget row above.
  - `low` `reject` `panel.spec.ts` edited though Design Notes say it is not — the Tasks' wrapper div changes the footer's children; the fix would edit this spec.
  - `false` `reject` `resetRememberedState` now turns the choice off — required by the Tasks.
  - `false` `reject` `Confirm` gains no test — it calls `Verdict` unchanged; AC4 forbids a second check, and the verdict legs pin the source.
  - `false` `reject` `Loop.Boundary` does not abandon on a mid-turn toggle — the reading Design Notes adopt ("No step-boundary abandon").
  - `false` `reject` another user unchanged is tested in-process only — `HandleRestraintUpdate` writes only `CallerUsername()`'s row; the verdict leg pins the other user.
  - `low` `reject` the 500 path for an unreadable body is not exercised — shared `RenderBadBody`, reachable only by a transport failure the harness cannot produce.
  - `false` `reject` AD-53/AD-55 untested — no screen route calls `Verdict`, and `check-objectscript` keeps restraint codes to `Restraint.cls`/`Error.cls`.
  - `false` `reject` no-browser-storage untested — the diff adds no storage call; the choice travels only over `PUT /agent/restraint`.

## Design Notes

**Governing ADs:** AD-30, AD-40, AD-24 (the `readOnly` member), AD-50, AD-9, AD-19, AD-53, AD-55, AD-39, AD-37, AD-21, and Conventions › Concurrent writes and › When `SCHEMAVERSION` moves. No new AD is needed: AD-30 already places this toggle over Story 3.7's single gate, and AD-50 is the store.

**Measured composition.** The three sources compose only inside `Verdict` today. `Dispatch.Restraint` :63, `Confirm` :273, `Loop.Restraint` :79, `Turn` :80 and `Switches` :305 all call it. So a fourth `If` there reaches every point of effect, and the check-objectscript containment rule keeps it the only producer.

**No step-boundary abandon.** `Loop.Boundary` :317 abandons a turn when *enforced* read-only changes, which is AD-30's wording for the instance switch. When the per-user toggle changes mid-turn, the next write tool call instead returns the blocked result, and `Confirm` refuses any live proposal. That is AD-30's point of effect, with no second check.

**Not audited.** The choice is the caller's own preference (AD-50). Like `PUT /agent/context`, it can only restrain the caller. Switch and hold changes stay audited.

**Precedence (inference).** Enforced, then for you, then by the definition follows the published footer row's order (EXPERIENCE :289), which is what `Restraint.cls` already inferred for enforced over definition.

**Consumed-by:** the existing `Verdict` callers above; Home's agent-status line through `restraintSentence`. **Consumes:** `Kernel.State.Pref` (AD-50), `Kernel.Restraint.Verdict`.

**Contended with Epic 16** (each edit sits off their hunks; see Never): `Error.cls`, `Router.cls`, `Pref.cls`, `panel.ts`, `strings.ts`, `_components.scss`, EXPERIENCE.md and `EndpointCoverage.cls`. `panel.spec.ts` is not edited: the switch's component spec is its own file.

**DW-1621** is addressed by the Definition form task and its AC. Its string is authored at EXPERIENCE :335.

## Verification

Slot B. Copy each changed `.cls` into `/tmp/ocupilot-b-ci/src` and load it on `ocupilot-b-ci`. Only one test run is in flight at a time. Before any browser run, rebuild and `docker cp ui/dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`.

**Commands:**

- `(loop)` Run `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>` for each of `ReadOnlyForYou`, `Restraint`, `SwitchesWire`, `AgentViolation`, `EndpointCoverage`, `ConfigGate`, `ToolWrite`, `TurnGrounding`, `PrefState`, `PreferencesWire` and `Envelope`, one call at a time. Expected: 0 failures each, with totals checked against `%UnitTest_Result`.
- `(loop)` Run `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1` over `browser/read-only-for-you`, `definitions`, `switches` and `panel` (each `.browser-spec.mjs`). Expected: all pass.
- `(loop)` Run `cd ui && npm run test:tools && npm run test:components`, `uv run scripts/check-objectscript.py <changed .cls>`, `uv run scripts/test_check_objectscript.py` and `bash scripts/lint-docs.sh`. Expected: clean.
- `(once, before dev_complete)` Run the full ObjectScript sweep on `ocupilot-b-ci`, one class per call, then `cd ui && npm test && npm run build`, then `a11y-structural-invariants.browser-spec.mjs` (the switch is on every screen), then `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`. Expected: green, with a non-zero count. CI runs the full browser suite (Rule 29).

**Pinning mutations (Rule 19; record each as `mutation: … → …`):**

- **AC1:** delete the for-you branch in `Verdict`. Expected: `ReadOnlyForYou` and `ToolWrite` go red.
- **AC2:** let a stored `"0"` clear `enforcedReadOnly` in `Verdict`. Expected: the `ReadOnlyForYou` enforced-wins leg goes red. Also drop the toggle's `aria-disabled` guard. Expected: the component spec goes red.
- **AC3:** make `GuardedValue` answer a process-private memo. Expected: the no-cache leg goes red.
- **AC4:** add the literal `"READONLY.USER"` to `Dispatch.cls`. Expected: `check-objectscript` goes red.
- **DW-1621:** unbind the checkbox's `(change)`. Expected: `definition-form.page.spec.ts` and the browser leg go red.

- mutation: deleted the for-you `Refuse` branch in `Restraint.Verdict` (throwaway copy, recompiled) → `ReadOnlyForYou` red (4 of 10: `TestOnBlocksThatUserAlone`, `TestForYouWinsOverTheDefinition`, `TestPutStoresAndGetReadsItBack`, `TestTheChoiceIsNeverCachedWithinOneProcess`) and `ToolWrite` red (`TestAUserWithReadOnlyForThemselvesIsDroppedByTheRealVerdict`)
- mutation: a stored `"0"` clears `enforcedReadOnly` in `Restraint.Verdict` → `ReadOnlyForYou` red (`TestEnforcedWins`, `TestPutFalseUnderEnforcedStaysEnforced`)
- mutation: dropped the enforced `preventDefault` guard in `ReadOnlyToggle.onClick` → `read-only-toggle.spec.ts` red (the AC2 case)
- mutation: `Pref.GuardedValue` answers a `^||` process-private memo → `ReadOnlyForYou` red (9 of 10, `TestTheChoiceIsNeverCachedWithinOneProcess` among them)
- mutation: the literal `"READONLY.USER"` added to `Dispatch.cls` → `check-objectscript.py` red at `Dispatch.cls:65`; with the `USER` tail removed from `RESTRAINT_CODE_RE`, `test_check_objectscript.py` red (2 cases)
- mutation: removed the Read-only checkbox's `(change)` binding → `definition-form.page.spec.ts` red (the DW-1621 case) and, rebuilt and redeployed, the `definitions.browser-spec.mjs` DW-1621 leg red
- mutation: deleted the for-you `Refuse` branch in `Restraint.Verdict` (throwaway, recompiled) → `TurnGrounding` red (`TestReadOnlyForYouReadsTrue`), the Integration AC's second consumer
- mutation: `Restraint.ReadOnlyForYou` reads any value but `"0"` as on (throwaway, recompiled) → `ReadOnlyForYou` red (`TestNoRowIsOff` and 3 more), AC3's no-row leg
- mutation: dropped `'statusReadOnlyForYou'` from `FOOTER_KEYS` → `agent-status.test.mjs` red (the footer-key roster and the adopted-verdict case), AC1's client footer
- mutation: dropped `this.newest = run.then(...)` in `setReadOnlyForYou` → `agent-status.test.mjs` red (the overtaken read hangs); dropped the `request !== this.request` guard in `writeReadOnlyForYou` → red (the older write replaces the newer read)
- mutation (QA): dropped the extra-member check (`tExtra ||`) in `Switches.HandleRestraintUpdate` (throwaway copy, recompiled) → `ReadOnlyForYou` red (`TestABadBodyIsRefusedAndNothingIsWritten`: the `{"readOnly":true,"extra":1}` body was accepted and the choice was written); reverted byte-identical, recompiled, green again. The Bad-body matrix row's own doc-comment named this mutation but it had not been demonstrated; it is now.
- mutation (CR): removed the switch's `(change)` binding in `read-only-toggle.ts` → `read-only-toggle.spec.ts` red (the AC1 press case and the refused-write case), AC1's client half
- mutation (CR): `restraintOf` answers `readOnlyForYou: false` → `read-only-toggle.spec.ts` red ("reads on while read-only is on for the caller", AC1) and `agent-status.test.mjs` red (3 cases), AC3's client read
- mutation (CR): dropped the `AgentStatus` subscription in `ReadOnlyToggle`'s constructor → `read-only-toggle.spec.ts` red (the two redraw cases)

## Auto Run Result

Status: done
Blocking condition: none

**Change.** The user's own read-only choice is a `Pref` row (Kind `restraint`, name `readOnly`) and the fourth source `Restraint.Verdict` reads, with code `AGENT.READONLY.USER` and footer key `statusReadOnlyForYou`. `PUT /agent/restraint` stores it for the caller only; the panel gets a "Read-only for me" switch and the Definition form a Read-only checkbox (DW-1621). `Dispatch`, `Loop`, `Confirm`, `Turn` and `Gate` are unchanged.

**Files.**

- Server: `Kernel/Restraint.cls` (fourth source, precedence), `Kernel/State/Pref.cls` (kind, `GuardedValue`), `Api/Error.cls` (two codes), `Api/Switches.cls` (`RestraintBody`, `HandleRestraintUpdate`), `Api/Router.cls` (route).
- Client: `shell/read-only-toggle.ts` (new), `shell/panel.ts`, `core/agent-status.ts` (`readOnlyForYou`, `setReadOnlyForYou`), `areas/agent/definition-form.page.ts`, `core/strings.ts`, `styles/_components.scss`; EXPERIENCE.md :289 and :335 in place (981 lines).
- Gates: `scripts/check-objectscript.py` (`READONLY.USER` tail) and its harness; `ui/angular.json` and `ui/tools/angular-json.test.mjs` (warning 1854kB to 1900kB, Epic 16's hunk byte for byte; this build's initial total 1,857,424 bytes).
- Tests: `Test/ReadOnlyForYou.cls`, `read-only-toggle.spec.ts`, `read-only-for-you.browser-spec.mjs` (new); legs in `ToolWrite`, `TurnGrounding`, `definition-form.page.spec.ts`, `definitions.browser-spec.mjs`, `agent-status.test.mjs`, `preferences-reset.test.mjs`; rosters in `AgentViolation`, `Restraint`, `SwitchesWire`, `EndpointCoverage`, `ConfigGate`, `panel.spec.ts`; `browser/preferences-reset.mjs` turns the choice off per context.

Contended files: EXPERIENCE.md, `Error.cls`, `Router.cls`, `Pref.cls`, `EndpointCoverage.cls`, `strings.ts`, `panel.ts`, `panel.spec.ts`, `_components.scss`, `ui/angular.json`, `ui/tools/angular-json.test.mjs` (the last two identical to Epic 16's hunk).

**Review.** 14 findings: 2 patched (1 medium: two `AgentStatus` interleaving tests; 1 low: four `mutation:` lines), 0 deferred, 12 rejected with reasons in the triage log. Follow-up review recommended: false (patched: high 0, medium 1, low 1).

**Verification.** Full ObjectScript sweep on `ocupilot-b-ci` after a full-package compile: 306 classes, 2541 tests, 0 failed. `npm test` green (1,498 tools, 1,489 components; 1,500 tools after the patch), `npm run build` clean, `check-objectscript` 0 problems, its harness 135 OK, `lint-docs` clean. Browser, bundle redeployed: `read-only-for-you`, `definitions`, `switches`, `a11y-structural-invariants` green; `panel` failed once on the sign-out leg (sign-in surface still up after 30 s) and passed 12/12 alone. `smoke.sh --container ocupilot-b-ci`: 48/48 passed; the account's choice reads off afterwards.

**Residual risk.** A GET served before a concurrent PUT commits can leave the switch stale until the next read (triage log).
