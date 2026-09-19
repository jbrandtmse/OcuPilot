---
title: 'Story 10.2: The OpenAI and Google Gemini adapters'
type: 'feature'
created: '2026-09-18'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/.claude/rules/objectscript-basics.md'
  - '{project-root}/.claude/rules/objectscript-testing.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** OcuPilot runs on one provider family. Story 10.1 shipped the message and
tool-definition translators, but no shipped catalog row and no adapter class reaches them, so an
operator who already pays OpenAI or Google must open a new vendor relationship to adopt OcuPilot.

**Approach:** Two catalog rows and two `Base` subclasses — the "one row plus one adapter" claim
made real. The shared template, retry, credential ladder, egress policy and translators are used
unchanged; only what each vendor's published reference forces is added: a request-URL seam for
Gemini's model-in-path, the Gemini call-id echo (DW-1180), and key-shape gates that assert no
prefix the vendor does not publish.

## Boundaries & Constraints

**Always:** the catalog row's `adapterClass` is the only dispatch — no shipped class branches on a
provider key. `anthropic` stays the **first** row and the column set stays at fourteen (twelve
projected): `Test/AgentViolation.cls:212-213` pins both and is Epic 5's file. Every failure exits
through the base's never-throw template as a `PROVIDER.*` code with vendor text only in
`detail.providerText` (AD-12, AD-39); the credential is read straight onto a header and never into
a local, a URL, a status or a log line (AD-35, AD-48). Retry, backoff, timeout and the clamp are
the shared ones (AD-42) — a call that threw mid-flight is never retried. The URL actually called
carries the same scheme and authority the port judged (AD-42). Tool names travel as the wire names
`Registry.WireName` already produced, with no second transform (Conventions › Tool naming).

**Never:** no live provider call in any verification — there is no key and no egress budget, and
the transport seam is a stub subclass. No new catalog column, no change to `Api/**`, `ui/**`, the
agent loop, the tool registry, the proposal lifecycle or any screen (epic acceptance condition).
No per-adapter retry, no stored key, no empty auth header. Not Story 10.3's work: no
OpenAI-compatible row, no local or plain-HTTP allowance — `allowsLocal` is false on both rows.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| OpenAI turn | stored definition on the shipped `openai` row, messages + tools | `POST` to the row's endpoint; `Authorization` header set; body `{model, max_completion_tokens, temperature, messages, tools}` from the translators; reply mapped to canonical blocks | body unreadable → `PROVIDER.TRANSPORT`, no partial reply |
| Gemini turn | same on the shipped `gemini` row | `POST` to the row's endpoint with `{model}` replaced by the definition's model; `x-goog-api-key` header; body `{contents, systemInstruction?, tools?, generationConfig{maxOutputTokens, temperature}}`; reply mapped | as above |
| Gemini model unusable in a path | model outside `^[A-Za-z0-9._-]+$`, or a substitution that would change scheme or authority | refused `PROVIDER.EGRESS` before any socket | no call made |
| Retryable status | 429 with `Retry-After`, then 200 | one retry at the shared delay, then the reply | attempts exhausted → `PROVIDER.UNAVAILABLE` |
| Mid-flight raise | transport raises on attempt 1 | no second attempt (AD-42) | `PROVIDER.TRANSPORT` |
| Vendor error body | 400 carrying `error.message` (both families) | `PROVIDER.REFUSED` with that message in `detail.providerText` | raw body to the log alone |
| Gemini call id (DW-1180) | reply whose `functionCall` carries `id` | canonical block keeps that id; the next request's `functionResponse` echoes it; a synthesized id is not echoed | unmatched result still refused as in 10.1 |
| Key shape | key empty, or carrying whitespace | `PROVIDER.KEYSHAPE` before any socket; neither row declares a prefix | reason names no key material |

</intent-contract>

## Code Map

- `src/OcuPilot/Kernel/Provider/Catalog.cls` — `XData Providers:52` holds the one shipped row; the
  new rows append after it. Header prose at `:9-15` ("Release 1 ships exactly one row") is
  superseded and replaced at its origin. `XData ArmedProviders:66` is not a shipped row.
