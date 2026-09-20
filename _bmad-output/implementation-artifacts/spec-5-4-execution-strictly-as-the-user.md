---
title: 'Story 5.4: Execution strictly as the user'
type: 'feature'
created: '2026-09-19'
status: 'done'
baseline_revision: '138c4e732e5207d673f3debd511d3c60e4091df1'
baseline_commit: '138c4e7'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
deferred:
  - 'OcuPilotIdentity grants %Admin_Secure:USE because that is the narrowest resource Security.Users.Get answers to on 2026.2 (measured on a throwaway as a least-privileged principal); the containment is the application Routines allow-list plus the New $ROLES frame, not the resource. Revisit if a narrower read appears.'
  - 'ui/browser/suggested-view.browser-spec.mjs AC8 (Story 4.10, out of this story''s scope) is flaky at the 900px row: the panel measured 321 against a published 320 on two consecutive runs, then passed on the baseline bundle and on this story''s bundle alike, so it is a sub-pixel rounding in the browser measurement rather than a layout change. A geometry assertion that can read one pixel either way needs a tolerance or a settle the spec does not have.'
  - 'spec-4-9''s Verification table (lines 525 and 530) names `Ledger.TestARefusalBeforeDispatchRecordsARowWithNoPairs` and `Ledger.TestABoundaryStopBeforeDispatchRecordsARowWithNoPairs`, which DW-1120 renamed here because those rows now record the tool''s declared pairs. Epic 4''s spec is done and out of this story''s footprint, so the two names are left stale rather than edited.'
  - 'The matrix row "Provider port gate" expects a `PROVIDER.*` refusal, which contradicts the same intent-contract''s Always clause ("A privilege refusal carries `AUTH.NOPRIVILEGE`, `#REASONAUTHNOPRIVILEGE` and `detail.failedPair`, built once and rendered twice") and AD-39. `ProviderPort.Invoke` therefore refuses `AUTH.NOPRIVILEGE` through `Kernel.Denial`, which is what `PortGate.TestEveryPortEvaluatesItsDeclaredGate` asserts; the row''s behavioural claim -- refused before the outbound request leaves, no request issued -- is pinned. The cell is a drafting residue predating the AD-39 unification in this same spec and needs correcting at its origin; the intent-contract is read-only to this stage.'
  - summary: >-
      An identity read that fails for any reason is reported as AUTH.DISABLED, so a missing or broken OcuPilotIdentity locks every account out behind a message that names the wrong cause and offers no repair path.
    evidence: |-
      Identity.IsEnabled fails closed on pKnown 0 (spec-pinned, and Disabled.TestAnUnreadableEnabledFlagRefuses pins it), and Router.OnPreDispatch renders the single AUTH.DISABLED code. Install creates the application on every run, so the state needs a code deploy without install; an operator deleting the application by hand reaches it directly. Distinguishing needs a second code and branch, which the spec does not settle.
    location: >-
      src/OcuPilot/Kernel/Identity.cls:34
    severity: medium
  - summary: >-
      EnsureIdentityApplication's create and drift-repair path has no test, so a regression there is a silent total lockout that every other gate reports as green.
    evidence: |-
      Test/Installer.cls has TestSecondRunRepairsDriftedApplication for OcuPilotStateProbe and no sibling for the identity pair; TestUninstallLeavesNoResidue names neither identity object. A fresh install still produces a correct application, so the whole suite, the browser gate and smoke stay green.
    location: >-
      src/OcuPilot/Install/Installer.cls:2093
    severity: medium
  - summary: >-
      The install drift oracle does not fold the identity application or its role, so drift on the new escalation is invisible to it.
    evidence: |-
      Installer.cls:3383 reports tAppEnabled and tRoleResources for the state pair only.
    location: >-
      src/OcuPilot/Install/Installer.cls:3383
    severity: medium
  - summary: >-
      Api.Definitions.RenderForbidden is a third privilege-refusal sentence, across twelve Definitions and Switches routes, for the same OcuPilotAdmin:USE pair whose sibling sentence this story deleted.
    evidence: |-
      It renders 403 / FORBIDDEN / AUTH.NOPRIVILEGE / detail.failedPair with its own wording. The spec's Code Map names it as answering a different question and the intent scopes the divergence to tool-versus-screen, so it is out of this story rather than wrong in it. Tests assert the code and the pair, never the sentence.
    location: >-
      src/OcuPilot/Api/Definitions.cls:1212
    severity: medium
  - summary: >-
      A tool that legitimately declares no privilege pairs now has its ledger row withheld from every cross-user reader, an %All-holding administrator included.
    evidence: |-
      Navigate.PrivilegePairs returns empty with pResolved 1 and its argument pairs are the target screen's, empty for Home, so a navigate-to-Home row records nothing and EvaluateRequired withholds it forever. AC8 specifies exactly this withholding; the tension is with AD-46's gating on the resources recorded on the row. Resolving it is a product call between a sentinel and the current shape.
    location: >-
      src/OcuPilot/Kernel/Audit/Ledger.cls:465
    severity: medium
  - summary: >-
      AC1's tool-identity assertion has no shipped-code falsifier, and the identity role's absence is asserted on a path where that escalation never runs, with no positive control.
    evidence: |-
      AsTheUser compares $Username inside the tool body against $Username in the caller, which the in-process dispatcher makes the same variable read twice; the spec's own AC1 mutation line was rewritten to mutate the fixture. Separately, GuardedUserEnabled is entered only from OnPreDispatch, so no test establishes the identity role is ever present. The fix is to drive one call through the ToolSetProbe child-process pattern as a real least-privileged principal.
    location: >-
      src/OcuPilot/Test/AsTheUser.cls:80
    severity: medium
  - summary: >-
      EvaluateAnyOf's OR semantics are pinned by no test, and every new port-gate assertion runs with the gate class substituted.
    evidence: |-
      Test.ProviderGate answers all-or-nothing, so nothing drives a caller holding exactly one member of INVOKEPAIRS; swapping GateAnyOf for the AND evaluator in ProviderPort.Invoke would leave the suite green while refusing every real caller short of all thirteen resources. Test.ScreenGate already has Hold(resource, permission) and could express it.
    location: >-
      src/OcuPilot/Screen/Gate.cls:192
    severity: medium
  - summary: >-
      TurnSecretResidue sweeps no log line although its class header and AC5 both name one, and it drives the ledger writers directly rather than running a turn.
    evidence: |-
      The class reads ledger rows, transcript steps and the progress record; completed and failed are a stubbed HTTP status plus the status string passed to the writer. The log half is covered by the pre-existing Test/ProviderSecret, which is a different surface from the matrix row's log line for that turn.
    location: >-
      src/OcuPilot/Test/TurnSecretResidue.cls:1
    severity: medium
  - summary: >-
      The matrix's exactly one refused ledger row per refused call is asserted nowhere.
    evidence: |-
      DenialParity asserts result shape, sentence parity, repeat-identity and the pair-check count; it never counts the rows the refusals wrote.
    location: >-
      src/OcuPilot/Test/DenialParity.cls:231
    severity: medium
  - summary: >-
      The provider port's new gate evaluates the calling process where the matrix row describes the turn owner's live grants.
    evidence: |-
      ProviderPort.Invoke is reached only from Loop inside the turn job, and Screen.Gate.HoldsPrivilege is $System.Security.Check over a $ROLES frozen at the spawn, which the intent-contract's Never clause reserves for the foreground path. Loop.HoldsAnyResource already answers the owner question with CheckUserPermission over the same list, so the new gate is a second, weaker answer to a question already answered.
    location: >-
      src/OcuPilot/Port/ProviderPort.cls:89
    severity: medium
  - summary: >-
      The per-request identity read is unmeasured.
    evidence: |-
      OnPreDispatch now performs New $ROLES, AddRoles, a %SYS switch, Security.Users.Get and a restore on every dispatched route, including a running turn's roughly one-second progress polls. What would settle it: measure OnPreDispatch latency with and without the read at that poll cadence.
    location: >-
      src/OcuPilot/Api/Router.cls:571
    severity: low
  - summary: >-
      No operator documentation names OcuPilotIdentity.
    evidence: |-
      README warns by name that deleting OcuPilotState by hand strands the install; the identity application carries a sharper version of the same hazard and is named in neither README nor any install-object list.
    location: >-
      README.md:230
    severity: low
  - summary: >-
      Two retired refusal sentences survive in fixtures.
    evidence: |-
      Test/ErrorReadStub.cls:56 and ui/src/app/areas/web-applications/openapi-viewer.page.spec.ts:243 still carry sentences the instance can no longer produce. Both are stub inputs rather than assertions, so they are inert, but they are superseded claims left where a later reader will mine them.
    location: >-
      src/OcuPilot/Test/ErrorReadStub.cls:56
    severity: low
  - summary: >-
      refused-tool.browser-spec.mjs drives a turn without the turn-slot guard its siblings use.
    evidence: |-
      context-chip, navigate, proposal-card and proposal-confirm all call requireFreeSlot first.
    location: >-
      ui/browser/refused-tool.browser-spec.mjs:1
    severity: low
  - summary: >-
      The IsEnabled-before-HoldsAdminResource ordering in OnPreDispatch is unexercised.
    evidence: |-
      Test.Disabled's principal always holds %Admin_Operate, so nothing pins that a disabled account holding no administrative resource reads 401 AUTH.DISABLED rather than 403 AUTH.NOADMIN.
    location: >-
      src/OcuPilot/Api/Router.cls:571
    severity: low
  - summary: >-
      The doc claim that a second application gives the escalation to one method overstates the containment.
    evidence: |-
      The Routines allow-list is OcuPilot.Kernel.State.Base:<db>:1, the same whole-class granularity EnsureApplication uses, so any guarded method in that file could call AddRoles for it. The claim appears in both Installer.cls and Base.cls.
    location: >-
      src/OcuPilot/Kernel/State/Base.cls:55
    severity: low
  - summary: >-
      AC3 is measured at Dispatch.Advertise rather than at the provider request the matrix names.
    evidence: |-
      ToolSetFull logs in as a least-privileged principal in a child process and compares the roster; the roster equality and the no-%All control are real, but the request that carries the roster is not on the measured path.
    location: >-
      src/OcuPilot/Test/ToolSetFull.cls:166
    severity: low
