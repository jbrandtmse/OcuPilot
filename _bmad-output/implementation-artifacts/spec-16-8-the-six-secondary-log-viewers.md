---
title: 'Story 16.8: The six secondary log viewers'
type: 'feature'
created: '2026-09-27'
status: 'done'
baseline_revision: '95515d9d55100694da203a8cdb3fb4eaef7523ff'
baseline_commit: '4ace0f45eaa80442913cad545a475af0b3b19409'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-16-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The Logs area shows only alerts.log, messages.log, the application errors and the audit database. The instance keeps six more logs: the System Monitor log, background task errors, xDBC errors, SQL diagnostics, the interoperability event log and the analytics log. Today they are readable only in the classic portal, so "all the logs" is not true. Separately, the viewer's next/previous-match controls exist only as Enter and Shift+Enter (DW-1102), and its store survives a sign-out (DW-1110).

**Approach:** `LogSourcePort` gains six fixed-enum source keys, all served through one new entry point, `Recent`. `Recent` answers the newest entries as rows, bounded by the read's row cap. Four of the logs are kept per namespace; for those, the port merges the entries from every namespace the caller can read. Each source has a descriptor, a route and a `SOURCES` entry, and the shared viewer renders them in a new entries mode. The viewer also gains two match controls, and its store joins the sign-out teardown.

## Boundaries & Constraints

**Always:**

