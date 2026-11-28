---
title: 'Story 21.36: Task output and mail password'
type: 'feature'
created: '2026-11-20'
status: 'done'
baseline_revision: '18ca3836456d8febb2446a9caebdb7d3238b729d'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-21-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-21-19-shell-advisor-permission-and-task-leaves.md'
warnings: ['multiple-goals', 'oversized']
---

<intent-contract>

## Intent

**Problem:** Two Task Manager leaves have no OcuPilot surface: a task's output file (TM-17) and the Task Manager mail password (TM-18's last setting). Story 21.19 built the email settings and left both here, with owner answer U-70's records already in the spine (AD-21's Story 21.19 consumer line, AD-35's Task Manager mail password paragraph).

**Approach:** The output file becomes a `log-viewer` sub-screen of Task schedule, opened from Task details, read through `LogSourcePort` as a new bounded, tail-first source keyed by the task id. The password becomes a secret-only write (`tasks.mail.password`) on `ConfigPort`, on `analytics.settings.setkey`'s model, reached from the Task Manager email screen. Two ordered batches, each committable alone.

## Boundaries & Constraints

**Always:** One descriptor and one port per screen (AD-5, AD-52); the port gates first (AD-29). The output file is read only when the stored `OpenOutputFile` is true, `OutputDirectory` normalizes to `<ManagerDirectory>` computed at call time, the vendor's own join `OutputDirectory_OutputFilename` is that same file directly in that directory, and `OutputFilename` matches `TaskRules.OUTPUTFILEPATTERN` with no `..`; anything else is shown on Task details and never read (AD-21). The read is bounded and reports truncation (AD-36); output text is untrusted (AD-11, AD-60). The password is supplied at the write, and product code never stores, reads, compares, fingerprints, renders or logs it (AD-35, AD-56 (i), AD-58, AD-59). Every user-facing string comes from EXPERIENCE.md through `strings.ts`, and nothing under "Strings, escalated" is used until ruled. Shared registration files take add-only edits.

