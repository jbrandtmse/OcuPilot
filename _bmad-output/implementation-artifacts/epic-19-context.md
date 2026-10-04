# Epic 19 Context: Stage 3 - System Explorer over the Atelier API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Give developers a System Explorer inside OcuPilot, built on the IRIS Atelier API and in-process ports. Built so far: code browsing, editing, compiling, export and import; search, compare and macros; the SQL catalog; the guarded query console with background runs; and the data browser's tree, grid and editing with one confirmed Save. Still to come: the data browser's export, shortcuts, go-to-row and tabs (19.16), Documatic and DocDB (19.9), SQL activity (19.10), and an agent picker with guarded agent SQL (19.11). Everything reaches the instance through a port, in process, as the signed-in user, never with the user's password and never by modifying a vendor web application. As in the classic portal, a `%Development` holder gets in.

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
- **No caller-shaped SQL through Atelier's `action/query`**, which prepares with privilege checks off (DW-1963). Caller SQL, and any statement a person's choices shape, goes through `Port/SqlPort`.
- **Table rows are screen-only.** Grid pages, save outcomes and console rows, with their SQLCODE and messages, never reach a declared read, a tool's view, screen context, the ledger, an audit payload or a log line: an arbitrary table's columns are unclassified and can hold patient data.
- **19.16** (client-side, no backing route):
  - CSV of the page as shown, built in the browser from the visible page only, so no new read exists. Recommended for its plan to settle: at most 500 rows, cut cells as cut, staged values marked or excluded.
  - Shortcuts for the row actions, Save, export, go-to-row and tabs, with a help dialog. The harvest's chords (Ctrl+N, -, D, S, E, F, G, F5, F1) are not carried. Avoid browser-reserved chords (Ctrl+N, Ctrl+Shift+N) and the shell's Ctrl/Cmd+K, I and B; the shell has no single-character shortcuts, and the grid already binds Ctrl/Cmd+PageUp and PageDown.
  - Go-to-row by absolute row number, computing the offset (the harvest's is page-relative).
  - Tabs keep their own state, staged changes included, across a switch, and closing one with staged changes asks first.
  - ARIA matches the portal, not the harvest's `announce`; 19.8 owns the editing announcements.
- **19.9.** Documatic loads in place from `/csp/documatic/%25CSP.Documatic.cls` under the browser-level session; no token enters a frame (AD-28), and the content-security policy names only the instance's origin (AD-47). DocDB (`/api/docdb/v1/:ns`) lists, creates and drops databases; report whether `%Service_DocDB` is enabled, never assume. Create and drop are writes, and the in-process port that reaches DocDB names itself (inference).
- **19.10.** `INFORMATION_SCHEMA.CURRENT_STATEMENTS` (classic page `%CSP.UI.Portal.SQL.CurrentStatements`): text, statistics and application metadata. Existing statement reads select no user name, client or call stack, so its spec decides its columns and gate (inference). Canceling another session's query is a later catalog row.
- **19.11.** Advertises `explorer.sqlquery.run` behind the console's guard, a mutating statement becoming a confirmed proposal, prepared in process with checks on (DW-1964). It shows the real guard on the card (DW-2004), decides the limit on called functions (DW-2003), whether SQL or grid rows reach the model (the spine forbids it today) and whether the agent proposes row changes. Moving the default definition is a security change (AD-42).
- **Who gets in.** The API floor is any `%Admin_*` resource or `%Development:USE`. SQL screens declare `%CSP.UI.Portal.SQL.Home`; the data browser `%cspapp.exp.utilsqlopen`, unioning `%cspapp.exp.utilsqlopenview`'s custom resource. A new surface declares its classic page's `RESOURCE`. Confirm pair sets with a purpose-built least-privileged principal, never `%Operator`.
- **Governance (AD-22).** After 2026-10-04 the owner decides how a new write key enters `Kernel/Governance/Baseline.cls`: ask.
- **Budgets.** Bundle warning 2838kB; crossing it re-bases `ui/angular.json` and `angular-json.test.mjs` to the measured size (DW-1166); stop and ask above 3800kB. Fixed strings: `strings.test.mjs` caps them at 2,600, so measure first; raising it needs the lead. A new dependency is ask-first, vendored, and runs under the content-security policy.

## Technical Decisions

- **`Port/SqlPort`: reuse, never fork.** `%Prepare(text, 1)` in the target namespace as the user, every value bound, bounded by `$System.Alarm` at `BoundSeconds()` (50 s) with an open transaction rolled back, each statement released in its own namespace (DW-1986). Caller SQL uses `Run` and `Classify`; the grid uses `BrowsePlan`/`BrowseRun` and `SavePlan`/`Save`, with identifiers from the caller's privilege-filtered `INFORMATION_SCHEMA` rows, a page of 50 to 500 rows, and one guarded statement per saved row (at most 100), its outcome from `%ROWCOUNT` (AD-21, AD-61).
- **Person-only SQL writes (AD-53).** `explorer.sqldata.save` and `explorer.sqlquery.run` are unadvertised with keys disabled; target `(class, <ns>, sql)`, a row key bound, never an id (AD-13); no extra pairs, no `CLASSICPAGES`, no vendor audit event (named gaps fifteen and sixteen).
- **Self-protection (AD-10).** `PROHIBITED.OCUPILOTSQL` (`Kernel/Proposal/Prohibited.cls`) refuses console text naming `ocupilot` or an `OcuPilot` schema, and a grid read or save of such a table, or a view over one. Named limit: DW-1987.
- **The write pattern.** One tool, two callers (AD-53, AD-55); the screen mints no proposal. Each write answers for the per-target lock (AD-34; a Save does not hold it yet, DW-1882), fingerprint and server diff (AD-6, AD-51, AD-54), read-back (AD-58), change event (AD-14), `Snippet` (AD-59), `CLASSICPAGES` (AD-44), audit marker or named gap (AD-15), and a removal's impact (AD-8).
- **`AtelierPort`** alone names `%Api.Atelier.*`: gate first, then version; vendor text logged, never sent; never `%SQL_Manager.StatementIndex` or caller text in `action/query`.
- **Reads (AD-36, AD-24, AD-60).** One declared read serves screen and tool, capped by the row cap, 1,000 characters a field and 65,536 in all, sanitized before the model.

## UX & Interaction Patterns

- **EXPERIENCE.md.** Edit the side-bar line (:159) and the closed dialog set (:173) in place; 19.16's shortcut-help and go-to-row dialogs join it, and dialogs never stack. System Explorer's Fixed strings run :586 to :599, the table's end; the data browser's behavior is :670 to :684. Move every citation the suites hold (`npm run test:tools`).
- **Every screen** registers the ten-item contract, three or more Code-group prompts, aliases and Fixed strings; viewers, editors and tabs are unlisted (`sideBarPosition` 0).
- **The data browser.** Tree leading, grid beside it, stacked when narrow. The APG grid: `role="grid"`, one Tab stop, `aria-activedescendant`; `--ocu-*` tokens only. Polite status lines; a refusal is the alert banner. Staged changes are keyed by row key; leaving or opening another table asks "Leave without saving?", and a namespace switch discards them with a notice.
- **CSV (`core/csv.ts`, the data table's rule).** Header of column labels, cells as displayed, a leading `=`, `+`, `-`, `@`, tab or carriage return prefixed `'`, UTF-8 with a byte-order mark, CRLF, `<screen>-<YYYYMMDD>-<HHMMSS>.csv` in local time.
- **Shortcuts.** Home's Shortcuts block lists each binding as a label and its keys; a portal-matching help dialog would follow it (inference).
- **Confirmations.** Destructive: `typed-name-dialog`. A data change: `warning-dialog`.
- **Known gaps (range-end cleanup).** A tooltip cannot show text taller than the window (DW-1976). A nine-tab strip hides tabs (DW-1978), which bears on 19.16's tabs.

## Cross-Story Dependencies

- **Done:** 19.1 to 19.8 and 19.12 to 19.15. **Order:** 19.16, then 19.9, 19.10 and 19.11.
- **19.16 consumes 19.8's** grid, store and staged-changes model (now per tab), editing announcements, `warning-dialog` and `FormDirty` guard, and `core/csv.ts`. DW-2053 (an untouched new row counted, never sent) reopens if 19.16 changes how staged rows count.
- **19.11** reuses governance, the copy-out draft, the sanitizer, the read-back and Download CSV.
- **Rosters a change trips.** Always `ExplorerDescriptor`, `ReadTool` (counts need the lead), `ToolRoundTrip` `REFUSEEMPTY`, `SurfaceCoverage`, `Descriptor` `ReadShapes`, and `DeveloperFloor`'s `SCREENS`, `TOOLS`, `HELDWRITES` and count word "thirty-four". A route: `EndpointCoverage`, `DeveloperFloorRoutes`. A write: `GovernanceBaseline`, `DraftRegistry`. An untrusted channel: `InjectionChannels`. The client's mirror, navigation and self-protection tests, and a regenerated `screens.generated.ts`.
- **Slot A.** Profile `ocupilot-slot-a`; throwaway `ocupilot-a2-ci` (52780/1979), never restarted. Load by `rsync` into `/tmp/ocupilot-a2-ci/src/`, then `$System.OBJ.LoadDir`. One test class per call; probes touch only `OcuProbe*` objects.
- **Concurrency.** Epic 18 runs in parallel, with 18.7 (encryption key files; 18.22 to 18.24 split from it) open. Edit shared files add-only (`Router.cls`, `strings.ts`, `_components.scss`, `Baseline.cls`, roster tests, `screen-outlet.ts`, EXPERIENCE.md, the spine, the bundle budget) after checking `.worktrees/epic-18`'s diff. Regenerate `screens.generated.ts` and `ToolFields.cls`; never hand-merge them.
