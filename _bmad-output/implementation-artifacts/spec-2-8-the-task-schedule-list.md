---
title: 'Story 2.8: The task schedule list'
type: 'feature'
created: '2026-09-14'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-2-7-the-ssl-tls-configurations-list.md'
warnings: ['oversized']
deferred:
  - summary: "The vendor Task.CRUD LIST's `Suspended` key is `false` for every task, including genuinely suspended ones, so no list read can carry a truthful per-task suspended signal. Story 4.10's Home suggested-view line \"tasks suspended after an error (from the task schedule list, Story 2.8)\" (epics.md:2838) therefore has no source, and Story 6.7's Task details will need one too."
    evidence: "Probed live 2026-09-14 (`server: ocupilot-iris`). `Task.CRUD` LIST returns `\"Suspended\":false` for ids 4 and 21; `SELECT ID,Name,Suspended FROM %SYS.Task WHERE Suspended>0` returns exactly those two with stored `Suspended=2`; `Task.CRUD` INFO on id 4 returns `\"Suspended\":true`. Cause: `RunList` applies a Yes/No coercion (`$ZCONVERT(v,\"U\")[\"YES\"`) to a column whose display values are ''/'Suspend Leave'/'Suspend Reschedule'."
    location: 'src/OcuPilot/Screen/Read.cls:29'
    severity: 'med'
    footprint: 'out-of-footprint'
    note: "The truth is in the same endpoint's INFO, and `AdminPort` already admits INFO (`Parameter TYPESUFFIXES = \"GET,LIST,INFO\"`). Only `Read.cls:29 Parameter DETAILTYPE = \"GET\"` and AD-36's Rule (\"the port issues that endpoint's GET once per surviving row\") stand in the way. Recommended: amend AD-36 to let `read.source.rowGet` declare `type` (`GET` default, `INFO` permitted) and route to the story that first needs the signal (4.10 or 6.7). Not taken here: no AC of this story requires it, and amending an AD is the lead's (Rule 20)."
  - summary: "AC2's Resume action is not shipped by this story: the banner renders without it. Nothing in EXPERIENCE.md specifies a visible-but-unwired action, and Epic 2 has no write path at all."
    evidence: "EXPERIENCE.md:102 tiers this screen `1/3 · P0 (control 4)` - the screen is build step 1/3, the Task Manager control is step 4; :111 tiers Suspend Task Manager at 4. epics.md:572 (FR-51) routes \"the three Task Manager controls\" to Epic 7. `AdminPort.cls:84 Parameter TYPESUFFIXES = \"GET,LIST,INFO\"` admits no write suffix, and no action handler is registered anywhere in the client."
    location: '_bmad-output/planning-artifacts/epics.md:2013'
    severity: 'med'
    footprint: 'out-of-footprint'
    note: 'Route to Epic 7 (FR-51). Recorded here because it narrows AC2, which is the lead''s call at the validation gate.'
---

<intent-contract>

## Intent

**Problem:** The Tasks area has no built screen, so an operator cannot see the instance's scheduled tasks, when each last ran or next runs, or whether the Task Manager is running them at all — the one fact that decides whether any of the schedule means anything.

