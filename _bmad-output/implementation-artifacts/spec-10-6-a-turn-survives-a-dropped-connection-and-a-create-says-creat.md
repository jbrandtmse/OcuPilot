---
title: 'Story 10.6: A turn survives a dropped connection, and a create says created'
type: 'bugfix'
created: '2026-09-25'
status: 'done'
baseline_revision: '3abf7fbbef0b731b2a8a9fe00122d53ab3d60218'
baseline_commit: '3abf7fbbef0b731b2a8a9fe00122d53ab3d60218'
review_loop_iteration: 0
followup_review_recommended: true
context: []
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** On slot C, three of about ten Claude Opus 5 turns stopped with `PROVIDER.TRANSPORT`. In each, `%Net.HttpRequest` returned `ERROR #6097 <READ>` within a second, before any status line, and `Base.Attempts` ends the call on its first transport failure (`Base.cls:300-304`). Separately, after a confirmed create the panel reads "<entity> was updated", because the panel's change sentence always uses the updated template (`panel.ts:981`).

**Approach:**

- A model call whose connection broke before a status line arrived is retried once, on a new request object, inside the existing attempt and delay budget (AD-42 as amended 2026-09-25).
- Every provider request sets `SocketTimeout` 0.
- The panel takes the change action and the created id from the confirm's own answer, which already carries both.

## Boundaries & Constraints

**Always:**

- **What counts as a transport failure.** `IssueHttpsPost` returned an error status that is not `$$$CSPTimeout`, and no status line was read, so the answered `pStatus` is 0.
  - Only this is retried.
  - It is retried at most once per call, and only while `tAttempt < tMaxAttempts` and the attempt deadline has not passed.
  - The wait before the retry is `Retry.DelaySec(tAttempt, "", <remaining delay budget>)`.
- **What stays as today.**
  - A raise (`tThrew`) is never retried.
  - A timeout is never retried.
  - A status line followed by a broken body is never retried.
  - Every 4xx/5xx keeps its present handling.
  - A retry that fails ends `PROVIDER.TRANSPORT`, 502, with the present reason.
- **Writes are never retried mid-flight (AD-42).** The confirm path and the screen path each reach the port exactly once per write.
- **The key stays where it is (AD-35).** It stays on `ApiKey` across the retry, as it does for a status retry. It is cleared on every exit. The retry's log line carries the `%Status` only.
- **The panel sentence comes from the confirm's answer.**
  - The action is the confirm's `action`, read through the existing `confirmedAction`: created, updated or deleted, falling back to updated.
  - The id is the confirm's `createdId` when it is present, otherwise the proposal target's id. These are the same values the change event and the toast use (AD-14).
- **Contended files (Epic 12).** In `core/turn.ts` and `shell/panel.ts`, insert every new member immediately before `ok`, so each sits apart from Epic 12's `continues` line after `auditMarked`.
- **No live provider in any test.** Do not read `.env.local`.

**Never:**

