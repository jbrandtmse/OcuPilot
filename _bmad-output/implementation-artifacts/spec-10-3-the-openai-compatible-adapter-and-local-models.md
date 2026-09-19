---
title: 'Story 10.3: The OpenAI-compatible adapter, and local models'
type: 'feature'
created: '2026-09-19'
status: 'done'
baseline_revision: 'e4f7a39b767cc1c15d98a3c295fcad9018dd632a'
baseline_commit: 'e4f7a39b767cc1c15d98a3c295fcad9018dd632a'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized', 'epic5-dependency']
deferred:
  - summary: >-
      A PUT of a key against a definition whose credType is none is not refused, so a secret can be
      written to a credential entry that nothing ever reads.
    evidence: |-
      Api/Definitions.CredentialRefusal refuses the write for credType env
      (AGENT.CREDENTIAL.ENVUNWRITABLE) and has no arm for none, so the ladder falls through to the
      rung, privilege and shape checks and the store write proceeds. Largely mitigated in this pass:
      AgentRules.Normalize now clears both credential references for none, so a keyless row names no
      entry to write to. The clean refusal needs a violation code with its own published sentence,
      which this spec does not settle.
    location: >-
      src/OcuPilot/Api/Definitions.cls:1031
    severity: medium
  - summary: >-
      A definition may be marked local while naming a public endpoint, and LeavesInstance then
      answers 0, so the context chip states no egress for a call that leaves the instance.
    evidence: |-
      LeavesInstance's first line is "If pMarkedLocal Quit 0", and AgentRules validates markedLocal
      only against the row's allowsLocal column, never against the endpoint's resolved kind. Both
      predate this diff and are pinned by the unchanged
      ContextBound.TestLeavesInstanceClassification; what is new is that compatible is the first
      shipped row where the flag can be set at all. Settling it means deciding in AD-42 whether the
      declaration is authoritative -- refusing an unresolvable host would break this story's own
      private-DNS case, which is the reason the declaration exists.
    location: >-
      src/OcuPilot/Kernel/Egress.cls (LeavesInstance), src/OcuPilot/Kernel/AgentRules.cls (Validate)
    severity: medium
  - summary: >-
      ResolveEndpoint's marked-local proxy blanking has no independent pinning assertion.
    evidence: |-
      Reverting it alone reddens nothing, because Egress.LeavesInstance reads pMarkedLocal first and
      short-circuits, and its only non-test caller (Api/Context.cls) passes the value straight
      through. Settled by two legs on ResolveEndpoint's own pProxyHost output -- blank for a
      marked-local definition with a proxy stored, the proxy host for the same definition unmarked.
      Worth doing at the next touch of that method.
    location: >-
      src/OcuPilot/Port/ProviderPort.cls:353
    severity: low
  - summary: >-
      The plain-HTTP acknowledgment is not re-applied at call time.
    evidence: |-
      AgentRules.SchemeAccepted gives pHttpAcknowledged a default of 1 and ProviderPort.Dispatch
      calls the three-argument form, while ValuesFor never loads HttpAcknowledged into pValues.
      Unreachable through the API today: Validate refuses the configuration on write, and
      HttpAcknowledged is a security field, so it cannot be turned off while it is needed. Threading
      it through adds a parameter for a state no request can reach; what would settle it is a stored
      row carrying credType creds, a plain-http endpoint and HttpAcknowledged 0, which only a
      GuardedCreate bypassing AgentRules can produce.
    location: >-
      src/OcuPilot/Kernel/AgentRules.cls (SchemeAccepted), src/OcuPilot/Port/ProviderPort.cls:252
    severity: low
  - summary: >-
      A self-hosted OpenAI-compatible server answering a string error member yields an empty
      detail.providerText.
    evidence: |-
      Base.ProviderMessage reads error.message and quits when error is not an object, so a body
      shaped {"error": "text"} carries no provider text. The compatible family is any endpoint an
      operator names rather than a vendor with a published contract, and widening the shapes read
      needs evidence of what such servers actually answer -- which no permitted verification can
      obtain, since DW-1200 forbids a live provider call. The overreaching doc claim was corrected
      at its origin in this pass; the behavior stands.
    location: >-
      src/OcuPilot/Kernel/Provider/Base.cls (ProviderMessage)
    severity: low
  - summary: >-
      Three prose claims that SecurityFields() names six properties are stale now that it names
      seven.
    evidence: |-
      Test/DefinitionsFieldGapProbe.cls:5, Test/AgentSchema.cls and Test/AgentState.cls each say six
      in a doc comment. None is an assertion, so no pin reddens and the suite stays green; all three
      are Epic 5's files, and the standing mechanical-pin grant covers a pin a shipped surface
      reddens, not a comment. Needs Epic 5's owner or the range-end cleanup story.
    location: >-
      src/OcuPilot/Test/DefinitionsFieldGapProbe.cls:5
    severity: low
  - summary: >-
      deferred-work.md calls DW-1175 a duplicate of DW-1169 while its own status line still reads
      routed, so the Rule 17 drain will pick it up again as work.
    evidence: |-
      The appended note records the orchestrator's ruling but neither appended progress line carries
      a status= field, unlike every sibling line in both entries. Ledger hygiene the burn-down gate
      owns rather than this story.
    location: >-
      _bmad-output/implementation-artifacts/deferred-work.md
    severity: low
---

<intent-contract>

## Intent

**Problem:** OcuPilot ships three cloud provider families. A change-controlled site that will not let screen data or log text leave the instance has no option: every shipped catalog row sets `allowsLocal` false, plain HTTP is refused unless a definition is marked local, and a definition cannot be saved with no credential at all, so a keyless model on the operator's own network cannot be configured.

**Approach:** Append a fourth catalog row, `compatible`, whose adapter reuses Story 10.1's OpenAI message and tool-definition pair unchanged and differs only in endpoint normalization, optional-or-absent auth, and being the first shipped row to set `allowsLocal` true. Represent "no credential" as a third `credType`, tighten the plain-HTTP rule so a credential crossing it needs a stored acknowledgment, and make `LeavesInstance` compute from the configuration the request actually uses now that a marked-local call bypasses the proxy.

## Boundaries & Constraints

**Always:** A family is one catalog row plus one adapter — the agent loop, tool registry, proposal lifecycle and every screen stay untouched. The row is **appended**, never prepended. The adapter reuses `MessageAdapter.CanonicalToOpenAi` / `OpenAiToCanonical` and `ToolDefAdapter.ToOpenAi` verbatim; the locked JSON-Schema subset is not relaxed. No credential ever reaches a local, a status, a log line, a URL or a trap (AD-35). Never-throw discipline and the shared retry, backoff and timeout rules are `Base`'s, not the adapter's. Plain HTTP and a local address are licensed only by the definition's own `MarkedLocal` together with the row's `allowsLocal`; the link-local range keeps no escape.

