---
title: 'Story 18.39: The agent''s context budget'
type: 'feature'
created: '2026-10-11'
status: 'done'
baseline_revision: '6846375c3cb35e2a870391ce1821ce62b3b8609c'
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

**Task 0** [x] (`ocupilot-ci`, after `LOAD-OK` and `STARTPATH-OK`; halt on a contradiction). Record: (a) the advertised count (registered less AD-53's three), and the characters of the serialized `tools` array, the built-in prompt and each request of a scripted three-call `turnprobe` turn; (b) that the `tools` JSON is identical across those calls and a second turn, in name order -- halt if not, since no cache could hit; (c) with the owner's Anthropic key (`/Users/jbrandt/git/OcuPilot/.env.local`, read at the point of use, never printed, logged, ledgered or committed; on a probe definition created and removed on `ocupilot-ci`), two one-call turns seconds apart: each call's `input_tokens`, `cache_creation_input_tokens`, `cache_read_input_tokens` and latency -- halt if the second's cache read is 0. With no key, record "unmeasured". The figures go into the AD-24 amendment.

**Execution:**

1. [x] `Kernel/Agent/Limits.cls` -- add `Parameter TURNRESULTMAXLENGTH As %Integer = 262144;`: characters one turn's tool results carry together; a reply's share is the lesser of `TOOLRESULTMAXLENGTH` and what remains; screen context is bounded separately (AD-24).
2. [x] `Kernel/Agent/Loop.cls` -- `Run` keeps the turn's remaining budget (from `TURNRESULTMAXLENGTH`) and passes it to `AnswerTools` as a new trailing optional ByRef `pTurnBudget` (`""` means none, so the Ledger probes' direct calls are unchanged). `AnswerTools` starts `tBudget` at the lesser of the two and lowers `pTurnBudget` wherever it lowers `tBudget` (floor 0). The class header says history within a turn is append-only.
3. [x] `Kernel/Provider/Anthropic.cls` -- `CallMessages`: the last tool gains `cache_control` `{"type":"ephemeral"}`; when the final message's content is a block array, its last block gains it; nothing else is marked and `system` stays a string. `MapResponse`: `RequestTokens` is `input_tokens` plus `cache_creation_input_tokens` plus `cache_read_input_tokens`. Doc comments state the contract: the prefix (tools, system, messages) never changes; the markers move.
4. [x] `Kernel/Agent/Prompt.cls` -- append to `BUILTIN`: "When a tool answers TOOL.RESULTTOOLARGE, this turn can carry no more tool results: answer from the results you already have, or ask the user to narrow the request." Update the header's closing clause.

**Tests** (classes under 500 lines):

5. [x] `Test/TurnLimitsBudget.cls` (new, extends `TurnLimitsNav`): `MAXITERATIONS` 4, `MAXTOKENS` 500000, `TOOLRESULTMAXLENGTH` 6000, `TURNRESULTMAXLENGTH` 9000.
6. [x] `Test/TurnBudget.cls` (new; in process and live-safe, as `TurnTools`). (a) On the shipped limits, a two-call turn with no screen context whose usages carry cache fields: call 1's body marks the last tool only; call 2's marks the last tool and the final message's last block, two markers in all; `tools` equal across calls; `system` a string; the turn row's `InputTokens` sums every input field. (b) On `TurnLimitsBudget`, four calls answering `probe.counter.read` with `rows` and `width` sized so reply 1 fits, reply 2 is cut (`truncated`, fewer rows) and reply 3 is `TOOL.RESULTTOOLARGE`, not dispatched (the probe's dispatch count unchanged); call 4 re-sends every message of call 3 identical once `cache_control` members are removed.
7. [x] `Test/AdapterCache.cls` (new; Anthropic through `ProviderStub` as `Provider` drives it, the others through the shipped adapters as `OpenAIAdapter`, `GeminiAdapter` and `CompatibleAdapter` do): the Anthropic body's markers; no `cache_control` in the OpenAI, Gemini or compatible body; matrix row 5 per family through `MapResponse`.
8. [x] `Test/Adapter.cls` -- `CANONICALBODY` gains the two markers, in place.
9. [x] `Test/SseFixture.cls` (add-only) -- `Anthropic` copies the scripted body's `cache_creation_input_tokens` and `cache_read_input_tokens` into `message_start`'s usage when present.
10. [x] `Test/TurnStream.cls` -- one method (Integration): a streamed two-call turn through the turn job, the scripted usages carrying cache fields; `TurnProvider.Recorded` shows matrix rows 1-2's markers and equal `tools`; the turn row's `InputTokens` is all three input fields summed over both calls. One header clause added.
11. [x] `Test/ScreenGrounding.cls` -- `Statement` 10 is Task 4's sentence; the test checks 1 to 10.
12. [x] **Rule 30 sweep.** Grep `src/OcuPilot/Test` for exact Anthropic body or `tools` JSON, `cache_control`, `input_tokens`, the prompt's sentences and `AnswerTools` callers; update an old-shape assertion in place. Run, editing only if red: `Adapter`, `Provider`, `ProviderStream`, `ProviderStreamFamilies`, `TurnLoop`, `TurnTools`, `TurnSanitize`, `TurnNavigate`, `TurnCitations`, `AnthropicThinking`, `Governance`, `Sanitize`, `Ledger`, `LedgerStep`, `LedgerSense`, `LedgerClientRows`, `ToolDispatch` (Epic 20's file: run only), `TurnContext`, `TurnConversation`, `TurnGrounding`, `AgentConnection`, `AgentConnectionBound`.

