---
title: 'Story 20.10: Source-control hooks'
type: 'feature'
created: '2026-10-13'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
warnings: [oversized]
deferred:
  - summary: >-
      OcuPilot's create and delete of a class or routine drop the source-control class's follow-up user action, so a class that asks "add to source control?" for a new document, or asks after a delete, is never asked and AfterUserAction never runs.
    evidence: |-
      Measured at Story 20.10's plan on ocupilot-b-ci: with a probe source-control class whose UserAction answers 1, the Atelier delete route answered result.ext {action:1, target:<question>}; PutDoc of a new document runs UserAction(1,1) and (1,7) (irissys/%Api/Atelier/v2.cls:615-628, read). AtelierPort reads neither ext.
    location: >-
      src/OcuPilot/Port/AtelierPort.cls SaveSet (pCreate) and DeleteSet
    severity: medium
---

<intent-contract>

## Intent

**Problem:** On a namespace under source control, two things are unproven or wrong:

- Nothing shows that OcuPilot's embedded rule, BPL and DTL editors, or OcuPilot's own saves, go through the namespace's hooks.
- When source control has not released a document for editing, OcuPilot's own save answers "The source code API refused one of the values supplied." (measured).

The criterion as written asks for the hooks, menus, user actions and status to be "exchanged through the port". Under AD-63, OcuPilot cannot do that for the vendor's editors. Measured at this plan, the editors already exchange all four with the instance themselves (Design Notes › Rule 5 draft).

**Approach:**

- Pin, in OcuPilot's frame, that the editors exchange the hooks, menus, user actions and status themselves.
- Make `AtelierPort` refuse a document source control has not released, with its own code and sentence.
- Pin that OcuPilot's own saves run the same hooks in the calling process. That covers the person's save, the agent's save, and Story 20.16's saves behind the editors.

## Boundaries & Constraints

**Always:**

- **AD-63's five limits hold unchanged.** This story changes no frame, page, store, builder or descriptor.
- **The refusal.** A `PutDoc` answer whose vendor text names `#5845:`, `#5865:` or `#6151:` is 409 `EXPLORER.DOCUMENT.SOURCECONTROL` with its published sentence. That holds whether the answer is HTTP 400 (measured) or a 2xx carrying the error.
  - Those three numbers are the source-control edit check: not editable, not checked out, read-only by source control.
  - The vendor's text is logged at information severity through `LogNote` and never sent (AD-39).
  - The branch runs after the 404, 409 and 423 answers and after the access refusal. It runs before 400 `PORT.VALIDATION` and 422 `EXPLORER.SAVE.REFUSED`.
- **The hooks run because the vendor's routes run them.** In the calling process, as the signed-in user, each `Atelier` route kills `%SourceControl` and creates its own instance. `AtelierPort.Route`'s `New %SourceControl` stays, and OcuPilot adds no hook call.
- **Tests that turn source control on** do it only in `USER`, through `OcuPilot.Test.SourceControlProbe`, and only when `USER` has no source-control class. Each removes it again and verifies it is gone: the setting, the probe class and its log global.
- **One new literal**, added only (Design Notes › Strings).

**Never:**

- Any read, write, post or listener on the frame, `?VSCODE=1`, or pre-written storage.
- A call to `%Api.InteropEditors` from shipped code or from the ObjectScript tests. The browser spec only observes the frame's own requests.
- A source-control menu, status or user action of OcuPilot's own on any screen (Design Notes › Rule 5 draft, option C).
- A new screen, write tool, governance key, entity type, read or area.
- Mapping a hook's own `OnBeforeSave` error to the new code. The vendor wraps that error in #16008, and it stays 422 `EXPLORER.SAVE.REFUSED`.
- Turning source control on in `HSCUSTOM`, or in any namespace that already has a source-control class.
- Edits to `.github/workflows/ci.yml`, `ui/tools/ci-shards.mjs`, `ui/tools/ci-timings.json`, `ui/tools/ci.test.mjs`, `Screen/Registry.cls`, `Screen/Read.cls`, `Kernel/Proposal/Prohibited.cls`, `Port/LogSourcePort.cls`, `app.routes.ts`, `angular.json`, `screens.generated.ts`, or 20.7's `interop-editor.page.ts`, `interop-editor.store.ts`, `interop-editor-frame.ts` and `vendor-frame.ts`.

## I/O & Edge-Case Matrix

