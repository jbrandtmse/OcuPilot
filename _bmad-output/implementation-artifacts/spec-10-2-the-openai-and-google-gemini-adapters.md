---
title: 'Story 10.2: The OpenAI and Google Gemini adapters'
type: 'feature'
created: '2026-09-18'
status: 'done'
baseline_revision: 'a3c11ab82b04053fbb6fda18311882efa9485445'
baseline_commit: '0e39b67a7a93ff4b7e23f675543b27531539f599'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/.claude/rules/objectscript-basics.md'
  - '{project-root}/.claude/rules/objectscript-testing.md'
warnings: ['oversized']
deferred:
  - summary: >-
      The scripted transport now exists twice, and nothing pins the two copies equal
      (DW-1191). The AD-48 half of this entry closed in the 2026-09-19 rework.
    evidence: |-
      ProviderStub.IssueHttpsPost:227 and ProviderStubTransport.Transport:37 record the same thirteen
      values and run the same two arming legs; no test compares the two recordings, so a value added
      to one and not the other leaves every assertion green. The rework grew this copy by the two
      arming legs (~45 lines) rather than shrinking it. Closes by making ProviderStub delegate its
      transport, which means threading its identity parameter and four instance helpers through a
      class method, under its ten-plus subclasses.
    location: >-
      src/OcuPilot/Test/ProviderStubTransport.cls:37
    severity: medium
  - summary: >-
      ProviderStubTransport.MoveArmedRow has no executed test host: no test arms a row move on a
      call routed through this class.
    evidence: |-
      ProviderStub.ArmRowMove's only caller is Test/AgentConnection.cls:774, whose fixture switches in
      CatalogAnthropicStub, so the row move it drives runs ProviderStub's own copy. Replacing this
      copy's body with Quit 0 reddens nothing. The class header now says so rather than claiming the
      coverage. Closes with a mid-flight-conflict test on one new family, a surface this story does
      not otherwise drive through the connection screen.
    location: >-
      src/OcuPilot/Test/ProviderStubTransport.cls:145
    severity: low
  - summary: >-
      A stored Gemini endpoint carrying no {model} placeholder runs a model the definition does not name.
    evidence: |-
      Gemini.RequestUrl answers an unchanged endpoint when the placeholder is absent, and CallMessages
      deliberately puts no model in the body, so a definition whose Model is gemini-3.8-flash pointed at a
      stored .../models/gemini-2.5-pro:generateContent calls 2.5-pro while every screen and ledger row says
      3.8-flash. Whether to warn, refuse or document it is a product call the spec does not settle; the
      missing test travels with the decision.
    location: >-
      src/OcuPilot/Kernel/Provider/Gemini.cls:61
    severity: medium
  - summary: >-
      Kernel/AgentRules has no create-time rule on model, so a model that cannot enter Gemini's URL path
      is a turn-time refusal rather than a validation failure at save.
    evidence: |-
      The rule list validates name, provider, tokens, temperature, credentials, endpoint, prompt, retention
      and iterations, never model. This story is what first makes the model load-bearing on the wire. A new
      rule means a new violation code and changes what the form accepts.
    location: >-
      src/OcuPilot/Kernel/AgentRules.cls:82
    severity: medium
  - summary: >-
      OpenAI sends temperature unconditionally; the row's own default model may refuse a non-default value,
      the same vendor constraint that forced max_completion_tokens.
    evidence: |-
      Unverifiable here: confirming it needs a live provider call, which this story forbids. If true, every
      turn on the shipped openai row fails with PROVIDER.REFUSED. Settled by one call with a key, or by the
      vendor's per-model parameter table.
    location: >-
      src/OcuPilot/Kernel/Provider/OpenAI.cls:54
    severity: medium (unverified)
  - summary: >-
      Anthropic.IsApiKeyShapeValid keeps its own prefix test instead of delegating to Base.KeyShapeAccepted,
      and answers differently where a row declares no prefix.
    evidence: |-
      Anthropic returns 1 for any value when KeyPrefix is empty; KeyShapeAccepted refuses an empty or
      whitespace-bearing one. Unreachable today: no shipped or probe row puts that family on a prefix-less
      row. The base's claim has been narrowed to the families that delegate; migrating Anthropic would make
      it true again.
    location: >-
      src/OcuPilot/Kernel/Provider/Anthropic.cls:109
    severity: low
  - summary: >-
      ProviderMessage is three byte-identical bodies across Anthropic, OpenAI and Gemini.
    evidence: |-
      Anthropic.cls:165, OpenAI.cls:104 and Gemini.cls:146 parse, type-check and read error.message
      identically. A Base helper would leave each adapter a one-liner and make "the message alone, never the
      body" one enforceable rule; it touches the canonical family, so it is not this story's smallest change.
    severity: low
  - summary: >-
      A non-string error.message stringifies an OREF into detail.providerText in all three adapters.
    evidence: |-
      Set tMessage = tParsed.error.message with an object or array value yields "N@%Library.DynamicObject",
      which reaches a screen and a tool result as the vendor's words. The same shape is pre-existing in the
      Anthropic adapter, so the fix is pattern-level, alongside the ProviderMessage entry above.
    location: >-
      src/OcuPilot/Kernel/Provider/OpenAI.cls:112
    severity: low
  - summary: >-
      Base.HttpFor maps PROVIDER.EGRESS to 502 rather than the 503 own-configuration class its own doc
      names.
    evidence: |-
      HttpFor lists TIMEOUT, UNCONFIGURED, CREDENTIAL, CREDENTIALSTORE, KEYSHAPE and TLS and falls through
      to 502; no socket is opened on an egress refusal, so it belongs with the 503 group. Pre-existing --
      the port produced that code before this story -- and unasserted either way.
    location: >-
      src/OcuPilot/Kernel/Provider/Base.cls:546
    severity: low
  - summary: >-
      The /agent/providers payload's prefix-less keyShapeReason states no rule, and the client's inline
      check returns early on an empty prefix.
    evidence: |-
      Definitions.cls:259 renders the bare REASONAGENTKEYSHAPE sentence for a row with no prefix, which is
      now two of the three shipped rows; the form shows no inline warning for a pasted key carrying a space.
      Both surfaces are excluded by this story's intent (no Api/** or ui/** change), and the assertion would
      have to live in Test/AgentViolation.cls or Test/AgentCredential.cls, outside this footprint.
    location: >-
      src/OcuPilot/Api/Definitions.cls:259
    severity: low
  - summary: >-
      AC5's "same fourteen columns" is pinned by value, not by count, so an extra or misspelled column
      passes.
    evidence: |-
      AgentRules.AssertRowPinned asserts thirteen values per row; tRow.somTypo reads "" and a fifteenth
      column goes unnoticed. AgentViolation.cls pins the projected key set for row 0 only and is Epic 5's
      file, so a prefix-less row's projection is never checked.
    location: >-
      src/OcuPilot/Test/AgentRules.cls:151
    severity: low
  - summary: >-
      The key-shape gate's whitespace test misses U+00A0 and other Unicode spaces.
    evidence: |-
      $ZStrip(..ApiKey, "*WC") removes ASCII space, tab and control characters only, so a key pasted from a
      rendered web page carrying a non-breaking space is accepted and fails later as PROVIDER.REFUSED rather
      than PROVIDER.KEYSHAPE -- the paste error the gate exists to catch.
    location: >-
      src/OcuPilot/Kernel/Provider/Base.cls:585
    severity: low
  - summary: >-
      Both new adapter suites depend on outbound DNS for api.openai.com and generativelanguage.googleapis.com.
    evidence: |-
      ProviderPortProbe stubs the permission gate, the secret class and TLS, not Kernel.Egress, so the port
      judges the shipped endpoint's host for real. On a leg without DNS every method fails as if the product
      were broken. AC3 now carries a positive control so its refusals stay attributable; the rest do not.
    location: >-
      src/OcuPilot/Test/OpenAIAdapter.cls:1
    severity: low
  - summary: >-
      The matrix's "key empty" half is refused earlier as PROVIDER.CREDENTIAL, not PROVIDER.KEYSHAPE.
    evidence: |-
      Base.Invoke refuses an unresolvable or empty key at :149-163 before the shape gate at :168, so the
      ..ApiKey '= "" term in KeyShapeAccepted cannot decide that call. The row's observable contract -- no
      socket, no key material in the reason -- holds; only the code name differs, and the more specific code
      is the better answer. The intent-contract is read-only, so the wording stands.
    location: >-
      src/OcuPilot/Kernel/Provider/Base.cls:149
    severity: low
  - summary: >-
      Per-family coverage is asymmetric, and the unreadable-body matrix row is covered only by composition.
    evidence: |-
      OpenAIAdapter has the exhausted-attempts and key-shape legs; GeminiAdapter has neither, though its
      PROBEKEY is documented as the prefix-less fallback. The unreadable-body row is met by Adapter.cls:687-690
      (each family's MapResponse answers an error %Status) plus Provider.cls:385 (the Base mapping to
      PROVIDER.TRANSPORT), not by a per-family end-to-end leg.
    location: >-
      src/OcuPilot/Test/GeminiAdapter.cls:1
    severity: low
  - summary: >-
      ProviderStub.WATCHEDHEADERS does not watch Authorization, so the canonical suite cannot see a leaked
      OpenAI header.
    evidence: |-
      OpenAIStub now watches x-goog-api-key as well as its own, and GeminiStub already watched all four, but
      ProviderStub.cls is Epic 5's footprint and still watches only x-api-key and anthropic-version.
    location: >-
      src/OcuPilot/Test/ProviderStub.cls:32
    severity: low
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
- `src/OcuPilot/Test/ProviderStubTransport.cls` — the scripted-transport body as class methods
  taking the identity and the watched-header list, over `ProviderStub`'s own globals and public
  arming and reading API. `ProviderStub` is left unchanged because a stub extending a shipped
  adapter cannot inherit its instance method, and because consolidating would mean threading that
  class's identity parameter and four instance helpers through a class method, or changing the
  hierarchy under its ten-plus subclasses — a refactor of the shared test substrate rather than
  this story's work.
