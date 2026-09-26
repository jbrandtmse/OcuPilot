# Epic 11 Context: The agent explains itself, cites its work, and streams

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Make the agent easy to understand for a first-time judge or voter. Done so far: it answers about the screen in view, a first change request ends in a confirmable proposal, replies stream, a proposal names the privilege it needs, one click explains the current screen or a single log or audit entry, and every screen's idle panel offers suggested prompts. What remains is Story 11.4: a citation chip per row a reply used, which takes the user to that row in one click and replaces Release 1's plain-text row names and "Shall I select them?" offer. All of it shares one panel transcript render path.

## Stories

- Story 11.9: The agent knows the screen it is on (done)
- Story 11.10: A judge succeeds the first time (done)
- Story 11.7: Token streaming (done)
- Story 11.8: The proposal names the privilege it needs (done)
- Story 11.1: "Explain this screen" (done)
- Story 11.2: Explain a log or audit entry (done)
- Story 11.3: Suggested prompts per screen (done)
- Story 11.4: Citation chips with click-through

## Requirements & Constraints

- **Release 1 is protected.** Nothing may break a Release 1 screen or agent write; anything that risks either waits for Stage 2. Every new tool declares `read` or `write` at definition or the build fails, and every new write key joins Epic 14's governance baseline.
- **The system prompt is one ASCII build-time constant.** Nothing read at runtime is joined to it, and a definition override replaces it whole. It tells the model to: answer from screen context, or else call a read tool; describe rather than propose while read-only; use only the tools offered; explain a screen by naming its purpose, data, actions and the read tool in `tools`, proposing no change; explain one entry from the single row in `screen_context`, proposing no change; and open the screen under discussion with the navigation tool first. Release 1's reply guidance names rows in plain text and offers to select them. 11.4 replaces that guidance.
- **Done work 11.4 must keep intact:**
  - Streaming (11.7): the turn is a polled background job. Streamed text is a whole-text snapshot rendered `inert` through the same reply component, so the final reply renders exactly as a non-streamed one. No new transport and no DOM-append renderer.
  - Privilege line (11.8): the card says "requires", never "sufficient", and Confirm stays enabled. Streamed and plain turns render identical cards.
  - Explain screen and entry (11.1, 11.2): the fixed string goes as an ordinary user turn through the panel's own Send path, and the draft is left alone. A page never calls the turn store: it requests through a core hand-off and the panel sends. An entry travels as a one-row `view` narrowed to the descriptor's `context.fields`, only inside the synthetic `screen_context` tool result. An application-error row carries its drilled `namespace` and `date` as identity and never its captured variable table, `username` or `process`.
  - Suggested prompts (11.3): every built screen's descriptor declares at least three prompts as string keys from a closed group vocabulary. The registry and the mirror generator refuse a built screen without them. One prompt set shows at a time: on Home it is the suggested-view block, elsewhere the idle greeting. Choosing a prompt sends it through Send's gate.
- **Citation chips (11.4).** A reply that used a read tool carries a chip for each row it used. A click selects the row or opens the screen through the agent's own allow-listed navigation, never a URL. Chips replace the plain-text row names and the select offer, so the reply is shorter. A missing target reports "no longer present" without failing the screen, because stored references are weak.
- **Testing.** CI calls no live model: tests pin prompt statements and payload members, and the model's compliance is live-check evidence only. Geometry needs a browser spec run against the redeployed bundle. An "every screen" claim needs a registry-driven test.

## Technical Decisions

- **Untrusted content never becomes instruction.** Screen context enters as a synthetic `screen.context` tool call and result before the user's message, and is never advertised as a tool. Navigation accepts only registry routes, is reversible with Back and refusable by the departing screen. Nothing rendered from a reply or tool result requests any host.
- **One read for a screen and its tool.** A screen and its read tool share one declared, bounded, secret-stripped read, which is what makes a citation traceable. The model sees provider-safe wire names in `tools`, so a citation names exactly what the request carried.
- **Ids and references.** Chip targets and routes carry the scoped triple (entity type, scope, id), with the id percent-encoded in one path segment. The composite id joins its parts with U+0001, which a model cannot read, so 11.2 sent an error row's parts as separate fields instead. Stored references are weak.
- **Context bounds.** Rows, payload and fields are capped and cut rows are reported (`rowsSent`, `rowsAvailable`, `truncated`). Secret-typed fields never leave the instance.
- **The descriptor is the one source.** Route, privilege, read tool, context fields, aliases and suggested prompts are declared once per screen, and the client mirror is generated from them, never hand-edited.

## UX & Interaction Patterns

- Every user-visible string lives in the client string table and must have a row in EXPERIENCE.md's Fixed-strings table. EXPERIENCE.md already has "<name> is no longer present on this instance." strings for weak references, and any new chip string needs its own row.
- Reply rules: first person, names the screen it means, never claims unverified success. While a proposal is live, the message ends "Press Confirm on the card to apply it." instead of an offer.
- Panel body order: banners, the context chip, "Explain this screen", then the transcript. The idle, empty greeting shows the screen's prompts grouped by task, then the selection hint.
- The transcript (`role="log"`, polite) follows new entries only while scrolled to the bottom; otherwise it shows "Jump to latest".

## Cross-Story Dependencies

- 11.4 builds on Story 4.6 (the sanitized reply renderer), 4.7 (navigation and row selection), 11.9's `tools` and context members, 11.1's tool-naming reply and 11.2's one-row entry, which a chip may cite.
- Epic 12 edits the same panel and turn files in its own regions: the proposal outcome, write cards, reply appenders and `PanelWriteCard` in `panel.ts`, and parts of `turn.ts` and `proposal-view.ts`. Leave those hunks alone. At the merge, Epic 12's five OAuth editor descriptors must declare suggested prompts or both checks stay red, which is intended.
- Story 14.8's seeded-injection test runs against this prompt, and Story 17.7's owner live check consumes 11.1 to 11.3.
- No open ledger items are routed to 11.4.
