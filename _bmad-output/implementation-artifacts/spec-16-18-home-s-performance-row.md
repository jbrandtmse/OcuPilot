---
title: "Story 16.18: Home's performance row"
type: 'feature'
created: '2026-09-26'
status: 'done'
baseline_revision: '585d73b023e3655fb35bc71d312ca2d17041edcd'
baseline_commit: '6aa6d51c7d4c2cf4554c0ce3a56380825cc9ddce'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-16-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Home shows system information but nothing moving, so a person cannot tell at a glance whether the instance is busy or struggling. The other contest entries lead with live metrics.

**Approach:**

- Add a new `MonitorPort`, gated per AD-29. It reads the instance's dashboard sensors in-process (`SYS.Monitor.SAM.Sensors`, which is what `/api/monitor/metrics` serves) and exposes them on a new shell-chrome route, `GET /api/ocupilot/ui/performance`.
- Home joins AD-43's auto-refresh roster.
- A framework-free store feeds Home's refresh binding, the row, a ten-minute sparkline and Home's screen-context row.

## Boundaries & Constraints

**Always:**

- **One sample, five numbers.** One sensor collection per read. The route answers `{cacheEfficiency, globalReferencesPerSecond, globalUpdatesPerSecond, diskReadsPerSecond, diskWritesPerSecond}` as numbers from the unlabeled Prometheus lines:
  - `iris_cache_efficiency`
  - `iris_glo_ref_per_sec`
  - `iris_glo_update_per_sec`
  - `iris_phys_reads_per_sec`
  - `iris_phys_writes_per_sec`

  A missing or non-numeric metric fails the whole read. It is never a partial row.
- **The gate.**
  - The pair set is `%Admin_Operate:USE` and `%DB_IRISSYS:READ`, evaluated with `OcuPilot.Screen.Gate.EvaluateRequired` before any sensor call.
  - A refusal is the `Kernel.Denial` 403 envelope naming the failed pair.
  - The switch to `%SYS` is an explicit save and restore (AD-16).
  - `MonitorPort` is the only class that names `SYS.Monitor.SAM.Sensors`.
- **Home's declaration.** Home declares `refreshes: true` and `refreshRates: [5, 10, 30, 60]`, and appears in EXPERIENCE.md's Auto-refresh roster (AD-43, once amended). Its default rate is every 10 s, declared on its descriptor as the one exception to the published default of off (AD-43 as amended at the spec gate); a person can still turn it off, and that choice persists. Its rate persists under the preference name `home`, because its route is empty.
- **The row.**
  - It shows the last successful answer.
  - A 403 at any time clears it: no row, no heading, no zeros.
  - Any other fault before a first success leaves it absent. A fault after one keeps the last values, and the framework's own fault surfaces as usual.
- **The sparkline** plots only answers received while this Home view is open.
  - Each successful answer adds one point: client time and `globalReferencesPerSecond`.
  - Points older than 600 s are dropped.
  - Fewer than two points draw no line.
  - Leaving Home, a 403, and sign-out each clear it.
- **Home's context.** Home's `context.fields` are the five names, and the one store row is what the screen context sends (AD-24).
- **Copy.** All copy is added to EXPERIENCE.md Fixed strings and `strings.ts` before it is used. Tokens only.

**Never:**

- No HTTP call from OcuPilot to `/api/monitor`.
- No read tool, governance key or `Kernel/Governance/Gate.cls` change.
- No client-computed rate.
- No invented or backfilled history.
- No charting library, and no lazy load or `@defer`.
- No change to System Information's behavior or to Home's three suggested prompts.
- No edit to Epic 14's planned hunks: `Router.cls:127-128`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Present | Caller holds both pairs; the sensors answer all five | 200 with five numbers; row and one context row; sparkline point 1 | None |
| Second tick | Rate 5 s, two answers | Line drawn through two points | None |
| Ten minutes | Points older than 600 s | Dropped; line spans ≤ 600 s | None |
| Denied | Caller lacks `%Admin_Operate:USE` (or `%DB_IRISSYS:READ`) | 403 `Denial` naming the pair; the sensor call count is 0; no row, context rows `[]` | Refresh read answers `ok`/`[]`, so no fault stamp |
| Metric missing | Sensor text lacks one name, or has a non-numeric value | 500 generic envelope; nothing partial | Logged once; row keeps the last success, or stays absent |
| Labeled line | `iris_glo_ref_per_sec{id="x"} 5` | Ignored; only the bare line counts | — |

