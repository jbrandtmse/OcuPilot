---
title: 'Story 10.1: The message and tool-definition adapters'
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

**Problem:** Epic 3 shipped one provider base with Anthropic's message shape as canonical, but nothing translates that shape into the dialects the other three families speak, so Stories 10.2 and 10.3 have no seam to build adapters against. Separately, one provider call's worst case is unbounded, because the attempt deadline gates only when a further attempt may *start* and nothing bounds the stored per-call timeout or attempt count (DW-1104).

**Approach:** Add two translator classes under `Kernel/Provider/` — one for messages in both directions, one for tool definitions in the request direction — that carry the locked cross-vendor JSON-Schema subset verbatim, and clamp the effective timeout and attempt count at the point of use so one call's worst case is at most `Retry.ATTEMPTBUDGETSECONDS`. Nothing above `ProviderPort` changes.

## Boundaries & Constraints

**Always:**

- Anthropic's shape stays canonical. A translator is reached only from inside a family adapter that already knows its own dialect, so no translator branches on a provider name (AD-42; the catalog row's `adapterClass` is the dispatch).
- The locked subset is kept verbatim — top level `{type:"object", properties, required, additionalProperties:false}`; per property `{type, description, enum?, items?, minimum?, maximum?, minItems?, maxItems?}`; never `$ref`/`oneOf`/`anyOf`/`allOf`/`pattern` (`harvest/iris-session-agent.md:87`). Already emitted by `Screen/Tool/Registry.cls` `EMITTEDTOPKEYWORDS`/`EMITTEDKEYWORDS`; this story pins those two lists against the rule and forbids either translator from widening or narrowing them.
- The response direction produces **canonical** blocks. `Kernel/Agent/Loop.cls:407-412` pushes a reply's tool-use blocks back into the canonical history verbatim and reads `name`/`input` off them, so a family's reply must arrive as canonical `tool_use` `{type,id,name,input}` with `input` an object.
- Never-throw is unchanged. A translation that cannot be completed returns an error `%Status`; `Base.Attempts` turns that into a `PROVIDER.*` fault and `Base.Invoke` still returns `$$$OK` on every path (AD-12, AD-39, AD-42).
- No credential and no vendor raw text passes through a translator. Neither class reads `ApiKey`, and a vendor message reaches a consumer only as `detail.providerText` (AD-35, AD-39, AD-48).
- After the clamp, one call's worst case is `(attempts x timeout) + RETRYBUDGETSECONDS <= ATTEMPTBUDGETSECONDS`, and the shipped defaults (90 s x 3 + 30 = 300) are unchanged.

**Never:**

