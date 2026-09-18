---
title: 'Story 6.14: The messages.log viewer'
type: 'feature'
created: '2026-09-18'
status: 'done'
baseline_revision: '68027e6e04479fb10f5df484789cf6a496c2df70'
baseline_commit: '68027e6e04479fb10f5df484789cf6a496c2df70'
review_loop_iteration: 1
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The Logs side bar has no messages.log entry. Everything the screen needs already
ships: `LogSourcePort.SOURCES` carries `messages` with `MESSAGESPAIRS`, `Router.cls:88` carries
`GET /logs/messages`, and Story 6.13 built the shared `log-viewer` page, store and parser. What is
missing is a descriptor, one client source entry, and four ledger items the screen's arrival makes
due.

**Approach:** Declare `LogMessageViewer` at `sideBarPosition` 2 against the `logsource` source port
6.13 added, add one route to `log-viewer.page.ts`'s `SOURCES` map, and spend the story on the four
items: the fault banner's destination (DW-148), `AdminPort.ForgetTask`'s `<PROTECT>` (DW-1025) and
its surviving rows (DW-1101), and AC4's Clear control (DW-1109).

## Boundaries & Constraints

**Always:**

- **No new reader, no new route, no parser change, no new archetype, no store of its own.** The
  screen reads `/logs/messages` (`LogPage.Handle("messages")`) for its pages and
  `LogSourcePort.Rows("messages", cap)` for its declared read. `SOURCES`, `MESSAGESFILE`,
  `MESSAGESPAIRS`, `HEADFORM`, `Page`, `Rows`, `Entries`, `HeadParts`, `log-line.ts` and
  `log-viewer.store.ts`'s cursor logic are **unchanged**.
- **The pair set is `%Admin_Operate:USE` alone**, equal to `LogSourcePort.MESSAGESPAIRS`, so both
  ways in meet one gate (AD-29). `Screen/Area.cls` is untouched: the Logs union already covers it
  and its accepted false denial stands as the owner settled it (DW-278).
- **The rotation AC is `Page`'s existing mechanism, re-established on the `messages` key.**
  `LogSourcePort.cls:514-526` restarts at byte 1 on either of two conditions — the cursor's
  `identity` no longer matches the file's, or the cursor is past `size + 1` — and answers
  `restarted` true; `log-viewer.store.ts:246` replaces rather than appends on it. Nothing new is
  built; the story pins it for this file.
- `refreshes: false` / `refreshRates: []`; the screen joins no AD-43 roster, registers no timer and
  opens no `EventSource` or `WebSocket`.
- Every rendered severity carries its word (`EXPERIENCE.md:658`); a level outside the vendor's
  five-word scale renders as the number itself.
- `AdminPort.cls`, `Screen/Read.cls`, `Registry.cls`, `Descriptor/Base.cls`, `Installer.cls`,
  `Smoke.cls`, `Router.cls`, `Error.cls`, `Test/Descriptor.cls`, `screen-mirror.mjs`,
  `screen-store.ts` and `strings.ts` are shared with Epic 4: **additive only**.
- `ui/src/app/core/screens.generated.ts` is regenerated with `node tools/screen-mirror.mjs`, never
  hand-merged.

**Never:**

- Never `src/OcuPilot/Kernel/**`, `Port/ProviderPort.cls`, `Screen/Tool/**`,
  `scripts/check-objectscript.py` or its harness, `ui/src/app/app.ts`, `app.spec.ts`,
  `ui/src/app/shell/panel/**`, `ui/package.json`, `package-lock.json`, `angular.json`, `README.md`.
- Never a new source kind or a `Screen/Tool` class: the `logsource` port closes DW-1100 as declared
  (`Read.cls:263-266` dispatches `read.source.endpoint` generically).
- Never a caller-supplied path, file name or namespace on any route (AD-21).
- Never a row action, primary action or link out of a `log-viewer` (AD-44).
- Never a new shell command-bar slot for Clear: the viewer's own sticky bar is where its search,
  jump and Raw controls already live (`log-viewer.page.ts:75-102`).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| First load | screen opens | one tail page from `/logs/messages`; the browser never holds more than one window | a fault is the screen's own refusal |
| Rotation mid-paging | held `identity` no longer matches, or `offset > size + 1` | `restarted` true, window re-seeded from byte 1, rendered rows **replaced** | a restart is an outcome, never a fault |
| Gate refused | caller holds no `%Admin_Operate:USE` | 403 `AUTH.NOPRIVILEGE` naming the pair, before any filesystem touch | the fixture's touch counter reads zero |
| Declared read | `GET /screens/logs.messages/read` | at most the cap's rows, newest first, exactly `time`, `severity`, `text` | the page envelope reaches no caller |
| Chip click / Clear | user clicks a severity chip, then Clear | the filter is that severity; Clear returns every row and disappears | — |
| Search with no match | needle matches nothing in the filtered set | "No matches." | — |
| Unprivileged async read | caller lacking write on the async-task database finishes an `AdminPort` async read | the vendor row is left in place and **no fault is logged** | no `<PROTECT>` in any log OcuPilot writes |
| Fault banner | a server fault, this screen built and allowed | "Open messages.log" opens `logs/messages` **and** the Logs side bar | while the screen is not allowed the control stays `aria-disabled` |