---

<intent-contract>

## Intent

**Problem:** OcuPilot's claim is that adopting the agent widens nobody's access, including the
adopter's. Today that claim rests on architecture (AD-1's in-process execution) and on static token
bans, not on observables. Five gaps make it unprovable or false: a tool's privilege refusal and a
screen's are two independent implementations with five different `reason` sentences, so "the same
403 the screen would produce" is measurably untrue; `$ROLES` is asserted free of OcuPilot's database
role only at the provider boundary, never inside a tool or port body; `Screen.Gate.EvaluatePairs`
holds an empty pair set to be satisfied by everyone, and two ledger writers emit exactly that, so a
cross-user reader holding only `OcuPilotAdmin:USE` receives `llm` and pre-dispatch refusal rows
ungated (DW-1120); `ProviderPort.Invoke` is the one port whose primary entry evaluates no named gate
before its call; and a disabled IRIS account keeps full OcuPilot access until its token pair lapses
(DW-444).

**Approach:** Make the guarantee observable rather than architectural. One privilege-refusal
constructor feeds both renderings (AD-39), so screen and tool cannot drift. One `EvaluateRequired`
entry point, on which an empty requirement is never held, serves the ledger and every port, while
the screen gate keeps the declared-empty affordance `Home` relies on. Every port declares a named
gate and a test enumerates the package to prove it. A disabled account is refused at the front of
every dispatched route, from one deliberately-narrow escalated read. The rest is pinning: runtime
`$ROLES` and `$USERNAME` assertions inside a tool body and a port call, a full-tool-set assertion
for a least-privileged principal, and a residue sweep proving no provider key survives a turn.

## Boundaries & Constraints

**Always:**

- A tool body runs in the calling process, under the caller's own `$USERNAME` and `$ROLES`, with no
  service account, no `$System.Security.Login`, no second authenticated hop and no IRIS credential
  other than the caller's own (AD-1, AD-8).
- The tool set advertised to the model is the full registry roster, always. Privilege is checked at
  call time; nothing is ever hidden from the model to enforce it (AD-8).
- A privilege refusal carries `AUTH.NOPRIVILEGE`, `OcuPilot.Api.Error.#REASONAUTHNOPRIVILEGE` and
  `detail.failedPair`, built once and rendered twice — the screen renders the human half, the tool
  result the machine half (AD-39). OcuPilot never retries a refusal by another credential or another
  path.
- The one permitted escalation for OcuPilot's own protected storage (AD-9) is not in effect while
  any tool, port or provider code runs; no storage method calls a tool, a port, or code that could;
  nothing is spawned or re-entered from inside an escalated frame.
- Every class under `src/OcuPilot/Port/` declares a named pair set and evaluates it before its
  outbound call (AD-29). `AdminPort` keeps the vendor's `ResourcesOR()` as its declared gate, which
  AD-29 fixes as a lower bound with the remedy at the descriptor's pair set.
- A provider key exists only in `Kernel.Provider.Base.ApiKey` for the length of the call and is
  cleared on every exit. It never reaches a `%Status`, an exception, a log line, a ledger row, a
  transcript or a progress record (AD-35).
- The pair set of a log read is established two ways together: the backing class's own check, plus a
  run as a real least-privileged principal on the throwaway (AD-29). A denial test uses a
  purpose-built role, never `%Operator`, which carries `%DB_IRISSYS:RW`.

**Never:**

- Never build `MonitorPort` or a metrics surface: `src/OcuPilot/Port/MonitorPort.cls` is Epic 6's
  path and no OcuPilot code reaches `/api/monitor/metrics` today.
- Never fill `Write.ProhibitedClass()` or build AD-10's prohibited set — that is Story 5.5's, and
  DW-1207 stays as Story 5.3 shipped it. Never narrow `webapp.list.update`'s argument set here.
- Never change the privilege primitive each path uses: a foreground request evaluates the process
  (`$System.Security.Check`), a turn job evaluates the user's current grants
  (`$SYSTEM.Security.CheckUserPermission`) because its own `$ROLES` is a copy frozen at the spawn
  (AD-31). Unify the refusal, not the check.
- Never change `Gate.EvaluatePairs`'s declared-empty meaning: `Screen/Descriptor/Home.cls:37`
  declares `"privileges": []` deliberately, and refusing it would lock every user out of Home.
- Never edit `scripts/**`, `.github/workflows/**`, `ui/tools/ci*.mjs`, `module.xml`, `spec/**`
  (Epic 13), `ui/src/app/shell/{header,account-menu,side-bar,command-box}*` or `ui/src/styles/**`
  (Epic 15). Never modify a `src/OcuPilot/Test/**` or `ui/src/app/core/**` file another epic created
  — create a new file instead.
- Never run a destructive or privilege-mutating check anywhere but the throwaway `ocupilot-ci`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Tool runs as the caller | A turn owned by `P`, a read tool whose pairs `P` holds | The tool body observes `$Username = P`; `$ROLES` contains no `%DB_OCUPILOT`; the row the tool returns is the one `P`'s own screen read returns | No error expected |
| Tool refused for privilege | `P` lacks `%Admin_Secure:USE`; the model calls that tool | Tool result content `{code:"AUTH.NOPRIVILEGE", detail:{failedPair:"%Admin_Secure:USE"}}`, reason `REASONAUTHNOPRIVILEGE`; exactly one refused ledger row; no second call issued by OcuPilot | Refusal is an ordinary tool result (AD-39), never an exception |
| Screen refused for the same pair | `P` reads the same descriptor over `/screens/:screen/read` | HTTP 403 `{error:"FORBIDDEN", reason:<same sentence>, code:"AUTH.NOPRIVILEGE", detail:{failedPair:<same>}}` | One envelope only (AD-12) |
| Full tool set advertised | `P` holds one `%Admin_*` resource and nothing else; a turn starts | The provider request advertises every tool `Registry.ListTools` returns, count equal to a `%All` holder's | No error expected |
| Escalation absent under a tool | A tool body and an `AdminPort` call inside a turn | `$ROLES` read at both points excludes `%DB_OCUPILOT` | No error expected |
| Storage re-entry | Any `Kernel/State/**` guarded method | Reaches no `OcuPilot.Port.*`, `OcuPilot.Kernel.Agent.*`, `OcuPilot.Screen.Tool.*`, `OcuPilot.Kernel.Provider.*` | Static ban already enforced; runtime probe confirms |
| Key residue after a turn | A turn whose provider call used canary key `K`, run to completion and to failure | `K` absent from every ledger column, transcript step, progress record and log line for that turn | Soundness gate stores nothing if a declared secret survives |
| Empty requirement, ledger | A ledger row whose `RequiredPairs` is `""`, read cross-user by an `OcuPilotAdmin:USE` holder | `EvaluateRequired("")` is 0; the row is withheld | Owner's own rows stay ungated |
| Empty requirement, screen | `Home`, declaring `"privileges": []` | `Gate.Evaluate` is 1 — unchanged | No error expected |
| Port gate | `logs/messages` for `P` without `%Admin_Operate:USE` | 403 with `failedPair="%Admin_Operate:USE"`, raised before the file is opened | No file handle taken, no partial read |
| Provider port gate | A turn whose owner holds no resource in the closed admin list | `PROVIDER.*` refusal before the outbound request leaves | No request issued |
| Disabled account, any route | `P` disabled; a previously-issued or newly-refreshed access token | 401 `{error:"UNAUTHORIZED", code:"AUTH.DISABLED"}` on every `/api/ocupilot` route | No `WWW-Authenticate`, one envelope |
| Disabled account, `/refresh` | `P` disabled, valid refresh token | The vendor still mints a pair — not preventable from OcuPilot code; the minted pair is refused at its first use | Recorded as a named limitation, not worked around |
| Disabled account, running turn | `P` disabled while a turn runs | `P`'s progress polls are refused, the 120 s poll lease lapses, the job abandons at the next step boundary | Turn ends `TURN.*`, no half-applied work |

</intent-contract>

## Code Map

**Server — the refusal seam:**

- `src/OcuPilot/Screen/Gate.cls` — `IsAuthenticatedPrincipal` (`:44`), `Evaluate` (`:58`, area at
  `:64`, descriptor at `:72`, the `'tResolved` refusal at `:71`), `RequiredPairs` (`:89`),
  **`EvaluatePairs` (`:109`)** whose `Set tAllowed = 1` at `:112` is DW-1120's line and whose doc
  comment states the declared-empty affordance, `HoldsPrivilege` (`:143`, the only
  `$System.Security.Check`, an overridable seam every fixture uses), `ClassicResource` (`:155`).
- `src/OcuPilot/Screen/Descriptor/Home.cls:37` — `"privileges": []`, the one shipped descriptor that
  depends on an empty set evaluating true. The reason `EvaluatePairs` is not simply inverted.
- `src/OcuPilot/Kernel/Agent/Dispatch.cls` — the gate chain in `AnswerOne`: same-user `:222`,
  governance `:227`, restraint for `kind=write` `:241`, **declared pairs `:257-268`** (`MissingPair`
  `:262`), schema `:270`, argument-derived pairs `:279-290`, `Registry.InvokeTool` `:292`.
  `HoldsPair` (`:72`) is `$SYSTEM.Security.CheckUserPermission` at `:76`. `DeniedContent` (`:663`) →
  `ErrorContent` (`:678`) builds the refusal content. `ResolveClientCall` duplicates the whole chain
  (gate `:458`, pairs `:476-489`, argument pairs `:503-516`).
- `src/OcuPilot/Api/ScreenRead.cls:56-62` — the screen half: `Gate.Evaluate` then
  `Error.Render(403, #FORBIDDEN, "This account may not read that screen", #AUTHNOPRIVILEGE, tDetail)`
  with `detail.failedPair` at `:60`. The literal sentence is what diverges from the tool's.
