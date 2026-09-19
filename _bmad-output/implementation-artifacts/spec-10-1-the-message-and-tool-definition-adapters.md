---
title: 'Story 10.1: The message and tool-definition adapters'
type: 'feature'
created: '2026-09-18'
status: 'done'
baseline_revision: 'f92e266af4790f89fc17a891e6f8b39d3e28cb24'
baseline_commit: 'f92e266af4790f89fc17a891e6f8b39d3e28cb24'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/.claude/rules/objectscript-basics.md'
  - '{project-root}/.claude/rules/objectscript-testing.md'
warnings: ['oversized']
deferred:
  - summary: >-
      Kernel/Agent/Limits.cls:91-101 still states that one provider call's true worst case is the
      attempt deadline plus the stored TimeoutSeconds, which the clamp this story added makes false.
    evidence: |-
      The sentence is the same superseded claim this story corrected at its two other origins
      (Retry.ATTEMPTBUDGETSECONDS and Base.Attempts). The file is Epic 5's footprint, so it was
      read and not written here. Settle by replacing the one sentence; the spine's AD-42 already
      carries the amended bound.
    location: >-
      src/OcuPilot/Kernel/Agent/Limits.cls:91-101
    severity: medium
  - summary: >-
      A turn stopped at a boundary may leave a tool_use in the stored canonical history with no
      answering tool_result, which every family's request direction would then send unanswered.
    evidence: |-
      Both new request directions refuse the converse (a result with no call) and neither refuses
      this one; the canonical Anthropic path has the same exposure, so it is not introduced here.
      Settle by reading Kernel/Agent/Loop.cls's Boundary exit: whether it appends a tool_result for
      the blocks it did not dispatch before it quits the loop.
    location: >-
      src/OcuPilot/Kernel/Provider/MessageAdapter.cls:135
    severity: medium (unverified)
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

### Review Findings

Code review 2026-09-19 (full-opus, four layers). 9 root-cause entries after grouping -- high 0,
medium 6, low 3 -- from 59 raw findings (blind-hunter 31, edge-case-hunter 14, verification-gap 9,
acceptance-auditor 5). Four patched in-pass and pinned; five closed with an owner. No high, so the
story closes `done`.

**Patched in this review** (`Kernel/Provider/MessageAdapter.cls`, `Test/Adapter.cls`):

- `[med]` A JSON array satisfied the `$IsObject` test in `ArgumentsText`, `ArgumentsOf` and
  `ArgumentsObject`, so a provider's array `arguments` became a canonical `tool_use` whose `input`
  is not an object -- against the Boundaries rule and both matrix reply rows -- and a canonical
  array input traveled as `function.arguments` array text. All three now require a
  `%Library.DynamicObject`, the check `BodyOf` and `ToolDefAdapter.SchemaOf` already made.
- `[med]` A reply's tool call with no `id` (OpenAI) or no function name (either family) was stored
  as a canonical block that no later request can correlate a result with, so every subsequent
  request in that conversation would answer `PROVIDER.TRANSPORT` -- permanently. Both reply
  directions now refuse it, so one turn fails cleanly instead.
- `[med]` Two documented OpenAI request-direction branches -- `content` JSON `null` for a
  calls-only message, and the suppressed empty companion for a results-only one, which are the two
  shapes `Loop.AnswerTools` produces -- had no assertion that could fail (Rule 19).
- `[low]` `VENDORNAMEPATTERN` and `ToolDefAdapter`'s class doc called
  `Registry.WIRENAMEPATTERN` "the grammar both families publish". Verified against both vendors'
  references: it is OpenAI's exactly; Gemini additionally requires a leading letter or underscore.
  What keeps every wire name inside both is `Registry.TOOLNAMEPATTERN`, now asserted beside it.

**Closed with an owner:**

- `[med]` `DW-1179` `escalated` -- `%Net.HttpRequest.Timeout` bounds one socket read, not one
  attempt, so AD-42's amended 300 s worst case is not a wall-clock bound. The clamp arithmetic is
  total and correct; the gap is pre-existing and its fix is a spine amendment or a transport-level
  deadline, neither of which is this stage's.
- `[med]` `DW-1180` `routed owner=10-2` -- Gemini's reference does declare an optional `id` on
  `FunctionCall` and `FunctionResponse`.
