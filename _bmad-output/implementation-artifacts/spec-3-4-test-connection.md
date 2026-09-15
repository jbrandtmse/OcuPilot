---
title: 'Story 3.4: Test connection'
type: 'feature'
created: '2026-09-15'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred:
  - summary: >-
      AC5 is entirely client work -- the inline progress indicator, `aria-disabled` for the
      duration, focus staying on the button -- and there is no `ui/` surface for this screen.
      The same entry carries the call order the route imposes on the form: create (disabled),
      store the key, test, then save with `enabled` true.
    evidence: |-
      `ui/src/app/areas/` holds `home` and `logs` only; `epics.md` Story 3.5 already owns the
      `form-page` contract and the button-primary pattern (EXPERIENCE.md:367) states the
      progress/`aria-disabled`/focus rule. The key cannot be stored before the definition
      exists: `POST /agent/definitions/:id/credential` needs an id.
    location: 'Story 3.5 (The Definition form)'
    severity: medium
  - summary: >-
      The published failure sentence assumes the provider supplied text, and only one of the nine
      `PROVIDER.*` codes ever carries `detail.providerText`. What the form renders for the other
      eight is undecided.
    evidence: |-
      `strings.ts:233` publishes one failure string ending `Provider said: <text>`.
      `Kernel/Provider/Base.Fault` **:358** attaches the field only when a caller passes text, and
      the one caller that does is the non-retryable HTTP branch **:208**, whose code is always
      `PROVIDER.REFUSED`; every other `Fault` call site (**:116**, **:120**, **:132**, **:221**,
      `ProviderPort.Refuse` **:408**) passes `""`, and `PROVIDER.TLS` **:231** builds a fault with
      no detail at all. The envelope's own `reason` (`ReasonFor` **:385**) is OcuPilot's written
      sentence for each of the eight.
    location: 'Story 3.5 (The Definition form)'
    severity: medium
  - summary: >-
      The rail attention dot's third condition -- "Test connection failed since the last save" --
      has no stored source. This story deliberately records nothing on a failed test.
    evidence: |-
      EXPERIENCE.md:342 states the condition. `Kernel/State/Agent.cls` carries `Enabled` **:94**
      and `ConnectionVerified` **:99** and no failure stamp; a failed test here writes nothing,
      so a transient provider outage cannot disable a working definition.
    location: 'Story 3.5 or 3.6, whichever owns the dot'
    severity: low
---

<intent-contract>

## Intent

**Problem:** Nothing can set `ConnectionVerified`, so no definition can be enabled through the wire
and a bad key, a wrong endpoint or a missing TLS configuration first shows up inside a turn.

**Approach:** One route, `POST /agent/definitions/:id/test`, that merges an optional body over the
stored definition exactly as `PUT` does, validates it, makes **one** bounded provider call through
the already-shipped `ProviderPort.InvokeDraft`, and on success records `ConnectionVerified` on the
stored row when the values tested were the stored ones. Nothing else about the definition changes.

## Boundaries & Constraints

**Always:**

- The call goes through `ProviderPort.InvokeDraft`, which applies AD-42's scheme and resolved-address
  rules, AD-32's TLS configuration and the adapter the catalog row names -- the path a turn takes.
- The route gates on `OcuPilotAdmin:USE` before anything else, through the shipped
  `IsAdministrator` / `RenderForbidden` pair; the port's own `DRAFTPAIRS` gate is the backstop.
- Refusals are the shipped envelopes: `{field, code}` violations in Story 3.1's 422 for field faults,
  and the port's own fault rendered through `Api.Error.Render` -- `Api/LogPage.cls:42`'s idiom.
- The reply is bounded on the instance before it leaves, and is model output: untrusted content
  (AD-11), never a log line, never part of a change record.
- Compile the **whole tree** through the IRIS MCP tools with `server: "ocupilot-iris"`;
  `uv run scripts/check-objectscript.py` clean (`check_route_ordering`, `check_handler_wire_tests`,
  `check_naming`, `check_state_package_isolation`).

**Never:**

- **No real outbound call to any provider, from any test.** Every leg runs against
  `Test/ProviderStub` in process, or is a wire leg that refuses before the transport.
- No key in the test body and no key argument anywhere: the credential is resolved by
  `Base.Invoke` straight onto its own property, and an argument would bind it to a local in two
  frames, which is what `^%ETN` captures and OcuPilot renders (AD-35, AD-48).
