---
title: 'System usage and the dashboard meters'
type: 'feature'
created: '2026-09-17'
status: 'ready-for-dev'
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

**Approach:** One listed `meters` descriptor under OS management declares one bounded read: an admin `GET` source on `Monitor` with three `parts` (`SYSTEMUSAGE`, `SYSTEMUSAGESHM`, `DASHBOARDMAIN`), merged into one row the screen and the tool share (AD-36). A new page draws the counters and a shared `meter` component in `shell/`, and it auto-refreshes through the shared framework.

## Boundaries & Constraints

**Always:**

- **Descriptor `OcuPilot.Screen.Descriptor.SystemUsage`:**
  - route `os-management/system-usage`, area `os-management`, `sideBarPosition` 3 (Processes · Locks · System usage · Databases · Devices; Locks is unbuilt), archetype `meters`, `built` true
  - `entityType` `""` (it administers nothing, so there is no change-event key and no `Kernel/EntityType.cls` edit), scope `instance`, `id.kind` `none`, `parentScope` `""`
  - `refreshes` true, rates `[5,10,30,60]`
  - pairs `%Admin_Operate:USE` then `%DB_IRISSYS:READ`, extended only by what a real least-privileged principal on the throwaway still refuses (AD-29)
  - tool `osmgmt.systemusage`; aliases `["system usage", "memory", "shared memory", "global references"]`; no primary or row action; `classicPage` `%cspapp.op.utilsysmonitor` (the key `%SYS.Portal.Resources.NormalizePage("/csp/sys/op/UtilSysMonitor.csp")` answers on slot B), exemption false; `secretFields` `[]`
- **Read:** `source` `{port: admin, endpoint: Monitor, type: GET, parts: [{type: SYSTEMUSAGE, as: Usage}, {type: SYSTEMUSAGESHM, as: SharedMemory}, {type: DASHBOARDMAIN, as: Dashboard}]}`. The 18 fields:
  - `Usage.` + AllGlobalReferences, GlobalUpdateReferences, RoutineCalls, LogicalBlockRequests, BlockReads, BlockWrites, JournalEntries, JournalBlockWrites, LastUpdate
  - `SharedMemory.` + SMHAllocated, SMHUsed, SMHAvailable
  - `Dashboard.Performance.` + GlobalRefsPerSecond, CacheEfficiency
  - `Dashboard.SystemUsage.` + DatabaseSpace, JournalSpace, LockTable, WriteDaemon
- **`parts` grammar** (Registry and mirror, same sentences, corpus-pinned): only on an admin `GET` with no `criteria`, `rowGet`, `forEach` or `query`; 1 to 3 parts; `type` matches `^[A-Z]+$`; `as` matches `^[A-Z][A-Za-z0-9]*$` and is unique; every field starts with a declared `as` and has one or two segments after it.
- **Parts at runtime:** a `GET` with parts issues only its parts, in declared order (Monitor answers `{}` for any type it does not name). An object answer merges under `<as>`. An array answer merges its row whose `Description` is exactly `Total`. A part with no such row, or with any non-2xx answer (404 included), fails the whole read with its named fault, never a partial row. Every projected value is a scalar of at most 1,000 characters.
- **`AdminPort`:** an additive per-endpoint map (`Monitor/SYSTEMUSAGE`, `Monitor/SYSTEMUSAGESHM`, `Monitor/DASHBOARDMAIN`) resolves a bare vendor parameter. Every other endpoint keeps `TYPE`-prefix resolution, and it is still reads only.
- **Meter** (`ui/src/app/shell/meter.ts`), inputs `(label, value, unit, percent | null, state | null, word | null, error | null)`:
  - Layout: a 6px `rounded.full` track (`surface-container-high`), the label in caption above, the value in code type beside it. It computes nothing from vendor data.
  - Fill: `success`, `warning` or `error` by state. The value text takes the same color and the word shows beside it.
  - Pending (`value` null, no error): "—" and a skeleton in place of the fill. Failed: "—" with the error in its tooltip.
  - No CSS transition or animation on the fill, ever. A meter with `state` null (a value meter) draws no track and no word.