**Rework 1 (orchestrator ruling (A), 2026-10-12; AD-31 as corrected):**

R1. [x] Task 0 (d), `ocupilot-ci`: with the owner's OpenAI and Gemini keys from `.env.local` where present (read at the point of use, never printed, logged, ledgered or committed; on a probe definition created and removed), two calls seconds apart per family on the catalog's default model: record whether the response reports the cached subset separately (`usage.prompt_tokens_details.cached_tokens`, `usageMetadata.cachedContentTokenCount`) and its value on the second call; an absent key records "unmeasured" and the documented field stands. Read each family's cached-input rate for that model from the vendor's pricing page; record the rate, the URL and the read date under Design Notes "For the lead".
R2. [x] `Kernel/Provider/Response.cls`: a non-persistent `BoundTokens` property, the request tokens with the cached part at its billed weight, rounded up to a whole token. Each family's `MapResponse` sets it: Anthropic `input_tokens` + `cache_creation_input_tokens` + 0.1 x `cache_read_input_tokens` (writes stay at full weight; the ruling names reads); OpenAI and Gemini `prompt_tokens` (`promptTokenCount`) less the cached subset plus the rate x the subset, where R1 confirmed the field, else the whole count; compatible the whole count. Each rate is a parameter on its adapter class whose doc line names the source. An absent field counts 0.
R3. [x] `Kernel/Agent/Loop.cls`: `Boundary`'s token figure sums `BoundTokens` (the whole count when empty) and the response tokens; `RequestTokens`, the turn row's `InputTokens` and the ledger's `requestTokens` keep the provider's whole count. No schema change.
R4. [x] Tests, each with a `mutation:` line: `AdapterCache` (or a sibling under 500 lines) pins `BoundTokens` per family from a stubbed usage block (Anthropic 10, 200, 3000 gives 510; OpenAI and Gemini at their parameter; compatible the whole count; a missing cached field the whole count); `TurnBudget` pins C5 on a limits class where three scripted cached Anthropic calls pass `MAXTOKENS` at full weight but not at billed weight, and the turn row still records the whole count.

**Acceptance Criteria:**

