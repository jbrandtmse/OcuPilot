---
title: 'Story 16.10: External language servers'
type: 'feature'
created: '2026-09-28'
status: 'done'
baseline_revision: 'fcbe98eb34edaab5ceb5fcea4f9811e9d0b51a17'
baseline_commit: 'fcbe98eb34edaab5ceb5fcea4f9811e9d0b51a17'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-16-context.md'
warnings: ['oversized', 'multiple-goals']
deferred:
  - summary: 'Start and Stop perform two further classic pages (%CSP.UI.Portal.ExternalLanguageServerStart, %CSP.UI.Portal.ExternalLanguageServerStop with its hidden %CSP.UI.Portal.Dialog.ExternalLanguageServerStopDialog), whose custom resources AD-44 unions through a tool''s CLASSICPAGES; that mechanism is Story 18.14''s and is not on this branch'
    evidence: 'git grep CLASSICPAGES on OCU-1-epic16 and on origin/feature/OCU-1_ocupilot-mvp at a9e7c151 finds nothing; AD-44 names Story 18.14 as the implementer'
    location: 'src/OcuPilot/Screen/Tool/LanguageServerStart.cls, LanguageServerStop.cls'
    severity: 'low'
  - summary: >-
      A start the instance refuses (500 LANGUAGESERVER.START) also raises the shell's generic server-fault banner beside the list's own sentence, until the next call succeeds.
    evidence: |-
      ui/src/app/core/fault.ts classifyFault reads every 5xx other than INSTALL.* as server-fault, and main.ts hands every requestJson outcome to connectivity.note; the spec fixes the status at 500 (inference: not observed in a browser).
    location: >-
      ui/src/app/core/fault.ts:81
    severity: low
---

<intent-contract>

## Intent

**Problem:** OcuPilot has no screen for the instance's external language servers (the Java, .NET, Python and other gateways). A developer has to use the classic portal to see which servers run, to start or stop one, and to read why one failed to start (FR-78).

**Approach:** A new OS management list, `os-management/language-servers`, reads the admin API's `LanguageServer` LIST. A per-row `ACTIVITY` detail call supplies each row's Running state. Start and Stop are action-style row actions (AD-51), each with an agent write tool, and each updates the row in place. A server's name opens its Activity log: a parent-scoped `log-viewer` screen whose declared read lists the `ACTIVITY` answer's `Activity` rows, rendered by the shared log viewer. Create, edit and delete are proposed as Story 16.25 (Design Notes, Q1).

## Boundaries & Constraints

**Always:**

- **Admin API only (AD-2, AD-27).** Reads use `LanguageServer` LIST (`/ext-lang-servers`) and ACTIVITY (`/ext-lang-server/activity`); writes use START and STOP. Every call goes through `AdminPort`, and every type except LIST takes `name` as a query parameter. `ShouldRunAsync()` is 0 for every type, so every call is synchronous (AD-26).
- **Pairs (AD-8, AD-29).** Both screens declare `%Admin_ExternalLanguageServerEdit:USE` and `%DB_IRISSYS:READ`.
  - The first is `ownPrivileges`, because OS management's set (`Area.cls:109`) lacks it.
  - The start and stop tools add no pair.
  - Measured on `ocupilot-ci`: a principal holding exactly these two pairs listed, read the activity, started and stopped a server. Without `%DB_IRISSYS:READ`, every call failed.
- **List read.** It declares:
  - source `{port: admin, endpoint: LanguageServer, type: LIST}`, with `rowGet` `{key: Name, param: name, type: ACTIVITY, fields: [CurrentlyRunning], derived: []}`;
  - fields `Name, Type, Port, CurrentlyRunning`; filter `Name, Type`; sort `Name` ascending; paging `cap`.
  - The `ACTIVITY` detail call sends the vendor's `maxRows` 1, because only `CurrentlyRunning` merges.
  - Table columns: Name (`name`), Type (`text`), Port (`number`), and `CurrentlyRunning` headed "Running" (`status`, so Yes or No with its disc).
