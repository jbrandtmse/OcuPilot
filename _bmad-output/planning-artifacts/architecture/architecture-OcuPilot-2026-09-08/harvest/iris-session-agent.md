# Harvest map — iris-session-agent (OcuPilot agent core)

`/Users/jbrandt/git/iris-session-agent` · 170 `.cls`, **50,845 lines** (24,828 production + 26,017 test) + `static/chat-panel.js` (1,944).

Single root package `SessionAgent.*` — a package-level rename is the top-line job.

| Package | Lines | Reuse |
|---|---|---|
| `SessionAgent.Tool.*` | 8,304 | framework yes, the 28 Ens tools no |
| `SessionAgent.LLM.*` | 4,321 | **highest** |
| `SessionAgent.EnsPortal.*` | 2,629 | discard (Zen) |
| `SessionAgent.UI.*` | 2,038 | contracts only |
| `SessionAgent.Search.*` | 1,417 | domain-specific |
| `SessionAgent.Agent.*` | 1,319 | **highest** |
| `SessionAgent.Util.*` | 867 | **highest** |
| `SessionAgent.Installer` | 778 | design |
| `SessionAgent.Audit.*` | 629 | high |
| `SessionAgent.Task.*` | 606 | design |
| `SessionAgent.Config.*` | 414 | design |
| `SessionAgent.Chat.*` | 368 | high |
| `SessionAgent.Sample.*` | 1,000 | **do not harvest** |
| `SessionAgent.Test.*` | 26,017 | designs only — see §8 |

## 1. Provider layer — take nearly verbatim (~2,200 lines, rename-only)

| Path | Lines | Role |
|---|---|---|
| `src/SessionAgent/LLM/Provider.cls` | 598 | Abstract base; non-abstract `Invoke()` template method |
| `src/SessionAgent/LLM/AnthropicProvider.cls` | 757 | Messages API — **canonical passthrough, no translation** |
| `src/SessionAgent/LLM/OpenAIProvider.cls` | 612 | Chat Completions |
| `src/SessionAgent/LLM/GeminiProvider.cls` | 770 | `generateContent`; URL template interpolates `{model}` |
| `src/SessionAgent/LLM/OpenAICompatProvider.cls` | 702 | Ollama/vLLM/LM Studio/OpenRouter; `NormalizeChatCompletionsLocation()`; optional auth |
| `src/SessionAgent/LLM/Util/MessageAdapter.cls` | 692 | canonical(=Anthropic) ↔ OpenAI/Gemini, both directions |
| `src/SessionAgent/LLM/Util/ToolDefAdapter.cls` | ~190 | canonical `{name,description,input_schema}` → OpenAI/Gemini |
| `src/SessionAgent/Util/RetryWithBackoff.cls` | 440 | `IsRetryable`, `ParseRetryAfter`, `ParseGeminiRetryDelay`, `ExpBackoffSec` (full jitter) |

**Abstract contract:** 4 methods + 1 virtual hook —
`CallMessages(pCanonicalHistory, pToolDefs, pSystemPrompt, pCacheConfig, Output pProviderResponse)`, `GetEndpointUrl()`, `GetAuthHeader(pApiKey)`, `GetProviderName()`, and virtual `IsApiKeyShapeValid(pApiKey)`.

**`Invoke()` template flow:** `$ZHorolog` → `EnvSecret.Resolve` → credential-missing envelope → key-shape gate → virtual `..CallMessages()` → latency → `Audit.Emit.LogLlmCall(11 args)`. **Always returns `$$$OK`**; failures surface as `pProviderResponse.StopReason="error"`. *This never-throw discipline is the most portable decision in the repo.*

**HTTP:** `%Net.HttpRequest` direct. Each concrete has an identically-shaped **instance** method `IssueHttpsPost(pPayloadJson, pAuthHeaderList, pEndpointUrl, pTimeoutSec) As %DynamicObject` — deliberately an instance method so test subclasses override it to inject canned responses. Returns `{statusCode, bodyText, headers}`, not the raw `%Net.HttpResponse`. Clean seam.

**Gaps OcuPilot must close:**
- SSL hardcoded `Parameter SSLCONFIGURATION = "DefaultSSL"` on all four; applied only when `https=1`; no `SSLCheckServerIdentity`.
- **Proxy not handled anywhere** — `grep -rn "Proxy" src` = zero hits. `ProxyServer`/`ProxyPort`/`ProxyHTTPS`/`ProxyAuthorization` never set.
- Timeout `Parameter HTTPTIMEOUTSEC = 90` on all four; not operator-configurable.