- **C1 (cache).** Given an Anthropic definition, when a turn makes its first and a later provider call, then each request carries matrix rows 1-2's markers and no other, over the same `tools` array.
- **C2 (other families).** Given an OpenAI, Gemini or compatible definition, when a turn calls its provider, then the body carries no caching field and reads as before.
- **C3 (turn budget).** Given a turn whose tool results pass `TURNRESULTMAXLENGTH`, when later replies are answered, then matrix row 4 holds and every earlier message is re-sent unchanged but for the moved tail marker.
- **C4 (tokens).** Given replies reporting cached usage, when the turn counts its spend, then the turn row's `InputTokens` and the ledger's request tokens include cache writes and reads as matrix row 5 states.
- **C5 (bound, Rework 1).** Given replies reporting cached prompt tokens, when `Boundary` checks the turn's spend against `MAXTOKENS`, then Anthropic's cache reads count at 0.1, OpenAI's and Gemini's separately reported cached subsets at their recorded rate, and any other count at full weight.
- **Integration.** Given `ocupilot-ci` and the `turnprobe` row, when a streamed two-call turn runs through the turn job, then the recorded requests carry C1's markers and the turn row counts cached tokens (C4).

### Review Findings

Code review 2026-10-12 over `356bdf63..HEAD` (`review_tier: full-opus`; blind-hunter, edge-case-hunter, verification-gap and acceptance-auditor). 29 layer rows, 23 entries: high 0, medium 2, low 19, false 2. Patched 5, deferred 1, rejected 17.

- [x] [Review][Patch] (medium; fix-risk low; in-story; clear) C5's output half had no pinning test: every scripted reply reported 3 output tokens, so `Loop.Run` passing `tBound` alone changed no leg. The billed-weight test gains a fourth leg whose second reply reports 80 (3,203 against 3,200) [src/OcuPilot/Test/TurnBudget.cls:446]
- [x] [Review][Patch] (medium, Rule 30; fix-risk low; in-story harness; clear) `TurnBudget` and `TurnTools` relied on the instance's kill switch, read-only switch and holds being off. `TurnLoopProbe.ForceRestraintClear`, beside its force switches, is set by `TurnToolsCase.OnBeforeOneTest`, and `RunTurn`'s snapshot follows it. With both switches on, both classes stayed green (runs 769, 770); without the call, `TurnBudget` went 7 of 8 red (run 771) [src/OcuPilot/Test/TurnToolsCase.cls:40]
- [x] [Review][Patch] (low; fix-risk low; in-story; clear) The shared harness left each turn's ledger rows behind (`Turn.GuardedDelete` does not cascade to them). `TurnToolsCase.OnAfterOneTest` now deletes and counts them per turn key; the billed-weight test's own delete goes (run 775 added no orphan row) [src/OcuPilot/Test/TurnToolsCase.cls:57]
- [x] [Review][Patch] (low; fix-risk low; in-story; clear) Four doc comments said the bound counts a cached part "at the weight the provider bills it", which cache writes (billed 1.25, counted 1), compatible and the 0.05-rate models contradict; reworded to what the code counts [src/OcuPilot/Kernel/Agent/Limits.cls:19]
- [x] [Review][Patch] (low; fix-risk low; in-story; clear) `Anthropic`'s class header said the request "marks two places"; a first call without screen context marks one. Now "at most two", as `CallMessages` says [src/OcuPilot/Kernel/Provider/Anthropic.cls:13]
- [x] [Review][Defer] (low; fix-risk low; out-of-footprint) `TurnToolsCase`'s name carries no `TestCase`, so `testClassesOnDisk` leaves `TurnTools` (on the floor before) and `TurnBudget` off the on-disk floor; CI legs still run the instance's list [ui/tools/ci-runner.mjs:381] -- deferred: DW-2259, routed to 23-7, occurrence appended

Rejected:

- [low] The `TOOL.RESULTTOOLARGE` sentence says the turn can carry no more results, also when a reply's budget or one unboundable result raised it: Task 4's text, pinned verbatim; by-design.
- [low] The step card's reason for a budget refusal reads as though a result existed: the Fixed string is the reply-budget refusal's, and the spec forbids changing one; by-design.
- [low] Once the turn budget is spent, a navigation or proposal call is refused too: AD-24 as amended refuses any call under 256; by-design.
- [low] A screen-context turn answered in one call pays the cache-write premium on its tail: matrix row 1 marks it; by-design.
- [low] OpenAI's and Gemini's flat 0.1 under-counts an off-catalog model with a higher cached rate: R2 sets one rate per adapter, and every suggested model bills 0.1; by-design.
- [low] A model that keeps calling tools after the budget is spent wastes calls: the prompt tells it to stop, and the iteration, wall-clock and token bounds end the turn; wontfix-theoretical, real only for a model that ignores the refusal sentence.
- [low] A reply of ten or more tool calls can move the tail past Anthropic's lookback: the tool breakpoint, about 99% of each prompt (Task 0), is unaffected, and a third breakpoint is new surface.
- [low] The counted figure behind `TURN.LIMIT.TOKENS` is recorded nowhere: R3 names what the records keep, and a cached turn reaches the bound only after about 25 calls.
- [low] `AdapterCache`'s C4 and C5 methods overlap: each pins its own AC with its own recorded mutations.
- [low] The 256 floor is a literal in `Loop` while `Limits` documents it: the literal predates the story, and the doc describes the behavior.
- [low] Refused results and the sanitizer's frame are not taken off the budget: the budget is under 256 by then, and the frame lies outside AD-24's content bound by AD-60's design.
- [low] Rule 2: `TurnBudget.Sent` repeats `AnthropicThinking.Sent`, and `TurnBudget.Used` resembles `TurnStream.Cached`: one- to four-line helpers, and sharing them would couple unrelated test classes (Rule 31).
- [low] The triage log's line saying `TurnLimits` pins the output half is wrong: a spec edit; the fourth leg above now pins it.
- [low] The Auto Run Result names `TurnLimitsBilled` (no tests) as missing from `ci-timings.json`, where `TurnBudget` and `AdapterCache` are: a spec edit; untimed classes weigh at the median until the merge-gate refresh.
- [low] AD-41 still says "total provider tokens", and AD-31's "billed weight" leaves cache writes (billed 1.25, counted 1) unsaid: spine wording, for the lead (Rule 20).
- [false] No streamed Anthropic test of the weighted figure: `TurnStream`'s armed integration test pins the cache fields through the stream, and the weighted figure is computed from those fields in the same `MapResponse`.
- [false] The weight parameter has two names and `Base` declares neither: `Response.WeightedTokens` is the one computation, `PromptBound` already counts a family that sets nothing as whole, and Anthropic's parameter weights a different field.

## Spec Change Log

- 2026-10-12, lead, spec gate (orchestrator rulings): cache reads count at full weight against the 500,000-token turn limit; "trims history" is read as an entry budget, tier 1, because editing an earlier tool result in place breaks the echoed thinking blocks (a 400 on current models) and restarts every family's cache, and Anthropic's context-editing beta is the sanctioned route if earlier results are ever to be cleared; the turn budget is 262,144 characters with each reply's share capped at 65,536. AD-24 and AD-31 amended.

- 2026-10-12, orchestrator ruling (A) on Task 0's figures, superseding full weight: the token bound counts cached prompt tokens at their billed weight (Rework 1, C5); `MAXTOKENS` stays 500,000; AD-31 corrected. Making each call smaller is Story 18.45, split from this story (Rule 5).

## Review Triage Log

### 2026-10-12 -- Review pass

