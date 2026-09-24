---
title: 'Story 9.8: Edit task'
type: 'feature'
created: '2026-09-24'
status: 'done'
baseline_revision: 'f60ec57f88dcdab640612c3a50fb3b058e79ca67'
baseline_commit: 'f60ec57f88dcdab640612c3a50fb3b058e79ca67'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-9-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-9-7-the-new-task-wizard.md'
warnings: ['oversized']
deferred:
  - summary: >-
      A vendor 409 on Task.CRUD PUT that the edit rules do not pre-empt surfaces PORT.CONFLICT, whose sentence speaks of a duplicate name.
    evidence: |-
      Implement pass: the past-start 7432 refusal maps to the port's generic 409 conflict; the rules refuse the reachable cases first (STARTDATE.PAST), so an unforeseen 409 would read as a name clash. Settle by listing the vendor's 409 causes for RunPut and mapping each.
    location: >-
      src/OcuPilot/Port/TaskPort.cls
    severity: medium (unverified)
---

<intent-contract>

## Intent

**Problem:** A scheduled task can be created, run, suspended, resumed and deleted from OcuPilot, but its settings cannot be changed. Fixing a schedule still means deleting and recreating the task, or leaving for the classic portal.

**Approach:** Add the edit half of `TaskForm`: a tabbed `form-page` at `tasks/schedule/edit/<id>`, opened from Task details' Edit. Its tabs are the wizard's four steps, drawn from the same field model. It saves through a new merge-write tool, `tasks.schedule.update`: the screen's Save uses it under AD-55 and the agent's proposal under AD-4 and AD-6.

## Boundaries & Constraints

**Always:**

- **One model.** The tabs are `task-fields.ts`'s `STEPS`, and each tab draws `fieldsOfStep(step)` with the wizard's own labels. The wizard's step and field templates move into one shared component that the stepper and the tabs both render, so no field template exists twice. Rules are `TaskRules.Validate`, which gains an `update` mode over the fresh read.
- **Tool `tasks.schedule.update`** (`Screen/Tool/TaskUpdate.cls`), on `TaskScheduleList`:
  - `READTYPE GET`, `WRITETYPE PUT`, `SENDSBODY 1`, `CHANGEACTION updated`, `PORTCLASS TaskPort`.
  - `IdArgument` is `Id` and `IdParam` is `id`, as `TaskDelete` does. The target is `task:instance:<id>`.
  - `PERMITTEDFIELDS` holds the create's 34 fields minus `TaskClass` and `NameSpace`. Both are drawn read-only with `taskEditFixed`; changing a task's type replaces every setting, so that stays delete-and-create.
  - `MergeUpdate` is a new `Write` hook. Its default is `Mint.Merge`, and it is called by `Mint`, by `Confirm.FingerprintMatches` and by the screen Save. The task tool merges a supplied `Settings` key by key over the fresh read's `Settings` and writes a `Settings.<key>` diff row for each change. Every other field uses `Mint.Merge`.
  - `ArgumentProblem` calls `Validate("update")` over the fresh read.
  - The derived schema is described by `TaskCreate.Described`. `TaskClass` and `NameSpace` are absent from it.
