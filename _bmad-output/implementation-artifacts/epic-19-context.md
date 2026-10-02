# Epic 19 Context: Stage 3 - System Explorer over the Atelier API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Give developers a System Explorer inside OcuPilot, built on the IRIS Atelier API. Classes and routines are listed, viewed, compiled, deleted, exported and imported as XML, and edited with a save checked against the version it read. Code can be searched, compared and looked up by macro. The SQL catalog gets a query console behind a DML and DDL guard, and rows are browsed and edited in a grid harvested from iris-table-editor. Documatic, DocDB, SQL activity, and an agent picker with guarded agent SQL complete the stage. Everything reaches Atelier through one port, `Port/AtelierPort`, in process as the signed-in user. It never handles the user's password and never modifies a vendor web application. As in the classic portal, a `%Development` holder with no administrative resource gets in. Every screen keeps the one contract earlier stages followed.

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
  - One descriptor declares each screen, and the screen reaches the outside through one port.
  - The read tool's and the write tools' field lists derive from that descriptor.
  - Every agent write is a server-minted proposal with an instance-computed diff, an explicit confirmation and an agent marker.
  - Every read is bounded and reports truncation, and every gate checks the caller's own privileges at call time.
  - Acceptance is this contract plus each catalog row's backing route. Each story's plan writes its finer criteria; none are invented in advance.
- **Backing routes still to build**, relative to `/api/atelier/v<N>/:ns`:
  - 19.3: `PUT doc/:name` carrying the version it read.
  - 19.4: v2 `action/search`, `getmacrodefinition` and `getmacrolocation`, and two document reads diffed in the client.
  - `POST action/query`, used by:
    - 19.5, through `INFORMATION_SCHEMA` and `CALL %SQL_Manager.Catalog`;
    - 19.6, through `{query, parameters}` and `EXPLAIN`;
    - 19.7 and 19.8, the data browser;
    - 19.10, through `INFORMATION_SCHEMA.CURRENT_STATEMENTS`. Cancelling a statement is Stage 4.
  - 19.9: Documatic at `/csp/documatic/%25CSP.Documatic.cls`, and DocDB at `/api/docdb/v1/:ns`.
