# Epic 19 Context: Stage 3 - System Explorer over the Atelier API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Give developers a System Explorer inside OcuPilot, built on the IRIS Atelier API. Classes and routines are listed, viewed, compiled, deleted, exported and imported as XML, and edited with a save checked against the ETag it read. Code can be searched, compared and looked up by macro. The SQL catalog gets a query console behind a DML and DDL guard, and rows are browsed and edited in a grid harvested from iris-table-editor. Documatic, DocDB, SQL activity, and an agent picker with guarded agent SQL complete the stage. Everything reaches Atelier through one port, `Port/AtelierPort`, in process as the signed-in user; it never handles the user's password and never modifies a vendor web application. Like the classic portal, the explorer admits a `%Development` holder who holds no administrative resource, and every screen keeps the one contract earlier stages followed.

## Stories

- Story 19.1: Classes and routines, listed and viewed
- Story 19.2: Compile, delete, export and import (compile and delete shipped; export and import split to 19.13)
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

- **One contract (FR-80).** One descriptor declares each screen, and the screen reaches outside through one port. Its read tool's and write tools' field lists derive from that descriptor. Every agent write is a server-minted proposal with an instance-computed diff, an explicit confirmation and an agent marker. Every read is bounded and reports truncation. Every gate checks the caller's own privileges at call time. Acceptance is this contract plus each catalog row's backing route (CP-36, OS-23, EX-02 to EX-34, DT-01). Each story's plan writes its finer criteria; none are invented in advance.
- **Backing routes**, relative to `/api/atelier/v<N>/:ns`:
  - 19.2 (shipped): `POST action/compile` and `DELETE docs`.
  - 19.13: the v7 routes `POST action/xml/export`, `action/xml/list` and `action/xml/load`, plus `PUT doc/:name` with `ignoreConflict=1` for a single UDL file.
  - 19.3: `PUT doc/:name` carrying the ETag.
  - 19.4: v2 `action/search`, v2 `getmacrodefinition` and `getmacrolocation`, and two document reads diffed in the client.
  - `POST action/query`: 19.5 (`INFORMATION_SCHEMA` and `CALL %SQL_Manager.Catalog`), 19.6 (`{query, parameters}` and `EXPLAIN`), 19.7 and 19.8 (the data browser), and 19.10 (`INFORMATION_SCHEMA.CURRENT_STATEMENTS`; cancelling a statement is Stage 4).
  - 19.9: Documatic at `/csp/documatic/%25CSP.Documatic.cls`, and DocDB at `/api/docdb/v1/:ns`.
- **What gates the stage.**
  - `action/query` runs any statement type unguarded and applies no row limit. The guard therefore ships with the console, and OcuPilot applies the row cap and reports truncation itself.
  - XML export and load need Atelier v7. The 2026.2 floor answers v8, so the gate never fires there; test it through the port's version seam answering 6.
  - Observe the ETag conflict on document `PUT` on a throwaway before building on it.
  - DocDB needs `%Service_DocDB` enabled. Report the requirement; never assume it.
- **Who gets in.** A caller holding neither an `%Admin_*` resource nor `%Development` is shown "no administrative privileges on this instance", and the turn endpoint refuses them with the same message. A `%Development`-only caller reaches System Explorer and is refused everywhere a classic `%Developer` is refused.
- **Governance (AD-22).** Every new write key gets its line in `Kernel/Governance/Baseline.cls` in the same change, and every new destructive key ships disabled.
  - 19.2 shipped the compile keys `true` and the delete keys `false`.
  - 19.13's plan sets the export keys `true` and the import keys `false`, because an import silently replaces existing code (measured).
  - After 2026-10-04 the owner decides how new keys enter.
- **Limits carried knowingly from the harvest.** Only single-column primary keys. The identifier pattern refuses delimited names. `rowsAffected` always reads 1. `%VID` offset paging re-reads earlier rows and runs a separate `COUNT(*)` per page, and a failed count shows zero rows.
- **Measure, never assume.** Take each pair set from the handler's own checks plus a purpose-built least-privileged principal on the throwaway, never `%Operator`. Read a classic page's `RESOURCE` in `irissys/`; never recall it.