- `src/OcuPilot/Kernel/Provider/Anthropic.cls` — the reference implementation of the six-method
  family contract; the new adapters mirror its structure, not its wire shape.
- `src/OcuPilot/Kernel/Provider/Base.cls` — `Attempts:219` reads the URL at `:221`;
  `NewRequest:313`; `IsApiKeyShapeValid:456`. The `RequestUrl` seam and the key-shape helper go
  here.
- `src/OcuPilot/Kernel/Provider/MessageAdapter.cls` — `CanonicalToGemini:263` writes
  `functionResponse` at `:312-316`; `GeminiToCanonical:347` synthesizes the id at `:379`;
  `GEMINISTOPREASONS:61`. `ToolDefAdapter.cls` `ToOpenAi:58` / `ToGemini:85` pass names through.
- `src/OcuPilot/Port/ProviderPort.cls:220` — `Dispatch` resolves the row, judges endpoint and
  proxy, and constructs `adapterClass` at `:298`. Read-only here.
- `src/OcuPilot/Kernel/AgentRules.cls:284-315` — `SchemeAccepted` / `IsAbsoluteHttps`: verified
  that a `{model}` placeholder in the path is accepted and that `Egress.HostOf:80` returns the
  authority unaffected by it.
- `src/OcuPilot/Test/ProviderStub.cls:227-281` — the scripted, recording transport, today an
  instance method on an `Anthropic` subclass; `Test/CatalogAnthropicStub.cls` is the pattern for
  re-adapting a shipped row to a stub, and `Test/ProviderPortProbe.SetCatalogClass` switches the
  catalog in.
- `src/OcuPilot/Test/AgentRules.cls:116,119,343` — the key-set pin and the two uses of `openai` as
  the *unknown* provider; `:122-146` pins the shipped row column by column.
