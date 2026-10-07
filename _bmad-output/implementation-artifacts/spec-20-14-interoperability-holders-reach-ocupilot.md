---
title: 'Story 20.14: Interoperability holders reach OcuPilot'
type: 'feature'
created: '2026-10-07'
status: 'done'
baseline_revision: 'e7840fbd7bb141c1161792f84e27d4bcb8dd17c1'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-20-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Before any route runs, the API refuses every caller who holds no `%Admin_*` resource and no `%Development`. So `%EnsRole_Operator`, `_Administrator` and `_Monitor` accounts cannot open OcuPilot at all, although the classic Interoperability pages admit them (DW-2140).

**Approach:** Repeat Story 19.12's audit over every descriptor, tool and route for a caller whose only floor member is `%Ens_Portal:USE`, and pin the result as per-principal rosters. Then add `%Ens_Portal` to `Screen.Gate`'s floor; the router, `ProviderPort` and the turn's step check derive from it. The plan-time audit found no surface that needs a new pair.

## Boundaries & Constraints

**Always:**

- **One home.** `Screen.Gate` gains `INTEROPRESOURCE = "%Ens_Portal"`. `FloorResources()` answers `ADMINRESOURCES`, then `%Development`, then `%Ens_Portal`. `Router.FLOORRESOURCES`, `ProviderPort.INVOKEPAIRS` and the turn's `resources` (`Api/Turn.cls:150`) stay derived from it at compile time. `%Ens_Portal` never joins `ADMINRESOURCES`.
- **Every other gate is unchanged.** No screen, tool or route gains or loses a pair (Design Notes › Audit).
- **Real principals.** Test principals are purpose-built on a throwaway, armed by `OCUPILOT_ALLOW_PRINCIPALS`, and their grants are read back through `Kernel.Shell.Effective`. Each holds READ on the install namespace's code database, which every caller needs, and no `%Admin_*` or `%Development:USE`. They are removed afterwards.
- **Classic resources are read on the instance**, never recalled.
- **`AUTH.NOADMIN` keeps its code.** Its reason names all three floor kinds and still contains `%Admin_`.

**Never:**

- No new error code, route, descriptor, tool, governance key or Fixed string.
- No change to any existing descriptor's or tool's pairs.
- No line inserted into EXPERIENCE.md; edit in place only.
- Never use `%Operator` to prove a denial. Never configure the dev instance or another slot's throwaway.

## I/O & Edge-Case Matrix

Principals, each with READ on the install namespace's code database: **E** also holds `%Ens_Portal:U`; **Mon**, **Op** and **Adm** hold the stock `%EnsRole_Monitor`, `%EnsRole_Operator` and `%EnsRole_Administrator`; **Below** holds that READ alone.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Below the floor | `GET /instance` as Below | 403 `AUTH.NOADMIN`. The reason names `%Admin_`, `%Development` and `%Ens_Portal` | none |
| Sign-in (DW-2140) | `GET /instance` and `GET /navigation` as E, Mon, Op and Adm | 200. The allowed areas and screens equal Design Notes › Rosters. Every other area and screen reads `allowed:false`, naming its `failedPair` | none |
| Interoperability reads | `interop.productions` (`?ns=HSCUSTOM`) as E and Op; `interop.processes` (`?ns=HSCUSTOM`) as Op and Adm | E: 403, naming `%Ens_ProductionConfig:READ`. Op: 200 on productions, 403 on processes naming `%Ens_Code:READ`. Adm: 200 on processes, with rows | 403 `AUTH.NOPRIVILEGE` |
| Event log | `logs.eventlog` read as E and Op | E: 403, naming `%Ens_EventLog:USE`. Op: 200 | as above |
| Administrative screen | `webapp.list` read as E | 403, naming `%Admin_Secure:USE` | as above |
| Route sweep | Every `UrlMap` route as E and as Op, with `DeveloperFloorRoutes.ConcretePath`'s placeholders. Roster non-GET routes are not sent | The roster's GETs answer neither 403 nor 5xx. Every other route answers 403 `AUTH.NOPRIVILEGE` naming a pair | no 5xx |
| Tools | `Registry.ListTools`, keeping each tool whose `RequiredPairs` the principal holds through `Effective` | Exactly that principal's tool roster. No write tool for any principal | none |
| Turn (Integration, AD-31) | The principal holds `TurnWireFixture.Resources(0)` plus a second role with `%Ens_Portal:U,%Ens_ProductionConfig:R`. A turnprobe turn calls `interop.productions.read`, then `webapp.list.read` | The first step answers with no error. The second is refused `AUTH.NOPRIVILEGE`, naming `%Admin_Secure:USE`. The turn completes and is never `TURN.ABANDONED.PRIVILEGE` | none |
| Other namespace | `GET /navigation?ns=USER` as any of the four | 403 `NS.DENIED`, naming `%DB_USER:READ` (unchanged; the stock roles grant no `%DB_USER`) | none |

