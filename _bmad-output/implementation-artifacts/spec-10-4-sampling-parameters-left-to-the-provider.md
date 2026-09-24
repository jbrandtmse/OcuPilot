---
title: 'Story 10.4: Sampling parameters left to the provider'
type: 'bugfix'
created: '2026-09-23'
status: 'done'
baseline_revision: '0b4fe3390ad15528ab8505488fbc679a3a916242'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred:
  - summary: >-
      AgentViolation's providers-route assertion message still says "the twelve cascade columns" and names only adapterClass and authVersion as absent.
    evidence: |-
      The expected column string is exact and green; only the message is stale (thirteen columns now, and reasoningEffort is also deliberately absent). Task 15 limits this story to one literal edit in a file outside Epic 10's footprint.
    location: >-
      src/OcuPilot/Test/AgentViolation.cls:215
    severity: low
---

<intent-contract>

## Intent

**Problem:** Every shipped catalog row applies a canonical `temperature` of 0 to each new definition, and every adapter sends it. The catalog default models of Anthropic and OpenAI refuse that value, so a definition built from OcuPilot's defaults fails Test connection on the first try. Claude Opus 5 also thinks by default, and `Anthropic.MapResponse` keeps only `text` and `tool_use` blocks. A turn that calls a tool therefore sends the next request without that assistant turn's thinking blocks.

**Approach:** Make temperature optional end to end. The catalog declares no canonical value, and the stored column may be empty. OpenAI, Gemini and compatible send the field only when a value is set. The Anthropic adapter never writes any sampling parameter. A new catalog column, `acceptsTemperature`, tells the form which families take a temperature. The Anthropic adapter keeps a reply's content verbatim whenever the reply carries reasoning blocks, and the loop's echo sends that content back unchanged.

## Boundaries & Constraints

**Always:**

- Adapters decide what goes on the wire. The catalog is the one place a provider fact is spelled, and no shipped class or client component branches on a provider name.
- A stored temperature that is not empty is an explicit value. It is kept, projected, and sent to the families that take one. Nothing migrates, clears or rewrites it.
- Every test tier is stub-based: no socket, no live provider, no key. Every new user-facing string is a row in EXPERIENCE.md's Fixed strings and an appended key in `strings.ts`. Colours come from tokens only.

**Never:**

- Send `temperature`, `top_p` or `top_k` to Anthropic.
- Refuse a stored temperature on an Anthropic definition. Validation stays family-blind, so an existing row saved with 0 still saves.
- Move `SCHEMAVERSION`, or hand-write a Storage section.
- Change the tool registry, the proposal lifecycle, or any screen other than the Definition form.
- Change the loop anywhere except the one echo branch described in Tasks.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Create omits temperature | `POST /agent/definitions` with no `temperature` key, any shipped provider | stored `Temperature` `""`; projection answers `"temperature": null` | No error expected |
| Explicit empty | body `"temperature": ""` | stored unset, accepted | No error expected |
| Explicit value | `0`, `.7`, `0.7`, `2` | stored and projected as given | No error expected |
| Out of range | `3`, `-1`, `"abc"` | refused | one violation `{temperature, AGENT.TEMPERATURE.RANGE}` |
| OpenAI / compatible body, unset | stored `""` | the request body has no `temperature` key | No error expected |
| Gemini body, unset | stored `""` | `generationConfig` has `maxOutputTokens` and no `temperature` | No error expected |
| Non-Anthropic body, set | stored `0.7` | `temperature` 0.7 (Gemini: `generationConfig.temperature` 0.7) | No error expected |
| Anthropic body, any stored value | `""`, `0`, `0.7` | body has none of `temperature`, `top_p`, `top_k` | No error expected |
| Pre-story row | a row saved with `Temperature` 0, then updated with an unrelated field | still 0, projected 0, sent as 0 to a family that takes one | No error expected |
| Reply with reasoning and a tool call | content `[thinking{thinking,signature}, redacted_thinking{data}, text, tool_use]` | the next request's assistant message `content` is that array, same order, each block's JSON identical | No error expected |
| Reply without reasoning | content `[text, tool_use]` | echo unchanged from today (text block when non-blank, then the tool_use blocks) | No error expected |
| Providers route | `GET /agent/providers` | each row carries `canonicalTemperature` `null` and `acceptsTemperature`: `false` for anthropic, `true` for openai, gemini and compatible | No error expected |

</intent-contract>

## Code Map

