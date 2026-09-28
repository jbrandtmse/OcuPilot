---
title: 'Story 16.9: The unified log hub'
type: 'feature'
created: '2026-09-27'
status: 'done'
review_loop_iteration: 0
baseline_revision: '7ed5b617ac47e64b714b6b83e503264198fe81b7'
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-16-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The Logs area has ten sources on ten screens, so a person investigating an incident has to open each one to learn where anything happened, and nothing shows the sources side by side in time order (FR-77, amended 2026-09-27 with the merged timeline).

**Approach:** A new Logs screen, `logs/hub` ("Unified log hub"), is one descriptor whose declared read is a new **composed** read kind. It runs each listed Logs screen's own read under that screen's own gate, projects each row to `{time, source, severity, text, id}` on the instance's clock, keeps the rows inside a window (default: the last hour), and merges them newest first. The answer carries a per-source summary beside the rows. One page shows the Sources list (count, last entry, explain) with the Timeline beside it (filters, entries that open their source at that entry).

## Boundaries & Constraints

**Always:**

- **Members are fixed, never named by a caller (AD-21).** The members are the Logs area's listed built screens other than the hub, in side-bar order: alerts, messages, errors, audit, systemmonitor, taskerrors, xdbc, sqldiagnostics, eventlog, analytics. The roster is derived from the registry, and a test pins it equal to that list. The read's only inputs are the `since` criterion and `maxRows`. No parameter names a source, a file, a path or a namespace.
- **Each member through its own read and gate (AD-5, AD-8, AD-29, AD-36).** For each member, in the caller's process:
  1. `Screen.Gate.Evaluate(member)` runs first. `Screen.Read.Execute` does not gate, so this call is required.
  2. On a refusal, the member is left out (`shown` false, `requires` = the failed pair) and read zero times. A 403 from the member's read is treated the same way.
  3. Otherwise the member's own read runs:
     - log-viewer members and audit: `Screen.Read.Execute(member, maxRows, …)`. Audit is given `beginDateTime` = `since`.
     - errors: the new port reader, behind the same gate (Design Notes).
  4. Any other member failure fails the whole read with that member's envelope. The answer is never partial (AD-36).
- **Hub gate.** The hub declares `%Admin_Operate:USE` alone (the messages.log viewer's set, which is inside the Logs area's set). It declares no `ownPrivileges`, so the Logs area never needs `%Ens_EventLog:USE` or `%DeepSee_Portal:USE` (AD-8 as amended for DW-1755).
- **Instance clock.** Every `time` is instance-local `YYYY-MM-DDTHH:MM:SS.mmm` (Design Notes table). The window and the merge compare that form.
  - `since` is instance-local `YYYY-MM-DD HH:MM:SS`, defaulting to 1 hour ago (`defaultHoursAgo` 1, from `$Horolog`). The answer's `criteria` reports it.
  - A row with no time is left out of the timeline.
- **Caps and truncation.**
  - Each member is read at `maxRows`.
  - A member is `truncated` when its read was cut while its oldest returned row is still at or after `since`, or when the merged cut drops any of its window rows.
  - The merged rows are cut to `maxRows`, newest first. The answer's `truncated` is the OR of every member's flag.
  - `LogSourcePort.Rows` reports the port's own cut (a tail window that started past the file's first byte, or a `Recent` reader or merge cut), and `Execute`'s logsource branch ORs it into `truncated`.
- **Answer shape.** `{fields, rows, truncated, criteria, sources}`.
  - `rows`: `{time, source, severity, text, id}`. `source` is the member's route. `severity` is on the console scale -2..3, or `""` where the source records none. `id` is the member's AD-13 composite id, or `""`.
  - `sources`: one entry per member, in roster order: `{source, shown, requires, count, truncated, last}`.
    - `count` is the member's rows in the answer.
    - `last` is the member's newest row, whether or not it is inside the window, projected as a row with `text` cut at 1,000 characters ending U+2026. It is null when the member has no rows or is not shown.
  - The generic read route and `logs.hub.read` answer the same object. The tool's view carries `sources` beside its rows.
- **Page (AD-19).**
  - A root `LogHubStore` fetches through `ApiService`, because `createScreenRead` drops `sources`. The store is reset at sign-out.
  - The page publishes the rows it shows to the hub's ScreenStore, so screen context and Download CSV follow what is on screen.
  - Filters are client-side:
    - a Source select and a Severity select, each with "Any";
    - the command bar's "Filter rows" field, through the same `applyView` screen context uses.
  - Counts in the Sources list are the entries left after all three filters.
- **Opening at an entry** is always by a person's click, so it is never announced (AD-11 rule 3). By family:
  - Log viewers: a one-shot `ScreenArrivals` `entry`. The viewer marks and scrolls to the matching line, or says "That entry is no longer in the loaded range."
  - Audit: arrival criteria bracketing the entry's second, then `logs/audit/<id>`, where the existing dialog opens.
  - Application errors: `logs/errors/<id>`, which the error-log page now drills to that error's detail.
- **Explain (AD-11, AD-60).** Both use the existing `ExplainEntry` with "Explain this entry":
  - on a timeline entry, it sends that row alone as `{time, source, severity, text}`;
  - on a Sources row, it sends that source's `last` alone. It is `aria-disabled` with "Requires <resource>" when the source is not shown, or "No entries." when it has no entry.
- **Copy.** It comes verbatim from the Design Notes rows, and EXPERIENCE.md and `strings.ts` change in the same change.

**Never:**

