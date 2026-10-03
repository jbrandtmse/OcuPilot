# Epic 19 Context: Stage 3 - System Explorer over the Atelier API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Give developers a System Explorer inside OcuPilot, built on the IRIS Atelier API. Classes and routines are done: listed, viewed, compiled, deleted, exported and imported as XML, and edited with a save checked against the version it read. So are search, compare and macro lookup. The SQL catalog is done too: it lists schemas, tables, views and procedures, and opens each to every classic detail tab. What remains is the query console with its DML and DDL guard, a data grid harvested from iris-table-editor, Documatic, DocDB, SQL activity, and an agent picker with guarded agent SQL. Everything reaches the instance through a port, in process, as the signed-in user. Nothing handles the user's password or modifies a vendor web application. As in the classic portal, a `%Development` holder with no administrative resource gets in, and every screen keeps the one contract earlier stages followed.

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

- **One contract (FR-80).**
  - One descriptor declares each screen. The screen reaches the outside only through a port, and its tools' field lists derive from the descriptor.
  - Every agent write is a server-minted proposal, with an instance-computed diff, an explicit confirmation and an agent marker.
  - Every read is bounded and reports truncation. Every gate checks the caller's own privileges at call time.
  - Acceptance is this contract plus each row's backing route.
- **19.6, the binding design constraint (DW-1964).**
  - Atelier's `action/query` prepares every statement with SQL privilege checks off (`%Prepare(query,0)`). Measured: a principal with `%Development:USE` and database access, but no SQL grant, read an ungranted table and ran an UPDATE that persisted (DW-1963).
  - So caller SQL never passes through `action/query`. The console enforces the caller's SQL privileges itself, by preparing in process with privilege checks on.
  - The spine does not yet name the class that owns that prepare. A call Atelier cannot carry either names itself in AD-61 or gets its own port.
- **19.6, the guard.**
  - The DML and DDL guard ships **with** the console, never after it.
  - The console runs a statement with parameters, a max-rows cap and a run-in-background option, and can explain its plan.
  - A DML or DDL statement needs an explicit confirmation before it runs.
  - The agent's free-form SQL tool (19.11) passes the same guard, and its mutating statements become ordinary confirmed proposals.
- **19.6, guard questions for the spec gate.**
  - The guard classifies on the instance. Nothing that changes state is decided in the browser (AD-11), and a rule a screen enforces only in its UI is no prohibition (AD-10). The stage extract's "client-side statement-type check" wording predates both (inference).
  - A statement the guard cannot classify should be treated as mutating, as the governance read-only preset blocks what it cannot classify (inference).
  - Some statements still need a declared treatment: privilege, utility and procedure-call statements, and a query whose function writes (inference).
  - A DDL statement can carry code, such as a procedure's or a trigger's body. That bears on the "agent never authors code" call once 19.11 routes agent DDL (inference).
  - No prohibited-set arm names SQL against OcuPilot's own tables or classes yet. `PROHIBITED.OCUPILOTCODE` covers documents only (inference).
  - AD-7 prevents a mutation by a detached process, so a background run of a mutating statement needs a decision (inference).
- **19.6 is a confirmed write. Which mechanism runs it is a story decision:** a screen action (AD-53), or a Save through the write tool (AD-55). Either way, the write pattern below applies.
- **Who gets in.**
  - Any `%Admin_*` resource or `%Development:USE` passes the floor, and a `%Development`-only caller is refused wherever a classic `%Developer` is.
  - Every SQL screen declares `%CSP.UI.Portal.SQL.Home` (`%Development`) as its classic page (AD-44). For any other classic page, read its `RESOURCE` in `irissys/` or on the instance, never from memory.
- **Other backing routes.**
  - 19.9: Documatic at `/csp/documatic/%25CSP.Documatic.cls`, and DocDB at `/api/docdb/v1/:ns`. DocDB needs `%Service_DocDB` enabled: report that, never assume it.
  - 19.10: `INFORMATION_SCHEMA.CURRENT_STATEMENTS`. Canceling a statement is Stage 4.
  - 19.7 and 19.8 inherit DW-1963. A grid read resolves its table through the caller's privilege-filtered row first, as the catalog does, and a grid write cannot run through `action/query` (inference).
- **Governance (AD-22).**
  - A new write key gets its line in `Kernel/Governance/Baseline.cls` in the same change, and a new destructive key ships disabled.
  - After 2026-10-04 the owner decides how new keys enter the baseline. Read tools add no key.
- **New dependencies (Rule 5) are ask-first.** A dependency must be vendored with no CDN, must run under the content-security policy, and counts toward the bundle.
- **Budgets.**
  - **Bundle.** The initial-bundle warning is 2,622 kB, against 2,621,812 bytes measured, so any UI addition crosses it. Re-base `ui/angular.json` and `angular-json.test.mjs` to the new measured size (DW-1166). Stop and ask above 3,800 kB; the hard error is 4,000 kB.
  - **Fixed strings.** The `strings.test.mjs` bound is 2,500. Raising it needs the lead.
