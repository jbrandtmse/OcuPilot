---
title: 'The tool registry, its one gate point, and the three shell reads'
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

**Problem:** The turn job answers every `tool_use` with a fixed `TOOL.UNAVAILABLE` and advertises no tools, so the agent cannot read anything a screen reads. The registry lists tools but nothing dispatches them. Its two tool sources disagree on `View`, and a model-supplied `maxRows` reaches the port with no bound.

**Approach:** The job advertises every registered tool in the cross-vendor schema subset. It answers each call through one dispatcher: resolve, identity, the one governance gate point, the restraint verdict for write tools, the tool's privilege pairs against the user's current grants, argument validation, and then the tool's uniform `View`, in process. The result goes back as delimited `tool_result` content. Three shell read tools, a bounded SQL read path and the harvested window guard complete the read side.

## Boundaries & Constraints

**Always:**

- A tool runs in the job's process and calls the management surface directly. No tool or dispatcher code issues an HTTP request (AD-1).
- The dispatcher consults the gate point after identity and before any port, restraint read, pair check or tool. In Release 1 the gate allows every registered tool, because prohibited actions are absent from the set (AD-10, AD-22).
- The pairs a tool declares are checked with `$SYSTEM.Security.CheckUserPermission($USERNAME, …)`. A denial is reported as a tool result and never retried (AD-8, AD-31). The boundary's any-admin check from 4.1 stays.
- A tool result reaches the model only as the content of a `tool_result` block. It is the result JSON, or `{code, detail?}` on failure, and never a `reason` or vendor text. The system prompt stays `Prompt.Builtin()` or the definition's override, whole (AD-11, AD-39).
- An emitted tool schema obeys the harvested subset verbatim. The top level is `{type:"object", properties, required, additionalProperties:false}`; a property uses only `type, description, enum, items, minimum, maximum, minItems, maxItems`. The validator keeps enforcing `maxLength`, and emission moves it into the property's description.
- On the wire a tool name has its dots replaced by underscores, so it matches `^[a-zA-Z0-9_-]{1,64}$`. Everywhere else the tool keeps its dotted name (Conventions › Tool naming).
- Every tool result is capped at `Limits.TOOLROWS` (200) rows and `Limits.TOOLRESULTMAXLENGTH` (65,536) characters, and reports `truncated` (AD-24, AD-36). Secret fields stay stripped by `Screen.Read.Execute`.
- SQL binds every value with `?`. Its text is a call-site literal (AD-21).

**Never:**