- **Port** (`TaskPort`, `Task.CRUD`, vendor facts measured below):
  - Add `Task.CRUD/PUT` to `MUTATINGTYPES`. The existing `PROPERTYFAULTS` rows apply to it unchanged.
  - **GET:** drop the whole `Settings` object when the task's type declares a classic-only setting. A setting is classic-only when it is of type `%SYS.Task.Password` or a subclass, credential-named, or a collection. `TaskPort` owns this one classifier. `TaskRules.TypeSettings` reads it, so the wizard also draws `SMTPPass` classic-only.
  - **PUT:** drop `Type` (the port's own GET completion adds it). Drop `DailyStartTime`, `DailyEndTime` and `Settings` when they equal the stored value, which the port reads fresh inside the call. The vendor keeps a key that is omitted.
- **Rules in update mode.**
  - A rule is judged only when a field it reads changed. A stored value is sent back as the instance holds it.
  - **Name:** a rename that another task's id already uses, compared case-insensitively, is refused `TASK.NAME.TAKEN`. The task's own name is not a conflict.
  - **Start:** changing `StartDate`, `DailyStartTime` or `DailyEndTime` requires `StartDate` plus `DailyStartTime` to be later than now (`TASK.STARTDATE.PAST`).
  - **RunAsUser:** judged only on a change. `TASK.RUNASUSER.SECURE` applies when the new value is neither the stored account nor `$Username`.
  - **Output file:** a changed `OutputFilename` follows AD-21's pattern, and `OutputDirectory` is never the caller's. When the stored directory is neither `""` nor the manager directory, a change is refused `TASK.OUTPUTFILENAME.CLASSICONLY`.
  - **Settings:** a `Settings` argument on a task whose read carries no `Settings` is refused on `Settings`: `TASK.SETTING.SECRET` for a secret setting, `TASK.SETTING.CLASSICONLY` otherwise.
- **Prohibited set** (`Prohibited.cls`, arms appended):
  - `PermittedChangeFields` gains a `TYPETASK` arm equal to `PERMITTEDFIELDS`. A `Settings.<key>` change is judged as `Settings`.
  - `GrantsPrivilegeByEffect`'s task arm receives the live target, as `Resource` does. It is true only when `RunAsUser` changes to an account that is neither the stored one nor `$Username`.
  - The create's behavior, with no live target, is unchanged.
- **Screen Save** is `PUT /tasks/:id` → `TaskSave.HandleUpdate`, in `SslSave.Update`'s order:
  1. pairs;
  2. an integer id;
  3. the fresh read (404 `TASK.ABSENT`);
  4. undeclared keys (400);
  5. changed fields;
  6. rules (422);
  7. `MergeUpdate`;
  8. the prohibited set;
  9. send;
  10. port violations.

  It answers 200 `{id, name}`.
- **Form read:** `GET /tasks/form?id=<n>` adds `task` (the tool's fresh read with `Id`) and `settingsClassicOnly`. `types` covers the task's namespace. An absent id answers 404 `TASK.ABSENT`.
- **Route:** add `/tasks/:id` PUT after `/tasks/check` and before `/tasks`.
- **Client:**
  - `TaskEditorPage` (new) is registered in `DESCRIPTOR_EDIT_PAGES`, so the bare route keeps the wizard.
  - The wizard store gains an edit mode: `open(id)`, an `opened` snapshot, `changedBody`, `saved`, `absent`, and `refresh` on a change event. It follows `SslFormStore`.
  - Save sends the changed fields only, and `Settings` whole when any setting changed. On success it shows "Saved" and publishes `task` `updated` with the numeric id (AD-14).
  - A refused Save opens the tab holding the first refused field through `tabToOpen`, then focuses the summary and then that field. It carries the dirty guard and the RunAsUser consequence line.
  - The page links to the task's details.
- **Entry points:**
  - Task details' Edit link goes live because `CREATE_ONLY_FORMS` is emptied.
  - The schedule list's name cell keeps opening Task details (EXPERIENCE.md :109). A list that declares both a detail screen and an editor opens the detail screen; Task schedule is the only such list.
  - `TaskForm`'s `labelKey` becomes the neutral `proposalEntityTask`, as `UserForm`'s is.
- **DW-1624:** the edit tabs draw every value of a wizard-created task, read from the instance: priority, output file and its flags, suspend, reschedule, batch, mirror status, and the three address lists.
- **Copy:** new words go in `strings.ts` and in Fixed strings, marked `[ADDED 2026-09-24 - see the story change log]`. Use tokens and `\uXXXX` escapes only.
- **Probes:** tests create only tasks named `OcuP98*`, on `ocupilot-ci`, and delete them by id after checking the exact name. Each task-creating test class is armed on `OCUPILOT_ALLOW_TASK_CONTROL` and added to that block's `# classes:` line.

**Never:**

- Changing `TaskClass` or `NameSpace` on an edit.
- Returning a classic-only setting's value in any read, payload, diff, ledger row or log line (AD-35).
- A second field template, `@angular/material/stepper`, or lazy loading.
- A `fingerprintExcludes` on `TaskScheduleList`. `TaskScheduleRun`'s subject names `NextScheduled`, so the registry would refuse it.
- Touching a vendor task in a test.
- Edits beyond appends in the shared-append files.
- A full browser-suite run locally.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Two-field save | `OcuP98Edit`, Weekly on `24`, AC7 values set; change Description and DailyIncrement | 200 and "Saved". Those two change; every other field and the settings read back unchanged (`docker exec`) | — |
| Past start | A probe task whose stored start is in the past (SQL `UPDATE` of `StartDate`); change Description | 200. The body omits the unchanged times | — |
| Time on a past start | The same task; change `DailyStartTime` only | Nothing is sent | 422 `TASK.STARTDATE.PAST` on StartDate |
| Rename taken | Rename to `Purge Tasks` | Nothing is sent | 422 `TASK.NAME.TAKEN` |
| Secret-bearing type | A `%SYS.Task.DiagnosticReport` probe with `SMTPPass` set | The form read and the proposal carry no `Settings`. An edit keeps `SMTPPass`, compared in process and never printed | A settings change: `TASK.SETTING.SECRET` |
| Runs as another, unchanged | A least-privileged principal edits the Description of a task that runs as `_SYSTEM` | 200; the proposal is not destructive | — |
| Runs as another, changed | The same principal sets RunAsUser to `_SYSTEM` | Nothing is sent | `TASK.RUNASUSER.SECURE` |
| Agent edit, task ran | Mint `tasks.schedule.update`, then RunNow; `NextScheduled` and `LastFinished` move | Confirm writes. It is not refused as target changed | A field changed by someone else still refuses |
| Absent | PUT to or open a deleted id | The page shows "This task no longer exists." | 404 `TASK.ABSENT` |

</intent-contract>

## Code Map

S = `src/OcuPilot/`, U = `ui/src/app/`. Anchors are at HEAD `8ab8886e8de5bf330aae99922e874ce02643cd35`.

**Vendor facts, measured on `ocupilot-ci` on 2026-09-24 over `/api/admin/v2/task` (the same endpoint class). Probes were removed.**

- Read with `GetTextAsString` on slot A:
  - `Task.CRUD` `RunPut` is `%OpenId`, `MergeJsonAndObj`, `%Save`. A 7432 answers 409, and the answer is `TaskToJson`.
  - `ValidateRequest` sets `AllRequired` only for POST.
  - `MergeJsonAndObj` sets only the keys the body defines.
  - A body that carries `Settings` builds a new `%New` of the task class and applies `SetSettings`.
  - GET answers the 34 template keys plus `Settings`. It does not answer `NextScheduled`, which only `INFO` answers.
- **PUT behavior:**
  - A body carrying `Type` answers 400 #40307.
  - A partial body answers 200 and the other keys are kept.
  - A body with no `Settings` keeps the settings. `Settings: {}` resets each setting to its default.
- **What moves:**
  - A Description PUT moves only Description on GET and nothing on INFO.
  - A `DailyStartTime` PUT moves INFO's `NextScheduled`.
  - A run moves INFO's `NextScheduled`, `LastSchedule`, `LastStarted`, `LastFinished` and `Error`, and nothing on GET.
- **A stored past start:**
  - A PUT that re-sends the unchanged `DailyStartTime` or `DailyEndTime` answers 409 #7432.
  - Every other key re-sent alone answers 200, and so does the complete body without those two.
  - An object `%Save` of Description alone passes.
- **Run as another account:** a principal holding only `%Admin_Task:U` and `%DB_IRISSYS:R`:
  - edits a task that runs as another account with RunAsUser unchanged: 200;
  - changes RunAsUser to another account: 500 #7405;
  - renames a task to a taken name: 200, because the vendor accepts duplicates.
- **Output directory:** `OutputDirectory ""` writes the file to the manager directory (`/durable/iris/mgr/`).
- **Secret setting population:**
  - `%SYS.Task.DiagnosticReport.SMTPPass` is typed `%SYS.Task.Password`. It is the only such property in `HSCUSTOM` and `%SYS`.
  - `IsCredentialName("SMTPPass")` is 0, and 9.7's `TypeSettings` draws it as an ordinary setting.
  - Vendor task 6 has this type on slot A and on `ocupilot-ci`.
- **Slot A tasks:** 18 tasks. No task sets an output directory or file. Setting values are strings or integers.

**Server:**

- `S/Screen/Tool/TaskCreate.cls` is the template for `Described`, `PrivilegePairs` and `Consequence`. `TaskDelete.cls` :19-82 has the `Id`/`id` target and `TaskPort`.
- `S/Screen/Tool/Write.cls` holds the parameters (:30-201), `IdArgument` (:477) and `ComposeCreate` (the hook precedent).
- `S/Kernel/Proposal/Mint.cls`: `Merge` :455 (an object argument replaces the value wholesale, :482) and the merge call ~:197. `Confirm.cls` `FingerprintMatches` :570-642 re-merges at :623, and `ToolDerivedFields` is at :363/:685.
- `S/Kernel/Proposal/Prohibited.cls`:
  - `PermittedChangeFields` :494-508 has no task arm yet;
  - `Task()` :1323 and `ReviewedFewOnly` :1490;
  - `GrantsPrivilegeByEffect` task arm :1817-1823;
  - `Prohibits` passes `tTarget` to `Resource` at :709/:717, and the task arm gets only `.tChanged` at :743.
- `S/Port/TaskPort.cls` :41-86 (GET completion and `Create`). `S/Port/AdminPort.cls` `MUTATINGTYPES` :269 and `PROPERTYFAULTS` :2247, which is keyed by endpoint.
- `S/Area/Task/TaskRules.cls`: `Validate` :82, `TypeSettings` :623 (classic-only at :695-700), `NameTaken` :779, `HandleForm` :813. `TaskSave.cls` is the create; `S/Area/Security/SslSave.cls` :176-229 is the update template, and `SslRules.HandleForm` :296 shows the `?name=` read.
- `S/Api/Router.cls` :154-156 holds the routes and :1039-1060 the wrappers (`SslUpdate(pId)` :1025 is the template). `S/Api/Error.cls` holds the `TASK.*` codes :2621-2888 and `TaskViolationCodes` :2900.
- `S/Screen/Tool/Classification.cls`: copy the create's entry at :484-520 as `tasks.schedule.update`, then run `cd ui && node tools/field-lists.mjs`.
- `S/Screen/Descriptor/TaskForm.cls` (doc and `labelKey`) and `TaskScheduleList.cls` (doc).

**Rosters:**

- `Test/ToolWrite.cls` :1169-1296 asserts `Task.CRUD/PUT` is not mutating. That is the tripwire this story re-points.
- `Test/PortFixture.cls` :21, `Test/SurfaceCoverage.cls` :143-149, `Test/ToolRoundTrip.cls` :35 (`REFUSEEMPTY`).
- `Test/Prohibited.cls` :327/:394-405: `SettableFields` must equal `PermittedChangeFields`.
- `Test/EndpointCoverage.cls` :159-163 and :402.
- `Test/Descriptor.cls` :537-560 (no `fingerprintExcludes`, kept).
- `Test/Wire.cls` :627 and `Test/WireSecurityRead.cls` :388/:392 (TaskForm's `labelKey`).
- `scripts/ci-throwaway.sh` :271-273 and `ui/tools/ci.test.mjs` :1764-1900.

**Client:**

- `U/areas/tasks/task-fields.ts` (whole file) and `task-wizard.store.ts`:
  - reads :233-331; writes :336-544;
  - `open` :357;
  - `setText` :397 (a period change resets the day; a type change reloads settings);
  - `loadTypes` :552; `change` :568.
- `U/areas/tasks/task-wizard.page.ts`:
  - step bodies :160-446 (they move to the shared component);
  - `view`/`settingView` :881-937 and the field getters :581-716;
  - `afterRefusal` :819-875.
- The create-and-edit template is `U/areas/security/ssl-form.store.ts` (`open` :438, `absorb` :714, `save` :538-578, `changedFields` :679, `publish` :773) with `ssl-form.page.ts` (summary :134, tabs :157, bar :561, leave dialog :577, `routeId` :1056).
- `U/core/navigation.ts` `CREATE_ONLY_FORMS` :202 (with the docs at :194 and :172). `U/shell/data-table.ts` :496-506 decides the name cell. `U/shell/screen-outlet.ts` `DESCRIPTOR_EDIT_PAGES` :131. `U/areas/tasks/details.page.ts` :115-118 and :277 draw Edit.
- `U/core/strings.ts`: `taskDetailsEdit` :811, `formSaved` :254, `formLeaveWithoutSaving` :258, `taskSettingClassicOnly` :2066, `taskRunAsOtherEffect` :2064, `taskDetailsGone`.
- `ui/angular.json` :51-57: the warning is at 1551kB and the error at 1600kB. The current build is 1,524,742 B.
- Browser:
  - `ssl-editor.browser-spec.mjs` :230-425 is the template, including its visual gate at :425;
  - `tasks.browser-spec.mjs` :492 and :526-528;
  - `task-wizard.browser-spec.mjs`;
  - `structural-walk.mjs` walks editors at their bare route only (:122-130).

## Tasks & Acceptance

**Execution:**

Server:

- `S/Port/AdminPort.cls` and `S/Port/TaskPort.cls` -- `Task.CRUD/PUT` mutating; the classic-only classifier; GET drops a classic-only type's `Settings`; PUT drops `Type` and the unchanged times and `Settings` -- the vendor wire facts stay in the port (AD-27's containment; AD-35).
- `S/Screen/Tool/Write.cls` -- the `MergeUpdate` hook, defaulting to `Mint.Merge` -- no behavior changes for existing tools.
- `S/Kernel/Proposal/Mint.cls` and `Confirm.cls` -- call the tool's `MergeUpdate` at the merge and at the fingerprint re-merge -- so mint and confirm take one digest.
- `S/Screen/Tool/TaskUpdate.cls` (new) -- the tool as in Boundaries -- one tool for both callers.
- `S/Kernel/Proposal/Prohibited.cls` -- the `TYPETASK` change list; the privilege-by-effect delta with the live target -- AD-10 by effect.
- `S/Area/Task/TaskRules.cls` -- `update` mode; `NameTaken` excludes the task's own id; `TypeSettings` reads the port's classifier; `HandleForm ?id=` -- one rule set.
- `S/Area/Task/TaskSave.cls` (`HandleUpdate`/`Update`), `S/Api/Router.cls` and `S/Api/Error.cls` (`TASK.ABSENT`, whose reason is "This task no longer exists.", and `TASK.OUTPUTFILENAME.CLASSICONLY`) -- AD-12, AD-39 and AD-55.
- `S/Screen/Tool/Classification.cls` and the regenerated `ToolFields.cls`; `S/Screen/Descriptor/TaskForm.cls` and `TaskScheduleList.cls` (`labelKey` and docs); `scripts/ci-throwaway.sh`.

Server tests (armed; `OcuP98*` names only):

- `Test/TaskUpdate.cls` (new) -- the schema; the mint's diff rows; a confirm after a run; the untouched fields surviving an agent confirm; RunAsUser unchanged and changed; the secret-bearing type.
- `Test/TaskEdit.cls` (new) -- the Matrix rows through `PUT /tasks/:id` and `GET /tasks/form?id=`, and the port's PUT omissions.
- `Test/TaskWire.cls` -- the new route and read refuse a principal missing a pair, and each answers one envelope.
- The rosters in the Code Map, with names read from the instance.

Client:

- `U/areas/tasks/task-fields.ts` plus `tools/task-fields.test.mjs` -- `valuesFromTask` (with `HH:MM:SS` read as `HH:MM`), `changedBody`, `EDIT_FIXED_FIELDS`, and the tab map equal to the step map.
- `U/areas/tasks/task-field-group.ts` (new) -- one field group per step key, rendered by the wizard's steps and by the editor's tabs.
- `task-wizard.store.ts` (edit mode) and `task-editor.page.ts` (new), each with its spec -- load, absent, save, Saved, refusal routing, dirty guard, refresh, and the details link.
- `U/shell/screen-outlet.ts`, `U/core/navigation.ts` and `U/shell/data-table.ts` -- the edit page entry, the emptied set, and the detail screen chosen before the editor -- with `navigation.test.mjs` and `details.page.spec.ts` legs.
- `U/core/strings.ts` plus EXPERIENCE.md Fixed strings -- `taskEditFixed`, the two new reasons, and any new label.
- `ui/browser/task-editor.browser-spec.mjs` (new) -- Details › Edit; every DW-1624 value drawn; a two-field save read back by `docker exec`; refusal routing; the leave dialog; the visual gate. `tasks.browser-spec.mjs` -- Details shows Edit.

**Acceptance Criteria:**

- **AC1.** Given a task, when its edit form opens from Task details' Edit, then:
  - the form shows the wizard's fields, each with the task's current value, in four tabs named for the wizard's steps;
  - `TaskClass` and `NameSpace` are shown and read-only;
  - a refused Save opens the refused field's tab, with its marker and ", N errors".
- **AC2.** Given a Save or a confirmed agent edit that changes two fields, when it is sent, then the body is the fresh read merged with the change. The port omits only the unchanged keys listed in Boundaries, and every field the caller did not change reads back as it was.
- **AC3.** Given a proposal minted before the task runs, when the run moves `NextScheduled`, then the confirm writes. The tool's fresh read does not carry that field (measured), so the fingerprint cannot cover it, and `TaskScheduleList` declares no exclusion.
- **AC4.** Given a task whose type holds a secret setting, when it is read, edited or proposed, then the setting's value appears in no answer, payload, diff or ledger row, and an edit keeps the stored value. A `Settings` change on such a type, from either caller, is refused `TASK.SETTING.SECRET` by name before any port call, so a replacing `Settings` that drops the secret is never sent (AD-4 as amended, ruling c006bcb3). Pinned on a `%SYS.Task.DiagnosticReport` probe on `ocupilot-ci`: an edit changing another setting without the secret is refused and the stored `SMTPPass` is unchanged; an edit that leaves `Settings` unchanged writes, and `SMTPPass` survives it (compared in process, never printed). Each leg has its own `mutation:` line.
- **AC5.** Given a principal without `%Admin_Secure:USE`, when it edits a task that runs as another account and leaves RunAsUser unchanged, then the save succeeds and the proposal is not destructive. When it changes RunAsUser, both callers refuse on RunAsUser.
- **DW-1624.** Given a task created by the wizard with the AC7 values, when its edit form opens, then every value is drawn from the instance. The browser spec asserts each one.
- **Integration.** Given `TaskEditorPage`, which consumes `GET /tasks/form?id=`, `PUT /tasks/:id` and `ChangeBus`, when a Save succeeds, then Task details and Task schedule re-fetch and show the new value. The browser spec observes this.

### Review Findings

Code review 2026-09-24 (four layers, full-opus). 0 decision-needed, 6 patch (applied), 1 routed, 5 closed at emission, 26 rejected.

- [x] [Review][Patch] [med] An edit skipped the privilege the task's type declares (`%SYS.Task.Definition.CheckPermission`, e.g. `Ens.Util.Tasks.Purge`'s `%Ens_PurgeSchedule:USE`), which the create and the classic editor enforce and the vendor PUT does not (read on the instance) -- `ValidateUpdate` refuses any change `TaskClass:TASK.TASKCLASS.PERMISSION`; `TaskWire.TestTheLeastPrincipalCannotEditATypeItsPrivilegeGuards` (Save and mint). fix-risk low. [src/OcuPilot/Area/Task/TaskRules.cls:250]
- [x] [Review][Patch] [med] The card's `unchangedCount` counted `Type` and the two held times the port never sends (over by 3 to 4), and the only assertion pinned the overcount -- `MergeUpdate` counts the unchanged keys `TaskPort.Trimmed` keeps; the assertion now expects them. fix-risk low. [src/OcuPilot/Screen/Tool/TaskUpdate.cls:166]
- [x] [Review][Patch] [low] `WithholdSettings` answered the settings of a type not compiled in the task's namespace, contrary to its doc (AD-35) -- `ClassicOnlySettings` reports `pRead`, and an unread type is withheld; `TaskRules.TestAnUnclassifiableTypeIsWithheld`. [src/OcuPilot/Port/TaskPort.cls:179]
- [x] [Review][Patch] [low] `WithheldSettingsCode` set `SECRET` on a classifier error and then failed the call (500 / internal mint error) -- it now answers `$$$OK`, so the change is refused by name; same test. [src/OcuPilot/Area/Task/TaskRules.cls:452]
- [x] [Review][Patch] [low] `TaskEditProbe.RunNow` ran any id -- it now refuses a task whose name does not start `OcuP98`. [src/OcuPilot/Test/TaskEditProbe.cls:116]
- [x] [Review][Patch] [low] AC4's agent-caller guard (`TaskUpdate.MergeSettings`'s withheld branch, which runs before `ArgumentProblem`) had no isolating mutation -- line added under Verification. The Save's second guard is the same branch (500, nothing sent).
- [x] [Review][Defer] [med] Task delete, suspend, resume and run skip the type's declared privilege too -- out of footprint: DW-1638 `routed owner=burndown`.
- [x] [Review][Defer] [low] DW-1636: a 7432 on the Save lands on StartDate (422, `PROPERTYFAULTS`); only a start that passes inside the confirm window reaches the agent card as `PORT.CONFLICT`'s name sentence. Measured on `ocupilot-ci`: changing `TimePeriodEvery`, `TimePeriodDay` or `DailyIncrement` on a past-started task answers 200. `wontfix-accepted`, reopen_if in the ledger.
- [x] [Review][Defer] [low] The Integration browser leg sees the re-read that navigation causes, not the event; the publish is pinned by `task-wizard.store.spec.ts` and the editor is full-page, so no task screen is mounted during a Save. `wontfix-accepted` reopen_if=a task list or details view renders beside the editor.
- [x] [Review][Defer] [med] A principal without `%Admin_Secure` may edit the settings of a task that runs as `_SYSTEM` -- `by-design` (AC5, Boundaries "judged only on a change"; the vendor allows it, measured).
- [x] [Review][Defer] [low] Save merges over the fresh read with no opened-state check, so a concurrent edit of the same field is last-writer-wins -- `by-design` (the `SslSave.Update` template; no Save carries one). `TaskForm`'s neutral `labelKey` retitles the wizard "Task" -- `by-design` (Boundaries), so EXPERIENCE.md's 9.7 row calling "New task" the title is stale.

