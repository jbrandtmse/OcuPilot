---
title: "Story 20.34: The cube manager's build and synchronize"
type: 'feature'
created: '2026-10-15'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** To rebuild or update a cube, an analytics developer still opens the classic Cube Manager or Architect. OcuPilot reads cubes (Story 20.11) but cannot change one. The vendor's build and synchronize check no `%DeepSee_*` resource and write no audit event (measured), and a build deletes every fact first: the cube and every cube that depends on it read empty until the build ends.

**Approach:**

- A listed Analytics screen, **Cube manager**, with its own pair `%DeepSee_Admin:USE` (the classic `%DeepSee.UI.CubeRegistry`'s `RESOURCE`). Its rows show each cube's facts, last build, last update, whether it can be synchronized, whether an update is running, and the cubes that depend on it.
- Two row actions, **Build** and **Synchronize**, and the agent's two write tools for them. Each is an action-style write through `AnalyticsPort` (AD-51, AD-52, AD-53) over a port-composed `STATE` read.
- **Build** is destructive, so its governance key ships `false`. **Synchronize** is not, so its key ships `true`. The vendor's **Repair** is the same `%BuildCube` call, so it is offered as Build (Rule 5 apply-and-report, already in `epics.md`).
- Each write runs inside its own request (AD-7), a build on the vendor's own build agents, and records OcuPilot's own `ConfigChange` from either caller, because the vendor audits neither.

## Boundaries & Constraints

**Always:**

- **Gate first (AD-29, AD-65).** Before any vendor call, `AnalyticsPort` checks, in order:
  1. the endpoint's pairs, `MANAGERPAIRS` (`%DeepSee_Portal:USE`, `%DeepSee_Admin:USE`);
  2. the namespace's shape, and that it reports analytics (else 409 `ANALYTICS.NAMESPACE`);
  3. READ on the namespace's globals and routines databases;
  4. for `BUILD` and `SYNCHRONIZE` only: WRITE on the database `^DeepSee.Fact` maps to in that namespace, and that database mounted read-write (else 409 `ANALYTICS.CUBE.READONLY`).

  A refusal names the failed pair.
- **Preconditions are refused by name before any vendor call,** from the `STATE` read, over the target and every cube `%DeepSee.CubeUtils.%GetDependentCubes` names for it (the vendor updates them in the same call):
  - **Build:** any of them updating → 409 `ANALYTICS.CUBE.BUSY`.
  - **Synchronize:** any of them updating → `ANALYTICS.CUBE.BUSY`; any whose source records no changes (no `DSTIME`) → `ANALYTICS.CUBE.NODSTIME`; any never built (`%GetCubeDSTime` 0) → `ANALYTICS.CUBE.NOTBUILT`. The last one stops the vendor's silent full build of a never-built cube under the synchronize key.
  - "Updating" is the vendor's own `%IsCubeAvailable` answering reason code `build`, or a zero-timeout incremental probe of `^DeepSee.Build(<index>,"SYNC")` failing (taken and released at once, as the vendor's own query probe does).