</intent-contract>

## Code Map

### The floor and its consumers

- `src/OcuPilot/Screen/Gate.cls`:
  - `ADMINRESOURCES` doc :31-44, value :45;
  - `DEVELOPMENTRESOURCE` doc :50-53, value :54 (the shape the new parameter copies);
  - `FloorResources` doc :298-304, body :305-308. `FloorPairSpec` :314 iterates it, so it needs no edit.
- `src/OcuPilot/Api/Router.cls`:
  - docs :38-39 and :46-53; `FLOORRESOURCES` :54, which is derived;
  - `HoldsAdminResource` :1240, needing no code change;
  - `OnPreDispatch` doc :1318-1321, and the refusal reason :1421.
- `src/OcuPilot/Port/ProviderPort.cls`: `INVOKEPAIRS` doc :60-66, value :68 (derived).
- `src/OcuPilot/Api/Turn.cls:150` (derived). `Kernel/Agent/Loop.cls`: `Boundary` :335 and `HoldsAnyResource` :401 read it at every step.
- Docs that state the floor:
  - `Api/Error.cls` :92-99 and `Api/Definitions.cls` :5-6;
  - `ui/src/app/core/navigation.ts` :19, :975, `ui/src/app/core/instance.ts` :17, `ui/src/app/shell/instance-notice.ts` :26;
  - `docs/DEVELOPMENT.md` :346;
  - EXPERIENCE.md :79, :224, :756, :829 ("no `%Admin_*` and no `%Development`").

### What the tests reuse (Story 19.12)

- `Test/DeveloperFloorFixture.cls`: `CodeResource` :62, `NewPassword` :55, `ResetRole` :117, `Composed` :167, `Holds` :197, `HoldsAdministrative` :206, `Call` :217.
- `Test/DeveloperFloor.cls`:
  - `Navigation` :151, `AllowedOf` :172, `Sorted` :185;
  - the parity leg :416, `Compiled` :491, `ClassicResource` :501;
  - the tools leg :461;
  - the below-floor test :347.
- `Test/DeveloperFloorRoutes.cls`: `Roster` :85, `ConcretePath` :97 (a class method), the sweep :126. `Test/ConfigGate.cls` `Routes` :219.
- `Test/DeveloperFloorTurn.cls`: the template. `Test/TurnWireFixture.cls`: `Resources` :55, `EnsurePrincipal` :77, `USERA` :16, `StartConversation` :374, `AwaitEnd` :384.
- `Kernel/Shell/Effective.cls`: `Read` :236, `Compose` :63, `Holds` :194. `Screen/Tool/Registry.cls`: `ListTools` :106, `RequiredPairs` :423.
- Floor pins:
  - `Test/PortGate.cls` :272-292 `TestTheAdministrativeFloorHasOneHome`;
  - `Test/Wire.cls` :861-873, which iterates `FLOORRESOURCES`; the prose ":864 other thirteen" becomes fourteen.
- `scripts/ci-throwaway.sh`: `# classes:` lines :312 (`OCUPILOT_ALLOW_PRINCIPALS`) and :502 (`OCUPILOT_ALLOW_TEST_PROVIDER`). `ui/tools/ci.test.mjs` derives its roster from them.
- `ui/browser/developer-floor.browser-spec.mjs` is the browser template.

### Contended with Epic 18 (Rule 11), checked 2026-10-07