- `src/OcuPilot/Test/OpenAIStub.cls`, `src/OcuPilot/Test/GeminiStub.cls` — new stubs extending
  the two shipped adapters, delegating transport, `Wait` and `NowSeconds` to those class methods.
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
  it matches `^[A-Za-z0-9_-]{1,64}$` — OpenAI's published name grammar. Gemini's is not a narrowing
  of it: it requires a leading letter or underscore but admits dots. The test therefore asserts a
  pattern **inside** both rather than their intersection, requiring a leading letter.

### Review Findings

_Code review 2026-09-19 (full, `full-opus`; blind-hunter, edge-case-hunter, verification-gap,
acceptance-auditor). 45 raw findings, 11 root-cause entries: high 0, med 3, low 8._

- [x] [Review][Patch] `Base.KeyShapeAccepted`'s prefix arm is unexercised and weaker than its own
  fallback arm [src/OcuPilot/Kernel/Provider/Base.cls:597] -- no catalog row pairs a non-empty
  `keyPrefix` with an adapter that delegates, and that arm applied no whitespace test, so a key
  with a carriage return would have reached `SetHeader`, which stores a value verbatim. The
  whitespace test now guards both arms and `Test/OpenAIAdapter` drives the arm both ways.
- [x] [Review][Patch] The intent's "no empty auth header" had no pinning test on either new family
  [src/OcuPilot/Kernel/Provider/OpenAI.cls:77] -- a `keySource: none` call is now asserted to reach
  the transport carrying no watched header. The Gemini twin is not falsifiable through the stub's
  header recording and is ledgered (DW-1199).
- [x] [Review][Patch] `Test/Adapter.cls`'s two tool-name grammar parameters contradict each other
  on the leading-letter rule [src/OcuPilot/Test/Adapter.cls:51]
- [x] [Review][Patch] `GeminiStub.WATCHEDHEADERS`'s doc says no other family sends `Authorization`
  [src/OcuPilot/Test/GeminiStub.cls:20]
- [x] [Review][Patch] The rule-8 doc keeps the superseded "build step 7" phrase its shipped twin
  dropped [src/OcuPilot/Test/AgentRules.cls:270]
- [x] [Review][Patch] Two assertion messages overclaim -- "most capable first" is not true of the
  `gemini` row, and `IsKnown` reads the armed block only while armed
  [src/OcuPilot/Test/AgentRules.cls:132]
- [x] [Review][Patch] AC3's positive control ran with no tools while the call it controls for sends
  them [src/OcuPilot/Test/GeminiAdapter.cls:279]
- [x] [Review][Patch] `ProviderStubTransport`'s header claims the same script and recording as
  `ProviderStub` while carrying neither arming leg
  [src/OcuPilot/Test/ProviderStubTransport.cls:8]
- [x] [Review][Defer] `Test/CatalogAnthropicStub`'s header still says `anthropic` is the only key
  `Validate` accepts [src/OcuPilot/Test/CatalogAnthropicStub.cls:2] -- deferred: Epic 5's
  footprint; DW-1197, `routed owner=burndown`
