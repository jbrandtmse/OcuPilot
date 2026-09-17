---
title: 'The context chip, its toggle and the paste warning'
type: 'feature'
created: '2026-09-17'
status: 'done'
baseline_revision: 'f20224304b177b00d5706949d1d2102a364e58ad'
baseline_commit: 'f20224304b177b00d5706949d1d2102a364e58ad'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-4-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Story 4.4 accepts, projects and bounds screen context server-side and publishes `GET/PUT /api/ocupilot/agent/context`, but no client reads either: the chip slot at `panel.ts:148` is empty, `turn.ts:408-411` posts `{message, conversationId}` with no `context`, and the eight chip and warning keys in `core/strings.ts` have no consumer. Nothing tells the user what leaves the instance or where, and nothing warns before a pasted key is sent.

**Approach:** Two framework-free `core/` modules — a store over `/agent/context` and a pure assembler that also answers "does this draft look like a secret" — plus a `shell/context-chip.ts` child in the reserved slot and an inline warning in the panel footer. The Send path assembles the payload fresh from the screen the user is on at the moment of the click.

## Boundaries & Constraints

**Always:**

- **Chip text, sharing on.** `<Screen>, <NAMESPACE>` then ` · ` before each further segment: the row count (`STRINGS.tableRowCount`), `provider`, `endpointHost`. `<Screen>` is `stringFor(screen.labelKey)`, `<NAMESPACE>` is `scope.namespace()`. Every separator glyph is `aria-hidden` (EXPERIENCE.md:637), and the chip is not a live region (it is absent from EXPERIENCE.md:632's roster). Composing with `Users`, `HSCUSTOM`, 6 reproduces `STRINGS.contextChipScreenSegment` byte for byte, pinned by a test.
- **The row segment is omitted** exactly when the turn would post no `view`: the descriptor declares no read or table, its `context.fields` is empty, or it declares any `context.secretFields`.
- **Pill.** Rendered only when `leavesInstance === true`, reading `STRINGS.contextChipLeavesInstance`, with `STRINGS.contextChipSentToHost` (`<host>` replaced by `endpointHost`) as both its `title` and a visually-hidden description. `leavesInstance`, `provider` and `endpointHost` come only from `GET /agent/context`; the client makes no second judgement (AD-42). `leavesInstance: null` renders no pill.
- **Key glyph.** A 14px glyph, itself `aria-hidden`, with `STRINGS.agentContextChipSecretGlyph` as a visually-hidden name, whenever the current screen's `context.secretFields` in `screens.generated.ts` is non-empty.
- **Toggle.** A Material switch named `STRINGS.agentShareContextLabel` reflecting `share`. A change mirrors optimistically, then `PUT /api/ocupilot/agent/context {share}` through the one API service (AD-20, AD-28) and adopts the 200 body; a refusal reverts the mirror and adds no new error surface. The choice is only ever stored on the instance — never in `localStorage` (AD-24).
- **Sharing off.** The chip reads exactly `STRINGS.contextChipSharingOff`; the pill and the row segment go; no `context` is posted.
- **Absent chip.** No enabled definition (`AgentStatus.configured` false) or a store that has not answered leaves `.ocu-panel-chip-slot` empty, which `_components.scss:3149` already hides.
- **Updates.** Route (`router.events`), namespace (`onScopeChange`, `scope.ts:405` — the channel written for this consumer), selection and the screen's filtered and sorted view (`ScreenStore.subscribe`, `screen-store.ts:95`), and `agent-switch` on the `ChangeBus` (a changed `contextRowCap` or instance default) each bump the component's generation signal (AD-19).
- **Send.** `panel.ts` assembles the payload at the click and passes it to `TurnStore.send(message, context)`. Shape: `{route: screen.route, namespace: scope.namespace(), entity?, view?}`, `view = {rows, rowsAvailable, sort, direction, filter}`; `rows` is `applyView(...)` narrowed to the descriptor's `context.fields` and sliced to `contextRowCap`; `rowsAvailable` is the full post-filter count. `context` is omitted entirely when the URL resolves to no descriptor, when `scope.namespace()` is `''`, or when sharing is off. The client's slice is an **additional** bound, never a substitute: `Screen/Context` and `Kernel/Agent/Bound` stay the enforcement point (AD-24, AD-5, AD-36).
- **Paste warning.** Inline in the footer above the composer label, in the `banner` warning treatment (DESIGN.md:1203), `role="status"`, message `STRINGS.agentPanelSecretWarning` with `STRINGS.agentPanelSecretWarningSend` and `STRINGS.agentPanelSecretWarningEdit`. Raised on Send or Enter when `looksLikeSecret(text)` and `text` is not the text a previous Send anyway acknowledged: nothing is sent, the draft is kept, focus does not move. Send anyway sends that text and records it; Edit clears the warning and moves focus to the composer **without** recording it, so an unchanged text is warned about again. The record clears on a sent turn and on `endSession()`.
- **`looksLikeSecret(text)`** is true when the trimmed text starts with `sk-`, `-----BEGIN`, `AKIA`, `ghp_`, `xox` or `AIza`, or when any maximal whitespace-delimited token is at least 24 characters, uses at least three of lower case, upper case, digit and symbol, and contains none of `/ . : ^ (`. A token holding one of those five characters never qualifies, whatever its substrings.
- **No new string-table literal.** Every user-visible literal is an existing `core/strings.ts` key; non-ASCII is authored as `\uXXXX` (Conventions › Client asset homes).

**Never:** a client re-derivation of `leavesInstance`, the endpoint host, the provider, or the secrets backstop list; `localStorage` for the share choice; any server change — 4.4's two routes, `Screen/Context`, `Kernel/Agent/Bound`, `Kernel/State/Sharing`, `Switch` and every `TURN.CONTEXT.*` / `AGENT.CONTEXT.*` code stay exactly as they are; a third "follow the instance default" toggle position; any change to AD-7; hand-editing `screens.generated.ts`; a new `%Persistent` class; Markdown or highlighting (4.6); announcements or agent navigation (4.7); error-banner copy or a refused Send (4.8); ledger rows or usage (4.9); the panel widening over Home or starter prompts (4.10); DW-458 and DW-460.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| List screen, remote provider | Users at `HSCUSTOM`, 6 rows in view, `share` true, cap 200, `leavesInstance` true, host `api.anthropic.com` | chip `Users, HSCUSTOM · 6 rows · Anthropic · api.anthropic.com` plus the pill and its host tooltip | none |
| Local provider | `leavesInstance` false | same text, no pill | `null` also renders no pill |
| Secret-typed screen | `agent/definitions/edit` | key glyph with its name; no row segment; posted context carries no `view` | none |
| Toggle off | switch cleared | chip reads `contextChipSharingOff`; `PUT {share:false}` answers 200; the next Send posts no `context` | PUT refused → mirror reverts, chip re-reads the server's value |
| View changes | filter narrows 6 rows to 2 | row segment reads `2 rows`; the next Send posts 2 rows | none |
| Cap below the view | `contextRowCap` 1, 6 rows in view | chip `1 rows`; posted `rows` length 1, `rowsAvailable` 6 | server's `rowsAvailable >= rows.length` check never fires |
| Namespace unresolved | `scope.namespace()` is `''` | chip absent; Send posts no `context` | avoids 422 `TURN.CONTEXT.INVALID` |
| No enabled definition | `provider` `''`, `leavesInstance` null | no chip at all; the slot stays empty | none |
| Secret-looking draft | `sk-ant-api03-…` pasted, Send pressed | warning shown, nothing sent, draft kept, focus unchanged; Send anyway sends that text; Edit returns focus to the composer | — |
| Non-triggers | `https://localhost:52774/csp/sys/UtilHome.csp`, `%Api.Mgmnt.v2`, `^OcuPilotTurnSlot("_SYSTEM")` | no warning; Send sends | — |

</intent-contract>

## Code Map

- `ui/src/app/shell/panel.ts` -- chip slot `:148` (empty, named for this story at `:48`); banner stack `:115-146` (the lock banner `:140-143` is the `role="status"` precedent); footer `:190-220` with the read-only line `:191`, composer label `:192`, composer row `:193-215`; `sendCurrentDraft()` `:494-500` (the send is `:498`), `onComposerKeydown` `:472-478`, `onSendOrStop` `:481-487`; `composerUnavailable` `:347-350`; `describedBy` `:366-371`; `COMPOSER_ID` `:16`; injections `:224-228`; generation signal `:264` and the subscribe block `:266-278`; `@if` conditions must be paren-free member references (`:73-75`).
- `ui/src/app/shell/tool-call-card.ts` -- the panel-child pattern: `input.required` `:71`, `OnPush` `:30`, `STRINGS` `:73`, view-only local signal `:76`, slot substitution `:138-142`. Registered at `panel.ts:13,80`.
- `ui/src/app/shell/panel.spec.ts` -- `mount()` `:83-123` (providers `:107-118`) needs the new store; four pinned inventories change: buttons `:141-144`, `expect(aside.querySelector('.ocu-context-chip')).toBeNull()` `:147`, banner slots `:166-169`, body order `:171-174`, footer children `:181-187`.
- `ui/src/app/core/turn.ts` -- `send(message)` `:387`, body construction `:408-411`, `TurnStoreOptions` `:257-267`, `endSession` (draft/record clearing) near `:470`.
- `ui/src/app/core/agent-status.ts` -- the store to copy: path constants `:35,44`, `answered()` `:281`, `subscribe()` `:306-311`, `load()`/`read()` `:324-367` with the generation/request/newest stale-answer guard `:245,255,268` and the `connectivity.retryWhenReachable` park `:352`, `reset()` `:374-381`, `agent-switch` re-read `:390-394`.
- `ui/src/app/core/scope.ts` -- `namespace()` `:201`, `subscribe()` `:309`, `onScopeChange` `:405-413` (its doc names the chip as a consumer).
- `ui/src/app/core/screen-store.ts` -- `ScreenStore` `:55`, `subscribe()` `:95`, `data()` `:104`, `selection()` `:186`, `active()` `:196`, `sort/direction/filter/maxRows` `:236,246,256,266`, `truncated()` `:108`; `ScreenStores.for()` `:325-341`.
- `ui/src/app/core/screen-read.ts` -- `applyView(rows, read, {filter, sort, direction})` `:105-139`, `ViewOptions` `:30-34`. `ui/src/app/shell/command-bar.ts:407-419` is the working precedent for a shell component pulling the same view; `:279-282` shows the `screenForUrl` computed.
- `ui/src/app/core/navigation.ts` -- `screenForUrl()` `:396-398`. `ui/src/app/shell/locator-bar.ts:155-166` -- how the entity id and the screen title are read.
- `ui/src/app/core/screens.generated.ts` -- `ContextDeclaration` `:69-75`, `ScreenDeclaration.context` `:265`; the only screen with secrets today is `agent/definitions/edit` (`:446-447`, `:474-479`). Generated; `ui/tools/screen-mirror.mjs --check` enforces it.
- `ui/src/app/core/strings.ts` -- `contextChipLeavesInstance` `:69`, `contextChipSentToHost` `:71`, `contextChipScreenSegment` `:73` (a worked example, not a template), `contextChipSharingOff` `:75`, `agentShareContextLabel` `:306`, `tableRowCount` `:310`, `agentPanelSecretWarning` `:565`, `...Send` `:567`, `...Edit` `:569`, `agentContextChipSecretGlyph` `:571`. `ui/tools/strings.test.mjs` authorizes a literal three ways only (table `:232`, `EXTRACTED_FROM_PROSE` `:253-267`, the closed trio `:440-444`) and pins the exact count `:446-465` -- all ten keys are already authorized, so this story adds none. Helpers: `stringFor` `strings.ts:668`, `formatRowCount` `table-model.ts:99`, `AGENT_SWITCH_ENTITY` `agent-status.ts:50`, `retryWhenReachable` `connectivity.ts:250`, `decodeEntityId` `entity-id.ts:67`.
- `ui/src/app/core/api.ts` -- `requestJson` `:328`, `JsonResult` `:107-121`, `?ns=` attachment `:412-415`. `ui/src/app/core/fault.ts` -- `classifyFault` `:69` for the refused PUT.
- `ui/src/main.ts` -- construction order `:43-185` (`AgentStatus` `:169`, `TurnStore` `:146-151`, `ScreenStores` `:158`, `RefreshService` `:159-164`), provider list `:191-208`. `ui/src/app/app.ts` -- signed-in loads `:446-459`, sign-out clearing `:400-460` (`agentStatus.reset()` `:437`), panel import `:35`, Ctrl/Cmd+I `:314`.
- `ui/src/styles/_components.scss` -- panel block `2995-3321`, `.ocu-panel-banner-slot:empty, .ocu-panel-chip-slot:empty` `:3149-3151`, `.ocu-banner*` variants `:357-392`, `.ocu-visually-hidden` `:3312-3322`; new rules go at `:3322`, before the Story 4.5 header `:3323`. Tokens only, enforced by `client-lint.mjs:11-16`.
- `ui/browser/turn.browser-spec.mjs` -- the browser-spec model: live-container refusal `:38`, readiness `:39-40`, `runIris` `:68-80`, `ensureDefinition` `:89-99`, `scriptReply`/`toolUseReply`/`textReply` `:108-119`, `awaitCall` `:126-131`, `signedInAt` `:134-150`, `typeAndSend` `:152-155`. `ui/browser/panel.browser-spec.mjs` -- `enabledProbeDefinition()` `:76-98`, `removeProbeDefinitions()` `:64-73`, `loadStrings()` `:28`.
- Server contract (read-only reference, unchanged by this story): `src/OcuPilot/Api/Context.cls` -- `HandleRead` `:20`, `HandleUpdate` `:40`, the exactly-one-boolean-member check `:58-66`, the seven-key body `:88-132`. `src/OcuPilot/Api/Turn.cls` -- `ContextViolation` `:322-361`, `Scope.Current()` match `:330`, `rowsAvailable >= rows.length` `:356-360`, share gate `:113-114`, row cap `:104,137`. `src/OcuPilot/Screen/Context.cls:64-69` -- any secret field collapses the payload to identity. `src/OcuPilot/Kernel/Egress.cls:408-430` -- `LeavesInstance`.

## Tasks & Acceptance

**Execution:**

- New `ui/src/app/core/agent-context.ts` + `ui/tools/agent-context.test.mjs` -- the framework-free store over `GET/PUT /api/ocupilot/agent/context` on `core/agent-status.ts`'s shape (`answered`, accessors for all seven keys, `setShare`, `subscribe`, `reset`, `agent-switch` re-read, stale-answer guard) -- the one source of `share`, `contextRowCap`, `provider`, `endpointHost`, `leavesInstance`.
- New `ui/src/app/core/screen-context.ts` + `ui/tools/screen-context.test.mjs` -- pure `assembleScreenContext(inputs)` returning the `POST /turn` shape or `null`, `contextRowsSent(inputs)` for the chip, and `looksLikeSecret(text)` -- the payload and the chip's count come from one function so they cannot disagree, and the draft check is testable under `node --test`.
- `ui/src/app/core/turn.ts` -- widen to `send(message, context?)` and attach `context` at `:410` when it is non-null -- the turn carries the screen.
- New `ui/src/app/shell/context-chip.ts` -- the `.ocu-context-chip` component: text, pill, tooltip, key glyph, switch, and the five subscriptions above.
- `ui/src/app/shell/panel.ts` -- render the chip in the slot behind a paren-free `contextChipVisible` getter, add the inline warning above the composer label, and route `sendCurrentDraft()` / the Enter path through the warning and the assembler.
- `ui/src/styles/_components.scss` -- a `// --- The context chip (Story 4.11)` block at `:3322`: chip box, egress pill, 14px key glyph, switch, and the footer warning, in tokens only, restrained under the kill switch (DESIGN.md:1132).
- New `ui/src/app/testing/agent-context.ts` -- `stubAgentContext()` taking a `Partial` of the seven keys, mirroring `testing/agent-status.ts:24-39`.
- `ui/src/app/shell/panel.spec.ts` -- extend `mount()` with the new provider, update the four pinned inventories, and cover the chip's presence/absence, its text, the pill and tooltip, the glyph, the toggle, the sharing-off sentence, and the warning's three behaviors.
- `ui/src/main.ts`, `ui/src/app/app.ts` -- construct, provide, load after sign-in beside `agentStatus.load()`, and `reset()` in the sign-out block with its one-line reason.
- New `ui/browser/context-chip.browser-spec.mjs` -- the real-runtime legs against the slot-A throwaway: chip text on Users, the pill and tooltip, the glyph on the definition form, the toggle surviving a reload, the warning's two buttons, and the Integration AC below.
- `ui/tools/turn.test.mjs` -- a case that `context` reaches the POST body and that a `null` context omits the key.

**Acceptance Criteria:**

- **Integration:** given the panel on the throwaway with an enabled turnprobe definition and the Users list showing N rows, when Send is pressed, then the turn's recorded provider messages carry the synthetic `screen_context` pair naming that route, that namespace and exactly the N rows the chip displayed, read back through `OcuPilot.Test.TurnProvider`'s recorded messages -- observed off the instance, not in the client store.
- Given the user navigates from one screen to another between two turns, when the second turn is sent, then its posted context names the second screen's route and rows and none of the first screen's, so context is assembled fresh at Send rather than cached.
- Given an operator raises `contextRowCap` on Switches while the panel is open, when the `agent-switch` event lands, then the chip's row count and the next turn's posted `rows` both follow the new cap without a reload.
- Given a screen whose descriptor declares a secret-typed field, when the chip renders and a turn is sent, then the key glyph carries its accessible name, the chip shows no row segment, and the posted context carries no `view`.
- Given the toggle is cleared and the browser is reloaded, when the panel returns, then the chip still reads the sharing-off sentence, because the choice was stored per user on the instance and re-read from `GET /agent/context`.
- Given a draft that trips the warning, when Send anyway is pressed, then that exact text is sent and the warning does not return for it; when Edit is pressed instead, focus lands on the composer, the draft is unchanged, and a further Send warns again.
- Given the three non-triggers in the matrix, when each is sent, then no warning appears and the turn is accepted.

**Review pass (2026-09-17) -- patch items to apply, smallest fix per item:**

- `panel.ts`: `contextChipVisible`'s generation never bumps on a namespace change -- `Panel`'s constructor subscribes to navigation/agentStatus/agentContext/panel/turn/router.events but not `onScopeChange`, unlike `context-chip.ts`'s own subscription, and `scope.ts`'s own doc says a namespace change re-fetches in place rather than re-routing (no `router.events` fires). `app.ts` issues `scope.load()`, `agentStatus.load()` and `agentContext.load()` as three independent, unordered async reads, so a namespace resolving after the other two can leave the chip absent until an unrelated event re-renders the panel. Fix: subscribe to `onScopeChange(this.scope, () => this.bump())` in `Panel`'s constructor and unsubscribe on destroy, mirroring `context-chip.ts`.
- `panel.spec.ts`: no test exercises "the cap follows `agent-switch` without a reload" at the component level -- only `agent-context.test.mjs`'s store-level AD-14 test covers it. Fix: add a Story 4.11 test constructing a real `AgentContext` over a stub API (the existing "a refused PUT reverts the mirror" test is the precedent), changing `contextRowCap` live while `ContextChip`/`Panel` are mounted, and asserting both the rendered row count and the next Send's posted `rows`/`rowsAvailable` follow the new value.
- `panel.ts`: `syncSecretRecord()` treats "no conversation id, no entries, not busy" as a session reset, but a failed send (a conversation-creation failure, or a non-404 refusal of `POST /turn`) on a tab's first turn produces that exact state without `endSession()` or a new conversation ever happening -- so a "Send anyway" acknowledgment is wiped by a transient failure and an immediate identical retry is warned about again, contradicting "the record clears on a sent turn and on `endSession()`". Fix: clear `acknowledgedSecretText` only on `sendCurrentDraft()`'s own `'sent'` outcome (already present) and on the explicit sign-out / new-conversation paths, not from a generic `turn.subscribe` heuristic; add a test sending an acknowledged secret, forcing the send to fail, and asserting the record survives.
- No test asserts `.ocu-context-chip-restrained` toggles with the chip's `killSwitch` input. Fix: add a case mounting with `killSwitch` true and false and asserting the class's presence/absence.
- `agent-context.ts`: `setShare()` returns `true` whenever the PUT answers `kind: 'ok'`, even when `infoOf(result.body)` is `null` (a malformed 200 body) -- the optimistic mirror stands but is never actually adopted from the server, and the caller is told the write succeeded. Fix: when `next === null` on an otherwise-ok response, revert to `previous` and return `false`, matching the refusal branch; add a test for a 200 with a malformed body.
- `app.spec.ts`: the existing "leaving the signed-in state..." test pins `agentStatus.reset()` and `turn.endSession()` at the sign-out site but not the new `agentContext.reset()` call alongside them. Fix: extend that test with a real `AgentContext` and assert `answered()` is `false` immediately after the state leaves signed-in.

## Spec Change Log

- 2026-09-17, lead at spec gate: EXPERIENCE.md's Secret-like message warning row widened to any screen and given the trigger, once-per-draft, Send anyway and Edit semantics the story's AC carries, so the UX row and the AC agree.

## Review Triage Log

### 2026-09-17 — Review pass

- verdicts: 13 findings — high 0, medium 5, low 5, false 3, maybe-false 0
- findings:
  - `[medium]` `[patch]` blind-hunter: `Panel.contextChipVisible` does not react to a `ScopeService` namespace change (no `onScopeChange` subscription in `Panel`'s constructor, unlike `context-chip.ts`) — applied: subscribed to `onScopeChange` in `Panel`'s constructor.
  - `[false]` `[reject]` blind-hunter: `looksLikeSecret`'s exclusion of tokens containing `/ . : ^ (` produces false negatives on JWTs and slash-bearing secrets — refuted: this exact algorithm, including the exclusion list, is specified byte-for-byte in the spec's frozen `<intent-contract>`; the code matches it exactly, so this is the specified behavior, not a defect.
  - `[low]` `[patch]` blind-hunter: no test covers the kill-switch/"restrained" chip state — applied: added a test asserting `.ocu-context-chip-restrained` toggles with `killSwitch`.
  - `[medium]` `[patch]` blind-hunter: no end-to-end test for "the chip's row count follows `agent-switch` without a reload" — applied: added a `panel.spec.ts` test with a real `AgentContext`, changing `contextRowCap` live and asserting the rendered count and the next Send's posted `rows`/`rowsAvailable`.
  - `[medium]` `[patch]` edge-case-hunter: `panel.ts`'s `syncSecretRecord()` clears the "Send anyway" acknowledgment on a failed send (conversation-creation failure or a non-404 `POST /turn` refusal), not only on `endSession()`, contradicting the frozen "clears on a sent turn and on `endSession()`" — applied: the automatic clear now fires only from `sendCurrentDraft()`'s own `'sent'` outcome and the explicit sign-out/new-conversation paths; added a test forcing a send to fail and asserting the acknowledgment survives.
  - `[low]` `[patch]` edge-case-hunter: `agent-context.ts`'s `setShare()` returns `true` on a 200 PUT whose body is malformed, without adopting it — applied: reverts the mirror and returns `false` when the body cannot be parsed, matching the refusal branch; added a covering test.
  - `[false]` `[reject]` edge-case-hunter: `contextRowCap` is not clamped to 1-1000 client-side — refuted: the range is a server-enforced invariant (`Switches.contextRowCap`, unchanged since Story 4.4, AD-24); the client already guards non-positive values from crashing, and adding a further client-side clamp would itself be the "client re-derivation of a server-enforced bound" the intent-contract's Never list forbids.
  - `[low]` `[patch]` verification-gap: `app.ts`'s sign-out call to `agentContext.reset()` has no `app.spec.ts` pin, unlike the sibling `agentStatus.reset()`/`turn.endSession()` calls at the same site — applied: extended the existing sign-out test with a real `AgentContext` asserting `answered()` is `false` after sign-out.
  - `[medium]` `[patch]` verification-gap: same root cause as the blind-hunter "cap follows `agent-switch`" entry above — grouped, same fix.
  - `[low]` `[reject]` verification-gap: `Panel.currentEntityId()`'s wiring into `context.entity` has no test — rejected: no built screen today combines an entity-detail route with declared `context.fields`, so this path is unreachable in the shipped product, and a proper test needs new synthetic route/descriptor scaffolding beyond a direct correction; reopen if a future screen combines the two.
  - `[medium]` `[patch]` intent-alignment: same root cause as the blind-hunter "`contextChipVisible` does not react to scope" entry above — grouped, same fix.
  - `[low]` `[reject]` intent-alignment: same root cause as the verification-gap "`currentEntityId()` untested" entry above — grouped, same disposition.
  - `[false]` `[reject]` intent-alignment: the pill/glyph use a visually-hidden sibling span rather than `aria-describedby`/`aria-labelledby` — refuted: this matches the codebase's established `.ocu-visually-hidden` sibling-span convention (pre-existing, used elsewhere for icon+hidden-text pairs) and satisfies the intent-contract's literal "a visually-hidden description"/"name" wording without requiring an ARIA relationship attribute.

## Design Notes

**Governing ADs:** AD-5 (the descriptor, mirrored into `screens.generated.ts`, is the only source of `context.fields` and `context.secretFields`), AD-11 (the payload is consumed as the synthetic `screen_context` pair, never advertised), AD-19 (framework-free stores mirrored into signals; the chip's subscriptions), AD-20 and AD-28 (absolute paths through the one API service), AD-24 (per-user sharing on the instance; the client's slice is an extra bound, the kernel remains the enforcement point), AD-33 (rendered as data), AD-36 (the tool's view is the screen's view), AD-39 (one envelope; the refused PUT renders no new copy), AD-42 (the pill is computed from the same configuration the request uses), AD-47 (no CDN), AD-48 (error detail never enters context). AD-7 and AD-9 are untouched.

**Where the sources differ, and what was chosen.**

- The warning is inline above the composer (EXPERIENCE.md:528 and DESIGN.md:1145 agree; DESIGN.md:1203 supplies the `warning` banner treatment). It is not one of EXPERIENCE.md:445's seven panel banners and does not join the banner stack at `:426`.
- EXPERIENCE.md:528 gates the warning on being "on a screen with secret-typed fields"; the story's AC (`epics.md:2970`) fires on the draft alone, on any screen. The wider AC is implemented, per the orchestrator's decision. **Proposed UX row for the lead:** widen EXPERIENCE.md:528's trigger to the draft alone, and record the "once per draft text", Send anyway and Edit semantics that only `epics.md:2971` carries today.
- The pill is an element after the chip's text, not a text segment, so no separator literal is needed between the host and the pill -- DESIGN.md:1145 gives it its own background, radius and padding. The two stale mockups disagree with each other and are not pinned.
- A screen with no table posts no `view`, so the chip omits the row segment rather than reading `0 rows`, matching EXPERIENCE.md:712's Home illustration.
- Row counts reuse `STRINGS.tableRowCount` (`<n> rows`) for every value, singular included; neither UX document states a pluralization rule and the data table already reads that way.
- The warning's visibility and the acknowledged text are two view-only signals on `panel.ts`, as `tool-call-card.ts:76` holds its expanded state; the decision logic is the pure `looksLikeSecret`.

**Known boundaries, stated so they are not filed as defects.** `Bound`'s 65,536-character total cut can reduce what the server sends below the chip's count; the user sees the actual figure on the read tool-call card's `<n> rows returned · <m> sent` (Story 4.5). `PUT /agent/context` carries no row version -- that is 4.4's shipped contract for a single-row, single-writer, per-user preference, and this story does not change it. The store is two-state plus row absence, so a user who has chosen can never return to following the instance default; the AC asks for a two-position switch, and a `DELETE` would be a server change this story forbids.

**Consumes:** 4.4 (`GET/PUT /agent/context`, the `context` field of `POST /turn`, `Screen/Context`, `Bound`, `contextRowCap`, `Egress.LeavesInstance`), 4.5 (`TurnStore.send`, the composer and Send/Stop, `endSession`), 4.3 (the chip slot, `PanelState` draft), 2.4 and 1.9 (`ScreenStore`, `applyView`, the descriptor mirror), 1.11 (`ScopeService`, `onScopeChange`), 1.2 (`core/strings.ts`).
**Consumed-by:** 4.7 (navigation changes which screen the next turn's context comes from, and reads this assembler), 4.10 (Home's suggested view sits beside this chip and passes `panel-home`'s width), 4.8 (a refused Send's copy sits over this warning), Epic 5 (a write proposal carries the same assembled context), Epic 11 (citation chips over the rows this posts), Epic 14 (per-user turn limits read the same per-user store shape).

## Verification

**Commands:**

- `cd ui && npm test` -- expected: green, including the two new `node --test` suites, `turn.test.mjs`, `strings.test.mjs` (its exact count unchanged -- this story adds no literal) and `panel.spec.ts`.
- `cd ui && npm run build` -- expected: the six `prebuild` checkers and the build pass; `client-lint.mjs` in particular accepts no literal text node and no raw non-ASCII byte.
- `uv run scripts/check-objectscript.py` -- expected: 0 findings (no ObjectScript changes, so this only guards against an accidental one).
- Throwaway `ocupilot-ci` (already up; never tear it down or bring up a second): `npx ng build`, then `docker cp ui/dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci npm run test:browser` for `context-chip`, `panel` and `turn`. A browser result read before that rebuild and copy is not evidence. For the full suite, `npx ng build --configuration production,harness` first.
- Dev instance (`server: "ocupilot-slot-a"`): nothing to compile or run -- no ObjectScript changes. Run no test class.
- `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` -- expected: every check passes and more than zero checks run.

**Rule 19 -- the mutation to apply per AC as each pinning test lands, recorded here with its result:**

- Integration AC: drop `context` from `turn.ts:410`'s body -> the browser Integration leg goes red on the missing `screen_context` pair.
- Fresh-at-Send: memoize the assembled payload on first Send -> the two-screen browser leg reddens on the second turn's route.
- Cap follows `agent-switch`: remove the bus subscription from `agent-context.ts` -> the cap leg reddens.
- Secret screen: return a `view` for a descriptor with non-empty `secretFields` -> `screen-context.test.mjs`'s secret case and the glyph browser leg redden.
- Per-user persistence: skip the `PUT` and mirror only locally -> the reload leg reddens.
- Warning: make `looksLikeSecret` return false for a `sk-` prefix -> the warning cases redden; make it return true for `%Api.Mgmnt.v2` -> the non-trigger cases redden.

## Auto Run Result

**Summary.** Implemented: `core/agent-context.ts` (the store over `GET/PUT /agent/context`), `core/screen-context.ts` (`assembleScreenContext`, `contextRowsSent`, `contextViewDeclared`, `looksLikeSecret`), `shell/context-chip.ts` (the chip component), `turn.ts` widened to `send(message, context?)`, `panel.ts` wired to render the chip, gate Send behind the paste warning, and assemble context fresh at the click, plus the sign-in/sign-out wiring in `main.ts`/`app.ts` and the SCSS block for the chip, pill, switch and warning. A real defect was found and fixed during implementation: `assembleScreenContext` originally posted `route: ''` for Home, which the server's `ContextViolation` refuses with 422 -- fixed by adding "route is `''`" to the omission conditions.

**Files changed:**

- `ui/src/app/core/agent-context.ts` (new) -- the `AgentContext` store.
- `ui/src/app/core/screen-context.ts` (new) -- the payload assembler and secret-draft check.
- `ui/src/app/shell/context-chip.ts` (new) -- the chip component.
- `ui/src/app/testing/agent-context.ts` (new) -- `stubAgentContext()`.
- `ui/tools/agent-context.test.mjs`, `ui/tools/screen-context.test.mjs` (new) -- unit suites.
- `ui/browser/context-chip.browser-spec.mjs` (new) -- real-instance specs, including the Integration AC.
- `ui/src/app/core/turn.ts`, `ui/tools/turn.test.mjs` -- `context` parameter and its pinning test.
- `ui/src/app/shell/panel.ts`, `ui/src/app/shell/panel.spec.ts` -- chip slot, paste warning, Send-path wiring, and the Story 4.11 test suite.
- `ui/src/main.ts`, `ui/src/app/app.ts`, `ui/src/app/app.spec.ts`, `ui/src/app/app.wire.spec.ts`, `ui/src/app/app.gate-outlet.wire.spec.ts` -- construction, load/reset wiring, and DI updates for unrelated specs.
- `ui/src/styles/_components.scss` -- the chip/switch/warning CSS block.

**Review findings breakdown (13 findings, 4 review layers -- full detail in `## Review Triage Log`):**

- Patched (6, grouped into 6 fix entries): `contextChipVisible` missing an `onScopeChange` subscription (medium); no component-level test for "cap follows `agent-switch`" (medium); `syncSecretRecord()` clearing an acknowledgment on a failed send rather than only on a genuine reset (medium); no test for the kill-switch/restrained chip state (low); `setShare()` not reverting on a malformed 200 body (low); no `app.spec.ts` pin for `agentContext.reset()` on sign-out (low). Each fix verified: full `npm test` (889 `node --test` + 439 vitest, all green), `npm run build` clean, and all 24 browser-spec tests (`context-chip`, `panel`, `turn`) green against the rebuilt/redeployed throwaway bundle.
- Rejected as false (3): `looksLikeSecret`'s excluded-character list producing JWT/AWS-secret false negatives (the exact algorithm is specified byte-for-byte in the frozen `<intent-contract>`); `contextRowCap` not clamped client-side to 1-1000 (the range is a server-enforced invariant this story must not re-derive, per AD-24's Never list); the pill/glyph using a visually-hidden sibling span rather than an ARIA relationship attribute (matches the codebase's established convention and the intent-contract's literal wording).
- Rejected as low/unreachable (2, one root cause): `Panel.currentEntityId()`'s wiring into `context.entity` has no test -- no built screen today combines an entity-detail route with declared `context.fields`, so the path is unreachable in the shipped product; reopen if a future screen combines the two.

**Follow-up review recommendation: true.** Two or more medium-severity entries were patched in this pass (the `onScopeChange` subscription, the live-cap component test, and the `syncSecretRecord` reset-detection fix), which this template's rule makes `true` regardless of how thoroughly the patches were re-verified here. Named unverified risk: the two most recently patched medium fixes -- "cap follows `agent-switch` without a reload" and "a failed send preserves the paste-warning acknowledgment" -- are proven only at the component (vitest) level; neither has a browser-spec leg exercising it against the live throwaway (an operator actually changing `Switches.contextRowCap`, or a live network failure on `POST /turn`), so a regression in either wiring path at the real-DOM/real-instance layer would not be caught until a future pass adds one.

**Verification performed:**

- `cd ui && npm test` -- 889 `node --test` + 439 vitest component tests, all green (post-patch; 888/436 pre-patch).
- `cd ui && npm run build` -- clean; pre-existing 500 kB budget warning only (142.89 kB over, unchanged in nature from before this story).
- `uv run scripts/check-objectscript.py` -- 0 findings (no ObjectScript touched).
- Rebuilt (`npx ng build`), `docker cp`'d into `ocupilot-ci`, confirmed the served bundle hash via `curl`, then ran against the live throwaway: `context-chip.browser-spec.mjs` 6/6, `panel.browser-spec.mjs` 10/10, `turn.browser-spec.mjs` 8/8 -- all pass, both before and after the patch pass.
- `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` -- 19 passed, 0 failed, 2 pending (Epic 3, unrelated) -- both before and after the patch pass.
- Matrix Test Audit: every I/O & Edge-Case Matrix row has at least one covering test that ran and passed (unit and/or browser).
- Four review layers (blind-hunter, edge-case-hunter, verification-gap, intent-alignment) ran in parallel against the full diff; 13 findings triaged, 6 patched, 4 rejected as false, 2 rejected as unreachable-today (one root cause) -- detail in `## Review Triage Log`.

**Residual risks:** the named follow-up-review risk above (two patched medium fixes proven only at component level, not browser level); and the pre-existing 142.89 kB bundle-size budget overage, unrelated to this story and not worsened by it.

Status: done
Blocking condition: none
