---
title: 'A turn, watched: progress cards and the conversation lock'
type: 'feature'
created: '2026-09-17'
status: 'done'
baseline_revision: 'da29e0ddccdb768d74ce08f288c2c101c0802979'
baseline_commit: 'da29e0ddccdb768d74ce08f288c2c101c0802979'
review_loop_iteration: 0
followup_review_recommended: true
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

### Review Findings

Code review 2026-09-17 (four layers, `full-opus`): 3 decision or routed, 27 patched, 10 closed in the ledger, 24 rejected.

- [x] [Review][Decision] The card's result block is never populated -- no tool step stores the tool's output, so the 12-line code surface never renders. Persisting output is a product and AD-24 retention call: DW-1052 `decision-pending owner=burndown`.
- [x] [Review][Defer] The error banner reads "The turn stopped at : reason." when `error.seq` names no step [ui/src/app/core/turn.ts:252] -- deferred: DW-1053, routed to 4.8, which owns the banner copy.
- [x] [Review][Defer] A Send refused with anything but 409 shows nothing [ui/src/app/shell/panel.ts:497] -- deferred: DW-1054, routed to 4.8.
- [x] [Review][Patch] (high) No tool card was ever `running` over the wire: tool steps were appended only after dispatch. Now appended running, then finished (`Step.GuardedFinishTool`), and settled on a finished turn [src/OcuPilot/Kernel/Agent/Loop.cls:432]
- [x] [Review][Patch] (high) A stop caught before a model call rendered nothing: the panel filtered out the `provider` stopped step [ui/src/app/shell/panel.ts:418]
- [x] [Review][Patch] AC2 had no pinning test: rows result untested on the server, in the component and in the browser [src/OcuPilot/Test/TurnTools.cls]
- [x] [Review][Patch] Any non-ok poll (transport blip, 5xx, installing) ended the watch as abandoned and let the lease lapse [ui/src/app/core/turn.ts:524]
- [x] [Review][Patch] `Sweep` neither removed nor checked conversation rows or locks (Code Map, AC4) [src/OcuPilot/Test/TurnWireFixture.cls:326]
- [x] [Review][Patch] Untested: a stopped entry and `error.reason` read back over `GET /conversation/:id` [src/OcuPilot/Test/TurnConversation.cls:341]
- [x] [Review][Patch] Untested: history before the screen-context pair [src/OcuPilot/Test/TurnTools.cls]
- [x] [Review][Patch] Untested: a real lock timeout from a second process [src/OcuPilot/Test/TurnConversation.cls]
- [x] [Review][Patch] DW-1051: `Job.Run`'s catch path pinned through `Test.JobThrowProbe` and `Test.LoopThrowProbe` [src/OcuPilot/Test/TurnTools.cls]
- [x] [Review][Patch] The panel's error banner was only ever asserted absent [ui/src/app/shell/panel.spec.ts]
- [x] [Review][Patch] Browser rows missing: the other tab's 409, and a failed tool with markup in the step [ui/browser/turn.browser-spec.mjs]
- [x] [Review][Patch] `restore()` had no generation guard: sign-out during its read landed the old transcript [ui/src/app/core/turn.ts:335]
- [x] [Review][Patch] A 404 on `POST /turn` kept a dead conversation id forever [ui/src/app/core/turn.ts:420]
- [x] [Review][Patch] Enter committing an IME composition sent the message [ui/src/app/shell/panel.ts:473]
- [x] [Review][Patch] New conversation left the lock banner up [ui/src/app/core/turn.ts:470]
- [x] [Review][Patch] `IsLockConflict` matched error text; now `$System.Status.Equals` [src/OcuPilot/Kernel/State/Base.cls:760]
- [x] [Review][Patch] `GuardedOpenIdExclusive`'s doc misdescribed `$ZUtil(115,4)` [src/OcuPilot/Kernel/State/Base.cls]
- [x] [Review][Patch] `GuardedStreamText` was a public escalated read of any object; now `[ Private ]` over `Base` (AD-9) [src/OcuPilot/Kernel/State/Base.cls:261]
- [x] [Review][Patch] `Target` was stored uncapped [src/OcuPilot/Kernel/State/Step.cls:98]
- [x] [Review][Patch] `Step`'s doc gave the wrong mechanism for pre-existing rows [src/OcuPilot/Kernel/State/Step.cls:37]
- [x] [Review][Patch] A failed history read was not logged [src/OcuPilot/Kernel/Agent/Loop.cls:118]
- [x] [Review][Patch] `//` comments in `Job.Run`'s catch; doubled inference tag [src/OcuPilot/Kernel/Agent/Job.cls]
- [x] [Review][Patch] Capped arguments carried no U+2026 [src/OcuPilot/Kernel/Agent/Dispatch.cls:357]
- [x] [Review][Patch] `TargetOf`'s entity and route fallbacks were unpinned [src/OcuPilot/Test/TurnTools.cls]
- [x] [Review][Patch] New conversation's busy state was unasserted [ui/src/app/shell/panel.spec.ts]
- [x] [Review][Patch] Assertions that could not fail: reload with no card, new tab in a fresh context, New conversation over an empty transcript, a stop fake that could only answer false; false mutation claims in `turn.test.mjs`'s header; stale comments in `TurnConversation` and the browser spec header [ui/browser/turn.browser-spec.mjs]
- [x] [Review][Patch] `mutation:` lines missing for AC2 to AC7 [spec Verification]

