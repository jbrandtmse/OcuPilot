---
title: 'The turn runs in a background job and returns immediately'
type: 'feature'
created: '2026-09-16'
status: 'blocked'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings:
  - multiple-goals
  - oversized
deferred: []
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
| Disabled user | **BLOCKED (intent gap G1; see Auto Run Result)** | — | — |
| Sign-out | **BLOCKED (intent gap G2; see Auto Run Result)** | — | — |
| Bounds | Iterations reach the definition's `MaxIterationsPerTurn` / elapsed time reaches 600 s / input plus output tokens reach 500,000 | `completed` with the harvested fallback reply and `limit:"iterations"` / `abandoned` `TURN.LIMIT.DURATION` / `abandoned` `TURN.LIMIT.TOKENS` | No error expected |
| Provider fault | Invoke answers `PROVIDER.CREDENTIALSTORE`, `PROVIDER.CREDENTIAL`, or any other `PROVIDER.*` | `failed`, with `error.seq` naming the model step and `error.code` the fault. The definition stays enabled for CREDENTIALSTORE and is disabled for CREDENTIAL | Never an exception to the client |
| Job lost | The turn is running, or queued for more than 10 s, and no live process holds the user's slot | The next reserve or poll marks it `abandoned` `TURN.ABANDONED.JOBLOST` and frees the slot | No error expected |
| Progress caps | More than 100 steps; a summary over 1,000 characters or a text over 131,072 | Steps past 100 are counted in `stepsDropped`. A field is cut at its cap and `truncated` is true | No error expected |
| Retention | A terminal turn ended 15 minutes or more ago | The next reserve by any user deletes the turn and its steps. A poll then answers 404 | No error expected |
| Integration, DW-347 (consumer: the turn job, through `ProviderPort.Invoke`) | Armed: a `turnprobe` definition is created, its key stored, and the definition enabled and made default, all over the wire. Then a turn is posted | The stub's recorded SHA-256 of the key header equals that of the posted key | No error expected |
| Prompt, DW-333 | The definition's override is empty / non-empty | The provider receives the built-in prompt / exactly the override, never both | No error expected |
| Body UTF-8, DW-23 | The posted message contains U+00E9 and U+4E2D | The provider receives both characters intact | No error expected |

</intent-contract>

## Code Map

