---
title: 'Story 2.8: The task schedule list'
type: 'feature'
created: '2026-09-14'
status: 'done'
baseline_revision: '9a6e570be9f8b1220750b5fb462647b16ed1acf3'
baseline_commit: '9a6e570be9f8b1220750b5fb462647b16ed1acf3'
review_loop_iteration: 0
followup_review_recommended: true
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
  - summary: "A list screen's table frame collapses to its header's height inside the shell, so the virtual-scroll viewport reads `clientHeight` 0, its rows overflow the frame and the footer paints over them. A real pointer click at a row's centre therefore reaches the footer, not the row, and no list screen scrolls its own body."
    evidence: "Measured in headless Chrome against `ocupilot-ci`, 2026-09-14, on all four list routes: `cdk-virtual-scroll-viewport` reads `clientHeight` 0 with `scrollHeight` 1620 (web-applications/list), 360 (permissions/users), 108 (security/ssl) and 684 (tasks/schedule), and `.ocu-data-table-frame` is 38px tall in every one. `document.elementFromPoint` at the first row's centre answers `.ocu-data-table-footer`. It is unchanged at viewport heights 900, 700 and 500, and reproduces on the three screens that shipped before this story."
    location: 'ui/src/styles/_components.scss:1917'
    severity: 'med'
    footprint: 'out-of-footprint'
    note: "Pre-existing: it predates the task schedule and reproduces on Stories 2.5-2.7's screens, so it is Story 2.4's `ListPage`/`DataTable` height chain (`app-list-page { height: 100% }` over an outlet with no definite height), not this screen's. `users.browser-spec.mjs` already worked around it by dispatching a synthetic click rather than driving the mouse, and `tasks.browser-spec.mjs` follows that precedent; `data-table.browser-spec.mjs` does not meet it because its harness page has no shell around the table. Not taken here: fixing the shell's height chain is out of this story's footprint and would change every list screen's layout."
  - summary: "AC2's Resume action is not shipped by this story: the banner renders without it. Nothing in EXPERIENCE.md specifies a visible-but-unwired action, and Epic 2 has no write path at all."
    evidence: "EXPERIENCE.md:102 tiers this screen `1/3 · P0 (control 4)` - the screen is build step 1/3, the Task Manager control is step 4; :111 tiers Suspend Task Manager at 4. epics.md:572 (FR-51) routes \"the three Task Manager controls\" to Epic 7. `AdminPort.cls:84 Parameter TYPESUFFIXES = \"GET,LIST,INFO\"` admits no write suffix, and no action handler is registered anywhere in the client."
    location: '_bmad-output/planning-artifacts/epics.md:2013'
    severity: 'med'
    footprint: 'out-of-footprint'
    note: 'Route to Epic 7 (FR-51). Recorded here because it narrows AC2, which is the lead''s call at the validation gate.'
  - summary: >-
      A stopped Task Manager raises no warning strip: the banner matches only `Status` equal to
      `Suspended`, so an instance whose scheduler is not running at all renders the full schedule
      with nothing said about it -- the same consequence the suspended banner exists to announce.
    evidence: |-
      `TASKMGRStatus()` has three values (0 not running, 1 running, 2 suspended) and
      `%CSP.UI.Portal.TaskSchedule` renders all three. The shipped descriptor compares
      `Task.Manager`'s `Status` to the single literal `Suspended`, so only value 2 raises the strip.
      What the endpoint answers for value 0 is unverified: `%Api.Admin` is absent from `irissys/`,
      and observing it would mean stopping a Task Manager, which no check here may do to the live
      instance.
    location: 'src/OcuPilot/Screen/Descriptor/TaskScheduleList.cls:93'
    severity: medium
    footprint: out-of-footprint
    note: >-
      Not taken here: EXPERIENCE.md:468 specifies this banner as "the Task Manager is suspended"
      and the one Fixed strings row says so, so covering the stopped state needs a second sentence
      and a second row -- a UX decision, not a patch. The grammar already admits it (a banner
      declares one field and one value, so a second banner or a value set is the shape), and Epic 7
      owns the Task Manager controls.
  - summary: >-
      EXPERIENCE.md still specifies a Resume control on this banner at `:102` and `:468`, which
      AC2 was narrowed at the spec gate to drop; the UX document carries no note of the deviation.
    evidence: |-
      `:468` reads "warning banner above the table ... with Resume (privilege-gated per Privilege
      Gating)" with its Exit column set to Resume, and `:102` -- the row this story edited to add
      the column roster -- still reads "a warning banner with Resume while it is suspended". The
      shipped strip asserts `dismiss === false` and carries no control.
    location: '_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md:468'
    severity: medium
    footprint: out-of-footprint
    note: >-
      The Spec Change Log records the lead accepting the narrowing in epics.md; EXPERIENCE.md was
      not amended with it. Amending a planning artifact is the lead's (Rule 20). Route to Epic 7
      (FR-51) or annotate both rows as deferred to it.
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

