---
title: 'Story 19.12: A %Development holder reaches System Explorer, as the classic portal allows'
type: 'feature'
created: '2026-10-01'
status: 'done'
baseline_revision: '315f73a347dd8e2c7da0d64775480c10b7cbdcd4'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-19-context.md'
warnings: ['oversized']
deferred:
  - summary: 'The interoperability event log (LogEventViewer, LogSourcePort EVENTLOGPAIRS) lacks %Ens_Portal:USE, which the classic EnsPortal.EventLog requires'
    evidence: 'irislib/EnsPortal/Template/standardPage.cls:441-448 calls EnsPortal.Application.CheckPrivileges, which requires %Ens_Portal:USE (irislib/EnsPortal/Application.cls:234-248); LogSourcePort.cls:239 declares %Ens_EventLog:USE alone. A holder of %Ens_EventLog without %Ens_Portal opens it here and is refused there. It does not rely on the floor (the %Developer principal holds neither), so it is outside this story.'
    location: 'src/OcuPilot/Screen/Descriptor/LogEventViewer.cls'
    severity: 'med'
  - summary: >-
      System Explorer's Routines list shows routines its viewer answers PORT.NOTFOUND for
    evidence: |-
      On ocupilot-a2-ci as _SYSTEM, GET /screens/explorer.routines/read lists EnsJob.mac (Database HSCUSTOM), and GET /screens/explorer.routine/read?name=EnsJob.mac answers 404 PORT.NOTFOUND; USER's listed Ens*.mac routines do the same. Story 19.1's surface, observed while choosing this story's fixture documents.
    location: >-
      src/OcuPilot/Port/AtelierPort.cls
    severity: medium
---

<intent-contract>

## Intent

**Problem:** The API refuses every caller who holds no `%Admin_*` resource. So a `%Developer` account, which the classic portal admits to System Explorer, cannot open OcuPilot at all (DW-1903).

**Approach:** Widen the floor to any `ADMINRESOURCES` member or `%Development:USE`. `Screen/Gate.cls` holds it, and the router, `ProviderPort` and the turn's step check all derive from it. Then prove, over every descriptor, tool and route, that a real `%Developer` principal opens exactly what the classic portal opens to it, plus its own data.

## Boundaries & Constraints

**Always:**

- **One home.** `Screen.Gate` keeps `ADMINRESOURCES` as it is: thirteen `%Admin_*` resources.
  - It adds `DEVELOPMENTRESOURCE` (`%Development`), `FloorResources()` (the admin list plus that resource) and `FloorPairSpec()` (each member at `USE`).
  - These are derived from it at compile time, never copied:
    - `Router.FLOORRESOURCES`, which `HoldsAdminResource` tests;
    - `ProviderPort.INVOKEPAIRS`;
    - the turn's `resources` in `Api/Turn.cls`.
- **Every other gate is unchanged.** Each keeps its own pairs, evaluated at call time in the caller's process (AD-8, AD-29). No screen, tool or route gains or loses a pair.
- **"D" is the test principal, and it is real.** D holds role `%Developer` plus READ on the install namespace's code database, and nothing else.
  - That READ is every caller's documented prerequisite. Without it, `%CSP.REST.AccessCheck` answers a bare 403.
  - D is created only on `ocupilot-a2-ci`, armed by `OCUPILOT_ALLOW_PRINCIPALS`, and removed afterwards.
- **Classic resources are read, never recalled.** Every classic `RESOURCE` a test or comment cites comes from the instance (`%Dictionary.CompiledParameter`) or from `irissys/` and `irislib/`.

**Never:**

- No new error code, route, descriptor, tool or governance key. `AUTH.NOADMIN` keeps its code.
- Never put `%Development` into `ADMINRESOURCES`. `ToolWrite`'s USE rule and the list's closed `%Admin_*` meaning depend on it staying out.
- Never elevate to read the dashboard for a caller who lacks `%DB_IRISSYS` (AD-8, AD-9).
- Never insert a line into EXPERIENCE.md. Edit in place only.
- Never use `%Operator` to prove a denial. Never touch `ocupilot-ci`.

## I/O & Edge-Case Matrix