- verdicts: 14 findings -- high 0, medium 1, low 11, false 2, maybe-false 0
- findings:
  - `[medium]` `[patch]` The turn budget's size is pinned only from above: seeding it from `TOOLRESULTMAXLENGTH` leaves `TurnBudget` (b) green -- patched: a retained-length assertion on reply 2 in `TurnBudget` (b), with the `Loop.Run` mis-seed mutation recorded under Verification.
  - `[low]` `[reject]` The client-fulfilled branch's `Spend` call is unpinned for the turn budget -- both branches call the one helper, a navigation directive is a few hundred characters against 262,144, and a pin needs a client call on narrowed limits (more than a direct correction).
  - `[low]` `[reject]` The Gemini leg of the other-families test has no mutation of its own -- Rule 19 asks one demonstrated mutation per AC, and C2's `ToOpenAi` mutation reddened the OpenAI and compatible legs.
  - `[low]` `[reject]` The "read as before" legs of the other families have no mutation line -- they belong to C4, whose recorded mutation reddened `AdapterCache`; one per AC.
  - `[low]` `[reject]` The `cache_creation_input_tokens` term of the sum has no mutation line -- one per AC; the 210, 3200 and 3230 cases pin the term.
  - `[low]` `[reject]` "Tools identical across calls" has no mutation line -- the assertions are non-vacuous (the array is asserted non-empty first) and C1's mutations are the AC's; one per AC.
  - `[low]` `[reject]` The 262,144 literal in `TurnBudget` (a) has no mutation line -- a source-constant pin; the spec lets the gate set another number, and changing it is a deliberate edit of both.
  - `[low]` `[reject]` The new prompt sentence says the turn can carry no more results, while `TOOL.RESULTTOOLARGE` also answers one result too large for its reply budget -- the sentence is Task 4's text, pinned verbatim by `ScreenGrounding`; its second clause (ask the user to narrow the request) fits both cases, and the fix is a spec edit.
  - `[low]` `[reject]` Row 3, "body as today": the system prompt every family sends grew by one sentence (3,288 to 3,452 characters) -- Task 4 puts it in the shared prompt because the turn budget and its refusal apply to every family; the contract's row pins no caching field in their bodies, which `AdapterCache` asserts.
  - `[low]` `[reject]` Row 4 is exercised on narrowed limits, the shipped limits only by the parameter's value -- the same code runs on both, and a 262,144-character turn needs four results of 65,536 characters.
  - `[false]` `[reject]` Row 5: no test drives the `MAXTOKENS` boundary with cache fields -- `TurnBudget`'s billed-weight test drives the boundary, its fourth leg on the output half, and `TurnBudget` (a) and `TurnStream` pin the input sum that feeds it.
  - `[low]` `[reject]` The shipped 368-tool array appears only in the armed `TurnStream` test and Task 0 -- the Integration AC is that test by design, and Task 0 measured the shipped array identical across calls, a second turn and processes.
  - `[low]` `[reject]` Live evidence covers the tool marker only, never the moving tail marker against the real provider -- Task 0 (c) is scoped to two one-call turns; closed by QA's live two-call turn (Design Notes).
  - `[false]` `[reject]` Out-of-matrix additions: the `TurnToolsCase` extraction, and AD-24's spine text still awaiting Task 0's figures -- the extraction follows the `StreamCase` precedent and keeps `TurnTools` green (run 672); the spine amendment is the lead's (Rule 20).

### 2026-10-12 -- Review pass (Rework 1)

