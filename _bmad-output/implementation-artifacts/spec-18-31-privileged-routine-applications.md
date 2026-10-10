---
title: 'Story 18.31: Privileged routine applications'
type: 'feature'
created: '2026-10-10'
status: 'blocked'
baseline_commit: 'd4be0dc200f1df903669dd692e3533e00bdf8529'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Privileged routine applications are `Security.Applications` type 4, behind the classic `%CSP.UI.Portal.Applications.PrivRoutineList` and `.PrivRoutine` pages, gated by `%Admin_Secure`. They are classic-only: `AdminPort` answers `Security.PrivilegedRoutine` writes 501, and a web-application write naming one fails as a logged 500 (DW-2252).

**Approach:** A Web applications list at position 5. An unlisted editor with the classic page's tabs: General, Application roles, Matching roles, and Routines and classes. Four tools, `webapp.routineapps.read`, `.create`, `.update` and `.delete`. OcuPilot's own two are refused by Story 18.10's arm, extended to the new type.

## Boundaries & Constraints

**Always:**

- The id is the name, `foldcase`; a create sends it as typed.
- An update merges the complete set over a fresh `GET` (AD-4). General's Save sends `Description`, `Enabled` and `Resource`. The role and routine tabs act only through the update tool's screen actions, each a delta over the fresh read (AD-56 (ii)).
- Keys: create and update `true`, delete `false` (AD-22).
- Every Rules row is refused before any `PUT` (AD-39).
- A `MatchRoles` grant of `%All` or an `%Admin_*` role is minted destructive (AD-10).

**Never:**

- Add an AD-10 code or predicate. Reuse `Prohibited.OwnRoutineApplication`, `RefusesBeforeState` and `RoutineEndpointRefused` (Rule 31).
- Write `OcuPilotState` or `OcuPilotIdentity`, even under a mutation.
- Change `WebApp.App` `GET` or the Web applications list.
- Touch `MappingMint` outside Task 12.
- Build on an owner-hold entry.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Read | List or read tool | One read's rows, with `Enabled` and `Description` from each row's `GET` | Missing pair: 403 |
| Create | `OcuProbe1831A` | 201, stored as typed (either caller) | Name any application holds: `PRIVROUTINE.TAKEN` |
| Update | A setting | The complete set, with lists as freshly read | 404; 409 `WRITE.TARGETBUSY` |
| Deltas | Add or remove an application role, a matching role, or a routine `{RoutineOrClass, Db, Type}` | Applied over the fresh read | Absent role, duplicate, or not held: refused |
| Delete | A probe | Gone; the name is typed to confirm | 404 `PORT.NOTFOUND` |
| Rules | `Name` empty or over 64; `Description` over 256; `Enabled` not one of its six forms; `Resource` neither empty nor a listed `Service`, `System` or `Application` resource; a role entry with no targets or naming an absent role; a routine entry with an empty name, an undefined `Db`, or a `Type` other than `Routine` or `Class`; a wrong shape | 422 `PRIVROUTINE.*` on the field; nothing sent | The mint refuses the same way |
| Own two | Any write, by any path | 403 `PROHIBITED.OCUPILOTROUTINEAPP`; controls `aria-disabled` | Nothing sent |
| Web app | A routine tool naming `/csp/user` | 404 `PRIVROUTINE.TYPE` from the fresh read | Nothing sent |
| DW-2252 | `WebApp.App` `PUT` or `DELETE` naming a routine app | 409 `PRIVROUTINE.WEBAPP`, unlogged, before the vendor | Today: 500 #799, and `DELETE` deletes it |

</intent-contract>

## Code Map

Paths are under `src/OcuPilot/` unless they start with `ui/`. **Analog: Story 18.30** (`git show 05b99fd1 c494cfe5`): every roster it edits has a counterpart here.

**Siblings (Rule 31):**

- `Screen/Tool/RoutineAppUpdate` extends `WebAppUpdate`, keeping `MatchRoles`, the role actions and `ScreenActionDelta` (:259).
- `RoutineAppCreate` and `RoutineAppDelete` extend their `DocDbApp*` counterparts, overriding `PORTCLASS` (`AdminPort`), `MintClass` (the default mint), `TypedId`, `ArgumentProblem` and `Described`.
- `Area/WebApp/RoutineAppRules` and `RoutineAppSave` extend `DocDbAppRules` and `DocDbAppSave`, overriding only the members bound to Doc DB's composite id or fields.
- `Api/RoutineAppError`, the `RoutineAppList` and `RoutineAppForm` descriptors and `Test/RoutineAppProbe` take their Doc DB siblings' shapes.

