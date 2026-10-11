---
title: 'Story 18.33: Privileged routine application roles and routines'
type: 'feature'
created: '2026-10-11'
status: 'done'
baseline_revision: 'd76c76d9cee17c5358a191962e3768aa3026f2e0'
baseline_commit: 'd76c76d9cee17c5358a191962e3768aa3026f2e0'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred:
  - summary: >-
      `Prohibited.PermittedChangeFields` still names the routine application type in its Doc DB clause, which the new routine line above it makes unreachable; remove that term when Epic 20's open diff to the file has merged.
    evidence: |-
      Epic 20's committed Story 20.23 (6aa1f459) changes `Prohibited.cls`, so Rule 11 allowed this story lines added only; the old clause `(pType = ..#TYPEDOCDBAPPLICATION) || (pType = ..#TYPEROUTINEAPPLICATION)` is dead for the routine type.
    location: >-
      src/OcuPilot/Kernel/Proposal/Prohibited.cls:1146
    severity: low
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

### 2026-10-11 -- Review pass

- verdicts: 22 findings -- high 0, medium 4, low 15, false 3, maybe-false 0
- findings:
  - `[medium]` `[patch]` A list equal to the fresh read is never judged (`Judged`), and no test seeds a refused stored list -- added the stale-list legs to `RoutineAppMembers.TestEveryListRuleIsRefusedBeforeAnyPut`; mutation red.
  - `[medium]` `[patch]` The editor page's ChangeBus re-read is untested -- added a page spec (update re-reads, deletion and another application do not); mutation red.
  - `[medium]` `[patch]` The Routines tab's privilege caption for a privileged matching-role target is unpinned -- added the leg to the C5 page test; mutation red.
  - `[low]` `[patch]` A refused Save sent from another tab, opening General with its count, is unpinned -- added a page spec; the two switches cover each other, so the mutation drops both.
  - `[low]` `[patch]` The store spec's failed-read test cannot see `refresh`'s guards -- asserted reason, refusal code and absence, and added the late-read test; both mutations red.
  - `[medium]` `[patch]` The routine delta's refusal sentences and "echoing no value" are unasserted -- `RoutineAppMembers` asserts status, `TOOL.ARGUMENTS` and the exact sentence; sentence swap red.
  - `[low]` `[patch]` `DatabaseNames` ordering is unpinned (reported as defer) -- a case-insensitive order check in `RoutineAppRead`; reversal red.
  - `[low]` `[patch]` `DatabaseDefined` has no caller and no test -- Task 2 names it; an exact-name leg in `RoutineAppRead`; case-ignoring mutation red.
  - `[low]` `[patch]` A tautological half in the Save's description assertion -- reduced to the stored description.
  - `[low]` `[patch]` The equal-list mint refusal asserted a not-OK status alone -- asserts the "nothing would change" sentence.
  - `[low]` `[patch]` Two browser negatives could pass before the render or request landed -- the first waits for the Assign to enable, the second for network idle.
  - `[low]` `[reject]` Surrounding whitespace in a direct API caller's routine name is stored as sent -- the UI trims, the vendor's trimming is unknown, and a guard adds a rule no AC names.
  - `[low]` `[defer]` The routine type's old name in `PermittedChangeFields`' Doc DB clause is now unreachable -- Rule 11 allowed lines added only while Epic 20's 20.23 edits the file; recorded in `deferred:`.
  - `[false]` `[reject]` The spec's `## Auto Run Result` read `ready-for-dev` -- the Finalize step rewrites it.
  - `[low]` `[patch]` The client-specs mutation line named no spec -- it points at the four specs whose comments carry each mutation.
  - `[low]` `[patch]` The Integration AC had no mutation line -- added: a renamed `Role` sent by the tab turns the browser spec red.
  - `[low]` `[reject]` The Rules row names a 422 no caller emits for the list codes -- the Save refuses a list (400) and the actions answer 400, the codes ride the shared rule set and the mint's sentence; the fix is a spec edit.
  - `[low]` `[patch]` The Roles and Routines rows' `TOOL.ARGUMENTS` code was not asserted -- `RoutineAppMembers.Refusal` asserts it on every refused action.
  - `[low]` `[reject]` A person's privileged add is a caption, not a confirm -- by design: the Boundaries bullet gives a person's tab `privilegedGrantEffect` and the agent the destructive treatment.
  - `[low]` `[defer]` `Prohibited` routes the routine type ahead of the shared clause rather than splitting it -- the same root cause as the deferred dead term above.
  - `[false]` `[reject]` Tabs are for an edit and a create shows General alone -- Task 10 says so.
  - `[false]` `[reject]` `Judged` is behavior the intent does not state -- Task 4 states it and AD-4 needs it for a setting-only update.

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

