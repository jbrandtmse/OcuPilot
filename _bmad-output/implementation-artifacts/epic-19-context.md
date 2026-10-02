# Epic 19 Context: Stage 3 - System Explorer over the Atelier API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Give developers a System Explorer inside OcuPilot, built on the IRIS Atelier API. Classes and routines are already listed, viewed, compiled, deleted, exported and imported as XML, and edited with a save checked against the version it read. The rest of the stage adds search, compare and macro lookup; the SQL catalog; a query console behind a DML and DDL guard; a data grid harvested from iris-table-editor; Documatic, DocDB and SQL activity; and an agent picker with guarded agent SQL. Everything reaches Atelier through one port, `Port/AtelierPort`, in process as the signed-in user. It never handles the user's password and never modifies a vendor web application. As in the classic portal, a `%Development` holder with no administrative resource gets in. Every screen keeps the one contract earlier stages followed.

## Stories

- Story 19.1: Classes and routines, listed and viewed
- Story 19.2: Compile, delete, export and import (export and import split to 19.13)
- Story 19.3: The source editor, with ETag conflict detection
- Story 19.4: Search, compare and macro lookup
- Story 19.5: The SQL catalog browser
- Story 19.6: The query console and its DML and DDL guard
- Story 19.7: The data browser - tree, grid, filter and sort
- Story 19.8: The data browser - editing, staging and export
- Story 19.9: Documatic and DocDB
- Story 19.10: SQL activity
- Story 19.11: The agent gains guarded SQL and a picker
- Story 19.12: A %Development holder reaches System Explorer, as the classic portal allows
- Story 19.13: XML export and import

## Requirements & Constraints

- **One contract (FR-80).**
  - One descriptor declares each screen, and the screen reaches the outside through one port. The read tool's and the write tools' field lists derive from it.
  - Every agent write is a server-minted proposal with an instance-computed diff, an explicit confirmation and an agent marker. Every read is bounded and reports truncation. Every gate checks the caller's own privileges at call time.
  - Acceptance is this contract plus each catalog row's backing route. Each story's plan writes its finer criteria.
- **Backing routes still to build**, relative to `/api/atelier/v<N>/:ns`:
  - 19.4: a text search, which must use a synchronous route observed on the throwaway; `POST action/getmacrodefinition` and `getmacrolocation`; and two document reads diffed in the client. Classic pages: `%CSP.UI.Portal.RoutineCompare`, which compares two routines across namespaces and declares `%Development:USE` (read in `irissys/`); the legacy Find page (`%CSP.UI.System.FindPane`), whose gate is unread. Macro lookup has no classic page and declares that.
  - `POST action/query`, used by 19.5 (`INFORMATION_SCHEMA`, `CALL %SQL_Manager.Catalog`), 19.6 (`{query, parameters}`, `EXPLAIN`), 19.7 and 19.8 (the data browser), and 19.10 (`INFORMATION_SCHEMA.CURRENT_STATEMENTS`; cancelling a statement is Stage 4).
  - 19.9: Documatic at `/csp/documatic/%25CSP.Documatic.cls`, and DocDB at `/api/docdb/v1/:ns`.
- **The stage's own gates.**
  - `action/query` runs any statement type unguarded and applies no row limit. The guard ships with the console, and OcuPilot applies the row cap and reports truncation itself.
  - DocDB needs `%Service_DocDB` enabled. Report that requirement; never assume it.
- **The agent never authors code.**
  - No tool schema carries document text. A local file's text is a screen-only action value of at most 3,000,000 characters.
  - The editor's save is screen-only: both save tools are unadvertised and their keys ship `false`. An agent-authored save would be a later story, if the owner asks.
