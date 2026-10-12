---
title: 'Story 18.45: The agent''s tool roster scoped per turn'
type: 'feature'
created: '2026-10-12'
status: 'done'
baseline_revision: 'c6e305f94a020c5f0f50e1aa2795d3af4c25d748'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-18-39-the-agent-s-context-budget.md'
warnings: ['oversized']
deferred:
  - summary: >-
      Gemini refuses five tools' declarations with 400, because `ToolDefAdapter.GeminiSchema` copies an INTEGER property's numeric `enum` members and Gemini's schema takes strings only; every Gemini request that carries one fails, and a scoped turn carries one from the call after it finds one.
    evidence: |-
      Task 0 on `ocupilot-ci`: `countTokens` of the full roster answered 400 at `security_secrets_creatersa`, `security_secrets_createsymmetric`, `security_secrets_replacersa`, `security_ssl_create` and `security_ssl_update` (`Length` `[2048,3072,4096]` and the like); `generateContent` with `security_secrets_creatersa` alone answered 400 and 200 with the members as strings.
      The fix is to write such members as strings in `GeminiSchema` and read them back in `GeminiToCanonical`, as the empty-enum respelling does; the scoped turn only postpones the failure to a turn that finds one of the five.
    location: >-
      src/OcuPilot/Kernel/Provider/ToolDefAdapter.cls:233
    severity: high
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

Under `src/OcuPilot/` at `0b5ef14df1dd1aaea66ea47b26ab0eb081bd6c1a`.

- `Kernel/Agent/Loop.cls`: `ContextRoute` :65; `Run` :143 (`Advertise` :221-226, `Invoke` :245); `AnswerTools` :503 (dispatch :623, step content :646, `Spend` :656, `Sanitize.Results` :661).
- `Kernel/Agent/Dispatch.cls` (not edited): `Advertise` :92 stays the whole listing; `Capped` :792 cuts `rows` whole.
- `Screen/Tool/Registry.cls` (read-only): `ListTools` :114, `WireName` :310, `IsAdvertised` :337, `ProviderTools` :354, `DescriptionOf` :498.
- `Api/Turn.cls` `BoundedContext` :534 sets the payload's `tools` (:543-545).
- Shell tools: `Kernel/Shell/*Read`, `Screen/Tool/Navigate.cls` (seam :62); `Kernel/Agent/Sanitize.cls` `Results` :38; `Prompt.cls` `BUILTIN` :21.
- `Kernel/Provider/Anthropic.cls` `CallMessages` :71 (tail :95-101, tools :103-114); `ToolDefAdapter.ToOpenAi` :72, `ToGemini` :99; `MessageAdapter.ResultText` :665; `Base.cls` :163 (`pTools`).
- Harnesses: `TurnToolsCase`, `ToolDispatchProbe.SetRegistryClass`; other families: `AnthropicThinking` :198-214; turn job: `TurnProvider`, `ToolWire` :124, `TurnStream` :410-433.

## Tasks & Acceptance

**Task 0** [x] (`ocupilot-ci`, after `LOAD-OK` and `STARTPATH-OK`; keys from `/Users/jbrandt/git/OcuPilot/.env.local` read at the point of use, never printed, logged, ledgered or committed, on a probe definition created and removed; halt on a contradiction). Under "For the lead": (a) each Anthropic catalog model's `max_input_tokens`, and `count_tokens` of the full and the scoped first request (else a `max_tokens` 1 call's usage, on `claude-haiku-5-5` only); (b) Gemini's `inputTokenLimit` and `countTokens` likewise; (c) OpenAI's documented windows; (d) each model that cannot hold the full request plus 32,000 `max_tokens`, named (Haiku 4.5 and local compatible servers expected; no key or server: "unmeasured"); (e) the scoped first call's and the largest starting set's characters and tokens against the full call's, and an Anthropic second call's `cache_read_input_tokens`; (f) one live scoped turn per family with a key: call 1 searches, call 2 calls the found tool, each 200. Every live Anthropic call, (e)'s cache read included, uses `claude-haiku-5-5` (owner, 2026-10-12); another Anthropic model only for a check about that model, named with the reason. Record Haiku 5.5's figures beside 18.39's Opus ones, naming the model of each.

**Execution:**

