---
title: 'Story 6.13: The alerts.log viewer'
type: 'feature'
created: '2026-09-18'
status: 'done'
baseline_revision: '71d904743f486ab973cdb0a544cd7b2899b59438'
baseline_commit: '71d904743f486ab973cdb0a544cd7b2899b59438'
review_loop_iteration: 2
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The Logs area's side bar has no alerts.log entry, and the instance's alerts are reachable only through the classic console-log page. Nothing in `src/` or `ui/src/` reads `alerts.log`.

**Approach:** Add `alerts` to `LogSourcePort`'s fixed source enum behind the paging endpoint Epic 2 built, give that port a second entry point that projects the same window into declared-read rows, add `logsource` as a fourth `read.source.port`, declare one `log-viewer` descriptor, and build the shared log viewer that Story 6.14 will declare rather than rebuild.

**One file, one reader.** The monitoring API reads the same file (`irissys/%SYSTEM/Monitor.cls:60`) and reads it lossily, and every call advances the instance-wide SAM cursor whatever tag is passed, so `MonitorPort` is not shipped by this story (DW-1116; `epics.md` 6.13 AC1 and AC2 amended 2026-09-18).

## Boundaries & Constraints

**Always:**

- The screen has exactly one reader, `OcuPilot.Port.LogSourcePort`. `Page` serves the bounded byte window the screen pages by; `Rows` projects the same window into `{time, severity, text}` rows, newest first, which is what the declared read and its derived tool answer. No class names `SYS.Monitor.SAM.Sensors`, `%SYSTEM.Monitor` or `/api/monitor`, and nothing this story ships writes `^IRIS.Temp.SAM`.
- The source key is bound by the route and by the descriptor's `read.source.endpoint`; no caller names a file (AD-21). `Page` is unchanged: one new key in the enum, one new route, `LogPage.Handle` untouched.
- The gate is the port's own (AD-29) and precedes every filesystem touch. `ALERTSPAIRS` is `%Admin_Operate:USE` alone -- reading a file off disk consults no database resource and this path never enters `%SYS` -- and the screen declares exactly that one pair, so both ways in meet the same gate.
- **A log the instance has not written yet is an empty read, not a failed one.** `Page` answers 404 `LOG.ABSENT` for an absent file, because a caller paging by byte offset asked for a file; `Rows` and the viewer read that code as zero entries. Every other refusal, the gate's included, passes through.
- Every refusal is a written reason with a slug and a stable code from `OcuPilot.Api.Error` (AD-12, AD-39); raw status text goes to `Kernel.Fault.LogRaw` and nowhere else.
- Nothing streams. The descriptor declares `refreshes: false` / `refreshRates: []`, joins no AD-43 roster, registers no timer, opens no `EventSource` or `WebSocket`, and adds rows only on an explicit **Load newer**.
- Every rendered severity carries its word; color never alone (`EXPERIENCE.md:658`, `DESIGN.md:1084`). **The vendor's scale has five words, not the four `EXPERIENCE.md:409` lists:** `irissys/%sySystem.inc:158-163` declares `-2` and `-1` debug, `0` informational, `1` warning, `2` severe, `3` fatal. The chips render **Debug · Info · Warning · Severe · Fatal**.
- **One head grammar, two implementations.** `LogSourcePort.HEADFORM` and `ui/src/app/areas/logs/log-line.ts`'s `HEAD_RE` are the same grammar: both files are written by the same `$zu(9)` path, so one grammar serves `alerts.log` and `messages.log`, and a line that does not match it is a continuation of the entry above.
- **Widening `read.source.port` needs no spine amendment.** AD-36 enumerates two source *kinds* -- an instance endpoint reached through a port, or OcuPilot's own protected state -- not port names. The `admin|state|mgmnt` list lives only in `Screen/Read.cls`'s parameters, `Registry.cls`'s arm and its mirrored refusal sentence, so adding `logsource` is ordinary in-footprint work.
- `Screen/Read.cls`, `Screen/Registry.cls`, `Descriptor/Base.cls`, `AdminPort.cls`, `Installer.cls`, `Smoke.cls`, `Router.cls`, `Error.cls`, `Test/Descriptor.cls`, `screen-mirror.mjs`, `screen-store.ts` and `strings.ts` are shared with Epic 4: **additive only**.
- `ui/src/app/core/screens.generated.ts` is regenerated with `node tools/screen-mirror.mjs` from `ui/`, never hand-merged.

**Never:**

