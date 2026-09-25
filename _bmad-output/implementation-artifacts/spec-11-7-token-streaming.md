---
title: 'Story 11.7: Token streaming'
type: 'feature'
created: '2026-09-25'
status: 'in-progress'
baseline_revision: 'f24c030227b7276120e3d65dc30afb4ae2783f62'
baseline_commit: 'f24c030227b7276120e3d65dc30afb4ae2783f62'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-11-context.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
deferred:
  - summary: >-
      Gemini finish reasons that are not the model declining (MALFORMED_FUNCTION_CALL, UNEXPECTED_TOOL_CALL, TOO_MANY_TOOL_CALLS, and others) map to the canonical refusal, so such a turn now ends PROVIDER.DECLINED with "The model declined to answer this request".
    evidence: |-
      MessageAdapter.GEMINISTOPREASONS (pre-existing, Epic 10) folds ten Gemini reasons into refusal; Loop routes every canonical refusal to PROVIDER.DECLINED as the intent requires. Turn-level DECLINED is exercised only through the Anthropic stop_reason; OpenAI and Gemini refusal shapes are pinned at adapter level (streamed equals plain).
    location: >-
      src/OcuPilot/Kernel/Provider/MessageAdapter.cls:75
    severity: medium
---

<intent-contract>

## Intent

**Problem:** A reply appears only when the whole model call has finished, so a slow model reads as a hang. Separately, a provider refusal ends a turn as an empty reply (DW-1181), because nothing reads the canonical `refusal` stop reason.

**Approach:** A model call made by a turn asks the provider to stream. `%Net.HttpRequest` hands each arriving chunk to an OcuPilot `%Net.ChunkedReader`. The reader parses the SSE events, and at most every 400 ms it writes the text so far into the running model step's existing `text` field. After the call, the same reader assembles the family's ordinary non-streamed JSON body, and the unchanged `MapResponse` reads it. The panel renders a running model step's text as a growing reply. When the turn ends, that text is replaced by exactly what a non-streamed turn renders. A `refusal` stop reason ends the turn with a new error, `PROVIDER.DECLINED`.

## Boundaries & Constraints

**Always:**

- **The wire contract does not change (AD-7, AD-33).** The turn stays a background job and the panel keeps polling `GET /turn/:id/progress` every 1000 ms. No key is added to the progress payload or to a step. Streamed text travels only in the `text` of the model step whose `status` is `running`: the same row, the same `TEXTMAXLENGTH` cap, the same owner, and it dies with the turn.
- **Streamed text is a snapshot, never a delta.**
  - Each write replaces the step's `text` with the whole text so far for the current call.
  - Every published snapshot is a prefix of the next one and, for a call that does not end in a refusal, of its final `Response.Text`.
  - Text blocks are joined the way `Anthropic.MapResponse` joins them (no separator).
  - The step's existing outcome write (`Step.GuardedUpdate`) overwrites the snapshot: with the final text on success, and with `""` on a fault.
- **Coalescing cadence.**
  - At most one write per model step per `Limits.STREAMINTERVALMS` (400 ms).
  - A write happens only when the text has grown.
  - The first text is written as soon as it arrives.
  - Nothing is written once the text reaches `TEXTMAXLENGTH`.
  - No row is ever added.
  - The clock is read through a method that a probe can override.
- **Retry composition (AD-42 as amended 2026-09-25).**
  - The reader is created fresh for every attempt, starting from empty text.
  - It sees bytes only after `%Net.HttpRequest` has parsed a status line (`HttpRequest.cls:1498`, `:2129`, `:2140-2163`). So a published snapshot implies a status line, and a call that published anything is never transport-retried.
  - A retry before any status line starts from empty text and overwrites.
  - **A status line followed by a broken body, an in-stream `error` event, or a stream with no terminator** ends the call `PROVIDER.TRANSPORT` and is never retried. The terminators are `message_stop`, `[DONE]`, and Gemini's `finishReason`. The step reads `error` with `text` `""`, the reply is null, and the banner is the one a non-streamed transport failure shows.
- **Which calls stream.** A call streams only when the caller passes a stream sink **and** the adapter's class parameter `STREAMS` is 1.
  - `Kernel.Agent.Loop` always passes one, so every turn test and browser spec driving `turnprobe` now runs the streamed path unless its tag is marked `Plain`. That is intended evidence.
  - Test connection (`TestCall`, `InvokeDraft`) passes none, so it is unchanged.
  - All four adapters ship `STREAMS = 1`: Anthropic, OpenAI, Gemini, and Compatible (inherited from OpenAI). Setting `STREAMS = 0` on one class and recompiling it is the per-family off switch; a non-streamed call renders identically.
- **A streamed request.**
  - The body carries `"stream": true`. OpenAI and Compatible also send `"stream_options": {"include_usage": true}`.
  - Gemini calls `:streamGenerateContent?alt=sse` on the same origin, so the egress origin check is unchanged.
  - `AcceptGzip` is 0 and `ReadRawMode` is 1. The reader decodes UTF-8 itself, carrying the `$ZConvert` handle across chunks, because `text/event-stream` without a charset is otherwise read as Latin-1 (`HttpRequest.cls:2177-2179`).
- **The reader never raises and never does device I/O.**
  - The socket is the current device during `ReadChunk` (`HttpRequest.cls:2051`).
  - A failed snapshot write stops publishing for that call and never fails the call.
  - The real `IssueHttpsPost` does not copy a streamed body into `pBody` (a long SSE body can exceed the string limit). The reader's assembled body is the body of record. When the reader received no bytes, the transport's `pBody` is used, which is how stubs and non-2xx JSON answers reach the existing paths.
  - A body whose first non-blank character is `{` is JSON and is mapped exactly as today. This covers errors and a server that ignored `stream`.
  - The reader's back-references are released on every path.
- **Rendering (AD-11 rule 4, AD-33).**
  - The streamed text renders through the same `<app-reply>` component (the `parseReply` data tree, then DOMPurify), beside the same avatar, in its own `div.ocu-panel-message-agent.ocu-panel-message-streamed` that carries `inert`. It is therefore neither focusable nor announced; the final reply is announced as today (EXPERIENCE.md:794).
  - It shows only while the turn is live, `running`, and has no error banner.
  - When the turn ends, the streamed block is removed and the final block is inserted exactly as for a non-streamed turn.
  - Nothing animates it. Under reduced motion the text still grows (content, not motion), and the follow scroll is instant through the existing CSS.
  - The 11.10 follow rule applies unchanged, because `settle` measures scroll-height growth.
- **Refusal (DW-1181).** When a response's `StopReason` is `MessageAdapter.#REFUSALSTOPREASON`, streamed or not, the model step becomes `error`, `""`, `PROVIDER.DECLINED`. The turn fails with that code and the reason "The model declined to answer this request". No reply is shown.
- **Unchanged:** the prompt (`Prompt.BUILTIN`), tokens (counted from the assembled usage after the call, AD-31), `Boundary` checks, Stop (the flag is still read between steps), proposals, and never retrying a write.
- Every stateful check runs on `ocupilot-ci`, one test class per runner call. CI stays stub-based.