- `src/OcuPilot/Test/AgentWire.cls:79` — the same `openai` stand-in over the wire. **Epic 5's
  file; see Design Notes.**

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Kernel/Provider/Base.cls` — **first**, because both adapters build on it: add
  `RequestUrl(ByRef pValues)` defaulting to the judged endpoint, read it in `Attempts`, and refuse
  `PROVIDER.EGRESS` without a socket when the result is empty or its scheme or authority differs
  from the judged endpoint's; add one concrete key-shape helper (prefix when the row declares one,
  otherwise non-empty and whitespace-free) that reads `ApiKey` inside the expression.
- `src/OcuPilot/Kernel/Provider/OpenAI.cls` — new `Base` subclass: Chat Completions body,
  `Authorization: Bearer` header written straight from `ApiKey`, `MessageAdapter` +
  `ToolDefAdapter` in both directions, `error.message` for `ProviderMessage`.
- `src/OcuPilot/Kernel/Provider/Gemini.cls` — new `Base` subclass: `generateContent` body,
  `x-goog-api-key` header, the same two translators, `error.message`, and the `RequestUrl`
  override that substitutes the validated model for `{model}`.
- `src/OcuPilot/Kernel/Provider/Catalog.cls` — append the `openai` and `gemini` rows **after**
  `anthropic`, with the model, endpoint, credential and key-shape values Design Notes fixes;
  replace the superseded one-row prose. No new column.
- `src/OcuPilot/Kernel/Provider/MessageAdapter.cls` — **DW-1180**: keep a vendor
  `functionCall.id` where the reply carries one, synthesize only where it does not, and echo a
  vendor id on the matching `functionResponse`; add `MALFORMED_FUNCTION_CALL`,
  `UNEXPECTED_TOOL_CALL` and `TOO_MANY_TOOL_CALLS` to `GEMINISTOPREASONS` as `refusal`; correct
  the class doc's Gemini correlation paragraph at its origin.
- `src/OcuPilot/Test/ProviderStub.cls` — lift the scripted-transport body into a class method
  taking the identity, leaving the existing instance method and every recorded key unchanged.
- `src/OcuPilot/Test/OpenAIStub.cls`, `src/OcuPilot/Test/GeminiStub.cls` — new stubs extending
  the two shipped adapters, delegating transport, `Wait` and `NowSeconds` to that class method.
- `src/OcuPilot/Test/CatalogProbeShipped.cls` — `CatalogProbe` subclass that re-adapts the two
  shipped rows to those stubs and changes no other column.
- `src/OcuPilot/Test/OpenAIAdapter.cls`, `src/OcuPilot/Test/GeminiAdapter.cls` — the matrix rows,
  each driven through `ProviderPort.Invoke` on the shipped row.
- `src/OcuPilot/Test/Adapter.cls` — the Gemini id round trip and the added stop reasons.
- `src/OcuPilot/Test/AgentRules.cls` — key-set pin becomes `anthropic,openai,gemini`; both
  unknown-provider stand-ins become a key the catalog does not declare; pin each new row column
  by column as `:122-146` pins the first.

**Acceptance Criteria:**

- **AC1 (Integration).** Given a stored definition on the shipped `openai` row, when
  `ProviderPort.Invoke` runs a turn-shaped call with messages and tools, then the request recorded
  at the transport seam is a POST to that row's endpoint carrying the `Authorization` header and a
  Chat Completions body built from the row's own `defaultModel`, `canonicalMaxTokens` and
  `canonicalTemperature`, and the reply becomes canonical text and `tool_use` blocks.
- **AC2 (Integration).** The same for the shipped `gemini` row: the recorded URL is the row's
  endpoint with the definition's model substituted, the header is `x-goog-api-key`, the body is
  `contents` / `systemInstruction` / `tools` / `generationConfig`, and the reply becomes canonical.
- **AC3.** Given a Gemini definition whose model would not survive substitution, when the call is
  made, then it is refused `PROVIDER.EGRESS` with no socket opened and no credential in the reason.
- **AC4.** Given each new family, when the provider answers a retryable status, raises mid-flight,
  or refuses with an error body, then the shared retry, the no-retry-after-a-raise rule and the
  `detail.providerText` mapping behave exactly as they do for the canonical family, and `Invoke`
  still answers `$$$OK`.
- **AC5.** Given the shipped catalog, when it is read, then it declares `anthropic`, `openai` and
  `gemini` in that order with the same fourteen columns, each new row naming its own adapter class,
  and default models and suggestions are row values that no code spells.
- **AC6.** Given a Gemini reply whose `functionCall` carries an `id`, when the next request is
  built, then its `functionResponse` echoes that id; a call the provider sent without one is
  answered by name as before (DW-1180).
- **AC7.** Given every canonical tool the registry advertises, when its wire name is emitted, then
  it matches `^[A-Za-z0-9_-]{1,64}$` — the intersection of both vendors' published name grammars.

## Design Notes

**Governing ADs.** AD-42 (four adapters, the endpoint allow-list, shared retry and the mid-flight
rule, the credential ladder), AD-32 (named SSL configuration — unchanged, the port supplies it),
AD-35 and AD-48 (no credential in an exception, status, log line or trap), AD-12 and AD-39 (one
envelope, vendor text normalized at the port), AD-21 (a value is validated to a shape and never
concatenated blind — why the model is gated before it enters a URL path), AD-11 with Conventions ›
Tool naming (dots became underscores once, at the registry), AD-31 and AD-41 (the call stays inside
the turn's bounds), AD-8 and AD-9 (the adapter runs unescalated, in the caller's process).

**Consumes:** Story 10.1 (`MessageAdapter`, `ToolDefAdapter`, the `Retry` clamp), Epic 3
(`ProviderPort`, `Catalog`, `Egress`, the credential ladder, the definition form).
**Consumed-by:** Story 10.3 (reuses the OpenAI request and response handling and the `RequestUrl`
seam for endpoint normalization), Epic 11's streaming, Epic 14's per-user restraints.

**Where the vendors' current references overrule the harvest map** (checked 2026-09-18 against
each vendor's published reference; the harvest map is `harvest/iris-session-agent.md` §1):

- **No prefix gate on either row.** The harvest map gates `sk-` and `AIzaSy`. OpenAI's
  authentication reference publishes no key grammar and names workload-identity access tokens as
  valid bearer credentials; Google's API-key page states that since 2026-05-28 AI Studio issues
  service-account-bound *auth* keys rather than the older standard keys. A prefix gate would
  therefore refuse currently-issued credentials. Both rows set `keyPrefix` empty and the adapters
  gate on empty-or-whitespace instead, which is the paste error the gate exists to catch.
- **`max_completion_tokens`, not `max_tokens`** — OpenAI's schema marks `max_tokens` deprecated
  and incompatible with its reasoning models.
- **Gemini's key goes in the `x-goog-api-key` header**, never the `?key=` query parameter the
  wider Google API surface still accepts: a credential in a URL is refused by AD-35.
- **Gemini's `FunctionCall` and `FunctionResponse` do carry an optional `id`** (DW-1180), and the
  function-calling guide instructs the caller to echo it; `name` remains required, so the existing
  name correlation stays as the answer for a call that carried none.

**Row values.** `openai`: label `OpenAI`, endpoint `https://api.openai.com/v1/chat/completions`,
default model `gpt-5.6-terra` with `gpt-5.6-sol` and `gpt-5.6-luna` beside it, `OPENAI_API_KEY` /
`OcuPilotOpenAI`. `gemini`: label `Google Gemini`, endpoint
`https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent`, default model
`gemini-3.8-flash` with `gemini-3.5-flash` and `gemini-2.5-pro` beside it, `GEMINI_API_KEY` /
`OcuPilotGemini`. Both take the canonical 32000 / 0 tuning and `authVersion` empty — neither family
sends a version header, and Gemini's version is the endpoint's own path segment. Model ids are
configuration and were taken from each vendor's current model page; `gpt-6-astra` is deliberately
absent because its tool calling requires the Responses API. Gemini's per-model output cap was not
confirmed for the chosen model, so 32000 is the table's canonical value an operator may lower, not
a verified ceiling.

