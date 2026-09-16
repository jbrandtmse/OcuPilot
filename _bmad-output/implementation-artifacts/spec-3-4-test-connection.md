---
title: 'Story 3.4: Test connection'
type: 'feature'
created: '2026-09-15'
status: 'done'
baseline_revision: 'd2bcba2276499ac1fe1b64ca4a46141a3707b63d'
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
  - summary: >-
      `POST /agent/definitions/:id/test` carries the stored credential to whatever endpoint the
      body names, so an OcuPilot administrator who may not read a key's value can direct it at a
      host they control and read it off their own server.
    evidence: |-
      `HandleTest` merges a writable `endpointUrl` and `ConnectionOutcome` calls through whatever
      `testedAsStored` says; `Base.Invoke` puts the resolved key on `x-api-key`. AD-42 already
      grants an administrator the choice of where the instance's data goes and AD-35 is about
      surfaces OcuPilot itself displays, so this is a question about AD-42's own boundary rather
      than a deviation -- but nothing records it as accepted. Settle it by deciding whether a
      body-supplied `endpointUrl` may be tested at all, or only a stored one.
    location: 'Epic 3 decision sheet (AD-42)'
    severity: medium
  - summary: >-
      A test made against values that are not the stored ones records nothing at all, and the
      `test` verb's change record classifies itself `securityChange: false`.
    evidence: |-
      `ConnectionOutcome` calls `LogChange` only inside `If tTestedAsStored`, so the case where the
      credential leaves for an endpoint the row does not hold is the one with no record.
      `LogChange` special-cases only `CREDENTIALVERB`, and a `test` record's change set holds
      `connectionVerified` and `updatedAt`, neither a `SecurityFieldNames()` member.
    location: 'Story 3.8 (the audit row over the change record)'
    severity: medium
  - summary: >-
      `connectionVerified` in the 200 body is the stored row's flag, so an already-verified
      definition tested with an edited endpoint answers `connectionVerified: true` beside
      `testedAsStored: false`.
    evidence: |-
      `ConnectionOutcome` sets `tVerified` from `pStored("connectionVerified")` when the values
      were not the stored ones. Both facts are true of the row, but rendered as one sentence they
      read as "verified against what you just tested". The matrix row states `connectionVerified`
      false unconditionally from an unverified fixture.
    location: 'Story 3.5 (what the form renders from the two fields)'
    severity: medium
  - summary: >-
      A concurrent write during the provider call can leave the row marked verified against
      security values it was never tested with.
    evidence: |-
      `MatchesStoredSecurityFields` runs before `InvokeDraft` and `GuardedSetVerification` runs
      after it; a `PUT` landing in between clears the flags and this then sets `ConnectionVerified`
      back on the new values. Settled by re-comparing the row's security fields inside the write,
      or by passing the snapshot into `GuardedSetVerification` and having it refuse on a
      difference.
    location: 'src/OcuPilot/Api/Definitions.cls (ConnectionOutcome)'
    severity: medium
  - summary: >-
      `SecurityFieldNames()` silently skips a state property that has no wire field, so a security
      field added without one would compare as unchanged everywhere it is read.
    evidence: |-
      The skip is deliberate and documented for `IsSecurityChange` (a property with no wire field
      cannot appear in a change set), but `MatchesStoredSecurityFields` now reads the same list to
      decide whether a row may be marked verified, where the skip is silent data loss. Shipped by
      Story 3.1; a length check against `Agent.SecurityFields()` would close it.
    location: 'src/OcuPilot/Api/Definitions.cls (SecurityFieldNames)'
    severity: low
  - summary: >-
      `check_handler_wire_tests` keys a `:param` route on its dispatch class, so any new `:param`
      route passes the gate on a sibling class's existing wire assertions.
    evidence: |-
      `LITERAL_ROUTE_RE` in `scripts/check-objectscript.py` excludes `:`, so the key falls back to
      the dispatch class -- `OcuPilot.Api.Router`, which `Test/AgentWire` already names. The gate
      reads as per-route coverage and is class-wide for every id-taking route. Shipped by Story
      1.x, not this change.
    location: 'scripts/check-objectscript.py (check_handler_wire_tests)'
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

### Already shipped, and already satisfying most of this story

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