**Never:**

- No new transport to the browser: no SSE or held-open request, and no `since`/cursor parameter.
- No progress-payload key and no `TurnWire` key-set change.
- No row per token.
- No DOM-append renderer. `reply.spec.ts:115` ("rebuilds rather than appends") stays green.
- No new user-visible client string, no Fixed-strings row, and no `strings.ts` edit.
- No edit to Epic 12's hunks:
  - `turn.ts`: `NO_OUTCOME`, `ProposalOutcome`, and `decideProposal` at `:1078-1140`.
  - `panel.ts`: the `reply:` appender block `:868-886`, `PanelWriteCard`, `recordWriteCard`, and `:1016-1045`.
  - `panel.spec.ts`: `:3380-3430`.
- No change to `Kernel/Proposal/**`, `Api/Turn.cls`, `Prompt.cls` or `AdminPort`.
- No live key in any test or fixture.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Streamed text | turn call, SSE text deltas | running model step `text` grows as prefixes; final reply equals the non-streamed reply; panel shows growing block then the final block | none |
| Split input | UTF-8 char and SSE line split across chunks; CRLF; `:` comments; `ping`; unknown event | text identical to the unsplit stream | unknown events ignored |
| Tool call | `input_json_delta` / `tool_calls[].function.arguments` fragments; Gemini whole `functionCall` | canonical `ToolCallsJson` equal to the non-streamed body's; same proposal | none |
| Thinking | Anthropic `thinking_delta` + `signature_delta` | `ContentJson` equal to non-streamed; thinking never in the snapshot | none |
| Retry before status | no status line, then streamed success | one retry (AD-42); final text once; no snapshot contains it twice | none |
| Break after bytes | 200, half the events, then `<READ>` | `PROVIDER.TRANSPORT`, 1 call, step `error` text `""`, banner, no reply, no streamed block | not retried |
| In-stream error / no terminator | 200 then `event: error`, or body ends early | as the row above | not retried |
| Non-2xx while streaming | 429/400 JSON body | existing retry/`PROVIDER.REFUSED` handling unchanged | as today |
| Refusal (DW-1181) | `stop_reason: refusal`, `content_filter`, Gemini `SAFETY`/`blockReason`, streamed or not | turn `failed`, `PROVIDER.DECLINED`, banner, no reply | none |
| No sink | Test connection, `Invoke` without sink | request has no `stream`, URL and headers unchanged | as today |
| Reduced motion | `prefers-reduced-motion: reduce` | final DOM equals the non-reduced final DOM; streamed block has no animation or transition | none |

</intent-contract>

## Code Map

- `src/OcuPilot/Kernel/Provider/Base.cls`:
  - `Attempts` `:257-363`. The request is built at `:286`, `IssueHttpsPost` is called at `:300`, the transport-retry condition is at `:315`, and 2xx `MapResponse` runs at `:329-330`.
  - `NewRequest` `:413-439` (sets `SocketTimeout` 0 at `:425`).
  - `IssueHttpsPost` `:485-509` is the one transport seam; it reads the body into a string at `:502-507`.
  - `ReasonFor` `:649-663` is the home of every `PROVIDER.*` sentence.
- Adapters:
  - `Kernel/Provider/Anthropic.cls`: `CallMessages` `:47-89`; `MapResponse` `:129-170` joins text blocks with no separator.
  - `OpenAI.cls` `:49-65`, Chat Completions.
  - `Gemini.cls`: `RequestUrl` `:65-82`, `CallMessages` `:95-113`.
  - `Compatible.cls` extends OpenAI; its `RequestUrl` is `:47-83`.
- `Kernel/Provider/MessageAdapter.cls`: `OPENAISTOPREASONS` `:65`, `GEMINISTOPREASONS` `:75`, `REFUSALSTOPREASON` `:90`, `OpenAiToCanonical` `:212-275`, `GeminiToCanonical` `:407-470`. It is reused unchanged after assembly.
- `Port/ProviderPort.cls`:
  - `Invoke` `:93` calls `Dispatch` `:249`, which builds `tSettings` and calls `tAdapter.Invoke` at `:348`. Both gain a trailing optional sink, carried as `tSettings("stream")`. A local array node holds an OREF.
  - `InvokeDraft` `:210` is Test connection's path ("draft" there means an unsaved definition) and also calls `Dispatch`, passing no sink.
- `Kernel/Agent/Loop.cls`:
  - `:208` appends the running model step (`tSeq`); `:213` calls `Invoke`.
  - `:229-237` is where the refusal is consumed: before `GuardedUpdate(... "ok" ...)`, route a refusal to the fault branch, shaped like `:221-227`.
  - `PortClass()` `:33`. `Test/TurnLoopProbe.cls:111` answers `Test.ProviderPortProbe`, which extends the real port, so the new formal is inherited.
- `Kernel/Agent/Limits.cls`: the parameter block `:11-111`. `TEXTMAXLENGTH` 131072 is the snapshot cap.
- `Kernel/State/Step.cls`:
  - `GuardedUpdate` `:118-128` is the pattern the new snapshot write copies: an SQL open by `(TurnKey, Seq)`, then `GuardedSaveIfCurrent` on `RowVersion`.
  - `ApplyContent` `:211-219` caps the text.
  - After begin, the job is the step's only writer; signals are separate globals (`Turn.cls:12-14`).
- `Kernel/State/Turn.cls:487` sends `reply` only for `completed`. That is unchanged.
- `Api/Error.cls:205-280`: the `PROVIDER.*` parameters. This is a shared-append file, so append one parameter after `:280`. `ReasonForTurnError` `:1037-1046` already routes `PROVIDER.` to `Base.ReasonFor`.
- Vendor, read-only:
  - `irislib/%Net/HttpRequest.cls`: `ResponseChunkReader` `:830`; `ReadChunk` is called per piece at `:2238-2244`; exceptions are swallowed at `:2239-2243`; chunked decoding `:2201-2300`; gzip is buffered whole at `:2195-2218`; `AcceptGzip` `:807`; `ReadRawMode` `:1726`.
  - `irislib/%Net/ChunkedReader.cls` has one method, `ReadChunk(chunk)`.
- Stubs:
  - `Test/TurnProvider.cls`: `Script` `:37-43`, `TextReply` `:68`, `ToolUseReply` `:80`, `IssueHttpsPost` `:110-151`. Its state lives in `^IRIS.Temp.OcuPilotTurnProvider(tag)`, and the tag is the request's `model`.
  - `Test/ProviderStub.cls` (queue methods `:55-80`, `IssueHttpsPost` `:227+`) and `Test/ProviderStubTransport.cls:36-80` are shared by `OpenAIStub`, `GeminiStub` and `CompatibleStub`.
