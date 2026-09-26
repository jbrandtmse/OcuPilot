---
title: 'Story 11.4: Citation chips with click-through'
type: 'feature'
created: '2026-09-25'
status: 'ready-for-dev'
baseline_revision: '7ae16d6a4ae22fc77d018b60e02da6d71773f396'
baseline_commit: '7ae16d6a4ae22fc77d018b60e02da6d71773f396'
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

**Problem:** Release 1's built-in prompt tells the model to "Name each row you report in backticks and offer to select it.", so a reply about six accounts names them as inline code and ends "Shall I select them?". Verifying the answer costs a follow-up turn or a search. Nothing in a reply links back to the row it came from.

**Approach:**

- When a turn ends, the instance derives the reply's citations. It takes each backticked span in the final reply and keeps it only when the span equals the identifying value of a row that a read tool in that same turn returned. Each citation records the AD-13 triple, the screen's route and the span text.
- The citations are stored with the turn and the transcript entry and travel on the progress poll and the restored conversation as `citations`.
- The reply renderer turns each matching inline code span into a chip, a `<button>`. A click opens the row through the navigation tool's own allow-list, encoder and URL builder, never an `href`.
- If the cited row is gone, the panel says "no longer present" under the reply, and the screen does not fail.
- The prompt sentence stops asking the model to offer a selection.

## Boundaries & Constraints

**Always:**

- **Binding (the core invariant).** A chip names only a row that a read in the same turn returned. The server builds candidates only from a dispatched, non-error tool call. The tool must be read-kind, instance-fulfilled and descriptor-backed (`Screen/Tool/Read`), and the rows come from its bounded `tool_result` content (the rows the model saw).
  - A candidate's descriptor must be built, have an empty `ParentScope()` and pass `Navigate.AcceptsEntityId`.
  - A row's id is the value of the table's one `kind:"name"` column (`single`), or of its one part (`composite` of one part).
  - An id that is empty, longer than 256 characters or ends in U+2026 (field-truncated) is skipped.
  - Model text only selects among candidates. It never creates one.
- **Matching.** A span matches a candidate when it equals the id exactly, or when `Kernel.EntityRef.NormalizedId(type, …)` of both are equal.
  - Citations keep order of first mention. There is one per distinct `(type, scope, id)`, at most `20`, and the rest are ignored.
  - A span that matches nothing stays code.
- **Wire and storage.** A citation is `{type, scope, id, route, label}`:
  - `type` is `PrimaryEntityType()`;
  - `scope` is `EntityRef.ScopeFor(Scope())`, computed in the job when the read returns;
  - `id` is the row's value as the read returned it;
  - `route` is `Route()`;
  - `label` is the span text.

  `citations` is always present on both payloads. It is `[]` while a turn runs, when there are none, and on older rows. It is stored as JSON text on `Turn` and on `Entry`, with no `SCHEMAVERSION` move (an older row reads as empty), and it is never replayed to the model (AD-24).
- **Client allow-list.** `parseCitations` drops any entry whose route is not a built screen, or whose screen has a `parentScope` or does not accept an id. The mirror of `AcceptsEntityId` is `single`, or `composite` with exactly one part.
- **Chip rendering (AD-11 rule 4, AD-33).**
  - Only a `codespan` whose text equals a citation's `label` becomes `<button type="button" class="ocu-reply-citation">`, built with `createElement` and `textContent`.
  - A codespan inside a link label stays code. Fenced code is never a chip.
  - `button` joins `REPLY_TAGS`, and `type` joins `ALLOWED_ATTR`. No `href`, no `data-*` attributes, and no request.
  - The streamed `<app-reply>` gets no citations.
