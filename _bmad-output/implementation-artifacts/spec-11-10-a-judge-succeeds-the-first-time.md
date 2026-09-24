---
title: 'Story 11.10: A judge succeeds the first time'
type: 'feature'
created: '2026-09-24'
status: 'done'
baseline_revision: 'd0ea94cce5ce589264db29df45da6e5e2f5e7c50'
baseline_commit: 'd0ea94cce5ce589264db29df45da6e5e2f5e7c50'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-11-context.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['multiple-goals', 'oversized']
deferred:
  - summary: >-
      Api/Definitions.cls MergeBody doc comment still says readOnly's default is 1 after the default moved to 0.
    evidence: |-
      Story 11.10 set Kernel.State.Agent.ReadOnly InitialExpression to 0; the comment at Api/Definitions.cls:1438 reads "on readOnly, whose default is 1". The story's Never list forbids editing Api/Definitions.cls, so the prose was left stale.
    location: >-
      src/OcuPilot/Api/Definitions.cls:1438
    severity: low
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

### Review Findings

Code review 2026-09-24 (full-opus; blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor): 41 rows, 7 entries (med 3, low 4), 18 rejected.

- [x] [Review][Patch] [med] A wheel turned up during the panel's own smooth scroll was swallowed and the transcript carried on to the newest entry, still following (reproduced in headless Chrome, and in the app by `transcript-follow` (d) with the fix removed) -- `onWheelUp` stops the own scroll where it stands and turns following off; a passive native wheel listener calls it [ui/src/app/shell/panel-follow.ts:84, ui/src/app/shell/panel.ts:653]
- [x] [Review][Patch] [med] The install-survival pin never ran a migration step, so a later step rewriting `ReadOnly` would pass it -- the test now also runs `RunMigrations("", 0)` and re-reads both flags [src/OcuPilot/Test/DefinitionDefaults.cls:109]
- [x] [Review][Patch] [low] DW-1620: the `MergeBody` doc comment's "whose default is 1" replaced with the create behavior [src/OcuPilot/Api/Definitions.cls:1438]
- [x] [Review][Patch] [low] `DefinitionDefaults` placed alphabetically in the arming roster [scripts/ci-throwaway.sh:231]
- [x] [Review][Defer] [med] The Definition form has no read-only control (FR-24) -- deferred: DW-1621 decision-pending, owner burndown
- [x] [Review][Defer] [low] A quoted `readOnly` on create stores the read/write default -- deferred: DW-1622 wontfix-accepted
- [x] [Review][Defer] [low] Expanding a card while following scrolls the opened card up -- deferred: DW-1623 wontfix-accepted

Rejected: the form's default duplicating `InitialExpression` (the AC requires both); growth outside a render (resize, zoom) not followed (self-heals at the next render; a `ResizeObserver` for no demonstrated harm); a reload animates to the newest entry (Always: scripts pass no behavior); Jump removed under focus when the user wheels to the bottom (Never: no scroll moves focus, Always: it goes away at the newest entry); change detection per scroll event (no measured cost); the statement's refusal and trigger wording (golden text); `DefinitionDefaults` armed and the footprint list (recorded under Departures; a spec edit); the cross-class `SetDefinitionReadOnly` helper (no harm named); no mutation note in the class header (false: mutations live here); the page spec's `.at(-1)` Save pick (discriminates, mutation recorded); sub-pixel retarget and a stuck `inFlight` (only while following; an upward scroll clears it); scroll anchoring turning following off (false: collapse plus append in one frame ends clamped at the newest entry in Chrome); the geometry fake's unconditional scroll event (test fidelity only); AC6's structural clause without its own mutation (AC6 has recorded mutations, and the filter matches `ocu-*` classes); 4 px / 5 px and a refused send outside real layout (layout-independent arithmetic, pinned by mutation in the unit); the EXPERIENCE.md row's change-log pointer (a spec edit).

## Spec Change Log

## Review Triage Log

### 2026-09-24 — Review pass