</intent-contract>

## Code Map

Server:

- `src/OcuPilot/Port/MgmntPort.cls` is the template for a non-admin port gate:
  - `PAIRS` :33, `GateClass` :109
  - `Invoke` gate :169-173
  - `Refuse` :569 and `Fail` :578
- `src/OcuPilot/Kernel/Shell/SystemInfo.cls` shows the `%SYS` switch (`Dashboard()` :121-135) and the fixture seam (`ReadSource()` :108, overridden by `Test/UiSystemFixture.cls`).
- `src/OcuPilot/Api/UiSystem.cls` is the thin-handler precedent. `Api/Ledger.cls:104` `RenderFault` renders a port fault.
- `src/OcuPilot/Api/Router.cls:139` holds `/ui/system`. Add `/ui/performance` after it; the target is beside `UiSystem()` at :842.
- `src/OcuPilot/Screen/Descriptor/Home.cls` is the declaration. Rewrite its doc comment lines 12-14 ("It does not refresh"). `LogErrorList.cls:92` is the precedent for `context.fields` on a read-less descriptor.
- `src/OcuPilot/Screen/Context.cls` `Build` :45 narrows rows to `ContextFields()` (:79, :106). Screen context is already generic.
- `src/OcuPilot/Api/Preferences.cls` `IsBuiltRoute` :377 refuses `""`. `IsValueKind` :356. The kind is `Kernel/State/Pref.cls` `KINDREFRESH` :80.
- `src/OcuPilot/Test/EndpointCoverage.cls:129` holds the `/ui/system` probe row. Add the new row beside it.

Client:

- `ui/src/app/areas/home/home.page.ts`:
  - template :262-419; System Information block :348-368
  - constructor :643-698; comment :673-676 to rewrite
- `ui/src/app/areas/os-management/system-usage.page.ts:125-146` is the refresh-binding pattern: `stores.for`, `refresh.bind(screen, read)`, `readNow`, `REFRESH_ACTION_ID`, and unbind on destroy.
- `ui/src/app/core/refresh.ts`:
  - `RefreshService.bind` :227 accepts a custom `RefreshRead` (:87, result :78)
  - a tick writes `store.applyTick`
- `ui/src/app/core/screen-store.ts`: `setRate` :494-497 and `adoptRemembered` :142 skip route `''`; `ScreenStores.for` :575.
- `ui/src/app/core/screen-context.ts`: `computeView` :93 (the `read === null` branch :99-102 sends store rows narrowed to `context.fields`) and `contextViewDeclared` :80.
- `ui/src/app/core/system-info.ts` is the store pattern: guarded `load` :122, `reset` :149, `SYSTEM_INFO_PATH` :28. Wiring:
  - `ui/src/main.ts`: created :215, provided :270
  - `ui/src/app/app.ts:632`: sign-out reset
  - `ui/src/app/testing/system-info.ts`: the stub
- `ui/src/app/core/strings.ts`: append after the `readBack*` keys, before `} as const` at :2903. Reuse three existing labels:
  - `systemUsageCacheEfficiency` :946
  - `processDetailsGlobalReferences` :895
  - `systemUsageGlobalUpdates` :926
- `ui/src/styles/_components.scss` (6,567 lines): the Home block styles are at :5010-5307. Append the row styles at the end.
- Structural gate: `ui/browser/read-back.browser-spec.mjs:213-231` is the two-theme pattern. The walker is `ui/browser/structural-walk.mjs`.
- `ui/browser/home-system-information.browser-spec.mjs` is the Home browser precedent. It covers principals, and wrap at 1,440 and 720 px.

