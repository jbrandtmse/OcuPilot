---
title: 'Story 16.4: Task export and import'
type: 'feature'
created: '2026-09-29'
status: 'done'
baseline_revision: '99fa0b4e6a22b8ac4351e94b375b9a3ab6da1464'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-16-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** A developer-administrator who gets a task's schedule right on one instance has to type it in again on the next. The classic portal can export a task to a server file and import that file, but OcuPilot cannot, and its file fields may never take a caller path (AD-21).

**Approach:** Task schedule gains **Export** (the selected task, written to a new server file) and **Import** (every task in a server file). Each opens a dialog that names the file with the shared server path picker as an allowed root plus a relative name. Two write tools, `tasks.schedule.export` and `tasks.schedule.import`, each with two callers (AD-53), reach a new `Port/TaskTransferPort`. That port resolves the file through `Port/PathPort` and calls the vendor's own `%SYS.Task.ExportTasks` / `ImportTasks`, so a file the classic portal writes imports here and the reverse also holds.

## Boundaries & Constraints

**Always:**

- **File naming (AD-21's sixth case).** The file travels only as `root` (an allowed directory, exactly as the Allowed directories read answers it) and `path` (a relative name). Nothing else names it.
  - The tool resolves it through `PathPort.Resolve` at the mint and again at the write.
  - Export uses kind `file` with `pOverwrite` 1: the export tool declares that it overwrites, as a constant in the port and never a caller value, so an existing file at the name is replaced, while PathPort still refuses a directory under the name (`PATH.EXISTS`), the instance's files (`PATH.INSTANCE`) and OcuPilot's served files (`PATH.SERVED`). [AMENDED 2026-09-29, spec gate, orchestrator direction: export declares `pOverwrite`]
  - Import uses kind `source`.
  - Refusals carry `detail.violations` on the `root` / `path` fields, and the picker draws each on its field.
  - The resolved path goes only to the vendor call. It never appears in a settable field, a diff, a ledger row or an answer.
- **Privileges.** Both tools' pairs are the Task schedule's (`%Admin_Task:USE`, `%DB_IRISSYS:READ`), plus PathPort's `%Admin_FileSystemAccess:USE`, plus `Gate.WithClassicPages` over `CLASSICPAGES` `%cspapp.op.utilsystaskaction`.
  - Both callers refuse a caller missing any pair by name, before any port call (AD-8, AD-29).
  - `TaskTransferPort` checks its own `PAIRS` first. PathPort's gate still runs inside `Resolve`.
- **Export.**
  - It writes one task, named by the target id, with `ExportTasks($ListBuild(id), <resolved>, "-d")`.
  - Before the call it refuses a relative name whose parent directory does not exist: `TASK.EXPORT.DIRECTORY`, a violation on `path`.
  - If the vendor call fails and the name was absent at the write's resolve, it deletes any file now standing at that name, which is then the call's own. A file that existed before the call is left as the call left it.
  - The export dialog's note and the export proposal card's consequence line (AD-10) both say "A file already at this name is replaced."
- **Import.**
  - It reads the file's tasks first, with `%XML.Reader` correlated to `%SYS.Task`, saving nothing.
  - It refuses the whole file before the vendor call when any task would fail. Nothing is imported in that case.
  - Only then does it call `ImportTasks(<resolved>, "-d", 0)`.
  - A task already on the instance (same `JobGUID`, the vendor's own key) is skipped, as the vendor skips it.
  - A file whose every task is present is refused `TASK.IMPORT.PRESENT`.
- **The reviewed `tasks` summary.**
  - For the agent, the mint computes it on the instance: `Name (NAMESPACE)` for each task the import will create, in file order, joined by `; `.
  - It is a composed argument shown on the card and stored in the payload.
  - At the write the port recomputes it from the file and refuses `TASK.IMPORT.CHANGED` on a mismatch.
  - The screen caller sends no `tasks`, so no comparison is made for it.
- **Secrets and untrusted content.** Settings are never read into OcuPilot, previewed, returned, logged or stored (AD-35). Task names and descriptions read from a file are untrusted data (AD-11, AD-60).
- **Shared-state bookkeeping.**
  - Each new write key joins `Kernel/Governance/Baseline.cls`, enabled.
  - Each tool has a port `Snippet` for every `Invoke` branch (AD-59).
  - Every roster that counts tools, ports, write types or classic pages is bumped for these two tools only (additive; Epic 18 shares them).
- **Copy.** New strings go into EXPERIENCE.md's Fixed strings in place, which stays at 993 lines, and into `strings.ts`.
- **Screens.** Task schedule keeps its three suggested prompts. Both dialogs pass the DW-1337 structural walk in both themes.

**Never:**

- Overwrite a directory, an instance file or a served file (PathPort refuses each), or write any file from the import.
- Create a directory.
- Accept a path in any other form.
- Edit `Port/PathPort.cls`.
- Edit `Port/AdminPort.cls` beyond the one `MUTATINGTYPES` append.
- Walk `^SYS("Task")` or save a `%SYS.Task` ourselves.
- Import a subset of a file the person did not choose.
- Add a new entity type or a new screen.
- Hand-edit `screens.generated.ts`.
- Call `$System.Security.Login` in product code.
- Run a test or a configuration-changing probe on `ocupilot`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Export | Selected task; allowed root; new name whose directory exists | The file holds the vendor's `<Tasks><Task>…</Task></Tasks>` for that task; the status line reads "Exported <task> to <path>."; the list re-reads | none |
| Export onto an existing file | That name is an existing file | The file is replaced by the task's export; the done line as for Export | none |
| Export onto a directory | That name is a directory | Nothing written | 400 `PATH.EXISTS` on `path` |
| Export, missing directory | `sub/t.xml` where `sub/` is absent | Nothing written | 400 `TASK.EXPORT.DIRECTORY` on `path` |
| Instance or served location | A name directly in the manager directory; a name under `csp/ocupilot/` | Nothing written or read | `PATH.MANAGER` / `PATH.SERVED` on `path` |
| Root off the list | A `root` the allow-list does not answer | Nothing | 400 `PATH.ROOT` on `root` |
| Export of a gone task | Task deleted after it was selected | Nothing | 404, as the fresh read answers it |
| Import | An export file whose tasks are absent | Each task is created by the vendor; the list re-reads; the status line reads "Imported the tasks in <path>. Any already on this instance were skipped." | none |
| Round trip | Export, delete the task, import | Every stored property of the re-imported task equals the exported one's except its ID | none |
| Some tasks present | A file of three tasks, one with a `JobGUID` already here | Two created, one skipped; the agent's `tasks` names the two | none |
| All present | Every `JobGUID` already here | Nothing | 409 `TASK.IMPORT.PRESENT` |
| Missing file / a directory | `path` names nothing, or names a directory | Nothing | 400 `PATH.NOFILE` on `path` |
| Not a task export | Malformed XML, another root element, or `<Tasks/>` | Nothing | 422 `TASK.IMPORT.FILE` |
| A task that cannot be created | Any task in the file: its namespace is unreadable; its class is absent there; it lacks the type's declared privilege; its RunAsUser is unknown or disabled, or is another user and the caller lacks `%Admin_Secure:USE`; or its name is held by a task with another `JobGUID` | Nothing imported, for any position in the file | That rule's existing code and reason: `TASK.NAMESPACE.UNKNOWN`, `TASK.TASKCLASS.UNKNOWN`, `TASK.TASKCLASS.PERMISSION`, `TASK.RUNASUSER.UNKNOWN` / `.DISABLED` / `.SECURE`, or `TASK.NAME.TAKEN`, with `detail.task` naming the first refused task |
| File changed after the proposal | The agent's proposal, then the file rewritten with other tasks | Nothing | 409 `TASK.IMPORT.CHANGED` |
| Missing pair | A caller without `%Admin_FileSystemAccess:USE` (or `%Admin_Task:USE`), either caller | Nothing; no port call | 403 `AUTH.NOPRIVILEGE` naming the pair |
| Password setting | Export of a `%SYS.Task.DiagnosticReport` holding `SMTPPass` | Exported as the vendor writes it; the dialog's note says a password setting is encoded, not encrypted; no card, ledger, answer or log carries it | none |

</intent-contract>

## Code Map

**Server** (`src/OcuPilot/`):

- `Port/PathPort.cls` (Epic 18's, consume only):
  - `Resolve` :266, with the contract at :234-265. Kinds `KINDFILE` :62 and `KINDSOURCE` :66; `PAIRS` :47.
  - Refusals come from `Violation` :647, which fills `detail.violations` on the fields the caller names. `Roots` :153.
- `Port/TaskPort.cls` :35 extends AdminPort. It is the new port's superclass.
  - `Invoke` :77: a `Task.CRUD` GET is completed with INFO's `Type`.
  - `WithholdSettings` :175, `SnippetForm` :261, `Snippet` :271.
- `Port/BackgroundTaskPort.cls` is the precedent for a pseudo-endpoint port over vendor `%SYS` classes:
  - `ENDPOINT` :34, `PAIRS` :60.
  - `Invoke` :89: other endpoints go to super; then the gate (:97); a caller body is refused (:101).
  - `Gate` :130, `GateRefusal` :304, `PortalControl` :400 (in `%SYS`, AD-16).
  - `SnippetForm` :429 and `Snippet` :440 use `AdminPort.ObjectScriptStep` :2797.
- Composed arguments into a port (AD-51): `AuditCopy.cls` (whole file, 164 lines), `AuditPort` `COMPOSEDTYPES` :55 and `Body` :347, `ProcessPort` `COMPOSEDTYPES` :71.
- `Screen/Tool/Write.cls`:
  - `SCREENACTIONS` :167 and `SCREENVALUES` :217. The grammar is `<action>=<name>:<name>`, parsed by `ScreenActionValueNames` :579.
  - `READANSWERS` :180, `FINGERPRINTSUBJECT` :97, `PRECONDITIONFIELD` :105, `PORTCLASS` :114, `CLASSICPAGES` :124, `CHANGEACTION` :134.
  - `PortQuery` :440 is called by the confirm before its re-read and before the write. The mint's read and the screen route's read carry the id only (`Mint.cls:166`, `ScreenAction.cls:255`).
  - `StateDiff` :486, `MintClass` :495, `ScreenActionDelta` :607, `ArgumentProblem` :809.
  - `View` :759 is Final: it runs schema validation (`additionalProperties: false`) and then `MintClass().Mint`.
- `Kernel/Proposal/Mint.cls`:
  - `Mint` :131. The fresh read is at :166, and a non-create requires the target present.
  - `Merge` :534 refuses an argument its fresh read does not answer (:553).
- `Kernel/Proposal/Confirm.cls` `FingerprintMatches` :624. A non-create re-reads with the canonical id (:641), which `EntityRef` folds for `task:integer` (`RULEINTEGER`: a non-integer is folded to lower case).
- `Screen/Tool/BackgroundTaskMint.cls` is the precedent for a `MintClass` that rewrites the id before `##super`.
- `Kernel/Proposal/Prohibited.cls`:
  - `Prohibits` :907; the `task` arm is `ReviewedFewOnly` (:1018, :1693).
  - `SkippedFields` :3434 skips the fingerprint-subject names, which is why every composed argument belongs in the subject.
- `Screen/Tool/TaskDelete.cls` is the precedent for a task target. It declares `IdArgument` "Id", `PORTCLASS` TaskPort, subject `Name,TaskClass,NameSpace,Type`, and `PRECONDITIONFIELD` Name.
- `Area/Task/TaskRules.cls` holds the create's per-task rules and codes:
  - `IsReadable` :1078; `TypeSettings` :890 (known class); `Permitted` :996 (Private; `%SYS.Task.Definition.CheckPermission`); `RunAsViolations` :513 (Private); `NameTaken` :1046.
  - The port must not call `Area/`, because the dependency direction runs Registry to Ports. The port repeats these checks with vendor calls.
- `Api/ScreenAction.cls`:
  - `Handle` :76 and `Resolve` :139. The action must be in `RowActionIds` (:151), and `id` must be non-empty (:191).
  - `Values` :453 requires every declared name as a non-empty string. `Run` :217. `Fault` :530 passes the port's `detail` unchanged.
- `Api/Error.cls`: the PATH codes are at :387-462. The TASK codes start at :3685; `TASKRUNASUSER*` are at :3850-3862. The task validation roster is at :3976.
- `Screen/Descriptor/TaskScheduleList.cls`: `privileges` :91, `rowActions` :99, `classicPage` :108.
- `Kernel/Governance/Baseline.cls`: XData `Keys` :17-115. The 16.5 and 16.6 keys are appended at :112-113.

**Client** (`ui/src/app/`):

- `shell/server-path-picker.ts`, selector `app-server-path-picker`:
  - Inputs: `store` (`AllowedDirectoriesStore`, `core/allowed-directories.ts:82-109`) :105, `kind` `'file'` :108, `root` :111, `path` :114, `rootReason` :117, `pathReason` :120, `idPrefix` :123.
  - `changed` emits `{root, path}` :126. It is controlled and checks nothing.
- `areas/os-management/namespace-list.page.ts:49-175` is the precedent for a page that wraps `<app-list-page/>`, registers a declared action itself and sends it through `ScreenActionHandler.sendFor`.
- `shell/screen-action-handler.ts`:
  - `UNDRAWN_ACTIONS` :185-195.
  - `send` :795-845: it puts only the envelope's `reason` on the sink.
  - `sendFor` :853, `continued()`.
- `core/violations.ts`: `violationsOf` :35, `reasonForField` :67.
- Screen-level actions are Story 16.3's pattern:
  - `core/screen-actions.ts`: ids :29-40, `ACTION_LABELS` :72-94, `DESCRIPTOR_ACTION_LABELS` :104-142, `register` :155.
  - `shell/command-bar.ts` :317-321 and :704-717 (never held by selection), and `hasContent` :627.
  - `shell/command-box.ts` :497-499.
- `shell/dialog.ts` (`app-dialog`); `shell/broadcast-dialog.ts` (inline `role="alert"` refusal); `shell/screen-outlet.ts` `DESCRIPTOR_PAGES` :117-157.
- `core/strings.ts`: `actionImport` :1575 and the `pathPicker*` keys :805-815. The object ends at `} as const;` :3707.
- `ui/tools/strings.test.mjs` pins values unique (:738) and each citation's line (:787).

**Rosters:**

| Roster | Where |
|---|---|
| `Test/ReadTool.cls` | :93 count 159 (94 writes), sorted list at :94 |
| `Test/SurfaceCoverage.cls` | XData `Coverage` :54 |
| `Test/ToolRoundTrip.cls` | `REFUSEEMPTY` :44 |
| `Test/ToolWrite.cls` | :1220-1325; `AdminPort.MUTATINGTYPES` :329 and `BODYLESSTYPES` :345 or the port's `COMPOSEDTYPES`; mirror `Test/PortFixture.cls:21` |
| `Test/PortGate.cls` | `ROSTER` :28 |
| `Test/DraftRegistry.cls` | :116, :155, :208; `TYPEDTARGETIDS` :56 |
| `Test/DraftPorts.cls` | `TestTaskPort` :160 as precedent |
| `Test/ClassicPageGate.cls` | `OWNPAIRS` :51, count :120 (10) |
| `Test/MappingDescriptor.cls` | `CLASSICROSTER` :16, where it lists every declarer |
| `Test/Prohibited.cls` | :392-398 composed settable counts |
| `Test/GovernanceBaseline.cls` | :16 |
| `Test/TaskScheduleActions.cls` | :99 |
| `ui/tools/screen-mirror.test.mjs` | :1046-1050 |
| `ui/tools/screen-actions.test.mjs` | :110-126 |
| `scripts/ci-throwaway.sh` | `OCUPILOT_ALLOW_PRINCIPALS` :196-245 and `OCUPILOT_ALLOW_TASK_CONTROL` :306-316, checked by `ui/tools/ci.test.mjs:1818-1930` |

- Test precedents:
  - `Test/ProcessBroadcastLive.cls`: `EnsurePrincipal` :406, the screen caller `Act` :379, and the agent via `ProposalFixture.SeedTurn` → `MintClass.Mint` → `Confirm.Confirm` at :205-235.
  - `Test/TaskProbe.cls`: `PREFIX` :10, `RemoveAll` :36.
  - `Test/TaskWire.cls`: both arming variables at :20-23.
  - `Test/PathPortFixture.cls`.
- Browser precedents:
  - `permissions-effective.browser-spec.mjs`: `assertThrowaway` :212.
  - `process-broadcast.browser-spec.mjs:116-143`: the structural wrapper.
  - `namespace-mappings.browser-spec.mjs:458`: a dialog walk.
- Tasks side-bar pins: `tasks.browser-spec.mjs:1025` and `background-tasks.browser-spec.mjs:167`. They are unchanged, because no screen is added.

**Docs:** EXPERIENCE.md `:173` (dialogs), `:319` (Task schedule strings row), `:603` (command-bar).

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Port/TaskTransferPort.cls` (new; extends `TaskPort`; the AD-27 named case) -- the one class naming the vendor's export, import and task-file reader.
  - Parameters:
    - `ENDPOINT` "TaskTransfer";
    - `PAIRS` "%Admin_Task:USE,%DB_IRISSYS:READ,%Admin_FileSystemAccess:USE";
    - `IMPORTID` "import";
    - `COMPOSEDTYPES` "TaskTransfer/EXPORT,TaskTransfer/IMPORT" (the `ProcessPort` grammar).
  - `Invoke`: any other endpoint goes to `##super`. Then the gate. A caller body is refused. The types follow.
  - Read `TASK`: `##super`'s `Task.CRUD` `GET` for `id`, plus `root` and `path` answered `""`.
  - Read `SCHEDULE`: `{root:"", path:"", tasks:""}` when `id` equals `IMPORTID` without regard to case; otherwise 404.
  - Read `PREVIEW` (`root`, `path` in the query): `Locate`, then `Preview`. Answers `{tasks, count, present}`, or the refusals.
  - Write `EXPORT`:
    1. `Locate` the file.
    2. Refuse a missing parent directory with `TASK.EXPORT.DIRECTORY`.
    3. Refuse a gone task with 404.
    4. Call `ExportTasks` in `%SYS` (AD-16), inside `Try`.
    5. On any failure, if the name was absent at this write's resolve, delete a file now standing at that name; then answer the normalized fault (AD-39). The raw text is logged only.
    6. On success, answer `{root, path}`.
  - Write `IMPORT`:
    1. `Locate` the source.
    2. `Preview`.
    3. Refuse `TASK.IMPORT.PRESENT`.
    4. When the query carries a non-empty `tasks` and it differs from the recomputed summary, refuse `TASK.IMPORT.CHANGED`. The screen caller's payload holds `tasks` `""`, so it is never compared.
    5. Call `ImportTasks(<resolved>, "-d", 0)` in `%SYS`.
    6. Answer `{imported, skipped}`, counted by `JobGUID` afterwards.
  - `Locate(pType, pRoot, pPath, .pResolved, .pHttpStatus, .pFault)`: `PathPort.Resolve(pRoot, pPath, file` (for EXPORT, `pOverwrite` 1) `| source` (for IMPORT)`, "root", "path", …)`, through an overridable `PathPortClass()` seam.
  - `Preview`: the file's tasks through `%XML.Reader` `Correlate("Task","%SYS.Task")`. It never touches `Settings`.
    - Zero tasks, or a parse fault, is `TASK.IMPORT.FILE`.
    - For every task, the matrix's rules are applied through vendor calls:
      - `%SYS.Namespace.Exists` plus read permission on the namespace;
      - the class compiled and extending `%SYS.Task.Definition` in that namespace (explicit save and restore);
      - `%SYS.Task.Definition.CheckPermission`;
      - the RunAsUser exists and is enabled in `%SYS`, and `%Admin_Secure:USE` is held when it is not `$Username`;
      - a name held by another `JobGUID`.
    - The first failure answers that code with `detail.task`.
    - Presence is by `JobGUID`, read through the vendor's class or bound SQL. Use `%ExecDirectNoPriv` after the gate if SQL privilege refuses a least-privileged caller (AD-29's `LogSourcePort` precedent).
    - The summary covers the absent tasks.
  - `SnippetForm` answers `objectscript` for `TaskTransfer`. `Snippet` renders `ExportTasks($ListBuild(<id>), "<root><path>", "-d")` and `ImportTasks("<root><path>", "-d", 0)`; any other endpoint goes to `##super`.
  - The vendor calls sit behind overridable seams, so a fixture can observe them and deny them.
- `src/OcuPilot/Screen/Tool/TaskExport.cls` (new) -- `tasks.schedule.export`:
  - `DESCRIPTORCLASS` TaskScheduleList, `PORTCLASS` TaskTransferPort, `READTYPE` TASK, `WRITETYPE` EXPORT, `SENDSBODY` 0.
  - `CHANGEACTION` "updated", `DESTRUCTIVE` 0.
  - `SCREENACTIONS` "export", `SCREENVALUES` "export=root:path".
  - `READANSWERS` "Name,TaskClass,NameSpace,Type,root,path", `FINGERPRINTSUBJECT` "Name,TaskClass,NameSpace,root,path", `PRECONDITIONFIELD` "Name".
  - `CLASSICPAGES` "%cspapp.op.utilsystaskaction".
  - `Endpoint`, `IdArgument` "Id", `IdParam` "id". `SettableFields` `root,path`.
  - `InputSchema` adds `root` and `path` (required, with descriptions). `DESCRIPTION` is under Design Notes.
  - `ArgumentProblem` checks that both are non-empty strings. `ScreenActionDelta` turns the values into those arguments with no resolution, so the write's `PATH.*` fault reaches the picker.
  - `PortQuery` copies `root` and `path`. `StateDiff` returns no rows.
  - `PrivilegePairs`: the screen's pairs, plus `%Admin_FileSystemAccess:USE`, then `Gate.WithClassicPages`. `MintClass` is `TaskExportMint`.
- `src/OcuPilot/Screen/Tool/TaskExportMint.cls` (new) -- the port's `Locate` for the file, plus its missing-directory refusal; on failure it answers the port's own status and fault, so the agent reads `PATH.*` codes. Then `##super`.
- `src/OcuPilot/Screen/Tool/TaskImport.cls` (new) -- `tasks.schedule.import`, with the same shape except:
  - `READTYPE` SCHEDULE, `WRITETYPE` IMPORT, `CHANGEACTION` "created".
  - `SCREENACTIONS` "import", `SCREENVALUES` "import=root:path".
  - `READANSWERS` and `FINGERPRINTSUBJECT` "root,path,tasks", `PRECONDITIONFIELD` "path".
  - `SettableFields` `root,path,tasks`. `InputSchema` never advertises `tasks`, so `additionalProperties: false` refuses it from the agent.
  - The `Id` description says to send the literal `import`.
- `src/OcuPilot/Screen/Tool/TaskImportMint.cls` (new):
  1. Replace the id with `IMPORTID` whatever was sent.
  2. Call the port's `PREVIEW` with `root` and `path`, and answer its fault unchanged.
  3. Set `tasks` to the preview's summary.
  4. Call `##super`.
- `src/OcuPilot/Screen/Descriptor/TaskScheduleList.cls` -- append `{"id": "export", "selfProtection": ""}` and `{"id": "import", "selfProtection": ""}` to `rowActions`. The rest is unchanged, the three prompts included.
- `src/OcuPilot/Port/AdminPort.cls` -- append `TaskTransfer/EXPORT,TaskTransfer/IMPORT` to `MUTATINGTYPES` (:329), as `BackgroundTask/*` and `Process/BROADCAST` are there. This is add-only in a list Epic 18 shares, and nothing else in the class changes.
- `src/OcuPilot/Api/Error.cls` -- add each code with its reason (server-only), beside the other `TASK.*` codes. Do not add them to `TaskViolationCodes` (:3976), which lists the task form's field codes:
  - `TASK.EXPORT.DIRECTORY` (400, one violation on `path`): "There is no such directory under that allowed directory."
  - `TASK.IMPORT.FILE` (422): "This file is not a task export, or it holds no task."
  - `TASK.IMPORT.PRESENT` (409): "Every task in this file is already on this instance."
  - `TASK.IMPORT.CHANGED` (409): "The file's tasks changed after the import was proposed."
- `src/OcuPilot/Kernel/Governance/Baseline.cls` -- append `"tasks.schedule.export": true` and `"tasks.schedule.import": true` after :113.
- **Server tests** (new; each class at most 500 lines; `OcuP164` probe prefix; each removes what it made and fails if any is left):
  - `Test/TaskTransferFixture.cls`: a port subclass with a pair-deny seam and vendor-call observers.
  - `Test/TaskTransfer.cls` (armed `OCUPILOT_ALLOW_TASK_CONTROL`):
    - Every matrix refusal row, as port legs and through both tools' arguments. Crafted XML files are written into a probe subdirectory of `PathPort.Roots`' first root.
    - The one-bad-task-anywhere leg, with no task created.
    - The export-onto-an-existing-file leg: the file is replaced by the task's export (and a directory under the name is refused `PATH.EXISTS`).
    - The summary's shape.
    - Both snippets.
  - `Test/TaskTransferLive.cls` (armed `OCUPILOT_ALLOW_PRINCIPALS` and `OCUPILOT_ALLOW_TASK_CONTROL`), using a least-privileged principal holding exactly the three pairs plus the code-database read:
    - The screen caller over HTTP: export, delete, import, then every stored property compared except the ID.
    - The agent caller: mint and confirm for both, including `TASK.IMPORT.CHANGED`.
    - A principal without `%Admin_FileSystemAccess:USE`: 403 on both callers, with no file written.
    - Vendor parity: an `ExportTasks`-written file imports through the tool, and the tool's file imports through `ImportTasks`.
    - Auditing on: the import writes `%System/%System/ConfigurationChange` per created task, and the export writes none.
- **Server rosters** -- the Code Map's list. Each is bumped for the two tools, their port and their write types only:
  - `ReadTool` becomes 161 and 96, with `tasks.schedule.export` and `.import` in sort order.
  - `SurfaceCoverage` gains two rows; `ToolRoundTrip` gains two entries.
  - `ToolWrite` and `PortFixture` gain the port's types.
  - `PortGate` gains `TaskTransferPort`; `DraftRegistry` and `DraftPorts` (a `TestTaskTransferPort`) are updated.
  - `ClassicPageGate` becomes 12; `Prohibited` gets composed counts 2 and 3; `GovernanceBaseline` and `TaskScheduleActions` are updated.
  - `ci-throwaway.sh` and `ci.test.mjs` arm the two new test classes.
- `ui/src/app/areas/tasks/task-schedule.page.ts` (new, registered in `DESCRIPTOR_PAGES`) -- follows the Copy mappings shape:
  - It wraps `<app-list-page/>` and a `role="status"` line.
  - It registers `export` on `TASK_SCHEDULE`, which draws as a row action held by "Select a row first".
  - It registers the screen-level `TASK_IMPORT_ACTION_ID`, which is never held.
  - It opens one dialog at a time and sends through `sendFor(TASK_SCHEDULE, 'export', <Id>, {root, path}, sink)` or `sendFor(TASK_SCHEDULE, 'import', 'import', {root, path}, sink)`.
  - On a refusal the dialog stays open:
    - A `root` / `path` violation lands on the picker (`reasonForField`).
    - Any other reason shows inline (`role="alert"`). With `detail.task`, it reads `taskImportRefused`.
  - On success the dialog closes and the status line reads the done string.
- `ui/src/app/areas/tasks/task-export-dialog.ts` and `task-import-dialog.ts` (new) -- `app-dialog` titled `taskExportTitle` (the selected row's name) or `taskImportTitle`.
  - Each embeds `app-server-path-picker kind="file"` over an `AllowedDirectoriesStore` loaded when it opens.
  - The export dialog shows `taskExportNote`. Buttons: `taskExportAction` or `actionImport`, and `actionCancel`.
- `ui/src/app/shell/screen-action-handler.ts`:
  - `UNDRAWN_ACTIONS[TASK_SCHEDULE] = [EXPORT, IMPORT]`.
  - `sendFor` takes an optional `ActionSink`.
  - Add `lastRefusal(): {reason, violations, detail} | null`, set by each `send` from `violationsOf` and the envelope, and read after `sendFor` as `continued()` is.
- `ui/src/app/core/screen-actions.ts`, `shell/command-bar.ts`, `shell/command-box.ts`:
  - `TASK_IMPORT_ACTION_ID = 'task-import'`, labeled `actionImport` in `ACTION_LABELS`, drawn and listed exactly as `PERMISSION_CHECK_ACTION_ID` is.
  - `DESCRIPTOR_ACTION_LABELS[TaskScheduleList]`: `export` → `taskExportAction`.
- `ui/src/app/core/strings.ts` -- add the Design Notes keys, each citing `EXPERIENCE.md:319`. Then regenerate `core/screens.generated.ts` with `node tools/screen-mirror.mjs`.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` -- the three in-place edits under Design Notes, leaving `wc -l` at 993.
- **Client tests:**
  - New `areas/tasks/task-export-dialog.spec.ts`, `task-import-dialog.spec.ts` and `task-schedule.page.spec.ts`: the request body, a violation on each picker field, an inline refusal, the done line, one dialog at a time.
  - `shell/command-bar.spec.ts` and `command-box.spec.ts`: Import is drawn and listed only where registered, never held by selection.
  - `shell/screen-action-handler.spec.ts`: `lastRefusal` and the undrawn pair.
  - `ui/tools/screen-mirror.test.mjs:1046-1050` and `screen-actions.test.mjs`.
- `ui/browser/task-transfer.browser-spec.mjs` (new; `ocupilot-ci` only, `assertThrowaway`) -- a probe task with a distinctive schedule, then:
  - Export through the dialog.
  - Exporting again onto the same name replaces the file (the note's replace sentence is shown); a name that is a directory reads `PATH.EXISTS`'s reason on the file field.
  - Delete the task, then Import through the dialog; the list shows it and its Task details show the same schedule.
  - The DW-1337 structural walk of both dialogs at wide light, narrow light and wide dark.
  - Cleanup of the task, the file and the directory.
- **Bundle:** re-base `maximumWarning` and the `angular-json.test.mjs` literal under DW-1166 only if the build exceeds 2217kB. HALT `blocked` above 3800kB.

**Acceptance Criteria:**

- **AC1 (export).** Given a task selected on Task schedule and a relative name under an allowed directory (new, or an existing file, which is replaced), when Export is confirmed, then:
  - the file exists at that name and holds `<Tasks>` with exactly that task in the vendor's format;
  - the status line reads "Exported <task> to <path>.";
  - no task changed.
- **AC2 (round trip).** Given that file and an instance holding no task with its `JobGUID` (the exporting instance after the task is deleted, which is what another instance presents to the import), when Import is confirmed with it, then:
  - the task is listed again;
  - every stored property equals the exported one's except its ID;
  - importing the same file again is refused `TASK.IMPORT.PRESENT` with nothing added.
- **AC3 (vendor format).** Given a file written by `%SYS.Task.ExportTasks` (the bytes the classic portal's Export writes, measured), when it is imported through either tool caller, then it imports. Given a file the export tool wrote, `%SYS.Task.ImportTasks` (what the classic Import calls) imports it.
- **AC4 (no path from a caller).** Given the picker, when either dialog sends, then:
  - the request carries only `root` and `path`, resolved through `PathPort` at the write, and at the mint too for the agent;
  - each `PATH.*` refusal and `TASK.EXPORT.DIRECTORY` lands on its picker field, and nothing is written.
- **AC5 (agent).** Given a scripted or live turn, when the agent proposes `tasks.schedule.export` or `tasks.schedule.import` and the user confirms, then the file or the tasks result as they do on the screen:
  - the import card shows `root`, `path` and `tasks`;
  - a file rewritten between mint and confirm is refused `TASK.IMPORT.CHANGED`.
- **AC6 (all or nothing).** Given a file in which any one task breaks a matrix rule, when it is imported by either caller, then no task is created, and the refusal carries that rule's code and `detail.task`. The dialog reads "Nothing was imported: task <task> cannot be created here. <reason>".
- **AC7 (privilege and governance).** Given a caller missing `%Admin_FileSystemAccess:USE` or `%Admin_Task:USE`, when either caller sends, then it is refused 403 naming the pair before any port call. Given either key disabled, the agent is refused and the screen still acts.
- **AC8 (copy and structure).** Given this story's strings, then:
  - they are in EXPERIENCE.md's Fixed strings and `strings.ts`, pinned by `npm run test:tools`, with EXPERIENCE.md at 993 lines;
  - both dialogs pass the structural walk in both themes.
- **AC9 (integration).** Given `ocupilot-ci`, when `TaskSchedulePage`'s dialogs (consumer) send through `POST /api/ocupilot/screens/tasks.schedule/action` to the tools over `TaskTransferPort`, then the Task schedule re-reads and shows the imported task.

## Spec Change Log

- 2026-09-29, spec gate (lead): export overwrites. The plan made export non-overwriting (`pOverwrite` 0); the orchestrator's direction for this story is `kind=file` with `pOverwrite` declared, and DW-1777's fix and Story 18.3's spec already count 16.4 as an overwriting consumer. Amended: Boundaries (file naming, the vendor-failure cleanup, the replace line, Never), the matrix's existing-name rows, the port's EXPORT step 5 and `Locate`, the browser spec's existing-name step, AC1, Decision 2, the export tool description, the Fixed strings (`taskExportReplaces`), spine change (e) and the AC4 mutation. The spine's (a)-(e) were written at this gate (AD-15, AD-21, AD-27, AD-44, AD-51, AD-53).

## Review Triage Log

### 2026-09-29 — Review pass

- verdicts: 23 findings — high 0, medium 6, low 14, false 3, maybe-false 0
- findings:
  - `[medium]` `[patch]` verification-gap: `ImportTasks`' `runPastTasksTomorrow` 0 was unpinned, since every probe started in the future — added `TaskTransferLive.TestAPastStartTaskIsScheduledAsTheVendorSchedulesIt`, which holds a past-start import equal to the vendor's own with 0; passing 1 turns it red.
  - `[medium]` `[patch]` verification-gap: the port's gate was tested only for `%Admin_FileSystemAccess:USE` — `TestTheGateRefusesAMissingPairBeforeAnyCall` now denies each `PAIRS` member on EXPORT, IMPORT, PREVIEW and `CheckExport`; a gate skipping `%Admin_Task:USE` turns it red.
  - `[medium]` `[patch]` verification-gap: the `NullEntityResolver` was unpinned — added `TestAnExternalEntityIsNeverResolved` (an external DTD declaring the file's elements and an entity over a sentinel file); without the resolver the summary carries the sentinel's text, measured red.
  - `[low]` `[patch]` verification-gap: the in-file duplicate-name refusal was unpinned — added `TestAFileNeverYieldsOneTaskTwice`; dropping the line imports two same-named tasks (red).
  - `[medium]` `[patch]` verification-gap: the unreadable-but-existing namespace branch was never reached — the Live rules leg adds a `USER` task as the four-pair principal, who cannot read `%DB_USER` (asserted); `Readable` answering 1 turns it red.
  - `[medium]` `[patch]` verification-gap: `lastRefusal`'s "null after an applied action" ran on a fresh handler and could not fail — it now refuses, then applies, on one handler; keeping `lastRefused` through `send` turns it red.
  - `[low]` `[patch]` verification-gap: AC3, AC8 and the client halves of AC4 and AC6 had no mutation line of their own — each mutation was demonstrated, reverted and recorded under `## Verification`.
  - `[low]` `[reject]` verification-gap other: AC2's "every stored property equals" holds for a future-start task only; with the 0 the Always section requires, the vendor recomputes a past-start task's `DayNextScheduled` and `LastSchedule` forward. These are vendor-computed next-run state (AD-6 names a task's next-scheduled time as a side-effect field). The fix edits the spec; the behavior is pinned by the past-start leg above and recorded under residual risks.
  - `[medium]` `[patch]` verification-gap other: a task with no `<Name>` would reach `$Data(pNames(""))` and answer 500 — `FileTasks` now reads such a file as not a task export (422 `TASK.IMPORT.FILE`), pinned by a `nameless.xml` case (red without the check).
  - `[low]` `[patch]` verification-gap other: two tasks sharing a `JobGUID` in one file were both summarized and counted — `Examine` now marks an accepted task's GUID present, as the vendor skips the second; pinned in `TestAFileNeverYieldsOneTaskTwice` (red without the line).
  - `[low]` `[reject]` verification-gap other: no row is highlighted after an import — the change event's target is `import` by Decision 4, and the matrix asks for a re-read and the status line only.
  - `[low]` `[reject]` verification-gap other: the spec's run line said `TaskTransfer` 12/12 — the fix edits the spec; the run record was rewritten anyway with this pass's results.
  - `[low]` `[patch]` intent-alignment: `PATH.INSTANCE` was never exercised through these tools and import had no `PATH.MANAGER` case — `TestTheServedDirectoryAndInstanceFilesAreRefused` (through `PathPortFixture`'s database-directory seam, the file left untouched) and a `messages.log` import case were added; `PATH.SERVED` is covered the same way.
  - `[false]` `[reject]` intent-alignment: the status line and script join `root` and `path` as text — every root ends in a separator: `%SYS.FileSystemAccess.Create` stores `NormalizeDirectory(RootPath)` (`irissys/%SYS/FileSystemAccess.cls:39`), and the manager directory ends in one; `NameAdmitted` admits only clean segments, so the join equals the resolved path.
  - `[low]` `[reject]` intent-alignment: the import script is the bare `ImportTasks` with no whole-file pre-check, and the export's `$ListBuild("12")` quotes the id — the spec's Snippet text, and AD-59 renders the vendor call.
  - `[low]` `[reject]` intent-alignment: the Live missing-pair leg mints in the runner's process and checks the refusal at confirm — the agent's dispatch gate is the generic `Kernel/Agent/Dispatch` pair check over `PrivilegePairs`, which `AssertCommon` pins for both tools.
  - `[false]` `[reject]` intent-alignment: the RunAs rule order differs from the create's — `TaskRules.RunAsViolations:520-542` also checks `%Admin_Secure` before existence; the port repeating the rules is the spec's (the port must not call `Area/`).
  - `[low]` `[reject]` intent-alignment: `TASK.IMPORT.CHANGED` answers only after the other checks, and its reason names the file when the instance moved — the spec's IMPORT step order and reason.
  - `[low]` `[reject]` intent-alignment: correlation loads Settings into memory, and hostile names reach the card — correlation is spec-mandated and never reads Settings; the summary is built from `Name` and `NameSpace` alone; names are untrusted data under AD-11 and AD-60.
  - `[low]` `[reject]` intent-alignment: classic-page byte parity is not tested — measured at plan (Design Notes); AC3's pinning test holds the vendor calls the classic page makes.
  - `[low]` `[reject]` intent-alignment: `MappingDescriptor` gains a `%cspapp.` branch and `ClassicPageGate` principals gain two grants — the branch checks the key through the portal's own resolver (AD-44), since that page is no compiled class here; the grants are the two tools' own pairs, held by both principals, so the discriminating resource is unchanged.
  - `[false]` `[reject]` intent-alignment: a wrapper page, a screen-level Import and the regenerated mirror — `task-schedule.page.ts` in `DESCRIPTOR_PAGES` and Decision 5 are the spec's, and `screen-mirror.mjs --check` passes in `prebuild`.
  - `[low]` `[reject]` intent-alignment: the dark pass checks contrast only — the same pass set every structural spec uses.

## Design Notes

**Measured on `ocupilot-ci`, 2026-09-29** (vendor source in `%SYS.TaskSuper`, which is Hidden):

- **Format.** `ExportTasks(ListOfIDS, FileName, qspec)` writes `<Tasks><Task>…` through `%XML.Writer`.
  - It writes `JobGUID`, the schedule, `Suspended`, `RunAsUser`, `NameSpace`, and `Settings` as Base64 of its `$ListBuild`. There is no ID.
  - The classic portal's Export writes the same bytes.
- **Import semantics.** `ImportTasks(FileName, qspec, runPastTasksTomorrow)`:
  - skips a `JobGUID` already present, answering OK silently;
  - imports task by task, so tasks before a failure stay;
  - answers only a `%Status`.
- **Round trip.** A round trip kept 48 of 48 stored properties; only the ID changed.
- **Device output.** With qspec `d` both methods write to the device, so pass `-d`.
- **Privileges.**
  - Export needs `%DB_IRISSYS:READ` only.
  - Import needs `%Admin_Task:USE` and `%DB_IRISSYS:READ`, plus `%Admin_Secure:USE` for another RunAsUser (#7405).
  - Neither checks `%Admin_FileSystemAccess`.
- **Audit.** Export writes no audit event. Import writes `%System/%System/ConfigurationChange` "Create Task <name>" per created task.
- **Classic pages.** Both classic pages are the Hidden CSP page `%cspapp.op.utilsystaskaction`. `TaskForm.cls:53` has the precedent for naming one.

**Decisions.**

1. **One task per export; the whole file per import.** This matches the classic portal: Export is a button on one task's page, and Import takes the whole file with no picking.
2. **Export overwrites, as the classic Export does.** [AMENDED 2026-09-29, spec gate: the orchestrator's direction for this story is that export uses kind `file` with `pOverwrite` declared; Story 18.3's spec and DW-1777's fix already treat 16.4 as an overwriting consumer. Was: "Export never overwrites".]
   - The export tool declares `pOverwrite` 1; PathPort still refuses a directory, the instance's files and OcuPilot's served files.
   - OcuPilot cannot restore a replaced file, so the dialog's note and the proposal card's consequence line say an existing file is replaced (developer tool first: a consequence, not a ban).
3. **Import is validated whole before the vendor call.** The vendor keeps the tasks before a failure. The port therefore repeats the vendor's own refusals, and OcuPilot's task-name rule, for every task first.
4. **Target identities.**
   - Export targets the task.
   - Import targets the literal `import` on the `task` type, as the auditing tools use `SYSTEM`.
   - Why not the file itself: the mint's and the screen route's fresh reads carry only the id, and the confirm re-reads with the canonical id, which `task:integer` folds to lower case. A path id would therefore misname a file on a case-sensitive filesystem.
   - So the file is two composed arguments, read at the write (Story 18.14's copy-mappings precedent). The reviewed `tasks` summary makes a changed file refuse instead of importing unreviewed tasks.
   - Consequence: two live import proposals share one target, so confirming one cancels the other (AD-34).
5. **Import is declared as a row action but drawn as a screen-level action.** The screen route resolves only declared row actions and a non-empty id, but Import needs no selection.
   - It is therefore undrawn as a row action and drawn in Check permission's screen-level slot.
   - Export stays an ordinary row action.
6. **Secrets.** A `%SYS.Task.Password` setting is exported as the vendor writes it: Base64, recoverable. This follows the owner's developer-tool-first direction: a consequence, not a ban.
   - OcuPilot never reads it.
   - The dialog's note and the tool's description say so.
7. **Not AD-54's create kind.** The vendor import takes a file, not a composed body over a 404 read. AD-54's purpose, never overwriting what someone else made, holds by construction: the vendor skips a present `JobGUID`, and the port refuses a name another task holds.

**Tool descriptions** (for the model, not Fixed strings):

- export: "Propose writing one scheduled task to a new file on the server, in the instance's own task export format, so another instance can import it. Name the file by `root`, an allowed directory exactly as the Allowed directories screen lists it, and `path`, a relative file name under it whose directory exists; an existing file at that name is replaced, so say so in the rationale. The file holds the task's settings as the instance stores them, and a password setting in it is encoded, not encrypted: say so in the rationale."
- import: "Propose importing every task in a task export file on the server, named by `root` and `path` as for export. Send the literal 'import' as the id. A task already on this instance, with the same task GUID, is skipped. The whole file is refused, and nothing imported, when any task in it cannot be created here."

**Fixed strings.** Fold the following into EXPERIENCE.md `:319` in place, with no new line:

- Append to the String cell: `"Export" · "Export <task>" · "Import tasks" · "The file holds the task's definition and settings, and a password setting in it is encoded, not encrypted." · "A file already at this name is replaced." · "Exported <task> to <path>." · "Imported the tasks in <path>. Any already on this instance were skipped." · "Nothing was imported: task <task> cannot be created here. <reason>"`.
- Append to the Where cell: "Task schedule's Export (the selected task) and Import (a server file) dialogs (Story 16.4, FR-76): the action label, each dialog's title, the export's note and its replace line, which is also the export proposal card's consequence line, each done line, and an import refused for one task. [ADDED 2026-09-29 - Story 16.4]".
- Keys: `taskExportAction`, `taskExportTitle`, `taskImportTitle`, `taskExportNote`, `taskExportReplaces`, `taskExportDone`, `taskImportDone`, `taskImportRefused`.
- Reused keys: `actionImport`, `actionCancel`, and the `pathPicker*` keys.
- Other in-place edits:
  - `:173`: add "export a task and import tasks (Task schedule, Story 16.4)" to the dialog list.
  - `:603`: after the Check permission sentence, add "Import on Task schedule (Story 16.4) is screen-level too; Export acts on the selected task."

**Governing ADs.** AD-21 (sixth case), AD-27, AD-51, AD-52, AD-53, AD-8, AD-29, AD-44, AD-15, AD-22, AD-59, AD-58, AD-13, AD-14, AD-34, AD-35, AD-11, AD-60, AD-39, AD-16, AD-5, AD-19, AD-54 (decision 7). AD-57 and AD-36 are untouched: no console and no new read. None contradicts an AC.

**Spine changes for the lead (Rule 20).**

- (a) **AD-27, "Story 16.4's case".** The admin API has no task export or import (`Task.CRUD`, read on the route table). So `Port/TaskTransferPort`, declared by the two tools (AD-52):
  - repeats the Tasks pairs and PathPort's;
  - in `%SYS` (AD-16), calls `%SYS.Task.ExportTasks` and `ImportTasks`, which is what the classic `%cspapp.op.utilsystaskaction` does (its export byte-identical, measured);
  - reads a file's tasks through `%XML.Reader` correlated to `%SYS.Task`, saving nothing;
  - refuses a file any of whose tasks the vendor would refuse, because the vendor keeps tasks imported before a failure (measured).
- (b) **AD-51's case list.** `TaskTransferPort` builds the vendor calls from the tools' declared `root` and `path`, resolved through PathPort at the write, and refuses an import whose file no longer yields the reviewed `tasks`.
- (c) **AD-15 and AD-53, the sixth named case.** Exporting a task writes no vendor audit event (measured on `ocupilot-ci`, 2026-09-29).
- (d) **AD-44.** Story 16.4's `CLASSICPAGES` is `%cspapp.op.utilsystaskaction`, for both tools.
- (e) **AD-21's sixth case.** "Story 16.4's export is an overwriting `file` consumer (it declares `pOverwrite` 1) and its import a `source`." [written by the lead at the spec gate, with (a)-(d)]

**Integration.**

- **Consumes:**
  - 18.1's `PathPort.Resolve`, `AllowedDirectoriesStore` and `app-server-path-picker`;
  - 9.8's `TaskPort`;
  - the screen action route and `ScreenActionHandler.sendFor`;
  - 16.3's screen-level action slot;
  - `violations.ts`;
  - `structural-walk.mjs`.
- **Consumed-by:** no later story is planned. This story's consumers are named in AC9 and AC5.

**Ledger inbox.** None owned.

- Declined DW-118: Story 15.6 resolved it, as 16.18 recorded.
- DW-1638 (task delete/run privilege) is 16.11's.

## Verification

**Commands:**

- Loop, ObjectScript on `ocupilot-ci`:
  1. `rsync -a --delete src/ /tmp/ocupilot-ci/src/`
  2. `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/1518373f-040c-4be6-a814-a27bfbff2961/scratchpad/epic-16/compile.sh <changed paths>`
  3. `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class <C>`, one class per call. Run:
     - `TaskTransfer`, `TaskTransferLive`, `TaskScheduleActions`, `TaskWire`, `Prohibited`;
     - `ReadTool`, `SurfaceCoverage`, `ToolRoundTrip`, `ToolWrite`;
     - `PortGate`, `DraftRegistry`, `DraftPorts`, `ClassicPageGate`, `GovernanceBaseline`;
     - `Descriptor`, `ScreenRead`, `ReadBack`.

  Expected: green.
- Loop, client: `cd ui && npm run test:tools && npx ng test --include src/app/areas/tasks/task-export-dialog.spec.ts --include src/app/areas/tasks/task-import-dialog.spec.ts --include src/app/areas/tasks/task-schedule.page.spec.ts --include src/app/shell/command-bar.spec.ts --include src/app/shell/command-box.spec.ts --include src/app/shell/screen-action-handler.spec.ts --include src/app/shell/server-path-picker.spec.ts`. Expected: green, with EXPERIENCE.md at 993 lines.
- Loop, browser: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/ && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/task-transfer.browser-spec.mjs browser/task-schedule-actions.browser-spec.mjs browser/tasks.browser-spec.mjs`. Expected: green in both themes.
- Once, before dev_complete:
  - `cd ui && npm test`. Expected: green, with the bundle under 2217kB or re-based.
  - The full ObjectScript sweep on `ocupilot-ci`, one class at a time. Expected: green apart from the named known residue.
  - The full browser suite is CI's.

**Planned mutations (Rule 19):**

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | `EXPORT` passes `$ListBuild()` (empty) | `TaskTransferLive` export leg: no task in the file |
| AC2 | `IMPORT` passes `runPastTasksTomorrow` 1 | `TaskTransferLive` round-trip property compare |
| AC4 | `Locate` passes `pOverwrite` 0 for EXPORT | `TaskTransfer` export-onto-an-existing-file leg answers `PATH.EXISTS` instead of replacing it |
| AC5 | the `tasks` comparison becomes `If 0` | `TaskTransferLive` `TASK.IMPORT.CHANGED` leg |
| AC6 | `Preview` checks only the first task | `TaskTransfer` bad-task-last leg: a task created |
| AC7 | `PrivilegePairs` drops `%Admin_FileSystemAccess:USE` | `TaskTransferLive` 403 leg (the port's gate must refuse too, so mutate both) |
| AC8/AC9 | the page's `sendFor` omits `path` | `task-schedule.page.spec.ts` and `task-transfer.browser-spec.mjs` |

**Mutations run (Rule 19)**, each on `ocupilot-ci`, reverted, and the tree checked unchanged after:

- AC1 mutation: `TaskTransferPort.Export` passes `$ListBuild()` to the vendor → `TaskTransferLive` `TestTheScreenRoundTripKeepsEveryStoredProperty` (the export answers 500, no file), `TestTheAgentExportsAndImportsThroughConfirm` and `TestVendorFilesAndToolFilesAreInterchangeable` red.
- AC2 mutation: `VendorImport` passes `runPastTasksTomorrow` 1 → `TaskTransferLive` `TestAPastStartTaskIsScheduledAsTheVendorSchedulesIt` red (a future-start probe cannot show it); `Examine` never counting a task present → the round-trip leg's second import red.
- AC3 mutation: `ROOTELEMENT` "TaskList" → `TaskTransferLive` `TestVendorFilesAndToolFilesAreInterchangeable` red (the vendor's file refused `TASK.IMPORT.FILE`).
- AC4 mutation: `Locate` passes `pOverwrite` 0 for an export → `TaskTransfer` `TestAnExportWritesTheTaskAndReplacesAFileAtTheName` (answers `PATH.EXISTS`) and `TestAFailedExportDeletesOnlyAFileItWrote` red.
- AC5 mutation: the reviewed-tasks comparison becomes `If 0` → `TaskTransferLive` `TestTheAgentExportsAndImportsThroughConfirm` `TASK.IMPORT.CHANGED` leg red.
- AC4 mutation (client): the page's `showRefusal` ignores the violations → `task-schedule.page.spec.ts` "AC4: a refusal on the name…" red.
- AC6 mutation: `Examine` checks only the first task it would create → `TaskTransfer` `TestOneTaskThatCannotBeCreatedImportsNothing` bad-task-last legs red, with the vendor import made. `Readable` answers 1 → `TaskTransferLive` rules leg answers `TASK.TASKCLASS.UNKNOWN` for `USER`, red. Dropping the in-file name line → `TestAFileNeverYieldsOneTaskTwice` red. The page drops its `detail.task` sentence → `task-schedule.page.spec.ts` "AC2, AC6…" red.
- AC7 mutation: `%Admin_FileSystemAccess:USE` dropped from both tools' `PrivilegePairs` and the port's `PAIRS` → `TaskTransferLive` `TestAPrincipalWithoutAPairIsRefusedOnBothCallers` red. `TaskTransferPort.Gate` skips `%Admin_Task:USE` → `TaskTransfer` `TestTheGateRefusesAMissingPairBeforeAnyCall` red on every type and on `CheckExport`.
- AC8 mutation: `taskExportReplaces` reworded in `strings.ts` → `tools/strings.test.mjs` red.
- Other: drop the `NullEntityResolver` → `TestAnExternalEntityIsNeverResolved` red (the summary carries the sentinel file's text); drop the in-file GUID line → `TestAFileNeverYieldsOneTaskTwice` red; drop the nameless check → `TestAnImportRefusesAFileThatIsNotATaskExport` red; keep `lastRefused` through `send` → `screen-action-handler.spec.ts` "answers null once a later action…" red.
- Password row mutation: drop `WithholdSettings` from `TaskPort`'s read → `TaskTransfer` `TestAPasswordSettingIsExportedButNeverRead` red on the read leg.
- AC8/AC9 mutation: the page's `sendFor` omits `path` → `task-schedule.page.spec.ts` export and import legs red; `task-transfer.browser-spec.mjs` red after rebuild and redeploy.

**Run (implement stage, after review):** the full ObjectScript sweep on `ocupilot-ci` ran 362 classes and 2,737 tests. Its one failure in a class this story touches, `ToolEmit` (both tools declared their file pair outside the `WRITERESOURCE` convention), was fixed and re-ran 11/11. The rest is residue: `PathPortInstance` 1, `TaskHistory` 3, `Retention` 1, `WireSecurityRead` 1, `ProposalPrivilege` 1 (`%SYS` holds 1,055 application errors, above one delete's cap), and 30 classes refused by arming variable. This story's refused classes re-ran armed (`docker exec -e`): `TaskTransfer` 15/15, `TaskTransferLive` 6/6, `TaskWire` 6/6, `ClassicPageGate` 3/3. `npm test` passed 1706 tool and 1826 component tests; the bundle is 2.18 MB. On a redeployed bundle, `task-transfer` passed 3/3 and `task-schedule-actions` 4/4. `tasks.browser-spec.mjs` passed 12/15; its three failures are Task history reads timing out, as the `TaskHistory` residue does (inference).

## Auto Run Result

Status: done
Blocking condition: none

- **Implemented:** Task schedule's Export and Import, as two write tools (`tasks.schedule.export`, `tasks.schedule.import`) with two callers each, over the new `Port/TaskTransferPort` (PathPort-resolved files, `%SYS.Task.ExportTasks`/`ImportTasks` in `%SYS`, whole-file validation before import). The client adds the Task schedule page, two dialogs over the server path picker, a screen-level Import, `lastRefusal()` on the handler and eight strings. `PathPort.cls` is untouched; `AdminPort.cls` has only the `MUTATINGTYPES` append.
- **Files:**
  - Server: `Port/TaskTransferPort.cls`; `Screen/Tool/TaskExport.cls`, `TaskExportMint.cls`, `TaskImport.cls`, `TaskImportMint.cls`; `Api/Error.cls` (four codes); `Kernel/Governance/Baseline.cls`; `Port/AdminPort.cls`; `Screen/Descriptor/TaskScheduleList.cls`.
  - Server tests: `Test/TaskTransfer.cls`, `TaskTransferLive.cls`, `TaskTransferFixture.cls`, and the Code Map's rosters.
  - Client: `areas/tasks/` page, two dialogs and their three specs; the handler, `screen-actions.ts`, the command bar and box; `strings.ts`; `screens.generated.ts` (regenerated); `screen-outlet.ts`.
  - Also: `scripts/ci-throwaway.sh` arming comments, EXPERIENCE.md (993 lines), `browser/task-transfer.browser-spec.mjs` and `task-schedule-actions.browser-spec.mjs`.
  - Outside the Code Map: `core/proposal-view.ts` with `tools/proposal-view.test.mjs` (the card's `TASK.EXPORT.REPLACES` consequence line), and an add-only block at the end of `_components.scss`.
- **Deviations:**
  - Export and Import are declared before Delete, not appended, so the row menu keeps the destructive action last.
  - PREVIEW refuses an all-present file, so the agent's mint refuses it too.
  - Both tools declare the file pair as `WRITERESOURCE`/`WRITEPERMISSION`, the convention `ToolEmit` reads.
- **Review:** 23 findings (high 0, medium 6, low 14, false 3), triaged in the Review Triage Log.
  - Patched: 6 medium and 4 low.
  - The two port changes: a task with no name is refused `TASK.IMPORT.FILE`, and a second task sharing a `JobGUID` is counted present. The rest are new test legs and Rule 19 lines.
  - Nothing deferred; 10 rejected with reasons in the log.
  - Follow-up review: `false`. The computation reached two or more patched mediums, but every patch is pinned by a demonstrated red, so no specific unverified risk can be named.
- **Verification:** see `## Verification`, "Run (implement stage, after review)". Every recorded mutation was applied, observed red and reverted with the tree unchanged, and every probe task, file and principal was removed.
- **Residual risks:**
  - A task whose start date is past has its `DayNextScheduled` and `LastSchedule` recomputed by the vendor's import with 0, so AC2's property compare holds for a future-start task only.
  - The three `tasks.browser-spec.mjs` Task history failures are attributed to the throwaway's old history rows (inference); CI's fresh throwaway settles it.
  - `ocupilot-ci` lacks `OCUPILOT_ALLOW_TASK_CONTROL` and `OCUPILOT_ALLOW_NAMESPACE_CONFIG`, so the armed classes ran through `docker exec -e`; CI arms them itself.