- [x] [Review][Defer] `Base.OriginOf` compares the authority byte for byte and strips no userinfo
  [src/OcuPilot/Kernel/Provider/Base.cls:356] -- deferred: unreachable from shipped code; DW-1198,
  `wontfix-accepted` with a probe on Story 10.3's normalization
- [x] [Review][Defer] Gemini's no-empty-auth-header guard cannot be pinned through the stub's
  header recording [src/OcuPilot/Test/ProviderStubTransport.cls:166] -- deferred: DW-1199,
  `wontfix-accepted` with a probe on presence-aware recording

**Rejected.**

- `false` -- nothing enforces the shared wire-name grammar, so a tool named `2fa_reset` would reach
  Gemini: `Registry.ListTools:127` refuses any `TOOLNAME` outside
  `^[a-z][a-z0-9]*\.[a-z][a-z0-9]*\.[a-z][a-z0-9]*$`, so a leading digit or underscore cannot
  reach `WireName`.
- `low` -- AC7's text names `^[A-Za-z0-9_-]{1,64}$` while the test asserts a stricter pattern: the
  stricter pattern satisfies AC7 in every case. The Tasks bullet's stale `Test/StubTransport.cls`
  was corrected at its origin by the lead (2026-09-19).
- `low` -- `IsSynthesizedCallId` is a bare prefix match: a colliding vendor id then travels on
  neither part and name-and-order correlation is correct; real only if a vendor documents ids with
  that prefix.
- `low` -- a numeric `functionCall.id` is discarded: the vendor's reference types `id` as a string,
  so the synthesized fallback is the right answer.
- `low` -- the class doc presents the Gemini `finishReason` list as the vendor's complete enum:
  settling it needs the vendor's current enum page, and an unlisted blocking reason maps to
  `end_turn`; no OcuPilot request can produce the image-safety reasons it would most likely add.
- `low` -- `MALFORMED_FUNCTION_CALL` maps to `refusal`: spec-bound, the Tasks name those three
  reasons.
- `low` -- duplicated `ProviderMessage` bodies, `IsApiKeyShapeValid` one-liners, and ~150 shared
  lines across the two new suites: DW-1193 already owns the `ProviderMessage` root cause, and a
  shared test base is more than a direct correction.
- `low` -- `ProviderStub.Reset()` followed by `SecretProbe.SetValue` is a dead re-set: a redundant
  re-arm is not a defect, and removing it couples the tests to `Reset`'s internals.
- `low` -- `KeyShapeAccepted`'s `(..ApiKey '= "")` term cannot be false at either call site: both
  callers refuse an empty key earlier with a more specific code, and a method correct standalone is
  not a defect.
- `low` -- the gate bounds no length, so a multi-kilobyte paste is accepted: neither vendor
  publishes a length grammar.
- `low` -- a foreign canonical id replayed into a Gemini request is untested: documented behavior,
  it is emitted on both parts so the pair still correlates, and it is reached only by repointing a
  stored definition at another family mid-conversation.
- `low` -- the `followRedirect` comment was compressed: the `"unset"` sentinel's meaning is still
  stated.

- [x] [Review] AD-35's named verification is unmet for the two families this story adds. Add
  `ProviderStub`'s forced-error-log arming and armed-row legs to `Test/ProviderStubTransport.cls`
  so the sweep reaches `OpenAI.ApplyAuth` and `Gemini.ApplyAuth`, and extend the AD-35 proof in
  `Test/ProviderSecret.cls` to both. The implementation already conforms -- the lead verified
  lead-side that the key reaches `Authorization` and `x-goog-api-key` and appears in no fault,
  status, message or URL -- what is missing is the automated proof. Duplication alone stays
  deferred (DW-1191).
- [x] [Review] `Test/AgentWire.cls:79` carries `"nosuchprovider"` as a bare literal. Change it to
  reference `##class(OcuPilot.Test.AgentRules).#UNKNOWNPROVIDER` so the fixture is tied to the
  catalog guard at `AgentRules.cls:132`. Orchestrator-granted 2026-09-19; still exactly one token
  of surface in that file and nothing else.
- [x] [Review] `Test/CatalogProbeShipped.Table` fails open: on a key rename or parameter drift it
  would let a real outbound POST carrying the probe key reach a vendor, silently and in the
  direction of making the call. Assert that exactly the two expected rows were replaced, before
  `Invoke` runs, rather than after it returns. No live exposure today -- the rows match.
- [x] [Review] Correct at their origin any remaining doc-comment or spec sentence asserting
  something the code does not do -- the built-URL containment wording and the Google leading-letter
  justification were both named. Replace the wrong sentence; do not append a qualifier beside it.

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
the orchestrator granted that one value there (2026-09-19); it reads
`##class(OcuPilot.Test.AgentRules).#UNKNOWNPROVIDER`, so the fixture is tied to the catalog guard at
`AgentRules.cls:132` — one token of surface and nothing else, reported as a footprint extension.
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

- **AC1** — `OpenAIAdapter.TestAShippedOpenAiRowIsCalledInItsOwnDialect`. `mutation:` point
  `Test/CatalogProbeShipped`'s `OPENAISTUB` at `OcuPilot.Test.ProviderStub`, the canonical family's
  stub, so the `openai` row the call resolves names a canonical adapter → red on the recorded
  header name and on the `messages` / `max_completion_tokens` body assertions. Mutating the
  shipped row's own column cannot bite: that catalog re-adapts the row to a stub regardless.
- **AC2** — `GeminiAdapter.TestAShippedGeminiRowIsCalledInItsOwnDialect`. `mutation:` have
  `Gemini.RequestUrl` answer the endpoint unchanged → red on the recorded URL still carrying
  `{model}`.
- **AC3** — `GeminiAdapter.TestAModelThatWouldNotSurviveSubstitutionIsRefused`. `mutation:` drop
  the model-shape gate in `Gemini.RequestUrl` → red on the expected `PROVIDER.EGRESS` code and on
  the zero-calls assertion. The guard's other arm is pinned by
  `GeminiAdapter.TestABuiltUrlOnAnotherAuthorityIsRefused` over `Test/ProviderOriginProbe`;
  `mutation:` drop the `tOrigin '= tJudged` term from `Base.Attempts` → red on that method alone.
- **AC4** — `OpenAIAdapter.TestTheSharedRetryAndRefusalRulesHold` (and its Gemini twin).
  `mutation:` have `Base.Attempts`'s attempt `Catch` record a retryable status rather than a raise
  → red on the one-attempt assertion. Removing the mid-flight `Quit` alone cannot bite: the
  `$$$ISERR(tIssueSC)` exit below it ends the loop on the same attempt.
