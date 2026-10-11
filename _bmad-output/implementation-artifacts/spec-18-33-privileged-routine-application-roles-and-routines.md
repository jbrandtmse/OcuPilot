---
title: 'Story 18.33: Privileged routine application roles and routines'
type: 'feature'
created: '2026-10-11'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Story 18.31's routine application editor has only General: roles, matching roles and routines stay classic-only, and `webapp.routineapps.update` only resends the fresh lists (AD-4).

**Approach:** The editor gains the classic Application roles, Matching roles, and Routines and classes tabs, each add or remove one of six screen actions on the update, a delta over the fresh read (AD-56 (ii)); the agent sends `MatchRoles` and `Routines` as complete lists. A grant of `%All` or an `%Admin_*` privilege is destructive; OcuPilot's own two stay refused (18.10's arm). DW-2279: the Doc DB tools' refusals stop naming a mapping.

## Boundaries & Constraints

**Always:**

- Every update sends both lists, as read or as changed (AD-4).
- The tabs act only through the six row actions; General's Save sends its three settings and refuses a list.
- Every rule is decided before any `PUT`, by one rule set on both callers (AD-39, AD-55).
- A grant through a role, a matching role or a routine is destructive with `GRANT.PRIVILEGED` (AD-10); a person's tab states `privilegedGrantEffect`.

**Never:**