D is the principal described above.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Sign-in (DW-1903) | `GET /navigation` as D | 200. Exactly four areas are allowed: home, logs, system-explorer and agent. Exactly the ten screens in Design Notes › Audit are allowed. Every other area and screen reads `allowed:false` with its `failedPair` | none |
| System Explorer | The four `explorer.*` reads as D, in HSCUSTOM and with `?ns=USER` | 200 with rows. In USER the rows come through `%Developer`'s `%DB_USER` | none |
| Administrative screen | `GET /screens/webapp.list/read` as D | 403 `AUTH.NOPRIVILEGE`, `failedPair` `%Admin_Secure:USE` | none |
| Logs (DW-1853) | D opens Logs | Logs opens on Analytics alone. Analytics reads 200. The `logs.messages` read is 403, naming `%Admin_Operate:USE` | none |
| Below the floor | A principal holding only code-database READ | 403 `AUTH.NOADMIN` on every route. The reason names `%Admin_` and `%Development` | none |
| Route sweep | Every `UrlMap` route as D, with placeholders that reach each route's gate | 403 for every route outside the 29-route roster (Design Notes › Audit). The roster's GET routes answer neither 403 nor 5xx | no 5xx |
| Turn (Integration) | A principal holding `TurnWireFixture.Resources(0)` plus `%Development:U`, and no `%Admin_*`, runs a turnprobe turn that calls `explorer.classes.read` and then `webapp.list.read` | The first step answers rows. The second is refused `AUTH.NOPRIVILEGE`, naming `%Admin_Secure:USE`. The turn completes and is never `TURN.ABANDONED.PRIVILEGE` | none |
| Home system information | `GET /ui/system` as D | 200. The five dashboard members are `""`; mirror and production answer. No `uisystem` line reaches `messages.log` | none |

</intent-contract>

## Code Map

### Where the floor is held and used

- `src/OcuPilot/Screen/Gate.cls`:
  - `ADMINRESOURCES` :43, and its doc :31-42;
  - `ADMINPERMISSION` :46;
  - `AdminPairSpec` :295, the shape `FloorPairSpec` copies.
- `src/OcuPilot/Api/Router.cls`:
  - `ADMINRESOURCES` :47, derived (`DependsOn` Gate :19);
  - `HoldsAdminResource` :1175, with its doc :1168-1174;
  - the `OnPreDispatch` doc :1253-1256, and the refusal :1354-1357.
- `src/OcuPilot/Port/ProviderPort.cls`: `INVOKEPAIRS` :67, doc :60-66; the any-of gate :104-111.
- `src/OcuPilot/Api/Turn.cls` :148: `tValues("resources")`, read by `Kernel/Agent/Loop.cls` `Boundary` :358 and `HoldsAnyResource` :388 at every step (AD-31).
- `src/OcuPilot/Api/Error.cls` :92-106: the `AUTHNOADMIN` and `AUTHNOPRIVILEGE` docs, which say "`%Admin_*`" and "holds an administrative resource".
- `src/OcuPilot/Kernel/Shell/SystemInfo.cls` `Dashboard` :103-117. It switches to `%SYS` and logs any failure through `FieldRead.LogSourceFailure` (`Kernel/Shell/FieldRead.cls` :71) at error severity.

### What tests build on

- `src/OcuPilot/Kernel/Shell/Navigation.cls` `Payload` :20 / `SetVerdict` :64. It reports every built screen's and area's `allowed` and `failedPair`, through `Gate.Evaluate` in the caller's process.
- `src/OcuPilot/Screen/Tool/Registry.cls`: `ListTools` :106 and `RequiredPairs` :423.
- `src/OcuPilot/Kernel/Shell/Effective.cls`: `Read` :236, `Compose` :63 and `Holds` :194. This is the one effective-privilege composition (AD-8). It counts public grants.
- **Fixture precedents:**
  - `src/OcuPilot/Test/ConfigGate.cls`: `Routes` :219 (the compiled `UrlMap`), the sweep :390. `ConcretePath` :262 is an instance method, so copy its shape.
  - `src/OcuPilot/Test/TurnWireFixture.cls`: `Resources(0)` :55, `EnsurePrincipal` :77 (second-role resources), `Call` :354, `StartConversation` :374, `AwaitEnd` :384.
  - `src/OcuPilot/Test/TurnProvider.cls` `ToolUseReply` :169 takes an array of `{name, input}`.
  - `src/OcuPilot/Test/AtelierPortDenial.cls` :107-116 and :164: real-principal setup that reads back grants.
  - `ui/browser/panel-principal.browser-spec.mjs` :38-77: makes a principal through `docker exec … -U %SYS`, then signs in.
