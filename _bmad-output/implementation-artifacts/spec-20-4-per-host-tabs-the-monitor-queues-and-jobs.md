---
title: 'Story 20.4: Per-host tabs, the monitor, queues and jobs (reads; the actions are the stated partial)'
type: 'feature'
created: '2026-10-10'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
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

- [ ] **Task 0** (`ocupilot-b-ci` only, through `docker exec`; record each as a `Task 0:` line under Verification):
  - `NormalizePage` spells `EnsPortal.ProductionMonitor`, `EnsPortal.Queues` and `EnsPortal.Jobs` as written.
  - With the probe production stopped, record whether `EnumerateHostStatus` and `EnumerateJobStatus(op)` answer stale rows. The port's running-or-troubled check governs either way.
  - Terminate the running op job's process (`$SYSTEM.Process.Terminate`). Record how long its `^IRIS.Temp.EnsJobStatus` entry stays unrepaired with no OcuPilot call. If it stays at least 30 s, AC6's pin uses a dead job (Tests). Otherwise AC6 pins a live production and `Dead` through `JobRow` with a pid no process holds.
  - Record whether `%EXTERNAL(TimeCreated)` and `%EXTERNAL(TimeLogged)` read local time; the columns show what they read.
  - A Monitor-role principal (`%EnsRole_Monitor` plus `%DB_USER:R`) opens Production monitor, and is refused Status naming `%Ens_ProductionConfig:READ`.
- [ ] `src/OcuPilot/Port/InteropPort.cls` (extend, reads only):
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
- [ ] `Kernel/EntityType.cls` (append): `interop-queue`, `interop-message`, `interop-job`, each kept exactly, with no `IDRULES` row. Its class comment gains one line each.
- [ ] Descriptors (new, `src/OcuPilot/Screen/Descriptor/`). Each declares area `interoperability`, scope `namespace`, privileges = its endpoint's pairs, `ownPrivileges` = those less `%Ens_Portal:USE`, no actions, three suggested prompts, a table, context fields, a `toolIdentifier`, and `classicPage`:
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

- [ ] `InteropItemSettingList.cls` (in place, Epic 20's own): archetype `detail` and `tab` `{group, position 2, labelKey Settings}`. Its route, read, actions and `toolIdentifier` are unchanged.
- [ ] Client:
  - `interop-item-setting-list.page.ts`: import `DetailPage` for `ListPage` and render `<app-detail-page />`, so the strip draws over Item settings. Its action registration and dialog are unchanged.
  - `interop-item-add.store.ts` :211: the `changed` event it publishes names its tool (`interop.items.add`), with a leg in `interop-item-add.store.spec.ts`.
  - `strings.ts` (add-only): titles, empty states, prompts, tab labels, the `queue` criterion label, and the column labels no existing value covers. Reuse a key wherever its value exists.
  - Regenerate `screens.generated.ts`.
- [ ] `EXPERIENCE.md`, no line inserted above :604:
  - :159 gains " · Production monitor · Queues · Jobs", plus a sentence naming the item tabs in order.
  - :604 gains a Story 20.4 clause with every new literal.
  - :896's roster gains Production monitor, Queues and Jobs after its last name.
  - Then `cd ui && npm run test:tools`.
- [ ] `Test/ProductionProbe.cls` (in place): the op's `Hang` logs `$$$LOGINFO("OcuPilot probe message")` before it hangs, so each message leaves one row with the op's `ConfigName`.
- [ ] Tests (new). Each class runs one per call and stays under about 500 lines. `InteropHostRead` and `InteropHostGate` each create and remove their own probe: `SetHang` 600 with the production running and three messages sent, then stopped with force and removed in `OnAfterAllTests`.
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
- [ ] Roster sweep (Rule 30). Each file changed joins the targeted set:
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
- [ ] `ui/browser/interop-host-tabs.browser-spec.mjs` (new). `before` and `after` follow `interop-items`', with the probe running, hung, and holding waiting messages. Every step waits for `waitForMapAnswered` and its rows:
  - open the op from Production items: the strip reads Status, Settings, Queue, Log, Messages, Jobs, and each tab shows its rows
  - Production monitor lists the op, and its name opens the Status tab
  - Queues lists the op's queue and opens Queue messages
  - Jobs lists the op job

**Acceptance Criteria:**

- **AC1 (per-host tabs, integration):** Given the probe production running in USER on `ocupilot-b-ci` with its op hung and messages waiting, when the op is opened from Production items, then the strip shows Status, Settings, Queue, Log, Messages and Jobs in that order, each tab reads through `InteropPort`, and each tab's read tool returns the same rows.
- **AC2 (monitor, integration):** Given that production, when Production monitor renders, then it lists the items the production runs, with the vendor's status, queue count and last activity, through `InteropPort`. A row opens that item's Status tab, the screen refreshes when auto-refresh is turned on, and with no production running it lists none.
- **AC3 (queues and jobs, integration):** Given waiting messages, when Queues, Queue messages and Jobs render, then they read through `InteropPort`: the op's queue with its count, its entries with their headers, and the op's job with its active message, linked to Process details. They offer no abort, abort all, suspend or stop, which are the stated partial.
- **AC4 (gates):** Given a principal lacking one declared pair of a new screen, when it reads the screen or calls its read tool, then it is refused naming that pair before any vendor call. A principal holding exactly the pairs and READ on the namespace's database reads every row, the log and message reads included, with no SQL grant.
- **AC5 (namespace and identity):** Given a namespace that does not report interoperability, or an unknown or ambiguous item, when any new read runs, then it answers 409 `INTEROP.NAMESPACE`, 404 or 409 `INTEROP.ITEM.AMBIGUOUS`.
- **AC6 (reads change nothing):** Given every new read, when it runs, then the vendor's queue, active-message, job-request and job-status globals and the probe's header statuses are unchanged, a dead job included where Task 0 allows.
- **AC7 (navigation):** Given the tab group, when Production items' name cell or a monitor row is opened, then the item's Status tab opens. A setting change's toast still opens Item settings on its item, and an item change's toast still opens Production items.

## Spec Change Log

## Review Triage Log

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
  - The item lookup (`ItemParts`, `ItemObject`, the `AMBIGUOUS` count) and `ReadState` are reused.
  - The SQL copies `LogSourcePort.FetchEvents`' form; its reason is in the Code Map.
  - `InteropHostGate` reuses `InteropItemGate`'s principals. Item settings' page reuses `DetailPage`. There is no new store or loader.
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
  - new: `InteropHostRead`, `InteropHostGate`, `InteropHostDescriptor`
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

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

**Plan summary.** Shape chosen from measurement: reads first, with the actions as the AC's stated partial. Measured on `ocupilot-b-ci`, each action is a vendor class method with its own check and no audit row. `AbortOperation`, `SuspendOperation` and `Stop` answer OK on an idle or unknown target, so the actions need their own design, and Design Notes › Split charters them as 20.23.

This spec ships nine read screens through `InteropPort`:

- the item's parent-scoped tab group (Status, Settings, Queue, Log, Messages, Jobs; Item settings joins it at position 2)
- Production monitor, Queues with Queue messages, and Jobs

It adds no write and no governance key, and no posture question remains. Flagged `oversized` and `multiple-goals`; a second seam is named in Design Notes. Spine drafts for AD-62, AD-29, AD-36, AD-13, AD-43, AD-8 and AD-44 are listed for the runner to write at the spec gate.