**Client:** `ui/src/app/areas/web-applications/routine-app-form.page.ts`, `.store.ts` and `routine-app-actions.ts`. General copies the Doc DB form and imports its constants. The role tabs copy `web-app-editor.page.ts` :334-457: no tab component exists, and DW-2278 owns the shared base.

**No new port:** `AdminRoutes` :188-189 and `FieldLists` :534 exist.

## Tasks & Acceptance

**Task 0** (`ocupilot-ci`, after `LOAD-OK` and `STARTPATH-OK`): record S0; halt on a contradiction with Design Notes.

**Execution:**

1. **Entity type.** `Kernel/EntityType.cls` :102 adds `routine-application`, and `Kernel/EntityRef.cls` :59 adds `routine-application:foldcase`.
2. **Codes (DW-2262).** New `Api/RoutineAppError.cls` holds `PRIVROUTINE.VALIDATION`, `.NAME`, `.DESCRIPTION`, `.ENABLED`, `.RESOURCE`, `.ROLES`, `.ROUTINES`, `.TAKEN` and `.WEBAPP`. `PRIVROUTINE.TYPE` and its sentence move there unchanged from `Api/PctAccessError.cls` :2, :51-55 and :67. Repoint `AdminPort` :1972 and :1985-1986, and `Api/Error.cls` :1239 and :1450.
3. **`Port/AdminPort.cls` (DW-2252):**
   - `MUTATINGTYPES` :484 adds `Security.PrivilegedRoutine/PUT` and `/DELETE`; `BODYLESSTYPES` :500 adds `/DELETE`; mirror both in `Test/PortFixture.cls` :21.
   - `PrivilegedRoutineGuard` :1975 takes the endpoint. For a `WebApp.App` `PUT` or `DELETE` whose `KeptType` has bit 4, it answers 409 `PRIVROUTINE.WEBAPP`, unlogged. The branch at :1257 calls it for both endpoints.
   - Add `DatabaseDefined` and `DatabaseNames` beside `NamespaceDefined` :2936, reading `Config.Databases` in `%SYS`.
4. **`Kernel/Proposal/Prohibited.cls`**, add-only, because Epic 20 edits it too:
   - `TYPEROUTINEAPPLICATION` beside :596, also in `COVEREDTYPES` :259 and the chain :1327.
   - A private `RoutineApplicationFields` supplies the fields beside :1124 (five) and :1244 (three).
   - After :1400, a branch refusing `OCUPILOTROUTINEAPP` when `OwnRoutineApplication(tId)` holds; a `ReviewedFewOnly` branch beside :1606.
   - One line before :4463 hands the type to the web application's `MatchRoles` privilege check.
5. **Descriptors.**
   - `RoutineAppList`:
     - `web-applications/routine-applications`, position 5, `list`, `instance`, the area's pairs, `create`.
     - `rowActions` `delete`, the four role actions, `add-routine` and `remove-routine`, all with `selfProtection` `ocupilot-routine-application`.
     - Read: `LIST`, `rowGet` `{key: Name, param: name, fields: [Enabled, Description]}`. Columns: `Name`, `Enabled`, `Resource`, `Description`.
     - Classic page `.PrivRoutineList`; three prompts; `webapp.routineapps`.
   - `RoutineAppForm`: `.../edit`, 0, `form-page`, classic page `.PrivRoutine`, three prompts, `webapp.routineappform`.