All rows are in `USER`, with the probe source-control class enabled.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Menu and user action | A probe DTL checked out by the person. They open its editor screen, choose Source Control › Check In (the probe answers Yes/No/Cancel), then Yes | The menu lists "Undo Check Out", "Check In" and "Source Control Messages". The editor's own "Server Side Source Control" dialog shows the probe's question. The probe records `UserAction` (`0`, `%SourceMenu,%CheckIn`), then `AfterUserAction` with answer 1, as the person | - |
| Embedded save | They edit the transform's Description and choose Save | "`<doc>` saved." The probe records `GetStatus`, then `OnBeforeSave`, then `OnAfterSave` for `<doc>.CLS`, as the person. No message reaches the shell, and the shell's main frame sends nothing under `/api/interop-editors/` | - |
| Embedded refusal | The probe marks the DTL not checked out, and the person saves | "Unable to save `<doc>`". The definition's `TimeChanged` is unchanged, and no `OnBeforeSave` is recorded | The vendor answers 400 |
| Rule opened while refused | The probe marks the rule not checked out, and the person opens its editor | "This is marked Read Only by Server Side Source Control." The menu lists "Check Out" and "Get Latest" | - |
| Rule compile | The rule is checked out, and the person chooses Compile | "Rule saved and compiled." The probe records `OnBeforeSave`, `OnAfterSave`, `OnBeforeCompile` and `OnAfterCompile`, in that order. "Source Control Messages" becomes enabled | - |
| Port save | `AtelierPort` SAVE with Compile on | 200. The same four hooks are recorded, in order, with `$Job` and `$Username` the caller's. The caller's `%SourceControl` is unchanged | - |
| Port compile and delete | COMPILE, then DELETE | `OnBeforeCompile` and `OnAfterCompile`, then `OnBeforeDelete` and `OnAfterDelete` | - |
| Person's save refused | The Classes list's `save` over HTTP, on a class not checked out | 409 `EXPLORER.DOCUMENT.SOURCECONTROL` with its sentence. The class is unchanged | Logged at information severity |
| Hook veto | The probe's `OnBeforeSave` returns an error | 422 `EXPLORER.SAVE.REFUSED` | Logged as a fault |
| Agent's editor save (20.16) | `interop.transformeditor.save` minted on the probe DTL, then confirmed while not checked out, then a second proposal confirmed while checked out | First: 409 `EXPLORER.DOCUMENT.SOURCECONTROL`, the text unchanged. Second: confirmed, saved, and the four hooks recorded in the confirm process | - |

</intent-contract>

## Code Map

All paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-20`. Lines were read at `945b4fe4`. Stories 20.16 and 20.8 implement first and edit `AtelierPort.cls`, `AtelierPortSave.cls`, `strings.ts` and EXPERIENCE.md, so anchor those files by symbol.

### Server

- **`src/OcuPilot/Port/AtelierPort.cls`** (3,425 lines):
  - `Invoke` :852, whose fault list is in its doc at :829-851.
  - `SaveSet` :2500, doc :2480-2499. It calls `PutDoc` :2546, then `Compile` :2553.
  - `CompileSet` :1856, `DeleteSet` :1893, `ImportSet` :2396 (a UDL import is also a `PutDoc`).
  - `Route` :3000, with `New %request, %response, %session, %SourceControl` at :3015.
  - `Outcome` :3132, doc :3112-3131:
    - the non-2xx branch: `PutDoc` 409 at :3175, 423 at :3180, 400 → `PORT.VALIDATION` at :3186;
    - the 2xx branch: `AccessDenied` at :3205, then `PutDoc` → 422 `SAVEREFUSED` at :3209.
  - `AccessDenied(pCodes, pRaw)` :3225 (one caller), `ACCESSDENIEDCODES` :465, `LOCKEDCODE` :468, `LogNote` :3249.
- **`src/OcuPilot/Api/AtelierError.cls`**: `DOCUMENTLOCKED` :57-61 (the shape to follow). The `SAVEREFUSED` doc at :78-81 names "a source-control refusal" among its causes.
- **Test helpers to reuse:**
  - `Test/AtelierPortFixture.cls`: `Invoke`, `UseFakeRoutes`, `Arm`, `SetVersion`, `Clear`, `CallCount`.
  - `Test/LogProbe.cls` `Captured`.
  - `Test/ExplorerSaveProbe.cls` (package `OcuProbe193`): `MakeClass` (inherited from `ExplorerProbe`), `ClassText`, `Version`, `Source`, `Remove`.
  - `Test/ExplorerSave.cls` `Save(pList, pId, pText, pVersion, pCompile, .pStatus, .pBody)` :59, the person's save over HTTP.
  - `Test/ExplorerSaveFlow.cls` `Dispatch` :65 (the agent's dispatcher) and `Test/ExplorerWrite.cls` `ConfirmIn` :126.
  - `Test/GovernanceFixture` `Snapshot` and `Restore`, `Test/ProposalFixture` `RemoveSeeded`.
  - 20.16's `Test/InteropEditorProbe.cls` (planned: `Make(pKind, pPackage)` writes and compiles a probe of each kind in `USER`; `Remove(pPackage)`).
- **`Test/AtelierPortSave.cls`** `TestTheVendorsRefusalsAreAnsweredByName` :224-249. Its canned-case table is where the new rows go.
- **The arming pattern:** `Test/NamespaceInterop.cls`:20 and :66-70. `scripts/ci-throwaway.sh`'s `OCUPILOT_ALLOW_NAMESPACE_CONFIG` block is at :643-658, with its `# classes:` lines at :652-657. `ui/tools/ci.test.mjs` derives each roster from the declarations; no edit there.

### Client and documents

