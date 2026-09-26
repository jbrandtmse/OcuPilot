---
title: 'The turn runs in a background job and returns immediately'
type: 'feature'
created: '2026-09-16'
status: 'done'
baseline_revision: 'a7a1802c14a9da22f24afd85521c5a6beb98a229'
baseline_commit: 'a7a1802c14a9da22f24afd85521c5a6beb98a229'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings:
  - multiple-goals
  - oversized
deferred:
  - summary: >-
      AD-31 says the poll lease covers disablement and, in the same rule, that it does not; AD-7 still places progress in a temp global, and epics.md Story 4.1 still says the lease covers a disabled account.
    evidence: |-
      ARCHITECTURE-SPINE.md AD-31 Rule ("disablement is covered by a poll lease" vs "the lease does not cover disablement"); AD-7 Rule ("a temp global keyed by turn id") vs AD-33 and Kernel.State.Step; epics.md:2698. The 2026-09-16 probe in the spec's Design Notes shows the instance answers a disabled account's Bearer poll.
    location: >-
      _bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md AD-31, AD-7; _bmad-output/planning-artifacts/epics.md:2698
    severity: medium
  - summary: >-
      CLAUDE.md still says check-objectscript.py has 18 rules; Story 4.1 added the nineteenth (the turn job's reach).
    evidence: |-
      CLAUDE.md "Running and verifying" says 18 rules; the checker now prints "over 19 rule(s)".
    location: >-
      CLAUDE.md:132
    severity: low
---

<intent-contract>

## Intent

**Problem:** OcuPilot cannot run a turn yet. The turn is the first server path that sends a stored key on every call, runs longer than the stock 60-second Web Gateway response timeout, and acts for a user whose privileges can change while it runs.

**Approach:** `POST /api/ocupilot/turn` reserves the caller's one turn slot, spawns a job outside any escalated frame with every starting value passed in, and answers 202 with an opaque turn id. The job runs a bounded provider loop. Between steps it re-checks the stop flag, the switches and the user's current grants. It writes capped progress records that the owner polls through `GET /api/ocupilot/turn/{id}/progress`.

## Boundaries & Constraints

**Always:**

- No request is held for the length of a turn. The job changes nothing on the instance and writes only OcuPilot's own state: the turn row, its steps, and the provider port's own bookkeeping (AD-7).
- The job is spawned from the handler frame after every escalated read has returned. The turn key, user, definition id, namespace, message and switch snapshot go in as `JOB` arguments (AD-9).
- A provider call receives either the built-in system prompt (a build-time constant) or, when the definition has one, its administrator-written override in its place. Nothing is ever concatenated into either (AD-11, DW-333).
- Provider faults stay distinct: `PROVIDER.CREDENTIALSTORE` fails the turn and leaves the definition enabled. `PROVIDER.CREDENTIAL` fails it, and the port disables the definition (Story 4.0).
- Progress is untrusted data. It is stored in OcuPilot's protected database, owned by the starter, capped, and deleted with its turn. A poll for a turn the caller does not own answers exactly like an unknown id (AD-33).
- One error envelope, one response writer, bound SQL, `%EXACT` on user names and turn keys (AD-12/39, AD-21).
- Test provider calls never leave the container. No test records a key, only its SHA-256 (AD-35).
- The limits are named constants in one place until Story 14.6 makes them settings (AD-31): wall-clock 600 s, iterations min(definition maximum, 100), provider tokens 500,000, poll lease 120 s, progress retention 15 minutes after the end, message 16,000 characters.

**Never:**

- Spawn from, or call a port or provider from, an escalated frame. Put `JOB` anywhere but `Kernel/Agent/Job.cls`.
- Read `%SYS` security state from the job, or add any elevation beyond AD-9's.
- Make a turn tool call reach an instance surface. 4.1 advertises no tools, and an unsolicited `tool_use` gets a fixed error result.
- Change the Web Gateway configuration, or run an armed or job-spawning class on the live `ocupilot` instance.
- Build the client panel, a stop route, context capture or the ledger (Stories 4.3 through 4.9).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Start | Authenticated caller past the router gates. An enabled default definition exists, no kill switch or hold applies, and the caller has no turn queued or running. `POST /turn {"message":"..."}` | 202 `{"turnId":"<opaque>"}`. A job runs the turn | No error expected |
| Body | Not a JSON object; `message` missing, not a string, blank, or over 16,000 characters | 400 `TURN.BADBODY`, or 422 with a violation on `message` (`TURN.MESSAGE.REQUIRED`, `TURN.MESSAGE.LENGTH`) | Nothing reserved, no job |
| Refused start | No enabled default / instance kill switch / hold on the caller | 503 `PROVIDER.UNCONFIGURED` / 403 `AGENT.KILLSWITCH.GLOBAL` / 403 `AGENT.KILLSWITCH.USER` | Nothing reserved |
| Busy | Caller already has a queued or running turn. Also: two POSTs at once | 409 `TURN.BUSY`, reason "A turn is in progress. Wait for it to finish before sending another message." Of two concurrent POSTs, exactly one gets 202 | No second row or job |
| Poll | The owner calls `GET /turn/{id}/progress` | 200 `{turnId, state, startedAt, endedAt, iterations, tokens{input,output}, limit, steps[{seq, kind, name, status, summary, text, code, truncated}], stepsDropped, reply, error{seq, code, reason}}`. `state` is one of queued/running/completed/stopped/abandoned/failed | No error expected |
| Not yours | Another user's turn id, or an unknown id | 404 `TURN.NOTFOUND`, with the same body in both cases | Never 403 |
| Over 60 s | The stub holds its one call for 70 s | POST answers in under 5 s. Every poll answers in under 5 s. The turn reaches `completed`, and `endedAt - startedAt` is at least 70 s. The container's `Server_Response_Timeout` reads 60 | No error expected |
| Identity | A turn is started by an armed least-privileged principal | The provider call observes `$USERNAME` = that principal, and a `$ROLES` without `%DB_OCUPILOT` | No error expected |
| Boundary re-checks | Between steps: the stop flag is set; the kill switch or a hold goes on; enforced read-only differs from the snapshot; `CheckUserPermission($USERNAME, …)` answers 0 for every router admin resource (revoked, or user deleted) | At the next boundary, with no further provider call: `stopped` `TURN.STOPPED` / `stopped` `AGENT.KILLSWITCH.*` / `abandoned` `TURN.ABANDONED.READONLY` / `abandoned` `TURN.ABANDONED.PRIVILEGE` | No error expected |
| Lease | The turn is running and no authenticated poll by its owner has renewed it for 120 s (tab closed, stopped polling, or the account disabled and its poll refused) | At the next boundary, with no further provider call: `abandoned` `TURN.ABANDONED.LEASE` | No error expected |
| Disabled user (probe) | Armed principal starts a turn; the account is disabled while the turn runs; a Bearer poll is sent | Planning probes on the slot-A throwaway whether the instance refuses the disabled account's poll. Refused: the lease row above covers disablement. Answered: disablement is bounded only by the 600 s wall-clock limit, the Design Notes record the probe, and the Auto Run Result says so for the lead | No error expected |
| Sign-out | The owner, with running or queued turns, sends `POST /api/ocupilot/turn/abandon`; `ui/src/app/core/session.ts` `signOut()` sends it before `/logout`, best-effort | 200 with the count abandoned. Every such turn reaches `abandoned` `TURN.ABANDONED.SIGNOUT` at its next boundary; another user's turns are untouched | A failed abandon never blocks the sign-out |
| Bounds | Iterations reach min(the definition's `MaxIterationsPerTurn`, 100) / elapsed time reaches 600 s / input plus output tokens reach 500,000 | `completed` with the harvested fallback reply and `limit:"iterations"` / `abandoned` `TURN.LIMIT.DURATION` / `abandoned` `TURN.LIMIT.TOKENS` | No error expected |
| Provider fault | Invoke answers `PROVIDER.CREDENTIALSTORE`, `PROVIDER.CREDENTIAL`, or any other `PROVIDER.*` | `failed`, with `error.seq` naming the model step and `error.code` the fault. The definition stays enabled for CREDENTIALSTORE and is disabled for CREDENTIAL | Never an exception to the client |
| Job lost | The turn is running, or queued for more than 10 s, and no live process holds the user's slot | The next reserve or poll marks it `abandoned` `TURN.ABANDONED.JOBLOST` and frees the slot | No error expected |
| Progress caps | More than 100 steps; a summary over 1,000 characters or a text over 131,072 | Steps past 100 are counted in `stepsDropped`. A field is cut at its cap and `truncated` is true | No error expected |
| Retention | A terminal turn ended 15 minutes or more ago | The next reserve by any user deletes the turn and its steps. A poll then answers 404 | No error expected |
| Integration, DW-347 (consumer: the turn job, through `ProviderPort.Invoke`) | Armed: a `turnprobe` definition is created, its key stored, and the definition enabled and made default, all over the wire. Then a turn is posted | The stub's recorded SHA-256 of the key header equals that of the posted key | No error expected |
| Prompt, DW-333 | The definition's override is empty / non-empty | The provider receives the built-in prompt / exactly the override, never both | No error expected |
| Body UTF-8, DW-23 | The posted message contains U+00E9 and U+4E2D | The provider receives both characters intact | No error expected |

</intent-contract>

## Code Map

- `src/OcuPilot/Api/Router.cls` -- UrlMap :66-90 (the checker's route-ordering rule ~:1538 decides placement), thin wrappers :93-268, `OnPreDispatch` :402-474 (install gate, `IsAuthenticatedPrincipal`, `HoldsAdminResource` :300, `Kernel.Scope`). `ADMINRESOURCES` :44 is the list the handler passes the job for its grants check.
- `src/OcuPilot/Api/Error.cls` -- 12 closed slugs :20-54, `Render` :790, code parameters (`PROVIDERUNCONFIGURED` :194, `AGENTKILLSWITCH*` :562-565), `ReasonForViolation` :620, `ViolationCodes` :657, `ReasonForRestraint` :574.
- `src/OcuPilot/Api/Definitions.cls` -- the handler pattern to copy: `HandleCreate` :299, `BodyIsReadable` :1225, `RenderNotFound` :1199.
- `src/OcuPilot/Api/Response.cls` -- `JSONStatus(pStatus, pData)` :25.
- `src/OcuPilot/Kernel/Utils.cls` -- `ReadRequestBody` :366 (reads `GetMimeData("BODY")`, else `Content`; no size cap). The header :14-21 wrongly says no production caller exists; Definitions and Switches already call it.
- `src/OcuPilot/Kernel/State/Base.cls` -- escalation golden example :6-25, `APPLICATION` :48, guarded save :105/:140 (`STATE.CONFLICT` on a stale version, never a retry), `GuardedProbeSet` :256 (the scalar-global idiom, test-only today), `GuardedOpenOneWhere*` :380-468, `GuardedIdsWhere` :500. `OcuPilot*` globals map to OCUPILOT (`Installer.EnsureMapping` :2676; probed for `^OcuPilotTurnSignal` and `^OcuPilotTurnSlot`), and new tables get SQL grants from the dictionary (`StateTables` :3091). `Test/State.cls` :425 covers new subclasses automatically.
- `src/OcuPilot/Kernel/State/Hold.cls` -- the closest per-user row shape (`GuardedForUser` :36, `GuardedCreate` :80).
- `src/OcuPilot/Kernel/State/Agent.cls` -- `ResolveDefault` :548, `MaxIterationsPerTurn` :88, `SystemPromptOverride` :92.
- `src/OcuPilot/Kernel/Restraint.cls` -- `Resolved(user, .v)` :174, re-read on each call (`killSwitch`, `killSwitchAudience`, `enforcedReadOnly`, `code`). `check_restraint_containment` (checker ~:755) forbids naming an `AGENT.KILLSWITCH.*` code outside it, so the loop records `v("code")`.
- `src/OcuPilot/Port/ProviderPort.cls` -- `Invoke(defId, .messages, .tools, system, .response, .http, .fault)` :77, always `$$$OK`, passes `system` to `Dispatch` unchanged. `ValuesFor` :305-329 carries the override at :325 and nothing reads it. Current callers pass `""` (`Test/ProviderConsumer` :214, `Test/ProviderPort` :103). Disables only on CREDENTIAL :129-135.
- `src/OcuPilot/Kernel/Provider/Anthropic.cls` -- `CallMessages` :38-77 (content is a plain string today; `system` sent only when non-empty), `ApplyAuth` :84-88, `MapResponse` :106-144 (`ToolCallsJson`, usage).
- `src/OcuPilot/Kernel/Provider/Catalog.cls` -- `Providers` XData :48-52, `Table` :59, `Row` :106. `Base.IssueHttpsPost` :316 is the stub override point.
- `scripts/check-objectscript.py` -- `check_handler_wire_tests` :1314 keys a route by substring and ignores the method (:1332-1343). `check_state_package_isolation` :773 (no `JOB`, no re-entry under `Kernel/State/`). Harness: `scripts/test_check_objectscript.py` `TestHandlerWireTestRule` :650.
- `src/OcuPilot/Test/Dispatch.cls` :79-85 -- seeds the body with `InsertMimeData` (`[Final, Internal]`, `irislib/%CSP/Request.cls` :637). `Content` :71 is a public property.
- `src/OcuPilot/Test/Http.cls` -- `AbsoluteRequest` :206, localhost:52773 (through Apache and the Web Gateway), default client timeout 30 s.
- Patterns: `Test/AgentWireSecurity.cls` :59-156 (armed principal), `Test/ProviderStub.cls` :187-237 (in-process stub, `^||` state that never crosses into a job), `Test/ProviderPortProbe.cls`, `Test/CatalogAnthropicStub.cls`, `Test/CredentialFixture.cls`, `Test/AgentCredential.cls` :106-142 (key POST).
- `scripts/ci-throwaway.sh` :147-195 -- the armed environment block. `ui/tools/ci.test.mjs` pins no `OCUPILOT_ALLOW_*` name, so only the script changes.
- `ui/src/app/core/session.ts` -- path constants :33-36; `schedule` option :118, defaulted :401-404; `signOut()` :660-685 clears the tab first, then posts `/logout` with the Bearer and `credentials: 'include'`, reading no outcome (DW-5).
- `ui/tools/session.test.mjs` :905-1048 -- the sign-out tests (throw, 401, never settles) the abandon request must keep green.
- Vendor evidence, read-only: harvest `iris-session-agent.md` l.72-74 (10-step flow, `BuildMaxIterFallback`), l.87 (schema subset). `EXPERIENCE.md` l.278-280 (fixed strings).

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Kernel/Agent/Limits.cls` (new) -- every number the turn obeys, as parameters: AD-31's six (600 s, 100 iterations, 500,000 tokens, 120 s lease, 900 s retention, 16,000 characters), plus the progress caps (100 steps, 1,000 and 131,072 characters) and the 10 s queued threshold. Nothing else spells them.
- `src/OcuPilot/Api/Error.cls` -- `TURN.BADBODY`, `TURN.MESSAGE.REQUIRED`, `TURN.MESSAGE.LENGTH`, `TURN.BUSY`, `TURN.NOTFOUND`, `TURN.UNAVAILABLE`, `TURN.STOPPED`, `TURN.ABANDONED.READONLY`, `TURN.ABANDONED.PRIVILEGE`, `TURN.ABANDONED.LEASE`, `TURN.ABANDONED.SIGNOUT`, `TURN.ABANDONED.JOBLOST`, `TURN.LIMIT.DURATION`, `TURN.LIMIT.TOKENS`, each with its sentence written once.
- `src/OcuPilot/Kernel/State/Turn.cls` (new, 26 chars) -- the turn row: `TurnKey` (opaque, unique), `UserName`, `DefinitionId`, `State`, `Code`, `QueuedAt`, `StartedAt`, `EndedAt`, `Iterations`, `InputTokens`, `OutputTokens`, `LimitHit`, `StepsDropped`, `JobId`. After `GuardedBegin` the job is its only writer. Guarded methods:
  - `GuardedReserve`: takes `Lock +^OcuPilotTurnSlot(user):0`, reconciles lost jobs, refuses busy, inserts a `queued` row, sets the lease to now, sweeps turns past retention with their steps and signals, and releases the lock.
  - `GuardedBegin`: the job takes the slot lock with a 10 s wait, conditional on the row still reading `queued`, and holds the lock for its life. `GuardedFinish` records the terminal state and releases it.
  - Signals, as scalar nodes `^OcuPilotTurnSignal(key, "renewed"|"stop"|"abandon")` set and read only inside these frames: `GuardedRenew(key)`, `GuardedRequestStop(key, user)`, `GuardedAbandonForUser(user, .count)` (every queued or running turn of that user, `%EXACT` on the name), `GuardedSignals(key, .stop, .abandon, .renewedAt)`.
  - `GuardedForOwner(key, user)` and the poll's reconcile.
  No `JOB` and no port calls (checker :773).
- `src/OcuPilot/Kernel/State/Step.cls` (new, 26 chars) -- one row per progress record, keyed by `TurnKey` plus `Seq`, with caps applied on write. It is deleted with its turn.
- `src/OcuPilot/Kernel/Agent/Prompt.cls` (new) -- `Builtin()`, the built-in system prompt as a compiled constant. Its wording is not an AC.
- `src/OcuPilot/Port/ProviderPort.cls` -- `Invoke` sends the definition's `systemPromptOverride` (after `$Char(0)` normalization), when non-empty, in place of `pSystemPrompt`, whole; otherwise `pSystemPrompt`. `InvokeDraft` is unchanged -- DW-333.
- `src/OcuPilot/Kernel/Provider/Anthropic.cls` -- when `pMessages(n,"blocks")` holds a JSON array, send it as `content`. Plain strings are unchanged.
- `src/OcuPilot/Kernel/Agent/Loop.cls` (new) -- the harvested flow rewritten for the job:
  - Every limit comes through `..LimitsClass()` (default `Kernel.Agent.Limits`); the iteration cap is min(the definition's maximum, the limit).
  - Before each model call, the boundary runs in this order: stop, sign-out, switches (`Restraint.Resolved`, recording its `code`), read-only against the snapshot, grants (`$SYSTEM.Security.CheckUserPermission(user, r, "USE")` over the passed resource list, 0 for all is `TURN.ABANDONED.PRIVILEGE`), lease (now minus `renewedAt` at or past the limit), time, tokens.
  - A model step goes through `..PortClass()`, `ProviderPort` by default, with `Prompt.Builtin()` as the system prompt.
  - A `tool_use` answer is echoed back as assistant blocks, with one `tool_result` per call (`is_error`, content `{"code":"TOOL.UNAVAILABLE"}`) through the `..DispatchTools` seam 4.2 replaces.
  - Progress steps are written as the loop runs, and the fallback reply is used at the iteration cap.
- `src/OcuPilot/Kernel/Agent/Job.cls` (new) -- `Start(values, .key)`, called from the handler frame (`JOB …::5`; a failed spawn finishes the turn `failed` `TURN.UNAVAILABLE`), and `Run(...)`, the job entry point. `Run` asserts `$USERNAME` equals the passed user, begins, runs the loop, and finishes on every exit path, the outer Catch included.
- `src/OcuPilot/Api/Turn.cls` (new):
  - `HandleStart`: body via `Kernel.Utils.ReadRequestBody`, validation, `Restraint.Resolved`, `Agent.ResolveDefault`, reserve, then `Job.Start` from this unescalated frame with the values and `Router.#ADMINRESOURCES`, then 202.
  - `HandleProgress`: owner lookup, reconcile, `GuardedRenew` for the owner's non-terminal turn only, then 200 or 404.
  - `HandleAbandon`: `GuardedAbandonForUser($USERNAME)`, 200 `{"abandoned":n}`.
- `src/OcuPilot/Api/Router.cls` -- `/turn/:id/progress` GET, `/turn/abandon` POST, `/turn` POST, in that order, with thin wrappers.
- `src/OcuPilot/Kernel/Provider/Catalog.cls` -- when `$System.Util.GetEnviron("OCUPILOT_ALLOW_TEST_PROVIDER")` is `1`, `Row`/`IsKnown` resolve a `turnprobe` row: adapter `OcuPilot.Test.TurnProvider`, endpoint `https://192.0.2.10/v1/messages`, key prefix `sk-ant-`. The row stays out of the provider list the screens read.
- `src/OcuPilot/Test/TurnProvider.cls` (new) -- an `Anthropic` subclass overriding `IssueHttpsPost`. It reads a script and writes records under `^IRIS.Temp.OcuPilotTurnProvider(<model tag>)`, selected by the request's `model`. Records: `$USERNAME`, `$ROLES`, the key header's SHA-256, `system`, the message contents, the time, and a returned marker after the hang. A script entry is a hang in seconds plus a reply body.
- `src/OcuPilot/Kernel/Utils.cls` -- correct the header to name the real production callers -- DW-23.
- `src/OcuPilot/Test/Dispatch.cls` -- seed the body by assigning `%request.Content`, not `InsertMimeData` -- DW-422.
- `scripts/check-objectscript.py` + `scripts/test_check_objectscript.py` -- DW-400 and the job's reach:
  - A literal route counts as covered only by a bounded match of its whole URL plus its method literal in the same class. Harness cases: `/turn` covered only by `/turn/:id/progress` or `/turn/abandon` tests is flagged; GET and POST on one URL with only a GET test is flagged.
  - New rule: `Kernel/Agent/` names no `OcuPilot.Port.*` other than `ProviderPort`, and no `Area`, `Screen` or `Api` handler. `JOB` appears only in `Kernel/Agent/Job.cls`.
- `scripts/ci-throwaway.sh` -- add `OCUPILOT_ALLOW_TEST_PROVIDER: "1"`.
- `ui/src/app/core/session.ts` -- `TURN_ABANDON_PATH`. After its local half, `signOut()` posts it with the captured Bearer, waits at most 3,000 ms (a named constant, through `schedule`), reads no outcome, then posts `/logout` as today. A tab with no pair sends neither.
- `ui/tools/session.test.mjs` -- abandon precedes `/logout` and carries the same Bearer; an abandon that throws, answers 401, or never settles still lets `/logout` go (the last once the scheduled bound fires); no pair sends neither.
- Tests (new classes, each under 500 lines; every job-spawning test signals, waits for, and on timeout terminates what it spawned in `OnAfterOneTest`):
  - `Test/TurnLoop.cls` -- in-process and live-safe, through `Test.ProviderPortProbe`, restraint seams and a narrowed `Limits` subclass: bounds, fallback, every boundary check including lease and sign-out signals, a user name no account holds, provider faults, caps, prompt precedence.
  - `Test/TurnStore.cls` -- live-safe, no spawn: reserve and busy, owner lookup, renew, abandon scoped to its user, retention deleting steps and signals, caps.
  - `Test/TurnWire.cls` -- armed `OCUPILOT_ALLOW_TEST_PROVIDER` + `OCUPILOT_ALLOW_PRINCIPALS`: start, body, refused start, busy with a concurrent pair, poll shape, 404 for a second principal, identity, revoke and delete mid-turn, sign-out with both principals running, job lost, UTF-8.
  - `Test/TurnLong.cls` -- armed: the over-60-s row with the client timeout at 120 s, and the lease row (the stub holds its first call 125 s and answers `tool_use`; no poll until 2 s after its returned marker, then one poll).
  - `Test/TurnChain.cls` -- armed: DW-347. It restores the prior default and removes its entry.

**Acceptance Criteria:**

- Given each matrix row except Disabled user (probe), which the planning probe under Design Notes settles, when the suites run, then a named test observes it at the outermost surface it names: HTTP for route rows, the stub's records for provider rows, `session.test.mjs` for the client half of Sign-out.
- Given the tree, when `check-objectscript.py` runs, then the job's reach rule and the exact-route wire rule pass on the shipped code. Their harness shows each one failing on its fixture.
- Given every armed class on an unarmed instance, when it runs, then `OnBeforeAllTests` refuses by name and nothing is created.
- Given any test that spawns a job, when it exits by any path, then no process it spawned is still alive, and no turn row, signal node, slot lock or `^IRIS.Temp.OcuPilotTurnProvider` node of its own remains.

### Review Findings

Code review 2026-09-16, `full-opus`: blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor. 45 rows: 13 patch entries, 2 defer, and 30 rejected rows grouped below.

- [x] [Review][Patch] A 400 `TURN.BADBODY` reason carries `ReadRequestBody`'s vendor exception text, against AD-39 (med; fix-risk low, one handler branch) [src/OcuPilot/Api/Turn.cls:34]
- [x] [Review][Patch] The `turnprobe` row's refusal is asserted only where the arming variable is unset, and CI never runs such an instance (med; fix-risk low, a private seam and a probe subclass) [src/OcuPilot/Kernel/Provider/Catalog.cls:134]
- [x] [Review][Patch] No test makes the switches unreadable at a step boundary, so a fail-open boundary stays green (med; fix-risk low, test only) [src/OcuPilot/Kernel/Agent/Loop.cls:167]
- [x] [Review][Patch] The identity-mismatch test never reserves the turn it says was finished (med; fix-risk low, test only) [src/OcuPilot/Test/TurnWire.cls:410]
- [x] [Review][Patch] A begin that did not happen without an error, and a failed boundary read, end the turn with no log line (med; fix-risk low, log calls only) [src/OcuPilot/Kernel/Agent/Job.cls:70]
- [x] [Review][Patch] A spawn not accepted within its timeout answers 503 with no log line (low; fix-risk low) [src/OcuPilot/Api/Turn.cls:86]
- [x] [Review][Patch] Whitespace-only model text is echoed as a text block beside `tool_use` (low; fix-risk low) [src/OcuPilot/Kernel/Agent/Loop.cls:265]
- [x] [Review][Patch] `HandleStart`'s doc says nothing is reserved for any refusal; the spawn-failure 503 follows the reserve (low; doc) [src/OcuPilot/Api/Turn.cls:26]
- [x] [Review][Patch] `CallerUsername`'s doc names a fixture seam no class uses (low; doc) [src/OcuPilot/Api/Turn.cls:18]
- [x] [Review][Patch] The identity assertion spells OcuPilot's database role as a literal (low; test only) [src/OcuPilot/Test/TurnWire.cls:138]
- [x] [Review][Patch] Two doc comments attribute a test to QA (low; doc) [src/OcuPilot/Test/TurnWire.cls:407]
- [x] [Review][Patch] `TURN_ABANDON_PATH` is only ever compared with itself (low; test only) [ui/tools/session.test.mjs:1058]
- [x] [Review][Patch] AC 4's mutation was observed only on `TurnStore`, which spawns nothing (low; Rule 19 line) [## Verification]
- [x] [Review][Defer] `Definitions` and `Switches` render the same vendor text in their 400 reason [src/OcuPilot/Api/Definitions.cls:1210] — deferred: pre-existing since DW-24's fix, out of footprint; DW-447 routed to burndown
- [x] [Review][Defer] AD-31's "only a fresh password login is refused" was not probed for AD-28's silent cookie `/login` [ARCHITECTURE-SPINE.md AD-31] — deferred: planning artifact; occurrence appended to DW-444

Rejected:

- false: a kill switch ends a turn `stopped`, not "abandoned" (AD-30). "Abandons" is AD-30's verb for the stop flag too, `epics.md` Story 5.1 says "stopped by the user or the kill switch", and the Boundary row specifies `stopped` `AGENT.KILLSWITCH.*`.
- false: `/turn/abandon` bypasses the API service (AD-20). The path is absolute, and the service reads the token store `signOut()` has already cleared.
- low, by-design: the grants check covers the router's admin resources, not `%Ens_Credentials:READ`. Tasks fix the list; the port declares no pair for `Invoke`; 4-2 adds per-step pairs.
- low, by-design: the job-reach rule is a denylist. Tasks specify exactly its tokens.
- low, by-design: every poll answers the whole record. The Poll row fixes the shape; a cursor would be additive.
- low, by-design: retention runs only at a reserve (Retention row). A turn orphaned by a restart is one row per user, reconciled at that user's next poll or reserve.
- low: the iteration cap is read once. The Design Notes place the definition's per-call re-read in the port.
- low: `HoldsAnyResource` reads an exception as "holds nothing". It fails closed, and the probe shows the call answers 0 rather than throwing.
- low: the outer `Catch` of `Job.Run` does not finish a turn it never began. Nothing between the limits read and the begin can throw, and JOBLOST reconciles within 10 s.
- low: `/logout` waits behind the abandon, without `keepalive`. The window is one round trip, and this was already adjudicated (BH18).
- low: `JOB_RE` matches `job` in a trailing comment. The false positive is loud.
- low: `J` and `$SYSTEM.WorkMgr` spawns, and a `$ClassMethod` call to the principal helpers, are unmatched. No such spelling is in the tree.
- low: `Catalog.Table`'s doc says it is the only table seam. The armed block is not the table, and `Row`'s doc names it.
- low: TurnChain's arming guard is outside rule 17. AC 3 records its refusal, and rule 17's population is principal creators.
- low: TurnChain's teardown terminates without waiting, and the cannot-begin test reserves under the suite account. Either leaves a loud teardown failure only on an abort.
- low: a sweep stops at the first delete that fails. That needs a persistent database fault.
- low: a message over the string limit answers 500; a lease-signal failure orphans a queued row; a running step survives a loop error; a sign-in within the 3 s wait. All four were already adjudicated (ECH5, ECH6, BH19, ECH1).
- low: the verb literal may appear anywhere in the class. Tasks say "method literal in the same class" (ECH11).
- low: Matrix sub-cases (the cut flag, the 503, the abandon count) have no mutation line of their own. Rule 19 asks for one per row, and each row has one.
- low: the QA test is uncommitted. The lead commits it after smoke.
- duplicate: `epic-4-context.md` still says the lease covers disablement. It was compiled at 18:49Z, before AD-31's corrections, so the next plan's pre-warm refreshes it (noted for the lead).
- duplicate: AD-7's temp-global wording (DW-445); `CLAUDE.md`'s 18 rules (DW-446).
- not a defect: the memlog keeps the superseded AD-31 entry. The memlog is append-only, and its `correction` entries follow it.
- rejected, spec edit: the spec's `deferred` list, its "For the lead" bullet and the Lease row's disablement clause are stale.

## Spec Change Log

- 2026-09-16, plan halt G1/G2 answered by the orchestrator under the owner's standing autonomy instruction. AD-31 amended (existence and privilege from current grants; a 120 s poll lease covers disablement and abandoned tabs; OcuPilot's sign-out calls `POST /turn/abandon` because a token logout fires no session event; limits as named constants). AD-11 rule 1 amended for DW-333 (the override replaces the built-in prompt whole). Story 4.1's AC 4 and AC 6 in `epics.md` amended to match. The Disabled user and Sign-out matrix rows replaced; a Lease row added; the Bounds row caps iterations at 100. DW-250 declined and re-owned to 4-2. Re-plan must re-probe the disabled-account Bearer poll on the throwaway.
- 2026-09-16, lead at dev_complete: the Boundary 'never read `%SYS` security state from the job' is read as OcuPilot's own identity and grant decisions; the provider port's pre-existing AD-32 TLS-configuration check, run with the caller's own privileges and no elevation, is outside it. AD-31 and AC 4 were corrected at their origin so disablement is bounded by the wall-clock limit and the lease bounds an unwatched turn.

## Review Triage Log

### 2026-09-16 — Review pass

- verdicts: 74 findings — high 0, medium 21, low 50, false 3, maybe-false 0
- findings:
  - `[low]` `[reject]` BH1 echoing an unsolicited `tool_use` with no `tools` would be refused by the real API — unreachable in 4.1: with no tools advertised the provider emits no `tool_use`; 4.2 advertises tools.
  - `[low]` `[reject]` BH2 no boundary between tool calls of one reply — 4.1 tool calls reach nothing; Tasks place the boundary before each model call; per-tool checks belong to 4.2's `DispatchTools`.
  - `[false]` `[reject]` BH3 boundary uses `Restraint.Resolved`, not `Verdict(definition)` — the fields `Boundary` reads (`killSwitch`, its `code`, `enforcedReadOnly`) do not depend on the definition (`Restraint.cls` :98-121); Tasks name `Resolved`.
  - `[low]` `[reject]` BH4 the job gets `$Namespace`, not the `?ns=` scope — nothing in 4.1's job reads a scope namespace.
  - `[medium]` `[patch]` BH5 `Job.Run` logs nothing and leaves a turn it could not begin queued — `Job.Run` now logs every failure through `Kernel.Fault.LogRaw` and finishes a not-begun turn `failed` `TURN.UNAVAILABLE`; pinned by `TurnWire.TestAJobThatCannotBeginFinishesItsTurnFailed`.
  - `[low]` `[reject]` BH6 a POST during a poll's reconcile gets a spurious 409 — millisecond window, a resend succeeds; the zero-wait reserve lock is specified in Tasks.
  - `[medium]` `[patch]` BH7 the Busy row's slot lock is never seen to fail over HTTP — added a held-slot leg to the busy method; mutation recorded.
  - `[low]` `[patch]` BH8 `TurnWire` and `TurnLong` doc comments name mutations the runs contradicted — both corrected to the observed mutations.
  - `[low]` `[reject]` BH9 the spec's observed list sits apart from the planned one — the fix is a spec edit; the stale Auto Run Result is written at finalize.
  - `[low]` `[patch]` BH10 matrix rows with no recorded mutation — every flagged row now has an observed mutation line in `## Verification`.
  - `[medium]` `[patch]` BH11 `TurnCodes`, `ReasonForTurn` and the poll's `error.reason` are untested — added `TurnStore.TestAnEndedTurnsPollCarriesItsErrorSentence` and `TestEveryTurnCodeHasASentence`.
  - `[low]` `[reject]` BH12 `TURN.MESSAGE.*` are outside `ViolationCodes`/`ReasonForViolation` — the sentences live beside the codes and are pinned by the `TURN*` sweep; folding them in needs `AgentViolation`'s AGENT-only sweep reworked.
  - `[medium]` `[patch]` BH13 rule 17 cannot see `TurnWire`/`TurnLong` principal helpers — the helpers are called by `##class(OcuPilot.Test.TurnWireFixture)` and listed in `DESTRUCTIVE_TEST_RE`, with a harness case.
  - `[low]` `[patch]` BH14 `TurnChain` teardown stops and checks the slot as `$Username`, not the posting account — now `Http.GetTestUsername()`; the unparseable-202 leak and missing `OnAfterOneTest` rejected (one method; `OnAfterAllTests` cleans).
  - `[low]` `[patch]` BH15 `TurnStore` header claims every turn uses a probe user — header corrected.
  - `[low]` `[patch]` BH16 missing tests and unused seams — the iteration cap's second leg now asserts `completed|iterations`; `TurnLoopProbe.SetLimitsClass` removed; spawn failure (needs a seam), identity mismatch (unreachable), empty body (same branch as `[1]`) and the 16,000 boundary (cosmetic) rejected.
  - `[medium]` `[patch]` BH17 `/turn/abandon` sent without `credentials: 'omit'` — added, and asserted in `session.test.mjs`.
  - `[low]` `[reject]` BH18 `/logout` waits up to 3 s, no `keepalive`, timer not canceled — the wait is specified; a late timer settles a settled promise.
  - `[low]` `[reject]` BH19 a `running` step survives a job death; the reply has no truncation flag — only an abnormal death leaves one; the panel is 4.5; the reply cap is not a matrix row.
  - `[low]` `[reject]` BH20 poll cost — bounded by the 100-step cap and 15-minute retention; no measured cost.
  - `[medium]` `[defer]` BH21 AD-31 says the lease both covers and does not cover disablement; AD-7's temp-global wording and `epics.md` :2698 disagree with the shipped design — planning artifacts, pre-existing; recorded in `deferred`.
  - `[low]` `[defer]` BH22 `CLAUDE.md` still counts 18 checker rules — agent-context file; recorded in `deferred`.
  - `[low]` `[reject]` BH23 `J` abbreviation of `JOB` unmatched; no rule-7 harness case for `$Job` — no `J` spelling in the tree; `$Job` in `Turn.cls` is pinned by the shipped-tree test.
  - `[low]` `[reject]` BH24 a shipped class carries the test-only `turnprobe` row — specified in Tasks; unarmed it resolves nothing (now pinned), and an uncompiled adapter is already refused by `ProviderPort`.
  - `[low]` `[patch]` BH25 `TurnLong`'s lease test polls 2 s after the stub returns — it now waits for the stored turn to end, then polls once.
  - `[low]` `[reject]` ECH1 a sign-in within the 3 s abandon wait is ended by the delayed `/logout` — needs a new sign-in within 3 s of signing out; fix adds a guard.
  - `[low]` `[reject]` ECH2 an expired access token makes the abandon 401 — the lease then ends the turn (AD-31).
  - `[medium]` `[patch]` ECH3 `Run` does not finish a turn `GuardedBegin` did not begin — grouped with BH5.
  - `[medium]` `[patch]` ECH4 a failed final `GuardedFinish` is silent and later reads JOBLOST — grouped with BH5 (now logged).
  - `[low]` `[reject]` ECH5 a message over the string limit answers 500 — a 3.6 MB body; still one envelope.
  - `[low]` `[reject]` ECH6 a signal or sweep fault after the insert leaves a queued row — a database fault; the row is reconciled as JOBLOST within 10 s.
  - `[low]` `[reject]` ECH7 a `running` step survives a loop failure — grouped with BH19.
  - `[low]` `[reject]` ECH8 a `DispatchTools` override answering fewer results — no override in 4.1; 4.2's seam contract.
  - `[low]` `[reject]` ECH9 whitespace-only text beside `tool_use` echoed — `tool_use` unreachable in 4.1.
  - `[medium]` `[patch]` ECH10 the route matcher is bounded only at its end — now bounded at both ends, the API base allowed; harness case added; the shipped tree stays clean.
  - `[low]` `[reject]` ECH11 the verb may be named anywhere in the class — Tasks specify "method literal in the same class".
  - `[low]` `[reject]` ECH12 `J` abbreviation — grouped with BH23.
  - `[low]` `[patch]` ECH13 `TurnLong` lease timing — grouped with BH25.
  - `[medium]` `[patch]` VG1 a poll's lease renewal is never checked — added `TurnStore.TestAPollRenewsOnlyItsOwnersUnfinishedTurn`.
  - `[medium]` `[patch]` VG2 `error.reason` and `TurnCodes()` untested — grouped with BH11.
  - `[medium]` `[patch]` VG3 the poll's `limit` and `tokens` are never checked — `TurnLoop` now asserts the view's `limit` and `tokens.input|output`.
  - `[medium]` `[patch]` VG4 the handler's read-only snapshot is never checked — `TurnWire.TestTheSwitchesAreReadAgainAtEveryStepBoundary` starts a turn under enforced read-only and asserts it completes.
  - `[medium]` `[patch]` VG5 switches and holds are never turned on mid-turn — the same method turns on a hold, the kill switch and read-only during the first call.
  - `[medium]` `[patch]` VG6 the catalog's unarmed refusal of `turnprobe` is never checked — added `TurnStore.TestTheTurnProbeRowResolvesOnlyWhenArmed`.
  - `[medium]` `[patch]` VG7 rule 17 blind to `TurnWireFixture` — grouped with BH13.
  - `[medium]` `[patch]` VG8 the concurrent pair has never been seen to fail — grouped with BH7.
  - `[low]` `[reject]` VG9 a failed spawn is never tested — rare; forcing it needs a seam the handler lacks.
  - `[low]` `[patch]` VG10 Rule 19: ACs and rows with no recorded mutation — grouped with BH10; AC 3 and AC 4 lines added.
  - `[low]` `[reject]` VG11 the second arming guard is never observable — it refuses on a throwaway that predates the new variable.
  - `[low]` `[patch]` VG12 `TurnStore` teardown releases a held slot before asserting none is held — the assertion now runs first.
  - `[low]` `[patch]` VG13 the dropped-step update does not re-read the step count — it does now.
  - `[low]` `[patch]` VG14 the race posters are terminated but never confirmed ended — the busy method now waits for and asserts their exit.
  - `[low]` `[reject]` VG15 `TURN.MESSAGE.*` outside `ReasonForViolation` — grouped with BH12.
  - `[low]` `[patch]` VG16 a refused armed class still runs its teardown on live — `OnAfterAllTests` returns early when unarmed in all three classes.
  - `[low]` `[reject]` IA1 a final answer arriving after stop, revoke or sign-out completes the turn — the matrix ends a turn "at the next boundary", and no further call is made.
  - `[low]` `[reject]` IA2 the wall clock does not interrupt a call in flight — boundary semantics per the matrix; one call is bounded by the port's timeout.
  - `[low]` `[reject]` IA3 the job reads `%SYS` through `ProviderPort.SslConfigurationMissing` — AD-32 binds every port call to that check; it runs with the caller's own privileges and escalates nothing; rewording the Never is a spec edit (noted for the lead).
  - `[false]` `[reject]` IA4 `JOB` in `Test/TurnWire.cls` — existing test classes (`InstallLock`, `DemoOptIn`) spawn helpers; the Never scopes to shipped code, as the checker does.
  - `[low]` `[reject]` IA5 stop is observed in process only — no stop route until 4.5; the flag is read the same way at every boundary.
  - `[medium]` `[patch]` IA6 a kill switch or hold turned on mid-turn is never observed — grouped with VG5.
  - `[medium]` `[patch]` IA7 read-only changed mid-turn is never observed — grouped with VG5.
  - `[low]` `[reject]` IA8 bounds run on narrowed limits — Tasks specify a narrowed `Limits` subclass.
  - `[low]` `[reject]` IA9 provider faults observed through `GuardedView`, not a poll — the view is the poll's projection; the handler adds only `reason`, now pinned.
  - `[low]` `[reject]` IA10 caps observed on narrowed limits — as IA8.
  - `[low]` `[reject]` IA11 retention's 404 dispatched in process — `Test.Dispatch` runs the shipped router.
  - `[low]` `[reject]` IA12 a queued lost turn is observed in process only — over HTTP it needs a spawn that never begins.
  - `[low]` `[reject]` IA13 sign-out of a queued turn observed in process only — same signal and boundary as a running turn.
  - `[low]` `[patch]` IA14 the job-side stub's `system` is never asserted — `TurnWire` shape test now asserts the built-in prompt.
  - `[medium]` `[patch]` IA15 the poll's `error.reason` and `limit` are never asserted — grouped with BH11 and VG3.
  - `[medium]` `[patch]` IA16 the concurrent pair stayed green under its mutation — grouped with BH7.
  - `[low]` `[patch]` IA17 identity mutation doc stale; rule 7 does not cover `OcuPilot.Kernel.Agent` — doc grouped with BH8; token added to rule 7 with a harness case.
  - `[low]` `[reject]` IA18 UTF-8 observed before `%Net.HttpRequest` sends — the vendor send path uses RAW for `application/json` with no charset (`irislib/%Net/HttpRequest.cls` :1290-1305); a real send would leave the container.
  - `[low]` `[reject]` IA19 step `name` and `reply` are capped beyond the intent — a stored-field cap; no conflict with the intent.
  - `[false]` `[reject]` IA20 the Auto Run Result reads `ready-for-dev` — written at finalize.

## Design Notes

**Governing ADs (Rule 6):** AD-7 (job, polling, never mutates), AD-8 (grants checked at call time), AD-9 (spawn and escalation ordering), AD-11 (system prompt, delimited tool results), AD-12/39 (envelope, codes), AD-20 (absolute API paths), AD-21 (bound SQL), AD-28 (sign-out sends Bearer and cookie), AD-30 (switches re-read between steps), AD-31 (identity re-validation, lease, sign-out, limits), AD-33 (progress channel), AD-35 (no key in records), AD-37 (a deleted user abandons), AD-41 (bounds, one concurrent turn), AD-42 (the stored key goes only to the stored endpoint). Conventions: the 29-character cap, row version, route ordering, error shape, dates, opaque turn ids.

**Probed on the slot-A throwaway:**

- 2026-09-16, on a throwaway started after 18:19Z: `JOB` passes a 100,000-character argument, and the child inherits `$USERNAME`/`$ROLES`, also when spawned by a least-privileged user. A lock taken inside an AddRoles frame outlives the frame, blocks other processes, and frees on process exit. `CheckUserPermission($USERNAME, …)` reads current grants: 0 after role removal or deletion, 1 for a disabled user. A least-privileged process switching to `%SYS` gets `<PROTECT>`. An `EventClass` on `/api/ocupilot` saw `OnStartSession`/`OnLogin` at `/login` and nothing at a Bearer `/logout`. A 70-second request through the stock gateway answers 504 at 60.0 s.
- 2026-09-16 18:52-18:54Z, disabled account (container brought up and torn down by this run): a principal holding `%DB_HSCUSTOM:R,%Admin_Operate:U` minted a pair and read `GET /instance` 200. After `Security.Users.Modify` set `Enabled` 0 (read back 0), the same access token answered 200 twice, `POST /refresh` minted a new pair (200) whose access token answered 200, a second refresh 81 s after the disable answered 200 and its token 200, and only a credential `POST /login` answered 401. Expired access tokens answered 401.

**Decisions made in planning:**

- **Disablement is bounded by the wall clock alone.** The instance answers a disabled account's Bearer poll and refresh, so the client keeps renewing the lease. AD-31's fallback applies: such a turn ends at 600 s at the latest.
- **Concurrency is a process lock, not a row flag.** The job holds `^OcuPilotTurnSlot(user)` for its whole life, so a crashed job frees the slot by exiting. The `queued` window closes the race between POST and the job's start.
- **Signals are scalar nodes, not row fields.** A poll every few seconds, Stop and sign-out all write while the job writes the turn row. On a row-versioned row each would draw `STATE.CONFLICT` from the others. Each signal is a set-once flag or a latest timestamp, so a plain node set loses nothing, and the job only reads them. AD-7 names a global keyed by turn id.
- **The grants check takes its resource list as a value.** Kernel code does not reach `Api.Router`; the handler passes `ADMINRESOURCES` in, and 4.2 extends it per tool through `DispatchTools`.
- **Precedence lives in the port.** `Invoke` reads the definition at every call, so an edited override takes effect at the next call (AD-42) with no second read in the loop.
- **A cross-process seam is armed by the environment.** Every existing stub is `^||` state that a job never sees, and `ProviderPortProbe` falls back to the real adapter inside a job. An environment-armed catalog row reaches the job, and the credential route through the shipped `Definitions` class, without a production catalog change.
- **Values in, live reads after.** Starting state is passed in (AD-9). The switches, grants, signals and definition are re-read at each step (AD-30, AD-8, AD-42).
- **The client waits at most 3 s for abandon.** Unbounded, a hung abandon would keep `/logout` from ever being sent and leave the browser-level login alive.

**Declined DW-250:** the job opens no output capture, and a fresh `JOB` has no `^||%capture`. The first caller that can nest a capture is 4.2's tool dispatch into `AdminPort`, so it belongs to 4-2.

**Integration:** the client consumer in this story is `session.ts` `signOut()`, which calls `POST /turn/abandon`: its request is pinned by `session.test.mjs`, the route's effect on the instance by `TurnWire`. The panel's first consumer is Story 4.5. Consumes: `ProviderPort.Invoke` (3.2/4.0), `Restraint.Resolved` (3.7), `State.Base` escalation (1.3), Router gates (1.6/1.8), `Kernel.Utils.ReadRequestBody`. Consumed-by:

- 4-2: the `DispatchTools` seam and the per-step privilege pairs.
- 4-4: context on the POST body.
- 4-5: the progress contract, `GuardedRequestStop`, busy, lease renewal by polls.
- 4-6: `reply` and `error`.
- 4-8: provider faults as turn errors naming the step.
- 4-9: step records and usage.
- 5-1: the terminal state outliving the job.
- 14-6: `Kernel.Agent.Limits` becomes per-user settings.

## Verification

**Commands (live dev instance `ocupilot`, profile `ocupilot-slot-a`: compile, lint, and in-process classes that spawn nothing):**

- `iris_doc_load` with `server: "ocupilot-slot-a"`, `namespace: "HSCUSTOM"`, path `/Users/jbrandt/git/OcuPilot/.worktrees/epic-4/src/**/*.cls`, `compile: true` -- expected: clean.
- `uv run scripts/check-objectscript.py` and `uv run scripts/test_check_objectscript.py` -- expected: clean.
- `iris_execute_tests`, one class per call, each read back from `%UnitTest_Result`: `Test.TurnLoop`, `Test.TurnStore`, `Test.Utils`, `Test.AgentCredential`, `Test.ProviderPort`, `Test.ProviderConsumer` -- expected: green.
- `Test.TurnWire`, `Test.TurnLong`, `Test.TurnChain` on live -- expected: refused by name.
- `cd ui && npm test` -- expected: green.
- `bash scripts/lint-docs.sh` -- expected: clean.

**Commands (slot-A throwaway only: HTTP, armed, principals, anything that spawns a job):**

- `sh scripts/ci-throwaway.sh up --dir /tmp/ocupilot-ci --project ocupilot-ci --web 52776 --super 1975`
- `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node ui/tools/ci-runner.mjs --container ocupilot-ci` -- expected: all green. `Test.TurnLong` runs over 200 s; a client-side timeout is not a failure and is never re-submitted.
- `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` -- expected: non-zero checks, all pass.
- `sh scripts/ci-throwaway.sh down --dir /tmp/ocupilot-ci --project ocupilot-ci`, only for an `up` this run made.

**Planned mutations (Rule 19; record the observed red next to each):**

- Over 60 s: `HandleStart` calls `Loop.Run` in-process instead of `Job.Start` -> `TurnLong` red (the POST answers 504).
- Identity: `Job.Start` wrapped in an AddRoles frame -> `TurnWire` identity leg red.
- Busy: `GuardedReserve` skips the queued-window check -> the concurrent-pair leg red.
- 404: `GuardedForOwner` drops the user predicate -> the second-principal leg red.
- Boundary checks: remove the grants check -> the revoke leg red. Remove the read-only comparison -> the `TurnLoop` read-only leg red.
- Lease: remove the lease comparison -> the `TurnLoop` lease leg and the `TurnLong` lease leg red.
- Sign-out: `GuardedAbandonForUser` drops the user predicate -> the `TurnWire` second principal's turn is abandoned, red. `signOut()` posts `/logout` first -> the `session.test.mjs` ordering test red. Await abandon without the bound -> the never-settles test red.
- Bounds: compare with `>` against a one-iteration cap -> the `TurnLoop` fallback leg red.
- Prompt: `Invoke` joins `pSystemPrompt` and the override -> the `TurnLoop` precedence leg red.
- DW-347: the stub hashes `""` -> `TurnChain` red.
- DW-400: revert to substring keying -> the harness prefix case red.
- DW-422: drop the `Content` assignment -> the `AgentCredential` dispatch legs red.
- Job reach: reference `OcuPilot.Port.AdminPort` from `Loop.cls` -> the harness rule red.

Observed, each reverted and reloaded after its run (live for `TurnLoop`, `TurnStore` and `AgentCredential`; the throwaway for the armed classes):

- mutation: `HandleStart` runs `Job.Run` in the request process instead of `Job.Start` -> `TurnLong.TestATurnOutlivesTheGatewayResponseTimeout` red (no 202; answered at 60.08 s).
- mutation: `AddRoles` in `Job.Start` itself -> `TurnWire` identity leg stayed green, because the routine application admits only `Kernel.State.Base`. mutation: the spawn called from an escalated frame added to `Kernel.State.Base` -> `TurnWire.TestAStartRunsAsTheCallerAndThePollAnswersItsShape` red (`$ROLES` carried `%DB_OCUPILOT`).
- mutation: `ReconcileHeld` drops the queued-window check -> `TurnStore.TestAReserveIsOneQueuedTurnPerUser` red; `TurnWire.TestABusyCallerIsRefusedAndAConcurrentPairStartsOne` stayed green, because the reserve's zero-wait slot lock refuses the simultaneous loser and the running job holds the slot.
- mutation: `GuardedForOwner` drops the user predicate -> `TurnStore.TestOnlyTheOwnerFindsRenewsAndStopsATurn` red and `TurnWire.TestAnotherPrincipalsTurnAnswersLikeAnUnknownId` red.
- mutation: `Loop.Boundary` without the grants check -> `TurnLoop.TestAUserNoAccountHoldsIsAbandonedForPrivilege` red and `TurnWire.TestRevokingOrDeletingThePrincipalAbandonsItsTurn` red (both legs).
- mutation: `Loop.Boundary` without the read-only comparison -> `TurnLoop.TestTheSwitchesEndTheTurnBeforeACall` red.
- mutation: `Loop.Boundary` without the lease comparison -> `TurnLoop.TestTheLeaseAndTheWallClockAbandonTheTurn` red and `TurnLong.TestALapsedLeaseAbandonsTheTurn` red.
- mutation: `GuardedAbandonForUser` drops the user predicate -> `TurnStore.TestAnAbandonReachesOnlyItsUser` red and `TurnWire.TestSignOutAbandonsOnlyTheCallersTurn` red.
- mutation: `signOut()` posts `/logout` before the abandon -> `session.test.mjs` "sign-out abandons the turns before /logout" red (and the never-settles test).
- mutation: the abandon awaited without the scheduled bound -> `session.test.mjs` "an abandon that never settles lets /logout go once the bound fires" red.
- mutation: the iteration cap compared with `>` -> `TurnLoop.TestTheIterationCapCompletesWithTheFallbackReply` red (two calls).
- mutation: `SystemPromptFor` joins the prompt and the override -> `TurnLoop.TestAnOverrideReplacesTheBuiltInPromptWhole` red.
- mutation: `TurnProvider` hashes `""` -> `TurnChain.TestAKeyStoredOverTheWireReachesTheTurnsProviderCall` red.
- mutation: literal routes keyed by substring again -> harness `test_a_shorter_route_is_not_covered_by_a_test_naming_only_longer_ones` and `test_a_second_method_on_one_url_is_its_own_obligation` red.
- mutation: `Test.Dispatch` without the `Content` assignment -> `AgentCredential` red on its three dispatch legs (`TestAReReadThatAnswersNothingStillRecordsWhatTheClearDid`, `TestAStoreWhoseDefinitionVanishesRefusesAndSaysTheKeyWasStored`, `TestASweepStillRunsWhenThePostedDefinitionVanishes`).
- mutation: `Loop.PortClass` names `OcuPilot.Port.AdminPort` -> harness `test_the_shipped_tree_passes_every_rule_this_story_added` red on `check_agent_job_reach`.

Observed in the review pass. Mutations shared a run only when each targeted a different method, and every other method of that run stayed green:

- mutation: `Loop.Boundary` without the stop flag -> `TurnLoop.TestStopAndSignOutEndTheTurnBeforeACall` red.
- mutation: `Loop.Boundary` without the wall-clock comparison -> `TurnLoop.TestTheLeaseAndTheWallClockAbandonTheTurn` red on its wall-clock leg.
- mutation: `Loop.Boundary` without the token comparison -> `TurnLoop.TestTheTokenLimitAbandonsAtTheNextBoundary` red.
- mutation: `Loop.Run` ignores the fault -> `TurnLoop.TestProviderFaultsFailTheTurnNamingTheModelStep` red.
- mutation: `Loop.Run` sends `""` as the system prompt -> `TurnLoop.TestAReplyCompletesTheTurnWithTheBuiltInPrompt` red.
- mutation: `Loop.Boundary` without the kill-switch check -> `TurnWire.TestTheSwitchesAreReadAgainAtEveryStepBoundary` red on its hold and global legs.
- mutation: `HandleStart` passes 0 as the read-only snapshot -> the same method red on its read-only-from-the-start leg.
- mutation: `HandleStart` skips `MessageViolation` -> `TurnWire.TestABadBodyIsRefusedAndReservesNothing` red.
- mutation: `HandleStart` skips the kill-switch refusal -> `TurnWire.TestARefusedStartReservesNothing` red.
- mutation: `GuardedReserve` skips the slot lock -> `TurnWire.TestABusyCallerIsRefusedAndAConcurrentPairStartsOne` red, the held-slot leg included.
- mutation: `ReconcileHeld` treats a running turn as live -> `TurnStore.TestALostTurnIsFinishedByTheNextReserveOrReconcile` and `TurnWire.TestALostJobIsAbandonedByTheNextPoll` red.
- mutation: `GuardedReserve` skips the retention sweep -> `TurnStore.TestRetentionDeletesTheTurnItsStepsAndSignals` red.
- mutation: `Step.GuardedAppend` ignores the step cap -> `TurnStore.TestStepsAreCappedOnWrite` and `TurnLoop.TestCapsCountDroppedStepsAndCutFields` red.
- mutation: `HandleProgress` skips `GuardedRenew` -> `TurnStore.TestAPollRenewsOnlyItsOwnersUnfinishedTurn` red.
- mutation: `HandleProgress` blanks `error.reason` -> `TurnStore.TestAnEndedTurnsPollCarriesItsErrorSentence` red.
- mutation: `ReasonForTurn` without its `TURN.LIMIT.TOKENS` branch -> `TurnStore.TestEveryTurnCodeHasASentence` red.
- mutation: `Catalog.Row` without the environment test -> `TurnStore.TestTheTurnProbeRowResolvesOnlyWhenArmed` red on live.
- mutation: `Anthropic.CallMessages` writes the body without UTF-8 encoding -> `TurnWire.TestAStartRunsAsTheCallerAndThePollAnswersItsShape` red on the message assertion.
- mutation: `Job.Run` leaves a turn it could not begin unfinished -> `TurnWire.TestAJobThatCannotBeginFinishesItsTurnFailed` red.
- mutation: the abandon settles only on success -> `session.test.mjs` "an abandon that throws still lets /logout go" red; the abandon without `credentials: 'omit'` -> "sign-out abandons the turns before /logout" red.
- mutation (AC 3): `TurnLong.OnBeforeAllTests` without its arming guard -> `check-objectscript.py` red (rule 17 on `TurnWireFixture.EnsurePrincipal`).
- mutation (AC 4): `Turn.GuardedDelete` skips the signal kill -> `TurnStore` teardown red in 8 of 11 methods ("left steps or signals").
- mutation (AC 2): the route matcher bounded only at its end -> harness `test_a_route_at_the_tail_of_a_longer_route_is_not_covered_by_it` red; `OcuPilot.Kernel.Agent` dropped from rule 7 -> `test_a_state_class_naming_the_agent_package_is_refused` red; `TurnWireFixture` dropped from rule 17 -> `test_the_turn_principal_helpers_are_in_the_population` red.

Observed in the code review. Throwaway mutations were made only to the copies under `/tmp/ocupilot-ci/src`, which were then restored from the worktree and reloaded. Live and client mutations were restored from a saved copy, and `cmp` confirmed each restore:

- mutation: `Loop.Boundary` goes on past a failed restraint read -> `TurnLoop.TestUnreadableSwitchesFailTheTurnBeforeACall` red (live run 2305).
- mutation: `Catalog.Row` without its arming test -> `TurnStore.TestTheTurnProbeRowResolvesOnlyWhenArmed` red on the armed throwaway, on the unarmed-catalog assertion alone (run 9).
- mutation: `HandleStart` renders the parse fault's vendor text again -> `TurnWire.TestABadBodyIsRefusedAndReservesNothing` red on "not json" (throwaway run 8).
- mutation: `Job.Run`'s identity-mismatch branch without `Finish` -> `TurnWire.TestAJobIdentityMismatchReachesTheConsoleLog` red on its state assertion (run 8, the only other red).
- mutation (AC 4, a class that spawns jobs): `Turn.GuardedDelete` skips the signal kill -> `TurnWire` teardown red in 8 of 11 methods (throwaway run 10).
- mutation: `TURN_ABANDON_PATH` names `/turns/abandon` -> `session.test.mjs` "sign-out abandons the turns before /logout" red.

## Auto Run Result

Status: done
Blocking condition: none

**Summary.** `POST /turn` reserves the caller's slot, spawns `Kernel/Agent/Job` from the unescalated handler frame, and answers 202. The job runs a bounded loop that re-checks stop, sign-out, switches, read-only, grants, lease, wall clock and tokens before each provider call, and writes capped progress to `Kernel.State.Turn` and `Step`. `GET /turn/:id/progress` answers the owner only and renews the lease. `POST /turn/abandon` is called by `signOut()` before `/logout`, waiting at most 3 s.

**Files.**

- `src/OcuPilot/Api/Turn.cls`, `Router.cls` (3 routes), `Error.cls`: the handler, the routes, and the 14 `TURN.*` codes with their sentences.
- `src/OcuPilot/Kernel/Agent/Job.cls`, `Loop.cls`, `Limits.cls`, `Prompt.cls`: the spawn, the loop, the limits, and the built-in prompt.
- `src/OcuPilot/Kernel/State/Turn.cls`, `Step.cls`, `Base.cls`: the turn and step rows, and the slot lock and signal helpers.
- `src/OcuPilot/Port/ProviderPort.cls`: the override replaces the prompt whole (DW-333).
- `src/OcuPilot/Kernel/Provider/Anthropic.cls`: block content and a UTF-8 body (DW-23).
- `src/OcuPilot/Kernel/Provider/Catalog.cls`: the armed `turnprobe` row.
- `src/OcuPilot/Kernel/Utils.cls`: header corrected. `src/OcuPilot/Test/Dispatch.cls`: body seeded through `Content` (DW-422). `Test/Http.cls`: optional client timeout.
- `src/OcuPilot/Test/TurnLoop`, `TurnStore`, `TurnWire`, `TurnLong`, `TurnChain`, plus fixtures `TurnFixture`, `TurnWireFixture`, `TurnProvider`, `TurnLimits`, `TurnLoopProbe`.
- `scripts/check-objectscript.py` and its harness: exact-route wire keying bounded at both ends (DW-400), the job-reach rule, rule 7 covering `OcuPilot.Kernel.Agent`, and rule 17 covering the turn principal helpers.
- `scripts/ci-throwaway.sh`: `OCUPILOT_ALLOW_TEST_PROVIDER`.
- `ui/src/app/core/session.ts`, `ui/tools/session.test.mjs`: the sign-out abandon.

**Review.** 74 findings: 0 high, 21 medium, 50 low, 3 false.

- Patched: 11 medium and 11 low entries after grouping.
- Deferred: 2 (BH21, BH22).
- Rejected: 38, each with its reason in the triage log.
- Patched medium entries:
  - `Job.Run` now logs every failure and finishes a turn it could not begin.
  - New tests pin lease renewal by a poll, `error.reason` and the `TURN*` sentences, `limit` and `tokens` in the view, the read-only snapshot, switches turned on mid-turn, the catalog's arming gate, and the busy slot lock.
  - Rule 17 now sees the turn principal helpers, and the route matcher is bounded at its start.
  - `/turn/abandon` is sent with `credentials: 'omit'`.

**Follow-up review: recommended.** 11 medium entries were patched. `Job.Run`'s failure logging is not asserted by any test, and the roughly 180 lines of test code added in this pass were reviewed by no layer.

**Verification (final tree).**

- Live `ocupilot`: compile clean. `TurnLoop` 10/10 (run 2294), `TurnStore` 11/11 (run 2293). `Utils`, `AgentCredential`, `ProviderPort` and `ProviderConsumer` were green at runs 2280–2283 in this pass. `TurnWire`, `TurnLong` and `TurnChain` refuse by name (runs 2295–2297). Live holds no turn row, step or signal.
- Throwaway `ocupilot-ci`: all 93 classes green, 883 tests. They ran in three explicit `--class` chunks, runs 204–296, because one sweep exceeds a foreground call. Smoke 19/19.
- Local: `check-objectscript.py` 0 problems; harness 107 OK; `npm test` and `npm run build` green; `lint-docs` clean.
- Every review mutation was reverted, and the tree matched its pre-mutation state byte for byte.

**QA pass (independent falsification).** New test: `src/OcuPilot/Test/TurnWire.cls`
`TestAJobIdentityMismatchReachesTheConsoleLog`, closing the follow-up review's logging gap --
`Job.Run` is called directly (nothing spawned) and the assertion reads the throwaway's real
`messages.log` through `OcuPilot.Port.LogSourcePort.Page`, since `Job.cls` has no probe seam. Six
mutations, each independent of every mutation already recorded above, reverted and reloaded after
its run; the tree matched byte for byte each time (`git diff --stat` empty except the kept test).

- mutation: `Job.Run`'s identity-mismatch branch drops `Do ..Log(...)` -> `TurnWire.TestAJobIdentityMismatchReachesTheConsoleLog` red (throwaway run 5); green again at run 6 (QA).
- mutation: `Turn.GuardedBegin` drops the `tRow.UserName '= pUser` ownership check -> `TurnStore.TestBeginAndFinishHoldTheSlotBetweenThem` red (live run 2299), a test with no mutation recorded anywhere before this pass; green again at run 2300 (QA).
- mutation: `Turn.GuardedView` hardcodes `error.seq` to 0 instead of `+tRow.ErrorSeq` -> `TurnStore.TestAnEndedTurnsPollCarriesItsErrorSentence` red on all three codes (live run 2299), a second, independent angle on a review-pass-added test whose only recorded mutation to date targeted `reason`, not `seq`; green again at run 2300 (QA).
- mutation: `Base.GuardedTurnSlotUnlock` skips its `Lock -^OcuPilotTurnSlot` -> every `TurnStore` method's "no probe slot is left held" teardown assertion red, 11 of 11 (live run 2301); the leaked locks cleared with the mutated run's process, confirmed against `iris_locks_list` before reloading; green again at run 2302 (QA).
- mutation: `TurnChain.OnBeforeAllTests` drops its `OCUPILOT_ALLOW_TEST_PROVIDER` guard -> called directly (never through `iris_execute_tests`, so no armed test body ran), the call answers `$$$OK` instead of refusing (live); reverted, the refusal returns unchanged (QA).
- mutation: `TurnWire.cls`'s `/turn/abandon` literal split into `"/turn/" _ "abandon"` (behavior unchanged, defeats the checker's literal-route regex) -> `uv run scripts/check-objectscript.py` on the real shipped tree (not the harness fixture) reports the route uncovered; reverted, 0 problems again (QA).

**For the lead.**

- AD-31 contradicts itself on whether the lease covers disablement (deferred BH21).
- The Never "read `%SYS` security state from the job" is crossed by the port's existing AD-32 TLS check, which reads with the caller's own privileges (IA3).