- No file under `Kernel/Agent/`, `Kernel/Proposal/`, `Screen/`, `Api/`, `Install/`, `module.xml` or `ui/` is added or changed by this story. `Screen/Tool/Registry.cls` and `Kernel/Agent/Limits.cls` are read-only evidence here.
- No shipped catalog row is added. The families arrive in 10.2 and 10.3; a probe row in `Test/CatalogProbe.cls` is what drives a second adapter class in this story (`Test/AgentRules.cls:119` pins the shipped key set to `anthropic` alone).
- No clamp is written into `Kernel/State/Egress.cls` — that file is Epic 5's footprint, and the bound belongs where the call's worst case is computed anyway, so a caller-supplied settings array is bounded too.
- No second tool-name mapping. `Registry.WireName` (`Screen/Tool/Registry.cls:195`) is the one dot-to-underscore transform; a family whose grammar is narrower is refused by the registry's build-time check, never by a per-family rewrite.
- No live network. Every check in this story runs through the transport seam.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Canonical family is a passthrough | A canonical message and tool array, provider `anthropic` | No translator is called; the outbound body is unchanged from today's | No error expected |
| Canonical to OpenAI messages | System prompt, history, an assistant `tool_use` echo, a user `tool_result` | A `messages[]` array: a leading `role:"system"` message, `assistant.tool_calls[]` carrying `id`, `type:"function"`, `function.name`, `function.arguments` as JSON **text**, and one `role:"tool"` message per result carrying `tool_call_id` | A `tool_result` whose `tool_use_id` has no preceding `tool_use` is an error `%Status`; no call is made |
| OpenAI reply to canonical | `choices[0].message` with text and `tool_calls[]`, plus `finish_reason` and `usage` | `Response.Text`, `ToolCallsJson` as canonical `tool_use` blocks with `input` parsed into an object, `StopReason` mapped into the canonical vocabulary, `RequestTokens`/`ResponseTokens` from `usage.prompt_tokens`/`usage.completion_tokens` | `function.arguments` that will not parse, and a body with no `choices` array, are each an error `%Status` — never a silent empty reply (the DW-336 rule) |
| Canonical to Gemini messages | The same canonical input | A `contents[]` array with roles `user`/`model`, the system prompt in `systemInstruction.parts[].text`, `functionCall` parts, and `functionResponse` parts correlated **by name** in call order, because Gemini carries no call id | A `tool_result` with no matching preceding `tool_use` is an error `%Status`; two calls to the same tool in one reply stay correlated by call order |
| Gemini reply to canonical | `candidates[0].content.parts[]` carrying `functionCall` `{name, args}` | Canonical `tool_use` blocks with an adapter-synthesized `id` that the next request resolves back to the same function name; `StopReason` from `finishReason`; tokens from `usageMetadata.promptTokenCount`/`candidatesTokenCount` | A body with no `candidates` array is an error `%Status`, not an empty reply |
| Tool definitions to OpenAI | A canonical `{name, description, inputSchema}` array | `tools[].type:"function"` with `function.{name, description, parameters}`; the emitted subset reaches `parameters` unchanged, `additionalProperties:false` included | A schema that will not parse advertises that tool with no properties, as the Anthropic adapter already does (`Anthropic.cls:183`) — it never fails the call |
| Tool definitions to Gemini | The same array | `tools[0].functionDeclarations[]`; `parameters` type values in Gemini's own vocabulary; `additionalProperties` dropped because Gemini's schema refuses it | Dropping it removes only the provider-side hint: `Registry.ValidateArguments` still refuses an undeclared argument on the instance, so AD-11's closed vocabulary survives |
| A stored timeout above the budget | `State.Egress.TimeoutSeconds` 3600, `MaxAttempts` 3 | The effective timeout and attempt count are clamped so `(attempts x timeout) + RETRYBUDGETSECONDS <= ATTEMPTBUDGETSECONDS`; at least one attempt is always made; the clamp is logged once | Never a refusal — the call proceeds with the clamped values |
| The shipped defaults | No `Egress` row, or 90 / 3 | Unchanged: three attempts of 90 s, worst case exactly `ATTEMPTBUDGETSECONDS` | No error expected |

</intent-contract>

## Code Map

Anchors verified against the working tree in this worktree on 2026-09-18.

**New files.**

- `src/OcuPilot/Kernel/Provider/MessageAdapter.cls` -- canonical to and from each non-canonical dialect. Four class methods, no state, no provider-name branch: `CanonicalToOpenAi` / `OpenAiToCanonical` / `CanonicalToGemini` / `GeminiToCanonical`. The compatible family reuses the OpenAI pair (10.3).
- `src/OcuPilot/Kernel/Provider/ToolDefAdapter.cls` -- canonical tool array to each family's declaration shape, request direction only. `ToOpenAi` / `ToGemini`, plus the schema rewrite Gemini needs.
- `src/OcuPilot/Test/Adapter.cls` -- the pinning tests for both translators: the subset pin, both round trips, the correlation rules, the clamp arithmetic's boundary cases. Non-destructive, so it runs on the dev instance.
- `src/OcuPilot/Test/AdapterProvider.cls` -- the Integration AC's consumer. Extends `OcuPilot.Test.ProviderStub` (`src/OcuPilot/Test/ProviderStub.cls:22`) so it inherits the recording transport seam (`:227`) and the queued-answer script (`:55`), and overrides `CallMessages` / `MapResponse` to route through the two translators for a dialect a switch names.

**Changed files.**

- `src/OcuPilot/Kernel/Provider/Retry.cls` -- add the clamp arithmetic beside the backoff it belongs with. `ATTEMPTBUDGETSECONDS = 300` at `:66`, `RETRYBUDGETSECONDS = 30` at `:51`; the work budget is their difference, computed rather than spelled a third time. **Correct the doc at `:56-65` at its origin** -- it currently states the unbounded worst case DW-1104 reports.
- `src/OcuPilot/Kernel/Provider/Base.cls` -- apply the clamp: `tMaxAttempts` at `:214-215` and `NewRequest`'s timeout at `:316`. Log once when a stored value was clamped, the way `:223` logs an informational line. **Correct the doc at `:202-210`**, which states the same superseded claim.
- `src/OcuPilot/Test/ProviderRetry.cls` -- the existing ceiling pin is `TestTheTurnSideAndProviderSideCeilingsAgree` at `:378`, whose third assertion (`:386`) only checks that the *defaults* fit. Add the worst-case bound over stored values, and correct the doc at `:340-360`.
- `src/OcuPilot/Test/CatalogProbe.cls:20` -- add the probe rows whose `adapterClass` is `OcuPilot.Test.AdapterProvider`. This is the file that already holds five such rows; never the shipped table.

