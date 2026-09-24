---
title: 'Story 9.7: The New Task wizard'
type: 'feature'
created: '2026-09-24'
status: 'done'
baseline_revision: '0743a1a3675b232bc6e9103f38b9431c8dfa7047'
baseline_commit: 'f9851990568c3c30a459502deb960612d5625086'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-9-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-9-5-the-ssl-tls-editor.md'
warnings: ['oversized']
deferred:
  - summary: >-
      Each task-creating test leaves two vendor-written Task history rows per probe task (create and delete), which accumulate on a reused instance.
    evidence: |-
      ocupilot-ci's %SYS_Task.History holds 236 rows named OcuP97*, two per probe create (e.g. OCUP97MONTHLY 8 rows over 4 runs); the tests delete the tasks by id, not their history.
    location: >-
      src/OcuPilot/Test/TaskProbe.cls
    severity: low
  - summary: >-
      proposal-demo's AC1 leg reads the agent's closing reply with no wait, so it goes red when the reply lands one panel poll after the proposal card (CI run 36029831321).
    evidence: |-
      The selector appears once in the file (a bare page.$eval at :505) and nothing waits on it; locally the card and reply render together about 1.2 s after send, 3 full-file runs 3/3 plus 11 single-leg runs green.
      Timing on CI not observed (inference). The file is unchanged by this story and identical on origin/OCU-1-epic11.
    location: >-
      ui/browser/proposal-demo.browser-spec.mjs:505
    severity: medium (unverified)
---

<intent-contract>

## Intent

**Problem:** A scheduled task can be listed, run, suspended, resumed and deleted from OcuPilot, but it cannot be created. Creating the instance's housekeeping still means leaving for the classic Task Scheduler Wizard.

**Approach:** Add one create-only `form-page` at `tasks/schedule/edit`, reached from the Task schedule list's Create. It is a linear vertical stepper with four steps: Basics; Task type and settings; Schedule; Options and notifications. It saves through a new write tool, `tasks.schedule.create`. The screen's Save uses it under AD-55, and the agent's create uses it under AD-54. The field model is built once in `task-fields.ts` and `TaskRules`, so Story 9.8's edit tabs use it too.

## Boundaries & Constraints

**Always:**

- **Steps and fields.** Every value except `TaskClass` and `Settings` comes from `Task.CRUD`'s derived 35-key template. `TaskClass` and `Settings` are the task type and that type's own settings.
  - **Basics:** Name, Description, NameSpace.
  - **Task type and settings:** TaskClass, then one input per non-collection setting of the chosen type, loaded when the type changes.
  - **Schedule:**
    - TimePeriod (Daily, Weekly, Monthly, Monthly Special, Run After, On Demand), then TimePeriodEvery, TimePeriodDay and RunAfterGUID as that period reads them.
    - DailyFrequency (Once, Several). The quadruple DailyFrequencyTime (Minutes, Hourly), DailyIncrement, DailyStartTime and DailyEndTime; Once shows only DailyStartTime.
    - StartDate and EndDate.
    - Expires and ExpiresDays, ExpiresHours and ExpiresMinutes.
    - The frequency, date and expiry fields are drawn only for periods 0–3.
  - **Options and notifications:**
    - RunAsUser, Priority (Normal, Low, High), IsBatch, MirrorStatus (Primary, Non-Primary, Any).
    - OpenOutputFile, OutputFilename, OutputFileIsBinary, EmailOutput.
    - SuspendOnError, SuspendTerminated, RescheduleOnStart.
    - EmailOnCompletion, EmailOnError and EmailOnExpiration, each a comma-separated list of addresses.
- **Stepper behavior.**
  - Next sends the values so far to `POST /tasks/check` and advances only if the current step has no violation. Back keeps every value.
  - The last step's primary reads "Create task". Cancel returns to Task schedule.
  - A step in error shows a `destructive` marker, and its heading names the step's first refusal in text (`taskStepError`). Its accessible name gains ", N errors" through `tabAccessibleName`.
  - Create task sends everything. A refusal opens the step holding the first refused field, through `tabToOpen` over the field→step map, and focuses the error summary and then the field.
  - After a successful create, the page is replaced (`replaceUrl`) by the new task's details, `tasks/schedule/details/<id>`, and one `task` `created` change event is published with the numeric id.
- **Rules.** `TaskRules.Validate(mode, args, .violations)` holds every rule, for both callers and for the check route. Each refusal is `{field, code, reason}` (AD-39). A field that does not apply to the chosen period is ignored and sent as the vendor default.
  - **Name:**
    - required, 1–50 characters, first character a letter (`%SYS.TaskSuper` doc);
    - not already the name of a task, compared case-insensitively (`TASK.NAME.TAKEN`, see Design Notes).
  - **Description:** at most 100 characters. It is refused rather than silently truncated.
  - **NameSpace:** one of the caller's readable namespaces, the list the shell's `/namespaces` answers.
  - **TaskClass:**
    - a non-abstract subclass of `%SYS.Task.Definition` compiled in NameSpace;
    - each setting key must be one of that type's settings;
    - each setting value must pass the type's own `<setting>IsValid`, called in NameSpace as the vendor's task utility does (`TASKMGR.int` :97-112), and a `Required` setting must be non-empty. A refusal lands on `Settings.<key>`.
    - A setting whose name matches the credential pattern is refused (`TASK.SETTING.SECRET`), and the form draws it as classic-only. The measured `HSCUSTOM` population has none.
  - **TimePeriod** fixes how TimePeriodEvery and TimePeriodDay are read (TaskSuper doc; ranges from `TASKMGR.int` :131-197):

    | Period | TimePeriodEvery | TimePeriodDay | Also |
    | --- | --- | --- | --- |
    | Daily | 1–7 days | `""` | |
    | Weekly | 1–5 weeks | a set of digits 1–7 (Sunday = 1), at least one | |
    | Monthly | 1–12 months | 1–31 (31 = last day) | |
    | Monthly Special | 1–12 | `week^day` (week 1–5, 5 = last; day 1–7) | |
    | Run After | `""` | `0` | RunAfterGUID must be an existing task's JobGUID |
    | On Demand | `""` | `""` | |

  - **DailyFrequency:**
    - Once needs DailyStartTime `HH:MM`.
    - Several needs DailyFrequencyTime, DailyIncrement (1–1440 for Minutes, 1–24 for Hourly), DailyStartTime, and a DailyEndTime later than DailyStartTime.
  - **Dates:** StartDate is required for periods 0–3 and is `YYYY-MM-DD`. StartDate plus DailyStartTime must be later than now (instance clock); the form defaults to tomorrow. EndDate, if present, is later than StartDate.
  - **Expires:** each offset is a whole number (days 0–999, hours 0–24, minutes 0–60), blank meaning 0. Expires and the offsets apply to periods 0–3 only. See Design Notes for the measured facts.
  - **RunAsUser:**
    - Blank means the caller.
    - It must name an existing, enabled user (vendor 7406 and 7402).
    - A name other than `$Username` needs `%Admin_Secure:USE`. Without it the rules refuse on the field (`TASK.RUNASUSER.SECURE`) before any port call.
  - **Emails** must match `^[^@\s,]+@[^@\s,]+$`. OutputFilename follows the AD-21 ruling below.
- **Tool `tasks.schedule.create`** (`Screen/Tool/TaskCreate.cls`):
  - Declarations: `CREATES 1`, `WRITETYPE POST`, `PORTCLASS` TaskPort, `DESCRIPTORCLASS` TaskScheduleList, `CHANGEACTION created`, and the list's pairs.
  - Its absence read is the list type filtered to the one row whose `Name` equals the argument: `READTYPE LIST`, `READIDPARAM filter`, `READROWKEY Name`, as `AuditEventReset` does.
  - Compose sends the **complete** 34-key body, because the vendor's POST requires every key except `Settings` (measured 400 #40301). Supplied fields become diff rows, with each setting a `Settings.<key>` row. Every other key takes the vendor's initial value from the form read's `defaults` and is counted as unchanged, as FR-17's collapse shows it.
  - `ArgumentProblem` calls `TaskRules.Validate("create")`.
- **Port.** In `AdminPort`:
  - Add `Task.CRUD/POST` to `MUTATINGTYPES`.
  - Map vendor codes to field violations in `PROPERTYFAULTS`; the vendor text is never carried:

    | Field | Vendor codes |
    | --- | --- |
    | RunAsUser | 7402, 7405, 7406 |
    | DailyIncrement | 7404 |
    | DailyEndTime | 7408 |
    | EndDate | 7409 |
    | TimePeriodDay | 7410, 7426, 7428 |
    | OutputFilename | 7411, 7412 |
    | TaskClass | 7413, 7414, 7433, 7434 |
    | TimePeriodEvery | 7427, 7429 |
    | DailyFrequencyTime | 7430 |
    | RunAfterGUID | 7431 |
    | StartDate | 7432 |

  - Keep a 201's `Location` for the caller.

  `TaskPort` sets `Id` (an integer) on a `Task.CRUD/POST` answer from that `Location`'s `id=`. The vendor body carries no id; it is only in `Location: /api/admin/v1/task?id=<n>` (measured).