- `[med]` `DW-1181` `routed owner=burndown` -- nothing consumes the canonical `refusal` stop
  reason, so a blocked reply renders as an empty turn; the consuming code is Epic 5's footprint.
- `[low]` `DW-1182` `wontfix-accepted owner=10-3` -- an OpenAI `content` parts array loses its text.
- `[low]` `DW-1183` `wontfix-accepted owner=10-2` -- `is_error` is dropped by both request
  directions.

The lead's three named checks came back: both reply directions are name-transparent and
`Registry.ResolveWire` is still the one reverse mapping; the clamp's guard is total over every
value `State.Egress` can store and `ProviderPort.Dispatch` can pass, and `Base`'s two call sites
reach the division only through `TimeoutOf`; the Gemini id synthesis is collision-safe both for one
reply calling a function twice (the ordinal differs) and across families (the map is id-to-name and
the name is in the id).

## Spec Change Log

## Review Triage Log

- Matrix Test Audit (implement, 2026-09-18): the clamp row's "logged once" cell had no pinning assertion. Patched in-pass -- `Test/AdapterProvider.cls` gains a `LogRaw` capture seam and `Logged`, and `Test/Adapter.cls` the method named on AC3's line above.

### 2026-09-18 - Review pass

- verdicts: 57 findings - high 0, medium 17, low 35, false 4, maybe-false 1
- findings:

