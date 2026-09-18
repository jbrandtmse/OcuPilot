---
title: 'Story 4.8: A slow or rate-limited provider degrades the turn rather than failing it'
type: 'feature'
created: '2026-09-18'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
warnings: ['oversized']
owned_ledger: ['DW-334', 'DW-413', 'DW-441', 'DW-1053', 'DW-1054']
deferred:
  - summary: 'DW-334 declined in part: the resolver calls are cached but not timed out, because no bounded-resolver API exists'
    evidence: '$System.INetInfo.HostNameToAddr and HostNameToAddrMulti take (host, family) only -- no timeout argument, no deadline. Bounding them means JOBbing a resolver per lookup and polling it, which costs more per call than the lookups it bounds. The cache this story adds removes the repeat cost; the first lookup of a host in a turn is still whatever the resolver takes.'
    location: 'src/OcuPilot/Kernel/Egress.cls'
    severity: 'low'
  - summary: 'DW-441 is the owner''s call and is not decided here; the spec states three options and recommends one'
    evidence: 'See Design Notes "DW-441 -- for the owner". Today a marked-local plain-http endpoint is still requested through a configured proxy in cleartext, pinned as intended by OcuPilot.Test.ProviderProxy:179-185. Unreachable in Release 1: no shipped route writes the State.Egress proxy row.'
    location: 'src/OcuPilot/Port/ProviderPort.cls:266'
    severity: 'med'
---

<intent-contract>

## Intent

**Problem:** A rate limit, a 5xx, a slow model or a slow DNS resolver is today indistinguishable to a user from a broken product. The retry arithmetic exists (`Kernel/Provider/Retry`) but nothing bounds the *total* time one provider call may add to a turn, `Retry-After`'s HTTP-date form is discarded, every endpoint judgement pays four uncached resolver lookups plus a `GetInterfacesInfo` read, and two failure surfaces show the user nothing at all — a turn whose error names no step renders `"The turn stopped at : ..."`, and a Send the instance refuses with anything but 409 renders nothing.

**Approach:** Make the provider call's cost a set of named, test-read numbers and make every failure visible. Bound one call's total wall time and its total added sleep; honor both `Retry-After` forms; carve the two deterministic 5xx out of the retryable band; cache the egress judgement for a few seconds and bring its last unseamed resolver call inside the seam; and give the panel a wording for a failure that names no step and a banner for a refused Send.

## Boundaries & Constraints

**Always:**

- **AD-42 governs the arithmetic.** Bounded timeout; retry only on a retryable status; delay is the greater of the provider's hint and the exponential backoff; **a call that threw mid-flight is never retried**; a provider failure surfaces as a turn error, never as an exception to the client.
- **AD-39 / AD-12 govern the surface.** One envelope `{error, reason, code, detail}`; the screen renders `reason`, a tool result renders `code`; vendor text is normalized at the port boundary (`Base.ProviderMessage` → `detail.providerText`) and the raw `%Status` goes to `Fault.LogRaw` only. No new envelope field, no second shape.
- **AD-35.** No credential value, no resolved endpoint the caller did not supply, reaches a reason, a log line or an exception.
- **AD-31 / AD-11's client-fulfilled wait are unchanged.** `Loop.AnswerClientCall`'s 250 ms `Boundary` pass and `NAVWAITSECONDS` are not touched, and the two waits do not compound: the provider retry sleeps happen inside `Base.Attempts`, between a turn's step boundaries, and are bounded by their own budget so `NAVWAITSECONDS + PROVIDERCALLSECONDS` is the worst any single step costs.
- **Every number has one home and a test reads it with `$Parameter`.** No test restates a value.
- Rule 14: non-ASCII in source is a `\uXXXX` escape. Rule 19: every AC's pinning test has a recorded `mutation:` line.

**Never:**

