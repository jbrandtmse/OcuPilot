---
title: 'Story 16.20: Older messages.log files'
type: 'feature'
created: '2026-09-26'
status: 'done'
baseline_revision: 'bdaff16aaf1b217aef326b13b13e47b213b84fb6'
baseline_commit: 'bdaff16aaf1b217aef326b13b13e47b213b84fb6'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-16-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The messages.log viewer shows only the current file. When the instance rotates it (at `MaxConsoleLogSize`), everything before the rotation is readable only from a shell on the server. This is Community Idea DPI-I-966. Separately, the viewer never publishes its lines to its screen store, so a typed turn's screen context on messages.log carries no rows today (Story 11.2's review measured `rowsSent` 0).

**Approach:** `LogSourcePort` gains a bounded list of the rotated files in the manager directory. Its `messages` page accepts one rotated file name, checked against the rotation pattern, under the same gate, cursor and identity it already uses. The viewer adds a file choice, carries the chosen name in its address as `?file=`, and publishes the lines it shows into its screen store. Screen context and "Explain this entry" then work on whichever file is open.

## Boundaries & Constraints

**Always:**

- **Name, never path (AD-21 named case, Design Notes).** A file is named by `file`, a single segment matching `^messages\.old_[0-9]{8}(_[0-9]{1,6})?$`. It is resolved under `ManagerDirectory()` on every call and must still sit directly in that directory after normalization (precedent: `Area/WebApp/Location.cls:34-60`). An absent or empty `file` means `messages.log`. Any other value is refused 400 `LOG.FILE`, including `messages.log` itself, a path, `..`, or a `file` on the alerts route. The refusal comes after the gate and before any filesystem touch, and no refusal echoes a path.
- **Exactly messages.log's privilege (AD-8, AD-29).** The list and the older-file page are both gated on `MESSAGESPAIRS` (`%Admin_Operate:USE`) through the existing `Gate`, first, before any filesystem touch. There is no new pair.
- **Paging is unchanged.** An older file pages through the same `Page` path as messages.log: tail first, then Load newer from `offset` and `identity`. The identity is the SHA-256 of the file's first line (`LogSourcePort.cls:1746`), and a restart happens on an identity mismatch or an offset past the end. Search, chips, Raw and Explain are unchanged.
- **The list** is `GET /api/ocupilot/logs/messages/files` and answers `{source, files: [{name, size, modified}], truncated}`.
  - Regular files only: the pattern above, plus `messages.log`.
  - Order: `messages.log` first, then last-modified descending, with name descending as the tie-break.
  - At most 1,000 entries, reporting a cut.
  - `modified` is ISO-8601 UTC (`GetFileDateModified(path, 1)`).
- **Address.** `file` is a screen-state query parameter beside `ns` (`core/navigation.ts:619-647`). `withQuery` already drops it when navigating to another screen.
  - The page reads `file` when it is constructed and on every `NavigationEnd` (precedent: `database-details.page.ts:231`).
  - Choosing a file navigates to the same route, merging `file` (removed for messages.log) and keeping `ns`.
- **Screen context (AD-24).**
  - After every read, the viewer publishes its lines into its `ScreenStore` through `applyTick` as `{time: stamp, severity, text}`, the declared `context.fields`, as `error-log.page.ts:880` does. This applies to alerts.log too, since the page is shared.
  - The panel's existing `assembleScreenContext` caps and narrows the rows. Nothing in the panel changes.
- **The file choice is messages-only.** alerts.log renders no choice and issues no list request (Story 16.8 reuses this page).
- **Copy** comes from the Fixed-strings row in Design Notes, verbatim.

**Never:**

