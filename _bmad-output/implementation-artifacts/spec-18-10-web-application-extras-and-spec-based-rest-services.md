---
title: 'Story 18.10: Web application extras and spec-based REST services'
type: 'feature'
created: '2026-10-08'
status: 'in-progress'
baseline_revision: 'aae612042dc4d159aa931e144974a5bd3912a973'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['multiple-goals', 'oversized']
deferred:
  - summary: >-
      AdminPort's direct PUT and DELETE on Security.PrivilegedRoutine may reach the vendor for OcuPilotState or OcuPilotIdentity, without the AD-10 arm.
    evidence: |-
      (inference, maybe-false) The guard refuses only web-application names; the AD-10 arm lives in Prohibited.Prohibits, which the proposal tools call. Whether AdminPort's PUT or DELETE on this endpoint consults Prohibits is not settled: EndpointType admits PUT through TYPESUFFIXES, and the endpoint is not in MUTATINGTYPES. Settle by reading EndpointType and the mutating path for Security.PrivilegedRoutine, with no live write to OcuPilotState.
    location: >- # file:line
      src/OcuPilot/Port/AdminPort.cls:1246
    severity: high (unverified)
  - summary: >-
      AdminPort's generic WebApp.PctClassAccess PUT and DELETE may skip the PctAccessPort shape check, so a malformed class reaches the vendor.
    evidence: |-
      (inference, maybe-false) The shape check lives in PctAccessPort.Shape; WebApp.PctClassAccess PUT and DELETE are in AdminPort MUTATINGTYPES. Settle by reading the route table to see whether the REST surface reaches AdminPort's generic endpoint for that type while bypassing PctAccessPort.
    location: >- # file:line
      src/OcuPilot/Port/AdminPort.cls:472
    severity: medium (unverified)

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

**Rework items (pass 2, lead decisions 2026-10-09, after pass 1 returned `blocked` with its work uncommitted):**

- [ ] [Rework] Decision 1, the 403. `WebAppDelete`'s `NameSpace` precondition answers 400 `TOOL.ARGUMENTS` before the AD-10 arm runs, because `OcuPilotState` and `OcuPilotIdentity` have an empty `NameSpace`. `WebAppDelete` answers 403 `PROHIBITED.OCUPILOTROUTINEAPP`, with `Prohibited`'s own reason and envelope, for those two before its precondition, on every caller path: the screen action route, the agent's mint and the agent's confirm. This is Task 1's "refuse a `DELETE` before `Target()`". Other privileged routine applications keep today's precondition refusal unchanged (18.31 owns them). Do not reorder `Prohibits` against `StateDiff` globally. Then write P1, the route and confirm 403 test. Mutation: remove the early check, so the answer is 400 again and P1 reddens.
- [ ] [Rework] Decision 2, the typed name. A `%`-class access entry's Delete confirmation is typed against the entry's `Class` value, exactly as its row shows it, never the composite id with its U+0001 separators. Set that on the pct-class-access descriptor and write P7, the browser Delete leg. Mutation: the dialog compares against the id, so the Delete button never enables and P7 reddens.
- [ ] [Rework] P11, the port-side `System` refusal. Demonstrate its mutation through a test-only seam that replaces the vendor call (as `Test/UserCopyVendorFault` does), never a real delete of an instance-owned entry.
- [ ] [Rework] Re-measure after the patches and write the numbers into `## Auto Run Result`: the bundle's initial total, and the Fixed-strings literal count against the 3000 bound. If the count crosses 3000, raise the bound to exactly 3400 with ruling Q3's comment line.

**Acceptance Criteria:**

