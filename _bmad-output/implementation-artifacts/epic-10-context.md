# Epic 10 Context: Run on any model, and harden the write path

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

An operator runs the agent on the vendor they already pay for (OpenAI, Google Gemini) or on a model hosted on their own network through any OpenAI-compatible endpoint, so adopting OcuPilot needs no new vendor relationship and a change-controlled site can keep screen data inside the instance. Stories 10.1-10.3 delivered the translators and the three extra adapters behind the fixed provider contract. The epic was reopened for live-key fixes that make every shipped provider's default model work on the first try: sampling parameters left to the provider (10.4), a connection test that answers before the Web Gateway's timeout (10.5), and turns that survive a dropped connection with a create that reports "created" (10.6). The last open story, 10.7, makes Claude Opus 5.5 the Anthropic default, so a first install gets Anthropic's current flagship model without editing the model name. It has high priority and must merge before the submission cut.

## Stories

- Story 10.1: The message and tool-definition adapters (done)
- Story 10.2: The OpenAI and Google Gemini adapters (done)
- Story 10.3: The OpenAI-compatible adapter, and local models (done)
- Story 10.4: Sampling parameters left to the provider (done)
- Story 10.5: A connection test that answers before the gateway does (done)
- Story 10.6: A turn survives a dropped connection, and a create says created (done)
- Story 10.7: Claude Opus 5.5 as the Anthropic default (open, the only remaining story)

## Requirements & Constraints

- **Default models are catalog configuration, not code.** Each provider's default model and model suggestions live in the provider catalog row and are shown as suggestions on the Definition form. Nothing hardcodes a model name in code.
- **The Anthropic default becomes `claude-opus-5-5` (10.7).**
  - A new Anthropic definition created without a model gets `claude-opus-5-5`.
  - The row's suggestions list `claude-opus-5-5` first, then keep `claude-opus-5`, `claude-sonnet-5`, `claude-haiku-4-5` and `claude-fable-5-1`.
  - A definition that already stores a model keeps it. Nothing migrates stored rows.
- **No sampling parameter goes to Anthropic, on any model.** A definition on `claude-opus-5-5` sends no `temperature`, `top_p` or `top_k`, exactly as on `claude-opus-5`. The owner verified a connection test and a tool-calling turn on `claude-opus-5-5` on the public demo on 2026-09-25, so 10.7 needs no live key.
- **Pins follow the new default.** Every test and fixture that pins the Anthropic row or its canonical default must name `claude-opus-5-5`. Test data that only needs some model name may keep `claude-opus-5`. The README's provider table, which names `claude-opus-5` today, must state the new default.
- **CI never calls a live provider.** Stubs pin every request body. The live check on each catalog default model belongs to the owner, in Story 17.7.
- **Adding or changing provider behaviour is adapter work plus a form entry.** The agent loop, the tool registry, the proposal lifecycle and every screen except the Definition form stay unchanged.

## Technical Decisions

- **One provider base with four adapters behind `ProviderPort` (AD-42).** Anthropic's message shape is canonical. The other families translate both ways through the message and tool-definition adapters, and the cross-vendor JSON-Schema subset rule stays as written so one tool array serves all four families.
- **Retry and budget rules, delivered, not to regress (AD-42):**
  - A retryable status is retried with the delay set to the greater of the provider's hint and exponential backoff.
  - A model call gets one retry on a new connection after a transport failure, inside the same budget.
  - A write is never retried after it threw mid-flight.
  - Every provider request sets `SocketTimeout` 0.
  - Stored timeouts and attempt counts are clamped at the point of use to the 300 s attempt budget, never refused.
- **A provider call never throws.** A failure becomes a turn error or a Test-connection result in the single error envelope with a stable dotted-uppercase `code` (AD-39).
- **Delivered in 10.4-10.6, not to regress:**
  - The other families send a temperature only when one is set.
  - OpenAI writes `reasoning_effort` only when the catalog value is non-empty.
  - Anthropic thinking blocks and Gemini `thoughtSignature` values are echoed back byte for byte within a turn.
  - Test connection's wait stays bounded below the gateway's `Server_Response_Timeout`.
  - A confirmed create reads "<entity> was created".
- **Secrets (AD-35).** A key is fetched at the point of use and cleared before return. It never appears in a status, log line, trap or URL.

## UX & Interaction Patterns

- The Definition form shows the catalog's model suggestions, so after 10.7 `claude-opus-5-5` is the first suggestion for Anthropic. The temperature field still reads as not applicable for Anthropic.

## Cross-Story Dependencies

- **10.7 builds on 10.4.** It reuses 10.4's no-sampling rule for Anthropic and the catalog row that 10.2 made the source of default models.
- **10.7 dispatch.** It runs on the first slot to free and merges before the submission cut.
- **Epic 17 owns the README note and the live check.** The README note on the Web Gateway timeout for slow models is Story 17.6. The live check of each provider on its catalog default model is Story 17.7, which the owner runs.