- **Meter state** (`ui/src/app/core/meter-state.ts`, framework-free):
  - Vendor word: `Normal` → normal, `Warning` → warning, `Troubled` → error, any other word → warning. The vendor's word is shown.
  - Percentage: at or above 85 → warning ("Warning"), at or above 95 → error ("Troubled"), else normal ("Normal").
- **Meters on the page:**
  - Shared memory: `SMHUsed / SMHAllocated` as a percentage.
  - Database space, Journal space, Lock table, Write daemon: status meters in the vendor's words.
  - Global references per second, Cache efficiency: value meters.
  - Counters group: global references, global updates, routine calls, logical block requests, block reads, block writes, journal entries, journal block writes, last update.
- Shared files are additive only. New Fixed strings rows go after EXPERIENCE.md's last table row. Non-ASCII in code is written as `\uXXXX`.

**Never:**

- No `MonitorPort`, no HTTP to `/api/monitor` or `/api/admin` (AD-1, AD-27), no CPU meter (FR-76), and nothing sourced from `EnsembleMonitor` or `UtilSysMonitor`.
- No ECP, queues, tasks, license, alerts or `BusyProcesses`/`UpcomingTasks` members. No needle animation, no write, no classic link-out.
- No edits to `Kernel/**`, `Port/ProviderPort.cls`, `Screen/Tool/**`, `scripts/check-objectscript.py` or its test, `app.ts`, `app.spec.ts`, `ui/package*.json`, `angular.json`, `README.md`, `shell/panel/**`.

## I/O & Edge-Case Matrix

Reads are `GET /api/ocupilot/screens/osmgmt.systemusage/read`.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Live | `_SYSTEM` | 200, one row; all 18 fields are non-null scalar keys at most 1,000 characters; `Usage.BlockReads` and `SharedMemory.SMHAllocated` numeric; the four status fields in Normal/Warning/Troubled | — |
| Tick | two reads 5 s apart | `Usage.AllGlobalReferences` non-decreasing | — |
| Pairs | real principal holding `%Admin_Operate:USE` only; then the full declared set | 403 `AUTH.NOPRIVILEGE` naming `%DB_IRISSYS:READ`; then 200 | Never 500 |
| Bare type elsewhere | `AdminPort.Invoke("Process", "SYSTEMUSAGE", ...)` | 501 `PORT.NOTIMPLEMENTED` | Map is per endpoint |
| Parts grammar | parts on a `LIST`; 4 parts; duplicate `as`; a field outside every `as`; parts with `rowGet` | refused by both engines with the same sentence | Install refuses the descriptor |
| Meter state | word `Warning` / `Troubled` / unknown; percent 84.9 / 85 / 95 | warning / error / warning; normal / warning / error; word shown | — |
| Meter fault | a read faults after one success; or before any | last values kept with the refusal strip; before any success each meter shows "—" with the error tooltip | Not an empty state |

</intent-contract>

## Code Map

- **Vendor** (`%Api.Admin.Endpoints.Monitor`, hidden; read on slot B, read-only):
  - `ResourcesOR` is `%Admin_Operate` for every type, and nothing runs async.
  - `Run` is a `$CASE` over the unprefixed parameters `DASHBOARDMAIN` 12, `SYSTEMUSAGESHM` 14, `SYSTEMUSAGE` 15. Any other type answers `{}`.
  - `RunSystemUsage` returns an object of GLOSTAT totals (numbers) plus `LastUpdate`.
  - `RunSystemUsageSHM` returns an array of `{Description, SMHAllocated, SMHAvailable, SMHUsed, SMTUsed, GSTUsed, AllUsed}`. Its trailer rows are `Total`, `Available SMT & GST`, `Total SMT & GST Allocated` and `Total SMH Pages Allocated`; only the first is exact `Total`. Blank cells read 0.
  - `RunMain` returns an object: `Performance{GlobalRefsPerSecond, CacheEfficiency, …}` (numbers once commas are stripped) and `SystemUsage{DatabaseSpace, DatabaseJournal, JournalSpace, LockTable, WriteDaemon, …}` (words), plus ECP, Status, Alerts, Licensing and arrays.
  - The backing calls (`SYS.Metrics.GetMainMetrics`, `$$GUIstat^GLOSTAT`, the `SharedMemoryHeap` natives) ship compiled only, so only the principal run settles their pairs.
  - Documented cut-offs (`irissys/SYS/Stats/Dashboard.cls`): LockTable Warning above 85%, Troubled above 95% (`:92-94`); WriteDaemon Normal/Troubled (`:96-98`).
  - `src/OcuPilot/Test/AdminInventory.cls:68` already lists `Monitor`.
