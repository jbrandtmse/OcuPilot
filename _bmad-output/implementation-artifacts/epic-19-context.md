# Epic 19 Context: Stage 3 - System Explorer over the Atelier API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Give developers a System Explorer inside OcuPilot, built on the IRIS Atelier API and on in-process ports. Already built: code browsing, editing and compiling; search, compare and macros; the SQL catalog; the query console with its DML and DDL guard and background runs; and a read-only data browser, a grid ported from iris-table-editor. Still to build: grid editing, staging and export (19.8), Documatic and DocDB (19.9), SQL activity (19.10), and an agent picker with guarded agent SQL (19.11). Everything reaches the instance through a port, in process, as the signed-in user. Nothing handles the user's password, and nothing modifies a vendor web application. As in the classic portal, a `%Development` holder with no administrative resource gets in.

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

## Requirements & Constraints

- **One contract (FR-80).**
  - One descriptor per screen, and the outside is reached only through a port.
  - Every agent write is a server-minted, fingerprinted, confirmed proposal.
  - Every read is bounded and reports truncation.
  - Every gate checks the caller's own privileges at call time.
- **No caller-shaped SQL through Atelier's `action/query`.** It prepares with SQL privilege checks off (DW-1963), so caller SQL and any statement shaped by a person's choices go through `Port/SqlPort`, which prepares with the checks on.
- **Table rows are screen-only.** Grid pages and console rows, with their SQLCODE and messages, never reach a declared read, a tool's view, screen context, the ledger, an audit payload or a log line. An arbitrary table's columns carry no reviewed classification (AD-3), and they can hold patient data.
- **19.8, the grid editor** (catalog rows EX-25 to EX-31 and EX-33).
  - **Editing.** Type-specific editors use the harvest's `DataTypeFormatter` parsers, never its display functions (they shift dates to UTC and lose precision past 2^53). Undo works in edit mode. Rows can be inserted, duplicated and deleted.
  - **Saving.** Every save is a confirmed write, applied optimistically and rolled back on failure. Staged saves reconcile by primary key, which recovers a stale index after paging. The harvest hard-coded `rowsAffected` as 1, so read the instance's real count (inference).
  - **Around the grid.** CSV export of the page; keyboard shortcuts with a help dialog; a go-to-row dialog; ARIA announcements that match the portal, not the original; and multi-table tabs.
  - **DW-2028.** Port the shared data-table's cut-cell tooltip (`shell/data-table.ts`, on pointer and on the active cell).
- **Open at 19.8's spec gate.** Each is an inference from a spine with no grid-write case yet, and each answer is named in the spine:
  - an agent tool, or only a person's own Save, as 19.6 did with an unadvertised tool whose key ships disabled;
  - how the diff, fingerprint, ledger and read-back treat row values;
  - a row's target identity (AD-13: a composite key is still one segment) and entity type (AD-14's closed enum);
  - its `Snippet` (AD-59);
  - its audit gap: no vendor event records SQL DML with the stock event set, as measured for console runs.
- **Who gets in.**
  - The API floor is any `%Admin_*` resource or `%Development:USE`.
  - The SQL screens declare `%CSP.UI.Portal.SQL.Home`.
  - The data browser declares `%cspapp.exp.utilsqlopen`, and its route unions `%cspapp.exp.utilsqlopenview`'s custom resource.
  - Read any other classic page's `RESOURCE` in `irissys/` or on the instance.
- **Other backing routes.**
  - 19.9: Documatic at `/csp/documatic/%25CSP.Documatic.cls`, and DocDB at `/api/docdb/v1/:ns`. DocDB needs `%Service_DocDB`: report whether it is enabled, never assume.
  - 19.10: `INFORMATION_SCHEMA.CURRENT_STATEMENTS`, whose classic page is `%CSP.UI.Portal.SQL.CurrentStatements`. Canceling another session's query is a later catalog row.
- **Governance (AD-22).** A new write key joins `Kernel/Governance/Baseline.cls` in the same change. After 2026-10-04 the owner decides how it enters the baseline, so ask.
- **Budgets.**
  - Bundle: the warning is 2780kB. Crossing it re-bases `ui/angular.json` and `angular-json.test.mjs` to the measured size (DW-1166). Stop and ask above 3800kB.
  - Fixed strings: `strings.test.mjs` caps them at 2,500. 19.7 measured 2,382 before its own row, so measure first. Raising the cap needs the lead.
- **Measure, never assume.**
  - Confirm pair sets with a purpose-built least-privileged principal on the throwaway, never `%Operator`.
  - A new dependency is ask-first, vendored with no CDN, and must run under the content-security policy.

## Technical Decisions