- **AC5** — `OcuPilot.Test.AgentRules.TestTheShippedProviderRowsArePinned`. `mutation:` change the
  `gemini` row's `defaultModel` in the `Providers` XData → red on that row's model alone.
- **AC6** — `OcuPilot.Test.Adapter.TestAVendorGeminiCallIdSurvivesTheRoundTrip`. `mutation:` make
  `GeminiToCanonical` synthesize an id even where the reply carried one → red on the echoed
  `functionResponse.id`.
- **AC7** — `OcuPilot.Test.Adapter.TestEveryWireToolNameFitsBothVendorGrammars` over
  `Registry.WireName`'s output for every name `Registry.ListTools` advertises. `mutation:` have
  `Registry.WireName` leave one dot in place → red on the per-name assertion, naming that tool.
  Asserted against the transform, not against `ProviderTools`'s output: that method already
  refuses a name failing `WIRENAMEPATTERN`, so a grammar check over what it emitted could not
  fail.
- **The shared key-shape gate's prefix arm** (added at review) --
  `OpenAIAdapter.TestTheKeyShapeGatesPrefixArmRefusesAKeyOfAnotherShape`. `mutation:` have
  `Base.KeyShapeAccepted`'s prefix arm answer 1 -> red on the wrong-prefix leg's expected
  `PROVIDER.KEYSHAPE` and on its zero-calls assertion, every other method staying green.
- **"No empty auth header"** (added at review) --
  `OpenAIAdapter.TestACallWithNoKeySendsNoAuthenticationHeader`. `mutation:` drop the
  `If ..ApiKey = "" Quit` guard from `OpenAI.ApplyAuth` -> red on the recorded header names.
- **AD-35 on the two new families** (added at rework) --
  `ProviderSecret.TestNoCredentialMaterialReachesTheLogsOrTheEnvelope`'s legs seven to ten, which
  run on the throwaway alone because they force a real `^ERRORS` entry. Each leg asserts which stub
  served it and **how many** forced entries it wrote -- `REFUSALENTRIES` 2 for a refusal, its
  `ApplyAuth` leg and the transport's, and `RAISEENTRIES` 1 for a mid-flight raise, the transport
  having raised before its own. Counted exactly, not "grew": with a `>` test either leg alone
  satisfied it and neither was pinned (measured -- the transport-leg mutation below reddened
  nothing until the assertion was tightened). `mutation:` have `Gemini.RequestUrl` append the
  credential as the `?key=` query parameter the wider vendor API also accepts -> red on the gemini
  legs' three variable-table assertions, because `Base.Attempts`'s URL local then carries it, every
  other leg green. `mutation:` delete the `Do ..ForceErrorLog()` call from
  `ProviderStubTransport.Transport` -> red on both refusal legs' count assertions and on no other.
  `mutation:` delete the two stubs' `ApplyAuth` overrides -> red on all four, the mid-flight legs
  reading 0 entries -- which is what shows those overrides are the only writer on a raise rather
  than a second copy of the transport's leg.
- **The re-adapting catalog fails closed** (added at rework) --
  `OpenAIAdapter.TestADriftedShippedKeyLeavesTheReAdaptingCatalogAnsweringNothing` over
  `Test/CatalogProbeDrift`, whose `OPENAIKEYSHIPPED` names a key the shipped table does not declare.
  `mutation:` delete the `If (tOpenAiRows = 1) && (tGeminiRows = 1)` refusal from
  `CatalogProbeShipped.Table` -> red on that method's error-status, empty-table and
  `PROVIDER.UNCONFIGURED` assertions and on no other method in the class. **That red is itself the
  hazard**: with the guard gone the drifted row keeps the shipped `adapterClass`, and the measured
  run's failure text is the vendor's own `Incorrect API key provided: probeope****...` -- a real POST
  left the instance. Run that mutation only where outbound egress is acceptable. Changing
  `OPENAIKEYSHIPPED` instead cannot stand in for it: that reddens with or without the guard, so it
  pins the re-adaptation rather than the refusal.

## Review Triage Log

### 2026-09-19 — Review pass

- verdicts: 56 findings — high 0, medium 18, low 30, false 6, maybe-false 2
- findings:

From the Blind Hunter layer:

  - `low` `patch` Base.KeyShapeAccepted's "two families cannot answer two ways" is false; Anthropic keeps its own prefix test — verified at `Anthropic.cls:109-113`: it returns 1 for any value on a prefix-less row. No shipped or probe row puts that family on one, so unreachable; the base's claim was narrowed to the families that delegate and the exception named. Migration deferred.
  - `low` `defer` `ProviderMessage` is a third byte-identical copy — verified across `Anthropic.cls:165`, `OpenAI.cls:104`, `Gemini.cls:146`. A Base helper touches the canonical family; not this story's smallest change.
  - `medium` `defer` `ProviderStubTransport` dropped ProviderStub's armed-error-log and armed-row legs — verified at `ProviderStub.cls:269-273`; both helpers are `[ Private ]` and `ProviderStub.cls` is Epic 5's, so AD-48's forced-error-log sweep cannot reach the two new `ApplyAuth` bodies from this footprint.
  - `medium` `patch` the egress guard's origin-differs arm had no failing case — verified: `Gemini.MODELPATTERN` admits no character that changes an authority, so every shipped refusal lands on the empty arm. Added `Test/ProviderOriginProbe` and `GeminiAdapter.TestABuiltUrlOnAnotherAuthorityIsRefused`; mutation demonstrated red on that method alone.
  - `medium` `patch` the refusal told the operator the endpoint resolves to a refused address — verified: `Fault(code, "", …)` falls through to `ReasonFor(PROVIDEREGRESS)`. Added `Base.REASONBUILTURLEGRESS`, passed at the refusal and asserted in AC3.
  - `low` `defer` `HttpFor` maps `PROVIDER.EGRESS` to 502 rather than 503 — verified at `Base.cls:546-559`; pre-existing, since the port produced that code before this story.
  - `medium` `defer` no create-time `model` rule — verified: `AgentRules.cls:82-115` validates nine fields and never `model`. A new rule is a new violation code and changes what the form accepts; not settled by the spec.
  - `low` `patch` `MODELPATTERN`'s doc claimed it "admits every model id the vendor publishes" — a qualified `models/<id>` is refused, correctly, because the placeholder sits under the endpoint's own `models/`. Sentence narrowed.
  - `medium` `defer` a placeholder-free Gemini endpoint silently ignores the definition's model — verified at `Gemini.cls:61-63` with `CallMessages` putting no model in the body. Warn, refuse or document is a product call.
  - `medium` `patch` AC7's assertion could not fail — verified: `Registry.cls:240-241` already refuses a name failing `WIRENAMEPATTERN`, so a grammar check over what `ProviderTools` emitted was vacuous. Rewritten over `WireName`'s output per canonical name from `ListTools`, with the shared grammar spelled independently; the leading-letter overclaim corrected; mutation re-demonstrated.
  - `medium` `patch` `IsSynthesizedCallId` treats "not my prefix" as "the vendor issued it" — verified: the request direction echoed `functionResponse.id` for a foreign id while the replayed `functionCall` carried none. Fixed symmetrically: a call id now travels on both parts or on neither.
  - `low` `patch` three `finishReason` values collapsed to `refusal` on a justification that does not hold for them — the mapping is spec-bound (named in Tasks); the sentence was corrected to the real reason, that the canonical vocabulary has no finer value.
  - `low` `defer` the prefix-less key rule has no operator-facing reason and no client counterpart — both surfaces (`Api/**`, `ui/**`) are excluded by the intent.
  - `low` `defer` AC5's fourteen columns pinned by value, not by count — verified: `AssertRowPinned` checks thirteen values; the projection pin lives in Epic 5's `AgentViolation.cls`.
  - `false` `reject` the sentinel is a parameter in one file and a literal in another — the orchestrator granted exactly one literal in `AgentWire.cls`, and the guard the finding wants is present in `AgentRules` (`IsKnown(..#UNKNOWNPROVIDER) = 0`). A `$Parameter` reference would add a cross-class dependency to a file this epic does not own.
  - `low` `patch` `OpenAIStub.WATCHEDHEADERS` omitted `x-goog-api-key` — added, so its "neither of the other families' headers" assertion can see a leak. The `ProviderStub.WATCHEDHEADERS` half is Epic 5's file and is deferred.
  - `low` `patch` both suites depend on outbound DNS, so AC3 could pass for the wrong reason — a positive control was added in the same method: the row's own model reaches the transport once.
  - `low` `defer` the whitespace test misses U+00A0 — `$ZStrip(…, "*WC")` removes ASCII whitespace and control characters only.
  - `low` `patch` the guard's log could not distinguish its two arms and evaluated `OriginOf` twice — the judged origin is now computed once into `tJudged` and both origins are named in the log line.
  - `maybe-false` `defer` OpenAI sends `temperature` unconditionally — settling it needs a live provider call, which this story forbids. Recorded with what would settle it.
  - `low` `patch` smaller consistency gaps — `CatalogProbeShipped.Table` gained the doc comment its siblings carry and `Base`'s seam list now names `KeyShapeAccepted`; the spec's own file name was corrected to `ProviderStubTransport.cls`. The `[ Private ]` half is wrong: `CatalogProbe.Table`, the method it overrides, carries no such keyword.
  - `false` `reject` the DW-1180 ledger entry is not closed — Rule 15(a): `bmad-build-auto` never writes the ledger; the lead harvests after `dev_complete`.

From the Edge Case Hunter layer:

  - `medium` `patch` a canonical history carrying a foreign `tool_use` id is echoed to Gemini — grouped with the symmetric-id fix above.
  - `medium` `patch` the rebuilt `functionCall` part omits `id`, so the answer references a call the request does not identify — verified at `MessageAdapter.cls:305-311`; the same fix closes it, and AC6 now asserts the call side.
  - `low` `reject` a vendor id beginning `geminicall` would be classified synthesized — wontfix-theoretical: it is then sent on neither part and falls back to name-and-order correlation, which is correct; no vendor documents such ids.
  - `low` `reject` a `functionCall.id` arriving as a number is discarded — the vendor's reference types `id` as a string; the fallback is correct behavior, not a defect.
  - `medium` `patch` the egress reason names the endpoint when the cause is the model — duplicate of the reason finding above; patched.
  - `low` `reject` a model of `.` or `..` changes the path — refuted: the placeholder is one segment of `models/{model}:generateContent`, so the substituted segment is `.:generateContent`, never `..`; no traversal, and the guard covers scheme and authority.
  - `medium` `defer` a placeholder-free endpoint ignores the model — duplicate; deferred.
  - `maybe-false` `defer` `temperature` on a reasoning model — duplicate; deferred with what would settle it.
  - `low` `defer` a non-string `error.message` yields an OREF string in `detail.providerText` (OpenAI) — real, and identical in the pre-existing Anthropic adapter, so the fix is pattern-level.
  - `low` `defer` the same for Gemini — same root cause; one ledger entry.
  - `low` `patch` AC3 could pass on an unresolvable host with the model gate never running — duplicate of the DNS finding; the positive control closes it.
  - `medium` `defer` `ProviderStubTransport` dropped the `^%ETN` capture leg, leaving AD-48 unproven for both new `ApplyAuth` bodies — duplicate; deferred with the delegation that closes it.
  - `low` `patch` `Anthropic.IsApiKeyShapeValid` should delegate — duplicate; the claim was narrowed in-pass, the migration deferred.
  - `false` `reject` `AgentWire.cls:79` should read the sentinel from a parameter — duplicate; refused for the footprint reason above.
  - `medium` `patch` `VENDORNAMEPATTERN` is OpenAI's alone and admits `_x` and `9x` — verified; the new AC7 test asserts against a `SHAREDNAMEPATTERN` that carries the leading-letter rule.
  - `low` `patch` three shipped classes still carried the superseded one-row prose — verified at `Anthropic.cls:1`, `AgentRules.cls:270`, `State/Agent.cls:53`; each corrected at its origin.

From the Verification Gap Reviewer layer:

  - `medium` `patch` AC7's wire-name assertion cannot fail — filed pre-verified; rewritten as above and the spec's `mutation:` line corrected.
  - `medium` `patch` the origin-containment arm is driven by nothing — filed pre-verified; closed by the new probe adapter and its test.
  - `medium` `defer` Gemini's placeholder-free branch has no test and silently ignores the model — the test travels with the product decision, so both were deferred together rather than pinning behavior nobody has decided.
  - `low` `patch` Anthropic does not adopt `Base.KeyShapeAccepted` — the layer's own disposition was defer-and-narrow; the claim was narrowed in-pass and the migration deferred.
  - `low` `defer` the two new rows' `/agent/providers` projection is unasserted, including the prefix-less key-shape sentence — the assertion would have to live in an Epic 5 file and the sentence in `Api/**`, which the intent excludes.
  - `low` `defer` the matrix's "key empty" half is not testable as written — verified: `Base.Invoke:149-163` refuses an empty key before the shape gate. The row's observable contract still holds; the intent-contract is read-only.
  - `low` `patch` `CatalogProbe.cls:18-20` still said the shipped table declares exactly `anthropic` — corrected.
  - `low` `reject` the `geminicall` prefix collision — duplicate; wontfix-theoretical as above.

