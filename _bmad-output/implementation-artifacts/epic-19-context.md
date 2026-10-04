# Epic 19 Context: Stage 3 - System Explorer over the Atelier API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Give developers a System Explorer inside OcuPilot, built on the IRIS Atelier API and on in-process ports. Done so far: classes and routines (listed, viewed, compiled, deleted, exported and imported as XML, edited with ETag-checked saves); search, compare and macro lookup; the full SQL catalog; the SQL query console with its DML and DDL guard; and background query runs. What remains is a data browser harvested from iris-table-editor (a read-only grid in 19.7, then editing, staging and export in 19.8), Documatic and DocDB, SQL activity, and an agent picker with guarded agent SQL. Everything reaches the instance through a port, in process, as the signed-in user. Nothing handles the user's password, and nothing modifies a vendor web application. As in the classic portal, a `%Development` holder with no administrative resource gets in.

## Stories

- Story 19.1: Classes and routines, listed and viewed
- Story 19.2: Compile, delete, export and import (export and import split to 19.13)
- Story 19.3: The source editor, with ETag conflict detection
- Story 19.4: Search, compare and macro lookup
- Story 19.5: The SQL catalog browser (remaining detail tabs split to 19.14)
- Story 19.6: The query console and its DML and DDL guard (run-in-background split to 19.15)
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
  - One descriptor declares each screen. A screen reaches the outside only through a port, and its tools' field lists derive from the descriptor.
  - Every agent write is a server-minted, fingerprinted proposal, with an instance-computed diff, an explicit confirmation and an agent marker.
  - Every read is bounded and reports truncation. Every gate checks the caller's own privileges at call time.
  - Acceptance is this contract plus each row's backing route.
- **No caller-shaped SQL through `action/query` (AD-61 rule 7, DW-1963, DW-1964).** That route prepares with SQL privilege checks off: a principal with no SQL grant read and updated a table through it. Catalog reads use it only for port-owned fixed statements over the privilege-filtered `INFORMATION_SCHEMA`, with values bound. Caller SQL goes through `Port/SqlPort`, which prepares with the checks on.
- **19.7's read path is the binding question.** The grid reads a table's rows through a statement shaped by the person's choices: the table, its columns, a wildcard filter and a sort.
  - Rows come through a path that checks the caller's SQL privileges: `SqlPort`'s prepare with checks on. Never `AtelierPort` or `action/query`.
  - Caller text never reaches the statement. The table and every column the filter or sort names resolve against the caller's privilege-filtered catalog rows first, as the catalog tabs do. Every filter value is bound.
  - iris-table-editor's `SqlBuilder` builds its SQL in the browser for `action/query`. Here the client sends choices and the instance composes the statement from the resolved catalog row, keeping `SqlBuilder`'s rules: `*` becomes `%`, `?` becomes `_`, `LIKE ? ESCAPE '\'`, conditions joined with AND, unknown columns dropped (inference).
- **Open at 19.7's spec gate (each an inference from the spine as it stands).**
  - Are grid rows a declared read (the tool's view and screen context, under AD-24's bounds), or a screen-only payload like the console's (AD-36, AD-39's sixth exception)? Table rows can hold patient data, which is why journal record values are screen-only (AD-36, AD-48).
  - AD-61 says a later call Atelier cannot carry "names itself here", and a grid read run through `SqlPort` is such a call. AD-7's fifth shape covers only the port's fixed statements and the console, while a grid statement varies by table, columns, filter and sort.
  - `PROHIBITED.OCUPILOTSQL` is worded for console statements. Is a grid read of an `OcuPilot` schema refused the same way? It belongs to the same self-protection family.
  - Paging conflicts with the spine. AD-36 and the Operational Envelope cap rows rather than paginate, and the shared data-table has no page-size control. The harvest pages with a `%VID` offset plus a `COUNT(*)` per page, and every page read runs under `SqlPort`'s 50 s alarm.
  - Which classic page does it replace? The classic counterpart is SQL Home's Open Table, `/csp/sys/exp/UtilSqlOpen.csp`. Read its normalized class name and its `RESOURCE` on the instance (AD-44).