- **Floor pins this story moves:**
  - `src/OcuPilot/Test/PortGate.cls` :242 `TestTheAdministrativeFloorHasOneHome`;
  - `src/OcuPilot/Test/Wire.cls` :811 `TestEveryAdminResourceNamedExistsOnTheInstance`, with its prose at :326 and :800-810.

  `ConfigGate`'s sweep asserts `reason [ "%Admin_"`, so the new reason keeps that text.
- `scripts/ci-throwaway.sh`: the `OCUPILOT_ALLOW_PRINCIPALS` `# classes:` lines :223-286 and `OCUPILOT_ALLOW_TEST_PROVIDER` :401. `ui/tools/ci.test.mjs` :2096-2177 derives the roster from each class's arming parameter.
- **Documents stating the old floor:**
  - EXPERIENCE.md :79, :224, :714 and :787 ("no `%Admin_*`");
  - `docs/DEVELOPMENT.md` :346-347;
  - `ui/src/app/core/instance.ts` :16-18 (doc).

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Screen/Gate.cls`: add `DEVELOPMENTRESOURCE`, `FloorResources()` and `FloorPairSpec()`. State the floor once in `ADMINRESOURCES`' doc.
- `src/OcuPilot/Api/Router.cls`:
  - add `FLOORRESOURCES As %String = {##class(OcuPilot.Screen.Gate).FloorResources()}`;
  - `HoldsAdminResource` iterates it;
  - the refusal reason becomes "This account holds neither an InterSystems IRIS administrative privilege nor %Development; OcuPilot requires USE on at least one %Admin_ resource or on %Development";
  - fix the two docs.
- `src/OcuPilot/Port/ProviderPort.cls`: set `INVOKEPAIRS` to `{##class(OcuPilot.Screen.Gate).FloorPairSpec()}` and fix its doc.
- `src/OcuPilot/Api/Turn.cls` :148: change it to `##class(OcuPilot.Api.Router).#FLOORRESOURCES`.
- `src/OcuPilot/Kernel/Shell/SystemInfo.cls` `Dashboard`: when `$System.Security.Check("%DB_IRISSYS","READ")` is false, return the members empty with no switch and no log line. Keep the restore-first `Catch`.
- `src/OcuPilot/Api/Error.cls`: correct the two doc sentences in place.
- `src/OcuPilot/Test/PortGate.cls` :242:
  - assert `Router.FLOORRESOURCES = Gate.FloorResources()`, `INVOKEPAIRS = Gate.FloorPairSpec()`, and `FloorResources() = ADMINRESOURCES _ ",%Development"`;
  - keep `Router.ADMINRESOURCES = Gate.ADMINRESOURCES`.
- `src/OcuPilot/Test/Wire.cls` :811: iterate `Router.FLOORRESOURCES`, and correct the prose at :326 and :803 in place.
- `src/OcuPilot/Test/DeveloperFloorFixture.cls`, new:
  - `EnsurePrincipal`: makes D, or with an argument `"neither"`, the code-database-only principal;
  - `RemovePrincipals`;
  - `Call`: HTTP as a principal;
  - grant read-back through `Effective`. Setup asserts that a public pair (`%DeepSee_Portal:USE`) and `%Development:USE` read held.
- `src/OcuPilot/Test/DeveloperFloor.cls`, new, at most about 500 lines. It covers the matrix's sign-in, System Explorer, administrative screen, Logs, below-the-floor (one route and the reason; `ConfigGate`'s sweep already covers every route) and Home rows. Plus two derived legs:
  - **Classic parity.** Every screen `/navigation` allows D must be in the declared ten. Each one with a `classicPage` must have that page's compiled `RESOURCE` empty or holding a member D holds at USE.
  - **Tools.** Every tool `ListTools` returns: its `RequiredPairs` held by D through `Effective` must be exactly the declared ten tools, and no tool classified `write` may be among them.
- `src/OcuPilot/Test/DeveloperFloorRoutes.cls`, new: the route sweep row.
  - Placeholders: `:screen` is `webapp.list`, `:kind` is `global`, and other ids are absent ones.
  - Non-GET roster routes are not called.