- Open an output capture around a tool call, or anywhere outside `Port/AdminPort.cls`.
- Let `Kernel/Agent/` name any `OcuPilot.Screen.*` class other than `OcuPilot.Screen.Tool.Registry`. Let anything other than `Kernel/Agent/Dispatch.cls` call `Registry.InvokeTool`.
- Name a restraint code outside `Kernel/Restraint.cls` and `Api/Error.cls`; the dispatcher passes `v("code")` through.
- Build a write tool, a proposal, the ledger row, screen context, or client panel work (Stories 4.3–4.9, Epic 5). Change AD-7's Rule.
- Run a job-spawning, principal-creating or armed class on the live `ocupilot` instance.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Advertise | A turn starts | Every provider request carries one tool per registered tool, in name order: wire name, description, and a schema in the subset. A `maxLength` bound is stated in the property's description | The registry cannot list, or a schema breaks the subset: the turn ends `failed` `TURN.UNAVAILABLE`, logged, with no provider call |
| Read call | `tool_use` names a registered read tool with valid input | One `tool_result` with the same `tool_use_id`, `is_error` false, and the tool's result JSON as content. A `tool` step is recorded under the dotted name with status ok | No error expected |
| Several calls | One reply carries N `tool_use` blocks | N `tool_result` blocks, in the same order, in one user message holding no text block | No error expected |
| Unknown | The wire name matches no tool | `is_error`, `{"code":"TOOL.UNKNOWN"}`. Nothing is invoked | Turn continues |
| Identity | `$USERNAME` differs from the turn's user | Every call answers `TOOL.UNAVAILABLE`, logged. Nothing is invoked | Turn continues |
| Gate denies | The gate point answers not allowed (probe) | `TOOL.DENIED`. No restraint read, pair check or tool. The tool is still advertised on the next request | Turn continues |
| Write, restrained | Kind `write`. `Verdict` answers blocked with a code / answers an error status, even with `blocked` 0 | That code / `TOOL.UNAVAILABLE`. The tool is not invoked (DW-387) | Turn continues |
| Pair denied | The user's current grants lack a declared pair, including a role removed after the job started | `AUTH.NOPRIVILEGE`, `detail.failedPair` `resource:permission`. The tool is not invoked | Not retried; turn continues. Pairs that cannot be read answer `TOOL.UNAVAILABLE` and invoke nothing |
| Arguments | `input` is not an object, or fails the input schema | `TOOL.ARGUMENTS`, `detail.problem`. No port is called | Turn continues |
| Tool fault | `View` answers an error with a fault | `{code, detail?}` from the fault, whatever the port's HTTP status (DW-298) | Turn continues |
| Row cap | `maxRows` absent or above 200 | The port or store is asked for at most 201 rows. At most 200 rows are returned, with `truncated` true when any were cut | No error expected |
| Size cap | The serialized result exceeds 65,536 characters | Trailing rows are dropped until it fits, with `truncated` true. A result with no `rows` that still exceeds answers `TOOL.RESULTTOOLARGE` | Turn continues |
| Shell reads | `shell.instance.read`, `shell.namespaces.read`, `shell.privileges.read`, input `{}` | The JSON `Api.Instance`, `Api.Namespaces` and `Api.Navigation` `Payload` answer, unchanged. No pairs beyond the router's gate | No error expected |
| Prompt | Any turn that calls a tool | Every request's `system` is unchanged by tool results. Tool content appears only inside `tool_result` | No error expected |
| Integration (consumer: the turn job, over the wire) | Armed. A turn is posted as the suite's account. The stub answers call 1 with `shell_instance_read` and `permissions_users_read`, then text | Call 2 carries both results: the instance's own `instanceName`, and user rows. The turn completes with two ok tool steps. Call 1's recorded `tools` lists every wire name | No error expected |
| Revoked mid-turn | Armed principal with two roles. The role carrying `%Admin_Secure:USE` is removed during call 1, which answers `permissions_users_read` | `AUTH.NOPRIVILEGE` `%Admin_Secure:USE`, although the job's `$ROLES` still names the role. The turn reaches call 2 and completes | No error expected |
| SQL bound | A declared state read with `maxRows` n | The store runs `SELECT TOP ? …` bound to n+1. `BoundedWhere` window: 0 means 24 h, 1–720 explicit, -1 keyed (no time predicate). Any other value is refused naming the bound. The cutoff is bound as a parameter, never in the text | Refusal is a problem string, no SQL run |

</intent-contract>

## Code Map

- `src/OcuPilot/Kernel/Agent/Loop.cls` -- `DispatchTools` :38-58 is the seam replaced here. `Run` :68: `Kill tTools` and `Invoke` :100-101. `Boundary` :149 (`HoldsAnyResource` :214 stays). `AnswerTools` :268: dispatch :285, step append :300. The header doc :1-13 says no tools are advertised.
- `src/OcuPilot/Kernel/Agent/Job.cls` -- `Run` :55 → `Loop.Run` :75. `src/OcuPilot/Api/Turn.cls` :88 passes `Router.#ADMINRESOURCES`. `Kernel/Agent/Limits.cls` holds the parameters :11-40.
- `src/OcuPilot/Screen/Tool/Registry.cls`:
  - `ListTools` :78 → `{name, kind, class, descriptor}`; `Resolve` :140.
  - `ValidateArguments` :175, `SchemaProblem` :257, `SCHEMAKEYWORDS` :36 (includes `maxLength`, from DW-279).
  - Seams used by fixtures: `ToolPackage`, `ExcludedPackage`, `ScreenRegistryClass`, `ReadToolClass`.
  - The header :1-4 says nothing dispatches.
