---
title: 'Story 6.11: Databases, with free space arriving as it lands'
type: 'feature'
created: '2026-09-17'
status: 'blocked'
review_loop_iteration: 0
followup_review_recommended: false
baseline_revision: '5c8559d371d3dab76255bb4fb8d2c2513c24659e'
baseline_commit: '5c8559d371d3dab76255bb4fb8d2c2513c24659e'
context: []
warnings: ['oversized']
deferred: []
---

# Story 6.11: Databases, with free space arriving as it lands

## Auto Run Result

Status: blocked
Blocking condition: intent gap

Six load-bearing decisions cannot be taken against the descriptor grammar, the read contract or the
vendor surface as they stand. Each has two or more defensible readings with observably different
outcomes, and nothing in `epics.md`, the spine or the UX spines selects between them. The questions
are below, each with a recommended option and the text this spec would carry if the lead picks it.
`## Code Map` holds the probe evidence so the next pass re-reads nothing; the size warning is that
evidence, which the next pass consumes and replaces.

## Clarification Needed

### Q1 — Per-row arrival of the free-space figures is not expressible in the read contract

`EXPERIENCE.md:625` is authoritative on behavior and says the figures "arrive **per row** from the
asynchronous directory call and fill their skeleton cells as they land"; `:496` names the state.
But `Screen/Read.cls:208` answers **one complete envelope**: the admin `LIST` branch (`:324-337`)
is synchronous, `rowGet` is issued per surviving row *inside* the read (`DetailRow`, `:759`), and
there is no incremental, partial-row or second-pass shape anywhere in `Read.cls`. `source.type`
admits only `LIST,GET,UPCOMING,HISTORY` (`Registry.cls:1368`), so a per-database `INFO` read is not
declarable; only `rowGet.type` admits `INFO` (`:1625`).

Measured on slot B: LIST **7.7 ms**; `INFO` **54-66 ms** per database; all 14 databases **0.852 s**
sequential. So a `rowGet` read costs about 0.9 s here, against NFR-1's 2 s budget.

