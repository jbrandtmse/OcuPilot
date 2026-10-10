---
title: 'Story 18.31: Privileged routine applications'
type: 'feature'
created: '2026-10-10'
status: 'ready-for-dev'
baseline_commit: 'bb49cd147447d4dbade1191a14f16c3c0cb1d490'
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

**Approach:** A Web applications list at position 5. An unlisted editor with the classic page's General tab. Four tools: `webapp.routineapps.read`, `.create`, `.update` and `.delete`, over `Description`, `Enabled` and `Resource`. The update resends the freshly read roles and routines, because the vendor empties routines it isn't sent. OcuPilot's own two are refused by Story 18.10's arm, extended to the new type. The Application roles, Matching roles and Routines tabs, the database list and the `%All` grant check are Story 18.33's (orchestrator ruling on this story's first plan, 2026-10-10: split for size, Rule 5).

## Boundaries & Constraints

**Always:**

- The id is the name, `foldcase`; a create sends it as typed.
- An update merges the complete set over a fresh `GET` (AD-4). General's Save sends `Description`, `Enabled` and `Resource`.
- Keys: create and update `true`, delete `false` (AD-22).
- Every Rules row is refused before any `PUT` (AD-39).

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
| Delete | A probe | Gone; the name is typed to confirm | 404 `PORT.NOTFOUND` |
| Rules | `Name` empty or over 64; `Description` over 256; `Enabled` not one of its six forms; `Resource` neither empty nor a listed `Service`, `System` or `Application` resource; a wrong shape | 422 `PRIVROUTINE.*` on the field; nothing sent | The mint refuses the same way |
| Own two | Any write, by any path | 403 `PROHIBITED.OCUPILOTROUTINEAPP`; controls `aria-disabled` | Nothing sent |
| Web app | A routine tool naming `/csp/user` | 404 `PRIVROUTINE.TYPE` from the fresh read | Nothing sent |
| DW-2252 | `WebApp.App` `PUT` or `DELETE` naming a routine app | 409 `PRIVROUTINE.WEBAPP`, unlogged, before the vendor | Today: 500 #799, and `DELETE` deletes it |

</intent-contract>

## Code Map

Paths are under `src/OcuPilot/` unless they start with `ui/`. **Analog: Story 18.30** (`git show 05b99fd1 c494cfe5`): each roster it edits has a counterpart here.