**Never:** No caller path or file name: the caller names a task id, never a location. No new AD and no AD amendment. No `AuthPassword` row in the Task Manager email read (Story 21.19's AC2 stands). No change to `AuditPort`'s mask (Story 21.24 ships it). No edit to a file Epic 24's branch has changed beyond feature (none of this story's files, checked at plan; re-check before each edit). No write to slot A's `ocupilot`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Output read | task `OpenOutputFile` 1, `OutputDirectory` the manager directory, `run.txt` with lines | rows `{offset, text}` from the file's last 65,536 bytes, whole LF-ended lines, each byte one character (the vendor writes 8-bit text), newest first; `truncated` true when the file is larger than the window or the row cap cut | none |
| Empty output | the file exists, 0 bytes | zero rows, not truncated | none |
| Not written yet | the record names the file, the file is absent | no rows | 404 `LOG.TASKOUTPUT.ABSENT` |
| No output file | `OpenOutputFile` 0 or `OutputFilename` empty | no file touched | 409 `LOG.TASKOUTPUT.NONE` |
| Elsewhere | `OutputDirectory` not the manager directory, the manager directory without its trailing separator (the vendor then writes `.../iris/mgr<name>`, measured), or a name outside the pattern | no file touched; the refusal echoes no path | 409 `LOG.TASKOUTPUT.ELSEWHERE` |
| Task gone | `taskId` unknown, or not a whole number of at most 10 digits | no record read for a shape miss; no file touched | 404 `TASK.ABSENT` (Task details' "This task no longer exists.") |
| Missing pair | caller lacking `%Admin_Task:USE` or `%DB_IRISSYS:READ` | no record read | 403 `AUTH.NOPRIVILEGE` (the shared log-source gate's code, as every sibling source; orchestrator ruling 2026-11-21) |
| Password set | person's dialog or agent's confirmed card, value `p` | `EmailSet("AuthPassword", p)`; read-back `written`, never examined | vendor refusal surfaces as the write's fault, value-free |
| Password clear | empty value | `EmailSet("AuthPassword", "")` clears it (`CLEARABLESECRETS`) | none |
| Password draft | "Give me the script instead" | `EmailSet("AuthPassword", "<AuthPassword>")`, no value | none |

</intent-contract>

## Code Map

- **Spine records:** `ARCHITECTURE-SPINE.md:644` (AD-21, the task output consumer), `:846` (AD-35, the mail password, secret-only via AD-56 (i)). AD-21's third case pattern at `:599`.
- **Log source port:** `src/OcuPilot/Port/LogSourcePort.cls` -- `SOURCES` :98, `Sources()` :470, `PairsFor` :499 (one `If` per key), `Page` :727 (gate, `maxBytes` default 65536 :423, cap :427, the `integrity` branch :775 is the template for a source whose `file` is an id), `Resolve` :3124 (`%File.NormalizeFilename` against `ManagerDirectory()` :652, computed per call), `DirectlyIn` :3158 (Private: `NormalizeDirectory` + `GetDirectory`/`GetFilename`; reuse it), `OpenStream` :684, `Identity` :3639, `ReadWindow` :3698 (whole lines, UTF-8), `Rows` :1038 (the declared read; turns `LOG.ABSENT` into `[]` at :1063, which the new source must not), `FileRefusal` :3464. `PathPort`'s manager helpers answer true for an empty manager directory, so never use them as an admission check.
- **Declared read:** `src/OcuPilot/Screen/Read.cls:552-563` calls `LogSourcePort.Rows(endpoint, max+1, ...)` with no criteria; the route-param pattern to copy is :697-701 / :783-787 (`SeedCriteria` into `tQuery`).
- **Task record:** the Task details GET (`Task.CRUD` through `AdminPort`) already answers `OpenOutputFile`, `OutputDirectory`, `OutputFilename`, `OutputFileIsBinary` (measured); `Screen/Descriptor/TaskDetails.cls` names none of them. `Area/Task/TaskRules.cls` `OUTPUTFILEPATTERN` :49, `IsManagerDirectory` :388 (Private, trailing-separator compare only; not the admission check). `irissys/%SYS/Task.cls` extends the unexported `%SYS.TaskSuper`.
- **Sub-screen precedent:** `Screen/Descriptor/LanguageServerActivity.cls` (log-viewer, `id` single, `parentScope`, one criterion from the route id). Client: `ui/src/app/areas/os-management/language-server-form.page.ts:488-495,553` (`activityLink`), `ui/src/app/areas/logs/log-viewer.page.ts:91-113` (`DECLARED_READ`, `SOURCES`), `log-viewer.store.ts:173` (`readRowsOf`), :213 (`reportLinesOf`). Task details page `ui/src/app/areas/tasks/details.page.ts:109-121` (links nav), :267-318 (`historyUrl`, `editUrl`).
- **Read tool:** derived `<toolIdentifier>.read` (`Screen/Tool/Registry.cls:11-17,260-268`); the AD-60 sanitizer applies to every read tool's result (inference: no per-tool step).
- **Secret-only sibling:** `Screen/Tool/AnalyticsSettingKey.cls` (non-admin port, `SECRETBODY`, `CLEARABLESECRETS`, `SCREENACTIONS`/`SCREENVALUES`/`SCREENEMPTY`, `StateDiff`); its descriptor `AnalyticsSettingList.cls:33` (`secretArguments`); `Classification.cls:1597-1603` (`authored {"GoogleMapsKey": "secret"}`) plus regenerated `ToolFields.cls` (`cd ui && node tools/field-lists.mjs`). Kernel: `Kernel/Proposal/Operation.cls:177` `SecretBody`; callers `Confirm.cls:440`, `Api/ScreenAction.cls:439`, `Draft.cls:189`. `Api/ScreenAction.cls:188` admits only `rowActions`; `LicenseKey.cls:37-38` lists one id as both `primaryAction` and row action. `ReadBack.KindOf` :240-251 reports `written` for a secret-only write.
- **Config port:** `src/OcuPilot/Port/ConfigPort.cls` -- `PAIRS` :64, `WRITEPAIRS` :69, `TASKMAILROSTER` :166 (no `AuthPassword`), `WRITETYPES` :205, `Serves` :299, `Invoke` :364, `Admit` :439, `Row` :467, `SetValue` :789, `Apply` :868, `SendNode` :1047 (`EmailSet` :1058), `SnippetForm` :1422, `Snippet` :1433, `RosterLine` :1487. Vendor `irissys/%SYS/Task/Config.cls:98` `AuthPassSet` (returns the store status), `:175` `EmailSet`.
- **Task mail screen:** `Screen/Descriptor/TaskMailSettingList.cls`; `Screen/Tool/TaskMailSettingSet.cls`. Client `ui/src/app/areas/os-management/config-settings.page.ts:70-75` (`CONFIG_SET_KEY_ACTION`/`CONFIG_KEY_VALUE`, page-wide singletons), :168, :371-381, :432-437; dialog `ui/src/app/areas/interoperability/interop-item-setting-dialog.ts` (`secret` input, `title` input). Client rosters `shell/screen-action-handler.ts:558`, `core/screen-actions.ts:215`.
- **Leak pins to model:** `Test/AnalyticsSettingsWrite.cls:316` `TestTheKeyIsSetByBothCallersAndSurfacesNowhere`; `Test/AuthOptionsWrite.cls:215`; `Test/DraftRegistry.cls:145,184,410` (its synthetic id for `task-mail-setting` is `Port`, `TYPEDTARGETIDS` :60, so the draft must render `<AuthPassword>` for any target id); `Test/TaskMailAuditMask.cls`. Armed roster `scripts/ci-throwaway.sh:963` (`OCUPILOT_ALLOW_CONFIG_SETTINGS`).
- **Strings:** `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` Fixed strings (:250 on); `ui/src/app/core/strings.ts`; `ui/tools/strings.test.mjs` (both directions, literal band :615-617).

## Tasks & Acceptance

**Task 0 (on `ocupilot-ci` only; record results under Design Notes before code).** The plan measured the vendor (Design Notes). The one open item, a REST request process holding only `%Admin_Task:USE` and `%DB_IRISSYS:READ` reading a manager-directory file, is measured and passes (Design Notes). `TaskOutputRead` keeps a denial-free leg for it.

### Batch 1: the task output viewer (server and client; commit when its loop is green)

- `src/OcuPilot/Port/LogSourcePort.cls` -- add source `taskoutput` (`TASKOUTPUTKEY`, `TASKOUTPUTPAIRS` `%Admin_Task:USE,%DB_IRISSYS:READ`, in `SOURCES` and `PairsFor`; not in `TAILSOURCES` or `RECENTSOURCES`). `Rows` takes an optional criteria array; for `taskoutput` it requires `taskId` matching `^[0-9]{1,10}$`, reads the stored record through an overridable seam `TaskOutputRecord(pTaskId, .pFound, .pOpen, .pDirectory, .pFile)` (`%SYS.Task` `%OpenId(id, 0)` in `%SYS`, explicit namespace save and restore, every reference dropped), then refuses in the matrix's order, then resolves through `Resolve`/`DirectlyIn` and requires `NormalizeFilename(OutputDirectory_OutputFilename)` to equal that resolved file, opens, and reads the last 65,536 bytes as whole lines with no UTF-8 decode (a flag on `ReadWindow`, default unchanged). Rows `{offset, text}`, newest first, capped by the caller's max with truncation reported. No `Page` route and no live tail.
- `src/OcuPilot/Api/Error.cls` -- `LOGTASKOUTPUTNONE`, `LOGTASKOUTPUTELSEWHERE`, `LOGTASKOUTPUTABSENT` and their reasons (ruled strings).
- `src/OcuPilot/Screen/Read.cls` -- the `logsource` branch seeds a declared read's criteria (the :697-701 pattern) and passes them to `Rows`; a read with no criteria is unchanged.
- `src/OcuPilot/Screen/Descriptor/TaskOutput.cls` -- new, on `LanguageServerActivity`'s shape: route `tasks/schedule/output`, `parentScope` `tasks/schedule`, `sideBarPosition` 0, archetype `log-viewer`, `id` single, entity `log-entry`, privileges and `classicPage` Task details' own (`%CSP.UI.Portal.TaskInfo`), source `{"port": "logsource", "endpoint": "taskoutput", "type": "LIST"}`, fields `offset`, `text`, sort `offset` desc, paging `cap`, criterion `taskId` (Task details' label, length and hint, no `vendorParam`), column `text` (`logViewerColumnMessage`), tool `tasks.taskoutput` (derived `tasks.taskoutput.read`), three suggested prompts.
- `src/OcuPilot/Screen/Descriptor/TaskDetails.cls` -- `read.fields`, `filter`, `sort.fields` and `context.fields` add `OpenOutputFile`, `OutputDirectory`, `OutputFilename`; table columns add `OutputFilename` (`taskOutputFilename`, existing) and `OutputDirectory` (ruled string). No row action.
- Regenerate `Screen/Titles.cls` and `ui/src/app/core/screens.generated.ts` (`screen-mirror`).
- `ui/src/app/areas/logs/log-viewer.page.ts`, `log-viewer.store.ts` -- `'tasks/schedule/output': DECLARED_READ`; an `outputRowsOf` mapper beside `readRowsOf` (text only, no stamp or severity, oldest first as drawn); the three refusals drawn in place of rows with their ruled sentences; a drawn truncation line when the read says `truncated`, for this source only.
- `ui/src/app/areas/tasks/details.page.ts` -- a third details link, "Open output file" (ruled), to `tasks/schedule/output/<Id>`, shown only when `OpenOutputFile` is true and `OutputFilename` is not empty; the port decides whether it reads.
- `ui/src/app/core/strings.ts`, EXPERIENCE.md -- the ruled Batch 1 strings, add-only.
- Tests: `Test/TaskOutputRead.cls` (new; live-safe: an on-demand fixture task the class creates, never run, whose probe file the class writes itself in the manager directory, both removed in `OnAfterOneTest`; screen read and `tasks.taskoutput.read` answer the same rows; tail-only and truncated on a file larger than the window; empty; absent; none; elsewhere through the seam with no path in the answer; non-numeric id; gate refusal). `Test/TaskDetails.cls` (the three fields; still no action). `ui/src/app/areas/tasks/details.page.spec.ts` (link shown and hidden), `log-viewer.spec.ts` (mapper, refusals, truncation line), `ui/browser/task-output.browser-spec.mjs` (new: an on-demand task the spec creates through OcuPilot's API with an output file name, its file written by `docker exec` into `OCUPILOT_BROWSER_CONTAINER`'s manager directory; Task details shows the link, the viewer shows the file's last line after the answered signal; the spec deletes the task and the file).

### Batch 2: the mail password (server and client; commit when its loop is green)

- `src/OcuPilot/Port/ConfigPort.cls` -- write type `PASSWORD` in `WRITETYPES`, served for `TaskMail` only; its `Invoke` branch reads the target row (`AuthUser`) for the fresh read and sends `EmailSet("AuthPassword", pBody.AuthPassword)`, returning the vendor's status, with no roster, rules or `StoredFor`; `Snippet` renders `Set tSC = ##class(%SYS.Task.Config).EmailSet("AuthPassword", "<AuthPassword>")` whatever the target id. The secret never enters a local that outlives the call, a status text or a trap.
- `src/OcuPilot/Screen/Tool/TaskMailPassword.cls` -- new, on `AnalyticsSettingKey`'s shape: `TOOLNAME tasks.mail.password`, `DESCRIPTORCLASS TaskMailSettingList`, `PORTCLASS ConfigPort`, `ENDPOINTNAME TaskMail`, `WRITETYPE PASSWORD`, `SENDSBODY 0`, `SECRETBODY` and `CLEARABLESECRETS` `AuthPassword`, `STATEFIELD AuthPassword`, `PRECONDITIONFIELD` and `FINGERPRINTSUBJECT` `Value` (the `AuthUser` row the password signs in with), `SCREENACTIONS password`, `SCREENVALUES` and `SCREENEMPTY` `password=AuthPassword`, `CLASSICPAGES %cspapp.mgr.utilsystaskmail`, `StateDiff` as the sibling's (one row, empty before and after); the description tells the model to send the literal `AuthUser` and never a password; pairs exactly `TaskMailSettingSet`'s write pairs (`ConfigPort.WRITEPAIRS`), which is stricter than the vendor's own `%Admin_Manage:USE` (measured) and never looser.
- `src/OcuPilot/Screen/Descriptor/TaskMailSettingList.cls` -- `primaryAction` `password` and `rowActions` add `password`; top-level `secretArguments: ["AuthPassword"]`; doc comment: the password is a write, never a row.
- `src/OcuPilot/Screen/Tool/Classification.cls` -- the tool's entry, `authored {"AuthPassword": "secret"}`; regenerate `ToolFields.cls`.
- `src/OcuPilot/Kernel/Governance/Baseline.cls` -- `tasks.mail.password` `true` (not destructive; a clear is undone by a set).
- Client: `config-settings.page.ts` -- the secret action and its value name come from a per-descriptor map (Analytics `setkey`/`GoogleMapsKey`, Task Manager email `password`/`AuthPassword`) instead of the two singletons; Task Manager email draws one toolbar button "Set mail password" (ruled) that opens the existing dialog with `secret` and the ruled title (its existing `title` input; the dialog file is not edited), target `AuthUser`. `shell/screen-action-handler.ts`, `core/screen-actions.ts` -- the `password` action, add-only. `strings.ts`, EXPERIENCE.md -- the ruled Batch 2 strings.
- Tests: `Test/TaskMailPasswordWrite.cls` (new, armed by `OCUPILOT_ALLOW_CONFIG_SETTINGS`, added to `ci-throwaway.sh`'s roster line :963; on `TestTheKeyIsSetByBothCallersAndSurfacesNowhere`'s model: holds the original value in a local and restores it in `OnAfterOneTest` without printing it; both callers set a probe, `EmailGet` compares equal in-process (1/0 only), read-back `written`; clear empties it; the probe is absent from both answers, the proposal row, the ledger, screen context, messages.log, the draft (which carries `<AuthPassword>`), and the Task Manager email read; the key `false` refuses). The audit row's mask stays `TaskMailAuditMask`'s, re-run unchanged: the vendor writes the audit row about a minute after the set (measured), so this class never waits on one. `Test/TaskMailSettingRules.cls`'s "AuthPassword is no setting of `tasks.mail.set`" leg keeps passing. `config-settings.page.spec.ts` (the button, the dialog's secret field, the sent action and value name), `ui/browser/config-settings.browser-spec.mjs` (a set-and-clear leg; its "never the mail password" leg keeps passing).

**Rework 1 (open items only; everything else is closed and not to be re-derived):** work every unchecked item under `### Review Findings` and the `## Fix Pack`. The two Patch items carry the orchestrator's rulings: `TaskError` is a new sibling class on `SqlActivityError`'s and `MonitorError`'s shape that declares the six `LOG.TASKOUTPUT.*` codes and their reasons (code strings unchanged; `Api/Error.cls` returns to feature's parameter count, `git show origin/feature/OCU-1_ocupilot-mvp:src/OcuPilot/Api/Error.cls | grep -c '^Parameter '`, and `PATHROOT`'s comment reads "(AD-12, AD-21, AD-39)" again); the Set mail password dialog shows no "Current value" line and the clear hint once, with no new sentence (if one seems needed, HALT and name it). Update the two roster tests with names read from the instance, run `a11y-structural-invariants.browser-spec.mjs` against the rebuilt bundle (a governance settle timeout there is DW-1822, not this story's), and give every changed pinning assertion its `mutation:` line.

**Acceptance Criteria:**

- AC1 (TM-17). Given a task whose record names an output file in the manager directory, when a person opens "Open output file" from Task details or the agent calls `tasks.taskoutput.read` with its id, then both answer the same lines from the file's tail, bounded, with truncation stated; for a record naming any other location, both refuse without touching the file and Task details shows the location.
- AC2 (TM-18). Given the Task Manager email screen, when a person sets the mail password from its dialog or confirms the agent's `tasks.mail.password`, then the vendor stores it, an empty value clears it, and the value appears in no read, card, proposal row, ledger row, screen context, log line, copy-out draft or unmasked audit row.
- AC3. Given the default baseline, when the agent proposes `tasks.mail.password`, then it mints and confirms; with its key `false`, the governance gate refuses it.

### Review Findings

- [x] [Review][Patch] (rework 2, orchestrator ruling 2026-11-21: DW-2811 is fixed here, not deferred) An unterminated final line is a line: a task output whose last line has no line feed must show that line, so a one-line output written without a trailing LF never reads "No entries." The fix is local to the tail read (`LogSourcePort` `ReadWindow` / `TaskOutputRows`); the 65,536-byte window still starts at a line boundary, and a file of 64 KB or less is still never marked truncated. Add a test with a short no-LF file (its one line shows, not truncated) and one longer than 64 KB whose cut falls inside a no-LF tail (the rows the window can honestly show, the truncated sentence, never a mid-line start), each with a `mutation:` line; check the change leaves every other log source's tail unchanged (`LogSourceDenial`, every class starting `LogSource`, `TaskOutputRead`). [src/OcuPilot/Port/LogSourcePort.cls, src/OcuPilot/Test/TaskOutputRead.cls] -- closed in rework 2: `TaskOutputRows` serves the end of a no-line-feed window as one row; `ReadWindow` is unchanged.

Code review 2026-11-21 (full-opus, four layers; measured on `ocupilot-ci`): 37 rows, 7 patch, 8 defer, 22 rejected; no high.

- [x] [Review][HIGH] CI run 44851185597 (on `ae4b9b1b3`): two roster tests the new screen broke. (1) `OcuPilot.Test.ScreenRead.TestEveryDeclaredLogSourceReadFieldIsAKeyOfTheLiveRow`: "OcuPilot.Screen.Descriptor.TaskOutput: the declared read answers through the executor => READ.CRITERION: taskId is required" and "all nine production logsource reads are checked … : 10" — the test must supply the task-output read's `taskId` criterion (a test-owned task with an output file) and count ten. (2) `OcuPilot.Test.WireSecurityRead.TestTheTaskSchedulesPairSetIsEnforcedForARealPrincipal`: "the seven task screens …" — the task area now has eight screens with Task output. Update both to the new shape with names read from the instance, keep each test's intent, and write a `mutation:` line for each. The same run's `a11y-structural-invariants` red was the governance settle timeout (DW-1822, Story 21.23's), so the walk never reached the new id-requiring Task output screen: run that spec locally against the rebuilt bundle and confirm the new screen is walked or skipped by rule. [src/OcuPilot/Test/ScreenRead.cls, src/OcuPilot/Test/WireSecurityRead.cls]

- [x] [Review][Patch] (rework, ruling 2026-11-21T01:38Z (1)) `Api/Error.cls` went 991 to 997 of the 1,000-parameter limit that `MonitorError` and `SqlActivityError` record (ERROR #5290): move the six `LOG.TASKOUTPUT.*` parameters to a sibling `TaskError`, code strings unchanged, and restore `PATHROOT`'s "(AD-12, AD-21, AD-39)" [src/OcuPilot/Api/Error.cls:388]
- [x] [Review][Patch] (rework, ruling (2)) The Set mail password dialog states "Current value: (none)" whatever is stored and shows the clear hint twice: no current-value line, the hint once [ui/src/app/areas/os-management/config-settings.page.ts]
- [x] [Review][Patch] A relative stored `OutputDirectory` was judged from the reading process's directory: the vendor stores `../` verbatim and HSCUSTOM normalizes it to the manager directory (measured), so another file than the task writes was read; `TaskOutputHere` now requires an absolute directory, with a relative leg [src/OcuPilot/Port/LogSourcePort.cls TaskOutputHere]
- [x] [Review][Patch] The password's refusal paths (another target at the screen and the confirm, a short caller, a second confirm) were never scanned for the probe; scans added and the confirm refusal pinned to `CONFIG.SETTING.NOTFOUND` [src/OcuPilot/Test/TaskMailPasswordWrite.cls]
- [x] [Review][Patch] `SetPassword`'s vendor-refusal branch ran in no test; `ConfigGateSeam.SendPassword` honours `VendorRefuses`, and `TestAVendorRefusalIsTheWritesFaultWithoutTheValue` pins 400, the logged code and no value [src/OcuPilot/Test/ConfigGateSeam.cls]
- [x] [Review][Patch] The "one byte more" leg wrote two bytes and began on a line boundary; it now writes 65,537 bytes, drops the partial line and asserts its `WriteFile` statuses [src/OcuPilot/Test/TaskOutputRead.cls:247]
- [x] [Review][Patch] The card-row assertion would print a stored probe on a regression; it now compares in process [src/OcuPilot/Test/TaskMailPasswordWrite.cls:286]
- [x] [Review][Defer] Matrix row "Missing pair" names `PORT.ACCESSDENIED`, the shared gate answers `AUTH.NOPRIVILEGE` — deferred: resolved by ruling (3), the code kept and the I/O row amended by the lead
- [x] [Review][Defer] DW-2810: a `*.txt` symbolic link in the manager directory is followed outside it (measured) [LogSourcePort.cls OpenStream] — deferred: wontfix-theoretical, placing a link needs OS access or `%System_CallOut`
- [x] [Review][Defer] DW-2811: a tail window with no line feed answers no rows beside the cut sentence [LogSourcePort.cls ReadWindow] — deferred: wontfix-accepted
- [x] [Review][Defer] DW-2812: `OutputFileIsBinary` is ignored [LogSourcePort.cls TaskOutputRecord] — deferred: wontfix-accepted
- [x] [Review][Defer] DW-2813: `tasks.mail.set` inherits `AuthPassword` as a declared secret, exempted in `DraftRegistry` [src/OcuPilot/Test/DraftRegistry.cls:89] — deferred: wontfix-accepted
- [x] [Review][Defer] DW-2814: a card for a target other than `AuthUser` is refused only at the confirm [Screen/Tool/TaskMailPassword.cls] — deferred: wontfix-accepted
- [x] [Review][Defer] DW-2815: the test's row cleanup swallows SQL failures [TaskMailPasswordWrite.cls:105] — deferred: wontfix-accepted
- [x] [Review][Defer] DW-2236 occurrence: `BackgroundTasksLive` red once on the admin-API compact's Pause (run 992), green on rerun — deferred: existing flake entry

Rejected: `ELSEWHERE` for a name outside the pattern (the matrix row names it); 8-bit inference (measured at Task 0); Base64 leak scans (the product never holds the encoded form; `TaskMailAuditMask` owns the audit row); raw versus decoded body parse (each matches what it reads; the 8-bit mutation went red); criteria admitted port-wide for log sources (as analytics and locale; real only with a second parented log screen); file replaced mid-read (a re-read answers the new file); zero-padded task id (ids come from the task list); 11-digit id answers `READ.CRITERION` (the criterion's declared length, as Task details); secret fallback in the page map (both secret descriptors are mapped); Catch restore order (`TaskOutputRecord` drops references first by contract, `SendPassword` restores on both paths); EXPERIENCE.md row grown in place (spec-named, 21.19 precedent); model- and developer-facing text (sibling style); browser spec's empty-password precondition (AD-35: the value cannot be held); the remaining duplicates of the rows above.

## Fix Pack

Rides the rework the ruling already schedules.

1. A `ui/tools` test pins `TaskError`'s three `REASON*` sentences to `strings.ts` `taskOutputNone`, `taskOutputElsewhere` and `taskOutputAbsent` (the `config-settings.test.mjs` pattern), with its `mutation:` line.
2. A `TaskOutputRead` leg: a `TaskOutputRecord` error armed through `LogSourceFixture` answers 500 with no path in the answer and no file touched.

## Spec Change Log

- 2026-11-20, orchestrator rulings at the spec gate (authoritative over the escalated list in Design Notes):
  - AD-21 note applied in the spine (`fbc419892`).
  - Strings ruled (veto item), four changed: truncated "OcuPilot shows only the end of this file."; empty reuses the shared viewer's "No entries."; elsewhere "OcuPilot reads output files only in the manager directory. Open this one on the server."; not yet written "This task has not written its output file yet. It writes one each time it runs." Kept as proposed: "Open output file", "Task output", "Output directory", "This task does not write its output to a file.", the three prompts, and "Set mail password" with the reused "Value" label and clear hint.
  - `tasks.mail.password` ships enabled on `tasks.mail.set`'s pairs (stricter than the vendor's `%Admin_Manage:USE`, accepted).
  - The output read never echoes the path, in a refusal or in the agent tool's result.
  - The 65,536-byte tail starts at a line boundary, never mid-line; a file under 64 KB is never marked truncated.
  - The 8-bit text is shown as the server stores it, with no encoding guessed; a test carries a non-ASCII byte.
  - Report at finalize whether the read added a Baseline key.
  - Task 0's REST-read stop rule stands: if a REST process cannot read the file, HALT `intent gap` as a question; never widen privilege.

## Review Triage Log

### 2026-11-20 — Review pass

- verdicts: 17 findings — high 0, medium 2, low 10, false 5, maybe-false 0
- findings:
  - `[medium]` `[patch]` `SetPassword`'s body-shape guard had no test; a body without a string `AuthPassword` would clear the stored password — added `TestAMalformedBodyIsRefusedAndClearsNothing` (three shapes, 400 `PORT.VALIDATION`, stored password unchanged); mutation line recorded.
  - `[medium]` `[patch]` the 8-bit byte was pinned at the port only — added `TestAnEightBitByteReachesBothCallersAsStored` (screen and agent show the same character); mutation line recorded.
  - `[low]` `[patch]` the mint for another target had no assertion before its guarded confirm leg — added `AssertStatusOK` on the mint.
  - `[low]` `[reject]` the proposal table scan cannot see stream columns — `StoredText` decodes the streams of the only proposal minted; no harm named.
  - `[low]` `[reject]` leak scans look for the plain probe, not its Base64 form — product code never holds the value to encode it; the vendor's audit row is Story 21.24's mask.
  - `[low]` `[reject]` the config-settings browser spec requires an empty mail password on entry — throwaway only, the value cannot be held without printing it.
  - `[low]` `[reject]` secondary pinning tests lack their own `mutation:` line — Rule 19 asks one demonstrated mutation per AC, and each AC has several.
  - `[low]` `[reject]` the spec's `BackgroundTasksLive` note is stale — the fix edits this spec's prose and the class needs no change.
  - `[false]` `[reject]` the `UNSENTSECRETS` exemption leaves `tasks.mail.set`'s draft unchecked — `TaskMailSettingRules` keeps the "AuthPassword is no setting" leg that guards it.
  - `[low]` `[reject]` the vendor's separator-less join is asserted against a stubbed record only — the join was measured at plan time and the stub names the measured shape.
  - `[low]` `[reject]` the matrix names `PORT.ACCESSDENIED` for a missing pair, and the shared log-source gate answers `AUTH.NOPRIVILEGE` (as `LogSourceDenial` pins for every sibling) — changing one source's code would diverge from its siblings; recorded under Auto Run Result for the matrix wording.
  - `[false]` `[reject]` the viewer reverses the port's newest-first rows — the spec says oldest first as drawn.
  - `[false]` `[reject]` EXPERIENCE.md is edited in the same change — the spec's Batch tasks name that edit.
  - `[low]` `[reject]` several shared files change existing lines — each change is a spec bullet (`Read.cls`, `Registry.cls`, `LogSourcePort`); `childListFor` is covered by the navigation specs, all green.
  - `[false]` `[reject]` the no-read property is shown by test code — product code never reads the value; the tests are the proof.
  - `[low]` `[reject]` the password row action always targets `AuthUser` — a refused other target is pinned at the action route and the confirm.
  - `[false]` `[reject]` the diff cannot show the two batches — they are the two commits.

### 2026-11-21 — Review pass (rework 1, follow-up)

- verdicts: 9 findings — high 0, medium 0, low 8, false 1, maybe-false 0
- findings:
  - `[low]` `[patch]` the agent's step reason for the three refusals (`ReasonForToolCode`, `TaskError.ReasonFor`) had no test — added `TestTheAgentsStepReasonForEachRefusalIsThePublishedSentence`; two mutations observed red and recorded.
  - `[low]` `[patch]` the 500 test's no-text legs had no observed mutation — the status text carried into `Fail`'s reason went red alone; line recorded.
  - `[low]` `[reject]` `task-error.test.mjs` does not pin the code strings across server and client — `TaskOutputRead` and `log-viewer.spec.ts` assert the same literals on each side.
  - `[low]` `[patch]` the agent's tool-code dispatch has no test (intent auditor) — same defect as the first row; closed by it.
  - `[low]` `[reject]` the `ScreenRead` sweep covers only the happy path of the real read — the refusals, order and truncation are `TaskOutputRead`'s, run on the live port.
  - `[low]` `[reject]` the new 500 leg is outside the matrix — it is Fix Pack item 2.
  - `[low]` `[reject]` the missing-pair row is read through the fixture gate in `TaskOutputRead` — `WireSecurityRead` enforces the pair set for a real principal.
  - `[low]` `[reject]` the password write and draft are untouched by this diff — this pass changes only the dialog's presentation, by ruling (2); the write legs closed in earlier passes.
  - `[false]` `[reject]` no browser-level check exists — `task-output`, `tasks`, `config-settings` and `a11y-structural-invariants` ran against the rebuilt bundle, all green.

### 2026-11-21 — Review pass (rework 2)

- verdicts: 8 findings — high 0, medium 1, low 5, false 0, maybe-false 2
- findings:
  - `[low]` `[patch]` the fallback's read position was not pinned (70,000 identical bytes) — the long leg now carries `S` at the window's first byte and `E` at its last; two mutations recorded.
  - `[medium]` `[patch]` a line longer than the window ending in a line feed answered a row ending in that line feed — the fallback strips a trailing line feed and carriage return; a 70,001-byte leg and its mutation recorded.
  - `[low]` `[patch]` the second read in `TestAnUnterminatedFinalLineIsALine` had no status assertion — added.
  - `[low]` `[reject]` a read error inside the fallback has no test — forcing a second-read failure needs a seam the class lacks, and the status handling is the existing window read's.
  - `[low]` `[reject]` the short-file leg and the first long leg pass without the fix — they pin that the existing end-of-file handling keeps serving an unterminated last line (regression guards, as the item asks); the single-line leg is the one red before the fix.
  - `[maybe-false]` `[reject]` the row for a window holding no whole line starts mid-line, against "never a mid-line start" — the one row a window with no line boundary can show; the row is the end of the file's last line, offset at the window's first byte, with the answer truncated and the ruled truncated sentence drawn (decided in-stage; the lead may veto).
  - `[low]` `[reject]` the "No entries." and truncated-sentence rendering is not asserted at the client for this case — `log-viewer.spec.ts` and `task-output.browser-spec.mjs` own the rendering of rows and the truncated line; this pass changes only the rows.
  - `[maybe-false]` `[reject]` other log sources' tails answer no rows for a no-line-feed window — out of this pass's scope by the ruling, and `ReadWindow` is unchanged, so they are as before.

## Design Notes

**Governing ADs:** AD-5, AD-6, AD-8, AD-10, AD-11, AD-12/AD-39, AD-13, AD-14, AD-15, AD-16, AD-21 (Story 21.19's consumer line), AD-22, AD-24, AD-29, AD-35 (the Task Manager mail password), AD-36, AD-37, AD-44, AD-51, AD-52, AD-53, AD-56 (i) and (ii), AD-58, AD-59, AD-60.

**Ledger inbox:** none routed to `21-36-task-output-and-mail-password` (`LEDGER slice` empty). Declined: none.

**Consumed-by / Consumes (Rules 1-2):** `LogSourcePort`'s `taskoutput` source is consumed in this story by Task output and `tasks.taskoutput.read` (AC1); `ConfigPort`'s `PASSWORD` type by Task Manager email's Set mail password and `tasks.mail.password` (AC2). No later story consumes either. Consumes: `LogSourcePort`'s resolve, stream and window helpers (6.13, 16.20, 18.4); the Task details read (6.7); `ConfigPort`'s TaskMail endpoint and `config-settings.page.ts` (21.19); the kernel's secret-only path (7.2, 18.8, 24.13).

**Extends (Rule 2/31):**

- The `taskoutput` source extends `LogSourcePort` beside `integrity` (a source whose `file` is an id), reusing `Resolve`, `DirectlyIn`, `OpenStream`, `Identity` and `ReadWindow`; `ReadWindow` gains a no-decode flag rather than a copy.
- `TaskOutput` copies `LanguageServerActivity`'s declaration (a descriptor is a declaration, not code); the client reuses `DECLARED_READ` and adds a mapper beside `readRowsOf`, because output lines carry no stamp, job or record type.
- `TaskMailPassword` extends `Write` on `AnalyticsSettingKey`'s model; a shared base would couple the analytics port, an Epic 24 file, to the Task Manager's. `config-settings.page.ts` turns its two secret singletons into a per-descriptor map instead of adding a second path.

**Task 0, measured on `ocupilot-ci` (2026-11-20, plan stage; every probe object removed, the mail password restored, proven 1/0 without printing it):**

- Output file: with `OpenOutputFile` 1 the vendor writes `OutputDirectory_OutputFilename` by plain string join (a directory stored without its trailing slash wrote `/durable/iris/mgrOcuP2136out.txt`); each run overwrites the file; lines end in LF; text is 8-bit (`$Char(233)` one byte `E9`, `$Char(8364)` written `?`); with `OpenOutputFile` 0 no file is written. `NormalizeDirectory` answers `/durable/iris/mgr/` with or without the slash. `%SYS.Task.RunLegacyTask` with `ExecuteCode` was the measuring task.
- Task details: `GET /api/admin/v2/task?id=` and the in-process `%Api.Admin.Endpoints.Task.CRUD.TaskToJson` both answer `OpenOutputFile` (boolean), `OutputDirectory`, `OutputFilename`, `OutputFileIsBinary`.
- A process logged in as a user holding only `%Admin_Task:USE` and `%DB_IRISSYS:READ` read the file through `%Stream.FileCharacter` (measured in a Task Manager process). A REST process measured the same way (implement stage, 2026-11-20): a scratch web app on `ocupilot-ci` served a request as a user holding only `%Admin_Task:USE`, `%DB_IRISSYS:READ` and read on the code database (no `%Admin_Operate`), and its `%Stream.FileBinary` link and read of a manager-directory file succeeded (HTTP 200, 18 of 18 bytes). The web app, user, role, class and file were removed. Task 0 passes; the read needs no pair beyond the two the source declares.
- Mail password: `EmailSet("AuthPassword", p)` stores it Base64-encoded and returns 1; `""` clears it; each real change writes one `Modify Task Config.MailAuthPassword` audit row about a minute later, its EventData carrying Base64 values (Story 21.24 masks them); a user holding `%Admin_Manage:USE` and `%DB_IRISSYS:READ` sets it (no `%DB_IRISSYS:WRITE`), one without `%Admin_Manage:USE` is refused `#921` by the vendor.

**Decided in-stage:**

- TM-17 is a sub-screen, not a panel: Task details keeps one read, and the viewer is the shared log-viewer page with one declared read that the agent's tool shares (AD-36). The link shows whenever the record names a file; the port alone decides whether it reads, so the client never judges a location.
- Admission is stricter than "normalizes to" alone: the vendor's join must name the same file, so a directory stored without its separator (whose file the vendor writes beside the manager directory, measured) is refused rather than read as a different file. **Proposed AD-21 note for the runner** (not applied here): append to Story 21.19's consumer line "The file read is the vendor's own join `OutputDirectory_OutputFilename`, which IRIS concatenates without a separator (measured 2026-11-20), so a stored directory that lacks its trailing separator names a file outside the manager directory and is shown, never read."
- The window is the last 65,536 bytes (`LogSourcePort`'s default page) and the declared read's row cap; output is 8-bit, so no UTF-8 decode. An absent file is its own refusal, not empty rows, so the screen can say the task has not written it.
- The password is a write, never a row: Story 21.19's AC2 holds and its two "never the mail password" tests stay as written. The action targets the `AuthUser` row, so the fingerprint covers the account the password signs in with, as the SMTP password's covers `SMTPUsername`; no read ever reports whether a password is stored.
- `tasks.mail.password` ships `true`: a clear is undone by a set, and no data is destroyed. No consequence code (no restart, nothing else changes).
- A `taskId` that is not a whole number is answered as an unknown task (`TASK.ABSENT`), so the viewer adds no refusal string for it.
- The epic context is reused as the runner instructed; the tree was clean at this plan's start, and this stage wrote only its spec (probe scripts stay in its scratch folder).

**Strings, escalated** (proposed in EXPERIENCE.md's style; nothing is used until ruled):

- "Open output file": Task details' link to the viewer (the catalog's TM-17 wording; modeled on "Edit task" and "Activity log").
- "Task output": the viewer's title (modeled on "Activity log", "Task details").
- "Output directory": Task details' field beside the existing "Output file name" (modeled on that string).
- "This task does not write its output to a file.": `LOG.TASKOUTPUT.NONE` (modeled on "This task no longer exists.").
- "OcuPilot reads only an output file in the manager directory, so open this one on the server.": `LOG.TASKOUTPUT.ELSEWHERE` (modeled on `TASK.OUTPUTFILENAME.CLASSICONLY`'s sentence).
- "This task has not written its output file yet. It writes the file each time it runs.": `LOG.TASKOUTPUT.ABSENT` (modeled on "That file is no longer in the manager directory.").
- "The output file is empty.": the empty state (modeled on "This global holds no nodes."; the alternative is reusing "No entries.").
- "OcuPilot shows the last part of this file; the earlier part is cut.": the truncation line (modeled on "OcuPilot shows the first part of this message; the rest is cut.").
- Prompts, Troubleshooting group: "What did this task's last run report?" · "Did this task's output show an error?" · "Summarize this task's output." (modeled on the Activity log's prompts).
- "Set mail password": Task Manager email's toolbar button and the dialog's title, through the dialog's existing `title` input (modeled on "Set password"). The dialog's field keeps its existing "Value" label and "Leave it empty to clear the value." hint, as the Google Maps key's does, so `interop-item-setting-dialog.ts` is not edited.

**Size.** Batch 1 touches about 17 files (two regenerated mirrors among them) plus roster tests, Batch 2 about 14; each is verifiable and committable alone, so the plan keeps one story.

## Verification

Shared surfaces: the Tasks area's built routes (one unlisted sub-screen), Task details' read fields and columns, the registered read and write tool rosters and counts, the governance baseline, the confirm channel's `secretArguments`, Task Manager email's actions, `LogSourcePort`'s source enum, and the EXPERIENCE.md Fixed strings table. The implement stage greps `ui/browser`, `ui/tools`, the `ui/src` specs and `src/OcuPilot/Test` for each old shape; every file it changes joins the `(loop)` set. Every test added or changed passes on a fresh environment, in either order.

Rosters, each run as a full class (`(loop)` when the story changes it, else re-run once in the sweep): `ReadTool` (count and name list: `tasks.taskoutput.read`, `tasks.mail.password`), `ReadDescriptions` (the Tasks group, if the tool joins it), `Descriptor` (`ReadShapes` and the Task details row), `SurfaceCoverage` (a row for `TaskOutput` and for `tasks.mail.password`), `ToolWrite` (the non-AdminPort write count at `ToolWrite.cls:1326`, 147 to 148), `GovernanceBaseline`, `DraftRegistry` (script form and no secret rendered, with the `Port` synthetic target), `ToolRoundTrip` (`REFUSEEMPTY` gains `tasks.mail.password:TOOL.ARGUMENTS`), `TaskDetails`, `TaskMailSettingRead`, `TaskMailSettingRules`, `BackgroundTasksLive` (a tasks holder's verdicts gain Task output), `LogPairs`, `LogSource`; unchanged and re-run: `EndpointCoverage` (no new route), `ScreenGrounding`, `PortGate` (no new port class), `Prohibited`, `TaskMailAuditMask`. Client: `ui/tools/navigation.test.mjs`, `screen-mirror.test.mjs`, `strings.test.mjs`, `ci.test.mjs` (the armed roster).

Pinning tests and the mutation each must show red (the implement stage records each as `mutation: <change> -> <red test>`, reverted and confirmed byte-identical, reloaded):

- AC1: the location check dropped (`ELSEWHERE` never raised) -> `TaskOutputRead`'s elsewhere and no-separator legs red; the tail window read from byte 1 -> its tail-only leg red; the `truncated` flag never set -> its truncation leg red; the details link shown regardless of `OpenOutputFile` -> `details.page.spec.ts` red.
  - mutation: `ELSEWHERE` never raised (`TaskOutputRows`' location test made false) -> `TaskOutputRead` red on `TestALocationOtherThanOneFileInTheManagerDirectoryIsRefused` and `TestBothCallersRefuseAnotherLocationWithoutAPath` (observed, reverted, reloaded).
  - mutation: the vendor's join compare dropped from `TaskOutputHere` -> `TestALocationOtherThanOneFileInTheManagerDirectoryIsRefused` red on the no-separator leg alone (observed, reverted, reloaded).
  - mutation: window read from byte 1 (`tStart` = 1) -> `TestAFileLargerThanTheWindowReadsOnlyItsEnd` red on its newest-row and oldest-row legs (observed, reverted, reloaded).
  - mutation: `pTruncated` always 0 -> `TestAFileLargerThanTheWindowReadsOnlyItsEnd` and `TestTheScreenAndTheAgentToolAnswerTheSameRows` red (observed, reverted, reloaded).
  - mutation: link shown whatever `OpenOutputFile` and `OutputFilename` hold -> `details.page.spec.ts` "Open output file links the viewer only when the record names an output file" red (observed, reverted).
  - mutation: the window decoded as UTF-8 (`TaskOutputRows` passing `pDecode` 1 to `ReadWindow`) -> `TestASmallFileReadsWholeNewestFirstAsStored` and `TestAnEightBitByteReachesBothCallersAsStored` red (observed, reverted, reloaded).
  - mutation: the absolute-directory test in `TaskOutputHere` made `If 0` -> `TestALocationOtherThanOneFileInTheManagerDirectoryIsRefused` red alone (code review; observed, reverted, reloaded).
  - mutation: `showTruncation` ignoring the answer's `truncated`, `LOG.TASKOUTPUT.ELSEWHERE` dropped from `OUTPUT_REFUSALS`, and the store mapping rows with `readRowsOf` -> `log-viewer.spec.ts` red on the truncation, the elsewhere-refusal and the text-alone legs (observed together, reverted).
  - mutation: the six `LOG.TASKOUTPUT.*` parameters moved to `TaskError`; one word of `REASONELSEWHERE` changed -> `ui/tools/task-error.test.mjs` red on its sentence test (observed, reverted).
  - mutation: a `TaskOutputRecord` failure answered as an absent task in `TaskOutputRows` -> `TaskOutputRead.TestARecordThatCannotBeReadAnswersFiveHundredWithoutAPath` red alone (observed, reverted, reloaded).
  - mutation: the task criterion supplied under another name in `ScreenRead.TestEveryDeclaredLogSourceReadFieldIsAKeyOfTheLiveRow` -> that test red on `READ.CRITERION` (observed, reverted, reloaded).
  - mutation: `%DB_IRISSYS:READ` removed from `TaskOutput`'s privileges -> `WireSecurityRead.TestTheTaskSchedulesPairSetIsEnforcedForARealPrincipal` red on the `%Admin_Task` alone entry (observed, reverted, reloaded).
  - mutation: the `LOG.TASKOUTPUT.` branch dropped from `Error.ReasonForToolCode`, and `TaskError.ReasonFor` answering `REASONNONE` for ELSEWHERE -> `TaskOutputRead.TestTheAgentsStepReasonForEachRefusalIsThePublishedSentence` red on each, alone (observed separately, reverted, reloaded).
  - mutation: `LogSourcePort.Fail` carrying the failed status's text as the fault reason -> `TaskOutputRead.TestARecordThatCannotBeReadAnswersFiveHundredWithoutAPath` red alone on its no-text legs (observed, reverted, reloaded).
  - mutation: `TaskOutputRows` answering no rows when the window holds no whole line (the fallback absent) -> `TaskOutputRead.TestAnUnterminatedFinalLineInAFileLargerThanTheWindow` red alone on its single-line leg (observed before the fix, run 1132).
  - mutation: `TaskOutputRows` dropping the last line when the file does not end in a line feed -> `TestAnUnterminatedFinalLineIsALine` and `TestAnUnterminatedFinalLineInAFileLargerThanTheWindow` red, alone (observed, reverted, reloaded; run 1134).
  - mutation: the fallback reading from `tStart - 1` -> `TestAnUnterminatedFinalLineInAFileLargerThanTheWindow` red on its first-byte, last-byte and length legs (observed, reverted, reloaded; run 1168).
  - mutation: the fallback keeping the terminating line feed -> `TestAnUnterminatedFinalLineInAFileLargerThanTheWindow` red on its length and no-line-feed legs, alone (observed, reverted, reloaded; run 1169).
- AC2: `ConfigPort`'s `PASSWORD` branch sends `""` in place of the body's value -> `TaskMailPasswordWrite`'s set leg red; the draft renders the body's value in place of `<AuthPassword>` -> `DraftRegistry.TestNoSecretReachesAnyRenderedScript` red; the page sends `setkey`/`GoogleMapsKey` for Task Manager email -> `config-settings.page.spec.ts` red.
  - mutation: `SetPassword` sends `""` in place of the body's value -> `TaskMailPasswordWrite` red on the set legs of all three of its write tests (observed, reverted, reloaded).
  - mutation: the draft's script renders `""` in place of `<AuthPassword>` (the Snippet's `PASSWORD` branch) -> `DraftRegistry.TestNoSecretReachesAnyRenderedScript` red naming `tasks.mail.password` (observed, reverted, reloaded). The planned form, rendering the body's value, stays green: the draft masks the body before the port renders it.
  - mutation: `SetPassword` logs the password through `LogFault` -> `TaskMailPasswordWrite.TestThePasswordIsSetByBothCallersAndSurfacesNowhere` red on its `messages.log` leg for both probes (observed, reverted, reloaded).
  - mutation: `CLEARABLESECRETS` emptied in `TaskMailPassword` -> `TestAnEmptyPasswordClearsItAndAnotherTargetIsRefused` red on the person's and the agent's clear legs (observed, reverted, reloaded).
  - mutation: `TaskMailPassword.PrivilegePairs` answers the screen's pairs alone -> `TestThePairsAreTheSettingSetsAndAShortCallerIsRefusedBeforeTheVendor` red (observed, reverted, reloaded).
  - mutation: the page's secret map sends `setkey`/`GoogleMapsKey` for Task Manager email -> `config-settings.page.spec.ts` red on two tests (observed, reverted).
  - mutation: `SetPassword`'s vendor-refusal branch made `If 0` -> `TaskMailPasswordWrite.TestAVendorRefusalIsTheWritesFaultWithoutTheValue` red (code review; observed, reverted, reloaded).
  - mutation: `SetPassword`'s body-shape test reduced to `'$IsObject(pBody)` -> `TaskMailPasswordWrite.TestAMalformedBodyIsRefusedAndClearsNothing` red (observed, reverted, reloaded).
  - mutation: the page passing `currentShown` and `consequenceShown` true for the mail password dialog, and the dialog drawing its current-value line whatever `currentShown` holds -> `config-settings.page.spec.ts` (the Set mail password dialog test) and `interop-item-setting-dialog.spec.ts` red (observed, reverted).
- AC3: the `tasks.mail.password` line removed from `Baseline.cls` -> `GovernanceBaseline` and `TaskMailPasswordWrite`'s key leg red.
  - mutation: the `tasks.mail.password` line removed from `Baseline.cls` -> `GovernanceBaseline.TestEveryRegisteredWriteKeyHasABaselineLine` red, and `TaskMailPasswordWrite` red on the key leg and both other write tests, whose confirms read `GOVERNANCE.DISABLED` (observed, reverted, reloaded).

**Commands.** ObjectScript test runs are one call each, never two in one message.

- `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/b708a79b-b765-42ec-adea-dbc87acf6251/scratchpad/e21u/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` (loop) -- expected: `LOADERRORS=0`, no compile error.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<Class>` (loop), once each for `TaskOutputRead`, `TaskMailPasswordWrite`, and every roster class above that the story changes -- expected: green.
- `cd ui && node tools/field-lists.mjs` and `cd ui && node tools/screen-mirror.mjs` (loop) -- expected: regenerated files match their `--check`.
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/` (loop) -- expected: within the 2500/4000 kB budgets.
- `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/<file>.browser-spec.mjs` (loop), one call per file: `task-output`, `tasks`, `config-settings` -- expected: green.
- `cd ui && npm run test:tools` and `cd ui && npm run test:components` (loop) -- expected: green.
- `uv run scripts/check-objectscript.py`, `uv run scripts/test_check_objectscript.py`, `bash scripts/lint-docs.sh` (loop) -- expected: clean.
- The full ObjectScript sweep over `src/OcuPilot/Test` (once, before `dev_complete`), one class per call or batches sized from `ui/tools/ci-timings.json` to about 8 minutes -- expected: green. The full browser suite is left to CI (Rule 29).

## Auto Run Result

Status: done
Blocking condition: none

**Rework 2 (this pass only).** Closed DW-2811 (Review Findings, first item): `LogSourcePort.TaskOutputRows` serves the end of a window that holds no whole line (a last line longer than 64 KB) as one row, offset at the window's first byte, without a terminating line feed or carriage return, the answer truncated; `ReadWindow` and every other log source's tail are unchanged. A last line with no line feed after complete lines, and a short no-line-feed file, were already rows and are now pinned. The two resolved `deferred:` entries are removed (closed in rework 1). Earlier passes closed in the Review Findings.

**Decided in-stage (kept from the first pass).** `childListFor` prefers a non-`log-viewer` child, so Task schedule's History stays its child list beside Task output; the logsource read requires its route criterion as the interop read does; `Registry.CriteriaProblem` and the mirror admit a logsource read's parent route id; `DraftRegistry` gains `UNSENTSECRETS` (`tasks.mail.set=AuthPassword`).

**Decided in-stage (rework 2).** A window with no line boundary has no whole line to show; its row starts mid-line, which the truncated sentence states. Ruled by the orchestrator (2026-11-21): "never a mid-line start" applies only to a window that contains a line boundary; a single final line longer than the window answers its end as one row, marked truncated, with "OcuPilot shows only the end of this file."

**Review.** 8 findings: 3 patched (1 medium, 2 low), 5 rejected (3 low, 2 maybe-false), in the Triage Log. Follow-up review recommended: false (no high patched).

**Verification.** On `ocupilot-ci`: `TaskOutputRead` 17 green (two new tests), `LogSource`, `LogSourceDenial`, `LogSourceFiles`, `LogSourceClock`, `LogSourceRotation`, `LogSourceWire`, `ScreenRead`, `TaskDetails`, `TaskMailPasswordWrite` and the other `Task*` test classes green, one class per call; `npm run test:tools` 2361 green; `check-objectscript.py` 0 problems; `task-output` browser spec green (4) on the rebuilt, redeployed bundle. Four Rule 19 mutations observed red, reverted and reloaded (see Verification). No probe task or file remains.

**Residual risks.** None named beyond the in-stage decision above.
