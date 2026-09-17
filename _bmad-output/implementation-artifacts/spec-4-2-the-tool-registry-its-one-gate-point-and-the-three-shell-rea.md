---
title: 'The tool registry, its one gate point, and the three shell reads'
type: 'feature'
created: '2026-09-16'
status: 'done'
baseline_revision: '84a9c94c7ffee5039f70161c18e86aebba81c257'
baseline_commit: '84a9c94c7ffee5039f70161c18e86aebba81c257'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings:
  - multiple-goals
  - oversized
deferred:
  - summary: >-
      BoundedWhere has no guarded helper that runs its fragment with a parameter array, and rule 21 refuses joining the fragment to a literal outside Kernel/State/Base.cls.
    evidence: |-
      Every Guarded* helper in Base.cls binds 0-3 scalar parameters; BoundedWhere returns text plus a %DynamicArray. Its first consumer (Story 4.9's ledger view, inference) needs a Base.cls helper that takes both.
    location: >-
      src/OcuPilot/Kernel/State/Base.cls BoundedWhere
    severity: medium
  - summary: >-
      The dispatcher's write branch is only exercised with a forced restraint verdict; no test reads the real Kernel.Restraint.Verdict for a write call.
    evidence: |-
      ToolDispatchProbe.Restraint answers a forced verdict in every write leg, and no write tool ships in Release 1's registry, so an argument-order slip in Dispatch.Restraint stays green. Story 5.1's first write tool should pin the branch through the real verdict on the throwaway.
    location: >-
      src/OcuPilot/Kernel/Agent/Dispatch.cls Restraint
    severity: medium
  - summary: >-
      A tool fault's detail object reaches the model whole, so a validation envelope's violations[].reason would reach it too.
    evidence: |-
      Dispatch.AnswerOne renders tFault.detail unchanged. Today's read faults carry only detail.failedPair or detail.problem; AD-39 envelopes from Api handlers carry violations[]{field, code, reason}. Becomes real when Story 5.1's write tools answer one.
    location: >-
      src/OcuPilot/Kernel/Agent/Dispatch.cls AnswerOne
    severity: medium (unverified)
  - summary: >-
      AD-24's "recording the number actually sent so the read tool-call card can show it" is not recorded on a tool step.
    evidence: |-
      Loop.AnswerTools records a tool step's name, status and code only; neither the row count sent nor truncated is kept. The read tool-call card story (4.5, inference) consumes it.
    location: >-
      src/OcuPilot/Kernel/Agent/Loop.cls AnswerTools
    severity: medium
  - summary: >-
      CLAUDE.md still says check-objectscript.py has 18 rules; it has 21.
    evidence: |-
      `uv run scripts/check-objectscript.py` reports 21 rules after this story. Agent-context file; tracked as DW-446.
    location: >-
      CLAUDE.md
    severity: low
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

### 2026-09-16 — Review pass

- verdicts: 58 findings — high 0, medium 23, low 32, false 3, maybe-false 0 (rows marked "same as" share one root cause and its route)
- findings:
  - `[medium]` `[reject]` BH: `Read.View` filters and sorts at most 200 fetched rows where the screen uses 1,000 — by-design: the intent's Row cap row requires the port be asked for at most 201 rows; `truncated` reports the cut and server-side criteria still apply first (residual risk below).
  - `[low]` `[patch]` BH: `Read.View`'s context-cap cut is now unreachable and `ReadTool` texts still describe it — fixed the stale assertion message and replaced the stale mutation line on `TestTheToolViewIsTheRouteReadNarrowed` with an observed one.
  - `[medium]` `[patch]` BH: `BoundedWhere` binds a space-separated cutoff, while OcuPilot's time columns store `YYYY-MM-DDTHH:MM:SSZ`, so a string compare leaks up to a day — cutoff now ISO `T`/`Z`; `StateBound` asserts the form.
  - `[medium]` `[defer]` BH: `BoundedWhere` has no guarded helper that runs its fragment with a parameter array — recorded in `deferred`; Story 4.9 adds the helper in `Base.cls`.
  - `[medium]` `[patch]` BH: rule 21 checks only the first character, so a literal joined to a caller value passes — the SQL argument must now be one whole literal followed by `,` or `)`; harness case added.
  - `[low]` `[reject]` BH: rule 20 does not stop a shipped direct call to a tool's `View` — no shipped caller does; it becomes real only if shipped code calls `View` outside the registry.
  - `[medium]` `[reject]` BH: the shell privilege and namespace payloads use the job's frozen `$ROLES` while the dispatcher uses current grants — by-design: the intent requires each `Payload` unchanged (residual risk below).
  - `[low]` `[reject]` BH: `Capped` cuts only a top-level `rows` array — by-design: the Size cap row answers a rowless result over the cap `TOOL.RESULTTOOLARGE`; namespace and area lists are far below 65,536 characters.
  - `[medium]` `[defer]` BH: a fault's `detail` reaches the model whole, so a future validation envelope's `violations[].reason` would too — no read path carries one today; recorded in `deferred` for Story 5.1.
  - `[low]` `[reject]` BH: `HoldsPair` reads a `CheckUserPermission` error as not held — fail-closed, and the user asked about is `$USERNAME`, which exists.
  - `[low]` `[reject]` BH: resolve runs before identity, so an unknown name under a mismatched user answers `TOOL.UNKNOWN` — by-design: the intent's Approach orders resolve before identity, and a job cannot run as another user.
  - `[low]` `[reject]` BH: `ResolveWire` lists the registry on every call — measured at a few milliseconds per listing on live.
  - `[medium]` `[patch]` BH: dispatcher branches untested (gate error, gate code, internal fault) — `ToolDispatch` gained the gate-code, gate-error and internal-fault legs; a blocked verdict with no code is closed by the `TOOL.UNAVAILABLE` default.
  - `[medium]` `[patch]` BH: `ProviderTools` refusals untested beyond the listing failure — `ToolEmit.TestAToolTheProviderCannotTakeRefusesTheListing` over the new `Test/AdvertiseTool` fixture covers subset, description and result-schema refusals; the loop's log line and its audit row on live follow `TurnLoop`'s existing pattern.
  - `[medium]` `[patch]` BH: `ToolRoundTrip` passes with 8 of 11 tools and any code — every tool must now conform except those `REFUSEEMPTY` names with their code.
  - `[low]` `[patch]` BH: the restraint tail alternatives are hand-copied and the comment overclaims — harness ties them to the codes `Api/Error.cls` declares; comment narrowed to a split at the `AGENT.` prefix.
  - `[medium]` `[defer]` BH: AD-24's "number actually sent" is not on the tool step — recorded in `deferred` for the tool-call card story.
  - `[low]` `[patch]` BH: `Read.Description` ignores `DESCRIPTION` — it now substitutes the screen into `DESCRIPTION`.
  - `[low]` `[reject]` BH: `ValidateSchema` is public with a test as its only caller — harmless helper; `SchemaProblem` is private.
  - `[low]` `[reject]` BH: `TurnTools` asserts the literal "At most 50 characters." — fails loudly if the descriptor changes.
  - `[low]` `[reject]` BH: spec bookkeeping (stale Auto Run Result, duplicated mutation list, sweep not run) — the fix edits this build's spec; the sweep and smoke ran at verification.
  - `[low]` `[defer]` BH: `CLAUDE.md` says the checker has 18 rules — agent-context file; recorded in `deferred` (DW-446).
  - `[low]` `[patch]` BH: `lines` used as a mode flag — renamed `is_client`.
  - `[low]` `[patch]` BH: `ToolWire.Teardown` discards `RemovePrincipals`' answer — it now uses it.
  - `[low]` `[patch]` ECH: an `OR` inside a `BoundedWhere` predicate escapes the window — each predicate is parenthesized.
  - `[low]` `[reject]` ECH: rule 20 and a direct `View` call — same as the BH row above.
  - `[medium]` `[reject]` ECH: shell payloads and frozen roles — same as the BH row above.
  - `[medium]` `[patch]` ECH: an internal tool failure answers `INTERNAL` and logs nothing — a fault at 500 or above is logged with the view's status.
  - `[low]` `[reject]` ECH: `Base.PrivilegePairs` defaults to none, resolved — by-design: the spec's task sets that default; shell reads rely on it.
  - `[low]` `[reject]` ECH: a row deleted between `TOP ?` and open leaves `truncated` false — a concurrent-delete race; the row is gone either way.
  - `[false]` `[reject]` ECH: an absent or null `input` is refused `TOOL.ARGUMENTS` — the intent's Arguments row requires exactly that for a non-object input.
  - `[low]` `[reject]` ECH: `ValidateArguments`' catch text could reach the model — no input bounded by the turn's token limit makes it throw.
  - `[low]` `[reject]` ECH: an error result's `detail` is not size-capped — a problem string over 65,536 characters needs a key that long.
  - `[low]` `[reject]` ECH: a limits class answering 0 breaks every result — production `Limits` is fixed at 200 and 65,536.
  - `[low]` `[patch]` ECH: the restraint regex split claim — same as the BH row above.
  - `[low]` `[reject]` ECH: `ToolRoundTrip` has no arming guard — its effects are those of opening the audit, process, SSL and web-application screens plus probe definitions it removes.
  - `[medium]` `[reject]` ECH: filter and sort over at most 200 rows — same as the first BH row.
  - `[medium]` `[patch]` ECH: rule 21 first-character check — same as the BH row above.
  - `[medium]` `[patch]` VG: the gate's own refusal code is never tested — `ToolDispatch` gate-code leg added.
  - `[medium]` `[patch]` VG: `ErrorRead`'s pairs are never checked — `ToolEmit.TestEveryLiveToolRequiresItsScreensPairs` pins every live tool's pairs.
  - `[medium]` `[defer]` VG: the write branch only ever reads a forced verdict — no write tool ships; recorded in `deferred` for Story 5.1.
  - `[medium]` `[patch]` VG: `ToolRoundTrip` accepts `INTERNAL` — same as the BH row above.
  - `[medium]` `[patch]` VG: rule 21 lets caller values into SQL text — same as the BH row above.
  - `[low]` `[reject]` VG: the listing-failure test asserts `Run`'s initial outcome — `Calls` 0 is the discriminating leg, and skipping the refusal makes a provider call.
  - `[low]` `[reject]` VG: `ToolShell`'s refusal method passes empty with no shell tools — its sibling method asserts registration.
  - `[low]` `[reject]` VG: sub-legs with no `mutation:` line — Rule 19 asks one per AC and each AC has one; the legs added in this pass have theirs.
  - `[low]` `[patch]` VG: `Read.View` dead code and stale test message — same as the BH row above.
  - `[low]` `[reject]` IA: identity after resolve — same as the BH row above.
  - `[low]` `[reject]` IA: only top-level `rows` are cut — same as the BH row above.
  - `[medium]` `[defer]` IA: `BoundedWhere` has no consumer path — same as the BH row above.
  - `[medium]` `[patch]` IA: rule 21 admits a joined literal — same as the BH row above.
  - `[false]` `[reject]` IA: `Prompt.BUILTIN` rewritten outside the Code Map — no document pins the text, the old sentence told the model it had no tools while tools are advertised, and the prompt stays a build-time constant sent whole (AD-11).
  - `[medium]` `[defer]` IA: a fault's `detail` passes whole — same as the BH row above.
  - `[low]` `[reject]` IA: `Advertise` runs before the first boundary — by-design: the spec's task advertises once before the loop.
  - `[low]` `[patch]` IA: a schema breaking the subset is tested only at `EmitSchema` — same as the `ProviderTools` BH row above.
  - `[medium]` `[defer]` IA: the restraint verdict is always forced — same as the VG row above.
  - `[false]` `[reject]` IA: the shell reads are not tested through `Dispatch` — `ToolWire` answers `shell_instance_read` through the dispatcher in a real job.
  - `[low]` `[reject]` IA: SQL bound observed through counts rather than the `TOP ?` text — the two-id fetch for `maxRows` 1 over three definitions discriminates, with its mutation recorded.

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

Observed at implement, green: live runs 2309-2317 read back from `%UnitTest_Result` (`ToolDispatch` 11, `ToolEmit` 8, `ToolShell` 2, `TurnTools` 4, `StateBound` 3, `ReadTool` 23, `TurnLoop` 11, `TurnStore` 11, `ErrorLog` 15); `ToolWire` refused by name on live (run 2318); on the throwaway, `ToolWire`, `ToolRoundTrip`, `TurnWire`, `StateRead`, `SwitchState` and `TurnChain` one class each; the checker (21 rules, 0 problems), its harness (119 tests), `lint-docs.sh` and `npm test` (798 node tests, 382 component tests). Not run here: the full throwaway sweep, `TurnLong`, and `smoke.sh`.

Observed at implement. ObjectScript mutations were made only to the throwaway's copy under `/tmp/ocupilot-ci/src`, loaded with `ckb` so subclasses recompiled, run through `ci-runner.mjs` one class at a time (throwaway runs 7-32), then restored from the worktree, reloaded, and `cmp`-checked. Checker mutations were made to `scripts/check-objectscript.py` and restored from a saved copy.

- mutation: `Loop.Run` keeps `Kill tTools` before each call -> `TurnTools.TestEveryRequestAdvertisesEveryTool` red (neither call carries a tool array).
- mutation: `Registry.WireName` keeps the dots -> `ToolEmit.TestEveryLiveToolHasAReversibleWireName` red, and `TestEveryLiveToolIsAdvertisedInTheSubset` red (the listing refuses).
- mutation: `Registry.EmitProperty` leaves `maxLength` -> `ToolEmit.TestEveryLiveToolIsAdvertisedInTheSubset` red on `logs.audit.read`, and `TestTheEmissionCorpus` red.
- mutation: `Dispatch.Answer` renders `is_error` for every call -> `ToolWire.TestATurnAnswersTheShellAndUsersReads` red.
- mutation: `Dispatch.Answer` reverses its results -> `TurnTools.TestSeveralCallsAreAnsweredInOrderInOneMessage` red.
- mutation: `Registry.ResolveWire` falls back to the first tool -> `ToolDispatch.TestAnUnknownToolReachesNothing` red, and `TestARegisteredReadCallAnswersItsResult` red on the unknown call's name.
- mutation: the `$USERNAME` check removed -> `ToolDispatch.TestAnotherUsersCallIsRefusedAndLogged` red.
- mutation: `InvokeTool` called before `Decide` -> `ToolDispatch.TestAGateDenialReachesNothingAndTheToolStaysAdvertised` red, with five other methods whose counts the early call moved.
- mutation: `Gate.Decide` answers 0 -> `ToolDispatch.TestTheShippedGateAllowsEveryLiveTool` red, with seven methods whose probe delegates to the shipped gate.
- mutation: the write branch skipped -> `ToolDispatch.TestARestrainedWriteIsNotRun` red on its blocked leg. mutation: the branch trusts `blocked` and not the status -> the same method red, alone.
- mutation: `Dispatch.HoldsPair` uses `$System.Security.Check` -> `ToolWire.TestARoleRemovedMidTurnIsRefusedFromCurrentGrants` red on "the users read is refused naming the pair". mutation: the pair check removed -> `ToolDispatch.TestADeniedPairIsNamedAndNothingRuns` red.
- mutation: argument validation skipped -> `ToolDispatch.TestRefusedArgumentsReachNoTool` red.
- mutation: the fault rendered whole, `reason` included -> `ToolDispatch.TestAToolFaultAnswersItsCodeAndDetailOnly` red.
- mutation: `Read.View` passes the model's `maxRows` -> `ToolEmit.TestTheReadToolClampsMaxRowsToTheCap` red. mutation: `ErrorRead.View` likewise -> `ToolEmit.TestTheErrorToolClampsAndPassesItsPortsFault` red.
- mutation: the `Capped` check removed -> `ToolDispatch.TestTheSizeCapDropsTrailingRows` red, and `TestTheRowCapCutsAndMarks` red.
- mutation: `ShellNamespaces` drops `writable` -> `ToolShell.TestEachShellToolAnswersItsHandlersPayload` red.
- mutation: `Loop.Run` joins the last message's blocks to the system prompt -> `TurnTools.TestNoToolResultReachesTheSystemPrompt` red.
- mutation: `Agent.GuardedScreenRows` reads every id instead of `TOP ?` -> `ToolRoundTrip.TestAStateReadFetchesOneRowMoreThanItAnswers` red. mutation: `BoundedWhere` writes the cutoff into the text -> `StateBound.TestAWindowBindsItsCutoff` red. mutation: the 720 check removed -> `StateBound.TestAWindowOutsideTheBoundIsRefused` red.
- mutation: `AGENT_REACH_RE` bans every `OcuPilot.Screen.*` again -> harness `test_the_tool_registry_passes_and_every_other_screen_class_is_refused` and `test_the_shipped_tree_passes_every_rule_this_story_added` red.
- mutation: `check_tool_dispatch`'s `InvokeTool`, HTTP and capture branches each disabled -> harness `test_invoke_tool_outside_the_registry_and_the_dispatcher_is_refused`, `test_an_http_request_or_api_path_on_the_dispatch_path_is_refused` and `test_a_capture_outside_the_admin_port_is_refused` red, one each.
- mutation: `check_state_sql_literal` disabled -> harness `test_a_variable_sql_argument_is_refused` and `test_a_concatenated_sql_argument_is_refused` red.
- mutation: DW-393's regex reverted -> harness `test_a_code_assembled_across_a_concatenation_is_refused`, `test_a_parameter_named_without_its_hash_is_refused` and `test_a_client_naming_a_code_is_refused_and_a_spec_is_not` red. mutation: DW-394's client scan disabled -> `test_a_client_naming_a_code_is_refused_and_a_spec_is_not` red.
- mutation: `RemoveSecondRole` dropped from `DESTRUCTIVE_TEST_RE` -> harness `test_the_turn_principal_helpers_are_in_the_population` red.
- mutation (AC 4): `ToolWire.OnBeforeAllTests` without its `ARMINGVARIABLE` guard -> `check-objectscript.py` rule 17 red at `ToolWire.cls:52`.
- mutation (AC 5): `ToolWire.Teardown` skips `RemovePrincipals` -> `ToolWire` red in both methods on the teardown assertion; a clean re-run (throwaway run 33) removed what it left.

Observed at review, on the patched tree: live runs 2329-2332 (`ToolEmit` 10, `ToolDispatch` 11, `StateBound` 3, `ReadTool` 23), checker 0 problems, harness 121 tests. Mutations as above, on the throwaway copy (runs 101-109) or the checker, each restored and compared:

- mutation: the gate's own code replaced by `TOOL.DENIED` in `Dispatch.AnswerOne` -> `ToolDispatch.TestAGateDenialReachesNothingAndTheToolStaysAdvertised` red on "a denial carrying its own code answers that code".
- mutation: the 500-and-above `LogFault` removed from `Dispatch.AnswerOne` -> `ToolDispatch.TestAToolFaultAnswersItsCodeAndDetailOnly` red.
- mutation: `ErrorRead.PrivilegePairs` deleted -> `ToolEmit.TestEveryLiveToolRequiresItsScreensPairs` red on `logs.applicationerrors.read`.
- mutation: `Registry.ProviderTools` ignores `EmitSchema`'s status -> `ToolEmit.TestAToolTheProviderCannotTakeRefusesTheListing` red on its subset leg.
- mutation: `BoundedWhere` stops parenthesizing predicates -> `StateBound.TestAWindowBindsItsCutoff` and `TestAKeyedReadEmitsNoTimePredicate` red. mutation: the cutoff left space-separated -> `StateBound.TestAWindowBindsItsCutoff` red.
- mutation: `Read.View` answers every call as an internal failure -> `ToolRoundTrip.TestEveryToolConformsToItsResultSchemaOrAnswersACode` red.
- mutation: `Read.View` passes no filter to `ApplyView` -> `ReadTool.TestTheToolViewIsTheRouteReadNarrowed` red.
- mutation: rule 21 checks only the first character of the SQL argument -> harness `test_a_literal_joined_to_a_caller_value_is_refused` red. mutation: `USER` dropped from the restraint tail alternatives -> harness `test_every_declared_restraint_code_is_seen_by_its_tail` red.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** The turn job advertises every registered tool (wire names, emitted subset, `maxLength` in descriptions) and answers each `tool_use` through `Kernel/Agent/Dispatch.cls`: resolve, identity, `Kernel/Governance/Gate.cls`, restraint for writes, pairs from current grants, arguments, then `Registry.InvokeTool`, with both caps and `{code, detail?}` failures. Both tool sources share `Tool/Base.cls`'s contract; three shell reads wrap the handlers' payloads; state reads bind `SELECT TOP ?`; `BoundedWhere` ships tested and unconsumed; checker rules 20 and 21 are new and rules 18 and 19 widened.

**Files.**

- `Kernel/Agent/Dispatch.cls`, `Kernel/Governance/Gate.cls` (new) -- the dispatcher and the gate point.
- `Kernel/Agent/Loop.cls`, `Limits.cls`, `Prompt.cls` -- advertise once, delegate, caps; the built-in prompt no longer says there are no tools.
- `Screen/Tool/Base.cls`, `Read.cls`, `ErrorRead.cls`, `Registry.cls`; `Shell.cls`, `ShellInstance.cls`, `ShellNamespaces.cls`, `ShellPrivileges.cls` (new) -- one contract, clamps, wire names, emission, the shell reads.
- `Kernel/State/Base.cls`, `Agent.cls`, `Hold.cls`, `Screen/Read.cls` -- `BoundedWhere`, bounded state reads.
- `Api/Error.cls`, `Kernel/Restraint.cls` -- `TOOL.*` codes and sentences; doc corrections.
- `scripts/check-objectscript.py`, `scripts/test_check_objectscript.py` -- rules 18-21 and their harness.
- Tests: `ToolDispatch`, `ToolEmit`, `ToolShell`, `TurnTools`, `StateBound`, `ToolRoundTrip`, `ToolWire` (new); fixtures `DispatchTool/`, `AdvertiseTool/`, `ToolDispatchProbe`, `ErrorReadStub`, `StateReadProbe`, `StateReadToolProbe`; `ReadTool`, `TurnLoop`, `TurnLoopProbe`, `TurnProvider`, `TurnWireFixture` updated.

**Review.** 58 findings: 21 rows patched (distinct entries: medium 8, low 6), 8 rows deferred (5 items in `deferred`), 29 rejected with the reason in the triage log. Patches: ISO cutoff and grouped predicates in `BoundedWhere`; rule 21 requires a whole literal; internal tool faults logged; gate-code, gate-error, pairs, advertise-refusal and strict round-trip tests; restraint tails tied to the declared codes; stale test texts and `Read.Description` corrected. Follow-up review: `false` -- every patch was observed red under its mutation, and the full sweep and smoke passed on the patched tree, so no unverified risk can be named.

**Verification.** Live `ocupilot`: whole-tree compile clean; runs 2319-2332 green (`ToolDispatch`, `ToolEmit`, `ToolShell`, `TurnTools`, `StateBound`, `ReadTool`, `ErrorLog`, `TurnLoop`, `TurnStore`); `ToolWire` refused by name (run 2328). Checker 21 rules, 0 problems; harness 121 OK; `lint-docs.sh` clean; `npm test` 798 node and 382 component tests. Throwaway `ocupilot-ci`, fresh `up` from the final tree: full sweep 100 classes, 918 tests, 0 failed; `smoke.sh` executed 19, passed 19; torn down after.

**Residual risks.** The read tool filters and sorts at most 200 fetched rows where the screen uses 1,000 (intent Row cap; `truncated` signals it). The shell privilege and namespace reads evaluate the job's frozen `$ROLES` while the dispatcher checks current grants, so they can disagree after a mid-turn role change. Both are recorded as by-design in the triage log.

**For the lead (Rule 20 candidates, decided in planning and not written to the spine):**

- Conventions › Tool naming: the wire spelling replaces dots with underscores, because the provider's tool-name grammar refuses dots.
- The harvested bounded-where guard lives in `Kernel/State/Base.cls`, not `Screen/Tool/`, because `check_state_package_isolation` refuses a State class naming `Screen`.
- The emitted schema moves `maxLength` into the property's description, so the validator's subset and the harvested verbatim subset differ by that one keyword.
