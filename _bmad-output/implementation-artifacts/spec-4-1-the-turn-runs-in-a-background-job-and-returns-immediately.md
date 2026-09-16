---
title: 'The turn runs in a background job and returns immediately'
type: 'feature'
created: '2026-09-16'
status: 'ready-for-dev'
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

## Spec Change Log

- 2026-09-16, plan halt G1/G2 answered by the orchestrator under the owner's standing autonomy instruction. AD-31 amended (existence and privilege from current grants; a 120 s poll lease covers disablement and abandoned tabs; OcuPilot's sign-out calls `POST /turn/abandon` because a token logout fires no session event; limits as named constants). AD-11 rule 1 amended for DW-333 (the override replaces the built-in prompt whole). Story 4.1's AC 4 and AC 6 in `epics.md` amended to match. The Disabled user and Sign-out matrix rows replaced; a Lease row added; the Bounds row caps iterations at 100. DW-250 declined and re-owned to 4-2. Re-plan must re-probe the disabled-account Bearer poll on the throwaway.

## Review Triage Log

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

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

- **Disabled-account probe, for the lead:** the instance answers a disabled account's Bearer poll and refresh (Design Notes). The pre-authorized fallback applies: disablement is bounded only by the 600 s wall clock, and the lease does not cover it.
- **AD-31 needs a correction at its origin before Epic 5 plans confirm.** Its clause "a write still fails at the authenticated confirm (AD-7)" does not hold for a Bearer-authorized confirm (inference): every Bearer request the probe sent as the disabled account was answered. Nothing in 4.1 depends on it.
- Re-planned only what the answers required: the lease, sign-out route and client edit, limits in one class, grants from a passed resource list, override precedence in the port.