- No write tool, governance key or `Baseline.cls` entry. No change to any existing Logs screen's own gate, route, read or `Area.cls` pairs.
- No new archetype. The hub is `list`, with its page in `DESCRIPTOR_PAGES`.
- No lazy route or `@defer`. No new vendor-internal traversal. Audit is reached only through `AuditList`'s read (AD-2, AD-27), and its `EventData` is never projected.
- Never edit `.github/workflows/ci.yml`, `ui/tools/ci-runner.mjs` or `ui/browser.config.mjs` (Story 13.5 runs on slot B). Changes to the `ui/tools/ci.test.mjs` and `scripts/ci-throwaway.sh` rosters are add-only.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Seeded | one entry in eventlog (HSCUSTOM), one console line at severity 2 (messages.log, and alerts.log, which receives severity 2 and above (inference)), a sign-in audit row, all inside the hour | the Sources list reads ten rows. The seeded sources have count ≥ 1 and their seeded entry as last entry. The timeline holds them newest first, each with time, source label, severity chip and text | — |
| Fresh default | open with no criteria | `criteria.since` is 1 hour before the instance's now, echoed into "Begin date and time" | — |
| Quiet source | alerts.log's newest entry is two days old | alerts row: count 0, last entry = that two-day-old line; nothing from alerts in the timeline | — |
| Least privilege | `%Manager` + `%DB_HSCUSTOM` principal (no `%Ens_EventLog`) | hub 200. eventlog is `shown` false with `requires` `%Ens_EventLog:USE` and has no row. The notice reads "Not shown: Interoperability event log — requires %Ens_EventLog:USE." messages, alerts and the Logs area stay open | no error |
| Namespace skipped | caller cannot read USER | USER's entries are absent, as on each source's own viewer | not a fault |
| Cap inside window | member returns `maxRows` rows, all after `since` | that source is `truncated`; its row shows "This list was cut at the row cap — older entries are not shown." | — |
| Cap outside window | member truncated but its oldest row is before `since` | not truncated; rows before `since` are dropped | — |
| Merged cut | the rows in the window exceed `maxRows` | the newest `maxRows` are kept; every source that lost a window row is `truncated` | — |
| Filters | Source = Interoperability event log, Severity = Severe, text "probe" | only the rows matching all three remain; every other source's count reads 0; "Clear filter" restores | "No matches." when nothing is left |
| Open a viewer entry | click the time of the eventlog row | `logs/eventlog` opens with that line `aria-current="true"`, highlighted and scrolled into view | if absent: "That entry is no longer in the loaded range." |
| Open an audit entry | click an audit row's time | `logs/audit/<id>` opens with its criteria bracketing that second and the event dialog open | — |
| Open an error | click an application-error row's time | `logs/errors/<ns,date,n>` shows that error's detail level | — |
| Member fault | a member read answers 500 or `PORT.TIMEOUT` | the whole read fails with that envelope; the page shows its error presentation | never partial |
| Bad window | `?since=yesterday` | 400 `READ.CRITERION` naming `since` | before any member is read |
| Caller naming a source | `?source=x&file=y&namespace=z` | ignored: only declared criteria are read (the allow-list) | — |

</intent-contract>

## Code Map

Server (`src/OcuPilot/`):

- `Port/LogSourcePort.cls`:
  - `SOURCES` :84, `RECENTSOURCES` :142; `PairsFor` :434 and `ErrorPairSpec` :471 (applicationerrors per namespace: `%Admin_Operate:USE`, `%DB_IRISSYS:READ`, and db `READ`+`WRITE`).
  - `NamespaceResolver` :534, `ReadableNamespaces` :1062.
  - `Page` :661 (tail read, `DEFAULTMAXBYTES` 64 KB :370).
  - `Rows` :787. It drops `Recent`'s `truncated` at :800, and `LOG.ABSENT` becomes an empty answer at :806.
  - `HeadParts` :868; `Recent` :909; `Prefix` :1578; `ClockStamp` :1586; `LocalFromUtc` :1596; `Drain` :1614-1641.
  - `Errors` :1674, `ErrorsRead` :2254 (one `%SYS` window, AD-48), `ErrorRows` :2462.
  - `Gate` :2631 (private), `DeniedRefusal` :2238.
  - Epic 14's `Snippet` sits after `Fail` :3028. **Add the new reader after `Drain` (:1641).**
- `Screen/Read.cls`:
  - source-kind parameters :131-151; `Execute` :234 (kind guard :251; branches: state :260, logsource :269-276, mgmnt :277, admin …).
  - The audit mask call `AuditPort.MaskVendorSecrets` :381; `truncated` :385; the cap :399; `criteria` :415.
  - `CriteriaParams` :620, `SeedCriteria` :703, `HoursAgo` :775; `DEFAULTMAXROWS` 1000 :77.
- `Screen/Tool/Read.cls` `ResultSchema` :81-94 and `View` :185-250 (`criteria` passed through at :240; add `sources` the same way).
- `Api/ScreenRead.cls` `Handle` :49-85 (`Gate.Evaluate` :57). It forwards selected result members; add `sources`.
- `Screen/Gate.cls` `Evaluate(descriptor, .failedPair)`, which includes AD-44's custom classic resource.
- `Screen/Registry.cls`:
  - `ReadProblem` :999 (allowed ports :1029-1031; logsource and state restrictions :1137-1149); `READSOURCETYPES` :1640.
  - `AreaCoverageProblem` :794, `TableProblem` :2032 (exactly one `name` column).
- `Kernel/EntityId.cls` `JoinComposite` :74 / `SplitComposite` :81.
- Descriptors:
  - `Screen/Descriptor/LogEventViewer.cls` is the shape to copy.
  - `AuditList.cls`: read :115-183; id parts `UTCTimeStamp, SystemID, AuditIndex`; `beginDateTime` :152.
  - `LogErrorList.cls`: no read; id `namespace, date, errorNumber` :89; pairs :83.
  - `Screen/Area.cls:120` holds the `logs` pairs (unchanged).
- Tests:
  - `Test/ReadTool.cls`: count 127 :93, name roster :94, descriptor pairs :112.
  - `Test/Navigation.cls`: Logs count 10 :364, order :365.
  - `Test/Descriptor.cls`: `ReadShapes` :67 (Log rows :83-90), per-screen legs :960/:1004/:1044, area row :1745.
  - `Test/ScreenRead.cls` :385 (logsource count 8).
  - `Test/WireSecurityRead.cls`: `AUDITUSER` :122, code read :210, `EnsurePrincipal` :309, teardown :280-305, DW-1755 leg :1205-1221.
  - Seam and seed precedents: `Test/LogRecordsFixture.cls` and `Test/LogSecondarySeed.cls` (the eventlog recipe).
  - `scripts/ci-throwaway.sh` arming rosters: `OCUPILOT_ALLOW_PRINCIPALS` :231, `OCUPILOT_ALLOW_ERROR_SEED` :240.

Client (`ui/src/app/`):