- **The vendor calls, exactly:** `%DeepSee.Utils.%BuildCube(<cube>, 1, 0, 0, 0, 0, .stats)` (async on the vendor's agents, no console output, no tracking) and `%DeepSee.Utils.%SynchronizeCube(<cube>, 0, .facts)`. Each runs switched to the namespace (AD-16) inside `%SYS.Capture`, so nothing the vendor writes reaches the response.
- **Vendor answers are mapped:** OK → done; `#20006` (build errors) → done, with the error count; `#20005` (lock) → 409 `ANALYTICS.CUBE.BUSY`; `#20013` (no such cube) → 404; `<PROTECT>` → `PORT.ACCESSDENIED`; anything else → 409 `ANALYTICS.CUBE.FAILED`, its status text logged through `Kernel.Fault.LogRaw`, never sent.
- **The vendor's own cube check still applies.** `CubeManager` rows come from `%GetCubeList(.l,"cubes",1)`, and the `STATE` read asks `%CubeExists` and `%CheckPrivilege` first, so a cube the caller's resources hide reads as absent (404).
- **A cube id is kept exactly (AD-13).** A name whose spelling differs from the vendor's logical name (`%GetCubeName`) reads as absent, so one cube is one AD-34 hold key.
- **Both callers (AD-53, AD-34).** The person's row action and the agent's confirmed proposal run one operation under the target's hold, with the same gate, preconditions, change event (`cube`, `updated`, AD-14), read-back (`nothingSent`, AD-58) and audit row. The agent's adds the marker (AD-15). Governance is asked only for the agent (AD-22).
- **Audit (AD-15).** After the namespace is restored, every completed build or synchronize records OcuPilot's own `ConfigChange` (verb `build` or `synchronize`, entity `cube`, effects: the namespace and the cubes updated). It never fails the write.
- **The answer for the screen** (AD-39's fifth exception) is the output lines `Facts in <cube>: <n>` per cube built, `Build errors in <cube>: <n>` when above 0, and `Facts updated in <cube>: <n>` per cube synchronized. They are stored nowhere and never sent to the model.
- **Untrusted content (AD-11, AD-60).** Cube names and captions reach the screen only as interpolated text.
- **Compile order.** A class whose `Parameter` `{...}` value names another project class extends it or declares `DependsOn` on it (20.31's container-compile red).
- **Contended files take add-only edits** (Design Notes › Rule 11).

**Never:**

- A call to `/api/deepsee`, `%Api.DeepSee` or `%DeepSee.REST.*` (their `RepairBuild` and `SynchronizeCube` included).
- A `JOB`, background run or `PORT.STARTED` answer under Gate question Q1's recommended answer. The classic page `JOB`s its build; OcuPilot does not (AD-7).
- In product code: `%BuildCube` with a fact list or `pIndexOnly`, `%KillCube`, `%FixBuildErrors`, `%SetAgentCount`, `%escalateToBuild`, or any vendor method that writes outside the two calls above.
- A product read or write of `^DeepSee.*`, `^OBJ.DSTIME` or `^IRIS.Temp.DeepSee*` other than the one lock probe above. The fixture's cleanup is a test's.
- Edits to `app.routes.ts`, `angular.json` (its budgets and the DW-371 pin), `Screen/Registry.cls`, `Screen/Read.cls`, `Kernel/EntityType.cls`, `Port/LogSourcePort.cls`, `.github/workflows/ci.yml`, `ui/tools/ci-shards.mjs`, `ui/tools/ci-timings.json`, `ui/tools/ci.test.mjs`, `epics.md` or the spine. The lead writes the spine drafts.

## I/O & Edge-Case Matrix

Rows run in USER on `ocupilot-b-ci` with `AnalyticsProbe` **(20.11, planned)** created there, as `_SYSTEM` unless named. "Action" is `POST /api/ocupilot/screens/analytics.cubemanager/action?ns=USER`. Probe cubes: `OcuPilotProbeCategories` (5 rows, no `DSTIME`), `OcuPilotProbeVisits` (1,000 rows, `DSTIME` `AUTO`, related to Categories, so a dependent of it), `OcuPilotProbeGuarded` (resource `%DeepSee_Admin`).

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| List | `GET /screens/analytics.cubemanager/read?ns=USER` | One row per probe cube: `{Name, Caption, Facts, LastBuild, LastUpdate, Synchronizes, Updating, DependentCubes}`. Visits `Synchronizes` true, Categories false; Categories' `DependentCubes` is `OcuPilotProbeVisits`; each `Facts` equals `%GetCubeFactCount` | - |
| Build, person | Build on Categories, typed name `OcuPilotProbeCategories` | 200. Categories 5 and Visits 1,000 facts; both rows' `LastBuild` move; output lines `Facts in OcuPilotProbeCategories: 5` and `Facts in OcuPilotProbeVisits: 1000`; one `ConfigChange` row (`build`, `cube`); no marker | - |
| Build, agent | Key enabled for the test; the agent proposes `analytics.cubemanager.build` on Categories; the person confirms | The card is destructive, with no typed name, and its rows name `OcuPilotProbeVisits` under Dependent cubes. Confirm does as the person's Build, plus the marker | - |
| Build key off | The baseline's `false` | The agent's call is denied by governance and mints nothing; the person's Build still builds | Governance's structured denial |
| Synchronize | 10 Visit rows changed (`AnalyticsProbe.ChangeVisits(10)`), then Synchronize on Visits | 200, no dialog. Output `Facts updated in OcuPilotProbeVisits: 10`; Visits keeps 1,000 facts and its `LastBuild`; one `ConfigChange` row (`synchronize`) | - |
| No DSTIME | Synchronize on Categories | No vendor call, so no new `CubeEvent` row | 409 `ANALYTICS.CUBE.NODSTIME` |
| Not built | `%KillCube` Visits, then Synchronize on Visits | No vendor call; Visits keeps 0 facts | 409 `ANALYTICS.CUBE.NOTBUILT` |
| Busy | The test process holds `^DeepSee.Build("OCUPILOTPROBEVISITS")`, then its `"SYNC"` node instead, in USER; Build and Synchronize on Visits over HTTP | No vendor call; facts and `CubeEvent` rows unchanged | 409 `ANALYTICS.CUBE.BUSY` |
| Moved | The agent's build minted, then the person builds the same cube | The confirm is refused as target-changed (`BuildStamp` is in the subject) | AD-6 fingerprint |
| Read-only | An action in HSLIB | No vendor call | 409 `ANALYTICS.CUBE.READONLY` |
| No analytics | Any read or action in HSCUSTOM | No vendor call | 409 `ANALYTICS.NAMESPACE` |
| Pair missing | P1 (no `%DeepSee_Admin:USE`) | Refused before any vendor call | 403, `failedPair` `%DeepSee_Admin:USE` |
| No WRITE | P4 (`%DeepSee_Admin:USE`, `%DB_USER:R`) | The list answers; both actions refused before any vendor call | 403, `failedPair` `%DB_USER:WRITE` |
| Hidden | P3; `OcuPilotProbeHidden` carries a resource P3 lacks | Absent from the list; an action on it reads absent | 404 |
| Spelling or unknown | Build on `ocupilotprobevisits`, or on `NoSuchCube` | Nothing built | 404 |
| Vendor answers | `AnalyticsCubeSeam` answers `#20006` with 2 errors, `#20005`, and another error | Done with `Build errors in <cube>: 2`; 409 `ANALYTICS.CUBE.BUSY`; 409 `ANALYTICS.CUBE.FAILED`, with the text logged and absent from the body | As listed |

</intent-contract>

## Code Map

All paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-20`. Line numbers were read at `d85b4a6ca99d33d1c88c1211d858f3ba679a68e6`. Stories 20.11, 20.32, 20.33 and 20.35 land first. Their symbols are marked **(20.11, planned)** or **(20.33, planned)**, and Task 0 re-anchors them. Anchor by symbol.

### The sibling to extend: Story 20.23's queue and job actions (commit `6aa1f459`)

- **`src/OcuPilot/Port/InteropPort.cls`** is the action-write shape:
  - `Pairs` :851, `Serves` :901, `Invoke` :1000, `Admit` :1097 (WRITE instead of READ for a write);
  - types :345-361, `IsRuntimeWrite` :795, `IsAnyWrite` :821, `ACTIONKEY` :676;
  - `InvokeTyped` :4683: a read type answers the row, a write type calls `PerformRuntime` → `PerformJobAction` :4984, and a query carrying `ACTIONKEY` is refused through `RowRefusal`/`RuntimeRefusal` :4652/:4662 before anything is stored;
  - `ReadJob` :4804, `JobStatused` :4820;
  - `ENTITY*`/`VERB*` :613-625 and `AuditRuntime` :5015-5030 (`Kernel/Audit/Event.Record`, after the namespace is restored);
  - `SnippetForm` :5032, `Snippet` :5057, `RuntimeSnippet` :5103 (AD-59);
  - `LogFault` :2671, `Deny`, `Refuse`, `Conflict`, `Absent` and `Fail` :2677-2740;
  - `%SYS.Capture` use :7044 and :7460, `EndTestCapture` :6944.
- **`src/OcuPilot/Screen/Tool/InteropAction.cls`** (140 lines): `PrivilegePairs` :89, `ArgumentNamespace`, `PortQuery` :131, `STATEMARKER`, `CONSEQUENCECODE`. **`InteropJobAction.cls`**: `AFTERWORD` :39 and the diff rows :73-100. **`InteropJobStop.cls`**: the parameter block a concrete tool declares.
- **`src/OcuPilot/Screen/Tool/Write.cls`**: parameters :30-244 (`DESTRUCTIVE` :52, `FINGERPRINTSUBJECT`, `PRECONDITIONFIELD`, `PRECONDITIONCODES`, `SCREENACTIONS`, `CLASSICPAGES`, `CHANGEACTION`, `SENDSBODY`), `Destructive()` :579. **`InteropItemTestSend.WriteOutput`** :286 is the output-lines sibling.
- **`Screen/Registry.cls`** :2891 `FingerprintSubjectProblem` validates the subject; **`Screen/Tool/Registry.cls`** :807 finds tools by package scan.

### Kernel (unchanged; the paths both callers take)

- **`Kernel/Proposal/Mint.cls`** :351/:524 (`destructive`), **`Kernel/State/Propose.cls`** :141, `CLAIMLOCKSECONDS` :420.
- **`Kernel/Proposal/Operation.cls`**: `Hold` :58, `HoldTool` :77, `Release` :100, `OutputOf`. **`Confirm.cls`**: the hold :274, `RecordAgentWrite` :478/:492. **`Api/ScreenAction.cls`**: the hold :317, the output :451-456.
- **`Kernel/Proposal/ReadBack.cls`**: `Of` :83, `KindOf` :236, `nothingSent` :147-149.
- **`Kernel/Proposal/Prohibited.cls`**: `COVEREDTYPES` :282, `PortClassOf` :1397, `Prohibits` :1429, the type condition :1440, 20.23's `ReviewedFewOnly` branches :1758-1771, `ReviewedFewOnly` :4370.
- **`Kernel/Governance/Baseline.cls`** `XData Keys` :17. **`Kernel/Audit/Event.cls`**: `EVENTCONFIG` :25, `Record` :194.
- **`Kernel/Shell/Namespaces.cls`** `GlobalDatabase` :84, `RoutineDatabase` :92; **`NamespaceFeatures.cls`** `Reports` :18; **`Screen/Area.cls`** :90 (the `analytics` area).

### Analytics (planned)

- **`Port/AnalyticsPort.cls`** **(20.11, planned)**: `ENDPOINTS`, `PORTALPAIRS`, `Pairs`, `Serves`, `GateClass()`, `Admit`, `Invoke`, private `Deny`/`Refuse`/`Conflict`, the Cubes row builder (`%GetCubeName`, `%GetCubeCaption`, `%GetCubeFactCount`, `GetLastUpdate(…,"build")` as local time), `Snippet`/`SnippetForm`. **(20.33, planned)**: `MDXPAIRS` and `MdxAdmit`'s WRITE-and-read-write check on `GetGlobalDest(ns,"^DeepSee.Cache.Results")`.
- **`Api/AnalyticsError.cls`** **(20.11, planned)**: `NAMESPACE`, `REASONNAMESPACE`; the `MDX*` codes **(20.33, planned)**.
- **`Screen/Descriptor/AnalyticsCubeList.cls`** **(20.11, planned)** is the descriptor sibling; the MDX query descriptor **(20.33, planned)** holds side-bar position 7.
- **Tests (20.11, planned):** `AnalyticsProbe` (`Enable`, `Create`, `Remove`, `Gone`), `AnalyticsGate` (P1, P2 and its principal helper), `AnalyticsGateSeam`, `AnalyticsPort.TestTheReadsWriteNothing`, `AnalyticsDescriptor`; `ui/tools/analytics.test.mjs`; `ui/browser/analytics.browser-spec.mjs`.

### Tests and rosters

| Roster | Anchor | Row shape (20.23's) |
|---|---|---|
| Other-port writes | `Test/ToolWrite.cls` :1338, 51 | the integer and its sentence |
| Registry size and names | `Test/ReadTool.cls` :93, 392 | count and the sorted names |
| Empty-argument refusals | `Test/ToolRoundTrip.cls` :96 `REFUSEEMPTY` | `interop.jobs.stop:TOOL.ARGUMENTS` |
| Write coverage | `Test/SurfaceCoverage.cls` `XData Coverage` :54 | `<tool name=".." class=".." method=".."/>` |
| Per-family pairs | `Test/ToolEmit.cls` :234 | an `ElseIf %Extends(<family>)` branch |
| Disabled keys | `Test/GovernanceBaseline.cls` `DISABLED` :15 and its sentence :71; `Test/Governance.cls` (read :160); `Test/ToolDispatch.cls` :179 | the key, in baseline order |
| Classic pages | `Test/ClassicPageGate.cls` `OWNPAIRS` :75, `RUNTIMEKEYS` :84, the count sentence :163; `Test/MappingDescriptor.cls` `CLASSICROSTER` :24 | `tool=<own pairs>`; `tool=<page>` |
| Covered types | `Test/Prohibited.cls` :229 | the `CoveredTypes()` string |
| Screens | `Test/StageTwoTools.cls` `XData Elsewhere` :121, `TestTheRosterAndElsewhereAreEveryRegisteredScreen` :415 | `<screen name=".."/>` |
| Port gate | `Test/PortGate.cls` `ROSTER` :29 | `<port>=<PAIRS>;<PAIRS>` and a denial leg |
| Read shapes | `Test/Descriptor.cls` `XData ReadShapes` :67 | `<screen name filter sort kinds/>` |
| Navigation | `Test/Navigation.cls`, the analytics block | pinned order |
| Unchanged, checked | `Test/SaveHoldCoverage.cls` :31 (routes only; no new route), `Test/EndpointCoverage.cls`, `Test/DraftRegistry.cls`, `Test/InteropSettingDescriptor.cls` :259 | - |

- **Fixture siblings:** `Test/InteropItemSeam.cls`, `Test/GovernanceFixture.cls`, `Test/Http.cls`, `Test/InteropJobActions.cls` (both callers).
- **Arming:** `scripts/ci-throwaway.sh`, the `# classes:` lines before `OCUPILOT_ALLOW_PRINCIPALS` (:511).
- **Client tests:** `ui/tools/navigation.test.mjs` :131, `ui/tools/screen-mirror.test.mjs` owners :2451, `ui/tools/strings.test.mjs` (bound 3,800), `ui/tools/citations.test.mjs`.

### Client

- **`ui/src/app/shell/screen-action-handler.ts`**:
  - `SCREEN_ACTION_DESCRIPTORS` :70;
  - `DESTRUCTIVE_ACTIONS` :521, a global list of action ids that has no `build` yet;
  - `DESTRUCTIVE_CONSEQUENCES` :549 (a destructive action without one is not drawn, DW-389);
  - `TYPED_NAME_ROWS` :649, `WARNING_CONSEQUENCES` :713;
  - the outcome dialog :1557 and `outcomeLinesOf` :1854.
- **`ui/src/app/core/screen-actions.ts`**: `ACTION_LABELS` :112, `DESCRIPTOR_ACTION_LABELS` :160. **`core/proposal-view.ts`**: `CONSEQUENCE_*` (about :390), `consequenceSentence` :449. **`shell/proposal-card.ts`** :122 (the destructive bar).
- **`core/strings.ts`**, `core/screens.generated.ts` (regenerated by `node tools/screen-mirror.mjs`).
- **EXPERIENCE.md**: the side-bar table :157-170, its prose :159, the Dialogs list :173, Fixed strings :604.

### Vendor (read only; `irislib/%DeepSee/`)

- **`Utils.cls`:**
  - `%IsCubeAvailable` :141 (a 0.1 s probe of `^DeepSee.Build(idx,"QUERY")`; code `build` while a build holds the cube);
  - `%BuildCube` :223 (`pAsync=1, pVerbose=1, pIndexOnly=0, pMaxFacts=0, pTracking=1, .pBuildStatistics, pFactList`; expands to dependents :244);
  - `%BuildOneCube` :341: a `CubeEvent` row before the lock :389-400, `Lock +^DeepSee.Build(idx):1` → `#20005` :433, the agents' single-build lock with no timeout :455, `^DeepSee.InitCode` :478, `%KillFacts` :553, `#20006` :1104-1109, `^DeepSee.CloseCode` :1132;
  - `%SynchronizeCube` :1964 (expands to dependents; a pending time-dimension upgrade escalates to a build :2002-2025);
  - `%SynchronizeOneCube` :2088 (`"SYNC"` lock, 30 s; a never-built cube becomes a full build :2142-2148; `#20008` NoDSTIME :2221-2224);
  - `%GetCubeDSTime` :2663, `%GetCubeFactCount` :3097, `%CheckPrivilege` :3331, `%GetCubeList` :7962.
- **`CubeUtils.cls`** `%GetDependentCubes` :92 (writes nothing; answers a count, the uppercase indexes as subscripts). **`CubeManager/Utils.cls`** `GetLastUpdate` :101-113 (`"synch"` is any update; `"build"` excludes synchronizes).
- **`UI/CubeRegistry.cls`**: `PAGENAME` "Cube Manager" :23, `RESOURCE` `%DeepSee_Admin` :25. **`UI/Dialog/RepairBuild.cls`** :268-274 `JOB`s `%BuildCube` and polls a tracking global.
- **`CubeManager/CubeEvent.cls`** :12-111: fields, `UserName` set from `$USERNAME`.
- **`%SYSTEM/WorkMgr.cls`** :38 and :74: a queued unit of work runs in the caller's security context.

## Tasks & Acceptance

**Execution:**

- [ ] **Task 0 (re-anchor and measure, no product code).** First run `git rev-parse --show-toplevel`.
  1. Confirm that 20.11, 20.32, 20.33 and 20.35 are implemented here: `Port/AnalyticsPort.cls`, `Api/AnalyticsError.cls`, `Test/AnalyticsProbe.cls`, `Test/AnalyticsGate.cls` and the MDX query descriptor exist. If one is missing, stop and report to the lead.
  2. Re-anchor every planned symbol above, and record:
     - `ReadTool`'s count, `ToolWrite`'s other-port count (51 expected), `ClassicPageGate`'s count sentence, and the strings count against 3,800;
     - the analytics block in `Navigation.cls` and the next free side-bar position (8 expected);
     - `AnalyticsPort`'s parameters and its Cubes row builder, and where 20.33's destination check lives;
     - `AnalyticsProbe`'s cube and class names, and whether `Remove` and `Gone` already clear the residue Design Notes › Measured lists.
  3. Run `git -C /Users/jbrandt/git/OcuPilot/.worktrees/epic-23 diff --stat origin/feature/OCU-1_ocupilot-mvp...HEAD` if that worktree exists. If Epic 23 changed a line this story edits, stop and ask the lead. Stop and ask too if adding `CubeManager` to the port's `ENDPOINTS` needs an edit to `Screen/Registry.cls` or `Screen/Read.cls` (Rule 11).
  4. Measure on `ocupilot-b-ci` with `AnalyticsProbe`:
     1. `%SYS.Portal.Resources.NormalizePage("_DeepSee.UI.CubeRegistry.zen")` and that page's compiled `RESOURCE`;
     2. `%IsCubeAvailable`, `%GetCubeDSTime`, the cube class's `%GetSourceInfo`, `%GetDependentCubes`, `GetLastUpdate(…,"synch")` and the `"SYNC"` lock probe write nothing (USER's `^DeepSee*` and `^IRIS.Temp.DeepSee*` node counts unchanged), and how long each takes;
     3. that `%DeepSee_Architect` grants no public permission (else name another `%DeepSee_*` resource that grants none);
     4. `%SYS.Namespace.GetGlobalDest("USER","^DeepSee.Fact")` names USER's database, and HSLIB's names a read-only one;
     5. that the probe's Categories source declares no `DSTIME` and Visits' declares `AUTO`.

  A measurement that contradicts this spec halts the stage with its evidence.
- [ ] **`src/OcuPilot/Api/AnalyticsError.cls`** **(20.11, planned; add-only).** Codes and sentences:
  - `ANALYTICS.CUBE.BUSY`, `ANALYTICS.CUBE.NODSTIME`, `ANALYTICS.CUBE.NOTBUILT`, `ANALYTICS.CUBE.READONLY` and `ANALYTICS.CUBE.FAILED`, each with its `REASON*`, the sentences in Design Notes › Strings;
  - the consequence codes `ANALYTICS.CUBE.BUILD` and `ANALYTICS.CUBE.SYNCHRONIZE`;
  - a `CubeCodes` list and `ReasonFor` branches, as `InteropError`'s `RuntimeCodes` and `ReasonFor` do.
- [ ] **`src/OcuPilot/Port/AnalyticsPort.cls`** **(20.11, planned; add-only members).**
  - **Declarations.**
    - `CubeManager` joins `ENDPOINTS`; `MANAGERPAIRS = "%DeepSee_Portal:USE,%DeepSee_Admin:USE"`.
    - Types `STATE`, `BUILD` and `SYNCHRONIZE` on `CubeManager`, beside `LIST`. `ACTIONKEY` and `NAMESPACEKEY` keys, as `InteropPort`'s.
    - `Serves`, `Pairs` and an `IsWrite` predicate.
  - **Gate.** `Admit` adds the Always list's fourth step for the two write types. The destination check is extracted from 20.33's MDX gate into one helper taking the global (`^DeepSee.Cache.Results` for MDX, `^DeepSee.Fact` here), and both call it.
  - **`CubeManager` `LIST`.** One row per `%GetCubeList(.l,"cubes",1)` entry, through 20.11's Cubes row builder, extended rather than copied:
    - `{Name, Caption, Facts, LastBuild}` as the Cubes read answers them;
    - `LastUpdate`, from `GetLastUpdate(…,"synch")`, in the same local form;
    - `Synchronizes`, the source's `dstime` from the cube class's `%GetSourceInfo`;
    - `Updating`, the Always list's probe;
    - `DependentCubes`, the `%GetDependentCubes` indexes as logical names (`%GetCubeName`), sorted and joined with `, `.

    It stops at `maxRows+1`, and its rows are built after the namespace is restored.
  - **`STATE`.** One cube by its exact logical name (absent unless `%CubeExists`, `%CheckPrivilege` and the spelling all hold). It answers `{Name, Namespace, Facts, LastBuild, BuildStamp, LastUpdate, Built, Synchronizes, Updating, DependentCubes}`:
    - `BuildStamp` is `GetLastUpdate(…,"build")` as the vendor stores it, to the millisecond, so two builds in one second still differ (`LastBuild` shows seconds);
    - `Built`, `Synchronizes` and `Updating` are judged over the cube and its dependents.

    When the query carries `ACTIONKEY`, a state the action does not fit is refused with its precondition code.
  - **`BUILD` and `SYNCHRONIZE`.**
    - Re-read and re-judge the state, then call the vendor through two seam methods, `VendorBuild` and `VendorSynchronize`, inside the capture.
    - Map the answer as the Always list says, and answer `{lines}` from `pBuildStatistics("cubes",<index>,"factCount"/"errors")` or the synchronize's per-cube `pFactsUpdated`.
    - Record the audit row through a private `AuditWrite`, the sibling of `InteropPort.AuditRuntime`.
  - **`Snippet`/`SnippetForm`.** The two calls as script, the cube name in a doubled-quote literal, as `InteropPort.RuntimeSnippet` composes them.
  - **Doc comments** name AD-7, AD-29, AD-51, AD-53 and AD-65.
- [ ] **`src/OcuPilot/Screen/Tool/AnalyticsAction.cls`** (new, abstract; follows `InteropAction`, Design Notes › Rule 31).
  - `PORTCLASS` `AnalyticsPort`, `READTYPE` `STATE`, `SENDSBODY` 0, `READSVALUES` 1, `NAMESPACEFIELD` `Namespace`, `STATEMARKER` `Updating`, `CLASSICPAGES` `%DeepSee.UI.CubeRegistry`.
  - `IdArgument` `Name`, `IdParam`, `SettableFields`, `Consequence`, `PortQuery`, `ArgumentNamespace`.
  - `PrivilegePairs`: the screen's pairs (`Screen.Gate.RequiredPairs`), then WRITE on the resource of the database `^DeepSee.Fact` maps to, then READ on the routines database, then each classic page's custom resource, each once.
  - A `StateDiff` whose rows are Cube, Facts, Last build, Last update and Dependent cubes, with the action's afterword on Last build (Build) or Last update (Synchronize), as `InteropJobAction`'s rows carry `AFTERWORD`.
  - `WriteOutput`, which answers the port's `lines` as `InteropItemTestSend.WriteOutput` does.
- [ ] **`src/OcuPilot/Screen/Tool/AnalyticsCubeBuild.cls`** (new):
  - `TOOLNAME` `analytics.cubemanager.build`, `SCREENACTIONS` `build`, `WRITETYPE` `BUILD`, `DESTRUCTIVE` 1, `CHANGEACTION` `updated`;
  - `FINGERPRINTSUBJECT` `Updating,DependentCubes,BuildStamp,Namespace`, `PRECONDITIONFIELD` `Updating`;
  - `PRECONDITIONCODES` `ANALYTICS.CUBE.BUSY,ANALYTICS.CUBE.READONLY,ANALYTICS.NAMESPACE`, `CONSEQUENCECODE` `ANALYTICS.CUBE.BUILD`, `AFTERWORD` "Rebuilt now";
  - `DESCRIPTION`: "Rebuild one cube from its source: deletes its facts and rebuilds them, with every cube that depends on it. It is the classic Cube Manager's Build, also called Repair Build. The cubes cannot be queried while it runs."
- [ ] **`src/OcuPilot/Screen/Tool/AnalyticsCubeSynchronize.cls`** (new):
  - `TOOLNAME` `analytics.cubemanager.synchronize`, `SCREENACTIONS` `synchronize`, `WRITETYPE` `SYNCHRONIZE`, `DESTRUCTIVE` 0, `CHANGEACTION` `updated`;
  - `FINGERPRINTSUBJECT` `Updating,Built,Synchronizes,DependentCubes,Namespace`, `PRECONDITIONFIELD` `Synchronizes`;
  - `PRECONDITIONCODES` adds `ANALYTICS.CUBE.NODSTIME` and `ANALYTICS.CUBE.NOTBUILT`; `CONSEQUENCECODE` `ANALYTICS.CUBE.SYNCHRONIZE`, `AFTERWORD` "Synchronized now";
  - `DESCRIPTION`: "Apply the source changes recorded since a cube's last update to it and to the cubes that depend on it. Its source must record changes (DSTIME). The cube stays queryable."
- [ ] **`src/OcuPilot/Screen/Descriptor/AnalyticsCubeManager.cls`** (new; sibling of `AnalyticsCubeList`).
  - Declarations:
    - route `analytics/cube-manager`, side-bar position 8, archetype `list`;
    - area `analytics`, scope `namespace`, `built` true, `refreshes` false;
    - `toolIdentifier` `analytics.cubemanager`, pairs `%DeepSee_Portal:USE` and `%DeepSee_Admin:USE` (own), `classicPage` `%DeepSee.UI.CubeRegistry`;
    - entity `cube`, id single `Name`;
    - read `analytics` `CubeManager`;
    - `rowActions` `[{"id": "build", "selfProtection": ""}, {"id": "synchronize", "selfProtection": ""}]`;
    - `classicLinkExemption` all false, `context.fields` equal to the read fields, three prompts.
  - Columns: Name `name`, Caption `text`, Facts `number`, Last build and Last update `text`, Synchronizes and Updating `status`, Dependent cubes `text`; default sort Name.
  - The doc comment names AD-5, AD-29, AD-44, AD-51, AD-53 and AD-65.
- [ ] **`src/OcuPilot/Kernel/Proposal/Prohibited.cls`** (add-only): a type parameter for `cube`, appended to `COVEREDTYPES` and the :1440 condition, and a branch calling `ReviewedFewOnly`. OcuPilot owns no cube, so no self-protection predicate applies (AD-10).
- [ ] **`src/OcuPilot/Kernel/Governance/Baseline.cls`** (add-only): `"analytics.cubemanager.build": false` and `"analytics.cubemanager.synchronize": true` (AD-22).
- [ ] **Client.**
  - `ui/src/app/shell/screen-action-handler.ts`:
    - `SCREEN_ACTION_DESCRIPTORS` gets the descriptor;
    - `DESTRUCTIVE_ACTIONS` gets `build`;
    - `DESTRUCTIVE_CONSEQUENCES` gets `{build: STRINGS.analyticsCubeBuildConsequence}`;
    - `TYPED_NAME_ROWS` gets `{name: 'Name', field: '', equals: '', advisory: ''}`;
    - no `WARNING_CONSEQUENCES` entry, so Synchronize sends at once.
  - `ui/src/app/core/screen-actions.ts`: the two labels.
  - `core/proposal-view.ts`: the two consequence codes.
  - `core/strings.ts` (add-only): Design Notes › Strings.
  - Then `cd ui && node tools/screen-mirror.mjs`.
- [ ] **`src/OcuPilot/Test/AnalyticsProbe.cls`** **(20.11, planned; add-only methods):**
  - `ChangeVisits(pCount)` updates that many Visit rows' measure.
  - `CreateHidden()` compiles and builds `OcuPilotProbeHidden` on the Category source, carrying Task 0's resource; `RemoveHidden()` removes it.
  - `Remove` and `Gone` also cover the hidden cube and the build residue Design Notes › Measured lists, where 20.11's do not already.
- [ ] **`src/OcuPilot/Test/AnalyticsCubeSeam.cls`** (new; sibling of `AnalyticsGateSeam` and `InteropItemSeam`): an `AnalyticsPort` subclass whose `VendorBuild` and `VendorSynchronize` answer a status the test sets.
- [ ] **`src/OcuPilot/Test/AnalyticsCubeManager.cls`** (new; armed `OCUPILOT_ALLOW_PRINCIPALS`; `AnalyticsProbe` `Remove`, `Enable` and `Create` in `OnBeforeAllTests`, `Remove` and `Gone` in `OnAfterAllTests`). The port's own rows and refusals, in process and, where the matrix says so, over HTTP:
  - the `List` row equals the vendor's own answers;
  - `STATE` for the spelling and unknown rows;
  - No DSTIME, Not built (Visits is rebuilt after the leg), Read-only and No analytics, and Busy: the test process takes the build lock, then the `"SYNC"` node, switched to USER and released at the end, while an HTTP action (another process) acts. Each asserts the `CubeEvent` row count unchanged;
  - the Vendor answers rows, calling `AnalyticsCubeSeam` in process;
  - `TestTheNewReadsWriteNothing` extends 20.11's node-count assertion to `LIST` and `STATE`.
- [ ] **`src/OcuPilot/Test/AnalyticsCubeActions.cls`** (new; armed; probe as above). Both callers end to end over HTTP:
  - Build, person and agent: the card's rows, `destructive`, the confirm, the facts and `LastBuild`, the output lines, the `ConfigChange` rows, and the marker for the agent only;
  - Build key off (`GovernanceFixture`);
  - Synchronize;
  - Moved.
- [ ] **`src/OcuPilot/Test/AnalyticsCubeGate.cls`** (new; armed; sibling of `AnalyticsGate`, whose principal helper becomes a public class method rather than being copied).
  - P1: the matrix row.
  - P3 holds the floor, `%DeepSee_Admin:USE`, `%DB_USER:RW` and READ on the install namespace's code database. P3 builds Visits through the screen, and the agent's `analytics.cubemanager.read` answers P3 the same rows as the screen read. With `CreateHidden`, the Hidden row.
  - P4 is P3 with `%DB_USER:R`: the No WRITE row.
- [ ] **`src/OcuPilot/Test/AnalyticsDescriptor.cls`** **(20.11, planned; add-only):** the cube manager's declarations, `Registry.Validate`, `NormalizePage` equal to `classicPage`, and the page's compiled `RESOURCE` naming a pair the screen declares.
- [ ] **`src/OcuPilot/Test/PortGate.cls`**: `MANAGERPAIRS` joins `AnalyticsPort`'s `ROSTER` row, with its denial leg.
- [ ] **Rosters under `src/OcuPilot/Test/`, each row's name read from the instance, never recalled:**
  - `ToolWrite` 51 → 53, with its sentence;
  - `ReadTool` +3 (the derived read and two writes);
  - `ToolRoundTrip` `REFUSEEMPTY`: `analytics.cubemanager.read:ANALYTICS.NAMESPACE`, and both writes `:TOOL.ARGUMENTS`;
  - `SurfaceCoverage`: two `<tool>` rows naming `AnalyticsCubeActions`' methods;
  - `ToolEmit`: an `AnalyticsAction` branch;
  - `GovernanceBaseline` `DISABLED` and its sentence, `Governance`, `ToolDispatch`: `analytics.cubemanager.build`;
  - `ClassicPageGate`: `OWNPAIRS` +2 and its count sentence, and a `CUBEBUILDKEY` parameter beside `RUNTIMEKEYS` (each story names its own disabled keys there), enabled where those are (:601);
  - `MappingDescriptor` `CLASSICROSTER` +2;
  - `Prohibited`'s covered types;
  - `StageTwoTools` `Elsewhere`: `<screen name="AnalyticsCubeManager"/>`;
  - `Descriptor` `ReadShapes`: one row;
  - `Navigation`: the analytics block, +1.
- [ ] **`scripts/ci-throwaway.sh`**: the three new armed classes on the `# classes:` lines before `OCUPILOT_ALLOW_PRINCIPALS`.
- [ ] **`ui/tools/analytics.test.mjs`** **(20.11, planned)**: each new `REASON*` equals its `strings.ts` key and its EXPERIENCE.md literal; the three output line templates equal their EXPERIENCE.md literals. **`ui/tools/navigation.test.mjs`**: the route in the roster. **`ui/tools/screen-mirror.test.mjs`**: the descriptor joins the owners list. **`ui/tools/strings.test.mjs`**: raise its bound only as that file says, when the count comes within 50.
- [ ] **`ui/browser/analytics-cube-manager.browser-spec.mjs`** (new; sibling of `analytics.browser-spec.mjs`).
  - **`before`**: refuse the live container, require readiness `installed`, and through `runIris` run `AnalyticsProbe` `Remove`, `Enable` and `Create("_SYSTEM")`. **`after`**: `Remove`, then assert `Gone`.
  - **Tests**, each with its mutation comment, in USER:
    1. **AC1 and AC7:** Build on Categories through the typed-name dialog. The outcome shows the two facts lines, the Cube manager's rows show the new Last build without a reload, and the Cubes list then shows it too.
    2. **AC2:** after `ChangeVisits(10)`, Synchronize on Visits shows `Facts updated in OcuPilotProbeVisits: 10`.
    3. **AC3:** Synchronize on Categories shows the No DSTIME sentence.
    4. **AC6:** the per-spec `structural` helper at 1280 light, 720 light and 1280 dark finds no fresh entry, and the screen shows three prompts.
- [ ] **EXPERIENCE.md:**
  - :157-170 and :159: Analytics gains Cube manager. The sentence: "Cube manager (Story 20.34): Build and Synchronize as row actions; Build is also the classic Repair Build."
  - :173: the destructive dialog list gains "the Cube manager's Build (typed name)".
  - :604: the literals, with a Story 20.34 clause.
  - Then run `cd ui && npm run test:tools`.
- [ ] **Roster sweep (Rule 30).** Search `src/OcuPilot/Test`, `ui/tools`, `ui/browser` and the `ui/src` specs for:
  - the rosters above;
  - `DESTRUCTIVE_ACTIONS`;
  - the analytics side-bar count;
  - the built-screen count that Screen permissions derives.

  Each changed file joins `(loop)`.

**Acceptance Criteria:**

- **AC1 (the story's criterion: a build or a repair is a confirmed write).**
  - **Given** `AnalyticsProbe` in USER, and the person on the Cube manager.
  - **When** the person builds `OcuPilotProbeCategories` through the typed-name dialog, or the agent proposes `analytics.cubemanager.build` with its key enabled and the person confirms.
  - **Then:**
    - Categories and its dependent Visits are rebuilt (5 and 1,000 facts), and their Last build moves;
    - the agent's card is destructive and names `OcuPilotProbeVisits` among the dependent cubes before Confirm;
    - each caller records one `ConfigChange` row, and only the agent's records the marker;
    - a refused Build writes no `CubeEvent` row.
- **AC2 (a synchronize is a confirmed write that loses nothing).**
  - **Given** 10 changed Visit rows.
  - **When** Synchronize runs on Visits, as the person's action or the agent's confirmed proposal.
  - **Then:**
    - exactly the 10 changes are applied (`Facts updated in OcuPilotProbeVisits: 10`), and Visits keeps 1,000 facts and its Last build;
    - each caller records its `ConfigChange` row, and only the agent's records the marker.
- **AC3 (refused by name before any vendor call).**
  - **Given** the matrix's No DSTIME, Not built, Busy, Read-only and No analytics states.
  - **When** either action runs.
  - **Then** each answers its code and sentence, and the vendor writes no `CubeEvent` row and changes no fact.
- **AC4 (the gate is OcuPilot's, and the vendor's cube check still applies; AD-29, AD-65).**
  - **Given** P1, P3 and P4.
  - **When** each reads or acts.
  - **Then:**
    - P1 is refused naming `%DeepSee_Admin:USE`, and P4's actions naming `%DB_USER:WRITE`;
    - P3 does not see `OcuPilotProbeHidden`, and an action on it reads absent;
    - `PortGate` holds `MANAGERPAIRS` and its denial.
- **AC5 (governance; AD-22).**
  - **Given** the baseline.
  - **When** the agent proposes a Build.
  - **Then** governance denies it while the person's Build still runs, and Synchronize is allowed for the agent.
- **AC6 (declared, rostered, structural).**
  - **Given** the descriptor and the two tools.
  - **When** the instance validates them and the build regenerates the mirror.
  - **Then:**
    - each validates on both sides, with three prompts;
    - the `Elsewhere` row is load-bearing (removing it reddens that test alone);
    - Analytics navigation carries the Cube manager at its pinned position;
    - no floor principal opens it, because no shipped role but `%All` holds `%DeepSee_Admin`;
    - the DW-1337 structural gate finds no fresh entry in either theme.
- **AC7 (Integration, Rule 1).**
  - **Given** P3 signed in.
  - **When** a Build completes on the Cube manager.
  - **Then:**
    - 20.11's Cubes read, `GET /screens/analytics.cubes/read?ns=USER`, answers the new `LastBuild` and `Facts`;
    - the Cube manager re-fetches its rows on the `cube` change event, without a reload;
    - the agent's `analytics.cubemanager.read` answers P3 the same rows as the screen read.
- **AC8 (the fixture leaves USER as found).**
  - **Given** a run of any test class or the browser spec.
  - **When** it ends.
  - **Then** `AnalyticsProbe.Gone()` is true: no probe cube or class, the hidden cube included, no probe `CubeEvent` row and none of the residue Design Notes › Measured names, and USER's analytics flags read their recorded values.

## Spec Change Log

- 2026-10-15, spec gate (runner): Q1, Q2 and Q3 ruled as recommended (A each; none conflicts with an AD); the spine carries the Story 20.34 clauses in AD-65, AD-51, AD-7, AD-15, AD-22, AD-8, AD-44 and AD-10.

## Review Triage Log

## Design Notes

**Governing ADs (Rule 6).**

- **AD-65:** the port's write extension, its gate and its vendor calls.
- **AD-7:** each write finishes in its own request; Gate question Q1.
- **AD-51:** action-style writes over a port-composed `STATE`; declared subjects.
- **AD-52:** `AnalyticsPort` is the tools' declared port.
- **AD-53:** two callers of one operation.
- **AD-6:** the proposal and its fingerprint. **AD-34:** the hold.
- **AD-22:** Build `false`, Synchronize `true`.
- **AD-15:** OcuPilot's own `ConfigChange`; Gate question Q2.
- **AD-10:** `cube` is covered, `ReviewedFewOnly`.
- **AD-29:** the gate. **AD-8:** pairs. **AD-64:** the screen is adjustable; `MANAGERPAIRS` is not, so a lowered screen still refuses at the port.
- **AD-44:** the classic page. **AD-13:** the cube id. **AD-14:** the change event. **AD-58:** `nothingSent`. **AD-59:** snippets.
- **AD-5:** one descriptor, no page code. **AD-16:** switched calls. **AD-36:** the read and its cap.
- **AD-11 and AD-60:** untrusted names. **AD-39:** refusal sentences once on the server, and the output lines.

Checked, not engaged: AD-41 and AD-42 (no spawn under Q1 A), AD-26 (no 202), AD-21 (no caller text reaches SQL), AD-47 and AD-63 (nothing framed), AD-40 (unchanged).

**Measured at this plan on `ocupilot-b-ci`** (2026-10-15; IRIS for Health 2026.2 build 221U; auditing on). Analytics was enabled on `/csp/user`, three probe classes and three cubes were built (one related to another), and everything was removed and verified gone. USER's flags read 0 again.

- **Timings** (wall seconds, `pVerbose` 0, 16 cores):

  | Source rows | Async build (agents) | Single-process build |
  |---|---|---|
  | 1,000 | 0.06 | 0.06 |
  | 100,000 | 1.4 to 1.5 | 2.1 |
  | 1,000,000 | 4.8 | 20.9 |

  - A 5-row cube took 3.8 s, because it also rebuilt its 1,000,000-row dependent.
  - A synchronize of 10 changes over 1,000,000 facts took 0.055 s.
- **During a build:** facts read 0 throughout, `%IsCubeAvailable` read 0 with code `build`, and MDX failed after 1 s ("Cube is locked for rebuilding").
- **Locks:**
  - A build against a held build lock waited 1 s, then `#20005`. It left the facts untouched and saved a failed `build` `CubeEvent` row, which `GetLastUpdate("build")` counts.
  - A synchronize against a held build lock waited 30 s, then `#20005`.
  - A build against a held `"SYNC"` node failed after 1 s.
  - A cascade whose dependent was locked rebuilt the target and then failed. It is not atomic.
- **Synchronize:**
  - On a never-built cube it ran a full build and answered OK with 0.
  - On a source without `DSTIME` it answered `#20008` ("does not support %SynchronizeCube").
  - An unknown cube answered `#20013`.
  - A build with 2 bad rows of 6 answered `#20006` and kept 4 facts.
- **Audit and records:**
  - No build, synchronize or refusal wrote an audit row. Toggling the web application's flags wrote `ApplicationChange` rows.
  - `CubeEvent` gets one row per cube per operation, with `UserName` = `$USERNAME`.
  - An in-flight row reads "Build In Progress" as an error status.
- **`%GetDependentCubes`** answered `1` with the node `("OCUPILOTPROBE34VISITS")`, and wrote nothing.
- **Residue** `%KillCube` and a class delete leave: `^DeepSee.Cache.Results(<mixed-case cube>)`, `^DeepSee.Update("classes",<source class>)`, and tracking nodes in `^IRIS.Temp.CubeManagerUpdateTracking`, `DeepSeeTracking` and `DeepSeeBuildStats`. The vendor counters (`^DeepSee.Update`, `Tasks`, `TaskGroups`, the `CubeEvent` id) and the work-queue pool stay, as 20.11 names.

**Decisions.**

- **In the request, on the vendor's agents.** At the measured rate a 1,000,000-fact cube builds in 5 s, well inside the Web Gateway's `Server_Response_Timeout` of 60 s (`Installer.GatewayResponseTimeout` reads it). The confirm or action request waits for the vendor's agents, which run in the caller's security context (`WorkMgr.cls`:38), so the mutation is the person's own, as a production start's jobs are under AD-62 (6). Gate question Q1.
- **`pTracking` 0.** OcuPilot reads no tracking global. 1 would kill another build's progress nodes before the lock is taken (`Utils.cls` :373, :1175) and leave IRISTEMP nodes keyed by the request's pid.
- **Synchronize never builds.** The vendor turns a synchronize of a never-built cube into a full build. Refusing it keeps the destructive operation behind Build's key. A never-built cube has no facts to lose, but a full build can be long and makes the cube unqueryable while it runs.
- **Preconditions span the dependents,** because both vendor calls update them in the same call and a dependent's lock or missing `DSTIME` fails the call after the target changed.
- **The `"SYNC"` probe is needed.** Without it, a Build that meets a running synchronize reaches the vendor, waits 1 s, and leaves a failed `build` row that moves Last build.
- **No impact route.** Dependent cubes are a column of the row the person acts on and a row of the agent's card, so `Kernel/Proposal/Impact.cls`, a roster of removal impacts, is untouched.
- **`BuildStamp` is in Build's subject.** A build confirmed after someone else's build is refused as moved, so two people do not rebuild a cube twice for one intent.
- **Output lines are label-first** ("Facts in X: 5"), so no plural form is needed on the server.
- **The hidden cube** exists only while `AnalyticsCubeGate` runs, because `%DeepSee_Admin`, the guarded probe cube's resource, is the Cube manager's own pair and so hides nothing from its users. 20.11's tests never see it.

**Gate questions (for the orchestrator; none blocks under its recommended answer).**

- **Q1, a build longer than a request (AD-7).** *Ruled (A) by the lead at the gate, 2026-10-15: inside the confirm request, as AD-7 says; the lost answer past the Web Gateway timeout is a named limit.*
  - (A) As planned: the write runs in its request on the vendor's agents, with no OcuPilot cap. A build that outlasts the gateway's 60 s keeps running in that request's process to its end, writing its ledger row, marker and audit row. Its HTTP answer is lost, so the person sees a gateway fault while the rows show the result. Named limit; scale as measured. **Recommended.**
  - (B) Run it as the classic page does: `JOB` `%BuildCube`, wait up to 30 s, then answer 202 `PORT.STARTED`, with the row reading Updating until it ends. This needs an AD-7 clause (a confirmed mutation in a process OcuPilot spawns), an AD-42 fifth spawn site, AD-26's continuation for an in-process port, and a kind on 20.33's `Kernel/Shell/BackgroundRun`. About a third more work (inference).
  - (C) Refuse a build whose sources hold more than a row cap. *Rejected:* the rate depends on cores and on the cube's own code.
- **Q2, the audit record (AD-15).** *Ruled (A) by the lead at the gate: OcuPilot's own `ConfigChange`, as 20.23, 20.5 and 20.6 do.*
  - (A) OcuPilot's own `ConfigChange` from both callers, as 20.23, 20.5 and 20.6 record unaudited vendor actions. The vendor's `CubeEvent` rows are its own bookkeeping. **Recommended.**
  - (B) The marker alone, and the person's action as a named gap (AD-53).
- **Q3, the user code a build runs.** *Ruled (A) by the lead at the gate: a named limit; it runs as the signed-in person, as from the classic page.* A build runs the cube's source expressions and callbacks (`%OnBuildCube`, `%OnProcessFact` and the others), `^DeepSee.InitCode` and `CloseCode`, and the registry's PostBuild code. A synchronize runs its PreSynch and PostSynch code.
  - (A) Named limit: it runs as the signed-in person, as from the classic page and Architect, and the consequence sentences say so. It is the cube author's code, as 20.33's computed dimensions are. **Recommended.**
  - (B) Refuse a namespace or cube that defines any of it.

**Spine drafts (Rule 20; the lead writes them at the gate):**

- **AD-65, a Story 20.34 clause:** "The cube manager's build and synchronize run through `AnalyticsPort`'s `CubeManager` `BUILD` and `SYNCHRONIZE` behind `MANAGERPAIRS` and WRITE on the database `^DeepSee.Fact` maps to (a read-only one is refused 409 `ANALYTICS.CUBE.READONLY`). Over a port-composed `STATE` that spans the cube and its dependents, they refuse by name, before any vendor call: an update in progress (`ANALYTICS.CUBE.BUSY`), and for a synchronize a source without `DSTIME` (`ANALYTICS.CUBE.NODSTIME`) or a never-built cube (`ANALYTICS.CUBE.NOTBUILT`). They call `%BuildCube(cube,1,0,0,0,0)` and `%SynchronizeCube(cube,0)` inside an output capture. The reads `%IsCubeAvailable`, `%GetCubeDSTime`, `%GetSourceInfo`, `%GetDependentCubes` and `GetLastUpdate(…,"synch")` join the measured pure reads, and the zero-timeout `"SYNC"` lock probe is the one vendor-global name the port uses."
- **AD-51, a case:** "`AnalyticsPort` answers the cube tools' fresh read through a port-composed `STATE` type (Story 20.34)."
- **AD-7** (under Q1 A): "A cube build or synchronize runs in its confirm or action request on the vendor's agents, which run in the caller's security context (Story 20.34; measured, 1,000,000 facts in 4.8 s). A build that outlasts the Web Gateway's response timeout runs to its end in that request's process; its answer is lost (named limit)."
- **AD-15, a named case:** "The cube manager's build and synchronize, which the vendor does not audit (its `CubeEvent` rows are bookkeeping; measured, auditing on), record OcuPilot's own `ConfigChange` from either caller, beside the marker for an agent write (Story 20.34)."
- **AD-22:** "`analytics.cubemanager.build` ships `false`; `analytics.cubemanager.synchronize` ships `true` (Story 20.34)."
- **AD-8:** "The Cube manager requires `%DeepSee_Admin:USE`, `%DeepSee.UI.CubeRegistry`'s `RESOURCE`, which no shipped role but `%All` holds. Its writes add WRITE on the database `^DeepSee.Fact` maps to, and READ on the routines database (Story 20.34)."
- **AD-44:** "The Cube manager and its two tools declare `%DeepSee.UI.CubeRegistry` (Story 20.34)."
- **AD-10:** "`cube` is a covered type, `ReviewedFewOnly`; OcuPilot owns no cube (Story 20.34)."

**Strings (about 18 literals, add-only; values checked unique at Task 0, reusing a key whose value is identical).**

- **Labels:** "Cube manager"; actions "Build" and "Synchronize"; columns "Last update", "Synchronizes", "Updating" and "Dependent cubes". "Caption", "Facts" and "Last build" are reused from 20.11, and so is the Cubes empty sentence.
- **Afterwords:** "Rebuilt now", "Synchronized now".
- **Consequences:**
  - `analyticsCubeBuildConsequence` (`ANALYTICS.CUBE.BUILD`): "Building deletes this cube's facts and rebuilds them from its source, with every cube that depends on it. They cannot be queried until it ends, and a build that fails leaves their facts gone. The cube's own code and the namespace's analytics start-up code run as you."
  - `analyticsCubeSynchronizeConsequence` (`ANALYTICS.CUBE.SYNCHRONIZE`): "Synchronizing applies the source changes recorded since the last update to this cube and the cubes that depend on it. They stay queryable, and their other facts are unchanged. The cube's own code runs as you."
- **Refusals** (each `REASON*` equal to its value):
  - BUSY: "This cube, or a cube that depends on it, is being built or synchronized now. Try again when that ends."
  - NODSTIME: "This cube, or a cube that depends on it, has a source that does not record its changes (DSTIME), so it can only be built."
  - NOTBUILT: "This cube, or a cube that depends on it, has never been built, so there is nothing to synchronize. Build it first."
  - READONLY: "This namespace keeps its cubes' facts in a read-only database, so they cannot be built or synchronized here."
  - FAILED: "The instance answered this update with an error, so it may not have finished. The cube's Facts and Last update show what it holds now."
- **Output templates** (server only; EXPERIENCE.md and `analytics.test.mjs`, never `strings.ts`): "Facts in <cube>: <n>", "Build errors in <cube>: <n>", "Facts updated in <cube>: <n>".
- **Prompts:** "Which cubes can be synchronized rather than rebuilt?", "Which cubes depend on another cube?", "When was each cube last built or updated?"

**Named limits:**

- A build beyond the gateway's timeout (Q1 A).
- The vendor's single-build lock in a namespace whose agent count is limited has no timeout (`%BuildOneCube` :455). A build there waits for another build to end.
- In the race after the check:
  - a synchronize that meets a newly started build waits up to 30 s before 409 `ANALYTICS.CUBE.BUSY`;
  - a build that meets one leaves the vendor's failed `build` row, which moves Last build.
- The cascade is not atomic (measured): a dependent failing after the target leaves the target rebuilt and answers 409.
- Dependents the caller's resources hide are not updated, because the vendor filters them out (inference).
- A cube with a pending time-dimension upgrade is rebuilt by its synchronize (the vendor's escalation, `%SynchronizeCube` :2002-2025).
- A cube with versions builds its pending version (vendor).
- Build errors are a count. Their rows stay in the classic page.
- A failure's vendor text is logged, never shown.
- Updating is a moment's reading.
- Subject areas are not listed (as in 20.11).

**Integration, Consumes, Consumed-by (Rules 1 and 2).**

- **Integration:** AC7. 20.11's Cubes read and the agent's read tool consume this story's writes against the real instance.
- **Consumes:**
  - 20.11: `AnalyticsPort`, `AnalyticsError`, `AnalyticsProbe`, `AnalyticsGate`'s principals, `AnalyticsGateSeam`'s pattern, `cube`, and Cubes' Last build and Facts;
  - 20.33: the destination check and position 7; 20.32: positions 4 to 6;
  - 20.23: the action-write shape, `ReviewedFewOnly` and the audit helper's pattern;
  - the kernel's mint, confirm, screen action, hold, read-back and draft.
- **Consumed-by:**
  - 20.12, whose workflows may propose a synchronize (inference);
  - Epic 21's 21.8, whose cube registry editors may extend the Cube manager (inference).

**Ledger inbox (Rule 17):** none owned (`owned_ledger=0`). DW-2407 (`ToolWrite`'s count) is honored by the roster task.

**Rule 31 (extend, don't copy).**

- **Extended:**
  - 20.11's Cubes row builder (`CubeManager` and `STATE`);
  - 20.33's destination check, made one helper;
  - `AnalyticsGate`'s principal helper, made public;
  - `AnalyticsProbe`, with add-only methods;
  - `TestTheReadsWriteNothing`'s assertion, applied to the new reads.
- **Followed as siblings:** the tools follow `InteropJobAction`/`InteropJobStop`, the seam `InteropItemSeam`, and the browser spec `analytics.browser-spec.mjs`.
- **The copies:**
  - **`AnalyticsAction`'s `PortQuery`, `PrivilegePairs` and `ArgumentNamespace` follow `InteropAction`'s.** A slice never depends on another slice (Design Paradigm), and the pair shape differs: there is no own resource, but there is WRITE on the fact destination and READ on the routines database. A neutral parent would move the methods `InteropSettingDescriptor.TestTheSharedParentHoldsTheSixMethods` pins on `InteropAction` (DW-2268).
  - **`AnalyticsPort`'s private `AuditWrite` and capture helper** copy `InteropPort`'s per-port helpers, as 20.11 keeps each port's `Deny`, `Refuse` and `Conflict`.

**Rule 11 (contended files).**

- **Add-only:** `Kernel/Proposal/Prohibited.cls`, `Kernel/Governance/Baseline.cls`, `Test/ReadTool.cls`, `Test/SurfaceCoverage.cls`, `Test/StageTwoTools.cls`, `Test/ToolWrite.cls`, `Test/Descriptor.cls`, `screens.generated.ts` (regenerated), `strings.ts`, the side-bar specs and EXPERIENCE.md.
- **Unchanged:** `Kernel/EntityType.cls` (20.11's `cube`), `Screen/Registry.cls` and `Screen/Read.cls`: the port's `ENDPOINTS` drive validation and the mirror's parse (inference; Task 0 confirms).
- **Epic 23** (23.5 batch d, read at this plan) edits `Screen/Registry.cls`, `Test/ReadTool.cls`, `screens.generated.ts`, `screen-mirror.mjs` and its test, `_components.scss`, `data-table.ts`, `detail-page.ts` and EXPERIENCE.md. This story touches `ReadTool.cls`, `screens.generated.ts`, `screen-mirror.test.mjs`'s owners and EXPERIENCE.md, each add-only.
- **Footprint extensions (Rule 11 (b)):**
  - `Screen/Tool/AnalyticsAction.cls`, `AnalyticsCubeBuild.cls`, `AnalyticsCubeSynchronize.cls`;
  - `Kernel/Proposal/Prohibited.cls`, `Kernel/Governance/Baseline.cls`;
  - `shell/screen-action-handler.ts`, `core/screen-actions.ts`, `core/proposal-view.ts`;
  - `scripts/ci-throwaway.sh`.

**Size.** One story, the size of 20.23 (five actions on one port) or smaller: two actions, one list and one read. No split is recommended.

**Weight.** No page code and no lazy chunk. The initial bundle gains one mirror entry, about 18 strings and a few handler-map entries, about 4 kB (inference). From the measured 1.96 MB that gives about 1.965 MB, under the owner's fixed 2500 kB warning.

## Verification

**Shared surfaces:**

- `ReadTool`'s count and names; `ToolWrite`'s other-port count; `ToolRoundTrip`'s `REFUSEEMPTY`; `SurfaceCoverage`'s tool rows; `ToolEmit`'s family branches;
- the disabled-key lists in `GovernanceBaseline`, `Governance` and `ToolDispatch`; `ClassicPageGate`'s `OWNPAIRS`, `RUNTIMEKEYS` and count sentence; `MappingDescriptor`'s `CLASSICROSTER`; `Prohibited`'s covered types; `PortGate`'s `ROSTER`;
- `StageTwoTools`' `Elsewhere`, `Descriptor`'s `ReadShapes`, `Navigation.cls`' analytics block;
- `navigation.test.mjs`'s routes, `screen-mirror.test.mjs`'s owners;
- the client's global `DESTRUCTIVE_ACTIONS`, the strings table, and EXPERIENCE.md :157-173 and :604;
- the built-screen count Screen permissions derives (+1);
- `AnalyticsProbe` (the hidden cube, `ChangeVisits`), and USER's analytics flags while a probe runs.

*Every test added or changed passes on a fresh environment, in either order.* Each class creates and removes its probe, principals and locks, and the hidden cube exists only inside `AnalyticsCubeGate`.

**Setup (slot B; never the dev instance `ocupilot-slot-b`):**

- `(loop)` **Load `src`:**
  1. `rsync -a --checksum --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-20/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`
  2. In `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`, run `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)`.
- `(loop)` **Before any browser run:** `cd ui && npm run build && docker exec ocupilot-b-ci sh -c 'cd /durable/iris/csp/ocupilot && rm -rf ./*' && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`

**Commands.** Run each in the foreground with `timeout: 600000`, one at a time, and read each class's result from `%UnitTest_Result`. Size batches from `ui/tools/ci-timings.json` to about 8 minutes, splitting a batch that would exceed that.

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.AnalyticsCubeManager --class OcuPilot.Test.AnalyticsCubeActions --class OcuPilot.Test.AnalyticsCubeGate --class OcuPilot.Test.AnalyticsDescriptor --class OcuPilot.Test.AnalyticsPort --class OcuPilot.Test.PortGate`. Expected: green.
- `(loop)` The same runner with `Prohibited`, `GovernanceBaseline`, `Governance`, `ToolDispatch`, `ToolWrite`, `ReadTool`, `ToolRoundTrip`, `ToolEmit`, `SurfaceCoverage` and `StageTwoTools`. Expected: green.
- `(loop)` The same runner with `Descriptor`, `Navigation`, `ClassicPageGate`, `MappingDescriptor`, `DraftRegistry`, `SaveHoldCoverage`, `AnalyticsGate`, `DeveloperFloor` and `InteropFloor`, then every class the sweep changes. Expected: green.
- `(loop)` `cd ui && npm run test:tools`, then `cd ui && npm run test:components`. Expected: green.
- `(loop)` `cd ui && npm run build -- --verbose`. Expected: the prebuild chain is green, there is no new lazy chunk, and the initial total is under 2500 kB, about 1.965 MB (record it).
- `(loop)` `uv run scripts/check-objectscript.py <each changed .cls>` and `bash scripts/lint-docs.sh`. Expected: clean.
- `(loop)` After the redeploy, one file per call: `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/<file>`, for:
  - `analytics-cube-manager.browser-spec.mjs`;
  - `analytics.browser-spec.mjs`;
  - `namespace-categories.browser-spec.mjs`;
  - `a11y-structural-invariants.browser-spec.mjs` (about 430 s);
  - each side-bar spec the sweep changes.

  Expected: green.
- **Lead-owned (the runner's), not `(once)`:** the full ObjectScript sweep, `cd ui && npm test`, `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`, and Rule 30's fresh check.
- **Left to CI:** the full browser suite.

**Planned pinning mutations (Rule 19).** Revert each byte-identical, then reload or rebuild and redeploy before the next.

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | `VendorBuild` answers OK without calling the vendor | `AnalyticsCubeActions`' facts and Last build legs, and browser AC1 |
| AC1 | `AnalyticsCubeBuild.DESTRUCTIVE` 0 | `AnalyticsCubeActions`' card leg (`destructive`) |
| AC1 | `StateDiff` drops the Dependent cubes row | `AnalyticsCubeActions`' card leg |
| AC1 | The write skips `AuditWrite` | `AnalyticsCubeActions`' two `ConfigChange` legs |
| AC2 | `SYNCHRONIZE` calls `%BuildCube` | `AnalyticsCubeActions`' Synchronize leg (10 updated, Last build kept) and browser AC2 |
| AC3 | `STATE` skips the `DSTIME` check | `AnalyticsCubeManager`'s No DSTIME leg (409 FAILED and a new `CubeEvent` row), and browser AC3 |
| AC3 | `STATE` skips the never-built check | `AnalyticsCubeManager`'s Not built leg (facts become 1,000) |
| AC3 | The probe skips the `"SYNC"` node | `AnalyticsCubeManager`'s Busy leg on the `"SYNC"` node (a `CubeEvent` row appears) |
| AC3 | `Admit` skips the read-only check | `AnalyticsCubeManager`'s HSLIB leg |
| AC3 | `#20006` maps to FAILED | `AnalyticsCubeManager`'s seam leg |
| AC4 | `MANAGERPAIRS` loses `%DeepSee_Admin:USE` | `AnalyticsCubeGate`'s P1 leg, and `PortGate`'s denial leg |
| AC4 | The write gate checks READ, not WRITE | `AnalyticsCubeGate`'s P4 leg |
| AC4 | `STATE` skips `%CheckPrivilege` | `AnalyticsCubeGate`'s Hidden leg |
| AC5 | The baseline line for Build reads `true` | `GovernanceBaseline`'s `DISABLED` test and `AnalyticsCubeActions`' key-off leg |
| AC6 | The `Elsewhere` row is removed | `StageTwoTools.TestTheRosterAndElsewhereAreEveryRegisteredScreen`, alone |
| AC6 | A pale color in a list cell | The browser AC6 structural test |
| AC7 | `VendorBuild` answers OK without calling the vendor | `AnalyticsCubeGate`'s Cubes-read clause (Last build and Facts unchanged) |
| AC7 | The read tool's view drops `LastBuild` | `AnalyticsCubeGate`'s read-tool clause |
| AC8 | `Remove` skips the hidden cube | `AnalyticsProbe.Gone()` in `AnalyticsCubeGate`'s `OnAfterAllTests` |

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Planned as one story over 20.11, 20.32, 20.33 and 20.35, which land first (Task 0 re-anchors them). Gate questions Q1 (a build longer than a request, AD-7), Q2 (the audit record) and Q3 (the user code a build runs) are for the orchestrator at the spec gate, each with a recommendation; none blocks under it. The Rule 20 drafts are in Design Notes.