- **`Port/SqlPort`: reuse, never fork.**
  - **Gate.** AtelierPort's read pairs plus the screen's gate.
  - **Prepare.** `Executed` prepares with `%Prepare(text, 1)` in the target namespace (explicit save and restore), as the user, with values bound positionally.
  - **Bounds.** Each run is bounded by `$System.Alarm` at `BoundSeconds()` (50 s), and past it the answer is `stopped`. An open transaction is rolled back.
  - **Statement cache.** Each statement is released in its own namespace, so privileges never rest on the cache (DW-1986).
  - **Caller SQL** (the console, and 19.11's agent tool) goes through `Run` and `Classify`. They use a closed `statementType` table and refuse session control, administration, server files and password text. An unrecorded query or DML is refused 422 `EXPLORER.SQL.UNRECORDED`.
- **The grid reads through `BrowsePlan` and `BrowseRun`, never `Classify`.**
  - The table and columns resolve against the caller's privilege-filtered `INFORMATION_SCHEMA.TABLES` and `COLUMNS` rows.
  - The key is the primary-key constraint's columns (composite allowed), else `IS_IDENTITY`, else a column named `ID`.
  - Pages use `OFFSET`/`FETCH` plus a `COUNT(*)`, 50 to 500 rows, with cells cut at 1,000 characters.
  - Grid writes run port-composed statements through `SqlPort`, a rule 19.7 hands to 19.8.
  - Identifiers come from the catalog rows, delimited with `"` doubled, and every value is bound (AD-21). Each distinct composed statement records one statement-index row (AD-7).
- **Self-protection (AD-10).** `PROHIBITED.OCUPILOTSQL` lives in `Kernel/Proposal/Prohibited.cls`.
  - It refuses a console statement that names `ocupilot` or touches an `OcuPilot` schema.
  - It refuses a grid read of such a table before any statement, and a read of a view over one before any row.
  - Named limit: DW-1987, a view grant whose base tables the caller cannot read.
- **The write pattern.**
  - One tool has two callers (AD-53, AD-55). The screen mints no proposal; the confirm dialog is its review.
  - Each write answers for:
    - the per-target lock (AD-34; a Save does not hold it yet, DW-1882);
    - the fingerprint (AD-6) and the server-computed diff;
    - the read-back (AD-58);
    - the change event (AD-14);
    - the port's `Snippet` (AD-59);
    - `CLASSICPAGES` (AD-44);
    - the audit marker, or a named gap (AD-15).
  - 19.11 advertises `explorer.sqlquery.run`, whose key stays disabled until then.
- **`AtelierPort`** (19.10's fixed statements) is the only class that names `%Api.Atelier.*`.
  - It gates first, then checks versions, and it never sends vendor text.
  - It never uses `docnames`' `filter`, `POST modified`, the `work` routes, search's `regex`, a catalog `pFilter` or `%SQL_Manager.StatementIndex`.
  - No statement read selects a user name, client or call stack.
- **Reads (AD-36, AD-24, AD-60).** One declared read serves a screen and its tool. It is capped by the row cap, 1,000 characters a field and 65,536 in all. Its row text is sanitized before it reaches the model.
- **Documatic and agents.** Documatic loads under the browser-level session, and no token enters a frame (AD-28). The content-security policy names only the instance's origin (AD-47). Moving the default agent definition is a security change (AD-42).

## UX & Interaction Patterns

- **EXPERIENCE.md.**
  - Edit the side-bar line (:159) and the closed dialog set (:173) in place. Dialogs never stack.
  - System Explorer's Fixed-strings rows run from :586 to :598, the table's last row, so new rows go after :598.
  - Move every citation the suites hold (`npm run test:tools`).
- **Every screen** registers the ten-item contract, at least three Code-group prompts, its aliases and its Fixed strings. Viewers, editors and tabs are unlisted (`sideBarPosition` 0).
- **The data browser.**
  - Tree on the leading side, grid on the rest; below the narrow breakpoint they stack.
  - The grid follows the APG pattern: `role="grid"`, one Tab stop, `aria-activedescendant`.
  - It uses `--ocu-*` tokens only, with no hardcoded colors (enforced by lint).
- **CSV (the data-table's rule).** Cells are written as displayed. A leading `=`, `+`, `-`, `@`, tab or carriage return is prefixed with `'`. UTF-8 with a byte-order mark, CRLF, named `<screen>-<YYYYMMDD>-<HHMMSS>.csv`.
- **Confirmations.** A destructive action uses `typed-name-dialog`. A data change confirms with "Run this statement?".
- **Known gaps, routed to range-end cleanup.** A tooltip cannot show text taller than the window (DW-1976). A nine-tab strip hides tabs (DW-1978).

## Cross-Story Dependencies

- **Done:** 19.1 to 19.7, and 19.12 to 19.15.
- **19.8 consumes 19.7's work:** the grid, the store's filter, sort and offset state, the `columns` and `key` shapes, and the writes-through-`SqlPort` rule.
- **19.11.**
  - It advertises `explorer.sqlquery.run` behind the console's guard.
  - It shows the real guard on the agent's card (DW-2004).
  - It decides the limit on called functions and procedures (DW-2003), and whether grid rows ever reach the model.
  - It reuses governance, the copy-out draft, the sanitizer, the read-back and Download CSV.
- **19.10** lists other sessions' statements, so its spec decides its columns and gate (inference).
- **Rosters a change trips.**
  - Always: `ExplorerDescriptor`, `ReadTool` (its counts need the lead), `ToolRoundTrip` `REFUSEEMPTY`, `SurfaceCoverage`, `Descriptor` `ReadShapes`, and `DeveloperFloor`'s `SCREENS`, `TOOLS`, `HELDWRITES` and count word "thirty-three".
  - A route: `EndpointCoverage` and `DeveloperFloorRoutes`. A write: `GovernanceBaseline` and `DraftRegistry`. An untrusted channel: `InjectionChannels`.
  - The client's mirror, navigation and self-protection tests, and a regenerated `screens.generated.ts`.
- **Slot A.**
  - Use the profile `ocupilot-slot-a` and this epic's throwaway, `ocupilot-a2-ci` (52780/1979), which is never restarted.
  - Load by `rsync` into `/tmp/ocupilot-a2-ci/src/`, then `$System.OBJ.LoadDir`.
  - Run one test class per call. Probes touch only their own `OcuProbe*` objects.
- **Concurrency.**
  - Epic 18 runs in parallel, with 18.21 open.
  - Edit shared files add-only: `Router.cls`, `strings.ts`, `_components.scss`, `Baseline.cls`, the roster tests, `screen-outlet.ts`, EXPERIENCE.md, the spine and the bundle budget. Check `.worktrees/epic-18`'s diff first.
  - Regenerate `screens.generated.ts` and `ToolFields.cls`; never hand-merge them.