- verdicts: 8 findings -- high 0, medium 1, low 7, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` A streamed OpenAI or Gemini reply's cached subset reaching `BoundTokens` has no test, and the streamed form is the production path -- patched: `ProviderStreamFamilies.TestAStreamedReplyKeepsItsCachedSubset` (plain and streamed legs for openai, gemini and compatible), with a `StreamAdapter` usage-pruning mutation recorded per family under Verification.
  - `[low]` `[reject]` `Anthropic.CACHEREADWEIGHT`'s doc line cites the vendor page's per-model cache-read rates with no record in the spec -- the page was read directly on 2026-10-12 and the line matches it; the spec's fix would be an edit to this build's spec, and the rates reach the lead under Auto Run Result.
  - `[low]` `[patch]` `Limits.MAXTOKENS` still read "input plus output" -- corrected to the billed-weight wording.
  - `[low]` `[reject]` The shipped `MAXTOKENS` of 500,000 is not driven with cached usage at real scale -- the same code runs on the narrowed 3,200, and a 500,000-token turn needs about sixteen 190,000-token calls.
  - `[low]` `[reject]` OpenAI, Gemini and compatible are not scripted through the loop -- `PromptBound` is family-agnostic and pinned directly, and each adapter's figure is pinned at the mapping and the stream level.
  - `[low]` `[reject]` R1's live measurement was non-streamed and tool-free while production streams the tool array -- the Design Notes label the stream's wire form an inference, and the new streamed test pins the pass-through of the shape the vendors document.
  - `[low]` `[reject]` Anthropic's flat 0.1 over-counts Opus 5.5 and Sonnet 5.5 (billed 0.05) and Fable 5.1 (0.025) -- the ruling names 0.1 and the over-count is the safe side; for the lead's AD-31.
  - `[low]` `[reject]` Design Notes still carry the full-weight "at most three provider calls" line and the first AD-31 proposal -- the Change Log records ruling (A), the spec is `oversized`, and those lines are the lead's.

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

- Task 0, measured on `ocupilot-ci` 2026-10-12 (AD-24 carries these figures). Advertised: 368 tools, the 371 registered less AD-53's three (`explorer.sqldata.save`, `osmgmt.licensekey.activate`, `security.secrets.replacesymmetric`). The `tools` array is 525,377 characters before this story and 525,414 after (the marker, 37), of which descriptions 112,090 and input schemas 387,162; the built-in prompt is 3,288 characters before and 3,452 after. A scripted three-call turn sends 528,815, 529,120 and 529,425 characters before and 529,016, 529,358 and 529,663 after. The `tools` JSON is the same text across those calls, across a second turn and across separate processes, in name order. Live (the owner's Anthropic key, `claude-opus-5-5`, two one-call turns six seconds apart, streamed, markers on the last tool only because no screen context): call 1 `input_tokens` 1,118, `cache_creation_input_tokens` 189,627, `cache_read_input_tokens` 0, 7.00 s in the transport (8.13 s the whole turn); call 2 1,118, 0 and 189,627, 2.07 s (2.51 s). Each call is 190,745 tokens whichever side of the cache it falls, and the turn row records 190,745 for both. Under Rework 1's billed weight a cached Anthropic call counts about 20,100 tokens against `MAXTOKENS` (inference: 1,118 + 0.1 x 189,627). The tools array is 99.4 percent of each call's prompt, so the cost of a turn is the tools array, not history or results. The key was read from `.env.local` once, for these two turns.
- Live tail marker, measured on `ocupilot-ci` 2026-10-12 (QA): a two-call turn (the owner's Anthropic key, `claude-opus-5-5`, the 368-tool registry, call 1 answering `shell_instance_read`) sent the moving marker on the call that carries the `tool_result` (two `cache_control` members in that request) and was answered HTTP 200 with `cache_read_input_tokens` 189,627 and `cache_creation_input_tokens` 1,345; the turn completed and its `InputTokens` read 381,730 over the two calls.
- R1, measured on `ocupilot-ci` 2026-10-12 (the owner's OpenAI and Gemini keys, read once each from `.env.local`; one non-streamed two-call attempt per family through the shipped port and adapter, an 89,438-character prompt, six seconds apart, no tools). OpenAI `gpt-5.6-terra` reports `usage.prompt_tokens_details.cached_tokens` separately, inside `prompt_tokens`: call 1 `prompt_tokens` 20,887, `cached_tokens` 0, `cache_write_tokens` 20,884; call 2 20,887, 20,884 and 0. Gemini `gemini-3.8-flash` omits `usageMetadata.cachedContentTokenCount` on call 1 and reports 22,721 inside `promptTokenCount` 24,769 on call 2. Rates, read 2026-10-12: OpenAI cached input $0.20 against input $2.00 per 1M tokens, cache writes $2.50, short context (long context $0.40 against $4.00), `https://developers.openai.com/api/docs/pricing.md`; Gemini context caching $0.075 against input $0.75 through 2026-12-31 and $0.15 against $1.50 from 2027-01-01, `https://ai.google.dev/gemini-api/docs/pricing`. Every cached rate is 0.1 of its input rate. `StreamAdapter` keeps the streamed `usage` and `usageMetadata` objects whole, so a streamed body carries the same fields (inference: the wire form of the stream's last chunk was not measured). Cache writes bill at 1.25 times input on Anthropic and OpenAI and count at full weight here.
- Declined: per-call tool selection (Story 18.45); in-place trimming (above); Anthropic's context-editing beta (`context-management-2025-06-27`), the sanctioned in-place route if earlier results are ever to be cleared.
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