1. [x] `Screen/Tool/ToolsFind.cls` (new, extends `Screen/Tool/Base` as `Navigate` does) -- `shell.tools.find`, read, no pairs, no secret arguments; input `query` (string, required, at most 200), `limit` (integer 1 to 20, default 8). Over `RegistryClass()`'s `ListTools` (a seam), every advertised tool but itself: a query word (lower case, alphanumeric runs of 2+, first 10) scores 2 when the canonical name contains it, else 1 when `DescriptionOf` does; 0 dropped; by score, then name; answers `{query, rows: [{name: wire name, description}], rowsAvailable, truncated}`. No word: `TOOL.ARGUMENTS`. Description: "Search the tools you were not given at the start of this turn by what they do; a tool found can be called from your next step."
2. [x] `Kernel/Agent/Loop.cls` -- (a) `ContextTools(pContextJson)`, sibling of `ContextRoute`: the payload's `tools`. (b) `Scope(ByRef pTools, pContextJson)`, once after `Advertise`: when the array holds the discovery tool, sets `pTools("scoped")` 1 and `pTools(n, "start")` 1 for each `shell_` wire name and each `ContextTools` name; else leaves it whole. (c) `AnswerTools` gains a trailing optional `ByRef pTools`: after `Spend`, a non-error discovery result on a scoped array gets `content` = one `{"type":"tool_reference","tool_name":<wire>}` per row in the array (an absent tool is a 400) and not `start`, in row order, each such tool given the next `pTools(n, "found")` once; with none, the content stays. (d) Header.
3. [x] `Kernel/Provider/Base.cls` -- `pTools` doc: `scoped`, `start`, `found`; absent means the whole array.
4. [x] `Kernel/Provider/Anthropic.cls` -- scoped: every tool sent, `defer_loading: true` without `start`, `cache_control` on the last `start` tool, never on a deferred one; unscoped unchanged.
5. [x] `Kernel/Provider/ToolDefAdapter.cls` -- `Carried(ByRef pTools)`: every index unscoped; scoped, `start` in array order then `found` by number. `ToOpenAi` and `ToGemini` iterate it.
6. [x] `Kernel/Provider/MessageAdapter.cls` -- `ResultText`: content of `tool_reference` blocks only reads `Found tools you can call from your next step: <names, comma-separated>.`
7. [x] `Kernel/Agent/Sanitize.cls` -- `Results`: a non-empty array of blocks each exactly `{type: tool_reference, tool_name}` matching `^[a-zA-Z0-9_-]{1,64}$` passes unchanged; anything else as today.
8. [x] `Kernel/Agent/Prompt.cls` -- statement 5, in place: "Your tools start with the shell's and this screen's; shell_tools_find finds any other tool by what it does, callable from your next step. Use only the tools you are offered or find, and when a search finds none that can do what was asked, say so rather than describe a capability you lack."

**Tests** (under 500 lines each; `mutation:` lines when observed):

