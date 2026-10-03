# Epic 19 Context: Stage 3 - System Explorer over the Atelier API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Give developers a System Explorer inside OcuPilot, built on the IRIS Atelier API. Classes and routines are already listed, viewed, compiled, deleted, exported and imported as XML, edited with a save checked against the version it read, searched and compared, and their macros can be looked up. The SQL catalog already lists schemas, tables, views and procedures, and a table opens to its first five catalog tabs. The rest of the stage adds the catalog's remaining detail tabs, a query console behind a DML and DDL guard, a data grid harvested from iris-table-editor, Documatic, DocDB, SQL activity, and an agent picker with guarded agent SQL. Everything reaches Atelier through one port, `Port/AtelierPort`, in process as the signed-in user. It never handles the user's password and never modifies a vendor web application. As in the classic portal, a `%Development` holder with no administrative resource gets in. Every screen keeps the one contract earlier stages followed.

## Stories

- Story 19.1: Classes and routines, listed and viewed
- Story 19.2: Compile, delete, export and import (export and import split to 19.13)
- Story 19.3: The source editor, with ETag conflict detection
- Story 19.4: Search, compare and macro lookup
- Story 19.5: The SQL catalog browser (remaining detail tabs split to 19.14)
- Story 19.6: The query console and its DML and DDL guard
- Story 19.7: The data browser - tree, grid, filter and sort
- Story 19.8: The data browser - editing, staging and export
- Story 19.9: Documatic and DocDB
- Story 19.10: SQL activity
- Story 19.11: The agent gains guarded SQL and a picker
- Story 19.12: A %Development holder reaches System Explorer, as the classic portal allows
- Story 19.13: XML export and import
- Story 19.14: The SQL catalog's remaining detail tabs

## Requirements & Constraints

- **One contract (FR-80).** One descriptor declares each screen, the screen reaches the outside through one port, and the tools' field lists derive from it. Every agent write is a server-minted proposal with an instance-computed diff, an explicit confirmation and an agent marker. Every read is bounded and reports truncation. Every gate checks the caller's own privileges at call time. Acceptance is this contract plus each row's backing route.
- **`action/query` gates the stage.** It runs any statement type, applies no row limit, and prepares every statement with SQL privilege checks off (measured; DW-1963).
  - A catalog read sends only a port-owned fixed statement, with every caller value bound in `parameters`. It never sends a catalog query's `pFilter`.
  - Caller SQL never passes through `action/query`. The console (19.6) and the agent's SQL tool (19.11) prepare in process with privilege checks on (DW-1964, routed to 19.6). The spine does not yet name the class that owns that prepare.
  - The guard ships with the console, never after it.