- Tests that must stay green:
  - `TurnWire` `:134-138` pins the key sets.
  - `ProviderTransportRetry` and `ProviderRetry`.
  - `Provider` `:131-158`, `Adapter` `:554-618`, `OpenAIAdapter`, `GeminiAdapter` (its `url` assert at `:217` is for a call with no sink), `CompatibleAdapter`, `AnthropicThinking`.
  - `TurnProviderFault`, `AgentConnection*`, `ScreenGrounding`.
- `scripts/ci-throwaway.sh:299`: the `OCUPILOT_ALLOW_TEST_PROVIDER` roster. Epic 12 inserts after `:303`.
- Client:
  - `ui/src/app/core/turn.ts`: `TurnStep` `:117-140`, `TurnEntry` `:265-285`, `turnErrorBanner` `:705-717`, poll `:1328-1368`, live update `:1359`, `finalizeLive` `:1422-1436`, which settles running steps.
  - `ui/src/app/shell/panel.ts`: template turn block `:395-434` (reply `:422-427`), `PanelTurnView` `:170-176`, the `turns` getter `:841-890`, which already filters out `model` steps at `:849-851`.
  - `ui/src/app/shell/reply.ts:107-114` rebuilds on every change.
  - `ui/src/app/shell/panel-follow.ts:99-106`: `settle`.
  - `panel.spec.ts` helpers: `fakeTurnApi` `:666`, `turnStep` `:689`, `progressWith` `:2683`, `fakeTranscriptGeometry` `:3656`, `mountAnswered` `:3681`. The 11.10 block ends at `:3888`.
  - `ui/tools/turn.test.mjs`: helpers `:23-120`.
  - `ui/browser/turnprobe-spec.mjs`: `scriptReply` `:151`, `setTag` `:132`, `armProbeDefinition` `:171`, `requireFreeSlot` `:231`.
  - `ui/browser/panel-spec.mjs:62`: `signedInAt(..., mediaFeatures)`.
  - `ui/browser/proposal-card.browser-spec.mjs` has the tool-use arming to copy.
  - Specs with reply selectors that must stay green: `turn`, `reply`, `transcript-follow`, `proposal-demo`.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md:673` is the Busy row, a single line. Epic 12 edits `:148-168` and adds rows after `:513`.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Kernel/Provider/StreamSink.cls` (new, abstract): `Publish(pText As %String)`. It gives the provider layer the contract, so it never names `Kernel.Agent`.
- `src/OcuPilot/Kernel/Provider/StreamAdapter.cls` (new): one assembler per family (`anthropic`, `openai`, `gemini`). Each takes SSE events (name and data) into a state and answers two things: the text so far (non-thinking text only), and at the end the family's native non-streamed JSON body plus a status. The status is an error when the stream carried an `error` event or no terminator. Unknown events and delta types are ignored, and unknown block types are kept as started. Gemini keeps any part member other than `text` and joins only consecutive plain-text parts.
- `src/OcuPilot/Kernel/Provider/StreamReader.cls` (new, extends `%Net.ChunkedReader`). Its `ReadChunk` does, in order:
  1. Decode UTF-8 with a carried handle.
  2. Split lines on LF, strip CR, and keep the partial tail.
  3. Parse SSE: blank-line dispatch, `event:`/`data:`, multi-line data, and `:` comments.
  4. Feed the family assembler.
  5. Hand the text so far to the sink whenever it has grown. The sink applies the cadence and the cap.

  It also keeps a bounded copy of a non-SSE (JSON) body. It catches everything, does no device I/O, and exposes the body of record and a status.
- `src/OcuPilot/Kernel/Provider/Base.cls`, `Anthropic.cls`, `OpenAI.cls`, `Gemini.cls`, `Compatible.cls`:
  - Add `Parameter STREAMS = 1` and `StreamsFor(ByRef pSettings)`.
  - In `Attempts`, decide streaming per call, then per attempt: set `AcceptGzip` 0 and `ReadRawMode` 1, create a fresh `StreamReader`, and have the adapter write `stream` (and `stream_options` for OpenAI/Compatible) and, for Gemini, the SSE URL.
  - After `IssueHttpsPost`: use the reader's body when it received bytes. On a 2xx with an assembly status that is an error, end `PROVIDER.TRANSPORT` without a retry. Release the reader.
  - The real `IssueHttpsPost` skips the `Data`-to-`pBody` copy when a reader is attached.
  - Doc comments state the streaming exits.
- `src/OcuPilot/Port/ProviderPort.cls` -- `Invoke` and `Dispatch` take a trailing `pStream` (default `""`), and `Dispatch` sets `tSettings("stream")`. Nothing else changes.
- `src/OcuPilot/Kernel/Agent/StreamStep.cls` (new, extends `StreamSink`) holds the turn key, the step seq, the limits class, the last-write time and the last length. `Publish` applies the cadence and cap and calls `Step.GuardedStreamText`. It reads its clock through `NowMs()`.
- `src/OcuPilot/Kernel/State/Step.cls` -- Add `GuardedStreamText(pKey, pSeq, pText, pLimitsClass)`. It writes `Text` only when the row is `kind` `model` and `status` `running`, capped through `ApplyContent`.
- `src/OcuPilot/Kernel/Agent/Limits.cls` -- Add `Parameter STREAMINTERVALMS As %Integer = 400;` with a one-line doc.
- `src/OcuPilot/Kernel/Agent/Loop.cls`:
  - Pass `##class(OcuPilot.Kernel.Agent.StreamStep).%New(pKey, tSeq, tLimits)` as the new `Invoke` argument (`:213`).
  - Route `StopReason = refusal` to the failed branch with `PROVIDER.DECLINED` (DW-1181).
- `src/OcuPilot/Api/Error.cls` (append only) -- Add `Parameter PROVIDERDECLINED = "PROVIDER.DECLINED";` after `:280`, with a doc comment. Change "twelve" to "thirteen" in the two `PROVIDER.*` count sentences, `:205` and `:1051`, and nowhere else (`:2396` counts slugs). This is a one-word correction of a count this story changes; Epic 12's hunks at `:1064` and `:2316+` are untouched.
- `src/OcuPilot/Kernel/Provider/Base.cls` `ReasonFor` -- `PROVIDERDECLINED` answers "The model declined to answer this request".
- `src/OcuPilot/Test/SseFixture.cls` (new) -- Builds each family's SSE from a native non-streamed body, with a text piece size. Its Anthropic output covers text, `tool_use` with the input split across `input_json_delta` fragments, thinking with signature, and refusal.
- `src/OcuPilot/Test/ProviderStub.cls` and `ProviderStubTransport.cls`:
  - Add `QueueStream(pStatus, pSse, pSliceBytes, pBreakAfterBytes)`. When a reader is attached, it feeds the SSE's raw UTF-8 bytes into `ReadChunk` in slices, and can then break with status 200.
  - Record `acceptGzip`, `readRawMode` and `streamReader`.