- `src/OcuPilot/Api/Router.cls` -- UrlMap :66-90 (add `/turn/:id/progress` GET before `/turn` POST), thin wrappers :93-268, `OnPreDispatch` :402-474 (install gate, `IsAuthenticatedPrincipal`, `HoldsAdminResource` :300, `ADMINRESOURCES` :44, `Kernel.Scope`).
- `src/OcuPilot/Api/Error.cls` -- 12 closed slugs :20-54, `Render` :790, code parameters (`PROVIDERUNCONFIGURED` :194, `AGENTKILLSWITCH*` :562-565), `ReasonForViolation` :620, `ViolationCodes` :657, `ReasonForRestraint` :574.
- `src/OcuPilot/Api/Definitions.cls` -- the handler pattern to copy: `HandleCreate` :299, `BodyIsReadable` :1225, `RenderNotFound` :1199.
- `src/OcuPilot/Api/Response.cls` -- `JSONStatus(pStatus, pData)` :25.
- `src/OcuPilot/Kernel/Utils.cls` -- `ReadRequestBody` :366 (reads `GetMimeData("BODY")`, else `Content`; no size cap). The header :14-21 wrongly says no production caller exists; Definitions and Switches already call it.
- `src/OcuPilot/Kernel/State/Base.cls` -- escalation golden example :6-25, `APPLICATION` :48, guarded save :105/:140, `GuardedOpenOneWhere*` :380-468, `GuardedIdsWhere` :500. All subclasses share the `^OcuPilot.Kernel.State.Base*` extent. `OcuPilot*` globals map to OCUPILOT (`Installer.EnsureMapping` :2676), and new tables get SQL grants from the dictionary (`StateTables` :3091), so no roster edit is needed. `Test/State.cls` :425 covers new subclasses automatically.
- `src/OcuPilot/Kernel/State/Hold.cls` -- the closest per-user row shape (`GuardedForUser` :36, `GuardedCreate` :80).
- `src/OcuPilot/Kernel/State/Agent.cls` -- `ResolveDefault` :548, `MaxIterationsPerTurn` :88, `SystemPromptOverride` :90-92.
- `src/OcuPilot/Kernel/Restraint.cls` -- `Resolved(user, .v)` :174, which re-reads each call (`killSwitch`, `killSwitchAudience`, `enforcedReadOnly`, `code`).
- `src/OcuPilot/Port/ProviderPort.cls` -- `Invoke(defId, .messages, .tools, system, .response, .http, .fault)` :77, always `$$$OK`. `ValuesFor` :305-329 carries the override at :325, and nothing reads it. Disables only on CREDENTIAL :129-135.
- `src/OcuPilot/Kernel/Provider/Anthropic.cls` -- `CallMessages` :38-77 (content is a plain string today), `ApplyAuth` :84-88, `MapResponse` :106-144 (`ToolCallsJson`, usage).
- `src/OcuPilot/Kernel/Provider/Catalog.cls` -- `Providers` XData :48-52, `Table` :59, `Row` :106. `Base.IssueHttpsPost` :316 is the stub override point.
- `scripts/check-objectscript.py` -- `check_handler_wire_tests` :1314. The key is a substring and the method is ignored (:1332-1343). Rules 6/7 are escalation containment; route ordering is at ~:1539. Harness: `scripts/test_check_objectscript.py` `TestHandlerWireTestRule` :650.
- `src/OcuPilot/Test/Dispatch.cls` :79-85 -- seeds the body with `InsertMimeData` (`[Final, Internal]`, `irislib/%CSP/Request.cls` :637). `Content` :71 is a public property.
- `src/OcuPilot/Test/Http.cls` -- `AbsoluteRequest` :206, localhost:52773 (through Apache and the Web Gateway), default client timeout 30 s.
- Patterns: `Test/AgentWireSecurity.cls` :59-156 (armed principal), `Test/ProviderStub.cls` :187-237 (in-process stub, `^||` state that never crosses into a job), `Test/CatalogProbe.cls`, `Test/CredentialFixture.cls`, `Test/AgentCredential.cls` :106-142 (key POST).
- `scripts/ci-throwaway.sh` :147-195 -- the armed environment block. Check whether `ui/tools/ci.test.mjs` pins that list.
- Vendor evidence, read-only: harvest `iris-session-agent.md` l.72-74 (10-step flow, `BuildMaxIterFallback`), l.87 (schema subset), l.123 (lock protocol, which 4.5 owns). `EXPERIENCE.md` l.278-280 (fixed strings).

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Kernel/State/Turn.cls` (new, 26 chars) -- the turn row: `TurnKey` (opaque, unique), `UserName`, `DefinitionId`, `State`, `Code`, `StopRequested`, `QueuedAt`, `StartedAt`, `EndedAt`, `Iterations`, `InputTokens`, `OutputTokens`, `LimitHit`, `StepsDropped`, `JobId`. Guarded methods:
  - `GuardedReserve`: takes `Lock +^OcuPilotTurnSlot(user):0`, reconciles lost jobs, refuses busy, inserts a `queued` row, sweeps turns past retention, and releases the lock.
  - `GuardedBegin`: the job takes the slot lock with a 10 s wait and holds it for its life.
  - `GuardedFinish`: records the terminal state and releases the lock.
  - `GuardedRequestStop`, `GuardedForOwner(key, user)`, and the poll's reconcile.
  No `JOB` and no port calls (rules 6/7).
- `src/OcuPilot/Kernel/State/Step.cls` (new, 26 chars) -- one row per progress record, keyed by `TurnKey` plus `Seq`, with caps applied on write. It is deleted with its turn.
- `src/OcuPilot/Kernel/Agent/Prompt.cls` (new) -- the built-in system prompt as a compiled constant, and `For(override)` implementing the precedence rule -- DW-333.
- `src/OcuPilot/Kernel/Agent/Job.cls` (new) -- `Start(values, .key)`, called from the handler frame (`JOB …::5`; a failed spawn finishes the turn `failed` `TURN.UNAVAILABLE`), and `Run(...)`, the job entry point. `Run` asserts `$USERNAME` equals the passed user, begins, runs the loop, and finishes on every exit path, the outer Catch included.
- `src/OcuPilot/Kernel/Agent/Loop.cls` (new) -- the harvested flow rewritten for the job:
  - Parameters `MAXTURNSECONDS` 600 and `MAXTURNTOKENS` 500000. The iteration cap comes from the definition.
  - The boundary check runs in the matrix's order: stop, switches, read-only, grants, time, tokens.
  - A model step goes through `..PortClass()`, `ProviderPort` by default.
  - A `tool_use` answer is echoed back as assistant blocks, with one `tool_result` per call (`is_error`, content `{"code":"TOOL.UNAVAILABLE"}`) through the `..DispatchTools` seam 4.2 replaces.
  - Progress steps are written as the loop runs, and the fallback reply is used at the iteration cap.
- `src/OcuPilot/Kernel/Provider/Anthropic.cls` -- when `pMessages(n,"blocks")` holds a JSON array, send it as `content`. Plain strings are unchanged.
- `src/OcuPilot/Api/Turn.cls` (new) -- `HandleStart` (body via `Kernel.Utils.ReadRequestBody`, validation, `Restraint.Resolved`, `Agent.ResolveDefault`, reserve, then `Job.Start` from this unescalated frame, then 202) and `HandleProgress` (owner lookup, reconcile, 200 or 404).
- `src/OcuPilot/Api/Router.cls` -- the two routes and their thin wrappers.
- `src/OcuPilot/Api/Error.cls` -- `TURN.BADBODY`, `TURN.MESSAGE.REQUIRED`, `TURN.MESSAGE.LENGTH`, `TURN.BUSY`, `TURN.NOTFOUND`, `TURN.UNAVAILABLE`, `TURN.STOPPED`, `TURN.ABANDONED.READONLY`, `TURN.ABANDONED.PRIVILEGE`, `TURN.ABANDONED.JOBLOST`, `TURN.LIMIT.DURATION`, `TURN.LIMIT.TOKENS`, each with its sentence written once.
- `src/OcuPilot/Kernel/Provider/Catalog.cls` -- when `$System.Util.GetEnviron("OCUPILOT_ALLOW_TEST_PROVIDER")` is `1`, `Row`/`IsKnown` resolve a `turnprobe` row: adapter `OcuPilot.Test.TurnProvider`, endpoint `https://192.0.2.10/v1/messages`, key prefix `sk-ant-`. The row stays out of the provider list the screens read.
- `src/OcuPilot/Test/TurnProvider.cls` (new) -- an `Anthropic` subclass overriding `IssueHttpsPost`. It reads a script and writes records under `^IRIS.Temp.OcuPilotTurnProvider(<model tag>)`, selected by the request's `model`. Records: `$USERNAME`, `$ROLES`, the key header's SHA-256, `system`, the message contents, and the time. A script entry is a hang in seconds plus a reply body.
- `src/OcuPilot/Kernel/Utils.cls` -- correct the header to name the real production callers -- DW-23.
- `src/OcuPilot/Test/Dispatch.cls` -- seed the body by assigning `%request.Content`, not `InsertMimeData` -- DW-422.
- `scripts/check-objectscript.py` + `scripts/test_check_objectscript.py` -- DW-400 and the job's reach:
  - A literal route counts as covered only by a bounded match of its whole URL plus its method literal in the same class. Harness cases: `/turn` covered only by a `/turn/:id/progress` test is flagged; GET and POST on one URL with only a GET test is flagged.
  - New rule: `Kernel/Agent/` names no `OcuPilot.Port.*` other than `ProviderPort`, and no `Area`, `Screen` or `Api` handler. `JOB` appears only in `Kernel/Agent/Job.cls`.
