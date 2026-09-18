---
title: 'Databases, with free space arriving as it lands'
type: 'feature'
created: '2026-09-17'
status: 'ready-for-dev'
route: 'dispatch'
baseline_revision: 'c95d0c0ee1553bf84457f892d5fe991c24605749'
baseline_commit: 'c95d0c0ee1553bf84457f892d5fe991c24605749'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-6-context.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** OS management's side bar stops at System usage, so the contest's "disks" has no surface (FR-58, `epics.md` Story 6.11). The free-space figures come from the one Release 1 endpoint path that answers asynchronously (AD-26), so this story is also where that path first reaches a screen.

**Approach:** Four hand-written descriptors under OS management — the General view, the Free-space view, Database details and its volume files — each declaring one bounded read on `%Api.Admin.Endpoints.Database.SysCRUD` through `AdminPort`, which owns the async poll. The Free-space view paints its rows from the General view's fast `LIST` read with **skeleton cells** where the three figures go, then fills them together from its own read; the table cannot reflow because `DataTable`'s grid tracks come from the declared column kinds, never from content (`data-table.ts:611-617`).

## Boundaries & Constraints

**Always:**

- **`OcuPilot.Screen.Descriptor.DatabaseList`** — route `os-management/databases`, area `os-management`, `labelKey` `databaseListLabel`, `sideBarPosition` **4**, archetype `list (two views)`, `built` true, `refreshes` true with `refreshRates` `[5, 10, 30, 60]`, `privileges` `%Admin_Manage:USE` then `%DB_IRISSYS:READ`, `entityType` `database` (already the 22nd value of the closed vocabulary — **no `Kernel/` edit**), `scope` `instance`, `parentScope` `""`, `id` `{"kind": "single", "parts": []}`, `emptyStateKey` `databaseListEmpty`, `commandAliases` `["databases", "disks"]`, `toolIdentifier` `osmgmt.databases`, `classicPage` `%CSP.UI.Portal.OpDatabases` with no exemption.
  Read: `{"port": "admin", "endpoint": "Database", "type": "LIST"}`, `paging` `cap`, no criteria. `fields` exactly `Directory`, `Size`, `MaxSize`, `Status`, `Resource`. Table, five columns: `Directory`/`lockColumnDirectory`/`name` · `Size`/`databaseColumnSize`/`number` · `MaxSize`/`databaseColumnMaxSize`/`text` (LIST answers the display string `"Unlimited"`) · `Status`/`taskHistoryColumnStatus`/`text` (mount state lives inside it — `Mounted/RW`, `Mounted/R`; LIST carries no `Mounted` boolean) · `Resource`/`webAppColumnResource`/`identifier`.
- **`DatabaseFreeSpace`** — route `os-management/database-free-space` (**not** `databases/free-space`: `buildRoutes` emits a `/:id` route for every built screen (`app.routes.ts:62-80`), and a one-segment suffix would race it), `labelKey` `databaseFreeSpaceLabel`, `sideBarPosition` 0, archetype `list`, `parentScope` `""`, `refreshes` true, `privileges` `%Admin_Manage:USE`, `%Admin_Operate:USE`, `%DB_IRISSYS:READ` in that order, `id` `{"kind": "single", "parts": []}`, `emptyStateKey` `databaseListEmpty` (reused), `commandAliases` `["free space", "database free space"]`, `toolIdentifier` `osmgmt.databasefreespace`, same `classicPage`.
  Read: `LIST` plus `"rowGet": {"key": "Directory", "param": "dir", "type": "INFO", "fields": ["AvailableSpace", "DiskFree", "Mounted"], "derived": []}`. `fields` exactly `Directory`, `Size`, `AvailableSpace`, `DiskFree`, `Mounted`. Table, five columns: `Directory`/`name` · `Size`/`number` · `AvailableSpace`/`databaseColumnAvailable`/`number` · `DiskFree`/`databaseColumnDiskFree`/`text` (`"1.113TB"`) · `Mounted`/`databaseColumnMounted`/`text`.
  **`MaxSize` is not declared here.** LIST answers `"Unlimited"` and `INFO` answers numeric `0`; `rowGet.fields` is the mechanism that keeps the disagreeing member out of the row, and the maximum is the General view's column (`epics.md` AC1 asks for it once).
