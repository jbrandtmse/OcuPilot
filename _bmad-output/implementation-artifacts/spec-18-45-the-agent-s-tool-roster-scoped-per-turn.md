---
title: 'Story 18.45: The agent''s tool roster scoped per turn'
type: 'feature'
created: '2026-10-12'
status: 'draft'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-18-39-the-agent-s-context-budget.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Every provider call of a turn carries all 368 advertised tools: 525,414 characters (descriptions 112,090, schemas 387,162), about 190,700 tokens on `claude-opus-5-5` and 99% of the call (18.39 Task 0). 18.39 made a repeated call cheap through caching; it did not make a call smaller, so a model whose window cannot hold the roster cannot run a turn at all.

**Approach:** Choose each call's tool set after 20.24's listing and never inside it (AD-5, Rule 31): a turn starts with a small set and reaches the rest by the mechanism Design Notes recommends per family. Whether a tool reached only after a discovery step is acceptable is the owner's product-promise question (Auto Run Result); Tasks past Task 0 are written once it is answered.

## Boundaries & Constraints

**Always:** Dispatch, gates and governance are unchanged: any listed, advertised tool still dispatches by its wire name with every gate at call time (AD-8, AD-22). The listing is read through `ListTools` once per turn; the selection is a pure function of it and the turn's starting route. History stays append-only (AD-24). An unadvertised tool (AD-53) is never sent, found or dispatched.

