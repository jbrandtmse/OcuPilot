# Harvest: iris-session-agent — round 1 — 2026-09-08

Sources consulted: 79 files under `/Users/jbrandt/git/iris-session-agent` (README.md, module.xml, ci.yml, 5 docs, 71 `.cls`/`.js` sources read in full or by targeted extraction) plus `git log`. Publisher for every source: the project author (jbrandtmse / Joshua Brandt, per module.xml `<Author>`). Last commit: 2026-06-10 (`6a2b272`); module.xml version `1.0.4` (committed 2026-05-11). Core classes last changed 2026-05-07/08.

Method note: source code was treated as primary; README claims were checked against code. Where a file was read only by `grep`/`sed` extraction (not end-to-end), the claim is limited to the extracted lines and marked accordingly.

## Architecture summary — with class/package map

**Single root package `SessionAgent`** (all shipped code; the only IPM resource is `SessionAgent.PKG`). Sub-packages and their classes, from the `src/` tree listing:

| Sub-package | Classes | Role |
|---|---|---|
| `SessionAgent.Agent` | `AgentLoop`, `CallerContext`, `ProviderResponse`, `TurnResult`, `ProviderOverride` (test-only injection holder) | Per-turn orchestrator + DTOs |
| `SessionAgent.LLM` | `Provider` (abstract), `OpenAIProvider`, `AnthropicProvider`, `GeminiProvider`, `OpenAICompatProvider`; `Util.MessageAdapter`, `Util.ToolDefAdapter` | Provider adapters + canonical-shape translation |
| `SessionAgent.Config` | `Agent` (`%Persistent`), `AgentDefaults` | Per-agent config row + seed/default helpers |
| `SessionAgent.Tool` | `Base` (abstract), `Registry`, `Search.Base` (abstract), `Inspection.*` (17), `Search.*` (11) | Tool contract, reflection registry, 28 tools |
| `SessionAgent.Audit` | `Emit`, `LlmCall` (`%Persistent`), `ToolCall` (`%Persistent`) | Audit ledger + `%SYS` audit-event registration |
| `SessionAgent.Chat` | `History` (`%Persistent`), `Turn` | Conversation storage (canonical Anthropic-shape turns in a stream) |
| `SessionAgent.UI` | `AgentConfig` (Zen page), `ChatPanel` (CSS emitter), `ChatPanelAsset` (`%CSP.Page` serving `chat-panel.js`) | Zen UI + static-asset delivery |
| `SessionAgent.EnsPortal` | `MessageViewer`, `VisualTrace`, `Util.ChatPanelDrawHelper` | Portal-page subclasses hosting the chat panel |
| `SessionAgent.Search` | `NamespaceVocabulary`, `UserVocabulary`, `SeedVocabulary` (all `%Persistent`), `VocabCapture`, `VocabularyDigest`, `SynthesizeAlias` | Search-agent vocabulary learning |
| `SessionAgent.Security` | `ReadOnlyRole` | RBAC role installer |
| `SessionAgent.Task` | `PurgeOrphanedChatHistory`, `PurgeStaleSearchChat`, `UserVocabularyDecay` (`%SYS.Task.Definition`) | Sweep tasks |
| `SessionAgent.Util` | `EnvSecret`, `Json`, `RetryWithBackoff` | Secret ladder, JSON helpers, retry policy |
| `SessionAgent.Sample` | `Production`, `Bootstrap`, `BS.OrderIngest`, `BP.OrderRouter`, `BP.OrderValidator`, `BO.SqlPersist`, `BO.FilePublish`, `Msg.*`, `Persist.OrderRow` | Dormant sample interop production (test fixture, ships in the package) |
| `SessionAgent.Installer` | (top-level class) | IPM `<Invoke>` orchestrator |
| `SessionAgent.Test` | ~95 classes | `%UnitTest` suite, mocks, fixtures |

Globals/SQL names observed: `^SessionAgent.Config.AgentD/I/S`, `^SessionAgent.Audit.LlmCallD`, `^SessionAgent.Chat.HistoryD`; SQL schemas `SessionAgent_Config.Agent`, `SessionAgent_Audit.LlmCall`, `SessionAgent_Audit.ToolCall`, `SessionAgent_Search.SeedVocabulary`. Role name `SessionAgent_ReadOnly`. Audit event source `"SessionAgent"`. Task names `SessionAgent.PurgeOrphanedChatHistory`, `SessionAgent.PurgeStaleSearchChat`, `SessionAgent.UserVocabularyDecay`. **Collision note for OcuPilot:** anything named `SessionAgent.*`, the role `SessionAgent_ReadOnly`, the audit source `SessionAgent`, or `/csp/<ns>/sa-static/` would collide if both modules are installed in one namespace.

### Agent loop (`SessionAgent.Agent.AgentLoop.RunTurn`)

Signature: `RunTurn(pAgentName, pSessionKey, pPortalUser, pUserText, pContextHints As %DynamicObject = "") As SessionAgent.Agent.TurnResult`. Synchronous, never throws (errors land in `TurnResult.AssistantMarkdown`). Steps read from the source:

1. Build `CallerContext` (AgentName, PortalUser, Namespace=`$NAMESPACE`, IrisSessionId **or** SearchSessionKey depending on agent name — the two agent names are hard-coded here).
2. `Chat.History.LoadOrCreate(...)` acquires an exclusive per-row lock (`%OpenId(id,4)`); lock conflict → "Concurrent turn in progress; please wait."
3. Read `Config.Agent` live every turn (hot config); "Agent not configured" / "Agent … is disabled" gates; `MaxIterationsPerTurn` normalised to class parameter default 10.
4. Append user turn; search agent's first turn gets a vocabulary-digest prefix (two-array invariant: digest never persisted).
7. Iteration loop `While (tIter < tMaxIter) && (tStop = 0)`: `InstantiateProvider(tConfig)` → `tProvider.ConfigAgent = tConfig` → `tProvider.Invoke(turns, toolDefs, sysPrompt, cacheCfg, config, ctx, .resp)` → parse `tool_use` blocks → `Tool.Registry.Dispatch(...)` per block → append `tool_result` turn → repeat. Anthropic gets `cache_control` on system block + last tool.
8. Max-iteration fallback builds a 3-section summary from `ToolCallsRendered`; cross-session tool dispatch produces a server-side prepended notice.
9. `TurnResult` carries `AssistantMarkdown` (MAXLEN 65536), `UsageRollup` (input/output/cache tokens), `DurationMs`, `ToolCallsRendered`.