- **One navigation.** `navigation.ts` gains `entityUrl(route, entityId, scope, currentUrl)`:
  - the target is `route` (plus `'/' + encodeEntityId(entityId)` when there is an id);
  - scope `''` or `instance` goes through `withQuery(target, currentUrl)`;
  - a namespace scope becomes `'/' + target + '?ns=' + encodeURIComponent(scope)` (AD-13, AD-44).

  `AgentNavigator.act` switches to it, passing scope `''`, and its URLs stay byte-identical. The chip calls `router.navigateByUrl(entityUrl(…))`, so the unsaved-changes guard answers it too. A click is user-initiated, so it is not announced (AD-11 rule 3 covers moves the user did not start).
- **Presence (AD-37).** After the navigation resolves `true`, the chip waits for the target store's `lastUpdate()` to be non-null. It then decides from the raw `data()`:
  - present: some row's `rowKey` equals the id, exactly or after `normalizeEntityId`;
  - absent: no match and not `truncated()`;
  - unknown: otherwise.

  Absent shows `citationAbsent` under that turn's reply, in a `role="status"` line. Present, or a later click that finds the row, clears it. Unknown shows nothing. A refused navigation shows nothing.
- **Prompt (AD-11 rule 1).** In `Prompt.BUILTIN`, replace "Name each row you report in backticks and offer to select it." with "Name each row you report by its identifying value in backticks, exactly as the tool returned it; the user can click that name to select the row, so do not offer to select rows."
  - The eight `ScreenGrounding` statements and the navigation sentence are unchanged.
  - The prompt stays printable ASCII.
- **Epic 12 (Rule 11).** Stay off its hunks:
  - `panel.ts` `:155`, `:927`, `:933-935`, `:1072`, `:1101`, `:1220`;
  - `turn.ts` `:89`, `:342`, `:1141`, `:1181`;
  - `strings.ts` `:1955` (renumbered only as the reference check forces).

  New strings go at the `strings.ts` tail, and the new Fixed-strings row goes after the table's last row.

**Never:**

- No chip from `screen_context` rows (they come from the client), from `ErrorRead`, or from a parent-scoped, `none`-id or multi-part composite screen.
- No `href`, URL string or route text taken from the model.
- No new endpoint, tool, dispatch path or transport.
- No change to the streamed append mode.
- No chip text through `innerHTML`.
- No `DESIGN.md` edit.
- No live key in any test.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Cite | turn calls the Users read tool (wire name read from the instance; returns `_SYSTEM`), reply "`_SYSTEM` holds %All." | poll `citations` = `[{type, scope:"instance", id:"_SYSTEM", route:"permissions/users", label:"_SYSTEM"}]`; `_SYSTEM` renders as a chip | none |
| Not returned | reply also backticks `NotARow` | no citation for it; renders as `code` | none |
| No read | reply answered from `screen_context` only | `citations: []`; spans stay code | none |
| Canonical | the read returned `/csp/user`, reply cites `` `/CSP/USER/` `` | one citation, `id` `/csp/user`, `label` `/CSP/USER/` | none |
| Click | chip `_SYSTEM`, user on Home | navigates to `/permissions/users/_SYSTEM` (encoded, `ns` kept); the row is selected | none |
| Namespace scope | citation scope `USER`, current `?ns=HSCUSTOM` | URL carries `?ns=USER` | none |
| Gone | cited user deleted, then chip clicked | list opens, nothing selected, "<name> is no longer present on this instance, so there is nothing to select." | no refusal strip, no fault |
| Truncated | read truncated and row not among rows | no sentence | none |
| Dirty form | on an unsaved editor | guard's own dialog; declined -> no move, no sentence | none |
| Restore | reload after the turn | restored turn renders the same chips | older rows: `[]` |
| Hostile label | row id `<img src=x>` cited | chip text is literally `<img src=x>`; no request | none |
| Streamed | same turn streamed vs plain | identical final turn DOM (chips included) | none |

</intent-contract>

## Code Map

**Server:**