- `src/OcuPilot/Screen/Tool/Base.cls` -- declares `TOOLNAME`, `KIND`, `DESCRIPTION` and `InputSchema` only. Doc :8-9 says nothing dispatches.
- `src/OcuPilot/Screen/Tool/Read.cls`:
  - `InputSchema` :49; criteria `maxLength` :95-96.
  - `View(pDescriptor, pArgs, pContextCap, .pResult)` :119 drops `tHttp`/`tFault` at :146.
- `src/OcuPilot/Screen/Tool/ErrorRead.cls`:
  - `View(pArgs, pContextCap, .pResult)` :85 passes `maxRows` unbounded at :99-100.
  - The schema says "no ceiling" at :70. `DESCRIPTORCLASS` :40 is `LogErrorList`, whose pairs are `%Admin_Operate:USE`, `%DB_IRISSYS:READ`.
- `src/OcuPilot/Screen/Read.cls`:
  - `Execute(pDescriptor, pMaxRows, .pResult, .pHttpStatus, .pFault, .pCriteria)` :140. `DEFAULTMAXROWS` 1000 :40. It sends `tMax+1` to the port :171 and has no ceiling.
  - `StateRows` :236 calls `STATEROWSMETHOD` :84/:246 with no bound; the doc there says "unbounded here".