- No new tool, criterion or governance key; `Kernel/Governance/Gate.cls` untouched. `logs.messages.read` keeps reading messages.log.
- No change to the `LogMessageViewer` descriptor XData, `screens.generated.ts`, `structural-baseline.json`, `panel.ts`, or the agent's navigation.
- No glob or listing beyond the one pattern; no path, directory or other file name reaches the port from a caller.
- Stay off Epic 14's hunks (Design Notes). Nothing of Epic 17's is edited.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Open | messages.log viewer; manager dir holds messages.log and rotated files | choice lists messages.log, then rotated files newest first, each "`<name> · <size> KB · <modified>`"; rows are messages.log's tail | list refused → no choice rendered; rows as today |
| Choose older | pick `messages.old_20260926_5` | URL `/ocupilot/logs/messages?ns=HSCUSTOM&file=messages.old_20260926_5`; `GET /logs/messages?file=…`; that file's tail; search "n of N", chips, Raw, Load newer as today | none |
| Shared link | a fresh tab opens that URL | same file opens and the choice shows it | none |
| Back to current | choose messages.log | `file` leaves the URL; messages.log's tail | none |
| Context | typed turn / Explain on an older row | `screen_context` rows are that file's lines (cap applied); Explain sends that one line | none |
| Removed since | URL names a well-formed name no longer on disk | 404 `LOG.ABSENT` → "That file is no longer in the manager directory."; the choice lists the name alone, selected | no empty state |
| Bad name | `file=` `/etc/passwd`, `../messages.log`, `messages.log`, `messages.old_2026`, `messages.old_20260101_1.bak`, `alerts.log` | 400 `LOG.FILE`, no filesystem touch, no path echoed; the page shows the generic refusal | — |
| Wrong source | `GET /logs/alerts?file=messages.old_20260101` | 400 `LOG.FILE` | — |
| No privilege | caller lacks `%Admin_Operate:USE` | `/files` and `?file=` both 403 naming it, no filesystem touch | holder of that pair alone is served |
| Decoys | a directory named `messages.old_20260102`, `messages.log.1`, `alerts.old_20260101` | not listed | — |
| Many | 1,001 matching files | newest 1,000, `truncated` true | — |

</intent-contract>

## Code Map

Server (`src/OcuPilot/`):

- `Port/LogSourcePort.cls`:
  - class doc :1-45, which says a caller names no file (correct it at origin);
  - `MESSAGESFILE` :66, `MESSAGESPAIRS` :78, `FileFor` :427, `ManagerDirectory` :439 and the seams `FileExists` :464, `OpenStream` :470;
  - `Page` :508-620, whose order is enum, gate, maxBytes, cursor, resolve, open, identity, window;
  - `Rows` :622, which calls `Page` with no file;
  - `Gate` :1702, `Resolve` :1711-1744, `Identity` :1746, `Refuse` :1897.
  - Epic 14 appends `SnippetForm`/`Snippet` after `Fail` (:1907-1914). Add new methods after `Resolve`, never at the end.
- `Api/LogPage.cls:29` `Handle`: reads `offset`/`maxBytes`/`identity`; its class doc says no caller names a file.
- `Api/Router.cls`: UrlMap :117-122 (`/logs/messages` :122); `LogMessages` :697-704, whose doc says the same. Epic 14 edits :129 and :748-756.
- `Api/Error.cls` LOG codes :300-372. Append after `LOGMAXROWS` :372.
- `Area/WebApp/Location.cls:34-60` is the containment precedent; `Install/Installer.cls:2407` is the `%File:FileSet` precedent (filter `Type` = `F`).
- Tests:
  - `Test/LogSourceFixture.cls` seams and touch counter :137-149;
  - `Test/LogSource.cls` scratch-dir pattern (`<mgr>ocupilotlogprobe/`, :41-160);
  - `Test/LogSourceWire.cls:188-205`, which asserts `file=/etc/passwd` is ignored and becomes a refusal;
  - `Test/LogSourceDenial.cls` principals :41-120, legs :205-320;
  - `Test/LogSourceRotation.cls:45-57`, the arming precedent for `OCUPILOT_ALLOW_LOG_ROTATION`;
  - `Test/EndpointCoverage.cls:111` (Epic 14 edits :118);
  - `scripts/ci-throwaway.sh:189` roster (Epic 14 edits :208, :226, :297).

Client (`ui/src/app/`):

- `areas/logs/log-viewer.store.ts`: `LogViewerSource` :12, `MESSAGES_SOURCE` :22, `setSource` :133, `open` :189, `read` :206-255 (ABSENT branch :225).
- `areas/logs/log-viewer.page.ts`:
  - `SOURCES` :44;
  - bar :82-114, where the choice goes after the search;
  - refusal :132-136; constructor :237-258;
  - `refusalMessage` :355; `emptyTitle` :379.