- `shell/screen-outlet.ts`: `DESCRIPTOR_PAGES` :111-140; `ARCHETYPE_PAGES` :82-93 (`list` → `ListPage`).
- `core/screen-arrival.ts`: `ScreenArrival` :16-23, `take` :37; the setter precedent is `shell/agent-navigator.ts:99-106`.
- `core/explain-entry.ts` `request(screen, row)`; `core/screen-context.ts` `assembleEntryContext` :154-171, `computeView`/`applyView` :93-111.
- `core/screen-store.ts`: `ScreenStores.for` :606, `applyTick` :286, `filter()` :454. `shell/command-bar.ts` draws "Filter rows" and Download CSV for any declared read.
- `core/navigation.ts` `entityUrl` :653; `core/entity-id.ts` `joinCompositeId` :41.
- `areas/logs/log-viewer.page.ts`: `SOURCES` :67-76, the `?file=` handling :329-353, `publishRows` :360, `onExplain` :460, the empty states :526-530, the chip markup :174-188.
- `areas/logs/log-viewer.store.ts` :12-27 and :346-410; `log-line.ts`: `LogLine` :16-35, `SEVERITY_CHIPS` :48, `severityWord` :62 (2 → "Severe").
- `areas/logs/audit.page.ts` `detailRow` :297-303 and arrival :196-206; `audit.store.ts` `useArrival` :198-215, `applyEcho` :245.
- `areas/logs/error-log.page.ts`: the drill doc :79-82, the `openNamespaces` guard :455. `error-log.store.ts` `openNamespaces/Dates/List/Detail` :333-394. The page never reads its `:id` today.
- `app.ts`: injections :248-250, resets :559-566. `app.spec.ts`: seeds :1069-1087, asserts :1195-1210.
- `core/strings.ts`: append before `} as const` :3260. Reused keys: `agentExplainEntryAction`, `privilegeRequiresResource`, `errorLogLevelCapNotice`, `logViewerEmpty`, `logViewerNoMatches`, `logViewerClearFilter`, `logViewerColumnSeverity`, `logViewerColumnMessage`, `auditColumnTime`, `auditEventFieldSource`, `auditCriteriaBegin`, `auditCriteriaTimeHint`, `auditCriteriaSearch`, `auditCriteriaAnyOption`, `promptGroupTroubleshooting`, the severity words and the ten source labels.
- Rosters and specs:
  - `areas/logs/explain-roster.spec.ts:25-42` holds the allowed Logs pages.
  - `tools/navigation.test.mjs:133-172` holds the built-route order.
  - `tools/screen-mirror.mjs` holds `readProblem`, the twin of `ReadProblem`.
- `ui/browser/`:
  - `secondary-logs.browser-spec.mjs` and `secondary-log-spec.mjs`: seeding, `assertThrowaway`, the walk :263-291.
  - `unreadable.browser-spec.mjs:99-138`: creating and removing a principal.
  - `turnprobe-spec.mjs:77-82`: `resultPayload`.
  - `structural-walk.mjs` walks every built screen, and its baseline is append-only.
