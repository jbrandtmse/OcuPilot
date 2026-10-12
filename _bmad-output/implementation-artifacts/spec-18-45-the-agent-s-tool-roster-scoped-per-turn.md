---
title: 'Story 18.45: The agent''s tool roster scoped per turn'
type: 'feature'
created: '2026-10-12'
status: 'ready-for-dev'
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

Under `src/OcuPilot/` at `0b5ef14df1dd1aaea66ea47b26ab0eb081bd6c1a`.

- `Kernel/Agent/Loop.cls`: `ContextRoute` :65; `Run` :143 (`Advertise` :221-226, `Invoke` :245); `AnswerTools` :503 (dispatch :623, step content :646, `Spend` :656, `Sanitize.Results` :661).
- `Kernel/Agent/Dispatch.cls` (not edited): `Advertise` :92 stays the whole listing; `Capped` :792 cuts `rows` whole.
- `Screen/Tool/Registry.cls` (read-only): `ListTools` :114, `WireName` :310, `IsAdvertised` :337, `ProviderTools` :354, `DescriptionOf` :498.
- `Api/Turn.cls` `BoundedContext` :534 sets the payload's `tools` (:543-545).
- Shell tools: `Kernel/Shell/*Read`, `Screen/Tool/Navigate.cls` (seam :62); `Kernel/Agent/Sanitize.cls` `Results` :38; `Prompt.cls` `BUILTIN` :21.
- `Kernel/Provider/Anthropic.cls` `CallMessages` :71 (tail :95-101, tools :103-114); `ToolDefAdapter.ToOpenAi` :72, `ToGemini` :99; `MessageAdapter.ResultText` :665; `Base.cls` :163 (`pTools`).
- Harnesses: `TurnToolsCase`, `ToolDispatchProbe.SetRegistryClass`; other families: `AnthropicThinking` :198-214; turn job: `TurnProvider`, `ToolWire` :124, `TurnStream` :410-433.

## Tasks & Acceptance

**Task 0** [ ] (`ocupilot-ci`, after `LOAD-OK` and `STARTPATH-OK`; keys from `/Users/jbrandt/git/OcuPilot/.env.local` read at the point of use, never printed, logged, ledgered or committed, on a probe definition created and removed; halt on a contradiction). Under "For the lead": (a) each Anthropic catalog model's `max_input_tokens`, and `count_tokens` of the full and the scoped first request (else a `max_tokens` 1 call's usage, on `claude-haiku-5-5` only); (b) Gemini's `inputTokenLimit` and `countTokens` likewise; (c) OpenAI's documented windows; (d) each model that cannot hold the full request plus 32,000 `max_tokens`, named (Haiku 4.5 and local compatible servers expected; no key or server: "unmeasured"); (e) the scoped first call's and the largest starting set's characters and tokens against the full call's, and an Anthropic second call's `cache_read_input_tokens`; (f) one live scoped turn per family with a key: call 1 searches, call 2 calls the found tool, each 200. Every live Anthropic call, (e)'s cache read included, uses `claude-haiku-5-5` (owner, 2026-10-12); another Anthropic model only for a check about that model, named with the reason. Record Haiku 5.5's figures beside 18.39's Opus ones, naming the model of each.

**Execution:**

1. [ ] `Screen/Tool/ToolsFind.cls` (new, extends `Screen/Tool/Base` as `Navigate` does) -- `shell.tools.find`, read, no pairs, no secret arguments; input `query` (string, required, at most 200), `limit` (integer 1 to 20, default 8). Over `RegistryClass()`'s `ListTools` (a seam), every advertised tool but itself: a query word (lower case, alphanumeric runs of 2+, first 10) scores 2 when the canonical name contains it, else 1 when `DescriptionOf` does; 0 dropped; by score, then name; answers `{query, rows: [{name: wire name, description}], rowsAvailable, truncated}`. No word: `TOOL.ARGUMENTS`. Description: "Search the tools you were not given at the start of this turn by what they do; a tool found can be called from your next step."
2. [ ] `Kernel/Agent/Loop.cls` -- (a) `ContextTools(pContextJson)`, sibling of `ContextRoute`: the payload's `tools`. (b) `Scope(ByRef pTools, pContextJson)`, once after `Advertise`: when the array holds the discovery tool, sets `pTools("scoped")` 1 and `pTools(n, "start")` 1 for each `shell_` wire name and each `ContextTools` name; else leaves it whole. (c) `AnswerTools` gains a trailing optional `ByRef pTools`: after `Spend`, a non-error discovery result on a scoped array gets `content` = one `{"type":"tool_reference","tool_name":<wire>}` per row in the array (an absent tool is a 400) and not `start`, in row order, each such tool given the next `pTools(n, "found")` once; with none, the content stays. (d) Header.
3. [ ] `Kernel/Provider/Base.cls` -- `pTools` doc: `scoped`, `start`, `found`; absent means the whole array.
4. [ ] `Kernel/Provider/Anthropic.cls` -- scoped: every tool sent, `defer_loading: true` without `start`, `cache_control` on the last `start` tool, never on a deferred one; unscoped unchanged.
5. [ ] `Kernel/Provider/ToolDefAdapter.cls` -- `Carried(ByRef pTools)`: every index unscoped; scoped, `start` in array order then `found` by number. `ToOpenAi` and `ToGemini` iterate it.
6. [ ] `Kernel/Provider/MessageAdapter.cls` -- `ResultText`: content of `tool_reference` blocks only reads `Found tools you can call from your next step: <names, comma-separated>.`
7. [ ] `Kernel/Agent/Sanitize.cls` -- `Results`: a non-empty array of blocks each exactly `{type: tool_reference, tool_name}` matching `^[a-zA-Z0-9_-]{1,64}$` passes unchanged; anything else as today.
8. [ ] `Kernel/Agent/Prompt.cls` -- statement 5, in place: "Your tools start with the shell's and this screen's; shell_tools_find finds any other tool by what it does, callable from your next step. Use only the tools you are offered or find, and when a search finds none that can do what was asked, say so rather than describe a capability you lack."