Rejected (false): vendor omits `Settings` for a type with none (19 of 19 tasks on `ocupilot-ci` answer an object); `Judged` misses period fields on a past start (measured 200 above); an edited file with `OutputDirectory ""` misses the manager directory (measured vendor fact, triage R4); `TASK.ABSENT` in `TaskViolationCodes` (`ReasonForTask` needs it); duplicate `Remove` in `TestTheFormReadAnswersOneTask` (two probes); AC1 needs a mutation per bullet (Rule 19 is per AC); the port trim guards a changed `Settings` (it drops only an equal one); the QA test is uncommitted (the lead commits). Rejected (low): a declared setting the stored read lacks answers 500 (0 of 19 tasks; nothing sent); stale dependent fields after a period change (the rules judge the merged period); blur marks an over-long held value (Save is not blocked); the editor's `NavigationEnd` on an id-less route and the shared root store (destroy precedes create); the classic-only sentence with an empty list for an unreadable namespace (residual risk already recorded); a leading-zero id; duplicated time and read helpers, `NameTaken`'s second branch, `Changed` run twice; duplicated checkbox SCSS; `ToolWrite`'s leftover `id`; `taskOutputFileClassicOnly` unused in the client; details-page and browser coverage of a secret-bearing edit (component tier covers it); the "before any port call" wording (the fix edits the AD).