- **Activity read.** It declares:
  - source `{port: admin, endpoint: LanguageServer, type: ACTIVITY, rows: "Activity"}`;
  - one criterion, `name` (`text`, `maxLength` 50, which is `Config.Gateways` `Name`'s MAXLEN), filled from the route id as Task history's `taskId` is;
  - fields `ID, DateTime, RecordType, Job, Text`, sorted `ID` descending (the vendor answers newest first);
  - the vendor's `maxRows` at the cap plus one, under Story 16.7's `rows` rule.
- **The shared log viewer renders the Activity log.** A new source kind reads the screen's own declared-read route and maps each row to a line:
  - time: `DateTime` as `YYYY-MM-DDTHH:MM:SS.000`. The vendor's `$ZDT($H,3)` is already instance-local, so no zone conversion happens (Conventions › Dates).
  - pid: `Job`.
  - severity: Debug → `-1`, Info → `0`, Warning → `1`, Error → `2`, following `LogSourcePort.EventSeverity`'s precedent. Any other word shows as itself.
  - text: `Text`.
  - Load newer re-reads the window, and screen context carries the read's rows as answered (AD-24, AD-36).
  - The eight existing sources are unchanged.
- **Opening the Activity log.** The list's name cell opens it at `os-management/language-servers/activity/<name>` through `childListFor`. The Activity log is the list's one parent-scoped child. The click is a person's, so it is not announced (AD-11).
- **Start and Stop (AD-51, AD-52, AdminPort default).**
  - Each tool declares read type `ACTIVITY`. Its `PRECONDITIONFIELD`, `STATEFIELD` and `FINGERPRINTSUBJECT` are each `CurrentlyRunning`, and it sends no body.
  - Start refuses a running server with "This server is already running." Stop refuses a stopped one with "This server is not running." Both refuse in `StateDiff`, before any write.
  - Stop first opens the warning dialog "Stopping it ends every connection to it at once." (primary button).
  - A vendor error on `START` answers 500 `LANGUAGESERVER.START`, "The server did not start. Its activity log records why." The vendor's text goes to the log only (AD-39).
- **Two callers (AD-53).** The same tools serve the screen's action route and the agent's proposal.
  - Governance keys `osmgmt.languageservers.start` and `osmgmt.languageservers.stop` join `Baseline.cls`, enabled (AD-22).
  - The read-back is the action-style "sends no value" (AD-58).
  - The copy-out renders AdminPort's existing `START` and `STOP` routes (AD-59; `AdminRoutes.cls:123-124`).
  - The change event re-fetches the list, and the row is marked "Changed" (AD-14).
- **Entity type `language-server` (AD-13, AD-14).**
  - It joins `EntityType.TYPES` with no `IDRULES` pair, because names are case-sensitive (a lowercase spelling answered 404).
  - It joins `Prohibited`'s covered types with the reviewed-few branch and no arm. Under AD-10 OcuPilot runs no language server, and nothing in `src/` names one.
- **Placement and descriptors.**
  - The list takes OS management side-bar position 9, after Story 16.7's 7 and 8. The Activity log takes position 0, with `parentScope` set to the list's route.
  - Classic pages are `%CSP.UI.Portal.ExternalLanguageServers` and `%CSP.UI.Portal.ExternalLanguageServerActivities`, with no exemption (AD-44).
  - Each screen has three suggested prompts. Copy is taken verbatim from Design Notes.
  - EXPERIENCE.md is edited in place and stays at 993 lines.

**Never:**

- No create, edit or delete, no form page and no field-list derivation (Q1; the proposed 16.25).
- No caller-named path, and the servers' `LogFile` is neither shown nor read (AD-21).
- No `LogSourcePort` source, no new port or API route, and no new AD-27, AD-21 or AD-36 source-kind case.
- No auto-refresh: AD-43's roster is unchanged.
- No test starts, stops or deletes a vendor `%` server, and no probe runs on `ocupilot`.
  - Probes run on `ocupilot-ci` against the test's own uniquely named `OcuPilotProbeELS*` Java servers.
  - Each probe server is stopped before it is removed, because a deleted running server keeps listening (measured).
  - Its activity rows are removed with it.
- Edits to the contended files named in Design Notes are add-only.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Fresh list | `ocupilot-ci` with its 8 vendor servers, all stopped | 8 rows sorted by Name, each with Type, Port and Running "No" | — |
| Start | a stopped probe Java server, Start chosen | Returns in about 11 s. Running reads "Yes" in place with "Changed" | — |
| Start a running server | Start on a row that reads Running "Yes" | Refused "This server is already running."; nothing sent | 400 before any port call |
| Stop | a running probe, Stop, then Proceed in the warning dialog | Running reads "No" in place | Cancel sends nothing |
| Stop a stopped server | Stop on a row that reads "No" | Refused "This server is not running." | 400 before any port call |
| Failed start | a probe whose `JavaHome` names no JVM | "The server did not start. Its activity log records why."; the row stays "No"; the log shows an Error line with the Severe chip | 500 `LANGUAGESERVER.START` |
| Activity log | the server's name chosen | The viewer opens at `.../activity/<name>` with the newest window: time, pid, chip and text. Load newer re-reads it | — |
| Unknown or missing name | `.../activity/NoSuch`, or a read with no `name` | the viewer's error presentation | 404 or 400, from the port |
| Agent stop, state moved | proposal minted while running; the server stopped elsewhere before Confirm | Confirm is refused because the fingerprint moved | — |
| Without the own pair | principal holding `%Admin_Operate:USE`, `%Admin_Manage:USE` and `%DB_IRISSYS:READ` | Only this entry reads unavailable ("Requires %Admin_ExternalLanguageServerEdit:USE"); Processes and the rest stay open | route, reads and tools 403 naming the pair |
| Exactly the screen's pairs | principal holding `%Admin_ExternalLanguageServerEdit:USE` and `%DB_IRISSYS:READ` | list, activity, Start and Stop succeed | — |

</intent-contract>

## Code Map

Anchors are as of `0a3f28dd`. Story 16.7, implemented first, moves lines in `Read.cls` and `Registry.cls` and adds `source.rows`.

**Vendor facts** (measured on `ocupilot-ci`, 2026-09-28):

- Extracted sources are in the session scratchpad `epic-16/`: the endpoint is `Api.Admin.Endpoints.LanguageServer.cls` and the transcript is `els-probe-transcript.txt`.
- `ResourcesOR()` is `%Admin_ExternalLanguageServerEdit` for every type.
- LIST rows are `{Name, Port, Type}`, and the endpoint honours `maxRows` and `filter`.
- ACTIVITY answers `{Activity:[{ID, DateTime, RecordType, Job, Text}], CurrentlyRunning}`, newest first, with `maxRows` honoured.
  - `CurrentlyRunning` is `%Net.Remote.Service.IsGatewayRunning`: it pings only when the port is busy.
  - The rows are kept in `^IRIS.Temp.Gateway.ActivityLogD`.
- START takes 10.7 to 14.7 s and answers 200 `{}`. A start of a running server answers 200 in 0.2 s.
  - A bad `JavaHome` answers 500 #5001 in 0.3 s.
  - A process that dies after launch answers 500 "Failed to detect Gateway" in 5.7 s, and leaves a registration that only a later start and stop clear.
- STOP is a hard `%Shutdown(0)` that answers 200 in 0.7 s, and 200 again on a stopped server.
- Audit: START leaves only `%System/%System/OSCommand` events; STOP leaves none.

**Server** (`src/OcuPilot/`):

- `Port/AdminPort.cls`: `TYPESUFFIXES` :109, which has no `ACTIVITY`; `MUTATINGTYPES` :318 and `BODYLESSTYPES` :334, which have no `LanguageServer` entry; the fault paths `Refuse(500, …)` :848-947; `QUERYPAIRS` :582 is the one-line-table precedent.
- `Screen/Read.cls`: the `rowGet` detail loop :478-, and the executor guard, admin LIST branch and 16.7's `rows` extraction, located by symbol.
- `Screen/Registry.cls`: `ReadProblem` :1013; `READSOURCETYPES` :1820; `ROWGETTYPES` :2078 and `RowGetProblem` :2097; `TABLECOLUMNKINDS` :2199; `AreaCoverageProblem` :803, where `ownPrivileges` is validated.
- `ui/tools/screen-mirror.mjs`: read source types :1892, `ROW_GET_TYPES` :2432, `rowGetProblem` :2456.
- Precedents:
  - `Screen/Descriptor/TaskRunList.cls`: the parent-scoped child reached from the name cell, with a route-id criterion.
  - `LogEventViewer.cls`: a `log-viewer` declaration.
  - `TaskScheduleList.cls:115`: `rowGet` with type `INFO`.
  - `WebSessionList.cls:39`: `ownPrivileges`.
  - `NamespaceList.cls`: the shape of an OS management list.
  - `Screen/Tool/ProcessSuspend.cls`: an action tool at :32-87, with `StateDiff` at :150.
  - `BackgroundTaskPause.cls`: a sibling tool that extends another tool.
- `Api/ScreenAction.cls`: the screen route, which selects the tool through `SCREENACTIONS`.
- `Api/Error.cls`: codes are appended at the end (:4066-4076 is the latest pair).
- `Kernel/EntityType.cls:48` `TYPES`; `Kernel/EntityRef.cls:59` `IDRULES` (no change).
- `Kernel/Proposal/Prohibited.cls`: `COVEREDTYPES` :250, a `TYPE*` parameter near :371, the reviewed-few branch :982-985, and `UncoveredWriteTools` :1009.
- `Kernel/Governance/Baseline.cls`: append after :103.

**Client** (`ui/src/app/`):

- `areas/logs/log-viewer.store.ts`: `LogViewerSource` :12-27, `entriesOf` :83-100, the entries read :354-360, and the reset key `tailPath` :218-229.
- `areas/logs/log-viewer.page.ts`: `SOURCES` :82-91, the source chosen from `screenForUrl` :348-352, `publishRows` :446-453.
- `areas/logs/log-line.ts` `SEVERITY_WORDS` :37; `core/entity-id.ts`, whose decode is called once (AD-13).
- `core/navigation.ts:254` `childListFor`, which skips only the `detail` archetype.
- `core/table-model.ts:86` `cellView`: in a `status` column a boolean reads Yes or No with a disc.
- `core/screen-actions.ts:72` `ACTION_LABELS`, which has no `start` or `stop`; `STRINGS.actionStop` 'Stop' exists at `strings.ts:121`.
- `shell/screen-action-handler.ts`: descriptor constants :82-119 and the roster :55-79; `DESTRUCTIVE_ACTIONS` :206; `WARNING_CONSEQUENCES` :297.
- `core/strings.ts`: append before `} as const` :3514.

**Rosters (add-only; Epic 18 edits them too):**

- `Test/ReadTool.cls` :93-94 and :112.
- `Test/SurfaceCoverage.cls`: screens to :131, tools to :215.
- `Test/Descriptor.cls`: `ReadShapes` :67-, the entity-type count :1706, area rows :1844 and :1937.
- `Test/Navigation.cls`: OS management count and order :338-339.
- `Test/Wire.cls:700`, and `Test/WireSecurityRead.cls` :549, :556 and :559.
- `Test/ToolWrite.cls:1221` and `Test/PortFixture.cls:21`: `MUTATINGTYPES` equality.
- `Test/ToolRoundTrip.cls:42`.
- `Test/Prohibited.cls:218`.
- `Test/RowGetCorpus.cls` and `Test/ReadSourceCorpus.cls`.
- `ui/tools/`: `navigation.test.mjs` :150-165 and :233-250; `navigation-wire.test.mjs` :98-180; `self-protection.test.mjs:354`, the pin precedent; `ci.test.mjs` :1823-1840.
- `shell/rail-wire.spec.ts:88-180`.
- `scripts/ci-throwaway.sh`: the `OCUPILOT_ALLOW_PRINCIPALS` block :243.
- Browser side-bar pins:
  - `ui/browser/namespaces.browser-spec.mjs:376-385` (`slice(0, 6)`, which holds);
  - Story 16.7's `license-usage.browser-spec.mjs`, planned as "8 entries in order" (becomes 9).

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Port/AdminPort.cls`:
  - add `ACTIVITY` to `TYPESUFFIXES`;
  - add `LanguageServer/START` and `LanguageServer/STOP` to `MUTATINGTYPES` and `BODYLESSTYPES`;
  - add a one-line table mapping a vendor error on `LanguageServer/START` to 500 `LANGUAGESERVER.START`. It is add-only, and the vendor text goes to the log only;
  - document the measured facts on the class.
- `src/OcuPilot/Api/Error.cls`: append `LANGUAGESERVERSTART` and `REASONLANGUAGESERVERSTART`.
- `src/OcuPilot/Screen/Registry.cls` and `ui/tools/screen-mirror.mjs`, refusing identically:
  - `ROWGETTYPES` gains `ACTIVITY`;
  - `ACTIVITY` is admitted as a read type only together with `rows`, and only on a `parentScope` screen whose one criterion is the text `name`;
  - add the corpus rows to `Test/RowGetCorpus.cls` and `Test/ReadSourceCorpus.cls`.
- `src/OcuPilot/Screen/Read.cls`:
  - an `ACTIVITY` detail call sends `maxRows` 1 and merges its declared fields;
  - the `rows` read admits `ACTIVITY` and sends the `name` criterion.
- `src/OcuPilot/Screen/Descriptor/LanguageServerList.cls` (new):
  - `route` `os-management/language-servers`, `labelKey` `languageServersLabel`, position 9, `list`, no refresh;
  - pairs and `ownPrivileges` per Boundaries;
  - `entityType` `language-server`, scope `instance`, id `single`;
  - `rowActions` `start` and `stop`;
  - `emptyStateKey` `languageServerListEmpty`, with `table.emptyNextKey` `""` and `emptyAgentKey` `languageServerListEmptyAgent`;
  - aliases `language servers`, `gateways` and `external servers`;
  - `toolIdentifier` `osmgmt.languageservers`; read and table per Boundaries; `context.fields` equal to the read's fields.
- `src/OcuPilot/Screen/Descriptor/LanguageServerActivity.cls` (new):
  - `route` `os-management/language-servers/activity`, `labelKey` `languageServerActivityLabel`, position 0, `log-viewer`, `parentScope` the list;
  - the same pairs; `entityType` `log-entry`, id `single`; no refresh, actions or aliases;
  - read per Boundaries, with filter `DateTime, RecordType, Text`; `context.fields` equal to the read's fields;
  - table columns: `DateTime` (`name`), `RecordType` (`status`), `Job` (`number`), `Text` (`text`), with `emptyNextKey` `tableReadOnlyEmptyNext` and `emptyAgentKey` `""`;
  - `emptyStateKey` `logViewerEmpty`; `toolIdentifier` `osmgmt.languageserveractivity`.
- `src/OcuPilot/Screen/Tool/LanguageServerStart.cls` (new) and `LanguageServerStop.cls` (new, extending Start):
  - tools `osmgmt.languageservers.start` and `.stop`; `WRITETYPE` `START` or `STOP`; `READTYPE` `ACTIVITY`; `SENDSBODY` 0; `SCREENACTIONS` `start` or `stop`;
  - `IdArgument` `Name`, `IdParam` `name`;
  - `CHANGEACTION` stays the default `updated`, because AD-14's action set is closed;
  - `StateDiff` returns one `CurrentlyRunning` row (no → yes, or yes → no), or the refusal parameter `RUNNINGREASON` or `STOPPEDREASON` set to the published sentence.
- `src/OcuPilot/Kernel/EntityType.cls`: append `language-server`.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls`: append the type to `COVEREDTYPES`, add `TYPELANGUAGESERVER`, and add a `ReviewedFewOnly` branch.
- `src/OcuPilot/Kernel/Governance/Baseline.cls`: append the two keys, `true`.
- **New `src/OcuPilot/Test/LanguageServer.cls`** (unarmed; reads vendor servers only; one run at a time). It pins:
  - both descriptors register;
  - the list over the vendor servers answers boolean `Running` values;
  - the `ACTIVITY` detail call sends `maxRows` 1, observed through a port seam;
  - the activity read's rows and fields, and its 400 when `name` is missing;
  - the tools' registration (subject adequacy, pairs equal to the screen's, `SCREENACTIONS`);
  - `StateDiff`'s two refusals and its rows, over fixture fresh reads;
  - `Prohibited` covers the new type.