</intent-contract>

## Code Map

**Read for the shape, change nothing:**

- `src/OcuPilot/Port/LogSourcePort.cls` — `SOURCES:49`, `MESSAGESKEY/FILE/PAIRS:52-68`,
  `Page:450-548` (step order, the two restart conditions at `:514-526`, seven result keys),
  `Rows:570-593`, `Entries:597-632`, `HeadParts:641-660`.
- `src/OcuPilot/Api/LogPage.cls` and `Api/Router.cls:88` — the route already binds `messages`.
- `src/OcuPilot/Screen/Read.cls:151-155`, `:263-266` — the `logsource` branch, endpoint-generic.
- `src/OcuPilot/Screen/Descriptor/LogAlertViewer.cls` — the descriptor to mirror; `sideBarPosition`
  2 is free (`LogErrorList.cls:71` is 3, `AuditList.cls:116` is 4), so **nothing renumbers**.
- `ui/src/app/areas/logs/{log-viewer.page,log-viewer.store,log-line}.ts` — the shared viewer.
- `_bmad-output/implementation-artifacts/spec-6-13-the-alerts-log-viewer.md` — `## Design Notes`
  "The viewer's contract for Story 6.14" is the authority on what is already built.

**Changed by this story:**

- `src/OcuPilot/Screen/Descriptor/LogMessageViewer.cls` — new. Route `logs/messages`, area `logs`,
  `labelKey messagesLogListLabel`, `sideBarPosition 2`, archetype `log-viewer`,
  `privileges [{%Admin_Operate, USE}]`, `entityType log-entry`, `scope instance`,
  `id {"kind":"none","parts":[]}`, `read.source {"port":"logsource","endpoint":"messages","type":"LIST"}`,
  `read.fields/filter ["time","severity","text"]`, `paging "cap"`,
  `commandAliases ["messages","messages.log"]`, `classicPage "%cspapp.op.utilsysconsolelog"`,
  `toolIdentifier "logs.messages"`.
- `ui/src/app/areas/logs/log-viewer.store.ts` — additive: a `MESSAGES_SOURCE` beside
  `ALERTS_SOURCE`. `ui/src/app/areas/logs/log-viewer.page.ts` — one `SOURCES` entry, plus the
  Clear control and its `chipValue` reset (DW-1109).
- `ui/src/app/shell/fault-banner.ts` — **two defects in one handler.** `:97` takes the *first*
  built `log-entry` screen, which is `LogAlertViewer` at `sideBarPosition` 1, so the control
  labeled "Open messages.log" opens alerts.log today and would still do so after this story;
  and `openMessagesLog():153-157` navigates without `ShellState.showArea` (DW-148). Resolve the
  screen from the descriptor's own declaration of the file it shows — the `messages.log`
  `commandAliases` value, never a route literal typed in the shell (AD-5) — and open the area.
  `fault-banner.spec.ts:35`'s synthetic `screen('logs/messages','log-entry')` now has a production
  twin and must assert against the real ordering.
- `src/OcuPilot/Port/AdminPort.cls` — additive, inside `ForgetTask:660-673`: skip the `%DeleteId`
  when the caller does not hold write on the database the vendor's async-task rows live in, and
  log nothing when it is skipped (DW-1025). One guard clause plus whatever it needs to name the
  resource; no signature change, no new call site — `ForgetTask` is called only from
  `AwaitTask:872,878`, which Epic 4 does not call.
