---
title: 'Story 20.36: Investigate'
type: 'feature'
created: '2026-10-15'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-20-12-the-agent-gains-guided-workflows-and-investigate.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** From a log or audit entry the agent can only explain that one entry. A developer-administrator facing a stuck production still starts from a blank page: nothing gathers the related rows and weighs causes.

**Approach:** An **Investigate this entry** control sits beside every Explain this entry. It sends the explain-entry turn (same screen context, same DW-1838 marker) with `workflow: "investigate"`, a read-only entry in Story 20.12's catalog. The ordinary turn follows its steps (related log reads, then the state of what the entry names) and answers with a Recap and Hypotheses ranked most likely first, each naming in backticks the rows it rests on. A cited row from a citable read becomes a chip through the existing citation machinery.

## Boundaries & Constraints

**Always:**

- **One more catalog entry, no new mechanism.** `investigate` is data in 20.12's `XData Catalog` (Design Notes › Catalog entry). It has no `writes`, carries `"entry": true` ("offered by an entry control, not by a prompt"), and every `reads` name resolves on the instance as `read`. The turn, the synthetic `workflow` pair, the refusals, the chip and Continue are 20.12's, unchanged.
- **The same gate as Explain.** The control renders when Explain renders and refuses for the same reasons (kill switch, a running turn, sharing off): `aria-disabled` plus `aria-describedby` naming the reason, never hidden. It extends `core/explain-entry.ts` with a kind.
- **The same turn as Explain, plus the workflow.** The panel sends "Investigate the selected entry" with the context `assembleEntryContext` builds today (one `selected` or `focus` marker) and the workflow `{id: "investigate", text: "Investigate this entry"}` through 20.12's `send(message, context, workflow)`. Per AD-66, the chip then shows and every later send carries `investigate` until End workflow, a new conversation or sign-out.
- **Read-only.** Every write call in an investigate turn answers `WORKFLOW.NOTASTEP` and mints nothing. The finish tells the model to name the guided workflow or screen that would make a fix.
- **Strings and shared files.** Three new strings go in `strings.ts` and EXPERIENCE.md's Fixed strings, with unique values. `_components.scss`, `strings.ts` and EXPERIENCE.md take add-only edits.
- **Bundle.** The initial total stays under 2500 kB. It measured 1.96 MB; 20.12 adds about 6 kB and this story about 2 kB, so expect about 1.97 MB (inference).

**Never:**

- A new route, tool, governance key, screen, descriptor, entity type, suggested prompt or system-prompt sentence. `BUILTIN` is unchanged; the marker's meaning for an investigate turn travels in the catalog step's `say`.
- A prompt that names `investigate`, or a write in its steps.
- Edits to `Kernel/Proposal/*`, `Kernel/Governance/*`, `Screen/Registry.cls`, `Screen/Read.cls`, `Kernel/EntityType.cls`, `Kernel/Agent/Citations.cls`, `app.routes.ts`, `angular.json`, `.github/workflows/ci.yml`, `ui/tools/ci-shards.mjs`, `ui/tools/ci-timings.json` or `ui/tools/ci.test.mjs`.
- Changing an existing grid track (`.ocu-log-row-explain`, `.ocu-log-hub-row-explain`) or an existing Explain control's attributes.
- Chips for log rows. Their screens' ids are `none` or three-part composites, so `Registry.CitationSource` gives no candidates (named limit).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Investigate a row | A messages.log row's Investigate, agent armed, sharing on | POST /turn: message "Investigate the selected entry", `context` with exactly one marker for that row, `workflow: "investigate"`. The first provider request holds `screen_context`, then the `workflow` result for `investigate`, then that message. The chip reads "Guided workflow" and "Investigate this entry" | - |
| Each entry point | The error log's row menu item, the audit dialog's action, the hub's source and timeline buttons | The same body for that entry. The audit dialog closes only when the request is accepted, as Explain's does | - |
| Gated | Kill switch, a running turn, or sharing off | Investigate is `aria-disabled`, described by that reason's id; choosing it records nothing | - |
| Not armed | No enabled definition | Neither control shows; the error log menu stays `[Delete]` | - |
| A write | The investigate turn calls `permissions.users.delete` | No proposal, no card | `WORKFLOW.NOTASTEP` tool result |
| A citable read | The turn calls `permissions.users.read`, then replies with `` `_SYSTEM` `` | The reply shows a citation chip for `_SYSTEM` | - |
| A log row cited | The reply backticks a messages.log line | Text only, no chip (named limit) | - |
| Already in a workflow | A workflow is active, then Investigate | `investigate` replaces it | - |
| Follow-up | A typed message while the chip shows | The body carries `investigate`; writes stay refused until End workflow | - |
| Explain unchanged | Explain this entry, no workflow active | Today's body exactly, with no `workflow` | - |