- **New `src/OcuPilot/Test/LanguageServerWire.cls`**, armed by the existing `OCUPILOT_ALLOW_PRINCIPALS`:
  - it creates a uniquely named probe Java server through `Config.Gateways` in `%SYS`;
  - with the exact-pairs principal: the list, the activity and Start/Stop through `POST /api/ocupilot/screens/:screen/action`, with Running observed each way;
  - the agent path: mint and confirm a start;
  - a stop minted while running, then stopped out of band, is refused at Confirm;
  - a bad `JavaHome` start answers `LANGUAGESERVER.START`;
  - the principal without the own pair gets 403 naming it on every call;
  - teardown stops, deletes, removes the probe's activity rows and removes the principals.
  - Add the class to the `PRINCIPALS` `# classes:` comment and to `ui/tools/ci.test.mjs` (add-only).
- Rosters: add rows for the two screens, two read tools, two write tools and the new entity type in every file under Code Map › Rosters.
- `ui/src/app/areas/logs/log-viewer.store.ts`:
  - a `LogViewerSource` kind `read` holding the declared-read URL;
  - `readRowsOf` maps rows to `LogLine`s per Boundaries, oldest first as drawn, with `raw` equal to `Text`;
  - the rows as answered are kept for publishing, and `truncated` is taken from the answer.
