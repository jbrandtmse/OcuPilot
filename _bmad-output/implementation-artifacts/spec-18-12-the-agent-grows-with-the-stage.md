---
title: 'Story 18.12: The agent grows with the stage'
type: 'feature'
created: '2026-10-11'
status: 'done'
baseline_revision: 'ea3b7abe6aa36292b55a7704184d7625d6639996'
baseline_commit: 'ea3b7abe6aa36292b55a7704184d7625d6639996'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred:
  - summary: >-
      StageTwoTools reads only its declared roster, so a Stage 2 screen or write tool added later is never visited unless its author adds a row.
    evidence: |-
      Both loops walk the roster or the registry through the roster filter; nothing compares the roster to the registered descriptors. A reverse check needs a Stage 2 marker on descriptors or a baseline of the earlier screens, neither of which exists, and Descriptor/Base is Epic 20 contended.
    location: >-
      src/OcuPilot/Test/StageTwoTools.cls Roster
    severity: medium
  - summary: >-
      The roles read lists "Every caller" first while the vendor stores it last, so an update that echoes MatchRoles as read reports it changed, in order alone.
    evidence: |-
      Probed on ocupilot-ci: Security.PrivilegedRoutine GET answers named roles ascending then the empty-matching entry; webapp.routineapproles.read sorts MatchRole ascending and answers it first; minting webapp.routineapps.update with MatchRoles as read lists MatchRoles under changed, before and after differing in order only. Fix is an order-insensitive list compare in the shared mint (Write.cls, contended) or a read in the vendor's order.
    location: >-
      src/OcuPilot/Screen/Descriptor/RoutineAppRoleList.cls read.sort
    severity: medium
---

<intent-contract>

## Intent

**Problem:** The agent has to keep pace with Stage 2: every new screen must reach it through its descriptor, and two gaps remain (no read tool answers a privileged routine application's `MatchRoles` or `Routines`, DW-2321; Guardrails omits the turns-per-hour limit, DW-1756).

**Approach:** C1 as a completeness test over Epic 18's descriptors: every Stage 2 screen brings a read tool and a confirmed single-write tool declared from the same descriptor, with no hand-written dispatch or field list (the orchestrator's tier-1 restatement per AD-3). Plus DW-2321 and DW-1756. Split on the orchestrator's ruling (2026-10-11, Rule 5): the context budget is Story 18.39's, proxy and custom CA Story 18.40's, the wallet rung Story 18.41's. DW-1084 is closed `by-design` with its evidence (the live prompt's backtick line, Story 11.4's criterion).

## Boundaries & Constraints

**Always:** The tool listing stays 20.24's per-process cache (AD-5); Rule 31 forbids a second cache.

**Never:** Build on a `decision-pending` entry. Build the context budget, proxy or CA configuration, or the wallet rung (Stories 18.39 to 18.41).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| DW-2321 | The agent changes one entry of an application's `MatchRoles` or `Routines` | A read tool answers the current list, so the update sends it whole with one entry changed | A caller without the list's pairs is refused by name (AD-8) |
| DW-1756 | Guardrails, with turns an hour set on Switches | The limits section names the setting in force | No limit set reads as no limit |

</intent-contract>


## Code Map

Paths under `src/OcuPilot/` unless `ui/`, at `785cdd9d`.