9. [x] Fixtures `Test/ScopeTool/`: `Registry` (extends `DispatchTool.Registry`, package `OcuPilot.Test.ScopeTool.`), `Find` (extends `ToolsFind` on it), `Reader` (`probe.found.read`), `Shell` (`shell.probe.read`), the last two extending `DispatchTool.Counter`.
10. [x] `Test/ToolsFind.cls`: "permissions users read" ranks `permissions_users_read` first; never itself or an unadvertised tool; `limit`, `rowsAvailable`; no word refused; no match `rows` []. mutation: no `IsAdvertised` check.
11. [x] `Test/TurnScope.cls` (`TurnToolsCase`, `ScopeTool`): (a, C1, C3) call 1 searches "found", call 2 calls `probe_found_read`, call 3 ends: the same `tools` text each call, only it deferred, the marker on the last non-deferred tool; call 2 carries its `tool_reference`; dispatched once, step ok. mutation: `Scope` marks all `start`. (b) a context naming it sends it undeferred. (c) `DispatchTool`, with no discovery tool, sends every tool undeferred, marker last. mutation: no discovery check. (d, C2) every built screen's starting set, as `ToOpenAi` carries it, is at most 65,536 characters; the largest recorded. mutation: `Carried` answers every index.
12. [x] `Test/TurnScopeFamilies.cls` (openai, gemini, compatible, as `AnthropicThinking` reaches them): call 1 carries the starting set only, call 2 adds `probe_found_read` after it, the tool message names it, dispatched once. mutation: no `found` set.
13. [x] `Test/AdapterScope.cls` (driven as `AdapterCache` is): tasks 4-6; unscoped unchanged. mutations: the marker on a deferred last tool; old `ResultText`.
14. [x] `Test/Sanitize.cls`, one method: task 7's pass, idempotent; a bad name, an extra member or a mixed array framed. mutation: pass any array.
15. [x] `Test/ToolWire.cls`, one method (Integration): call 1 searches "permissions users read", call 2 calls `permissions_users_read` `{maxRows: 5}`: the same `tools` text each call with it deferred, call 2's `tool_result` its `tool_reference`, both steps ok. mutation: no (c) replacement.
16. [x] `Test/ScreenGrounding.cls`: `Statement` 5 is task 8's. mutation: the old text.
17. [x] **Rule 30 sweep.** Rosters: `ReadTool` :94-95 (374, names), `DeveloperFloor.TOOLS` and its count message, `InteropFloor.BASETOOLS`, `InteropFloorOwnPairs.FLOORONLY` (`tool:shell.tools.find=no classic resource`), `ToolRoundTrip.REFUSEEMPTY` (`shell.tools.find:TOOL.ARGUMENTS`), `TurnStream` :425 (last non-deferred tool). Grep `src/OcuPilot/Test` for `shell.screen.open`, `"tools")`, `MarkOf(`, `373` and the old statement 5; run each class changed plus `AnthropicThinking`, `TurnTools`, `TurnBudget`, `AdapterCache`, `Adapter`, `LedgerWire`, `TurnNavigate`, `ToolSetFull`, `RegistryCache`, `InteropFloorTurn`, `DeveloperFloorTurn`, editing only if red.

**Acceptance Criteria** (epics.md, Story 18.45):

- **C1.** Given the registry's whole listing, cached per process (20.24), when a turn assembles a provider call, then the call carries a scoped tool set chosen after the listing and never inside it.
- **C2.** Given a supported family or model whose window cannot hold the full roster, when Task 0 measures each, then each is named and the scoped set fits it.
- **C3.** Given an advertised tool outside the starting set, when the agent needs it in the turn, then it reaches it by the mechanism the owner accepts, and dispatch answers it exactly as today.
- **Integration.** Given `ocupilot-ci` and the `turnprobe` row, when a turn through the turn job searches and then calls the found tool, then both answer and the requests carry task 4's array and the `tool_reference`.

## Spec Change Log