- `ui/src/app/areas/logs/log-viewer.page.ts`:
  - `SOURCES` resolves the Activity log's route to a `read` source. Its URL is `GET /api/ocupilot/screens/osmgmt.languageserveractivity/read` with `name` (the route id, decoded once) and the screen store's max rows;
  - for a `read` source, `publishRows` publishes the read's rows;
  - there is no file choice.
- `ui/src/app/core/screen-actions.ts`: `ACTION_LABELS` gains `start` → `actionStart` and `stop` → `actionStop`.
- `ui/src/app/shell/screen-action-handler.ts`: register the list, and add `WARNING_CONSEQUENCES` `{stop: languageServerStopConsequence}`.
- `ui/src/app/core/strings.ts`, EXPERIENCE.md (in place, per Design Notes), and the regenerated `core/screens.generated.ts`.
  - `ui/tools/self-protection.test.mjs` pins `RUNNINGREASON`, `STOPPEDREASON` and `REASONLANGUAGESERVERSTART` equal to their keys.
- Client tests:
  - `log-viewer.spec.ts`: the `read` source's mapping, publishing and Load newer; the `:450-477` pin admits a declared-read source;
  - `screen-action-handler.spec.ts`: Start sends; Stop warns and then sends;
  - `data-table.spec.ts`: the Running disc;
  - `rail-wire.spec.ts` and the `ui/tools` roster tests.
- **New `ui/browser/language-servers.browser-spec.mjs`**, on `ocupilot-ci` with `assertThrowaway`:
  - it seeds a probe Java server through the throwaway's admin API as `_SYSTEM`;
  - list → Start → Running "Yes" with "Changed" → name cell → Activity log entries and chips, Explain present → back → Stop, warning dialog, Proceed → "No" → Stop again refused;
  - the principal without the own pair sees the unavailable entry;
  - the DW-1337 walk of both screens at wide light, narrow light and wide dark;
  - teardown per the wire class.
  - Extend 16.7's side-bar pin to nine entries.

**Acceptance Criteria:**

- **AC1.** Given `ocupilot-ci`, when External language servers opens (the ninth OS management entry), then it lists every server the instance defines with Name, Type, Port and Running, where Running is the vendor's own `CurrentlyRunning` read as Yes or No.
- **AC2.** Given a stopped server, when the person chooses Start, then it starts and its row reads Running "Yes" in place, marked "Changed".
  - Given a running server, when they choose Stop and Proceed past the warning, then it reads "No" in place.
  - The wrong verb for the row's state is refused with its published sentence and sends nothing.
  - A start the instance refuses says "The server did not start. Its activity log records why."
- **AC3.** Given a server, when its name is chosen, then its Activity log opens in the shared log viewer at `os-management/language-servers/activity/<name>`. It shows the newest entries with time, pid, severity chip and text, and Load newer and "Explain this entry" work as on every log viewer.
- **AC4.** Given the agent, when it proposes `osmgmt.languageservers.start` or `.stop` and the person confirms, then the write is the screen action's, and a proposal whose server changed state since the mint is refused at Confirm. Both keys are in `Baseline.cls`, enabled.
- **AC5.** Given a principal holding OS management's pairs but not `%Admin_ExternalLanguageServerEdit:USE`, when they open OS management, then this entry alone reads "Requires %Admin_ExternalLanguageServerEdit:USE", and its route, its two read tools and its two write tools answer 403 naming that pair. A principal holding exactly the screen's two pairs reads both screens and starts and stops a server.
- **AC6.** Given the new strings, when the story lands, then they are in EXPERIENCE.md's Fixed strings (993 lines, no citation moved) and in `strings.ts`, pinned by `npm run test:tools`, and the three refusal sentences are pinned equal to their server copies.
- **AC7 (Integration).** Given `ocupilot-ci` with a probe server running, when the consumers read, then:
  - `LogViewerPage` (consumer) renders `osmgmt.languageserveractivity`'s declared read, and `osmgmt.languageserveractivity.read` returns the same newest rows;
  - `ListPage` (consumer) shows the Running value that `osmgmt.languageservers.read` returns;
  - both screens pass the DW-1337 walk with no new allowance.