- `scripts/ci-throwaway.sh` -- add `OCUPILOT_ALLOW_TEST_PROVIDER: "1"`, and its pin in `ui/tools/ci.test.mjs` if one exists.
- Tests (new classes, each under 500 lines; every job-spawning test signals, waits for, and on timeout terminates what it spawned in `OnAfterOneTest`):
  - `Test/TurnLoop.cls` -- in-process and live-safe, through `Test.ProviderPortProbe` and restraint seams: bounds, fallback, boundary re-checks, provider faults, caps, prompt precedence.
  - `Test/TurnStore.cls` -- live-safe, no spawn: reserve and busy, owner lookup, retention, caps.
  - `Test/TurnWire.cls` -- armed `OCUPILOT_ALLOW_TEST_PROVIDER` + `OCUPILOT_ALLOW_PRINCIPALS`: start, body, refused start, busy with a concurrent pair, poll shape, 404 for a second principal, identity, revoke and delete mid-turn, job lost, UTF-8.
  - `Test/TurnLong.cls` -- armed: the over-60-s row with the client timeout at 120 s.
  - `Test/TurnChain.cls` -- armed: DW-347. It restores the prior default and removes its entry.

**Acceptance Criteria:**

- Given each matrix row not marked BLOCKED, when the throwaway suite runs, then a named test observes it at the outermost surface it names: HTTP for route rows, the stub's records for provider rows.
- Given the tree, when `check-objectscript.py` runs, then the job's reach rule and the exact-route wire rule pass on the shipped code. Their harness shows each one failing on its fixture.
- Given every armed class on an unarmed instance, when it runs, then `OnBeforeAllTests` refuses by name and nothing is created.
- Given any test that spawns a job, when it exits by any path, then no process it spawned is still alive, and no turn row, slot lock or `^IRIS.Temp.OcuPilotTurnProvider` node of its own remains.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs (Rule 6):** AD-7 (job, polling, never mutates), AD-8 (grants checked at call time), AD-9 (spawn and escalation ordering), AD-11 (system prompt, delimited tool results), AD-12/39 (envelope, codes), AD-21 (bound SQL), AD-30 (switches re-read between steps), AD-31 (identity re-validation, bounds, sign-out), AD-33 (progress channel), AD-35 (no key in records), AD-37 (a deleted user abandons), AD-41 (bounds, one concurrent turn), AD-42 (the stored key goes only to the stored endpoint). Conventions: the 29-character cap, row version, route ordering, error shape, dates, opaque turn ids.