- `Api/Router.cls`, `Api/Error.cls`, `Test/PortGate.cls`, `Test/Wire.cls`, `Test/WireSecurityRead.cls` and EXPERIENCE.md: every edit below is `CONTENDED non-add-only`. Epic 18's hunks are route lines, prefix lines and `ROSTER`, none in these regions.
- `scripts/ci-throwaway.sh`: add-only.
- Not contended: `Screen/Gate.cls`, `ProviderPort.cls` and every new file.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Screen/Gate.cls`: add `INTEROPRESOURCE` with a doc stating the classic Interoperability menu's check. `FloorResources()` appends it. Correct the three docs.
- `src/OcuPilot/Api/Router.cls` (`CONTENDED non-add-only`): the reason at :1421 becomes "This account holds no InterSystems IRIS administrative privilege, %Development or %Ens_Portal; OcuPilot requires USE on at least one %Admin_ resource, on %Development or on %Ens_Portal". Correct the docs at :38-53 and :1318-1321.
- Docs, corrected in place:
  - `ProviderPort.cls` :60-66 and `Definitions.cls` :5-6;
  - `Error.cls` :92-99 (`CONTENDED non-add-only`);
  - the four client doc comments;
  - `DEVELOPMENT.md` :346;
  - EXPERIENCE.md :79, :224, :756 and :829, which become "no `%Admin_*`, no `%Development` and no `%Ens_Portal`" (`CONTENDED non-add-only`);
  - test prose stating the old floor: `ConfigGate` :10 and :385, `ProhibitedRoute` :97, `LogSourceDenial` :247, and `WireSecurityRead` :19 (`CONTENDED non-add-only`).
- `src/OcuPilot/Test/PortGate.cls` (`CONTENDED non-add-only`): :284 asserts `ADMINRESOURCES _ ",%Development,%Ens_Portal"`. Correct the doc at :273-275. `Test/Wire.cls` :864: "thirteen" → "fourteen" (`CONTENDED non-add-only`).
- `src/OcuPilot/Test/DeveloperFloor.cls`: rename `TestBelowTheFloorIsRefusedNamingBothHalves` to `...NamingEachMember`, and make it also assert `%Ens_Portal` in the reason.
- `src/OcuPilot/Test/InteropFloorFixture.cls` (new, not a TestCase). It refuses unless armed.
  - `EnsurePrincipal(pPassword, pKind, .pUser)` makes one principal per kind: `portal` (E), `monitor`, `operator` or `administrator`. Each has a purpose-built code-READ role. E also gets a role granting `%Ens_Portal:U`; the other three get their stock `%EnsRole_*` role. A role name never equals a user name (#942).
  - `RemovePrincipals()` returns what survives.
  - Every other helper delegates to `DeveloperFloorFixture`.
- `src/OcuPilot/Test/InteropFloor.cls` (new, at most about 500 lines). `OnBeforeAllTests` reads back that each principal holds `%Ens_Portal:USE` and the code READ, and holds no `%Admin_*` and no `%Development:USE`.
  - **Sign-in:** each principal's areas and screens equal its roster, and each refused entry names its pair.
  - **Parity:** for each principal, every open screen with a `classicPage` declares a pair from that page's compiled `RESOURCE`, and the principal holds it.
  - **Tools:** each principal's tool roster, with no write.
  - The interoperability-read, event-log and administrative-screen rows.
- `src/OcuPilot/Test/InteropFloorRoutes.cls` (new): the route-sweep row, as E and as Op, against each principal's route roster. Note that `DeveloperFloorRoutes` never sends `explorer/sql` POSTs to a non-developer; here each of them must answer 403, naming `%Development:USE`.
- `src/OcuPilot/Test/InteropFloorTurn.cls` (new, from `DeveloperFloorTurn`): the Turn row, with tag `interopfloor-probe`.
- **The floor-only roster (orchestrator condition, 2026-10-07; AC6).** A test, in `InteropFloor` or its own class, enumerates every screen descriptor, read tool and write tool. Each must declare a pair outside the floor members (`Screen.Gate.FloorResources()`), or be listed in a closed `FLOORONLY` roster with its reason: `owner-scoped` or `no classic resource`.
  - An unlisted floor-only surface fails, naming it. So does a roster entry that no longer exists or now declares a pair.
  - Routes are pinned by the E sweep: a route E opens outside its roster fails.
  - The floor change does not ship without this test.
- `scripts/ci-throwaway.sh`, add-only:
  - `# classes: InteropFloor, InteropFloorFixture, InteropFloorRoutes, InteropFloorTurn` under `OCUPILOT_ALLOW_PRINCIPALS`, with its sentence;
  - `InteropFloorTurn` under `OCUPILOT_ALLOW_TEST_PROVIDER`.
