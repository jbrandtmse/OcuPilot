---
title: 'Story 16.11: Start, suspend and resume the Task Manager'
type: 'feature'
created: '2026-09-30'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-16-context.md'
warnings: ['oversized', 'multiple-goals']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Task schedule's banner reports a suspended or stopped Task Manager, but no OcuPilot surface can suspend, resume or start it. The classic Task schedule page is still the only way, and Home's Task Manager finding can only link to Task schedule. Separately, the task row tools suspend, resume, run, schedule-run and delete skip the privilege each task type declares, which the create, the 9.8 edit and the classic portal all enforce (DW-1638).

**Approach:** Add three action-style write tools over the vendor's `Task.Manager` (`SUSPEND`, `RESUME`, `RUN`) on the Task schedule screen. The screen and the agent both reach them. Suspend sits on the command bar behind a warning dialog. The banner carries Resume or Start through a new per-case `action` key, gated by a `bannerRequires` verdict that the read computes. Home's finding proposes the fix. Each task row tool judges the task type's privilege on both callers.

## Boundaries & Constraints

**Always:**

- **The three tools.**
  - `tasks.schedule.suspendmanager` (`SUSPEND`), `tasks.schedule.resumemanager` (`RESUME`) and `tasks.schedule.startmanager` (`RUN`).
  - Each has endpoint `Task.Manager`, `READTYPE` `GET`, `SENDSBODY` 0 and `DESTRUCTIVE` 0.
  - `PRECONDITIONFIELD`, `FINGERPRINTSUBJECT`, `STATEFIELD` and `READANSWERS` are all `Status`.
  - The id argument is `Id` and the query parameter is `id`. The vendor ignores `id` (measured).
  - Each is its own governance key, added **enabled** to `Kernel/Governance/Baseline.cls`.
- **The target is `task/instance/manager`.** The descriptor's primary type is `task` and the id is the literal `manager`, as Import's `task/instance/import` is. The `task` id rule folds case, so `manager` is compared without regard to case. The agent is refused any other id: an absent `Id` is refused by the input schema's `required` and the tool-call refusal (`TOOL.ARGUMENTS`), and a different one by `ArgumentProblem`. The screen route is refused a different id by `ScreenActionDelta`. Nothing is sent.
- **The state each verb accepts.** Each tool acts only from one `Status`. Anything else is refused in `StateDiff`, on both callers, before any write. The refusal is a 400 `TOOL.ARGUMENTS` whose `detail.problem` is a published sentence:

  | Tool | `Running` | `Suspended` | `Not running` |
  |---|---|---|---|
  | suspendmanager | acts | "The Task Manager is already suspended." | "The Task Manager is not running. Start it first." |
  | resumemanager | "The Task Manager is already running." | acts | "The Task Manager is not running. Start it first." |
  | startmanager | "The Task Manager is already running." | "The Task Manager is suspended. Resume it instead." | acts |

  - Any other `Status` value, an absent one or one that is not a string is refused with an unpublished problem.
  - The diff row is `Status: <before> → <after>`, where `after` is `Suspended` for suspend and `Running` for resume and start.
- **Pairs.**
  - Suspend and resume require exactly the screen's pairs, `%Admin_Task:USE` and `%DB_IRISSYS:READ`.
  - Start also declares `%Admin_Secure:USE` (AD-8 amendment below). A caller without it is refused by name before any port call, at the mint, at Confirm and on the screen route.
  - No tool declares `CLASSICPAGES`. The classic page that performs all three operations is the descriptor's own `%CSP.UI.Portal.TaskSchedule`.
- **The start's process frame.** The vendor starts the Task Manager as a job with the caller's `$ROLES`, so the start's port call must run in no escalated frame (AD-9).
- **The screen caller's dialogs.** Suspend opens the warning dialog (a button-primary Proceed) titled "Suspend Task Manager", whose body is "No scheduled task will run until it is resumed.". Nothing is sent until Proceed. Resume and Start are sent at once, with no dialog.
- **The agent's suspend proposal** carries that same sentence through a consequence code the client maps (`proposal-view.ts`).
- **A banner case's `action`.**
  - The key is optional. When present it names one of the screen's declared `rowActions`, and `Screen/Registry.cls`, `ui/tools/screen-mirror.mjs` and `Test/BannerCorpus.cls` all refuse any other value in the same words.
  - The screen read answer carries `bannerRequires` beside `banner`: the first pair the caller lacks for the raised case's action tool, as `resource:permission`, or `""`.
  - The list page draws the action's button inside the strip. It is `aria-disabled` with "Requires <pair>" while `bannerRequires` is non-empty (EXPERIENCE.md Privilege Gating).
- **The banner is recomputed from the read.** It follows an auto-refresh tick and a change event (AD-14, AD-43). No client code sets it from a write's response.
- **DW-1638.** `TaskResume` (and through it `TaskSuspend`), `TaskRun` (and through it `TaskScheduleRun`, which keeps no methods of its own) and `TaskDelete` judge the task type's privilege on both callers: `ArgumentProblem` for the agent's mint and `ScreenActionDelta` for the screen route. Both go through one new public `TaskRules` method. The problem text is the existing `Api.Error.#REASONTASKTASKCLASSPERMISSION` sentence, now published. A task the check's read cannot find (404) is left to the fresh read to refuse.
- **Test hygiene.**
  - Every test leaves the Task Manager running and restored by a teardown that also runs on failure. No test depends on another's state (Consistency Conventions › Tests).
  - A test stops the Task Manager only on the throwaway, by terminating its process from a `%SYS` step of its own, never through OcuPilot.
  - It restarts it with `%SYS.Task.StartTASKMGR()` from a `%All` process and asserts the process reads user `TASKMGR` with `%All`.
