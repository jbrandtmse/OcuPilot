---
title: 'Story 18.39: The agent''s context budget'
type: 'feature'
created: '2026-10-11'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Every provider call of a turn re-sends the whole advertised tool array (about 94 KB of descriptions over about 360 tools, plus their schemas) with no prompt caching, and a turn's own tool results accumulate with no turn-level bound, so each call is larger and slower and a long turn grows without limit.

**Approach:** Assemble each call within a budget, downstream of 20.24's listing: the Anthropic adapter marks the stable prefix for prompt caching while the other families keep sending what they send today; a turn's tool results share one turn budget that cuts and then refuses past it, with earlier history append-only; and Anthropic's cached tokens count toward AD-31's token spend.

## Boundaries & Constraints

**Always:** The tool array is `ProviderTools`' whole advertised set (AD-5, AD-8), built once per turn and byte-identical on every call. Within a turn no message already sent is changed, reordered or removed. Every cut is AD-24's marked cut (`Bound`); every result passes `Sanitize.Results` once (AD-60).

**Never:** A per-call tool selection or a second listing cache (AD-8, Rule 31). A request change for OpenAI, Gemini or compatible. Gemini's `cachedContents` or Anthropic's context-editing beta. A new error code, Fixed string, client change or schema change. Building on a `decision-pending` entry.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| First call (Anthropic) | a turn's first provider request | the last tool carries `"cache_control":{"type":"ephemeral"}`, and the final message's last block when that message is blocks (screen context); nothing else; `system` stays a string | -- |
| Later call (Anthropic) | a request after tool results | the last tool and the final message's last block carry the marker, nothing else; `tools`, and every earlier message less its moved marker, identical to the previous call | -- |
| Other families | an OpenAI, Gemini or compatible request | no `cache_control`; body as today | -- |
| Turn budget | results summing past `TURNRESULTMAXLENGTH` | a reply's budget is the lesser of `TOOLRESULTMAXLENGTH` and what the turn has left; a result past it is cut by whole rows, marked `truncated` | under 256 left: `TOOL.RESULTTOOLARGE`, not dispatched |
| Cached usage | Anthropic usage `input_tokens` 10, `cache_creation_input_tokens` 200, `cache_read_input_tokens` 3000 | `RequestTokens` 3210; OpenAI `prompt_tokens` and Gemini `promptTokenCount` read as before | an absent field counts 0 |

</intent-contract>

## Code Map

Under `src/OcuPilot/` at `266eee9d`. Epic 20's open diff touches none of these files (2026-10-11).

- `Kernel/Agent/Loop.cls`: `Run` :135 seeds history (`Convo.HistoryMessages` :163, `HISTORYMAXLENGTH`) and the context pair :175-205; `Advertise` once :212; `Invoke` per call :235; tokens :240-241 into `Boundary` :218, :388. `AnswerTools` :479: reasoning echo :484-507, reply budget `tBudget` :511, refusal under 256 :536, decrements :594, :632, `Sanitize.Results` on the new blocks only :638.
- `Kernel/Agent/Limits.cls`: `TOOLRESULTMAXLENGTH`, `HISTORYMAXLENGTH`, `MAXTOKENS`.
- `Kernel/Provider/Anthropic.cls`: `CallMessages` :54 (`system` :61, messages :63-78, tools :79-89); `MapResponse` usage :170-173. Streamed usage: `StreamAdapter.cls` merges `message_start` and `message_delta` usage key by key (:170, :205-211) into the body `MapResponse` reads (:246).
- Unchanged: `MessageAdapter.cls` OpenAI usage :280-282, `GeminiUsage` :492-497; the listing, `Screen/Tool/Registry.cls` `ListTools` :114 and `ProviderTools` :354.
- `Kernel/Agent/Prompt.cls`: `BUILTIN` :20 and its sentence-group header.
- Tests: `Test/TurnLoopProbe.cls` (`SetDispatchClass` :46, `SetLimitsClass` :53) over `ProviderPortProbe` and `ProviderStub`; `Test/ToolDispatchProbe.cls` with `DispatchTool/Counter.cls` (`rows`, `width`); `Test/TurnTools.cls` (`RunTurn` :77, `Reply` :111, budget tests :287-336); `Test/TurnLimits.cls` (`MAXTOKENS` 3) and `TurnLimitsNav.cls`; `Test/Adapter.cls` `CANONICALBODY` :838, pinned :805; `Test/Provider.cls` :120-121; `Test/SseFixture.cls` `Anthropic` :50 (usage :57-59); `Test/TurnProvider.cls` (`Script` :48, `Recorded` :150); `Test/TurnStream.cls` (armed); `Test/ScreenGrounding.cls` `Statement` :20 (1 to 9), test :48.