- No client file and no `strings.ts` key -- the three strings AC2 and AC3 name are already published
  (`strings.ts:231,233,235`). AC5's rendering is Story 3.5's.
- No second read-only or kill-switch enforcement point (AD-30). No `$System.Security.Audit()` call:
  Story 3.8 owns registration and emits from the one `LogChange` seam (AD-15).
- No principal, SSL configuration, credential entry, definition or `^ERRORS` write left on the live
  `ocupilot` container; no `docker compose up`/`down` against it.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Test a stored definition, provider answers | admin, no body, credential resolves | 200 `{connected:true, reply, replyTruncated, latencyMs, connectionVerified:true, testedAsStored:true}`; the row's `ConnectionVerified` is 1, `Enabled` and `DefaultMark` untouched | none |
| Test with edits that change no security field | body sets `model` | as above, `testedAsStored` true | the model is not a `SecurityFields()` member, so Story 3.1's own rule leaves verification standing |
| Test with edits that change a security field | body sets `endpointUrl` | the call is still made and reported; `connectionVerified` false, `testedAsStored` false; **the row is not written** | verification is a property of the stored row (`ConnectionVerified`'s own contract, **:96**) |
| Provider refuses | stub answers 401 with an Anthropic error body | 502, `unavailable`, `PROVIDER.REFUSED`, `detail.providerText` = the body's `error.message` **only**; no flag changes | the raw body reaches `LogRaw` and nowhere else (AD-39) |
| Reply longer than the bound | stub answers a long text block | 200, `reply` cut to `TESTREPLYMAX`, `replyTruncated` true | the cut is on the instance, so no client can render more |
| Retryable status | stub answers 429 | **one** transport call, then `PROVIDER.UNAVAILABLE`; no backoff wait is taken | a person is holding focus on a button; retry belongs to a turn |
| Link-local endpoint in the body | `https://169.254.169.254/latest/meta-data` -- **https**, so the scheme rule passes and the address rule is the one that fires (`Validate` **:144-151** reports only one of the two) | 422, `AGENT.ENDPOINT.LINKLOCAL` on `endpointUrl`, before any call | no escape, whatever `markedLocal` says (AD-42) |
| Private-network endpoint | `https://10.1.2.3/v1` | the call is attempted | RFC-1918 is not refused -- `Kernel/Egress.cls:21-23` |
| Loopback endpoint, row disallows local | `https://127.0.0.1/v1` | 422, `AGENT.ENDPOINT.ADDRESS` | allowed only when marked local **and** the catalog row admits it |
| Endpoint resolves to nothing | a name with no A or AAAA record | the route accepts it; the port refuses `PROVIDER.EGRESS`, which `HttpFor` **:371** answers 502 for | write time deliberately does not judge resolvability (`AgentRules.AddressViolation` **:230**) |
| Credential does not resolve | `envVarName` naming an unset variable | 503, `PROVIDER.CREDENTIAL` naming the reference; **no flag cleared** | `FlagUnresolvedCredential` **:120** is `Invoke`'s alone; a draft test is how a disabled definition is re-enabled |
| Not an administrator | authenticated, no `OcuPilotAdmin:USE` | 403, `AUTH.NOPRIVILEGE`, `detail.failedPair` | shipped `RenderForbidden` **:534** |
| Unknown id | any body | 404, `AGENT.NOTFOUND`, before the body is read | shipped `RenderNotFound` **:544** |
| Set default onto a definition that is not enabled | `POST /agent/definitions/:id/default` | 422, `AGENT.DEFAULT.DISABLED` on `default`; the marker does not move | **DW-330** |

</intent-contract>

## Code Map

Anchors verified against the working tree, 2026-09-15.

**Already shipped, and already satisfying most of this story**

- `src/OcuPilot/Port/ProviderPort.cls` -- `InvokeDraft` **:151** (gate **:157**, `Normalize`
  **:168**), `Dispatch` **:183**: catalog row **:185**, `keyPrefix`/`authVersion` **:194**, the
  create's canonical endpoint **:200**, `SchemeAccepted` **:209**, `Egress.IsPermitted` **:213**,
  `State.Egress.Resolve` **:222**, `SslConfigurationMissing` **:229**, adapter from the row **:240**
  and dropped **:250**. `Invoke` **:77** reads `Enabled` **:96**; `InvokeDraft` deliberately does not
  **:92-95**. `FlagUnresolvedCredential` **:120** is `Invoke`'s alone.
- `src/OcuPilot/Kernel/Provider/Base.cls` -- `Invoke` **:102** (credential straight onto the property
  **:114**, shape gate **:119**, cleared on every exit **:128,:137**), `Attempts` **:154**
  (`maxAttempts` **:157**, non-retryable branch sets `detail.providerText` **:208**, retry exhausted
  **:212**), `NewRequest` **:233** (`Timeout` **:244**), `Fault` **:358**, `HttpFor` **:371**,
  `ReasonFor` **:385**.
- `src/OcuPilot/Kernel/Provider/Anthropic.cls` -- `MapResponse` **:105** (text blocks concatenated
  **:132**), `ProviderMessage` **:149** (`error.message` only).
- `src/OcuPilot/Kernel/Provider/Response.cls` -- `Text` **:24**, `LatencyMs` **:40** (measured across
  every attempt, `Base.Invoke` **:138-140**), `StopReason` **:20**.
- `src/OcuPilot/Kernel/State/Egress.cls` -- `#DEFAULTTIMEOUT` 90 **:22**, `#DEFAULTMAXATTEMPTS` 3
  **:27**, `Resolve` **:68**. **AC2's ten-second bound sits inside the shipped default.**
- `src/OcuPilot/Kernel/State/Agent.cls` -- `ConnectionVerified` **:99** ("as currently configured";
  every path today only clears it), `Enabled` **:94**, `SecurityFields()` **:122**,
  `SnapshotSecurityFields` **:131**, `GuardedUpdate` **:181**, `GuardedClearVerification` **:219**
  (the shape to mirror), `SetDefaultGuarded` **:283** (existence check only -- DW-330),
  `GuardedRebalanceDefault` **:343** (case 2 **:359-367** is what relocates the marker),
  `ResolveDefault` **:320**.
- `src/OcuPilot/Api/Definitions.cls` -- `Fields()` **:55** (`connectionVerified` not writable),
  `HandleUpdate` **:204** and its merge **:230-243**, `HandleSetDefault` **:299**,
  `ValuesFromRow` **:617**, `MergeBody` **:645**, `OpenDefinition` **:600**, `IsAdministrator`
  **:524**, `RenderForbidden` **:534**, `RenderNotFound` **:544**, `RenderBadBody` **:554**,
  `RenderViolations` **:590**, `BodyIsReadable` **:570**, `LogChange` **:776**, `CatalogClass`
  **:93**, `SecretClass` **:516**.
- `src/OcuPilot/Kernel/AgentRules.cls` -- `Normalize` **:53**, `Validate` **:104** (the
  enable-unverified rule **:171**), `SchemeAccepted` **:257**, `AddressViolation` **:230**.
- `src/OcuPilot/Kernel/Egress.cls` -- `IsPermitted` **:121**, `Classify` **:86**; the header
  **:21-23** is the authority for "private ranges are not refused".
- `src/OcuPilot/Api/Router.cls` -- `UrlMap` **:65-71**; `:id/default` **:65** and `:id/credential`
  **:66** are the sub-resource precedent and the ordering rule.
- `src/OcuPilot/Api/LogPage.cls` -- `PortClass()` **:21** (the seam to copy) and the port-fault
  render **:42**.
- `src/OcuPilot/Api/Error.cls` -- `Render` **:492**, `CODEPATTERN` **:470**, the nine `PROVIDER.*`
  codes **:194-242**, the `AGENT.*` neighborhood **:339-462**.
- `src/OcuPilot/Api/Response.cls` -- `JSON` **:13**.

**Test substrate, all of it reusable**

- `src/OcuPilot/Test/ProviderStub.cls` -- `QueueAnswer` **:50**, `Calls()` **:117**, `Recorded`
  **:127** (`timeout`, `sslConfiguration`, `body`, `headerNames`), `Waits()` **:134**, `Reset`
  **:35**. No socket is opened by anything above it.
- `src/OcuPilot/Test/CatalogProbe.cls` -- `#LOCALKEY` `probe-local` **:29** whose `adapterClass` is
  the stub **:41**; `#PROBEKEY` names a different stub, which is what makes "the adapter comes from
  the row" observable.
- `src/OcuPilot/Test/ProviderPortProbe.cls` -- port subclass with five switches (**:18-75**).
- `src/OcuPilot/Test/DefinitionsProbe.cls` -- handler subclass overriding `CatalogClass` **:26** and
  `SecretClass` **:31**; add `PortClass` here.
- `src/OcuPilot/Test/AgentWire.cls` -- `Call` **:44**, the canonical route roster **:52**,
  `#PROBEPREFIX` **:19**, `OnAfterOneTest` **:35**. `Test/AgentFixture.RemoveProbeDefinitions` is the
  cleanup every agent class uses. `Test/Http.AbsoluteRequest` **:206** is the wire driver.

## Tasks & Acceptance

**Execution:**

1. `src/OcuPilot/Api/Error.cls` -- add `AGENTDEFAULTDISABLED = "AGENT.DEFAULT.DISABLED"` in the
   `AGENT.*` neighborhood, with its producer named in the doc comment. Must satisfy `CODEPATTERN`.
2. `src/OcuPilot/Kernel/State/Agent.cls` -- add `GuardedSetVerification(pId) As %Status`, the mirror
   of `GuardedClearVerification` **:219**: open, snapshot the security fields, set
   `ConnectionVerified` to 1, `GuardedUpdate` with that snapshot -- so the timestamp and the default
   rebalance stay in one place and no field reads as changed. It never touches `Enabled`: enabling is
   a separate act the operator takes, which `Validate` **:171** then permits.
   In `SetDefaultGuarded` **:283**, refuse an explicit set-default onto a definition that is not
   enabled, with a distinguishable status, and say in the header why: the marker means "in force",
   `ResolveDefault` already answers `""` for a disabled one, and `GuardedRebalanceDefault` case 2
   would relocate it on the next unrelated write. **(DW-330.)**
3. `src/OcuPilot/Port/ProviderPort.cls` -- in `Dispatch` **:183**, after `State.Egress.Resolve`
   **:222**, lower `tSettings("maxAttempts")` to `pValues("maxAttempts")` when that is a positive
   integer **below** the resolved bound. It can only lower, never raise; `ValuesFor` **:256** never
   sets it, so a turn is unchanged. Document the key on `InvokeDraft`'s "normalized and added to in
   place" paragraph **:147-150**.
4. `src/OcuPilot/Api/Definitions.cls` -- add `PortClass()` returning `OcuPilot.Port.ProviderPort`
   (the `LogPage.cls:21` seam) and `HandleTest(pId)`:
   administrator gate, 404 on an unknown id, read and merge the body over `ValuesFromRow` exactly as
   `HandleUpdate` **:221-243** does -- `ReadRequestBody`, `BodyIsReadable`, `RenderBadBody`,
   `MergeBody`, with `connectionVerified` forced to the stored value --
   `AgentRules.Normalize`, `AgentRules.Validate(.tValues, pId, .tViolations)` -> `RenderViolations`;
   then set `tValues("maxTokens")` to `#TESTMAXTOKENS` and `tValues("maxAttempts")` to 1, build the
   one-message array from `#TESTPROMPT`, send no tools and no system prompt, and call
   `InvokeDraft` through `PortClass()`. A fault renders through
   `Api.Error.Render(tHttpStatus, tFault.error, tFault.reason, tFault.code, tFault.detail)`.
   On success: compare each `SecurityFields()` member of the merged values against the stored row;
   when all match, `GuardedSetVerification(pId)` and `LogChange("test", pId, before, after)`; answer
   200 with `connected`, `reply` (cut to `#TESTREPLYMAX`), `replyTruncated`, `latencyMs`,
   `connectionVerified` and `testedAsStored`. **No reply text enters `LogChange`.**
   Three parameters carry the budget, each with its reason in the doc comment:
   `TESTMAXTOKENS = 32` (enough for one short sentence, two orders below the definition's ceiling),
   `TESTREPLYMAX = 200` (characters, the bound AC2 names), and `TESTPROMPT`, one short ASCII
   sentence asking for a one-line acknowledgement -- a build-time constant, never composed from
   anything read at runtime (AD-11).
5. `src/OcuPilot/Api/Definitions.cls`, `HandleSetDefault` **:299** -- refuse a definition whose
   `Enabled` is 0 with `RenderViolations` carrying `{field:"default", code:"AGENT.DEFAULT.DISABLED"}`
   before calling `SetDefaultGuarded`. Belt and braces with task 2, the idiom this handler already
   uses twice for server-owned fields (**:176**, **:235**). **(DW-330.)**
6. `src/OcuPilot/Api/Router.cls` -- add
   `<Route Url="/agent/definitions/:id/test" Method="POST" Call="AgentDefinitionTest"/>` beside
   `:id/default` **:65** and above every single-segment `:id` route (`check_route_ordering`), plus the
   thin `Call=` wrapper.
7. `src/OcuPilot/Test/DefinitionsProbe.cls` -- add `PortClass()` answering
   `OcuPilot.Test.ProviderPortProbe`, so the in-process legs drive the stub adapter through the probe
   catalog without touching the shipped handler.
8. `src/OcuPilot/Test/AgentConnection.cls` -- **new.** The in-process legs through
   `DefinitionsProbe` over a `probe-local` definition: the 200 body and every key in it; the flag
   written; `testedAsStored` false and the row unwritten when a security field is edited; the
   `PROVIDER.REFUSED` envelope carrying `detail.providerText` and **not** the raw body; the reply
   cut at the bound; one transport call on a queued 429 with `Waits()` empty; and the request the
   stub recorded carrying the test budget rather than the definition's `maxTokens`.
   Also the wire legs, which must refuse **before** the transport: 403, 404, 422 on a link-local
   endpoint, and `PROVIDER.CREDENTIAL` from a definition whose `envVarName` names a variable this
   test first asserts is unset -- so "no socket was opened" is a checked precondition, not a hope.
   Definitions named with the shared probe prefix and removed in `OnAfterOneTest`.
9. `src/OcuPilot/Test/AgentWire.cls` -- add the new route to the canonical roster **:52** and its
   ordering assertion; add the DW-330 wire leg (set default onto a disabled definition -> 422,
   `AGENT.DEFAULT.DISABLED`, and the marker did not move).
10. `src/OcuPilot/Test/AgentState.cls` -- add `GuardedSetVerification`'s own legs (sets the flag,
    leaves `Enabled` and the marker alone, stamps `UpdatedAt`) and `SetDefaultGuarded`'s refusal.
11. `src/OcuPilot/Test/ProviderPort.cls` -- add the attempt-ceiling pair: with
    `pValues("maxAttempts")` 1 a queued 429 makes one call; without it, three. And that a value above
    the resolved bound does not raise it.

**Acceptance Criteria:**

- **AC1** -- Given an administrator testing a definition with edits, when the route runs, then
  exactly one transport call is made, carrying the test budget rather than the definition's
  `maxTokens`, through the adapter the catalog row names, with the instance's TLS configuration and
  timeout on the request -- the same `Dispatch` a turn takes.
- **AC2 (server half)** -- Given the provider answers, when the route returns, then the body carries
  the reply cut to the declared bound with `replyTruncated` saying so, the measured `latencyMs`, and
  `connectionVerified`; and OcuPilot's own per-call budget (`#DEFAULTTIMEOUT` 90 s, one attempt, no
  backoff) never aborts or delays a call that would answer within ten seconds. See Design Notes for
  why that is the pinnable half.