- **Port** (`src/OcuPilot/Port/AdminPort.cls`):
  - `Invoke(pEndpoint, pType, ByRef pQuery, pBody, Output pResult, Output pHttpStatus, Output pFault)` is at `:314`.
  - `EndpointType` (`:676-685`, private) takes the class and applies `TYPESUFFIXES` (`:101`) and `$Parameter(class, "TYPE"_suffix)`; a miss is 501 at `:340-344`.
  - Pass `pEndpoint` in and add a map parameter in `QUERYPAIRS`' `<endpoint>/<type>` grammar (`:130`). Do not widen `TYPESUFFIXES`, which `QueryPairsProblem` (`:517-523`) also reads.
- **Grammar:**
  - `Screen/Registry.cls` `ReadProblem`: source keys `:816`, where `parts` is admitted; GET block `:837-862`; `fields` `:918`; `TableProblem` `:1005` (runs for every read: one `name` column, `emptyStateKey`, `emptyNextKey`); admin `%DB_IRISSYS:READ` rule `:1014-1025`. An empty `entityType` is legal (`Validate :176-187`).
  - `ui/tools/screen-mirror.mjs` `readProblem :495`: source keys `:511`, GET block `:536-550`, fields `:606`. `BuiltArchetypeKey` is emitted from built descriptors (`:1618-1639`).
  - `src/OcuPilot/Test/ReadSourceCorpus.cls` XData `Cases` (`:12`, case shape `:49`) is run by `Test/ReadTool.cls:224` and `ui/tools/screen-mirror.test.mjs:438-452`.
- **Read** (`Screen/Read.cls`): guard `:215`; GET branch `:246-297` (`Invoke` `:271`, 404 → `[]` `:273-279`, wrap `:295`); projection `Project :759` → `CopyAs :782-800`, which goes one level down. A part field walks `<as>` and then up to two members.
- **Client:**
  - `shell/screen-outlet.ts` `ARCHETYPE_PAGES :54-62`, a required key per `BuiltArchetypeKey`, pinned by `screen-outlet.spec.ts:333`. Add `meters: SystemUsagePage`.
  - Pattern: `areas/os-management/process-details.page.ts:123-206` (`stores.for`, `refresh.bind(screen, createScreenRead(...))`, `readNow`, `REFRESH_ACTION_ID`, the generation signal, `showSkeleton`/`showRefusal`, `DestroyRef` unbind), its spec `:108-247`, and the pure store test `ui/tools/process-details-store.test.mjs`.
  - Tokens: `_tokens.scss` (`--ocu-success :141`, `--ocu-warning :146`, `--ocu-error :62`, `--ocu-surface-container-high :83`); `.ocu-skeleton-bar` in `_components.scss:76-95`. `client-lint.mjs` forbids hardcoded colors.
- **Strings:** `core/strings.ts:53`. `ui/tools/strings.test.mjs` requires set equality with the Fixed strings table, with a bound of 400 at `:327-330` and 399 used, so raise the bound. The last table row is EXPERIENCE.md `:362`.
- **Rosters:**
  - `Test/ReadTool.cls` count `:93` (28→29), names `:94`, pairs `:100`, grammar list `:263`
  - `Test/Wire.cls:675` and `Test/WireSecurityRead.cls:497,507` os-management screens JSON
  - `ui/tools/navigation.test.mjs:126-145`, `screen-mirror.test.mjs:603`, and the `LIVE_PAYLOAD` in `navigation-wire.test.mjs:74-98` and `shell/rail-wire.spec.ts:74-97`
  - `Install/Smoke.cls` (`processdetails` check `:696-764` as the model) and `Test/Smoke.cls` (`:458-469`, path count `:566-573` 23→24, skipped names `:669`)
- **Browser:** `ui/browser/processes.browser-spec.mjs` (`signedInAtList :129`, chip `:453-463`, inline `irisSession` principal setup `:78`, live-container guard `:114`).

