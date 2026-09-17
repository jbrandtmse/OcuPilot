---
title: 'System usage and the dashboard meters'
type: 'feature'
created: '2026-09-17'
status: 'blocked'
baseline_revision: 'ab754db8824ec1d51a110dbc678b10ec7b92b0ee'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-6-context.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** OS management has no System usage screen, so an administrator must leave for the classic portal to see instance load (FR-56). Nothing draws a meter yet, and Database details (6.11) needs one.

**Approach:** One listed `meters` descriptor under OS management reads the admin API's `Monitor` endpoint through `AdminPort`, which serves every counter. A new OS management page shows the counters and a shared `meter` component in `shell/`. It auto-refreshes through the shared framework. The meter set, its thresholds and the read shape follow the recommended amendments under Design Notes, which the lead has not yet decided.

## Boundaries & Constraints

**Always:**

- **Descriptor `SystemUsage`** (recommended; see Q4 for the read):
  - route `os-management/system-usage`, area `os-management`, `sideBarPosition` 2 (Processes · Locks · System usage · Databases · Devices), archetype `meters`, `built` true
  - entity `system-usage` (a new closed-enum value, AD-14), scope `instance`, `refreshes` true, rates `[5,10,30,60]`
  - pairs start as `%Admin_Operate:USE`, `%DB_IRISSYS:READ` (`ResourcesOR` plus the admin-read rule). The backing calls (`GLOSTAT`, `SYS.Metrics`, `%SYSTEM.Config.SharedMemoryHeap`) ship without source, so a real least-privileged principal on the throwaway settles the set (AD-29).
  - tool `osmgmt.systemusage`; aliases `["system usage", "CPU", "memory", "dashboard"]`; no primary or row action; `classicPage` `%CSP.UI.Portal.UtilSysMonitor` (inference: the CSP page `/csp/sys/op/UtilSysMonitor.csp`, `%CSP.Portal.Application:471`; confirm the normalized key with `%SYS.Portal.Resources.NormalizePage`), exemption false; `secretFields` `[]`