- `angular.json:54` `maximumWarning` 2004kB.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Port/LogSourcePort.cls`:
  - **`Rows`**: pass the port's own cut back beside the rows (the `Page` tail's `truncated`, and `Recent`'s).
  - **New `RecentErrors(pMaxRows, pSince, Output pAnswer, Output pHttpStatus, Output pFault)`**, placed after `Drain`. What it does:
    - gates `LogErrorList`'s instance pairs (`%Admin_Operate:USE`, `%DB_IRISSYS:READ`) first, because `PairsFor("applicationerrors")` without a namespace is empty. It then gates each readable namespace's `PairsFor("applicationerrors", ns)`, skipping a namespace that fails;
    - in one `%SYS` window (AD-16, AD-48), walks each namespace's dates on or after `since`'s date newest first, then their `ErrorList`s, stopping at `pMaxRows+1`;
    - answers `{rows:[{time, severity:"2", text:"[NS] <errorText>", namespace, date, errorNumber}], truncated}`, where `date` is `DateList`'s string byte for byte and `time` is date plus `Time` → `YYYY-MM-DDTHH:MM:SS.000`;
    - fails a gated namespace's fault with `LOG.UNREADABLE`.
  - Make `LocalFromUtc` callable from `Screen.Timeline`.
- `src/OcuPilot/Screen/Timeline.cls` (new, no storage):
  - `Members()` derives the roster from the registry.
  - `Compose(pMaxRows, pSince, Output pAnswer, Output pHttpStatus, Output pFault)` does the gate, read, project, window, merge, cut and per-source flags described under Always, using the per-member projection in the Design Notes table.
  - The member gate and member read are overridable seams for a test fixture, as `LogRecordsFixture` is.
  - Ties keep roster order, then each member's own order.
- `src/OcuPilot/Screen/Read.cls`:
  - add the kind `SOURCETIMELINE` = `timeline` to the guard and add its branch;
  - seed and validate the `since` criterion as any declared `datetime` criterion;
  - call `Screen.Timeline.Compose`, and return its `rows`, `truncated` and `sources` without re-cutting them, plus `criteria`;
  - in the logsource branch, OR in the port's reported cut.
- `src/OcuPilot/Screen/Tool/Read.cls`: `View` and `ResultSchema` carry `sources`. `src/OcuPilot/Api/ScreenRead.cls` forwards `sources`.
- `src/OcuPilot/Screen/Registry.cls` `ReadProblem`:
  - accept `timeline` only in the `logs` area, with `endpoint` equal to the area key, type `LIST`, no `rowGet`, exactly one `datetime` criterion `since` carrying `defaultHoursAgo` and no `atOrAfterField`, and fields `time, source, severity, text, id`;
  - refuse a `timeline` member whose own read is `timeline`.
  - `ui/tools/screen-mirror.mjs` `readProblem` refuses the same way.
- `src/OcuPilot/Screen/Descriptor/LogHub.cls` (new). Declaration:
  - `route` `logs/hub`, `labelKey` `logHubLabel`, `sideBarPosition` 11, archetype `list`, `built` true, `refreshes` false;
  - `privileges` `[%Admin_Operate:USE]`; `entityType` `log-entry`, scope `instance`, id `none`; `classicPage` `""`;
  - `context.fields` `[time, source, severity, text]`; `emptyStateKey` `logViewerEmpty`;
  - `commandAliases` `["log hub","timeline","all logs"]`, and the three prompts (Troubleshooting);
  - `read`: source `{"port":"timeline","endpoint":"logs","type":"LIST"}`; fields `time, source, severity, text, id`; filter `time, source, severity, text`; sort `time` desc; paging `cap`; criteria `[{"param":"since","labelKey":"auditCriteriaBegin","kind":"datetime","maxLength":50,"defaultHoursAgo":1}]`;
  - `table`: columns time (`name`), source (`text`), severity (`status`), text (`text`), with `emptyNextKey` `tableReadOnlyEmptyNext` and `emptyAgentKey` `""`;
  - `toolIdentifier` `logs.hub`.
- Server tests, one class per run:
  - **New `Test/LogHub.cls`**, over a `Test/LogHubFixture.cls` seam, pins:
    - the roster equals the ten listed Logs screens in side-bar order;
    - a gate-refused member is read zero times and appears `shown` false with its pair;
    - a member 403 is handled the same way, and a member 500 fails the whole read;
    - window filtering;
    - the truncated-inside-window and outside-window cases, and the merged cut flagging sources;
    - `last` outside the window, and the 1,000-character cut;
    - merge order and ties;
    - the audit UTC → local conversion and the error date form;
    - `since` refused 400 before any member is read.
  - **New `Test/LogHubWire.cls`**, armed by `OCUPILOT_ALLOW_PRINCIPALS`:
    - seeds one eventlog entry in HSCUSTOM through `LogSecondarySeed`'s eventlog recipe;
    - checks that `GET /api/ocupilot/screens/logs.hub/read` and `logs.hub.read`'s `View` show the same newest rows and `sources`;
    - creates `%Manager`+`%DB_HSCUSTOM` principal. For it: hub 200; eventlog not shown, requiring `%Ens_EventLog:USE`, with no eventlog row; messages and alerts shown and their routes 200; Logs area verdict `true`;
    - removes the seed and the principal.
  - **New `Test/LogHubErrors.cls`**, armed by `OCUPILOT_ALLOW_ERROR_SEED`: seeds one HSCUSTOM application error through the existing guarded helper, and checks that `RecentErrors` and the hub row give its time form, `[HSCUSTOM] ` text and composite id.
  - Rows in `ReadTool` (128, plus `logs.hub.read`), `Navigation` (Logs 11, the hub at 11), `Descriptor` (`ReadShapes`, the hub leg, the area row) and `ScreenRead` (the timeline kind). Re-check `ScreenRead`/`LogSecondary` legs that pinned `truncated` for a tail.
  - Add the two classes to the `ci-throwaway.sh` roster comments and to `ui/tools/ci.test.mjs` (add-only).
- `ui/src/app/core/screen-arrival.ts`: an optional `entry: {time, text}` on `ScreenArrival`. Update the doc to say an arrival may also come from a person's choice in the log hub.
- `ui/src/app/areas/logs/log-hub.store.ts` (new, root). It holds:
  - `read(since?)` → `GET /api/ocupilot/screens/logs.hub/read`, with the hub ScreenStore's max rows;
  - `rows`, `sources`, `criteria`, `loading`, `error`;
  - `sourceFilter` and `severityFilter`;
  - `reset()`.
- `ui/src/app/areas/logs/log-hub.page.ts` (new):
  - The **Sources** section is a table with columns Source, Entries and Last entry, plus an Explain control:
    - Source is a link for a shown source, and `aria-disabled` with "Requires <resource>" otherwise;
    - Entries holds the count, followed by the cap sentence when the source is truncated;
    - Last entry shows time, severity chip and text on one line, or "No entries.".
  - The **Timeline** section has, in order:
    - the "Begin date and time" field with its hint and a Search button;
    - Source and Severity selects, each with "Any";
    - "Clear filter";
    - the notice banner, one line per source that is not shown;
    - the rows: the time as a link, the source label, the severity chip (none when `""`), the text and Explain.
  - Severity matches by word (`severityWord`), so "Debug" covers -2 and -1, and an entry with no severity matches only "Any". Source matches by route.
  - It registers Refresh, publishes the visible rows through `applyTick`, and follows the navigation rules above.
  - A pure helper computes the next second of a zone-less stamp without the browser's zone.
- `ui/src/app/areas/logs/log-viewer.page.ts`: take the route's arrival. After the first read settles, find the first line whose `stamp` equals the entry `time` and whose `raw` contains its `text` (less a trailing U+2026). Mark it `aria-current="true"` and highlight it, scroll it into view and focus it. Otherwise show the info banner "That entry is no longer in the loaded range."
- `ui/src/app/areas/logs/error-log.page.ts` and `error-log.store.ts`: on `logs/errors/<id>`, decode and split the id once, then `openNamespaces → openDates(ns) → openList(date) → openDetail(n)`. Nothing changes for the bare route.
- `ui/src/app/shell/screen-outlet.ts`: map `OcuPilot.Screen.Descriptor.LogHub` to `LogHubPage` in `DESCRIPTOR_PAGES`. `ui/src/app/app.ts` and `app.spec.ts`: reset `LogHubStore`, with a sibling assertion.
- `ui/src/app/core/strings.ts`, EXPERIENCE.md (the Design Notes strings folded into `:584`/`:585` in place, the `:90` edit and the `:627` sentence; line count unchanged at 993, no citation shift) and the regenerated `core/screens.generated.ts`. Also regenerate the IPM manifest if `ipm-manifest.mjs --check` asks for it.
- Client tests:
  - **New `areas/logs/log-hub.page.spec.ts`** covers:
    - the Sources list from `sources`, and counts from the filtered rows;
    - the not-shown notice with its exact text, and the cap sentence;
    - the three filters and "Clear filter";
    - each navigation family: the arrival `entry`; the audit criteria bracket plus the id route; the errors id route;
    - the explain payloads and the disabled reasons;
    - the `applyTick` rows.
  - Existing specs and tools gain cases or rows:
    - `log-viewer.spec.ts`: the arrival mark and the gone banner;
    - `error-log.page.spec.ts`: the id-route drill;
    - `tools/screen-arrival.test.mjs`: the `entry` member;
    - `explain-roster.spec.ts`: `LogHubPage`;
    - `tools/navigation.test.mjs`: the `logs/hub` route;
    - `screen-mirror.test.mjs`: the `timeline` refusal parity.
- **New `ui/browser/log-hub.browser-spec.mjs`**, on `ocupilot-ci` only, with `assertThrowaway`:
  - It seeds the six secondary stores through `secondary-log-spec.mjs`, plus one severity-2 console line.
  - It covers:
    - the Sources rows with their counts and last entries;
    - the timeline order;
    - the filters with counts updating;
    - a timeline entry's time opening `logs/eventlog` at that line, and an audit entry opening its dialog;
    - Explain sending that entry alone, read through `resultPayload`;
    - a `%Manager`+`%DB_HSCUSTOM` principal seeing the not-shown notice while messages and alerts stay;
    - the DW-1337 walk of the hub at wide light, narrow light and wide dark.
  - It removes what it seeded and the principal.

**Acceptance Criteria:**

- **AC1.** Given the hub on `ocupilot-ci`, when it opens, then the Sources list shows all ten Logs sources in side-bar order, each with its entry count for the window and its last entry (even one older than the window), and each shown source's name opens that source.
- **AC2.** Given a Sources row, when it renders, then it carries "Explain this entry", which sends that source's last entry alone. It is `aria-disabled` with "Requires <resource>" for a source that is not shown, and with "No entries." for an empty one.
- **AC3.** Given the Timeline, when the hub opens, then it holds every shown source's entries from the last hour (the "Begin date and time" field reads the instance's time an hour ago), newest first, each with time, source, severity where recorded, and text. Search with a changed begin re-reads.
- **AC4.** Given sources whose stores keep UTC (eventlog, SQL diagnostics, audit) and local time (the files, application errors), when merged, then every time is shown and ordered as instance-local `YYYY-MM-DDTHH:MM:SS.mmm`.
- **AC5.** Given each member, when the hub reads, then it goes through that screen's own gate and read at the per-source cap, and no caller value names a source, file, path or namespace. A source cut inside the window shows "This list was cut at the row cap — older entries are not shown."
- **AC6.** Given a `%Manager`+`%DB_HSCUSTOM` principal, when the hub opens, then the Logs area, the hub, messages.log and alerts.log stay open. The event log is left out without an error, and the notice reads "Not shown: Interoperability event log — requires %Ens_EventLog:USE."
- **AC7.** Given the Timeline, when the person filters by source, severity or text, then only matching entries remain, each source's Entries count updates to match, and "Clear filter" restores the rest.
- **AC8.** Given a timeline entry, when its time is chosen, then its source opens at that entry. On a viewer the line is marked and scrolled to (or "That entry is no longer in the loaded range."); on audit the event dialog opens; on application errors the error's detail opens. Its "Explain this entry" sends `{time, source, severity, text}` of that entry alone.
- **AC9.** Given the new strings, when this story lands, then they are in EXPERIENCE.md's Fixed strings and in `strings.ts`, pinned equal by `npm run test:tools`.
- **AC10 (Integration).** Given `ocupilot-ci` with seeded entries, when `LogHubPage` (consumer) reads `GET /api/ocupilot/screens/logs.hub/read` and the `logs.hub.read` tool reads the same composed read, then both show the same newest rows and the same `sources`. And when `LogViewerPage` (consumer) takes the hub's arrival, then it marks the chosen line. The hub passes the DW-1337 walk with no new allowance in both themes, and the bundle stays under 2004 kB (stop and ask at 3800 kB).

## Spec Change Log

- 2026-09-28T01:59Z, lead spec gate: (1) EXPERIENCE.md is edited in place with its line count unchanged (orchestrator's standing rule for shared-append files); the two new Fixed-strings rows are folded into the existing Story 16.8 lines `:584`/`:585` instead of added, so no citation shifts (Design Notes and Tasks updated). (2) The three spine changes under Design Notes are written into the spine by the lead in this gate's commit (AD-36 amended, Conventions › Dates, the Design Paradigm's `LogSourcePort` clause); the implement stage does not write them. (3) `src/OcuPilot/Screen/Timeline.cls`, `ui/src/app/app.ts` and `app.spec.ts` sit outside Epic 16's listed paths and are not contended; the lead reports them as footprint extensions.

## Review Triage Log

### 2026-09-28 — Review pass

- verdicts: 22 findings — high 0, medium 10, low 10, false 2, maybe-false 0 (plus one stage-agent finding, medium)
- findings:
  - `[medium]` `[patch]` VG: `Read.Execute` carrying the port's cut into `truncated` had no test — added `Test/LogSourceReadFixture.cls` and a declared-read leg in `LogSource` (long file: fewer rows than the cap, truncated 1; short file 0).
  - `[medium]` `[patch]` VG: AC4's UTC→local leg could not fail on a UTC instance and was clock-bound — `Timeline.LocalTime` seam; `LogHubFixture.Offset` runs the fixture clock +2h; the leg asserts the shifted times and the merge on them.
  - `[medium]` `[patch]` VG: `RecentErrors`' cap and `truncated` untested — `LogHubErrors` seeds a second error and pins cap 1 (newest row, cut) and an uncut read.
  - `[medium]` `[patch]` VG: the hub's Download CSV never ran — `log-hub.page.spec.ts` captures the Blob under Source + text filters.
  - `[low]` `[patch]` VG: `ScreenRead` timeline row-shape loop could run zero times — an unbounded (`since` "") read with a rows floor.
  - `[low]` `[patch]` VG: `LogHub` 403 leg guarded by `If $IsObject` — presence asserted first.
  - `[medium]` `[patch]` VG: CSV registration-only check (grouped with the CSV entry above).
  - `[low]` `[patch]` VG: AC1 and AC9 had no `mutation:` line — mutations applied, observed red, reverted, recorded in `## Verification`.
  - `[low]` `[reject]` VG: NFR-1 timing not recorded — it belongs in `## Auto Run Result`, which finalize writes; measured and recorded there.
  - `[low]` `[reject]` IA: Sources and Timeline stacked, not side by side — Design Note 1 reads "beside" as both sections on one page; side by side would force the 40rem table and 48rem rows into sideways scroll at the wide viewport. Not a direct correction.
  - `[medium]` `[patch]` IA: the instance-clock conversion is not observable on UTC instances (grouped with the AC4 entry above).
  - `[low]` `[patch]` IA: the tool schema said `sources` counts "these rows", but the count precedes the tool's own filter and cap — description corrected in `Tool/Read.cls`.
  - `[medium]` `[patch]` IA: Download CSV via a page action, untested (grouped with the CSV entry). `visible()` is the store's own view, so the file follows the screen.
  - `[false]` `[reject]` IA: an explicit empty `since` means no bound — the Tasks seed `since` "as any declared datetime criterion", whose convention is an empty string for an unset bound.
  - `[medium]` `[patch]` IA: nothing pinned that the real member read gives audit `beginDateTime` — extracted `Timeline.MemberCriteria`, pinned by a `LogHub` leg.
  - `[medium]` `[patch]` IA: no test combined a real member with truncation (grouped with the `Execute` port-cut entry).
  - `[low]` `[reject]` IA: the one-hour default is indistinguishable from UTC on a UTC instance — `HoursAgo` is pre-existing and unchanged. A clock seam in that shared method is not a direct correction.
  - `[low]` `[reject]` IA: "scrolled into view" not asserted, and focus moves — `focus()` scrolls the row into view itself, so a position check cannot discriminate, and the Tasks line says "focus it".
  - `[low]` `[patch]` IA: the audit browser leg waited for any dialog — it now asserts the Begin/End criteria read the entry's second and the next.
  - `[medium]` `[patch]` IA: hub → application error detail untested end to end — the browser spec seeds one USER error and walks a timeline error row to `[data-ocu-level="detail"]`.
  - `[low]` `[patch]` IA: the seeded browser row checked only "a last entry exists" — counts now include errors and audit, and eventlog/xdbc's last entry is the seed.
  - `[false]` `[reject]` IA: `Test/ErrorLog.cls` change outside the intent — a test adaptation that still asserts a cap-of-one cut, on a date holding two or more errors.
  - `[medium]` `[patch]` stage agent: the application error log's `last` was null when it had no error on or after the bound's date, against the intent's "whether or not it is inside the window". Fixed: `RecentErrorsRead` reads a namespace's newest date when none is on or after the bound (still bounded at `maxRows`+1 per namespace). `LogHubErrors` pins it with a bound of tomorrow. The Tasks line "dates on or after `since`'s date" now also reads that one date.