From the Intent Alignment Auditor layer:

  - `medium` `patch` the intent's expectation is provenance, the diff's check is a prefix — duplicate of the symmetric-id fix; patched.
  - `medium` `patch` the guard's second half is unreachable from shipped code and undriven — duplicate; patched.
  - `false` `reject` the guard newly refuses a scheme-less endpoint for the canonical family too — refuted: `ProviderPort.cls:246` runs `AgentRules.SchemeAccepted`, and both `IsAbsoluteHttps` and `IsAbsoluteHttp` require a scheme, so a scheme-less endpoint never reaches `Attempts`.
  - `low` `defer` the key-shape matrix row's empty half sits at a different surface, and Gemini has no key-shape leg — duplicate of the two entries above.
  - `low` `defer` per-family coverage is asymmetric and the unreadable-body row is covered for neither family at adapter level — verified: it is met by composition, `Adapter.cls:687-690` plus `Provider.cls:385`. Recorded rather than patched.
  - `medium` `defer` AD-48's executable check is bound to the Anthropic-derived stub — duplicate of the `ProviderStubTransport` entry.
  - `false` `reject` `GEMINISTOPREASONS` is a fourth shared-code change the intent did not name — the spec's Tasks name those three reasons explicitly; it is named work.
  - `low` `patch` `KeyShapeAccepted`'s claim holds for two of three families, and the name collides with `Api.Definitions.KeyShapeAccepted` — the claim was narrowed; the name is not ambiguous at any call site, both being fully qualified.
  - `low` `patch` the spec named the new file `Test/StubTransport.cls` while the diff ships `ProviderStubTransport.cls` — the file was renamed into this story's footprint and the spec corrected.
  - `false` `reject` cross-epic test edits the intent fenced no boundary for — the sentinel edits are the orchestrator's granted change and are reported as a footprint extension; `Test/AgentViolation.cls` is correctly untouched.

### 2026-09-19 — Review pass (rework iteration 1)

- verdicts: 43 findings — high 0, medium 5, low 15, false 23, maybe-false 0
- findings:

From the Blind Hunter layer:

  - `false` `reject` `## Auto Run Result` was not updated for this pass -- step-04's Finalize writes that section in this same pass, after the review layers report; it is stale only between those two points.
  - `false` `reject` the `## Review Triage Log` still records the AD-48 item as `medium defer` -- that log is append-only per-pass history; the workflow appends an entry per pass and never rewrites an earlier one, and this entry records the closure.
  - `false` `reject` `review_loop_iteration` stayed at 0 although the commit says "rework iteration 1" -- different counters: that field is step-04's bad_spec loopback count, which step-01 resets to 0 on a re-dispatch; the lead's rework count lives in the commit message.
  - `low` `reject` the three revisions the spec names disagree -- verified, and each is labeled and doing a distinct job: `baseline_revision` anchors this pass's diff, `baseline_commit` the story's, and `## Verification`'s a42aa48 the epic's scope check. Rejected: the fix is an edit to this build's spec and no reader can get a wrong result from picking any of them, only a wider or narrower diff.
  - `false` `reject` nothing records that the changed code was executed -- refuted by this pass's own run: the whole sweep on throwaway `ocupilot-b-ci` over the committed tree, `ProviderSecret` among it, plus three demonstrated mutations. Recorded under `## Auto Run Result`.
  - `false` `reject` legs seven and eight can pass vacuously because `ApplyAuth` quits on an empty key -- refuted: `Base.Invoke:157-163` refuses an empty key with `PROVIDER.CREDENTIAL` before the transport, so `ApplyAuth`'s guard is unreachable on this path, and `ProviderStub.Reset()` per leg clears `servedBy`, so an unresolved canary reddens the served-by assertion. The header half is pinned by AC1/AC2 already.
  - `medium` `patch` the two new `ApplyAuth` overrides are redundant with the transport leg and nothing falsifies them; no new-family leg queues a mid-flight raise -- verified: `Transport` raises before its own leg on a `throw` script, so the `ApplyAuth` leg's only distinguishing case was undriven. Each family now runs a refusal leg and a mid-flight leg, each asserting its own forced-entry count grew.
  - `low` `patch` `ProviderStubTransport.MoveArmedRow` has no caller that can arm it, while the class header claims the row move reaches the two new families -- verified: `ArmRowMove`'s only caller drives the canonical stub. The leg itself is spec-mandated ("its own forced-error-log arming and armed-row legs"), so the claim was narrowed to capability rather than coverage and the gap deferred.
  - `medium` `patch` `ProviderSecret` points readers at `ProviderStub`'s header as the authority on covered frames, which does not name the new families' -- verified, and it is the sentence that exists to stop a mutation being read as coverage. The exclusion is now stated for `OpenAI.ApplyAuth` and `Gemini.ApplyAuth` in this pass's own file.
  - `low` `patch` "It fails closed." is asserted from a check over two keys while the shipped table declares three -- verified: the `anthropic` row still names its shipped adapter under this catalog. Claim narrowed to the two rows the guard covers, and the answer for that family (`CatalogAnthropicStub`) named. The layer's wider guard was refuted: counting every row that names a shipped adapter would refuse the table for every current caller.
  - `medium` `patch` AC7's replacement sentence contradicts the project's own cited source -- verified at `ToolDefAdapter.cls:29` (dated 2026-09-18): Gemini's grammar admits dots, so it is not a narrowing of OpenAI's. Corrected at AC7 and in `Adapter.cls`'s own doc.
  - `low` `patch` AC7 quotes `VENDORNAMEPATTERN` while the test asserts `SHAREDNAMEPATTERN` -- grouped with the entry above; AC7 now says which pattern the test applies and why. The half claiming the earlier Rejected entry was contradicted is refuted: that entry rejected changing the regex, and this pass changed the justification clause.
  - `low` `patch` `SHAREDNAMEPATTERN`'s comment gives one of several reasons and carries an unlabeled inference -- grouped with the AC7 entry: the comment now names OpenAI's leading digit and hyphen as well as the underscore, and the unsourced Gemini length bound carries `(inference)`.
  - `low` `patch` this pass moved the line DW-1199's evidence anchors at -- verified: the inserted arming legs pushed `HeaderNames` from `:107` to `:166`. Anchor corrected.
  - `low` `patch` the rewritten deferred entry anchors at prose, not code -- verified: `Transport` is declared at `:37`, not `:35`. Corrected.
  - `low` `patch` DW-1191's severity fell medium to low while the duplication it tracks grew -- verified: the pass added ~45 lines to the second copy. Severity restored to medium, what closed named in the summary, and the unpinned-equality residual added to the evidence.
  - `false` `reject` the pass added non-open-item prose to an `oversized` spec -- refuted: that rule binds the lead's next re-open. The additions are the open items' own mandated output (item 4's spec-sentence correction, Rule 19's `mutation:` lines) and the workflow's required Finalize section.
  - `low` `patch` `ForceErrorLog` widened from a private instance method to a public class method with no reason given -- verified. The doc now names the two `ApplyAuth` overrides as the only reason, and the double guard was already in place.
  - `low` `patch` the rewritten class header miscounts the rungs -- verified: legs seven onward also resolve through `SecretProbe` on the `env` rung. The enumeration now reads ten legs, eight of them environment-rung.
  - `low` `reject` `DriveTheNewFamilies` restores the catalog seam only on the success path -- verified real, and bounded: `OnAfterOneTest`'s `Reset` clears it and the class has one test method. Rejected: no developer meets it in ordinary use and the fix adds a Try/Catch rather than correcting a line.
  - `low` `patch` the new legs fail hard where the credentials-rung leg skips, and the residual-risk bullet predates them -- the method doc already states the resolver dependency; the new dependency is now named under `## Auto Run Result`'s residual risks.