6. **Rule `ocupilot-routine-application`.** Add it to `Screen/Registry.cls` :2967, `ui/tools/screen-mirror.mjs` :315 and `core/self-protection.ts`. `self-protection.test.mjs` pins its names to `Kernel/State/Base`'s `APPLICATION` and `IDENTITYAPPLICATION`. Its sentence is `routineAppRefusalOcuPilot`.
7. **Tools** (`RoutineAppList`, `%Admin_Secure:USE`):
   - Create: the three settings, `CLASSICPAGES` `.PrivRoutine`, and `ArgumentProblem` adds `Taken`.
   - Update:
     - `PERMITTEDFIELDS` are the three settings, with the same `CLASSICPAGES`; `ArgumentProblem` calls `RoutineAppRules.Problem`.
     - `MatchRoles` and `Routines` are excluded from the derived fields and authored as complete lists.
     - `SCREENACTIONS` are the role actions, `add-routine=RoutineOrClass:Db:Type` and `remove-routine=RoutineOrClass:Db`.
     - `ScreenActionDelta` handles the routine actions and sends the rest to `##super`.
   - Delete: `READANSWERS` and `FINGERPRINTSUBJECT` hold all five fields, and `RefusedBeforeState` calls `Prohibited.RefusesBeforeState`.
8. **`RoutineAppRules`.**
   - `Check` and `RoutineEntryProblem`, which the delta shares.
   - `Taken` answers true for an object, or for a 404 carrying `PRIVROUTINE.TYPE`.
   - `HandleForm` answers `{row, roles, databases}`, taking roles from `FormRules.Roles` :405.
   - `RenderViolations` and `DefaultRow`.
   - `RoutineAppSave` answers 400 `PORT.FIELDUNEXPECTED` to a body carrying `MatchRoles` or `Routines`.
9. **Wiring.**
   - `Api/Router.cls`, beside :257-259: `GET /routine-application/form`, `PUT /routine-application/:id` and `POST /routine-application`, with their wrappers beside :1918.
   - `Classification.cls`, beside :685: two entries of three `ordinary` fields; then run `bash scripts/field-lists.sh`.
   - `Baseline.cls`, beside :172: `true`, `true`, `false`.
10. **Client.**
    - A create shows General only. The Routines tab adds a routine through a database picker.
    - The tabs call `ScreenActionHandler.startFor`. On the own two, every control is `aria-disabled` with the rule's sentence.
    - Wire in: `shell/screen-outlet.ts` :245; `screen-action-handler.ts` :114, :482 (`routineAppDeleteConsequence`) and :564 (`{name: 'Name'}`); `app.ts` :60-61, :383-385 and :730.
    - Then run `node tools/screen-mirror.mjs`.
11. **Strings.** `strings.ts` is add-only, each string cited `/** EXPERIENCE.md:NNN */`. EXPERIENCE.md :167 and :357 are edited in place, `[ADDED 2026-10-10 - Story 18.31]`. The bound stays 3400; stop past 3350.
12. **DW-2279.** Only if `grep -c PARENTDESCRIPTION src/OcuPilot/Screen/Tool/MappingMint.cls` is non-zero here:
    - add `Screen/Tool/DocDbAppMint`, extending `MappingMint` with Doc DB wording in its three description parameters;
    - point the `DocDbApp*` tools' `MintClass` at it;
    - add a `DocDbAppWrite` leg.

    Otherwise, change nothing and say so in Auto Run Result.

**Tests** (armed by `OCUPILOT_ALLOW_PRINCIPALS` except the descriptor class; `OnAfterOneTest` runs `RoutineAppProbe.RemoveAll`; each class under 500 lines):

13. **ObjectScript.**
    - `RoutineAppDescriptor`.
    - `RoutineAppRead`: rows checked against the raw `GET`; the form read; 404 when absent.
    - `RoutineAppWrite` and `RoutineAppDelta`: the matrix, through both callers and over the wire. The kernel branch is asked through `Prohibits` (as `OwnRoutineApplication.Ask` asks); the privilege mark and DW-2252 are checked on a probe.
    - `RoutineAppGate`: exactly `%Admin_Secure:USE`, `%DB_IRISSYS:READ` and the install database's READ allow every operation. Without the first, each one is refused by name before any port call.
14. **Client.** Specs, plus `ui/browser/routine-applications.browser-spec.mjs`:
    - Open the list from the side bar and wait for `OcuPilotState`'s row, whose Delete is `aria-disabled`.
    - Give a probe an application role, a matching role and a routine; change its `Description`; delete it by typed name.
    - An after hook runs `RemoveAll`.