## Spec Change Log

- 2026-09-24 spec gate (lead): ruling 2 approved by the orchestrator (c006bcb3) with a condition: a changed `Settings` on a secret-bearing type must carry the secret or be refused by name; AD-4 amended with it; AC4 extended to pin both legs.

- 2026-09-24 spec gate (lead): ruling 1 applied as recommended (epics.md 9.8 AC3 amended, Rule 5 tier 1); ruling 2 (AD-4) asked of the orchestrator before the implement spawn; DW-1631 filed and routed here.

## Review Triage Log

### 2026-09-24 — Review pass

- verdicts: 20 findings — high 0, medium 6, low 7, false 7, maybe-false 0
- findings:
  - `[medium]` `[patch]` (verification-gap) a changed output file on a task writing to the manager directory is never saved in a test — `TaskEdit.TestTheEditsOwnRefusals` now saves `other.txt` there and reads name and directory back; mutation line added.
  - `[low]` `[patch]` (verification-gap) the mint's "held time in the other spelling" leg sent the instance's own spelling — `TaskUpdate.TestTheMintAnswersOneRowPerChange` now sends `01:00` against a held `01:00:00`; mutation line added.
  - `[medium]` `[patch]` (verification-gap) DW-1631's wizard side (`SMTPPass` classic-only through `TypeSettings`) had no test — `TaskRules.TestASecretTypedSettingIsClassicOnly` pins the type read, the create's refusal by name and the edit's code; mutation line added.
  - `[medium]` `[patch]` (verification-gap) edit-mode setting refusals (invalid, unknown) unexercised — `TaskEdit` Save legs for `KeepDays abc` (INVALID) and `Nope` (UNKNOWN), and a `TaskUpdate` mint leg for UNKNOWN.
  - `[low]` `[patch]` (verification-gap) `WithheldSettingsCode`'s `TASK.SETTING.CLASSICONLY` branch untested — a leg on `HS.Registry.Document.Archive.Task` in `TaskRules.TestAListSettingIsClassicOnly`.
  - `[medium]` `[patch]` (verification-gap) the AC3 test confirmed before the task had run — `TestAConfirmAfterTheTaskRanWrites` now waits, bounded at 150 s, for INFO's `LastFinished` to move before confirming (run 10441 green).
  - `[low]` `[patch]` (verification-gap) read-back assertions skipped silently when the task is missing — `$$$AssertTrue($IsObject(...))` added before each in `TaskEdit`, `TaskWire` and `TaskUpdate`.
  - `[low]` `[patch]` (verification-gap, other) a case-only retype of the stored run-as account was a change, so a principal without `%Admin_Secure` was refused — `TaskRules.SameValue` compares `RunAsUser` without case; `TaskRules.TestAnEditComparesTheAccountWithoutCase`; mutation line added.
  - `[false]` `[reject]` (intent-alignment R1) the start rule also reads `TimePeriod` — measured on `ocupilot-ci`: a period change on a past-started task is refused by the vendor (7432, `TASK.STARTDATE.REFUSED`), so judging it first is the one sensible reading; `TaskEdit.TestAStartAlreadyPastIsSentBackAsHeld` now pins the period leg at 422 `TASK.STARTDATE.PAST`.
  - `[false]` `[reject]` (intent-alignment R2) the change event's id is a string — every `ChangeBus` id is a string; the value is the task's numeric id, as AD-14 asks.
  - `[medium]` `[patch]` (intent-alignment R3) AC3 pinned "scheduled to run", not "ran" — same root cause and fix as the AC3 row above.
  - `[false]` `[reject]` (intent-alignment R4) a changed file on a task holding `OutputDirectory ""` keeps `""` — measured vendor fact: `""` writes to the manager directory, which is what AD-21 asks.
  - `[low]` `[patch]` (intent-alignment R5) run-as account case — same root cause and fix as the case-only retype row above.
  - `[low]` `[reject]` (intent-alignment R6) shared-file edits beyond appends — `Prohibited.cls` is not a shared-append file and the spec directs its arms; the one rewritten line in `strings.ts` is `taskCreate`'s `EXPERIENCE.md:541` reference moved to `:543`, forced by the two appended Fixed-strings rows and pinned by the strings roster test.
  - `[medium]` `[patch]` (intent-alignment R7) no create-side test of `SMTPPass` classic-only — same root cause and fix as the DW-1631 row above.
  - `[false]` `[reject]` (intent-alignment R8) body parsed before the id check — `SslSave.HandleUpdate`, the named template, parses the body before decoding the id too.
  - `[false]` `[reject]` (intent-alignment table) past start probed on a once-a-day task, not the AC7 weekly one — the Matrix fixes no shape, and once-a-day is the shape the vendor re-checks (measured), so it is the one that makes the omission load-bearing.
  - `[false]` `[reject]` (intent-alignment table) the summary's focus step is not in the browser spec — `task-editor.page.spec.ts` pins the focus order at the component tier.
  - `[low]` `[reject]` (intent-alignment table) DW-1624's probe is created through `TaskSave.Create`, not the wizard's UI — the same server Save the wizard posts to, with the AC7 values; the UI create is pinned by `task-wizard.browser-spec.mjs`.
  - `[false]` `[reject]` (intent-alignment table) other reads may carry a classic-only value — probed on `ocupilot-ci`: `Task.CRUD` `LIST` and `INFO` carry no `Settings`, and Task details names no `Settings` field.