From the Edge Case Hunter layer:

  - `low` `patch` an answered row other than openai/gemini still names a shipped adapter -- duplicate of the fail-closed claim entry; the claim was narrowed and the proposed wider guard refuted.
  - `low` `patch` a removed `STUBIDENTITY` makes expected and actual both empty, so the served-by assertion degenerates -- verified by the layer live on slot B (`$Parameter` answers `""` for an undefined parameter). Each leg now asserts the expected identity is non-empty first. The assertion is falsifiable for the case it exists to catch, demonstrated by the `OPENAISTUB` mutation.
  - `low` `reject` a renamed or uncompiled stub makes `$Parameter` raise, aborting the method -- verified real and loud: a raise fails the method and the class reports failed; it is not a silent pass. Rejected: the fix adds an existence branch, and the catalog seam is cleared by `OnAfterOneTest` regardless.
  - `low` `patch` `MoveArmedRow`'s new copy is reached by no test -- duplicate; claim narrowed, gap deferred.
  - `low` `reject` a future `RequestUrl` override could interpolate an ungated value into the path -- `wontfix-theoretical`: `Gemini.RequestUrl` is the only override and gates with `MODELPATTERN`, and the doc now states the obligation. Real if a second override interpolates a caller-supplied value.
  - `medium` `patch` AC7's "Gemini's narrows" -- duplicate of the grammar entry; patched.
  - `low` `patch` the fail-closed mutation's blast radius is mis-scoped -- grouped with the verification-gap entry below; the mutation line was replaced with one that isolates the guard, and its blast radius measured.

From the Verification Gap Reviewer layer:

  - `medium` `patch` the new AD-35 legs never assert that the two new families wrote a forced entry, so deleting all three `ForceErrorLog()` calls leaves the class green on legs one to six's cumulative count -- filed pre-verified and confirmed by reading the assertions. Each leg now brackets its own `ErrorLogCount()`, and a mid-flight leg per family reaches the `ApplyAuth` frame.
  - `medium` `patch` the fail-closed guard has no assertion that can fail if it is removed, and the named mutation reddens with or without it -- filed pre-verified. Added `Test/CatalogProbeDrift` and `OpenAIAdapter.TestADriftedShippedKeyLeavesTheReAdaptingCatalogAnsweringNothing`; the guard-removal mutation was demonstrated red on that method alone, five of six green.
  - `low` `defer` `ProviderStubTransport.MoveArmedRow` has no executed test host -- filed pre-verified with disposition `defer`, taken: the leg is spec-mandated, so it stays and the header stops claiming coverage. Recorded in `deferred:`.
  - `false` `reject` the rework's changes are outside every verification path and no run is recorded -- refuted by this pass's throwaway run, which the layers could not see because Finalize had not yet written it.
  - `low` `patch` AC7's corrected sentence still misdescribes its own test -- duplicate of the grammar entry.
  - `medium` `patch` nothing pins the two copies of the scripted transport equal -- verified; folded into DW-1191's evidence, which is what tracks the duplication.
  - `low` `patch` the deferred entry's anchors cite a doc-comment line -- duplicate; corrected.

From the Intent Alignment Auditor layer:

  - `false` `reject` the intent's expectations live at the shipped-wire surface and this diff changes none of it -- descriptive and correct: the shipped behavior landed upstream, and a rework closing proof obligations is not expected to move it.
  - `false` `reject` matrix row 3's doc narrows rather than lands -- the retraction is item 4's own deliverable: the previous sentence claimed containment the code does not give.
  - `medium` `patch` the new proof stands one frame below the two methods the item names -- duplicate of the frame-exclusion entry; the exclusion is now stated rather than left to `ProviderStub`'s header.
  - `low` `reject` the served-by assertion, which needs no error seed, sits inside the seed gate -- by design: the class refuses anywhere the seed is absent because an application error cannot be un-logged, and the same drift has an instance-independent pin in `OpenAIAdapter`.
  - `false` `reject` the stubs' "Nothing else is overridden" argument was weakened -- the sentence was narrowed accurately in the same edit, which is what keeps it true.
  - `false` `reject` `AgentWire.cls:79` is a fence the intent does not name -- the orchestrator granted it and the spec reports it as a footprint extension; the fence the intent does name, `AgentViolation.cls`, is untouched.
  - `false` `reject` AC7 was always beyond the intent -- descriptive; the corrected wording is the patch above.
  - `low` `patch` the deferred entry's anchor lands two lines up -- duplicate; corrected.

## Auto Run Result

Status: done
Blocking condition: none

**What this pass changed.** The four open `[Review]` items, and nothing else.