- **Screen Save.** `Area/Task/TaskSave.cls` `HandleCreate` follows `SslSave.Create`'s order:
  1. pairs;
  2. name shape;
  3. absence read (a taken name answers 422 on Name);
  4. undeclared keys (400 `PORT.FIELD.UNEXPECTED`);
  5. rules;
  6. the tool's compose;
  7. the prohibited set;
  8. send;
  9. port violations.

  It answers 201 `{id, name}`. `Area/Task/TaskRules.cls` also serves `HandleForm` and `HandleCheck`.
- **Routes** are appended to `Api/Router.cls`'s tail as a new `/tasks` prefix family, in this order:
  - `GET /tasks/form?namespace=` answers `{requiredFields, maxLengths, rules, defaults, namespace, types, runAfter}`:
    - `types` is `[{class, name, settings:[{name, label, kind, required, default}]}]`, with collections excluded;
    - `runAfter` is `[{guid, id, name}]`;
    - `defaults` are a `%SYS.Task` `%New()`'s own values with StartDate tomorrow.
  - `POST /tasks/check` answers `{violations}`, 200 always unless the caller is refused.
  - `POST /tasks`.
- **Prohibited set** (`Kernel/Proposal/Prohibited.cls`, appended arms only):
  - `PermittedCreateFields` gains a `TYPETASK` arm listing every settable field.
  - `GrantsPrivilegeByEffect` gains a `TYPETASK` arm: true when the payload's RunAsUser is non-blank and names an account other than `$Username`, ignoring case. The agent's proposal is then minted destructive, with the consequence `TASK.RUNSASOTHER` naming the user (the DW-1207 pattern).
  - The page shows `taskRunAsOtherEffect` under RunAsUser before Save.
- **Agent's created event (AD-14).** Confirm's answer carries `createdId` when the tool's `CreatedId(written)` (new on `Write.cls`, default `""`) answers one. `core/turn.ts` publishes that id in place of the target's. The write stays keyed by `task:instance:<Name>` (AD-13).
- **Descriptors:**
  - `Screen/Descriptor/TaskForm.cls` (new): `tasks/schedule/edit`, `form-page`, `sideBarPosition` 0, the list's pairs, `entityType task`, `classicPage` `%cspapp.op.utilsystaskbuilder` (the class the classic `UtilSysTaskBuilder.csp` compiles to; confirm with `%SYS.Portal.Resources.NormalizePage`, AD-44), three `suggestedPrompts`, `toolIdentifier tasks.scheduleform`.
  - `TaskScheduleList` gains `primaryAction {"id":"create"}`. Regenerate `screens.generated.ts`.
  - The form is added to `CREATE_ONLY_FORMS` until 9.8, so the row name cell keeps opening details.
- **Copy and style.**
  - Every new word is a `strings.ts` key plus a Fixed-strings row, appended with `[ADDED 2026-09-24 - see the story change log]`. `taskCreate` "Create task" references EXPERIENCE.md :533.
  - Use tokens only and `\uXXXX` escapes, name every input, and allow no overflow. There is no DW-1337 allowance.
  - The stepper is OcuPilot's own `shell/form-stepper.ts` (`FormStepper`, `FormStepBody`), the vertical twin of `FormTabs` over `core/form-tabs.ts`. No `@angular/material/stepper`, `@angular/cdk/stepper` or `@angular/forms`.
- **Probes and tests** create only tasks named `OcuP97*` on `ocupilot-ci`, delete them by id after checking the exact name, and never touch a vendor task. Every task-creating test class is armed on `OCUPILOT_ALLOW_TASK_CONTROL` and added to that block's `# classes:` line.

**Never:**

- An edit or update tool, or a PUT route. Those are Story 9.8.
- A caller-supplied OutputDirectory, or any path beyond the AD-21 ruling.
- A secret-valued setting, or a collection setting (classic-only).
- A `@angular/material/stepper` import. Raising the bundle budget, or lazy loading, without the owner's answer (Design Notes).
- Anything but appends in `Api/Error.cls`, `Api/Router.cls`, `screen-outlet.ts`, `strings.ts`, `_components.scss`, Fixed strings, `Classification.cls` and `Prohibited.cls`. No write to Epic 12's or 11.10's files.
- A full browser-suite run locally. A private key in any file.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Create weekly | Name `OcuP97W`, type `%SYS.Task.PurgeTaskHistory` KeepDays 30, Weekly every 1 on Mon+Wed (`"24"`), Several every 30 Minutes 01:00–05:00, StartDate tomorrow | 201 `{id}`; the page is `tasks/schedule/details/<id>` showing the task; the schedule list shows it; `docker exec` reads the stored schedule back | — |
| Next on empty Basics | Next with Name blank | Stays on Basics; its heading names the refusal in text | `TASK.NAME.REQUIRED` on Name |
| Back keeps values | Fill Basics and type, Next, Back | Every value is still there | — |
| Type loads settings | Choose `%SYS.Task.IntegrityCheck`, then `PurgeTaskHistory` | Its settings appear, with their defaults; the previous type's settings are gone | — |
| Name taken | Name `Purge Tasks` (vendor task, any case) | Nothing is sent | 422 `TASK.NAME.TAKEN` on Name |
| Several without increment | Several, DailyIncrement blank | Nothing is sent | `TASK.DAILYINCREMENT.REQUIRED` |
| Past start | StartDate today, 00:00 | Nothing is sent | `TASK.STARTDATE.PAST` |
| Bad setting | PurgeTaskHistory KeepDays `0` (MINVAL 1) | Nothing is sent | a violation on `Settings.KeepDays` |
| Run as other | A `%Admin_Task`-only principal sets RunAsUser `_SYSTEM` | Nothing is sent | `TASK.RUNASUSER.SECURE` on RunAsUser |
| Run as other, allowed | Holder of `%Admin_Secure:USE`; agent create with RunAsUser `_SYSTEM` | The proposal is destructive and names the user; confirm creates it | — |
| Agent create | Agent `tasks.schedule.create` On Demand | The proposal's target is `task:instance:<Name>`; confirm answers `createdId`; the event carries the id | A name taken since mint refuses the confirm |
| On Demand expiry | On Demand with Expires true | The instance stores Expires 0; the form draws no expiry for On Demand | — |

</intent-contract>

## Code Map

S = `src/OcuPilot/`, U = `ui/src/app/`. Anchors are at HEAD `0531828660a625c45e2eab879561e0ffb000d505`.

**Vendor (measured on `ocupilot-ci` 2026-09-24 over `/api/admin/v2/task`, which is the same endpoint class; probe tasks and principals removed):**

- `%Api.Admin.Endpoints.Task.CRUD` (Hidden; read with `GetTextAsString` on slot A):
  - `PutAndPostSchema` L108-147 (35 keys).
  - `ValidateRequest` L510-537: every key is required on POST except `Settings`.
  - `RunPost` L324-336: `%New` → `MergeJsonAndObj` → `%Save`, then 201 with `Location` only.
  - `MergeJsonAndObj` L57-106 converts DISPLAYLIST strings and `YYYY-MM-DD` dates, and applies `Settings` through `SetSettings` without checking the result.
  - `ResourcesOR` L149-155: POST accepts `%Admin_Task` or `%Admin_Operate`.
- **Measured behavior:**
  - Create allocates a new id each time: 1385, then 1386 for the same name. It is not an upsert, and **duplicate names are accepted**.
  - A blank RunAsUser is stored as the caller.
  - A principal with only `%Admin_Task:U` and `%DB_IRISSYS:R` creates a task, so no extra write pair is needed.
  - A save-time refusal answers 500 carrying the vendor code (7432, 7404, 7426, 7205, 7207 were observed).
  - `%SYS.Task.RunLegacyTask`'s `ExecuteCode` needs `%Admin_Manage:USE` (7434).
- **RunAsUser:** `%Admin_Task:U` alone was refused 7405 for another user and for `_SYSTEM`. After `%Admin_Secure:U` was added, both saved with 201.
- **Expires:**
  - An On Demand task stores Expires 0 whatever is sent.
  - A Daily task keeps `Expires: true` and `ExpiresMinutes: 30`.
  - The save accepts -1, 1000, 25 and 61, stores 1.5 as 1, and refuses `abc` (7207).
  - `%SYS.TaskSuper.Expired()` answered 1 for every in-memory variation tried, so the runtime expiry was not measurable in process.
  - The vendor's own task utility asks "Task Expires", then "Expires in how many days / hours / mins", with bounds 0–999, 0–24 and 0–60, and stores 0 as `""`. It asks only for periods 0–3 (`irissys/TASKMGR.int` :225-235).