**Contended:** Epic 14's 14.1 plans edits to `Router.cls:127-128`, `EndpointCoverage.cls`, `strings.ts` and `_components.scss`. This story only adds lines, away from those hunks. Epic 23 has no changes since the merge base.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Port/MonitorPort.cls` (new):
  - `PAIRS = "%Admin_Operate:USE,%DB_IRISSYS:READ"` and a `GateClass` seam.
  - `Performance(Output pValues, Output pHttpStatus, Output pFault) As %Status`:
    1. Gate.
    2. Save the namespace, switch to `%SYS`, run `Source()`, restore.
    3. Parse the text.
  - `Source()` returns `##class(SYS.Monitor.SAM.Sensors).PrometheusMetrics()`. It is a string, and it is the fixture seam.
  - `Parse(pText, Output pValues) As %Status` takes exact bare names and a numeric value.
- `src/OcuPilot/Kernel/Shell/Performance.cls` (new) is the shell read over the port. `src/OcuPilot/Api/UiPerformance.cls` (new) is the thin `HandlePerformance`: success through `Response.JSON`, a fault through the port's status and fault.
- `src/OcuPilot/Api/Router.cls`: add `<Route Url="/ui/performance" Method="GET" Call="UiPerformance"/>` after :139, and its thin target.
- `src/OcuPilot/Screen/Descriptor/Home.cls`:
  - `refreshes: true`
  - `refreshRates: [5, 10, 30, 60]`
  - `refreshDefault: 10` -- a new optional descriptor key (seconds, one of `refreshRates`; absent means off), validated identically by `Screen/Registry.cls` and `ui/tools/screen-mirror.mjs` and mirrored into `screens.generated.ts`; the refresh framework starts at it when no rate is persisted for the screen (AD-43 as amended). Only Home declares it; a test pins that no other descriptor does.
  - `context.fields` = the five names
  - rewrite the doc comment
- Then regenerate with `cd ui && node tools/screen-mirror.mjs`.
- `src/OcuPilot/Api/Preferences.cls`, the refresh kind's set and list only: accept the name `home`, declared once as a `Pref` parameter (for example `HOMEREFRESHNAME`). Every other kind still requires a built route.
- `ui/src/app/core/account-preferences.ts` exports `HOME_REFRESH_NAME = 'home'`. `screen-store.ts` keys the rate for descriptor `OcuPilot.Screen.Descriptor.Home` by it; every other `''` route still remembers nothing.
- `ui/src/app/core/performance.ts` (new, framework-free, AD-19):
  - `PERFORMANCE_PATH`
  - `PerformanceRow` with `read(): Promise<RefreshReadResult>` (per the matrix), `values()`, `denied()`, `points()`, `clearHistory()`, `reset()`, `subscribe()`
  - pure `sparklinePath(points, now, width, height)`: zero baseline; x spans 600 s from the first point, then scrolls
  - pure `formatPerformance`: rates are whole numbers with grouping; cache efficiency has one decimal
- Wire it in `main.ts`, `app.ts` (sign-out) and a testing stub.
- `ui/src/app/areas/home/performance-row.ts` (new, `OnPush`):
  - heading "Performance" and five label/value/unit items
  - an inline `<svg role="img">` with its label, carrying one `<path>` under Global references
  - rendered before the System Information block and only when values exist
  - wraps at 720 px
