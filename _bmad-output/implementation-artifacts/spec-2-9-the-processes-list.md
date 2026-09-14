---
title: 'Story 2.9: The processes list'
type: 'feature'
created: '2026-09-14'
status: 'in-progress'
baseline_revision: '127c79e92dc0165381f9296fe729c24c49aa1670'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-2-8-the-task-schedule-list.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** OS management has no built screen, so its side-bar entry does not exist and an operator cannot see what is running on the instance without leaving for the classic portal. It is also the screen EXPERIENCE.md:580 names **first** among the six that auto-refresh, and the first list whose rows change on their own.

**Approach:** A fifth list screen on the four shipped templates — one descriptor declaring a `Process` LIST through `AdminPort`, rendered by `ListPage`. Two firsts land with it: the `os-management` area gets its first screen (and, with it, `%DB_IRISSYS:READ`), and the command bar gains the **sort control** EXPERIENCE.md:339 places there — shared surface that reaches all five lists, and the thing that makes AC2's "sort unchanged" falsifiable at all.

## Boundaries & Constraints

**Always:**

- The read declares `%Admin_Operate:USE`, `%Admin_Manage:USE` and `%DB_IRISSYS:READ`, in that order (amended by the lead 2026-09-14; see the Spec Change Log). Probed live 2026-09-14: `%Api.Admin.Endpoints.Process` `ResourcesOR()` answers the single resource `%Admin_Operate` (no OR alternative, unlike `Task.CRUD`), and `Registry.ReadProblem`'s last arm requires the second. `Screen/Area.cls:48` therefore gains `%DB_IRISSYS:READ` **after** `%Admin_Operate:USE` — order matters, because `Gate.EvaluatePairs` names the first unheld pair and `Wire.cls:387` pins the verdict that flips.
- **The vendor's namespace key is `Nspace`, not `Namespace`.** Probed: the LIST row's twenty-one keys are `Job Pid Username Device Nspace Routine Commands Globals State ClientName EXEname IPAddress CanBeExamined CanBeSuspended CanBeTerminated CanReceiveBroadcast PrvGblBlkCnt OSUserName CPUTime ParentPid ElapsedTime`. Numeric ones are `Job Pid Commands Globals PrvGblBlkCnt CPUTime ParentPid`; the four `CanBe*`/`CanReceive*` are booleans; the rest are strings, `ElapsedTime` included (`"76:26:46"`). Declare the vendor's spelling and carry the label in the string key.
- **The sort control is a command-bar control, never a clickable header.** EXPERIENCE.md:386 and :604 give a data-table `role="grid"` with **one Tab stop**; a focusable header cell would break that, and an unfocusable clickable one would be mouse-only. The header keeps `aria-sort` and its arrow (`data-table.ts:188-196`, DESIGN.md:1043) as the readout.
- The control renders in DESIGN.md:1039's existing command-bar vocabulary (a menu button with a ▾, as the View menu is) in its "further screen actions" slot, and calls the **already-shipped** `ScreenStore.setSort` / `setDirection` (`screen-store.ts:215-229`), which already persist per screen through `rememberView()` (`:280-287`). No new persistence.
- Every new string comes from a new EXPERIENCE.md Fixed strings row, inserted **after `:318`** so only the ten `/** EXPERIENCE.md:n */` comments at `:319` and below shift.
- Denial checks run on the throwaway (`scripts/ci-throwaway.sh`, `ocupilot-ci`). `%All` passes every resource check, so a denial needs a real principal.

**Never:**

- **Never terminate, suspend, resume or broadcast to a process, on any instance.** The vendor class declares `TYPEBROADCAST` 10, `TYPERESUME` 11, `TYPESUSPEND` 12 and `TYPETERMINATE` 13; `AdminPort.cls:84 TYPESUFFIXES = "GET,LIST,INFO"` admits none of them, and that is the containment. Those controls are Stories 5.12, 7.8 and 16.6. No `rowActions`, no `primaryAction` — Epic 2 ships read tools only.
- **Never assert that the row set survives a tick.** Rows appear and vanish because processes start and end; AC2 says sort, filter and selection are unchanged, and says nothing about rows. See Design Notes.
- Never declare `Device`, `ClientName`, `EXEname`, `IPAddress`, `ParentPid`, `Job`, `PrvGblBlkCnt`, `CPUTime`, `ElapsedTime` or the four `CanBe*` booleans. The `CanBe*` set exists only to gate the controls this story does not ship; the client and identity columns are Story 6.8's process details.
- No `rowGet` (every declared field is in the LIST), no `banner`, no outbound classic link (`list` archetype, AD-44).
- Never `docker compose up`/`down` against the live `ocupilot` container, and never copy `Test/Screen/Refreshing.cls`'s declaration — it is `namespace`-scoped and carries a `terminate` row action.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| List loads | `GET /api/ocupilot/screens/osmgmt.processes/read?maxRows=1000`, caller holds both pairs | `{fields, rows, truncated, banner}`; `banner` `""`; 63 rows on the live instance, each carrying the seven declared fields | No error expected |
| Cap honoured | `maxRows=5` | Exactly 5 rows. Probed: the port returns 2 for `maxRows=2`, 5 for 5, 63 for 1001 | No error expected |
| Cap default | No `maxRows` on the vendor call | The vendor's own `ClassQuery.GetMaxRows()` defaults to **1000**, so no read is ever unbounded even below OcuPilot's cap | No error expected |
| Never-set field | A daemon row whose `Username` is `""` (12 of 63 rows also have `Nspace` `""`) | Cell renders "(none)" in body type, not an empty cell | No error expected |
| Numbers | `Commands` 87405746, `Globals` 12139941 | `kind: number` → `.ocu-data-table-cell-numeric`, `tabular-nums`, right-aligned (`_components.scss:2063-2067`) | No error expected |
| Privilege missing | Caller holds `%Admin_Operate:USE` and `%DB_IRISSYS:READ` but not `%Admin_Manage:USE` | 403 naming the failing pair `%Admin_Manage:USE`; inline alert, on-screen data stays | `Error.Render` envelope with the pair in `reason` |
| Auto-refresh tick | Rate 5 s, a non-default sort, a filter and a selection in place | Rows re-read in place; sort, filter and selection identical; status-bar stamp updates; no skeleton, nothing announced | A refused tick is never retried |
| Sort persists | A non-default sort set, then the screen is left and re-entered | The chosen field and direction restore from `preferences` key `ocupilot.screen.views` | Unreadable storage falls back to the declared default |