- `src/OcuPilot/Api/Error.cls` — `AUTHNOPRIVILEGE` (`:111`), `REASONAUTHNOPRIVILEGE` (`:118`, the
  canonical sentence), `ReasonForToolCode` (`:988`), `FORBIDDEN`/`UNAUTHORIZED` slugs,
  `AUTHANONYMOUS` (`:123`), `AUTHNOADMIN` (`:96`). `IsValidCode` validates by shape, so a new code
  needs no edit here. **Contended with Epic 4** — read, do not edit.
- Other `AUTH.NOPRIVILEGE` renderings that are **not** this story's to collapse, because they answer
  a different question: `src/OcuPilot/Api/Definitions.cls:1216` (OcuPilot's own admin resource),
  `src/OcuPilot/Api/Ledger.cls:108`.

**Server — the ports:**

- `src/OcuPilot/Port/MgmntPort.cls` — `Parameter PAIRS` (`:33`), `Pairs()` (`:126`), gate as the
  first statement of `Invoke`'s `Try` (`:173`), refusal (`:176`).
- `src/OcuPilot/Port/LogSourcePort.cls` — `MESSAGESPAIRS` (`:68`), `ALERTSPAIRS` (`:85`),
  `ERRORSINSTANCEPAIRS` (`:108`), `ErrorPairSpec()` (`:274`, the per-namespace globals-database
  resolution), `Page()` gate (`:463-480`), `Errors()` (`:730-736`), `Gate()` (`:1181`).
- `src/OcuPilot/Port/ProviderPort.cls` — `Invoke` (`:81`) calls `Authenticated()` (`:437`) **only**;
  `InvokeDraft` (`:186`) additionally gates `DRAFTPAIRS` (`:57`, `OcuPilotAdmin:USE`); `Gate()`
  (`:448`). `Invoke` is the one port entry with no named pair gate.
- `src/OcuPilot/Port/AdminPort.cls` — `Sequence()` `:842-847` evaluates the vendor `ResourcesOR()`
  through `HoldsResource()` (`:527`); `HoldsPair()` (`:636`); `QUERYPAIRS` (`:164`) and
  `QueryPairRefused()` (`:409`) are a post-500 diagnostic, not a pre-call gate. `BARETYPES` (`:175`)
  is how monitoring data is reached today — there is no `MonitorPort`.
- `src/OcuPilot/Screen/Descriptor/{LogMessageViewer,LogAlertViewer,LogErrorList}.cls` — each records
  the classic page it replaces and states that `%Admin_Operate:USE` is what that page requires
  (`LogMessageViewer.cls:10,25,47`; `LogAlertViewer.cls:10,44`; `LogErrorList.cls:22`).
- `src/OcuPilot/Api/{LogPage,ErrorLog}.cls` — gateless passthroughs by design (`LogPage.cls:14,30`);
  the gate lives in the port.

**Server — identity and the ledger:**

- `src/OcuPilot/Api/Router.cls` — `ADMINRESOURCES` (`:53`, the closed 13-resource list),
  `HoldsAdminResource` (`:418`, `$System.Security.Check` at `:424`), `ResolvedUsername` (`:394`),
  **`OnPreDispatch` (`:520`)**: install gate `:527-548`, identity `:552`, admin gate `:557-559`,
  namespace `:564-587`. `:510-517` records that a future `%SYS` read here brackets with
  `Kernel.Utils`. `XData UrlMap` `:73-113` — **epic-wide shared-append, tail only**; no route exists
  for `/login`, `/refresh`, `/logout` or `/revoke` and none can.
- `src/OcuPilot/Kernel/Utils.cls` — `SwitchNamespace` (`:44`) / `RestoreNamespace` (`:59`), AD-16's
  harvested pair.
- `src/OcuPilot/Kernel/State/Base.cls` — `Parameter APPLICATION = "OcuPilotState"` (`:50`),
  `DBRESOURCE = "%DB_OCUPILOT"` (`:62`), 32 `New $ROLES` + `AddRoles` site pairs, the first at
  `:135/:137`; `GuardedRolesSnapshot` (`:478`) and `GuardedRolesSnapshotThenThrow` (`:1011`) are the
  existing test-only probes. Header `:8-27` states the frame rule; `:34` warns the frame does not
  reach a child.
- `src/OcuPilot/Kernel/Agent/Job.cls:47` — the tree's only `JOB`, with its "no escalation in any
  caller frame" contract at `:36`.
- `scripts/check-objectscript.py` (**read-only — Epic 13's**) — `ESCALATION_ALLOWED` (`:605`) is
  exactly `{Kernel/State/Base.cls, Test/State.cls}` and `ESCALATION_RE` (`:622`) matches every
  abbreviation of `New $ROLES` and `AddRoles`; `REENTRY_TOKENS` (`:639`) bans `OcuPilot.Api`,
  `.Port`, `.Screen`, `.Area`, `.Kernel.Agent` under `Kernel/State/`; `check_agent_job_reach`
  (`:866`) confines `JOB` to `Kernel/Agent/Job.cls`. These three decide where the DW-444 escalation
  can live and are the reason it lives in `Base.cls`.
- `src/OcuPilot/Kernel/Agent/Loop.cls` — `Boundary` (`:267`, checked at `:302`, called `:197`,
  `:425`, `:639`), `HoldsAnyResource` (`:330`, `CheckUserPermission` at `:339`),
  **`RecordRefusedRow` (`:779`)** whose `:788` passes `"", ""` — DW-1120's second writer.
- `src/OcuPilot/Kernel/Audit/Ledger.cls` — **`RecordProviderCall` (`:78`)** whose `:85` passes `""`
  for `pRequiredPairs` — DW-1120's first writer; `RecordToolCall` (`:114`, `PairsToString` at
  `:125`); `RedactArguments` (`:157`, declared-secret drop `:167-179`, cap `:180`, backstop `:181`,
  soundness gate `:192`); `ViewForUser` (`:346`): admin gate `:358`, own rows `:408-415`, truncated
  withheld `:416-422`, unparseable withheld `:425-428`, **per-row `EvaluatePairs` `:429`**;
  `PairsToString` (`:257`), `StringToPairs` (`:308`).
- `src/OcuPilot/Kernel/State/Ledger.cls` — `RequiredPairs As %String(MAXLEN=512)` (`:102`),
  `PAIRSMAXLENGTH` (`:115`), `RequiredPairsTruncated` (`:109`), persist `:173-174`.
- `src/OcuPilot/Kernel/Audit/Log.cls` — `CREDENTIALSUFFIXES` (`:53`), `CREDENTIALEXACTNAMES` (`:63`),
  `Redact` (`:117`), `IsCredentialName` (`:172`).
- `src/OcuPilot/Kernel/Secret/Ladder.cls` — `Resolve` (`:84`), `Credential` (`:241`), `Environment`
  (`:382`), `LogCodes`/`LogReason` (`:361`/`:372`, codes only, never vendor text).
- `src/OcuPilot/Kernel/Provider/Base.cls` — `Property ApiKey [ Internal ]` (`:74`), assigned `:160`
  and `:170`, cleared `:190`, `:199`, `:204`. The only holder.
- `src/OcuPilot/Kernel/State/Turn.cls` — `UserName` (`:41`), `JobId` (`:74`), `ContextRoute` (`:92`).
  No credential column exists; `Api/Turn.cls:396` records that the instance observes no token
  sign-out.
- `src/OcuPilot/Install/{Installer,Roster}.cls` — `Roster.cls:105-150` declares the three web
  applications; `Installer.cls:2995` is the existing `Security.Users.Get(pUsername,.tProps)` idiom,
  `:1423-1426` records that `Security.Users` is `%SYS`-mapped, `:2944` shows the explicit AD-16
  bracket, and the `OcuPilotState` privileged routine application is created here.
  **Contended with Epic 13's `Install/Uninstall*`**; `Installer.cls` and `Roster.cls` are not in
  Epic 13's declared hold. Touch the minimum and report the extension.
- `irissys/%CSP/REST.cls` — the interception: `TokenLoginEndpoint`/`TokenLogoutEndpoint`/
  `TokenRevokeEndpoint`/`TokenRefreshEndpoint` (`:56-65`) are read by the CSP server, not by
  ObjectScript; `HandleTokenResponse` (`:425`) is `[Final, Internal]` and reads an already-minted
  pair from `$System.Context.CSP().AuthTokenInfo` (`:433`); `OnPreDispatch` is called from `:359`
  inside `DispatchRequest` and `AccessCheck` from `:180` inside `Page()`, **neither of which is
  reached on the four token paths**. Read-only reference.

**Server — existing tests to extend around, never edit:**

- `src/OcuPilot/Test/ScreenGate.cls` (pre-epic fixture overriding `HoldsPrivilege`, used by 14
  classes), `Navigation.cls` and `ScreenRead.cls` (Epic 6), `ToolDispatchProbe.cls` and
  `LedgerGate{,Probe}.cls` and `ToolWire.cls` (Epic 4) — **shared-create, other epics' files**.
- Epic 5's own, safe to modify: `ToolDispatch.cls`, `Ledger.cls`, `LedgerPairs.cls`,
  `LedgerWire.cls`.
- Adjacent coverage to reuse patterns from, not to edit: `TurnTools.cls` (the advertisement
  contract), `TurnWire.cls:142` (the one existing `$ROLES`-absent assertion, at the **provider**
  boundary), `State.cls:629,:640` (frame present/absent), `ProviderSecret.cls` (canary key through
  forced failures), `LogSourceDenial.cls` / `ErrorLogDenial.cls` / `MgmntPortDenial.cls`
  (purpose-built principals over the wire), `Token.cls` (the token contract, gated by
  `OCUPILOT_ALLOW_PRINCIPALS=1` at `:20`/`:71`), `RouterFixture.cls:13` (overrides
  `ResolvedUsername`, the rig for a pre-dispatch denial with no real session), `Http.cls`
  (`MakeRequest`/`RawRequest`).

**Client:**

- `ui/src/app/shell/tool-call-card.ts` — `step = input.required<TurnStep>()` (`:71`), `failed`
  (`:86`), `statusText` (`:98-103`) whose `:101` is
  `STRINGS.toolCallStatusFailed.split('<reason>').join(step.reason)`, template `:48-50`. No
  `.spec.ts` sibling exists yet. Hosted at `ui/src/app/shell/panel.ts:331`.
- `ui/src/app/core/turn.ts` — `TurnStep` (`:113-127`) already carries `reason` (`:125`) and
  **`failedPair` (`:126`)**, parsed at `:311`; `settledSteps()` (`:452-456`) back-fills `reason`
  only. The pair is already on the wire — `Kernel/State/Step.cls:61` and its projection at `:196`,
  minted by `Dispatch.cls:262-266` and `:284-288`. **No server or `core/` change is needed to carry
  it.**
- `ui/src/app/core/strings.ts:182` — `toolCallStatusFailed: 'failed — <reason>',` (the em dash
  is authored as an escape, Rule 14); `:181`
  `toolCallStatusDone`; `:228` `privilegeRequiresResource: 'Requires <resource>',` already used by
  `panel.ts:1066-1069` for the navigation gate. **No new string.**
- `EXPERIENCE.md` — `:409` the Fixed-strings/component row that owns `"failed — <reason>"`; `:198`
  and `:757` resolve that slot with the resource; `:223`/`:225` the privilege-gating rows. No table
  addition needed, so the epic-wide shared-append path is not used.
- `ui/browser/panel-spec.mjs` — `saveAndSettle(page, config)` (`:91-101`), `signedInAt` (`:60`),
  `authHeader` (`:36`), `definitions` (`:46`).
- `ui/browser/turnprobe-spec.mjs` — `armProbeDefinition` (`:171`), `disarmProbeDefinition` (`:179`),
  `scriptReply` (`:151`), `runIris` (`:52`), `requireFreeSlot` (`:231`), `abandonTurns` (`:203`) —
  the module a scripted-turn spec needs.
- `ui/browser/panel-principal.browser-spec.mjs` — the existing least-privileged-principal panel
  spec; the pattern to copy into a new file.

## Tasks & Acceptance

**Execution:**

**1 — One privilege refusal, two renderings (AC2).**

- `src/OcuPilot/Screen/Denial.cls` (**new**) — the single constructor for a privilege refusal:
  `Detail(pFailedPair)` returning `{failedPair}`, plus the fixed triple (HTTP 403,
  `OcuPilot.Api.Error.#FORBIDDEN`, `#AUTHNOPRIVILEGE`) and the one reason sentence, read from
  `OcuPilot.Api.Error.#REASONAUTHNOPRIVILEGE` so no sentence is authored twice. One class method per
  rendering: `Envelope()` for a handler, `Content()` for a tool result. It calls nothing and holds no
  state.
- `src/OcuPilot/Api/ScreenRead.cls:56-62` — replace the literal `"This account may not read that
  screen"` with `Denial.Envelope(tFailedPair)`. The observable change is the `reason` sentence.
- `src/OcuPilot/Kernel/Agent/Dispatch.cls` — `DeniedContent`/`ErrorContent` at `:663`/`:678` build
  the pair refusal through `Denial.Content()`, for all four pair sites (`:263`, `:285`, `:481`,
  `:508`). The `$SYSTEM.Security.CheckUserPermission` primitive at `:76` is unchanged.
- `src/OcuPilot/Port/MgmntPort.cls:176` and `src/OcuPilot/Port/LogSourcePort.cls:471,736` — their
  pair refusals take the same `code`, `reason` and `detail` from `Denial`.

**2 — An empty requirement is never held where it is not declared (AC2, DW-1120).**

- `src/OcuPilot/Screen/Gate.cls` — add `EvaluateRequired(pPairs, Output pFailedPair)`: identical to
  `EvaluatePairs` except that an empty list returns 0 with `pFailedPair = ""`. Correct
  `EvaluatePairs`'s doc comment at `:107-108` to say which of the two questions it answers and name
  `Home` as the declared-empty case. `Evaluate` (`:58`) keeps calling `EvaluatePairs`.
- `src/OcuPilot/Kernel/Audit/Ledger.cls:429` — the per-row cross-user gate calls `EvaluateRequired`,
  so every row already stored with an empty set is withheld retroactively. Owner rows (`:408-415`)
  stay ungated.
- `src/OcuPilot/Port/{MgmntPort,LogSourcePort,ProviderPort}.cls` — every port gate calls
  `EvaluateRequired`, so a mis-edited empty `Parameter` fails closed instead of opening the port.
- `src/OcuPilot/Kernel/Audit/Ledger.cls:85` (`RecordProviderCall`) — record the pairs the turn
  actually carries rather than the literal `""`: the pair set of the screen route the turn holds
  (`Kernel/State/Turn.cls:92`) resolved through `Gate.RequiredPairs`, empty when the turn carried no
  screen context. Empty is now safe because the gate withholds it.
- `src/OcuPilot/Kernel/Agent/Loop.cls:788` (`RecordRefusedRow`) — record what the refusal knows: the
  failed pair for a pair denial, the tool's declared pairs from `Registry.RequiredPairs` where the
  tool resolved, empty where neither exists.

**3 — Every port declares and evaluates a named gate (AC6).**

- `src/OcuPilot/Screen/Gate.cls` — move the closed administrative-resource list to
  `Parameter ADMINRESOURCES` here, as its one home, and add an `EvaluateAnyOf` classmethod taking
  the same pair list and `Output pFailedPair`, for an OR-set.
  `src/OcuPilot/Api/Router.cls:53,418-424` reads the parameter from
  `Gate` instead of holding its own copy; its behavior is unchanged.
- `src/OcuPilot/Port/ProviderPort.cls` — declare `Parameter INVOKEPAIRS` as that list at `USE` and
  evaluate it with `EvaluateAnyOf` in `Invoke` (`:81`), before the outbound request, beside the
  existing `Authenticated()` check. A caller who could not reach any OcuPilot API route cannot make
  the instance call a provider on their behalf either. `InvokeDraft`'s `DRAFTPAIRS` is unchanged.
- `src/OcuPilot/Test/PortGate.cls` (**new**) — enumerate every class in package `OcuPilot.Port`
  through `%Dictionary.CompiledClass` and assert each declares a pair-bearing `Parameter` and that
  its outbound entry evaluates it. This is the executable form of AD-29's "a port without a named
  gate is a review failure", and it is what makes Epic 6's future `MonitorPort` fail closed.

**4 — Refuse a disabled account (AC1, DW-444).**

- `src/OcuPilot/Kernel/State/Base.cls` — add `GuardedUserEnabled(pUserName, Output pKnown)`, the one
  method that escalates for this read: `Parameter IDENTITYAPPLICATION = "OcuPilotIdentity"`, a
  **second** privileged routine application whose role grants exactly this read and nothing else,
  entered with `New $ROLES` in this method's own frame and unwound on return; brackets `%SYS` with
  `Kernel.Utils.SwitchNamespace`/`RestoreNamespace` (AD-16, restore first in the `Catch`); reads
  `Properties("Enabled")` from `##class(Security.Users).Get()`; answers a boolean plus `pKnown`, and
  calls no tool, no port, no provider and spawns nothing. **It lives here and not in a new class
  because `scripts/check-objectscript.py:605` confines `New $ROLES` and
  `$SYSTEM.Security.AddRoles` to this file and to `Test/State.cls`, and `scripts/` is Epic 13's** —
  so the containment rule is honoured rather than widened. `Security.Users` and `Kernel.Utils` are
  outside `REENTRY_TOKENS` (`:639`), so the package-isolation rule still passes.
- `src/OcuPilot/Kernel/Identity.cls` (**new**) — the non-escalating policy face:
  `IsEnabled(pUserName)` calls `Base.GuardedUserEnabled` and refuses when `pKnown` is 0, so an
  unreadable flag never reads as "enabled". Carries `Parameter AUTHDISABLED = "AUTH.DISABLED"`
  (`Api/Error.cls` validates a code by shape, so it needs no edit there).
- `src/OcuPilot/Install/{Roster,Installer}.cls` — declare and create that application and its role
  beside the existing `OcuPilotState` pair, idempotently (AD-17), and remove them on uninstall. Keep
  the edit to the minimum: Epic 13 holds `Install/Uninstall*`.
- `src/OcuPilot/Api/Router.cls:552-559` — between the identity check and the admin-resource gate,
  refuse a disabled caller with `Error.Render(401, #UNAUTHORIZED, <reason>, "AUTH.DISABLED")`. This
  runs on every dispatched OcuPilot route, which is every route a token can be used on.

**5 — Pin what is already true (AC1, AC3, AC4, AC5).**

- `src/OcuPilot/Test/AsTheUserProbe.cls` (**new**) — a fixture tool and a fixture port hook that
  record `$Username` and `$ROLES` at the moment the body runs.
- `src/OcuPilot/Test/AsTheUser.cls` (**new**) — AC1 and AC4 through the real dispatcher and a real
  `AdminPort` call: `$Username` equals the caller, `$ROLES` excludes
  `Kernel.State.Base.#DBRESOURCE`, and the tree contains no `$System.Security.Login` and no second
  authenticated hop on the tool path.
- `src/OcuPilot/Test/ToolSetFull.cls` (**new**) — AC3 over the wire: a purpose-built
  least-privileged principal's turn advertises exactly the roster `Registry.ListTools` returns, with
  the same count a `%All` holder sees.
- `src/OcuPilot/Test/TurnSecretResidue.cls` (**new**) — AC5: a canary key through a completed turn
  and a failed turn, then a sweep of every ledger column, transcript step, progress record and log
  line for that turn. Asserts the key is absent and that `Provider.Base.ApiKey` is empty after the
  call returns on both paths.
- `src/OcuPilot/Test/DenialParity.cls` (**new**) — AC2: the same missing pair through
  `/screens/:screen/read` and through `Dispatch` yields equal `code`, equal `reason` and equal
  `detail.failedPair`; exactly one refused ledger row per refused call and no second attempt.
- `src/OcuPilot/Test/LedgerEmptyPairs.cls` (**new**) — DW-1120: `EvaluateRequired("")` is 0,
  `Gate.Evaluate("OcuPilot.Screen.Descriptor.Home")` is still 1, a stored `llm` row and a
  pre-dispatch refusal row are withheld from a cross-user `OcuPilotAdmin:USE` holder and visible to
  their owner, and both writers now record what they know.
- `src/OcuPilot/Test/LogPairs.cls` (**new**) — AC6, AD-29's two ways together: for each of the three
  log sources, the pair set the descriptor declares equals the resource its classic page requires,
  **and** a purpose-built least-privileged principal (never `%Operator`) is refused at exactly that
  pair over the wire and admitted when granted it. Anything the instance still refuses is added to
  the port's declared set in task 3's file and re-run.
- `src/OcuPilot/Test/Disabled.cls` (**new**) — DW-444 over the wire, gated by
  `OCUPILOT_ALLOW_PRINCIPALS=1` as `Token.cls:20` is: create a principal, take a token pair, disable
  the account, then assert every OcuPilot route answers 401 `AUTH.DISABLED`; call `/refresh`, take
  the newly minted pair, and assert it is refused the same way. Removes what it created.

**6 — The card names the missing privilege (AC2).**

- `ui/src/app/shell/tool-call-card.ts:98-103` — when `step.failedPair` is non-empty, resolve
  `STRINGS.toolCallStatusFailed`'s `<reason>` slot with it instead of `step.reason`, so the card
  reads `failed — %Admin_Secure:USE`. No string is added; `core/turn.ts` already carries the field.
- `ui/src/app/shell/tool-call-card.spec.ts` (**new**) — the failed-with-pair, failed-without-pair
  and done cases.
- `ui/browser/refused-tool.browser-spec.mjs` (**new**) — a scripted turn (`turnprobe-spec.mjs`) as a
  least-privileged principal calls a tool it may not call; the card's status text carries the pair,
  and no second call is issued. Reuses `saveAndSettle()` if it saves a form (DW-1169).

**Acceptance Criteria:**

- **AC1.** Given a turn owned by `P`, when any tool body or port call executes, then `$Username` is
  `P`, `$ROLES` carries no OcuPilot state role, and no OcuPilot-held IRIS credential, service
  account or second authenticated hop exists on that path.
- **AC2.** Given a caller lacking a declared pair, when the same descriptor is reached once as a
  screen read and once as a tool call, then both refusals carry the same `AUTH.NOPRIVILEGE` code,
  the same reason sentence and the same `detail.failedPair`; the tool-call card renders the pair;
  OcuPilot issues no second call and no alternate credential.
- **AC3.** Given a principal holding one administrative resource and nothing else, when a turn
  assembles the advertised tool set, then it is the full registry roster — identical to what a
  `%All` holder is offered.
- **AC4.** Given any tool, port or provider code executing, when `$ROLES` is read at that point,
  then OcuPilot's protected-storage role is absent; and no `Kernel/State` method reaches a tool, a
  port or provider code, and nothing is spawned from inside an escalated frame.
- **AC5.** Given a turn that resolved a provider key, when the turn ends by success or by failure,
  then the key is absent from every ledger column, transcript step, progress record and log line,
  and the in-memory holder is empty.
- **AC6.** Given every class under `src/OcuPilot/Port/`, when it makes its outbound call, then it has
  already evaluated a named pair set of its own; and given a least-privileged principal, when a log
  read is attempted, then it is refused at exactly the pair its classic portal page requires and
  admitted once granted it.
- **AC7 (DW-444).** Given an account disabled after its token pair was issued, when any
  `/api/ocupilot` route is called with that pair or with one `/refresh` has since minted, then it is
  refused 401 `AUTH.DISABLED`, and a turn the account was running ends when its poll lease lapses.
- **AC8 (DW-1120).** Given a ledger row whose `RequiredPairs` is empty, when a cross-user reader
  holding only `OcuPilotAdmin:USE` reads it, then it is withheld; and given `Home`, whose descriptor
  declares an empty privilege set, when it is gated, then it is still admitted.

## Spec Change Log

## Review Triage Log

### 2026-09-19 — Review pass

- verdicts: 51 findings — high 0, medium 26, low 22, false 3, maybe-false 0
- findings:
  - `[medium]` `[defer]` blind-hunter: a new install step with no `SCHEMAVERSION` move can leave an already-installed instance without `OcuPilotIdentity` — evidence: `Install` runs every ensure step unconditionally (`Installer.cls:785-830`, no version short-circuit), and AD-38 has the start hook install before traffic, so the state needs a code deploy without install; grouped with the edge-case finding below, whose diagnosis half is the real residue.
  - `[medium]` `[patch]` blind-hunter: `OnPreDispatch`'s doc says "Four concerns" and "None of the four reaches `%SYS`" — evidence: verified false at `Router.cls:485,523`; rewritten to five concerns, naming the enabled read as the one that reaches `%SYS` and locating the switch in `GuardedUserEnabled`.
  - `[medium]` `[patch]` blind-hunter: the uninstall confirmation omits `identityApplication` and `identityRole`, which `Uninstall` now deletes — evidence: verified at `Installer.cls:3636`; both names added to the message.
  - `[low]` `[defer]` blind-hunter: "a second application gives it to one method" overstates the containment — evidence: `Routines = "OcuPilot.Kernel.State.Base:<db>:1"` is whole-class, so any guarded method in that file could call `AddRoles`.
  - `[low]` `[patch]` blind-hunter: `RecordRefusedRow`'s `pFailedPair` is dead — evidence: verified both call sites (`Loop.cls:442,467`) stop at `pTool`; parameter, branch and the doc sentence removed, the doc now saying where a pair denial is actually recorded.
  - `[medium]` `[patch]` blind-hunter: the `$System.Security.Login` sweep is case-sensitive and the tree writes `$SYSTEM.` — evidence: ObjectScript `[` is case-sensitive; scan now folds case, matches `.Security.Login`, and carries a positive control over the test package.
  - `[medium]` `[patch]` blind-hunter: the `%Net.HttpRequest` control passes on a doc comment — evidence: verified `ProviderPort.cls` names it only at line 22 while `Provider/Base.cls` has ten real uses; control repointed at the provider base.
  - `[medium]` `[defer]` blind-hunter: AC1's falsifier was weakened to a fixture mutation — evidence: `$Username` inside the body and in the caller are the same variable in one process, so no shipped mutation reddens it.
  - `[low]` `[patch]` blind-hunter: tautological assertion in `Disabled`'s refresh `Else` arm — evidence: the assertion restates the branch condition; replaced with a 4xx-not-5xx assertion that distinguishes a refusal from a fault.
  - `[low]` `[patch]` blind-hunter: `PostToken`'s doc names a `pBearer` parameter it does not have — evidence: verified against the signature; doc rewritten to the body-carried refresh token.
  - `[medium]` `[defer]` blind-hunter: `EvaluateAnyOf`'s OR semantics are pinned by no test — evidence: `Test.ProviderGate` is all-or-nothing, so swapping `GateAnyOf` for `Gate` would leave the suite green.
  - `[low]` `[reject]` blind-hunter: the turn job reaches `Screen.Registry` through `Ledger.RoutePairs`, outside `check_agent_job_reach`'s file scope — rejected: Kernel to Registry is the spine's legal dependency direction and the checker passes; no harm named.
  - `[low]` `[defer]` blind-hunter: the identity read runs on every dispatched request, unmeasured — evidence: real per-request cost including a running turn's polls; nothing measured it.
  - `[low]` `[patch]` blind-hunter: `GuardedUserEnabled` leaves the whole user record in the frame — evidence: `Security.Users.Get` fills the array with hash and salt fields; `Kill tProperties` added after the one field is read.
  - `[false]` `[reject]` blind-hunter: the identity role's two-resource drift comparison is unverified — refuted: read back from the instance as `%Admin_Secure:U,%DB_IRISSYS:R`, same order and abbreviations, so the comparison converges.
  - `[false]` `[reject]` blind-hunter: the card replaces the reason with the pair rather than adding it — refuted: spec task 6 specifies the pair "instead of `step.reason`"; by design.
  - `[false]` `[reject]` blind-hunter: `EvaluateAnyOf`'s first-member pair reaches the card — refuted: a provider fault updates a `model` step and `Step.GuardedUpdate` has no `failedPair` parameter, so no tool-call card renders it.
  - `[low]` `[defer]` blind-hunter: two retired refusal sentences survive in fixtures — evidence: `Test/ErrorReadStub.cls:56` and `openapi-viewer.page.spec.ts:243`; both are stub inputs, not assertions.
  - `[low]` `[defer]` blind-hunter: no operator documentation for `OcuPilotIdentity` — evidence: README names `OcuPilotState`'s hazard by name and not this one.
  - `[low]` `[reject]` blind-hunter: `Denial.Content` bypasses `Dispatch.ProjectedDetail` — rejected: `Detail()` emits only `failedPair` and `ProjectedDetail` narrows only `violations`, so no bad outcome today, and the method is `Private` on `Dispatch`, making the fix more than a direct correction.
  - `[low]` `[defer]` blind-hunter: `refused-tool.browser-spec.mjs` omits `requireFreeSlot` — evidence: four sibling specs call it before driving a turn.
  - `[low]` `[defer]` blind-hunter: the `IsEnabled`-before-`HoldsAdminResource` ordering is unexercised — evidence: the principal always holds `%Admin_Operate`, so a reshuffle would go unnoticed.
  - `[medium]` `[defer]` edge-case: a tool that legitimately declares no pairs has its row withheld from every cross-user reader, `%All` included — evidence: verified `Navigate.PrivilegePairs` returns empty with `pResolved` 1 and Home's argument pairs are empty; AC8 specifies exactly this withholding, so the residue is the AD-46 auditability tension, not the code.
  - `[medium]` `[patch]` edge-case: uninstall confirmation understates what it destroys — evidence: same defect as the blind-hunter row above; patched there.
  - `[medium]` `[defer]` edge-case: the install drift oracle does not fold the identity application or its role — evidence: `Installer.cls:3383` reports `tAppEnabled`/`tRoleResources` for the state pair only.
  - `[medium]` `[defer]` edge-case: an identity read that fails for any reason renders `AUTH.DISABLED` for every account — evidence: real and severe (total lockout behind a misleading message), but the spec pins the fail-closed refusal and a distinct code adds public surface the spec does not settle.
  - `[medium]` `[patch]` edge-case: the login scan is case-sensitive — evidence: same defect as the blind-hunter row; patched there.
  - `[medium]` `[patch]` edge-case: a raise between `SetEnabled` 0 and its re-enable leaves the account disabled for the next method — evidence: verified no teardown re-enabled it; `OnAfterOneTest` added.
  - `[low]` `[patch]` edge-case: `RecordRefusedRow`'s pair-denial branch is unreachable — evidence: same defect as the blind-hunter row; patched there.
  - `[medium]` `[defer]` edge-case: `TurnSecretResidue` sweeps no log line although its header and AC5 name one — evidence: verified the class reads rows, steps and the progress record only; the log half is covered by the pre-existing `Test/ProviderSecret`.
  - `[medium]` `[patch]` edge-case: `Base.cls`'s doc claims the uninstall confirmation lists the identity application — evidence: it did not; made true by the confirmation patch.
  - `[low]` `[reject]` edge-case: `Denial.cls` ships at `Kernel/` not the spec's `Screen/` — rejected: deliberate and recorded in the class header; the spec's path is refused by `check_agent_job_reach` for `Kernel/Agent/`.
  - `[medium]` `[patch]` verification-gap: AC1's login scan is case-blind to this tree's spelling — evidence: filed pre-verified; patched with case folding plus a positive control.
  - `[medium]` `[defer]` verification-gap: AC1's tool-identity assertion has no shipped-code falsifier — evidence: filed pre-verified; the fix is to drive the call through the `ToolSetProbe` child-process pattern, which is more than a direct correction.
  - `[medium]` `[defer]` verification-gap: `EnsureIdentityApplication`'s drift-repair path is untested — evidence: filed pre-verified; a regression there is a silent total lockout, and the fix is a new installer test.
  - `[medium]` `[defer]` verification-gap: `Api.Definitions.RenderForbidden` is a third privilege-refusal sentence across twelve routes — evidence: filed pre-verified; the spec's Code Map names it as answering a different question, and the intent scopes the divergence to tool-versus-screen.
  - `[low]` `[patch]` verification-gap: the tautological `Else` assertion — evidence: same defect as the blind-hunter row; patched there.
  - `[medium]` `[patch]` verification-gap: `LedgerEmptyPairs`'s second block is guarded by an `If` nothing asserts — evidence: verified; the guard assertion was added and immediately went red, exposing that `NewTurnKey` answered `emptypairs-0` every call because `$ZHex` reads its argument as a number. Both new classes now use the tree's hex-binary idiom.
  - `[low]` `[patch]` verification-gap: `pFailedPair` is dead — evidence: same defect as the blind-hunter row; patched there.
  - `[medium]` `[defer]` verification-gap: `ViewForUser` permanently withholds a shipped ungated tool's row — evidence: same root cause as the edge-case row above; deferred there.
  - `[low]` `[patch]` verification-gap: three mutation recipes name `EvaluatePairs`, which those call sites no longer use — evidence: verified at `Test/MgmntPort.cls:118`, `Test/MgmntPortDenial.cls:258`, `Test/LedgerWire.cls:295`; all three corrected, as was the stale contract line at `Ledger.cls:370`.
  - `[low]` `[reject]` verification-gap: the spec's Auto Run Result section still reads "Planning only" — rejected: it is written at this step's Finalize, and a finding whose fix is to edit this build's spec is rejected by rule.
  - `[medium]` `[defer]` intent-alignment: the provider gate evaluates the calling process where the matrix describes the turn owner's live grants, and answers `AUTH.NOPRIVILEGE` where the matrix says `PROVIDER.*` — evidence: `Loop.HoldsAnyResource` already answers the owner question with `CheckUserPermission`; the code-family half is the intent-contract contradiction already recorded in the deferred list.
  - `[medium]` `[defer]` intent-alignment: every new port-gate assertion runs with the gate class substituted — evidence: same root cause as the `EvaluateAnyOf` row; deferred there.
  - `[medium]` `[defer]` intent-alignment: the identity role's absence is asserted on a path where it never runs, with no positive control — evidence: same root cause as AC1's falsifier row; deferred there.
  - `[low]` `[patch]` intent-alignment: `RecordRefusedRow`'s pair-denial branch is unreachable — evidence: same defect as the blind-hunter row; patched there.
  - `[medium]` `[defer]` intent-alignment: the residue sweep drives the ledger writers rather than a turn — evidence: same root cause as the log-sweep row; deferred there.
  - `[medium]` `[defer]` intent-alignment: "exactly one refused ledger row" is asserted nowhere — evidence: verified `DenialParity` asserts result shape, sentence parity, repeat-identity and the pair-check count, but never counts rows.
  - `[low]` `[defer]` intent-alignment: AC3 is measured at `Dispatch.Advertise` rather than at the provider request — evidence: the roster equality and the no-`%All` control are real; the request itself is not on the path.
  - `[low]` `[patch]` intent-alignment: claims left standing at their origin — evidence: `Ledger.cls:370` corrected in this pass; the two fixture sentences are the deferred row above.
  - `[low]` `[reject]` intent-alignment: the shared-create clause is unmet for four test files — rejected as a defect and reported as a footprint extension instead: `Test/MgmntPort.cls` and `Test/MgmntPortDenial.cls` were created by Epic 6, which `dispatch.yaml` records as **merged** with its worktree removed and its branch deleted, and `Test/Ledger.cls`/`Test/LedgerWire.cls` are named in this spec as Epic 5's to modify. Verified the live branches (`OCU-1-epic13`, `OCU-1-epic15`) and `feature` all carry identical blobs for all four, so no contended epic owns them and no collision exists.

## Design Notes

**Governing ADs (Rule 6).** AD-8 (privilege is the process's, checked at call time, never cached;
`(resource, permission)` pairs; the full tool set always advertised), AD-1 (in-process, so "runs as
the user" is a property of the process), AD-9 (the one permitted escalation and its two ordering
rules), AD-29 (every port declares and evaluates its own gate; `ResourcesOR()` is a lower bound),
AD-31 (the turn job re-validates the identity it froze; the 120 s poll lease), AD-35 (no credential
in an exception, status, log line or trap). Also in force: AD-39 (one envelope, two renderings, and
the reason the screen and the tool are not given two shapes), AD-12, AD-16, AD-21 (`$ROLES` alone
never authorizes), AD-37, AD-41. AD-10 is named but **not** implemented here — Story 5.5 owns it.

**The AD-8 tension DW-444 creates, and exactly how narrow the escalation is.** AD-8's Rule says
"There is no service account and no elevation anywhere on the request path… The one permitted
elevation is AD-9's", and AD-9 scopes its privileged routine application to "the storage classes,
and only the storage classes". DW-444's decided fix puts an escalated `Enabled` read on the request
path, which neither clause admits. The decision is the owner's, taken at Epic 4's merge gate, and it
stands; the spine already records it in `## Deferred`. What this spec fixes is its shape, so it
cannot become a general elevation: one method (`Base.GuardedUserEnabled`), one argument, one boolean
answer, one field read; a **second** privileged routine application (`OcuPilotIdentity`) rather than
a role added to `OcuPilotState`, so no existing guarded storage call gains any reach; entered with
`New $ROLES` in the reading method's own frame and unwound on return; calling no tool, no port and
no provider, and spawning nothing, so AD-9's two ordering rules hold unchanged. It sits in
`Kernel/State/Base.cls` because that is where `check-objectscript.py:605` already confines every
escalation in the tree, and `Kernel/Identity.cls` holds the policy without escalating — so the
static containment rule that proves AD-9 keeps working unchanged, and `scripts/`, which Epic 13
holds, is not touched. **Both AD-8's "one permitted
elevation" clause and AD-9's "only the storage classes" clause need a one-line amendment naming this
second site.** `bmad-build-auto` cannot amend a planning artifact, so this is flagged for the
runner to apply under Rule 20 at the story's gate, in the same commit as the story.

**Why `/refresh` cannot be refused at the mint, and why the hole closes anyway.** The four token
paths are handled by the CSP server before `DispatchRequest` runs: the endpoint parameters at
`irissys/%CSP/REST.cls:56-65` are read by the server's own layer, `HandleTokenResponse` (`:425`) is
`[Final]` and reads a pair that has already been minted, and every overridable hook — `OnPreDispatch`
(`:359`), `AccessCheck` (`:180`), `Page`, `Login`, `GetAuthChallenge` — is called from code the token
paths never reach. `Token.cls:329` pins the observable that proves it: a failed `/login` carries no
`WWW-Authenticate`, which `%CSP.REST.Login()` always sets. The one method that does run,
`ProcessCorsRequest`, is post-mint and can only turn into a bare 500, so it would trade a security
answer for an unexplained failure; it is rejected. The refusal therefore lives at **use**, in
`OnPreDispatch`, which covers every route a pair can be presented to — so a pair `/refresh` mints
for a disabled account is inert. `Disabled.cls` pins exactly that sequence rather than asserting a
refusal that cannot exist.

**Why the running turn needs no `Enabled` check of its own.** AD-31's Rule states that a
least-privileged job cannot read its own enabled flag without a second elevation, and bounds a
disabled account's turn by the wall clock. It does not need amending: the poll lease is renewed only
by the turn owner's authenticated polls, those polls now answer 401, and the job abandons at the next
step boundary once the lease lapses. The bound improves from 600 s to 120 s with no escalation inside
the job and no change to AD-31. (inference — from AD-31's lease contract and the new gate's coverage
of the progress route; `Disabled.cls` measures it rather than assuming it.)

**Why `EvaluatePairs` is not simply inverted.** DW-1120's directive is that an empty `RequiredPairs`
must never evaluate true. Applied literally to `Gate.EvaluatePairs` it would lock every user out of
Home, whose descriptor declares `"privileges": []` deliberately and whose doc comment at
`Gate.cls:107-108` names that as the way "a screen that never gates is expressed". The two callers
are asking different questions — "is this screen's declared requirement met" versus "has this row
named a requirement at all" — so they get two named entry points. `Evaluate`'s existing `'tResolved`
guard at `:71` already proves the screen path never reaches `EvaluatePairs` with an *unread*
requirement, which is the case DW-1120 is really about. Every port is pointed at `EvaluateRequired`
as well, so a `Parameter` mis-edited to empty fails closed.

**Why the privilege primitive is not unified.** `Screen.Gate.HoldsPrivilege` is
`$System.Security.Check` (the calling process) and `Dispatch.HoldsPair` is
`$SYSTEM.Security.CheckUserPermission` (the user's current grants). Both are correct where they sit:
a foreground request's process *is* the user, while a turn job's `$ROLES` is a copy frozen at the
spawn, which is precisely what AD-31 exists to compensate for. They can disagree — a role revoked
mid-turn is caught by the job's check and not by a stale process — and that disagreement is AD-31
working. AC2's "the same 403" is about the refusal the caller observes, which AD-39 already splits
into two renderings of one envelope; that is what `Screen/Denial.cls` makes literal.

**Ports that are deliberately not changed.** `AdminPort` keeps the vendor `ResourcesOR()` gate:
AD-29 fixes it as a lower bound and puts the remedy at the screen descriptor's declared pair set,
not at the port, so widening it here would duplicate a gate the descriptor already owns.
`QueryPairRefused()` stays a post-500 diagnostic. `Api/LogPage.cls` and `Api/ErrorLog.cls` stay
gateless passthroughs, because the gate belongs to the port and two gates would be two places to be
wrong.

**What AC6's "anonymous metrics" clause means in this story.** `/api/monitor/metrics` answering
anonymously is AD-29's *reason*, not a surface OcuPilot has. No `MonitorPort` exists, nothing in the
tree names that path, and `src/OcuPilot/Port/MonitorPort.cls` is in Epic 6's footprint. This story
therefore does not build it and does not gate it; `Test/PortGate.cls` is what makes it impossible for
it to arrive gateless. Monitoring data reached today goes through `AdminPort`'s `BARETYPES`
(`AdminPort.cls:175`) and so inherits the vendor gate.

**Why the card renders the pair and not a new sentence.** `toolCallStatusFailed` already owns a
`<reason>` slot (`strings.ts:182`, EXPERIENCE.md:409) and `TurnStep.failedPair` is already on the
wire (`turn.ts:126`, `Step.cls:196`), so the change is one line in the card and no string,
EXPERIENCE.md row or server field is added. EXPERIENCE.md:198 resolves that slot as `<resource>` and
:757 illustrates it as "requires %Admin_Secure"; AD-8 requires the **pair** to be named, so the slot
is filled with `resource:permission` verbatim. (inference — the two illustrations resolve the same
slot differently and neither is the Fixed-strings row; if the owner wants the "Requires " prefix it
is one line using the existing `privilegeRequiresResource` string.) The pinning test asserts the
card's status text carries the failed pair rather than the generic reason, which both readings
satisfy.

**"Reported, never retried" is a claim about OcuPilot, not about the model.** OcuPilot cannot stop a
model from asking again; what it guarantees is that no second path exists — the refusal returns as an
ordinary tool result (AD-39), no fallback credential is attempted, the same call refused twice
refuses identically, and exactly one ledger row is written per refused call. That is what
`DenialParity.cls` asserts.

**Ledger inbox (Rule 17).** Both entries are addressed, neither re-opened. **DW-444** — tasks 4 and
the `Disabled.cls` item; the `/refresh` half is bounded by the evidence above rather than declined.
**DW-1120** — task 2 and `LedgerEmptyPairs.cls`; the entry's "fix `EvaluatePairs`" is honoured as
`EvaluateRequired` at the ledger's call site for the reason recorded above, and both writers are
fixed as directed.

**Consumes (Rule 2):** 5.3 (`Confirm`'s gate chain and its pair re-check), 4.2 (`Dispatch`'s gate
chain, the registry, `Restraint`), 4.9 (the ledger, `RequiredPairs`, redaction), 4.5 (the progress
record and `failedPair` on the step), 3.2/3.3 (`ProviderPort`, the credential ladder), 2.1
(`AdminPort`), 1.9 (the descriptor registry and `Screen.Gate`), 1.6/1.7 (the token contract), 1.13
(the error envelope). Every Integration AC runs against the throwaway, never a mock.

**Consumed-by (Rule 2):** 5.5 (fills `ProhibitedClass()` behind the same gate chain), 5.6 (the audit
marker on a write that has passed these gates), 5.8–5.13 (the six area writes), 6.x (every screen
read through `Screen/Denial.cls` and the port gates; `Test/PortGate.cls` gates the `MonitorPort` Epic
6 will add), 7.x and 14.5 (the per-user scoping over the same enforcement point).

**Footprint extensions to report.** `src/OcuPilot/Install/{Roster,Installer}.cls` are in Epic 5's
declared `paths_hint` and are not inside Epic 13's stated hold (`Install/Uninstall*`), but Epic 13 is
running; the edit is confined to declaring and creating one application and one role. `Api/Error.cls`
is **read** only — the new code lives on `Kernel/Identity.cls` because `IsValidCode` validates by
shape. `Api/Router.cls`'s `UrlMap` is not touched; no route is added.

**Not this story.** AD-10's prohibited set and `Write.ProhibitedClass()` (5.5, DW-1207 — leave the
seam exactly as 5.3 shipped it). Building `MonitorPort` or any metrics surface (Epic 6).
`DW-1208`'s `%All`-only `webapp.list.update`: it is a *capability* limitation, not a refusal shape —
the write needs `%Admin_Secure:WRITE`, a pair this resource model cannot grant, so a non-`%All`
caller's refusal is exactly AC2's refusal naming that pair, and no special case is added; the
user-facing statement of the limitation belongs to the story that ships the write (5.8).

## Verification

**Slot A. Every IRIS MCP call carries `server: "ocupilot-slot-a"`. Every privilege-mutating or
destructive check runs on the throwaway `ocupilot-ci` — never on `ocupilot`, never on any
`ocupilot-slot-*` container.**

**Commands:**

- `uv run scripts/check-objectscript.py <staged paths>` — expected: no findings. In particular
  `check_escalation_containment` still passes because the new escalation is inside
  `Kernel/State/Base.cls`, already on `ESCALATION_ALLOWED` (`:605`), and
  `check_state_package_isolation` still passes because `Security.Users` and `OcuPilot.Kernel.Utils`
  are outside `REENTRY_TOKENS` (`:639`). A finding here is a design error, not a license to edit
  `scripts/`, which Epic 13 holds.
- `bash scripts/lint-docs.sh` — expected: clean.
- `cd ui && npm run build` — expected: the six `prebuild` checkers pass; the bundle lands in
  `ui/dist/ocupilot-ui/`.
- `cd ui && npm test` — expected: `node --test tools/*.test.mjs` then the component runner, both
  green, including the new `tool-call-card.spec.ts`. `ui/tools/strings.test.mjs` is untouched and
  passes because no string is added.
- `bash scripts/ci-throwaway.sh --dir /tmp/ocupilot-ci --project ocupilot-ci --web 52776 --super 1975`
  — expected: container `ocupilot-ci` healthy. Tear down only this throwaway, and only because this
  transcript names its `up`.
- Load and compile into the throwaway with the IRIS MCP tools, **one file at a time to its exact
  relative path**, then `grep` the loaded source **inside the container** before believing a red or a
  green: `%SYSTEM.OBJ.LoadDir` with `cuk` skips a file it judges unchanged, and `cp -R src/ …` nests
  a stray copy.
- `iris_execute_tests` — **one test class per tool call**, each landed in `%UnitTest_Result` before
  the next is sent; these classes create and remove principals, roles and a privileged routine
  application. Order: `OcuPilot.Test.AsTheUser`, `…DenialParity`, `…LedgerEmptyPairs`, `…PortGate`,
  `…ToolSetFull`, `…LogPairs`, `…TurnSecretResidue`, `…Disabled`, then the shipped
  `…ToolDispatch`, `…Ledger`, `…LedgerPairs`, `…Navigation`, `…ScreenRead`, `…MgmntPort`,
  `…LogSource`, `…ErrorLog`, `…ProviderPort`, `…State`, `…Escalation`, `…Secret`,
  `…ProviderSecret`, `…TurnLoop`, `…TurnWire`, `…Token`, `…Wire`, `…Gate`. Confirm the totals with
  the `%UnitTest_Result` SQL probe (numeric run index, joined through `TestMethod`) before reporting
  any suite green; a client-side timeout is not a failed run and is never re-submitted.
- `OCUPILOT_ALLOW_PRINCIPALS=1` is required for `…Disabled`, `…ToolSetFull` and `…LogPairs`, as
  `Token.cls:20` already establishes.
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`
  then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci npm run test:browser`
  — expected: green. A browser spec reads the **deployed** bundle, so the rebuild and the copy are
  part of the check, not preparation for it.
- **The full-suite browser leg runs on a throwaway the `%UnitTest` class sweep has not touched**
  (DW-1204, open): bring up a second throwaway for the full leg, or run the browser leg first on a
  fresh container, and say which was done.
- `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` — expected: every
  assertion executed and passing; zero executed checks is a failure, never a pass.

**Privilege verification, per AD-29 (the part that is not a command).** For each of the three log
sources and for the tool-set assertion, the pair set is established **two ways together**: read the
backing class's own privilege check (the descriptors at `LogMessageViewer.cls:10,47`,
`LogAlertViewer.cls:10,44`, `LogErrorList.cls:22` already record it against the classic pages), then
run the read on `ocupilot-ci` as a **purpose-built least-privileged role** — never `%Operator`, which
carries `%DB_IRISSYS:RW` and is a self-escalation primitive — and add to the port's declared set
anything the instance still refuses. Reading `ResourcesOR()` alone settles nothing.