- mutation: `Anthropic.CallMessages` marks no tool -> `TurnBudget` (the markers test and the context-turn test), `AdapterCache` (the marks test) and `TurnStream` (the integration test) went red.
- mutation: `Anthropic.CallMessages` marks no message tail -> `TurnBudget` (all three tests), `AdapterCache` (the marks test) and `TurnStream` (the integration test) went red.
- mutation: `ToolDefAdapter.ToOpenAi` marks its last declaration -> `AdapterCache` (the other-families test) went red on the OpenAI and compatible legs.
- mutation: `Loop.AnswerTools` ignores `pTurnBudget` -> `TurnBudget` (the budget test) went red on the cut, the refusal, the dispatch count and the error step.
- mutation: `Loop.AnswerTools` re-runs `Sanitize.Results` over every earlier user message -> `TurnBudget` (the budget test) went red on the unchanged-message leg for calls 3 and 4.
- mutation: `Anthropic.MapResponse` without `cache_read_input_tokens` -> `TurnBudget` (the markers test), `AdapterCache` (the token test) and `TurnStream` (the integration test) went red.
- mutation: `Prompt.BUILTIN` without the `TOOL.RESULTTOOLARGE` sentence -> `ScreenGrounding` (the statements test) went red.
- mutation: `Loop.Run` seeds the turn budget from `TOOLRESULTMAXLENGTH` -> `TurnBudget` (the budget test) went red on the retained-length assertion alone (run 683; green after the restore, run 684).
- mutation: `Loop.AnswerTools` refuses under 255, not 256 -> `TurnBudget` (the floor test) went red on the 255 leg (QA, run 698).
- mutation: `Loop.AnswerTools` starts the reply budget at the turn's remainder alone -> `TurnBudget` (the floor test) went red on the cap leg (QA, run 690).
- mutation: `Loop.Spend` leaves the reply budget unlowered -> `TurnBudget` (the exact-edge test) went red on the second call of one reply (QA, run 691).
- mutation: `Loop.AnswerTools` without the empty-budget guard -> `TurnBudget` (the no-budget test) went red on all three legs (QA, run 692).
- mutation: `ToolDefAdapter.ToGemini` marks its last declaration -> `AdapterCache` (the other-families test) went red on the Gemini leg alone (QA, run 693).
- mutation: `Anthropic.CallMessages` marks every tool -> `AdapterCache` (the marks test) and `TurnBudget` (the markers and context tests) went red (QA, runs 694 and 695).
- mutation: `Anthropic.CallMessages` marks the last block of every message -> `AdapterCache` (the marks test) and `TurnBudget` (the markers, context and budget tests) went red (QA, runs 696 and 697).
- mutation: `Anthropic.MapResponse` weights cache reads at 1 -> `AdapterCache` (the bound test) and `TurnBudget` (the billed-weight test) went red (Rework 1, runs 703 and 704).
- mutation: `Anthropic.MapResponse` leaves cache writes out of the bound -> `TurnBudget` (the billed-weight test, the second and third legs) and `AdapterCache` (the bound test) went red (runs 705 and 706).
- mutation: `Anthropic.CACHEREADWEIGHT` 0 -> `TurnBudget` (the billed-weight test, the second leg) and `AdapterCache` (the bound test) went red (runs 707 and 708); 0.5 -> the first leg (run 709).
- mutation: `Loop.Run` sums `RequestTokens` into the bound -> `TurnBudget` (the billed-weight test, the first leg) went red (run 710).
- mutation: `Loop.Run` records the bound as the turn row's input -> `TurnBudget` (the billed-weight test, the whole-count assertion, and the markers test) went red (run 711).
- mutation: `Loop.RecordProviderRow` records the bound as the ledger's request tokens -> `TurnBudget` (the billed-weight test, the ledger assertion) went red (run 712).
- mutation: `Loop.PromptBound` answers 0 for an empty figure -> `TurnBudget` (the fallback test) went red alone (run 713).
- mutation: `OpenAI.MapResponse` leaves out its weight -> `AdapterCache` (the bound test) went red on the OpenAI cached leg alone (run 714).
- mutation: `Compatible.CACHEDINPUTWEIGHT` removed, so it inherits OpenAI's 0.1 -> `AdapterCache` (the bound test) went red on the rates line and the compatible cached leg (run 715).
- mutation: `MessageAdapter.GeminiUsage` leaves out the cached count -> `AdapterCache` (the bound test) went red on the Gemini cached leg alone (run 716).
- mutation: `Response.WeightedTokens` rounds down -> `AdapterCache` (the bound test and the weighted-count test) went red on the fraction legs (run 717).
- mutation: `Response.WeightedTokens` leaves the cached part unclamped -> `AdapterCache` (the weighted-count test) went red on the clamp legs (run 718).
- mutation: `StreamAdapter.TakeOpenAi` keeps only the prompt and completion counts of the streamed usage -> `ProviderStreamFamilies` (the streamed cached-subset test) went red on the openai leg alone (run 761).
- mutation: `StreamAdapter.TakeGemini` keeps only the prompt and candidate counts of the streamed usage metadata -> `ProviderStreamFamilies` (the streamed cached-subset test) went red on the gemini leg alone (run 762).
- mutation: `Loop.Run` leaves the output tokens out of the bound (`tBound` alone at both sites) -> `TurnBudget` (the billed-weight test) went red on the fourth leg alone (code review, run 765; green after the restore, run 766).
Each applied on `ocupilot-ci` to a copy of the class, the class and every descendant recompiled, then restored; the worktree was not written.