- **Harvest limits carried knowingly (19.7, 19.8).** Only single-column primary keys. Delimited names are refused. `rowsAffected` always reads 1. `%VID` offset paging re-reads rows and counts per page, and a failed count shows zero rows.
- **Measure, never assume.** Take pair sets from the handler's checks plus a purpose-built least-privileged principal on the throwaway, never `%Operator`.
- **The ledger.**
  - DW-1001: a new read tool records an occurrence, and the fix is left to the burn-down. AD-36's criterion `hint` (Story 18.19) is the likely mechanism (inference), but it is in the spine only, not in this branch's code until 18.19 merges forward.
  - DW-1963 is a vendor-defect candidate. The owner decides whether to report it.

## Technical Decisions

- **AD-61: the Atelier port.** `Port/AtelierPort` is the only class that names `%Api.Atelier.*`, and only through parameters. It calls route methods in the caller's process, one at a time.
  1. **Gate first.** `%Development:USE`, then READ per namespace on the routines, globals and mapped code databases (never IRISSYS). A write also needs WRITE on the routines database. A refusal names the failed pair.
  2. **Version.** Calls `v<min(N,8)>`, with each endpoint's minimum: `Query` 6; the XML routes 7; search and macros 2. Below the minimum the answer is `PORT.NOTIMPLEMENTED`, before any call.
  3. **Body.** A catalog body is `{query, parameters}`: a port-owned fixed statement, with only validated caller values bound. A tab binds the schema and name that its privilege-filtered `INFORMATION_SCHEMA.TABLES`, `VIEWS` or `ROUTINES` row answers.
  4. **Namespace.** Switched by explicit save and restore around the vendor call only (AD-16).
  5. **Capture.** The ceiling is about 3.6 million characters. Only `action/index` uses a temporary file.
  6. **Outcome.**
     - 404 is `PORT.NOTFOUND`, unlogged on a read; 400 is `PORT.VALIDATION`.
     - Soft refusals and `<PROTECT>` are `PORT.ACCESSDENIED`.
     - A SQL error under 200 is 500 `INTERNAL`.
     - Vendor text is logged, never sent.
  7. **Never:**
     - `docnames`' `filter`, `POST modified`, or the `work` routes.
     - Search's `regex`, `word` or `wild`.
     - Caller text in `query`, or a catalog `pFilter`.
     - `%SQL_Manager.StatementIndex`. Measured: its aggregation check starts a background process that journaled 74 to 78 statistics writes into IRISSYS, HSCUSTOM and USER, even for a READ-only caller.
     - A user name, client or call stack in any statement read.
  8. **Cost.** Catalog and 19.14 reads are cheap (measured).
- **The catalog family is the read pattern 19.6 must not reuse for caller SQL.** 19.5 and 19.14's `Catalog.*` endpoints are fixed statements over `action/query` with bound values, and they are safe only because no caller text reaches `query`. 19.5's spec named the `Query` route as a 19.6 input; DW-1964 supersedes that. 19.14's statements read tools are what 19.11 reuses for the agent's SQL.
- **AD-7's fifth shape.** A fixed statement's first prepare records a statement-index row, and may record a cached query; that is not a mutation. The shape names the port's fixed statements only. Whether it covers caller statements is for 19.6's or 19.11's spec to state (inference).
- **Reads (AD-36, AD-24, AD-60).**
  - One declared read serves the screen and its tool. It is bounded by the row cap and by the per-field (1,000) and total (65,536) bounds. Secret-typed fields never leave the instance.
  - Code and long text may be row fields: a code line, a trigger's code, a view's text, a procedure's description, and a statement's or cached query's text (cut at 1,021 characters with `...` on screen). Each is untrusted, bounded and sanitized.
  - A document's whole text is a screen-only payload. Query results and cell values are untrusted content (AD-11).
  - `read.note {key, text}` is one fixed sentence on a declared read. The list page shows it above the rows, and the read tool's description ends with it. `Screen/Registry.cls` and `screen-mirror.mjs` validate it alike, and `screen-mirror.test.mjs` holds its text equal to `strings.ts`.
- **AD-5's parent-scoped tab group.** Every member names the same `parentScope` and criterion, and the group's head is the parent list's `<route>/document`.
- **SQL (AD-21).** Every caller value is bound, and a name is resolved against `INFORMATION_SCHEMA` before the resolved name is bound. A grid's identifiers cannot be bound in statement text, so they need that resolve or a named AD-21 case (inference).
- **The write pattern (19.2, 19.13, 19.3).** 19.6, 19.8 and 19.9 follow it and amend the spine at their own spec gates.
  - **Callers.** One tool has two callers (AD-53, AD-55). The screen mints no proposal and uses its confirm dialog. Text the model must not author is a `SCREENVALUES` value, and an unadvertised tool can be reached only from its screen.
  - **What each write must answer for a SQL statement:**
    - the target that keys AD-34's lock and AD-6's fingerprint, and the server-computed diff;
    - the read-back (AD-58), the change event (AD-14), and the `Snippet` script form (AD-59);
    - `CLASSICPAGES` (AD-44), and new codes in `Api/AtelierError.cls` or the new port's own class.
  - **Audit (AD-15).** The stock events record none of the earlier Explorer writes. The instance has `%System/%SQL` statement events by source and kind (Story 7.11). Measure whether a console run records one; if not, add it to AD-53's named-gap list.
  - **Protection.** `PROHIBITED.OCUPILOTCODE` covers any `OcuPilot*` document (AD-10). Console output reaches only the screen and the proposal card (AD-39).