### Test substrate, all of it reusable

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
   `TESTMAXTOKENS = 32` (enough for one short sentence, three orders below the definition's ceiling),
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

- Task 4's provider call, flag write and answer construction sit in
  `Api/Definitions.ConnectionOutcome`, which `HandleTest` calls after its gate, 404, body read and
  validation. `HandleTest` still renders through `RenderViolations`, `Api.Error.Render` and
  `Api.Response.JSON` exactly as the task states. The split is what task 8's in-process legs need: a
  `%UnitTest` process has no `%response`, so a handler that renders cannot be driven there at all.
- Task 8's **403 wire leg** is one entry added to `Test/AgentWireSecurity`'s refusal roster rather
  than a leg in `Test/AgentConnection`. It needs a real principal holding no `OcuPilotAdmin`, which
  that class builds, tears down and arms with `OCUPILOT_ALLOW_PRINCIPALS`; a second copy would
  duplicate ~120 lines and add a class to `check_destructive_test_guard`'s population. The other
  three wire legs are `AgentConnection`'s as written.
- `HandleTest` takes `enabled` from the row as well as `connectionVerified`, so the body is not
  merged *exactly* as `PUT` merges it. The route never writes `Enabled`, and left merged a form
  posting its whole state with Enable ticked meets `AGENT.ENABLE.UNVERIFIED` before any call -- on
  the one flow Test connection exists to unblock. Added at review; pinned by
  `AgentConnection.TestABodyCarryingEnabledDoesNotRefuseTheTest`.
- DW-330 changed two shipped wire legs in `Test/AgentWire`
  (`TestReadUpdateSetDefaultAndDeleteOverTheWire`, `TestAnAcceptedWriteEmitsItsChangeRecordFromTheHandler`):
  both moved the marker onto a definition the API creates disabled, which is now a 422. Each now
  enables its definitions through `AgentFixture.SetFlags` first.

## Review Triage Log

### 2026-09-15 - Review pass

- verdicts: 42 findings - high 0, medium 18, low 20, false 4, maybe-false 0
- findings:
  - `[medium]` `[defer]` The route carries the stored credential to a body-supplied endpoint - real; AD-42 already grants an administrator that choice and AD-35 governs OcuPilot's own displayed surfaces, so this is AD-42's boundary rather than a deviation; deferred to the decision sheet.
  - `[medium]` `[defer]` No change record when the tested values are not the stored ones - verified: `LogChange` sits inside `If tTestedAsStored`; deferred to Story 3.8, which owns what the audit records.
  - `[medium]` `[defer]` The `test` record classifies itself `securityChange: false` - verified: `IsSecurityChange` sees only `connectionVerified` and `updatedAt`; same root cause and same owner as the row above.
  - `[medium]` `[patch]` A test body carrying `enabled: true` is refused 422 before any call - verified by mutation; `enabled` is now taken from the row like `connectionVerified`, and `TestABodyCarryingEnabledDoesNotRefuseTheTest` pins it.
  - `[low]` `[patch]` `ConnectionVerified`'s property doc still said every path here only clears it - corrected at its origin to name `GuardedSetVerification`.
  - `[low]` `[reject]` `MatchesStoredSecurityFields` compares normalized values against un-normalized stored ones - real only for a row written outside the API, which normalizes before saving; the fix adds a normalized copy to guard a state no production path reaches.
  - `[medium]` `[patch]` The failure legs' "no flag changed" assertions run against rows already `0|0` - the credential leg, whose stated property is "no flag is cleared", is now arranged `1|1` and reddens under a mutation that clears on the fault path. The other legs pin the opposite direction (not set) and stand.
  - `[medium]` `[defer]` `connectionVerified` in the answer is the stored row's flag, so a verified definition tested with an edited endpoint answers true beside `testedAsStored` false - verified; deferred to Story 3.5, which renders the pair.
  - `[medium]` `[defer]` `HandleTest`'s success path is exercised by no test - verified: deleting `Api.Response.JSON(tAnswer)` leaves the suite green; closing it needs a stub reachable over HTTP or a `%CSP.Response` stub plus device capture.
  - `[medium]` `[patch]` The route's administrator gate could not redden - two cases added to `AgentWireSecurity`'s roster (unknown id, link-local body); with the gate removed they answer 404 and 422 while the plain case stays 403.
  - `[false]` `[reject]` `If '$IsObject(tAnswer)` in `HandleTest` is unreachable - `ConnectionOutcome` is `..`-dispatched and a subclass could answer neither; failing loudly on a state not shown reachable is correct behavior.
  - `[low]` `[patch]` `SetDefaultGuarded` reported "not enabled" for a row it could not open - now reports "No such agent definition", the distinction the reason parameter exists to keep.
  - `[low]` `[patch]` The attempt-ceiling test pinned `#DEFAULTMAXATTEMPTS` while `Dispatch` compares the resolved setting - now reads the bound from `Egress.Resolve`.
  - `[medium]` `[patch]` The unresolvable-endpoint leg assumed its resolver - it runs through the shipped adapter, so a resolving name would open a real socket; it now asserts `Egress.Classify` answers `unresolvable` first.
  - `[low]` `[reject]` AC4's marked-local positive half and the body-driven escape have no leg - the positive half is covered at `Test/ProviderPort:284`, and the escape is the same `Validate` call already pinned at create.
  - `[medium]` `[defer]` The failed-verification-write 500 has no test - verified; closing it needs a fourth overridable seam, the shape Story 3.3 deferred for the same reason.
  - `[low]` `[reject]` Re-testing an already-verified definition rewrites the row - true; the cost is a bumped timestamp and a record naming it, and the fix is a guard on a state nothing suffers from.
  - `[medium]` `[patch]` "`ValuesFor` never sets `maxAttempts`" was unpinned while `Dispatch` is on the turn's path too - a fourth leg now drives the stored entry on a 429 and reddens when `ValuesFor` names a ceiling.
  - `[low]` `[patch]` Stale counts in two headers the same diff edited - "two seams" and "six handlers" corrected.
  - `[low]` `[patch]` `TestAnUnknownIdAnswers404OnEveryRouteThatTakesOne` covered four of six id-taking routes - `/credential` and `/test` added, so the method's own claim is true.
  - `[low]` `[reject]` `replyTruncated`'s boundary at exactly `TESTREPLYMAX` is untested - the behavior there is correct (a reply of exactly the bound was not cut); one constant drives both the cut and the flag.
  - `[medium]` `[defer]` A concurrent write during the provider call can leave the row verified against untested values - verified by reading: the comparison precedes `InvokeDraft` and the write follows it.
  - `[low]` `[defer]` `SecurityFieldNames()` skips a state property with no wire field - real and now load-bearing for the verification write; shipped by Story 3.1, so not caused here.
  - `[low]` `[reject]` `SetDefaultGuarded` reads `Enabled` off an in-memory copy `%OpenId` may hand back - true, and the read sits outside the transaction; an admin-rare race whose fix is a `%Reload` or a widened transaction, and the automatic rebalance moves the marker off a disabled row on the next write anyway.
  - `[low]` `[reject]` The enabled read is not inside `SetDefaultGuarded`'s transaction - same root cause and same disposition as the row above.
  - `[low]` `[patch]` The attempt-ceiling test breaks on an instance holding an egress row - same root cause as the `#DEFAULTMAXATTEMPTS` row; fixed by the same change.
  - `[low]` `[patch]` `TESTMAXTOKENS` was documented as two orders of magnitude below the ceiling - 32000/32 is three; corrected.
  - `[medium]` `[defer]` The route's 200 answer is produced by no test (verification-gap layer, filed `defer`) - same root cause as the row above it; deferred to Story 3.5 with the mutation that stays green recorded.
  - `[medium]` `[patch]` The administrator gate cannot be observed by the only leg covering it (verification-gap layer, filed `patch`) - same root cause as the gate row above; the two roster cases were its filed fix.
  - `[low]` `[reject]` `latencyMs` is pinned only by a `%GetTypeOf` the type hint makes unfailable - true, and the spec's Design Notes already decline to assert the figure ("observable on a real instance rather than asserted here"); making it falsifiable means a sleeping leg.
  - `[medium]` `[defer]` The failed-verification-write path has no test (verification-gap layer, filed `patch`) - same root cause as the earlier row; the filed fix adds a fourth seam, which is public surface, so it defers rather than patches.
  - `[medium]` `[defer]` `AgentConnection.Outcome` re-implements `HandleTest`'s arrangement rather than driving it - same root cause as the unpinned success path; both close together.
  - `[low]` `[reject]` `MatchesStoredSecurityFields` normalization (verification-gap `Other`) - same refutation as the earlier row.
  - `[low]` `[reject]` `AssertEquals(tAnswer.connected, 1)` pins a literal set unconditionally - true; it pins the key's presence and type, which is what the key roster assertion beside it is for.
  - `[low]` `[patch]` AC4's private-network and loopback mutations lived only in test doc comments - added to the spec's `## Verification`, with the unresolvable-endpoint one beside them.
  - `[false]` `[reject]` The marked-local positive half is not a gap (verification-gap `Other`) - filed as not-a-finding by the layer itself; confirmed at `Test/ProviderPort:284`.
  - `[medium]` `[defer]` The matrix states outcomes at the route and most rows are evidenced at `ConnectionOutcome` - the same unpinned-success-path root cause, recorded from the intent layer's surface-by-surface table.
  - `[low]` `[defer]` `check_handler_wire_tests` keys a `:param` route on its dispatch class, so the gate named in the intent is class-wide - verified in the checker; shipped by Story 1.x.
  - `[false]` `[reject]` The attempt bound sits in `Dispatch` rather than `InvokeDraft` - task 3 of this spec prescribes `Dispatch`, and `ValuesFor` setting no key is now pinned.
  - `[medium]` `[patch]` The 403 row has no falsifying surface - same root cause as the gate rows; closed by the two roster cases.
  - `[low]` `[patch]` `AgentWire`'s new inline comments claim the API cannot enable a definition - after this story it can (create, store the key, test, then `PUT`); reworded to say what is actually true of a test process.
  - `[false]` `[reject]` The Intent block and the Tasks block of this spec read differently on five axes - descriptive; the tasks settle each one and the Spec Change Log discloses the deviations.

### 2026-09-15 - Code review (four layers)

- entries: high=0 med=6 low=8 rows=46 unresolved_high_med=1
- patched here: AC1's TLS clause asserted on the route; the comparison-precedes-the-call ordering pinned through a definition stored with no endpoint; AC3's `detail.providerText` asserted on the rendered envelope; the route's non-object-body 400 pinned; a `tBound > 1` guard so the attempt-ceiling method cannot go vacuous on an instance whose stored bound is 1; the post-write re-read failure logged rather than silently fabricated; four doc corrections (`Outcome` does not validate, the probe's inherited-method claim, two stale counts).
- routed: DW-366 (`AGENT.DEFAULT.DISABLED` has no published client sentence) to 3-5; DW-367 (`Test/AgentConnection` past the 500-line guidance) closed `wontfix-accepted` with a probe.
- unresolved: DW-366 alone. DW-357, DW-362 and DW-365 were re-confirmed rather than re-filed - each is an entry an earlier gate already dispositioned, so none is counted again.

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