- `src/OcuPilot/Test/DeveloperFloorTurn.cls`, new: the Turn row. It arms both variables and gives `TurnWireFixture`'s principal `Resources(0)` plus a second role holding `%Development:U`.
- `scripts/ci-throwaway.sh`: add `# classes:` lines for the four new classes (`OCUPILOT_ALLOW_PRINCIPALS`) and for `DeveloperFloorTurn` (`OCUPILOT_ALLOW_TEST_PROVIDER`). Edit `ui/tools/ci.test.mjs` only if it reddens.
- `ui/browser/developer-floor.browser-spec.mjs`, new. D signs in, sees no no-privileges notice, opens System Explorer › Classes with rows, and finds Permissions unavailable, naming its pair. It removes D in `after`.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` :79, :224, :714 and :787: in place, "no `%Admin_*`" → "no `%Admin_*` and no `%Development`". Also `docs/DEVELOPMENT.md` :346-347, and the doc at `ui/src/app/core/instance.ts` :16-18.

**Acceptance Criteria:**

- **AC1 (the story's first criterion).** Given D, when it signs in, then it passes the floor and System Explorer's lists and viewers read as they do for a classic `%Developer`. The floor's one home is `Screen/Gate.cls`, and the router, the provider port and the turn's step check derive from it.
- **AC2 (second criterion, DW-1853).** Given D, when every descriptor, tool and route is evaluated, then D opens exactly the declared rosters, and nothing else. Each roster member either answers only D's own data, or declares a pair set its classic page's `RESOURCE` admits, or replaces a page with none. Everything else is refused, naming a failed pair.
- **AC3 (third criterion, Integration).** Given a principal holding `%Development` and no `%Admin_*`, when its turn calls a tool it holds and one it lacks, then the first answers and the second is refused by name. The turn neither abandons nor is refused at the provider port.
- **AC4 (fourth criterion).** Given `FloorResources()` returning `ADMINRESOURCES` alone (the old floor), when `DeveloperFloor`, `DeveloperFloorTurn` and the browser spec run, then each reddens.
- **AC5.** Given D on Home, when System information loads, then it shows "not reported" for the dashboard members and writes nothing to `messages.log`.

## Spec Change Log

- 2026-10-02, spec gate (lead): DW-1853 resolved by parity accepted (the screen already declares its classic page's `RESOURCE` member); the non-additive edits approved, none contended at gate time, re-checked at edit time; the AD-8 sentence, AD-61 rule 1's wording and PRD FR-3/FR-65 are amended by the lead when the story ships.

## Review Triage Log

### 2026-10-01 — Review pass

- verdicts: 16 findings — high 0, medium 4, low 10, false 2, maybe-false 0
- findings:
  - `[medium]` `[patch]` `Dashboard`'s `%DB_IRISSYS` guard is pinned on its admitted side only by `%All` callers, which pass a misspelled name — the fixture gains an administrator (code READ plus `%DB_IRISSYS:R`, `%Admin_Operate:U`, no `%All`) and `DeveloperFloor.TestHomeSystemInformationAnswersAnAdministratorWithoutAll` asserts the members answer (mutation run 486).
  - `[low]` `[reject]` `DeveloperFloorRoutes` sends none of the 12 non-GET roster routes — the intent's route-sweep row scopes the open check to GET; those calls write D's own restraint, context, preferences and password rows, which outlive D; `POST /conversation` and `POST /turn` run in `DeveloperFloorTurn`.
  - `[medium]` `[patch]` The route sweep never checks that a refused route names its failed pair (AC2) — the refused branch asserts `AUTH.NOPRIVILEGE` and `detail.failedPair`; all 114 refused routes meet it (run 484; mutation run 488).
  - `[low]` `[patch]` Two browser assertions cannot fail (the notice after the rail wait; an absent explorer item reads as available) — waits for the frame or a settled notice message, asserts no message, asserts the item exists; the AC4 mutation now reddens at the notice assertion.
  - `[low]` `[reject]` Reverse parity: `LogTaskErrorViewer` refuses D while `%CSP.UI.Portal.BackgroundTaskError` compiles `RESOURCE` `""` — probed as D on `ocupilot-a2-ci`: the page loads only by direct URL and errors (`<SUBSCRIPT>` in `ErrorLogFetch`) without a task id, and its parent list under `/csp/sys/op` refuses D; the fix drops a pair, which the intent forbids.
  - `[medium]` `[patch]` The parity leg reads `%CSP.UI.System.ViewCode`'s missing `RESOURCE` row as empty, so `ExplorerRoutineDocument` passed unchecked — `ClassicResource` tells a missing row apart and `INTERNALCHECKS` records ViewCode's `OnPreHTTP` `%Development` check (irislib `%CSP/UI/System/ViewCode.cls`:15-17); mutation run 487.
  - `[low]` `[reject]` "Plus its own data" is not tested as D — owner scoping is identity-based and pinned for non-`%All` principals by `TranscriptGate`, `TranscriptsWire` and `LedgerWire`.
  - `[low]` `[reject]` Tools are never invoked by D — the Tasks specify the held set through `Effective`; AC3 invokes a tool as a `%Development` principal in a real turn.
  - `[low]` `[reject]` Logs is not opened in the UI — landing on an area's first open screen is principal-independent and pinned by `ui/tools/navigation.test.mjs` and `area-verdict.spec.ts`; `DeveloperFloor` pins D's map.
  - `[low]` `[reject]` Home is checked at the API only — the intent's Home row is the API call; `""` rendering as "Not reported" is pinned by `home.page.spec.ts` and `home-system-information.browser-spec.mjs`.
  - `[false]` `[reject]` Below the floor is split across two classes — the reason is one constant in `Router.OnPreDispatch`, and `ConfigGate` sweeps every route with a code-READ-only principal; the row is met.
  - `[medium]` `[patch]` The route sweep checks status only — same root cause and fix as the third row.
  - `[low]` `[reject]` Turn harnesses still pass `Router.#ADMINRESOURCES` to `Loop.Run` — their principals hold `%All`, so the list cannot change their outcome; the product value is pinned over HTTP by `DeveloperFloorTurn`, and `TurnWire.cls` is being edited by Epic 23.
  - `[low]` `[patch]` Doc comments outside the diff still state the old floor — corrected in place: `ConfigGate.cls` :9 and :384, `ProhibitedRoute.cls` :96, `LogSourceDenial.cls` :237, `navigation.ts` :19, `instance-notice.ts` :26; the spine, PRD and DW-1853 note are the lead's at ship.
  - `[low]` `[reject]` D is created on every armed throwaway, not only `ocupilot-a2-ci` — the `ci-throwaway.sh` lines the Tasks require arm exactly that; the variable confines it to throwaways and each class removes its principals.
  - `[false]` `[reject]` `## Auto Run Result` still reads `ready-for-dev` — finalize rewrites that section.

