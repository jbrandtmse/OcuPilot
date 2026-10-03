---
title: 'Story 19.6: The query console and its DML and DDL guard'
type: 'feature'
created: '2026-10-03'
status: 'done'
baseline_revision: '3858df8f6c5587f22660dd42ba618b7f1dd7f2b2'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-19-context.md'
warnings: ['oversized']
deferred:
  - summary: >-
      Vendor candidate: a CREATE TABLE text a privileged account has already prepared in a namespace is
      answered from its cached query without the next principal's privilege check, so a principal with no
      DDL privilege creates the table through %Prepare(text, 1); DW-1964's CREATE TABLE leg uses a fresh name per run.
    evidence: |-
      ocupilot-a2-ci 2026-10-03: principal with %Development:USE, %DB_USER:RW, no grants; CREATE TABLE OcuProbe196.Made (X INTEGER)
      ran after _SYSTEM had prepared the same text, and answered -99 under a never-prepared name; DROP TABLE,
      TRUNCATE, SELECT and UPDATE stayed -99. The classic SQL page prepares the same way (inference).
    location: 'src/OcuPilot/Port/SqlPort.cls (Prepared, Executed)'
    severity: 'medium'
  - summary: >-
      An INSERT through a view over OcuPilot's tables, by a principal granted privileges on the view but not
      on its base tables, is not refused PROHIBITED.OCUPILOTSQL: the statement index records only the view for
      an INSERT, and INFORMATION_SCHEMA.VIEW_TABLE_USAGE hides the base table from that principal.
    evidence: |-
      ocupilot-a2-ci 2026-10-03: principal with %Development:USE, %DB_HSCUSTOM:RW and SELECT, INSERT, DELETE on a view
      over OcuPilot_Kernel_State.Proposal; Classify recorded only the view for INSERT, the base table for DELETE and
      SELECT. As %All the view expansion finds it. Whether the vendor then runs that INSERT is unmeasured.
    location: 'src/OcuPilot/Port/SqlPort.cls (Prepared)'
    severity: 'medium'
  - summary: >-
      Whether an IRIS SQL form other than IDENTIFY BY or IDENTIFIED BY sets a password, which the pre-prepare text
      refusal would let reach the statement index (DW-1982's root cause).
    evidence: |-
      Settle by listing the IRIS SQL statements that accept a password. A name probe of INFORMATION_SCHEMA.ROUTINES in
      HSCUSTOM found no password-setting routine (inference: a name probe does not cover the population).
    location: 'src/OcuPilot/Port/SqlPort.cls (PASSWORDPATTERN)'
    severity: 'medium (unverified)'
---

<intent-contract>

## Intent

**Problem:** System Explorer cannot run a SQL statement, so a developer still opens the classic Execute Query page. Atelier's `action/query` would run one, but it prepares with SQL privilege checks off (DW-1963), so it cannot carry a caller's statement.

**Approach:** A new listed screen, SQL query, runs one statement in the chosen namespace. A new port prepares it in process, as the signed-in user, with privilege checks on. The instance's own prepared statement type drives a guard. A query runs at once with bound values, a Max rows cap and an Explain plan. DML, DDL, a CALL or an unclassified statement runs only after a confirmation dialog, through an unadvertised write tool (AD-53) that Story 19.11 will advertise to the agent. Statements that change the server process, administer accounts, roles or databases, name server files, set a password, or touch OcuPilot's own tables are refused by name.

## Boundaries & Constraints

**Always:**

- `Port/SqlPort` gates first: `AtelierPort.PAIRS` and `AtelierPort.NamespacePairs(ns)` through `EvaluateRequired`, before any prepare (AD-29, AD-61 rule 1). The two routes also evaluate the screen's own gate, which carries the classic page's custom resource (AD-44).
- Every statement is prepared with `%SQL.Statement.%Prepare(text, 1)`, with `%SelectMode` 1, in the target namespace (explicit save and restore, AD-16), in the request's own process, with no escalated frame (AD-8, AD-9). The switched region calls only vendor classes, and the restore comes first in every `Catch`.
- The kind comes from `%Metadata.statementType` through the closed table in Design Notes › Guard. A type number the table does not name is `other`, and needs confirmation.
- Values are bound positionally through `%Execute(args...)`, never spliced.
- Inputs:
  - a statement is 1 to 100,000 characters;
  - at most 100 values, each a string of at most 32,767 characters;
  - Max rows is 1 to 1,000 (default 1,000).
- Answers:
  - a cell is cut at 1,000 characters, ending in U+2026;
  - an answer is cut at 1,000,000 characters, by whole rows from the end;
  - `truncated` reports either cut.
- Queries and DML run under `$System.Alarm` set to `TestCall.BoundSeconds(TestCall.GatewaySeconds())`. Past it, the answer is `stopped`. DDL and CALL run without it (named limit).
- If a run leaves `$TLevel` above where it started, the port rolls back to that level and answers `error`.
- A mutating kind runs only through the screen action `run` of `explorer.sqlquery.run`. The tool is `ADVERTISED` 0, and its baseline key ships `false`. Its target is `(class, <ns>, sql)`.
- The self-protection predicate lives once, in `Kernel/Proposal/Prohibited.cls`. The run route, the plan route and the write path (inside AD-34's lock) all call it.

**Never:**

- Caller SQL through `AtelierPort` or `action/query`. Never `%Prepare(…, 0)`, `%ExecDirectNoPriv`, or a value concatenated into a statement (DW-1964, AD-21).
- A statement's text, values, rows, SQL error text or plan anywhere but this screen's answer. That excludes log lines, ledger rows, audit payloads, screen context, tool results and stored state (AD-39 exception draft).
- A classifier written as text rules. Only two text rules exist, both fail-closed: the password refusal before prepare, and the OcuPilot backstop.
- A run-in-background option (split to 19.15, Design Notes), an advertised tool, an enabled key, a third-party library or SQL parser, an edit to `Api/Error.cls`, the `work` routes, `docnames`' `filter`, or `POST modified`.
- A state change decided in the browser. The client opens the dialog only when the server answers `confirm`, and the write path classifies the statement again (AD-11).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Query | `SELECT Name FROM OcuProbe196.Granted WHERE Num > ?`, values `["0"]`, Max rows 1 | `rows`: its columns, one row, `truncated` true | Cap notice |
| Values asked | a statement with two `?` and no values, or the wrong number | `parameters` with count 2; nothing runs | None |
| Bound, not spliced | `WHERE Name = ?` with value `' OR ''='` | `rows` with no row | None |
| Mutating | `UPDATE OcuProbe196.Granted SET Num = 3` | run: `confirm {kind dml, tables}`, table unchanged; confirmed action: `done`, rowCount | None |
| Disguised | `/* SELECT */ DELETE …`, `-- c` line then DELETE | kind `dml` (type 4) → `confirm` | None |
| Two statements | `SELECT …; DELETE …` | `error`, SQLCODE -25, nothing runs | Shown as text |
| Session | START TRANSACTION, COMMIT, SAVEPOINT, SET OPTION, LOCK TABLE, CANCEL QUERY | 422 `EXPLORER.SQL.SESSION` | Banner |
| Administration | GRANT, REVOKE, CREATE ROLE, DROP USER, DROP DATABASE | 422 `EXPLORER.SQL.ADMINISTRATION` | Banner |
| Server files | LOAD DATA, CREATE SERVER, CREATE FOREIGN TABLE, THROUGH | 422 `EXPLORER.SQL.SERVERFILES` | Banner |
| Password | `CREATE USER x IDENTIFY BY 'p'` | 422 `EXPLORER.SQL.PASSWORD` before any prepare; the statement index holds no row for it | Banner |
| OcuPilot's own | as `%All` in the install namespace: `SELECT ID FROM OcuPilot_Kernel_State.Proposal`, a view over it, `DROP TABLE OcuPilot_Kernel_State.Proposal` | 403 `PROHIBITED.OCUPILOTSQL` on run, on plan and on the write path | Banner |
| Unprivileged (DW-1964) | a principal granted SELECT on `Granted` alone: SELECT, UPDATE, TRUNCATE, CREATE TABLE, CALL on `Hidden` | run: `error` SQLCODE -99; write path: `error` -99; nothing changes | Shown as text |
| Read on the write path | a query sent to the `run` action | 422 `EXPLORER.SQL.READS` | Banner |
| Long | a query or DML past the bound | `stopped`; a stopped DML leaves the table unchanged | Status line |
| Plan | Explain an UPDATE; Explain CREATE TABLE | `plan` text, table unchanged; `noplan` | None |
| Bad input | statement empty or too long; values not an array of strings, more than 100, or one too long; Max rows outside 1–1,000 | 400 `EXPLORER.SQL.INPUT`, before any prepare | Banner |
| Gate | no `%Development:USE`, or no READ on the namespace's code database | 403 `AUTH.NOPRIVILEGE` naming the pair, before any prepare | Banner |

</intent-contract>

## Code Map

- **Port to mirror:** `src/OcuPilot/Port/AtelierPort.cls`.
  - `Invoke` :830-966. It gates through `$ClassMethod(..GateClass(),"EvaluateRequired",…)` at :840-861, then `Deny`, `Refuse` :3115 and `NAMESPACEPATTERN`.
  - `NamespacePairs` :725 (public, reused) and `PAIRS` :75.
  - `SnippetForm` :3136, `Snippet` :3158-3204 and `Literal` :3208 (AD-59).
  - `SqlPort` copies this signature and gate order. It names no `%Api.Atelier.*` class.
- **Tool exemplars:** `src/OcuPilot/Screen/Tool/`.
  - `Write.cls` holds the parameters :52-217 and `ScreenActionValueNames` :644.
  - `ExplorerSave.cls` is the unadvertised exemplar, read in full: `ADVERTISED` 0, `SCREENVALUES`, `ScreenActionDelta`, `PortQuery`, `StateDiff`, `WriteOutput`.
  - `ExplorerImport.cls` :32, :60 shows a literal target.
  - Do not extend `ExplorerWrite.cls`: its routines-database WRITE pair (:102-114) is wrong for SQL.
- **Screen action route:** `src/OcuPilot/Api/ScreenAction.cls`.
  - `Values` :480-530 requires every declared value, each a non-empty string. So `parameters` travels as JSON array text and `maxRows` as digits.
  - Other anchors: `ToolFor` :535, the `Run` order :220-386, and `output` :377-380.
- **Operation:** `src/OcuPilot/Kernel/Proposal/Operation.cls`.
  - `ReadTarget` :316-321 calls the declared port's `Invoke(endpoint, READTYPE, .query)`.
  - `OutputOf` :189.
- **Prohibited set:** `src/OcuPilot/Kernel/Proposal/Prohibited.cls`.
  - `Prohibits` :1024, with the class/routine arm at :1064-1068 that the new arm sits beside.
  - Pattern for the new code: `OCUPILOTCODE`/`REASON` :460-465, `Codes()` :696, `ReasonFor` :732.
  - Helpers: `WriteTypeOf` :1789 and `OwnNameStems` :2371.
- **Route handler pattern:** `src/OcuPilot/Area/Security/LdapRules.cls:692-848`.
  - `Gate` with the descriptor plus the classic page, through `Kernel.Denial.Envelope`.
  - `Kernel.Utils.ReadRequestBody`, `Api.Response.JSON` and `Api.Error.Render`.
- **Router:** `src/OcuPilot/Api/Router.cls`. The UrlMap tail is :224, thin wrappers follow :1638-1643, and the ordering invariants are at :56-70. A route sharing no prefix may be appended.
- **Bound:** `src/OcuPilot/Kernel/Provider/TestCall.cls`, `BoundSeconds` :88 and `GatewaySeconds` :61.
- **Error codes:** `src/OcuPilot/Api/AtelierError.cls:14-85` (code/reason parameter pairs).
- **Governance:** `src/OcuPilot/Kernel/Governance/Baseline.cls:150-159`.
- **Descriptors:**
  - `Screen/Descriptor/ExplorerCompare.cls`: a listed `form-page` with no read, `id.kind none` and a classic page.
  - `AuditingConfig.cls:60`: a form page that declares `rowActions`.
- **Target id:** `src/OcuPilot/Kernel/EntityRef.cls:131-136`. The `documentset` rule keeps a comma-free `sql` exactly.
- **Client:**
  - `ui/src/app/shell/screen-outlet.ts:135-210`, `DESCRIPTOR_PAGES`.
  - `areas/system-explorer/source-editor.page.ts` with `.store.ts:276-285`: `sendFor` plus `lastOutput()`.
  - `code-search.page.ts:114-161`: a `role="status"` line and a page-owned `role="table"` grid.
  - `macro-lookup.store.ts:1-34,161-174`: a framework-free store, its per-`ScreenStore` `WeakMap`, and `requestJson`'s refusal capture.
  - `shell/warning-dialog.ts:19-113`, `shell/screen-action-handler.ts:1125-1205` and `core/api.ts:328`.
  - `_components.scss:4930-4947` (code surface) and :7474-7503 (status line and grid rows).
- **Tests to follow:**
  - `Test/AtelierPortDenial.cls` (`EnsurePrincipal`, `ProbeAs`) and `Test/ExplorerSqlProbe.cls` (probe-schema lifecycle).
  - `ui/browser/system-explorer-sql.browser-spec.mjs`, with `turnprobe-spec.mjs:52,67` (`runIris`) and `panel-spec.mjs:62` (`signedInAt`).
  - `areas/system-explorer/source-editor.page.spec.ts` (vitest and jsdom).
- **Vendor (read, never edited):**
  - `irislib/%SQL/Statement.cls`: `%Prepare(text, checkPriv=1, noAudit=0)` :519, `%Execute(%parm...)` :802, `%GetImplementationDetails` :1052.
  - `irislib/%SQL/StatementMetadata.cls`: `statementType` :23-107, `parameters` :142.
  - `irislib/%SQL/StatementResult.cls`: `%SQLCODE` :222, `%Message` :194, `%ROWCOUNT` :204, `%Next` :277, `%NextResult` :324.
  - `irislib/%SQL/IResultSet.cls:69`, `%StatementIndexHash`.
  - `irislib/INFORMATION/SCHEMA/STATEMENTLOCATIONS.cls` and `STATEMENTRELATIONS.cls`.
  - `irislib/%SYSTEM/SQL.cls`: `Explain` :4312.
  - `irislib/%SYSTEM/SQL/Schema.cls:132`, `Default()`.
  - `irissys/%CSP/UI/Portal/SQL/Home.cls:2660-2930`: the classic Execute, background run, cancel and `$$$SMPAuditExecute`.

## Tasks & Acceptance

**Execution:**

- [x] **Task 0** (`ocupilot-a2-ci`, before code; probe schema `OcuProbe196`, a purpose-built principal, each removed after). Record the results in Design Notes.
  - (a) Enable `%System/%SQL/DynamicStatementDML` and `DynamicStatementDDL`. Run one DML and one DDL through a probe that calls `%Prepare(text,1)`/`%Execute`, read the audit rows, then restore both events' prior state.
  - (b) Measure what `TestCall.GatewaySeconds()` answers for a `%Developer` principal.
- [x] `src/OcuPilot/Port/SqlPort.cls` (new): the port.
  - **Gate:** as above.
  - **Classify**, in the switched region. It returns:
    - `{Namespace, Kind, StatementType, Tables, Parameters, Columns}`, or `{error: {sqlcode, message}}`;
    - `Parameters` counts the `?` positions that take a value (every `columnType` but 4 and 5), and `Run` leaves the output positions empty;
    - `Tables` comes from `INFORMATION_SCHEMA.STATEMENT_RELATIONS`, keyed by the cached query's `%StatementIndexHash`, else by `STATEMENT_LOCATIONS` `<implementation class>.1`.
  - **Refusals before prepare:** input bounds, and `(?i)\bIDENTIF(Y|IED)\b`.
  - **Refusals after classify:** the three refused groups.
  - **`Run`:** for a query, cap+1 fetch, cell and total cuts. For any other kind, `%ROWCOUNT`, and for a CALL its first result set, bounded alike. Then the alarm, the `$TLevel` rule, and outcomes `rows | done | error | stopped`. A prepare or execute error is the `error` outcome, never a fault. So the write path answers it as a compile answers its errors, in `output`, and a failed statement changes nothing.
  - **`Plan`:** `$SYSTEM.SQL.Explain(text, {"silent":1}, , .plan)` for `query` and `dml` kinds, else `noplan`.
  - **`Invoke`:** endpoint `Sql`, read type `GUARD` (Classify plus the declared values), write type `RUN` (refuses the `query` kind `EXPLORER.SQL.READS`).
  - **`SnippetForm`/`Snippet`:** an ObjectScript prepare-and-execute with literals.
  - **Test seams:** `GateClass()` and `BoundSeconds()`.
- [x] `src/OcuPilot/Area/Explorer/SqlConsole.cls` (new): `HandleRun` and `HandlePlan`. Each does the screen gate, reads the body, calls the port, calls `Prohibited.SqlStatement`, then answers. `confirm` comes before any execution for a mutating kind, and `parameters` when the count differs.
- [x] `src/OcuPilot/Api/Router.cls`: add-only. `POST /explorer/sql/run` and `POST /explorer/sql/plan` at the UrlMap tail, with two thin wrappers at the class end.
- [x] `src/OcuPilot/Screen/Descriptor/ExplorerSqlQuery.cls` (new).
  - Route `system-explorer/sql-query`, side bar 10, `form-page`, no read.
  - `rowActions [{id: run}]`, privileges `[%Development:USE]`, entity `class`, scope `namespace`, `id.kind none`.
  - Context fields `[]`, `classicPage` `%CSP.UI.Portal.SQL.Home`.
  - Three prompts in group Code, aliases, `toolIdentifier` `explorer.sqlquery`.
- [x] `src/OcuPilot/Screen/Tool/ExplorerSqlRun.cls` (new). Extends `Write`:
  - `PORTCLASS` SqlPort, `ADVERTISED` 0, `SCREENACTIONS` run, `SCREENVALUES` `run=statement:parameters:maxRows`;
  - `READTYPE` GUARD, `WRITETYPE` RUN, `SENDSBODY` 0, `DESTRUCTIVE` 1, `CHANGEACTION` updated;
  - `PRECONDITIONFIELD` Kind, `FINGERPRINTSUBJECT` `Namespace,Kind,StatementType,Tables,statement,parameters`;
  - `InputSchema`: `statement`, `parameters`, `maxRows` plus the three rationale fields;
  - `ScreenActionDelta`: parses and bounds the three values, refusing other spellings (AD-56 ii);
  - `PortQuery`, `StateDiff` (rows Kind and Tables), and `WriteOutput` (the run answer, screen only).
- [x] `src/OcuPilot/Kernel/Proposal/Prohibited.cls`:
  - `OCUPILOTSQL` with its reason;
  - `SqlStatement(pText, pTables, pRecordsTables, Output pProhibits, Output pCode)` (Design Notes › Self-protection);
  - in `Prohibits`, the class branch reads the payload's guard fields when `WriteTypeOf` is `RUN`;
  - `Codes()` and `ReasonFor`.
- [x] `src/OcuPilot/Api/AtelierError.cls`: add-only. `EXPLORER.SQL.INPUT`, `.SESSION`, `.ADMINISTRATION`, `.SERVERFILES`, `.PASSWORD`, `.READS` and `.PARAMETERS`, with the reasons in Design Notes › Strings.
- [x] `src/OcuPilot/Kernel/Governance/Baseline.cls`: one line, `"explorer.sqlquery.run": false`.
- [x] `ui/src/app/areas/system-explorer/sql-query.page.ts` and `sql-query.store.ts` (new):
  - a statement textarea on the code surface, Max rows, Run and Explain plan;
  - value fields after a `parameters` answer, cleared when the text changes;
  - `app-warning-dialog` on `confirm`, which on Proceed calls `sendFor(descriptor, 'run', 'sql', {statement, parameters, maxRows})`;
  - a `role="status"` line, a page-owned `role="table"` grid of text cells, the error as text, and the plan in a `<pre>`;
  - refusals as `role="alert"`, and state per `ScreenStore`.
- [x] `ui/src/app/shell/screen-outlet.ts`: add-only import and `DESCRIPTOR_PAGES` entry. Regenerate `ui/src/app/core/screens.generated.ts`.
- [x] `ui/src/app/core/strings.ts`: keys at the end, each annotated `/** EXPERIENCE.md:597 */`. `ui/src/styles/_components.scss`: add-only console rules on tokens.
- [x] EXPERIENCE.md:
  - :159 in place: append `· SQL query`.
  - :173 in place: add "run a SQL statement that changes data, the schema or calls a procedure (SQL query, Story 19.6)" to the warnings list.
  - A Fixed-strings row after :596.
- [x] Tests (ObjectScript, new): `Test/SqlPort.cls`, `Test/SqlPortLive.cls` with `Test/SqlConsoleProbe.cls`, `Test/SqlConsoleRoutes.cls` (HTTP) and `Test/SqlConsoleWrite.cls` (the screen action). Together they cover:
  - every matrix row;
  - the kind table over the numbers 1–80, 99 and an unknown 81;
  - a probe procedure that leaves `$TLevel` raised, rolled back to its start;
  - a source pin that `SqlPort` names no `%Api.Atelier` class and calls no `AtelierPort.Invoke`.
- [x] Rosters: as listed in Design Notes › Rosters.
- [x] Client tests: `sql-query.page.spec.ts` (new), the tools tests the screen trips, and `ui/browser/system-explorer-sql-query.browser-spec.mjs` (new).
- [x] `ui/angular.json` and `ui/tools/angular-json.test.mjs`: re-base `maximumWarning` to the measured build. Stop and ask above 3,800 kB.

**Acceptance Criteria:**

- **AC1:** Given probe tables in USER, when a person runs a SELECT with `?` values and a Max rows, then the instance's columns and rows show, the values are bound as values, at most Max rows show with the cut announced, and a statement whose `?` count differs from the values given asks for exactly that many values.
- **AC2:** Given a DML, DDL, CALL or unclassified statement, when Run is pressed, then nothing runs until the person confirms a dialog naming its kind and tables. The kind is the instance's prepared statement type, so a comment or a leading `/* SELECT */` cannot change it, and text holding two statements is refused by the instance.
- **AC3:** Given a session, administration, server-file or password statement, when it is run or explained, then it is refused by name before running, and a password statement is refused before any prepare.
- **AC4:** Given a `%All` caller in OcuPilot's install namespace, when a statement reads or changes OcuPilot's own tables or code, then it is refused `PROHIBITED.OCUPILOTSQL` on the run route, the plan route and the write path. This covers a direct reference, a view over its tables, and DDL naming them.
- **AC5:** Given Explain plan, when it is pressed, then the instance's plan shows without executing, an unprivileged table is refused as a run is, and a DDL or CALL shows that it has no plan.
- **AC6:** Given a query or DML that runs past the bound, when it is run, then it is stopped and reported, and a stopped DML leaves its table unchanged.
- **AC7:** Given a confirmed run, when it completes, then:
  - it goes through `explorer.sqlquery.run`, which the provider tool list, the dispatch lookup and screen context's `tools` never carry;
  - no ledger row or OcuPilot marker is written;
  - the console's text, rows, SQL errors and plan never reach screen context, a tool result, the ledger or a log line.
- **AC8:** Given classic parity (AD-44, Story 19.12), when the descriptor is read, then it declares `%CSP.UI.Portal.SQL.Home`. A custom resource on that page gates the screen and both routes, and a `%Developer` opens SQL query in USER and is refused by name where it cannot read the code database.
- **AC9 (Integration, Rule 1):** Given the console in USER on the real instance, when the person confirms `CREATE TABLE OcuProbe196.Made (X INTEGER)`, then SQL tables (Story 19.5) lists `OcuProbe196.Made` and its Fields tab reads `X`.
- **DW-1964:** Given a principal with `%Development:USE` and `%DB_USER:RW` granted SELECT on one probe table only, when it runs SELECT, UPDATE, TRUNCATE, CREATE TABLE and CALL against the other through the console's run route and its write path, then each answers SQLCODE -99 and the table is unchanged. No console path calls `action/query` (the `SqlPort` source pin).

## Spec Change Log

- 2026-10-03, lead (spec gate, by=merge_gate): the split is approved: Story 19.15 (`19-15-the-query-console-runs-a-query-in-the-background`, right after 19.6) takes the run-in-background option; this spec's scope stands. The design is approved as planned; the spine carries the drafts (AD-61's named case for `Port/SqlPort` with the alarm-rollback and `Explain` measurements, AD-10, AD-21, AD-36, AD-39, AD-53, AD-51, AD-44, AD-13, AD-8). The plan's `deferred:` vendor item is filed as DW-1982 (decision-pending). Contended edits approved: EXPERIENCE.md :159 in place; :173 hand-merged by whichever of 19.6 and Epic 18's story lands second, keeping both; `angular.json` under the re-measure rule.

## Review Triage Log

### 2026-10-03 — Review pass

- verdicts: 31 findings — high 2, medium 6, low 17, false 5, maybe-false 1
- findings:
  - `[medium]` `[patch]` verification-gap: a custom resource on the classic SQL page is never shown to gate the run and plan routes (AC8) — `ClassicPageGate.TestAnAssignedPageGatesTheSqlConsole` added (both routes and the confirmed run, lacking and holding principals); mutations runs 3892, 3893.
  - `[medium]` `[patch]` verification-gap: the value count before the confirmation is untested for a statement that changes something — `SqlConsoleRoutes` legs for an UPDATE with a `?`, without and with its value; mutation run 3898.
  - `[high]` `[patch]` verification-gap: a DML statement through a view over OcuPilot's tables is never exercised — verified real: an INSERT through such a view recorded only the view (probe on `ocupilot-a2-ci`), so rule (b) missed it; `Prepared` now adds each view's base tables from `INFORMATION_SCHEMA.VIEW_TABLE_USAGE`, with INSERT and DELETE view legs in `SqlPortLive`, `SqlConsoleRoutes` and `SqlConsoleWrite`; mutation run 3894. A principal holding privileges on the view alone still sees no base table: deferred.
  - `[low]` `[patch]` verification-gap: rule (c)'s default schema is never verified through the port — `SqlPortLive` asserts the guard's `DefaultSchema` equals the namespace's; mutation run 3895.
  - `[low]` `[patch]` verification-gap: the fail-closed refusal of an unindexed statement has no test — `Test/SqlPortUnindexed` fixture and `SqlPortLive.TestAnUnindexedStatementFailsClosedAndLogsNoText`; mutation run 3896.
  - `[medium]` `[patch]` verification-gap: AC7's no-log-line check never reaches the one path that logs (`Fail`) — the same test's log leg scans `messages.log` for the refusal's line and the statement's mark; mutation run 3897.
  - `[low]` `[patch]` verification-gap: the rolled-back and stopped-query status lines are never rendered in a test — one `sql-query.page.spec.ts` case; mutation observed red under vitest.
  - `[low]` `[reject]` verification-gap other: a re-prepare answering another type shows an empty status line — needs a schema or grant change between the two prepares of one request; the fix adds a branch and a string.
  - `[low]` `[reject]` verification-gap other: the bound-not-spliced value catches only a quoted splice — its recorded mutation reddened it, and a raw splice breaks `SqlConsoleWrite`'s no-trace UPDATE and the browser spec's echo leg.
  - `[low]` `[patch]` verification-gap other: the AC9 browser comment named a different first-failing assertion — corrected to "Proceed created the table"; browser runs carry no run id.
  - `[low]` `[reject]` verification-gap other: `FINGERPRINTSUBJECT` includes `maxRows`, beyond the task line — the fix would edit this build's spec; `PortQuery` needs `maxRows` after projection (Auto Run Result).
  - `[low]` `[reject]` verification-gap Rule 19: AC6's query half has no demonstrated mutation — Rule 19 asks one per AC (the DML half, run 3877); an unbounded five-way cross join would hold a throwaway process to the gateway bound.
  - `[medium]` `[patch]` verification-gap Rule 19: AC7's log clause could not fail — grouped with the log-line row above.
  - `[medium]` `[patch]` verification-gap Rule 19: AC8's route clause had no test, its `%Developer` clause no mutation line — the route clause is grouped with the first row; the `%Developer` clause is `DeveloperFloor`'s, and one mutation per AC is the bar.
  - `[low]` `[patch]` verification-gap Rule 19: the AC9 line has no run id — grouped with the AC9 comment row.
  - `[low]` `[reject]` verification-gap Rule 19: `Executed`'s privileged prepare is pinned only by source text — not reachable on its own: `Classify`'s privileged prepare refuses first, and the source pin catches the off spelling.
  - `[high]` `[patch]` intent-alignment A: `ExplorerSqlRun` declared no pairs, so the classic SQL page's custom resource was never checked on the confirmed run — verified: with the resource assigned, a lacking principal's confirmed run was admitted (run 3892 with the old code); `PrivilegePairs` now answers `Screen.Gate.RequiredPairs` of its descriptor.
  - `[false]` `[reject]` intent-alignment B: missing database READ answers `NS.DENIED` over HTTP — the caller is refused 403 naming the pair before any prepare; the router's namespace gate answers first for every namespace-scoped route, and the port's own refusal is pinned by `SqlPortLive`.
  - `[medium]` `[defer]` intent-alignment C: a CREATE TABLE text another account prepared runs for an unprivileged principal — vendor behavior, already in `deferred:`.
  - `[low]` `[reject]` intent-alignment D: the production bound is never exercised — a 50-second wait per run; the fixture overrides only `BoundSeconds`, and Task 0 (b) measured the production value.
  - `[false]` `[reject]` intent-alignment D: the `other` kind runs unbounded — the intent bounds queries and DML; `other` is neither.
  - `[false]` `[reject]` intent-alignment D: the screen says a stopped DML statement's changes were undone from its kind alone — the instance rolls a stopped DML statement back whole (measured; the stopped-UPDATE leg pins the table unchanged).
  - `[low]` `[reject]` intent-alignment E: the routes prepare a statement naming OcuPilot before refusing it — the prepare executes nothing and leaves the statement-index row every console statement leaves; a pre-prepare check is a new guard.
  - `[low]` `[reject]` intent-alignment E: the write path's DROP leg names a stand-in table — rule (a) refuses it either way, the real name is pinned on both routes where nothing executes, and a regressed refusal would drop OcuPilot's own table.
  - `[low]` `[patch]` intent-alignment E: rule (c) is tested with made-up inputs only — grouped with the default-schema row.
  - `[false]` `[reject]` intent-alignment F: vendor audit rows carry the text and values when the operator enables those events — the intent's line is anchored on AD-39, which governs what OcuPilot emits; the vendor row is AD-53's named gap, and `noAudit` would hide the run from the operator's chosen audit.
  - `[low]` `[reject]` intent-alignment G: the 1,000,000-character cut is measured over the kept rows — the overshoot is the column header and envelope.
  - `[maybe-false]` `[defer]` intent-alignment G: another SQL form may set a password — deferred (medium, unverified) with the check that settles it.
  - `[false]` `[reject]` intent-alignment G: the index check uses a SELECT literal as a stand-in for CREATE USER — by design: no password statement is prepared even under a mutation.
  - `[low]` `[reject]` intent-alignment G: THROUGH is pinned by its type number alone — it prepares only against a pass-through foreign server the throwaway cannot host; type 80's kind and the server-files refusal are each pinned.
  - `[low]` `[reject]` intent-alignment G: a refused-kind statement whose prepare fails answers `error` — nothing runs, and the kind is unknown without a prepare.

## Design Notes

**Intent gap: split (recommended).** The story asks for a run-in-background option. As a background job, it needs four things this story cannot also carry:

- A fourth spawn site. AD-42 names three.
- A decision under AD-7. AD-7 forbids a mutation by a detached process, so background runs would be queries only.
- An owner-scoped result store in protected state, swept like progress (AD-9, AD-33, AD-37).
- A poll route, a cancel route and their client state.

Measured, it is feasible:

- `$System.Alarm` bounds a query.
- A least-privileged user's `$SYSTEM.SQL.CancelQuery(pid)` stopped its own job's query in 0.001 s, with SQLCODE -456.

**Recommended:**

- **19.6 (this spec):** the console, the guard, values, Max rows, the plan and confirmed DML and DDL.
- **19.15 (new, `N.<M+1>`):** `19-15-the-query-console-runs-a-query-in-the-background`. A query (never a mutating kind) runs in a job spawned from no escalated frame, as the signed-in user, under the same alarm bound, cancellable through `CancelQuery` on its own job. Its result is kept in protected state, keyed by run and owner, answers 404 to anyone else, and is swept as progress is.

The guard stays in this story with the console.

**Measured on `ocupilot-a2-ci`, 2026-10-03.** Probe schema `OcuProbe196`, probe class `OcuProbe196.Probe` (USER and HSCUSTOM), and principals `OcuProbe196U`/`R` were created and removed, and checked gone. Statement-index rows remain on the throwaway, including the password row in `deferred:`.

- **Privileges** (principal: `%Development:U`, `%DB_USER:RW`, SELECT on `Granted`):
  - `%Prepare(text,1)` answered -99 for SELECT, UPDATE, INSERT, DELETE, TRUNCATE (`%NOTRIGGER`), CREATE/ALTER/DROP TABLE, CREATE VIEW, CREATE INDEX, CREATE PROCEDURE and CALL. It also answered -99 for SELECT on a view over the granted table.
  - GRANT prepared, then failed at execution with -112.
  - `EXPLAIN` and `$SYSTEM.SQL.Explain` answered -99 for the ungranted table.
  - The principal reads its own statements' `STATEMENT_LOCATIONS` and `STATEMENT_RELATIONS` rows.
- **Classifier:**
  - `statementType` matched the vendor table for 41 statements.
  - `WITH`, `UNION` and `EXPLAIN …` (including `EXPLAIN STAT UPDATE/DELETE`) are type 1, and EXPLAIN STAT left the table unchanged.
  - TRUNCATE is 4. `INSERT OR UPDATE` is 2. CALL is 45.
  - A leading comment and `/* SELECT */` did not change type 4.
  - `a; b` was refused at prepare with -25.
  - `SELECT %SYSTEM.CancelQuery(1)` is type 1: a function's effect is invisible to the type (named limit).
- **Relations:**
  - SELECT, DML and CREATE VIEW record their tables. A view lists its base tables, and `SELECT … FROM OcuPilot_Kernel_State.Proposal` records `OCUPILOT_KERNEL_STATE.PROPOSAL`.
  - DDL on a table, CALL, privilege and utility statements record none.
  - A DML statement's cached query answers no `%StatementIndexHash`; its `STATEMENT_LOCATIONS` row `<class>.1` does.
- **Bound:**
  - `$System.Alarm.Set(3)` stopped a cross-join count after 3.03 s, with SQLCODE -450.
  - It stopped an UPDATE (slow function, 40 rows) after 3.05 s, with SQLCODE -149, and the table read unchanged.
- **Plan:** `Explain` answers `<plans><plan>…` text in about 0.003 s and executes nothing. It refuses CREATE TABLE and CALL with -481a.
- **Audit:** every `%System/%SQL/*` event and `%System/%SMPExplorer/ExecuteQuery` read `Enabled` No.

**Task 0, measured on `ocupilot-a2-ci`, 2026-10-03.** Probe objects and principals were removed and checked gone.

- **(a) Audit:** with `%System/%SQL/DynamicStatementDML` and `DynamicStatementDDL` enabled, one `%Prepare(text,1)`/`%Execute` of each wrote one audit row. The DDL row (`SQL CREATE TABLE Statement`) holds the statement text; the DML row (`SQL INSERT Statement`) holds the text and the bound parameter values. Both events were restored to disabled.
- **(b) Bound:** `TestCall.GatewaySeconds()` answered 60 for a `%Developer` principal, read from the configuration file (`CSP.ini`), and 60 for `_SYSTEM`, from the live Gateway registry; `BoundSeconds` is 50 for both.

**Guard** (`%Metadata.statementType` → kind):

| Kind | Types | Console |
|---|---|---|
| `query` | 1, 28, 32, 79 | runs at once |
| `dml` | 2, 3, 4 | confirm |
| `ddl` | 9–15, 17, 35–44, 52, 54–58, 60–68, 70, 71 | confirm |
| `call` | 45 | confirm |
| `other` | 16, 25, 27, 99, any unnamed number | confirm |
| session | 5, 6, 20–24, 26, 46–48, 51, 53, 59, 78 | `EXPLORER.SQL.SESSION` (they change or act on a server process, which a console run does not keep; cancel is Stage 4) |
| administration | 7, 8, 18, 19, 29–31, 33, 34, 49, 50 | `EXPLORER.SQL.ADMINISTRATION` (AD-10's account, role, namespace and database predicates cannot be evaluated on a SQL statement's target; Permissions and OS management carry them) |
| server files | 69, 72–77, 80 | `EXPLORER.SQL.SERVERFILES` (AD-21: no caller names a server path or another server) |

**Self-protection** (`PROHIBITED.OCUPILOTSQL`, AD-9, AD-10). Any of these refuses the statement:

- (a) its text contains `ocupilot` in any case;
- (b) a table or view the statement index records for it, a view's base tables included, is in a schema beginning `OcuPilot` in any case;
- (c) it records no table, and `$SYSTEM.SQL.Schema.Default()` begins with `OcuPilot`.

Rule (a) is the fail-closed backstop where the instance records no target, and it over-refuses a literal or comment. A value bound by `?` is never text. The named gap is a procedure or function whose own code reaches OcuPilot's tables: the guard sees the statement, not the code it calls (as AD-57 names its gap).

**Decisions (for the spec gate).**

- *Port.* `Port/SqlPort` is AD-61's first named case (draft below). It sits beside AtelierPort as AD-27's named-case ports sit beside AdminPort, reuses rule 1's gate and names no Atelier class.
- *Write mechanism.*
  - A confirmed run is AD-53's screen action. It goes through one tool, `explorer.sqlquery.run`, unadvertised and with its key `false`. Story 19.11 advertises it.
  - `statement`, `parameters` and `maxRows` are declared screen values. 19.11 decides how the agent supplies them, and whether code-carrying DDL (types 35–38, 43, 67) is refused for the agent.
  - The target is `(class, <ns>, sql)`, as 19.13's `import`. That serializes console writes per namespace (10 s claim) and lets the SQL catalog re-fetch on AD-14's event. Its sibling-cancel effect on agent proposals is 19.11's to revisit.
- *Audit.* The vendor records no event for a console run with the stock event set (measured). So this is AD-53's named gap and AD-15's named case for 19.11. Task 0 (a) records whether an enabled event captures it.
- *Results.* Results are screen-only. The spine does not settle whether a console result reaches the agent; the descriptor declares no read and no context fields.
- *AD-7.* No turn runs a console statement here, so the fifth shape is unchanged. 19.11 extends it when its turn prepares caller statements.
- *Select mode.* ODBC (1), so dates and times read alike across locales. The classic page offers Display, ODBC and Logical.

**Spine amendments (draft, for the lead's gate).**

- **AD-61**, replacing the closing paragraph:

  > A later call Atelier cannot carry names itself here. **Story 19.6's case, the SQL console** [AMENDED 2026-10-03, Story 19.6 spec gate, Rule 20]. `action/query` carries a caller's statement only with privilege checks off (rule 7), a form AD-8 and AD-21 rule out. So `Port/SqlPort` (declared by `explorer.sqlquery.run`, AD-52) evaluates rule 1's read pairs. It then prepares the statement whole with `%SQL.Statement.%Prepare(text, 1)` in the target namespace (rule 4) and runs it there, as the signed-in user. It names no `%Api.Atelier.*` class and uses no capture. It classifies by the prepared `statementType`. It refuses session, administration and server-file statements, and text setting a password (before any prepare, because the instance keeps a prepared statement's text, a password literal included, in its statement index; measured). It bounds a query or DML with `$System.Alarm` at `TestCall.BoundSeconds` and rolls back a transaction a run leaves open. Measured on `ocupilot-a2-ci`: a principal holding `%Development:USE`, `%DB_USER:RW` and SELECT on one table was refused -99 at prepare for SELECT, DML, TRUNCATE, table, view, index and procedure DDL, and CALL on another; a GRANT was refused at execution (-112).

- **AD-10**, a new arm:

  > **OcuPilot's own tables and code, through SQL** (Story 19.6): a console statement whose text names `ocupilot`, whose recorded tables (a view's base tables included) lie in an `OcuPilot` schema, or that records none while the instance's default schema is an `OcuPilot` one, is refused `PROHIBITED.OCUPILOTSQL` on every path, reads included.

  Named gap: a procedure's or function's own code.

