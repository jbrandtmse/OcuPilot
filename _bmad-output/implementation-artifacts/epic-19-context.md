# Epic 19 Context: Stage 3 - System Explorer over the Atelier API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Give developers a System Explorer inside OcuPilot. Sixteen of seventeen stories are done: code browsing, editing, compile, export and import; search, compare and macros; the SQL catalog; the guarded query console with background runs; the data browser; the class reference; the DocDB browser; and SQL activity. One story remains, 19.11. It advertises the console's guarded SQL tool to the agent and adds a picker among enabled agent definitions, so an operations agent and a developer agent can differ. Every feature reaches the instance through a port, in process, as the signed-in user. None uses the user's password, and none modifies a vendor web application.

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

- **19.11's criteria.**
  - Given several enabled definitions, the user chooses among them in the picker, and the panel names the one in use.
  - The agent's SQL tool passes the console's DML and DDL guard, and any mutating statement is a confirmed proposal.
- **DW-1964.** The tool prepares in process with privilege checks on (`SqlPort`, `%Prepare(text, 1)`). It never passes caller SQL through Atelier's `action/query`, which prepares with checks off (DW-1963).
- **DW-2004.** A screen action's fresh read carries no statement: `ScreenAction.Run` reads with an empty payload. So the `GUARD` read, `StateDiff` and the fingerprint's guard fields read empty. Compose the mint's fresh read from the proposed statement, so the card shows the real kind, statement type, tables and consequence.
- **Agent definitions.** These rules come from the PRD's FR-24 and catalog row CP-36.
  - Every user may see definitions for selection; only OcuPilot administrators may edit them.
  - Exactly one is the default. Release 1's panel uses it; a picker among enabled definitions is Stage 3.
  - CP-36 asks for named agents per area, each with an About bubble.
  - A definition carries its own provider, model, endpoint, credential reference, limits, system prompt override, read-only flag and retention.
  - A change to its provider, endpoint or credential disables it until Test connection passes.
- **The contract every surface keeps.**
  - Each write is a server-minted, fingerprinted proposal that a person confirms.
  - Each read is bounded and reports truncation.
  - Each gate checks the caller's own privileges at call time.
- **Budgets.**
  - **Bundle:** 19.10 measured 2,942,499 B against a 2943kB warning, so any client addition crosses it. Re-base `ui/angular.json` with `angular-json.test.mjs` (DW-1166), and stop to ask above 3,800 kB.
  - **Fixed strings:** 2,659 of the 2,700 cap, which leaves 41. Raising the cap is a footprint item for the spec gate.

## Technical Decisions

- **The guard as shipped (19.6).** `SqlPort` runs as follows:
  - It checks `AtelierPort`'s rule-1 read pairs, then prepares the statement whole as the signed-in user in the target namespace, binding every value.
  - It classifies by the prepared `statementType`:
    - `query` (1, 28, 32, 79) runs at once;
    - `dml`, `ddl`, `call` (45) and `other` need a confirmation;
    - session, administration and server-file statements are refused by name.
  - It refuses text that sets a password before any prepare, because the statement index keeps the literal (DW-1982). It refuses a statement with no statement-index row as 422 `EXPLORER.SQL.UNRECORDED`.
  - It refuses `PROHIBITED.OCUPILOTSQL` on every path, reads included.
  - A DDL statement tied to a system privilege needs `%CHECKPRIV`. Statements are released per namespace (DW-1986).
  - An alarm at `TestCall.BoundSeconds` bounds each run, and a transaction the run leaves open is rolled back.
  - Input is one statement of at most 100,000 characters, at most 100 values, and Max rows from 1 to 1,000.
- **`explorer.sqlquery.run`.** It is AD-53's unadvertised case (`ADVERTISED 0`).
  - It is an action-style write on `SqlPort` (AD-51, AD-52): read type `GUARD`, `RUN`, no body.
  - Its fingerprint covers Namespace, Kind, StatementType, Tables, `statement`, `parameters` and `maxRows`. It is destructive.
  - It serves the mutating kinds only. A query runs at once through the console's own route, outside the tool.
  - Its target `(class, <ns>, sql)` serializes runs per namespace, so a confirm cancels every sibling proposal in that namespace (AD-34). 19.11 revisits that.
  - Its key is `false` in `Baseline.cls`.