- Never retry a call that raised, a call that timed out, or a call whose body could not be built.
- Never let a provider choose how long OcuPilot blocks: `Retry-After` stays clamped, and the new budget truncates the last wait rather than honoring it whole.
- Never cache the egress *permission* decision beyond the declared TTL, and never cache it across processes — the cache is process-private and dies with the turn job.
- Never change `Loop`'s wait, `Nav`, the progress contract, the tool registry or the gate. Out of scope: streaming (Epic 11), per-user turn limits (Epic 14), a client-side retry of the Send itself, and any change to `AD-7`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Rate limit, then success | attempt 1 → 429 with `Retry-After: 3`; attempt 2 → 200 | one `Wait` of `max(3, jittered backoff)` seconds, then the mapped response; the turn's `model` step settles `ok` | No error expected |
| HTTP-date hint | 429 with `Retry-After: <now + 12s as an HTTP date>` | the hint resolves to 12 s and is compared with the backoff; the greater is waited | A date in the past, or unparseable, resolves to 0 and the backoff alone is used |
| Hint above the cap | 429 with `Retry-After: 600` | clamped to `MAXRETRYAFTERSECONDS` (30) and the attempt is still made | No error expected |
| Retry budget exhausted | two 429s each hinting 30 s, `RETRYBUDGETSECONDS` 30 | first wait 30 s; the second wait would exceed the budget, so the loop stops without sleeping | `PROVIDER.UNAVAILABLE`, HTTP 502, turn `failed` |
| Deterministic 5xx | 501 (or 505) | not retried; one attempt only | `PROVIDER.REFUSED` with `detail.providerText`, HTTP 502 |
| Retryable 5xx on every attempt | 503 × 3 attempts | 2 waits, 3 calls, then stop | `PROVIDER.UNAVAILABLE`, HTTP 502 |
| Call raised mid-flight | `IssueHttpsPost` throws on attempt 1 | exactly one call; no `Wait` | `PROVIDER.TRANSPORT`, HTTP 502; raw status to the log only |
| Per-call timeout | `Post()` returns `$$$CSPTimeout` | exactly one call; no retry | `PROVIDER.TIMEOUT`, HTTP 504; the turn's error card names the `provider` step |
| Attempt deadline | a stored `timeoutSeconds` large enough that elapsed time passes `ATTEMPTBUDGETSECONDS` before the next attempt | no further attempt is started | `PROVIDER.TIMEOUT`, HTTP 504 |
| No response object | `Post()` returns OK but `HttpResponse` is not an object | one attempt; no retry | `PROVIDER.TRANSPORT`, HTTP 502 |
| Turn error naming no step | turn finishes `failed` with `errorSeq` 0 (job-level refusal), or a seq past `MAXSTEPS` | panel renders the no-step banner wording | Banner present, not blank, not `"stopped at : "` |
| Send refused, not 409 | `POST /turn` answers 401 / 404 / 422 / 500 / status 0 | the panel shows a send-refusal banner carrying the envelope's `reason`, the draft is kept, no transcript entry is appended | 409 keeps today's lock banner and is unchanged |
| Repeat judgement of one host | `Classify("api.anthropic.com")` twice inside the TTL | one set of resolver lookups and one `GetInterfacesInfo`; the second answers from the process cache | A cache read that fails falls through to a live lookup |
| Probe controls the address set | `EgressProbe` arms a set for a host the real resolver answers for | `Addresses` returns exactly the probe's set | No real address is unioned in |

</intent-contract>

## Code Map

Instance — retry and transport:

- `src/OcuPilot/Kernel/Provider/Retry.cls` — the whole arithmetic, pure, driven directly by tests. `RETRYABLESTATUSES = "408,409,429"` :17, `SERVERERRORFLOOR` 500 :20, `STATUSCEILING` 599 :23, `BACKOFFBASESECONDS` 1 :26, `BACKOFFCAPSECONDS` 8 :30, `MAXRETRYAFTERSECONDS` 30 :36. `IsRetryable` :43, `ParseRetryAfter` :58 (**delta-seconds only today**), `ExpBackoffSec` :70 (doubling window, full jitter, `$Random((w*10)+1)/10` :83), `DelaySec` :93 (`max(hint, backoff)`).
- `src/OcuPilot/Kernel/Provider/Base.cls` — `Attempts` :201-269 is the loop and the only place the three failure kinds are told apart: `Try { ..IssueHttpsPost } Catch attemptEx { Set tThrew = 1 }` :223-228, the thrown exit :230-236, the error-`%Status` exit with `$System.Status.Equals(tIssueSC, $$$ERRORCODE($$$CSPTimeout))` :237-241, the status branches :242-263, `Do ..Wait(Retry.DelaySec(tAttempt, tRetryAfter))` :264. `NewRequest` :280-302 (`Timeout` :291 from `pSettings("timeoutSeconds")` else `State.Egress.#DEFAULTTIMEOUT`; the proxy quad :295-300). `IssueHttpsPost` :316 — **the one transport seam**. `Wait` :339 — **the one clock seam today**. `Fault` :406, `HttpFor` :419 (TIMEOUT→504, else 502/503), `ReasonFor` :434 — the one home of the sentences. `LogRaw` :471.
- `src/OcuPilot/Kernel/State/Egress.cls` — `DEFAULTTIMEOUT` 90 :22, `DEFAULTMAXATTEMPTS` 3 :27, `TimeoutSeconds` :47; `Resolve` seeds both into `pSettings` :75-76, overridden from the stored row :87-88.
- `src/OcuPilot/Port/ProviderPort.cls` — `Dispatch` :220-309: `Egress.Resolve` :259, endpoint judgement `Egress.IsPermitted(tEndpoint, …)` :250, proxy judgement :267, https flag forcing :274-277, caller may only *lower* `maxAttempts` :283-285, adapter `Invoke` :305. `ProxyHostOf` :362.
- `src/OcuPilot/Api/Error.cls` — the ten `PROVIDER.*` literals, declared once: `PROVIDEREGRESS` :209, `PROVIDERREFUSED` :239, `PROVIDERUNAVAILABLE` :243, `PROVIDERTIMEOUT` :248, `PROVIDERTRANSPORT` :252. `ReasonForTurnError` delegates every `PROVIDER.` code to `Base.ReasonFor` :935.

Instance — egress judgement:

- `src/OcuPilot/Kernel/Egress.cls` — `Classify` :94 calls `InstanceAddresses` :196 (`$System.INetInfo.GetInterfacesInfo()` :200, doc comment :194-195 refuses to cache it). `Addresses` :153-173 — `For tFamily = 1,2`, `..MultiLookup(pHost, tFamily)` :158 (**the seam**) and then `$System.INetInfo.HostNameToAddr(pHost, tFamily)` :168 (**outside it — DW-413**). `MultiLookup` :181-184. `Rank` :233, `IsPermitted` :121 (`tPermitted = (''pMarkedLocal && ''pAllowsLocal)` :132), `LeavesInstance` :408, `HostLeaves` :417. Kind literals :28-46.