- **AC3 (server half)** -- Given the provider refuses, when the route returns, then the envelope
  carries `PROVIDER.REFUSED` with `detail.providerText` holding the provider's own `error.message`
  and nothing else of the body, and the definition's `Enabled` and `ConnectionVerified` are
  unchanged -- so a later `PUT` with `enabled` false still succeeds and one with `enabled` true is
  refused by the shipped `AGENT.ENABLE.UNVERIFIED` rule.
- **AC4** -- Given an endpoint in the link-local range, when it is tested, then it is refused with no
  escape; private-network hosts are attempted; a loopback or instance address is attempted only where
  the definition is marked local on a catalog row that admits it -- the same `Kernel.Egress`
  judgement at write time (the route's `Validate`) and at call time (the port's `IsPermitted`).
- **DW-330** -- Given a definition that is not enabled, when an explicit set-default names it, then
  it is refused with `AGENT.DEFAULT.DISABLED` and the marker does not move; the automatic marker
  `GuardedRebalanceDefault` case 1 places on a disabled definition is unaffected, being a placeholder
  rather than a claim.
- **Integration AC** -- Given an HTTP client holding only the published route contract, when it posts
  to `/agent/definitions/:id/test` without OcuPilot's administrative resource, with an unknown id,
  with a link-local endpoint, and with an unresolvable credential reference, then it observes 403,
  404, 422 and 503 in the shipped envelope with the codes above -- each a code the shipped path can
  only reach before the transport, which is how "no socket was opened" is observable from a process
  that cannot read the stub's counter. Exercised by `OcuPilot.Test.AgentConnection` against the
  running instance.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs:** AD-42 (egress, the credential ladder, retry, "Test connection exercises the
configured endpoint with a minimal budget"), AD-32 (TLS at install), AD-35 and AD-48 (no credential
reaches a surface OcuPilot displays), AD-39 and AD-12 (one envelope, vendor text normalized), AD-11
(model output is untrusted content), AD-8 and AD-21 (gate at call time, no anonymous caller), AD-9
(protected state, escalation confined to the storage call), AD-7 as amended (a write to OcuPilot's
own state is not a mutation of the instance), AD-30 (no second switch enforcement point).