**No streaming, no SSE.** The whole turn is one blocking ZenMethod hyperevent call; the only client-side polling is `IsChatHistoryLocked` every ~2 s while a "lock held" banner is visible. Per-call provider timeout is 90 s (`Parameter PerCallProviderTimeoutSec = 90` on AgentLoop; `HTTPTIMEOUTSEC = 90` on each concrete), with the README requiring the Web Gateway response timeout be raised to 300 s.

### Provider abstraction

`SessionAgent.LLM.Provider` (abstract, `%RegisteredObject`): four abstract methods — `CallMessages(history, toolDefs, systemPrompt, cacheConfig, Output resp)`, `GetEndpointUrl()`, `GetAuthHeader(apiKey)`, `GetProviderName()` — plus virtual `IsApiKeyShapeValid()` (default accept) and a non-overridable `Invoke()` template that resolves the key via `EnvSecret`, runs the shape check, calls `CallMessages`, computes latency, and emits one `Audit.LlmCall` row. Canonical wire shape **is the Anthropic Messages shape**; `MessageAdapter`/`ToolDefAdapter` translate to OpenAI Chat Completions and Gemini `generateContent`; OpenAI-compatible reuses the OpenAI branch. Each concrete owns its own inline retry loop using `RetryWithBackoff` helpers and its own `%Net.HttpRequest` build (`IssueHttpsPost`).

**Provider selection is not a registry.** `AgentLoop.InstantiateProvider` is an `If/ElseIf` chain on `Config.Agent.Provider` over the four literal strings; unknown → `$$$NULLOREF` → "Unsupported provider". The Provider class doc says "one subclass + one entry in the provider registry"; in code that entry is an edit to this chain, plus hard-coded provider lists in `UI.AgentConfig` (`valueList="openai,anthropic,gemini,openai-compatible"`, `SaveAgentConfig` Rule 2, the model-suggestion `switch`, `getCanonicalMaxTokens`) and `AgentDefaults.GetCanonicalDefaults`. A new wire shape also needs a branch in both adapters.

### API key storage

`Config.Agent` has **no ApiKey property** (doc comment states this explicitly; a test `ConfigAgentTest.TestSchemaHasNoApiKey` is referenced). It stores only `EnvVarName` and `CredentialName`. `Util.EnvSecret.Resolve(envVar, credName)` ladder: (1) `$SYSTEM.Util.GetEnviron(envVar)`; (2) `Ens.Config.Credentials.%OpenId(credName, 0).Password`; (3) `ResolveFromAesStore` — **a stub that returns `""`** (v1 ships the interface only). Canonical credential row names: `SessionAgentOpenAI`, `SessionAgentAnthropic`, `SessionAgentGemini`. Prefix shape checks: `sk-` (OpenAI), `sk-ant-` (Anthropic), `AIzaSy` (Gemini); OpenAI-compatible accepts anything including empty (Ollama no-auth). Never-log invariant is documented and enforced by review + one test; no encryption of its own.

### UI delivery

Entirely Zen/CSP, no REST, no dedicated web application:

- `SessionAgent.EnsPortal.VisualTrace Extends EnsPortal.VisualTrace` and `SessionAgent.EnsPortal.MessageViewer Extends EnsPortal.MessageViewer` — add a chat tab/pane; `%OnDrawHTMLHead` writes `<link>`/`<script>` tags for `/csp/<ns>/sa-static/{prism.min.css,marked.min.js,prism.min.js,dompurify.min.js}` and `/csp/<ns>/SessionAgent.UI.ChatPanelAsset.cls`.
- `SessionAgent.UI.ChatPanelAsset Extends %CSP.Page` streams `static/chat-panel.js` from the IPM module root with `CONTENTTYPE = "text/javascript"`.
- `SessionAgent.EnsPortal.Util.ChatPanelDrawHelper.DrawChatPanel(...)` emits the semantic HTML shell + `window.SessionAgentChat = {agentName, sessionKey, portalUser, priorTranscript, placeholder, ...}` bootstrap; `EmitConfigEmpty(agentName, isAdmin)` renders "This agent isn't configured yet" with a link to `AgentConfig.zen` for admins.
- `static/chat-panel.js` (1,944 lines, IIFE, no innerHTML, no CDN) calls `zenPage.SendChatMessage(agentName, sessionKey, userText, contextHintsJson)` synchronously and renders the returned JSON; Markdown via vendored marked → DOMPurify → Prism.
- ZenMethods (server surface): `SendChatMessage(...) As %String` returns `TurnResult.ToJson()` or `{"error":{"kind":"internal"|"lock_held","message":...}}`; `IsChatHistoryLocked(agent, sessionKey)` → `{"locked":bool}`; `RecordClickThrough(searchSessionKey, sessionId, contributingToolCallsJson)` (MessageViewer only).
- Observed: `VisualTrace` declares `Parameter PAGENAME = "Visual Trace + Agent"` (non-empty) whereas `MessageViewer` and `AgentConfig` declare `PAGENAME = ""` with the MPP5646 `%OnGetPageName()` workaround.

### Agent-config screen (`SessionAgent.UI.AgentConfig.zen`)