- **Properties:** `%SYS.TaskSuper` is Deployed. Its properties are listed from `%Dictionary.CompiledProperty` on slot A:
  - 66 compiled properties;
  - 49 documented, of which 47 are on TaskSuper and 2 are `%%OID` and `%Concurrency`;
  - undocumented: ExpiresDays, ExpiresHours, ExpiresMinutes, SkipAuditOnReschedule and the 13 `Display*` properties.
- **Task types:** there is no admin route that lists them. `HSCUSTOM` holds 48 subclasses of `%SYS.Task.Definition` with 88 settings, none credential-named. `irissys/%SYS/Task/Definition.cls` has `GetTaskName` :137, `GetSettings` :47, `SetSettings` :73 (drops errors) and `CheckPermission` :217.
- **Classic pages:**
  - New Task is `/csp/sys/op/UtilSysTaskBuilder.csp` (`%cspapp.op.utilsystaskbuilder`; tile at `irissys/%CSP/UI/Portal/Application.cls` :445).
  - Edit is `UtilSysTaskOption.csp`.

**Server:**

- `S/Port/AdminPort.cls`:
  - `MUTATINGTYPES` :262. Epic 12 appends `Security.OAuth2.Server/REVOKE` to the same line, so expect a textual merge.
  - `BODYLESSTYPES` :278, `CONSTANTBODIES` :433, `PROPERTYFAULTS` :2222.
  - `Invoke` reads `Location` only for a 202 (:774-779) and returns the body (:798).
  - `HttpMethodFor` :1866, `EndpointType` :1878.
- `S/Port/TaskPort.cls` :41-60 is the GET completion. Add the POST id.
- `S/Screen/Tool/`:
  - `SslCreate.cls` is the create template (`PrivilegePairs` :143).
  - `AuditEventReset.cls` :49-51 is the `READTYPE LIST`/`READROWKEY` template.
  - `TaskDelete.cls` :19-64 has the task tool shape (`IdArgument` `Id`).
  - `Write.cls`: parameters :30-201, `DerivedFields` :291, `IdArgument` :453.
  - `Classification.cls`: append after the SSL entries (:330-356). `Settings` is `opaque`, added back by the tool as a string-valued object (the `AllowedHosts` precedent, doc :87-91). OutputDirectory is left out of the positive list (AD-21).
  - Then run `cd ui && node tools/field-lists.mjs`. `FieldLists.cls` :426-465 already holds `Task.CRUD`.
- `S/Kernel/Proposal/`:
  - `Mint.cls`: create path :140-186. `Compose` :532 refuses an object argument, so give tools a `ComposeCreate` hook with the kernel's `Compose` as the default. `GrantsPrivilegeByEffect` call :306, consequences :64 and :658.
  - `Confirm.cls` :381 (`ApplyAt`) is where the answer gains `createdId`.
  - `Operation.cls` :252-282 (`ReadTarget` row key) and :383-400.
  - `Prohibited.cls`: `TYPETASK` :269, `Task()` :1311, `PermittedCreateFields` :579, `Created` :815-850, `GrantsPrivilegeByEffect` :1780.
- `S/Kernel/EntityRef.cls` :59 `task:integer`. A letter-first name never folds onto an id.
- `S/Area/Security/SslSave.cls` (`Create` :121-170, `Gate` :341, `Answer` :297) and `SslRules.cls` (`HandleForm` :275) are the templates for the new `S/Area/Task/` classes.
- `S/Api/Router.cls`: append after :153, handlers before :1036.
- `S/Screen/Descriptor/`:
  - `TaskScheduleList.cls` `primaryAction` :90.
  - `SslForm.cls` is the form descriptor template.
  - `Registry` checks suggested prompts at :571.
- `scripts/ci-throwaway.sh` :265-270 (`# classes: TaskResume`). `ui/tools/ci.test.mjs` :1769.

**Rosters a new tool, route or screen trips:**