- **The iris-table-editor harvest.**
  - Keep its call sites, never its names.
  - **Lift:** the builders and formatters (`SqlBuilder`, `DataTypeFormatter`), the model types, the CSV helpers, and `grid-styles.css`. That stylesheet's `--ite-*` token contract is bridged to OcuPilot's tokens.
  - **Port three `grid.js` algorithms:** keyboard navigation, the filter row with tri-state sort, and staging with primary-key reconciliation, including stale-index recovery after pagination. Delete `grid.js`'s nine drifted formatter clones.
  - **Do not carry:** its Atelier services (hardcoded Basic auth, `Buffer.from`, raw `fetch`), or its plaintext-password-in-server-memory session.
  - **Limits carried knowingly:**
    - Primary keys are single-column only: `IS_IDENTITY`, falling back to a column named `ID`.
    - The identifier regex refuses delimited names.
    - `rowsAffected` always reads 1.
    - `%VID` paging re-reads the preceding rows on every page.
    - A failed count shows zero rows.
    - Undo works in edit mode only.
- **Who gets in.**
  - Any `%Admin_*` resource or `%Development:USE` passes the floor. A `%Development`-only caller is refused wherever a classic `%Developer` is.
  - The SQL screens declare `%CSP.UI.Portal.SQL.Home` (`%Development`). Read any other classic page's `RESOURCE` in `irissys/` or on the instance, never from memory.
- **Other backing routes.**
  - 19.9: Documatic is at `/csp/documatic/%25CSP.Documatic.cls`, and DocDB at `/api/docdb/v1/:ns`. DocDB needs `%Service_DocDB` enabled: report whether it is, never assume.
  - 19.10: `INFORMATION_SCHEMA.CURRENT_STATEMENTS`. Canceling another session's query is a separate, later catalog row.
- **Governance (AD-22).**
  - A new write key gets its line in `Kernel/Governance/Baseline.cls` in the same change, and a new destructive key ships disabled. Read tools add no key.
  - After 2026-10-04, the owner decides how new keys enter the baseline.
- **New dependencies are ask-first.** A dependency must be vendored with no CDN, must run under the content-security policy, and counts toward the bundle.
- **Budgets.**
  - **Bundle.** The warning is 2704kB, and Epic 18's literal (2712kB) meets it at merge. A UI addition that crosses the warning re-bases `ui/angular.json` and `angular-json.test.mjs` to the new measured size (DW-1166). Stop and ask above 3800kB.
  - **Fixed strings.** `strings.test.mjs` bounds them at 2500. Measure before adding a row. Raising the bound needs the lead.
- **Measure, never assume.** Take pair sets from the handler's checks, then confirm them with a purpose-built least-privileged principal on the throwaway, never `%Operator`.
- **DW-1001.** A new read tool records an occurrence. The fix lands in Epic 19's close burn-down.

## Technical Decisions