</intent-contract>

## Code Map

Paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-20`; lines were read at `091114cdac9327c92487243e02251fc17db4c4ca`. **Story 20.12 is planned but not built**: every symbol marked **(20.12, planned)** comes from its spec's Code Map and Tasks and is re-anchored at Task 0.

**Server:**

- `src/OcuPilot/Kernel/Agent/Workflow.cls` **(20.12, planned)**: `XData Catalog`, `Lookup`, `Ids`, `Writes`, `WriteRefusal`, `Exchange` (`{workflow, purpose, steps:[{step, say, reads?, writes?}], finish, previous}`).
- `src/OcuPilot/Test/WorkflowCatalog.cls` **(20.12, planned)**: the literal id roster, the resolution leg (`Registry.ResolveWire(WireName(..))`), and "every workflow is offered by at least one built screen's prompt".
- `src/OcuPilot/Test/WorkflowLoop.cls` **(20.12, planned)**: `TurnToolsCase.RunTurn(..., pWorkflow)` and the recorded first request's messages.
- `src/OcuPilot/Kernel/Agent/Loop.cls` and `Dispatch.cls`: the opening builder and write branch, as 20.12 extends them; read only here.
- `src/OcuPilot/Screen/Context.cls` `Build` :112-130 validates `selected`/`focus`; `Api/Turn.cls` `BoundedContext` :535 and `BoundFocus` :589 bound them. Unchanged.
- `src/OcuPilot/Kernel/Agent/Prompt.cls` `BUILTIN` :22. Its explain sentence ("When the user asks you to explain the selected entry, screen_context marks the entry they chose ... and propose no change.") is unchanged; `Test/ScreenGrounding.cls` keeps 20.12's count.
- `src/OcuPilot/Kernel/Agent/Citations.cls` `Candidates` :25 and `Cite` :61, called at `Loop.cls`:346, :362 and :720. `Loop.CitesRows` :797 and `Screen/Tool/Registry.cls` `CitationSource` :669 (`none` or a composite of two or more parts gives no candidates, :676 and :694). Unchanged.
- `src/OcuPilot/Test/TurnCitations.cls` `TestAFinishedTurnCarriesItsCitationsOnThePollAndTheRestore` :154: the in-process loop over `ProviderStub`, calling `permissions_users_read` and replying `` `_SYSTEM` ``. The pattern for the new leg.
- **Measured on `ocupilot-b-ci` (2026-10-15)**: `logs.alerts.read`, `logs.messages.read`, `logs.eventlog.read`, `logs.audit.read`, `logs.applicationerrors.read`, `logs.hub.read`, `logs.systemmonitor.read`, `interop.itemlog.read`, `interop.messages.read`, `osmgmt.dashboard.read` and `osmgmt.systemusage.read` resolve as `read`; 20.12 measured `interop.productions.read` and `interop.itemstatus.read`. Of these, only `interop.messages.read` has a citation source.

**Client (`ui/src/app/`):**

- `core/explain-entry.ts`: `ExplainEntryRequest {screen, row}` :34, `request(screen, row)` :88, `take()` :96. Built at `main.ts`:217. `core/fix-finding.ts`:50 delegates its gate to it (unchanged).
- `areas/logs/log-viewer.page.ts`: the row's Explain button :297-308 (`data-ocu-log="explain"`), getters :613-627, `onExplain` :630. The row grid's trailing track is `.ocu-log-row-explain`, `styles/_components.scss`:5521-5523.
- `areas/logs/error-log.page.ts`: `EXPLAIN_ENTRY_ITEM` :43, the menu template :239-266, `menuItems` :711-743 (the explain item at :731-741), `onMenuItem` :824 and `explainRow` :836.
- `areas/logs/audit.page.ts`: the dialog's Explain action :139-151 (`data-ocu-audit="explain"`), getters :322-336, `onExplain` :342-348.
- `areas/logs/log-hub.page.ts`: the hidden column header :100-104, the per-source button :148-160 (`source-explain`, per-source state in `sourceRows` :432-455), the timeline button :252-261 (`explain`), `onExplainEntry` :626 and `onExplainSource` :632. The timeline grid is `_components.scss`:7609-7611.
- `shell/panel.ts`: `onExplainEntry` :2014-2022 (`take()`, the gate again, `assembleEntryContext` from `core/screen-context.ts`:163-171, `sendWithContext` :2045). The chips render through `<app-reply [citations]>` :540-546 (`shell/reply.ts` `CITATION_CLASS` :19).
- `core/turn.ts` `send` :1220, gaining `workflow` and `ActiveWorkflow` **(20.12, planned)**. `shell/workflow-chip.ts` **(20.12, planned)**.
- `core/strings.ts`: `agentExplainEntryAction` :101 and `agentExplainEntryMessage` :103.
- `ui/tools/screen-mirror.mjs`: `extractXData` :109 and the catalog reader **(20.12, planned)**.

**Tests and pins:**

- `ui/tools/explain-entry.test.mjs` :53-99 (seven tests). `ui/src/app/testing/explain-entry.ts`: `stubExplainEntry` :21, `explainContext` :56 and `narrowedEntry` :74.
- Page specs: `log-viewer.spec.ts` :1212-1301 (`explainButtons` :1239; the no-extra-track pin :1276-1280); `error-log.page.spec.ts` :1128-1196 (labels pinned at :1147, other levels at :1164-1172); `audit.page.spec.ts` :609-660; `log-hub.page.spec.ts` :270; `panel.spec.ts` :4540-4686 (mount option :174, :227); `explain-roster.spec.ts` :27.
- Browser: `explain-entry.browser-spec.mjs` (legs at :187, :217, :275 and :312; menu labels pinned at :255; arming and seeding in its header); `error-log-actions.browser-spec.mjs` :207 and :296 (`[actionDelete]` unarmed, unchanged); `log-hub.browser-spec.mjs` :357-374; `proposal-card-spec.mjs` `cardViolations` :31, which runs every DW-1337 invariant on a route in light at 1280 and 720 and in dark at 1280.

## Tasks & Acceptance

**Execution:**

- [ ] **Task 0 (re-anchor, no code).** Confirm 20.12 is merged into `OCU-1-epic20`; if not, HALT `blocked` with "Story 20.12 not built". Then re-anchor every **(20.12, planned)** symbol, `panel.ts`'s explain path, the four pages' explain markup, and the end of `strings.ts`. Confirm that `Investigate this entry`, `Investigate the selected entry` and `Ask the agent` are still unused values, and that `permissions.users.delete`'s governance key is enabled on the default policy (20.12's matrix relies on it), so its call reaches `WORKFLOW.NOTASTEP`.
- [ ] **`src/OcuPilot/Kernel/Agent/Workflow.cls`**: add the `investigate` entry (Design Notes › Catalog entry). Document `entry` in the class header.
- [ ] **`src/OcuPilot/Test/WorkflowCatalog.cls`**: the roster gains `investigate`. The prompt-offer leg skips `entry` workflows and asserts that no built screen's prompt names one, and that an `entry` workflow has no `writes`.
- [ ] **`src/OcuPilot/Test/WorkflowLoop.cls`**: add two legs. An investigate turn whose context carries `selected` records `screen_context` (with the marker) then the `workflow` result for `investigate` (its finish included) before the person's text. In that turn, `probe.counter.write` answers `WORKFLOW.NOTASTEP` and the counter is unchanged.
- [ ] **`src/OcuPilot/Test/TurnCitations.cls`**: add `TestAnInvestigateTurnCitesARowItRead`, an investigate turn (`GuardedBegin` with 20.12's trailing `pWorkflow`) that reads `permissions_users_read` and `logs_messages_read` and replies with `` `_SYSTEM` `` and a backticked messages.log line. The poll carries exactly one citation, `_SYSTEM`. Its teardown removes its rows, as the sibling's does.
- [ ] **`ui/src/app/core/explain-entry.ts`**: add `ExplainEntryKind = 'explain' | 'investigate'`, `INVESTIGATE_WORKFLOW = 'investigate'`, and `kind` on `ExplainEntryRequest`. `request(screen, row, kind = 'explain')` keeps its gate. Callers that pass two arguments are unchanged.
- [ ] **`ui/src/app/shell/panel.ts`**: `onExplainEntry` reads `request.kind`. For `investigate` it sends `agentInvestigateEntryMessage` through `sendWithContext(text, context, {id: INVESTIGATE_WORKFLOW, text: STRINGS.agentInvestigateEntryAction})`; for `explain` it is unchanged.
- [ ] **The four pages.** Each gains an Investigate control beside each Explain control, with the same disabled and described-by values and handlers that pass `'investigate'`:
  - `log-viewer.page.ts`: `data-ocu-log="investigate"`. Both buttons are wrapped in one `span.ocu-log-entry-actions` inside the existing trailing track.
  - `error-log.page.ts`: `INVESTIGATE_ENTRY_ITEM = 'investigate-entry'`, pushed right after the explain item under the same condition.
  - `audit.page.ts`: a second `dialogAction` button, `data-ocu-audit="investigate"`, that closes the dialog only on an accepted request.
  - `log-hub.page.ts`: `data-ocu-hub="source-investigate"` and `data-ocu-hub="investigate"`, each in the explain button's cell, wrapped alike. The hidden column header reads `agentEntryActionsColumn`.
- [ ] **`ui/src/styles/_components.scss`** (add-only): `.ocu-log-entry-actions` (inline-flex, the existing spacing token as its gap, `white-space: nowrap`), with no new color.
- [ ] **`ui/src/app/core/strings.ts`** (add-only) and **EXPERIENCE.md** (add-only), per Design Notes › Strings. Then run `cd ui && npm run test:tools` and fix any citation an inserted row shifts.
- [ ] **Client tests**, each with its `Mutation` note:
  - `ui/tools/explain-entry.test.mjs`: the kind is recorded, the default is `explain`, both kinds are refused under each reason, and `INVESTIGATE_WORKFLOW` is a catalog id with `entry: true`, read through 20.12's catalog reader in `screen-mirror.mjs` (exported, add-only, if 20.12 kept it private).
  - The four page specs: Investigate renders beside Explain, is `aria-disabled` with the same described-by, and requests `investigate` for its own row. The error log's labels pin becomes `[actionDelete, agentExplainEntryAction, agentInvestigateEntryAction]`.
  - `panel.spec.ts`, a Story 20.36 block: an investigate request sends the sentence, the marked context and the workflow, and the chip shows "Investigate this entry". An explain request with no active workflow sends no `workflow`.
  - `ui/src/app/testing/explain-entry.ts`: `fire()` takes an optional kind.
- [ ] **`ui/browser/investigate-entry.browser-spec.mjs`** (new). It arms `turnprobe` and seeds errors the way `explain-entry.browser-spec.mjs` does, refuses `LIVE_CONTAINER`, and cleans up in `after`. It covers AC1 and AC2, plus a leg per remaining entry point that reads the recorded body. In `explain-entry.browser-spec.mjs`, the labels pin at :255 gains the Investigate label.
- [ ] **Roster sweep (Rule 30).** Search `src/OcuPilot/Test`, `ui/tools`, `ui/browser` and the `ui/src` specs for assertions on these, and add each changed file to the `(loop)` set:
  - the four pages' row cells, menu items and dialog actions;
  - `ExplainEntryRequest`;
  - the catalog's ids;
  - the hub's column headers.

**Acceptance Criteria:**

- **AC1 (Investigate returns a recap and ranked hypotheses, citing rows; Integration, Rules 1 and 2).**
  - **Given** the signed-in shell on `ocupilot-b-ci`, `logs/messages` in `HSCUSTOM`, and a scripted `turnprobe` definition.
  - **When** the person chooses Investigate on a row.
  - **Then:**
    - `TurnProvider.Recorded` of the first call holds `screen_context` with exactly one marker for that row, then the `workflow` result for `investigate` (its steps' reads, and a finish naming Recap and Hypotheses), then "Investigate the selected entry";
    - the scripted reply's `permissions_users_read` call returns rows, and its `permissions_users_delete` call returns `WORKFLOW.NOTASTEP` with no card;
    - the final scripted reply renders its Recap and numbered Hypotheses, with one citation chip for `_SYSTEM`;
    - the chip reads "Guided workflow" and "Investigate this entry".
- **AC2 (the control, gated like Explain, in both themes).**
  - **Given** the four pages over `stubExplainEntry` (page specs), and the armed shell on `ocupilot-b-ci` (browser).
  - **When** each page shows its entry controls, or the store reports a running turn.
  - **Then:**
    - each Explain this entry has an Investigate this entry beside it;
    - while a turn runs, Investigate is `aria-disabled` and described by the busy reason;
    - `logs/messages`, with both controls shown and the chip present after the turn, passes `cardViolations` (the DW-1337 invariants) at 1280 and 720 in light and at 1280 in dark.
- **AC3 (read-only and data).**
  - **Given** the catalog.
  - **When** the instance validates it and an investigate turn calls a write.
  - **Then** `WorkflowCatalog` is green with `investigate` (an `entry` workflow with no writes and no prompt), and `WorkflowLoop`'s write leg answers `WORKFLOW.NOTASTEP` with nothing minted.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs.**

- **AD-66**: one more catalog entry; the refusals and the chip are 20.12's.
- **AD-11**: the DW-1838 marker clause and the citation clause (a chip only for a citable read).
- **AD-24 and AD-60**: the marker and the workflow result are bounded and sanitized as today.
- **AD-7**: the turn job never mutates.
- **AD-6, AD-10, AD-22, AD-30 and AD-40**: a write never mints (`WORKFLOW.NOTASTEP` at dispatch), and every gate stays where it is.
- **AD-36 and AD-8**: the reads are unchanged and run as the person.
- **AD-39**: the refusal sentence is 20.12's.
- **AD-19**: the client store.

Checked and not engaged: AD-5 (no descriptor or prompt changes; every screen keeps at least three prompts), AD-51 to AD-53, AD-58, AD-59, AD-62 and AD-65. No new screen is added, so `StageTwoTools`' `Elsewhere` block is unchanged.

**Catalog entry** (ASCII; no `iris_` text):

```json
{"id": "investigate", "entry": true,
 "purpose": "Investigate the one log or audit entry the user chose, changing nothing.",
 "steps": [
  {"say": "screen_context marks the entry: selected is its index in rows, or focus holds it; that marker, not entity, names it. Read what it records."},
  {"say": "Read the same log, and the hub across logs, around the entry's time for what came before and after it.", "reads": ["logs.hub.read", "logs.messages.read", "logs.alerts.read", "logs.eventlog.read", "logs.applicationerrors.read", "logs.audit.read", "logs.systemmonitor.read"]},
  {"say": "Read the state of what the entry names: the instance, a production and its items, an item's log, or its messages.", "reads": ["osmgmt.dashboard.read", "osmgmt.systemusage.read", "interop.productions.read", "interop.itemstatus.read", "interop.itemlog.read", "interop.messages.read"]}],
 "finish": "Answer under two headings. Recap: what the entry records and what the reads found. Hypotheses: numbered, most likely first, each naming in backticks the rows it rests on, as the reads returned them. Propose no change; where a hypothesis suggests a fix, name the guided workflow or the screen that would make it."}
