# Epic 19 Context: Stage 3 - System Explorer over the Atelier API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Give developers a System Explorer inside OcuPilot. Code browsing, editing, compiling, export and import are built, along with search, compare and macros, the SQL catalog, the guarded query console, the data browser and the embedded class reference. Three stories remain: the DocDB browser (19.17), SQL activity (19.10), and the agent's guarded SQL with a picker among agent definitions (19.11). Every feature reaches the instance through a port, in process, as the signed-in user. None uses the user's password, and none modifies a vendor web application. As in the classic portal, a `%Development` holder gets in.

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

- **One contract.** Every new screen has exactly one descriptor and reaches the outside only through a port that has its own gate, never through an HTTP call to `/api/*`. A read tool and a confirmed write tool arrive with each screen. Every write is a server-minted, fingerprinted proposal that a person confirms. Every read is bounded and reports truncation. Every gate checks the caller's own privileges at call time. A destructive key defaults to disabled.
- **Who gets in.** The API floor is any `%Admin_*` resource or `%Development:USE`. A new surface declares its classic page's `RESOURCE`, read in `irissys/` and never recalled; a screen whose classic page has none says so. Confirm each pair set by running as a purpose-built least-privileged principal.
- **19.17 DocDB** (measured during Story 19.9's plan on `ocupilot-a2-ci`). The page lists, creates and drops document databases, and reports whether `%Service_DocDB` is enabled rather than assuming it.
  - **Stock instance:** the service is disabled; the `%Developer` role grants `%DocDB_Admin:U` and `%Service_DocDB:U`.
  - **The vendor's REST gate:** the service must be enabled and the caller must hold `%Service_DocDB:USE`, plus `%DocDB_Admin:USE` or `%Admin_Secure:USE`.
  - **In-process `%SYSTEM.DocDB`** (`GetAllDatabases`, `CreateDatabase`, `DropDatabase`) checks neither, so the port must repeat the vendor's gate. Create and drop also need WRITE on the namespace's routines database.
  - **Service status:** `CheckServiceStatus^%SYS.DOCDB` answers 822 both when the service is disabled and when the caller lacks the resource, and audits each refusal. To tell the two apart, check the caller's own `%Service_DocDB:USE` first. Reading `Security.Services` needs `%Admin_Secure:USE`.
  - **Names:** a name must be a valid class name. A duplicate or an existing class is refused, so nothing is overwritten. An unqualified name becomes `ISC.DM.<name>`.
  - **Audit:** no vendor event records a create or a drop.
  - **Self-protection:** a name in the `OcuPilot` package is OcuPilot code, which `PROHIBITED.OCUPILOTCODE` refuses.
  - **Out of scope:** the admin API's `/doc-dbs` (WA-11) is a different list.
  - **Vendor defect:** the vendor's REST drop of a database created without a resource fails even for `_SYSTEM` (DW-2084). It does not affect an in-process drop.
- **19.10 SQL activity.** The page lists currently executing statements from `INFORMATION_SCHEMA.CURRENT_STATEMENTS`, showing their text, statistics and application metadata. Cancel is a later catalog row.
  - **Gate:** the classic page `%CSP.UI.Portal.SQL.CurrentStatements` declares `RESOURCE = "%Admin_Operate"`, not `%Development`.
  - **Columns:** the classic page selects server, process, user name, namespace, bound `Parameters` and `CallerName`.
  - **The spec decides** the side-bar area, the columns, whether bound values are screen-only, and which port carries the read. `AtelierPort` would add `%Development:USE` and namespace READ, and its `action/query` carries only fixed statements with privilege checks off (inference).
- **19.11 agent SQL and picker.**
  - **The tool:** it advertises `explorer.sqlquery.run` behind the console's guard, prepared in process with privilege checks on (`SqlPort`); a mutating statement is a confirmed proposal. The proposal card must show the real guard: the mint's fresh read is composed from the proposed statement (DW-2004).
  - **The plan decides:**
    - whether the tool closes the called-function and procedure limit (DW-2003);
    - whether query rows reach the model, which the spine forbids today (console rows are screen-only, AD-36);
    - whether the agent may propose row changes through `explorer.sqldata.save`, which would reopen DW-2057.
  - **The picker:** it chooses among enabled definitions, and the panel names the one in use. Definitions are visible to every user for selection and editable only by OcuPilot administrators. Moving the default marker is a security change (AD-42), so a per-user pick belongs in AD-50's preference store (inference).
- **Governance (AD-22, owner, 2026-10-04).** A story adds each new write key to `Kernel/Governance/Baseline.cls` in the same change, enabled unless its criteria disable it. Destructive keys are disabled, so DocDB create is `true` and drop is `false`. The baseline only grows: flipping `explorer.sqlquery.run`'s existing `false` is not an addition and needs a ruling (inference).
- **Budgets.**
  - **Bundle:** after the 18.7 merge the bundle measures 2,909,916 B against a 2910kB warning, so any client addition crosses it. Re-base `ui/angular.json` with `angular-json.test.mjs` (DW-1166), and stop and ask above 3,800 kB.
  - **Fixed strings:** capped at 2,700 in `strings.test.mjs`; measure before adding.

## Technical Decisions

- **Ports.**
  - Only `AtelierPort` names `%Api.Atelier.*`. It checks the gate first and the version second, and it logs vendor text but never sends it.
  - Caller SQL goes through `Port/SqlPort` (`%Prepare(text, 1)`, every value bound, alarm-bounded, statements released per namespace), never through `action/query` (DW-1963).
  - A new port, such as 19.9's recommended `Port/DocDbPort`, is added to the spine's port list with its gate at the spec gate (AD-29, Rule 20). A test pins any vendor-internal routine it calls, such as `CheckServiceStatus`. 19.9 also recommends answering a disabled service with 409, naming the service.
- **DocDB tools (recommended):**
  - `explorer.docdb.create` declares `CREATES` and fingerprints the name's absence (AD-54);
  - `explorer.docdb.delete` is destructive;
  - both declare their port (AD-52) and add the target routines database's WRITE pair;
  - each needs a named audit gap (AD-15).
- **The write pattern.** One tool serves two callers, and the screen mints no proposal (AD-53, AD-55). Each write accounts for:
  - the per-target lock (AD-34);
  - the fingerprint and the server-computed diff (AD-6, AD-51, AD-54);
  - read-back (AD-58);
  - the change event (AD-14);
  - the copy-out snippet (AD-59);
  - its classic page (AD-44);
  - an audit marker or a named gap (AD-15).
- **Reads (AD-36, AD-24, AD-60).** One declared read serves the screen and the tool. It is capped at 1,000 characters a field and 65,536 in all, and sanitized before it reaches the model. A statement's text is a row field, shown cut at 1,021 characters with `...`.
- **Self-protection (AD-10).** `PROHIBITED.OCUPILOTSQL` refuses SQL that names `ocupilot` or touches an `OcuPilot` schema, reads included.

## UX & Interaction Patterns

- **EXPERIENCE.md, edited in place:** the side-bar line at :159 and the closed dialog set at :173. A new Fixed-strings row goes after :601. The panel header at :700 holds no picker design yet. Move every citation the suites hold (`npm run test:tools`).
- **Every screen** registers the ten-item screen contract: three or more prompts, aliases and Fixed strings. Viewers and tabs stay unlisted.
- **Confirmations.** A destructive action uses a `confirm-dialog` with a typed-name field. An agent proposal carries none. Dialogs never stack.
- **Context chip.** The chip and the per-turn egress line name the turn's own provider and host, so they must follow a picked definition (inference).

## Cross-Story Dependencies

- **Done:** 19.1 to 19.9 and 19.12 to 19.16. **Order:** 19.17, then 19.10, then 19.11.
- **What the remaining stories reuse:**
  - 19.17 reuses `AtelierPort`'s namespace and write pairs.
  - 19.10 reuses the catalog's fixed-statement reads and the statement-text field (19.5, 19.14).
  - 19.11 reuses `SqlPort`, the console guard, governance and the copy-out draft.
- **Contended in-place edits (19.17):**
  - a new read source kind touches `Screen/Read.cls`, `Screen/Registry.cls` and `ui/tools/screen-mirror.mjs`;
  - a drop touches `DESTRUCTIVE_ACTIONS` in `screen-action-handler.ts`;
  - a live fixture must enable `%Service_DocDB` and restore it.
- **Rosters a change trips:**
  - `ExplorerDescriptor`, `ReadTool`, `ToolRoundTrip`, `SurfaceCoverage`, `Descriptor`, and `DeveloperFloor`'s `SCREENS`, `TOOLS` and its count word;
  - for a route, `EndpointCoverage` and `DeveloperFloorRoutes`;
  - for a write, `GovernanceBaseline` and `DraftRegistry`;
  - `InjectionChannels`;
  - a regenerated `screens.generated.ts`.
- **Slot A:**
  - Use profile `ocupilot-slot-a` and the throwaway `ocupilot-a2-ci` (52780); never restart the throwaway. Load the source by `rsync` into `/tmp/ocupilot-a2-ci/src/`, then `$System.OBJ.LoadDir`.
  - The macOS `/tmp` cleaner is the first suspect for an unexplained red (DW-2033).
  - Run one test class per call.
- **Epic 18 runs in parallel** (18.22 to 18.24 open). Keep edits to shared files add-only after checking `.worktrees/epic-18`'s diff:
  - `strings.ts`, `_components.scss`, `Baseline.cls`, `Router.cls`, the roster tests, EXPERIENCE.md, the spine and the bundle budget.
  - Regenerate generated files rather than hand-merging them.