- `src/OcuPilot/Kernel/Agent/Loop.cls`:
  - `AnswerTools` `:414`. Per call, `:536-539` read `tResult`, `tIsError`. `:552` stores the step, and `pToolLog` at `:554-558` is the accumulator precedent. The resolved tool (`class`, `descriptor`, `kind`) is `tRunningResolved` `:503`. `tResult.content` is the bounded JSON `{fields, rows, …}` (`Bound.Apply` `:109-113`).
  - `Run` sets the final reply at `:239-243`, and `FallbackReply` at `:253-258` (the iteration cap).
  - The synthetic `screen_context` is at `:156-180` (never a candidate).
- `src/OcuPilot/Kernel/Agent/Job.cls` -- `Run` `:117` (`AppendConvoEntry`) and `:119` (`Finish` → `Turn.GuardedFinish`).
- `src/OcuPilot/Kernel/State/Turn.cls`:
  - `Reply` `:82`; `GuardedFinish` `:324`;
  - `GuardedView` `:461`, members near `:487`;
  - the add-a-property precedent is `ContextRoute` `:88-92`.
- `src/OcuPilot/Kernel/State/Entry.cls` and `Convo.cls`:
  - `Entry.Reply` `:27`; `GuardedAppend`; `GuardedRows` `:102`, members near `:144`;
  - precedent `TurnKey` `:49-53`;
  - `Convo.AppendEntry`.
- `src/OcuPilot/Kernel/EntityRef.cls` -- `Wire` `:180` (shape), `ScopeFor` `:203`, `NormalizedId` `:244`, `IDRULES` `:59`.
- `src/OcuPilot/Screen/Descriptor/Base.cls`:
  - `Route` `:163`, `PrimaryEntityType` `:225`, `Scope` `:251`, `ParentScope` `:258`, `IdKind` `:266`, `IdParts` `:273`, `Field("table")`.
  - There is no id-field accessor. The single-id rule is the one `name` column, enforced at `Screen/Registry.cls:1965-1968`. The client twin is `rowKey` (`ui/src/app/core/table-model.ts:40`).
- `src/OcuPilot/Screen/Tool/Navigate.cls` -- `AcceptsEntityId` `:226`.
- `src/OcuPilot/Kernel/Agent/Prompt.cls:17` -- the `BUILTIN` sentence.

**Server tests:**

- `Test/TurnNavigate.cls:481-485` pins the old sentence verbatim.
- `Test/ScreenGrounding.cls:46-60` holds the eight statements, `Builtin()`=`BUILTIN`, and ASCII.
- `Test/TurnWire.cls` pins exact key sets: `:134` (progress), `:138` (steps), `:237` (restored rows).
- `Test/TurnProvider.cls` has `Script` `:44`, `TextReply` `:108`, `ToolUseReply` `:120`.

**Client:**

- `ui/src/app/core/turn.ts`:
  - `TurnEntry` `:281-301`;
  - `parseRestoredEntry` `:622-638` (add after `:635`);
  - `send()`'s initial entry `:1049-1059`;
  - `pollOnce` `:1404-1444` (parse near `:1433`, spread at `:1435`; `finalizeLive` carries it over).
  - Unknown keys are ignored.
- `ui/src/app/shell/panel.ts`:
  - `PanelTurnView` `:174-182`;
  - the transcript `@for` `:439`; the final reply `@if (turn.reply !== null)` `:466`, `<app-reply>` `:469`; the streamed branch `:471-478`;
  - the `turns` getter `:896-946`: add a separate `citations` field and leave `reply:` `:930-942` alone.
- `ui/src/app/core/reply.ts`:
  - `ReplyTag` / `REPLY_TAGS` `:40-73`;
  - the `codespan` case in `inlineTokenToNodes`; `linkNodes`; `parseReply`, whose options gain `citations`.
- `ui/src/app/shell/reply.ts`:
  - `ALLOWED_ATTR`, `buildNode`, `sanitizeReplyRoot`;
  - `Reply` (`text` input, `computed` nodes, `effect` build).