## Spec Change Log

- 2026-09-29, spec gate (lead): the orchestrator took the split (A) at the merge gate -- this story keeps the list with each server's Running state, Start and Stop, and the Activity log; the editor (create, edit, delete) and DW-253 moved to Story 16.25 (epics.md, both blocks tagged). Spine amended at the gate: AD-8 (the own pair), AD-36 (`ACTIVITY` as a `rowGet` detail and as `source.rows` `Activity`), AD-15 and AD-53 (Stop, the fifth unaudited write). This story's Activity log needs Story 16.7's `source.rows`, which lands first. Status `blocked` to `ready-for-dev`.

## Review Triage Log

### 2026-09-29 — Review pass

- verdicts: 26 findings — high 0, medium 4, low 17, false 5, maybe-false 0
- findings:
  - `[medium]` `[patch]` Explain this entry on the Activity log hands off the row as answered, and no test read the handed-off row — added the declared-read case in `log-viewer.spec.ts`; mutation line under Verification.
  - `[medium]` `[patch]` The page's switch to another server's Activity log without leaving the page was untested — added the post-mount navigation case in `log-viewer.spec.ts`; mutation line under Verification.
  - `[low]` `[patch]` The refused start's vendor text reaching the log was unasserted — `LogProbe.Captured` assertion added to `LanguageServer.TestARefusedStartAnswersItsPublishedCode`; mutation line under Verification.
  - `[low]` `[patch]` `ActivityRowsProblem`'s criterion-kind and one-criterion legs had no corpus case — two rows added to `ReadSourceCorpus`; `screen-mirror.test.mjs`, `Descriptor` and `ReadTool` green.
  - `[low]` `[patch]` AC4's mutation line named only the unarmed class — re-run against `LanguageServerWire` (all four red) and the line corrected.
  - `[low]` `[patch]` AC6 had no mutation line — demonstrated on `self-protection.test.mjs` and written.
  - `[medium]` `[patch]` AC7 had no test comparing the read tools' answers with the screens' — `LanguageServerWire` now compares both tools' views with the screen reads; mutation line written.
  - `[low]` `[patch]` `rail-wire.spec.ts`'s new case named a fixture-only mutation — comment reworded to what it pins; the server side is `OcuPilot.Test.Wire`'s.
  - `[low]` `[patch]` `LanguageServerWire.Running()` read 0 on a failed read, so stopped-state checks passed on a failure — it now answers -1 for a failed or non-boolean read.
  - `[low]` `[patch]` Two `LanguageServer` legs quit silently when the vendor list was empty — each now asserts the list first.
  - `[false]` `[reject]` Wrong-verb refusal comes after the fresh `ACTIVITY` read, not before any port call — Boundaries say "before any write", and `StateDiff` needs that read.
  - `[false]` `[reject]` Stop on a stopped row opens the warning before the refusal — Boundaries make the warning unconditional ("Stop first opens the warning dialog").
  - `[low]` `[reject]` The two state sentences reach the screen through a client allow-list over `detail.problem`, not the envelope's reason — both copies are pinned equal by `self-protection.test.mjs`; moving them into the reason is a kernel change for every action tool.
  - `[low]` `[reject]` A missing `name` is refused 400 by the read layer, not the port — the outcome (400, the viewer's refusal) is the matrix row's; it follows the parent-scoped read precedent in `Read.cls`.
  - `[low]` `[reject]` The area principal's agent mint and confirm are not exercised — the tools' pairs are pinned equal to the screen's, and the dispatch gate over `PrivilegePairs` is pinned by existing suites.
  - `[low]` `[reject]` The failed start is not driven end to end in a browser — each part is pinned (wire 500 and stopped state and Error row, client sentence, Error to Severe mapping); a browser leg adds a second probe and minutes.
  - `[medium]` `[patch]` The unarmed class asserted every `%` server reads not running, which depends on the instance — assertion removed; the class counts the vendor rows only.
  - `[low]` `[patch]` A vendor `%` name's route-to-read decode was untested — declared-read case added for `%2525Java%2520Server` in `log-viewer.spec.ts`.
  - `[low]` `[reject]` Load newer is re-read only in a stubbed unit test — the windowed re-read is shared with the secondary logs, whose browser spec clicks it.
  - `[false]` `[reject]` The out-of-band stop is exercised through the kernel's `Mint`/`Confirm`, not HTTP — the confirm route is a thin wrapper over that operation (AD-53).
  - `[low]` `[reject]` Read-back and copy-out rest on generic machinery — `DraftRegistry` and `ReadBack` iterate every registered write tool and stayed green.
  - `[low]` `[patch]` The "live-captured" navigation payloads gained hand-shaped entries — same root cause as the rail-wire row; the comment now says the instance side is `OcuPilot.Test.Wire`'s.
  - `[low]` `[reject]` The generic log-viewer loop keys its expectation on `port === 'admin'` while the page keys on `SOURCES` — a mismatch reddens the loop, which is the wanted signal.
  - `[false]` `[reject]` Shared modules were refactored despite add-only — the add-only rule covers the contended files, and every edit there is an addition or a directed count bump.
  - `[low]` `[reject]` "Port" is published at `:584` and reused from `sslTestPort` rather than keyed `languageServerColumnPort` — the strings test allows one key per value; `test:tools` green.
  - `[false]` `[reject]` Explain sends the raw row rather than `{time, severity, text}` — the intent has screen context carry the rows as answered, and `narrowRow` keeps the declared fields.

## Design Notes

**Q1: size and split (Rule 5 tier 2, for the lead).** The epics block is two stories' worth.

- The editor alone matches Story 18.2's size (a paired list and form, three tools and a save route; 75 files), before counting DW-253's generator change, an AD-4 named exception and AD-21 path handling.
- Start, Stop and the Activity log add the list, two action tools, two read shapes and a log-viewer source.

Options:

- **(A), recommended; this spec:**
  - 16.10 carries the epics' first three criteria.
  - A new Story 16.25, "The external language server editor", carries the fourth (create, edit, delete confirming by name) and DW-253.
  - Each half ships alone, and this half needs no field lists.
- **(B)** Delete joins 16.10's row actions; 16.25 keeps create, edit and DW-253. This splits the fourth criterion.
- **(C)** Keep one story: this spec plus the editor, using the facts below. `oversized`.

**Handed to the editor story** (measured on `ocupilot-ci`, so its plan does not re-probe):

- **PUT is the only create and edit** (an upsert, answering 201 on create).
  - `Type` is required on every PUT and cannot change (500 "Cannot modify Type"). `Port` is required on create.
  - Unknown keys answer 400 #40307; range errors answer 500 (#7203, #7204, #7206).
  - Nothing checks for a duplicate port or for an existing `Resource` or SSL name.
- **It keeps omitted keys, `Custom` member by member (an AD-4 measurement).** But a PUT carrying `Custom` on a Python server clears the classic-only `PythonCreateVirtualEnvironment` and `PythonPathVar`. So omit an unchanged `Custom` (an AD-4 named exception), and state the consequence when a Custom member changes on a Python server.
- **`PutRequestBodySchema(type)` builds `Custom` by `Type`:**
  - Java, XSLT, JDBC, ML and R: `{ClassPath, JavaHome, JVMArgs}`;
  - .NET: `{DotNetVersion, Exec32, FilePath}`;
  - Python: `{PythonOptions, PythonPath}`;
  - Remote: `{Address}`;
  - ODBC, and no argument: `{}`.
  - For DW-253, derive one list per `Config.Gateways.Type` value, keyed `LanguageServer:<Type>`. This needs:
    - `AdminPort.Template` taking an argument (`TEMPLATEARGUMENTS` holds one per endpoint);
    - `field-lists.mjs:180`'s key rule;
    - the counts in `DerivedFields.cls:35-82`;
    - the `field-lists.test.mjs:119` case.
    - Nested `Custom.*` members reach a schema only as one object argument, following the OAuth client `Metadata` precedent.
- **AD-21:** `LogFile`, `ClassPath`, `JavaHome`, `PythonPath` and `FilePath` are server paths. Recommended: shown, never set, and never sent, as the SSL/TLS file fields are. A settable path is a new AD-21 case, or PathPort's sixth, which still waits on Epic 18's consumer follow-up.
- **Pairs:** PUT and DELETE need `%Admin_Manage:USE` and `%DB_IRISSYS:WRITE`. A Python delete also needs `%System_CallOut:USE`: without it, the virtual environment was already deleted before the vendor refused.
- **A deleted running server keeps listening.** The classic page refuses edit and delete while a server runs, and the editor should refuse the same. The delete's read type is `ACTIVITY`.
- **Audit and classic pages:** writes leave `%System/%System/ConfigurationChange` events. The classic editor is `%CSP.UI.Portal.ExternalLanguageServer`, and it defaults `Resource` by type (`%Gateway_SQL` for JDBC and ODBC, `%Gateway_ML` for ML), while the API defaults to `%Gateway_Object`.
- **With an editor, the name cell opens the editor** (`editorScreenFor` comes before `childListFor`), so 16.25 links the Activity log from the editor.

**Spine changes for the lead** (Rule 20). They follow AD-8's and AD-36's existing patterns, so they do not block by themselves:

- (a) AD-8, append: "**OS management's External language servers is a further own-pair case** [AMENDED 2026-09-28, Story 16.10 spec gate, Rule 20]: its list and its Activity log declare `%Admin_ExternalLanguageServerEdit:USE` as their own pair beside the area's `%DB_IRISSYS:READ`, because `LanguageServer`'s `ResourcesOR()` names only that resource and a principal holding exactly those two pairs listed, read, started and stopped servers (measured on `ocupilot-ci`), so a holder of OS management's set keeps every other OS management screen."
- (b) AD-36, append: "**`ACTIVITY` is a detail type, and a list over one member** [AMENDED 2026-09-28, Story 16.10 spec gate, Rule 20]. `LanguageServer`'s LIST answers no running state, and its `ACTIVITY` answers `CurrentlyRunning` beside the `Activity` rows. So External language servers' `rowGet` issues `ACTIVITY` with the vendor's `maxRows` 1, merging `CurrentlyRunning`, and the Activity log, a parent-scoped screen whose one criterion is its route id, reads `ACTIVITY` with `source.rows` `Activity` under the same cap-plus-one rule as a bare type."
- (c) AD-15's named case, append: "The fifth is stopping an external language server (`LanguageServer` `STOP`, no event with auditing on, measured on `ocupilot-ci` 2026-09-28); its start leaves only the launch's `%System/%System/OSCommand` events." AD-53's named gap, append: "The fifth: External language servers' Stop (Story 16.10)."

**Copy** (EXPERIENCE.md in place; the count stays 993):

- **Fold into `:584`.** Strings: "External language servers" · "Running" · "Port" · "Start" · "Activity log" · "This server is already running." · "This server is not running." · "Stopping it ends every connection to it at once." · "The server did not start. Its activity log records why." · "No external language servers on this instance." · "start or stop an external language server". Where used, tagged `[ADDED 2026-09-28 - Story 16.10]`:
  - the screen's side-bar entry and title, the ninth OS management entry (`:164`);
  - its Running and Port columns, beside the reused "Name" and "Type";
  - Start, beside the reused "Stop" (`:269`);
  - the two state refusals;
  - Stop's warning consequence (`:617`);
  - the refused start;
  - the empty state and its agent fragment;
  - the Activity log title, rendered by the shared log viewer (`:627`).
- **Fold into `:585`.** Prompts, in the Troubleshooting group, three per screen:
  - list: "Which external language servers are running?" · "Which servers share a port with another server?" · "Which server should I check first when a gateway call fails?"
  - Activity log: "What does this server's activity log say about its last start?" · "Did this server log any errors?" · "When was this server last started or stopped?"
- **`:155`, in place:** after "suspend/resume process", add " · start/stop an external language server".
- **`:627`, in place:** the Where cell adds "; a language server's Activity log (Story 16.10)". Its body adds: "A language server's Activity log reads the instance's own activity rows for that server, a newest window that Load newer re-reads; its record types Debug, Info, Warning and Error take the Debug, Info, Warning and Severe chips."
- **Keys:**
  - `languageServersLabel`, `languageServerColumnRunning`, `languageServerColumnPort`, `languageServerActivityLabel`, `actionStart`;
  - `languageServerRefusalRunning`, `languageServerRefusalStopped`, `languageServerStopConsequence`, `languageServerStartFailed`;
  - `languageServerListEmpty`, `languageServerListEmptyAgent`;
  - `languageServerListPrompt1-3`, `languageServerActivityPrompt1-3`.

**Governing ADs:**

- reads and the screens: AD-2, AD-5, AD-8 (amended), AD-19, AD-20, AD-24, AD-26, AD-27, AD-29, AD-36 (amended), AD-43, AD-44;
- writes: AD-10, AD-13, AD-14, AD-15 and AD-53 (amended), AD-22, AD-39, AD-51, AD-52, AD-58, AD-59;
- untrusted text: AD-11, AD-60 (activity text reaches the model only as tool results, through the sanitizer);
- AD-21 (no path); Conventions › Dates.
- AD-3, AD-4, AD-54 and AD-55 bind the editor story.

**Named limits:**

- A start blocks until the server answers or its `InitializationTimeout` (up to 300 s) runs out. Beyond the gateway's 60 s, the screen sees a 504 while the start still completes (inference).
- `CurrentlyRunning` pings a busy port with a 10 s timeout, so a port held by a foreign process can slow the list by up to 10 s per such row (inference, from `IsGatewayRunning`).
- A `Remote` server's start is the vendor's logged no-op.
- The Activity log lives in IRISTEMP and empties on restart (inference).
- Vendor `%` servers may be started and stopped, as in the classic portal.
- The implement stage records the list read's time against NFR-1.

**Integration:**

- **Consumes:**
  - Story 16.7's `source.rows`, which must land first;
  - 16.8's log viewer and `LogLine`;
  - 6.7's `childListFor` and route-id criterion;
  - 5.12's action-write shape;
  - 16.5's `WARNING_CONSEQUENCES` precedent;
  - `structural-walk.mjs`.
- **Consumed-by:** the proposed Story 16.25, whose editor links the Activity log and whose delete reads `CurrentlyRunning` through `ACTIVITY`.

**Ledger:**

- DW-253 is declined here. It belongs to the editor's field lists: under (A) the lead re-owns it to 16.25 when chartering that story; under (C) it is implemented here as sketched above.
- The CLASSICPAGES gap is in frontmatter `deferred`.

## Verification

Slot A only. Everything that creates a server, starts it, stops it or creates a principal runs on `ocupilot-ci`. Every browser run first rebuilds the bundle and copies it in with `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, and exports `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`.

**Commands:**

- `cd ui && npm run test:tools` (loop) -- expected: green, covering `screen-mirror` (ACTIVITY parity), `strings`, `self-protection` (three pins), `navigation`, `navigation-wire`, `screen-actions` and `ci`. Mutation: the mirror admits `rows` on `ACTIVITY` with no `parentScope` → its parity case goes red.
- `cd ui && npx ng test --include src/app/areas/logs/log-viewer.spec.ts --include src/app/areas/logs/explain-roster.spec.ts --include src/app/shell/screen-action-handler.spec.ts --include src/app/shell/warning-dialog.spec.ts --include src/app/shell/data-table.spec.ts --include src/app/shell/list-page.spec.ts --include src/app/shell/side-bar.spec.ts --include src/app/shell/rail-wire.spec.ts --include src/app/shell/screen-outlet.spec.ts` (loop) -- expected: green. Mutations:
  - AC3: map `Error` to `0` → the chip case goes red;
  - AC2: Stop sends without its warning → the handler case goes red.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class <C>` (loop), one class per call. `<C>` is each of: `OcuPilot.Test.LanguageServer`, `LanguageServerWire`, `RowGetCorpus`, `ReadSourceCorpus`, `ScreenRead`, `Descriptor`, `Navigation`, `Wire`, `WireSecurityRead`, `ReadTool`, `SurfaceCoverage`, `EndpointCoverage`, `ToolWrite`, `ToolRoundTrip`, `ToolEmit`, `Prohibited`, `GovernanceBaseline`, `PortFixture`, `PromptCorpus`, and the class or classes Story 16.7 adds for `rows`. Expected: green. Mutations:
  - AC1: the detail call omits `maxRows` → the `LanguageServer` seam leg goes red;
  - AC2: `StateDiff` accepts a running server → the refusal leg goes red;
  - AC4: the fingerprint subject is emptied → registration refuses it, and the out-of-band stop leg goes red;
  - AC5: drop `ownPrivileges` → `Descriptor`'s area-coverage row goes red;
  - AC5: the tool declares `%Admin_Manage:USE` → the exact-pairs wire leg goes red.
- `cd ui && npm run build && docker cp … && node --test --test-concurrency=1 browser/language-servers.browser-spec.mjs browser/secondary-logs.browser-spec.mjs browser/messages-log.browser-spec.mjs browser/alerts-log.browser-spec.mjs browser/log-hub.browser-spec.mjs browser/explain-entry.browser-spec.mjs browser/namespaces.browser-spec.mjs browser/license-usage.browser-spec.mjs browser/processes.browser-spec.mjs browser/a11y-structural-invariants.browser-spec.mjs browser/screen-height.browser-spec.mjs` (loop) -- expected: green within the structural baseline. Mutation: the name cell opens no child → the AC3 leg goes red on a rebuilt, redeployed bundle.
- `cd ui && npm test`, `uv run scripts/check-objectscript.py`, `bash scripts/lint-docs.sh`, and `wc -l` on EXPERIENCE.md (once, before `dev_complete`) -- expected: green, and 993.
  - If the bundle crosses `maximumWarning`, re-base it to 5% above the measured total and update `angular-json.test.mjs`'s literal in the same change (DW-1166). Stop and ask above 3800 kB.
- The full ObjectScript sweep on `ocupilot-ci`, one class at a time (once, before `dev_complete`) -- expected: green apart from the known residue. The full browser suite is CI's (Rule 29).

Mutations demonstrated (implement stage, each reverted with the tree unchanged after):

- mutation: `activityRowsProblem` admits an `ACTIVITY` read with no `parentScope` → `screen-mirror.test.mjs` "readProblem returns every ... sentence OcuPilot.Test.ReadSourceCorpus declares" went red.
- mutation: `RECORD_SEVERITIES` maps `Error` to `'0'` → `log-viewer.spec.ts` "maps each row to a line oldest first ..." went red.
- mutation: the `LanguageServerList` entry dropped from `WARNING_CONSEQUENCES` → `screen-action-handler.spec.ts` "opens the warning before Stop ..." went red.
- mutation: `PUBLISHED_PROBLEMS` emptied → `screen-action-handler.spec.ts` "shows a state refusal's published sentence ..." went red.
- mutation: `Read.DetailRow` sends no `maxRows` on an `ACTIVITY` detail call → `OcuPilot.Test.LanguageServer.TestTheActivityDetailCallSendsOneRow` went red.
- mutation: `LanguageServerStart.StateDiff` lets a start through for a running server → `OcuPilot.Test.LanguageServer.TestTheStateDiffRefusesTheWrongVerb` went red.
- mutation (AC4): `FINGERPRINTSUBJECT` emptied → the tool registry refuses it: `OcuPilot.Test.LanguageServer`'s `TestTheToolsAreActionWritesOverTheScreensOwnPairs`, `TestTheDescriptorsRegister` and `TestProhibitedCoversTheType` went red, and so did all four `OcuPilot.Test.LanguageServerWire` methods, `TestTheAgentsStartConfirmsAndAMovedStopIsRefused` among them.
- mutation: `ownPrivileges` dropped from `LanguageServerList` → `OcuPilot.Test.LanguageServer.TestTheDescriptorsRegister` (area coverage and registry validation) went red.
- mutation: `AdminPort.TYPEFAULTS` emptied → `OcuPilot.Test.LanguageServer.TestARefusedStartAnswersItsPublishedCode` went red.
- mutation: `language-server` dropped from `Prohibited.COVEREDTYPES` → `OcuPilot.Test.LanguageServer.TestProhibitedCoversTheType` went red.
- mutation: `LanguageServerStart.PrivilegePairs` adds `%Admin_Manage:USE` → `OcuPilot.Test.LanguageServerWire.TestTheExactPairsPrincipalStartsAndStopsTheProbe` went red (403 naming `%Admin_Manage:USE`).
- mutation: the name cell's `childListFor` link skipped for this list, rebuilt and redeployed → `language-servers.browser-spec.mjs` AC1-AC3 went red at the Activity log wait.
- mutation (AC3): a row's `entry` sent as `{time, severity, text}` rather than `line.record` → `log-viewer.spec.ts` "Explain this entry hands that row, as the read answered it, ..." went red.
- mutation (AC3): the page's declared-read `NavigationEnd` branch removed → `log-viewer.spec.ts` "another server's Activity log, reached without leaving the page, ..." went red.
- mutation (AC2): the `TYPEFAULTS` branch's `LogFault` call removed → `OcuPilot.Test.LanguageServer.TestARefusedStartAnswersItsPublishedCode` ("which reaches the log") went red.
- mutation (AC6): one word of `LanguageServerStart.RUNNINGREASON` changed → `self-protection.test.mjs` "Story 16.10: the two state refusals and the refused start ..." went red.
- mutation (AC7): the Activity log's declared sort direction set to `asc` → `OcuPilot.Test.LanguageServerWire.TestTheExactPairsPrincipalStartsAndStopsTheProbe`, which compares `osmgmt.languageserveractivity.read`'s rows with the screen read's, went red.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** External language servers is OS management's ninth entry: the vendor's `LanguageServer` LIST with a per-row `ACTIVITY` detail call (`maxRows` 1) for Running, Start and Stop as action-style row actions and agent tools (Stop warns first; the wrong verb is refused with its published sentence; a refused start answers 500 `LANGUAGESERVER.START`), and each server's Activity log as a parent-scoped `log-viewer` reading `ACTIVITY` over `Activity` through a new `read` source in the shared viewer. The plan's Q1 halt closed at the spec gate (Spec Change Log).

**Files.**

- Server: `Port/AdminPort.cls` (`ACTIVITY`, bodyless `START`/`STOP`, `TYPEFAULTS`), `Api/Error.cls` (code and sentence), `Screen/Read.cls` and `Screen/Registry.cls` (`ACTIVITY` detail and rows rule), two descriptors, two tools, `EntityType`, `Prohibited`, `Baseline`.
- Client: `log-viewer.store.ts`/`.page.ts` (`read` source, published rows, route switch), `log-line.ts` (`record`), `screen-actions.ts`, `screen-action-handler.ts` (registration, Stop warning, published state refusals), `strings.ts`, regenerated `screens.generated.ts`, `screen-mirror.mjs`; EXPERIENCE.md in place (993 lines).
- Tests: new `Test/LanguageServer.cls`, `Test/LanguageServerWire.cls` (armed by `OCUPILOT_ALLOW_PRINCIPALS`; `ci-throwaway.sh` roster comment), `language-servers.browser-spec.mjs`; roster bumps for this story's additions only.
- Outside the Code Map: `Test/LanguageServerEndpoint.cls` (fixture), `ui/src/app/areas/logs/log-line.ts`, `ui/tools/screen-mirror.test.mjs`.

**Review.** 26 findings (medium 4, low 17, false 5): 13 patched, all test-side (Explain row, route switch, `%` name decode, vendor text to log, two corpus rows, AC7 tool-versus-screen comparison, strict `Running()`, no silent skips, an instance-dependent assertion removed, AC4/AC6/AC7 mutation lines); 13 rejected with reasons in the Review Triage Log; one item deferred (the server-fault banner beside a refused start). Follow-up review: `false` -- four mediums were patched, all test-only and each demonstrated red by mutation, so no unverified risk can be named.

**Verification.** On `ocupilot-ci`: targeted classes green (WireSecurityRead's known task-history residue aside); every AC's mutation demonstrated red and reverted (Verification). `npm test` green (tools 1,707, components 1,839); build 2.18 MB; `check-objectscript`, `lint-docs` 0 problems. Browser: this story's eleven spec files 70/72, the two failures in `alerts-log.browser-spec.mjs`, whose seed-once entries have left the 202 KB tail of the 9-day-old throwaway's alerts.log. Full sweep: 365 classes, 2,988 tests, 7 failed, all residue: `PathPortInstance` 1, `Retention` 1, `TaskHistory` 3, `WireSecurityRead` 1, and `ProposalPrivilege.TestAMintRecordsItsArgumentPairs`, whose `%SYS` delete mint meets 1,085 application errors, more than one delete lists (150 to 231 a day since 09-24, so not this story's). The list read takes about 20 ms (NFR-1).

**Residual risks.** The tools' fresh `ACTIVITY` read sends no `maxRows`, so a mint or confirm reads up to the vendor's default of a server's activity rows; a start blocks up to the server's `InitializationTimeout` (Named limits); the full browser suite is CI's.