## Tasks & Acceptance

**Task 0** (`ocupilot-ci`, after `LOAD-OK` and `STARTPATH-OK`; halt on a contradiction). Record: (a) the advertised count (registered less AD-53's three), and the characters of the serialized `tools` array, the built-in prompt and each request of a scripted three-call `turnprobe` turn; (b) that the `tools` JSON is identical across those calls and a second turn, in name order -- halt if not, since no cache could hit; (c) with the owner's Anthropic key (`/Users/jbrandt/git/OcuPilot/.env.local`, read at the point of use, never printed, logged, ledgered or committed; on a probe definition created and removed on `ocupilot-ci`), two one-call turns seconds apart: each call's `input_tokens`, `cache_creation_input_tokens`, `cache_read_input_tokens` and latency -- halt if the second's cache read is 0. With no key, record "unmeasured". The figures go into the AD-24 amendment.

**Execution:**

1. `Kernel/Agent/Limits.cls` -- add `Parameter TURNRESULTMAXLENGTH As %Integer = 262144;`: characters one turn's tool results carry together; a reply's share is the lesser of `TOOLRESULTMAXLENGTH` and what remains; screen context is bounded separately (AD-24).
2. `Kernel/Agent/Loop.cls` -- `Run` keeps the turn's remaining budget (from `TURNRESULTMAXLENGTH`) and passes it to `AnswerTools` as a new trailing optional ByRef `pTurnBudget` (`""` means none, so the Ledger probes' direct calls are unchanged). `AnswerTools` starts `tBudget` at the lesser of the two and lowers `pTurnBudget` wherever it lowers `tBudget` (floor 0). The class header says history within a turn is append-only.
3. `Kernel/Provider/Anthropic.cls` -- `CallMessages`: the last tool gains `cache_control` `{"type":"ephemeral"}`; when the final message's content is a block array, its last block gains it; nothing else is marked and `system` stays a string. `MapResponse`: `RequestTokens` is `input_tokens` plus `cache_creation_input_tokens` plus `cache_read_input_tokens`. Doc comments state the contract: the prefix (tools, system, messages) never changes; the markers move.
4. `Kernel/Agent/Prompt.cls` -- append to `BUILTIN`: "When a tool answers TOOL.RESULTTOOLARGE, this turn can carry no more tool results: answer from the results you already have, or ask the user to narrow the request." Update the header's closing clause.

**Tests** (classes under 500 lines):

5. `Test/TurnLimitsBudget.cls` (new, extends `TurnLimitsNav`): `MAXITERATIONS` 4, `MAXTOKENS` 500000, `TOOLRESULTMAXLENGTH` 6000, `TURNRESULTMAXLENGTH` 9000.
6. `Test/TurnBudget.cls` (new; in process and live-safe, as `TurnTools`). (a) On the shipped limits, a two-call turn with no screen context whose usages carry cache fields: call 1's body marks the last tool only; call 2's marks the last tool and the final message's last block, two markers in all; `tools` equal across calls; `system` a string; the turn row's `InputTokens` sums every input field. (b) On `TurnLimitsBudget`, four calls answering `probe.counter.read` with `rows` and `width` sized so reply 1 fits, reply 2 is cut (`truncated`, fewer rows) and reply 3 is `TOOL.RESULTTOOLARGE`, not dispatched (the probe's dispatch count unchanged); call 4 re-sends every message of call 3 identical once `cache_control` members are removed.
7. `Test/AdapterCache.cls` (new; Anthropic through `ProviderStub` as `Provider` drives it, the others through the shipped adapters as `OpenAIAdapter`, `GeminiAdapter` and `CompatibleAdapter` do): the Anthropic body's markers; no `cache_control` in the OpenAI, Gemini or compatible body; matrix row 5 per family through `MapResponse`.
8. `Test/Adapter.cls` -- `CANONICALBODY` gains the two markers, in place.
9. `Test/SseFixture.cls` (add-only) -- `Anthropic` copies the scripted body's `cache_creation_input_tokens` and `cache_read_input_tokens` into `message_start`'s usage when present.
10. `Test/TurnStream.cls` -- one method (Integration): a streamed two-call turn through the turn job, the scripted usages carrying cache fields; `TurnProvider.Recorded` shows matrix rows 1-2's markers and equal `tools`; the turn row's `InputTokens` is all three input fields summed over both calls. One header clause added.
11. `Test/ScreenGrounding.cls` -- `Statement` 10 is Task 4's sentence; the test checks 1 to 10.
12. **Rule 30 sweep.** Grep `src/OcuPilot/Test` for exact Anthropic body or `tools` JSON, `cache_control`, `input_tokens`, the prompt's sentences and `AnswerTools` callers; update an old-shape assertion in place. Run, editing only if red: `Adapter`, `Provider`, `ProviderStream`, `ProviderStreamFamilies`, `TurnLoop`, `TurnTools`, `TurnSanitize`, `TurnNavigate`, `TurnCitations`, `AnthropicThinking`, `Governance`, `Sanitize`, `Ledger`, `LedgerStep`, `LedgerSense`, `LedgerClientRows`, `ToolDispatch` (Epic 20's file: run only), `TurnContext`, `TurnConversation`, `TurnGrounding`, `AgentConnection`, `AgentConnectionBound`.