**Never:** A second listing cache or a selection inside `Screen/Tool/Registry.cls` (Epic 20's file). Growing an Anthropic call's `tools` array within a turn (see Design Notes). Moving the OpenAI adapter to the Responses API. A new error code in `Api/Error.cls` (sibling class only). Building on a `decision-pending` entry.

## I/O & Edge-Case Matrix

Under option A, the recommendation (Design Notes).

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Anthropic call | any call of a turn | `tools` holds the whole advertised listing, byte-identical across the turn; every tool outside the starting set `defer_loading: true`; `cache_control` on the last non-deferred tool | a deferred tool never carries `cache_control` (a 400) |
| Other families | OpenAI, Gemini, compatible | `tools` holds the starting set, then the starting set plus each tool found so far | -- |
| Discovery | the model calls the discovery tool | Anthropic: the result is `tool_reference` blocks, expanded by the API; others: the found definitions are sent from the next call | no match: an ordinary empty result |
| No screen context | a turn from the panel alone | the starting set is the shell's tools and the discovery tool | -- |

</intent-contract>

## Code Map

Under `src/OcuPilot/` at `6846375c`. The 18.39 rework is editing `Loop.cls`, `Provider/Response.cls` and the adapters' `MapResponse`; implement re-anchors after it lands.

- `Kernel/Agent/Loop.cls`: `Run` :138 reads the route once (`ContextRoute` :60, used :161), takes the array once through `Advertise` :215-216 and passes it to every `Invoke` :239; `AnswerTools` :488 echoes `ContentJson`.
- `Kernel/Agent/Dispatch.cls`: `Advertise` :92 is `Registry.ProviderTools`; `AnswerOne` resolves any listed wire name (`ResolveWire` :208), so the selection changes no gate.
- `Screen/Tool/Registry.cls` (read-only here): `ListTools` :114 (20.24's per-process cache), `IsAdvertised` :337, `ProviderTools` :354 (the `pTools(n, name|description|inputSchema)` shape every adapter reads).
- `Screen/Context.cls` `ScreenTools` :178: a screen's read and write tools, advertised only, the source of the starting set.
- Shell tools (`Kernel/Shell/ReadTool` subclasses, e.g. `InstanceRead.cls`, plus `Screen/Tool/Navigate.cls`): `shell.instance.read`, `shell.namespaces.read`, `shell.privileges.read`, `shell.screen.open`.
- `Kernel/Provider/Anthropic.cls` `CallMessages` :64 (marks the last tool :103, the tail :92), `MapResponse` :158 (keeps `ContentJson` only on a reasoning block). `OpenAI.cls` `CallMessages` :58 (`ToolDefAdapter.ToOpenAi` :72; `Compatible` inherits it); `Gemini.cls` `CallMessages` :140 (`ToGemini` :99). `Catalog.cls` rows (OpenAI on `/v1/chat/completions`).
- `Kernel/Agent/Prompt.cls` `BUILTIN` :21 ("Use only the tools you are offered..."); `Kernel/Agent/Sanitize.cls` `Results` (AD-60).
- Tests on the old shape: `Test/AdapterCache.cls`, `TurnBudget.cls`, `Adapter.cls` `CANONICALBODY`, `TurnProvider.cls` `Recorded`, `TurnStream.cls`, `ScreenGrounding.cls`, `ReadTool.cls` (counts).

## Tasks & Acceptance

**Task 0** [ ] (`ocupilot-ci`, after `LOAD-OK` and `STARTPATH-OK`; keys from `/Users/jbrandt/git/OcuPilot/.env.local` read at the point of use, never printed, logged, ledgered or committed; halt on a contradiction). Record under Design Notes "For the lead": (a) each Anthropic catalog model's `max_input_tokens` (Models API) and the full roster request's `count_tokens`; (b) each Gemini catalog model's `inputTokenLimit` (`models.get`) and `countTokens` of the full request; (c) the OpenAI models' documented windows; (d) every family and model whose window cannot hold the full request plus the canonical 32,000 `max_tokens`, named; an absent key records "unmeasured". Parts (e) the scoped call's size against the full one and (f) one live scoped turn per family whose key exists are written with the Tasks.

**Execution:** written after the owner's answer (Auto Run Result).

**Acceptance Criteria** (epics.md, Story 18.45):

- **C1.** Given the registry's whole listing, cached per process (20.24), when a turn assembles a provider call, then the call carries a scoped tool set chosen after the listing and never inside it.
- **C2.** Given a supported family or model whose window cannot hold the full roster, when Task 0 measures each, then each is named and the scoped set fits it.
- **C3.** Given an advertised tool outside the starting set, when the agent needs it in the turn, then it reaches it by the mechanism the owner accepts, and dispatch answers it exactly as today.

## Spec Change Log

- 2026-10-12, owner (relayed by the Planner and the orchestrator, feature 3b01d9dd): "A: screen + search (Recommended)" -- the whole answer. As the owner saw it: "Current screen's tools, the general tools and a tool search; every other tool is reachable in the same turn after a search. One extra call when it reaches outside; works with every model, including local ones." Build A as this plan framed it.

## Review Triage Log

## Design Notes

**Families** (vendor docs read 2026-10-12: Anthropic tool search (`platform.claude.com/docs/en/agents-and-tools/tool-use/tool-search-tool`), the `claude-api` skill's model table; OpenAI `developers.openai.com/api/docs/guides/tools-tool-search` and models compare; Gemini `ai.google.dev` function calling, models).

| Family | Native deferral | Call carries | Model reaches the rest | Fallback |
|---|---|---|---|---|
| Anthropic (all five catalog models listed as supported) | `defer_loading: true` plus server search (`tool_search_tool_regex_20251119`, `_bm25_20251119`) or a custom search tool answering `tool_reference` blocks; no beta header | every definition on every call; deferred ones stay out of the context window and the cached prefix | after a search; "the API automatically expands these references" | none needed |
| OpenAI (`/v1/chat/completions`) | Responses API only ("In the Responses API, only `gpt-5.4` and later models support `tool_search`") | today: all | -- | OcuPilot's discovery tool; found definitions appended from the next call |
| Gemini | none: `allowed_function_names` still sends every declaration | today: all | -- | the same |
| Compatible (vLLM, Ollama, llama.cpp, LiteLLM) | none standard | today: all | -- | the same |

**Anthropic cannot grow its array.** Adding a plain tool mid-conversation invalidates every earlier thinking block (`tool_set_changed`, a 400 for accounts created on or after 2026-08-31 on Opus 5.5, Sonnet 5.5 and Fable 5.1) and restarts the cache; a `defer_loading` tool nothing has referenced is outside both comparisons (skill, `preserved-thinking-migration/causes.md`). So Anthropic declares the whole set up front, deferred, and a deferred tool may not carry `cache_control` (a 400): the marker moves to the last non-deferred tool. OpenAI with `reasoning_effort` `none`, Gemini and compatible servers bind no reasoning to the tool set (inference; Task 0 (f) confirms on Gemini 3's thought signatures).

**Recommended mechanism (option A):** one OcuPilot discovery tool for all four families (`shell.tools.find`, a `Kernel/Shell/ReadTool` subclass searching `ListTools`' names and descriptions, no second cache), answered to Anthropic as `tool_reference` blocks (Anthropic's documented "custom tool search implementation") and to the others by appending the found definitions. Starting set: the four shell tools, `ScreenTools` of the turn's route, and the discovery tool. Declined: Anthropic's server search, which saves one call per discovery but adds two response block types (`server_tool_use`, `tool_search_tool_result`) the adapter, the stream reader and the echo must keep, and a second search the other families cannot share.

**Size (inference from 18.39 Task 0's averages, 1,428 characters and about 520 tokens a tool):** a starting set of 5 to 15 tools is about 7,000 to 21,000 characters, 2,600 to 7,800 tokens, against 190,700. On Anthropic the request still carries all 525,414 characters of definitions, but the docs say "`defer_loading` controls what enters the context window, not what you send", and discovered definitions "count as input tokens like any other tool definition" (Task 0 (e) measures).

**Windows** (the full request about 190,700 tokens on Opus 5.5's tokenizer, plus 32,000 `max_tokens`): `claude-opus-5-5`, `claude-opus-5`, `claude-sonnet-5`, `claude-fable-5-1` 1M; `claude-haiku-4-5` 200K with an older tokenizer (about 141,000 to 191,000 tokens for the roster (inference)), at or past its window; `gpt-5.6-terra`, `-sol`, `-luna` 1,050,000, `gemini-2.5-pro` 1,048,576 and `gemini-3.5-flash` 1,000,000 (Perplexity citing each vendor's page, not read directly; Task 0 confirms), `gemini-3.8-flash` unverified; compatible servers take their model's configured window (vLLM `max_model_len`, Ollama `num_ctx`), commonly 8K to 128K (inference), so none holds the roster.

**Governing ADs:** AD-5 (20.24's listing; selection after it), AD-8, AD-11 (rule 1: `screen_context` never advertised), AD-22, AD-24 (as 18.39 amended), AD-31, AD-35 (Task 0's keys), AD-42, AD-53, AD-60. AD-22: no write key (a read tool).

**Rule 31.** Extends `ScreenTools`, `ListTools`, `Kernel/Shell/ReadTool` and 18.39's `Anthropic.CallMessages` marker; no second cache. **Rule 11** (checked at plan): Epic 20's diff names none of `Loop.cls`, `Dispatch.cls`, `Registry.cls` or the adapters; the prompt lists `Loop.cls` and `Dispatch.cls` as Epic 20's, and option A changes `Loop.Run`'s advertise point in place, so implement re-checks and stops if Epic 20's diff names either. **Fixed strings:** 3,279 of 3,400 (counted from `strings.test.mjs`'s extractor); none expected. **Bundle:** no client change expected.

**Integration ACs:** C3 is the integration AC (a turn through the turn job on `turnprobe`). **Consumes:** 20.24 (`ListTools`), 18.39 (caching, turn budget, billed-weight bound), 18.12 (the roster), 4.7 (navigation). **Consumed-by:** 18.40, 18.41 (rebase on `Anthropic.cls`). **Ledger inbox:** empty.

**For the lead** (Rule 20), proposed wording under option A, made at the spec gate once the owner answers:

- AD-8: "The full tool set is always advertised, save ..." becomes "The full tool set is always reachable within a turn, save ...: a call carries the turn's starting set, and every other advertised tool is reached through the discovery tool (AD-24)."
- AD-24 (18.39's paragraph): "The tool array is the listing's whole set (AD-5, AD-8), built once per turn and byte-identical on every call" becomes "The tool set is chosen after the listing, never inside it (AD-5): the turn starts with the shell's tools, the starting screen's tools and the discovery tool. A family that defers (Anthropic) sends the listing's whole set on every call, byte-identical within the turn, every other tool `defer_loading`, a found tool reaching the model as a `tool_reference`; any other family sends the starting set and appends each found definition from the next call, its cache restarting at the tools." "marks its last tool" becomes "marks its last non-deferred tool".
- AD-22: "while the tool stays advertised" becomes "while the tool stays reachable". AD-53: the discovery tool never finds an unadvertised tool. AD-60: a `tool_reference` block, a registry name with no instance data, passes unchanged.
- No vendor defect candidate.

## Verification

**Shared surfaces:** every provider body's `tools` (`CANONICALBODY`, `AdapterCache`'s last-tool marker, `TurnProvider.Recorded`), the built-in prompt's statements (`ScreenGrounding`), the read-tool roster and counts (`ReadTool`, `SurfaceCoverage`) if a discovery tool is added.

**Standing criterion:** every test added or changed passes on a fresh environment, in either order.

**Commands** (each inside one 10-minute foreground call; the class list is written with the Tasks):

- `(loop)` `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/carry-2026-10-08/epic-18-d8/load-ocupilot-ci.sh` -- expected `LOAD-OK` and `STARTPATH-OK`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one at a time, totals from `%UnitTest_Result`.
- `(loop)` `uv run scripts/check-objectscript.py`; `bash scripts/lint-docs.sh`.
- Full ObjectScript sweep: the runner's (a Rule 30 sweep task); browser suite: CI's.

## Auto Run Result

Status: blocked
Blocking condition: intent gap -- the owner's product-promise question for Story 18.45 (epics.md: "If the chosen mechanism changes what the agent can do in a turn ... that is the owner's product-promise question, raised at the spec gate before anything is built").

**Question for the owner (relay unchanged):** Every agent call today sends all 368 tools, about 190,700 tokens on Claude Opus 5.5 and 99% of the call; Claude Haiku 4.5 and most OpenAI-compatible local servers cannot hold that at all. Making the call smaller means the agent starts each turn holding only some tools. Which do you want?

- **A (recommended):** The agent starts each turn with the tools of the screen the user is on, the shell tools (instance, namespaces, privileges, navigation) and a tool search. Every other tool stays reachable in the same turn after the agent searches for it. Cost: one extra model call each time it needs a tool outside its starting set, and a tool the search does not surface is one it may not find. On Anthropic the full roster is still sent but held back until found, so caching keeps working; on OpenAI, Gemini and compatible servers the found tools join the next call.
- **B:** The agent gets only the current screen's and the shell tools, with no search; to act on another screen it navigates there and the user sends the next message. Smallest call, but no work across screens in one turn.
- **C:** Keep sending all 368 tools (18.39's caching keeps repeat calls fast on Anthropic) and name the models that cannot hold them as unsupported. Nothing changes for the agent.

**Planned:** intent, Code Map, family comparison with sources, Task 0's measurements independent of the answer, the epics' ACs, and AD-8, AD-22, AD-24, AD-53 and AD-60 wording under option A. **Not written:** Tasks 1 onward, their tests and `mutation:` plans, which depend on the answer. No call was made to `ocupilot-ci` or `ocupilot`, and no live provider call.