- `home.page.ts`:
  - get Home's store; bind `refresh` with `performanceRow.read` and `readNow()`
  - register `REFRESH_ACTION_ID`
  - on destroy, `clearHistory()` and unbind when it owns the binding
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`:
  - :83 in place: add the performance row to Home's contents.
  - :835 in place: add Home to the roster, and state that Home alone defaults to every 10 s (the line count stays the same).
  - Append one Fixed-strings row at 576 (the copy is in Design Notes).
  - The line count moves by one, after the table only. No `strings.ts` citation points past 575.
- `ui/src/app/core/strings.ts`: append the keys cited `/** EXPERIENCE.md:576 */`.
- `_components.scss`: append at the end.
- Update comments that state Home does not refresh: `home.page.ts:673-676`, `system-info.ts:18-19`, `Kernel/Shell/SystemInfo.cls:4-6`.
- Tests:
  - new `Test/MonitorPort.cls`: parse table through the seam; gate refused with sensor calls = 0; missing or non-numeric metric fails the read.
  - new `Test/UiPerformanceWire.cls` (HTTP on `ocupilot-ci`, marked principals):
    - code DB `:R` + `%DB_IRISSYS:R` → 403 naming `%Admin_Operate:USE`
    - code DB `:R` + `%Admin_Operate:U` → 403 naming `%DB_IRISSYS:READ`
    - both pairs → 200 with the five live numbers
  - `Test/EndpointCoverage.cls`: the probe row.
  - `Test/PreferencesWire.cls`: the `home` refresh rate is accepted; a `home` favorite is refused.
  - new `ui/tools/performance.test.mjs`.
  - Cases in `ui/tools/screen-store.test.mjs` and `ui/tools/screen-context.test.mjs`.
  - Home component cases in `ui/src/app/areas/home/home.page.spec.ts`.
  - new `ui/browser/home-performance.browser-spec.mjs`.

**Acceptance Criteria:**

- **AC1.** Given a caller holding `%Admin_Operate:USE` and `%DB_IRISSYS:READ`, when Home renders on `ocupilot-ci`, then a "Performance" row shows five values from one instance answer, each with its unit:
  - Cache efficiency, in refs per block read or write
  - Global references, /s
  - Global updates, /s
  - Disk reads, /s
  - Disk writes, /s
- **AC2.** Given Home open with auto-refresh at 5 s, when two answers have arrived, then the values update silently and the Global references sparkline draws a line through exactly the points received. On the first answer it drew none. After leaving Home and returning, it starts empty again.
- **AC3.** Given a caller lacking either pair, when Home renders, then no Performance heading, value or zero is drawn, and the rest of Home is unchanged.
- **AC4.** Given the row present, when a turn is sent from Home, then the screen context carries one row with the same five numbers. When the row is absent, the context carries none.
- **AC5.** Given Home's chip set to 10 s, when the user navigates away and back, or signs out and back in, then the chip reads every 10 s.
- **AC6 (Integration).** Home, the consumer, reads `GET /ui/performance` on `ocupilot-ci` and renders the row in both themes, passing the DW-1337 structural gate (wide and narrow, light and dark) with no new allowance. The bundle stays under 1900 kB.

## Spec Change Log

- 2026-09-26, lead, spec gate: AD-43 amended (the set is eight, Home added; a screen may declare its default rate, Home's is every 10 s) and AD-29 gained the `MonitorPort` paragraph, both as recommended below except the default rate, which the lead ruled on (tier-1: AC2 must hold without a person enabling refresh). Status reset to ready-for-dev.

## Review Triage Log

### 2026-09-26 — Review pass

- verdicts: 14 findings — high 0, medium 1, low 8, false 5, maybe-false 0
- findings:
  - `[medium]` `[patch]` Home's tick re-reading System Information would pass every test: the 15.4 timer case cannot see the framework tick, which `homeRefresh`'s `schedule` seam holds — patched: the AC2 tick case asserts `systemInfo.calls` unchanged, the 15.4 comment corrected; mutation recorded.
  - `[low]` `[patch]` AC2 (clearHistory, fewer than two points), AC4 (store row) and AC5 (instance `home` key) had no `mutation:` line — patched: four mutations run and recorded under Verification.
  - `[low]` `[patch]` `screen-context.test.mjs` asserted `contextRowsSent(... rows: [])` is 0, which cannot fail — patched: the assertion deleted; the `view.rows` assertion stays.
  - `[low]` `[reject]` Browser AC2's first-answer check is conditional and its point count allows `received - 1` — the response event can precede the render; `home.page.spec.ts` pins "none on the first answer" and exactly `M L`, and a tighter browser sync adds machinery for no new reach.
  - `[low]` `[patch]` `performance.test.mjs` asserted `denied()` false after `reset()` without ever denying — patched: the test is refused first and asserts `denied()` true before the reset; mutation recorded.
  - `[low]` `[reject]` The metric-missing 500 is tested on the port, not over HTTP — the handler passes the port's fault to `Error.Render` unchanged (`pDetail` defaults to `""`); an HTTP leg needs a new fault-injection seam on the route.
  - `[false]` `[reject]` A zero sensor-call count on denial is shown only with a test gate — the recorded "drop the gate" mutation turns `UiPerformanceWire`'s real-principal refusals red, so the gate order is proven on real principals too.
  - `[low]` `[reject]` "Turned off stays off" is not exercised in the browser — pinned in `screen-store.test.mjs`, `refresh.test.mjs` and `PreferencesWire` (value "0" under `home`); a browser leg would duplicate them.
  - `[low]` `[reject]` The rendered row (`PerformanceRow`) and the context row (`ScreenStore`) are two holders fed by one answer — both drop stale answers; the worst case is a context row one tick older than the row.
  - `[low]` `[reject]` A denied caller keeps the chip, the "Last update" stamp and a 10 s 403 poll — spec-bound: the Decisions choose an `ok`/`[]` tick for a 403 and the intent's "a 403 at any time" needs the reads to continue; a denial writes no audit record (`Screen/Gate.cls`, `Kernel/Denial.cls`).
  - `[false]` `[reject]` The shared framework change reaches all eight roster screens — for the others it only makes a remembered rate that lands after bind re-arm the timer, which AD-43/Story 15.5 already require; `refresh.test.mjs` pins it.
  - `[false]` `[reject]` Home's turn now always carries a `view` — the matrix's Denied row requires context rows `[]`, which is that view.
  - `[false]` `[reject]` One collection per read shortens external scrapers' windows — that is the intent's "one sensor collection per read" and AD-29's recorded (inference).
  - `[false]` `[reject]` The spec's Auto Run Result still read ready-for-dev -- finalize writes it.

## Design Notes

**Recorded in AD-43 and AD-29 at the spec gate (2026-09-26).** The halt as raised: A screen joins the auto-refresh set only by declaring it in its descriptor and appearing in the roster. AD-43's Rule enumerates the set as seven, so Home joining changes that Rule. It is the only AD-conformant path: any refresh on Home without joining is the per-screen refresh AD-43 exists to prevent.

Recommended text:

> AD-43 **Binds:** "…the eight auto-refreshing screens EXPERIENCE.md's Auto-refresh controls row enumerates". **Rule**, second paragraph: "**The set is eight, and EXPERIENCE.md's Auto-refresh controls row is the roster:** Processes, Process details, Databases, Database details, Task schedule, Task details, System usage, Home (the owner-decided six of DW-175, plus Process details on 2026-09-17, whose classic page refreshes, and Home on 2026-09-26, Story 16.18, whose performance row is the only part of Home a tick re-reads)…"; the rest unchanged.

The companion addition to AD-29 records `MonitorPort`'s first contract:

> "**`MonitorPort` reads the dashboard sensors in-process** — `SYS.Monitor.SAM.Sensors.PrometheusMetrics()` in `%SYS`, what `/api/monitor/metrics` serves (AD-1) — and is the only class that names it. Its pair set is `%Admin_Operate:USE` (the dashboard's own `ResourcesOR()`) and `%DB_IRISSYS:READ`, measured: neither the sensors nor `SYS.Stats.Dashboard` checks `%Admin_Operate`, and without `%DB_IRISSYS:READ` the switch to `%SYS` raises `<PROTECT>`. Its per-second values are the sensors' own, each over the interval since the previous collection (the vendor's stored previous value), so its reads shorten an external scraper's windows (inference)."

Once both are in the spine, set `status: ready-for-dev`. No other spec change is needed.

**Measured on `ocupilot-ci`, 2026-09-26.** The probe principals were removed.

- **Why not the dashboard's own source.** `/api/admin` `Monitor` `DASHBOARDMAIN` (`SYS.Metrics.GetMainMetrics`) answers only `GlobalRefsPerSecond` and `CacheEfficiency` as current values. `GlobalSetKill`, `DiskReads` and `DiskWrites` are totals, and its `GlobalRefsPerSecond` stayed 395 across 10 s while the sensors read 47,089 to 81,615.
- **The sensors.** They answer all five per second. Their `HELP` lines say "per second", and cache efficiency is "global references / physical reads + writes". It is labeled "(percentage)", but it read 8745.8, the same ratio as the dashboard. The vendor's doc comment calls the class "Collect all Dashboard and other SAM Sensors".
- **Cost and a first-read zero.** One collection took 60 to 71 ms. The first collection read 0 for every rate.
- **Least-privileged principals**, each with code DB `:R`:
  - `%Admin_Operate:U` alone: `<PROTECT>` entering `%SYS`.
  - `%DB_IRISSYS:R` alone: both the sensors and `SYS.Stats.Dashboard` answered.
  - Both pairs: the sensors answered.

**Why not a declared read (AD-36).** A declared read would gate all of Home (AD-8), which never gates, and would add a read tool. The row is shell chrome, like `/ui/system` (the AD-50 precedent). The agent receives the values through screen context (AD-24), not a tool.

**Copy for the EXPERIENCE.md row at 576, verbatim:**

> "Performance" · "Disk reads" · "Disk writes" · "/s" · "refs per block read or write" · "Global references per second, last ten minutes"

The Where column: "Home's performance row (Story 16.18): its heading; two labels beside the reused 'Cache efficiency', 'Global references' and 'Global updates'; the unit of the four rates, and the unit of cache efficiency; and the sparkline's accessible name. Absent, not zeros, for a caller without the dashboard's pairs." [ADDED 2026-09-26 - Story 16.18]

**Governing ADs:** AD-43, AD-29, AD-1, AD-5, AD-8, AD-11, AD-12, AD-16, AD-19, AD-20, AD-21, AD-24, AD-36, AD-39, AD-46, AD-50, NFR-1.

- **AD-46:** the row shows instance metrics, and nothing of OcuPilot's own is hidden or exposed.
- **NFR-1:** the row loads after Home's first paint and adds about 70 ms per read.

**Decisions:**

- Home's default rate is every 10 s (lead ruling at the spec gate, AD-43): with the published default of off, AC2's "refreshes while Home stays open" and the ten-minute line would hold only after a person turned refresh on, and the first sensor collection reads 0. Every other screen stays off by default.
- Home's prompts are unchanged, because Home is not a new screen (11.3).
- A 403 returns an `ok`/empty tick, so a caller without the pairs sees no fault stamp.

**Integration ACs.**

- **Consumes:** none from another story.
- **Consumed-by:** 16.18's Home (AC6); 16.7's full dashboard (inference).

**Governance:** Story 14.2's baseline is held. No tool is added, and `Gate.cls` is untouched. DW-118 is declined, because Story 15.6 already resolved it. The ledger inbox is empty.

**Bundle:** one small component and one store; no library, no lazy load.

## Verification

**Commands:**

- `cd ui && node tools/screen-mirror.mjs --check && node --test tools/performance.test.mjs tools/screen-store.test.mjs tools/screen-context.test.mjs tools/strings.test.mjs tools/citations.test.mjs` (loop). Expected: green. Mutations to record:
  - Append a point on a 403 → the "starts empty" case goes red.
  - Keep points older than 600 s → the prune case goes red.
- `cd ui && npx ng test --include src/app/areas/home/home.page.spec.ts` (loop). Expected: green. Mutation: render zeros when denied → the AC3 case goes red.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.MonitorPort`, then `UiPerformanceWire`, `PreferencesWire` and `EndpointCoverage`, one at a time (loop). Expected: green. Mutations:
  - Drop the gate → the 403 cases go red.
  - Accept a partial parse → the missing-metric case goes red.