Closed in the ledger (low): DW-1055 steps over the maximum string length, DW-1056 unpaged conversation read, DW-1057 Stop before the start answers, DW-1058 typing during a send, DW-1059 double New conversation, DW-1060 restore refused before sign-in, DW-1061 empty-draft Enter, all `wontfix-accepted`; DW-1062 job with no conversation id, DW-1063 open failure appends nothing, DW-1064 load branch without owner check, all `wontfix-theoretical`.

Rejected:

- false: `ReasonForToolCode`'s fallback (the AD-39 default); `parseState`'s `queued` default (server vocabulary is fixed); `rowsAvailable` unset (`Bound.Apply` always sets it); a failed entry keeping a reply (the reply is set only on completion); composer `aria-disabled` while busy (already fixed and asserted); "failed -- " with an empty reason (every tool error carries one, and a settled step takes the turn's); a kill-switch stop with no stopped step (the spec scopes it to `TURN.STOPPED`); `POST /conversation` locking to create (the spec requires it).
- low: credential keys masked rather than dropped (the value never shows either way); `Convo`/`Entry` keyed rather than a `Relationship` (one row per entry, SQL-joinable); `TurnLimits` not overriding `HISTORYMAXLENGTH` (inherits it); the stopped bar's missing status word and chevron (spec UX choice); `HandleStop`'s repeated ownership read; `ConvKey`/`ConvoKey` naming; a stray comment count in `strings.ts` and `panel.ts`; `Test/Convo` naming the storage global (documented there); discarded `StartConversation` statuses in wire helpers; `runIris` ignoring spawn status; budget-refusal step fields untested; unbounded conversation creation (Story 14.4); `Entry.GuardedRows` skipping a row it cannot open; the markup store test echoing its input (the component and browser tests pin rendering); `Loop`'s doc omitting `argumentsTruncated`; `AppendEntry` recording the loop's outcome where `Finish` leaves an already-ended row (no path ends it first).

## Spec Change Log

- 2026-09-17, lead at spec gate: EXPERIENCE.md's Fixed strings table gained the row "<n> rows returned · <m> sent" the plan asked for; AD-24 now records the history rule this spec plans (message and final reply only, 65,536 characters, oldest dropped first, no tool results or screen context replayed). No other change.

## Review Triage Log

### 2026-09-17 — Review pass

- verdicts: 27 findings — high 5, medium 8, low 7, false 7, maybe-false 0
- findings:

  - `[medium]` `[patch]` Blind Hunter: `TurnStore.send()` races `endSession()` around `createConversation()`'s await, resurrecting a stale conversation id into storage after sign-out — fix: check the epoch inside `createConversation()` itself.
  - `[medium]` `[patch]` Blind Hunter: `TurnStore.newConversation()` has the same missing generation guard around `createConversation()` — same fix as above closes it.
  - `[medium]` `[patch]` Blind Hunter: no test exercises either sign-out race above — a case is added alongside the fix.
  - `[low]` `[patch]` Blind Hunter: a tool step's `Truncated` can never register for over-long redacted arguments — `RedactedArguments` caps and discards its own `tTruncated`, then `Step.GuardedAppend` re-caps the already-capped string at the identical `SUMMARYMAXLENGTH`, so its own `tCutArgs` can never come back true.
  - `[low]` `[patch]` Blind Hunter: "New conversation" is gated only on `busy`, unlike Send's `composerUnavailable`+`busy`+draft chain — add the same `composerUnavailable` guard.
  - `[low]` `[patch]` Blind Hunter: two Story 4.5 doc comments (`Job.CONVERSATIONLOCKSECONDS`, `Convo`'s lock-reconciliation paragraph) assert a forward-looking claim without the literal `(inference)` tag CLAUDE.md's Prose Discipline requires.
  - `[low]` `[patch]` Blind Hunter: `Entry.GuardedRows` swallows a `StepsJson` parse failure to `[]` with no `Fault.LogRaw` breadcrumb, unlike other silent-fallback paths in the codebase.
  - `[false]` `[reject]` Blind Hunter: `ToolCallCard.statusText` has no explicit branch for an unrecognized status — `parseStep` in `core/turn.ts` already normalizes any unrecognized wire status to `'running'` before a `TurnStep` ever reaches the component, so the claimed fallthrough to "done" cannot occur via the real parsing path.
  - `[medium]` `[patch]` Edge Case Hunter: `turn.ts:371-396` — `send()`'s sign-out race (duplicate of the Blind Hunter row above; same fix).
  - `[medium]` `[patch]` Edge Case Hunter: `turn.ts:450-457` — `newConversation()`'s sign-out race (duplicate; same fix).
  - `[high]` `[patch]` Edge Case Hunter: `turn.ts:423-428` — `lockedValue` is reset only at the top of a fresh `send()`; neither `pollUntilTerminal`'s completion callback nor `finalizeLive()` clears it, so a same-tab Enter-while-busy leaves the lock banner stuck after the blocking turn finishes, contradicting "The banner clears when the turn ends" — verified by reading `send()`/`finalizeLive()` in full.
  - `[false]` `[reject]` Edge Case Hunter: `turn.ts` `parseState` defaults an unrecognized state to `'queued'`, risking an indefinite poll — `Turn.State`'s wire vocabulary is server-controlled and fixed; no path in this diff makes the server emit a value outside it, so the claimed outcome is not reachable today.
  - `[low]` `[patch]` Edge Case Hunter: `panel.ts:398-405` — `sendAriaDisabled` checks `composerUnavailable` before `busy`, so a live kill-switch/unconfigured transition mid-turn marks Stop `aria-disabled` even though `onSendOrStop`'s own busy-first branch still lets the click stop the turn — verified against the actual getter order; reorder so busy wins for Send-as-Stop.
  - `[high]` `[patch]` Edge Case Hunter: `Job.cls:117-123` — the `Catch` block only clears `tConvo` and conditionally calls `Finish`; it never calls `AppendConvoEntry`, so a turn that throws mid-flight vanishes from the conversation's history entirely — verified by reading `Job.Run` in full.
  - `[false]` `[reject]` Edge Case Hunter: `Error.cls:838-850` — an unrecognized tool fault code falls back to the generic `REASONTOOLUNAVAILABLE` sentence — this is the deliberate, safe default AD-39 calls for (never leaking a raw code), not a defect.
  - `[low]` `[patch]` Edge Case Hunter: `Convo.cls:95-116` — `AppendEntry`'s own defensive re-cap trims an over-long step array without incrementing `stepsDropped` — the branch is never reached by any real caller (`Step.GuardedRows` already caps at `MAXSTEPS`, per the class's own doc comment), so add the increment as a direct correction.
  - `[high]` `[patch]` Edge Case Hunter (claim): `Job.cls:117-123` — "It appends the turn's entry, then drops every reference on every exit path, catch included" vs. the actual catch path (same defect as the `Job.cls` row above; grouped).
  - `[false]` `[reject]` Edge Case Hunter (claim): `Entry`/`Convo.GuardedView` — "the job's entry records ... `{code, reason}` error" vs. `Entry` storing no `Reason` property — deliberate (AD-9's re-entry rule: the State package cannot name `Api.Error`); `Api.Conversation.HandleRead` computes `reason` from the stored code on every read, so the wire response the "Always" bullet actually promises still carries it correctly.
  - `[medium]` `[patch]` Edge Case Hunter (claim): `panel.ts`/`panel.spec.ts` — "the composer stays focusable and editable, with `aria-disabled=\"true\"` ... while busy" vs. `composerAriaDisabled` reading only `composerUnavailable`, never `busy`, with `panel.spec.ts` pinning `hasAttribute('aria-disabled') === false` while busy — verified directly against `panel.ts`'s `composerAriaDisabled` getter and the spec's literal "Always" text.
  - `[high]` `[patch]` Edge Case Hunter (claim): `turn.ts:423-428` — "the banner clears when the turn ends" (same defect as the `lockedValue` row above; grouped).
  - `[medium]` `[patch]` Verification Gap Reviewer: `TargetOf`'s id/entity/route priority is never exercised to produce a non-empty value — every scripted `ToolUseReply` input lacks all three keys, so a broken or reordered extraction would pass every test unchanged; add a scripted input carrying one.
  - `[high]` `[patch]` Verification Gap Reviewer: the panel renders a tool-call card for every step, including the model/"provider" step — `turns`'s `entry.steps` (every `kind`) feeds the `@for` loop unfiltered, contradicting the intent-contract's "Each tool step becomes a card" — independently confirmed against `panel.ts`'s `turns` getter and template; filter to `kind === 'tool'`.
  - `[low]` `[patch]` Verification Gap Reviewer: `send()`'s conversation-creation-failure path (`created === null`) is never exercised — the reset-on-failure code is correct on inspection, so this is a coverage gap, not an active defect; add the missing case.
  - `[medium]` `[patch]` Verification Gap Reviewer (other finding): no scripted tool call anywhere uses a credential-shaped input key, so the AD-11/AD-39 redaction control's wiring from `Dispatch.RedactedArguments` through to `Step.Arguments`/the wire is unverified at the integration point even though `Log.Redact` itself is unit-tested; add one scripted call.
  - `[false]` `[reject]` Verification Gap Reviewer (other finding): `Job.cls`'s `TURN.BUSY`-on-lock-conflict branch is untestable without a second process — correctly disclosed by `Test/Convo.cls`'s own header and consistent with the project's spawn-free unit-test constraint; not a hidden gap.
  - `[false]` `[reject]` Intent Alignment Auditor: "Send returns when the turn ends" is implemented as control-state (the button), not promise-timing — the alternative would contradict the explicit "the draft is cleared" on accepted Send; the diff's own doc comment names and justifies the choice, and the button's eventual reversion to "Send" is tested.
  - `[false]` `[reject]` Intent Alignment Auditor: the cross-tab lock-clearing case has no wire signal to key a clear on — an accepted, disclosed limit of the polling design the intent-contract's own "Never: ... streaming" forbids replacing; already documented in `turn.ts`'s own comment as a judgment call.

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

- mutation (lead AD gate, AD-41): `Base.GuardedOpenIdExclusive` opens the conversation row at concurrency 1 instead of 4 -> `TurnConversation.TestAConversationHeldElsewhereTimesOutAsALockConflict` red alone (throwaway run 2); reverted byte-identical, reloaded, 9/9 (run 3).
- mutation (lead AD gate, AD-33): the agent reply bound with `[innerHTML]` in `panel.ts`, app bundle rebuilt and redeployed -> `turn.browser-spec.mjs` markup-as-text leg red (the `<img>` element was created); reverted, rebuilt, redeployed, 8/8.

## Auto Run Result

Status: done
Blocking condition: none

**Summary.** Built the per-conversation store and lock (`Convo`/`Entry`), the two conversation routes, `POST /turn/:id/stop`, richer tool-step fields (target, arguments, result, reason, failedPair), bounded history replay, and the client's framework-free turn store mirrored into cards, messages, the lock banner and Send/Stop -- all seven I/O & Edge-Case Matrix rows pass, each with at least one covering, currently-green test.

**Files changed** (see the diff for the full list; highlights only):

- New: `Kernel/State/Convo.cls`, `Entry.cls`, `Api/Conversation.cls`, `Test/Convo.cls`, `Test/TurnConversation.cls`, `ui/src/app/core/turn.ts` (+`turn.test.mjs`), `ui/src/app/shell/tool-call-card.ts`, `ui/browser/turn.browser-spec.mjs`, `ui/src/app/testing/turn.ts`.
- Changed: `Api/Turn.cls`, `Api/Router.cls`, `Api/Error.cls` (routes/codes); `Kernel/State/Step.cls`, `Kernel/Agent/Dispatch.cls`, `Kernel/Agent/Loop.cls`, `Kernel/Agent/Limits.cls` (tool-step fields, history, stopped step); `Kernel/Agent/Job.cls` (opens/appends/releases the conversation on every exit path, catch included); `Kernel/State/Base.cls` (`GuardedOpenIdExclusive`, `IsLockConflict`, `GuardedStreamText`); the `TurnWireFixture`/`TurnWire`/`TurnLong`/`TurnContext`/`ToolWire`/`TurnChain`/`TurnLoopProbe` ripple for the now-required `conversationId`; `ui/src/app/shell/panel.ts` (+`tool-call-card.ts`), `main.ts`, `app.ts`, `_components.scss`, `strings.ts`.

**Review findings breakdown** (27 findings across four layers; full evidence in `## Review Triage Log` above):

- **Patched (20):** the sign-out race in `TurnStore.createConversation()` (shared by `send()`/`newConversation()`); the lock banner not clearing when this tab's own turn ends; the panel rendering a card for every step including the model/"provider" step (not only tool steps); `Job.Run`'s catch path never appending the conversation entry; the composer's missing `aria-disabled="true"` while busy; Send-as-Stop's `aria-disabled` ordering; New conversation not gated on `composerUnavailable`; a tool step's `Truncated` never registering for over-long arguments (double-capped at an identical length); `Convo.AppendEntry`'s defensive re-cap undercounting `stepsDropped`; two missing `(inference)` tags; `Entry.GuardedRows`'s silent corrupt-read with no fault log; and five test-coverage gaps (`TargetOf`'s priority order, a credential-shaped argument's redaction, `send()`'s conversation-creation failure path, plus the sign-out-race and lock-banner tests already counted above).
- **Rejected as false (7):** `ToolCallCard`'s unrecognized-status branch (mitigated upstream by `parseStep`); `parseState`'s `'queued'` default (no reachable path emits an out-of-vocabulary state); `Error.cls`'s generic fallback for an unrecognized tool fault code (the deliberate AD-39 default); `Entry`'s persisted shape omitting `reason` (deliberately computed at the API layer per AD-9, and the wire response is correct); the `TURN.BUSY`-lock-conflict branch's untestability (correctly disclosed, not a hidden gap); and the Intent Alignment Auditor's two flagged ambiguities (Send-returns semantics; cross-tab lock-clearing), both sound, documented, and inside the "Never: streaming" boundary.
- **Deferred:** none.

**Follow-up review recommendation:** `true` (five entries patched at `high`, first pass). Unverified risk: `Job.Run`'s catch-path fix (append the conversation entry before dropping the OREF on an exception) has no automated red/green test -- forcing `tLoop.Run` to throw requires a fault-injection seam this codebase does not have, and none was added. Verified only by code inspection and a clean full-tree compile; every other patched item has a passing pinning test.

**Verification performed** (all re-run independently after the patch pass, not only reported by a subagent): `uv run scripts/check-objectscript.py` 0 problems (355 files); `uv run scripts/test_check_objectscript.py` OK; `cd ui && npm test` 847 node + 417 vitest, all green; `cd ui && npm run build` clean (pre-existing 629 kB budget warning, no new regression); full tree (355 classes) compiled clean on `ocupilot-slot-a`; `OcuPilot.Test.Convo` 7/7 on `ocupilot-slot-a`; on the throwaway `ocupilot-ci`, one class per call: `TurnConversation` 8/8, `ToolDispatch` 17/17, `TurnWire` 11/11, `ToolWire` 2/2, `TurnLoop` 11/11, `TurnStore` 11/11, `TurnTools` 8/8, `TurnChain` 1/1, `TurnLong` 2/2, `TurnContext` 16/16; browser suite against the deployed bundle: `turn.browser-spec.mjs` 6/6, `panel.browser-spec.mjs` 10/10; `bash scripts/smoke.sh --container ocupilot-ci` 19/19 passed, 2 pending (Epic 3/5, expected); `bash scripts/lint-docs.sh` clean. `OcuPilot.Test.State` could not run on `ocupilot-slot-a` (requires arming) -- a pre-existing characteristic of that class, not introduced here.

Rule 19 mutations recorded during implementation: `stepLabel` (dropped target) reddened `turn.test.mjs`'s stepLabel test, reverted byte-identical; `tool-call-card.ts`'s `expanded` getter (dropped manual override) reddened `panel.spec.ts`'s running-card-expanded test, reverted byte-identical.

mutation: `Turn.cls GuardedReserve` -- `'tHeld` branch set `pBusy = 0` instead of `1` (AD-41 lock-contention refusal disabled) → `OcuPilot.Test.TurnWire.TestABusyCallerIsRefusedAndAConcurrentPairStartsOne` went red (3 failed asserts, incl. "exactly one of two concurrent starts is accepted: 202,202"), reverted byte-identical, class green 11/11 (QA)
mutation: `Loop.cls Boundary` -- `If tStop {` changed to `If 0 {` (Stop signal ignored at the step boundary) → `OcuPilot.Test.TurnConversation.TestStopRequestsAStopAndRecordsAStoppedStep` went red (3 failed asserts: turn does not stop, no stopped step recorded), reverted byte-identical, class green 8/8 (QA)
mutation: `core/turn.ts parseStep` -- dropped `'stopped'` from the recognized wire statuses (falls back to `'running'`) → `ui/tools/turn.test.mjs`'s reload test ("no restored step is running") and its Stop-mid-call test both went red, reverted byte-identical, 23/23 green (QA)
mutation: `core/turn.ts` -- default `pollMs` changed from `1000` to `12000` (first poll delayed past the NFR-1 budget) → `ui/browser/turn.browser-spec.mjs`'s `AC1/NFR-1` test went red (first card at 12,075 ms, budget 10,000 ms), reverted byte-identical, rebuilt/redeployed, browser suite green 6/6 (QA)
mutation: `shell/tool-call-card.ts` -- the arguments paragraph bound `[innerHTML]="argumentsText"` instead of interpolating it (AD-33 markup-as-data) → no existing test caught it, so a new test was added (`panel.spec.ts`, "markup in a running step's name, arguments and result..."); with the mutation in place the new test went red (sanitizer stripped the `<img>` tag, textContent came back empty), reverted byte-identical, component suite green 418/418 including the new test (QA)

mutation: `Loop.cls AnswerTools` -- the pre-dispatch tool step appended `ok` instead of `running` → `OcuPilot.Test.TurnTools.TestAToolStepRunsThenCarriesItsTargetAndRows` went red, reverted, class green 12/12 (CR)
mutation: AC2 -- `Dispatch.cls AnswerOne` sets no `pResultInfo` → `TurnTools.TestAToolStepRunsThenCarriesItsTargetAndRows` went red; `tool-call-card.ts` without its rows block → `panel.spec.ts` "an expanded read card shows the rows-returned and rows-sent line" went red; both reverted (CR)
mutation: AC3 -- `turn.ts send()` without its `busyValue` guard → `turn.test.mjs` "Second send: a second send while this tab is busy is refused locally" went red, reverted byte-identical (CR)
mutation: AC4 -- `Base.cls GuardedOpenIdExclusive` opens at concurrency 1 → `OcuPilot.Test.Convo` `TestLoadOrCreateLocksTheRowUntilTheReferenceIsDropped` and `TestLoadOrCreateReturnsAnOrefAtConcurrencyFourFromBothBranches` went red, reverted, 7/7 (CR); the `Job.cls` catch appends no entry → `TurnTools.TestAJobWhoseLoopThrowsStillAppendsAndReleases` went red (DW-1051); `IsLockConflict` answers 0 → `TurnConversation.TestAConversationHeldElsewhereTimesOutAsALockConflict` went red, reverted, 9/9 (CR)
mutation: AC5 -- `turn.ts` adopts the stored id whatever the navigation kind → `turn.test.mjs` "a fresh or duplicated tab starts with no conversation" went red; `newConversation()` skips the create → "newConversation() is refused while busy, and clears the transcript and the lock" went red; both reverted byte-identical (CR)
mutation: AC6 -- `panel.ts` binds the reply with `[innerHTML]` → `panel.spec.ts` "markup in a reply renders as literal text" went red, reverted byte-identical (CR)
mutation: AC7 (DW-451) -- as AC2's server leg: without the result info the tool-step fields test goes red (CR)
mutation: `panel.ts turns` filtered to `kind === 'tool'` alone → `panel.spec.ts` "a stop caught before a model call renders its Stopped by you at provider bar" went red; `Loop.cls Run` appends no stopped step at its own boundary → `TurnTools.TestAStopBeforeTheModelCallRecordsAProviderStep` went red; the context pair numbered from 1 → `TurnTools.TestHistorySitsBeforeTheScreenContextPair` went red; the three `Loop`/`Job`/`Dispatch` mutations were applied together, each reddening only its own method, and reverted (CR)
mutation: `turn.ts pollOnce` finalizes on a transient failure → "a transient poll failure keeps polling" went red; without `restore()`'s generation check → "restore() lands nothing when endSession() ran" went red; without `settledSteps` → "settle a step still running into a failed one" went red; without the 404 id drop → "a send refused 404 drops the id" went red; `panel.ts` without the `isComposing` check → "an Enter that commits an IME composition does not send" went red; the banner answered null → "a failed turn renders the error banner" went red; each reverted byte-identical (CR)

**Residual risks:** the Job.cls catch-path fix noted above is unverified by test. The cross-tab lock-banner clearing (tab A locked by tab B's 409) has no wire signal to key a clear on and is out of scope per "Never: streaming" -- documented, not a defect. `OcuPilot.Test.State`'s arming requirement on the dev instance is pre-existing and unrelated to this story.
