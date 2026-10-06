# Epic 19 Context: Stage 3 - System Explorer over the Atelier API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Give developers a System Explorer inside OcuPilot: code browsing, editing, compile, export and import; search, compare and macros; the SQL catalog; the guarded query console and the agent's guarded SQL; the data browser; the class reference; the DocDB browser; and SQL activity. Seventeen of eighteen stories are done. The last, 19.18, is the epic's burn-down. It closes the five ledger entries Epic 19 filed against its own surfaces before the epic merges, so the agent's read tools describe their criteria truthfully and the screens read correctly. Every feature reaches the instance through a port, in process, as the signed-in user, without the user's password and without modifying a vendor web application.

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
- Story 19.18: Epic 19 burn-down

## Requirements & Constraints

- **19.18's five legs.** Read each ledger entry with `bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md show DW-n`.
  - **DW-1001.** A derived read tool describes each text criterion as the port accepts it, and a test reads each affected tool's emitted description. The criteria that take one exact name, or literal search text, currently carry the generic comma-list description.
  - **DW-1945.** `ExplorerWrite`'s agent legs for compile and delete go through `Dispatch.Answer`, as `ExplorerTransfer`'s do. Then a schema, pairs or governance regression on those tools reddens them.
  - **DW-1977.** The three SQL statements tabs and their read tools' descriptions say, in one sentence, that the figures are as of the instance's last aggregation.
  - **DW-2092.** The data browser's save dialog, tab and status sentences take singular and plural forms ("1 row changes", "1 change waiting to be saved").
  - **DW-2093.** `ExplorerDescriptor`'s area-count test method is named for the counts it asserts, and its `SurfaceCoverage` rows are renamed with it.
- **The contract every surface keeps.** Each write is a server-minted, fingerprinted proposal that a person confirms. Each read is bounded and reports truncation. Each gate checks the caller's own privileges at call time.
- **Budgets.**
  - **Bundle:** 19.11 measured 2,953,622 B (JS 2,749,972 and CSS 203,650) against a `maximumWarning` of 2954kB, so any client addition crosses it. Re-base the warning in `ui/angular.json` and `ui/tools/angular-json.test.mjs` (DW-1166). The error is 4000kB; stop and ask above 3,800 kB.
  - **Fixed strings:** 2,664 literals in the table against `strings.test.mjs`'s 2,700 bound (:583-587), with `STRINGS` holding 2,665 keys. The bound moves story by story, each move with a comment.

## Technical Decisions

- **DW-1001: the mechanism already exists.** AD-36 lets a criterion declare `hint`, added by Story 18.19 and present on this branch. The read tool publishes `hint` as that criterion's description in place of its kind's generic one, and the screen never shows it.
  - **Where it lives.** `Screen/Registry.cls` allows it on any kind (`CriteriaHintProblem`, at most 300 characters). `ui/tools/screen-mirror.mjs` holds the same rule (`criteriaHintProblem`). `Screen/Tool/Read.cls` `AddCriteria` publishes it, followed by the omit or default sentence (always for a `datetime`, for text or choice only when a default is declared), and a choice keeps its `enum`.
  - **What is left.** The grammar likely needs no change and AD-36 no edit (inference). The work is declaring hints in the descriptors, regenerating `ui/src/app/core/screens.generated.ts`, and adding the test.
  - **The test pattern.** `JournalDescriptor`'s hint leg reads `Read.InputSchema(class).properties.<param>.description`. `ExplorerDescriptor` (:392-404) already pins the statements tools' exact descriptions.
  - **Bundle cost.** Hints are emitted into the client mirror, so they ship in the bundle (inference).
  - **No strings work.** A hint is never shown on screen, so it needs no `strings.ts` key or Fixed-strings row.