**S0:** no probe definition, turn, conversation or stub node left by the new tests.

(QA) No new test file. `Test/TurnBudget.cls` gains three methods (the turn budget's edges at a direct `AnswerTools` call, on run 699 six methods green); `Test/TurnToolsCase.cls` gains `NewDefinition`, taken out of `RunTurn` (`TurnTools` 13 green, run 700).

## Auto Run Result

Status: done
Blocking condition: none

**Summary (Rework 1).** The turn's token bound now counts a cached prompt part at its billed weight: `Response.BoundTokens` (new, non-persistent) is set by each family's `MapResponse` (Anthropic reads at 0.1 and writes whole, OpenAI and Gemini cached subsets at 0.1, compatible whole), and `Loop.Run` feeds `Boundary` that figure plus the output; `RequestTokens`, the turn row's `InputTokens` and the ledger keep the whole count. R1: the OpenAI and Gemini fields and rates are in Design Notes.

**Files.**

- `Kernel/Provider/Response.cls`: `BoundTokens`, `WeightedTokens`. `Anthropic.cls`, `OpenAI.cls`, `Gemini.cls`, `Compatible.cls`: the weight parameters and their sources. `MessageAdapter.cls`: the OpenAI and Gemini readers take a trailing weight.
- `Kernel/Agent/Loop.cls`: `PromptBound`, the bound accumulator. `Limits.cls`: `MAXTOKENS` doc only.
- Tests: `AdapterCache` and `TurnBudget` gain two methods each; new `TurnLimitsBilled`; `ProviderStreamFamilies` gains the streamed cached-subset method.

**Review.** One pass, 8 findings: 2 patched (1 medium, 1 low), 6 low rejected with reasons in the triage log, none deferred. Follow-up review recommended: false.

**Verification.** On `ocupilot-ci` after a fresh load: `AdapterCache` 5 (734), `TurnBudget` 8 (757), `ProviderStreamFamilies` 5 (763), `Provider` 20, `Adapter` 25, `TurnLoop` 11, `Ledger` 11, `TurnStream` 7, `TurnTools` 13, `ScreenGrounding` 16, `OpenAIAdapter` 6, `GeminiAdapter` 4, `CompatibleAdapter` 6, `ProviderStream` 11, `AnthropicThinking` 4, `GeminiEmptyEnum` 6, `AgentConnection` 20, `AgentConnectionBound` 15, `AgentRules` 20, `AgentWire` 18 (runs 736-754), `LedgerWire` 6 (731), all green. `check-objectscript` 0 problems, `lint-docs` 0 issues. Each of this pass's 14 `mutation:` lines reddened its test and was restored; the lead's own spot check of the `Loop.Run` sum mutation reddened `TurnBudget` (run 756).

**Residual risks.** Anthropic's pricing page bills cache reads at 0.05 on Opus 5.5 and Sonnet 5.5 and 0.025 on Fable 5.1 and Mythos 5.1, and 0.1 is a deliberate upper bound (orchestrator, 2026-10-12: a flat weight errs conservative and needs no table that ages with each model release). `TurnBudget` and `AdapterCache` are not yet in `ci-timings.json`.