- Add a tool, route, governance key, entity type, `PROHIBITED.*` code or classic page.
- Write `OcuPilotState` or `OcuPilotIdentity`, even under a mutation.
- Build on DW-2283, DW-2284 or another owner-hold entry.
- Edit `Prohibited.cls` except by adding lines and splitting the routine type out of the change-fields clause at :1139 (Epic 20's open diff does not touch the file; re-check under Rule 11).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Roles | Add or remove `Role`, or `MatchRole` and `Role` | Applied; `Routines` as read | Absent, granted, not granted: 400 `TOOL.ARGUMENTS` |
| Routines | Add or remove `{RoutineOrClass, Db, Type}` | Applied; `MatchRoles` as read | Held, not held, empty: 400 |
| Agent lists | A complete list | Stored; the other as read | As Rules |
| Rules | `MatchRoles` misshapen or naming an absent role; a routine entry not exactly three strings, its name empty or holding `,` or `:`, an unlisted `Db`, `Type` not `Routine` or `Class` | 422 `WEBAPP.MATCHROLES.SHAPE`, `.UNKNOWN` or `PRIVROUTINE.ROUTINES`; nothing sent | The mint alike |
| Grant | `%All` or a role carrying an `%Admin_*` resource added as a target; a routine added under one | `destructive`, `GRANT.PRIVILEGED` | A remove, or under unprivileged roles: not |
| Own two | Any of the six actions | 403 `PROHIBITED.OCUPILOTROUTINEAPP`; tab controls `aria-disabled` | Nothing sent |
| Save | General's Save carrying a list | 400 `PORT.FIELDUNEXPECTED` | Nothing sent |
| DW-2279 | A Doc DB tool's mint, `Namespace` or `Name` empty | 400 naming "the namespace the record belongs to" or "the Doc DB application record" | No "mapping" |

</intent-contract>

## Code Map

Paths are under `src/OcuPilot/` unless under `ui/`; Tasks carry the rest:

- `WebAppUpdate` :259, the role delta over the same `MatchRoles` shape and port, and :116, the list schema. `Classification.cls` :714 keeps both lists unnamed, as for `webapp.list.update`.
- `Mint.cls` :333-351 maps `GrantsPrivilegeByEffect` to `destructive` and `GRANT.PRIVILEGED`.
- The classic page lists `Config.Databases:List("*")` (`PrivRoutine.cls` :425), as `PathPort.DatabaseDirectories` :546 does for directories.
- `InteropItemMint` :14-20 overrides `MappingMint` :19-25.
- Client: `web-app-editor.page.ts` :333-457, :783-835, :960-995 (role tabs); `web-app-class-access-tab.ts` (a tab component); `FormRules.Roles` :405 (`[{name, privileged}]`).
- Tests: `WebAppSave` :225-262 and `Act` :271; `RoutineAppProbe.WithLists` :69.

## Tasks & Acceptance

**Task 0** (`ocupilot-ci`, after `LOAD-OK` and `STARTPATH-OK`): record S0; check on a probe `OcuProbe1833T0` whether a list `PUT` records `%System/%Security/ApplicationChange` (AD-15; none is a named gap), then remove it. Halt on a contradiction with Design Notes.

**Execution:**

1. `Api/RoutineAppError.cls`: `PRIVROUTINE.ROUTINES`, "Each routine entry names a routine or class, a database this instance defines and its type, Routine or Class.", in `Codes`, `ViolationCodes`, `FieldOf` (`Routines`) and `ReasonFor`.
2. `Port/AdminPort.cls`, beside `NamespaceDefined` :2961: `DatabaseNames(Output pNames As %List) As %Status`, the sorted `Config.Databases:List("*")` names, read in `%SYS` per call (AD-16); `DatabaseDefined(pName)`, exact membership.
3. `Area/WebApp/Create.cls`: `MatchRolesViolation` :450 drops `[ Private ]`.
4. Rules:
   - `DocDbAppRules.HandleForm` :245 calls a new overridable `FormRead(pFresh, pRow, pBody) As %Status` (default `$$$OK`) before rendering.
   - `RoutineAppRules.Check` calls `##super`, then judges each list sent (with `pFull` 1, only one differing from `pFresh`'s): `MatchRoles` by `MatchRolesViolation`, `Routines` by a new `RoutinesViolation` applying the Rules row, adding `PRIVROUTINE.ROUTINES` once.
   - `RoutineAppRules.FormRead`, given a fresh read: `row.MatchRoles` and `row.Routines` as read, `roles` (`FormRules.Roles`), `databases` (`DatabaseNames`).
5. `DocDbAppSave.Unexpected` :268 reads a new overridable `SaveFields(pToolClass)` (default `SettableFields`); `RoutineAppSave` answers `RoutineAppRules`' `FIELDS`.
6. `Screen/Tool/RoutineAppUpdate.cls`:
   - `SettableFields`: `##super()` plus both lists; `InputSchema` adds them, described; `DESCRIPTION` says each is complete and a privilege grant is confirmed as a delete is.
   - `SCREENACTIONS`: the role four, `add-routine`, `remove-routine`. `SCREENVALUES`: the role four as `WebAppUpdate` :61, then `add-routine=RoutineOrClass:Db:Type,remove-routine=RoutineOrClass:Db:Type`.
   - `ScreenActionDelta`: role actions go to `##class(OcuPilot.Screen.Tool.WebAppUpdate).ScreenActionDelta`; a routine action answers `pFresh`'s `Routines` with one entry added or removed (name exact, `Db` without case, `Type` exact), refusing an empty value, an add held or a remove not held, echoing no value; else `##super`.
7. `Kernel/Proposal/Prohibited.cls`, adding lines only:
   - split `PermittedChangeFields`' :1139: the Doc DB type keeps `DocDbApplicationFields()`; `If pType = ..#TYPEROUTINEAPPLICATION Quit ..RoutineApplicationChangeFields()`, that private method at the end: `DocDbApplicationFields()` plus `MatchRoles` and `Routines`. Create stays three.
   - In `GrantsPrivilegeByEffect`, before the web branch :4510: the routine type takes `GrantsPrivilegeByEffect(..#TYPEWEBAPPLICATION, …)`, then, if 0, a new private `AddsRoutineUnderPrivilege`: the payload adds a routine entry the target lacks while a target role in its `MatchRoles` escalates (`RoleEscalates` :4268).
8. `Screen/Descriptor/RoutineAppList.cls` :39: the six row actions, `selfProtection` `ocupilot-routine-application`.
9. **DW-2279** (re-check Epic 20's diff, Rule 11): `Screen/Tool/DocDbAppMint.cls` extends `MappingMint` with "the namespace the record belongs to", "the Doc DB application record" and "namespace or record name"; each `DocDbApp*` tool's `MintClass` names it.
10. Client, `ui/src/app/areas/web-applications/`:
    - The store keeps the lists, `roles` and `databases` outside the General buffer, and gains `refresh()`.
    - Editing shows `FormTabs` General, Application roles, Matching roles, and Routines and classes; a create, General only.
    - New `routine-app-member-tabs.ts` holds the three bodies. The role tabs follow the web editor's, a privileged pick stating `privilegedGrantEffect`. Routines lists Database, Routine or class, Type and Remove, and adds by a hinted name, a `databases` picker, a Routine or Class picker and Assign, stating `privilegedGrantEffect` while a held target role is privileged.
    - Each act is `ScreenActionHandler.startFor(ROUTINE_APP_LIST, …, values)`, then refreshes. On the own two every control is `aria-disabled`, described by `routineAppRefusalOcuPilot`.
    - `shell/screen-action-handler.ts` add-only: `ADD_ROUTINE`, `REMOVE_ROUTINE` beside :161-164; the six in `UNDRAWN_ACTIONS` :363. Run `node tools/screen-mirror.mjs`.
11. `strings.ts` add-only, cited `/** EXPERIENCE.md:357 */`: `routineAppTabRoutines` 'Routines and classes', `routineAppRoutinesEmpty` 'This application lists no routines or classes.', `routineAppFieldRoutine` 'Routine or class', `routineAppRoutineHint` 'A routine name, or Package.Name for a class.'; the rest reuse their keys (one key per value). EXPERIENCE.md :357 in place, `[ADDED 2026-10-11 - Story 18.33]`; stop past 3350.

**Tests** (`RoutineAppProbe` probes, `RemoveAll` in `OnAfterOneTest`, each class under 500 lines; a class declaring `OCUPILOT_ALLOW_PRINCIPALS` joins `scripts/ci-throwaway.sh`'s roster, add-only):

12. ObjectScript:
    - New `RoutineAppMembers` (`WithLists` probe): each action through `/screens/webapp.routineapps/action` and the agent's lists through mint and confirm, the GET holding the change and the other list; every refusal sends nothing (`Facts` unchanged); General's Save refuses a list; the own two through `Prohibits`, `RefusesBeforeState` and each action's route (403, the port arm refusing too).
    - New `RoutineAppGrant`: the Grant rows through the update's mint (`destructive`, `consequence`) and `GrantsPrivilegeByEffect` directly.
    - `RoutineAppRead`: the form read's lists equal the GET's, `%All` is marked privileged, `databases` equals `Config.Databases:List`'s names.
    - `RoutineAppGate`: the area's two pairs and the install database's READ apply `add-routine` and `add-application-role`; without `%Admin_Secure:USE`, refused by name before any port call.
    - `RoutineAppDescriptor`: the six actions with the rule, five settable, the kernel's five and three, the code. `DocDbAppDescriptor`: DW-2279's sentences.
13. Client: store, page and member-tabs specs; an undrawn leg in `screen-action-handler.spec.ts`. `ui/browser/routine-applications.browser-spec.mjs`, a new test on its own probe: after the editor answers, add and remove a role, a matching role and a routine through the tabs, each row appearing and going; the own two's tab controls `aria-disabled`; the after hook runs `RemoveAll`.
14. **Rule 30 sweep:** edit `RoutineAppDescriptor` :123 (five change fields), `RoutineAppWrite` :574-579 (the lists now pass; a field outside the five still `UNCOVEREDFIELD`), and `RoutineAppRead` or `DocDbAppWrite` where they pin the old shape or wording. Run, editing only if red: `ReadTool`, `SurfaceCoverage`, `EndpointCoverage`, `ToolRoundTrip`, `ToolWrite`, `ToolDispatch`, `PortGate`, `ClassicPageGate`, `MappingDescriptor`, `SaveHoldCoverage`, `ProhibitedRoute`, `Governance`, `GovernanceBaseline`, `RefusalCopy`, `Test.Prohibited`, `Test.Descriptor`, `Wire`, `WireSecurityRead`, `WebAppSave`, `field-lists.test.mjs`, `navigation.test.mjs`, `screen-mirror.test.mjs`, `strings.test.mjs`, `ci.test.mjs`.

**Acceptance Criteria:**

- **C1.** Given a probe, when the form read answers, then its lists equal the GET's, roles carry privileged marks, and databases are the instance's.
- **C2.** Given a probe, when either caller adds or removes a role, a matching role or a routine, then the instance holds exactly that change and the other list as read (AD-4), and the editor re-reads.
- **C3.** Given a Rules row, a duplicate add or a remove of what is not held, when either caller sends it, then it is refused before any `PUT`, the probe unchanged.
- **C4.** Given the own two, when any of the six actions targets one, then 403 `PROHIBITED.OCUPILOTROUTINEAPP`, nothing changes, and every tab control is `aria-disabled` with the rule's sentence.
- **C5.** Given a Grant row, when the agent proposes it, then it is destructive with `GRANT.PRIVILEGED`, and a person's tab states `privilegedGrantEffect`; the matrix's exceptions are not destructive.
- **C6.** Given the rosters, when the suites run, then Task 12's descriptor facts, the Save's list refusal, DW-2279's wording and the strings bound hold.
- **Integration.** Given `ocupilot-ci`, when the page and the agent act, then the page consumes the form read and the six actions, and the agent the update's two lists (C1-C5, the browser spec).

## Spec Change Log

- 2026-10-11, lead, spec gate: Epic 20's open diff no longer touches `Prohibited.cls`, so the intent's Never bullet admits splitting the :1139 clause and Task 7 replaces it instead of leaving it unreached (Rule 5 tier 1); Task 0's probe takes the `OcuProbe1833` prefix S0 checks; AD-4 and AD-10 amended; AD-56 (ii) and AD-8 need no line; `AdminPort`'s `Config.Databases` read follows `NamespaceDefined`'s precedent; AD-15 is written from Task 0's measurement at `dev_complete`.

## Review Triage Log

## Design Notes

**Seeds** (`18436f8d`, 18.31's "For 18.33"; not re-probed): the lists are `[{MatchRole, TargetRoles}]` and `[{RoutineOrClass, Db, Type}]`; the rules refuse DW-2284's coercions and an absent role first; the area's pairs and the install database's READ wrote both and read `Config.Databases` (AD-8).

**Rule 31.** Reused: the role delta, `MatchRolesViolation`, the web grant branch, the generic `WEBAPP.MATCHROLES.*` sentences. Copied: the client role tabs, for DW-2278's reason (routed to 23.7). Not reused: `PathPort`'s read, other columns of an unrelated port.

**`,` and `:`** separate the classic page's stored `name:db:flag` entries (`PrivRoutine.cls` :221, :247-250, :339-344); the vendor store's matching form is an inference.

**Naming the privilege** is AD-10's form: the destructive treatment, `GRANT.PRIVILEGED`'s sentence, and the diff (a role grant's role; a routine's row, the roles among the unchanged rows).

**For the lead** (Rule 20, at the gate): AD-4, the routine `PUT` replaces a sent `MatchRoles` and empties an omitted `Routines`; AD-10, a grant through a routine; AD-56 (ii), the six deltas; AD-15 per Task 0; AD-8, no extra pair; and whether `AdminPort`'s `Config.Databases` read, no admin API call, wants a line.

**Ledger.** DW-2279: Task 9, C6. **Governing ADs:** AD-3, 4, 5, 8, 10, 14, 15, 16, 22, 34, 36, 39, 53, 55, 56, 58. **Consumed-by:** 18.12. **Consumes:** 18.31, 9.2, 8.x (`FormRules.Roles`, `MatchRolesViolation`), 18.30. **Integration ACs:** the Integration line.

## Verification

**Shared surfaces:** `RoutineAppList`'s row actions and the undrawn roster; `RoutineAppUpdate`'s schema and settable fields; the kernel's routine change fields; `PRIVROUTINE` codes; the routine form read; the Doc DB mints' wording; Fixed strings.

**Standing criterion:** every test added or changed passes on a fresh environment, in either order.

**Commands:**

- `(loop)` `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/carry-2026-10-08/epic-18-d8/load-ocupilot-ci.sh` -- expected `LOAD-OK` and `STARTPATH-OK`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one at a time, totals from `%UnitTest_Result`: Task 12's classes, `RoutineAppWrite`, `DocDbAppWrite`, `WebAppSave`, and each class the sweep changes.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`; `uv run scripts/check-objectscript.py`.
- `(loop)` With `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, then `node --test --test-concurrency=1 browser/routine-applications.browser-spec.mjs` and any spec the sweep changes. Bundle vs the 3326kB warning: re-base under DW-1166 if crossed; stop and ask above 3800kB.
- Full ObjectScript sweep: the runner's; browser suite: CI's.

**Mutations (Rule 19),** each recorded as `mutation:`, none writing the own two: C1 `FormRead` adds nothing; C2 the routine delta answers `##super`, then `Routines` leaves `SettableFields`; C3 `RoutinesViolation` accepts any `Db`; C4 the client rule answers `''` (the kernel arm only through `Prohibits`); C5 drop `AddsRoutineUnderPrivilege`, then the web delegation; C6 drop a row action, then `SaveFields`, then a `MintClass`.

**S0:** no `OcuProbe1831*` or `OcuProbe1833*` application, role, resource or user; `OcuPilotState` and `OcuPilotIdentity` type 4 and enabled, as Task 0 recorded them.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