- `src/OcuPilot/Screen/Gate.cls` -- `RequiredPairs(pDescriptor, .pResolved)` :89 (descriptor pairs plus the classic resource), `HoldsPrivilege` :143 (process check). Descriptor permissions are words (`USE`, `READ`), which `CheckUserPermission` accepts.
- `src/OcuPilot/Api/Instance.cls` `Payload` :31, `Api/Namespaces.cls` `Payload` :131 (`scope` is `Kernel.Scope.Current()`, which is the job's namespace in a job), `Api/Navigation.cls` `Payload` :19. Each is writer-free and reads no `%request`. `Port/LogSourcePort.cls` already names `Api.Namespaces.GlobalDatabase`.
- `src/OcuPilot/Kernel/Restraint.cls`:
  - `Verdict(pUserName, pDefinitionId, .pVerdict)` :78.
  - Doc :11-12 says the rule reads ObjectScript only; :16-17 says the Governance folder stays empty.
  - Current callers: `Resolved` :174, `Install/Smoke.cls` :705.
- `src/OcuPilot/Api/Error.cls` -- `AUTHNOPRIVILEGE` :111, `TOOLUNAVAILABLE` :659 (no sentence), `TurnCodes` :706 and `ReasonForTurn` :713 (the pattern to copy), `Render` :934. Detail key convention: `failedPair`.
- `src/OcuPilot/Kernel/Provider/Base.cls` :105-109 -- tool array shape `pTools(n,"name"|"description"|"inputSchema")`. `Anthropic.cls` :70-80 sends `tools` only when the count is above 0; `SchemaOf` :183.
- `src/OcuPilot/Kernel/State/Agent.cls` -- `GuardedList` :414 (`SELECT ID … ORDER BY ID`), `GuardedScreenRows` :455. `Hold.cls` `GuardedScreenRows` :126 is also called by `Api/Switches.cls` :331. `Base.cls` `GuardedIdsWhere` :584 binds one parameter.
- `scripts/check-objectscript.py`:
  - `RESTRAINT_CODE_RE` :749, `check_restraint_containment` :764, `AGENT_REACH_RE` :814 (bans all `OcuPilot.Screen.*`, strings included), `check_agent_job_reach` :821.
  - `SCAN_ROOTS` :181 already includes `ui`. `CHECKS` :1672.
  - Harness: `FixtureTreeCase` :44, `TestAgentJobReachRule` :931, `TestRestraintContainment` :1159, shipped-tree tests :1429-1484.
- Tests to follow or change:
  - `Test/TurnProvider.cls`: `Script` :21, `Recorded` :46 (fields at :94-106; `tools` is parsed at :91 but never stored), `ToolUseReply(pName, …)` :63 (fixed id, `input {}`).
  - `Test/TurnWireFixture.cls` `EnsurePrincipal` :57, `SetRoleResources` :90 (one role).
  - `Test/TurnLoop.cls` `Reply` :116; `Test/TurnLoopProbe.cls` :23/:40-48.
  - `Test/ReadTool.cls` `TestNothingHereDispatches` :627; `Test/Read/ToolRegistry.cls`, `Test/ErrorReadProbe.cls`, `Test/PortFixture.cls`, `Test/AgentFixture.cls` `CreateDefinition` :23 / `RemoveProbeDefinitions` :79.
  - `Test/AdminPortFault.cls` :143-158 pins that an empty outer capture passes.
- Vendor and harvest evidence, read-only:
  - `irissys/%SYS/Capture.int` :10 refuses only when `^||%capture` holds buffered output.
  - `harvest/iris-session-agent.md` :87 (the subset rule) and :97 (the guard). Source: `/Users/jbrandt/git/iris-session-agent/src/SessionAgent/Tool/Search/Base.cls` :66-90 and :180-244.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Screen/Tool/Base.cls` -- declare one contract for both sources (DW-295):
  - `View(pDescriptor, pArgs, pContextCap, Output pResult, Output pHttpStatus, Output pFault) As %Status`
  - `ResultSchema(pDescriptor) As %DynamicObject`
  - `Description(pDescriptor) As %String`, defaulting to `DESCRIPTION`
  - `PrivilegePairs(pDescriptor, Output pResolved) As %List`, defaulting to none and resolved.
  Replace the "Nothing here dispatches" paragraph.
- `src/OcuPilot/Screen/Tool/Read.cls` -- conform to the contract:
  - `View` returns the executor's status and fault, and sends `maxRows` as min(the argument or the cap, the cap).
  - `Description` names the descriptor's `toolIdentifier`. `PrivilegePairs` is `Screen.Gate.RequiredPairs`.
  - `ResultSchema` is `{fields, rows, truncated}`.
- `src/OcuPilot/Screen/Tool/ErrorRead.cls` -- the same contract (DW-298). `maxRows` is clamped to the cap before `LogSourcePort.Errors`, and the schema's "no ceiling" text is replaced. `PrivilegePairs` comes from `DESCRIPTORCLASS`.
- `src/OcuPilot/Screen/Tool/ShellInstance.cls`, `ShellNamespaces.cls`, `ShellPrivileges.cls` (new) -- `shell.instance.read`, `shell.namespaces.read`, `shell.privileges.read`. Each has kind `read`, the closed empty schema, and `View` answering its handler's `Payload` unchanged, with a result schema for that payload and no pairs.
- `src/OcuPilot/Screen/Tool/Registry.cls` -- add:
  - `WireName(pName)` and `ResolveWire(pWireName, Output pTool)`.
  - `ProviderTools(Output pTools)` in the shape `Provider/Base.cls` expects. Each emitted schema is checked against `EMITTEDKEYWORDS` (the verbatim subset), and `maxLength` moves into the description. Any other keyword fails the listing.
  - `RequiredPairs(pTool, Output pResolved)`.
  - `InvokeTool(pTool, pArgs, pContextCap, Output pResult, Output pHttpStatus, Output pFault)`.
  Correct the header.
- `src/OcuPilot/Kernel/Agent/Limits.cls` -- `TOOLROWS` 200, `TOOLRESULTMAXLENGTH` 65536.
- `src/OcuPilot/Api/Error.cls` -- `TOOL.UNKNOWN`, `TOOL.DENIED`, `TOOL.ARGUMENTS`, `TOOL.RESULTTOOLARGE`, and a sentence for `TOOL.UNAVAILABLE`; add `ToolCodes()` and `ReasonForTool(pCode)`.
- `src/OcuPilot/Kernel/Governance/Gate.cls` (new) -- `Decide(pTool, pKind, pUser, pArgs, Output pDecision)` sets `allowed` and `code`. Release 1 allows everything. Story 14.2's policy attaches here.
- `src/OcuPilot/Kernel/Agent/Dispatch.cls` (new):
  - `Advertise(Output pTools)`.
  - `Answer(pKey, pUser, pDefinitionId, pToolUses, pLimitsClass, Output pResults, Output pNames)`, which runs the matrix order, renders content and applies both caps.
  - Seams `RegistryClass`, `GateClass`, `Restraint(pUser, pDefinitionId, .pVerdict)` (`Kernel.Restraint.Verdict`), and `HoldsPair(pUser, pResource, pPermission)` (`CheckUserPermission`). Production overrides none.
- `src/OcuPilot/Kernel/Agent/Loop.cls` -- add a `DispatchClass()` seam. `Run` advertises once before the loop and passes `.tTools` to every `Invoke`. `DispatchTools` gains the definition id and limits and delegates to `Answer`. Steps carry the dotted name. Correct the header.
- `src/OcuPilot/Kernel/State/Base.cls` -- `BoundedWhere(pWindowHours, pTimeColumn, ByRef pParams, Output pProblem, pPredicates...) As %String`: the harvested guard, renamed, with the matrix's modes. `pTimeColumn` must match `^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)?$`. It runs no SQL and does not escalate.
- `src/OcuPilot/Kernel/State/Agent.cls`, `Hold.cls` -- `GuardedScreenRows(Output pRows, pMaxRows As %String = "")`. A positive value reads ids through `SELECT TOP ? ID … ORDER BY ID`; `""` keeps the unbounded list `Api.Switches` uses.
- `src/OcuPilot/Screen/Read.cls` -- `StateRows` passes `tMax+1` to the store. Replace the "unbounded here" paragraph.
- `src/OcuPilot/Kernel/Restraint.cls` -- replace the two doc sentences the Code Map names.
- `scripts/check-objectscript.py` + `scripts/test_check_objectscript.py`:
  - `check_agent_job_reach` admits `OcuPilot.Screen.Tool.Registry` alone.
  - New `check_tool_dispatch`: `InvokeTool` is named only in `Screen/Tool/Registry.cls` and `Kernel/Agent/Dispatch.cls` (Test/ excluded). `%Net.HttpRequest` or an `/api/` literal is refused under `Screen/Tool/`, under `Kernel/Governance/` and in `Kernel/Agent/Dispatch.cls`. `BeginCapture` or `%SYS.Capture` is refused outside `Port/AdminPort.cls`.
  - New `check_state_sql_literal`: under `Kernel/State/`, outside `Base.cls` where the helpers are defined, the SQL argument of every `Guarded*Where*` or `GuardedExecute*` call is a string literal.
  - `check_restraint_containment` (DW-393): also matches a code's tail (`.KILLSWITCH.GLOBAL`, `READONLY.ENFORCED`, …) and the parameter names without `#`.
  - `check_restraint_containment` (DW-394): also scans `ui/src` `.ts` and `.html`, excluding `.spec.ts`.
  - Harness: each change red on its fixture; the shipped tree passes.
