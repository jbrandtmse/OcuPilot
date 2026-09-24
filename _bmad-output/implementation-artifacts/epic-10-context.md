# Epic 10 Context: Run on any model, and harden the write path

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

An operator runs the agent on the vendor they already pay for (OpenAI, Google Gemini) or on a model hosted on their own network through any OpenAI-compatible endpoint, so adopting OcuPilot needs no new vendor relationship and a change-controlled site can keep screen data inside the instance. Stories 10.1-10.3 delivered the translators and the three extra adapters behind the fixed provider contract. The epic was reopened on 2026-09-23 for two high-priority live-key fixes that make every shipped provider's catalog default model connect on the first try. 10.4 (done) left sampling parameters to the provider. 10.5 makes Test connection answer with OcuPilot's own reason before the Web Gateway's timeout produces an empty 504, and carries two Gemini defects the smoke found.

## Stories

- Story 10.1: The message and tool-definition adapters (done)
- Story 10.2: The OpenAI and Google Gemini adapters (done)
- Story 10.3: The OpenAI-compatible adapter, and local models (done)
- Story 10.4: Sampling parameters left to the provider (done)
- Story 10.5: A connection test that answers before the gateway does

## Requirements & Constraints

- **Adding or changing provider behaviour is adapter work plus a form entry.** No change to the agent loop, the tool registry, the proposal lifecycle or any screen other than the Definition form. The agent's observable behaviour must not depend on which of the four families is chosen.
- **Test connection must answer before the Web Gateway does.** Its wait is bounded safely below the gateway's configured `Server_Response_Timeout`, or 60 s when the value cannot be read. Raising that setting therefore lengthens the test. The installer already reads the value (`OcuPilot.Install.Installer.GatewayResponseTimeout`, registry first, then the gateway config file). It only reports the value and never changes it, and there is no Web Gateway prerequisite.
  - On timeout, a definition marked local gets a reason saying the model may still be loading and to test again in a minute.
  - Any other definition gets a reason naming the provider and how long the test waited.
  - A timed-out test never marks the definition verified. A later passing test enables it as usual.
- **Agent turns have no gateway limit.** A turn whose first provider call outlasts the gateway timeout must still complete, because the turn runs in a background job. Pin this with a stub that delays past the gateway's bound.
- **DW-1600 (routed to 10.5).** Every Gemini turn is refused on its first provider call. The navigate tool's route `enum` is built from every built screen's route, Home's route is the empty string, and Gemini refuses an empty enum value. Any fix must keep one tool array serving all four families, and the cross-vendor JSON-Schema subset must not be relaxed for one vendor.
- **DW-1601 (routed to 10.5).** Test connection on Gemini's default model (`gemini-3.8-flash`) returns an empty or cut-off reply. Gemini 3 thinks by default, and thinking consumes the fixed 32-token test budget (`TESTMAXTOKENS`). That budget is small on purpose: a yes-or-no check must not cost a turn's money. The planning docs do not decide the fix.
- **CI never calls a live provider.** Stubs pin every request body, and a stub's delay stands in for a slow provider. The live proof on each catalog default model is the owner's check in Story 17.7.

## Technical Decisions

- **One provider base with four adapters behind `ProviderPort` (AD-42).** Anthropic's message shape is canonical. The other families translate both ways through the message and tool-definition adapters, and nothing outside the port speaks a vendor dialect. The catalog is the one source for per-family facts (AD-5). The form and the adapters read catalog columns, never a provider name.
- **Delivered by 10.4, and 10.5 builds on it:**
  - Temperature is optional. The catalog declares `canonicalTemperature` `null`, and the `acceptsTemperature` column tells the form which families take a temperature. Anthropic requests never carry sampling parameters.
  - The catalog's `reasoningEffort` column is `"none"` on openai and empty elsewhere. It is not served to the form. OpenAI writes `reasoning_effort` only when the value is non-empty.
  - Anthropic reasoning blocks travel verbatim. `Response.ContentJson` holds the reply's content array when it has thinking blocks, and `Loop.AnswerTools` echoes that array unchanged.
  - A Gemini `functionCall`'s `thoughtSignature` is kept on the canonical `tool_use` block and written back byte for byte.
  - Reasoning never crosses a turn, and it is never rendered or persisted.
- **Retry and timeout rules are shared across adapters.**
  - Retry only on a retryable status. The delay is the greater of the provider's hint and exponential backoff with jitter. A call that threw mid-flight is never retried.
  - Stored per-call timeouts and attempt counts are clamped at the point of use so that they fit the 300 s attempt budget.
  - One call's worst case is the attempt budget plus the per-call timeout, because the deadline only gates when an attempt may start (DW-1104).
  - `%Net.HttpRequest.Timeout` re-arms on each socket read. So the 10.5 bound cannot rely on the per-call timeout alone to beat the gateway (inference).
- **Never throw from a provider call.** A failure becomes a turn error or a Test-connection result in the single error envelope `{error, reason, code, detail}`, with a stable dotted-uppercase `code` (AD-39). Vendor text is normalized at the port boundary. Raw text goes only to the log and the ledger.
- **Background turns (AD-7).** `POST /turn` starts a job and returns a turn id at once, and the panel polls. No request is held open for a turn. Test connection is a foreground request, which is why only it needs the gateway-aware bound.
- **Egress is an allow-list (AD-42).** Test connection exercises the configured endpoint with a minimal budget and takes the same TLS path as a real turn (AD-32).
  - A marked-local definition may name a loopback or private address and bypasses any proxy. A cloud metadata endpoint is refused in every address family.
  - A stored credential goes only to the stored endpoint.
  - Changing provider, endpoint or credential disables the definition until a test passes.
- **Secrets never surface (AD-35).** A key is fetched at the point of use and cleared before return. It never appears in a status, log line, trap or URL, and that holds on the new timeout path.
- **Definitions live in protected OcuPilot state.** Writes are conditional on `RowVersion` and fail with a 409 `STATE.CONFLICT` on mismatch. Normalize `$Char(0)` on `%String` reads whose write path includes SQL `UPDATE`.

## UX & Interaction Patterns

- **Test connection result:**
  - The button shows inline progress while running. Success reads "Connected. Reply: <the model's first words>" in `role="status"`.
  - A provider refusal reads "The provider refused the request. Check the key and try again. Provider said: <text>".
  - Nothing about a failure is stored: no failed-test state and no rail badge.
- **Fixed strings are canonical and verbatim.** 10.5's two timeout reasons each become a row in EXPERIENCE.md's Fixed strings table and a key in `ui/src/app/core/strings.ts`, with non-ASCII written as `\uXXXX`. Copy is in the second person, says what happened and what to do next, and never shows raw provider JSON alone.
- The Temperature field shows "Provider default" when unset. Where `acceptsTemperature` is false it is readonly, reads "Not applicable" and carries a caption (delivered in 10.4).

## Cross-Story Dependencies

- 10.5 runs after 10.4 in the same runner, and both were dispatched ahead of Epic 12. 10.5 builds on 10.4's catalog columns and echo path, and on Test connection and the Definition form from the agent-configuration epic.
- The README's note on the Web Gateway response timeout for slow models belongs to Story 17.6. The per-provider live check on catalog default models belongs to Story 17.7, which the owner runs.
- Token streaming in the polish-week epic depends on this epic and must not put the write path at risk.