**Rule 19 mutations** — each applied alone, observed red on its named test, reverted byte-identically,
with `git status --short` and `git diff --stat` confirmed unchanged afterwards. Every server mutation
is copied into the throwaway, `grep`ed inside the container, and the **whole package** recompiled
before the run (a subclass keeps its own compiled copy of an inherited method). Every client mutation
that a browser spec reads is rebuilt and redeployed before the run.

- AC1 mutation: `AsTheUserProbe.Tool.View` records a fixed identity in place of `$Username` →
  `AsTheUser.TestAToolBodyRunsUnderTheCallersRoles`.
- AC2 mutation: `ScreenRead.Handle`'s gate branch restored to its own literal reason sentence in
  place of `Kernel.Denial.Envelope` → `DenialParity.TestTheScreenAndTheToolRefuseIdentically`.
- AC2 mutation, second: `Kernel.Denial.Detail` drops `failedPair`, which is the one object both
  renderings carry → `DenialParity.TestTheRefusalNamesTheFailedPair`.
- AC3 mutation: `Registry.ProviderTools` filters the roster by `Gate.HoldsPrivilege` →
  `ToolSetFull.TestEveryToolIsAdvertisedToALeastPrivilegedPrincipal`.
- AC4 mutation: `Kernel/State/Base.cls`'s `New $ROLES` removed from one guarded method the tool path
  calls → `AsTheUser.TestNoStateRoleIsPresentInsideAToolBody`.