**"As edited, before save" reads as a merge over a stored row.** A definition must exist before its
key can be stored -- `POST /:id/credential` takes an id -- and the ladder resolves a *reference*, not
a pasted value, so a test of an unsaved definition could only ever test the environment rung
**(inference)** -- the epic does not spell the form's order.
Passing a key in the test body was rejected: `Base.Invoke` resolves the credential straight onto its
own property precisely so no frame binds it to a local, and an argument would undo that in two frames
(AD-48). So the form's order is create (disabled), store the key, test, save with `enabled` true --
recorded as a deferred entry for Story 3.5.

**Verification is a property of the stored row.** `ConnectionVerified`'s own contract is "as
currently configured", and `GuardedUpdate` clears it whenever a `SecurityFields()` member changes. So
a test whose merged security fields differ from the stored ones reports its result and writes
nothing; one whose non-security fields differ (the model, the tuning) still sets the flag, because
Story 3.1 already decided those changes do not invalidate a verification. One declaration,
`SecurityFields()` **:122**, now read by three call sites.

**One attempt, not the instance's three.** AC1's bolded "one" and AC5's "focus stays on the button
for the duration" both point the same way: a retry ladder can add two honored `Retry-After` waits of
up to 30 s each (`Retry.cls` `#MAXRETRYAFTERSECONDS`), which makes the interaction unbounded from the
operator's side, and a 429 already answers the question the operator asked -- the key is accepted and
the provider is busy. The turn keeps retry; nothing AC1 names about "the same path" (TLS, egress,
adapter, credential, the request the adapter builds) changes.

