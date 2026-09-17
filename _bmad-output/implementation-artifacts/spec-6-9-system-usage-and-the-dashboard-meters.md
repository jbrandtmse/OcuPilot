---
title: 'System usage and the dashboard meters'
type: 'feature'
created: '2026-09-17'
status: 'done'
baseline_revision: '12cd5949cb352ac11b121267db8e18a9577e6a9a'
baseline_commit: '12cd5949cb352ac11b121267db8e18a9577e6a9a'
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

### Review Findings

Code review 2026-09-17 (full, four layers). Patched in the review pass; no decision-needed, no defer.

- [x] [Review][Patch] `BARETYPES` copied the vendor's type numbers and claimed `Monitor` publishes no parameter; it publishes `SYSTEMUSAGE` 15, `SYSTEMUSAGESHM` 14 and `DASHBOARDMAIN` 12 (probed on slot B). Now a per-endpoint list resolved through the bare parameter [src/OcuPilot/Port/AdminPort.cls:132]
- [x] [Review][Patch] Shared memory's readout was the raw `SMHUsed` (400 beside a 40% fill), and a zero allocation drew a full green fill; the readout is now the percentage with `%` [ui/src/app/areas/os-management/system-usage.store.ts:117]
- [x] [Review][Patch] A loaded status meter showed the pending dash beside its word; the word is now its whole readout [ui/src/app/shell/meter.ts:180]
- [x] [Review][Patch] A fault before the first success left the counters skeleton and `aria-busy` on for good [ui/src/app/areas/os-management/system-usage.page.ts:173]
- [x] [Review][Patch] "Issues only its parts, in declared order" had no assertion; the fixture's recorded types are now asserted [src/OcuPilot/Test/SystemUsage.cls:193]
- [x] [Review][Patch] The meter readout sat under the track; DESIGN.md puts the value right of it [ui/src/styles/_components.scss:3549]
- [x] [Review][Patch] Browser AC1/AC2 asserted before the read landed (waited only for `app-meter`) [ui/browser/system-usage.browser-spec.mjs:158]
- [x] [Review][Patch] The store test's `PENDING_STATE` assertion passed with the fallback removed (`undefined !== null`) [ui/tools/system-usage-store.test.mjs:109]
- [x] [Review][Patch] Stale comments and titles (the meter's "refusal strip elsewhere", the Pairs mutation note, "nine counters", "keeps the last values on every meter") and dead code (store `CounterView`, page `STRINGS`, `void fixture`) [ui/src/app/shell/meter.ts:34]
- [x] [Review][Patch] Rule 19: AC1, AC2, AC3, Pairs, Parts and Integration had no recorded mutation; run and recorded under Verification [spec ## Verification]

Closed without a patch (ledger, `by=cr`): DW-1065 runtime scalar/1,000 check (wontfix-theoretical), DW-1066 generic fault tooltip, DW-1067 no meter role, DW-1068 part type unchecked at install, DW-1069 smoke row count only, DW-1070 Tick null-null, DW-1071 no parts+rowGet corpus case (wontfix-accepted), DW-1072 `meters` archetype bound to one page (wontfix-theoretical). DW-1015 occurrence appended.

Rejected:

- by-design: a fault after a success dashes the meter number and draws no refusal strip, per Boundaries "Failed" and EXPERIENCE.md's `meters` row.
- by-design: value meters draw no skeleton (Boundaries: no track); `>= 85`/`>= 95` are the gate's inclusive cut-offs; the percentage words are the spec's own Normal/Warning/Troubled; the skeleton and the track share `surface-container-high` per DESIGN.md.
- false: `CopyAs` regresses a literal dotted key (no other descriptor declares a field with two dots); `CopyAs` depth is unbounded (the grammar bounds it to two members).
- low: the browser spec does not cover AC3 (the page spec does); the denied deep-link test compares a constant string (its page assertions carry it).

## Spec Change Log

- 2026-09-17 (spec gate, orchestrator answers): Q1 (a) meter names and values from the admin `Monitor` answers through `AdminPort`, CPU to FR-76, epics.md 6.9 AC2 and prd.md FR-56 amended; Q2 (a) status meters take the vendor's word, percentage meters 85/95 labeled in DESIGN.md as borrowed from the vendor lock-table cut-off; Q3 accepted (Normal/Warning/Troubled, `success` fill, "—" with a skeleton; DESIGN.md and EXPERIENCE.md amended); Q4 accepted (AD-36 `parts`, at most 3, merged into one bounded row; `AdminPort` maps unprefixed request types). Status reset to `draft` for re-plan.
- 2026-09-17 (re-plan): intent block rewritten to the answers. Changes: empty entity type instead of a new enum value (no `Kernel/EntityType.cls` edit); the three types as parts of one `GET`; the "CPU" and "dashboard" aliases dropped; the classic key observed; the side-bar position corrected to 3.

## Review Triage Log

### 2026-09-17 — Review pass

- verdicts: 22 findings — high 0, medium 0, low 9, false 13, maybe-false 0
- findings:
  - `low` `patch` blind-hunter: `AdminPort.BareType` loops every `BARETYPES` entry after a match instead of stopping, so a future duplicate key would silently resolve to whichever sorts last — added `Quit` after the match in `AdminPort.cls:156`; recompiled on slot B and the throwaway, `OcuPilot.Test.SystemUsage` and `OcuPilot.Test.WireSecurityRead` re-run green.
  - `false` `reject` blind-hunter: three `SharedMemory.*` table columns share one `labelKey` — refuted: `system-usage.page.ts`'s `counterViews` filters to `isCounterField` (`Usage.*` only), so those columns and their shared label are never rendered; the underlying field keys stay distinct wherever consumed.
  - `false` `reject` blind-hunter: `SharedMemory.SMHAvailable` is read but never rendered — refuted: it is part of the declared 18-field read/tool contract (`osmgmt.systemusage.read` in `Test/ReadTool.cls`) by design (Read.cls: "one row for screen and tool"); not every declared field must reach the page.
  - `false` `reject` blind-hunter: `Meter.displayValue`'s bare `String(value)` skips `cellView`'s number formatting — refuted: `cellView`'s "number" kind formatting is `textOf(value)` = `JSON.stringify(number)`, functionally identical to `String(value)`; neither path rounds or groups.
  - `low` `reject` blind-hunter: no ARIA meter/progressbar role on the track — real gap, but EXPERIENCE.md's Accessibility Floor names "meter state" only under "Color never alone" (already satisfied by the shown word) and does not require a range role here, unlike the resize-handle where the design doc explicitly does; a correct role would also have to span the non-numeric status-meter shape, which is more than a direct fix.
  - `false` `reject` blind-hunter: `emptyStateKey`/`systemUsageEmpty` looks unreachable — refuted: every read-declaring descriptor must declare `emptyStateKey` as a structural (`TableProblem`) obligation regardless of runtime reachability; the story's own test comment already documents that zero rows never occurs for this archetype.
  - `low` `reject` blind-hunter: the two value meters show no unit — real minor ambiguity, but the code comment documents the deliberate choice not to invent copy absent from EXPERIENCE.md's Fixed strings (project convention); low everyday impact and the fix (minting new UI copy) is more than a direct correction.
  - `false` `reject` blind-hunter: bare-type test coverage looks asymmetric (only `SYSTEMUSAGE` gets a negative "elsewhere" case) — refuted: `BareType`/`EndpointType` resolution is suffix-generic, so one representative negative case covers the shared path for all three `BARETYPES` entries; the other two are additionally proven correct end-to-end by the live parts-merge test.
  - `false` `reject` blind-hunter: no `ARCHITECTURE-SPINE.md` change accompanies the new `parts` grammar — refuted: `ARCHITECTURE-SPINE.md:411`'s AD-36 already states the exact extension, naming "System usage, Story 6.9" by name, predating this diff's baseline.
  - `low` `reject` blind-hunter: `Meter`'s `state === null` overload has no runtime guard — real but speculative: the invariant is enforced by TypeScript's type system and documented at the sole existing caller; a runtime guard for a currently-single, correct caller is unrequested extra complexity.
  - `false` `reject` blind-hunter: `meterStateFromWord`'s fallback looks visually indistinguishable from a real "Warning" — refuted: the fallback preserves the vendor's original word verbatim (`meter-state.ts:29`), so an unrecognized value reads with its own text even though it shares warning's color, exactly as Boundaries specify.
  - `false` `reject` blind-hunter: `OcuPilot.Test.Read.ReadFixture`'s wiring "isn't visible in this diff" — refuted: it is a pre-existing class (used by `Test/ErrorLog.cls` before this story); independently re-ran `OcuPilot.Test.SystemUsage` (6/6 pass) confirming the wiring works.
  - `false` `reject` edge-case-hunter: `PartsObject` has no lower-bound guard against a zero-length `parts` array — refuted: it is only ever called with the descriptor's installed, `Registry.PartsProblem`-validated array (`Read.cls:286`), the same install-time-validate/runtime-trust pattern every other grammar rule in `Registry.cls` uses.
  - `low` `patch` edge-case-hunter: same `AdminPort.BareType` no-short-circuit finding as above — grouped with the blind-hunter row; same fix.
  - `false` `reject` edge-case-hunter: `CopyAs`'s new descent loop might not resolve a dotted field whose later segment is a literal flat key rather than a nested object — refuted: none of the 18 declared fields need that shape (each is single-level or a genuinely nested two-level vendor object per the Code Map), the new algorithm matches its own doc comment exactly, and the pre-diff baseline (`git show`) could not have resolved a genuine two-level field like `Dashboard.Performance.GlobalRefsPerSecond` at all, so there is no regression versus any field this or a prior story declares.
  - `low` `patch` edge-case-hunter: `meterViewFor`'s `'percent'` branch calls the hardcoded `sharedMemoryPercent(row)` instead of reading `config.field`/`config.denominatorField`, contradicting the type's own doc comment that `denominatorField` is used by the percent kind — added a generic `percentFromFields` helper, had `sharedMemoryPercent` delegate to it (preserving its existing exported signature and test), and switched `meterViewFor` to call it with `config.field`/`config.denominatorField`; `system-usage-store.test.mjs` (9/9), `npm test` (1312/1312) and the browser spec (3/3) re-run green.
  - `false` `reject` edge-case-hunter: `CopyAs` sets `tSource = pFrom` before confirming `pFrom` is an object — refuted: when `pFrom` is not an object, `tType` stays `"unassigned"` throughout, so the `"unassigned"` branch fires and `tSource` is never dereferenced.
  - `low` `reject` edge-case-hunter (claim): the task list says the browser spec covers "AC1 to AC3", but it only exercises AC1, AC2 and the denied deep link — true as far as the browser spec alone goes, but AC3 (silent tick, no `aria-live`) is genuinely verified by `system-usage.page.spec.ts`'s dedicated AC3 test, so there is no functional gap; the only fix is correcting the spec's own task-list wording, which is out of scope for a code patch.
  - `low` `reject` verification-gap (other finding): same `AdminPort.BareType` no-short-circuit finding as above, independently — grouped with the blind-hunter/edge-case-hunter rows; same fix.
  - `false` `reject` intent-alignment: the Matrix's "last values kept with the refusal strip" phrase might mean a page-level banner rather than the per-meter tooltip the code implements — refuted on the spec's own text: the more precise Boundaries section is unambiguous ("Failed: '—' with the error in its tooltip"), the implementation is internally consistent with it and documented, and no other archetype or EXPERIENCE.md row uses "refusal strip" as a defined term; any fix would be to the spec's own loose wording, not the code.
  - `false` `reject` intent-alignment: "no CSS transition or animation on the fill, ever" might also bar the pending skeleton's animation — refuted: the same Boundaries sentence already distinguishes "the fill" from "a skeleton in place of the fill" as different elements, and the codebase's universal skeleton pattern (`_components.scss`'s `ocu-skeleton-pulse`, honoring `prefers-reduced-motion`) already animates skeletons everywhere else in the app.
  - `false` `reject` intent-alignment: the Matrix's "parts with rowGet" refusal scenario has no dedicated corpus case — refuted: `Registry.cls`'s `RowGetProblem` runs before `PartsProblem` (`:936` vs `:947`) and already refuses any `rowGet` lacking a valid route-id `criteria`; since `parts` structurally excludes `criteria`, the combination is caught by the pre-existing, already-tested `RowGetProblem` rule before `PartsProblem` ever runs, so no dedicated case is needed for the two engines to agree.

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

- AC1: `Usage.BlockReads` dropped from the read fields. `mutation: system-usage.store.ts isCounterField excludes Usage.BlockReads → system-usage.page.spec.ts "AC1: reads once, and renders the counters…" red; reverted.`
- AC2: the warning branch returns normal; a transition added to the fill. `mutation: meterStateFromPercent's 85 branch returns state normal → page spec "AC2: a warning or error state colors…" red; .ocu-meter-fill transition: none → width 0.2s → meter.spec.ts ".ocu-meter-fill sets transition and animation to none" red; both reverted.`
- AC3: refresh binding omitted. `mutation: SystemUsagePage refresh.bind removed → page spec "AC3: with the chip at 5 s…" red; reverted.`
- AC4: the 85 comparison changed to 86. `mutation: meter-state.ts's meterStateFromPercent 85 bound raised to 86 → ui/tools/meter-state.test.mjs "meterStateFromPercent: below 85 is Normal, at or above 85 is Warning, at or above 95 is Troubled" went red (85 read as Normal instead of Warning); reverted, tree byte-identical.`
- Pairs: `%DB_IRISSYS:READ` dropped. `mutation: SystemUsage descriptor privileges without %DB_IRISSYS:READ, compiled on ocupilot-b-ci → WireSecurityRead.TestTheSystemUsagePairSetIsEnforcedForARealPrincipal red on the operate-only refusal assertions; reverted, class re-run green.`
- Parts: the `Total` match loosened to a prefix. `mutation: Read.TotalRow matches $Extract(Description,1,5)="Total" → SystemUsage.TestTwoPartsMerge… red; an extra base GET issued before the parts → the same test red on "only the declared parts are issued, in declared order"; both reverted.`
- Integration: a part `as` misspelled. `mutation: Read.CopyAs stops one member short and projects the group object → SystemUsage.TestTheReadToolAnswersTheSameRowAsTheRoute (and Live) red on the scalar assertion; reverted, class re-run green.`

## Auto Run Result

Status: done
Blocking condition: none

**Summary:** Implemented the System usage screen: an admin `GET` on `Monitor` with three merged `parts` (`SYSTEMUSAGE`, `SYSTEMUSAGESHM`, `DASHBOARDMAIN`) feeding one bounded 18-field row, a new `SystemUsage` descriptor under `os-management`, a shared framework-free `meter-state` module and `app-meter` component, and a page with a counters group plus seven meters, auto-refreshing at 5/10/30/60 s.

**Files changed:**

- `src/OcuPilot/Port/AdminPort.cls` — per-endpoint bare-type map (`BARETYPES`) so `Monitor`'s unprefixed vendor types resolve; short-circuits on the first match (review patch).
- `src/OcuPilot/Screen/Registry.cls`, `ui/tools/screen-mirror.mjs`, `src/OcuPilot/Test/ReadSourceCorpus.cls`, `src/OcuPilot/Test/ReadSource/Parts.cls` (new), `src/OcuPilot/Test/ReadSource/Endpoint.cls` — admit and validate `source.parts` identically in both engines, with corpus coverage.
- `src/OcuPilot/Screen/Read.cls` — issues declared parts in order, merges them (object, or exact `Total` row), fails the whole read on any part fault, and projects `<as>.<member>[.<member>]`.
- `src/OcuPilot/Screen/Descriptor/SystemUsage.cls` (new) — the descriptor: route, pairs, tool, table of 18 fields.
- `ui/src/app/core/meter-state.ts` + `ui/tools/meter-state.test.mjs` (new) — word/percent-to-severity mapping, framework-free.
- `ui/src/app/shell/meter.ts` + `meter.spec.ts` (new) — the shared meter component (OnPush, tokens only, no transition/animation on the fill).
- `ui/src/app/areas/os-management/system-usage.page.ts`, `system-usage.store.ts`, `system-usage.page.spec.ts`, `ui/tools/system-usage-store.test.mjs` (new); `ui/src/app/shell/screen-outlet.ts` — the page, its store, and `meters` archetype registration; `meterViewFor`'s percent branch reads `config.field`/`config.denominatorField` generically (review patch).
- `EXPERIENCE.md`, `ui/src/app/core/strings.ts`, `ui/tools/strings.test.mjs` — Fixed strings row and raised bound.
- `src/OcuPilot/Test/SystemUsage.cls` (new) — Live, Tick, Pairs, Bare-type-elsewhere, parts-merge/Total-row/whole-read-fault, and the Integration AC.
- `src/OcuPilot/Test/WireSecurityRead.cls` — the Pairs row against a real least-privileged principal.
- Roster tripwires: `Test/ReadTool.cls`, `Test/Wire.cls`, `Install/Smoke.cls`, `Test/Smoke.cls`, `ui/tools/navigation.test.mjs`, `ui/tools/navigation-wire.test.mjs`, `ui/tools/screen-mirror.test.mjs`, `ui/src/app/shell/rail-wire.spec.ts`.
- `ui/browser/system-usage.browser-spec.mjs` (new) — AC1, AC2 (including a real computed-style check on the fill), and the denied deep link.

**Review findings breakdown (22 findings across 4 layers):** 2 patched (both `low`): `AdminPort.BareType` now stops at its first `BARETYPES` match instead of silently taking a future duplicate's last entry; `meterViewFor`'s percent branch now computes generically from `config.field`/`config.denominatorField` instead of a hardcoded field pair, matching its own type's doc comment. 20 rejected — 13 refuted on verification (false), 7 real-but-cosmetic or spec-wording issues where the fix would be more than a direct code correction or would mean editing this spec (ARIA meter semantics, no unit on the two value meters, no runtime guard on `Meter`'s `state === null` contract, asymmetric-looking bare-type test coverage, and three intent-alignment wording ambiguities all resolved by the spec's own more precise text or by a pre-existing rule that already covers the scenario). Full detail in `## Review Triage Log` above.

**Follow-up review recommendation:** false. Only two `low` entries were patched (no `high`, no two-or-more `medium`), so this has converged.

**Verification performed:**

- `uv run scripts/check-objectscript.py` — 0 problems, 360 files (re-run after the patches).
- `bash scripts/lint-docs.sh` — clean (re-run after the patches).
- Full `src/OcuPilot/` loaded and compiled on `ocupilot-slot-b`, HSCUSTOM — clean; `AdminPort.cls`'s patch additionally loaded and compiled directly onto the throwaway `ocupilot-b-ci`.
- `node tools/ci-runner.mjs --container ocupilot-b-ci`, one class per call: `SystemUsage` 6/6, `WireSecurityRead` 14/14 (both re-run after the `BareType` patch) — plus, before the patch, `Wire` 20/20, `ReadTool` 26/26, `ScreenRead` 22/22, `Descriptor` 35/35, `OcuPilot.Test.Inventory` (the runnable class behind "AdminInventory") 5/5, `Smoke` 32/32 — 160 ObjectScript unit tests total, 0 failed.
- `bash scripts/smoke.sh --container ocupilot-b-ci` — 36 passed, 0 failed, 2 pending (Epic 3), 1 skipped (agentswitches, instance-state-dependent); `systemusage` explicit pass (re-run after the patches).
- `cd ui && npm run build && npm test` — build green (260.95 kB over the pre-existing 500 kB initial-bundle budget, unrelated to this story), 851 `node --test` + 461 vitest = 1312 tests, 0 failures (re-run after the `meterViewFor` patch, including `system-usage-store.test.mjs`'s 9/9).
- Bundle rebuilt and redeployed to `ocupilot-b-ci`; `system-usage.browser-spec.mjs` 3/3 (AC1, AC2 with a real `getComputedStyle` check, the denied deep link) — re-run after both patches.
- I/O & Edge-Case Matrix: every row covered by a passing test (Live/Tick/Bare-type-elsewhere/Integration in `Test.SystemUsage`; Pairs in `Test.WireSecurityRead`; Parts grammar in `ReadSourceCorpus`'s 13 cases; Meter state in `meter-state.test.mjs`; Meter fault across `meter.spec.ts`, `system-usage.page.spec.ts` and `system-usage-store.test.mjs`).

**Residual risks:** none identified. The throwaway `ocupilot-b-ci` is left running (healthy) since this run's own implementation subagent brought it up.
