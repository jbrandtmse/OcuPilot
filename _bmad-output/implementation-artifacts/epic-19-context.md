# Epic 19 Context: Stage 3 - System Explorer over the Atelier API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Give developers a System Explorer inside OcuPilot, built on the IRIS Atelier API and on in-process ports. These parts are done:

- Classes and routines: listed, viewed, compiled, deleted, exported and imported as XML, and edited with ETag-checked saves.
- Search, compare and macro lookup.
- The full SQL catalog.
- The SQL query console with its DML and DDL guard, which the instance enforces.

What remains is running a console query in the background, a data grid harvested from iris-table-editor, Documatic and DocDB, SQL activity, and an agent picker with guarded agent SQL. Everything reaches the instance through a port, in process, as the signed-in user. Nothing handles the user's password, and nothing modifies a vendor web application. As in the classic portal, a `%Development` holder with no administrative resource gets in. Every screen keeps the one contract earlier stages followed.

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
  - One descriptor declares each screen. The screen reaches the outside only through a port, and its tools' field lists derive from the descriptor.
  - Every agent write is a server-minted, fingerprinted proposal, with an instance-computed diff, an explicit confirmation and an agent marker.
  - Every read is bounded and reports truncation. Every gate checks the caller's own privileges at call time.
  - Acceptance is this contract plus each row's backing route.