- mutation: C1 `RoutineAppRules.FormRead` returns at once → `RoutineAppRead.TestTheFormReadCarriesTheListsTheRolesAndTheDatabases` and `TestTheFormReadAnswersTheNameAndThreeSettings` red (run 661); with only the row's lists skipped, the same two (run 660).
- mutation: C2 `RoutineAppUpdate.ScreenActionDelta` sends the routine actions to `##super` → `RoutineAppMembers.TestTheRoutineActionsApplyADeltaAndKeepTheRoles` red (run 662); its forwarded role delta sent to `##super` → `TestTheRoleActionsApplyADeltaAndKeepTheRoutines` red (run 675); `Routines` out of `SettableFields` → `RoutineAppMembers.TestTheAgentSendsEachListWhole`, `TestTheRoutineActionsApplyADeltaAndKeepTheRoles` and `RoutineAppDescriptor.TestTheToolsDeclareTheirKindPortPairsAndFields` red (runs 663, 664).
- mutation: C3 `RoutineAppRules.EntryValid` accepts any `Db` → `RoutineAppMembers.TestEveryListRuleIsRefusedBeforeAnyPut` and `TestTheRoutineActionsApplyADeltaAndKeepTheRoles` red (run 665); `RoutinesViolation` adding nothing → the same two (run 678); `Judged` answering 0 → the first alone, every row (run 677).
- mutation: C4 the client rule, `selfProtectionReason`'s `ocupilot-routine-application` branch answering `''` → `routine-app-member-tabs.spec.ts`, `routine-app-form.page.spec.ts` (both of its own-application tests) red, and with the bundle rebuilt and redeployed `routine-applications.browser-spec.mjs`'s first and third tests red on `aria-disabled` and the own-application sentence; no click was made, and the own two read as they did.
- mutation: C4 the kernel arm, the `routine-application` own-application arm of `Prohibited.Prohibits` dropped (one arm at a time; `RefusedBeforeState` and the port arm stay) → `RoutineAppMembers.TestTheOwnTwoAreRefusedByEachActionAndTheMint` red on its `Prohibits` legs alone (run 668); `RoutineAppUpdate.RefusedBeforeState` answering 0 → the same test red on the removes and the mint (the set still refuses the write; run 676); `S0` read after each.
- mutation: C5 `AddsRoutineUnderPrivilege` dropped → `RoutineAppGrant.TestARoutineAddedUnderAPrivilegedRoleIsAGrant` and `TestTheClassifierAnswersTheSameWhenAskedDirectly` red (run 666); the web delegation dropped → all three red (run 667); `IsPrivilegedRole` without the `%Admin_` prefix → all three red (run 679).
- mutation: C6 `add-routine` dropped from `RoutineAppList` → `RoutineAppDescriptor.TestTheListIsDeclaredAsTheSpecPlacesIt` red (run 669); from `RoutineAppUpdate.SCREENACTIONS` → `TestTheSixRowActionsAreTheUpdatesAndTheSaveAdmitsTheThreeSettings` red (run 680); `RoutineAppSave.SaveFields` answering `##super` → `RoutineAppMembers.TestTheGeneralSaveRefusesAListAndKeepsBoth` and that descriptor test red (runs 670, 671); `RoutineAppError.FieldOf` without the routines line → `TestTheCodesAnswerTheirSentences` and the same descriptor test red (run 681); `DocDbAppUpdate.MintClass` answering `MappingMint` → `DocDbAppDescriptor.TestTheMintNamesARecordInItsRefusals` and `TestTheToolsDeclareTheirKindPortPairsAndFields` red (run 672); `DocDbAppUpdate.PrivilegePairs` answering no pair → `RoutineAppGate.TestWithoutAPairTheRoleAndRoutineActionsAreRefusedByName` and the two inherited refusal tests red (run 673), `RoutineAppUpdate.SCREENACTIONS` emptied → its holder test and refusal test red (run 674).
- mutation: C6 `RoutineApplicationChangeFields` without the two lists (the three settings alone) → `RoutineAppWrite.TestTheOwnTwoApplicationsAreRefusedEveryWrite` red on its `Routines` and `MatchRoles` legs (run 686); its line in `PermittedChangeFields` dropped → `RoutineAppDescriptor.TestTheToolsDeclareTheirKindPortPairsAndFields` and three `RoutineAppMembers` tests red (runs 683 to 685).
- mutation: client specs, each reverted byte-identical: the store's `absorb` ignoring `row.MatchRoles`, `refresh` taking the fields always or never, the page's tab entry dropped or the strip drawn on a create, the tabs' `Role` sent under another name, `MatchRole` and `Role` swapped, `Type` sent as its label, the databases picker emptied, the privilege caption dropped or always drawn, `onApplied` without `refresh` or without the picker reset, the sink without `setRefusal` or reading again on a refusal, the name untrimmed, the database guard dropped, a body drawn for every tab, and the list's `UNDRAWN_ACTIONS` entry dropped → the spec carrying that mutation comment above its pinning test red each time (`routine-app-form.store.spec.ts`, `routine-app-form.page.spec.ts`, `routine-app-member-tabs.spec.ts`, `screen-action-handler.spec.ts`).
- mutation: C2 the routine delta's held and not-held sentences swapped → `RoutineAppMembers.TestTheRoutineActionsApplyADeltaAndKeepTheRoles` red on its three sentence legs (run 706); C3 `Judged` answering 1 for any sent list → `TestEveryListRuleIsRefusedBeforeAnyPut` red on its two stale-list legs (run 706).
- mutation: C1 `AdminPort.DatabaseNames` building its list in reverse and `DatabaseDefined` ignoring case → `RoutineAppRead.TestTheFormReadCarriesTheListsTheRolesAndTheDatabases` red on the order and exact-name legs (run 707).
- mutation: C2, C5 the page's ChangeBus subscription not refreshing → `routine-app-form.page.spec.ts` "another caller's change" red; `hasRoutineEffect` without the matching-role targets → its C5 test red; `refresh` not returning on a failed read → the store spec's failed-read test red; `refresh` without its `generation` guard → "a read that lands after the form has moved on" red; `afterRefusal`'s `tabToOpen` and `focusField`'s tab switch both dropped (each alone is covered by the other) → "a Save refused for a General field" red.
- mutation: Integration the tabs' `onAssignApplicationRole` sending `Name` for `Role`, bundle rebuilt and redeployed → `routine-applications.browser-spec.mjs`'s third test red on its first action assertion; reverted byte-identical, green again.