## Design Notes

**Governing ADs:** AD-8 (the floor paragraph at spine :199), AD-29, AD-44, AD-5, AD-21 (unauthenticated floor: the API application carries no role, so D needs the code-database READ like any caller), AD-31, AD-61, AD-9, AD-16, AD-39.

**How the provider port's floor changes.** `INVOKEPAIRS` becomes the floor's pair spec: any `%Admin_*` resource or `%Development`, each at `USE`, still an any-of set. The provider is called for D's turn, and every tool call in it is still gated by that tool's own pairs. `%Development` sorts last, so `ProviderPortOwner`'s first-pair read is unchanged.

**Audit (derived, 2026-10-01).** Every source was read on `ocupilot-a2-ci` or in `irissys/`/`irislib/`.

Grants:

- Stock public grants: `%DB_ENSLIB/HSLIB/IRISLIB/IRISLOCALDATA:R`, `%DB_IRISTEMP:RW`, `%DeepSee_Portal:U`, `%IAM:U` and seven `%Service_*:U`.
- `%Developer` grants `%Development:U` and `%DB_USER:RW`, plus `%DB_%DEFAULT`, `%DocDB_Admin`, `%Native_*`, `%Service_*` and `%System_CallOut`. It does not grant `%DB_HSCUSTOM`, `%DB_IRISSYS`, any `%Admin_*`, `%Ens_*` or `OcuPilotAdmin`.
- `AtelierPort.NamespacePairs`:
  - HSCUSTOM: `%DB_HSCUSTOM`, `%DB_ENSLIB`, `%DB_HSLIB` and `%DB_IRISLIB`, all READ;
  - USER: `%DB_USER`, `%DB_ENSLIB` and `%DB_IRISLIB`, all READ.

What D opens:

| Surface | Count | What D opens | Why it matches the classic portal |
|---|---|---|---|
| Descriptors | 97 | Home | `%CSP.Portal.Home` `RESOURCE` is `""` |
| | | `AgentGuardrails`, `AgentLedger`, `AgentTranscripts`, `AgentTranscript` | No classic page. They show OcuPilot's own declarations, or D's own rows (owner-scoped; others need `OcuPilotAdmin`) |
| | | `ExplorerClassList` and `ExplorerClassDocument` | `%Development:USE` = `ClassList` |
| | | `ExplorerRoutineList` | `%Development:USE` = `RoutineList` |
| | | `ExplorerRoutineDocument` | `%Development:USE` = `ViewCode`'s own check |
| | | `LogAnalyticsViewer` | `%DeepSee_Portal:USE`, one member of `%DeepSee.UI.LogViewer`'s `%DeepSee_Portal,%DeepSee_PortalEdit` |
| Tools | 196 | `agent.transcripts.read`, `shell.instance.read`, `shell.namespaces.read`, `shell.privileges.read` | Own or caller-scoped data, or the instance identity every classic page header shows |
| | | `shell.screen.open` | Takes the target screen's pairs |
| | | The four `explorer.*.read` tools and `logs.analytics.read` | As their screens. No write tool is among the ten |
| Routes | 143 | 29 open, 114 refused. GET open: `/agent/definitions`, `/agent/restraint`, `/agent/context`, `/agent/ledger`, `/turn/:id/progress`, `/conversation/:id`, `/transcripts/:id`, `/instance`, `/namespaces`, `/navigation`, `/account/preferences`, `/ui/about`, `/ui/help`, `/ui/system`, `/ui/findings`, `/ui/guardrails`, `/logs/analytics`. Non-GET open: `PUT /agent/restraint`, `PUT /agent/context`, `POST /turn`, `POST /turn/:id/stop`, `/turn/:id/navigation`, `/turn/abandon`, `/proposal/:id/confirm`, `/cancel` and `/draft`, `POST /conversation`, `/account/password`, `POST /account/preferences` | Owner-scoped, or an empty classic `RESOURCE` (`%CSP.UI.Portal.About` reads `""`). `/agent/definitions` lists what the panel's picker needs, with no credentials or endpoints |

- **No existing surface needs a new pair.** Every floor-only surface already matches its classic page or has none. The work is the floor plus the tests that hold these rosters, so a later surface cannot join them silently.
- **DW-1853 resolves by parity, not by a new pair.** The classic analytics log page admits every caller, because `%DeepSee_Portal:U` is public. Adding a pair here would refuse what the classic portal allows (AD-8). Logs opens on that screen alone, which is AD-8's area rule (DW-1768).
- **Measured during planning on `ocupilot-a2-ci`.** A probe holding `%Developer`, `%DB_HSCUSTOM:R` and `%Admin_Task:U` was created and then removed.
  - `/ui/system` wrote one severity-2 `uisystem` line (`<PROTECT>` at the `%SYS` switch). That is Home's common path for every `%Developer` after the widening, hence the `SystemInfo` task.
  - `/ui/about` wrote nothing.
  - `explorer.classes` read 200.

**Ledger inbox.** DW-1903 is addressed by AC1 and the sign-in row. DW-1853 is addressed by AC2 and the Logs row.

**Integration ACs.**

- **Consumes:** `Screen.Gate`, `Kernel.Shell.Effective`, `Screen.Tool.Registry`, `TurnWireFixture` and `TurnProvider`.
- **Consumed-by:** Stories 19.2 to 19.11. Their screens and tools declare `%Development`-class pairs from the start and join these rosters.

**Proposed amendments, for the lead's spec gate:**

- AD-8: replace "Until Story 19.12 ships, the floor is the `%Admin_*` list alone." with the audit's outcome above, and name the turn's step check as the floor's third consumer.
- AD-61 rule 1: "which Story 19.12 widens" becomes "widened by Story 19.12".
- PRD FR-3 (:239) and FR-65 (:912) still state `%Admin_*` only.
- The EXPERIENCE.md edits above are a tier-1 change made in place.

**Footprint (Rule 11).** Neither `.worktrees/epic-18` nor `.worktrees/epic-23` touches any of these files (diff and status checked 2026-10-01). Re-check at edit time.

- **Add-only:** the `Gate.cls` additions, the four new classes, the browser spec, and the `ci-throwaway.sh` lines.
- **Non-additive edits to shared files, which need the lead's approval:**
  - `Router.cls`: the loop source, the reason and docs;
  - `Error.cls`: two doc sentences;
  - `ProviderPort.cls` :67;
  - `Turn.cls` :148;
  - `SystemInfo.cls` `Dashboard`;
  - `PortGate.cls` and `Wire.cls`: one method each;
  - the four EXPERIENCE.md rows;
  - `DEVELOPMENT.md` and `instance.ts` (docs).