- `areas/logs/error-log.page.ts:358,880`: the `ScreenStores` and `publishRows` pattern.
- `areas/logs/log-line.ts`: pure helpers (tested by `log-line.spec.ts`).
- `areas/tasks/upcoming.page.ts:91` and `styles/_components.scss:2736`: `ocu-criteria-select`, to reuse without new SCSS.
- `core/strings.ts`: append before `} as const` :2961. The `:1951` citation `EXPERIENCE.md:618` becomes `:619`. Epic 14 edits :166.
- Specs:
  - `areas/logs/log-viewer.spec.ts` (`:20` tail path, `:377` SOURCES mutation) and `log-line.spec.ts`;
  - `ui/browser/messages-log.browser-spec.mjs`, the docker-exec seeding and `assertThrowaway` pattern;
  - `explain-entry.browser-spec.mjs` legs (a) :176-201 and `screen_context` capture :122-167;
  - `impact.browser-spec.mjs:226-256`, the DW-1337 pattern.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Port/LogSourcePort.cls`:
  - add `ROTATEDFORM`, `FILESCAP` 1000 and `ROTATEDSOURCE` (= `MESSAGESKEY`);
  - `Page` gains a trailing `pFile As %String = ""`, checked after the cursor step (`LOG.FILE` 400);
  - `Resolve` takes the file and applies the containment check;
  - new `Files(pSource, Output pResult, Output pHttpStatus, Output pFault)`, which runs enum, then gate, then enumeration, through one new overridable enumeration seam;
  - correct the class doc sentence.
- `src/OcuPilot/Api/Error.cls`: `LOGFILE = "LOG.FILE"` with its doc.
- `src/OcuPilot/Api/LogPage.cls`: pass `%request.Get("file","")`; new `HandleFiles(pSource)`; correct the class doc.
- `src/OcuPilot/Api/Router.cls`: `<Route Url="/logs/messages/files" Method="GET" Call="LogMessageFiles"/>` before :122. Add the thin `LogMessageFiles` after `LogMessages` and correct that method's doc.
- Tests:
  - `src/OcuPilot/Test/LogSourceFixture.cls`: override the enumeration seam and count one touch.
  - New `src/OcuPilot/Test/LogSourceFiles.cls`: the port over a scratch dir holding messages.log, three rotated files written with a `Hang` between them, and the matrix decoys. It covers list order, the decoys, the cap (via the seam), every bad name, zero touches before the gate and before the name check, an older file's page and cursor, and `Rows` unchanged.
  - New `src/OcuPilot/Test/LogOlderFilesWire.cls`: HTTP on both literal routes. It is armed by `OCUPILOT_ALLOW_LOG_ROTATION` and writes `messages.old_20000101_4242` with head-format lines into the real manager dir, removed in `OnAfterAllTests`. It covers the listed entry's size and modified, a page of that file, the bad names as 400 `LOG.FILE` with no path in the body, and one envelope.
  - `src/OcuPilot/Test/LogSourceWire.cls:194`: drop `file=/etc/passwd` from the ignored set.
  - `src/OcuPilot/Test/LogSourceDenial.cls`: legs for `/files` and `?file=messages.old_20000102` (never written). Without the pair, both answer 403 naming it; with `%Admin_Operate:USE` alone, `/files` answers 200 and the file answers 404 `LOG.ABSENT` (past the gate).
  - `src/OcuPilot/Test/EndpointCoverage.cls`: a probe row for `/logs/messages/files` after :111.
  - `scripts/ci-throwaway.sh:189`: `# classes: LogOlderFilesWire, LogSourceRotation`.
- `ui/src/app/areas/logs/log-viewer.store.ts`:
  - `LogViewerSource.filesPath?` set on `MESSAGES_SOURCE`;
  - add `file()`, `files()`, `filesLoaded()` and `gone()`;
  - `setSource(source, file)` resets when either changes;
  - `read` appends `file=`;
  - `loadFiles()`;
  - `LOG.ABSENT` with a named file sets `gone`; without one, keep today's empty state.
- `ui/src/app/areas/logs/log-line.ts`: `fileOptionText({name, size, modified})`, where size is KB rounded up with `en-US` grouping and modified is browser-local `YYYY-MM-DD HH:MM`.
- `ui/src/app/areas/logs/log-viewer.page.ts`:
  - the `select.ocu-criteria-select` with `aria-label` `logViewerFileLabel`, shown when `filesPath` is set and the list has loaded, with a name-only option when the URL's file is not listed;
  - the URL `file` read and navigate;
  - `publishRows` into `inject(ScreenStores)`;
  - the refusal `logViewerFileGone`;
  - Refresh re-reads the list and the window.
- `ui/src/app/core/strings.ts`, the EXPERIENCE.md row and the edits in place (Design Notes), and `README.md` (Design Notes).
- Client tests:
  - `log-viewer.spec.ts`: options and order, choose/URL, shared URL, back to current, gone, alerts has no choice or request, and rows published and replaced.
  - `log-line.spec.ts`: `fileOptionText`.
  - New `ui/browser/messages-log-files.browser-spec.mjs`: seed and remove its fixture on `ocupilot-ci`. It covers AC1 and AC2 through the UI and the shared link, and the DW-1337 walk at wide light, narrow light and wide dark with the choice open on the older file.
  - `explain-entry.browser-spec.mjs`: leg (d), which seeds and removes the same fixture on `ocupilot-ci`: an older file's row Explain sending that line, and a typed turn's `screen_context` rows coming from that file.