**Tests** (under 500 lines each; `mutation:` lines when observed):

9. [ ] Fixtures `Test/ScopeTool/`: `Registry` (extends `DispatchTool.Registry`, package `OcuPilot.Test.ScopeTool.`), `Find` (extends `ToolsFind` on it), `Reader` (`probe.found.read`), `Shell` (`shell.probe.read`), the last two extending `DispatchTool.Counter`.
10. [ ] `Test/ToolsFind.cls`: "permissions users read" ranks `permissions_users_read` first; never itself or an unadvertised tool; `limit`, `rowsAvailable`; no word refused; no match `rows` []. mutation: no `IsAdvertised` check.
11. [ ] `Test/TurnScope.cls` (`TurnToolsCase`, `ScopeTool`): (a, C1, C3) call 1 searches "found", call 2 calls `probe_found_read`, call 3 ends: the same `tools` text each call, only it deferred, the marker on the last non-deferred tool; call 2 carries its `tool_reference`; dispatched once, step ok. mutation: `Scope` marks all `start`. (b) a context naming it sends it undeferred. (c) `DispatchTool`, with no discovery tool, sends every tool undeferred, marker last. mutation: no discovery check. (d, C2) every built screen's starting set, as `ToOpenAi` carries it, is at most 65,536 characters; the largest recorded. mutation: `Carried` answers every index.
12. [ ] `Test/TurnScopeFamilies.cls` (openai, gemini, compatible, as `AnthropicThinking` reaches them): call 1 carries the starting set only, call 2 adds `probe_found_read` after it, the tool message names it, dispatched once. mutation: no `found` set.
13. [ ] `Test/AdapterScope.cls` (driven as `AdapterCache` is): tasks 4-6; unscoped unchanged. mutations: the marker on a deferred last tool; old `ResultText`.
14. [ ] `Test/Sanitize.cls`, one method: task 7's pass, idempotent; a bad name, an extra member or a mixed array framed. mutation: pass any array.
15. [ ] `Test/ToolWire.cls`, one method (Integration): call 1 searches "permissions users read", call 2 calls `permissions_users_read` `{maxRows: 5}`: the same `tools` text each call with it deferred, call 2's `tool_result` its `tool_reference`, both steps ok. mutation: no (c) replacement.
16. [ ] `Test/ScreenGrounding.cls`: `Statement` 5 is task 8's. mutation: the old text.
17. [ ] **Rule 30 sweep.** Rosters: `ReadTool` :94-95 (374, names), `DeveloperFloor.TOOLS` and its count message, `InteropFloor.BASETOOLS`, `InteropFloorOwnPairs.FLOORONLY` (`tool:shell.tools.find=no classic resource`), `ToolRoundTrip.REFUSEEMPTY` (`shell.tools.find:TOOL.ARGUMENTS`), `TurnStream` :425 (last non-deferred tool). Grep `src/OcuPilot/Test` for `shell.screen.open`, `"tools")`, `MarkOf(`, `373` and the old statement 5; run each class changed plus `AnthropicThinking`, `TurnTools`, `TurnBudget`, `AdapterCache`, `Adapter`, `LedgerWire`, `TurnNavigate`, `ToolSetFull`, `RegistryCache`, `InteropFloorTurn`, `DeveloperFloorTurn`, editing only if red.

**Acceptance Criteria** (epics.md, Story 18.45):

- **C1.** Given the registry's whole listing, cached per process (20.24), when a turn assembles a provider call, then the call carries a scoped tool set chosen after the listing and never inside it.
- **C2.** Given a supported family or model whose window cannot hold the full roster, when Task 0 measures each, then each is named and the scoped set fits it.
- **C3.** Given an advertised tool outside the starting set, when the agent needs it in the turn, then it reaches it by the mechanism the owner accepts, and dispatch answers it exactly as today.
- **Integration.** Given `ocupilot-ci` and the `turnprobe` row, when a turn through the turn job searches and then calls the found tool, then both answer and the requests carry task 4's array and the `tool_reference`.