**Retry design worth copying:** `RetryWithBackoff.Execute()` exists but the providers **don't** use it — it needs a `"Class.Method"` string via `$ClassMethod`, incompatible with instance-method virtual dispatch. Each concrete runs an inline `While tAttempt < tMaxAttempts` loop calling the *pure helpers*. Delay = `MAX(provider retry-after hint, exponential backoff)`. **Mid-flight idempotency rule:** if `IssueHttpsPost` *throws* (vs returning a retryable status), set `tMidFlight=1` and break without retrying — the request may already have been processed upstream.

| Provider | `PROVIDERNAME` | Auth header | Key gate | Adaptation |
|---|---|---|---|---|
| Anthropic | `anthropic` | `$ListBuild("x-api-key: "_key, "anthropic-version: 2023-06-01")` — a **%List** | `sk-ant-` | none |
| OpenAI | `openai` | `"Bearer "_key` (string) | `sk-` | `CanonicalToOpenAi`/`OpenAiToCanonical` |
| Gemini | `gemini` | `"x-goog-api-key: "_key` | `AIzaSy` | `CanonicalToGemini`/`GeminiToCanonical` + `ToGeminiSchema` |
| OpenAI-compat | `openai-compatible` | `"Bearer "_key` **or `""` → header omitted** (Ollama) | none | reuses the openai branch |

Prompt caching (`pCacheConfig = {SystemEnabled, ToolsEnabled}`) is set by AgentLoop **only** when `Provider="anthropic"`.

`$Char(0)` sentinel normalization appears in every `GetEndpointUrl()`, in `EnvSecret.Resolve` and in `AgentLoop` — carry the pattern.

## 2. Agent loop — take the design, rewrite the code

`src/SessionAgent/Agent/AgentLoop.cls` (930) · `CallerContext.cls` (~80) · `TurnResult.cls` (~70) · `ProviderResponse.cls` (~50) · `ProviderOverride.cls` (~190, test seam).

`ClassMethod RunTurn(pAgentName, pSessionKey, pPortalUser, pUserText, pContextHints) As TurnResult`

**Two blocking problems for OcuPilot:**
1. **Fully synchronous.** Called straight from a Zen `SendChatMessage` ZenMethod. No streaming, no JOB, no queue. The browser blocks for the whole turn. An Angular SPA with per-step progress needs `RunTurn` restructured into a resumable/step-wise form or backgrounded with a progress channel.
2. **No context-window trimming exists.** No trim/truncate/prune/summarize anywhere. Full conversation replayed every iteration, grows unboundedly until the provider rejects it. `Chat.Turn.ContentJson MAXLEN=65536`; `TurnsJson` is an unbounded stream.

10-step flow: build `CallerContext` at the trust boundary → `Chat.History.LoadOrCreate` (**exclusive-locked** OREF; NULLOREF → "Concurrent turn in progress") → read live `Config.Agent` **every turn** (hot config) → append user message → `Tool.Registry.ListTools()` → system prompt → iteration loop → save history (releases lock) → build `TurnResult` → return.

Iteration limit is two-tier: `Parameter MaxIterationsPerTurn = 10` floor, effective value from `Config.Agent.MaxIterationsPerTurn` (1–100). On cap-hit, `BuildMaxIterFallback()` synthesizes a 3-section message rather than a bare error.

**`CallerContext`** (`%RegisteredObject`, 6 props): `AgentName`, `IrisSessionId`, `SearchSessionKey`, `PortalUser`, `Namespace`, `ChatHistoryId`. **Enforced invariant in `Tool.Base` doc: tools MUST NEVER touch `%session`, `%request`, `$NAMESPACE` or Zen page state — everything arrives through `CallerContext`. Keep verbatim.**

`InstantiateProvider` (line 668) is a 4-branch `If/ElseIf` on `pConfig.Provider`. Adding a provider = one subclass + one branch. **OcuPilot should use a registry table instead.**

## 3. Tool framework — take the rules, improve the mechanism

`Tool/Base.cls` (326) · `Tool/Search/Base.cls` (246) · `Tool/Registry.cls` (323) · 28 concrete tools (~7,400 lines, all `MutatesState=0`, all Ens-specific).

Declaration = 3 parameters + 2 abstract classmethods:
`Parameter ToolName`, `Parameter Description`, `Parameter MutatesState`, `GetInputSchema() As %DynamicObject`, `Invoke(pCallerCtx, pJsonArgs, Output pResult) As %Status`.

**The locked cross-vendor JSON-Schema subset** — harvest the *rule*: top level `{type:"object", properties, required, additionalProperties:false}`; property level `{type, description, enum?, items?, minimum?, maximum?, minItems?, maxItems?}`. **Never** `$ref`/`oneOf`/`anyOf`/`allOf`/`pattern`. This is what makes one canonical tool array work across all four providers.

