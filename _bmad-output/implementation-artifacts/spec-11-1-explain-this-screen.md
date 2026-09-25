---
title: 'Story 11.1: "Explain this screen"'
type: 'feature'
created: '2026-09-25'
status: 'done'
baseline_revision: '74f8b43e3e3eadc9ac7dedfb3415e4f2eea0d1ef'
baseline_commit: '74f8b43e3e3eadc9ac7dedfb3415e4f2eea0d1ef'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-11-context.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The panel has no one-click way to ask what the current screen is. `STRINGS.agentExplainScreenAction` ("Explain this screen", EXPERIENCE.md:268) exists but nothing renders it. On Home a turn carries no screen context at all, because the server refuses Home's empty route, so an explain turn there could not name the screen (DW-1077).

**Approach:** Put an "Explain this screen" button under the context chip. One click sends that fixed sentence as an ordinary user turn with the screen's context, and leaves the draft alone. Add one sentence to the built-in prompt constant: explain the screen, name the read tool in `tools` that its data comes from, and propose no change. Let Home's turn carry its identity (route `""`). Drop the panel's duplicate banner on a Send that never reached the instance (DW-1112).

## Boundaries & Constraints

**Always:**

- The message sent is exactly `STRINGS.agentExplainScreenAction`, as the user role. It never goes into the system prompt, and the draft is never touched (AD-11 rule 1).
- The prompt stays one ASCII build-time constant. The new sentence is the golden text in Design Notes, inserted directly after "Use only the tools you are offered, ... a capability you lack." and before "Answer briefly and plainly.".
- The explain turn uses the Send path's own call, `TurnStore.send(text, this.assembleContext())`. On `'sent'` it cancels live cards `canceled-by-message` and follows the newest entry, as Send does.
- The button renders exactly when the context chip does (`contextChipVisible`), so it shows on every built screen.
  - `aria-disabled="true"` when the composer is unavailable, a turn is running, or sharing is off. `aria-describedby` names the topmost reason: kill switch, then busy, then the chip's sharing-off sentence.
  - A click while `aria-disabled` sends nothing.
- `ContextViolation` still requires `route` to be a string. Only the empty-string refusal goes, and `""` resolves to Home through the registry.
- Streaming (11.7), the privilege line (11.8) and 11.10's follow rule are unchanged.

**Never:**

