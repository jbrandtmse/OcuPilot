---
title: 'Story 19.10: SQL activity'
type: 'feature'
created: '2026-10-05'
status: 'done'
baseline_revision: '24b9c705e82bb9fa1807a0f264530c3b2e82ceef'
baseline_commit: '24b9c705e82bb9fa1807a0f264530c3b2e82ceef'
review_loop_iteration: 0
followup_review_recommended: true
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

### Review Findings

Code review 2026-10-05 (full-opus; blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor).

- [x] [Review][Patch] (medium) QA's `armedIris` runs `docker` without the spec first refusing the live container, so `angular-json.test.mjs`'s DW-159 gate is red (found while verifying patches) [ui/browser/sql-activity.browser-spec.mjs:78]
- [x] [Review][Patch] (medium) The descriptor's pairs are checked against a literal, never against the port's `PAIRS`, so the side bar's verdict and the port's gate can drift [src/OcuPilot/Test/SqlActivityDescriptor.cls:101]
- [x] [Review][Patch] (medium) `Remote`'s JSON type is unpinned: the client drops the link only for `=== true`, and dropping `"boolean"` in `Rows` leaves every test green [src/OcuPilot/Test/SqlActivityPort.cls:204]
- [x] [Review][Patch] (medium) The per-namespace text verdict is only ever read with one namespace: keying it on nothing leaves every test green [src/OcuPilot/Port/SqlActivityPort.cls:242]
- [x] [Review][Patch] (low) The AC2 leg's comment and QA line blame a cached declaration. The leg reads the descriptor's screen verdict (`GET /navigation`), and the descriptor mutation reddens it once recompiled; `PAIRS` and the mirror are not on its path [ui/browser/sql-activity.browser-spec.mjs:254]
- [x] [Review][Patch] (low) The AC3 leg's title and comment blame `%Development:USE`, but the principal lacks `USER`'s database READ, so the pre-check withholds the text [ui/browser/sql-activity.browser-spec.mjs:235]
- [x] [Review][Patch] (low) The "ignoring case" legs of `TestIsRemote` cannot fail: no leg differs only in case [src/OcuPilot/Test/SqlActivityPort.cls:197]
- [x] [Review][Patch] (low) The Read and Dev legs never assert the login identity, so a failed login would read as the suite's `%All` account [src/OcuPilot/Test/SqlActivityGate.cls:133]
- [x] [Review][Patch] (low) The two copies of the navigation payload, which move with `Wire`, lack SQL activity [ui/tools/navigation-wire.test.mjs:412]
- [x] [Review][Patch] (low) The browser spec's `after` removes the principals before stopping the probe, so a throw there leaves the probe running [ui/browser/sql-activity.browser-spec.mjs:94]
- [x] [Review][Patch] (low) "It creates nothing else" is wrong: each fresh literal leaves a statement-index row and a cached query (145 such rows in `USER` on `ocupilot-a2-ci`) [src/OcuPilot/Test/SqlActivityPort.cls:9]
- [x] [Review][Patch] (low) `ACTIVITYVALUE`'s doc promises a check `InjectionChannels` does not make [src/OcuPilot/Test/InjectionSeed.cls:84]
- [x] [Review][Patch] (low) The browser spec's header says the empty state is a leg the suite's account cannot reach, and omits the principals it creates [ui/browser/sql-activity.browser-spec.mjs:3]
- [x] [Review][Patch] (low) `IsRemote` is documented "Pure", but its default argument reads the instance [src/OcuPilot/Port/SqlActivityPort.cls:95]
- [x] [Review][Defer] (low) `Routine` and `Workers` are compared only at their default values, and the child-statement `RunType` branch never runs [src/OcuPilot/Test/SqlActivityPort.cls:96] — deferred: needs a nested or parallel probe; ledgered `wontfix-accepted`

**Rejected:**

