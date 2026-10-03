# Epic 19 Context: Stage 3 - System Explorer over the Atelier API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Give developers a System Explorer inside OcuPilot, built on the IRIS Atelier API. Classes and routines are already listed, viewed, compiled, deleted, exported and imported as XML, edited with a save checked against the version it read, searched and compared, and their macros can be looked up. The rest of the stage adds the SQL catalog, a query console behind a DML and DDL guard, a data grid harvested from iris-table-editor, Documatic, DocDB, SQL activity, and an agent picker with guarded agent SQL. Everything reaches Atelier through one port, `Port/AtelierPort`, in process as the signed-in user. It never handles the user's password and never modifies a vendor web application. As in the classic portal, a `%Development` holder with no administrative resource gets in. Every screen keeps the one contract earlier stages followed.

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
- **`action/query` is the stage's gate.** It executes **any** statement type unguarded and applies no row limit. So the DML and DDL guard ships **with** the query console (19.6), never after it. OcuPilot applies the row cap and reports truncation itself.
  - The route is `POST /api/atelier/v<N>/:ns/action/query` (vendor `Query`). It is in the URL map from v1 and redefined in v6. This was read in the vendor source and not yet observed.
  - Users: 19.5 (catalog reads), 19.6 (`{query, parameters}`, the plan), 19.7 and 19.8 (the data browser), and 19.10 (`INFORMATION_SCHEMA.CURRENT_STATEMENTS`; canceling a statement is Stage 4).
- **What that means for 19.5's catalog reads.**
  - They never open a path where caller text reaches a statement. The statement text is fixed and owned by the port, and every caller value (a schema, a table, a filter) is bound.
  - They use the information schema and the catalog queries the classic SQL pages use.
  - Candidates for verification on the instance, not facts: the research names `%SQL.Manager.Catalog`'s queries (`Schemas`, `Tables`, `Fields`, `Indices`, `Constraints`, `Triggers`, `Procedures`), called through `action/query`.
  - Whether a catalog row set is filtered by the caller's SQL privileges is measured with a least-privileged principal (inference).
- **The classic SQL pages.** 19.5's plan reads each page's `RESOURCE` and detail tabs on the instance. Known: `SQL/Home` declares `%Development`, and `SQL/QButtons/RuntimeStats` declares `%Development:USE`. The research lists Home's catalog tabs (Fields, Indices, Triggers, Constraints, Cached queries, Partitions) and its system and deprecated toggles; that is a research reading, not an observation.
- **Other backing routes.** 19.9 uses Documatic at `/csp/documatic/%25CSP.Documatic.cls` and DocDB at `/api/docdb/v1/:ns`. DocDB needs `%Service_DocDB` enabled: report that requirement and never assume it.
- **The agent never authors code.**
  - No tool schema carries document text. A local file's text is a screen-only action value of at most 3,000,000 characters.
  - The editor's save is screen-only (`explorer.classes.save` and `explorer.routines.save`, unadvertised, keys `false`).
- **Who gets in.** A caller holding neither an `%Admin_*` resource nor `%Development:USE` is refused the API and the turn. A `%Development`-only caller reaches System Explorer and is refused wherever a classic `%Developer` is.
- **Governance (AD-22).** Every new write key gets its line in `Kernel/Governance/Baseline.cls` in the same change, and every new destructive key ships disabled. From 2026-10-04 the owner decides how new keys enter the baseline. As shipped: compile `true`, delete `false`, export `true`, import `false`, save `false`. Read tools add no key.
- **New dependencies (Rule 5).** A third-party library, such as an editor or grid library, is ask-first: halt for the owner before adding it. It must be vendored with no CDN, run under the content-security policy, and count toward the bundle. 19.4 wrote its own diff and needed none.
- **Bundle.** The initial-bundle warning is 2,548 kB, against 2,547,991 bytes measured after 18.5 merged forward, so nearly any UI addition crosses it. Re-base `ui/angular.json` and `angular-json.test.mjs` to the measured size (DW-1166). Stop and ask above 3,800 kB; the hard error is 4,000 kB.
- **Harvest limits carried knowingly (19.7, 19.8):** only single-column primary keys; the identifier pattern refuses delimited names; `rowsAffected` always reads 1; `%VID` offset paging re-reads earlier rows and runs a `COUNT(*)` per page, and a failed count shows zero rows.
- **Measure, never assume.** Take each pair set from the handler's own checks plus a purpose-built least-privileged principal on the throwaway, never `%Operator`. Read a classic page's `RESOURCE` in `irissys/` or on the instance; never recall it.
- **The ledger.**
  - DW-1001: every derived read tool describes a text criterion as a comma list where `*` matches. A new read tool repeats this, so record an occurrence and leave the fix alone. Epic 19's burn-down story owns the fix: a criterion description declared in the descriptor (`Screen/Registry.cls`, checking Epic 18's diff at edit time).
  - DW-1957 (the search route splices `documents` into SQL) and DW-1958 (it runs a caller regex with no operation limit) are vendor-defect candidates. The owner decides whether to report them together with DW-1905 and DW-1926, and no story acts on them.

