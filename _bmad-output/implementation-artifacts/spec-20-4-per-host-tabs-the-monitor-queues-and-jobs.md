---
title: 'Story 20.4: Per-host tabs, the monitor, queues and jobs (reads; the actions are the stated partial)'
type: 'feature'
created: '2026-10-10'
status: 'done'
baseline_revision: '0a451914fe862a8cc51f4194f83f97289bcbdf99'
baseline_commit: '00b1beefec887efee69cab0445dd9a61d6d70327'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
warnings: [oversized, multiple-goals]
deferred:
  - summary: >-
      The queue and job actions (abort one queued message, abort a whole queue, abort or suspend a job's message, stop a job) are this story's stated partial and need a follow-up story; Design Notes › Split carries its measured charter.
    evidence: |-
      Story 20.4's second AC names the actions as custom endpoints and reads-first as a stated partial; catalog rows IO-11 and IO-12 are write-confirm.
      Measured on ocupilot-b-ci at this plan: each action exists as a vendor class method with its own check, writes no audit row, and two of them answer OK on an idle target.
    location: >-
      src/OcuPilot/Port/InteropPort.cls
    severity: med
  - summary: >-
      The classic per-host Actions tab's remaining item actions (temporary stop, start and restart of one item, change class, copy) have no story; enable, disable and remove are 20.3's row actions and Test is 20.6's.
    evidence: |-
      Read in irislib/EnsPortal/ProductionConfig.cls:952-1077 and :4240 (updateActions). Story 20.4's criteria name only abort, abort all, suspend and stop; IO-08's change class and copy are unbuilt.
    location: >-
      src/OcuPilot/Screen/Descriptor/InteropItemList.cls
    severity: low
---

<intent-contract>

## Intent

**Problem:** OcuPilot lists a production's items and their settings (20.3, 20.22), but none of a host's runtime state: its queue, its event log, its messages, its jobs, the production monitor, and the namespace's queues and jobs. Diagnosing a running production still means the classic portal.

**Approach:** Extend `Port/InteropPort` (AD-62) with nine read endpoints. Item settings joins a parent-scoped tab group under Production items (AD-5): Status, Settings, Queue, Log, Messages and Jobs, one descriptor per tab. Production monitor, Queues (with Queue messages) and Jobs join the Interoperability side bar. Every screen's read tool derives from its descriptor (FR-80). This story ships the reads only. The queue and job actions are the AC's stated partial and go to a follow-up story, whose charter Design Notes › Split records.

## Boundaries & Constraints

**Always:**

- Every new read goes through `InteropPort.Invoke` behind the port's gate (AD-29, AD-62 (2)): the endpoint's pairs, then READ on the namespace's globals database. Each refusal names its pair. The vendor's reads check nothing (measured), so this gate is the whole gate.
- Each screen declares its classic page's own check as an own pair (the `InteropFloor*` rule, AD-8), and its read tool is derived (AD-36).
- `Ens.MessageHeader` and `Ens_Util.Log` are read by bound SQL through `%ExecDirectNoPriv`, after the gate, as `LogSourcePort` reads `Ens_Util.Log` (AD-29's named exception, extended here). The `%Ens_*` resources grant no SQL (measured).
- Reads are bounded by AD-24 and AD-36 (cap plus one, total and per-field bounds). Log text, names and message metadata reach the model only through AD-60. No message body or contents are read.
- A read changes nothing (AD-7). The port never calls `Ens.Job:Enumerate`, whose `MarkDeadJobs` repairs dead jobs, writing seven globals, an event-log row and the queue (read in source; measured that it writes nothing when no job is dead). It never calls a queue or job action.
- Item settings keeps its route, tools and rules. Only its archetype (`detail`), its `tab` and its page's host component change, and `InteropSettingDescriptor`'s archetype assertion moves with them.
- Edits to files another epic is changing are add-only: roster rows, list entries, and the count pins that move with them (Design Notes › Contended files).

**Never:**

- No write, tool, governance key or proposal: no abort, abort all, suspend or stop (the stated partial), and none of the classic Actions tab's item actions (temporary stop, start or restart, change class, copy).
- No `%Api.InteropEditors.*`, no `Ens.Job:Enumerate`, `MarkDeadJobs` or `StopJobs`, no `Ens.Queue` or `Ens.Job` method that writes, and no message body, contents or trace.
- No edit to `Screen/Registry.cls`, `ui/tools/screen-mirror.mjs`, `screen-outlet.ts`, `screen-action-handler.ts` or `navigation.ts`. The tab group, the row targets and the auto-refresh use declarations those already accept.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Status tab | An item opened from Production items or the monitor (`item` = composite or `Production\|\|Name`) | One row: the item's config facts (`Production, Name, ClassName, Type, Enabled`), plus the host monitor's `Status, AdapterState, LastActivity` while its production is the namespace's current one and running or troubled; otherwise those three are empty | 404 `PORT.NOTFOUND` for an unknown production or item; 409 `INTEROP.ITEM.AMBIGUOUS` |
| Queue tab / Queue messages | Waiting messages | One row per entry (`Priority, Index, MessageId`), joined to its header (`Source, Target, BodyClass, TimeCreated, Status`). A pool-size-0 business process reads `Ens.Actor`'s entries whose target is the item | No entries: no rows |
| Log tab | Event log rows whose `ConfigName` is the item | Newest first: `ID, TimeLogged, Type, Text, Job, SessionId` | — |
| Messages tab | Headers sourced by or targeted at the item | Newest first: `ID, TimeCreated, Status, Source, Target, BodyClass, SessionId` | — |
| Jobs tab / Jobs | The running production's jobs | `Job, Host, Status, AdapterState, LastActivity, Retry, ActiveMessage, Dead`. `Dead` is true when no process holds the pid; such a row is answered, never repaired | Production not running or troubled: no rows |
| Monitor | The namespace's running production | One row per item it runs, from `Ens.Util.Statistics:EnumerateHostStatus`: `Name, Type, Status, AdapterState, LastActivity, ElapsedTime, Queue, Count`, plus `Production` and `Item` (`Production\|\|Name`). Vendor hosts the production does not configure (`Ens.Actor`, `Ens.ScheduleHandler`, …) are left out | Not running or troubled: no rows |
| Queues | The namespace's queues (`Ens.Queue:Enumerate`) | `Name, Count, Active, Created` (`Active`: the host's jobs holding an active message) | — |
| Gate | A caller missing one declared pair | Refused before any vendor call | 403 naming the pair |
| Namespace | A namespace that does not report interoperability | Refused | 409 `INTEROP.NAMESPACE` |

</intent-contract>

## Code Map

### Port

- `src/OcuPilot/Port/InteropPort.cls` (2165 lines), 20.2/20.3/20.22's shape:
  - `ENDPOINTS` :51 (read by `ui/tools/screen-mirror.mjs`:1084, so no mirror edit); endpoint constants :53-69; `PRODUCTIONPAIRS` :74
  - `Pairs` :286, `Serves` :301, `Invoke` :391 (Items → `InvokeItems` :408, Settings → `InvokeSettings` :412), `Admit` :470 (pairs, namespace shape, `NamespaceFeatures`, globals-database READ)
  - `ReadState` :603 and `StateRow` :660 read the production's state (reuse for "running or troubled")
  - `ItemParts` :1323 accepts the composite or `Production||Name`; `ItemObject` :1079 finds an item; `GatherSettings` :1517 counts same-named items for `AMBIGUOUS`. The new item-scoped endpoints reuse all three.
  - `SnippetForm` :2037 answers only writes, so it needs no branch.
- `src/OcuPilot/Screen/Read.cls` :547-568: the interop branch requires a parent-scoped list's one criterion and passes the cap plus one. No edit.
- `src/OcuPilot/Port/LogSourcePort.cls` `FetchEvents` :1615-1625 is the NoPriv precedent (`SELECT TOP ? … FROM Ens_Util.Log … ORDER BY ID DESC`). It is not called: another port, a merged-namespace row shape, and no criterion (Registry refuses criteria on `logsource`).
- Vendor (read only, `irislib/`):
  - `Ens/Util/Statistics.cls` `EnumerateHostStatus` :100 (skips `Ens.MonitorService`, `Ens.Alarm`, `Ens.Alert`) and `EnumerateJobStatus(pHostName)` :182 (`""` answers no rows, measured)
  - `Ens/Queue.cls` `Enumerate` :876 (`Name, Count, Created`; hides `SystemSignal:`), `EnumerateItem(QueueName, PriorKey)` :910 (`Priority, Index, MessageId`), `GetCount` :966
  - `Ens/Job.cls` `Enumerate` :837 calls `MarkDeadJobs` :675 (never call)
  - `EnsPortal/ProductionConfig.cls`: tabs :764-1077; tab gates in `initSecurity` :7824; Messages query :851-864; queue resolution `EnsPortal/Utils.cls` `ItemQueueList` :517 (pool-size-0 business process → `Ens.Actor` filtered by target, :561-647); Log query `Utils.cls` :689-692
  - `EnsPortal/Utils.cls` `ItemStatuses` :149: the configuration page's per-item status, read from the host monitor
  - `EnsPortal/ProductionMonitor.cls` RESOURCE `%Ens_Dashboard:USE` :13; `EnsPortal/Queues.cls` RESOURCE `%Ens_Queues:READ` :15; `EnsPortal/Jobs.cls` RESOURCE `%Ens_Jobs:READ` :10
  - `%Library/EnsembleMgr.cls`: `%EnsRole_Operator` :5083 holds `%Ens_Dashboard:U`, `%Ens_Queues:R`, `%Ens_Jobs:R`, `%Ens_EventLog:U`, `%Ens_MessageHeader:U`, `%Ens_ProductionConfig:R`; `%EnsRole_Monitor` :5357 holds `%Ens_Portal:U`, `%Ens_Dashboard:U`

### Screens and registry

- `Screen/Descriptor/InteropItemSettingList.cls` (83 lines) is the shape each tab copies (descriptors are one declaration per screen, AD-5); `InteropItemList.cls` and `InteropProductionList.cls` the list shapes; `ExplorerSqlIndices.cls` a `detail` tab with a LIST read.
- Tab group rules, `Screen/Registry.cls`:
  - `TabProblem` :572: position 1's route is the group; position above 1 means `sideBarPosition` 0
  - `TabGroupProblem` :694: shared area and archetype :723; positions 1..N :732; shared `parentScope` :756; one shared criterion (param, kind, maxLength) :764 via `TabCriterion` :792; a parent-scoped group is `<parentScope>/document` :771
  - `rowTarget` :3864 (keys `route, field, unless`; list archetypes only; field one of `read.fields`; route a built, id-keyed screen); `RefreshProblem` :465; column kinds `name, identifier, text, number, status` :2603
- `Kernel/EntityType.cls` `TYPES` :107 (65 entries, `production-item-setting` last); `log-entry` and `production-item` exist. `cd ui && node tools/screen-mirror.mjs --check` reads "161 descriptor(s), 11 area(s), 65 entity type(s)".

### Client

- `ui/src/app/areas/interoperability/interop-item-setting-list.page.ts` :48-60: `imports: [ListPage, …]`, template `<app-list-page />`. `ui/src/app/shell/detail-page.ts` (`app-detail-page`) draws the strip from `tabMembersFor` and hosts `<app-list-page />`.
- `ui/src/app/core/navigation.ts`, read only:
  - `documentScreenFor` :302 is what Production items' name cell takes once `items/document` exists (`data-table.ts` :655-662)
  - `childListFor` :329 skips `detail`
  - `screenForEntityType` :502 and `ownerListFor` :617 take list archetypes only. So a setting change's toast falls back to the one screen declaring `production-item-setting`, and `routeIdFor` :627 is unchanged.
- `ui/src/app/core/strings.ts` interop block :6185-6371. `ui/tools/strings.test.mjs` bound 3400 (:608-611); 3036 literals now.
- `EXPERIENCE.md`:
  - :159 Interoperability side-bar sentence
  - :896 Auto-refresh controls roster (`citations.test.mjs` gates the phrase "**Auto-refresh controls.** On Processes")
  - :604 the last Fixed-strings row; 90 `strings.ts` citations point at it, so no line is inserted above :604

### Tests

- `Test/ProductionProbe.cls` (522 lines): the op's `Hang` method in `ClassText` :52-66; `Create` :141, `Send` :326, `SetHang` :381, `Settle` :419, `Remove` :494 (deletes the probe's headers and log rows :512-513), `Gone` :474.
- `Test/InteropItemGate.cls` :340-400 and :440-460: principals and the `JOB`/`Login` probe; `Test/InteropSettingGate.cls` reuses them through a parameter.
- Rosters this story moves:

| File | Anchor | What |
|---|---|---|
| `Test/InteropFloor.cls` | `BASESCREENS` :31, `OPERATORSCREENS` :42, `OPERATORTOOLS` :45 | floor rosters |
| `Test/Navigation.cls` | :530-531 | 6 interop screens and their order |
| `Test/ReadTool.cls` | :93-94 | 331 and the sorted names |
| `Test/Descriptor.cls` | :1764 | 65 entity types; refreshing legs :642, :738, :1776 |
| `Test/SurfaceCoverage.cls` | :215-220 | screens |
| `Test/InteropSettingDescriptor.cls` | :35 | asserts `list` |
| `ui/tools/navigation.test.mjs` | :348-353 | built-route roster |
| `ui/tools/screen-mirror.test.mjs` | :1349/:1382, :2393-2407 | criteria roster, own-privilege owners |
| `ui/browser/structural-walk.mjs` | `SKIP` :97/:108 | routes needing ids |
| `scripts/ci-throwaway.sh` | :404-422 | `# classes:` arming lines, with `ui/tools/ci.test.mjs` :2285 |

- `ui/browser/interop-items.browser-spec.mjs` (`before` :180, `openItems` :164) and `interop-item-settings.browser-spec.mjs` (`ROUTE` :41) open the op from Production items and now land on the Status tab.

## Tasks & Acceptance

**Execution:**

- [x] **Task 0** (`ocupilot-b-ci` only, through `docker exec`; record each as a `Task 0:` line under Verification):
  - `NormalizePage` spells `EnsPortal.ProductionMonitor`, `EnsPortal.Queues` and `EnsPortal.Jobs` as written.
  - With the probe production stopped, record whether `EnumerateHostStatus` and `EnumerateJobStatus(op)` answer stale rows. The port's running-or-troubled check governs either way.
  - Terminate the running op job's process (`$SYSTEM.Process.Terminate`). Record how long its `^IRIS.Temp.EnsJobStatus` entry stays unrepaired with no OcuPilot call. If it stays at least 30 s, AC6's pin uses a dead job (Tests). Otherwise AC6 pins a live production and `Dead` through `JobRow` with a pid no process holds.
  - Record whether `%EXTERNAL(TimeCreated)` and `%EXTERNAL(TimeLogged)` read local time; the columns show what they read.
  - A Monitor-role principal (`%EnsRole_Monitor` plus `%DB_USER:R`) opens Production monitor, and is refused Status naming `%Ens_ProductionConfig:READ`.