`Extends EnsPortal.Template.standardPage [ System = 4 ]`, `Parameter RESOURCE = "%Ens_Portal:USE"` (view gate only; an EDITRESOURCE is mentioned in the doc comment as future work and is not present). Form components (XData `contentPane`, labels set at runtime in `%OnAfterCreatePage` to dodge the `^IRIS.Msg` `<PROTECT>` codegen):

| id | control | values |
|---|---|---|
| `agentSelect` | select | `session-inspection,message-search` (display "Session Inspection,Message Search") |
| `providerSelect` | select | `openai,anthropic,gemini,openai-compatible` (display "OpenAI,Anthropic,Google Gemini,OpenAI-Compatible (Ollama/vLLM)") |
| `modelCombo` | editable combobox | per-provider suggestions set client-side in `providerChanged()`: openai `gpt-4.1-mini,gpt-4.1-nano,gpt-5-mini`; anthropic `claude-sonnet-4-5,claude-opus-4-7`; gemini `gemini-2.5-pro,gemini-3-pro`; openai-compatible `qwen2.5:32b,llama3.3:70b` — free text accepted |
| `endpointUrlText` | text, hidden unless openai-compatible | full URL incl. path |
| `credTypeRadio` | radioSet | `env,creds` (display "Environment Variable,Ens.Config.Credentials") |
| `envVarText` | text | env-var name |
| `credCombo` | editable combobox, hidden unless creds | populated by ZenMethod `GetCredentialsList()` from `Ens_Config.Credentials` |
| `maxTokensText`, `temperatureText`, `maxIterText`, `searchChatRetentionDays` (hidden), `systemPromptText` (textarea, live counter, 8192 cap), `enabledCheck`, `saveButton`, `cancelButton` | | |

Server ZenMethods: `LoadAgentConfig(agentName)`, `LoadProviderDefaults(provider)` (wraps `AgentDefaults.GetCanonicalDefaults`), `GetCredentialsList()`, `SaveAgentConfig(13 args)` returning `{success, errors:[{field,message}]}`. Validation rules in `SaveAgentConfig`: agent name in set; provider in set; MaxTokens positive integer ≤ 32000; Temperature in [0,2]; credType domain; env→EnvVarName required; creds→CredentialName required; openai-compatible→EndpointUrl required; system prompt ≤ 8192; retention 1–365; max-iter 1–100. Provider change cascades canonical model/cred/env/endpoint defaults and a MaxTokens heuristic (32000 cloud / 4096 compat). **No test-connection / ping action exists** (grep for `test.connection|TestConnection|ping` over the class returned no code). **No first-login gate**: seed rows ship `Enabled=0` and the chat panel shows the config-empty prompt per agent; nothing redirects an unconfigured user to the form.

### Extensibility mechanisms

- **Tool:** subclass `SessionAgent.Tool.Base` (or `Tool.Search.Base` for bounded-WHERE search tools); override `Parameter ToolName`, `Parameter Description`, `Parameter MutatesState` (default 0); implement `ClassMethod GetInputSchema() As %DynamicObject` (locked JSON-Schema subset: `type/properties/required/additionalProperties:false`, no `$ref/oneOf/anyOf/allOf/pattern`) and `ClassMethod Invoke(pCallerCtx, pJsonArgs, Output pResult) As %Status` returning an MCP envelope `{content:[…], structuredContent:{…}}` or `{isError:1, content:[…]}`. Discovery is reflection: `Registry.ListTools()` queries `%Dictionary.ClassDefinition WHERE Super = 'SessionAgent.Tool.Base' OR Super = 'SessionAgent.Tool.Search.Base' AND Abstract = 0` (direct superclass only — a new intermediate base needs another OR clause; `SessionAgent.Test.*` excluded). `Registry.Dispatch` refuses any `MutatesState=1` tool with "Tool blocked by read-only policy"; there is no permission model for mutating tools, only a blanket block.
- **Agent:** no registry. The two names `session-inspection` and `message-search` are literal in `AgentDefaults.GetSystemPrompt/GetSeedConfig`, `Installer.SeedDefaultAgentConfigs`, `AgentLoop.RunTurn` (CallerContext keying), `Registry.Dispatch` (`$Case` for audit key), `AgentConfig` `valueList` and Rule 1, and the two portal subclasses. A third agent requires edits in all of these.
- **Provider:** see above — one subclass of `LLM.Provider` plus edits to `AgentLoop.InstantiateProvider`, `AgentConfig` (three places), `AgentDefaults.GetCanonicalDefaults`, `SaveAgentConfig` Rule 2, and (for a new wire shape) `MessageAdapter`/`ToolDefAdapter`.

## Provider and model options — table

