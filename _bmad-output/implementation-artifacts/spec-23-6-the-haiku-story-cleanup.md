---
title: 'Story 23.6: The Haiku-story cleanup'
type: 'refactor'
created: '2026-10-09'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['multiple-goals', 'oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** A read-only review of the three Haiku-trial stories (20.21 agent saves, 20.19 source reads, 18.29 user copy) filed 19 items: one fail-open guard, an untrue refusal reason, duplicated helpers, logic and literals, comments that misstate the code or narrate history, and an 825-line test class. An addendum adds the same review's items on 18.10 (`%`-class access) and 20.20 (agent creates): one refusal text carrying a raw U+0001, a misplaced parameter, missing citations, a duplicated helper and stale docs.

**Approach:** Every item was verified at head `a3455ddb`, and the addendum's at the heads named in its table (Design Notes). Fix each confirmed item. The guard, the reason change and the readable refusal text go test-first. Everything else is a behavior-preserving refactor or prose fix, pinned by the existing classes and specs, which pass before and after.

## Boundaries & Constraints

**Always:** Implement runs only after Story 20.20 has merged and the lead has forward-merged the feature branch. Find each item by method name, never by the line numbers below (20.20 moves them). Outside the I/O matrix's three changed rows, wire codes, payloads, fingerprints, schemas and route answers stay byte-identical. Follow CLAUDE.md's Prose discipline: replace a wrong sentence, never append a correction, and name no story, run or review round in a new comment. Run one test class at a time, on `ocupilot-ci` only, and use `server: "ocupilot-slot-a"` on every MCP call.

**Never:** `text-diff.ts` or Compare, DW-2241, any filing candidate under Design Notes, a new or reworded error code, a change to the `ocupilot` dev instance, the full browser suite, or the full ObjectScript sweep (the lead runs that).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| CHANGED: stored arguments not an object | `ExplorerSave` / `ExplorerCreate` `ConfirmProblem(name, "", .p)` | `p` is a refusal sentence. Through Confirm that is 400 `TOOL.ARGUMENTS`, nothing written. | Today `p` is `""` (observed on `ocupilot-ci`). |
| Unchanged: arguments `{}` | `ConfirmProblem(name, {}, .p)` | Refused: "the namespace of the document is not known…" | — |
| CHANGED: object-only routine read | `explorer.routine.source` on `EnsJob.mac` | 404 `PORT.NOTFOUND`, reason `AtelierPort.#REASONNOSOURCE` "The instance keeps no source for this document." | It answers `REASONNOTFOUND` today. |
| Unchanged: absent document read | absent class | 404 `PORT.NOTFOUND`, `REASONNOTFOUND` | — |
| Unchanged: copy with empty `CopyFrom` | `POST /users/copy`, the rules pass | 422 violation `CopyFrom` `USERCOPY.SOURCE`, nothing created | — |
| Unchanged: policy-refused password on a copy | `POST /users/copy` or the confirm | 422 `USER.PASSWORD.POLICY`, one violation on `Password` with the policy's reason | Unlogged |
| Unchanged: save schema | `explorer.classes.save` `InputSchema` | `Edits` has `maxItems` 20 as a JSON number, and its description says "One to 20" | — |
| CHANGED: `%`-class access refused by presence | a `WebAppPctAccessMint` mint whose superclass answers "already present" or "not present" | `detail.problem` names the entry with `ErrorDeleteMint.ReadableId`'s breadcrumb (` › `) between its parts; the status, code and HTTP status are unchanged | Today the text carries a raw U+0001 between the parts. |

</intent-contract>

## Code Map

- `src/OcuPilot/Kernel/Proposal/Confirm.cls`, read-only. `Transition` asks `ConfirmProblem` at :395 with `ParsedObject(...)` (:772), which always answers an object (`{}` when the arguments do not parse). Before that, `FingerprintMatches` (:672) re-merges `{}`, and a save's digest then misses (409 `TARGETCHANGED`). A non-empty problem is answered 400 `TOOL.ARGUMENTS` with `detail.problem`.
- `src/OcuPilot/Port/AdminPort.cls`: `PasswordGuard` :3926 [Private] builds the 422. `Refuse` is at :3416. `UserCopyPort` extends `AdminPort`, so it inherits private members.
- `src/OcuPilot/Test/StreamCase.cls`: the repository's abstract `%UnitTest.TestCase` base, extended by `ProviderStream` and `ProviderStreamFamilies`. It is the precedent for the two bases this story adds.
- `ui/tools/ci-runner.mjs:369` `testClassesOnDisk` lists only classes whose `Extends` line names `TestCase` and skips `[ Abstract ]` ones. That is why the new bases' names end in `TestCase`.
- `ui/tools/ci.test.mjs:2285` holds the arming roster: the `# classes:` lines in `scripts/ci-throwaway.sh` must equal the classes that declare `Parameter ARMINGVARIABLE` with that value in their own source.
- `src/OcuPilot/Test/SurfaceCoverage.cls:220` binds `permissions.users.copy` to `OcuPilot.Test.UserCopy:TestTheCopyToolPinsItsInputSchemaAndSnippetForm`. That method stays in `UserCopy`.

## Tasks & Acceptance

**Execution:**

- Baseline: before editing, run every class under Verification once on the unchanged code and record that each is green. That is the "before" of every refactor.
- `src/OcuPilot/Test/ExplorerSaveMintUnit.cls`: in `TestTheConfirmRuleAsksTheStoredNamespace`, add a leg asserting that `ConfirmProblem(<doc>, "", .p)` is non-empty for the class save and the routine save. Observe red on the unchanged code (Rule 19).
- `src/OcuPilot/Screen/Tool/ExplorerSave.cls`: in `ConfirmProblem`, a non-object `pArgs` sets `pProblem` to "the proposal's stored arguments could not be read, so the agent does not save it", and the doc says so (20.21-2, AD-6, AD-40). In `InputSchema`, set `Edits.maxItems` as a JSON number (`%Set(…, "number")`) from `ExplorerSaveMint.#MAXEDITS`, and build the description's count from the same parameter (20.21-7).
- `src/OcuPilot/Test/ExplorerCreateRules.cls` and `src/OcuPilot/Screen/Tool/ExplorerCreate.cls` (both from 20.20): add the same leg in `TestTheNamesThatAreNeverCreated` and observe it red, then make the same fix in `ExplorerCreate.ConfirmProblem`, ending "…so the agent does not create it". This is the same root cause.
- `src/OcuPilot/Test/ExplorerSaveRules.cls`: `TestAHeaderRenameIsRefused` matches "change the document's name" (20.21-1).
- `src/OcuPilot/Screen/Tool/ExplorerSaveMint.cls`: in the class doc's last step, "the stored text" becomes "the new text". In `Hunk`'s doc, delete `(<var>p</var>)` and `(<var>s</var>)` (20.21-5).
- `src/OcuPilot/Test/ExplorerSaveAgentProbe.cls`: `Wide`'s doc says what the code writes: <var>pLines</var> lines `Set x<n> = <n>`, n counted from 1, inside its one method and before `Quit 1`, so the class is pLines + 9 lines long (20.21-6).
- `src/OcuPilot/Test/ExplorerSaveFlow.cls`, folding in `src/OcuPilot/Test/ExplorerSaveAgent.cls` (20.21-8, which also covers 20.21-3):
  - In `TestTheMintedProposalShows…`, also assert one row with `field` `Text`.
  - In `TestAConfirmedSaveIsMarkedLedgered…`, also assert `confirmed updated`, line 6 `    Quit 2`, and `output.errors` 0.
  - Move `TestTheSavedButNotCompiledIsSaid` across on Flow's own `Dispatch` and `EditOf`.
  - In `TestTheProviderIsShownTheEditsContract`, assert `maxItems` is typed `number`.
  - Add the moved behavior to Flow's header.
  - Delete `ExplorerSaveAgent.cls`, and remove its compiled class from `ocupilot-ci`.
- `ui/src/app/shell/proposal-card.ts`: `linesRows` reads "The card's changed-lines rows, which its summary line counts." `summaryFields` describes the lines-changed form as well as the field count (20.21-4).
- `src/OcuPilot/Test/ExplorerDescriptor.cls`: rewrite the doc of `TestTheAreaAdvertisesItsReadsAndWrites`, as merged, without the "Story … adds / adding" parentheticals. Keep lines at about 110 characters or fewer, and take the counts from the merged assertion (20.19-1).
- `src/OcuPilot/Screen/Tool/ExplorerSourceRead.cls`, `src/OcuPilot/Port/AtelierPort.cls` (20.19-2, 20.19-3):
  - `Escaped` drops `[ Private ]`.
  - Add `Parameter REASONNOSOURCE = "The instance keeps no source for this document."` beside `REASONNOTFOUND`.
  - `View`'s not-available branch answers `REASONNOSOURCE`, and the class doc says so.
  - Test first: the object-only legs of `ExplorerSourceEdges` (live `EnsJob.mac`) and `ExplorerSource` (fake route) assert the reason and go red on the current code.
- New `src/OcuPilot/Test/ExplorerSourceTestCase.cls` (`%UnitTest.TestCase [ Abstract ]`, no test methods) holds `NAMESPACE`, `FAKE`, `Fetch`, and `ArmDocument(pName, pLines, pObjectOnly = 0)`. The latter is ExplorerSource's version; Edges' `pIndexStatus` is never passed, so it is dropped. `src/OcuPilot/Test/ExplorerSource.cls` and `src/OcuPilot/Test/ExplorerSourceEdges.cls` extend it, delete their own copies, and call `##class(OcuPilot.Screen.Tool.ExplorerSourceRead).Escaped(` (20.19-2).
- `src/OcuPilot/Test/ExplorerSourceTurn.cls`: both `Do ..RemoveKeyed()` become `Do $$$AssertStatusOK(..RemoveKeyed(), …)` (20.19-4).
- `src/OcuPilot/Area/Permissions/UserCreate.cls` (18.29-1, AD-55):
  - Add `ClassMethod ComposePayload(pName, pArgs, Output pPayload, ByRef pViolations) As %Status`: the kernel's `Mint.Compose` over the tool's settable fields, where a composition problem is today's error status.
  - `Perform` calls it after `Validate`, then `If $$$ISERR(tSC) || (pViolations > 0) Quit`.
  - List it beside the other overridable seams in the class doc.
- `src/OcuPilot/Area/Permissions/UserCopy.cls`: delete `Perform`. Override `ComposePayload`: an empty `CopyFrom`, or a `ComposeCreate` problem, is one violation (`CopyFrom`, `UserCopyError.#SOURCE`); otherwise use the tool's `ComposeCreate`. The docs say the create rules require the password and its policy, and the source check is the copy's own (18.29-1, 18.29-2).
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls`: add `Parameter COPYWRITETYPE = "COPY"` and `Parameter COPYFIELDS = "CopyFrom,FullName,Roles,EscalationRoles"` next to `BROADCASTWRITETYPE`, each with a doc. The copy arm of `Prohibits` uses `..#COPYWRITETYPE`, and `Copied` uses `$ListFromString(..#COPYFIELDS)` (18.29-6).
- `src/OcuPilot/Screen/Tool/UserCopy.cls`: both `"USERCOPY.SOURCE"` literals become `##class(OcuPilot.Api.UserCopyError).#SOURCE`. `ComposeCreate`'s field list becomes `$ListFromString(##class(OcuPilot.Kernel.Proposal.Prohibited).#COPYFIELDS)`. Delete the Rule 19 note in `PrivilegePairs`' doc (18.29-4, 18.29-6).
- `src/OcuPilot/Port/AdminPort.cls`: `ViolationRefusal(pCode, pField, pReason, Output pHttpStatus, Output pFault) [ Private ]` moves here from `UserCopyPort`, and `PasswordGuard` builds its 422 through it (18.29-6).
- `src/OcuPilot/Port/UserCopyPort.cls`: rename `USEREndpoint` to `USERENDPOINT` at every reference (18.29-5). `Copy`'s inline verdict becomes `..PasswordGuard(pName, tPassword, .pHttpStatus, .pFault)`. Delete its own `ViolationRefusal`, and keep `PolicyRefusal` and `SourceRefusal` (18.29-6).
- Split `src/OcuPilot/Test/UserCopy.cls` (18.29-2, -3, -4); each class stays under about 500 lines:
  - New `src/OcuPilot/Test/UserCopyTestCase.cls` (`[ Abstract ]`) gets the header, `ARMINGVARIABLE`, every probe parameter, the three lifecycle methods, and every helper. The refusal message names `$ClassName()`. `MakePrincipals`' doc names three principals and four roles.
  - `UserCopy` extends it and keeps 15 methods: `TestTheCopyRouteAnswersOneJsonEnvelope` … `TestACopyPayloadAdmitsItsFourFieldsAlone`, the snippet test and the schema test. The `SameNames` mutation note stays in its header.
  - New `src/OcuPilot/Test/UserCopyConfirm.cls` takes the 7 principal, confirm, port-gate and SQL-privilege methods. The "(run 78)" sentence becomes: the confirm's pair gate answers first, so the port's gate is pinned by `TestThePortRefusesACopyWhoseCallerLacksAdminSecureWhateverTheRoute`.
- `scripts/ci-throwaway.sh:264`: change the line to `# classes: UserCopyTestCase, UserCopyRefusals, PasswordPolicy`. In `src/OcuPilot/Test/UserCopyNoGate.cls`, the doc names `UserCopyConfirm`.
- `ui/src/app/shell/set-password-dialog.ts`: import `USERS_PASSWORD_CHECK_PATH` from `../areas/permissions/user-create-form.store` and delete the local constant. In `ui/src/app/areas/permissions/user-create-form.page.ts`, indent the body of `@if (!copying)` (and nothing else) by two spaces (18.29-7).
- **Addendum, 18.10 (`%`-class access):**
  - `src/OcuPilot/Test/WebAppPctAccess.cls`: add `TestAPresenceRefusalNamesTheEntryReadably`. It mints the agent's delete of an entry the application does not hold, so no setup is needed, and if practical the create of one it holds. It asserts that `detail.problem` holds no `$Char(1)` and does hold `$Char(8250)`. Observe it red on the unchanged code (18.10-1, Rule 19).
  - `src/OcuPilot/Screen/Tool/WebAppPctAccessMint.cls`: after `##super`, pass a string `detail.problem` through `##class(OcuPilot.Screen.Tool.ErrorDeleteMint).ReadableId`, exactly as `SuperserverMint.Mint` does. The method doc says so (18.10-1, AD-39).
  - `src/OcuPilot/Port/AdminPort.cls` (18.10-2, 18.10-4b):
    - Move `Parameter PRIVROUTINEENDPOINT` out from between `MUTATINGTYPES`' doc block and `MUTATINGTYPES`, with its own one-line doc.
    - Add to `MUTATINGTYPES`' doc a short paragraph on `WebApp.PctClassAccess` `PUT` and `DELETE`, in the style of its siblings, naming no story.
    - In the privileged-routine type check, name the bit test `(+tKept \ 4) # 2` (a local such as `tIsRoutineApp`, or a parameter for the bit), with no behavior change.
  - `ui/src/app/core/strings.ts`: give each of the 16 keys from `webAppPctAccessListLabel` through `webAppPctAccessAllApplications` (the 18.10 keys without a cite) its `/** EXPERIENCE.md:NNN */` cite. Use the Fixed-strings row that publishes it, read at the time of the edit; rows 471 and 475 were at `357985c0`. `npm run test:tools` must stay green (18.10-3).
  - `ui/src/app/areas/web-applications/web-app-class-access-dialog.ts`: replace the two `Math.random` ids with the id pattern sibling dialogs use. Give the Add button its own string key beside the `webAppPctAccess*` keys, used by the tab and the dialog, with the cite its siblings carry, in place of `screenPermissionsAddButton` (18.10-4c, 18.10-4d).
  - `src/OcuPilot/Screen/Tool/WebAppDelete.cls` and `WebAppUpdate.cls`: class-qualify the `<parameter>OCUPILOTROUTINEAPP</parameter>` cites as `OcuPilot.Kernel.Proposal.Prohibited.OCUPILOTROUTINEAPP` (18.10-4e).
  - `ui/src/app/areas/web-applications/web-app-editor.page.ts`: the class-access tab reads `count: counts[CLASS_ACCESS_TAB] ?? 0`, as its siblings do (18.10-4f).
- **Addendum, 20.20 (agent creates).** Do these on the merged code. The lead re-verifies each at the forward-merged head before the implement spawn:
  - `src/OcuPilot/Port/AtelierPort.cls`:
    - `SaveSet`'s doc states what `pCreate` does: it sends no version and refuses a name the namespace holds (409 `EXPLORER.DOCUMENT.CONFLICT`) before the `PUT`. The "a save never creates one" step applies without `pCreate` (20.20-1).
    - The taking rule's docs (`TAKINGROUTINETYPES`' and `Takes`') say the rule was measured for `.mac` and `.int` and is `(inference)` for `bas`, `mvi` and `mvb`. Read the 20.20 spec's measurement first, and if it shows more types measured, say those (20.20-5).
  - `src/OcuPilot/Screen/Tool/ExplorerSaveMint.cls`: `SaveLines` delegates to `##class(OcuPilot.Port.AtelierPort).SavedLines(pText)`, and its doc says the two are one rule (20.20-2).
  - `src/OcuPilot/Test/ExplorerCreateFlow.cls` and `ExplorerCreateRules.cls`: each header states the environment the tests actually need. They run in process, not over HTTP (20.20-5).
  - `ui/browser/agent-code-create.browser-spec.mjs`: the `Mutation (Rule 19)` comment names a mutation that exists in `proposal-card.ts` and reddens that assertion. Apply it once on a rebuilt bundle to confirm, then revert (20.20-5).
- This spec's `## Review Triage Log`: append one line per item, fixed (with the test that pins it) or declined (with the reason).

**Acceptance Criteria:**

- Given stored arguments that are not an object, when `ConfirmProblem` of a save or a create is asked, then it answers a refusal, and its new leg was observed red before the fix.
- Given a routine the instance keeps only as object code, when `explorer.routine.source` reads it, then it answers 404 `PORT.NOTFOUND` with `REASONNOSOURCE`, and an absent document still answers `REASONNOTFOUND`.
- Given `POST /users/copy`, when it runs through `UserCopy`'s `ComposePayload` override, then an empty, absent, directory-service or delegated source is refused 422 on `CopyFrom` `USERCOPY.SOURCE` and nothing is created; a valid copy carries the source's roles; and `POST /users` through the default still creates as before. This is the integration criterion (Rule 1), pinned by `UserCopy`, `UserCreate` and `UserCreateWire`.
- Given every refactor and prose task, when it lands, then each class and spec under Verification is green before and after, and Rule 30's fresh check passes.
- Given the split, when the suite runs, then `UserCopy` and `UserCopyConfirm` hold 22 test methods between them, each class passes alone and in either order, and `npm run test:tools` is green.
- Given an agent's `%`-class access mint refused because the entry is present or absent, when its `detail.problem` is read, then it names the entry's parts with ` › ` between them and holds no U+0001, and its new test was observed red before the fix.
- Given the story completes, then each of the 19 items and each addendum item reads fixed or declined with a reason in `## Review Triage Log`.

## Spec Change Log

- 2026-10-09, lead, spec gate: appended the orchestrator's addendum from the Planner's read-only reviews of 18.10 (`357985c0`) and 20.20 (`39ed66f1`). It adds a third CHANGED matrix row (18.10-1), its acceptance criterion, the addendum tasks, verdict table and Verification lines, and the matching tier-1 amendment to the story block in `epics.md`. Filed: DW-2256 to DW-2261 (the plan's filing candidates), DW-2262 (18.10-4a, to 18.31), and DW-2263 and DW-2264 (record-only).
- 2026-10-09, lead, before implement: forward-merged feature `81fc2d01` (20.20 merged at `51fef06d`, green on `6eaf65d4`, run 37981328129). Every story file is unchanged from `39ed66f1` through `6eaf65d4` to the merged head. Each 20.21, 20.20 and 20.19-1 row re-verifies at the merged head, including both `ConfirmProblem` early quits, `maxItems` 20, `SaveSet`'s doc, `SavedLines` and `SaveLines`, and the `(measured)` doc. `FreeCheck` still reads `^rINDEXCLASS`. Rule 31, as reworded, is on the branch: the 20.20-4 and 20.20-6 declines state their reasons.
- 2026-10-09, lead: the Baseline task's "before" is CI run 37981328129, green on `6eaf65d4`, whose code equals implement's baseline. Re-running the whole class list before editing is therefore skipped, because the dispatch says not to re-run unchanged suites. A class may still be run before its own edit where a local reference helps. The red-first legs are still observed red on unchanged product code.

## Review Triage Log

## Design Notes

**Verdicts at `a3455ddb`.** "Overlap" says whether 20.20 (`origin/OCU-1-epic20`) touches those lines.

| Item | Now at | Verdict | Overlap | Action |
| --- | --- | --- | --- | --- |
| 20.21-1 | `Test/ExplorerSaveRules.cls:96` | confirmed | no | match the full phrase |
| 20.21-2 | `Screen/Tool/ExplorerSave.cls:212` | confirmed in the method; unreachable through Confirm (`ParsedObject` → `{}`) | no | fail closed; `ExplorerCreate.cls` (20.20) has the same `:148` shape |
| 20.21-3 | `Test/ExplorerSaveAgent.cls:50-54` | confirmed (no caller) | no | goes with the class (20.21-8) |
| 20.21-4 | `ui/src/app/shell/proposal-card.ts:762,767` | confirmed | no | rewrite both docs |
| 20.21-5 | `Screen/Tool/ExplorerSaveMint.cls:14,241` | confirmed | no (20.20 edits `:283-285` only) | "new text"; drop `p` and `s` |
| 20.21-6 | `Test/ExplorerSaveAgentProbe.cls:13-14` | confirmed: it writes `Set xN = N` inside the method | no | describe the code |
| 20.21-7 | `Screen/Tool/ExplorerSave.cls:87` | confirmed | no | derive from `MAXEDITS`; pin the type |
| 20.21-8 | `Test/ExplorerSaveAgent.cls` | 2 of 5 tests duplicated, 2 partly, 1 unique | no | fold into Flow (about 430 lines) and delete |
| 20.19-1 | `Test/ExplorerDescriptor.cls:132` | narration confirmed; the 192-character wrap is already fixed (112 now) | yes (`:132-134`) | rewrite after the merge |
| 20.19-2 | `Test/ExplorerSource.cls:49-89`, `Test/ExplorerSourceEdges.cls:66-110`, `ExplorerSourceRead.cls:184` | confirmed | no | product `Escaped`; test base |
| 20.19-3 | `Screen/Tool/ExplorerSourceRead.cls:117-121` | confirmed | no | `REASONNOSOURCE` |
| 20.19-4 | `Test/ExplorerSourceTurn.cls:133,161` | confirmed | no | assert the status |
| 18.29-1 | `Area/Permissions/UserCopy.cls:27-101` vs `UserCreate.cls:111-179` | confirmed: 3 differences (the source check, `ComposeCreate`, problem → violation) | no | `ComposePayload` hook |
| 18.29-2 | `UserCopy.cls:22,61`; `Test/UserCopy.cls:751-753` | confirmed: `Validate` requires no source; 3 accounts and 4 roles | no | override doc; `MakePrincipals` doc |
| 18.29-3 | `Test/UserCopy.cls` (825 lines, a test at `:814`) | confirmed | no | base + 2 classes |
| 18.29-4 | `Test/UserCopy.cls:461`; `Screen/Tool/UserCopy.cls:64-65` | confirmed (one product class only) | no | replace; delete |
| 18.29-5 | `Port/UserCopyPort.cls:21` (10 refs), `Test/UserCopy.cls:509,822` | confirmed; no `ui/` reference | no | `USERENDPOINT` |
| 18.29-6 | 422: `UserCopyPort.cls:79-82,250-263` vs `AdminPort.cls:3926`; fields: `Prohibited.cls:5690` vs `Screen/Tool/UserCopy.cls:119`; `"COPY"` at `Prohibited.cls:1407`; `"USERCOPY.SOURCE"` at `Screen/Tool/UserCopy.cls:80,98` | all 4 confirmed. `PasswordGuard` and `UserCopyError.#SOURCE` exist; no copy-field or kernel `COPY` constant does | no | as tasked; the kernel names its write type, as for `BROADCASTWRITETYPE` |
| 18.29-7 | `set-password-dialog.ts:18` vs `user-create-form.store.ts:22`; `user-create-form.page.ts:183-262` | confirmed; the shell already imports from areas (`panel.ts`) | no | import; indent |

**18.10 and 20.20 items (addendum).** The lead verified these at the spec gate: 18.10's at `a3455ddb` (which holds `357985c0`), and 20.20's at `39ed66f1` (20.20's code head, not yet on feature). 20.20-3 is Epic 20's own spec correction and is not this story's.

| Item | Now at | Verdict | Action |
| --- | --- | --- | --- |
| 18.10-1 | `WebAppPctAccessMint.Mint` (doc `:21`; `##super` call); `Mint.cls:180,184` | confirmed: the id is `JoinComposite` and the problem passes through | `ReadableId`, red-first test |
| 18.10-2 | `AdminPort.cls:470` between the doc (`:128-469`) and `MUTATINGTYPES` (`:472`); the doc names no `PctClassAccess` | confirmed | move; add the paragraph |
| 18.10-3 | `strings.ts:394-406`, `:409-411` | confirmed: 16 keys without a cite | cite each |
| 18.10-4a | `PctAccessError.cls:51-55` | confirmed | declined here: DW-2262, routed to 18.31 |
| 18.10-4b | `AdminPort.cls:1971` | confirmed (commented, not named) | name it |
| 18.10-4c | `web-app-class-access-dialog.ts:80,82` | confirmed | sibling id pattern |
| 18.10-4d | tab `:46`, dialog `:60` use `screenPermissionsAddButton` | confirmed | own key |
| 18.10-4e | `WebAppDelete.cls:118`, `WebAppUpdate.cls:237` | confirmed (bare `<parameter>`; it lives on `Prohibited`) | qualify |
| 18.10-4f | `web-app-editor.page.ts:671` | literal 0 confirmed. It is not a defect: `count` is the save's refused-field badge, and no save field lives on that tab | read it as the siblings do |
| 20.20-1 | `AtelierPort.SaveSet` doc (`:2468-2492`) | confirmed: "a save never creates one" is stale for `pCreate` | document `pCreate` |
| 20.20-2 | `AtelierPort.SavedLines` `:2561`; `ExplorerSaveMint.SaveLines` | confirmed identical | delegate |
| 20.20-4 | `ExplorerCreateFlow.Dispatch`/`CodeOf`; `ExplorerCreateRules.ProblemOf` | confirmed (optional) | declined: three small helpers in three test classes; a shared helper adds a cross-class dependency for little gain |
| 20.20-5 | `ExplorerCreateFlow.cls:7`, `ExplorerCreateRules.cls:6`; `agent-code-create.browser-spec.mjs:264`; `AtelierPort.cls:2633` (and `TAKINGROUTINETYPES` `:370`) | confirmed | three one-line fixes |
| 20.20-6 | `ExplorerCreateMint` stores `COMPILEKEY` true | confirmed (optional) | declined: it changes the stored proposal's shape and needs a 20.20 spec amendment, for no behavior gain |
| record | `AtelierPort.FreeCheck` reads `^rINDEXCLASS`; `Literal` on very long control-character lines | — | DW-2263, DW-2264 (`wontfix-accepted`, each with `reopen_if`) |

**Governing ADs:**

- AD-6 and AD-40: the confirm re-asks, and fails closed.
- AD-53 and AD-54: agent save and create.
- AD-12 and AD-39: codes unchanged, each reason written once on the server.
- AD-36, AD-60 and AD-61: source reads through AtelierPort.
- AD-55: two callers, one tool. The hook keeps both payloads.
- AD-2: the password guard's 422.
- AD-27 and AD-52: UserCopyPort.
- AD-10 and AD-3: the copy fields live in the kernel and are authored once.
- AD-35: the secret still merges after the verdict.
- AD-17: test helpers live under `Test`, and the shared `Escaped` lives in product code.
- Conventions: naming and Tests.

**Consumed-by / Consumes (Rules 1 and 2).**

- `UserCreate.ComposePayload` is used by `POST /users` (the default) and `POST /users/copy` (the override).
- `AdminPort.ViolationRefusal` is used by `PasswordGuard` and by `UserCopyPort`'s source and vendor refusals.
- `ExplorerSourceTestCase` is used by `ExplorerSource` and `ExplorerSourceEdges`.
- `UserCopyTestCase` is used by `UserCopy` and `UserCopyConfirm`.

Every consumer is inside this story.

**Folded on purpose:** `ExplorerCreate.ConfirmProblem` is the same root cause as 20.21-2, and I checked it because the dispatch asked. The lead can strike that task at the post-merge re-verification. No item is declined. Ledger inbox: none.

**Files this story edits:**

- Screen/Tool: `ExplorerSave`, `ExplorerCreate`, `ExplorerSaveMint`, `ExplorerSourceRead`, `UserCopy`.
- Port: `AtelierPort`, `AdminPort`, `UserCopyPort`.
- `Kernel/Proposal/Prohibited`.
- Area/Permissions: `UserCreate`, `UserCopy`.
- Test:
  - Edited: `ExplorerSaveMintUnit`, `ExplorerSaveRules`, `ExplorerSaveFlow`, `ExplorerSaveAgentProbe`, `ExplorerCreateRules`, `ExplorerDescriptor`, `ExplorerSource`, `ExplorerSourceEdges`, `ExplorerSourceTurn`, `UserCopy`, `UserCopyNoGate`.
  - New: `ExplorerSourceTestCase`, `UserCopyTestCase`, `UserCopyConfirm`.
  - Deleted: `ExplorerSaveAgent`.
- Other: `scripts/ci-throwaway.sh`; `ui/src/app/shell/proposal-card.ts`, `set-password-dialog.ts`; `ui/src/app/areas/permissions/user-create-form.page.ts`.
- Addendum: `Screen/Tool/WebAppPctAccessMint`, `WebAppDelete`, `WebAppUpdate`; `Test/WebAppPctAccess`, `ExplorerCreateFlow`, `ExplorerCreateRules`; `ui/src/app/core/strings.ts`; `ui/src/app/areas/web-applications/web-app-class-access-dialog.ts`, `web-app-class-access-tab.ts`, `web-app-editor.page.ts`; `ui/browser/agent-code-create.browser-spec.mjs`. `AdminPort`, `AtelierPort` and `ExplorerSaveMint` are already listed.

**Filing candidates, not absorbed** (filed at the spec gate, `routed owner=range-end-cleanup`): DW-2256 (`ExplorerSaveMint.Mint` answers `REASONNOTFOUND` when `available` is false), DW-2257 (its inline escaped-length measure), DW-2258 (`ExplorerSaveTurn` discards `RemoveKeyed()`'s status), DW-2259 (`testClassesOnDisk` misses classes on a project base), DW-2260 (`USERS_PATH` declared twice) and DW-2261 (the tests' `LIMIT = 60000`).

## Verification

Run on slot A with `ocupilot-ci` (52776/1975; directory `/Users/jbrandt/.ocupilot-throwaways/ocupilot-ci`). One test run in flight at a time, each awaited in `%UnitTest_Result`; never re-submit after a client-side timeout.

**Shared surfaces:** none on screen. The ObjectScript test-class roster changes (`ExplorerSaveAgent` removed; `UserCopyConfirm` and two abstract bases added), and so does the `OCUPILOT_ALLOW_PRINCIPALS` arming roster. Standing criterion: existing tests that assert a surface this story changes are updated in this story, and every test the story adds or changes passes on a freshly built instance and in either order.

**Commands:**

- Load (loop): `rsync -a --delete src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-ci/src/`, then `Do $System.OBJ.LoadDir("/opt/ocupilot/src","ck-d",.e,1)` in `docker exec -i ocupilot-ci iris session iris -U HSCUSTOM`. Expected: 0 errors. Once `ExplorerSaveAgent` is deleted, also run `Do $System.OBJ.Delete("OcuPilot.Test.ExplorerSaveAgent")` there.
- Classes (loop): `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one class at a time. Expected: 0 failed, before and after. Classes:
  - ExplorerSaveMintUnit, ExplorerSaveRules, ExplorerSaveFlow, ExplorerSave
  - ExplorerCreateRules, ExplorerCreateFlow
  - ExplorerDescriptor, ExplorerSource, ExplorerSourceEdges, ExplorerSourceTurn, AtelierPortDocument
  - UserCopy, UserCopyConfirm, UserCopyRefusals, UserCreate, UserCreateWire, PasswordPolicy
  - Prohibited, ClassicPageGate, SurfaceCoverage
  - Addendum: WebAppPctAccess, PctAccessSaveWire, PctAccessVendorFault, AtelierPortSave, AtelierPortCreate, AtelierPortScriptRun (the last two arrive with 20.20)
- Addendum client (loop): `npm run test:components` for `web-app-class-access-dialog.spec.ts`, `web-app-class-access-tab.spec.ts` and `web-app-editor.page.spec.ts`. Run `browser/web-applications-class-access.browser-spec.mjs` with the two specs above. Run `browser/agent-code-create.browser-spec.mjs` once, for its mutation line.
- Checks (loop):
  - `uv run scripts/check-objectscript.py <changed .cls>` is clean.
  - `cd ui && npm run test:tools` is green (arming roster).
  - `npm run test:components` is green: `proposal-card*.spec.ts`, `set-password-dialog.spec.ts`, `user-create-form.page.spec.ts`.
  - `npm run build` is green, prebuild checkers included.
- Browser (loop): `npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/users-create.browser-spec.mjs browser/users-actions.browser-spec.mjs`. Expected: green.
- (once, before dev_complete) Full browser suite: not run locally; CI's browser shards run it. Full ObjectScript sweep: run by the lead, not by implement.

**Mutations (Rule 19). Name the red test on each line.**

- `mutation:` restore `If '$IsObject(pArgs) Quit $$$OK` in `ExplorerSave.ConfirmProblem` → the non-object leg of `ExplorerSaveMintUnit` goes red. The same mutation in `ExplorerCreate` → `ExplorerCreateRules`.
- `mutation:` `View` answers `REASONNOTFOUND` → the reason leg of `ExplorerSourceEdges`' live object-only test goes red.
- `mutation:` `MAXEDITS` 19 → the `Edits` leg of `ExplorerSaveFlow` goes red. Setting `maxItems` as a string → its type leg goes red.
- `mutation:` the rename refusal reads "…rename the document…" → `ExplorerSaveRules` `TestAHeaderRenameIsRefused` goes red.
- `mutation:` delete `UserCopy`'s `ComposePayload` override → a named leg of `UserCopy` goes red.
- `mutation:` drop `EscalationRoles` from `COPYFIELDS` → the admitted leg of `TestACopyPayloadAdmitsItsFourFieldsAlone` goes red.
- `mutation:` `ViolationRefusal` names field `Pwd` → a named password-refusal leg of `UserCopy` or `PasswordPolicy` goes red.
- `mutation:` change `USERS_PASSWORD_CHECK_PATH`'s suffix → `set-password-dialog.spec.ts:145` goes red.
- `mutation:` `RemoveKeyed` answers an error → `ExplorerSourceTurn`'s new assertion goes red.
- `mutation:` drop the `ReadableId` pass from `WebAppPctAccessMint.Mint` → `WebAppPctAccess` `TestAPresenceRefusalNamesTheEntryReadably` goes red.
- `mutation:` `AtelierPort.SavedLines` drops its empty last line → `ExplorerSaveMintUnit` or `AtelierPortSave` goes red through the delegate. Name the test.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Planned at `a3455ddb` and halted after planning, as the dispatch asked. All 19 items were verified at that head: 19 confirmed, 0 refuted. Two are partly already fixed: 20.19-1's line wrap, and 20.21-2, which is unreachable through Confirm. Implement waits for 20.20 to merge.