## Design Notes

**Governing ADs:**

- AD-3, AD-4 (ruling 2), AD-5, AD-6, AD-8, AD-10, AD-13 (`task:integer`), AD-14, AD-16;
- AD-19, AD-21 (the third exception on the edit form), AD-27 (containment only; not a fallback case: the same endpoint is called), AD-29, AD-34, AD-35;
- AD-39, AD-44 (the one classic key remains `utilsystaskbuilder`; the edit's `UtilSysTaskOption.csp` is not declared (inference: one descriptor carries one key)), AD-52, AD-53, AD-55, AD-56 (ii).

**Choices:**

- **The edit is reached from Task details.** EXPERIENCE.md :109 names Task details › Edit and a row overflow menu. The menu entry is not built, because row actions are AD-53 write operations and navigation is not one. The name cell keeps opening details, as Story 6.7 decided.
- **Run as another account** is judged on a change. The vendor enforces the same rule (measured), so an edit of a vendor task that runs as `_SYSTEM` is an ordinary edit.
- **Bundle (inference):** the shared field-group component keeps the wizard neutral. The editor page, the store's edit mode and the model additions come to about +10 to 15 kB, for an initial total of about 1.535 to 1.54 MB. That is under the 1580kB stop line and possibly under the 1551kB warning. Report the measured figure. If the measured total crosses 1580kB, HALT with `intent gap` and state the figure.

**Requested lead rulings (Rule 5 / Rule 20; the spec implements the recommended answer):**

1. **epics.md 9.8 AC3 (apply and report).** The Then clause presumes that the fingerprinted read carries the next-scheduled time. It does not (measured), and excluding `NextScheduled` on `TaskScheduleList` would break `TaskScheduleRun`'s subject. Replace the Then clause with:

   > "that field is outside the fingerprint -- the tool's fresh read does not carry it (measured) -- and a test pins that a proposal whose task ran before confirm still writes"

2. **AD-4 (Rule 20).** Append:

   > "`Task.CRUD`'s port omits a re-sent `DailyStartTime` or `DailyEndTime` equal to the stored one, because the vendor re-checks the start against the clock and refuses 7432 on a past-started task. It omits an unchanged `Settings`, because a sent `Settings` replaces every setting and a secret-typed setting is never read (AD-35). It omits its own `Type`. The vendor keeps an omitted key (measured). [AMENDED 2026-09-24, Story 9.8 plan]"

   If this is declined, a task whose start has passed (every vendor task) cannot be edited, and a Diagnostic Report task's SMTP password is erased on its first edit.

**Ledger inbox:** DW-1624 is addressed by the DW-1624 AC. DW-1631 (the 9.7 wizard's `SMTPPass` exposure, filed at the spec gate) is addressed by AC4's classifier.

**Contention:** `origin/OCU-1-epic12` edits `AdminPort.cls` (the `MUTATINGTYPES` line), `PortFixture`, `SurfaceCoverage`, `ToolRoundTrip`, `ci-throwaway.sh`, `strings.ts`, `screens.generated.ts`, `_components.scss`, EXPERIENCE.md, the spine and epics.md. Expect hand merges on one-line rosters. Footprint extensions: `Kernel/Proposal/{Mint,Confirm,Prohibited}.cls` (one hook and appended arms), `ui/src/app/shell/data-table.ts` and `navigation.ts`.

**Integration ACs:**

- **Consumes:** 9.7's `task-fields.ts`, `TaskRules`, `TaskPort`, `TaskForm` and `PROPERTYFAULTS`; 9.1-9.5's form-tabs, Save order and `FormDirty`; and `SslFormStore`'s edit mode.
- **Consumed-by:** nothing later in Epic 9. The tool is the agent's.

## Verification

Slot A. Every IRIS MCP call carries `server: "ocupilot-slot-a"`. Anything that creates or changes a task or a user runs on `ocupilot-ci` only. Run one test class per call.

**Commands:**

- `(loop)` `cd ui && node --test tools/task-fields.test.mjs tools/navigation.test.mjs tools/strings.test.mjs tools/screen-mirror.test.mjs tools/field-lists.test.mjs tools/ci.test.mjs tools/form-tabs.test.mjs` -- expected: green.
- `(loop)` `cd ui && npm run test:components` -- expected: green, including `task-editor.*`, `task-wizard.*`, `task-field-group`, `details.page`, `data-table` and `screen-outlet`.
- `(loop)` `uv run scripts/test_check_objectscript.py && uv run scripts/check-objectscript.py && bash scripts/lint-docs.sh` -- expected: clean.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<X>`, one at a time -- expected: 0 failures. X is:
  - TaskUpdate, TaskEdit, TaskWire, TaskSave, TaskCreate, TaskRules;
  - ToolWrite, Prohibited, ProhibitedByEffect, SurfaceCoverage, EndpointCoverage, ToolRoundTrip;
  - Descriptor, DerivedFields, AdminInventory, Wire, WireSecurityRead, RefusalCopy, TaskLists, TaskDetails.
- `(loop)` `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`. Then run each spec file alone with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/<f>` -- expected: green. The files are task-editor, task-wizard, tasks and a11y-structural-invariants. Report the build's "Initial total".
- **The DW-1337 structural gate:** `task-editor.browser-spec.mjs`'s visual-gate test at 1440x900, on each of the four tabs. It checks that every input has an accessible name, that no control is narrower than its declared minimum (24x24), and that no element overflows its container. The walk visits editors at their bare route only, so this test is the edit route's gate.
- `(once, before dev_complete)` `node ui/tools/ci-runner.mjs --container ocupilot-ci --package OcuPilot.Test` -- expected: 0 new failures. The full browser suite is CI's.

**Mutations (Rule 19):**

- AC1: skip `tabToOpen` in the editor's `afterRefusal`.
- AC2: drop the port's `DailyStartTime` omission (the past-start Save then answers 409), and separately merge `Settings` wholesale.
- AC3: set INFO's `NextScheduled` on `TaskPort`'s GET answer.
- AC4: remove the `%SYS.Task.Password` arm of the classifier.
- AC5: make the privilege-by-effect arm ignore the live target.
- DW-1624: drop `OutputFileIsBinary` from `valuesFromTask`.
- Integration: skip the `updated` publish.

**Mutations observed (implement pass; each reverted and the file byte-identical by sha1; ObjectScript recompiled with its descendants on `ocupilot-ci`; client rebuilt and redeployed before a browser result counted):**

- mutation (AC1): skip `tabToOpen` in `TaskEditorPage.afterRefusal` -> `task-editor.page.spec.ts` "AC1: a refused Save opens..." went red, and `task-editor.browser-spec.mjs` "AC1: a refused Save..." went red.
- mutation (AC2, port): disable `TaskPort.Trimmed`'s time omission -> `OcuPilot.Test.TaskEdit.TestAStartAlreadyPastIsSentBackAsHeld` (the vendor's 409) and `TestThePortOmitsWhatTheVendorKeeps` went red (run 10420).
- mutation (AC2, settings): merge a supplied `Settings` wholesale in `TaskUpdate.MergeSettings` -> `TaskEdit.TestATwoFieldSaveKeepsEveryOtherField` went red (run 10422); send an unchanged `Settings` as `{}` from `TaskPort.Trimmed` -> `OcuPilot.Test.TaskUpdate.TestAConfirmedTwoFieldEditKeepsEveryOtherField` went red (run 10435).
- mutation (AC3): set `INFO`'s `NextScheduled` on `TaskPort`'s `GET` answer -> `TaskUpdate.TestAConfirmAfterTheTaskRanWrites` went red (run 10424).
- mutation (AC4, refused leg): drop the `%SYS.Task.Password` arm of `TaskPort.ClassicOnlySettings` -> `TaskUpdate.TestASecretSettingIsNeverReadAndAChangeIsRefused` went red (run 10425).
- mutation (AC4, unchanged-Settings-survives leg): make `TaskPort.WithholdSettings` set `Settings` to `{}` instead of removing it -> `TaskUpdate.TestAnEditLeavingTheSettingsKeepsTheSecret` went red on "the stored secret survives it" (run 10426).
- mutation (AC5): make the task arm of `Prohibited.GrantsPrivilegeByEffect` ignore the live target -> `TaskUpdate.TestRunningAsAnotherAccountIsJudgedOnAChange` went red (run 10427); disable `TaskRules.ValidateUpdate`'s `Judged` filter -> `OcuPilot.Test.TaskWire.TestTheLeastPrincipalEditsButCannotMoveRunAs` went red (run 10429).
- mutation (DW-1624): force `OutputFileIsBinary` false in `valuesFromTask` -> `tools/task-fields.test.mjs` and `task-editor.page.spec.ts` "DW-1624" went red.
- mutation (Integration): skip the `updated` publish in `TaskWizard.save` -> `task-wizard.store.spec.ts` "Integration, AD-14" went red; the browser rename leg stayed green, since both screens read again on return, and its comment says so.
- mutation: drop the edit route's `Gate` call -> `TaskWire.TestTheEditRoutesRefuseACallerLackingAPair` went red (run 10431); drop `NameTaken`'s own-id exclusion -> `TaskEdit.TestARenameToATakenNameIsRefused` went red (run 10433); set a supplied `Settings` wholesale in `TaskUpdate.MergeUpdate` -> `TaskUpdate.TestTheMintAnswersOneRowPerChange` went red (run 10434).
- mutation (review pass, DW-1631 create side): make `TaskPort.ClassicOnlyKind`'s `%SYS.Task.Password` arm `If 0` -> `OcuPilot.Test.TaskRules.TestASecretTypedSettingIsClassicOnly` went red (run 10443), and `TaskEdit.TestTheFormReadAnswersOneTask`'s secret leg (run 10444).
- mutation (review pass, output file): replace `'..IsManagerDirectory(tDirectory)` with `1` in `TaskRules.ValidateUpdate` -> `TaskEdit.TestTheEditsOwnRefusals`'s manager-directory leg went red (run 10444).
- mutation (review pass, account case): make `TaskRules.SameValue`'s `RunAsUser` line `If 0` -> `TaskRules.TestAnEditComparesTheAccountWithoutCase` went red (run 10443).
- mutation (review pass, time spelling): make `TaskUpdate.MergeUpdate`'s time loop run zero times -> `TaskUpdate.TestTheMintAnswersOneRowPerChange` went red on a phantom `DailyStartTime` row (run 10445).
- mutation (entry points): put TaskForm back in `CREATE_ONLY_FORMS` -> `tools/navigation.test.mjs` and `details.page.spec.ts` Edit legs went red; drop the detail-first term in `data-table.ts` -> `data-table.spec.ts` "Story 9.8" went red; drop TaskForm from `DESCRIPTOR_EDIT_PAGES` -> `screen-outlet.spec.ts` "Story 9.8" went red.
- mutation (QA, AC4/Matrix "Secret-bearing type", the Save-side wire route): the existing AC4 legs (`TaskUpdate.TestASecretSettingIsNeverReadAndAChangeIsRefused`, `TestAnEditLeavingTheSettingsKeepsTheSecret`) pin the rule and `TaskSave.Update` by direct class-method call only; no test sent a `Settings` change on a secret-bearing type through the actual `PUT /tasks/:id` route (Gate, body read, id decode, JSON envelope). Added `TaskEdit.TestASecretBearingTypesSettingsChangeIsRefusedBySaveOverTheWire` (QA). Mutation: in `TaskRules.WithheldSettingsCode`, make the `secret` arm of the kind loop `If 0` -> the code answered over the wire drops to `TASK.SETTING.CLASSICONLY` and the new test went red (run 10692); reverted, `TaskRules.cls` byte-identical by sha1 (`3ff66172c580f8d1dd4a96ab83d1fae54dfce8a8`), re-run green (run 10693).
- mutation (code review, AC4 agent caller): make `TaskUpdate.MergeSettings`'s withheld branch `If 0` -> `TaskUpdate.TestASecretSettingIsNeverReadAndAChangeIsRefused` went red on "a settings change refuses the mint" and "by name" (run 10701).
- mutation (code review, unchanged count): count every payload key in `TaskUpdate.MergeUpdate` instead of `TaskPort.Trimmed`'s -> `TaskUpdate.TestTheMintAnswersOneRowPerChange` went red on the count (run 10701, together with the line above; each red in its own test). Reverted byte-identical by sha1 (`39eec11d`), green run 10702.
- mutation (code review, type privilege): delete the `Permitted` line of `TaskRules.ValidateUpdate` -> `TaskWire.TestTheLeastPrincipalCannotEditATypeItsPrivilegeGuards` went red (run 10698); reverted by sha1 (`d9694918`), green run 10699.
- mutation (code review, unreadable type): drop `'$Get(tRead)` from `TaskPort.WithholdSettings` -> `TaskRules.TestAnUnclassifiableTypeIsWithheld` went red (run 10695); reverted by sha1 (`36d4be6b`), green run 10696. After the patches: TaskEdit 8/8 (10703), TaskSave 8/8, TaskCreate 7/7, TaskDetails 6/6, TaskResume 14/14 (10704-10707); `check-objectscript` clean.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** Edit task: `tasks.schedule.update` (`Screen/Tool/TaskUpdate.cls`) with the `Write.MergeUpdate` hook called by Mint, Confirm's fingerprint re-merge and the screen Save; `TaskPort`'s one classic-only classifier (password-typed, credential-named, collection), GET/PUT/POST answers withholding such a type's `Settings`, and the PUT trim (AD-4's named exception); `TaskRules` update mode, `PUT /tasks/:id` (`TaskSave.HandleUpdate`), `GET /tasks/form?id=`, `TASK.ABSENT` and `TASK.OUTPUTFILENAME.CLASSICONLY`; the prohibited set's task change list and live-target run-as arm. Client: the wizard's step templates moved into `task-field-group.ts`, rendered by the stepper and by the new tabbed `task-editor.page.ts`; the store's edit mode; `CREATE_ONLY_FORMS` emptied; detail-first name cells.