| provider (exact `Config.Agent.Provider`) | models/options | config fields | class | evidence path |
|---|---|---|---|---|
| `openai` | seed/default `gpt-4.1-mini`; form suggestions `gpt-4.1-mini, gpt-4.1-nano, gpt-5-mini`; free text. Endpoint default `https://api.openai.com/v1/chat/completions` (overridable via `EndpointUrl`). Auth `Bearer <key>`; key prefix check `sk-`. Payload: `model, temperature, max_tokens, tools` (function-wrapped) | `Model`, `MaxTokens` (seed 32000), `Temperature` (0.0), `EnvVarName` (`OPENAI_API_KEY`), `CredentialName` (`SessionAgentOpenAI`), `EndpointUrl` (optional), `SystemPromptOverride`, `MaxIterationsPerTurn`, `Enabled`, `ReadOnly`, `SearchChatRetentionDays` | `SessionAgent.LLM.OpenAIProvider` | `/Users/jbrandt/git/iris-session-agent/src/SessionAgent/LLM/OpenAIProvider.cls`; `.../Config/AgentDefaults.cls`; `.../UI/AgentConfig.cls` |
| `anthropic` | default `claude-haiku-4-5-20251001`; suggestions `claude-sonnet-4-5, claude-opus-4-7`. Endpoint `https://api.anthropic.com/v1/messages`; headers `x-api-key`, `anthropic-version: 2023-06-01`; prefix `sk-ant-`; `cache_control` on system block + last tool; canonical passthrough | same, env `ANTHROPIC_API_KEY`, cred `SessionAgentAnthropic` | `SessionAgent.LLM.AnthropicProvider` | `.../LLM/AnthropicProvider.cls`; `.../Agent/AgentLoop.cls` (cache flags) |
| `gemini` | default `gemini-2.5-flash`; suggestions `gemini-2.5-pro, gemini-3-pro`. Endpoint template `https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent`; header `x-goog-api-key`; prefix `AIzaSy`; `generationConfig.maxOutputTokens/temperature`; tools wrapped as a single `functionDeclarations` object; retry delay parsed from response body | same, env `GEMINI_API_KEY`, cred `SessionAgentGemini` | `SessionAgent.LLM.GeminiProvider` | `.../LLM/GeminiProvider.cls`; `.../LLM/Util/ToolDefAdapter.cls` |
| `openai-compatible` (Ollama / vLLM / LM Studio / any OpenAI Chat Completions endpoint) | default `qwen2.5:32b` (form) / README says `qwen3:14b`; suggestions `qwen2.5:32b, llama3.3:70b`. **`EndpointUrl` required** (form default `http://localhost:11434/v1`; `/chat/completions` auto-appended if absent); http or https; `Bearer` header only when a key resolves; no shape check; MaxTokens heuristic 4096 | same, env `OLLAMA_API_KEY` (may be empty), cred empty | `SessionAgent.LLM.OpenAICompatProvider` | `.../LLM/OpenAICompatProvider.cls`; `.../Config/AgentDefaults.cls` |
| **Not present:** Azure OpenAI, AWS Bedrock, Vertex AI, Cohere, Mistral | README §Contributing names Cohere/Bedrock/Vertex as candidates a contributor could add; no class exists | — | — | `/Users/jbrandt/git/iris-session-agent/README.md` (§Contributing); `src/SessionAgent/LLM/` listing |

Shared: SSL config name hard-coded `DefaultSSL` in all four concretes (`Parameter SSLCONFIGURATION = "DefaultSSL"`); HTTP timeout 90 s; retry via `Util.RetryWithBackoff` (MaxAttempts 4, base 1 s, cap 32 s, retry on 429/5xx, `Retry-After` honoured); no proxy properties set (grep for `Proxy` in all four providers returned nothing).

## Tool catalog — table

All 28 concrete tools declare `MutatesState = 0` (verified by grep across `src/SessionAgent/Tool/**`); `Registry.Dispatch` blocks anything else. Count reconciles with README/module.xml "28 tools" (29 `Parameter ToolName` hits minus the abstract `Tool.Base`). Evidence path for every row: `/Users/jbrandt/git/iris-session-agent/src/SessionAgent/Tool/<Inspection|Search>/<Class>.cls`.

| tool | purpose (from `Parameter Description`) | read/mutate | class |
|---|---|---|---|
| `session_summary` | Shape, duration, error count, root message class for an Ens session; `session_exists=false` when purged | read | `Tool.Inspection.SessionSummary` |
| `session_timeline` | Chronological message events (sender→receiver, timestamps) | read | `Tool.Inspection.SessionTimeline` |
| `message_headers` | `Ens.MessageHeader` rows for a session, optional min severity | read | `Tool.Inspection.MessageHeaders` |
| `event_log` | `Ens.Util.Log` entries for a session, filter by `message_id` / `min_severity` | read | `Tool.Inspection.EventLog` |
| `rule_log` | `Ens.Rule.Log` decisions for a session | read | `Tool.Inspection.RuleLog` |
| `explain_error` | Decode a `%Status` / IRIS error code into an operator explanation | read | `Tool.Inspection.ExplainError` |
| `get_message_detail` | Header + body summary + linked rule decisions for one message | read | `Tool.Inspection.GetMessageDetail` |
| `get_message_body` | Open/render a message body via body-class dispatch ladder | read | `Tool.Inspection.GetMessageBody` |
| `get_business_process_instance` | Persistent BP instance rows (+ `Ens.BP.Context`/`Thread` for BPL) | read | `Tool.Inspection.GetBusinessProcessInstance` |
| `get_business_process_source` | Structured source of a BP class (super, params, props, methods) | read | `Tool.Inspection.GetBusinessProcessSource` |
| `list_business_process_methods` | Compiled methods + signatures via `%Dictionary.CompiledMethod` | read | `Tool.Inspection.ListBusinessProcessMethods` |
| `find_related_sessions` | Sessions sharing a super-session key | read | `Tool.Inspection.FindRelatedSessions` |
| `find_sessions_by_body` | Sessions via `Ens.SearchTableBase` (PropName, PropValue) pivot | read | `Tool.Inspection.FindSessionsByBody` |
| `get_rule_source` | Raw RuleDefinition XData from a compiled rule class (Epic 13) | read | `Tool.Inspection.GetRuleSource` |
| `get_class_source` | Full ObjectScript source of any compiled class (Epic 13) | read | `Tool.Inspection.GetClassSource` |
| `get_queue_state` | Depth + oldest-message age of a named queue (Epic 13) | read | `Tool.Inspection.GetQueueState` |
| `get_production_config_item` | Adapter class, pool size, enabled flag, settings of a config item (Epic 13) | read | `Tool.Inspection.GetProductionConfigItem` |
| `search_by_session` | Single session by SessionId (keyed lookup, no time window) | read | `Tool.Search.SearchBySession` |
| `search_by_status` | Sessions by one or more Status values within a window | read | `Tool.Search.SearchByStatus` |
| `search_by_time` | Sessions in an ISO-8601 UTC window (default last 24 h) | read | `Tool.Search.SearchByTime` |
| `search_by_source` | Sessions by exact `SourceConfigName` | read | `Tool.Search.SearchBySource` |
| `search_by_target` | Sessions by exact `TargetConfigName` | read | `Tool.Search.SearchByTarget` |
| `search_by_message_class` | Sessions by full package-qualified `MessageBodyClassName` | read | `Tool.Search.SearchByMessageClass` |
| `search_by_super_session` | Sessions sharing a super-session key (key or seed session id) | read | `Tool.Search.SearchBySuperSession` |
| `search_by_body_field` | `Ens.SearchTableBase` pivot join (default window 168 h) | read | `Tool.Search.SearchByBodyField` |
| `inspect_body_candidates` | Indexed prefilter (≤50) then body-content substring/regex filter | read | `Tool.Search.InspectBodyCandidates` |
| `vocab_lookup` | List/save/search the operator's saved vocabulary aliases | read (declared 0; "save" mode writes `UserVocabulary` rows — see Leads) | `Tool.Search.VocabLookup` |
| `find_sessions_using_class` | Sessions referencing a class in Source/Target/MessageBodyClassName (Epic 13) | read | `Tool.Search.FindSessionsUsingClass` |