- **Listing, dispatch.** `Screen/Tool/Registry.cls` `ListTools` :114 (20.24's cache), `BuildListing` :258-270 (one `.read` per read). `Api/ScreenAction.cls` `ToolFor` (~:588): the tool whose `DESCRIPTORCLASS` is the screen and `ScreenActionIds` hold the action.
- **Fields (AD-3).** `Screen/Tool/Write.cls`: `FieldRows` :758, `AdmittedFields` :813, `SettableFields` :572, `PortClass` :307; generated `ToolFields.cls`. `Classification.cls` :58-62 (`MatchRoles`, `Routines` unnamed; the update authors them).
- **Read (AD-36).** `Screen/Read.cls`: a parent-scoped `GET` over one member requires its criterion (:695), reads the vendor's 404 as no rows (:707); `RowsMember` :961. Arrays pass `Kernel/Agent/Bound.cls` :88 uncut.
- **Models.** `DatabaseVolumeList.cls`, `JournalFileDatabaseList.cls`. `navigation.ts` `childListFor` :329 needs an id kind other than `none`; `data-table.ts` :656 tries the editor first, so the list's name cell still opens the form.
- **Vendor** (read on `ocupilot`): the `Security.PrivilegedRoutine` `GET` (`PropsToJson`) always answers `MatchRoles` `[{MatchRole, TargetRoles[]}]` and `Routines` `[{RoutineOrClass, Db, Type}]`, `[]` when empty; another application type is 404 `PRIVROUTINE.TYPE` (`AdminPort`).
- **Probes.** `Test/RoutineAppProbe.cls` (`Seed`, `WithLists`, `Mint`, `Entries`, `Targets`, `RemoveAll`; `OcuProbe1831`), `Test/RoutineAppGate.cls`.
- **DW-1756.** `Kernel/Shell/Guardrails.cls` :105-109; `Kernel/State/Switch.cls` `Resolve` :118 (`turnsPerHour`, default 0), `SetGuarded` :165; `core/guardrails.ts` :52-56, :136-143; `guardrails.page.ts` :111-114.
- **Out of scope**, anchors in this spec at `785cdd9d`: 18.39 (context budget); 18.40 (proxy, custom CA); 18.41 (wallet rung).

## Tasks & Acceptance

**Task 0** (`ocupilot-ci`, after `LOAD-OK` and `STARTPATH-OK`): record S0.

**Execution:**

1. `Screen/Descriptor/RoutineAppRoleList.cls` and `RoutineAppRoutineList.cls` (new, after `DatabaseVolumeList`).
   - Common: `list`, built, `sideBarPosition` 0, no refresh, `RoutineAppList`'s pairs, `entityType` "", `instance`, `parentScope` `web-applications/routine-applications`, no actions, `classicPage` `%CSP.UI.Portal.Applications.PrivRoutine`. Source `{port: admin, endpoint: Security.PrivilegedRoutine, type: GET, rows}`. One criterion: `name`, text, `maxLength` 64, `labelKey` `tableColumnName`, `hint` "One privileged routine application, spelled as webapp.routineapps.read answers its Name.". Paging `cap`, `emptyNextKey` `tableReadOnlyEmptyNext`, and three prompts.
   - Roles: route `.../roles`, `webapp.routineapproles`, rows `MatchRoles`, id `[MatchRole]`. Fields and context `MatchRole, TargetRoles`; sort and filter `MatchRole` (asc). Columns: `webAppFieldMatchRole` (`name`, `emptyKey` `routineAppRolesEveryCaller`), `userColumnRoles` (`identifier`); label `routineAppRolesLabel`, empty `routineAppRolesEmpty`.
   - Routines: route `.../routines`, `webapp.routineapproutines`, rows `Routines`, id `[RoutineOrClass, Type, Db]`; fields, context and sort `RoutineOrClass, Db, Type` (default `RoutineOrClass` asc); filter `RoutineOrClass, Db`. Columns: `routineAppFieldRoutine` (`name`), `systemInfoDatabase`, `tableColumnType`; label `routineAppTabRoutines`, empty `routineAppRoutinesEmpty` (reused).
2. `RoutineAppUpdate.cls` `DESCRIPTION` adds: "Read the current lists first with webapp.routineapproles.read and webapp.routineapproutines.read, and send each list whole with only your change."
3. Strings, add-only.
   - Under `/** EXPERIENCE.md:357 */`: `routineAppRolesLabel` 'Application and matching roles', `routineAppRolesEmpty` 'This application grants no roles.', `routineAppRolesEveryCaller` 'Every caller', `routineAppRolesPrompt1-3` and `routineAppRoutinesPrompt1-3` (what a list holds, an administrative grant or an entry's database, changing one entry).
   - Under `:583`: `agentGuardrailsLimitsHeading` 'Limits', `agentGuardrailsTurnsLimit` 'Each user may start at most <n> agent turns an hour.' and `agentGuardrailsTurnsNone` 'Agent turns an hour are not limited.'
   - EXPERIENCE.md in place, line count unchanged: :357 gains the ten (`[ADDED 2026-10-11 - Story 18.12]`); :583 replaces `"Screen context"` with `"Limits"` and gains the two. Run `node tools/screen-mirror.mjs`; stop past 3350 strings.
4. `Kernel/Shell/Guardrails.cls` (DW-1756): `limits.turnsPerHour` from `Switch.Resolve` (0 is no limit); the header bullet says so.
5. Client (DW-1756). `core/guardrails.ts`: `GuardrailsLimits.turnsPerHour` (`wholeNumber`, required by `narrowGuardrails`); `turnsLine`: `agentGuardrailsTurnsNone` at 0, else `agentGuardrailsTurnsLimit` with `<n>` grouped. `guardrails.page.ts`: the last section's heading becomes `agentGuardrailsLimitsHeading`; `.ocu-guardrails-turns` follows `.ocu-guardrails-limits`.

**Tests** (classes under 500 lines):

6. `Test/StageTwoTools.cls` (new; C1).
   - **Roster.** XData `Roster`: one `<screen name kind [list] [reason]>` per screen Epic 18 commits added (`git log --diff-filter=A`). Kind `form` (with its `list`): DatabaseIntegrity (DatabaseList), EncryptionKeyFileForm (EncryptionKeyFile), and the `<X>Form`/`<X>List` pairs for DocDbApp, EcpDataServer, GlobalMapping, LicenseServer, LocalDatabase, MftConnection, Namespace, PackageMapping, RemoteDatabase, RoutineApp, RoutineMapping and Superserver.
   - Kind `read-only`, each with a reason: AllowedDirectoryList, DatabaseIntegrityLog, EcpAppServerTab, JournalFileDatabaseList, JournalFileDetails, JournalRecordList, MetricsList, the three `Sql*PrivilegeList`, 18.36's four `Dashboard*` (once landed), and Task 1's two. Every other screen (24) is kind `writes`.
   - `<tool>` rows: the 17 Epic 18 tools bound to earlier screens (`DatabaseDetails` 5, `DatabaseList` 1, `UserList` 3, `RoleList` 2, `WalletSecretList` 4, `RestApiList` 2).
   - **Kinds test.** Each screen is built, registered and its row's kind: `form`, no read or bound write tool, its `list` reading and binding one; `read-only`, a read and no action or bound tool; `writes`, a read and a bound tool. A reading screen's `<toolIdentifier>.read` is listed and bound to it.
   - **Actions test.** Each row action of a `writes` screen resolves by `ToolFor`'s rule to exactly one bound tool; the primary action does too, or resolves to a bound tool with `Creates()` 1. Every bound tool is advertised except AD-53's `osmgmt.licensekey.activate` and `security.secrets.replacesymmetric`.
   - **Fields test.** For each bound tool and `<tool>` row: listed as a `write` of its own class; `AdmittedFields()` within `SettableFields()`; every other settable name but `IdArgument()` is a first path segment of its `ToolFields` entry, or `PortClass()` is not `AdminPort` (AD-51, AD-52). Failures name `tool:name`.
   - The source survey found no gap; a gap the run names is the blocking condition, never a silent row.
7. `Test/RoutineAppListsRead.cls` (new; DW-2321), through `RoutineAppProbe`.
   - One test pins both shapes.
   - With two entries in each list, `GET /screens/<screen>/read?name=` and the tool's view answer one row per entry, equal to the vendor `GET`'s arrays; an empty list or absent name answers no rows, a web application 404 `PRIVROUTINE.TYPE`, no `name` 400 `READ.CRITERION`.
   - **Integration:** read `Routines` through the tool, `Mint` the update with those rows less one and `MatchRoles` as read, confirm: the diff changes `Routines` alone; `Entries` and `Targets` keep the rest.
   - `RoutineAppGate` gains one method: without `%Admin_Secure:USE`, both reads are refused 403, naming it.
8. DW-1756. `Test/Guardrails.cls`: `TestTheLimitsAreTheKernelsOwn` also asserts `turnsPerHour`; a new method sets 7, then 0, through `SetGuarded`, reads each back, then `SwitchFixture.Reset`. `GuardrailsWire` asserts the member; `guardrails.test.mjs` the narrowing and `turnsLine` at 0 and 1200; `guardrails.page.spec.ts` the headings and turns line; `guardrails.browser-spec.mjs` a leg that sets 7 (`setSwitches`), reads the line, restores in `finally`.
9. `routine-applications.browser-spec.mjs`: a leg seeds a probe with lists (`iris`), opens both routes at `<route>/<encoded name>`, and after the table answers sees one row per entry (`Every caller` included) and a locator back to the list; then `removeProbes`.
10. **Rule 30 sweep.** Add-only: `SurfaceCoverage` (two screens), `Descriptor` `ReadShapes`, `navigation.test.mjs` :258-270 (two routes). In place: `ReadTool` :93 (356 + 18.36's four + two) and :94; two `name:READ.CRITERION` tokens in `ToolRoundTrip` `REFUSEEMPTY`. Grep the test trees for Web applications rosters (`Navigation`, `Wire*`, floor rosters). Run, editing only if red: `ToolEmit`, `ToolDispatch`, `EndpointCoverage`, `RoutineAppRead`, `RoutineAppMembers`, `RoutineAppDescriptor`.

**Acceptance Criteria:**

- **C1 (screens).** Given the Stage 2 roster, when `StageTwoTools` reads the registries, then each screen is its row's kind and each declared action resolves to exactly one write tool of its own descriptor.
- **C1 (fields).** Given every Stage 2 write tool, when its settable names meet its generated field list, then each is admitted from it, authored on one of its paths, or a composing port's argument.
- **DW-2321.** Given two entries in each list, when either read answers by route or tool, then it returns one row per entry, under the matrix's refusals.
- **Integration.** Given the routines `webapp.routineapproutines.read` answered, when the agent sends `webapp.routineapps.update` with one entry removed, then the confirmed write removes that entry alone.
- **DW-1756.** Given turns an hour of 7 on Switches, when Guardrails opens, then its Limits section reads `agentGuardrailsTurnsLimit` with 7, and `agentGuardrailsTurnsNone` at 0.

## Spec Change Log

- 2026-10-11, lead: narrowed on the orchestrator's split ruling (feature 5b86e803, Rule 5): 18.12 keeps C1 (restated per AD-3), DW-2321 and DW-1756; C2 to C4 moved to Stories 18.39, 18.40 and 18.41 (their anchors stay in this Code Map, to be compressed to pointers at the re-plan). DW-1084 closed by-design. Intent narrowed, Proposed Split removed, status reset to draft for a re-plan in place.

## Review Triage Log

### 2026-10-11 - Review pass

- verdicts: 19 findings - high 0, medium 5, low 12, false 2, maybe-false 0
- findings:
  - `[medium]` `[patch]` verification-gap: the empty-list and absent-name legs counted rows only, so a 404 read as "no rows" - the legs now assert 200 on the route and the tool; mutation recorded.
  - `[medium]` `[patch]` verification-gap: the 17 `<tool>` roster rows were never checked to name a tool - the fields test asserts each is listed; mutation recorded.
  - `[low]` `[patch]` verification-gap: the primary-action leg passed when two tools claimed the id - it asserts at most one claimant; mutation recorded.
  - `[medium]` `[defer]` verification-gap: the roster is the only input to C1, with no reverse check against the registry - fix needs a Stage 2 marker or a baseline of earlier screens (Descriptor, contended); deferred.
  - `[low]` `[patch]` verification-gap: `guardrails.page.spec.ts` adjacency line passed on `undefined` - coalesced to null.
  - `[low]` `[patch]` verification-gap: `TestTheTurnsAnHourFollowTheSwitch` reset the switch row only as its last statement - `OnAfterOneTest` resets it too.
  - `[low]` `[patch]` verification-gap: three doc comments named mutations the spec did not record - aligned to the recorded ones.
  - `[low]` `[reject]` verification-gap: `RoutineAppGate` refuses only the `%Admin_Secure:USE` principal - Task 7 prescribes that leg; the other pair is pinned by the `WireSecurityRead` screens roster this story edited.
  - `[low]` `[reject]` verification-gap: "at most 1 agent turns an hour" - the sentence is fixed by Task 3; cosmetic.
  - `[low]` `[reject]` intent-alignment: C1 asserts registry facts and invokes no tool, proposal or confirm per screen - Task 6 and the AD-3 restatement define it so; the confirmed write is the Integration AC's.
  - `[false]` `[reject]` intent-alignment: "declared from the same descriptor" is met by the tool class's `DESCRIPTORCLASS` - that is how AD-3 binds a tool; nothing diverges.
  - `[low]` `[reject]` intent-alignment: the fields test passes any settable name on a non-admin port - Task 6 states that clause (AD-51, AD-52).
  - `[medium]` `[defer]` intent-alignment: no reverse assertion that every registered Epic 18 descriptor is on the roster - same root cause as the roster-only finding above.
  - `[false]` `[reject]` intent-alignment: `StageTwoTools` is referenced nowhere - `ci-shards.mjs` offers every class on disk and weighs an unrecorded one at the median, so no registration exists to miss.
  - `[low]` `[reject]` intent-alignment: two routes and ten strings ship that the intent does not name - tools exist only as screens (Task 1).
  - `[low]` `[reject]` intent-alignment: the reads are tested in process, not through the model, and the `DESCRIPTION` sentence is untested prompt text - the Integration AC is stated at that surface.
  - `[low]` `[reject]` intent-alignment: refusal by name is tested at the route, not the tool as an outsider - Task 7 prescribes the route leg; the registry's gate point is shared.
  - `[low]` `[reject]` intent-alignment: DW-1756 lands on the page, which the agent cannot read - the matrix row is the Guardrails section; the heading rename is Task 5's.
  - `[medium]` `[defer]` stage lead, from the implement report, probe-verified on `ocupilot-ci`: the roles read lists "Every caller" first while the vendor stores it last, so an update that echoes `MatchRoles` as read reports it changed, in order alone - fix is in the shared mint or the read's order, both outside this story; deferred.

## Design Notes

**Ledger.** DW-2321: Tasks 1, 2, 7, 9 (privileged routine applications, as the intent names). DW-1756: Tasks 3 to 5, 8. Declined DW-1084: closed `by-design` by the lead.

**Governing ADs:** AD-3, 5 (one listing cache), 8, 22 (no key), 24, 36, 41, 44, 50, 51, 52, 53.

**Rule 31.** Descriptors follow `DatabaseVolumeList`; tests extend `RoutineAppProbe`, `RoutineAppGate`. `StageTwoTools` is not `SurfaceCoverage` rows (contended, 742 lines). The editor's tabs keep 18.33's form read, whose one `GET` also feeds the pickers; both readers copy the same arrays.

**Measured** (source, `785cdd9d`): 48 Epic 18 descriptors (24 write, 10 read-only, 14 forms), 83 Stage 2 write tools, no action or field gap.

**Integration ACs:** the Integration line. **Consumes:** 18.31, 18.33, 18.5, 14.6, 16.22, 20.24. **Consumed-by:** 18.39, 18.42.

**For the lead** (Rule 20):

- **Gaps outside this scope.** (1) `FSAccess.Path`/`Purpose` writes have no surface (Allowed directories is read-only by 18.1); a write widens AD-21's sixth-case roots, the owner's call. (2) DW-2321's web-application half: `webapp.list.update` takes `MatchRoles` whole and no read answers it; re-own the residual. (3) Forms show scalar fields no read answers (superservers 14, local databases 10, user copy 12).
- **Pre-authorization (Rule 11).** The in-place edits to `ReadTool` :93-94, `ToolRoundTrip` `REFUSEEMPTY` and any `Navigation` count are in Epic 20's files and need the orchestrator's pre-authorization at the spec gate (as 18.11).
- No spine change required; no vendor defect candidate.

## Verification

**Shared surfaces:** read-tool registry (+2), `SurfaceCoverage`, `ReadShapes`, Web applications' routes and wire rosters, `REFUSEEMPTY`, the Guardrails answer and headings, structural walk routes, Fixed strings.

**Standing criterion:** every test added or changed passes on a fresh environment, in either order.

**Commands:**

- `(loop)` `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/carry-2026-10-08/epic-18-d8/load-ocupilot-ci.sh` -- expected `LOAD-OK` and `STARTPATH-OK`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one at a time, totals from `%UnitTest_Result`: Tasks 6 to 8's classes and every class Task 10 edits or runs.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`; `uv run scripts/check-objectscript.py`; `bash scripts/lint-docs.sh`.
- `(loop)` With `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, then `node --test --test-concurrency=1` `browser/guardrails.browser-spec.mjs` and `browser/routine-applications.browser-spec.mjs`, then `browser/a11y-structural-invariants.browser-spec.mjs` (391 s; fix a fresh key on the new routes). Bundle against 3487kB (DW-1166); stop and ask above 3800kB.
- Full ObjectScript sweep: the runner's; browser suite: CI's.

**Mutations (Rule 19),** recorded as `mutation:`, reverted byte-identical, descendants recompiled or bundle redeployed:

- C1: `JournalFileDatabaseList` `built` false (kinds); `RoutineAppDelete` `SCREENACTIONS` "" (actions); `RoutineAppUpdate.SettableFields` plus `Bogus`, `LocalDatabaseCreate` on `AdminPort` (fields).
- DW-2321: the roles read's `rows` `Routines`; its pairs without `%Admin_Secure:USE`. Integration: `SettableFields` without `Routines`.
- DW-1756: `Guardrails.Read` without `turnsPerHour`; `turnsLine` constant; the page's turns line removed.

Recorded (each applied on `ocupilot-ci`, the mutated class and its descendants recompiled or the bundle rebuilt and redeployed, red observed, reverted; the tree hash was identical after):

- mutation: `JournalFileDatabaseList` `built` false -> `StageTwoTools.TestEachScreenIsItsRowsKind` red ("JournalFileDatabaseList is built").
- mutation: `RoutineAppDelete` `SCREENACTIONS` "" -> `StageTwoTools.TestEachDeclaredActionResolvesToExactlyOneWriteTool` red ("RoutineAppList:delete resolves to exactly one write tool").
- mutation: `RoutineAppUpdate.SettableFields` plus `Bogus` -> `StageTwoTools.TestEverySettableNameComesFromTheGeneratedFieldList` red (`webapp.routineapps.update:Bogus`).
- mutation: `LocalDatabaseCreate` `PORTCLASS` the admin port -> the same test red, naming `osmgmt.localdatabases.create:` root, path, Size, GlobalJournalState and ResourceName.
- mutation: the roles read's `rows` `Routines` -> `RoutineAppListsRead` red in both methods (the roles legs).
- mutation: the roles list's pairs without `%Admin_Secure:USE` -> `RoutineAppGate.TestWithoutTheAreasResourceBothListReadsAreRefusedByName` red (the roles leg alone).
- mutation: `RoutineAppUpdate.SettableFields` without `Routines` -> `RoutineAppListsRead.TestAnAgentSendsTheRoutinesItReadLessOneEntry` red (the mint answers "nothing would change").
- mutation: `Guardrails.Read` without `turnsPerHour` -> `Guardrails.TestTheLimitsAreTheKernelsOwn`, `Guardrails.TestTheTurnsAnHourFollowTheSwitch` and `GuardrailsWire.TestALeastPrivilegedPrincipalReadsTheWholeAnswer` red.
- mutation: `turnsLine` answering the none sentence always -> `guardrails.test.mjs` "the turns line reads no limit at 0 and the limit, grouped, above it" and `guardrails.page.spec.ts` "names the turns an hour in force" red.
- mutation: the page's `.ocu-guardrails-turns` line removed -> `guardrails.page.spec.ts` red and, rebuilt and redeployed, `guardrails.browser-spec.mjs` AC1 and the Story 18.12 leg red.
- mutation: the roles list's `emptyKey` removed (mirror regenerated, rebuilt, redeployed) -> `routine-applications.browser-spec.mjs` Story 18.12 leg red ("(none)" where "Every caller" is expected).
- mutation: `Read.cls` absence mapping off (`tObjectGone` 0) -> `RoutineAppListsRead.TestBothListsAnswerOneRowPerEntryByRouteAndTool` red on the empty and absent legs, which assert 200 where a bare row count stayed green.
- mutation: a `<tool>` roster row misspelled (`permissions.users.grantsqlx`) -> `StageTwoTools.TestEverySettableNameComesFromTheGeneratedFieldList` red ("is a listed write tool").
- mutation: `RoutineAppUpdate` and `RoutineAppDelete` both declare `create` in `SCREENACTIONS` -> `StageTwoTools.TestEachDeclaredActionResolvesToExactlyOneWriteTool` red ("RoutineAppList:create is claimed by at most one write tool").

**S0:** no `OcuProbe1831*` application or `OcuProbe1833Role*` role; switches as Task 0 recorded.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** C1 `Test/StageTwoTools.cls` (kinds, actions, fields over 54 screens and 17 tool rows; no gap found). DW-2321: `RoutineAppRoleList` and `RoutineAppRoutineList` declare `webapp.routineapproles.read` and `webapp.routineapproutines.read`; `RoutineAppUpdate` `DESCRIPTION` says to read them first. DW-1756: `Guardrails.Read` answers `limits.turnsPerHour`; the client narrows it, adds `turnsLine`, and the last section is headed Limits with the turns line under the limits line. Twelve strings added (3268 to 3279 fixed strings), EXPERIENCE.md rows 357 and 583 edited in place, mirror regenerated.

**Files.** New: the two descriptors, `Test/StageTwoTools.cls`, `Test/RoutineAppListsRead.cls`. Changed: `Kernel/Shell/Guardrails.cls`, `Screen/Tool/RoutineAppUpdate.cls`, `Test/{Guardrails,GuardrailsWire,RoutineAppGate,Descriptor,SurfaceCoverage,ReadTool,ToolRoundTrip,Wire,WireSecurityRead}.cls`, `scripts/ci-throwaway.sh` (arming-roster comment), `core/guardrails.ts`, `guardrails.page.ts`, `core/strings.ts`, `core/screens.generated.ts`, `testing/guardrails.ts`, five client specs, `guardrails.browser-spec.mjs`, `routine-applications.browser-spec.mjs`, EXPERIENCE.md.

**Review.** 19 findings: 6 patched (three assertion strengthenings with recorded mutations, the page spec line, the Guardrails reset and the comment alignment), 2 deferred (roster-only completeness; roles read order against the vendor's), the rest rejected with reasons in the log. Follow-up review: false, since the two patched mediums are test assertions each shown red by a recorded mutation and green after.

**Verification.** `OcuPilot.Test` on `ocupilot-ci`: 19 classes green in runs 694 to 712; after the review patches StageTwoTools 725 (3), RoutineAppListsRead 726 (2), Guardrails 721 (11), RoutineAppRead 727 (4), RoutineAppGate 715 (6). `npm run test:tools` 1913 of 1913; components 2945 (236 files), the Guardrails page spec re-run after its patch; browser specs guardrails 3 of 3, routine-applications 4 of 4, a11y-structural 13 of 13. Initial bundle 3,388,876 bytes against 3527kB. `check-objectscript`, `lint-docs` clean; secrets scan 0.

**Residual risks.** `ReadTool` `tWithCriteria` (57 to 59) is an Epic 20 file edit beyond the :93/:94 pre-authorization, the same count union; at the merge it becomes 60 with Epic 20's 58. `ReadTool` :93 reads 371 here. S0 holds: no `OcuProbe1831*` or `OcuProbe1833*` object, and the switch row is absent where Task 0 found one with default values.