**Acceptance Criteria:**

- **AC1.** Given the messages.log viewer on `ocupilot-ci` with a seeded rotated file, when it opens, then the file choice lists messages.log and every rotated file, newest first, each with its size and last-modified time.
- **AC2.** Given an older file is chosen, when it loads, then it pages, searches and filters as messages.log does, the address carries `file=<name>` and reopens that file in a fresh tab, and both a typed turn's screen context and "Explain this entry" carry its lines.
- **AC3.** Given any `file` value reaches the server, when it is resolved, then only a rotated-pattern name directly in the manager directory is read, everything else is refused 400 `LOG.FILE` before any filesystem touch, and a caller without `%Admin_Operate:USE` is refused 403 on the list and on the file, exactly as on messages.log.
- **AC4.** Given `README.md`, when this story completes, then Community ideas lists DPI-I-966 among the ideas OcuPilot implements. The Open Exchange listing is Epic 17's and is handed off (Design Notes).
- **AC5 (Integration).** Given `ocupilot-ci` with a seeded rotated file, when the messages.log viewer (the consumer) reads `GET /logs/messages/files` and `GET /logs/messages?file=`, then it renders the choice and the older file's rows in both themes, passes the DW-1337 structural gate with no new allowance, and the bundle stays under 1900 kB (re-base under DW-1166 if crossed).

### Review Findings

Code review 2026-09-27 (full-opus; Blind Hunter, Edge Case Hunter, Verification Gap, Acceptance Auditor): 34 raw findings, 26 entries, no high or medium. Lead's points 1-5 hold: published rows are the declared `{time, severity, text}` with `secretFields` empty, capped by `assembleScreenContext` and again on the instance; `file` reaches the filesystem only through `Page`'s pattern check (`Rows`, `logs.messages.read` and Explain pass none); containment by name holds (symlink case DW-1726); Epic 14's hunks untouched; README's DPI-I-966 title and Community Opportunity status checked on ideas.intersystems.com, nothing of Epic 17's edited.

- [x] [Review][Patch] `gone` survived a Refresh, so the removed-file refusal masked the next read's rows or its real fault [ui/src/app/areas/logs/log-viewer.store.ts:302]
- [x] [Review][Patch] Load newer's appended lines were never checked in the published screen store [ui/src/app/areas/logs/log-viewer.spec.ts:648]
- [x] [Review][Patch] `explain-entry` leg (d), the only real-browser pin of AC2's screen-context clause, had no `mutation:` line [_bmad-output/implementation-artifacts/spec-16-20-older-messages-log-files.md, Verification]
- [x] [Review][Patch] `LogMessageViewer`'s doc said the screen and its read are "the same window" with nothing added; it now names the `?file=` case [src/OcuPilot/Screen/Descriptor/LogMessageViewer.cls:3]
- [x] [Review][Patch] `LogSourceFiles`' header said the manager directory is never written while it creates `ocupilotfilesprobe/` there [src/OcuPilot/Test/LogSourceFiles.cls:10]
- [x] [Review][Defer] symlink/directory/FIFO with a rotated name [src/OcuPilot/Port/LogSourcePort.cls:1782] — deferred: DW-1726 wontfix-theoretical
- [x] [Review][Defer] the choice navigates per change event (arrow keys on a closed select) [ui/src/app/areas/logs/log-viewer.page.ts:367] — deferred: DW-1727 wontfix-accepted
- [x] [Review][Defer] older-file context names no file while `logs.messages.read` reads messages.log [ui/src/app/areas/logs/log-viewer.page.ts:333] — deferred: DW-1728 by-design (Decision 2)

Rejected:

- low: no `value: ''` option when the list lacks messages.log — IRIS always has messages.log; the page's own read would 404 too.
- low (spec-bound): `?file=messages.log` shows the generic refusal — the matrix's Bad name row requires it.
- low: leg (d) seeds before `signedInAt`'s try — the other legs' pattern; residue only on a throwaway.
- false: `<INVALID OREF>` in `LogSourceFiles`/`LogSourceDenial`/`LogOlderFilesWire` when a page fails — the test still errors red.
- low: DST fall-back could misorder local option text — CI and throwaway browsers run UTC.
- low: an older file with a failed list shows no choice — list and page share one gate; only a transient list failure reaches it.
- low: client ignores `truncated` — the spec asks nothing of the client; IRIS purges long before 1,000.
- low: option text forms (empty `modified`, grouping, name-alone) — the Tasks and matrix specify them.
- low: Auto Run Result's counts differ from its triage log — the fix edits the spec under review.
- low: `ROTATEDSOURCE` repeats `"messages"` — no caller diverges; a rename reddens `LogSourceFiles`.
- low: `GetFileDateModified` per entry before the cap — about 40 files on a real instance.
- low: the alerts `?file=` legs check less than the messages legs — one `FileRefusal` path serves both.
- low: `filesGeneration` and a failed Refresh list are untested — guards, not AC behavior.
- low: `Files`' unreadable-directory branch is untested — the manager directory is IRIS's own.
- false: `LogSourceWire`'s "source/file/path" label is stale — `filename` is still sent.
- false: the alerts no-choice case pins two guards together — defense in depth, no defect.
- false: the select's label reuses `databaseVolumeColumnFile` — documented departure; `strings.test.mjs` refuses a duplicate value.
- false: spec `done` against sprint `review` — the review's sprint sync sets it.

## Spec Change Log

- 2026-09-26, lead, spec gate: the AD-21 named case (the rotated messages files) written into the spine exactly as recommended under Design Notes (Rule 20, light path). No other change.

## Review Triage Log

### 2026-09-26 — Review pass

- verdicts: 16 findings — high 0, medium 4, low 8, false 3, maybe-false 1
- findings:
  - `[low]` `[reject]` `modified`'s UTC flag is unfalsifiable on a UTC host — the code passes `GetFileDateModified(p, 1)` (`%Library.File` `utc` argument) as the spec requires; the throwaway and CI images are UTC, so a leg cannot redden without a non-UTC instance; the fix adds environment machinery for a correct line.
  - `[medium]` `[patch]` the cap is never exercised with `messages.log` in the listing — added a third leg to `LogSourceFiles.TestTheListIsCappedAndSaysSo` (messages.log + 1,000 rotated = 1,000 entries, truncated); mutation recorded.
  - `[low]` `[reject]` `DirectlyIn` is unreachable — every name reaching `Resolve` has matched `ROTATEDFORM` whole (no `/`, no `..`), so no input can make it return 0; it is the spec's post-normalization containment kept as defense in depth (wontfix-theoretical; real only if the pattern is widened).
  - `[medium]` `[patch]` alerts.log's published rows are untested — added "alerts.log publishes its lines into its own screen store too" to `log-viewer.spec.ts`; mutation recorded.
  - `[low]` `[patch]` AC5's walk leg had no mutation line — applied the `aria-label` removal, rebuilt, redeployed, observed AC5 red, reverted, green; line recorded.
  - `[low]` `[reject]` the select's name reuses `databaseVolumeColumnFile` instead of a `logViewerFileLabel` key — `ui/tools/strings.test.mjs` refuses duplicate values and a key carries one citation, so a second "File" key cannot exist; both published labels are "File".
  - `[medium]` `[patch]` (intent) the cap's reading R1a (messages.log counted) was unpinned — same root cause and patch as the cap row above.
  - `[low]` `[reject]` (intent) the tie-break is plain string order (`_2` before `_10`) — the spec says "name descending"; two rotations sharing one modification second is rare and a natural sort adds a comparator.
  - `[false]` `[reject]` (intent) `README.md` edited against "nothing of Epic 17's" — the README edit is AC4 itself; Epic 17's deliverable is the Open Exchange listing, untouched.
  - `[maybe-false]` `[reject]` (intent) `?file=` naming a directory with a rotated name is not refused cleanly — would need `%File.Exists` on a directory checked on the instance; if true it is low: IRIS never creates such a directory and the outcome is a failure envelope with no content.
  - `[false]` `[reject]` (intent) Refresh re-reading the list is unstated — the spec's Tasks list names it ("Refresh re-reads the list and the window").
  - `[medium]` `[patch]` (intent) alerts.log screen context untested — same root cause and patch as the alerts row above.
  - `[low]` `[reject]` (intent) offset-past-the-end restart not exercised with `file` — the named file changes only the resolved path; the restart branch is shared and pinned by `LogSource`.
  - `[low]` `[reject]` (intent) browser leg does not click Load newer or Raw on an older file — Load newer with `file` is pinned in `log-viewer.spec.ts`; Raw reads the same loaded lines regardless of file.
  - `[low]` `[reject]` (intent) the bad-name page refusal has no browser leg — the 400 is pinned over the wire (`LogOlderFilesWire`) and the page side in `log-viewer.spec.ts` with a recorded mutation.
  - `[false]` `[reject]` (intent) decoys and zero touches pinned at the port, not the wire — the port owns both guarantees and the wire calls the same `Files`/`Page`; no divergent path exists.