- `false`: `IsRemote` differs from the classic page's cluster-only test — the vendor's AMS writes `Server` as `$ZU(110)_":"_$g(^%SYS("SSPort"))` (`%SYS.AppMetadataStack.SQL` :142, :552), which is `LocalServer`, so no local row reads remote.
- `false`: a mapped database could make `GetSQLStatement` raise `<PROTECT>` past the pre-check — `^rINDEXSQL` resolves to the routines database in HSCUSTOM, USER, %SYS, HSLIB and HSSYS (measured).
- `false`: a remote row's hash looked up locally fails the read — an unknown hash answers `""` with OK (measured at implement).
- `false`: `TestIsRemote`'s `LocalServer` assertion cannot fail — a `LocalServer` mutation reddens it.
- `low`, spec-bound: no Server column; `Started` is local time; the note's own-statement wording; one row's fault fails the read; the pre-check resolves through `DatabaseResources`; a prompt about open transactions with no transaction column; `Routine` (`CallerName`) blank for a top-level statement.
- `low`: the own-statement matrix case has no principal-run leg (vendor behavior; needs a probe run as the principal).
- `low`: `ProtectCount` has no positive control — the event and auditing are both on (`ocupilot-a2-ci`), and the read's 500 reddens the pre-check mutation too.
- `low`: `Stop` could terminate a reused pid — only after an aborted run leaves a record and its pid is reused before a restart.
- `low`, maybe-false: the empty-state leg may flake if another process runs SQL during its one read — reopen if CI reds it on a row that is not the probe's.
- `low`: `maxRows` shapes other than `0` untested — the pattern is a one-line anchored regex.

## Spec Change Log

- 2026-10-05, lead (spec gate): the five decisions are ruled tier-1 and written into the spine (Design Paradigm, AD-7's fifth shape, AD-29 `SqlActivityPort` with the FR-80 deviation, AD-36, AD-43 roster ten, AD-61 rule 7 narrowed at origin). Two claims corrected here: SQL activity's pair set is not Processes' (Processes also requires `%Admin_Manage:USE`), and the classic page hides `CallerName`; `Routine` stays as the AC's application metadata. `DatabaseFreeSpace` stays off AD-43's roster by design (Databases' entry covers both views). DW-2093's decline is accepted; it moves to the epic's burn-down.

## Review Triage Log

### 2026-10-05 — Review pass