- verdicts: 18 findings — high 0, medium 3, low 11, false 4, maybe-false 0
- findings:
  - `[medium]` `[patch]` Re-propose's `followNewest()` had no test — added the Story 11.10 Re-propose case to `panel.spec.ts`; mutation recorded.
  - `[medium]` `[patch]` "restored on reload opens at its newest entry" was unpinned — added the fresh-`settle` case to `panel-follow.spec.ts`; mutation recorded.
  - `[low]` `[patch]` the fits-its-viewport case never reached `atNewest` — it now asserts `atNewest` and a scroll event leaving following on.
  - `[low]` `[reject]` `panel.spec` New conversation's null-control assertion cannot tell a reset from an empty transcript — the same test's `scrollTop` 800 assertion pins the reset.
  - `[low]` `[patch]` AC5, AC7 and the arrival-while-following row had no `mutation:` line — demonstrated and recorded under Review pass additions (AC1 and AC4 already carry one per AC).
  - `[low]` `[patch]` browser (b) did not prove the reply arrived after the scroll-up — hang raised to 12 s and a one-reply precondition asserted before the arrival.
  - `[false]` `[reject]` the default is tested at storage, not at a turn — the verdict is the single gate (AD-30) and is pinned not blocked for a default row; an API create stores the same flag (`AgentWire:110`).
  - `[low]` `[defer]` `Api/Definitions.cls:1438` doc comment still says `readOnly`'s default is 1 — the file is on this story's Never list.
  - `[low]` `[reject]` the prompt statement's effect on a model is untested — excluded by the intent (no live model); Story 17.7's owner check consumes it.
  - `[false]` `[reject]` the statement adds "do not navigate" and narrows its trigger — it is the Design Notes golden text verbatim.
  - `[low]` `[reject]` the control's visibility is state, not geometry, so a viewport change with no scroll event can leave it shown at the newest entry — rare, harmless, and the fix adds a branch.
  - `[low]` `[patch]` no test combined a 4 px distance with an arrival — added to `panel-follow.spec.ts`.
  - `[low]` `[patch]` accepted-send variants untested — grouped with the Re-propose patch; Enter and Send anyway share `sendCurrentDraft`'s pinned path, a locked send the refused one.
  - `[false]` `[reject]` proposal-card and error-banner arrivals untested — `settle` reacts to any transcript growth, so every entry kind takes the pinned path.
  - `[medium]` `[patch]` restore on reload untested, and it animates under smooth scroll — grouped with the restore patch; the animation follows the spec's "scripts never pass a behavior".
  - `[low]` `[reject]` "goes away by the user's own scroll" tested only in the unit spec — the panel wiring is the same `onTranscriptScroll` handler the `userScroll` cases pin.
  - `[low]` `[reject]` no test that a send leaves focus alone — only `onJumpToLatest` calls `focus`; a test would guard no demonstrated state.
  - `[false]` `[reject]` stateful checks on `ocupilot-b-ci` cannot be verified from the diff — every run of this pass was on `ocupilot-b-ci`.

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
  - mutation: `ReadOnly` `InitialExpression = 1`, package recompiled -> `DefinitionDefaults.TestANewDefinitionIsReadWrite` red (4 assertions) and `AgentWire.TestASoundCreateIsReturnedByTheListImmediately` red on "created read/write" alone
- `emptyBuffer` `readOnly = true` -> the form page spec's create-body case red.
  - mutation: `emptyBuffer` `out['readOnly'] = true` -> `definition-form.page.spec.ts` "Story 11.10: a create posts readOnly false" red (1 of 52)
- An installer step that sets every definition's `ReadOnly` to 0 -> `DefinitionDefaults` install-survival leg red.
  - mutation: `UPDATE ... SET ReadOnly = 0` at the top of `Installer.Install` for the production profile -> `DefinitionDefaults.TestAStoredFlagSurvivesAnInstall` red on "the stored read-only flag is still 1" alone
- Drop `MergeBody`'s boolean type guard -> `AgentWire`'s re-seated quoted-flag leg red.
  - mutation: `MergeBody`'s boolean `%GetTypeOf` guard line deleted -> `AgentWire.TestABodyThatIsNotAMapOfScalarsIsRefused` red on "with the stored flag kept" alone (1 of 17)