**Never:** No live provider call in any verification, ever — not a probe, not a mutation (orchestrator ruling 2026-09-19, DW-1200). No edit to `ui/src/app/core/**`, `ui/browser/context-chip.browser-spec.mjs`, `Api/Context.cls`, or any `Test/**` class outside this story's own footprint. No new `/agent/providers` catalog column and no hand-written Storage section. No key-shape grammar for this family — the vendors publish none.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Keyless local call | shipped `compatible` row; `credType` `none`; `EndpointUrl` `http://127.0.0.1:11434/v1`; `MarkedLocal` 1 | `keySource` resolves `none`; no `Authorization` header on the request at all; canonical `Response` with text and stop reason | No error expected |
| Endpoint normalization | stored endpoint `http://host:11434/v1` (or with a trailing `/`) | POST goes to `http://host:11434/v1/chat/completions`, scheme and authority unchanged | An override answering another authority or `""` → `PROVIDER.EGRESS`, zero calls |
| Endpoint already complete | stored endpoint ends `/chat/completions` | POST goes to it unchanged — no second path segment appended | No error expected |
| Plain HTTP with a stored credential, unacknowledged | `credType` `creds`; `http://` endpoint; `MarkedLocal` 1; `HttpAcknowledged` 0 | save refused | one violation `{field: "httpAcknowledged", code: AGENT.HTTP.ACK.REQUIRED}` |
| Plain HTTP with a stored credential, acknowledged | same, `HttpAcknowledged` 1 | save accepted; definition disabled until Test connection passes again | No error expected |
| Loopback named without the local declaration | `http://127.0.0.1:11434/v1`; `MarkedLocal` 0 | save refused | `{endpointUrl, AGENT.ENDPOINT.ADDRESS}` |
| Link-local metadata address | `https://169.254.169.254/v1`; `MarkedLocal` 1; `allowsLocal` 1 | save refused — the range has no escape | `{endpointUrl, AGENT.ENDPOINT.LINKLOCAL}`; at call time `PROVIDER.EGRESS` |
| Private-network endpoint | `https://10.0.0.5/v1`; `MarkedLocal` 1 | permitted; `leavesInstance` answers false | No error expected |
| Marked-local endpoint with a proxy configured | `State.Egress` holds a proxy host; definition `MarkedLocal` 1 | request carries no proxy server, port or tunnel; `LeavesInstance` answers 0 | No error expected |
| `credType` `none` on a family that forbids it | `provider` `anthropic`, `credType` `none` | save refused | `{credType, AGENT.CREDTYPE.UNKNOWN}` |
| OpenAI refusal reply | `choices[0].message.content` null, `refusal` non-empty, `finish_reason` `stop` | canonical text is the refusal; stop reason `refusal` | No error expected |
| Gemini prompt-level block | 200 carrying only `promptFeedback.blockReason`, no candidates | stop reason `refusal`, the block reason as the provider's text | Not a `PROVIDER.TRANSPORT` fault |
| Vendor error body whose `error.message` is not a string | `{"error":{"message":{...}}}` | `detail.providerText` is empty | Never the literal `N@%Library.DynamicObject` |

</intent-contract>

## Code Map