- **Tools.** `Screen/Tool/RoutineAppCreate`, `RoutineAppUpdate` and `RoutineAppDelete` extend the `DocDbApp*` tools, overriding the tool, descriptor, `PORTCLASS` (`AdminPort`), `RULES`, `CLASSICPAGES`, `Endpoint`, `MintClass` (the kernel's `Mint`), `InputSchema` (no `Namespace`) and `RefusedBeforeState`; the create also `TypedId` and `ArgumentProblem`.
- **Rules and Save.** `Area/WebApp/RoutineAppRules` and `RoutineAppSave` extend Doc DB's, whose new `ERRORCLASS` (default `OcuPilot.Api.DocDbAppError`) and `NAMESPACED` (default 1; 0 drops `Namespace`, its rule and the composite join) leave Doc DB unchanged.
- `Api/RoutineAppError`, `RoutineAppList`, `RoutineAppForm` and `Test/RoutineAppProbe` take their Doc DB siblings' shapes; the `rowGet` is `LdapConfigList` :68's.
- `ui/src/app/areas/web-applications/routine-app-form.page.ts`, `.store.ts` and `routine-app-actions.ts` copy the Doc DB form without `Namespace`: no form base exists (DW-2278).
- `Mint.Merge` :550 sends the whole fresh read, so the update resends `MatchRoles` and `Routines`.

## Tasks & Acceptance

**Task 0** (`ocupilot-ci`, after `LOAD-OK` and `STARTPATH-OK`): record S0; halt on a contradiction with Design Notes.

**Execution:**

1. `routine-application`, `foldcase`, beside `docdb-application` in `Kernel/EntityType.cls`, `Kernel/EntityRef.cls` and `ui/src/app/core/entity-ref.ts`.
2. **DW-2262.** `Api/RoutineAppError.cls`: `PRIVROUTINE.VALIDATION`, `.NAME`, `.DESCRIPTION`, `.ENABLED`, `.RESOURCE`, `.TAKEN`, `.WEBAPP`, and `.TYPE` moved unchanged from `Api/PctAccessError.cls` :2, :49-55 and :67. Repoint `AdminPort` :1972, :1985-1986 and `Api/Error.cls` :1239, :1450.
3. **DW-2252.** `Port/AdminPort.cls`: `Security.PrivilegedRoutine/PUT` and `/DELETE` join `MUTATINGTYPES` :484, `/DELETE` `BODYLESSTYPES` :500 (and `Test/PortFixture.cls` :21). :1257 also calls `PrivilegedRoutineGuard` :1975 for `WebApp.App`: a `PUT` or `DELETE` on a `KeptType` with bit 4 answers 409 `PRIVROUTINE.WEBAPP`, unlogged.
4. `Kernel/Proposal/Prohibited.cls`, add-only (Epic 20 edits it): `TYPEROUTINEAPPLICATION` beside :596 and in :259 and :1327; the lists beside :1124 and :1244 answer `DocDbApplicationFields()`; after :1403, refuse `OCUPILOTROUTINEAPP` for the type when `OwnRoutineApplication(tId)`; `ReviewedFewOnly` beside :1606.
5. `Screen/Descriptor/RoutineAppList`: `web-applications/routine-applications`, position 5, list, instance, id `Name`, the area's pairs, create, and delete with `selfProtection` `ocupilot-routine-application`; `LIST` with `rowGet {key: Name, param: name, fields: [Enabled, Description]}`; columns `Name`, `Enabled`, `Resource`, `Description`; `.PrivRoutineList`; three prompts; `webapp.routineapps`. `RoutineAppForm`: `.../edit`, 0, form-page, `.PrivRoutine`, three prompts, `webapp.routineappform`.
6. Rule `ocupilot-routine-application`, a `Name` of `OcuPilotState` or `OcuPilotIdentity` in any case, sentence `routineAppRefusalOcuPilot` (exists): `Screen/Registry.cls` :2967, `ui/tools/screen-mirror.mjs` :315, `ui/src/app/core/self-protection.ts`; `self-protection.test.mjs` pins the names to `Kernel/State/Base`.
7. `Screen/Tool/RoutineApp*` (`%Admin_Secure:USE`, `PERMITTEDFIELDS` `Description,Enabled,Resource`): create and update declare `CLASSICPAGES` `%CSP.UI.Portal.Applications.PrivRoutine`; the create's `ArgumentProblem` adds `Taken` (`PRIVROUTINE.TAKEN`); the delete's `READANSWERS` and `FINGERPRINTSUBJECT` name all five fields.
8. `Area/WebApp/RoutineAppRules` overrides `IsName` (non-empty, at most 64 characters) and `Taken` (an object, or a 404 carrying `PRIVROUTINE.TYPE`).
9. `Api/Router.cls`, beside Doc DB's: `GET /routine-application/form`, `PUT /routine-application/:id`, `POST /routine-application`. `Screen/Tool/Classification.cls` beside :685: `webapp.routineapps.create` and `.update`, three `ordinary` settings, `MatchRoles` and `Routines` unnamed as in `webapp.list.update`; then `bash scripts/field-lists.sh`. `Kernel/Governance/Baseline.cls`: `true`, `true`, `false`.
10. Client: the Code Map's form (`Name` on create only); on the own two, Save is `aria-disabled` with the rule's sentence. Wire it beside Doc DB's in `ui/src/app/`: `shell/screen-outlet.ts`, `shell/screen-action-handler.ts` (`routineAppDeleteConsequence`, `{name: 'Name'}`) and `app.ts`, sign-out reset included; run `node tools/screen-mirror.mjs`.
11. `ui/src/app/core/strings.ts` add-only, cited `/** EXPERIENCE.md:NNN */`; EXPERIENCE.md :167 and :357 in place, `[ADDED 2026-10-10 - Story 18.31]`. 3000 of 3400 used; stop past 3350.
12. **DW-2279**, only if `grep -c PARENTDESCRIPTION src/OcuPilot/Screen/Tool/MappingMint.cls` is non-zero here: add `Screen/Tool/DocDbAppMint`, extending `MappingMint` with Doc DB wording in its three description parameters; name it in the `DocDbApp*` tools' `MintClass`; add a `DocDbAppWrite` leg. Otherwise change nothing and say so in Auto Run Result.

**Tests** (prefix `OcuProbe1831`; `OCUPILOT_ALLOW_PRINCIPALS` arms all but the descriptor class; `OnAfterOneTest` runs `RoutineAppProbe.RemoveAll`):

13. `Test/RoutineAppDescriptor`: declarations, classification, baseline, codes. `RoutineAppRead`: rows against the raw `GET`, the form read, absent 404. `RoutineAppWrite`: this story's matrix rows, both callers and the wire; the own two through `Prohibits`, as `OwnRoutineApplication.Ask`. `RoutineAppGate`: exactly `%Admin_Secure:USE`, `%DB_IRISSYS:READ` and the install database's READ allow everything; without the first, each is refused by name before any port call.
14. Page, store and actions specs. `ui/browser/routine-applications.browser-spec.mjs`: from the side bar, wait for `OcuPilotState`'s row (Delete `aria-disabled`); create, change and typed-name delete a probe; an after hook runs `RemoveAll`.
15. **Rule 30 sweep**, as 18.30 did:
    - entity types 64 to 65: `Test/Descriptor`, `SuperserverDescriptor`, `MftConnectionDescriptor`;
    - `ReadTool` (327 to 331), `SurfaceCoverage`, `EndpointCoverage`, `ToolRoundTrip`, `Governance`, `ToolDispatch`, `GovernanceBaseline`, `ClassicPageGate`, `MappingDescriptor`, `Test/Prohibited`, a `SaveHoldCoverage` leg; `ScreenRead`, `ToolWrite`, `PortGate`, `ProhibitedRoute`, `RefusalCopy` and `field-lists.test.mjs` only if red;
    - `Wire`, `WireSecurityRead`, `WebSessionsLive`, `navigation.test.mjs`, `side-bar-pins.test.mjs`, `screen-mirror.test.mjs`, `ci-throwaway.sh`'s arming roster;
    - `WebAppPctAccess` :170 reads `RoutineAppError`; `OwnRoutineApplication` drops "501" from :7-9, :291 and :302 and does not re-run its endpoint `DELETE` mutation.

**Acceptance Criteria:**

- **C1.** Given the list and `webapp.routineapps.read`, when each reads, then both answer one read's rows with each row's `GET` `Enabled` and `Description`; the form read answers the name and three settings.
- **C2.** Given probes, when either caller runs the matrix's Create, Update, Delete, Rules, Web app and DW-2252 rows, then each answers as the matrix says, a refusal sends nothing, read-backs `match` (absent after a delete), and a change keeps a probe's role and routine (AD-4).
- **C3.** Given `OcuPilotState` or `OcuPilotIdentity`, when the list, the editor, the mint or the confirm targets it, then it answers 403 `PROHIBITED.OCUPILOTROUTINEAPP`, nothing changes, and Delete and Save are `aria-disabled` with that sentence.
- **C4.** Given the rosters, when the suites run, then position 5, keys `true`/`true`/`false`, `routine-application` `foldcase` on both sides, `PRIVROUTINE.TYPE` from `RoutineAppError` (DW-2262) and the strings bound hold.
- **Integration.** Given `ocupilot-ci`, when the page and the agent act, then the page consumes the three routes and the delete action, and the agent the four tools (C1-C3, the browser spec).

## Spec Change Log

- 2026-10-10, spec gate (lead): DW-2279 re-owned to 18.33, because 20.3 is not on feature (Task 12 stays unbuilt here); AD-2, AD-13, AD-44 and AD-54 amended.

- 2026-10-10, spec gate (lead): the intent was trimmed of 18.33's half (the Deltas row, the role and routine Rules clauses, and the tab-delta and `MatchRoles`-grant Always bullets), matching the split ruling.

- 2026-10-10, lead: the orchestrator ruled to split for size. 18.31 keeps the list, the General tab and the four tools over `Description`, `Enabled` and `Resource`, plus DW-2252, DW-2262 and DW-2279 (conditional on 20.3). The roles, matching roles and routines tabs, the database list and C6 move to 18.33, whose plan is seeded from this spec's first version (commit `18436f8d`). The status is reset to `draft` for a re-plan.

## Review Triage Log

## Design Notes

**Scope.** 18.33 builds the role, matching-role and routine deltas, their rules, the database list and the `MatchRoles` grant check; this story builds none of them.

**Measured** (`ocupilot-ci`; the first plan, `18436f8d`, seeds 18.33; the epic context has the rest):

- `LIST` answers no `Description`; a `GET` body sent back changes nothing. `PUT` keeps the name as typed, and a three-setting create answered 201 with both lists empty (this re-plan). A name over 64 or a description over 256 is 500 #7201.
- For 18.33: a sent `MatchRoles` replaces the list; any `Type` but `Routine` stores `Class` and an empty entry is dropped (vendor candidates, owner hold); no `Type` is 400 #40301; `%DB_HSCUSTOM:R` reads `Config.Databases`.

**For the lead.** DW-2283: `OwnRoutineApplicationWire` settles the own two, DW-2252's `DELETE` leg the rest. The monitor state read 1 before the probe; S0 omits it (epic context).

**Ledger.** DW-2252: Task 3, C2. DW-2262: Task 2, C4. DW-2279: Task 12, which the lead re-owns while 20.3 is off feature, as now.

**Governing ADs:** AD-2 (now `WebApp.App` writes), 3, 4, 5, 6, 8, 10, 13 (`routine-application`, `foldcase`), 14, 15, 22, 27, 34, 36, 39, 44 (`.PrivRoutine`), 52, 53, 54 (`TypedId` on a single-part id), 55, 58, 59; the noted ones want spine lines at the gate (Rule 20). **Consumed-by:** 18.33 (its tabs extend these tools and form; it may re-parent the update onto `WebAppUpdate`), 18.12. **Consumes:** 18.10, 18.30, 8.x (`ResourceList`). **Integration ACs:** the Integration line, `RoutineAppWrite`, the browser spec.

## Verification

**Shared surfaces:** Web applications side bar and lists, entity types, tool, route, key and classic-page rosters, self-protection rules, `PRIVROUTINE.TYPE`'s home, Doc DB's Rules and Save, 18.10's tests, Fixed strings.

**Standing criterion:** *existing tests that assert a surface this story changes are updated in this story, and every test the story adds or changes passes on a freshly built instance and in either order.*

**Commands:**

- `(loop)` `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/carry-2026-10-08/epic-18-d8/load-ocupilot-ci.sh` -- expected `LOAD-OK` and `STARTPATH-OK`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one at a time, totals from `%UnitTest_Result`: the new classes, Task 15's, the four `DocDbApp*`, both `OwnRoutineApplication*` and `WebAppPctAccess`.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`; `uv run scripts/check-objectscript.py`.
- `(loop)` With `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, then `node --test --test-concurrency=1 browser/routine-applications.browser-spec.mjs` and Task 15's specs.
- `(once, before dev_complete)` The full ObjectScript sweep, one class at a time; `cd ui && npm test && npm run build`, the bundle against 3,213,418 bytes and the 3326kB warning (DW-1166); `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS`; S0.

**Mutations (Rule 19),** each recorded as `mutation:`, none writing the own two: C1 drop `rowGet`; C2 drop, each alone, the absence fingerprint, one rule, the `Routines` resend and the guard's `WebApp.App` branch; C3 drop the kernel branch (asked through `Prohibits`; the port arm stays), then the client rule; C4 the delete's key `true`.

**S0:** no `OcuProbe1831*` application, role or user; the own two as Task 0 recorded them.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Re-planned to the split; one probe; S0 held.