- `ui/browser/interop-floor.browser-spec.mjs` (new): Adm signs in. It sees no no-privileges notice, `interoperability/processes?ns=HSCUSTOM` renders rows, and Permissions stays listed but unavailable, naming `%Admin_Secure:USE` (`privilegeRequiresResource`). It removes the principal in `after`.

**Acceptance Criteria:**

- **AC1 (first criterion).** Given every descriptor, tool and route, when they are evaluated as E, Mon, Op and Adm past the widened floor, then each principal opens exactly its roster. Every open screen that replaces a classic page declares a pair from that page's `RESOURCE` that the principal holds. So nothing opens that the classic portal would refuse.
- **AC2 (second criterion, DW-2140).** Given E, which holds `%Ens_Portal:USE` and no `%Admin_*` or `%Development:USE`, when it signs in and calls every route, then the API admits it. Every surface outside its roster is refused by its named pair.
- **AC3 (Integration).** Given a `%Ens_Portal` holder with no `%Admin_*` and no `%Development`, when its turn calls a tool it holds and then one it lacks, then the first answers and the second is refused by name. The turn neither abandons nor is refused at the provider port.
- **AC4.** Given the floor's one home, when the router, the provider port and the turn compile, then each carries `%Ens_Portal` from `Screen.Gate`, and Below's reason names all three kinds.
- **AC5 (browser).** Given Adm in a real browser, when it signs in, then it works in Interoperability without the no-privileges notice, and Permissions names its failed pair.
- **AC6 (orchestrator condition: every surface has its own permission check).** Given every screen, read tool, write tool and route, when the suite runs, then each either declares a pair outside the floor or is listed in the floor-only roster with its reason. A surface with neither reddens, naming it.

## Spec Change Log

- 2026-10-07, runner spec gate: the orchestrator cleared the six contended edits, on the condition that the audit's "no surface needs a new pair" becomes a pinned test (AC6, the floor-only roster task, and its mutation row). The AD-8 amendment and the PRD FR-3 and FR-65 lines are written.

## Review Triage Log

### 2026-10-07 -- Review pass

- verdicts: 4 findings -- high 0, medium 0, low 1, false 1, maybe-false 0 (plus 2 notes rejected)
- findings:
  - `[false]` `[reject]` Roster non-GET routes are never sent, so AC2 is unverified for them -- the I/O matrix says "Roster non-GET routes are not sent"; `POST /turn` and `POST /conversation` are sent by `InteropFloorTurn`.
  - `[low]` `[patch]` AC5 has no `mutation:` line of its own -- applied: `InteropProcessList` pairs to `%Admin_Secure:USE` alone, browser spec red on rows, reverted byte-identical (`diff -r` with the throwaway source), line written.
  - `[low]` `[reject]` the "holds no write tool" assertion has no mutation of its own -- no write tool exists in the roster's reach; the AC6 write-tool mutation pins the write half; a mutation would need a new write tool.
  - `[false]` `[reject]` `ci-timings.json` needs rows for the new classes -- `npm run test:tools` passed; new files are placed by the shard tool's default share, not by a required row.
  - Auditor note, not a finding: the AC6 reading counts any pair on a resource other than `%Ens_Portal` as "own"; recorded under "Reading of AC6" and passed to the orchestrator.

## Design Notes

**Governing ADs:**