- `src/OcuPilot/Kernel/Provider/Catalog.cls:55-57` -- `XData Providers`; the three shipped rows and the fourteen columns. Append the fourth row after `gemini`. `Catalog.cls:9-16` states that no shipped row exercises `endpointRequired` or `allowsLocal` -- correct that at its origin.
- `src/OcuPilot/Kernel/Provider/OpenAI.cls` (119 lines) -- the class the new adapter is closest to. `ApplyAuth` at `:75-79` is the omit-when-empty shape to copy; `CallMessages` `:45-68` and `MapResponse` `:95-98` delegate to the shared pair and are reused as they stand.
- `src/OcuPilot/Kernel/Provider/Base.cls:140-185` -- `Invoke`'s key ladder. `keySource` defaults to `KEYSOURCESTORED`; a source that is neither `stored` nor `body` resolves nothing, skips `IsApiKeyShapeValid` and sends no key header (`:174-181`). `KEYSOURCENONE` is declared at `:51`. **`KeyShapeAccepted` (`:599-604`) needs no change** -- with `keySource` `none` it is never called.
- `src/OcuPilot/Kernel/Provider/Base.cls:337-340` `RequestUrl` (concrete, returns the stored endpoint), `:230-245` `Attempts`' origin check, `:349-365` `OriginOf` (authority compared as written, port included), `:376-398` `NewRequest` (proxy set from `pSettings` at `:392-395`), `:535` `ProviderMessage` (abstract).
- `src/OcuPilot/Kernel/Provider/{Anthropic,OpenAI,Gemini}.cls:165-178, 104-117, 149-162` -- three byte-identical `ProviderMessage` bodies; each reads `error.message` untyped (`:173`, `:112`, `:157`). DW-1193.
- `src/OcuPilot/Kernel/Provider/MessageAdapter.cls:201-261` `OpenAiToCanonical` (`content` at `:222`, `finish_reason` at `:252`, no `refusal` read anywhere), `:369-423` `GeminiToCanonical` (`:375-376` the no-candidates error, no `promptFeedback` read), `:59` `OPENAISTOPREASONS` (5 entries), `:69` `GEMINISTOPREASONS` (**11 entries, 9 of them `refusal`** -- counted from the parameter, not from prose). DW-1202.
- `src/OcuPilot/Kernel/Egress.cls:558-563` `LeavesInstance` -- tests the proxy **before** `pMarkedLocal`. `:204-220` `IsPermitted`, `:113-141` `Classify` (`pKind` one of public / loopback / linklocal / instance / unresolvable), `:447-454` `IsLinkLocal` (`169.254.0.0/16`, `fe80::/10`), `:541-552` `IsPrivate` (RFC 1918 plus `fc00::/7`).
- `src/OcuPilot/Kernel/AgentRules.cls:142-152` credential rules (`CREDTYPEENV`/`CREDTYPECREDS` at `:29,:34` -- exactly two accepted today), `:160-180` the endpoint block, `:284-288` `SchemeAccepted`, `:257-264` `AddressViolation`, `:271-275` `AllowsLocal`.
- `src/OcuPilot/Kernel/State/Agent.cls:33-120` properties (`MarkedLocal` `:48-55` already exists; there is no acknowledgment flag), `:138-141` `SecurityFields`, `:122-124` the two unique indexes. `SCHEMAVERSION` lives on `Install/Installer.cls:68` (value 1), not here.
- `src/OcuPilot/Port/ProviderPort.cls:220-309` `Dispatch` (row selected by `adapterClass` at `:226`; proxy judged `:265-271`; TLS forced by scheme `:272-296`; **no proxy bypass exists**), `:373-397` `ValuesFor` (**does not set `keySource`**), `:319-345` `ResolveEndpoint` (answers `pProxyHost` unconditionally).
- `src/OcuPilot/Api/Definitions.cls:104-106` `Fields()`, `:199-202` `ProviderColumns()` (twelve columns), `:812` where Test connection chooses `keySource`.
- `src/OcuPilot/Api/Error.cls:1097-1106` the endpoint and local-unsupported reasons; the violation codes sit at `:431-460`.
- `src/OcuPilot/Test/AgentRules.cls:131,:147` the two pins of `Keys()` = `anthropic,openai,gemini`; `:155,:174` `AssertRowPinned` asserts `allowsLocal` **0 for every row**. `UNKNOWNPROVIDER` is `nosuchprovider` (`:30`) -- no collision.
- `src/OcuPilot/Test/{CatalogProbeShipped,OpenAIAdapter,OpenAIStub,AdapterProvider}.cls` -- the reviewed pattern for driving a shipped row through `ProviderPort` with only the transport swapped. `Test/Egress.cls:8` notes it must use the `probe-local` row because no shipped row allows local -- correct at origin.
- **Read-only, Epic 5's, and load-bearing:** `src/OcuPilot/Api/Context.cls:110-113` is where `leavesInstance` is computed and projected (**not** `Api/Definitions.cls`) -- it calls `ProviderPort.ResolveEndpoint` then `Egress.LeavesInstance`, so fixing those two makes AC4 true with no edit here. `src/OcuPilot/Test/AgentWire.cls:113` pins the definition projection's key set **exactly**. `src/OcuPilot/Test/AgentViolation.cls:212` pins the `/agent/providers` column set **exactly** -- which is why no catalog column is added; `:207` derives the row count and `:213` pins row 0 as `anthropic`, both satisfied by appending.
- `ui/src/app/areas/agent/definition-form.store.ts:28-46` `ProviderRow` (already reads `allowsLocal`), `:52-73` `WRITABLE_FIELDS` (already sends `markedLocal`, with **no control rendering it**), `:752-764` `applyProviderDefaults`. `definition-form.page.ts:191-204` the endpoint field -- the new controls go directly below it.
- `ui/src/app/shell/context-chip.ts:187-190` -- the pill is `leavesInstance() === true`, so `false` renders nothing. **No client change is needed for AC4.**
- `ui/tools/strings.test.mjs:455-498` -- `strings.ts` may hold **nothing** EXPERIENCE.md does not authorize, and `REQUIRED_ALONGSIDE_TABLE` is explicitly not to be extended. `EXPERIENCE.md:334` is the Definition form's Fixed-strings row; `:403` defines the egress treatment as `{colors.egress-warning}` on `{colors.egress-warning-container}`; `:761` is AC4's own source sentence.
- `README.md:28-33` -- already names "any OpenAI-compatible endpoint, including local models"; it carries neither the privacy framing nor the tool-call caveat AC5 requires.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Kernel/Provider/Catalog.cls` -- append the `compatible` row after `gemini`: `label` `OpenAI-compatible`, `defaultModel` and `modelSuggestions` empty (no vendor publishes a default; the model is always operator-supplied), `defaultEndpoint` empty with `endpointRequired` true, `canonicalMaxTokens` 32000, `canonicalTemperature` 0, `defaultEnvVarName` `OPENAI_COMPATIBLE_API_KEY`, `defaultCredentialName` `OcuPilotCompatible`, `keyPrefix` empty, `adapterClass` `OcuPilot.Kernel.Provider.Compatible`, `allowsLocal` **true**, `authVersion` empty. Correct the class doc's "no shipped row exercises `allowsLocal`" at its origin.
- `src/OcuPilot/Kernel/Provider/Compatible.cls` -- new. `ProviderName` `compatible`; `CallMessages`, `MapResponse` and the tool path delegate to the shared OpenAI pair unchanged; `ApplyAuth` writes `Authorization: Bearer <key>` only when a key is present and otherwise writes nothing; `IsApiKeyShapeValid` answers `..KeyShapeAccepted()`; `RequestUrl` appends `/chat/completions` when the stored endpoint's path does not already end in it, tolerating one trailing slash and leaving scheme and authority byte-identical so `Base.Attempts`' origin check passes.
- `src/OcuPilot/Kernel/Provider/Base.cls` -- make `ProviderMessage` concrete: parse once, and read `error.message` only when `%GetTypeOf("message")` is `string`, answering `""` otherwise. Closes DW-1193's OREF defect for all four families.
- `src/OcuPilot/Kernel/Provider/{Anthropic,OpenAI,Gemini}.cls` -- delete the three duplicated `ProviderMessage` overrides.
- `src/OcuPilot/Kernel/Provider/MessageAdapter.cls` -- DW-1202: in `OpenAiToCanonical`, read a string `message.refusal` as the reply text and map the stop reason to `refusal` when one is present; in `GeminiToCanonical`, read a top-level `promptFeedback.blockReason` when `candidates` is empty or absent and answer `refusal` with that reason as the provider's text rather than the no-candidates error; add `IMAGE_SAFETY:refusal` to `GEMINISTOPREASONS`, taking it to **12 entries, 10 of them `refusal`**, and correct the doc comment's count at its origin.
- `src/OcuPilot/Kernel/Egress.cls` -- reorder `LeavesInstance` so `pMarkedLocal` is tested **before** the proxy host. A marked-local call no longer crosses the proxy, so counting it would make the chip disagree with the request by construction (DW-441, AD-42).
- `src/OcuPilot/Kernel/State/Agent.cls` -- add `HttpAcknowledged As %Boolean [ InitialExpression = 0 ]` and include it in `SecurityFields()`. Carry the "Added with no `SCHEMAVERSION` move" doc comment the Consistency Conventions require, as `State/Turn.cls:88` does.
- `src/OcuPilot/Kernel/AgentRules.cls` -- add `CREDTYPENONE = "none"`, accepted by Rule 5 only when `AllowsLocal(provider)` and requiring neither `envVarName` nor `credentialName`. Extend `SchemeAccepted` so plain HTTP additionally needs `credType` `none` or `HttpAcknowledged`, emitting the new violation on field `httpAcknowledged`.
- `src/OcuPilot/Api/Error.cls` -- add `AGENTHTTPACKREQUIRED` (`AGENT.HTTP.ACK.REQUIRED`) and its reason: one sentence saying the key would cross the network unencrypted and the acknowledgment is what accepts that.
- `src/OcuPilot/Port/ProviderPort.cls` -- `ValuesFor` sets `keySource` to `KEYSOURCENONE` when `credType` is `none`; `ResolveEndpoint` answers `pProxyHost` `""` for a marked-local definition; `Dispatch` blanks `proxyServer`, `proxyPort`, `proxyHttps` and `proxyTunnel` in the settings it hands `NewRequest` when the endpoint is marked local, beside the existing scheme-driven TLS handling.
- `src/OcuPilot/Api/Definitions.cls` -- add `httpAcknowledged` to `Fields()` as a writable boolean; make Test connection choose `keySource` `none` for a `none` `credType` with no body key.
- `src/OcuPilot/Test/CompatibleAdapter.cls`, `src/OcuPilot/Test/CompatibleStub.cls` -- new, following `Test/OpenAIAdapter` and `Test/OpenAIStub`: drive the **shipped** `compatible` row through `ProviderPort.Invoke` with only the transport swapped, covering the keyless call, both normalization rows and the absent auth header.
- `src/OcuPilot/Test/CatalogProbeShipped.cls` -- re-adapt the `compatible` row onto `Test/CompatibleStub` alongside the two it already re-adapts, keeping every other shipped column.
- `src/OcuPilot/Test/AgentRules.cls` -- update both `Keys()` pins to the four appended rows in order; give `AssertRowPinned` an expected `allowsLocal` so the fourth row's `true` is pinned rather than contradicted, and correct the "`allowsLocal` false for every row" doc at its origin; add the `credType` `none` acceptance and refusal legs.
- `src/OcuPilot/Test/Egress.cls` -- pin the AC3 matrix against the **shipped** `compatible` row rather than the `probe-local` probe, and pin the reordered `LeavesInstance` including the marked-local-with-proxy row.
- `src/OcuPilot/Test/EgressLocal.cls` -- new: read-only over `Api.Context.Body`, asserting that a marked-local `compatible` definition answers `provider`, `endpointHost` and `leavesInstance` **false**, with a proxy configured and without.
- `src/OcuPilot/Test/Adapter.cls` -- add the three DW-1202 reply rows and the DW-1193 non-string `error.message` row.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` -- add the Definition form's three new literals to the Fixed-strings row at `:334` with their `Where` note: the local-model control, the no-API-key credential option, and the plain-HTTP acknowledgment sentence shown in the egress treatment. Declared footprint extension (see Design Notes).
- `ui/src/app/core/strings.ts` -- append the three keys beside `agentDefinitionFieldEndpoint`. Append only: never reorder, rename or reflow.
- `ui/src/app/areas/agent/definition-form.{page.ts,store.ts}` -- render, immediately below the endpoint field and gated on `store.provider()?.allowsLocal === true`, a local-model control bound to `markedLocal`; add the no-API-key option to the credential-type choice, gated the same way; and render the acknowledgment control bound to `httpAcknowledged` in the egress treatment, shown when the endpoint is plain HTTP and a credential is configured.
- `ui/browser/definitions.browser-spec.mjs` -- add a case that picks the OpenAI-compatible provider, fills a loopback `http://` endpoint, ticks the local-model control, saves with no key, and asserts the definition is accepted with no endpoint violation.
- `README.md` -- extend the provider paragraph so small local models are presented as the privacy option, with the caveat that the write path needs a model capable of reliable multi-field tool calls.
- Unit-test every I/O matrix row in the classes named above.

**Acceptance Criteria:**

- **Integration (Rule 1).** Given the shipped `compatible` catalog row and a stored definition naming it, when `OcuPilot.Port.ProviderPort.Invoke` runs with only the transport substituted, then the port resolves the row's own `adapterClass`, issues one POST to the normalized endpoint with no `Authorization` header, and returns a canonical `Response` -- observed through the port, never by reading the adapter's own state.
- Given a fourth family is added, when the diff is reviewed, then it touches no part of the agent loop, the tool registry, the proposal lifecycle or any screen -- only a catalog row, one adapter, the shared rules the ledger entries name, the definition form and its strings.
- Given the catalog, when `Keys()` is read, then `anthropic` is still first and `compatible` is last.
- Given a definition whose `provider`, `endpointUrl`, `markedLocal`, `credType` or `httpAcknowledged` changes, when it is saved, then it is disabled until Test connection passes again.
- Given the README, when it describes providers, then it presents small local models as the privacy option and states the multi-field tool-call caveat.

