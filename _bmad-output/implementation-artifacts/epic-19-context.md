# Epic 19 Context: Stage 3 - System Explorer over the Atelier API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Give developers a System Explorer inside OcuPilot. Fifteen stories are built: code browsing, editing, compiling, export and import; search, compare and macros; the SQL catalog; the guarded query console and its background runs; the data browser; the embedded class reference; and the DocDB browser. Two remain. SQL activity (19.10) lists the statements running on the instance right now, so a slow instance can be diagnosed. Story 19.11 advertises the console's guarded SQL tool to the agent and adds a picker among enabled agent definitions, so an operations agent and a developer agent can differ. Every feature reaches the instance through a port, in process, as the signed-in user. None uses the user's password, and none modifies a vendor web application.

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
- Story 19.17: The DocDB browser

## Requirements & Constraints

- **One contract.** Every new screen has exactly one descriptor and reaches the outside only through a port with its own gate, never through an HTTP call to `/api/*`. A read tool arrives with each screen. Every write is a server-minted, fingerprinted proposal that a person confirms. Every read is bounded and reports truncation. Every gate checks the caller's own privileges at call time. A destructive key defaults to disabled.
- **Who gets in.** The API floor is any `%Admin_*` resource or `%Development:USE`. A new surface declares its classic page's `RESOURCE`, read in `irissys/` and never recalled. Confirm each pair set by running as a purpose-built least-privileged principal.
- **19.10 SQL activity.** Currently executing statements list with their text, statistics and application metadata.
  - **Source:** `INFORMATION_SCHEMA.CURRENT_STATEMENTS`, a `_PUBLIC`-owned table built from the SQL application metadata stack (`%SYS.AppMetadataStack.SQL.GetStackInfo`). It has one row per running statement, with a `Namespace` column, so the read is instance-wide rather than per namespace (inference).
  - **Statement text:** `INFORMATION_SCHEMA.GetSQLStatement(Namespace, StatementIndexHash)`. The vendor's note says a `%Development:USE` holder gets every statement's text.
  - **The classic page** is `%CSP.UI.Portal.SQL.CurrentStatements`, served under `/csp/sys/op/` (System Operation). It declares `RESOURCE = "%Admin_Operate"`, not `%Development`. It selects server, process id, user name, namespace, run type, duration, statement id and hash, transaction nesting level, bound `Parameters`, cached query, `CallerName`, worker count, start time, and parent and child statements. A details pane shows the metadata stack. It auto-refreshes and offers Cancel Query.
  - **Out of scope:** cancel (`$SYSTEM.SQL.CancelQuery`) is a later catalog row.
  - **The spec decides:**
    - the area: OS management, as the classic page and the PRD's OS-section row place it, or System Explorer, as this epic does;
    - the columns, and whether bound `Parameters` (possibly secret values, AD-35) and the identifying columns are shown;
    - which port carries the read;
    - whether the screen joins auto-refresh.
  - **The port:** `AtelierPort`'s gate adds `%Development:USE` and namespace READ, which is not the classic pair. Its `action/query` carries only fixed statements, prepared with privilege checks off. A fixed in-process read gated on `%Admin_Operate:USE` would match the classic page more closely (inference).
  - **DW-2093:** rename `ExplorerDescriptor.TestTheAreaHoldsTwentyFourReadsAndEightWrites` (`ExplorerDescriptor.cls:141`) to its real counts, and with it the eight `SurfaceCoverage` rows that name it (`:323-330`), when this story changes those counts.
- **19.11 agent SQL and picker.**
  - **The tool:** it advertises `explorer.sqlquery.run` behind the console's guard, prepared in process with privilege checks on (`SqlPort`); a mutating statement is a confirmed proposal. The proposal card must show the real guard (kind, statement type, tables, consequence), so the mint's fresh read is composed from the proposed statement (DW-2004).
  - **The plan decides:**
    - whether the tool closes the limit for a called function or procedure that names a server path or changes state (DW-2003);
    - whether query rows, or statement-index columns such as `UserName`, reach the model, which the spine forbids today;
    - whether code-carrying DDL is refused for the agent;
    - how a confirmed statement's SQL error is recorded;
    - whether the agent may propose row changes through `explorer.sqldata.save`, which would make DW-2057 real.
  - **The picker:** it chooses among enabled definitions, and the panel names the one in use. Every user can see definitions for selection; only OcuPilot administrators can edit them. The PRD's row (CP-36) has a developer agent and an operations agent differing per area, with an About bubble. Moving the default marker is a security change (AD-42), so a per-user pick belongs in AD-50's per-user store and never moves the marker (inference).
- **Governance (AD-22).** A story adds each new write key to `Kernel/Governance/Baseline.cls` in the same change, enabled unless its criteria disable it. The baseline grows only by such additions and is never regenerated. Flipping `explorer.sqlquery.run`'s existing `false` is not an addition, so it needs a ruling (inference).
- **Budgets.**
  - **Bundle:** after the 18.22 merge it measures 2,939,195 B against a 2940kB warning, so any client addition crosses it. Re-base `ui/angular.json` with `angular-json.test.mjs` (DW-1166). Stop and ask above 3,800 kB.
  - **Fixed strings:** capped at 2,700 in `strings.test.mjs`. 19.17 measured 2,623 before the 18.22 merge added its own, so measure before adding.