- **Code text reaching the model** (a search hit's line, a macro's definition) is bound by AD-11 and AD-39. It enters only as delimited tool-result content, bounded by AD-24 and passed through AD-60's sanitizer, never as instruction. Today no source text joins a tool's view, so whether hit or definition text does is a decision for 19.4's spec gate (inference).
- **Who gets in.** A caller holding neither an `%Admin_*` resource nor `%Development:USE` is refused the API and the turn. A `%Development`-only caller reaches System Explorer and is refused wherever a classic `%Developer` is.
- **Governance (AD-22).** Every new write key gets its line in `Kernel/Governance/Baseline.cls` in the same change, and every new destructive key ships disabled. From 2026-10-04 the owner decides how new keys enter the baseline. As shipped: compile `true`, delete `false`, export `true`, import `false`, save `false`.
- **New dependencies (Rule 5).** A third-party library, such as a diff, editor or grid library, is ask-first: halt for the owner before adding it. It must be vendored with no CDN, run under the content-security policy, and count toward the bundle.
- **Bundle.** The initial-bundle warning is 2,488 kB, against 2,487,199 bytes measured at 19.3, so nearly any UI addition crosses it. Re-base `ui/angular.json` and `angular-json.test.mjs` to the measured size (DW-1166). Stop and ask above 3,800 kB; the hard error is 4,000 kB.
- **Harvest limits carried knowingly (19.7, 19.8):** only single-column primary keys; the identifier pattern refuses delimited names; `rowsAffected` always reads 1; `%VID` offset paging re-reads earlier rows and runs a `COUNT(*)` per page, and a failed count shows zero rows.
- **Measure, never assume.** Take each pair set from the handler's own checks plus a purpose-built least-privileged principal on the throwaway, never `%Operator`. Read a classic page's `RESOURCE` in `irissys/`; never recall it.

## Technical Decisions