- **`DatabaseDetails`** — route `os-management/databases/details`, `labelKey` `databaseDetailsLabel`, `sideBarPosition` 0, archetype `detail`, `parentScope` `os-management/databases`, `refreshes` true, `privileges` `%Admin_Operate:USE` then `%DB_IRISSYS:READ` — **Operate alone, not Manage**: `SysCRUD.ResourcesOR()` answers Manage-or-Operate for `GET` and `TYPEINFO`, and the `AsyncResult` poll `TYPEINFO` needs requires Operate on its own, so adding Manage would deny the screen to a principal who can read it. `id` `{"kind": "composite", "parts": ["Directory"]}`, `emptyStateKey` `databaseDetailsGone`, `toolIdentifier` `osmgmt.databasedetails`, `classicPage` `%CSP.UI.Portal.DatabaseDetails`, `commandAliases` `["database details"]`.
  Read: `GET` with one criterion `{"param": "dir", "labelKey": "lockColumnDirectory", "kind": "text", "maxLength": 256}` filled from the route id, plus `"rowGet": {"key": "dir", "param": "dir", "type": "INFO", "fields": ["Size", "AvailableSpace", "DiskFree", "Mounted"], "derived": []}` — `TaskDetails.cls:80-92` is this exact shape. `fields` are `Directory` (seeded from the criterion by `Read.Execute:313`, since neither `GET` nor `INFO` answers it) plus `GET`'s ten — `MaxSize`, `ExpansionSize`, `NewVolumeThreshold`, `NewVolumeDirectory`, `ResourceName`, `NewGlobalIsKeep`, `NewGlobalCollation`, `ClusterMountMode`, `ReadOnly`, `GlobalJournalState` — plus the four above: fifteen. `Directory` is the one `name` column.