- **`Port/SqlPort` (AD-61's SQL case): reuse it, never fork it.**
  - **Gate.** AtelierPort's read pairs (`PAIRS`, `NamespacePairs(ns)`), plus the screen's gate with its classic page. It names no `%Api.Atelier.*` class and uses no capture.
  - **Prepare.** The statement is prepared whole with `%SQL.Statement.%Prepare(text, 1)`, in the target namespace (explicit save and restore, AD-16), in the request's own process, as the signed-in user. No escalated frame is open, and values are bound positionally.
  - **Privileges do not rest on the statement cache (DW-1986).** Each statement is released in the namespace it was prepared in. A DDL statement whose type ties to a system privilege is refused -99 unless `%CHECKPRIV` says the caller holds that privilege.
  - **Classify.** It classifies by the prepared `statementType` through a closed table. The `query` kind is types 1, 28, 32 and 79. It refuses:
    - session and process control;
    - administration of users, roles, privileges and databases;
    - server-file and other-server statements;
    - text that sets a password, before any prepare.
  - **Bounds.**
    - Inputs: a statement of 1 to 100,000 characters, at most 100 values of up to 32,767 characters each, and Max rows from 1 to 1,000.
    - Cuts: a cell at 1,000 characters and an answer at 1,000,000, by whole rows. `truncated` reports either cut.
    - Queries and DML run under `$System.Alarm` at `BoundSeconds()`, 50 s against a 60 s gateway. Past it, the answer is `stopped`.
    - A transaction a run leaves open is rolled back. `Explain` executes nothing.
  - **Entry points.** `Gate`, `Classify` and `Run(ns, text, values, maxRows, mode, …)`. A grid statement is composed by the port, not taken from caller text, so 19.7 decides whether it enters through `Run` or a new `SqlPort` method (inference).
- **The catalog family (19.5, 19.14), through `AtelierPort`.**
  - **Endpoints.** `Catalog.*` endpoints over `action/query` (v6). Each sends a fixed statement, with validated values in `parameters`.
  - **Resolve first.** A table's tab resolves through the caller's privilege-filtered `INFORMATION_SCHEMA.TABLES` row first: none answers 404, two answer 400. Views resolve through `VIEWS` and procedures through `ROUTINES`.
  - **Tree.** SQL tables' read takes `system` and `schema` criteria. HSCUSTOM holds 2,066 tables, past the 1,000 row cap, so a schema tree reads one schema at a time (inference).
  - **Keys.** The Fields read carries no identity or primary-key field. Primary-key detection needs a catalog addition (inference): the harvest reads `INFORMATION_SCHEMA.COLUMNS` `IS_IDENTITY`, falls back to a column named `ID`, and treats `IS_GENERATED` columns as read-only.
  - **Reuse.** A page may issue another built screen's declared read through the read route, under that screen's gate, cap and fields (AD-5).
  - **AtelierPort's rules.**
    - It is the only class that names `%Api.Atelier.*`.
    - It gates first: `%Development:USE`, then READ on the routines, globals and mapped code databases, per namespace. A write also needs WRITE on the routines database.
    - Below an endpoint's version it answers `PORT.NOTIMPLEMENTED`. Vendor text is logged, never sent.
    - It never uses `docnames`' `filter`, `POST modified`, the `work` routes, search's `regex`, `word` or `wild`, a catalog `pFilter`, or `%SQL_Manager.StatementIndex`. No statement read selects a user name, client or call stack.
- **Reads (AD-36, AD-24, AD-60).**
  - One declared read serves both the screen and its tool. It is bounded by the row cap (1 to 1,000), 1,000 characters a field and 65,536 in all, and it reports `rowsSent`, `rowsAvailable` and `truncated`.
  - Row text is untrusted, and it is sanitized before it reaches the model. `read.note` is one fixed sentence.
  - A console run's rows and plan are a screen-only payload. They never become a declared read, a tool's view, screen context, a log line, a ledger row or an audit payload, and they are never stored except in 19.15's owner-only run row.
- **SQL text (AD-21).** Every caller value is bound, and shape validation never substitutes for binding. The console prepares the caller's own statement whole. Named limit: a function or procedure that a statement calls can reach a server path or change state while the statement is typed as a query (DW-2003).
- **Self-protection (AD-10).**
  - `PROHIBITED.OCUPILOTSQL` refuses a console statement on every path, reads included, when:
    - its text names `ocupilot`;
    - its recorded tables, a view's base tables included, lie in an `OcuPilot` schema;
    - it records no tables while the instance's default schema is an `OcuPilot` one.
  - It is one predicate in `Kernel/Proposal/Prohibited.cls`. Documents fall under `PROHIBITED.OCUPILOTCODE`.
- **Background runs (19.15, done).**
  - `Area/Explorer/SqlBackground` is AD-42's fourth spawn site. The job runs only the `query` kind and checks the gates once (AD-31).
  - `Kernel/State/SqlRun` keeps each run owner-only, for 900 s, and is swept at every start and by retention. Anyone else's run answers 404.
  - Caps are 1 per user and 5 per instance. Task 0 found five runs holding 7 of 8 Community license units.
- **The write pattern, for 19.8 and 19.9.**
  - One tool has two callers (AD-53, AD-55), and the screen mints no proposal.
  - Each write answers for its target (AD-34's lock, AD-6's fingerprint), the server-computed diff, the read-back (AD-58), the change event (AD-14), the `Snippet` form (AD-59), `CLASSICPAGES` (AD-44), new error codes, and its audit (AD-15).
  - A grid write cannot use `action/query`. It runs port-owned statements through `SqlPort` (inference).
  - `explorer.sqlquery.run` is AD-53's third unadvertised tool, and its key stays disabled until 19.11 advertises it. AD-53's fifteenth gap: no vendor event records a console run.
- **Documatic and agent definitions.** Documatic loads under the browser-level session, and no token enters a frame (AD-28). The content-security policy names only the instance's origin (AD-47). Moving the default definition is a security change (AD-42).

## UX & Interaction Patterns

- **The area.**
  - System Explorer is rail position 8. Its side bar (EXPERIENCE.md :159) reads Classes · Routines · Search · Compare · Macros · SQL schemas · SQL tables · SQL views · SQL procedures · SQL query.
  - Viewers, editors and tabs are unlisted (`sideBarPosition` 0). Prompts use the group `webAppPromptGroupCode`.
  - Every screen registers the 10-item contract, at least three prompts, its aliases and its Fixed strings.
- **EXPERIENCE.md.**
  - System Explorer's Fixed-strings rows are :586 to :597. SQL query, at :597, is the table's last row, so new rows go after it.
  - Edit the side-bar line :159 and the dialog set :173 in place.
  - Move every citation the suites hold (`npm run test:tools`).
- **Lists and the grid.**
  - The shared data-table uses CDK virtual scroll up to the max-rows cap, with client-side sort and filter, a "N rows · Max rows" footer, no page-size control, and Download CSV. The CSV keeps a formula prefix `'`, a UTF-8 byte-order mark and CRLF line ends.
  - Tables follow the APG grid pattern: `role="grid"`, one Tab stop and `aria-activedescendant`.
  - The data browser's grid is the ported harvest. It draws OcuPilot's design tokens, never its own palette, with no hardcoded colors (enforced by lint). 19.8 requires its accessibility to match the portal's rather than the original's.
- **Rendering.** Code renders as text on `code-surface`. Output panes carry a polite live status line. A diff reuses `line-diff.ts`.
- **Dialogs.**
  - Dialogs are a closed set, and they never stack.
  - Destructive actions use `typed-name-dialog`.
  - The console's "Run this statement?" dialog opens only on a server `confirm`.
- **Known shared-UI gaps, routed to range-end cleanup.** A long cell clips, and its tooltip cannot show text taller than the window (DW-1976). A nine-tab strip hides tabs (DW-1978).

## Cross-Story Dependencies

- **Done:** 19.1, 19.12, 19.2, 19.13, 19.3, 19.4, 19.5, 19.14, 19.6 and 19.15.
- **Next: 19.7.**
  - It takes the schema tree from the SQL schemas and SQL tables reads, and the column metadata from Fields.
  - It reads rows through `SqlPort`'s prepare with privilege checks on.
- **19.8** builds on 19.7's grid:
  - editing, staged saves, CSV export, the keyboard help, go-to-row, ARIA and multi-table tabs;
  - every save is confirmed;
  - it may reuse `extraActions` and the data-table's Download CSV rules (inference).
- **19.11.**
  - It advertises `explorer.sqlquery.run` behind the same guard.
  - DW-2004: on a screen action, the fresh read carries no statement. So the agent's card must compose the guard from the proposed statement.
  - It decides DW-2003's limit on functions and procedures.
  - It adds the picker and 16.15's egress line, and reuses governance (14.2), the copy-out draft (14.1), the sanitizer (14.3), the read-back (16.17) and Download CSV (16.23).
- **19.10.** The rule against identifying columns binds the statements tabs. 19.10 lists other sessions' statements, so its spec decides its own columns and gate (inference).
- **Rosters a new screen, route or tool trips.**
  - `ExplorerDescriptor`, `ReadTool` (its counts need the lead), `ToolRoundTrip` `REFUSEEMPTY`, `SurfaceCoverage` and `Descriptor` `ReadShapes`.
  - `DeveloperFloor`: `SCREENS`, `TOOLS` and the count word "thirty-three".
  - For a new route: `EndpointCoverage` and `DeveloperFloorRoutes`. For a new untrusted channel: `InjectionChannels`.
  - The client's navigation, mirror, rail-wire and self-protection tests, and a regenerated `screens.generated.ts`.
  - For a write tool: `GovernanceBaseline` and `DraftRegistry`.
- **Slot A.**
  - Use the profile `ocupilot-slot-a`. The throwaway is `ocupilot-a2-ci` (52780/1979), and it is never restarted.
  - Load source by `rsync` into `/tmp/ocupilot-a2-ci/src/`, then run `$System.OBJ.LoadDir`.
  - Run one test class per call.
  - Probes create and remove only their own `OcuProbe*` objects.
- **Concurrency.**
  - Epic 18 runs in parallel, and 18.20 is in implement.
  - Shared files are edited add-only and unioned by whichever epic reaches the feature branch second. They include `Router.cls`, `strings.ts`, `_components.scss`, `Baseline.cls`, `GovernanceBaseline`, `ReadTool`, `ToolRoundTrip`, `ToolDispatch`, `ClassicPageGate`, `SurfaceCoverage`, `EndpointCoverage`, `screen-outlet.ts`, EXPERIENCE.md, the spine and the bundle budget.
  - Check `.worktrees/epic-18`'s diff before editing a shared file.
  - Regenerate `screens.generated.ts` and `ToolFields.cls`; never hand-merge them.