**Mutations added at review**, applied to the throwaway's own `src/`, whole tree recompiled, red
observed, reverted, and `git status --short` / `git diff --stat` unchanged afterwards:

- **AC4, second clause** -- `mutation:` classify `10.0.0.0/8` as loopback in `Kernel/Egress.KindOf`
  -> `AgentConnection.TestAPrivateNetworkEndpointIsAttempted` goes red on both halves (the create
  answers 422, the call answers `PROVIDER.EGRESS` with the stub never entered).
- **AC4, third clause** -- `mutation:` skip `AgentRules.Validate` in `HandleTest` ->
  `TestALoopbackEndpointInTheBodyIsRefusedOnItsField` goes red at 502 as well as the link-local leg.
- **Matrix, unresolvable endpoint** -- `mutation:` make `AgentRules.AddressViolation` refuse
  `unresolvable` -> `TestAnUnresolvableEndpointIsAcceptedByTheRouteAndRefusedByThePort` goes red at
  422 instead of 502.
- **The `enabled` pin** -- `mutation:` drop the `enabled` line from `HandleTest` ->
  `TestABodyCarryingEnabledDoesNotRefuseTheTest` goes red at 422 `AGENT.ENABLE.UNVERIFIED`.
- **The route's administrator gate** -- `mutation:` remove `IsAdministrator` from `HandleTest` ->
  `AgentWireSecurity`'s two new `/test` cases go red at 404 and 422 while the plain case stays
  green, which is what the port's backstop was hiding.
