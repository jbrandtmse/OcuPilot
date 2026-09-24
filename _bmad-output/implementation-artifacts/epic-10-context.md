# Epic 10 Context: Run on any model, and harden the write path

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

An operator runs the agent on the vendor they already pay for (OpenAI, Google Gemini) or on a model hosted on their own network through any OpenAI-compatible endpoint, so adopting OcuPilot needs no new vendor relationship and a change-controlled site can keep screen data inside the instance. Stories 10.1-10.3 delivered the translators and the three extra adapters behind the fixed provider contract. The epic was reopened on 2026-09-23 for two high-priority live-key fixes that make every shipped provider's catalog default model connect on the first try. 10.4 leaves sampling parameters to the provider. 10.5 makes Test connection answer with OcuPilot's own reason before the Web Gateway's timeout produces an empty 504.

## Stories

- Story 10.1: The message and tool-definition adapters (done)
- Story 10.2: The OpenAI and Google Gemini adapters (done)
- Story 10.3: The OpenAI-compatible adapter, and local models (done)
- Story 10.4: Sampling parameters left to the provider
- Story 10.5: A connection test that answers before the gateway does

## Requirements & Constraints

- **Adding or changing provider behaviour is adapter work plus a form entry.** No change to the agent loop, the tool registry, the proposal lifecycle or any screen other than the Definition form. The agent's observable behaviour must not depend on which of the four families is chosen.
- **Temperature is optional.** A new definition stores temperature unset, and validation accepts unset. An explicit value from 0 to 2 remains possible where the provider takes one. A definition saved before 10.4 keeps its stored temperature as an explicit value, and nothing migrates or rewrites it. Adding an optional property that old rows read safely does not move `SCHEMAVERSION`; record that reasoning at the change.
- **Request bodies:** with temperature unset, OpenAI, Gemini and OpenAI-compatible requests carry no temperature, so the provider default applies. An Anthropic request never carries `temperature`, `top_p` or `top_k`, whatever the definition holds, because the current Claude models in the catalog refuse them.
- **Thinking blocks round-trip.** Claude Opus 5 thinks by default. When a turn calls a tool and then continues, the next request sends that assistant turn's thinking blocks back byte for byte.
- **CI never calls a live provider.** Stubs pin every request body: no sampling parameter to Anthropic, ever, and no temperature to the other families when it is unset. A stub returns a thinking block beside a tool call and asserts the block comes back unchanged. The live proof on each catalog default model is the owner's check at the demo freeze, not this epic's.
- **Test connection must answer before the Web Gateway does.** Its wait is bounded safely below the gateway's configured `Server_Response_Timeout`, which the installer already reads, or 60 s when the value cannot be read. Raising that setting therefore lengthens the test.
  - On timeout, a definition marked local gets a reason saying the model may still be loading and to test again in a minute.
  - Any other definition gets a reason naming the provider and how long the test waited.
  - A timed-out test never marks the definition verified. A later passing test enables it as usual.
- **Agent turns have no gateway limit.** A turn whose first provider call outlasts the gateway timeout must still complete, because the turn runs in a background job. Pin this with a stub that delays past the gateway's bound.
- There is no Web Gateway prerequisite. The installer only reports the timeout value and never changes it.

## Technical Decisions

- **One provider base with four adapters behind `ProviderPort`.** Anthropic's message shape is canonical. The other families translate both ways through the message and tool-definition adapters, and nothing outside the port speaks a vendor dialect. The cross-vendor JSON-Schema subset is locked and must not be relaxed for one vendor.
- **Retry and timeout rules are shared across adapters.**
  - Retry only on a retryable status. The delay is the greater of the provider's hint and exponential backoff with jitter.
  - A call that threw mid-flight is never retried.
  - Stored per-call timeouts and attempt counts are clamped at the point of use, never refused, so that attempts plus backoff fit the 300 s attempt budget.
  - `%Net.HttpRequest.Timeout` re-arms on each socket read, so a slowly dripping provider is bounded by the turn limits, not by the call timeout. The Test-connection bound in 10.5 therefore cannot rely on the per-call timeout alone to beat the gateway (inference).
- **Never throw from a provider call.** A provider failure becomes a turn error or a Test-connection result in the single error envelope: `{error, reason, code, detail}` with a stable dotted-uppercase `code`. Vendor text is normalized at the port boundary. The raw text goes only to the log and the ledger.
- **Background turns (AD-7).** `POST /turn` starts a job and returns a turn id at once, and the panel polls progress. No request is held open for a turn. Test connection, by contrast, is a foreground request, which is why only it needs the gateway-aware bound.
- **Egress is an allow-list (AD-42).** Test connection exercises the configured endpoint with a minimal budget and reports what it reached.
  - Marked-local definitions may name loopback or private addresses and bypass any proxy. A cloud metadata endpoint is refused in every address family.
  - A stored credential goes only to the stored endpoint. A body-supplied endpoint tested before save carries the body's own key or none.
  - Changing provider, endpoint or credential disables the definition until a test passes.
- **Outbound TLS (AD-32).** Calls use the installer-created named SSL configuration. Test connection takes the same path as a real turn.
- **Secrets never surface (AD-35).** A key is fetched at the point of use and cleared before return. It never appears in a status, log line, trap or URL, and that holds on the new timeout path too.
- **Definitions live in protected OcuPilot state.** Writes are conditional on `RowVersion` (a 409 `STATE.CONFLICT` on mismatch). Normalize `$Char(0)` on `%String` reads whose write path includes SQL `UPDATE`.

## UX & Interaction Patterns

- **Definition form:**
  - Name, provider, model, endpoint, key and Test connection sit above the fold. Maximum tokens, Temperature, Maximum iterations, System prompt override and Retention are collapsed under "Advanced", closed by default.
  - Choosing a provider cascades its defaults and suggested models, preserving values the user changed.
  - 10.4 makes Temperature read "Provider default" when unset. For Anthropic it shows the field as not applicable, with the reason.
- **Test connection result:**
  - The button shows inline progress while running. Success reads "Connected. Reply: <the model's first words>" in `role="status"`.
  - The provider-refusal sentence is "The provider refused the request. Check the key and try again. Provider said: <text>". Saving before a passing test shows "Saved — disabled until Test connection passes."
  - Nothing about a failure is stored: no failed-test state and no rail badge.
- **Fixed strings are canonical and verbatim.** Every new published sentence becomes a row in EXPERIENCE.md's Fixed strings table and a key in `ui/src/app/core/strings.ts`, with non-ASCII authored as `\uXXXX`. 10.5 requires this for its two timeout reasons. "Provider default" and the Anthropic not-applicable reason are new published sentences too, so they need rows as well (inference). The copy is second person, says what happened and what to do next, and never shows the provider's raw JSON alone.
- The context chip is computed from the same configuration as the request. A local provider shows its host with no "leaves the instance" pill.

## Cross-Story Dependencies

- 10.5 runs after 10.4 in the same runner, and both were dispatched ahead of Epic 12.
- Both build on the delivered 10.1-10.3 adapters, the provider base, the Definition form and Test connection from the agent-configuration epic. They must not modify the agent loop, the tool registry or the proposal lifecycle.
- The per-provider live check on catalog default models, including the demo prompts on every shipped provider, belongs to Story 17.7, which the owner runs.
- Token streaming in the polish-week epic depends on this epic and must not put the write path at risk.