Blind Hunter:

  - `[low]` `[patch]` `LogClamp`'s doc called its line "informational" while `Fault.LogRaw` routes it to `Audit.Log.Error` (severity 2, operator console) - the doc now states the seam and level it actually uses; the level itself is rejected below.
  - `[low]` `[reject]` The clamp line carries its two numbers in a fabricated `$$$ERROR` and logs an empty code - `pStatus` is `Fault.LogRaw`'s only detail channel and `pCode` is empty because no client response pairs with this line.
  - `[medium]` `[defer]` `Kernel/Agent/Limits.cls:91-101` still carries the worst-case sentence this story falsifies, with nothing machine-readable recording it - filed in frontmatter `deferred:`; Epic 5's footprint.
  - `[medium]` `[patch]` `GEMINISTOPREASONS` omits values the class's own cited enumeration lists - `LANGUAGE:refusal` added; `OTHER` left to the documented default; `MALFORMED_FUNCTION_CALL` not added, being unverified against the reference this class cites.
  - `[medium]` `[patch]` `StopReason` let any tool call overwrite `length` or `content_filter` - the override now fires only where the mapped reason was the default, so a truncated or filtered tool-calling reply keeps the reason a caller can act on.
  - `[low]` `[reject]` The request direction turns a non-object `input` into an empty object while the reply direction refuses one - every path that builds a canonical block yields an object (`ArgumentsObject` refuses, `ArgumentsOf` normalizes, Anthropic passes the vendor's own), and the fix guards state not shown reachable.
  - `[medium]` `[patch]` A `tool_use` with an empty id registered an empty subscript, so a result with an empty id "matched" and traveled as an empty `tool_call_id` - an id-less call is no longer registered and such a result is refused, as the class doc promises.
  - `[medium]` `[patch]` `GeminiSchema`'s "no keyword outside the emitted subset can enter" was an overclaim; an unrecognized keyword is copied through - the clause is replaced and `Registry.EmitSchema` named as the enforcer.
  - `[low]` `[patch]` `GeminiSchema` described itself as producing a copy while aliasing `enum` and `required` - stated at the method, in the same correction.
  - `[low]` `[reject]` Unknown block types are dropped silently and the two dialects differ on the resulting message - `Loop` builds only `text`, `tool_use` and `tool_result`; the fix adds a branch on state not shown reachable.
  - `[low]` `[patch]` The Gemini ordering claim rested on an unstated invariant - the class doc now names the canonical history's call order as what it depends on.
  - `[low]` `[patch]` `AdapterProvider`'s Gemini body is not Gemini's real shape (top-level `model`, no `generationConfig`) - the fixture's doc now says the body carries only the translators' output and is not to be copied as a family adapter.
  - `[low]` `[reject]` `CANONICALBODY` cannot demonstrate AC5's "before" half - the identity follows from `Anthropic.cls` being unchanged since `baseline_revision`, which `git diff` shows; the literal pins forward stability.
  - `[medium]` `[patch]` AC1's emitted-then-translated chain was never linked in one test - `Registry.ProviderTools`' own emitted schemas now go through both translators and `Outside()` asserts no keyword outside the subset at any depth.
  - `[medium]` `[patch]` AC1's mutation exercised only the literal comparison - a second mutation over the live chain was named, applied, observed red and reverted; AC1's `## Verification` line records it.
  - `[low]` `[reject]` `EffectiveAttempts`' `tAllowed` floor is unreachable given the timeout clamp - it is a documented boundary of a pure arithmetic method driven directly over its range; deleting it would leave a future caller dividing by zero.
  - `[low]` `[reject]` The story changes what the attempt deadline is for without saying so - the rewritten `ATTEMPTBUDGETSECONDS` paragraph states both roles, the between-attempts deadline and the clamp ceiling, at its origin.
  - `[low]` `[reject]` `LogClamp` re-implements the "never fewer than one" floor - that copy is what suppresses a phantom "clamped" line for a stored count of 0, so removing it is a behavior change rather than a deletion.
  - `[medium]` `[reject]` The run result reported 12 methods and 12 of 12 for a 13-method class - the fix is to edit this build's spec; finalize records 13 of 13 and the post-patch run indices.
  - `[low]` `[reject]` `Test/Adapter.cls` is 659 lines against the ~500-line guidance - a split is well beyond a two-way door and the class is cohesive by subject; reopen_if it passes 800 lines or a method's subject leaves the class header.
  - `[false]` `[reject]` `Test/Adapter.cls`'s header overclaims its footprint - the spec's own Verification defines instance-level state as security objects, web applications, credentials, tasks, databases and namespaces; an OcuPilot state row and a console line are none of those.
  - `[low]` `[reject]` `Test/ProviderPortProbe.cls:4`'s adapter count is now stale - that file is outside this story's footprint (Epic 5 owns it); reopen_if a fourth stub adapter is added.
  - `[low]` `[patch]` No test pinned the function-name grammar both new class docs assert - `Registry.WIRENAMEPATTERN` is now asserted equal to the grammar they cite.
  - `[low]` `[reject]` `ToolDefAdapter`'s `%Status` returns are unreachable and `SchemaOf` is public with no outside caller - the `%Status` is the seam 10.2 and 10.3 call through and narrowing it would change their contract; `SchemaOf` mirrors `Anthropic.SchemaOf` deliberately.
  - `[false]` `[reject]` AC2's recorded `git diff` command does not produce the recorded result - it is evaluated against the finalize commit; both the working-tree and committed forms return exactly the eight Code Map paths.

Edge Case Hunter:

  - `[low]` `[reject]` `BlocksOf` swallows an unparseable blocks JSON and the message's calls vanish - the canonical adapter parses blocks the same way and falls back identically, so this is not introduced here.
  - `[low]` `[reject]` A blocks array yielding nothing sends OpenAI an empty message where Gemini sends none - same root cause as the dropped-block-type row above.
  - `[medium]` `[patch]` A first choice carrying no `message` answered `$$$OK` with empty text, against the matrix's own DW-336 rule - a guard now refuses it, with a test leg.
  - `[low]` `[reject]` A canonical role absent or outside OpenAI's four - `Loop` writes only `user` and `assistant`; the fix adds a mapping on state not shown reachable.
  - `[medium]` `[patch]` An empty `tool_use_id` passes the existence test - grouped with the empty-id row above and fixed with it.
  - `[maybe-false]` `[defer]` A `tool_use` left unanswered in stored history would be sent unanswered - if true this is medium; filed in frontmatter `deferred:` with what would settle it.
  - `[low]` `[reject]` An `input` parsing as a JSON array reaches `function.arguments` as array text - grouped with the non-object-input row above.
  - `[low]` `[patch]` `SchemaOf` accepted any object, so an array schema reached OpenAI's `parameters` while Gemini silently got an empty one - it now requires a `%Library.DynamicObject`, the check `BodyOf` already made.
  - `[low]` `[reject]` A non-string schema `type` emits a stringified OREF - `Registry.SCHEMATYPES` admits only the six string types and `EmitSchema` refuses anything else, so no caller reaches it; the fix adds a guard.
  - `[low]` `[reject]` `WorkBudgetSec` would go non-positive if the two budgets were set within nothing of each other - both are shipped parameters pinned against the turn-side ceiling; theoretical.
  - `[low]` `[patch]` The test helper `Path()` returned a mid-path scalar instead of an empty string - fixed, so its documented contract holds and an AC2 assertion cannot pass against a wrong-shaped body.
  - `[low]` `[reject]` The deadline pin's stored timeout and its elapsed stand-in are no longer coupled - grouped with the deadline-purpose row above.
  - `[false]` `[reject]` Removing the no-clamp test left "the clamp only lowers" unpinned - `EffectiveTimeoutSec(tWork-1)` pins an in-budget value passing through and the defaults test pins 90 end to end through `NewRequest`.
  - `[medium]` `[reject]` The run result's method count disagrees with the class - grouped with the 12-versus-13 row above.
  - `[medium]` `[patch]` Four of six reported greens predated the in-pass patch - all seven classes were re-run after the patch set; runs 184 to 192 are recorded at finalize.
  - `[medium]` `[patch]` The matrix's "never a silent empty reply" was falsified by a choices array whose first entry is empty - grouped with the no-message row above and fixed with it.

Verification Gap Reviewer:

  - `[medium]` `[patch]` The Gemini `finishReason` map had no executed assertion, every test body short-circuiting on tool calls or carrying no reason - a sweep over a reply with no `functionCall` part was added, plus a truncated tool-calling leg.
  - `[low]` `[patch]` The clamp line's level and code are observed by nothing - the doc half is corrected above; the level is rejected as the one every other `Attempts` exit uses, reopen_if an operator reports console noise from a clamped call.
  - `[low]` `[reject]` `Retry`'s `tAllowed` floor is unreachable and its apparent pins cannot redden - grouped with the floor row above.
  - `[low]` `[reject]` `Retry`'s zero-timeout branch is unreachable from production - grouped with the same row.
  - `[medium]` `[patch]` Two refusal legs asserted an empty `Text` on a fresh response, which is the only value it could have had - both now seed `Text` before the refusing call and assert it was not overwritten.
  - `[medium]` `[reject]` The run result undercounts the class it certifies - grouped with the 12-versus-13 row above.
  - `[low]` `[reject]` `lint-docs.sh` and `npm test` outcomes are not recorded - the fix is to edit this build's spec; both are recorded at finalize.
  - `[low]` `[patch]` `GeminiSchema` copies non-rewritten members by reference - stated at the method, grouped with the copy row above.

Intent Alignment Auditor:

  - `[low]` `[reject]` The row-to-family hop is unpinned: two probe rows name one `adapterClass` and the dialect comes from a switch - the spec's Code Map chose one fixture with a dialect switch, the row-to-adapter hop is pinned by `ServedBy` and AC2's mutation, and the per-family adapters are 10.2's and 10.3's.
  - `[low]` `[reject]` The shipped seam has no shipped caller - by design; `Consumed-by` names 10.2 and 10.3 and Rule 1's Integration AC is satisfied by the probe row plus the fixture.
  - `[medium]` `[patch]` The locked subset is enforced upstream of the translators, not in them - grouped with the overclaim and live-chain rows above.
  - `[low]` `[reject]` The degenerate pair satisfies the product inequality but not a wall-clock reading - grouped with the zero-timeout row above.
  - `[low]` `[reject]` No test stores an `Egress` row, so the matrix's named state is one hop from what is pinned - `Egress.Resolve` to the settings array is pinned by `Test.Egress`, `Dispatch`'s pass-through by `Test.ProviderPort`, and the clamp over that array by the new tests; mutating the instance's single shared row here would court the cross-class fixture hazard DW-54 names for no new information.
  - `[low]` `[reject]` "Logged once" is pinned at the seam rather than at the rendered line - `Base.LogRaw` is this class's designed seam and the one `ProviderPortProbe` already captures; asserting the console line would pin `Audit.Log`'s formatting, which `Test.Log` owns.
  - `[low]` `[reject]` The tool-call stop reason overrides the vendor's, and a candidate with no parts answers `$$$OK` - the first is now narrowed to the Gemini case it exists for; the second is documented at the method as "the model answered, with nothing in it".
  - `[false]` `[reject]` The diff is one revision behind the tree on the spec's `status` line - an artifact of when the diff was staged; that line is this workflow's own field, not a reviewed-diff change.

### 2026-09-19 - Code review (full-opus; blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor)

- 59 raw findings, 9 entries after grouping: high 0, medium 6, low 3. 4 patched, 5 ledgered
  (`DW-1179` to `DW-1183`). Dispositions and evidence are the `### Review Findings` subsection
  under `## Tasks & Acceptance`.
- Re-filings of items this story already adjudicated were closed where they closed: the clamp
  line's level and empty code, `WorkBudgetSec` going negative, `EffectiveAttempts`' unreachable
  floor and zero-timeout branch, `Test/Adapter.cls`'s length against the 500-line guidance, and
  `SchemaOf` being public. The superseded sentence at `Kernel/Agent/Limits.cls:91-101` is
  `DW-1104`'s occurrence and the lead's at adjudication; it was not re-filed.
- Verified clean and worth recording: `Registry.TOOLNAMEPATTERN` is strictly narrower than both
  vendors' function-name grammars, so the wire round trip cannot produce a name either family
  refuses; `Base.cls:324` is the only `%Net.HttpRequest.Timeout` assignment on the provider path.

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

- **AC1** -- pinned by `OcuPilot.Test.Adapter.TestTheLockedSubsetIsKeptVerbatimByBothTranslators`. `mutation:` add `pattern` to `Screen/Tool/Registry.cls` `EMITTEDKEYWORDS` -> red on the emitted-property-keyword assertion (observed 2026-09-18). That test now also carries `Registry.ProviderTools`' own emitted schemas through both translators; `mutation:` have `ToolDefAdapter.GeminiSchema` emit Gemini's `format` keyword beside each `type` -> red on "no Gemini declaration carries a keyword outside the emitted subset" (observed 2026-09-18).
- **AC2** -- pinned by `OcuPilot.Test.Adapter.TestAProbeFamilyIsOneCatalogRowPlusOneAdapter`, driving `ProviderPort.Invoke` against a stored probe definition. `mutation:` point `CatalogProbe.DIALECTADAPTER` at `OcuPilot.Test.ProviderStub` -- the canonical adapter over the transport seam, which is `Anthropic` without the socket this story may not open -> red on `ServedBy` and on every field-name assertion in both dialects (observed 2026-09-18).
- **AC3** -- pinned by `OcuPilot.Test.ProviderRetry.TestAStoredTimeoutFarPastTheDeadlineIsClampedAtThePointOfUse`. `mutation:` make `Retry.EffectiveTimeoutSec` answer its argument unchanged -> red on the recorded timeout (3600) and on the bound (3630 <= 300) (observed 2026-09-18). The row's logging half is pinned by `OcuPilot.Test.Adapter.TestTheClampLogsOnceWhenItLoweredAValueAndIsSilentOtherwise`; `mutation:` return from `Base.LogClamp` before it logs -> red on the one-line assertion (observed 2026-09-18).
- **AC4** -- pinned by `OcuPilot.Test.Adapter`'s two translation-failure tests. `mutation:` answer `$$$OK` from `MessageAdapter.UnmatchedResult`, so an unmatched result is dropped rather than refused -> red on both refusal legs and on "no call was made" (observed 2026-09-18). Raising instead falsifies nothing: `Base.Invoke`'s outer `Catch` answers `$$$OK` for a raise as for a status, which is the never-throw template working.
- **AC5** -- pinned by `OcuPilot.Test.Adapter.TestTheCanonicalFamilyIsAByteIdenticalPassthrough` beside `OcuPilot.Test.Provider`'s existing Anthropic body assertions. `mutation:` route the Anthropic adapter's `CallMessages` through `MessageAdapter.CanonicalToOpenAi` -> red on the byte-identity assertion and on the `tool_calls` / `tool_call_id` foreign-field assertions (observed 2026-09-18).
- **(QA)** AC1, AC2, AC4 and AC5's four mutations above independently re-applied and re-observed on `ocupilot-slot-b` -- red at runs 198/200/201/202, green at 199/203, tree confirmed byte-identical after each revert (observed 2026-09-19).
- **(QA)** `OcuPilot.Test.Adapter.TestGeminiSchemaCopiesAnUnrecognizedKeywordThroughUnchanged` pins the corrected doc claim that a keyword outside the locked subset is copied through rather than refused. `mutation:` drop `ToolDefAdapter.GeminiSchema`'s fallback `tOut.%Set(tKey, tValue)` copy branch -> red on the copied-through keyword (observed 2026-09-19).
- **(QA)** `OcuPilot.Test.Adapter.TestTheClampStaysSilentForAStoredAttemptCountOfZero` pins that a stored attempt count of zero logs no clamp line. `mutation:` remove `Base.LogClamp`'s own `tAsked < 1` floor -> red on a spurious clamp line (observed 2026-09-19).
- **(CR)** `OcuPilot.Test.Adapter.TestAnArrayIsNeverSentAsArgumentsAndNeverBecomesACanonicalInput` and
  `TestAReplysUnanswerableToolCallIsRefusedRatherThanStored` pin the two guards this review added.
  `mutation:` the pre-patch code itself -- both methods red at run 205 (16 of 18) against it and
  green at 206 with the guards in place (observed 2026-09-19).
- **(CR)** `OcuPilot.Test.Adapter.TestTheOpenAiRequestSendsTheLoopsCallsOnlyAndResultsOnlyShapes`
  pins the two request shapes `Loop.AnswerTools` produces. `mutation:` send the calls-only message's
  `content` as a string instead of `null` -> red on the content-type assertion (run 207);
  `mutation:` drop the empty-companion `Continue` at `MessageAdapter.cls:156` -> red on the message
  count, which reports the `{"role":"user","content":""}` it lets through (run 208). Both reverted,
  tree byte-identical, class green at run 209 (observed 2026-09-19).
- **(QA) Files changed:** `src/OcuPilot/Test/Adapter.cls` (QA) -- two gap-filling test methods added; no other file under `src` or `ui` differs from baseline.

## Auto Run Result

Status: done
Blocking condition: none

**What was implemented.** Two translator classes under `Kernel/Provider/` carry the canonical
(Anthropic) message array into the OpenAI and Gemini dialects and each dialect's reply back into
canonical `tool_use` blocks, and the canonical tool array into each family's declaration shape;
neither branches on a provider name and neither reads a credential. The effective per-call timeout
and attempt count are clamped at the point of use, so `(attempts x timeout) + RETRYBUDGETSECONDS`
is at most `ATTEMPTBUDGETSECONDS` for any stored or caller-supplied pair, at least one attempt is
always made, and the shipped 90 x 3 + 30 defaults clamp to themselves. Nothing above
`ProviderPort` changed.

**Files changed** -- the eight the Code Map names, plus this spec:

- `Kernel/Provider/MessageAdapter.cls` -- new: both directions of both dialects, correlating a
  result with the nearest preceding call and synthesizing an id for Gemini.
- `Kernel/Provider/ToolDefAdapter.cls` -- new: the tool array in each family's declaration shape;
  Gemini loses only `additionalProperties`, named in `GEMINIDROPPED`.
- `Kernel/Provider/Retry.cls` -- `WorkBudgetSec`, `EffectiveTimeoutSec`, `EffectiveAttempts`; the
  superseded `ATTEMPTBUDGETSECONDS` paragraph replaced at its origin.
- `Kernel/Provider/Base.cls` -- the clamp applied at `Attempts` and at `NewRequest` through a
  private `TimeoutOf`, `LogClamp` logging once when a value was lowered; the superseded `Attempts`
  paragraph replaced.
- `Test/Adapter.cls` -- new: 13 methods over every matrix row and error column, the clamp's
  boundaries and its log line, AC2's port leg and AC5's byte identity.
- `Test/AdapterProvider.cls` -- new: the probe family adapter, a `ProviderStub` subclass whose
  dialect is a switch, with a log-capture seam.
- `Test/CatalogProbe.cls` -- two probe rows naming that adapter. No shipped row added.
- `Test/ProviderRetry.cls` -- the no-clamp residual-risk pin replaced by the clamp pin, a
  defaults-unchanged pin, and a 65-pair worst-case sweep.

**Review findings.** 57 across four layers: high 0, medium 17, low 35, false 4, maybe-false 1.
Routed 22 patch, 2 defer, 33 reject. Every rejected finding's reason is its own row under
`## Review Triage Log` above.

Patched, grouped by root cause -- 8 medium entries and 5 low:

- medium: the Gemini `finishReason` map was unexercised and incomplete; the stop reason let a tool
  call overwrite a truncation or a filter; an id-less call correlated with an id-less result; the
  two translator docs overclaimed what they enforce and hid both the aliasing and the ordering
  dependency; AC1 was pinned against a fixture schema rather than the registry's own emitted
  output; a first choice with no message was answered as an empty reply; two refusal-leg assertions
  could not fail; four reported greens predated the in-pass patch.
- low: `LogClamp`'s doc word; `SchemaOf` accepted a non-object; the test helper `Path()` returned a
  mid-path scalar; the fixture's body could be read as a family adapter's; the vendor name grammar
  was unpinned.

Deferred, in frontmatter `deferred:`: the superseded sentence at `Kernel/Agent/Limits.cls:91-101`
(Epic 5's footprint), and an unverified exposure where a boundary-stopped turn could leave a
`tool_use` unanswered in stored history.

**Follow-up review recommended: true.** Eight medium entries were patched on a first pass. The
unverified risk it names: the two translators still have no shipped caller, so every wire-shape
claim rests on a fixture's composed body rather than on a family adapter's request, and this pass
changed canonical stop-reason behavior that only that fixture exercises. Story 10.2's adapters are
the first real exercise of it.

**Verification**, all on `ocupilot-slot-b` (IRIS 2026.2 build 221U, instance GUID
`EE371308-B136-11F1-B1BD-82DD33222152`); no socket was opened to a provider:

- `uv run scripts/check-objectscript.py` -- clean, 479 files over 21 rules.
- `uv run scripts/test_check_objectscript.py` -- 126 of 126.
- All 479 classes loaded and compiled `cku`, then the provider tree force-compiled `ck` so no
  subclass kept a stale copy of an inherited method -- no errors.
- `bash scripts/lint-docs.sh` -- clean: markdownlint 0 issues, check-prose 0 problems in 89 files.
- From `ui/`: `npm test` -- 1044 `node --test` and 640 component tests passing, unchanged.
- `node ui/tools/ci-runner.mjs --container ocupilot-slot-b --class <one class>`, one per
  invocation, every run after the patch set and each confirmed against `%UnitTest_Result`:
  `Adapter` 13/13 (run 192), `ProviderRetry` 12/12 (185), `Provider` 20/20 (186), `ProviderPort`
  20/20 (187), `ProviderConsumer` 6/6 (188), `AgentRules` 18/18 (189), `ReadTool` 27/27 (190).
  `ReadTool` was added to the set: it is what pins `Registry.ValidateArguments` refusing an
  undeclared argument, which is the matrix row that says Gemini losing `additionalProperties`
  costs nothing.
- `OcuPilot.Test.ProviderSecret` cannot run on a dev instance -- its own `OCUPILOT_ALLOW_ERROR_SEED`
  guard refuses there. It ran 1/1 green on this slot's throwaway
  (`scripts/ci-throwaway.sh up --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci --web 52777
  --super 1976`), which was then torn down. The class is unchanged by this story.
- AC2's second half: `git diff --name-only 84a5fdc..HEAD -- src ui module.xml` returns exactly the
  eight Code Map paths and nothing under `Kernel/Agent/`, `Kernel/Proposal/`, `Screen/`, `Api/`,
  `Install/`, `module.xml` or `ui/`.
- Six mutations demonstrated: the five on the `## Verification` lines above plus the clamp's log
  line, each applied, recompiled over the whole package, observed red, reverted, and the tree
  confirmed byte-identical.

**Residual risks.**

- No shipped caller reaches either translator until Story 10.2, so the wire bodies are pinned as
  the translators' own output and as a fixture's composition of it, never as a shipped family
  adapter's request.
- The clamp's log line is written at the level and through the seam every other `Attempts` exit
  uses, which puts a misconfiguration on the operator console. That is deliberate and recorded;
  reopen it if an operator reports noise from a clamped call.
- The Gemini reply direction synthesizes call ids, so a history that reached Gemini and then a
  different family carries ids no other vendor issued. Both request directions resolve them only
  locally, so this is inert today.
