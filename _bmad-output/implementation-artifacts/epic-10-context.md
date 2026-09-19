# Epic 10 Context: Run on any model, and harden the write path

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

An operator runs the agent on the vendor they already pay for — OpenAI or Google Gemini — or on a model hosted on their own network through any OpenAI-compatible endpoint, so adopting OcuPilot needs no new vendor relationship and a change-controlled site can keep screen data and log text inside the instance entirely. The provider contract, the credential ladder and the endpoint-egress policy were settled in the earlier agent-configuration epic precisely so this is adapter work against a fixed interface: three more adapters plus the message and tool-definition translators, with nothing above the port changing. This epic depends only on that earlier epic; the per-user restraints and remaining hardening it once carried were re-sequenced away by the owner on 2026-09-16 and are out of scope.

## Stories

- Story 10.1: The message and tool-definition adapters
- Story 10.2: The OpenAI and Google Gemini adapters
- Story 10.3: The OpenAI-compatible adapter, and local models

## Requirements & Constraints

- Four provider families — Anthropic, OpenAI, Google Gemini, any OpenAI-compatible endpoint including a local model — behind the same tool-calling contract, so the agent's observable behavior does not depend on which is chosen.
- Adding a family means an adapter plus a form entry: **no change to the agent loop, the tool registry, the proposal lifecycle or any screen.** This is an acceptance condition, not a guideline.
- An OpenAI-compatible endpoint must work with **no API key** when the endpoint requires none — the auth header is omitted, not sent empty.
- Plain HTTP is accepted only when no credential is configured, or with an explicit acknowledgment stored on the definition and shown in the egress treatment.
- Default models per provider are configuration surfaced as suggestions, never fixed in code, and must come from one place rather than being duplicated between form and defaults.
- Per adapter: Test connection succeeds and reports the model's reply, and a turn with tool calls completes. The read and write demo journeys must pass on every shipped provider before the demo freeze.
- The README presents small local models as the privacy option, with the caveat that the write path needs a model capable of reliable multi-field tool calls.

## Technical Decisions

- **One provider base, four adapters, behind `ProviderPort`.** Anthropic's message shape is canonical; every other family translates through the message and tool-definition adapters in both directions. Nothing outside the port speaks a vendor dialect.
- **The cross-vendor JSON-Schema subset is locked and kept verbatim:** an object with properties, required and additional properties refused; per property only type, description and optionally enum, items, numeric bounds, item-count bounds. Never references, unions or pattern. This is what lets one canonical tool array serve all four families — relaxing it for one vendor breaks the others.
- **Never-throw discipline.** The invoke template always returns success; a provider failure becomes an error stop reason and then a turn error, normalized into the single error envelope with a stable machine code — never an exception to the client, never raw vendor text.
- **Retry rules are shared, not per-adapter.** Retry only on a retryable status; delay is the greater of the provider's own hint and an exponential backoff with jitter, bounded by an attempt count; every call carries a bounded timeout. **A call that threw mid-flight is never retried** — it may already have been processed upstream. Worst case for one call is the attempt budget plus the stored per-call timeout, because a deadline only gates whether a further attempt may start.
- **Endpoint egress is policy, not a free-text URL.** Writing one requires the administrative resource and is audited as a security change. It validates to an absolute HTTPS URL, or an explicitly declared local address for the OpenAI-compatible adapter. Loopback and private addresses are allowed for local models **only** when the definition is explicitly marked local; the link-local metadata range stays refused, and the instance itself cannot be named.
- **A configured proxy is a destination too**, judged by the same host policy, with an HTTPS endpoint tunnelled so the proxy never terminates the session carrying the key — and a marked-local plain-HTTP endpoint **bypasses the proxy entirely** rather than crossing it in cleartext.
- **Outbound TLS uses a named SSL configuration the installer creates if absent**, server-identity checking on; never hardcoded to whatever a harvested adapter used, never left to the instance default. Proxy settings are configuration, not code.
- **Credentials resolve through an ordered ladder at the point of use and never surface** — not in a definition, an API response, a URL, a message, a status, a log line, a trap or an exception, because OcuPilot renders the instance's own error and message logs and the agent reads them. Per-provider key-shape checks catch paste errors before a call; an OpenAI-compatible definition has no shape gate.
- **Provider selection should resolve through a registry, not a branch chain.** The harvested original dispatches on a four-way conditional; here a family is a registry entry, consistent with the "adapter plus form entry" condition.
- Changing a definition's provider, endpoint or credential disables it until Test connection passes again. Prompt-caching configuration applies to the canonical family only.
- Most of this is a rename-only port from the harvested sibling project (four providers, two adapters, retry helpers, the mock-provider seam and the split keeping live-network tests out of the unit run). It keeps its call sites but takes OcuPilot's own package, credential, environment-variable and audit names.

## UX & Interaction Patterns

- **The context chip is computed from the same configuration the request uses**, so the two cannot disagree. It names screen, namespace, row count, provider and endpoint host; the "leaves the instance" pill appears only when the host is not on a private network, so a local provider shows the host and no pill.
- **The plain-HTTP acknowledgment uses the egress treatment** — the same visual role as that pill, not an ordinary warning.
- The definition form keeps provider, model, endpoint, key and Test connection above the fold, the rest collapsed. Choosing a provider cascades its canonical defaults and suggested models, preserving a value the user customized away from the previous provider's default.
- Test connection reports the model's first words on success, and on failure a written sentence plus the provider's text. Nothing about a failure is stored — no persisted "test failed" state, no rail badge for one.
- The API key field is write-only: never pre-filled, never echoing a stored value.

## Cross-Story Dependencies

- Story 10.1's translators are consumed by both 10.2 and 10.3, so it lands first.
- Story 10.3 reuses 10.2's OpenAI request and response handling, differing in endpoint normalization, optional or absent auth, the local-address allowance and the plain-HTTP rule.
- The epic depends on the agent-configuration epic for the provider base, credential ladder, endpoint validation, Test connection and the definition form, and must not modify the agent loop, tool registry, proposal lifecycle or screens.
- Token streaming in the polish-week epic is conditional on this epic finishing, ranked behind that epic's other work, and must not put the agent write path at risk.