- No citation chips and no reply-rendering change (Story 11.4).
- No new user-visible string and no `strings.ts` edit.
- No gate on writes: an explain turn that proposes still mints a card that needs Confirm (AD-6).
- No edit to Epic 12's hunks in `panel.ts` (the reply appenders, `PanelWriteCard`) or `panel.spec.ts` (`:3382-3395`).
- No live key in any test.
- No work on DW-458, DW-460, DW-1001 or DW-1013 (see Design Notes).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| List screen | `os-management/processes`, share on, draft "keep me" | the user bubble reads "Explain this screen" and `POST /turn` carries that message plus the screen's context. The recorded `screen_context` has `tools[0]` `osmgmt_processes_read`, the recorded `system` carries the explain sentence, and the draft still reads "keep me" | none |
| Home (DW-1077) | `/?ns=HSCUSTOM` | posts `{route: "", namespace}` with no `view`. The payload is `screen` `shell.home`, `tools` `[]`, `readOnly` a boolean, `rowsSent` 0. The chip's "Home, HSCUSTOM" is now what the turn sends | none |
| Form page | `agent/definitions/edit` (identity only) | the button shows, and the turn posts identity only with `tools` `[]` | none |
| No screen | unknown URL, or no enabled definition | no button (the chip's gate) | none |
| Sharing off | the chip toggle is off | `aria-disabled`, described by the chip's sharing-off sentence; a click posts nothing | none |
| Busy / kill switch | a turn is running, or the kill switch is on | `aria-disabled`, described by the busy reason or the kill-switch banner; a click posts nothing | none |
| Live proposal | a card is live | the explain turn cancels it: "Canceled — by your message" | none |
| Refused send | 422 with an envelope | the panel banner shows the envelope's `reason`, as today | unchanged |
| Unreachable (DW-1112) | status 0, or 5xx with no envelope | no `[data-slot="send-error"]`; the shell's connectivity banner is the one alert | the draft is kept |
| 4xx with no envelope | 403, 404 or 422, reason `null` | the panel keeps its `connectivityServerFault` fallback | unchanged |

</intent-contract>

## Code Map

- `src/OcuPilot/Kernel/Agent/Prompt.cls` -- `BUILTIN` and its doc comment. `TurnLoop:140`, `TurnTools:268` and `TurnWire:145` compare against `Builtin()` whole, so they follow the constant unedited.
- `src/OcuPilot/Test/ScreenGrounding.cls` -- `Statement(n)` `:19-29`, and `TestThePromptCarriesTheScreenStatements` `:44`, which asserts each statement once.
- `src/OcuPilot/Test/TurnGrounding.cls`:
  - `RecordedContext` `:100` answers the `screen_context` payload;
  - `TurnProvider.Recorded(TAG, 1, "system" | "messages")` gives the raw request;
  - `ProcessContext` `:119`.
  - Already armed in `scripts/ci-throwaway.sh`, so new methods need no arming line.
- `src/OcuPilot/Api/Turn.cls:448` -- the `route` check in `ContextViolation`.
  - `BoundedContext` `:499` → `Screen.Context.Build` → `DescriptorForRoute`.
  - Probed read-only on `ocupilot-ci`: `DescriptorForRoute("")` is `OcuPilot.Screen.Descriptor.Home`; `ScreenTools` gives `[]`; `Build` gives `{"screen":"shell.home","route":"",...,"rows":[]}`.
  - `Kernel/Agent/Loop.ContextRoute` already treats `""` as Home's (`LedgerEmptyPairs:162`).
- `ui/src/app/core/screen-context.ts:128-139` -- `assembleScreenContext` returns `null` for `route === ''`. `ui/tools/screen-context.test.mjs:93` pins that.
- `ui/src/app/shell/panel.ts`:
  - chip slot `:314-318`;
  - `describedBy` `:782`; `sendErrorText` `:816-826`;
  - `contextChipVisible` `:1555`; `sendCurrentDraft` `:1629`; `assembleContext` `:1656`;
  - the busy reason `<span>` `:500`.
  - Epic 12's hunks sit at `:149-152`, `:868-882`, `:1014-1070` and `:1162`.
- `ui/src/app/shell/context-chip.ts:59` -- the sharing-off `<span>`, which has no id yet.
- `ui/src/app/shell/panel.spec.ts`:
  - `mount` `:139`;
  - Story 4.11's chip-visible pattern `:1475` (`stubAgentContext({share})`, `url`, `screenStores`);
  - `mountWithProposals` `:2705`;
  - the two Story 4.8 fallback tests `:839-880`.
- `ui/src/app/core/fault.ts` -- `classifyFault` `:69` and `isBannerFault` `:102`. `fault-banner.ts` is the shell's connectivity banner.
- `ui/browser/screen-grounding.browser-spec.mjs` -- the pattern to copy:
  - `armProbeDefinition`, `scriptReply`;
  - `recordedMessages` and `screenContextPayload`;
  - `putShare`.
- `ui/browser/turn.browser-spec.mjs:378-379` -- asserts a Home turn records exactly one message, which is false once Home sends context (share defaults on, `Switch.DEFAULTSHARECONTEXT` 1).
- EXPERIENCE.md (`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/`) -- `:268` is the string row, which is already there. `:589` is the panel's **Body.** paragraph.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Kernel/Agent/Prompt.cls` -- Insert the golden sentence at the Always position. Update the doc comment's sentence counts.
- `src/OcuPilot/Api/Turn.cls` -- In `ContextViolation`, refuse a non-string `route` but accept `""`. Update the doc comment to say `""` is Home's route.
- `src/OcuPilot/Test/ScreenGrounding.cls` -- Changes:
  - Add `Statement(7)` (the golden sentence) and its assertion "the explain statement". The header now says seven statements.
  - Add `TestHomesEmptyRouteIsAccepted`. `ContextViolation` accepts `{route: "", namespace: <current>}` and refuses `route` 5. `BoundedContext` for Home gives `screen` `shell.home`, `tools` `[]` and a boolean `readOnly`.
- `src/OcuPilot/Test/TurnGrounding.cls` -- Add two methods:
  - `TestAnExplainTurnCarriesTheReadToolAndTheStatement`: for "Explain this screen" with `ProcessContext()`, `tools[0]` is `osmgmt_processes_read`, recorded `system` contains `ScreenGrounding.Statement(7)`, and the last user message's text is the message.
  - `TestHomesContextReachesTheTurn`: the matrix Home row, over the wire.
- `ui/src/app/core/screen-context.ts` -- Drop the `route === ''` exclusion and update the doc comment.
- `ui/tools/screen-context.test.mjs` -- Change the Home case: it now posts `{route: '', namespace}` with no `view`.
- `ui/src/app/shell/context-chip.ts` -- Export `CONTEXT_CHIP_OFF_ID` and set it as the sharing-off `<span>`'s `id`.
- `ui/src/app/shell/panel.ts` -- Changes:
  - Inside the chip slot's `@if (contextChipVisible)`, after the chip, add `<button type="button" class="ocu-button-text ocu-panel-explain" data-slot="explain">` labeled `STRINGS.agentExplainScreenAction`, with `explainAriaDisabled` and `explainDescribedBy` getters.
  - Add `onExplain()`, which runs the Always send. Share the post-send block with `sendCurrentDraft` through a private helper.
  - DW-1112: `sendErrorText` answers `null` when the refusal has no `reason` and `isBannerFault(classifyFault(...))`.
- `ui/src/app/shell/panel.spec.ts`:
  - Append `describe('Story 11.1: Explain this screen')` covering the matrix rows from List screen to Live proposal.
  - Rewrite the two Story 4.8 fallback tests (status 0 and 502) to expect no `[data-slot="send-error"]`, and add a 403-with-no-envelope leg that keeps the fallback.
- `ui/browser/explain-screen.browser-spec.mjs` (new) -- Three legs:
  - (a) the List-screen row, with a scripted reply naming `osmgmt_processes_read`, which renders verbatim;
  - (b) the Home row;
  - (c) the sharing-off row, with share restored in `after`.
- `ui/browser/turn.browser-spec.mjs` -- Replace `:378-379` with: no recorded entry carries "first turn", and the final user entry's text is "second turn, new conversation".
- EXPERIENCE.md -- On `:589` (**Body.**), in place at the end of the paragraph, append: `Beneath the context-chip, "Explain this screen" (button-text) sends that sentence as the user's next message with the screen's context, leaving the draft as it is; it shows wherever the chip does and is aria-disabled while the agent is off, while a turn runs, or while screen context is off, described by that reason [ADDED 2026-09-25 - Story 11.1].`

**Acceptance Criteria:**

- **AC1.** Given any built screen with a definition enabled, when the user presses "Explain this screen", then one turn is sent with that message and the screen's context, and the prompt instructs the model to name the screen's purpose, data and actions.
  - Pinned by the panel spec, `ScreenGrounding`, `TurnGrounding` and browser (a).
- **AC2.** Given the explain turn, when its request is recorded, then its `screen_context` names the screen's read tool in `tools`, the one read the screen made (AD-36), and the prompt tells the model to name it.
  - A reply that names it renders verbatim (browser (a)).
  - The model's own compliance is not CI-provable; the live check is extra evidence only.
- **AC3.** Given Home, a list and a form page, when the panel renders, then the button is there, one click, under the same gate as the chip, which no screen's declaration changes; on Home the turn carries Home's identity (browser (b)).
- **AC4.** Given the AD-11/AD-24 pins (`ContextBound`, `TurnContext`, `TurnLoop`, `TurnTools`, `TurnWire`, `TurnNavigate`), when they run, then they stay green unedited.

### Review Findings

Code review 2026-09-25, `full-opus`, four layers. 25 findings: 6 patched (1 med, 5 low), 0 deferred, 0 decision-needed, 19 rejected.

- [x] [Review][Patch] (med) The relaxed empty route was pinned only in its bare form; nothing reddened if Home skipped the namespace or view bounds [src/OcuPilot/Test/ScreenGrounding.cls:136] — added Home legs: a foreign namespace and a non-array `rows` are refused, and a row sent on Home reaches the payload with no field value.
- [x] [Review][Patch] (low) `RoutePairs`' doc said no turn carries an empty route and that Home posts no context, which this story made false [src/OcuPilot/Kernel/Audit/Ledger.cls:80]
- [x] [Review][Patch] (low) The unavailable button faded to `opacity: 0.55`, which matches neither DESIGN.md's 38% nor the `restrained` treatment the command bar's unavailable actions use [ui/src/styles/_components.scss] — now `color: var(--ocu-restrained)` at full opacity.
- [x] [Review][Patch] (low) The style block sat inside Story 4.11's context-chip section [ui/src/styles/_components.scss] — moved to follow that section as its own block.
- [x] [Review][Patch] (low) Browser legs (a) and (b) clicked as soon as the button showed, while it can still be `aria-disabled` during load [ui/browser/explain-screen.browser-spec.mjs:346] — they now wait for it to be available, as `context-chip.browser-spec.mjs:315` does for the composer.
- [x] [Review][Patch] (low) `ContextViolation`'s doc ran three rules together [src/OcuPilot/Api/Turn.cls:428]

Rejected:

- `false` The "Live proposal" leg under the null-context mutation stays green — applied in review: 4 legs red including it, since the mutation bypasses `sendWithContext`'s cancel.
- `false` `turn.browser-spec` "no earlier turn" is too loose — an earlier turn cannot reach history without its "first turn" user entry.
- `false` `TurnGrounding` explain leg breaks on string `content` — with context the last user entry is an array; a string would error the test, not pass it.
- `false` Browser leg (c)'s 1500 ms wait can miss a late send — the disabled guard returns synchronously; no deferred send path exists.
- `false` DW-1112's null leaves no trace once the shell banner clears — that banner is the one alert the merge gate asked for; Send keeps the draft.
- `false` The paste warning stays up during an explain turn — it concerns the draft, which explain leaves; a second send while busy raises the lock banner by design.
- `false` Home and no-context turns now differ on the wire but share `""` in the ledger — they shared it before too; the doc is corrected above.
- `false` DW-1077/DW-1112 not updated in the ledger — adjudication is the lead's gate.
- `false` QA's tests are uncommitted — the lead commits them with this pass.
- `low` Aria-disabled with no reason while navigation loads — the composer shares the window; transient, and a fix adds a branch (same call as the implement review).
- `low` `EXPLAINMESSAGE` can drift from `STRINGS` — browser (a) pins the real string end to end.
- `low` Panel-spec gaps (re-enable on sharing on, a refused explain, 5xx draft kept) — the shared Send path and signal reactivity are pinned elsewhere.
- `low` `before`/`after` force `share: true` — the instance default is on; `screen-grounding` restores the same way.
- `low` `TurnGrounding`'s echo assertions pin 11.9 behavior — its 11.1 assertion carries run 12420's mutation.
- `low` `Prompt.cls` doc groups the explain sentence with the `screen_context` statements and `Statement(7)` precedes 6 in the prompt — no reader is misled into a behavior.
- spec-bound: sharing off disables explain on every screen, narrowing epics.md's "every screen" — the spec's Always rule; explain with no screen is meaningless.
- spec-bound: EXPERIENCE.md sentence formatting and tag — the text is the spec's verbatim task.
- spec-bound: AC2's render leg is pass-through evidence — the spec already says so.
- duplicate: `answered` window reported by two layers (counted once above).

## Spec Change Log

- 2026-09-25, lead spec gate: no `epics.md` annotation is needed for DW-1077. Story 11.9's AC there reads "they still send no field values or rows", which Home posting its identity only keeps true; the "posts no context at all" wording is 11.9's spec, not the epic's AC.

## Review Triage Log

### 2026-09-25 — Review pass

- verdicts: 14 findings — high 0, medium 0, low 4, false 10, maybe-false 0
- findings:
  - `[low]` `[patch]` Busy leg's "click posts nothing" holds by `TurnStore`'s own refusal, not the panel guard — added a no-lock-banner assertion; narrowing the guard to sharing reddens it.
  - `[low]` `[patch]` `explainDescribedBy`'s topmost-reason order unpinned — added "Kill switch with sharing off"; putting sharing first reddens it alone.
  - `[low]` `[patch]` AC2's context leg, AC3's gate and AC4 had no `mutation:` line — AC2 and AC3 applied red and reverted, recorded in `## Verification`; AC4 has none applicable; AC2's render leg is 11.7's unchanged path.
  - `[false]` `[reject]` `turn.browser-spec` "carries no earlier turn" weakened — the spec's task prescribes that replacement, forced by Home now sending context.
  - `[false]` `[reject]` DW-1112's one alert is untested at the shell — `main.ts:95` feeds every `requestJson` fault, `POST /turn` included, to `ConnectivityService`.
  - `[false]` `[reject]` DW-1112 goes wider than 5xx — `isBannerFault` is exactly the set the shell banner publishes, so each such fault still raises one alert.
  - `[false]` `[reject]` Prompt placement unpinned — the one literal holds the sentence at the specified position; moving it harms no user.
  - `[false]` `[reject]` No-definition case of "No screen" untested — the button shares the chip's `@if`, whose `configured()` arm the 4.11 chip tests pin.
  - `[false]` `[reject]` Another tab's lock is outside the gate — Send is gated the same way; the lock banner is the designed answer.
  - `[low]` `[reject]` While navigation is still loading the button is `aria-disabled` with no reason — a transient load window the composer shares; a fix adds a branch for no everyday harm.
  - `[false]` `[reject]` `turn.browser-spec` weakening (second report) — same prescribed replacement as above.
  - `[false]` `[reject]` Form-page `tools []` unpinned server-side — `ScreenGrounding:85` pins it.
  - `[false]` `[reject]` `followNewest` now runs before `setDraft('')` — `follow()` scrolls synchronously and sets following; the composer shrinking only enlarges a bottom-anchored box; panel browser legs green.
  - `[false]` `[reject]` EXPERIENCE.md and SCSS changes outside scope — the EXPERIENCE sentence is a spec task; the SCSS dims the `aria-disabled` state (footprint extension).

## Design Notes

**Governing ADs:**

- AD-11: rule 1 (a fixed user message plus a prompt-constant sentence), rule 4 (rendering untouched).
- AD-24 (as amended by 11.9): `tools` and `readOnly` are what the citation rests on; Home now sends identity.
- AD-36: one read, so naming the read tool traces to the screen's read.
- AD-5: the button resolves the screen through the mirror, never a per-screen list.
- AD-19: the pure `core/` change.
- AD-7 and AD-33: an ordinary turn job, streamed as 11.7 left it.
- AD-39: DW-1112 keeps the envelope's reason.
- AD-30 and AD-6: "propose no change" is prompt guidance, not a gate.
- No AD changes.

**Golden sentence** (ASCII, pinned verbatim as `Statement(7)`):

```text
When the user asks you to explain this screen, say what the screen is for, what data it shows and what actions its tools offer, name the read tool in tools that its data comes from, or say that it has none, and propose no change.
```

**Why a prompt sentence and not a longer message.** The user bubble and the published string stay "Explain this screen". The sentence reaches every screen with no second context channel. A definition override replaces the prompt whole (AD-11), so the explain turn then reads as the user's plain question.

**Wire name, not dotted name.** The model sees the provider-safe names in `tools` (Conventions › Tool naming), so the citation names exactly what the request carried.

**Placement.** The chip row is the one panel region present on every screen and in every panel state. EXPERIENCE.md's greeting and starter prompts show only while idle and empty, and 11.3's suggested prompts will join them there. A persistent control beside the chip collides with neither.

**DW-1077 resolved by the turn side.** AC1 and AC3 on Home need Home's identity to reach the model, and once it does the chip's "Home, HSCUSTOM" is what the turn sends. This supersedes 11.9 AC4's clause "Home posts no context at all". Home still posts no field or row. Recommended apply-and-report annotation for the lead on that 11.9 bullet in `epics.md`: "Home posts its identity only (Story 11.1, DW-1077)".

**DW-1112, first face only.** Per the merge-gate note, one status-0 Send raises one alert. The second face (a 4xx with no envelope reads as a server fault) is theoretical under AD-12, since every `/turn` refusal carries an envelope. Its fallback is kept, so it still raises exactly one alert.

**Ledger inbox:** DW-1077 and DW-1112 are addressed (matrix rows Home and Unreachable).

- Declined DW-458: panel-layout width rule in `panel-layout`, not on the explain path; a medium-risk layout change in a file this story does not touch.
- Declined DW-460: needs a product choice between ignoring the rail click and exiting full screen, which the note leaves open; `rail.ts` is not touched.
- Declined DW-1001: needs a descriptor-declared criterion-description mechanism across `Screen/Tool/Read.cls`, the registry and the mirror; not floor-blocking.
- Declined DW-1013: the same mechanism as DW-1001. Array fields never reach screen context (`Build` drops them), so explain is not misled by `[]`.

**Integration ACs:** no service is introduced; this story is a consumer.

- **Consumes:** 11.9's `tools` and `readOnly`, 4.11's `assembleScreenContext` and chip, 4.5's `TurnStore.send`, 11.7's reply render, 11.10's follow. The consumer ACs run against the throwaway: `TurnGrounding` and browser (a) and (b).
- **Consumed-by:** 11.4 (chips may later replace the plain-text tool name) and 17.7 (the owner's live check).

**footprint_extensions:**

- Contended, staying off Epic 12's hunks: `panel.ts`, `panel.spec.ts`.
- Shared: EXPERIENCE.md, one in-place sentence with no line shift.
- Outside Epic 11's footprint: `context-chip.ts` (an id); `turn.browser-spec.mjs` (one leg, forced by the Home change).

## Verification

**Slot and instance.**

- Slot A. Every IRIS MCP call carries `server: "ocupilot-slot-a"`.
- Stateful checks run only on `ocupilot-ci` (52776/1975). Never touch `ocupilot`, `ocupilot-slot-*` or `ocupilot-b-ci`.
- Load and recompile with `bash /tmp/epic-11-lead/load.sh` (`LOADRESULT`, `ERRCOUNT`).
- Browser runs: `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci` exported.

**Commands:**

- `uv run scripts/check-objectscript.py && bash scripts/lint-docs.sh` -- expected: clean.
- **(loop)** Run each of `ScreenGrounding`, `TurnGrounding`, `ContextBound`, `TurnContext`, `TurnLoop`, `TurnTools`, `TurnWire`, `TurnNavigate` and `LedgerEmptyPairs` with `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one per call. Expected: green, confirmed by the `%UnitTest_Result` probe, never re-submitted.
- **(loop)** `cd ui && npm run test:tools && npm run test:components` -- expected: green.
- **(loop)** `cd ui && node --test --test-concurrency=1 browser/explain-screen.browser-spec.mjs browser/turn.browser-spec.mjs browser/context-chip.browser-spec.mjs browser/screen-grounding.browser-spec.mjs browser/panel.browser-spec.mjs` -- expected: green against the redeployed bundle.
- **(once, before dev_complete)** The full ObjectScript sweep on `ocupilot-ci`, one class at a time, then `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS`. Report it as "N ran, 13 refused (arming), 1 known residue". The full browser suite runs in CI only.

**Pinning mutations (Rule 19).** Apply each, recompile or rebuild and redeploy, observe red, revert, and confirm `git status --short` is unchanged. Record `mutation: ... -> ...` under each.

- The explain sentence is deleted from `BUILTIN` → `ScreenGrounding` "the explain statement" goes red alone; `TurnGrounding`'s explain leg goes red.
  - mutation: explain sentence deleted from `BUILTIN`, recompiled -> `ScreenGrounding.TestThePromptCarriesTheScreenStatements` "the explain statement" red alone (run 12419); `TurnGrounding.TestAnExplainTurnCarriesTheReadToolAndTheStatement` red (run 12420).
- `onExplain` sends `panel.draft()` → the panel-spec list leg goes red; browser (a) goes red.
  - mutation: `onExplain` sends `this.panel.draft()` -> panel-spec "List screen" leg red; rebuilt and redeployed, browser (a) red on the user bubble ("keep me"), (b) red too (empty draft sends nothing).
- The `route === ''` exclusion is restored in `assembleScreenContext` → `screen-context.test.mjs` Home case and browser (b) go red.
  - mutation: `|| inputs.descriptor.route === ''` restored -> `screen-context.test.mjs` Home case red; rebuilt and redeployed, browser (b) red ("Home posts a screen_context pair").
- The empty-route refusal is restored in `ContextViolation` → `TurnGrounding` Home leg (422) and `ScreenGrounding` Home test go red.
  - mutation: `|| (tContext.%Get("route") = "")` restored, recompiled -> `ScreenGrounding.TestHomesEmptyRouteIsAccepted` red (run 12421); `TurnGrounding.TestHomesContextReachesTheTurn` red on 422 `TURN.CONTEXT.INVALID` (run 12422).
- The sharing-off arm is dropped from `explainAriaDisabled` → the panel-spec sharing-off leg and browser (c) go red.
  - mutation: `|| !this.agentContext.share()` dropped -> panel-spec "Sharing off" leg red; rebuilt and redeployed, browser (c) red (aria-disabled never "true").
- The explain button is gated on `screen.read !== null` → the panel-spec Home and form-page legs go red.
  - mutation: button wrapped in `@if` on `screenForUrl(url)?.read != null` -> panel-spec "Home" and "Form page" legs red.
- The DW-1112 `null` arm is removed → the panel-spec status-0 leg goes red.
  - mutation: `if (isBannerFault(fault)) return null;` removed -> panel-spec status-0 and 5xx legs red; answering `null` for every no-envelope refusal -> the 403 leg red.
- AC2, the context leg: `onExplain` calls `this.turn.send(STRINGS.agentExplainScreenAction, null)`.
  - mutation: that call -> panel-spec "List screen", "Home", "Form page" and "Live proposal" legs red.
- AC3, the chip's gate: the button moved outside `@if (contextChipVisible)`.
  - mutation: that move -> panel-spec "No screen" leg red.
- The busy and kill-switch guard in `onExplain` is narrowed to sharing only.
  - mutation: `if (!this.agentContext.share()) return;` -> panel-spec "Busy" leg red on the lock banner, and "Kill switch" red.
- The reasons' order: the sharing-off arm moved first in `explainDescribedBy`.
  - mutation: that move -> panel-spec "Kill switch with sharing off" leg red alone.
- AC4 has no mutation: its pins are the unedited `ContextBound`, `TurnContext`, `TurnLoop`, `TurnTools`, `TurnWire` and `TurnNavigate`, green in the sweep.
- Home keeps the namespace and view bounds (review): `If tContext.%Get("route") = "" Quit ""` after the route type check.
  - mutation: that line, recompiled -> `ScreenGrounding.TestHomesEmptyRouteIsAccepted` red on "Home in another namespace is refused" and "Home with rows that are not an array is refused" alone (run 12684); reverted, green (run 12685).

**Manual check (extra evidence, never the proof).** Owner's 2026-09-23 live-key rules apply: the key is read from `/Users/jbrandt/git/OcuPilot/.env.local` into one command's environment, never printed or stored, and any credential lives only on `ocupilot-ci` and is removed after. Press Explain on Processes with a live Anthropic definition. The reply should name the screen's purpose, data and actions and cite `osmgmt_processes_read`.

**QA-stage additions (AC3 gap closure).** The legs above sample List, Home and Form page; no test
walked the full registry, so a gate that happened to exclude an untested archetype (e.g. `detail`)
would have passed unnoticed. Added `ui/src/app/shell/panel.spec.ts` (QA) "AC3: every built screen
shows the explain button under the same gate as the chip (registry-driven)", iterating
`SCREENS.filter(s => s.built && s.route !== '')` (52 screens; Home is the dedicated leg above).
Also added `ui/src/app/shell/panel.spec.ts` (QA) "Busy with sharing off", closing the one untested
pairwise ordering in `explainDescribedBy` reachable through the UI (kill switch and busy cannot
co-occur: the kill switch disables the composer, so no turn can be in flight while it is on).

- mutation: wrap the button in a nested `@if` excluding `archetype === 'detail'` -> the new
  registry test goes red alone, naming the first failing descriptor
  (`OcuPilot.Screen.Descriptor.DatabaseDetails`); all 145 other legs, including List/Home/Form
  page, stay green -- the gap a sample cannot see. Reverted; `git diff` on `panel.ts` empty.
- mutation: swap the `busy` and sharing-off checks in `explainDescribedBy` -> "Busy with sharing
  off" goes red alone (`describedBy` resolves to the sharing-off sentence instead of the busy
  reason); the 145 other legs stay green. Reverted; `git diff` on `panel.ts` empty.

Checked, not duplicated: DW-1112's "one alert" claim. `ui/src/main.ts` wires `onFault` once, at
`ApiService` construction; `ApiService.requestJson` (`api.ts:396-398`) calls it for every
non-`ok` result regardless of path, so `POST /turn` gets no special case. That crossing is already
proven generically by `ui/tools/refresh-connectivity.wire.test.mjs` against a real `ApiService` +
`ConnectivityService` pair; a turn-specific integration test would re-prove an architectural
invariant this story does not touch, which the story's own review already rejected as a finding on
that reasoning.

`test:components`: 1264/1264 after this pass (was 1261/1261 in Auto Run Result; +2 QA legs, +1
already in the tree from elsewhere in the epic). `test:tools`: 1433/1433, unchanged.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** Beneath the context chip there is now an "Explain this screen" button. It sends that fixed sentence through the Send path, with the screen's context, and leaves the draft as it is. The built-in prompt gains the explain sentence, pinned as `Statement(7)`. Home posts its identity (`route ""`), which the client now sends and the instance now accepts. The panel raises no second banner for a status 0 or 5xx that has no envelope (DW-1112).

**Files changed:**

- `Kernel/Agent/Prompt.cls`: the sentence.
- `Api/Turn.cls`: `""` accepted as a route.
- `Test/ScreenGrounding.cls` and `Test/TurnGrounding.cls`: the new legs.
- `core/screen-context.ts` and `tools/screen-context.test.mjs`: Home posts its identity.
- `shell/context-chip.ts`: the off id.
- `shell/panel.ts`: the button, its getters, `onExplain` and the shared `sendWithContext`, and DW-1112.
- `shell/panel.spec.ts`: the 11.1 legs and the 4.8 rewrite.
- `browser/explain-screen.browser-spec.mjs` (new) and `browser/turn.browser-spec.mjs`.
- `styles/_components.scss`: the disabled look.
- EXPERIENCE.md: `:589`.

**Review.** 14 findings: 3 low were patched (the busy-leg lock-banner assertion, the two-reason order leg, and the mutation lines), 1 low was rejected and 10 were false. Nothing was deferred. `followup_review_recommended: false`, because no medium or high was patched.

**Verification:**

- `check-objectscript` reported 0 problems and `lint-docs` 0 issues.
- `test:tools` passed 1433/1433 and `test:components` 1261/1261. After the patches, `panel.spec` passed 144/144.
- The story's browser specs (`explain-screen`, `turn`, `context-chip`, `screen-grounding`, `panel`) passed 34/34 against the rebuilt and redeployed bundle.
- ObjectScript sweep on `ocupilot-ci`: 254 ran, 13 refused (arming), 1 known residue (`WireSecurityRead` task-history). The other 240 were green, including ScreenGrounding 11/11, TurnGrounding 9/9, and every AC4 pin.
- Smoke on `ocupilot-ci`: 49/49.
- Initial bundle total: 1,597,260 bytes (1.60 MB), under the 1670 kB warning.
- The live-key check was not run; it is extra evidence only.

**Residual risk.** Home now opens every turn with a `screen_context` pair. Other browser specs that start on Home are covered only by CI's full browser run.

**footprint_extensions:**

- `ui/src/app/shell/panel.ts` and `ui/src/app/shell/panel.spec.ts`: contended, and none of Epic 12's hunks were touched. `merge-tree` against `origin/OCU-1-epic12` adds no conflict.
- `ui/src/app/shell/context-chip.ts`.
- `ui/src/styles/_components.scss`: shared-append, own block.
- EXPERIENCE.md: one in-place sentence.
- `ui/browser/turn.browser-spec.mjs`.