- **"No flag was cleared"** -- `mutation:` clear the verification on `ConnectionOutcome`'s fault
  path -> `TestAnUnresolvableCredentialIsRefusedBeforeTheTransport` goes red at `0|1`.
- **A turn keeps the stored ladder** -- `mutation:` have `ProviderPort.ValuesFor` set
  `maxAttempts` to 1 -> `ProviderPort.TestACallerMayLowerTheAttemptCeilingAndMayNotRaiseIt`'s
  fourth leg goes red at one call.

**Mutations added at QA (Rule 19), closing DW-360 and DW-361, applied to the throwaway's own
`src/`, whole tree recompiled, red observed, reverted, and `diff -rq` confirming the throwaway's
`src/` and this repository's equal afterwards:**

- **DW-360** (the route's 200 answer, and `HandleTest`'s own arrangement, were exercised by no
  test) -- closed by `AgentConnection.TestTheShippedHandlerAnswersTheSuccessBodyOverTheWire`,
  which drives the literal, inherited `HandleTest` through a new
  `Test.RouterFixture./agent-definitions/:id/test` route (`Test.Dispatch` supplies the
  `%CSP.Request`/`%CSP.Response` stubs and captures the device, the shape `InstanceFaultRoute`
  already uses for DW-120) against a definition naming the real `anthropic` key (the only one
  `AgentRules.Validate` accepts) with `OcuPilot.Test.CatalogAnthropicStub` switched in through
  `ProviderPortProbe.SetCatalogClass` so the call still reaches a stub. `mutation:` delete
  `Api.Response.JSON(tAnswer)` from `HandleTest` -> the captured-body and JSON-parse assertions go
  red (run 7 of 8; green at run 8).