</intent-contract>

## Code Map

**The descriptor**

- `src/OcuPilot/Screen/Descriptor/TaskScheduleList.cls:51-102` — the closest template (auto-refresh, `instance` scope, `single` id, `%DB_IRISSYS:READ`). Copy its shape and doc-comment voice; drop its `banner`. `SslConfigList.cls:32-75` is the no-banner form.
- `src/OcuPilot/Screen/Registry.cls` — `Validate` `:131-247` refuses in order: read `:182` → `MalformedPair` `:190` → `AreaCoverageProblem` `:198` → `RefreshProblem` `:207` → `BannerProblem` `:216` → `ClassicLinkProblem` `:227` → route uniqueness `:233`. `ReadProblem`'s `%DB_IRISSYS:READ` arm `:563-574`; `AreaCoverageProblem` `:307-327`; column kinds `:670`.
- `src/OcuPilot/Screen/Read.cls:79-145` `Execute` — `maxRows + 1` at `:100`, cap at `:123`, `truncated` at `:137`, response keys `:134-138`. Untouched by this story.
- `src/OcuPilot/Kernel/EntityType.cls:22` — `process` is already in the closed vocabulary; the count pin (`Test/Descriptor.cls:530`, 26) does not move.
- `src/OcuPilot/Screen/Descriptor/` holds descriptors flat; regenerate with `node ui/tools/screen-mirror.mjs`.

**Area, and the pins that move**

- `src/OcuPilot/Screen/Area.cls:48` — `{"key":"os-management","railPosition":3,…,"privileges":[{"resource":"%Admin_Operate","permission":"USE"}]}`. Append the second pair; update the doc at `:18-24`, which enumerates the areas naming `%DB_IRISSYS:READ`.
- `src/OcuPilot/Test/Descriptor.cls:628` — `$ListBuild("os-management", "%Admin_Operate:USE", 0, 0)` → `"%Admin_Operate:USE, %DB_IRISSYS:READ"` (`PairText` `:655-664` joins in declared order). New per-descriptor test on the template at `:164-205`. `:191` (`exactly one shipped descriptor declares a banner`) must stay 1.
- **`src/OcuPilot/Test/Wire.cls:387`** — `$Get(tVerdict("os-management")) = 1` for the `%Admin_Operate`-only `#ADMINUSER`. Adding the pair **flips this to a denial**; rewrite it as a `failedPair` assertion. Easy to miss and it is a real behaviour change for that principal. New denial leg on the template at `:521-550`.
- `src/OcuPilot/Test/WireSecurityRead.cls` — `SYSREADUSER` (`:103`, `%DB_IRISSYS:R,%Admin_Operate:U`) is **already exactly this screen's allowed principal**. The denial side needs a new `%Admin_Operate:U`-only pair beside `:26-53`, wired at `:107`, `:117`, and into both cleanup lists `:141`/`:145`; leg template `:234`; count literals `:236`, `:318`.
- `src/OcuPilot/Test/ReadTool.cls:93` (`4`→`5`), `:94` (the `$Order`-alphabetical roster — `osmgmt.processes.read` sorts **first**), `:95` (a fifth `$ListBuild` pair), `:150` (the class roster).
- `src/OcuPilot/Test/Navigation.cls:214-232` (the area-gate arms gain `os-management`) and `:251-281` (the payload now carries a screen under an area that had none).
- `src/OcuPilot/Test/ScreenRead.cls:179-239` — **no edit**: the drift guard walks the roster and holds every `read.fields` and `context.fields` entry to the live row, so a wrong key (`Namespace` for `Nspace`) fails at `:227` naming the field.

**Smoke**

- `src/OcuPilot/Install/Smoke.cls:450` loop bound `4`→`5`; `:451` names `"webapplications,users,ssl,tasks"` → append `,processes`; `:455` a fifth `$Select` arm **before** the pinned `, 1: "")` catch-all; a `PROCESSLISTTOOL` parameter beside `:58`; doc `:438-446`; **`:558`** the `arealists` pending note drops "OS management", leaving Logs.
- `src/OcuPilot/Test/Smoke.cls:133` and `:136-139` (pending note by content), `:257-258`/`:269-272` (fail lines), `:297`, `:300-303` (`4`→`5`, the expected tool list, the loop bound), new live-check test on the template at `:235-241`. `:321-362` needs **no** edit — it derives loop bound, name count and arm count from `Smoke.cls`'s own source and asserts they agree.