- **The ETag conflict path must be observed on the throwaway, not assumed.** The behavior below was read in the vendor's `PutDoc` and has not been observed.
  - The save compares the client's `If-None-Match` value with the document's current version. A mismatch answers 409 with the instance's current text.
  - A document absent at the write is saved whatever the value, so a document deleted since the read is re-created.
  - A lock held by another process answers 423, and a text the instance cannot store answers 200 with the error in its status. Code that merely fails to compile is stored (201, measured at 19.13).
  - `ignoreConflict=1` skips the check. 19.13's import uses it; the editor must not.
  - In process there is no HTTP header, so the port would seed the stub request's `HTTP_IF_NONE_MATCH` CGI value (inference).
  - Measured at 19.2: content naming another class creates that class (#16023).
- **The other gates of the stage.**
  - `action/query` runs any statement type unguarded and applies no row limit. The guard ships with the console, and OcuPilot applies the row cap and reports truncation itself.
  - DocDB needs `%Service_DocDB` enabled. Report that requirement; never assume it.
- **The agent never authors code.**
  - 19.2's and 19.13's tools carry no document text in any tool schema. A local file's text is a screen-only action value of at most 3,000,000 characters.
  - A 19.3 save tool that took source text from the model would cross that line. It is an owner decision at the spec gate, never an implementation choice (inference).
- **Who gets in.**
  - A caller holding neither an `%Admin_*` resource nor `%Development` is shown "no administrative privileges on this instance". The turn endpoint refuses them with the same message.
  - A `%Development`-only caller reaches System Explorer and is refused wherever a classic `%Developer` is refused.
- **Governance (AD-22).**
  - Every new write key gets its line in `Kernel/Governance/Baseline.cls` in the same change, and every new destructive key ships disabled.
  - From 2026-10-04, the owner decides how new keys enter the baseline.
  - As shipped: compile `true`, delete `false`, export `true`, import `false`.
- **Limits carried knowingly from the harvest (19.7, 19.8):**
  - only single-column primary keys;
  - the identifier pattern refuses delimited names;
  - `rowsAffected` always reads 1;
  - `%VID` offset paging re-reads earlier rows and runs a `COUNT(*)` per page, and a failed count shows zero rows.
- **Measure, never assume.**
  - Take each pair set from the handler's own checks plus a purpose-built least-privileged principal on the throwaway, never `%Operator`.
  - Read a classic page's `RESOURCE` in `irissys/`; never recall it.

## Technical Decisions

- **AD-61: the Atelier port.**
  - **What it is.** `Port/AtelierPort` is the only class that names an `%Api.Atelier.*` class, and it names them only through parameters. `scripts/check-objectscript.py` refuses the literal `%Atelier`. The port calls route methods in the caller's process, one route at a time. The browser never calls `/api/atelier`, nothing sends a Basic header, and JWT is never enabled on the vendor application.
  - **Gate first (AD-29).**
    - `%Development:USE` is checked first.
    - Then READ, per namespace at call time, on the routines and globals databases and on every database the namespace maps code from except IRISSYS.
    - A write (compile, delete, import, and any later save) also needs WRITE on the target namespace's routines-database resource, because the API checks no WRITE. An export needs only the read pairs.
    - Each write tool declares the same pairs (AD-8), so a caller without one is refused by name before any port call.
  - **Version.** The port calls `v<min(N, 8)>`. Each route declares its minimum in `MINVERSIONS`, and an older instance is refused `PORT.NOTIMPLEMENTED` before any call. The 2026.2 floor answers 8; tests reach older versions through the version seam.
  - **Stub CSP state.**
    - The port runs `New %request, %response, %session, %SourceControl`, seeds query parameters and writes a body it builds to the stub's content stream.
    - It switches namespace by explicit save and restore around the vendor call only (AD-16), and calls no `OcuPilot.*` class while switched.
  - **Capture.**
    - An answer above about 3.6 million characters is refused `PORT.UNAVAILABLE`.
    - `action/index` alone goes through a temporary file, because the capture killed the process with signal 11.
  - **Outcomes** are read from four places: the `%Status`, `%response.Status`, the envelope's `status.errors` and the result's `status`.
    - 404 is `PORT.NOTFOUND`, unlogged on a read.
    - 400 is `PORT.VALIDATION`.
    - Soft refusals (#5838, #5883, #302) and `<PROTECT>` are `PORT.ACCESSDENIED`, except inside a compile's or an import's output and a delete's per-item results.
    - Vendor text is logged, never sent (AD-39).
  - **Never** send `docnames`' `filter`, call `POST modified`, or call the `work` routes (DW-1926).
  - A call Atelier cannot carry, such as DocDB, needs its own named entry in AD-61 or a new port, as a spine amendment at that story's spec gate (inference).
- **The write pattern 19.2 and 19.13 set** (each later explorer write follows it, amending the spine at its own spec gate):
  - **Action-style (AD-51).** Each story adds a named case: the port builds the vendor query or body from the tool's declared arguments. The fresh read is a port-composed type, and the tool declares the fingerprint subject over it.
  - **Two callers (AD-53, AD-55).** A screen action or Save and the agent's proposal reach one tool. Text the model must not author travels as a declared screen-only value (`SCREENVALUES`), never in the input schema.
  - **The per-target lock (AD-34)** orders a confirm and a screen action. A screen Save does not hold it yet (DW-1882).
  - **Self-protection (AD-10).** `PROHIBITED.OCUPILOTCODE` refuses deleting, compiling or replacing-by-import a document named `OcuPilot*`, in any case and any namespace, on both callers. A save also replaces code, so 19.3 extends the arm (inference).
  - **Console output (AD-39's fifth exception).** Compile and import lines reach the screen and the proposal card only, never the model, a tool result, the ledger, a log line or screen context. A story whose output joins them widens the exception.
  - **Audit (AD-15 and AD-53, eleventh case).** The stock event set records no compile, delete, export, import, load or `PUT` (measured), so the agent marker is the only record. A save names its own case (inference).
  - **Classic pages (AD-44).** Each tool lists, in `CLASSICPAGES`, the classic pages whose operation it performs, as a screen does. The classic portal has no editor, so the editor declares that it has no classic equivalent (AC2: new capability, not parity).
  - **Server files (AD-21's sixth case).** A file is named by a `PathPort` root plus a relative name and resolved again at the write. `PathPort`'s pairs are declared only when `root` is sent.
  - **Codes, scripts and output.**
    - New codes go in `Api/AtelierError.cls`, never `Api/Error.cls`, each with its Fixed string.
    - Every write type needs a `Snippet` (AD-59).
    - Read-back (AD-58) and the change event (AD-14) apply.
  - **Long work.** A long compile or import past the gateway's 60 s answers 504 while the instance finishes it (inference). The screen compiles a selection one action per document and streams the lines.
- **Reads (AD-36, AD-24).**
  - One declared read serves the screen and its tool.
  - Source, XML and `.int` text is the screen-only `document`, never in a tool's view or the screen context. Text being edited is the same.
  - Query results and cell values are untrusted content to the model (AD-11, AD-60). Secret-typed fields never leave the instance.
- **SQL and the guard.**
  - Every caller value is bound. Table and column names cannot be bound, so the identifier path needs a named AD-21 case or names first resolved against `INFORMATION_SCHEMA` (inference).
  - One classifier on the instance serves both the console and the agent's SQL tool. A client-only check is not a gate (AD-10, AD-40; inference).
  - DML and DDL need explicit confirmation in the console and are ordinary confirmed proposals from the agent.
- **The iris-table-editor harvest.**
  - Keep its call sites, never its names.
  - Lift `SqlBuilder`, `DataTypeFormatter`, `UrlBuilder`, `ErrorHandler`, the model types, `grid-styles.css` (bridged to OcuPilot's tokens) and the CSV helpers.
  - Port three algorithms from `grid.js`: keyboard navigation; the filter row and tri-state sort; and staging with primary-key reconciliation and stale-index recovery.
  - Never carry its plaintext-password session.
- **Documatic and agent definitions.**
  - Documatic loads under the browser-level session. A token never enters a frame (AD-28), and the content-security policy names only the instance's origin (AD-47).
  - Moving the default definition is a security change, and the egress line follows the definition a turn uses (AD-42).

## UX & Interaction Patterns

- **The area.**
  - System Explorer is rail position 8, listing Classes and Routines. Each opens an unlisted viewer at `<list route>/document`.
  - Prompts use the group "Code". Each story's plan places its screens.
- **Every screen** registers the 10-item screen contract, at least three suggested prompts, aliases and its Fixed strings. The side bar lists only built screens.
- **Line-cited documents.**
  - In EXPERIENCE.md, System Explorer's Fixed-strings rows are :586 to :592; append new rows after :592.
  - The closed dialog set is at :173; a new dialog joins it in place.
  - Edit DESIGN.md only in place, and move every citation the suites hold (`npm run test:tools`).
- **The editor (19.3)** is a full-page form-page route:
  - a sticky Save and Cancel bar, with "Saved" as a status;
  - an unsaved-changes guard ("Leave without saving?") that also answers an agent navigation (AD-11 rule 3);
  - a conflict refused by name, never silently overwritten.
- **Code** renders as text on `code-surface` (`<pre tabindex=0>`), never as markup. Output panes carry a polite live status line.
- **Dialogs** are a closed set and never stack. Destructive actions use `typed-name-dialog`: a name for one document, a count for a set.

## Cross-Story Dependencies

- **Done.**
  - 19.1 shipped the port, the area and the four read tools.
  - 19.12 widened the floor. `Test.DeveloperFloor*` pins a real `%Developer`, and every later screen, tool and route joins those rosters.
  - 19.2 shipped compile, delete, `DOCS`, `documentset`, `extraActions` and the `output` channel.
  - 19.13 shipped `EXPORTDOCS`, `EXPORT`, `IMPORTTARGET`, `PREVIEW` and `IMPORT`, plus four tools. Export keys are on and import keys off.
    - It added the UDL header rule and the `PUT doc?ignoreConflict=1` path for one UDL document.
    - Its reviewed import summary carries a sha256 of the file's lines, refused `CHANGED` on any change.
    - The registry now holds four explorer reads and eight writes. `DeveloperFloor`'s writes are exactly the two exports.
- **19.3 is next.**
  - **Version token.** The viewer answers the document's version as `modified`, taken from the index read's `ts`. Whether that equals the value the vendor's conflict check compares is unmeasured; Task 0 settles it on the throwaway (inference).
  - **Reuse.** It can reuse `DOCS`, `documentset`, the `output` channel for a save-and-compile, and 19.13's header rule, which confirms the text still names the document being saved.
  - **Rosters.** Its write trips the rosters listed in 19.13's spec under Code Map › Rosters a 19.13 change trips.
  - **Libraries.** A source-editor library would be a new third-party dependency: Rule 5's ask-first tier, so halt for the owner. It must be vendored with no CDN, run under the content-security policy, and add to the bundle.
- **19.4** adds search and macro lookup and reuses the write gate. A client diff library is likewise an ask-first decision.
- **19.5 to 19.8, 19.10 and 19.11** go through `action/query`.
  - 19.6's third criterion and 19.11's second describe one agent SQL tool behind one guard. Whichever story introduces it wires it through the guard.
  - 19.7 and 19.8 issue 19.5's declared reads rather than write a second query (AD-5). 19.8 edits 19.7's grid and may reuse `extraActions` (inference).
- **19.11** builds on the agent definitions and 16.15's egress line. Reuse governance (14.2), the copy-out draft (14.1), the sanitizer (14.3), the read-back (16.17) and Download CSV (16.23).
- **Bundle.**
  - The initial-bundle warning is 2,447 kB, against a measured 2,446,524 bytes at 19.13, so nearly any UI addition crosses it.
  - Re-base `ui/angular.json` and `angular-json.test.mjs` to the measured size (DW-1166). Stop to ask above 3,800 kB; the hard error is 4,000 kB.
- **Slot A.**
  - Use the `ocupilot-slot-a` profile.
  - The throwaway is `ocupilot-a2-ci` (52780/1979). This epic's runner owns it, and it is never restarted.
  - Load source by `rsync` into `/tmp/ocupilot-a2-ci/src/`, then run `$System.OBJ.LoadDir`.
  - Run one test class at a time. Probes write and remove only their own documents and files.
- **Concurrency.**
  - Epic 18 runs on slot B (18.16, then 18.5 to 18.13), and Epic 23 is closed.
  - Six roster files are unioned with 18.16 by whichever reaches feature second: `GovernanceBaseline`, `ReadTool`, `ToolRoundTrip`, `Governance`, `ToolDispatch` and `ClassicPageGate`.
  - Check `.worktrees/epic-18`'s diff and status before editing a shared file, and keep shared edits add-only.
  - Regenerate `screens.generated.ts` and `ToolFields.cls`; never hand-merge them.
  - DW-1905 (the `index` crash) and DW-1926 (the `work` routes) are the owner's; no story acts on them.