- `src/OcuPilot/Test/TurnProvider.cls`:
  - When a reader is attached, feed `SseFixture.Anthropic(<scripted body>)` in 7-byte slices.
  - Add `ScriptStream(tag, hang, body, midHangSeconds, breakAtHalf)`.
  - Add `Plain(tag)`, which makes `StreamsFor` answer 0 for that tag.
  - Scripted non-200 or transport entries behave as today.
- `src/OcuPilot/Test/ProviderStream.cls` (new; split into `ProviderStreamFamilies.cls` if it passes about 500 lines) -- Adapter-level. Cover:
  - Each matrix row from "Split input" to "No sink", for all four families, through the stubs.
  - Canonical parity: streamed equals non-streamed for `Text`, `ToolCallsJson`, `ContentJson`, `StopReason` and tokens.
  - The snapshot-prefix property.
  - The request shape (`stream`, `stream_options`, Gemini URL, `AcceptGzip` 0, `ReadRawMode` 1).
  - A sink that throws never fails the call.
  - The retry-before-status case with a text-once assertion.
  - The break-after-bytes case with `Calls` 1.
- `src/OcuPilot/Test/TurnStream.cls` (new, armed by `OCUPILOT_ALLOW_TEST_PROVIDER`) -- Turn jobs through `turnprobe`. Cover:
  - Mid-call, the running model step's `text` is non-empty and a prefix of the reply.
  - Completion equals the `Plain` run's reply and model-step text.
  - Break at half gives a failed turn with `PROVIDER.TRANSPORT`, `Calls` 1, step `text` `""` and a null reply.
  - The same `ToolUseReply` streamed and plain mints equal proposals (tool, arguments, target, diff, fingerprint, with ids and times excluded).
  - A refusal, plain and streamed, gives `PROVIDER.DECLINED`.
  - A `StreamStep` probe with a fake `NowMs()` writes at most once per interval and never past the cap.
- `scripts/ci-throwaway.sh` -- Add the line `# classes: TurnStream` directly after `:299` (`# classes: TurnGrounding`), and no other edit.
- `ui/src/app/core/turn.ts` -- Export `streamedText(entry: TurnEntry): string | null`, placed after `turnErrorBanner`. It answers the `text` of the last `model` step that is `running`, and only when the entry is `live` and `running` and the text is non-empty; otherwise null. No `TurnEntry` field changes.
- `ui/tools/turn.test.mjs` -- Cover `streamedText`:
  - running model step with text, a finished model step, a non-live entry, an empty text;
  - after `finalizeLive` for completed, failed and stopped;
  - two polls showing growth.
- `ui/src/app/shell/panel.ts`:
  - Import `streamedText`.
  - Add `readonly streamed: string | null` to `PanelTurnView`, set as `streamed: errorBanner === null ? streamedText(entry) : null` directly after `message: entry.message,`.
  - In the template, turn the reply `@if` at `:422` into `@if … @else if (turn.streamed !== null)`, rendering the streamed block described under Always.
- `ui/src/app/shell/panel.spec.ts` -- Add a "Story 11.7" describe block at the end of the file. Cover:
  - a running model step renders one `.ocu-panel-message-streamed[inert]` `app-reply` and no final reply;
  - markup in streamed text renders as text (no `img` or `script` element);
  - completion leaves exactly the non-streamed DOM, with no streamed block;
  - a failed turn shows the banner only;
  - growth while following scrolls to newest.