- `src/OcuPilot/Test/TurnProvider.cls` -- record each request's `tools`. `ToolUseReply` scripts several calls, each with its own name, id and input.
- `src/OcuPilot/Test/TurnWireFixture.cls` -- a principal holding two roles, and removal of the second role.
- `src/OcuPilot/Test/ReadTool.cls` -- retire `TestNothingHereDispatches`, and move view calls to the new signature.
- New tests, each class under 500 lines. A class that spawns a job reaps it and its rows on every exit path.
  - `Test/ToolDispatch.cls`, with fixtures `Test/DispatchTool/` (a counting read tool, a counting write tool and their registry) and `Test/ToolDispatchProbe.cls`. Live-safe. Covers the rows Unknown through Size cap, and that the production gate allows every live tool.
  - `Test/ToolEmit.cls` -- live-safe, runs no tool. Every live tool's wire name, emitted schema, result schema and description. An emission corpus of each forbidden keyword plus `maxLength`. Read and ErrorRead clamping and fault passing, over fixtures. `ToolCodes` sentences.
  - `Test/ToolShell.cls` -- live-safe. Each shell tool equals its `Payload` and conforms to its result schema.
  - `Test/TurnTools.cls` -- live-safe, in process through `TurnLoopProbe` with a `DispatchClass` seam. Rows Advertise (including the listing failure), Several calls and Prompt.
  - `Test/StateBound.cls` -- live-safe. `BoundedWhere` modes, refusals, and a cutoff that never appears in the text.
  - `Test/ToolRoundTrip.cls` -- throwaway only. Every real tool through `InvokeTool` conforms to its result schema, or answers a fault with a code. Over three probe definitions, `maxRows` 1 answers 1 row, truncated, from a store fetch of 2 ids.
  - `Test/ToolWire.cls` -- armed with `OCUPILOT_ALLOW_TEST_PROVIDER` and `OCUPILOT_ALLOW_PRINCIPALS`. Rows Integration and Revoked mid-turn.