## Design Notes

**Spine change for the lead (AD-21 named case):** append to AD-21's first paragraph, after the task-output case:

> The fourth is an older console log [AMENDED 2026-09-26, Story 16.20 spec gate, Rule 20]: the messages.log viewer names one rotated file, never a path - a single segment matching `^messages\.old_[0-9]{8}(_[0-9]{1,6})?$`, the name IRIS gives `messages.log` when it rotates it (measured on `ocupilot-ci`: `messages.old_YYYYMMDD`, then `_1`, `_2` and on within a day) - resolved under `<ManagerDirectory>` computed at call time and never cached, required to sit directly in that directory after normalization, and read through `LogSourcePort`'s `messages` source under that source's own gate, cursor and identity, so it needs exactly `messages.log`'s privilege. The same port lists the files the pattern matches, with their size and modification time, newest first and bounded. The name travels as the `file` query parameter of the viewer's address and of `GET /logs/messages`; any other value, `messages.log` itself included, is refused `LOG.FILE` before the filesystem is touched, and no refusal echoes a path.

No other AD changes. **Why a query parameter and not an AD-13 segment:** the descriptor's id is `none` because a log line is not an entity (AD-13), and a file is a view of the one screen, not an entity id. A path segment would change the descriptor, the mirror, `screenForUrl` and the entity context. `navigation.ts` already treats every parameter but `ns` as screen state (AD-44), and AD-11's "criteria never in the URL" governs the agent's navigation directive, not a person's choice. Plan-stage evidence: `ocupilot-ci` holds 40 rotated files (`messages.old_20260922_3` to `messages.old_20260927`, 2.6-3.4 MB, `MaxConsoleLogSize=5`), each opening on a distinct "Console logging file switched" line. The oldest are pruned (inference: the purge task). The test fixtures are written only on `ocupilot-ci` and removed.

**Fixed strings row**, appended after EXPERIENCE.md:577 as the new :578:

> `| "File" · "<name> · <size> KB · <modified>" · "That file is no longer in the manager directory." | the messages.log viewer's file choice (Story 16.20, DPI-I-966): the select's accessible name; each option, messages.log first and then the rotated files newest first, <size> in kilobytes rounded up and <modified> the last-modified time in the browser's local time as YYYY-MM-DD HH:MM; and the refusal shown in place of rows when the file the address names has been removed [ADDED 2026-09-26 - Story 16.20] |`

- The keys are `logViewerFileLabel`, `logViewerFileOption` and `logViewerFileGone`, with `·` written as `·`.
- Move every citation of a line of 578 or later by one; today that is only `strings.ts:1951`. `npm run test:tools` finds any other.
- Edit :85 (the messages.log viewer row) and :619 (the log-viewer pattern) in place, adding "and the older rotated files through a file choice (Story 16.20)".

**README (footprint extension, not contended).** Change "two ideas" to "three ideas" (:346) and add a bullet after :352: "[DPI-I-966](https://ideas.intersystems.com/ideas/DPI-I-966), **Option to show older message.log in IRIS SMP:** the `messages.log` viewer opens every older messages file the instance keeps, with the same search, filters and agent explanations." Remove the roadmap line :377, and add "and its older files" to the Logs row :114.

**Open Exchange sentence for the lead to hand to the orchestrator (Epic 17, owner):** "DPI-I-966, Option to show older message.log in IRIS SMP: the messages.log viewer opens every older messages file the instance keeps in its manager directory, newest first with size and time, with the same search, filters and agent explanations."

**Decisions.**

1. Older files open on their tail, as messages.log does. The viewer still has no page-older control.
2. The agent's read tool stays on messages.log (no new criterion). Older lines reach the model through screen context and Explain only, and the screen context names no file.
3. A switch of namespace keeps what the switcher keeps today. `file` is screen state.

**Governing ADs:** AD-21, AD-29, AD-8, AD-13, AD-44, AD-24, AD-36, AD-11, AD-12, AD-39, AD-19, AD-20, AD-43, AD-47, AD-5, AD-35 (unchanged), AD-48 (not touched: the `^ERRORS` path is untouched).