- [x] [Review] The three contended pins are GRANTED (orchestrator, 2026-09-19) and the edits already
  in the tree stand: `Test/AgentViolation.cls:47,:90` (the error-code count, under the widened
  standing grant for pins that count or enumerate a surface this epic ships),
  `Test/ContextBound.cls:220`, and the additive `.ocu-field-egress` rule in
  `ui/src/styles/_components.scss`. Report each under footprint extensions with its line and the
  forcing surface.
- [x] [Review] **Condition on the `ContextBound` flip: the new assertion must name `DW-441`** -- in
  its message or a one-line comment beside it. Flipping an expected value is exactly what makes a
  red suite go green, and the diff alone cannot later tell a decided change from a convenient one.
  The message already says why; the id says who decided it and when. This applies to every
  expectation flip from here, not only this one.
- [x] [Review] Re-demonstrate **both halves** of DW-1214's mutation on a **fresh** throwaway, since
  the repair touches `Egress` again and the previous observation was lost with its container:
  `fd00:ec2::254`, `fd20:ce::254` and the mixed-case expanded spelling refused while marked-local,
  **and** `fd12:3456:789a::1` still permitted while marked-local. The second half is the one that
  matters -- a guard refusing both would look identical to a working one.

## Spec Change Log

## Review Triage Log

### 2026-09-19 -- Review pass

- verdicts: 44 findings -- high 0, medium 21, low 15, false 8, maybe-false 0. The
  intent-alignment layer's twelve enumerated readings are descriptive by its own brief and are not
  findings; the divergences it filed that are findings appear below, grouped with the layer that
  filed them first.
- findings:
  - `[medium]` `[patch]` `AgentRules.Normalize` has no `none` arm, so a keyless definition keeps the credential references the form filled in -- verified at `Kernel/AgentRules.cls`: the method branches on `env` and `creds` only, and its own doc excused clearing neither for an *unrecognized* type, which `none` is not. Fixed: a `none` arm clearing both, the doc sentence, and a `none` leg in `TestTheCredentialInvariantNormalizesInBothDirections`.
  - `[medium]` `[patch]` (same root cause) `definition-form.page.ts`'s `onNoKey` comment claimed "the server's own XOR invariant normalizes" the references -- it did not, for this value. Corrected at origin.
  - `[medium]` `[defer]` (same root cause) `Api/Definitions.CredentialRefusal` refuses a key write for `credType` `env` but has no `none` arm, so a key PUT against a keyless definition writes a secret nothing reads -- verified at `Api/Definitions.cls:1031`. Largely mitigated by the patch above; the clean refusal needs a violation code this spec does not settle.
  - `[medium]` `[patch]` `onNoKey` unticked forced `credType` to `creds`, silently changing an `env` definition's rung on a control that never rendered it. Fixed: the displaced rung is remembered and restored.
  - `[medium]` `[patch]` `showHttpAcknowledge` was not gated on `localAllowed`, so a vendor row offered a control that cannot clear the refusal it will get (`AGENT.ENDPOINT.SCHEME`, on `endpointUrl`) -- verified against `AgentRules.SchemeAccepted`. Fixed, with the reason at the getter.
  - `[medium]` `[patch]` (Rule 19) no test in any tier rendered the acknowledgment control: the browser leg ticks the keyless choice first, so the getter is false when it asserts, and every provider fixture in `definition-form.page.spec.ts` set `allowsLocal` false. Inverting the getter to `false` reddened nothing. Fixed: a `LOCAL_PROVIDERS` fixture and three component cases.
  - `[medium]` `[patch]` (Rule 19) the store's provider cascade clear-down only ever ran with nothing to clear, so deleting it reddened nothing while shipping a form whose Save is refused on two fields it renders no control for. Fixed by the third new component case.
  - `[medium]` `[patch]` (Rule 19) `Api/Definitions.KeySourceFor`'s `none` return and `KeySourceIsTheStoredOne`'s second arm had no test host at all, and the second is what lets a keyless definition be verified and so enabled -- confirmed by search: no test referenced either. Fixed by a new pin, both mutations demonstrated (runs 139, 138).
  - `[medium]` `[patch]` (Rule 19) `HttpAcknowledged`'s membership of `SecurityFields()` was asserted nowhere, so the one edit that widens the definition's egress was also the one edit that would not disable it. Fixed in the same pin.
  - `[medium]` `[patch]` (Rule 19) `CompatibleAdapter.TestABaseEndpointIsNormalizedAndAnAuthorityChangeIsRefused` had no authority-change and no empty-URL leg, so its name claimed coverage it did not hold. Fixed: a leg driving `RequestUrl` to `""` and observing `PROVIDER.EGRESS` with zero calls, and the doc now names where the authority arm is pinned.
  - `[medium]` `[patch]` `Test/CompatibleAdapter.StoredDefinition` wrote a row the write path refuses -- plain http, keyed rung, no acknowledgment -- so the family's integration AC ran on a configuration no operator can store. Fixed: the fixture sets `HttpAcknowledged`.
  - `[medium]` `[patch]` `Test/Egress.cls`'s `OnAfterOneTest` deleted the instance's outbound-settings row after every one of 23 methods, only one of which writes it, so running any single method removed state a developer cares about. Fixed: the teardown is scoped by a flag the writing method sets.
  - `[medium]` `[patch]` `Test/EgressLocal.cls` took the instance's default-agent marker and never restored it. Fixed: the displaced id is recorded and put back.
  - `[medium]` `[patch]` `Test/CatalogProbe.cls`'s "no shipped provider row exercises either column" is falsified by the `compatible` row on both counts, and correcting that claim at its origin was a Task the previous pass applied to `Catalog.cls` only. Fixed at origin.
  - `[medium]` `[patch]` `Compatible.RequestUrl` compared the completions suffix case-sensitively and tolerated exactly one trailing slash, so `.../V1/CHAT/COMPLETIONS` gained a second operation segment and `.../v1//` reached the wire doubled. Fixed: case-blind comparison and a full collapse that never touches the authority, with legs for both.
  - `[medium]` `[patch]` (Rule 19) `Adapter.TestAGeminiPromptBlockIsARefusalNotATransportFault`'s `[ "PROVIDER.TRANSPORT" = 0` assertion cannot fail while the status is `$$$OK`. Fixed: the discriminating assertion is now that the blocked body's outcome differs from the unreadable body's.
  - `[medium]` `[patch]` `Test/Egress.TestAMarkedLocalCallCarriesNoProxy` asserted server, tunnel and TLS flag but not `proxyPort`, which the intent names and the stub records. Fixed, with the control leg asserting the unmarked call does carry it.
  - `[medium]` `[patch]` `Base.ProviderMessage`'s doc claimed "all four vendors answer an error body shaped `{error: {message}}`" -- the fourth family is any endpoint an operator names, not a vendor. Corrected at origin; the shape question is deferred.
  - `[medium]` `[defer]` a `compatible` definition may be marked local while naming a public endpoint, and `LeavesInstance` answers 0, so the chip states no egress for a call that leaves -- verified. The short-circuit and the absent cross-check both predate this diff, pinned by the unchanged `ContextBound.TestLeavesInstanceClassification`; what is new is that `compatible` is the first shipped row where the flag can be set. An AD-42 amendment, and refusing an unresolvable host would break this story's own private-DNS case.
  - `[medium]` `[patch]` `Adapter.TestEveryGeminiStopReasonMapsAndImageSafetyIsARefusal` asserted a population from its own map -- the project's named generalize-from-one-probe pitfall. Fixed: the doc says the count pins the map, not the vendor's vocabulary, labeled `(inference)`.
  - `[medium]` `[patch]` `MessageAdapter.OpenAiToCanonical` drops partial content when a refusal is present, deliberately and pinned, but nothing said so. Stated at the statement.
  - `[low]` `[patch]` `Api/Definitions.KeySourceFor`'s `none` rung is decided after the body key and the doc read as unconditional. Corrected, and the precedence is now asserted.
  - `[low]` `[patch]` `ProviderPort.Dispatch`'s `IsHttps` term inside the proxy block no longer discriminates on any permitted configuration, and the mutation that covered it was replaced. Kept rather than deleted, with its new status stated at it.
  - `[low]` `[patch]` `Kernel/AgentRules.cls` and `Test/AgentRules.cls` class headers dropped the count they stated and left a sentence that does not parse. Both corrected.
  - `[low]` `[patch]` the README's local-model capability sentence is an inference no permitted verification can measure, presented as fact. Labeled `(inference)` where it is made.
  - `[low]` `[defer]` `ResolveEndpoint`'s marked-local proxy blanking has no independent pin -- reverting it alone reddens nothing, because `LeavesInstance` short-circuits first. Two legs on its own outputs belong at the next touch of that method.
  - `[low]` `[defer]` the acknowledgment is not re-applied at call time: `SchemeAccepted`'s `pHttpAcknowledged` defaults to 1 and `ValuesFor` never loads it. Unreachable through the API, because `Validate` refuses the configuration on write and the field is a security field, so it cannot be turned off while it is needed.
  - `[low]` `[defer]` a self-hosted server answering `{"error": "text"}` yields an empty `detail.providerText`. Widening the shapes read needs vendor evidence no permitted verification can obtain (DW-1200), so the doc was corrected instead.
  - `[low]` `[defer]` three prose claims that `SecurityFields()` names six properties are stale. All three are Epic 5's files, none is an assertion, so no pin reddens and the mechanical-pin grant does not cover the edit.
  - `[low]` `[defer]` `deferred-work.md` calls DW-1175 a duplicate of DW-1169 while its own `status=` line still reads `routed`, so the Rule 17 drain will pick it up again. Ledger hygiene the burn-down gate owns.
  - `[false]` `[reject]` "`IsMetadataAddress`'s every-spelling claim fails for its IPv4 entries; `[0:0:0:0:0:ffff:a9fe:a9fe]` classifies public" -- refuted by probing the instance: every spelling that is a valid URL host classifies `linklocal`, because `Egress.Canonical` folds the IPv4-mapped and `::a.b.c.d` forms to a dotted quad before the comparison. The only `unresolvable` answers came from malformed inputs, themselves refused with no escape.
  - `[false]` `[reject]` "the README edit deleted 'including local models', so the paragraph a reader hits first no longer names local models" -- refuted by the diff: the very next sentence is headed "The OpenAI-compatible option is the privacy option" and names Ollama, vLLM and LM Studio, which is AC5's requirement stated more strongly than before.
  - `[false]` `[reject]` "`ui/src/app/core/strings.ts` is on the Never list and was edited" -- the dispatch's footprint carries an explicit shared-append exception for that file. The three keys are appended and nothing else in it moved.
  - `[false]` `[reject]` "`Test/ProviderProxy.cls`'s expectation flips were not among the three the grant enumerated" -- that file is `Test/Provider*.cls`, inside this story's own footprint, so no grant was needed; both flips name DW-441 in their own text.
  - `[false]` `[reject]` "the Gemini prompt-block path should surface `blockReasonMessage` rather than the enum token" -- the matrix specifies "the block reason as the provider's text", which is what ships. A different field changes the intent.
  - `[false]` `[reject]` "`Validate` produces two violations for one mistake on an unknown provider" -- the pair is what the accumulate-every-violation contract produces, and the one place the code suppresses a second violation says why. Suppressing this one changes a rule's output on an already-refused submission.
  - `[false]` `[reject]` "the `AGENT.ENDPOINT.ADDRESS` matrix row's code is not the code produced" -- for a plain-`http://` loopback with `markedLocal` 0 the scheme rule fires first and the save IS refused, on a code naming the true first reason; the row's address substance is pinned for `https://127.0.0.1/v1` with exactly that code. The only fix edits this build's matrix.
  - `[false]` `[reject]` "the grant-provenance comments break the prose rule against naming who decided what" -- the dispatch and this spec's second `[Review]` item require exactly that provenance on an expectation flip. The prose rule forbids narrating review rounds and finding ids, not naming a decision's authority.
  - `[low]` `[reject]` the two IPv4 entries in `METADATAADDRESSES` duplicate `IsLinkLocal`'s `169.254.0.0/16` test -- true and harmless; the list states the intent in one place, and the fix removes a guard rather than correcting one.
  - `[low]` `[reject]` `KindOf` reports a unique-local metadata address as kind `linklocal` -- the operator-facing sentence was corrected at its origin in `Api/Error.cls`, so the misnomer is internal; a `metadata` kind means a new rank in `KindRank` and a new violation code.
  - `[low]` `[reject]` `METADATAADDRESSES` has no structural assertion of its own -- all four entries are asserted by name in `Test/Egress.TestACloudMetadataAddressIsRefusedInEveryFamily`, a stronger pin than a count.
  - `[low]` `[reject]` `State/Agent.cls`'s "a row stored before this property existed reads it back as 0" is untested -- `InitialExpression` is what makes it true and the compiler owns that; constructing a row with the node absent means writing the global by hand.
  - `[low]` `[reject]` `EXPERIENCE.md`'s Fixed-strings rows list the three new strings after the API-key row while the form renders them before it -- a reference table's row order, which no reader meets as a defect.
  - `[low]` `[reject]` the previous pass's run result and the empty triage log -- this pass's own in-flight bookkeeping, and the fix is to edit this build's spec, which triage rejects by rule. Finalize replaces the result and writes this log; the iteration counter stays 0 because no `bad_spec` loopback occurred.
  - `[low]` `[reject]` `Test/ContextProbe.cls` subclasses `Api/Context.cls` to reach a private method, so the fence guarded the file and not the surface -- the file is unedited, the probe is this story's own new file and is named in the dispatch's footprint, and a test-only subclass is the sanctioned way to reach a private method here.