**Read before writing -- the contract these classes have to satisfy.** Nothing in this list is edited by this story except the two doc paragraphs named under *Changed* above.

- `src/OcuPilot/Kernel/Provider/Base.cls` -- the seam contract at `:24-30`, the `pMessages`/`pTools` subscript contract at `:106-109`, and the never-throw promise at `:129-193`. Read these; the only lines this story changes in the file are `:202-210`, `:214-215` and `:316`.
- `src/OcuPilot/Kernel/Provider/Anthropic.cls` -- the canonical passthrough. Request body `:44-92`, `blocks` handling `:57-66`, reply reading `:121-159`, `SchemaOf`'s parse-failure rule `:183`.
- `src/OcuPilot/Kernel/Agent/Loop.cls` -- the only builder of the canonical message array. `("role")`/`("content")` at `:144-145`, `("blocks")` at `:162-163`, the assistant echo at `:411-412`, tool results at `:532-533`, block shapes `tool_use` `:157-160` and `tool_result` `:166-168` / `:452-457`.
- `src/OcuPilot/Screen/Tool/Registry.cls` -- the only builder of the canonical tool array: `ProviderTools` `:228`, subscripts written `:272-274`. `EMITTEDTOPKEYWORDS` `:57`, `EMITTEDKEYWORDS` `:62`, `EmitSchema` `:292`, `EmitProperty` `:334`, `WireName` `:195`, `WIRENAMEPATTERN` `:65`, `ValidateArguments` `:490`.
- `src/OcuPilot/Port/ProviderPort.cls` -- `Dispatch` resolves the row and the adapter at `:222-233`, mutates the settings array at `:275-295`, and hands off at `:305`.
- `src/OcuPilot/Kernel/State/Egress.cls` -- `Resolve` `:68`, `DEFAULTTIMEOUT = 90` `:22`, `DEFAULTMAXATTEMPTS = 3` `:27`, the two unbounded properties `:47` and `:52`. **Epic 5's footprint: read, never write.**
- `src/OcuPilot/Kernel/Agent/Limits.cls:91-101` -- carries the same superseded worst-case sentence. **Epic 5's footprint**; see Design Notes.
- `src/OcuPilot/Api/Error.cls` -- the ten `PROVIDER.*` codes at `:201-261`. No new code is needed: a translation failure is `PROVIDER.TRANSPORT`, which is what `Base.Attempts:266` already answers for a body the adapter could not read.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Kernel/Provider/ToolDefAdapter.cls` -- new. Translate the canonical tool array into each family's declaration shape, carrying the locked subset through unchanged for OpenAI and rewriting only what Gemini's schema grammar refuses. First: confirm each family's declaration shape, schema-type vocabulary and function-name grammar against the vendor's published API reference and cite it in the class doc comment; do not carry a shape from this spec unverified. Rationale: this is the class that makes one tool array serve four families.
- `src/OcuPilot/Kernel/Provider/MessageAdapter.cls` -- new. Translate the canonical message array into each dialect and each dialect's reply back into canonical blocks, with the same citation discipline. Correlation is by the nearest preceding `tool_use` block for a `tool_result`, which is unambiguous even when ids repeat across iterations. Rationale: the loop only ever holds canonical history, so both directions have to close.
- `src/OcuPilot/Kernel/Provider/Retry.cls` -- add the two clamp methods (effective timeout, then effective attempts from it, never fewer than one) and correct the superseded worst-case paragraph. Rationale: pure arithmetic belongs where it can be driven directly over its whole range, which is why this class exists.
- `src/OcuPilot/Kernel/Provider/Base.cls` -- read the attempt count and the request timeout through the clamp, log once when either was lowered, and correct the superseded paragraph. Rationale: the point of use is the one place that bounds a stored value and a caller-supplied one alike.
- `src/OcuPilot/Test/AdapterProvider.cls` -- new fixture: a family adapter that exists only as a probe catalog row plus this class, proving the "one row plus one adapter" condition without a shipped row.
- `src/OcuPilot/Test/CatalogProbe.cls` -- add the probe rows for that fixture.
- `src/OcuPilot/Test/Adapter.cls` -- new. Unit-test every I/O matrix row above, including each error column.
- `src/OcuPilot/Test/ProviderRetry.cls` -- extend the ceiling pin with the worst-case bound over stored values, and correct its doc.

**Acceptance Criteria:**

- **AC1** -- Given the locked cross-vendor JSON-Schema subset rule, when a tool schema is emitted and then translated, then the rule is kept verbatim: `Registry.EMITTEDTOPKEYWORDS` and `EMITTEDKEYWORDS` equal the rule's literal lists, no translator's output introduces a keyword outside them, and the only keyword any family may lose is one its own grammar refuses, with the loss named in the class doc comment.
- **AC2** -- Given a family that exists only as a probe catalog row plus one adapter class, when a caller drives `ProviderPort.Invoke` through it, then the call completes and the recorded outbound body is that family's shape -- with no file under `Kernel/Agent/`, `Kernel/Proposal/`, `Screen/`, `Api/`, `Install/` or `ui/` added or changed. (Integration AC, Rule 1.)
- **AC3** -- Given any stored `State.Egress.TimeoutSeconds` and `MaxAttempts` above zero, when one provider call is made, then `(effective attempts x effective timeout) + RETRYBUDGETSECONDS` is at most `ATTEMPTBUDGETSECONDS`, at least one attempt is always made, and the shipped defaults produce exactly the three 90-second attempts they produce today. (DW-1104.)
- **AC4** -- Given a translation that cannot be completed -- an unmatched tool result, an unparseable arguments string, a reply body missing its own content array -- when it is met, then `Base.Invoke` still returns `$$$OK`, the response's stop reason is `error`, the fault carries a `PROVIDER.*` code, and no vendor raw text or credential material appears on any surface OcuPilot renders.
- **AC5** -- Given a canonical (Anthropic) definition, when a call is made after this story, then neither translator is reached and the outbound body is byte-identical to the one the same inputs produced before it.

## Spec Change Log

## Review Triage Log

## Design Notes

**Consumes:** Story 3.2 (the provider base, the `adapterClass` catalog column, the never-throw template, the `ProviderStub` transport seam); Story 4.2 (`Screen/Tool/Registry.cls`'s emitted schema subset and `WireName`); Story 4.8 (`Retry`'s budgets and the attempt deadline this story turns into a real bound).

**Consumed-by:** Story 10.2 (the OpenAI and Google Gemini adapters -- each calls the dialect pair for its own family from `CallMessages` and `MapResponse`); Story 10.3 (the OpenAI-compatible adapter, which reuses the OpenAI pair unchanged and differs only in endpoint normalization, optional or absent auth, the local-address allowance and the plain-HTTP rule).

**Governing ADs.** AD-42 (one base, four adapters, Anthropic canonical, bounded timeout, retry only on a retryable status, never after a mid-flight throw); AD-39 and AD-12 (one envelope, a stable machine code, vendor text normalized at the boundary); AD-11 (the model is assumed compromised; the closed argument vocabulary is what keeps a tool call bounded, which is why Gemini losing `additionalProperties` costs nothing -- the instance validates arguments regardless); AD-31 and AD-41 (a turn is bounded, and one provider call is the step whose bound was missing); AD-35 and AD-48 (no credential in a status, a log line or a trap); AD-32 (the TLS configuration and proxy are stored settings, never a parameter of these classes); AD-24 (the canonical history is already capped before a translator sees it, so neither translator caps anything).

**Why the clamp is at the point of use.** `State.Egress.TimeoutSeconds` and `MaxAttempts` are both unbounded `%Integer`s, and `ProviderPort.Dispatch` also lowers `maxAttempts` itself for Test connection (`ProviderPort.cls:283-285`). Clamping in `Base` bounds the stored pair, the port's own lowering and a test's array with one rule, and it leaves `Kernel/State/Egress.cls` -- Epic 5's footprint -- untouched. Clamping only ever lowers, so it composes with the port's lowering rather than fighting it.

**Two dependencies on paths this story does not own.**

1. `src/OcuPilot/Kernel/Agent/Limits.cls:91-101` states "one call's true worst case is this plus the stored `TimeoutSeconds`", which this story makes false. The file is Epic 5's footprint, so the sentence is **not** edited here. It is a one-line correction at its origin and is flagged to the lead rather than worked around.
2. AD-42's Rule says "every provider call carries a bounded timeout" without naming the bound. The invariant this story establishes -- one call's worst case is at most `ATTEMPTBUDGETSECONDS` -- is a numeric invariant later stories will assume, so it belongs in the spine under Rule 20. This stage cannot amend a planning artifact; the amendment is the lead's, in its bookkeeping commit.

**Ledger inbox.** `DW-1104` is addressed by AC3, the last two I/O matrix rows, and the two `Retry`/`Base` tasks. The owner decided the direction at the merge gate -- bound one call's worst case -- so the product question is not reopened here.

**Correlation, and the one place the families genuinely differ.** OpenAI carries a call id (`tool_calls[].id`, echoed as `tool_call_id`), so the canonical id passes through in both directions. Gemini carries no id at all: a `functionResponse` correlates by `name`, and by order when a reply called the same function twice. So the Gemini pair is the asymmetric one -- the reply direction synthesizes a canonical id, and the request direction resolves a `tool_result`'s id back to a name by nearest preceding `tool_use`. The exact id literal is the implementer's; what the tests pin is that the round trip closes and that an unmatched id is an error rather than a dropped result.

## Verification

**Slot and instance.** This epic's slot is **B**. Every IRIS MCP call in this story carries `server: "ocupilot-slot-b"` on **every** call -- the profile `ocupilot-iris` does not exist and an omitted `server` silently reaches an unrelated container. The dev instance is `ocupilot-slot-b` (web 52775, superserver 1974). No check in this story mutates instance-level state -- no security object, web application, credential, scheduled task, database or namespace -- so all of it runs against the dev instance. Should a later stage need a throwaway, it is `bash scripts/ci-throwaway.sh --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci --web 52777 --super 1976` (container `ocupilot-b-ci`), and a browser run exports both `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci`. This story adds no client code and no browser spec.

**Commands:**

- `uv run scripts/check-objectscript.py` -- expected: clean. The rules that bite here are `check_naming`, `check_package_placement`, `check_rename_tokens` (no `SessionAgent`/`MessageAdapter`-era package token), `check_non_ascii_literals` and `check_test_class_properties`.
- `uv run scripts/test_check_objectscript.py` -- expected: clean.
- Compile each new and changed class through the IRIS MCP tools with `server: "ocupilot-slot-b"`, `namespace: "HSCUSTOM"` -- expected: no errors. Read the error text; a clean local file is not evidence.
- `bash scripts/lint-docs.sh` -- expected: clean (this spec is the only Markdown this story touches).
- From `ui/`: `npm test` -- expected: unchanged and green. This story adds no client code; the run is the regression check that it did not.
- `node ui/tools/ci-runner.mjs --container ocupilot-slot-b --class <one class>` -- **one class per invocation, one invocation per message**, and never a re-submit on a client-side timeout. Order: `OcuPilot.Test.Adapter`, then `OcuPilot.Test.ProviderRetry`, then the regression set `OcuPilot.Test.Provider`, `OcuPilot.Test.ProviderPort`, `OcuPilot.Test.ProviderConsumer`, `OcuPilot.Test.ProviderSecret`, `OcuPilot.Test.AgentRules`. Confirm the totals with the `%UnitTest_Result` SQL probe in `.claude/rules/objectscript-testing.md` before reporting a suite green; the runner envelope truncates.
- `git diff --name-only 84a5fdcf327cf56afabeb8871b5a9ee0dcc6cf79..HEAD -- src ui module.xml` -- expected: only the eight paths the Code Map names. This is AC2's second half.

**Pinning tests and their mutations** (Rule 19 -- one demonstrated mutation per AC; a mutation is applied to the instance's copy of `src/`, the whole tree is recompiled, red is observed, the mutation is reverted, and `git status --short` plus `git diff --stat` are confirmed unchanged):

- **AC1** -- pinned by `OcuPilot.Test.Adapter`'s subset test. `mutation:` add `pattern` to `Screen/Tool/Registry.cls` `EMITTEDKEYWORDS` -> the subset pin goes red.
- **AC2** -- pinned by `OcuPilot.Test.Adapter`'s probe-family test driving `ProviderPort.Invoke`. `mutation:` point the probe row's `adapterClass` at `OcuPilot.Kernel.Provider.Anthropic` -> the recorded outbound body is the canonical shape and the assertion on the target family's field names goes red.
- **AC3** -- pinned by `OcuPilot.Test.ProviderRetry`'s worst-case test. `mutation:` make the clamp method in `Kernel/Provider/Retry.cls` return its argument unchanged -> the bound over a stored 3600-second timeout goes red.
- **AC4** -- pinned by `OcuPilot.Test.Adapter`'s translation-failure tests. `mutation:` in `MessageAdapter`, raise instead of returning an error `%Status` on an unmatched `tool_use_id` -> the `$$$OK`-on-every-path assertion goes red.
- **AC5** -- pinned by `OcuPilot.Test.Provider`'s existing Anthropic body assertions plus a new byte-identity test in `OcuPilot.Test.Adapter`. `mutation:` route the Anthropic adapter's `CallMessages` through `MessageAdapter.CanonicalToOpenAi` -> the canonical-passthrough test goes red.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
