---
title: 'Story 18.10: Web application extras and spec-based REST services'
type: 'feature'
created: '2026-10-08'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['multiple-goals', 'oversized']
deferred:
  - summary: >-
      The web-application tools can reach OcuPilot's own privileged routine applications, and no prohibited arm refuses them.
    evidence: |-
      On ocupilot-ci, Prohibited.Prohibits answered 0 for webapp.list.delete on OcuPilotState and for webapp.list.update setting its MatchRoles to :%All. WebApp.App GET, PUT and DELETE reach any application type (vendor source). The delete's mint refuses only because the GET answers no NameSpace (WebAppDelete.StateDiff); whether the update's mint and the editor's Save reach it is unmeasured (inference).
    location: >- # file:line
      src/OcuPilot/Kernel/Proposal/Prohibited.cls:5181
    severity: high (unverified)
---

<intent-contract>

## Intent

**Problem:** The web application editor has no `%`-class access list, which the classic page offers. And OcuPilot's own privileged routine applications, `OcuPilotState` and `OcuPilotIdentity`, are reachable by the web application tools with no AD-10 arm refusing a delete or a `MatchRoles` change (DW-2239, measured at this story's first plan). The vendor's privileged-routine endpoint also writes any application type.

**Approach:** This follows the orchestrator's 2026-10-09 rulings Q1 and Q4 on this story's first plan. Two parts:

- The `%`-class access list on the web application editor, read and changed through the admin API.
- An AD-10 arm refusing a delete of OcuPilot's own two privileged routine applications, disabling either, and any change to their `MatchRoles` or `Roles`, through every path that reaches them, including the vendor's privileged-routine endpoint. It sits in the family of the existing arms for OcuPilot's own web applications (`PROHIBITED.PRIVILEGEGRANT`, and deleting OcuPilot's own web applications). A target-type check goes wherever OcuPilot reaches that endpoint. A Rule 19 test proves each arm reddens under its mutation, and AD-10 is amended at this story's spec gate.

Doc DB applications (18.30), privileged routine applications (18.31) and spec-based REST services (18.32) are split out.

## Boundaries & Constraints

**Always:** The measurements in Design Notes are this story's baseline and the split stories' Task 0 baseline; re-measure only what they leave open. Under ruling Q3 (2026-10-09), the Fixed-strings bound becomes 3400 in the first code head that needs it, with a comment line in `strings.test.mjs` naming the ruling; a merge takes the higher value.

**Never:** Build Doc DB applications, the privileged routine application screens and tools, or spec-based REST services here. Build on DW-2084 or any other owner-hold entry.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| OcuPilot's own privileged routine application | A delete of `OcuPilotState` or `OcuPilotIdentity`, disabling either, or a change to its `MatchRoles` or `Roles`, through any path | Refused by the AD-10 arm; nothing sent | Today: `Prohibits` answers 0 |
| Privileged-routine write to a web application | `PUT` or `DELETE` on `Security.PrivilegedRoutine` naming `/csp/...` | Refused by the type check; nothing sent | Vendor: changes the application then answers 500, or deletes it |
| %-class access field shape | A class without a leading `%`, a type other than `AllowClass` or `AllowPrefix`, or an absent application | Refused on its field | Vendor: 500 #1498, #1496 or #869, each logged at severity 2 |

</intent-contract>

## Code Map

Paths are under `src/OcuPilot/` unless they start with `ui/`.

- `Kernel/Proposal/Prohibited.cls`: `Prohibits` :1284, `Target()` :1365, `Changed()` :1395, `Codes()` :927.
- `Port/AdminPort.cls`: guards :1214-1312; `EndpointType` :1244 (501 outside `MUTATINGTYPES`); `KeptType` :1947.
- Models: `SuperserverPort`, `MftPort`, `SuperserverMint`, `DocDbSave`, `SqlAdminPrivilegeList`, `sql-privileges-tab.ts`, `docdb-create-dialog.ts`, `ProhibitedRoute` :596.
- Editor tabs: `ui/src/app/areas/web-applications/web-app-editor.store.ts:23-29`, `.page.ts:658-667`. Classic tab 5 draws no Delete on a system row.

## Tasks & Acceptance

**Execution** (Tasks 1 and 3 are DW-2239):