```

**Decisions:**

- **No `BUILTIN` change.** AD-66 forbids per-workflow text in the system prompt, so the marker's meaning for this turn is in the first step's `say`. 20.12's sentence already tells the model to follow the steps.
- **`entry` instead of a validator change.** No prompt names `investigate`. `WorkflowCatalog` checks that over every built screen, which keeps `Registry.cls` and the mirror untouched.
- **The chip shows (AD-66: the panel carries the workflow until the person ends it).** Follow-ups therefore stay read-only, and End workflow returns to ordinary turns.
- **The entry point is the existing kind-free store, given a kind.** `fix-finding.ts` stays a separate store that delegates its gate, because its pending item is a check, not a row.

**Strings** (3 client literals; the server sentence is 20.12's):

- `agentInvestigateEntryAction` "Investigate this entry"
- `agentInvestigateEntryMessage` "Investigate the selected entry"
- `agentEntryActionsColumn` "Ask the agent"

EXPERIENCE.md: add a Fixed strings row after :268 for the three: "an entry's Investigate control beside each Explain this entry, the message it sends with the `investigate` workflow (Story 20.36, AD-66), and the log hub's hidden column header for the two" [ADDED 2026-10-15 - Story 20.36].

**Spine drafts (Rule 20, apply-and-report; the lead writes them at the gate):**

- **AD-24**, the explain-entry sentence "The client sends a marker only on an Explain this entry turn" becomes "... on an Explain this entry or Investigate turn (Story 20.36)".
- **AD-11**, the DW-1838 clause gains: "An Investigate turn (Story 20.36) sends the same marker and names the `investigate` workflow (AD-66)."
- **AD-66** gains: "A catalog entry marked `entry` is offered by the explain-entry controls instead of a prompt, and has no writes (Investigate, Story 20.36)."

**Integration, Consumes, Consumed-by (Rules 1 and 2):**

- **Integration:** AC1. The messages.log page (entry point) and the panel (send, recap, chip) drive a real instance.
- **Consumes:**
  - Story 20.12: the catalog, the `workflow` pair, `WORKFLOW.NOTASTEP`, `send(..., workflow)` and the chip;
  - Story 11.2 and DW-1838: the store, the marker and `assembleEntryContext`;
  - Story 11.4: the citations;
  - Story 16.9: the hub.
- **Consumed-by:** none in this epic. Story 21.7's managed alerts would gain Investigate by the same control (inference).

**Rule 31 (extend, don't copy).**

- `explain-entry.ts` gains a kind, and the panel's one explain path branches on it.
- The tests extend `WorkflowCatalog`, `WorkflowLoop`, `TurnCitations`, `explain-entry.test.mjs`, `stubExplainEntry` and the page specs.
- The browser spec copies `explain-entry.browser-spec.mjs`'s arming through `turnprobe-spec.mjs` and `list-spec.mjs`, not its legs, because its assertions differ.
- `.ocu-log-entry-actions` is new, because no existing class groups two text buttons in one track.

**Rule 11.** `git -C ../epic-23 diff --stat origin/feature/OCU-1_ocupilot-mvp...HEAD` touches only bookkeeping files and `epics.md`, none of which this story edits. No overlap and no ask.

**Size.** This is one story: one data entry and one client control in four places. No split is recommended.

**Named limits:**

- Log rows are cited as text, not chips.
- Managed alerts do not exist until Story 21.7, so "an alert" means an alerts.log row.
- The model follows the steps; the instance enforces only that nothing is written.
- An Explain chosen while Investigate is active carries `investigate`, per 20.12's rule.

**Live provider checks:** none planned. CI and every test stay stub-based.

**Ledger inbox (Rule 17):** none.

## Verification

**Shared surfaces:** the four log pages' entry controls (the log row's trailing cell, the error log's row-menu items, the audit dialog's actions, and the hub's cells and hidden header); `ExplainEntryRequest`; the workflow catalog's id roster; the strings table and EXPERIENCE.md :268. *Every test added or changed passes on a fresh environment, in either order.* Each test makes and removes its own definition, turn, conversation and seeded errors.

**Setup (slot B, throwaway only):**

- **Load `src`:** run `rsync -a --checksum --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-20/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`. Then run `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)` in `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`.
- **Before any browser run:** `cd ui && npm run build && docker exec ocupilot-b-ci sh -c 'cd /durable/iris/csp/ocupilot && rm -rf ./*' && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`.

**Commands.** Run each in the foreground with `timeout: 600000`, one at a time, and read results from `%UnitTest_Result`.

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.WorkflowCatalog --class OcuPilot.Test.WorkflowLoop --class OcuPilot.Test.TurnCitations --class OcuPilot.Test.TurnGrounding --class OcuPilot.Test.ScreenGrounding --class OcuPilot.Test.TurnSanitize`, plus every class the sweep changes. Expected: green.
- `(loop)` `cd ui && npm run test:tools`, then `cd ui && npm run test:components`. Expected: green.
- `(loop)` `cd ui && npm run build -- --verbose`. Expected: the prebuild chain is green and the initial total is under 2500kB (about 1.97 MB, inference). Record it.
- `(loop)` `uv run scripts/check-objectscript.py <each changed .cls>` and `bash scripts/lint-docs.sh`. Expected: clean.
- `(loop)` After the redeploy, one file per call: `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/<file>` for `investigate-entry.browser-spec.mjs`, `explain-entry.browser-spec.mjs`, `error-log-actions.browser-spec.mjs` and `log-hub.browser-spec.mjs`. Expected: green.
- **Lead-owned (the runner's):** the full ObjectScript sweep, `cd ui && npm test`, `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`, and Rule 30's fresh check.
- **Left to CI:** the full browser suite.

**Planned pinning mutations (Rule 19).** Revert each byte-identical, then reload, or rebuild and redeploy.

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | `onExplainEntry` sends no workflow for `investigate` | `panel.spec.ts`' 20.36 block, and the browser AC1 workflow leg |
| AC1 | The catalog's `investigate` entry is removed | `explain-entry.test.mjs`' catalog leg, `WorkflowLoop`, and the browser AC1 (422) |
| AC1 | `Loop` skips `Citations.Cite` in a workflow turn | `TurnCitations`' investigate leg, and the browser chip leg |
| AC2 | `request` ignores `kind` | `explain-entry.test.mjs`, and the page specs |
| AC2 | The error log drops its investigate item | `error-log.page.spec.ts`' labels pin |
| AC2 | `.ocu-log-entry-actions` takes `nowrap` off and a fixed width that overflows the track | the browser `cardViolations` leg |
| AC3 | `investigate` gains `"writes": ["permissions.users.delete"]` | `WorkflowCatalog`' entry leg, and `WorkflowLoop`'s write leg (it mints) |

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Planned against Story 20.12's planned code, which is not built yet; Task 0 halts if 20.12 has not merged into `OCU-1-epic20`. The spine drafts in Design Notes await the lead at the spec gate.