## Design Notes

**Members and projection** (this is the order of the side bar, and so of `sources` and of merge ties):

| member | read | `time` | `severity` | `text` | `id` |
|---|---|---|---|---|---|
| `logs/alerts`, `logs/messages` | own declared read (`Rows` → `Page` tail) | as read (`HeadParts`) | the file's digit | as read | `""` |
| `logs/errors` | `RecentErrors` behind `LogErrorList`'s gate (it declares no read, and adding one would draw a filter on a Release 1 screen) | `MM/DD/YYYY` + `HH:MM:SS` → the form | `2` (every entry is an error trap; "Severe") | `[NS] <errorText>` (summary fields only, AD-48) | `JoinComposite(ns, date, errorNumber)` |
| `logs/audit` | own declared read, `beginDateTime` = `since` (AdminPort async and AuditPort mask unchanged) | `UTCTimeStamp` → local via `LocalFromUtc` | `""` | `<EventSource>/<EventType>/<Event>`, then `: <Description>` when not empty; never `EventData` | `JoinComposite(UTCTimeStamp, SystemID, AuditIndex)` |
| the six secondaries | own declared reads (`Rows` → `Recent`) | as read | as read | as read (`[NS] ` prefix kept) | `""` |

**Decisions.**

1. **One page, both views visible.** The owner's paragraph says the timeline sits "beside its list of sources", and the counts must update visibly as the timeline is filtered. The two are therefore sections of one page over one read, not two routes behind the command bar's View control, whose options are navigations.
2. **The count is the window's.** It is the source's entries in the answer under the active filters. A total over the whole source would need an unbounded read, and it could not "update to match" a filter. The last entry ignores the window and the filters, so a quiet source still says where to look.
3. **Single-select filters, as in Release 1** (EXPERIENCE.md `:648`). The text filter is the command bar's own field, so screen context, the page and Download CSV agree through one `applyView`.
4. **Truncation words** are the error log's cap sentence (`:329`). The log viewers render no truncation sentence of their own.
5. **Audit bracket:** begin is the entry's second and end is the next second. `(inference)` The vendor's end bound's inclusiveness is unmeasured; the bracket holds either way.
6. **`Rows`' port cut** makes `logs.messages.read` and the other logsource tools say `truncated` when older lines were not read. This is a correction under AD-36, not a regression.
7. **Timing.** The hub runs ten reads, audit's async among them. The implement stage times the read on `ocupilot-ci` with the seeds and records it against NFR-1 (2 s at 1,000 rows).