- **Counters** (one row, cumulative since startup, the vendor's total column): AllGlobalReferences, GlobalUpdateReferences, RoutineCalls, LogicalBlockRequests, BlockReads, BlockWrites, JournalEntries, JournalBlockWrites, LastUpdate, plus shared memory used, allocated and available from the `Total` row.
- **Meter component** (`ui/src/app/shell/meter.ts`): 6px `rounded.full` track, label in caption above, value in code type beside it, a unit, and the state as a word and a color. Warning and error color both the fill and the value text. Before the first value: "—" and a skeleton. A failed meter shows "—" with the error in its tooltip. No transition on the fill width, ever. The page passes it `(label, value, unit, percent | null, state)`, and the component computes nothing from the vendor.
- Shared files are additive only. New Fixed strings rows go after the last row. Non-ASCII in code is `\uXXXX`. No context field over 1,000 characters.

**Never:**

- No `MonitorPort` and no HTTP request to `/api/monitor` or `/api/admin` (AD-1, AD-27).
- Nothing read from `UtilSysMonitor`'s source.
- No full System Dashboard groups: ECP, queues, upcoming tasks, license detail and alerts are FR-76 (P1).
- No needle animation, no write, no classic link-out.
- No edits to `Kernel/**`, `Port/ProviderPort.cls`, `Screen/Tool/**`, `scripts/check-objectscript.py` or its test, `app.ts`, `app.spec.ts`, `ui/package*.json`, `angular.json`, `README.md`, `shell/panel/**`.

## I/O & Edge-Case Matrix

Reads are `GET /api/ocupilot/screens/osmgmt.systemusage/read`.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Live | `_SYSTEM` | 200, one row; every declared field is a non-null key; `BlockReads` numeric | — |
| Tick | two reads 5 s apart | `AllGlobalReferences` non-decreasing | — |
| Pairs | principal holding `%Admin_Operate:USE` only; then the full set | 403 `AUTH.NOPRIVILEGE` naming the first missing pair; then 200 | Never 500 |
| Meter state | vendor word `Warning` / `Troubled`, or a percent at or above a threshold | state word and warning or error color on the fill and the value | — |
| Meter fault | read faults after one success | last values kept; faulted view per the `meters` state row | Not an empty state |

</intent-contract>

## Code Map

- **Vendor** (`%Api.Admin.Endpoints.Monitor`, hidden; read on slot B, read-only):
  - `ResourcesOR` is `%Admin_Operate`.
  - Request types are unprefixed parameters: `DASHBOARDMAIN` 12, `SYSTEMUSAGESHM` 14, `SYSTEMUSAGE` 15 (also `DASHBOARDECP` 10, `DASHBOARDGLOBALS` 11, `DASHBOARDRESOURCES` 13, `LICENSEUSAGE` 16). The only `TYPE*` parameters are the base ones.
  - `RunSystemUsage` answers one object of GLOSTAT totals plus `LastUpdate`.
  - `RunSystemUsageSHM` runs `%SYSTEM.Config.SharedMemoryHeap:WebList` (`irissys/%SYSTEM/Config/SharedMemoryHeap.cls:374-411`): one row per consumer, then Total rows.
  - `RunMain` runs `SYS.Metrics.GetMainMetrics(,,.values)`. It returns Performance (GlobalRefsPerSecond, CacheEfficiency, …), SystemUsage status words (DatabaseSpace, DatabaseJournal, JournalSpace, LockTable, WriteDaemon: `Normal`/`Warning`/`Troubled`) and Licensing (LicenseUse %). It does not pass the status array, so the classic `WARNING`/`ERROR` icons are not in the answer.
- **`irislib/%CSP/UI/Portal/EnsembleMonitor.cls`:** the Interoperability System Monitor (`RESOURCE %Ens_Dashboard:USE`, `MetricClass %SYS.Ensemble`).
  - It holds 28 meter definitions: 23 value, 2 bar and 3 table meters.
  - It has no CPU, memory or performance meter.
  - It sets no `RangeLower`/`RangeUpper`/`ThresholdLower`/`ThresholdUpper` (declared with no default at `irislib/%CSP/Util/HTMLMeter.cls:39-48`; the bar meter only clamps 0-100, `HTMLBarMeter.cls:59-100`).
- **Documented cut-offs**, from comments only (`irissys/SYS/Stats/Dashboard.cls`):
  - LockTable: Warning above 85%, Troubled above 95% (`:92`)
  - DatabaseSpace: under 5 MB / under 2 MB (`:77`)
  - JournalSpace: under 250 MB / under 50 MB (`:85`)
  - WriteDaemon: Normal/Troubled (`:96`)
- **Port:**
  - `src/OcuPilot/Port/AdminPort.cls` resolves a type as `$Parameter(class, "TYPE"_suffix)` (`:680`) against `TYPESUFFIXES` (`:101`), so it cannot name `SYSTEMUSAGE`.
  - Gate `:244`; `QUERYPAIRS` `:130`.
- **Grammar:**
  - `Screen/Registry.cls`: `READSOURCETYPES` `:1351`, `ReadProblem :789`, `TableProblem :1613` (a read needs `table` with one `name` column), `AreaCoverageProblem :589`.
  - `Screen/Read.cls`: GET branch `:246-283`, non-LIST guard `:215`.
  - `ui/tools/screen-mirror.mjs`: `READ_SOURCE_TYPES :1030`, sources `:354-363`.
  - `Screen/Archetype.cls:73` already holds `meters`.
  - `Screen/Area.cls:102`: OS management's union already covers the starting pairs.
- **Client:**
  - `ui/src/app/shell/screen-outlet.ts`: `ARCHETYPE_PAGES :54-62` must cover every built archetype, and `BuiltArchetypeKey` (`core/screens.generated.ts:43`) gains `meters`; `DESCRIPTOR_PAGES :79-85`.
  - Precedent page `areas/os-management/process-details.page.ts:122-203` (bind, `readNow`, skeleton, fault).
  - `core/refresh.ts` `RefreshService :152`.
  - `ui/src/styles/_tokens.scss` (`--ocu-secondary :44`, `--ocu-error :62`, `--ocu-surface-container-high :83`, `--ocu-success :141`, `--ocu-warning :146`); skeleton `_components.scss:77-85`.
- **Strings:**
  - `core/strings.ts`: reuse `processDetailsGlobalReferences :824`.
  - `ui/tools/strings.test.mjs:330` bound is 400 with 399 used, so a new row needs the bound raised.
- **Rosters** (as 6.8): `Test/ReadTool.cls:94,100,263`, `Test/Wire.cls`, `Test/Descriptor.cls:49`, `Install/Smoke.cls:542-579` (+ `Test/Smoke.cls:571,669`), `ui/tools/navigation.test.mjs:126-135`, `screen-mirror.test.mjs:603`, `navigation-wire.test.mjs:38` and `shell/rail-wire.spec.ts:37` `LIVE_PAYLOAD`s, `strings.test.mjs`.
- **Browser:** `ui/browser/processes.browser-spec.mjs` (`signedInAtList :129`, chip `.ocu-command-bar-refresh :453`).

## Tasks & Acceptance

Provisional. Re-derived once the lead decides Q1-Q4.

**Execution:**

- [ ] `src/OcuPilot/Port/AdminPort.cls` -- let a declared type resolve an unprefixed endpoint parameter for `Monitor`'s read types (additive map beside `TYPESUFFIXES`); still reads only, no queueing.
- [ ] `src/OcuPilot/Screen/Registry.cls`, `Screen/Read.cls`, `ui/tools/screen-mirror.mjs`, the shared `Test/ReadSourceCorpus.cls` -- the read shape Q4 settles, with the same refusal sentence in both engines.
- [ ] `src/OcuPilot/Screen/Descriptor/SystemUsage.cls` (new) -- the declaration.
- [ ] `ui/src/app/shell/meter.ts` + `meter.spec.ts` (new), `ui/src/app/core/meter-state.ts` + `ui/tools/meter-state.test.mjs` (new) -- the component, and a pure state function (vendor word or percent to state).
- [ ] `ui/src/app/areas/os-management/system-usage.page.ts`, `.store.ts`, `.page.spec.ts` (new), `shell/screen-outlet.ts` -- the counters group and the meters; register the page.
- [ ] EXPERIENCE.md Fixed strings (append), `core/strings.ts`, `strings.test.mjs` -- the screen's strings; regenerate the mirror.
- [ ] `src/OcuPilot/Test/SystemUsage.cls` (new), `Test/WireSecurityRead.cls` -- matrix rows Live, Tick and Pairs, and the Integration AC.
- [ ] Rosters, the Smoke check `systemusage`, and `ui/browser/system-usage.browser-spec.mjs` (new).

**Acceptance Criteria:**

- AC1: Given System usage on the throwaway, when it loads, then global references, routine calls, block reads, block writes, journal entries and shared memory show with live values, and the refresh chip offers 5/10/30/60 s.
- AC2: Given a meter before its first value, when it renders, then it shows "—" with a skeleton. Given a value at a warning or error state, then the word shows and the warning or error color is on both the fill and the value text. The fill declares no transition.
- AC3: Given the chip at 5 s, when a tick fires, then the screen re-reads with no skeleton, no announcement and no `aria-live`.
- Integration: given `osmgmt.systemusage.read` in process, when called, then it answers the row the route answers over the declared fields. 6.11 is the meter's second consumer.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs:**

- AD-1, AD-2, AD-26, AD-27: `Monitor` is synchronous and in process, through `AdminPort`.
- AD-8, AD-29: the pair set, confirmed by a real principal.
- AD-5, AD-13, AD-14: the new entity-type value, scope `instance`.
- AD-19: the meter-state function is framework-free in `core/`.
- AD-24, AD-36: one declared, bounded read, shared by screen and tool.
- AD-43: System usage is on the roster; silent refresh; the needle never animates.
- AD-44: the classic key, no link-out.

**Port decision.** `AdminPort`, not `MonitorPort`. `%Api.Admin.Endpoints.Monitor` serves every counter plus shared memory and the dashboard's main metrics, in process, behind `ResourcesOR` (probed on slot B). `MonitorPort` stays 6.13's.

**Open questions for the lead (intent gap; each has a recommendation):**

- **Q1: meter names and source (Rule 5, ask first).** The AC says the CPU, memory and performance meters take "names and thresholds" from `EnsembleMonitor`'s "25 meter definitions". That class is the Interoperability production monitor. It has 28 definitions (25 without its 3 table meters), no CPU, memory or performance meter, and no thresholds. The AC cannot be met as worded.
  - Recommended amendment (epics.md 6.9 AC2, prd.md FR-56 consequence 2, the epic context): "Meter names come from the admin API's `Monitor` system-usage and dashboard answers."
    - **Performance:** global references per second and cache efficiency, as value meters.
    - **Memory:** shared memory used as a percentage of allocated.
    - **Status meters:** Database space, Journal space, Lock table and Write daemon, in the vendor's own words.
    - **CPU:** dropped from 6.9. No admin API source exists; `/api/monitor`'s SAM sensors would need `MonitorPort`, so CPU goes to FR-76's full dashboard (P1).
  - Alternative: build `MonitorPort` now for a CPU meter.
- **Q2: thresholds (a number with product meaning, ask first).** Nothing in `EnsembleMonitor` confirms 80%/95%. The vendor's only documented percentage cut-off is the lock table's 85%/95%, and its state words are computed in compiled `SYS.Metrics`.
  - Recommended: status meters take the vendor's word as their state. Percentage meters (shared memory) use 85% warning and 95% error, cited as the vendor's lock-table cut-off.
  - Amend DESIGN.md's meter `[ASSUMPTION]` row and `meter` paragraph to match.
- **Q3: UX conflicts (tier-1 corrections, apply and report).** Recommended settlements:
  - State words: show the dashboard's own "Normal" / "Warning" / "Troubled". EXPERIENCE.md's "normal / warning / alert" becomes those words.
  - Normal fill: `success`. EXPERIENCE.md is canonical on behavior, and `--ocu-success` exists. Amend DESIGN.md's `secondary`.
  - Pending glyph: "—" with a skeleton. Amend DESIGN.md's "…".
- **Q4: read shape (architectural weight, AD-36 amendment by Rule 20).** The screen needs three vendor answers (`SYSTEMUSAGE` one object, `SYSTEMUSAGESHM` rows, `DASHBOARDMAIN` one object). The grammar holds one source per read, and `AdminPort` cannot name unprefixed types.
  - Recommended: an admin `GET`-like source may declare `parts`, a bounded list (at most 3) of `{type, as}`. Each part answers one object, or its `Total` row for a row list. The parts merge into the read's one row under `<as>.<member>` fields, using the existing member-field grammar. Screen and tool get the same one row, capped at one.
  - Alternative: counters only in the read, with shared memory and the dashboard answer as the screen-only payload. That keeps meters out of the tool, and so out of the agent's reach.

**Ledger inbox:** `slice 6-9-system-usage-and-the-dashboard-meters` owns no entries. DW-1001 and DW-1018 are not re-filed.

**Integration ACs:** the Integration AC; AC1 through the page.

**Consumes:** `AdminPort` (2.1), `Screen.Read` (2.x, 6.7), the refresh framework (1.14), the gate (1.9).

**Consumed-by:** 6.11 Database details (the meter component, free space); 4.4 (screen context through the descriptor); FR-76's full dashboard (P1, reuses the meter and the `Monitor` types).

## Verification

Stateful steps run on the slot B throwaway `ocupilot-b-ci` only. `ocupilot-slot-b` is compiled into and read, never otherwise changed.

**Commands:**

- `uv run scripts/check-objectscript.py` -- expected: 0 findings.
- Load and compile `src/OcuPilot/` through the IRIS MCP tools with `server: "ocupilot-slot-b"`, namespace HSCUSTOM -- expected: clean.
- `sh scripts/ci-throwaway.sh up --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci --web 52777 --super 1976` -- expected: healthy. Teardown only if this run brought it up: `sh scripts/ci-throwaway.sh down --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci`.
- From `ui/`: `node tools/ci-runner.mjs --container ocupilot-b-ci --class <Class>`, one class per call, for SystemUsage, WireSecurityRead, Wire, ReadTool, ScreenRead, Descriptor, Smoke and the read-source corpus test -- expected: green, totals confirmed from `%UnitTest_Result`.
- `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` -- expected: `systemusage` passes.
- `cd ui && npm run build && npm test` -- expected: green, `screen-mirror --check` clean.
- From `ui/`: `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci npm run test:browser` -- expected: `system-usage.browser-spec.mjs` green.
- `bash scripts/lint-docs.sh` -- expected: clean.

**Mutations to record (Rule 19):**

- AC1: `BlockReads` dropped from the read fields.
- AC2: the warning branch returns normal; a transition added to the fill.
- AC3: refresh binding omitted.
- Pairs: `%Admin_Operate:USE` dropped.
- Integration: a read field misspelled.

## Auto Run Result

Status: blocked
Blocking condition: intent gap

Story 6.9's meter AC cannot be met as worded, and the numbers it asks to confirm are not in the named source. `%CSP.UI.Portal.EnsembleMonitor` is the Interoperability production monitor. It has 28 meter definitions, not 25, and no CPU, memory or performance meter. None of its meters sets a threshold, so 80%/95% cannot be confirmed there. The read also needs three `Monitor` request types that the one-source grammar and `AdminPort`'s `TYPE`-prefix resolution cannot express. Open questions Q1-Q4, with recommended amendments, are under Design Notes. The counters themselves are settled: `AdminPort` over `%Api.Admin.Endpoints.Monitor`, with no `MonitorPort`.