- Lead, spec gate: a test asserts that no registered tool's canonical name contains an underscore, so the wire mapping in the spine's Tool naming row (each dot becomes an underscore) stays reversible.

**Acceptance Criteria:**

- Given each matrix row, when the suites run, then a named test observes it at the outermost surface it names: the stub's recorded requests for the Advertise, Prompt and Integration rows, the `tool_result` content for the dispatch rows, and the store's fetch for SQL bound.
- Given the registry, when it lists tools, then every tool declares a name, kind, description, input schema and result schema. The three shell reads appear beside the per-screen read tools, and no two tools share a wire name.
- Given the tree, when `check-objectscript.py` runs, then the new and changed rules pass on the shipped code, and the harness shows each one failing on its fixture.
- Given every armed class on an unarmed instance, when it runs, then `OnBeforeAllTests` refuses by name and nothing is created.
- Given any test that spawns a job or creates a principal or definition, when it exits by any path, then nothing it created remains: no live process, turn row, step, signal, slot lock, stub record, role or probe definition.

## Spec Change Log

- 2026-09-16, lead at spec gate: Conventions › Tool naming amended in the spine (wire spelling replaces dots with underscores; the dotted name stays canonical); one Tasks item added to pin reversibility. DW-250 closed wontfix-theoretical at the gate; DW-390 stays owned and is adjudicated against the delivered caller probe.

## Review Triage Log

## Design Notes

**Governing ADs (Rule 6):**

- AD-1: in-process tools.
- AD-5: tool identity from the descriptor.
- AD-8, AD-29, AD-31: pairs at call time, from current grants.
- AD-10, AD-22: the gate point; prohibited actions are absent.
- AD-11: delimited results; the prompt is unchanged.
- AD-21: bound, literal SQL.
- AD-24, AD-36: the row and size caps; one read serves screen and tool.
- AD-30, AD-40: restraint at the write-tool boundary. Confirm still re-checks at the write in Epic 5.
- AD-39: the machine half in tool results.
- AD-9: the guard lives in `Kernel/State`, because the checker refuses a State class naming `Screen`.
- AD-48: `ErrorRead` stays summary-only.

Conventions: Tool naming, Error shape, 29-character cap. AD-7's Rule is unchanged.

**Probed on live `ocupilot`, 2026-09-16 (read-only, nothing spawned):**

- `Restraint.Verdict` answers OK, not blocked, for a 600-character definition id, a 40,000-character user, `$Char(0)` and `"1||2"`. No input makes its read fail.
- `SELECT TOP ? … WHERE Name %STARTSWITH ?` binds both parameters on this build.
- The tool-name regex `^[a-zA-Z0-9_-]{1,64}$` is taken from platform.claude.com's "Define tools" page. Its API primer says `{1,128}`; the stricter one is used.

**Decisions made in planning:**