- Given a web application in the editor, when its Percent class access tab is read, an entry added and a user entry deleted, then each round-trips through the admin API.
- Given the agent, when it proposes `webapp.pctaccess.create` or `.delete`, then it mints and confirms, its read-back verdict is `matches` (create) or `notFound` (delete), and it renders a `Snippet`.
- Given a system entry, when its delete is clicked or proposed, then it is refused `PCTACCESS.SYSTEM` before the vendor, and its Delete is `aria-disabled` with that sentence.
- Given `OcuPilotState` or `OcuPilotIdentity`, when a delete, a disable or a `MatchRoles` or `Roles` change reaches the prohibited set from the screen's action route or an agent's confirm, then it answers 403 `PROHIBITED.OCUPILOTROUTINEAPP` with the published sentence, and nothing changes.
- Given `Security.PrivilegedRoutine` naming a web application, when `AdminPort` is called, then it refuses before the vendor (`GET` 404, `PUT` and `DELETE` 409 `PRIVROUTINE.TYPE`), while `OcuPilotState` still reads.

**Review patches (pass 1, 2026-10-08; each is a finding in `## Review Triage Log`; the test pins are not intent):**

- **P1 — routine arm at the route and the confirm.** Add a wire test (the `PctAccessSaveWire` pattern) that posts a delete, a disable and a `MatchRoles` change of `OcuPilotState` and of `OcuPilotIdentity` through the screen action route and through the agent confirm path. Each asserts 403 `PROHIBITED.OCUPILOTROUTINEAPP`, the published sentence, and an unchanged application read back from the instance. Also covers the "nothing sent" claim.
- **P2 — `OwnRoutineApplication.Ask`.** Return the `%Status` to the caller and assert it OK in the negative leg (`TestUnrelatedNotRefused`), so a `Prohibits` error cannot read as "not prohibited".
- **P3 — privileged-routine PUT leg.** Add a `PUT` leg to `TestPrivilegedRoutineEndpointRefusesAWebApp` asserting 409 `PRIVROUTINE.TYPE` on a web-application name, with the vendor untouched. The DELETE mutation is destructive on the throwaway; note it in `## Verification`.
- **P4 — tool-level mint and confirm (AC2).** Test `webapp.pctaccess.create` and `.delete` through `Mint`, then confirm: the read-back verdict is `matches` for create and `notFound` for delete, and `Snippet` is non-empty. Use the `ToolRoundTrip` style.
- **P5 — `WebAppPctAccessDelete.StateDiff`.** Call it with `System` = 1 (asserts `pProblem` is the `PCTACCESS.SYSTEM` sentence) and with `System` unassigned (asserts the origin-unknown problem).
- **P6 — `PctAccessSave` EXISTS.** Create an entry, post it again, and assert 409 `PCTACCESS.EXISTS` with one vendor write only.
- **P7 — editor Delete (browser).** Add a browser leg that clicks a non-system Delete in the editor, confirms, and checks the entry is gone on the instance. Rebuild and redeploy the bundle before the run.
- **P8 — sentence pin.** Add a cross-language equality test in `ui/tools/self-protection.test.mjs`, in the `SERVINGPATHREASON` style, comparing `pctAccessRefusalSystem` in `strings.ts` with the `PCTACCESS.SYSTEM` reason in `Api/PctAccessError.cls`.
- **P9 — PortFixture.** Add `WebApp.PctClassAccess/PUT` and `/DELETE` to `MUTATINGTYPES`, and `WebApp.PctClassAccess/DELETE` to `BODYLESSTYPES`, in `Test/PortFixture.cls`, matching `AdminPort`.
- **P10 — `foldfirst`.** Add the `foldfirst` rule to `Kernel/EntityRef.cls` (lower-cases the first composite part, keeps the rest) and register it in `IDRULENAMES` and `ui/src/app/core/entity-ref.ts`. Point `pct-class-access` at `foldfirst`, and update the pins in `ui/tools/screen-mirror.test.mjs`. Keep `foldcase-firstpart` for its existing users.
- **P11 — mutations.** On `ocupilot-ci`, run one at a time with recompile and revert, each observed red and the tree byte-identical after revert: the System refusal (`StateDiff` and the port refusal), the percent-sign shape check, and the `Enabled` clause of the routine arm.
- **P12 — probe cleanup.** `OnAfterOneTest` in the `WebAppPctAccess` test removes any `%OcuProbe1810*` entry on both applications and any probe-created entry, so a mutation cannot leave one behind.

## Spec Change Log