## Technical Decisions

- **AD-61: the Atelier port.** `Port/AtelierPort` is the only class that names an `%Api.Atelier.*` class, through parameters only. It calls route methods in the caller's process, one route at a time. The browser never calls `/api/atelier`.
  1. **Gate first (AD-29).** `%Development:USE`, then READ per namespace at call time on the routines and globals databases and every database the namespace maps code from except IRISSYS. A write also needs WRITE on the routines database's resource; an export needs only the read pairs. A refusal names the failed pair.
  2. **Version.** The port calls `v<min(N, 8)>`, and each route declares its minimum in `MINVERSIONS` (XML routes 7; `Search` and both macro routes 2). An older instance is refused `PORT.NOTIMPLEMENTED` before any call.
  3. **Stub CSP state.** `New %request, %response, %session, %SourceControl`, and query parameters are seeded into `%request.Data`. A body the port builds is written to the stub's content stream. A macro lookup's context comes from the document's own text through `GetDoc`; no caller supplies it.
  4. **Namespace (AD-16).** It is switched by save and restore around the vendor call only, and no `OcuPilot.*` class is called while switched.
  5. **Capture.** An answer above about 3.6 million characters is refused `PORT.UNAVAILABLE`. `action/index` alone goes through a temporary file (signal 11 under the capture), and a later route that needs the file device names itself.
  6. **Outcome from four places:** the `%Status`, `%response.Status`, the envelope's `status.errors` and the result's `status`.
     - 404 is `PORT.NOTFOUND`, unlogged on a read; 400 is `PORT.VALIDATION`.
     - Soft refusals (#5838, #5883, #302) and `<PROTECT>` are `PORT.ACCESSDENIED`.
     - Vendor text is logged, never sent (AD-39).
  7. **Never:** `docnames`' `filter` (spliced into SQL), `POST modified`, or the `work` routes (DW-1926). A search always sends `regex=0`, never `word` or `wild`, and builds `documents` from the declared scope alone (both measured).
  8. **Cost.** A search reads every document in scope until `max` matches: 1.3 to 1.6 s and about 4.0 million global references over HSCUSTOM's 10,319 classes. `docnames` and search allocate `^CacheTemp` and may rebuild `^rINDEX`; that stays inside AD-7's fourth shape (inference).
  - **`action/query` has no AD-61 entry yet.** 19.5's spec gate amends rules 2, 3, 5, 7 and 8 for it: its minimum version, a body built only from port-owned statement text plus bound values, its capture behavior, and its measured cost (inference). A call Atelier cannot carry, such as DocDB or Documatic, needs its own named entry or a new port.
- **Reads (AD-36, AD-24, AD-5, AD-60).**
  - One declared read serves the screen and its tool, bounded by the row cap and the per-field (1,000) and total (65,536) bounds. Secret-typed fields never leave the instance.
  - A row may carry one line of code, such as a search match or a macro definition. It is untrusted content, cut by AD-24's per-field bound and passed through AD-60. A document's whole text stays the screen-only payload and never reaches a tool.
  - Query results and cell values are likewise untrusted content (AD-11, AD-60).
  - Only the vendor's own 404 reads as no rows (`Screen/Read.cls` `IsAbsence`); any other 404 code fails the read.
  - A page may issue another built screen's declared read under that screen's gate. Compare issues the viewer's read twice, and 19.7 and 19.8 issue 19.5's reads.
- **SQL and the guard.**
  - Every caller value is bound. Table and column names cannot be bound in statement text. So the identifier path needs a named AD-21 case, or the names are first resolved against `INFORMATION_SCHEMA`; a catalog query that takes them as arguments binds them (inference).
  - One classifier on the instance serves both the console and the agent's SQL tool, and a client-only check is not a gate (AD-10, AD-40; inference). DML and DDL need explicit confirmation in the console and are ordinary confirmed proposals from the agent.
- **The write pattern (19.2, 19.13, 19.3).** Later writes (19.6, 19.8, 19.9) follow it and amend the spine at their own spec gate.
  - **Action-style (AD-51).** The port builds the vendor body from declared arguments, and a port-composed type answers the fresh read. `PRECONDITIONCODES` (Story 18.18) lets a confirm read a declared precondition refusal as target-changed.
  - **Two callers (AD-53, AD-55).** A screen action and the agent's proposal reach one tool. Text the model must not author is a declared `SCREENVALUES` value, and an unadvertised tool is reachable by its screen only.
  - **Per-target lock (AD-34)** and **self-protection (AD-10)**: `PROHIBITED.OCUPILOTCODE` covers any `OcuPilot*` document.
  - **Console output (AD-39's fifth exception)** reaches the screen and the proposal card only.
  - **Audit (AD-15, AD-53).** The stock event set records none of these writes, so each new write measures and names its case.
  - **Classic pages (AD-44).** Each tool lists its `CLASSICPAGES`, or the screen declares it has no classic equivalent.
  - **Codes.** New codes go in `Api/AtelierError.cls` with their Fixed strings. Every write type needs a `Snippet` (AD-59). Read-back (AD-58) and the change event (AD-14) apply.
- **The iris-table-editor harvest.** Keep its call sites, never its names. Lift `SqlBuilder`, `DataTypeFormatter`, `UrlBuilder`, `ErrorHandler`, the model types, `grid-styles.css` (bridged to OcuPilot's tokens) and the CSV helpers. Port three `grid.js` algorithms: keyboard navigation; the filter row and tri-state sort; and staging with primary-key reconciliation and stale-index recovery. Never carry its plaintext-password session.
- **Documatic and agent definitions.** Documatic loads under the browser-level session; a token never enters a frame (AD-28), and the content-security policy names only the instance's origin (AD-47). Moving the default definition is a security change, and the egress line follows the definition a turn uses (AD-42).

## UX & Interaction Patterns

- **The area.** System Explorer is rail position 8. Its side bar lists Classes · Routines · Search · Compare · Macros. The viewer (`<list route>/document`) and the editor (`<list route>/editor/:id`) are unlisted with `sideBarPosition` 0. Prompts use the group "Code".
- **Every screen** registers the 10-item screen contract, at least three suggested prompts, aliases and its Fixed strings. The side bar lists only built screens.
- **Line-cited documents.**
  - System Explorer's Fixed-strings rows in EXPERIENCE.md are :586 to :594; append new rows after :594.
  - The closed dialog set is at :173; a new dialog joins it in place.
  - Edit DESIGN.md only in place, and move every citation the suites hold (`npm run test:tools`).
- **Code** renders as text on `code-surface`, never as markup. Output panes carry a polite live status line. A diff reuses 19.4's `line-diff.ts` and `.ocu-line-diff`.
- **The editor** keeps a sticky Save and Cancel bar, asks "Leave without saving?" before any navigation (AD-11 rule 3), and refuses a conflict by name.
- **Dialogs** are a closed set and never stack. Destructive actions use `typed-name-dialog`: a name for one document, a count for a set.

## Cross-Story Dependencies

- **Done.**
  - 19.1 built the port, the area, the viewers and the four read tools.
  - 19.12 made the floor admit `%Development:USE`. `DeveloperFloor`, `DeveloperFloorRoutes` and `DeveloperFloorTurn` pin a real `%Developer`, and every later screen, tool and route joins those rosters.
  - 19.2 built compile and delete; 19.13 built XML export and import; 19.3 built the editors and the ETag-checked save.
  - 19.4 built Search and Macros, two declared reads exposed as the advertised `explorer.search.read` and `explorer.macro.read`, and Compare, a form page that diffs two viewer reads in the browser. The viewer links to Compare and Macros.
- **19.5 is next.** Its reads are the ones 19.7 and 19.8 later issue. A new screen or read tool trips these rosters:
  - `ExplorerDescriptor`, `ReadTool`, `ToolRoundTrip`, `SurfaceCoverage`, `Descriptor`, and `DeveloperFloor` (screens, tools, reads, count words).
  - `InjectionChannels`, for a new untrusted channel.
  - The client's navigation and mirror tests.
  - A regenerated `screens.generated.ts`.
- **19.6 and 19.11.** 19.6's third criterion and 19.11's second describe one agent SQL tool behind one guard; whichever story introduces it wires it through the guard. 19.8 edits 19.7's grid and may reuse `extraActions` (inference).
- **19.11** builds on the agent definitions and 16.15's egress line. It reuses governance (14.2), the copy-out draft (14.1), the sanitizer (14.3), the read-back (16.17) and Download CSV (16.23).
- **Slot A.**
  - Use the `ocupilot-slot-a` profile. The throwaway is `ocupilot-a2-ci` (52780/1979); this epic's runner owns it, and it is never restarted.
  - Load source by `rsync` into `/tmp/ocupilot-a2-ci/src/`, then run `$System.OBJ.LoadDir`. Run one test class per call.
  - Probes write and remove only their own `OcuProbe*` documents and files.
  - Two reds there are known and outside this epic: `WireSecurityRead`'s task-history cap (DW-1554) and `Retention`'s day-old conversations (DW-1929).
- **Concurrency.**
  - Epic 18 runs on slot B. 18.5 (journals) merged forward into this epic at 19.4's boundary; 18.18 (journal settings) and 18.19 (the record browser) remain.
  - Shared files are edited add-only and unioned by whichever epic reaches feature second: `Baseline.cls`, `GovernanceBaseline`, `ReadTool`, `ToolRoundTrip`, `Governance`, `ToolDispatch`, `ClassicPageGate`, `SurfaceCoverage`, `screen-outlet.ts`, EXPERIENCE.md and the spine.
  - Edits that are not add-only need the lead's approval: `strings.ts` citations, the `strings.test.mjs` Fixed-strings bound (2,100) and the `angular.json` budget.
  - Check `.worktrees/epic-18`'s diff and status before editing a shared file. Regenerate `screens.generated.ts` and `ToolFields.cls`; never hand-merge them.