**AC2's ten seconds, without an outbound call.** Ten seconds is a latency expectation about a cloud
model, not behavior OcuPilot implements, so no test can assert it without the call this story may not
make. What is pinnable, and what is pinned, is that OcuPilot's own budget cannot be the thing that
misses it: the request's `Timeout` read back from the stub equals the resolved setting, the shipped
default is 90 s, and with one attempt no backoff wait is taken (`Waits()` empty). The measured
`latencyMs` is reported to the operator, so the real figure is observable on a real instance rather
than asserted here.

**AC3's text, and why it cannot carry key material.** What is surfaced is `detail.providerText`,
which `Anthropic.ProviderMessage` **:149** reads as the body's `error.message` member alone; the raw
body goes to `LogRaw` and nowhere else. It cannot carry OcuPilot's key material because OcuPilot
never puts the key anywhere the provider could echo into that field: it travels in the `x-api-key`
header, never in the URL, the body or a message, and `Test/ProviderSecret` and `Test/SecretLeak`
already pin that no live frame holds it. What the provider chooses to say is the provider's, so it is
rendered as delimited data attributed to the provider ("Provider said:"), never as OcuPilot's own
voice (AD-11, AD-39), and it is bounded. Story 3.2's rule that "the vendor's raw status text is
discarded" is about an IRIS `%Status` whose text can contain the value being stored; a provider's
error message is neither, and discarding it would leave AC3 with nothing to show.