## Technical Decisions

- **AD-61, the Atelier port.** `Port/AtelierPort` is the only class that names an `%Api.Atelier.*` class, and it names them only through parameters. The literal `%Atelier` is forbidden under `src/` and `ui/`, comments included. The port calls `%Api.Atelier.v8`'s route methods in the caller's process, as the signed-in user, one route at a time. The browser never calls `/api/atelier`, nothing sends a Basic header, and JWT is never enabled on the vendor application.
  - **Gate first (AD-29).** Before any vendor call the port checks `%Development:USE`. It then checks READ, per namespace at call time, on the routines and globals databases and on every database the namespace maps code from except IRISSYS (from `findmappings^%R`, whose signature a test pins). A refusal names the failed pair and is never answered as an empty list.
  - **The write gate.** A write (compile and delete; import from 19.13) also requires WRITE on the resource guarding the target namespace's routines database, resolved at call time, because the API checks no WRITE itself. The write tools declare the same pair (AD-8), so both callers are refused by name before any port call. A `%Developer` therefore writes in USER (`%DB_USER:RW`) and is refused in HSCUSTOM. An export needs the read pairs alone.
  - **Version.** The port calls `v<min(N, 8)>`. Each route declares its minimum in `MINVERSIONS`, and on an older instance the port refuses `PORT.NOTIMPLEMENTED`, naming both versions, before any call. 19.13's XML routes declare 7.
  - **Stub CSP state and namespace.** The port runs `New %request, %response, %session, %SourceControl` and seeds query parameters into `%request.Data`. It omits trailing route arguments, and uses `Port/AtelierRequest` where a route checks the body's content type. It switches the namespace by explicit save and restore around the vendor call only (AD-16) and restores it first in every `Catch`. No `OcuPilot.*` class is called while switched.
  - **Capture.**
    - The port captures each route's output, so the vendor envelope never reaches OcuPilot's response (AD-12).
    - An answer above about 3.6 million characters is refused `PORT.UNAVAILABLE`. A large export can reach it.
    - Compile measured safe under the capture: 800 calls, no process death.
    - The XML routes are unmeasured under the capture (19.2's deferred T0.1, now 19.13's).
    - `action/index` alone writes through a port-owned temporary file (`FILEDEVICEROUTES`), because under the capture it ended the process with signal 11. A later route that needs the file device is named in AD-61.
  - **Outcome from four places:** the `%Status`, `%response.Status`, the envelope's `status.errors` and the result's own `status`.
    - A 404 is `PORT.NOTFOUND`: unlogged on a read, logged on a write.
    - A 400 is `PORT.VALIDATION`.
    - The API answers a privilege or read-only refusal as a soft error (#5838, #5883, #302), never as `<PROTECT>`. Those soft errors and a `<PROTECT>` are both `PORT.ACCESSDENIED`, except inside a compile's output and a delete's per-item results, where they are that write's own output.
    - Vendor text is logged, never sent (AD-39).
  - **Never** send `docnames`' `filter`, which the vendor splices into SQL; the port filters parsed rows before the cap. **Never** call `POST modified`, which writes `^ISC.Src.Jrn` in every mapped database. **Never** call the `work` routes (`QueueAsync`, `PollAsync`, `CancelAsync`): the poll checks no owner, and the queue runs a routine the caller names (DW-1926).
  - A call Atelier cannot carry, such as DocDB, needs its own named entry in AD-61 or a new port, as a spine amendment at that story's spec gate (inference).
- **The API's floor (AD-8), shipped by 19.12.** Before any route runs, the API refuses a caller who holds no member of `Screen.Gate.FloorResources()`, which is `ADMINRESOURCES` plus `%Development`, each at USE.
  - `Screen/Gate.cls` is the floor's one home. The router, `ProviderPort` and the turn's per-step check derive it at compile time.
  - `%Development` never joins `ADMINRESOURCES`.
  - Each new screen, route and tool declares its own `%Development`-class pair, matching its classic page's `RESOURCE` and unioned with any custom resource on that page (AD-44).
  - A write tool names in `CLASSICPAGES` each further classic page whose operation it performs. The compile tools name `%CSP.UI.Portal.Dialog.Compile`, and the deletes name none. Export and import name `.Dialog.Export` and `.Dialog.Import` (19.13).
- **The write-tool pattern 19.2 established**, for 19.3, 19.13 and every later explorer write:
  - **Action-style (AD-51).** `AtelierPort` builds the vendor query or body from the tool's declared arguments, a named AD-51 case. It answers the fresh read through the port-composed `DOCS` type (`{Present, Modified, Absent}`), from one `docnames` read of about 0.35 s on HSCUSTOM's classes. Each tool declares a fingerprint subject over that read. Compile flags are always `c` plus three declared booleans (`k`, `b`, `u`), never free text.
  - **Targets (AD-13).** A `class` or `routine` id may name a document set under the `documentset` rule: split on commas, drop empty pieces, keep unique names, sort by code point. A single name, the literal `import` included, reads as itself. A set holds at most 100 documents, on both callers.
  - **Two callers (AD-53, AD-55).** A list's action acts on its checked rows through `multiSelect {action, extraActions, max}`. AD-5 was amended to add `extraActions`, and `eligible` with `ineligibleKey` became optional as a pair. The agent's caller is the proposal.
    - The screen caller mints no proposal, emits no marker, and is not gated by read-only or the kill switch.
    - Both callers get the prohibited set, the per-target lock (AD-34, keyed on the canonical set), the read-back and the change event.
  - **Self-protection (AD-10).** Deleting or compiling a document whose name begins with `OcuPilot`, in any case and in any namespace, is refused `PROHIBITED.OCUPILOTCODE` on both callers. 19.13 adds importing a file that holds one, checked against the file's documents at the write.
  - **Console output (AD-39's fifth exception).** A compile's console lines (an import's from 19.13) travel as `output` on the screen action's and the confirm's answer. They render as text on the screen and on the proposal card, and never reach the model, a tool result, a ledger row, a log line or screen context.
  - **Audit (AD-15 and AD-53, tenth case).** With the stock event set, no vendor event records a compile or a delete, and the classic `%System/%SMPExplorer/*` events are disabled by default. The agent's marker is the only record, and a screen action leaves none. 19.2's plan measured that load and `PUT` record none either; 19.13 names its own case at ship.
  - **Errors.** New codes go in `Api/AtelierError.cls`, never `Api/Error.cls`. It holds `EXPLORER.DOCUMENT.ABSENT` and the three import codes (`EXPLORER.IMPORT.UNREADABLE`, `.CHANGED` and `.TOOLARGE`), which stay unused until 19.13; their Fixed strings are already published.
  - **Snippets.** `Invoke` needs a `Snippet` for every type (AD-59), or the registry test fails.
- **Server files (AD-21's sixth case, 19.13).** A server file is named by a `PathPort` root plus a relative name, never a path, and resolved again at the write. The export is an overwriting `file` consumer whose overwrite is a constant, and the import is a `source`. The tool declares `%Admin_FileSystemAccess:USE` and `%DB_IRISSYS:READ` only when `root` is sent. Naming these consumers in AD-21, and the XML routes in AD-61 rule 2, are 19.13's spec-gate amendments. A local file's content is a screen-only value of at most 3,000,000 characters and never appears in a tool's schema: the agent never authors code.
- **Streaming (decided at 19.2).** The screen compiles a selection as one screen action per document, in list order, and appends each answer's lines as it lands. Each action is a complete foreground write (AD-7) answering one envelope (AD-12), so no new channel is needed. The agent's confirm compiles the whole set in one call. A compile with dependents that outlasts the Web Gateway's 60 s answers 504 while the instance completes it (inference).
- **Reads (AD-36, AD-24).**
  - One declared read serves both the screen and the tool, under the row cap and the context caps. A `text` or `choice` criterion may declare a `default`.
  - Source, XML and `.int` text is the screen-only `document`, which never reaches a tool's view or the screen context. The agent reads structure rows, with `Description` cut at 1,000 characters and sanitized.
  - Query results and cell values are untrusted content to the model (AD-11, AD-60). Secret-typed fields never leave the instance.
- **SQL (AD-21) and the guard.**
  - Every caller value is bound. Table and column names cannot be bound, and validation never substitutes for binding, so the identifier path needs either a named AD-21 case or names first resolved against `INFORMATION_SCHEMA` (inference).
  - One classifier on the instance serves both the console and the agent's SQL tool; a client-only check is not a gate (AD-10, AD-40; inference).
  - A DML or DDL statement needs an explicit confirmation in the console and is an ordinary confirmed proposal from the agent. Release 1 gave the agent catalog SELECTs only.
- **The iris-table-editor harvest.** Keep its call sites, never its names, and bridge its `--ite-*` tokens to OcuPilot's.
  - Lift `SqlBuilder`, `DataTypeFormatter`, `UrlBuilder`, `ErrorHandler`, the model types, `grid-styles.css` and the CSV helpers.
  - Port three algorithms out of `grid.js`: keyboard navigation; the filter row and tri-state sort; staging with primary-key reconciliation and stale-index recovery.
  - Rework its Atelier services behind a transport seam aimed at the OcuPilot API. Never carry its plaintext-password session.
- **Documatic and agent definitions.** Documatic loads from the instance under the browser-level session. A token never enters a frame (AD-28), and the content-security policy names only the instance's origin (AD-47). The picker chooses among enabled definitions. Moving the default marker stays a security change, and the egress chip and line follow the definition a turn uses (AD-42).

## UX & Interaction Patterns

- **The area.** "System Explorer" is rail position 8; Agent co-pilot is 9, pinned at the bottom. Its side bar lists Classes and Routines, each with an unlisted viewer at `<list route>/document`. Home's tile reads "Classes · Routines", and prompts use the group "Code". Each story's plan decides where its screens sit; the catalog files SQL activity under system operation.
- **Every screen** registers the 10-item screen contract, at least three suggested prompts, aliases and its Fixed strings. The side bar lists only built screens.
- **Line-cited documents.**
  - System Explorer's Fixed-strings rows are EXPERIENCE.md :586 to :590; append new rows after :590. Rows :589 and :590 already carry 19.2's strings and the import refusals.
  - The closed dialog set at :173 names the compile dialog; each new dialog joins it in place.
  - Edit DESIGN.md only in place, and move every citation the suites hold (`npm run test:tools` names them).
- **Code and tables.**
  - Source, XML, `.int`, query text and console output render as text on `code-surface` in `<pre tabindex=0>`, never as markup, with identifiers set in `code`. Each write's output pane carries a polite live status line.
  - Lists use the shared data table with the max-rows footer.
  - The harvested grid's roving tabindex gives way to the portal's model, and its CSV writer to the shipped Download CSV (inference).
  - Design tokens only.
- **Dialogs** are a closed set and never stack. A destructive action uses the one-level `typed-name-dialog`: one document is confirmed by typing its name, and a set by typing its count. The compile dialog opens with keep source checked, dependents unchecked and skip up-to-date checked. The 19.13 dialogs offer a server file (`server-path-picker`) or this browser, plus a compile checkbox, checked by default, on import, and a refused version is shown in the dialog.
- **The editor (19.3)** follows form-page conventions: a sticky Save, and an unsaved-changes guard that can also refuse an agent navigation. An ETag conflict is refused by name, never silently overwritten.

## Cross-Story Dependencies

- **19.1 (done)** landed `Port/AtelierPort`, `Port/AtelierRequest`, `MINVERSIONS`, `FILEDEVICEROUTES`, the criterion `default`, the area and four read tools. Its named limit: a namespace whose names exceed about 3.6 million characters is refused `PORT.UNAVAILABLE` (HSCUSTOM's classes use 1.83 MB).
- **19.12 (done)** widened the floor.
  - `Test.DeveloperFloor`, `DeveloperFloorRoutes` and `DeveloperFloorTurn` pin a real `%Developer` principal to 4 areas, 10 screens, 10 tools (none a write) and 29 routes.
  - Every later screen, tool and route joins those rosters.
  - A test class that arms principals needs its `# classes:` line in `scripts/ci-throwaway.sh`.
- **19.2 (done, Part A)** shipped the following:
  - the `DOCS`, `COMPILE` and `DELETE` types;
  - the tools `explorer.{classes,routines}.{compile,delete}` over the abstract bases `ExplorerWrite`, `ExplorerCompile`, `ExplorerDelete` and `ExplorerMint`;
  - the write gate, `PROHIBITED.OCUPILOTCODE`, `documentset`, `extraActions` and the `output` channel;
  - DW-1922's `objectonly`: a routine kept only as object code is stated as such rather than shown as not found.

  The registry now holds 200 tools, 127 of them writes. `ExplorerDescriptor.TestTheAreaHoldsFourReadsAndFourWrites` replaced the read-only tripwire. DW-1930 to DW-1934 were accepted as limits; DW-1934 is that every write reads `DOCS` over the whole category two or three times.
- **19.13 is next.** It takes AC4 and AC5 verbatim, and it starts from 19.2's spec, whose items marked `[B]` or `(19.13)` hold its design and measurements.
  - **Types and tools.** It adds the `EXPORT`, `PREVIEW` and `IMPORT` types, the tools `explorer.{classes,routines}.{export,import}`, and import as each list's `primaryAction`.
  - **Measured vendor behavior.**
    - Run `xml/list` before `xml/load` and refuse an unreadable file first: malformed XML otherwise leaves a stub class.
    - Load with `selected` set to the listed names.
    - One missing name voids a whole export (#6308), so the fresh read refuses it first.
    - A UDL file's document name comes from its header line.
  - **Rosters it trips.** `DeveloperFloor` gains the two export tools, and its "none is a write" becomes "exactly the two exports". `ExplorerDescriptor` goes to four reads and eight writes, and `ReadTool`'s count moves with them.
  - **DW-1932** reopens if 19.13 revises the Routines list's dialogs and the delete warning still names a persistent class.
  - **Named limits.** It does not read classic `%RO` files, and it imports every document the file holds.
- **On `AtelierPort`:**
  - 19.3 takes the ETag from the viewer read's `ts`, and can reuse `DOCS`, `documentset` and the `output` channel for a save-and-compile.
  - 19.4 adds search and macro lookup and reuses the write gate.
  - 19.5 to 19.8, 19.10 and 19.11 go through `action/query`.
  - 19.8's staging may reuse `extraActions` (inference).
- **The guard is shared.** 19.6's third criterion and 19.11's second describe the same agent SQL tool behind one guard; whichever story introduces the tool wires it through the guard.
- **Data screens.** 19.7 and 19.8 can issue 19.5's declared catalog reads rather than write a second query (AD-5), and 19.8 edits 19.7's grid.
- **New libraries.** 19.3 and 19.4 may need an editor or a diff library. Ask the owner first (Rule 5); anything added is vendored, with no CDN.
- **19.11** builds on the agent definitions and 16.15's egress line. Reuse governance (14.2), the copy-out draft (14.1), the sanitizer (14.3), the read-back (16.17) and Download CSV (16.23).
- **Bundle.** 19.2 re-based the initial-bundle warning in `ui/angular.json` and `angular-json.test.mjs` to 2,433 kB (measured 2.43 MB). A story that exceeds it re-bases both to the measured size, and stops to ask above 3,800 kB.
- **Slot A.**
  - Use the `ocupilot-slot-a` profile.
  - The throwaway is `ocupilot-a2-ci` (52780/1979, `/tmp/ocupilot-a2-ci`), owned by this epic's runner and never restarted. Load source by `rsync` into `/tmp/ocupilot-a2-ci/src/`, then `$System.OBJ.LoadDir` inside the container. Run one test class at a time. Every probe writes only documents it created itself and removes them afterwards.
  - Story 23.3 has closed, and Epic 18 runs on slot B (18.16, then 18.5 to 18.13). Before editing a shared file, check `.worktrees/epic-18`'s diff and status.
  - Shared-file edits stay add-only. Regenerate `screens.generated.ts` and `ToolFields.cls`; never hand-merge them.
  - DW-1905 and DW-1926, whether to report the `index` crash and the `work` routes to InterSystems, are the owner's; no story acts on them.
