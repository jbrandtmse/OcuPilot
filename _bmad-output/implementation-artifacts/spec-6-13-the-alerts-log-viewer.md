---
title: 'Story 6.13: The alerts.log viewer'
type: 'feature'
created: '2026-09-18'
status: 'ready-for-dev'
baseline_revision: '71d904743f486ab973cdb0a544cd7b2899b59438'
baseline_commit: '71d904743f486ab973cdb0a544cd7b2899b59438'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The Logs area's side bar has no alerts.log entry, `MonitorPort` — one of the five ports the spine names (`ARCHITECTURE-SPINE.md:46`) — does not exist, and the instance's alerts are reachable only through the classic console-log page. Nothing in `src/` or `ui/src/` references `alerts.log`, `SAM.Sensors` or `/api/monitor`.

**Approach:** Build `MonitorPort` on the `MgmntPort` pattern, add `monitor` as a fourth `read.source.port`, add `alerts` to `LogSourcePort`'s fixed source enum behind the paging endpoint Epic 2 built, declare one `log-viewer` descriptor, and build the shared log viewer that Story 6.14 will declare rather than rebuild.

## Boundaries & Constraints

**Always:**

- `MonitorPort` is the only class naming `SYS.Monitor.SAM.Sensors` or `%SYSTEM.Monitor`. It evaluates its declared `PAIRS` with `$System.Security.Check` **before** it reads an argument or calls vendor code (AD-29), switches to `%SYS` by explicit save/restore (AD-16) because the class does not exist in `HSCUSTOM` (probed), runs the vendor method behind fresh `%request`/`%response` stubs with device output captured, and reads its outcome from both the return value and `%response.Status` (AD-2's discipline, `MgmntPort.cls:1-23`).
- **Tag mode only.** Every call sets `%request.Data("tag",1)`. The no-tag path writes the instance-wide cursor `^IRIS.Temp.SAM("LastAlertSent")` in `%SYS`, which would consume another scraper's alerts — a read-triggered vendor write AD-7 permits in exactly two named cases, neither of them this one. Tag mode leaves that global byte-identical (probed).
- Every refusal is a written reason with a slug, a stable `MONITOR.*` code and a sentence chosen at the port; vendor text and captured device output go to `Kernel.Fault.LogRaw` and nowhere else (AD-12, AD-39).
- The bounded tail travels on the Epic-2 contract unchanged: one new route, one new key in `LogSourcePort`'s enum, `LogPage.Handle` untouched. The source key is bound by the route; no caller names a file (AD-21).
- Nothing streams. The descriptor declares `refreshes: false` / `refreshRates: []`, joins no AD-43 roster, registers no timer, opens no `EventSource` or `WebSocket`, and adds rows only on an explicit **Load newer**.
- Every rendered severity carries its word; color never alone (`EXPERIENCE.md:658`, `DESIGN.md:1084`). **The vendor's scale has five words, not the four `EXPERIENCE.md:409` lists:** `irissys/%sySystem.inc:158-163` declares `-2` and `-1` debug, `0` informational, `1` warning, `2` severe, `3` fatal. The chips render **Debug · Info · Warning · Severe · Fatal**, mapped to `DESIGN.md:1084`'s pairs — debug on the restrained pair, severe and fatal both on the inverted `{colors.on-error}` on `{colors.error}`. The artifact is not amended for this; the strings row carries the fifth word so the lead's amendment does.
- **Widening `read.source.port` needs no spine amendment.** AD-36 enumerates two source *kinds* — an instance endpoint reached through a port, or OcuPilot's own protected state — not port names, and `MonitorPort` is already one of the five ports `ARCHITECTURE-SPINE.md:46` declares. The `admin|state|mgmnt` list lives only in `Screen/Read.cls`'s parameters, `Registry.cls:832`'s arm and its mirrored refusal sentence, so adding `monitor` is ordinary in-footprint work. Do not stall on a Rule 20 amendment that is not due.
- `Screen/Read.cls`, `Screen/Registry.cls`, `Descriptor/Base.cls`, `AdminPort.cls`, `Installer.cls`, `Smoke.cls`, `Router.cls`, `Error.cls`, `Test/Descriptor.cls`, `screen-mirror.mjs`, `screen-store.ts` and `strings.ts` are shared with Epic 4: **additive only**.
- `ui/src/app/core/screens.generated.ts` is regenerated with `node tools/screen-mirror.mjs` from `ui/`, never hand-merged.

**Never:**

- Never `src/OcuPilot/Kernel/**`, `Port/ProviderPort.cls`, `Screen/Tool/**`, `scripts/check-objectscript.py` or its harness, `ui/src/app/app.ts`, `app.spec.ts`, `ui/src/app/shell/panel/**`, `ui/package.json`, `package-lock.json`, `angular.json`, `README.md`.
- Never an HTTP call to `/api/monitor` — the port calls the vendor in process (AD-1).
- Never a caller-supplied path, filename or namespace on any route this story adds (AD-21).
- Never a row action, a primary action or a link out of a `log-viewer` (AD-44; `Archetype.cls:67` classifies it `list` for link-out).
- Never `Kernel/EntityType.cls` or `Screen/Archetype.cls`: `log-entry` and `log-viewer` are already in both vocabularies.
- Never a severity chip rendered from a number OcuPilot invented — the scale is the vendor's (`irissys/%sySystem.inc:158-163`).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Gate refused | caller holds neither declared pair | `MonitorPort` answers 403 `AUTHNOPRIVILEGE` with `detail.failedPair`, **before** any vendor call and before any argument is read | no vendor code runs; nothing is logged as a fault |
| First load | screen opens | tail page from `/logs/alerts` (window = file tail), then `MonitorPort` with the tag taken from the tail's earliest header line; merged, ordered, de-duplicated | either half faulting keeps the other's rows |
| Load newer | user presses Load newer | tail page from the held `offset`+`identity`, then `MonitorPort` with the newest rendered row's tag | a restart (`restarted` true) re-seeds from byte 1 and is an outcome, never a fault |
| Duplicate entry | the same line reaches both halves | one row, the file's — it carries pid and category and an unmangled stamp | — |
| Monitor-only entry | a line written between the two calls | rendered with the pid cell reading its declared `emptyKey` | — |
| Monitor half faults | vendor throws, or its answer exceeds `MAXANSWERCHARS` | tail rows stay on screen; the polite line "Recent entries are unavailable — showing the file tail." | `MONITOR.TOOLARGE` / `MONITOR.FAILED`; `<MAXSTRING>` is caught and mapped, never propagated |
| Unmatched tag | the tail's earliest prefix is not a line the vendor recognises | the vendor answers the whole file; the port's size bound refuses it rather than truncating | `MONITOR.TOOLARGE` |
| No header line in the tail window | the window opens mid-continuation-line | no monitor call is made; the tail renders alone | — |
| Nothing new | tag is the file's last line | vendor answers `[]`; merged list is the tail alone | — |
| Empty file / no matches | alerts.log absent or zero rows / search matches nothing | "No entries." / "No matches." | a missing file is not a fault |
| Severity outside the scale | a line carries a severity the vendor scale does not name | the chip shows the number itself on the restrained pair | never color alone, never silently dropped |
| Rotation mid-paging | `identity` no longer matches | `Page` restarts cleanly at byte 1 (`LogSourcePort.cls:486-497`) | the held tag is discarded with it |

</intent-contract>

## Code Map

**Read for the shape, change nothing:**

- `src/OcuPilot/Port/MgmntPort.cls:1-60` — the port template: `PAIRS`, `GATECLASS`, gate-first ordering, stubbed `%request`/`%response`, outcome from two places, per-method written reasons, fixture seams. `MonitorPort` copies this and adds the `%SYS` save/restore `MgmntPort` deliberately does not need.
- `src/OcuPilot/Port/LogSourcePort.cls:37-47` (enum + its "no caller names a file" contract), `:50-66` (`MESSAGESKEY` / `MESSAGESFILE` / `MESSAGESPAIRS = "%Admin_Operate:USE"` and the reason a file read consults no database resource), `:203-229` (`Sources`, `PairsFor`), `:339-350` (`FileFor`, `ManagerDirectory`), `:419-513` (`Page`: step order, cursor pair, refuse-never-clamp `maxBytes`, two restart conditions, the seven result keys).
- `src/OcuPilot/Api/LogPage.cls:5-8`, `:13-24`, `:29-50` — the route binds the source key; `Handle` needs no change for a second key.
- `src/OcuPilot/Screen/Read.cls:27-30` (the three source kinds), `:122-143` (`PortClass`, `SOURCEADMIN`/`SOURCESTATE`/`SOURCEMGMNT`, `MgmntPortClass`), `:259` (the `mgmnt` Execute branch and its extra out-param) — the exact precedent a `monitor` branch follows.
- `src/OcuPilot/Screen/Registry.cls:829-833` (the source-port arm and its sentence), `:1025-1032` (`paging` must be `cap`), `:1040` (a read always declares a `table`), `:1049-1059` (`%DB_IRISSYS:READ` required on `admin`), `:1152-1154` (criteria travel on admin and mgmnt).
- `ui/tools/screen-mirror.mjs:362`, `:516` — the mirrored source-port refusal; the two engines refuse with the same sentence.
- `src/OcuPilot/Screen/Descriptor/LogErrorList.cls:71-97` — the Logs-area descriptor shape; `AuditList.cls:110-171` — the full read+table shape.
- `src/OcuPilot/Screen/Descriptor/SystemUsage.cls:50` — `"id": {"kind": "none", "parts": []}`, the form a screen with no detail route takes.
- `irissys/%SYSTEM/Monitor.cls:56-79` (`GetAlerts`; `:60` is `s file=$zu(12)_"alerts.log"`), `irissys/%Api/Monitor.cls:9-16`, `:32-42`, `irissys/%sySystem.inc:158-163` (the severity scale), `irissys/%CSP/UI/System/ViewTextFilePane.cls:19`, `:56-57` (the classic page shows alerts.log first). **Read-only reference exports: never edit, load or compile these.**

**Probed on `ocupilot-slot-b`, 2026-09-18:** `SYS.Monitor.SAM.Sensors` does not exist in `HSCUSTOM` and is source-stripped in `%SYS`; `/api/monitor` is `authEnabled: 64` (`$$$AutheUnauthenticated`) with an empty resource and answers `200` to an anonymous `curl`; `SAM.Sensors.Alerts()` raises `<UNDEFINED> *%request` with no stub and `<UNDEFINED> ... %response` in tag mode without a response stub; it returns a scalar `%String`, not the `%Stream.Object` its signature declares; a bogus tag returns the whole file; `/csp/sys/op` carries `resource: "%Admin_Operate"`; `%SYS_Portal.Resources` is empty, so no custom page resource applies (AD-44).

## Tasks & Acceptance

**Execution:**

1. **Fixed strings rows, applied by the lead before this spec was dispatched.** `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md:367` and `:368` carry both rows verbatim, after the Devices row. Implement edits no planning artifact; it reads those rows as the authority for the 15 new strings, and `strings.test.mjs` re-derives its authorized set from them.
2. `src/OcuPilot/Port/MonitorPort.cls` — new. `PAIRS = "%Admin_Operate:USE,%DB_IRISSYS:READ"`, `GATECLASS`, `SENSORCLASS = "SYS.Monitor.SAM.Sensors"`, `ENDPOINTALERTS = "Alerts"`, `REQUESTTYPE = "LIST"`, `TAGKEY = "tag"`, `TAGHEADER = "ISC-SAM-LAST-ALERT-TAG"`, `MAXANSWERCHARS`, `MAXENTRIES`. One entry point `Invoke(pEndpoint, pType, ByRef pQuery, pBody, Output pAnswer, Output pHttpStatus, Output pFault, Output pTag)` mirroring `MgmntPort.Invoke` plus the tag out-param. Seams `GateClass`, `SensorClass`, `LogFault` overridable for a fixture; production overrides none.
3. `src/OcuPilot/Port/LogSourcePort.cls` — additive: `ALERTSKEY = "alerts"`, `ALERTSFILE = "alerts.log"`, `ALERTSPAIRS = "%Admin_Operate:USE"`, appended to `SOURCES`, `PairsFor` and `FileFor`. `Page` is unchanged.
4. `src/OcuPilot/Api/Router.cls` — additive: `/logs/alerts` (GET) → a thin `Call=` wrapper on `LogPage.Handle("alerts")`, and `/logs/alerts/recent` (GET) → a new `Api/MonitorLog.cls` handler over `MonitorPort`. Both placed under the REST route-ordering convention and covered by `check-objectscript.py`'s structural `UrlMap` rules.
5. `src/OcuPilot/Api/MonitorLog.cls` — new, `LogPage.cls`'s shape: `PORTCLASS` seam, reads only `tag` off `%request`, answers through `Response.JSON` or `Error.Render`.
6. `src/OcuPilot/Screen/Read.cls` + `Screen/Registry.cls` + `ui/tools/screen-mirror.mjs` — additive: `SOURCEMONITOR = "monitor"`, `MonitorPortClass()`, an Execute branch, the validator arm and its mirrored sentence, and the `%DB_IRISSYS:READ` requirement extended to `monitor` (the port sets `$NAMESPACE` to `%SYS`, so database READ is routine-execution permission, AD-9). Corpus cases in `Test/ReadSourceCorpus.cls` and the mirror's own corpus, one per refusal.
7. `src/OcuPilot/Screen/Descriptor/LogAlertViewer.cls` — new. Route `logs/alerts`, area `logs`, `labelKey "alertLogListLabel"`, `sideBarPosition 1`, `archetype "log-viewer"`, `built true`, `refreshes false`, `refreshRates []`, privileges `%Admin_Operate:USE` + `%DB_IRISSYS:READ`, `entityType "log-entry"`, scope `instance`, `id {"kind":"none","parts":[]}`, no actions, `read.source {"port":"monitor","endpoint":"Alerts","type":"LIST"}`, `read.fields ["time","severity","text"]`, `paging "cap"`, `table` of three columns, `emptyStateKey`, `commandAliases ["alerts","alerts.log"]`, `classicPage "%cspapp.op.utilsysconsolelog"`, no exemption, `toolIdentifier "logs.alerts"`.
8. `ui/src/app/areas/logs/log-viewer.page.ts` + `log-viewer.store.ts` + `log-line.ts` (the parser) — new, and `ui/src/app/shell/screen-outlet.ts`'s `ARCHETYPE_PAGES` gains `'log-viewer'` (`BuiltArchetypeKey` gains the key on regeneration and the build fails until the map does). The parser, the severity chips, the sticky search with highlight and polite "n of N", next/previous, jump to top and bottom, Load newer, the Raw toggle and the severity-chip-click filter with Clear all live here, shared with 6.14. Styles in `ui/src/styles/`, tokens only.
9. `src/OcuPilot/Screen/Tool/ErrorRead.cls:4-6` carries a claim this story falsifies — "the declared-read pipeline is admin-port-only by two independent hard-codings". It has been wrong since Story 6.1 added `mgmnt`. **`Screen/Tool/**` is outside this story's footprint**, so the correction is not made here: it is reported to the lead as a footprint item at hand-back, not worked around.
10. **The roster tripwires.** `src/OcuPilot/Test/Navigation.cls` pins only os-management by index; its logs block (`:228-229`, `:257-258`, `:267`) pins the area's declared pairs, which this screen's subset does not widen — read it and confirm rather than assume. `Install/Smoke.cls:625` (loop bound 26), `:626` (the name list) and `:630` (the indexed `$Select`) move together. `Test/Smoke.cls:588` (roster), `:599`/`:600`/`:602` (the count, three times), `:601` (`tExpected`), `:640` (the 1000-char window comment recording 272 characters after 6.12) and `:693` (a fourth roster that Story 6.12 left stale — `"devices"` is missing from it) all need attention. `Test/ReadTool.cls:94`, `:100` and `Test/Wire.cls:397-398` carry logs entries.
11. **Client tripwires.** `ui/tools/navigation.test.mjs:126-160` (a new entry inserts before `'logs/errors'` at `:129`; the prose message at `:161` is rewritten), `ui/tools/navigation-wire.test.mjs:51-76` and `ui/src/app/shell/rail-wire.spec.ts:47-72` (the two `LIVE_PAYLOAD` copies; neither reddens alone), `ui/browser/screen-height.browser-spec.mjs:36-57` (a `log-viewer` entry and its viewport comment), `ui/src/app/core/screens.generated.ts` regenerated.
12. Tests: `Test/MonitorPort.cls`, `Test/MonitorPortDenial.cls`, `Test/MonitorPortFixture.cls`, `Test/LogSource.cls` (the `alerts` key), `Test/Descriptor.cls` (additive), `Test/ScreenRead.cls`, `Test/ReadTool.cls`; client `ui/src/app/areas/logs/log-viewer.spec.ts`, `log-line.spec.ts`, and `ui/browser/alerts-log.browser-spec.mjs`.

**Acceptance Criteria:**

- **AC1 (gate before the call).** Given a principal holding neither `%Admin_Operate:USE` nor `%DB_IRISSYS:READ`, when it invokes `MonitorPort`, then the answer is 403 `AUTHNOPRIVILEGE` naming the first unheld pair, and a fixture counting vendor entries records **zero** — the refusal precedes argument reading and vendor code alike. Pinned by `Test/MonitorPortDenial.cls`.
- **AC2 (tag mode only).** Given any `MonitorPort` call, when it completes, then `%request.Data("tag",1)` was set and `^IRIS.Temp.SAM("LastAlertSent")` in `%SYS` is byte-identical before and after. Pinned by `Test/MonitorPort.cls`.
- **AC3 (the envelope).** Given the vendor throws, or answers more than `MAXANSWERCHARS`, when the port returns, then the caller gets one AD-12 envelope with a `MONITOR.*` code and a written reason, the vendor's raw text reaches `Fault.LogRaw` only, and no exception escapes. Pinned by `Test/MonitorPort.cls`.
- **AC4 (the merge).** Given both halves answer and share a line, when the screen renders, then that line appears **once**, as the file's row (pid and category present, the stamp in the file's own local grammar, never the API's falsely `Z`-suffixed one); rows are ordered by normalized stamp with file order breaking ties; a monitor-only line renders with the pid cell reading its `emptyKey`; and no line the union of the two windows contains is missing. Pinned by `log-viewer.spec.ts`.
- **AC5 (bounded paging, both ends).** Given the tail, when the user reaches the newest end and presses Load newer, then a page is requested from the held `offset`+`identity` and a rotation answers `restarted` true and re-seeds from byte 1 without a fault; when the user reaches the oldest end, then no further page is requested and the control is not offered. Pinned by `Test/LogSource.cls` and `log-viewer.spec.ts`.
- **AC6 (nothing streams).** Given the screen is open and untouched, when fake timers advance ten minutes, then the store issues **zero** additional requests, registers no interval and opens no `EventSource` or `WebSocket`; new rows arrive only on an explicit Load newer. Pinned by `log-viewer.spec.ts`.
- **AC7 (the viewer).** Given a rendered tail, when the user searches, then matches highlight, a polite `role="status"` announces "n of N", next/previous move the caret, jump to top and bottom move the viewport, the Raw toggle swaps to the bounded monospace block with a line-number gutter and no wrapping, and clicking a severity chip sets that severity as the filter with Clear in the command bar. Pinned by `log-viewer.spec.ts` and `alerts-log.browser-spec.mjs`.
- **AC8 (row geometry, UX-DR80's half).** Given a real alerts.log tail on a throwaway carrying one entry at each level of the vendor's severity scale and the file's longest line, when the browser measures every rendered log row, then each is exactly 28 px — a fixed height, not a minimum (`DESIGN.md:912`). Pinned by `alerts-log.browser-spec.mjs`.
- **AC9 (least-privileged principal).** Given a purpose-built role holding exactly the declared pairs — never `%Operator` — when the read, the tail route and the recent route are exercised on a throwaway, then each answers rows; and when a pair is removed, then each names that pair. Whatever the instance still refuses is appended to the declared set. Pinned by `Test/MonitorPortDenial.cls` and `Test/LogSourceDenial.cls`.
- **AC10 (integration, Rule 1).** Given the screen's derived read tool `logs.alerts.read`, when it is invoked against the live instance, then it answers the same bounded rows the screen's declared read answers, narrowed by the context cap and with no secret field — and the bounded tail is **not** in its view. Pinned by `Test/ReadTool.cls` and `Test/ScreenRead.cls`.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs (Rule 6):** AD-1, AD-2 (the sequence `MonitorPort` imitates), AD-5, AD-7 (why no-tag mode is refused), AD-8, AD-12, AD-16, AD-21, AD-24, AD-29 (the port's own gate), AD-35, AD-36 (the fourth source kind), AD-39, AD-43 (the roster this screen does not join), AD-44.

**`MonitorPort`'s shape and gate, with evidence.** `%Api.Monitor`'s `/alerts` route (`irissys/%Api/Monitor.cls:9-16`) is a two-line pass-through to `SYS.Monitor.SAM.Sensors.Alerts()` (`:32-42`) with no gate of any kind, on a web application configured `authEnabled: 64` and answering `200` to an anonymous request — so the port's own `$System.Security.Check` is the only gate there is. The sensor class is `[ Hidden ]`, source-stripped and absent from `HSCUSTOM`, so the port switches to `%SYS` and declares `%DB_IRISSYS:READ` alongside `%Admin_Operate:USE`; `%Admin_Operate` is the resource the classic page that shows alerts.log carries (`/csp/sys/op`), and `%SYS_Portal.Resources` holds no custom assignment. `Alerts()` hard-requires `%request` at its second line and `%response` in tag mode, which is why the stubs are not optional. Both pairs are a **lower bound** until AC9's least-privileged run says otherwise.

**The merge rule, and what it really is.** `%SYSTEM.Monitor.GetAlerts` reads `$zu(12)_"alerts.log"` (`irissys/%SYSTEM/Monitor.cls:60`) — the same file the bounded tail reads. The merge is therefore one file read two ways, and the API's reading is strictly lossier: it drops the pid and the bracketed category, quotes the severity, and rewrites a local-time stamp with a `Z` suffix nothing converted. So **the file wins on every collision**, the de-duplication key is `(normalized stamp, severity, text)` — not pid, which one side does not have — and ordering is by normalized stamp with file order breaking ties. Two identical file lines from different pids are never de-duplicated against each other; only a monitor row against a file row. What the API uniquely supplies is the cursor: "what is new since the tag I hold", without OcuPilot re-reading the file. The tag is taken from the tail window's earliest **header** line, so the two windows coincide and no gap is possible; a window with no header line makes no monitor call at all.

**The viewer's contract for Story 6.14.** 6.14 declares, and does not rebuild: the `log-viewer` page and store, `log-line.ts`'s parser (one grammar serves both files — `messages.log` head lines match the same regex, and the parser tolerates continuation lines, of which `messages.log` on slot B has 139 against `alerts.log`'s 0), the severity chips and their five words, the sticky search with highlight and polite count, next/previous, jump to top and bottom, Load newer, the Raw toggle, the severity-chip filter with Clear, the `ARCHETYPE_PAGES` entry, the styles, and the `alerts`-shaped `LogSourcePort` key. 6.14 adds its own descriptor at `sideBarPosition 2`, the `messages` source is already in the enum and its route already exists, and it re-confirms the 28 px row against messages.log's own severity mix. **Its read tool has no descriptor-derived path — DW-1100.**

**Ledger inbox dispositions.**

- **DW-148** — declined here, stays 6.14. Its own residual names the fault banner's "Open messages.log" link, which is `EXPERIENCE.md:502`'s generic internal-error banner and reaches the messages.log screen 6.14 builds. This story builds no screen that link targets, and there is no published "Open alerts.log" string.
- **DW-278** — **decided here**, because 6.13 is the first Logs viewer to ship and the decision was routed to whichever that is. This screen declares `%Admin_Operate:USE` and `%DB_IRISSYS:READ` and **does not** declare `%Admin_Secure:USE`; the pair set is a subset of the Logs area's union (`Screen/Area.cls:117`), so `Area.cls` is untouched and the area's accepted false denial stands exactly as the owner settled it on 2026-09-14. 6.14 inherits the decision rather than re-taking it.
- **DW-1025** — **investigated here, fixed in 6.14.** The entry's question is answered and its evidence is on the entry as a trailer: the `<PROTECT>` is OcuPilot's, not the vendor's. The fix belongs to 6.14 because it is a guard inserted into `AdminPort.ForgetTask`'s existing body — a modification of a file Epic 4 shares under additive-only discipline — and 6.14 already owns the entry. This story neither touches `AdminPort.cls` nor pins the fix; it renders the lines the defect produces, which is why the evidence was gathered now.

**Pair sets.** Screen: `%Admin_Operate:USE`, `%DB_IRISSYS:READ`. `MonitorPort.PAIRS`: the same. `LogSourcePort.ALERTSPAIRS`: `%Admin_Operate:USE` alone, because reading a file off disk consults no database resource (`LogSourcePort.cls:57-65`). The screen's gate is the wider of the two; AC9 is what establishes both rather than copying them.

**AD-35 becomes load-bearing for alerts.log.** OcuPilot's own structured logger writes `[OcuPilot.Log]` lines into alerts.log — 18 of the 34 lines on slot B — so this screen is the first to render OcuPilot's own log output back to a user and to an agent. AD-35's rule that no credential may enter a log line now governs alerts.log as it already governs messages.log and the error log.

**Consumes (Rule 2):** `LogSourcePort.Page` (Epic 2), `LogPage.Handle` (Epic 2), `Screen/Read` + `Registry` (Epic 2), `ListPage`'s command bar and its filter and View slots (Epic 2, Story 6.11), `Screen.Gate`, `Kernel.Fault.LogRaw`, `Api.Response`/`Api.Error`. **Consumed-by (Rules 1, 2):** Story 6.14 (the whole viewer, the parser, the chips, the controls, the styles), Story 11.2 (explains a row through `logs.alerts.read`), Story 1.12's Home suggested view (the "new alerts.log entries" attention line, `EXPERIENCE.md:525`, which `epics.md:3044` says joins when this read lands). AC10 is the Integration AC and is exercised against a real instance, never a mock.

## Verification

**Commands:**

- `cd ui && npm run build` — expected: the six `prebuild` checkers pass, including `screen-mirror.mjs --check` against the regenerated mirror and `classic-links.mjs` reporting one honored exemption (unchanged).
- `cd ui && npm test` — expected: `node --test tools/*.test.mjs` and the Angular component runner green, including the two `LIVE_PAYLOAD` copies and `strings.test.mjs` at 481 keys.
- `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci npm run test:browser` — expected: `alerts-log.browser-spec.mjs` and `screen-height.browser-spec.mjs` green. Rebuild and `docker cp` the bundle first; a browser spec reads the deployed bundle.
- `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh` — expected: clean.
- `node tools/ci-runner.mjs` on a throwaway brought up **after the last edit** (`sh scripts/ci-throwaway.sh up --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci --web 52777 --super 1976`) — expected: the whole ObjectScript sweep green, not a chosen subset. One `iris_execute_tests` call at a time; never re-submit after a timeout.
- `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` — expected: non-zero executed checks, all passing, including the new area-list check.

**Mutations (Rule 19) — one per AC:**

- AC1 — `mutation:` move the `PAIRS` evaluation in `MonitorPort.Invoke` to after the vendor call → `Test/MonitorPortDenial.cls` vendor-entry count goes to 1 and the test reddens.
- AC2 — `mutation:` drop the `%request.Data("tag",1)` seed → `Test/MonitorPort.cls`'s cursor-unchanged assertion reddens.
- AC3 — `mutation:` remove the `Try`/`Catch` around the vendor call → `Test/MonitorPort.cls`'s envelope assertion reddens on the thrown case.
- AC4 — `mutation:` make the de-duplication keep the monitor row instead of the file's → `log-viewer.spec.ts`'s pid-present assertion reddens.
- AC5 — `mutation:` send the tail request without `identity` → `Test/LogSource.cls`'s restart assertion reddens.
- AC6 — `mutation:` add a `setInterval` re-read to `log-viewer.store.ts` → `log-viewer.spec.ts`'s zero-requests-after-ten-minutes assertion reddens.
- AC7 — `mutation:` drop the severity word from the chip, leaving color alone → `log-viewer.spec.ts`'s chip-text assertion reddens.
- AC8 — `mutation:` change `log-row-height` to 32px in the stylesheet, rebuild and redeploy → `alerts-log.browser-spec.mjs`'s height assertion reddens.
- AC9 — `mutation:` remove `%DB_IRISSYS:READ` from `MonitorPort.PAIRS` → `Test/MonitorPortDenial.cls`'s named-pair assertion reddens.
- AC10 — `mutation:` add the tail rows to the tool's answer → `Test/ReadTool.cls`'s field-set assertion reddens.

Each mutation is applied, observed red, reverted, and the tree confirmed byte-identical (`git status --short` and `git diff --stat` unchanged). A mutation to ObjectScript is believed only after the whole package is recompiled on a throwaway whose source copy was refreshed first.

**Manual checks:**

- `iris_server_profiles` reports `ocupilot-slot-b` on 52775 before any MCP call in this story.
- The classic page `%cspapp.op.utilsysconsolelog` is confirmed to exist on the throwaway before the descriptor's `classicPage` is trusted.
