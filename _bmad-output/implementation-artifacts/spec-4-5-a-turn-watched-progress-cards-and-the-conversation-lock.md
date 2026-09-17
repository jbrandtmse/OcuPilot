---
title: 'A turn, watched: progress cards and the conversation lock'
type: 'feature'
created: '2026-09-17'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-4-context.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/harvest/iris-session-agent.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Story 4.1's turn job and progress store have no client: Send is a hard-coded `aria-disabled` no-op, nothing renders progress, there is no Stop route, and no conversation exists on the instance, so a reload loses everything and the model never sees an earlier turn. A tool step records only name, status and code (DW-451), so a read card has nothing to show.

**Approach:** Add a per-user conversation store on the instance, opened by the job under the harvested exclusive-lock protocol, plus a stop route and richer tool steps. On the client, add a framework-free turn store (Send, poll, Stop, New conversation, per-tab restore) that the panel mirrors into cards, messages, the lock banner and Send/Stop.

## Boundaries & Constraints

**Always:**

- `POST /api/ocupilot/conversation` returns 201 `{conversationId}` (32 hex). `GET /api/ocupilot/conversation/:id` returns `{conversationId, turns:[{seq, message, state, reply|null, error|null, steps[], stepsDropped}]}`; a caller who is not the owner, or an unknown id, gets 404 `TURN.CONVERSATION.NOTFOUND`. `POST /api/ocupilot/turn` requires `conversationId`: a missing one is 422 with a `TURN.CONVERSATION.REQUIRED` violation, and one the caller does not own is 404. Both checks run before `GuardedReserve`. `POST /api/ocupilot/turn/:id/stop` calls `GuardedRequestStop` and answers 200 `{stopRequested: true|false}` (false when the turn is already terminal), or 404 `TURN.NOTFOUND`.
- Per-conversation lock (harvested `Chat.History.LoadOrCreate`): one method returns the conversation OREF at concurrency 4 from both branches. The load branch is `%OpenId(id,4)`; the create branch is `%New`, save, close, then `%OpenId(id,4)`. A lock timeout returns NULLOREF, with a status that tells a lock conflict from a persistence failure. The job opens the conversation after `GuardedBegin` and holds the OREF for the turn's life. It appends the turn's entry, then drops every reference on **every** exit path, catch included. `POST /conversation` uses the same method (create branch) and releases at once. 4.1's per-user slot lock stays the AD-41 enforcement.
- The job's entry records the user message, final state, reply, `{code, reason}` error, and the final step projection (at most 100 steps, the rest counted). The next turn's model request carries prior turns in order: each turn with a reply contributes its user message then its reply as an assistant message, and turns without a reply are skipped. This history is bounded by `Limits.HISTORYMAXLENGTH` 65,536 characters, dropping the oldest whole turns, and sits before the `screen_context` pair. Prior tool results and prior context are never replayed.
- A tool step adds `target` (the input's `id`, else `entity`, else `route`, else absent) and `arguments` (compact JSON of the input, any key matching `Kernel/Audit/Log.IsCredentialName` dropped, cut at `SUMMARYMAXLENGTH` with U+2026). On success it adds `result {rowsReturned, rowsSent, truncated}` from `Bound`'s `rowsAvailable/rowsSent/truncated` when rows-shaped. On failure it adds `reason` (the code's published sentence) and `failedPair` when `detail.failedPair` exists. When `Loop.Boundary` stops **by Stop** (`TURN.STOPPED`), the loop appends a `stopped` step named for what it was about to run: the canonical tool name and target, or `provider`.
- Panel: the user message is appended on an accepted Send (202), the draft is cleared, and Send becomes Stop and keeps focus. While busy the composer stays focusable and editable, with `aria-disabled="true"` and the description "A turn is in progress". Polling runs every 1,000 ms until the turn is terminal. Each tool step becomes a card, in `seq` order: a `<button aria-expanded>` whose accessible name includes the status; the running card is expanded, and a completed card collapses unless the user opened it. Status texts are "running" (the spinner is replaced by the word under reduced motion), "done", "failed — <reason>", and "Stopped by you at <step>" (restrained bar, no body, not expandable). The body is the arguments summary, then the result on the code surface, capped at 12 lines and scrolling inside itself. A read also shows the rows-returned and rows-sent line (Design Notes). A completed reply renders as plain text beside the avatar (4.6 swaps in Markdown). A terminal state other than completed or Stop renders the error banner "The turn stopped at <step>: <reason>.", where `<step>` is the name and target of the step at `error.seq` and `<reason>` is `error.reason`. Send returns when the turn ends, with focus unchanged.
- Lock: Enter (without Shift) or Send while busy, or a 409 `TURN.BUSY`, shows the lock banner in `data-slot="lock"` (`role="status"`). The draft is kept, focus does not move, and nothing is appended. The banner clears when the turn ends.
- The conversation id lives in `sessionStorage` (`ocupilot.conversation`) and is adopted only on reload or Back/Forward, using `token-store.ts`'s navigation-kind rule, so a new or duplicated tab starts fresh. On restore, a 404 drops the id. Restored turns render with no running cards. New conversation (header icon button) calls `POST /conversation` and clears the transcript; it is `aria-disabled` with "Stop the turn first" while busy. Sign-out clears the id.
- Every model- or tool-originated string renders through interpolation as text. No `innerHTML` and no sanitizer bypass.

**Never:** a second concurrency bound or relaxing the slot lock; any change to AD-7; screen context assembly, the chip or the paste warning (4.11); Markdown or highlighting (4.6); proposal cards, "done · audit marked" or "blocked by read-only mode" (Epic 5); a transcripts screen or retention (14.4); streaming; persisting the draft; hand-writing a Storage section.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Send, one read | turnprobe: `shell.namespaces.read` then text | user message; card running→done, collapsed; reply text; first card <10 s | none |
| Stop mid-call | provider hangs 4 s returning tool_use; Stop pressed | 200 stopRequested true; card "Stopped by you at shell.namespaces.read"; no reply, no error banner | stop after terminal → false |
| Second send | Enter while busy, or another tab gets 409 | lock banner, draft kept, no message rendered | 409 `TURN.BUSY` |
| Foreign conversation | USERB posts turn / GETs USERA's id | 404 `TURN.CONVERSATION.NOTFOUND` | no slot reserved |
| Reload | after a completed and a stopped turn | both restored, no running card; next turn's recorded provider messages hold turn 1's message+reply only | 404 → fresh conversation |
| Markup in reply/step | reply `<img src="http://203.0.113.9/x">` | literal text; no request off-origin | none |
| Failed tool | privilege missing | card "failed — <reason>"; step carries `failedPair` | none |

</intent-contract>

## Code Map

- `src/OcuPilot/Api/Turn.cls` -- `HandleStart` :28, body keys :13-17, violations :298-309, busy :128-130, 202 :149-151. `HandleProgress` renews the lease :188-191 and adds `error.reason` :192-194. Abandon :205-221. Add `HandleStop` and the `conversationId` check here.
- `src/OcuPilot/Api/Router.cls` -- UrlMap :66-92. Put `/turn/:id/stop` beside `/turn/:id/progress`, and `/conversation/:id` GET before `/conversation` POST (Conventions › REST route ordering).
- `src/OcuPilot/Api/Error.cls` -- `TURN.*` parameters :620-678, the TURN code list :760, sentences :767. Add the two conversation codes.
- `src/OcuPilot/Kernel/State/Turn.cls` -- `GuardedReserve` :140-178, `GuardedBegin` :237-264, `GuardedFinish` :308-331, `GuardedRequestStop` :342-350, `GuardedView` :414-453, sweep :457-473.
- `src/OcuPilot/Kernel/State/Step.cls` -- MAXSTEPS :51-56, cuts :122-130, `GuardedRows` :91-112. Add Target, Arguments, Result, Reason, FailedPair and status `stopped`. These are safe-default additions with no SCHEMAVERSION move; record why at the class.
- `src/OcuPilot/Kernel/State/Base.cls` -- `GuardedSave` :119-131, `GuardedSaveIfCurrent` :154-196, slot lock :306-314. `Sharing.cls` (81 lines) is the per-user store to copy.
- New `src/OcuPilot/Kernel/State/Convo.cls` (27 chars) and child `Entry.cls` (27): a parent-child relationship, weak `UserName` MAXLEN 160, `StepsJson` stream documented as an opaque display payload. Grants and `Test/State.cls StateClasses` derive from the dictionary, and `module.xml` takes the package.
- `src/OcuPilot/Kernel/Agent/Job.cls` -- `Start` :32-52 values, `Run` :59-96 (Finish on every branch). Thread `conversationId` through both.
- `src/OcuPilot/Kernel/Agent/Loop.cls` -- messages :97-127, model step :146-166, `Boundary` :139/:359 with stop at :213-217, tool steps :380/:405, errorSeq :142/:179.
- `src/OcuPilot/Kernel/Agent/Dispatch.cls` -- the bounded result and `detail.failedPair` exist only in content (:15, :26-28, :254, :294-298, :327, :344). Return them to `AnswerTools`.
- `src/OcuPilot/Kernel/Agent/Limits.cls` -- constants :11-54. Add `HISTORYMAXLENGTH`; `Test/TurnLimits.cls` overrides it.
- `src/OcuPilot/Test/TurnProvider.cls` -- `Script(tag,hang,body)` :22-26, `TextReply` :54, `ToolUseReply` :66-86, recorded `messages`. `TurnWireFixture.cls` `StartBody` :266 needs `conversationId` for every existing caller, and `Sweep` must also check conversation rows. `TurnWire.cls` has 462 lines.
- `ui/src/app/shell/panel.ts` -- template :55-147, lock slot :97, transcript :102-118, composer and Send :121-146 (Send hard-coded :136-143), `composerUnavailable` :259-271, `describedBy` :277-281, generation mirror :178-191. `app.ts` sign-out is at :437; the Ctrl/Cmd+I chord is at :44-51 and :307-317.
- `ui/src/app/core/api.ts` -- `requestJson` :328, `JsonResult` :107-121, `scopedPath` :412. `core/token-store.ts` -- `readSessionStorage` :86, `readNavigationKind` :71. `core/panel-layout.ts` -- `setDraft` :169-177, `endSession` :194-200. `core/agent-status.ts` is the store pattern; its test is `tools/agent-status.test.mjs`. It is wired at `main.ts:156,178-184`.
- `ui/src/app/core/strings.ts` -- `actionStop` :117, `actionNewConversation` :119, `toolCallStoppedByYou` :171, `agentTurnStoppedBanner` :173, `agentTurnLockBanner` :175, `accessibilityReducedMotionSpinnerWord` :570. `tools/strings.test.mjs` `EXTRACTED_FROM_PROSE` :209 and the count test :390-422.
- `ui/src/styles/_components.scss` -- `.ocu-panel*` :3001-3295, tokens only.
- `ui/browser/panel.browser-spec.mjs` -- `enabledProbeDefinition` :76-98, `signedInAt` :101-116, sign-out leg :398-411 (DW-1048). `audit.browser-spec.mjs:631-646` is a timing-assertion precedent.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Kernel/State/Convo.cls`, `Entry.cls` -- the store, `LoadOrCreate(id, user, timeout, .status)` as above, a guarded owner read, `AppendEntry`, and `GuardedView` in the GET shape -- conversation state on the instance.
- `src/OcuPilot/Kernel/State/Step.cls`, `Kernel/Agent/Dispatch.cls`, `Kernel/Agent/Loop.cls`, `Kernel/Agent/Limits.cls` -- tool step fields, the stopped step, bounded history -- DW-451 and model continuity.
- `src/OcuPilot/Kernel/Agent/Job.cls` -- open the conversation exclusively after begin, append before finish, and release on every path. A NULLOREF lock conflict finishes the turn `failed` / `TURN.BUSY`.
- `src/OcuPilot/Api/Turn.cls`, new `Api/Conversation.cls`, `Api/Router.cls`, `Api/Error.cls` -- the routes and codes above, as thin wrappers.
- New `src/OcuPilot/Test/Convo.cls` (spawn-free, dev instance) -- both branches: the owner is `$JOB` in `^$LOCK` for the row's lock name; dropping the reference clears it; a persistence failure and a timeout give different statuses; ownership; entry cap; history bound and drop order.
- New `src/OcuPilot/Test/TurnConversation.cls` (armed, throwaway), plus `TurnWireFixture.cls` -- HTTP tests of each new route (status, content type, body): the conversation 404/422 rows, stop true/false/404, tool step fields including `failedPair`, the stopped step, the entry appended per terminal state, and history in recorded provider messages. Existing turn wire classes stay green.
- New `ui/src/app/core/turn.ts` + `ui/tools/turn.test.mjs` -- the store: send (ensuring a conversation first), 1,000 ms poll, stop, lock on busy or 409, restore with navigation-kind adoption, new conversation, endSession. Node tests cover every matrix row with a fake API and clock.
- `ui/src/app/shell/panel.ts` (+ new `shell/tool-call-card.ts`), `_components.scss`, `main.ts`, `app.ts` -- render and wire as above. `panel.spec.ts` covers ARIA, focus retention, Enter vs Shift+Enter, collapsed/expanded, the stopped card without body, and markup rendered as text.
- `ui/src/app/core/strings.ts`, `ui/tools/strings.test.mjs` -- add "done", "failed — <reason>", "A turn is in progress" and "Stop the turn first" by extending the prose extraction from EXPERIENCE.md, plus the Design Notes row once the lead lands it.
- New `ui/browser/turn.browser-spec.mjs` -- seed the turnprobe definition and scripts via `docker exec <OCUPILOT_BROWSER_CONTAINER> iris session` with `TurnWireFixture`/`TurnProvider`, then run every matrix row in a real browser. `panel.browser-spec.mjs` -- wait for `#ocu-panel-composer` before the :404 evaluate (DW-1048).

**Acceptance Criteria:**

- Given an enabled turnprobe definition scripted with a read then a reply, when Send is clicked in the browser, then the first card is visible within 10,000 ms of the click, measured in the spec, and the final reply follows (NFR-1 over OcuPilot's own path).
- Integration: given the panel on the throwaway, when Send is pressed, then the panel's own request reaches Story 4.1's `POST /turn` with the conversation id, and its poll renders the step records the job wrote, including 4.2's read with `rowsReturned`/`rowsSent` from 4.4's `Bound`. This is observed in the DOM, not in the store.
- Given a turn is running, when Enter is pressed in the composer, then the lock banner shows, the draft is unchanged, focus stays, and the transcript's message count is unchanged. When the same user's other tab sends, it receives 409 and shows the same banner.
- Given `LoadOrCreate` is called for an existing id and for a new id, then each returns an OREF whose row lock this process owns, and dropping the OREF releases it. A job whose loop throws still leaves no conversation lock and no slot lock (`Sweep`).
- Given a completed turn, when the page reloads, then that tab restores the turn with no running card, a new tab shows an empty transcript, and after New conversation the next turn's recorded provider messages carry no earlier turn.
- Given a reply or step carrying markup and an off-origin image URL, when it renders, then the text is literal and the browser records no request to any other origin.
- DW-451 is closed by the tool step fields above; DW-1048 by the composer wait, with the full browser suite green once.

## Spec Change Log

- 2026-09-17, lead at spec gate: EXPERIENCE.md's Fixed strings table gained the row "<n> rows returned · <m> sent" the plan asked for; AD-24 now records the history rule this spec plans (message and final reply only, 65,536 characters, oldest dropped first, no tool results or screen context replayed). No other change.

## Review Triage Log

## Design Notes

**Governing ADs:** AD-7 (unchanged; Stop sets the flag), AD-9 (the job opens the store after its spawn, never from an escalated frame), AD-11 and AD-33 (text-only rendering, no egress), AD-19 (framework-free store, mirrored), AD-20 (absolute API paths), AD-24 (rows sent on the read card), AD-31 (polls renew the lease), AD-39 (`reason` for the screen, `code` for tools), AD-41 (slot lock enforces; the banner is the affordance), and Conventions (29-character names, `RowVersion`, an HTTP test per handler).

**Lock reconciliation (no conflict).** AD-41 and 4.1's `^OcuPilotTurnSlot(user)` bound a user to one turn. The harvested protocol bounds a conversation to one writer. A conversation has one owner, so the slot lock subsumes it in Release 1. Nothing is relaxed or duplicated, and the per-conversation lock is what still holds once Epic 14 makes per-user limits configurable. A concurrency-4 lock outlives the escalated `New $ROLES` frame it was taken in (inference). `Test/Convo`'s `^$LOCK` assertion is what verifies it.

**Why history is in scope.** The PRD glossary (`prd.md:171-172`) defines a conversation as a sequence of turns with one turn at a time, and a transcript as its stored record. The lock only has a purpose if turns share state, and UX-DR62 expects the next reply to know what the last turn did. Prior replies go in as assistant content, never system or user content (AD-11 rule 1).

**Browser NFR-1.** The stub provider answers without waiting, so the 10 s assertion measures the part OcuPilot controls: job spawn, the reserve, the 1 s poll and the render. The PRD itself places model latency outside the target.

**Proposed UX row for the lead** (EXPERIENCE.md Fixed strings, before implementation): `"<n> rows returned · <m> sent"` — expanded read tool-call card result line (AD-24). The strings test refuses any literal EXPERIENCE.md does not carry.

**UX choices where sources differ:** the stop sentence is the card's status (EXPERIENCE.md :377/:512) with DESIGN.md's restrained bar and no body. New conversation is an icon button (UX-DR42). The lock banner sits in the banner stack (EXPERIENCE.md :425), shown only on a second send (:511).

**Consumes:** 4.1 (turn routes, progress contract, `GuardedRequestStop`, slot lock, lease), 4.2 (tool dispatch, shell reads, `detail.failedPair`), 4.3 (panel slots, `PanelState` draft, Ctrl/Cmd+I).
**Consumed-by:** 4.11 (attaches context to this Send), 4.6 (renders `reply` in this transcript), 4.7 (announcements in this log), 4.8 (error banner and step naming), 4.9 (per-call rows beside these steps), Epic 5 (proposal cards and cancel-on-New-conversation), 14.4 (transcripts over `Convo`).

## Verification

**Commands:**

- `cd ui && npm test` -- expected: node and vitest suites green, including `turn.test.mjs` and `strings.test.mjs`.
- `cd ui && npm run build` -- expected: prebuild checkers and build pass.
- `uv run scripts/check-objectscript.py` -- expected: 0 findings.
- Dev instance (`server: "ocupilot-slot-a"`): compile `OcuPilot.PKG`, then run `OcuPilot.Test.Convo` and `OcuPilot.Test.State`, one class per call, totals confirmed in `%UnitTest_Result`.
- Throwaway `bash scripts/ci-throwaway.sh up --dir /tmp/ocupilot-ci --project ocupilot-ci --web 52776 --super 1975`: run `TurnConversation`, `TurnWire`, `TurnLoop`, `TurnStore`, `TurnTools`, `TurnChain`, `TurnLong` and `TurnContext`, one per call. Then `npx ng build`, `docker cp ui/dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, and `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci npm run test:browser` for `turn` and `panel`. For the full suite, rebuild `npx ng build --configuration production,harness` first. Tear down only a throwaway this run brought up.
- `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` -- expected: every check passes and more than zero checks run.
- Rule 19: record one `mutation:` line per AC here as each pinning test lands.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Planned only. Ledger inbox: DW-451 addressed (tool step fields), DW-1048 addressed (composer wait). Lead actions before implement: land the proposed EXPERIENCE.md row in Design Notes. The history-in-scope decision and the lock reconciliation are recorded there for review.