**Discovery** is reflection over `%Dictionary.ClassDefinition` with `%EXACT(Super) = 'SessionAgent.Tool.Base' OR ... 'SessionAgent.Tool.Search.Base'`. **Flat-`Super` limitation:** equality, not a superclass-chain walk, so every new intermediate base needs a hand-added `OR`, and the SQL is duplicated in `ListTools` and `ResolveToolName`. **OcuPilot: replace with `%IsA` or a recursive walk.**

**Dispatch** 8 steps: resolve → **L2 read-only enforcement** (reject any `MutatesState=1`, never invoking it) → timer → `$ClassMethod(cls,"Invoke")` in Try/Catch → latency → **unconditional** `Audit.Emit.LogToolCall` (success, error, unknown-tool and policy-block alike) → return `$$$OK`.

**Argument validation is per-tool, hand-written — there is no framework validator.** `additionalProperties:false` is enforced only by the provider. A schema-driven validator is a clear OcuPilot improvement.

MCP envelope: success `{content:[...], structuredContent:{...}}`; error `{isError:1, content:[{type:"text",text:"..."}]}`. Raw stack traces go to `Audit.ToolCall.ErrorText` only, never to `content[0].text`.

`Tool.Search.Base` adds `BuildBoundedWhereClause(...)` — an anti-runaway-query guard forcing every search onto a bounded time window on an indexed lead column. Reusable for any SMP query surface.

## 4. Secret resolution