15. **Rule 30 sweep**, each change made as 18.30 made it:
    - Entity types go from 64 to 65: `Test/Descriptor.cls` :1763 (shape :179), `SuperserverDescriptor` :130, `MftConnectionDescriptor` :141. 20.3's type adds to these at the merge.
    - Tool and route rosters: `ReadTool` :93-94 (327 to 331); `SurfaceCoverage` :211 and :410; `EndpointCoverage` :269; `ToolRoundTrip` :84.
    - Governance: `Governance` :63 and :149; `ToolDispatch` :172; `GovernanceBaseline` :15 and :71.
    - Pages and types: `ClassicPageGate` :75 and :154; `MappingDescriptor` :24; `Test/Prohibited.cls` :232; one `SaveHoldCoverage` leg.
    - Area lists: `Wire` :534; `WireSecurityRead` :847, :998 and :1027; `WebSessionsLive` :290.
    - Client tools: `navigation.test.mjs` :254-264 and :601; `side-bar-pins.test.mjs` :36; `screen-mirror.test.mjs` :283; `ci-throwaway.sh` :388.
    - `ScreenRead` :220, only if it goes red.
    - Story 18.10's tests:
      - `WebAppPctAccess.cls` :170 reads `RoutineAppError`.
      - `OwnRoutineApplication.cls` drops "501" from its header (:8-9) and its mutation lines.
      - Its endpoint `DELETE` mutation is not re-run.

**Acceptance Criteria:**

- **C1.** Given the list and the read tool, when each reads, then both answer one read's rows with each row's `GET` `Enabled` and `Description`, and the form read answers the record with its roles and databases.
- **C2.** Given a probe, when either caller runs the matrix's Create, Update, Deltas and Delete rows on it, then each holds and its read-back `matches`, or reads absent after the delete.
- **C3.** Given a Rules row, when either caller sends it, then it is refused before any `PUT`.
- **C4.** Given `OcuPilotState` or `OcuPilotIdentity`, when the list, the editor, the mint or the confirm targets it, then the answer is 403 `PROHIBITED.OCUPILOTROUTINEAPP`, nothing changes, and Delete is drawn `aria-disabled` with that sentence.
- **C5.** Given a probe routine application, when `AdminPort` sends a `WebApp.App` `PUT` or `DELETE` naming it, then the answer is 409 `PRIVROUTINE.WEBAPP` and the application is unchanged (DW-2252).
- **C6.** Given a probe, when the agent proposes adding `%All` to its `MatchRoles`, then the proposal is destructive and names the privilege.
- **C7.** Given the rosters, when the suites run, then position 5, keys `true`/`true`/`false`, `routine-application` with `foldcase` on both sides, `PRIVROUTINE.TYPE` from `RoutineAppError` unchanged (DW-2262), and the strings bound all hold.
- **Integration.** On `ocupilot-ci`, the page consumes the three routes and the screen actions, and the agent the four tools (C1-C6 and the browser spec).

## Spec Change Log

## Review Triage Log

## Design Notes