- Browser run (loop). Expected: green in both themes. Mutation: drop the route's `globalReferencesPerSecond` → AC1 goes red.

  ```bash
  cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/ && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/home-performance.browser-spec.mjs browser/home-system-information.browser-spec.mjs
  ```

- `cd ui && npm test` (once, before dev_complete). Expected: green, with the bundle under 1900 kB.
- Full ObjectScript sweep on `ocupilot-ci`, one class at a time (once, before dev_complete). Expected: green.

**Mutations (Rule 19), 2026-09-26, implement pass.** Each applied, red observed, reverted; the tree was byte-identical afterwards (a checksum over `git status --short`, `git diff`, `git diff --stat` and every untracked file matched before and after).

- mutation: append a point on a 403 in `core/performance.ts` `read` -> red: `performance.test.mjs` "a 403 clears the row" and "the line starts empty".
- mutation: keep points older than 600 s (drop the window filter in `read`) -> red: `performance.test.mjs` "points older than ten minutes are dropped".
- mutation: hold zeros instead of `null` on a 403 in `read` -> red: `home.page.spec.ts` both AC3 cases (no heading, no value, no zero).
- mutation: key Home's rate by its empty route (drop `HOME_REFRESH_NAME` in `ScreenStores.for`) -> red: `screen-store.test.mjs` AC5, "a remembered off is adopted", "a rate remembered after the store was made".
- mutation: drop the store subscription `RefreshService.bind` makes -> red: `refresh.test.mjs` "a remembered rate the account answers after the bind re-arms at it".
- mutation: empty Home's `context.fields` in the mirror -> red: `screen-context.test.mjs` both AC4 cases.
- mutation: drop the gate (`If 0`) in `MonitorPort.Performance`, recompiled with `MonitorPortFixture` on `ocupilot-ci` -> red: `OcuPilot.Test.MonitorPort` `TestTheGateRefusesBeforeAnySensorCall` and `OcuPilot.Test.UiPerformanceWire` `TestACallerLackingEitherPairIsRefusedNamingIt`.
- mutation: accept a partial parse (`Continue` past a missing or non-numeric metric in `MonitorPort.Parse`) -> red: `OcuPilot.Test.MonitorPort` `TestAMissingOrNonNumericMetricFailsTheWholeRead` and `TestALabeledLineIsIgnored`.
- mutation: drop `globalReferencesPerSecond` from `MonitorPort.METRICS`, recompiled on `ocupilot-ci` (the deployed bundle unchanged) -> red: `home-performance.browser-spec.mjs` AC1 (the row never renders; the route answered four members).