- **Screen-only results (AD-36, AD-39's sixth exception).** A run's rows, plan, SQLCODE and message never reach a declared read, a tool's view, screen context, the ledger or a log line. 19.6 records a confirmed statement's SQL error as `output`. The agent never reaches a background run (19.15).
- **Named limits.**
  - A function or procedure that a query or CALL invokes can reach a server path or change state while the statement is still typed a query (AD-21, DW-2003).
  - A held compile can skip a DDL statement's object privileges (AD-61, inference).
  - The view base-table limit (AD-10, DW-1987).
- **Audit.** The vendor records no event for a console run (AD-53's named gap fifteen). AD-15 has no case for an SQL run yet; once the agent proposes one, its marker is that write's only record.
- **What advertising reopens.** Each item is a spine edit at 19.11's gate (Rule 20).
  - **AD-53 and AD-8.** The tests that assert the tool is absent from the provider list, the dispatch lookup and the context's `tools` must invert. AD-8's "today ... two Save tools" list omits the license key, `sqlquery.run` and `sqldata.save`, so correct it at origin.
  - **AD-3.** A tool declares `read` or `write`, and the existing tool covers only the mutating kinds. So an agent query needs a decision: a separate read tool, or proposals for reads too (inference).
  - **AD-7.** A turn job never mutates the instance. A query run in a turn extends the fifth shape (statement-index rows), and through a called function it could change state (DW-2003) (inference).
  - **Rows reaching the model** would amend AD-36 and AD-39. An arbitrary table's columns carry no secret classification (AD-3), so only AD-24's bounds and AD-60's sanitizer would stand in front of them.
  - **Statement metadata.** AD-61 rule 7 keeps user names, clients and call stacks out of the statement reads. A free query of `INFORMATION_SCHEMA`'s statement tables would return them (inference). DW-2096 (a credential literal in statement text) is pending on the burn-down sheet.
  - **Row changes.** Letting the agent propose them through `explorer.sqldata.save` (unadvertised, `false`) would contradict AD-36's "row values never reach the model" and make DW-2057 real.
  - **Undecided by 19.6:** refusing code-carrying DDL (types 35-38, 43, 67) for the agent, how the agent supplies `statement`, `parameters` and `maxRows`, and recording a confirmed statement's SQL error.
- **Governance (AD-22, amended by the owner 2026-10-04).**
  - **The rule:** a story that ships a **new** write key adds it to `Kernel/Governance/Baseline.cls` in the same change, enabled unless that story's criteria set it disabled. A key absent from the baseline reads disabled when it mutates. The baseline grows only by such additions and is never regenerated.
  - **The amendment** only continued the new-key rule past the voting week; the old text left later entries to the owner. AD-22 authorizes no change to an already-listed key's shipped value: its only sanctioned edit is an addition.
  - **So:** `explorer.sqlquery.run` is already listed `false`. Advertising it adds no key, and turning it `true` needs a ruling and an amendment (inference that silence does not permit it).
  - **The AD-53 reading.** AD-53's sentence "its key shipping disabled until Story 19.11 advertises it" can be read as anticipating a change (inference). Both precedents left the key `false` when the tool was advertised: `security.auditing.purge` (14.2) and the audit-encryption change.
  - **Who the key affects.** It is asked only on the agent's path, at dispatch and at Confirm. A person's run is never governed. While it reads `false`, the advertised tool returns a structured denial.
- **Definitions and the picker.**
  - **AD-42.**
    - Writing an endpoint requires OcuPilot's administrative resource and is audited.
    - Moving the default marker is a security change: `POST /agent/definitions/:id/default`, administrators only.
    - The context chip and the egress line share `ProviderPort.EgressOf`. Today the chip forecasts from the current default, so a picked definition needs AD-42 amended (inference).
  - **AD-50.** A per-user pick belongs in the Kind-discriminated per-user store (`Kernel/State/Pref`), behind a caller-own shell-chrome route. It is never screen context or a tool's view, never browser storage, and never moves the marker (inference).
  - **The selection list.** `GET /agent/definitions` answers the selection projection to every caller past the floor: name, provider, model, enabled and default. This corrects the previous compile's inference that the picker had no list to read. The Definitions screen and the single-definition read are administrator-only. The projection carries no endpoint host, so the chip needs the port's resolution for the pick (inference).
  - **The turn's definition decides:**
    - the read-only verdict (`Kernel.Restraint.Verdict`, and so the context's `readOnly`, AD-24 and AD-30);
    - the iteration limit (AD-31);
    - the system prompt override (AD-11 rule 1);
    - transcript retention.
  - **Widening.** Picking a read/write definition over a read-only default widens what that user's turns may propose. Enforced read-only, the kill switch and per-user read-only (14.5) still apply (inference).
  - **Validation.** Validate the pick at turn start. State what a pick whose definition was later disabled or deleted falls back to (DW-20's shape). Earlier turns replay to the model (AD-24), so switching definition mid-conversation sends them to the new provider (inference).

## UX & Interaction Patterns

- **EXPERIENCE.md, edited in place:**
  - The panel's Header row (:702) holds avatar, "Agent co-pilot", New conversation and the full-screen toggle, and no picker. The panel's parts are also listed at :153 and :624.
  - Definitions and Switches are open to OcuPilot administrators only (:226).
  - The dialog set is closed (:173).
  - Fixed strings end at :603, so new rows go after it. :597 holds the console's four consequence sentences.
  - The context chip (:626) and the egress line (:261, :627) name the turn's own provider and host.
  - Move every citation the suites hold (`npm run test:tools`).
- **An agent SQL proposal.** It takes the destructive treatment with no typed name. Its card shows kind, statement type, tables and consequence (DW-2004), plus Story 11.8's pairs line. SQL grants are the instance's verdict at prepare, so that line cannot predict them (inference).
- **New conversation and a new turn** cancel every live proposal.

## Cross-Story Dependencies

- **Done:** every story except 19.11. 19.10's CI run 37352698013 was pending at the last log entry.
- **19.11 reuses:**
  - `SqlPort`, `ExplorerSqlRun` and the console guard with its strings;
  - governance and the AD-59 draft;
  - 19.14's statement read tools;
  - the definitions list route, the `Pref` store and `ProviderPort.EgressOf`.
- **Rosters a change trips:** `ToolRoundTrip`, `ToolEmit`, `ReadTool`, `SurfaceCoverage`, `Governance`, `GovernanceBaseline`, `DeveloperFloor` (`TOOLS` and its count word), `Prohibited`, `SqlConsoleWrite`, `DraftRegistry`, `InjectionChannels`, and the client's `screen-mirror` and `strings` suites.
- **DW-2093.** The `ExplorerDescriptor` method rename belongs to Epic 19's close burn-down. Any change 19.11 makes to that area's counts drifts the name further.
- **Slot A:**
  - Use profile `ocupilot-slot-a` and the throwaway `ocupilot-a2-ci` (52780/1979). Never restart the throwaway.
  - Load the source with `rsync` into `/tmp/ocupilot-a2-ci/src/`, then `$System.OBJ.LoadDir("/opt/ocupilot/src", ...)`.
  - The macOS `/tmp` cleaner is the first suspect for an unexplained red (DW-2033).
  - Run one test class per call.
- **Epic 18 runs in parallel.** 18.23 is in rework and adds `security.encryptionstartup.update` to `Baseline.cls`; 18.24 has not started.
  - Keep edits to shared files add-only after checking `.worktrees/epic-18`'s diff: `Baseline.cls`, the spine, `epics.md`, EXPERIENCE.md, `strings.ts`, the roster tests and `angular.json`.
  - Regenerate generated files rather than hand-merging them.