- [x] `src/OcuPilot/Port/InteropPort.cls` (extend, reads only):
  - `ENDPOINTS` gains `Monitor, ItemStatus, Queues, QueueItems, ItemQueue, ItemLog, ItemMessages, Jobs, ItemJobs`, each serving `LIST` alone.
  - Pair sets:
    - `MONITORPAIRS` `%Ens_Portal:USE,%Ens_Dashboard:USE`
    - `QUEUEPAIRS` `%Ens_Portal:USE,%Ens_Queues:READ` (Queues, QueueItems)
    - `JOBPAIRS` `%Ens_Portal:USE,%Ens_Jobs:READ`
    - ItemStatus `PRODUCTIONPAIRS`; ItemQueue `PRODUCTIONPAIRS` plus `%Ens_Queues:READ`; ItemLog plus `%Ens_EventLog:USE`; ItemMessages plus `%Ens_MessageHeader:USE`; ItemJobs plus `%Ens_Jobs:READ`
  - `Invoke` sends the nine to one dispatcher, `InvokeRuntime`, beside `InvokeItems` and `InvokeSettings`. It checks `maxRows` as they do. The item endpoints require `item` (400 `REASONITEMIDREQUIRED`) and resolve it with `ItemParts`, then `ItemObject`, with `GatherSettings`' count rule: 404 unknown, 409 `AMBIGUOUS`. QueueItems requires `queue`.
  - Shared gatherers (Rule 31), each switching by explicit save and restore and calling no `OcuPilot.*` class while switched:
    - `GatherHosts(pNamespace, pName, pMax)`: Monitor (`pName` "") and ItemStatus. Only while `ReadState` reads the namespace's current production running or troubled. It answers the `EnumerateHostStatus` rows whose name is an item of that production. ItemStatus takes `Status`, `AdapterState` and `LastActivity` from the item's row, the light the classic configuration page draws per item (`EnsPortal/Utils.cls` `ItemStatuses` :149, under that page's `%Ens_ProductionConfig:READ`). Its config facts come from `ItemObject`.
    - `GatherQueueItems(pNamespace, pQueue, pTarget, pMax)`: QueueItems and ItemQueue. It runs `EnumerateItem`, opens each header (`%OpenId`), and drops entries whose target is not `pTarget` when it is given.
    - `ItemQueueName(pItem)`: the item's `QueueName()`, or `Ens.Actor` with the item as target for a business process of pool size 0.
    - `GatherJobs(pNamespace, pHost, pMax)`: Jobs (every host `EnumerateHostStatus` answers) and ItemJobs. Only while running or troubled. Each row goes through `JobRow`, which adds `Dead` from `'$Data(^$JOB(pid))`.
    - `SqlRows(pNamespace, pSql, pArgs…)`: ItemLog and ItemMessages. `%ExecDirectNoPriv`, every value bound, `TOP ?` set to the cap plus one.
      - The Log statement is `Utils.cls`:689-692's, with `%EXTERNAL(Type)`.
      - The Messages statement is `ProductionConfig.cls`:851-864's union of the newest by source and by target.
  - Queues runs `Ens.Queue:Enumerate` plus `Active`, the count of `EnumerateJobStatus(name)` rows with an active message.
  - Every row carries its parent key: `Production` and `Item` on item rows, `Queue` on queue entries.
- [x] `Kernel/EntityType.cls` (append): `interop-queue`, `interop-message`, `interop-job`, each kept exactly, with no `IDRULES` row. Its class comment gains one line each.
- [x] Descriptors (new, `src/OcuPilot/Screen/Descriptor/`). Each declares area `interoperability`, scope `namespace`, privileges = its endpoint's pairs, `ownPrivileges` = those less `%Ens_Portal:USE`, no actions, three suggested prompts, a table, context fields, a `toolIdentifier`, and `classicPage`:
  - `InteropMonitorList`: route `interoperability/monitor`, `sideBarPosition` 5, `list`; refreshes at `[5,10,30,60]`, default off; entity `production-item`, composite `[Production, Name]`; `rowTarget` `{route: interoperability/productions/items/document, field: Item}`; `EnsPortal.ProductionMonitor`; `interop.monitor`.
  - `InteropQueueList`: `interoperability/queues`, `sideBarPosition` 6, `list`, refreshes as the monitor; entity `interop-queue`, single (`Name`); `EnsPortal.Queues`; `interop.queues`.
  - `InteropQueueMessageList`: `interoperability/queues/messages`, `sideBarPosition` 0, `list`, `parentScope` `interoperability/queues`, criterion `queue` (text, 256, with a hint); entity `interop-message`, single (`MessageId`); `EnsPortal.Queues`; `interop.queuemessages`.
  - `InteropJobList`: `interoperability/jobs`, `sideBarPosition` 7, `list`, refreshes as the monitor; entity `interop-job`, single (`Job`); `rowTarget` `{route: os-management/processes/details, field: Job, unless: Dead}`; `EnsPortal.Jobs`; `interop.jobs`.
  - The tabs. Each is `detail`, `sideBarPosition` 0, `parentScope` `interoperability/productions/items`, criterion `item` as Item settings declares it (text, 352, the same label and hint), group `interoperability/productions/items/document`, `classicPage` `EnsPortal.ProductionConfig`:

    | Descriptor | Route | Position | Entity | Tool |
    |---|---|---|---|---|
    | `InteropItemStatusTab` | the group's own route | 1 | `production-item`, composite | `interop.itemstatus` |
    | `InteropItemQueueTab` | `…/items/queue` | 3 | `interop-message` | `interop.itemqueue` |
    | `InteropItemLogTab` | `…/items/log` | 4 | `log-entry` | `interop.itemlog` |
    | `InteropItemMessageTab` | `…/items/messages` | 5 | `interop-message` | `interop.itemmessages` |
    | `InteropItemJobTab` | `…/items/jobs` | 6 | `interop-job` | `interop.itemjobs` |

- [x] `InteropItemSettingList.cls` (in place, Epic 20's own): archetype `detail` and `tab` `{group, position 2, labelKey Settings}`. Its route, read, actions and `toolIdentifier` are unchanged.
- [x] Client:
  - `interop-item-setting-list.page.ts`: import `DetailPage` for `ListPage` and render `<app-detail-page />`, so the strip draws over Item settings. Its action registration and dialog are unchanged.
  - `interop-item-add.store.ts` :211: the `changed` event it publishes names its tool (`interop.items.add`), with a leg in `interop-item-add.store.spec.ts`.
  - `strings.ts` (add-only): titles, empty states, prompts, tab labels, the `queue` criterion label, and the column labels no existing value covers. Reuse a key wherever its value exists.
  - Regenerate `screens.generated.ts`.
- [x] `EXPERIENCE.md`, no line inserted above :604:
  - :159 gains " · Production monitor · Queues · Jobs", plus a sentence naming the item tabs in order.
  - :604 gains a Story 20.4 clause with every new literal.
  - :896's roster gains Production monitor, Queues and Jobs after its last name.
  - Then `cd ui && npm run test:tools`.
- [x] `Test/ProductionProbe.cls` (in place): the op's `Hang` logs `$$$LOGINFO("OcuPilot probe message")` before it hangs, so each message leaves one row with the op's `ConfigName`.
- [x] Tests (new). Each class runs one per call and stays under about 500 lines. `InteropHostRead` and `InteropHostGate` each create and remove their own probe: `SetHang` 600 with the production running and three messages sent, then stopped with force and removed in `OnAfterAllTests`.
  - `Test/InteropHostRead.cls`:
    - Each endpoint's rows on the probe: Monitor holds the op and the service and no vendor host; ItemStatus is one row; Queues and QueueItems show two entries with headers; ItemQueue matches them; ItemLog and ItemMessages hold the probe's rows; Jobs and ItemJobs hold the op job with its active message.
    - Each screen's read route and read tool answer the same rows.
    - With the production stopped, Monitor, Jobs and ItemJobs read none, and Status has empty runtime fields.
    - 404 and 409 on the `item` criterion.
    - AC6: snapshot `^Ens.Queue`, `^Ens.ActiveMessage`, `^Ens.JobRequest`, `^IRIS.Temp.EnsJobStatus($namespace)` and the probe's header statuses, run every read, and assert them equal. When Task 0 allows, also with the op job terminated, where Jobs answers it `Dead` and unrepaired.
  - `Test/InteropHostGate.cls` (armed under `OCUPILOT_ALLOW_PRINCIPALS`, reusing `InteropItemGate`'s principals through a parameter):
    - Per endpoint, a principal holding exactly its pairs and `%DB_USER:R` reads it, the SQL reads included, with no SQL grant.
    - Dropping each pair in turn is refused by name, through the port and through the screen read route.
  - `Test/InteropHostDescriptor.cls`:
    - the nine declarations, and Item settings' archetype and tab
    - the group's six members in order, with one criterion
    - `Pairs` for each endpoint and the `ENDPOINTS` roster
    - `ItemQueueName` for a pool-size-0 business process and for an operation
    - `JobRow`'s `Dead` for a pid no process holds
    - each read tool registered; no descriptor declaring an action
- [x] Roster sweep (Rule 30). Each file changed joins the targeted set:
  - `InteropSettingDescriptor` :35 (`detail`)
  - `InteropFloor`: a `MONITORSCREENS`/`MONITORTOOLS` pair for the Monitor role's `InteropMonitorList` and `interop.monitor.read`, and the Operator rosters gain all nine
  - `Navigation` :530-531 (6 → 15)
  - `ReadTool` :93-94 (+9)
  - `Descriptor` :1764 (65 → 68) and its refreshing legs
  - `SurfaceCoverage` :215-220
  - `navigation.test.mjs` :348-353 (list entries) plus four legs:
    - Production items' name cell opens the Status tab
    - a monitor row opens it
    - a setting change still opens Item settings
    - an item change with its tool still opens Production items, not the monitor
  - `screen-mirror.test.mjs` :1382 and :2402
  - `structural-walk.mjs` `SKIP` (the six parent-scoped routes)
  - `ci-throwaway.sh` with `ci.test.mjs`
  - `interop-items` and `interop-item-settings` browser specs: open the item, then the Settings tab
  - Governance, ToolDispatch, GovernanceBaseline and ClassicPageGate's `OWNPAIRS` are unchanged (no key, no write).
- [x] `ui/browser/interop-host-tabs.browser-spec.mjs` (new). `before` and `after` follow `interop-items`', with the probe running, hung, and holding waiting messages. Every step waits for `waitForMapAnswered` and its rows:
  - open the op from Production items: the strip reads Status, Settings, Queue, Log, Messages, Jobs, and each tab shows its rows
  - Production monitor lists the op, and its name opens the Status tab
  - Queues lists the op's queue and opens Queue messages
  - Jobs lists the op job

- [x] **Review patches, pass 1** (a fresh subagent; Rule 18). New legs go in a new class `Test/InteropHostEdges.cls` (under about 500 lines, its own probe created and removed as `InteropHostRead` does, armed in `scripts/ci-throwaway.sh` with `ui/tools/ci.test.mjs`); `InteropHostRead` does not grow:
  - P1: `MakeTroubled` the probe production, then read Monitor, Jobs, ItemJobs and ItemStatus: rows still answered (`LIVEWORDS`), the vendor's job, queue and status globals unchanged across the reads, and, where the operation job's status entry persists unrepaired with `Ens.MonitorService` dead, its Jobs row `Dead` true. Settle the production afterwards. Mutations: `LIVEWORDS` = `Running` goes red; if a dead job is observed, `GatherJobs` on `Ens.Job:Enumerate` goes red.
  - P2: `ItemMessages` for the probe service lists the three headers it sourced. Mutation: the first subselect on `TargetConfigName`.
  - P3: a business process of pool size 0 with entries for two targets in `Ens.Actor`: `ItemQueue` lists only its own. Mutation: invert or delete the `Continue` in `GatherQueueEntries`.
  - P4: `maxRows` 1 on each of the nine answers exactly one row where the probe holds more than one. Mutation: `tTop` always `SQLMAX`, or the `pMax` checks dropped.
  - P5: read by a process whose operating-system zone is not UTC, `TimeCreated` and `TimeLogged` equal the stored UTC value moved by that offset, computed by arithmetic, not by the vendor primitive. Mutation: `LocalStamp` reformats without converting.
  - P6: `ui/browser/interop-host-tabs.browser-spec.mjs`: the Jobs link is read from the operation's own row; the action-trigger count is taken on Queues as well as Queue messages. Mutation: `JobRow` marks only the operation's row dead.
  - P7: `InteropHostGate` calls `FailedPair` and `LegText` through `InteropItemGate` as `InteropSettingGate` does, deleting its copies; its class header states why it keeps its own principals, `ProbeAs` and `Probe`.
  - P8: demonstrate and record: AC1, `InteropItemSettingListPage` hosting `<app-list-page />` (rebuild, redeploy; the Settings strip leg goes red; revert byte for byte, rebuild, redeploy, green again); AC6, `JobRow`'s `Dead` forced false (`TestAJobNoProcessHoldsReadsDead` goes red).
  - P9: replace the false sentence in `InteropHostRead`'s `TestAStoppedProductionAnswersNoRuntimeRow` comment with what Task 0 measured.

**Acceptance Criteria:**

- **AC1 (per-host tabs, integration):** Given the probe production running in USER on `ocupilot-b-ci` with its op hung and messages waiting, when the op is opened from Production items, then the strip shows Status, Settings, Queue, Log, Messages and Jobs in that order, each tab reads through `InteropPort`, and each tab's read tool returns the same rows.
- **AC2 (monitor, integration):** Given that production, when Production monitor renders, then it lists the items the production runs, with the vendor's status, queue count and last activity, through `InteropPort`. A row opens that item's Status tab, the screen refreshes when auto-refresh is turned on, and with no production running it lists none.
- **AC3 (queues and jobs, integration):** Given waiting messages, when Queues, Queue messages and Jobs render, then they read through `InteropPort`: the op's queue with its count, its entries with their headers, and the op's job with its active message, linked to Process details. They offer no abort, abort all, suspend or stop, which are the stated partial.
- **AC4 (gates):** Given a principal lacking one declared pair of a new screen, when it reads the screen or calls its read tool, then it is refused naming that pair before any vendor call. A principal holding exactly the pairs and READ on the namespace's database reads every row, the log and message reads included, with no SQL grant.
- **AC5 (namespace and identity):** Given a namespace that does not report interoperability, or an unknown or ambiguous item, when any new read runs, then it answers 409 `INTEROP.NAMESPACE`, 404 or 409 `INTEROP.ITEM.AMBIGUOUS`.
- **AC6 (reads change nothing):** Given every new read, when it runs, then the vendor's queue, active-message, job-request and job-status globals and the probe's header statuses are unchanged, a dead job included where Task 0 allows.
- **AC7 (navigation):** Given the tab group, when Production items' name cell or a monitor row is opened, then the item's Status tab opens. A setting change's toast still opens Item settings on its item, and an item change's toast still opens Production items.

### Review Findings

Code review 2026-10-11 (full-opus; blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor; diff `00b1beef` plus QA's tree). 34 rows, 17 entries after grouping: high 0, medium 3, low 14. Every medium is patched.

- [x] [Review][Patch] (med, fix-risk low) A runtime read that cannot take the production's runtime lock (a start, stop or update holds it) answered a logged 500, not `Invoke`'s documented 503: `Mapped` now answers `CODERUNTIMELOCK` with `Unavailable`; pinned by `InteropHostEdges.TestABusyRuntimeLockAnswersUnavailable` [InteropPort.cls `Mapped`]
- [x] [Review][Patch] (med, fix-risk low) `ProductionProbe.Release` slept a fixed 3 s for the vendor's dead-job repair; it now waits, 15 s at most, until the ended jobs' rows leave the host monitor [ProductionProbe.cls `Release`]
- [x] [Review][Patch] (med, fix-risk low) The zone leg's local half assumed a UTC instance; its oracle is now the reading process's own offset [InteropHostEdges.cls `TestTheStampsAreConvertedOnceToTheZoneOfTheReader`]
- [x] [Review][Patch] (low) `InteropHostRead`'s header and its snapshot test's mutation note said dead jobs are pinned only on the row builder; they now name `InteropHostEdges`' Troubled leg
- [x] [Review][Patch] (low) `TestAStoppedProductionAnswersNoRuntimeRow`'s comment claimed a Queues leg it never runs; the clause and an unused `Kill` are gone
- [x] [Review][Patch] (low) `GatherJobs`' comment said it keeps `GatherHosts`' hosts; it now says every host `EnumerateHostStatus` answers, the vendor's included
- [x] [Review][Patch] (low) `InteropHostEdges`' header now states the child session's sign-in requirement and the lock holder
- [x] [Review][Patch] (low) The browser spec's header and `TestEachReadToolIsRegistered`'s comment claimed checks they do not make; reworded
- [x] [Review][Patch] (low) `InteropHostRead` read `.Status` on a lookup that can miss (`<INVALID OREF>` in place of a named failure); guarded
- [x] [Review][Patch] (low) `Invoke`'s comment listed no result for the nine reads; it points at `InvokeRuntime`
- [x] [Review][Defer] (low) Log and Messages match the item's name in any production, case-insensitively: by-design, the classic statements do the same; the port's comments now say so - DW-2303
- [x] [Review][Defer] (low) Jobs omits `Ens.MonitorService`, `Ens.Alarm` and `Ens.Alert`, which `EnumerateHostStatus` skips: by-design (Tasks) - DW-2302
- [x] [Review][Defer] (low) A pool-size-0 process's Jobs tab reads no row (inference): by-design, the classic per-host tab reads the same query - DW-2304
- [x] [Review][Defer] (low) A monitor row links the Monitor role to a Status tab it is refused: wontfix-accepted, row links are drawn whatever the target's pairs - DW-2305
- [x] [Review][Defer] (low) The reads' `%ResultSet` loops drop `Next()`'s status: wontfix-theoretical - DW-2306
- [x] [Review][Defer] (low) AC6's snapshot covers the operation's queue and job, not the whole trees: wontfix-accepted, the whole trees move on their own - DW-2307
- [x] [Review][Defer] (low) `InteropHostEdges` is 615 lines: wontfix-accepted until it next grows - DW-2308
- Rejected: the spec's pre-merge counts (the fix edits this spec); a Jobs-tab `rowTarget` (Registry refuses one on `detail`); an orphan `Ens.Actor` entry shown on every pool-size-0 tab (the classic page keeps it as `*Deleted*`); AC2's stopped-production leg as unfalsifiable (a read answering configured items without vendor rows turns it red); clause-level mutation lines for AC1-AC3 (one per AC is the bar, and each has one); AC4's tool-call refusal (InteropFloor pins each role's tool roster, the tool shares the screen's gate); Status's missing `Item` (the matrix names its fields; the composite carries the parent); the gate comments' "before any vendor call" and the monitor's "light" (both hold).

## Spec Change Log

## Review Triage Log

### 2026-10-10 - Review pass

- verdicts: 19 findings - high 0, medium 9, low 8, false 2, maybe-false 0
- findings:
  - `[medium]` `[patch]` Troubled production and the read-never-repairs half of AC6 have no test: `LIVEWORDS` = `Running` alone and `GatherJobs` on `Ens.Job:Enumerate` both stay green - verification-gap, pre-verified (`MakeTroubled` is unused by the new tests; Task 0's 1.28 s repair was measured with `Ens.MonitorService` alive) - fix: a Troubled leg in the new class `InteropHostEdges` (P1). Applied: `InteropHostEdges.TestATroubledProductionStillAnswersItsRowsAndChangesNothing`; in a Troubled production the dead job's entry stays unrepaired (at least 45 s), the reads answer it Dead and change nothing; both mutations red.
  - `[medium]` `[patch]` The Messages tab's sourced-by half is never read: the first subselect can become `TargetConfigName = ?` unseen - verification-gap, pre-verified - fix: read the service's item (P2). Applied: `TestTheServicesMessagesAreThoseItSourced`; the `MESSAGESQL` mutation red.
  - `[medium]` `[patch]` The pool-size-0 target filter in `GatherQueueEntries` has no executed test - verification-gap, pre-verified; the matrix row names it - fix: a pool-size-0 item with entries for two targets (P3). Applied: `TestAPoolSizeZeroItemReadsOnlyItsOwnActorEntries` with two pool-size-0 items and queued `Ens.Actor` entries, all removed; both mutations red.
  - `[medium]` `[patch]` No test pins the row cap on any of the nine endpoints (AD-24, a stated boundary) - verification-gap, pre-verified - fix: `maxRows` 1 on each (P4). Applied: `TestARowCapOfOneAnswersOneRowOnEveryEndpoint`; both mutations red.
  - `[medium]` `[patch]` The UTC-to-local stamp is unobservable in the UTC throwaway; the stamps test compares the port to the same vendor primitive - verification-gap, pre-verified - fix: a leg under a non-zero `$ZTIMEZONE` with arithmetic as the oracle (P5). Applied: `TestTheStampsAreConvertedOnceToTheZoneOfTheReader`, which reads in a child session under `TZ=PST8` (`$ZTIMEZONE` does not move the conversion). It found a real defect: `%EXTERNAL(TimeLogged)` and `%EXTERNAL(TimeCreated)` already convert to the reader's zone, so `LocalStamp` converted twice; `LOGSQL` and `MESSAGESQL` now read the stamps as stored. Both mutations red.
  - `[medium]` `[patch]` The Jobs browser leg takes the link from the first link in the table, not the operation's row - verification-gap, pre-verified - fix: read it from that row's own cell (P6). Applied: the link is read from the operation's row and triggers are counted on Queues; the `JobRow` mutation red.
  - `[low]` `[patch]` Rule 19: AC1's Settings-strip client mutation was not run, and `JobRow`'s `Dead` pin (`TestAJobNoProcessHoldsReadsDead`) has no `mutation:` line; the other listed pins are covered by their AC's demonstrated mutation (one per AC is the bar; AC4's gate test loops every endpoint and pair, so one mutated pair shows the loop discriminates) - closed in the review pass (P8). Applied: both mutations demonstrated and recorded (client rebuilt and redeployed both ways).
  - `[medium]` `[patch]` `InteropHostGate` copies `InteropItemGate`'s `FailedPair` and `LegText` byte for byte, where `InteropSettingGate` calls them through `ITEMGATE` - Rule 31, no stated reason - fix: call them through `ITEMGATE`; its own principals and `ProbeAs`/`Probe` stay, with the reason in its class header (P7). Applied: its copies are deleted, the reason is in the class header, and `InteropItemGate`, `InteropSettingGate` and `InteropHostGate` are green.
  - `[low]` `[patch]` `LiveCurrent` and `QueueOf` read the production state beside `ReadState` with no stated reason - `ReadState` also runs `ProductionNeedsUpdate` with up to a second of retries and answers 404 for a missing production, neither of which a gatherer inside a switched namespace wants; the reason goes in the commit message, no code change. Applied: the reason is in Design Notes and goes in the commit message.
  - `[low]` `[reject]` `InteropHostRead` is 671 lines against the roughly 500 of the spec - the fix is a split, more than a direct correction; the legs the patch pass adds go to a new class so it does not grow.
  - `[low]` `[patch]` A doc comment in `InteropHostRead` says the `LiveCurrent` word-test mutation "shows the check is load-bearing here", which the spec's Task 0 line contradicts (a stopped production leaves the vendor no row) - replace the sentence at its origin (P9). Applied.
  - `[low]` `[patch]` The browser spec's closing assertion says "neither list offers an action" but counts triggers only on Queue messages - count them on Queues too (P6). Applied.
  - `[low]` `[patch]` Intent audit: the browser surface carries the thinnest evidence and the Settings-strip client mutation was not run - same root as the Rule 19 row; closed by P8, which ran the client mutation. Browser specs ran green on a rebuilt, redeployed bundle in this pass.
  - `[low]` `[reject]` Intent audit: the model-facing bounds, `truncated` and AD-60 are untested for these nine - they live in generic, unchanged layers (`Screen/Read.cls`'s interop branch, `Kernel/Agent/Loop.cls` applying `Sanitize` to every tool result, with `TurnSanitize`); the port-level cap is pinned by P4.
  - `[low]` `[reject]` Intent audit: `QUEUESCANMAX` cuts a pool-size-0 scan silently at 10,000 entries - a named bound in the parameter's comment; a flag would add a field to every queue row for a queue that long.
  - `[medium]` `[patch]` Intent audit: dead jobs are covered only at the row builder - same root as the first row (P1).
  - `[medium]` `[patch]` Intent audit: the time zone is not tested - same root as the stamp row (P5).
  - `[false]` `[reject]` Intent audit: the AD edits are not in the diff - commit b98144ee, before the baseline, amended AD-62, AD-29, AD-36, AD-13, AD-43, AD-8 and AD-44 (eight "Story 20.4" mentions in the spine).
  - `[false]` `[reject]` Intent audit: `ProductionProbe.Settle`'s new `Release` reaches other probe classes - it acts only when the stored `HangSeconds` is above 30; the other users set 1 to 13.

## Design Notes

**Governing ADs:** AD-5, AD-7, AD-8, AD-11, AD-13, AD-14, AD-16, AD-19, AD-24, AD-29, AD-36, AD-43, AD-44, AD-60, AD-62, AD-64 (the new screens are adjustable like any other). For the follow-up: AD-10, AD-15, AD-22, AD-34, AD-48, AD-51, AD-53, AD-58, AD-59.

**Measured at this plan on `ocupilot-b-ci`** (USER, the probe created and removed, eight principals created and deleted):

- The reads check nothing of their own. A principal holding `%DB_USER:R` and `%Ens_Portal:U` read:
  - `EnumerateHostStatus`, 8 rows in 0.3 ms, the vendor's `Ens.Actor`, `Ens.ScheduleHandler` and `EnsLib.Background.*` among them
  - `Ens.Queue:Enumerate`, 4 rows (`_SyncCall:<pid>` appears during a synchronous call)
  - `EnumerateItem`, 3 rows
  - `EnumerateJobStatus(op)`, 1 row with `ActiveMessage`; `("")` answers 0
  - the header `%OpenId`
- `%ExecDirect` on `Ens.MessageHeader` and `Ens_Util.Log` answered SQLCODE -99 for that principal and for one holding every read resource. `%ExecDirectNoPriv` answered 4 and 1 rows in 0.1 ms.
- `Ens.Job:Enumerate` with no dead job changed none of `MarkDeadJobs`' seven globals or the log (CRC before and after).

**Decisions:**

- **Reads first.** The vendor offers every action (below), but each needs a design this story should not carry beside nine reads: two act on nothing and leave a latent request, one answers OK for any pid, abort is destructive, and none is audited. The AC sanctions the partial.
- **The item's tabs are a parent-scoped tab group** (AD-5, Story 19.5's mechanism). The group's head must be `<parentScope>/document`. Moving Item settings there would rewrite 20.22's route in two files Epic 18 is changing (`navigation.test.mjs` :349 and :698), so a Status tab is the head, and Item settings is position 2 at its own route.
  - Status is the item's config facts plus the status light the classic configuration page draws per item (`ItemStatuses`, under that page's `%Ens_ProductionConfig:READ`). Queue counts and jobs stay behind their own pairs, on their tabs and on the monitor. The monitor's rows and the items' rows open the same place.
  - Every member is `detail`, as the group rule requires; Item settings' page hosts `DetailPage`, which draws the strip.
  - Classic tab order after Status.
- **No Actions tab.** The classic tab's enable, disable and remove are Production items' row actions (20.3), and Test is 20.6's. The remaining item actions are the second `deferred:` item.
- **Monitor rows are the production's items**, linked by `Item` (`Production||Name`), which `ItemParts` accepts. Vendor hosts (`Ens.Actor`, …) are left out (they appear in Queues and Jobs), so every row links.
  - `Production||Name` is the `item` criterion's second spelling (20.22), carried in a route segment. It is never an entity reference (no proposal or change event carries it), so AD-13 needs no rule for it.
  - It avoids putting U+0001 in a field the read tool hands the model.
- **Entity types.** Monitor and Status use `production-item`. Once a listed list shows that type, a change event without its tool would open the monitor (`screenForEntityType` prefers a listed list). So every item event names its tool, and `ownerListFor` keeps the toast on Production items (pinned in `navigation.test.mjs`).
  - The agent's confirm (`turn.ts` :1451) and the screen action route (`screen-action-handler.ts` :1354, :1373) already name it.
  - The add dialog's store (`interop-item-add.store.ts` :211) does not, and gains it here.
  - The Log tab reuses `log-entry`. Three types are new, so 20.23's change events reach them: `interop-queue`, `interop-message` (20.9's messages, inference) and `interop-job`.
- **Jobs without `Ens.Job:Enumerate`.** Jobs reads `EnumerateJobStatus` per host. A dead job is shown `Dead` and its link withheld (`unless`), never repaired. The classic Jobs page repairs it on every view; OcuPilot's read must not write (AD-7).
- **Auto-refresh.** Production monitor, Queues and Jobs join AD-43's set, default off, as their classic pages refresh (`ProductionMonitor.cls` :211, `Queues.cls` :144, `Jobs.cls` :19). The tabs do not.
- **Pairs.** Each screen declares its classic page's check (`ProductionConfig` `initSecurity` :7824 for the tabs). The Monitor role now opens Production monitor; the Operator role opens all nine.
- **No new error code** (`InteropError.cls` unchanged): absences are `PORT.NOTFOUND`; the item and namespace refusals are 20.3's.
- **Rule 31.**
  - `InvokeRuntime` copies `InvokeItems`' dispatch shape for another row family; the reason is in the Code Map.
  - `GatherHosts`, `GatherQueueItems`, `GatherJobs` and `SqlRows` each serve two endpoints.
  - The item lookup (`ItemParts`, `ItemObject`, the `AMBIGUOUS` count) is reused. `LiveCurrent` and `QueueOf` read the production's state themselves, not through `ReadState`, which also runs the update check with up to a second of retries and answers 404 for a missing production, neither of which a gatherer inside a switched namespace wants.
  - The SQL copies `LogSourcePort.FetchEvents`' form; its reason is in the Code Map.
  - `InteropHostGate` reads a leg and a refusal's failed pair through `InteropItemGate`, as `InteropSettingGate` does, but builds its own principals, `ProbeAs` and `Probe`: the nine reads need a principal missing each single pair and one holding exactly each endpoint's pairs, where that class's six are the item writes'. Item settings' page reuses `DetailPage`. There is no new store or loader.
- **Posture.** None remains. The reads add no write, key or self-protection target: OcuPilot runs no production, so AD-10 gains no arm. `%ExecDirectNoPriv` follows AD-29's owner-reviewed LogSourcePort exception. The actions' posture is answered by the epic's standing rules (follow-up charter).

**Split (`oversized`): reads first.** This spec is the reads. The follow-up, numbered 20.23 by the runner (Rule 5 apply-and-report; the AC names the partial), is the actions. Its charter is from this plan's measurements:

- **Abort one queued message:** `Ens.Queue.AbortItem(queue, priority, index)`.
  - Its own check is `%Ens_Queues:WRITE` (#940 without it). Without WRITE on the namespace's globals database it hits `<PROTECT>`, writing two Protect audit rows.
  - It sets the header Aborted, and a waiting synchronous caller gets an error at once. An unknown entry is an error.
  - Destructive, so its key ships `false`.
- **Abort a whole queue:** `AbortQueue(queue)`, the same check. It leaves the in-progress message alone.
  - Destructive, key `false`. Its fingerprint is the enumerated entries (AD-48's precedent).
- **Abort or suspend a job's message:** `Ens.Job.AbortOperation(pid)` (`%Ens_Jobs:WRITE`) and `SuspendOperation(pid)` (`%Ens_MessageSuspend:USE` alone).
  - Each answers OK for any pid and only sets `^Ens.JobRequest`. That acts only inside a retry loop; measured, it stayed set into the next message.
  - So the port must refuse unless the fresh read shows the job retrying its active message (AD-62 (5)).
  - Abort is destructive; suspend is not (a suspended message is resendable, 20.9).
- **Stop a job:** `Ens.Job.Stop(pid, timeout, force)` (`%Ens_Jobs:WRITE`).
  - It answers OK for any pid in 0.1 ms and logs `Stopping job`. Forced, it took the timeout (10 s), put the active message back on the queue, and left the host `Error` with Update pending; `UpdateProduction` started a new job.
  - So: refuse a pid that is no job of the running production, cap at AD-62 (6)'s 15 s, and let the card say Update follows. Undone by Update, so not destructive.
- **Audit:** no vendor audit row for any of them (AD-15 and AD-53 named gaps). Classic pages are `EnsPortal.Queues`, `EnsPortal.Jobs` and `EnsPortal.ProductionConfig`.

If the runner wants this spec smaller, the second seam moves Queues, Queue messages and Jobs to 20.23. 20.4 then keeps the tab group and the monitor (AC1, AC2), and its Queue and Jobs tabs are AC2's reads for one host.

**Spine drafts (Rule 20; the runner writes them at the spec gate):**

- **AD-62:** "Story 20.4: `InteropPort` gains nine reads (`Monitor`, `ItemStatus`, `Queues`, `QueueItems`, `ItemQueue`, `ItemLog`, `ItemMessages`, `Jobs`, `ItemJobs`), each `LIST` behind its classic page's pair. It reads `Ens.MessageHeader` and `Ens_Util.Log` with `%ExecDirectNoPriv` after its gate. It never calls `Ens.Job:Enumerate`, whose `MarkDeadJobs` writes, nor any queue or job action (measured: the vendor's reads check nothing)."
- **AD-29:** add InteropPort's two tables to `LogSourcePort`'s no-SQL-grant paragraph.
- **AD-36:** the parent-scoped `interop` lists gain Queue messages (`queue`) and the item's tabs (`item`).
- **AD-13:** `interop-queue` (the queue's name), `interop-message` (the header id) and `interop-job` (the pid), each kept exactly.
- **AD-43:** the roster gains Production monitor, Queues and Jobs, default off.
- **AD-8:** the 20.14 sentence on `%EnsRole_Monitor` is corrected at origin: it now also opens Production monitor and its read tool.
- **AD-44:** the new screens declare `EnsPortal.ProductionMonitor`, `EnsPortal.Queues`, `EnsPortal.Jobs` and `EnsPortal.ProductionConfig`.

**Integration ACs, Consumes, Consumed-by:**

- Integration: AC1-AC4 run against a real instance: `ocupilot-b-ci`, the screen read route, the read tool, and the browser spec.
- Consumes: 20.3 (Production items, the `production-item` id, `ItemObject`), 20.22 (Item settings and `ItemParts`' two spellings), 20.2 (`ReadState`), 19.5 (the parent-scoped tab group), 6.10 and 16.12 (`rowTarget` and `unless`), OS management's Process details, and `Test/ProductionProbe`.
- Consumed-by: 20.23 (the actions on Queue messages, the Queue tab and Jobs), 20.9 (`interop-message`, inference), 20.12 (Investigate from a host or log row, inference).

**Ledger inbox (Rule 17):** empty.

**Contended files (Rule 11).** Epic 23 is clean. Epic 18 is committed ahead on:

- `EntityType.cls` `TYPES`, `Descriptor.cls`:1764, `ReadTool.cls` :93-94 and `SurfaceCoverage.cls`
- `strings.ts`, `screens.generated.ts`, `screen-mirror.test.mjs`, `navigation.test.mjs`
- `EXPERIENCE.md` :167/:357, and others this story does not touch

This story's edits there are appended roster rows and list entries, plus the count pins that move with them, which Epic 18 moves too. The forward merge sums them (Rule 22). No line Epic 18 changed is edited. The in-place edits are Epic 20's own: the port, `InteropItemSettingList`, its page, `interop-item-add.store.ts`, `InteropSettingDescriptor`, `Navigation.cls`, `InteropFloor`, `ProductionProbe` and two browser specs.

**Strings and weight.** About 75 literals: nine titles, empty states and three prompts each, five tab labels, the `queue` criterion, and about ten column labels. That takes the table from 3036 to about 3110, under 3400. The client weight is about 30 kB (nine mirrored descriptors and the strings; inference) on 3,221,633 bytes, under 3326 kB. Implement measures and states it.

## Verification

**Shared surfaces:**

- entity types: 65 → 68, from `node tools/screen-mirror.mjs --check`
- the Interoperability side bar (4 → 7 listed) and the navigation count
- Production items' name cell, now the Status tab
- Item settings' archetype and tab
- the interop endpoint roster and the read-tool roster
- the `InteropFloor` rosters, and the area verdict for the Monitor role
- AD-43's auto-refresh roster, and the Fixed-strings table
- the probe operation's log line
- the item add's change event, which now names its tool
- the rosters of governance keys disabled by default (Governance, ToolDispatch, GovernanceBaseline, ClassicPageGate's `OWNPAIRS`): unchanged

*Existing tests that assert a surface this story changes are updated in this story, and every test the story adds or changes passes on a freshly built instance and in either order.*

**Setup (slot B):**

- `rsync -a --checksum --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-20/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`
- then, in `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`, `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)`
- Before a browser run: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`.
- Never the dev instance `ocupilot-slot-b`.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one class per call, each read from `%UnitTest_Result`:
  - new: `InteropHostRead`, `InteropHostGate`, `InteropHostDescriptor`, `InteropHostEdges`
  - changed or consuming: `InteropSettingDescriptor`, `InteropSettingControl`, `InteropItemControl`, `InteropControl`, `InteropFloor`, `InteropFloorTurn`, `Navigation`, `ReadTool`, `Descriptor`, `SurfaceCoverage`
- `(loop)` `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/<file>`, one file per call: `interop-host-tabs.browser-spec.mjs`, `interop-items.browser-spec.mjs`, `interop-item-settings.browser-spec.mjs`, `a11y-structural-invariants.browser-spec.mjs` (DW-1337, both themes).
- `(loop)` Expected clean: `cd ui && npm run test:tools && npm run test:components`; `uv run scripts/check-objectscript.py <changed .cls>`; `bash scripts/lint-docs.sh`.
- `(once, before dev_complete, runner-side in foreground batches)`, in order:
  1. the full ObjectScript sweep on `ocupilot-b-ci`, one class at a time
  2. `cd ui && npm test && npm run build`, under 3326 kB
  3. `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`
- `(CI)` The full browser suite.

**Planned pinning mutations (Rule 19):**

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | Drop `InteropItemQueueTab`'s `tab` | `InteropHostDescriptor`'s group leg; the browser strip leg |
| AC1 | `SqlRows` drops the `ConfigName` bind (all rows) | `InteropHostRead`'s log leg |
| AC1 | Item settings' page keeps `<app-list-page />` | the browser strip leg on Settings |
| AC2 | `GatherHosts` keeps vendor hosts | `InteropHostRead`'s monitor leg |
| AC2 | Drop the running-or-troubled check | the stopped-production leg |
| AC2 | Drop the monitor's `rowTarget` | `navigation.test.mjs`' monitor leg; the browser monitor leg |
| AC3 | `ItemQueueName` ignores pool size 0 | `InteropHostDescriptor`'s queue-name leg |
| AC3 | `GatherQueueItems` skips the header join | `InteropHostRead`'s queue legs |
| AC4 | Drop each endpoint's own pair in turn | that pair's `InteropHostGate` leg |
| AC4 | `SqlRows` uses `%ExecDirect` | `InteropHostGate`'s SQL legs (-99) |
| AC5 | `InvokeRuntime` skips the `AMBIGUOUS` count | `InteropHostRead`'s identity leg |
| AC6 | `GatherJobs` reads `Ens.Job:Enumerate` | the dead-job leg (with a dead job, as Task 0 allows) |
| AC6 | `GatherQueueItems` calls `Ens.Queue.AbortItem` on each entry it reads | the snapshot leg (the pin under Task 0's fallback) |
| AC7 | `InteropItemStatusTab` moved off `…/document` | `navigation.test.mjs`' name-cell leg |
| AC7 | The add store's event drops its `tool` | `interop-item-add.store.spec.ts`' tool leg; `navigation.test.mjs`' item-change leg |

**Task 0 (ocupilot-b-ci, 2026-10-10; implement stage; the five open cells):**

- Task 0: `NormalizePage` answers `EnsPortal.ProductionMonitor`, `EnsPortal.Queues` and `EnsPortal.Jobs` exactly as typed. Each is a compiled class with RESOURCE `%Ens_Dashboard:USE`, `%Ens_Queues:READ` and `%Ens_Jobs:READ`, which the descriptors' `classicPage` and pairs carry.
- Task 0: with the probe production stopped, `EnumerateHostStatus` and `EnumerateJobStatus(OcuPilotProbeOp)` answered 0 rows and `^IRIS.Temp.EnsJobStatus("USER","sys")` held no job; a production stopped with force (a hung operation) left the same. The vendor's monitor holds no stale row, so the running-or-troubled word test is defense in depth: the clause that is load-bearing in `LiveCurrent` is the production-identity one, pinned by an item of the probe's second production (`TestAnItemOfAnotherProductionReadsNoRuntimeRow`).
- Task 0: after `$System.Process.Terminate` of the operation job (pid 27851), the process was gone in 0.26 s and its `^IRIS.Temp.EnsJobStatus("USER","sys",<pid>)` entry was moved to a ghost id (`Z<pid>_<n>`) and its active message put back on the queue in 1.28 s, with no OcuPilot call (`Ens.MonitorService` logged `DeadJobAlert`). That is far under 30 s, so AC6 pins a live production and `Dead` through `JobRow` with a pid no process holds and with a ghost id (`InteropHostDescriptor`), not a killed job.
- Task 0: a stamp's conversion follows the reading process's operating-system zone, not `$ZTIMEZONE`. Setting `$ZTIMEZONE` to 480 moved `$H` and left `Ens.DataType.UTC`'s conversion (`$$$timeUTCtoLocal`, which is also the display conversion `%EXTERNAL(TimeCreated)` and `%EXTERNAL(TimeLogged)` apply) and `LogSourcePort.LocalFromUtc` unchanged, while a session started with `TZ=PST8` (`$ZTIMEZONE` 480) read a log row stored `00:10:42.615` as `16:10:42.615` through `%EXTERNAL`. The container's zone is UTC, so a read there cannot tell local from UTC. The port reads the stamps as stored and converts once with `LocalStamp` (what the classic Queue tab does), writing the log readers' form, `YYYY-MM-DDTHH:MM:SS.mmm`; `InteropHostEdges` checks the conversion in a child session started with `TZ=PST8`, against arithmetic on the stored value.
- Task 0: in a Troubled production (the probe armed, then `MakeTroubled`: state 4, every `_Ensemble` job ended), the operation job's `^IRIS.Temp.EnsJobStatus("USER","sys",<pid>)` entry (pid 52227) stayed unrepaired for at least 45 s with no OcuPilot call, holding its active message 261 beside the queue's two entries, because nothing ran `Ens.MonitorService`. Monitor, Jobs, ItemJobs and ItemStatus answered rows (`Status` OK, `AdapterState` n/a), the Jobs and ItemJobs rows read `Dead` true, and `Settle` recovered the production afterwards. So AC6's dead job is pinned in a Troubled production (`InteropHostEdges`), and the quick repair measured above needs a running monitor service.
- Task 0: a Monitor-role principal (`monitor` in `InteropFloor`: `%EnsRole_Monitor` plus READ on the code database) opens Production monitor (the screen read answers 200 and the area, screen and `interop.monitor.read` rosters hold them) and is refused an item's Status tab naming `%Ens_ProductionConfig:READ`; the `%Ens_Portal` holder is refused Production monitor naming `%Ens_Dashboard:USE` (`InteropFloor.TestTheInteroperabilityReadsFollowTheirOwnPairs`, run 131).

**Demonstrated mutations (Rule 19; each applied, observed red, reverted byte-identical and reloaded; implement stage):**

- mutation: AC1, `InteropItemQueueTab`'s `tab` dropped -> `InteropHostDescriptor.TestTheItemTabsFormOneGroupInOrder` ("position 3 is Queue") and `TestTheNineDeclarationsRegister` went red.
- mutation: AC1, the Log statement's `ConfigName = ?` filter replaced by `? IS NOT NULL` -> `InteropHostRead.TestEachEndpointAnswersTheProbesRows` ("the log holds no row of another item or of the production") went red.
- mutation: AC2, `GatherHosts` no longer leaves out the hosts the production does not configure -> `InteropHostRead.TestEachEndpointAnswersTheProbesRows` (the monitor leg) went red.
- mutation: AC2, `LiveCurrent` without its `pProduction '= tCurrent` clause -> `InteropHostRead.TestAnItemOfAnotherProductionReadsNoRuntimeRow` (status and jobs legs) went red. The planned "drop the running-or-troubled check -> the stopped-production leg" is not falsifiable alone (Task 0: a stopped production leaves the vendor no row), so the identity clause carries the AC.
- mutation: AC2, the monitor's `rowTarget` set null in the mirror -> `navigation.test.mjs` "Story 20.4: the Status tab is what an item row opens" (monitor leg) went red.
- mutation: AC3, `ItemQueueName` ignoring pool size 0 -> `InteropHostDescriptor.TestAnItemsQueueFollowsItsKindAndPoolSize` went red.
- mutation: AC3, `GatherQueueEntries` answering empty header fields -> `InteropHostRead.TestEachEndpointAnswersTheProbesRows` ("each carries its header") and `TestTheStampsAreTheInstancesLocalClockTime` went red.
- mutation: AC4, `%Ens_Queues:READ` dropped from `QUEUEPAIRS` -> `InteropHostGate.TestAPrincipalHoldingExactlyAnEndpointsPairsReadsItsRows` and the through-the-port leg went red for Queues and QueueItems.
- mutation: AC4, `SqlRows` using `%ExecDirect` -> `InteropHostGate` ItemLog and ItemMessages legs (rows 0, the screens' 500) went red.
- mutation: AC5, `ResolveItem` without its `AMBIGUOUS` count -> `InteropHostRead.TestAnInputThatNamesNoReadIsRefusedByName` went red for five item endpoints.
- mutation: AC6, `GatherQueueEntries` calling `Ens.Queue.AbortItem` on each entry it reads -> `InteropHostRead.TestNoReadChangesWhatTheVendorKeeps` (and the two row legs) went red. The `Ens.Job:Enumerate` mutation is read by the Troubled leg below, where nothing repairs the dead job.
- mutation: AC7, `documentScreenFor` answering null for Production items -> `navigation.test.mjs` "Story 20.4: the Status tab is what an item row opens" (name-cell leg) went red.
- mutation: AC7, the add store's event without `tool` -> `interop-item-add.store.spec.ts` "names the add tool on the event it publishes" went red.
- mutation: P1, `LIVEWORDS` = `Running` -> `InteropHostEdges.TestATroubledProductionStillAnswersItsRowsAndChangesNothing` went red (the Monitor, ItemStatus, Jobs and ItemJobs legs).
- mutation: P1 and AC6, `GatherJobs` running `Ens.Job:Enumerate` -> the same test went red (the job reads Dead with its message gone, the snapshot differs, and the queue holds one message fewer).
- mutation: P2, the first subselect of `MESSAGESQL` on `TargetConfigName` -> `InteropHostEdges.TestTheServicesMessagesAreThoseItSourced` went red.
- mutation: P3, the target `Continue` in `GatherQueueEntries` deleted, then inverted -> `InteropHostEdges.TestAPoolSizeZeroItemReadsOnlyItsOwnActorEntries` went red each time, and left no entry or header behind.
- mutation: P4, `tTop` always `SQLMAX` -> `InteropHostEdges.TestARowCapOfOneAnswersOneRowOnEveryEndpoint` went red for ItemLog and ItemMessages; the `pMax` tests dropped from the host, job, queue and entry gatherers -> the same test went red for Monitor, Queues, QueueItems, ItemQueue and Jobs.
- mutation: P5, `LocalStamp` reformatting without converting -> `InteropHostEdges.TestTheStampsAreConvertedOnceToTheZoneOfTheReader` went red for the header, the queue entry and the log row. `%EXTERNAL` around the log and message stamps, as first written, converted them twice: the same test went red for the header and the log row, the queue entry staying green.
- mutation: P6, `JobRow` marking only the operation's row dead -> `interop-host-tabs.browser-spec.mjs` "the operation's own row links to Process details" went red.
- mutation: P8 and AC1, `InteropItemSettingListPage` hosting `<app-list-page />` again (rebuilt and redeployed) -> `interop-host-tabs.browser-spec.mjs` "the Settings tab carries the same strip" went red with an empty strip; reverted byte for byte (the bundle hash `main-QGQHPIB6` is the unmutated build's), rebuilt, redeployed and green.
- mutation: P8 and AC6, `JobRow`'s `Dead` forced false -> `InteropHostDescriptor.TestAJobNoProcessHoldsReadsDead` went red, and so did `InteropHostEdges.TestATroubledProductionStillAnswersItsRowsAndChangesNothing`.

**QA stage (2026-10-11, slot B; each mutation applied to the throwaway's copy of the source, reloaded, run, reverted byte-identical and reloaded, so the worktree never held one):**

- (QA) `src/OcuPilot/Test/InteropHostEdges.cls` (modified, 548 lines, 7 tests): `TestEachRowCarriesTheOrderAndFiguresTheVendorGives` and `TestAHostWithNoQueueOrJobAnswersNoRow`, with the helpers `VendorRow` and `Clock`. No new class: it would need the arming roster and the shard timings, which this stage does not edit.
- (QA) `src/OcuPilot/Test/InteropHostRead.cls` (modified): `TestTheStampsAreTheInstancesLocalClockTime` reads the stored columns raw. Its oracle applied the vendor's conversion to `%EXTERNAL(...)`, which already converts; read by a process under `TZ=PST8` it expected 13:23:12.126 where the port, converting once, answers 21:23:12.126 for a stamp stored 05:23:12.126.
- mutation: AC1, `InteropItemQueueTab`'s `tab` dropped -> `InteropHostDescriptor.TestTheItemTabsFormOneGroupInOrder` and `TestTheNineDeclarationsRegister` went red.
- mutation: AC2, `GatherHosts` no longer leaving out the hosts the production does not configure -> `InteropHostRead.TestEachEndpointAnswersTheProbesRows` went red.
- AC2 equivalence: `LiveCurrent` answering the current production whatever its state leaves `InteropHostRead` and `InteropHostEdges` green. Measured: a production stopped with force with messages queued reads state 3 (Suspended) with `EnumerateHostStatus` and `EnumerateJobStatus` answering no row, and a Stopped one names no production, so the word test guards nothing observable on this vendor. The identity-clause mutation above carries AC2.
- mutation: AC3, `ItemQueueName` ignoring pool size 0 -> `InteropHostDescriptor.TestAnItemsQueueFollowsItsKindAndPoolSize` went red.
- mutation: AC4, `JOBPAIRS` without `%Ens_Jobs:READ` -> `InteropHostGate.TestEachMissingPairIsRefusedByNameThroughThePort` and `TestAPrincipalHoldingExactlyAnEndpointsPairsReadsItsRows` went red.
- mutation: AC5, `ResolveItem` without its ambiguity refusal -> `InteropHostRead.TestAnInputThatNamesNoReadIsRefusedByName` went red.
- mutation: AC6, `GatherQueueEntries` calling `Ens.Queue.AbortItem` on each entry it reads -> `InteropHostRead.TestNoReadChangesWhatTheVendorKeeps` ("no read changed the queue ...") went red, with two row legs.
- mutation: AC7, `documentScreenFor` answering null for Production items -> `navigation.test.mjs` "Story 20.4: the Status tab is what an item row opens" ("the Production items name cell opens the Status tab") went red; reverted with `git checkout`.
- mutation: `LOGSQL` ordered by `ID` ascending -> `InteropHostEdges.TestEachRowCarriesTheOrderAndFiguresTheVendorGives` ("the log is newest first", "its newest line ...") went red; `InteropHostRead` stayed green, so the Log tab's order had no pin.
- mutation: `QueueEntryRow` answering the index as the priority -> the same test ("each is listed under the priority and index the vendor's queue gives it") went red; `InteropHostRead` stayed green.
- mutation: `HostRow` answering `Count` from the elapsed-time column -> the same test's two monitor legs went red.
- mutation: `ReadItemStatus` copying `Status` and `LastActivity` but not `AdapterState` -> "the item's status carries the monitor's light" went red.
- mutation: `JobRow` answering the adapter state as the status -> "the operation's job row is the vendor's" went red.
- mutation: `ListQueues` reading `Created` from the count column -> "the operation's queue row is the vendor's" went red.
- mutation: `ListQueueEntries` answering 404 for an empty queue -> `InteropHostEdges.TestAHostWithNoQueueOrJobAnswersNoRow` (the service's queue and the missing queue) went red; every other test stayed green.
- mutation: `LocalStamp` reformatting without converting, `InteropHostRead` run under `TZ=PST8` -> `TestTheStampsAreTheInstancesLocalClockTime` went red on its three stamp legs. Before the oracle change the same run was red with `LocalStamp` correct.
- Final tree, each class run alone: `InteropHostEdges` 7, `InteropHostRead` 7, `InteropHostGate` 3, `InteropHostDescriptor` 8 (runs 610-613), `interop-host-tabs.browser-spec.mjs` 4 of 4.

**Code review (2026-10-11, slot B, applied to the throwaway's copy only, reverted byte-identical and reloaded):**

- mutation: the runtime-lock test dropped from `InteropPort.Mapped` -> `InteropHostEdges.TestABusyRuntimeLockAnswersUnavailable` went red (run 615); green again on the reverted tree (run 616).
- After the review patches, each class run alone: `InteropHostEdges` 8, `InteropHostRead` 7, `InteropHostGate` 3, `InteropHostDescriptor` 8, `InteropControl` 11, `InteropItemControl` 6, `InteropSettingControl` 7 (runs 616-622); `interop-host-tabs.browser-spec.mjs` 4 of 4; `npm run test:tools` 1907.

## Auto Run Result

Status: done
Blocking condition: none

**Plan summary.** Shape chosen from measurement: reads first, with the actions as the AC's stated partial. Measured on `ocupilot-b-ci`, each action is a vendor class method with its own check and no audit row. `AbortOperation`, `SuspendOperation` and `Stop` answer OK on an idle or unknown target, so the actions need their own design, and Design Notes › Split charters them as 20.23.

This spec ships nine read screens through `InteropPort`:

- the item's parent-scoped tab group (Status, Settings, Queue, Log, Messages, Jobs; Item settings joins it at position 2)
- Production monitor, Queues with Queue messages, and Jobs

It adds no write and no governance key, and no posture question remains. Flagged `oversized` and `multiple-goals`; a second seam is named in Design Notes. Spine drafts for AD-62, AD-29, AD-36, AD-13, AD-43, AD-8 and AD-44 are listed for the runner to write at the spec gate.

### Implementation result (2026-10-10, slot B, `ocupilot-b-ci`)

**Summary.** `InteropPort` gains nine `LIST` reads (`Monitor`, `ItemStatus`, `Queues`, `QueueItems`, `ItemQueue`, `ItemLog`, `ItemMessages`, `Jobs`, `ItemJobs`) behind their classic pages' pairs, one dispatcher (`InvokeRuntime`) and shared gatherers (`GatherHosts`, `GatherJobs`, `GatherQueueEntries`, `SqlRows`). The Log and Messages tabs read `Ens_Util.Log` and `Ens.MessageHeader` through `%ExecDirectNoPriv` after the gate, with every value bound. The port never calls `Ens.Job:Enumerate` or any queue or job action and writes nothing. Nine screens ship with derived read tools: Production monitor, Queues, Queue messages, Jobs, and the item's Status, Queue, Log, Messages and Jobs tabs; Item settings becomes the group's second tab. Three entity types are new (65 to 68). The add store's change event names `interop.items.add`. No write, no governance key.

**Files changed.**

- `src/OcuPilot/Port/InteropPort.cls`: the nine endpoints, pair sets, dispatcher, gatherers and row builders.
- `src/OcuPilot/Kernel/EntityType.cls`: `interop-queue`, `interop-message`, `interop-job`.
- `src/OcuPilot/Screen/Descriptor/`: nine new descriptors (`InteropMonitorList`, `InteropQueueList`, `InteropQueueMessageList`, `InteropJobList`, `InteropItemStatusTab`, `InteropItemQueueTab`, `InteropItemLogTab`, `InteropItemMessageTab`, `InteropItemJobTab`); `InteropItemSettingList` is now a `detail` tab at position 2.
- `src/OcuPilot/Test/`: new `InteropHostRead`, `InteropHostGate`, `InteropHostDescriptor`, `InteropHostEdges`; `ProductionProbe` logs a line per message and gains `Release`; roster updates in `Descriptor`, `InteropDescriptor`, `InteropFloor`, `InteropSettingDescriptor`, `Navigation`, `ReadTool`, `SurfaceCoverage`, `ToolRoundTrip`.
- `scripts/ci-throwaway.sh`: arming lines for the new classes.
- `ui/`: Item settings' page hosts `DetailPage`; `interop-item-add.store.ts` names its tool; 58 strings; regenerated `screens.generated.ts`; new `interop-host-tabs.browser-spec.mjs`; `interop-item-settings` browser spec, `structural-walk.mjs`, `navigation.test.mjs`, `screen-mirror.test.mjs` and two component specs updated.
- `EXPERIENCE.md`: the side-bar sentence, the Fixed-strings clause and the auto-refresh roster, edited in place.

**Review (one pass; layers verification-gap and intent-alignment).** 19 findings: high 0, medium 9, low 8, false 2. Patches applied: the Troubled and dead-job leg, the sourced-by Messages leg, the pool-size-0 target leg, the row-cap leg, the zone leg, the Jobs link scoping, `InteropHostGate` reusing `InteropItemGate`'s `FailedPair` and `LegText`, the two stale comments, and the two missing mutations. The zone leg found a real defect, fixed in the port: `%EXTERNAL` already converts a stamp to the reader's zone, so `LocalStamp` converted twice; the Log and Messages statements now read the stamps as stored. Deferred: none. Rejected, with the reason in the Review Triage Log: `InteropHostRead` at 671 lines (the legs added go to `InteropHostEdges`), model-facing bounds and sanitizing (generic layers, unchanged), `QUEUESCANMAX` cutting silently (a named bound), the spine edits (commit b98144ee), `Settle`'s `Release` (acts only above a 30 s hang).

**Follow-up review: recommended (`true`).** Seven medium entries were patched. The unverified risk: the patch pass (`InteropHostEdges`, the `InteropHostGate` refactor and the port's stamp change) was written after the review layers read the diff and has had no independent read, and the stamp conversion shows only under a non-UTC zone, which `InteropHostEdges` reaches with a child session under `TZ=PST8`.

**Task 0 cells.**

- `NormalizePage` spells `EnsPortal.ProductionMonitor`, `EnsPortal.Queues` and `EnsPortal.Jobs` as written (resources `%Ens_Dashboard:USE`, `%Ens_Queues:READ`, `%Ens_Jobs:READ`).
- A stopped production leaves `EnumerateHostStatus` and `EnumerateJobStatus(op)` with 0 rows, forced stop included.
- A terminated operation job's status entry was repaired in 1.28 s with the monitor service alive; in a Troubled production it stayed unrepaired for at least 45 s, so AC6 pins a dead job there (`InteropHostEdges`) and `JobRow` for a pid no process holds.
- `%EXTERNAL(TimeCreated)` and `%EXTERNAL(TimeLogged)` convert to the reader's operating-system zone; the port reads the stamps as stored and converts once.
- A Monitor-role principal opens Production monitor and is refused an item's Status tab naming `%Ens_ProductionConfig:READ`.

**Verification (final tree, on the freshly synced `ocupilot-b-ci`).**

- ObjectScript classes, each run alone, every test passing: `InteropHostEdges` 7, `InteropHostRead` 7, `InteropHostGate` 3, `InteropHostDescriptor` 8, `InteropSettingDescriptor` 12, `InteropSettingControl` 7, `InteropItemControl` 6, `InteropControl` 11, `InteropFloor` 7, `InteropFloorTurn` 1, `Navigation` 14, `ReadTool` 28, `Descriptor` 60, `SurfaceCoverage` 4, `InteropItemGate` 5, `InteropSettingGate` 5, `InteropDescriptor` 12, `ToolRoundTrip` 2 (runs 171 to 188).
- `uv run scripts/check-objectscript.py`: 0 problems over 1873 files. `bash scripts/lint-docs.sh`: 0 issues, 0 prose problems. `npm run test:tools`: 1907 pass. `npm run test:components`: 220 files, 2800 tests pass. `node tools/screen-mirror.mjs --check`: 170 descriptors, 11 areas, 68 entity types.
- Browser specs, one per call on the rebuilt, redeployed bundle: `interop-host-tabs` 4 of 4, `interop-items` 3 of 3, `interop-item-settings` 3 of 3, `a11y-structural-invariants` 13 of 13 on the first and the third run. Two runs between them failed on screens this story does not touch: one visit of `security/auditing/user-events` did not settle within 20 s, and one run failed before measuring, cause not captured.
- Bundle initial total 3,245,971 bytes (`main` 3,040,500 and `styles` 205,471) under `maximumWarning` 3326kB; `angular.json` unchanged.
- Mutations demonstrated, 22 `mutation:` lines in `## Verification`: AC1 (two, plus the Settings-strip client mutation), AC2 (three), AC3 (two), AC4 (two), AC5, AC6 (three, `Ens.Job:Enumerate` and `JobRow` among them), AC7 (two), and P1 to P6.
- The full ObjectScript sweep, `npm test` and `smoke.sh` are left to the runner, as is the full browser suite (CI).

**Residual risks.** `QUEUESCANMAX` (10,000) stops a pool-size-0 scan silently. The zone leg needs `%System_CallOut:USE` and a child IRIS session in the container. The two `a11y-structural-invariants` failures above were not diagnosed. The Rule 31 copies (`InvokeRuntime` beside `InvokeItems`; `SqlRows` beside `LogSourcePort.FetchEvents`; `InteropHostGate`'s own principals, `ProbeAs` and `Probe`; `LiveCurrent` and `QueueOf` beside `ReadState`) have their reasons in the Code Map, Design Notes and the commit message.