1. **AD-35's automated proof now covers all three families.** `Test/ProviderStubTransport` carries
   its own forced-error-log arming and armed-row legs, reading `ProviderStub`'s globals and public
   arming API; `Test/OpenAIStub` and `Test/GeminiStub` each gained an `ApplyAuth` override that
   delegates with `##super` and then forces the armed entry. `Test/ProviderSecret` drives four new
   legs -- a refusal and a mid-flight raise on each shipped non-canonical row over
   `CatalogProbeShipped` -- asserting which stub served each and **how many** forced entries it
   wrote. `ProviderStub.cls` is byte-identical to HEAD.
2. **`Test/AgentWire.cls:79`** reads `##class(OcuPilot.Test.AgentRules).#UNKNOWNPROVIDER`. That one
   line is the file's only difference from HEAD.
3. **`Test/CatalogProbeShipped.Table` fails closed** on the two rows it re-adapts: unless each key
   matched exactly one row it clears the object and answers an error `%Status`, so `Catalog.Row`
   resolves nothing and the port refuses before `Invoke`. `Test/CatalogProbeDrift` and
   `OpenAIAdapter.TestADriftedShippedKeyLeavesTheReAdaptingCatalogAnsweringNothing` pin it.
4. **Wrong claims replaced at their origin:** `Base.RequestUrl`'s containment sentence (the path is
   not checked there), `Adapter.cls`'s `SHAREDNAMEPATTERN` grammar sentence and AC7.

**Files changed.** `Test/ProviderStubTransport.cls` (two arming legs, and its header now says the
row-move leg is capability rather than coverage); `Test/OpenAIStub.cls`, `Test/GeminiStub.cls` (the
`ApplyAuth` leg); `Test/ProviderSecret.cls` (legs seven to ten, exact entry counts, the frame
exclusion for the new families); `Test/CatalogProbeShipped.cls` (the guard, scoped to its two rows);
`Test/CatalogProbeDrift.cls` (new); `Test/OpenAIAdapter.cls` (the fail-closed test);
`Kernel/Provider/Base.cls`, `Test/Adapter.cls` (one corrected sentence each, doc only);
`Test/AgentWire.cls` (the one granted value).

**Review findings.** 43 findings across four layers -- high 0, medium 5, low 15, false 23.
**16 patched** (5 medium, 11 low): the two new legs' forced-entry production was unasserted and the
mid-flight case undriven; the fail-closed guard had no assertion that could fail if removed; the
`ApplyAuth`-frame exclusion was not stated for the new families; AC7's replacement sentence
contradicted `ToolDefAdapter.cls:29`'s dated citation (Gemini admits dots, so it is not a narrowing
of OpenAI's); DW-1191 understated the residual it now tracks; plus ten doc, anchor and assertion
corrections. **1 deferred:** `ProviderStubTransport.MoveArmedRow` has no executed test host -- the
leg is spec-mandated, so the header stopped claiming coverage instead. **23 rejected**, the
substantive ones: the vacuity claim against legs seven and eight (`Base.Invoke:157-163` refuses an
empty key before the transport, so `ApplyAuth`'s guard is unreachable there); "the code was never
executed" (refuted by this pass's throwaway run); and the stale `## Auto Run Result` /
`## Review Triage Log` / `review_loop_iteration` observations, which read the spec between the
review layers and this section.

**One measured surprise, recorded because it changed the work.** The first form of the new
assertion was "the entry count grew". It reddened to **neither** mutation: each leg's `ApplyAuth`
override and the transport's own leg each satisfy it alone. The assertions are now exact
(`REFUSALENTRIES` 2, `RAISEENTRIES` 1), and both legs are individually pinned.

**Verification**, all on slot B; no verification of OcuPilot's own behavior opened a provider socket.

- `uv run scripts/check-objectscript.py` clean (489 files, 21 rules);
  `uv run scripts/test_check_objectscript.py` 126/126; `bash scripts/lint-docs.sh` clean.
- Whole tree loaded and compiled `cuk` on `ocupilot-slot-b` -- 489/489, no errors.
- From `ui/`: `npm run build` and `npm test` green and unchanged (1044 `node --test`, 640 component).
  No file under `ui/` changed this pass.
- **Whole sweep on throwaway `ocupilot-b-ci`** (mine; `up` and `down` both run here), over the exact
  committed tree: **128 classes, 1247 tests, 0 failed, 0 probe leftovers, 0 overlaps, 0 foreign
  runs.** `ProviderSecret` green (run 85), `OpenAIAdapter` 6/6 (run 76), `GeminiAdapter` 4/4 (run
  53), `Adapter` 20/20 (run 8), `AgentRules` 18/18 (run 16), `AgentWire` 17/17 (run 20).
  `AgentViolation` 8 (run 19) and `TurnStore` 11 (run 125) green **unedited**.
- **Four mutations demonstrated**, each applied to the container's source copy, whole tree
  recompiled, red observed, reverted, `diff -r` confirming the copy identical to the repo again and
  `git status --short -- src ui` carrying only this pass's intended changes throughout:
  (a) `Gemini.RequestUrl` appending `?key=` + the credential -> red on the gemini legs' three
  variable-table assertions, every other leg green; (b) dropping
  `ProviderStubTransport.Transport`'s `ForceErrorLog()` -> red on both refusal legs' counts alone;
  (c) dropping both stubs' `ApplyAuth` overrides -> red on all four, the mid-flight legs reading 0;
  (d) deleting `CatalogProbeShipped.Table`'s refusal -> red on the new drift test alone, five of six
  green in that class.
- `git diff --name-only a42aa488..` over `src ui module.xml` touches `src/OcuPilot/**` only.

**Residual risks.**

- Mutation (d)'s red **is** the hazard: with the guard gone the drifted row keeps the shipped
  `adapterClass`, and the measured failure text was the vendor's own
  `Incorrect API key provided: probeope****...` -- one real POST left the instance, carrying the
  fabricated probe key, which the vendor rejected. The `mutation:` line says to run it only where
  outbound egress is acceptable. No other verification here reached a provider.
- Legs seven to ten resolve `api.openai.com` and `generativelanguage.googleapis.com`, so the AD-35
  sweep now carries the resolver dependency the two adapter suites already had; a leg with no
  resolver reddens on its served-by assertion rather than passing quietly.
- A local inside the shipped `OpenAI.ApplyAuth` or `Gemini.ApplyAuth` is reachable by no forced
  entry -- the stubs' overrides delegate first, so those frames have returned. What is proven for
  both new families is that no frame live during their provider work holds the credential. Stated at
  `ProviderSecret`'s mutation paragraph so a mutation there is not read as coverage.
- DW-1191 is back at `medium`: this pass grew the second copy of the scripted transport by the two
  arming legs, and no test pins the two copies equal.