**Measured at plan** (2026-10-10, `ocupilot-ci`; 18.10's `622b70eb` baseline holds):

- **Reads.**
  - `LIST` rows are `{Name, Namespace, NamespaceDefault, Enabled, Type, Resource, IsSystemApp, DispatchClass}`, with `Enabled` always false.
  - `GET` answers `{MatchRoles, Routines[{RoutineOrClass, Db, Type: Routine|Class}], Enabled, Resource, Description}`.
  - A `GET` body sent back with `PUT` changes nothing.
- **Names.** A create stores the name as typed (201). A lower-cased `PUT` keeps the stored spelling.
- **Writes.**
  - A sent `MatchRoles` replaces the list.
  - Any `Type` other than `Routine` is stored as `Class`; an omitted `Type` is 400 #40301.
  - An empty entry is dropped silently, and an absent `Db` is stored as given.
  - An absent match role is 500 #875; a name over 64 characters or a description over 256 is 500 #7201.
- **`WebApp.App`.** `LIST` omits routine apps and `GET` answers one with web defaults. `PUT` on one is 500 #799, and `DELETE` (200) deletes it.
- **Least privilege.** Holding exactly `%Admin_Secure:U` and `%DB_IRISSYS:R`, over HTTP it listed, created one with roles and routines, read roles and resources, round-tripped and deleted. With `%DB_HSCUSTOM:R` added it read `Config.Databases` in process (`Exists`, and a `List` of 14).
- **`AdminPort` in process.** `LIST` 200, a new `PUT` 501, and an `OcuPilotState` `PUT` 403. S0 held, with the monitor at 0.

**Decisions** (spine, at the gate):

- AD-13: `routine-application` is `foldcase`.
- AD-4: the complete set.
- AD-36: `rowGet`.
- AD-8: no pair beyond the area's.
- AD-44: create and update declare `.PrivRoutine`.
- AD-2: the type check covers `WebApp.App` writes; `GET` is unchanged, because 18.10's 403 on the web application Save follows it.
- AD-10: one predicate covers both types.
- AD-15: `ApplicationChange`.

**Rule 31.** Each override is bound to Doc DB's composite id or fields, and DW-2278 owns the base. `Prohibited` is contended, so its branch reuses the predicate.

**For the lead.** Vendor candidates, on owner hold and never reported:

- `WebApp.App` `DELETE` deletes a routine application.
- `PUT` reads any `Type` as `Class` and drops an empty entry silently.

**Ledger.** DW-2252 is Task 3 and C5; DW-2262 is Task 2 and C7; DW-2279 is Task 12, conditional, or else re-owned by the lead.

**Proposed split** (the lead numbers it; 18.33 is the burn-down):

- **18.31, narrowed.**
  - The list, the General editor and the three tools over the three settings; the update still sends the fresh `MatchRoles` and `Routines` (AD-4).
  - The entity type, the kernel branch, the self-protection rule and `MUTATINGTYPES`.
  - DW-2252, DW-2262 and DW-2279.
  - Tasks 1-6 and 9-15, without the delta parts.
- **New story.** The Application roles, Matching roles and Routines and classes tabs:
  - the update's `MatchRoles` and `Routines` arguments and the six delta actions (`WebAppUpdate`'s role delta, plus a routine delta);
  - the role and routine rules;
  - `DatabaseDefined` and `DatabaseNames`;
  - C6.
- **Alternative.** Waive the bound and dispatch this spec as written, which is complete for one story.

**Governing ADs:** AD-2, 3, 4, 5, 6, 8, 10, 13, 14, 15, 22, 27, 34, 36, 39, 44, 52, 53, 54, 55, 56, 58, 59. **Consumed-by:** 18.12. **Consumes:** 18.10, 18.30, 9.2 (`WebAppUpdate`), 8.x (`ResourceList`, `FormRules.Roles`).

## Verification

**Shared surfaces:** Web applications side bar and lists, entity types, tool, route, key and classic-page rosters, self-protection rules, the home of `PRIVROUTINE.TYPE`, 18.10's routine tests, and Fixed strings.

**Standing criterion:** *existing tests that assert a surface this story changes are updated in this story, and every test the story adds or changes passes on a freshly built instance and in either order.*

**Commands:**

- `(loop)` `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/carry-2026-10-08/epic-18-d8/load-ocupilot-ci.sh` -- expected `LOAD-OK` and `STARTPATH-OK`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one class at a time, totals read from `%UnitTest_Result`. Run the new classes, Task 15's, and `DocDbAppWrite`, `OwnRoutineApplication`, `OwnRoutineApplicationWire` and `WebAppPctAccess`.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`; `uv run scripts/check-objectscript.py`.
- `(loop)` With `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`, run `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, then `node --test --test-concurrency=1 browser/routine-applications.browser-spec.mjs` and Task 15's specs.
- `(once, before dev_complete)` The full ObjectScript sweep, one class at a time.
- `(once, before dev_complete)` `cd ui && npm test && npm run build`, then the bundle: 3,213,418 bytes at 18.30, warning at 3326kB (DW-1166).
- `(once, before dev_complete)` `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS`, then S0.

**Mutations (Rule 19).** Record each as `mutation:`.

- C1: drop `rowGet`.
- C2: drop the absence fingerprint, then the routine delta.
- C3: drop one rule.
- C4: drop the kernel branch, then the client rule.
- C5: drop the guard's `WebApp.App` branch.
- C6: drop the privilege line.
- C7: set delete to `true`.

**S0:** no `OcuProbe1831*` application, role or user; the own two as recorded; the monitor at 0.

## Auto Run Result

Status: blocked
Blocking condition: size: the plan is 18.4 KB after four trims, over the stage's 16 KB bound, and about 40% larger than Story 18.30, which filled one implement pass; the proposed split is under Design Notes (or the lead waives the bound and dispatches this spec as written)