## Tasks & Acceptance

**Execution:**

- [ ] `src/OcuPilot/Port/AdminPort.cls` -- add the per-endpoint bare-type map and pass the endpoint into `EndpointType` -- `Monitor`'s types carry no `TYPE` prefix.
- [ ] `src/OcuPilot/Screen/Registry.cls`, `ui/tools/screen-mirror.mjs`, `src/OcuPilot/Test/ReadSourceCorpus.cls` -- admit and validate `source.parts` per Boundaries, with identical sentences and one corpus case per refusal plus one sound case -- AD-36 grammar in both engines.
- [ ] `src/OcuPilot/Screen/Read.cls` -- issue the parts, merge them (object, or exact `Total` row), fail whole on any part fault or a missing `Total`, and project `<as>.<member>[.<member>]` -- one row for screen and tool.
- [ ] `src/OcuPilot/Screen/Descriptor/SystemUsage.cls` (new) -- the declaration per Boundaries. `table` lists all 18 fields with `Usage.LastUpdate` as the `name` column, `emptyNextKey` `tableReadOnlyEmptyNext`, and a new `emptyStateKey`.
- [ ] `ui/src/app/core/meter-state.ts` + `ui/tools/meter-state.test.mjs` (new) -- word and percentage to `{state, word}` per Boundaries -- pure, reused by 6.11.
- [ ] `ui/src/app/shell/meter.ts` + `meter.spec.ts` (new) -- the component per Boundaries (OnPush, tokens only).
- [ ] `ui/src/app/areas/os-management/system-usage.page.ts`, `system-usage.store.ts`, `system-usage.page.spec.ts`, `ui/tools/system-usage-store.test.mjs` (new); `ui/src/app/shell/screen-outlet.ts` -- counters group plus the seven meters from the row, bound like Process details; register `meters`.
- [ ] `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` (one Fixed strings row after `:362`), `ui/src/app/core/strings.ts`, `ui/tools/strings.test.mjs` -- title, labels, units, Normal/Warning/Troubled, empty state; reuse existing values; raise the bound; regenerate the mirror.
- [ ] `src/OcuPilot/Test/SystemUsage.cls` (new) -- matrix rows Live, Tick and Bare type elsewhere, a two-part fixture pinning the `Total`-row rule and the whole-read fault, and the Integration AC.
- [ ] `src/OcuPilot/Test/WireSecurityRead.cls` -- the Pairs row with real principals on the throwaway; append any pair the instance still refuses (descriptor, `Screen/Area.cls` union if needed).
- [ ] Rosters in the Code Map, plus the Smoke check `systemusage` -- roster tripwires.
- [ ] `ui/browser/system-usage.browser-spec.mjs` (new) -- AC1 to AC3 and the denied deep link for the `%Admin_Operate:USE`-only principal.

**Acceptance Criteria:**

- AC1: Given System usage on the throwaway, when it loads, then it shows global references, routine calls, block reads, block writes, journal entries and shared memory with live values, the seven meters, and a refresh chip offering 5/10/30/60 s.
- AC2: Given a meter before its first value, when it renders, then it shows "—" with a skeleton. Given a warning or error state, then the word shows and the warning or error color is on both the fill and the value text. The fill's computed `transition-duration` and `animation-name` are `0s` and `none`.
- AC3: Given the chip at 5 s, when a tick fires, then the screen re-reads with no skeleton, no announcement and no `aria-live`.
- AC4 (thresholds): given a shared-memory percentage of 85 or 95, when the meter renders, then it reads Warning or Troubled. The numbers are DESIGN.md's labeled assumption, borrowed from the vendor's lock-table cut-off. They replace the story's "80%", which no meter definition carries.
- Integration: given `osmgmt.systemusage.read` called in process as the same user, when compared with the route's answer, then both carry the same 18 field keys and one row, and every value is scalar and at most 1,000 characters.

## Spec Change Log

