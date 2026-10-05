# Epic 19 Context: Stage 3 - System Explorer over the Atelier API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Give developers a System Explorer inside OcuPilot, built on the IRIS Atelier API and in-process ports. Built: code browsing, editing, compiling, export and import; search, compare and macros; the SQL catalog; the guarded query console; and the data browser. Still to come: Documatic and DocDB (19.9), SQL activity (19.10), and an agent picker with guarded agent SQL (19.11). Everything reaches the instance through a port, in process, as the signed-in user, never with the user's password and never by modifying a vendor web application. As in the classic portal, a `%Development` holder gets in.

## Stories

- Story 19.1: Classes and routines, listed and viewed
- Story 19.2: Compile, delete, export and import
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
- Story 19.14: The SQL catalog's remaining detail tabs
- Story 19.15: The query console runs a query in the background
- Story 19.16: The data browser - export, shortcuts, go-to-row and tabs

## Requirements & Constraints

- **One contract (FR-80).** One descriptor per screen; the outside only through a port with its own gate, never an `/api/*` call over HTTP; every agent write a server-minted, fingerprinted, confirmed proposal; every read bounded and reporting truncation; every gate on the caller's own privileges at call time.
- **SQL.** Caller SQL, and any statement a person's choices shape, goes through `Port/SqlPort`, never Atelier's `action/query`, which prepares with privilege checks off (DW-1963). `action/query` carries only the port's fixed statements with validated, bound values.
- **Table rows are screen-only.** Grid pages, save outcomes and console rows, with their SQLCODE and messages, never reach a declared read, a tool's view, screen context, the ledger, an audit payload or a log line. The page's CSV is built in the browser, with no request.
- **19.9 Documatic.** The catalog names a same-origin frame over `/csp/documatic/%25CSP.Documatic.cls?LIBRARY=&CLASSNAME=` under the browser-level session; `%CSP.Documatic` declares no `RESOURCE`, so its web application gates it (inference). The spine names no such path or embed: AD-28 forbids a token in a frame, AD-47's policy names only the instance's origin, and the vendor-editor hand-off is Stage 4. So the spec gate amends the spine for the path and the frame (inference). It measures whether `/csp/documatic` takes the group's browser-level login and whether the shipped policy admits a same-origin frame.
- **19.9 DocDB.** Databases list, create and drop (the catalog's `/api/docdb/v1/:ns`). The spine names no DocDB port: its port list is closed and `AtelierPort` names only `%Api.Atelier.*`, so the spec gate adds one, with its own gate (AD-29), declared by the write tools (AD-52) (inference). The vendor's handlers check `CheckAdmin^%SYS.DOCDB` and `CheckAccess^%SYS.DOCDB`, then call the documented `%SYSTEM.DocDB` (`CreateDatabase(name, type, resource)`, `GetAllDatabases`, `DropDatabase`). AD-27's named cases (repeat the guard, call the documented class) are the precedent (inference). Create and drop are writes: one tool, two callers (AD-53, AD-55), the create fingerprinting absence (AD-54), the drop destructive. The gate decides impact, AD-10 reach, audit event or named gap, and entity type (inference). `DropAllDatabases` is outside the criteria (inference: not carried). The admin API's `/doc-dbs` is the DocDB web-application list, a different thing.
- **19.9 `%Service_DocDB`.** Report whether it is enabled; never assume. `%Api.DocDB`'s dispatch checks it (`CheckServiceStatus^%SYS.DOCDB`), so an in-process call skips that unless the port repeats it (inference, as AD-61 found for `%Development`). Reading it through Security needs `%Admin_Secure:USE` and `%DB_IRISSYS:READ`, which a `%Developer` lacks (inference).
- **19.10.** The classic page `%CSP.UI.Portal.SQL.CurrentStatements` declares `RESOURCE = "%Admin_Operate"`, not `%Development`. It reads `INFORMATION_SCHEMA.CURRENT_STATEMENTS` across every namespace, including `UserName`, `ProcessID`, `Parameters` (bound values) and `CallerName` (read in the export). A port-fixed `action/query` read applies no SQL privilege, so the resource pair is the whole gate (inference). No existing statement read selects a user name, client or call stack, so its spec decides the columns, whether bound values are screen-only, and the area (inference). Cancel is a later catalog row.
- **19.11.** It advertises `explorer.sqlquery.run` behind the console's guard: a mutating statement is a confirmed proposal, prepared in process with checks on (DW-1964). The card shows the real guard (DW-2004: compose the mint's fresh read from the statement). The spec names the called-function limits and decides whether the agent may call path-taking or state-changing procedures (DW-2003). It decides whether SQL rows reach the model, which the spine forbids today (AD-36, AD-39), and whether the agent proposes row changes (`explorer.sqldata.save`). The picker chooses among enabled definitions and the panel names the one in use. Moving the default marker is a security change (AD-42), and the context chip forecasts from the default, so a picked definition changes its source (inference).
- **Who gets in.** The API floor is any `%Admin_*` resource or `%Development:USE`. SQL screens declare `%CSP.UI.Portal.SQL.Home`; the data browser declares `%cspapp.exp.utilsqlopen`, unioning `%cspapp.exp.utilsqlopenview`'s custom resource. A new surface declares its classic page's `RESOURCE`; a screen with none says so (AD-44), as DocDB must. Confirm pair sets with a purpose-built least-privileged principal, never `%Operator`.
- **Governance (AD-22).** After 2026-10-04 the owner decides how a write key enters `Kernel/Governance/Baseline.cls`. That covers 19.9's create and drop, and whether 19.11 turns `explorer.sqlquery.run` on (inference). Ask.
- **Budgets.** After 19.16 the bundle measures 2859kB against a 2860kB warning, so the next client addition crosses it. Re-base `ui/angular.json` and `angular-json.test.mjs` to the measured size (DW-1166); stop and ask above 3800kB. `strings.test.mjs` caps Fixed strings at 2,600, so measure first; raising the cap needs the lead. A new dependency is ask-first, vendored, and runs under the content-security policy.