- `ui/src/app/shell/agent-navigator.ts:92-110` -- `act()` builds the URL at `:95-97`.
- `ui/src/app/core/navigation.ts` -- `screenForRoute` `:381`, `ownIdSegment` `:370`, `hasIdRoute` `:507`, `withQuery` `:636`, `NAMESPACE_PARAM` `:619`.
- `ui/src/app/core/entity-id.ts:69` `encodeEntityId`; `ui/src/app/core/entity-ref.ts:107` `normalizeEntityId`.
- `ui/src/app/core/screen-store.ts`:
  - `subscribe` `:197`, `data` `:206`, `truncated` `:210`, `lastUpdate` `:225`;
  - `ScreenStores.for` `:555`, called as `for(screen.descriptor, screen.refreshRates)` (`list-page.ts:118`);
  - provided in `main.ts:253`;
  - `ListPage` clears answers on mount, and `selectFromRoute` `:176-186` selects the row.
- `ui/src/app/core/strings.ts`:
  - the tail `:2463-2465`; `/** EXPERIENCE.md:<n> */` above each key;
  - `taskCreate` references `:600` (`:1955`).
  - `ui/tools/strings.test.mjs` has the band `:553` (upper bound 1100) and the reference check `:746-791`.
- EXPERIENCE.md (`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`):
  - reply rules `:248`; `message-agent` `:584`;
  - the Fixed-strings table ends at `:559`;
  - the absent-reference rows `:265` and `:491` (not reused, because values are unique).
- `ui/src/styles/_components.scss` -- `.ocu-reply-code-inline` `:3874` (the chip keeps `{typography.code}`, and DESIGN.md `:854` rules out `agent-accent`).

**Client tests:**

- `ui/tools/reply.test.mjs` (tag checks `:373`, `:412`) and `ui/src/app/shell/reply.spec.ts`.
- `ui/tools/turn.test.mjs`.
- `panel.spec.ts`:
  - the streamed-vs-plain `.ocu-panel-turn` equality `:3956-3974`;
  - fixtures `mountWithProposals` `:2718` and `progressWith` `:2696`.