- 2026-09-17 (spec gate, orchestrator answers): Q1 (a) meter names and values from the admin `Monitor` answers through `AdminPort`, CPU to FR-76, epics.md 6.9 AC2 and prd.md FR-56 amended; Q2 (a) status meters take the vendor's word, percentage meters 85/95 labeled in DESIGN.md as borrowed from the vendor lock-table cut-off; Q3 accepted (Normal/Warning/Troubled, `success` fill, "—" with a skeleton; DESIGN.md and EXPERIENCE.md amended); Q4 accepted (AD-36 `parts`, at most 3, merged into one bounded row; `AdminPort` maps unprefixed request types). Status reset to `draft` for re-plan.
- 2026-09-17 (re-plan): intent block rewritten to the answers. Changes: empty entity type instead of a new enum value (no `Kernel/EntityType.cls` edit); the three types as parts of one `GET`; the "CPU" and "dashboard" aliases dropped; the classic key observed; the side-bar position corrected to 3.

## Review Triage Log

## Design Notes

**Governing ADs:**

- AD-1, AD-2, AD-26, AD-27: `Monitor` is synchronous and in process, through `AdminPort` only.
- AD-8, AD-29: pairs are established by a real least-privileged principal on `ocupilot-b-ci`.
- AD-13, AD-14: scope `instance`, no entity type, no change-event key.
- AD-19: `meter-state` and the store are framework-free.
- AD-24, AD-36: one bounded row with `parts`, shared by screen and tool.
- AD-43: seventh roster screen, silent refresh.
- AD-44: the classic key, no link-out.

**Parts read only their parts.** Monitor's `Run` answers `{}` for any type it does not name, so a base `GET` call would add a gate and a call for nothing. A `GET` with parts therefore issues its parts alone.

**Member depth.** `DASHBOARDMAIN` nests its groups, so a part field is `<as>.<member>` composed with the existing `<object>.<member>` projection, at most two members deep. That bounds the row to declared scalars and keeps `BusyProcesses` and `UpcomingTasks` out.

**Value meters.** No vendor threshold exists for global references per second or cache efficiency, so they carry no state word or track rather than an invented "Normal".

**Ledger inbox:** `slice 6-9-system-usage-and-the-dashboard-meters` owns no entries.

**Integration ACs:** the Integration AC above; AC1 through the page.

**Consumes:** `AdminPort` (2.1), `Screen.Read` (2.x, 6.4, 6.7), the refresh framework (1.14), the gate (1.9).

**Consumed-by:** 6.11 Database details (the meter component and `meter-state`, free-space percentage); 4.4 (screen context through the descriptor); FR-76's full dashboard (P1, reuses the meter and `parts`).

## Verification

Stateful steps run on the slot B throwaway `ocupilot-b-ci` only. `ocupilot-slot-b` is compiled into and read, never otherwise changed. Every IRIS MCP call carries `server: "ocupilot-slot-b"`.

**Commands:**

- `uv run scripts/check-objectscript.py` -- expected: 0 findings.
- Load and compile `src/OcuPilot/` through the IRIS MCP tools, `server: "ocupilot-slot-b"`, namespace HSCUSTOM -- expected: clean.
- `sh scripts/ci-throwaway.sh up --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci --web 52777 --super 1976` -- expected: healthy. Tear down only if this run brought it up: `sh scripts/ci-throwaway.sh down --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci`.
- From `ui/`: `node tools/ci-runner.mjs --container ocupilot-b-ci --class <Class>`, one class per call and never two at once, for SystemUsage, WireSecurityRead, Wire, ReadTool, ScreenRead, Descriptor, AdminInventory and Smoke -- expected: green, with totals confirmed from `%UnitTest_Result`.
- `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` -- expected: `systemusage` passes.
- `cd ui && npm run build && npm test` -- expected: green, `screen-mirror --check` clean.
- From `ui/`: `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci npm run test:browser` (both variables on every run) -- expected: `system-usage.browser-spec.mjs` green.
- `bash scripts/lint-docs.sh` -- expected: clean.

**Mutations to record (Rule 19):**

- AC1: `Usage.BlockReads` dropped from the read fields.
- AC2: the warning branch returns normal; a transition added to the fill.
- AC3: refresh binding omitted.
- AC4: the 85 comparison changed to 86.
- Pairs: `%DB_IRISSYS:READ` dropped.
- Parts: the `Total` match loosened to a prefix.
- Integration: a part `as` misspelled.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Re-planned around the orchestrator's Q1-Q4 answers. Nothing remains open for planning.