**Probed on the slot-A throwaway (2026-09-16, ZProbe classes, torn down):**

- `JOB` passes a 100,000-character argument, and the child inherits `$USERNAME`/`$ROLES`, also when spawned by a least-privileged user.
- A lock taken inside an AddRoles frame outlives the frame, blocks other processes, and frees on process exit.
- `CheckUserPermission($USERNAME, …)` reads current grants: 0 after role removal or deletion, 1 for a disabled user. `$SYSTEM.Security.Check` stays 1.
- A least-privileged process switching to `%SYS` gets `<PROTECT>`.
- An `EventClass` on `/api/ocupilot` saw `OnStartSession`/`OnLogin` at `/login` and nothing at a Bearer `/logout`.
- A 70-second request through the stock gateway answers 504 at 60.0 s.

**Decisions made in planning:**

- **Concurrency is a process lock, not a row flag.** The job holds `^OcuPilotTurnSlot(user)` for its whole life, so a crashed job frees the slot by exiting. The `queued` window is what closes the race between POST and the job's start.
- **A cross-process seam is armed by the environment.** Every existing stub is `^||` state that a job never sees. Worse, `ProviderPortProbe` falls back to the real adapter inside a job. An environment-armed catalog row reaches the job, and the credential route through the shipped `Definitions` class, without a production catalog change.
- **DW-333 precedence:** the override replaces the built-in prompt whole. This is the only reading that keeps both FR-24's "override" and AD-11's "nothing concatenated".
- **Values in, live reads after.** Starting state is passed in (AD-9). The switches, grants and definition are re-read at each step, per AD-30, AD-8 and AD-42 (a disabled or edited definition takes effect at the next call).
- **Numbers the ACs leave open:** 600 s, 500,000 tokens, 100 steps, a 15-minute retention (Story 5.1 needs at least 10), 16,000 characters. They are constants until Story 14.6's settings.

**Declined DW-250:** the job opens no output capture, and a fresh `JOB` has no `^||%capture`. The first caller that can nest a capture is 4.2's tool dispatch into `AdminPort`, so it belongs to 4-2.

**Integration:** no client consumer in this story; the first will be Story 4.5. Consumes: `ProviderPort.Invoke` (3.2/4.0), `Restraint.Resolved` (3.7), `State.Base` escalation (1.3), Router gates (1.6/1.8), `Kernel.Utils.ReadRequestBody`. Consumed-by:

- 4-2: the `DispatchTools` seam and the per-step privilege pairs.
- 4-4: context on the POST body.
- 4-5: the progress contract, `GuardedRequestStop`, busy.
- 4-6: `reply` and `error`.
- 4-8: provider faults as turn errors naming the step.
- 4-9: step records and usage.
- 5-1: the terminal state outliving the job.

**Spine (Rule 20, for the lead, not applied here):**

- AD-11 rule 1 gains the precedence sentence.
- AD-31 needs the G1/G2 amendments below.

## Verification

**Commands (live dev instance `ocupilot`, profile `ocupilot-slot-a`: compile, lint, and in-process classes that spawn nothing):**

- `iris_doc_load` with `server: "ocupilot-slot-a"`, `namespace: "HSCUSTOM"`, path `/Users/jbrandt/git/OcuPilot/.worktrees/epic-4/src/**/*.cls`, `compile: true` -- expected: clean.
- `uv run scripts/check-objectscript.py` and `uv run scripts/test_check_objectscript.py` -- expected: clean.
- `iris_execute_tests`, one class per call, each read back from `%UnitTest_Result`: `Test.TurnLoop`, `Test.TurnStore`, `Test.Utils`, `Test.AgentCredential` -- expected: green.
- `Test.TurnWire`, `Test.TurnLong`, `Test.TurnChain` on live -- expected: refused by name.
- `bash scripts/lint-docs.sh` -- expected: clean.