**Client — the sort control**

- `ui/src/app/shell/command-bar.ts:129-138` — the auto-refresh chip; the sort control goes beside it. `onAdvanceRate` `:279` is the shape to follow for a command-bar control that writes the store.
- `ui/src/app/core/screen-store.ts:215-229` `setSort`/`setDirection` — **zero production callers today**; `rememberView()` `:280-287` already writes `{sort, direction, filter, maxRows}` to `preferences.setScreenView` (`preferences.ts:184-187`, key `ocupilot.screen.views` `:41`), and the constructor restores at `:80-87`. `applyTick` `:131-137` writes only rows/truncated/banner/lastUpdateAt, so sort survives a tick by construction.
- `ui/src/app/shell/data-table.ts:539-556` `get headers` — resolves the effective sort field (`:544`, falling back to `read.sort.default`) and direction (`:545`); `:188-196` emits `aria-sort` and the arrow span. Read-only readout; do not add a handler.
- `ui/src/app/core/screen-read.ts:105-114` `applyView` — the shared view rule (case-insensitive contains, stable one-field sort, numbers numerically, `null` last).
- `ui/src/app/core/table-model.ts:65-91` `cellView` — `number` → `numeric:true`; `identifier` → `code:true`; `name` → `code:true, link:true`. `:170-183` `reconcile` — on a re-fetch the **active row clamps to its old index** and the **selection clears when its key is gone**; `rowKey` `:37-43` derives from the `name` column's field for a `single` id.
- `ui/src/app/shell/list-page.ts:43-53` — needs no change; a list screen is entirely descriptor-driven.

**Client — the pins that move**

- `ui/tools/navigation.test.mjs:112-116` — `['', 'tasks/schedule', …]` gains `'os-management/processes'` at **index 1** (os-management is rail 3, tasks is rail 4); reword `:115`.
- `ui/tools/navigation-wire.test.mjs:34-129` and `ui/src/app/shell/rail-wire.spec.ts:34-129` — two byte-identical `LIVE_PAYLOAD` copies, each with `os-management` at `:46-54` holding `screens: []`. **Neither goes red on its own.**
- `ui/tools/screen-mirror.test.mjs:428` — `['SslConfigList','TaskScheduleList','UserList','WebAppList']` gains the fifth; `:477-478` asserts every non-TaskScheduleList descriptor has `banner === null`, which the new one satisfies.
- `ui/tools/strings.test.mjs` — `:297-302` the 126–154 Fixed-strings band, `:328-343` the **derived** closed-world equality (168 keys today; `REQUIRED_ALONGSIDE_TABLE` is pinned at 3 and must not grow), `:432-438` duplicate **values** refused, `:481-518` every `/** EXPERIENCE.md:n */` comment re-resolved.
- `ui/src/app/core/strings.ts` — reuse `tableColumnName:309`? **No** — the Pid column is not "Name". Reuse only `headerNamespaceLabel:398` ('Namespace') and `tableReadOnlyEmptyNext:321`. Ten comments at `:319` and below shift when a row is inserted after EXPERIENCE.md`:318`.
- `ui/tools/angular-json.test.mjs:247-280` — a `.mjs` in `ui/browser/` importing `node:test` **must** be named `*.browser-spec.mjs`; `:300-310` pins origin `http://localhost:52776` and refuses the live container.
- `ui/browser/list-spec.mjs` — `viewCount` `:40-47` (reads `aria-rowcount` minus the header; never DOM rows), `clearFilter` `:50-61`, `filterToSubset` `:74-107` (clears first, then `0 < kept < total` and `expectRow` present).
- `ui/browser/tasks.browser-spec.mjs:295-398` — the AC4 "survives the tick" leg: synthetic click for selection (`:310-312`, DW-273), `scrollTop` on `cdk-virtual-scroll-viewport` (`:314-317`), the `before`/`after` snapshots (`:319-335`, `:381-398`), the chip (`:343-352`), and the **two-stage** tick wait — a read issued (`:362-367`) then the stamp moved (`:375-379`). Its `:301-303` comment records that it cannot drive a sort because no control ships.

**Read-only evidence (live `ocupilot`, 2026-09-14, reads only)**