### 2026-09-14 — Review pass

- verdicts: 45 findings — high 0, medium 8, low 28, false 9, maybe-false 0
- findings:
  - `[medium]` `[patch]` `banner.messageKey` escapes `declaredStringKeys`, so a typo ships a strip that never appears — verified: the enumerator reads `labelKey`, `emptyStateKey` and the table keys only, and `stringFor` blanks an unknown key by design. Added the banner's key and extended the guard test; mutation observed red.
  - `[low]` `[patch]` nothing pins the read tool's payload as carrying no `banner`, though three doc comments claim it — verified: `Tool.Read.View` builds its answer key by key, so the claim holds but nothing guards it. Added `ReadTool:TestTheToolPayloadCarriesNoBanner`; mutation observed red.
  - `[low]` `[reject]` every read-tool call pays for a banner it discards — real but one in-process call, and the smallest fix adds a parameter to `Execute`'s public surface.
  - `[low]` `[reject]` the banner's endpoint is held to no privilege rule of its own — spec-bound: "the read's own `%DB_IRISSYS:READ` arm covers the banner's call too" is the declared design, and the one shipped banner is correctly paired. Recorded under residual risk.
  - `[medium]` `[patch]` the Task Manager state is read back with no settle — verified: `%CSP.UI.Portal.TaskSchedule` hangs a second between `SuspendSet` and `TASKMGRStatus()`. Replaced the immediate read with a bounded poll.
  - `[false]` `[reject]` the strip is a live region a tick writes, against "refresh is silent" — refuted: banners announce by design here (`fault-banner.ts` and `instance-notice.ts` are both `role="alert"`), and `:580`'s "no announcement" governs the refresh stamp and spinner, as `command-bar.ts` records.
  - `[medium]` `[defer]` `EXPERIENCE.md:102` and `:468` still specify a Resume control on this banner — verified at both lines; amending a planning artifact is the lead's (Rule 20). Deferred.
  - `[low]` `[reject]` the row key resolves to `Name`, which is not guaranteed unique — spec-bound (`id.kind: single`), and `SELECT Name, COUNT(*) ... HAVING COUNT(*) > 1` returns no rows on the instance.
  - `[low]` `[reject]` no assertion covers the task schedule's name link — the detail screen is Epic 6's; pinning the link now would pin the very inference the descriptor labels `(inference)`.
  - `[low]` `[reject]` `filterToSubset` drops the every-row containment check — the old check ran over the rows rendered *now*, which is the vacuity DW-267 names; the AC1 mutation compensates by proving nothing but `Namespace` matches `%SYS`.
  - `[low]` `[patch]` nothing pins `BANNERSEVERITIES` against the stylesheet that justifies it — added a two-way assertion over the `.ocu-banner-*` rules; mutation observed red.
  - `[low]` `[reject]` the fault rule is asserted for one of the four branches its doc enumerates — the two the matrix names (a port failure and a non-2xx) share one code path and are covered; fixtures for the other two are more than a direct correction.
  - `[false]` `[reject]` `## Auto Run Result` still reads `ready-for-dev` — that section is this step's own output, written at finalize.
  - `[low]` `[patch]` `WireSecurityRead`'s `PreparedPassword` still says "three accounts" where there are five — corrected.
  - `[low]` `[reject]` the shared glyph/message rules only lay out under the page-specific class — true, and moving `display: flex` onto `.ocu-banner` would change the three sign-in banners.
  - `[low]` `[reject]` `.ocu-banner-warning` has no dark pairing — pre-existing: `.ocu-banner-info` and `.ocu-banner-restrained` share the shape, and the dark toggle is the spine's `## Deferred` (FR-73), so no viewer reaches it.
  - `[low]` `[reject]` `ScreenRead`'s new test states its Task Manager precondition rather than checking it — the header says so, and CI's throwaway always starts running; a check would need a namespace switch.
  - `[low]` `[patch]` the browser-spec inventory rule keys on a single-quoted `node:test` import — verified: nothing in the repository enforces a quote style, and the failure direction is "a spec that never runs". Replaced with a regex over both styles.
  - `[medium]` `[defer]` a stopped Task Manager answers a Status the banner never matches, so no strip stands while nothing can run — the design specifies only "suspended" (`EXPERIENCE.md:468`) and a second sentence needs a Fixed strings row. Deferred.
  - `[medium]` `[patch]` `banner.messageKey` is not checked against the string source — same root cause as the first row; patched with it.
  - `[low]` `[reject]` `filterToSubset` counts `aria-rowcount` but seeks `expectRow` among rendered rows — a flake risk, not a false green, and downstream of the already-deferred collapsed-viewport defect.
  - `[medium]` `[patch]` `TASKMGRStatus` is read immediately after `SuspendSet` — same root cause as the settle row; patched with it.
  - `[false]` `[reject]` a failing banner endpoint logs a fault every tick — refuted: `AdminPort.Fail` writes no log.
  - `[low]` `[reject]` `BannerProblem` admits a banner on any archetype — only `ListPage` renders one and no such descriptor exists; an archetype branch guards state never demonstrated.
  - `[low]` `[patch]` the `node:test` substring matches one quote style — same root cause as the inventory-rule row; patched with it.
  - `[low]` `[patch]` AC2's `finally` calls an asserting resume, which can replace the leg's real failure — verified: the resume itself still runs, only the message is lost. Wrapped it; `after` still asserts.
  - `[false]` `[reject]` a `BannerCorpus` case omitting `banner` would throw on the unassigned type hint — refuted: every case carries the key, and the corpus runs green on both engines.
  - `[low]` `[reject]` `filterTo`'s containment check was removed from three shipped specs — same root cause as the containment row above.
  - `[medium]` `[patch]` the banner's `messageKey` is the one declared string key the build-time check does not read — pre-verified by the gap layer; same patch as the first row.
  - `[medium]` `[patch]` the hand-added `tasks/schedule` entry in both client fixtures is compared against no live response — verified: `Wire.cls` had only area-level tasks assertions while the three sibling lists each pin a whole entry. Added `Wire:TestTheTaskScheduleIsDeniedToAPrincipalWithoutAdminTask`; the pair-swap mutation reddened it and nothing else.
  - `[low]` `[patch]` the spec/module split is a substring heuristic — same root cause as the quote-style rows; patched with them.
  - `[low]` `[reject]` `filterToSubset` mixes the view count and the rendered window — same root cause as the population row above.
  - `[low]` `[reject]` Last run / Next run are read from rendered rows only — same population issue; the assertion fails rather than falsely passes.
  - `[low]` `[patch]` `BANNER_SEVERITIES` is not compared to the `.ocu-banner-*` rules — same root cause as the severity row; patched with it.
  - `[low]` `[patch]` `before.stamp` is captured and never asserted, leaving the matrix's stamp clause unpinned at this tier — verified. Asserting it exposed that the `after` snapshot was taken before the tick landed; the leg now waits for the stamp to move first. Mutation observed red.
  - `[low]` `[reject]` the "(none)" cell's body type is not asserted — the kind-to-face mapping is pinned by Story 2.4's shared data-table tests; the story's own observable (a word, never an empty cell) is asserted.
  - `[low]` `[reject]` the privilege-missing row's rendered half is not exercised for this screen — the spec routes AC5 to the wire test, and "on-screen data stays" is pinned generically by `screen-read.test.mjs`.
  - `[false]` `[reject]` the shipped `equals: "Suspended"` literal meets a suspended instance only at the browser tier — that is the tier AC2 lives at, it runs in CI, and it passed.
  - `[low]` `[reject]` the banner-fault branches are broader than the tested surface — same root cause as the fault-branch row above.
  - `[false]` `[reject]` the banner width resolves DW-139 opposite to the connectivity banner — refuted: that banner's own comment records it as an occurrence rather than a resolution, and its full-width form is for the two states where there is no content column.
  - `[low]` `[reject]` nine prose line citations were repaired by +5 with no gate behind them — all nine were re-resolved by hand against the document and are correct; gating prose comments is a new tool.
  - `[false]` `[reject]` the matrix's "18 vendor rows" is not pinned — pinning a container-dependent count is the wrong assertion (the throwaway lists 19 with the demo fixture); the shape half is pinned exactly.
  - `[false]` `[reject]` the footprint reaches Stories 2.5-2.7's verification surface — DW-267 is an explicit task of this spec (Rule 17, Design Notes).
  - `[low]` `[reject]` the live-container guard compares a name rather than an identity — pre-existing, and the precedent `users.browser-spec.mjs` set.
  - `[false]` `[reject]` the front matter and `## Auto Run Result` disagree — same as the staleness row; written at finalize.

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