- **(a) Recommended - one read, `rowGet.type = "INFO"`, and AC2's granularity narrows.** No new
  grammar. Free-space cells render as skeletons until the read lands, then fill together. The
  no-reflow guarantee survives untouched and is already true (Q4). Requires an `epics.md` AC
  amendment, an `EXPERIENCE.md` amendment at `:496` and `:625`, and the parenthetical in
  `ARCHITECTURE-SPINE.md` AD-26 ("the UX already renders as skeleton cells filling in as they
  land") corrected at its origin in the same commit (Rule 20). That is a Rule 5 *ask-first*
  narrowing, which is why it is a question and not a decision.
- **(b) New grammar - a per-row read the client issues N times.** Admit `INFO` as a `source.type`
  for a single-object source taking `dir` as its one criterion, on a third unlisted descriptor,
  and have the Free-space page call it once per row. Cost: `Registry.cls` `READSOURCETYPES`,
  `ui/tools/screen-mirror.mjs`, `Test/ReadSourceCorpus.cls`, a new per-cell loading state in
  `data-table.ts`, a new `data-table` row in `DESIGN.md` (which specifies no per-cell skeleton -
  its `skeleton` entry is whole-row and its async-free-space skeleton is on the `meter`), and N
  concurrent requests each queueing its own one-worker `$System.WorkMgr` queue detached for ten
  days. It also breaks AD-36's "one read shared by screen and tool" for that view. Amends AD-36.
- **(c) Ship the General view now** and charter the Free-space view to a named later story.

### Q2 — One descriptor or two for the two views, and their gates differ

The grammar admits **one `read` and one `table` per descriptor**, with exactly one `name` column
(`Registry.cls:810`, `:1746`, `:1794`); `route` and `toolIdentifier` are unique (`:283`, `:204`);
there is no `views` key in the 27-key vocabulary (`:318`). `list (two views)` is in the closed
archetype vocabulary (`Archetype.cls:65`) and **no screen declares it**; the moment one does with
`built: true` it becomes a required key of `ARCHETYPE_PAGES` (`screen-outlet.ts:51-53`,
`screen-mirror.mjs:1812-1813`) and `ng build` fails until a page is registered.

The two views do **not** share a gate. `SysCRUD.ResourcesOR()` returns
`$LISTBUILD("%Admin_Manage","%Admin_Operate")` for `IsTypeGet()` or `TYPEINFO` and
`$LISTBUILD("%Admin_Manage")` for everything else, **`LIST` included**; the `AsyncResult` poll the
free-space call needs requires `%Admin_Operate` **alone**. A descriptor's gate requires *all* its
declared pairs (`Gate.cls:109-129`), so one descriptor covering both views must declare
Manage + Operate + `%DB_IRISSYS:READ` and will deny each view to a principal who could read it.

- **(a) Recommended - two descriptors, one listed.** `DatabaseList` at `os-management/databases`,
  `sideBarPosition` 4, archetype `list (two views)`, pairs `%Admin_Manage:USE` + `%DB_IRISSYS:READ`;
  `DatabaseFreeSpace` at `os-management/databases/free-space`, `sideBarPosition` 0, archetype
  `list`, pairs `%Admin_Manage:USE` + `%Admin_Operate:USE` + `%DB_IRISSYS:READ`. The command-bar
  View control switches route. Each view keeps its own read, table and derived read tool, which is
  what AD-36 wants. Both pair sets are already inside the os-management union (`Area.cls:102`), so
  no `Area.cls` edit. One `ARCHETYPE_PAGES` entry for `list (two views)` over `ListPage`'s binding,
  with `UpcomingPage` the registrant to copy. Caveat to weigh: the locator bar and `aria-current`
  then track two routes where `EXPERIENCE.md:382` describes one screen with a View menu.
- **(b) One descriptor, one route, a `DESCRIPTOR_PAGES` page holding the second column set** as a
  screen-local constant and passing `DataTable` a spread declaration; nothing in production forbids
  it (`screen-fixture.test.mjs:35-54` bans hand-built declarations only in specs). Fewer files and
  one route, but the strict single gate above, and one read means the General view pays the
  free-space cost.
- **(c) A new `views` declaration key** - refused here as a grammar extension this stage may not
  invent.

### Q3 — Database details' three sections: two are collections, and one has no surface at all

AC3 names properties, volume files and the background tasks running against that database. One
descriptor declares one read. `parts` admits at most three, **each answering one object**, merged
into the read's **one row** (`Registry.cls:1537-1616`, `Read.cls:509-550`) - a volume list and a
task list are collections, so `parts` cannot carry them (an array part is coerced to a single
`Description = "Total"` row, `Read.cls:536`).

Volume files are reachable: `Database.SysCRUD` `TYPEVOLUMELIST` (type 10), synchronous, `dir` its
only parameter, answering a bare array of
`VolumeNumber, VolumeDirectory, File, Size, VolumeDirectoryTotalSize, DiskFree`; an ordinary
single-file database returns **one** row, not zero. `AdminPort` needs `VOLUMELIST` appended to
`Parameter TYPESUFFIXES` (`AdminPort.cls:101`) - not `BARETYPES`, because the vendor publishes it as
the `TYPE`-prefixed `TYPEVOLUMELIST` and only the `TYPESUFFIXES` branch of `EndpointType`
(`:689-696`) resolves that. Its gate is **`%Admin_Manage` only**, stricter than `GET`'s.

Background tasks have **no admin-API surface**. The only callable answer is the `%SYS` class query
`%SYS.BackgroundTask:RunningInDatabase(dir)` (`ID`, `StartTime`, `DisplayType`), which is what the
classic page reads (`%CSP.UI.Portal.DatabaseDetails:DrawTasks` ->
`%CSP.UI.Portal.Background.Utils:GetTaskList`). Ruled out with evidence: no `%Api.Admin.*` class
references `%SYS.BackgroundTask`; `Database.Actions` is write-only; `%Api.Admin.Util.AsyncTask`
carries no directory and its `TaskName` is built from `%CSP.Request.URL`, which excludes the query
string and so loses `dir`; the whole v2 `UrlMap` has 26 database routes and none for tasks. AD-36's
sources are `admin`, `mgmnt`, `state`, and AD-27 confines `%Api.Admin.*` to `AdminPort`; a `%SYS`
class query is none of the three.

- **(a) Recommended - narrow AC3 to properties and volume files, charter background tasks.**
  Database details is one `detail` descriptor whose read is a parent-scoped single-object `GET` on
  `Database.SysCRUD` keyed by `dir`, and volume files ship as a second, parent-scoped `list`
  descriptor under it. Background tasks are ledgered with a named owner and the port decision
  attached. Requires an `epics.md` and `EXPERIENCE.md:98` AC amendment - *ask-first*.
- **(b) Properties only**, both collections chartered. Smallest; leaves two thirds of an AC open.
- **(c) A new source kind or port for supported `%SYS` class queries** - the shape `LogSourcePort`
  has for files. Real architecture work: a new AD, its own gate under AD-29, and it is what Stage
  2's database actions will need anyway.

### Q4 — The no-reflow mechanism already exists; confirm it is the answer

The shared table is **not** an HTML `<table>` and has no `table-layout`. Rows are CSS grid with the
track list bound per row (`data-table.ts:191`, `:232`), and the tracks are **derived from the
declared column kinds and never from content**: `data-table.ts:611-617` maps `number`/`status` to
`minmax(0, 1fr)` and everything else to `minmax(0, 2fr)`. Row height is the `--ocu-row-height`
token and cells clip (`_components.scss:2217-2246`). So a cell whose value arrives on a later tick
**cannot** reflow the table, with no new layout work.

- **Recommended:** state that as the mechanism and pin it with a browser-level AC - jsdom computes
  no layout, so this belongs in `ui/browser/`. This spec would add
  `ui/browser/databases.browser-spec.mjs` asserting that the header column boundaries and the row
  height are identical before and after the free-space cells carry values
  (`getBoundingClientRect()` sampled twice), modeled on `locks.browser-spec.mjs`, plus the row in
  `screen-height.browser-spec.mjs:41-49`.
- Confirm also whether this story backfills that geometry roster for Locks and System usage, which
  were never added when they shipped.

### Q5 — The View control has no published copy, and this story's strings row is unauthored

`command-bar.ts:98-102` records that the View slot was left **deliberately unrendered** because
`EXPERIENCE.md:382` and `DESIGN.md:1039` name a View menu but publish no label for it or for its
options. `ui/tools/strings.test.mjs` demands exact set equality against EXPERIENCE.md's Fixed
strings table in both directions (`:340-344`, `:364-379`), and that table ends at Story 6.10's row
(`EXPERIENCE.md:364`), so nothing can be built until the lead applies a row. Values must be unique,
and `"General"`, `"Status"` and `"Directory"` already exist (Process details `:362`, Task history
`:359`, Locks `:364`) and must be reused rather than repeated. The current key count is 438 against
a band assertion of at most 450 (`strings.test.mjs:335-336`), so about 27 keys of headroom.

Proposed row, for the lead to apply verbatim or amend:

> | "Databases" · "View" · "Free space" · "Size" · "Maximum" · "Mounted" · "No databases on this instance." · "Database details" · "This database no longer exists." | Databases list and Database details (Story 6.11): the side-bar entry and screen title, the fourth OS management entry (`:164`, `:97`); the command-bar View control's accessible name, whose two options are "General" (`:362`) and "Free space", the second also the free-space column header; its column headers beyond the Locks row's "Directory" (`:364`) and the Task history row's "Status" (`:359`), where "Status" carries the vendor's own mount word and "Mounted" is the Free-space view's own boolean column; its empty state, which names the instance because the read is instance-scoped and whose second line is the Web applications row's (`:315`); and the details screen's title, reached from the Databases name cell and never a side-bar entry, with its "no longer exists" empty state in the Task details and Process details pattern (`:361`, `:362`) |

Q3's answer decides whether volume-file and background-task labels join that row.

### Q6 — Which "properties", and which classic page

`SysCRUD` `GET` answers **10 configurable** fields - `MaxSize, ExpansionSize, NewVolumeThreshold,
NewVolumeDirectory, ResourceName, NewGlobalIsKeep, NewGlobalCollation, ClusterMountMode, ReadOnly,
GlobalJournalState` - and `Directory` is **not** in the body, only in the request. But the classic
details page's own properties panel shows **metrics**: `GetDetailPane` builds an
`%CSP.Util.HTMLDashboardPane` with `MetricClass = "SYS.Metrics"`,
`MetricMethod = "GetDatabaseMetrics"` under "General Information" and "Database Size" - the same
source `TYPEINFO` uses. `GET`'s ten fields are what `%CSP.UI.Portal.Database` ("Database
Properties", `%Admin_Manage`) *edits*.

- **Recommended:** properties = `GET`'s ten fields, plus the `TYPEINFO` metrics as `parts`, so the
  screen shows what the classic page shows and the meter component (Story 6.9) has values to draw.
  Note `parts` fails the whole read on any part fault (`Read.cls:522-528`), so an `INFO` timeout
  would fail Database details' read rather than degrade it - which is AD-26's contract, but worth
  the lead's eye on a screen that auto-refreshes every 5 s.
- **The classic key is `%CSP.UI.Portal.OpDatabases`, not `%CSP.UI.Portal.Databases`.** `OpDatabases`
  is `%Admin_Operate`, `/csp/sys/op/`, and carries the literal General/Free-space toggle this story
  rebuilds (`radioSet id="freespaceSwitch" displayList="General view,Free space view"`, reading
  `Config.Databases:LocalDatabaseList` and `SYS.Database:FreeSpace`); `Databases` is
  `%Admin_Manage`, `/csp/sys/mgr/`, the Configuration list - a different screen. Details is
  `%CSP.UI.Portal.DatabaseDetails` (`%Admin_Operate`), which exists and auto-refreshes itself. Both
  spellings survive `%SYS.Portal.Resources.NormalizePage` unchanged. Confirm, because AD-44 unions
  the custom resource assigned to the classic key into the gate, so the choice changes it.

## Intent

**Problem:** The OS management area's fourth and fifth screens do not exist, so the side bar stops
at System usage and the contest's "disks" has no surface. FR-58 asks for the instance's local
databases in a General and a Free-space view, and a Database details screen under auto-refresh -
and the free-space figures come from the one Release 1 endpoint path that answers asynchronously
(AD-26), so this story is also where that path first reaches a screen.

**Approach:** Two new descriptors for the list (Q2) plus one for Database details, each declaring a
read that `AdminPort` serves from `%Api.Admin.Endpoints.Database.SysCRUD`; the async free-space
call is polled inside the port, so the slice writes no polling logic. The exact descriptor shape
and the free-space arrival mechanism wait on Q1, Q2 and Q3.

## Boundaries & Constraints

**Always:** `AdminPort` is the only code naming an `%Api.Admin.*` class (AD-27), and it alone polls
the async task with a bounded wait that fails `PORT.TIMEOUT` and never answers partially (AD-26).
Every read is descriptor-declared and shared with its derived tool (AD-36), bounded by the max-rows
cap. Scope is `instance`; the id is the database directory, one segment through the shared encoder
(AD-13). Pair sets are established by reading the backing class *and* running the read as a real
least-privileged principal on a throwaway, never from `ResourcesOR()` alone (AD-29). Database
details is on AD-43's roster of seven and joins it by declaring `refreshes` **and** appearing in
`EXPERIENCE.md`'s Auto-refresh controls row. Every touch of a file Epic 4 shares
(`Screen/Read.cls`, `Registry.cls`, `Descriptor/Base.cls`, `AdminPort.cls`, `Installer.cls`,
`Smoke.cls`, `Router.cls`, `Error.cls`, `Test/Descriptor.cls`, `screen-mirror.mjs`,
`screen-store.ts`, `strings.ts`) is **additive only**.

**Never:** no `rowTarget` - the name cell reaches details through the paired-surface chain, both
engines refuse a `rowTarget` on any archetype other than exactly `list` (`Registry.cls:2318`) and
on any screen that already pairs its own surface (`:2435`), and **DW-1078** is referenced, not
extended. No classic-link exemption: `list (two views)` is link-out class `list` (`Archetype.cls:65`).
No hand-written polling in the slice. No row or primary action - the database write actions are
Stage 2. No new top-level source folder, so `Install/Roster.cls` is untouched. No storage default
sections, no `%` or `_` in names, no `Screen/Tool/**`, `Kernel/**`, `ProviderPort.cls`,
`check-objectscript.py`, `app.ts`, `package.json`, `angular.json` or `shell/panel/**` edits.

## I/O & Edge-Case Matrix

Rows marked *(Q1)* take their final shape from that answer; everything else is settled by the
evidence in `## Code Map`.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| General view loads | `Database.SysCRUD` `LIST`, no query params | 14 rows carrying `Directory`, `Size`, `MaxSize` (`"Unlimited"`), `Status` (`"Mounted/RW"`) | none expected; 7.7 ms |
| Free-space figures pending *(Q1)* | the async task is `Queued` | `Result` is `{}` and HTTP is 200; the port keeps polling at `POLLINTERVAL` 0.05 s; free-space cells render as skeletons | none - pending is not a fault |
| Free-space figures complete *(Q1)* | the task reaches `Finished` | the port answers 200 with the task's `Result`; `AvailableSpace`, `DiskFree`, `Mounted` reach their cells | none expected; 54-66 ms per database |
| Bounded wait exceeded | the task is still `Queued`/`Running` at `ASYNCTIMEOUT` 30 s | the read is refused, never partial; the task row is deliberately left in place | HTTP 503, slug `unavailable`, code `PORT.TIMEOUT`, reason "The instance did not finish that operation in time" |
| The async job fails | `State` reaches `Failed` with a `FailureReason` | the read is refused | HTTP 500 through `Fault.Outcome`, vendor text to the log only |
| A database is read-only | `/usr/irissys/mgr/irislib/` | `ReadOnlyReason` non-empty and `EndFree` the **empty string** where a mounted-RW database gives a number | the cell reads its `emptyKey` word, never "(none)" if empty means something else |
| Details opened on a live database | route id = an existing directory | `GET`'s ten fields, plus `parts` per Q6, in one row; auto-refresh silent, sort/filter/selection/scroll preserved | none expected; 0.40 ms |
| Details opened on a stale id | route id = a directory the instance no longer has | `ValidateSemantics` `%OpenId` fails and sets 404 **before** the async hand-off | the port maps it to `PORT.NOTFOUND`, which draws the generic "request refused" with a Retry that cannot clear it - the same path Secrets accepted as DW-1021 |
| `dir` omitted | a read issued with no directory criterion | refused at `ValidateQueryParams` | HTTP 400, `PORT.VALIDATION` |
| Least-privileged principal | `%Admin_Manage` only, on a throwaway | the General view reads; the free-space poll is expected to fail, since `AsyncResult` requires `%Admin_Operate` alone | the gate names the first unheld pair; whatever the instance still refuses is appended to the declared set (AD-29) |
| Table geometry while cells fill | rows rendered, free-space cells empty then valued | header column boundaries and row height unchanged; the grid tracks are kind-derived and content-independent | a geometry claim belongs in `ui/browser/`, not jsdom |

## Code Map

Probe evidence, so the next pass re-reads nothing. Every line anchor was read; `(inference)` marks
what was derived rather than observed. All IRIS probes ran on `ocupilot-slot-b` as `_SYSTEM`, so
none of them is evidence about least privilege.

### Vendor surface

`%Api.Admin.*` is `[Hidden]` and lives in IRISLIB, so it is absent from the `irissys/` export and
was read from the instance with `%Compiler.UDL.TextServices.GetTextAsString`.

- `%Api.Admin.Endpoints.Database.SysCRUD` - `TYPEVOLUMELIST = 10`, `TYPEINFO = 11`;
  `ShouldRunAsync()` is `Return ..Type = ..#TYPEINFO`, so **exactly one type is async**;
  `ValidateQueryParams` requires `dir` for every type but POST and LIST; `RunInfo` calls
  `SYS.Metrics.GetDatabaseMetrics(..Directory, ...)` and
  `SYS.Database.FileCompact(..Directory, 0, .EndFree)`. **The async unit is one task per
  database** - there is no all-databases INFO.
- Routes, `%Api.Admin.Dispatch.v2` `UrlMap`: `GET /database-dirs` LIST, `GET /database-dir` GET,
  `POST /database-dir/info` TYPEINFO, `GET /database-dir/volumes` TYPEVOLUMELIST.
- **LIST** (14 rows here), one row verbatim:
  `{"Directory":"/durable/iris/mgr/HSCUSTOM/","MaxSize":"Unlimited","Size":41,"Status":"Mounted/RW","Resource":"%DB_HSCUSTOM","Encrypted":false,"Mirrored":false,"SFN":7,"EncryptionKeyID":"","EncryptionVersion":"0"}`.
  **No free-space column and no `Mounted` boolean** - mount state is inside `Status`
  (`Mounted/RW`, `Mounted/R`); `MaxSize` is the display string `"Unlimited"`.
- **INFO** (complete):
  `{"Size":41,"ExpansionSize":0,"MaxSize":0,"ReadOnlyReason":"","EncryptionKeyID":"","BlockSize":8192,"Blocks":5248,"AvailableSpace":1.7,"DiskFree":"1.113TB","EndFree":0,"LastExpansionTime":"2026-09-16 14:30:51","MirrorSetName":"","MirrorDBName":"","SFN":7,"Mirrored":false,"Encrypted":false,"Full":false,"Mounted":true,"MirrorFailoverDB":false}`.
  `Directory` is absent - it is the request's own `dir`. `MaxSize` is numeric `0` for unlimited,
  disagreeing with LIST's `"Unlimited"`.
- **GET** (complete, 10 fields, identical field set and order on two databases):
  `{"MaxSize":0,"ExpansionSize":0,"NewVolumeThreshold":0,"NewVolumeDirectory":"/durable/iris/mgr/HSCUSTOM/","ResourceName":"%DB_HSCUSTOM","NewGlobalIsKeep":false,"NewGlobalCollation":5,"ClusterMountMode":false,"ReadOnly":false,"GlobalJournalState":true}`.
- **VOLUMELIST** - a bare array:
  `[{"VolumeNumber":0,"VolumeDirectory":"/durable/iris/mgr/HSCUSTOM/","File":"IRIS.DAT","Size":41,"VolumeDirectoryTotalSize":41,"DiskFree":1167037}]`.
- **The async handshake, observed.** `%Api.Admin.Util.AsyncTask` queues through the Work Queue
  Manager (`Set queue = $System.WorkMgr.%New(, 1)`, `queue.Queue("..MgrEntrypoint", ..GUID)`,
  `queue.Detach(.token, 86400 * 10)`) and answers **HTTP 202** with
  `Location: /api/admin/v1/async-result?id=<GUID>` - hard-coded `/v1/` even on a v2 request, which
  is benign because the port matches only the `async-result?id=` substring. The poll endpoint sets
  **no HTTP status at all**, so pending and finished are both **200**, distinguished only by
  `State`. Caught in process at a 5 ms poll interval:
  - pending: `{"State":"Queued","TaskName":"POST /v2/ocupilot/database-dir/info","Console":[],"FailureReason":"","Result":{},"TimeQueued":"...","TimeStarted":"","TimeFinished":""}`
  - complete: `{"State":"Finished", ... "Result":{ the INFO body above }}`

  Over plain HTTP the pending state was **not** observable - the worker finished inside the gap
  between the POST and the first poll. **No partial answer is possible**: `Result` is written once,
  by `SaveResult` after `Run()` returns, and a metric failure ends in `State: "Failed"` with
  `Result: {}`, never a half-filled object.
- **Timing**, `$ZHOROLOG` around `AdminPort.Invoke`, five iterations each unless noted: LIST
  **7.7 ms**; INFO **54-66 ms** per database and **0.852 s** for all 14 sequential; GET
  **0.40 ms**; `SYS.Database:VolumeFiles` **0.17 ms** (1 row);
  `%SYS.BackgroundTask:RunningInDatabase` **0.10 ms** (0 rows). `POLLINTERVAL` is 0.05 s and the
  work finishes in a few ms, so essentially the whole per-INFO cost is one `Hang 0.05` (inference).
- **Gates.** `SysCRUD.ResourcesOR()`: `IsTypeGet() || TYPEINFO` -> `%Admin_Manage` **or**
  `%Admin_Operate`; everything else, LIST and VOLUMELIST included -> `%Admin_Manage` only.
  `%Api.Admin.Endpoints.AsyncResult.ResourcesOR()` -> `%Admin_Operate` **alone**, and its
  `ValidateSemantics` 404s a task whose `Username` is not the caller's. `SYS.Database.cls:86`
  declares `Parameter RESOURCEREQUIRED = "%Admin_Secure"` (consumed by
  `$$$CheckForClassResource*`, `irislib/%sySecurity.inc:445-452`) and is the backing class of both
  GET and VOLUMELIST - **whether it bites is unreadable**, because every method body in
  `SYS.Database.cls` and all of `SYS.Metrics.cls` is stripped in this build. Only a
  least-privileged probe settles it, and until it runs no `QUERYPAIRS` entry should be added.
- **Named faults through `AdminPort`, probed:** an unknown `dir` gives `404`
  `{"error":"not_found","reason":"That item is no longer present on this instance","code":"PORT.NOTFOUND"}`;
  a missing `dir` gives `400` `PORT.VALIDATION`. Both are set in `ValidateSemantics` /
  `ValidateQueryParams`, i.e. **before** the async hand-off, so they are real statuses and not
  swallowed by the `IsRunningAsync` guard.
- **Background tasks:** `%SYS.BackgroundTask:RunningInDatabase(dir)` unions
  `SYS_Database.BackgroundFileCompact` and `SYS_Database.BackgroundDefragment` on
  `Database = :dir AND HasEnded = 0`, three columns `ID`, `StartTime`, `DisplayType` (observed
  values `Compact Database Space`, `Defragment Database`). **0 rows on this instance.** Integrity
  check is not covered - `SYS.BackgroundIntegrity` has no `Database` property. No progress columns;
  `%SYS.BackgroundTask:DatabaseList` carries progress but is unfiltered.
- **Classic keys:** `%CSP.UI.Portal.OpDatabases` (`%Admin_Operate`, `/csp/sys/op/`, the
  General/Free-space `radioSet`, `Config.Databases:LocalDatabaseList` and `SYS.Database:FreeSpace`,
  its name cell linking to `%CSP.UI.Portal.DatabaseDetails`); `%CSP.UI.Portal.DatabaseDetails`
  (`%Admin_Operate`, holding `taskBlock` / `detailBlock` / `idVolumeFile` - the AC's three
  sections - and calling `DrawAutoRefresh`). `DrawTasks` draws nothing when the list is empty, and
  `idVolumeFile` stays hidden unless `MultiVolume`, so classic shows no volumes where the API
  returns a row.

### Server-side project code

- `src/OcuPilot/Screen/Descriptor/LockList.cls:43-90` - the newest full declaration and the model
  for this story's list. `ProcessDetails.cls` - the parent-scoped `detail` with auto-refresh and
  the model for Database details. `SystemUsage.cls:66-71` - the only `parts` source.
- `src/OcuPilot/Screen/Registry.cls:318` the 27 declaration keys; `:1746`/`:1794` one `table` and
  exactly one `name` column; `:1368` `READSOURCETYPES`; `:1625` `ROWGETTYPES`; `:1537-1616`
  `parts`; `:2249-2279` `parentScope`; `:2318-2321` `rowTarget` refused unless `archetype` is
  exactly `list`; `:2381`/`:2435` a `rowTarget` refused on a screen that already pairs its own
  surface; `:602-623` area coverage; `:2089-2101` `ScreensForArea` ordering by `sideBarPosition`
  then **class name**; `:1798-1807` a composite id's parts must be `read.fields` entries.
  Descriptors are discovered by SQL over `%Dictionary.CompiledClass`, so a new `.cls` needs no
  registry edit.
- `src/OcuPilot/Screen/Archetype.cls:65` - `{"key":"list (two views)","linkOut":"list"}`, so it may
  declare a `classicPage` but never an exemption; `Test/ClassicLinkCorpus.cls:37,53` already
  carries both cases for that key.
- `src/OcuPilot/Screen/Read.cls:208` `Execute`; `:324-337` the admin `LIST` branch; `:509-550`
  `PartsObject`, where any non-2xx including 404 fails the whole read; `:759` `DetailRow`; `:74`
  `DEFAULTMAXROWS`; `:343` truncation.
- `src/OcuPilot/Screen/Area.cls:102` - the os-management union is `%Admin_Operate:USE`,
  `%Admin_Manage:USE`, `%DB_IRISSYS:READ`, so **no `Area.cls` edit** for either pair set above.
  Its own doc comment's false-denial count (`:57-58`, "0 of 1 ... 2 of 3 once 6.8 and 6.10 land")
  is already stale and this story makes it staler - correct it at its origin, not by appending.
- `src/OcuPilot/Screen/Gate.cls:109-129` - all declared pairs required; `pFailedPair` names the
  **first** miss in declared order, so pairs are appended, never prepended.
- `src/OcuPilot/Port/AdminPort.cls:325` `Invoke`; `:101` `TYPESUFFIXES` (no `VOLUMELIST`); `:130`
  `QUERYPAIRS` (nothing for any database query); `:141` `BARETYPES`; `:357-362` the 202 +
  `Location` async entry; `:761` `IsRunningAsync = 0`; `:851-886` `AwaitTask`; `:163`
  `POLLINTERVAL = 0.05`; `:160` `ASYNCTIMEOUT = 30`; `:879` the timeout refusal with
  `src/OcuPilot/Api/Error.cls:185` `PORTTIMEOUT = "PORT.TIMEOUT"`; `:689-696` `EndpointType`.
  `MonitorPort` does not exist; the ports are `AdminPort`, `MgmntPort`, `LogSourcePort`,
  `ProviderPort`.
- `src/OcuPilot/Api/Router.cls:81` - one generic `/screens/:screen/read` route, so a new screen
  adds none. `Install/Installer.cls` and `Install/Roster.cls:95` need no per-screen edit.
- `src/OcuPilot/Screen/Tool/Registry.cls:104-120` - the derived read tool arrives for free, one per
  descriptor whose `Read()` is an object; nothing under `Screen/Tool/**` needs editing.

### Roster tripwires, with their current literals

- **`src/OcuPilot/Test/Navigation.cls` is pinned by literal index and count and has gone stale
  twice.** `:329` `Do $$$AssertEquals(tOsMgmt.screens.%Size(), 4, ...)`; `:330-337` the four
  index/route/labelKey assertions - 0 `os-management/processes/details`,
  1 `os-management/processes`, 2 `os-management/locks`, 3 `os-management/system-usage`. Because
  `ScreensForArea` collates by `(sideBarPosition, class name)`, adding `DatabaseDetails` (0),
  `DatabaseFreeSpace` (0) and `DatabaseList` (4) makes the roster **7** and rewrites **every**
  index: 0 `databases/details`, 1 `databases/free-space`, 2 `processes/details`, 3 `processes`,
  4 `locks`, 5 `system-usage`, 6 `databases` (inference, from `$Order` over the class-name
  subscript; contingent on the class names Q2 and Q3 settle). Duplicate positions within an area
  are legal - `security` already ships four at 0.
- `src/OcuPilot/Install/Smoke.cls:595` the loop bound `For tI = 1:1:23`, `:596` the
  comma-separated name list, `:600` the `$Select` arms, `:727-787` `CheckProcessDetails` as the
  model for a detail check; `src/OcuPilot/Test/Smoke.cls:593` asserts arm count == name count ==
  loop bound, and `:564`, `:572-575`, `:670` carry the path count and the tool-parameter list.
- `src/OcuPilot/Test/ReadTool.cls:93` tool count `30`; `:94` the sorted tool-name string; `:337`
  `tWithCriteria` `8`; `:604` `tWithBanner` `1`; `:263` the admin-`%DB_IRISSYS:READ` class list.
- `src/OcuPilot/Test/Wire.cls:675` and `src/OcuPilot/Test/WireSecurityRead.cls:510,517,520` - four
  verbatim JSON literals enumerating every os-management screen in roster order with its
  `failedPair`; `WireSecurityRead.cls:506`/`:599` are the per-screen least-privileged models.
- `src/OcuPilot/Test/Descriptor.cls:1273-1305` the `LockList` model; `:763` archetype count `16`
  and `:1054` `EntityType.Count()` `28` both stay, since `database` is already in
  `Kernel/EntityType.cls:28`. `Test/ScreenRead.cls:187-199` is self-discovering for an admin `LIST`
  screen and skips a `GET`-source one.
- Corpora are shape-driven and none needs a new screen unless Q1(b) or Q2(c) widens a rule, in
  which case `Test/ReadSourceCorpus.cls` is where the refusal sentence is pinned and
  `ui/tools/screen-mirror.test.mjs` runs the same block.

### Client-side project code

- `ui/src/app/core/screens.generated.ts:22` the archetype key and `:43-51` `BuiltArchetypeKey`;
  regenerate with `node tools/screen-mirror.mjs` from `ui/`, and `prebuild` runs `--check`.
- `ui/src/app/shell/screen-outlet.ts:51-53` the `ARCHETYPE_PAGES` required-key type assertion,
  `:55-64` the map, `:81-87` `DESCRIPTOR_PAGES` (resolved first), `:115-125` the resolution order;
  `screen-outlet.spec.ts:317-353` pins both.
- `ui/src/app/shell/list-page.ts:68-190` `ListPage`;
  `ui/src/app/areas/tasks/upcoming.page.ts:85-110`, `:144-172`, `:219-224` - the registrant to
  copy for a control above the shared table, and `:39` the page-held `WeakMap<ScreenStore, ...>`
  pattern for state `ScreenStore.rememberView` (`screen-store.ts:305-312`) has no slot for.
- `ui/src/app/shell/command-bar.ts:98-102` the unrendered View slot and why; `:162-219` the sort
  menu to copy, with `SORT_TRIGGER_ID :33`, `SORT_MENU_ID :36` and `SORT_MENU_OVERLAY_ID :39`;
  `:230-239` and `:471-478` the auto-refresh chip.
- `ui/src/app/shell/data-table.ts:611-617` the kind-derived grid tracks - **the no-reflow
  mechanism** - with `:191`/`:232` where they bind, `:143-153` the whole-table skeleton (the only
  skeleton; there is no per-cell state), `:410` columns, `:422-455` the row-link chain and
  `encodeEntityId`; `ui/src/app/core/table-model.ts:71-105` `cellView`;
  `ui/src/styles/_components.scss:2217-2246` the fixed row height and clipped cells, `:85-120` the
  skeleton rows, `:3565-3578` the meter's own `ocu-meter-fill-skeleton`.
- `ui/src/app/shell/meter.ts:96-102` the seven signal inputs (`label, value, unit, percent, state,
  word, error`), `:110` `isTrack`, `:115-129` pending giving a skeleton fill and `'—'`,
  `:159-163` `fillPercent`; `ui/src/app/core/meter-state.ts:11,26,40`. Story 6.9's `METER_CONFIGS`
  (`system-usage.store.ts:59-72`) is screen-local, so Database details declares its own.
- `ui/src/app/core/refresh.ts:227-248` `bind`, which throws for a `refreshes` screen bound with a
  null read; `ui/src/app/shell/status-bar.ts:186-189` the stamp;
  `ui/src/app/core/detail-highlights.ts:33-61`. **Five** descriptors declare `refreshes` today -
  `ProcessDetails`, `ProcessList`, `SystemUsage`, `TaskDetails`, `TaskScheduleList` - so this
  story's two screens are exactly the two missing members of AD-43's seven. Four descriptors' own
  doc comments already say "six" (`ProcessList.cls:35`, `TaskDetails.cls:39`,
  `TaskScheduleList.cls:40`, `TaskRunList.cls:30`) where two say "seven"; correct them at their
  origin.
- `ui/src/app/areas/os-management/` holds only Story 6.8's and 6.9's six files - Story 6.10 added
  none, rendering Locks through `ListPage` on the descriptor alone. Convention:
  `<kebab>.page.ts` + `.page.spec.ts` + `<kebab>.store.ts`, with the pure store pinned by a new
  `ui/tools/<kebab>-store.test.mjs`.
- `ui/src/app/core/navigation.ts:241-254` `detailScreenFor` - it pairs by the **child's**
  `parentScope`, `built`, unlisted, id-keyed, `archetype === 'detail'` and `tab === null`, and
  never inspects the parent's archetype, so a `list (two views)` parent pairs with **no** grammar
  change (inference, read from the predicate); `:305-315` `parentCriteria`, which decodes twice;
  `ui/src/app/core/entity-id.ts:56,67`; `ui/src/app/app.routes.ts:62-80` `buildRoutes`, which
  emits the `/:id` route for every built screen, so no route edit.
- Tripwires: `ui/tools/navigation.test.mjs:125-163` the hand-ordered route roster and its prose
  message at `:162`; `ui/tools/strings.test.mjs:334-337` and `:358-392` (438 keys,
  `REQUIRED_ALONGSIDE_TABLE` fixed at 3) with `ui/src/app/core/strings.ts` appended in
  EXPERIENCE.md row order, each key preceded by its `/** EXPERIENCE.md:<line> */` citation; the two
  hand-maintained `LIVE_PAYLOAD` copies `ui/tools/navigation-wire.test.mjs:38-306` and
  `ui/src/app/shell/rail-wire.spec.ts:37`, neither of which goes red alone because each is an
  independent fixture, nothing compares them, and `os-management/locks` has no `screenVerdict`
  assertion at all; `ui/src/app/testing/screen-declaration.ts:13-45` with
  `ui/tools/screen-fixture.test.mjs:56-60`; `ui/browser/screen-height.browser-spec.mjs:41-49` the
  per-screen geometry roster, to which Locks and System usage were never added;
  `ui/browser/locks.browser-spec.mjs` the newest browser model; and
  `ui/browser/browser.config.mjs:60-84`, which **throws** unless `OCUPILOT_BROWSER_ORIGIN` and
  `OCUPILOT_BROWSER_CONTAINER` are both non-default. Browser specs register by filename alone
  (`package.json:17`), and `ui/tools/angular-json.test.mjs:247-280` enforces the naming both ways.
- Side-bar order is only the descriptors' `sideBarPosition`, sorted ascending
  (`navigation.ts:100-104`, `:132-134`). Current os-management: details 0, processes 1, locks 2,
  system-usage 3 - so **Databases takes 4** and Devices 5.

## Tasks & Acceptance

Held until Q1 through Q6 are answered: the Execution list's descriptor count, class names, read
shapes and the ACs' falsifiable observables all follow from those answers. Two items are settled
regardless of how the questions land, and are recorded here so they are not rediscovered:

**Execution (settled items only):**

- `src/OcuPilot/Test/Navigation.cls` -- rewrite the os-management count literal at `:329` and
  **every** per-index assertion at `:330-337` to the new `(sideBarPosition, class name)` collation
  order -- the roster is pinned by literal index and count and has now gone stale twice from an
  added os-management screen; this story adds two or three.
- `src/OcuPilot/Install/Smoke.cls` -- add the new lists to the name list at `:596`, add a
  `$Select` arm each at `:600`, raise the loop bound at `:595`, and add a `CheckDatabaseDetails`
  private method on the `CheckProcessDetails` model (`:727-787`) to `Run`'s call list at `:185`;
  then update `src/OcuPilot/Test/Smoke.cls:564`, `:572-575` and `:670` -- `Test/Smoke.cls:593`
  asserts arm count == name count == loop bound, so a partial edit is red.

**Acceptance Criteria:** deferred with the Execution list. The shape is fixed even where the
content is not: the async path needs one AC for the pending state, one for completion and one for
the bounded-wait `PORT.TIMEOUT` refusal; the no-reflow claim needs a browser-level AC because jsdom
computes no layout; and each AC names its pinning test with a `mutation:` line in `## Verification`
(Rule 19).

## Design Notes

Settled by the evidence above and not part of any question, so the next pass can take these as
given.

- **`rowTarget` is not this story's mechanism and must not be declared.** `EXPERIENCE.md:98`
  reaches Database details from the "Databases name cell", which is the paired-surface chain; both
  engines refuse a `rowTarget` on any archetype other than exactly `list` (`Registry.cls:2318`) and
  on any screen that already pairs its own surface (`:2435`). **DW-1078** (a `rowTarget` admitting
  a multi-part composite target) is therefore untouched - referenced, not re-filed, and not
  extended. No 13th refusal is needed.
- **`MaxSize` must be read from one source, not two.** LIST answers the display string
  `"Unlimited"`; INFO and GET answer numeric `0`. The Free-space view reuses LIST's string for that
  column - it is already in the same row - so the two views can never disagree on it, and since no
  column kind is a date it renders as `text`.
- **The General view's "mounted state" is inside `Status`.** LIST carries no `Mounted` boolean
  (`"Mounted/RW"`, `"Mounted/R"`); INFO does. So the General view shows `Status` and the Free-space
  view may add `Mounted` as its own column.
- **Scope is `instance`** - the database list is instance-wide, a row's marker is its directory,
  and the classic page it replaces is pinned to `%SYS`. The empty state therefore names the
  instance ("No databases on this instance.").
- **The id is the directory**, one segment through the shared encoder (AD-13), `id.kind` `single`
  or a one-part composite over `Directory`, which must then be a `read.fields` entry
  (`Registry.cls:1798-1807`).
- **Neither new screen needs an `Area.cls` edit** - both candidate pair sets are inside the
  os-management union.
- **AD-29's pair sets are a lower bound and must be established on a throwaway at implement time**,
  with four principals to separate: `%Admin_Manage`-only (does LIST succeed and the INFO *poll*
  fail?), `%Admin_Operate`-only (does INFO's round trip succeed while LIST 403s?), either without
  `%Admin_Secure:USE` (does `SYS.Database`/`SYS.Metrics` refuse, and with what status?), and
  whether `%DB_<db>:READ` matters for `FileCompact`'s `EndFree`. A denial test needs a purpose-built
  role, never `%Operator`.
- **Ledger.** Nothing is owned by this story - `ledger.sh slice
  6-11-databases-with-free-space-arriving-as-it-lands` reads empty. DW-1073, DW-1074, DW-1078 and
  DW-1079 are referenced where relevant and not re-filed. The two genuinely new gaps - the absent
  per-row read shape and the absent background-task surface - are the subject of Q1 and Q3 rather
  than ledger entries, since filing them would duplicate the intent-gap path Rule 15 gives a
  `decision-pending` item. **DW-1079** also matters operationally: `WalletCollectionList` answers
  zero rows on slot B, so `Test/ScreenRead` and `Test/Smoke` are already red there for reasons that
  are not this story's.
- **Consumes:** Story 2.1 (`AdminPort`'s sync and async paths, `AwaitTask`, `PORT.TIMEOUT`), Story
  2.3 (the declared read), Story 2.4 (`ListPage`, the shared table, the command bar), Story 1.14
  (the auto-refresh framework), Story 6.7 (a parent-scoped single-object `GET` with auto-refresh),
  Story 6.8 (`ProcessDetails`' own page and `detail-highlights`) and Story 6.9 (the meter component
  and the `parts` source). **Consumed-by:** Story 6.12 (Devices, the fifth os-management side-bar
  entry, inherits the `Test/Navigation.cls` roster this story rewrites) and Stage 2's database
  actions, which will need whatever Q3 decides about a non-admin-API source. This story introduces
  no shared service of its own beyond the additive `AdminPort` `TYPESUFFIXES` widening of Q3
  (Rule 1).

## Verification

Held with the Execution list: the commands are this project's standard gates, but a
`mutation:` line per AC cannot be written before the ACs exist.

**Commands (the gates this story will run, unchanged from the epic's other stories):**

- `cd ui && npm run build` -- expected: clean, including the six `prebuild` checkers, with
  `screen-mirror.mjs --check` green against the regenerated `screens.generated.ts`.
- `cd ui && npm test` -- expected: `node --test tools/*.test.mjs` then the Angular component runner
  green, `navigation.test.mjs` and `strings.test.mjs` included.
- `cd ui && npm run test:browser` -- expected: green, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777`
  and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci` both set, against this slot's own throwaway.
- `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh` -- expected: clean.
- One `iris_execute_tests` call per test class on `ocupilot-slot-b`, never two in one message, with
  the totals verified against `%UnitTest_Result` before any suite is reported green.
- `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` -- expected: a
  non-zero executed-check count with no failures.