- `src/OcuPilot/Kernel/Provider/Catalog.cls:55-60` -- shipped XData rows. `:76` is the armed `turnprobe` row. Each row carries `"canonicalTemperature":0`. The column doc at `:33-34` says "the tuning applied when a create omits them".
- `src/OcuPilot/Kernel/Provider/Anthropic.cls:51` -- writes `temperature` unconditionally. The class doc's wire contract (`:11`) names it. `MapResponse` (`:123-160`) keeps only `text` and `tool_use`, so thinking blocks are dropped here. `ProviderStub`, `TurnProvider` and `CatalogAnthropicStub` (all in `src/OcuPilot/Test/`) extend this class and inherit both methods.
- `src/OcuPilot/Kernel/Provider/OpenAI.cls:54`, `Gemini.cls:104` -- `+$Get(pValues("temperature"))`. An empty value therefore becomes 0 on the wire. `Compatible.cls` inherits `OpenAI.CallMessages`, and the class docs at `OpenAI.cls:13` and `Gemini.cls:19` name the field.
- `src/OcuPilot/Kernel/Provider/Response.cls` -- `Text` and `ToolCallsJson`. No property carries the rest of a reply.
- `src/OcuPilot/Kernel/Agent/Loop.cls:229-239` -- `ToolUses(ToolCallsJson)` returns the array unfiltered, so every element is dispatched as a call. That is why reasoning blocks cannot travel in `ToolCallsJson`. `:403-420` `AnswerTools` builds the echo from `pText` plus `pToolUses`. `:239` is its only caller.
- `src/OcuPilot/Port/ProviderPort.cls:444` -- `ValuesFor` sets `pValues("temperature") = +tRow.Temperature`, which turns unset into 0.
- `src/OcuPilot/Kernel/State/Agent.cls:97-98` -- `Property Temperature As %Numeric(SCALE = 2) [ InitialExpression = 0 ]`. Saves go through object `%Save` (`State/Base.cls:158-227`; only `RowVersion` is SQL-updated), so an empty `%Numeric` stores as null with no `$Char(0)` sentinel.
- `src/OcuPilot/Kernel/AgentRules.cls:157-159` -- rule 4 calls `IsNumberInRange` (`:383-389`), which refuses `""`. The rule list doc is at `:105`.
- `src/OcuPilot/Api/Definitions.cls` -- `:17-22` header, `:149-152` `CatalogDefaults` (keep it: a null column yields `""`), `:199-202` `ProviderColumns`, `:1404-1416` `ApplyCatalogDefaults`, `:1463-1473` `SetTyped`. `SetTyped` writes `+pValue` for a number, so unset is projected as 0. `:1482-1497` `ChangeSet`: a create compares against an empty before-state.
- `src/OcuPilot/Test/TurnTools.cls:1-60, :175-200` -- the in-process turn harness: `TurnLoopProbe`, `ProviderPortProbe`, and `ProviderStub.QueueAnswer`/`Recorded("body", n)` (`ProviderStub.cls:55, :195`). Copy its setup and `RunTurn`/`Reply` helpers. Do not edit or extend `TurnTools` (it is Epic 9's file).
- `src/OcuPilot/Test/{OpenAI,Gemini,Compatible}Adapter.cls:110/98/112, :186/174/140, :242/230` -- setup helpers store `+pRow.canonicalTemperature`, and the body assertions compare with `+`. An absent key and 0 then read the same, so these must change. `Test/Provider.cls:147` asserts the Anthropic body's temperature is 0. `Test/Adapter.cls:814` `CANONICALBODY` contains `"temperature":0`. `Test/AgentRules.cls:162-172` `AssertRowPinned` pins `canonicalTemperature`, and `:193-208` holds the rule 4 legs.
- **Not Epic 10's, and reddened by this story:** `Test/AgentViolation.cls:214` pins the `/agent/providers` column set exactly. `Test/AuditRecord.cls:196-200` expects a create's audit record to carry a `temperature` change with an empty old value; a create now stores unset, `ChangeSet` sees no difference, and the entry is gone.
- `ui/src/app/areas/agent/definition-form.store.ts` -- `:28-46` `ProviderRow`, `:140-144` `numberAt` (answers 0 for null), `:795-812` `loadProviders`, `:816-824` `applyProviderDefaults` (`String(row.canonicalTemperature)`), `:863-868` body numbers (an empty value is already sent as `""`).
- `ui/src/app/areas/agent/definition-form.page.ts` -- `:375-393` the Temperature field, `:793-796` its getter, `:1117-1132` `fieldView`/`describedBy`. The retention field (`:440-448`, `aria-disabled` plus `ocu-field-caption`) is the precedent for an inert field. `[attr.placeholder]="STRINGS.…"` is the placeholder precedent (`areas/logs/log-viewer.page.ts:84`).
- `ui/src/app/core/strings.ts:521` -- `agentDefinitionFieldTemperature`. `EXPERIENCE.md:335-336` -- the Definition form's Fixed-strings rows. `ui/tools/strings.test.mjs:532-535` bounds the table at 150-700 literals; it holds 695 today, 698 after this story's three.
- `ui/browser/definitions.browser-spec.mjs:436` -- the Story 10.3 case, the pattern for a provider switch and save. `ui/browser/structural-walk.mjs:483` exports `detectScreen(page, {route, checks, viewport, theme, minimums})` and `INVARIANTS`, the DW-1337 detectors, callable on the current page state.

## Tasks & Acceptance

**Execution:**

1. `src/OcuPilot/Kernel/Provider/Catalog.cls` -- In all five XData rows, set `"canonicalTemperature":null`, and add `"acceptsTemperature"` after `allowsLocal`: `false` on anthropic and turnprobe, `true` on openai, gemini and compatible. Update the column docs. `canonicalTemperature` is now "applied when a create omits it; `null` leaves it unset so the provider default applies". `acceptsTemperature` is "whether this family's request may carry a temperature; the Definition form reads it".
2. `src/OcuPilot/Kernel/State/Agent.cls` -- Change to `Property Temperature As %Numeric(SCALE = 2);` with no InitialExpression. The doc comment says: `""` is unset and the provider's default applies; 0-2 is explicit. It also records the no-`SCHEMAVERSION`-move reasoning from Design Notes in two sentences.
3. `src/OcuPilot/Kernel/AgentRules.cls` -- Rule 4 accepts `""` or a number from 0 to 2, and the rule doc at `:105` changes to match.
4. `src/OcuPilot/Port/ProviderPort.cls:444` -- Pass the stored value through: `""` when unset, `+value` otherwise.
5. `src/OcuPilot/Kernel/Provider/Anthropic.cls` -- Delete the temperature line and correct the wire-contract doc. `MapResponse` additionally sets `pResponse.ContentJson` to `content.%ToJSON()` **only when** some block's `type` is `thinking` or `redacted_thinking`.
6. `src/OcuPilot/Kernel/Provider/{OpenAI,Gemini}.cls` -- Write `temperature` only when `$Get(pValues("temperature")) '= ""`, and mark it optional in the class docs. `Compatible` inherits the change.
7. `src/OcuPilot/Kernel/Provider/Response.cls` -- Add `Property ContentJson As %String(MAXLEN = "")`: the reply's content array verbatim when it carries reasoning blocks that must go back to the provider, and `""` otherwise.
8. `src/OcuPilot/Kernel/Provider/Base.cls:110` -- The doc names `temperature` as optional.
9. `src/OcuPilot/Kernel/Agent/Loop.cls` -- `AnswerTools` gains a trailing `pContentJson As %String = ""`. When it parses to a non-empty array, that array is the assistant message's `blocks` and the rebuild is skipped. `:239` passes `tResponse.ContentJson`. Nothing else in the loop changes. This is a footprint extension (see Design Notes).
10. `src/OcuPilot/Api/Definitions.cls` -- `SetTyped` writes JSON `null` for a `number` whose value is `""`. `ProviderColumns` appends `$ListBuild("acceptsTemperature", "boolean")`. Correct the header at `:17-22`: a shipped row declares no canonical temperature, so a create that omits one stores it unset.
11. `src/OcuPilot/Test/AdapterSampling.cls` -- new. Drives every shipped row through `ProviderPort` with only the transport swapped. The three OpenAI-family rows use `CatalogProbeShipped`; the anthropic row uses `CatalogAnthropicStub`. Covers the six body rows of the matrix, plus a pin that for each shipped row, `acceptsTemperature` equals whether a stored `0.7` reaches the recorded body.
12. `src/OcuPilot/Test/AnthropicThinking.cls` -- new, on the `TurnTools` harness. Queue reply 1 with the matrix's reasoning content (a signature containing `+`, `/` and `=`), then queue reply 2 as plain text. Assert that request 2's assistant message `content` has the same size and order, and that each block's `%ToJSON()` equals the served block's. Also cover the no-reasoning echo row.
13. `src/OcuPilot/Test/ProviderSampling.cls` -- new, over HTTP following `Test/AgentWire`'s `Call` seam (copy the helper; do not extend that class). Covers the create, explicit-empty, explicit-value and out-of-range rows; `GET /agent/providers` for both columns; and the pre-story row (created through `GuardedCreate` with `Temperature` 0, then `PUT` of an unrelated field).
14. `src/OcuPilot/Test/{Adapter,AgentRules,Provider,OpenAIAdapter,GeminiAdapter,CompatibleAdapter}.cls` -- Update the pins located in the Code Map. `CANONICALBODY` loses `temperature`. `AssertRowPinned` expects `canonicalTemperature` `""` and takes an expected `acceptsTemperature`. Rule 4 gains unset-accepted legs. Setup helpers store the row's value verbatim, and body assertions test that the key is present or absent, never `+value`. `Adapter` gains a `MapResponse` leg: `ContentJson` is set with reasoning and `""` without, and `Text` and `ToolCallsJson` stay unchanged.
15. `src/OcuPilot/Test/AgentViolation.cls:214` -- Append `,acceptsTemperature` to the pinned column string, with a one-line comment naming Story 10.4 as the shipping surface. `src/OcuPilot/Test/AuditRecord.cls:198` -- Drop `"temperature"` from the loop's field list and correct "five" to "four", with a one-line comment: Story 10.4 creates temperature unset, so it matches the empty before-state and records no change. Make one literal edit each and nothing else.
16. `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` -- Add one Fixed-strings row directly below `:336`: `"Provider default" · "Not applicable" · "This provider's current models refuse sampling settings, so OcuPilot sends none and the model uses its own."` The row's Where column: the Definition form's Temperature field (Story 10.4). The first literal is the placeholder while the value is empty on a row that takes a temperature. The second and third are the placeholder and caption on a row whose `acceptsTemperature` is false.
17. `ui/src/app/core/strings.ts` -- Append `agentDefinitionTemperatureProviderDefault`, `agentDefinitionTemperatureNotApplicable` and `agentDefinitionTemperatureNotApplicableCaption` beside `:521`. Append only.
18. `ui/src/app/areas/agent/definition-form.store.ts` -- `ProviderRow.canonicalTemperature: number | null`, and add `acceptsTemperature: boolean`, parsed as `!== false` so an absent column still reads as applicable. The cascade sets `''` for a null canonical value. Add a `temperatureApplies()` read over the selected row.
19. `ui/src/app/areas/agent/definition-form.page.ts` -- On a row that applies, the placeholder is "Provider default". On a row that does not, the input is `readonly` with `aria-disabled="true"`, its placeholder is "Not applicable", and the caption is rendered as `ocu-field-caption` and referenced from `describedBy`. A stored value is displayed as held and is never cleared by the form.
20. `ui/src/app/areas/agent/definition-form.page.spec.ts` -- Add cases for the cascade to `''`, the "Provider default" placeholder, the Anthropic-row state (readonly, aria-disabled, caption, described-by), and a held value surviving a save.
21. `ui/browser/definitions.browser-spec.mjs` -- Add one case. Open Create and expand Advanced. On anthropic, assert the not-applicable state and caption. Switch to OpenAI and assert `value === ''` with the "Provider default" placeholder. Save by the Integration AC case's path, and read the definition's `temperature` as `null` from the API. In each of the two states, run `detectScreen` with every `INVARIANTS` check at 1280 and 720 px light and at 1280 px dark, and assert no violations.
22. **DW-1590** -- `src/OcuPilot/Kernel/Provider/Catalog.cls` gains a row column `reasoningEffort`: `"none"` on the openai row, `""` on every other row (compatible included, because an OpenAI-compatible server is not OpenAI and may refuse an unknown key). `OpenAI.CallMessages` writes `reasoning_effort` only when the value it is handed is non-empty; `ProviderPort` passes the row's value through as it passes `authVersion`. The column is not added to `ProviderColumns` (the form has no use for it), so `/agent/providers` and its pin are unchanged by this task. New legs in `AdapterSampling`: the openai row's recorded body carries `"reasoning_effort":"none"` beside its tools; the compatible row's body carries no `reasoning_effort` key.
23. **DW-1591** -- `MessageAdapter.GeminiToCanonical` keeps a `functionCall` part's sibling `thoughtSignature` (a string) as a `thoughtSignature` member of the canonical `tool_use` block it builds, verbatim; `CanonicalToGemini` writes it back as the replayed `functionCall` part's sibling `thoughtSignature`, verbatim, and writes nothing when the block has none. `Loop.AnswerTools` already pushes each `tool_use` block unchanged, so no loop change beyond task 9. New leg (in `AnthropicThinking` or a new `Test/GeminiSignature.cls`, on the same `TurnTools` harness with the gemini row): reply 1 is a Gemini `functionCall` part carrying a `thoughtSignature` (containing `+`, `/` and `=`), reply 2 plain text; request 2's replayed `functionCall` part carries that signature byte for byte. Plus a `MessageAdapter` round-trip leg without a signature (no key written).

**Acceptance Criteria:**

- **Integration (Rule 1).** Given the Anthropic adapter's `Response.ContentJson`, when `OcuPilot.Kernel.Agent.Loop` answers a tool call and makes its next provider call, then that request's assistant message carries the reply's reasoning blocks unchanged. This is observed on the recorded request through the port, never by reading the adapter's state.
- **Integration (Rule 1).** Given the `acceptsTemperature` column served by `GET /agent/providers`, when the Definition form renders a provider in a real browser, then the Temperature field's state follows the column.
- Given a new definition on a provider whose row takes a temperature, when the Definition form opens and Advanced is expanded, then Temperature is empty, reads "Provider default", and saves unset. Given the anthropic row, then the field reads "Not applicable", is readonly and `aria-disabled`, and its caption gives the reason. Both states pass every DW-1337 invariant.
- Given any shipped row, when the suite runs, then no test opens a socket or reads a key, and the live proof on each catalog default model stays the owner's Story 17.7 check.
- **DW-1590.** Given the shipped openai row with tools advertised, when a turn's request is built, then the body carries `reasoning_effort` `"none"`; given the compatible row, then it carries no `reasoning_effort`. (The catalog default `gpt-5.6-terra` refuses function tools on chat/completions otherwise -- lead live probe 2026-09-24.)
- **DW-1591.** Given a Gemini reply whose `functionCall` part carries a `thoughtSignature`, when the loop answers the call and makes its next provider call, then the replayed `functionCall` part carries that signature unchanged. (The catalog default `gemini-3.8-flash` answers 400 without it -- lead live probe 2026-09-24.)
- Given the diff, when it is reviewed, then it touches no tool registry, proposal code or screen other than the Definition form, and the only loop change is the `AnswerTools` echo branch.

## Spec Change Log

- 2026-09-24, spec gate (lead): added tasks 22-23 and their two acceptance criteria for DW-1590 (OpenAI `reasoning_effort`) and DW-1591 (Gemini `thoughtSignature`), both found by the lead's live probe of the catalog default models; the Observation paragraph in Design Notes is replaced by the decision.

## Review Triage Log

### 2026-09-23 — Review pass

- verdicts: 18 findings — high 0, medium 1, low 5, false 12, maybe-false 0
- findings:
  - `[medium]` `[patch]` The form's Temperature tests never let the provider name and `acceptsTemperature` disagree, so a name branch (AD-5) would pass — added the page-spec case `the field follows the acceptsTemperature column, never the provider name` with the columns inverted; the name-keyed `temperatureApplies()` mutation reddens it alone (recorded in Verification).
  - `[low]` `[patch]` The browser case's two DW-1337 `freshViolations` assertions had no recorded mutation, and `unmeasurable` is not asserted — recorded the caption contrast mutation (`#eeeeee`, rebuilt and redeployed; red at 1.12:1), which also shows the caption is measured; no `unmeasurable === 0` assertion added, because the form route carries 4 unmeasurable text elements before this story in every state.
  - `[low]` `[reject]` AC5 has no pinning mutation for the stub-adapter guards — the spec records AC5 as a tier property with no pinning test by construction; the only mutation that exercises a guard points a test at a shipped adapter, which risks the live call AC5 forbids, and the guard is a plain prefix test plus `Quit` read at `AdapterSampling.BodyFor`.
  - `[low]` `[patch]` `AnthropicThinking` asserted that its own `SIGNATURE` constant contains `+`, `/` and `=`, which no code change can fail — deleted the assertion; the parameter's doc comment carries the fact. Class re-run on the throwaway: 4 tests, 0 failed (run 247).
  - `[low]` `[defer]` `AgentViolation.cls:215`'s message still says "the twelve cascade columns" and names only two absent columns — the expected value is exact; correcting the message is a second literal edit, which task 15 forbids on a file outside Epic 10's footprint.
  - `[false]` `[reject]` The reasoning echo runs on the `probe-local` row through `ProviderStub`, not the shipped `anthropic` row — `ProviderStub` overrides neither `CallMessages` nor `MapResponse`, so the shipped `Anthropic.MapResponse` and `Loop.AnswerTools` run; the row differs only in `adapterClass`.
  - `[false]` `[reject]` Block equality compares re-serialized objects, not raw request text — the Design Notes define the check this way ("Byte-for-byte, as tested"): every value and the order are asserted, which is what the provider validates.
  - `[false]` `[reject]` `SetTyped`'s empty-number-to-`null` rule reaches other number fields — no other number field can be empty: `maxTokens`, `maxIterationsPerTurn` and `retentionDays` carry InitialExpressions and rules that refuse empty, and every catalog number column is set.
  - `[false]` `[reject]` Removing the `Temperature` InitialExpression changes definitions created outside `POST` — task 2 specifies it; the only non-test readers are `ProviderPort.ValuesFor` and the projection, both of which handle unset.
  - `[false]` `[reject]` DW-1590 and DW-1591 exceed the intent contract — tasks 22-23 and their ACs were added at the spec gate by the lead.
  - `[false]` `[reject]` The `Run` call site is a second loop edit — task 9 names it (`:239 passes tResponse.ContentJson`).
  - `[false]` `[reject]` The three keys are not at the end of `strings.ts` — task 17 says "beside `:521`. Append only".
  - `[low]` `[reject]` The EXPERIENCE.md row sits at the end of the Fixed-strings table (line 465), not below `:336` as task 16 says — `ui/tools/strings.test.mjs` pins every `EXPERIENCE.md:n` reference in `strings.ts` to its line, so inserting at 337 would re-point every reference below it, against task 17's append-only keys; the end of the table is the only consistent place.
  - `[false]` `[reject]` Neither tier calls the Test-connection route — no AC requires it; `HandleTest` calls `ProviderPort.Invoke`, the body path `AdapterSampling` drives.
  - `[false]` `[reject]` "Anthropic takes no temperature" is spelled in both the adapter and the column — the Design Notes choose this deliberately, and `AdapterSampling.TestEachRowsColumnAgreesWithWhatItsAdapterSends` pins the two equal.
  - `[false]` `[reject]` `AdapterSampling` needs a resolver for the shipped hosts — that is the port's egress gate, which the Story 10.2/10.3 shipped-row tests already use; no provider connection is opened.
  - `[false]` `[reject]` Explicit values run on openai and anthropic only, and `.7` travels as a JSON string — the matrix names no provider set, and a bare `.7` is not valid JSON.
  - `[false]` `[reject]` The pre-story row is written through today's object layer — storage is unchanged by this story, so a 0 written now is stored the same as one written before it.

## Design Notes

**Governing ADs.** **AD-42** is the fixed provider contract. One base serves four adapters, Anthropic's shape is canonical, and the canonical assistant turn is the reply's own content, which is why reasoning blocks travel verbatim. **AD-39** is the envelope: rule 4's refusal keeps `{field, code, reason}`, and no new code is added. **AD-5** makes the catalog the one source, so the form reads `acceptsTemperature` rather than a provider name. **AD-9** covers the stored row: object `%Save` through `State/Base`, and no hand-written Storage. **AD-12**: no handler writes the response. **AD-11**: reasoning blocks are model output held only in the in-memory turn messages, and are never rendered, persisted or placed in a system prompt. **AD-24** is unchanged: earlier turns replay only the user message and the final reply, so no reasoning crosses a turn. **AD-35**: no key is involved. **AD-19**: the store stays framework-free and the page mirrors it. Conventions: **When `SCHEMAVERSION` moves**, **Concurrent writes** (unchanged: temperature is written through the guarded save), and **Theme/tokens** (the caption reuses `ocu-field-caption`).

**`SCHEMAVERSION` does not move.**

- No stored row changes meaning. A pre-story row holds an explicit number and reads as that number, with no migration.
- `Temperature` keeps its type. Only its default and its accepted values widen to include empty.
- An older build reading a new unset row computes `+""`, which is 0: its own canonical default, the value it would have written itself (inference: the older build's semantics are read from the pre-story `ValuesFor:444`).
- Downgrade is unsupported (Operational Envelope).

This is the Conventions row's "a property every pre-existing row reads as a safe default" case, and the property doc records it.

**AC6 has a visible cost.** A definition saved before this story with 0 on an OpenAI row keeps 0, so the default model keeps refusing it until the operator empties the field. That follows AC6's "nothing rewrites it", so nothing here works around it.

**Why a column, and why the adapter also hard-codes the Anthropic omission.**

- The form needs to know that a family takes no temperature. It cannot branch on a provider name, and `canonicalTemperature: null` already means "provider default", so a boolean column carries the fact.
- The Anthropic AC is unconditional ("whatever the definition holds"), so the adapter has no code path that writes a sampling field.
- `AdapterSampling`'s column-agreement pin keeps the two facts equal.
- `claude-haiku-4-5`, one of the anthropic row's suggestions, would accept a temperature. Opus 5, Sonnet 5 and Fable 5/5.1 return a 400 (claude-api reference, cached 2026-06-24). The AC is family-wide by the owner's decision, so the row is `false`.

**Why the loop is touched.**

- The existing reply channels cannot carry reasoning. `Loop.ToolUses` dispatches every element of `ToolCallsJson`, and `Text` is a string.
- The echo in `AnswerTools` is where the canonical assistant turn is written.
- The epic context's "must not modify the agent loop" comes from Story 10.1's AC about *adding a family*. This story changes the canonical turn's content and adds no family.
- The change is one optional parameter and one branch, taken only when a reply carries `thinking` or `redacted_thinking`. Every existing reply takes today's path, so the Epic 4/5 turn suites keep their exact echo.
- Rejected alternative: carrying the content inside a `tool_use` block's extra member. It is a side channel through dispatch and the step records, and it bloats progress (AD-33).
- The API requires reasoning blocks to go back unchanged and in order on the same model, and warns that removing or reordering them can return an ordering or signature 400 (claude-api reference). When `thinking` is omitted, Opus 5 runs adaptive thinking; its blocks carry an empty `thinking` string under the default `display: "omitted"`, plus a `signature`.

**Byte-for-byte, as tested.** Each block's `%ToJSON()` must equal the served block's `%ToJSON()`. Every member value is also asserted with `%Get`. This covers what the provider validates: every value, in order. It does not test incidental escaping, which IRIS's serializer normalizes either way.

**Wire representation of unset.** The server answers JSON `null`. The client sends `""` on write; `MergeBody` already takes it verbatim, and rule 4 accepts it. `SetTyped`'s `""`-to-`null` rule is general, but no other number field can be empty: each has an InitialExpression and a rule that refuses empty.

**Files outside Epic 10's exclusive list:**

- `src/OcuPilot/Kernel/Agent/Loop.cls` (footprint extension; no contended epic declares it).
- `src/OcuPilot/Test/AgentViolation.cls:214` and `src/OcuPilot/Test/AuditRecord.cls:198` (mechanical pins, one literal each).
- `EXPERIENCE.md` (one appended row), `ui/src/app/core/strings.ts` (three appended keys).
- `ui/tools/strings.test.mjs` only if the 700 bound trips after a merge, moved under that file's own documented protocol.

**DW-1590 and DW-1591 (added at the spec gate, lead live probe 2026-09-24, keys never recorded).** `gpt-5.6-terra` on `/v1/chat/completions`: a body with tools and no `reasoning_effort` answered 400 ("Function tools with reasoning_effort are not supported ... set reasoning_effort to 'none'"); the same body with `"reasoning_effort":"none"` answered 200 and a tool round trip answered 200. `gemini-3.8-flash`: the replayed `functionCall` without its `thoughtSignature` answered 400 ("Function call is missing a thought_signature"); with it, 200. Both break every tool-using turn on a default model, which is this story's intent, so both ride here. The signature is a per-call attribute of the vendor's call part, like the vendor `id` DW-1180 already carries on the canonical `tool_use` block, so it travels the same way and needs no new channel. `claude-opus-5` answered the same probe 200 with and without echo on that call (it returned no reasoning blocks that time), so AC4 stays stub-pinned as planned.

**Ledger inbox:** DW-1590, DW-1591 (routed by the spec gate; addressed by tasks 22 and 23).

**Consumes:** Story 10.1 (`Base`, the canonical shape, `MessageAdapter`), Stories 10.2 and 10.3 (the three adapters, `CatalogProbeShipped`, the stubs), Story 3.x (`AgentRules`, `State/Agent`, the Definition form), and Story 4.x (`Loop.AnswerTools` and the `TurnTools` harness).

**Consumed-by:**

- Story 10.5: Test connection runs the same body path.
- Story 11.7: streaming reads the same `Response` and must keep `ContentJson`'s echo.
- Story 17.7: the owner's live check on each catalog default model.

## Verification

**Slot and instance.** Slot **B**. Every IRIS MCP call carries `server: "ocupilot-slot-b"`. Slot B's dev instance is stale against this branch, so every test, sweep and mutation runs on the throwaway. Bring it up with exactly these values: `bash scripts/ci-throwaway.sh up --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci --web 52777 --super 1976` (container `ocupilot-b-ci`). Never stop, remove, recreate or `down` `ocupilot`, any `ocupilot-slot-*` container, or `ocupilot-ci`. Tear down only a throwaway whose `up` this session ran. Browser runs export `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci`, after `cd ui && npm run build` and `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`. No live provider call and no key, ever.

**Commands:**

- `uv run scripts/check-objectscript.py` and `uv run scripts/test_check_objectscript.py`. Expected: clean.
- Compile the whole `OcuPilot` package on the throwaway (`$System.OBJ.LoadDir` plus `CompilePackage("OcuPilot")`). Expected: no errors. `Anthropic` has three test subclasses, and `OpenAI` has one shipped subclass, all of which hold their own compiled copies.
- `bash scripts/lint-docs.sh`. Expected: clean (EXPERIENCE.md).
- **(loop)** `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class <Class>`, one class per invocation and one invocation per message, with no re-submit on a client-side timeout. Classes: `OcuPilot.Test.AdapterSampling`, `OcuPilot.Test.AnthropicThinking`, `OcuPilot.Test.ProviderSampling`, `OcuPilot.Test.Adapter`, `OcuPilot.Test.AgentRules`, `OcuPilot.Test.Provider`, `OcuPilot.Test.OpenAIAdapter`, `OcuPilot.Test.GeminiAdapter`, `OcuPilot.Test.CompatibleAdapter`, `OcuPilot.Test.AgentViolation`, `OcuPilot.Test.AuditRecord`, `OcuPilot.Test.AgentWire`, `OcuPilot.Test.TurnTools`, `OcuPilot.Test.TurnLoop`. Confirm totals with the `%UnitTest_Result` probe in `.claude/rules/objectscript-testing.md`.
- **(loop)** `cd ui && npm run test:tools && npm run test:components`. Expected: green, including `strings.test.mjs`'s authorized-values and count assertions at 698 literals.
- **(loop)** `cd ui && node --test --test-concurrency=1 browser/definitions.browser-spec.mjs`, with both environment variables set and the bundle redeployed. The full browser suite is CI's `browser` job and is not run locally.
- **(once, before dev_complete)** The full ObjectScript sweep: all 215 classes that extend `%UnitTest.TestCase` under `src/OcuPilot/Test` (count them with `grep -rl 'Extends %UnitTest.TestCase' src/OcuPilot/Test`), run one at a time on `ocupilot-b-ci`. Then `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`. Zero executed checks is a failure.

**Pinning tests and mutations** (Rule 19). Apply each mutation, recompile the package, observe red, revert, and confirm `git status --short` and `git diff --stat` are unchanged. The implement stage fills in the observed run for each line below.

- AC1, server: `ProviderSampling.TestACreateWithNoTemperatureStoresItUnset`. `mutation:` restore `canonicalTemperature` 0 on the openai row, then expect red on the `null` projection. Observed (run 15): red on the openai legs (null projection, stored unset, read-back null); `TestTheProvidersRouteServesBothTemperatureColumns` also red.
- AC1, rule: `AgentRules.TestAnUnsetTemperatureIsAccepted`. `mutation:` drop rule 4's empty arm, then expect red. Observed (run 16): red, both legs refused `AGENT.TEMPERATURE.RANGE`; no other method.
- AC1, client: the page-spec cascade case. `mutation:` `String(row.canonicalTemperature)` with no null check, then expect red (`'null'`). Observed: red, `expected 'null' to be ''`; 47 other cases green.
- AC1, browser: the new definitions case. `mutation:` remove the placeholder binding, rebuild and redeploy, then expect red. Observed: red on the "Not applicable" assertion (placeholder `null`); the six other cases green.
- AC form invariants (DW-1337): the two `freshViolations` assertions in the new definitions case. `mutation:` a stylesheet rule giving `#ocu-definition-temperature-caption` `color: #eeeeee`, rebuilt and redeployed. Observed (review pass): red on the not-applicable state's assertion, `contrast|light|app-definition-form-page>p.ocu-field-caption: 1.12:1 under 4.5:1`; the six other cases green.
- AC2: `AdapterSampling.TestAnUnsetTemperatureIsNotSentToTheOtherFamilies`. `mutation:` `OpenAI.CallMessages` writes `temperature` unconditionally, then expect red on the openai and compatible legs only. Observed (run 17): red on those two legs only. `mutation:` the same in `Gemini`, then expect red on the gemini leg only. Observed (run 18): red on the gemini leg only.
- AC3: `AdapterSampling.TestAnthropicIsSentNoSamplingParameterWhateverTheDefinitionHolds`. `mutation:` restore `Anthropic.cls:51`, then expect red. Observed (run 19): red on all three held values; the agreement test also red on anthropic. Column pin: `mutation:` set anthropic `acceptsTemperature` true, then expect red on the agreement test. Observed (run 20): red on that test alone. Form: `mutation:` drop the not-applicable branch in the page, then expect red on the page-spec Anthropic case. Observed: red on it and on the held-value case (readonly); 46 green. Column, not name (AD-5): page-spec case `the field follows the acceptsTemperature column, never the provider name`. `mutation:` `temperatureApplies()` returns `this.value('provider') !== 'anthropic'`. Observed (review pass): red on that case alone, 48 green.
- AC4: `AnthropicThinking.TestReasoningBlocksReturnUnchangedInTheNextRequest`. `mutation:` delete the `pContentJson` branch in `AnswerTools`, then expect red. Observed (run 21): red, the echo two blocks where four were served. `mutation:` `MapResponse` never sets `ContentJson`, then expect red on the same test and on the `Adapter` leg. Observed: red on both (runs 22, 23).
- AC5: no pinning test by construction. It is a property of the tiers (stubs, no socket), confirmed by the diff and by `ProviderStub`'s transport seam.
- AC6: `ProviderSampling.TestAStoredTemperatureIsKeptThroughAnUpdateAndSent`. `mutation:` `SetTyped` writes `null` for 0 as well as for `""`, then expect red on the projection leg. Observed (run 24): red there, and on the explicit-0 legs. `mutation:` `ValuesFor` maps 0 to `""`, then expect red on the recorded body leg. Observed (run 25): red on that leg alone.
- DW-1590: the `AdapterSampling` openai tools leg. `mutation:` the openai row's `reasoningEffort` emptied, then expect red on that leg only. Observed (run 26): red on the openai leg only. `mutation:` `OpenAI.CallMessages` writes `reasoning_effort` unconditionally, then expect red on the compatible leg only. Observed (run 27): red on the compatible leg only.
- DW-1591: the Gemini signature leg. `mutation:` `CanonicalToGemini` omits `thoughtSignature`, then expect red. Observed (run 28): red, and the round-trip leg too. `mutation:` `GeminiToCanonical` drops it, then expect red on the same leg. Observed (run 29): red on the same leg and the round-trip leg.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** Temperature is optional end to end: catalog rows declare `canonicalTemperature` `null` and a new `acceptsTemperature` column; `State/Agent.Temperature` has no InitialExpression; rule 4 accepts empty; OpenAI, Gemini and compatible send `temperature` only when set; Anthropic sends no sampling parameter. `Anthropic.MapResponse` keeps a reasoning reply's content in `Response.ContentJson`, and `Loop.AnswerTools` echoes it verbatim. DW-1590: a `reasoningEffort` row column (`none` on openai) sent as `reasoning_effort`. DW-1591: a Gemini `thoughtSignature` rides the canonical `tool_use` block and is written back beside the replayed call. The Definition form shows "Provider default" where the row takes a temperature, and a readonly, `aria-disabled`, captioned "Not applicable" field where it does not.

**Files.**

- `src/OcuPilot/Kernel/Provider/{Catalog,Anthropic,OpenAI,Gemini,MessageAdapter,Response,Base}.cls` -- the two columns, the conditional sends, the reasoning content, the signature round trip, docs.
- `src/OcuPilot/Kernel/State/Agent.cls`, `Kernel/AgentRules.cls`, `Port/ProviderPort.cls`, `Api/Definitions.cls` -- unset stored, accepted, passed through, projected `null`; `acceptsTemperature` served.
- `src/OcuPilot/Kernel/Agent/Loop.cls` -- the `AnswerTools` echo branch and its call site (footprint extension).
- `src/OcuPilot/Test/{AdapterSampling,AnthropicThinking,ProviderSampling}.cls` -- new; `Test/{Adapter,AgentRules,Provider,OpenAIAdapter,GeminiAdapter,CompatibleAdapter}.cls` -- pins updated; `Test/AgentViolation.cls:214`, `Test/AuditRecord.cls:198` -- one literal each.
- `ui/src/app/areas/agent/definition-form.{store,page,page.spec}.ts`, `ui/browser/definitions.browser-spec.mjs`, `ui/src/app/core/strings.ts` (three keys), `EXPERIENCE.md` (one row).

**Review.** Two layers (verification-gap, intent-alignment), 18 findings: 3 patched (1 medium: a column-versus-name page-spec case; 2 low: the DW-1337 caption mutation recorded, a self-referential assertion deleted), 1 deferred (stale `AgentViolation` message), 14 rejected with reasons in the Review Triage Log. Follow-up review: not recommended (one medium patched, no high).

**Verification.** On `ocupilot-b-ci`: the full sweep once before review, 217 classes, 1948 tests, 0 failed (runs 30-246, confirmed by the `%UnitTest_Result` probe); after the review patch, `AnthropicThinking` 4/0 (run 247); smoke 49/49. `check-objectscript.py` 0 problems, its harness 128 OK, `lint-docs.sh` clean. `test:tools` 1370/1370, `test:components` 1040/1040. `definitions.browser-spec.mjs` 7/7 on a rebuilt, redeployed bundle. Every AC mutation observed red and reverted (see Verification).

**Deviations and residual risks.**

- The EXPERIENCE.md row is at the end of the Fixed-strings table (line 465), not below `:336` (task 16): `strings.test.mjs` pins every `EXPERIENCE.md:n` reference, so an insertion at 337 would re-point every reference below it. The in-document `` `:n` `` references to lines past 464 are now one line off; nothing checks them.
- A definition saved with 0 before this story keeps sending 0 to OpenAI until an operator empties the field (AC6, accepted in Design Notes).
- The live proof on each catalog default model stays the owner's Story 17.7 check.