`src/SessionAgent/Util/EnvSecret.cls` (~160). `Resolve(pEnvVarName, pCredentialName) As %String` — three-rung ladder, first non-empty wins:
1. `$SYSTEM.Util.GetEnviron(pEnvVarName)`
2. `Ens.Config.Credentials` — `%OpenId(name, 0)` (**concurrency=0, lock-free**, so LLM calls don't serialize on a credentials lock) then `.Password`, a `%CSP.Util.Passwd` fetching from `%SYS.Ensemble.SecondaryGet`. That indirection is where "not stored in readable form" actually comes from.
3. AES custom store — **v1 stub, returns `""`**.

Returns `%String` not `%Status`, deliberately, so the value can never land in a status message.

**`Ens.Config.Credentials` needs an interop-enabled namespace** — OcuPilot on plain IRIS Community (PRD OQ16) must swap this rung.

NEVER-LOG enforcement: `Config.Agent` has **no** `ApiKey` property (test `TestSchemaHasNoApiKey` locks it); `SaveAgentConfig` has **no** `pApiKey` parameter; the `IsApiKeyShapeValid` gate was added after a real bug where `EnvVarName=PATH` leaked the whole Windows `PATH` into an HTTP-401 echo. Concretes cache the key on `Property ApiKey [Internal]` and clear it before returning.

## 5. Persistence

| Class | Lines | Key properties | Index | Global |
|---|---|---|---|---|
| `Config/Agent.cls` | 212 | `AgentName`, `Provider`, `Model`, `MaxTokens`, `Temperature`, `SystemPromptOverride(8192)`, `CredentialName`, `EnvVarName`, `EndpointUrl(512)`, `ReadOnly [=1]`, `Enabled [=0]`, `MaxIterationsPerTurn(1..100)[=10]` | `AgentNameIdx [Unique]` | `^SessionAgent.Config.AgentD/I/S` |
| `Chat/History.cls` | 249 | `AgentName`, `SessionKey`, `PortalUser`, `TurnsJson As %Stream.GlobalCharacter`, `CreatedAt`, `UpdatedAt`, `ConfigSnapshot(2048)` | `ConvKeyIdx On (AgentName,SessionKey,PortalUser) [Unique]` | `^SessionAgent.Chat.HistoryD/I/S` |
| `Audit/LlmCall.cls` | — | `Timestamp`, `ChatHistoryId`, `Provider`, `Model`, `RequestTokens`, `ResponseTokens`, `LatencyMs`, `StopReason`, `CacheHitTokens`, `IsError`, `ErrorText(4096)` | `ChatHistoryIdIdx` | `^SessionAgent.Audit.LlmCallD/I/S` |
| `Audit/ToolCall.cls` | — | + `ToolName`, `ArgsJson(8192)`, `ResultJson(32768)`, `ResultSetSize`, `QueryTemplate(2048)`, `IndexUsed` | `ChatHistoryIdIdx` | `^SessionAgent.Audit.ToolCallD/I/S` |

**Hashed globals trap:** `Search.*` classes got compiler-generated `^SessionAgenC88B.*` / `^SessionAgeC88B.NamespaceVoDDDDD` because the name exceeded 31 chars. Brittle across a rename — OcuPilot should keep names short enough that the compiler doesn't hash.

**Per-conversation locking** (`Chat/History.cls:161`): existing row → `%OpenId(tId, 4, .pStatus)` (**concurrency=4 = exclusive**); new row → `%New()`+`%Save()`+`%Close()`+re-`%OpenId(id,4)` so both branches return an identically-locked OREF. NULLOREF on lock timeout with `pStatus` distinguishing lock conflict from persistence failure. Caller must `%Save()` (commit+release) or `%Close()` (discard+release); `AgentLoop.ReleaseChatHistory()` is called on every exit path including the outer catch.

**Audit dual-write** (`Audit/Emit.cls`, 289): each `Log*` persists a `%Persistent` row **and** emits `$System.Security.Audit("SessionAgent", "LlmCall"|"ToolCall", <provider|toolname>, ...)`. `EnsureEvents()` switches to `%SYS` and pre-registers **11 (Source,Type,Name) triples** — without pre-registration the native `Audit()` call silently no-ops.

Three purge tasks extend `%SYS.Task.Definition`, each ending with a `TaskRun` audit carrying `rows_deleted` / `scan_time_ms`.

## 6. Config form — the 11 validation rules

All server-side in `UI/AgentConfig.cls:SaveAgentConfig` (line 1115, rules ~1123–1270). Failures **accumulate** into `errors[]` as `{field, message}` so the operator sees everything in one round-trip. **No `pApiKey` parameter** — that absence is the schema invariant.

1 AgentName in the known set · 2 Provider in the known set · 3 MaxTokens 1–32000 · 4 Temperature 0–2 · 4b CredType in `{env,creds}` · 5 `env` ⇒ EnvVarName non-empty · 6 `creds` ⇒ CredentialName non-empty · 7 `openai-compatible` ⇒ EndpointUrl non-empty · 8 SystemPrompt ≤ 8192 · 9 retention 1–365 and `^[0-9]+$` · 10 MaxIterationsPerTurn 1–100 · 11 save-status catch-all.

**XOR credential invariant:** whichever of `EnvVarName`/`CredentialName` the radio didn't select is always cleared to `""`, so the `EnvSecret` ladder is deterministic.

**Provider cascade** across 4 members: `LoadProviderDefaults` [ZenMethod] → `AgentDefaults.GetCanonicalDefaults(provider)`; JS `onChangeProvider` orchestrator; `getCanonicalMaxTokens`; `providerChanged()` field cascade. The **preserve-when-customized heuristic**: snapshot pre-cascade MaxTokens and old provider, compute the *old* provider's canonical default, run the cascade, restore the pre-cascade value only if it differed from the old canonical.

Model suggestion lists are hardcoded in `providerChanged()` and duplicated against `AgentDefaults` — and are stale/fictional. **OcuPilot must source model lists from one place.**

**MPP5646 workaround** (already in `.claude/rules/iris-interoperability.md`): `Parameter PAGENAME = ""` + runtime `%OnGetPageName()`, all labels set in `%OnAfterCreatePage()`.

## 7. Names OcuPilot must not inherit

Package `SessionAgent` (+ 14 sub-packages) · ZPM module `iris-session-agent` · static dir `sa-static` → `/csp/<ns>/sa-static/` · asset page `/csp/<ns>/SessionAgent.UI.ChatPanelAsset.cls` · role `SessionAgent_ReadOnly` · **audit Source `SessionAgent`**, types `LlmCall`/`ToolCall`/`VocabWrite`/`TaskRun`, 11 registered triples · globals `^SessionAgent.*` and hashed `^SessionAgenC88B.*` · SQL schemas `SessionAgent_Chat`/`_Audit`/`_Search`/`_Config` · credentials `SessionAgentOpenAI`/`Anthropic`/`Gemini` · env vars `OPENAI_API_KEY`/`ANTHROPIC_API_KEY`/`GEMINI_API_KEY`/`GOOGLE_API_KEY`/`OLLAMA_API_KEY` · tasks `SessionAgent.PurgeOrphanedChatHistory`/`PurgeStaleSearchChat`/`UserVocabularyDecay` · agent ids `session-inspection`/`message-search` · JS globals `window.SessionAgentChat*` · CSS `--sa-*` / `sa-*` · `Parameter TARGETNAMESPACE = "HSCUSTOM"`.

No `SqlProcName`/`SqlProc` anywhere — the repo defines no stored procedures.

## 8. Tests — 26,017 lines, not portable

90 files, 51% of the repo. Each references `SessionAgent.*` 30–87 times, hard-coding FQ class names, SQL against `SessionAgent_*` schemas, literal agent and tool names, the audit Source string, and `%Dictionary` reflection filtering on `Super = 'SessionAgent.Tool.Base'`. **A package rename breaks essentially all of it.**

The **designs** are the harvest: the mock-provider seam (`ProviderOverride.SetOverride` + `IssueHttpsPost` override), the `*ProviderLive` split keeping network tests out of the unit run, and `ToolCallRoundtripIntegrationTest`'s 52-pair provider×tool matrix driven off `Registry.GetCanonicalToolDefs()` so fixture and runtime share one source of truth.