- Never `src/OcuPilot/Kernel/**`, `Port/ProviderPort.cls`, `Screen/Tool/**` (beyond DW-1111's one-comment correction), `scripts/check-objectscript.py` or its harness, `ui/src/app/app.ts`, `app.spec.ts`, `ui/src/app/shell/panel/**`, `ui/package.json`, `package-lock.json`, `angular.json`, `README.md`.
- Never the monitoring API, in process or over HTTP (DW-1116).
- Never a caller-supplied path, filename or namespace on any route this story adds (AD-21).
- Never a row action, a primary action or a link out of a `log-viewer` (AD-44; `Archetype.cls:67` classifies it `list` for link-out).
- Never `Kernel/EntityType.cls` or `Screen/Archetype.cls`: `log-entry` and `log-viewer` are already in both vocabularies.
- Never a severity chip rendered from a number OcuPilot invented -- the scale is the vendor's (`irissys/%sySystem.inc:158-163`).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Gate refused | caller holds no `%Admin_Operate:USE` | 403 `AUTH.NOPRIVILEGE` with `detail.failedPair`, on the page route and on the declared read alike, **before** any filesystem touch | the fixture's touch counter reads zero |
| First load | screen opens | one tail page from `/logs/alerts` (window = the file's last bytes), parsed into rows oldest first | a fault here is the screen's own refusal |
| Load newer | user presses Load newer | one page from the held `offset`+`identity`; a rotation answers `restarted` true and re-seeds from byte 1 | a restart is an outcome, never a fault |
| Oldest end | the first window is the file's own tail | no control is offered and no page is requested for anything older | -- |
| Continuation line | a line does not match the head grammar | it is appended to the entry above it, newline-separated, in both engines | -- |
| Window opens mid-continuation | the first line is a fragment | one leading entry with no time and no severity, its bytes kept; the pid and severity cells read the table's empty word | -- |
| Declared read | the screen's read tool, or `GET /screens/logs.alerts/read` | at most the cap's rows, **newest first**, each carrying exactly `time`, `severity`, `text` | the port's page envelope reaches no caller |
| Absent file | the instance has raised no alert | the declared read answers zero rows with 200; the screen renders "No entries." | 404 `LOG.ABSENT` on the page route, read as empty rather than refused |
| Empty file / no matches | zero rows / search matches nothing | "No entries." / "No matches." | -- |
| Severity outside the scale | a line carries a severity the vendor scale does not name | the chip shows the number itself on the restrained pair | never color alone, never silently dropped |
| Rotation mid-paging | `identity` no longer matches | `Page` restarts cleanly at byte 1 (`LogSourcePort.cls`) | the rendered rows are replaced, not appended to |

</intent-contract>

## Code Map

**Read for the shape, change nothing:**

- `src/OcuPilot/Port/LogSourcePort.cls` -- the enum and its "no caller names a file" contract, `MESSAGESKEY`/`MESSAGESFILE`/`MESSAGESPAIRS` and the reason a file read consults no database resource, `Sources` / `PairsFor` / `FileFor` / `ManagerDirectory`, and `Page`: step order, cursor pair, refuse-never-clamp `maxBytes`, two restart conditions, seven result keys.
- `src/OcuPilot/Api/LogPage.cls` -- the route binds the source key; `Handle` needs no change for a second key.
- `src/OcuPilot/Screen/Read.cls` -- the source kinds, `PortClass` / `SOURCEADMIN` / `SOURCESTATE` / `SOURCEMGMNT` / `MgmntPortClass`, and the `mgmnt` Execute branch, which is the precedent the `logsource` branch follows.
- `src/OcuPilot/Screen/Registry.cls` -- the source-port arm and its sentence, `paging` must be `cap`, a read always declares a `table`, the `%DB_IRISSYS:READ` rule (admin only), criteria travel on admin and mgmnt.
- `ui/tools/screen-mirror.mjs` -- the mirrored source-port refusals; the two engines refuse with the same sentence, and `Test/AdminPairCorpus.cls` is the one corpus both run.
- `src/OcuPilot/Screen/Descriptor/LogErrorList.cls` -- the Logs-area descriptor shape; `SystemUsage.cls` -- `"id": {"kind": "none", "parts": []}`, the form a screen with no detail route takes.
- `irissys/%sySystem.inc:158-163` (the severity scale), `irissys/%CSP/UI/System/ViewTextFilePane.cls:19`, `:56-57` (the classic page shows alerts.log first). **Read-only reference exports: never edit, load or compile these.**

**Changed by this story:**

- `src/OcuPilot/Port/LogSourcePort.cls` -- additive: `ALERTSKEY` / `ALERTSFILE` / `ALERTSPAIRS` appended to `SOURCES`, `PairsFor` and `FileFor`; `HEADFORM`; and the second entry point `Rows` with its private `Entries` and `HeadParts`. `Page` is unchanged.
- `src/OcuPilot/Api/Router.cls` -- additive: `/logs/alerts` (GET) as a thin `Call=` wrapper on `LogPage.Handle("alerts")`.
- `src/OcuPilot/Screen/Read.cls` + `Screen/Registry.cls` + `ui/tools/screen-mirror.mjs` -- additive: `SOURCELOGSOURCE = "logsource"`, `LogSourcePortClass()`, an Execute branch, the validator arm and its mirrored sentence, with a corpus case per refusal in `Test/AdminPairCorpus.cls`.
- `src/OcuPilot/Screen/Descriptor/LogAlertViewer.cls` -- new. Route `logs/alerts`, area `logs`, `sideBarPosition 1`, archetype `log-viewer`, one privilege pair, `id {"kind":"none","parts":[]}`, `read.source {"port":"logsource","endpoint":"alerts","type":"LIST"}`, `read.fields ["time","severity","text"]`, `paging "cap"`, `toolIdentifier "logs.alerts"`.
- `ui/src/app/areas/logs/log-viewer.page.ts` + `log-viewer.store.ts` + `log-line.ts` -- new, and `screen-outlet.ts`'s `ARCHETYPE_PAGES` gains `'log-viewer'`. The parser, the five severity chips, the sticky search with highlight and polite count, next/previous, jump to top and bottom, Load newer, the Raw toggle and the chip filter live here, shared with 6.14. Styles in `ui/src/styles/`, tokens only.
- `src/OcuPilot/Screen/Tool/ErrorRead.cls:4-6` -- **comment only** (DW-1111): the "admin-port-only by two independent hard-codings" claim has been false since Story 6.1 added `mgmnt` and is false twice over now. Corrected at its origin; nothing else in that contended file is touched.
- The roster tripwires: `Install/Smoke.cls` (loop bound, name list, indexed `$Select`, the zero-or-one list), `Test/Smoke.cls` (four rosters and the three counts), `Test/ReadTool.cls`, `Test/WireSecurityRead.cls`, `Test/Navigation.cls`'s logs block; and the client's `navigation.test.mjs`, `navigation-wire.test.mjs`, `rail-wire.spec.ts`, `screen-height.browser-spec.mjs` and the regenerated `screens.generated.ts`.

**Rule 14 -- the reusable lesson.** `log-line.ts` was authored with two **literal NUL bytes** inside its de-duplication key. Git classified the file binary, so every review layer's diff read only "Binary files ... differ" and grep skipped the file: the parser AC4 rests on was unreviewable until the bytes were written as escapes. Author every non-ASCII character in source as an escape sequence; a literal one is invisible in exactly the place a reviewer looks.

**Probed on `ocupilot-slot-b` and the throwaway `ocupilot-b-ci`, 2026-09-18:** a fresh throwaway has **no** `/durable/iris/mgr/alerts.log` at all until the instance raises an alert (measured: absent at bring-up, nine lines after the ObjectScript suite ran), which is why the absent file is an empty read rather than a refusal; `/csp/sys/op` carries `resource: "%Admin_Operate"`; `%SYS_Portal.Resources` is empty, so no custom page resource applies (AD-44).

## Tasks & Acceptance

**Execution:**

1. **Fixed strings rows, applied by the lead before this spec was dispatched.** `EXPERIENCE.md:367` and `:368` carry both rows verbatim. Implement edits no planning artifact; `strings.test.mjs` re-derives its authorized set from them. `alertLogRecentUnavailable` is authorized by `:368` and rendered by nothing this story ships -- DW-1117.
2. `src/OcuPilot/Port/LogSourcePort.cls` -- the `alerts` key, `HEADFORM`, and `Rows` / `Entries` / `HeadParts`.
3. `src/OcuPilot/Api/Router.cls` -- the `/logs/alerts` route.
4. `src/OcuPilot/Screen/Read.cls` + `Screen/Registry.cls` + `ui/tools/screen-mirror.mjs` -- the `logsource` source port, its two refusal sentences in both engines, and a corpus case per refusal.
5. `src/OcuPilot/Screen/Descriptor/LogAlertViewer.cls` -- the descriptor.
6. The client: the page, the store, the parser, the styles and the `ARCHETYPE_PAGES` entry.
7. The roster and client tripwires listed in the Code Map.
8. Tests: `Test/LogSource.cls` (the key, the parse, the order, the row keys), `Test/LogSourceDenial.cls` (AC9's least-privileged principal), `Test/Descriptor.cls`, `Test/ScreenRead.cls`, `Test/ReadTool.cls`; client `log-viewer.spec.ts`, `log-line.spec.ts`, `ui/browser/alerts-log.browser-spec.mjs`.

**Acceptance Criteria:**

- **AC1 (the file itself, and only the file).** Given the alerts.log screen, when it loads, then its rows come from `alerts.log` through `LogSourcePort` -- `alerts` is in the shipped enum, resolves to `alerts.log` under the manager directory, and declares `%Admin_Operate:USE` -- and no shipped class reaches the monitoring API or writes `^IRIS.Temp.SAM`. Pinned by `Test/LogSource.cls`.
- **AC2 (the gate precedes the file).** Given a caller holding none of the source's declared pairs, when it asks for a page, then the answer is 403 `AUTH.NOPRIVILEGE` naming the pair, and the fixture's filesystem-touch counter reads **zero**; the same caller holding that one pair is served and the counter moves. Pinned by `Test/LogSource.cls`.
- **AC3 (the declared read).** Given the `logsource` source port, when `Screen/Read.Execute` runs the descriptor's read against the live instance, then the answer's fields are exactly the declared ones, every declared field is a key of a live row, and the cap bounds them. Pinned by `Test/ScreenRead.cls`.
- **AC4 (the rows parse).** Given a window of log lines, when either engine parses it, then a head line yields time, pid, severity and text; a line that does not match the grammar folds into the entry above it; a window opening mid-continuation keeps its bytes as an entry with no time and no severity; a severity outside the vendor's scale renders as the number itself; and one carrying none renders the table's empty word. Pinned by `Test/LogSource.cls`, `log-line.spec.ts` and `log-viewer.spec.ts`.
- **AC5 (bounded paging, both ends).** Given the tail, when the user presses Load newer, then a page is requested from the held `offset`+`identity` and a rotation answers `restarted` true and re-seeds from byte 1 without a fault; when the user reaches the oldest end, then no further page is requested and the control is not offered. Pinned by `Test/LogSource.cls` and `log-viewer.spec.ts`.
- **AC6 (nothing streams).** Given the screen is open and untouched, when fake timers advance ten minutes, then the store issues **zero** additional requests, registers no interval and opens no `EventSource` or `WebSocket`; new rows arrive only on an explicit Load newer. Pinned by `log-viewer.spec.ts` and `alerts-log.browser-spec.mjs`.
- **AC7 (the viewer).** Given a rendered tail, when the user searches, then matches highlight, a polite `role="status"` announces "n of N", Enter and Shift+Enter move the caret, jump to top and bottom move the viewport, the Raw toggle swaps to the bounded monospace block with a line-number gutter and no wrapping, and clicking a severity chip sets that severity as the filter. Every chip carries its word. Pinned by `log-viewer.spec.ts` and `alerts-log.browser-spec.mjs`.
- **AC8 (row geometry, UX-DR80's half).** Given a real alerts.log tail on a throwaway carrying one entry at each level of the vendor's severity scale and the file's longest line, when the browser measures every rendered log row, then each is exactly 28 px -- a fixed height, not a minimum (`DESIGN.md:912`). Pinned by `alerts-log.browser-spec.mjs`.
- **AC9 (least-privileged principal).** Given a purpose-built role holding exactly `%Admin_Operate:USE` -- never `%Operator` -- when the page route and the declared read are exercised on a throwaway, then both carry past the gate; and for a principal holding `%Admin_Secure:USE` instead, both are refused 403 naming `%Admin_Operate:USE`. Pinned by `Test/LogSourceDenial.cls`.
- **AC10 (integration, Rule 1).** Given the screen's derived read tool `logs.alerts.read`, when it is invoked against the live instance, then it answers the same bounded rows the screen's declared read answers, narrowed by the context cap, each row carrying exactly `time`, `severity` and `text` -- and the port's page envelope (`lines`, `offset`, `identity`) is **not** in its view. Pinned by `Test/ReadTool.cls` and `Test/LogSource.cls`.

### Review Findings

Code review (Tier 1, `full`, 2026-09-18). Layers: `blind-hunter`, `edge-case-hunter`, `verification-gap`,
`acceptance-auditor`, all `full-opus`, all barred from executing tests; every execution-dependent probe was
run by the reviewer on `ocupilot-slot-b` (52775) and the throwaway `ocupilot-b-ci` (52777).

#### Patched in this pass

| # | Severity | Finding | Where | Evidence it is closed |
|---|---|---|---|---|
| 1 | high | `log-line.ts` carried two literal NUL bytes in `mergeKey`, so git classified the file binary and the review diff read "Binary files ... differ" — the parser AC4 rests on was unreviewable, and grep skipped the file (Rule 14) | `log-line.ts` | escape form; `file(1)` now reports ASCII text and the file diffs |
| 2 | med | Pinned the monitoring half; removed with it in the 2026-09-18 rework (DW-1116). | -- | -- |
| 3 | med | AC7's jump controls moved nothing in a real browser: `app-log-viewer-page` was missing from the height chain, so `.ocu-log-viewport` never overflowed and `scrollTo` was a no-op. The old spec branched on `scrollable` and passed | `_components.scss`, `alerts-log.browser-spec.mjs` | the host joins the chain; the spec asserts `scrollable` unconditionally and both jumps; observed red before, green after, on the throwaway |
| 4 | med | Pinned the monitoring half; removed with it in the 2026-09-18 rework (DW-1116). | -- | -- |
| 5 | med | Pinned the monitoring half; removed with it in the 2026-09-18 rework (DW-1116). | -- | -- |
| 6 | med | Pinned the monitoring half; removed with it in the 2026-09-18 rework (DW-1116). | -- | -- |
| 7 | med | Pinned the monitoring half; removed with it in the 2026-09-18 rework (DW-1116). | -- | -- |
| 8 | med | The I/O matrix's "search matches nothing → No matches." was unreachable — the search highlighted without standing the rows down | `log-viewer.page.ts` | `searchFoundNothing`; the existing empty-state test now reaches it from the search alone |
| 9 | med | The `logs/alerts` entry added to both `LIVE_PAYLOAD` copies was read by no assertion, so either copy could drift | `navigation-wire.test.mjs`, `rail-wire.spec.ts` | a `screenVerdict('logs/alerts')` assertion in each |
| 10 | low | An entry carrying no severity rendered an empty chip | `log-line.ts` | `severityWord('')` is the empty-cell word; pinned |
| 11 | low | The polite count could announce "5 of 2": `onChip` did not reset the caret as `onSearch` does | `log-viewer.page.ts` | caret reset; pinned |
| 12 | low | A `waitForFunction` whose predicate was `true` waited for nothing; the paging assertion rested on a fixed sleep | `alerts-log.browser-spec.mjs` | polls for the request, then a settling beat |
| 13 | low | The store's doc comment claimed a sign-out teardown that does not exist (corrected at its origin, DW-1110) | `log-viewer.store.ts` | the comment states what is true and names the entry |
| 14 | low | The page's doc comment presented the search input's native clear as "the command bar's" (DW-1109) | `log-viewer.page.ts` | the comment states what ships and names the entry |
| 15 | low | A re-flow dropped a conjunction in the roster comment | `Test/Smoke.cls` | restored |
| 16 | med | The browser spec re-seeded `alerts.log` on every run, so a second run against one throwaway doubled every seeded entry and the chip test's counts drifted with how often the suite had been run; and a count taken before the rows settled was one a later assertion could never match again — observed as a 30 s timeout on the second run | `alerts-log.browser-spec.mjs` | seeds only when the marker is absent; `settled()` waits for the row count to stop moving. Two consecutive runs on one throwaway: 87 seeded lines before and after, both green |
| 17 | med | AC8's and AC7's geometry rested on whatever the instance's own `alerts.log` happened to hold: on a fresh throwaway (nine rows) the viewport does not overflow and the jump controls have nowhere to go | `alerts-log.browser-spec.mjs` | the seed carries 80 further informational entries, so the window overflows whatever the browser's size; verified from a cleaned file |

#### Decided: the one HIGH this review paused on

**DW-1116** -- **decided by the orchestrator, 2026-09-18: the monitoring half is not shipped.** Measured on
the throwaway: kill `^IRIS.Temp.SAM` in `%SYS`, confirm it stays undefined through a five-second control with
no call, then issue one `MonitorPort.Invoke` and the node comes back defined, carrying alerts.log's newest
line; an empty tag, a bogus tag and a matching tag all advance it. Tag mode decides which rows come back, not
whether the cursor is written. Since the API reads the same file the tail reads, and reads it lossily, the
merge bought no data at the cost of another SAM consumer's alerts. The implementation is recoverable at
`33361dc`; FR-76's story re-takes the decision where a consumer exists. `epics.md` 6.13 AC1 and AC2 carry the
amendment; nothing in this tree reaches the monitoring API.


#### Filed, not patched

- **DW-1109** `escalated owner=burndown` -- AC7's "Clear filter" control exists nowhere in the client. Fix risk
  high: a shared shell control plus a strings row `EXPERIENCE.md:367` lists as *reused*, so it needs a Rule 5
  amendment.
- **DW-1110** `escalated owner=burndown` -- `LogViewerStore` is absent from `app.ts`'s sign-out teardown, so one
  principal's log rows survive a sign-out in the same tab (AD-8). One line, in a contended file.
- **DW-1111** -- **closed in the rework**: the "admin-port-only by two independent hard-codings" claim in
  `Screen/Tool/ErrorRead.cls:4-6` is corrected at its origin, comment only, under an explicit footprint
  exception.
- **DW-1117** `escalated owner=burndown` -- `EXPERIENCE.md:368` authorizes
  `alertLogRecentUnavailable`, which no shipped component renders now that the monitoring half is gone. The
  string stays in `strings.ts` because the authorized set is re-derived from that table and the table is the
  lead's to amend (Rule 5).


#### Closed at emission

`wontfix-accepted` unless noted; `reopen_if` is the probe that would revive it. The items that pinned the
monitoring half went with the code they pinned.

- The `load-older` absence assertions cannot fail -- nothing renders that selector. AC5's oldest-end witness is
  the one-request count beside them, which is asserted. *reopen_if:* a control for the older end is added.
- `Test/ReadSourceCorpus.cls` gained no `logsource` case. The three refusal arms are covered in **both** engines
  through `Test/AdminPairCorpus.cls`, which `screen-mirror.test.mjs:673` reads off disk. *reopen_if:* a
  `logsource`-specific `type`/`forEach`/`query` sentence is added.
- `matchesSearch` matches on pid, stamp and category while `highlightSpans` marks only the text. The row still
  paints `.ocu-log-row-match`, so a match is visible. *reopen_if:* the row-match background is removed.
- `screen-height.browser-spec.mjs`'s `log-viewer` case depends on `alerts-log.browser-spec.mjs` having seeded
  the file, through the glob's own order. Both are throwaway-scoped and `alerts-log` sorts first.
  *reopen_if:* `screen-height.browser-spec.mjs` is run alone against a fresh throwaway.
- The viewer renders no header row, so `logViewerColumnSeverity`, `logViewerColumnMessage` and `auditColumnTime`
  reach the mirror and the agent tool but not the screen; and the pid cell's empty word is the component's
  `tableEmptyValue` rather than a declared `emptyKey`. Both follow `EXPERIENCE.md:408`'s log-viewer pattern,
  which is rows rather than a table. `by-design`.
- The info and warning chips set `color` only over the surface; severe and fatal use the declared inverted pair.
  Every chip carries its word, so "never color alone" holds. *reopen_if:* a contrast check fails on a chip.

#### Scoped re-review of the rework (Tier 1, `scoped`, baseline `33361dc`, 2026-09-18)

Reviewed the rework diff only. Every probe was run by the reviewer on the throwaway `ocupilot-b-ci`
(52777), brought up fresh for this pass; no layer executed a test. The removal is complete: no
`MonitorPort`, `MonitorLog`, `MONITOR.*`, `/logs/alerts/recent`, merge, dedup, tag or
recent-unavailable reference survives anywhere in `src/`, `ui/` or the tooling.

| # | Severity | Finding | Where | Disposition |
|---|---|---|---|---|
| 18 | med | DW-1111's replacement was false in the same way the claim it replaced was: "the declared-read grammar names one endpoint and one request type". `read.source.forEach` names a **second** endpoint (`Screen/Read.cls:39`; `ForEachRows` issues `forEach.endpoint`, then `source.endpoint` per parent), `read.source.parts` names one to three request types on one endpoint (`SystemUsage.cls` declares three), and `rowGet` adds a second request type | `Screen/Tool/ErrorRead.cls:4-6` | patched, comment only, inside the granted one-comment exception: the sentence now carries the already-reviewed twin's reason from `LogErrorList.cls:7` -- a descriptor declares exactly one read, and three drill levels with three column sets could not be one |
| 19 | low | `HEADFORM` has no optional group -- it ends `-?[0-9]+ .*$` -- so "the same span the grammar's own optional group matches" named a group that is not there. The optional group is `log-line.ts`'s `HEAD_RE`; the two strip rules do agree, which is what the sentence should say | `LogSourcePort.cls` (`HeadParts`), `Test/LogSource.cls` | patched; both engines' strip rules checked against each other on `[a]b] c`, `[a] b] c`, `[a]] b` and `[] x` |
| 20 | med | `epic-6-context.md:86` and `:261` still say 6.13 ships `MonitorPort` and merges the monitoring API's entries -- the context 6.14's runner reads at spawn, for the story that declares against this very page and store | `epic-6-context.md` | **DW-1118** `routed owner=6-14-the-messages-log-viewer` |
| 21 | low | The rework's one unreproduced smoke failure (`executed=43 passed=42 failed=1`) names no check, so it cannot be triaged after the fact. Five further runs here: `executed=44 passed=44 failed=0` | `scripts/smoke.sh` reporting | **DW-1119** `escalated owner=burndown` |

**Re-demonstrated (Rule 19), by the reviewer, whole tree recompiled in-container before each result:**

- AC10 -- a fourth key in `LogSourcePort.Entries` -> `Test/LogSource.TestRowsProjectTheTailNewestFirst` red on exactly the row-key assertion (`["time","severity","text","pid"]`), 1 of 19; reverted byte-identical.
- AC9 -- `%DB_IRISSYS:READ` added to `ALERTSPAIRS` -> `Test/LogSourceDenial.TestTheAlertLogsOnePairGovernsBothWaysIn` red on exactly the three served assertions the spec names, which is what establishes that both ways in read that one parameter; reverted byte-identical.

**Re-verified:** `check-objectscript` 372 files / 0 problems (after the patches); `npm run build` green; `npm test` 45 vitest files + the node suite, 0 failed; `ci-runner` 7 classes / 157 tests / 0 failed, then `LogSource` and `ReadTool` again after the patches; `npm run test:browser` 130/130 against the redeployed bundle; `smoke.sh` x5 `executed=44 passed=44 failed=0 pending=2`, `alerts` passing; `lint-docs.sh` clean. `Rows`'s gate order is `Page`'s -- enum, empty-pair refusal, gate, `maxBytes`, cursor, **then** `Resolve` -- so no file is resolved before the gate on either way in, and `Test/LogSourceDenial` establishes it over the wire for both.

**Closed at emission** (`wontfix-accepted`; `reopen_if` revives it):

- `Test/ReadTool.TestTheAlertReadToolCarriesTheTailsRowsAndNotItsCursor` quits before its row-key assertion when the read answers no rows, which is an instance whose `alerts.log` does not exist yet. The assertion above it (`fields`, and the absence of `lines`/`offset`/`identity`) runs unconditionally, and the row-key claim is pinned unconditionally in `Test/LogSource`. Its doc comment's mutation would show nothing on a genuinely empty instance. *reopen_if:* the `Test/LogSource` row-key assertion is removed.
- `Registry.ReadProblem` does not check a `logsource` `endpoint` against `LogSourcePort.Sources()`; a bogus key is refused 404 `LOG.SOURCE` by the port, named. `Test/Descriptor` pins the shipped descriptor's key against the live enum. *reopen_if:* a second `logsource` descriptor lands.
- `Rows` takes `Page`'s default window and no `maxBytes`, so a cap larger than the window answers fewer rows than asked. Documented at the method. *reopen_if:* a `logsource` read declares a cap above what 65536 bytes of that file hold.
- The `logsource` refusal set: the port-enum sentence and the `rowGet` sentence are `logsource`-specific and have a corpus case each in `Test/AdminPairCorpus`, which both engines run (`ReadTool.TestEveryAdminPairCorpusCaseGetsItsSentence`, `screen-mirror.test.mjs:672`); every other arm refuses `logsource` through a generic non-admin guard that interpolates the port name, so it is identical in both engines by construction. 18 cases, the four admin `%DB_IRISSYS:READ` negatives intact.

## Spec Change Log

- **2026-09-18, the monitoring half is not shipped** (orchestrator decision at the 6.13 spec gate; `epics.md` 6.13 AC1 and AC2 amended in the same breath, DW-1116). `MonitorPort`, `Api/MonitorLog`, the `/logs/alerts/recent` route, the `MONITOR.*` codes and their tests are removed; the fourth source port is repointed from `monitor` to `logsource` and dispatches to `LogSourcePort`, which gains a `Rows` entry point over the window it already serves. The implementation being removed is recoverable at `33361dc`. `## Intent`, the `Always`/`Never` blocks, the I/O matrix, the Code Map, all ten ACs and `## Verification` were rewritten to match; the ACs' numbering is kept so earlier trailers still resolve.
- **2026-09-18, an absent alerts.log is an empty read.** Measured on a fresh throwaway: the file does not exist until the instance raises an alert. `Page` still answers 404 `LOG.ABSENT` for the byte-paging caller; `Rows` and the viewer read that one code as zero entries, which is what makes the I/O matrix's own "a missing file is not a fault" row reachable.


## Review Triage Log

Code review 2026-09-18: 1 high, 10 med and 6 low patched in-pass; 9 items closed at emission. The detail is
under `### Review Findings`, which is kept as the history of the pass that reviewed the monitoring half.
DW-1108 closed `resolved-by:6-13-the-alerts-log-viewer`.

Rework 2026-09-18 (orchestrator-directed): **DW-1116 decided** -- the monitoring half is not shipped, and the
findings under `### Review Findings` that pinned it (items 2, 4, 5, 6, 7 and the merge halves of 16 and 17)
went with the code they pinned. **DW-1111 granted and closed** by correcting the claim at its origin in
`Screen/Tool/ErrorRead.cls:4-6`, comment only. DW-1109 and DW-1110 stand `escalated owner=burndown`; neither
is reachable from this story's footprint. **DW-1117 filed**: `EXPERIENCE.md:368` still authorizes
`alertLogRecentUnavailable`, which no shipped component renders.


## Design Notes

**Governing ADs (Rule 6):** AD-1, AD-5, AD-8, AD-9, AD-12, AD-13, AD-21, AD-24, AD-29, AD-35, AD-36, AD-39, AD-43 (the roster this screen does not join), AD-44, AD-48.

**Why one reader, and what it costs.** `%SYSTEM.Monitor.GetAlerts` reads `$zu(12)_"alerts.log"` (`irissys/%SYSTEM/Monitor.cls:60`) -- the same file the bounded tail reads -- and reads it strictly more lossily: it drops the pid and the bracketed category, quotes the severity, and rewrites a local-time stamp with a `Z` suffix nothing converted. What it uniquely supplies is a cursor, and that cursor is instance-wide: measured on the throwaway, one call defines `^IRIS.Temp.SAM("LastAlertSent")` from undefined whatever tag is passed, so another SAM scraper on the operator's instance loses every alert OcuPilot's read moved past. The merge therefore buys no data the tail lacks at a cost the operator did not ask for, and the screen reads the file once (DW-1116).

**Two engines, one grammar.** `LogSourcePort.HEADFORM` parses the head line on the server, because a declared read answers rows; `log-line.ts`'s `HEAD_RE` parses it on the client, because the screen renders raw lines with a Raw view and a search. They are the same grammar over the same file, and the same shapes are pinned on both sides -- the continuation fold, the mid-continuation window, the optional bracketed category and a severity outside the vendor's scale.

**The viewer's contract for Story 6.14.** 6.14 declares, and does not rebuild: the `log-viewer` page and store, `log-line.ts`'s parser (one grammar serves both files -- `messages.log` head lines match the same regex, and the parser tolerates continuation lines, of which `messages.log` on slot B has 139 against `alerts.log`'s 0), the severity chips and their five words, the sticky search with highlight and polite count, next/previous, jump to top and bottom, Load newer, the Raw toggle, the severity-chip filter, the `ARCHETYPE_PAGES` entry, the styles, and the `alerts`-shaped `LogSourcePort` key and its `Rows` projection. 6.14 adds its own descriptor at `sideBarPosition 2` against the `messages` key, which is already in the enum and already has its route. **Its read tool has no descriptor-derived path -- DW-1100.**

**Ledger inbox dispositions.**

- **DW-148** -- declined here, stays 6.14. Its residual names the fault banner's "Open messages.log" link, which reaches the screen 6.14 builds.
- **DW-278** -- **decided here**, because 6.13 is the first Logs viewer to ship. This screen declares `%Admin_Operate:USE` alone and does **not** declare `%Admin_Secure:USE`; the pair set is a subset of the Logs area's union (`Screen/Area.cls:117`), so `Area.cls` is untouched and the area's accepted false denial stands as the owner settled it on 2026-09-14.
- **DW-1025** -- **investigated here, fixed in 6.14.** The `<PROTECT>` is OcuPilot's, not the vendor's; the fix is a guard inside `AdminPort.ForgetTask`, which is not this story's file.
- **DW-1111** -- **closed here**, comment only, at its origin.
- **DW-1116** -- decided by the orchestrator; this story's shape is that decision.

**Pair sets.** Screen: `%Admin_Operate:USE`. `LogSourcePort.ALERTSPAIRS`: the same one pair. They are deliberately equal, so a user meets the same gate whether the screen pages the file or an agent reads the declared rows; AC9 establishes it on a real least-privileged principal rather than copying it.

**AD-35 becomes load-bearing for alerts.log.** OcuPilot's own structured logger writes `[OcuPilot.Log]` lines into alerts.log, so this screen is the first to render OcuPilot's own log output back to a user and to an agent. AD-35's rule that no credential may enter a log line now governs alerts.log as it already governs messages.log and the error log.

**Consumes (Rule 2):** `LogSourcePort.Page` (Epic 2), `LogPage.Handle` (Epic 2), `Screen/Read` + `Registry` (Epic 2), `ListPage`'s command bar (Epic 2, Story 6.11), `Screen.Gate`, `Kernel.Fault.LogRaw`, `Api.Response`/`Api.Error`. **Consumed-by (Rules 1, 2):** Story 6.14 (the whole viewer, the parser, the chips, the controls, the styles, the `Rows` projection), Story 11.2 (explains a row through `logs.alerts.read`), Story 1.12's Home suggested view (`epics.md:3044`). AC10 is the Integration AC and is exercised against a real instance, never a mock.


## Verification

**Commands** (all run 2026-09-18 against `ocupilot-slot-b` and the throwaway `ocupilot-b-ci`):

- `uv run scripts/check-objectscript.py` -- `scanned 372 ObjectScript file(s) over 18 rule(s); 0 problem(s)`.
- `cd ui && npm run build` -- the six `prebuild` checkers pass; `classic-links` reports one honored exemption, `field-lists` and `ipm-manifest` up to date.
- `cd ui && npm test` -- `tests 857 / pass 857 / fail 0` (node), then `Test Files 45 passed / Tests 515 passed` (vitest).
- `node tools/ci-runner.mjs --container ocupilot-b-ci`, no `--class`, against a throwaway brought up after the last edit -- `ci-runner: 96 class(es), 964 test(s), 0 failed, 0 with probe leftovers, 0 overlap(s), 0 foreign run(s)` / `ci-runner: green.`
- `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci npm run test:browser`, after `npm run build` and `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/` -- `tests 130 / pass 130 / fail 0`.
- `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` -- `executed=43 passed=43 failed=0 pending=2 skipped=1` / `PASSED`, `alerts` among the passes.
- `bash scripts/lint-docs.sh` -- `Summary: 0 issues in 0 files`, `check-prose: 0 problem(s) in 74 file(s)`.

**Mutations (Rule 19) -- one per AC, each applied, observed red, reverted, and the tree confirmed byte-identical:**

- AC1 -- `mutation:` drop `alerts` from `LogSourcePort.SOURCES` -> `Test/LogSource.TestTheAlertsKeyIsServedFromTheManagerDirectory` red (`the alerts key is in the shipped enum: messages,applicationerrors`) (observed).
- AC2 -- `mutation:` resolve the file above the gate in `Page` -> `Test/LogSource.TestNoFileIsOpenedBeforeTheGate` red (`and no file was resolved, opened or read`) (observed).
- AC3 -- `mutation:` delete the `logsource` arm from `Screen/Read.Execute` -> `Test/ScreenRead.TestEveryDeclaredLogSourceReadFieldIsAKeyOfTheLiveRow` red (`PORT.NOTIMPLEMENTED`, the read having fallen through to the admin port) (observed).
- AC4 -- `mutation:` make a non-matching line open its own entry in `parseFileLines` -> `log-line.spec.ts`'s continuation test red (`expected ... to have a length of 2 but got 3`) (observed).
- AC5 -- `mutation:` send the tail request without `identity` -> `log-viewer.spec.ts`'s Load-newer cursor assertion red (observed).
- AC6 -- `mutation:` add a `setInterval` re-read to `log-viewer.store.ts` -> `log-viewer.spec.ts`'s zero-timers assertion red (`expected 21 to be 1`) (observed).
- AC7 -- `mutation:` drop the severity word from the chip, leaving color alone -> `log-viewer.spec.ts`'s chip-text assertion red (observed).
- AC8 -- `mutation:` `--ocu-log-row-height: 32px`, rebuilt and redeployed -> `alerts-log.browser-spec.mjs`'s height assertion red over 96 measured rows (observed).
- AC9 -- `mutation:` add `%DB_IRISSYS:READ` to `LogSourcePort.ALERTSPAIRS`, recompiled in the throwaway -> `Test/LogSourceDenial.TestTheAlertLogsOnePairGovernsBothWaysIn` red on all three served assertions (observed).
- AC10 -- `mutation:` give each row a fourth key in `LogSourcePort.Entries` -> `Test/LogSource.TestRowsProjectTheTailNewestFirst`'s row-key assertion red (`["time","severity","text","pid"]`) (observed).

An ObjectScript mutation was believed only after the whole tree was recompiled -- `iris_doc_load` with `cuk` on `ocupilot-slot-b`, or an in-container `$System.OBJ.LoadDir` after refreshing the throwaway's source copy for the two that need a throwaway. A browser mutation was believed only after `npm run build` and a `docker cp` of the bundle.

**Manual checks:**

- `iris_server_profiles` reported `ocupilot-slot-b` on 52775 before any MCP call in this pass.
- The classic page `%cspapp.op.utilsysconsolelog` is confirmed to exist on the throwaway.