**Integration ACs.** Consumes: `LogSourcePort.Page`'s gate, cursor and identity (6.12/6.14); `ExplainEntry` (11.2); `ScreenStore` with `assembleScreenContext` (4.11); `structural-walk.mjs` (15.6). Consumed-by: none in this story. Story 16.8 extends the same page and store and must keep the choice messages-only (inference). Story 16.9 lists sources, and rotated files are not a source, so it does not consume the list (inference until its plan).

**Concurrent epics.** Epic 14's hunks, named in the Code Map (`LogSourcePort` after `Fail`, `Router` :129 and :748-756, `EndpointCoverage` :118, `ci-throwaway.sh` :208/:226/:297, `strings.ts` :166, `EXPERIENCE.md` :269/:273/:275, `panel.ts`), are all avoided. Story 14.3's sanitizer is unbuilt (backlog). It would act server-side on model-bound content and would cover these rows with no change here (inference). Epic 18 has no branch yet, and Epic 23 has no source diff.

**Ledger and governance.** The inbox is empty. DW-118 is declined because Story 15.6 resolved it. DW-1110 (store teardown) stays with 16.8; the file list survives a sign-out as the rows do today. No write tool is added and `Gate.cls` is untouched.

## Verification

**Commands:**

- `cd ui && npm run test:tools` (loop) -- green, including `strings.test.mjs` and `ci.test.mjs`. Mutation: drop `LogOlderFilesWire` from the `ci-throwaway.sh` roster, and `ci.test.mjs` goes red.
- `cd ui && npx ng test --include src/app/areas/logs/log-viewer.spec.ts --include src/app/areas/logs/log-line.spec.ts` (loop) -- green. Mutations:
  - the store omits `file=`, and the choose case goes red;
  - drop `publishRows`, and the published-rows case goes red;
  - render the choice for alerts, and the alerts case goes red.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.LogSourceFiles`, then `LogOlderFilesWire`, `LogSourceWire`, `LogSourceDenial`, `LogSource`, `LogSourceRotation` and `EndpointCoverage`, one at a time (loop) -- green. Mutations:
  - drop the pattern check, and the bad-name legs go red;
  - move the name check before the gate, and the touch or denial leg goes red;
  - sort ascending, and the order leg goes red;
  - drop the `Type` = `F` filter, and the decoy leg goes red.
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/ && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/messages-log-files.browser-spec.mjs browser/explain-entry.browser-spec.mjs browser/messages-log.browser-spec.mjs browser/alerts-log.browser-spec.mjs browser/screen-height.browser-spec.mjs browser/a11y-structural-invariants.browser-spec.mjs` (loop). These are the story's own specs plus every existing spec the shared viewer could break. Expected: green, within the structural baseline. Mutation: the page ignores the URL's `file`, and the shared-link leg goes red.
- `cd ui && npm test`, `uv run scripts/check-objectscript.py`, `bash scripts/lint-docs.sh` (once, before dev_complete) -- green; bundle under 1900 kB.
- The full ObjectScript sweep on `ocupilot-ci`, one class at a time (once, before dev_complete) -- green.

**Mutations (implement, 2026-09-26, each applied, red observed, reverted byte-identical; ObjectScript reloaded with `LoadDir` on `ocupilot-ci`, client rebuilt and redeployed):**

