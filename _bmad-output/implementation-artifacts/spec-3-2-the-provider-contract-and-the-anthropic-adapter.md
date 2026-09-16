---
title: 'Story 3.2: The provider contract and the Anthropic adapter'
type: 'feature'
created: '2026-09-15'
status: 'done'
baseline_revision: '1d24c1c7c8ecb839e885926fbc69e6959f6f9db5'
baseline_commit: '1d24c1c7c8ecb839e885926fbc69e6959f6f9db5'
review_loop_iteration: 0
followup_review_recommended: true
context: []
warnings: ['oversized']
deferred:
  - summary: >-
      ProviderPort reads a stored definition's systemPromptOverride into pValues and nothing
      ever reads it back, so a definition's own system prompt is silently dropped on the
      Invoke path.
    evidence: |-
      Port/ProviderPort.ValuesFor populates pValues("systemPromptOverride"); Dispatch forwards
      only the caller's pSystemPrompt argument and Anthropic.CallMessages reads that argument.
      Which of the two wins is a precedence rule no AC states, so it is not settleable here.
    location: >-
      src/OcuPilot/Port/ProviderPort.cls ValuesFor / Dispatch
    severity: medium
  - summary: >-
      Every endpoint judgement costs four resolver lookups plus a GetInterfacesInfo read,
      unbounded and uncached, on the write path and again on every provider call.
    evidence: |-
      Kernel/Egress.Addresses queries HostNameToAddrMulti and HostNameToAddr in families 1 and
      2; Classify re-reads GetInterfacesInfo per classification and says it deliberately never
      caches. A slow or hung resolver blocks the calling process with no deadline. The lookups
      are what the intent mandates, so the fix is a bounded, cached classification, not fewer
      checks.
    location: >-
      src/OcuPilot/Kernel/Egress.cls Addresses / InstanceAddresses
    severity: medium
---

<intent-contract>

## Intent

**Problem:** OcuPilot has no way to reach an LLM. The harvested provider layer hardcodes `DefaultSSL`, handles no proxy, has no operator-settable timeout, and dispatches providers through a four-branch `If/ElseIf`; and the one field that decides where the instance's data goes is, today, validated only as a URL literal — a hostname that resolves to loopback, link-local or the instance itself is a request-forgery primitive through a DNS name (DW-21).

**Approach:** One provider base with a never-throw `Invoke()` template and adapters selected from `Kernel/Provider/Catalog`'s table — a registry, not a branch — with Anthropic's message shape canonical and passthrough. `Port/ProviderPort` owns the outbound edge: it declares its gate, applies the installer-created named SSL configuration plus stored proxy and timeout settings, validates the **resolved** address at call time as well as at write time, retries only on a retryable status and never after a mid-flight throw, and renders every failure as a turn error carrying a `PROVIDER.*` code. The credential is held on the adapter instance, never in a local variable and never in a URL, message, status or trap.

## Boundaries & Constraints

**Always:**

- `Invoke()` returns `$$$OK` on **every** path. A failure is `pResponse.StopReason = "error"` plus a `Kernel.Fault.Build` envelope in `pFault` and an HTTP status in `pHttpStatus` — the two other ports' output shape (`Port/LogSourcePort.cls:419`). An exception never reaches a caller (AD-12, AD-39, AD-42).
- Every adapter comes from a `Catalog` row's `adapterClass` column. No shipped class branches on a provider name.
- TLS uses the SSL configuration named once on `Kernel/State/Base.cls` and created by the installer if absent, `Type` client, `VerifyPeer` 1, `CAFile` `%OSCertificateStore`; the request carries `SSLCheckServerIdentity = 1` (AD-32).
- Proxy, per-call timeout and attempt bound are read from stored instance configuration, never from class parameters at the call site (AD-32, Operational Envelope › Config).
- The endpoint's **resolved** address is checked at write time *and* at call time (DW-21). Both families are queried explicitly; every literal is canonicalised before it is range-checked.
- The key is resolved into the adapter instance's `[ Internal ]` property and written straight onto the request's headers. **No local variable on the provider path ever holds key material**, because `^%ETN` captures the local symbol table at every stack level (AD-48) and OcuPilot renders that log (AD-35, AD-46).
- ObjectScript under `src/OcuPilot/` only; `uv run scripts/check-objectscript.py` (17 rules) passes; compile through the IRIS MCP tools with `server: "ocupilot-iris"`.

**Never:**