**Mutations (Rule 19) — each applied, observed red, reverted; `git status --short` and `git diff --stat` were byte-identical to the pre-mutation snapshot afterwards:**

- AC1 — mutation: drop `"Namespace"` from the descriptor's `read.filter`, regenerate the mirror, rebuild and restart the throwaway → `tasks.browser-spec.mjs`'s namespace leg red: `filtering on "%SYS" left 0 of 19 row(s), expected a proper non-empty subset holding "Switch Journal"`. Observed. **The same mutation applied to the throwaway's server class alone stayed green**, because the filter runs on the client from the built bundle's mirror — so this leg is only falsifiable through a rebuild and a restart, which is what the run above did. This is the mutation Story 2.7 found stayed green before `clearFilter` existed, so it is also the check that DW-267's fix works: the message names both failure modes' observable. `Test/Descriptor.cls`'s `read.filter` equality pin is the second witness, on the declaration.
- AC2 — mutation: change `banner.equals` from `"Suspended"` to `"Running"` → the running leg red (`no strip stands while the Task Manager is running`, the strip rendered with the suspended sentence). Observed; the server class alone is enough here, since the client compares the answered key rather than `equals`. Second half — mutation: make `Read.BannerKey` propagate a port failure instead of answering `""` → `ScreenRead:TestADeclaredBannerIsResolvedInsideTheReadAndNeverFailsIt` red on the faulting fixture (`ERROR #5001: the read failed: ... PORT.NOTIMPLEMENTED`), so the list no longer returns rows. Observed.
- AC3 — mutation: comment out `CreateTask` in `Fixture.cls`'s creator cascade and bring up a fresh throwaway → the demo leg red: `filtering on "nightly purge" left 0 of 18 row(s)`, one row fewer than the fixture's 19. Observed.
- AC4 — mutation: set `"refreshes": false` in the descriptor, regenerate the mirror, rebuild and restart → the auto-refresh leg red on `the command bar carries the auto-refresh chip, which only a refreshing screen renders`. Observed. Stamp half (added at review) — mutation: stop writing `lastUpdateAt` in `ScreenStore.applyTick`, rebuild and restart → the leg red on `the stamp stood before the tick: ""`. Observed. Writing that assertion is what exposed the leg's own weakness: the `after` snapshot was taken when the tick's *request* went out, so every "survives the tick" assertion could read state the tick had not yet touched. The leg now waits for the stamp to move before it snapshots.
- AC5 — mutation: revert `Screen/Area.cls`'s `tasks` entry to `%Admin_Task:USE` alone → four `Test.Descriptor` tests red, naming `OcuPilot.Screen.Descriptor.TaskScheduleList: area 'tasks' does not declare %DB_IRISSYS:READ, ... (AD-8)`, plus the area content pin. Observed.
- Grammar — mutation: add `error` to `screen-mirror.mjs`'s `BANNER_SEVERITIES` → the JS corpus run red on the two severity cases. Observed. Mutation: delete the `bannerProblem` call from `buildMirror` → the generator-refusal assertion red while the corpus run stays green, which is what separates the rule from its wiring. Observed. Mutation: delete the `BannerProblem` call from `Registry.Validate` → `Descriptor:TestABannerOutsideTheGrammarIsRefused` red. Observed.
- Store — mutation: leave `bannerKey` unwritten in `ScreenStore.applyTick` → `screen-store.test.mjs`'s banner test red. Observed.
- String keys (added at review) — mutation: drop `banner.messageKey` from `screen-mirror.mjs`'s `declaredStringKeys` → `screen-mirror.test.mjs`'s "every string key a table or banner declaration names is one the key check reads" red. Observed.
- Severity set (added at review) — mutation: delete `.ocu-banner-warning` from `_components.scss` → "every declared banner severity has a `.ocu-banner-` rule in the stylesheet" red. Observed.
- Tool payload (added at review) — mutation: carry the read's `banner` into the payload `Tool.Read.View` builds → `ReadTool:TestTheToolPayloadCarriesNoBanner` red on `the tool payload carries no banner key`, and only that test. Observed.
- Navigation entry (added at review) — mutation: swap the two pairs in `TaskScheduleList.cls`'s `privileges` → `Wire:TestTheTaskScheduleIsDeniedToAPrincipalWithoutAdminTask` red on both the whole-entry and the `failedPair` assertions, and on nothing else in the suite. Observed — which is the demonstration that the descriptor's pair order, previously pinned only by two hand-written client fixtures, is now pinned against the instance.