- **`DatabaseVolumeList`** — route `os-management/databases/volumes`, `labelKey` `databaseVolumeListLabel`, `sideBarPosition` 0, archetype `list`, `parentScope` `os-management/databases`, `refreshes` false, `privileges` `%Admin_Manage:USE` then `%DB_IRISSYS:READ` (`TYPEVOLUMELIST` takes `ResourcesOR()`'s Manage-only arm), `id` `{"kind": "composite", "parts": ["VolumeNumber"]}`, `emptyStateKey` `databaseVolumeListEmpty`, `toolIdentifier` `osmgmt.databasevolumes`, `classicPage` `%CSP.UI.Portal.DatabaseDetails`, `commandAliases` `["volume files"]`.
  Read: `{"type": "VOLUMELIST"}` with the same one route-id criterion. `fields` exactly `VolumeNumber`, `VolumeDirectory`, `File`, `Size`, `VolumeDirectoryTotalSize`, `DiskFree` — the six members the endpoint answers. Table: `File`/`databaseVolumeColumnFile`/`name` · `VolumeNumber`/`databaseVolumeColumnVolume`/`number` · `VolumeDirectory`/`lockColumnDirectory`/`identifier` · `Size`/`databaseColumnSize`/`number` · `VolumeDirectoryTotalSize`/`databaseVolumeColumnDirectoryTotal`/`number` · `DiskFree`/`databaseColumnDiskFree`/`number`.
- **`VOLUMELIST` joins the source vocabulary**, additively and on the `UPCOMING`/`HISTORY` precedent (Stories 6.5 and 6.6): `Registry.cls:1368` `READSOURCETYPES`, its own arm refusing `rowGet` and `forEach` worded like `HISTORY`'s (`:898-912`), the same in `screen-mirror.mjs`'s `readProblem`, the list branch of `Read.Execute` (`:325`), and `AdminPort.cls:101` `TYPESUFFIXES` — the vendor publishes it `TYPE`-prefixed, so `TYPESUFFIXES` and not `BARETYPES` is the branch of `EndpointType` (`:689-696`) that resolves it.
- **One new client mechanism, used twice: a page may issue another built screen's declared read** through the same `/screens/:screen/read` route (`Router.cls:81`). The Free-space page reads `osmgmt.databases` for its rows; the Database details page reads `osmgmt.databasevolumes` for its "Volume files" section. Each read stays descriptor-declared and shared with its own derived tool, so AD-36 holds.
- **Additive only** where Epic 4 shares a file: `Screen/Registry.cls`, `Screen/Read.cls`, `Port/AdminPort.cls`, `Install/Smoke.cls`, `Test/Descriptor.cls`, `ui/tools/screen-mirror.mjs`, `ui/src/app/core/strings.ts`. Add types, arms, keys, cases and test methods; change no existing sentence or declared key. `screens.generated.ts` is **regenerated** (`node tools/screen-mirror.mjs` from `ui/`), never hand-merged.

**Never:**

- **No background-tasks section.** `%SYS.BackgroundTask:RunningInDatabase` is a `Final Internal` class query no `%Api.Admin.*` class references; the section is the owner's call as **DW-1080** (`decision-pending`, `owner=burndown`) and `epics.md` AC3 is already amended. Add no source kind, no port and no ledger entry for it.
- **No `parts` on Database details.** `PartsProblem` refuses `parts` alongside `read.criteria` (`Registry.cls:1555-1558`) and every field of a parts read must be `<as>.<member>` (`:1607-1618`), which leaves the screen no field to key its id from. `rowGet.type = "INFO"` is Story 6.7's shipped grammar, issues the same two request types, and needs no amendment.
- **No `rowTarget`.** The name cell reaches Database details through the paired-surface chain; both engines refuse a `rowTarget` on a screen that already pairs its own surface (`Registry.cls:2435`). **DW-1078** is referenced, not extended.
- No hand-written polling in the slice, no partial answer: `AdminPort.AwaitTask` (`:851-886`) is the only poller, bounded by `ASYNCTIMEOUT` 30 s at `POLLINTERVAL` 0.05 s. No row or primary action — the database writes are Stage 2. No `Area.cls` pair edit (all four sets are inside the os-management union, `:102`). No planning-artifact edit, no `Kernel/**`, `Port/ProviderPort.cls`, `Screen/Tool/**`, `check-objectscript.py`, `app.ts`, `ui/src/app/shell/panel/**`, `ui/package.json`, `angular.json` or `README.md`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| General view loads | `LIST`, caller holds both pairs | 14 rows, five columns; `Directory` linked to details; truncation reported at the cap | none expected; 7.7 ms |
| Free-space figures pending | the General read has answered, the free-space read has not | every row on screen with `Directory` and `Size` filled; `Available`, `Disk free` and `Mounted` drawn as skeleton cells | pending is not a fault |
| Free-space figures land | the read resolves | the three columns carry values in one tick; no skeleton remains; header boundaries and row height unchanged | none expected; 0.852 s for 14 databases against NFR-1's 2 s |
| Bounded wait exceeded | the async task is still `Queued`/`Running` at 30 s | the read is refused whole, never partial; the vendor task row is left in place | HTTP 503, slug `unavailable`, code `PORT.TIMEOUT` |
| The async job fails | `State` reaches `Failed` | the read is refused | HTTP 500 through `Fault.Outcome`; vendor text to the log only |
| Details on a live database | route id is an existing directory | fifteen fields in one row, the `Available` value meter drawn, auto-refresh silent with sort, filter, selection and scroll preserved | none expected; 0.40 ms + one `INFO` |
| Details' `INFO` faults mid-refresh | the `rowGet` answers non-2xx other than 404 | the last values stay on screen and the refresh strip appears | never a blanked screen on a 5 s refresh |
| Details on a stale id | the instance no longer has that directory | `ValidateSemantics` 404s before the async hand-off; the row is dropped and the screen reads "This database no longer exists." | `PORT.NOTFOUND`; the generic refusal path Secrets accepted as DW-1021 |
| Volume files | a single-file database | one row, `File` `IRIS.DAT`, `VolumeNumber` 0 | a database with none reads "No volume files for this database." |
| `%Admin_Manage` only | a real least-privileged principal on the throwaway | the General view and the volume list read; the Free-space view and Database details are denied naming the first pair not held | the gate names the pair; never a 500, never an empty state |

</intent-contract>

## Code Map

Vendor (read from the instance — `%Api.Admin.*` is `[Hidden]` and absent from `irissys/`):

- `%Api.Admin.Endpoints.Database.SysCRUD` — `TYPEVOLUMELIST = 10`, `TYPEINFO = 11`; `ShouldRunAsync()` is `Return ..Type = ..#TYPEINFO`, so exactly one type is async and the unit is **one task per database**. `ValidateQueryParams` requires `dir` for every type but POST and LIST. `ResourcesOR()`: Manage-or-Operate for `IsTypeGet()` or `TYPEINFO`, Manage alone for everything else including `LIST` and `TYPEVOLUMELIST`. `%Api.Admin.Endpoints.AsyncResult.ResourcesOR()` answers `%Admin_Operate` alone and its `ValidateSemantics` 404s a task belonging to another user.
- Answers, verbatim members. `LIST`: `Directory, MaxSize, Size, Status, Resource, Encrypted, Mirrored, SFN, EncryptionKeyID, EncryptionVersion`. `INFO`: `Size, ExpansionSize, MaxSize, ReadOnlyReason, EncryptionKeyID, BlockSize, Blocks, AvailableSpace, DiskFree, EndFree, LastExpansionTime, MirrorSetName, MirrorDBName, SFN, Mirrored, Encrypted, Full, Mounted, MirrorFailoverDB` (no `Directory`). `GET`: the ten in Boundaries, identical set and order on two databases. `VOLUMELIST`: a bare array of `VolumeNumber, VolumeDirectory, File, Size, VolumeDirectoryTotalSize, DiskFree`, one row for an ordinary single-file database.
- The async handshake: `%Api.Admin.Util.AsyncTask` answers **202** with `Location: /api/admin/v1/async-result?id=<GUID>` (hard-coded `/v1/`, benign — the port matches the `async-result?id=` substring); the poll sets **no HTTP status**, so pending and finished are both 200 and differ only in `State`. `Result` is written once by `SaveResult`, so **no partial answer exists**. An unknown `dir` is 404 `PORT.NOTFOUND` and a missing `dir` is 400 `PORT.VALIDATION`, both set before the hand-off.
- `SYS.Database.cls:86` declares `Parameter RESOURCEREQUIRED = "%Admin_Secure"` and backs `GET` and `VOLUMELIST`; every method body in that class and in `SYS.Metrics.cls` is stripped in this build, so **only the least-privileged probe settles whether it bites** — add no `QUERYPAIRS` entry before it runs.

Server:

- New: `src/OcuPilot/Screen/Descriptor/{DatabaseList,DatabaseFreeSpace,DatabaseDetails,DatabaseVolumeList}.cls`. Models: `LockList.cls:43-90` (newest full list), `ProcessDetails.cls:37-110` (parent-scoped detail with auto-refresh), `TaskDetails.cls:80-92` (`GET` + keyed `rowGet.type INFO`), `X509CredentialList.cls:55-67` (`LIST` + `rowGet`).
- `Screen/Registry.cls` — `:1368` `READSOURCETYPES`; `:898-912` the `HISTORY` arm to copy; `:844` the type refusal sentence; `:1798-1807` `id.parts ⊂ read.fields`; `:1790-1793` exactly one `name` column; `:2249-2279` `ParentScopeResolutionProblem`; `:602-623` area coverage. Descriptors are discovered by SQL over `%Dictionary.CompiledClass` — no roster edit.
- `Screen/Read.cls` — `:262-320` the `GET` branch, `:313` the id seeding, `:316` the `rowGet` key seeding; `:325` the list branch to extend; `:759` `DetailRow`; `:74` `DEFAULTMAXROWS`; `:343` truncation.
- `Port/AdminPort.cls` — `:101` `TYPESUFFIXES` (already carries `INFO`); `:130` `QUERYPAIRS`; `:160` `ASYNCTIMEOUT`; `:163` `POLLINTERVAL`; `:325` `Invoke`; `:357-362` the 202 + `Location` entry; `:851-886` `AwaitTask`; `:879` the timeout refusal with `Api/Error.cls:185` `PORTTIMEOUT`.
- `Screen/Area.cls:102` — the union already carries all three pairs. Its own `:57-58` false-denial count ("0 of 1 … 2 of 3 once 6.8 and 6.10 land") is stale; correct the sentence, do not append to it.
- Untouched: `Screen/Gate.cls`, `Screen/Tool/**` (the four read tools derive themselves, `Tool/Registry.cls:104-120`), `Api/Router.cls:81` (one generic read route), `Install/Installer.cls`, `Install/Roster.cls`, `Kernel/**`.

Roster tripwires, with their current literals — **no stage re-runs these by itself**:

- `src/OcuPilot/Test/Navigation.cls:329` count `4` and `:330-337` the four per-index assertions. `ScreensForArea` collates by `(sideBarPosition, class name)` (`Registry.cls:2089-2101`), so the roster becomes **8** and **every index moves**: 0 `databases/details`, 1 `database-free-space`, 2 `databases/volumes`, 3 `processes/details`, 4 `processes`, 5 `locks`, 6 `system-usage`, 7 `databases`. Duplicate positions inside an area are legal (`security` ships four at 0).
- `src/OcuPilot/Install/Smoke.cls:595` loop bound `For tI = 1:1:23`, `:596` the name list, `:600` the `$Select` arms, `:727-787` `CheckProcessDetails` as the detail model, `:185` `Run`'s call list; `src/OcuPilot/Test/Smoke.cls:593` asserts arm count == name count == loop bound, and `:564`, `:572-575`, `:670` carry the path count and tool-parameter list.
- `src/OcuPilot/Test/ReadTool.cls:93` tool count `30`, `:94` the sorted tool-name string, `:337` `tWithCriteria` `8`, `:263` the admin-`%DB_IRISSYS:READ` class list.
- `src/OcuPilot/Test/Wire.cls:675` and `src/OcuPilot/Test/WireSecurityRead.cls:510`, `:517`, `:520` — four verbatim JSON literals enumerating every os-management screen in roster order with its `failedPair`; `:506` and `:599` are the per-screen least-privileged models.
- `src/OcuPilot/Test/Descriptor.cls:763` archetype count `16` and `:1054` `EntityType.Count()` `28` both **stay** — `list (two views)` and `database` are already in their vocabularies.
- `ui/tools/strings.test.mjs:334-337` the 150–450 literal band (423 today) and `:358-392` set equality in both directions against EXPERIENCE.md's table; `ui/tools/navigation.test.mjs:125-163` the hand-ordered route roster and its message at `:162`; `ui/tools/navigation-wire.test.mjs:38-306` and `ui/src/app/shell/rail-wire.spec.ts:37` the two `LIVE_PAYLOAD` copies, **neither of which reddens alone**; `ui/browser/screen-height.browser-spec.mjs:41-49` the geometry roster, which never got Locks or System usage.

Client:

- `ui/src/app/shell/screen-outlet.ts:51-53` the `ARCHETYPE_PAGES` required-key assertion (so `list (two views)` must gain an entry the moment a built screen declares it), `:55-64` the map, `:81-87` `DESCRIPTOR_PAGES` (resolved first), `:115-125` the order; `screen-outlet.spec.ts:317-353` pins both.
- `ui/src/app/shell/list-page.ts:68-190` `ListPage`; `ui/src/app/areas/tasks/upcoming.page.ts:85-110`, `:144-172`, `:219-224` the registrant to copy for a control above the shared table.
- `ui/src/app/shell/command-bar.ts:98-102` records that the View slot is deliberately unrendered because no copy existed. That reason is gone once the strings row lands — rewrite the comment, do not append to it. `:162-219` is the sort menu to copy, with `SORT_TRIGGER_ID :33`, `SORT_MENU_ID :36`, `SORT_MENU_OVERLAY_ID :39`; `:230-239` and `:471-478` the auto-refresh chip.
- `ui/src/app/shell/data-table.ts:611-617` the kind-derived grid tracks — **the no-reflow mechanism** — binding at `:191`/`:232`; `:143-153` the whole-table skeleton (there is no per-cell state today); `:422-455` the row-link chain; `ui/src/styles/_components.scss:2217-2246` the fixed row height and clipped cells, `:85-120` the skeleton rows.
- `ui/src/app/shell/meter.ts:96-102` the seven signal inputs, `:115-129` pending giving a skeleton fill and `'—'`; `ui/src/app/core/meter-state.ts`. Story 6.9's `METER_CONFIGS` is screen-local (`system-usage.store.ts:59-72`), so Database details declares its own — one **value** meter, no percentage and no state, since `AvailableSpace` and `Size` are not published in the same unit.
- `ui/src/app/core/navigation.ts:225-254` `childListFor` and `detailScreenFor` — both `.find()` over `parentScope`, disjoint on `archetype === 'detail'`, so one parent may pair one detail child and one child list; `:305-315` `parentCriteria`, which decodes twice and rejects an id segment containing `/`; `ui/src/app/core/entity-id.ts:56`; `ui/src/app/app.routes.ts:62-80` `buildRoutes`.
- `ui/src/app/core/refresh.ts:227-248` `bind`, which throws for a `refreshes` screen bound with a null read; `ui/src/app/shell/status-bar.ts:186-189` the stamp; `ui/src/app/core/detail-highlights.ts:33-61` the shared field highlight.
- `ui/src/app/areas/os-management/` holds Stories 6.8 and 6.9's six files; convention `<kebab>.page.ts` + `.page.spec.ts` + `<kebab>.store.ts` with the pure store pinned by `ui/tools/<kebab>-store.test.mjs`. `ui/browser/browser.config.mjs:60-84` **throws** unless both `OCUPILOT_BROWSER_ORIGIN` and `OCUPILOT_BROWSER_CONTAINER` are non-default; browser specs register by filename (`package.json:17`) and `ui/tools/angular-json.test.mjs:247-280` enforces the naming both ways.
- Unaffected: `ui/tools/classic-links.mjs` (four bare `classicPage`s, no exemption), `ui/tools/field-lists.mjs` (no write tool), `ui/src/app/testing/screen-declaration.ts`.

## Tasks & Acceptance

**Execution:**

1. **Precondition, applied by the lead before this spec was dispatched.** `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md:365` carries the Databases row verbatim, after the Locks row, and `:98`'s screen-inventory row is corrected with the AC3 amendment. Implement edits no planning artifact; it reads that row as the authority for the 24 new strings, and `strings.test.mjs` re-derives its authorized set from it. The lead also recorded, in AD-5, that a page may issue another built screen's declared read (this story's two uses), so that mechanism is settled grammar rather than a slice invention.
2. `src/OcuPilot/Screen/Registry.cls` — add `VOLUMELIST` to `READSOURCETYPES` and its own arm refusing `rowGet` and `forEach`, worded like the `HISTORY` arm; extend the type refusal sentence's list. Rationale: the vocabulary fails closed, so the type must be admitted before any descriptor can name it.
3. `ui/tools/screen-mirror.mjs` — the same widening in `readProblem`, character-identical sentences.
4. `src/OcuPilot/Test/ReadSourceCorpus.cls` — cases for the new type: one sound parent-scoped `VOLUMELIST`, and refusals for a non-`admin` port, a declared `rowGet` and a declared `forEach`. One corpus is what keeps the two engines' sentences identical; `ui/tools/screen-mirror.test.mjs` runs the same block.
5. `src/OcuPilot/Port/AdminPort.cls` — append `VOLUMELIST` to `TYPESUFFIXES`. Add **no** `QUERYPAIRS` entry until item 17's probe says the backing query is stricter.
6. `src/OcuPilot/Screen/Read.cls` — the list branch treats `VOLUMELIST` exactly as `UPCOMING` and `HISTORY`. Additive.
7. The four descriptors from Boundaries. Each doc comment states why its pair set is what it is; `DatabaseList`'s and `DatabaseFreeSpace`'s record **why the classic key is `%CSP.UI.Portal.OpDatabases`** and not `%CSP.UI.Portal.Databases` — `OpDatabases` is the `%Admin_Operate` page at `/csp/sys/op/` carrying the literal General/Free-space toggle, and AD-44 unions the custom resource assigned to that key into the gate, so the choice changes the gate. Compile through the IRIS MCP tools on `ocupilot-slot-b` and read the error text.
8. `src/OcuPilot/Screen/Area.cls` — replace the stale false-denial count sentence at `:57-58` with the real one for eight os-management screens, established by item 17's probe rather than asserted.
9. `ProcessList.cls:35`, `TaskDetails.cls:39`, `TaskScheduleList.cls:40`, `TaskRunList.cls:30` — the auto-refresh roster is **seven** screens, not six. Replace the wrong word at each origin.
10. `ui/src/app/core/strings.ts` — the 24 keys of item 1 in EXPERIENCE.md row order, each preceded by its `/** EXPERIENCE.md:<line> */` citation; reuse `processDetailsGroupGeneral`, `taskHistoryColumnStatus`, `lockColumnDirectory`, `webAppColumnResource` and `tableReadOnlyEmptyNext`. `ui/tools/strings.test.mjs:334-337` — this row takes the table to 447 of a 450 ceiling, so raise the upper bound to 520 and say why in the existing comment's own form, as the 400 → 450 move did.
11. Regenerate the mirror: `cd ui && node tools/screen-mirror.mjs`. Never hand-merge `screens.generated.ts`.
12. `ui/src/app/shell/screen-outlet.ts` — `ARCHETYPE_PAGES['list (two views)']` plus a `DESCRIPTOR_PAGES` entry for `os-management/database-free-space`, both resolving to one new `ui/src/app/areas/os-management/databases.page.ts` over `ListPage`'s binding, which holds the two routes and their label keys as a screen-local constant and renders the command bar's View control. `ui/src/app/shell/command-bar.ts` — render the View slot and rewrite the `:98-102` comment.
13. `ui/src/app/areas/os-management/database-details.page.ts` + `.store.ts` — the "General" properties group, the one `Available` value meter, and the "Volume files" section fed by the `osmgmt.databasevolumes` read. A faulted refresh keeps the last values and raises the refresh strip; the field highlight is the shared `detail-highlights.ts` helper, never a per-page diff.
14. `ui/tools/navigation.test.mjs`, `ui/tools/navigation-wire.test.mjs`, `ui/src/app/shell/rail-wire.spec.ts` — the route roster and both `LIVE_PAYLOAD` literals.
15. `src/OcuPilot/Test/Navigation.cls` — the count `4` → `8` **and every per-index assertion** rewritten to the collation order in the Code Map, with the comment corrected. The roster has gone red in CI on two consecutive stories; demonstrate a mutation on one corrected assertion (Rule 19) and sweep for any other test pinning a per-area roster by index.
16. `src/OcuPilot/Test/Descriptor.cls` and `Test/ScreenRead.cls` — the exact field and column-set pins for all four descriptors, the corpus test from item 4, the seeded-`Directory` assertion, and a live-value assertion that the read answers values rather than null-filled keys. `Test/ReadTool.cls` — counts `30` → `34`, `tWithCriteria` `8` → `10`, the sorted tool-name string and the IRISSYS class list.
17. `src/OcuPilot/Test/WireSecurityRead.cls` — one least-privileged test per new screen, on the `:506`/`:599` model. Create purpose-built principals on the throwaway, never `%Operator`: `%Admin_Manage`-only, `%Admin_Operate`-only, and each without `%Admin_Secure:USE`. **Append whatever the instance still refuses to the declared pair sets and correct the descriptors and Boundaries at their origin** (AD-29 — `ResourcesOR()` is a lower bound); a stricter backing query goes in `AdminPort`'s `QUERYPAIRS`. Update `Test/Wire.cls:675` and `WireSecurityRead.cls:510`, `:517`, `:520`.
18. `src/OcuPilot/Install/Smoke.cls` — the three new list tools in the name list, one `$Select` arm each, the loop bound raised, and a `CheckDatabaseDetails` private method on the `:727-787` model added to `Run`'s call list; then `src/OcuPilot/Test/Smoke.cls:564`, `:572-575`, `:593`, `:670`. A partial edit is red.
19. `ui/browser/databases.browser-spec.mjs` — **new**: the General view's headers and rows, the View control switching route, the skeleton cells before the figures land, their filling together, and the geometry sampled twice with `getBoundingClientRect()`. `ui/browser/screen-height.browser-spec.mjs:41-49` — backfill `os-management/locks` and `os-management/system-usage`, which were never added, and add the two Databases views; confirm System usage's own scroll element rather than assuming `cdk-virtual-scroll-viewport`. Both `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci` on every browser and `ci-runner` call; rebuild and redeploy the bundle before believing any result.
20. Verification pass: the commands in `## Verification`, then the throwaway teardown.

**Acceptance Criteria:**

- **AC1** — Given the four compiled descriptors, when `Registry.Validate` runs over the roster, then all four validate, `DatabaseList` is the fourth OS-management side-bar entry between System usage and (unbuilt) Devices, and `screens.generated.ts` carries all four. Pinned by `Test/Descriptor.cls`, `Test/Navigation.cls` and `ui/tools/navigation.test.mjs:125`.
- **AC2** — Given the Free-space view opened, when the General read has answered and the free-space read has not, then every row is on screen with its `Directory` and `Size` cells filled and its `Available`, `Disk free` and `Mounted` cells drawn as skeleton cells — not "(none)", not empty. Pinned by `ui/browser/databases.browser-spec.mjs`.
- **AC3** — Given the same view, when the free-space read resolves, then all three figure columns carry the values `INFO` reported, in one tick, with no skeleton left and no second request per row. Pinned by the same browser spec and by `Test/ScreenRead.cls` (every declared field a key of the live row, holding real values).
- **AC4** — Given rows rendered with empty figure cells, when the figures arrive, then the header column boundaries and the row height are identical to two decimal places before and after, because the grid tracks come from the declared column kinds. Pinned by `ui/browser/databases.browser-spec.mjs` — jsdom computes no layout, so this AC cannot live in a component spec.
- **AC5** — Given an async `INFO` task that does not reach `Finished` within `ASYNCTIMEOUT`, when the free-space read runs, then it is refused whole with HTTP 503 and code `PORT.TIMEOUT`, and no row carries a partial figure. Pinned by `Test/ScreenRead.cls`.
- **AC6** — Given Database details on screen with values, when an auto-refresh's `INFO` call faults with a non-404 status, then the last values stay on screen and the refresh strip appears. Pinned by `ui/src/app/areas/os-management/database-details.page.spec.ts` and `ui/tools/database-details-store.test.mjs`.
- **AC7** — Given a real principal on the throwaway holding exactly `%Admin_Manage:USE` and `%DB_IRISSYS:READ`, when each of the four reads is issued, then the General view and the volume list are served and the Free-space view and Database details are refused naming the first pair not held — never a 500 and never an empty state; and the declared sets are corrected to whatever the instance actually refuses. Pinned by `Test/WireSecurityRead.cls`.
- **AC8** — Given Database details opened on a live directory, when its read answers, then it is one row of exactly fifteen fields: `Directory` seeded from the route-id criterion, `GET`'s ten properties and the `rowGet`'s four, with neither `MaxSize` nor `ExpansionSize` taken from `INFO`. Pinned by `Test/Descriptor.cls` (exact set) and `Test/ScreenRead.cls`.
- **AC9** — Given a `VOLUMELIST` source declared with one route-id criterion, when `osmgmt.databasevolumes` reads a single-file database, then it answers one row whose `File` is `IRIS.DAT`, and Database details' "Volume files" section renders that row — the consumer exercising the new source type at the DOM, not by inspecting the declaration. Pinned by `Test/ScreenRead.cls` and `ui/browser/databases.browser-spec.mjs`.
- **AC10** — Given the four derived read tools, when each is invoked, then it returns its own screen's declared read — same fields, filter and sort — narrowed by the context cap, with no secret fields and no second query. Pinned by `Test/ReadTool.cls`.

## Design Notes

**Governing ADs:** AD-2, AD-5, AD-8, AD-13, AD-26 (async through the port only), AD-27 (`AdminPort` alone names `%Api.Admin.*`), AD-29 (pair sets are established, not copied), AD-36 (one read per screen, shared with its tool), AD-37, AD-43 (the roster of seven), AD-44 (the classic key's custom resource unions into the gate).

**Consumes:** Story 2.1 (`AdminPort`'s sync and async paths, `AwaitTask`, `PORT.TIMEOUT`), 2.3 (the declared read), 2.4 (`ListPage`, the shared table, the command bar), 1.14 (the auto-refresh framework), 6.3 (`rowGet.type`, the parent-scoped list grammar), 6.5 and 6.6 (`UPCOMING`/`HISTORY` — the precedent `VOLUMELIST` follows exactly), 6.7 (a parent-scoped `GET` with a keyed `rowGet` and auto-refresh), 6.8 (`detail-highlights`), 6.9 (the meter component).

**Consumed-by:** Story 6.12 (Devices, the fifth side-bar entry, inherits the `Test/Navigation.cls` roster this story rewrites), Stage 2's database actions (which will reuse these descriptors' reads and row keys), and any later screen whose vendor answer is a `TYPE`-prefixed list.

**Integration AC:** AC9 — the Database details page consumes `osmgmt.databasevolumes`, the read the new `VOLUMELIST` source type introduces, and the effect is asserted at the DOM. AC2 is the same mechanism's second consumer (the Free-space page consuming `osmgmt.databases`).

**Why two descriptors and not one.** A descriptor's gate requires every pair it declares (`Gate.cls:109-129`) and the two views do not share one: `LIST` takes Manage alone while the `AsyncResult` poll takes Operate alone, so a single descriptor would deny each view to a principal who could read it. Two descriptors also keep one read per view, which is what AD-36 wants, and give each its own derived tool.

**Why the figures arrive together.** `Read.Execute` answers one envelope and issues `rowGet` per row inside it, so per-figure arrival is not declarable; `Result` is written once by the vendor, so no partial answer exists either. The whole read costs 0.852 s for fourteen databases against NFR-1's 2 s, which is why one read was chosen over N requests. `epics.md` AC2, `EXPERIENCE.md:496` and `:625` and AD-26's parenthetical are amended to match.

**Why the pair sets may move.** `ResourcesOR()` plus a backing query's own check is a lower bound, and `SYS.Database`'s `RESOURCEREQUIRED = "%Admin_Secure"` is unreadable in this build. Execution 17 establishes the real sets; a correction goes into the descriptors and into Boundaries above, not appended as a note.

**Ledger.** Nothing is owned by this story. DW-1073, DW-1074, DW-1078, DW-1079 and DW-1080 are referenced where relevant and not re-filed; DW-1021 is the accepted path for a stale route id. DW-1079 matters operationally: `WalletCollectionList` answers zero rows on slot B, so `Test/ScreenRead` and `Test/Smoke` are already red there for reasons that are not this story's.

## Verification

**Commands** (from the worktree root unless noted; every IRIS MCP call carries `server: "ocupilot-slot-b"`):

- `uv run scripts/check-objectscript.py` over every changed `.cls` -- expected: no findings
- Compile the changed classes with `iris_doc_load` + `iris_doc_compile` -- expected: clean, error text read on any failure
- `iris_execute_tests` on `OcuPilot.Test.Descriptor`, then `ScreenRead`, then `ReadTool`, then `WireSecurityRead`, then `Wire`, then `Navigation`, then `Smoke` -- **one class per tool call**, each confirmed landed in `%UnitTest_Result` before the next; never re-submit on a client-side timeout
- `cd ui && node tools/screen-mirror.mjs && npm run build` -- expected: mirror regenerated, then `prebuild`'s six checkers pass including `screen-mirror.mjs --check`
- `cd ui && npm test` -- expected: green, including `screen-mirror.test.mjs`, `strings.test.mjs`, `navigation.test.mjs`, `navigation-wire.test.mjs`, `angular-json.test.mjs`, `database-details-store.test.mjs` and the two new component specs
- `sh scripts/ci-throwaway.sh up --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci --web 52777 --super 1976`, then `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci npm run test:browser` -- expected: green, `databases.browser-spec.mjs` and `screen-height.browser-spec.mjs` included. Rebuild and `docker cp dist/ocupilot/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/` before reading any result; `down` the same throwaway before returning and tear down nothing else
- `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` -- expected: the three new list checks and `CheckDatabaseDetails` execute and pass; zero executed checks is a failure
- `bash scripts/lint-docs.sh` -- expected: clean

**Mutations** (Rule 19 — one per AC; apply, observe red, revert, confirm `git status --short` and `git diff --stat` unchanged):

- AC1 -- mutation: change `DatabaseList`'s `sideBarPosition` to 5 → `navigation.test.mjs`'s route-roster assertion and `Test/Navigation.cls`'s per-index assertions go red
- AC2 -- mutation: make `databases.page.ts` withhold rows until the free-space read resolves → the browser spec's skeleton-cell assertion goes red (no rows to sample)
- AC3 -- mutation: make `Screen/Read.Project` emit every declared field as JSON `null` → `Test/ScreenRead`'s real-value assertion goes red naming the null-filled row
- AC4 -- mutation: in `data-table.ts:611-617`, map one column kind to `auto` instead of `minmax(0, <n>fr)` → the geometry assertion goes red once the figures widen the cell; rebuild and redeploy before re-running
- AC5 -- mutation: make `AdminPort.AwaitTask` return the last poll's `Result` on timeout instead of refusing → `Test/ScreenRead`'s `PORT.TIMEOUT` assertion goes red
- AC6 -- mutation: make `database-details.store.ts` clear its fields when a refresh faults → the component spec's last-values assertion goes red
- AC7 -- mutation: remove `%Admin_Operate:USE` from `DatabaseFreeSpace`'s `privileges` → `WireSecurityRead`'s denial-order assertion goes red
- AC8 -- mutation: add `"ReadOnlyReason"` to `DatabaseDetails`'s `read.fields` without adding it to `rowGet.fields` → `Test/ScreenRead.TestEveryDeclaredReadFieldIsAKeyOfTheLiveRow` goes red
- AC9 -- mutation: change `DatabaseVolumeList`'s source type to `LIST` → `Test/ScreenRead`'s volume-row assertion goes red (the endpoint answers the database list instead); and drop `VOLUMELIST` from `AdminPort`'s `TYPESUFFIXES` → the read fails at `EndpointType`
- AC10 -- mutation: rename `DatabaseVolumeList`'s `toolIdentifier` to `osmgmt.volumes` → `Test/ReadTool`'s tool-name roster goes red

Recompile the whole `OcuPilot` package after any mutation to an inherited method before reading a result, and confirm which compiled copy ran.

## Implementation Notes

## Spec Change Log

- 2026-09-17, plan iteration 2: the six clarifications of iteration 1 answered and folded in as settled; the question apparatus removed. Two mechanism corrections recorded at their origin in Boundaries — Database details reads `GET` plus `TYPEINFO` through `rowGet.type = "INFO"` rather than `source.parts`, and the Free-space view's route is `os-management/database-free-space`.

## Review Triage Log

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

All six clarifications are written in as settled. Four descriptors ship: the General view (listed,
position 4), the Free-space view, Database details and its volume files. One additive grammar
widening — `VOLUMELIST` joins `READSOURCETYPES` and `AdminPort`'s `TYPESUFFIXES` on the
`UPCOMING`/`HISTORY` precedent — and one new client mechanism, a page reading another built
screen's declared read, used by the Free-space view for its rows and by Database details for its
volume-files section. The os-management roster goes from four screens to eight, not seven: the
volume-files screen is the second parent-scoped list the Q3 answer names.