- **19.14's open questions**, carried from 19.5's plan. Each needs a decision at 19.14's plan or spec gate:
  - `StatementIndex` answers other users' statement text, user names, client addresses and call stacks to any `%Development` holder. It also calls `CheckAggregateStats^%SYS.SQLSRV`, which may write (inference).
  - `Partitions` fails the whole fetch (#31007) on a table that is not partitioned.
  - A view's full SQL and a procedure's description would become row text. AD-36 so far admits only one line of code, or a trigger's code, as a row field.
  - `ProcedureInfo` declares `RETURN_VALUE` twice, so the route's object rows keep only the second.
- **Detail-tab privilege.** A table's tab answers only for a table that the caller's own privilege-filtered `INFORMATION_SCHEMA.TABLES` row shows. This is stricter than the classic page. `Indices`, `Triggers` and `Constraints` do not filter by SQL privilege (measured). A view's or procedure's tab needs the same resolve against its own information-schema table (inference).
- **Classic parity (AD-44).** Every catalog screen declares `%CSP.UI.Portal.SQL.Home` (`%Development`). That page has nine table tabs, two view tabs and two procedure tabs. `SQL/QButtons/RuntimeStats` declares `%Development:USE`.
- **Other backing routes.**
  - 19.9: Documatic at `/csp/documatic/%25CSP.Documatic.cls`, and DocDB at `/api/docdb/v1/:ns`. DocDB needs `%Service_DocDB` enabled: report that, never assume it.
  - 19.10: `INFORMATION_SCHEMA.CURRENT_STATEMENTS`. Canceling a statement is Stage 4.
  - A call Atelier cannot carry is named in AD-61 or gets its own port.
- **The agent never authors code.** No tool schema carries document text. A local file's text is a screen-only action value of at most 3,000,000 characters, and the editor's save is screen-only.
- **Who gets in.** Any `%Admin_*` resource or `%Development:USE` passes the floor. A `%Development`-only caller is refused wherever a classic `%Developer` is.
- **Governance (AD-22).** A new write key gets its line in `Kernel/Governance/Baseline.cls` in the same change, and a new destructive key ships disabled. From 2026-10-04 the owner decides how new keys enter the baseline. Read tools add no key.
- **New dependencies (Rule 5).** These are ask-first. A dependency must be vendored with no CDN, run under the content-security policy, and count toward the bundle.
- **Budgets.**
  - **Bundle.** The initial-bundle warning is 2,595 kB, against 2,594,351 bytes measured after the 18.18 merge, so any UI addition crosses it. Re-base `ui/angular.json` and `angular-json.test.mjs` to the measured size (DW-1166). Stop and ask above 3,800 kB; the hard error is 4,000 kB.
  - **Fixed strings.** The `strings.test.mjs` bound is 2,300, against 2,179 literals measured now. Raising it needs the lead.
- **Harvest limits carried knowingly (19.7, 19.8).**
  - Only single-column primary keys.
  - The identifier pattern refuses delimited names.
  - `rowsAffected` always reads 1.
  - `%VID` offset paging re-reads earlier rows and runs a `COUNT(*)` per page. A failed count shows zero rows.
- **Measure, never assume.** Take pair sets from the handler's checks plus a purpose-built least-privileged principal on the throwaway, never `%Operator`. Read a classic page's `RESOURCE` in `irissys/` or on the instance.
- **The ledger.**
  - DW-1001: derived read tools describe a text criterion as a comma list where `*` matches. A new read tool records an occurrence and leaves the fix to Epic 19's burn-down story. AD-36 now lets a criterion declare `hint` (Story 18.19, not yet on this branch), which is the mechanism that fix can use (inference).
  - DW-1957, DW-1958 and DW-1963 are vendor-defect candidates. The owner decides whether to report them, and no story acts on them.

## Technical Decisions

- **AD-61: the Atelier port.** `Port/AtelierPort` is the only class that names `%Api.Atelier.*`, through parameters only. It calls route methods in the caller's process, one at a time.
  1. **Gate first.** `%Development:USE`, then READ per namespace on the routines, globals and mapped code databases (never IRISSYS). A write also needs WRITE on the routines database. A refusal names the pair.
  2. **Version.** The port calls `v<min(N, 8)>`. Each endpoint's minimum is in `MINVERSIONS` (`Query` 6; the XML routes 7; search and macros 2). An older instance gets `PORT.NOTIMPLEMENTED` before any call.
  3. **Stub CSP state.** A body the port builds goes to the stub's content stream. A catalog body is `{query, parameters}`, and a tab binds the schema and table that the resolve row answers.
  4. **Namespace.** Switched by save and restore around the vendor call only (AD-16).
  5. **Capture.** The ceiling is about 3.6 million characters (`PORT.UNAVAILABLE`). Only `action/index` goes through a temporary file. `Query` ran 400 calls under the capture with no process death (19.5's Task 0; not recorded in the spine).
  6. **Outcome.**
     - 404 is `PORT.NOTFOUND`, unlogged on a read; 400 is `PORT.VALIDATION`.
     - Soft refusals and `<PROTECT>` are `PORT.ACCESSDENIED`.
     - `action/query` answers a SQL error with 200 and `status.errors` and discards the rows it fetched. The port makes that 500 `INTERNAL`.
     - Vendor text is logged, never sent.
  7. **Never used:**
     - `docnames`' `filter`, `POST modified` and the `work` routes.
     - Search's `regex`, `word` and `wild`.
     - Caller text in `query`, and a catalog query's `pFilter`.
  8. **Cost.** Each read's cost is measured and named in the spine. A catalog read is cheap.
- **AD-7's fifth shape.** A fixed statement's first prepare records a statement-index row and may record a cached query. Neither is a mutation in AD-7's sense.
- **AD-5: parent-scoped tab group.** Every member names the same `parentScope` and its one criterion, and the head is the parent list's `<route>/document`. The tab strip carries the route id. `Screen/Registry.cls` and `ui/tools/screen-mirror.mjs` validate this alike. 19.14 builds on this mechanism and on 19.5's port family.
- **Reads (AD-36, AD-24, AD-60).**
  - One declared read serves the screen and its tool. It is bounded by the row cap and by the per-field (1,000) and total (65,536) bounds. Secret-typed fields never leave the instance.
  - A row may carry one line of code: a search match, a macro definition or a trigger's code. Such a field is untrusted, cut by the per-field bound and sanitized.
  - A document's whole text is the screen-only payload and never reaches a tool.
  - Only the vendor's own 404 reads as no rows.
  - A page may issue another built screen's read under that screen's gate.
- **SQL.**
  - Every caller value is bound. 19.5 resolves a name against `INFORMATION_SCHEMA` first and then binds the resolved name.
  - A data grid's identifiers cannot be bound in statement text, so they need that resolve or a named AD-21 case (inference).
  - Query results and cell values are untrusted content (AD-11, AD-60).
- **The write pattern (19.2, 19.13, 19.3).** 19.6, 19.8 and 19.9 follow it and amend the spine at their own spec gates.
  - **Action-style (AD-51).** `PRECONDITIONCODES` lets a confirm read a declared precondition refusal as target-changed.
  - **One tool, two callers (AD-53, AD-55).** Text the model must not author is a `SCREENVALUES` value. An unadvertised tool can be reached only from its screen.
  - **Protection.** Writes take a per-target lock (AD-34). `PROHIBITED.OCUPILOTCODE` covers any `OcuPilot*` document (AD-10).
  - **Console output** reaches only the screen and the proposal card (AD-39).
  - **Audit (AD-15).** The stock events record none of these writes, so each write names its case.
  - **Per tool.** Each tool lists its `CLASSICPAGES` (AD-44). New codes go in `Api/AtelierError.cls`. Each write type needs a `Snippet` (AD-59), and read-back (AD-58) and the change event (AD-14) apply.
- **The iris-table-editor harvest.** Keep its call sites, never its names.
  - Lift `SqlBuilder`, `DataTypeFormatter`, `UrlBuilder`, `ErrorHandler`, the model types, `grid-styles.css` (bridged to OcuPilot's tokens) and the CSV helpers.
  - Port three `grid.js` algorithms: keyboard navigation; the filter row with tri-state sort; and staging with primary-key reconciliation and stale-index recovery.
  - Never carry its plaintext-password session.
- **Documatic and agent definitions.**
  - Documatic loads under the browser-level session, and no token enters a frame (AD-28). The content-security policy names only the instance's origin (AD-47).
  - Moving the default definition is a security change, and the egress line follows the definition a turn uses (AD-42).

## UX & Interaction Patterns

- **The area.** System Explorer is rail position 8. Its side bar: Classes · Routines · Search · Compare · Macros · SQL schemas · SQL tables · SQL views · SQL procedures.
  - Viewers, editors and tabs are unlisted (`sideBarPosition` 0), and the side bar marks a tab's parent list.
  - Prompts use the group "Code".
- **Every screen** registers the 10-item contract, at least three prompts, aliases and its Fixed strings.
- **EXPERIENCE.md.**
  - System Explorer's Fixed-strings rows are :586 to :595; append new rows after :595.
  - Edit the side-bar line :159 and the dialog set :173 in place.
  - Move every citation the suites hold (`npm run test:tools`).
- **Code** renders as text on `code-surface`. Output panes carry a polite live status line. A diff reuses `line-diff.ts`.
- **The editor** keeps a sticky Save and Cancel bar, asks "Leave without saving?" before navigating, and refuses a conflict by name.
- **Dialogs** are a closed set and never stack. Destructive actions use `typed-name-dialog`.

## Cross-Story Dependencies

- **Done.** 19.1, 19.12, 19.2, 19.13, 19.3, 19.4 and 19.5.
  - 19.5 built nine `Catalog.*` endpoints, four lists, the five-tab group and nine `explorer.sql*.read` tools.
  - 19.12's `DeveloperFloor*` rosters pin a real `%Developer`, and every later screen, tool and route joins them.
- **19.14 is next.** A new screen or read tool trips these rosters:
  - `ExplorerDescriptor`, `ReadTool`, `ToolRoundTrip` (`REFUSEEMPTY`), `SurfaceCoverage`, `Descriptor` `ReadShapes`, and `DeveloperFloor` (screens, tools, count words).
  - `InjectionChannels`, for a new untrusted channel.
  - The client's navigation, mirror, rail-wire and self-protection tests.
  - A regenerated `screens.generated.ts`.
- **19.7 and 19.8** issue 19.5's reads. 19.8 edits 19.7's grid and may reuse `extraActions` (inference).
- **19.6 and 19.11** describe one agent SQL tool behind one guard, and whichever story introduces it wires it.
  - 19.11 builds on the agent definitions and 16.15's egress line.
  - It reuses governance (14.2), the copy-out draft (14.1), the sanitizer (14.3), the read-back (16.17) and Download CSV (16.23).
- **19.10.** 19.14's `StatementIndex` question bears on 19.10, which lists other sessions' statement text (inference).
- **Slot A.**
  - Use the profile `ocupilot-slot-a`. The throwaway is `ocupilot-a2-ci` (52780/1979), and it is never restarted.
  - Load source by `rsync` into `/tmp/ocupilot-a2-ci/src/`, then run `$System.OBJ.LoadDir`. Run one test class per call.
  - Probes create and remove only their own `OcuProbe*` objects.
  - Known residue: `WireSecurityRead` (DW-1554) and `Retention` (DW-1929) are red. `JournalWrite`, `JournalWriteGate` and `PathPortInstance` run no tests, because the throwaway predates `OCUPILOT_ALLOW_JOURNAL`.
- **Concurrency.**
  - Epic 18 runs on slot B. 18.18 merged forward at 19.5's boundary, and 18.19 (the journal record browser) is in progress.
  - Shared files are edited add-only and unioned by whichever epic reaches feature second: `Baseline.cls`, `GovernanceBaseline`, `ReadTool`, `ToolRoundTrip`, `Governance`, `ToolDispatch`, `ClassicPageGate`, `SurfaceCoverage`, `screen-outlet.ts`, EXPERIENCE.md and the spine.
  - Edits that are not add-only need the lead: `ReadTool`'s counts, `strings.ts` citations, the Fixed-strings bound and the `angular.json` budget.
  - Check `.worktrees/epic-18`'s diff before editing a shared file. Regenerate `screens.generated.ts` and `ToolFields.cls`; never hand-merge them.