- 2026-10-12, lead, spec gate: A built as planned; AD-8 (with the owner's choice quoted), AD-24, AD-22, AD-53 and AD-60 amended as proposed. Owner, relayed the same morning: every live Anthropic check uses `claude-haiku-5-5` (Task 0 (a), (e), (f)). Rule 11: the `ReadTool` :94 count and `DeveloperFloor`'s count message need the orchestrator's pre-authorization as unions; the other roster edits are add-only.
- 2026-10-12, owner (relayed by the Planner and the orchestrator, feature 3b01d9dd): "A: screen + search (Recommended)" -- the whole answer. As the owner saw it: "Current screen's tools, the general tools and a tool search; every other tool is reachable in the same turn after a search. One extra call when it reaches outside; works with every model, including local ones." Build A as this plan framed it.

## Review Triage Log

### 2026-10-12 -- Review pass

- verdicts: 12 findings -- high 2, medium 2, low 3, false 5, maybe-false 0
- findings:
  - `[medium]` `[patch]` The description branch of `ToolsFind.Score` was pinned by no test (verification-gap) -- added `ToolsFind.TestADescriptionAloneFindsATool`; with the branch dropped it alone goes red (run 760).
  - `[medium]` `[patch]` `Loop.Found`'s numbering was exercised for one tool in one search (verification-gap) -- added `TurnScopeFamilies.TestASecondSearchAppendsAfterWhatTheFirstFound` (OpenAI, four calls); with the numbering restarted per search it alone goes red (run 761). `PrepareFamily` is the setup `AssertScopedTurn` shared. Numbering two new tools in reverse inside one answer stays unpinned: the fixture listing gives no tool order that tells row order from array order.
  - `[high]` `[defer]` Five declarations (`security_secrets_creatersa`, `security_secrets_createsymmetric`, `security_secrets_replacersa`, `security_ssl_create`, `security_ssl_update`) make Gemini answer 400, and no test asserts a starting set is Gemini-valid (verification-gap, other) -- pre-existing: every Gemini request carrying the whole roster failed before this story; recorded once in `deferred:`.
  - `[low]` `[patch]` `DeveloperFloor`'s test method still read "FortySix" for forty-seven tools (verification-gap, other) -- renamed `TestTheToolsTheDeveloperHoldsAreTheDeclaredRoster`.
  - `[low]` `[patch]` `ReadTool`'s roster message left out the tool search (verification-gap, other) -- added "the tool search".
  - `[false]` `[reject]` The Anthropic requests are checked on the recorded body, not against the API, and `claude-haiku-4-5` got no scoped call (intent-alignment) -- CI is stub-based by the owner's rule; Task 0 (f) ran a scoped turn on `claude-haiku-5-5`, `gpt-5.6-terra` and `gemini-3.8-flash`; the Tool search page lists Claude Haiku 4.5 among the models that take `defer_loading` and says a custom tool's `tool_result` may return `tool_reference` blocks.
  - `[false]` `[reject]` No Anthropic model fails to hold the full roster and no compatible server was measured (intent-alignment) -- Task 0 (d) is a measurement, not a defect: Haiku 4.5 needs 142,571 tokens against 200,000, and the compatible family is "unmeasured" as the spec allows.
  - `[high]` `[defer]` Gemini refuses five tools' declarations, so a Gemini turn works until it finds one of them (intent-alignment) -- the same root cause as the Gemini row above; one `deferred:` entry.
  - `[low]` `[patch]` `TestEveryBuiltScreensStartingSetFitsTheLimit` would pass on an empty starting set (intent-alignment) -- added an assertion that the largest set names tools.
  - `[false]` `[reject]` A listing without the discovery tool is sent whole, which is the original call (intent-alignment) -- the Design Notes choose it so no tool becomes unreachable, and `TestARegistryWithoutTheSearchIsSentWhole` pins it.
  - `[false]` `[reject]` `ToolsFind` reads `ListTools` again per search while `Advertise` read it at the turn's start (intent-alignment) -- both read the per-process cache (AD-5), which changes only on a recompile, and `Found` references only names in the turn's own array.
  - `[false]` `[reject]` Dispatch and governance (intent-alignment) -- the auditor reports no divergence: `Registry.cls`, `Dispatch.cls` and `Api/Error.cls` are untouched.

## Design Notes

**Families** (2026-10-12). Anthropic: a `defer_loading` tool is sent but kept out of context, no beta header, on all five catalog models; a custom tool may answer `tool_reference` blocks, which "the API expands"; `cache_control` on a deferred tool, an all-deferred array or a reference to an absent tool is a 400; an unreferenced deferred tool is outside the thinking-block check. OpenAI defers only on its Responses API; the others never.

**Choices.** One discovery tool, not Anthropic's server search: all four families, no new response block, a step card and ledger row per search (AD-33, AD-41); Anthropic's array never grows (`tool_set_changed`). The starting set is the `shell` area plus the context's `tools`, derived on the instance (AD-24). A listing without `shell.tools.find` is sent whole, so nothing becomes unreachable. It declares no pair: it answers only what the whole array gave every caller. The search reads `ListTools`' per-process cache as any tool does; only rows in the turn's one array are used. Results become canonical `tool_reference` blocks (AD-42).

**Governing ADs:** AD-5, AD-8, AD-11, AD-22 (a read: no key), AD-24, AD-31, AD-35, AD-41, AD-42, AD-53, AD-60. **Rule 31:** `ToolsFind` follows `Navigate`; `ContextTools` extends `ContextRoute`; one `Carried`; no second cache. **Rule 11:** Epic 20's diff names no file here at plan; `Loop.cls` is on its list, so implement re-checks and stops if it appears. No Fixed string, no client change. **Consumes:** 20.24, 18.39, 18.12, 4.7. **Consumed-by:** 18.40, 18.41 (`Anthropic.cls`). **Ledger inbox:** empty.

**For the lead** (Rule 20; applied at the spec gate, 2026-10-12):

- AD-8 (the owner's answer): "The full tool set is always advertised, save ..." becomes "The full tool set is always reachable within a turn, save ...: a call carries the turn's starting set, every other advertised tool reached through the discovery tool (AD-24) (owner, 2026-10-12: 'every other tool is reachable in the same turn after a search')."
- AD-24, 18.39's paragraph: "The tool array is the listing's whole set (AD-5, AD-8), built once per turn and byte-identical on every call" becomes "The tool set is chosen after the listing, taken once per turn, never inside it (AD-5): a turn starts with the shell area's tools, `shell.tools.find` among them, and the screen context's `tools`. Anthropic gets the whole set, byte-identical within the turn, the rest `defer_loading`, a found tool arriving as a `tool_reference`; other families get the starting set plus, from the next call, each found tool (their cache restarting at the tools (inference)), rendering a `tool_reference` as text. A listing without the discovery tool is sent whole." "its last tool" becomes "its last non-deferred tool".
- AD-22: "while the tool stays advertised" becomes "while the tool stays reachable". AD-53: the discovery tool never finds an unadvertised tool. AD-60: a `tool_reference` block, a wire name with no instance data, passes unchanged.
- No vendor defect candidate.
- Task 0, measured on `ocupilot-ci` 2026-10-12 (keys `ANTHROPIC_API_KEY`, `OPENAI_API_KEY` and `GEMINI_API_KEY` from `.env.local`, read at the point of use, on probe definitions made and removed; `OLLAMA_BASE_URL` and `OLLAMA_MODEL` read only to test reachability). Every Anthropic inference call used `claude-haiku-5-5`; the Models API reads and the full-request `count_tokens` on the other catalog models are checks about each model's fit, named for (d). Beside 18.39's `claude-opus-5-5` figures (368 advertised tools, tools array 525,414 characters, one call 190,745 tokens), the roster is now 371 advertised tools (370 before `shell.tools.find`): descriptions 113,283 and schemas 389,885 characters, the tools array 529,523 and the first request 533,420 characters.
- (a) Anthropic windows by the Models API, `max_input_tokens` and `max_tokens`: `claude-opus-5-5`, `claude-opus-5`, `claude-sonnet-5`, `claude-fable-5-1` and `claude-haiku-5-5` 1,000,000 and 128,000; `claude-haiku-4-5` 200,000 and 64,000. `count_tokens` on `claude-haiku-5-5`: the full first request 192,172 tokens, the scoped one 4,644, the largest starting set's 11,135.
- (b) Gemini (`gemini-3.8-flash`, `gemini-3.5-flash`, `gemini-2.5-pro`): `inputTokenLimit` 1,048,576 and `outputTokenLimit` 65,536 each. `countTokens` refused the full request on every model with 400 (five declarations with integer `enum` members, `deferred:`), so no full figure exists; scoped 3,270 and largest set 7,634 tokens on `gemini-3.8-flash` and `gemini-3.5-flash`; `gemini-2.5-pro` answered 404 "no longer available to new users".
- (c) OpenAI, documented (`developers.openai.com/api/docs/models/<id>`, read 2026-10-12): `gpt-5.6-terra`, `gpt-5.6-sol` and `gpt-5.6-luna` each a 1,050,000 context window, 922,000 maximum input and 128,000 maximum output tokens; the pricing page's long-context threshold is 272K input tokens.
- (d) Full request plus 32,000 `max_tokens` against the window, by `count_tokens` on each model: `claude-opus-5-5` 192,172 (224,172), `claude-fable-5-1` 192,172, `claude-opus-5` 192,170, `claude-sonnet-5` 192,238, `claude-haiku-5-5` 192,172, all in 1,000,000; `claude-haiku-4-5` 142,571 (174,571) in 200,000. **No Anthropic model fails to hold it**, `claude-haiku-4-5` included, against the plan's expectation: its tokenizer counts 26 percent fewer tokens. OpenAI and Gemini hold it by their documented limits (full OpenAI tokens unmeasured; Gemini's request is refused first). Local compatible servers: unmeasured, the owner's server did not answer. The scoped sets fit every window measured: 2,990 to 4,644 tokens first call, 11,135 at most.
- (e) Characters, request body and tools array, full against scoped (no screen context) against the largest starting set (`tasks/schedule`, 16 tools): OpenAI dialect 544,169 and 540,245; 12,688 and 8,764; 30,788 and 26,864. Gemini dialect 521,956 and 518,019; 12,435 and 8,498; 29,875 and 25,938. Anthropic sends every tool, 366 of them deferred in the scoped shape: 533,420 and 529,523; 541,106 and 537,209; 540,875 and 536,978, of which only the starting set counts toward the context, 192,172, 4,644 and 11,135 tokens. Two scoped first calls on `claude-haiku-5-5` (`max_tokens` 1), six seconds apart, both 200: call 1 `input_tokens` 1,293, `cache_creation_input_tokens` 3,351, `cache_read_input_tokens` 0; call 2 1,293, 0 and 3,351. The cached prefix is the 3,351 tokens up to the marker on the last starting tool.
- (f) One live scoped turn per family through the production loop and port (user message: search "permissions users read", call the tool found with `maxRows` 1), each completed with call 1 the search and call 2 `permissions_users_read`, 371 tools, 5 starting, 8 found after call 1, every call answered with a reply and no fault (the port reports HTTP status 0 on success): `claude-haiku-5-5` 4,644, 7,964 and 8,337 request tokens (3,351 of call 2 read from the cache); `gpt-5.6-terra` 2,990, 4,599 and 4,779; `gemini-3.8-flash` 3,270, 5,518 and 5,718. Compatible: unmeasured (no server).
- Not in the plan: the five Gemini declarations above make every Gemini request that carries the whole roster fail today, so a scoped turn is the first that works until it finds one of the five (`deferred:`). `ToolDefAdapter.GeminiEmptyEnumArgs` also reads `Carried`, so a found tool's respelled empty `enum` is decoded.

## Verification

**Shared surfaces:** a turn's provider `tools` (`TurnStream`, `ToolWire`), prompt statement 5 (`ScreenGrounding`), the tool roster and counts (`ReadTool`, `DeveloperFloor`, `InteropFloor`, `InteropFloorOwnPairs`, `ToolRoundTrip`).

**Standing criterion:** every test added or changed passes on a fresh environment, in either order.

**Commands** (each inside one 10-minute foreground call):

- `(loop)` `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/carry-2026-10-08/epic-18-d8/load-ocupilot-ci.sh` -- expected `LOAD-OK` and `STARTPATH-OK`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one at a time, totals from `%UnitTest_Result`: tasks 10-16's classes, `TurnStream`, and each class task 17 edits or runs.
- `(loop)` `uv run scripts/check-objectscript.py`; `bash scripts/lint-docs.sh`. No client tier.
- Full ObjectScript sweep: the runner's; browser suite: CI's.

- mutation: `ToolsFind.View` skips the `IsAdvertised` check -> `ToolsFind` (the unadvertised test) went red (run 704).
- mutation: `ToolsFind.View` ranks by name alone, not score -> `ToolsFind` (the ranking test) went red (run 705).
- mutation: `ToolsFind.View` reports `rowsAvailable` as the rows named -> `ToolsFind` (the ranking and limit tests) went red (run 706).
- mutation: `ToolsFind.View` searches an empty word list -> `ToolsFind` (the refusal test) went red (run 707).
- mutation: `Loop.Scope` marks every tool `start` -> `TurnScope` (the search, screen and starting-set-size tests, run 708) and `TurnScopeFamilies` (all three, run 709) went red.
- mutation: `Loop.ContextTools` reads no names -> `TurnScope` (the screen test) went red (run 710).
- mutation: `Loop.Scope` skips the discovery-tool check -> `TurnScope` (the whole-registry test) went red (run 711).
- mutation: `Anthropic.MarkedTool` answers the last tool -> `TurnScope` (the search test, run 712) and `AdapterScope` (the scoped request, run 713) went red.
- mutation: `ToolDefAdapter.Carried` answers every index -> `TurnScope` (the starting-set-size test, run 714), `TurnScopeFamilies` (all three, run 715) and `AdapterScope` (the dialects test, run 716) went red.
- mutation: `Loop.Found` numbers no tool -> `TurnScopeFamilies` (all three) went red (run 717).
- mutation: `Anthropic.CallMessages` reads `found` as `start` -> `AdapterScope` (run 718) and `TurnScope` (the search test, run 719) went red.
- mutation: `MessageAdapter.ResultText` reads every array as JSON -> `AdapterScope` (the reference test, run 720) and `TurnScopeFamilies` (all three, run 721) went red.
- mutation: `Sanitize.IsToolReferences` answers 1 for any non-empty array -> `Sanitize` (the reference test) went red (run 722).
- mutation: `Loop.Found` keeps the search's text as its content -> `ToolWire` (the integration test, run 723) and `TurnScope` (the search test, run 724) went red.
- mutation: `Prompt.BUILTIN` carries the old statement 5 -> `ScreenGrounding` (the statements test) went red (run 725).
- mutation: `Registry.ResolveWire` resolves an unadvertised tool -> `TurnScope` (the unadvertised test) went red (run 726).
- mutation: `ToolsFind.Score` drops the description branch -> `ToolsFind` (the description-alone test) went red (run 760).
- mutation: `Loop.Found` numbers from 0 on every search -> `TurnScopeFamilies` (the second-search test) went red (run 761).
Each applied on `ocupilot-ci` to a copy of the class, the class and every descendant recompiled, then restored; the worktree was not written.

**S0:** the new tests leave no probe definition, turn or stub node.

## Auto Run Result

Status: done
Blocking condition: none

**Summary.** Option A: a turn starts with the shell's tools and the screen context's `tools`, and `shell.tools.find` reaches the rest in the same turn. Anthropic gets the whole listing, byte-identical for the turn, the rest `defer_loading`, the cache marker on the last non-deferred tool and a found tool arriving as a `tool_reference`; OpenAI, Gemini and compatible servers get the starting set, then each found tool in the order found, the reference reading as the names found. A listing without the discovery tool is sent whole. Task 0 figures are under Design Notes: the full first request is 192,172 tokens on `claude-haiku-5-5`, the scoped one 4,644, the largest starting set 11,135.

**Files.** `Screen/Tool/ToolsFind.cls` (new, the search); `Kernel/Agent/Loop.cls` (`ContextTools`, `Scope`, `Found`, `AnswerTools` takes the array); `Kernel/Provider/Anthropic.cls` (deferral, marker); `ToolDefAdapter.cls` (`Carried`); `MessageAdapter.cls` (`ResultText`); `Sanitize.cls` (references pass); `Prompt.cls` (statement 5); `Base.cls` (doc). Tests: `ToolsFind`, `TurnScope`, `TurnScopeFamilies`, `AdapterScope`, `AdapterCacheCase` (setup `AdapterCache` and `AdapterScope` share), the `ScopeTool` fixtures, one method each in `Sanitize` and `ToolWire`, `TurnStream`, `TurnToolsCase`, `ScreenGrounding` and the roster classes `ReadTool`, `DeveloperFloor`, `InteropFloor`, `InteropFloorOwnPairs`, `ToolRoundTrip`.

**Review.** 12 findings: 5 patched (2 medium, 3 low), 1 root cause deferred (Gemini, `deferred:`), 5 rejected `false` with reasons in the log. Follow-up review recommended: `false` -- the two medium patches added tests only, each shown red under its mutation and green after.

**Verification.** `LOAD-OK` and `STARTPATH-OK`; 29 classes green on `ocupilot-ci` (runs 727-755, totals read from `%UnitTest_Result`), then `ToolsFind` 8 (758), `TurnScopeFamilies` 4 (762), `TurnScope` 5 (763), `DeveloperFloor` 10 (764), `ReadTool` 28 (765) after the review patches; `check-objectscript` 0 problems, `lint-docs` 0 issues; 18 mutations observed red. `ocupilot-ci` reads S0.

**Residual risks.** Gemini 400 on five declarations (deferred, high, pre-existing). The compatible family and a window-limited model are unmeasured, and no Anthropic model of the catalog fails to hold the full request, so the saving is measured in tokens and speed, not in a model made runnable. The port records HTTP status 0 on success, so Task 0 (f) shows each live turn's replies, not a literal 200.