**Commands (slot-A throwaway only: HTTP, armed, principals, anything that spawns a job):**

- `sh scripts/ci-throwaway.sh up --dir /tmp/ocupilot-ci --project ocupilot-ci --web 52776 --super 1975`
- `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node ui/tools/ci-runner.mjs --container ocupilot-ci` -- expected: all green.
- `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` -- expected: non-zero checks, all pass.
- `sh scripts/ci-throwaway.sh down --dir /tmp/ocupilot-ci --project ocupilot-ci`, only for an `up` this run made.

**Planned mutations (Rule 19; record the observed red next to each):**

- Over 60 s: `HandleStart` calls `Loop.Run` in-process instead of `Job.Start` -> `TurnLong` red (the POST answers 504).
- Identity: `Job.Start` wrapped in an AddRoles frame -> `TurnWire` identity leg red.
- Busy: `GuardedReserve` skips the queued-window check -> the concurrent-pair leg red.
- 404: `GuardedForOwner` drops the user predicate -> the second-principal leg red.
- Boundary checks: remove the grants check -> the revoke leg red. Remove the read-only comparison -> the `TurnLoop` read-only leg red.
- Bounds: compare with `>` against a one-iteration cap -> the `TurnLoop` fallback leg red.
- Prompt: concatenate constant and override -> the `TurnLoop` precedence leg red.
- DW-347: the stub hashes `""` -> `TurnChain` red.
- DW-400: revert to substring keying -> the harness prefix case red.
- DW-422: drop the `Content` assignment -> the `AgentCredential` dispatch legs red.
- Job reach: reference `OcuPilot.Port.AdminPort` from `Loop.cls` -> the harness rule red.

## Auto Run Result

Status: blocked
Blocking condition: intent gap

**G1 -- Story 4.1 AC 4 / AD-31 "re-checks that the user is still enabled".**

- **Why it is unimplementable:** a least-privileged job cannot observe its own account's `Enabled` flag on 2026.2 without the elevation AD-8 forbids.
- **Evidence** (probed on the slot-A throwaway):
  - `$SYSTEM.Security.CheckUserPermission($USERNAME, "%Admin_Operate", "USE")` answered 1 for a disabled user. It answered 0 after role removal and after deletion.
  - `$SYSTEM.Security.Check` answered 1 throughout.
  - The job's `Set $Namespace="%SYS"` raised `<PROTECT>`, so `Security.Users` is unreachable. AD-9's escalation adds only `%DB_OCUPILOT`.
- **Recommended amendment** (AD-31 and the AC): "re-checks that the user still exists and still holds the privilege each remaining step needs, read from the user's current grants. A disabled account is not observable to the job; its turn ends at the wall-clock bound, and it can confirm no write (AD-7/AD-40)."
- **Alternative:** a second, narrow elevation that reads `Security.Users.Enabled`. It contradicts AD-8's "the one permitted elevation is AD-9's" and would need an Update-intent re-architecture.

**G2 -- Story 4.1 AC 6 / AD-31 "Sign-out abandons the user's running turns".**

- **Why it is unimplementable:** no OcuPilot code runs when a JWT session ends, so the instance cannot see a sign-out.
- **Evidence** (probed): with `EventClass` set on `/api/ocupilot`, `/login` fired `OnStartSession`/`OnLogin`, and a Bearer `POST /logout` (200, token then 401) fired no `OnLogout` and no `OnEndSession`. The token session is `%SYS.TokenAuth` in `^SECURITY`, reachable only through `[Internal]` methods the job cannot call.
- **Options:**
  - (a) Recommended. OcuPilot's own sign-out first sends `POST /api/ocupilot/turn/abandon`, which abandons every running turn the caller owns (`abandoned` `TURN.ABANDONED.SIGNOUT`). `session.ts` `signOut()` :660 sends it before `/logout`, best-effort under DW-5. A session ended any other way is covered by the bounds and by confirm needing a live session. This adds one route and a client edit to 4.1.
  - (b) A poll lease: the job abandons at the next boundary when no poll has renewed the turn for N seconds. It covers every way a session ends, but it also abandons a turn whose tab was closed or throttled in the background.
  - (c) Both.

**Not blocking; confirm in the same amendment:** the DW-333 precedence (the override replaces the built-in prompt, never concatenated; add a sentence to AD-11 rule 1), and the planning numbers under Design Notes. On re-plan, replace only the two BLOCKED matrix rows and any AC wording the amendment changes.