- mutation: store omits `file=` -> `log-viewer.spec.ts` choose, Load-newer and shared-link cases red.
- mutation: `publishRows` writes nothing -> the published-rows case red.
- mutation: `ALERTS_SOURCE` gains a `filesPath` -> the alerts case red.
- mutation: `RotatedName` drops the `ROTATEDFORM` match -> `LogSourceFiles.TestEveryOtherNameIsRefusedBeforeAnyFileAccess` red.
- mutation: the `LOG.FILE` check moved above the gate -> `LogSourceFiles.TestTheNameIsCheckedAfterTheGate` red.
- mutation: `Files` lists before the gate -> `LogSourceFiles.TestNothingIsListedBeforeTheGate` and `TestOnlyTheConsoleLogListsOlderFiles` red.
- mutation: sort ascending -> `LogSourceFiles` order, tie-break and cap legs red.
- mutation: drop the `Type` = `F` filter -> `LogSourceFiles.TestDecoysAreNotListed` red.
- mutation: `MESSAGESPAIRS` gains `%DB_IRISSYS:READ` -> `LogSourceDenial.TestTheOlderFilesMeetTheConsoleLogsOnePair` red.
- mutation: drop `LogOlderFilesWire` from the `ci-throwaway.sh` roster -> `ci.test.mjs` DW-1276 red.
- mutation: the page ignores the address's `file` -> the shared-link leg red in `log-viewer.spec.ts` and in `messages-log-files.browser-spec.mjs`.
- mutation: the store treats `LOG.FILE` as `LOG.ABSENT` -> `log-viewer.spec.ts` "a name the server refuses LOG.FILE is the generic refusal" red (matrix row Bad name, the page side).
- mutation: `Files` counts only rotated files against `FILESCAP` -> `LogSourceFiles.TestTheListIsCappedAndSaysSo` third leg red (1,001 entries).
- mutation: `publishRows` returns early for a source without `filesPath` -> `log-viewer.spec.ts` "alerts.log publishes its lines" red.
- mutation: the file choice loses its `aria-label` (rebuilt, redeployed) -> `messages-log-files.browser-spec.mjs` AC5 walk red (`select.ocu-criteria-select: no accessible name`) and AC1 red.
- mutation: `publishRows` returns at once (rebuilt, redeployed on `ocupilot-ci`) -> `explain-entry.browser-spec.mjs` leg (d) red (`rowsSent` 0, expected 3).
- mutation: `read` stops clearing `gone` -> `log-viewer.spec.ts` "a Refresh after a removed file" red.
- mutation: Load newer appends into the held array (`Object.assign`) -> `log-viewer.spec.ts` "Load newer publishes the appended lines" red.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** `LogSourcePort` lists the console log's rotated files (`Files`, gate first, one directory read, regular files matching `ROTATEDFORM`, messages.log first then newest first, cap 1,000 with `truncated`) and pages one by `file` under the `messages` gate, cursor and identity; any other name is 400 `LOG.FILE` after the gate and before any filesystem touch. `GET /logs/messages/files` is routed; the viewer shows a file choice (messages only), carries `?file=`, shows the removed-file refusal, and publishes its lines to its screen store. README lists DPI-I-966.

**Files.** Server: `Port/LogSourcePort.cls`, `Api/Error.cls` (`LOGFILE`), `Api/LogPage.cls` (`file`, `HandleFiles`), `Api/Router.cls` (route + `LogMessageFiles`). Tests: new `Test/LogSourceFiles.cls`, `Test/LogOlderFilesWire.cls`; `LogSourceFixture`, `LogSourceWire`, `LogSourceDenial`, `EndpointCoverage`; `scripts/ci-throwaway.sh` roster. Client: `log-viewer.store.ts`, `log-viewer.page.ts`, `log-line.ts`, `strings.ts` (two keys, one citation shift), `_components.scss` (one bar-sizing rule), specs `log-viewer.spec.ts`, `log-line.spec.ts`, new `browser/messages-log-files.browser-spec.mjs` and `browser/older-file-spec.mjs`, `explain-entry.browser-spec.mjs` leg (d). Docs: EXPERIENCE.md (row :578, :85 and log-viewer pattern in place), `README.md` (footprint extension).

**Departures from the spec text.** The select's name reuses `databaseVolumeColumnFile` ("File"): `strings.test.mjs` refuses a second key with the same value. One SCSS rule sizes the select in the bar (the jump buttons wrapped without it). `ownFile` on the source names messages.log's list entry.

**Review.** 16 findings: 3 patched (cap leg with messages.log, alerts published-rows case, AC5 mutation line), 13 rejected with reasons in the triage log; nothing deferred. Follow-up review: false — two medium entries were patched, both test-only additions with observed-red mutations; no unverified risk can be named.

**Verification.** `npm run test:tools` 1,546 green; `npm test` 112 files / 1,522 green, then `log-viewer.spec.ts` 37 green after the review cases; `check-objectscript` 0, `lint-docs` 0. Full ObjectScript sweep on `ocupilot-ci`: 302 ran, 285 green, 16 refused (arming), 1 known residue (`WireSecurityRead` task history, DW-1425/DW-1468); `LogSourceFiles` re-run green after the patch. Browser (rebuilt, redeployed): `messages-log-files`, `explain-entry`, `messages-log`, `screen-height`, `a11y-structural-invariants` 40/40; `alerts-log` 7/7 with `ocupilot-ci`'s `alerts.log` emptied for the run and restored (its seed lines sat outside the 64 KB tail, the DW-1190 shape on the alerts spec). Bundle 1,889,964 B, under 1900 kB, no re-base. Trial merge with `origin/OCU-1-epic14` adds no conflict beyond the three already present at HEAD.

**Residual risks.** The alerts browser spec's re-seed check still greps the whole file (it passes on CI's fresh throwaway). Open Exchange sentence for Epic 17 is in Design Notes for the lead.