**Spine change for the lead** (Rule 20). It is consistent with AD-5's "a page may issue another built screen's declared read" and with AD-36's bounded one-read rule, so it does not block:

- (a) Append to AD-36:

  > **A declared read may compose its area's listed screens' reads** [AMENDED 2026-09-27, Story 16.9 spec gate, Rule 20]. The log hub's read (`source.port` `timeline`) runs each other listed Logs screen's own read in side-bar order in the caller's process: that screen's gate first, then its own executor, criteria and row cap. The application error log, which declares no read, goes through `LogSourcePort`'s bounded newest-errors reader behind the same gate. A member the caller may not read is left out and named with its failed pair; any other member fault fails the whole read. Rows are projected to `{time, source, severity, text, id}` on the instance's clock, windowed by one `datetime` criterion, merged newest first and cut to the row cap. The answer carries `sources`, a per-member summary, beside the rows, in the screen's answer and the tool's view alike. It never widens a read: every row is one its own screen would show the caller.

- (b) Conventions › Dates, append: "A log entry's `time` is the instance's local clock time as `YYYY-MM-DDTHH:MM:SS.mmm` with no zone, the form the log viewers show; a store that keeps UTC is converted on the instance, and the log hub windows and orders on that form (Stories 16.8, 16.9)."
- (c) In the Design Paradigm's `LogSourcePort` description, after "the `^ERRORS` global", insert: "(also read newest first across the readable namespaces for the log hub)".