**DW-1183** (`is_error` dropped in both request directions, `wontfix-accepted`) is **not tripped**:
its probe is a 10.2 turn showing the model retrying a failed tool as though it had succeeded, and
no verification here makes a live turn. Gemini's reference does document an `error` key convention
inside `functionResponse.response`, which is the cheapest fix if the probe ever fires. **DW-1182**
is owned by 10.3 and untouched: nothing here changes how `message.content` is read.

**The unknown-provider sentinel is `nosuchprovider`, at all three sites.**
`Test/AgentWire.cls:79`, `Test/AgentRules.cls:116` and `:343` each use a shipped provider key as
their *unknown* provider, so making `openai` shipped would cost each of them a violation. All three
move to the one sentinel; two conventions must not exist. `AgentWire.cls` is Epic 5's footprint and
the orchestrator granted this one literal there (2026-09-19) — that edit is exactly one literal and
nothing else, to keep the conflict surface minimal, and it is reported as a footprint extension.
**`CatalogProbe`'s probe key is not usable as the sentinel:** `Test/TurnStore.cls:266-271` shows it
resolves and reads `IsKnown` whenever `OCUPILOT_ALLOW_TEST_PROVIDER` is 1, so an assertion built on
it would pass or fail by environment. A guard in `Test/AgentRules.cls` asserts the catalog does not
declare the sentinel, so shipping that key one day fails loudly there rather than silently costing a
violation in a file this epic does not own.

**Append after `anthropic`; never prepend — a recorded constraint, not an accident.**
`Test/AgentViolation.cls:213` asserts `%Get(0).key` is `anthropic` and `:203` asserts a count
*relative* to `Catalog.Keys()`; `:212` pins the twelve projected column names, and `strings.ts`'s
landing copy names Anthropic because the form selects the first row. Appending two rows and adding
no column keeps all four true without touching an Epic 5 file or the client. Reordering the rows
would break `:213`, so the order is part of this story's contract.

## Verification

**Slot and instance.** This epic's slot is **B**. Every IRIS MCP call carries
`server: "ocupilot-slot-b"` (dev instance, web 52775, superserver 1974); an omitted `server`
silently reaches an unrelated container and the profile `ocupilot-iris` does not exist. **No
verification in this story may make a live provider call** — there is no key and no egress budget,
and the transport seam is `Test/ProviderStub`'s recording override, reached for the two new
families through `Test/OpenAIStub` and `Test/GeminiStub`. Anything mutating instance-level state,
and the whole-suite sweep, runs on the throwaway: `bash scripts/ci-throwaway.sh up --dir
/tmp/ocupilot-b-ci --project ocupilot-b-ci --web 52777 --super 1976` (container `ocupilot-b-ci`).