**Consumes:** Story 3.1 (`Kernel/State/Agent`, `AgentRules`, `Api/Definitions`, `Provider/Catalog`),
Story 3.2 (`Port/ProviderPort`, `Provider/Base`, `Provider/Anthropic`, `Kernel/Egress`,
`State/Egress`, `Test/ProviderStub`, `Test/CatalogProbe`), Story 3.3 (`Secret/Ladder`,
`Test/DefinitionsProbe`), Story 1.9 (`Screen/Gate`), Story 1.1 (`Api/Error`, `Api/Response`,
`Kernel/Fault`).
**Consumed-by:** Story 3.5 (the form's Test connection button and its three published strings),
Story 3.6 (the first-login gate, which clears once a definition is enabled), Story 3.8 (the audit row
over the `test` verb's change record).

## Verification

Every instance-touching check runs on the throwaway (`sh scripts/ci-throwaway.sh up|down`), never on
the live container, which must still hold zero definitions and zero OcuPilot-named credential entries
afterwards. Nothing here opens a socket to a provider.

**Commands:**

- `uv run scripts/check-objectscript.py` -- expected: clean.
- Load and compile the **whole tree** with `mcp__iris-dev__iris_doc_load`, `server:
  "ocupilot-iris"`, `namespace: "HSCUSTOM"`, `path: "/Users/jbrandt/git/OcuPilot/src/**/*.cls"`,
  `baseDir: "/Users/jbrandt/git/OcuPilot/src"`, `compile: true`, `flags: "cku"` -- expected: no error
  text.
- `bash scripts/lint-docs.sh` -- expected: clean.
- From `ui/`: `npm run build` and `npm test` -- expected: unchanged and green (no client file).
- `node ui/tools/ci-runner.mjs --container ocupilot-ci --class <one class>` -- **one class per
  invocation, one invocation per message**, each landed in `%UnitTest_Result` before the next:
  `OcuPilot.Test.AgentConnection`, `OcuPilot.Test.AgentState`, `OcuPilot.Test.AgentWire`,
  `OcuPilot.Test.ProviderPort`, then the regression set `OcuPilot.Test.AgentRules`,
  `OcuPilot.Test.AgentCredential`, `OcuPilot.Test.Provider`, `OcuPilot.Test.ProviderConsumer`,
  `OcuPilot.Test.Egress`. Confirm totals with the `%UnitTest_Result` SQL probe in
  `.claude/rules/objectscript-testing.md`, never the runner envelope.
- `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` -- expected: PASSED,
  zero executed checks is a failure.

**Recorded mutations (Rule 19) -- one per AC. Apply to the throwaway's own `src/`, recompile the
whole tree (a subclass keeps its own compiled copy of an inherited method), observe red, revert, and
confirm `git status --short` and `git diff --stat` unchanged.**

- **AC1** -- `mutation:` drop the `maxTokens` override in `HandleTest` so the definition's own value
  is sent -> the `AgentConnection` leg asserting the recorded request body's `max_tokens` goes red.
  Second `mutation:` in `Dispatch`, ignore `pValues("maxAttempts")` -> the one-call leg goes red at
  three calls with a non-empty `Waits()`.
- **AC2** -- `mutation:` stop cutting `reply` at `#TESTREPLYMAX` -> the bounded-reply and
  `replyTruncated` assertions go red. Second `mutation:` set `NewRequest`'s `Timeout` **:244** to a
  literal 5 -> the leg asserting the recorded timeout equals the resolved setting goes red, which is
  the ten-second half made falsifiable.
- **AC3** -- `mutation:` put the raw body into `detail.providerText` instead of
  `ProviderMessage`'s result -> the leg asserting the field is the `error.message` and carries no
  other member of the body goes red.
- **AC4** -- `mutation:` in `HandleTest`, skip `AgentRules.Validate` -> the link-local wire leg goes
  red, answering the port's `PROVIDER.EGRESS` (502) instead of the 422 on the field.
- **DW-330** -- `mutation:` remove the guard from `HandleSetDefault` -> the wire leg goes red,
  answering 500 from the state layer's own refusal rather than 422. Second `mutation:` remove the
  guard from `SetDefaultGuarded` as well -> it goes red at 200 and the marker moves, which is what
  shows the two checks are independent rather than one written twice.
- **Integration AC** -- `mutation:` remove the 404 branch from `HandleTest` -> the unknown-id wire
  leg goes red at 500. **Not** the administrator gate: removing it leaves the port's own
  `DRAFTPAIRS` gate answering 403 with the same `AUTH.NOPRIVILEGE` code and the same
  `detail.failedPair`, so that mutation cannot redden anything and would be an unfalsifiable
  pin (Rule 19).

**Manual checks:**

- After the run, on the live container: `GET /api/ocupilot/agent/definitions` returns an empty list,
  and `iris_sql_execute` over `OcuPilot_Kernel_State.Agent` counts 0 rows.
- Tear the throwaway down before returning (`sh scripts/ci-throwaway.sh down`), naming the project
  and directory in the run result.