- 2026-10-09, lead: pass 1 (Haiku) returned `blocked` on two decisions, with its work uncommitted and kept for pass 2's finalize. Decision 1 is a targeted early 403 in `WebAppDelete` for OcuPilot's two applications (Task 1's wording). Decision 2 types the confirmation against `Class`. The orchestrator confirmed the `Enabled` leg of the arm. The four rework items above are pass 2's whole scope.
- 2026-10-09, spec gate (lead): `Enabled` joins the arm. Disabling `OcuPilotState` or `OcuPilotIdentity` is refused (measured: `Prohibits` answered 0 for disabling `OcuPilotIdentity`), in the `SERVINGPATH` doctrine that refuses breaking OcuPilot's own serving path. `Routines` and `Resource` stay with 18.31's gate. Its mutation: the `Enabled` clause is removed and the disable leg reddens. Spine amendments written: AD-10, AD-2, AD-13, AD-44, AD-51.
- 2026-10-09, lead: the orchestrator's rulings on the first plan were applied to the intent block. Q1 narrows 18.10 to the `%`-class access list plus DW-2239 and splits out 18.30 (Doc DB applications), 18.31 (privileged routine applications) and 18.32 (spec-based REST services). Q2 answers AD-53 with (B), written at 18.32's gate. Q3 sets the Fixed-strings bound to 3400. Q4 puts DW-2239's AD-10 arm and type check here. Reset to `draft` for a re-plan.

## Review Triage Log

### 2026-10-08 — Review pass

- verdicts: 23 findings — high 1, medium 9, low 7, false 4, maybe-false 2
- findings:
  - `[medium]` `[patch]` Routine-application arm has no route-level or confirm-level test; a route or confirm that bypasses `Prohibits` is not caught, and "nothing sent" is not asserted — patch P1 and P2 add the 403 wire test and the unchanged-state read-back. The implementer's pre-fix deferral (routine application reachable by web-application tools, measured before the arm existed) is superseded by the arm and is removed from `deferred:`; its open question is P1. not applied: blocked. The delete legs of `OwnRoutineApplicationWire` are red on the unmodified code (see Verification).
  - `[low]` `[reject]` The Enabled mutation is absent from `## Verification` — the fix is a spec edit, which the triage rules reject; the leg exists (`OwnRoutineApplication.TestDisableRefused`), and its mutation run is P11.
  - `[low]` `[patch]` `OwnRoutineApplication.Ask` turns a `Prohibits` error into "not prohibited" — P2 returns the status and asserts OK in the negative leg. fix applied: `Ask` returns the status as an `Output`; `TestUnrelatedNotRefused` asserts it OK.
  - `[medium]` `[patch]` No PUT leg for the privileged-routine guard — P3 adds it. fix applied: `TestPrivilegedRoutineEndpointRefusesAWebApp` PUT leg asserts 409 `PRIVROUTINE.TYPE` and that `/csp/user` reads unchanged.
  - `[high]` `[patch]` AC2 (agent create and delete mint, read-back verdicts, Snippet) has no executing test — P4. fix applied: `WebAppPctAccess.TestAgentCreateAndDeleteMintConfirmAndReadBack`; create reads `matches`, delete reads `notFound`, snippet non-empty.
  - `[medium]` `[patch]` `WebAppPctAccessDelete.StateDiff` System refusal is unpinned at the tool level — P5. fix applied: `TestStateDiffRefusesASystemEntry` and `TestStateDiffRefusesAnUnknownOrigin`.
  - `[medium]` `[patch]` `PctAccessSave` EXISTS refusal has no wire test — P6. fix applied: `PctAccessSaveWire.TestAnExistingEntryIsRefusedAndNotWrittenAgain`.
  - `[medium]` `[patch]` Editor non-system Delete has no browser leg — P7. not applied: blocked. The browser Delete leg is red (see Verification).
  - `[low]` `[patch]` The client sentence `pctAccessRefusalSystem` has no cross-language pin against `PCTACCESS.SYSTEM` — P8. fix applied: cross-language pin in `ui/tools/self-protection.test.mjs`.
  - `[medium]` `[patch]` `Test/PortFixture` MUTATINGTYPES omits the two `WebApp.PctClassAccess` mutating entries and the `/DELETE` bodyless entry the spec's Task 6 requires — P9. fix applied: `PortFixture.MUTATINGTYPES` gains both entries. `BODYLESSTYPES` is inherited from `AdminPort`, which already lists `WebApp.PctClassAccess/DELETE`; `PortFixture` declares none of its own.
  - `[low]` `[patch]` Task 4's `foldfirst` rule was not built; `pct-class-access` uses `foldcase-firstpart` — P10 builds the spec-named rule and points the entity type at it. fix applied: `foldfirst` added to `EntityRef.cls`, `entity-ref.ts`, `IMPLEMENTED_ID_RULES` and the `screen-mirror.test.mjs` pins; `pct-class-access` points at it; `entity-ref.test.mjs` pins it. Behavior matches `foldcase-firstpart`.
  - `[low]` `[patch]` Task 13 names `entity-ref.test.mjs` and `self-protection.test.mjs` as changed; neither is — folded into P8 and P10.
  - `[false]` `[reject]` Fixed-strings bound not raised. `ui/tools/strings.test.mjs` passes 25 of 25 at the 3000 bound on this tree, so the literal count is within it.
  - `[low]` `[reject]` `ui/tools/ci-timings.json` does not list the new classes and spec. Shares balance from that file, and CLAUDE.md's roll-up rule is one-leg-per-class, which unlisted classes still satisfy. Balance only is low; the refresh needs a green run's data, which this pass does not have.
  - `[medium]` `[patch]` Two Rule 19 mutations were not run (the System refusal and the percent-sign shape check) — P11 runs them on `ocupilot-ci` with revert and byte-identity; the Enabled mutation runs there too. fix applied (partial): the percent-sign and StateDiff System mutations ran red and were reverted byte-identical; the port-side System mutation is not run (see Verification).
  - `[medium]` `[patch]` `TestShapeRefused` under the percent-sign mutation leaves an `Ens.Director` entry on `all-applications`; `OnAfterOneTest` removes only the probe class — P12 removes any `%OcuProbe1810*` entries and probe-created application entries in cleanup. fix applied: `WebAppPctAccess.OnAfterOneTest` removes every `%OcuProbe1810` entry and every `all-applications` entry the test added; run 87 leaves none.
  - `[medium]` `[patch]` Intent layer: the tests exercise only the kernel verdict, not the MCP tool, the proposal flow or the route, and never assert that the vendor was left untouched — folded into P1 and P3. fix applied (partial): the P3 leg is in place; the P1 route legs are blocked (see Verification).
  - `[maybe-false]` `[defer]` AdminPort's direct PUT and DELETE on `Security.PrivilegedRoutine` for routine-typed names may bypass the AD-10 arm — see the first `deferred:` item. Settle by reading EndpointType and the mutating path, with no live write.
  - `[medium]` `[defer]` (maybe-false) AdminPort's generic `WebApp.PctClassAccess` endpoint may bypass the shape check — see the second `deferred:` item.
  - `[false]` `[reject]` Delete tool disabled by default (`webapp.pctaccess.delete` false in Baseline). The spec's AD-22 ruling is "delete destructive and disabled"; the Baseline entry is the ruling.
  - `[false]` `[reject]` The fixed-strings bound was not touched. Same refutation as the bound finding above; the bound is the ruling's 3000 until the count exceeds it.
  - `[false]` `[reject]` The spine's AD-10 amendment is absent from the diff. The amendment is in the base revision (`aae612042`, five "Story 18.10 spec gate" hits), so it is not a defect of this change.
  - `[low]` `[reject]` CI bookkeeping (`ci-timings.json`) — the same claim as the ci-timings finding above; same reason.

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

**Review pass 1 (P1–P12) pins and runs, 2026-10-08.** Runs on `ocupilot-ci`, one class at a time, after `load-ocupilot-ci.sh` each time: `OwnRoutineApplication` run 80 green (7/7), then run 89 red and run 90 green; `WebAppPctAccess` run 81 green (7/7), run 85 red and run 86 green (System), run 87 red and run 88 green (shape); `PctAccessSaveWire` run 82 green (3/3); `OwnRoutineApplicationWire` runs 83 and 84 red, 2 of 2 (blocked, see below). Client: `node --test tools/*.test.mjs` 1903/1903 green; `ng test` on `src/app/areas/web-applications` 65/65 green; `screen-mirror.mjs --check` up to date.

- `OwnRoutineApplication.TestDisableRefused` (P11, Enabled clause): mutation: `If ..Disables(pPayload, .pChanged) Quit 1` -> `If 0 Quit 1` in `Prohibited.RoutineApplicationChanges`; run 89 red on that leg; reverted, `cmp` byte-identical; run 90 green.
- `WebAppPctAccess.TestStateDiffRefusesASystemEntry` (P11, StateDiff): mutation: `If pFresh.%Get("System") = 1` -> `If 0` in `WebAppPctAccessDelete.StateDiff`; run 85 red (three legs); reverted, byte-identical; run 86 green.
- `WebAppPctAccess.TestShapeRefused` (P11, percent sign; P12 cleanup): mutation: `If '$Match(tClass, ..#CLASSPATTERN) Quit` -> `If 0 Quit` in `PctAccessPort`; run 87 red; the `Ens.Director` row the mutation wrote is removed by `OnAfterOneTest` (runner: 0 probe leftovers); reverted, byte-identical; run 88 green.
- `WebAppPctAccess.TestSystemEntryRefused` port-side System refusal (P11): NOT RUN. Mutation `If pType = "DELETE"` -> `If 0` in `PctAccessPort.Invoke` would send a vendor DELETE of an instance-owned entry on the throwaway (it lists the `/api/*` entries), which cannot be restored from here. Needs a fresh throwaway or the lead's word.
- `WebAppPctAccess.TestStateDiffRefusesAnUnknownOrigin` (P5): mutation: drops the `unassigned` branch of `StateDiff`; not run.
- `WebAppPctAccess.TestAgentCreateAndDeleteMintConfirmAndReadBack` (P4): mutation: `STATE` answers 200 for an absent entry, so the delete confirm reads `matches`; not run. The snippet leg asserts `PctAccessPort.Snippet` directly, not the copy-out draft.
- `PctAccessSaveWire.TestAnExistingEntryIsRefusedAndNotWrittenAgain` (P6): mutation: removes the `EXISTS` branch in `PctAccessSave.Create`; not run.
- `OwnRoutineApplication.TestUnrelatedNotRefused` (P2) and `TestPrivilegedRoutineEndpointRefusesAWebApp` PUT leg (P3): mutation for P2 is `Ask` returning 0 without a status; for P3 the PUT branch of `PrivilegedRoutineGuard` removed. Not run; the DELETE mutation is destructive on the throwaway, so the PUT leg is the only one of the two that could run.
- `OwnRoutineApplicationWire` (P1), both legs: mutation: drops the `DELETE` clause of the arm. Not run; the legs are red on the unmodified code (blocker below).
- `ui/tools/self-protection.test.mjs` Story 18.10 pin (P8): mutation: changes one word of `REASONSYSTEM` in `PctAccessError.cls`; not run.
- `ui/tools/entity-ref.test.mjs` foldfirst pin (P10): mutation: `foldfirst` as `(id) => id`; not run. `screen-mirror.test.mjs` pins (P10) updated to `foldfirst`; green.
- `web-applications-class-access.browser-spec.mjs` Delete leg (P7): mutation: drops `delete` from the tab's `startFor`; not run; the leg is red (blocker below).
- `web-app-class-access-tab.spec.ts` (P7 side fix): fake handler gains `pending`; green.

**Blockers (pass 1, not resolved by this pass):**

- **P1 delete legs.** On `OcuPilotState` and `OcuPilotIdentity` the vendor reads an empty `NameSpace` (measured: `NS=` on both). `WebAppDelete.StateDiff` answers that as "did not report that web application's own record", so both the screen route and the mint answer `TOOL.ARGUMENTS` (400) before `Prohibited` runs. The arm's delete branch is correct when asked directly (`OwnRoutineApplication` green), but no route reaches it. Decide: reorder the routine check ahead of the precondition, or change the precondition for routine applications, then re-run `OwnRoutineApplicationWire`.
- **P1 MatchRoles on the agent path.** `WebAppUpdate` excludes `MatchRoles` from its settable fields, so no agent proposal carries it; the test's class header says so. The screen route pins it (green).
- **P7 Delete.** The tab's Delete opens the typed-name dialog, which asks for the composite id (`/csp/user<U+0001>AllowClass<U+0001>%OcuProbe1810.Browser`); the destructive button stays `aria-disabled` after the displayed text is typed, and the entry stays. The editor page did not mount `app-screen-action-dialogs`, so before this pass the Delete drew nothing; the tab now mounts it. Decide the typed name for this descriptor (for example the class).

**Manual checks:** `ocupilot-ci` is at S0 (read after run 90: no `%OcuProbe1810` entry, no `Ens.Director` entry on `all-applications`, `OcuPilotState` and `OcuPilotIdentity` present and enabled, `/csp/ocuprobe1810` absent).

## Auto Run Result

Status: blocked
Blocking condition: review patches P1 and P7 need two decisions. (1) The routine-application delete answers 400 TOOL.ARGUMENTS from WebAppDelete.StateDiff before the AD-10 arm runs, because the routine applications report an empty NameSpace; AC4's 403 PROHIBITED.OCUPILOTROUTINEAPP is therefore not reached through the screen route. Decide whether the routine check moves ahead of the StateDiff precondition or the precondition changes for routine applications. (2) The editor's Delete confirmation is a typed-name dialog whose composite id contains invisible U+0001 separators, so the displayed text cannot be typed to enable the destructive button; decide the typed name for the pct-class-access descriptor. Also open: the P11 port-side System refusal mutation was not run, because it would send a vendor DELETE of an instance-owned entry on the throwaway.

Pass 1 (2026-10-08, implement of 18.10 at baseline aae612042). Implementation subagent: the %-class access list (port, tools, Save route, editor tab, dialog), the AD-10 arm and the privileged-routine guard, and the Rule 30 sweep. Review layers (verification-gap, intent-alignment) triaged 23 findings: 13 patch, 4 reject-as-false, 3 reject, 2 defer (see the Review Triage Log pass entry).

Patched and green on ocupilot-ci: P2 OwnRoutineApplication Ask status (run 80, 7/7); P3 PUT leg (same run); P4 agent create and delete mint and read-back (WebAppPctAccess run 81, 7/7); P5 StateDiff System and unknown-origin legs (same run); P6 EXISTS wire leg (PctAccessSaveWire run 82, 3/3); P8 sentence pin in self-protection.test.mjs; P9 PortFixture MUTATINGTYPES; P10 foldfirst rule, now used by pct-class-access, with screens.generated.ts regenerated; P12 probe cleanup (run 87, no leftover).

Mutations run on ocupilot-ci, each reddened and reverted byte-identical: StateDiff System refusal (run 85 red, 86 green); percent-sign shape check (87 red, 88 green); Enabled clause of the routine arm (89 red on TestDisableRefused, 90 green).

Client: npm run test:tools 1903/1903 green; the component tab spec 65/65 green. check-objectscript 0 problems; lint-docs 0 issues. Bundle and fixed-strings count are unchanged from the implement pass (bundle under the 3326 kB warning; strings test 25/25 at the 3000 bound).

Not applied: P1 (blocked decision 1) and P7 (blocked decision 2). Their rows in the triage log read "not applied: blocked". The implementer's six self-deferrals were re-triaged: the routine-application reachability item is superseded by the arm and removed; AC2, the two unrun mutations and the browser delete path are patches, not deferrals; the foldfirst item is patch P10; the ci-timings item is rejected (see the log). Two deferred items remain (AdminPort routine-name bypass, high unverified; generic PctClassAccess shape bypass, medium unverified).

Throwaway ocupilot-ci reads S0 after the last run. Nothing committed, staged or pushed. The worktree holds the uncommitted pass-1 work for the lead's decision.

Re-planned after the 2026-10-09 rulings. Task 0 was re-measured on `ocupilot-ci`, which is left at S0.