- `ui/browser/stream-reply.browser-spec.mjs` (new) -- Legs:
  - **(a)** A long Markdown reply (code block, list, remote image, link, non-ASCII) scripted with `ScriptStream` and a mid hang. Mid-turn the streamed block is visible, `inert`, grows between two reads, and the transcript is at newest.
  - **(b)** The final reply container's `outerHTML` equals the `Plain(tag)` run's.
  - **(c)** Reduced motion: the final HTML equals (b)'s, and the streamed block's computed `animation-name` is `none` and `transition-duration` is `0s`.
  - **(d)** Break at half: the banner text equals the plain transport-failure banner, with no reply and no streamed block.
  - **(e)** A streamed write proposal's card matches the plain run's (`outerHTML` with proposal ids and times normalized).
  - **(f)** A refusal shows the `PROVIDER.DECLINED` banner.
  - **(g)** Zero off-origin requests throughout.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md:673` -- In place, on the same line, append to the Busy row's second cell: "; while the model writes, its reply grows in place at the progress poll's pace, rendered like the final reply, not announced and not focusable until final; if the turn stops or fails meanwhile the partial text is removed and the turn ends as it would have without streaming `[ADDED 2026-09-25 - Story 11.7]`".

**Acceptance Criteria:**

- **Streaming on.** Given a turn against a streaming adapter, when a reply arrives, then the panel shows it growing while the turn still runs as a job and the panel still polls. The progress payload's key sets are unchanged: `TurnWire` is green and unedited. This is the Integration AC.
- **Release 1 rendering rules.** Given streamed text containing HTML, a remote image and a link, when it renders, then no `img`, `script` or `iframe` element is created from it, no off-origin request is made, and it sits in the same avatar row as the final reply.
- **Same final rendering.** Given the same scripted reply streamed, plain and under reduced motion, when each turn ends, then the three final reply DOMs are equal.
- **Failure mid-stream.** Given a failure mid-stream, when the turn ends, then it renders exactly the non-streamed failure: the banner, and no reply.
- **Write proposals.** Given a streamed turn that proposes a write, when the card renders, then the proposal and card equal the non-streamed ones.
- **Retry composition.** Given a transport retry, or a break after a status line, when the turn ends, then no text is duplicated and a call that streamed anything was not retried.
- **Refusal (DW-1181).** Given a refusal from any family, when the turn ends, then it fails `PROVIDER.DECLINED` with a banner, never with an empty reply.
- **Existing tests.** Given the prompt pins and the Test connection tests, when they run, then they are green and unedited.

### Review Findings

Code review 2026-09-25, tier `full-opus`, four layers (blind, edge-case, verification-gap, acceptance). 36 rows, 15 entries: high 0, medium 2, low 13; 11 rejected.

- [ ] [Review][Decision] DW-1661: Gemini tool-call failure reasons (`MALFORMED_FUNCTION_CALL`, `UNEXPECTED_TOOL_CALL`, `TOO_MANY_TOOL_CALLS`) end `PROVIDER.DECLINED` -- the fix contradicts Epic 10's pinned refusal map (`Adapter.cls:609`, `:1052`) and needs new copy or a new code; `decision-pending owner=burndown` (recommended: a code of its own). [MessageAdapter.cls:75]
- [x] [Review][Defer] A streamed call has no wall-clock bound, since every chunk re-arms `TimeoutSeconds` -- DW-1179's root cause; occurrence appended; the false worst-case sentence in `Limits.PROVIDERCALLSECONDS` corrected at its origin. [Limits.cls:110]
- [x] [Review][Patch] `TurnStream` creates principals but was armed by `OCUPILOT_ALLOW_TEST_PROVIDER` alone -- now `ARMINGVARIABLE` `OCUPILOT_ALLOW_PRINCIPALS` plus `PROVIDERVARIABLE`, and listed in the principals roster. [TurnStream.cls:17, ci-throwaway.sh:204]
- [x] [Review][Patch] The declined-reason assert compared the reason with `ReasonFor` itself -- now the literal sentence. [TurnStream.cls:302]
- [x] [Review][Patch] A snapshot cut at the cap left a failed step `truncated` with empty text -- `GuardedSnapshotText` keeps the flag as it was; the cadence test asserts it. [Step.cls:147]
- [x] [Review][Patch] `StreamStep` comments called `$ZHorolog` a within-the-day clock with a midnight wrap (measured on `ocupilot-ci`: 465,466 s since start) -- corrected. [StreamStep.cls:54, :69-71]
- [x] [Review][Patch] `StreamReader`'s `Faulted` exit had no test -- `ProviderStream.TestAReaderThatRaisedAnswersNoBody`. [StreamReader.cls:200]
- [x] [Review][Patch] Gemini's endpoint guard and query join had no test -- two legs in `ProviderStreamFamilies`; `StreamCase.CallDirect` takes an endpoint. [Gemini.cls:103-116, StreamCase.cls:70]
- [x] [Review][Patch] The raising-sink and OpenAI `tool_calls` mutations were claimed in doc comments, never observed -- observed; lines under Verification. [ProviderStream.cls:207, ProviderStreamFamilies.cls:15]
- [x] [Review][Patch] The Test-connection leg reset `ProviderPortProbe` only on its last line, and `StreamCase`'s header said every call is direct -- reset moved to `OnAfterOneTest`, header corrected. [StreamCase.cls:6, :30]
- [x] [Review][Defer] by-design: a refusal keeps no provider text in the fault (Always: Refusal; Design Notes, why a banner).
- [x] [Review][Defer] by-design: after Stop, streamed text grows until the call ends (Scope decisions: Stop keeps its step boundary).
- [x] [Review][Defer] by-design: a preamble streamed before a tool call disappears when the call ends (Scope decisions).
- [x] [Review][Defer] by-design: Compatible sends `stream_options`; a server that omits usage counts 0 tokens (Always: a streamed request; Scope decisions).
- [x] [Review][Defer] by-design: every snapshot rewrites the whole text so far (AD-33 amendment: a snapshot, never a delta).

- [ ] [CI] instance: `OcuPilot.Test.ReadTool.TestTheMessagesReadToolCarriesTheConsoleLogsRowsAndNotItsCursor` red in CI run 36152768790 on `e5c0bff5` ("the tool's oldest row in the window is the console log's"), the reopen_if of DW-1144 -- `src/OcuPilot/Test/ReadTool.cls:1199` -- make the file comparison hold when a console line lands between the tool's read and the port's (OcuPilot's own structured logger writes `messages.log`, and this story's provider tests write many lines just before `ReadTool` runs): e.g. read the port immediately before and after the tool at the same cap and accept the tool's oldest row matching either; the `read.source.endpoint` -> `alerts` mutation must still redden it; write its `mutation:` line. Test-only; no product change.

Rejected: (low) text that stops growing mid-call waits for the next write -- cosmetic, and the fix changes the reader's hand-over contract; (low) the Error banner row names no `PROVIDER.DECLINED` trigger -- that trigger list was never exhaustive; (low) `StreamStep`'s defensive branches untested -- the "never fails the call" promise is pinned at the reader; (low) browser legs (b) and (c) read values (a) and (b) set -- a failure still reads red; (false) a 2xx JSON body above 3,000,000 characters -- no model reply reaches it; (false) tool-call deltas without `index` -- the array position is already the fallback; (false) Gemini thought parts break the prefix -- no request asks for thoughts; (false) a mid-stream read timeout ends `PROVIDER.TIMEOUT` -- the amended AD-42 names a broken body, an error event and a missing terminator, and a timeout is still never retried; (false) browser (g) and the avatar row have no mutation -- each AC has one observed mutation; (low) the prefix check is vacuous on three refusal legs -- the parity assert carries them; (false) turn-level refusal only through Anthropic -- `Loop` reads the canonical stop reason, and `Adapter` plus `ProviderStreamFamilies` pin every family's refusal shapes to it.

## Spec Change Log

- 2026-09-25, rework iteration 1 (trigger ci): CI run 36152768790 reddened `ReadTool` on the flaky messages-window comparison DW-1144 named; one `[CI]` item re-opens the spec.
- 2026-09-25, lead spec gate: the proposed AD-33 and AD-42 amendments and the Deferred row are written into the spine (Rule 20); Design Notes gain the live per-family check below.

## Review Triage Log

### 2026-09-25 — Review pass

- verdicts: 22 findings — high 0, medium 3, low 12, false 7, maybe-false 0
- findings:
  - `[medium]` `[patch]` An error event followed by its terminator was untested; every error leg was also a no-terminator stream — added error-then-terminator legs to `ProviderStream` and `ProviderStreamFamilies`; mutation recorded.
  - `[medium]` `[patch]` Nothing pinned a fresh reader per attempt on a status retry whose JSON body reached the reader — added `TestAStatusRetryReadsTheNextStreamFromEmpty` (529 JSON through the reader, then SSE); mutation recorded.
  - `[low]` `[patch]` panel.spec growth case did not depend on the streamed block, and browser (a) had no overflow precondition — (a) now waits for overflow and then for the smooth follow scroll while the block shows; panel.spec asserts the block at each growth poll.
  - `[low]` `[patch]` Browser (b) is not independent and its mutation comment was wrong; (c) never checked the block was gone — comment corrected, (c) asserts no streamed block after the end, the `@if` mutation line no longer credits (b).
  - `[low]` `[patch]` AC "Release 1 rendering rules" and the reduced-motion half had no mutation line — `[innerHTML]` and `animation` mutations applied, observed red, recorded.
  - `[low]` `[reject]` The spec says `ReadChunk` exceptions are swallowed; the vendor adds them to `Post`'s status — no runtime effect (`StreamReader` catches everything); the fix edits this spec.
  - `[low]` `[patch]` A declined call's provider ledger row read `ok` — the refusal check now runs before `RecordProviderRow`, so the row records `error`/`PROVIDER.DECLINED`; `TurnStream` asserts it; mutation recorded.
  - `[low]` `[reject]` Three planned mutation bullets disagree with the observed lines — the observed lines directly beneath are the record; the fix edits this spec.
  - `[low]` `[reject]` Spec names `Step.GuardedStreamText`, code has `GuardedSnapshotText` — the spec's name clashes with private `State.Base.GuardedStreamText` and would not compile; the fix edits this spec.
  - `[medium]` `[defer]` Non-declining Gemini finish reasons map to canonical refusal and now end `PROVIDER.DECLINED` — pre-existing mapping in `MessageAdapter.cls:75`; recorded in `deferred:`.
  - `[low]` `[patch]` Declined turn's ledger row reads `ok` (same root cause as the ledger row above) — fixed there.
  - `[false]` `[reject]` Transport claims proven only by stubs — the live per-family check drove the real `%Net.HttpRequest` chunk-reader path for all four families; CI is stub-based by intent.
  - `[low]` `[reject]` `STREAMS = 0` is never set in a test — no family ships 0 after the live check; the fix adds a test-only adapter class for a switch not in use.
  - `[false]` `[reject]` `turnprobe` streams only 200 bodies the fixture can convert — intended: the spec says scripted non-200 and transport entries behave as today.
  - `[false]` `[reject]` Real-clock cadence not measured — the spec pins the cadence through the overridable `NowMs()` probe.
  - `[false]` `[reject]` Turn-level prefix checked only on polled texts — each polled text is asserted a prefix of the reply; pairwise order is pinned at the reader.
  - `[false]` `[reject]` `StreamStep` keeps `LastLength` across attempts — a retried attempt's predecessor publishes nothing (no bytes, or a JSON body), so it stays 0.
  - `[low]` `[reject]` A mid-stream read timeout ends `PROVIDER.TIMEOUT`, not `PROVIDER.TRANSPORT` — the same exit a plain call's body timeout takes, never retried; not worth a new branch.
  - `[low]` `[patch]` Reduced-motion leg compares only the final container and no CSS targets the block — grouped with the (b)/(c) and mutation-line patches above.
  - `[false]` `[reject]` Gemini adds an endpoint condition to streaming — "only when" states necessary conditions; an endpoint not naming `:generateContent` is called plain.
  - `[false]` `[reject]` `STREAMS = 0` on OpenAI also turns off Compatible — the intent says Compatible inherits; Compatible can set its own.
  - `[low]` `[patch]` The body-build failure exit dropped the reader without `Release()` — release added on that exit.

## Design Notes

**Governing ADs.**

- AD-7 and AD-33: the contract is unchanged; the draft lives in the model step's own `text`, capped, owned, and dying with the turn.
- AD-11 rules 1 and 4: the prompt is untouched, and there is one render path.
- AD-31 and AD-41: the bounds are unchanged; tokens are counted after the call, and `TEXTMAXLENGTH` caps the draft.
- AD-39: the refusal becomes a turn error.
- AD-42 and its 2026-09-25 amendment: `SocketTimeout` 0 is kept, and a stream never triggers a transport retry after its status line.
- AD-9 and AD-8: `GuardedStreamText` is a leaf storage call made from the reader. Its `New $ROLES` frame unwinds before `%Net` resumes reading, and it calls no port, tool or provider.
- AD-19: `streamedText` is a pure function in `core/`.
- AD-35: the key is never in the reader or the sink.
- AD-12: one envelope.

**Proposed spine amendments (Rule 20, for the lead).**

- **AD-42.** "A streamed model call is requested only by a turn. A status line followed by an in-stream error, a missing terminator or a broken body ends it `PROVIDER.TRANSPORT`, never retried. Streamed text reaches the reader only after a status line, so no retry can duplicate it. The streamed body is decoded by OcuPilot from raw UTF-8 and is never gzip-encoded."
- **AD-33.** "A running model step's `text` carries the call's text so far, as a whole snapshot, written at most once per `STREAMINTERVALMS` (400 ms). The step's outcome replaces it. No row is added."
- The Deferred row "Streaming replies" can then read "Done, Story 11.7".

**Why the step's `text`, not a new member.** It needs no wire change, so `TurnWire`'s pins keep holding. The cap and ownership already exist. It clears itself on a fault. The panel already hides model steps, so only the view derives the growing block.

**Why a banner for every refusal.** A refusal is the provider declining, which AD-39 surfaces as a turn error. A banner is also the one rendering that stays the same across the four families and across a refusal that arrives after streamed text (an Anthropic refusal can end a partial answer). Today OpenAI and Gemini refusal text renders as a reply; after this story it renders as the banner.

**Why assemble into the native body.** Every stop-reason, refusal, thinking and tool mapping stays in the one tested `MapResponse` per family. Parity is one equality test per fixture.

**Scope decisions.**

- Stop keeps its step-boundary contract: text already streaming may finish before the turn stops, and then it is removed.
- A preamble streamed before a tool call disappears when the call ends, because a non-streamed turn never shows it.
- A compatible server that omits `usage` counts 0 tokens, as it already does when not streamed.
- Aborting a stream in flight is not attempted, because `ReadChunk` exceptions are swallowed (`HttpRequest.cls:2239-2243`).

**Transport inferences (verify, not proof).**

- Each provider sends `Transfer-Encoding: chunked` (inference). A non-chunked body still works, but its text arrives at the end.
- In production a non-2xx JSON body also passes through `ReadChunk` (`HttpRequest.cls:2238`). The reader keeps it as the body of record, and its shape (`{`) routes it to today's paths, so the stubs, which answer through `pBody`, and production reach the same code.

**Live per-family check (lead gate, extra evidence, never the proof).** After implementation, one live streamed turn per family whose key or URL is present in `/Users/jbrandt/git/OcuPilot/.env.local` and reachable from `ocupilot-ci` (Anthropic, OpenAI, Gemini, and the compatible adapter against `OLLAMA_BASE_URL`), each key read at the point of use and each credential removed afterwards. Record per family: `Transfer-Encoding`, `Content-Type`, that the text grew, and that the final reply equals a `STREAMS = 0` run's shape. **A family whose live streamed call fails where its plain call succeeds ships `STREAMS = 0`**, recorded in `## Spec Change Log`, so streaming never puts a Release 1 turn at risk; a family that cannot be reached is reported as unchecked, never as passed. The spine's AD-33 and AD-42 amendments (2026-09-25, this story's spec gate) are written.

**Integration ACs.** `StreamSink`, `StreamReader` and `StreamAdapter` have one consumer, `Kernel.Agent.Loop` through `StreamStep`, and its observable effect is pinned by `TurnStream` and the browser spec.

- Consumes:
  - 4.1 (the turn job), 4.5 (steps and the panel), 4.8 (turnprobe), 5.x (the proposal card).
  - 10.1 to 10.4 (the adapters), 10.6 (the transport retry), 11.10 (the follow rule).
- Consumed-by:
  - 17.7: the owner's live check per default model.
  - 11.8, 11.1, 11.4: these render into the same reply block.

**Addressed DW-1181:** the refusal task and matrix row.

**footprint_extensions:**

- Contended, staying off Epic 12's hunks as listed: `ui/src/app/core/turn.ts`, `ui/src/app/shell/panel.ts`, `ui/src/app/shell/panel.spec.ts`.
- Shared-append: `src/OcuPilot/Api/Error.cls`.
- Outside Epic 11's footprint:
  - `src/OcuPilot/Kernel/State/Step.cls`, `src/OcuPilot/Port/ProviderPort.cls`, `scripts/ci-throwaway.sh` (one line, clear of Epic 12's insertion after `:303`).
  - `EXPERIENCE.md:673` (one line in place; no line shift).
  - `Test/ProviderStub.cls`, `Test/ProviderStubTransport.cls`, `Test/TurnProvider.cls`, and the new test classes.

## Verification

**Slot and instance.** Slot A. Every IRIS MCP call carries `server: "ocupilot-slot-a"`, and stateful checks run only on `ocupilot-ci` (52776/1975).

- Load code with `cp -R src/. /tmp/ocupilot-ci/src/`, then `docker exec -i ocupilot-ci iris session iris -U HSCUSTOM` with `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck",,1)`, and recompile the whole package before trusting any result.
- Browser runs:
  1. Build: `cd ui && npm run build`.
  2. Deploy: `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`.
  3. Export `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`.
- Never touch `ocupilot`, `ocupilot-slot-*` or `ocupilot-b-ci`.

**Commands:**

- `uv run scripts/check-objectscript.py && bash scripts/lint-docs.sh` -- expected: clean.
- **(loop)** Run each of these classes with `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`: `ProviderStream`, `ProviderStreamFamilies` (if split), `TurnStream`, `ProviderTransportRetry`, `ProviderRetry`, `Provider`, `Adapter`, `OpenAIAdapter`, `GeminiAdapter`, `CompatibleAdapter`, `AnthropicThinking`, `TurnWire`, `TurnProvider`, `TurnProviderFault`, `ScreenGrounding`, `AgentConnectionWire`. Expected: green.
  - Run one class per call, never re-submit, and confirm each with the `%UnitTest_Result` probe.
- **(loop)** `cd ui && npm run test:tools && npm run test:components` -- expected: green (`turn.test.mjs`, `panel.spec.ts`, `reply.spec.ts`, `strings.test.mjs`, `ci.test.mjs`).
- **(loop)** `cd ui && node --test --test-concurrency=1 browser/stream-reply.browser-spec.mjs browser/turn.browser-spec.mjs browser/reply.browser-spec.mjs browser/transcript-follow.browser-spec.mjs browser/proposal-card.browser-spec.mjs` -- expected: green against the redeployed bundle.
- **(once, before dev_complete)** The full ObjectScript sweep on `ocupilot-ci`, one class at a time, then `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS`. Report the sweep as "N ran, 13 refused (arming), 1 known residue". The full browser suite runs in CI only.

**Pinning mutations (Rule 19).** Recompile, or rebuild and redeploy, before reading each one. Revert, and confirm `git status --short` is unchanged.

- `Loop` passes no sink → `TurnStream`'s mid-call snapshot leg goes red, and browser (a) goes red.
- The reader publishes deltas instead of snapshots, or keeps its text across attempts → `ProviderStream`'s retry text-once leg goes red.
- The transport-retry condition also admits a call whose status line arrived (`+tStatus = 0` dropped) → the break-after-bytes `Calls` 1 assertion goes red.
- A 2xx whose assembly status is an error is mapped as a success → `ProviderStream`'s in-stream-error and no-terminator legs go red.
- `Loop`'s fault branch passes the streamed text instead of `""` to `GuardedUpdate` → `TurnStream`'s break leg goes red (step text not empty).
- `streamedText` ignores `live` or `running` → the `turn.test.mjs` finalize cases go red.
- The template keeps the streamed block beside the final reply (`@else if` changed to a separate `@if`) → the `panel.spec` completion case goes red, and browser (b) goes red.
- `inert` removed → the `panel.spec` and browser (a) attribute asserts go red.
- The refusal branch is removed → `TurnStream`'s refusal leg goes red, and browser (f) goes red.
- The Anthropic assembler drops `input_json_delta` → `ProviderStream` tool parity goes red, and `TurnStream` proposal equality goes red.
- UTF-8 is decoded per chunk without the handle → the split-input leg goes red.
- `STREAMINTERVALMS` is ignored → the `StreamStep` cadence leg goes red.

Observed on `ocupilot-ci` (whole `OcuPilot` package force-compiled, or bundle rebuilt and redeployed; each reverted, tree byte-identical):

- mutation: `Loop` passes `""` for the sink → red: `TurnStream` mid-call and break legs; browser (a) (no streamed block).
- mutation: `StreamReader.Publish` hands over only the new text → red: `ProviderStream` retry text-once, parity prefix and split-input legs.
- mutation: `(+tStatus = 0)` dropped from `Base.Attempts`' transport-retry condition → red: `ProviderStream` break-after-bytes (`Calls` 2).
- mutation: `Base.Attempts` skips the 2xx assembly-status check → red: `ProviderStream` error-event and no-terminator legs, `ProviderStreamFamilies` error and cut legs.
- mutation: `Loop`'s fault branch writes the step's streamed text → red: `TurnStream` break and streamed-refusal step-text asserts.
- mutation: `streamedText` drops its `live` test, or its `state` test → red: `turn.test.mjs` direct null cases; the finalize cases stay green because the step-status test also holds.
- mutation: streamed block in a separate `@if` and `streamed` read from the last model step whatever its status → red: `panel.spec` completion case; browser (a). Either change alone stays green: the `@else` and `streamedText`'s guards are independent.
- mutation: `inert` removed → red: `panel.spec` running case; browser (a).
- mutation: the refusal branch in `Loop` disabled → red: `TurnStream` refusal (both runs); browser (f).
- mutation: `input_json_delta` branch of `StreamAdapter.TakeAnthropic` disabled → red: `ProviderStream` tool and thinking parity; `TurnStream` proposal equality (no proposal minted); browser (e).
- mutation: `StreamReader.ReadChunk` decodes without the carried handle → red: `ProviderStream` parity, split-input, retry and raising-sink legs.
- mutation: `StreamStep.Publish` ignores `STREAMINTERVALMS` → red: `TurnStream` cadence leg.
- mutation: `StreamAdapter.Body` ignores `Errored` → red: `ProviderStream` error-then-`message_stop` leg; `ProviderStreamFamilies` "error then end" for openai, gemini and compatible.
- mutation: one reader created before `Base.Attempts`' loop and never released → red: `ProviderStream` status-retry leg (the pre-status retry leg stays green).
- mutation: `Loop` records the provider ledger row before its refusal check → red: `TurnStream` refusal ledger-row asserts (both runs).
- mutation: streamed text bound through `[innerHTML]` instead of `<app-reply>` → red: `panel.spec` markup case (an `img` is created) and running case.
- mutation: an `animation` on `.ocu-panel-message-streamed` → red: browser (c) animation assert.

Code review, observed on `ocupilot-ci` (whole package recompiled; two batches of independent mutations, each reddening only its own method; reverted, tree byte-identical, all three classes green again, runs 12109-12111):

- mutation: `Try` around the sink hand-over in `StreamReader.Publish` removed → red: `ProviderStream` raising-sink leg (run 12103).
- mutation: `tool_calls` arguments append in `StreamAdapter.TakeOpenAi` dropped → red: `ProviderStreamFamilies` openai and compatible tool parity (12104).
- mutation: `Truncated` restore in `Step.GuardedSnapshotText` dropped → red: `TurnStream` cadence truncation assert (12105).
- mutation: `Faulted` check in `StreamReader.Body` removed → red: `ProviderStream.TestAReaderThatRaisedAnswersNoBody` (12106).
- mutation: `Gemini.StreamsFor` removed → red: `ProviderStreamFamilies` endpoint-naming-no-method leg (12107).
- mutation: `PROVIDERDECLINED` line in `Base.ReasonFor` removed → red: `TurnStream` refusal sentence, both runs (12108).

**(QA) `ProviderStream.cls` (extended, not new).** Added `TestATestConnectionCallCarriesNoStreamThroughTheRealPort`: a Test-connection call through the real, unmodified `ProviderPort.InvokeDraft` against the shipped `compatible` row (re-adapted to its stub by `OcuPilot.Test.CatalogProbeShipped`) carries no `stream` member, closing the one leg the existing no-sink tests do not reach -- they call the adapter's `Invoke` directly, bypassing `Dispatch`'s own catalog resolution. mutation: `InvokeDraft` passes a stream sink on `Dispatch`'s trailing argument → red: the new test's two body-shape asserts. Observed red, reverted, `git status --short` clean, `ProviderStream` 10/10 on `ocupilot-ci`.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** A turn's model call streams (all four families ship `STREAMS = 1`): `StreamReader` (a `%Net.ChunkedReader`) decodes UTF-8 across chunks, parses SSE and feeds `StreamAdapter`, which publishes the text so far to `StreamStep` (400 ms cadence, `TEXTMAXLENGTH` cap, via `Step.GuardedSnapshotText`) and afterwards assembles the family's plain JSON body for the unchanged `MapResponse`. A 2xx stream with an error event, no terminator or a broken body ends `PROVIDER.TRANSPORT` unretried. A canonical refusal fails the turn `PROVIDER.DECLINED` (DW-1181) and its ledger row records the same code. The panel renders the running model step's text in an inert `app-reply` block that the final reply replaces.

**Files.** New: `Kernel/Provider/StreamSink`, `StreamAdapter`, `StreamReader`, `Kernel/Agent/StreamStep`; tests `SseFixture`, `StreamCase`, `ProviderStream`, `ProviderStreamFamilies`, `TurnStream`, `StreamSinkProbe`, `StreamStepProbe`, `ui/browser/stream-reply.browser-spec.mjs`. Edited: `Base`, `Anthropic`, `OpenAI`, `Gemini` (streaming request), `ProviderPort` (trailing sink), `Loop` (sink, refusal), `Step`, `Limits`, `Api/Error` (`PROVIDERDECLINED`), `ProviderStub`, `ProviderStubTransport`, `TurnProvider`, `turn.ts` (`streamedText`), `panel.ts`, `panel.spec.ts`, `turn.test.mjs`, `ci-throwaway.sh` (one roster line), `EXPERIENCE.md:673`.

**Deviations from the spec's wording.** `GuardedStreamText` is named `GuardedSnapshotText` (the spec's name clashes with private `State.Base.GuardedStreamText`); `StreamsFor` takes `pValues` too (`TurnProvider.Plain` reads the model tag; Gemini streams only for an endpoint naming `:generateContent`); the template uses `@else { @if }` because `client-lint.mjs` does not parse `@else if`.

**Review.** 22 findings: 10 patched (2 medium, 8 low), 1 deferred (medium, pre-existing Gemini refusal mapping), 11 rejected (see the triage log). Patched: error-then-terminator legs, a status-retry leg pinning a fresh reader per attempt, the ledger row for a declined call, the reader released on the body-build exit, browser (a)'s overflow precondition with an awaited smooth follow, (c) asserting the block is gone, and two recorded mutations (`[innerHTML]`, `animation`). Follow-up review recommended: false (patched high 0, medium 2; each patched pin has an observed mutation, so no unverified risk can be named).

**Verification.** `check-objectscript` 0 problems; `lint-docs` clean; `test:tools` 1,425/1,425; `test:components` 1,247/1,247. Story classes on `ocupilot-ci`, one per call: ProviderStream 9/9, ProviderStreamFamilies 4/4, TurnStream 5/5 (after patches); the handoff also ran ProviderTransportRetry, ProviderRetry, Provider, Adapter, OpenAIAdapter, GeminiAdapter, CompatibleAdapter, AnthropicThinking, TurnWire, TurnProviderFault, ScreenGrounding, AgentConnectionWire green. Browser against the redeployed bundle: stream-reply 7/7; the handoff also ran turn 10/10, reply 5/5, transcript-follow 4/4, proposal-card 3/3, proposal-demo 3/3. Full ObjectScript sweep once: 253 ran, 13 refused (arming), 1 known residue (`WireSecurityRead` task history); 239 green. `smoke.sh --container ocupilot-ci`: 49/49. Bundle initial total 1.59 MB (292.53 kB transfer), under the 1,670 kB warning. All 17 `mutation:` lines observed red and reverted.

**Live per-family check** (extra evidence; keys read at use, nothing stored or printed, probe classes removed from `ocupilot-ci`). Anthropic: chunked, `text/event-stream; charset=utf-8`, 7 snapshots, final shape equals plain, streamed tool input equals plain. OpenAI: chunked, `text/event-stream; charset=utf-8`, 12 snapshots, same. Gemini: chunked, `text/event-stream`, 1-2 snapshots, same on 2 of 3 runs (one run stopped at `max_tokens`, read as budget spent on thinking (inference)). Compatible (Ollama through `host.docker.internal`): chunked, `text/event-stream`, 27 snapshots, same, usage reported. No family ships `STREAMS = 0`.

**Residual risk.** Every transport claim in CI is stub-proven; the real `%Net.HttpRequest` path is covered only by the live check. Turn-level `PROVIDER.DECLINED` is exercised through the Anthropic shape; OpenAI and Gemini refusals are pinned at adapter level.

footprint_extensions: contended `ui/src/app/core/turn.ts`, `ui/src/app/shell/panel.ts`, `ui/src/app/shell/panel.spec.ts` (beside Epic 12's hunks; trial merge clean); shared-append `src/OcuPilot/Api/Error.cls`; outside Epic 11: `Kernel/State/Step.cls`, `Port/ProviderPort.cls`, `scripts/ci-throwaway.sh`, `EXPERIENCE.md`, `Test/ProviderStub.cls`, `Test/ProviderStubTransport.cls`, `Test/TurnProvider.cls`.
