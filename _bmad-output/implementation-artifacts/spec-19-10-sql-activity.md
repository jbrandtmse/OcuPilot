---
title: 'Story 19.10: SQL activity'
type: 'feature'
created: '2026-10-05'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-19-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** An administrator diagnosing a slow instance cannot see which SQL statements are running right now. The classic page that shows them, `%CSP.UI.Portal.SQL.CurrentStatements`, lives in System Operation behind `%Admin_Operate`. The table it reads, `INFORMATION_SCHEMA.CURRENT_STATEMENTS`, answers every running statement on the instance to any principal that can run SQL, and its bound `Parameters` hold values in clear (measured).

**Approach:** Add an OS management screen, SQL activity (`os-management/sql-activity`). It lists the instance's running statements through a new port, `Port/SqlActivityPort`, which runs one fixed read in process behind the classic page's measured gate. Each row carries the statement's text, its execution statistics and its application metadata. The read joins auto-refresh, its Process ID cell opens Process details, and the agent gets the same rows from `osmgmt.sqlactivity.read`.

## Boundaries & Constraints

**Always:**

- **The port's gate (AD-29).** `SqlActivityPort` checks `PAIRS` = `%Admin_Operate:USE,%DB_IRISSYS:READ` in order, before any read, through `Screen.Gate.EvaluateRequired` behind a `GateClass` seam, as `DocDbPort` does.
  - A refusal answers 403 `PORT.ACCESSDENIED`, with `detail.failedPair` naming the pair.
  - The descriptor declares the same two pairs. OS management's set already covers both, so the screen declares no own pair.