- **If the story must split:**
  - (a) the floor, `PortGate`, `Wire`, `DeveloperFloor` and the browser spec;
  - (b) `DeveloperFloorRoutes` and `DeveloperFloorTurn`.

## Verification

Load the source into `ocupilot-a2-ci` without the MCP tools, and never restart that container. Sync with `rsync -a --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-19/src/ /tmp/ocupilot-a2-ci/src/`, then run `$System.OBJ.LoadDir("/opt/ocupilot/src","ck",.tErrors,1)` in `docker exec -i ocupilot-a2-ci iris session iris -U HSCUSTOM`, checking both the status and `tErrors`.

**One test-runner call at a time, ever.** Run one class or one spec file per call, wait for it, and never re-submit after a client-side timeout.

**Commands:**

- `uv run scripts/check-objectscript.py && uv run scripts/test_check_objectscript.py` (loop): expected green.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-a2-ci --class <Class>` (loop), one class per call, for: `OcuPilot.Test.DeveloperFloor`, `DeveloperFloorRoutes`, `DeveloperFloorTurn`, `PortGate`, `Wire`, `ConfigGate`, `TurnWire`, `ProviderPortOwner` and `WireAreaAnyScreen`. Expected green. Planned mutations:
  - AC1/AC4: `FloorResources()` answers `ADMINRESOURCES` alone → `DeveloperFloor`, `DeveloperFloorTurn` and the browser spec redden;
  - AC2: `WebAppList` privileges `[]` → `DeveloperFloor`'s parity leg reddens; `LogMessageViewer` privileges `%DeepSee_Portal:USE` → the parity leg reddens; delete `Gate()` from `Area/WebApp/FormRules` → `DeveloperFloorRoutes` reddens;
  - AC3: `Turn.cls` :148 back to `ADMINRESOURCES` → `DeveloperFloorTurn` reddens (abandoned); `INVOKEPAIRS` back to `AdminPairSpec()` → it reddens (provider refused);
  - AC5: remove the `%DB_IRISSYS` guard → `DeveloperFloor`'s Home leg reddens;
  - one-home: a literal `Router.FLOORRESOURCES` → `PortGate` reddens.
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-a2-ci:/durable/iris/csp/ocupilot/` (loop, before each browser run), then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52780 OCUPILOT_BROWSER_CONTAINER=ocupilot-a2-ci node --test --test-concurrency=1 browser/developer-floor.browser-spec.mjs`. Expected green. The full browser suite is CI's three shards, not a local step.
- `bash scripts/lint-docs.sh && cd ui && npm run test:tools` (loop, after the EXPERIENCE.md edit): expected green.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-a2-ci`, the full ObjectScript sweep, one class at a time (once, before dev_complete). Expected green apart from residue named in 19.1's run (DW-1425/DW-1468, DW-1759).

Record one `mutation: <change> → <test that reddened>` line per AC here as each is observed (Rule 19).

- mutation: AC1/AC4, `Gate.FloorResources()` answers `ADMINRESOURCES` alone (Router, ProviderPort, Turn recompiled) → `DeveloperFloor` red, 6 of 8 (run 459); `DeveloperFloorTurn` red, start refused `AUTH.NOADMIN` (run 460); `developer-floor.browser-spec.mjs` red at "the frame, not the no-privileges notice" (the notice renders "no administrative privileges on this instance").
- mutation: AC2, `WebAppList` privileges `[]` → `DeveloperFloor` red: parity leg (opens outside the roster, `%Admin_Secure` unheld), sign-in, administrative-screen and tools legs (run 461).
- mutation: AC2, `LogMessageViewer` privileges `%DeepSee_Portal:USE` → `DeveloperFloor` red: parity, tools (`logs.messages.read` joins the held set), Logs and sign-in legs (run 462).
- mutation: AC2, `Gate()` deleted from `Area/WebApp/FormRules.HandleForm` → `DeveloperFloorRoutes` red on `GET /web-applications/form` (run 467).
- mutation: AC3, `Turn.cls` :148 back to `Router.#ADMINRESOURCES` → `DeveloperFloorTurn` red, turn not completed (run 464).
- mutation: AC3, `INVOKEPAIRS` back to `Gate.AdminPairSpec()` → `DeveloperFloorTurn` red, turn not completed (run 465).
- mutation: AC5, `%DB_IRISSYS` guard removed from `SystemInfo.Dashboard` → `DeveloperFloor.TestHomeSystemInformationLogsNothingForTheDeveloper` red alone (run 463).
- mutation: one home, `Router.FLOORRESOURCES` a literal → `PortGate.TestTheAdministrativeFloorHasOneHome` red (run 466).
- mutation: AC5 admitted side, the `Dashboard` guard checks a misspelled `%DB_IRISYS` → `DeveloperFloor.TestHomeSystemInformationAnswersAnAdministratorWithoutAll` red alone (run 486).
- mutation: AC2 parity, `DeveloperFloor.INTERNALCHECKS` emptied → `TestEveryOpenScreenMatchesItsClassicPage` red on `ExplorerRoutineDocument` (`%CSP.UI.System.ViewCode` compiles no `RESOURCE`) (run 487).
- mutation: AC2 routes, `Kernel.Denial.Detail` answers `""` for every pair → `DeveloperFloorRoutes` red, 113 refused routes naming no pair (run 488).