- The roster tripwires: `Install/Smoke.cls` (a `MESSAGESLISTTOOL = "logs.messages"` parameter, the
  loop bound `:632` 27→28, the name list `:633` — use `messages`, distinct from the existing
  `messageslog` page check — and the indexed `$Select` `:634`); `Test/Smoke.cls` (the roster
  `:588`, the `30`→`31` count in the assertion, the `If` guard and the `For` bound `:601-604`,
  `tExpected:602`, the window comment `:552-571`, and the fourth roster `:702`);
  `Test/Navigation.cls`'s logs block; `Test/Wire.cls`; `Test/ReadTool.cls:94` (the alphabetical
  name roster) and `:100` (the descriptor pairing); `ui/tools/navigation.test.mjs:129`;
  `ui/tools/navigation-wire.test.mjs:62,433` and `ui/src/app/shell/rail-wire.spec.ts:58,442`
  (**neither `LIVE_PAYLOAD` copy reddens alone** — each needs its own
  `screenVerdict('logs/messages')` assertion, 6.13 finding #9); `screens.generated.ts`
  regenerated; `ui/browser/screen-height.browser-spec.mjs` (a `logs/messages` case beside AC-A).

**Measured on `ocupilot-slot-b` (52775), 2026-09-18:**

- `messages.log` is 160,452 bytes / 1,177 lines: 1,038 head lines and **139 continuations**;
  severities present are 0 (778), 1 (19) and 2 (241) — **three of the vendor's five words, not
  five**. The last 65,536 bytes (one default window) hold 29 / 2 / 220. Longest line 1,126 chars.
- Zero `PROTECT` lines in `messages.log` here; `_SYSTEM` holds `%DB_IRISLOCALDATA:WRITE`
  (`$System.Security.Check` = 1). DW-1025's sighting was on a fresh throwaway.
- `^|"^^:ds:IRISLOCALDATA"|Api.Admin.Util.AsyncTaskD` holds **7** rows (4 when DW-1101 was filed),
  every one `_SYSTEM` / `Finished` / `GET /v2/ocupilot/database/syscrud`, queued, started and
  finished in the same second. `%Api.Admin.Util.AsyncTask`'s IdKey is `GUID` and the rows exist by
  that id; `%DeleteId` on a missing id returns `ERROR #5810`, which `ForgetTask` would log — and
  **neither** log carries "an async task row could not be removed". So `ForgetTask` is not reached
  for these: `AdminPort.cls:361` enters the await only when the sequence answers 202 **and** the
  `Location` header contains `ASYNCLOCATION`.

## Tasks & Acceptance

**Execution:**

1. **Fixed strings row and the planning correction, applied by the lead before this spec was dispatched.** `EXPERIENCE.md:369` carries the messages.log row verbatim (`messagesLogListLabel`, `logViewerClearFilter`), and `:411`'s `log-viewer` row no longer says alerts.log merges the monitoring API's entries -- both logs are read from the file through the bounded endpoint (DW-1116). Implement edits no planning artifact; it reads that row as the authority for the two new strings.
2. `src/OcuPilot/Screen/Descriptor/LogMessageViewer.cls` — the descriptor.
3. `ui/src/app/areas/logs/log-viewer.store.ts` + `log-viewer.page.ts` — `MESSAGES_SOURCE`, the
   `SOURCES` entry, the Clear control.
4. `ui/src/app/shell/fault-banner.ts` — the destination and the side bar.
5. `src/OcuPilot/Port/AdminPort.cls` — `ForgetTask`'s guard.
6. The roster and client tripwires listed in the Code Map; regenerate `screens.generated.ts`.
7. Tests: `Test/LogSource.cls` (the `messages` key, the rotation restart, the row projection),
   `Test/LogSourceDenial.cls` (AC7), `Test/Descriptor.cls` (both shipped `logsource` endpoints
   against the live `LogSourcePort.Sources()` enum), `Test/ScreenRead.cls`, `Test/ReadTool.cls`,
   `Test/AdminPort*.cls` (AC9); client `log-viewer.spec.ts`, `fault-banner.spec.ts`,
   `fault-banner.wire.spec.ts`; `ui/browser/messages-log.browser-spec.mjs`.

**Acceptance Criteria:**

- **AC1 (bounded, never the whole file).** Given the messages.log screen, when it loads and the
  user presses Load newer, then each request is one `/logs/messages` page bounded by
  `DEFAULTMAXBYTES`, the browser holds only the windows it has been given, and no request asks for
  the file's whole size. Pinned by `log-viewer.spec.ts` and `Test/LogSource.cls`.
- **AC2 (the declared read and its derived tool — the Integration AC, Rule 1).** Given
  `read.source {"port":"logsource","endpoint":"messages"}`, when `Screen/Read.Execute` and the
  derived tool `logs.messages.read` run against the live instance, then both answer at most the
  cap's rows, newest first, each carrying exactly `time`, `severity`, `text`, with no `lines`,
  `offset` or `identity` in the tool's view and **no `Screen/Tool` class involved** — which closes
  DW-1100. Pinned by `Test/ScreenRead.cls` and `Test/ReadTool.cls`.
- **AC3 (a rotation restarts cleanly).** Given a held cursor on `messages.log`, when the file is
  rotated under it, then the next page answers `restarted` true and re-seeds from byte 1 without a
  fault, and the rendered rows are replaced rather than appended to; and the same holds when the
  held offset is past the new file's end. Pinned by `Test/LogSource.cls` and `log-viewer.spec.ts`.
- **AC4 (search and the Raw view's geometry).** Given a rendered tail, when the user searches, then
  matches highlight, a polite `role="status"` announces "n of N", Enter and Shift+Enter move the
  caret; and when the Raw toggle is pressed, then the block is monospace with a line-number gutter,
  does not wrap, and scrolls horizontally inside its own box while the page does not — measured in
  a real browser, since jsdom computes no layout. Pinned by `log-viewer.spec.ts` and
  `messages-log.browser-spec.mjs`.
- **AC5 (the chip filter and Clear).** Given a rendered tail, when the user clicks a severity chip,
  then only that severity's rows remain, the chip reads `aria-pressed`, and a Clear control appears
  in the viewer's sticky bar; when Clear is pressed, then every row returns and the control
  disappears. Every chip carries its word. Pinned by `log-viewer.spec.ts` and
  `messages-log.browser-spec.mjs`.
- **AC6 (row geometry, UX-DR80's other half).** Given a real `messages.log` tail on a throwaway
  seeded through `%SYS.System.WriteToConsoleLog` so all five vendor levels are present (DW-1103:
  every level reaches this file, unlike alerts.log) together with a line at least as long as the
  1,126 chars slot B's file holds, when the browser measures every rendered log row, then each is
  exactly 28 px — a fixed height, not a minimum (`DESIGN.md:912`). Pinned by
  `messages-log.browser-spec.mjs`.
- **AC7 (least-privileged principal, AD-29).** Given a purpose-built role holding exactly
  `%Admin_Operate:USE` — never `%Operator` — when the page route and the declared read are
  exercised on a throwaway, then both carry past the gate; and for a principal holding
  `%Admin_Secure:USE` instead, both are refused 403 naming `%Admin_Operate:USE`, with the
  fixture's filesystem-touch counter at zero. Pinned by `Test/LogSourceDenial.cls`.
- **AC8 (the fault banner reaches this screen, DW-148).** Given a server fault and this screen
  built and allowed, when the user presses "Open messages.log", then the route opened is
  `logs/messages` — not the first `log-entry` screen, which is alerts.log — and the Logs side bar
  is showing it. Pinned by `fault-banner.spec.ts` and `messages-log.browser-spec.mjs`.
- **AC9 (no `<PROTECT>` in the file this screen displays, DW-1025).** Given a caller that does not
  hold write on the database the vendor's async-task rows live in, when an `AdminPort` async read
  completes, then the row is left in place and **no fault is logged** — nothing OcuPilot writes to
  `messages.log` or `alerts.log` carries `<PROTECT>` from that delete; and given a caller that does
  hold it, the row is still deleted. Pinned by an `AdminPort` test with a real least-privileged
  principal on a throwaway plus a log sweep.

### Review Findings

- [x] [Review][Patch] Two smoke roster assertions could not fail: `messages` is a prefix of `messageslog` [src/OcuPilot/Test/Smoke.cls:593, :711]
- [x] [Review][Patch] An unmapped `log-viewer` route silently rendered alerts.log; no test pinned the map [ui/src/app/areas/logs/log-viewer.page.ts:217]
- [x] [Review][Patch] Clear removed itself while holding focus, against EXPERIENCE.md's Focus destinations [ui/src/app/areas/logs/log-viewer.page.ts:362]
- [x] [Review][Patch] The AC9 log sweep passed as "nothing logged" if it could not read [src/OcuPilot/Test/WireSecurityRead.cls:1105]
- [x] [Review][Patch] `AwaitTask`'s doc comment still promised an unconditional delete; `Test/LogSource`'s header understated what it needs [src/OcuPilot/Port/AdminPort.cls:871, src/OcuPilot/Test/LogSource.cls:8]
- [x] [Review][Patch] `Test/ReadTool`'s comment claimed an index immunity the window does not have [src/OcuPilot/Test/ReadTool.cls:1180]
- [x] [Review][Defer] `ASYNCTASKPAIR` is a literal under a doc comment claiming it is derived; a non-default IRISLOCALDATA resource silently stops every delete [src/OcuPilot/Port/AdminPort.cls:86] -- deferred: DW-1137, `escalated owner=burndown`, fix-risk high (a %SYS resolution on the async path in a file Epic 4 shares)
- [x] [Review][Defer] The guard leaves a vendor async-task row behind on every unprivileged async read, with nothing to purge them [src/OcuPilot/Port/AdminPort.cls:682] -- deferred: DW-1136, `escalated owner=burndown`, a product/ops call the guard itself does not settle
- [x] [Review][Defer] The planning artifacts still put Clear in the shell command bar, and the new strings row cites two wrong lines [EXPERIENCE.md:412, :367, :369; epics.md 6.14 AC4] -- deferred: DW-1138, `escalated owner=burndown`, a Rule 5 amendment code review may not make
- [x] [Review][Defer] The two `LIVE_PAYLOAD` fixtures describe a verdict set no live instance can answer [ui/src/app/shell/rail-wire.spec.ts:61, ui/tools/navigation-wire.test.mjs:65] -- deferred: DW-1139, terminal with a reopen probe; client parsing, which is what they test, is unaffected
- [x] [Review][Defer] AC9's privileged half is pinned by the delete being attempted, never by a real row going [src/OcuPilot/Test/AdminPortForget.cls:52] -- deferred: DW-1140, terminal with a reopen probe
- [x] [Review][Defer] `onClear`'s caret reset is unreachable by any fixture these specs build [ui/src/app/areas/logs/log-viewer.page.ts:366] -- deferred: DW-1141, terminal with a reopen probe
- [x] [Review][Defer] The browser spec's re-seed guard counts its marker in the whole file, not the rendered window [ui/browser/messages-log.browser-spec.mjs:80] -- deferred: DW-1142, terminal; the failure is loud
- [x] [Review][Defer] A `messages.log` rotated to empty has no zero-row arm in the smoke or three suites [src/OcuPilot/Install/Smoke.cls:678] -- deferred: DW-1143, `wontfix-theoretical`
- [x] [Review][Defer] `Test/ReadTool`'s index comparison keeps a narrow flake window [src/OcuPilot/Test/ReadTool.cls:1184] -- deferred: DW-1144, terminal with a reopen probe
- [x] [Review][Defer] `messages-log.browser-spec` restates `alerts-log.browser-spec`'s harness [ui/browser/messages-log.browser-spec.mjs:1] -- deferred: DW-1145, terminal; reopens on a third log viewer
- [x] [Review][Defer] DW-1101 still read as this story's, so its ledger slice could not read empty [_bmad-output/implementation-artifacts/deferred-work.md] -- deferred: re-owned `routed owner=burndown by=cr` with the residual named

Code review, Tier 1 `full`, baseline `68027e6`, four layers (`blind-hunter`, `edge-case-hunter`,
`verification-gap`, `acceptance-auditor`) on `review_tier: full-opus`, barred from executing tests;
every execution-dependent claim was re-run by the reviewer on `ocupilot-slot-b` (52775) or the
throwaway `ocupilot-b-ci` (52777) and is marked with the instance it came from.

**Patched in this pass** (six edits, all in-footprint):

1. **MED, Rule 19 — two roster tripwires could not fail.** `Test/Smoke.cls`'s
   `TestNoCredentialsSkipsRatherThanPasses` matched `"  skipped  " _ tName` unterminated, and
   `messages` is a prefix of the existing `messageslog` check, so the assertion was satisfied by
   the console-log page line with no `messages` check at all (both lines confirmed present in a
   real no-credentials report, slot B). Terminated both roster matches — `$Char(10)` for the pass
   roster, `" -- "` for the skipped one, which `sign-out` as the last line needs. Falsified by
   renaming `messages` to `messagesx` in `Install/Smoke.cls`'s name list: both assertions red on
   `ocupilot-b-ci`, where the unterminated form stayed green.
2. **MED — an unmapped `log-viewer` route silently rendered alerts.log.**
   `log-viewer.page.ts:217` resolves `SOURCES[route] ?? ALERTS_SOURCE`, and this story is what
   makes that fall-through live (two entries, with `EXPERIENCE.md`'s `log-viewer` row anticipating
   "P1 secondary logs"). Added a `log-viewer.spec.ts` leg derived from the mirror: every built
   `log-viewer` screen is mounted and asserted to request `/api/ocupilot/logs/<its declared
   endpoint>`. Falsified by dropping the `'logs/messages'` entry from `SOURCES` — red naming the
   fall-through to `/api/ocupilot/logs/alerts` (observed). It also covers the cross-screen
   `setSource` path no test reached before.
3. **MED — Clear removed itself while holding focus.** `EXPERIENCE.md`'s Accessibility Floor,
   *Focus destinations*: "No control is disabled or removed while it holds focus without a named
   destination." `@if (showClear)` dropped the focused button on its own click and focus fell to
   `<body>`. `onClear` now hands focus to the chip whose filter it cleared, the project's own
   `document.querySelector(...)?.focus()` idiom. Pinned in the AC5 leg; falsified by removing the
   call — red reading `<body>` (observed).
4. **LOW — the AC9 log sweep could pass without reading anything.** `ConsoleLogSince`'s two
   assertions are absences, so a failed `LinkToFile` or `MoveTo` read as "nothing was logged".
   It now answers a sentence on either failure and the caller reads that first. (The
   bytes-versus-characters concern three layers raised is **not** a defect: `MoveTo` is
   `%Stream.FileBinary`'s, which `%Stream.FileCharacter` inherits unchanged, so the position is
   the byte `%File.GetFileSize` reported — noted at the method.)
5. **LOW — two stale contract statements.** `AwaitTask`'s doc comment still said both terminal
   arms "delete the row"; it now says they hand the row to `ForgetTask`, which deletes only for a
   caller holding `ASYNCTASKPAIR`. `Test/LogSource.cls`'s header still said "needs a writable
   manager directory and nothing else" while its new leg needs the instance's own `messages.log`.
6. **LOW — a false immunity claim.** `Test/ReadTool.cls` explained its last-row comparison as
   immune to a write landing between the two reads. A write shifts every position in a
   cap-bounded newest-first window, the last as much as the first; the comment now says what the
   comparison actually rests on (adjacent calls, nothing in the class writes the file) and what it
   discriminates (the file, not the index).

**Escalated to the burn-down gate** (`escalated owner=burndown`, decided at the decision sheet that
follows this story):

- **DW-1137 (MED, fix-risk high)** — `ASYNCTASKPAIR` is a literal under a doc comment headed
  "Derived from the vendor's storage, not chosen". On an instance whose IRISLOCALDATA carries a
  non-default resource the guard denies every caller and `ForgetTask` stops deleting, silently.
  `Test/AdminPortForget` derives and compares, so any instance the suite runs on reddens.
- **DW-1136 (MED)** — the guard's own consequence: every unprivileged async read now leaves a
  vendor async-task row behind for good, and the vendor's `PurgeAsyncQueue()` is `[Internal]` and
  scheduled by nothing. The refusal is right; the row it leaves is undecided.
- **DW-1138 (MED)** — the planning artifacts still put Clear in the shell command bar
  (`EXPERIENCE.md:412`, `:367`; `epics.md` 6.14 AC4), and the new Fixed strings row cites `:411`
  and `:403` where it means `:412` and `:406`. A Rule 5 amendment, which code review may not make.

**Closed terminal** (DW-1139 through DW-1145, each with its `reopen_if` probe): the two
`LIVE_PAYLOAD` fixtures now describe a verdict set no live instance can answer (alerts denied on
`%DB_IRISSYS:READ` beside messages allowed, although both declare `%Admin_Operate:USE` alone);
AC9's privileged half is pinned by the delete being *attempted*, never by a real row going;
`onClear`'s caret reset is unreachable by any fixture these specs build; the browser spec's
re-seed guard counts its marker in the whole file rather than the rendered window;
`Test/ReadTool`'s index comparison keeps a narrow flake window; the browser spec restates
`alerts-log.browser-spec`'s harness; and a `messages.log` rotated to empty has no zero-row arm
(theoretical). DW-1101 was re-owned to `burndown` with the residual named — the ledger still read
it as this story's, so the story's slice could not read empty.

**Checked and refuted** — each of these was filed by a layer and disproved by running it, not by
reading it:

- "`AdminPortForget`'s first leg may not be falsifiable: `##super` may bind `..HoldsPair` to
  `AdminPort`'s own copy." Removing the guard reddens leg 1 and leaves leg 2 green
  (**slot B**, and again on **ocupilot-b-ci**), so the fixture override does drive it.
- "AC9's wire leg is green with or without the guard: `ForgetTask` is never reached."
  With the guard removed, `TestAnUnprivilegedAsyncReadLeavesNoProtectInTheConsoleLog` fails with
  the vendor's real `<PROTECT>%DeleteData+38^%Api.Admin.Endpoints.Security.Audit.RecordListTask.1`
  in the bytes `messages.log` grew by (**ocupilot-b-ci**). The async path *is* taken for the audit
  read, the sweep *does* read the appended region, and AC9's pinning test is falsifiable.
- "The pre-existing DW-249 async-row assertion reddens once `ForgetTask` stops deleting."
  `WireSecurityRead` is 18 of 18 green across three runs (**ocupilot-b-ci**).
- "AC6's CSS-declaration read cannot survive the bundler." It finds `.ocu-log-row` in the
  production-built, minified stylesheet and passes (**ocupilot-b-ci**, 26 of 26 browser tests
  green after a rebuild and `docker cp`). A future merge of that rule would make it fail loudly,
  not silently.
- "The browser seeding's positional `iris session` argument and its 1,213-character line may not
  survive." All five vendor levels and the long line reach the file; AC6's `width > 1126`
  assertion passes (**ocupilot-b-ci**).
- "`alerts-log.browser-spec`'s row-height test is left unfalsifiable at its origin."
  `.ocu-log-row` is one global rule serving both screens, so pinning its declaration once covers
  both; a second copy adds no discriminating power.
- "The patch omits most of `Test/WireSecurityRead.cls`." The reviewed diff carries all three of
  its hunks, the new test and `ConsoleLogSince` included.
- "Clear leaves the search narrowing the rows, so AC5's 'every row returns' is false." Clear is
  the severity filter's; the search is a separate `input type="search"` with its own affordance.
- "`ShellState.showArea` overwrites a persisted side-bar preference." `showArea` is the shell's
  own API, already the locator bar's, and AC8 *requires* the bar shown — by design.


## Design Notes

**Governing ADs (Rule 6):** AD-1, AD-5, AD-8, AD-9, AD-12, AD-13, AD-21, AD-26, AD-29, AD-35,
AD-36, AD-39, AD-43 (the roster this screen does not join), AD-44, AD-48.

**Why Clear lands here rather than at the decision sheet.** DW-1109 stands `escalated
owner=burndown` with two options: build a shared shell command-bar control, or amend AC7 and
`EXPERIENCE.md:367` down to the chip toggle. Both were priced against a *shell* control. This
screen's command bar **is** `.ocu-log-viewer-bar` — 6.13 put the search, both jump controls and the
Raw toggle there — so Clear is one `button-text` beside the chips and one strings row, which drops
the fix risk from high to low and meets `epics.md` 6.14 AC4 as written. Nothing in
`shell/command-bar.ts` changes.

**DW-1101 is a second root cause, not the same fix.** The DW-1025 guard is about a caller who
*cannot* delete; DW-1101's rows belong to `_SYSTEM`, who can (measured). The evidence line above
locates it at `AdminPort.cls:361`: a queued task whose 202 or `Location` the parse does not match
is never awaited and so never forgotten, which is also why no fault was logged. That is a real
defect in the async dispatch, not in the delete — out of this story's shape, which is a viewer plus
one guard in the same method. Re-owned with the residual named; this story does not close it.

**Consumes (Rule 2):** `LogSourcePort.Page` / `Rows` and `LogPage.Handle` (Epic 2, Story 2.11),
`Screen/Read` + `Registry` and the `logsource` source port (Epic 2, Story 6.13), the shared
`log-viewer` page, store, parser, chips and controls (Story 6.13), `Screen.Gate`,
`Kernel.Fault.LogRaw`, `Api.Response` / `Api.Error`. **Consumed-by (Rules 1, 2):** the shell's
fault banner (AC8, in this story), Story 11.2 (explains a row through `logs.messages.read`),
Story 1.12's Home suggested view.

**Ledger dispositions.** Referenced, not re-filed.

| Entry | Disposition here |
|---|---|
| DW-148 | **resolved** — AC8, together with the twin defect that the control opened alerts.log |
| DW-278 | **resolved** — this screen declares `%Admin_Operate:USE` alone; `Area.cls` untouched, the union's accepted false denial stands (owner, 2026-09-14) |
| DW-1025 | **resolved** — AC9's guard in `ForgetTask` |
| DW-1100 | **resolved** — the `logsource` declaration alone; `Read.cls:263-266` is endpoint-generic, so no source kind and no `Screen/Tool` file |
| DW-1101 | **re-owned**, residual at `AdminPort.cls:361` (see above) — not the DW-1025 fix |
| DW-1103 | **resolved** — AC6 seeds `messages.log` through the vendor's own writer at all five levels, which is what the entry says this story can do |
| DW-1109 | **resolved** — AC5, in the viewer's own bar |
| DW-1119 | referenced; `smoke.sh`'s unquotable failure line is untouched here |
| DW-1073, DW-1074, DW-1078, DW-1079, DW-1080, DW-1090, DW-1093, DW-1098, DW-1099, DW-1102, DW-1110, DW-1116, DW-1118 | declined — none is reachable from this footprint. DW-1110's fix is one line in `app.ts`, which this story may not edit; DW-1102 needs an owner decision on publishing two control names |

**What this story leaves to the burn-down gate.** DW-1101's residual (the unawaited 202),
DW-1110 (`LogViewerStore` absent from `app.ts`'s sign-out teardown, AD-8), DW-1102 (no published
names for next/previous), DW-1117 (`alertLogRecentUnavailable` rendered by nothing), DW-1119
(`smoke.sh`'s unnamed failing check), DW-1099, DW-1090, DW-1079, DW-1078 and DW-1074; plus
DW-1080's charter and DW-1116's FR-76 hand-off, which are the user's at the decision sheet.

## Verification

**Commands** (all from the worktree root unless noted; slot B is `ocupilot-slot-b` on 52775, the
throwaway `ocupilot-b-ci` on 52777):

- `uv run scripts/check-objectscript.py` — 0 problems.
- `cd ui && npm run build` — the six `prebuild` checkers pass.
- `cd ui && npm test` — the node suite then the vitest run, 0 failed.
- `node tools/ci-runner.mjs --container ocupilot-b-ci` against a throwaway brought up **after the
  last edit** — 0 failed, 0 probe leftovers, 0 overlaps.
- `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci npm run test:browser`,
  after `npm run build` and `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`.
- `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` — `messages`
  among the passes; zero executed checks is a failure, never a pass.
- `bash scripts/lint-docs.sh` — clean.

**Mutations (Rule 19) — one per AC. Apply, observe red, revert, confirm the tree byte-identical.**
An ObjectScript mutation counts only after the whole tree is recompiled; a client mutation only
after `npm run build` and a `docker cp` of the bundle.

- AC1 — `mutation:` drop the `'logs/messages'` entry from `log-viewer.page.ts`'s `SOURCES` map →
  `log-viewer.spec.ts`'s AC1 path-equality assertion red, reading `/api/ocupilot/logs/alerts`
  (observed at code review). **Corrected**: the line read "drop `maxBytes`'s default clamp so the
  store requests the file's `size`", and no such clamp exists on the client — the store sends only
  `''` or `?offset=…&identity=…`, and the window is bounded by `LogSourcePort.DEFAULTMAXBYTES` on
  the server, which `Test/LogSourceWire.TestAPageNeverExceedsTheCap` pins.
- AC2 — `mutation:` change the descriptor's `read.source.endpoint` to `alerts` →
  `Test/ReadTool.cls`'s `logs.messages.read` row-source assertion red.
- AC3 — `mutation:` drop the `pIdentity '= tIdentity` arm from `LogSourcePort.cls:522` →
  `Test/LogSource.cls`'s rotation-restart assertion red.
- AC4 — `mutation:` `.ocu-log-raw`'s `white-space: pre` → `pre-wrap`, rebuilt and redeployed →
  `messages-log.browser-spec.mjs`'s no-wrap assertion red (observed). Removing the declaration
  outright is **not** a mutation: `pre` is the UA default for a `<pre>`, so the block still does
  not wrap and the spec stays green.
- AC5 — `mutation:` make Clear a no-op (leave `chipValue` set) → `log-viewer.spec.ts`'s
  clear-restores-every-row assertion red.
- AC6 — `mutation:` `--ocu-log-row-height: 32px`, rebuilt and redeployed →
  `messages-log.browser-spec.mjs`'s height assertion red over every measured row.
- AC7 — `mutation:` add `%DB_IRISSYS:READ` to `LogSourcePort.MESSAGESPAIRS`, recompiled in the
  throwaway → `Test/LogSourceDenial.cls`'s served assertions red.
- AC8 — `mutation:` drop the `showArea` call from `openMessagesLog` →
  `fault-banner.spec.ts`'s side-bar assertion red; and revert the screen resolution to
  "first `log-entry` screen" → the destination assertion red.
- AC9 — `mutation:` remove `ForgetTask`'s privilege guard, recompiled in the throwaway → the
  `AdminPort` test's "no `<PROTECT>` logged for an unprivileged caller" assertion red
  (**observed at code review, twice**: `Test/AdminPortForget`'s first leg reddens on
  `ocupilot-slot-b` with leg 2 green, and `Test/WireSecurityRead`'s sweep reddens on
  `ocupilot-b-ci` carrying the vendor's own
  `<PROTECT>%DeleteData+38^%Api.Admin.Endpoints.Security.Audit.RecordListTask.1`).

**Mutations added by the review pass** (each applied, observed red, reverted, tree confirmed
byte-identical):

- `Test/Smoke.cls`'s two roster assertions — `mutation:` rename `messages` to `messagesx` in
  `Install/Smoke.cls`'s name list → both roster assertions red on `ocupilot-b-ci`.
- `log-viewer.spec.ts`'s every-log-viewer-reads-its-own-file leg — `mutation:` drop the
  `'logs/messages'` entry from `SOURCES` → red naming the fall-through to alerts.log.
- `log-viewer.spec.ts`'s AC5 focus assertion — `mutation:` drop the `focus()` call from `onClear`
  → red reading `<body>`.

**Manual checks:**

- `iris_server_profiles` reports `ocupilot-slot-b` on 52775 before any MCP call in the pass.
- `docker exec <throwaway> grep -c PROTECT /durable/iris/mgr/messages.log` reads 0 after the
  ObjectScript sweep, including its denial classes.

## Auto Run Result

Status: done
Blocking condition: none

Implemented on Opus, falsified by an independent QA pass and reviewed on Opus with four layers. QA found AC6's rendered-height assertion could not distinguish `height` from `min-height`, because every log cell is `nowrap` with `overflow: hidden`, and pinned the rule's declaration instead. The review then found three more assertions that could not fail: two smoke roster lines (`messages` is a prefix of `messageslog`), an unmapped `log-viewer` route silently rendering alerts.log through the `SOURCES[route] ?? ALERTS_SOURCE` fallback -- DW-148 one layer down, and live only because this story adds a second log screen -- and Clear removing itself while holding focus, against the Accessibility Floor's focus-destination rule. Six ledger entries closed by this story's work (DW-1100, DW-1025, DW-148, DW-1109, DW-278, DW-1103) and DW-1138 closed by the lead's planning amendment; DW-1136, DW-1137 and DW-1101 go to the burn-down gate.