- **One fixed statement, in the caller's namespace.**
  - The statement is `CURRENTSTATEMENTS`. It reads `INFORMATION_SCHEMA.CURRENT_STATEMENTS`, ordered by `ExecutionDuration` descending, and is prepared with `%SQL.Statement` in the process's own namespace. It needs no switch (AD-16) and binds nothing (AD-21).
  - It never selects `Parameters`, and it never calls `GetSQLStatement` inside the SQL.
  - A row whose `ProcessID` is `$JOB` (the reading process's own statement) is left out.
- **The row** is `{Server, ProcessID, UserName, Namespace, RunType, Elapsed, Started, StatementId, StatementHash, Statement, Routine, CachedQuery, Workers, TransactionLevel, Remote}`:
  - `RunType` is the classic page's `CASE WHEN Parent IS NULL THEN QueryRunType ELSE ParentType || ' Query' END`.
  - `Elapsed` is `ROUND(ExecutionDuration, 3)`, a number.
  - `Started` is `ExecutionStart`, the instance's local time as the vendor answers it.
  - `Routine` is `CallerName`. `TransactionLevel` is `TP_NestingLevel`.
  - `Remote` is true when `Server` differs, ignoring case, from `$ZU(110)_":"_$Get(^%SYS("SSPort"))`. This is the classic page's test (`CurrentStatements.cls:320`), done by a pure `IsRemote(server)`.
  - The port answers rows in `ExecutionDuration` order and cuts them at the query's `maxRows`.
- **The statement text** comes from the vendor's documented `##class(INFORMATION.SCHEMA.CURRENTSTATEMENTS).GetSQLStatement(ns, hash, .sc)`, called through a `Text` seam:
  - **Pre-check:** the port calls it only when the caller holds READ on the resources guarding the row's namespace's routines and globals databases. It resolves them once per namespace per read through `AtelierPort.DatabaseResources`. An empty resource, or a pair the caller lacks, answers `""` with no call, which writes no `Protect` audit row.
  - **Withheld:** an answer of #921 (another user's statement, read without `%Development:USE`) answers `""`.
  - **Failure:** any other error status, or a throw, fails the whole read with 500 `INTERNAL`. The vendor text is logged and never sent (AD-39).
  - **Shaping:** the text is `$ZStrip(text, "<>WC")`. Text longer than 1,024 characters is cut to its first 1,021 and `...`, as 19.14's statement text is (AD-36).
- **The descriptor:**
  - `OcuPilot.Screen.Descriptor.SqlActivityList`: route `os-management/sql-activity`, area `os-management`, `sideBarPosition` 20, archetype `list`.
  - Auto-refresh: `refreshes` true and `refreshRates` `[5, 10, 30, 60]`, default off (AD-43).
  - Entity: type `sql-statement` (new, no id rule), scope `instance`, id `{composite, [Server, ProcessID, StatementHash]}` (the vendor's IdKey).
  - Actions: none, primary or row.
  - `rowTarget`: `{route: os-management/processes/details, field: ProcessID, unless: Remote}`.
  - Classic page: `%CSP.UI.Portal.SQL.CurrentStatements` (`NormalizePage` measured). `toolIdentifier` is `osmgmt.sqlactivity`.
- **Strings:** every new sentence lives once in `strings.ts` and once in EXPERIENCE.md's Fixed strings. Styling uses `--ocu-*` tokens only, and the DW-1337 structural gate holds in both themes.

**Never:**

- `Parameters`, which holds bound values with no schema and can hold a secret (AD-35), in any read, field, log line or tool result.
- `%SQL.Manager.Catalog`, `UpdateSQLStatsByHash^%SYS.SQLSRV`, `%SQL_Manager.StatementIndex` or `%SYS.AppMetadataStack.SQL`.
- An `%Api.Atelier` route (AD-61) or a `/api/*` call (AD-1).
- Cancel query (catalog OS-24, a later row), a write tool, a governance key, a new error code, or anything added to `Api/Error.cls`.
- A client page, store or dialog. The generic `ListPage` serves the screen.
- A change to Process details' read or page.

## I/O & Edge-Case Matrix

Measured on `ocupilot-a2-ci` (Design Notes › Measured). "Probe" means a long statement another account runs in USER, binding the value `OcuSecretProbe1910…`.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| List | probe running; caller holds the two pairs | The probe is a row: `Namespace` `USER`, `RunType` `DynamicStatement`, `Elapsed` above 0, `CachedQuery` set, `Remote` false. Rows come slowest first, and the reading process's own statement is absent. The tool answers the same rows. | None |
| Nothing running | only the reading process | no rows; the empty state | None |
| Parameters | probe binds `OcuSecretProbe1910…` | the value appears in no field of the screen's answer or the tool's | None |
| Text, no database READ | caller lacks `%DB_USER:READ` | `Statement` `""`, drawn as "Not shown"; `GetSQLStatement` is not called; the `Protect` audit row count is unchanged | None |
| Text, no `%Development` | caller holds `%DB_USER:READ` | `Statement` `""` (vendor #921) | None |
| Text shown | caller holds `%Development:USE` and `%DB_USER:READ`, or the statement is the caller's own | the vendor's text, cut at 1,021 characters plus `...` when it is over 1,024 | None |
| Pair missing | caller lacks `%Admin_Operate:USE` or `%DB_IRISSYS:READ` | 403 `PORT.ACCESSDENIED` naming it; no statement prepared; the side bar lists the screen unavailable, naming it | Refusal as today |
| Vendor fault | `Text` answers an error other than #921 (seam) | 500 `INTERNAL`, no rows; the vendor text is logged | Logged |
| Remote row | `IsRemote` of another `server:port` | true, so the Process ID cell is text; local is false | None |

</intent-contract>

## Code Map

Paths are under `src/OcuPilot/` or `ui/` unless given in full. Line numbers were read at HEAD `c43a8286`.

- **Templates:**
  - `Port/DocDbPort.cls`: `PAIRS` :41, `GATECLASS` :44, `ENDPOINT` :47, `TYPELIST` :50, `GateClass` :119, `Pairs` :126, `Invoke` :226 (inline gate :233-238), `Deny` :493, `SnippetForm` :551, `Snippet` :566.
  - `Port/BackgroundTaskPort.cls` is an instance-scoped list port with no namespace and no criteria.
  - `Port/AtelierPort.cls` `DatabaseResources` :677 gives the routines and globals resources.
- **Read source kind** (template: `docdb`, with `background`'s no-namespace dispatch):
  - `Screen/Read.cls`:
    - `SOURCEDOCDB` :268 and `DocDbPortClass` :272-275;
    - the allow-list :375;
    - the background branch :414-423 and the docdb branch :490-499;
    - the doc comment :26, which still says "three source kinds".
  - `Screen/Registry.cls`:
    - the allow-list :1142 and its "ten sources" sentence :1143;
    - the background rules :1187-1208 and the docdb rules :1209-1230;
    - the stale `ReadProblem` doc :1077-1092;
    - `RefreshProblem` :450-486 (refuses refresh with criteria, :1610).
  - `tools/screen-mirror.mjs`:
    - `SOURCE_*` :933-950 and `READ_SOURCE_PORTS` :951;
    - the docdb trio :1014-1030;
    - `readProblem` :1214, with its sentence at :1232-1237;
    - the docdb arm :1296-1309;
    - the union template :3392, which regenerates `src/app/core/screens.generated.ts`.
- **Screen:**
  - `Screen/Descriptor/LockList.cls` is the template: an OS management list with a `rowTarget` to Process details (:98).
  - `ProcessList.cls` has the refresh rates.
  - `Kernel/EntityType.cls` `TYPES` :82 (19.17's doc-line form).
- **Vendor (read-only):**
  - `irislib/INFORMATION/SCHEMA/CURRENTSTATEMENTS.cls` (columns; `GetSQLStatement` is a public `SqlProc`);
  - `irislib/%CSP/UI/Portal/SQL/CurrentStatements.cls`: `RESOURCE` :21, query :213-235, `isCluster`/server test :320, text :348-402.
- **Client:**
  - `src/app/shell/screen-outlet.ts:117-129` maps `list` to `ListPage`, with no `DESCRIPTOR_PAGES` entry.
  - `data-table.ts:632-680` draws the `rowTarget` link on the `name` cell, with `unless`.
  - `refresh.ts:243-254` binds the chip from the mirror.
  - `core/strings.ts`: the last key is :5743 and `} as const` is :5744. Reuse `processColumnPid`, `processColumnUser`, `processColumnRoutine`, `headerNamespaceLabel`, `taskHistoryColumnStarted`, `explorerSqlColumnStatement` and `tableReadOnlyEmptyNext`. `strings.test.mjs:771` refuses duplicate values.
- **EXPERIENCE.md** (`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/`): Process details :92, the OS management side bar :164, the last Fixed-strings row :602, Auto-refresh controls :889 (keep "On Processes", which `citations.test.mjs` resolves by phrase).
- **Rosters a change trips** (`Test/` unless shown):
  - `ReadTool` :93 (275 → 276) and its roster :94.
  - `ToolRoundTrip` `REFUSEEMPTY` :75 stays unchanged, since the read answers `{}` at 200.
  - `SurfaceCoverage`: a screen row after :199.
  - `Descriptor`: a `ReadShapes` row before :174, and `EntityType` count :1748 (55 → 56).
  - `PortGate` `ROSTER` :29, plus a denial leg beside the docdb leg :237-247 through a gate seam.
  - `DraftRegistry` :229-241 requires `Snippet` and `SnippetForm`.
  - The "ten sources" sentence, pinned at `AdminPairCorpus:58` and `DocDbDescriptor:59`.
  - `Navigation` :493 (45 → 46) and its per-index rows :494-498.
  - `Wire` :723-744: a strip step for the new last entry, which an Operate-only principal sees denied on `%DB_IRISSYS:READ`. The area verdict at :406-407 is unchanged.
  - `WireSecurityRead` :570, :577, :580.
  - `DeveloperFloor` :218-226, which derives the refusal.
  - Client: `tools/screen-mirror.test.mjs` `READ_SOURCE_PORTS` :2699, and a per-source test beside docdb's :2778-2805; `tools/navigation.test.mjs` :134-223 (after :223) and :343-375.
- **Injection (AD-11 rule 5):** `Test/InjectionChannels.cls` source (m) is at :296-308, and `Test/InjectionSeed.cls` `Plant` at :154, with source m's plant and remove at :488-518.
- **Principals:**
  - `Test/DocDbGate.cls` `PRINCIPALS` and `EnsurePrincipals` :181.
  - `Test/DocDbProbe.cls` `Probe` :319, which logs in as the principal in a child process.
  - `scripts/ci-throwaway.sh` PRINCIPALS `# classes:` lines :217-336, checked by `ui/tools/ci.test.mjs:2177-2207`.
- **Budgets:**
  - `angular.json:54` is `2940kB` against a measured 2,939,195 B, pinned at `tools/angular-json.test.mjs:521`.
  - Fixed strings: 2,650 literals of the 2,700 cap (`strings.test.mjs:585-588`).

## Tasks & Acceptance

**Execution:**

- [ ] `src/OcuPilot/Port/SqlActivityPort.cls` (new) -- the Boundaries' port.
  - Members: `PAIRS`, `ENDPOINT` `CurrentStatements`, `TYPELIST` `LIST`, `CURRENTSTATEMENTS`; `Invoke` (gate, a body refused, any other endpoint or type 501 `PORT.NOTIMPLEMENTED`); the private seams `Rows` and `Text`; and the pure `IsRemote`.
  - `Snippet` and `SnippetForm` answer `[]` and `""`, since the port has no write (AD-59).
  - The doc comment names the measured exposure and the two vendor answers it maps.
- [ ] `src/OcuPilot/Screen/Read.cls`, `Screen/Registry.cls`, `ui/tools/screen-mirror.mjs` -- add the `sqlactivity` source kind.
  - `Read.cls`: `SOURCESQLACTIVITY`, a `SqlActivityPortClass()` seam, the allow-list entry, and a dispatch branch that seeds only `maxRows` (cap + 1), as background does.
  - Registry and mirror alike: endpoint `CurrentStatements`, type `LIST`, and no `rowGet`, `forEach`, `query`, `parts` or `rows`. The sentence becomes "eleven sources".
  - Correct the stale source-kind docs at `Read.cls:26` and `Registry.cls:1077-1092`, then regenerate `screens.generated.ts`.
- [ ] `src/OcuPilot/Kernel/EntityType.cls` -- add `sql-statement` with its doc line.
- [ ] `src/OcuPilot/Screen/Descriptor/SqlActivityList.cls` (new) -- the Boundaries' descriptor.
  - Read fields: the row.
  - `filter`: `ProcessID, UserName, Namespace, RunType, Statement, Routine`.
  - `sort`: `ProcessID, UserName, Namespace, RunType, Elapsed, Started`, defaulting to `Elapsed` descending.
  - `paging`: `cap`. `read.note`: `sqlActivityNote`.
  - Columns:
    - Process ID (`name`), User, Namespace, Run type, Elapsed (s) (`number`);
    - Statement (`identifier`, `emptyKey` `sqlActivityTextWithheld`);
    - Routine (`identifier`) and Started.
  - Context fields: every read field; no secret fields.
  - Prompts: three, group `promptGroupTroubleshooting`. Aliases: `sql activity`, `running queries`, `current statements`. Empty state: `emptyNextKey` `tableReadOnlyEmptyNext`, no agent key.
- [ ] `src/OcuPilot/Test/SqlActivityProbe.cls` (fixture, new).
  - `Start(ns, literal, value, .pid)` JOBs a CPU-bound probe statement and waits until its row is listed. The statement is a dictionary cross join that keeps `literal` in `((...))` and binds `value`.
  - `Stop(pid)` terminates the job and waits until its row is gone.
  - `ProtectCount()` counts `%System/%Security/Protect` rows with `%IGNOREINDEX`.
  - `Probe` reads as a principal in a child process, after `DocDbProbe.Probe`.
  - Principal helpers refuse unless `OCUPILOT_ALLOW_PRINCIPALS` reads 1.
- [ ] `src/OcuPilot/Test/SqlActivityDescriptor.cls` (new, unarmed) -- the registry and mirror refusals for the source (the `Cases` corpus `screen-mirror.test.mjs` runs), and the descriptor's shape.
- [ ] `src/OcuPilot/Test/SqlActivityPort.cls` (new, unarmed) -- the matrix's port rows as the suite's account, and a pin on the vendor surface.
  - Rows: list, own row absent, ordering, `maxRows` cut, Parameters absent from the port and the tool result, the cut over 1,024 characters, `IsRemote`, and the vendor-fault seam.
  - The vendor pin covers the columns `CURRENTSTATEMENTS` selects and `GetSQLStatement`'s signature.
  - Every probe job is stopped after each method.
- [ ] `src/OcuPilot/Test/SqlActivityGate.cls` (new, armed PRINCIPALS) -- purpose-built principals, each with READ on the install namespace's code database.
  - `OcuP1910Exact`, holding the two pairs: lists another account's probe in USER, text withheld, `ProtectCount` unchanged.
  - `OcuP1910NoOperate` and `OcuP1910NoSys`: refused, naming their pair.
  - `OcuP1910Read`, adding `%DB_USER:READ`: text withheld (#921).
  - `OcuP1910Dev`, adding `%Development:USE`: the text is shown.
- [ ] `src/OcuPilot/Test/InjectionSeed.cls`, `InjectionChannels.cls` -- source (n). The planted probe statement keeps the seed as a literal, `osmgmt.sqlactivity.read` reads it in a turn, and teardown stops the job.
- [ ] `src/OcuPilot/Test/SqlActivityGateSeam.cls` (new) -- overrides `GateClass` for `PortGate`'s denial leg, as `DocDbGateSeam` does. Then update the rosters (Code Map › Rosters): each count and roster follows what its derivation answers, and each new name is read from the instance.
- [ ] `scripts/ci-throwaway.sh` -- add-only `# classes:` line for `SqlActivityGate` under PRINCIPALS (near :336).
- [ ] `ui/src/app/core/strings.ts` (end), EXPERIENCE.md -- the Design Notes › Strings.
  - EXPERIENCE.md edits:
    - a new Fixed-strings row after :602;
    - in place at :164, append "· SQL activity (Stage 3, Story 19.10)";
    - in place at :889, append "SQL activity" after Dashboard;
    - in place at :92, "statement text is Story 19.10's" becomes "its statement text is on SQL activity, whose Process ID cell links here".
  - Then move every citation `strings.test.mjs` reports.
- [ ] `ui/angular.json`, `ui/tools/angular-json.test.mjs` -- re-base `maximumWarning` on the measured build (DW-1166). Stop above 3,800 kB.
- [ ] `ui/browser/sql-activity.browser-spec.mjs` (new) -- run against the throwaway (it refuses the live and slot containers).
  - Start a probe through `runIris`, open the screen, and see its row's Process ID, Namespace, Elapsed and Statement.
  - The Process ID link opens Process details for that pid.
  - The auto-refresh chip offers 5/10/30/60 s and starts off.
  - `after` stops the probe.

**Acceptance Criteria:**

- **AC1 (Integration).** Given a probe statement running in USER under another account on `ocupilot-a2-ci`, when a caller holding `%Admin_Operate:USE` and `%DB_IRISSYS:READ` opens OS management › SQL activity, then the probe is a row (Process ID, User, Namespace, Run type, Elapsed, Statement, Routine, Started) read through `SqlActivityPort`, the reading process's own statement is not, and `osmgmt.sqlactivity.read` answers the same rows.
- **AC2 (gate).** Given purpose-built principals each lacking one pair, when each reads, then each is refused 403 naming that pair before any statement is prepared, and the side bar lists SQL activity unavailable with that pair.
- **AC3 (text).** Given the matrix's three text rows, when each principal reads, then:
  - without the namespace's database READ the text is empty, no `GetSQLStatement` call is made and no `Protect` audit row is written;
  - without `%Development:USE` another account's text is empty;
  - with both the text is shown, cut at 1,021 characters plus `...` above 1,024.
- **AC4 (no bound values).** Given the probe binds `OcuSecretProbe1910…`, when the screen and the tool read, then no answer carries the value.
- **AC5 (link).** Given a listed probe, when its Process ID cell is clicked, then Process details opens for that pid. Given `IsRemote` true, the cell is text.
- **AC6 (auto-refresh).** Given SQL activity, when it opens, then the command bar's auto-refresh chip offers 5, 10, 30 and 60 s and starts off.
- **AC7 (injection).** Given a running statement whose text keeps the seed, when a turn reads it through `osmgmt.sqlactivity.read`, then the seed arrives inside a `tool_result` only, and the turn mints no proposal, announces no navigation and posts nowhere but the endpoint.
- **AC8 (structure).** Given both themes, when the structural walk and the screen's spec run, then the gate passes and the screen keeps three suggested prompts.

## Spec Change Log

- 2026-10-05, lead (spec gate): the five decisions are ruled tier-1 and written into the spine (Design Paradigm, AD-7's fifth shape, AD-29 `SqlActivityPort` with the FR-80 deviation, AD-36, AD-43 roster ten, AD-61 rule 7 narrowed at origin). Two claims corrected here: SQL activity's pair set is not Processes' (Processes also requires `%Admin_Manage:USE`), and the classic page hides `CallerName`; `Routine` stays as the AC's application metadata. `DatabaseFreeSpace` stays off AD-43's roster by design (Databases' entry covers both views). DW-2093's decline is accepted; it moves to the epic's burn-down.

## Review Triage Log

## Design Notes

**Decisions on the five open questions:**

1. **Area and port: OS management and `SqlActivityPort`, not System Explorer and `AtelierPort`.**
   - The classic page declares `%Admin_Operate` under `/csp/sys/op/`, and the story's persona is a production administrator.
   - `AtelierPort`'s gate adds `%Development:USE` and namespace READ, which would refuse the classic audience. No vendor check requires them: the data is instance-wide and public to SQL (measured). So AD-8 and AD-44 give the classic page's pair set.
   - The classic page lists nothing without `%DB_IRISSYS:READ` (measured), so the set is that page's measured audience. This also leaves `Wire`'s Operate-only area verdict unchanged.
   - FR-80's catalog row names `action/query`. It is the planned backing route, not an AC, and Stories 19.6 and 19.17 left theirs the same way. The spine records the deviation.
2. **AD-61 rule 7 is narrowed at its origin.** It was written for 19.14's statement tabs, whose classic tab shows no user. SQL activity shows `UserName`, as its classic page does, and `Routine` (`CallerName`), which that page selects but hides (`CurrentStatements.cls:115`); the routine is the story's application metadata. It never reads `Parameters` (AD-35).
3. **DW-2093 is declined:** the screen is not in System Explorer, so `ExplorerDescriptor`'s counts do not change.
4. **Process details is unchanged.**
   - The 6.8 amendment places the text "behind Story 19.10's SQL activity screen".
   - SQL activity's Process ID cell links to Process details by pid, as Locks' does. EXPERIENCE.md :92 now says where the text lives.
   - A reverse link would be a client page change, outside this story.
5. **Auto-refresh joins, default off.** The classic page refreshes, which was the reason Process details and the Dashboard joined (AD-43). The roster becomes ten.

**Statistics** are the execution's own: elapsed time, start time, workers and transaction level. The statement's aggregate history is per namespace and already shown by the SQL catalog's statements tab (19.14).

**Measured** (2026-10-05, `ocupilot-a2-ci`; every probe job, routine, user, role and principal removed and each checked gone):

- **Exposure:** a principal holding only READ on HSCUSTOM's database listed, through privilege-checked dynamic SQL in HSCUSTOM, `irisowner`'s statement running in USER. The rows are instance-wide.
- **Bound values:** `Parameters` held the bound value `OcuSecretProbe1910` in clear.
- **Statement text:**
  - Without READ on the statement's database, `GetSQLStatement` answers `<PROTECT>` and writes one `%System/%Security/Protect` audit row per call. This includes the SQL-function form inside a SELECT.
  - With READ but without `%Development:USE`, another user's text answers #921 with no audit row.
  - The caller's own text needs neither.
  - `%SQL.Manager.Catalog.GetStatementInfoOption` behaves the same.
- **The classic page:**
  - As `%Admin_Operate` alone it rendered "No Results" with two statements running.
  - With `%DB_IRISSYS:READ` added, it listed both, each as "Statement text could not be retrieved", and showed its own text.
  - `NormalizePage` answers `%CSP.UI.Portal.SQL.CurrentStatements`.
- **Cost:** with 40 processes, a read of 3 rows took 0.3 ms, and 60 text calls under 1 ms.
- **Server:** `Server` reads `52b901ba53c6:1972`, equal to `$ZU(110)_":"_^%SYS("SSPort")`.

**Strings** (9 literals; 2,650 + 9 of 2,700):

- "SQL activity"
- "Run type"
- "Elapsed (s)"
- "Not shown"
- "No SQL statements are running on this instance."
- "Statement text shows for your own statements, and for another user's when you hold %Development:USE and READ on its namespace's database."
- "Which SQL statements have been running the longest?"
- "Who is running SQL right now, and in which namespace?"
- "Is any statement running inside an open transaction?"

**Spine amendments (drafts, for the lead's gate, Rule 20):**

- **Design Paradigm, the Ports row and Stage 3's capability row:** add `SqlActivityPort` (`INFORMATION_SCHEMA.CURRENT_STATEMENTS`, in process, Story 19.10).
- **AD-29:** add it to Binds, and add this paragraph:
  > `SqlActivityPort` reads the instance's running SQL statements in the caller's process (Story 19.10). `INFORMATION_SCHEMA.CURRENT_STATEMENTS` answers them to any principal that can run SQL (measured), so the port first requires `%Admin_Operate:USE` and `%DB_IRISSYS:READ`, the classic page's measured audience. It reads one fixed statement, leaves out its own process's statement and never selects `Parameters` (AD-35). It reads a statement's text through the vendor's `GetSQLStatement` only when the caller holds READ on the statement's namespace's routines and globals databases, because the call otherwise writes a `Protect` audit row. The vendor withholds another user's text without `%Development:USE`, as the classic page does.
- **AD-61 rule 7:** "no statement read selects a user name, client or call stack" becomes "no SQL statements tab's read selects a user name, client or call stack, as its classic tab shows none; SQL activity (AD-29) shows the running user, as its classic page does".
- **AD-36:** "A declared read may name the SQL activity port (source kind `sqlactivity`, Story 19.10): `LIST` on `CurrentStatements`, with no namespace, criteria, detail call or parts; a running statement's text is a row field, cut as a statement's is."
- **AD-43:** "nine" becomes "ten" in Binds and Rule, and SQL activity is added "(2026-10-05, Story 19.10, default off, as its classic page refreshes)".
- **AD-7's fifth shape:** "So does `SqlActivityPort`'s fixed statement, once per namespace it is read in."

**ADs:** AD-1, AD-5, AD-7, AD-8, AD-11, AD-13, AD-14, AD-19, AD-21, AD-24, AD-29, AD-35, AD-36, AD-39, AD-43, AD-44, AD-59, AD-60, AD-61.

- AD-16: no switch, since the vendor reads other namespaces itself.
- Not engaged: AD-2, AD-6, AD-22, AD-26, AD-27, AD-53, AD-55 (no write, no admin API).

**Integration ACs:** AC1. **Consumes:** `AtelierPort.DatabaseResources`, `Screen.Gate`, `ListPage`, `rowTarget`, the refresh framework. **Consumed-by:** this story's screen and read tool; the first later consumer would be catalog OS-24's cancel (unplanned).

**Footprint (Rule 11)**, checked against `.worktrees/epic-18` at `fdda65d15cda9dd29c99a2db08c3c27cdc3cf47a` (diff and `status -s`, 18.23 re-planning):

- **Contended, for the lead:** the spine and `ui/angular.json` with its test (both epics re-base it on the same line).
- **Not contended:** every other file. Epic 18 touches `EncryptionError`, `EncryptionPort`, `Installer` and its probe.
- **Position 20:** Epic 18's later stories may add an OS management screen at the same position. That is renumbered at the forward merge.
- **Outside `paths_hint`:** EXPERIENCE.md and `scripts/ci-throwaway.sh` (`footprint_extensions`).

**Ledger inbox:** Declined DW-2093: SQL activity lands in OS management, so `ExplorerDescriptor`'s counts do not change; the rename waits for the next story that changes them.

**Ledger candidates for the lead:** `DatabaseFreeSpace` declares `refreshes` true but is named on neither AD-43's roster nor EXPERIENCE.md :889 (low).

## Verification

All of these run on `ocupilot-a2-ci` and never on `ocupilot` or a slot container:

- every check that starts a probe statement or creates principals;
- loading the source: `rsync -a --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-19/src/ /tmp/ocupilot-a2-ci/src/`, then `$System.OBJ.LoadDir("/opt/ocupilot/src","ck",.tErrors,1)` in `docker exec -i ocupilot-a2-ci iris session iris -U HSCUSTOM`. Never restart the container. Touch `/tmp/ocupilot-a2-ci` first, because of the macOS `/tmp` cleaner (DW-2033).

The stateful classes run one at a time: one test-runner call per message, wait for it to land, never re-submit after a timeout. After each, no `OcuP1910*` principal and no probe job remains.

**Commands:**

- `uv run scripts/check-objectscript.py && uv run scripts/test_check_objectscript.py` (loop) -- green.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-a2-ci --class OcuPilot.Test.<X>` (loop), one class at a time -- green:
  - the story's classes: SqlActivityDescriptor, SqlActivityPort, SqlActivityGate, InjectionChannels;
  - the rosters: ReadTool, ToolRoundTrip, SurfaceCoverage, Descriptor, DeveloperFloor, PortGate, DraftRegistry, AdminPairCorpus, DocDbDescriptor, Navigation, Wire, WireSecurityRead.
- `cd ui && npm run test:tools` (loop) -- green.
- Browser (loop). First build and deploy: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-a2-ci:/durable/iris/csp/ocupilot/`. Then run `OCUPILOT_BROWSER_ORIGIN=http://localhost:52780 OCUPILOT_BROWSER_CONTAINER=ocupilot-a2-ci node --test --test-concurrency=1 browser/sql-activity.browser-spec.mjs browser/a11y-structural-invariants.browser-spec.mjs` -- green.
- `bash scripts/lint-docs.sh && cd ui && npm run test:tools` (loop, after the EXPERIENCE.md edits) -- green.
- `cd ui && npm test` (once, before dev_complete) -- green, with the budget re-based.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-a2-ci` (once, before dev_complete) -- the full ObjectScript sweep, one class at a time, green apart from known residue. The full browser suite is CI's.

**Pinning tests and the mutation each must redden (Rule 19).** The implement stage records a `mutation:` line under each:

- AC1: `Rows` drops the `$JOB` filter → SqlActivityPort's own-row leg; `Rows` sets no `Namespace` → its list leg and the browser row leg.
- AC2: `PAIRS` without `%DB_IRISSYS:READ` → SqlActivityGate's NoSys leg.
- AC3: the pre-check removed → SqlActivityGate's `ProtectCount` leg; #921 mapped to a failure → its Read leg; the cut removed → SqlActivityPort's length leg.
- AC4: `Parameters` added to `CURRENTSTATEMENTS` and the row → SqlActivityPort's Parameters leg.
- AC5: `rowTarget` removed → the browser link leg.
- AC6: `refreshes` false → the browser chip leg and SqlActivityDescriptor's shape leg.
- AC7: `Loop.Run` appends the last `tool_result` to the system prompt → source (n)'s leg, as source (a)'s does.
- AC8: the third prompt removed → SqlActivityDescriptor's shape leg.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