## Design Notes

**Governing ADs.** **AD-42** is the center: the endpoint is configuration deciding where the instance's data goes; an explicitly-declared local address is its named exception; the proxy is a destination too; a stored credential goes only to the stored endpoint; and the chip's statement is computed from the same configuration the request uses -- which is why `LeavesInstance` is reordered in the same story that makes the call bypass the proxy. Also governing: **AD-35** (no credential in a status, log, URL or trap -- `ApplyAuth` moves the key onto the request in one statement and binds no local), **AD-39** (one envelope, a stable machine code, and `detail.violations[]` carrying `{field, code, reason}` -- both new refusals take that shape; vendor text is normalized, which is what DW-1193's type check enforces), **AD-32** (the named SSL configuration still applies to every https endpoint; a plain-HTTP endpoint has none and `Dispatch` already blanks it), **AD-21** (no caller value concatenated; the endpoint is validated and the normalized path is built from a fixed literal), **AD-12** (no handler writes the response), **AD-9** (the new property is stored through `State/Base`'s guarded save), **AD-37** (`credType` `none` names no credential entry, so nothing is created or deleted) and **AD-11** (a refusal string recovered from a vendor reply is tool-result content, never instruction).

**`SCHEMAVERSION` does not move.** `HttpAcknowledged` is a new boolean every pre-existing row reads as its `InitialExpression` 0, and 0 is the conservative answer -- an untouched row licenses nothing it did not license before. That is exactly the Consistency Conventions' "adding a property that every pre-existing row reads as a safe default", the case `RowVersion` and `CredentialCreated` already set; the property carries the doc comment saying so.

**Why the keyless license rides `allowsLocal` and not a new column.** `Test/AgentViolation.cls:212` pins the `/agent/providers` column set as an exact ordered string and is Epic 5's file, so a fifteenth column cannot be added from here. `allowsLocal` already means "this family serves a model on your own network", which is the same family and the same operator decision the keyless case belongs to, and `AgentRules.AllowsLocal` already reads it. One switch rather than two.