- verdicts: 18 findings — high 0, medium 7, low 9, false 2, maybe-false 0
- findings:
  - `[medium]` `[patch]` (verification-gap) the row fields after `StatementHash` were never compared with the vendor's columns — `TestTheProbeIsARowAndTheReaderIsNot` now starts its probe in one open transaction (`SqlActivityProbe.Start`'s new `pLevel`) and holds `StatementId`, `StatementHash`, `Routine`, `CachedQuery`, `Workers`, `TransactionLevel` and `Started` equal to the vendor's row for that pid; mutation run 1054.
  - `[medium]` `[patch]` (verification-gap) a row's `Remote` was only ever seen false — `SqlActivitySeam` arms `LocalServer`, and `TestIsRemote` reads the probe's row as remote; mutation run 1055.
  - `[medium]` `[patch]` (verification-gap) the globals database's pair in `MayReadText` was never exercised, every probe namespace having one database — the port resolves resources through a private `Resources` seam, and `TestTheTextPreCheckNeedsBothDatabases` holds each half alone and both; mutation run 1056.
  - `[medium]` `[patch]` (verification-gap) a throw from `Text` was never driven — the seam arms a throw, and `TestAVendorFaultFailsTheRead` asserts 500 `INTERNAL`, no rows, the text unsent and logged once; mutation run 1057.
  - `[low]` `[patch]` (verification-gap) `TestTheVendorSurface`'s substring check could not fail for `Parent` while `ParentType` stayed — now a whole-word `$Locate`; mutation run 1058.
  - `[low]` `[patch]` (verification-gap) AC4's screen and tool legs passed on an empty answer — each now also asserts 200 and the probe's row.
  - `[low]` `[reject]` (verification-gap) AC8's structural leg and AC2's side-bar half carry no mutation line of their own — Rule 19 asks one demonstrated mutation per AC and each AC has one; the AC1 and AC5 halves the finding also named are closed by the first two rows.
  - `[low]` `[reject]` (verification-gap) the note says a caller's own text shows, while the pre-check withholds it in a namespace whose databases the caller cannot read — both the note and the unconditional pre-check are the spec's; the case needs the caller's own statement running under an application role's database grant.
  - `[low]` `[reject]` (intent-alignment) the Pair missing row's `PORT.ACCESSDENIED` is asserted only at the port, while the screen read and the tool refuse first with the descriptor gate's `AUTH.NOPRIVILEGE` — the Boundaries place the code on the port; the outer refusal is the shared AD-8 gate naming the same pair, and the side-bar half is pinned over HTTP by `Wire` and `WireSecurityRead`.
  - `[low]` `[reject]` (intent-alignment) "Not shown" is pinned only as the column's declared `emptyKey` — the shared table renders `emptyKey` and `table-model.test.mjs` and `locks.browser-spec.mjs` pin that rendering.
  - `[medium]` `[patch]` (intent-alignment) the Nothing running row had no test and `emptyStateKey` was unasserted — `TestTheDescriptorShape` now pins `sqlActivityEmpty` (mutation run 1059); "only the reading process" cannot be arranged on a shared instance, and its mechanism is the own-row leg.
  - `[low]` `[reject]` (intent-alignment) own-statement text reads R2a while the note reads R2b — same root cause and disposition as the note row above.
  - `[false]` `[reject]` (intent-alignment) the tool's row set is not compared with the port's — screen and tool resolve through the one declared read (AD-36), `Elapsed` moves between calls so set equality is no stable assertion, and the probe row is asserted in each.
  - `[false]` `[reject]` (intent-alignment) "no statement prepared" is observed as `Rows` calls, not `%Prepare` calls — `Rows` is the port's only prepare site, so zero calls is zero prepares.
  - `[medium]` `[patch]` (intent-alignment) the vendor fault's text was never seen reaching the log, and a throw was never driven — grouped with the throw row: the seam records each logged status's text, and both fault legs assert it; mutation run 1057.
  - `[medium]` `[patch]` (intent-alignment) a remote row's `Remote` and text pre-check are unexercised — the `Remote` half is grouped with the remote row above (run 1055); the text half is refuted on `ocupilot-a2-ci`: `GetSQLStatement` answers `""` with OK for a hash an existing namespace does not hold, and a namespace that does not resolve never reaches the call.
  - `[low]` `[patch]` (intent-alignment) the "empty resource, no call" path was untested — grouped with the split-database row: its last leg arms an unresolved routines resource and reads no text.
  - `[low]` `[reject]` (intent-alignment) another account's statement is read only at the port; the screen, tool and browser legs read as the suite's account — the declared read adds nothing account-specific beyond the port's gate and text rule, which `SqlActivityGate` pins with real principals.

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
  - mutation: the `$JOB` filter removed from `Rows` → `SqlActivityPort.TestTheProbeIsARowAndTheReaderIsNot` red on the own-row leg (run 1028).
  - mutation: `Rows` sets no `Namespace` → the same method red on its namespace, screen-read and tool legs (run 1029); the browser row leg red (`(none)` where `USER` was expected).
  - mutation: `Routine` read from the `CachedQuery` column → the same method red on its vendor-column leg (run 1054).