## Technical Decisions

- **Ports.**
  - Only `AtelierPort` names `%Api.Atelier.*`. It checks the gate first and the version second, and it logs vendor text but never sends it.
  - Caller SQL goes through `Port/SqlPort` (`%Prepare(text, 1)`, every value bound, alarm-bounded, statements released per namespace), never through `action/query` (DW-1963, DW-1964).
  - A new port, or a new call on an existing one, is named in the spine with its gate at the spec gate (AD-29, AD-61, Rule 20). A test pins any vendor-internal routine it calls.
- **Reads (AD-36, AD-24, AD-60).**
  - One declared read serves the screen and the tool. It is capped at 1,000 characters a field and 65,536 in all, and it is sanitized before it reaches the model.
  - A statement's text is a row field, shown cut at 1,021 characters with `...`.
  - **Screen-only payloads:** console rows and plans, background-run answers, data-browser pages and save outcomes. None of them is ever a declared read, a tool's view or screen context.
- **No statement read selects a user name, client or call stack** (AD-61 rule 7, written for the catalog's statement tabs).
- **19.11's tool.** `explorer.sqlquery.run` is AD-53's unadvertised named case; its key ships `false`.
  - Its target `(class, <ns>, sql)` serializes runs per namespace. Its sibling-cancel effect on agent proposals is 19.11's to revisit.
  - A console run has no vendor audit event, which is AD-15's named case.
  - A turn that prepares caller statements extends AD-7's fifth shape.
  - The agent never reaches a background run (19.15).
- **The write pattern.** One tool serves two callers, and the screen mints no proposal (AD-53, AD-55). Each write accounts for:
  - the per-target lock (AD-34);
  - the fingerprint and the server-computed diff (AD-6, AD-51, AD-54);
  - read-back (AD-58);
  - the change event (AD-14);
  - the copy-out snippet (AD-59);
  - its classic page (AD-44);
  - an audit marker or a named gap (AD-15).
- **Self-protection (AD-10).** `PROHIBITED.OCUPILOTSQL` refuses SQL that names `ocupilot` or touches an `OcuPilot` schema, reads included.

## UX & Interaction Patterns

- **EXPERIENCE.md, edited in place:**
  - the System Explorer side-bar line is :159, with the OS management row in the table below it;
  - the closed dialog set is :173;
  - a new Fixed-strings row goes after :602;
  - the panel header row is :701 and holds no picker;
  - the Process details row (:92) says statement text is Story 19.10's.
  - Move every citation the suites hold (`npm run test:tools`).
- **Auto-refresh.** The Auto-refresh controls row is AD-43's roster of nine screens. A screen joins only by declaring it in its descriptor and appearing in that row.
- **Every screen** registers the ten-item screen contract: three or more prompts, aliases and Fixed strings.
- **Confirmations.** A destructive action uses a `confirm-dialog` with a typed-name field. An agent proposal carries none. Dialogs never stack.
- **The picker.** The Definitions screen is open to OcuPilot administrators only, so the picker cannot list definitions through that screen's read (inference). The context chip and each turn's egress line name the turn's own provider and host, so both must follow a picked definition (inference).

## Cross-Story Dependencies

- **Done:** 19.1 to 19.9 and 19.12 to 19.17. **Order:** 19.10, then 19.11.
- **What the remaining stories reuse:**
  - 19.10 reuses the catalog's fixed-statement reads and the statement-text field (19.5, 19.14).
  - 19.11 reuses `SqlPort`, the console guard, governance, the copy-out draft and 19.14's read tools.
- **Process details (6.8)** shows whether a cached query is executing, named by its routine, and defers the statement's text to 19.10.
- **Rosters a change trips:**
  - `ExplorerDescriptor` (with DW-2093's rename), `ReadTool`, `ToolRoundTrip`, `SurfaceCoverage`, `Descriptor`, and `DeveloperFloor`'s `SCREENS`, `TOOLS` and its count word;
  - for a route, `EndpointCoverage` and `DeveloperFloorRoutes`;
  - for a write, `GovernanceBaseline` and `DraftRegistry`;
  - `InjectionChannels`;
  - a regenerated `screens.generated.ts`;
  - for a System Explorer screen, the Home tile captions in `system-explorer.browser-spec.mjs`, which went red in CI at 19.17.
- **Slot A:**
  - Use profile `ocupilot-slot-a` and the throwaway `ocupilot-a2-ci` (52780); never restart the throwaway. Load the source by `rsync` into `/tmp/ocupilot-a2-ci/src/`, then `$System.OBJ.LoadDir`.
  - The macOS `/tmp` cleaner is the first suspect for an unexplained red (DW-2033).
  - Run one test class per call.
- **Epic 18 runs in parallel.** 18.23 is being re-planned and edits the spine and `epics.md`; 18.24 has not started.
  - Keep edits to shared files add-only after checking `.worktrees/epic-18`'s diff: `strings.ts`, `_components.scss`, `Baseline.cls`, `Router.cls`, the roster tests, EXPERIENCE.md, the spine and the bundle budget.
  - DW-2093's rename edits `SurfaceCoverage` rows in place, so it is not add-only.
  - Regenerate generated files rather than hand-merging them.