## Auto Run Result

Status: done
Blocking condition: none

**What shipped.** A fourth list screen on the three shipped templates: `Screen/Descriptor/TaskScheduleList.cls` declares a `Task.CRUD` LIST through `AdminPort` over `tasks/schedule`, with `Suspended` deliberately absent from its read, table and agent context. Two firsts land with it — the screen declares auto-refresh (`refreshes: true`, rates `[5, 10, 30, 60]`; no client change was needed beyond the mirror), and the descriptor grammar gains a `banner`: a second declared port read, refused at install by `Registry.BannerProblem` and its sentence-for-sentence mirror `bannerProblem`, resolved inside the screen's own read by `Read.BannerKey`, and rendered by `ListPage` as a warning strip above the table. Every fault in the banner answers `""` and never fails the list. DW-267 is closed by `ui/browser/list-spec.mjs`, the one filter helper all four list specs now share.

**Files changed** (49). New: `Screen/Descriptor/TaskScheduleList.cls` (the screen) · `Test/BannerCorpus.cls`, `Test/BannerRegistry.cls`, `Test/Banner/Bad.cls` (the grammar's shared corpus and its refusal fixtures) · `Test/ReadBanner/{Matching,Faulting}.cls` (the match arm and the fault-swallow rule against the real port) · `ui/browser/list-spec.mjs` (the shared filter helper) · `ui/browser/tasks.browser-spec.mjs` (four legs, one per AC). Changed: `Screen/{Area,Registry,Read}.cls` and `Screen/Descriptor/Base.cls` (the `%DB_IRISSYS:READ` pair, the banner rule, its evaluation, its accessor) · `Install/Smoke.cls` and `Test/Smoke.cls` (the fourth area-list check) · `Test/{Descriptor,Navigation,ReadTool,ScreenRead,Wire,WireSecurityRead}.cls` (the moved pins and the new instance-side proofs) · `ui/tools/screen-mirror.mjs` plus the emitted `screens.generated.ts` · `ui/src/app/shell/list-page.ts`, `ui/src/app/core/{refresh,screen-read,screen-store,strings}.ts`, `ui/src/styles/_components.scss` (the strip and the `banner` key's path through the client) · the three sibling browser specs, six pinned fixtures, `EXPERIENCE.md` (one Fixed strings row) and `README.md` (the smoke roster).