- `ui/browser/stream-reply.browser-spec.mjs` leg (b) `:262-280` (`finalReplyHtml` `:173-180`).
- `ui/browser/turnprobe-spec.mjs`:
  - `armProbeDefinition` `:171`, `scriptReply` `:151`;
  - a read then text is at `task-resume.browser-spec.mjs:222`;
  - `textReply` is at `navigate.browser-spec.mjs:156`;
  - `iris-session.mjs` runs instance commands.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Kernel/Agent/Citations.cls` (new, no storage):
  - `Candidates(pDescriptor, pContent As %String, ByRef pInto As %DynamicArray)` appends `{type, scope, id, route}` for each row, per the Binding rule.
  - `Cite(pReply As %String, pCandidates As %DynamicArray) As %DynamicArray` scans the backticked single-line spans and applies the Matching rule.
- `Loop.cls`:
  - `AnswerTools` gains a ByRef candidate array. At `:552`, for a non-error `Screen.Tool.Read` call, it calls `Candidates` with the descriptor and `tResult.content`.
  - `Run` sets `pOutcome("citations")` to `Cite(...).%ToJSON()` wherever it sets `pOutcome("reply")`.
- `Job.cls`, `State/Turn.cls`, `State/Entry.cls`, `State/Convo.cls`:
  - add `Citations As %String(MAXLEN = "")` on `Turn` and `Entry`, with a doc note that it is empty on older rows and no `SCHEMAVERSION` move;
  - add a trailing optional `pCitations` to `GuardedFinish`, `AppendEntry` and `GuardedAppend`, threaded from `pOutcome`;
  - `GuardedView` and `GuardedRows` emit `citations` (parsed array, `[]` when empty).
- `Prompt.cls` -- the sentence swap, verbatim from Boundaries.
- `src/OcuPilot/Test/TurnCitations.cls` (new):
  - unit legs for every Binding and Matching rule: returned, not returned, error result, canonical, composite of 2 parts, parent-scoped, truncated id, order, dedupe, cap;
  - a stubbed turn (`TurnProvider`: users read, then text) whose poll and restored row carry the citation.
- `TurnNavigate.cls:484` -- assert the new sentence, and that "offer to select" is absent.
- `TurnWire.cls:134`, `:237` -- add `citations` to the pinned key sets.
- `ui/src/app/core/citations.ts` (new, framework-free, AD-19):
  - the `Citation` type;
  - `parseCitations(value)` (allow-list rule);
  - `acceptsEntityId(screen)`;
  - `citationPresence(rows, truncated, screen, id)` returning `'present' | 'absent' | 'unknown'`;
  - `formatCitationAbsent(label)`.
- `ui/src/app/core/navigation.ts` -- `entityUrl`. `agent-navigator.ts` `act()` uses it.
- `ui/src/app/core/turn.ts` -- `TurnEntry.citations`, set in the three constructions.
- `ui/src/app/core/reply.ts`:
  - `parseReply(text, {origin, citations?})`;
  - a new node kind, `{kind:'citation', citation}`, for a matching codespan outside a link;
  - `'button'` in `ReplyTag` and `REPLY_TAGS`.
- `ui/src/app/shell/reply.ts`:
  - `citations` input and `cite` output;
  - `buildNode` makes the button and records element-to-citation in a `WeakMap`;
  - one delegated `(click)` on the root emits `cite`;
  - `'type'` in `ALLOWED_ATTR`.
- `ui/src/app/shell/citation-navigator.ts` (new, root-provided):
  - `open(citation)`: the allow-list re-check, `navigateByUrl(entityUrl(...))`, then the presence rule on `ScreenStores.for(...)`;
  - it exposes the absent keys, subscribable, and releases any earlier pending check on each open.
- `ui/src/app/shell/panel.ts`:
  - `PanelTurnView.citations`;
  - `<app-reply [text]="turn.reply" [citations]="turn.citations" (cite)="onCite($event)">`;
  - after that reply div, one `<p class="ocu-citation-absent" role="status">` per absent citation of that turn;
  - mirror the navigator into a signal.
- `ui/src/app/core/strings.ts` -- append `citationAbsent: '<name> is no longer present on this instance, so there is nothing to select.'` with its reference, and renumber `taskCreate` `:600`→`:601`.
- EXPERIENCE.md:
  - Append this row after `:559`: `| "<name> is no longer present on this instance, so there is nothing to select." | a citation chip whose row no longer resolves when clicked (Story 11.4, AD-37); the screen still opens [ADDED 2026-09-25 - Story 11.4] |`.
  - Amend `:248` in place: the reply "names the rows it used in backticks, and each one a read returned renders as a citation chip that selects the row (Story 11.4, FR-71); it no longer offers to select them".
  - Amend `:584` in place: drop the "Shall I select them?" example, and add "a row it cites renders as a citation chip".
- `ui/tools/strings.test.mjs` -- raise the band only if the count passes 1100, to 1150, citing Story 11.4.
- `ui/src/styles/_components.scss`, your own block -- `.ocu-reply-citation`, as a code-typography outlined button with a focus ring and tokens only, and `.ocu-citation-absent`.
- Tests:
  - `ui/tools/citation-chips.test.mjs` (new): `parseCitations`, `entityUrl`, `acceptsEntityId`, `citationPresence`.
  - `ui/tools/reply.test.mjs`: chip node, span not cited, inside a link, fenced.
  - `ui/tools/turn.test.mjs`: both parse paths, and missing becomes `[]`.
  - `ui/src/app/shell/reply.spec.ts`: button DOM, the hostile label as text, and a click emits.
  - `ui/src/app/shell/citation-navigator.spec.ts` (new): URL, the refused navigation, and present, absent and unknown.
  - `panel.spec.ts`: append `describe('Story 11.4')` covering the chip after the final reply, the absent line, and streamed-vs-plain equality with citations in both final polls.
- `ui/browser/citation-chips.browser-spec.mjs` (new) -- with the probe definition:
  - (a) a scripted users read, then "`_SYSTEM` and `NotARow` …" from Home: one chip; `NotARow` is `code`; the click lands on `permissions/users/_SYSTEM` with the row `aria-selected`; after a reload the chip is restored;
  - (b) create `OcuPilotCiteGone`, cite it, delete it, click: the sentence shows, with no `role="alert"` strip; the user is removed in `finally`.

**Acceptance Criteria:**

- **AC1.** Given a turn whose read tool returned rows and whose final reply backticks some of their ids, when the turn finishes (live or restored), then the reply renders a chip for each cited returned row and no chip for any other span.
  - Pinned by `TurnCitations` and browser (a).
- **AC2.** Given a chip, when it is clicked, then the browser opens the cited screen with that row selected through `entityUrl` and `navigateByUrl`. The route must be one the registry builds and the id must be encoded by `encodeEntityId`, and the chip has no `href`.
  - Pinned by `citation-navigator.spec.ts` and browser (a).
- **AC3.** Given the built-in prompt, when it is read, then it carries the new citation sentence verbatim and no "offer to select" instruction, while every `ScreenGrounding` statement still holds.
  - Pinned by `TurnNavigate` and `ScreenGrounding`. "Shorter" is live-check evidence only.
- **AC4.** Given a chip whose row was deleted, when it is clicked, then the screen opens without a refusal and the panel shows the absent sentence.
  - Pinned by `citation-chips.test.mjs`, the navigator spec and browser (b).
- **AC5 (integration, Rule 1).** Given 11.7's streamed turn and 11.1/11.2's explain turns, when they finish, then they render through the same reply path unchanged.
  - Pinned by `stream-reply` (b), `panel.spec` `:3956` and `explain-screen`.

## Spec Change Log

- 2026-09-26, lead spec gate: the proposed AD-11 paragraph is written into the spine (Rule 20). This spec was planned before Epic 12 merged into the branch (`521e3f72`); Epic 12's branch is gone, so its "stay off Epic 12's hunks" constraints are lifted, but every Code Map line reference in `panel.ts`, `turn.ts`, `strings.ts` and EXPERIENCE.md may have moved (the `taskCreate` citation is now `:613`) and must be re-read before editing. The EXPERIENCE.md restatements at the former `:248` and `:584` are accepted as Rule 5 tier-1 apply-and-report edits.

## Review Triage Log

## Design Notes

**Governing ADs:**

- AD-11: rule 1 (prompt constant), rule 3 (the chip click is user-initiated; it reuses the allow-list), rule 4 (markup-free button), and "A tool the browser fulfils" (the chip reuses its client half).
- AD-13: the triple, one encoder, per-type canonical spelling.
- AD-33 and AD-5: the route comes from the descriptor.
- AD-36: the bounded view is the candidate source.
- AD-37: weak, stored as data; "no longer present".
- AD-14: the selection is the list's own `selectFromRoute`.
- AD-19: `core/citations.ts` is framework-free.
- AD-24: never replayed.
- AD-44: `ns` from the scope.
- AD-8: the arriving screen's gate applies.

No AC contradicts an AD.

**Why inline chips.** The story asks to "click a name in the reply", and the epic context says chips "replace the plain-text row names". A separate chip row would leave the plain names in place. The inline button only swaps which element a matched codespan becomes, and the final-DOM equality still holds because the streamed branch never carries citations.

**Why server-side binding.** The client never holds read rows. The job has them in memory at `AnswerTools` and knows the descriptor, so it builds the triple with the instance's own `EntityRef` rules. The model's spans only pick among rows the instance returned.

**Proposed spine amendment (Rule 20, for the lead).** Append to AD-11 after rule 4's paragraph:

> A citation chip is a reference, not a navigation proposal. The instance derives it when the turn ends, from the backticked spans of the final reply that equal a row a read tool returned in that turn (the AD-13 triple plus the descriptor's route), and stores it with the turn as data (AD-37). A click is user-initiated and opens the row through the navigation tool's own allow-list and URL builder, so it is not announced (Story 11.4).

**Scope decisions (Rule 27).** Left out:

- chips from `screen_context` rows (client-supplied);
- chips for parent-scoped, `none`-id and multi-part composite screens and `ErrorRead`;
- more than 20 chips per reply;
- a DESIGN.md component entry;
- a server-side presence probe (presence is the arriving screen's own read).

**amendments (Rule 5, apply-and-report):** EXPERIENCE.md `:248` and `:584` are restated in place to match AC3. No AC or AD changes.

**Integration ACs.**

- **Consumes:**
  - Story 4.6's renderer;
  - Story 4.7's navigation and `selectFromRoute`;
  - 11.9's prompt;
  - 11.7's stream pin.

  The consumer ACs run on the throwaway in browser (a) and (b).
- **Consumed-by:**
  - 14.8's seeded-injection test: a chip makes no request and moves only on a click;
  - 17.7, the owner's live check.

**Ledger inbox:** none.

**footprint_extensions:**

- **Contended**, off Epic 12's hunks:
  - `panel.ts`, `panel.spec.ts`, `turn.ts`;
  - `strings.ts` (own tail, plus the `taskCreate` reference).
- **Outside Epic 11's footprint:**
  - `Kernel/State/{Turn,Entry,Convo}.cls`, `Test/TurnWire`, `Test/TurnNavigate`;
  - `core/navigation.ts`, `shell/agent-navigator.ts`;
  - `_components.scss` (own block), EXPERIENCE.md, `strings.test.mjs`.

## Verification

**Slot and instance.** Slot A; every IRIS MCP call carries `server: "ocupilot-slot-a"`. Stateful checks run only on `ocupilot-ci`.

- Load with `bash /tmp/epic-11-lead/load.sh` and read `LOADRESULT`/`ERRCOUNT`.
- Before any browser run: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci` exported.
- Bundle warning at 1670 kB (standing ruling).