- **DW-361** (the "provider answered and the flag could not be written" 500 had no test) --
  closed by `AgentConnection.TestTheVerificationWriteFailingAnswersFiveHundredAndNoAnswerBody`,
  forced by a genuine concurrent-delete race rather than a new seam: the row is deleted between
  the read that captures `tStored` and the call into `ConnectionOutcome`, so
  `GuardedSetVerification` fails on a row that is genuinely gone. `mutation:` stop returning on
  `tWriteSC`'s failure in `ConnectionOutcome` (swallow it instead of building the fault) -> the
  no-answer and has-a-fault assertions go red (run 4 of 8; green at run 6).

**Mutations added at code review (Rule 19), applied to the throwaway's own `src/`, whole tree
recompiled, red observed, reverted, and `diff -rq` confirming the throwaway's `src/` and this
repository's equal afterwards:**

- **AC1's TLS clause** -- `mutation:` clear `tSettings("sslConfiguration")` on `Dispatch`'s HTTPS
  branch -> `AgentConnection.TestATestOfTheStoredValuesAnswersAndRecordsVerification`'s new
  recorded-configuration assertion goes red (run 11), and nothing else does.
- **The comparison precedes the call** -- `mutation:` move `MatchesStoredSecurityFields` below
  `InvokeDraft` in `ConnectionOutcome` -> `TestOnlyASecurityEditStopsTheRowBeingWritten`'s third
  leg goes red at `testedAsStored` 0 and flags `0|0` for a definition stored with no endpoint
  (run 12), which is the state the port's own backfill would otherwise read as an edit.
- **AC3 at the wire** -- `mutation:` drop the `tFault.detail` argument from `HandleTest`'s
  `Api.Error.Render` call -> `TestTheShippedHandlerRendersTheProviderTextOverTheWire` goes red on
  an envelope carrying `error`, `reason` and `code` and no `detail` (run 13); every in-process
  assertion stays green, which is what made the drop silent.
- **The bad-body stage** -- `mutation:` delete the `BodyIsReadable` branch from `HandleTest` ->
  `TestABodyThatIsNotAnObjectIsRefusedBeforeAnyCall` goes red at 422 with seven violations on
  fields the caller never sent (run 14).

**Manual checks:**

- After the run, on the live container: `GET /api/ocupilot/agent/definitions` returns an empty list,
  and `iris_sql_execute` over `OcuPilot_Kernel_State.Agent` counts 0 rows.
- Tear the throwaway down before returning (`sh scripts/ci-throwaway.sh down`), naming the project
  and directory in the run result.


## Auto Run Result

Status: done
Blocking condition: none

**What shipped.** `POST /agent/definitions/:id/test`: administrator gate, 404, the body merged over
the stored row with `connectionVerified` and `enabled` taken from the row, `AgentRules` validation,
then one bounded call through `ProviderPort.InvokeDraft` -- thirty-two tokens, one short build-time
prompt, no tools, no system prompt, one attempt. On success it answers `connected`, `reply` cut to
200 characters, `replyTruncated`, `latencyMs`, `connectionVerified` and `testedAsStored`, and writes
`ConnectionVerified` only when every security field of the merged values still matches the row.
DW-330 lands twice: `HandleSetDefault` refuses a disabled definition with
`AGENT.DEFAULT.DISABLED` on `default`, and `SetDefaultGuarded` refuses it underneath.