- Delete the new prompt statement -> `ScreenGrounding` red on "the open-the-screen-first statement" alone.
  - mutation: statement deleted from `BUILTIN` -> `ScreenGrounding.TestThePromptCarriesTheScreenStatements` red on "the open-the-screen-first statement" alone (1 of 10 methods, 1 assertion)
- `FOLLOW_TOLERANCE_PX = 5` -> `panel-follow.spec.ts` 5 px case red. `= 3` -> 4 px case red.
  - mutation: `= 5` -> "a user scroll to 4 px ... and to 5 px does not" red on its 5 px leg; `= 3` -> the same test red on its 4 px leg (1 of 5 each)
- Let the panel's own scroll events clear following -> `panel-follow.spec.ts` intermediate-positions case red.
  - mutation: `onScroll`'s `!this.inFlight || top < previous` arm made unconditional -> "a smooth scroll on its way there keeps following on" red (1 of 5)
- Scroll on every arrival regardless of following -> the browser spec's scrolled-up leg red (`scrollTop` moved).
  - mutation: `settle` scrolls on `scrollHeight` growth whatever `following` reads, rebuilt and redeployed -> `transcript-follow` (b) red on "the reply arrived without moving the scrolled-up transcript"; dropping only the `following` check (growth still read off `scrollHeight - clientHeight`) reddens (a), (b) and (c) at their scrolled-away precondition, since the control's own row counts as growth
- No scroll on send -> the browser spec's long-conversation leg red.
  - mutation: `followNewest()` dropped from `sendCurrentDraft`, rebuilt and redeployed -> `transcript-follow` (a) red at "turn 2, after Send" (962 px away), (b) and (c) green; `panel.spec.ts` "an accepted send scrolls" red as well
- Drop the reduced-motion override -> the browser spec's reduced-motion leg red.
  - mutation: the `prefers-reduced-motion` `scroll-behavior: auto` block deleted, rebuilt and redeployed -> `transcript-follow` (c) red on "reduced motion computes scroll-behavior auto"
- Remove focus to the transcript on jump -> `panel.spec.ts` jump case and the browser jump leg red.
  - mutation: the `focus` call dropped from `onJumpToLatest` -> `panel.spec.ts` "pressing Jump to latest ... focuses the transcript" red (1 of 123) and, rebuilt and redeployed, `transcript-follow` (b) red on "focus is on the transcript"
- Review pass additions:
  - mutation: `followNewest()` dropped from `onCardRepropose` -> `panel.spec.ts` "Story 11.10: an accepted Re-propose scrolls ..." red (1 of 1057)
  - mutation: the first `settle` records `lastNewest` without scrolling -> `panel-follow.spec.ts` "a transcript restored on reload opens at its newest entry" red (1 of 1057)
  - mutation: the `afterEveryRender` settle made a no-op -> `panel.spec.ts` "an arrival while following scrolls ..." red (1 of 1057)
  - mutation: `Loop.cls` sends `Builtin()` cut before the new statement, package recompiled -> `TurnWire.TestAStartRunsAsTheCallerAndThePollAnswersItsShape` red on "under the built-in system prompt" (1 of 13)
  - mutation: `agentJumpToLatest` set to 'Jump to newest' -> `strings.test.mjs` table-equals-source tests red (3 of 25); its citation set to `:465` -> "every EXPERIENCE.md line reference resolves" red alone
- (QA) restore-on-reload was pinned only in the pure follow unit -- added `panel.spec.ts` "a transcript restored on reload opens at its newest entry" (Story 11.10 block), mounting a three-turn restored conversation and faking post-mount geometry the way `mountAnswered` does, triggered by an unrelated `navigation.notify()` render.
  - mutation: `settle`'s `grew` changed to `newest > this.lastNewest && this.lastNewest > 0` -> both this test and `panel-follow.spec.ts`'s existing restore case go red (2 of 1058 and 1 of 7); reverted, `panel-follow.ts` byte-identical to before