**Acceptance Criteria:**

- **C1 (cache).** Given an Anthropic definition, when a turn makes its first and a later provider call, then each request carries matrix rows 1-2's markers and no other, over the same `tools` array.
- **C2 (other families).** Given an OpenAI, Gemini or compatible definition, when a turn calls its provider, then the body carries no caching field and reads as before.
- **C3 (turn budget).** Given a turn whose tool results pass `TURNRESULTMAXLENGTH`, when later replies are answered, then matrix row 4 holds and every earlier message is re-sent unchanged but for the moved tail marker.
- **C4 (tokens).** Given replies reporting cached usage, when the turn counts its spend, then the turn row's `InputTokens`, which AD-31's bound reads, includes cache writes and reads as matrix row 5 states.
- **Integration.** Given `ocupilot-ci` and the `turnprobe` row, when a streamed two-call turn runs through the turn job, then the recorded requests carry C1's markers and the turn row counts cached tokens (C4).

## Spec Change Log

- 2026-10-12, lead, spec gate (orchestrator rulings): cache reads count at full weight against the 500,000-token turn limit; "trims history" is read as an entry budget, tier 1, because editing an earlier tool result in place breaks the echoed thinking blocks (a 400 on current models) and restarts every family's cache, and Anthropic's context-editing beta is the sanctioned route if earlier results are ever to be cleared; the turn budget is 262,144 characters with each reply's share capped at 65,536. AD-24 and AD-31 amended.

## Review Triage Log

## Design Notes

**Families** (`Provider/Catalog.cls` rows; vendor docs and the `claude-api` skill, read 2026-10-11):

| Family | Caching | Request change | Usage |
|---|---|---|---|
| Anthropic | explicit `cache_control`, at most 4 breakpoints, minimum 512 to 4,096 tokens by model, 5-minute TTL refreshed on a hit | Task 3 | `input_tokens` excludes `cache_creation_input_tokens` and `cache_read_input_tokens`: add both |
| OpenAI | automatic for prefixes of 1,024 tokens or more, tools included | none; `prompt_cache_key` declined, since `Compatible` inherits `OpenAI.CallMessages` and a LiteLLM proxy can refuse it | `prompt_tokens_details.cached_tokens` within `prompt_tokens` (inference) |
| Gemini | implicit on 2.5 and later, 2,048 to 4,096 tokens | none; explicit `cachedContents` is a separate provider-side create | `cachedContentTokenCount` within `promptTokenCount` |
| Compatible | the server's own (vLLM, llama.cpp, Ollama) | none | a subset where reported |

**Append-only, not trim in place.** Anthropic's current models (Opus 5.5, the catalog default; Sonnet 5.5; Fable 5.1) bind each thinking block to the conversation before it: changing or deleting an earlier tool result invalidates every later one, a 400 for accounts created on or after 2026-08-31, and restarts every family's cache there (`claude-api` skill, `model-migration.md` Breaking change 3). The loop echoes reasoning blocks verbatim (`AnswerTools` :484-507), so the budget bounds what enters history with AD-24's cut. Earlier turns replay as text only (`HistoryMessages`), so their oldest-first trim is unaffected.

