# Epic 11 Context: The agent explains itself, cites its work, and streams

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Make the agent easy to understand for a first-time judge or voter. Done so far: it answers about the screen in view, a first change request ends in a confirmable proposal, replies stream, and a proposal names the privilege it needs. What remains: explain any screen or log entry in one click, offer suggested prompts per screen, and let a citation chip take the user to the row the agent used. Polish-week work that may keep landing through the voting week; every story changes the same panel transcript render path. The rest run in the order 11.1, 11.2, 11.3, 11.4 (owner re-order, 2026-09-22).

## Stories

- Story 11.9: The agent knows the screen it is on (done)
- Story 11.10: A judge succeeds the first time (done)
- Story 11.7: Token streaming (done)
- Story 11.8: The proposal names the privilege it needs (done)
- Story 11.1: "Explain this screen"
- Story 11.2: Explain a log or audit entry
- Story 11.3: Suggested prompts per screen
- Story 11.4: Citation chips with click-through

## Requirements & Constraints

- **Release 1 is protected.** Nothing may break a Release 1 screen or agent write; anything that risks either waits for Stage 2. Every new tool declares `read` or `write` at definition or the build fails, and every new write key joins Epic 14's governance baseline.
- **The system prompt is one build-time constant.** Nothing read at runtime is joined to it. Its current statements: answer from the screen context when it holds the answer, else call a read tool; while read-only, describe the change instead of proposing it; use only the tools offered; open the screen under discussion with the navigation tool first. 11.4 replaces the plain-text row-naming sentence.
- **Done work later stories must keep intact:**
  - Streaming (11.7): the turn is a background job polled every second; streamed text is a whole-text snapshot in the running model step's `text`, rendered `inert` through the same reply component, removed when the turn ends so the final reply renders exactly as a non-streamed one. No new transport, no DOM-append renderer.
  - Privilege line (11.8): a proposal records at mint the pairs its write's gate requires; its wire row carries `privilege: {requires, missing}`, with `missing` evaluated at each read by Confirm's own check, or `null` when nothing was recorded. The card says "requires", never "sufficient", and Confirm stays enabled. Streamed and plain turns render identical cards. After a turn ends the line is not refreshed until a restore (open, escalated to burndown).
- **Explain (11.1, 11.2).** "Explain this screen" is one panel click on every screen; the reply names purpose, data shown and actions available, and cites the read tool it used. Every log viewer and audit-database row has an explain entry point that sends that entry, and only that entry. For an application error only the summary fields go, never the captured variable table (it can hold patient data). Entry text reaches the model as delimited tool-result content, never as instruction.
- **Suggested prompts (11.3).** When the panel is idle, each screen offers at least three prompts grouped by task; choosing one sends it. A screen declares prompts in its own descriptor beside its command-box aliases. 11.3 covers every screen existing when it runs; Epic 9 and 12 editors declare their own.
- **Citation chips (11.4).** A reply that used a read tool carries a chip per row used. A click selects the row or opens the screen through the agent's allow-listed navigation, never a URL. Chips replace the plain-text row names and select offer. A missing target reports "no longer present" without failing the screen.
- **Testing.** CI calls no live model: tests pin prompt statements, payload members and defaults. Anything about scroll or geometry needs a browser spec, run against the redeployed bundle.

## Technical Decisions

- **Untrusted content never becomes instruction.** Screen context enters as a synthetic `screen.context` tool call and result before the user's message, never advertised as a tool. Navigation accepts only registry routes, is announced, reversible with Back, and refusable by the departing screen. Nothing rendered from a reply, tool result or progress record requests any host; browser-fulfilled tools are read-only.
- **Context bounds.** Rows capped per instance (1 to 1,000, default 200); payload capped at 65,536 characters, cut by whole rows from the end; each field capped at 1,000 characters, ending in U+2026 when cut. The payload reports `rowsSent`, `rowsAvailable`, `truncated`, `truncatedFields`; secret-typed fields never leave the instance. A request carrying `tools` or `readOnly` is refused `TURN.CONTEXT.INVALID`.
- **One read for a screen and its tool.** A screen and its read tool share one declared, bounded, secret-stripped read, which is what makes a citation traceable.
- **Privilege.** `ResourcesOR()` is a lower bound; the instance's refusal is the verdict. The shell's privilege map answers per area and screen, never per pair.
- **Read-only and kill switch** are evaluated on the instance at the point of effect; a write tool returns "blocked" and no proposal is minted.
- **Ids and references.** Chip targets and routes carry the scoped triple (entity type, scope, id), the id percent-encoded in one path segment. Stored references are weak.
- **Application error log** is read through `SYS.ApplicationError` in `%SYS` with the namespace as a parameter; its detail payload never enters a tool result or screen context.

## UX & Interaction Patterns

- Every user-visible string lives in the client string table and must appear in EXPERIENCE.md's fixed-string table. "Explain this screen" is already listed there as a panel one-click action.
- The transcript (`role="log"`, polite) follows new entries while within 4 CSS px of the bottom; scrolled away, it stays put and shows "Jump to latest". Reduced motion makes scrolls instant.
- The context chip reads `<Screen>, <NAMESPACE> · <N rows>`, and `<N rows>` must match what the next turn sends.
- Home shows its starter prompts; EXPERIENCE.md is canonical over the greeting.

## Cross-Story Dependencies

- Builds on Story 4.4 (context payload), 4.7 (navigation), 4.10 (Home's starter prompts), 4.11 (context chip), Epic 5 (proposal card) and 1.9 (privilege map). 11.1 and 11.4 build on 11.9's prompt and context members.
- Epic 12 edits the same panel and turn files in its own regions (proposal outcome, write cards, `panel.ts`, parts of `turn.ts` and `proposal-view.ts`); leave those hunks alone.
- 11.2's variable-table rule is the one 11.9 applies to the error list's context.
- Story 14.8's seeded-injection test will run against this prompt.
- Ledger items to address or decline with a reason:
  - 11.1: DW-458 (narrowed panel brings the side bar back and cannot widen again), DW-460 (rail stays live while the panel is full screen), DW-1077 (Home's empty route mislabels the chip), DW-1112 (status-0 Send shows two identical alert banners).
  - 11.2: DW-1610 (error list's context rows carry the shell's namespace and no date).
  - 11.3: DW-1147 (all-zero starter fallback fires on a refused read), DW-1158 (Home shows its prompts), DW-1160 (zero-count line renders a dateless sentence).