- (CR) A wheel turned up during the own smooth scroll stops it and stops following.
  - mutation: `onWheelUp` made to return false and change nothing -> `panel-follow.spec.ts` "a wheel turned up during the own smooth scroll ..." red (1 of 8); the passive wheel listener dropped from `panel.ts` -> `panel.spec.ts` "a wheel turned up while the own scroll is on its way ..." red (1 of 126) and, rebuilt and redeployed, `transcript-follow` (d) red on "the own scroll stopped short of the newest entry" (carried to the newest entry)
- (CR) Stored flags survive the migration steps.
  - mutation: `UPDATE OcuPilot_Kernel_State.Agent SET ReadOnly = 0` added to `Installer.MigrateToVersion1`, package recompiled on `ocupilot-b-ci` -> `DefinitionDefaults.TestAStoredFlagSurvivesAnInstall` red on "the stored read-only flag is still 1 after the migrations" alone (run 245); reverted and recompiled, green

## Auto Run Result

Status: done
Blocking condition: none

**Change.** A new definition is read/write (`Agent.ReadOnly` `InitialExpression` 0, the form's `emptyBuffer` `readOnly` false); stored values are untouched and `SCHEMAVERSION` does not move. `Prompt.BUILTIN` ends with the golden statement. The panel transcript follows the conversation through `shell/panel-follow.ts`, with Jump to latest outside the log and scroll animation in CSS.

**Files.** `Kernel/State/Agent.cls` (default), `Kernel/Agent/Prompt.cls` (statement), `Test/DefinitionDefaults.cls` (new: default and install survival), `Test/Restraint.cls`, `Test/AgentWire.cls`, `Test/ScreenGrounding.cls` (re-seated pins), `definition-form.store.ts` and its page spec, `shell/panel-follow.ts` and spec (new), `shell/panel.ts` and spec, `_components.scss`, `strings.ts`, `strings.test.mjs` (literal bound 700 to 750), EXPERIENCE.md (row `:467`, Body line), `browser/transcript-follow.browser-spec.mjs` (new), seven browser-spec comment lines, `scripts/ci-throwaway.sh` (arming roster).

**Departures (footprint_extensions).** `DefinitionDefaults` is armed by `OCUPILOT_ALLOW_PRODUCTION_INSTALL`, not unarmed: it calls `Installer.Install("")`, which the checker refuses in an unarmed class, so `scripts/ci-throwaway.sh` gained `# classes: DefinitionDefaults`. `strings.test.mjs`'s bound conflicts with Epic 9's 900 at merge: keep 900 and both comment paragraphs.

**Review.** 18 findings: 7 patched (2 medium, 5 low; the Re-propose and restore groups, the fits-viewport case, the 4 px arrival case, browser (b)'s arrival precondition, five mutation lines), 1 deferred (stale `Api/Definitions.cls:1438` comment, Never-listed file), 10 rejected as logged. Follow-up review recommended: true (2 medium patched) -- restore-on-reload opening at the newest entry is pinned in the pure follow unit only; no panel or browser test reloads a long transcript.

**Verification.** `check-objectscript.py` 0 problems; `lint-docs.sh` clean; `test:tools` 1375/1375; `test:components` 1057/1057; browser `transcript-follow`, `reply`, `panel` 20/20 against the rebuilt, redeployed bundle (1,326,022 bytes, under the 1378 kB warning; DW-1166 not applied). Full ObjectScript sweep on `ocupilot-b-ci`, one `ci-runner` call per class: 224 classes, runs 18-241 consecutive, 1992 methods, 1992 passed, 0 failed (`%UnitTest_Result`, 16:06:20-16:25:54 instance time). `smoke.sh --container ocupilot-b-ci`: executed=49 passed=49 failed=0. Mutations recorded under `## Verification`.

**Residual risk.** A wheel scroll made while the panel's own smooth scroll is still running can be overridden by it (observed in headless Chrome; the browser spec lets the own scroll finish first) (inference).