**Review.** Four layers, 45 findings: 0 high, 8 medium, 28 low, 9 false. **Nine patched** — the banner's `messageKey` added to the build-time string-key check (a mistyped key shipped an invisible strip with every gate green); a `Wire.cls` leg pinning the tasks navigation entry against the instance (the descriptor's pair order was pinned only by two hand-written client fixtures); a poll for the Task Manager state after `SuspendSet`, which the vendor's own portal waits a second for; the status-bar stamp asserted after the tick (which exposed that the leg's `after` snapshot was taken before the tick landed); the AC2 `finally` no longer masking a leg's real failure; either quote style accepted for the `node:test` import in the browser-spec inventory rule; the read tool's payload pinned to carry no `banner`; the severity set pinned against the `.ocu-banner-*` rules that justify it; and one stale doc count. **Two deferred** (in `deferred:`): a stopped Task Manager raises no strip, because the design specifies only "suspended" and a second sentence is a UX decision; and `EXPERIENCE.md:102`/`:468` still specify a Resume control on this banner, which AC2 was narrowed to drop. **Rejected** — read-tool cost of one discarded in-process call, and the banner endpoint's own privilege rule, both spec-bound by the "one read covers both" design; the `Name`-derived row key, spec-bound by `id.kind: single` and with no duplicate names on the instance; the dropped every-row containment check, whose loss the AC1 mutation compensates by proving the match comes from `Namespace` alone; three fault branches outside the matrix; the `role="status"` strip (banners announce by design here, and `:580`'s "no announcement" governs the refresh stamp); the content-column banner width (the connectivity banner's own comment records that it is not a resolution of DW-139, and its full-width form is for the two states with no content column); and a handful of pre-existing conditions — the dark-theme banner pairing, the collapsed-viewport rendered-row population, the name-based container guard.

**Verification.** `check-objectscript` 189 files / 16 rules / 0 problems · `lint-docs` 0 issues · `screen-mirror.mjs` regenerates with no drift · `npm run build` green through five prebuild checkers · `npm test` 704 node + 240 component, 0 failed. Live `ocupilot` (reads only, one class per call): ReadTool, Descriptor, ScreenRead, Navigation, Smoke — 87 tests, 0 failed; `smoke.sh` PASSED 13/13 with `tasks` passing and `arealists` naming only Logs and OS management. Throwaway `ocupilot-ci`: full suite 50 classes / 467 tests / 0 failed / 0 overlaps / 0 probe leftovers; `smoke.sh` PASSED 14/14; `npm run test:browser` 39/39. Thirteen mutations applied, observed red and reverted. The throwaway was torn down; the live instance's Task Manager reads `TASKMGRStatus` 1, its tasks are intact and no test principal survives.

**Residual risk.** The AC2 leg's new poll returns whatever the instance reports after ten seconds rather than throwing, so a genuinely refused `SuspendSet` fails on the caller's assertion instead of the poll's — a path the run did not exercise, and the reason a follow-up review is recommended. The banner's endpoint is covered by the read's own pair rather than by a rule of its own, so a future banner naming an endpoint behind a resource the screen does not declare would validate and then answer `""` silently; this story's one banner is correctly paired.