Search tools inherit the bounded-WHERE invariant from `Tool.Search.Base` (default window 24 h, max 720 h, keyed-lookup sentinel −1, parameterised binds only) and must declare `GetIndexedLeadColumns()`.

## Install and namespace behaviour

- **module.xml** (`/Users/jbrandt/git/iris-session-agent/module.xml`, v1.0.4): `<Packaging>module`, `<SourcesRoot>src`, one `<Resource Name="SessionAgent.PKG"/>`, one `<FileCopy Name="src/static/" Target="${cspdir}/${namespace}/sa-static/"/>`, three `<Invoke>`s in order: `SessionAgent.Installer.Install`, `SessionAgent.Audit.Emit.EnsureEvents`, `SessionAgent.Security.ReadOnlyRole.Install`. **No `<Dependencies>`, no `<CSPApplication>`/web-app element, no `<UnInstall>` hook, no `%ZSTART`, no Docker/compose artefacts in the granted tree, no IPM `<SystemRequirements>`.** Static assets are served by the pre-existing `/csp/<ns>/` web application (the doc comment records that a dedicated `/csp/static/...` web app failed because the Web Gateway only routes pre-existing prefixes).
- **`Installer.Install(pVars)`**: if called from `%SYS`, switches to `Parameter TARGETNAMESPACE = "HSCUSTOM"`; then (1) `Audit.Emit.EnsureEvents()` — `Security.Events.Create("SessionAgent", Type, Name, …)` in `%SYS`; (2) `ReadOnlyRole.Install()` — creates role `SessionAgent_ReadOnly` (no resources) and `$SYSTEM.SQL.Security.GrantPrivilege("SELECT", "Ens.MessageHeader,Ens.SuperSessionIndex,Ens_Util.Log,Ens_Rule.Log", "TABLE", role)`; (3) schedules three `%SYS.Task` rows (daily 02:00, daily 03:00, weekly Sunday 04:00; dedup by `Name` because `%SYS.Task` does not enforce uniqueness); (4) seeds two `Config.Agent` rows with `Enabled=0`; (5) `Search.SeedVocabulary.Seed()`; (6) prints bookmark URLs. Idempotent by explicit existence checks.
- **`Installer.InstallIntoNamespace(ns)`**: rejects `""` and `%SYS`; checks `Config.Namespaces.Exists` (doc notes `%ExistsId` returns 0 on 2024.1) and `Config.MapPackages.Exists(ns,"SessionAgent")` — the mapping itself is an operator step (`Config.MapPackages.Create`); requires an interop-enabled namespace (grant fails SQLCODE −30 otherwise); runs `Install()` in that namespace; copies `${cspdir}/hscustom/sa-static/` → `${cspdir}/<lower ns>/sa-static/` (non-fatal). Config rows, audit rows, chat history are per namespace.
- **IPM / IRIS versions**: README states IRIS / IRIS for Health **2024.1+** and IPM **0.10.x or later**, with the `zpm "enable -map -globally"` step; nothing in module.xml enforces either (README claim only).
- **Uninstall**: none in code; the README's teardown for the sample production is `Sample.Bootstrap.UninstallProduction()`; dropping the namespace removes rows.

## Reuse assessment — table

Classification is inference from the cited code: "reusable as-is" = no Zen/CSP coupling found in the class; "adapt" = usable with bounded edits; "rewrite" = Zen-bound or hard-wired to the two-agent design.

