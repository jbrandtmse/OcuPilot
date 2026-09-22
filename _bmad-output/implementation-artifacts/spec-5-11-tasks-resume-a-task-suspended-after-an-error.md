---
title: 'Story 5.11: Tasks - resume a task suspended after an error'
type: 'feature'
created: '2026-09-21'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Epic 5's write path has shipped three writes and all three are the same shape - a `PUT`
of a complete body merged over a fresh `GET`. Resuming a task is not that shape. The vendor exposes
it only as `Task.CRUD`'s bodyless `RESUME` request type, no `PUT` can set `Suspended`, and the state
the diff is about is absent from both the schedule list's read and the `GET` the mint reads - so the
tool, the diff row and the fingerprint the acceptance criteria describe have nothing to stand on
today. Two more gaps sit on the same path: the list cannot tell a suspended task from a running one
(DW-269), and the navigation tool refuses an `entityId` on a screen whose id is composite, which is
exactly what AC2 asks for (DW-1419).

**Approach:** Ship `tasks.schedule.resume`, the first **action-style** write - a write tool that
declares its own admin request type, admits no settable fields and sends no body, while every gate,
the lock, the fingerprint and the marker stay where they are. Give the schedule list `Task.CRUD`'s
truthful `Suspended` through the `INFO` `rowGet` AD-36 names (DW-269), which is also what makes the
proposal's fresh read, its one state diff row and its fingerprint exclusions expressible. Widen the
navigation tool's `entityId` to a composite id of exactly one part, and make a list select the row
its own route names - closing DW-1419 for the agent's navigation and the toast's "Open in
&lt;screen&gt;" together.

## Boundaries & Constraints

**Always:**

- The resume is `Task.CRUD` `RESUME`. Measured on the instance 2026-09-21: `Parameter TYPERESUME = 14`
  ("introduced in v2, replacing PATCH /v1/task"), `Run` dispatches it, `NeedsRequestBody()` excludes
  it, `ValidateQueryParams` requires the `id` query parameter, `ResourcesOR()` answers
  `$LISTBUILD("%Admin_Task")` alone for it, and `ShouldRunAsync()` is not overridden. `RunResume` is
  `Set sc = obj.Resume(obj.%Id())` with the vendor's own comment *"this returns ok even if it is not
  suspended"*.
- **It cannot be a merge write.** `MergeJsonAndObj`'s settable list omits `Suspended`, `RunPut` only
  `%Save()`s, and `TaskToJson` (the `GET`) carries no `Suspended` at all. Only `RunInfo` answers it
  (`Do ret.%Set("Suspended", obj.Suspended, "boolean")`).
- Everything the write path already does still happens, unchanged and in the same places: minted on
  the instance from a fresh read with a single-use token and a ten-minute expiry; confirm a separate
  authenticated POST refused to a caller carrying the turn marker; the prohibited set,
  `Restraint.Verdict`, the declared pairs and the fingerprint re-read all evaluated inside AD-34's
  one transition under the per-target lock; the marker emitted from `Confirm.Transition`'s one site
  after the write reads OK, with `$System.Security.Audit`'s return value checked.
- The pair set is the screen's own - `%Admin_Task:USE` and `%DB_IRISSYS:READ` - at `USE`, never
  `WRITE` (AD-8 as amended 2026-09-21). The vendor's RESUME gate is `%Admin_Task` alone, which the
  screen already declares, so `PrivilegePairs()` adds nothing new.
- The entity type is `task`, already a member of the kernel enum. This story adds its AD-13
  canonicalization rule and its `Prohibited` branch.
- The Task schedule list keeps the five columns `EXPERIENCE.md:102` declares. `Suspended` joins the
  **read**, not the table.
- Every state-changing check runs on the throwaway `ocupilot-ci` (`http://localhost:52776`). Never
  resume or suspend a task on `ocupilot`. A class or spec that resumes the demo task restores the
  suspended-after-an-error state on **every** exit path, teardown *and* an in-method frame after
  `Try`/`Catch` (the 5.10 pattern) - and releases the task OREF immediately after any `RunNow`,
  because `%SYS.Task.RunNow` leaves an exclusive lock the Task Manager then skips
  (`.claude/rules/objectscript-basics.md`).
- Tests run one class or suite per invocation, waiting for each to land in `%UnitTest_Result`.

**Never:**

- No new screen descriptor, no Angular page, no side-bar entry. The destination is the **existing
  Task schedule list**; retargeting at Task details is Story 7.6's one-line change.
- No row action and no primary action on `TaskScheduleList`. Story 7.6 declares the Run, Suspend,
  Resume and Delete row actions together with their handlers; `epics.md:3935`'s amendment forbids an
  inert control shipping ahead of its handler.
- Nothing writes to `%SYS.Task.History`. That table is the vendor's; the agent mark is the audit row
  AD-15 emits (see Design Notes).
- No suspend tool, no Task Manager controls, no Run, no Delete (Story 7.6, Epic 16).
- **No task-specific prohibition invented.** AD-10's Release 1 set names none for tasks, and adding
  one is a spine change, not a story's.
- No second composite grammar (AD-5). `entityId` widens to a composite of exactly **one** part; a
  composite of two or more parts and an id kind of `none` stay refused `NAV.ENTITYNOTALLOWED`.
- No `docker compose up`/`down`/`restart` against `ocupilot` or any `ocupilot-slot-*` container; no
  teardown of a throwaway this session did not start.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Resume proposed | agent calls `tasks.schedule.resume` with the task's id, task is suspended after an error | proposal minted from a fresh `Task.CRUD` `INFO` read; **one** diff row `Status: Suspended -> Scheduled`; no unchanged-fields caption; `destructive` false | No error expected |