**Files.** Server: `Port/{AdminPort,TaskPort}`, `Screen/Tool/{Write,TaskUpdate,Classification,ToolFields}`, `Kernel/Proposal/{Mint,Confirm,Prohibited}`, `Area/Task/{TaskRules,TaskSave}`, `Api/{Router,Error}`, `Screen/Descriptor/{TaskForm,TaskScheduleList}`. Tests: new `Test/{TaskUpdate,TaskEdit,TaskEditProbe}`; `Test/{TaskWire,TaskRules,TaskResume,ToolWrite,PortFixture,SurfaceCoverage,EndpointCoverage,ToolRoundTrip,ReadTool,Wire,WireSecurityRead}`. Client: `areas/tasks/{task-fields,task-field-group,task-editor.page,task-wizard.page,task-wizard.store}.ts` and specs, `core/{navigation,strings,screens.generated}.ts`, `shell/{data-table,screen-outlet}.ts` and specs, `_components.scss`, `browser/{task-editor,tasks}.browser-spec.mjs`, `tools/{task-fields,navigation}.test.mjs`. Docs: EXPERIENCE.md (two Fixed-strings rows), `scripts/ci-throwaway.sh` (`# classes: TaskUpdate, TaskEdit`).

**Review.** Two layers (verification-gap, intent-alignment), 20 findings: 8 entries patched (6 medium members, 7 low members across them), 0 deferred from the layers, 7 false and 3 low rejected with reasons in the triage log. Patched: test legs for the manager-directory output file, the other time spelling, DW-1631's create side, edit-mode setting refusals, the withheld-read `CLASSICONLY` code, a bounded wait for the task to finish before AC3's confirm, read-back existence asserts; one code fix (`TaskRules.SameValue` compares `RunAsUser` without case). The review's R1 probe measured that the vendor refuses a period change on a past-started task (7432), so the start rule keeps reading the period; a test leg pins it. The full sweep then tripped `TaskResume`'s empty-task-list tripwire; it now asserts the edit's thirty-two with `Type` absent.