- **DW-1001: which criteria.** The descriptors hold 44 text criteria with no `hint`, and each carries "A server-search criterion, as a comma-separated list of names. * matches any name. Omit it to match every name."
  - **Named by the AC (22):**
    - `webapp.openapi` `application` and `security.secrets` `collection`;
    - `explorer.search` `text`, which a `*` or comma list searches literally, answering 0 rows with no refusal;
    - `explorer.macro` `document` and `macro`;
    - the 17 SQL catalog tools: `schema` on `sqltables`, `sqlviews` and `sqlprocedures`; `table` on `sqltable`, `sqlfields`, `sqlindices`, `sqltriggers`, `sqlconstraints`, `sqlpartitions`, `sqlpartitionmappings`, `sqlcachedqueries` and `sqltablestatements`; `view` on `sqlview`, `sqlviewfields` and `sqlviewstatements`; and `procedure` on `sqlprocedure` and `sqlprocedurestatements`.
  - **Also Epic 19's:** `explorer.class` and `explorer.routine` `name`, which take one exact document name (the ledger's 19.1 occurrence).
  - **Genuinely comma lists:** `logs.audit`'s six criteria, and `explorer.classes` and `explorer.routines` `pattern`. AtelierPort's `pattern` also takes a leading `'` to exclude a piece, which the generic sentence omits.
  - **Outside the AC's list (13):**
    - in `osmgmt`: `databasedetails` and `databasevolumes` `dir`; `globalmappings`, `packagemappings` and `routinemappings` `namespace`; `journalfile` and `journalfiledatabases` `file`; `languageserveractivity` `name`; `processdetails` `pid`;
    - in `tasks`: `taskdetails` and `taskhistory` `taskId`, and `history` `search` (6.7's occurrence).
  - **Scope.** The AC's general clause may be read to cover these 13; the plan decides (inference).
  - **Parent-scoped criteria.** A parent-scoped (route-id) criterion is required, so "Omit it to match every name" is false there as well.
- **What the catalog and search criteria accept (AD-61).**
  - A catalog tab's schema, table, view or procedure is bound as a parameter. It is resolved through the caller's privilege-filtered `INFORMATION_SCHEMA` row, and no pattern argument (`pFilter`) is ever sent.
  - A search sends `regex=0`, never `word` or `wild`.
  - Macro names are validated by shape.
  - The journal hints show the house style: "spelled as `<tool>.read` answers its Name".
- **DW-1977: already shipped (inference).**
  - **What shipped.** f1d89c56 ("feat(19.14): DW-1977 statistics note") added AD-36's `read.note {key, text}`, validated alike by the registry and the mirror. The three statements descriptors declare it with key `explorerSqlStatementsNote` and text "Statistics are as of the instance's last aggregation, so a recently run statement can read blank." The list page draws it above the rows, `Read.Description` appends it, and the `ExplorerDescriptor`, list-page and browser specs pin it.
  - **What is left.** The ledger entry is still open, so the leg is to verify and close it.
  - **Why the tabs do not aggregate.** AD-61 rule 7 forbids reading `%SQL_Manager.StatementIndex`, because its aggregation journals writes into IRISSYS, HSCUSTOM and USER.
- **DW-1945: which tests move.**
  - **Today.** `ExplorerWrite.MintFor` (:76-93) calls the tool's `View` directly. `ExplorerTransfer.DispatchFor` (:85-113) instead sends one `tool_use`, named through `Screen.Tool.Registry.WireName`, through `Kernel.Agent.Dispatch.Answer`, then parses the tool result.
  - **The two legs.** The compile leg is `TestTheAgentCompilesThroughConfirm` (:223). The delete leg is `TestTheAgentsDeleteIsGovernedAndThenConfirmed` (:281). Its "refused at the dispatch gate" is asserted through `Gate.Decide`, never through the dispatcher.
  - **The governance leg.** The dispatcher refuses a key the baseline disables at dispatch (`is_error`, code `GOVERNANCEDISABLED`). `ExplorerTransfer`'s import leg (:228-232) asserts that refusal, then keeps a direct mint to prove the confirm-side 403.
  - **Keys.** At the baseline `explorer.classes.compile` is true and `explorer.classes.delete` false. AD-22 permits no change to a listed key's value.
- **DW-2093: the rename.**
  - `TestTheAreaHoldsTwentyFourReadsAndEightWrites` (:141) asserts 26 reads and 11 writes since 19.11, and its doc comment already says so.
  - `SurfaceCoverage.cls` :324-331 names it in eight rows: classes and routines compile, delete, export and import.
  - Rename the method and the rows in one change, because the roster resolves each row to a compiled method (inference).
  - A count-named method drifts again with the next Explorer tool (inference).
- **DW-2092: the strings.**
  - `explorerSqlDataSaveConsequence` is used at `data-browser.page.ts`:608.
  - `explorerSqlDataWaiting` is used at `data-browser.page.ts`:455 (the tab name) and `data-browser.store.ts`:768 (the status).
  - **House pattern.** A `...One` key is chosen when the count is 1 (`explorerCompileTitleOne`, `formTabErrorOne`). The consequence sentence holds three counts, so one key per combination does not scale, and the plan picks a composition (inference).
  - **Other plural-only sentences the AC does not name:** `explorerSqlDataDiscarded` (store :567), `explorerSqlDataSavedSummary` (store :619), and the console's `explorerSqlRowsChanged` (`sql-answer.ts`:96).
- **Bounds and sources stay put (AD-3, AD-5, AD-24, AD-36).**
  - A descriptor is the one source, and the mirror is generated, never hand-edited.
  - A description is the hand-authored semantic half, written once and reviewed.
  - A description or note changes no read, field set, filter or bound, and screen and tool still share one read.
  - A note carries no instance data.

## UX & Interaction Patterns

- The data browser's literals sit in EXPERIENCE.md's Fixed-strings row at :599. A new singular form is a new literal there and in `strings.ts`, and `strings.test.mjs` holds the two equal.
- Moving a line shifts the citations the suites hold, so run `cd ui && npm run test:tools`.
- Neither a hint nor a test rename changes any screen.

## Cross-Story Dependencies

- **Done:** every story but 19.18. 19.11's CI run 37389702149 was pending at the last log entry.
- **Rosters a change trips:** `ExplorerDescriptor`, `SurfaceCoverage`, `ExplorerWrite`, the client's `screen-mirror`, `strings` and `angular-json` suites, and the `--check` prebuild that compares `screens.generated.ts` with the descriptors.
- **Slot A:**
  - Use profile `ocupilot-slot-a` and throwaway `ocupilot-a2-ci` (52780/1979), which is running. Never restart the throwaway.
  - Load the source with `rsync` into `/tmp/ocupilot-a2-ci/src/`, then `$System.OBJ.LoadDir("/opt/ocupilot/src", ...)`.
  - Run one test class per call.
  - The macOS `/tmp` cleaner is the first suspect for an unexplained red (DW-2033).
- **Epic 18 is paused after 18.23.** 18.23 is in progress and not merged into feature, with CI run 37388387925 pending.
  - **18.23's diff** touches the spine, `epics.md`, EXPERIENCE.md, `Baseline.cls` and `strings.ts` (+93 lines). It adds a new descriptor, `EncryptionStartup`, and two `SurfaceCoverage` rows near :200 and :366. It re-bases the warning in `angular.json` (2940kB to 2973kB) and in `angular-json.test.mjs`.
  - **What 18.23 does not touch:** `Registry.cls`, `Read.cls`, `screen-mirror.mjs`, `ExplorerWrite`, `ExplorerDescriptor` and the data browser files.
  - **18.24 (RSA and symmetric-key wallet secrets)** is in backlog and likely edits `WalletSecretList.cls`, where `security.secrets`' hint goes (inference).
  - Keep shared-file edits add-only, and regenerate generated files rather than hand-merging them.
- **The branches meet over budget.**
  - **Fixed strings.** From 2,650 at the shared base (cbdeecc4), Epic 18's branch now holds 2,691 literals and this branch 2,664. Merged, that comes to about 2,705, over the 2,700 bound before DW-2092 adds any (inference, which assumes no literal is counted on both sides).
  - **Bundle warning.** Each branch re-bases the same `maximumWarning` line to a different value, so the merge conflicts there (inference).