- AC5 mutation: `Provider/Base.cls:199`'s always-runs clear deleted →
  `TurnSecretResidue.TestTheKeyIsDiscardedWhenTheTurnEnds`; and the declared-secret drop removed from
  `Ledger.RedactArguments:167-179` → `TurnSecretResidue.TestNoKeyReachesTheLedger`.
- AC6 mutation: the gate statement removed from `LogSourcePort.Page` (`:471`) →
  `LogPairs.TestTheConsoleLogRefusesWithoutAdminOperate`; and `ProviderPort.Invoke`'s new
  `EvaluateAnyOf` call removed → `PortGate.TestEveryPortEvaluatesItsDeclaredGate`.
- AC7 mutation: the disabled branch removed from `Router.OnPreDispatch` →
  `Disabled.TestADisabledAccountsTokenIsRefused` and
  `Disabled.TestADisabledAccountsProgressPollIsRefused` (the progress poll answers 404 again); and `Identity.IsEnabled` made to admit when
  `Base.GuardedUserEnabled` answers `pKnown` 0 → `Disabled.TestAnUnreadableEnabledFlagRefuses`.
- AC8 mutation: `EvaluateRequired`'s empty-list branch returns 1 →
  `LedgerEmptyPairs.TestAnEmptyRequirementIsNeverHeld`; and `Gate.Evaluate` pointed at
  `EvaluateRequired` → `LedgerEmptyPairs.TestHomeIsStillAdmitted` (the falsifier for the Home
  affordance this story deliberately preserves).