**Fixed strings rows.** EXPERIENCE.md is edited IN PLACE with its line count unchanged (993 lines; lead ruling at the spec gate, the orchestrator's standing rule for shared-append files while two slots edit it). So the two rows below are NOT added as new lines: their quoted strings and their "where used" text are folded into the two existing Story 16.8 lines, the strings row `:584` and the prompts row `:585`, each gaining the Story 16.9 part after its own text with its own `[ADDED 2026-09-27 - Story 16.9]` tag. No citation shifts. The content to fold in:

> `| "Unified log hub" · "Sources" · "Timeline" · "Entries" · "Last entry" · "Not shown: <source> — requires <resource>." · "That entry is no longer in the loaded range." | the unified log hub (Story 16.9, FR-77): its side-bar entry and screen title, the eleventh Logs entry (`:90`, `:163`); its two section headings; the Sources list's count and last-entry column headers beside the reused "Source" and "Explain this entry" (`:268`), a truncated source reading the application error log's cap sentence (`:329`) and a source the user may not read reading "Requires <resource>" (`:294`); the timeline's notice, one line per source left out, naming the privilege it needs; and the sentence a log viewer (`:629`) shows when the entry it was opened at from the hub's timeline has left its loaded range [ADDED 2026-09-27 - Story 16.9] |`

> `| "Which logs recorded errors in the last hour?" · "What happened just before the most recent error, across every log?" · "Which log should I open first to investigate, and why?" | the unified log hub's suggested prompts (Story 16.9, AD-5): Troubleshooting group, declared on its descriptor [ADDED 2026-09-27 - Story 16.9] |`

- **Keys.** `logHubLabel`, `logHubSourcesHeading`, `logHubTimelineHeading`, `logHubColumnEntries`, `logHubColumnLastEntry`, `logHubNotShown` (`—` escaped), `logViewerEntryGone`, and `logHubPrompt1-3`. Every other word on the page is reused (Code Map).
- **No citation shift.** The line count is unchanged, so no `/** EXPERIENCE.md:n */` citation moves; `npm run test:tools` must still pass, and `wc -l` on EXPERIENCE.md must still read 993.
- **Edit `:90` in place.** Its fourth cell becomes "secondary viewers, and the hub: every source with its count and last entry and an explain entry point, beside a timeline merging every readable source newest first over a window (default the last hour), filtered by source, severity and text, each entry opening its source at that entry (FR-77, Story 16.9)".
- **Append to the log-viewer row (`:627`, in place):** "Opened from the log hub's timeline, a viewer marks the chosen line (`aria-current`) and scrolls to it, or says "That entry is no longer in the loaded range."."

**Governing ADs:**

- the read and the screen: AD-5, AD-36 (amended above), AD-24, AD-8, AD-29, AD-21;
- the sources: AD-48, AD-26, AD-35, AD-2/AD-27 (audit only through its read);
- navigation and the client: AD-11 (a person-initiated arrival; criteria never in the URL), AD-13, AD-16, AD-19, AD-20;
- errors, the model and refresh: AD-12/AD-39, AD-60 (the sanitizer by construction), AD-43 (no auto-refresh);
- AD-44 (no classic page), AD-22 (reads only; no governance key);
- Conventions › Dates (amended above).

**Integration.**

- **Consumes:**
  - 16.8's `Rows`/`Recent`, the tails, `LocalFromUtc` and `ReadableNamespaces`;
  - `Screen.Gate.Evaluate`, `Screen.Read.Execute`, and `AuditList`'s read (AdminPort async and `AuditPort.MaskVendorSecrets`);
  - `SYS.ApplicationError` through `ErrorsRead`;
  - `Kernel.EntityId`;
  - `ScreenArrivals` (11.11), `ExplainEntry` (11.2), `ScreenStore`/`applyView` (4.11), and 16.23's Download CSV;
  - `structural-walk.mjs` (15.6).
- **Consumed-by:** no later story is planned. The consumers are this story's own `LogHubPage`, `logs.hub.read` and `LogViewerPage`'s arrival (AC10).

**Ledger.** The inbox is empty, and no entry is declined. Governance is unchanged, because only a read tool is added.

## Verification

**Commands** (slot A). Everything that seeds or creates a principal runs on the `ocupilot-ci` throwaway only (mutates the shared runtime). Every browser run sets `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`, and first rebuilds the bundle and runs `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`.

- `cd ui && npm run test:tools` (loop). Expect green: `screen-mirror`, `strings` (rows, citation shift), `navigation`, `screen-arrival` and `ci` (roster). Mutation: the mirror accepts a `timeline` read outside `logs` → the parity case goes red.
- `cd ui && npx ng test --include src/app/areas/logs/log-hub.page.spec.ts --include src/app/areas/logs/log-viewer.spec.ts --include src/app/areas/logs/error-log.page.spec.ts --include src/app/areas/logs/audit.page.spec.ts --include src/app/areas/logs/explain-roster.spec.ts --include src/app/app.spec.ts --include src/app/shell/screen-outlet.spec.ts --include src/app/shell/side-bar.spec.ts --include src/app/shell/command-box.spec.ts` (loop). Expect green. Mutations to apply and observe:
  - counts computed from unfiltered rows → the AC7 case goes red;
  - the source-row explain sends every row → the AC2 case goes red;
  - the viewer ignores the arrival → the AC8 mark case goes red;
  - drop the `LogHubStore` reset → the `app.spec.ts` case goes red.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class <C>` (loop), one class per call. `<C>` is each of: `OcuPilot.Test.LogHub`, `LogHubWire`, `LogHubErrors`, `LogSecondary`, `LogSecondaryWire`, `LogSource`, `LogSourceDenial`, `ErrorLog`, `ScreenRead`, `ScreenReadWire`, `Descriptor`, `Navigation`, `Wire`, `WireSecurityRead`, `ReadTool`, `EndpointCoverage`, `SurfaceCoverage`, `PromptCorpus`. Expect green. Mutations to apply and observe:
  - AC5: read a refused member → the `LogHub` zero-read leg goes red;
  - AC5: ignore a member's truncation → the truncated-inside-window leg goes red;
  - AC4: skip `LocalFromUtc` for audit → the conversion leg goes red;
  - AC3: sort ascending → the merge leg goes red;
  - AC6: add `%Ens_EventLog:USE` to the hub's privileges → the `LogHubWire` least-privilege leg goes red, and the hub answers 403;
  - AC10: `View` drops `sources` → the `LogHubWire` route/tool leg goes red.
- `cd ui && npm run build && docker cp … && node --test --test-concurrency=1 browser/log-hub.browser-spec.mjs browser/secondary-logs.browser-spec.mjs browser/messages-log.browser-spec.mjs browser/alerts-log.browser-spec.mjs browser/audit.browser-spec.mjs browser/error-log.browser-spec.mjs browser/explain-entry.browser-spec.mjs browser/a11y-structural-invariants.browser-spec.mjs browser/screen-height.browser-spec.mjs` (loop). Expect green within the structural baseline. Mutation: the time link opens the bare route with no arrival → the AC8 leg goes red, on a rebuilt and redeployed bundle.
- `cd ui && npm test`, `uv run scripts/check-objectscript.py`, `bash scripts/lint-docs.sh` (once, before dev_complete). Expect green, and the bundle under 2004 kB. Record the hub read time for NFR-1.
- The full ObjectScript sweep on `ocupilot-ci`, one class at a time (once, before dev_complete). Expect green. The full browser suite runs in CI, not locally (Rule 29).

**Mutations observed (Rule 19, each reverted byte-identical; ObjectScript on `ocupilot-ci` with subclasses recompiled, the browser one on a rebuilt, redeployed bundle):**

- mutation: `screen-mirror.mjs` `timelineProblem` accepts a timeline outside `logs` → `screen-mirror.test.mjs` ReadSourceCorpus case red.
- mutation: `timelineMemberProblem` drops its listed-member test → `screen-mirror.test.mjs` timeline-member case red.
- mutation: Sources counts from unfiltered rows → `log-hub.page.spec.ts` AC7 case red.
- mutation: a Sources row's Explain sends every row → `log-hub.page.spec.ts` AC2/AC8 case red.
- mutation: `LogViewerPage` ignores the arrival → `log-viewer.spec.ts` two Story 16.9 cases red.
- mutation: `ErrorLogPage` ignores its id route → `error-log.page.spec.ts` id-route drill red.
- mutation: `app.ts` drops `logHub.reset()` → `app.spec.ts` sign-out case red.
- mutation: `Timeline.Compose` reads a refused member → `LogHub` zero-read leg red.
- mutation: `Timeline.Compose` ignores a member's cut → `LogHub` truncation leg red.
- mutation: `Timeline.Project` projects the audit stamp with `ClockStamp` instead of `LocalTime`, under the fixture's +2h clock → `LogHub` projection leg red.
- mutation: `Timeline.Compose` merges ascending → `LogHub` merge, window, cut and projection legs red.
- mutation: `Read.Execute` timeline branch skips the bound refusal → `LogHub` bad-bound leg red.
- mutation: `Registry.TimelineProblem` accepts any area → `ReadTool` ReadSourceCorpus leg red.
- mutation: `%Ens_EventLog:USE` added to `LogHub`'s privileges → `LogHubWire` principal leg red, the hub answering 403 naming that pair.
- mutation: `Tool.Read.View` drops `sources` → `LogHubWire` route/tool leg red.
- mutation: `Read.Execute` drops `sources` → `ScreenRead` timeline executor leg red.
- mutation: `LogSourcePort.Rows` drops the tail's size cut → `LogSource` tail-cut leg red; drops `Recent`'s cut → `LogSecondary` merge leg red.
- mutation: `RecentErrors` drops the `[NS] ` prefix → `LogHubErrors` red.
- mutation: `LogHubPage.onOpenEntry` sets no arrival → `log-hub.browser-spec.mjs` AC8 viewer leg red.
- mutation (AC1): `Timeline.Members` keeps a timeline, so the hub joins its own roster → `LogHub` roster leg red; `Compose` takes `last` from window rows only → `LogHub` last-entry leg red; `RecentErrorsRead` reads no date before the bound → `LogHubErrors` last-entry legs red.
- mutation (AC9): `strings.ts` `logHubLabel` reads 'Unified log hubs' → three `tools/strings.test.mjs` parity cases red.
- mutation: `Read.Execute` drops the port's cut → `LogSource` declared-read leg red; `Timeline.MemberCriteria` gives audit no begin → `LogHub` begin leg red.
- mutation: `RecentErrors` answers `truncated` 0 → `LogHubErrors` cap leg red; skips the per-namespace gate → `LogHubErrors` namespace leg red.
- mutation: `LogHubPage.downloadCsv` writes `hub.rows()` → `log-hub.page.spec.ts` CSV case red.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** `logs/hub` ("Unified log hub"): the `timeline` read kind (`Screen/Timeline.cls`) gates and reads each listed Logs screen through its own gate and read. The application error log is read through `LogSourcePort.RecentErrors`. Rows are projected to the instance clock, windowed by `since`, merged newest first, and answered with `sources`. `LogHubStore` and `LogHubPage` (Sources and Timeline, three filters, open-at-entry, Explain) sit on the client; the log viewer marks an arrival entry, the error log drills its id route, and `Rows` reports the port's own cut.

**Files.**

- Server: `Screen/Timeline.cls`, `Screen/Descriptor/LogHub.cls` (new); `Port/LogSourcePort.cls` (`RecentErrors`, the `Rows` cut), `Screen/Read.cls` (timeline branch), `Screen/Registry.cls` (`TimelineProblem`, `TimelineMemberProblem`), `Screen/Tool/Read.cls` (`sources`), `Api/ScreenRead.cls` (doc).
- Server tests: `LogHub`, `LogHubWire`, `LogHubErrors`, `LogHubFixture`, `LogHubReadFixture`, `LogSourceReadFixture` (new); legs or rows in `Descriptor`, `Navigation`, `ReadTool`, `ScreenRead`, `LogSource`, `LogSecondary`, `WireSecurityRead`, `SurfaceCoverage`, `ErrorLog`, `ReadSourceCorpus`, `CriteriaCorpus`, `AdminPairCorpus`.
- Client: `log-hub.store.ts`, `log-hub.page.ts` (new); `log-viewer.page.ts`, `error-log.page.ts`, `error-log.store.ts`, `screen-arrival.ts`, `csv.ts` (`saveCsv`), `screen-outlet.ts`, `app.ts`, `strings.ts`, `_components.scss`, `screens.generated.ts`, `tools/screen-mirror.mjs`.
- Client tests: `log-hub.page.spec.ts`, `browser/log-hub.browser-spec.mjs` (new); cases in `log-viewer.spec.ts`, `error-log.page.spec.ts`, `explain-roster.spec.ts`, `app.spec.ts`, `tools/navigation.test.mjs`, `tools/screen-arrival.test.mjs`, `tools/screen-mirror.test.mjs`.
- Docs and rosters: EXPERIENCE.md in place (993 lines; `:627` cited for the log viewer where the Design Notes quote `:629`); `scripts/ci-throwaway.sh` roster comments (add-only).

**Review.** 22 layer findings plus one stage finding (triage log). 17 were patched, as 7 medium entries and 6 low. None was deferred. Rejected: NFR-1 not recorded (recorded here), the stacked layout (Design Note 1), the UTC default hour (pre-existing `HoursAgo`), and scroll-into-view (`focus()` scrolls). False: the empty `since` and the `ErrorLog` test adaptation. Follow-up review recommended: 7 medium entries patched. The named risk: `RecentErrorsRead` now reads each namespace's newest pre-window date on most hub reads, bounded at `maxRows`+1 per namespace. It was timed only on `ocupilot-ci`'s few namespaces and is unmeasured with many namespaces holding large error dates.

**Verification.**

- `npm run test:tools`: 1,613 green. `npm test`: 1,613 tools and 1,615 component tests green. `check-objectscript`: 0 problems. `lint-docs`: 0 issues.
- Targeted classes on `ocupilot-ci`: green. The Matrix audit added legs for the fresh default, the namespace skip, the member fault and a caller naming a source. Every mutation line in `## Verification` was observed red and reverted byte-identical.
- Browser: `log-hub` 6/6. The spec's other loop files: 58/60. The 2 `alerts-log` failures are throwaway residue: its seeded 1970 lines, written once, now sit outside the 64 KB tail of a 169 KB `alerts.log`.
- Full ObjectScript sweep on `ocupilot-ci`: 332 classes, 2,587 tests, 5 failed, plus 19 classes refused at `OnBeforeAllTests`. All of it is residue: arming variables this throwaway lacks (`TASK_CONTROL`, `ERROR_DELETE`, `AUDIT_PURGE`, `AUDIT_TOGGLE`, `ACCOUNT_PREFERENCES`, `PROCESS_CONTROL`, `SERVICE_CONFIG`); `WireSecurityRead`'s task-history leg (DW-1425/DW-1468); three `TaskHistory` demo-run legs, likely the same old-row residue (inference); and `Retention` finding expired rows from older suites. Every Logs and story class is green.
- NFR-1: the hub read over HTTP at 1,000 rows takes 0.19–0.21 s. Bundle: 2,002,678 bytes (main 1,831,897 + styles 170,781), under the 2004 kB warning with no budget message.

**Residual risk.** The handoff subagent loaded ten classes into the dev instance `ocupilot`, which holds an older tree, and then restored eight from `d757343a` and deleted `LogHub`/`Timeline`. Registry `Validate` passes and the audit read answers 200 there, but `Screen/Registry.cls` may not be byte-identical to what it held.