| component | verdict | reason | evidence path |
|---|---|---|---|
| `LLM.Provider` + 4 concretes + `Util.MessageAdapter` + `Util.ToolDefAdapter` | reusable as-is (adapt for new providers) | Pure `%RegisteredObject` + `%Net.HttpRequest`; only dependency on `Config.Agent` (via `ConfigAgent` property) and `Audit.Emit`. Adding Azure/Bedrock needs new subclasses + adapter branches | `src/SessionAgent/LLM/*.cls`, `src/SessionAgent/LLM/Util/*.cls` |
| `Util.EnvSecret`, `Util.RetryWithBackoff`, `Util.Json` | reusable as-is | No UI coupling; AES rung is a stub to fill if OcuPilot wants stored keys | `src/SessionAgent/Util/*.cls` |
| `Tool.Base`, `Tool.Search.Base`, `Tool.Registry` | reusable as-is / adapt | Contract is explicitly MCP-portable (no `%session`, no Zen state). Adapt: superclass-scan is direct-Super only; `MutatesState=1` is a hard block, so a permission model for OcuPilot's mutating settings-tools must be added to `Dispatch`; audit-key `$Case` hard-codes two agent names | `src/SessionAgent/Tool/Base.cls`, `Tool/Registry.cls`, `Tool/Search/Base.cls` |
| 28 `Tool.Inspection.*` / `Tool.Search.*` | reusable as-is | Interop diagnostics tools valid for any IRIS interop namespace; not needed for portal-settings screens but harvestable for a "Productions" area | `src/SessionAgent/Tool/**` |
| `Agent.AgentLoop`, `CallerContext`, `ProviderResponse`, `TurnResult` | adapt | Loop is UI-independent (single ClassMethod, JSON in/out) but keys on the two agent names, uses `pSessionKey` semantics tied to Ens sessions, and has no streaming/progress hook. `TurnResult.ToJson()` is already the envelope an Angular client could consume | `src/SessionAgent/Agent/AgentLoop.cls`, `Agent/TurnResult.cls` |
| `Config.Agent`, `Config.AgentDefaults` | adapt | Persistence shape is UI-neutral; agent-name enum and provider-canonical defaults are hard-coded; `SystemPromptOverride` MAXLEN 8192; OcuPilot needs an agent registry instead of two literals | `src/SessionAgent/Config/*.cls` |
| `Chat.History`, `Chat.Turn`, `Task.*` sweeps | adapt | Storage + exclusive-lock concurrency reusable; `SessionKey` keyed to Ens session / search GUID and orphan purge tied to `Ens.MessageHeader` — OcuPilot would key on screen/route context instead | `src/SessionAgent/Chat/*.cls`, `Task/*.cls` |
| `Audit.Emit`, `Audit.LlmCall`, `Audit.ToolCall` | reusable as-is | SQL ledger + `%SYS` event registration are UI-neutral; note `ChatHistoryId` is a `%String` (no real FK) | `src/SessionAgent/Audit/*.cls`, `docs/audit-sql-recipes.md` |
| `Security.ReadOnlyRole`, `Installer` | adapt | Patterns (idempotent role/grant/task/seed, `%SYS` save-restore, `InstallIntoNamespace` validation) are directly transferable; table list and role name are project-specific | `src/SessionAgent/Installer.cls`, `Security/ReadOnlyRole.cls` |
| `UI.AgentConfig` (Zen) | rewrite (harvest logic) | Zen page; but `SaveAgentConfig` validation rules, `GetCredentialsList`, `LoadProviderDefaults`, cascade heuristics are the spec for an Angular form + REST endpoint | `src/SessionAgent/UI/AgentConfig.cls` |
| `UI.ChatPanel`, `UI.ChatPanelAsset`, `EnsPortal.*`, `ChatPanelDrawHelper`, `static/chat-panel.js` | rewrite | Zen hyperevent transport (`zenPage.SendChatMessage`), `&html<>` emission, `EnsPortal.*` subclassing, `%CSP.Page` asset serving — none applies to an Angular SPA. Harvestable ideas: bootstrap context object, config-empty state, lock banner, citation-chip click-through, vendored Markdown pipeline | `src/SessionAgent/UI/ChatPanel*.cls`, `EnsPortal/*.cls`, `static/chat-panel.js` |
| `Search.*` vocabulary learning | optional adapt | Self-contained persistent classes; only relevant if OcuPilot keeps a message-search agent | `src/SessionAgent/Search/*.cls` |
| `Sample.*`, `Test.*` | reference only | Fixtures; the `%UnitTest` patterns (mock providers via `ProviderOverride`, roundtrip matrix) are worth copying | `src/SessionAgent/Sample/**`, `Test/**` |

**REST surface an Angular host would need (inference):** one POST that wraps `AgentLoop.RunTurn(agent, sessionKey, $Username, text, contextHints)` and returns `TurnResult.ToJson()` (or the `{error:{kind,message}}` envelope); one GET wrapping `Chat.History` load for transcript bootstrap (`FlattenTurnsForBootstrap` logic in the portal subclasses); one GET for lock state; CRUD for `Config.Agent` wrapping `LoadAgentConfig`/`SaveAgentConfig`/`GetCredentialsList`/`LoadProviderDefaults`; a GET for `Registry.ListTools()`. Streaming would require a new provider-side path — nothing exists today.

## Findings — claims

**Claim:** The project ships exactly four LLM providers — `openai`, `anthropic`, `gemini`, `openai-compatible` — selected by an `If/ElseIf` chain in `AgentLoop.InstantiateProvider`; no Azure OpenAI, Bedrock, Vertex, Cohere or Mistral adapter exists. | **Source:** /Users/jbrandt/git/iris-session-agent/src/SessionAgent/Agent/AgentLoop.cls (lines 668–702); /Users/jbrandt/git/iris-session-agent/src/SessionAgent/LLM/ (directory listing) | **Publisher:** project author | **Pub date:** 2026-05-08 (file), v1.0.4 | **Accessed:** 2026-09-08 | **Confidence:** high | **Class:** harvest