- **AD-21**, a new case:

  > **The SQL console's statement is the caller's own SQL, not a value** (Story 19.6): OcuPilot concatenates nothing into it, prepares it whole with privilege checks on as the signed-in user, binds its values as parameters, and refuses a statement that names a server file or another server (LOAD, foreign servers and tables, THROUGH).

- **AD-36:**

  > A console run's rows and plan are a screen-only payload (Story 19.6), bounded by its Max rows (1 to 1,000), 1,000 characters a cell and 1,000,000 in all, never a declared read, a tool's view or screen context.

- **AD-39**, the sixth exception:

  > A console run's rows, SQLCODE and message, and a plan, reach the screen only (Story 19.6).

- **AD-53:**
  - The unadvertised named case's third: `explorer.sqlquery.run`.
  - Named gap fourteen: SQL query's runs (no vendor event with the stock event set; every `%System/%SQL` event and `%SMPExplorer/ExecuteQuery` disabled, measured).
- **AD-51** (Story 19.6's case):

  > `SqlPort` builds the run from the tool's declared screen values and answers its fresh read through a port-composed `GUARD` type.

- **AD-44** (Story 19.6): the console declares `%CSP.UI.Portal.SQL.Home`, and its tool declares no `CLASSICPAGES`.
- **AD-13** (Story 19.6): the console's target is the literal `sql` under `class`.
- **AD-8** (Story 19.6): the console's write declares no pair beyond its screen's. Its SQL privileges, checked at prepare, and the databases it writes are the instance's to refuse (measured).
- **Deferred:** run-in-background, to Story 19.15, if the split is approved.

**Strings.** One Fixed-strings row (:597). Estimate: about 35 literals against 238 of headroom under `strings.test.mjs`'s 2,500 (2,262 flat measured), so no raise is needed.

- Labels: "SQL query", "Statement", "Explain plan", "Plan", "Value <n>", "Run this statement?".
- Confirmation consequences:
  - "It changes rows in <tables>, and cannot be undone from OcuPilot."
  - "It changes this namespace's schema, and cannot be undone from OcuPilot."
  - "It runs a stored procedure, which can change anything this account may change."
  - "The instance does not say what this statement changes."
- Status lines:
  - "<n> rows" and "<n> rows; the first <max> are shown"
  - "<n> rows changed" and "Done"
  - "Stopped after <s> seconds." and "Stopped after <s> seconds; its changes were undone."
  - "This statement takes <n> values." and "This kind of statement has no plan."
  - "SQLCODE <code>" and "Write one SQL statement, then Run."
- Reasons:
  - INPUT: "Send one statement of up to 100,000 characters, at most 100 values of up to 32,767 characters each, and Max rows from 1 to 1,000."
  - SESSION: "This statement controls a server process (a transaction, lock, option, cursor, namespace or running query) and is not run here."
  - ADMINISTRATION: "Users, roles, privileges and databases are changed on Permissions and OS management, where OcuPilot checks each change; this statement is not run here."
  - SERVERFILES: "This statement reads a server file or another server, which OcuPilot does not let a caller name."
  - PASSWORD: "A statement that sets a password is not prepared here, because the instance keeps a prepared statement's text; set passwords on Permissions › Users."
  - READS: "This statement only reads, so it runs without confirming."
  - PARAMETERS: "Give one value for each ? in the statement."
  - OCUPILOTSQL: "This statement reads or changes OcuPilot's own tables or code, which OcuPilot does not offer."
- Three prompts: "What does this statement's plan say about the indices it uses?" · "How do I pass a value to a ? in a statement?" · "Why was my statement refused here?"

**Rosters** (verify each at edit time; counts move):

- `GovernanceBaseline` `DISABLED` :14, `Governance` `EXPLORERDISABLED` :33, `ToolDispatch` :168.
- `ExplorerDescriptor` `DESCRIPTORS` :20 ("twenty-seven" :17), side bar :40, actions :169, baseline :164.
- `DeveloperFloor` `SCREENS` :33, `TOOLS` :36, the count words at :9, :439 and :462.
- `SurfaceCoverage`: a tool row and a screen row. `ReadTool` :93 if it counts every registered tool.
- `Test/Prohibited.cls` :427 if the tool's endpoint/type is composed. `RefusalCopy` :106-109 for `PROHIBITED.OCUPILOTSQL`.
- `DraftRegistry` (`SnippetForm` non-empty).
- `ui/tools/self-protection.test.mjs`: `KERNEL_REFUSALS` :282 and `ATELIER_REFUSALS` :505-520.
- Client rosters: `navigation.test.mjs` :257-290, `screen-mirror.test.mjs`, `side-bar.spec.ts`, `command-box.spec.ts`, and `browser/structural-walk.mjs` :88-101.

**Consumes:**

- `AtelierPort.NamespacePairs`/`PAIRS`, `Screen.Gate`, `Api.ScreenAction`, `Operation`, `Prohibited`, `TestCall.BoundSeconds`/`GatewaySeconds`;
- `ScreenActionHandler.sendFor`, `warning-dialog`;
- the SQL catalog (19.5) for AC9.

**Consumed-by:**

- 19.11: the guard, `SqlPort` and `explorer.sqlquery.run`. It advertises the tool and enables or keeps its key. It decides:
  - the agent's code-carrying DDL and the target id;
  - how a confirmed statement's SQL error is recorded (this story answers it as `output`);
  - whether results reach the model, including statement-index columns such as `UserName`.
- 19.15: background runs.
- 19.7 and 19.8: a grid write cannot use `action/query`, and may run port-owned statements through `SqlPort` (inference).

**ADs:** AD-5, AD-7, AD-8, AD-9, AD-10, AD-11, AD-12, AD-13, AD-14, AD-15, AD-16, AD-21, AD-22, AD-24, AD-29, AD-34, AD-36, AD-39, AD-42, AD-44, AD-51, AD-52, AD-53, AD-55, AD-56, AD-58, AD-59, AD-61.

**Footprint (Rule 11).** Checked 2026-10-03 against `.worktrees/epic-18` at `703210aeb83e8bb56de07e4c182943f6e433b108`, committed and uncommitted (an untracked 18.6 spec only).

- **Contended, add-only:**
  - `Api/Router.cls` (tail);
  - `screen-outlet.ts`, `strings.ts` (end), `_components.scss`;
  - `SurfaceCoverage`, `ReadTool` rows;
  - `navigation.test.mjs`, `screen-mirror.test.mjs`, and `rail-wire.spec.ts`/`navigation-wire.test.mjs` if they enumerate;
  - the Fixed-strings row after :596;
  - `screens.generated.ts` (regenerated).
- **Contended, not add-only (lead approval):**
  - EXPERIENCE.md :173 (Epic 18 edits the same line; union by hand) and :159;
  - `ui/angular.json` with `angular-json.test.mjs`;
  - the spine.
- **Shared by the union-at-merge rule:** `Baseline.cls`, `GovernanceBaseline`, `Governance`, `ToolDispatch` (add-only).
- **Not contended:**
  - `Prohibited.cls` (its class branch is not add-only), `AtelierError.cls`;
  - every new class and file;
  - `ExplorerDescriptor`, `DeveloperFloor*`, `RefusalCopy`, `Test/Prohibited.cls`, `DraftRegistry`, `self-protection.test.mjs`.

**Ledger inbox:**

- DW-1964 is carried as the `DW-1964:` criterion.
- DW-1963 (vendor) is decision-pending with the owner; this story adds no occurrence.
- No read tool is added, so there is no DW-1001 occurrence.

## Verification

Load source into `ocupilot-a2-ci` and never restart it:

1. `rsync -a --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-19/src/ /tmp/ocupilot-a2-ci/src/`
2. In `docker exec -i ocupilot-a2-ci iris session iris -U HSCUSTOM`, run `$System.OBJ.LoadDir("/opt/ocupilot/src","ck",.tErrors,1)`, then check the status and `tErrors`.

**Run one test-runner call at a time, and wait for each.** Never re-submit after a client-side timeout. Every `OcuProbe196*` object and principal is removed after the run, and the Task 0 audit events are restored.

**Commands:**

- `uv run scripts/check-objectscript.py && uv run scripts/test_check_objectscript.py` (loop): expected green.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-a2-ci --class OcuPilot.Test.<Class>` (loop), one class per call: expected green. Run it for:
  - `SqlPort`, `SqlPortLive`, `SqlConsoleRoutes`, `SqlConsoleWrite`;
  - `ExplorerDescriptor`, `DeveloperFloor`, `DeveloperFloorRoutes`;
  - `GovernanceBaseline`, `Governance`, `ToolDispatch`, `Prohibited`, `RefusalCopy`, `DraftRegistry`, `SurfaceCoverage`, `ReadTool`, `AtelierPort`.
- `cd ui && npm run test:tools && npx ng test --include 'src/app/areas/system-explorer/**/*.spec.ts' --include 'src/app/shell/**/*.spec.ts'` (loop): expected green.
- Browser (loop). Build and deploy first: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-a2-ci:/durable/iris/csp/ocupilot/`. Then run each file alone with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52780 OCUPILOT_BROWSER_CONTAINER=ocupilot-a2-ci node --test --test-concurrency=1 browser/<file>`, for `system-explorer-sql-query.browser-spec.mjs`, `system-explorer-sql.browser-spec.mjs` and `a11y-structural-invariants.browser-spec.mjs`: expected green. The full browser suite is CI's.
- `bash scripts/lint-docs.sh && cd ui && npm run test:tools` (loop, after the EXPERIENCE.md edit): expected green.
- `cd ui && npm test` (once, before dev_complete): expected green, with the budget re-based.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-a2-ci`, the full ObjectScript sweep, one class at a time (once, before dev_complete): expected green apart from the known `WireSecurityRead` (DW-1554) and `Retention` (DW-1929) residue.

**Planned mutations (Rule 19)**, one per AC:

- AC1: `Run` splices the first value into the text → the bound-not-spliced leg.
- AC2: `Classify` maps type 4 to `query` → the disguised-DELETE leg (it runs without `confirm`).
- AC3: the password check moved after the prepare → `SqlPortLive`'s statement-index-holds-no-row leg.
- AC4: rule (b) skipped → the view-over-`Proposal` leg.
- AC5: `Plan` executing the statement → the plan-leaves-the-table-unchanged leg.
- AC6: the alarm not set → the stopped-DML leg.
- AC7: `ADVERTISED` 1 → `SqlConsoleWrite`'s unadvertised leg.
- AC8: the descriptor's `classicPage` `""` → `ExplorerDescriptor`.
- AC9: `SqlPort.Run` answering `done` for a `ddl` kind without executing it → the browser AC9 leg (SQL tables does not list the table).
- DW-1964: `%Prepare(text, 0)` → the principal's UPDATE leg (the table changes).
- mutation: AC1, `Executed` splices the first value into the text as a literal → `SqlPortLive.TestAQueryAnswersItsRowsBoundAndCut`, the bound-not-spliced leg alone (run 3872).
- mutation: AC2, `TYPESQUERY` maps type 4 to `query` → `SqlConsoleRoutes.TestAChangeWaitsOnAConfirmationAndRunsNothing`, both disguised-DELETE legs and "nothing ran" (the DELETE ran without a confirmation; run 3873).
- mutation: AC3, the password check moved after the prepare in `Classify` → `SqlPortLive.TestRefusedStatementsAndThePasswordNeverReachTheIndex`, the statement-index leg alone (run 3874).
- mutation: AC4, rule (b)'s loop in `Prohibited.SqlStatement` skipped → `SqlPortLive.TestOcuPilotsOwnTablesAreFoundAndRefused`, the view-over-`Proposal` leg alone (run 3875).
- mutation: AC5, `Plan` runs the statement through `Executed` before `Explained` → `SqlPortLive.TestAPlanExecutesNothing`, the unchanged-table leg (run 3876).
- mutation: AC6, the alarm not set for an UPDATE (type 3) in `Executed` → `SqlPortLive.TestAStatementPastTheBoundIsStopped`, the stopped-UPDATE and unchanged-table legs (run 3877). Narrowed to type 3 so the unbounded cross-join query leg does not run on the throwaway.
- mutation: AC7, `ExplorerSqlRun.ADVERTISED` 1 → `SqlConsoleWrite.TestTheRunIsAbsentFromEveryRosterTheAgentSees`, six legs (run 3878).
- mutation: AC8, `ExplorerSqlQuery` `classicPage` `""` → `ExplorerDescriptor.TestSqlQueryKeysTheClassicSqlPage` (run 3879).
- mutation: AC9, `Run` answers `done` for a `ddl` kind without executing it → `system-explorer-sql-query.browser-spec.mjs`, the AC2/AC9 test at "Proceed created the table".
- mutation: DW-1964, both `%Prepare(pText, 1)` calls (`Prepared` and `Executed`) given 0 → `SqlPortLive.TestTheInstanceRefusesAnUngrantedTableAtPrepare`, legs 1-5, the unchanged-table and nothing-created legs (run 3880). `Executed` alone stays green, since `Classify` refuses first.
- mutation: AC8, `ExplorerSqlRun.PrivilegePairs` answering no pair → `ClassicPageGate.TestAnAssignedPageGatesTheSqlConsole`, the lacking principal's confirmed-run leg alone (run 3892); the screen gate dropped from `SqlConsole.Prepare` → its run and plan legs (run 3893).
- mutation: AC4, the view expansion in `Prepared` skipped → `SqlPortLive.TestOcuPilotsOwnTablesAreFoundAndRefused`, the INSERT-through-the-view legs alone (run 3894).
- mutation: AC4 rule (c), `Prepared` answering an empty `defaultSchema` → `SqlPortLive.TestTheKindIsThePreparedStatementType`, the default-schema leg alone (run 3895).
- mutation: the unindexed refusal dropped from `Classify` → `SqlPortLive.TestAnUnindexedStatementFailsClosedAndLogsNoText`, its refusal and logged legs (run 3896); AC7, the statement put into that refusal's logged status → its log leg alone (run 3897).
- mutation: AC1, the confirmation answered before the value count in `HandleRun` → `SqlConsoleRoutes.TestTheRunRouteAnswersAQueryAndAsksForValues`, the UPDATE-with-a-? leg alone (run 3898).
- mutation: AC6 on the screen, `statusLineFor` dropping its rolled-back line → `sql-query.page.spec.ts`, "reads a run whose open transaction was undone" (vitest).
- mutation: `PortGate`'s `SqlPort` row absent → `PortGate.TestEveryPortDeclaresANamedGate` (run 3925, before the row was added).

## Auto Run Result

Status: done
Blocking condition: none

- **Summary:** SQL query (System Explorer, side bar 10) runs one statement through the new `Port/SqlPort`. The port gates first, refuses bad input and password text before any prepare, prepares with `%Prepare(text, 1)` as the signed-in user, classifies by `statementType`, and refuses session, administration and server-file kinds. A query runs under the alarm with Max rows and the cell and answer cuts; Explain executes nothing. DML, DDL, CALL and unclassified statements answer `confirm` and run only through the unadvertised `explorer.sqlquery.run` (key `false`), which classifies again and holds `PROHIBITED.OCUPILOTSQL` inside the target's hold. Rows, errors and plans reach the screen only.
- **Files:** new `Port/SqlPort.cls`, `Area/Explorer/SqlConsole.cls`, `Screen/Descriptor/ExplorerSqlQuery.cls`, `Screen/Tool/ExplorerSqlRun.cls`; edited `Prohibited.cls` (code, `SqlStatement`, the RUN arm), `AtelierError.cls` (7 codes), `Router.cls` (2 routes), `Baseline.cls`; client `sql-query.page.ts`/`.store.ts` with `screen-outlet.ts`, `screens.generated.ts`, `strings.ts`, `_components.scss`; EXPERIENCE.md :159, :173, :597; `angular.json` budget 2655kB (measured 2,654,833 bytes, DW-1166); tests `SqlPort`, `SqlPortLive`, `SqlPortFixture`, `SqlPortUnindexed`, `SqlConsoleProbe`, `SqlConsoleRoutes`, `SqlConsoleWrite`, `sql-query.page.spec.ts`, `system-explorer-sql-query.browser-spec.mjs`; rosters `ReadTool`, `GovernanceBaseline`, `Governance`, `ExplorerDescriptor`, `DeveloperFloor`(`Routes`), `SurfaceCoverage`, `EndpointCoverage`, `ToolWrite`, `Test/Prohibited`, `RefusalCopy`, `PortGate`, `ToolEmit`, `AuditingUpdate`, `ToolRoundTrip`, `ClassicPageGate`, `navigation.test.mjs`, `self-protection.test.mjs`, `angular-json.test.mjs`, `ci-throwaway.sh`'s arming roster.
- **Review:** 31 findings; patched 2 high (the run's missing pairs, so the classic page's custom resource now gates the confirmed run; INSERT through a view over OcuPilot's tables, now expanded through `VIEW_TABLE_USAGE`), 4 medium entries and 6 low rows; 2 deferred (view-only principal, password forms); the rest rejected with reasons in the triage log. Follow-up review: `false` — both patched highs are pinned by demonstrated mutations (runs 3892, 3894), and the one measured limit of the view fix is deferred, not unverified.
- **Deviations from the plan:** `FINGERPRINTSUBJECT` carries `maxRows` so `PortQuery` keeps it after projection; the cut status reads "<n> rows are shown; the answer holds more." because the port never learns the total; the password reason names "the Users list in Permissions" instead of a `›` path; `explorerSqlRolledBack` added for a run that left a transaction open; `PortGate`'s roster row names the reused `OcuPilot.Port.AtelierPort.PAIRS`, and the test now reads a qualified row.
- **Verification:** `check-objectscript` 0 problems, harness OK; `lint-docs` clean; `npm test` 1781 tools and 2247 component tests green; browser `system-explorer-sql-query` 2/2 after the review patches (`system-explorer-sql` 4/4 and `a11y-structural-invariants` 12/12 at the handoff); per-class runs after patches green (`SqlPortLive` 3888, `SqlConsoleRoutes` 3889, `SqlConsoleWrite` 3890, `ClassicPageGate` 3891, `PortGate` 3936, `ToolEmit` 4153, `AuditingUpdate` 4154, `ToolRoundTrip` 4336). Full ObjectScript sweep on `ocupilot-a2-ci` as 20 sequential `--shard k/20` legs, one class at a time: 434 classes, 3,540 tests. `PortGate`, `ToolEmit`, `AuditingUpdate` and `ToolRoundTrip` were this story's roster misses, fixed and re-run green. Residue: `MappingCodeGlobals` (an `^oddPKG("OCUPILOT")` schema entry written 16:38:44 by the plan stage's probe process, journal-verified), `WireSecurityRead` (DW-1554). Environment: `JournalSettingsWrite`, `JournalWrite`, `JournalSettingsRules`, `PathPortInstance` and `JournalWriteGate` refuse at setup because this throwaway predates `OCUPILOT_ALLOW_JOURNAL`.
- **Residual risks:** the two deferred items; `ClassicPageGate.cls`, `PortGate.cls`, `ToolEmit.cls` and `AuditingUpdate.cls` are edits beyond the plan's footprint (add-only or union-at-merge roster lines, none on a line Epic 18 changes); probe runs leave `^oddPKG("OCUPROBE196")` schema entries in USER and HSCUSTOM, which no SQL statement removes.