- **Shared files.**
  - EXPERIENCE.md is edited in place and stays at 993 lines, with `npm run test:tools` green.
  - Additions to `strings.ts`, the baseline and every shared roster are add-only.
  - Check Epic 23's footprint before editing (spawn-prompt rule). If a contended file needs a non-additive edit, stop and report it (`blocked`).

**Never:**

- Suspend, stop or start the Task Manager on `ocupilot` (live). Every probe and test runs on `ocupilot-ci`.
- Add an entity type, a REST route, a `Prohibited` arm, a `CLASSICPAGES` entry or an `Api/Error.cls` parameter (it is at the compiler's limit).
- Hand-edit a generated file: `Port/AdminRoutes.cls` (it already routes all three), `FieldLists.cls`, `ToolFields.cls` or `screens.generated.ts`. Do not edit `Port/PathPort.cls` at all.
- Put the banner or `bannerRequires` into the read tool's view or into screen context. Both are screen chrome.
- Give the client a map of which pairs each tool requires.
- Run `%SYS.Task.PurgeTaskHistory` or `Ens.Util.Tasks.Purge` on anything but a probe task created with a harmless setting.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Suspend from the command bar | `Running`; a person activates "Suspend Task Manager" | The warning dialog opens. Proceed sends `SUSPEND`, and the re-read raises the suspended banner with "Resume Task Manager" while the rows still list. | Cancel sends nothing |
| Resume from the banner | `Suspended` | `RESUME` is sent at once. The change event re-reads, and the banner clears without a manual refresh. | none |
| Start from the stopped banner | `Not running`; the caller holds `%Admin_Secure:USE` | `RUN` is sent at once and the banner clears. The new process runs as `TASKMGR`. | none |
| Start without `%Admin_Secure:USE` | `Not running`; the caller holds only the screen's pairs | `bannerRequires` is `%Admin_Secure:USE`, and "Start Task Manager" is `aria-disabled` with "Requires %Admin_Secure:USE". The route and the mint answer 403 naming the pair. | Refused before any port call |
| Wrong verb for the state | The table above | 400 `TOOL.ARGUMENTS`, with `detail.problem` the published sentence the list shows | Nothing sent |
| Agent suspends | `{Id:"manager"}` | The proposal's diff is `Status: Running → Suspended` and it carries the consequence. Confirm sends `SUSPEND`, emits the marker, reads back `nothingSent` and publishes `task/instance/manager`. | none |
| Agent names another id, or none | `{Id:"7"}`, or no `Id` | 400 `TOOL.ARGUMENTS`: another id by `ArgumentProblem`, a missing one by the input schema's `required` | No proposal |
| State moves under a live proposal | Minted while `Running`, and someone suspends before Confirm | Confirm is refused because the fingerprint over `Status` moved | Nothing sent |
| Least-privileged suspend and resume | A principal holding exactly `%Admin_Task:USE` and `%DB_IRISSYS:READ` | Both succeed on the screen route (measured at the vendor) | none |
| Home finding | Banner suspended or stopped | The `task-manager` finding answers `fix` `agent`. Fix it opens Task schedule and sends "The Task Manager is not running scheduled tasks. Propose resuming it, or starting it if it is stopped." | The agent's wrong-verb proposal is refused with the published sentence |
| DW-1638 | A probe `Ens.Util.Tasks.Purge` task in HSCUSTOM; the caller lacks `%Ens_PurgeSchedule:USE` | Suspend, resume, run and delete are refused on the route and at the agent's mint with "This task type needs a privilege you do not hold." A holder of the pair suspends, resumes and deletes it. | Nothing sent to the task |
| Audit | Suspend, resume and start with auditing on | Suspend and resume each leave `%System/%System/ConfigurationChange` "Modify Task Config.Suspend". Start leaves no vendor event, only the agent marker on the agent path. | Marker failure never fails the write (AD-15) |

</intent-contract>

## Code Map

Anchors are as of `9a874a14`. Measured vendor facts are under Design Notes.

**Server (`src/OcuPilot/`):**

- **Precedents for the new tools:**
  - `Screen/Tool/LanguageServerStart.cls:70-162` refuses a verb in the wrong state through `StateDiff` and its published reason parameters. `LanguageServerStop.cls` is the subclass pattern.
  - `Screen/Tool/TaskResume.cls:23-120` declares a bodyless task action and its `PrivilegePairs`.
  - `Screen/Tool/TaskImport.cls:24,38,122` uses a literal id for a screen-level action.
  - `Screen/Tool/AuditPurge.cls:31,143-146` declares a consequence code.
- **Tool base, `Screen/Tool/Write.cls`:**
  - parameters at `:30-217`;
  - `ScreenActionDelta` at `:607`, the one hook the screen route passes with both the id and the fresh read;
  - `ArgumentProblem` at `:809`, which only the mint calls (`Kernel/Proposal/Mint.cls:217`);
  - an empty field list for a bodyless tool at `:617-618`.
  - `Screen/Tool/Registry.cls:33` holds the name pattern; the fingerprint subject's names must be read answers (`:137-143`, `Screen/Registry.cls:2565,2786`).
- **Screen route, `Api/ScreenAction.cls`:**
  - `Run` at `:217-363`: the pair gate at `:245` resolves `ArgumentPairs` from `{Id}`, then `ScreenActionDelta` at `:272`, then `Body`/`StateDiff`;
  - `Refuse` at `:550`;
  - `ToolFor` at `:496-515` (private);
  - action ids must be declared `rowActions` (`:151`).
- **Pairs:**
  - `Kernel/Proposal/Operation.cls:407-435` `RequiredPairsOf` and `:444` `MissingPair`, used by `Gate`, which the mint, `Confirm.cls:279` and the route call;
  - `Screen/Gate.cls:206` `RequiredPairs` and `:253` `EvaluatePairs`.
- **`Port/AdminPort.cls`:**
  - `MUTATINGTYPES` `:389` and `BODYLESSTYPES` `:405` have no `Task.Manager` entry yet.
  - `Port/AdminRoutes.cls:224-226` already routes `SUSPEND`, `RESUME` and `RUN`, so `Snippet` (`:2869-2921`) renders them with no change.
- **Task rules, `Area/Task/TaskRules.cls`:** `Permitted` at `:996` is private. The create's check is at `:141` and the edit's at `:250`. `Screen/Tool/TaskUpdate.cls:233-245` is the `ArgumentProblem` precedent.
  - The row tools are `TaskRun.cls` (with `TaskScheduleRun.cls`, which must keep no methods; see `Test/TaskScheduleActions.cls:83-84`) and `TaskDelete.cls`, whose port is `TaskPort` (`:30`).
  - Their `INFO` answers no `TaskClass` or `NameSpace`; `Task.CRUD` `GET` answers both.
- **Descriptor, `Screen/Descriptor/TaskScheduleList.cls`:** `rowActions` `:104`, banner `:139-146`, prompts `:107-111`. The stale "Resume is Epic 7's" doc lines are `:38-39`.
- **Banner validation, `Screen/Registry.cls`:** `BannerProblem` `:859-919` and `BannerCasesProblem` `:921-960`, whose case keys are at `:937`. The `multiSelect.action ∈ rowActions` precedent is `:3683-3691`.
- **The read, `Screen/Read.cls`:** `BannerKey` `:1036-1062`; the answer's `banner` is set at `:561`. `Screen/Tool/Read.cls:79-96,234-236` is the tool view, which stays unchanged.
- **Findings, `Kernel/Shell/Findings.cls`:** `TaskManager` `:430-440`, where `:437` uses `FIXLINK` and `FIXAGENT` is at `:40`.
- **Rosters (add-only):**
  - `Kernel/Governance/Baseline.cls:122-132`, append after `:132`;
  - `Test/ReadTool.cls:93-94` (182 becomes 185);
  - `Test/SurfaceCoverage.cls:239-257`;
  - `Test/ToolRoundTrip.cls:47` (`REFUSEEMPTY`);
  - `Test/ToolWrite.cls:1220-1300` and `Test/PortFixture.cls:21` (`MUTATINGTYPES` equality);
  - `Test/TaskScheduleActions.cls:99` (`rowActions` pin);
  - `Test/Findings.cls:263` (Task Manager `link`);
  - `Test/BannerCorpus.cls:47-78`;
  - any roster counting write tools that the sweep reddens (Guardrails's among them).
- **Arming:** `scripts/ci-throwaway.sh:317-330` (`OCUPILOT_ALLOW_TASK_CONTROL` `# classes:` lines), held equal by `ui/tools/ci.test.mjs:1818-1939`.
- **Test hosts:**
  - `Test/TaskWire.cls` (409 lines) is the precedent for a least-privileged principal and for `AgentMint`/`MintAs` with an `Ens.Util.Tasks.Purge` probe at `:280-306`.
  - `Test/TaskEditProbe.cls` has probe task helpers.
  - `Test/FindingsFixture.cls` supplies canned banners.
  - `Test/ScreenRead.cls:463` and `Test/WireSecurityRead.cls:418-419` assume a running Task Manager.

**Client (`ui/src/app/`):**

- **The banner, `shell/list-page.ts`:** the strip at `:60-65`, the stale doc comment at `:35-40`, `raisedCase` at `:197-203`, and `bannerText`/`bannerClass` at `:231-251`.
- **The banner's path through the client:**
  - `core/screen-read.ts:218-224` parses `banner`;
  - `core/screen-store.ts:122,251,287-290,306` holds it (`bannerKey`, `applyTick`, `clearAnswers`);
  - `core/refresh.ts:438,576,641-653` updates it on a tick and on a change event.
- **Actions, `core/screen-actions.ts`:**
  - `ScreenActions.register`/`has`/`run` at `:170-211`;
  - `TASK_IMPORT_ACTION_ID` at `:48`;
  - `ACTION_LABELS` at `:80-106`;
  - the Task schedule entry at `:155`.
- **`shell/screen-action-handler.ts`:**
  - `TASK_SCHEDULE`, `TASK_IMPORT_TARGET` at `:153-162`;
  - `UNDRAWN_ACTIONS` at `:221-235`;
  - `WARNING_CONSEQUENCES` at `:389-404`;
  - `PUBLISHED_PROBLEMS` at `:436-441`;
  - `startFor` at `:748-822`, whose empty-target guard is at `:758`.
- **Surfaces:**
  - `shell/command-bar.ts:326-334,642,733-750` draws Import at screen level;
  - `shell/command-box.ts:508-511`;
  - `areas/tasks/task-schedule.page.ts:142-145` registers the actions.
- **Gating:** `core/navigation.ts:617` `formatRequires`, and `STRINGS.privilegeRequiresResource` in `strings.ts:255`.
- **Home findings:**
  - `core/fix-finding.ts:19-25` `SENTENCE_KEYS`;
  - `core/findings.ts:209-217`;
  - `areas/home/home.page.ts:58-66,700-727`, where `task` is already in `FINDINGS_CHANGE_TYPES`.
- **Consequence codes:** `core/proposal-view.ts:189-230`.
- **Strings:** `core/strings.ts`, appended before `} as const` at `:3972`. The existing keys are `taskManagerSuspendedBanner` `:301`, `taskManagerStoppedBanner` `:303`, `findingFixTaskError` `:3203` and `actionStart` `:3809`.

**Tests and docs:**

- **Browser specs, `ui/browser/`:**
  - `tasks.browser-spec.mjs`: the banner leg `:379-428` asserts "no Resume (Epic 7 ships that)" at `:401`; `setTaskManagerSuspended` is at `:103-116`; the running-state before/after guards are at `:132` and `:152-166`.
  - `home-findings.browser-spec.mjs`: the `task-error` legs at `:191-353` are the pattern to follow.
- **Tools tests, `ui/tools/`:** `screen-mirror.test.mjs:1054,1275-1312`, `screen-actions.test.mjs:122-132`, `fix-finding.test.mjs:88,95` and `self-protection.test.mjs:386-421`.
- **Component specs:**
  - `shell/list-page.spec.ts:526-611`;
  - `shell/screen-action-handler.spec.ts:555-575,1421-1447`;
  - `areas/tasks/task-schedule.page.spec.ts:108-135`;
  - `shell/command-bar.spec.ts:1278`;
  - `shell/command-box.spec.ts:641-645`;
  - `areas/home/home.page.spec.ts`.
- **`EXPERIENCE.md`** (`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/`), edited in place: `:102`, `:269`, `:304`, `:562`, `:582`, `:686` and `:732`.

## Tasks & Acceptance

**Execution:**

- **`src/OcuPilot/Screen/Tool/TaskManagerSuspend.cls` (new)** -- the suspend tool and the shared base the other two extend.
  - Declares the parameters under Always, `SCREENACTIONS` `suspendmanager` and `WRITETYPE` `SUSPEND`.
  - Declares the four refusal sentences as parameters: `RUNNINGREASON`, `SUSPENDEDREASON`, `SUSPENDEDSTARTREASON` and `STOPPEDREASON`.
  - Declares `FROMSTATUS`/`TOSTATUS`, which drive `StateDiff` from the table.
  - `ArgumentProblem` and `ScreenActionDelta` (which calls `##super` first) refuse any `Id` other than `manager`.
  - `Consequence` answers `CONSEQUENCESUSPEND` = `TASK.MANAGER.SUSPEND`.
  - `InputSchema` describes the id as "the literal 'manager'".
  - An agent-facing `DESCRIPTION` says it proposes, and what it refuses.
- **`src/OcuPilot/Screen/Tool/TaskManagerResume.cls`, `TaskManagerStart.cls` (new)** -- subclasses carrying their own `TOOLNAME`, `SCREENACTIONS`, `WRITETYPE` (`RESUME`/`RUN`), `FROMSTATUS`/`TOSTATUS` and `DESCRIPTION`. Each answers no consequence.
  - `TaskManagerStart.PrivilegePairs` appends `%Admin_Secure:USE` to the screen's pairs.
- **`src/OcuPilot/Screen/Descriptor/TaskScheduleList.cls`** -- declarations for the new actions:
  - append `rowActions` `suspendmanager`, `resumemanager` and `startmanager`;
  - banner cases gain `"action": "resumemanager"` (`Suspended`) and `"action": "startmanager"` (`Not running`);
  - a fourth prompt, `taskScheduleListPrompt4`, in `taskPromptGroupSchedule`;
  - rewrite the doc lines that call Resume Epic 7's.
- **`src/OcuPilot/Screen/Registry.cls`, `ui/tools/screen-mirror.mjs`, `src/OcuPilot/Test/BannerCorpus.cls`** -- admit an optional case `action` that must name a declared `rowActions` id, refused in the same words on both sides.
  - Add corpus cases: a sound action, an action naming no declared row action, and an action that is not a string.
  - Regenerate `screens.generated.ts` (`BannerCase.action?`).
- **`src/OcuPilot/Screen/Read.cls`** -- beside `banner`, set `bannerRequires` on the screen read's answer.
  - It is resolved from the raised case's `action`: the tool whose `DESCRIPTORCLASS` is the descriptor and whose screen actions include it (as `ScreenAction.ToolFor` does), then its required pairs, then `Gate.EvaluatePairs`, in the caller's process.
  - It is `""` for no raised case, no action or no failed pair. A fault leaves it `""` and never fails the read.
- **`src/OcuPilot/Port/AdminPort.cls`, `src/OcuPilot/Test/PortFixture.cls`** -- add `Task.Manager/RESUME,RUN,SUSPEND` to `MUTATINGTYPES` and `BODYLESSTYPES`, and the same pairs to the fixture.
- **`src/OcuPilot/Kernel/Governance/Baseline.cls`** -- append the three keys, `true`.
- **`src/OcuPilot/Area/Task/TaskRules.cls`** -- add a public `TargetProblem(pId, Output pProblem) As %Status` (DW-1638).
  - It reads `Task.CRUD` `GET` `id` through `OcuPilot.Port.AdminPort`.
  - On a 404 it answers no problem. On any other fault it answers an error status.
  - If the task is found and `'..Permitted(TaskClass, NameSpace)`, then `pProblem` is `##class(OcuPilot.Api.Error).#REASONTASKTASKCLASSPERMISSION`.
- **`src/OcuPilot/Screen/Tool/TaskResume.cls`, `TaskRun.cls`, `TaskDelete.cls`** -- override `ArgumentProblem` and `ScreenActionDelta`, which calls `##super`, to call `TaskRules.TargetProblem` for DW-1638. `TaskSuspend` and `TaskScheduleRun` inherit these.
- **`src/OcuPilot/Kernel/Shell/Findings.cls`** -- `TaskManager` uses `FIXAGENT` for both banner keys.
- **`src/OcuPilot/Test/TaskManagerTools.cls` (new, unarmed, canned reads)** -- tests for the tools, the descriptor and the banner grammar:
  - each tool registers as action-style: `SENDSBODY` 0, no field rows, no `ToolFields`/`FieldLists` entry, `Task.Manager` in `BODYLESSTYPES`, subject `Status`;
  - the refusal matrix over all nine tool-and-state pairs and an unreadable `Status`;
  - the literal-id refusal on both hooks;
  - `PrivilegePairs`, where only start adds `%Admin_Secure:USE`;
  - the three baseline keys;
  - the descriptor's banner actions.
- **`src/OcuPilot/Test/TaskManagerLive.cls` (new, armed with `OCUPILOT_ALLOW_TASK_CONTROL`)** -- live runs of the three tools, with a teardown that restores the Task Manager on every exit:
  - suspend and resume through the screen route as `_SYSTEM` and as an exact-pairs principal;
  - the agent's mint and confirm, checking the marker, `readBack` `nothingSent` and the change event's target;
  - the fingerprint refusal after an out-of-band suspend;
  - the audit rows over a timestamp window;
  - start refused 403 naming `%Admin_Secure:USE` for the exact-pairs principal while `Running`, with no state change;
  - one stop and start: terminate the process, check the read is `Not running` and `bannerRequires` is the pair for that principal, start through the route as `_SYSTEM`, then assert `Running` with the process's user `TASKMGR`;
  - `bannerRequires` is `""` while suspended for the exact-pairs principal.
- **`src/OcuPilot/Test/TaskRowWire.cls` (new, armed)** -- the DW-1638 legs, following `TaskWire.cls:280-306`. A probe `Ens.Util.Tasks.Purge` task (`TypesToPurge` `events`) in HSCUSTOM is:
  - refused by suspend, resume, run and delete for a principal without `%Ens_PurgeSchedule:USE`, on the route and at the agent's mint, with the task unchanged;
  - suspended, resumed and deleted by a holder of the pair. The probe is never run.
- **Existing tests, `src/OcuPilot/Test/` and `scripts/ci-throwaway.sh`** -- follow the story's roster changes:
  - `TaskScheduleActions.cls` gets the `rowActions` pin;
  - `Findings.cls` expects `agent` for both states;
  - `ReadTool.cls` reads 185;
  - `SurfaceCoverage.cls` and `ToolRoundTrip.cls` each get three rows;
  - `ToolWrite.cls` gets the new pairs;
  - `scripts/ci-throwaway.sh` gets a `# classes: TaskManagerLive, TaskRowWire` line.
- **`ui/src/app/core/screen-read.ts`, `screen-store.ts`, `refresh.ts`** -- parse `bannerRequires` (a string, else `''`), keep it beside the banner key through `applyTick` and `clearAnswers`, and pass it on both tick paths.
- **`ui/src/app/shell/list-page.ts`** -- inside the strip, draw the raised case's action as a button when `ScreenActions.has(descriptor, action)`.
  - Its label comes from `actionLabel`.
  - While `bannerRequires` is non-empty it is `aria-disabled` with the "Requires <pair>" tooltip (`aria-describedby`).
  - Otherwise a click runs `ScreenActions.run`.
- **`ui/src/app/core/screen-actions.ts`** -- `TASK_MANAGER_SUSPEND_ACTION_ID` and the labels for Task schedule: `suspendmanager`, `resumemanager` and `startmanager` read "Suspend Task Manager", "Resume Task Manager" and "Start Task Manager".
- **`ui/src/app/shell/screen-action-handler.ts`** -- the handler's Task Manager entries:
  - `TASK_MANAGER_TARGET = 'manager'`;
  - add the three ids to `UNDRAWN_ACTIONS[TASK_SCHEDULE]`;
  - `WARNING_CONSEQUENCES[TASK_SCHEDULE].suspendmanager`;
  - add the four refusal sentences and `taskTypePrivilegeRefusal` to `PUBLISHED_PROBLEMS`.
- **`ui/src/app/shell/command-bar.ts`, `command-box.ts`, `areas/tasks/task-schedule.page.ts`** -- the surfaces:
  - the command bar draws "Suspend Task Manager" at screen level, as it draws Import;
  - the command box lists all three at screen level;
  - the page registers the three handlers, each calling `startFor(TASK_SCHEDULE, <id>, TASK_MANAGER_TARGET, {}, <the list's sink>)`.
- **`ui/src/app/core/fix-finding.ts`, `core/proposal-view.ts`** -- `'task-manager': 'findingFixTaskManager'`, and `CONSEQUENCE_TASKMANAGERSUSPEND` → `taskManagerSuspendConsequence`.
- **`ui/src/app/core/strings.ts`** -- append `taskManagerSuspendAction`, `taskManagerResumeAction`, `taskManagerStartAction`, `taskManagerSuspendConsequence`, `taskManagerRefusalRunning`, `taskManagerRefusalSuspended`, `taskManagerRefusalSuspendedStart`, `taskManagerRefusalStopped`, `taskTypePrivilegeRefusal`, `taskScheduleListPrompt4` and `findingFixTaskManager`, each citing its EXPERIENCE.md line.
- **EXPERIENCE.md (in place, 993 lines)** -- the rows this story changes:
  - `:102` and `:732` drop "arrives/ships with Epic 7" and name Resume and Start Task Manager on the banner, Start requiring `%Admin_Secure:USE`;
  - `:686` adds the stopped kind;
  - `:269` gets the three action labels;
  - `:304` gets the consequence, the four refusals and the task-type privilege sentence;
  - `:562` gets the fourth prompt, "What would stop running while the Task Manager is suspended?";
  - `:582` gets the Fix-it constant; its gloss "one constant per fixable check" stays true.
- **Client tests:**
  - `ui/tools/`: `screen-mirror.test.mjs` (banner pin and corpus parity), `screen-actions.test.mjs`, `fix-finding.test.mjs` (`task-manager` fixable) and `self-protection.test.mjs` (five pins: the four `TaskManagerSuspend.cls` reasons and `Error.cls` `REASONTASKTASKCLASSPERMISSION`);
  - component specs `list-page.spec.ts`, `screen-action-handler.spec.ts`, `command-bar.spec.ts`, `command-box.spec.ts`, `task-schedule.page.spec.ts` and `home.page.spec.ts`.
- **`ui/browser/tasks.browser-spec.mjs`** -- flip `:401`, then add legs, each restoring in `finally`:
  - Suspend Task Manager → the dialog's heading and body → Proceed → the suspended banner with Resume Task Manager and rows listed → Resume → the banner is gone, with auto-refresh off;
  - Cancel sends nothing;
  - a structural walk of the dialog and the banner button in both themes (DW-1337).
- **`ui/browser/home-findings.browser-spec.mjs`** -- a Task Manager leg: suspend with the helper, check the finding shows Fix it, click it, check it lands on Task schedule and the fixed sentence is sent, then resume in `finally`.

**Acceptance Criteria:**

- **AC1.** Given the Task schedule with the Task Manager running, when the user chooses Suspend Task Manager on the command bar, then a warning dialog titled "Suspend Task Manager" states "No scheduled task will run until it is resumed." with Proceed and Cancel, and nothing is sent until Proceed. Pinned in the browser.
- **AC2.** Given the Task Manager is suspended, when the Task schedule renders, then:
  - the warning banner sits above the table with Resume Task Manager and the rows still list;
  - activating Resume resumes it, and the banner clears on the change event's re-read without a manual refresh;
  - on the next auto-refresh tick the banner follows a suspend or resume made elsewhere.

  Pinned in the browser.
- **AC3 (privilege-gated).** Given a banner case whose action's tool requires a pair the caller lacks, when the screen reads, then `bannerRequires` names that pair and the button is `aria-disabled` with "Requires <pair>".
  - Pinned by the component spec, and by `TaskManagerLive`'s stopped-state `bannerRequires` for an exact-pairs principal.
  - Resume, whose pairs are the screen's own, is never gated for a caller who can open the screen.
- **AC4.** Given `Task.Manager` publishes no body template, when the tools are built, then each is action-style: an empty field list by derivation, no hand-typed field list and no body sent. Pinned by `TaskManagerTools` and `DerivedFields`.
- **AC5.** Given a stopped Task Manager, when a caller holding `%Admin_Secure:USE` starts it from the banner or through the agent, then it runs again as `TASKMGR`. A caller without the pair is refused by name before any port call, at the mint, at Confirm and on the route. Pinned by `TaskManagerLive`.
- **AC6.** Given each tool, when either caller uses it, then it:
  - refuses the wrong verb with the published sentence;
  - fingerprints `Status`;
  - reads back `nothingSent`;
  - publishes `task/instance/manager`;
  - has an enabled governance key and a script form (`Test/DraftRegistry`);
  - carries its consequence (suspend only).
- **AC7 (Integration).** Given Home with the Task Manager suspended or stopped, when the person chooses Fix it, then Task schedule opens and the fixed sentence is sent, and the agent's proposal is an ordinary proposal of `tasks.schedule.resumemanager`, or of `startmanager` after its refusal. Pinned in `Findings`, `fix-finding.test.mjs` and the Home browser leg.
- **AC8 (DW-1638).** Given a task whose type declares a resource the caller lacks, when that caller suspends, resumes, runs, schedule-runs or deletes it, from the screen or through the agent, then the request is refused with "This task type needs a privilege you do not hold." and nothing is sent. Pinned by `TaskRowWire`.
- **AC9.** Given any test in this story's classes or specs, when it ends, whether it passed or failed, then the Task Manager on the instance reads `Running` as `TASKMGR`.

## Spec Change Log

## Review Triage Log

## Design Notes

**Measured on `ocupilot-ci`, 2026-09-30.** The transcript and the extracted source are in the session scratchpad, `epic-16/16-11/` (`tm-probe-transcript.txt`, `Api.Admin.Endpoints.Task.Manager.cls`).

- **Routes** (v2): `GET /task/manager` → `{"Status": "Running"|"Suspended"|"Not running"}` (`%SYS.Task.TASKMGRStatus()` 1/2/0), and `POST /task/manager/{suspend,resume,run}`. Each answers `{}`.
  - **Cost.** The GET takes about 1.0 s, because of the status probe's lock wait.
  - **Resources.** `ResourcesOR()` is `%Admin_Task` or `%Admin_Operate` for every type.
  - **No async, no body.** No type is async and none takes a body; a stray body or `id` query parameter is ignored.
- **SUSPEND and RESUME** are `SuspendSet(1|0)`. They answer 200 even when nothing changes. A change is audited as `%System/%System/ConfigurationChange` "Modify Task Config.Suspend", Old/New 0/1, and a call that changes nothing is not (inference, from the row counts).
- **RUN** is `StartTASKMGR()`. It answers 409 #7400 whenever the process is alive, suspended included, and never resumes. From `Not running` it answers 200 and records no audit event.
- **What each principal could do.**
  - A principal with exactly `%Admin_Task:USE` and `%DB_IRISSYS:READ` suspended, resumed and started it.
  - One with only `%DB_IRISSYS:READ` was answered 403 on every call, and the state did not change.
- **Start runs the new Task Manager with the caller's `$ROLES`. Its user switches to `TASKMGR` only when the caller holds `%Admin_Secure:USE`.**
  - Without that pair it ran as the caller. A due probe task either did not run in 80 s or failed with `<UNDEFINED>Run+11^%SYS.TaskSuper.1 *User`.
  - With the screen's pairs plus `%Admin_Secure:USE` it ran as `TASKMGR` and the task succeeded.
  - Adding `%DB_IRISSYS:WRITE`, `%Service_Login:USE`, `%Admin_Manage:USE` or `%Admin_Operate:USE` instead left the process running as the caller.
  - A `_SYSTEM` start gives `TASKMGR` with `%All`.
- **Classic page.** Only `%CSP.UI.Portal.TaskSchedule` (`RESOURCE` `%Admin_Operate`) suspends, resumes or starts the Task Manager. It has one button, Start, Suspend or Resume, and confirms each one. `%SYS.Portal.Resources` is empty.
- **Final state.** The Task Manager is running as `TASKMGR` with `%All`, and the probe user, role and task are deleted.

**Decisions.**

- **Type and id.** The target reuses `task` with the literal `manager` (the Import precedent). A new type would need a per-tool entity-type mechanism, because the mint and the route key on the descriptor's primary type (`Mint.cls:154`, `ScreenAction.cls:189`).
  - With `task`, the Task schedule re-reads on the change event, and Home already reloads findings on `task` changes.
  - `Prohibited`'s `task` arm skips the tool's `STATEFIELD`, so it needs no change.
- **The banner action is a declaration** (AD-5, the `multiSelect.action` idiom). The gate is computed by the instance, like a proposal's first missing pair (AD-8), because the client holds no pair map.
- **DW-1638** goes through `ArgumentProblem` plus `ScreenActionDelta` (the two-caller refusal idiom), not `ArgumentPairs`. The type's resource is private to the vendor (`GetResource` is `[Private]`), and reading `$Parameter` in the task's namespace would refuse callers who cannot read that namespace, a regression. As the 9.8 edit does, the check runs at the mint and on the route, and not again at Confirm.
- **Fix it** uses one constant for the check, which keeps "one constant per fixable check". The agent cannot see the Task Manager state, because the read tool's view has no banner. A wrong-verb proposal is refused with a sentence naming the right verb.
- **Where the controls live.** Suspend is always on the command bar, and a Suspend in the wrong state is refused by the server after the dialog (the 16.10 precedent). Resume and Start live only on the banner and in the command box.

**Governing ADs:**

- AD-3 (no template, action-style);
- AD-5 (banner `action`);
- AD-6 and AD-51 (subject `Status`, the adequacy of that subject);
- AD-8 (pairs, the Start amendment, the refusal naming the pair);
- AD-9 (no escalated frame around the Start);
- AD-10 (no new arm);
- AD-13 (literal id);
- AD-14 and AD-43 (banner follows change and refresh);
- AD-15 and AD-53 (suspend and resume vendor-audited, Start named);
- AD-22 (keys);
- AD-29 (measured principal);
- AD-34;
- AD-36 (`bannerRequires` is chrome, not tool view);
- AD-39 (published refusals);
- AD-44 (the descriptor's own classic page, no `CLASSICPAGES`);
- AD-52 (default `AdminPort`);
- AD-55 and AD-56 (ii) (`ScreenActionDelta`);
- AD-58 (`nothingSent`);
- AD-59 (rest `Snippet` from `AdminRoutes`).

**Spine amendments for the lead (Rule 20):**

- (a) **AD-8**, appended after the 16.25 paragraph: "**Story 16.11's Task Manager Start declares a pair beyond its screen's set** [AMENDED 2026-09-30, Story 16.11 spec gate, Rule 20]: `tasks.schedule.startmanager` declares `%Admin_Secure:USE`, because the vendor's `StartTASKMGR` starts the Task Manager with the caller's roles and switches its user to `TASKMGR` only when the caller holds that pair. A Task Manager started by a holder of Task schedule's two pairs alone ran as that caller and failed a due task (`<UNDEFINED>Run+11^%SYS.TaskSuper.1 *User`); with the pair added, it ran as `TASKMGR` and the task ran (measured on `ocupilot-ci`, 2026-09-30). It is refused by name before any port call. Suspend and resume need only the screen's pairs."
- (b) **AD-15**, named case, appended: "The ninth is starting the Task Manager (`Task.Manager` `RUN`, Story 16.11: no event with auditing on, measured on `ocupilot-ci` 2026-09-30); its suspend and resume leave `%System/%System/ConfigurationChange`." **AD-53**, named gap, appended: "The ninth: Task schedule's Start Task Manager (Story 16.11)."
- (c) **AD-5**, a bullet after `multiSelect`: "**A banner case may name the action it offers** (`action`, one of the screen's `rowActions`, Story 16.11) [AMENDED 2026-09-30, Story 16.11 spec gate, Rule 20]. The screen's read answers `bannerRequires` beside `banner`: the first pair that action's tool requires and the caller lacks, evaluated in the caller's process at each read and never part of the tool's view. The strip draws the action `aria-disabled` with that pair while it is non-empty. Validated alike by `Screen/Registry.cls` and `ui/tools/screen-mirror.mjs`."

**Named limits:**

- Every Task schedule read, mint, Confirm and read-back pays the GET's ~1 s.
- **Start keeps the starter's roles.** Even a holder of `%Admin_Secure:USE` gets a Task Manager with their own roles and not `%All`. A `%SYS` task running as `_SYSTEM` succeeded under one (measured once), and other task types under such a Task Manager are unmeasured (inference).
- A stopped Task Manager is reproduced in tests only by terminating its process, since the vendor has no stop.
- Suspending the Task Manager also stops OcuPilot's own retention task (AD-48). The dialog's sentence covers it.

**Integration.**

- Consumes: the banner (DW-270), 16.4's screen-level Import pattern, 16.10's state-refusal pattern, 16.21's Findings, 5.12's action writes, AD-53's route, and `TaskWire`'s principal helpers.
- Consumed-by: Home's findings Fix it, in this story (AC7).
- No later story consumes the banner `action` key yet. The first candidate is any future banner with a remedy.

**Ledger.** DW-1638 is addressed by the `TaskRules`, row-tool and `TaskRowWire` tasks (AC8).

**Tests leave the Task Manager running** (AC9): see Always. CI's shards regroup classes, so each class restores its own state and depends on no other's.

## Verification

This runs on slot A only. Everything that changes the Task Manager or creates a principal or task runs on `ocupilot-ci`.

Every browser run first runs `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/` and exports `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`.

Armed classes run through the lead's shim: `EPIC16_ARM="OCUPILOT_ALLOW_PRINCIPALS OCUPILOT_ALLOW_PRODUCTION_INSTALL OCUPILOT_ALLOW_TASK_CONTROL OCUPILOT_ALLOW_NAMESPACE_CONFIG" PATH=<scratchpad>/epic-16-recover/shim:$PATH`.

Only one test run may be in flight at a time.

**Commands:**

- **Tools tier (loop):** `cd ui && npm run test:tools`. Expected green, covering `screen-mirror` (banner `action` parity), `strings`, `citations`, `self-protection` (five pins), `screen-actions`, `fix-finding` and `ci`.
- **Component specs (loop):**

  ```sh
  cd ui && npx ng test \
    --include src/app/shell/list-page.spec.ts \
    --include src/app/shell/screen-action-handler.spec.ts \
    --include src/app/shell/command-bar.spec.ts \
    --include src/app/shell/command-box.spec.ts \
    --include src/app/areas/tasks/task-schedule.page.spec.ts \
    --include src/app/areas/home/home.page.spec.ts
  ```

  Expected green.
- **ObjectScript classes (loop):** `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class <C>`, one class per call. Expected green. `<C>` is each of:
  - `OcuPilot.Test.TaskManagerTools`, then `TaskManagerLive` and `TaskRowWire` (armed);
  - `TaskScheduleActions`, `TaskWire`, `TaskResume`, `TaskRules`, `Findings`, `FindingsWire`;
  - `Descriptor`, `ReadTool`, `SurfaceCoverage`, `ToolWrite`, `ToolRoundTrip`, `PortFixture`, `DraftRegistry`, `GovernanceBaseline`, `DerivedFields`;
  - `ScreenRead`, `WireSecurityRead`.
- **Browser specs (loop):** `cd ui && node --test --test-concurrency=1 browser/tasks.browser-spec.mjs browser/home-findings.browser-spec.mjs browser/task-schedule-actions.browser-spec.mjs`. Expected green within the structural baseline.
- **Once, before `dev_complete`:** `cd ui && npm test`, `uv run scripts/check-objectscript.py`, `bash scripts/lint-docs.sh`, and `wc -l` on EXPERIENCE.md. Expected green, and 993 lines.
- **The full ObjectScript sweep on `ocupilot-ci` (once, before `dev_complete`)**, one class at a time. Expected green apart from the known residue named in the spawn prompt. The full browser suite runs in CI's three shards (Rule 29).

**Mutations to demonstrate (Rule 19, one per AC; each reverted, with the tree unchanged afterward):**

- **AC1:** drop `WARNING_CONSEQUENCES[TASK_SCHEDULE]`. The handler spec and the tasks browser leg go red.
- **AC2:** the banner button is not drawn. The tasks browser leg goes red on a rebuilt, redeployed bundle.
- **AC3:** `bannerRequires` is ignored by `list-page.ts`. Its spec goes red.
- **AC4:** `TaskManagerSuspend.SENDSBODY` is set to 1. `TaskManagerTools` goes red.
- **AC5:** remove `TaskManagerStart.PrivilegePairs`'s extra pair. `TaskManagerLive`'s 403 leg goes red.
- **AC6:** `StateDiff` accepts `Suspended` for suspend. The matrix leg goes red.
- **AC7:** `Findings.TaskManager` goes back to `FIXLINK`. `Findings` goes red.
- **AC8:** drop `TaskResume.ScreenActionDelta`'s check. `TaskRowWire`'s route leg goes red.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

- **Plan only.** No source was changed. The only file written in the worktree is this spec.
- **Probes on `ocupilot-ci`:**
  - The Task Manager was suspended and resumed, and stopped by terminating its process and started through the admin API, both as the least-privileged probe principals and as `_SYSTEM`.
  - A harmless probe task (`%SYS.Task.PurgeTaskHistory`, KeepDays 36500) was run to test whether a started Task Manager works.
  - End state: running as `TASKMGR` with `%All`. The probe user, role and task are deleted.
  - The transcript and helpers are in the session scratchpad, `epic-16/16-11/`.
- **Spine amendments for the lead** (Design Notes):
  - AD-8: Start's `%Admin_Secure:USE`;
  - AD-15 and AD-53: the ninth unaudited write;
  - AD-5: the banner `action` and `bannerRequires`.
- **DW-1638** is addressed by AC8.