1. `Kernel/Proposal/Prohibited.cls`: code `OCUPILOTROUTINEAPP` = `PROHIBITED.OCUPILOTROUTINEAPP`, reason "OcuPilot reads its own protected state through this privileged routine application, so it cannot be deleted or disabled and the roles it grants cannot be changed." Add it to `Codes()`, add `If pCode = ..#OCUPILOTROUTINEAPP Quit ..#OCUPILOTROUTINEAPPREASON` to `ReasonFor`, and fix the count at :915. Add `ROUTINEAPPLICATIONFIELDS = "MatchRoles,Roles"` and refuse an `Enabled` changed to false (spec gate, below); public `OwnRoutineApplication(pId)` compares `NormalizedPath` with the two `Base` names. For a `web-application` id that is one of them, refuse a `DELETE` before `Target()`, and a changed listed field after `Changed()`.
2. `Api/PctAccessError.cls` (new, like `UserCopyError`): `PCTACCESS.ALLOWTYPE`, `.CLASS`, `.APPLICATION`, `.SYSTEM` (409), and `PRIVROUTINE.TYPE`. `Error.cls` gets prefix lines only (:1236, :1444).
3. `AdminPort.cls`, before `EndpointType`: on `Security.PrivilegedRoutine` `GET`, `PUT` or `DELETE`, refuse a name the instance holds whose `KeptType` lacks bit `ROUTINEAPPBIT` (4), with no vendor call or log line; an absent name passes. `GET` answers 404; `PUT` and `DELETE` answer 409 `PRIVROUTINE.TYPE`.
4. `Kernel/EntityType.cls` gains `pct-class-access`. `Kernel/EntityRef.cls` gains rule `foldfirst`, which lower-cases the first composite part and keeps the rest; register it in `IDRULENAMES` and `entity-ref.ts`.
5. `Port/PctAccessPort.cls` (new, declaring its gate as `SuperserverPort` does), for every type but `LIST`: split the composite `name` into `name`, `allowType` and `class`. Refuse 422 before the vendor: `PCTACCESS.ALLOWTYPE` unless `AllowClass` or `AllowPrefix`; `PCTACCESS.CLASS` unless `^%[A-Za-z0-9][A-Za-z0-9.]{0,254}$`; `PCTACCESS.APPLICATION` for a trailing `/`, or a name neither `all-applications` nor answered by `WebApp.App` `GET`. `STATE` filters `LIST` to the row whose `Name` matches in any case and whose `AllowType` and `Class` match exactly. It answers `{AllowAccess, System}`, else 404. `Snippet` mirrors every branch.
6. `MUTATINGTYPES` in `AdminPort` and `Test/PortFixture` gain `WebApp.PctClassAccess/PUT` and `/DELETE`. `BODYLESSTYPES` gains `/DELETE`.
7. `Screen/Descriptor/WebAppPctAccessList.cls` (new): route `web-applications/list/class-access`, `sideBarPosition` 0, Web applications pairs; type `pct-class-access`, id `[Name, AllowType, Class]`; `LIST` of `Name, AllowType, Class, AllowAccess, System`, criterion `application` (`vendorParam` `names`); actions `create` and `delete` (`system-pct-access`); classic page `%CSP.UI.Portal.Applications.Web`, tool identifier `webapp.pctaccess`.
8. Tools on `PctAccessPort`, with `READTYPE` `STATE`. A new `WebAppPctAccessMint` joins `Name`, `AllowType` and `Class` into the id. `WebAppPctAccessCreate`: `CREATES` 1, `PUT`, field `AllowAccess`, `CLASSICPAGES` `%CSP.UI.Portal.Dialog.WebAppPctAccess`. `WebAppPctAccessDelete`: `DELETE`, `SENDSBODY` 0, `FINGERPRINTSUBJECT` `AllowAccess,System`, `DESTRUCTIVE` 1. `StateDiff` refuses `System` with `PCTACCESS.SYSTEM`.
9. `Classification` gets the create's entry, then regenerate `ToolFields`. `Baseline`: create `true`, delete `false`. `Prohibited` gets the type in `COVEREDTYPES` and the chain at :1295, a `ReviewedFewOnly` branch, and `PermittedCreateFields` `AllowAccess`.
10. `Area/WebApp/PctAccessSave.cls` (new, like `DocDbSave`) behind `POST /web-app/pct-access`. `system-pct-access` in `Registry.cls` and `self-protection.ts` reads `System`; its sentence is pinned equal to the `PCTACCESS.SYSTEM` reason.
11. Editor tab 5, "Percent class access" (`ui/src/app/areas/web-applications/web-app-class-access-tab.ts`): it reads `application` = `<name>,all-applications` and re-reads on change. Delete goes through `ScreenActionHandler.startFor`, and is `aria-disabled` on a system row with the rule's sentence. Add opens `web-app-class-access-dialog.ts` (Type, Class or package name, Allow access, Apply to all applications), which posts to the route. Then regenerate `screens.generated.ts`.
12. `strings.ts` keys are add-only. EXPERIENCE.md is edited in place, line count unchanged: UI literals into row :471, the refusal into :475. Past 3000 literals, the `strings.test.mjs` bound becomes 3400, with a comment naming ruling Q3.
13. Tests (armed by `OCUPILOT_ALLOW_PRINCIPALS`): new `Test/OwnRoutineApplication` restores both applications' `MatchRoles` and `Enabled` after each test. New `Test/WebAppPctAccess` creates and removes its probe application and `%OcuProbe1810.*` entries. Client: the tab and dialog specs, plus `web-app-editor.page.spec.ts`, `entity-ref.test.mjs`, `self-protection.test.mjs` and `screen-mirror.test.mjs`. Browser: `web-applications-class-access.browser-spec.mjs`.
14. **Shared-surface sweep (Rule 30).** Update each pin and run it: entity types 62 to 63: `Descriptor:1761`, `MftConnectionDescriptor:141`, `SuperserverDescriptor:130`; codes 33 to 34: `Prohibited:748`, `SuperserverDescriptor:174`, `AuthOptionsDescriptor:166`, `AuditingUpdate:505`, `EncryptionStartupDescriptor:138`, `SqlPrivilegeDescriptor:374`; `Prohibited:232`, `RefusalCopy:109`; `ReadTool:93-94` (321), `SurfaceCoverage`, `ToolRoundTrip:84`, `GovernanceBaseline:15`; `ClassicPageGate:75,154`, `MappingDescriptor:24`, `EndpointCoverage`, `DraftRegistry:57`, `PortGate`; `Wire:534`, `WireSecurityRead:847,998,1027`; `navigation.test.mjs`, `ci-throwaway.sh:257`.