- `AdminPort.Invoke("Process","LIST",…)` → HTTP 200, 63 rows in **8.9 ms**; `%Api.Admin.Endpoints.Process` has `TYPELIST` 0, `TYPEGET` 1, **no** `TYPEINFO`, and `ShouldRunAsync()` 0 for LIST (synchronous — no AD-26 path).
- `Pid` is unique across the 63 rows (no duplicates), so it is a sound `rowKey`. `Nspace` is `%SYS` 49, `HSCUSTOM` 2, `""` 12 — the read spans namespaces, so it is **instance**-scoped.
- The classic page is **`%CSP.UI.Portal.Processes`** (enumerated in `%SYS`; `%CSP.UI.Portal.ProcessDetails` is Story 6.8's).
- Three LIST samples two seconds apart returned the identical 63 PIDs in identical order on an idle instance — but see Design Notes for why no test may rely on that.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Screen/Area.cls` — append `{"resource":"%DB_IRISSYS","permission":"READ"}` to the `os-management` entry after `%Admin_Operate:USE`, and correct the doc at `:18-24`. Without it `AreaCoverageProblem` refuses the screen at install.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` — **before the descriptor and before `strings.ts`**, because `strings.test.mjs:328-343` is a closed-world equality derived from this table and a key with no row fails the build. Insert **two** rows after `:318`: (1) the Processes row — `"Processes" · "Process ID" · "User" · "Routine" · "State" · "Commands" · "Globals" · "No processes on this instance."` — its Where cell citing the side-bar list (`:164`), the IA row (`:91`), Namespace reusing the namespace switch's accessible name, the empty state naming the instance because the read spans namespaces, and its second line being the Web applications row's; (2) the sort-control row — `"Sort" · "Ascending" · "Descending"` — citing the command-bar composition (`:339`) and the announcement rule (`:604`). Also sharpen `:91`'s Purpose cell with the column roster, as 2.6–2.8 did to theirs.
- `ui/src/app/core/strings.ts` — add `processListLabel`, `processColumnPid`, `processColumnUser`, `processColumnRoutine`, `processColumnState`, `processColumnCommands`, `processColumnGlobals`, `processListEmpty`, `sortMenuLabel`, `sortDirectionAscending`, `sortDirectionDescending`, each with its `/** EXPERIENCE.md:n */` comment; **then bump by two the ten existing comments that point at lines ≥ 319**. None of the eleven values collides with an existing one (checked).
- `ui/src/app/shell/command-bar.ts` (+ its spec and `ui/src/styles/_components.scss` if the menu needs a class) — add the sort control: shown only when the screen's declaration carries `read.sort.fields`, labelled `sortMenuLabel`, offering each declared sort field under its **column's own `labelKey`** plus the two directions, and calling `store.setSort` / `store.setDirection`. Ordinary Tab stop; no new keyboard binding; the data-table is untouched.
- `src/OcuPilot/Screen/Descriptor/ProcessList.cls` — new, after the two above so every key it names exists. Route `os-management/processes`, area `os-management`, `labelKey` `processListLabel`, `sideBarPosition` 1, archetype `list`, `built` true, `refreshes` true, `refreshRates` `[5, 10, 30, 60]`, privileges `%Admin_Operate:USE` then `%DB_IRISSYS:READ`, `entityType` `process`, `secondaryEntityTypes` `[]`, scope `instance`, `parentScope` `""`, id `{"kind":"single","parts":[]}`, `primaryAction` `{"id":"","selfProtection":""}`, `rowActions` `[]`, `commandAliases` `["jobs"]`, `emptyStateKey` `processListEmpty`, `classicPage` `%CSP.UI.Portal.Processes`, `classicLinkExemption` not exempt, `toolIdentifier` `osmgmt.processes`, `context` `{"fields": the seven read fields, "secretFields": []}`. `read.source` `{port: admin, endpoint: "Process", type: "LIST"}`; `read.fields` `["Pid","Username","Nspace","Routine","State","Commands","Globals"]`; `filter` `["Pid","Username","Nspace","Routine","State"]`; `sort.fields` all seven, default `Pid`, direction `asc`; `paging` `"cap"`. `table.columns`: `Pid`/`processColumnPid`/**name**, `Username`/`processColumnUser`/text, `Nspace`/`headerNamespaceLabel`/text, `Routine`/`processColumnRoutine`/**identifier**, `State`/`processColumnState`/text, `Commands`/`processColumnCommands`/**number**, `Globals`/`processColumnGlobals`/**number**. `emptyNextKey` `tableReadOnlyEmptyNext`, `emptyAgentKey` `""`. The class doc comment states why the write types and the `CanBe*` fields are absent, and that `Nspace` is the vendor's spelling.
- `src/OcuPilot/Test/Screen/Refreshing.cls:1-7` — correct two claims at their origin: "No screen on the production roster refreshes" (false since 2.8) and the `:577` citation for the six-screen roster (it is `EXPERIENCE.md:580`). The fixture keeps its route: its registry overrides `DescriptorPackage()` and is never rostered with production (verified — `Screen.Read.Execute("osmgmt.processes")` answers `<CLASS DOES NOT EXIST>` today).
- `src/OcuPilot/Test/Descriptor.cls`, `Test/ReadTool.cls`, `Test/Wire.cls`, `Test/WireSecurityRead.cls`, `Test/Navigation.cls` — update the pins named in the Code Map and add the two new legs.
- `src/OcuPilot/Install/Smoke.cls` and `src/OcuPilot/Test/Smoke.cls` — the fifth area-list check and the pins that read it.
- `ui/tools/navigation.test.mjs`, `ui/tools/navigation-wire.test.mjs`, `ui/src/app/shell/rail-wire.spec.ts`, `ui/tools/screen-mirror.test.mjs` — update the four client pins; regenerate `ui/src/app/core/screens.generated.ts` with `node ui/tools/screen-mirror.mjs` and stage it (never hand-edit).
- `ui/tools/screen-store.test.mjs` — extend 2.8's "a tick leaves sort, direction, filter, selection and scroll alone" test to cover the sort control's writes, and add a test that a sort set through the control survives a store rebuild from `preferences` (the persistence half of AC1).
- `ui/browser/processes.browser-spec.mjs` — new spec, three legs, one per AC, importing `list-spec.mjs`.

**Acceptance Criteria:**

- **Given** a caller holding `%Admin_Operate:USE`, `%Admin_Manage:USE` and `%DB_IRISSYS:READ`, **when** the Processes screen loads at `os-management/processes`, **then** the table lists the instance's processes under Process ID, User, Namespace, Routine, State, Commands and Globals; typing into the command bar's filter narrows the rows to a proper non-empty subset; and the footer's max-rows field is editable and re-reads at the new cap. *(Integration AC — the screen reads through the route against a real instance, not a fixture.)*
- **Given** the command bar's sort control, **when** the user chooses a sort field other than the declared default and then leaves and re-enters the screen, **then** the table is ordered by that field, the header carries `aria-sort` on it, and the choice is still in force after the re-entry.
- **Given** the screen declares auto-refresh, **when** the user sets a rate from the command-bar chip with a **non-default sort**, a filter and a selection in place, **then** the rows re-read on that interval and the sort, filter and selection are unchanged and the status-bar stamp moves, with no skeleton shown and nothing announced. *(Integration AC — driven through the route in a real browser against the throwaway, not through the store.)*
- **Given** the rendered table, **when** a row paints, **then** the Process ID cell is `code`, the Routine cell is `code`, and the Commands and Globals cells are tabular and right-aligned; an empty `Username` or `Nspace` reads "(none)" rather than blank.
- **Given** a real principal on the throwaway holding `%Admin_Operate:USE` and `%DB_IRISSYS:READ` but not `%Admin_Manage:USE`, **when** it opens the Processes screen, **then** it is refused with `%Admin_Manage:USE` named as the failing pair and on-screen data stays; **and** the principal holding both is served the list, with `Registry.Validate` reporting no problem for this descriptor at install.

## Spec Change Log

- 2026-09-14, dev pass (deviation, **for the lead**): the declared pair set is **three** pairs, not
  two. `%Admin_Operate:USE` is the endpoint's `ResourcesOR()` gate as the spec probed, but the query
  behind it — `SYS.Process:CONTROLPANEL` — checks `%Admin_Manage:USE` *or* `%DB_IRISSYS:WRITE` for
  itself (`%SYS.ProcessQuery.CONTROLPANELExecute`, read in `irislib/`). A real principal holding the
  spec's two pairs is answered **500**, not the list, so AC5's "the principal holding both is served
  the list" was false as written. The descriptor and the `os-management` area declare the narrower
  half, `%Admin_Manage:USE`, between the other two; AC5's denial is observed on that pair instead.
  The 500 is `<INVALID OREF>AppendStatementResult+5^%Api.Admin.Util.ClassQuery.1`: the vendor helper
  does not check what `%Execute()` answered.
- 2026-09-14, lead (owner-delegated decision on the plan's intent gap, rework iteration 1): the recommended amendment is accepted. The declared pair set is `%Admin_Operate:USE`, `%Admin_Manage:USE`, `%DB_IRISSYS:READ`, in that order, and AC5's denial is observed on `%Admin_Manage:USE`; the `os-management` area carries the same three. AD-29 is amended at origin: an endpoint's `ResourcesOR()` is a lower bound, and a screen's pair set is established by running the read as a real least-privileged principal on a throwaway. The port's disguised 500 - a query's own privilege refusal arriving as a server fault with no pair named - is DW-274, routed to the burn-down; it is not this story's to fix. The third option (leave two pairs and let the port surface the query's status) was considered and refused: the area would list a screen it cannot serve, which is the DW-263 defect again.

## Review Triage Log

## Design Notes

**Governing architecture decisions (Rule 6).** AD-2 and AD-27 (`AdminPort` is the only caller of `%Api.Admin.*`; `TYPESUFFIXES` is what keeps the four write types unreachable) · AD-5 (one descriptor is the source of route, gate, read tool and table) · AD-8 (the pair set is an AND, evaluated per call; a denial names the failing pair) · AD-13 (the scoped triple; `instance` scope) · AD-19 (the store owns sort/filter/selection; components read signals — the sort control writes the store, never a component field) · AD-24 (the seven context fields are the capped payload; no secret fields) · AD-29 (`AdminPort` inherits the vendor's `ResourcesOR()` gate) · AD-36 (one declared read serves screen and tool, bounded by the cap; **no `rowGet`**) · AD-43 (live data has one framework; EXPERIENCE.md:580's roster names Processes **first** of the six) · AD-44 (a `list` archetype never links out; the descriptor declares `%CSP.UI.Portal.Processes`, so an operator's custom resource on that classic key still applies) · AD-45 (one smoke path). AD-6, AD-10, AD-14, AD-15 and AD-34 are not reached: this story writes nothing.

**Consumes:** Story 1.9's `Registry`, `Area` and `Gate`; Story 1.14's `RefreshService`, `ScreenStore`, `preferences` and the command-bar chip; Story 2.1's `AdminPort`; Story 2.3's `Screen.Read` and `GET /screens/:screen/read`; Story 2.4's `DataTable`, `ListPage` and its `reconcile`; Story 2.8's `ui/browser/list-spec.mjs`.

**Consumed-by:** Story 5.12 (agent-proposed suspend and resume from this list) · Story 6.8 (process details, which this list's Process ID cell navigates to) · Story 7.8 (terminate, suspend, resume) · Story 16.6 (P1 broadcast, the only thing needing multi-select here) · Epic 4 (dispatches `osmgmt.processes.read`). **The sort control is shared surface introduced here, and its first consumers are in this story:** every descriptor declaring `read.sort.fields` — all five list screens, the four shipped ones included. Its ACs are AC2 above; the four shipped lists are re-verified by `npm run test:browser`.

**Why this story adds the sort control, rather than reading "persists" as "the default survives".** EXPERIENCE.md:339 places sort in the command bar by name; :604 says "Selection and sort state are announced", and a state nothing can change is never announced; :580 says "Setting, sort, filter and max rows persist per screen" for this screen's own roster; :91 lists "persisted sort" beside filter, max rows and auto-refresh, the three operable controls that ship. The decisive argument is Rule 19: `applyTick` never writes sort, so while the sort can only ever equal the declared default, "sort unchanged after a tick" is **structurally unfalsifiable** at the browser tier — `before` already equals what a reset would produce. Story 2.8's QA pass found exactly this hole and could only close it at the store tier (`tasks.browser-spec.mjs:301-303` records why). AC2 here names sort first, on the screen the requirement is written for; shipping the same hole a second time is what Rule 19 exists to stop. The shape is not invented: DESIGN.md:1039's command bar ends with "further screen actions as `button-text`" and gives the View menu as "`button-secondary` with a ▾", and EXPERIENCE.md:386's "one Tab stop" is what rules out the header affordance. Only the copy is new, and it arrives as a cited Fixed strings row.

**Why no test may assert the row set survives a tick.** This is the first list whose rows change with no write behind them, and EXPERIENCE.md is silent on it: `:578`'s "a deleted row leaves the list … a created row appears highlighted" is scoped to a **change event from a confirmed write**, and the "Changed" tag (`:462`) would be a false statement over a process that merely started. Three LIST samples two seconds apart were identical on an idle instance, but that is a property of an idle instance, not of the endpoint — a browser run drives CSP worker and SQL query processes into and out of the very list it is asserting over. So the AC2 leg asserts the four state slots and the stamp, and deliberately **not** `after.names === before.names` (which is where 2.8's leg put half its confidence). Selection is made non-flaky by filtering to a core daemon first — `WRTDMN` is started by IRIS at instance start and cannot exit while it runs — so the selected row cannot legitimately vanish and `reconcile()` (`table-model.ts:170-183`, DW-18's delivered behaviour: active clamps to its old index, selection clears when its key is gone) is never triggered by churn. That makes the leg's red mean "the tick reset a slot", never "a process ended".

**Known gaps this story inherits and does not re-file (Rule 17 — this story owns no ledger entries).** **DW-273** constrains AC2's driving rather than blocking it: the table frame collapses to header height, so the viewport reads `clientHeight` 0 and a real pointer click at a row's centre reaches the footer. The leg therefore dispatches a synthetic click for the selection, as `users` and `tasks` already do, and sets `scrollTop` directly. The consequence worth stating: with `clientHeight` 0 the virtual scroller never recycles inside the shell, so no browser leg of this story can exercise `reconcile()` under real recycling — that is pinned by `table-model.test.mjs` and `data-table.browser-spec.mjs`'s harness page, which has no shell. **DW-260** (no list offers the manual Refresh action EXPERIENCE.md:565 requires) reaches this screen too; it is the fifth list to ship without one, and it stays `owner=burndown`. **DW-271** (a misspelled top-level descriptor key installs silently) is live for every key this descriptor declares.

**Pid is the `name` column.** `rowKey` derives from the `name` column's field for a `single` id (`table-model.ts:41-42`), and `Pid` is unique across the live population (probed), so the row key is sound. `name` renders `code: true` **and** `link: true`, which is what AC3's "process ids are set in `code`" asks for; the link's target is Story 6.8's process details and is inert until then, exactly as the task schedule's Name cell is inert until 6.7. `Routine` takes `identifier` (code, no link) per DESIGN.md:875 and `:1043`, which names *pid* among the identifier columns.

**`kind: number` has no production user today** — four shipped descriptors use `name`, `identifier`, `text` and `status` only. `Commands` and `Globals` are its first, which is why AC3 carries its own pinning test rather than resting on Story 2.4's shared table tests.

**The empty state is grammar, not a reachable view.** A zero-row process list cannot happen — the caller is itself a process. The key is declared because the grammar requires every `list` descriptor with a `read` to carry it (Conventions › Screen archetype); its rendering is pinned generically by Story 2.4's tests, and no live read pins it here. The sentence names the instance, not a namespace, because the read spans `%SYS`, `HSCUSTOM` and the unnamespaced daemons (probed).

## Verification

**Commands:**

- `uv run scripts/check-objectscript.py` — expected: clean over every changed `.cls` (16 rules).
- `cd ui && node tools/screen-mirror.mjs` then `git diff --stat ui/src/app/core/screens.generated.ts` — expected: the fifth descriptor appears; stage the regenerated file.
- `cd ui && npm run build` — expected: the six `prebuild` checkers pass, `screen-mirror.mjs --check` included.
- `cd ui && npm test` — expected: `node --test tools/*.test.mjs` plus the Angular component runner green, with `navigation.test.mjs`, `navigation-wire.test.mjs`, `screen-mirror.test.mjs`, `strings.test.mjs`, `screen-store.test.mjs`, `command-bar.spec.ts` and `rail-wire.spec.ts` all **updated rather than skipped**.
- `bash scripts/lint-docs.sh` — expected: clean after the two EXPERIENCE.md rows.
- IRIS MCP (`server: "ocupilot-iris"`): load and compile `src/OcuPilot/`, then run **one** `iris_execute_tests` call per message and wait for it to land in `%UnitTest_Result` before the next — `Test.Descriptor`, `Test.ReadTool`, `Test.ScreenRead`, `Test.Navigation`, `Test.Smoke`. **Never two test calls in one message.**
- `sh scripts/ci-throwaway.sh up && sh scripts/wait-readiness.sh --url http://localhost:52776/api/ocupilot/readiness/`, then from `ui/`: `OCUPILOT_BROWSER_EXECUTABLE="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" node --test --test-concurrency=1 browser/processes.browser-spec.mjs`, then the full `npm run test:browser` (the sort control reaches all five lists). Finish with `sh scripts/ci-throwaway.sh down`.
- `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` — expected: five area-list checks, the `processes` one reading `osmgmt.processes`; zero executed checks is a failure, never a pass.

**Nothing in this story terminates, suspends, resumes or broadcasts to a process on any instance.** `Test.Wire` and `Test.WireSecurityRead`'s principals are created and deleted on the throwaway only; live `ocupilot` is read-only throughout, and no `docker compose up`/`down` runs against it.

**Mutations (Rule 19) — one per AC. Apply, observe red, revert, and confirm `git status --short` and `git diff --stat` are byte-identical to the pre-mutation snapshot:**

- AC1 — mutation: change the descriptor's `read.fields` entry `"Nspace"` to `"Namespace"`, regenerate the mirror → `Test.ScreenRead`'s field-presence drift guard red naming `Namespace` as absent from the live row, and the browser leg's namespace filter red on `0 of N rows`. Second witness: `Test/Descriptor.cls`'s `read.fields` equality pin, on the declaration.
- AC2 — mutation: drop `"Commands"` from the descriptor's `read.sort.fields`, regenerate, rebuild, restart the throwaway → `processes.browser-spec.mjs`'s sort leg red because the control no longer offers the field it selects. Persistence half — mutation: remove the `rememberView()` call from `ScreenStore.setSort` → `screen-store.test.mjs`'s new restore test red, and only it.
- AC3 — mutation: set `this.sortBy = ''` in `ScreenStore.applyTick` → the browser AC3 leg red on the sort snapshot **and** `screen-store.test.mjs`'s tick test; `this.filterText = ''` instead reddens the filter clause alone. This mutation is the one that was unobservable at this tier before the sort control existed.
- AC4 — mutation: change the `Commands` column's `kind` from `number` to `text`, regenerate, rebuild → the render leg red on the missing `.ocu-data-table-cell-numeric`. Second: change `Pid`'s kind from `name` to `text` → red on the missing `.ocu-data-table-code`, and `screen-mirror.mjs` refuses the table outright (exactly one `name` kind), which is the stronger witness.
- AC5 — mutation: revert `Screen/Area.cls`'s `os-management` entry to `%Admin_Operate:USE` alone → `Test.Descriptor` red naming `OcuPilot.Screen.Descriptor.ProcessList: area 'os-management' does not declare %DB_IRISSYS:READ (AD-8)`, plus the area content pin and the rewritten `Wire.cls:387` verdict. Swap the two pairs in the descriptor's `privileges` instead → the new `Wire` leg red on `failedPair`, and nothing else.

## Auto Run Result

Status: blocked
Blocking condition: intent gap — the intent contract's declared privilege set is un-implementable as worded; the amendment is a lead decision (Rule 5, Rule 20)

**The gap.** Three statements inside `<intent-contract>` are false on this build, and no change to the
code can make them true. `%Api.Admin.Endpoints.Process` `ResourcesOR()` answers `%Admin_Operate`, as
the spec probed, but the query behind it does its own check: `irislib/%SYS/ProcessQuery.cls:994`
`CONTROLPANELExecute` opens `i '($SYSTEM.Security.Check($$$AdminManageResourceName,$$$PermUseName)!$$$IOwnSYSDBWrite)`
— `%Admin_Manage:USE` **or** write on IRISSYS. A principal holding exactly the spec's two pairs is
answered **500**, not the list (`%Api.Admin.Util.ClassQuery` never checks what `%Execute()` returned).
So: **Boundaries › Always #1** ("The read declares `%Admin_Operate:USE` **and** `%DB_IRISSYS:READ`");
the matrix row **List loads** ("caller holds both pairs"); and the matrix row **Privilege missing**
("holds `%Admin_Operate:USE` but not `%DB_IRISSYS:READ` → 403 naming `%DB_IRISSYS:READ`"). The last is
what fails the Matrix Test Audit: it is not merely uncovered, it is unreachable — under any sound
declaration `%Admin_Manage:USE` is refused first — and the audit forbids editing the expectation to
match the code.

**Recommended amendment (lead's call).** Amend the two matrix rows and the Always bullet to the
three-pair set `%Admin_Operate:USE`, `%Admin_Manage:USE`, `%DB_IRISSYS:READ` in that order, and
restate AC5's denial on `%Admin_Manage:USE`. This is what the dev pass implemented and verified. Two
consequences the lead owns rather than the pipeline:

1. **It widens the gate for a whole area, not one screen.** `AreaCoverageProblem` (AD-8) forces the
   area to cover its screens' pairs, so `os-management` carries all three and an operator holding
   `%Admin_Operate` alone loses the rail item — today decorative (the area had no screens), but it
   also pre-gates Locks and Process details (6.8, 7.8) on `%Admin_Manage`.
2. **The alternative was rejected inside the pass, not by the lead.** The vendor check is an OR;
   its other half is `%DB_IRISSYS:WRITE`, which the spine's Conventions call a self-escalation
   primitive. A third option exists and was not taken: leave the declared set at two pairs and make
   `AdminPort` surface the query's own `$$$OperationRequires` status as a named 403 instead of a
   500 — the screen would then be listed for an `%Admin_Operate`-only operator and refuse on open.

**Architectural weight (Rule 20).** "An admin-API endpoint's `ResourcesOR()` gate is not necessarily
the whole privilege requirement; the query behind it may check more, and a descriptor that declares
only the endpoint's gate yields a 500 instead of a named 403" constrains every later `AdminPort`
screen (Epics 5–7). AD-29's Rule currently reads as though inheriting `ResourcesOR()` settles it.
Only the lead writes the spine.

**State of the tree.** The implementation is complete and verified against the amended set; nothing
is committed. Re-dispatch after the amendment should need no re-implementation — only AC5's wording
and this section. The stale `## Verification` AC5 mutation line (it still names `%DB_IRISSYS:READ`)
goes with that edit.

**Lead-verified independently of the dev pass:** `check-objectscript` 190/16/0 · `lint-docs` 0 issues
· `npm run build` green · `npm test` 710 node + 249 component, 0 failed · `%UnitTest_Result` on live
`ocupilot`, latest run per class: 49 `OcuPilot.Test.*` classes, 0 failed. The throwaway and browser
legs below are the dev pass's own evidence, not re-run.

**What shipped.** A fifth list screen on the four shipped templates: `Screen/Descriptor/ProcessList.cls`
declares a `Process` LIST through `AdminPort` over `os-management/processes`, with the vendor's own
`Nspace` spelling, `Pid` as the `name` column and `Commands`/`Globals` as the first `number` columns
any descriptor ships. Two firsts land with it — the `os-management` area gets its first screen, and
the command bar gains the **sort control** (`sortMenuLabel`, `sortDirectionAscending`,
`sortDirectionDescending`): a `button-secondary` with a ▾ that offers each declared sort field under
its own column's label key plus the two directions, and writes `ScreenStore.setSort`/`setDirection`,
which already persist per screen. The data table is untouched; its header keeps `aria-sort` as the
readout, so the grid stays one Tab stop.

**Deviation (see Spec Change Log).** The pair set is three pairs, `%Admin_Manage:USE` between the
other two, because the query behind the endpoint checks it for itself. Without it a real
least-privileged principal is answered 500 rather than the list.

**Verification.** `check-objectscript` 190 files / 16 rules / 0 problems · `lint-docs` 0 issues ·
`screen-mirror` regenerates with no drift · `npm run build` green through six prebuild checkers ·
`npm test` 710 node + 249 component, 0 failed. Live `ocupilot` (reads only, one class per call):
Descriptor, ReadTool, ScreenRead, Navigation, Smoke — 89 tests, 0 failed; `smoke.sh` PASSED 14/14
with `processes` passing and `arealists` naming only Logs. Throwaway `ocupilot-ci` (clean container
from the final source and bundle): 50 classes / 471 tests / 0 failed / 0 overlaps / 0 probe
leftovers; `smoke.sh` PASSED 15/15; `npm run test:browser` 43/43. The throwaway was torn down; the
live instance was never recreated, holds no test principal and reads `TASKMGRStatus` 1.

**Mutations (Rule 19), each applied, observed red and reverted; `git status --short` and
`git diff --stat` were byte-identical to the pre-mutation snapshot afterwards.**

- AC1 — `Nspace` → `Namespace` throughout the declaration, mirror regenerated → `Test.ScreenRead`'s
  drift guard red naming `Namespace` as absent from the live row, and `Test.Descriptor`'s
  `read.fields` pin red on the declaration. Observed.
- AC2 — drop `Count` from `tableDeclaration`'s `read.sort.fields` → four `command-bar.spec.ts` sort
  tests red, the first on the offered field list. Observed. Persistence half — remove
  `rememberView()` from `ScreenStore.setSort` → `screen-store.test.mjs`'s new restore test red, and
  **only** it (the AC9 test above it sets four slots in a row and stays green, which is why the new
  test sets one at a time). Observed.
- AC3 — `this.sortBy = ''` in `ScreenStore.applyTick`, rebuilt and the throwaway restarted → the
  browser AC3 leg red on `the sort survives the tick` (`['descending', ...]` against
  `[..., 'descending']`), the AC2 leg red with it, plus `screen-store.test.mjs` and
  `refresh.test.mjs` at the store tier. **This is the mutation that was unobservable at the browser
  tier before the sort control existed** — Story 2.8's QA pass could only close it at the store.
  Observed.
- AC4 — `Commands` kind `number` → `text`, regenerated and rebuilt → the browser AC4 leg red on
  `the Commands cell is numeric`. Observed. Second witness: `Pid` kind `name` → `text` →
  `screen-mirror.mjs` refuses outright (`table.columns declares 0 name column(s)`). Observed.
- AC5 — revert `Screen/Area.cls`'s `os-management` entry to `%Admin_Operate:USE` alone → five
  `Test.Descriptor` tests red naming `OcuPilot.Screen.Descriptor.ProcessList: area 'os-management'
  does not declare %Admin_Manage:USE, ... (AD-8)`, plus the area content pin. Observed. Second —
  remove `%Admin_Manage:USE` from the descriptor **and** the area → `WireSecurityRead`'s processes
  leg red on all five denial assertions (the read is no longer refused; it 500s). Observed, and it
  is what proves the middle pair is load-bearing rather than decorative.