**Mutations (Rule 19), 2026-09-26, review pass.** Same discipline; tree checksum identical before and after.

- mutation: Home's bound read also calls `systemInfo.load()` -> red: `home.page.spec.ts` "AC2: the line is drawn only once two answers have arrived" (the panel re-read on the tick) and the 15.4 "no timer re-reads it" case.
- mutation: drop `this.performance.clearHistory()` from `HomePage`'s destroy -> red: `home.page.spec.ts` "AC2: leaving Home clears the line ... the next Home starts empty".
- mutation: `sparklinePath` draws from one point (`< 2` -> `< 1`) -> red: `performance.test.mjs` "draws nothing for fewer than two points", and both `home.page.spec.ts` AC2 cases.
- mutation: a successful `read` answers `rows: []` -> red: `home.page.spec.ts` AC4 (the context row).
- mutation: drop the `IsHomeRefresh` test from `Preferences.HandleUpdate`, recompiled on `ocupilot-ci` -> red: `home-performance.browser-spec.mjs` AC5 ("the instance remembers Home at 30 s under home"). `PreferencesWire` refuses on `ocupilot-ci` for its missing arming, so CI runs its leg.
- mutation: `reset()` keeps `deniedValue` -> red: `performance.test.mjs` "clearHistory drops the line and keeps the values; reset forgets both".