| Target is not suspended | the same call against a task whose `INFO` answers `Suspended` false | **refused at the mint**, naming that the task is not suspended; no proposal row, no card | `PROPOSAL.*` refusal reason; the vendor's own "ok even if it is not suspended" never reached |
| Resumed by someone else in between | proposal live, another party resumes the task, user presses Confirm | fingerprint mismatch: refused, the row closes, the card offers **only** Re-propose | AD-6's mismatch refusal, unchanged |
| Resume confirmed | user presses Confirm | `Task.CRUD` `RESUME` issued with `id` and **no body**; `INFO` then answers `Suspended` false; one `changed` event `(task, instance, <id>)` with action `updated`; marker emitted and the ledger row reads marked | a port fault passes through as its own envelope; the ledger row closes `error` and claims no marking |
| Two spellings of one task id | agent sends `"007"`, then `"7"`, for the same task | both canonicalize to one key, so the second proposal is the first's sibling: one lock, one cancel (AD-13, AD-34) | the loser is refused with the terminal state, never retried |
| A field on a bodyless write | a proposal for a `task` target carries any changed field | refused by `Prohibited` - `PermittedChangeFields("task")` is empty, so no field is permitted | `PROHIBITED.UNCOVEREDFIELD` |
| DW-269: suspended in a list read | the schedule list is read while a task is suspended | the row's `Suspended` is **true**, taken from the same endpoint's `INFO` per row (AD-36's `rowGet`); the read tool's view carries it too | a row whose `INFO` answers 404 is dropped; any other detail fault fails the whole read |
| DW-1419: navigation selects the row | agent calls `shell.screen.open` with `route` `tasks/schedule` and that task's `entityId` | accepted (composite of one part); the browser opens `tasks/schedule/<encoded id>` and the list **selects** that row - `aria-selected` true | a route the instance does not build is `NAV.ROUTEUNKNOWN`; a composite of two or more parts stays `NAV.ENTITYNOTALLOWED` |
| DW-1419: the toast's link | a `changed` event arrives while the schedule list is not open, the user activates "Open in Task schedule" | the same route, and the same selection on arrival - one mechanism, two callers | none |
| An id segment naming no row | the route carries an id the current rows do not contain | the list renders normally with nothing selected; no error and no empty state | none |
| Least-privileged confirm | caller holds neither `%Admin_Task:USE` nor `%DB_IRISSYS:READ` | 403 naming the failed pair; the task stays suspended | `AUTH.NOPRIVILEGE` with `detail.failedPair` |
| A live proposal against a task | a `task` proposal is open while the schedule list is showing | the screen's auto-refresh pauses with the chip; it resumes on close (AD-43) | none |

</intent-contract>

## Code Map

Line anchors read in this checkout on 2026-09-21. Vendor facts carry the probe that produced them.

### Measured on the live instance, 2026-09-21 (read-only probes, `server: "ocupilot-slot-a"`)

- `%Api.Admin.Endpoints.Task.CRUD` (`[ Hidden ]`, fetched with
  `%Compiler.UDL.TextServices.GetTextAsString`): `TYPEHISTORY` 10, `TYPEINFO` 11, `TYPERUN` 12,
  `TYPEUPCOMING` 13, **`TYPERESUME` 14**, `TYPESUSPEND` 15. `Run` is a `$CASE` dispatching all six.
  `NeedsRequestBody()` is `IsTypePatch() || IsTypePut() || IsTypePost() || TYPERUN || TYPESUSPEND` -
  **`TYPERESUME` is absent, so RESUME carries no body**. `ValidateQueryParams` returns early only for
  LIST, POST, HISTORY and UPCOMING, so RESUME takes `..Id = ..GetRequiredQueryParam("id")`.
  `ResourcesOR()` answers `$LISTBUILD("%Admin_Task")` for PATCH, RUN, RESUME and SUSPEND, and
  `$LISTBUILD("%Admin_Task","%Admin_Operate")` otherwise. `ShouldRunAsync()` is not overridden.
- `RunInfo` returns `Type`, `Status`, `Error`, `LastSchedule`, `LastStarted`, `LastFinished`,
  `NextScheduled` and, last, `Do ret.%Set("Suspended", obj.Suspended, "boolean")`. **`Status` here is
  `%SYS.TaskSuper.Status`, the last run's result** (1 success, -1 running, -2 untrapped error ...),
  not a suspend state.
- `RunList` applies `queryRunner.TreatColumnAsBoolean("Suspended", 1)` to a column whose display
  values are `''`, `'Suspend Leave'` and `'Suspend Reschedule'` - none contains "YES" - which is
  DW-269's coercion, at its origin.
- `MergeJsonAndObj`'s settable list (`p0` plus the email, display-value, date and `Settings` arms)
  contains no `Suspended` and no `Status`; `TaskToJson` emits neither. **No PUT can resume a task.**
- `%SYS.TaskSuper.Suspended` is `%Integer` with `VALUELIST=",0,1,2"` /
  `DISPLAYLIST=",,Suspend Leave,Suspend Reschedule"`. `Resume(ID)` is documented "Resume a Task
  previously suspended using Suspend or Suspended due to Error"; its body is stripped in the UDL
  export (`System = 4`).
- `%SYS.Task.History`'s own class comment: *"Used to track events in the TASKMGR environment / When
  jobs are completed / Deletion of tasks / Updates to Configuration data / Starting of the TASKMGR /
  **Suspending/Resuming Tasks or TASKMGR**"*. Its columns include `Username`, `Status`, `Error`,
  `ExecuteCode`, `LogDate`, `LogTime`, `Task`. **Which user a resume row records is not yet measured
  - measure it on the throwaway before pinning AC4.**

### The write path's three PUT assumptions

- `src/OcuPilot/Port/AdminPort.cls:118` `TYPESUFFIXES = "GET,LIST,INFO,CERTINFO,UPCOMING,HISTORY,VOLUMELIST"`;
  `:137` `MUTATINGTYPES = "PUT"`. `:405` refuses a `MUTATINGTYPES` call whose `pBody` is not an
  object (the silent-success guard). `:747-754` `HttpMethodFor` answers the suffix itself for a
  mutating type and `GET` otherwise; `:763-778` `EndpointType` refuses a suffix in neither list;
  `:780-792` `ImplementsRead` answers 1 whenever the class overrides `Run`, which `Task.CRUD` does.
  `:891-898` is `Sequence`'s mutating-and-async refusal (DW-1279), which reads `%request.Method`.
- `src/OcuPilot/Kernel/Proposal/Mint.cls:22` `READTYPE = "GET"`; `:137` the fingerprint is taken
  **over the merged payload** with the descriptor's `FingerprintExcludes`; `:259` reads the tool's
  `Destructive()`; `:278-330` `Merge` copies the fresh read, overwrites each `pSettable` field the
  arguments name, and pushes one `{field, before, after}` per changed value - **the diff exists only
  where a settable field moved**.
- `src/OcuPilot/Kernel/Proposal/Confirm.cls:41` `READTYPE = "GET"`, `:47` `WRITETYPE = "PUT"`, used
  once at `:379` `Invoke(tEndpoint, ..#WRITETYPE, .tQuery, tBody, ...)`; `:360` `WithSecrets` builds
  the body; `:368` `FieldNames` feeds the ledger; `:551-592` `FingerprintMatches` re-reads, digests
  with the same excludes and compares.
- `src/OcuPilot/Screen/Descriptor/Base.cls:485` `FingerprintExcludes` reads the descriptor's
  `fingerprintExcludes`. `src/OcuPilot/Screen/Registry.cls:1989-1995` is the only membership test:
  an excluded name must be a settable field of the screen's write tool **or** a name its read
  declares - so with no settable fields, every exclusion must be a read-declared name.

### The tool seams

- `src/OcuPilot/Screen/Tool/Write.cls`: `DESTRUCTIVE`/`Destructive()` (`:47`, `:59`), `Endpoint()`,
  `SettableFields()`, `IdArgument()` (default `"Name"`), `IdParam()` (default `"name"`),
  `ExcludedFields()`, `PermittedFields()`, `SecretArguments()`, `FieldRows()`, `AdmittedFields()`,
  `InputSchema()` (id property required, `additionalProperties: false`), `ResultSchema()`, and
  `View()` at `:249` - **`[ Final ]`**, the only method the model reaches.
- `src/OcuPilot/Screen/Tool/AuditingUpdate.cls` is the newest precedent (Story 5.10) and
  `UserUpdate.cls` the one before it; both implement `PrivilegePairs()` the same way - the screen's
  own `Gate.RequiredPairs` unioned with `WRITERESOURCE:WRITEPERMISSION`, appended only when
  `$ListFind` misses it. Both are merge tools; **no action-style write tool exists in the tree.**
- `src/OcuPilot/Screen/Tool/ToolFields.cls` holds three entries today -
  `permissions.users.update`, `security.auditing.update`, `webapp.list.update`. Generated by
  `ui/tools/field-lists.mjs` from `FieldLists.cls` joined with `Classification.cls`; `--check` runs
  at prebuild. `src/OcuPilot/Screen/Tool/FieldLists.cls:426-465` already carries `Task.CRUD`'s
  `PutAndPostSchema` rows (37, `Suspended` not among them); `:466` is `Task.Manager` with
  `"source":"none"` and `"rows":[]` - the shape for an endpoint publishing no template.

### The descriptors

- `src/OcuPilot/Screen/Descriptor/TaskScheduleList.cls`: route `tasks/schedule`, `built: true`,
  archetype `list`, entity `task`, scope `instance`, `id` `{"kind":"composite","parts":["Id"]}`,
  privileges `%Admin_Task:USE` + `%DB_IRISSYS:READ`, `refreshes: true` at rates 5/10/30/60,
  `toolIdentifier "tasks.schedule"`, **no `rowActions`, no `primaryAction`, no `rowGet`, no
  `fingerprintExcludes`**, read fields
  `["Name","Type","Namespace","Description","Id","LastFinished","NextScheduled"]`, five table
  columns, and a `Task.Manager` `GET` banner. Its own doc comment records why `Suspended` is absent
  and that taking it from `INFO` is DW-269's.
- `src/OcuPilot/Screen/Descriptor/TaskDetails.cls` is the **working `INFO` `rowGet` precedent**:
  `{"key":"taskId","param":"id","type":"INFO","fields":["Type","Suspended","Error","LastStarted","LastFinished","NextScheduled"],"derived":[]}`.
  `X509CredentialList.cls` is the `CERTINFO` one.
- `src/OcuPilot/Screen/Descriptor/TaskHistoryList.cls` already declares `Username` in `read.fields`,
  in `filter`, in `context.fields` and as a table column - **AC4's attribution is readable through
  the existing screen and its `tasks.history` read tool with no descriptor change.**
- `src/OcuPilot/Screen/Read.cls:789` `DetailRow` resolves `pRowGet.%Get("type")`, defaulting to
  `#DETAILTYPE` (`GET`), and invokes the port with it. `src/OcuPilot/Screen/Registry.cls:1704`
  `ROWGETTYPES = "GET,INFO,CERTINFO"`; `:1720` `RowGetProblem`. Mirror: `ui/tools/screen-mirror.mjs`
  `rowGetProblem()` ~`:1914` with its own `ROWGETTYPES` ~`:1886`.

### Identity, the prohibited set and coverage

- `src/OcuPilot/Kernel/EntityType.cls` `TYPES` already contains `task` and `task-history-entry`;
  `Count()` is 29, asserted at `src/OcuPilot/Test/Descriptor.cls:1278`. **No enum change.**
- `src/OcuPilot/Kernel/EntityRef.cls:59`
  `IDRULES = "web-application:foldcase-striptrailingslash,user:foldcase,auditing-configuration:singleton"`,
  `:64` `IDRULENAMES`, `:239` `IdRuleFor`, with the verbatim answer for a type with no rule. Client
  twin `ui/src/app/core/entity-ref.ts:64-91`; mirror roster `ui/tools/screen-mirror.mjs:154-158`
  `IMPLEMENTED_ID_RULES` with four named refusals at `:1951-2004`; pinned by
  `ui/tools/entity-ref.test.mjs:45,205`.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls:88`
  `COVEREDTYPES = "web-application,user,auditing-configuration"`; `:91`/`:93`/`:95` the three type
  constants; `:151-160` `CoveredTypes()`; `:188` `PermittedChangeFields`; `:204`
  `AlwaysProhibitedFields`; `:250` the fail-closed arm for a listed type with no branch; `:331`
  `WebApplication()`, `:395` `User()`, `:461` `Auditing()` - the shortest branch and the one to copy.
- `src/OcuPilot/Test/Prohibited.cls:178` asserts `CoveredTypes()` is exactly the three-type string;
  `~:163` uses `"task"` as one of its **uncovered** examples; `~:380` asserts `UncoveredWriteTools()`
  empty - **that one reddens the moment the new tool compiles unless `task` is covered in the same
  change**.
- `src/OcuPilot/Test/SurfaceCoverage.cls:105-124` `DeriveScreens`, with `:119` `If 'tBuilt Continue`
  - DW-1453's line; `:53` the first `<screen>` row, `:93` the first `<tool>` row, `:219-240`
  `Drift()`, `:249-259` the built-screen assertion, `:267-278` the per-tool assertion (no `built`
  gate on the tool half). Exactly one `built: false` descriptor exists in the tree today:
  `src/OcuPilot/Screen/Descriptor/AuditingConfig.cls`.

### Navigation, selection and the highlight

- `src/OcuPilot/Screen/Tool/Navigate.cls`: `:18-21` the doc paragraph declaring the composite
  refusal; `:53-68` `BuiltRoutes()`; `:74-102` `InputSchema` with the `route` enum and the
  `entityId` property; `:175-217` `Directive`, whose guard is
  `If (tEntityId '= "") && ($ClassMethod(tTargetDescriptor, "IdKind") '= "single")` -> `NAV.ENTITYNOTALLOWED`.
- `ui/src/app/shell/agent-navigator.ts:18` `NAVIGATIONDELAYMS = 1000`, `:80` the timer, `:96`
  `route + '/' + encodeEntityId(entityId)`, `:97` `navigateByUrl`, `:102-105` the heading
  announcement, `:108` the departing screen's refusal. `ui/src/app/core/turn.ts:394-402`,
  `:1192-1198` keep the announcement ahead of the directive. String
  `ui/src/app/core/strings.ts:194` `agentNavigationHeadingAnnouncement`.
- `ui/src/app/shell/list-page.ts` injects `Router` only, and reads the URL solely through
  `parentCriteria(screen, this.router.url)` at `:101`, which short-circuits for a screen whose
  `parentScope` is `""` (`ui/src/app/core/navigation.ts:306-314`). **Nothing reads this screen's own
  trailing id segment.** `ui/src/app/app.routes.ts:62-79` already registers `${screen.route}/:id`
  for any `id.kind !== 'none'` (`navigation.ts:429-430` `hasIdRoute`), so `tasks/schedule/:id`
  routes today.
- Selection already exists: `ui/src/app/core/screen-store.ts:282-287` `selection()/setSelection()`
  and `:340-363` `pendingSelection()/setPendingSelection()/clearPendingSelection()`, consumed by
  `ui/src/app/shell/data-table.ts:962-971` `applyPendingSelection()` (sets active + selection once
  the row is present). Rendered at `data-table.ts:230-234`:
  `[attr.aria-selected]="row.selected"` and `[class.ocu-data-table-row-selected]`.
- Toast: `ui/src/app/core/toasts.ts:189-210` `publish`, which builds `<route>/<encoded id>` via
  `navigation.ts:411-421` `screenForChange`; `ui/src/app/shell/toast-host.ts:193-198` `open()`;
  `:61` the `--ocu-panel-live-width` offset; `strings.ts:216` `tableChangeToastLink`.
- Highlight: `data-table.ts:1013-1019` `viewKeyFor`, `:1030-1039` `changedKeyFor`, `:234`
  `ocu-data-table-row-changed`, `:1041-1052` `scrollChangedIntoView`, `:1058-1063` the clear on
  select; `ui/src/app/core/refresh.ts:607-619` the `changed` subscription with its immediate
  `readNow()`, `:621-628` the `proposal-open`/`proposal-closed` pause, `:309-310` `paused()`,
  `strings.ts:222` `statusAutoRefreshPaused`.
- The two DW-1419 pinning tests that assert only the URL: `ui/src/app/shell/toast-host.spec.ts:161-172`
  and `ui/src/app/shell/agent-navigator.spec.ts:167-171`. jsdom can read `aria-selected` -
  precedent `ui/src/app/shell/data-table.spec.ts:472` and `:629-636`.

### The fixture and the browser precedents

- `src/OcuPilot/Install/Fixture.cls:528` `CreateTask` creates a `%SYS.Task` whose `TaskClass` is
  `OcuPilot.Install.DemoTask` with `SuspendOnError = 1`, calls `RunNow` and never waits;
  `OcuPilot.Install.DemoTask.OnTask()` throws deliberately, which is the only supported route to
  `Suspended` plus a populated `Error`. `OcuPilot.Test.Demo.TestDemoTaskIsSuspendedAfterAnError`
  polls for the suspended state. **The precondition already exists; nothing is added to the fixture.**
- Browser precedents to extend rather than rebuild: `ui/browser/auditing-write.browser-spec.mjs`
  (5.10's confirm end-to-end), `ui/browser/change-highlight.browser-spec.mjs` (5.7's two-second
  budget and scroll), `ui/browser/navigate.browser-spec.mjs` (4.7's announcement timing and Back),
  `ui/browser/tasks.browser-spec.mjs` (the Tasks area, whose header assertion at `:317-323` pins the
  five columns), helpers `ui/browser/panel-spec.mjs:99` `saveAndSettle` and
  `ui/browser/turnprobe-spec.mjs:77,132,151,171,213` (`nextTag`, `setTag`, `scriptReply`,
  `armProbeDefinition`, `requireFreeSlot`).

## Tasks & Acceptance

**Execution:**

1. `src/OcuPilot/Port/AdminPort.cls` -- admit `RESUME` as a **bodyless** mutating request type --
   `MUTATINGTYPES` is what `EndpointType` (`:771`) and `HttpMethodFor` (`:753`) read, and `:405`'s
   object-body refusal must not fire for a type the vendor declares needs no body. Keep `Sequence`'s
   mutating-and-async refusal (`:891-898`, DW-1279) firing for it, and say in the doc comment that
   the value `%request.Method` carries for RESUME is the vendor's request-type suffix rather than an
   HTTP verb.
2. `src/OcuPilot/Screen/Tool/Write.cls` -- add the three seams an action write needs, each defaulting
   to today's behavior: `ReadType()` (`GET`), `WriteType()` (`PUT`) and `SendsBody()` (1). Make
   `InputSchema`/`AdmittedFields` tolerate an empty admitted-field set, so the schema is the id
   property alone under `additionalProperties: false`. `View()` stays `[ Final ]`.
3. `src/OcuPilot/Kernel/Proposal/Mint.cls` -- take the fresh read's request type from the tool
   (`ReadType()`) instead of `#READTYPE`, and give a tool with no settable fields a declared **state
   diff**: one `{field, before, after}` row the tool computes from the fresh read, with a refusal
   when the target is not in the "from" state. The fingerprint keeps being taken over the stored
   object with the descriptor's excludes (`:137`), unchanged.
4. `src/OcuPilot/Kernel/Proposal/Confirm.cls` -- take the read and write request types from the tool,
   and send **no body** when `SendsBody()` is 0, so `:379`'s `Invoke` issues `RESUME` with the id
   query parameter alone. The ledger's `FieldNames` is empty for such a write, and the confirm
   channel stays closed by the tool declaring no secret arguments.
5. `src/OcuPilot/Kernel/Proposal/Disclosure.cls` -- a write that sends no body has **no** unchanged
   rows and no caption: the stored object is the fingerprint's subject, not a payload. This is also
   what keeps the vendor's own `Status` field (the last run's result) off a card whose one diff row
   is labeled `Status`.
6. `src/OcuPilot/Screen/Tool/TaskResume.cls` -- the new tool. `TOOLNAME "tasks.schedule.resume"`,
   `DESCRIPTORCLASS` the schedule list, `Endpoint()` `"Task.CRUD"`, `IdArgument()` `"Id"`,
   `IdParam()` `"id"`, `SettableFields()` empty, `ReadType()` `"INFO"`, `WriteType()` `"RESUME"`,
   `SendsBody()` 0, `Destructive()` 0, `WRITERESOURCE "%Admin_Task"`, `WRITEPERMISSION "USE"`,
   `PrivilegePairs()` on the `AuditingUpdate` pattern, and the state diff row
   `Status: Suspended -> Scheduled` with its not-suspended refusal.
7. `src/OcuPilot/Screen/Descriptor/TaskScheduleList.cls` -- declare the `INFO` `rowGet`
   `{"key": "Id", "param": "id", "type": "INFO", "fields": ["Suspended"], "derived": []}`
   (`TaskDetails.cls:63` is the shape; `Id` is the row field already in `read.fields` that carries
   the vendor's numeric task id), and add `Suspended` to `read.fields` and `context.fields`. Then
   declare `fingerprintExcludes` for whichever `INFO` fields the measurement below shows moving
   under a suspended task, adding each to the `rowGet`'s own `fields` in the same edit -- an
   exclusion must be a read-declared name (`Registry.cls:1989-1995`). Declare none if nothing moves.
   Leave the five table columns, the banner and the absent row actions exactly as they are, and
   correct the doc comment's DW-269 paragraph at its origin rather than appending to it. (DW-269)
8. `src/OcuPilot/Kernel/EntityRef.cls` -- add `task:integer` to `IDRULES`, `integer` to
   `IDRULENAMES`, a `RULEINTEGER` constant and its arm in the rule application: a task id
   canonicalizes to its integer spelling, so `"007"`, `"+7"`, `" 7 "` and `"7"` are one key; a value
   the rule cannot read as an integer is answered verbatim, as a type with no rule is. AD-13 obliges
   each write-tool story to add its own type's rule, and a numeric id has more than one spelling.
9. `ui/src/app/core/entity-ref.ts` and `ui/tools/screen-mirror.mjs` -- the client twin and the
   `IMPLEMENTED_ID_RULES` roster entry for the new rule, so the mirror does not throw at prebuild on
   a rule the client cannot implement.
10. `src/OcuPilot/Kernel/Proposal/Prohibited.cls` -- add `task` to `COVEREDTYPES`, a `TYPETASK`
    constant, and a `Task()` branch on the `Auditing()` shape: `PermittedChangeFields("task")` is
    empty and `AlwaysProhibitedFields("task")` is empty, so a `task` proposal carrying **any**
    changed field is refused. AD-10 names no task prohibition, and this story invents none.
11. `src/OcuPilot/Screen/Tool/Navigate.cls` -- accept `entityId` when the target's `IdKind()` is
    `single` **or** a composite of exactly one part; keep the refusal for every other composite and
    for `none`. Replace the `:18-21` doc paragraph's claim with the rule as it now stands. (DW-1419)
12. `ui/src/app/core/navigation.ts` and `ui/src/app/shell/list-page.ts` -- one helper that reads a
    list screen's **own** trailing id segment (as `parentCriteria` reads a parent's) and hands the
    decoded id to the store's existing pending-selection path, so the row is selected on arrival.
    One mechanism serves the agent's navigation and the toast's "Open in &lt;screen&gt;"; an id
    naming no present row selects nothing and is not an error. (DW-1419)
13. `src/OcuPilot/Test/SurfaceCoverage.cls` -- drop the `built` filter at `:119` so an unbuilt
    descriptor enters the roster, and add the `<screen>` row for `AuditingConfig`, the one
    `built: false` descriptor in the tree. Add the `<tool>` row for `tasks.schedule.resume`. (DW-1453)
14. `src/OcuPilot/Test/Prohibited.cls` -- update the `CoveredTypes()` literal at `:178`, drop `task`
    from the uncovered-example list at `~:163`, and keep `~:380`'s empty-`UncoveredWriteTools`
    assertion green.
15. `src/OcuPilot/Test/Descriptor.cls` -- update the task-schedule method's three absence assertions
    (no `rowGet`, the exact `read.fields` array, no `"Suspended"` anywhere in the read) to the new
    declaration, and keep the tripwire note in its doc comment accurate.
16. `src/OcuPilot/Test/TaskResume.cls` -- the story's own instance suite: the mint's diff row and its
    not-suspended refusal, the bodyless `RESUME` reaching the port with the id parameter and no body,
    the fingerprint refusing a target resumed in between, the two-spellings-one-key leg, the
    `Prohibited` field refusal, the marker and the ledger row, and the `INFO` `rowGet` answering
    `Suspended` truthfully for a suspended task in a list read. Restores the suspended-after-an-error
    state on every exit path.
17. `src/OcuPilot/Test/ProhibitedRoute.cls` -- one least-privileged leg over the wire: an account
    short of the declared pair is refused 403 naming it, and the task stays suspended (AD-29's
    sufficiency half, established the two ways AD-29 requires).
18. `src/OcuPilot/Test/ToolWrite.cls` -- the new tool's registration: its pairs at `USE`, its empty
    settable set, its `RESUME` write type, its `INFO` read type and `Destructive()` 0.
19. `ui/tools/entity-ref.test.mjs`, `ui/tools/screen-mirror.test.mjs`, `ui/tools/navigation.test.mjs`
    -- the new id rule in both directions, the `rowGet` mirror, and the composite-of-one `entityId`
    and own-id-segment helpers.
20. `ui/src/app/shell/list-page.spec.ts`, `ui/src/app/shell/agent-navigator.spec.ts`,
    `ui/src/app/shell/toast-host.spec.ts` -- assertions that the **row is selected**
    (`aria-selected`), not only that the URL is right; these replace what DW-1419 names as
    URL-string-only.
21. `ui/browser/task-resume.browser-spec.mjs` -- the end-to-end leg: read cards in order, the
    announcement before the route change, the destination heading, the row selected on arrival, the
    card's one diff row, Confirm, the re-fetch and the highlight inside two seconds, and the
    auto-refresh pause while the proposal is live. Refuses in `before()` unless
    `OCUPILOT_BROWSER_CONTAINER` names a `-ci` throwaway.
22. `src/OcuPilot/Screen/Tool/ToolFields.cls` (generated) -- regenerate with
    `node tools/field-lists.mjs`; add the tool's `Classification.cls` entry only if the generator
    requires one. The resume admits no fields, so its row set is empty -- `FieldLists.cls:466`'s
    `Task.Manager` `"source":"none"` entry is the shape.

**Acceptance Criteria:**

- **Given** a task suspended after an error, as the demo fixture creates, **when** the agent reads
  the task schedule, **then** that row's `Suspended` is true in both the screen's rows and the
  `tasks.schedule` read tool's view, taken from the same endpoint's `INFO` per row. (DW-269)
- **Given** the agent has read the schedule and that task's history in order, **when** it calls
  `shell.screen.open` with `tasks/schedule` and that task's id, **then** the announcement is posted
  first, the route changes about a second later to `tasks/schedule/<encoded id>`, the heading
  announces it was opened by the agent, and **the row is selected** - `aria-selected` true. (DW-1419)
- **Given** the same navigation arrives instead from the off-screen toast's "Open in Task schedule",
  **when** the list loads, **then** the same row is selected by the same mechanism. (DW-1419)
- **Given** a suspended task, **when** the agent calls `tasks.schedule.resume` with its id, **then**
  a proposal is minted from a fresh `INFO` read carrying exactly one diff row
  `Status: Suspended -> Scheduled`, no unchanged-fields caption, and `destructive` false.
- **Given** a task that is not suspended, **when** the same call is made, **then** it is refused at
  the mint with a reason naming that the task is not suspended, and no proposal row exists.
- **Given** a live proposal and a task another party has resumed since it was minted, **when** the
  user presses Confirm, **then** the fingerprint refuses it, the row closes and the card offers only
  Re-propose.
- **Given** a live proposal, **when** the user presses Confirm, **then** `Task.CRUD` `RESUME` is
  issued with the id query parameter and **no body**, the task's `INFO` answers `Suspended` false
  afterwards, the schedule list re-fetches in place and highlights that row within two seconds, and
  the agent's reply names the next run and offers the audit entry.
- **Given** the same confirmed resume, **when** the audit database is read, **then** one OcuPilot
  agent-write marker carries that proposal id, that tool, the scoped `(task, instance, <id>)` target
  and that user, and the ledger row reads marked (AD-15's ordinary case - this write does not close
  the audit channel).
- **Given** the same confirmed resume, **when** the task's own history is read through the existing
  `tasks.history` read, **then** it shows the resume attributed to that user.
- **Given** a live `task` proposal, **when** the Task schedule list is open, **then** its
  auto-refresh pauses with the chip and resumes on close (AD-43).
- **Given** a caller holding neither `%Admin_Task:USE` nor `%DB_IRISSYS:READ`, **when** they confirm,
  **then** they are refused 403 naming the failed pair and the task stays suspended.
- **Given** the surface floor, **when** the suite runs, **then** the coverage roster covers unbuilt
  descriptors as well as built ones, `AuditingConfig` has its row, `tasks.schedule.resume` has its
  row, and `UncoveredWriteTools` is empty. (DW-1453)

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs (Rule 6).** AD-1 (in-process, as the user), AD-2 (the port reproduces the vendor
sequence once, and only `AdminPort` names an `%Api.Admin.*` class - admitting `RESUME` happens
there), AD-3 (a RESUME publishes no template and needs none; its field list is empty, not
hand-typed), AD-5 (one descriptor, one composite grammar, tool identity independent of the screen's
name), AD-6 (minted, fingerprinted, single-use, closed confirm channel), AD-8 **as amended
2026-09-21** (the screen's own pair set, administrative resources at `USE`), AD-10 (the prohibited
set has one home, is evaluated at the write, and names nothing about tasks), AD-11 clause 3 and its
client-fulfilled navigation tool, AD-12/AD-39 (one envelope, two renderings), AD-13 **as amended**
(the scoped triple, and this story's own per-type canonicalization rule), AD-14 (one change event;
screens re-fetch, never patch), AD-15 (ordinary case - the marker never fails the write), AD-24 (the
`rowGet`'s fields ride inside the same caps), AD-26 (RESUME is synchronous; `ShouldRunAsync()` is not
overridden), AD-29 (the pair set established two ways together), AD-34 (one atomic transition, one
lock per canonical target), AD-36 (the `rowGet`, whose `INFO` clause cites this exact `Task.CRUD`
coercion as its probed example), AD-40 (confirm is user-originated; every gate is at the write),
AD-41 (the ledger row finalized after the write), AD-43 (Task schedule is on the seven-screen
roster, so a live `task` proposal pauses it), AD-44 (the classic key, unchanged), AD-45, AD-46,
AD-9, AD-30, AD-31, AD-33, AD-35, AD-37 hold and this story changes nothing in them.

**Consumes:** 5.1-5.7 (mint, card, atomic confirm, execution as the user, the prohibited set's
wholesale refusal, the marker, the change bus, the toast and the highlight); 5.8 (the `USE` pair
rule); 5.9 (the per-type id rule with its client twin, the per-type `Prohibited` block); 5.10 (the
declared-names union both confirm-channel validators share, and the in-method restore pattern); 2.8
(the schedule list and its banner); 6.6 (Task history, whose `Username` column AC4 reads); 4.7 (the
navigation tool and its announcement ordering). Epic 13's coverage gates.

**Consumed-by:** Story 7.6 retargets this story's navigation at the Task details route and adds the
Run, Suspend and Delete row actions on the same descriptor. Story 5.12 is the second action-style
write (process suspend and resume) and consumes seams 2-5 above rather than re-deriving them; 5.13
is the third (`SYS.ApplicationError` deletes, AD-48). Story 7.4 and Epic 16 consume the Task Manager
half, not this one. The `Suspended` the `rowGet` now answers is also what Home's suspended-tasks
attention line has been waiting for (`EXPERIENCE.md:552`); lighting that line is not this story's.

**The first action-style write, and why the invariants still hold.** The vendor gives exactly one way
to resume, and it carries no body, so three PUT assumptions become per-tool declarations rather than
kernel constants. Each invariant lands as follows, and none of them is relaxed:

- **AD-4** prevents "a confirmed change to two fields silently erasing the other forty". A write that
  sends no body erases nothing, so AD-4's merge idiom is not being avoided - it has no subject here.
  AD-3 already anticipates this class of endpoint (`Task.Manager`, `Process` and `Lock` are named
  "action-style with trivial or empty bodies"), so a bodyless write is a shape the spine plans for
  rather than one this story invents.
- **AD-6's fingerprint** covers the complete property set of the fresh read the diff was computed
  from, minus the descriptor's declared exclusions. For a merge write that is the same set as "the
  property set the write will send", because AD-4 makes the body a copy of the fresh read; for a
  bodyless action it is the same fresh read. The invariant AD-6 protects - a write against state
  that moved under the diff is refused - is preserved either way, and `Suspended` is inside it, so a
  task someone else resumed in the window is refused.
- **AD-10** is still evaluated inside AD-34's transition, over a `task` branch that lives in the
  kernel's one home.

**Why the diff row is labeled `Status`, and why nothing collides.** `epics.md:3728` and UJ-6 both
name the row `Status: Suspended -> Scheduled`; those are the product's words for the state, not the
vendor's `Status` field, which is the last run's result and which no resume changes. The two would
sit on one card only if the bodyless write also disclosed unchanged fields - it does not, because
nothing is sent (task 5).

**Why UJ-6's destination differs from AC2's.** UJ-6 (`epics.md:795`) narrates Task details. The
Story 5.11 block's AC carries an explicit `[AMENDED 2026-09-19]` marker retargeting it at the Task
schedule list and assigning the details route to Story 7.6. The amended AC governs; UJ-6's prose is
7.6's to correct, not this story's.

**AC4 reads two records, not one.** `%SYS.Task.History`'s own class comment says it tracks
"Suspending/Resuming Tasks or TASKMGR", and the table carries `Username`, so the task's own history
is where the resume is *attributed to that user*. It carries no marker column, and OcuPilot writes
nothing to a vendor table (AD-2, AD-37) - so "marked as coming through the OcuPilot agent co-pilot"
is the audit row AD-15 emits, correlatable to the history row by user and timestamp and to the
proposal by id, visible on the audit screen by AD-46. Reading the clause as "the history row itself
carries the marker" would be unimplementable; this is the only implementable reading, and it is
stated here rather than assumed. **Which user a vendor resume row records is not yet measured**
(inference that it is the caller) - measure it on the throwaway before pinning the assertion, and if
it records the task's `RunAsUser` instead, that is an intent gap to raise, not to work around.

**Why `task` needs an id rule after all.** AD-13 says a type with no rule canonicalizes to itself,
and a numeric id looks like it has one spelling. It does not: the model supplies the id as a string
through `Write.View`, so `"007"`, `"+7"` and `"7"` would be three target keys for one task, which is
exactly the DW-1359 hazard that put the canonical form in the identity layer in the first place -
AD-34's per-target lock and its sibling cancel would not cover the other two spellings.

**The region to distrust (Stories 5.9 and 5.10's lesson).** A safety predicate whose refusing branch
never runs against the real body. This story adds three: the not-suspended mint refusal, the `task`
`Prohibited` branch, and the widened `entityId` guard. Two notes on arming them. The `Prohibited`
branch's refusing arm cannot be reached through the resume tool itself, because that tool admits no
fields - so it is exercised by calling the predicate with a changed field directly, which **arms its
input** rather than replacing the method. And the `entityId` guard must be falsified in **both**
directions: a fix that admits a composite of one part and also admits a composite of three is not a
fix.

**Ledger dispositions.**

- **DW-269 addressed** (task 7, AC1). The lead re-owned it here on the evidence that Epic 6's merge
  landed the mechanism, and the tree confirms it: `Registry.cls:1704` `ROWGETTYPES` carries `INFO`,
  `Read.cls:789` issues it, and `TaskDetails.cls:63` is a working precedent. Story 4.10's decline
  rested on `Screen/Read` hard-coding the detail verb, which is no longer true.
- **DW-1419 addressed** (tasks 11-12, 20; AC2 and AC3). Its second clause - "nothing selects" - is
  this story's own navigation target, and one helper closes it for the agent's navigation and the
  toast together.
- **DW-1453 addressed** (task 13). Its stated premise - that 5.11 adds an unbuilt descriptor - is
  false: this story adds no descriptor at all, and `AuditingConfig` remains the tree's only
  `built: false` one. It is fixed here anyway because it is a two-way door whose blast radius today
  is a single coverage row, and leaving it open means the next unbuilt descriptor sits on no roster
  silently.

**Two measurements the implement stage owes before it declares anything.** Which `INFO` fields move
under a suspended task, which decides `fingerprintExcludes` (task 7) - declaring none and being
wrong means every confirm mismatches, declaring too many means the fingerprint stops protecting.
And which user a vendor resume row records in `%SYS.Task.History` (AC4). Both are throwaway probes,
neither is inferable from the source, and the schedule list auto-refreshes at five seconds, so a
`rowGet` per row is also worth timing against NFR-1 while the probe is up.

## Verification

**Targeted, inside the implement loop (loop):**

- `cd ui && node tools/field-lists.mjs && node tools/screen-mirror.mjs` -- expected: both regenerate
  cleanly; `git diff` touches only `ToolFields.cls` and `screens.generated.ts`.
- `uv run scripts/check-objectscript.py <changed paths>` -- expected: 21 rules pass.
- Load and compile the changed classes through the IRIS MCP tools with `server: "ocupilot-slot-a"`,
  reading the error text rather than assuming a clean compile. **Never resume or suspend a task on
  `ocupilot`.**
- `cd ui && npm run test:tools` and `npm run test:components` -- expected: green. These cover
  `entity-ref.test.mjs`, `screen-mirror.test.mjs`, `navigation.test.mjs`, `toasts.test.mjs`,
  `field-lists.test.mjs`, `list-page.spec.ts`, `data-table.spec.ts`, `agent-navigator.spec.ts`,
  `toast-host.spec.ts`, `proposal-card.spec.ts`.
- The throwaway `ocupilot-ci` is already up and was refreshed in place by an earlier runner; it is
  **not** pristine and no session here brought it up, so do not tear it down. **Before any result on
  it means anything:** sync the source to `/tmp/ocupilot-ci/src`, compile it, and run
  `OcuPilot.Install.Installer.Install` -- `ui/tools/ci-runner.mjs` does **not** load source. Then
  `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`
  -- a browser spec loads the deployed bundle, not the working tree.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.TaskResume` --
  and the same, **one class per invocation, waiting for each to land in `%UnitTest_Result` before the
  next**, for `OcuPilot.Test.Prohibited`, `OcuPilot.Test.ProhibitedRoute`, `OcuPilot.Test.Descriptor`,
  `OcuPilot.Test.ToolWrite`, `OcuPilot.Test.Proposal`, `OcuPilot.Test.ProposalConfirm`,
  `OcuPilot.Test.ProposalWire`, `OcuPilot.Test.SurfaceCoverage`, `OcuPilot.Test.EndpointCoverage`,
  `OcuPilot.Test.ScreenRead`, `OcuPilot.Test.ReadTool`, `OcuPilot.Test.AdminPortAsync`,
  `OcuPilot.Test.AuditMarker`, `OcuPilot.Test.Demo`. Expected: each class green, totals verified with
  the `%UnitTest_Result` SQL probe rather than the runner envelope. Never two test calls in one
  message. **After the sweep, read the demo task's `Suspended` back and assert it is suspended again.**
- `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci
  node --test --test-concurrency=1 browser/task-resume.browser-spec.mjs browser/tasks.browser-spec.mjs
  browser/navigate.browser-spec.mjs browser/change-highlight.browser-spec.mjs` -- expected: green.
  Clear `OcuPilot_Kernel_State.Pref` before trusting any local re-run: the browser suite is not
  idempotent on a reused instance (DW-1447, DW-1448).
- **Rule 19 -- one mutation per AC, applied on the throwaway, reverted, tree confirmed byte-identical
  (`git status --short`, `git diff --stat`) after each. Write the `mutation:` line here as each is
  demonstrated:**
  - `mutation: drop the INFO rowGet from TaskScheduleList's read -> the DW-269 leg of OcuPilot.Test.TaskResume and OcuPilot.Test.Descriptor's read-field assertion (AC1)`
  - `mutation: restore Navigate.Directive's 'IdKind() = single' guard -> the selection leg of ui/browser/task-resume.browser-spec.mjs and agent-navigator.spec.ts (AC2), which read NAV.ENTITYNOTALLOWED`
  - `mutation: widen the same guard to every composite -> ui/tools/navigation.test.mjs's three-part refusal (AC2's other direction)`
  - `mutation: ignore the route's own id segment in list-page -> the aria-selected assertions in list-page.spec.ts and toast-host.spec.ts (AC2, AC3)`
  - `mutation: remove the not-suspended refusal from the tool's state diff -> OcuPilot.Test.TaskResume's not-suspended leg (AC5), which mints a proposal whose diff says nothing changes`
  - `mutation: send an empty object body with the RESUME call -> AdminPort's bodyless-type handling and OcuPilot.Test.TaskResume's port leg (AC7)`
  - `mutation: add Suspended to the descriptor's fingerprintExcludes -> OcuPilot.Test.TaskResume's moved-under-you leg (AC6), which confirms instead of refusing`
  - `mutation: answer the id verbatim for the task rule in EntityRef.NormalizedId -> the two-spellings-one-key leg (AC7's one-lock half)`
  - `mutation: remove task from Prohibited.COVEREDTYPES -> OcuPilot.Test.Prohibited's empty-UncoveredWriteTools assertion and the covered-types roster`
  - `mutation: skip the marker emission in Confirm.Transition -> OcuPilot.Test.TaskResume's marker and ledger legs (AC8)`
  - `mutation: restore the built filter in SurfaceCoverage.DeriveScreens -> the AuditingConfig screen row goes unchecked; falsify by deleting that row and watching the roster stay green under the mutation and redden without it (AC12)`

**Full runs, once, before `dev_complete` (once, before dev_complete):**

- `cd ui && npm run build && npm test` -- expected: the prebuild checkers pass and both client tiers
  are green. `npm test` does **not** run the browser suite.
- `cd ui && npm run test:browser` -- expected: the whole browser suite green against the redeployed
  bundle.
- The full ObjectScript sweep through `ci-runner.mjs` against `ocupilot-ci`, one class at a time,
  reconciled against `%UnitTest_Result`, **followed by a read-back asserting the demo task is
  suspended again**.
- `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` -- expected: zero
  checks `pending`, `fail = 0`, a non-zero executed count, and `agentwrite` and `auditmarker` both
  pass. Read the skip lines, not the number (DW-1402).
- `bash scripts/lint-docs.sh` -- expected: clean.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