- **Fixed enum (AD-21).** Each route binds its own key and accepts no path. The keys are `systemmonitor`, `taskerrors`, `xdbc`, `sqldiagnostics`, `eventlog` and `analytics`.
  - Each route is `GET /api/ocupilot/logs/<key>` and reads no query parameter.
  - A `file` parameter is refused with 400 `LOG.FILE`, as on alerts.log.
  - The two files, `SystemMonitor.log` and `DeepSeeTasks_<NS>.log`, are named in the port.
  - For the four per-namespace sources, the namespace comes only from the set the caller can read (`Kernel.Shell.Namespaces`' `Payload`, through `NamespaceResolver()`, AD-48). It is never a caller string, and the route's `?ns=` never reaches the port.
- **Gate first (AD-29, AD-8).** `Recent` checks in this order: the enum, then the source's pair set, then each namespace's pair set, then the reads. Nothing above the gate touches a store. A namespace whose pairs fail is left out. A read that faults after its gate fails the whole answer with `LOG.UNREADABLE`, never a partial list (AD-36).
- **One read for screen and tool (AD-36).** The route and `Rows` go through the same `Recent`, under the declared read's row cap.
  - `Rows` projects each entry to `{time, severity, text}`, newest first, and never includes `pid` or `raw`.
  - The route answers `{source, entries: [{time, pid, severity, text, raw}], truncated}`, newest first.
- **Row shape (Design Notes table).**
  - `time` is instance-local `YYYY-MM-DDTHH:MM:SS.mmm`, the form `HeadParts` gives messages.log. A UTC store time is converted.
  - `severity` is on the console scale -2..3, as text.
  - A per-namespace entry's `text` begins `[<NAMESPACE>] `.
  - `raw` is `<time> (<pid>) <severity> <text>`.
  - Captured stacks (`Ens_Util.Log.Stack`) and client connection details are never read.
- **Shared viewer (AD-5, AD-19).** The six screens reuse `LogViewerPage` and `LogViewerStore` in an entries mode. Search with highlight and "n of N", the two new match controls, jump top/bottom, the chips, Raw, per-row Explain (one entry alone) and `publishRows` behave as on alerts.log. Load newer re-reads the newest window and jumps to the bottom. There is no cursor, and the file choice stays messages-only.
- Copy comes verbatim from the Fixed-strings rows in Design Notes. Each screen declares three prompts in the Troubleshooting group.

**Never:**

- No write tool, delete, governance key or `Gate.cls` change. No change to messages.log's or alerts.log's `Page` behavior, the 16.20 file choice, `panel.ts` or the agent's navigation.
- No namespace choice in the UI, and no `namespace` parameter anywhere.
- No `DeepSeeUpdate_*` file, no `.old` generation, and no direct `^%sqlcq`, `^Ens.Util.LogD` or `^IRIS.Temp.MgtPortalTask` traversal in product code. Reads go through the vendor readers the Design Notes name.
- No lazy route or `@defer`.
- Stay off Epic 14's hunks (Design Notes). The one it cannot avoid is the blocking condition.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Seeded | one entry seeded in each store, in HSCUSTOM where scoped | each viewer lists it with its time, pid, severity word and text; the scoped ones read `[HSCUSTOM] …` | — |
| Fresh stock | nothing seeded | the System Monitor log shows its own lines; the other five show "No entries." | no refusal, no fault |
| Readable set | caller reads HSCUSTOM, not USER | only HSCUSTOM's entries | the USER namespace is skipped, and that is not a fault |
| Predicate | namespace not interop-enabled, or no `DeepSeeTasks_<NS>.log` | contributes nothing to eventlog/analytics | — |
| No privilege | caller lacks the screen's pair | 403 naming the pair; zero reader calls | — |
| Search, Raw, Explain | search the seeded text | "1 of 1" and a highlight; Raw shows its `raw`; Explain sends that entry's `{time, severity, text}` alone | — |
| Match controls | 3 matches | Next match goes 1→2→3→1 and Previous match goes back; the count announces the position | — |
| Many | more than the cap across namespaces | newest `cap` entries, `truncated` true | — |
| Load newer | an entry seeded after opening | it appears at the tail | — |
| Bad param | `GET /logs/xdbc?file=x` | 400 `LOG.FILE` | — |
| Old entry point | `Page("xdbc")` | refused; `Page` serves messages and alerts only | — |
| Vendor fault | a gated namespace read raises `<PROTECT>` or `SQLCODE`<0 | 500 `LOG.UNREADABLE` | never partial, never read as empty |
| Sign-out | sign out, then another principal signs in in the same tab | the viewer holds none of the first principal's rows | — |

</intent-contract>

## Code Map

Server (`src/OcuPilot/`):

- `Port/LogSourcePort.cls`:
  - `SOURCES` `:63` and the per-key parameters `:66-123`; add the new parameters after `:118`.
  - `PairsFor` `:339` (an `If` chain) and `ErrorPairSpec` `:355`, the per-namespace `resource:READ` pattern to reuse.
  - `NamespaceResolver` `:418`, `FileFor` `:450`, `Page` `:537` (step order `:544-627`).
  - `Rows` `:656`; `Entries` `:683` (private, so the name is taken); `HeadParts` `:727-746`.
  - `Gate` `:1736`, `ReadWindow` `:2023` (tail by seeking back), `Refuse` `:2115`, `Fail` `:2125-2131`.
  - Epic 14 appends after `Fail` (HEAD `:2132`). **Add methods after `HeadParts` (`:746`), never at the end.**
- `Kernel/Shell/Namespaces.cls`: `Payload` `:109` is the readable set; `GlobalDatabase` `:84`.
- `Screen/Read.cls:269-276`: the `logsource` branch calls `Rows(endpoint, tMax + 1)`. Unchanged.
- `Api/LogPage.cls` `Handle` `:37`, `HandleFiles` `:54`, `Answer` `:67`.
- `Api/Router.cls`: UrlMap logs routes `:117-123`; add after `:123`. Wrappers `LogMessages` `:705`, `LogMessageFiles` `:713`; add after `:717`. Epic 14 inserts before `LogAlerts` (`:784`) and after `:130`/`:132`.
- `Api/Error.cls`: LOG codes `:306-380`. No new code is needed.
- `Screen/Area.cls:117`: the `logs` pair union.
- Descriptors to copy: `Screen/Descriptor/LogAlertViewer.cls` and `LogMessageViewer.cls`. `log-entry` is already in `Kernel/EntityType.cls:37`.
- Tests:
  - `Test/LogSourceFixture.cls:97` (`Sources()` falls back to `##super`).
  - `Test/LogSource.cls:176,:221`, `Test/LogSourceDenial.cls`, `Test/LogPairs.cls:33`, `Test/ErrorLog.cls:520`.
  - `Test/EndpointCoverage.cls:106-112`, `Test/SurfaceCoverage.cls:73-76`.
  - `Test/Descriptor.cls` `ReadShapes` `:82-83`, per-screen `:953-1009`, area `:1656`.
  - `Test/Navigation.cls:357-374` (Logs has 4 screens), `:228/:257/:267`.
  - `Test/Wire.cls:400-401`, `Test/ReadTool.cls:93-94,:112`.
  - `Test/LogOlderFilesWire.cls`, the arming and seeding precedent.
  - `scripts/ci-throwaway.sh:189`, the `OCUPILOT_ALLOW_LOG_ROTATION` roster.

Client (`ui/src/app/`):

- `areas/logs/log-viewer.store.ts`:
  - `LogViewerSource` `:12-22`; `ALERTS_SOURCE` `:25`.
  - `read()` `:302-355`; `reset()` `:149`, whose doc names DW-1110.
- `areas/logs/log-viewer.page.ts`:
  - `SOURCES` `:56-59`.
  - Bar `:101-146`; the doc paragraph on Enter/Shift+Enter `:92-94`.
  - `publishRows` `:333`, `onExplain` `:433`, `onSearchKey` `:553`, `step` `:574-583`.
- `areas/logs/log-line.ts`: `LogLine`; `severityWord` and the chips.
- `app.ts`: injections `:247-248`; teardown `:543-652` (`errorLogDrill.reset()` `:562`).
- `app.spec.ts`: the per-store teardown assertions `:1065-1069` and `:1183-1187`.
- `core/strings.ts`: log keys `:1093-1130`; prompts `:2214-2230`; `taskCreate` `:1951` cites `EXPERIENCE.md:624`; append before `} as const` `:3108`.
- Specs:
  - `areas/logs/log-viewer.spec.ts`, including `:297-301` (key path) and `:400-427` (every built `log-viewer` descriptor's first request is `/api/ocupilot/logs/<endpoint>`).
  - `areas/logs/explain-roster.spec.ts:27-41`.
- `ui/browser/`:
  - `messages-log-files.browser-spec.mjs` and `older-file-spec.mjs`, the docker-exec seed, `assertThrowaway` and walk precedents.
  - `explain-entry.browser-spec.mjs:122-167`, the `screen_context` capture.
  - `structural-walk.mjs`, which walks every built screen with no baseline entry.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Port/LogSourcePort.cls`:
  - Add the six keys to `SOURCES`, with `*KEY`/`*PAIRS` parameters, `SYSTEMMONITORFILE = "SystemMonitor.log"` and `ANALYTICSFORM = "DeepSeeTasks_<NS>.log"`.
  - Extend `PairsFor`: each key's instance pairs, plus `<globals-db resource>:READ` when a namespace is given for `sqldiagnostics` and `eventlog`.
  - `Page` refuses the new keys, as it refuses `applicationerrors`.
  - New `Recent(pSource, pMaxRows, Output pResult, Output pHttpStatus, Output pFault)`: enum, instance gate, then per-namespace sources over the readable set filtered by the source's predicate and gated per namespace. It calls a reader seam per source, merges by time descending, cuts to the cap with `truncated`, and restores the namespace (AD-16).
  - `Rows` delegates the new keys to `Recent`.
  - Correct the class doc at its origin. Put the new code after `HeadParts`.
- `src/OcuPilot/Port/LogRecords.cls` (new, called only by `LogSourcePort`): six readers, one per Design Notes row, each answering entries for one scope, bounded to `pMax`. It also holds the two line grammars (System Monitor, analytics).
  - The SQL readers switch into the target namespace by explicit save and restore, with the restore as the first line of every `Catch`. They check `%SQLCODE` and `%Next(.sc)`, so a `<PROTECT>` is a fault, not an empty result.
  - Nothing inside the switched frame calls an OcuPilot class.
- `src/OcuPilot/Api/LogPage.cls`: new `HandleRecent(pSource)`. It refuses `file` with `LOG.FILE`, calls `Recent` with the declared read's default cap, and writes through `Answer`.
- `src/OcuPilot/Api/Router.cls`: six `<Route Url="/logs/<key>" Method="GET" Call="Log<Key>"/>` after `:123`, and six thin wrappers after `:717`, each binding its key parameter.
- `src/OcuPilot/Screen/Area.cls:117`: add `%Ens_EventLog:USE` and `%DeepSee_Portal:USE` to `logs`.
- `src/OcuPilot/Screen/Descriptor/`: new `LogSystemMonitorViewer`, `LogTaskErrorViewer`, `LogXdbcViewer`, `LogSqlDiagnosticsViewer`, `LogEventViewer` and `LogAnalyticsViewer`, shaped as `LogAlertViewer`.
  - `route` `logs/<key>`, `toolIdentifier` `logs.<key>`, `read.source.endpoint` `<key>`, `sideBarPosition` 5-10 in that order.
  - `privileges`, `classicPage`, `labelKey`, prompts and `commandAliases` come from Design Notes.
- Tests:
  - New `src/OcuPilot/Test/LogSecondary.cls`, over a `LogRecords` fixture seam. It pins:
    - zero reader calls before the gate and for a failed namespace;
    - the readable-set and predicate filter;
    - per-source mapping (time conversion, severity, the `[NS]` prefix, pid, `raw`);
    - merge order, cap and `truncated`;
    - `Page` refusing a new key, and `Rows` projecting `{time, severity, text}`;
    - a fault failing the whole read.
  - New `src/OcuPilot/Test/LogSecondaryWire.cls`, armed by `OCUPILOT_ALLOW_LOG_ROTATION` (it writes the manager directory). It seeds one entry per store with the Design Notes recipes, reads each route over HTTP (one envelope, entry present, severity), and removes exactly what it seeded. It also pins the column sets of `%SQL.Manager.Catalog:XdbcErrors` and `%CSP.UI.System.BackgroundTask:EnumerateTasks`/`ErrorLog`, because both are vendor-internal.
  - `LogSourceDenial.cls`: per route, without the pair the answer is 403 naming it; with the pair alone it is 200 (eventlog: `%Ens_EventLog:USE` plus `%DB_HSCUSTOM:READ`).
  - Add rows to `EndpointCoverage`, `SurfaceCoverage`, `Descriptor` (`ReadShapes`, area row), `Navigation` (Logs count 10, indexes 5-10), `LogPairs`, `Wire` (area verdicts) and `ReadTool` (count and names; **contended**).
  - `LogSource.cls`: a key/pair test for each new key.
  - `scripts/ci-throwaway.sh:189`: add `LogSecondaryWire` to the roster comment.
- `ui/src/app/areas/logs/log-viewer.store.ts`:
  - `LogViewerSource.entries?: true`.
  - In entries mode `read()` issues a bare GET and maps `entries` to `LogLine`s, oldest first, `head` true, with no cursor and no file list.
  - `loadNewer()` re-reads the window.
  - Remove the DW-1110 sentence.
- `ui/src/app/areas/logs/log-viewer.page.ts`:
  - Add six entries-mode sources to `SOURCES`.
  - Add "Next match" and "Previous match" `ocu-button-text` buttons after the count, calling `step(1)` and `step(-1)` (`data-ocu-log="next"`/`"previous"`).
  - Replace the `:92-94` paragraph. Show Load newer in entries mode.
- `ui/src/app/app.ts`: inject `LogViewerStore` and call `reset()` in the sign-out teardown (DW-1110). `app.spec.ts`: a sibling assertion.
- `ui/src/app/core/strings.ts`, `EXPERIENCE.md` (two rows, edits in place, the citation shift) and the regenerated `ui/src/app/core/screens.generated.ts` (`node tools/screen-mirror.mjs`).
- Client tests:
  - `log-viewer.spec.ts`: entries mapping and order, no query on the read, Load newer re-reads, match buttons with their names and wrap, `publishRows` for an entries source, and no file choice. Update `:400-427` if it assumes a cursor.
  - New `ui/browser/secondary-logs.browser-spec.mjs`, on `ocupilot-ci` only, with `assertThrowaway`. It seeds one entry per store, then covers:
    - each screen's seeded row;
    - search "1 of 1" and the match buttons;
    - Raw;
    - Explain on the eventlog row sending that entry alone, and a typed turn's `screen_context` holding it;
    - the DW-1337 walk of the six seeded screens, plus Home, at wide light, narrow light and wide dark.
  - It removes what it seeded.

**Acceptance Criteria:**

- **AC1.** Given `ocupilot-ci` with one entry seeded in each of the six stores, when each viewer opens, then that entry renders in the shared log viewer, and search with highlight and "n of N", jump top and bottom, and Raw work on it as on alerts.log.
- **AC2.** Given any of the six routes, when it is called, then the source is fixed by the route: no path, file name or namespace is accepted, and a `file` parameter is refused 400 `LOG.FILE`. A per-namespace source reads only the namespaces the caller can read, and a caller without the screen's pairs gets a 403 naming the pair before any store is read.
- **AC3.** Given a row in any of the six viewers, when "Explain this entry" is pressed, then that entry alone is sent. A typed turn's screen context carries the rows on screen.
- **AC4.** Given a fresh stock container with nothing seeded, when each viewer opens, then the System Monitor log shows its own lines and the other five show "No entries.", with no refusal and no fault.
- **AC5 (DW-1102).** Given a search with matches, when "Next match" or "Previous match" is pressed, then the caret moves to the next or previous match (wrapping) and the polite count announces it. Both controls carry those accessible names.
- **AC6 (DW-1110).** Given a principal who read a log viewer, when they sign out, then `LogViewerStore` holds no rows.
- **AC7 (Integration).** Given `ocupilot-ci` with seeded entries, when `LogViewerPage` (the consumer) reads `GET /logs/<key>` and the `logs.<key>.read` tool reads `Rows`, then both show the same newest entries. The six screens pass the DW-1337 walk with no new allowance in both themes, and the bundle stays under the 2004 kB warning (re-base under DW-1166 if crossed; stop and ask at 3800 kB).

### Review Findings

Code review 2026-09-27 (tier `full-opus`, four layers). 35 entries: high 0, medium 8, low 24, false 3. 9 patched, 26 rejected, 0 deferred; nothing ledgered (DW-1755 already holds the area gating).

- [x] [Review][Patch] SQL diagnostics read every message of a result, unbounded (a load with no error limit writes one per failed row) [src/OcuPilot/Port/LogSourcePort.cls:1496] — `DIAGMESSAGEMAX` 20, then a U+2026 line; `LogSecondaryWire.TestADiagnosticsResultCarriesAtMostItsMessageCap`.
- [x] [Review][Patch] The task wire leg could not tell an `ErrorLog` row from the `Details` fallback [src/OcuPilot/Test/LogSecondarySeed.cls:78] — the seeded details now differ from the row.
- [x] [Review][Patch] `Recent`'s enum step had no test [src/OcuPilot/Test/LogSecondary.cls:303] — `messages` and an unknown key answer 404 `LOG.SOURCE`.
- [x] [Review][Patch] No real reader's pid was asserted [src/OcuPilot/Test/LogSecondaryWire.cls:64] — each seeded entry's pid is checked.
- [x] [Review][Patch] An entries source's `truncated` never reached a client test [ui/src/app/areas/logs/log-viewer.spec.ts:883].
- [x] [Review][Patch] `Area.cls` did not say the Logs rail is now also gated on `%Ens_EventLog:USE` [src/OcuPilot/Screen/Area.cls:37].
- [x] [Review][Patch] The `LOG.FILE` refusal said the log is "read whole" [src/OcuPilot/Api/LogPage.cls:73].
- [x] [Review][Patch] Stale fixture comment above the `nsPairs` branch [src/OcuPilot/Test/LogSourceFixture.cls:128].
- [x] [Review][Patch] AC7's mutation line pinned the `Rows` projection, not the route/tool integration test — recorded in Verification.

Rejected:

- `medium` spec-bound: one faulty namespace fails the whole per-namespace read — the Always rule and the Vendor fault row ("never partial").
- `medium` duplicate: `%Manager` loses the Logs rail — DW-1755 (decision-pending); facts re-measured on `ocupilot-ci`: `%Manager` holds `%Admin_Operate`, `%Admin_Secure`, `%DB_IRISSYS:RW` and no `%Ens_EventLog`.
- `medium` spec-bound: `%ExecDirectNoPriv` for `eventlog` and `sqldiagnostics` — Design Notes gate both on the database `READ`; the spec gate ruled it not elevation. Not in the spine (lead, Rule 20).
- `low` spec-bound: exited or canceled tasks not listed; xDBC omits `IRIS_ERROR`/`LOCATION`; same-second tasks collapse (the vendor query's own keying, classic page alike; direct traversal is a Never); `raw` of a time-less entry follows the spec's grammar.
- `low`: task status compared to "ERROR" (a non-English instance and a failed task with no rows); a task's rows past the cap keep the oldest (`truncated` reported); jump top/bottom and search exercised on one source (one code path); the AC1 browser title names pid and word; untested defensive branches.
- `low` wontfix-accepted: Next/Previous match are enabled with no matches, as Enter/Shift+Enter are, and the count reads "0 of 0" — `reopen_if=an accessibility audit flags them as inert`.
- `low`: Load newer's jump after a failed or superseded read, or on a destroyed view (a console error at most); a caret past a shrunk total (needs more than 1,000 entries to shift during a search).
- `low` theoretical: `ExpectedLocal` across a DST change (containers run UTC); analytics rollover between exists and open; seed cleanup races and re-seed without removal (throwaway only); the diagnostics `%SQLCODE` branch (a `%` table exists everywhere and a `<PROTECT>` lands in the tested `Catch`); public readers taking a namespace (the port's seams, like `OpenStream`, are public for fixtures; no other caller).
- `low`: EXPERIENCE.md's `[<namespace>]` sentence and the spine's AD-48/`LogSourcePort` wording — planning documents outside a review's edit.
- `low`: spec counts and citations — spec edits.
- `false`: an xDBC `<PROTECT>` on the cache database (a `%DB_USER`-only principal read the store, measured); `Trace` renders raw `-1` (`log-line.ts` maps -1 to the debug word); the per-namespace database pair is dead (it restates `Payload`'s filter; no harm).

### Rework (decision, iteration 1)

- [x] [Decision] DW-1755, decided at the merge gate (option B; AD-8 amended 2026-09-27, "An area's pair set covers its screens' pairs, except pairs a screen declares its own"): restore the Logs area's pair set in `src/OcuPilot/Screen/Area.cls` to Release 1's (`%Admin_Operate:USE`, `%Admin_Secure:USE`, `%DB_IRISSYS:READ`), and let a descriptor declare pairs beyond its area's as its own so `Screen.Registry.AreaCoverageProblem` leaves them out of the coverage check. The event-log descriptor declares `%Ens_EventLog:USE` and the analytics descriptor `%DeepSee_Portal:USE` as their own; each screen is still hidden from the side bar and command box and refused on its route and read tool for a caller without its pair (the existing per-screen gate). Keep the declaration validated identically wherever descriptors are validated (`Screen/Registry.cls` and, if it mirrors privilege pairs, `ui/tools/screen-mirror.mjs`), with a refusal for an own pair the screen's privilege set does not contain. Update `Area.cls`'s doc paragraph to match (delete the sentence it no longer holds). Tests: (a) a registry leg that an own pair passes coverage and an undeclared extra pair is still refused; (b) an integration leg on `ocupilot-ci` with a least-privileged principal holding exactly the Release 1 Logs pairs (plus what those screens need, as the existing Logs tests use) and **not** `%Ens_EventLog:USE`: the Logs area reads allowed, messages.log and alerts.log read allowed, and only the event-log screen and its read tool are refused naming `%Ens_EventLog:USE`; remove the principal after. Pin (b) with a Rule 19 mutation (put `%Ens_EventLog:USE` back in the area set -> the leg reds) and write its `mutation:` line. Re-run `WireSecurityRead` (its AUDITUSER expectation changed with the area set), `Descriptor`, `Wire`, `ScreenRead`, `EndpointCoverage`, `SurfaceCoverage`, `LogSecondary*` and the `secondary-logs` browser spec, one at a time.

## Spec Change Log

- 2026-09-27, lead: re-opened for one rework iteration on the merge-gate decision on DW-1755 (option B): the Logs area keeps its Release 1 pair set; the event-log and analytics screens own their extra pairs (AD-8 amended).

- 2026-09-27, lead, spec gate: orchestrator ruling (option A) on the contended `Test/ReadTool.cls:93-94,112` hunks: edit them on this branch for this story's six tools (count 126 here); the orchestrator reconciles with Story 14.4 at the second merge (127, name lists merged). The AD-21 fifth named case and the `LogSourcePort` description were written into the spine as recommended. Status reset to ready-for-dev.

## Review Triage Log

### 2026-09-27 — Review pass

- verdicts: 26 findings — high 0, medium 9, low 14, false 3, maybe-false 0
- findings:
  - `[low]` `[reject]` verification-gap: `LocalFromUtc` cannot fail on a UTC instance — direction measured correct with `TZ=America/New_York` (12:00Z → 08:00); a non-UTC test needs a time-zone seam around a one-line vendor call.
  - `[medium]` `[patch]` verification-gap: either half of the SQL diagnostics severity rule deletable — added `LogSecondary.TestTheSeverityRulesCoverEachCondition`; mutation run 16608.
  - `[medium]` `[patch]` verification-gap: the real fetchers' SQL fault path never ran — added `TestTheRealFetchersFailOnAnUnreadableStore` (`Ens_Util.Log` absent in `%SYS`, SQLCODE -30; an unknown namespace); mutation run 16609.
  - `[medium]` `[patch]` verification-gap: event types Assert, Alert, Info unpinned — the severity test covers all six types and the display values.
  - `[low]` `[patch]` verification-gap: `Page`'s refusal of the six keys unfalsifiable — the Page loop now runs holding no pair (404 vs 403); mutation run 16607.
  - `[medium]` `[patch]` verification-gap: the AC3 browser leg could not tell one row from all — the seed logs a warning and the error; the leg asserts at least two rows; mutation (explain the last row) red.
  - `[low]` `[patch]` verification-gap: browser clicks on the match controls with one match could not fail — removed; the component DW-1102 case pins them.
  - `[medium]` `[patch]` verification-gap: Load newer's jump to the bottom untested — component case clicking the page's button with a `scrollTo` spy; mutation red.
  - `[low]` `[patch]` verification-gap: AC2, AC3, AC4, AC7 had no mutation line — each named, applied, red observed and recorded in Verification.
  - `[medium]` `[reject]` verification-gap other: the Logs area now also gates on `%Ens_EventLog:USE`, so a principal without it (the stock `%Manager` role, measured) loses the Logs rail item — spec-directed (Tasks, `Area.cls:117`) under AD-8's area-union rule, whose precedent `Area.cls` documents; filed in `deferred` for the lead's decision.
  - `[low]` `[patch]` verification-gap other: the recorded store mutation could not isolate the guard it named — rewritten as the mutation actually applied, red observed.
  - `[false]` `[reject]` intent-alignment A: `taskerrors` not filtered to the readable set — Design Notes give it instance scope at `%Admin_Operate:USE`, as its classic page.
  - `[low]` `[reject]` intent-alignment B: `truncated` also set when a file window or a task's rows were cut — reports an incomplete answer honestly; no user harm.
  - `[low]` `[reject]` intent-alignment C: a fault in the interoperability predicate answers the generic 500, not `LOG.UNREADABLE` — `IsEnsembleNamespace` reads configuration; a wrap adds a branch for an unobserved fault.
  - `[false]` `[reject]` intent-alignment D: other query parameters ignored — "reads no query parameter" and `file` refused 400 as on alerts.log, which ignores the rest the same way.
  - `[medium]` `[reject]` intent-alignment F: a principal's Logs rail verdict changes — same root cause as the area-gating row above.
  - `[low]` `[reject]` intent-alignment 3.1: the readable set is pinned at the port, not over the wire — the resolver is the production `Namespaces.Payload`; readable-set mutation red (run 16613).
  - `[medium]` `[patch]` intent-alignment 3.2: vendor faults only simulated by the fixture — grouped with the real-fetcher patch above.
  - `[false]` `[reject]` intent-alignment 3.3: zero reader calls asserted only in the port — reads are observable only there; the wire legs pin the 403 naming the pair.
  - `[low]` `[reject]` intent-alignment 3.4: `truncated` from the byte window untested — grouped with B.
  - `[low]` `[reject]` intent-alignment 3.5: pid and severity word not asserted in the browser — pid in the Raw leg, word in the component case.
  - `[medium]` `[patch]` intent-alignment 3.6: Load newer's jump unmeasured — grouped with the Load newer patch above.
  - `[low]` `[reject]` intent-alignment 3.7: search and Raw exercised on `xdbc` only — one shared code path.
  - `[low]` `[reject]` intent-alignment 3.8: sign-out pinned in `app.spec.ts` only — the precedent for every other root store.
  - `[low]` `[reject]` intent-alignment 3.9: the fresh-stock leg depends on untouched stores — CI's browser job runs on a fresh throwaway; green on the reused one too.
  - `[low]` `[reject]` intent-alignment 3.11: route and tool compared at `maxRows=5` — one `Recent`, the cap is the caller's argument.

### 2026-09-27 — Review pass (rework iteration 1, DW-1755)

- verdicts: 6 findings — high 0, medium 0, low 5, false 1, maybe-false 0
- findings:
  - `[low]` `[reject]` verification-gap other: `## Auto Run Result` still names the Logs area gating as deferred and records no re-run of this pass — a spec edit; this pass's finalize writes it (re-runs confirmed from `%UnitTest_Result`, runs 16641-16651).
  - `[false]` `[reject]` intent-alignment 1: the event log is shown gated in the side bar and command box, not removed — the item says "(the existing per-screen gate)", which is what renders it; unchanged.
  - `[low]` `[reject]` intent-alignment 2: leg (b) reuses `AUDITUSER` (exactly the three Release 1 pairs plus code read), removed in `OnAfterAllTests` — meets "remove the principal after"; the leg asserts the missing pair first.
  - `[low]` `[reject]` intent-alignment 3: "only the event log" rests on route/tool calls for messages and alerts plus `ScreensFor`'s ten verdicts — the other secondaries' route pairs are pinned by `LogSourceDenial` (run 16651 green); `%DeepSee_Portal` has public `USE`, so no principal can lack it.
  - `[low]` `[reject]` intent-alignment 4: the area mutation cannot redden the event-log route/tool refusals — those are pinned by the existing `LogSourceDenial` eventlog mutation (run 16270); the item's named mutation targets the area verdict.
  - `[low]` `[reject]` intent-alignment 5: re-run evidence not on the diff — same as the first row; `secondary-logs` re-run 6/6 on a rebuilt, redeployed bundle during triage.

## Design Notes

**Sources (measured on `ocupilot-ci` 2026-09-27; `(inference)` where not run).** Scope "readable" means the `Payload` set.

| key | store and reader | scope | pairs | time | pid | severity | text |
|---|---|---|---|---|---|---|---|
| `systemmonitor` | `<mgr>SystemMonitor.log`, tail through `ReadWindow` | instance | `%Admin_Operate:USE` | the `MM/DD/YY-HH:MM:SS` prefix (local) | `''` | 0 | rest of the line |
| `taskerrors` | `%CSP.UI.System.BackgroundTask` `EnumerateTasks` + `ErrorLog(pid)` (an IRISTEMP global) | instance | `%Admin_Operate:USE` | task `StartTime` | task pid | ERROR→2, Msg→0 | `[NS] <task>: <ErrorText>`; a task with Status ERROR and no ErrorLog rows gives one entry with its `Details` |
| `xdbc` | `%SQL.Manager.Catalog:XdbcErrors(ns)` | readable | `%Admin_Operate:USE` | `DATE_TIME` | `DisplayPID` | 2 | `[NS] <SQLCODE> <MESSAGE>` (vendor values) |
| `sqldiagnostics` | `%SQL_Diag.Result`, `TOP n ORDER BY ID DESC`; `%SQL_Diag.Message` severity ≥2 | readable | `%Admin_Operate:USE` + ns db `READ` | `createTime` (UTC→local) | `processId` | 2 if `sqlcode`<0 or `errorCount`>0, else 0 | `[NS] <statement>`, then one line per message of severity ≥2 |
| `eventlog` | `Ens_Util.Log`, `TOP n ORDER BY ID DESC` via `%SQL.Statement.%ExecDirectNoPriv` | readable ∩ `%Library.EnsembleMgr.IsEnsembleNamespace` | `%Ens_EventLog:USE` + ns db `READ` | `TimeLogged` (UTC→local) | `Job` | Assert, Error, Alert→2; Warning→1; Info→0; Trace→-1 | `[NS] <ConfigName>: <Text>`, or `[NS] <Text>` with no ConfigName |
| `analytics` | `<mgr>DeepSeeTasks_<NS>.log`, tail | readable ∩ file exists | `%DeepSee_Portal:USE` | the `YYYY-MM-DD HH:MM:SS.mmm` prefix (local) | job column | 0 | `[NS] <source> <message>` |

- **Classic pages (AD-44)**, in the same order: `%CSP.UI.Portal.ViewLog`, `%CSP.UI.Portal.BackgroundTaskError`, `%CSP.UI.Portal.xDBCErrorNamespaces`, `%CSP.UI.Portal.SQL.Logs`, `EnsPortal.EventLog` and `%DeepSee.UI.LogViewer`.
- **Why these pairs.**
  - None of the six stores checks privilege itself. A principal holding only `%DB_USER:RW` read the file, the xDBC store and the task store. The classic page's resource is therefore the gate, per AD-29's "could have read it directly".
  - The background task page carries no resource, so it takes the area's `%Admin_Operate:USE`.
  - `%DeepSee_Portal` has public USE, so the analytics gate is parity with the classic page, and the readable-set filter is the real narrowing.
- **SQL privilege for `eventlog` (AD-8).** The vendor's `SELECT` grant on `Ens_Util.Log` exists in USER but not in HSCUSTOM. There, a `%EnsRole_Operator` holder got `SQLCODE` -99, measured. The read therefore does not depend on SQL grants, and its gate is `%Ens_EventLog:USE` plus the database `READ` that IRIS enforces on the globals. This is not role elevation.
- **Fresh stock.** Only `SystemMonitor.log` holds entries; it is created at start with its "System Monitor started" line (inference for containers other than `ocupilot-ci`). The task store is in IRISTEMP, so a restart empties it.
- **Seed recipes** (tests and browser spec, `ocupilot-ci` only; remove exactly what was added):
  - **systemmonitor:** `##class(%SYS.Monitor.SampleSubscriber).%New().LogMsg(marker)` in `%SYS`. To remove, truncate to the prior size only if nothing was appended after it.
  - **taskerrors:** set `^|"%SYS"|IRIS.Temp.MgtPortalTask(999000002)` with `Task`, `Status`="ERROR", `StartTime`, `NS` and `ErrorLog`, then kill that node.
  - **xdbc:** in HSCUSTOM, set `^|$$GetCacheDatabase^%SYS.SQLSRV()|%sqlcq("HSCUSTOM","LastError",999000001)`, then remove it with `KillLastErrorOne^%SYS.SQLSRV(999000001)`.
  - **sqldiagnostics:** `##class(%SQL.Diag.Result).addDiagResult`/`addDiagMessage` (inference: not run). Remove by id, and kill the globals only if the extent was empty before.
  - **eventlog:** `##class(Ens.Util.Log).LogError(...)`. Delete by id, then kill `^IRIS.Temp.EnsLogMonitor("HSCUSTOM",type)`.
  - **analytics:** `##class(%DeepSee.Utils).%WriteToLog(...)`, only if the file was absent; remove it with `%KillLogFile()`.

**Spine change for the lead** (Rule 20; consistent with AD-21 and AD-29, so it does not block):

- (a) Append to AD-21's first paragraph, after the fourth case:

  > The fifth is the analytics log [AMENDED 2026-09-27, Story 16.8 spec gate, Rule 20]: `DeepSeeTasks_<NAMESPACE>.log`, the name `%DeepSee.Utils.%GetLogFileName` gives a namespace's analytics task log (measured on `ocupilot-ci`), resolved under `<ManagerDirectory>` computed at call time and never cached, where `<NAMESPACE>` is a member of the set the caller can read and never a caller string; no caller names the file, and it is read through `LogSourcePort`'s `analytics` source under that source's own gate. The System Monitor's `SystemMonitor.log` is a fixed-enum name like `messages.log` and needs no case.

- (b) The `LogSourcePort` description at `:46` becomes: "every log source the admin API does not back: the manager directory's files, the `^ERRORS` global, and Story 16.8's System Monitor, background-task, xDBC, SQL diagnostics, interoperability event and analytics logs, the last four read per namespace over the set the caller can read, through the vendor's own readers, each pinned by a test on its columns where it is internal".

**Decisions.**

1. **Merged, not chosen.** The four per-namespace logs merge every readable namespace, so there is no namespace control and no caller namespace. This also suits the hub (inference).
2. **Load newer re-reads the newest window.** The new sources have no byte cursor. `Page` stays messages and alerts only.
3. **The server normalizes.** Rows are normalized on the server, so the client parses no new grammar.
4. **Current file only.** Neither `SystemMonitor.log.old` nor `DeepSeeTasks_<NS>.old` is read.

**Fixed strings rows**, appended after EXPERIENCE.md `:583` as `:584` and `:585`:

> `| "System Monitor log" · "Background task error log" · "xDBC error log" · "SQL diagnostics log" · "Interoperability event log" · "Analytics log" · "Next match" · "Previous match" | the six secondary log viewers (Story 16.8, FR-77): their side-bar entries and screen titles, the fifth to tenth Logs entries (`:90`, `:163`), in that order, each rendered in the shared log viewer whose empty state is its own "No entries." (`:379`); and the two controls beside the polite match count that move to the next and the previous match, wrapping (`:627`, DW-1102) [ADDED 2026-09-27 - Story 16.8] |`

> `| "What has the System Monitor reported recently?" · "Did the System Monitor raise alerts today?" · "When did the System Monitor last start?" · "Which background tasks failed, and why?" · "Which namespace did each failed background task run in?" · "Did any recent import or link task report errors?" · "Which xDBC connections hit an SQL error recently?" · "What does the most recent xDBC error mean?" · "Which namespaces are these xDBC errors in?" · "Which SQL loads reported errors?" · "What went wrong in the most recent failed load?" · "Did the latest load finish without errors?" · "Which production items logged errors recently?" · "Are any warnings repeating in the event log?" · "Summarize the interoperability errors by namespace." · "Did any cube build or synchronization fail recently?" · "Summarize the recent analytics log entries by namespace." · "Which analytics errors need attention?" | the six secondary log viewers' suggested prompts (Story 16.8, AD-5), three per screen in the previous row's order: Troubleshooting group, declared on each descriptor [ADDED 2026-09-27 - Story 16.8] |`

- **Keys.**
  - Labels: `systemMonitorLogListLabel`, `taskErrorLogListLabel`, `xdbcErrorLogListLabel`, `sqlDiagnosticsLogListLabel`, `eventLogListLabel`, `analyticsLogListLabel`.
  - Controls: `logViewerNextMatch` and `logViewerPreviousMatch`.
  - Prompts: `log<SystemMonitor|TaskError|Xdbc|SqlDiagnostics|Event|Analytics>ViewerPrompt1-3`.
- **Aliases.** `["system monitor","SystemMonitor.log"]`, `["background task errors"]`, `["xdbc","odbc","jdbc"]`, `["sql diagnostics","load data"]`, `["event log","interoperability"]` and `["analytics","deepsee"]`.
- **Citation shift.** Move every citation of a line of 584 or later by 2, for example `strings.ts:1951` `:624`→`:626`; `npm run test:tools` finds the rest.
- **Edit `:625` in place, which becomes `:627`:**
  - Column 2 reads "…; the six P1 secondary logs (Story 16.8)".
  - "with next/previous" becomes "with "Next match" and "Previous match" beside it".
  - Append: "The six secondary logs (Story 16.8) each show a bounded newest window of entries rather than a paged file, merged across every namespace the user can read where the log is kept per namespace, each such entry led by `[<namespace>]`; Load newer re-reads that window."

**Governing ADs:** AD-21, AD-29, AD-8, AD-48, AD-16, AD-36, AD-24, AD-5, AD-44, AD-13 (id `none`), AD-19, AD-20, AD-11, AD-12, AD-39, AD-43 (no refresh), AD-22 (reads only), AD-27 (untouched).

**Integration.**

- **Consumes:**
  - `LogSourcePort`'s gate, `ReadWindow` and `NamespaceResolver` (6.12-6.14, 7.10);
  - `Kernel.Shell.Namespaces.Payload`;
  - `LogViewerPage`/`LogViewerStore` and 16.20's `publishRows`;
  - `ExplainEntry` (11.2), `ScreenStore`/`assembleScreenContext` (4.11) and `structural-walk.mjs` (15.6).
- **Consumed-by:** Story 16.9, whose unified log hub lists these six sources with a count and last entry (`epics.md:6288`), through `Recent`/`Rows` (inference until its plan).

**Concurrent epics** (`origin/OCU-1-epic14` tip `b147b073`, merge base `c76cc726`).

- **Hunks this story stays off**, in HEAD lines:
  - `LogSourcePort` after `:2132`;
  - `Router` after `:73`, `:130`, `:132`, `:220`, `:769` and `:784`;
  - `Error.cls` from `:418`;
  - `EndpointCoverage` after `:82`, `:119` and `:121`;
  - `SurfaceCoverage` after `:60`, and `:146`;
  - `Test/Descriptor` after `:70`, and `:1519`;
  - `Test/Wire` `:463` and after `:480`;
  - `strings.ts` `:165-598`;
  - `navigation.test.mjs` `:196-221`;
  - `ci-throwaway.sh` `:197-318`;
  - `explain-entry.browser-spec.mjs` `:33` and `:134`;
  - `structural-walk.mjs`;
  - EXPERIENCE.md `:257-526`, `:646` and `:736`, all line-count neutral.
- `screens.generated.ts` is regenerated after any merge. `EntityType.cls` is untouched.
- **Contended: `Test/ReadTool.cls:93-94,112`.** The exact tool count and name roster and the descriptor-pair loop there are edited by Story 14.4 (+`agent.transcripts.read`). The six derived reads must change the same lines. This is the blocking condition.
- Story 14.3's sanitizer would cover these rows on the model path with no change here (inference). Epic 18 has no branch, and Epic 23 has no source diff.

**Ledger.**

- DW-1102 → AC5.
- DW-1110 → AC6.
- DW-118 is declined, because Story 15.6 resolved it.
- Governance is unchanged, since only read tools are added (AD-22).

## Verification

**Commands** (slot A; `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci` on every browser run; bundle rebuilt and `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/` first):

- `cd ui && npm run test:tools` (loop) -- green: `screen-mirror`, `strings` (rows, citation shift), `navigation`, `navigation-wire`, `explain-entry`, `screen-arrival`, `structural-baseline` and `ci` (roster).
  - mutation: drop `LogSecondaryWire` from the `ci-throwaway.sh` roster → `ci.test.mjs` red (observed, reverted).
  - mutation (DW-1755): delete the `ownPrivilegesProblem` call from `buildMirror` → the `screen-mirror.test.mjs` own-pair case red; skip its not-declared check → the same case red on the `OwnPrivilegeCases` corpus (each observed, reverted).
- `cd ui && npx ng test --include src/app/areas/logs/log-viewer.spec.ts --include src/app/areas/logs/explain-roster.spec.ts --include src/app/app.spec.ts --include src/app/areas/home/home.page.spec.ts --include src/app/shell/command-box.spec.ts --include src/app/shell/side-bar.spec.ts --include src/app/shell/rail-wire.spec.ts --include src/app/shell/screen-outlet.spec.ts --include src/app/shell/fault-banner.spec.ts` (loop) -- green. Mutations:
  - an entries source's Load newer reads `?offset=…&identity=…` (the `loadNewer` entries branch passes the offset and `read()` drops its `!entriesMode` guard) → the Load newer case red (observed, reverted);
  - drop `afterNextRender(() => this.onBottom())` from `onLoadNewer` → the Load newer jump case red (observed, reverted);
  - Next match calls `step(-1)` → match-button case red (observed alone, reverted);
  - drop the `LogViewerStore` reset → `app.spec.ts` DW-1110 case red (observed, reverted).
- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class <C>` (loop), one at a time, for `OcuPilot.Test.LogSecondary`, `LogSecondaryWire`, `LogSourceDenial`, `LogSource`, `LogSourceWire`, `LogOlderFilesWire`, `LogPairs`, `ErrorLog`, `EndpointCoverage`, `SurfaceCoverage`, `Descriptor`, `Navigation`, `Wire`, `ReadTool`, `ScreenReadWire` and `PromptCorpus` -- green. Mutations:
  - a reader called before the gate → `LogSecondary` gate leg red (observed, run 16263, reverted);
  - drop the namespace predicate for `eventlog` → predicate leg red (observed, run 16264, reverted);
  - sort ascending → merge leg red (observed with the mapping leg, run 16265, reverted);
  - drop `%Ens_EventLog:USE` from `EVENTLOGPAIRS` → `LogSourceDenial` eventlog leg red (observed, run 16270, reverted);
  - `EVENTLOGPAIRS` set to `%Admin_Operate:USE` → `LogPairs` classic-resource leg red (observed, reverted);
  - `eventlog` dropped from `SOURCES` → `LogSource` six-keys leg red (observed, reverted);
  - `LogEventViewer`'s read pointed at `xdbc` → `Descriptor` six-viewers leg red (observed, reverted);
  - delete `Page`'s `RECENTSOURCES` refusal → `LogSecondary` Page leg red (run 16607, reverted);
  - drop the `errorCount` half of the SQL diagnostics severity → `LogSecondary` severity leg red (run 16608, reverted);
  - delete `FetchEvents`' `%SQLCODE < 0` check → `LogSecondary` real-fetcher leg red (run 16609, reverted);
  - drop the per-namespace gate in `Recent` → `LogSecondary` refused-namespace leg red (run 16610, reverted);
  - AC2 readable set: `Recent` reads `HSCUSTOM,USER` whatever the resolver answers → `LogSecondary` readable-set leg red (run 16613, reverted);
  - AC4: an absent `SystemMonitor.log` answers an error → `LogSecondary` absent-log leg red (run 16611, reverted);
  - AC7: `Rows` projects `pid` too → `LogSecondary` Rows leg red (run 16612, reverted);
  - AC2 file: delete `HandleRecent`'s `file` refusal → `LogSecondaryWire` file leg red (run 16614, reverted).
  - Code review, run 16620, four mutations applied together, each reddening only its own assertion (reverted, source re-copied and byte-identical): AC7 `Rows` skips the newest entry → `TestEachToolReadsTheRoutesNewestEntries` red for all six keys; `FetchTaskErrors` executes `ErrorLog` on a wrong id → the seeded-entry leg's taskerrors row red; `FetchEvents` selects `ConfigName` before `Job` → the eventlog pid leg red; the diagnostics message cap removed → `TestADiagnosticsResultCarriesAtMostItsMessageCap` red.
  - Code review: delete `Recent`'s enum check → `LogSecondary` Page/Recent leg red for `messages` and an unknown key (run 16621, reverted).
  - Code review (client): drop the entries branch's `truncatedValue = flagAt(...)` → the log-viewer truncated case red alone (observed, reverted).
  - DW-1755 (b): `%Ens_EventLog:USE` put back on the `logs` area → `WireSecurityRead.TestTheLogsAreaStaysOpenWithoutTheEventLogsPair` red, with the audit test's Release 1 area verdict (run 16638, reverted).
  - DW-1755 (a): `AreaCoverageProblem` ignores own pairs → `Descriptor`'s own-pair, six-viewers and production-roster legs red (run 16639); delete `Validate`'s `OwnPrivilegesProblem` call → the own-pair leg red alone (run 16640); each reverted with `Registry` and its subclasses recompiled.
- `cd ui && npm run build && docker cp … && node --test --test-concurrency=1 browser/secondary-logs.browser-spec.mjs browser/messages-log.browser-spec.mjs browser/messages-log-files.browser-spec.mjs browser/alerts-log.browser-spec.mjs browser/explain-entry.browser-spec.mjs browser/screen-height.browser-spec.mjs browser/a11y-structural-invariants.browser-spec.mjs` (loop) -- green, within the structural baseline.
  - mutation: `SOURCES` drops `logs/eventlog` → seeded-row leg red (observed on a rebuilt, redeployed bundle; reverted and redeployed).
  - mutation (AC3): `onExplain` sends the last row instead of the clicked one → the Explain leg red, "the entry clicked" (observed on a rebuilt, redeployed bundle; reverted, rebuilt, redeployed, 6/6).
- `cd ui && npm test`, `uv run scripts/check-objectscript.py`, `bash scripts/lint-docs.sh` (once, before dev_complete) -- green; bundle under 2004 kB.
- The full ObjectScript sweep on `ocupilot-ci`, one class at a time (once, before dev_complete) -- green.

## Auto Run Result

Status: done
Blocking condition: none

- **Change:** six fixed-enum secondary log sources on `LogSourcePort` served by `Recent` (routes, descriptors, declared reads, three prompts each), the viewer's entries mode, "Next match"/"Previous match" (DW-1102) and the `LogViewerStore` sign-out reset (DW-1110). The readers the spec placed in `Port/LogRecords.cls` live in `LogSourcePort` after `HeadParts`: `PortGate` requires every `OcuPilot.Port` class on a roster line Epic 14 also edits, so a new class there would contend.
- **Files:** `Port/LogSourcePort.cls` (keys, pairs, `Recent`, readers), `Api/LogPage.cls`, `Api/Router.cls`, `Screen/Area.cls`, six `Screen/Descriptor/Log*Viewer.cls`; tests `LogSecondary`, `LogSecondaryWire`, `LogSecondarySeed`, `LogRecordsFixture`, and rows in `LogSource`, `LogSourceDenial`, `LogSourceFixture`, `LogPairs`, `Descriptor`, `EndpointCoverage`, `SurfaceCoverage`, `Navigation`, `Wire`, `WireSecurityRead`, `ReadTool` (126, as ruled), `ScreenRead` (eight logsource reads); client store, page, `app.ts`, `strings.ts`, `screens.generated.ts`, specs, `secondary-logs.browser-spec.mjs`; EXPERIENCE.md two rows and the log-viewer row; `ci-throwaway.sh` roster.
- **Review:** 26 findings; 9 patched (medium 5 entries, low 4), all test-side, each with an observed mutation; 1 deferred (Logs area gating, decision-pending); 16 rejected with reasons in the triage log. Follow-up review: false — every patch is a test whose red was observed.
- **Verification:** full ObjectScript sweep on `ocupilot-ci`: 308 ran, 16 refused (arming), 1 known residue (`WireSecurityRead` task history); `PortGate` and `ScreenRead` failed there and were fixed, then re-run green with every log class. `npm test` 1575 tool + 1558 component (log-viewer spec now 44); browser `secondary-logs` 6/6, `messages-log`, `messages-log-files`, `explain-entry`, `screen-height`, `a11y-structural-invariants`, `audit`, `error-log`, `suggested-prompts`, `suggested-view` green; `alerts-log` 5/7 on the reused throwaway only (seeded alerts outside the 64 KB tail of a 160 KB file; path unchanged). Bundle 1.94 MB. `check-objectscript` and `lint-docs` clean. Seeded stores read back empty.
- **Residual risk:** `LocalFromUtc` is falsifiable only on a non-UTC instance.
- **Rework iteration 1 (DW-1755, option B):**
  - Change: the Logs area is back to its Release 1 pairs. A descriptor may declare `ownPrivileges`, a subset of its `privileges` that `AreaCoverageProblem` leaves out. `OwnPrivilegesProblem` and the mirror's `ownPrivilegesProblem` refuse an own pair outside `privileges`, over one shared corpus. `LogEventViewer` owns `%Ens_EventLog:USE` and `LogAnalyticsViewer` owns `%DeepSee_Portal:USE`.
  - Files: `Screen/Area.cls`, `Screen/Registry.cls`, `Screen/Descriptor/Base.cls`, the two descriptors, `ui/tools/screen-mirror.mjs`, `screens.generated.ts` and `testing/screen-declaration.ts`. Tests: `DeclarationCorpus`, `Descriptor`, `WireSecurityRead` (the new leg (b), with the `AUDITUSER` area verdict now `true`), `Navigation`, `Wire`, the new fixtures `Test/OwnPair/Bad.cls` and `Test/OwnPairRegistry.cls`, and `screen-mirror.test.mjs`.
  - Review: 6 findings (low 5, false 1), 0 patched, 0 deferred, all rejected with reasons in the triage log. Follow-up review: false (a follow-up pass that patched no high). The DW-1755 `deferred:` entry was cleared as resolved.
  - Verification on `ocupilot-ci`, one class per call:
    - Green: `Descriptor` 55/55 (run 16649), `Wire`, `Navigation`, `ReadTool`, `ScreenRead`, `EndpointCoverage`, `SurfaceCoverage`, `LogSecondary` and `LogSecondaryWire` (runs 16641-16648), and `LogSourceDenial` (run 16651).
    - `WireSecurityRead` passed 23 of 24 (run 16650). The one failure is the known task-history residue.
  - Client and checks: `npm run test:tools` 1576/1576; `screen-mirror.test.mjs` 58/58 and `--check` up to date; `secondary-logs` 6/6 on a rebuilt, redeployed bundle (1.94 MB); `check-objectscript` clean. Mutations are recorded in Verification (runs 16638-16640 and the two mirror mutations).