- **The iris-table-editor harvest.** Keep its call sites, never its names.
  - Lift `SqlBuilder`, `DataTypeFormatter`, `UrlBuilder`, `ErrorHandler`, the model types, `grid-styles.css` (on OcuPilot's tokens) and the CSV helpers.
  - Port three `grid.js` algorithms: keyboard navigation; the filter row with tri-state sort; and staging with primary-key reconciliation.
  - Never carry its plaintext-password session.
- **Documatic and agent definitions.**
  - Documatic loads under the browser-level session, and no token enters a frame (AD-28). The content-security policy names only the instance's origin (AD-47).
  - Moving the default definition is a security change, and the egress line follows the definition a turn uses (AD-42).

## UX & Interaction Patterns

- **The area.** System Explorer is rail position 8. Its side bar: Classes · Routines · Search · Compare · Macros · SQL schemas · SQL tables · SQL views · SQL procedures.
  - Viewers, editors and tabs are unlisted (`sideBarPosition` 0). Prompts use the group "Code".
  - Every screen registers the 10-item contract, at least three prompts, its aliases and its Fixed strings.
- **EXPERIENCE.md.**
  - System Explorer's Fixed-strings rows are :586 to :596; append new rows after :596.
  - Edit the side-bar line :159 and the dialog set :173 in place. A console confirmation joins the closed dialog set (inference).
  - Move every citation the suites hold (`npm run test:tools`).
- **Rendering.** Code renders as text on `code-surface`. Output panes carry a polite live status line, and a diff reuses `line-diff.ts`.
- **Dialogs** are a closed set and never stack. Destructive actions use `typed-name-dialog`, and the editor asks "Leave without saving?".
- **Known shared-UI gaps (range-end cleanup).** A long cell clips, and its tooltip cannot show text taller than the window (DW-1976). A nine-tab strip hides tabs below 1920 px (DW-1978).

## Cross-Story Dependencies

- **Done.** 19.1, 19.12, 19.2, 19.13, 19.3, 19.4, 19.5 and 19.14. **Next: 19.6.**
- **Rosters a new screen or tool trips:**
  - `ExplorerDescriptor`, `ReadTool` (its counts need the lead), `ToolRoundTrip` `REFUSEEMPTY`, `SurfaceCoverage`, `Descriptor` `ReadShapes`, and `DeveloperFloor` (screens, tools, the count word "thirty-two").
  - `InjectionChannels`, for a new untrusted channel.
  - The client's navigation, mirror, rail-wire and self-protection tests, and a regenerated `screens.generated.ts`.
  - For a write tool: `GovernanceBaseline` and `DraftRegistry` (a script form for every write tool).
- **The agent's SQL tool.** 19.6 and 19.11 describe one agent SQL tool behind one guard, and whichever story introduces it wires it. 19.11 adds the picker over agent definitions and 16.15's egress line. It reuses governance (14.2), the copy-out draft (14.1), the sanitizer (14.3), the read-back (16.17) and Download CSV (16.23).
- **19.7 and 19.8.** They issue the catalog's reads. 19.8 edits 19.7's grid and may reuse `extraActions` (inference).
- **19.10.** The "no identifying column" rule binds the statements tabs. 19.10 lists other sessions' statements, so it decides its own columns and gate at its spec (inference).
- **Slot A.**
  - Use the profile `ocupilot-slot-a`. The throwaway is `ocupilot-a2-ci` (52780/1979), and it is never restarted.
  - Load source with `rsync` into `/tmp/ocupilot-a2-ci/src/`, then run `$System.OBJ.LoadDir`. Run one test class per call.
  - Probes create and remove only their own `OcuProbe*` objects.
  - Known residue: `WireSecurityRead` (DW-1554) and `Retention` (DW-1929) are red. `Journal*` and `PathPortInstance` run no tests.
- **Concurrency.**
  - Epic 18 runs on slot B. 18.19 is committed with CI pending, and 18.6 is in plan.
  - Shared files are edited add-only and unioned by whichever epic reaches the feature branch second: `Baseline.cls`, `GovernanceBaseline`, `ReadTool`, `ToolRoundTrip`, `Governance`, `ToolDispatch`, `ClassicPageGate`, `SurfaceCoverage`, `screen-outlet.ts`, EXPERIENCE.md and the spine.
  - Check `.worktrees/epic-18`'s diff before editing a shared file. Regenerate `screens.generated.ts` and `ToolFields.cls`; never hand-merge them.