## Auto Run Result

Status: done
Blocking condition: none

**Change.** The floor is any `%Admin_*` resource or `%Development` at USE, held once in `Screen/Gate.cls` (`DEVELOPMENTRESOURCE`, `FloorResources()`, `FloorPairSpec()`) and derived at compile time by `Router.FLOORRESOURCES`, `ProviderPort.INVOKEPAIRS` and the turn's `resources`. `SystemInfo.Dashboard` answers the five members empty, with no switch or log line, for a caller without `%DB_IRISSYS:READ`. Four new test classes and one browser spec pin the rosters.

**Files.**

- `Screen/Gate.cls`, `Api/Router.cls`, `Port/ProviderPort.cls`, `Api/Turn.cls`: the floor and its three consumers.
- `Kernel/Shell/SystemInfo.cls`: the `%DB_IRISSYS` guard. `Api/Error.cls`: two doc sentences.
- `Test/DeveloperFloorFixture.cls`, `DeveloperFloor.cls`, `DeveloperFloorRoutes.cls`, `DeveloperFloorTurn.cls`, `ui/browser/developer-floor.browser-spec.mjs`: new.
- `Test/PortGate.cls`, `Test/Wire.cls`: floor pins moved. `scripts/ci-throwaway.sh`: roster lines.
- EXPERIENCE.md (four rows in place), `docs/DEVELOPMENT.md`, `ui/src/app/core/instance.ts`: docs.
- Footprint extensions, doc comments only: `Test/ConfigGate.cls`, `Test/ProhibitedRoute.cls`, `Test/LogSourceDenial.cls`, `ui/src/app/core/navigation.ts`, `ui/src/app/shell/instance-notice.ts`.

**Review.** 16 findings. Patched: 3 medium entries (the dashboard guard's admitted side, refused routes naming their pair, the ViewCode parity pass) and 2 low. Rejected: 9 low and 2 false, each with its reason in the triage log. Deferred: one new item (the Routines list shows routines its viewer cannot open). Follow-up review: `false`. The count rule reads `true` (three medium patched), but no unverified risk can be named: each patch has an observed mutation and the full sweep ran after it.

**Verification (`ocupilot-a2-ci`).**

- Loop: check-objectscript and its harness, lint-docs and `npm run test:tools` (1766) all green.
- Classes: DeveloperFloor (9, run 491), DeveloperFloorRoutes (490), DeveloperFloorTurn (477), PortGate (478), Wire (479), ConfigGate (480), TurnWire (481), ProviderPortOwner (482), WireAreaAnyScreen (483).
- The browser spec is green after rebuilding and redeploying.
- Full ObjectScript sweep, once, after the patches: 400 classes, 3294 tests, 0 failed, 0 overlaps.
- Bundle 2.42 MB, no budget warning.

**Residual.**

- Three test-runner calls once went out in one message (runs 473 to 475). Their fixtures do not overlap, all were green, and each was re-run alone (476 to 478).
- The handoff's AC5 mutation left one severity-2 `uisystem` line in this throwaway's `messages.log`. The sweep was green regardless.
- The lead's ship amendments are pending: AD-8, AD-61 rule 1, PRD FR-3 and FR-65, and DW-1853's ledger note.