- Client mutation: `tool-call-card.ts:101` ignores `step.failedPair` again →
  `tool-call-card.spec.ts` "a privilege refusal names the pair" and
  `refused-tool.browser-spec.mjs` AC2.

**Manual checks:**

- `docker compose ps` on `ocupilot-ci` before and after the run — the live `ocupilot` and every
  `ocupilot-slot-*` container are untouched.
- The spine amendment AD-8 and AD-9 need (one clause each, naming the second privileged routine
  application) is reported to the runner for Rule 20, not applied here.

## Auto Run Result

**Change.** "Runs strictly as the user" becomes observable. One privilege refusal is built once and
rendered twice (`Kernel/Denial.cls`, new; `ScreenRead`, `Dispatch.DeniedContent`, `MgmntPort`,
`LogSourcePort` and `ProviderPort` all render through it, and four literal sentences are deleted).
`Screen/Gate.cls` gains `EvaluateRequired`, on which an empty requirement is never held, and
`EvaluateAnyOf`, `AdminPairSpec()` and `ParsePairSpec()`; it becomes the one home of
`ADMINRESOURCES`, which `Router` and `ProviderPort` derive at compile time. `EvaluatePairs` keeps
the declared-empty affordance `Home` relies on. The ledger withholds a row that recorded no
requirement, and both writers now record what they know. `ProviderPort.Invoke` declares and
evaluates `INVOKEPAIRS` before its outbound call. A disabled account is refused 401 `AUTH.DISABLED`
at the front of every dispatched route, from one deliberately narrow escalated read
(`Base.GuardedUserEnabled` behind the second privileged routine application `OcuPilotIdentity`,
with the non-escalating policy in `Kernel/Identity.cls`). The card names the failed pair.

