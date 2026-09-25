---
title: 'Story 11.1: "Explain this screen"'
type: 'feature'
created: '2026-09-25'
status: 'ready-for-dev'
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

## Spec Change Log

- 2026-09-25, lead spec gate: no `epics.md` annotation is needed for DW-1077. Story 11.9's AC there reads "they still send no field values or rows", which Home posting its identity only keeps true; the "posts no context at all" wording is 11.9's spec, not the epic's AC.

## Review Triage Log

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
- `onExplain` sends `panel.draft()` → the panel-spec list leg goes red; browser (a) goes red.
- The `route === ''` exclusion is restored in `assembleScreenContext` → `screen-context.test.mjs` Home case and browser (b) go red.
- The empty-route refusal is restored in `ContextViolation` → `TurnGrounding` Home leg (422) and `ScreenGrounding` Home test go red.
- The sharing-off arm is dropped from `explainAriaDisabled` → the panel-spec sharing-off leg and browser (c) go red.
- The explain button is gated on `screen.read !== null` → the panel-spec Home and form-page legs go red.
- The DW-1112 `null` arm is removed → the panel-spec status-0 leg goes red.

**Manual check (extra evidence, never the proof).** Owner's 2026-09-23 live-key rules apply: the key is read from `/Users/jbrandt/git/OcuPilot/.env.local` into one command's environment, never printed or stored, and any credential lives only on `ocupilot-ci` and is removed after. Press Explain on Processes with a live Anthropic definition. The reply should name the screen's purpose, data and actions and cite `osmgmt_processes_read`.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Planned and halted after planning, as the dispatch directed. The ledger inbox is dispositioned: DW-1077 and DW-1112 are addressed; DW-458, DW-460, DW-1001 and DW-1013 are declined in Design Notes. The spec is `oversized`.