**Endpoint normalization, and why the stored value is the base.** Ollama documents `http://localhost:11434/v1`, vLLM `http://localhost:8000/v1`, LM Studio `http://localhost:1234/v1` and OpenRouter `https://openrouter.ai/api/v1`; in every case the OpenAI client convention appends `/chat/completions`, and none of the four deviates (vendor docs, retrieved 2026-09-19). An operator will therefore paste a base ending `/v1`, while the shipped `openai` row stores the complete `.../v1/chat/completions` URL -- so the adapter accepts either and normalizes, rather than making the operator guess. Omitting the `Authorization` header entirely is documented-safe for Ollama and LM Studio (auth off by default) and for vLLM when no `--api-key` is set; OpenRouter always requires a key, which is why the key stays optional rather than absent. The `api_key='ollama'` placeholders in vendor examples are an OpenAI-SDK constraint, not a server check -- no vendor documents that an omitted header fails. **Unconfirmed and not relied on:** what any of the four does with a present-but-empty `Bearer `; the adapter omits the header rather than sending one, so the question does not arise. `169.254.0.0/16` is RFC 3927 and `fe80::/10` RFC 4291; `169.254.169.254` is the metadata address on AWS, Azure and GCP alike, and `Egress.IsLinkLocal` already refuses the whole range with no escape.

**AWS and GCP publish IPv6 metadata addresses that are not link-local** -- `fd00:ec2::254` and `fd20:ce::254`, both RFC 4193 unique-local, so `fc00::/7` classifies them as private rather than link-local and `IsPermitted` would allow them to a marked-local definition. Out of scope here, and filed as a new ledger candidate rather than widened silently: Release 1 runs on an operator's own instance, and admitting it needs an AD-42 amendment about whether unique-local is a local address.

**AC4 is server-side only.** `leavesInstance` is computed at `Api/Context.cls:110-113`, which is Epic 5's and is left untouched; the chip renders `leavesInstance() === true`, so `false` already produces no pill. Fixing `Egress.LeavesInstance` and `ProviderPort.ResolveEndpoint` -- both this epic's -- is what makes AC4 true, and `Test/EgressLocal.cls` pins it at the route body rather than in the browser. The brief's expectation that the projection lives in `Api/Definitions.cls` is corrected here at its origin.

**`Test/AgentWire.cls:113` -- covered by a standing grant.** That line pins the definition projection's key set as an exact ordered string, and adding `httpAcknowledged` to `Api.Definitions.Fields()` reddens it. The orchestrator granted (2026-09-19) mechanical pin updates in that file which are direct consequences of a surface this epic ships -- one literal each, each reported as a footprint extension naming the line and the shipping surface. Appending `,httpAcknowledged` after `markedLocal` is covered and is the only change to make there. Anything that alters what an assertion means -- removing or reordering keys, weakening a pattern, adding or deleting an assertion -- is **not** covered and is a Clarification. The grant exists because the pin on this epic's own contract lives in a file it does not own, which is filed as DW-1215 for `range-end-cleanup` and is not moved here.

**Declared footprint extension.** `EXPERIENCE.md` is the sole authority for every user-facing literal -- `ui/tools/strings.test.mjs:479-498` refuses any `strings.ts` value the document does not carry and names extending `REQUIRED_ALONGSIDE_TABLE` as the bypass it must not become -- so AC2's three new controls need a Fixed-strings row first. No contended epic declares that file; the edit is one row extension at `:334` and is reported as a footprint extension.

**Consumes:** Story 10.1 (`MessageAdapter`'s OpenAI pair, `ToolDefAdapter.ToOpenAi`), Story 10.2 (`Kernel/Provider/OpenAI.cls` as the nearest adapter, `Test/CatalogProbeShipped`'s re-adaptation pattern, `Test/ProviderStub`'s recording transport), Story 3.1-3.5 (`AgentRules`, `State/Agent`, the definition form), Story 4.11 (the context chip).

**Consumed-by:** Story 11.x's egress line and streaming read the same `leavesInstance` computation and the same canonical `Response`; Epic 12's demo journeys run the read and write paths on every shipped provider, this row included. The four families' `ProviderMessage` now has one implementation, so any later family inherits the type check rather than copying the defect.

**DW-1214 -- in scope, and the shape is the orchestrator's ruling (2026-09-19).** `IsLinkLocal`'s IPv6 arm is `0xFE80-0xFEBF` while `IsPrivate`'s is `0xFC00-0xFDFF`, so AWS's `fd00:ec2::254` and GCP's `fd20:ce::254` read private, not link-local, and `IsPermitted` admitted them to a marked-local definition while the IPv4 `169.254.169.254` was refused with no escape. **Do not redefine unique-local as non-local:** `fc00::/7` is how private IPv6 LANs are addressed and a local model legitimately sits there, so refusing the range would trade this story's own use case for a narrow risk. Refuse a **cloud instance-metadata endpoint in every address family, marked-local included** -- the no-escape treatment IPv4 link-local already has. The asymmetry to remove is the escape, not the range. The guard is a denylist of published addresses and **cannot be complete**: a provider shipping a new address is uncovered until the list learns it, and the durable posture is an allowlist. Say so at the guard. AD-42 and AC3 were corrected at their origins by the lead; the address arithmetic belongs here and in the test, not in the AD.

**Ledger dispositions.** **DW-441** -- addressed: `ProviderPort.Dispatch` bypasses the proxy for a marked-local endpoint (the direction decided at the Epic 4 merge gate) and `Egress.LeavesInstance` stops counting it, so the chip and the request cannot disagree. **DW-1193** -- addressed: `ProviderMessage` consolidates into `Base` with a single type check, closing the OREF text in all four families at once. **DW-1202** -- addressed: all three instances, in the matrix's last three rows. **Declined DW-1201:** standing up a loopback HTTP endpoint inside the throwaway needs an unauthenticated web application outside the installer's roster carrying AD-21's privilege floor, which the installer asserts against in both directions and `Test/WebApp.cls` (Epic 5's) pins; whether a test-only carve-out is admissible is a spine question, not adapter work, so it re-routes rather than being answered here. This story's own local-model evidence comes from the re-adapted shipped row, which opens no socket, so nothing here depends on it.

## Verification

**Slot and instance.** This epic's slot is **B**. Every IRIS MCP call carries `server: "ocupilot-slot-b"` (dev instance, web 52775, superserver 1974); an omitted `server` silently reaches an unrelated container and the profile `ocupilot-iris` does not exist. **No verification in this story may make a live provider call, ever** -- not a probe and not a mutation (orchestrator ruling 2026-09-19, DW-1200): Rule 19's falsifiability requirement does not override the egress prohibition, and a mutation discriminable only by a real third-party call is a recorded unfalsifiable-by-policy gap, not the call. The transport seam is `Test/ProviderStub`'s recording override, reached for this family through `Test/CompatibleStub`. Anything mutating instance state, and the whole sweep, runs on the throwaway: `bash scripts/ci-throwaway.sh up --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci --web 52777 --super 1976` (container `ocupilot-b-ci`, **not currently running**). Never stop, remove, recreate or `down` `ocupilot`, `ocupilot-slot-a`, `ocupilot-slot-b` or `ocupilot-ci`; tear down only a throwaway whose `up` this session ran. A browser run exports **both** `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci`, and prefers a **fresh** throwaway per run (DW-1190).

**Commands:**