**Commands:**

- `uv run scripts/check-objectscript.py && bash scripts/lint-docs.sh` -- expected: clean.
- **(loop)** One class per call: `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, for `TurnCitations`, `TurnWire`, `TurnNavigate`, `ScreenGrounding`, `TurnLoop`, `TurnTools` and `TurnGrounding`.
  - Expected: green, confirmed by the `%UnitTest_Result` probe, and never re-submitted.
- **(loop)** `cd ui && npm run test:tools && npm run test:components` -- expected: green.
- **(loop)** `cd ui && node --test --test-concurrency=1` over `browser/citation-chips`, `stream-reply`, `reply`, `navigate` and `explain-screen` (`.browser-spec.mjs`), against the redeployed bundle. Expected: green.
- **(once, before dev_complete)** The full ObjectScript sweep on `ocupilot-ci`, reported as "N ran, 13 refused (arming), 1 known residue". Then `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS`. The full browser suite runs in CI only.

**Pinning mutations (Rule 19).** Apply each, rebuild or recompile the whole package, observe red, revert, and confirm `git status --short` is unchanged. Record each as `mutation: ... -> ...`.

- AC1: `Run` leaves `citations` empty → `TurnCitations` stubbed-turn leg goes red, and browser (a) goes red.
- Binding: `Cite` accepts any backticked span → the `TurnCitations` "not returned" leg goes red.
- AC2: `entityUrl` drops `encodeEntityId` → `citation-chips.test.mjs` goes red, and browser (a) goes red.
- AC2: the chip renders as `<a href>` → `reply.spec.ts` goes red.
- AC3: restore the old sentence → `TurnNavigate` goes red.
- AC4: `citationPresence` answers `unknown` for no match → `citation-chips.test.mjs` goes red, and browser (b) goes red.
- AC5: the panel passes `turn.citations` only to a turn that never streamed → the `panel.spec` equality leg goes red.

**Manual check (extra evidence, never the proof).** Use the owner's live-key rules. On `permissions/users`, ask "Which users hold %All?". The reply names the accounts as chips, has no "Shall I select" offer, and a chip selects its row.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