**Files changed.** `Kernel/Denial.cls` (new, the one refusal constructor) and `Kernel/Identity.cls`
(new, the non-escalating enabled policy); `Screen/Gate.cls` (two new evaluators, the pair-spec
helpers, the administrative list's one home); `Api/Router.cls` (the disabled refusal, the derived
parameter, the corrected `OnPreDispatch` contract); `Api/ScreenRead.cls`, `Kernel/Agent/Dispatch.cls`,
`Port/{MgmntPort,LogSourcePort,ProviderPort}.cls` (render through `Denial`; the ports gate on
`EvaluateRequired`); `Kernel/Audit/Ledger.cls` (per-row `EvaluateRequired`, the provider writer's
route pairs); `Kernel/Agent/Loop.cls` (the refusal row's declared pairs); `Kernel/State/Base.cls`
(the identity escalation); `Install/Installer.cls` (creates, repairs, removes and now announces the
identity application and role); `ui/src/app/shell/tool-call-card.ts` (the pair in the status word).
Ten new test classes plus a four-class probe package, `tool-call-card.spec.ts` and
`refused-tool.browser-spec.mjs`; `Test/{Ledger,LedgerWire,MgmntPort,MgmntPortDenial}.cls` and
`panel.spec.ts` follow the unified sentence and the recorded pairs.

**Review findings.** 51 findings across four layers: 0 high, 26 medium, 22 low, 3 false. Twelve
entries patched in-pass (6 medium, 6 low): the `OnPreDispatch` contract, the uninstall
confirmation, the case-blind `$System.Security.Login` scan and its missing positive control, the
`%Net.HttpRequest` control that passed on a doc comment, a teardown that could leave the probe
account disabled, an `If` guard nothing asserted, the dead `pFailedPair` parameter, a tautological
assertion, a wrong doc parameter, the undropped user record, three stale mutation recipes and a
stale contract line. Seventeen items deferred (see frontmatter). Six rejected: the identity role's
drift comparison (**false** -- read back from the instance byte-identically), the card replacing
the reason with the pair (**false** -- spec task 6 says exactly that), `EvaluateAnyOf`'s first
member reaching the card (**false** -- a provider fault updates a `model` step and
`Step.GuardedUpdate` has no `failedPair`), the turn job reaching `Screen.Registry` through the
ledger (**low** -- Kernel to Registry is the legal direction and the checker passes),
`Denial.Content` bypassing `ProjectedDetail` (**low** -- no bad outcome today and the method is
`Private` on `Dispatch`), and the `## Auto Run Result` being stale (**low** -- written here, and a
finding whose fix is to edit this build's spec is rejected by rule).

**One defect the patches uncovered.** Adding the missing guard assertion turned
`LedgerEmptyPairs`'s second block red: `NewTurnKey()` answered `emptypairs-0` on every call,
because `$ZHex` reads its argument as a number and random bytes evaluate to 0. Both new classes now
use the tree's hex-binary idiom; no other `$ZHex` on binary remains in the tree.

**Verification.** `check-objectscript.py` 551 files / 21 rules / 0 problems; `lint-docs.sh` clean;
`npm run build` green through its six prebuild checkers; `npm test` 1087 `node --test` plus 687
component tests, 0 failed. Throwaway `ocupilot-ci` recreated from scratch, which installed this
story's source on a clean volume. Full browser suite **192/192** on that container **before** any
class sweep touched it (DW-1204); the one earlier red was `suggested-view` AC8's 900px row, shown to
be a flake by passing against both the baseline bundle and this story's. Full class sweep
`ci-runner.mjs --container ocupilot-ci`: **151 classes, 1387 tests, 0 failed, 0 probe leftovers, 0
overlaps, 0 foreign runs**, re-run to green after the patches. `smoke.sh --container ocupilot-ci`:
**executed=45 passed=45 failed=0 pending=2 PASSED**. Rule 19: the mutation for the test added at
this stage (`Disabled.TestADisabledAccountsProgressPollIsRefused`) was applied by deleting the
disabled branch from `OnPreDispatch`, synced into the container, the package recompiled, observed
red on exactly that assertion, then reverted byte-identically (`cmp` clean) and re-run green. The
live `ocupilot`, both `ocupilot-slot-*` containers and the other slots' throwaways were untouched.

**Footprint extensions.** `Install/{Installer}.cls` (declared in Epic 5's `paths_hint`, outside
Epic 13's `Install/Uninstall*` hold) and four shared-create test files:
`Test/{Ledger,LedgerWire}.cls`, which this spec names as Epic 5's to modify, and
`Test/{MgmntPort,MgmntPortDenial}.cls`, created by Epic 6 -- which `dispatch.yaml` records as
**merged**, worktree removed, branch deleted. `OCU-1-epic13`, `OCU-1-epic15` and `feature` were
verified to carry identical blobs for all four, so no contended epic owns them.

**Residual risks.** The follow-up flag is set because six medium entries were patched. The specific
unverified risk: the turn-key defect was latent in two new classes and surfaced only when a patched
assertion stopped being skipped, so `LedgerEmptyPairs` and `TurnSecretResidue` wrote rows under
genuinely distinct keys for the first time in this pass -- their per-method teardown assertions have
one full-sweep run of evidence at that key shape, not the several the rest of the suite has.
Beyond that: the identity escalation has no test for its install, drift-repair or removal path, and
a failure there reports as `AUTH.DISABLED` for every account; `EvaluateAnyOf`'s OR semantics are
pinned by no test; and the intent-contract's "Provider port gate" row expects `PROVIDER.*` where
its own Always clause and AD-39 require `AUTH.NOPRIVILEGE` -- a contradiction inside the frozen
block that needs correcting at its origin.

Status: done
Blocking condition: none