- **AD-61: the Atelier port.**
  - `Port/AtelierPort` is the only class that names an `%Api.Atelier.*` class, through parameters only. It calls route methods in the caller's process, one route at a time. The browser never calls `/api/atelier`.
  - **Gate first (AD-29).** `%Development:USE`, then READ per namespace at call time on the routines and globals databases and every database the namespace maps code from except IRISSYS. A write (compile, delete, import, save) also needs WRITE on the routines database's resource; an export needs only the read pairs. Each write tool declares the same pairs (AD-8), so a caller without one is refused by name before any port call.
  - **Version.** The port calls `v<min(N, 8)>`. Each route declares its minimum in `MINVERSIONS`, and an older instance is refused `PORT.NOTIMPLEMENTED` before any call.
  - **Stub CSP state.** `New %request, %response, %session, %SourceControl`; query parameters seeded into `%request.Data`; a body the port builds written to the stub's content stream; the namespace switched by save and restore around the vendor call only (AD-16).
  - **Capture.** An answer above about 3.6 million characters is refused `PORT.UNAVAILABLE`. `action/index` alone goes through a temporary file, because the capture killed the process with signal 11; a later route that needs the file device names itself in AD-61.
  - **Outcome from four places:** the `%Status`, `%response.Status`, the envelope's `status.errors` and the result's `status`.
    - 404 is `PORT.NOTFOUND`, unlogged on a read; 400 is `PORT.VALIDATION`.
    - Soft refusals (#5838, #5883, #302) and `<PROTECT>` are `PORT.ACCESSDENIED`, except inside a compile's or an import's output and a delete's per-item results.
    - `PutDoc` answers 409 `EXPLORER.DOCUMENT.CONFLICT`, 423 `EXPLORER.DOCUMENT.LOCKED` (neither logged as a fault), and a 2xx soft refusal 422 `EXPLORER.SAVE.REFUSED`.
    - Vendor text is logged, never sent (AD-39).
  - **Rule 7: never** send `docnames`' `filter` (the vendor splices it into SQL), call `POST modified`, or call the `work` routes (`QueueAsync`, `PollAsync`, `CancelAsync`), which also carry a queued `search` (DW-1926).
  - A call Atelier cannot carry, such as DocDB or Documatic, needs its own named entry in AD-61 or a new port, amended into the spine at that story's spec gate (inference).
- **19.4's routes, read in the vendor source and not yet observed.**
  - v2 `GET action/search` is synchronous. It runs `%Studio.Project.FindInFiles` or `FindInFilesRegex`, requires `query` and `documents`, defaults `regex` on and `max` to 200, captures its own console, and parses it into `{doc, matches[{member, line, attr, text}]}`.
  - Observe on the throwaway: its cost on a large namespace, how its capture nests under the port's, and whether `query` or `documents` reaches SQL the vendor concatenates. If either does, rule 7's reasoning applies (inference).
  - The macro routes take a POST JSON body (`docname`, `macroname`, includes, superclasses, imports, mode), so a macro resolves in one document's context. They answer `definition` lines or `{document, line}`, and a failed lookup answers a soft error.
- **The write pattern 19.2, 19.13 and 19.3 set.** Each later write follows it and amends the spine at its own spec gate.
  - **Action-style (AD-51).** Each story names its case. The port builds the vendor query or body from the tool's declared arguments, answers the fresh read through a port-composed type (`DOCS`, `EXPORTDOCS`, `IMPORTTARGET`, `PREVIEW`, `SAVEDOCS`), and the tool declares the fingerprint subject.
  - **Two callers (AD-53, AD-55).** A screen action and the agent's proposal reach one tool. Text the model must not author travels as a declared screen-only value (`SCREENVALUES`), never in the input schema. An unadvertised tool (`ADVERTISED = 0`) is reachable by its screen only; AD-53's named case and AD-8's advertised-set clause list each one.
  - **The per-target lock (AD-34)** orders a confirm and a screen action, the editor's save included. A form Save through AD-55 does not hold it yet (DW-1882).
  - **Self-protection (AD-10).** `PROHIBITED.OCUPILOTCODE` refuses deleting, compiling, or replacing by import or by save a document named `OcuPilot*`, in any case and any namespace, on both callers.
  - **Console output (AD-39's fifth exception).** Compile and import lines, an import's names, an export's XML lines answered to this browser, and a save's compile lines reach the screen and the proposal card only. A story whose output joins them widens the exception.
  - **Audit (AD-15, AD-53).** The stock event set records no compile, delete, export, import, load or `PUT` (measured), so the agent marker is the only record and a screen write leaves no audit row. Each new write measures and names its case.
  - **Classic pages (AD-44).** Each tool lists in `CLASSICPAGES` the classic pages whose operation it performs. A screen with no classic equivalent declares that.
  - **Server files (AD-21's sixth case).** A file is a `PathPort` root plus a relative name, resolved again at the write.
  - New codes go in `Api/AtelierError.cls` with their Fixed strings. Every write type needs a `Snippet` (AD-59). Read-back (AD-58) and the change event (AD-14) apply.
  - Work past the gateway's 60 s answers 504 while the instance finishes (inference). The screen compiles a selection one action per document.
- **Reads (AD-36, AD-24, AD-5).**
  - One declared read serves the screen and its tool. Source, XML and `.int` text is the screen-only `document`, never in a tool's view or the screen context.
  - A page may issue another built screen's declared read under that screen's own gate: a compare can issue the viewer's read twice, and 19.7 and 19.8 issue 19.5's reads.
  - Query results and cell values are untrusted content to the model (AD-11, AD-60). Secret-typed fields never leave the instance.
- **SQL and the guard.**
  - Every caller value is bound. Table and column names cannot be bound, so the identifier path needs a named AD-21 case, or names first resolved against `INFORMATION_SCHEMA` (inference).
  - One classifier on the instance serves both the console and the agent's SQL tool. A client-only check is not a gate (AD-10, AD-40; inference).
  - DML and DDL need explicit confirmation in the console and are ordinary confirmed proposals from the agent.
- **The iris-table-editor harvest.** Keep its call sites, never its names. Lift `SqlBuilder`, `DataTypeFormatter`, `UrlBuilder`, `ErrorHandler`, the model types, `grid-styles.css` (bridged to OcuPilot's tokens) and the CSV helpers. Port three `grid.js` algorithms: keyboard navigation; the filter row and tri-state sort; and staging with primary-key reconciliation and stale-index recovery. Never carry its plaintext-password session.
- **Documatic and agent definitions.** Documatic loads under the browser-level session; a token never enters a frame (AD-28), and the content-security policy names only the instance's origin (AD-47). Moving the default definition is a security change, and the egress line follows the definition a turn uses (AD-42).

## UX & Interaction Patterns

- **The area.** System Explorer is rail position 8, listing Classes and Routines. Each opens an unlisted viewer at `<list route>/document` and an unlisted full-page editor at `<list route>/editor/:id`. An unlisted screen takes `sideBarPosition` 0. Prompts use the group "Code".
- **Every screen** registers the 10-item screen contract, at least three suggested prompts, aliases and its Fixed strings. The side bar lists only built screens.
- **Line-cited documents.**
  - System Explorer's Fixed-strings rows in EXPERIENCE.md are :586 to :593; append new rows after :593.
  - The closed dialog set is at :173; a new dialog joins it in place.
  - Edit DESIGN.md only in place, and move every citation the suites hold (`npm run test:tools`).
- **Code** renders as text on `code-surface` (`<pre tabindex=0>`), never as markup. Output panes carry a polite live status line. A search match takes the log viewer's `secondary-container` highlight.
- **A diff** has no code-diff component in DESIGN.md. The proposal card's diff colors, `destructive` for before and `success` for after, are the nearest tokens (inference).
- **The editor** keeps a sticky Save and Cancel bar with "Saved" as a status, asks "Leave without saving?" before any person's or agent's navigation (AD-11 rule 3), and refuses a conflict by name rather than overwriting.
- **Dialogs** are a closed set and never stack. Destructive actions use `typed-name-dialog`: a name for one document, a count for a set.

## Cross-Story Dependencies

- **Done.**
  - 19.1: the port, the area, the viewers and the four read tools.
  - 19.12: the floor admits `%Development:USE`. `Test.DeveloperFloor`, `DeveloperFloorRoutes` and `DeveloperFloorTurn` pin a real `%Developer`, and every later screen, tool and route joins those rosters.
  - 19.2: compile, delete, `DOCS`, `documentset`, `extraActions` and the `output` channel.
  - 19.13: XML export and import, the UDL header rule (it skips a leading `/* */` comment), and a reviewed import checked by a sha256 of the file's lines.
  - 19.3: the class and routine editors, `SAVEDOCS`/`SAVE`, `If-None-Match` seeded with the version read and never `ignoreConflict`, and the unadvertised `explorer.classes.save` and `explorer.routines.save`.
- **19.4 is next.**
  - Compare can reuse the viewer's declared read. Reading two namespaces passes AD-61's gate in each (inference).
  - Search and macro routes are v2, so their `MINVERSIONS` entry is 2 (inference from the URL map).
  - A hit may link to the viewer or the editor (inference).
  - New read tools and screens trip the read-side rosters listed in 19.3's spec under Rosters: `ExplorerDescriptor`, `ReadTool`, `SurfaceCoverage`, `DeveloperFloor`, the navigation tests, and a regenerated `screens.generated.ts`.
  - A client diff library is ask-first (Rule 5).
- **19.5 to 19.8, 19.10 and 19.11** go through `action/query`. 19.6's third criterion and 19.11's second describe one agent SQL tool behind one guard; whichever story introduces it wires it through the guard. 19.8 edits 19.7's grid and may reuse `extraActions` (inference).
- **19.11** builds on the agent definitions and 16.15's egress line. Reuse governance (14.2), the copy-out draft (14.1), the sanitizer (14.3), the read-back (16.17) and Download CSV (16.23).
- **Slot A.**
  - Use the `ocupilot-slot-a` profile. The throwaway is `ocupilot-a2-ci` (52780/1979); this epic's runner owns it, and it is never restarted.
  - Load source by `rsync` into `/tmp/ocupilot-a2-ci/src/`, then run `$System.OBJ.LoadDir`. Run one test class per call.
  - Probes write and remove only their own `OcuProbe*` documents and files.
  - The throwaway holds more than 1,000 task history rows, so `WireSecurityRead`'s cap test reds there; this is known and outside this epic.
- **Concurrency.**
  - Epic 18 runs on slot B. 18.5 (journals) was split on 2026-10-02: settings went to 18.18 and the record browser to 18.19.
  - Shared files, edited add-only and unioned by whichever epic reaches feature second: `Baseline.cls`, `GovernanceBaseline`, `ReadTool`, `ToolRoundTrip`, `Governance`, `ToolDispatch`, `ClassicPageGate`, `SurfaceCoverage`, `screen-outlet.ts`, EXPERIENCE.md and the spine. Edits that are not add-only (`strings.ts` citations, the `angular.json` budget) need the lead's approval.
  - Check `.worktrees/epic-18`'s diff and status before editing a shared file. Regenerate `screens.generated.ts` and `ToolFields.cls`; never hand-merge them.
  - DW-1905 (the `index` crash) and DW-1926 (the `work` routes) belong to the owner; no story acts on them.