**Rule 31.** Extended: `AnswerTools`' DW-452 reply budget, `Bound`'s whole-row cut, `TurnLimitsNav`, `TurnTools`' `RunTurn` and `Reply` (lifted into `TurnFixture` if `TurnBudget` cannot reach them without inheriting `TurnTools`' tests), `Provider`'s and the family adapter tests' harnesses, `SseFixture`. No new `Kernel` class.

**Governing ADs:** AD-5, AD-7 (no new vendor write), AD-8, AD-11, AD-24, AD-31, AD-35 (Task 0's key), AD-41, AD-42, AD-60. AD-22: no key. **Integration ACs:** the Integration line. **Consumes:** 18.12 (the roster), 20.24 (`ListTools`), 4.5 (history), 11.7 (streaming), 10.4 (the reasoning echo). **Consumed-by:** 18.40 and 18.41, which rebase on this `Anthropic.cls`. **Ledger inbox:** empty.

**For the lead** (Rule 20):

- AD-24, proposed: "**A turn's request is assembled within a budget** (Story 18.39). Within a turn, history is append-only. This turn's tool results carry at most 262,144 characters together (`Limits.TURNRESULTMAXLENGTH`), each reply's share the lesser of 65,536 and what remains, cut by AD-24's mark and refused `TOOL.RESULTTOOLARGE` below 256. The tool array is the listing's whole set (AD-5, AD-8), identical on every call of a turn. The Anthropic adapter marks its last tool and the final message's last block `cache_control` ephemeral; OpenAI, Gemini and compatible servers cache by their own rules with no request change." The lead closes it with Task 0's advertised count, tool-array size and per-call tokens.
- AD-31, proposed: "Provider tokens count a prompt's whole size as the provider reports it: Anthropic's input tokens plus its cache writes and reads." Owner question, not built on: should cache reads count at full weight? Task 0's per-call tokens say how many calls a turn makes before 500,000.
- 262,144 is the plan's number; the gate may set another.
- Declined: per-call tool selection (it needs AD-8's "full tool set" restated, the owner's call); in-place trimming (above); Anthropic's context-editing beta (`context-management-2025-06-27`), the sanctioned in-place route if earlier results are ever to be cleared.
- Rule 11: no contended file. No vendor defect candidate.

## Verification

**Shared surfaces:** the Anthropic request body (`CANONICALBODY`, `TurnProvider`'s recorded `tools`), the built-in prompt's statements, the turn's token count (`InputTokens`, the ledger's `requestTokens`), `AnswerTools`' signature and budget, `SseFixture`'s streamed usage.

**Standing criterion:** every test added or changed passes on a fresh environment, in either order.

**Commands** (each inside one 10-minute foreground call):

- `(loop)` `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/carry-2026-10-08/epic-18-d8/load-ocupilot-ci.sh` -- expected `LOAD-OK` and `STARTPATH-OK`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one at a time, totals from `%UnitTest_Result`: `TurnBudget`, `AdapterCache`, `Adapter`, `ScreenGrounding`, `TurnStream` (35 s), and each class Task 12 edits or runs (sized from `ui/tools/ci-timings.json`).
- `(loop)` `uv run scripts/check-objectscript.py`; `bash scripts/lint-docs.sh`. No client file changes, so no client tier.
- Full ObjectScript sweep: the runner's; browser suite: CI's.

**Mutations (Rule 19),** each recorded as `mutation:` once observed, descendants recompiled: C1 no marker on the last tool, then none on the tail (`TurnBudget` a, `AdapterCache`); C2 a marker in `ToolDefAdapter.ToOpenAi` (`AdapterCache`); C3 `AnswerTools` ignoring `pTurnBudget` (`TurnBudget` b), and `Sanitize.Results` re-run over every earlier user message (`TurnBudget` b's unchanged leg); C4 `MapResponse` without `cache_read_input_tokens` (`TurnBudget` a, `AdapterCache`); Integration the same C4 mutation (`TurnStream`).

**S0:** no probe definition, turn, conversation or stub node left by the new tests.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