- `uv run scripts/check-objectscript.py` and `uv run scripts/test_check_objectscript.py` -- expected: clean.
- Compile every new and changed class through the IRIS MCP tools with `server: "ocupilot-slot-b"`, `namespace: "HSCUSTOM"` -- expected: no errors; read the error text. Recompile the whole `OcuPilot.Kernel.Provider` package after any change to `Base`, because each subclass holds its own compiled copy of an inherited method.
- `bash scripts/lint-docs.sh` -- expected: clean (README and EXPERIENCE.md are both authored Markdown).
- From `ui/`: `npm run build` then `npm test` -- expected: green, including `ui/tools/strings.test.mjs`'s authorized-values and exact-count assertions.
- `node ui/tools/ci-runner.mjs --container ocupilot-b-ci --class <one class>` -- **one class per invocation, one invocation per message**, and never a re-submit on a client-side timeout: a returned call is not a landed run. Order: `OcuPilot.Test.CompatibleAdapter`, `OcuPilot.Test.Adapter`, `OcuPilot.Test.AgentRules`, `OcuPilot.Test.Egress`, `OcuPilot.Test.EgressLocal`, then the regression set `OcuPilot.Test.OpenAIAdapter`, `OcuPilot.Test.GeminiAdapter`, `OcuPilot.Test.Provider`, `OcuPilot.Test.ProviderPort`, `OcuPilot.Test.ProviderProxy`, `OcuPilot.Test.ProviderSecret`, `OcuPilot.Test.ProviderSsl`, `OcuPilot.Test.AgentConnection`, `OcuPilot.Test.ContextBound`, `OcuPilot.Test.AgentWire`, `OcuPilot.Test.AgentViolation`. Confirm every total with the `%UnitTest_Result` SQL probe in `.claude/rules/objectscript-testing.md` before reporting a class green; the runner's envelope truncates and its per-method duration is milliseconds where the global's is seconds.
- **The whole sweep before the commit**: every `OcuPilot.Test.*` class on the throwaway -- **129 classes extend `%UnitTest.TestCase` on this branch** (counted with `grep -rl 'Extends %UnitTest.TestCase' src/OcuPilot/Test`, structurally rather than by filename: 355 `.cls` files live under `Test/`, most of them stubs, probes, fixtures and corpora) -- plus the whole `ui` suite and `npm run test:browser`. Not a subset. Zero executed checks is a failure, never a pass.
- `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` -- expected: every assertion passes, a non-zero count executed.
- `git diff --name-only <baseline>..HEAD -- src ui README.md _bmad-output/planning-artifacts` -- expected: only the paths the Tasks list names, and nothing under `Api/Context.cls`, `ui/src/app/core/` (beyond the appended `strings.ts` keys), `ui/browser/` (beyond `definitions.browser-spec.mjs`) or any `Test/**` class this story does not own.