- `Test/SurfaceCoverage.cls`: screen rows :90-96, tool rows :142/:147.
- `Test/EndpointCoverage.cls` :156-160 (probe count).
- `Test/Prohibited.cls` :376 (`PermittedCreateFields` sweep).
- `Test/ProhibitedByEffect.cls`.
- `Test/Descriptor.cls` :102/:537 and `Test/TaskLists.cls` (the list's primary action).
- `Test/AdminInventory.cls` :104 and `Test/PortFixture.cls` :21 (`MUTATINGTYPES` mirror).
- `Test/DerivedFields.cls`.
- `Test/ToolRoundTrip.cls` :35.
- `Test/ReadTool.cls` :93 is unchanged, because the form adds no read tool; confirm it stays green.

**Client:**

- `U/core/form-tabs.ts`: `tabErrorCounts` :30, `tabToOpen` :45, `tabAccessibleName` :60.
- `U/shell/form-tabs.ts` :27-120 is the pattern for `form-stepper.ts`.
- `U/areas/security/ssl-form.store.ts` / `.page.ts` are the store and page template: `open` :438, `save` :538, `absorb` :714, summary :134-146, form bar :561-573, `afterRefusal` :1065.
- `U/areas/permissions/user-create-form.page.ts` is the create-only analogue (`replaceUrl` :489).
- `ssl-actions.ts` is the Create registration template. It is injected at `U/app.ts` :265; `TaskActions` goes beside it. No store is injected.
- `U/shell/screen-outlet.ts` `DESCRIPTOR_PAGES` :99-116 (append) and `U/core/navigation.ts` `CREATE_ONLY_FORMS` :201 (entry plus doc).
- `U/areas/tasks/details.store.ts` `scheduleWords` :147 can serve the Schedule step's summary line.
- `U/core/turn.ts` :1086 (the `createdId` publish).
- `U/core/strings.ts` `} as const;` :1947. `ui/tools/strings.test.mjs` :686 requires unique values and :736-790 checks the references.
- EXPERIENCE.md :108 (screen row), :533 (stepper), :777 (the a11y rule).
- Browser: `tasks.browser-spec.mjs`, `task-schedule-actions.browser-spec.mjs`, `task-resume`, `task-run`, `a11y-structural-invariants`. `structural-walk.mjs` walks `TaskForm` at its bare route.

## Tasks & Acceptance

**Execution:**

Server:

- `S/Port/AdminPort.cls` and `S/Port/TaskPort.cls` -- add `Task.CRUD/POST`, the task `PROPERTYFAULTS`, and the 201 `Location` pass-through with the `Id` set -- so the create is reachable and the created id reaches both callers.
- `S/Screen/Tool/TaskCreate.cls` (new) -- the tool as in Boundaries. Its `ComposeCreate` builds the complete body, `CreatedId` answers `Id`, the `Described` semantic half is authored from `%SYS.TaskSuper`'s docs (AD-3), and the RunAsUser consequence is included -- so there is one tool for both callers.
- `S/Screen/Tool/Write.cls` -- add default `ComposeCreate` and `CreatedId` -- so these are hooks with no behavior change for existing tools.
- `S/Kernel/Proposal/Mint.cls` and `Confirm.cls` -- call the tool's `ComposeCreate`; add `createdId` to the answer -- AD-54 composition and AD-14's id.
- `S/Kernel/Proposal/Prohibited.cls` -- the `TYPETASK` create list and the RunAsUser effect arm -- AD-10 and DW-1207.
- `S/Screen/Tool/Classification.cls` -- the task entry. Then regenerate `ToolFields.cls`.
- `S/Area/Task/TaskRules.cls`, `TaskSave.cls` (new) -- the rules, form read, check and Save -- one rule set for three callers.
- `S/Api/Router.cls`, `S/Api/Error.cls` -- the `/tasks` routes and wrappers; the `TASK.*` codes and reasons -- AD-12 and AD-39.
- `S/Screen/Descriptor/TaskForm.cls` (new) and `TaskScheduleList.cls` -- the form descriptor and the list's `create` primary action.
- `scripts/ci-throwaway.sh` -- add the new task test classes to `# classes:`.

Server tests (armed on `OCUPILOT_ALLOW_TASK_CONTROL`; `OcuP97*` names only):

- `Test/TaskRules.cls` (new) -- one leg per TimePeriod 0–5 (Every/Day accepted and refused), the DailyFrequency quadruple, dates and past start, names and taken names, settings through `IsValid`, the Expires facts, and RunAsUser.
- `Test/TaskSave.cls` (new) -- the form-read shape (types and settings, defaults, runAfter), the check route, create 201 `{id}` with the whole stored task read back, the Matrix refusals, and the vendor-code mappings.
- `Test/TaskCreate.cls` (new) -- the schema and descriptions, the absence fingerprint by name, a name taken since mint refused at confirm, the complete body, `createdId`, and RunAsUser-other minted destructive with `%Admin_Secure` enforced for a least-privileged principal.
- `Test/TaskWire.cls` (new) -- every route refuses a principal missing a pair, and answers one envelope.
- The rosters in the Code Map, with names read from the instance.

Client:

- `U/areas/tasks/task-fields.ts` (new, framework-free) plus `tools/task-fields.test.mjs` -- the field order, the field→step map, kinds, per-period applicability and the complete-body builder -- the model 9.8 reuses.
- `U/shell/form-stepper.ts` (new) plus spec -- the vertical linear stepper: `ol`, `aria-current="step"`, error marker and text, and named step buttons ≥ 24x24.
- `U/areas/tasks/task-wizard.store.ts`, `task-wizard.page.ts`, `task-actions.ts` (new) plus specs -- the load, per-namespace types, Next check, Back, create, refusal routing, the dirty guard (`FormDirty`), the RunAsUser consequence line, and navigation to details.
- `U/shell/screen-outlet.ts`, `U/core/navigation.ts`, `U/app.ts`, `U/core/turn.ts` -- the map entry, `CREATE_ONLY_FORMS`, `TaskActions`, `createdId`.
- `U/core/strings.ts` plus EXPERIENCE.md Fixed strings -- step labels, "Next", `taskCreate`, `taskStepError`, field labels, the three prompts, `taskRunAsOtherEffect`, `taskSettingClassicOnly`, and `taskListEmptyAgent` if the list's empty state needs it.
- `ui/browser/task-wizard.browser-spec.mjs` (new) -- the Matrix's Create, Next-on-empty, Back, type-loads-settings and Name-taken rows; the details page and the schedule list after the create; the visual gate at 1440x900; probe tasks deleted by exact name.
- `tasks.browser-spec.mjs` -- the schedule list's Create is drawn and opens the wizard.

**Orchestrator rulings 2026-09-24 (binding; spine AD-21 amended):**

- AD-21 third named exception applied as planned: the output file is one name matching `^[A-Za-z0-9][A-Za-z0-9._-]{0,99}\.txt$` (a literal `..` refused), written under the manager directory computed at call time, sent as `OutputDirectory` and `OutputFilename`. Pin the refusal with a test that reddens when the pattern check is removed. Task-type settings are that type's own vendor-validated values (`<setting>IsValid`); the location-type settings are permitted as values, and **the proposal card names the location** so the user sees where the task will read or write (a test pins the named location on the card). AC7 stays whole.
- Bundle: build the wizard EAGER. Do NOT build a `@defer`/lazy pattern (the lazy-load move is the owner's, and would arrive as its own unit). The lead re-bases the warning under DW-1166 if crossed; if a measured initial total crosses 1580kB, HALT `intent gap` and report the figure.

**Acceptance Criteria:**

- **AC1.** Given the wizard, when it renders, then it is a linear vertical stepper of the four named steps. Next validates the current step through the server's rules. Back keeps values. The type step loads the chosen type's settings. The last primary reads "Create task". A step with an error names it in text as well as by its marker.
- **AC2.** Given the tool's schema and the form read, when they are compared with `%SYS.TaskSuper`, then every settable field is a derived template key, and each carries the authored description and legal values of its TaskSuper property.
- **AC3.** Given each TimePeriod 0–5, when TimePeriodEvery and TimePeriodDay are validated, then they are read as that period's table row says, and a value outside it is refused on its field.
- **AC4.** Given DailyFrequency Several, when DailyFrequencyTime or DailyIncrement is missing, then the create is refused on that field and nothing is sent. Once sends only DailyStartTime.
- **AC5.** Given Expires and its offsets, when a task is created, then `Test/TaskRules` pins what the instance stores:
  - On Demand stores Expires 0;
  - a Daily task keeps its offsets;
  - a non-number is refused before the call.
- **AC6.** Given a principal without `%Admin_Secure:USE`, when it sets RunAsUser to another user, then both callers refuse on RunAsUser before any port call. For a holder, the agent's proposal is destructive and names the user. The instance's own enforcement is pinned by test.
- **AC7.** Given priority, output file, suspend-on-error, reschedule-after-restart and the four email settings in the wizard, when Create task succeeds, then the task appears in the schedule list and its details screen with those values, read back from the instance.
- **Integration.** `TaskWizardPage` consumes `core/form-tabs.ts` through `FormStepper`, the `/tasks` routes and `ChangeBus`. A refused Create on step 1 opens it with its marker, and the created task's details open. The browser spec observes both.

### Review Findings

Code review 2026-09-24. Four layers ran on `full-opus`: blind, edge-case, verification-gap and acceptance. They produced 45 rows, grouped into 1 high, 5 medium and 12 low entries. Another 24 rows were rejected.

- [x] [Review][Patch] **HIGH, AD-13/AD-54.** Two spellings of a task name built two proposal targets. The rule was `task:integer`, which answered a letter-first name verbatim, so AD-34's lock did not cover `Nightly` against `NIGHTLY`. Fix-risk med: kernel identity, in two languages. Now the `integer` rule folds any non-integer to lower case. [src/OcuPilot/Kernel/EntityRef.cls:268, ui/src/app/core/entity-ref.ts:84]
- [x] [Review][Patch] **MED, AD-3.** `TaskRules.FIELDS` and `Defaults()` keys were hand lists that no test pinned to the permitted set, so a field could be validated and then dropped from the body. Fix-risk low. Both are now asserted equal to `PermittedCreateFields("task")`. [src/OcuPilot/Test/TaskCreate.cls:94]
- [x] [Review][Patch] **MED.** A period change carried `TimePeriodDay` over with a new meaning: Weekly `24` became the 24th of the month. Fix-risk low. `dayFor` now starts the period's own value. [ui/src/app/areas/tasks/task-wizard.store.ts:103]
- [x] [Review][Defer] **MED, AC7.** The details screen draws the schedule and Priority, not the output file, suspend, reschedule or email values. All of them are read back from the instance. Fix-risk low. Routed as DW-1624 to 9-8-edit-task, whose edit tabs draw every field.
- [x] [Review][Defer] **MED.** Two concurrent Saves can create one name twice, because the vendor accepts duplicates. Closed as DW-1625, wontfix-theoretical. The agent path is covered by the HIGH fix.
- [x] [Review][Defer] **MED, AD-54.** The Rule's "unchanged count is zero" does not hold for this create, because the vendor needs the complete body. Closed as DW-1629, by-design: the code follows the spec. The lead amends AD-54 under Rule 20.
- [x] [Review][Patch] **LOW.** A supplied `Settings` was counted as unchanged. It is now named by its `Settings.<key>` rows, so the count is 30. [src/OcuPilot/Area/Task/TaskRules.cls:442]
- [x] [Review][Patch] **LOW.** The taken-name mint leg asserted only 400. It now asserts the "already present" refusal. [src/OcuPilot/Test/TaskCreate.cls:131]
- [x] [Review][Patch] **LOW.** `TaskWire`'s run-as-self read-back guard skipped silently. It now asserts the task reads back. [src/OcuPilot/Test/TaskWire.cls:138]
- [x] [Review][Patch] **LOW.** No page leg drove AC7's EmailOutput control. It is now clicked and asserted in the body. [ui/src/app/areas/tasks/task-wizard.page.spec.ts:290]
- [x] [Review][Patch] **LOW.** A select setting whose default no option names showed its first option while sending `""`. It now draws the held value, as `view` does. [ui/src/app/areas/tasks/task-wizard.page.ts:922]
- [x] [Review][Patch] **LOW.** The Monthly Special weekday select lacked `aria-invalid` and `aria-describedby`. [ui/src/app/areas/tasks/task-wizard.page.ts:336]
- [x] [Review][Patch] **LOW.** Confirm's answer doc omitted `createdId`, and a blank line was missing before `ToolCreatedId`. [src/OcuPilot/Kernel/Proposal/Confirm.cls:696]
- [x] [Review][Patch] **LOW.** Removed the unused `.ocu-form-step-nav` rule. [ui/src/styles/_components.scss:5722]
- [x] [Review][Defer] **LOW.** A 201 with no `Location` id answers 500 after the write. Closed as DW-1626, wontfix-theoretical.
- [x] [Review][Defer] **LOW.** `RunAfter` reads JobGUID from `%SYS.Task` outside the port. Closed as DW-1627, wontfix-accepted.
- [x] [Review][Defer] **LOW.** `HandleCreate`'s vendor-refusal 422 rendering is unpinned. Closed as DW-1628, wontfix-accepted.
- [x] [Review][Defer] **LOW.** Each probe task leaves task-history rows. This is DW-1425, which already carries the 9.7 occurrence.

Rejected:

- **By-design:**
  - Agent Run After needs a user-supplied GUID (Design Notes).
  - `POST /tasks` stops at the first Name problem (the spec's Save order).
  - AC6 "before any port call" versus the absence read (the spec's Save order).
  - Output-file overwrite (the AD-21 ruling).
- **False:**
  - The `v1` Location path (measured).
  - Spec `status: done` versus tracker `review` (build-auto state).
  - Object-typed settings (the only one measured, `SMTPPass`, is classic-only).
  - Mixed TASK and non-TASK port rows (every `Task.CRUD` mapping is `TASK.*`).
- **Low, not worth the added complexity:**
  - Numeric Name gets REQUIRED from Save but SHAPE from check.
  - An empty end time answers SHAPE, not REQUIRED.
  - Weekly checkbox `aria-invalid`: the fieldset carries the description.
  - Expiry offset labels.
  - The hard-coded `Purge Tasks` in the browser spec.
  - Discarded browser cleanup result.
  - Endpoint-keyed `PROPERTYFAULTS` rows on task actions.
  - Trailing whitespace in a name.
  - No message when the types reload fails.
  - `/tasks/check` answers 400 for a non-object body.
  - Non-append edits in `Error.cls` and `Prohibited.cls`: no concurrent epic touches those hunks.
  - Fixture `OutputFileIsBinary` defaults.
  - The "exact name" wording against `TaskProbe`'s prefix check.
  - `Non-Primary` spelling.
- **Spec edits** (not in a review's remit): the triage counts and the change-log order.

### CI Rework (iteration 1)

- [x] [CI] browser: `task-wizard.browser-spec.mjs` "Matrix \"Create weekly\", AC7" failed on CI (run 36029831321, head `26284da8`) at its first assertion: `stepState(page)` read `[]` right after the URL reached `/tasks/schedule/edit`, before the stepper rendered -- `ui/browser/task-wizard.browser-spec.mjs:227` -- wait for the stepper's steps to render before reading them, and check every other leg of the file for the same read-before-render race; the file passed 5/5 locally, so reproduce the cold-start timing (e.g. run it first in a fresh browser) before claiming the fix.
- [x] [CI] browser: `proposal-demo.browser-spec.mjs` "AC1: UJ-3's own journey, as a non-%All holder of the screen's two pairs, inside NFR-1's budget" failed on the same run: `failed to find element matching selector ".ocu-panel-message-agent-text"` at `ui/browser/proposal-demo.browser-spec.mjs:505`. It passed on the previous head's CI (run 36009216113, `71aadf62`). Establish whether this story's diff (`turn.ts` createdId, `proposal-view.ts`, `screen-outlet.ts`, `app.ts`, `entity-ref.ts`, the kernel edits) causes it -- run the spec against a rebuilt, redeployed bundle -- and fix the cause if it is this story's; if it is not reproducible and not this story's, say so with the evidence (runs, bundle build) in `## Auto Run Result`. Do not edit the spec file itself if the cause is elsewhere: `proposal-demo` is not one of 11.10's seven specs, but check `git show origin/OCU-1-epic11:ui/browser/proposal-demo.browser-spec.mjs` before editing it.

## Spec Change Log

- 2026-09-24 rework 1 (implement): item 1 fixed by a `wizardReady` wait in `task-wizard.browser-spec.mjs`; item 2 found not this story's and not reproducible, its race deferred (`deferred:`).

- 2026-09-24 rework 1 (lead): CI run 36029831321 red on the browser job (two legs); re-opened with two `[CI]` items. Code review's patches (task-name case fold in `EntityRef`, period-day reset, field-list pins) are committed as the rework baseline.

- 2026-09-24 spec gate (lead): orchestrator rulings (a) on AD-21 (third named exception; location-type task settings permitted, named on the card) and (a) eager bundle (1580kB stop line); recorded in Tasks & Acceptance; spine AD-21 amended.

- 2026-09-24 implement (re-spawn): implementation resumed from an inherited, unverified partial tree (commit `9f44b36f`, from a stage lost to quota); `baseline_revision` kept at `f9851990`, so the story's diff includes it.

- 2026-09-24 spec gate (lead): applied ruling 2 (AD-3 and epics.md count: 49 documented, 47 on `%SYS.TaskSuper` plus `%%OID` and `%Concurrency`) and ruling 3 (EXPERIENCE.md stepper row reworded). Rulings 1 (AD-21 output file and task settings) and 4 (the owner's 1500kB bundle line) are asked of the orchestrator before the implement spawn.

## Review Triage Log

### 2026-09-24 — Review pass

- verdicts: 24 findings — high 0, medium 6, low 8, false 10, maybe-false 0
- findings:
  - `[medium]` `[patch]` A vendor refusal mapped by `PROPERTYFAULTS` was never observed through `TaskSave.Create` — added `TaskSaveSkew`/`TaskPortSkew` fixtures and `TaskSave.TestAVendorRefusalAnswersAsTheFormsOwn`; red when `PortViolations` is removed.
  - `[medium]` `[patch]` No test created a Monthly, Monthly Special or Run After task — added `TaskSave.TestEachPeriodCreatesAsItsRowReads` (stored period fields read back); red when Compose's Run After values are removed.
  - `[medium]` `[patch]` AC7's `EmailOutput` was never set or read back — set and asserted in `TestACreateAnswersItsIdAndReadsBackWhole` and `task-fields.test.mjs`; red when dropped from `FLAG_FIELDS`.
  - `[medium]` `[patch]` AC7's mutation reached only the client body builder, and the details screen was checked for the name only — server mutation (`Priority` out of `FIELDS`) recorded; the browser leg now asserts the details screen's schedule line (interval, 01:00, 05:00).
  - `[medium]` `[patch]` AC6's agent half had no least-privileged test — added `TaskWire.TestTheAgentsMintRefusesTheLeastPrincipalRunningAsAnother` (mint in a process logged in as the principal); red when the `%Admin_Secure` check is removed.
  - `[medium]` `[patch]` The schema was validated against a two-key body only — `TestTheSchemaIsDerivedAndDescribedFromTaskSuper` now validates a whole typed create against the schema and the rules.
  - `[low]` `[patch]` `VendorName()` could be empty and pass the taken-name mint leg vacuously — asserted non-empty in `TaskCreate` and `TaskSave`.
  - `[low]` `[patch]` The Matrix "nothing was created" count could not see a task under the vendor's upper-cased name — added `TaskProbe.Holders` and a count-unchanged assertion.
  - `[low]` `[patch]` Guarded assertions could skip silently (`tId`, `tResult`, the Run After rows) — each guard now has its assertion.
  - `[false]` `[reject]` AC sub-parts (AC1 Back, AC4 Once, AC5 parts, AC6 parts) have no mutation line — Rule 19 asks one demonstrated mutation per AC; each AC has one, and AC7's is now on the server path.
  - `[low]` `[patch]` `TASK.RUNASUSER.DISABLED`, `.SETTING.CLASSICONLY`, `.SETTING.SECRET` produced by no test — DISABLED pinned on the installed disabled account IAM, CLASSICONLY on `HS.Registry.Document.Archive.Task`'s `SourceIDS`; SECRET closed wontfix-theoretical: no task type on the measured instances has a credential-named setting (real once one does).
  - `[low]` `[patch]` Test doc comments named mutations the spec did not record — the Applied, Gate and 7404 mutations were applied and observed red (runs 10134-10136) and recorded under Verification.
  - `[false]` `[reject]` Ignored fields sent as `""` or fixed values rather than `%New()` defaults — the vendor's own utility writes exactly these (`TASKMGR.int` :182-205), and the contract's period table says so.
  - `[false]` `[reject]` Wire body is 35 keys, 33 without Settings — 33 plus optional Settings is the composed body; `OutputDirectory` is the AD-21 derived field.
  - `[low]` `[reject]` Input `maxlength` can truncate a paste silently — the form read's `maxLengths` drives `maxlength` in every editor (SSL, role, user); the rule refuses over-length on both API callers; diverging here alone buys nothing.
  - `[false]` `[reject]` A taken name is caught at Next rather than at Create's 422 — both are pinned (HTTP 422 in `TaskSave`, the raced browser leg).
  - `[low]` `[reject]` No HTTP confirm crosses into `TurnStore`; the allowed run-as-other runs as `%All` — each half is pinned (Confirm's `createdId`, `turn.test.mjs`), and `%All` holds `%Admin_Secure:USE`, the row's condition.
  - `[false]` `[reject]` Summary-then-field focus unpinned — `task-wizard.page.spec.ts` "Integration" pins the order.
  - `[false]` `[reject]` Three structural-baseline allowances for the route — the shell-wide DW-1583/1584 entries every form route carries; the wizard's own gate asserts no overflow.
  - `[low]` `[reject]` Arms and one method inserted mid-file rather than at the tail — no existing line is edited, and no concurrent epic touches these files (Design Notes, Contention).
  - `[false]` `[reject]` Location-type settings accepted as values — the AD-21 amendment permits them and the card naming the location is pinned.
  - `[false]` `[reject]` A second `# classes:` line in the task block — `ci.test.mjs` DW-1276 reads every classes line; its mutation is recorded.
  - `[false]` `[reject]` `classicOnly`, `options` and a repeated-digit refusal are beyond the stated shape — additive, and a set of digits has no repeats.
  - `[false]` `[reject]` Bundle and `classicPage` not evidenced — initial total measured 1,522,260 B; `NormalizePage("/csp/sys/op/UtilSysTaskBuilder.csp")` answers `%cspapp.op.utilsystaskbuilder` on slot A.

### 2026-09-24 — Review pass (rework 1)

- verdicts: 6 findings — high 0, medium 0, low 0, false 6, maybe-false 0
- findings:
  - `[false]` `[reject]` (verification-gap) Item 1's cold-start reproduction is not recorded — reproduced under 1,500 ms latency (red `actual []` without the wait, green with it); recorded under Verification, rework 1.
  - `[false]` `[reject]` (verification-gap) Item 2 is not addressed — investigated: 3 full-file runs 3/3 and 11 single-leg runs green on the rebuilt bundle, the file is unchanged by this story; its own race is deferred.
  - `[false]` `[reject]` (verification-gap) The spec claims more than the diff delivers — the items, Verification and Auto Run Result are written at finalize, after the review layers.
  - `[false]` `[reject]` (intent-alignment) CI-2 is not addressed — the same claim as the second row; refuted there.
  - `[false]` `[reject]` (intent-alignment) The CI-1 reproduction is not recorded — the same claim as the first row; refuted there.
  - `[false]` `[reject]` (intent-alignment) The diff changes only test synchronization, not the product — the auditor finds it sound under the rework reading; the stepper is drawn under `@if (loadedFlag)` by design.

## Design Notes

**Governing ADs:**

- AD-3 (the task paragraph; semantic half from TaskSuper), AD-4 (no subject for a create), AD-5, AD-6, AD-8 (the RunAsUser pair at call time), AD-10;
- AD-12, AD-13 (`task:integer`; name-keyed create), AD-14 (`createdId`), AD-16 (namespace switch for types and `IsValid`), AD-19;
- AD-21 (ruling below), AD-27 (in the port, not a fallback), AD-29 (least-privileged principal measured), AD-34, AD-35, AD-39;
- AD-44 (`classicPage`), AD-52 (TaskPort), AD-54, AD-55.

**Choices stated:**

- **The create's identity.** The vendor allocates a numeric id, accepts duplicate names, and returns the id only in `Location`, so an absence under the id means nothing. The create targets `task:instance:<Name>` and AD-54's fingerprint covers "no task has this name". Both callers refuse a taken name.
  - This is the one narrowing of the vendor, chosen so AD-54 has a subject and a name picks out one task in the list and to the agent.
  - The alternative permits a duplicate with a consequence line. It needs AD-54's absence inverted to "the holders of this name", a kernel change. It is not recommended.
- **The stepper is OcuPilot's own.** Measured: `MatStepper` in an eager component adds 83,411 B to the initial bundle before any wizard code. It also imports `MatIcon`, `@angular/common/http`, and `@angular/forms` via `ControlContainer`, which the app avoids.
- **Next validates on the server** (`POST /tasks/check`), so the schedule rules are written once (AD-39). Checks that need no server, such as required fields and length, also run on blur.
- **Running as another user is permitted and confirmed** (owner, 2026-09-23). The instance enforces `%Admin_Secure:USE` (measured), OcuPilot refuses first on the field, and a holder's agent proposal is destructive and names the account.
- **Run After on the agent path.** No read tool answers a task's JobGUID, so the agent can name a predecessor only by a GUID the user supplies. The wizard picks it from `runAfter`.
- **Expiry.** The measured facts are the storage semantics AC5 pins. The runtime meaning is the vendor doc on `Expires`: the run expires once the next submit time or the offset passes, whichever comes first. That meaning (inference) is labeled so, not guessed further. `Expired()` did not respond to any in-process variation tried.

**Requested lead rulings (Rule 5 / Rule 20):**

1. **AD-21 (required by AC7's "output file" and AC1's type settings).** Append:

   > "The third is a scheduled task's output file: the caller names one file, never a path -- a single segment matching `^[A-Za-z0-9][A-Za-z0-9._-]{0,99}\.txt$`, a literal `..` refused -- written to `<ManagerDirectory>` computed at call time and sent as `OutputDirectory` and `OutputFilename`. A task type's settings are values that type defines and validates (`<setting>IsValid`, as the vendor's own task utility does); a setting the type uses as a location is its value, confirmed like any other. [AMENDED 2026-09-24, Story 9.7 spec gate]"

   If this is declined, the output file becomes classic-only (OpenOutputFile, binary and EmailOutput stay), AC7 narrows, and path-named settings (4 of 88 measured) are drawn classic-only.
2. **AC2 count (Rule 5, apply and report).** The measured count is 49 documented out of 66 compiled, but only 47 are declared on `%SYS.TaskSuper`: the other two are `%%OID` and `%Concurrency`. Amend epics.md 9.7 AC2 and AD-3's sentence to:

   > "66 compiled properties, 49 documented: 47 declared on `%SYS.TaskSuper` rather than `%SYS.Task`, plus `%%OID` and `%Concurrency`"
3. **EXPERIENCE.md :533.** Change "Vertical Material stepper" to "Vertical stepper (`form-stepper`, Material 3 tokens)", and "(Material's `errorMessage`)" to "(the step's own error line)". The reason is the measured +83 kB above.
4. **Bundle: the owner's 1500kB line (asked before the implement spawn).**
   - **(a) Eager, as planned.** The wizard page, store, `task-fields` and `form-stepper` come to about 95–105 KB of source. At the measured 0.55 bundle-to-source ratio (X.509: 46,995 → 26,053) that is about +50–58 KB. The initial bundle goes from 1,476,787 B (measured today) to **about 1.53 MB** (inference). That crosses 1500kB and stays under the 1551kB warning.
   - **(b) Lazy wizard.** `screen-outlet.ts` maps `TaskForm` to a thin eager `TaskWizardShellPage`, whose template is `@defer (on immediate) { <app-task-wizard/> } @placeholder { skeleton }`. No store is injected in `app.ts`, and `TaskActions` stays eager.
     - Measured cost of `@defer` itself: +9,596 B initial for a trivial component.
     - Initial becomes **about 1.49 MB**, with about 50–58 KB in a lazy chunk.
     - It touches `ui/tools/build-output.test.mjs` (DW-371 fails on any extra `.js`; it would count a declared lazy chunk separately), one shell spec, and the browser spec's wait.
     - About 1–2 hours.
   - **(c) Also defer the other editors' pages** (SSL, web-app, user, role, X.509 and the three create forms, about 130 KB of pages).
     - The stores that `app.ts` injects for sign-out reset stay eager, or their reset moves to page destroy, which changes `app.spec.ts`'s reset legs.
     - The `users.browser-spec.mjs` mutation line on `DESCRIPTOR_EDIT_PAGES` needs re-pointing.
     - Initial becomes **about 1.36 MB** (inference).
     - About half a day.

**Ledger inbox:** none. `ledger.sh slice 9-7-the-new-task-wizard` is empty.

**Contention:**

- `origin/OCU-1-epic12` has no diff in `Registry`, `Kernel/Proposal`, `Router`, `Classification`, `screen-outlet` or `screen-mirror`.
- It edits the same one-line rosters: `AdminPort` `MUTATINGTYPES`/`BODYLESSTYPES`, `PortFixture`, `ReadTool`, `SurfaceCoverage`, `ToolRoundTrip`, and `strings.ts`/`screens.generated.ts`/`screen-action-handler.ts`. Expect hand merges, not design clashes.
- `footprint_extensions`: `ui/src/app/core/turn.ts`, `ui/src/app/core/navigation.ts`, `ui/src/app/app.ts`, `scripts/ci-throwaway.sh`, `Kernel/Proposal/{Mint,Confirm,Prohibited}.cls` (contended; appended arms and one hook each).

**Integration ACs:**

- **Consumes:**
  - 9.1–9.5: `core/form-tabs.ts`, the Save order, `FormDirty` and the summary.
  - 8.x: `CREATES`, `READROWKEY` and `PROPERTYFAULTS`.
  - 5.11 / 7.x: TaskPort.
  - The shell's `/namespaces`.
- **Consumed-by:** Story 9.8 (Edit task).
  - It reuses `task-fields.ts` (the field→step map read as field→tab), `TaskRules` (`Validate("update")`, `HandleForm` with `?id=`), `TaskPort`, `TaskForm` (it removes the `CREATE_ONLY_FORMS` entry and adds a `DESCRIPTOR_EDIT_PAGES` entry) and the `PROPERTYFAULTS`.
  - It adds `tasks.schedule.update` with `fingerprintExcludes` for the next-scheduled time.

## Verification

Slot A. Every IRIS MCP call carries `server: "ocupilot-slot-a"`. Anything that creates a task or user runs on `ocupilot-ci` only. Run one test class per call.

**Commands:**

- `(loop)` `cd ui && node --test tools/task-fields.test.mjs tools/navigation.test.mjs tools/strings.test.mjs tools/screen-mirror.test.mjs tools/field-lists.test.mjs tools/ci.test.mjs tools/form-tabs.test.mjs` -- expected: green.
- `(loop)` `cd ui && npm run test:components` -- expected: green, including `task-wizard.*`, `form-stepper`, `screen-outlet` and `turn`.
- `(loop)` `uv run scripts/test_check_objectscript.py && uv run scripts/check-objectscript.py && bash scripts/lint-docs.sh` -- expected: clean.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<X>`, one at a time -- expected: 0 failures each. X is:
  - TaskRules, TaskSave, TaskCreate, TaskWire;
  - TaskLists, TaskDetails, TaskScheduleActions, TaskResume, TaskRun;
  - Prohibited, ProhibitedByEffect, SurfaceCoverage, EndpointCoverage, ReadTool, ToolRoundTrip;
  - Descriptor, DerivedFields, AdminInventory, ScreenReadWire, RefusalCopy.
- `(loop)` `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`. Then run each spec file alone with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/<f>` -- expected: green. The files are task-wizard, tasks, task-schedule-actions, task-resume, task-run and a11y-structural-invariants. Report the build's "Initial total" bytes.
- `(once, before dev_complete)` `node ui/tools/ci-runner.mjs --container ocupilot-ci --package OcuPilot.Test` -- expected: 0 new failures. The full browser suite is CI's.

**Mutations (Rule 19; the pass that adds each pinning test writes its line):**

- AC1: drop the Next check call, and separately drop the step's error text.
- AC2: remove a description from `TaskCreate.Described`.
- AC3: widen Weekly's TimePeriodEvery to 1–7.
- AC4: drop the DailyIncrement-required rule.
- AC5: skip the On Demand Expires-0 alignment in the rules.
- AC6: drop the `%Admin_Secure` pre-check, and separately the `GrantsPrivilegeByEffect` task arm.
- AC7: drop OutputFileIsBinary from `task-fields`' body builder.
- Integration: skip `tabToOpen` in `afterRefusal`.
- Identity: set `CREATES` 0; answer `""` from `CreatedId`.

**Mutations observed (implement pass; each reverted, file byte-identical by sha1; ObjectScript runs on `ocupilot-ci`):**

- mutation: replace `TaskWizard.next()`'s check call with an empty answer -> `task-wizard.store.spec.ts` "AC1, Matrix Next on empty Basics" and the later-step leg went red.
- mutation: drop the step error line from `form-stepper.ts`'s template -> `form-stepper.spec.ts` AC1 step-in-error leg went red.
- mutation: remove `TimePeriod`'s entry from `TaskCreate.Described` -> `OcuPilot.Test.TaskCreate.TestTheSchemaIsDerivedAndDescribedFromTaskSuper` went red (run 10116).
- mutation: widen Weekly's `TimePeriodEvery` to 1-7 in `TaskRules.Validate` -> `OcuPilot.Test.TaskRules.TestEachPeriodReadsEveryAndDayAsItsRowSays` went red (run 10111).
- mutation: drop the `TASK.DAILYINCREMENT.REQUIRED` rule from `TaskRules.DailyViolations` -> `OcuPilot.Test.TaskRules.TestTheDailyQuadruple` went red (run 10112).
- mutation: drop the On Demand `Expires` 0 from `TaskRules.Compose` -> `OcuPilot.Test.TaskRules.TestTheExpiryFactsTheInstanceStores` went red (run 10113).
- mutation: drop the `%Admin_Secure` pre-check from `TaskRules.RunAsViolations` -> `OcuPilot.Test.TaskWire.TestTheLeastPrivilegedPrincipalCreatesAndCannotRunAsAnother` went red (run 10114); drop the task arm of `Prohibited.GrantsPrivilegeByEffect` (with `ProhibitedFixture` recompiled) -> `OcuPilot.Test.TaskCreate.TestARunAsAnotherAccountIsMintedDestructive` and `TestRunningAsAnotherAccountIsJudgedByEffect` went red (run 10115).
- mutation: drop `OutputFileIsBinary` from `task-fields.ts` `createBody` -> `tools/task-fields.test.mjs` body leg went red.
- mutation: skip `tabToOpen` in `TaskWizardPage.afterRefusal` -> `task-wizard.page.spec.ts` Integration went red; rebuilt and redeployed, `task-wizard.browser-spec.mjs` "Name taken, Integration" went red.
- mutation: set `TaskCreate.CREATES` 0 -> four `OcuPilot.Test.TaskCreate` methods went red (run 10117); answer `""` from `TaskCreate.CreatedId` -> `TestTheConfirmCreatesAndAnswersTheId` went red (run 10118).
- mutation: drop the `Validate` call from `TaskCreate.ArgumentProblem` -> `OcuPilot.Test.TaskCreate.TestTheMintAppliesTheFormsRules` went red (run 10119).
- mutation: drop the `OUTPUTFILEPATTERN` match from `TaskRules.Validate` -> `OcuPilot.Test.TaskRules.TestTheOutputFileIsOneNameNeverAPath` went red (run 10120).
- mutation: add `Settings.Directory` to the Task schedule's `secretArguments` in the mirror -> `tools/proposal-view.test.mjs` location-row leg went red.
- mutation: publish `target.id` in `TurnStore.confirmProposal` -> `tools/turn.test.mjs` createdId leg went red.
- mutation: drop TaskForm from `CREATE_ONLY_FORMS` -> `tools/navigation.test.mjs` editorScreenFor leg went red.
- mutation: drop `TaskCreate` from the `OCUPILOT_ALLOW_TASK_CONTROL` roster in `ci-throwaway.sh` -> `tools/ci.test.mjs` DW-1276 went red.

**Mutations observed (review pass; same discipline; batches read by assertion message):**

- mutation (AC7, server): remove `Priority` from `TaskRules.FIELDS` -> `OcuPilot.Test.TaskSave.TestACreateAnswersItsIdAndReadsBackWhole` went red on the priority read-back (run 10133).
- mutation: delete the `PortViolations` call from `TaskSave.Create` -> `TestAVendorRefusalAnswersAsTheFormsOwn` went red (run 10133).
- mutation: delete the Run After fixed values from `TaskRules.Compose` -> `TestEachPeriodCreatesAsItsRowReads` went red on OcuP97After (run 10133).
- mutation (AC6, agent half): make `TaskRules.RunAsViolations`' `%Admin_Secure` check never fire -> `OcuPilot.Test.TaskWire.TestTheAgentsMintRefusesTheLeastPrincipalRunningAsAnother` went red (run 10134).
- mutation: replace the `Gate` call in `TaskRules.HandleCheck` with a pass -> `TaskWire.TestACallerLackingAPairIsRefusedOnEveryRoute` went red on `/tasks/check` (run 10134).
- mutation: make `TaskRules.Applied` always drop the Several fields -> `TestACreateAnswersItsIdAndReadsBackWhole` went red on its 201 (run 10135).
- mutation: remove `Task.CRUD:7404` from `AdminPort.PROPERTYFAULTS` (TaskPort and TaskPortSkew recompiled) -> `TestTheVendorsCodesLandOnTheirFields` and `TestAVendorRefusalAnswersAsTheFormsOwn` went red (run 10136).
- mutation: remove `EmailOutput` from `task-fields.ts` `FLAG_FIELDS` -> `tools/task-fields.test.mjs` "the output file is emailed" went red.
- mutation (lead AD gate, AD-54): force `tPresent = 0` in `Confirm`'s create re-read (Confirm and its three fixture subclasses recompiled on `ocupilot-ci`) -> `OcuPilot.Test.TaskCreate.TestTheConfirmCreatesAndAnswersTheId` went red on "the confirm is refused" and "nothing more is written" (run 10378); reverted by sha1, green (run 10379).

**Mutations observed (code review; each reverted, files byte-identical by sha1; ObjectScript on `ocupilot-ci`):**

- mutation (AD-13, AD-54): answer a non-integer verbatim in `EntityRef.PlainInteger` -> `OcuPilot.Test.EntityRef.TestTheIdRuleTableIsDeclaredAndIsWhatNormalizationApplies` ("a task name folds to lower case", run 10385) and `TaskCreate.TestTheCreateIsMintedOverTheNamesAbsence` ("the target is the name in its canonical spelling", run 10386) went red; the same in `entity-ref.ts` -> `tools/entity-ref.test.mjs` AD-13 integer leg went red.
- mutation (AD-3): drop `MirrorStatus` from `TaskRules.FIELDS` -> `TaskCreate.TestTheSchemaIsDerivedAndDescribedFromTaskSuper` "the rules compose exactly the permitted set" went red (run 10386).
- mutation: carry the held day over in `TaskWizard.setText` -> `task-wizard.store.spec.ts` "a period change starts the day over" went red.
- mutation: drop the held-value option from `TaskWizardPage.settingView` -> `task-wizard.page.spec.ts` "a select setting whose default no option names" went red.
- Green after the revert: `EntityRef` 9/9 (10387), `TaskCreate` 7/7 (10388), `TaskWire` 3/3 (10382), `TaskSave` 8/8 (10383), `TaskRules` 9/9 (10384); `npm run test:tools` 1,396/1,396; `ng test` 1,154/1,154; `check-objectscript` clean; build initial total 1,522,189 B; bundle redeployed to `ocupilot-ci`, `task-wizard.browser-spec.mjs` 5/5.

**Mutations observed (rework 1):**

- mutation (CI item 1, timing): remove the `wizardReady` wait before `stepState` and add 1,500 ms request latency before the list's Create -> `task-wizard.browser-spec.mjs` "Matrix \"Create weekly\", AC7" went red with `actual []`, the CI failure; the fixed leg under the same latency went green; restored, sha1 `f2d6e6fc` matches.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** The New Task wizard: a create-only four-step `form-page` at `tasks/schedule/edit` (OcuPilot's own `form-stepper`), the `/tasks` form, check and create routes, the `tasks.schedule.create` tool for both callers (AD-54, AD-55), `TaskRules` as the one rule set, `TaskPort`'s created id from `Location`, `createdId` on the confirm answer and in `turn.ts` (AD-14), the `TYPETASK` prohibited-set arms, and the Task schedule list's Create. Resumed from the inherited tree `9f44b36f`, whose server side and client model were kept; this pass completed the component specs, the browser spec, the regenerated screen mirror and the roster updates, fixed the Options step's duplicated Priority and MirrorStatus inputs, and added the review's test legs.

**Files (beyond the inherited commit):** `ui/src/app/areas/tasks/task-wizard.page.ts` (duplicate inputs, `client-lint`); `screens.generated.ts` (regenerated); `strings.ts` (`taskCreate` reference); specs `form-stepper.spec.ts`, `task-wizard.store.spec.ts`, `task-wizard.page.spec.ts`, `task-actions.spec.ts`; `ui/browser/task-wizard.browser-spec.mjs` (new) and the `tasks.browser-spec.mjs` Create leg; `Test/TaskSave`, `TaskCreate`, `TaskRules`, `TaskWire`, `TaskProbe` (review legs); `Test/TaskSaveSkew`, `Test/TaskPortSkew` (new fixtures); `Test/Wire`, `Test/WireSecurityRead` (the wizard added to the tasks-area rosters, which the sweep reddened).

**Review:** 24 findings (two layers): 12 patched (6 medium, 6 low), 12 rejected with reasons in the triage log, 0 deferred from review. One stage finding deferred (below). `followup_review_recommended: true`: six medium patches added test legs and two fixtures after the review layers ran; each was reddened by this stage's own mutation, but no independent layer has read them.

**Verification (this stage's own runs, all on `ocupilot-ci`):**

- Inherited tree loaded and compiled whole before anything was trusted: 792 classes, status OK; recompiled whole (`CompilePackage`) before the sweep.
- Full ObjectScript sweep, once: `ci-runner --package OcuPilot.Test`, 239 classes, 2,097 tests, 3 failed, runs 10137-10375, no overlaps or foreign runs. `Wire` (1) and `WireSecurityRead` (1 of 2) were this story's roster trip (the wizard is a seventh tasks screen); rows added, `Wire` green (run 10376), `WireSecurityRead` 21/22 (run 10377). The remaining `TestTaskHistoryPairSetsAreEnforcedForARealPrincipal` fails on "nothing is cut at 1,000": this reused throwaway holds 2,078 task-history rows, 1,842 of them from other tasks (MIRROR OAUTH2 CONFIG SYNC TASK alone 674); no code of this story reads history. CI's fresh throwaway is the authority.
- The throwaway predates four arming blocks (`OCUPILOT_ALLOW_TASK_CONTROL`, `_AUDIT_TOGGLE`, `_ERROR_DELETE`, `_PROCESS_CONTROL`); runs added them to `docker exec` on `ocupilot-ci` only, as `ci-throwaway.sh` sets them on a fresh one.
- Story classes, after the review patches: `TaskSave` 8/8 (10129), `TaskCreate` 7/7 (10130), `TaskRules` 9/9 (10131), `TaskWire` 3/3 (10132).
- Client: `npm run test:tools` 1,396/1,396; `npm run test:components` 1,152/1,152; `check-objectscript` (794 files) and its harness, `lint-docs`, and `npm run build`'s prebuild checkers clean.
- Browser, bundle rebuilt and copied into `ocupilot-ci` first, one file at a time: `task-wizard` 5/5, `task-schedule-actions` 4/4, `task-resume` 3/3, `task-run` 2/2, `a11y-structural-invariants` 10/10, `tasks` 13/15. The two `tasks` failures are Story 6.6 AC1 and AC3 (Task history's demo-task row), over the same 2,078-row history; not this story's files.
- Bundle initial total: **1,522,260 bytes** (`main` 1,381,460 + `styles` 140,800), under the 1551kB warning; `angular.json` unchanged, no `@defer`.
- `classicPage`: `NormalizePage("/csp/sys/op/UtilSysTaskBuilder.csp")` answers `%cspapp.op.utilsystaskbuilder` on slot A (read-only).

**Residual risks:** the details screen shows only the schedule of AC7's values (priority, output file and addresses are pinned at the instance read-back); `TASK.SETTING.SECRET` is unreachable on the measured type population; each probe task leaves two vendor-written task-history rows (deferred).

footprint_extensions: `ui/src/app/core/proposal-view.ts`, `ui/src/app/areas/tasks/details.page.spec.ts`, `ui/src/app/shell/screen-outlet.spec.ts`, `ui/browser/structural-baseline.json`, `ui/tools/proposal-view.test.mjs`, `ui/tools/turn.test.mjs`, `ui/tools/navigation.test.mjs`, `src/OcuPilot/Test/Wire.cls`, `src/OcuPilot/Test/WireSecurityRead.cls`, plus the Design Notes list (`turn.ts`, `navigation.ts`, `app.ts`, `scripts/ci-throwaway.sh`, `Kernel/Proposal/{Mint,Confirm,Prohibited}.cls`). No 11.10 file or browser spec touched.

### Rework iteration 1 (CI)

Status: done
Blocking condition: none

- **Item 1 (fixed).** The wizard draws its stepper only once `GET /tasks/form` answers, and the URL moves before that. The Create weekly leg now calls the file's `wizardReady` before `stepState` (`ui/browser/task-wizard.browser-spec.mjs`, +2 lines). The other four legs already wait. Reproduced under 1,500 ms latency: red `actual []` without the wait, green with it. The whole file passed 5/5 under 1,000 ms latency on every request, and 5/5 four times without.
- **Item 2 (not this story's, not reproduced).** On the rebuilt, redeployed bundle with the server tree reloaded (`load-ci.sh` OK), `proposal-demo.browser-spec.mjs` passed 3/3 in three full-file runs and in 11 single-leg runs. The story does not touch that path:
  - `EntityRef`'s change is the `integer` rule, used by task and process. Web applications use `foldcase-striptrailingslash`.
  - The `Mint` hook covers creates only, and this journey is an update.
  - `createdId` is empty for web applications.
  - The spec file is unchanged since `f9851990` and identical on `origin/OCU-1-epic11`.

  The likely cause is in that file (inference): a bare read of the reply at :505. It is deferred in frontmatter, not edited.
- **Targeted runs on `ocupilot-ci`, one class per call:** `EntityRef` 9/9 (10389), `TaskRules` 9/9 (10390), `TaskSave` 8/8 (10391), `TaskCreate` 7/7 (10392), `TaskWire` 3/3 (10393), `Wire` 20/20 (10394), `ToolRoundTrip` 2/2 (10395), `SurfaceCoverage` 4/4 (10396). Counts were read back from `%UnitTest_Result`. `npm run test:tools` 1,396/1,396; `npm run test:components` 1,154/1,154. Build initial total 1,522,189 B.
- **Review:** 2 layers ran (verification-gap, intent-alignment) and filed 6 findings. All 6 were false and none were patched, so `followup_review_recommended: false`.
- footprint_extensions: none.