- Retry in `Kernel/Agent/Loop` or `Kernel/Agent/Dispatch`, retry a tool call, or re-dispatch a turn step.
- Retry inside `Kernel/Proposal/**`. This story does not edit that path; it is touched only by applying a mutation and reverting it.
- Special-case Test connection. Its `maxAttempts` of 1 (`Api/Definitions.cls:891`) already leaves no attempt for a retry.
- Change `Api/Error.cls`, `strings.ts`, EXPERIENCE.md, the spine, `Installer.cls`, or `TurnProvider.cls`.
- Edit Epic 12's `continues` lines, or `turn.ts:1078-1103`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| One break | attempts 3; first issue answers error, `pStatus` 0; second answers 200 | reply mapped; two transport entries, two `NewRequest`s; one wait ≤ 1 s | No error expected |
| Two breaks | same, both break | stops after 2 calls | `PROVIDER.TRANSPORT`, 502 |
| Status line then broken | error with `pStatus` 200 | 1 call | `PROVIDER.TRANSPORT`, no retry |
| No attempt left | `maxAttempts` 1 (Test connection's case), or deadline passed | 1 call | `PROVIDER.TRANSPORT` (not `PROVIDER.TIMEOUT`) |
| Raise / timeout | stub `throw` / `timeout` | 1 call each, as today | `PROVIDER.TRANSPORT` / `PROVIDER.TIMEOUT` 504 |
| Any family's request | Anthropic, OpenAI, Gemini, Compatible | request `SocketTimeout` is 0 | — |
| Turn, break once | TurnProvider script `-1`, then a text reply | turn `completed` with that reply, 2 calls | — |
| Turn, break twice | script `-1` only (repeats) | turn `failed`, code `PROVIDER.TRANSPORT`, 2 calls | existing envelope |
| Write fails | confirm; port raises / answers no HTTP / 503 | `WriteCount` 1 each; a second confirm is refused `BURNED` | existing handling |
| Confirmed create | confirm body `action:"created"` (`createdId` optional) | panel reply ends "<id> was created"; toast the same | — |
| Confirmed delete / update / no action | `deleted` / `updated` / absent | "was deleted" / "was updated" / "was updated" | — |

</intent-contract>

## Code Map

- `src/OcuPilot/Kernel/Provider/Base.cls`:
  - `:19-23` is the class doc: "raised and timed out are never retried".
  - `:223-226` is `Attempts`' exits doc.
  - The loop runs `:266-336`: request `:277`, raise branch `:293-299`, error-status branch `:300-304`, status-retry tail `:327-335`.
  - `NewRequest` `:390-412` is the only place a provider `%Net.HttpRequest` is built (grep of `src/`).
  - `IssueHttpsPost` `:455-474`; its doc `:445-447` says the outputs are meaningless on error.
- **Object lifetimes, for Design Notes.**
  - One request per attempt: created `:277`, released `:292` (`:282` on a build failure).
  - One adapter per call: `Port/ProviderPort.cls:341`, released `:351`.
  - Test connection passes `maxAttempts` 1 at `Api/Definitions.cls:891`, and `ProviderPort.cls:318` honours a lower value.
- **Vendor source, read-only.**
  - `irislib/%Net/HttpRequest.cls:451-454`: `SocketTimeout`, default 115; "0 to disable keep-alive".
  - `:1634-1655`: reuse only when the same object's `Device` is set and `zts-i%TimeLastUsed<i%SocketTimeout`; otherwise `CleanUp` and a new socket.
  - `:1509-1518`: after the response, the socket closes only for HTTP/1.0 without keep-alive, or on `Connection: close`.
  - `:98-111`: `CleanUp` closes `Device` and is called from `%OnClose`.
  - `:1498-1502`: a fresh `HttpResponse` is created before `Read`, and `Read` errors call `CleanUp`.
  - `:2123-2130`: `StatusLine`/`StatusCode` are set only once the status line is parsed.
  - `:2109`, `:2366`: `<READ>`/`<DISCONNECT>` become `$$$TCPIPError` (6097, `%occErrors.inc:2370`).
  - `:1228-1229`: a failed `Open` returns before any `HttpResponse` exists.
- `src/OcuPilot/Kernel/Provider/Retry.cls:11-14`: the class doc's never-retried list. `DelaySec` `:203` is reused as is.
- **Stubs.**
  - `Test/ProviderStub.cls` (extends Anthropic):
    - Queue methods `:55-80`.
    - `IssueHttpsPost` `:227-275`; its kinds are `throw`, `timeout` and `failure`, and `failure` answers `pStatus` 0.
    - Readers: `Calls`, `Recorded`, `Waits`, `ScriptElapsed`.
  - `Test/ProviderStubTransport.cls:36-80` is the same transport for `OpenAIStub`, `GeminiStub` and `CompatibleStub`.
- **Tests that move with the behavior change.**
  - `Test/ProviderRetry.cls:284-322` `TestNoFailedTransportIsEverRetried`: its third leg (failure, attempts 3, `Calls` 1) goes red.
  - `Test/TurnProviderFault.cls:152-170`: `:168` asserts `Calls` 1 "never retried". Its helper is `RunFailingTurn` `:94-108`, which asserts `failed`.
  - `Test/Provider.cls:367-374` (attempts 1) stays green.
- **Write-path fixtures.** `Test/ConfirmFixture.cls`, and `Test/ProposalFixture.cls`:
  - `ArmWriteException` `:89`, `ArmWriteFault` `:76`, `WriteCount` `:102`.
  - `Invoke` `:189` counts `writes` before raising.
  - `Test/ProposalConfirm.cls` has a `Seed()` helper; its write-fault leg is at `:511-530`.
  - `Kernel/Proposal/Operation.cls:390` `ApplyAt` is the one port write both callers reach.
- **Client, the fault.** `ui/src/app/shell/panel.ts`:
  - `:52` imports `formatChangeSentence` only.
  - `PanelWriteCard` `:148-153`.
  - `replyWithChangeSentence` `:971-986`, hardcoded at `:981` (`formatChangeSentence(STRINGS.tableChangeUpdated, proposal.target.id)`); its stale doc is `:966-967`.
  - `recordWriteCard` `:1151-1162`.
- **Client, the confirm answer.** `ui/src/app/core/turn.ts`:
  - `NO_OUTCOME` `:78-88`, `ProposalOutcome` `:295-318`.
  - `confirmedAction` `:359-362`, `confirmedId` `:369-372`.
  - The ok literal `:1066-1076` has no action.
  - The refusal literal is `:1104-1114`.
- `ui/src/app/core/toasts.ts:86-90`: `changeSentenceTemplate(action)` is already correct, and the toast path uses it (`shell/toast-host.ts:177`).
- **Server, correct and untouched.** `Screen/Tool/Write.cls:124` defaults `CHANGEACTION` to "updated", and `Write.cls:141` defaults `CREATES` to 0. `Kernel/Proposal/Confirm.cls:427,765` puts `action` on the answer, and `Api/Confirm.cls:43,48` sends it.
- **Existing client tests.**
  - `ui/src/app/shell/panel.spec.ts:3430-3467`: the Story 5.7 case expects "updated" with no action. Epic 12's hunk sits at `:3382-3425`.
  - `ui/tools/turn.test.mjs:1450-1537`: `created` reaches the bus.
- **Browser precedent.**
  - `ui/browser/proposal-confirm.browser-spec.mjs:27-76` has the imports, the `before` guard and arming. It proposes through `ToolUseReply` at `:161-194`.
  - `ui/browser/toast.browser-spec.mjs:180-209`: `sendAndConfirm` waits for the reply.
  - Helpers are in `ui/browser/turnprobe-spec.mjs`: `scriptReply` `:151` (its `httpStatus` -1 is a transport failure), `forgetTag`, `armProbeDefinition`, `requireFreeSlot`.
  - `ui/browser/panel-spec.mjs:62` `signedInAt` also resets remembered state, which `browser-reset.mjs` requires.
  - Web-app create input: `Screen/Tool/WebAppCreate.cls:46-100`, with `Name`, `NameSpace`, `AutheEnabled` 32 and the rationale fields from `InputSchema`. `Test/ProposalCreate.cls:430-441` shows the arguments.

## Tasks & Acceptance

**Execution:**

1. `src/OcuPilot/Kernel/Provider/Base.cls`:
   - **`NewRequest`.** `Set tRequest.SocketTimeout = 0`, with a doc sentence stating what 0 means, citing `HttpRequest.cls:451-454` and `:1636`.
   - **`IssueHttpsPost`.**
     - On an error status, set `pStatus` to `+pRequest.HttpResponse.StatusCode` when `$IsObject(pRequest.HttpResponse)` and its `StatusLine '= ""`. Otherwise `pStatus` stays 0.
     - Its doc says `pStatus` is the one meaningful output on error.
   - **`Attempts`.**
     - Add a `tTransportRetried` flag.
     - In the error branch, when all of these hold: the error is not a timeout, `+tStatus = 0`, the call has not retried yet, attempts remain, and the deadline has not passed. Then: log once (`LogRaw`, the status only, code `PROVIDER.TRANSPORT`), wait `DelaySec`, add the wait to the spent delay, and `Continue`.
     - Otherwise the branch behaves as today.
   - **Docs.** Rewrite the class doc `:19-23` and the exits doc `:223-226` to name the one exception, per AD-42.
2. `src/OcuPilot/Kernel/Provider/Retry.cls` -- Class doc `:11-14`: add that a transport failure before a status line is retried once by the base's loop (AD-42).
3. `src/OcuPilot/Test/ProviderStub.cls`:
   - Record `socketTimeout` per call.
   - Add `QueueBrokenAfterStatus(pStatus)`, a kind that answers `$$$ERROR($$$TCPIPError, "<READ>", 0)` with `pStatus` set.
   - Override `NewRequest` to count into `^||OcuPilotProviderStub("newRequests")`, then `##super`. Add a `NewRequests()` reader.
4. `src/OcuPilot/Test/ProviderStubTransport.cls` -- The same `socketTimeout` record and the same new kind, for parity. The class doc names the new kind.
5. `src/OcuPilot/Test/ProviderTransportRetry.cls` -- New, in process and unarmed. It copies `ProviderRetry`'s `Call`/`Settings` driver shape. Tests: the Matrix rows "One break", "Two breaks", "Status line then broken" and "No attempt left" (both legs), plus two more:
   - every family records `socketTimeout` 0, across `ProviderStub`, `OpenAIStub`, `GeminiStub` and `CompatibleStub`;
   - a real `Anthropic` adapter's `IssueHttpsPost` against `http://127.0.0.1:1/` (a refused loopback connect, not a provider) answers an error status with `pStatus` 0.

   The class header says it opens no socket to a provider.
6. `src/OcuPilot/Test/ProviderRetry.cls` -- Remove `TestNoFailedTransportIsEverRetried`'s third leg, which now lives in task 5. Rename the method `TestARaiseAndATimeoutAreNeverRetried` and correct its doc.
7. `src/OcuPilot/Test/TurnProviderFault.cls`:
   - `:168` becomes `Calls` 2: "retried once on a new connection, then the turn stops".
   - Add `TestATurnSurvivesOneBrokenConnection`: script `-1` then `TextReply("recovered")`; the turn ends `completed`, the reply is "recovered", and `Calls` is 2.
   - `RunFailingTurn` gains a trailing `pExpected As %String = "failed"`.
8. `src/OcuPilot/Test/WriteNeverRetried.cls` -- New, in process, driving `ConfirmFixture` + `ProposalFixture` with `Seed` copied from `ProposalConfirm`. It covers the Matrix row "Write fails". Its header states the AD-42 rule it pins.
9. `ui/src/app/core/turn.ts`:
   - `ProposalOutcome` gains `changeAction: ChangeAction` and `changedId: string`, both before `ok`.
   - `NO_OUTCOME` and the refusal literal take `'updated'` and `''`.
   - The ok literal takes `confirmedAction(result.body)` and `textAt(result.body, 'createdId')`.
10. `ui/src/app/shell/panel.ts`:
    - `PanelWriteCard` gains the same two members before `ok`, and `recordWriteCard` copies them.
    - `:981` uses `changeSentenceTemplate(card.changeAction)` with `card.changedId`, falling back to `proposal.target.id` when that is empty. Add the import at `:52`.
    - Replace the doc at `:966-967` with: the action and id are the confirm's own answer, the ones the change event carries.
11. `ui/src/app/shell/panel.spec.ts` -- After `:3467`: cases for `created`, `deleted` and `createdId`, per the Matrix.
12. `ui/tools/turn.test.mjs` -- The outcome carries `changeAction`/`changedId` for the created, absent and unknown-word answers.
13. `ui/browser/create-outcome.browser-spec.mjs` -- New. It follows `proposal-confirm`'s guard and arming, and its target is `/csp/ocupilotprobecreated`, removed in `before` and `after` through `%SYS` `Security.Applications`. It has two tests, both standing on Home:
    - **(AC4)** Propose and confirm a `webapp_list_create`. The last agent reply contains "/csp/ocupilotprobecreated was created" and not "was updated". A toast reads the same sentence, with the Web applications link. The application exists on the instance.
    - **(AC1 end to end)** Script create, then `-1`, then a text reply. The reply renders with no error, exactly one `app-proposal-card` exists, and TurnProvider `Calls` is 3. The card is then canceled.

**Acceptance Criteria:**

- **AC1.** Given a model call whose connection breaks before a status line, when the adapter handles it, then it retries once on a new request, within the attempt and delay budget, and only a second failure stops the turn with `PROVIDER.TRANSPORT`. AD-42 already records this at its origin (amended 2026-09-25); the spine is not edited again.
- **AC2.** Given any provider call, when its request is built, then `SocketTimeout` is 0.
- **AC3.** Given CI calls no live provider, when the suite runs, then:
  - a first-connection break proves the retry succeeds (tasks 5 and 7);
  - a double break proves the stop with `PROVIDER.TRANSPORT` (tasks 5 and 7);
  - `WriteNeverRetried` proves no write is re-sent.
- **AC4.** Given a confirmed proposal from a tool declaring `created`, when the panel and the toast report it, then both read "<entity> was created". Task 13 pins this end to end for a web-application create.

## Spec Change Log

## Review Triage Log

### 2026-09-25 — Review pass

- verdicts: 16 findings — high 0, medium 5, low 3, false 8, maybe-false 0
- findings:
  - `medium` `patch` VG: `IssueHttpsPost`'s new status-line branch never ran against the shipped method (the stub sets `pStatus` itself; the refused connect has no `HttpResponse`) — added `Test/BrokenReadRequest.cls` (a `%Net.HttpRequest` whose `Post` builds the response and answers `#6097`) and `TestABrokenReadIsClassifiedByItsStatusLine` over both shapes; mutation run 322.
  - `medium` `patch` VG: the transport retry's share of the delay budget was untested — added `TestATransportRetrySharesTheDelayBudget` (429-then-break waits `30|0`; break-then-429 waits sum to the budget); mutations runs 323, 324.
  - `medium` `patch` VG: nothing pinned that the retried request still carries the key (AD-35) — added a `keySha` assertion on call 2 to `TestATurnSurvivesOneBrokenConnection`; mutation run 325.
  - `low` `patch` VG other: `ProviderStubTransport`'s `brokenafterstatus` branch never ran — `TestABreakAfterAStatusLineIsNotRetried` now loops the four family stubs.
  - `medium` `patch` IA: the slot C shape (a read that broke before a status line) is not driven through the shipped transport — same root cause as the first row; the `BrokenReadRequest` empty-status-line leg covers it.
  - `medium` `patch` IA: status line then broken is covered only by a stub — same root cause as the first row.
  - `low` `reject` IA: the `SocketTimeout` comment implies more effect than it has — the comment states a guarantee that holds; Design Notes already record that one request per attempt means no reuse today. Cosmetic.
  - `false` `reject` IA: Test connection tested through stub settings, not its route — `AgentConnectionBound.TestTheChildMakesOneAttempt` pins the route (run 78, green).
  - `false` `reject` IA: the browser break lands on the second model call, not in the matrix — task 13 prescribes exactly that script.
  - `false` `reject` IA: "answers no HTTP" modeled as `ArmWriteFault(0)` — that is the fixture's no-HTTP answer, as the Code Map names.
  - `false` `reject` IA: updated and no-action checked at the outcome, not the panel reply — the Story 5.7 panel case asserts "was updated" with no action, and an explicit `updated` yields the same outcome value (turn.test.mjs legs).
  - `low` `reject` IA: a break just before the 300 s deadline whose ≤1 s wait crosses it ends `PROVIDER.TIMEOUT` — the deadline has then passed, which is what TIMEOUT reports; the fix would add a guard for a sub-second window.
  - `false` `reject` IA: with the delay budget spent the transport retry still goes after a 0 s wait — the intent gates it on attempts and deadline only, with the wait cut to the remaining budget.
  - `false` `reject` IA: the retry consumes an attempt — the intent's `tAttempt < tMaxAttempts` clause makes it so.
  - `false` `reject` IA: key clearing after a retried call is not pinned — `Invoke` clears `ApiKey` on every exit after `Attempts` returns (`Base.cls:206,215,220`); the retry returns through the same exits.
  - `false` `reject` IA: the panel's id fallback differs from the change event's — `targetOf(id)` finds the same proposal by id and returns its `target` (`turn.ts:1187`).

## Design Notes

**Governing ADs.**

- AD-42, as amended 2026-09-25: the retry rule, `SocketTimeout` 0, and never retrying a write.
- AD-35: the key through the retry.
- AD-14: one sentence per action; the id is the entity's own.
- AD-15: the marker sentence beside it, unchanged.
- AD-53/54/55: both callers share `Operation.ApplyAt`; a create's action and `createdId`.
- AD-24: the retry re-sends the body `CallMessages` rebuilds from the same `pMessages` (`Base.cls:278`), so it carries the same capped context.
- AD-31: a broken attempt returns no usage, so the token budget is not charged twice.
- AD-39: no new code or reason.
- AD-19: `turn.ts` stays framework-free.

**The owner's keep-alive inference, checked against the code.**

- A socket is reused only when the same request object issues a second request (`HttpRequest.cls:1634-1655`).
- OcuPilot builds one request per attempt (`Base.cls:277`) and releases it after the attempt (`:292`), and `%OnClose` closes its device (`:98-111`). The adapter lives for one call (`ProviderPort.cls:341,351`).
- So at HEAD no provider request reuses a kept-open socket. Slot C's `<READ>` was a fresh connection dropped before its status line, by the provider or the network (inference: from the code, not observed live).
- The retry is the fix. `SocketTimeout` 0 keeps a second request on one object off an idle socket if one is ever issued.
- `SocketTimeout` 0 does not close the socket after the response (`:1509-1518` closes only on HTTP/1.0 or `Connection: close`); releasing the object does.

**Test connection takes no retry.** AD-42's exception covers a model call, and Test connection is one, but it runs with `maxAttempts` 1 (`Definitions.cls:891`). The retry must fit inside the attempt budget, so none is left for it. Its job is also to report what the endpoint does; a hidden second try would mask a flaky endpoint at setup, and would spend the 10.5 wall-clock bound. `AgentConnectionBound.TestTheChildMakesOneAttempt` stays green.

**Classification.** A connect refusal, a TLS failure and a `<READ>`/`<DISCONNECT>` before the status line each answer `pStatus` 0, so each is retried once, bounded. A timeout already spent its per-call timeout, so it stays unretried.

**The created fault.**

- The server is correct. The tool declares its action (`WebAppCreate.cls:58`), the confirm returns it (`Confirm.cls:427` → `:765` `pResult.%Set("action", ...)`), and `turn.ts:1096-1102` publishes it.
- The toast is correct (`toasts.ts:86-90`).
- The only wrong line is `panel.ts:981`, which hardcodes `tableChangeUpdated`, because `ProposalOutcome` and `PanelWriteCard` drop the action.
- The fix also makes a confirmed delete read "was deleted", and a task create name its allocated id, as the toast already does.
- If the owner saw "updated" in a toast, that toast came from another build (inference).

**The create inference, verified.**

- 10 tools declare `CREATES = 1`: `AuditUserEventCreate`, `DeviceCreate`, `ResourceCreate`, `RoleCreate`, `SslCreate`, `TaskCreate`, `UserCreate`, `WalletSecretCreate`, `WebAppCreate`, `X509Import`.
- Exactly those 10 declare `CHANGEACTION = "created"`. No other tool declares it, and no subclass inherits `CREATES` from them.
- The source parameter lines and `%Dictionary.CompiledParameter` on `ocupilot-b-ci` agree class for class.
- The 48 tools split into 10 created, 15 deleted and 23 updated.

**Contended edits.**

- `origin/OCU-1-epic12` adds `continues` after `auditMarked` in `turn.ts` (`:85`, `:316`, `:1072`, `:1110`) and in `panel.ts` (`:150`, `:1183`). It also adds `replyWithStillRunningSentence` and a case at `panel.spec.ts:3382-3425`. This story's members go before `ok`, and it does not touch `turn.ts:1078-1103`.
- None of Epic 12's hunks changes `panel.ts:981`, `:52` or `:966-967`.
- `origin/OCU-1-epic15` does not change `toasts.ts`, `navigation.ts`, `turn.ts` or the panel.
- So nothing changes another branch's hunk, and there is no intent gap.

**Footprint extensions:**

- Provider tests: `Test/ProviderRetry.cls`, `Test/TurnProviderFault.cls`, `Test/ProviderStub.cls`, `Test/ProviderStubTransport.cls`.
- Client: `ui/src/app/core/turn.ts` and `ui/src/app/shell/panel.ts` (contended, placed beside Epic 12's lines as above), `ui/src/app/shell/panel.spec.ts`, `ui/tools/turn.test.mjs`.
- New files: `Test/ProviderTransportRetry.cls`, `Test/WriteNeverRetried.cls`, `ui/browser/create-outcome.browser-spec.mjs`.
- Nothing shared-append.

**Integration ACs.** This story adds no service. Existing consumers are pinned at their surfaces: `Kernel.Agent.Loop` through a real turn job (task 7), and the panel and toast through the browser (task 13).

**Consumes:**

- Story 4.8: `TurnProvider` and `TurnProviderFault`.
- Story 5.7: the change sentence and the toast.
- Story 8.1: `webapp.list.create`.
- Story 10.5: `TestCall`'s single attempt.

**Consumed-by:**

- Story 17.7: the owner's live check of turns on each default model.
- Story 11.7: streaming must keep the never-retry-writes rule.

**Ledger inbox:** none. DW-1423, the table's live-region announcement, is a different surface and is not claimed.

## Verification

**Slot and instance.**

- Slot B. Every IRIS MCP call carries `server: "ocupilot-slot-b"`.
- Every stateful check runs on the throwaway `ocupilot-b-ci` (52777/1976), which the runner has brought up; never on slot B's dev instance.
- Do not run `ci-throwaway.sh up` or `down`.
- Never touch `ocupilot`, any `ocupilot-slot-*` container, or `ocupilot-ci`.
- No live provider and no key.

**Loading code.** Refresh the copy with `cp -R src/. /tmp/ocupilot-b-ci/src/`, then run `docker exec ocupilot-b-ci iris session iris -U HSCUSTOM` with `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck",,1)` and `$System.OBJ.CompilePackage("OcuPilot","ck")`.

**Commands:**

- `uv run scripts/check-objectscript.py && uv run scripts/test_check_objectscript.py` -- expected: 0 problems.
- `bash scripts/lint-docs.sh` -- expected: clean.
- **(loop)** `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class <Class>`.
  - One class per invocation, one invocation per message, never re-submitted after a client-side timeout. Confirm totals with the `%UnitTest_Result` probe.
  - Classes: `OcuPilot.Test.ProviderTransportRetry`, `WriteNeverRetried`, `ProviderRetry`, `TurnProviderFault`, `Provider`, `ProviderConsumer`, `OpenAIAdapter`, `GeminiAdapter`, `CompatibleAdapter`, `Egress`, `AgentConnection`, `AgentConnectionBound`, `ProposalConfirm`, `AuditMarker`, `ProposalCreate`.
  - expected: 0 failed.
- **(loop)** `cd ui && npm run test:tools && npm run test:components` -- expected: green.
- **(loop)** Build and redeploy, then run the spec:
  - `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`
  - `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/create-outcome.browser-spec.mjs`
  - expected: 2/2.
  - The full browser suite is CI's `browser` job.
- **(once, before dev_complete)** The full ObjectScript sweep: every `%UnitTest.TestCase` under `src/OcuPilot/Test`, one class at a time on `ocupilot-b-ci`. Then `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`. Zero executed checks is a failure.

**Pinning mutations (Rule 19).** For each one: apply it, recompile the package (or rebuild and redeploy for client code), observe red, revert, and confirm `git status --short` and `git diff --stat` are unchanged. The implement stage records the run beside each line.

- AC1: remove the transport-retry branch in `Attempts` → "One break" and `TestATurnSurvivesOneBrokenConnection` go red.
  - mutation: deleted the retry block in `Base.Attempts` → `ProviderTransportRetry` run 16 red (`TestOneBreakIsRetriedOnANewRequest`, `TestTwoBreaksStopTheCall`), `TurnProviderFault` run 17 red (`TestATurnSurvivesOneBrokenConnection`, `TestATransportFailureFailsTheTurnAtItsProviderStep`), browser AC1 red.
- AC1, once only: drop the `tTransportRetried` guard → "Two breaks" goes red (3 calls).
  - mutation: removed `'tTransportRetried` from the retry condition → run 18 red, `TestTwoBreaksStopTheCall` ("retried once and only once").
- AC1, the classification: retry on any non-timeout error, ignoring `pStatus` → "Status line then broken" goes red.
  - mutation: removed `(+tStatus = 0)` from the retry condition → run 19 red, `TestABreakAfterAStatusLineIsNotRetried`.
- AC1, the budget: drop `tAttempt < tMaxAttempts` → the "No attempt left" row goes red.
  - mutation: removed `(tAttempt < tMaxAttempts)` → run 20 red, `TestABreakWithNoAttemptLeftIsNotRetried` (a wait recorded). Also removed the deadline test → run 21 red, same method (`PROVIDER.TIMEOUT`, 504).
- AC1, a new request: build one request before the loop and reuse it → the `NewRequests` assertion goes red.
  - mutation: one `NewRequest` before the loop, reused per attempt → run 22 red, `TestOneBreakIsRetriedOnANewRequest` ("on two request objects").
- AC1, the real classification: delete the status-line block in `IssueHttpsPost` → `TestABrokenReadIsClassifiedByItsStatusLine` goes red.
  - mutation: deleted the `$IsObject(pRequest.HttpResponse) && (StatusLine '= "")` block → run 322 red, the after-a-status-line leg (`pStatus` 0).
- AC1, the delay budget: pass `""` for the remaining budget in the transport branch; drop its spent-delay increment → `TestATransportRetrySharesTheDelayBudget` goes red.
  - mutation: `DelaySec(tAttempt, "", "")` → run 323 red, leg "429 then a break" (waits not `30|0`). Dropped `Set tSpentDelay = tSpentDelay + tDelay` in the transport branch → run 324 red, leg "a break then 429" (`.6|30`); this leg reddens only when the first backoff draw is non-zero.
- AC1, the key (AD-35): clear `..ApiKey` in the transport branch before `Continue` → `TestATurnSurvivesOneBrokenConnection` key assertion goes red.
  - mutation: `Set ..ApiKey = ""` beside `Set tTransportRetried = 1` → run 325 red, "the retried request carried the stored key". `Base.cls` restored byte-identical; runs 326-328 green.
- AC2: delete the `SocketTimeout` line → the four-family leg goes red (115).
  - mutation: deleted `Set tRequest.SocketTimeout = 0` → run 23 red, `TestEveryFamilyDisablesKeepAlive` (all four stubs) and `TestARefusedConnectAnswersNoStatus`.
- AC3, writes: in `Operation.ApplyAt`, re-invoke the port once when the first call errors or raises → `WriteNeverRetried` goes red (`WriteCount` 2).
  - mutation: `ApplyAt` re-invoked the port after an error or a raise → run 24 red, both methods, every leg; `Kernel/Proposal/**` restored byte-identical (`git diff --quiet`).
- AC4, the panel: revert `:981` to `STRINGS.tableChangeUpdated` → the `panel.spec.ts` created case and browser test 1's panel assertion go red.
  - mutation: `STRINGS.tableChangeUpdated` in `replyWithChangeSentence` → `panel.spec.ts` three Story 10.6 cases red; rebuilt and redeployed, browser AC4 red on the reply ("was updated"). Dropping `changedId` alone → the createdId case red. `changeAction: 'updated'` in `turn.ts`'s ok literal → the new `turn.test.mjs` case red.
- AC4, the toast: make `changeSentenceTemplate` return updated for created → browser test 1's toast assertion goes red.
  - mutation: `created` answered `tableChangeUpdated` in `toasts.ts`, rebuilt and redeployed → browser AC4 red on "the toast reads the create"; `toasts.ts` restored byte-identical.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** `Base.Attempts` retries a model call once, on a new request, when `IssueHttpsPost` failed with no status line (`pStatus` 0), inside the attempt count, deadline and delay budget (AD-42); `IssueHttpsPost` now reports the status code when a status line arrived before the break; `NewRequest` sets `SocketTimeout` 0. The panel's change sentence takes the confirm's own `action` and `createdId` through `ProposalOutcome` and `PanelWriteCard`, so a confirmed create reads "was created".

**Files.**

- `src/OcuPilot/Kernel/Provider/Base.cls` -- the retry branch, the status-line classification, `SocketTimeout` 0, docs.
- `src/OcuPilot/Kernel/Provider/Retry.cls` -- class doc names the one transport retry.
- `src/OcuPilot/Test/ProviderTransportRetry.cls` -- new: the matrix's adapter rows, four-family `SocketTimeout`, real-method classification, delay budget.
- `src/OcuPilot/Test/BrokenReadRequest.cls` -- new: a `%Net.HttpRequest` stand-in for a read that broke before or after its status line.
- `src/OcuPilot/Test/WriteNeverRetried.cls` -- new: confirm and screen writes reach the port once; a second confirm is `BURNED`.
- `src/OcuPilot/Test/ProviderStub.cls`, `ProviderStubTransport.cls` -- `socketTimeout` record, `QueueBrokenAfterStatus`, `NewRequests`.
- `src/OcuPilot/Test/ProviderRetry.cls` -- transport leg moved out; method renamed.
- `src/OcuPilot/Test/TurnProviderFault.cls` -- break twice is 2 calls; a turn survives one break and the retry carries the key.
- `ui/src/app/core/turn.ts`, `ui/src/app/shell/panel.ts` -- `changeAction`/`changedId` before `ok`; sentence from `changeSentenceTemplate`.
- `ui/src/app/shell/panel.spec.ts`, `ui/tools/turn.test.mjs` -- created/deleted/createdId cases; outcome legs.
- `ui/browser/create-outcome.browser-spec.mjs` -- new: AC4 end to end, and AC1 with a break after a proposal.

**Review.** 16 findings (verification-gap 4, intent-alignment 12): 6 patched (5 medium in 3 root causes, 1 low), 10 rejected with reasons in the Review Triage Log, 0 deferred. Patched by verdict: medium 5, low 1. Blind and edge-case layers are disabled in this project's toml.

**Follow-up review recommended: true.** Two or more medium entries were patched. The unverified risk: that a real `<READ>` before a status line over TLS answers `pStatus` 0 rests on reading `%Net.HttpRequest` (`:1498-1502`, `:2123-2130`) and on the `BrokenReadRequest` stand-in, not on a live socket (inference); the owner's live check is Story 17.7.

**Verification (all on `ocupilot-b-ci`, slot B).**

- `check-objectscript.py` 0 problems (823 files); `test_check_objectscript.py` 130 OK; `lint-docs.sh` 0 issues.
- Client: `test:tools` 1408/1408, and `turn.test.mjs` 59/59 again after two legs were added to its Story 10.6 case; `test:components` 1223/1223 in 93 files; `npm run build` green.
- Browser: `create-outcome.browser-spec.mjs` 2/2 after rebuild and `docker cp` redeploy. The full browser suite is CI's `browser` job.
- Full ObjectScript sweep, one class at a time: 250 classes, 2171 tests, 0 failed, runs 70-319, confirmed by the `%UnitTest_Result` probe (T=2171 P=2171 F=0 C=250). After review patches (test-only; `Base.cls` byte-identical to the swept code): `ProviderTransportRetry` 8/8 run 328, `TurnProviderFault` 5/5 run 327.
- Smoke: `smoke.sh --container ocupilot-b-ci` executed=49 passed=49 failed=0.
- Mutations: every line in `## Verification` applied, observed red, reverted; tree byte-identical after each.

**Residual risks.** The break-then-429 budget mutation reddens only on a non-zero first backoff draw (10 in 11). The handoff subagent returned once with an interim line while its background sweep was still running; that sweep died with it at run 69 (no run in flight, no writer left, tree quiescent), and the stage re-ran the full sweep itself.