**Verification.**

- Sweep (once, `ocupilot-ci`, `ci-runner --package OcuPilot.Test`, one class per call): 242 classes, 2117 tests, 2 failed (runs 10446-10687): `TaskResume.TestAChangedFieldOnATaskProposalIsRefused` (the tripwire above; fixed, re-run 10688 green, 14/14) and `WireSecurityRead.TestTaskHistoryPairSetsAreEnforcedForARealPrincipal` (the known ~2,000-row history residue, DW-1425/DW-1468). `%UnitTest_Result` SQL probe agrees; its other failing rows are `TmpProcessControlLocal`/`TmpTaskResume76`, stale classes on the instance that are not in this tree.
- Story classes after patches: TaskRules 11/11 (10438), TaskEdit 7/7 (10440), TaskUpdate 7/7 (10441), TaskWire 5/5 (10442).
- Browser (bundle rebuilt and redeployed, each file alone): task-editor 6/6 (visual gate on all four tabs) and task-wizard 5/5 after the review patches; the implement pass had task-editor 6/6, task-wizard 5/5, a11y-structural-invariants 10/10, tasks 13/15 (the two Story 6.6 residue legs).
- Client: targeted tools 213/213; components 1189/1189; `check-objectscript`, its harness and `lint-docs` clean.
- Bundle initial total: 1,537,954 B (main 1,396,777 + styles 141,177), under the 1551kB warning and the 1580kB stop line; `maximumWarning` unchanged.

**Follow-up review recommended:** true -- four medium entries were patched. Unverified risk: a vendor 409 on `Task.CRUD` PUT that the rules do not pre-empt surfaces `PORT.CONFLICT`, whose sentence speaks of a duplicate name.

**Residual risks.** `unchangedCount` counts the port-added `Type`, which the PUT never sends (off by one on the card). The browser Integration leg stays green without the `updated` publish (both screens re-read on return); the publish is pinned by `task-wizard.store.spec.ts`. A caller who cannot read the task's namespace gets no types, so no settings are drawn (inference). `strings.ts`'s `taskCreate` reference moved `EXPERIENCE.md:541` to `:543`; Epic 12's appended rows will shift it again at merge.

footprint_extensions: src/OcuPilot/Test/ReadTool.cls, src/OcuPilot/Test/TaskEditProbe.cls, src/OcuPilot/Test/TaskResume.cls, src/OcuPilot/Test/TaskRules.cls, ui/src/app/core/screens.generated.ts, ui/src/app/shell/data-table.spec.ts, ui/src/app/shell/screen-outlet.spec.ts, ui/src/app/areas/tasks/task-field-group.spec.ts, ui/src/styles/_components.scss (append-only)