Instance — turn:

- `src/OcuPilot/Kernel/Agent/Limits.cls` — 15 parameters, **no accessors**; every reader uses `$Parameter(<class-name-string>, "NAME")`. `WALLCLOCKSECONDS` 600 :11, `LEASESECONDS` 120 :21, `MAXSTEPS` 100 :30, `NAVWAITSECONDS` 60 :67.
- `src/OcuPilot/Kernel/Agent/Loop.cls` — `Parameter MODELSTEP = "provider"` :24; `LimitsClass()` :27, `PortClass()` :33. Model step appended `running` :172, `tLastSeq = tSeq` :174, the call :175, the fault branch :183-188 (`errorSeq = tSeq`), the ok settle :191-192. `Boundary` :229-289 (lease :271, wall clock :276). `AnswerClientCall`'s wait :581-635 — **not touched by this story**.
- `src/OcuPilot/Kernel/State/Turn.cls` — `GuardedFinish` :308-331 writes `Code` and `ErrorSeq`; `GuardedView` :421-484 emits `error {seq, code}` :448-455. `Api/Turn.cls` :212-214 adds `reason` from `ReasonForTurnError`.
- `src/OcuPilot/Kernel/State/Step.cls` — `GuardedAppend` :75; at the `MAXSTEPS` cap it **returns a seq for a row it did not store** :86-91 (`pStored` stays 0) — the second DW-1053 path.
- `src/OcuPilot/Install/Installer.cls` — `ReportGatewayGap` :1527 already reports the response timeout as `info` :1560-1567 and never modifies it; `GatewayResponseTimeout` :1592 with its registry :1629 and config-file fallbacks. Pinned by `Test/GatewayGap.cls`, `Test/GatewayIni.cls`, `Test/GatewayGapIpmPath.cls`.

Instance — test seams:

- `src/OcuPilot/Test/ProviderStub.cls` — extends `Anthropic`, overrides `IssueHttpsPost` :187 and `Wait` :178 only. `Reset` :35, `QueueAnswer(status, body, retryAfter)` :50 (last entry repeats :210), `QueueTransportFailure(pTimeout)` :63 ( `$$$CSPTimeout` :222 vs `$$$GeneralError` :225), `QueueThrow` :71, `Calls` :147, `Recorded` :157 (records the timeout and the proxy quad :195-209), **`Waits` :164 — the fake clock today: `Wait` records `+pSeconds` and never sleeps**.
- `src/OcuPilot/Test/Provider.cls` — drives the adapter directly. `Settings(Output, pMaxAttempts)` :62, `Call()` :84. Existing retry coverage :228-370.
- `src/OcuPilot/Test/ProviderPortProbe.cls` / `Test/ProviderPort.cls` (`Parameter PORT` :13) — the port seams.
- `src/OcuPilot/Test/EgressProbe.cls` — overrides `MultiLookup` :35 only (`If pFamily '= 1 Quit ""` :39; falls through to `##super` :38 with no set stored). `Test/Egress.cls` :148-156 pins the seam's location by `%Dictionary.CompiledMethod` origins; `:167-171` clears the probe in `OnAfterOneTest`.
- `src/OcuPilot/Test/ProviderProxy.cls` :169-185 — `TestAnHttpsEndpointAlwaysTunnelsThroughTheProxy`; its second half **asserts DW-441's behavior as correct today**.
- `src/OcuPilot/Test/TurnProvider.cls` — the `turnprobe` adapter for real turn jobs; `Script(pTag, pHangSeconds, pReplyBody)` :24, `IssueHttpsPost` :101 **always answers 200** :128 — so no non-200 provider behavior is reachable from a turn job today. `Kernel/Provider/Catalog.cls` arms it :58, :66-71, :134-152 behind `OCUPILOT_ALLOW_TEST_PROVIDER`.
- `src/OcuPilot/Test/TurnWireFixture.cls` — `EnsurePrincipal`, `EnsureDefinition`, `SetTag`, `Call`, `StartBody`, `AwaitEnd`, `Sweep`.

Client:

- `ui/src/app/core/turn.ts` — `stepLabel` :276; `turnErrorBanner(entry, template)` :291-298, the miss at :294-295 (`step === null` → `stepText = ''`, substituted anyway — **DW-1053**). `parseError` :228 defaults `seq` to 0. `send()` :446-517: the 409 branch :481-486 sets `lockedValue`; **every other non-ok** :487-496 clears `busy` and returns `'error'` with no state recorded — **DW-1054**; the conversation-mint failure :461-467 does the same. `pollOnce` :635-671 keeps polling on `installing`/0/≥500 and otherwise finalizes `abandoned` with `error: null` :646-650.
- `ui/src/app/core/api.ts` — `JsonResult` :107-115; the error arm carries `status`, `code` and **`reason: string | null`** :114, parsed from the envelope by `envelopeString` :133.
- `ui/src/app/core/fault.ts` — `classifyFault` :69-82 (status 0 → `unreachable`, 403 → `refused`, 404 → `absent`, 4xx → `rejected`, else `server-fault`); `ui/src/app/shell/fault-banner.ts` :111 `isBannerFault` is true only for `unreachable` and `server-fault`, which is why 401/404/422 change zero pixels.
- `ui/src/app/shell/panel.ts` — banner order and the `[data-slot="lock"]` banner :152-159; the per-turn error banner :205-209 and its computation :486; `sendCurrentDraft` :637-650 ignores the `'error'` outcome.
- `ui/src/app/core/strings.ts` — `agentTurnStoppedBanner` :173 with its `/** EXPERIENCE.md:279 */` comment :172; `agentTurnLockBanner` :175; the two connectivity sentences (`connectivityBannerUnreachable`, `connectivityServerFault` :646) and `actionRetry` :127.
- `ui/tools/strings.test.mjs` — reads EXPERIENCE.md at run time :21-33; anchors the table by the `**Fixed strings**` line and the `| String | Where |` header :48-69; forward :422-426 and reverse :446-465 assertions; the `/** EXPERIENCE.md:n */` comment must resolve to a line containing the literal :608-653; the extracted-literal band is `>= 150 && <= 260` :416-419 (≈246 today). `REQUIRED_ALONGSIDE_TABLE` is frozen at three :440-444, :478 — **not a place to add**.
- `ui/browser/turnprobe-spec.mjs` — shared helpers; `armProbeDefinition` :166 / `disarmProbeDefinition` :174 own the instance-state cleanup, `scriptReply` :146, `setTag` :132. `ui/browser/turn.browser-spec.mjs` :164-232 — the Stop and 409 specs; **no spec asserts the turn error banner's text and none exercises a non-409 Send refusal**.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Kernel/Provider/Retry.cls` — add `NONRETRYABLESERVERSTATUSES = "501,505"` and exclude them in `IsRetryable`; extend `ParseRetryAfter` to accept the RFC 9110 HTTP-date form, resolving it to whole delta-seconds against `$ZTimeStamp` (a past or unparseable date → 0) before the existing clamp; add `RETRYBUDGETSECONDS As %Integer = 30` and `ATTEMPTBUDGETSECONDS As %Integer = 300` with the reasoning in their doc comments; add `DelaySec(pAttempt, pRetryAfter, pRemainingBudget)` truncating the answer to the remaining budget. Keep every method pure.
- `src/OcuPilot/Kernel/Provider/Base.cls` — add `Method NowSeconds() As %Numeric { Quit $ZHorolog }` beside `Wait` as the **second seam**, doc'd as the clock a test replaces. In `Attempts`: record the call's start from `..NowSeconds()`, carry a spent-delay accumulator, pass the remaining budget into `DelaySec`, add the spent wait to the accumulator, and refuse to start a further attempt once `..NowSeconds() - start >= Retry.#ATTEMPTBUDGETSECONDS` — that exit sets `PROVIDER.TIMEOUT` and logs `"the provider call passed the time this instance allows before another attempt"`. Do not change the thrown / error-`%Status` / non-retryable exits.
- `src/OcuPilot/Kernel/Agent/Limits.cls` — add `PROVIDERCALLSECONDS As %Integer = 300`, doc'd as the turn's declared ceiling on one provider call including its retries, pinned equal to `Retry.#ATTEMPTBUDGETSECONDS` by test, and stating the consequence: a turn may be observed for up to `WALLCLOCKSECONDS + PROVIDERCALLSECONDS` because the wall clock is checked *before* a call, and a lapsed lease is noticed at most `PROVIDERCALLSECONDS` late (AD-31's "next step boundary", unchanged).
- `src/OcuPilot/Kernel/Egress.cls` — move the `HostNameToAddr` single-form call **inside** `MultiLookup`, which now unions both forms for one family and is the only method naming `$System.INetInfo` for a host lookup (DW-413); `Addresses` keeps its name and only unions across families. Add `JUDGEMENTCACHESECONDS As %Integer = 5`, a process-private cache for the per-host verdict and for the interface set, read and written by `Classify`/`InstanceAddresses`, plus `ClearJudgementCache()` (DW-334). A cache read that fails or has expired falls through to a live lookup; nothing is cached across processes.
- `src/OcuPilot/Test/EgressProbe.cls` — clear the judgement cache in `SetAddresses` and `Clear` so a probe's set is never masked by an earlier verdict.
- `src/OcuPilot/Test/ProviderStub.cls` — override `NowSeconds` to answer a fake clock; advance it by every `Wait` amount and by a per-call `ScriptElapsed(pSeconds)` the queue carries, so the attempt deadline and the retry budget are exercised with no real time passing. Keep `Waits()` and every existing entry point unchanged.
- `src/OcuPilot/Test/TurnProvider.cls` — extend `Script(pTag, pHangSeconds, pReplyBody, pHttpStatus = 200, pRetryAfter = "")` with the two new arguments defaulted so every existing caller is unchanged, and have `IssueHttpsPost` answer the scripted status and header — the only way a real turn job can reach a provider failure.
- `src/OcuPilot/Test/ProviderRetry.cls` — **new** `%UnitTest` class (keep under ~500 lines): the arithmetic over its whole range, the HTTP-date form, the 501/505 carve-out, budget truncation and exhaustion, the attempt deadline, the three failure kinds, and the bounds relation read with `$Parameter` from `Retry`, `State.Egress` and `Limits`.
- `src/OcuPilot/Test/TurnProviderFault.cls` — **new** `%UnitTest` class: a real turn job against a scripted 500 and against a scripted timeout; asserts the turn's `state`, `code`, `ErrorSeq` and the `model`/`provider` step's status, and that the progress route answers a well-formed envelope on every one — never a 500 with a stack.
- `src/OcuPilot/Test/Egress.cls` — extend for the seam move (a probe-armed set for a host the real resolver *does* answer for, e.g. `localhost`, returns exactly the probe's set) and the cache (repeat `Classify` of one host inside the TTL performs one set of lookups); keep the existing origin assertions :148-156.
- `src/OcuPilot/Test/Provider.cls` — leave its existing methods alone; only re-point any assertion the `DelaySec` signature change breaks.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` — **append one row at the end of the Fixed strings table**, immediately after the `"<n> rows returned · <m> sent"` row, which is line 351 today, so the new row lands on line **352** and no existing row's line number moves: `| "The turn stopped: <reason>." | error banner ending a turn whose failure names no step it stopped at (FR-23) |`.
- `ui/src/app/core/strings.ts` — add `agentTurnStoppedNoStepBanner: 'The turn stopped: <reason>.'` preceded by `/** EXPERIENCE.md:352 */` on its own line. Confirm the number against the edited file before running the suite — `ui/tools/strings.test.mjs` :608-653 requires the comment to name the line the literal actually sits on.
- `ui/src/app/core/turn.ts` — `turnErrorBanner(entry, template, noStepTemplate)` selects `noStepTemplate` when the `seq` lookup misses, and never substitutes an empty `<step>`; add `sendError(): SendRefusal | null` (`{status, code, reason}`) to `TurnStore`, set on every non-409 refused `POST /turn` **and** on a failed conversation mint, cleared at the start of the next `send()` and by `endSession()`. The 409 path is unchanged.
- `ui/src/app/shell/panel.ts` — pass both templates to `turnErrorBanner`; render a `[data-slot="send-error"]` banner immediately after the lock banner when `sendError()` is non-null, its text the envelope's `reason` when present and otherwise the connectivity sentence `classifyFault` selects for that status (`core/fault.ts`), with `role="alert"`. No new literal.
- `ui/tools/turn.test.mjs` — the no-step banner wording, the seq-past-`MAXSTEPS` case, and `sendError` set/cleared across 401, 404, 422, 500, status 0 and 409.
- `ui/src/app/shell/panel.spec.ts` — the send-refusal banner renders with the server's reason and disappears on the next successful send.
- `ui/browser/turn.browser-spec.mjs` — two specs, importing `turnprobe-spec.mjs` and asserting their own cleanup through `armProbeDefinition`/`disarmProbeDefinition`: a scripted 500 on every attempt ends the turn with a banner naming the `provider` step, and a Send the instance refuses with a non-409 status shows the send-refusal banner with the draft kept.

**Acceptance Criteria:**

- **AC1 (retry policy as numbers)** — Given `Retry`'s parameters, when a test reads them with `$Parameter` and drives `IsRetryable`, `ParseRetryAfter`, `ExpBackoffSec` and `DelaySec` over their whole input range, then 408/409/429 and 500–599 retry **except 501 and 505**; the backoff window is 1 s doubling to a cap of 8 s with full jitter; `DelaySec` is the greater of the honored hint and the backoff; and no value appears in the test as a literal.
- **AC2 (the two `Retry-After` forms)** — Given `Retry-After: 12`, an HTTP date 12 seconds in the future, an HTTP date in the past, and `not-a-date`, when `ParseRetryAfter` reads each, then it answers 12, 12, 0 and 0, and a value above `MAXRETRYAFTERSECONDS` answers the cap.
- **AC3 (bounded total added delay)** — Given two consecutive 429s each hinting 30 s and `RETRYBUDGETSECONDS` 30, when the call runs, then exactly one wait of 30 s is taken, the second is not, and the call ends `PROVIDER.UNAVAILABLE`; and given a stored `timeoutSeconds` large enough that the fake clock passes `ATTEMPTBUDGETSECONDS`, then no further attempt is started and the call ends `PROVIDER.TIMEOUT`.
- **AC4 (a thrown call is never retried)** — Given `IssueHttpsPost` raises on attempt 1, when the loop reads it, then `ProviderStub.Calls()` is 1, `Waits()` is empty, and the fault is `PROVIDER.TRANSPORT`; and given `IssueHttpsPost` instead returns an error `%Status`, the same holds with `PROVIDER.TIMEOUT` for `$$$CSPTimeout` and `PROVIDER.TRANSPORT` otherwise — the two are told apart only by the `Try`/`Catch` around the seam and by `$System.Status.Equals`.
- **AC5 (the timeout names its step)** — Given a real turn job whose scripted provider times out, when the turn resolves, then the turn row is `failed` with `Code = "PROVIDER.TIMEOUT"` and `ErrorSeq` equal to the `model` step whose `Name` is `"provider"`, `GET /turn/{id}/progress` carries `error {seq, code, reason}` with that seq, and the panel's banner reads `"The turn stopped at provider: The provider did not answer within the time this instance allows."`
- **AC6 (never an exception to the client)** — Given each of the five provider failure kinds in turn, when `GET /turn/{id}/progress` answers, then every response is exactly one well-formed envelope, the HTTP status is the one `Base.HttpFor` declares (504 for `PROVIDER.TIMEOUT`, 502 otherwise on the direct routes), no response body contains `}{`, and no reason, code or detail contains any part of the credential or the raw `%Status` — the raw text appears only through `Fault.LogRaw`.
- **AC7 (DW-1053)** — Given a turn that finished `failed` with `error.seq` naming no step in the same projection — `errorSeq` 0 from a job-level refusal, and a seq returned past `MAXSTEPS` — when the panel renders, then the banner reads `"The turn stopped: <reason>."` and never contains `"at :"`.
- **AC8 (DW-1054)** — Given `POST /turn` refused with 401, 404, 422, 500 or status 0, when the user pressed Send, then a `[data-slot="send-error"]` banner appears carrying the envelope's `reason` (or the connectivity sentence for that status when the envelope carries none), the draft is preserved, no transcript entry is appended, and the banner clears on the next successful send; 409 still raises the lock banner and nothing else.
- **AC9 (DW-413)** — Given `EgressProbe` armed with a set for a host the instance's real resolver answers for, when `Egress.Addresses` runs, then the returned set is exactly the probe's set, and `%Dictionary.CompiledMethod` still reports `Addresses.Origin = "OcuPilot.Kernel.Egress"` and `MultiLookup.Origin = "OcuPilot.Test.EgressProbe"`.
- **AC10 (DW-334)** — Given `Classify` called three times for the same host inside `JUDGEMENTCACHESECONDS`, when a counting probe records the underlying lookups, then one set of family lookups and one `GetInterfacesInfo` were performed; and given the TTL has passed, then the next call performs them again.
- **AC11 (the installer's Web Gateway note)** — Given `Installer.Install` on a clean throwaway, when its reports are read, then the Web Gateway response timeout appears exactly once at severity `info`, no report names it as a prerequisite, install succeeds when the Gateway registry answers nothing, and no Gateway value is written — the behavior Story 1.4 shipped, re-asserted here so this story's AC has a test rather than a claim.
- **AC12 (Integration, Rule 1)** — Given consumer `ui/src/app/shell/panel.ts` reading `core/turn.ts`, when a real turn against a scripted 500 ends in the browser, then `.ocu-panel-error-banner` is present in the DOM with text naming the `provider` step, and the composer is re-enabled with `Send` restored — observed through `npm run test:browser` against the deployed bundle, not through store state.
- **AC13 (the two waits do not compound)** — Given `Loop.AnswerClientCall`'s wait and a provider retry in the same turn, when a test reads the bounds, then `PROVIDERCALLSECONDS` equals `Retry.#ATTEMPTBUDGETSECONDS`, `PROVIDERCALLSECONDS < WALLCLOCKSECONDS`, and `DEFAULTMAXATTEMPTS * DEFAULTTIMEOUT + RETRYBUDGETSECONDS <= ATTEMPTBUDGETSECONDS` — every term read with `$Parameter`, none restated.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs:** AD-42 (the retry contract, the bounded timeout, the never-retry-a-thrown-call rule, the proxy as a judged destination), AD-39 and AD-12 (one envelope, two renderings, vendor text normalized at the port), AD-31 and AD-41 (the turn's bounds and the lease), AD-35 (no credential on any surface), AD-32 (outbound TLS and proxy are configuration), AD-11 (the progress record is untrusted content; invariant 3's wait is untouched), AD-33, AD-7 and the spine's *Superseded* entry on the Web Gateway response-timeout prerequisite, AD-19 (framework-free `core/`, mirrored into signals).

**What already exists, and what this story actually adds.** Epic 3 built `Retry.cls` and `Base.Attempts` to AD-42's shape, and `Test/Provider.cls` already pins the backoff, the attempt bound, the non-retryable status, the thrown call and the timeout. This story does **not** re-derive any of that. It adds the four things the existing code does not have — a bound on total added delay, a bound on one call's total wall time, the HTTP-date form of `Retry-After`, and the 501/505 carve-out — and it makes the *turn-level* half true: until now no test drove a provider failure through a real turn job at all, because `Test/TurnProvider` could only answer 200.

**Why the numbers are what they are.** Attempts 3 and timeout 90 s are the shipped `State.Egress` defaults and are unchanged; three attempts is what the provider SDKs default to and what the operator can already lower per row. `RETRYBUDGETSECONDS` 30 is one honored `Retry-After` at its own cap, so a provider that asks for the maximum gets it once and not twice. `ATTEMPTBUDGETSECONDS` 300 is `3 x 90 + 30` exactly, so the deadline binds only when the stored `timeoutSeconds` is larger than the default — which nothing bounds today. 300 is half of `WALLCLOCKSECONDS`, which is the relation AC13 pins.

**Why `PROVIDERCALLSECONDS` lives in `Limits` and the arithmetic does not.** `Kernel/Provider/` must not depend on `Kernel/Agent/`: the port is reached from Test connection as well as from a turn, and a provider class that reads the turn's limits would make the transport a turn-shaped thing. So the enforced deadline is `Retry`'s and the *declared* turn-side ceiling is `Limits`', and a test pins them equal — the same "one list, two homes, pinned equal by a test" idiom the spine already uses for the secrets pattern. A reviewer reading either class finds the other named in its doc comment.

**The clock seam.** `Wait` already exists and `ProviderStub` already records instead of sleeping, which is why the shipped backoff tests do not sleep. The budget and the deadline need *elapsed* time as well, so `NowSeconds()` joins it: production answers `$ZHorolog`, the stub answers a counter it advances by each recorded wait plus a scripted per-call duration. This is the same shape `OcuPilot.Test.TurnLimitsNav` uses for `Loop.LimitsClass()` — a seam the test overrides rather than a real number the test waits out.

**DW-334, addressed in part.** The repeat cost is removed with a process-private verdict cache at a 5-second TTL: one turn's many provider calls now pay one set of lookups instead of one per call, and the write path is unchanged in behavior because a definition is saved once. The TTL is deliberately short. `InstanceAddresses`' own doc comment refuses a cache because an interface can appear under a running instance; five seconds is short enough that the statement stays true in any operational sense while collapsing the per-call cost, and the cache is process-private so it cannot outlive the turn job. What is **declined** is the timeout half: `$System.INetInfo.HostNameToAddr` and `HostNameToAddrMulti` take `(host, family)` and nothing else, so bounding them means jobbing a resolver per lookup and polling it — more cost per call than the lookups it would bound. Recorded in frontmatter `deferred:`.

**DW-413.** The fix is one move: the single-form call goes inside `MultiLookup`, which becomes "every address this family answers for this host". The seam's name is kept because `Test/Egress.cls` :148-156 pins its origin structurally, and the test that proves the move works is the one that could not be written before — arm the probe for a host the real resolver *does* answer for and assert the probe's set is the whole set.

**DW-441 — for the owner.** Today `Base.NewRequest` :295 applies the proxy whenever `pSettings("proxyServer")` is non-empty, with no scheme, kind or marked-local condition, and `ProviderPort` :266-278 only *hardens* the tunnel flags for an https endpoint. So a marked-local `http://127.0.0.1:11434/...` endpoint is sent to the proxy host in cleartext, credential header included, and `Test/ProviderProxy.cls` :179-185 pins that as intended. It is unreachable in Release 1 because no shipped route writes the `State.Egress` proxy row. The options:

1. **Bypass** — do not apply the proxy when the endpoint is plain `http` and the definition is marked local. Standard `no_proxy` semantics; a marked-local endpoint is by definition reachable without the proxy, and the harm being removed is a credential in cleartext to a third host.
2. **Fail closed** — refuse the call with `PROVIDER.EGRESS` when a proxy is configured and the endpoint is a marked-local plain-`http` one, so the operator must choose.
3. **Status quo** — keep today's behavior and document it at the property.

**Recommended: (1).** It is the least surprising, it removes the only cleartext-credential path in the product, and it needs no new error code or operator action. (2) turns a working local configuration into a refusal the operator did not ask for; (3) leaves a latent credential exposure behind a row nothing writes yet. **Not decided here** — the lead carries it to the owner.

**DW-1053 and the one new fixed string.** The banner template has no wording for a failure that names no step, and two real paths produce one: a job-level refusal finishes with `errorSeq` 0 (`Job.cls` :85, :92, :99, :119, :123), and `Step.GuardedAppend` returns a seq for a row it did not store once `MAXSTEPS` is reached. A second template is the smallest fix and keeps both sentences canonical in EXPERIENCE.md. The row is **appended at the end of the Fixed strings table** rather than placed beside its sibling at `:279`: `ui/tools/strings.test.mjs` :608-653 requires every `/** EXPERIENCE.md:n */` comment to resolve to the line it names, so an insertion in the middle would renumber about seventy comments in `strings.ts` for no reader benefit. The extracted-literal band :416-419 has headroom for one row.

**DW-1054 adds no literal.** The envelope already carries a written `reason` for every refusal the API can produce, and `JsonResult`'s error arm already parses it (`api.ts` :114). The panel renders that sentence; only when the envelope carries none — status 0, or a body that is not an envelope — does it fall back to the connectivity sentence `classifyFault` already selects for that status. Inventing a wrapper sentence would put a second, weaker copy of the server's own reason in front of the user and cost a fixed-strings row for nothing.

**The Web Gateway note is information, and nothing changes.** The spine's *Superseded* section settles it: AD-7's background job holds no request open, so the response timeout is not a prerequisite and the stock 60 seconds suffices. `Installer.ReportGatewayGap` :1560-1567 already reports it at severity `info`, never modifies it, and tolerates a Gateway that answers nothing. AC11 exists to give that sentence a test on this story rather than a claim; no installer behavior changes.

**Integration ACs (Rule 1).** This story introduces no new service. It changes `Kernel/Provider/Retry`, `Kernel/Provider/Base`, `Kernel/Egress` and two client projections, all of which have live consumers today. AC12 is the integration criterion: the panel, through `core/turn.ts`, against a real turn job and the deployed bundle.

**Consumes:** 4.1 (`Kernel/Agent/{Job,Loop,Limits}`, `Kernel/State/{Turn,Step}`), 4.2 (`Dispatch`, the registry, the one gate point), 4.5 (`core/turn.ts`, the progress shape, the step fields, `TurnStore.send`), 4.7 (`Loop.AnswerClientCall`'s bounded wait — read before planning the retry loop and deliberately untouched; `ui/browser/turnprobe-spec.mjs`'s cleanup helpers), Epic 3 (`Port/ProviderPort`, `Kernel/Provider/*`, `Kernel/Egress`, `Kernel/State/Egress`), Epic 1 (`Api/Error`, `Kernel/Fault`, `core/strings.ts`, `Install/Installer`).

**Consumed-by:** 4.9 (the ledger records provider usage and result status per call, including the failure codes this story bounds), Epic 11 (streaming replaces the single `IssueHttpsPost` with an incremental read; the retry and budget arithmetic is what it will reuse), Epic 14 (per-user turn limits sit over `Limits`).

## Verification

**Commands:**

- `uv run scripts/check-objectscript.py` — expected: no findings on the changed `.cls` files.
- Compile into `ocupilot-slot-a` through the IRIS MCP tools with `server: "ocupilot-slot-a"` on **every** call — expected: every changed class compiles clean. Never load mutated code on the live instance and never spawn a turn there.
- `rsync -a --delete src/ /tmp/ocupilot-ci/src/` then `$System.OBJ.LoadDir("/opt/ocupilot/src", "ck", , 1)` inside `ocupilot-ci` — expected: 0 errors.
- `node ui/tools/ci-runner.mjs --container ocupilot-ci --class <Class>` — **one class per tool call, one invocation per message**, each confirmed in `%UnitTest_Result` before the next: `OcuPilot.Test.ProviderRetry`, `OcuPilot.Test.Provider`, `OcuPilot.Test.ProviderPort`, `OcuPilot.Test.ProviderProxy`, `OcuPilot.Test.Egress`, `OcuPilot.Test.ContextBound`, `OcuPilot.Test.TurnProviderFault`, `OcuPilot.Test.TurnLoop`, `OcuPilot.Test.TurnWire`, `OcuPilot.Test.GatewayGap`. Expected: all green, zero executed checks is a failure.
- `cd ui && npm test` — expected: the node assertions and the vitest component files all pass, including the new `turn.test.mjs` and `panel.spec.ts` cases and `strings.test.mjs` with the new row.
- `cd ui && npm run build` — expected: the six prebuild checkers pass and the initial bundle stays under `angular.json`'s 780 kB `maximumWarning` (766 kB measured before this story; the implement stage's own run is the figure to trust).
- `cd ui && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/` then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci npm run test:browser` — expected: the suite is green including the two new `turn.browser-spec.mjs` cases, and each asserts its own cleanup through `turnprobe-spec.mjs`'s `armProbeDefinition`/`disarmProbeDefinition`.
- `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` — expected: green, with a non-zero executed-check count.
- `bash scripts/lint-docs.sh` — expected: clean, including the edited EXPERIENCE.md.

**Mutations (Rule 19) — apply, observe red, revert, confirm `git status --short` and `git diff --stat` are unchanged, and record each next to its test:**

- AC1 — remove `501` from `NONRETRYABLESERVERSTATUSES` → `ProviderRetry`'s carve-out test goes red.
- AC2 — return `0` from the HTTP-date branch of `ParseRetryAfter` → the future-date case goes red.
- AC3 — pass the unbounded delay to `Wait` instead of the budget-truncated one → the budget test's `Waits()` assertion goes red; raise `ATTEMPTBUDGETSECONDS` to 100000 → the deadline test goes red.
- AC4 — move `IssueHttpsPost` outside the `Try` (or `Continue` instead of `Quit` after `tThrew`) → the thrown-call test's `Calls()` assertion goes red.
- AC5 — set `pOutcome("errorSeq") = 0` in `Loop`'s fault branch → `TurnProviderFault`'s step assertion goes red.
- AC6 — let `Base.Fault` pass the raw `%Status` text through as `reason` → the no-credential/one-envelope assertion goes red.
- AC7 — restore the single-template `turnErrorBanner` → the `turn.test.mjs` no-step case goes red.
- AC8 — drop the `sendError` assignment from the non-409 branch → the `panel.spec.ts` banner case goes red.
- AC9 — move the `HostNameToAddr` call back out of `MultiLookup` → the probe-controls-the-set test goes red on an instance whose resolver answers for the chosen host.
- AC10 — set `JUDGEMENTCACHESECONDS` to 0 → the lookup-count test goes red.
- AC11 — change the Gateway timeout report's severity from `info` to `warn` → `GatewayGap`'s assertion goes red.
- AC12 — rebuild and redeploy the bundle first (a browser spec runs the deployed bundle, never the working tree), then suppress the error banner's render in `panel.ts` → the browser spec goes red.
- AC13 — set `PROVIDERCALLSECONDS` to 700 → the bounds-relation test goes red.

**Manual checks:**

- After every mutation, `git status --short` and `git diff --stat` must match their pre-mutation output byte for byte before the next one is applied.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none. Planning only; the story is not implemented. One item is carried to the
owner rather than decided here — DW-441's proxy-on-a-marked-local-plain-http endpoint, with three
options and a recommendation in Design Notes.
