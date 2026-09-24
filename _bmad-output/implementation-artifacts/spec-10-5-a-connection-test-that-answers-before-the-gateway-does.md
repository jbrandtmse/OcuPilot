---
title: 'Story 10.5: A connection test that answers before the gateway does'
type: 'bugfix'
created: '2026-09-23'
status: 'done'
baseline_revision: 'b11c1e5e6fc9de9767a9bb1ab19c25cccfe7ceb5'
review_loop_iteration: 0
followup_review_recommended: true
context: []
warnings: ['oversized']
deferred:
  - summary: >-
      Test connection's child-path max_tokens is pinned in the JOB argument, not on the recorded wire request.
    evidence: |-
      Test/TurnProvider.cls (not Epic 10's file) records no max_tokens, so a Child that dropped maxTokens alone would stay green; AgentConnection pins it in process only.
    location: >-
      src/OcuPilot/Test/TurnProvider.cls:115
    severity: low
---

<intent-contract>

## Intent

**Problem:** Test connection makes its provider call inside the HTTP request. A provider that has not answered (a cold local model, a slow cloud endpoint) holds the request past the Web Gateway's `Server_Response_Timeout`, so the operator gets the gateway's empty 504 instead of a reason. `%Net.HttpRequest.Timeout` re-arms on every socket read (AD-42, DW-1179), so no per-read timeout can bound the wait. Two Gemini defects ride along: every Gemini turn is refused because the navigate tool's route `enum` carries Home's empty route (DW-1600), and Test connection on `gemini-3.8-flash` answers an empty reply because its 32-token cap is spent on thinking (DW-1601).

**Approach:** Run Test connection's one provider call in a short-lived child job and wait for it on the request process with a wall-clock deadline: a bound computed from the gateway timeout the installer already reads. On expiry the request answers OcuPilot's own reason (a local wording or a provider wording) and records nothing verified. A late answer is discarded. The Gemini tool translation respells an empty `enum` member reversibly, and the test's token cap rises so a model that thinks before it answers still answers.

## Boundaries & Constraints

**Always:**

- The bound is a wall-clock bound on the whole test, enforced in the request process. It never relies on a per-read timeout.
- The child calls the same `ProviderPort.InvokeDraft` a test calls today (same TLS, egress judgement, adapter and key rules; AD-32, AD-42). It inherits the caller's `$USERNAME` and `$ROLES`, is spawned from no escalated frame (AD-9), and writes nothing. The verification write, the change record and the response stay in the request process.
- The key never becomes a named local in either process (AD-35, AD-48). A stored key is resolved by the child's own adapter. A body key crosses by `$System.Event` message, evaluated straight into its `%DynamicObject`. No key enters a `JOB` argument, a global, a log line or the event reply.
- The new copy is one Fixed-strings row carrying two literals, appended at the END of EXPERIENCE.md's table, two appended `strings.ts` keys, and two `Base` parameters, all pinned equal. Non-ASCII is written as `\uXXXX`. Colours come from tokens.
- CI stays stub-based. No test opens a socket to a provider or reads a real key.

**Never:**

- Change `Installer.cls`, the turn path (`Kernel/Agent/Loop`, `Dispatch`, `Api/Turn`), `Screen/Tool/Navigate.cls` or `Screen/Tool/Registry.cls`.
- Relax the cross-vendor schema subset, or drop the `enum` keyword or the empty member for one family (Story 10.1's AC keeps the rule verbatim).
- Send a per-model thinking parameter to Gemini.
- Retry, stream, or return a partial reply on the timeout path.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Answers in time | provider answers before the bound | unchanged 200 `{connected, reply, ...}`, verification recorded as today | No error expected |
| Not answered, not local | `markedLocal` 0, no answer by the bound | 504 envelope, code `PROVIDER.TESTTIMEOUT`, reason "The provider (<label>) did not answer within <n> seconds. Check the endpoint and the provider's status, then test again." resolved, `detail{waitedSeconds, providerLabel, keySource, testedAsStored}` | nothing marked verified; a not-as-stored test records its security change with `faultCode` as today |
| Not answered, local | `markedLocal` 1 | code `PROVIDER.TESTTIMEOUTLOCAL`, reason "The model did not answer within <n> seconds. A local model may still be loading; test again in a minute." | same |
| Per-read timeout first | the child's call faults `PROVIDER.TIMEOUT` before the bound | mapped to the same two codes, with `<n>` the seconds actually waited | same |
| Late answer | the child answers after the request gave up | discarded. The row stays unverified. The next test in that process reads its own result, never the stale one | nonce plus a queue clear before each spawn |
| Later passing test | a timed-out test is followed by a test that answers | 200, `connectionVerified` true, and `PUT enabled:true` is then accepted | No error expected |
| Bound arithmetic | gateway `g` read as 60, 20, 10, 300; unread, `""`, non-numeric, ≤ 0 | 50, 10, 5, 290; unread cases → g = 60 → 50 | a failed read is never an error |
| Spawn fails | `JOB` not accepted within its timeout | 502 `PROVIDER.TRANSPORT`, logged | no call made |
| Gemini tools | any registered tool whose property `enum` (or `items.enum`) holds `""` | the Gemini declaration carries `"(empty)"` in its place. No Gemini declaration carries an empty member. Other families unchanged | — |
| Gemini call back | `functionCall` args `{route:"(empty)"}` on a tool the request respelled | canonical `input.route` is `""`. Replayed history re-spells `""` to `"(empty)"` for the same (tool, argument) only | a string equal to `"(empty)"` on any other argument passes verbatim |

</intent-contract>

## Code Map

- `src/OcuPilot/Api/Definitions.cls` -- `:85` `TESTMAXTOKENS` 32, with the cost rationale in its doc. `:740-758` `HandleTest`'s doc says "thirty-two tokens, and a single attempt". `:846` `ConnectionOutcome`: `:874` sets the budget, `:887` calls `$ClassMethod(..PortClass(), "InvokeDraft", ...)` in-process, `:890` `AnnotateCallFault`, `:944` builds the answer. `:162` `CatalogClass()` and `:1051` `PortClass()` are the seam precedent. `GuardedVersion` (`State/Agent.cls:417`) unwinds its escalation before the call.
- `src/OcuPilot/Port/ProviderPort.cls:210` `InvokeDraft` (Authenticated, then the `OcuPilotAdmin:USE` gate, then `Dispatch`). `:249` `Dispatch` fills `endpointUrl`, `keyPrefix`, `authVersion` and `reasoningEffort` in place.
- `src/OcuPilot/Kernel/Provider/Base.cls` -- `:67` `REASONBUILTURLEGRESS` is the reason-parameter precedent. `HttpFor` (~`:584`) maps `PROVIDER.TIMEOUT` to 504. `ReasonFor` (~`:599`) is "the one home" of the PROVIDER sentences. `Invoke` reads `keySource` / `keyBody` / `keyField`.
- `src/OcuPilot/Install/Installer.cls:1667` `GatewayResponseTimeout(.pTimeout, .pSource)` reads the live registry first, then `csp/bin/CSP.ini` `[SYSTEM]`. It answers both `""` when neither answers and returns an error status only on a throw. Read-only probe on slot B from HSCUSTOM: 60, "live Gateway registry", 3 ms. The file read answers 60 in 0 ms. The registry needs `%Admin_Manage:USE` (`irislib/%CSP/Mgr/GatewayRegistry.cls:25`), so a caller without it falls through to the file (inference: `%File` reads carry no IRIS resource gate). Call it; never edit it.
- `src/OcuPilot/Kernel/Agent/Job.cls:1-60` -- the turn job's spawn: `Job ...:(tNamespace):SPAWNTIMEOUT`, then `$Test`, then an identity check in `Run`. Its class doc claims "the one place in shipped code that spawns a process".
- `src/OcuPilot/Kernel/Provider/ToolDefAdapter.cls` -- `GEMINIDROPPED` and `GeminiSchema` (copies `enum` by reference), `ToGemini`. `src/OcuPilot/Kernel/Provider/MessageAdapter.cls:299` `CanonicalToGemini` (`:336` writes `args`), `:396` `GeminiToCanonical` (`:444` reads `args`), `:543` `ArgumentsOf`. `src/OcuPilot/Kernel/Provider/Gemini.cls` `CallMessages` / `MapResponse` run on one adapter instance per call.
- `src/OcuPilot/Screen/Tool/Registry.cls:238` `ProviderTools(.pTools)` builds the whole advertised set; `tools[0].function_declarations[64]` is navigate. `Screen/Tool/Navigate.cls:100-102` builds `route.enum` from `BuiltRoutes()`, and `Screen/Descriptor/Home.cls:29` declares `"route": ""`.
- `src/OcuPilot/Kernel/Provider/Catalog.cls:79-87` -- the armed `turnprobe` row (`OCUPILOT_ALLOW_TEST_PROVIDER`), adapter `OcuPilot.Test.TurnProvider`. Its script lives in `^IRIS.Temp.OcuPilotTurnProvider(tag)` keyed by model, with a hang, a body and a status (0 = transport timeout). It records `keySha`, and it is the cross-process stub a child job reaches.
- `src/OcuPilot/Test/DefinitionsProbe.cls` -- the `Definitions` subclass every in-process `ConnectionOutcome` driver uses (`AgentConnection`, `AuditRecord`, `AuditVerbs`, `ConnectionKey`, `DefinitionsFaults`). Its port is `ProviderPortProbe`, whose stubs live in process-private globals that a child job cannot see. Not Epic 10's file: add this story's one member only.
- `src/OcuPilot/Test/TurnLong.cls` -- `TestATurnOutlivesTheGatewayResponseTimeout` already pins AC3 (a 70 s stub against a 60 s gateway; the mutation is documented in its doc). Its arming variables are `OCUPILOT_ALLOW_PRINCIPALS` and `OCUPILOT_ALLOW_TEST_PROVIDER`. `Test/TurnChain.cls:99` tests a stored key over the wire through Test connection on `turnprobe`.
- `scripts/ci-throwaway.sh:271-277` -- the `# classes:` roster for `OCUPILOT_ALLOW_TEST_PROVIDER`. `ui/tools/ci.test.mjs:1854` holds it equal to the classes that declare the variable.
- Client: `ui/src/app/areas/agent/definition-form.store.ts:981` `absorbTestRefusal`, which renders `reason` verbatim for every code but `PROVIDER.REFUSED` and `STATE.CONFLICT`. `definition-form.page.ts:669` `failureText`. `ui/src/app/core/strings.ts:521-530` holds the Definition-form keys and 10.4's three.
- EXPERIENCE.md: the Fixed-strings table's last row is `:465` (10.4). `ui/tools/strings.test.mjs` bounds the table at ≤ 700 literals, and it holds 698 today, measured with the test's own extractor. `ui/tools/self-protection.test.mjs:61` is the server-copy-equals-`strings.ts` pin precedent (AD-53). `ui/browser/definitions.browser-spec.mjs:563` is 10.4's case with `detectScreen`, and `browser/error-log.browser-spec.mjs:264` is the `setRequestInterception` precedent.

## Tasks & Acceptance

**Execution:**

1. `src/OcuPilot/Api/Error.cls` -- Append `PROVIDERTESTTIMEOUT = "PROVIDER.TESTTIMEOUT"` and `PROVIDERTESTTIMEOUTLOCAL = "PROVIDER.TESTTIMEOUTLOCAL"`, each with a doc. The only edits to existing text are "ten" → "twelve" at `:205` and `:1039`.
2. `src/OcuPilot/Kernel/Provider/Base.cls` -- Add `REASONTESTTIMEOUT` and `REASONTESTTIMEOUTLOCAL`: the two matrix sentences, unresolved, with `<provider>` and `<n>`. `ReasonFor` answers them for the two codes, and `HttpFor` answers 504 for both. The count in the doc becomes twelve.
3. `src/OcuPilot/Kernel/Provider/TestCall.cls` -- new. Parameters `UNREADGATEWAYSECONDS` 60, `MARGINSECONDS` 10, `SPAWNTIMEOUT` 5 and `KEYWAITSECONDS` 10. Methods:
   - `GatewayClass()` is the seam that answers `OcuPilot.Install.Installer`.
   - `GatewaySeconds(Output pSource)` answers a positive whole number, or 60 with source `unread`.
   - `BoundSeconds(pGateway)` is pure: `g - min(MARGIN, g\2)`, where `g` is 60 when not a positive number, and it answers at least 1.
   - `Call(pPortClass, ByRef pValues, ByRef pMessages, pBound, Output pResponse, Output pHttpStatus, Output pFault, Output pWaited, Output pTimedOut)`: clear this process's event queue, spawn `Child`, and wait for `$lb(nonce, "ready")`. When `keySource` is body, signal the child the key inline from `pValues("keyBody")`. Then wait for `$lb(nonce, "result", json)`, and rebuild the `Response` (`Text`, `StopReason`, `HttpStatus`, `LatencyMs`) plus the fault. Every wait draws on one deadline, and a message with any other nonce is discarded. At the deadline, answer with `pFault` empty and `pTimedOut` 1; `pWaited` is the whole seconds waited, rounded.
   - `Child(pParent, pNonce, pUser, pPortClass, pValuesJson, pNeedsKey)`: refuse when `$Username` is not `pUser`, clear its own queue, signal ready, and take the key when `pNeedsKey` (`Do tKeyBody.%Set(field, $ListGet($System.Event.WaitMsg("", KEYWAITSECONDS), 2))`). Call `InvokeDraft` and signal the result. It never throws and logs through `Kernel.Fault.LogRaw`.
   - `ValuesJson(ByRef pValues)` serializes the values and excludes `keyBody`.
   - `TimeoutFault(pMarkedLocal, pLabel, pSeconds, Output pFault, Output pHttpStatus)` resolves the placeholders.
   - The class doc states the caller contract (no escalated frame) and that a drip-feeding provider keeps its child alive until its own per-read timeout, one child per press.
4. `src/OcuPilot/Api/Definitions.cls` -- Add `TestCallClass()` (a seam, `OcuPilot.Kernel.Provider.TestCall`) and `TestBoundSeconds()` (a seam: `BoundSeconds(GatewaySeconds())`). `ConnectionOutcome` calls `TestCallClass().Call(..PortClass(), ...)` in place of `:887`. On `pTimedOut`, or on a fault coded `PROVIDER.TIMEOUT`, it replaces the fault with `TimeoutFault(pValues("markedLocal"), <the ..CatalogClass() row's label, else the provider key>, pWaited)`. Then comes the existing `AnnotateCallFault` and record logic, unchanged. `TESTMAXTOKENS` becomes 1024 (DW-1601), and its doc says it is a cap rather than a spend. Correct the `HandleTest` and header docs.
5. `src/OcuPilot/Kernel/Provider/ToolDefAdapter.cls` -- **DW-1600.**
   - Add `GEMINIEMPTYENUM = "(empty)"`. `GeminiSchema` writes a copy of any `enum` array with each `""` member replaced by it, and never mutates the shared array.
   - Add `GeminiEmptyEnumArgs(ByRef pTools) As %DynamicObject`, answering `{<wire name>: {<argument>: "value"|"items"}}` for top-level properties whose `enum` or `items.enum` holds `""`.
   - The class doc says the one value this translation respells, why, and that the respelling is reversible.
6. `src/OcuPilot/Kernel/Provider/MessageAdapter.cls` -- `GeminiToCanonical` and `CanonicalToGemini` gain a trailing `pEmptyEnums As %String = ""` (that map as JSON). On a mapped (tool, argument) only, the first decodes `"(empty)"` to `""` in `input` (per element for `items`), and the second encodes `""` to `"(empty)"` in a replayed `functionCall`'s `args`. Existing callers are unchanged.
7. `src/OcuPilot/Kernel/Provider/Gemini.cls` -- Add `Property EmptyEnumArgs As %String(MAXLEN = "")`. `CallMessages` sets it from `pTools` and passes it to `CanonicalToGemini`, and `MapResponse` passes it to `GeminiToCanonical`.
8. `src/OcuPilot/Kernel/Agent/Job.cls` -- One doc sentence: it is one of two spawn sites; the other is `Kernel.Provider.TestCall` (footprint extension).
9. `src/OcuPilot/Test/AgentConnectionInline.cls` -- new. It extends `TestCall`, and `Call` runs `InvokeDraft` in-process with `pWaited` 0. `src/OcuPilot/Test/DefinitionsProbe.cls` -- add the one member `TestCallClass()` answering it, so every existing in-process driver keeps its process-private stubs. Grep every `ConnectionOutcome` driver and confirm each goes through `DefinitionsProbe`.
10. `src/OcuPilot/Test/AgentConnectionProbe.cls` -- new. It extends `Definitions`, and `TestBoundSeconds()` answers a process-private switch. The port stays the real `ProviderPort`, so the child reaches the armed `turnprobe` row.
11. `src/OcuPilot/Test/AgentConnectionBound.cls` -- new. It declares `OCUPILOT_ALLOW_TEST_PROVIDER` and refuses when it is unarmed. Legs:
    - the bound arithmetic rows;
    - `GatewaySeconds` through a seam answering `""`, then 20;
    - bound 2 s against a `TurnProvider` hang of 6 s: the fault code, elapsed at least 2 and under 4 s, the reason resolved, the `detail` fields, and the row still unverified after the child's `returned` is recorded;
    - the local reason;
    - a script status 0 maps to `PROVIDER.TESTTIMEOUT`;
    - body key: the recorded `keySha` equals the SHA of the sent key, and `ValuesJson` holds no key;
    - stale message: call A times out (bound 1, hang 3), call B (hang 2) answers B's own reply;
    - a later fast test verifies the row.

    Tear down after each child's `returned` appears (at most 15 s). Copy `TurnLong`'s definition setup; do not extend it.
12. `src/OcuPilot/Test/AgentConnectionWire.cls` -- new, over HTTP as `_SYSTEM`, and it declares `OCUPILOT_ALLOW_TEST_PROVIDER`. With the stock gateway, assert `GatewayResponseTimeout` reads 60 first. A `turnprobe` definition whose hang is 70 s answers 504 with the `PROVIDER.TESTTIMEOUT` envelope after 45-58 s; the gateway would have cut it at 60. `GET` shows it unverified after the child returns. Then a 0 s script makes the test answer 200 and verified, and `PUT {"enabled":true}` answers 200.
13. `src/OcuPilot/Test/GeminiEmptyEnum.cls` -- new. Over `Registry.ProviderTools` → `ToGemini`: no declaration anywhere carries an empty `enum` member; each respelled enum keeps its member count; navigate's `route` holds `"(empty)"`; and no registered enum already holds `"(empty)"`. Decode and encode round trips, scoped (an unmapped argument keeps `"(empty)"`). Plus one leg through the Gemini adapter with a stub: the recorded body has no empty member.
14. `src/OcuPilot/Test/AgentConnection.cls` -- Add a DW-1601 leg: `TESTMAXTOKENS >= 256`, with a message citing 26 thinking tokens against a cap of 32. Adjust nothing else unless a pin reddens.
15. `scripts/ci-throwaway.sh` -- Append `AgentConnectionBound` and `AgentConnectionWire` to the `OCUPILOT_ALLOW_TEST_PROVIDER` `# classes:` roster, keeping the alphabetical wrap. This is a comment only (footprint extension).
16. EXPERIENCE.md -- Append ONE row after `:465` holding both sentences as two literals: `"The model did not answer within <n> seconds. A local model may still be loading; test again in a minute." · "The provider (<provider>) did not answer within <n> seconds. Check the endpoint and the provider's status, then test again."` The Where column reads: the Definition form's Test connection failure line when the test waited its bound with no answer (Story 10.5); the first when the definition is marked local, the second otherwise; `<n>` is the seconds waited and `<provider>` the catalog label. The table reaches 700 literals.
17. `ui/src/app/core/strings.ts` -- Append `agentDefinitionTestTimeoutLocal` and `agentDefinitionTestTimeout` after 10.4's keys (`:530`), each `/** EXPERIENCE.md:466 */`.
18. `ui/tools/connection-timeout.test.mjs` -- new. `Base.cls`'s two parameters equal the two `strings.ts` values byte for byte, and each carries `<n>`; the non-local one also carries `<provider>`.
19. `ui/src/app/areas/agent/definition-form.store.ts` -- In `absorbTestRefusal`, for the two codes with a numeric `detail.waitedSeconds`, `testFailure` is the `STRINGS` template with `<n>` and `<provider>` (from `detail.providerLabel`) resolved. Without the detail it falls back to `reason`. `definition-form.page.spec.ts` gets cases for both codes and for the fallback.
20. `ui/browser/definitions.browser-spec.mjs` -- One case that intercepts `POST …/test` and answers each code's 504 envelope. It asserts the failure line equals the resolved template, and runs `detectScreen` with every `INVARIANT` at 1280 and 720 px light and 1280 px dark, with no violations. Correct the header's "never pressed" sentence to say the press is intercepted.

- [x] 21. `scripts/check-objectscript.py` -- (lead, at the implement halt) `JOB_ALLOWED` gains `src/OcuPilot/Kernel/Provider/TestCall.cls` and rule 19's prose names it beside `Job.cls` (AD-42 as amended 2026-09-24). `scripts/` is not a contended path, so this is an Epic 10 footprint extension. Verified: `check-objectscript.py` 0 problems over 741 files; `test_check_objectscript.py` 128/128.
- [x] 22. `ui/src/app/areas/agent/definition-form.page.ts` -- correct `failureText`'s doc comment for the two new codes.
- [x] 23. AC3's mutation: apply `TurnLong`'s documented mutation (run `Job.Run` inline in `Api.Turn.HandleStart`) to observe red, then revert byte-identical. Applying and reverting a mutation is not an edit of `Api/Turn.cls`; the file must be byte-identical afterwards (`git diff --stat` unchanged). Record the observed run under Verification.

**Acceptance Criteria:**

- **AC1.** Given a provider that has not answered, when Test connection has waited its bound (the gateway's `Server_Response_Timeout` as `Installer.GatewayResponseTimeout` reads it, minus the margin, or 50 s when unread), then the request answers OcuPilot's envelope before the gateway would: the local reason for a definition marked local, and otherwise the provider's label and the seconds waited. Raising the gateway setting raises the bound.
- **AC2.** Given a test that timed out, when its result is stored, then `connectionVerified` is unchanged, even after the child answers late, and a later passing test verifies it so the definition can be enabled.
- **AC3.** Given a turn whose first provider call outlasts the gateway timeout, when it runs, then it completes, as `TurnLong.TestATurnOutlivesTheGatewayResponseTimeout` pins. No turn code changes.
- **AC4.** Given the two reasons, when they render, then they are rows in EXPERIENCE.md's Fixed strings and keys in `strings.ts`, pinned equal to the server's parameters.
- **Integration (Rule 1).** Given `Kernel.Provider.TestCall`, when `Api.Definitions.HandleTest` serves `POST /agent/definitions/:id/test` over HTTP, then a stuck provider yields the envelope within the bound (`AgentConnectionWire`), and a stored key still reaches the turn's provider call through the child (`TurnChain`).
- **DW-1600.** Given a Gemini definition, when a turn's request is built, then no function declaration carries an empty `enum` member, and a model's `"(empty)"` on navigate's `route` reaches dispatch as `""`.
- **DW-1601.** Given any definition, when Test connection calls it, then the request's cap is `TESTMAXTOKENS` (1024), so a model that thinks before it answers has room to answer. The live proof on `gemini-3.8-flash` is Story 17.7's owner check.

## Spec Change Log

- 2026-09-24, implement halt (lead): the halt's intent gap is answered by task 21 (the lead edited the checker's `JOB_ALLOWED`; `scripts/` is outside every other open epic's footprint). Tasks 22-23 carry the two items the halt left open. Status reset to `in-progress`; tasks 1-20 are in the working tree, uncommitted, and are this pass's to review and finalize.

## Review Triage Log

### 2026-09-24 — Review pass

- verdicts: 22 findings — high 0, medium 10, low 8, false 4, maybe-false 0
- findings:
  - `[medium]` `[patch]` (verification-gap) the shipped bound path `TestBoundSeconds` → `GatewaySeconds` → `GatewayClass` is never run — added `TestTheShippedBoundFollowsTheGatewayRead` (20 → 10, 300 → 290 through the handler's own call class; the shipped read equals the installer's, source named); mutation run 306.
  - `[medium]` `[patch]` (verification-gap) the child's rebuilt request (budget, prompt, single attempt) is pinned only in process — added `TestTheChildSendsTheTestRequestAsItsCaller` (one message, the prompt, no tools, no system) and `TestTheChildMakesOneAttempt` (429 asked once), and the spawn leg asserts `maxTokens` / `maxAttempts` in the `JOB` argument; runs 303, 306. `max_tokens` on the wire stays unrecorded (`Test/TurnProvider.cls` is not Epic 10's file); deferred.
  - `[medium]` `[patch]` (verification-gap) `Gemini.CallMessages`' map to the history encode is never exercised — added `TestTheGeminiAdapterReplaysTheRespelling`; mutation run 308.
  - `[medium]` `[patch]` (verification-gap) `GeminiEmptyEnumArgs` checked for navigate only — the registry sweep now asserts every respelled enum is a mapped pair, and `TestTheMapNamesAnArrayArgument` pins the `items` kind; mutation run 308.
  - `[medium]` `[patch]` (verification-gap) nothing checks the child's user and roles — `TestTheChildSendsTheTestRequestAsItsCaller` asserts the recorded user and `$Roles` equal the caller's; a child that adds a role reddens it, run 306.
  - `[low]` `[patch]` (verification-gap) a non-local timeout with no label has no client case — one `expect` added; mutation (label stringified unchecked) red.
  - `[medium]` `[patch]` (verification-gap) `tJson [ BODYKEY` on a hand-built array cannot fail — removed; the spawn leg now reads the `JOB` argument `ConnectionOutcome` really handed (`AgentConnectionUnspawned.Handed`), with a body key sent; mutation run 306.
  - `[low]` `[patch]` (verification-gap) AC2's later-passing leg has no recorded mutation — observed, run 307.
  - `[medium]` `[patch]` (verification-gap) the Integration AC's stored key through the child is not pinned (`TurnChain` reads the turn's call) — `AgentConnectionWire` asserts both test calls' `keySha`; mutation run 310.
  - `[low]` `[patch]` (verification-gap) the per-read-timeout leg has no recorded mutation — observed, run 307.
  - `[low]` `[patch]` (verification-gap) the history encode was never observed red — observed, run 309.
  - `[low]` `[reject]` (intent-alignment) a child that throws is reported as a timeout after the full bound — `InvokeDraft` answers faults rather than throwing (AD-42), so only an internal defect reaches the child's `Catch`; guarding it adds a branch for a path no user meets.
  - `[false]` `[reject]` (intent-alignment) the child logs, against "writes nothing" — task 3 requires the child to log through `Kernel.Fault.LogRaw`; no state is written.
  - `[medium]` `[patch]` (intent-alignment) `$ROLES` is not compared in the child — same root cause and fix as the user/roles row above.
  - `[false]` `[reject]` (intent-alignment) the `strings.ts` keys sit mid-object — task 17 places them after 10.4's keys at `:530`.
  - `[false]` `[reject]` (intent-alignment) `Kernel/Agent/Job.cls` edited and `Api/Turn.cls` mutated — tasks 8 and 23 require both; `Api/Turn.cls` is byte-identical to HEAD.
  - `[medium]` `[patch]` (intent-alignment) respelling covers every depth, the map only top-level and `items` — same fix as the map row above: an unmapped respelled path now fails the sweep.
  - `[low]` `[reject]` (intent-alignment) the spawn-fail path is tested through an override, not a real `JOB` refusal — a refusal cannot be produced deterministically; `Spawn` is four lines.
  - `[low]` `[reject]` (intent-alignment) DW-1600/1601 are not driven through a live Gemini turn — the spec puts the live proof in Story 17.7's owner check; the adapter legs pin the canonical `input` dispatch reads.
  - `[low]` `[patch]` (intent-alignment) the client specs use mocked envelopes — `AgentConnectionWire` now also pins `detail.waitedSeconds` of the real envelope the client reads.
  - `[false]` `[reject]` (intent-alignment) AD-42's amendment is dated a day ahead — the system clock reads 2026-09-24 UTC.
  - `[medium]` `[patch]` (intent-alignment) the key-not-in-`JOB` claim is tested on a hand-built array — same fix as the unfalsifiable-assertion row above.

## Design Notes

**Governing ADs.**

- **AD-42**: Test connection takes the turn's path. The per-read timeout re-arms (DW-1179), which is why the bound is wall-clock, and a provider failure is an envelope, never a throw.
- **AD-7**: turns are already in a job, so AC3 needs no change. Test connection stays a foreground request that waits.
- **AD-9**: spawn from no escalated frame.
- **AD-35 / AD-48**: the key never becomes a local.
- **AD-39 / AD-12**: two codes, reasons in `Base.ReasonFor`, one writer.
- **AD-11**: the reply stays bounded at `TESTREPLYMAX`.
- **AD-32**: the same TLS configuration.
- **AD-17**: the installer only reads the gateway value.
- **AD-19**: the store stays framework-free.
- **AD-53**'s idiom: the server copy is pinned to the published sentence.

**Why a child job.** A bound inside the request process can only be a per-read timeout, and a provider that drips a byte at a time defeats it. With the call in a child, the request process owns the clock: `$System.Event.WaitMsg` with the remaining time. What happens to a child the request abandoned:

- Its result lands in a queue that the next `Call` in that pooled process clears first, and it carries a nonce the next call does not match.
- It writes nothing, so a late answer cannot verify a row.
- It lives until its own per-read timeout. A drip-feeding endpoint therefore holds one process per press, which we accept.

The ready handshake exists so the key is sent only to a child that has already cleared its queue.

**"Safely below", as a number.** bound = `g - min(10, g\2)`: 60 → 50, 20 → 10, 10 → 5. The margin covers the spawn and the post-call work: the verification write, the re-read, the audit row and the response, each sub-second. An unread value is taken as the stock 60. A gateway per-application override in CSP.ini is not read; the owner decision is to follow the value the installer reads (inference: a per-app override smaller than `[SYSTEM]` would still cut first). With the stock egress timeout of 90 s, the bound fires first. A lower stored timeout faults `PROVIDER.TIMEOUT` sooner and gets the same reasons.

**Status 504 with an envelope.** 504 is what `HttpFor` already gives a provider timeout, and the envelope is what tells it apart from the gateway's empty one. `AgentConnectionWire` observes a body through the gateway.

**DW-1600: respell, never drop.** Dropping `""` would take Home out of Gemini's navigation. That breaks "behavior does not depend on the family", and touching the subset would break Story 10.1's verbatim rule. So one value is respelled reversibly, in the Gemini translation only, and scoped to the (tool, argument) pairs the request respelled. This is the same idea as the dot-to-underscore name mapping. The Gemini model sees `"(empty)"` where the other families see `""` (inference: it will choose it for Home as readily as `""`; the live check is the lead's).

**DW-1601: a cap, not a spend.** Raising the one cap costs nothing for a model that stops after a sentence, and it cannot make any model refuse the call. Sending `thinkingConfig` was rejected. It is per model within one row: `"minimal"` was refused by 3.8-flash, and gemini-2.5-pro (a suggestion) takes only `thinkingBudget` (inference). A wrong knob would turn today's empty-but-passing test into a refusal. 1024 is 3% of a turn's 32000, and 40 times the 26 thinking tokens observed.

**Files outside Epic 10's exclusive list.**

- `Kernel/Agent/Job.cls` (one doc sentence).
- `Test/DefinitionsProbe.cls` (one member).
- `scripts/ci-throwaway.sh` (roster comment).
- `ui/tools/connection-timeout.test.mjs` (new).
- Shared-append: `Api/Error.cls`, `strings.ts`, EXPERIENCE.md.
- Contended, only if an Epic 9 merge pushes the table past 700: `ui/tools/strings.test.mjs`, under its own widening protocol.
- Run, not edited: `Test/TurnLong.cls`, `Test/TurnChain.cls`, `Installer.cls`, `Registry.ProviderTools`.

**Spine note for the lead (Rule 20).** Add to AD-42: "Test connection's one call runs in a child job the request waits for with a wall-clock bound of the gateway's `Server_Response_Timeout` less `min(10, g/2)` seconds (60 when unread). On expiry the request answers `PROVIDER.TESTTIMEOUT`/`…LOCAL` and records nothing." The Rule should also name `Kernel.Provider.TestCall` as the second process spawn site beside the turn job.

**Ledger inbox.** DW-1600 → tasks 5-7 and 13. DW-1601 → tasks 4 and 14.

**Consumes:** Story 10.4 (the `Response` shape, the catalog, the thought-signature echo), Story 3.4 (`HandleTest`, `ConnectionOutcome`), Story 1.4 (`GatewayResponseTimeout`), and Story 4.x (`TurnProvider`, `TurnLong`, `TurnChain`).

**Consumed-by:**

- Story 17.6: the README's gateway note can cite the bound.
- Story 17.7: the owner's live check of each default model's test and of Gemini turns.
- Story 11.7: streaming must not move the test off this path.

## Verification

**Slot and instance.** Slot B. Every IRIS MCP call carries `server: "ocupilot-slot-b"`. Every test, sweep and mutation runs on the lead's throwaway **`ocupilot-b-ci`** (web 52777), which is up. Do not run `ci-throwaway.sh up` or `down`.

- Load code by refreshing its source copy (`cp -R src/. /tmp/ocupilot-b-ci/src/`), then `docker exec ocupilot-b-ci iris session iris -U HSCUSTOM` with `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot", "ck", , 1)` and `$System.OBJ.CompilePackage("OcuPilot", "ck")`.
- Browser runs export `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci`, after `cd ui && npm run build` and `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`.
- Never touch `ocupilot`, any `ocupilot-slot-*` container, or `ocupilot-ci`, and never test on slot B's stale dev instance. No live provider and no key.

**Commands:**

- `uv run scripts/check-objectscript.py` and `uv run scripts/test_check_objectscript.py`. Expected: clean.
- `bash scripts/lint-docs.sh`. Expected: clean.
- **(loop)** `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class <Class>`. One class per invocation and one invocation per message; never re-submit on a client-side timeout. Classes: `OcuPilot.Test.AgentConnectionBound`, `AgentConnectionWire`, `GeminiEmptyEnum`, `AgentConnection`, `AuditRecord`, `AuditVerbs`, `ConnectionKey`, `DefinitionsFaults`, `Adapter`, `GeminiAdapter`, `TurnChain`, `TurnLong` (over three minutes). Confirm totals with the `%UnitTest_Result` probe in `.claude/rules/objectscript-testing.md`.
- **(loop)** `cd ui && npm run test:tools && npm run test:components`. Expected: green, including `strings.test.mjs` at 700 literals, `ci.test.mjs`'s arming roster, and `connection-timeout.test.mjs`.
- **(loop)** `cd ui && node --test --test-concurrency=1 browser/definitions.browser-spec.mjs`, with both variables set and the bundle redeployed. The full browser suite is CI's `browser` job.
- **(once, before dev_complete)** The full ObjectScript sweep: every class under `src/OcuPilot/Test` that extends `%UnitTest.TestCase`, one at a time on `ocupilot-b-ci`. Then `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`. Zero executed checks is a failure.

**Pinning tests and mutations** (Rule 19). Apply each mutation, recompile the package, observe red, revert, and confirm `git status --short` and `git diff --stat` are unchanged. The implement stage records each observed run.

- AC1, wall clock: `AgentConnectionBound`'s bound-2 leg. Mutation: `TestCall.Call` waits for the result with no deadline. Expect red on elapsed.
  - mutation: `Call`'s result `Await` deadline + 3600 s → `TestAnUnansweredTestAnswersAtItsBound` red (10 asserts, elapsed 6.5 s), run 271.
- AC1, wire: `AgentConnectionWire`. Same mutation. Expect red (the gateway's empty 504 at 60).
  - mutation: same → `TestATestAnswersBeforeTheGatewayDoes` red: 504 with no JSON body at 60.07 s, run 272.
- AC1, the margin: the arithmetic leg. Mutation: `MARGINSECONDS` 0.
  - mutation: `MARGINSECONDS` 0 → `TestTheBoundArithmetic` red (9 asserts), run 273.
- AC1, the source: the seam-20 leg. Mutation: `GatewaySeconds` answers 60 always.
  - mutation: `GatewaySeconds` keeps 60 whatever the read answers → `TestTheGatewayReadSetsTheBound` red on the 20 leg, run 274.
  - mutation: `Definitions.TestBoundSeconds` answers `BoundSeconds("")` → `TestTheShippedBoundFollowsTheGatewayRead` red on 10 and 290, run 306.
- AC1, the wording: the local leg. Mutation: select the non-local code for `markedLocal` 1.
  - mutation: `TimeoutFault` never selects the local code → `TestALocalDefinitionGetsTheLocalReason` red on code and reason, run 275.
- AC2: the late-answer leg. Mutation: record verification on `pTimedOut`. The stale-message leg: mutation: drop the nonce comparison.
  - mutation: `ConnectionOutcome` calls `GuardedSetVerification` when timed out → `TestAnUnansweredTestAnswersAtItsBound` red on the flags after the child returned, run 276.
  - mutation: `Await` drops the nonce comparison → `TestALateAnswerNeverReachesTheNextTest` red, reply-a read by the second test, run 277.
  - mutation: `ConnectionOutcome`'s verification write answers `$$$OK` unwritten → `TestALaterPassingTestVerifies` red on `connectionVerified` and the stored flags, run 307.
- Matrix "Per-read timeout first": `TestAPerReadTimeoutIsTheTestTimeout`.
  - mutation: the `PROVIDER.TIMEOUT` arm of `ConnectionOutcome`'s mapping dropped → red on the code and the seconds waited, run 307.
- AC3: `TurnLong.TestATurnOutlivesTheGatewayResponseTimeout`. Mutation: its documented one (run `Job.Run` inline in `Api.Turn.HandleStart`).
  - mutation: `HandleStart` calls `Job.Run` inline in place of `Job.Start` → `TestATurnOutlivesTheGatewayResponseTimeout` red (no 202, the start answered at 60.05 s) and `TestALapsedLeaseAbandonsTheTurn` red, run 297; reverted, `Api/Turn.cls` byte-identical to HEAD, package recompiled, green, run 298.
- AC4: `connection-timeout.test.mjs`. Mutation: change one word of `REASONTESTTIMEOUT`. Also `strings.test.mjs`: mutation: change one word of the EXPERIENCE row.
  - mutation: "endpoint" → "address" in `REASONTESTTIMEOUT` → the non-local byte-for-byte test red.
  - mutation: "loading" → "warming" in the EXPERIENCE row → `strings.test.mjs` red on three tests (table literal, authorization, line reference).
- Key handoff: the body-key leg. Mutation: the child skips the `%Set`.
  - mutation: `Child` skips the key's `%Set` → `TestABodyKeyCrossesByMessage` red, run 278.
  - mutation: `ValuesJson` writes `keyBody` as its JSON → `TestASpawnThatFailsIsATransportFault` red on the key and the body in the `JOB` argument `ConnectionOutcome` handed the spawn, run 306.
- Integration AC, stored key through the child: `AgentConnectionWire`'s `keySha` assertions on both test calls.
  - mutation: `ValuesJson` leaves out `credentialName` → red, `PROVIDER.CREDENTIAL` and both `keySha` assertions, run 310.
- The child's request, as its caller (AD-9, one attempt): `TestTheChildSendsTheTestRequestAsItsCaller`, `TestTheChildMakesOneAttempt`.
  - mutation: `Child` drops `maxAttempts` and adds `%Manager` to `$Roles` → red on the call count and on the roles, run 306.
- Matrix "Spawn fails": `AgentConnectionBound.TestASpawnThatFailsIsATransportFault`, through `Test/AgentConnectionUnspawned` (its `Spawn` answers 0) behind the probe's call switch.
  - mutation: `Call` carries on when `Spawn` answers 0 → red on the code, the 502 and the elapsed time (answered at the 3 s bound), run 300.
- Matrix "Not answered", not-as-stored record: `AgentConnectionBound.TestAnUnansweredTestOfUnstoredValuesIsRecorded`.
  - mutation: `ConnectionOutcome` maps the timeout after the fault branch → red, the record naming no `faultCode`, run 301; reverted byte-identical, green, run 302.
- Client: the page-spec case for the local code. Mutation: render `reason` for it. The browser case: mutation: the store ignores `detail`; rebuild and redeploy.
  - mutation: `testTimeoutText` returns null for the local code → the page-spec Story 10.5 case red (envelope reason received).
  - mutation: `testTimeoutText` reads `detail['ignored']`, rebuilt and redeployed → the browser Story 10.5 case red (30 s wait for the sentence).
  - mutation: `testTimeoutText` stringifies the label unchecked → the page-spec Story 10.5 case red on "The provider (undefined) ...".
- DW-1600: `GeminiEmptyEnum`'s whole-registry leg. Mutation: remove the respelling. Its decode leg: mutation: skip the decode.
  - mutation: `GeminiSchema`'s `enum` branch disabled → `TestNoGeminiDeclarationCarriesAnEmptyMember` and `TestTheGeminiAdapterSendsNoEmptyMember` red, run 279.
  - mutation: `GeminiToCanonical` skips `RespellEmpty` → `TestTheRespellingDecodesOnItsOwnPairsOnly`, `TestReplayedHistoryRespellsTheSamePairs` and the adapter leg red, run 280.
  - mutation: `CanonicalToGemini` skips `RespellEmpty` → `TestReplayedHistoryRespellsTheSamePairs` (encode assertions) and `TestTheGeminiAdapterReplaysTheRespelling` red, run 309.
  - mutation: `Gemini.CallMessages` passes no map and `GeminiEmptyEnumArgs` loses its `items` branch → `TestTheGeminiAdapterReplaysTheRespelling` and `TestTheMapNamesAnArrayArgument` red, run 308.
- DW-1601: the `AgentConnection` floor leg. Mutation: `TESTMAXTOKENS` 32.
  - mutation: `TESTMAXTOKENS` 32 → `TestTheTestCapLeavesRoomToThink` red alone, run 281.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** Test connection's one provider call runs in a child job (`Kernel/Provider/TestCall.cls`) that the request waits for against a wall-clock bound of `g - min(10, g\2)`, where `g` is the gateway timeout the installer reads, or 60 when unread. An unanswered test, or a `PROVIDER.TIMEOUT`, answers 504 `PROVIDER.TESTTIMEOUT` / `...LOCAL` with the resolved reason and `detail{waitedSeconds, providerLabel}`, and nothing is verified. Gemini respells an empty `enum` member as `"(empty)"`, reversibly, per (tool, argument) (DW-1600). `TESTMAXTOKENS` is 1024 (DW-1601). Copy: one EXPERIENCE row, two `strings.ts` keys and two `Base` parameters, pinned equal. The client resolves the sentence from `detail`.

**This pass.**

- Verified tasks 1-21 in the tree.
- Did tasks 22 (`failureText` doc) and 23 (AC3 mutation, runs 297/298; `Api/Turn.cls` byte-identical).
- Closed the Matrix audit's two uncovered rows:
  - `TestCall.Spawn` is extracted as the one `JOB`, and `Test/AgentConnectionUnspawned` makes the spawn-fail leg reachable.
  - Added the not-as-stored timeout record leg.
- Patched 15 review findings, all of them tests: the shipped bound composition, the child's request shape, user/roles and single attempt, the real `JOB` argument, the Gemini adapter's history encode, map coverage of every respelled enum, `keySha` through the child over the wire, and one client case.

**Files.** Shipped: `Api/Definitions.cls`, `Api/Error.cls`, `Kernel/Provider/{TestCall,Base,Gemini,MessageAdapter,ToolDefAdapter}.cls`, `Kernel/Agent/Job.cls` (doc), `definition-form.{store,page}.ts`, `strings.ts`, EXPERIENCE.md, `scripts/check-objectscript.py` (task 21), `scripts/ci-throwaway.sh` (roster comment). Tests: `Test/AgentConnection{Bound,Wire,Inline,Probe,Unspawned}.cls`, `Test/GeminiEmptyEnum.cls`, `Test/AgentConnection.cls`, `Test/DefinitionsProbe.cls`, `definition-form.page.spec.ts`, `definitions.browser-spec.mjs`, `ui/tools/connection-timeout.test.mjs`.

**Review.** 22 findings from 2 layers: 10 medium, 8 low, 4 false. 15 were patched, 7 rejected, and none deferred from triage. One residual, `max_tokens` not recorded on the wire, is in `deferred:`. Rejected, each with its reason in the triage log: a child throw read as a timeout, the child's log writes, the key order in `strings.ts`, the Job/Turn edits, the spawn-fail override, no live Gemini turn, and the amendment date. `followup_review_recommended: true` because 7 medium entries were patched. The named unverified risk is that the child's `max_tokens` is pinned only in the `JOB` argument, and AD-9 is checked only with a `%All` caller, not with a least-privilege principal over the wire.

**Verification** (on `ocupilot-b-ci`):

| Check | Result |
|---|---|
| Full ObjectScript sweep | 220 classes, 1970 tests, 0 failed (runs 311-530, confirmed by the `%UnitTest_Result` probe) |
| `smoke.sh` | 49/49 |
| `test:tools` | 1372/1372 |
| `test:components` | 1042/1042 |
| `definitions.browser-spec.mjs` (rebuilt and redeployed) | 8/8 |
| `check-objectscript.py` | 0 problems over 742 files |
| `test_check_objectscript.py` | OK |
| `lint-docs.sh` | 0 problems |

Every new pin's mutation was observed red (runs 300-310 and the client case) and reverted byte-identical.