**S0:** no `OcuProbe1831*` or `OcuProbe1833*` application, role, resource or user; `OcuPilotState` and `OcuPilotIdentity` type 4 and enabled, as Task 0 recorded them.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** The routine application editor has Application roles, Matching roles, and Routines and classes tabs on an edit (General alone on a create), each add or remove one of the list's six row actions, a delta over the fresh read. The agent's `webapp.routineapps.update` sends `MatchRoles` and `Routines` whole; one rule set (`RoutineAppRules.Check`, new `PRIVROUTINE.ROUTINES`) judges both callers before any `PUT`, and General's Save refuses a list. A grant through a role, matching role or routine is destructive with `GRANT.PRIVILEGED` (`AddsRoutineUnderPrivilege`); OcuPilot's own two stay 403 on all six actions and every tab control is `aria-disabled`. DW-2279: `DocDbAppMint` names the record in the three Doc DB tools' refusals. No tool, route, governance key, entity type or `PROHIBITED.*` code was added.

**Files.** Server: `Api/RoutineAppError`, `Area/WebApp/{Create,DocDbAppRules,DocDbAppSave,RoutineAppRules,RoutineAppSave}`, `Kernel/Proposal/Prohibited` (lines added), `Port/AdminPort` (`DatabaseNames`, `DatabaseDefined`), `Screen/Descriptor/RoutineAppList`, `Screen/Tool/{RoutineAppUpdate,DocDbAppMint,DocDbAppCreate,DocDbAppUpdate,DocDbAppDelete}`. Client: the form store and page, `routine-app-member-tabs.ts`, `screen-action-handler.ts`, `strings.ts`, `screens.generated.ts`, EXPERIENCE.md :357. Tests: `RoutineAppMembers` and `RoutineAppGrant` (new, in `scripts/ci-throwaway.sh`'s roster), `RoutineAppProbe`, `RoutineAppRead`, `RoutineAppGate`, `RoutineAppDescriptor`, `RoutineAppWrite`, `DocDbAppDescriptor`, five client specs and the browser spec's third test.

**Review.** 22 findings: 4 medium and 10 low patched (tests, a test helper and spec lines only; no source file changed in the patch pass), 2 deferred as one item (the dead routine term in `Prohibited`'s Doc DB clause, Rule 11), 6 rejected with reasons in the log. `followup_review_recommended` false: every patched medium was a missing pin, closed by a test whose mutation was observed red.

**Verification** (`ocupilot-ci`, src reloaded after the patch pass): `RoutineAppMembers` 6 (run 708), `RoutineAppRead` 4 (run 709); before the patches, `RoutineAppGrant` 3, `RoutineAppGate` 5, `RoutineAppDescriptor` 13, `DocDbAppDescriptor` 11, `RoutineAppWrite` 15, `DocDbAppWrite` 11, `WebAppSave` 7, `ToolEmit` 11 (runs 695 to 703); the implement pass's Rule 30 sweep of 29 classes (runs 631 to 659) was green. `check-objectscript` 0 problems; `test:tools` 1908; `test:components` 227 files, 2868 tests; the browser spec 3 of 3 on a rebuilt, redeployed bundle (3.31 MB initial, under the 3326kB warning, `angular.json` unchanged). Fixed strings 3126 to 3130 (bound 3400). S0 holds: no `OcuProbe18*` role, resource, user or application, and the own two read as before.

**Task 0 (AD-15).** A list-only `PUT` on a probe privileged routine application records `%System/%Security/ApplicationChange` ("Modify Application <name>", the data naming the `MatchRoles` and `Routines` changes), so the case is audited, not a named gap.

**Residual.** Each applied row action reads the form twice (the tabs' `applied` and the page's change-bus subscription). `ci-timings.json` has no rows for the two new classes. The deferred item waits on Epic 20's merge.