**Commands:**

- `uv run scripts/check-objectscript.py` and `uv run scripts/test_check_objectscript.py` —
  expected: clean.
- Compile every new and changed class through the IRIS MCP tools with `server: "ocupilot-slot-b"`,
  `namespace: "HSCUSTOM"` — expected: no errors; read the error text.
- `bash scripts/lint-docs.sh` — expected: clean.
- From `ui/`: `npm run build` and `npm test` — expected: unchanged and green. This story adds no
  client code; the run is the regression check that it did not.
- `node ui/tools/ci-runner.mjs --container <instance> --class <one class>` — **one class per
  invocation, one invocation per message**, never a re-submit on a client-side timeout. Order:
  `OcuPilot.Test.OpenAIAdapter`, `OcuPilot.Test.GeminiAdapter`, `OcuPilot.Test.Adapter`,
  `OcuPilot.Test.AgentRules`, then the regression set `OcuPilot.Test.Provider`,
  `OcuPilot.Test.ProviderPort`, `OcuPilot.Test.ProviderRetry`, `OcuPilot.Test.ProviderSecret`,
  `OcuPilot.Test.ProviderProxy`, `OcuPilot.Test.ProviderSsl`, `OcuPilot.Test.ProviderConsumer`.
  Confirm every total with the `%UnitTest_Result` SQL probe in
  `.claude/rules/objectscript-testing.md` before reporting a class green.
- **The whole sweep before the commit**: every `OcuPilot.Test.*` class on the throwaway, plus the
  whole `ui` suite — not a subset.
- `git diff --name-only a42aa488d5a55d8a319320a720c964d815eb5008..HEAD -- src ui module.xml` —
  expected: only the paths the Tasks list names, and nothing under `ui` or `Api`.

**Pinning tests and their mutations** (Rule 19 — one demonstrated mutation per AC; apply to the
instance's copy, recompile the whole package, observe red, revert, confirm `git status --short` and
`git diff --stat` unchanged):

- **AC1** — `OpenAIAdapter.TestAShippedOpenAiRowIsCalledInItsOwnDialect`. `mutation:` point the
  shipped `openai` row's `adapterClass` at `OcuPilot.Kernel.Provider.Anthropic` → red on the
  recorded header name and on the `messages` / `max_completion_tokens` body assertions.
- **AC2** — `GeminiAdapter.TestAShippedGeminiRowIsCalledInItsOwnDialect`. `mutation:` have
  `Gemini.RequestUrl` answer the endpoint unchanged → red on the recorded URL still carrying
  `{model}`.
- **AC3** — `GeminiAdapter.TestAModelThatWouldNotSurviveSubstitutionIsRefused`. `mutation:` drop
  the model-shape gate in `Gemini.RequestUrl` → red on the expected `PROVIDER.EGRESS` code and on
  the zero-calls assertion.
- **AC4** — `OpenAIAdapter.TestTheSharedRetryAndRefusalRulesHold` (and its Gemini twin).
  `mutation:` remove the mid-flight `Quit` in `Base.Attempts` → red on the one-attempt assertion.
- **AC5** — `OcuPilot.Test.AgentRules.TestTheShippedProviderRowsArePinned`. `mutation:` change the
  `gemini` row's `defaultModel` in the `Providers` XData → red on that row's model alone.
- **AC6** — `OcuPilot.Test.Adapter.TestAVendorGeminiCallIdSurvivesTheRoundTrip`. `mutation:` make
  `GeminiToCanonical` synthesize an id even where the reply carried one → red on the echoed
  `functionResponse.id`.
- **AC7** — `OcuPilot.Test.Adapter.TestEveryWireToolNameFitsBothVendorGrammars` over
  `Registry.ProviderTools`. `mutation:` have `Registry.WireName` leave one dot in place → red
  naming that tool.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