- **`ui/src/app/core/strings.ts`**: `explorerSaveRefused` :4603, `explorerEditorRefusedAction` :4605. The client shows the server's `reason`, never a code-to-string map (`source-editor.store.ts`:61).
- **`ui/tools/self-protection.test.mjs`**: `ATELIER_REFUSALS` :606, which pins each `AtelierError` sentence to its `strings.ts` key.
- **EXPERIENCE.md**:
  - :159, the Interoperability paragraph, which ends with 20.7's sentence;
  - :604, the Fixed strings row that the 20.x stories append to, ending with 20.7's clause;
  - :593, Story 19.3's save refusals, which stays as it is.
- **Browser helpers:**
  - `ui/browser/interop-editor-spec.mjs`: `until`, `armMessageCounters`, `watchEditorTraffic`;
  - `ui/browser/interop-editors.browser-spec.mjs`: the local `answered` :279, `editorFrame` :290, `snackbarWhere` :351, the DTL save selectors at :478-485, and `definitionModified`;
  - `panel-spec.mjs` `signedInAt`, `namespace-features.mjs` `waitForMapAnswered`, `turnprobe-spec.mjs` `runIris` (runs in `HSCUSTOM`).

### Vendor (read only; measured selectors in Design Notes)

- The source-control routes are at `irissys/%Api/InteropEditors/v7/spec.cls`:1574-1734.
- **The editors' save and compile routes** (`%Api.InteropEditors.v3.impl`/`v4.impl`, which are `[Hidden]`; read from the instance at this plan):
  - `PutDTL`, `PutBPL` and `PutRule`/`SubmitRoutingRule` call `Utils.CallSourceControlCallback` for `OnBeforeSave` (with the edit check) and `OnAfterSave`.
  - `CompileDTL` and `CompileBPL` set `%SourceControl` before `$system.OBJ.Compile`.
- `%Studio.Extension.Base` hook signatures: `irissys/%Studio/Extension/Base.cls`:81-334.
- `SourceControlClassSet`/`Get`: `irissys/%Studio/SourceControl/Interface.cls`:14-97. `$Char(0)` removes all three storage nodes.

## Tasks & Acceptance

**Execution:**

- [ ] **Task 0 (re-anchor, no code).** After 20.16 and 20.8 have merged into this branch, read again:
  - `AtelierPort.Outcome` and `AtelierPortSave.TestTheVendorsRefusalsAreAnsweredByName`;
  - EXPERIENCE.md :159 and :604, and the `strings.test.mjs` bound;
  - 20.16's `InteropEditorProbe` and the input of its `interop.transformeditor.save` (`Names`, `Edits`).

  Anchor this story's edits to what is there. If `interop.transformeditor.save` is not registered, stop with `## Clarification Needed`, because AC6 consumes it.