- AC2: `PAIRS` without `%DB_IRISSYS:READ` → SqlActivityGate's NoSys leg.
  - mutation: `PAIRS` = `%Admin_Operate:USE` → `SqlActivityGate.TestEachMissingPairIsRefusedByName` red on OcuP1910NoSys's refusal (run 1030).
  - mutation: the port's `EvaluateRequired` block removed → `PortGate.TestEveryPortEvaluatesItsDeclaredGate` red on the SqlActivityPort leg (run 1040); a `Rows` call placed before the gate → `SqlActivityPort.TestTheGateRefusesBeforeAnyStatement` red on the prepared count (run 1039).
  - mutation (code review): `PAIRS` = `%Admin_Operate:USE` → `SqlActivityDescriptor.TestTheDescriptorShape` red on its pairs-equal-`PAIRS` leg (run 1537).
- AC3: the pre-check removed → SqlActivityGate's `ProtectCount` leg; #921 mapped to a failure → its Read leg; the cut removed → SqlActivityPort's length leg.
  - mutation: `StatementText`'s `If 'pAllowed(pNamespace)` line removed → `SqlActivityGate.TestTheExactPairsListWithTheTextWithheld` red: the read answers 500 and the Protect count moves (run 1031).
  - mutation: the #921 line removed from `StatementText` → `SqlActivityGate.TestTheTextNeedsDevelopmentAndTheDatabase` red on the Read principal (run 1032) and `SqlActivityPort.TestAVendorFaultFailsTheRead` red on its withheld leg (run 1033).
  - mutation: the cut removed from `Shape` → `SqlActivityPort.TestTheTextIsCutAbove1024` red on both length legs (run 1034).
  - mutation: the globals database's pair dropped from `MayReadText` → `SqlActivityPort.TestTheTextPreCheckNeedsBothDatabases` red on its routines-only leg (run 1056); a throw from `Text` answered as `""` → `TestAVendorFaultFailsTheRead` red on its throw legs (run 1057).
  - mutation (code review): `StatementText`'s verdict keyed on nothing in place of `pNamespace` → `SqlActivityPort.TestTheTextVerdictIsPerNamespace` red on its unreadable-namespace leg (run 1536).
- AC4: `Parameters` added to `CURRENTSTATEMENTS` and the row → SqlActivityPort's Parameters leg.
  - mutation: `Parameters` selected and set on the row → `SqlActivityPort.TestTheBoundValueIsInNoAnswer` and `TestTheVendorSurface` red (run 1035).
- AC5: `rowTarget` removed → the browser link leg.
  - mutation: `rowTarget` removed, the mirror regenerated, rebuilt and deployed → the browser link leg red (no link to click).
  - mutation: `Rows` sets every row's `Remote` to 0 → `SqlActivityPort.TestIsRemote` red on its row leg, a probe read with the seam's `LocalServer` naming another server (run 1055).
  - mutation (code review): `Remote` set without its `boolean` type → `TestIsRemote` and `TestTheProbeIsARowAndTheReaderIsNot` red on their JSON-type legs; `IsRemote` without `$ZConvert` → `TestIsRemote` red on its case-only leg (both run 1536).
- AC6: `refreshes` false → the browser chip leg and SqlActivityDescriptor's shape leg.
  - mutation: `refreshes` false with no rates → `SqlActivityDescriptor.TestTheDescriptorShape` red on its two refresh legs (run 1043); rebuilt and deployed, the browser chip leg red (no `.ocu-command-bar-refresh`).
- AC7: `Loop.Run` appends the last `tool_result` to the system prompt → source (n)'s leg, as source (a)'s does.
  - mutation: `Loop.Run` appends the last message's blocks to the system prompt → `InjectionChannels` red in all fifteen methods, `TestRunningStatementLiteral` on invariant 1, the obeyed stub, the proposal and both navigation legs (run 1046).
- AC8: the third prompt removed → SqlActivityDescriptor's shape leg.
  - mutation: the third prompt removed → `SqlActivityDescriptor.TestTheDescriptorShape` red (run 1044).
- The source kind's refusals and the remaining port legs:
  - mutation: the sqlactivity arm removed from `Registry.ReadProblem` → `SqlActivityDescriptor.TestTheSqlActivitySourceRefusals` red on the endpoint, type and four key cases (run 1041); the arm removed from `screen-mirror.mjs`'s `readProblem` → the Story 19.10 mirror test red.
  - mutation: `ASC` order → `SqlActivityPort.TestRowsComeSlowestFirstAndCutAtTheCap` red on both order legs (run 1036); the cut removed from `Rows` → red on the cap leg (run 1037); `IsRemote` answering 0 → `TestIsRemote` red (run 1038).
  - mutation: the `CASE` tests `ParentType` in place of `Parent` → `SqlActivityPort.TestTheVendorSurface` red on its whole-word leg (run 1058); the descriptor's `emptyStateKey` set to `sqlActivityLabel` → `SqlActivityDescriptor.TestTheDescriptorShape` red (run 1059), the Nothing running row's empty state.

**QA pass.** (QA) `ui/browser/sql-activity.browser-spec.mjs` gains three legs the suite's `_SYSTEM` account could not reach, run as throwaway principals `OcuP1910BrExact` and `OcuP1910BrNoSys` (created and removed through `SqlActivityProbe`):

- AC3 text withheld: the probe is a row whose Statement cell reads "Not shown", its literal and bound value on no part of the page.
  - mutation: the generated mirror's Statement `emptyKey` set to `sqlActivityLabel`, rebuilt and deployed → the AC3 leg red.
- AC2 refusal: the screen shows "You need %DB_IRISSYS:READ to open SQL activity." and no row.
  - mutation: `%DB_IRISSYS:R` granted to the NoSys principal → the AC2 leg red (sentence wait times out).
  - mutation (code review): `%DB_IRISSYS:READ` dropped from `SqlActivityList.cls`'s `privileges`, recompiled on `ocupilot-a2-ci` → the AC2 leg red (sentence wait timed out). The leg reads the descriptor's verdict from `GET /navigation`; the page never mounts, so the port's `PAIRS` and the mirror are not on its path.
- Nothing running: with the probe stopped the empty-state sentence shows, no row.
  - mutation: the mirror's `emptyStateKey` set to `sqlActivityLabel`, rebuilt and deployed → the empty-state leg red.
- Not pinned in a browser: a remote row's text Process ID cell (no second instance); `SqlActivityPort.TestIsRemote` pins it.

## Auto Run Result

Status: done
Blocking condition: none

**Summary.** OS management gains SQL activity (`os-management/sql-activity`, position 20). `Port/SqlActivityPort` requires `%Admin_Operate:USE` and `%DB_IRISSYS:READ` (403 `PORT.ACCESSDENIED` with `failedPair`), prepares `CURRENTSTATEMENTS` in the caller's namespace, leaves out its own `$JOB`, never selects `Parameters`, and reads a statement's text through `GetSQLStatement` only for a caller holding READ on the namespace's routines and globals databases (#921 answers `""`; any other fault or a throw is 500 `INTERNAL`, logged). The `sqlactivity` source kind joins `Read`, `Registry` and the mirror ("eleven sources"), `sql-statement` joins the entity types, the agent gets `osmgmt.sqlactivity.read`, and injection source (n) is planted and read.

**Files.** New: `Port/SqlActivityPort.cls`; `Screen/Descriptor/SqlActivityList.cls`; tests `SqlActivityDescriptor`, `SqlActivityPort`, `SqlActivityGate`, `SqlActivityGateSeam`, `SqlActivitySeam` (the port test's seams) and the fixture `SqlActivityProbe`; `ui/browser/sql-activity.browser-spec.mjs`. Changed: `Screen/Read.cls`, `Screen/Registry.cls`, `Kernel/EntityType.cls`, `InjectionSeed`, `InjectionChannels`, `ui/tools/screen-mirror.mjs`, `screens.generated.ts`, `strings.ts`, EXPERIENCE.md (:92, :164, the row at :603, :889; one citation moved), `scripts/ci-throwaway.sh` (`# classes: SqlActivityGate, SqlActivityProbe`), `angular.json` and `angular-json.test.mjs`.