- **One gate point, two layers.** `Kernel.Governance.Gate` is AD-22's policy point, reached only from `Dispatch`, and `InvokeTool` has one caller. Restraint for write tools and privilege pairs follow it as separate steps: they are AD-30's and AD-8's gates, not policy.
- **Current grants for pairs.** `$System.Security.Check` reads the job's frozen `$ROLES`, so a pair revoked mid-turn would pass it. The ports keep their own process check.
- **Wire names.** The provider forbids dots, and replacing `.` with `_` is reversible under the name grammar, so the one tool array uses underscore names. The dispatcher resolves by comparing wire names, never by translating back.
- **`maxLength` in descriptions.** DW-279's bound stays enforced and visible to the model, while the emitted schema stays in the verbatim subset.
- **Shell tools call the handlers' `Payload`.** Each payload is writer-free and request-free. `LogSourcePort` already names `Api.Namespaces`, so this adds no new direction. In a job, `scope` reads the job's own namespace; Story 4.4 carries the screen's.
- **The SQL guard's population.** "SQL-backed read" means OcuPilot-authored SQL. The vendor's queries behind `AdminPort` cannot bind caller values that OcuPilot controls.
  - Today the only such read a tool reaches is the definitions list. Its runaway bound is `TOP ?` at the query.
  - The harvested window builder has no time-indexed search to bound yet. It ships tested and unconsumed (inference: Story 4.9's ledger view is its first consumer).
- **Result size.** `TOOLRESULTMAXLENGTH` cuts rows. Per-field cuts belong to Story 4.4.

**Ledger inbox (Rule 17):**

- DW-295 is addressed by `Base.View`. DW-298 by the clamp and the fault pass-through. DW-387 by the dispatcher's write branch, driven by a fixture write tool. DW-393 by the widened regex. DW-394 by scanning `ui/src`.
- **Declined DW-250:** neither the job nor the dispatcher opens a capture. `%SYS.Capture` refuses only an outer capture already holding output (`Capture.int` :10). No shipped class outside `AdminPort` opens one, and `check_tool_dispatch` keeps it that way. It would become real if a caller wrote output inside a capture and then called a tool.
- **Declined DW-390:** no input drives `Verdict`'s read failure (probed above), and a real one needs damaged protected storage. Both callers close on the error status itself: the loop's boundary, and the dispatcher, pinned by a probe that answers an error with `blocked` 0.

**Integration:**

- Consumer: the turn job (Story 4.1's loop), observed over the wire by `ToolWire` (the Integration row).
- Consumes:
  - 4-1: `Loop.DispatchTools`, `Job`, `Turn`
  - 2-3: `Screen.Read` and `Tool.Read`
  - 2-12: `ErrorRead` and `LogSourcePort`
  - 1-8, 1-9, 1-11: the three `Payload` methods and `Screen.Gate`
  - 3-7: `Restraint.Verdict`
  - 3-2: `ProviderPort` and Anthropic's tool array
- Consumed-by:
  - 4-4: `TOOLROWS` becomes the operator's context cap; per-field cuts; the scope namespace for tools
  - 4-5: tool step names and codes for the cards
  - 4-7: navigation tools register through the registry
  - 4-9: one ledger row per `Answer` call, with `RequiredPairs` as the resource required, and `BoundedWhere` for the ledger view
  - 5-1: write tools pass the restraint branch before minting
  - 5-3: the acting-on-behalf marker threads through `Dispatch`
  - 5-4: a denied tool's `AUTH.NOPRIVILEGE` result
  - 14-2: the policy attaches at `Gate.Decide`

## Verification

**Live dev instance `ocupilot`, profile `ocupilot-slot-a` (compile, lint, in-process classes that spawn nothing and create no principal):**

- `iris_doc_load` with `server: "ocupilot-slot-a"`, `namespace: "HSCUSTOM"`, path `/Users/jbrandt/git/OcuPilot/.worktrees/epic-4/src/**/*.cls`, `compile: true` -- expected: clean.
- `uv run scripts/check-objectscript.py` and `uv run scripts/test_check_objectscript.py` -- expected: 0 problems; harness OK.
- `iris_execute_tests`, one class per call, each read back from `%UnitTest_Result` before the next -- expected: green.
  - New: `Test.ToolDispatch`, `Test.ToolEmit`, `Test.ToolShell`, `Test.TurnTools`, `Test.StateBound`.
  - Existing: `Test.ReadTool`, `Test.ErrorLog`, `Test.TurnLoop`, `Test.TurnStore`.
  - `Test.Restraint` and `Test.SwitchState` write the instance's switches, so they run only in the throwaway sweep below.
- `Test.ToolWire` on live -- expected: refused by name.
- `bash scripts/lint-docs.sh` and `cd ui && npm test` -- expected: clean and green.

**Slot-A throwaway only (HTTP, jobs, principals, probe definitions, armed classes):**

- `sh scripts/ci-throwaway.sh up --dir /tmp/ocupilot-ci --project ocupilot-ci --web 52776 --super 1975`
- `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node ui/tools/ci-runner.mjs --container ocupilot-ci` -- expected: all green, including `Test.ToolRoundTrip` and `Test.ToolWire`. A client-side timeout is not a failure and is never re-submitted.
- `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` -- expected: non-zero checks, all pass.
- `sh scripts/ci-throwaway.sh down --dir /tmp/ocupilot-ci --project ocupilot-ci`, only for an `up` this run made.

**Planned mutations (Rule 19; record the observed red beside each):**

- Advertise: `Run` keeps `Kill tTools` -> `TurnTools` advertise leg red.
- Wire names: `WireName` keeps the dots -> `ToolEmit` wire-name leg red.
- Emission: `ProviderTools` leaves `maxLength` in the schema -> `ToolEmit` subset leg red.
- Read call / Integration: `Answer` renders `is_error` for every call -> `ToolWire` integration red.
- Several calls: results reversed -> `TurnTools` order leg red.
- Unknown: resolution falls back to the first tool -> `ToolDispatch` unknown leg red.
- Identity: the `$USERNAME` check removed -> identity leg red.
- Gate: `InvokeTool` called before `Decide` -> the gate-denial leg red (the fixture counts one call). `Gate.Decide` answers 0 -> the every-live-tool leg red.
- Restraint: the write branch skipped -> the restrained leg red. The branch trusts `blocked` and not the status -> the error-with-blocked-0 leg red.
- Pairs: `HoldsPair` uses `$System.Security.Check` -> `ToolWire` revoked leg red. Pair check removed -> `ToolDispatch` pair leg red.
- Arguments: validation skipped -> arguments leg red.
- Tool fault: the fault's `reason` rendered -> fault-shape leg red.
- Row cap: `Read.View` passes the model's `maxRows` -> `ToolEmit` clamp leg red. `ErrorRead` likewise -> its clamp leg red.
- Size cap: cap check removed -> size leg red.
- Shell reads: `ShellNamespaces.View` drops `writable` -> `ToolShell` red.
- Prompt: `Run` appends the last tool result to the system prompt -> `TurnTools` prompt leg red.
- SQL bound: `GuardedScreenRows` drops `TOP ?` -> `ToolRoundTrip` fetch-count leg red. `BoundedWhere` writes the cutoff into the text -> `StateBound` red. The 720 check removed -> `StateBound` refusal leg red.
- Checker: each rule change reverted -> its harness case red. DW-393 and DW-394 fixtures reverted -> their cases red.
- AC 4: `ToolWire.OnBeforeAllTests` without its arming guard -> `check-objectscript.py` rule 17 red.
- AC 5: `ToolWire` teardown skips role removal -> its teardown assertion red.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

**For the lead (Rule 20 candidates, decided in planning and not written to the spine):**

- Conventions › Tool naming: the wire spelling replaces dots with underscores, because the provider's tool-name grammar refuses dots.
- The harvested bounded-where guard lives in `Kernel/State/Base.cls`, not `Screen/Tool/`, because `check_state_package_isolation` refuses a State class naming `Screen`.
- The emitted schema moves `maxLength` into the property's description, so the validator's subset and the harvested verbatim subset differ by that one keyword.