**Files changed.** `Api/Error` one code; `Api/Router` the route and its wrapper; `Api/Definitions`
`HandleTest`, `ConnectionOutcome`, `MatchesStoredSecurityFields`, `PortClass` and five parameters,
plus the set-default guard; `Kernel/State/Agent` `GuardedSetVerification` and `SetDefaultGuarded`'s
refusal; `Port/ProviderPort` an attempt ceiling in `Dispatch` that can only lower. Tests: new
`Test/AgentConnection`; `Test/DefinitionsProbe` a port seam; DW-330 and the new pins in
`Test/{AgentWire,AgentState,AgentWireSecurity,ProviderPort}`. QA and code review took
`Test/AgentConnection` to sixteen methods and added `Test/{CatalogAnthropicStub,RouterFixture}`.

**Three deviations, in `## Spec Change Log`.** The call, the flag write and the answer sit in
`ConnectionOutcome` so the provider legs can run in a process with no response device; the 403 wire
leg is an entry in `AgentWireSecurity`'s roster rather than a second principal-creating class; and
`enabled` is taken from the row, because the route never writes it and a form posting its whole
state would otherwise be refused on the flow this story exists to unblock.

**Review.** 42 findings across four layers: 0 high, 18 medium, 20 low, 4 false. **Thirteen entries
patched** -- 5 medium, 8 low: the `enabled` pin; the route's administrator gate made falsifiable by
two roster cases (with the gate removed they answer 404 and 422 where the port's backstop hid it);
the credential leg's "no flag was cleared" arranged `1|1` so it can fail; the unresolvable-endpoint
leg's resolver precondition checked rather than assumed; a fourth attempt-ceiling leg pinning that
a turn keeps the stored ladder; `ConnectionVerified`'s property doc corrected at its origin;
`SetDefaultGuarded` reporting "no such definition" for a row it could not open; the attempt-ceiling
bound read from the resolved settings; the 404 roster completed; two stale counts and one wrong
order-of-magnitude claim; `AgentWire`'s over-broad "the API cannot enable one"; and AC4's two new
`mutation:` lines. **Eight deferred** in frontmatter `deferred:`. **Rejected:** the unreachable
`tAnswer` guard (fails loudly on a state not shown reachable); the normalized-versus-stored
comparison (no production path writes an un-normalized row); AC4's marked-local half and the
`replyTruncated` boundary (already covered, and correct at the boundary); re-testing rewriting the
row; `SetDefaultGuarded`'s stale-read race; `latencyMs` and `connected` pinning presence rather than
value, which the Design Notes already say.

**QA then closed both of the implement pass's named test gaps.** DW-360 is closed by a fixture
route that drives the literal, inherited `HandleTest` with real device capture, and DW-361 by a
concurrent row delete between the read and the call. Both are in `## Verification` with their
mutations; `Test/AgentConnection` carries sixteen methods after them and this review's two.

**Code review, four layers.** 0 high; 6 medium and 11 low root-cause entries, all patched here
except DW-357 (escalated to the decision sheet) and DW-362 (routed). The patches are in the
`## Review Triage Log`; the four new pins and their demonstrated mutations are in
`## Verification`.

**Verified.** `check-objectscript` 262 files, 17 rules, 0 problems; `lint-docs` clean; whole-tree
load and compile on `ocupilot-iris` (262 uploaded, 0 failed, "Compilation finished successfully");
from `ui/`, `npm run build` plus `node --test` and 290 component tests green, no client file
touched. On the throwaway `ocupilot-ci`, one class per invocation: **131 methods, 131 passed, 0
failed** across the 10 classes this story touches or regresses, read from `%UnitTest_Result` rather
than the runner envelope. `smoke.sh` executed=18 passed=18 failed=0, PASSED. Eleven mutations at
implement, two at QA and four at review were applied to the throwaway's own `src/`, the whole tree
recompiled, red observed and reverted, with `diff -rq` confirming the two trees equal afterwards.
The live `ocupilot` container was never recreated and holds zero agent definitions and zero
OcuPilot credential entries.

**Residual risks.** The credential reaching a body-supplied endpoint (DW-357, an AD-42 boundary
question for the decision sheet), the silence when the tested values are not the stored ones
(DW-358), and the concurrent-write window between the security comparison and the verification
write (DW-362). Each is a `deferred:` entry with what would settle it.