**Claim:** Exactly 28 concrete tools (17 inspection, 11 search) exist, all `MutatesState = 0`, and the reflection registry discovers only direct subclasses of `Tool.Base` or `Tool.Search.Base` while `Dispatch` refuses any `MutatesState = 1` tool. | **Source:** /Users/jbrandt/git/iris-session-agent/src/SessionAgent/Tool/** (grep of `Parameter ToolName/MutatesState`); /Users/jbrandt/git/iris-session-agent/src/SessionAgent/Tool/Registry.cls (`ListTools`, `Dispatch`, `ResolveToolName`) | **Publisher:** project author | **Pub date:** 2026-05-07 to 2026-05-09 | **Accessed:** 2026-09-08 | **Confidence:** high | **Class:** harvest

**Claim:** API keys are never persisted in `Config.Agent`; resolution is env-var → `Ens.Config.Credentials.Password` → an AES store rung that is an unimplemented stub returning `""`. | **Source:** /Users/jbrandt/git/iris-session-agent/src/SessionAgent/Util/EnvSecret.cls; /Users/jbrandt/git/iris-session-agent/src/SessionAgent/Config/Agent.cls | **Publisher:** project author | **Pub date:** 2026-05 (v1.0.4) | **Accessed:** 2026-09-08 | **Confidence:** high | **Class:** harvest

**Claim:** The agent loop is synchronous and non-streaming: one Zen hyperevent (`SendChatMessage`) blocks for the entire turn; provider HTTP timeout is 90 s; max iterations per turn is a per-agent config value 1–100 defaulting to 10; the only polling is a ~2 s lock probe. | **Source:** /Users/jbrandt/git/iris-session-agent/src/SessionAgent/Agent/AgentLoop.cls (Parameters, RunTurn steps 2–7); /Users/jbrandt/git/iris-session-agent/src/SessionAgent/EnsPortal/VisualTrace.cls (`SendChatMessage`, `IsChatHistoryLocked` doc); /Users/jbrandt/git/iris-session-agent/static/chat-panel.js (`submitTurn`, `checkLockState`); /Users/jbrandt/git/iris-session-agent/README.md (§3 Web Gateway timeout) | **Publisher:** project author | **Pub date:** 2026-05-08 / README 2026-06-10 | **Accessed:** 2026-09-08 | **Confidence:** high | **Class:** harvest

**Claim:** The UI is delivered purely through Zen: two `EnsPortal.*` page subclasses, one `EnsPortal.Template.standardPage` config form, a `%CSP.Page` that streams `chat-panel.js`, and a vendored Markdown bundle copied by IPM `<FileCopy>` into `${cspdir}/<ns>/sa-static/`; there are no REST endpoints and no module-created web application. | **Source:** /Users/jbrandt/git/iris-session-agent/module.xml; /Users/jbrandt/git/iris-session-agent/src/SessionAgent/UI/ChatPanelAsset.cls; /Users/jbrandt/git/iris-session-agent/src/SessionAgent/EnsPortal/VisualTrace.cls (lines 581–607); /Users/jbrandt/git/iris-session-agent/src/SessionAgent/EnsPortal/MessageViewer.cls (lines 535–557) | **Publisher:** project author | **Pub date:** 2026-05-11 (module.xml) | **Accessed:** 2026-09-08 | **Confidence:** high | **Class:** harvest

**Claim:** The agent-config form validates 11 rules server-side, offers editable model suggestions per provider (`gpt-4.1-mini,gpt-4.1-nano,gpt-5-mini` / `claude-sonnet-4-5,claude-opus-4-7` / `gemini-2.5-pro,gemini-3-pro` / `qwen2.5:32b,llama3.3:70b`), has no test-connection action, and gates only on `%Ens_Portal:USE`. | **Source:** /Users/jbrandt/git/iris-session-agent/src/SessionAgent/UI/AgentConfig.cls (XData `contentPane`, `%OnAfterCreatePage`, `providerChanged`, `SaveAgentConfig`) | **Publisher:** project author | **Pub date:** 2026-05-08 | **Accessed:** 2026-09-08 | **Confidence:** high (absence of test-connection: medium — grep-based) | **Class:** harvest

**Claim:** Install creates: `%SYS` audit event types under source `SessionAgent`; role `SessionAgent_ReadOnly` with SELECT on four `Ens.*` tables; three `%SYS.Task` entries; two seeded `Config.Agent` rows (`Enabled=0`); seed vocabulary rows. It creates no web app, no resource, no global mapping; package mapping to other namespaces is an operator step verified by `InstallIntoNamespace`. | **Source:** /Users/jbrandt/git/iris-session-agent/src/SessionAgent/Installer.cls; /Users/jbrandt/git/iris-session-agent/src/SessionAgent/Security/ReadOnlyRole.cls; /Users/jbrandt/git/iris-session-agent/src/SessionAgent/Audit/Emit.cls (`EnsureEvents`) | **Publisher:** project author | **Pub date:** 2026-05-08 | **Accessed:** 2026-09-08 | **Confidence:** high | **Class:** harvest

**Claim:** Pure-ObjectScript / no-embedded-Python is enforced by a CI grep (`grep -rn "Language = python" src/SessionAgent/` fails the build) and no-CDN by a second grep; `%UnitTest` execution is not in CI (TODO awaiting a Python-less IRIS image). | **Source:** /Users/jbrandt/git/iris-session-agent/.github/workflows/ci.yml | **Publisher:** project author | **Pub date:** v1.0.4 | **Accessed:** 2026-09-08 | **Confidence:** high | **Class:** harvest

**Claim:** Outbound LLM calls use `%Net.HttpRequest` with the SSL configuration name `DefaultSSL` hard-coded as a class parameter in each provider; no proxy configuration is set; retry policy is 4 attempts, exponential 1→32 s, on HTTP 429/5xx with `Retry-After` honoured. | **Source:** /Users/jbrandt/git/iris-session-agent/src/SessionAgent/LLM/{OpenAI,Anthropic,Gemini,OpenAICompat}Provider.cls (Parameters + retry-loop lines); /Users/jbrandt/git/iris-session-agent/src/SessionAgent/Util/RetryWithBackoff.cls | **Publisher:** project author | **Pub date:** 2026-05-07 | **Accessed:** 2026-09-08 | **Confidence:** high (proxy absence: medium — grep-based) | **Class:** harvest

**Claim:** Token usage is captured per call (`input_tokens`, `output_tokens`, `cache_creation_input_tokens`, `cache_read_input_tokens`) into `Audit.LlmCall` and rolled up into `TurnResult.UsageRollup`; no cost/pricing computation exists in code (pricing appears only as a README table). | **Source:** /Users/jbrandt/git/iris-session-agent/src/SessionAgent/LLM/Provider.cls (`Invoke` step 6); /Users/jbrandt/git/iris-session-agent/src/SessionAgent/Audit/LlmCall.cls; /Users/jbrandt/git/iris-session-agent/README.md (§6 pricing table) | **Publisher:** project author | **Pub date:** 2026-05-07 / 2026-06-10 | **Accessed:** 2026-09-08 | **Confidence:** high | **Class:** harvest

**Claim:** Every tool dispatch and every provider call writes an audit row (`SessionAgent_Audit.ToolCall` with `ArgsJson`/`ResultJson`, `SessionAgent_Audit.LlmCall`) and also emits `$System.Security.Audit("SessionAgent", …)`; audit rows reference chat history by a plain `%String` id, not an FK, so the purge task cascades manually. | **Source:** /Users/jbrandt/git/iris-session-agent/src/SessionAgent/Audit/Emit.cls; /Users/jbrandt/git/iris-session-agent/src/SessionAgent/Tool/Registry.cls (`Dispatch` step 7); /Users/jbrandt/git/iris-session-agent/src/SessionAgent/Task/PurgeOrphanedChatHistory.cls (header) | **Publisher:** project author | **Pub date:** 2026-05 | **Accessed:** 2026-09-08 | **Confidence:** high | **Class:** harvest

**Claim:** Streaming responses, MCP serving, PHI redaction, cross-namespace operation, vector search and LLM-generated aliases are explicitly out of v1 scope; cross-browser testing is deferred (Chrome only); the AES key store and a `CopyConfigBetweenNamespaces` helper are deferred. | **Source:** /Users/jbrandt/git/iris-session-agent/README.md (§Status, §Browser support, §Multi-Namespace Install); /Users/jbrandt/git/iris-session-agent/docs/testing/chrome-devtools-smoke.md; /Users/jbrandt/git/iris-session-agent/src/SessionAgent/Util/EnvSecret.cls | **Publisher:** project author | **Pub date:** 2026-06-10 (README) | **Accessed:** 2026-09-08 | **Confidence:** high (README claims consistent with code) | **Class:** harvest

**Claim:** The README's "adding a 5th provider needs one subclass + one registry entry, no shared-infrastructure edits" is only true of the server core; the Zen form, `AgentDefaults.GetCanonicalDefaults`, `SaveAgentConfig` Rule 2 and (for a new wire shape) both adapters also carry provider literals. | **Source:** /Users/jbrandt/git/iris-session-agent/README.md (§What it does, §Contributing) vs /Users/jbrandt/git/iris-session-agent/src/SessionAgent/UI/AgentConfig.cls, /Users/jbrandt/git/iris-session-agent/src/SessionAgent/Config/AgentDefaults.cls, /Users/jbrandt/git/iris-session-agent/src/SessionAgent/LLM/Util/MessageAdapter.cls | **Publisher:** project author | **Pub date:** 2026-05/06 | **Accessed:** 2026-09-08 | **Confidence:** high | **Class:** harvest

**Claim:** README and code disagree on the openai-compatible default model: README pricing table says `qwen3:14b`; `AgentDefaults.GetCanonicalDefaults` and the form suggestions say `qwen2.5:32b`. Code wins (recency rule; both files last touched May 2026, code is the executed value). | **Source:** /Users/jbrandt/git/iris-session-agent/README.md (§6 table) vs /Users/jbrandt/git/iris-session-agent/src/SessionAgent/Config/AgentDefaults.cls | **Publisher:** project author | **Pub date:** 2026-06-10 vs 2026-05-08 | **Accessed:** 2026-09-08 | **Confidence:** high | **Class:** harvest

## Leads — open questions

- `Tool.Search.VocabLookup` declares `MutatesState = 0` yet its description includes a "save" mode and `UserVocabulary.RecordSuccess` writes rows; the read-only invariant is scoped to `Ens.*` production data, not to the module's own tables. OcuPilot's permission model should define "mutation" precisely (only the description and parameter were read, not the `Invoke` body).
- `SessionAgent.EnsPortal.VisualTrace` sets `Parameter PAGENAME = "Visual Trace + Agent"` (non-empty) while sibling pages use `""` plus `%OnGetPageName()`; worth checking whether that page compiles on the OcuPilot container given OcuPilot's own MPP5646 rule.
- `Config.Agent.cls` contains a hand-written `Storage Default` XData (OcuPilot's rules forbid committing this); harvesting the class means stripping it.
- No test-connection endpoint exists; OcuPilot's "test connection" requirement needs a new provider-side method (a minimal `CallMessages` with `MaxTokens` small — the CI placeholder mentions `MaxOutputTokens=50` for the live matrix).
- The only remaining un-read parts of `AgentLoop.RunTurn` are steps 5–6 and the tool-dispatch body (lines ~240–555); tool-call rendering (`ToolCallsRendered` card shape) was not extracted.
- `_bmad-output/implementation-artifacts/deferred-work.md` (outside the granted set) is the authoritative TODO list referenced from README, `AgentConfig.cls`, `Installer.cls`.

## Gaps — what you looked for and could not find

- **Prompt-injection safeguards:** no code, comment or doc line mentioning prompt injection, tool-result sanitisation, or untrusted-content boundaries was found (grep over `src/` and `docs/`). System prompts in `AgentDefaults.GetSystemPrompt` contain only a read-only instruction and citation guidance.
- **Context-window management:** no history trimming, token budgeting or summarisation logic was found; `Chat.History.TurnsJson` is replayed in full each turn (`LoadTurns`), bounded only by `MaxIterationsPerTurn` and provider `max_tokens`.
- **Permission model for mutating tools:** none beyond the blanket `MutatesState=1` block and the `Config.Agent.ReadOnly` flag ("reserved for future write-capable agents").
- **Proxy / custom CA support for outbound HTTPS:** not present in the four provider classes.
- **Azure OpenAI / Bedrock / Vertex:** not present.
- **Cost computation:** not present in code.
- **Uninstall hook, `%ZSTART`, Docker/compose, IPM version constraint in module.xml:** not present.
- **A first-login "configure an agent" gate:** not present; closest analogue is `ChatPanelDrawHelper.EmitConfigEmpty` per panel.
- **Explicit `%AI.*`/AI Hub references:** not searched for directly; the claim "no AI Hub dependency" rests on README/module.xml text plus the observation that all provider I/O goes through `%Net.HttpRequest`.