**Approach:** A fourth list screen on the three shipped templates: one descriptor class declaring a `Task.CRUD` LIST read through `AdminPort`, rendered by `ListPage`. Two firsts that the epic deliberately lands here — the screen declares auto-refresh (AD-43's roster), and the descriptor grammar gains a `banner`: a second declared port read whose value raises a warning strip above the table when the Task Manager is suspended.

## Boundaries & Constraints

**Always:**

- The read declares `%Admin_Task:USE` **and** `%DB_IRISSYS:READ`. `Registry.ReadProblem`'s last arm refuses an admin-port read without the second, and `AreaCoverageProblem` then refuses the screen because the `tasks` area declares only the first — so `Screen/Area.cls:47` gains `%DB_IRISSYS:READ` **after** `%Admin_Task:USE` (order matters: `Gate.EvaluatePairs` names the first unheld pair, and three `failedPair` fixtures pin `%Admin_Task:USE`).
- `%Admin_Task` alone, never both of the vendor's `ResourcesOR()` resources. `Task.CRUD.ResourcesOR()` returns `%Admin_Task` **or** `%Admin_Operate`; a pair set is an AND, so declaring both would refuse an operator the port would have served. `Area.cls:25-31` already records this choice — follow it.
- The banner's read is a second `AdminPort` call on the same descriptor. A fault in it suppresses the banner and **never** fails the list (AC2: "the rows still list") — the opposite of AD-36's `rowGet` fault rule, deliberately.
- Every new string comes from a new EXPERIENCE.md Fixed strings row inserted after `:317`. `strings.test.mjs:328` is a closed-world count derived from that table, and `:481` re-resolves every `/** EXPERIENCE.md:n */` comment — so the ten comments in `strings.ts` pointing at lines ≥ 318 each shift by one.
- Denial and demo checks run on the throwaway (`scripts/ci-throwaway.sh`, `ocupilot-ci`, `OCUPILOT_DEMO=1`). `%All` passes every resource check, so a denial needs a real principal.

**Never:**

- **Never declare `Suspended` as a read field, a filter field, a sort field or a column.** The vendor LIST's `Suspended` key is `false` for every task on this build, suspended ones included (probed; see `deferred:`). A `Suspended` column sourced from the LIST would read "No" over a suspended task — a false statement on screen, which is worse than its absence.
- Never suspend, resume, start or stop the live `ocupilot` instance's Task Manager, and never create, run or delete a task on it. Every check that changes task-manager state runs on the throwaway.
- No `rowGet`: every field this screen needs is in the LIST. No GET is issued, so `context.secretFields` is empty.
- No Resume control, and no outbound classic link (`list` archetype, AD-44).
- Never `docker compose up`/`down` against the live `ocupilot` container.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| List loads | `GET /api/ocupilot/screens/tasks.schedule/read?maxRows=1000`, caller holds both pairs | `{fields, rows, truncated, banner}`; 18 vendor rows on a clean instance, each carrying `Name`, `Type`, `Namespace`, `Description`, `Id`, `LastFinished`, `NextScheduled` | No error expected |
| Task Manager running | `Task.Manager` GET answers `{"Status":"Running"}` | `banner` is `""`; no strip renders | No error expected |
| Task Manager suspended | `Task.Manager` GET answers `{"Status":"Suspended"}` | `banner` is `taskManagerSuspendedBanner`; the warning strip renders above the table **and the rows still list** | No error expected |
| Banner read faults | `Task.Manager` GET answers non-2xx or the port raises | `banner` is `""`, `rows` is the full list, HTTP 200 | Fault swallowed for the banner only; the list is unaffected |
| Never-run task | A row whose `LastFinished` / `NextScheduled` are `""` | Cell renders "(none)" in body type, not an empty cell | No error expected |
| Filter to a subset | "purge" typed into the command bar | Strictly fewer rows than unfiltered, strictly more than zero | No error expected |
| Privilege missing | Caller holds `%Admin_Task:USE` but not `%DB_IRISSYS:READ` | 403 naming the failing pair `%DB_IRISSYS:READ`; inline alert, on-screen data stays | `Error.Render` envelope with the pair in `reason` |
| Auto-refresh tick | Chip set to 5 s, a sort, a filter, a selection and a scroll offset in place | Rows re-read in place; sort, filter, selection and scroll identical; status-bar stamp updates; no skeleton, no announcement | A refused tick is never retried |

</intent-contract>

## Code Map

**The descriptor and its grammar**

- `src/OcuPilot/Screen/Descriptor/SslConfigList.cls` — the closest template: no `rowGet`, `instance` scope, `single` id, `%DB_IRISSYS:READ` pair, `refreshes: false`. Copy its shape and its doc-comment structure.
- `src/OcuPilot/Screen/Descriptor/Base.cls` — accessors `:129-458`; a `banner` accessor is added here, defaulting to null.
- `src/OcuPilot/Screen/Registry.cls` — `Validate` `:130` calls refusals in order: read `:181` → `MalformedPair` `:189` → `AreaCoverageProblem` `:197` → `RefreshProblem` `:206` → `ClassicLinkProblem` `:217`. `BannerProblem` goes between `:206` and `:217`. `ReadProblem`'s `%DB_IRISSYS:READ` arm is `:469-480`; `RefreshProblem` `:249-279` (whole seconds, strictly ascending, all > 0, non-empty iff `refreshes`); `AreaCoverageProblem` `:297-317`.
- `ui/tools/screen-mirror.mjs` — `readProblem` `:389`, `refreshProblem` `:317`; `bannerProblem` mirrors `BannerProblem` sentence-for-sentence. Emits `ui/src/app/core/screens.generated.ts` (tracked, never hand-edited); `--check` `:982` prints only "the checked-in mirror is stale".
- `src/OcuPilot/Test/RowGetCorpus.cls` / `AdminPairCorpus.cls` — the corpus pattern (`XData Cases`, `{name, declaration, expected}`) read by `Test/ReadTool.cls:110,133` and `screen-mirror.test.mjs:362,390`. `BannerCorpus.cls` follows it exactly.
- `src/OcuPilot/Screen/Read.cls:72` `Execute` — builds `{fields, rows, truncated}` at `:128-130`; the banner is evaluated after the rows and added as a fourth key. `:29 Parameter DETAILTYPE = "GET"` is untouched by this story.
- `src/OcuPilot/Port/AdminPort.cls:84` `Parameter TYPESUFFIXES = "GET,LIST,INFO"` — `Task.Manager` GET is already an admissible read.

**Areas, navigation and the pinned fixtures that move**

- `src/OcuPilot/Screen/Area.cls:47` — `{"key":"tasks","railPosition":4,…,"privileges":[{"resource":"%Admin_Task","permission":"USE"}]}`. Rail order is home 1, logs 2, os-management 3, **tasks 4**, permissions 5, web-applications 6, security 7, agent 8.
- `src/OcuPilot/Test/Descriptor.cls:549` — `$ListBuild("tasks", "%Admin_Task:USE", 0, 0)` becomes `"%Admin_Task:USE, %DB_IRISSYS:READ"` (`PairText()` joins in declared order).
- `src/OcuPilot/Test/ReadTool.cls:92-94` — count `3` → `4`; `tNames` is `$Order`-collected so alphabetical: `permissions.users.read,security.ssl.read,tasks.schedule.read,webapp.list.read`; add the `$ListBuild` descriptor pair.
- `ui/tools/navigation.test.mjs:112-116` — `['', 'permissions/users', …]` gains `'tasks/schedule'` at **index 1** (tasks is rail 4, home is rail 1); the message at `:115` is reworded.
- `ui/tools/navigation-wire.test.mjs:61` and `ui/src/app/shell/rail-wire.spec.ts:63` — both `LIVE_PAYLOAD` copies carry `tasks: {screens: []}`. **Neither goes red on its own** — update both or the fixtures quietly lie.
- `ui/tools/screen-mirror.test.mjs:390-412` — the literal list `['SslConfigList','UserList','WebAppList']` is inclusion-only; add the fourth by convention.
- `src/OcuPilot/Test/Screen/Sub.cls:20` already declares `"parentScope": "tasks/schedule"` — that route is the one the tree expects.

**Smoke**

- `src/OcuPilot/Install/Smoke.cls:441-449` — loop bound `3`, names `webapplications,users,ssl`, an indexed `$Select` with an empty catch-all arm (its comment describes exactly this story's edit). `:552` `AddPending` — the `arealists` pending note names "Logs, OS management and Tasks".
- `src/OcuPilot/Test/Smoke.cls:132-138` (pending note by content), `:255-257` (fail lines), `:273-292` (each check reads its own screen; three paths → four), `:306-343` (loop bound == name count == `$Select` arm count, read from `Smoke.cls`'s own source).

**Client**

- `ui/src/app/shell/list-page.ts:35-39` — the whole template is `<section class="ocu-list-page">` + `<app-data-table>`. **The banner strip goes between `:35` and `:36`.** `.ocu-list-page` is a column flex with `app-data-table { flex: 1 1 auto }` (`ui/src/styles/_components.scss:1920-1932`), so a sibling above needs no layout change. There is no `ng-content` anywhere in the client.
- `ui/src/styles/_components.scss:357-373` — the `.ocu-banner*` classes exist (used only by `sign-in.ts` today); DESIGN.md:1203 gives the warning variant.
- `ui/src/app/core/refresh.ts` (`RefreshService`, `chipLabel` `:332`, `advanceRate` `:347`, `tick` `:524`), `ui/src/app/core/screen-store.ts:117-122` (`applyTick` writes only rows/truncated/lastUpdateAt — preservation is already the framework's), `ui/src/app/shell/command-bar.ts:129-138` (the chip). **No screen declares refresh today**; declaring the two keys is the whole client change for AC4. `ui/tools/refresh.test.mjs:1082` forbids an area page arming its own timer.
- `ui/src/app/core/screen-read.ts:40-42,160-161` — the client's `{fields, rows, truncated}` shape; `banner` is additive.
- `ui/src/app/core/strings.ts` — `:253 taskManagerSuspendedBanner` already exists (`'The Task Manager is suspended — no scheduled task will run until it is resumed.'`, em dash), currently referenced by nothing. Reuse `:309 tableColumnName`, `:311 tableColumnType`, `:390 headerNamespaceLabel`, `:321 tableReadOnlyEmptyNext`. `strings.test.mjs:432` refuses duplicate **values**, so a new `taskColumnName: 'Name'` would go red.

**Browser specs (DW-267)**

- `ui/browser/ssl.browser-spec.mjs:129-150` — Story 2.7's `rowCount` + `clearFilter` fix, in one copy only.
- `ui/browser/users.browser-spec.mjs:138-159` and `ui/browser/web-applications.browser-spec.mjs:127-149` — `filterTo` byte-identical to ssl's, with no `clearFilter`; chained legs (`users:214,219,225`; `web-applications:193,199,204,210,212`, the `:210` leg carrying no assertion at all).
- `ui/browser.config.mjs` — the only shared module: `browserConfig()`, `launchOptions()` (honours `OCUPILOT_BROWSER_EXECUTABLE` at `:80`), `LIVE_CONTAINER` guard. Pure configuration, no `page` dependency.
- `ui/src/app/shell/data-table.ts:173` `[attr.aria-rowcount]="ariaRowCount"` (`:570`, `view().length + 1`) — the virtualisation-proof row-count signal. `:305 .ocu-data-table-count` is the footer text. `:498-500` `showEmpty` keys off the **unfiltered** data, so an over-filter leaves the grid mounted with zero body rows rather than swapping in the empty state.
- `ui/package.json:16-17` — `test:browser` is the fixed glob `browser/*.browser-spec.mjs` with `--test-concurrency=1`; `ui/tools/ci.test.mjs:590-614` requires every test command to name files, never a directory.

**Fixture (read-only for this story)**

- `src/OcuPilot/Install/Fixture.cls:478` `CreateTask` — name is `ResolvedPrefix(profile) _ " nightly purge"`, default prefix `OcuPilotDemo` (`:68`), so **`OcuPilotDemo nightly purge`**; description `"OcuPilot demo fixture: fails by design to demonstrate a task suspended after an error"`; `SuspendOnError = 1`; `RunNow` then the task throws (`Install/DemoTask.cls`). Idempotent, with an uninstall branch. Already shipped in Story 1.4 — **no fixture work in this story.**

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Screen/Area.cls` — append `{"resource":"%DB_IRISSYS","permission":"READ"}` to the `tasks` entry's `privileges`, after `%Admin_Task:USE` — without it `AreaCoverageProblem` refuses the screen at install.
- `src/OcuPilot/Screen/Registry.cls` — add `BannerProblem(pDeclaration)`, called from `Validate` after `RefreshProblem` and before `ClassicLinkProblem`. Refuse, in this order: a banner that is not an object; `source.port` not `admin`; `source.endpoint` not package-relative; `source.type` not `GET`; an empty `field`, `equals` or `messageKey`; a `severity` outside the closed set; and last, a banner declared while `read` is not ("a banner is chrome on a declared read's screen (AD-36)") — which is what makes the read's own `%DB_IRISSYS:READ` arm cover the banner's call too, so the pair is not checked twice.
- `src/OcuPilot/Test/BannerCorpus.cls` — new shared corpus, `XData Cases` of `{name, declaration, expected}` on `RowGetCorpus.cls`'s pattern: one case per refusal above plus one sound declaration. Read by both engines.
- `ui/tools/screen-mirror.mjs` — add `bannerProblem`, mirroring `BannerProblem` sentence-for-sentence, and carry `banner` into the emitted mirror.
- `src/OcuPilot/Screen/Descriptor/Base.cls` — add the `banner` accessor, defaulting to null so the three shipped descriptors need no edit.
- `src/OcuPilot/Screen/Read.cls` — after the rows are built, evaluate a declared banner: invoke its source through `AdminPort`, compare `field` to `equals`, and set `banner` to the `messageKey` on a match and `""` otherwise. **Any fault or non-2xx sets `""` and does not fail the read.**
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` — **before the descriptor**, because `strings.test.mjs:328`'s closed-world count is derived from this table and a key with no row fails the build. Insert one Fixed strings row after `:317`: `"Task schedule" · "Last run" · "Next run" · "No scheduled tasks on this instance."`, its Where cell citing the side-bar list (`:165`), the IA row (`:102`), the shared Name/Type, Namespace reusing the namespace switch's accessible name, and the empty state's second line as the Web applications row's. Also sharpen `:102`'s Purpose cell with the column roster, as 2.6 and 2.7 did to `:113` and `:135`.
- `ui/src/app/core/strings.ts` — add `taskListLabel`, `taskColumnLastRun`, `taskColumnNextRun`, `taskListEmpty`, each with its `/** EXPERIENCE.md:n */` comment; **then bump by one the ten existing comments that point at lines ≥ 318**.
- `src/OcuPilot/Screen/Descriptor/TaskScheduleList.cls` — new, after the two above so every key it names already exists. Route `tasks/schedule`, area `tasks`, `sideBarPosition` 1, archetype `list`, `built` true, `toolIdentifier` `tasks.schedule`, entity `task`, `secondaryEntityTypes` `[]`, scope `instance`, `parentScope` `""`, id `{"kind":"single","parts":[]}`, `classicPage` `%CSP.UI.Portal.TaskSchedule`, `classicLinkExemption` not exempt, `primaryAction` and `rowActions` empty, `commandAliases` as the three templates do. `emptyStateKey` `taskListEmpty`; `context` `{"fields": the seven read fields, "secretFields": []}` — empty because no `rowGet` means no GET is ever issued and the LIST carries no secret. `refreshes: true`, `refreshRates: [5, 10, 30, 60]`. `read.source` `{port: admin, endpoint: "Task.CRUD", type: "LIST"}`; `read.fields` `["Name","Type","Namespace","Description","Id","LastFinished","NextScheduled"]`; `filter` `["Name","Namespace","Type","Description"]`; `sort.fields` the same four plus `LastFinished` and `NextScheduled`, default `Name` asc; `paging: "cap"`. `table.columns`: `Name`/`tableColumnName`/name, `Namespace`/`headerNamespaceLabel`/text, `Type`/`tableColumnType`/text, `LastFinished`/`taskColumnLastRun`/text, `NextScheduled`/`taskColumnNextRun`/text. `emptyNextKey` `tableReadOnlyEmptyNext`, `emptyAgentKey` `""`. `banner` as in the Design Notes. The class doc comment states, in SslConfigList's voice, why `Suspended` is absent.
- `ui/src/app/shell/list-page.ts` — render the banner strip between `:35` and `:36`: a warning `.ocu-banner` with an icon and `stringFor(store.banner())`, shown only when the key is non-empty, not dismissible. No Resume control.
- `ui/src/app/core/screen-store.ts`, `ui/src/app/core/screen-read.ts` — carry `banner` from the response into the store alongside `rows`/`truncated`, so an auto-refresh tick clears a banner the moment the condition clears (EXPERIENCE.md:350).
- `src/OcuPilot/Test/Descriptor.cls`, `src/OcuPilot/Test/ReadTool.cls`, `ui/tools/navigation.test.mjs`, `ui/tools/navigation-wire.test.mjs`, `ui/src/app/shell/rail-wire.spec.ts`, `ui/tools/screen-mirror.test.mjs` — update the six content pins named in the Code Map.
- `src/OcuPilot/Install/Smoke.cls` and `src/OcuPilot/Test/Smoke.cls` — add `TASKLISTTOOL = "tasks.schedule"`, loop bound 3 → 4, a fourth name `tasks`, a fourth `$Select` arm, and drop `Tasks` from the `arealists` pending note (leaving Logs and OS management); update the three `Test/Smoke.cls` pins that read those.
- `ui/browser/list-spec.mjs` — **new shared module (DW-267)** exporting `viewCount(page)`, `clearFilter(page, total, timeoutMs)` and `filterToSubset(page, {text, expectRow, total, timeoutMs})`. `filterToSubset` clears first so every leg runs from the whole list, then asserts `0 < kept < total` off `aria-rowcount` (never DOM row elements — the table virtualises), and that `expectRow` survives. Named in `ui/browser/`, so the `*.browser-spec.mjs` glob does not run it as a suite and `client-lint.mjs`'s `browser/` walk still lints it.
- `ui/browser/users.browser-spec.mjs`, `ui/browser/web-applications.browser-spec.mjs`, `ui/browser/ssl.browser-spec.mjs` — delete the three local `filterTo` copies (and ssl's `rowCount`/`clearFilter`) and import the shared helper. Give `web-applications`' assertion-free `HSCUSTOM` leg (`:210`) a real assertion.
- `ui/browser/tasks.browser-spec.mjs` — new spec, four legs, one per AC (below).
- `src/OcuPilot/Test/WireSecurityRead.cls` — add a `tasks` leg: a real principal holding `%Admin_Task:USE` but not `%DB_IRISSYS:READ` is refused by name; holding both, served. Throwaway only; leave zero principals behind.

**Acceptance Criteria:**

- **Given** a caller holding `%Admin_Task:USE` and `%DB_IRISSYS:READ` on an instance with the Task Manager running, **when** the Task schedule screen loads, **then** the table lists the instance's scheduled tasks with Name, Namespace, Type, Last run and Next run, and typing into the command bar's filter narrows the rows to a proper subset of the unfiltered list.
- **Given** the Task Manager is suspended, **when** the screen renders, **then** a non-dismissible warning strip above the table reads "The Task Manager is suspended — no scheduled task will run until it is resumed.", **and** the rows still list; **and** when the Task Manager is running, no strip renders.
- **Given** a container built with `OCUPILOT_DEMO=1`, **when** the list renders, **then** the row named "OcuPilotDemo nightly purge" appears among the scheduled tasks.
- **Given** the screen declares auto-refresh, **when** the user sets a rate from the command-bar chip with a sort, a filter, a selection and a scroll offset in place, **then** the rows re-read on that interval and the sort, filter, selection and scroll are unchanged, with no skeleton shown and nothing announced.
- **Given** a real principal on the throwaway holding `%Admin_Task:USE` but not `%DB_IRISSYS:READ`, **when** it opens the Task schedule screen, **then** it is refused with `%DB_IRISSYS:READ` named as the failing pair and on-screen data stays; **and** granting that pair serves the list — with `Registry.Validate` reporting no problem for this descriptor at install, since a screen whose area under-declares the pair would otherwise read allowed and then be refused.

## Spec Change Log
- 2026-09-14, lead (spec gate, owner-delegated): both recorded decisions accepted at origin. epics.md Story 2.8 AC2 now says the banner ships without the Resume control, which is Epic 7's (FR-51). AD-36 now lets a `rowGet` declare its detail type (`GET` or `INFO`); the tasks LIST's `Suspended` coercion is DW-269, routed to Story 4.10, and this story still declares no `rowGet`.

## Review Triage Log

## Design Notes

**Governing architecture decisions (Rule 6).** AD-2 and AD-27 (`AdminPort` is the only caller of `%Api.Admin.*`, and the only file naming one) · AD-5 (one descriptor is the source of route, gate, read tool and table) · AD-8 (the pair set is an AND, evaluated per call, and a denial names the failing pair) · AD-13 (the scoped triple; the id is one percent-encoded segment) · AD-29 (every port carries its own gate) · AD-36 (one declared read serves screen and tool, bounded by the cap; **`rowGet` is not used here**) · AD-43 (live data has one framework; EXPERIENCE.md's roster names Task schedule among the six) · AD-44 (a `list` archetype never links out; the descriptor declares the classic page it replaces, `%CSP.UI.Portal.TaskSchedule`, in the class's own case) · AD-24 (the tool's view is the screen's, narrowed by the context cap) · AD-25 (the demo fixture is opt-in) · AD-45 (one smoke path). AD-14's change events and AD-6's proposals are not reached: this story writes nothing.

**Consumes:** Story 1.9's `Registry`, `Area` and `Gate`; Story 1.14's `RefreshService`, `ScreenStore` and the command-bar chip; Story 2.1's `AdminPort`; Story 2.3's `Screen.Read` and `GET /screens/:screen/read`; Story 2.4's `DataTable` and `ListPage`; Story 1.4's `Fixture.CreateTask`; Story 2.7's browser-spec shape.

**Consumed-by:** Story 4.10 (Home's suggested view — see the `deferred:` entry; the "tasks suspended after an error" line has no source until the LIST's `Suspended` defect is addressed) · Story 6.7 (Task details, which this list's name cell navigates to and which re-points UJ-6's agent target) · Epic 4 (dispatches `tasks.schedule.read`) · Epic 7 (the three Task Manager controls, including the Resume this story's banner does not carry). Shared surfaces introduced here and their first consumers: the `banner` grammar (this screen only today; EXPERIENCE.md:414's seven banner kinds are the later consumers) and `ui/browser/list-spec.mjs` (all four list specs, in this story).

**Why `Suspended` is absent — probed, not assumed.** `Task.CRUD` LIST answers `"Suspended":false` for ids 4 and 21 while `%SYS.Task` stores `Suspended=2` for exactly those two, and `Task.CRUD` INFO on id 4 answers `"Suspended":true`. `RunList` applies a Yes/No coercion to a column whose display values are `''`, `'Suspend Leave'` and `'Suspend Reschedule'`, none of which contains "YES". So the key is structurally false for every task on this build. The truthful value is in INFO, which `AdminPort` already admits (`TYPESUFFIXES = "GET,LIST,INFO"`); only `Read.cls:29 DETAILTYPE = "GET"` and AD-36's Rule stand in the way, and amending an AD is the lead's (Rule 20). Recorded in `deferred:` rather than worked around.

**Why no Resume control.** EXPERIENCE.md:102 tiers this screen `1/3 · P0 (control 4)` — the screen is build step 1/3 and the Task Manager control is step 4; `:111` tiers Suspend Task Manager at 4; epics.md:572 routes "the three Task Manager controls" to Epic 7. Epic 2 has no write path at all (`AdminPort` admits no write suffix; no action handler is registered anywhere in the client; AD-6's proposal/confirm/audit chain arrives in Epic 3). EXPERIENCE.md specifies no treatment for a visible-but-unwired action, so shipping a dead button would invent vocabulary the design does not carry. The banner ships; the control is Epic 7's. This narrows AC2 and is recorded in `deferred:` for the lead.

**The banner declaration:**

```json
"banner": {
  "source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET"},
  "field": "Status", "equals": "Suspended",
  "messageKey": "taskManagerSuspendedBanner", "severity": "warning"
}
```

It rides in the read's own response rather than a second route, so AD-36's "one read" stays true and an auto-refresh tick re-evaluates it — which is what makes EXPERIENCE.md:350's "gone the moment it clears" free. It is screen chrome, not rows, so it does **not** reach the read tool's payload (AD-36's tool view is the screen's rows).

**Rates.** `[5, 10, 30, 60]` from EXPERIENCE.md's auto-refresh bullet; `Test/Descriptor.cls:490` already asserts that exact list sound against `RefreshProblem`. Default off (`RATE_OFF = 0`); the chip is the control and the status-bar stamp is the readout.

**The empty state says "on this instance", not "in `<NAMESPACE>`"** — the read is `instance`-scoped and the rows span namespaces (`%SYS`, `HSSYS`, the install namespace), so a `<NAMESPACE>` sentence would be false. EXPERIENCE.md:365 requires the sentence to name its scope, and the instance is the scope.

**DW-267 (Rule 17).** Addressed by the `ui/browser/list-spec.mjs` task and the three spec rewrites above. The vacuity's mechanism, confirmed from the code rather than from the ledger: `filterTo` clears and types without waiting, then polls a predicate over *the rows rendered now* — so a needle the previous leg's survivors already carry satisfies it on the first poll, before the new filter narrows anything, and the leg passes whatever `read.filter` declares. `filterToSubset` fixes both ends: it clears and waits for the unfiltered count first, then requires `0 < kept < total`, so a no-op filter and an over-filter each fail with their own message. It reads `aria-rowcount` (the whole view) rather than DOM rows (the rendered window), because web-applications lists 47 rows and Story 2.10 will list 1,000.

**Id.** `{"kind": "single", "parts": []}`, as the three templates. Epic 6's Task details resolves a task by the vendor's numeric `Id`, which this read already carries as a field, so the id accessor is settled when that screen lands rather than guessed at now *(inference)*.

## Verification

**Commands:**

- `uv run scripts/check-objectscript.py` — expected: clean over every changed `.cls`.
- `cd ui && node tools/screen-mirror.mjs` then `git diff --stat ui/src/app/core/screens.generated.ts` — expected: the fourth descriptor appears; stage the regenerated file. Never hand-edit it.
- `cd ui && npm run build` — expected: the five `prebuild` checkers pass, `screen-mirror.mjs --check` included.
- `cd ui && npm test` — expected: `node --test tools/*.test.mjs` plus the Angular component runner green, with `navigation.test.mjs`, `navigation-wire.test.mjs`, `screen-mirror.test.mjs`, `strings.test.mjs`, `refresh.test.mjs` and `rail-wire.spec.ts` all updated rather than skipped.
- `bash scripts/lint-docs.sh` — expected: clean after the EXPERIENCE.md row insertion.
- IRIS MCP (`server: "ocupilot-iris"`): load and compile `src/OcuPilot/`, then run **one** `iris_execute_tests` call per message and wait for it to land in `%UnitTest_Result` before the next — `Test.Descriptor`, `Test.ReadTool`, `Test.ScreenRead`, `Test.Smoke`, and the new `Test.BannerCorpus` leg. Never two test calls in one message.
- `sh scripts/ci-throwaway.sh up && sh scripts/wait-readiness.sh --url http://localhost:52776/api/ocupilot/readiness/` then, from `ui/`, `OCUPILOT_BROWSER_EXECUTABLE="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" node --test --test-concurrency=1 browser/tasks.browser-spec.mjs` — expected: four legs green. Finish with `sh scripts/ci-throwaway.sh down`.
- `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` — expected: four area-list checks, the `tasks` one reading `tasks.schedule`; zero executed checks is a failure, never a pass.

**Everything that changes task-manager state runs on the throwaway.** The AC2 legs suspend and resume `ocupilot-ci`'s Task Manager through the container's own session and restore it in a `finally`. **Nothing in this story suspends, resumes or otherwise mutates the live `ocupilot` instance's Task Manager or any of its tasks, and nothing runs `docker compose up`/`down` against it.**

**Planned mutations (Rule 19) — one per AC, each reverted with `git status --short` and `git diff --stat` confirmed unchanged afterwards:**

- AC1 — mutation: drop `"Namespace"` from the descriptor's `read.filter` → `tasks.browser-spec.mjs`'s namespace leg goes red on `kept > 0` ("matched nothing"). This is the mutation Story 2.7 found stayed *green* before `clearFilter` existed, so it is also the check that DW-267's fix works.
- AC2 — mutation: change `banner.equals` from `"Suspended"` to `"Running"` → the suspended leg goes red (no strip while suspended) and the running leg goes red (a strip while running). Second half — mutation: make `Read.Execute` propagate a banner-read fault instead of swallowing it → the fault row of the I/O matrix goes red (the list no longer returns rows).
- AC3 — mutation: skip `CreateTask` in `Fixture.cls`'s creator cascade on a fresh throwaway → the "OcuPilotDemo nightly purge" leg goes red.
- AC4 — mutation: set `"refreshes": false` in the descriptor and regenerate the mirror → the chip is absent and the auto-refresh leg goes red.
- AC5 — mutation: revert `Screen/Area.cls:47` to `%Admin_Task:USE` alone → `Registry.Validate` reports `AreaCoverageProblem`'s sentence and `Test.Descriptor`'s area pin goes red.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
