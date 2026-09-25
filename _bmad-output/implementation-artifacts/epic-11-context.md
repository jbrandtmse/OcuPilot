# Epic 11 Context: The agent explains itself, cites its work, and streams

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Make the agent easy to understand for a judge or voter using it for the first time. It answers about the screen in view without re-fetching what is already shown, and a first request for a change ends in a proposal the user can confirm. Replies stream as they are written, and a proposal names the privilege it needs before Confirm. Any screen or log entry can be explained in one click, each screen offers suggested prompts, and a citation chip takes the user to the row the agent used. This is polish-week work, and improvements may keep landing through the voting week. Every story changes the same panel transcript render path, which is why they form one epic. Stories 11.9, 11.10 and 11.7 are done. The rest run in the order 11.8, 11.1, 11.2, 11.3, 11.4 (owner re-order, 2026-09-22), so that a partial epic merged before the deadline carries the privilege line. The data-egress line and the agent audit viewer moved to Epic 16 (16.15, 16.16).

## Stories

- Story 11.9: The agent knows the screen it is on (done)
- Story 11.10: A judge succeeds the first time (done)
- Story 11.7: Token streaming (done)
- Story 11.8: The proposal names the privilege it needs
- Story 11.1: "Explain this screen"
- Story 11.2: Explain a log or audit entry
- Story 11.3: Suggested prompts per screen
- Story 11.4: Citation chips with click-through

## Requirements & Constraints

- **Release 1 is protected.** Nothing may break a Release 1 screen or a Release 1 agent write, and any story that risks either waits for Stage 2. Every new tool declares `read` or `write` when it is defined, or the build fails. Every new write key is added to Epic 14's governance baseline rather than left to default.
- **The system prompt is one build-time constant.** Nothing read at runtime is joined to it, and a definition's override replaces it whole. 11.9 and 11.10 added these statements:
  - Answer from the screen context when it holds the answer. Call a read tool when it does not, or when its rows were cut.
  - While read-only, describe the change instead of proposing it.
  - Use only the tools offered.
  - Open the screen under discussion with the navigation tool before answering or proposing.

  Later stories extend the prompt under the same rule, and 11.4 replaces its plain-text row-naming sentence.
- **Streaming is in place (11.7).** A turn's reply grows in place while the model writes; later stories must keep it intact:
  - The wire is unchanged: the turn is a background job, the panel polls progress every second, and no key joins the progress payload or a step. Streamed text is a whole-text snapshot in the running model step's `text`, never a delta.
  - The growing block renders through the same reply component as the final reply, is `inert` (neither focusable nor announced), and shows only while the turn is live, running and has no error banner. When the turn ends it is removed and the final reply renders exactly as a non-streamed turn's would. Nothing animates it.
  - A provider refusal fails the turn `PROVIDER.DECLINED` ("The model declined to answer this request") with no reply.
  - No new transport to the browser, no DOM-append renderer (the reply rebuilds on every change), and no new user-visible string came with it.
- **Privilege line (11.8).** Every write proposal card carries one line. It names the pairs the write's own gate requires, the endpoint's `ResourcesOR()` resource among them, recorded at mint through the method Confirm's gate calls. Whether the user holds them is evaluated on the instance by Confirm's own check at each read of the proposal (AD-8, amended 2026-09-25); there is no new derivation and no second source of truth. The line says "requires", never "sufficient", because `ResourcesOR()` is a lower bound. When a pair is missing, the line reads as a warning and Confirm stays enabled, since the instance is the authority. The audit marker and the ledger do not change. Row-action tooltips and Save bars may carry the same line; anywhere it is not wired is recorded as an omission.
- **Explain (11.1, 11.2).**
  - "Explain this screen" is one click from the panel on every screen. The reply names the screen's purpose, the data shown and the actions available, and it cites the read tool it used.
  - Every log viewer row and every audit-database row has an explain entry point that sends that entry, and only that entry, as context.
  - For an application error, only the summary fields go. The captured variable table never goes, because it can hold patient data.
  - Entry text reaches the model as delimited tool-result content, never as an instruction.
- **Suggested prompts (11.3).** When the panel is idle, each screen offers at least three prompts, grouped by task; choosing one sends it as a turn. A screen declares its prompts in its own descriptor, next to its command-box aliases. 11.3 covers every screen that exists when it runs. The Epic 9 and Epic 12 editors already declare their own prompts, and EXPERIENCE.md's string table lists them.
- **Citation chips (11.4).** A reply that used a read tool carries a chip for each row it used. Clicking a chip selects the row or opens the screen through the same allow-listed navigation the agent uses, never through a URL. Chips replace Release 1's plain-text row names and the offer to select them, so replies get shorter. A target that no longer exists reports "no longer present" and does not fail the screen.
- **Testing.** CI calls no live model: tests pin the prompt statements, the payload members and the defaults. Live behaviour is proven in the owner's check in Story 17.7. Anything about scroll or geometry needs a browser spec, because jsdom computes no layout, and a browser spec runs against the redeployed bundle.

