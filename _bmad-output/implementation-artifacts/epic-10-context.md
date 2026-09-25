# Epic 10 Context: Run on any model, and harden the write path

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

An operator runs the agent on the vendor they already pay for (OpenAI, Google Gemini) or on a model hosted on their own network through any OpenAI-compatible endpoint, so adopting OcuPilot needs no new vendor relationship and a change-controlled site can keep screen data inside the instance. Stories 10.1-10.3 delivered the translators and the three extra adapters behind the fixed provider contract. The epic was reopened for live-key fixes that make every shipped provider's default model work on the first try: sampling parameters left to the provider (10.4), a connection test that answers before the Web Gateway's timeout (10.5), and now 10.6, where a momentary network failure no longer ends a turn and a confirmed create reports "created" rather than the wrong outcome. The aim of 10.6 is that the agent reads as reliable to a judge on the first try.

## Stories

- Story 10.1: The message and tool-definition adapters (done)
- Story 10.2: The OpenAI and Google Gemini adapters (done)
- Story 10.3: The OpenAI-compatible adapter, and local models (done)
- Story 10.4: Sampling parameters left to the provider (done)
- Story 10.5: A connection test that answers before the gateway does (done)
- Story 10.6: A turn survives a dropped connection, and a create says created (open, the only remaining story)

## Requirements & Constraints

- **Adding or changing provider behaviour is adapter work plus a form entry.** The agent loop, the tool registry, the proposal lifecycle and every screen except the Definition form stay unchanged. The agent's observable behaviour must not depend on which of the four families is chosen.
- **A model call survives one transport failure (10.6).** A transport failure means the connection broke before a status line arrived, as `ERROR #6097 <READ>` did on slot C within a second of the call.
  - The adapter retries the call once, on a new connection, inside the existing attempt and delay budget.
  - If the retry also fails, the turn stops with its present reason (`PROVIDER.TRANSPORT`).
  - A status line that arrived (any 4xx or 5xx) is not a transport failure and keeps the existing retryable-status handling.
  - The exception is for a model call only, because a model call changes nothing on the instance.
- **No provider request reuses a kept-open connection.** Every request is built with `SocketTimeout` 0, which disables `%Net.HttpRequest` keep-alive reuse, so the adapter never reads from a connection that the provider or the network closed while it sat idle.
- **Writes are never retried mid-flight.** A write tool call that threw mid-flight is never retried, because the instance may already have applied it. 10.6 must pin this with a test.
- **A confirmed create says created.** When a proposal from a tool that declares `created` is confirmed, both the toast and the panel must read "<entity> was created". Every create tool already declares `created`, so the fault is on the path from the confirm to the panel (inference).
- **CI never calls a live provider.** Stubs pin every request body, and 10.6 needs three pins:
  - A stub that breaks the first connection proves the retry succeeds on the second.
  - A stub that breaks both connections proves the turn stops with `PROVIDER.TRANSPORT`.
  - A test proves no write tool call is ever retried.
  - The live check on each catalog default model is the owner's, in Story 17.7.
- **Constraints from 10.5 that the retry must not break:**
  - Test connection's wait stays bounded by `g - min(10, g\2)` seconds, where `g` is the gateway's `Server_Response_Timeout`, or 60 when it cannot be read.
  - A timed-out test never marks a definition verified.
  - Agent turns have no gateway limit, because each turn runs in a background job.

## Technical Decisions

- **One provider base with four adapters behind `ProviderPort` (AD-42).**
  - Anthropic's message shape is canonical. The other families translate both ways through the message and tool-definition adapters, and nothing outside the port speaks a vendor dialect.
  - The catalog is the only source of per-family facts (AD-5). The form and the adapters read catalog columns and never branch on a provider name.
  - The cross-vendor JSON-Schema subset rule stays as written, so that one tool array serves all four families.
- **AD-42 already carries the 10.6 retry rule.** The spine was amended at 10.6's plan gate (owner decision). A model call gets one retry on a new connection after a transport failure, inside the same budget. Every write keeps the never-retry-mid-flight rule without exception, and every provider request sets `SocketTimeout` 0. The code must implement the rule as the spine states it. The story does not edit the spine again.
- **Budgets are shared across adapters.**
  - The retry delay is the greater of the provider's hint and exponential backoff with jitter.
  - Stored per-call timeouts and attempt counts are clamped at the point of use to fit the 300 s attempt budget. They are never refused.
  - One call's worst case is the attempt budget plus the per-call timeout, because the deadline only controls when an attempt may start.
  - `%Net.HttpRequest.Timeout` re-arms on each socket read, so a provider that sends its reply slowly is bounded by the turn limits (AD-31), not by the per-call timeout.
- **A provider call never throws.** A failure becomes a turn error or a Test-connection result in the single error envelope `{error, reason, code, detail}`, with a stable dotted-uppercase `code` (AD-39). Vendor text is normalized at the port boundary, and raw text goes only to the log and the ledger.
- **Turns run in the background (AD-7).** `POST /turn` starts a job and returns a turn id immediately, and the panel polls for the result. Only Test connection is a foreground request, and its one call runs in the `Kernel.Provider.TestCall` child job.
- **Delivered in 10.4 and 10.5, not to regress:**
  - Anthropic requests never carry `temperature`, `top_p` or `top_k`. The other families send a temperature only when one is set.
  - OpenAI writes `reasoning_effort` only when the catalog value is non-empty.
  - Anthropic thinking blocks and Gemini `thoughtSignature` values are echoed back byte for byte within a turn. Reasoning never crosses turns and is never rendered or persisted.
  - The navigate tool's route enum does not carry an empty value.
- **Egress and secrets (AD-32, AD-35, AD-42).**
  - A retry takes the same TLS, proxy and allow-list path as the first attempt (inference). A marked-local definition bypasses the proxy, and a cloud metadata endpoint is refused.
  - A key is fetched at the point of use and cleared before return. It never appears in a status, log line, trap or URL, including on the retry path.
- **Confirm outcomes are the AD-14 actions.** Created, updated and deleted each have one sentence, and `<entity>` resolves to the entity's own id.

## UX & Interaction Patterns

- **Outcome sentences are fixed strings.** "<entity> was created", "<entity> was updated" and "<entity> was deleted" are used in two places:
  - the sentence of the off-screen change toast;
  - the sentence the panel appends to a confirmed write's reply, so the record lasts after the toast is gone.
- The toast's "Open in <screen>" link names the screen the entity belongs to. 10.6 needs a browser spec that pins "was created" end to end for a web-application create.
- When both attempts fail, the turn stops with its existing `PROVIDER.TRANSPORT` reason. The story adds no new failure sentence.
- Fixed strings are canonical and verbatim. Each one is a row in EXPERIENCE.md's Fixed strings table and a key in `ui/src/app/core/strings.ts`, with non-ASCII written as `\uXXXX`.

## Cross-Story Dependencies

- **10.6 has its own slot.** It runs alone on slot B at Epic 12's next story boundary, and Epic 12 resumes after 10.6 merges. It builds on the 10.1-10.5 adapters and budgets.
- **The created-outcome fix spans two epics.** It touches the confirm path from Epic 5, whose Story 5.7 introduced the panel's outcome sentence, and the create tools that declare `created`.
- **The README and the live check belong to Epic 17.** The README note on the Web Gateway timeout for slow models is Story 17.6. The live check of each provider on its catalog default model is Story 17.7, which the owner runs.
- **Token streaming depends on this epic.** Streaming lands in the polish-week epic, and it must not put the write path or the never-retry-writes rule at risk.