- No real outbound call to a paid API from any test, and no SSL configuration, credential or principal created on the live `ocupilot` container. No `docker compose up`/`down` against it.
- No `$System.Security.Audit()` call — the triple is unregistered and would be dropped silently (AD-15). Story 3.8 owns registration and emission; this story marks the change through the shipped `Api/Definitions.LogChange` seam. Same split Story 3.1 made and recorded.
- No client file, no `strings.ts` key, no screen descriptor, no route. Story 3.4 adds the Test-connection route; Story 3.5 the form.
- No `%Net.HttpRequest` retried after it threw. No second enforcement point for read-only or the kill switch (AD-30) — this story reads neither.
- No adapter for OpenAI, Gemini or OpenAI-compatible, and no message/tool translation layer: build step 7 (spine › Deferred).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Happy call | enabled definition, `anthropic`, key resolves, stand-in transport returns 200 with a text block | `$$$OK`; `StopReason` from the body; text, `RequestTokens`, `ResponseTokens` populated; `pFault` empty | No error expected |
| Literal loopback endpoint | `https://127.0.0.1/v1`, `markedLocal` 0 | write refused with one 422 carrying `AGENT.ENDPOINT.ADDRESS` on `endpointUrl` | accumulated with every other violation, one round trip |
| Obfuscated loopback literal | `https://2130706433/v1`, `https://0177.0.0.1/v1`, `https://127.1/v1` | all three refused as loopback | canonicalised through `HostNameToAddr` *before* the range test — probed: each answers `127.0.0.1`, and `AddrType` calls all three IPv4, so a dotted-quad test alone passes them |
| Link-local endpoint | `https://169.254.169.254/latest/meta-data` | refused at write time with `AGENT.ENDPOINT.LINKLOCAL` and at call time with `PROVIDER.EGRESS`, **whatever `markedLocal` says** | never escapable; the metadata range is the case FR-27 names |
| Instance's own address | a host resolving to any address in `$System.INetInfo.GetInterfacesInfo()` | refused with `AGENT.ENDPOINT.ADDRESS` unless the definition is marked local on a provider whose row allows it | probed: this container answers `eth0`+`$C(1)`+`172.19.0.2/16`; `lo` is absent, so loopback is a range test, not an interface test |
| DNS rebinding | endpoint passed at write time, its name now resolves to `169.254.169.254` | the call is refused before any socket is opened: `StopReason` `error`, `PROVIDER.EGRESS`, HTTP 502 | the residual race is named under Design Notes, not claimed closed |
| Unresolvable host at call time | name resolves to `""` in both families | refused: `PROVIDER.EGRESS` | probed: `HostNameToAddr` answers `""`, never raises |
| Marked local on a provider that forbids it | `markedLocal` 1, `Provider` `anthropic` (`allowsLocal` false) | write refused with `AGENT.LOCAL.UNSUPPORTED` on `markedLocal` | the escape is a catalog column, so a family that supports it is a row |
| Plain HTTP endpoint | `http://localhost:11434/v1/...`, `markedLocal` 1, row allows local | accepted; TLS is not applied and `SSLConfiguration` is left empty | with `markedLocal` 0 or a row that forbids it, `AGENT.ENDPOINT.SCHEME` (Story 3.1's code, rule widened) |
| Retryable status | stand-in returns 429 with `retry-after: 7`, then 200 | one retry, delay `MAX(7, backoff)`; second call succeeds | attempts bounded by the stored `MaxAttempts`; exhausted ⇒ `PROVIDER.UNAVAILABLE` |
| Non-numeric `Retry-After` | `retry-after: Wed, 21 Oct 2026 07:28:00 GMT` | the hint is discarded and the exponential backoff alone is used | never parsed as a number; never a negative or huge delay |
| Non-retryable status | stand-in returns 401 with a provider error body | **no retry**; `PROVIDER.REFUSED`, HTTP 502, the provider's own `error.message` carried as `detail.providerText` | the raw body goes to `Fault.LogRaw` only |
| Mid-flight throw | stand-in raises | **no retry at all**; `PROVIDER.TRANSPORT`, HTTP 502 | the request may already have been processed |
| Missing SSL configuration | the named configuration absent at call time on an HTTPS endpoint | `PROVIDER.TLS`, HTTP 503, naming the configuration | never falls back to `DefaultSSL` and never proceeds unencrypted |
| Credential unresolved | `credType` `env`, variable unset | **no call is made**; `PROVIDER.CREDENTIAL` | the reason names the *reference*, never a value |
| Key fails its shape gate | resolved value does not start with the row's `keyPrefix` | **no call is made**; `PROVIDER.KEYSHAPE` | the reason states the expected prefix, never the value — the harvest's `EnvVarName=PATH` bug |
| Anonymous caller | `$Username` `UnknownUser` or `_PUBLIC` | `AUTH.ANONYMOUS`, HTTP 401, before any port work | AD-21: anonymous is not unprivileged |
| Draft (unsaved) definition | values supplied by a caller rather than resolved from state | requires `OcuPilotAdmin:USE` in the port; `AUTH.NOPRIVILEGE` with `detail.failedPair` otherwise | the entry Story 3.4 calls |

</intent-contract>

## Code Map

Every anchor re-verified against the working tree on 2026-09-15.

### Shipped surfaces this story builds on

- `src/OcuPilot/Kernel/Provider/Catalog.cls` — the one place a provider key, model, endpoint or key prefix is spelled. `XData Providers` **:38-43** (one row, `anthropic`; `keyPrefix` `sk-ant-` **:41**, `defaultEndpoint` `https://api.anthropic.com/v1/messages`), overridable `Table()` **:49**, `Keys()` **:74**, `Row()` **:95** (first match wins), `IsKnown()` **:119**. This story adds two columns; `Test/AgentRules.cls:119` asserts the shipped `Keys()` is exactly `anthropic`, so **columns are additive and safe, a new shipped row is not.**
- `src/OcuPilot/Kernel/AgentRules.cls` — `Normalize` **:52**, `Validate` **:96** (accumulates; never quits early), `Add` **:157**, `CatalogClass()` **:177** (overridable seam), `EndpointRequired` **:191** (reads the row's column, provider-name-free — the pattern the local escape copies), `IsAbsoluteHttps` **:211** (scheme matched case-insensitively; userinfo refused). Its header **:16-22** fixes the ByRef-array field vocabulary a violation names.
- `src/OcuPilot/Kernel/State/Agent.cls` — eighteen scalars, no `ApiKey`. `SecurityFields()` **:109-112** (the five whose change clears `ConnectionVerified` and `Enabled`), `SnapshotSecurityFields` **:118**, `GuardedUpdate` **:168-192**, `ResolveDefault` **:274**, `Timestamp()` **:130**. `MarkedLocal` joins the property set **and** `SecurityFields()`.
- `src/OcuPilot/Api/Definitions.cls` — `Fields()` **:44-47** (`$LB(field, property, kind, writable)`), `ValuesFromRow` **:394**, `ChangeSet` **:525-540** (keyed by field name so `Kernel/Audit/Log.Redact` can mask by key), `LogChange` **:548-557** — *"the single seam Story 3.8 wires to `$System.Security.Audit()`"*. `RenderViolations` **:367** renders one 422 with `detail.violations`.
- `src/OcuPilot/Port/LogSourcePort.cls` — the port shape to copy: `GateClass()` **:367** (overridable), `LogFault` **:398**, and the `(Output pResult, Output pHttpStatus, Output pFault)` signature at `Page` **:419** / `Errors` **:550**. `EvaluatePairs` delegation **:1032-1036**.
- `src/OcuPilot/Kernel/Fault.cls` — `Build(pSlug, pCode, pReason)` **:156-163** returns `{error, reason, code}`; `LogRaw` **:189-207** sends raw vendor text to the log **and nowhere else**; `LogError` **:215** is the interceptable seam (`Test/FaultProbe.cls` overrides it).
- `src/OcuPilot/Api/Error.cls` — slug enum **:19-66**, seven `PORT.*` codes **:156-185**, `AUTHANONYMOUS` **:116**, `AUTHNOPRIVILEGE` **:111**, `CODEPATTERN` `^[A-Z][A-Z0-9]*(\.[A-Z][A-Z0-9]*)*$` **:279**, `Render` **:301**, `IsValidCode` **:338**. `Test/Envelope.cls` and `Test/Fault.cls` already exercise the roster.
- `src/OcuPilot/Api/Router.cls:359-361` — the anonymous refusal, with `UnknownUser` and `_PUBLIC` as **inline literals**. This story moves the test to `Screen/Gate.cls` so the port and the router cannot drift; `Screen/Gate.cls` already owns the single `$System.Security.Check` consultation at `HoldsPrivilege` **:123-126** and the failed-pair string at `EvaluatePairs` **:89**.
- `src/OcuPilot/Kernel/Audit/Log.cls` — `Emit` writes **to the IRIS console log**, i.e. `messages.log`, which `Port/LogSourcePort.cls:54` (`MESSAGESFILE`) serves and OcuPilot renders. `CREDENTIALNAMES` **:55** is the backstop pattern; `Parameter REDACTED` **:42**; `WriteConsole` **:192** is the capture seam.
- `src/OcuPilot/Install/Installer.cls` — `Names()` **:122-175** (production names come from `Kernel/State/Base.cls` parameters, probe names are `"Probe"`-suffixed derivatives); the step sequence with its `tFailingStep` labels **:759-825**; `Ensure*` signature convention `(ByRef pNames, ByRef pReports) [ Private ]` (e.g. `EnsureAuditEvent` **:2538**). `Install/Fixture.cls:304-307` already reserves the ground: *"deliberately not AD-32's **ProviderPort** configuration, which the installer creates unconditionally and is not a fixture"*; `CreateSslConfig` **:308-335** is the `Security.SSLConfigs.Exists`/`Create` call shape to copy.
- `src/OcuPilot/Test/CatalogProbe.cls` — the seam that makes a column-driven rule falsifiable at a one-row floor. Add a second row here, not to the shipped table.
- `src/OcuPilot/Test/State.cls:28,:37` — the `ARMINGVARIABLE` + `OnBeforeAllTests` refusal shape `check_destructive_test_guard` looks for. `scripts/ci-throwaway.sh:25-27` (`ocupilot-ci`, 52776/1975; refuses `--web 52774`, `--super 1973`, `--project ocupilot`), arming vars at **:133,:140,:144**.
- `src/OcuPilot/Test/ErrorLogSeed.cls:80` — `$$LOG^%ETN()` is how an application-error entry is forced, guarded by `OCUPILOT_ALLOW_ERROR_SEED`; `Read()` **:97** and `CountFor()` **:105** read it back through `SYS.ApplicationError`.

### Vendor surfaces, read in the export and confirmed on the instance

- `irissys/Security/SSLConfigs.cls` — `Create(Name, ByRef Properties)` **:224**, `Exists(Name, .Cfg, .Status)` **:255**, `Get(Name, .Properties)` **:278**, `Delete` **:236**. `Type` **:179** 0 = client. `VerifyPeer` **:194** — for a client, **0 = none, 1 = require server certificate**. `CAFile` **:54** documents the special value `%OSCertificateStore`; `HS.HealthConnect.FHIRExplorer.Upgrade.Base.cls:33` is the vendor's own installer using it. Live instance: `ISC.FHIRExplorer.SSL.Config` carries `caFile %OSCertificateStore`, `verifyPeer 1`, `tlsMinVersion 16`, `type 0`.
- `irislib/%Net/HttpRequest.cls` — `SSLConfiguration` **:680**, `SSLCheckServerIdentity` **:688** (`InitialExpression = 1`, documented as the RFC 2818 §3.1 identity match — **this, not an SSLConfigs property, is what "server-identity checking on" names**; `VerifyPeer` is the separate chain check), `SSLUseSNI` **:695**, `Timeout` **:711** (default 30), `ProxyServer` **:726**, `ProxyPort` **:729** (8080), `ProxyHTTPS` **:736**, `ProxyTunnel` **:706**, `ProxyAuthorization` **:777**.
- `irislib/%Net/HttpResponse.cls` — `StatusCode` **:27**, `Data` **:14**, `GetHeader(name)` **:57**, which upper-cases the name, so `GetHeader("Retry-After")` matches whatever case the provider sent.
- `irislib/%SYSTEM/INetInfo.cls` — `HostNameToAddr(Host, Family, Format)` **:148**, `HostNameToAddrMulti` **:170**, `AddrType` **:32**, `IsIPV6Enabled` **:208**, `GetInterfacesInfo` **:536**, `LocalHostName` **:214**, `CheckAddressExist` **:427**.

**Probed on the `ocupilot` instance (IRIS for Health 2026.2), 2026-09-15 — reads only, nothing created**

| Probe | Result | Consequence |
|---|---|---|
| `HostNameToAddr("2130706433")` / `("0177.0.0.1")` / `("127.1")` | all `127.0.0.1` | canonicalise every literal through the resolver before range-testing it |
| `AddrType` on those three | all `1` (IPv4) | `AddrType` alone does **not** tell you the form is dotted-quad |
| `AddrType("::ffff:127.0.0.1")` | `2` (IPv6) | IPv4-mapped IPv6 needs its own unwrap |
| `IsIPV6Enabled()` | `0` | family `0` returns IPv4 only **on this instance** — an instance setting, not a guarantee |
| `HostNameToAddrMulti("google.com", 2)` | `2607:f8b0:400a:801::200e` | the AAAA lookup works regardless of that setting ⇒ query families **1 and 2 explicitly** |
| `HostNameToAddr("no-such-host-ocupilot.invalid")` | `""` | an unresolvable name is an ordinary empty answer, never an exception |
| `GetInterfacesInfo()` / `GetInterfacesInfo("lo")` | `eth0`+`$C(1)`+`172.19.0.2/16` / `""` | the instance's own addresses come from here; loopback does **not**, so it is a range test |
| `CheckAddressExist("160.79.104.10")` | `1` | **a trap: it pings.** It answers 1 for Anthropic's own address. It is not an "is this the instance" test and must not be used as one |
| `HostNameToAddr("api.anthropic.com")` | `160.79.104.10` | the happy path resolves |

**Provider wire contract** (claude-api skill, cached 2026-06-24): `POST https://api.anthropic.com/v1/messages`; headers `x-api-key`, `anthropic-version: 2023-06-01`, `content-type: application/json`; body `{model, max_tokens, messages:[{role, content}], system?, temperature?, tools:[{name, description, input_schema}]}`; response `{content:[{type:"text"|"tool_use", ...}], stop_reason, usage:{input_tokens, output_tokens}}`; error body `{type:"error", error:{type, message}}`. Retryable: 429, 500, 529 (the SDKs' own default also retries 408, 409 and the rest of 5xx). `retry-after` is **delta-seconds**. Current model ids carry no date suffix.

## Tasks & Acceptance

**Execution:**

1. `src/OcuPilot/Kernel/State/Base.cls` — add `Parameter SSLCONFIG = "OcuPilotProvider"` beside the other name parameters, so the installer, the port and the uninstall report read one literal. No method here changes; nothing under `Kernel/State/` may name `Api`/`Port`/`Screen`/`Area` (`check_state_package_isolation`, `scripts/check-objectscript.py:710`).
2. `src/OcuPilot/Kernel/Provider/Catalog.cls` — add three columns to the row and to the class's column documentation: `adapterClass` (`"OcuPilot.Kernel.Provider.Anthropic"`), `allowsLocal` (`false`), `authVersion` (`"2023-06-01"`). Correct the suggestion `claude-haiku-4-5-20251001` to `claude-haiku-4-5`. **Do not add a shipped row.**
3. `src/OcuPilot/Kernel/Egress.cls` — **new.** The endpoint address policy, called by both the write-time rules and the call-time port. `HostOf(pUrl)` (authority minus port; userinfo is already refused upstream), `Classify(pHost, Output pKind, Output pAddress)` returning one of `public` / `loopback` / `linklocal` / `instance` / `unresolvable`, and `IsPermitted(pUrl, pMarkedLocal, pAllowsLocal, Output pKind)`. Rules: an address literal is canonicalised through `$System.INetInfo.HostNameToAddr` before any range test; a name is resolved with `HostNameToAddrMulti` in family 1 **and** family 2 and **every** returned address is classified (worst kind wins); IPv4-mapped IPv6 is unwrapped; loopback is `127.0.0.0/8` and `::1`; link-local is `169.254.0.0/16` and `fe80::/10`; instance addresses are parsed from `GetInterfacesInfo()` on `$Char(1)` boundaries with the `/prefix` stripped. `linklocal` is refused unconditionally; `loopback` and `instance` are refused unless `pMarkedLocal` **and** `pAllowsLocal`; `unresolvable` is refused. Never call `CheckAddressExist`.
4. `src/OcuPilot/Api/Error.cls` — declare the new codes as parameters with their producer in the doc comment, in the `PORT.*` neighbourhood: `AGENTENDPOINTADDRESS`, `AGENTENDPOINTLINKLOCAL`, `AGENTLOCALUNSUPPORTED`, `PROVIDERUNCONFIGURED`, `PROVIDEREGRESS`, `PROVIDERCREDENTIAL`, `PROVIDERKEYSHAPE`, `PROVIDERREFUSED`, `PROVIDERUNAVAILABLE`, `PROVIDERTIMEOUT`, `PROVIDERTRANSPORT`, `PROVIDERTLS`. Every value must satisfy `CODEPATTERN`.
5. `src/OcuPilot/Kernel/State/Agent.cls` — add `Property MarkedLocal As %Boolean [ InitialExpression = 0 ]` with a header saying what it licenses, and add `"MarkedLocal"` to `SecurityFields()` **:111** so changing it disables the definition and clears its verification. No Storage section.
6. `src/OcuPilot/Kernel/AgentRules.cls` — add `AllowsLocal(pProvider)` reading the row's column the way `EndpointRequired` **:191** does; widen the scheme rule so `http://` is accepted only when `markedLocal` and `allowsLocal` are both true; add the address rule calling `Kernel.Egress`; add the `AGENT.LOCAL.UNSUPPORTED` rule. Every new check appends through `Add` and quits early nowhere.
7. `src/OcuPilot/Api/Definitions.cls` — add `markedLocal` to `Fields()` **:46** as a writable boolean; add `securityChange` (1 when `ChangeSet` touched any `SecurityFields()` name) to the object `LogChange` **:548** emits, so Story 3.8 keys its audit event off a classification already computed rather than recomputing one.
8. `src/OcuPilot/Kernel/State/Egress.cls` — **new `%Persistent`, 28 characters.** One instance-wide settings row: `ProxyServer`, `ProxyPort`, `ProxyHttps`, `ProxyTunnel`, `TimeoutSeconds` (`InitialExpression = 90`), `MaxAttempts` (`InitialExpression = 3`), `SslConfiguration` (`""` ⇒ `Base.#SSLCONFIG`). Copy `Kernel/State/Version.cls`'s house style: `MAXLEN` on every string, `InitialExpression` on every flag, a literal `SELECT TOP 1 ID FROM OcuPilot_Kernel_State.Egress` through `GuardedOpenOneWhereNoParam`, no hand-written Storage, no `list Of`. `Resolve(Output pSettings)` returns the stored row's values over the defaults; `SetGuarded(ByRef pValues)` writes them. No route renders it in Release 1 — say so in the header.
9. `src/OcuPilot/Kernel/Secret/Ladder.cls` — **new.** `Resolve(pCredType, pEnvVarName, pCredentialName) As %String` — `%String`, never `%Status`, deliberately, so the value can never land in a status message. Implements the environment-variable rung only (`$System.Util.GetEnviron`, with `$Char(0)` normalised to `""`); `creds` answers `""`. Header states that the credential rung, its interoperability-namespace condition and DW-22 are Story 3.3's.
10. `src/OcuPilot/Kernel/Provider/Response.cls` — **new `%RegisteredObject`.** `StopReason`, `Text`, `ToolCallsJson`, `RequestTokens`, `ResponseTokens`, `LatencyMs`, `HttpStatus`. `StopReason = "error"` is the failure signal.
11. `src/OcuPilot/Kernel/Provider/Retry.cls` — **new.** Pure helpers: `IsRetryable(pStatus)` against a declared parameter set (408, 409, 429, 5xx); `ParseRetryAfter(pHeaderValue)` accepting delta-seconds only and answering 0 for anything else, bounded by a declared ceiling; `ExpBackoffSec(pAttempt)` with full jitter; `DelaySec` = the greater of the two.
12. `src/OcuPilot/Kernel/Provider/Base.cls` — **new abstract base.** `Property ApiKey [ Internal ]`. Non-abstract `Invoke(ByRef pValues, ByRef pMessages, ByRef pTools, pSystemPrompt, ByRef pSettings, Output pResponse, Output pFault, Output pHttpStatus) As %Status` — the template: resolve the secret through `SecretClass()`, refuse on empty, gate the key shape against the row's `keyPrefix`, build the request, loop attempts, clear `..ApiKey` and drop the request in a `Try`/`Catch` that runs on every exit, **and return `$$$OK` always**. Abstract hooks: `CallMessages`, `ApplyAuth(pRequest)`, `ProviderName()`, `IsApiKeyShapeValid(pKey)`. `IssueHttpsPost(pRequest, pUrl, Output pStatus, Output pBody, Output pRetryAfter) As %Status` is an **instance** method and the one transport seam a test subclass overrides.
13. `src/OcuPilot/Kernel/Provider/Anthropic.cls` — **new.** Canonical passthrough: body `{model, max_tokens, temperature, system?, messages, tools?}`; `ApplyAuth` sets `x-api-key` from `..ApiKey` and `anthropic-version` from the row's `authVersion` **directly onto the request**, touching no local; response mapped to `Provider.Response`; an error body's `error.message` carried as `detail.providerText`, its raw form to `Fault.LogRaw` only.
14. `src/OcuPilot/Port/ProviderPort.cls` — **new.** `Invoke(pDefinitionId, ...)` resolves the definition from state; `InvokeDraft(ByRef pValues, ...)` takes caller-supplied values and additionally requires `OcuPilotAdmin:USE`. Both refuse an anonymous caller first (AD-21), then re-check the endpoint through `Kernel.Egress` (DW-21), then resolve the adapter from the row's `adapterClass`, then configure the `%Net.HttpRequest` from `Kernel.State.Egress.Resolve` — `SSLConfiguration`, `SSLCheckServerIdentity = 1`, `Timeout`, `Proxy*` — refusing with `PROVIDER.TLS` when the named configuration is absent on an HTTPS endpoint. `GateClass()` and `SecretClass()` are overridable seams, as `LogSourcePort.GateClass` **:367** is.
15. `src/OcuPilot/Screen/Gate.cls` — add `IsAuthenticatedPrincipal(pUser)` rejecting `""`, `UnknownUser` and `_PUBLIC`, and change `Api/Router.cls:359` to call it, so the two cannot drift.
16. `src/OcuPilot/Install/Installer.cls` — add `pNames("sslConfig") = ##class(OcuPilot.Kernel.State.Base).#SSLCONFIG _ tSuffix` in `Names()` and an `EnsureSslConfiguration(ByRef pNames, ByRef pReports)` step, labeled `tFailingStep = "EnsureSslConfiguration"`, placed inside the `%SYS` window after `EnsureAdminRole`. Guard-then-act (AD-17): create only when `Security.SSLConfigs.Exists` is false, with `Type` 0, `VerifyPeer` 1, `CAFile` `%OSCertificateStore`, `Enabled` 1; when it exists, **repair a drifted `VerifyPeer` or `CAFile` and report it** rather than adopting it silently; read the configuration back after writing and fail the step if it did not take. Name it in the uninstall confirmation string **:3172** and remove it in the destructive block.
17. `scripts/ci-throwaway.sh` — add `OCUPILOT_ALLOW_SSL_CONFIG: "1"` beside the three existing arming variables.
18. `src/OcuPilot/Test/CatalogProbe.cls` — append a second extra row, `probe-local`, with `allowsLocal` true and `adapterClass` `"OcuPilot.Test.ProviderStub"`, and give the existing `probe-endpoint-required` row the three new columns. Additive only.
19. `src/OcuPilot/Test/ProviderStub.cls` — **new**, extends `Kernel.Provider.Anthropic`, overrides `IssueHttpsPost` to answer a queued script of canned `(status, body, retry-after)` triples, to raise on demand, and to record what the request object carried (`SSLConfiguration`, `SSLCheckServerIdentity`, `Timeout`, `Proxy*`, the header names it was given). **No socket is ever opened.**
20. `src/OcuPilot/Test/Egress.cls` — **new.** Every I/O-matrix address row: the three obfuscated loopback literals, IPv4-mapped IPv6, link-local v4 and v6, an instance interface address read from `GetInterfacesInfo()`, an unresolvable name, a public name, and the marked-local escape driven through `CatalogProbe`'s `probe-local` row.
21. `src/OcuPilot/Test/Provider.cls` — **new.** The base's template and the adapter: `$$$OK` on every failure path, the canonical body shape, `ApplyAuth`'s two header names, the key-shape gate refusing before any transport call, and every `Retry` helper including the non-numeric `Retry-After`, the exhausted-attempts bound and the mid-flight throw.
22. `src/OcuPilot/Test/ProviderPort.cls` — **new.** The gate (anonymous refused; `InvokeDraft` without `OcuPilotAdmin:USE` refused with `detail.failedPair`), the configured-request assertions read back from the stub, the call-time egress refusal, and the `PROVIDER.*` code for each failure class.
23. `src/OcuPilot/Test/ProviderConsumer.cls` — **new. The Integration AC.** Uses only `ProviderPort`'s public class methods, as Epic 4's turn and Story 3.4 will, and asserts that each of the four failure classes yields `$$$OK` plus a turn-error envelope and that no exception escapes.
24. `src/OcuPilot/Test/ProviderSecret.cls` — **new.** `Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_ERROR_SEED"` with the `OnBeforeAllTests` refusal. The credential-never-leaks proof — see `## Verification`.
25. `src/OcuPilot/Test/ProviderSsl.cls` — **new.** `Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_SSL_CONFIG"` with the `OnBeforeAllTests` refusal. Runs the installer's step under the `probe` profile on the throwaway and reads the configuration back with `Security.SSLConfigs.Get`.

**Acceptance Criteria:**

- **AC1** — Given two catalog rows whose `adapterClass` columns name different classes, when the port is invoked once against each, then each call is served by the class its own row names, with no other change anywhere; and no shipped class selects behavior by provider name, so only `Kernel/Provider/Catalog.cls`'s `XData` and the adapter it points at spell a provider family.
- **AC2** — Given any failure the provider path can produce, when `ProviderPort.Invoke` returns, then it returns `$$$OK`, `pResponse.StopReason` is `"error"`, `pFault` carries a `PROVIDER.*` code from `Api/Error.cls`, and no exception reaches the caller.
- **AC3** — Given a clean instance with no `OcuPilotProvider` SSL configuration, when install runs, then the configuration exists with `Type` client, `VerifyPeer` 1 and `CAFile` `%OSCertificateStore`; and when the port issues an HTTPS call, the request carries that configuration name, `SSLCheckServerIdentity` 1, and the stored timeout and proxy settings — never `DefaultSSL` and never a class-parameter timeout.
- **AC4** — Given an endpoint whose literal or resolved address is loopback, link-local or one of the instance's own interface addresses, when it is written **and** again when a call is made, then it is refused; link-local unconditionally, the other two unless the definition is marked local on a provider whose catalog row allows it; and the accepted write is recorded through `LogChange` carrying `securityChange` and the old and new values. (**DW-21**, addressed.)
- **AC5** — Given a provider call that fails, when the port decides whether to try again, then it retries only on a status `Retry.IsRetryable` declares, waits the greater of the provider's `Retry-After` and the exponential backoff, stops at the stored attempt bound, and **never retries a call that threw**.
- **AC6** — Given a forced provider failure with a canary credential in play, when the application error log and `messages.log` are read afterwards, then the canary appears in neither, and the failure's `reason`, `code` and `detail` carry no credential material.
- **AC7 (Integration)** — Given a consumer holding only `ProviderPort`'s public contract, when it invokes through the port and the provider fails, then it observes a turn error it can render and no exception — exercised by `OcuPilot.Test.ProviderConsumer`, which inspects no internal state of the provider layer. **Consumed-by:** Story 3.4 (Test connection calls `InvokeDraft` with the definition as edited, so a TLS misconfiguration surfaces at setup), Epic 4's turn (calls `Invoke` with the enabled default definition's id). **Consumes:** Story 3.1 (`Kernel/Provider/Catalog`, `Kernel/State/Agent`, `Kernel/AgentRules`, `Api/Definitions.LogChange`), Story 1.3 (`Kernel/State/Base`, the `OCUPILOT` database, `OcuPilotAdmin`), Story 1.1 (`Api/Error`, `Kernel/Fault`), Story 1.9 (`Screen/Gate`), Story 2.12 (`Port/LogSourcePort`'s port shape and log readers), Story 1.4 (`Install/Installer`'s `Ensure*` sequence and `scripts/ci-throwaway.sh`).

## Spec Change Log

- 2026-09-15 — Design Notes › AD-16 corrected: `ProviderPort` **does** enter `%SYS` once, because `Security.SSLConfigs` is not compiled into the install namespace and AC3's `PROVIDER.TLS` refusal is unreachable without it. Save-and-restore, escalating nothing, failing open for a caller with no privilege on the security database.
- 2026-09-15 — a host that resolves to nothing is refused at **call** time (`PROVIDER.EGRESS`, as the matrix row says) and is not a write-time field violation: whether a name resolves is a property of the resolver at that instant, not of the value typed, and refusing on it broke two shipped Story 3.1 endpoint assertions. `Kernel.Egress.IsPermitted` still refuses it, per Task 3.
- 2026-09-15 — Verification › AC1, AC2 and AC6 mutations corrected to the ones actually demonstrated; AC6's originally recorded mutation is unfalsifiable and the entry says why.

## Review Triage Log

### 2026-09-15 — Review pass

- verdicts: 64 findings — high 1, medium 30, low 31, false 2, maybe-false 0
- findings:
  - `[medium]` `[patch]` `ProviderPort.Invoke` never reads `Enabled`, so Story 3.1's disable-on-security-change is inert against its only consumer — verified: `ValuesFor` read ten fields and neither `Enabled` nor anything testing it existed downstream. Patched: `ValuesFor` reads it, `Invoke` refuses `PROVIDER.UNCONFIGURED`, `InvokeDraft` deliberately does not. Pinned by `Test/ProviderPort.TestADisabledDefinitionIsNotCalledByTheStoredEntry`; mutation applied, red, reverted.
  - `[medium]` `[defer]` `ValuesFor` reads `systemPromptOverride` into `pValues` and nothing reads it back — verified: `Dispatch` forwards only the caller's `pSystemPrompt`. Whether the stored override or the caller's argument wins is a precedence rule no AC states; deferred to Epic 4's turn, which is the first caller that has both.
  - `[low]` `[patch]` `Retry.MAXRETRYAFTERSECONDS`'s doc says a longer hint is "answered as unavailable"; the code clamps and retries — verified at `Retry.cls:58-62`. Patched: the sentence now says what the code does.
  - `[medium]` `[patch]` `Egress.V6Groups` refuses any literal containing `.`, so `::127.0.0.1` classified public — verified by probe on the instance. Grouped with the unspecified-address entry below; patched in `Canonical`, which now unwraps the IPv4-compatible form too.
  - `[medium]` `[patch]` AC6's `PROVIDER.KEYSHAPE` mutation could not be falsified: leg four swapped the canary out before driving the shape gate — verified at `Test/ProviderSecret.cls:142`. Patched: the leg now drives the canary itself through a row whose prefix it fails, so the refusal that is about the key is made while the key is the canary.
  - `[medium]` `[patch]` `securityChange` is emitted by every write and asserted nowhere — verified by search: no test referenced it. Patched: `Test/AgentWire` now asserts `true` for a credential-reference change and `false` for a model-only one.
  - `[low]` `[reject]` `ProviderPort` re-spells `OcuPilotAdmin:USE`, the secret class and the log subsystem — real duplication, but each is the port's own declared seam default and the resource name is spelled the same way elsewhere in the tree; rerouting them through the kernel is more than a direct correction for no reachable defect.
  - `[low]` `[patch]` `Base.NewRequest` hardcodes `90` and reads `timeoutSeconds = 0` as `Timeout 0` — verified. Patched: the default comes from `State.Egress.#DEFAULTTIMEOUT` and a non-positive stored value takes it.
  - `[low]` `[reject]` `MaxAttempts` is unbounded above — real, but no shipped route writes that row in Release 1 and a ceiling parameter plus clamp is more than a direct correction.
  - `[medium]` `[defer]` every address judgement costs four resolver lookups plus `GetInterfacesInfo`, unbounded, on the write path and on every call — verified in `Egress.Addresses`. The lookups are what the intent mandates, so this is a cost the design creates rather than a deviation; deferred with the fix (a bounded, cached classification) named.
  - `[low]` `[reject]` `AgentRules.Validate` parses the catalog up to three times per call — Story 3.1's existing `Row()` pattern; negligible against a validation round trip.
  - `[low]` `[reject]` `InvokeDraft` normalizes but never validates, so a draft with no `maxTokens` reaches the wire as `0` — real, but it has no caller yet and the fix changes the port's output contract (a violations envelope). Story 3.4 is the first caller and owns field validation on its route.
  - `[low]` `[patch]` `Dispatch` mutates the caller's `pValues` undocumented — verified. Patched: both entry points now say so.
  - `[low]` `[patch]` `Base.Invoke` and `ProviderPort.Invoke` order their last two outputs oppositely, and a transposed call compiles — verified. The port follows the project's established shape and the base follows Task 12's stated signature, so the hazard is documented at the base rather than one of them re-ordered against its own spec.
  - `[low]` `[reject]` the installer rewrites and later deletes a pre-existing TLS configuration of the same name with no provenance record — true, and it is how every other `Ensure*` step in that class treats its own object; the name is in OcuPilot's own namespace.
  - `[low]` `[reject]` drift repair covers four properties and not `TLSMinVersion` / `CipherList` — by design: Task 16 names `VerifyPeer` and `CAFile`; widening it is a product decision.
  - `[low]` `[reject]` `Base.ProviderName()` is abstract with no caller — by design: Task 12 declares it as a family hook.
  - `[low]` `[reject]` `Response.LatencyMs` is asserted nowhere — real, but it has no consumer in this story and the only assertion available without a controlled clock is near-vacuous.
  - `[medium]` `[patch]` `Dispatch` computes the egress kind and discards it, so four different refusals are indistinguishable — verified. Patched: the kind goes to the log, not the envelope.
  - `[false]` `[reject]` the `claude-haiku-4-5` model-id change is unaccounted for — refuted: Task 2 asks for exactly that correction in as many words.
  - `[medium]` `[patch]` `Anthropic.MapResponse` accepts a JSON object as `content` and reports a successful empty reply — verified by reading: `$IsObject` passes an object and the iterator walks it by key. Patched: the guard now requires a `%Library.DynamicArray`, which is what the method's own doc claims.
  - `[low]` `[reject]` `CallMessages` can express only plain-text message content, so `tool_result` blocks cannot be sent back — real, and excluded by the intent's Never clause (no message translation layer; build step 7). Epic 4's turn extends the `pMessages` contract.
  - `[low]` `[patch]` `Test/Egress` builds a URL from an interface address without bracketing an IPv6 one — verified. Patched.
  - `[low]` `[reject]` `ProviderSecret.ErrorCount` compares row counts capped at 1000 and takes its date once — real, but the throwaway starts near zero errors and the midnight window is seconds a day; the per-entry read already uses each entry's own day.
  - `[low]` `[patch]` the `(inference)` label in `ProviderPort`'s header is malformed and carries its justification inline — verified against the project's prose rule. Patched.
  - `[low]` `[patch]` `ProviderStub.Recorded`'s doc lists ten keys and omits `contentType`, which a test asserts on — verified. Patched.
  - `[low]` `[patch]` `Test/ProviderConsumer`'s header claims one setup call reaches past the port when four more do — verified. Patched: it now separates what it arranges from what it asserts.
  - `[low]` `[reject]` `State.Egress`'s concurrent create can orphan a row, and `SetGuarded`'s partial-update semantics are untested — real, but no shipped route writes that row in Release 1 and a fixed singleton id is more than a direct correction.
  - `[low]` `[reject]` three classes are named `Egress` — spec-bound: Tasks 3, 8 and 20 name all three.
  - `[low]` `[reject]` an empty `GetInterfacesInfo` would make the instance's own address classify public — theoretical: the read is a vendor call that does not fail here, and failing closed would refuse every endpoint on a transient error.
  - `[high]` `[patch]` `0.0.0.0` and `::` classify `public` and are permitted — **measured**: `%Net.HttpRequest`, the client this port uses, reached the instance's own web server on `0.0.0.0` with HTTP 200 while `Egress.IsPermitted` answered 1. A loopback endpoint accepted with no marked-local flag and no catalog escape, which is the primitive AD-42 and DW-21 exist to remove. Patched: `IsLoopback` covers the unspecified address in both families and `Canonical` unwraps the IPv4-compatible form; pinned by `Test/Egress.TestTheUnspecifiedAddressIsNotPublic`, mutation applied, red, reverted.
  - `[medium]` `[patch]` a disabled definition is still callable — duplicate of the first entry; same patch.
  - `[medium]` `[defer]` the stored system prompt is dropped — duplicate; same deferral.
  - `[low]` `[reject]` `maxAttempts` has no ceiling — duplicate.
  - `[low]` `[patch]` the `Retry-After` clamp contradicts its doc — duplicate.
  - `[medium]` `[patch]` a 200 carrying an empty or unreadable `content` is reported as a successful blank — grouped with the `MapResponse` entry; the array guard covers the object case, and an empty array remains a reply this adapter reports as it was sent.
  - `[low]` `[reject]` `InvokeDraft` skips `Validate` — duplicate.
  - `[medium]` `[defer]` a hung resolver blocks the request process — duplicate.
  - `[low]` `[reject]` `AssertSslConfiguration` writes `Enabled` and does not read it back — by design: the method's doc scopes itself to AD-32's three properties, and `Test/ProviderSsl` asserts `Enabled` separately.
  - `[low]` `[reject]` `Test/ProviderPort`'s teardown deletes every `State.Egress` row, so a suite run would destroy an operator's stored settings — real, but nothing shipped can write that row in Release 1 and snapshot-and-restore is more than a direct correction.
  - `[low]` `[reject]` under the probe profile the port would name `OcuPilotProvider` while the installer created `OcuPilotProviderProbe` — real and unreachable: nothing calls the port under that profile, and production's suffix is empty.
  - `[false]` `[reject]` AC2 says every failure carries a `PROVIDER.*` code, and the two gate refusals carry `AUTH.*` — refuted: the intent's own matrix gives the anonymous and draft-privilege rows `AUTH.ANONYMOUS` and `AUTH.NOPRIVILEGE` explicitly, and no consumer branches on the prefix outside the four provider-failure classes.
  - `[low]` `[reject]` `Dispatch` resolves the adapter class before judging the endpoint, against Task 14's order — real, and it changes only which refusal a doubly-broken configuration reports; both refuse before any socket.
  - `[medium]` `[patch]` `securityChange` has no assertion — duplicate; same patch.
  - `[medium]` `[patch]` `MarkedLocal` joined `SecurityFields()` with no leg in the per-field test whose own doc says each field is exercised alone — verified at `Test/AgentState.cls:241`. Patched: the sixth leg added, header corrected from five to six.
  - `[medium]` `[patch]` the `MAX(hint, backoff)` rule is pinned only where the hint already wins, and the spec's AC5 mutation names a case no test contains — verified: attempt 1's window tops out at 1.0s against a 7-second hint. Patched: `Test/Provider` now drives `DelaySec` directly over both directions, and the AC5 mutation line is corrected.
  - `[medium]` `[patch]` `TestANonNumericRetryAfterIsDiscarded` cannot fail on the guard it names — verified on the instance: the HTTP-date string reads as 0 with or without the guard. Patched: `ParseRetryAfter` is asserted directly over five non-delta-seconds spellings.
  - `[medium]` `[patch]` the `Retry-After` ceiling and two of three declared retryable statuses are unexercised — verified by search. Patched: the clamp, the status table and its boundaries are asserted directly.
  - `[medium]` `[patch]` `ProviderPort.SslConfigurationMissing`'s shipped body runs in no test — verified: every class sets the probe's switch first. Patched: `Test/ProviderSsl`, already armed, asserts the real method for a present name, an absent one, and an unchanged namespace on both paths.
  - `[medium]` `[patch]` "the worst kind wins" has no case either way, because no resolvable name answers two kinds — verified. Patched: `Addresses` becomes an overridable seam in the idiom `Catalog.Table` and `Ladder.Environment` already use, with `Test/EgressProbe` supplying mixed sets.
  - `[medium]` `[patch]` the shipped outbound defaults are asserted against the parameters they are read from — verified: the same trap `Test/ProviderSsl` documents having measured. Patched: literals, plus the parameters pinned to the same literals.
  - `[medium]` `[patch]` the recorded AC5 mutation describes a case the tree does not contain — duplicate of the `MAX` entry; the mutation line is corrected there.
  - `[medium]` `[patch]` `Api/Error.cls` says the `PROVIDER.KEYSHAPE` reason states the expected prefix and `ReasonFor` returns no prefix — verified: a direct deviation from the matrix row, and a doc comment asserting the untrue half. Patched: the reason now names the row's prefix, asserted in `Test/Provider`.
  - `[medium]` `[patch]` no wire test sends `markedLocal`, and the three new violation codes are never observed as a 422 body — verified: the matrix states those rows at the wire and only the validator was exercised. Patched: `Test/AgentWire.TestACreateNamingARefusedAddressAnswersOneEnvelopeWithEveryViolation`.
  - `[medium]` `[patch]` `securityChange` untested — duplicate.
  - `[medium]` `[patch]` accumulation is not exercised for the three new codes — grouped with the wire-test entry; that test asserts the address violation, the local-unsupported violation and an unrelated one in one envelope.
  - `[low]` `[reject]` the instance-address rule reaches `Validate` through no test — the identical code path is exercised for loopback, link-local and local-unsupported; only the kind differs.
  - `[medium]` `[patch]` `AgentState`'s header says five security fields and `MarkedLocal` has no leg — duplicate.
  - `[medium]` `[patch]` the port's `%SYS` read is exercised by nothing — duplicate.
  - `[low]` `[patch]` `PROVIDER.EGRESS`'s HTTP 502 is unasserted while 401, 403 and 503 are — verified. Patched.
  - `[low]` `[patch]` the rebinding row is about a stored definition and every call-time test drives the draft entry — verified. Patched: `Test/ProviderPort.TestAStoredDefinitionIsJudgedAgainAtCallTime`.
  - `[medium]` `[patch]` the resolved kind is discarded — duplicate.
  - `[medium]` `[patch]` no test calls a `Retry` helper directly — duplicate.
  - `[medium]` `[patch]` AC6's second mutation does not falsify as the test is written — duplicate.

### 2026-09-15 — Code review (bmad-code-review, full; four layers)

- verdicts: 41 findings — high 0, medium 9, low 24, false 8
- patched (9 medium, 3 low):
  - `Test/EgressProbe.Addresses` used an argumented `Quit ##super(...)` on a method with no return type, raising `<COMMAND>`, which `Classify` swallowed into `unresolvable` for every host once the canned set was cleared — and the one assertion that named that behavior measured `..#EGRESS`, the shipped class, which has no seam to clear. Both fixed; the assertion now runs through the probe and was observed red against the restored bug.
  - `ProviderPort.SslConfigurationMissing` scored "could not check" as "absent". Measured: `Security.SSLConfigs.Exists` answers 0 with code 979 for a genuinely absent configuration and 0 with some other status for a read it could not perform, so an ordinary user running a turn — who holds nothing on the security database — would have been refused `PROVIDER.TLS` on every call, the opposite of the method's own documented fail-open contract. It now treats only 979 as absence.
  - `IsApiKeyShapeValid(pKey)` bound the credential to a local, against the intent's Always ("no local variable on the provider path ever holds key material"); the base conceded the exception in a doc comment instead of the code satisfying it. The argument is gone and the method reads `..ApiKey`, so the constraint is structural and the concession is deleted rather than reworded.
  - `Base.Invoke`'s outer `Catch` could leave `..ApiKey` set and carry an exception past the `$$$OK` the signature promises, since the clear ran in a later block. The clear is now the `Catch`'s first statement.
  - `Egress.IsLoopback` covered the literal `0.0.0.0` but not the rest of `0.0.0.0/8`, the same enumerate-rather-than-derive shape that admitted `0.0.0.0` in the first place. Widened to the block. Measured: only `0.0.0.0` reaches this instance; the others are refused at the socket, so this is completeness, not a live hole.
  - `Api/Error.AGENTENDPOINTADDRESS`'s doc claimed the write-time rule refuses a name that resolves to nothing, which `AgentRules.AddressViolation` deliberately does not and its own doc says so — the same "doc comment asserting the untrue half" already patched once for `PROVIDER.KEYSHAPE`.
  - `Kernel/State/Egress`'s `TimeoutSeconds` and `MaxAttempts` carried `InitialExpression` 90 and 3 while their docs said `0` means take the parameter, so a written row froze today's literals. Both start at 0.
  - Neither `MapResponse` shape guard ran in any test, including the array guard the previous pass added. Now pinned; see `## Verification` for what the mutation established about the top-level one.
  - `Base.NewRequest` never set `FollowRedirect`, leaving an egress bypass that re-sends the `x-api-key` to an unjudged host to a vendor default. Set explicitly and pinned.
  - `Test/SecretProbe`'s header claimed the `$Char(0)` normalization above it was exercised; it is inside the method the class replaces. Sentence corrected.
- **Two of the review's own additions were vacuous and were fixed before they landed:** the `followRedirect` assertion compared a `''`-normalised value, which cannot tell unset from 0; and the `InitialExpression` assertion compared resolved settings against the same parameter they default to. Both were caught by running the mutation rather than by reading, and both now discriminate.
- deferred (2 new): **DW-337** the stored proxy host is never egress-judged and `ProxyTunnel` defaults to 0, so a configured proxy is an unjudged destination that terminates TLS and sees the key (escalated: unreachable in Release 1, and refusing a loopback proxy would break a legitimate on-host forward proxy — a product call). **DW-338** `Egress.Addresses`' `HostNameToAddrMulti` half is unpinned; deleting it leaves the suite green because no host the suite resolves answers more than one address per family.
- settled: **DW-336** closed `resolved-by` this story with the mutation actually tried. **DW-335** carries an occurrence: its `Type` repair arm has the same missing-leg gap as its `Enabled` arm, so Story 3.3 should drift both.
- closed at emission: `PROVIDER.EGRESS`'s HTTP 502 and the link-local call-time code are spec-bound (the matrix states both); `fc00::/7` is by-design (Design Notes decided private ranges are not refused); `Validate`'s scheme/address `Else` is by-design (the address rule on a value whose scheme is already wrong would pay four resolver lookups on a string that is not an endpoint, and the write is refused either way); the provider's own message on `PROVIDER.UNAVAILABLE` is `wontfix-accepted`, reopen if a Test-connection user cannot diagnose a rate-limit refusal.
- **two documentation defects in the frozen intent block, amended by the lead under Rule 5:** the I/O matrix's link-local row named `AGENT.ENDPOINT.LINKLOCAL` for the call-time refusal where the port answers `PROVIDER.EGRESS`; Task 8 and Design Notes › Names called `OcuPilot.Kernel.State.Egress` 27 characters where it is 28, still inside the 29 cap.

## Design Notes

**Governing architecture decisions (Rule 6).**

- **AD-42** (`ARCHITECTURE-SPINE.md:448-454`) — the endpoint is an allow-list, not free text: administrative resource to write (shipped in 3.1), absolute HTTPS or a declared local address, never the instance/loopback/link-local unless marked local, audited as a security change; one base, adapters, Anthropic canonical, bounded timeout, retry only on a retryable status with the greater of the hint and backoff, **never after a mid-flight throw**, failure as a turn error. This story is AD-42's implementation; every clause has an AC.
- **AD-32** (`:378-382`) — the named SSL configuration the installer creates, server-identity checking on, never `DefaultSSL`; proxy is configuration, not code. Tasks 1, 8, 14, 16.
- **AD-35** (`:396-400`) + Conventions › Secrets (`:541`) — OcuPilot renders the very logs it writes, so the key never enters an exception, status, log line or trap. Task 12's `[ Internal ]` property and Task 24's proof.
- **AD-29** (`:358-362`) — *"a port without a named gate is a review failure."* `ProviderPort`'s gate is named and evaluated in two parts, below.
- **AD-12 / AD-39** (`:216`, `:426`, Conventions `:537`) — one envelope, `{error, reason, code, detail}`; vendor text normalised at the port boundary with the raw form kept for the log only. The provider's own message rides in `detail.providerText`; no field is added to the envelope.
- **AD-16** (`:242-246`) — `Security.SSLConfigs` lives in `%SYS`, and is not compiled into the install namespace, so both halves enter it: the installer's step inside the existing `%SYS` window, and `ProviderPort.SslConfigurationMissing` once, by explicit save and restore with the restore as the first line of the `Catch` and no `OcuPilot` class dispatched to inside the window. The port escalates nothing (AD-8) and so **fails open** — a caller holding no privilege on the security database gets the transport error the absent configuration causes anyway, while an administrator gets the named `PROVIDER.TLS` refusal. It still never falls back to another configuration and never proceeds unencrypted.
- **AD-9** (`:172-182`) — `Kernel/State/Egress.cls` inherits `Base`'s guarded methods and writes no escalation of its own; nothing is spawned from or re-enters an escalated frame, and no provider call is made from one.
- **AD-30** (`:364-370`) — read-only and the kill switch are Story 3.7's single enforcement point. This story adds no second one and reads neither.
- **AD-15** (`:236-240`) — an unregistered audit triple is dropped silently, so this story emits none. It hands `LogChange` a `securityChange` classification and Story 3.8 emits from that one seam. Same split Story 3.1 recorded.
- **AD-46** (`:486-492`) — OcuPilot's own log lines appear on OcuPilot's own log screens, which is exactly why AC6 exists rather than being a theoretical hardening.
- **AD-21** (`:284`) — *"anonymous does not mean unprivileged."* Task 15 moves the placeholder test to one home.
- **AD-48** (`:518`) — an `^ERRORS` entry captures **every local variable at every stack level**. That is the mechanism behind AC6's design and the reason the key is an object property rather than a local.

**`ProviderPort`'s named gate, and why it is not `OcuPilotAdmin`.** AD-29's rationale — *"a metric, a log line and an audit row reach a user through OcuPilot only if that user could have read them directly"* — does not transfer, because the provider call reads nothing of the instance's. What the port actually spends is the instance's credential against an endpoint an administrator already chose. So the gate is in two parts, both named and both evaluated in the port: **every** entry refuses an unauthenticated principal (`AUTH.ANONYMOUS`, AD-21), and the **draft** entry — the one that takes values from a caller rather than from OcuPilot's own state — additionally requires `OcuPilotAdmin:USE` (`AUTH.NOPRIVILEGE` with `detail.failedPair`), because an unsaved definition has not passed the write gate AD-42 puts on the endpoint field. An ordinary user running a turn goes through `Invoke`, whose endpoint came from the protected database.

**The local exception is a catalog column, not a provider name (the AD-42 / FR-27 reconciliation).** AD-42 and `epics.md:2316` refuse loopback *"unless the definition is explicitly marked local"*; `prd.md:530` and `epics.md:2391` say loopback and private-network hosts *"are allowed, because local models are a supported case"*; `EXPERIENCE.md:711` says the local model is *"not reproducible at the Anthropic-only floor: the local model is a step 7 provider."* All three hold together exactly when the escape is gated on a **catalog column** (`allowsLocal`) rather than on a provider name — the same move Story 3.1 made for rule 8's `endpointRequired`. At this floor the one shipped row sets it false, so the escape is closed in production and driven in tests through `CatalogProbe`; build step 7 opens it by adding a row. Two consequences worth stating plainly: **private-network ranges are not refused** — AD-42 names the instance, loopback and link-local and nothing else, and this container's own address is `172.19.0.2`, so a blanket RFC-1918 refusal would be both wider than the decision and self-defeating; and **link-local has no escape at all**, because `169.254.169.254` is the case FR-27 names and no local model lives there.

**Write time *and* call time, and what the residual gap actually is (DW-21).** Write time alone is defeated by a name repointed after the save — classic rebinding — and it is the only check that can tell the operator *on the field* that the endpoint is wrong, accumulated into 3.1's one round trip. Call time alone pays a resolver lookup on every turn, turns a resolver outage into a refusal rather than a connect error, and gives the operator no feedback until a turn fails. So: both. What "both" does **not** buy is closure. `%Net.HttpRequest` resolves the name itself when it connects, and there is no supported way to hand it a pre-resolved address while keeping SNI and the certificate identity match for that hostname — so between `HostNameToAddrMulti` and the socket's own resolution the answer can change (a TTL expiry, a round-robin rotation). The check raises the cost from "repoint DNS once" to "win a race against a lookup OcuPilot just performed"; it is defense in depth, not a proof **(inference** — no probe here observed a rebind race**)**. What actually contains an HTTPS endpoint is AC3's `VerifyPeer` 1 plus `SSLCheckServerIdentity` 1: a rebound address cannot present a certificate for the configured hostname. Which is precisely why the address check matters most on the `markedLocal` plain-HTTP path, where there is no TLS identity left to check.

**Two vendor traps the implementation must not walk into.** `$System.INetInfo.CheckAddressExist` reads like "is this address the instance's" and is a **ping** — probed, it answers 1 for `160.79.104.10`, Anthropic's own address — so using it would refuse every reachable endpoint. And `HostNameToAddr(host, 0)` follows `IsIPV6Enabled()`, which is an operator setting (0 here); the AAAA lookup works anyway, so families 1 and 2 are queried explicitly or an IPv6 loopback slips past on an IPv6-enabled instance.

**Why the key is an object property and never a local.** `^%ETN` captures the local symbol table at every stack level (AD-48), so any frame holding the resolved key when an entry is written puts it into a log OcuPilot renders. An object property is not in that table; the OREF a local holds stringifies to `"5@%Net.HttpRequest"`. That is why the harvest's `Property ApiKey [ Internal ]` survives the port and why `ApplyAuth` writes the header from `..ApiKey` straight onto the request rather than building a header list in a local first. The clear runs in a `Try`/`Catch` that executes on every exit, including the throwing one.

**What this story assumes about the credential seam (Story 3.3's).** The reference is two scalars — `CredType` and one of `EnvVarName` / `CredentialName`, already XOR-normalised by `AgentRules.Normalize` **:52**. Resolution returns a `%String`, never a `%Status`, so the value cannot ride in a status message; `""` is the only "unresolved" signal and produces `PROVIDER.CREDENTIAL` *before any call is made*. This story implements the environment-variable rung and nothing else; Story 3.3 replaces the body with the full ladder, adds the interoperability-namespace condition on the credentials rung, and owns DW-22's definition flagging. Nothing in the port changes when it does.

**Never-throw, in this project's terms.** The harvest's `Invoke()` *"always returns `$$$OK`; failures surface as `pProviderResponse.StopReason="error"`"* is kept exactly, and reconciled with the tree's port shape rather than replaced by it: the `%Status` return is always `$$$OK`, and the outcome travels in `pResponse.StopReason` plus the `(pHttpStatus, pFault)` pair `LogSourcePort.Page` **:419** already established. A test asserts `$$$OK` on every failure path, which is what makes "never throws" falsifiable rather than a claim about code that was never made to fail.

**The registry replaces the four-branch dispatch.** The harvest's `InstantiateProvider` is a four-way `If/ElseIf` on `pConfig.Provider` (`harvest/iris-session-agent.md:78`). Here the adapter class is a catalog column, so adding a family is one row plus one class, and `check_rename_tokens` keeps the harvested names out (`scripts/check-objectscript.py:273`, `FORBIDDEN_LITERALS` **:182-193**).

**Names.** `OcuPilot.Kernel.State.Egress` is 28 characters against the 29-character cap `check_naming` **:169,:344** applies to any class reaching `%Persistent`; `OcuPilot.Kernel.State.EgressSettings` is 36 and would make the compiler hash its storage global. The other new classes carry no storage and are not bound by the cap. The SSL configuration is `OcuPilotProvider`, never a harvested credential name.

## Verification

Every check below runs on the **throwaway** container `ocupilot-ci` (`bash scripts/ci-throwaway.sh`, project `ocupilot-ci`, 52776/1975 — it refuses `--project ocupilot`, `--web 52774` and `--super 1973`), never on the live `ocupilot` container. Nothing here creates an SSL configuration, a credential or a principal on the live instance, and no test opens a socket to any provider: `OcuPilot.Test.ProviderStub` overrides the base's `IssueHttpsPost` seam and answers a queued script of canned `(status, body, retry-after)` triples, so the whole provider path runs with no network.

**Commands:**

- `uv run scripts/check-objectscript.py` — expected: clean; the 17 rules include `check_naming`'s 29-character cap, `check_state_package_isolation`, `check_package_placement`, `check_rename_tokens`, `check_non_ascii_literals` and `check_destructive_test_guard`.
- `uv run scripts/test_check_objectscript.py` — expected: green (no new rule is added, so no new harness case).
- Compile every changed and new class through the IRIS MCP tools with `server: "ocupilot-iris"`, `namespace: "HSCUSTOM"` — expected: no error text.
- `bash scripts/lint-docs.sh` — expected: clean (this spec is the only Markdown this story touches).
- `node --test ui/tools/*.test.mjs` from `ui/` — expected: unchanged and green. This story adds no client file, no `strings.ts` key and no route, so `strings.test.mjs`'s 221 cardinality and `screen-mirror.mjs --check` are untouched.
- `bash scripts/ci-throwaway.sh` then `node ui/tools/ci-runner.mjs --container ocupilot-ci --class <one class>` — **one class per invocation, one invocation per message**, waiting for each run to land in `%UnitTest_Result` before sending the next, in this order: `OcuPilot.Test.Egress`, `OcuPilot.Test.Provider`, `OcuPilot.Test.ProviderPort`, `OcuPilot.Test.ProviderConsumer`, `OcuPilot.Test.ProviderSsl`, `OcuPilot.Test.ProviderSecret`, then the Story 3.1 regression trio `OcuPilot.Test.AgentRules`, `OcuPilot.Test.AgentSchema`, `OcuPilot.Test.AgentWire`. Confirm the totals with the `%UnitTest_Result` SQL probe in `.claude/rules/objectscript-testing.md` rather than from the runner envelope.

**AC6 — how the credential-never-leaks test is actually run, and on which container.** On `ocupilot-ci` only, armed by `OCUPILOT_ALLOW_ERROR_SEED`. The canary is a fabricated value of the right shape and no value — `sk-ant-ocupilotleakcanary0000000000` — so it passes the `keyPrefix` gate and is unmistakable in a grep; no real key is ever used. The test: (1) records the current byte length of `$System.Util.ManagerDirectory()_"messages.log"` and the current `SYS.ApplicationError` entry count for today, through `Port/LogSourcePort`'s own readers; (2) drives `ProviderPort` four times with the canary resolved through an overridden `SecretClass()` — a 401 body, a 429-until-exhausted sequence, a mid-flight throw, and one run whose stub calls `$$LOG^%ETN()` **from inside the adapter's own call frame**, which is the worst possible moment and forces a real `^ERRORS` entry rather than comparing two runs that both wrote nothing; (3) asserts each returned `reason`, `code` and `detail` is canary-free; (4) reads the bytes appended to `messages.log` since the mark and every `^ERRORS` entry recorded since the count, including its captured variable table, and asserts the canary appears in neither. The `$$LOG^%ETN()` leg is what makes the assertion non-vacuous: a row is written and the test asserts on its content.

**Recorded mutations (Rule 19) — one per AC, applied on the throwaway, observed red, reverted, and `git status --short` plus `git diff --stat` confirmed unchanged afterwards.**

*How one is applied:* to the throwaway's own copy of `src/`, never to the repository, so the tree is byte-identical by construction. **Recompile the whole tree** afterwards — `$System.OBJ.LoadDir("/opt/ocupilot/src", "ck", , 1)`, what the start hook runs. Recompiling only the mutated class leaves every subclass's own copy of an inherited method stale, and the mutation then reads as green: measured, on AC2, where a `Base.cls`-only recompile left all 18 tests passing and the same mutation failed 8 of them after a full one.

- **AC1** — `mutation:` add an `If pKey = "probe-local" { Set tClass = "..." }` branch in `ProviderPort`'s adapter resolution, bypassing the catalog column → `OcuPilot.Test.ProviderPort`'s "the adapter comes from the row, and a row pointing elsewhere is followed" assertion goes red, because `CatalogProbe`'s two probe rows name two different stubs and the branch would override the column.
- **AC2** — `mutation:` in `Kernel/Provider/Base.Invoke`, return an error `%Status` when `pFault` is set instead of `$$$OK` → `OcuPilot.Test.Provider`'s "`$$$OK` on every failure path" goes red on every forced failure class (observed: 8 of 18, run 72). Re-raising from `Invoke`'s own `Catch` does **not** falsify it — a mid-flight throw is caught one frame lower, in `Attempts`.
- **AC3** — `mutation:` set `SSLCheckServerIdentity = 0` where the port configures the request → `OcuPilot.Test.ProviderPort`'s configured-request assertion, read back from the stub's recorded request, goes red. Second mutation, for the installer half: change `EnsureSslConfiguration`'s `VerifyPeer` to 0 → `OcuPilot.Test.ProviderSsl`'s read-back through `Security.SSLConfigs.Get` goes red.
- **AC4** — `mutation:` in `Kernel/Egress.Classify`, range-test the literal before canonicalising it → `OcuPilot.Test.Egress`'s `https://2130706433/v1` case goes red (probed: it resolves to `127.0.0.1`, and `AddrType` calls it IPv4, so the dotted-quad test passes it). Second mutation, for the call-time half: delete the port's re-check → `OcuPilot.Test.ProviderPort`'s rebinding case goes red. Third mutation, added at review after the classifier was found to permit the unspecified address: drop the `0.0.0.0` term from `Kernel/Egress.IsLoopback` → `OcuPilot.Test.Egress.TestTheUnspecifiedAddressIsNotPublic` goes red, reporting `public` and permitted (observed, run 85). **Measured, not argued:** `%Net.HttpRequest` — the client the port itself uses — reached this instance's own web server on `0.0.0.0` with HTTP 200, so that classification licensed a loopback endpoint with no marked-local flag and no catalog escape.
- **AC5** — `mutation:` remove the `tMidFlight` break so a thrown call is retried → `OcuPilot.Test.Provider`'s "the transport seam is entered exactly once after a throw" goes red. Second mutation: replace `Retry.DelaySec`'s body with `Quit ..ParseRetryAfter(pRetryAfter)` → `OcuPilot.Test.Provider.TestTheRetryArithmeticOverItsWholeRange`'s mixed-draw leg goes red, because taking the hint alone answers the hint every time and the backoff can exceed it. The transport loop alone cannot falsify that rule — its one retry case uses a 7-second hint against a window that tops out at 1.0s, so hint-alone and greater-of-the-two answer the same number.
- **AC6** — `mutation:` hold the resolved key in a local in `Kernel/Provider/Base.Invoke` → every forced `^ERRORS` entry captures it and `OcuPilot.Test.ProviderSecret`'s variable-table assertion goes red (observed: 9 of 9 entries, run 74). **Not `Anthropic.ApplyAuth`**, which this spec named first: that frame has returned before either `$$LOG^%ETN()` leg runs, so a local there cannot appear in any forced entry and the class stays green (verified with a full recompile, run 73). The frames a forced entry does cover, and the one no forced entry can, are named at `Test/ProviderStub.ArmErrorLog`. Second mutation: interpolate the resolved key into the `PROVIDER.KEYSHAPE` reason → that leg's envelope assertion goes red. **Not the messages.log grep**, which this spec named first: the key-shape refusal writes no `LogRaw` at all, so its reason reaches no log by any path. The leg is also driven on a row whose prefix the canary fails rather than by substituting some other value, because a refusal made about a value the run does not care about proves nothing about the canary.
- **AC7** — `mutation:` make `ProviderPort.Invoke` return the error `%Status` instead of `$$$OK` plus a fault → `OcuPilot.Test.ProviderConsumer` goes red, since the consumer asserts on the turn-error envelope and never on a status.

**Mutations added at code review (2026-09-15), each applied to the live `ocupilot` tree, whole-tree recompiled, observed red, reverted; `git diff --stat` unchanged afterwards.**

- **AC4, the classifier's zero block** — `mutation:` narrow `Kernel/Egress.IsLoopback`'s zero arm from `$Piece(pAddress, ".", 1) = 0` back to `pAddress = "0.0.0.0"` → `Test/Egress.TestTheUnspecifiedAddressIsNotPublic` goes red on `0.0.0.1` and `0.1.2.3`, both reporting `public` and permitted (run 2105). Measured first: only `0.0.0.0` reaches this instance's web server (HTTP 200); `0.0.0.1`, `0.0.0.5` and `0.1.2.3` are refused at the socket with `#6059`. The block is refused whole because the enumeration, not the range, is what was wrong last time.
- **AC4, the resolver seam** — `mutation:` restore `Test/EgressProbe.Addresses`'s argumented `Quit ##super(...)` → `Test/Egress.TestTheWorstKindWinsOverAMixedRecordSet` goes red reporting kind `unresolvable` and an empty address (run 2105). The argumented `Quit` raises `<COMMAND>` on a method with no return type, which `Classify`'s own `Catch` swallows, so the probe answered `unresolvable` for every host once its canned set was cleared.
- **AC6 / AC3, the request's redirect behavior** — `mutation:` remove `Set tRequest.FollowRedirect = 0` from `Kernel/Provider/Base.NewRequest` → `Test/Provider.TestTheRequestCarriesTheSettingsItWasGiven` goes red (run 2107). The stub records the property raw rather than through `''`, because an unset `FollowRedirect` reads `""` and `''""` is 0 — normalised, the assertion could not tell "nobody set it" from "set to 0".
- **AC2, the reply's shape** — `mutation:` drop the `content`-array `%IsA` test from `Anthropic.MapResponse` → `Test/Provider.TestABodyOfTheWrongJsonShapeIsAFailure` goes red on the object-`content` leg (run 2107). Dropping the **top-level** `%IsA` test alone reddens neither leg, measured: a parsed non-`DynamicObject` is a `DynamicArray`, whose `content` is undefined, so the test below refuses the same bodies. That settles DW-336 — the guard is reachable but not independently falsifiable, and it earns its place by naming the cause in the log rather than by refusing anything.
- **Outbound defaults are deferred, not frozen** — `mutation:` give `Kernel/State/Egress.TimeoutSeconds` an `InitialExpression` of 90 → `Test/ProviderPort.TestAStoredRowStillTakesTheShippedDefaultsItDidNotName` goes red on the initial-value assertion (run 2109). Only the initial value separates the two: while the parameter and the frozen literal are the same number, resolving a row that froze one is indistinguishable from resolving a row that deferred to the other.

**Manual checks:**

- `docker compose ps` against the live container only, to confirm it was never recreated. `docker compose up`/`down` is never run against it.
- After the run, confirm the throwaway is torn down and that the live instance still holds exactly the two SSL configurations it started with (`ISC.FHIRExplorer.SSL.Config`, `ISC.FeatureTracker.SSL.Config`) — read through `iris_ssl_list` with `server: "ocupilot-iris"`, which creates nothing.

## Auto Run Result

**What this pass built.** The provider layer and its outbound edge: `Kernel/Egress` (the address
policy both the write rules and the port read), `Kernel/State/Egress` (stored proxy, timeout,
attempt bound and TLS name), `Kernel/Secret/Ladder` (the environment rung only),
`Kernel/Provider/{Response,Retry,Base,Anthropic}` and `Port/ProviderPort`. `Kernel/State/Base`
gains `SSLCONFIG`; `Kernel/Provider/Catalog` gains `adapterClass`, `allowsLocal` and `authVersion`,
which is what makes the adapter a registry row rather than a branch; `Kernel/State/Agent` gains
`MarkedLocal` and puts it in `SecurityFields()`; `Kernel/AgentRules` gains the scheme widening, the
address rule and the local-unsupported rule; `Api/Error` gains twelve codes; `Api/Definitions`
gains `markedLocal` and a `securityChange` classification on `LogChange`; `Screen/Gate` gains
`IsAuthenticatedPrincipal`, which `Api/Router` now calls so the two cannot drift; `Install/Installer`
gains `EnsureSslConfiguration` with read-back and drift repair, and removes it on uninstall;
`scripts/ci-throwaway.sh` arms `OCUPILOT_ALLOW_SSL_CONFIG`. Tests: `Test/{Egress,Provider,
ProviderPort,ProviderConsumer,ProviderSecret,ProviderSsl}` plus the fixtures `ProviderStub`,
`ProviderStubAlt`, `ProviderPortProbe`, `ProviderGate`, `SecretProbe`, `EgressProbe`;
`CatalogProbe` gained three rows, and `AgentRules`, `AgentState` and `AgentWire` gained legs.

**Review: 64 findings — high 1, medium 30, low 31, false 2.** Per-finding verdicts and the reason
each rejected finding was rejected are in `## Review Triage Log`; the breakdown by route is 39
patched, 3 deferred (2 root causes), 22 rejected.

The **high** was found by probe rather than by reading: `Kernel/Egress` classified `0.0.0.0` and
`::` as `public` and permitted them, and `%Net.HttpRequest` — the client the port itself uses —
reached this instance's own web server on `0.0.0.0` with HTTP 200. That is a loopback endpoint
accepted with no marked-local flag and no catalog escape, which is the request-forgery primitive
AD-42 and DW-21 exist to remove. `IsLoopback` now covers the unspecified address in both families
and `Canonical` unwraps the IPv4-compatible `::a.b.c.d` form; the mutation that removes the fix was
applied and observed red.

The other patches worth naming: the port never read `Enabled`, so Story 3.1's disable-on-security-change
was inert against its only consumer; the `PROVIDER.KEYSHAPE` reason did not state the expected
prefix, which the matrix row and `Api/Error`'s own doc comment both said it did; `MapResponse`
accepted a JSON object as `content` and reported a successful blank; and seven assertions could not
fail — `securityChange`, `MarkedLocal`'s membership of `SecurityFields()`, the retry arithmetic in
both directions, the `Retry-After` ceiling and status table, the port's own `%SYS` read, the
worst-kind-wins ranking, and the shipped defaults, which were asserted against the parameters they
are read from.

**Deferred (2).** The stored `systemPromptOverride` is read and dropped — which of it and the
caller's argument wins is a precedence rule no AC states, so it is Epic 4's to settle. And every
address judgement costs four resolver lookups plus a `GetInterfacesInfo` read, unbounded and
uncached, on the write path and on every call; the lookups are what the intent mandates, so the fix
is a bounded, cached classification rather than fewer checks.

**Verification.** `check-objectscript.py` clean over 17 rules and 251 files; its 85-case harness
green; `lint-docs.sh` clean; `ui` build and `npm test` green (720 node, 290 component). On the
throwaway `ocupilot-ci`, one class per invocation: **70 classes, 671 tests, 0 failed**, confirmed
independently by the `%UnitTest_Result` SQL probe (671/671/0), with no probe leftovers, no
overlapping runs and no foreign run. `smoke.sh` on the throwaway: 18 executed, 18 passed, 0 failed.
Mutations for AC2 and AC6 were unrecorded or false and were run here: AC2's has no recorded
predecessor and now does; AC6's named frame is genuinely unreachable and the entry says so.
**A mutation is only meaningful after a whole-tree recompile** — recompiling the mutated class
alone left AC2's mutation green, because every subclass keeps its own compiled copy of an inherited
method. The live `ocupilot` container was never recreated (0 restarts, last started 2026-09-11) and
still holds exactly the two TLS configurations it started with.

**Follow-up review recommended: true**, because a high was patched. The named unverified risk is
the shape of the address classifier, not this fix: it *enumerates* refused spellings rather than
deriving them, and the enumeration has now been wrong once. `::` and `::127.0.0.1` are classified
as reaching this host but were refused at the socket here, so whether another stack routes them is
unverified, and the next unenumerated spelling would fail the same way `0.0.0.0` did.

**Residual risks.** The live container's next restart will create `OcuPilotProvider` on it — AD-32's
intent, but a new security object, and the restart is the owner's call. Any probe install now also
creates `OcuPilotProviderProbe` wherever it runs. The write-time/call-time address check raises the
cost of a rebind but does not close it; what contains an HTTPS endpoint is `VerifyPeer` plus
`SSLCheckServerIdentity`, which is why the address check matters most on the marked-local
plain-HTTP path.

Status: done
Blocking condition: none
