---
title: 'Story 11.10: A judge succeeds the first time'
type: 'feature'
created: '2026-09-24'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-11-context.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['multiple-goals', 'oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** A new definition is created read-only, so a first-time user's first request for a change is declined. The agent does not open the screen under discussion unless told to. The panel's transcript never scrolls, so a sent message and its answer can land out of sight.

**Approach:** Flip the default for newly created definitions to read/write, in the stored class default and in the form's initial values. Nothing rewrites a stored value. Add one statement to the built-in prompt: open the screen under discussion first when the user is not on it. Make the transcript follow the conversation while it is at its newest entry. When the user has scrolled up, leave it where it is and offer **Jump to latest**.

## Boundaries & Constraints

**Always:**

- A definition created through the API (`POST /agent/definitions`), the form or `%New()` without `readOnly` stores `ReadOnly` 0. A body that sends `readOnly: true` still stores 1. Every write still needs confirmation. AD-10's prohibited set, enforced read-only, the kill switch and `Kernel.Restraint.Verdict` are unchanged.
- `Prompt.BUILTIN` stays one printable-ASCII constant that nothing composes (AD-11 rule 1). The new statement is appended after the navigation sentence, and every existing sentence stays verbatim.
- The follow rule has one predicate. The transcript is **at its newest entry** when `scrollHeight - scrollTop - clientHeight <= 4` CSS px (`FOLLOW_TOLERANCE_PX = 4`, absorbing sub-pixel rounding at browser zoom).
- An accepted send (Send, Enter, Send anyway or Re-propose) turns following on and scrolls to the newest entry.
- While following, every render that adds or grows an entry (a progress step, a reply, a proposal card, an error banner) scrolls to the newest entry.
- Only a scroll the user makes away from the newest entry turns following off. The panel's own scrolls, including a smooth scroll's intermediate positions, never turn it off.
- Following starts on, and New conversation turns it on. A transcript restored on reload opens at its newest entry.
- **Jump to latest** shows while the transcript holds at least one turn and is not at its newest entry. It sits outside the `role="log"` element, between the transcript and the footer, and never overlays the composer. Pressing it scrolls to the newest entry, turns following on and moves focus to the transcript. It goes away once the newest entry is in view, whether reached by the button or by the user's own scroll.
- Scroll animation is decided in CSS by the existing reduced-motion idiom: `scroll-behavior: smooth` on `.ocu-panel-transcript`, and `auto` under `@media (prefers-reduced-motion: reduce)`. Scripts never pass a `behavior` of their own.
- Tokens only, no color literals. Non-ASCII is written as `\uXXXX`. The control uses an existing button class, its accessible name is its text, and it is at least 24 x 24 CSS px.
- Every stateful check runs on `ocupilot-b-ci`, with one test class per runner call.

**Never:**

- No migration, upgrade step, SQL `UPDATE` or installer or fixture write touches a stored `ReadOnly`. `SCHEMAVERSION` does not move.
- No edit to `Api/Definitions.cls`, `Kernel/Restraint.cls`, `Screen/Tool/Navigate.cls`, `core/turn.ts` or `core/screen-context.ts`.
- No new error code and no user-visible string other than "Jump to latest".
- No scroll moves focus, except Jump to latest, which hands it to the transcript.
- No live model, no key and no `.env.local`. No test runs on slot B's dev instance.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| API create, flag omitted | `POST` with no `readOnly` | 201, `readOnly` false, verdict not blocked | none |
| API create, flag set | `readOnly: true` | stored 1, verdict blocked with the definition code | none |
| Quoted flag on update | stored 1, `PUT {"readOnly":"false"}` | 200, still 1 (the value is ignored, not coerced) | none |
| Form create | new-definition route, flag untouched | the POST body carries `readOnly: false` | none |
| Stored read-only kept | stored 1, then `Installer.Install("")`, then fresh read | still 1, and a stored 0 is still 0 | none |
| Send while scrolled up | the user has scrolled away, send accepted | following on, scrolled to the newest entry | refused or locked send: no scroll |
| Arrival while following | distance 4 px, reply arrives | scrolled to the newest entry, no control | none |
| Arrival while scrolled up | distance 5 px, reply arrives | `scrollTop` unchanged, Jump to latest shown | none |
| Jump pressed | control focused | at the newest entry, control gone, focus on the transcript | none |
| Reduced motion | `prefers-reduced-motion: reduce` | `scroll-behavior` computes `auto`, and a jump lands in the same frame | none |

</intent-contract>

## Code Map

- `src/OcuPilot/Kernel/State/Agent.cls:114` -- `Property ReadOnly As %Boolean [ InitialExpression = 1 ]`. This is the one stored default. `Temperature`'s doc comment shows how a no-move `SCHEMAVERSION` reasoning line is written.
- `src/OcuPilot/Api/Definitions.cls:366` `HandleCreate` -- seeds its values from `%New()` (`ValuesFromRow`), so the API default *is* the class default. `MergeBody:1452` skips a non-boolean value for a boolean field. `ApplyCatalogDefaults` touches only the catalog fields. **No change needed.**
- `ui/src/app/areas/agent/definition-form.store.ts:1073` -- `emptyBuffer()` sets `out['readOnly'] = true`. `body()` (`:884`) sends every writable field, so a form create posts this flag. The form draws no read-only control.
- Installer, demo fixture, smoke and scripts: none creates or writes an agent definition. `Install/*.cls`, `scripts/` and compose files were checked with grep for `State.Agent`, `ReadOnly` and `agent/definitions`. **No rewrite exists, so there is no halt.**
- `src/OcuPilot/Test/AgentFixture.cls:23` `CreateDefinition` and `TurnWireFixture.cls:217` `EnsureDefinition` -- both take the class default. Every probe and `turnprobe` definition becomes read/write.
- `src/OcuPilot/Test/Restraint.cls` -- these methods rely on the old default: `:86` `TestADefinitionMarkedReadOnly…`, `:115` `TestEnforcedReadOnlyWins…`, `:210` `TestAPerUserHoldOutranks…`, `:259` `TestTheDefinitionsFlagIsReRead…` and `:294` `TestResolvedAnswers…`. The helper is `SetDefinitionReadOnly:350`. The asserts at `:92` and `:312` claim "the class's own default".
- `src/OcuPilot/Test/AgentWire.cls:110` pins the created flag at 1. The quoted-flag leg at `:540-543` discriminates only while the default is 1.
- `src/OcuPilot/Test/TurnGrounding.cls:77,86,149` sets the flag explicitly in every method. `ScreenGrounding.cls:139-160` passes the verdict into `BoundedContext`. **Neither depends on the default.**
- `src/OcuPilot/Kernel/Agent/Prompt.cls` `BUILTIN` -- `TurnNavigate.cls:481` pins its last two sentences verbatim. `TurnWire:145`, `TurnLoop:140` and `TurnTools:268` compare the sent system prompt with `Builtin()`. `ScreenGrounding.cls:18` `Statement(1..5)` and `:43` `TestThePromptCarriesTheFiveStatements` are 11.9's pin.
- `src/OcuPilot/Screen/Tool/Navigate.cls` -- `shell.screen.open`, kind `read` (so it is usable while read-only), client-fulfilled. Its `DESCRIPTION` already says the move is announced and that Back returns. Read-only here.
- `ui/src/app/shell/panel.ts` -- transcript template `:344` (`role="log"`, `tabindex="0"`); `sendCurrentDraft:1560` and `onCardRepropose:1140` (the two send paths, `outcome === 'sent'`); `onNewConversation:1630`; `turn.subscribe` in the constructor; `bump:1651`. It has no scroll code today. Starter prompts only fill the draft (`onSuggestion:1354`).
- `ui/src/styles/_components.scss:3272` `.ocu-panel-transcript` (`overflow-y: auto`). Reduced-motion idiom at `:116` and `:3707`.
- `ui/src/app/shell/panel.spec.ts` -- harness `mount:139`, `stubTurnStore`, `fakeTurnApi:666`, `fakeTurnSchedule:682`, `turnStep:689`.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` -- the Body paragraph is `:541`. `strings.test.mjs:170` finds it by the prefix `**Body.** Banners, in order` and reads `aria-label="Conversation"`, so both must stay. The last Fixed-strings row is `:466`, and every `/** EXPERIENCE.md:n */` in `strings.ts` points at `:466` or earlier. `:746` is Focus destinations. Epic 9 appends 26 rows at the table end.
- `ui/tools/strings.test.mjs:538,562` hold the table and the source equal. `:725` resolves every line citation.
- `ui/browser/panel-spec.mjs:62` `signedInAt(browser, config, url, viewport, mediaFeatures)`. `turnprobe-spec.mjs` has `armProbeDefinition`, `setTag`, `scriptReply` and `requireFreeSlot`. `reply.browser-spec.mjs` has the long `TextReply` pattern. `structural-walk.mjs:483` `detectScreen`, `INVARIANTS` and `componentMinimums` are the DW-1337 detectors.
- These browser specs say "the definition ships read-only", which becomes false: `proposal-card:77`, `proposal-confirm:72`, `users-write:87`, `auditing-write:81`, `process-control:94`, `task-resume:101` and `error-log-delete:81`.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Kernel/State/Agent.cls` -- Set `ReadOnly`'s `InitialExpression` to 0. Rewrite its doc comment: the flag is read/write by default ("developer tool first"), and `SCHEMAVERSION` does not move, because a stored row keeps its value and a default is not a meaning.
- `ui/src/app/areas/agent/definition-form.store.ts` -- In `emptyBuffer()`, set `readOnly` to `false`.
- `src/OcuPilot/Kernel/Agent/Prompt.cls` -- Append the golden statement from Design Notes after the last sentence, and update the doc comment's sentence map.
- `src/OcuPilot/Test/ScreenGrounding.cls` -- Add `Statement(6)` and one named assertion, "the open-the-screen-first statement". Rename the method `TestThePromptCarriesTheScreenStatements` and update the header's count.
- `src/OcuPilot/Test/DefinitionDefaults.cls` (new, unarmed; probe definitions through `AgentFixture`, removed in teardown) -- Covers two things:
  - `%New()` and a `CreateDefinition` row read `ReadOnly` 0, and their verdict is not blocked.
  - Stored 1 and 0 survive `Installer.Install("")` (fresh `%OpenId`, every reference dropped first).
- `src/OcuPilot/Test/Restraint.cls` -- In the five methods named in the Code Map, set the flag to 1 with `SetDefinitionReadOnly` after creating the definition. Replace the two "class's own default" messages with "set read-only for this test".
- `src/OcuPilot/Test/AgentWire.cls` -- `:110` pins `readOnly` 0 ("created read/write"). Re-seat the quoted-flag leg: create with JSON `true` and assert the answer reads 1 (the flag is still settable), then `PUT {"readOnly":"false"}` and assert that 1 is kept.
- `ui/src/app/areas/agent/definition-form.page.spec.ts` -- A create's POST body carries `readOnly: false`. An edit of a stored `readOnly: true` definition sends `true` back.
- `ui/src/app/shell/panel-follow.ts` (new) -- The follow state over the transcript element. It holds `FOLLOW_TOLERANCE_PX`, the at-newest predicate, the following flag, the rule that own scrolls never clear it, and the jump. It has no Angular dependency.
- `ui/src/app/shell/panel-follow.spec.ts` (new) -- Uses a fake element. Covers distance 4 (following) and 5 (not following), a user scroll away and back, a smooth scroll's intermediate positions leaving following on, and the jump.
- `ui/src/app/shell/panel.ts` -- Wire the follow state: scroll after the render that follows an accepted send, and after a store notify while following. Render the control outside the log from `STRINGS.agentJumpToLatest`, with focus moving to the transcript on use. Reset following on New conversation.
- `ui/src/app/shell/panel.spec.ts` -- A new "Story 11.10" block covers five cases:
  - an accepted send scrolls, and a refused send does not;
  - an arrival while following scrolls, and one while scrolled up does not and shows the control;
  - the control's text is the key;
  - the jump focuses the transcript;
  - New conversation hides the control.
- `ui/src/styles/_components.scss` -- Append the control's rule, `scroll-behavior: smooth` on the transcript and its reduced-motion override (own entries only).
- `ui/src/app/core/strings.ts` -- Add `agentJumpToLatest: 'Jump to latest'` beside the panel keys, with `/** EXPERIENCE.md:467 */`. No existing citation shifts.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` -- Append one row after `:466`: `| "Jump to latest" | the panel transcript's return to its newest entry, shown while the user has scrolled away from it (Story 11.10) [ADDED 2026-09-24 - see the story change log] |`. Rewrite the Body paragraph `:541` in place as one line, keeping its prefix and attributes, to state the follow rule, the 4 px tolerance and reduced motion.
- `ui/browser/transcript-follow.browser-spec.mjs` (new) -- Arm `turnprobe` and script long `TextReply`s. Run three turns, and after each Send assert that the sent message's rect is inside the transcript's rect and that the transcript ends at its newest entry. Script a reply with `hangSeconds`, send it, and scroll up with `page.mouse.wheel` while the turn runs. On arrival, assert `scrollTop` is unchanged and Jump to latest is visible. Run `detectScreen` with every invariant and assert no entry names the control. Press the control and assert the transcript is at newest, the control is gone and focus is on the transcript. Reduced-motion leg: `signedInAt(..., mediaFeatures)` with `prefers-reduced-motion: reduce`, computed `scroll-behavior` is `auto` (`smooth` without it), and a jump lands at newest in the same `evaluate`.
- The seven browser specs in the Code Map -- Replace each stale comment line with "Cleared here rather than relying on the definition default; under read-only no proposal is minted (AD-30)."

**Acceptance Criteria:**

- Given a definition created through the API or the form with the flag untouched, when it is saved, then it reads `readOnly` false and its verdict is not blocked, while `Restraint`'s enforced and definition arms still block.
- Given a definition stored read-only, when the installer runs and the row is read again, then it is still read-only.
- Given the default pins, when `InitialExpression` or `emptyBuffer` is set back to read-only, then `DefinitionDefaults`, `AgentWire` and the form page spec go red.
- Given the built-in prompt, when `ScreenGrounding` runs, then `Builtin()` equals the class parameter and carries the new statement verbatim. `TurnNavigate`'s two sentences and the five 11.9 statements are still carried, and the prompt is printable ASCII.
- Given a turn over the wire, when the provider request is recorded, then its system prompt equals `Builtin()` (the Integration AC, pinned unedited by `TurnWire`).
- Given the transcript rules, when the story's browser spec runs against the redeployed bundle, then every matrix row from "Send while scrolled up" onward holds in real layout, and the control shows no structural violation.
- Given EXPERIENCE.md, when `strings.test.mjs` runs, then the new row and the new key are equal, every line citation resolves, and the Body line still yields "Conversation".

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs:** AD-11 (rule 1: the prompt is a constant; rule 3: navigation is announced, refusable and reversible, through the `client`-fulfilled tool), AD-30 (the read-only verdict and gate are unchanged, and only the stored default moves), AD-10 (untouched), AD-24 (as amended by 11.9: `readOnly` in context is the verdict, which now defaults to false for a new definition), AD-19 (the follow state is outside `core/`, in the shell), AD-53/AD-55 (unchanged; the switches still gate only the agent), and the Conventions: Angular naming, Client asset homes (`strings.ts`, `\uXXXX`), Theme (tokens only), and "When `SCHEMAVERSION` moves" (it does not).

**Golden statement** (appended as the prompt's last sentence, and pinned verbatim):

```text
When the user asks about something a screen shows, or asks to change it, and the screen_context does not show them on that screen, open that screen with the navigation tool first, before you answer or propose the change, so they see what you are discussing and the change when it lands; when they are already on it, do not navigate.
```

Home sends no context, so from Home the statement opens the target screen. That is the Story 17.7 check. With sharing off the agent cannot see the current screen and may announce a move to it; the move stays announced and refusable (inference).

**Why the default sources need no change.** `HandleCreate` builds its values from `%New()`. The installer, the demo fixture, smoke and the scripts create no definition. The form is the only second source, because it posts its own buffer.

**Row placement.** The row is appended at the table end because every gated `strings.ts` citation points at `:466` or earlier, so nothing shifts. Epic 9 appends at the same point, and the merge keeps both rows; `strings.test.mjs:725` then names any citation to recompute. Epic 9's rows also shift the prose line references in other rows (for example `` `:610` ``) by one or more. Those belong to other rows, and the shared-append rule leaves them alone.

**Why the control shows whenever the user has scrolled away.** The AC says it appears when an entry arrives while the user is scrolled up. Showing it whenever the transcript is away from its newest entry satisfies that with one condition and no unread count, so the way back is always there.

**Footprint extensions:** `src/OcuPilot/Test/DefinitionDefaults.cls` (new) and the seven browser specs' single comment lines. Of those, `proposal-confirm` and `task-resume` carry Epic 9 hunks at `:154` and `:502`, far from `:72` and `:101`. Read `git show origin/OCU-1-epic9:<path>` before editing. Nothing touched is a contended path.

**Integration ACs:** No new service. `panel-follow.ts` is private to the panel.

- Consumes: Story 3.1/3.5 (the definition and its form), 3.7 (the verdict), 4.5 (TurnStore sends and entries), 4.7 (`shell.screen.open`), 11.9 (the prompt pin).
- Consumed-by: Story 11.7 (streamed text appends under the same follow rule) and Story 17.7 (the owner's live check of the navigation statement).

**Ledger inbox:** none.

## Verification

**Slot and instance.** Slot B. Every IRIS MCP call carries `server: "ocupilot-slot-b"`. Stateful checks run only on `ocupilot-b-ci`. If it is down, bring it up with `sh scripts/ci-throwaway.sh up --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci --web 52777 --super 1976`, and tear it down only if this stage brought it up. Load code with `cp -R src/. /tmp/ocupilot-b-ci/src/` and then `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck",,1)` in `docker exec ocupilot-b-ci iris session iris -U HSCUSTOM`. Before any browser run, run `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, and export `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci`. Never touch `ocupilot`, any `ocupilot-slot-*` container or `ocupilot-ci`.

**Commands:**

- `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh` -- expected: clean.
- **(loop)** `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>` for `DefinitionDefaults`, `Restraint`, `AgentWire`, `ScreenGrounding`, `TurnNavigate`, `TurnGrounding` and `TurnWire` -- expected: green. Run one class per invocation and one invocation per message, never re-submit on a timeout, and confirm with the `%UnitTest_Result` probe.
- **(loop)** `cd ui && npm run test:tools && npm run test:components` -- expected: green (`strings.test.mjs`, `citations.test.mjs`, `panel.spec.ts`, `panel-follow.spec.ts`, `definition-form.page.spec.ts`).
- **(loop)** `cd ui && node --test --test-concurrency=1 browser/transcript-follow.browser-spec.mjs browser/reply.browser-spec.mjs browser/panel.browser-spec.mjs` -- expected: green against the redeployed bundle.
- **(once, before dev_complete)** The full ObjectScript sweep, one class at a time on `ocupilot-b-ci`, then `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`. The full browser suite runs in CI only.

**Pinning mutations (Rule 19).** Recompile the package or rebuild and redeploy the bundle before reading each result. Revert, confirm `git status --short` is unchanged, and record `mutation: … -> …` under each item.

- `InitialExpression = 1` -> `DefinitionDefaults` new-definition leg and `AgentWire:110` red.
- `emptyBuffer` `readOnly = true` -> the form page spec's create-body case red.
- An installer step that sets every definition's `ReadOnly` to 0 -> `DefinitionDefaults` install-survival leg red.
- Drop `MergeBody`'s boolean type guard -> `AgentWire`'s re-seated quoted-flag leg red.
- Delete the new prompt statement -> `ScreenGrounding` red on "the open-the-screen-first statement" alone.
- `FOLLOW_TOLERANCE_PX = 5` -> `panel-follow.spec.ts` 5 px case red. `= 3` -> 4 px case red.
- Let the panel's own scroll events clear following -> `panel-follow.spec.ts` intermediate-positions case red.
- Scroll on every arrival regardless of following -> the browser spec's scrolled-up leg red (`scrollTop` moved).
- No scroll on send -> the browser spec's long-conversation leg red.
- Drop the reduced-motion override -> the browser spec's reduced-motion leg red.
- Remove focus to the transcript on jump -> `panel.spec.ts` jump case and the browser jump leg red.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