## Technical Decisions

- **`Port/SqlPort`: reuse, never fork.** `%Prepare(text, 1)` in the target namespace as the user, every value bound, bounded by `$System.Alarm` at `BoundSeconds()` with an open transaction rolled back, each statement released in its own namespace (DW-1986). Caller SQL uses `Run` and `Classify`; the grid uses `BrowsePlan`/`BrowseRun` and `SavePlan`/`Save`, identifiers from privilege-filtered `INFORMATION_SCHEMA` rows (AD-21, AD-61).
- **Person-only SQL writes (AD-53).** `explorer.sqldata.save` and `explorer.sqlquery.run` are unadvertised with keys disabled; target `(class, <ns>, sql)`, a row key bound, never an id (AD-13); no extra pairs, no `CLASSICPAGES`, no vendor audit event (named gaps fifteen and sixteen).
- **Self-protection (AD-10).** `PROHIBITED.OCUPILOTSQL` refuses console text naming `ocupilot` or an `OcuPilot` schema, and a grid read or save of such a table or a view over one. Named limit: DW-1987.
- **The write pattern.** One tool, two callers (AD-53, AD-55); the screen mints no proposal. Each write answers for the per-target lock (AD-34; a Save does not hold it yet, DW-1882), fingerprint and server diff (AD-6, AD-51, AD-54), read-back (AD-58), change event (AD-14), `Snippet` (AD-59), `CLASSICPAGES` (AD-44), audit marker or named gap (AD-15), and a removal's impact (AD-8).
- **A new port names itself in the spine's port list** with its gate (AD-29). A test pins any vendor-internal routine it calls, as AD-61 pins `findmappings^%R`. DocDB's `%SYS.DOCDB` routines are not in the export, so what each requires is measured.
- **`AtelierPort`** alone names `%Api.Atelier.*`: gate first, then version; vendor text logged, never sent; never `%SQL_Manager.StatementIndex` or caller text in `action/query`.
- **Reads (AD-36, AD-24, AD-60).** One declared read serves screen and tool, capped by the row cap, 1,000 characters a field and 65,536 in all, sanitized before the model. A SQL statement's text is a row field, shown cut at 1,021 characters with `...`.

## UX & Interaction Patterns

- **EXPERIENCE.md.** Edit the side-bar line (:159) and the closed dialog set (:173) in place. System Explorer's Fixed strings run from :586 to :600, the table's end, and the data browser's behavior from :671 to :693. The panel header is :699, where a picker would sit (inference). Move every citation the suites hold (`npm run test:tools`).
- **Every screen** registers the ten-item contract, three or more Code-group prompts, aliases and Fixed strings. Viewers, editors and tabs are unlisted (`sideBarPosition` 0).
- **An embedded vendor page** renders in InterSystems' own styling; nothing themes it.
- **Confirmations.** Destructive: `typed-name-dialog`. A data change: `warning-dialog`. Dialogs never stack.
- **Known gaps (range-end cleanup).** A tooltip cannot show text taller than the window (DW-1976), and the SQL table's nine-tab strip hides tabs (DW-1978).

## Cross-Story Dependencies

- **Done:** 19.1 to 19.8 and 19.12 to 19.16. **Order:** 19.9, 19.10, 19.11.
- **19.9 carries DW-2061** (merge gate, option b): in Data browser export only, a number-typed cell whose value fully matches a strict number pattern skips the leading-character guard, with `core/csv.ts` unchanged. It may land instead as a pre-close fix with tests.
- **19.10** reuses the catalog's fixed-statement reads and statement-text field (19.5, 19.14).
- **19.11** reuses governance, the copy-out draft, the sanitizer, the read-back and Download CSV.
- **Rosters a change trips.** Always `ExplorerDescriptor`, `ReadTool` (counts need the lead), `ToolRoundTrip` `REFUSEEMPTY`, `SurfaceCoverage`, `Descriptor` `ReadShapes`, and `DeveloperFloor`'s `SCREENS`, `TOOLS`, `HELDWRITES` and count word "thirty-four". A route: `EndpointCoverage`, `DeveloperFloorRoutes`. A write: `GovernanceBaseline`, `DraftRegistry`. An untrusted channel: `InjectionChannels`. The client's mirror, navigation and self-protection tests, and a regenerated `screens.generated.ts`.
- **Slot A.** Profile `ocupilot-slot-a`; throwaway `ocupilot-a2-ci` (52780/1979), never restarted. Load by `rsync` into `/tmp/ocupilot-a2-ci/src/`, then `$System.OBJ.LoadDir`; its `/tmp` data is exposed to macOS's nightly cleaner (DW-2033), the first suspect for an unexplained red. One test class per call; probes touch only `OcuProbe*` objects.
- **Concurrency.** Epic 18 runs in parallel, with 18.7 open (18.22 to 18.24 split from it). Edit shared files add-only (`Router.cls`, `strings.ts`, `_components.scss`, `Baseline.cls`, roster tests, `screen-outlet.ts`, EXPERIENCE.md, the spine, the bundle budget) after checking `.worktrees/epic-18`'s diff. Regenerate `screens.generated.ts` and `ToolFields.cls`; never hand-merge them.