**Acceptance Criteria:**

- Given a web application in the editor, when its Percent class access tab is read, an entry added and a user entry deleted, then each round-trips through the admin API.
- Given the agent, when it proposes `webapp.pctaccess.create` or `.delete`, then it mints and confirms, its read-back verdict is `matches` (create) or `notFound` (delete), and it renders a `Snippet`.
- Given a system entry, when its delete is clicked or proposed, then it is refused `PCTACCESS.SYSTEM` before the vendor, and its Delete is `aria-disabled` with that sentence.
- Given `OcuPilotState` or `OcuPilotIdentity`, when a delete, a disable or a `MatchRoles` or `Roles` change reaches the prohibited set from the screen's action route or an agent's confirm, then it answers 403 `PROHIBITED.OCUPILOTROUTINEAPP` with the published sentence, and nothing changes.
- Given `Security.PrivilegedRoutine` naming a web application, when `AdminPort` is called, then it refuses before the vendor (`GET` 404, `PUT` and `DELETE` 409 `PRIVROUTINE.TYPE`), while `OcuPilotState` still reads.

## Spec Change Log

- 2026-10-09, spec gate (lead): `Enabled` joins the arm. Disabling `OcuPilotState` or `OcuPilotIdentity` is refused (measured: `Prohibits` answered 0 for disabling `OcuPilotIdentity`), in the `SERVINGPATH` doctrine that refuses breaking OcuPilot's own serving path. `Routines` and `Resource` stay with 18.31's gate. Its mutation: the `Enabled` clause is removed and the disable leg reddens. Spine amendments written: AD-10, AD-2, AD-13, AD-44, AD-51.
- 2026-10-09, lead: the orchestrator's rulings on the first plan were applied to the intent block. Q1 narrows 18.10 to the `%`-class access list plus DW-2239 and splits out 18.30 (Doc DB applications), 18.31 (privileged routine applications) and 18.32 (spec-based REST services). Q2 answers AD-53 with (B), written at 18.32's gate. Q3 sets the Fixed-strings bound to 3400. Q4 puts DW-2239's AD-10 arm and type check here. Reset to `draft` for a re-plan.

## Review Triage Log

## Design Notes

**Task 0, this scope.** Measured on `ocupilot-ci` on 2026-10-08, after `LOAD-OK`:

- **The list:** `GET /web-app/pct-accesses` answers `{Name, AllowType, Class, AllowAccess, System}`: 28 rows, 10 of them system. It filters by `names` (a list, `*`, any case), `allowTypes`, `classes` (any case) and `maxRows`, and ignores `name`. `/csp/hssys/` matched nothing.
- **One entry:** `GET /web-app/pct-access` answers `{AllowAccess}` or 404 #1495; a create `PUT` answered 201; a bodyless `DELETE`, 200.
- **`Type`:** 4 for both routine applications, 2 for `/csp/user` and OcuPilot's applications, 3 for `/csp/sys`. The list shows no routine application.
- **`Prohibits` answered 0** for `%All` on `OcuPilotState` (`ScreenAction.Preview`), disabling `OcuPilotIdentity`, and deleting `OcuPilotState`, whose mint refuses first on `NameSpace`.
- **No path writes `Security.PrivilegedRoutine`:** no tool names it, `AdminPort` answers 501, and try-it refuses `/api/admin` writes.
- **S0 after the probes:** monitor 0, 28 entries, no `OcuProbe1810` object, and both applications unchanged.

**Decisions:**

- Create and delete only, as the classic page offers; a change is a delete and a create.
- A system entry goes only with its application (vendor documentation; inference).
- `PctAccessPort` alone checks shapes. Otherwise the vendor logs #869, #1496 or #1498 at severity 2.
- The arm keys on the two production names, as `OcuPilotRoles` does.
- No endpoint has `Roles`, so the `Roles` leg calls `Prohibits` directly.

**Governing ADs:** AD-2, 3, 5, 8, 9, 10, 13, 15, 22, 29, 36, 44, 51, 52, 53, 54, 55, 58, 59.

**Consumed-by:** 18.31 (`OwnRoutineApplication`, the type check) and 18.12 (`webapp.pctaccess.*`). **Consumes:** 9.2, 5.5 and 7.1. **Integration ACs:** the browser spec and `Test/WebAppPctAccess`.

**Ledger:** DW-2239 is Tasks 1, 3 and 13. Nothing builds on an owner-hold entry.

**For the lead** (Rule 20):

- **AD-10:** "**OcuPilot's own privileged routine applications** (Story 18.10, DW-2239): deleting `OcuPilotState` or `OcuPilotIdentity`, or changing their `MatchRoles` or `Roles`, is refused `PROHIBITED.OCUPILOTROUTINEAPP` from either caller, through every tool that reaches them, as AD-9's escalation."
- **Also:** AD-2 (the type check), AD-13 (`foldfirst`), AD-44 (the create's `CLASSICPAGES`), AD-51 (`STATE`).
- **Settled at the spec gate:** `Enabled` joins the arm here; `Routines` and `Resource` are settled at 18.31's gate. The AD-10, AD-2, AD-13, AD-44 and AD-51 amendments are written.

**Baseline for 18.30-18.32** (first plan, 2026-10-08; pairs `%Admin_Secure:U` and `%DB_IRISSYS:R`):

- `DocDB`: an upsert keeping omitted keys; stores absent names; creates no database.
- `Security.PrivilegedRoutine`: an upsert emptying an omitted `Routines` (AD-4); writes any application type; `LIST` answers `Enabled` false.
- REST `POST`: an upsert compiling `.spec`, `.disp`, `.impl` (`DELETE` keeps `.impl`); unaudited; needs `%Development:USE` and routines WRITE; fetches a string `swagger`.

## Verification

**Commands (loop),** one run at a time:

- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.OwnRoutineApplication` — a probe routine application stays unrefused. Mutations: drop the `DELETE` clause → delete legs red; drop `MatchRoles` → `Prohibits`, route and confirm legs red; drop `Roles` → `UNCOVEREDFIELD`; drop `IDENTITYAPPLICATION` → identity leg red; drop the type check → `GET` and `PUT` legs red.
- `--class OcuPilot.Test.WebAppPctAccess`, then each swept class. Mutations: drop `PUT` from `MUTATINGTYPES` → create red; drop the `System` refusal → system red; drop the `%` check → shape red; `foldfirst` keeps case → spelling red.
- `cd ui && npm run test:tools && npm run test:components`. Mutation: no `,all-applications` → the tab spec red.
- Browser: `npm run build`; `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`; then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/web-applications-class-access.browser-spec.mjs browser/web-applications-editor.browser-spec.mjs`. Mutation: wrong post path → add leg red.
- `uv run scripts/check-objectscript.py`; `bash scripts/lint-docs.sh`.

**(once, before dev_complete):** the full ObjectScript sweep, one class per run.

**Shared surfaces:** the editor's tabs, entity types, prohibited codes, tool rosters, the Web applications area, Fixed strings and `MUTATINGTYPES`.

**Standing criterion:** existing tests that assert a surface this story changes are updated in this story, and every test the story adds or changes passes on a freshly built instance and in either order.

**Manual checks:** `ocupilot-ci` is at S0.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Re-planned after the 2026-10-09 rulings. Task 0 was re-measured on `ocupilot-ci`, which is left at S0.