## Technical Decisions

- **Untrusted content never becomes instruction.**
  - Screen context enters as a synthetic `screen.context` tool call and its result, placed before the user's message and never advertised as a tool.
  - Navigation accepts only registry routes. It is announced, reversible with Back, and the departing screen may refuse it.
  - Nothing rendered from a reply, a tool result or a progress record requests any host. Streamed text follows the same rules: sanitized, markup-free, rendered as data.
  - Tools that the browser fulfils are read-only by rule.
- **Context bounds.**
  - Rows are capped per instance (1 to 1,000, default 200).
  - The payload is capped at 65,536 characters, cut by whole rows from the end.
  - Each field is capped at 1,000 characters, and a cut value ends in U+2026.
  - The payload reports `rowsSent`, `rowsAvailable`, `truncated` and `truncatedFields`, and secret-typed fields never leave the instance.
  - The kernel adds `tools` and `readOnly` on the instance. They count within the size bound, and a request that carries either is refused `TURN.CONTEXT.INVALID`.
  - Earlier turns replay only as user messages and final replies.
- **One read for a screen and its tool.** A screen and its read tool share one declared read, bounded and stripped of secret fields. That is what makes a citation traceable to the same read the screen made.
- **Progress channel.** Progress lives in protected storage, is owned by the user who started the turn, and is capped per turn; the panel renders it as untrusted data. A running model step's snapshot is written at most every 400 ms, only when it has grown, within the step's text cap, and is overwritten by the step's outcome (final text, or empty on a fault).
- **Provider calls.** Only a turn's model call streams; Test connection never does. A transport failure before any status line is retried once on a new connection. A status line followed by a broken body, an in-stream error or a missing terminator ends `PROVIDER.TRANSPORT` and is never retried. A write is never retried mid-flight.
- **Privilege.** `ResourcesOR()` is a lower bound: the vendor query behind an endpoint may check more, and the instance's refusal is the verdict.
- **Read-only.** Read-only and the kill switch are evaluated on the instance at the point of effect. While either is in force, a write tool returns a "blocked" result and no proposal is minted.
- **Ids and references.** Chip targets and routes carry the scoped triple (entity type, scope, id), with the id percent-encoded in one path segment. Stored references are weak and render as "no longer present".
- **Error envelope.** There is one envelope: a screen renders its `reason`, and a tool result renders its `code`.
- **Application error log.** It is read through `SYS.ApplicationError` in `%SYS`, with the target namespace passed as a parameter. Its detail payload never enters a tool result or the screen context.

## UX & Interaction Patterns

- "Primary navigation is the agent": it answers, proposes, and takes the user to the screen it means after announcing the move.
- Every user-visible string lives in the client string table and must also appear in EXPERIENCE.md's fixed-string table. "Explain this screen" is already listed as a panel one-click action.
- While Busy, the reply grows in place at the poll's pace, rendered like the final reply, not announced and not focusable until final; if the turn stops or fails, the partial text is removed and the turn ends as it would have without streaming.
- The transcript (`role="log"`, polite) follows new entries, streamed text included, while it is within 4 CSS px of the bottom. Once the user scrolls away, it stays put and shows "Jump to latest". Under reduced motion, scrolls are instant.
- The context chip reads `<Screen>, <NAMESPACE> · <N rows>`, and `<N rows>` must match what the next turn sends.
- Home shows its starter prompts, because EXPERIENCE.md is canonical over the greeting.

## Cross-Story Dependencies

- Epic 11 depends on Epics 4, 5, 6 and 10:
  - Story 4.4: the context payload.
  - Story 4.7: navigation.
  - Story 4.10: Home's starter prompts.
  - Story 4.11: the context chip.
  - Epic 5: the proposal card.
  - Story 1.9: the privilege map.
- 11.1 and 11.4 build on 11.9's prompt and context members. Any change to the reply or transcript render path must keep 11.7's streamed block and 11.10's follow rule working.
- Epic 12 edits the same panel and turn files in its own regions (the proposal outcome and write-card code); leave those hunks alone.
- 11.2's rule that the variable table never goes is the same rule 11.9 applies to the error list's context.
- The seeded-injection test (Story 14.8) will run against this prompt once it exists.
- Ledger items routed here must be addressed, or declined with a reason:
  - 11.1:
    - DW-458: a narrowed panel brings the side bar back and cannot be widened again.
    - DW-460: the rail stays live while the panel is full screen.
    - DW-1077: Home's empty route mislabels the chip.
    - DW-1112: a status-0 Send shows two identical alert banners.
  - 11.2:
    - DW-1610: the error list's context rows carry the shell's namespace and no date.
  - 11.3:
    - DW-1147: the all-zero starter fallback fires on a refused read.
    - DW-1158: Home shows its prompts.
    - DW-1160: a zero-count line renders a dateless sentence.