## Spec Change Log

- 2026-10-12, lead, spec gate: A built as planned; AD-8 (with the owner's choice quoted), AD-24, AD-22, AD-53 and AD-60 amended as proposed. Owner, relayed the same morning: every live Anthropic check uses `claude-haiku-5-5` (Task 0 (a), (e), (f)). Rule 11: the `ReadTool` :94 count and `DeveloperFloor`'s count message need the orchestrator's pre-authorization as unions; the other roster edits are add-only.
- 2026-10-12, owner (relayed by the Planner and the orchestrator, feature 3b01d9dd): "A: screen + search (Recommended)" -- the whole answer. As the owner saw it: "Current screen's tools, the general tools and a tool search; every other tool is reachable in the same turn after a search. One extra call when it reaches outside; works with every model, including local ones." Build A as this plan framed it.

## Review Triage Log

## Design Notes

**Families** (2026-10-12). Anthropic: a `defer_loading` tool is sent but kept out of context, no beta header, on all five catalog models; a custom tool may answer `tool_reference` blocks, which "the API expands"; `cache_control` on a deferred tool, an all-deferred array or a reference to an absent tool is a 400; an unreferenced deferred tool is outside the thinking-block check. OpenAI defers only on its Responses API; the others never.

**Choices.** One discovery tool, not Anthropic's server search: all four families, no new response block, a step card and ledger row per search (AD-33, AD-41); Anthropic's array never grows (`tool_set_changed`). The starting set is the `shell` area plus the context's `tools`, derived on the instance (AD-24). A listing without `shell.tools.find` is sent whole, so nothing becomes unreachable. It declares no pair: it answers only what the whole array gave every caller. The search reads `ListTools`' per-process cache as any tool does; only rows in the turn's one array are used. Results become canonical `tool_reference` blocks (AD-42).

**Governing ADs:** AD-5, AD-8, AD-11, AD-22 (a read: no key), AD-24, AD-31, AD-35, AD-41, AD-42, AD-53, AD-60. **Rule 31:** `ToolsFind` follows `Navigate`; `ContextTools` extends `ContextRoute`; one `Carried`; no second cache. **Rule 11:** Epic 20's diff names no file here at plan; `Loop.cls` is on its list, so implement re-checks and stops if it appears. No Fixed string, no client change. **Consumes:** 20.24, 18.39, 18.12, 4.7. **Consumed-by:** 18.40, 18.41 (`Anthropic.cls`). **Ledger inbox:** empty.

**For the lead** (Rule 20; applied at the spec gate, 2026-10-12):

- AD-8 (the owner's answer): "The full tool set is always advertised, save ..." becomes "The full tool set is always reachable within a turn, save ...: a call carries the turn's starting set, every other advertised tool reached through the discovery tool (AD-24) (owner, 2026-10-12: 'every other tool is reachable in the same turn after a search')."
- AD-24, 18.39's paragraph: "The tool array is the listing's whole set (AD-5, AD-8), built once per turn and byte-identical on every call" becomes "The tool set is chosen after the listing, taken once per turn, never inside it (AD-5): a turn starts with the shell area's tools, `shell.tools.find` among them, and the screen context's `tools`. Anthropic gets the whole set, byte-identical within the turn, the rest `defer_loading`, a found tool arriving as a `tool_reference`; other families get the starting set plus, from the next call, each found tool (their cache restarting at the tools (inference)), rendering a `tool_reference` as text. A listing without the discovery tool is sent whole." "its last tool" becomes "its last non-deferred tool".
- AD-22: "while the tool stays advertised" becomes "while the tool stays reachable". AD-53: the discovery tool never finds an unadvertised tool. AD-60: a `tool_reference` block, a wire name with no instance data, passes unchanged.
- No vendor defect candidate.

## Verification

**Shared surfaces:** a turn's provider `tools` (`TurnStream`, `ToolWire`), prompt statement 5 (`ScreenGrounding`), the tool roster and counts (`ReadTool`, `DeveloperFloor`, `InteropFloor`, `InteropFloorOwnPairs`, `ToolRoundTrip`).

**Standing criterion:** every test added or changed passes on a fresh environment, in either order.

**Commands** (each inside one 10-minute foreground call):

- `(loop)` `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/carry-2026-10-08/epic-18-d8/load-ocupilot-ci.sh` -- expected `LOAD-OK` and `STARTPATH-OK`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one at a time, totals from `%UnitTest_Result`: tasks 10-16's classes, `TurnStream`, and each class task 17 edits or runs.
- `(loop)` `uv run scripts/check-objectscript.py`; `bash scripts/lint-docs.sh`. No client tier.
- Full ObjectScript sweep: the runner's; browser suite: CI's.

**S0:** the new tests leave no probe definition, turn or stub node.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Re-planned on answer A. No call to `ocupilot-ci` or `ocupilot`, no live provider call.
