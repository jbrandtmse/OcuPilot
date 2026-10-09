---
title: 'Story 18.10: Web application extras and spec-based REST services'
type: 'feature'
created: '2026-10-08'
status: 'done'
baseline_commit: '2ac4272dc852498fde08f81358c3bb357838a8ca'
baseline_revision: '2ac4272dc852498fde08f81358c3bb357838a8ca'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['multiple-goals', 'oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The web application editor has no `%`-class access list, which the classic page offers. And OcuPilot's own privileged routine applications, `OcuPilotState` and `OcuPilotIdentity`, are reachable by the web application tools with no AD-10 arm refusing a delete or a `MatchRoles` change (DW-2239, measured at this story's first plan). The vendor's privileged-routine endpoint also writes any application type.

**Approach:** This follows the orchestrator's 2026-10-09 rulings Q1 and Q4 on this story's first plan. Two parts:

- The `%`-class access list on the web application editor, read and changed through the admin API.
- An AD-10 arm refusing every change to OcuPilot's own two privileged routine applications (the owner: "Refuse every change"): a delete, a disable or a change to any field, through every path that reaches them, including the vendor's privileged-routine endpoint. It sits in the family of the existing arms for OcuPilot's own web applications (`PROHIBITED.PRIVILEGEGRANT`, and deleting OcuPilot's own web applications). A target-type check goes wherever OcuPilot reaches that endpoint. A Rule 19 test proves each arm reddens under its mutation, and AD-10 is amended at this story's spec gate.

Doc DB applications (18.30), privileged routine applications (18.31) and spec-based REST services (18.32) are split out.

## Boundaries & Constraints

**Always:** The measurements in Design Notes are this story's baseline and the split stories' Task 0 baseline; re-measure only what they leave open. Under ruling Q3 (2026-10-09), the Fixed-strings bound becomes 3400 in the first code head that needs it, with a comment line in `strings.test.mjs` naming the ruling; a merge takes the higher value.

**Never:** Build Doc DB applications, the privileged routine application screens and tools, or spec-based REST services here. Build on DW-2084 or any other owner-hold entry.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| OcuPilot's own privileged routine application | A delete of `OcuPilotState` or `OcuPilotIdentity`, disabling either, or a change to any of its fields, through any path | Refused by the AD-10 arm; nothing sent | Today: `Prohibits` answers 0 |
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

1. `Kernel/Proposal/Prohibited.cls`: code `OCUPILOTROUTINEAPP` = `PROHIBITED.OCUPILOTROUTINEAPP`, reason "OcuPilot reads its own protected state through this privileged routine application, so it cannot be deleted, disabled or changed." Add it to `Codes()`, add `If pCode = ..#OCUPILOTROUTINEAPP Quit ..#OCUPILOTROUTINEAPPREASON` to `ReasonFor`, and fix the count at :915. Public `OwnRoutineApplication(pId)` compares `NormalizedPath` with the two `Base` names. For a `web-application` id that is one of them, refuse every write (a create, a delete, a change to any field) before `Target()`.
2. `Api/PctAccessError.cls` (new, like `UserCopyError`): `PCTACCESS.ALLOWTYPE`, `.CLASS`, `.APPLICATION`, `.SYSTEM` (409), and `PRIVROUTINE.TYPE`. `Error.cls` gets prefix lines only (:1236, :1444).
3. `AdminPort.cls`, before `EndpointType`: on `Security.PrivilegedRoutine` `GET`, `PUT` or `DELETE`, refuse a name the instance holds whose `KeptType` lacks bit `ROUTINEAPPBIT` (4), with no vendor call or log line; an absent name passes. `GET` answers 404; `PUT` and `DELETE` answer 409 `PRIVROUTINE.TYPE`.
4. `Kernel/EntityType.cls` gains `pct-class-access`. Its id takes the existing rule `foldcase-firstpart` in `Kernel/EntityRef.cls` and `entity-ref.ts`: the application folds, the access type and the class keep their spelling.
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

- [x] [Rework] Decision 1, the 403. `WebAppDelete`'s `NameSpace` precondition answers 400 `TOOL.ARGUMENTS` before the AD-10 arm runs, because `OcuPilotState` and `OcuPilotIdentity` have an empty `NameSpace`. `WebAppDelete` answers 403 `PROHIBITED.OCUPILOTROUTINEAPP`, with `Prohibited`'s own reason and envelope, for those two before its precondition, on every caller path: the screen action route, the agent's mint and the agent's confirm. This is Task 1's "refuse a `DELETE` before `Target()`". Other privileged routine applications keep today's precondition refusal unchanged (18.31 owns them). Do not reorder `Prohibits` against `StateDiff` globally. Then write P1, the route and confirm 403 test. Mutation: remove the early check, so the answer is 400 again and P1 reddens.
- [x] [Rework] Decision 2, the typed name. A `%`-class access entry's Delete confirmation is typed against the entry's `Class` value, exactly as its row shows it, never the composite id with its U+0001 separators. Set that on the pct-class-access descriptor and write P7, the browser Delete leg. Mutation: the dialog compares against the id, so the Delete button never enables and P7 reddens.
- [x] [Rework] P11, the port-side `System` refusal. Demonstrate its mutation through a test-only seam that replaces the vendor call (as `Test/UserCopyVendorFault` does), never a real delete of an instance-owned entry.
- [x] [Rework] Re-measure after the patches and write the numbers into `## Auto Run Result`: the bundle's initial total, and the Fixed-strings literal count against the 3000 bound. If the count crosses 3000, raise the bound to exactly 3400 with ruling Q3's comment line.

**Rework items (pass 3, lead decision 2026-10-09, after pass 2 returned `blocked` on the endpoint arm):**

- [x] [Rework] Decision 3, option (a), as ruling Q4 requires ("through every path that reaches them, including the vendor's privileged-routine endpoint"). In `AdminPort`'s `PRIVROUTINEENDPOINT` branch, before any vendor call and unlogged, consult `Prohibited` and refuse 403 `PROHIBITED.OCUPILOTROUTINEAPP` for `OcuPilotState` or `OcuPilotIdentity` on a `DELETE`, and on a `PUT` that sets `Enabled` false or changes `MatchRoles` or `Roles`. Use the same `OwnRoutineApplication` and `RoutineApplicationChanges` predicates the kernel arm uses, never a second copy. A `GET` still reads. Give each clause its own Rule 19 leg (delete, disable, `MatchRoles`, `Roles`), each with its mutation line. Each leg asserts that the vendor was not reached, by reading the application's stored state before and after and failing on an empty read.
- [x] [Rework] Apply every `[patch]` row marked "(not applied)" in the "2026-10-09 — Review pass (pass 2 …)" entry of the Review Triage Log: the `foldfirst` pin, the published-sentence and refusal-code assertions, the vendor-untouched read that cannot pass on `""`, and the `PctAccessError` sentences. Run every mutation that entry and `## Verification` record as named but not run (the AC1 Delete `startFor` leg, the AC2 Snippet and `webapp` mint legs, P2, P3's PUT leg, P4, P5, P6, P8 and P10), then write or correct each `mutation:` line. Leave the rows marked `[reject]` alone.
- [x] [Rework] Replace the whole body of `## Auto Run Result` with this pass's record only: the two contract lines, then no more than eight lines covering what changed, the runs with their indices, the bundle size, the Fixed-strings count, and S0. Earlier passes' notes are in the Spec Change Log and the triage log; do not restate them.
- [x] [Rework] Read S0 in full at the end: no `%OcuProbe1810*` entry, probe application or principal; both routine applications' `MatchRoles`, `Roles` and `Enabled` as at the start; monitor state 0.

**Sweep items (pass 4, lead, 2026-10-09).** The runner's full ObjectScript sweep ran on a fresh `ocupilot-ci` over `fe8e3832`: 534 classes, 4,250 tests, 4 failed.

- [x] [Sweep] `Governance.TestTheDefaultEnablesEveryWriteButTheBaselineDisabled` (run 171) and `ToolDispatch.TestTheShippedGateAllowsEveryLiveToolButTheBaselineDisabled` (run 462). The baseline-disabled roster in both lacks `webapp.pctaccess.delete`. Add it to each roster, with its count and sentence, derived where the test already derives.
- [x] [Sweep] `Prohibited.TestTheSetHasOneHomeAndOneSentencePerCode` (run 324). `WebAppDelete` spells `PROHIBITED.OCUPILOTROUTINEAPP` and its sentence outside the set. Route the early 403 through a `Prohibited` method that answers the code and its reason, so the code and the sentence each live once, in `Prohibited.cls`. Keep Decision 1's behavior: 403 before the precondition, with `OwnRoutineApplicationWire` still green.
- [x] [Sweep] `ExplorerWire.TestTheReadToolsAnswerRowsAndNeverTheDocument` (run 158; again alone, run 535). Its `explorer.class.read` leg reads `OcuPilot.Port.AdminPort.cls`, which this story grew past the 65,536-character tool-result cap (`TOOL.RESULTTOOLARGE`). Point the leg at a small, stable class whose read stays well under the cap and still answers its `Description` row, for example `OcuPilot.Kernel.Agent.Limits.cls` (Rule 30: a test never relies on a growing production class's size). The cap itself is filed separately by the lead.
- [x] [Deferred] Settle pass 3's two `deferred:` items with evidence on `ocupilot-ci`. (a) Does the vendor's `Security.PrivilegedRoutine` `PUT` empty an omitted `MatchRoles` or `Roles`? Measure it on a probe privileged routine application your test creates and removes. If it does, the endpoint arm must treat an omitted `MatchRoles` or `Roles` on `OcuPilotState` or `OcuPilotIdentity` as a change and refuse it, with its own Rule 19 leg. (b) Does any caller other than `PctAccessPort` reach `WebApp.PctClassAccess` writes? Grep the routes and tools, and remember the try-it console refuses `/api/admin` writes. If none does, record why under Design Notes; if one does, route it through the shape check. Remove each settled item from `deferred:`.

**Rework items (orchestrator quality review, 2026-10-09).** The Planner's read-only review (Opus, four reviewers, on `f33263ed`) made the claims below. Each is a claim to verify against the code, not a finding to accept. Verify each one, patch what verifies, and record each as `confirmed` or `refuted`, with its evidence, in a new Review Triage Log entry, "2026-10-09 — Orchestrator quality review". The code review that ran after `f33263ed` may already have closed some (marked below); verify those against the current tree too.

- [x] [Rework] Claim 1, the arm's scope (the orchestrator's ruling, pending the owner's word). Build the arm to refuse **every** change to `OcuPilotState` and `OcuPilotIdentity`, by every path: delete, `Enabled`, `MatchRoles`, `Routines`, `Resource`, and any other field. This is what `Prohibited` already does for OcuPilot's own web applications; reuse that arm's shape rather than writing a field list. Paths: the kernel `Prohibits`, the early 403 (`RefusesDeleteBeforeState`, extended to every write type), and `AdminPort`'s `PRIVROUTINEENDPOINT` arm. Remove the `Roles` pins, which neither target carries (`OwnRoutineApplication.cls` around :153, :154 and :259). Pin each arm with its own Rule 19 mutation. If an "any field" refusal is already in place for OcuPilot's own web applications, reuse that predicate and pin it for these two names.
- [x] [Rework] Claim 7. Add a wire test that sends `Enabled`, and then `Resource`, for a routine application through the `WebAppSave` `PUT` route, and asserts 403 `PROHIBITED.OCUPILOTROUTINEAPP` with nothing changed. Mutation: the arm's any-field clause removed, and the test reddens.
- [x] [Rework] Claim 2, the duplicate id rule. `foldfirst` duplicates `foldcase-firstpart` in both languages (`EntityRef.cls` :64, :94 and :310, `entity-ref.ts` :112, `screen-mirror.mjs`, and a test). Map `pct-class-access` to `foldcase-firstpart` and remove `foldfirst` everywhere, including its test leg. The lead reverts the AD-13 amendment.
- [x] [Rework] Claim 5. Move the new `Prohibited.cls` parameters out from between the covered-types doc and `TYPEWEBAPPLICATION` (around :252-262) to where their family's parameters sit. Fix the reference at about :258 to the nonexistent `ROUTINEAPPLICATIONROLEFIELDS`. The claim that the refusal sentence is missing from EXPERIENCE.md's Fixed strings was closed by the code review (row 475); verify it.
- [x] [Rework] Claim 6, trivia. `AdminPort.cls` around :1248 narrates "Task 1 as ruled Q4"; state what the code does instead (CLAUDE.md's prose discipline). Fix `PctAccessSave`'s header order: the code reads first. Remove the unused `pTarget` (`Prohibited.cls` around :4549), or record why it is part of a shared signature.
- [x] [Rework] Claims 3 and 4, both closed by the code review: the one-home rule restored over the whole tree, the tests using `ReasonFor`; and the tab re-reading after a Delete, pinned by the browser Delete leg. Verify both against the current tree and record them; change nothing unless they are open.

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
- **P10 — id rule.** `pct-class-access` takes `foldcase-firstpart`, pinned by the id-rule table in `ui/tools/screen-mirror.test.mjs`.
- **P11 — mutations.** On `ocupilot-ci`, run one at a time with recompile and revert, each observed red and the tree byte-identical after revert: the System refusal (`StateDiff` and the port refusal), the percent-sign shape check, and the `Enabled` clause of the routine arm.
- **P12 — probe cleanup.** `OnAfterOneTest` in the `WebAppPctAccess` test removes any `%OcuProbe1810*` entry on both applications and any probe-created entry, so a mutation cannot leave one behind.

### Review Findings

Code review 2026-10-09 (four layers, `full-opus`): 67 raw rows; 15 entries survive grouping and rejection (med 3, low 12), plus one med the stage measured. Fields: severity, fix-risk, footprint, spec-status.

- [x] [Review][Patch] The `OCUPILOTROUTINEAPP` sentence is published nowhere, so its two test classes quote a literal and pass 4 loosened the one-home test for every code to admit them (only this sentence was quoted by a test class) [src/OcuPilot/Test/Prohibited.cls:783] — med; fix-risk low (DW-1598's own idiom); in-story; clear (AC4 "published sentence", Task 14 `RefusalCopy:109`). Fix: publish it in EXPERIENCE.md :475 and `strings.ts`, add the `KERNEL_REFUSALS` and `RefusalCopy` rows, compare the tests against the kernel parameter, restore the rule over the whole tree.
- [x] [Review][Patch] The Percent class access tab is not re-read after a confirmed Delete or an agent's confirmed write: its sink has no `applied` and nothing subscribes to `ChangeBus` (AD-14) [ui/src/app/areas/web-applications/web-app-class-access-tab.ts:213] — med; low; in-story; clear (Task 11).
- [x] [Review][Patch] `OwnRoutineApplicationWire` restores neither routine application, though its legs reach `WebApp.App` writes a regressed arm lets through [src/OcuPilot/Test/OwnRoutineApplicationWire.cls:56] — med; low; in-story; clear (Rule 30). The agent `MatchRoles` payload keeps `:%All`: a replacing set without it would cut OcuPilot's own escalation mid-test under that regression.
- [x] [Review][Patch] The endpoint legs' "vendor was not reached" reads cannot differ on this build: `Security.PrivilegedRoutine` `PUT` and `DELETE` are outside `MUTATINGTYPES`, so a mutated arm stops at 501; the class header, two mutation notes and two Verification lines say the vendor is reached [src/OcuPilot/Test/OwnRoutineApplication.cls:6] — low; low; in-story; clear.
- [x] [Review][Patch] No leg shows the arm leaves an unlisted change (a `Description`) of a routine application unrefused; a re-enable cannot be asked of an enabled application without disabling it, so it has no leg [src/OcuPilot/Test/OwnRoutineApplication.cls:175] — low; low; in-story; clear.
- [x] [Review][Patch] The tab draws `true`/`false`, gives its table no name and every row's Delete the same label, and shows the empty sentence before its first read answers [ui/src/app/areas/web-applications/web-app-class-access-tab.ts:131] — low; low; in-story; clear.
- [x] [Review][Patch] No unit leg pins the dialog's posted `AllowType` and `AllowAccess`, or the tab's re-read when its application changes [ui/src/app/areas/web-applications/web-app-class-access-dialog.spec.ts:63] — low; low; in-story; clear.
- [x] [Review][Patch] `SaveHoldCoverage` holds no key for the third composite-id create Save, `POST /web-app/pct-access` [src/OcuPilot/Test/SaveHoldCoverage.cls:75] — low; low; in-epic test file; clear.
- [x] [Review][Patch] AC2's create `Snippet` is never asserted, and the agent leg's mutation note names a mutation run 111 did not apply [src/OcuPilot/Test/WebAppPctAccess.cls:336] — low; low; in-story; clear.
- [x] [Review][Patch] The two `SurfaceCoverage` tool rows say the tools' mint is "not yet exercised by a test" [src/OcuPilot/Test/SurfaceCoverage.cls:329] — low; low; in-story rows; clear.
- [x] [Review][Patch] Wrong doc text: `Prohibited.cls` (the covered-types doc moved onto the new parameter, `ROUTINEAPPLICATIONROLEFIELDS` named, `RefusesDeleteBeforeState` "before any state is read"), `PctAccessSave` (order), `PctAccessError` ("four" codes), `WebAppPctAccessList` (`foldcase-firstpart`), the dialog (`Prohibited` agrees), and "thirty-three" or "forty-six" beside the 34 codes and 51 types [src/OcuPilot/Kernel/Proposal/Prohibited.cls:252] — low; low; in-story; clear.
- [x] [Review][Defer] Code and entity-type counts asserted as literals outside their roster pins (Task 14 bumped them) [src/OcuPilot/Test/AuditingUpdate.cls:505] — deferred: pre-existing pattern, occurrence on DW-2202 (Story 23.5).
- [x] [Review][Defer] A web-application write naming a privileged routine application reaches `WebApp.App` `PUT`, which answers `#799` at 500 and logs at severity 2; only OcuPilot's own two are refused before it [src/OcuPilot/Kernel/Proposal/Prohibited.cls:1426] — med; low; in-epic; routed DW-2252 owner 18.31 (measured under run 587).
- [x] [Review][Defer] `STATE`'s any-case application match has no leg [src/OcuPilot/Port/PctAccessPort.cls:143] — low; wontfix-accepted, reopen_if a `STATE` of an entry named with a re-cased application answers 404 while the list holds it (DW-2249).
- [x] [Review][Defer] `POST /web-app/pct-access` has no least-privileged denial leg [src/OcuPilot/Area/WebApp/PctAccessSave.cls:195] — low; not a two-way door (probe principals); wontfix-accepted, reopen_if the route answers anything but 403 naming the pair for a principal without `%DB_IRISSYS:READ` (DW-2250).
- [x] [Review][Defer] `ExplorerWire`'s class read leg exercises the field bound on one doc block (`Limits.cls` `PROVIDERCALLSECONDS`, 1,590 characters); it still pins rows, no document, the defaults and the bound [src/OcuPilot/Test/ExplorerWire.cls:193] — low; wontfix-accepted, reopen_if `Limits.cls` holds no doc block over 1,000 characters (DW-2251).

**Rejected** (one line each):

- `false` The Delete on a system row starts the typed-name flow: `startFor` reads the action's `system-pct-access` rule and refuses through the sink before any dialog.
- `false` A dotless `AllowPrefix` reads absent: measured, the vendor stores `%OcuProbe1810Pfx` as given and `STATE` answers 200.
- `false` A list row without `System`: the vendor's row always carries it (measured `{"AllowAccess":true,"System":true}`).
- `false` The browser Delete clicks before the button is released: `onConfirm` reads the `matches` computed, set synchronously on the input event.
- `false` The `%`-class writes may be unaudited (AD-15): measured, a `PUT` and a `DELETE` each raise `%System/%Security/ApplicationChange`.
- `false` Tests rely on `/csp/user` and the vendor's system entries (Rule 30): both ship on every fresh instance; the rule's failure mode is state a sibling test made.
- `false` The other `PCTACCESS.*` sentences are missing from EXPERIENCE.md: area violation sentences are not published by convention (`UserCopyError`, `SuperserverError`).
- `false` Shape refusals are not on their field: the codes name the field (pass-4 refutation stands).
- `false` Every wire leg needs its own mutation line: Rule 19 asks one per AC, and AC4's are recorded.
- `by-design` A system delete answers `TOOL.ARGUMENTS`, not `PCTACCESS.SYSTEM`: Task 8 puts the refusal in `StateDiff`, which answers its sentence that way; the port's 409 backs it.
- `by-design` `Resource`, and a `PUT` that empties `Routines`: settled at 18.31's gate (spec gate); the endpoint answers 501 on this build.
- `by-design` The route breaks the `/web-applications/` prefix (Task 10).
- `low` The editor Save has no routine-arm leg: `WebAppSave` and `WebAppWeakening` pin the Save's `Prohibits` call, and the arm is pinned in the kernel.
- `low` Scope wording for an `all-applications` delete, allow-type labels, a stale read racing a newer one, a re-cased `All-Applications`, a `LIST` failure inside `Entry`, a non-boolean `AllowAccess`'s sentence, `PUBLISHED_PROBLEMS` without the system sentence: rare, and each fix adds wording, a branch or a parameter.
- `low` `ROUTINEAPPBIT` literal, `"Enabled,"` literal, unused `pTarget`, `SnippetForm` override, prompt 3's group, `$IsObject` guards, the dialog spec's sample sentence, `strings.ts` comment refs: cosmetic, no reader misled.
- `low` A truncated read is not flagged on the tab: needs over 200 entries for one application.
- `low` Spec and cycle-log bookkeeping, the Auto Run Result's S0 line, the fe8e3832 message: the fix edits the spec or history; this review records the measured S0 below.

## Spec Change Log

- 2026-10-09, lead: the owner answered the scope with "Refuse every change". The Intent's arm and matrix row now say every change, matching the delivered arm. In the spine, AD-10's sentence is restated and AD-13's `foldfirst` amendment removed.
- 2026-10-09, lead: re-opened `in-progress` after code review, for the orchestrator's quality review claims. Implement runs on Sonnet: the owner ended the Haiku trial. Feature `98ab67bf` (Story 20.21) is merged in.
- 2026-10-09, lead: re-opened `in-progress` for pass 4 after the runner's full sweep (4 reds, all from this story), with pass 3's two deferred items. Implement passes so far: three.
- 2026-10-09, lead: pass 2 closed the four rework items and returned `blocked` on the endpoint arm. Decision 3 is (a), which ruling Q4 already requires. Pass 3's scope is the four items above; pass 2's review block was moved under the Review Triage Log.
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

### 2026-10-09 — Review pass (pass 2, follow-up after the rework)

- verdicts: 22 findings — high 0, medium 11, low 6, false 3, maybe-false 2
- findings:
  - `[medium]` `[intent_gap]` Verification-gap and intent layers: `Security.PrivilegedRoutine` PUT and DELETE naming `OcuPilotState` or `OcuPilotIdentity` reach the vendor unguarded. `PrivilegedRoutineGuard` refuses only web-application names (routine-type names pass by design), and `AdminPort` never consults `Prohibited`. The Intent requires the arm on every path, including this endpoint. Verified in code; latent, because grep finds no production caller of that endpoint today (the smoke test, the task read and the token and OAuth ports name other endpoints). Not patched: this is a decision, see the blocking condition. No test sends PUT or DELETE naming a routine (`OwnRoutineApplication` line 96 onward uses `/csp/user` only).
  - `[medium]` `[intent_gap]` Intent layer, same root cause: the endpoint carries no AD-10 arm, so the spec's "every path" reading and the diff's kernel-only arm diverge at `AdminPort.cls` `PRIVROUTINEENDPOINT`.
  - `[medium]` `[intent_gap]` Intent layer, same root cause: a `Roles` change on the routine application has no tool-path test, and the endpoint refuses it by nothing. `Roles` is not reachable through the arm's own `web-application` type.
  - `[medium]` `[patch]` (not applied: intent gap halts the pass first) `foldfirst` branch of `EntityRef.NormalizedId` (line 310) has no ObjectScript pin. Verified by grep: `foldfirst` and `RULEFOLDFIRST` appear only in `EntityRef.cls`, and only the TypeScript copy is pinned. Fix: an assertion in `WebAppPctAccess` with the mutation "remove the branch".
  - `[low]` `[patch]` (not applied) `OwnRoutineApplicationWire.AssertRefused` compares the envelope to `Prohibited.ReasonFor`, which is the same sentence the envelope was built from; the published sentence is not pinned literally. Fix: compare against the literal text.
  - `[low]` `[patch]` (not applied) `OwnRoutineApplication` PUT leg (line 110 to 114) compares `WebAppJSON` before and after, and both read `""` if the read fails, so "the vendor was not reached" can pass without a read. Fix: an `AssertNotEquals(tBefore, "")` guard.
  - `[low]` `[patch]` (not applied) `PctAccessSaveWire.TestAnUnexpectedKeyIsRefused` asserts only a 400 and a JSON content type, so a 400 from another cause passes. Fix: assert the refusal code.
  - `[medium]` `[patch]` (not applied) AC1 Delete leg's mutation (drop `delete` from `startFor`) is named but not run.
  - `[medium]` `[patch]` (not applied) AC2 has no mutation for the Snippet leg, and the `webapp` mint mutation (line 213) is not run.
  - `[medium]` `[patch]` (not applied) AC3's client `aria-disabled` half has no mutation line in `## Verification`.
  - `[medium]` `[patch]` (not applied) AC4's read-back and sentence legs have no mutation line.
  - `[medium]` `[patch]` (not applied) AC5's DELETE leg and its "still reads" leg have no mutation line.
  - `[low]` `[reject]` The DELETE leg of `TestPrivilegedRoutineEndpointRefusesAWebApp` sends a real vendor DELETE to `/csp/user` if its guard is removed. That is the mutation's purpose and runs only on the throwaway, so it is not a defect.
  - `[false]` `[reject]` `ApplicationHeld` answers 422 for a vendor failure. The doc comment states that behavior; it is a design note, not a gap.
  - `[low]` `[patch]` (not applied) The `PCTACCESS.APPLICATION`, `ALLOWTYPE`, `CLASS`, `BADID`, `NOTFOUND` and `PRIVROUTINETYPE` sentences in `PctAccessError.cls` are never asserted, only their codes.
  - `[maybe-false]` `[reject]` `tResult.System` against 0 at `WebAppPctAccess` line 131 may pass on an empty value. Reviewer said redundant with the agent delete leg; not verified, and the harm is a test that is weaker than it looks, not a defect in the product.
  - `[low]` `[reject]` The confirm-path refusal is inferred to come from `Prohibits` at write time rather than the early 403. Inference; the confirm arm is covered by the seeded-row leg, so the claim is not a defect.
  - `[medium]` `[patch]` (not applied) Rule 19 mutations recorded as not run: P2, P3 PUT leg, P4, P5, P6, P8, P10 and the browser `startFor` leg.
  - `[low]` `[reject]` The spec title says "spec-based REST services", which is the story's original scope. The Intent records the split of 18.30 to 18.32; a title edit is not worth a review finding.
  - `[false]` `[reject]` Fixed-strings count against the bound. `ui/tools/strings.test.mjs` asserts at most 3000 and `npm run test:tools` is 1903/1903 green on this tree, so the count is within the bound. Measured by the rework subagent at 2980.
  - `[false]` `[reject]` The intent layer's "%-class surface" check found a close match between intent and diff; no divergence, so no finding.

The four intent_gap rows are one group (one root cause: the endpoint carries no AD-10 arm). Lower entries are moot under the intent_gap branch, so no patch was applied and no code was reverted.

### 2026-10-09 — Review pass (pass 3, first review of the rework)

- verdicts: 18 findings — high 0, medium 2, low 10, false 3, maybe-false 3
- findings:
  - `[medium]` `[patch]` Verification-gap: the agent path's `MatchRoles` change to `OcuPilotState` or `OcuPilotIdentity` had no pinning test. Fix F1: a leg in `TestTheAgentConfirmRefusesEveryArmedAction` mints the `MatchRoles` change and expects the confirm refusal 403; mutation `ROUTINEAPPLICATIONFIELDS` drops `MatchRoles` reddens it (runs 126, 127; green 128). The class header is corrected.
  - `[low]` `[patch]` Verification-gap: AC3's `aria-disabled` unit half had no recorded mutation. Fix F3: the `SYSTEM_PCT_ACCESS_RULE` branch returns `''`; the tab spec goes red; green 4/4.
  - `[low]` `[patch]` Verification-gap: AC5's GET and DELETE guard legs had no recorded mutation. Fix F4: GET removed from the list (run 132 red, 133 green); DELETE mutated by its status 409 to 410 (run 134 red, 135 green), because removing it would send a vendor delete of `/csp/user`.
  - `[low]` `[patch]` Verification-gap: AC1's `,all-applications` read criterion and the Add post path had no recorded mutation. Fix F5: both run, the tab spec and the browser Add leg red, reverted and green.
  - `[low]` `[patch]` Verification-gap: AC4's wire leg mutation named in its docstring was never run. Fix F6: the field-loop branch of `RoutineApplicationChanges` disabled; the screen `add-matching-role` legs go red (run 136), green 137.
  - `[medium]` `[patch]` Verification-gap: the `PctAccessPort` trailing-slash clause answering `PCTACCESS.APPLICATION` was untested. Fix F2: `TestTrailingSlashApplicationRefused` asserts 422 with no vendor delete; mutation run 130 red, 131 green (10/10).
  - `[low]` `[patch]` Verification-gap: the `Enabled` sentence in the `RoutineEndpointRefused` comment said a PUT naming `Enabled` is refused; the code refuses only `Enabled` false. Fix F7: the comment says what the code does.
  - `[maybe-false]` `[defer]` Verification-gap, inference: a PUT omitting `MatchRoles` or `Roles` may reach the vendor. Already the second `deferred:` item; not appended again.
  - `[low]` `[patch]` Verification-gap: the `self-protection.ts` JSDoc for `SYSTEM_PCT_ACCESS_RULE` sat between the ECP block and its constants, orphaning the ECP doc. Fix F8: each block sits above its own constant; `self-protection.test.mjs` 36/36.
  - `[low]` `[reject]` Verification-gap: the Delete click on an `aria-disabled` system row opens the dialog, and the refusal arrives only after confirm. The port refuses before the vendor, as the spec requires; a client guard would be more than a correction.
  - `[maybe-false]` `[reject]` Verification-gap: the Fixed-strings count of 2980 was not re-run by this review. The pass-3 handoff measured it with a temporary copy of the test, since removed; the bound stays at 3000.
  - `[false]` `[reject]` Intent layer: the AD-10 amendment is absent from the diff. The spine carries the "Story 18.10 spec gate" AMENDED blocks (lines 114, 363, 442, 898, 1023) in committed history, so the diff need not contain them.
  - `[low]` `[reject]` Intent layer: the endpoint arm refuses a field the body names whether or not its value differs. The intent admits both readings of "change", and over-refusal is the safe side; a value comparison would be more than a correction.
  - `[false]` `[reject]` Intent layer: the descriptive divergence about test surfaces (kernel predicate, screen route, vendor-untouched read). It restates the MatchRoles gap above and the non-empty before-read already pinned in pass 3; no separate defect.
  - `[low]` `[reject]` Intent layer: the endpoint refuses a GET of a web application with 404, beyond the matrix. The spine amendment (line 114) states that refusal, so it is intended.
  - `[false]` `[reject]` Intent layer: `webapp.pctaccess.delete` is disabled by default. The AD-22 ruling is create enabled, delete destructive and disabled.
  - `[low]` `[reject]` Intent layer: the spec title still names spec-based REST services. The title mirrors the stories.yaml entry, and changing it would desynchronize the registry.
  - `[maybe-false]` `[reject]` Intent layer: the editor's shape handling is not established from the diff. The matrix row is met at `PctAccessPort.Shape`, which refuses on its field; the dialog's own behavior is not in the matrix.

### 2026-10-09 — Review pass (pass 4, verification-gap and intent-alignment)

- verdicts: 11 findings — high 0, medium 0, low 6, false 4, maybe-false 0
- findings:
  - `[low]` `[patch]` `GovernanceBaseline`'s exact-equality leg reddens on the `webapp.pctaccess.delete` flip, but no `mutation:` line records it — patched: the pass-4 Verification now records the run (553 red on `TestThePurgeIsTheOneDisabledLine`, reverted byte-identical, 554 green).
  - `[low]` `[patch]` `WebAppPctAccess` `Prohibited.cls:250` `COVEREDTYPES` row (`pct-class-access`) is load-bearing and had no recorded mutation — patched: removing the entry reddens run 556 on `TestAgentCreateAndDeleteMintConfirmAndReadBack`; reverted byte-identical, run 557 green.
  - `[low]` `[patch]` `OwnRoutineApplicationWire.cls` mutation comment still names `WebAppDelete.RefusedBeforeState` — patched: the comment now names `Prohibited.RefusesDeleteBeforeState`, where the seam lives.
  - `[low]` `[reject]` `ExplorerWire` explorer read leg asserts row count, not the `Description` text — rejected: the leg's purpose (no document, the field bound, rows present) is asserted; pinning the text would tie the test to production wording, which is more than a direct correction.
  - `[low]` `[reject]` `ToolDispatch` `||$ListFind` spacing — rejected: cosmetic; the line compiles and no reader is misled.
  - `[false]` `[reject]` `Roles` has no reachable path, so the arm's `Roles` leg is kernel-only — refuted as a defect: no route, confirm or vendor body writes `Roles` on this build (`Security.Applications` has no `Roles` property; Design Notes (a)), so no change can reach the vendor through it.
  - `[false]` `[reject]` the shape check lives only in `PctAccessPort`, so a malformed class is refused at confirm and not on the field — refuted: the codes name the field (`PCTACCESS.ALLOWTYPE`, `PCTACCESS.CLASS`, Task 5), and the refusal is before the vendor.
  - `[false]` `[reject]` a `PUT` naming an absent `/csp/` path reaches the vendor — refuted: `AdminPort` answers 501 `PORT.NOTIMPLEMENTED` for `Security.PrivilegedRoutine` `PUT` and `DELETE` on an absent name before any vendor call (measured on `ocupilot-ci` this pass), so OcuPilot never reaches the vendor for it.
  - `[false]` `[reject]` a `MatchRoles` omitted from a `PUT` may be emptied — refuted by the endpoint's `MergeJsonAndProperties` (sets `MatchRoles` only when the body carries it) and the probe (Design Notes (a)). The reviewer's note that the pass-3 Auto Run Result listed it as residual is a spec-text point, resolved by the pass-4 Auto Run Result, which no longer carries it.
  - `[low]` `[reject]` `ApplicationHeld` reads any failed `WebApp.App` `GET` as an absent application — rejected: a fault-versus-absent distinction is more than a direct correction, and the harm is a misleading message on a rare transient read.
  - `[false]` `[reject]` the `Roles` and `Disables` clauses of the route and confirm legs — refuted: the route and confirm legs name `MatchRoles` and `Enabled` only, and no route carries `Roles`; the kernel and endpoint legs cover `Roles`.

### 2026-10-09 — Orchestrator quality review

- verdicts: 7 claims — 5 confirmed and patched (1, 7, 2, 5, 6), 2 confirmed as closed earlier by the code review (3, 4); one sub-claim refuted (claim 5, the nonexistent parameter name)
- findings:
  - `[confirmed]` Claim 1, the arm's scope. Before this pass `Prohibits` refused a delete (before `Target()`), a disable and a change to `MatchRoles` or `Roles`, and passed every other change: `OwnRoutineApplication.TestAnUnlistedChangeIsNotRefused` pinned a `Description` change as not refused, and a `Resource`, a `Routines` or a create reached `WebApplication`'s non-serving branch, which permits them. Patched to the ruling: `Prohibits` refuses every write to either application before `Target()` (one condition, no field list; the shape of `WebApplication`'s last arm, `SERVINGPATH`, for OcuPilot's own web applications -- that arm keys on `pServes` and the install roster, so the shape is reused, not the predicate). `RoutineEndpointRefused` refuses every call but a `GET`; `RefusesDeleteBeforeState` is `RefusesBeforeState`, and `WebAppUpdate` overrides `RefusedBeforeState` as `WebAppDelete` does (the agent's mint and the screen action answer 403 before storing or sending anything). `WebAppCreate` does not: the mint skips the early answer for a create, its route and confirm ask the set, and `OcuPilotState` fails the name-shape rule first. The `Roles` pins are removed: neither application carries `Roles` (Design Notes (a); `Security.Applications.Get` reads none for either), so `TestRolesRefused`, `TestEndpointRolesRefused`, the `ROUTINEAPPLICATIONFIELDS` parameter, `RoutineApplicationChanges` and the `Roles` comparison in `PutBack` are gone. Evidence: mutations in Verification (runs 38, 39, 41, 43, 45, 47, 49), each red and reverted byte-identical.
  - `[confirmed]` Claim 1, text that now disagrees with the code (the spine and the Intent are reported, not edited): AD-10's "OcuPilot's own privileged routine applications" amendment (spine line 363) lists a delete, a disable and `MatchRoles` or `Roles`, and says `Routines` and `Resource` are settled at 18.31's gate; the arm now refuses every write. The refusal sentence (`OCUPILOTROUTINEAPPREASON`, EXPERIENCE.md row 475, `strings.ts` `routineAppRefusalOcuPilot`) named a delete, a disable and a roles change only; it now ends "cannot be deleted, disabled or changed.", edited in place at the three sites (row 475 keeps its line). The Intent's "any change to their `MatchRoles` or `Roles`" and the "For the lead" AD-10 text are narrower than the arm.
  - `[confirmed]` Claim 7. No wire leg sent a `PUT` through `WebAppSave`. Added `OwnRoutineApplicationWire.TestTheEditorSaveRefusesEveryField`: `Enabled` false, then a `Resource` that differs from the stored one, for each application; 403 `PROHIBITED.OCUPILOTROUTINEAPP`, the published sentence, the application reading back as before. Mutation: the arm restricted to a delete reddens both legs (run 39); the vendor refuses a write to a routine application and changes nothing (Verification, measurement), so the application still reads as it did.
  - `[confirmed]` Claim 2. `foldfirst` and `foldcase-firstpart` were the same branch in `EntityRef.NormalizedId` (one `Or` condition) and the same function in `entity-ref.ts`. `pct-class-access` maps to `foldcase-firstpart`; `foldfirst` is removed from `EntityRef.cls` (`IDRULES`, `IDRULENAMES`, `RULEFOLDFIRST`, the branch), `entity-ref.ts`, `screen-mirror.mjs` (`IMPLEMENTED_ID_RULES`), `screens.generated.ts` (regenerated), `screen-mirror.test.mjs` (the table row and the two rule lists), `entity-ref.test.mjs` (its leg) and `WebAppPctAccess` (`TestFoldFirstFoldsOnlyTheApplication`); two comments that named it say `foldcase-firstpart`. The mapping stays pinned by `screen-mirror.test.mjs`'s id-rule table. Spine line 442 (AD-13, "the `foldfirst` id rule") now disagrees with the code: the lead reverts it.
  - `[confirmed]` Claim 5, position. `OCUPILOTROUTINEAPP` and its sentence sat between `COVEREDTYPES` and `TYPEWEBAPPLICATION`, with `TYPEPCTACCESS` and `PCTACCESSFIELD`. The code and its sentence now follow `PRIVILEGEGRANTREASON`, the web-application arms; the type and its field follow `TYPEMFTCONNECTION`, the other `TYPE*` parameters.
  - `[refuted]` Claim 5, "the reference at about :258 to the nonexistent `ROUTINEAPPLICATIONROLEFIELDS`". The tree named `ROUTINEAPPLICATIONFIELDS`, which existed (the code review fixed the name); the parameter is now removed with Claim 1 and its doc says what the arm refuses.
  - `[confirmed]` Claim 5, the sentence missing from EXPERIENCE.md's Fixed strings: closed by the code review; row 475 holds it (grep), and `self-protection.test.mjs` pins it to the kernel parameter (`KERNEL_REFUSALS`).
  - `[confirmed]` Claim 6, `AdminPort.cls` narrating "Task 1 as ruled Q4": replaced with what the code does.
  - `[confirmed]` Claim 6, `PctAccessSave`'s header order: at `f33263ed` it listed AD-10's set before the read of the entry, and the code reads the entry first; closed by the code review (`c2812a9f`). Checked against `HandleCreate` and `Create`: pairs, body, hold, read (shape, then `EXISTS`), set, write, read-back, as the header says.
  - `[confirmed]` Claim 6, the unused `pTarget` of `RoutineApplicationChanges`: removed with the method (Claim 1).
  - `[confirmed]` Claim 3, closed by the code review: `Prohibited.TestTheSetHasOneHomeAndOneSentencePerCode` counts each sentence over every class in the tree, test classes included (against the baseline `b4b6ffb8` only its count of codes differs), and no test class spells the routine sentence (grep: `Prohibited.cls`, `strings.ts` and EXPERIENCE.md alone). Run 54 green.
  - `[confirmed]` Claim 4, closed by the code review: the tab's sink carries `applied: () => void this.load()` and the tab subscribes to `ChangeBus`; the browser Delete leg waits for the row to leave the table. The class-access browser spec is 3/3 on the rebuilt, redeployed bundle, and the tab spec is in the 2763 passing component tests.

### 2026-10-09 — Review pass (pass 5, after the orchestrator quality review rework)

- verdicts: 14 findings — high 0, medium 0, low 12, false 2, maybe-false 0
- findings:
  - `[low]` `[patch]` Verification-gap: the delete legs and the two-name match had no mutation line valid on the current tree (QA runs 563 and 564 name a removed clause and `Roles` legs) — patched: skip-delete, state-name, identity-name and field-list mutations run and recorded (runs 66, 67, 68, 71, 72), each reverted byte-identical.
  - `[low]` `[patch]` Verification-gap: the `GET` exemption of `RoutineEndpointRefused` had no mutation line and was read for OcuPilotState only — patched: `TestPrivilegedRoutineEndpointRefusesAWebApp` reads both applications; dropping the exemption reddens it (run 73).
  - `[low]` `[reject]` Verification-gap: the "reads back unchanged" assertions cannot fail under any mutation that can be run, since the vendor refuses a write to a routine application and the port answers 501 for the endpoint types — rejected: the 403, code and sentence assertions pin the behavior and redden under every recorded mutation; the equality still fails for a delete or a changed vendor, and the destructive delete mutation is deliberately not run on the real applications. The fix would edit the spec's wording.
  - `[low]` `[patch]` Verification-gap, other: `TestAnyOtherWriteIsRefused`'s comment claimed a leg for a change that restates the stored value — patched: the comment names what the leg covers.
  - `[low]` `[patch]` Verification-gap, other: descriptions still stating the narrow arm (EXPERIENCE.md row 475's usage cell, `self-protection.test.mjs` comment) — patched in place; the Intent, the matrix and AC4 stay as written (the intent block is read-only and AC4 remains true of the wider arm).
  - `[false]` `[reject]` Verification-gap, other: no class ran an ordinary application's update through `Mint` or `ScreenAction` after `WebAppUpdate.RefusedBeforeState` was added — refuted: `RefusesBeforeState` answers 0 for any other application, and `ProhibitedRoute` (24/24, run 76, its row actions over the wire) and `WebAppWeakening` (6/6, run 77) are green.
  - `[low]` `[reject]` Verification-gap, other: the create refusal is pinned at the kernel only — rejected: both create paths (`Create.cls` lines 168 and 250) refuse a name without a leading `/` first (`NameIsUsable`), which `OcuPilotState` and `OcuPilotIdentity` are, so no create reaches the arm over the wire; a wire leg would add a test for an unreachable path.
  - `[low]` `[reject]` Intent-alignment: the diff refuses a superset of the Intent's four-item list (reading R2) — rejected: the rework item for Claim 1 names that reading, so exactly one reading is in force; it is not an intent gap.
  - `[low]` `[reject]` Intent-alignment: the Intent's text and the spine's AD-10 (line 363) and AD-13 (line 442) are narrower than, or name a rule not in, the code — rejected for this build: the intent block is read-only and the spine is the lead's under Rule 20; both are named in the final report.
  - `[low]` `[reject]` Intent-alignment: the endpoint legs call `AdminPort` directly and a mutated arm lands on the port's 501 — rejected: no HTTP route reaches the endpoint (Design Notes), and the legs read the status, the code and the sentence.
  - `[low]` `[reject]` Intent-alignment: the create has a kernel leg only — the same refusal as the create row above.
  - `[low]` `[reject]` Intent-alignment: "nothing sent" is not tested as a difference — the same refusal as the unchanged-read row above.
  - `[low]` `[reject]` Intent-alignment: the `pct-class-access` fold lost its behavior test and keeps the id-rule table pin — rejected: Claim 2 removes that leg by instruction; the fold is exercised by `SaveHoldCoverage`'s re-cased Save leg and by `Test.EntityRef` on the shared branch.
  - `[false]` `[reject]` Intent-alignment: the matrix rows for the endpoint type check and the `%`-class access shapes are not exercised by this diff — refuted: `OwnRoutineApplication.TestPrivilegedRoutineEndpointRefusesAWebApp` and `WebAppPctAccess.TestShapeRefused` pin them from earlier passes and ran green here (runs 74 and 53).

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
- The arm lists no field: it refuses every write to either application, as the last arm of `WebApplication` refuses every write to one of OcuPilot's own web applications.

**Pass 4 settlements (measured on `ocupilot-ci`, 2026-10-09, probe created and removed by the measurement):**

- (a) The vendor's `PUT` on `Security.PrivilegedRoutine` (`%Api.Admin.Endpoints.Security.PrivilegedRoutine`'s `MergeJsonAndProperties`) sets `MatchRoles` only when the body carries it. An application created with `MatchRoles` `%Manager:%All`, then `PUT` with `{"Enabled":true,"Description":...}`, still reads `MatchRoles` `%Manager:%All`: an omitted `MatchRoles` is not emptied, so no omitted-key clause is needed. The same `PUT` always sets `Routines`, which reads empty afterwards (the AD-4 behavior, not a `MatchRoles` or `Roles` question). `Roles` is not in the endpoint's body at all, and `Security.Applications` has no `Roles` property on this build: a `Roles` value written through `Security.Applications.Modify` did not persist, so there is no `Roles` an omitted key could empty. The arm lists no field, so it has no `Roles` leg.
- (b) No path other than `PctAccessPort` reaches `WebApp.PctClassAccess` writes. Grep of `src/OcuPilot`: the only `ENDPOINT` that names it is `PctAccessPort`'s; the `POST /web-app/pct-access` route is `PctAccessSave`; `OcuPilot.Port.AdminRoutes` maps its `PUT` and `DELETE` rows, which only `AdminPort`'s transport reads for the calls `PctAccessPort` makes. (inference: no other caller passes a request-supplied endpoint to `AdminPort.Invoke`, from a grep of its callers, which pass a literal endpoint each.) The try-it console refuses `/api/admin` writes, as recorded in Task 0 above. No shape check is added to a second path.

**Governing ADs:** AD-2, 3, 5, 8, 9, 10, 13, 15, 22, 29, 36, 44, 51, 52, 53, 54, 55, 58, 59.

**Consumed-by:** 18.31 (`OwnRoutineApplication`, the type check) and 18.12 (`webapp.pctaccess.*`). **Consumes:** 9.2, 5.5 and 7.1. **Integration ACs:** the browser spec and `Test/WebAppPctAccess`.

**Ledger:** DW-2239 is Tasks 1, 3 and 13. Nothing builds on an owner-hold entry.

**For the lead** (Rule 20):

- **AD-10:** "**OcuPilot's own privileged routine applications** (Story 18.10, DW-2239): every write to `OcuPilotState` or `OcuPilotIdentity` -- a delete, a disable, a change to any field -- is refused `PROHIBITED.OCUPILOTROUTINEAPP` from either caller, through every tool and endpoint that reaches them, as AD-9's escalation."
- **Also:** AD-2 (the type check), AD-13 (`pct-class-access` takes `foldcase-firstpart`; no new rule), AD-44 (the create's `CLASSICPAGES`), AD-51 (`STATE`).
- **Settled:** the arm refuses every write to either application (orchestrator quality review, Claim 1). The AD-10, AD-2, AD-13, AD-44 and AD-51 amendments are written; the lead restates AD-10 as above and removes AD-13's `foldfirst`.

**Baseline for 18.30-18.32** (first plan, 2026-10-08; pairs `%Admin_Secure:U` and `%DB_IRISSYS:R`):

- `DocDB`: an upsert keeping omitted keys; stores absent names; creates no database.
- `Security.PrivilegedRoutine`: an upsert emptying an omitted `Routines` (AD-4); writes any application type; `LIST` answers `Enabled` false.
- REST `POST`: an upsert compiling `.spec`, `.disp`, `.impl` (`DELETE` keeps `.impl`); unaudited; needs `%Development:USE` and routines WRITE; fetches a string `swagger`.

## Verification

**Commands (loop),** one run at a time:

- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.OwnRoutineApplication` — a probe routine application stays unrefused. Mutations: restrict the arm to a `DELETE` → every other write's legs red; drop `IDENTITYAPPLICATION` → identity legs red; drop the type check → `GET` and `PUT` legs red.
- `--class OcuPilot.Test.WebAppPctAccess`, then each swept class. Mutations: drop `PUT` from `MUTATINGTYPES` → create red; drop the `System` refusal → system red; drop the `%` check → shape red; `pct-class-access` mapped to `foldcase` → the id-rule pins in `screen-mirror.test.mjs` red.
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
- `WebAppPctAccess.TestSystemEntryRefused` port-side System refusal (P11, pass 2): RUN. The delete goes through the seam `OcuPilot.Test.PctAccessVendorFault`, which counts a vendor `DELETE` and never sends it. Mutation: `If pType = "DELETE" {` -> `If 0 {` in `OcuPilot.Port.PctAccessPort`'s `Invoke`, with the seam recompiled; run 97 red on the vendor-count leg (one delete reached the vendor), then the 409 and `PCTACCESS.SYSTEM` legs. (Run 96, before the count leg moved ahead of the status leg, was red through an `<INVALID OREF>` after the 409 leg.) Reverted, `shasum` identical to the pre-mutation hash; run 98 green (7/7).
- `WebAppPctAccess.TestStateDiffRefusesAnUnknownOrigin` (P5): mutation: drops the `unassigned` branch of `StateDiff`; run 110, red on this leg, reverted byte-identical, green on the clean tree (run 119).
- `WebAppPctAccess.TestAgentCreateAndDeleteMintConfirmAndReadBack` (P4): mutation: `STATE` answers 200 for an absent entry, so the delete confirm reads `matches`; run 111, red on the agent and read-back legs (as applied, `STATE` raises an error for an absent entry rather than answering 200). Run 112 (snippet leg, `Snippet` answers `[]`) and run 113 (create verdict leg, `STATE` reports `AllowAccess` 0) are red. The snippet leg asserts `PctAccessPort.Snippet` directly, not the copy-out draft.
- `PctAccessSaveWire.TestAnExistingEntryIsRefusedAndNotWrittenAgain` (P6): mutation: removes the `EXISTS` branch in `PctAccessSave.Create`; run 109, red, reverted byte-identical, green on the clean tree (run 121).
- `OwnRoutineApplication.TestUnrelatedNotRefused` (P2) and `TestPrivilegedRoutineEndpointRefusesAWebApp` PUT leg (P3): mutation for P2 is `Ask` returning 0 without a status; for P3 the PUT branch of `PrivilegedRoutineGuard` removed. Run: P2 in run 108 (red on the negative leg's status assert, the only leg that asserts it); P3 in run 107 (`GET,DELETE` in the guard, red on the PUT leg). Both reverted byte-identical and green on the clean tree (runs 118 and 123).
- `OwnRoutineApplicationWire` (P1, pass 2, Decision 1): the screen route and the agent mint answer 403 `PROHIBITED.OCUPILOTROUTINEAPP` before the precondition (`Api/ScreenAction.cls` and `Kernel/Proposal/Mint.cls` call `RefusedBeforeState`, which `Screen/Tool/WebAppDelete.cls` overrides); the agent's stored delete is refused at its confirm. Run 91 green (2/2). Mutation: `WebAppDelete.RefusedBeforeState` `Quit 1` -> `Quit 0` in its routine branch; run 94 red, 2 of 2, both delete legs answering 400 `TOOL.ARGUMENTS` (the precondition). Reverted, `shasum` identical; run 95 green (2/2).
- `OwnRoutineApplicationWire` (P1, pass 2, Decision 1) also: `WebAppPctAccess` run 92 green (7/7) and `OwnRoutineApplication` run 93 green (7/7) on the unmutated tree.
- `ui/tools/self-protection.test.mjs` Story 18.10 pin (P8): mutation: changes one word of `REASONSYSTEM` in `PctAccessError.cls`; run with `node --test tools/self-protection.test.mjs` red (exit 1), reverted byte-identical, green (exit 0).
- P10: `pct-class-access` takes `foldcase-firstpart`; its pin is the id-rule table in `ui/tools/screen-mirror.test.mjs` (mutation in the quality-review block below).
- `web-applications-class-access.browser-spec.mjs` Delete leg (P7, pass 2, Decision 2): the dialog asks for the entry's `Class` as the row shows it (`TYPED_NAME_ROWS` in `ui/src/app/shell/screen-action-handler.ts`), and the leg waits for the action's POST answer before reading the instance. Unmutated, 3/3 green on the rebuilt, redeployed bundle. Mutation: the `WebAppPctAccessList` entry removed from `TYPED_NAME_ROWS`, rebuilt and redeployed; the class assertion goes red (the dialog asks for `/csp/user` U+0001 `AllowClass` U+0001 `%OcuProbe1810.Browser`). Reverted, `shasum` identical; rebuilt, redeployed, 3/3 green. The `drop delete from startFor` mutation of this leg was run in pass 3 (see Pass 3 below).
- `web-app-class-access-tab.spec.ts` (P7 side fix): fake handler gains `pending`; green.

**Blockers (pass 1; both closed in pass 2, see the Verification lines above):**

- **P1 delete legs.** Closed in pass 2 (Decision 1): the early 403 precedes the precondition on both routes; `OwnRoutineApplicationWire` green.
- **P1 MatchRoles on the agent path.** Closed in pass 4 (F1): `WebAppUpdate` settable fields include `MatchRoles`, so an agent proposal carries it; its confirm is refused 403 `PROHIBITED.OCUPILOTROUTINEAPP` (`OwnRoutineApplicationWire.TestTheAgentConfirmRefusesEveryArmedAction`). The screen route pins it (green).
- **P7 Delete.** Closed in pass 2 (Decision 2): the typed name is the entry's class; the browser Delete leg is green. The `app-screen-action-dialogs` mount from pass 1 is unchanged.

**Pass 3 (2026-10-09) pins and runs.** Every run on `ocupilot-ci`, one class or spec per call, after `load-ocupilot-ci.sh`. Each mutation was applied to the worktree source, loaded, run, then reverted from a saved copy and checked byte-identical before the next one.

- Clean tree: `OwnRoutineApplication` runs 99, 118 and 123 green (11/11); `WebAppPctAccess` runs 100 and 119 green (9/9); `OwnRoutineApplicationWire` runs 101 and 120 green (2/2); `PctAccessSaveWire` runs 102 and 121 green (3/3).
- `mutation` (endpoint DELETE leg, `TestEndpointDeleteRefused`): `RoutineEndpointRefused`'s `If pType = "DELETE" {` to `If 0 {`; run 103 red, 1 of 11.
- `mutation` (endpoint disable leg, `TestEndpointDisableRefused`): `Set tFields = "Enabled," _` to `Set tFields = `; run 104 red, 1 of 11.
- `mutation` (endpoint MatchRoles leg, `TestEndpointMatchRolesRefused`): `ROUTINEAPPLICATIONFIELDS` `"MatchRoles,Roles"` to `"Roles"`; run 105 red on it and on the kernel's `TestMatchRolesRefused`.
- `mutation` (endpoint Roles leg, `TestEndpointRolesRefused`): `ROUTINEAPPLICATIONFIELDS` to `"MatchRoles"`; run 106 red on it and on `TestRolesRefused`.
- `mutation` (P3, `TestPrivilegedRoutineEndpointRefusesAWebApp` PUT leg): `PrivilegedRoutineGuard` `"GET,PUT,DELETE"` to `"GET,DELETE"`; run 107 red.
- `mutation` (P2, `TestUnrelatedNotRefused`): `Ask` raises a forced `$$$ERROR` after the `Prohibits` call; run 108 red on that leg's status assert only.
- `mutation` (P6, `TestAnExistingEntryIsRefusedAndNotWrittenAgain`): `PctAccessSave` EXISTS branch `= 200` to `= 999`; run 109 red.
- `mutation` (P5, `TestStateDiffRefusesAnUnknownOrigin`): drop the `unassigned` branch of `StateDiff`; run 110 red.
- `mutation` (P4, agent create and delete mint): `PctAccessPort.State` `If '$IsObject(tEntry)` to `If 0`; run 111 red on the agent leg and `TestCreateReadDelete`.
- `mutation` (AC2 snippet leg): the delete `Snippet` answers `[]`; run 112 red on the snippet assertion.
- `mutation` (AC2 create verdict leg): `State` reports `AllowAccess` 0; run 113 red on the create verdict and the read-back grant.
- `mutation` (P10, `WebAppPctAccess.TestFoldFirstFoldsOnlyTheApplication`): `EntityRef.NormalizedId` `|| (tRule = ..#RULEFOLDFIRST)` to `|| 0`; run 114 red.
- `mutation` (`TestRefusalSentencesArePublished`): `PctAccessError` `REASONALLOWTYPE` "Choose" to "Pick"; run 115 red.
- `mutation` (`PctAccessSaveWire.TestAnUnexpectedKeyIsRefused`, code leg): the unexpected-field `Render` answers `#BADREQUEST`; run 116 red.
- `mutation` (the arm's published sentence, `ui/tools/self-protection.test.mjs` `KERNEL_REFUSALS`): `OCUPILOTROUTINEAPPREASON` "cannot" to "can not"; `node --test` red on "each kernel refusal is published verbatim in Fixed strings" (code review). The wire and endpoint legs compare the envelope with that parameter.
- `mutation` (endpoint vendor-untouched read, `AssertEndpointRefused`): the before-read `Set tBefore = ""`; run 122 red on the four endpoint legs.
- `mutation` (P8, `self-protection.test.mjs`): one word of `REASONSYSTEM`; `node --test` red, exit 1, reverted, exit 0.
- `mutation` (AC1 and P7, browser): `startFor` guarded by `if (Math.random() < 0)` in `web-app-class-access-tab.ts`, rebuilt and redeployed; `web-applications-class-access.browser-spec.mjs` 2 pass, 1 fail (the Delete leg waits for `.ocu-typed-name-field`). Reverted, rebuilt, redeployed: 3 of 3 green.
- Endpoint legs: `AdminPort` admits no `Security.PrivilegedRoutine` `PUT` or `DELETE` on this build, so the DELETE, disable, MatchRoles and Roles mutations answer 501 and reach no vendor; each leg reddens on its status and code.

**Pass 4 (2026-10-09) pins and runs.** Every run on `ocupilot-ci`, one class or spec per call, after `load-ocupilot-ci.sh`. Each mutation was applied to the worktree source, loaded, run, then reverted from a saved copy and checked byte-identical.

- `OwnRoutineApplicationWire.TestTheAgentConfirmRefusesEveryArmedAction` (F1, agent `MatchRoles` leg, added): run 124 red (the mint answers 200 and stores the proposal, so the leg now confirms it instead of expecting a mint refusal); the corrected leg then ran green (run index not printed by the runner). `mutation`: `ROUTINEAPPLICATIONFIELDS` `"MatchRoles,Roles"` to `"Roles"` in `Prohibited`; run 126 red on the agent confirmed `MatchRoles` legs (both applications), run 127 red again on the same and the screen `add-matching-role` legs. Reverted, `shasum` identical; run 128 green (2/2).
- `WebAppPctAccess.TestTrailingSlashApplicationRefused` (F2, added): run 129 green (10/10). `mutation`: remove `$Extract(tName, *) = "/"` from `PctAccessPort` shape; run 130 red on the 422 assertion of this leg. Reverted, `shasum` identical; run 131 green (10/10).
- `web-app-class-access-tab.spec.ts` `marks a system entry's Delete aria-disabled` (F3, unit): `mutation`: `selfProtectionReason`'s `SYSTEM_PCT_ACCESS_RULE` branch returns `''`; red on `expected null to be 'true'` (aria-disabled). Reverted, `shasum` identical; green 4/4. The browser leg in `web-applications-class-access.browser-spec.mjs` was not re-run; its mutation is as its own comment states.
- `OwnRoutineApplication.TestPrivilegedRoutineEndpointRefusesAWebApp` (F4a, GET leg): `mutation`: `PrivilegedRoutineGuard` `"GET,PUT,DELETE"` to `"PUT,DELETE"`; run 132 red on the GET 404 and `PRIVROUTINE.TYPE` legs. Reverted, `shasum` identical; run 133 green (11/11).
- `OwnRoutineApplication.TestPrivilegedRoutineEndpointRefusesAWebApp` (F4b, DELETE leg): `mutation`: the DELETE refusal's status 409 to 410 in `PrivilegedRoutineGuard`; run 134 red on the DELETE 409 leg only. Reverted, `shasum` identical; run 135 green (11/11).
- `web-app-class-access-tab.spec.ts` Add read criterion (F5a): `mutation`: `,all-applications` dropped from the read criterion in `web-app-class-access-tab.ts`; red on the `application=/csp/probe,all-applications` assertion. Reverted, `shasum` identical; green 4/4.
- `web-applications-class-access.browser-spec.mjs` Add leg (F5b): `mutation`: `PCT_ACCESS_SAVE_PATH` to `/api/ocupilot/web-app/pct-access/x`, rebuilt and redeployed; the Add leg red (waited out the row-count wait). Reverted, `shasum` identical, rebuilt, redeployed: 3 of 3 green.
- `OwnRoutineApplicationWire.TestTheScreenRouteRefusesEveryArmedAction` (F6): `mutation`: `RoutineApplicationChanges` field-loop test `If $ListFind(tFields, tField) Quit` to `If 0 Quit` in `Prohibited`; run 136 red on the screen `add-matching-role` legs (and the agent `MatchRoles` confirm legs). Reverted, `shasum` identical; run 137 green (2/2).

**Pass 4 (2026-10-09) sweep pins.** One class per run on `ocupilot-ci`, after `load-ocupilot-ci.sh` each time. Each mutation was applied to the worktree source, loaded, run, then reverted from a saved copy and checked byte-identical against the pre-mutation hash.

- The four red classes ran green on the clean tree: `Governance` run 536 (14/14), `ToolDispatch` run 537 (18/18), `Prohibited` run 540 (14/14, after the one-home fix), `ExplorerWire` run 541 (6/6); then the clean `OwnRoutineApplication` run 542 (11/11), `OwnRoutineApplicationWire` run 543 (2/2), `WebAppPctAccess` run 544 (10/10), `GovernanceBaseline` run 545 (3/3). `Governance` again after the revert: run 548 (14/14).
- `OcuPilot.Test.Governance.TestTheDefaultEnablesEveryWriteButTheBaselineDisabled` (the `webapp.pctaccess.delete` roster leg): `mutation`: `Kernel/Governance/Baseline.cls` `"webapp.pctaccess.delete": false` to `true`; run 546 red on that leg. Reverted, `shasum` identical.
- `OcuPilot.Test.ToolDispatch.TestTheShippedGateAllowsEveryLiveToolButTheBaselineDisabled` (the same roster line): `mutation`: the same baseline line; run 547 red on that leg. Reverted as above.
- `OcuPilot.Test.Prohibited.TestTheSetHasOneHomeAndOneSentencePerCode` (one-home; the sentence count is over production classes, since the test classes quote each sentence as their pinned copy): `mutation`: the sentence copied into the doc comment of `Screen/Tool/WebAppDelete.cls`; run 551 red on that leg. Reverted, `shasum` identical; run 552 green (14/14).
- `OcuPilot.Test.OwnRoutineApplicationWire` (the early 403, now `Kernel/Proposal/Prohibited.cls` `RefusesDeleteBeforeState`, Decision 1): `mutation`: `If ..OwnRoutineApplication(pIdValue) {` to `If 0 {`; run 549 red, 2 of 2 (the 400 precondition answers again). Reverted, `shasum` identical; run 550 green (2/2). This replaces the pass-2 mutation line, which named `WebAppDelete.RefusedBeforeState`.
- `OcuPilot.Test.ExplorerWire.TestTheReadToolsAnswerRowsAndNeverTheDocument` (the explorer class read leg now reads `OcuPilot.Kernel.Agent.Limits.cls`, not a growing production class): no new pin; green in run 541.
- Browser (rebuilt and redeployed bundle): `web-applications-class-access.browser-spec.mjs` 3/3 green, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776`.
- `ui`: `npm run build` green (prebuild checkers and postbuild licenses); `npm run test:tools` 1903/1903; `npm run test:components` 2733/2733 in 212 files.

**Pass 4 review patches (2026-10-09), each mutation applied to the worktree source, loaded, run, then reverted and checked by `shasum`:**

- `OcuPilot.Test.GovernanceBaseline.TestThePurgeIsTheOneDisabledLine` (the exact disabled-line roster): `mutation`: `Kernel/Governance/Baseline.cls` `"webapp.pctaccess.delete": false` to `true`; run 553 red on that leg. Reverted, `shasum` identical; run 554 green (3/3).
- `OcuPilot.Test.WebAppPctAccess.TestAgentCreateAndDeleteMintConfirmAndReadBack` (the `pct-class-access` covered-type row): `mutation`: `,pct-class-access";` removed from `COVEREDTYPES` in `Kernel/Proposal/Prohibited.cls`; run 556 red on that leg. Reverted, `shasum` identical; run 557 green (10/10).

**QA pass (2026-10-09) (QA).** Every run on `ocupilot-ci`, one class or spec per call, after `load-ocupilot-ci.sh`. Each mutation was applied to the worktree source, loaded, run, reverted and checked byte-identical by `shasum`, then the class ran green again.

- (QA) Arming per Task 13: `OwnRoutineApplication`, `OwnRoutineApplicationWire`, `PctAccessSaveWire` and `WebAppPctAccess` declare `ARMINGVARIABLE` `OCUPILOT_ALLOW_PRINCIPALS`, refuse in `OnBeforeAllTests` where it does not read 1, and sit in the PRINCIPALS roster of `scripts/ci-throwaway.sh`. `mutation`: `WebAppPctAccess` removed from that roster line; `node --test tools/ci.test.mjs` red on the DW-1276 roster test; reverted, 87/87 green.
- (QA) Self-containment: `WebAppPctAccess.OnAfterOneTest` removes the turn and proposals the agent leg seeds (`ProposalFixture.RemoveSeeded`); the Turn and Proposal row counts are the same after a second run.
- (QA) AC3, clicked or proposed: new `WebAppPctAccess.TestADeleteOfASystemEntryIsRefusedOnTheRouteAndTheMint` (the screen action route and the agent's mint each answer 400 `TOOL.ARGUMENTS` with the system sentence, and the entry stays listed). `mutation`: `If pFresh.%Get("System") = 1 {` to `If 0 {` in `WebAppPctAccessDelete.StateDiff`; run 576 red on it and on `TestStateDiffRefusesASystemEntry`; runs 575 and 577 green (11/11).
- (QA) AC4, kernel delete clause: `mutation`: `= "DELETE")` to `= "NODELETE")` in `Prohibits`' routine application delete clause; run 563 red, 2 of 11 (`TestDeleteStateRefused`, `TestDeleteIdentityRefused`). The wire class's seeded-delete confirm shares this clause and is not run under it, because an unrefused confirm would delete OcuPilotState on the instance.
- (QA) AC4, identity name: `mutation`: the `IDENTITYAPPLICATION` comparison in `Prohibited.OwnRoutineApplication` to `|| 0`; run 564 red, 5 of 11 (identity delete, disable and Roles, and the endpoint disable and Roles legs); both applications read back as recorded.
- (QA) AC4, early 403: `mutation`: `If $ClassMethod(pToolClass, "RefusedBeforeState", pId, .tEarlyCode) {` to `If 0 {` in `ScreenAction.Run`; run 566 red on `TestTheScreenRouteRefusesEveryArmedAction` only. The same change in `Mint.Mint` (`pIdValue`); run 567 red on `TestTheAgentConfirmRefusesEveryArmedAction` only.
- (QA) AC5, a routine application still reads: `mutation`: `If (tKept = "") || ((+tKept \ 4) # 2) Quit $$$OK` to `If (tKept = "") Quit $$$OK` in `AdminPort.PrivilegedRoutineGuard`; run 565 red, 5 of 11 (`TestPrivilegedRoutineEndpointRefusesAWebApp`'s last leg, and the four endpoint legs answering 409 instead of 403). Nothing reaches the vendor under it.
- (QA) Task 6 and P9, `MUTATINGTYPES`: `mutation`: `WebApp.PctClassAccess/PUT` removed from `AdminPort`; run 568 `WebAppPctAccess` red (`TestCreateReadDelete` and the agent leg), run 569 `ToolWrite` red on `TestEveryWriteToolsRequestTypeAgreesWithThePortsBodylessRoster`. The same pair removed from `PortFixture`: run 570 red on that test; clean `ToolWrite` run 571 (34/34).
- (QA) AC3, browser `aria-disabled`: `mutation`: the `SYSTEM_PCT_ACCESS_RULE` branch of `selfProtectionReason` answers only for `system === 'never'`, rebuilt and redeployed; `web-applications-class-access.browser-spec.mjs` 1 failed, 2 passed (the first test). Reverted, rebuilt, redeployed: 3/3 green, each test also green alone in reverse file order; `web-applications-editor.browser-spec.mjs` 7/7.
- (QA) Clean tree: `OwnRoutineApplication` run 572 (11/11), `OwnRoutineApplicationWire` 573 (2/2), `WebAppPctAccess` 577 (11/11), `PctAccessSaveWire` 561 (3/3). S0: both routine applications enabled with `MatchRoles` as at the start, no `%OcuProbe1810` entry, no probe application.

**Code review (2026-10-09) pins and runs.** On `ocupilot-ci`, one class per call after `load-ocupilot-ci.sh`; each mutation applied to the worktree, loaded, run, reverted and checked byte-identical by `shasum`.

- Clean: `Prohibited` run 578 (14/14), `RefusalCopy` 579 (8/8), `OwnRoutineApplication` 580 and 591 (12/12), `OwnRoutineApplicationWire` 581 (2/2), `SaveHoldCoverage` 582 (2/2), `WebAppPctAccess` 583 (11/11), `SurfaceCoverage` 584 (4/4). `npm run test:tools` 1903/1903, `npm run test:components` 2739/2739 in 212 files, `npm run build` green (initial total 3,186,379 bytes), Fixed strings 2981 against 3000. Browser on the rebuilt, redeployed bundle: `web-applications-class-access` 3/3, `web-applications-editor` 7/7.
- `mutation` (one-home rule over the whole tree, `Prohibited.TestTheSetHasOneHomeAndOneSentencePerCode`): the sentence quoted again as a parameter in `Test/OwnRoutineApplication.cls`; run 585 red on that leg.
- `mutation` (`RefusalCopy.TestEachKernelRefusalIsItsParameterAndNamesNoCaller`, the `OCUPILOTROUTINEAPP` row): `ReasonFor` answers a literal naming the agent; run 590 red.
- `mutation` (`OwnRoutineApplication.TestAnUnlistedChangeIsNotRefused`): `RoutineApplicationChanges`' `If $ListFind(tFields, tField) Quit` to `Quit`; run 586 red on that leg alone.
- `OwnRoutineApplicationWire` restore: under `ROUTINEAPPLICATIONFIELDS` `"Roles"` (run 587, red on the four `MatchRoles` legs) the vendor's `WebApp.App` `PUT` refused each with `#799` at 500, so nothing changed (DW-2252). `PutBack` was proven on a probe routine application created and removed by the probe: a changed `MatchRoles` and `Enabled`, and a deleted application, each read back as recorded.
- `mutation` (`SaveHoldCoverage` pct-access leg): `PctAccessSave` holds `..Text(tBody, ..#NAMEKEY)` alone; run 588 red on that leg (0.0 s wait).
- `mutation` (AC2 create snippet): `PctAccessPort.Snippet` answers `[]` for a `PUT`; run 589 red on that assertion.
- `mutation` (tab spec): `applied` dropped from the sink, the bus subscription dropped, the effect loading once, `loaded` dropped from `isEmpty`, `String()` in place of `cellView`: each reddens its own leg alone. Dialog spec: `AllowType: ALLOW_TYPES[0]` and `AllowAccess: true` each redden the posted-fields leg.
- `mutation` (browser Delete leg, row leaves the table): both re-reads dropped, rebuilt and redeployed; red on the wait (30 s). Either re-read alone keeps it green, because the action handler publishes the change the tab subscribes to. Reverted, rebuilt, redeployed: 3/3.
- S0 after the pass (clean source loaded, clean bundle deployed): both routine applications enabled, `MatchRoles` `:%DB_OCUPILOT` and `:OcuPilotIdentity`, `Roles` empty; 29 percent-class access entries, none `%OcuProbe`; no `/csp/ocuprobe1810`, `/csp/ocuprobehold` or probe routine application. Monitor state 2, as read before this pass's first run.

**Orchestrator quality review (2026-10-09) pins and runs.** Every run on `ocupilot-ci` (a fresh throwaway, so its run indices start low), one class per call, after `load-ocupilot-ci.sh`. Each mutation was applied to the worktree source, loaded, the mutated class and every descendant recompiled (`Prohibited` with its ten descendants; the two tools), run, reverted from a saved copy and checked byte-identical by `shasum`, then the class ran green again. This block supersedes the pass 3, pass 4, QA and code review lines that name `ROUTINEAPPLICATIONFIELDS`, `RoutineApplicationChanges`, `RefusesDeleteBeforeState`, a `Roles` leg, the `= "NODELETE"` clause (QA run 563) or the identity-name comparison (QA run 564): the arm lists no field, and none of those exists any more.

- Vendor measurement, on a probe `Type` 4 application created and removed by the measurement: `WebApp.App` `PUT` of `{"Enabled":false}`, `{"Description":"changed"}`, `{"Resource":"%Admin_Manage"}` and `{}` each answered 500 and the application read back unchanged. So a mutation that lets an update-class write reach the vendor changes neither routine application; no mutation that lets a delete through was run against the real applications (the delete-only mutations below keep the delete refused).
- Clean tree before any mutation: `OwnRoutineApplication` run 30 (11/11), `OwnRoutineApplicationWire` 31 (3/3), `WebAppPctAccess` 32 (10/10), `Prohibited` 33 (14/14), `RefusalCopy` 34 (8/8), `SaveHoldCoverage` 35 (2/2), `WebAppSave` 36 (7/7), `EntityRef` 37 (9/9).
- `mutation` (kernel arm over every write: `TestAnyOtherWriteIsRefused`, `TestDisableRefused`, `TestMatchRolesRefused`): `Prohibits`' `If (tType = ..#TYPEWEBAPPLICATION) && ..OwnRoutineApplication(tId) {` gains `&& (..WriteTypeOf(..ToolClassNamed(pToolName)) = "DELETE")`; `OwnRoutineApplication` run 38 red on those three legs and green on both delete legs. Reverted, `shasum` identical (`79e2d444`), run 40 green (11/11).
- `mutation` (Claim 7 `OwnRoutineApplicationWire.TestTheEditorSaveRefusesEveryField`, and the agent's seeded update confirms): the same mutation; run 39 red, 2 of 3 -- the Save answers 500 for `Enabled` and for `Resource` on both applications, and the seeded disable, `MatchRoles` and `Description` confirms answer 409; both applications read back unchanged.
- `mutation` (agent mint of an update, `TestTheAgentRefusesEveryWriteAtTheMintAndTheConfirm`): `WebAppUpdate.RefusedBeforeState` answers 0; run 41 red, 1 of 3, on the mints of a disable, a `MatchRoles` change and a `Description` change (the seeded confirms stay refused). Reverted, `shasum` identical (`f4b29403`); run 42 green.
- `mutation` (early answer for a delete, `TestTheAgentRefusesEveryWriteAtTheMintAndTheConfirm` and `TestTheScreenRouteRefusesEveryArmedAction`): `WebAppDelete.RefusedBeforeState` answers 0; run 43 red, 2 of 3, both delete legs answering 400 `TOOL.ARGUMENTS`. Reverted, `shasum` identical (`35a9b060`); run 44 green.
- `mutation` (the screen route's disable and matching-role legs): the kernel mutation above together with the `WebAppUpdate.RefusedBeforeState` one; run 49 red, 3 of 3, the two legs answering 500 from the vendor, which changed nothing. Either alone leaves them refused by the other (runs 39 and 41). Both reverted, `shasum` identical; run 50 green.
- `mutation` (endpoint delete, `TestEndpointDeleteRefused`): `RoutineEndpointRefused`' `If (pType = "GET") || (pName = "") ||` gains `|| (pType = "DELETE")` after the first term; run 45 red, 1 of 11, on that leg alone (the port answers 501). Reverted, `shasum` identical (`79e2d444`); run 46 green.
- `mutation` (endpoint `PUT` legs: `TestEndpointDisableRefused`, `TestEndpointMatchRolesRefused`, `TestEndpointAnyFieldRefused`): the same line gains `|| (pType = "PUT")`; run 47 red, 3 of 11, the delete leg green. Reverted, `shasum` identical; run 48 green.
- `mutation` (Claim 2, the id-rule pin): `pct-class-access:foldcase-firstpart` to `pct-class-access:foldcase` in `Kernel/EntityRef.cls`'s `IDRULES`; `node --test tools/screen-mirror.test.mjs` red on three tests (the id-rule table, the checked-in mirror twice) and `node tools/screen-mirror.mjs --check` answers stale. Reverted, `shasum` identical (`0f60004b`); 70/70 green and the check up to date.
- Removed with no mutation to run: `TestRolesRefused`, `TestEndpointRolesRefused`, `TestFoldFirstFoldsOnlyTheApplication` and the `entity-ref.test.mjs` `foldfirst` test.
- Final tree, after every revert: `OwnRoutineApplication` run 51 (11/11), `OwnRoutineApplicationWire` 52 and 60 (3/3; 60 after a comment-only edit of `WebAppUpdate`), `WebAppPctAccess` 53 (10/10), `Prohibited` 54 (14/14), `RefusalCopy` 55 (8/8), `SaveHoldCoverage` 56 (2/2), `WebAppSave` 57 (7/7), `EntityRef` 58 (9/9), `PctAccessSaveWire` 59 (3/3). `uv run scripts/check-objectscript.py` 0 problems over 1813 files.
- Client: `node --test tools/entity-ref.test.mjs tools/screen-mirror.test.mjs tools/self-protection.test.mjs` 123/123; `npm run test:tools` 1904/1904; `npm run test:components` 2763 in 216 files; `npm run build` green, initial total 3,190,536 bytes (main 2,985,065, styles 205,471); Fixed strings unchanged (no string was added or changed). Browser, on the rebuilt and redeployed bundle: `web-applications-class-access.browser-spec.mjs` 3/3.
- S0 at the end: `OcuPilotState` enabled, `MatchRoles` `:%DB_OCUPILOT`; `OcuPilotIdentity` enabled, `MatchRoles` `:OcuPilotIdentity`; `Roles` and `Resource` empty on both, as at the start; 47 applications, none a probe; no `OcuProbe` user, role or resource; 28 percent-class access entries, none a probe; no turn and no proposal row; monitor state 2, as at the start.

**Review patches of the orchestrator quality review pass (2026-10-09).** Runs on `ocupilot-ci` (indices from 61 after the sentence reword), one class per call, each mutation applied to `Prohibited.cls`, loaded, run, reverted from a saved copy and checked byte-identical by `shasum` (`b573429c`):

- `mutation` (the delete legs, `OwnRoutineApplication.TestDeleteStateRefused` and `TestDeleteIdentityRefused`): the arm's condition in `Prohibits` gains `&& (..WriteTypeOf(..ToolClassNamed(pToolName)) '= "DELETE")`, so the arm skips a delete; run 66 red, 2 of 11, on exactly those two legs.
- `mutation` (the state name): the `APPLICATION` comparison in `OwnRoutineApplication` becomes `0`; run 67 red, 6 of 11, on the OcuPilotState legs and the endpoint legs that name it.
- `mutation` (the identity name): the `IDENTITYAPPLICATION` comparison becomes `0`; run 68 red, 5 of 11, on the OcuPilotIdentity legs. These two lines replace QA runs 563 and 564.
- `mutation` (the any-field clause, `TestAnyOtherWriteIsRefused` and Claim 7's `TestTheEditorSaveRefusesEveryField`): the arm's condition gains `&& ((..WriteTypeOf(..ToolClassNamed(pToolName)) = "DELETE") || (pDiff [ "Enabled") || (pDiff [ "MatchRoles"))`, which reintroduces a field list. `OwnRoutineApplication` run 72 red, 1 of 11, on `TestAnyOtherWriteIsRefused`; `OwnRoutineApplicationWire` run 71 red, 2 of 3, on `TestTheEditorSaveRefusesEveryField` and the agent leg. (A first form keyed on the payload text, runs 69 and 70, left the Save leg green because the Save's merged payload names `Enabled`; the diff form is the one that discriminates.) The vendor refuses a write to a routine application (500, nothing changed), so no mutation here changes either application.
- `mutation` (the read exemption, `TestPrivilegedRoutineEndpointRefusesAWebApp`, which now reads both applications): `(pType = "GET") || ` dropped from `RoutineEndpointRefused`; run 73 red, 1 of 11.
- After the patches and the sentence reword, clean: `OwnRoutineApplication` run 74 (11/11), `OwnRoutineApplicationWire` 75 (3/3), `ProhibitedRoute` 76 (24/24), `WebAppWeakening` 77 (6/6); before the patches, with the reworded sentence, `RefusalCopy` 61 (8/8), `Prohibited` 62 (14/14), `OwnRoutineApplication` 63 and `OwnRoutineApplicationWire` 64. `npm run test:tools` 1904/1904, `npm run test:components` 2763 in 216 files, `npm run build` green, the class-access browser spec 3/3 on the rebuilt, redeployed bundle. The mutation line of the published sentence (`cannot` to `can not`) still applies to the reworded sentence.
- S0 after the pass: both routine applications enabled, `MatchRoles` `:%DB_OCUPILOT` and `:OcuPilotIdentity`; 47 applications, none a probe; no probe user, role or resource; 28 percent-class access entries, none a probe; no turn and no proposal row; monitor state 2.

**Manual checks:** `ocupilot-ci` is at S0 (read after run 90: no `%OcuProbe1810` entry, no `Ens.Director` entry on `all-applications`, `OcuPilotState` and `OcuPilotIdentity` present and enabled, `/csp/ocuprobe1810` absent).

## Auto Run Result

Status: done
Blocking condition: none

- This pass verified the orchestrator's seven claims: 5 confirmed and patched (1, 7, 2, 5, 6), 2 closed earlier by the code review (3, 4), one sub-claim refuted (Review Triage Log, "Orchestrator quality review"). Changed: `Prohibits`, the early 403 (`RefusesBeforeState`, now also on `WebAppUpdate`) and the `AdminPort` endpoint arm refuse every write to `OcuPilotState` and `OcuPilotIdentity`, with no field list; the `Roles` pins and `foldfirst` are gone (`pct-class-access` takes `foldcase-firstpart`); the parameters sit with their families; the editor-Save wire test is new. The refusal sentence now ends "cannot be deleted, disabled or changed." in `Prohibited.cls`, `strings.ts` and EXPERIENCE.md row 475 (in place, line count unchanged).
- Runs on `ocupilot-ci`, one class per call, green on the final tree: `OwnRoutineApplication` 74, `OwnRoutineApplicationWire` 75, `WebAppPctAccess` 53, `Prohibited` 62, `RefusalCopy` 61, `SaveHoldCoverage` 56, `WebAppSave` 57, `EntityRef` 58, `PctAccessSaveWire` 59, `ProhibitedRoute` 76, `WebAppWeakening` 77. Every mutation red then reverted byte-identical (Verification, the quality-review block and its review patches).
- Client: `npm run test:tools` 1904/1904; `npm run test:components` 2763 in 216 files; `npm run build` green; `web-applications-class-access.browser-spec.mjs` 3/3 on the rebuilt, redeployed bundle.
- Measured: bundle initial total 3,190,503 bytes (main 2,985,032, styles 205,471), under the 3,326 kB warning. Fixed strings 2984 against the 3000 bound, not raised (no literal added).
- Review (verification-gap and intent-alignment): 14 findings, 0 high, 0 medium, 12 low, 2 false; 4 low patched, 10 rejected. `followup_review_recommended` false (no `high` patched).
- For the lead (Rule 20): AD-10 (spine line 363) still lists a delete, a disable and `MatchRoles` or `Roles` and defers `Routines` and `Resource` to 18.31; the arm now refuses every write (text in Design Notes, "For the lead"). AD-13 (line 442) names `foldfirst`, which no longer exists. The Intent's wording is narrower than the arm and is read-only here.
- S0: both routine applications enabled with `MatchRoles` as at the start; no `%OcuProbe1810` entry, probe application, user, role or resource; 28 percent-class access entries; no turn or proposal row; monitor state 2.