- AD-8: the floor paragraph and its "own pair first" rule; this story amends it.
- AD-29; AD-31 (the step check derives the floor); AD-44 (classic pages); AD-62 (the interop screens' own pairs).
- AD-21 (code-database READ as every caller's prerequisite), AD-9, AD-16, AD-39.

**Audit.** Measured on `ocupilot-b-ci` on 2026-10-07. The floor was widened in a throwaway-only compile and then restored; the source trees were confirmed identical and the probe principals removed. It covered 150 descriptors, 295 tools and 172 routes.

- **Stock grants:**
  - `%Ens_Portal` is not public.
  - `%Ens_Portal:U` is granted directly by `%EnsRole_Operator`, `_Monitor`, `_AlertOperator`, `_PubSubDeveloper` and `_RulesDeveloper`. `_Administrator` and `_WebDeveloper` get it through `_Operator`.
  - No `%EnsRole_*` role grants an `%Admin_*` resource. `%Development` comes through `_InteropEditorsAPI` (directly) and `_Developer` (through `%Developer`).
  - Today all four principals are refused `AUTH.NOADMIN`.
- **No surface needs a new pair.** Every surface E opens on the floor alone is one of these:
  - owner-scoped: the Agent screens and routes;
  - an empty classic `RESOURCE` (Home);
  - the public `%DeepSee_Portal` (the analytics log), with parity held as Story 19.12 found;
  - an interoperability surface, which opens only through its own pair.
- Rosters (data):

| Principal | Areas | Screens | Tools | Open GET routes |
|---|---|---|---|---|
| E, Mon | agent, analytics, home, logs | AgentGuardrails, AgentLedger, AgentTranscript, AgentTranscripts, Home, LogAnalyticsViewer | agent.transcripts.read, logs.analytics.read, shell.instance.read, shell.namespaces.read, shell.privileges.read, shell.screen.open | R17 |
| Op | E's + interoperability | E's + InteropProductionList, LogEventViewer | E's + interop.productions.read, logs.eventlog.read | R17 + `/logs/eventlog` |
| Adm | Op's | Op's + InteropProcessList, InteropRuleList, InteropTransformList | Op's + interop.processes.read, interop.rules.read, interop.transforms.read | Op's |

- **R17** = `/agent/definitions`, `/agent/restraint`, `/agent/context`, `/agent/ledger`, `/turn/:id/progress`, `/conversation/:id`, `/transcripts/:id`, `/instance`, `/namespaces`, `/navigation`, `/account/preferences`, `/ui/about`, `/ui/help`, `/ui/system`, `/ui/findings`, `/ui/guardrails`, `/logs/analytics`.
- **The roster's non-GET routes**, which are not sent: `DeveloperFloorRoutes.Roster()`'s twelve that are not explorer routes.
- **Measured refusals:**
  - For E, the Interoperability area reads unavailable, naming `%Ens_ProductionConfig:READ` (AD-8's area rule).
  - E's 138 refusals each named a pair, and there was no 5xx.
  - E's `/ui/system` answered 200 and wrote no `uisystem` line.
- **Named limits:**
  - A holder of only `_RulesDeveloper` is refused Rules (AD-62 rule 7, `%Ens_Code:READ`).
  - Screens backed by `AtelierPort` keep `%Development:USE` (AD-61).
  - USER answers `NS.DENIED` to these roles, unchanged.

**Spine and planning amendments, for the runner (Rule 20 at the spec gate; Rule 5):**

- AD-8's floor paragraph:
  - Replace "`FloorResources()`: the `ADMINRESOURCES` list plus `%Development`, each at USE" with "…plus `%Development` and `%Ens_Portal`, each at USE".
  - Append: "**The floor also admits `%Ens_Portal:USE`** [AMENDED 2026-10-07, Story 20.14 spec gate, owner decision on DW-2140, Rule 20]. The classic Interoperability pages admit its holder (`EnsPortal.Application.CheckPrivileges`), and `%Ens_Portal` never joins `ADMINRESOURCES`. Story 20.14's audit (150 descriptors, 295 tools and 172 routes, measured on `ocupilot-b-ci`) found that no surface needs a new pair. An account holding only `%Ens_Portal:USE`, or `%EnsRole_Monitor`, opens Home, the four Agent screens, the analytics log, six tools and seventeen GET routes. `%EnsRole_Operator` adds Productions and the event log, and `_Administrator` also adds the three code lists, each through its own pair."
- At ship, the runner names `Test.InteropFloor`, `InteropFloorRoutes` and `InteropFloorTurn` there, and marks the Deferred row for DW-2140 as implemented.
- PRD FR-3 (:239, "holds neither an `%Admin_*` resource nor `%Development`") and FR-65 (:912, "holding neither…"): each becomes "no `%Admin_*` resource, no `%Development` and no `%Ens_Portal`".

**Integration ACs:**

- **Consumes:** `Screen.Gate`, `Kernel.Shell.Effective`, `Screen.Tool.Registry`, `DeveloperFloorFixture`, `TurnWireFixture` and `TurnProvider`.
- **Consumed-by:**
  - 20.15: the agent's check that the user holds a screen's pairs builds on these rosters.
  - 20.3 to 20.6, 20.9 and 20.11: each new screen or tool whose pairs a stock `%EnsRole_*` grants joins these rosters in its own story.

**Ledger.** DW-2140 is addressed by AC2 and the sign-in row.

## Verification

**Setup (slot B):**

- Before each load, sync: `rsync -a --delete <worktree>/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`.
- Load in `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM` with `$System.OBJ.LoadDir("/opt/ocupilot/src","ck",.tErrors,1)`, checking both the status and `tErrors`. Never load through the MCP tools.
- Run one test class or spec file per call, and never re-submit after a client-side timeout.
- Before a browser run: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci`.

**Commands:**

- `(loop)` `uv run scripts/check-objectscript.py <changed .cls>`: expected clean.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one class per call: `InteropFloor`, `InteropFloorRoutes`, `InteropFloorTurn`, `DeveloperFloor`, `DeveloperFloorRoutes`, `DeveloperFloorTurn`, `PortGate`, `Wire`, `ConfigGate`, `ProviderPortOwner` and `WireAreaAnyScreen`. Expected: 0 failed, read from `%UnitTest_Result`.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/interop-floor.browser-spec.mjs browser/developer-floor.browser-spec.mjs`: expected pass.
- `(loop)` `bash scripts/lint-docs.sh && cd ui && npm run test:tools`: expected clean.
- `(once, before dev_complete)` The full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci`, one class at a time. Then `cd ui && npm test && npm run build`, under 3165 kB, and `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`.
- `(CI)` The full browser suite runs in CI's shards only (Rule 29).

**Planned pinning mutations (Rule 19).** Apply each on the throwaway, observe red, then revert byte-identical. Record a `mutation:` line here for each.

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | Drop `%Ens_EventLog:USE` from `LogEventViewer`'s pairs | `InteropFloor` sign-in and parity (E opens it) |
| AC2 | `FloorResources()` without `%Ens_Portal` | `InteropFloor`, `InteropFloorRoutes`, `InteropFloorTurn` and the browser spec |
| AC2, routes | Delete `Gate()` from `Area/WebApp/FormRules.HandleForm` | `InteropFloorRoutes` on `GET /web-applications/form` |
| AC3 | `Turn.cls:150` back to `Router.#ADMINRESOURCES`, and separately `INVOKEPAIRS` back to the admin members alone | `InteropFloorTurn` |
| AC4 | `Router.FLOORRESOURCES` as a literal, and separately the former reason | `PortGate`; `DeveloperFloor`'s below-floor test |
| AC6 | Drop one surface's own pairs: a screen (`LogEventViewer`), a write tool (an `interop.productions.*` tool's `%Ens_ProductionRun:USE`) and a route (`Gate()` out of `FormRules.HandleForm`), each in turn | the floor-only roster test, naming the surface; the route through `InteropFloorRoutes` |

**Mutations run (Rule 19)**, each applied on `ocupilot-b-ci`, observed red, then reverted byte-identical (`diff -r` of the worktree and the throwaway source tree) and recompiled:

- mutation: AC1 -- `LogEventViewer`'s `privileges` and `ownPrivileges` without `%Ens_EventLog:USE` -> `InteropFloor` sign-in, parity and tools red; `InteropFloorOwnPairs` red naming `screen:LogEventViewer` and `tool:logs.eventlog.read`. The event-log read also meets `LogSourcePort.EVENTLOGPAIRS`, so `TestTheEventLogOpensForTheOperatorAlone` reddens only with both dropped (observed: red).
- mutation: AC2 -- `FloorResources()` without `%Ens_Portal`, `Router`, `ProviderPort` and `Turn` recompiled -> `InteropFloor` (6 of 7), `InteropFloorRoutes`, `InteropFloorTurn` and `interop-floor.browser-spec.mjs` ("the frame, not the no-privileges notice") red.
- mutation: AC2 routes -- `Gate()` out of `FormRules.HandleForm` (line 108) -> `InteropFloorRoutes` red on `GET /web-applications/form` for both principals (answers 500 `INTERNAL`, not a named pair).
- mutation: AC3 -- `Turn.cls:150` back to `Router.#ADMINRESOURCES` -> `InteropFloorTurn` red; separately `INVOKEPAIRS` as the `ADMINRESOURCES` members at `USE` alone -> `InteropFloorTurn` red.
- mutation: AC4 -- `Router.FLOORRESOURCES` as a literal -> `PortGate.TestTheAdministrativeFloorHasOneHome` red; the former reason text in `OnPreDispatch` -> `DeveloperFloor.TestBelowTheFloorIsRefusedNamingEachMember` red.
- mutation: AC6 screen -- `LogEventViewer` as in AC1 -> `InteropFloorOwnPairs` red naming it. Write tool -- `InteropProductionAction.PrivilegePairs` answering `%Ens_Portal:USE` alone (dropping `%Ens_ProductionRun:USE` alone leaves the screen's `%Ens_ProductionConfig:READ`, so it does not redden) -> red naming `interop.productions.start`, `.stop`, `.restart`, `.update` and `.recover`. Route -- `Gate()` out of `FormRules.HandleForm` -> `InteropFloorRoutes`. A stale entry -- `Home` given `%Admin_Operate:USE` -> red, "declares its own pair, so FLOORONLY must not list it".
- mutation: reads -- `InteropProductionList` and `InteropPort.PRODUCTIONPAIRS` both reduced to `%Ens_Portal:USE` -> `TestTheInteroperabilityReadsFollowTheirOwnPairs` red (the descriptor alone reddens sign-in, parity and tools).
- mutation: administrative screen -- `WebAppList` with no `privileges` -> `TestAnAdministrativeScreenIsRefusedNamingItsPair`, sign-in, parity and tools red.
- mutation: other namespace -- `%DB_USER:R` added to the fixture's code role -> `TestAnotherNamespaceIsDeniedUnchanged` red.

- mutation: AC5 -- `InteropProcessList`'s `privileges` and `ownPrivileges` as `%Admin_Secure:USE` alone (the Administrator lacks it) -> `interop-floor.browser-spec.mjs` red on the Business processes rows (`waitForRows` timeout); reverted, spec green.

**Reading of AC6.** "A pair outside the floor members" is implemented as a pair on any resource other than `%Ens_Portal`: the `%Development` and `%Admin_Operate` pairs of the Explorer and Logs surfaces refuse the `%Ens_Portal` holder by name, so the System Explorer and Logs surfaces that declare `%Development` or `%Admin_Operate` alone would all be listed under the literal reading. `FLOORONLY` holds the ten that declare nothing else: five screens and five tools.

## Auto Run Result

Status: done
Blocking condition: none

- Change: `Screen.Gate` gains `INTEROPRESOURCE = "%Ens_Portal"` and `FloorResources()` ends with it; the router, `ProviderPort` and the turn derive it. `AUTH.NOADMIN`'s reason names all three kinds. Docs and test prose corrected in place, inside the cleared contended regions only.
- Tests added: `InteropFloor`, `InteropFloorFixture`, `InteropFloorRoutes`, `InteropFloorTurn`, `InteropFloorOwnPairs` (the AC6 floor-only roster, ten entries) and `ui/browser/interop-floor.browser-spec.mjs`; `scripts/ci-throwaway.sh` arming lines (add-only).
- Review: 1 patch (AC5 mutation line), 3 rejected, 0 deferred. Follow-up review recommended: false.
- Verified: full ObjectScript sweep 507 classes, 4051 tests, 0 failed; smoke 50/50; `npm test` 2611 and `test:tools` 1883 passed; bundle 3.09 MB; both interop and developer-floor browser specs pass; every AC has a `mutation:` line.
- Residual: AC6 is read as "a pair on a resource other than `%Ens_Portal`" (ten surfaces listed); the literal reading would also list Explorer and Logs surfaces that declare only `%Development` or `%Admin_Operate`. The orchestrator should confirm. The spine, PRD and epics.md ship-time lines are the runner's.