## Auto Run Result

Status: done
Blocking condition: none

**Change.** `MonitorPort` gates `%Admin_Operate:USE` and `%DB_IRISSYS:READ`, reads `SYS.Monitor.SAM.Sensors` once in `%SYS` and parses the five unlabeled metrics, all or nothing. `GET /ui/performance` serves them. Home joins AD-43's roster with a new `refreshDefault` key (Registry, mirror and store; Home alone at 10 s) and remembers its rate under `home`. `PerformanceRow` is the refresh read, the row and the ten-minute line, and its success row is Home's context row. `RefreshService` now re-arms when a remembered rate lands after bind, on every roster screen.

**Files.**

- Server, new: `Port/MonitorPort.cls`, `Kernel/Shell/Performance.cls`, `Api/UiPerformance.cls`.
- Server, changed: `Api/Router.cls` (route after `/ui/system`), `Screen/Descriptor/Home.cls`, `Screen/Descriptor/Base.cls` and `Screen/Registry.cls` (`refreshDefault`), `Kernel/State/Pref.cls` and `Api/Preferences.cls` (`home`), `Kernel/Shell/SystemInfo.cls` (comment).
- Client, new: `core/performance.ts`, `areas/home/performance-row.ts`, `testing/performance.ts`.
- Client, changed: `home.page.ts`, `refresh.ts`, `screen-store.ts`, `account-preferences.ts`, `main.ts`, `app.ts`, `screen-mirror.mjs`, `screens.generated.ts`, `strings.ts`, `_components.scss`.
- Docs: EXPERIENCE.md (:83 and :836 in place, row 576 appended; `taskCreate` citation 616 -> 617).
- Tests: new `Test/MonitorPort.cls`, `Test/MonitorPortFixture.cls`, `Test/UiPerformanceWire.cls`, `tools/performance.test.mjs`, `browser/home-performance.browser-spec.mjs`. Updated: `Descriptor`, `DeclarationCorpus`, `EndpointCoverage`, `PortGate`, `PreferencesWire`, `ScreenGrounding`, `SurfaceCoverage`, five `*.spec.ts`, `explain-screen.browser-spec.mjs`, three `tools/*.test.mjs`. `scripts/ci-throwaway.sh` arms `UiPerformanceWire`.

**Review.** 14 findings: 4 patched (1 medium, 3 low), 10 rejected (5 false, 5 low), none deferred (see the triage log). `followup_review_recommended: false`: one medium patched, no high.

**Verification.**

- Loop commands green: mirror check and seven tool files (211 tests), `home.page.spec.ts` (54), `MonitorPort`, `UiPerformanceWire` and `EndpointCoverage`, and the browser specs `home-performance`, `home-system-information` and `explain-screen` (9 tests).
- `PreferencesWire` refuses on `ocupilot-ci` for missing arming. Checked by curl instead: `home` rate 200, `home` favorite 422.
- `npm test`: 1,539 tool tests and 1,499 component tests green. Bundle 1.88 MB, under 1900 kB.
- Full ObjectScript sweep: 298 classes. 282 ran, 16 refused (arming), 1 known residue (`WireSecurityRead` task history).
- Lints clean: check-objectscript, lint-docs, client-lint.

**Residual risks.**

- About 30 browser specs outside this story land on Home, which now shows a chip, a stamp and the row. The full browser suite runs in CI (Rule 29).
- A denied caller still polls a 403 every 10 s (by design, see the triage log).