- **Caller SQL never passes through Atelier's `action/query`.** That route prepares with SQL privilege checks off (DW-1963, a vendor-defect candidate; the owner decides whether to report it). Caller SQL goes through `Port/SqlPort`, which prepares in process with the checks on. This binds 19.15 and 19.11. A grid write in 19.8 cannot run through `action/query` either (inference).
- **19.15, the background run.**
  - It runs queries only, never a mutating kind. Each runs in a job, as the signed-in user, under 19.6's alarm bound.
  - It reuses SqlPort's guard and bounds: the input limits, Max rows, the cell and answer cuts, the alarm, the rollback, and the prohibited-SQL arm.
  - It needs:
    - a fourth AD-42 process spawn site;
    - an AD-7 decision limiting it to queries;
    - an owner-only result store in protected state (AD-9), with its sweep;
    - poll and cancel routes.
  - Cancel is `$SYSTEM.SQL.CancelQuery` on the run's own job. 19.6's plan measured it feasible: a least-privileged user's call stopped its own job's query in 0.001 s, with SQLCODE -456.
  - Open at the spec gate:
    - A stored result keeps rows that the screen-only clauses (AD-36, and AD-39's sixth exception) send to the screen alone, and that 19.6 never stores. Those clauses need an amendment (inference).
    - A query that calls a function can change state while it is still typed a query (AD-21's named limit, DW-2003). In a detached job, that runs into AD-7's "never mutates" (inference).
    - The job's prepare records a statement-index row, and AD-7's statement-index shape names only the port's fixed statements (inference).
    - Turns are capped at one concurrent turn per user (AD-41) and lapse without polls (AD-31). Whether a background run takes a like bound is undecided (inference).
- **Who gets in.**
  - Any `%Admin_*` resource or `%Development:USE` passes the floor. A `%Development`-only caller is refused wherever a classic `%Developer` is.
  - Every SQL screen declares `%CSP.UI.Portal.SQL.Home` (`%Development`) as its classic page (AD-44). Read any other classic page's `RESOURCE` in `irissys/` or on the instance, never from memory.
- **Other backing routes.**
  - 19.9: Documatic at `/csp/documatic/%25CSP.Documatic.cls`, and DocDB at `/api/docdb/v1/:ns`. DocDB needs `%Service_DocDB` enabled: report whether it is, never assume.
  - 19.10: `INFORMATION_SCHEMA.CURRENT_STATEMENTS`. Canceling another session's statement is Stage 4.
  - 19.7 and 19.8: a grid read resolves its table through the caller's privilege-filtered row first, as the catalog does (inference).
- **Governance (AD-22).** A new write key gets its line in `Kernel/Governance/Baseline.cls` in the same change, and a new destructive key ships disabled. Read tools add no key. After 2026-10-04, the owner decides how new keys enter the baseline.
- **New dependencies are ask-first.** A dependency must be vendored with no CDN, must run under the content-security policy, and counts toward the bundle.
- **Budgets.**
  - **Bundle.** The warning is 2655kB. A UI addition that crosses it re-bases `ui/angular.json` and `angular-json.test.mjs` to the new measured size (DW-1166). Stop and ask above 3800kB. The hard error is 4000kB.
  - **Fixed strings.** `strings.test.mjs` bounds the Fixed strings at 2500. Raising it needs the lead.
- **Harvest limits carried knowingly (19.7, 19.8).**
  - Primary keys are single-column only, and delimited names are refused.
  - `rowsAffected` always reads 1.
  - `%VID` offset paging re-reads rows and counts per page, and a failed count shows zero rows.
- **Measure, never assume.** Take pair sets from the handler's checks, plus a purpose-built least-privileged principal on the throwaway, never `%Operator`.
- **DW-1001.** A new read tool records an occurrence. The fix, a criterion description declared in the descriptor, lands in Epic 19's close burn-down.

## Technical Decisions

- **`Port/SqlPort`, AD-61's named case for SQL.**
  - **Gate.** It evaluates AtelierPort's read pairs first (`PAIRS`, `NamespacePairs(ns)`), plus the screen's gate with its classic page. It names no `%Api.Atelier.*` class and uses no capture.
  - **Prepare.** The statement is prepared whole with `%SQL.Statement.%Prepare(text, 1)`, in the target namespace (explicit save and restore, AD-16), in the request's own process, as the signed-in user. No escalated frame is open. Values are bound positionally.
  - **Privileges do not rest on the statement cache (DW-1986).**
    - Each statement is released in the namespace it was prepared in, which purges a one-use cached compile.
    - A DDL statement whose type ties to a system privilege is refused -99 unless `%CHECKPRIV` says the caller holds that privilege.
    - Named limit: a DDL statement's object privileges, and an unlisted type's own check, stay the instance's (DW-2003).
  - **Guard.** It classifies by the prepared `statementType` through a closed table. An unknown type is `other`, and needs confirmation. It refuses:
    - session and process control;
    - administration of users, roles, privileges and databases;
    - server-file and other-server statements (LOAD, foreign servers and tables, THROUGH);
    - text that sets a password, before any prepare, because the statement index keeps prepared text (DW-1982).
    - Only two text rules exist, both fail-closed: that password refusal and the OcuPilot backstop.
  - **Bounds.**
    - Inputs: a statement of 1 to 100,000 characters, at most 100 values of up to 32,767 characters each, and Max rows from 1 to 1,000.
    - Cuts: a cell at 1,000 characters, and an answer at 1,000,000, by whole rows. `truncated` reports either cut.
    - Queries and DML run under `$System.Alarm` at `TestCall.BoundSeconds(TestCall.GatewaySeconds())`: 50 s against a 60 s gateway. Past it, the answer is `stopped`. DDL and CALL run without the alarm (named limit).
    - A transaction a run leaves open is rolled back.
    - `Explain` executes nothing and respects privileges.
  - **Self-protection.** `PROHIBITED.OCUPILOTSQL` applies on every path, reads included (AD-10). It is one predicate in `Kernel/Proposal/Prohibited.cls`. Named gap: a procedure's or function's own code. Named limit: a grant on a view alone (DW-1987).
  - **Results are screen-only (AD-36, AD-39).** Rows, the SQLCODE and message, and the plan never become a declared read, a tool's view, screen context, a log line, a ledger row, an audit payload or stored state.
- **Confirmed DML and DDL (AD-53, AD-51, AD-8, AD-13).**
  - DML, DDL, CALL and unclassified statements run only through the screen action `run` of `explorer.sqlquery.run`. It is the unadvertised named case's third tool, and is never asked of governance. Its key ships disabled until 19.11 advertises it.
  - Its target is `(class, <ns>, sql)`. It declares no pair beyond its screen's.
  - SqlPort builds the run from the tool's declared screen values and answers its fresh read through a port-composed `GUARD` type.
  - The write path classifies again. The client opens the dialog only when the server answers `confirm` (AD-11).
  - Audit gap fourteen: with the stock event set, no vendor event records a console run.
- **A job, for 19.15.**
  - **AD-7.** A job inherits `$USERNAME` and `$ROLES` at spawn and never mutates the instance. It may write OcuPilot's own protected state. AD-7's read-side exceptions are an enumerated list of shapes.
  - **AD-9.** Nothing is spawned from inside an escalated frame. Storage escalates only through a privileged routine application, inside a `New $ROLES` frame, and never re-enters.
  - **AD-42.** Today's spawn sites are the turn job, `Kernel.Provider.TestCall`, and `Port/RemoteDatabasePort`'s remote-directory listing. A fourth names itself there.
  - **The store's model (AD-33, AD-31, AD-37).** Progress is keyed by run and owner. A poll for another user's run answers 404, never 403. Progress is capped in size, kept 15 minutes after a turn ends, and swept by retention.
- **AtelierPort (AD-61), for the remaining stories.**
  - It is the only class that names `%Api.Atelier.*`. It gates first: `%Development:USE`, then READ on the routines, globals and mapped code databases per namespace. A write also needs WRITE on the routines database.
  - Below an endpoint's version it answers `PORT.NOTIMPLEMENTED`. Catalog bodies are port-owned fixed statements that bind validated values, never caller text.
  - Vendor text is logged, never sent.
  - It never uses `docnames`' `filter`, `POST modified`, the `work` routes, search's `regex`, `word` or `wild`, or `%SQL_Manager.StatementIndex`. A statement read never carries a user name, client or call stack.
- **Reads (AD-36, AD-24, AD-60).**
  - One declared read serves both the screen and its tool. It is bounded by the row cap, 1,000 characters a field and 65,536 in all.
  - Code and long text are untrusted, bounded and sanitized. A document's whole text is a screen-only payload.
  - `read.note` is one fixed sentence on a declared read.
- **SQL identifiers (AD-21).** Every caller value is bound, and a name is resolved against `INFORMATION_SCHEMA` before it is bound. A grid's identifiers cannot be bound in statement text, so each needs that resolve or a named AD-21 case (inference).
- **The write pattern, for 19.8 and 19.9.**
  - One tool has two callers (AD-53, AD-55). The screen mints no proposal. Text the model must not author is a `SCREENVALUES` value.
  - Each write answers for its target, which keys AD-34's lock and AD-6's fingerprint. It also answers for the server-computed diff, the read-back (AD-58), the change event (AD-14), the `Snippet` form (AD-59), `CLASSICPAGES` (AD-44), new error codes, and its audit (AD-15).
- **The iris-table-editor harvest.**
  - Keep its call sites, never its names.
  - Lift `SqlBuilder`, `DataTypeFormatter`, `UrlBuilder`, `ErrorHandler`, the model types, `grid-styles.css` (on OcuPilot's tokens) and the CSV helpers.
  - Port three `grid.js` algorithms: keyboard navigation, the filter row with tri-state sort, and staging with primary-key reconciliation.
  - Never carry its plaintext-password session.
- **Documatic and agent definitions.**
  - Documatic loads under the browser-level session, and no token enters a frame (AD-28). The content-security policy names only the instance's origin (AD-47).
  - Moving the default definition is a security change (AD-42).

## UX & Interaction Patterns

- **The area.**
  - System Explorer is rail position 8. Its side bar ends with SQL schemas · SQL tables · SQL views · SQL procedures · SQL query.
  - Viewers, editors and tabs are unlisted. Prompts use the group "Code".
  - Every screen registers the 10-item contract, at least three prompts, its aliases and its Fixed strings.
- **EXPERIENCE.md.**
  - System Explorer's Fixed-strings rows are :586 to :597, with SQL query at :597. Append new rows after :597.
  - Edit the side-bar line :159 and the dialog set :173 in place.
  - Move every citation the suites hold (`npm run test:tools`).
- **Rendering.** Code renders as text on `code-surface`. Output panes carry a polite live status line. A diff reuses `line-diff.ts`.
- **Dialogs.**
  - Dialogs are a closed set, and they never stack.
  - Destructive actions use `typed-name-dialog`.
  - The console's "Run this statement?" dialog opens only on a server `confirm`.
- **Known shared-UI gaps, routed to range-end cleanup.** A long cell clips, and its tooltip cannot show text taller than the window (DW-1976). A nine-tab strip hides tabs (DW-1978).

## Cross-Story Dependencies

- **Done:** 19.1, 19.12, 19.2, 19.13, 19.3, 19.4, 19.5, 19.14 and 19.6.
- **Next: 19.15.** It extends 19.6's SQL query screen and SqlPort.
- **19.11.**
  - It advertises `explorer.sqlquery.run` behind the same guard, and each mutating statement becomes an ordinary confirmed proposal.
  - DW-2004: on a screen action, the fresh read carries no statement. So the agent's card must compose the guard from the proposed statement: its kind, statement type, tables and consequence.
  - It decides whether the agent may call path-taking or state-changing functions and procedures, and names those limits in AD-8, AD-10, AD-21 and AD-61 (DW-2003).
  - It also adds the picker and 16.15's egress line, and reuses governance (14.2), the copy-out draft (14.1), the sanitizer (14.3), the read-back (16.17) and Download CSV (16.23).
- **19.7 and 19.8.** They issue the catalog's reads. 19.8 edits 19.7's grid and may reuse `extraActions` (inference).
- **19.10.** The "no identifying column" rule binds the statements tabs. 19.10 lists other sessions' statements, so its spec decides its own columns and gate (inference).
- **Rosters a new screen or tool trips.**
  - `ExplorerDescriptor`, `ReadTool` (its counts need the lead), `ToolRoundTrip` `REFUSEEMPTY`, `SurfaceCoverage`, `Descriptor` `ReadShapes`, and `DeveloperFloor` (its count word is now "thirty-three").
  - `InjectionChannels`, for a new untrusted channel.
  - The client's navigation, mirror, rail-wire and self-protection tests, and a regenerated `screens.generated.ts`.
  - For a write tool: `GovernanceBaseline` and `DraftRegistry`.
- **Slot A.**
  - Use the profile `ocupilot-slot-a`. The throwaway is `ocupilot-a2-ci` (52780/1979), and it is never restarted.
  - Load source by `rsync` into `/tmp/ocupilot-a2-ci/src/`, then run `$System.OBJ.LoadDir`.
  - Run one test class per call.
  - Probes create and remove only their own `OcuProbe*` objects.
- **Concurrency.**
  - Epic 18 runs in parallel; 18.20 is in implement.
  - Shared files are edited add-only and unioned by whichever epic reaches the feature branch second. They include `Baseline.cls`, `GovernanceBaseline`, `ReadTool`, `ToolRoundTrip`, `ToolDispatch`, `ClassicPageGate`, `SurfaceCoverage`, `screen-outlet.ts`, EXPERIENCE.md and the spine.
  - Check `.worktrees/epic-18`'s diff before editing a shared file.
  - Regenerate `screens.generated.ts` and `ToolFields.cls`; never hand-merge them.