- [ ] **`src/OcuPilot/Api/AtelierError.cls`**:
  - Add `DOCUMENTSOURCECONTROL = "EXPLORER.DOCUMENT.SOURCECONTROL"`, documented as `DOCUMENTLOCKED` is (409 on the `CONFLICT` slug; the vendor's text logged at information severity, never sent).
  - Add `REASONDOCUMENTSOURCECONTROL` with the Strings literal.
  - In `SAVEREFUSED`'s doc, replace "a source-control refusal" with "a source-control hook's own refusal".
- [ ] **`src/OcuPilot/Port/AtelierPort.cls`**:
  - Add `Parameter SOURCECONTROLCODES = "5845,5865,6151";` beside `ACCESSDENIEDCODES`, documented as the vendor's source-control edit check.
  - Generalize `AccessDenied(pCodes, pRaw)` into `NamesCode(pCodes, pRaw, pList)`, taking the comma list. Its one caller passes `..#ACCESSDENIEDCODES`.
  - In `Outcome`, for `PutDoc`, add the refusal in Boundaries, in both the 400 branch and the 2xx branch: `Refuse(409, CONFLICT, DOCUMENTSOURCECONTROL, ...)`, then `LogNote`.
  - Update the docs of `Outcome`, `SaveSet` and `Invoke`'s fault list.
- [ ] **New `src/OcuPilot/Test/SourceControlProbe.cls`** (a helper, `%RegisteredObject`):
  - Parameters: `HOOKS = "OcuProbe2010.SourceControl"` and `LOG = "OcuProbe2010SourceControl"` (a global in the probe namespace). Its doc says what it creates and that it is test-only.
  - **`Enable(pNamespace) As %Status`**:
    - Refuse unless `$System.Util.GetEnviron("OCUPILOT_ALLOW_NAMESPACE_CONFIG") = 1`.
    - Remove a leftover setting that names `HOOKS`. Refuse if any other source-control class is set.
    - Write the hooks class with `%Compiler.UDL.TextServices.SetTextFromString` and compile it in `pNamespace` (explicit save and restore, the restore first in `Catch`). Then kill the log global, then `SourceControlClassSet(HOOKS, pNamespace)`.
  - **`Disable(pNamespace) As %Status`**:
    - `SourceControlClassSet($Char(0), pNamespace)`, but only when the setting is empty or names `HOOKS`.
    - Delete the class and kill the global.
    - Error unless `SourceControlClassGet` reads `""`, the class is absent and the global is undefined.
  - **Switches:** `Refuse(pNamespace, pDocument, pOn)`, `Veto(pNamespace, pDocument, pOn)` and `Action(pNamespace, pAction)`.
  - **Readers:** `Entries(pNamespace) As %DynamicArray`, one row per hook call as `{hook, name, user, job, extra}` with `Login` left out, and `Clear(pNamespace)`.
  - **The hooks class it writes** extends `%Studio.SourceControl.Base` and overrides the Base signatures exactly:
    - `OnBeforeLoad`, `OnAfterLoad`, `OnBeforeSave`, `OnAfterSave`, `OnBeforeCompile`, `OnAfterCompile`, `OnBeforeDelete`, `OnAfterDelete`, `GetStatus`, `UserAction` and `AfterUserAction`, each recording `$ListBuild(hook, InternalName, $Username, $Job, extra)`.
    - `GetStatus` answers in source control, editable unless refused, checked out by `$Username` when editable.
    - `OnBeforeSave` answers `$$$ERROR($$$ItemNotCheckedOut, InternalName)` when refused, and a `GeneralError` when vetoed.
    - `UserAction` answers the stored action (default 0) with the target "OcuPilot probe asks: proceed?".
    - `OnAfterSave` writes one console line.
- [ ] **`src/OcuPilot/Test/AtelierPortSave.cls`** `TestTheVendorsRefusalsAreAnsweredByName`, extended. The `For` list gains these rows; the doc and its mutation line are updated:

  | Vendor answer | OcuPilot's answer | Logged |
  |---|---|---|
  | `400 Bad Request` with `#5865` | `409 EXPLORER.DOCUMENT.SOURCECONTROL` | at information severity |
  | `400 Bad Request` with `#5845` | `409 EXPLORER.DOCUMENT.SOURCECONTROL` | at information severity |
  | `400 Bad Request` with `#6151` | `409 EXPLORER.DOCUMENT.SOURCECONTROL` | at information severity |
  | `200 OK` with `#5865` | `409 EXPLORER.DOCUMENT.SOURCECONTROL` | at information severity |
  | `400 Bad Request` with `#16021` | `400 PORT.VALIDATION` | as a fault |

- [ ] **New `src/OcuPilot/Test/SourceControlSave.cls`**, armed by `Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_NAMESPACE_CONFIG"` with `NamespaceInterop`'s `OnBeforeAllTests` refusal. About 300 lines.
  - **`OnBeforeOneTest`:** `Disable("USER")`, remove the `ExplorerSaveProbe` documents and 20.16's probe package `OcuProbe2010Ui`, clear the fixture and `LogProbe`, and snapshot governance.
  - **`OnAfterOneTest`:** `Disable("USER")`, asserted OK. Remove the probes, restore governance, and remove the seeded proposals.
  - **Tests:**
    1. `TestThePortRunsTheHooksInTheCallersProcess` (AC4).
    2. `TestTheCompileAndDeleteRunTheirHooks` (AC4).
    3. `TestThePersonsSaveIsRefusedByName` (AC5, over HTTP through `ExplorerSave.Save`, plus one allowed save that records the hooks under the HTTP account).
    4. `TestAHookVetoIsTheSavesRefusal` (AC5).
    5. `TestTheAgentsEditorSaveRunsTheHooksAndIsRefusedByName` (AC6, through `ExplorerSaveFlow.Dispatch` and `ExplorerWrite.ConfirmIn`, with an `Old` the probe's stored text holds exactly once).
  - Each test makes its probe documents before `Enable`.
- [ ] **`scripts/ci-throwaway.sh`** (add-only), after :657: a comment line saying that the source-control classes enable a probe source-control class on `USER` and remove it, then `# classes: SourceControlProbe, SourceControlSave`.
- [ ] **`ui/src/app/core/strings.ts`** (add-only): after `explorerEditorRefusedAction`, `/** EXPERIENCE.md:604 */ explorerDocumentSourceControl` with the literal. If `strings.test.mjs`'s literal count is then within 50 of its bound and the bound still reads 3,400, raise it to 3,800, as its comment rules.
- [ ] **`ui/tools/self-protection.test.mjs`** `ATELIER_REFUSALS`: add `['REASONDOCUMENTSOURCECONTROL', 'explorerDocumentSourceControl']` after `REASONSAVEREFUSED`.
- [ ] **Browser helpers.** If 20.16 or 20.8 has already exported equivalents of `answered`, `editorFrame` and `snackbarWhere` from `ui/browser/interop-editor-spec.mjs`, import those. Otherwise:
  - move the three there as exports, each taking its `timeoutMs` (and `config.username` where `editorShows` needs it);
  - import them in `interop-editors.browser-spec.mjs`, leaving its behavior unchanged.
- [ ] **New `ui/browser/interop-editor-source-control.browser-spec.mjs`**:
  - **`before`:**
    - Refuse `LIVE_CONTAINER` and require a `-ci` container (20.7's checks).
    - Through `runIris`, make 20.16's rule and DTL probes in `USER` (package `OcuProbe2010Ui`), then `SourceControlProbe.Enable("USER")`.
    - Record `^EnsPortal.Settings(<user>,"LastDTL")` and `"LastBP"` in `USER`, as 20.7 records them in `HSCUSTOM`.
  - **`after`:** `Disable("USER")` asserted OK, remove the package, and restore the two nodes.
  - **Each test** clears the log, signs in at `/ocupilot/interoperability/<list>/document/<probe>.cls?ns=USER` with the observers armed, waits for `answered` and the editor showing the document, and asserts by the measured selectors.
  - **Tests**, each with its Rule 19 mutation comment:
    - AC1, the DTL menu, user action and save;
    - AC2, the DTL refusal and the rule opened read-only;
    - AC3, the rule's Compile.
- [ ] **EXPERIENCE.md** (add-only), then `cd ui && npm run test:tools`:
  - **:604:** append the literal to the literals cell, and append to the description cell: "; and System Explorer's and the agent's saves (Story 20.10): the refusal of a document source control has not released for editing", closed with the row's `[ADDED YYYY-MM-DD - Story 20.10]` marker dated the day it lands.
  - **:159:** append "Where the namespace uses source control, each editor shows its own Source Control menu and runs the namespace's hooks itself (Story 20.10)."
- [ ] **Roster sweep (Rule 30).** Search `src/OcuPilot/Test`, `ui/tools`, `ui/browser` and the `ui/src` specs for:
  - a `PutDoc` 400 asserted as `PORT.VALIDATION`;
  - the `ATELIER_REFUSALS` size;
  - the strings count;
  - the namespace-config arming roster;
  - `AccessDenied`.

  Each changed file joins the `(loop)` set.

**Acceptance Criteria:**

- **AC1 (the restated criterion, in OcuPilot's frame).**
  - **Given** `USER` under the probe source-control class, and the probe DTL checked out by the person.
  - **When** they open its editor screen, choose Source Control › Check In with the probe answering 1, choose Yes, then edit the Description and save.
  - **Then:**
    - the menu holds "Undo Check Out", "Check In" and "Source Control Messages";
    - the dialog shows "OcuPilot probe asks: proceed?";
    - the log holds `UserAction` and then `AfterUserAction` with answer 1, then `GetStatus`, `OnBeforeSave` and `OnAfterSave`, all for `<doc>.CLS` as `config.username`;
    - the editor shows "`<doc>` saved.";
    - every `sourcecontrol` request is the frame's own;
    - the main frame sends nothing under `/api/interop-editors/`;
    - `armMessageCounters` reads no message.
- **AC2 (refusal inside the editors).**
  - **Given** the probe refusing the DTL, **when** the person saves, **then** the editor shows "Unable to save `<doc>`", `definitionModified` is unchanged, and no `OnBeforeSave` is logged.
  - **Given** it refusing the rule, **when** the rule's screen opens, **then** the editor shows "This is marked Read Only by Server Side Source Control." and its menu holds "Check Out" and "Get Latest".
- **AC3 (the rule editor's compile).**
  - **Given** the rule checked out.
  - **When** the person chooses Compile.
  - **Then** the editor shows "Rule saved and compiled.", the log holds `OnBeforeSave`, `OnAfterSave`, `OnBeforeCompile` and `OnAfterCompile` in that order, and "Source Control Messages" is enabled.
- **AC4 (OcuPilot's saves run the hooks in process).**
  - **Given** a probe class.
  - **When** `AtelierPort` saves it with Compile on, then compiles it, then deletes it.
  - **Then:**
    - each answers 200;
    - the hooks are recorded in the matrix's order, with `job = $Job` and `user = $Username`;
    - a `%SourceControl` set before the call is unchanged after it.
- **AC5 (the named refusal).**
  - **Given** a class the probe refuses.
  - **When** the person saves it from the Classes list.
  - **Then** the answer is 409 `EXPLORER.DOCUMENT.SOURCECONTROL` with `REASONDOCUMENTSOURCECONTROL`, and the class is unchanged.
  - **And** the canned rows hold.
  - **And** a vetoed save is 422 `EXPLORER.SAVE.REFUSED`.
- **AC6 (Integration: Story 20.16's save is the consumer).**
  - **Given** an `interop.transformeditor.save` proposal on the probe DTL.
  - **When** it is confirmed while refused, and a second one is confirmed while allowed.
  - **Then:**
    - the first answers `EXPLORER.DOCUMENT.SOURCECONTROL` and leaves the text unchanged;
    - the second is confirmed, the text holds the edit, and the four save and compile hooks are recorded with `job = $Job`.
- **AC7 (one published sentence).**
  - **Given** the new refusal.
  - **When** `cd ui && npm run test:tools` runs.
  - **Then** `self-protection.test.mjs` finds `REASONDOCUMENTSOURCECONTROL` equal to `strings.ts`'s `explorerDocumentSourceControl`, and published in EXPERIENCE.md's Fixed strings.
- **AC8 (nothing left behind).**
  - **Given** a run of `SourceControlSave` or of the browser spec.
  - **When** it ends, passing or failing.
  - **Then** `SourceControlClassGet("USER")` reads `""`, and neither the hooks class nor its global exists.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs:**

- **AD-63**: all five limits, unchanged, and its named consequence, amended (draft below).
- **AD-61**: rule 3 (`%SourceControl` is `New`ed and the route makes its own), rule 4 (switched), rule 6 (the new refusal) and rule 8 (corrected, draft below).
- **AD-53**: the person's save and the agent's save are one operation, so they share one refusal.
- **AD-62 item 1**: OcuPilot never calls `%Api.InteropEditors`.
- **AD-39**: vendor text is logged, never sent.
- **AD-8**: no elevation. The hooks run as the user, and the editors create their instance through `%CSP.Portal.SourceControl.Base`, which does not require `%Development`.
- **AD-7**: one request. A slow hook makes the request slow.
- **AD-47 and AD-28**: unchanged.

Checked and not engaged: AD-5, AD-44 and AD-64 (no screen); AD-10, AD-15, AD-22 and AD-58 (no new write, key or marker); AD-36 (no read); AD-29's `TOP` rule (no SQL).

**Measured at this plan on `ocupilot-b-ci`** (2026-10-13). The probe was a `%Studio.SourceControl.Base` subclass recording each hook, enabled in `USER`. The probe classes `OcuPilotProbe.SC2010.*`, the setting (`^|"USER"|oddStudioMenu("00-SourceControlClass")`), `^OcuPilotProbeSC2010`, `^EnsPortal.Settings("_SYSTEM","LastBP")` and `/tmp/sc2010` were removed afterwards, and their absence was verified.

| Path | What ran (Login left out) | Answer |
|---|---|---|
| DTL editor in OcuPilot's frame: load | `OnBeforeLoad`, `OnAfterLoad`, then `GetStatus` per menu or status fetch | Menu "Undo Check Out", "Check In", "Source Control Messages" (disabled); the button enabled |
| DTL editor: Check In (action 1), Yes | `UserAction 0\|%SourceMenu,%CheckIn`, then `AfterUserAction ...\|1` | Dialog "Server Side Source Control ... Yes No Cancel" |
| DTL editor: Save | `GetStatus`, `OnBeforeSave`, `OnAfterSave`, then `UserAction 1\|1` and `1\|7` | "`<doc>` saved." |
| DTL editor: Save while refused | `GetStatus` only | "Unable to save `<doc>`"; `TimeChanged` unchanged; route 400 "not checked out" |
| Rule editor: opened while refused | Load hooks, then `GetStatus` | "This is marked Read Only by Server Side Source Control."; menu "Check Out", "Get Latest" |
| Rule editor: Compile | `GetStatus`, `OnBeforeSave`, `OnAfterSave`, `OnBeforeCompile`, `OnAfterCompile` | "Rule saved and compiled."; Messages enabled |
| BPL editor, framed and standalone | Load hooks only; only `sourcecontrol/enabled` is requested | Menu holds only "Source Control Messages" (disabled) |
| `AtelierPort` SAVE + Compile (in a terminal, as the caller) | `GetStatus` x3, `OnBeforeSave`, `OnAfterSave`, `OnBeforeCompile`, `OnAfterCompile`, with the job the caller's | 200 |
| `AtelierPort` SAVE, refused | `GetStatus` | Vendor: 400, `result.status` "ERROR #5865 ..."; OcuPilot today: 400 `PORT.VALIDATION` |
| Atelier `PutDoc`, `OnBeforeSave` veto | `GetStatus`, `OnBeforeSave` | 200, `result.status` #16008 wrapping #5001 |
| Atelier `DELETE doc` | `OnBeforeDelete`, `OnAfterDelete`, `UserAction 1\|2` | 200, `result.ext` holding the probe's question |
| `AtelierPort` read (`GetDoc`) | `Login` only | - |
| Vendor `CompileDTL` route | - | 500, `<NOTOPEN>CompileDTL` in a web process whose null device was closed (DW-2394/2395). The same compile in a terminal with `%SourceControl` set ran `OnBeforeCompile` and `OnAfterCompile` |

- No message reached the shell, and the shell's main frame sent no `/api/` request during the editor's source-control exchange.
- Selectors: `interop-source-control-menu button`; `.mat-mdc-menu-panel .mat-mdc-menu-item` (`aria-disabled`); `mat-dialog-container` and its "Yes" button; `.mdc-snackbar__label`; the rule editor's banner button whose text is "Compile"; the DTL's `#transform-settings-iconbutton`, `#transform-settings-description-textarea` and `#top-banner-button-2-secondary`.
- The icon's attribute read inconsistently, so no test asserts it.

**Rule 5 draft (for the lead, as 20.7's was).**

- **Original** (`epics.md` Story 20.10): "**Given** source control is enabled on the namespace **When** an embedded editor saves **Then** the hooks, menus, user actions and status are exchanged through the port."
- **Proposed:** "**Given** source control is enabled on the namespace **When** a person saves, compiles or uses the Source Control menu in an embedded rule, BPL or DTL editor, in normal mode **Then** the editor exchanges the hooks, menus, user actions and status with the instance itself, through the vendor's interoperability API inside the frame, as the signed-in person and as it does outside OcuPilot, and nothing reaches OcuPilot's shell; and OcuPilot's own saves of classes and routines, the agent's edits behind these editors included, run the same save and compile hooks through `AtelierPort` and refuse by name a document source control has not released for editing."
- **Options:**
  - **A (recommended):** the proposed wording, pinned by AC1 to AC6. The story's promise, "edits go through the same hooks they would elsewhere", is measured to hold: the frame is the vendor's own app.
  - **B, the literal reading:** OcuPilot relays source control through its port. That needs `?VSCODE=1`'s `userAction` message, or reaching into the frame, and AD-63 items 2 and 3 forbid both.
  - **C:** OcuPilot's own Source Control menu and status in the screen's bar, through `%Atelier_v1_Utils.Extension` behind a port. It would put a second menu on one document. Action 2 opens a CSP page OcuPilot would have to frame (AD-47). It needs a write tool and key. None of this is needed once A holds.
- **Tier:** apply-and-report. It restates the observable and keeps the intent. Nothing is narrowed: the BPL editor's empty menu is the vendor's, standalone as well (measured).

**Decisions:**

- **409 on the `CONFLICT` slug, logged at information severity**, as `LOCKED` is. It is the document's state, not the caller's input, and a source-control class's text can name the user who holds the document.
- **Only #5845, #5865 and #6151.** In the Atelier API these come only from the source-control edit check (`v1.cls`:1216, `v2.cls`:692, `RoutineMgr` `ConstructEditError`). A hook's own error is wrapped in #16008, which OcuPilot cannot attribute, so it stays 422.
- **`USER` and the namespace-config variable.** Enabling a source-control class is namespace configuration, the classic page `%CSP.UI.Portal.SourceControl`, so the tests take that variable. `USER` is where the save probes already live. The helper refuses a namespace that already has a class, so a run never replaces an operator's setting.
- **The rule editor carries the compile legs**, because the DTL and BPL compile routes can fail on DW-2394's null device in a reused web process (measured), while the rule's did not.

**Strings (one literal, add-only):** `explorerDocumentSourceControl` = `REASONDOCUMENTSOURCECONTROL` = "Source control has not released this document for editing, so nothing was saved. Check it out first."

**Spine and UX drafts (Rule 20; the lead writes them at the gate):**

- **AD-63, named consequence**, appended: "Story 20.10 [measured at its plan]: where the namespace has a source-control class, each editor in normal mode exchanges the hooks, menus, user actions and status with the instance itself, through `%Api.InteropEditors`' `sourcecontrol` routes and its save, load and compile routes, as the signed-in person: its Source Control menu lists the class's enabled items, a Yes/No/Cancel action shows the editor's own dialog and sends AfterUserAction, a save runs OnBeforeSave and OnAfterSave, a compile OnBeforeCompile and OnAfterCompile, and a document the class has not released is refused (the rule editor opens it read-only). Nothing reaches OcuPilot's shell. The BPL editor lists no source-control item, standalone too. OcuPilot's own saves of the same documents run the same hooks through `AtelierPort` (AD-61 rule 6)."
- **AD-61 rule 6**, appended: "A `PutDoc` answer whose text names #5845, #5865 or #6151 (the source-control edit check) is 409 `EXPLORER.DOCUMENT.SOURCECONTROL`, its text logged at information severity and never sent; a hook's own `OnBeforeSave` error arrives wrapped in #16008 and stays 422 `EXPLORER.SAVE.REFUSED` (measured at Story 20.10's plan)."
- **AD-61 rule 8**, replacing "`GET doc` instantiates the namespace's configured source-control class, whose hooks run as they do for every Atelier client (inference)": "`GET doc` instantiates the namespace's configured source-control class and runs none of its load hooks; a save, compile or delete runs its save, compile and delete hooks in the caller's process, as the caller (measured at Story 20.10's plan)."
- **EXPERIENCE.md :159**: the sentence in the task.

**Integration, Consumes, Consumed-by (Rules 1 and 2):**

- **Integration:** AC6. 20.16's `interop.transformeditor.save` consumes the new refusal and the port's hooks against the real instance. AC5's HTTP leg is the person's caller.
- **Consumes:**
  - 20.7's editor screens and frame, and 20.13's hand-off;
  - 20.16's save tool and `InteropEditorProbe`;
  - 19.3's `ExplorerSave` and `ExplorerSaveProbe`;
  - 20.21's `ExplorerSaveFlow.Dispatch`;
  - 20.7's browser helpers.
- **Consumed-by:**
  - 19.3's, 20.20's, 20.21's and 19.13's saves, which carry the refusal with no edit;
  - 20.12's guided workflows, whose confirmed saves take it too (inference).

**Rule 31 (extend, don't copy):**

- `NamesCode` generalizes `AccessDenied` rather than adding a second matcher.
- The canned rows extend 19.3's table.
- The live legs reuse the save, dispatch, confirm and probe helpers named above.
- `SourceControlProbe` is new: no sibling probe enables source control.
- The browser spec is a new file rather than an extension of `interop-editors.browser-spec.mjs` (680 lines). Its fixtures are `USER` and a namespace-wide setting, against 20.7's `HSCUSTOM`, and the shared helpers move to `interop-editor-spec.mjs` instead of being copied.

**Contended files (Rule 11).** `OCU-1-epic18` (`ada420c3`, local) changes `strings.ts` (+2), `strings.test.mjs` (the bound), EXPERIENCE.md :379, the spine (one line) and `scripts/ci-throwaway.sh` (+1). This story's edits to those files are add-only. It does not touch `AtelierPort.cls`, `AtelierError.cls`, `AtelierPortSave.cls` or `self-protection.test.mjs`. No Rule 11 ask.

**Named limits:**

- **The BPL editor's Source Control menu lists no item.** It requests only `sourcecontrol/enabled`, framed and standalone alike (measured). For the lead: a vendor candidate.
- **The DTL and BPL bundles have no source-control output interceptor** (bundle reading), so their "Source Control Messages" stays disabled.
- **The DTL editor's refusal says only "Unable to save `<doc>`".** DTL and BPL do not open a refused document read-only.
- **OcuPilot's create and delete drop the class's follow-up user action** (frontmatter `deferred`).
- **A hook's own `OnBeforeSave` refusal reads as 422 `SAVE.REFUSED`.**
- **A slow hook slows the request.**
- **A source-control class's console output from an OcuPilot save is not shown**, except inside a compile's lines.
- **System Explorer's editors show no source-control status or menu.**
- **20.8's configuration app carries the same vendor menu code** (bundle reading, inference), and this story does not pin it. Its leg belongs to 20.8's browser spec.

**Ledger inbox (Rule 17):** none.

## Verification

**Shared surfaces:**

- the strings table, its count, and EXPERIENCE.md :159 and :604;
- `self-protection.test.mjs`'s `ATELIER_REFUSALS`;
- the `OCUPILOT_ALLOW_NAMESPACE_CONFIG` arming roster;
- `AtelierPort`'s `PutDoc` 400 answer;
- the `interop-editor-spec.mjs` helper exports;
- `USER`'s source-control setting and its `^EnsPortal.Settings` nodes, which are transient.

*Every test added or changed passes on a fresh environment, in either order.* Each class and the browser spec enable the probe themselves and remove it, verified, after each test.

**Setup (slot B; never the dev instance `ocupilot-slot-b`):**

- **Load `src`:**
  1. Run `rsync -a --checksum --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-20/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`.
  2. In `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`, run `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)`.
- **Before a browser run:** `cd ui && npm run build && docker exec ocupilot-b-ci sh -c 'cd /durable/iris/csp/ocupilot && rm -rf ./*' && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`.

**Commands.** Run each in the foreground with `timeout: 600000`, one at a time. Read each class's result from `%UnitTest_Result`.

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.SourceControlSave`. Expected: green.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.AtelierPortSave --class OcuPilot.Test.AtelierPortDocument --class OcuPilot.Test.ExplorerSave`, plus every class the sweep changes. Expected: green.
- `(loop)` `cd ui && npm run test:tools`. Expected: green.
- `(loop)` `cd ui && npm run build`. Expected: the prebuild chain is green and the initial total is under 1992kB.
- `(loop)` `uv run scripts/check-objectscript.py <each changed .cls>` and `bash scripts/lint-docs.sh`. Expected: clean.
- `(loop)` After the redeploy, run `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/<file>`, one file per call. Expected: green.
  - `interop-editor-source-control.browser-spec.mjs`
  - `interop-editors.browser-spec.mjs`
- **Lead-owned:** the full ObjectScript sweep, `cd ui && npm test`, `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`, and Rule 30's fresh check.
- **Left to CI:** the full browser suite.

**Planned pinning mutations (Rule 19).** Revert each byte-identical. Reload, or rebuild and redeploy, before the next.

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | `interop-editor.page.ts` hands the frame `HSCUSTOM` whatever the scope | AC1: no document, so no "Check In" and no hook |
| AC2 | The probe's `GetStatus` answers editable whatever is refused (the fixture holds the vendor's behavior) | AC2's DTL leg (the save succeeds) and its rule leg |
| AC3 | The probe's `OnBeforeCompile` records nothing | AC3, and AC4's compile clause |
| AC4 | `SaveSet` stores the text with `SetTextFromString` in place of `PutDoc` | AC4's save clause, and AC6's allowed leg |
| AC5 | `Outcome` without the source-control branch | The four canned rows, AC5's HTTP leg, and AC6's refused leg |
| AC5 | `SOURCECONTROLCODES` without 5845 | The 5845 canned row alone |
| AC7 | One word of `REASONDOCUMENTSOURCECONTROL` changed | `self-protection.test.mjs` |

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

- Plan pass. The vendor editors' source-control exchange in OcuPilot's frame, `AtelierPort`'s hooks and its refusal answer were measured on `ocupilot-b-ci`; every probe was removed and verified gone.
- For the lead at the spec gate: the Rule 5 draft (Story 20.10's criterion, apply-and-report, option A), the Rule 20 drafts (AD-63's consequence, AD-61 rules 6 and 8), the frontmatter `deferred` item, and the BPL menu as a vendor candidate.