**Pinning tests and their mutations** (Rule 19 -- one demonstrated mutation per AC; apply to the instance's copy, recompile the package **and every descendant**, observe red, revert, confirm `git status --short` and `git diff --stat` unchanged; a mutation that did not redden is unproven until you have confirmed which compiled copy ran):

- **AC1 (no API key)** -- `CompatibleAdapter.TestAKeylessCallSendsNoAuthorizationHeader`, driving the shipped row with `credType` `none`. `mutation:` have `ProviderPort.ValuesFor` leave `keySource` unset for a `none` `credType` -> red on the expected call, because `Base.Invoke` then resolves a stored key, finds none and faults `PROVIDER.CREDENTIAL` before any request is built. A second leg, `TestTheAdapterWritesNoHeaderWhenTheKeyIsAbsent`, pins the header itself; `mutation:` drop `Compatible.ApplyAuth`'s empty-key guard -> red on the recorded header names.
- **AC2 (plain HTTP)** -- `AgentRules.TestPlainHttpWithAStoredCredentialNeedsTheAcknowledgment`. `mutation:` drop the `credType`-or-acknowledgment term from `AgentRules.SchemeAccepted` -> red on the expected `AGENT.HTTP.ACK.REQUIRED` violation and on the zero-violations assertion for the acknowledged row, every other rule's legs staying green.
- **AC3, metadata arm (DW-1214)** -- `Egress.TestACloudMetadataAddressIsRefusedInEveryFamily`, over the metadata denylist. Demonstrated **two-sidedly** on a fresh `ocupilot-b-ci` throwaway; the run indices below are that container instance's own, which has been recreated since for the rework's sweep and browser run. Both mutations were applied to the container's copy of `Kernel/Egress.cls` and followed by `$System.OBJ.LoadDir` plus `CompilePackage("OcuPilot")`, so every descendant -- `Test/EgressProbe.cls` included -- recompiled. Green baseline run 1 (23 tests, 0 failed; this method passed 20 assertions), green again after revert at run 4.
  `mutation:` neutralize the metadata arm of `Egress.KindOf` (`If ..IsMetadataAddress(tAddress)` -> `If 0`) -> **run 2**, red on this method alone, 9 assertions: all three IPv6 metadata spellings (`fd00:ec2::254`, `fd20:ce::254`, and the mixed-case expanded `FD00:0EC2:0:0:0:0:0:0254`) classify `public` and are permitted at `markedLocal` 0 and 1 alike. The `fd12:3456:789a::1` legs stayed green, and so did the IPv4 legs, since `IsLinkLocal` still covers `169.254.0.0/16`.
  `counter-mutation:` the half that is the point -- make `IsMetadataAddress` answer for the whole of `fc00::/7` (first byte 252 or 253) rather than for a published address list -> **run 3**, red on this method alone and on exactly the three `fd12:3456:789a::1` legs, which classify `linklocal` and are refused at `markedLocal` 1, the metadata legs staying green. A guard that refused the whole range is therefore distinguishable from one that works, which a one-sided demonstration could not show.
  Directly observed on the unmutated code before either mutation, through `Classify` and `IsPermitted` on the shipped `compatible` row (`allowsLocal` 1): the three metadata spellings answer kind `linklocal` and are refused at `markedLocal` 0 and 1; `fd12:3456:789a::1` answers kind `public` and is permitted at both.
- **AC3 (local addresses)** -- `Egress.TestTheShippedCompatibleRowAllowsLoopbackAndPrivateAndStillRefusesLinkLocal`, over the shipped row rather than the probe. `mutation:` set the `compatible` row's `allowsLocal` false in the `Providers` XData -> red on the loopback and private rows, the link-local row staying green because that range has no escape -- which is what shows the two are enforced separately. The link-local arm is pinned by `Egress.TestLinkLocalHasNoEscape`; `mutation:` have `IsPermitted` fall through to the marked-local branch for `KINDLINKLOCAL` -> red on that method alone.
- **AC4 (the chip)** -- `EgressLocal.TestAMarkedLocalDefinitionAnswersLeavesInstanceFalseEvenWithAProxyConfigured`. `mutation:` restore `LeavesInstance`'s original order, testing the proxy host before `pMarkedLocal` -> red on the with-a-proxy leg's `leavesInstance` assertion and on no other. The bypass itself is pinned by `Egress.TestAMarkedLocalCallCarriesNoProxy` over the recorded request; `mutation:` delete `Dispatch`'s marked-local proxy blanking -> red on the recorded proxy server and tunnel.
- **AC5 (the README)** -- `node --test ui/tools/*.test.mjs` does not read the README, so this is a prose AC verified by `bash scripts/lint-docs.sh` plus inspection: the provider paragraph must name local models as the privacy option **and** state the multi-field tool-call caveat. Recorded as having no pinning test by construction -- a documentation sentence has no mutation that a suite can observe.
- **Endpoint normalization** -- `CompatibleAdapter.TestABaseEndpointIsNormalizedAndAnAuthorityChangeIsRefused`. `mutation:` have `Compatible.RequestUrl` answer the stored endpoint unchanged -> red on the recorded URL for the `/v1` row, the already-complete row staying green. The origin guard's other arm is already pinned by `OpenAIAdapter.TestABuiltUrlOnAnotherAuthorityIsRefused`.
- **DW-1193** -- `Adapter.TestANonStringProviderErrorMessageYieldsNoProviderText`. `mutation:` drop the `%GetTypeOf` test from `Base.ProviderMessage` -> red on the assertion that `detail.providerText` is empty, and specifically on its not containing `@%Library.DynamicObject`.
- **DW-1202** -- three rows, three mutations. `Adapter.TestAnOpenAiRefusalReachesTheCanonicalReply`; `mutation:` stop reading `message.refusal` -> red on the text and stop-reason assertions. `Adapter.TestAGeminiPromptBlockIsARefusalNotATransportFault`; `mutation:` remove the `promptFeedback` branch -> red on the stop reason and on the assertion that the fault code is not `PROVIDER.TRANSPORT`. `Adapter.TestEveryGeminiStopReasonMapsAndImageSafetyIsARefusal`; `mutation:` remove `IMAGE_SAFETY` from `GEMINISTOPREASONS` -> red on that key alone, the other eleven staying green.
- **Integration AC** -- `CompatibleAdapter.TestTheShippedCompatibleRowIsCalledThroughThePort`. `mutation:` point `Test/CatalogProbeShipped`'s compatible entry at `OcuPilot.Test.ProviderStub`, the canonical family's stub, so the row resolves a canonical adapter -> red on the recorded body's `messages` and `max_completion_tokens` and on the header name.
- **AC "the diff touches no part of the agent loop, the tool registry, the proposal lifecycle or any screen"** -- recorded, like AC5, as having **no pinning test by construction**: it is a statement about the shape of a diff, and a suite cannot assert it. Verified by the `git diff --name-only <baseline>..HEAD` command under **Commands** plus the footprint reading in the run result. Named here rather than left silently unlisted, so the absence is a decision and not an oversight.
- **AC "`Keys()` reads `anthropic` first and `compatible` last"** -- `AgentRules.TestAnUnknownProviderIsRefused` and `AgentRules.TestTheShippedProviderRowsArePinned`, each asserting the exact ordered string. `mutation:` move the `compatible` row to the front of `Catalog.cls`'s `Providers` XData and `anthropic` to the end -> **run 137**, red on exactly those two assertions (`Keys()` reading `compatible,openai,gemini,anthropic`) and on no other, because `AssertRowPinned` reads each row by key and is indifferent to order. This is not AC3's mutation, which flips `allowsLocal` and leaves the ordering green.
- **AC "a definition whose `httpAcknowledged` changes is disabled until Test connection passes again"**, and AC1's enablement half -- `CompatibleAdapter.TestAKeylessDefinitionIsTestableAsStoredAndTheAcknowledgmentDisables`, added in the rework pass at the surface that decides both, neither of which a port call reaches. `mutation:` remove `"HttpAcknowledged"` from `State/Agent.SecurityFields()` -> **run 138**, red on the security-field assertion alone. `mutation:` drop the second arm of `Api/Definitions.KeySourceIsTheStoredOne`, leaving `Quit (pKeySource = ..#KEYSOURCESTORED)` -> **run 139**, red on the stored-answer assertion alone -- which is what would otherwise let a keyless definition ship storable, callable and permanently unverifiable, and so never enablable. Green again after both reverts, at runs 140 and 141.
- **The `/agent/providers` and definition wire shapes** -- `Test/AgentViolation.cls:212` and `Test/AgentWire.cls:113` are Epic 5's and are the pins that must stay green; the first does, because no column is added, and the second is the declared dependency under Design Notes. Run both in the sweep and report them explicitly.

**Manual checks:**

- In the browser against a fresh throwaway: choose OpenAI-compatible in the Definition form, confirm the local-model control appears and the no-API-key option is offered, fill a loopback `http://` endpoint, save with no key, and confirm no endpoint violation is rendered. Then enable it and confirm the context chip names the provider and host with **no** "leaves the instance" pill (EXPERIENCE.md `:761`). Rebuild and redeploy the bundle before reading any browser result -- a browser spec runs against the deployed bundle, not the working tree.

## Auto Run Result

Status: done
Blocking condition: none

**Rework pass, iteration 1.** The story's implementation landed at `3c05e1b`; this pass worked the
three re-opened `[Review]` items, then the review findings they let through.

**The three re-opened items.** All three granted edits are intact and stand:
`Test/AgentViolation.cls:48,:92` (the field-level code count `30`->`31`, forced by `Api/Error.cls`
gaining `AGENT.HTTP.ACK.REQUIRED`), `Test/ContextBound.cls:224` (the marked-local-behind-a-public-proxy
expectation `1`->`0`), and the additive `.ocu-field-egress` rule at `ui/src/styles/_components.scss:3026`.
The `DW-441` provenance the orchestrator required was already present twice -- the doc comment at
`:215` and an inline comment at `:221-223`, beside the flipped line. Applying that condition to every
expectation flip this story makes found one more without it, `Test/AgentWire.cls:113`, and added it.
DW-1214's mutation was re-demonstrated two-sidedly on a fresh throwaway; both halves, the direct
before-mutation observation, and the run identities are under `## Verification`.

**What this pass changed beyond them** -- 16 files, every one inside the footprint. Production:
`AgentRules.Normalize` gains a `none` arm; `Compatible.RequestUrl` compares the completions suffix
case-blind and collapses every trailing slash without touching the authority;
`definition-form.page.ts` gates the acknowledgment control on the row's own `allowsLocal` and
restores the credential rung that "No API key" displaced. Tests: three component cases over a
provider row that licenses a local address -- the fixture that did not exist, which is why three
client branches had no test host; a new `CompatibleAdapter` pin over the keyless Test-connection key
source and `HttpAcknowledged`'s membership of `SecurityFields()`; an empty-`RequestUrl` refusal leg,
a fragment leg and a differently-cased leg; a `proxyPort` assertion with its control; a `none` leg
for the XOR invariant; and two destructive test teardowns scoped so they no longer delete a
developer instance's state. Prose corrected at its origin: `CatalogProbe`'s "no shipped row
exercises either column", `Base.ProviderMessage`'s "all four vendors", the Gemini stop-reason
count's implied population claim, two class-header counts, and the README's capability sentence, now
labeled `(inference)`.

**Review findings.** 44 findings across four layers: 21 medium, 15 low, 8 false. Patched 19 entries,
deferred 7, rejected the rest, each with its reason in `## Review Triage Log`. No entry was graded
`high`, and none routed to `intent_gap` or `bad_spec`, so the code was not re-derived and
`review_loop_iteration` stands at 0. Two refutations worth naming: the claimed IPv6 metadata-spelling
escape was disproved by probing the instance -- every spelling that is a valid URL host classifies
`linklocal`; and the claim that the README stopped naming local models is refuted by the paragraph
immediately after the edit.

**Follow-up review recommended: false.** This is a follow-up pass, so the recommendation turns only
on a patched `high`, and there was none. Patched entries by verdict: high 0, medium 18, low 1.

**Verification.** `uv run scripts/check-objectscript.py` (494 files, 21 rules, 0 problems),
`uv run scripts/test_check_objectscript.py` (126 tests, OK) and `bash scripts/lint-docs.sh` (91
files, 0 issues; `check-prose` 0 problems) all clean. From `ui/`: `npm run build` green with its six
prebuild checkers; `npm test` 1044 tool tests and 643 component tests, 0 failed. The whole
ObjectScript sweep on the `ocupilot-b-ci` throwaway: **130 classes, 1262 tests, 0 failed**, 0 probe
leftovers, 0 overlaps, 0 foreign runs. 131 files under `Test/` declare `%UnitTest.TestCase` and the
runner discovers the 130 declaring a `Test*` method, the exclusion its own header describes.
`bash scripts/smoke.sh` on that throwaway: 45 executed, 45 passed, 0 failed, 2 pending. The browser
suite ran on a **second** fresh throwaway carrying the rebuilt bundle (DW-1190): 186 tests, 185
passed, 1 failed; `smoke.sh` there answered 44 executed, 44 passed, 0 failed, 1 skipped, the skip
self-explaining because the browser suite had itself written the agent switches. The one browser
failure is `ui/browser/context-chip.browser-spec.mjs:489` "Cap follows agent-switch", pre-authorised
and out of scope: its repair was reverted from `feature` at `ed11819`, so that file is unrepaired on
this tree (DW-1169, cause DW-1175). It was not re-run. No verification in this pass made a live
provider call.

**Residual risks.** The seven `deferred:` entries, two of them medium: a key written to a keyless
definition is not refused by name -- largely mitigated here, since a keyless row now names no
credential entry to write to -- and a definition marked local while naming a public endpoint makes
the context chip state no egress for a call that leaves. The second is pre-existing behavior whose
reachability this story creates, and settling it is an AD-42 amendment rather than adapter work.