**Rosters updated outside the spec's file list:** `ReadTool` (276 tools and the name), `SurfaceCoverage`, `Descriptor` (`ReadShapes` row, 56 entity types), `PortGate` (roster and denial leg), `AdminPairCorpus` and `DocDbDescriptor` ("eleven sources"), `Navigation` (46 screens), `Wire` (strip step), `WireSecurityRead` (three rosters), `WireAreaAnyScreen` (the `%Operator` holder's OS management roster, found red by the sweep), `screen-mirror.test.mjs` (port list, per-source test, read-note roster), `navigation.test.mjs` (two rosters), `src/app/shell/area-verdict.spec.ts` (OS management's side-bar roster, found red by `npm test`), `license-usage.browser-spec.mjs` (count wording). `DraftRegistry`, `DeveloperFloor` and `ToolRoundTrip` needed no edit.

**Review.** Two layers ran (verification-gap, intent-alignment; blind-hunter and edge-case-hunter are disabled in `_bmad/custom/bmad-build-auto.toml`): 18 findings, 0 high, 7 medium, 9 low, 2 false. Patched: 5 medium entries (vendor-column leg with a probe in one open transaction; a remote row through the seam's `LocalServer`; the split-database pre-check through a new private `Resources` seam; a throw from `Text` and the logged vendor text; the Nothing running empty state) and 2 low (whole-word column check; AC4's screen and tool legs now require the probe row). Rejected: 7 low and 2 false, each with its reason in the Review Triage Log. Deferred: none. Follow-up review recommended: true (5 medium entries patched); the unverified risk is that a row's `Remote` path and the split-database pre-check are pinned through seams, never against a second instance's rows or a namespace whose routines and globals databases differ.

**Verification** (all on `ocupilot-a2-ci`, the current `src/` loaded first):

- `check-objectscript.py` 0 problems; its harness 146 OK; `lint-docs.sh` 0 issues; `npm run test:tools` 1,826 pass; `npm test` 1,826 tools and 2,483 component tests pass.
- Bundle 2,942,499 B initial (2943kB warning, `main-576T5BQA.js`); Fixed strings 2,659 literals of the 2,700 cap.
- Browser, on that bundle deployed: `sql-activity` 4 of 4, `a11y-structural-invariants` 12 of 12.
- Story classes after the review patches: SqlActivityPort 1052, SqlActivityDescriptor 1053; review mutations 1054-1059, each red as recorded in `## Verification`, applied to the throwaway's copy only and the tree confirmed identical after each.
- Full ObjectScript sweep (once): 472 classes, 3,826 tests, 1 failed (`WireAreaAnyScreen`, its roster patched and re-run green, run 1532), 0 probe leftovers. Residue, as known: the five encryption classes (`EncryptionKeyFileRead`, `EncryptionKeyFileWrite`, `EncryptionKeyGate`, `EncryptionKeyWrite`, `EncryptionWriteGate`) ran nothing because the throwaway does not arm `OCUPILOT_ALLOW_ENCRYPTION_CONFIG`. The instance offered 472 classes against the checkout's 470. Story and roster runs in the sweep: SqlActivityDescriptor 1416, SqlActivityGate 1417, SqlActivityPort 1418, InjectionChannels 1223, PortGate 1342, ReadTool 1378, Navigation 1299, Wire 1523, WireSecurityRead 1526, Descriptor 1146, DeveloperFloor 1147, DraftRegistry 1162, DocDbDescriptor 1156, SurfaceCoverage 1443, ToolRoundTrip 1470.
- After the runs no `OcuP1910*` user or role, probe job or probe registry node remains.

**Residual risks.** `SqlActivityGate` counts `Protect` audit rows instance-wide, so another process's `<PROTECT>` during its read would redden it.
