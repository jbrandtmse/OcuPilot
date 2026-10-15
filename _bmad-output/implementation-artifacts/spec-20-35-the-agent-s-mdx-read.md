---
title: 'Story 20.35: The agent''s MDX read'
type: 'feature'
created: '2026-10-14'
status: 'blocked'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-20-33-the-mdx-query-tool.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** A person can ask the agent about a cube's numbers, but the agent cannot run MDX: Story 20.33's MDX query screen is the person's own tool, and its answer never reaches the model. MDX text can also make the vendor run ObjectScript or SQL with the caller's rights, and an agent read tool never executes code (AD-60, AD-65).

**Approach:**

- A read tool, `analytics.mdxquery.read`, bound to MDX query (Story 20.33). It runs one MDX statement **synchronously in the turn job** through `AnalyticsPort`, under 20.33's gate and caps, and answers cells, or a drill-through's listing, to the model through AD-60.
- Before anything is prepared, it refuses with 422 `ANALYTICS.MDX.SQL` any statement in which `AnalyticsPort.MdxConstructs` finds text that runs server-side code or SQL. That detection is the one the screen's ask-first uses. Under the recommended ruling (Design Notes › Intent gap), it reads the vendor's own tokens and covers five constructs.
- The run polls the vendor up to its time bound, and stops early on the person's Stop. A stopped run leaves nothing running.

## Boundaries & Constraints

**Always:**

- **Gate first (AD-29, AD-65).** Before any vendor call, in this order:
  1. the argument schema;
  2. MDX query's pairs (`Screen.Gate.Evaluate` on its descriptor, including AD-64's adjustment and the classic page's custom resource);
  3. `MdxAdmit` in the turn's namespace (`Kernel.Scope.Current()`);
  4. `MdxConstructs`;
  5. `MdxPrepare`, with its kind and axes refusals.

  A refusal names the failed pair.
- **The detection** (option A). It is case-insensitive and reads three things:
  - the raw text;
  - the vendor lexer's tokens, in which a comment inside a word is dropped as the vendor drops it;
  - the tokens of every quoted string in the text, read the same way (`%MDX('…')`, `WITH … AS '…'`).

  `MDXCONSTRUCTS` is `%SEARCH,%SQLRESTRICT,RETURN,%ORDER,%PARM`. A refused statement is never prepared, run or cached.
- **Caps.**
  - 20.33's `AnalyticsPort` limits apply as written: `MDXMAXSTATEMENT`, `MDXMAXROWS`, `MDXMAXCOLUMNS`, `MDXMAXLISTINGROWS`, `MDXMAXCELL`, `MDXMAXANSWER`, `MDXSECONDS` and `MDXSETTLESECONDS`.
  - AD-24's row cap and per-reply total then apply at dispatch.
  - The vendor's error message is cut at `MDXMAXCELL`.
- **Bound and Stop (AD-7).**
  - The run polls the vendor's status. It also polls the turn's stop and abandon signals, and whether the lease has lapsed.
  - At the bound, or on any of those signals, it calls `MdxCancel`, waits up to `MDXSETTLESECONDS` for status 100, and answers `stopped`.
  - Nothing is left running it.
- **What reaches the model (AD-36, AD-39, AD-60):** the namespace, cube, columns, rows, counts, truncation, an error's message, or a stop's seconds.
  - A listing column named like a credential reads `[redacted]`, and credential literals in its text cells are masked (Story 19.11's rule).
  - The statement is the turn's own tool argument. It reaches no log line.
- **Extend, don't copy (Rule 31):**
  - 20.33's run loop becomes `AnalyticsPort.MdxRun` with a stop hook, and both `MdxQuery.Work` and this tool call it.
  - The listing mask reuses `ExplorerSqlRead`'s helpers.
  - The card's sentence comes through `Api.Error.ReasonForToolCode`, via a new `ANALYTICS.` branch beside `INTEROP.`.

**Never:**

- No background run, `SqlRun` row, `JOB`, route, screen, descriptor, write tool, governance key or proposal. No `/api/deepsee`, `%Api.DeepSee` or `%DeepSee.REST.*`.
- No pivot variables are handed to `%PrepareMDX`. `CREATE`, `DROP` and three or more axes are refused.
- Nothing under `Screen/Tool/` names an `OcuPilot.Api.*` class other than `Api.Error` (checker): `AnalyticsPort` builds the refusal.
- No `SurfaceCoverage` row: its tool half covers write tools only.
- No edits to `app.routes.ts`, `angular.json`, `Kernel/Proposal/Prohibited.cls`, `Kernel/Governance/Baseline.cls`, `.github/workflows/ci.yml`, `ui/tools/ci-shards.mjs`, `ui/tools/ci-timings.json`, `ui/tools/ci.test.mjs`, `epics.md` or the spine. The lead writes the spine drafts.

## I/O & Edge-Case Matrix

The rows run on `ocupilot-b-ci` with `AnalyticsProbe` (20.11; 20.33's grid cube and splice node) in USER, through the tool's `View` with the scope set to USER, as `_SYSTEM` unless a principal is named. "Node n" means `^OcuPilotProbeMdxSplice(n)` in USER.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Cells | A SELECT over `OcuPilotProbeVisits`: a measure on columns, the category level on rows | `{namespace, outcome: "cells", cube, columns, rows, rowsAvailable, columnsAvailable, truncated: false}`. `columns[0]` is `""` (the label column), then the column labels. Each row is `[label, cell…]`, and every cell is the vendor's value as text. These equal `%GetOrdinalLabel`/`%GetOrdinalValue` | - |
| Row cap | 2,000 grid members on rows, through a real turn | `rowsSent` equals the context row cap read at that moment, `rowsAvailable` is 2,000 and `truncated` is true | - |
| Typed drill | `DRILLTHROUGH SELECT FROM [OcuPilotProbeVisits]` | `outcome: "rows"`, `columns`, `rows` (arrays of text), at most 1,000, with `truncated` set when the source holds more | - |
| Cell drill | `{statement: <Cells>, drill: {row: 2, column: 1}}` | `outcome: "rows"`, equal to the vendor's listing for the composed `DRILLTHROUGH … %FILTER` of that cell | An ordinal past its axis is 400 `ANALYTICS.MDX.INPUT` |
| Credential column | A listing answer with a column named `Password` | That column's cells read `[redacted]` and it is listed in `redactedColumns` | - |
| Spliced | Each of `%SEARCH` (braces define node 351), `%SQLRESTRICT`, `RETURN`, `%ORDER BY` and `WITH %PARM P AS 'VALUE:{…node 352…}'` + `@P`, in mixed case, comment-split (`%SE/**/ARCH`, `--` and `//` forms), and inside `%MDX('…')` or `WITH MEMBER … AS '…'` | Nothing is prepared (the recorder port saw no `MdxPrepare`), and nodes 351 and 352 stay undefined | 422 `ANALYTICS.MDX.SQL` |
| Not a construct | `[%SE/**/ARCH]` as a bracketed name, or a plain SELECT | Detection finds none, and the statement proceeds to prepare | - |
| Kind / axes | `CREATE MEMBER …`, `DROP …`, or three axes | Nothing runs | 422 `ANALYTICS.MDX.KIND` / `ANALYTICS.MDX.AXES` |
| Syntax | `SELECT FROM [OcuPilotProbeVisits` | `{outcome: "error", message}` with the vendor's text, at most 1,000 characters | - |
| Bound | The slow grid query through the fixture whose `BoundSeconds()` is 2 | `{outcome: "stopped", seconds: 2}`. `%GetQueryStatus` reads 100, and no USER process runs `%DeepSee` code | - |
| Stop | The slow query, with the test's turn stop requested after 1 s | `stopped` within `MDXSETTLESECONDS` + 2 s, with the same checks | - |
| No analytics | Scope HSCUSTOM | No vendor call | 409 `ANALYTICS.NAMESPACE` |
| Read-only cache | Scope HSLIB | No vendor call | 409 `ANALYTICS.MDX.READONLY` |
| No WRITE | P1 (`%DB_USER:R`, `%Development:USE`) | Refused before any vendor call | 403 `AUTH.NOPRIVILEGE`, `failedPair` `%DB_USER:WRITE` |
| No pair | P4 (`%DB_USER:RW`, no `%Development`) | Refused | 403 naming `%Development:USE` |
| No SQL grant | P3 (RW, `%Development`, no SELECT on the source) drills a cell | `{outcome: "error", message}` carrying the vendor's SQLCODE -99 text | - |

</intent-contract>

## Code Map

All paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-20`. Line numbers were read at `868dfa8b93a41598864977cc1f7372c06928cff8`. Stories 20.11, 20.32 and 20.33 land first. Their symbols are marked **(20.11, planned)** and **(20.33, planned)**, and Task 0 re-anchors them.

### The sibling: the agent's SQL read (Story 19.11)

- **`src/OcuPilot/Screen/Tool/ExplorerSqlRead.cls`** (257 lines):
  - parameters: `TOOLNAME` :28, `KIND` :30, `DESCRIPTION` :32, `DESCRIPTORCLASS` :35, `PORTCLASS` :39 (a fixture seam), `MASK` :45;
  - methods: `InputSchema` :49, `PrivilegePairs` :63 (through `Screen.Gate.RequiredPairs`), `SecretArguments` :70 (with `pDeclared` 1), `ResultSchema` :80;
  - `View` :117: it validates its arguments again (:125), re-checks the screen gate (:131-137) and takes the namespace from `Kernel.Scope.Current()` (:148);
  - private `Projected` :191, whose credential-column scan is :207-221, and private `MaskedRows` :230.
- **`Screen/Tool/Base.cls`**: `TOOLNAME` :26, `KIND` :30, `FULFILMENT` :41, `ADVERTISED` :50, the abstract `InputSchema` :62 and `View` :136, `ArgumentsRefusal` :146 and `InternalRefusal` :158.
- **`Screen/Tool/Registry.cls`**:
  - `ToolClasses` :797-837 finds tools by scanning for subclasses and leaves out `OcuPilot.Test.*`. The name pattern is :46, and `WireName` :310 turns dots into underscores.
  - `SchemaProblem` :862 admits no `anyOf`. `InvokeTool` checks pairs and then the schema before `View` (:266-309, :719).
  - The listing cache rebuilds on the compile signature (:114-191), so it needs no edit.
- **`Screen/Context.cls` `ScreenTools`**: the code at :193-199 lists every advertised read tool bound to a form page, but the doc comment at :174-175 says a form page answers `[]`. **`Test/ExplorerDescriptor.cls`**:292 pins `["explorer_sqlquery_read","explorer_sqlquery_run"]` for the SQL screen.
- **Dispatch and bounds**:
  - `Kernel/Agent/Dispatch.cls`: `Bound` runs at :334-343 when the result has a `rows` array, and `Capped` at :344 otherwise. `ErrorContent` :753-759 sends `{code, detail}`, never the reason.
  - `Kernel/Agent/Bound.cls`: the row cap is :55-62. The per-field cut at :64-99 touches only object rows, so arrays of arrays pass uncut. The total is cut by whole rows at :115-152, and a single row too large answers `rowsSent` 0.
  - The AD-60 sanitizer runs in `Kernel/Agent/Loop.cls` at :733.
- **Turn signals**:
  - `Kernel/Agent/Loop.cls` `Boundary` :417-460 reads stop, abandon and the lease (`LEASESECONDS` 120, `Limits.cls`:25) only between steps.
  - `Kernel/State/Turn.cls`: `GuardedSignals` :507 and `GuardedRequestStop` :438. `Kernel/Proposal/Caller.cls` `TurnKey` :26 is `""` outside a turn.
  - The turn job sets no `$System.Alarm`.
- **The card**:
  - `Api/Error.cls` `ReasonForToolCode` :1211-1245. Its `INTEROP.` branch is :1235, and it falls back to a generic sentence. The sibling is `Api/InteropError.cls` `ReasonFor` :515.
  - `ui/src/app/shell/tool-call-card.ts`: the failed line is :123-137 and the rows line :198-206.
- **The checker**: `scripts/check-objectscript.py` :915-916 and :953-959 refuse any `OcuPilot.Api.*` other than `Api.Error` under `Screen/Tool/`. `SqlPort.RefuseFor` (`Port/SqlPort.cls`:1226-1254) is how a tool gets its fault.

### Analytics (planned)

- **`src/OcuPilot/Port/AnalyticsPort.cls` (20.11, 20.33, planned)**:
  - from 20.11: `Admit`, private `Deny`, `Refuse` and `Conflict`, and the `<PROTECT>` mapping;
  - from 20.33: `MDXPAIRS`, the `MDX*` limits, `MDXCONSTRUCTS`, `MdxAdmit`, `MdxConstructs`, `MdxPrepare`, `MdxStart`, `MdxStatus`, `MdxCancel`, `MdxDrill` and `MdxAnswer` (spec-20-33 :212-224).
- **`Api/AnalyticsError.cls` (20.11, 20.33, planned)**: `NAMESPACE` plus the `MDX*` codes, and no `MDXSQL` (spec-20-33 :211).
- **`Area/Analytics/MdxQuery.cls` (20.33, planned)**: `Work`'s run loop (spec-20-33 :235-238).
- **`Screen/Descriptor/AnalyticsMdxQuery.cls` (20.33, planned)**: a `form-page` with no read, `toolIdentifier` `analytics.mdxquery`, and `privileges` `[%DeepSee_Portal:USE, %Development:USE]`.
- **Tests (planned)**:
  - 20.11's `Test/AnalyticsProbe.cls` and `AnalyticsGate`;
  - 20.33's grid cube, slow query and `^OcuPilotProbeMdxSplice`;
  - 20.33's `AnalyticsMdx`, `AnalyticsMdxJob`, `AnalyticsMdxRoutes`, `AnalyticsMdxGate` (P1, P3, P4) and `AnalyticsMdxDescriptor`;
  - 20.11's `ui/tools/analytics.test.mjs` and 20.33's `ui/browser/analytics-mdx.browser-spec.mjs`.

### Tests and rosters to extend (read at this commit)

- `Test/SqlAgentRead.cls`:
  - arming is :18-20 and :59;
  - `Scope.Set` and `Clear` are :95, :102 and :162-168;
  - `TestATurnReadsRowsFramedAsData` :299-336 is the real-turn pattern.
- `Test/SqlCredentialMask.cls` :135.
- `Test/ReadTool.cls` :93-94 holds the count (390 at this commit) and the sorted names.
- `Test/ToolRoundTrip.cls` :95 is `REFUSEEMPTY` (`explorer.sqlquery.read:TOOL.ARGUMENTS`).
- `Test/ToolEmit.cls` :366-370, the `ExplorerSqlRead` branch, and :398, the unknown-source failure.
- `Test/DeveloperFloor.cls` `TOOLS` :41, compared at :489-500.
- `Test/NavSettleJob.cls` `StopWhenPending` (stop from a second process) and `Test/TurnToolsCase.cls`:118 (`Turn.GuardedBegin`).
- `scripts/ci-throwaway.sh`: the `OCUPILOT_ALLOW_PRINCIPALS` block, with `SqlAgentRead` at :261 and the variable at :504, and the `OCUPILOT_ALLOW_TEST_PROVIDER` block at :643 and :649. `ui/tools/ci.test.mjs` checks both directions and is not edited.
- `ui/browser/agent-sql.browser-spec.mjs` and `turnprobe-spec.mjs` (`armProbeDefinition`, `scriptReply`, `runIris`, `requireFreeSlot`).

### Vendor (read only; `irislib/%DeepSee/`)

- `Query/Parser.cls`:
  - comments are dropped inside an unquoted token (:273-305; :291 keeps them inside `[...]`);
  - `%Tokenize` :99 is `[Internal]` and a pure lexer (inference: it reads the text and writes nothing);
  - `%PARM`'s `{…}` value is captured from the query text (:1301-1318).
- `Query/query.cls` `%ResolveNamedParm` :5154 runs `X "Set %text = …"` on that value (:5178-5181).
- `Query/constant.cls`: `%ProcessAxes` :75 resolves it at execute. `%GetType` :38 resolves it with no prepare guard (prepare-time: inference).
- The other four sinks:
  - `ComputedDimension/SQL.cls` :48-107 and `Base.cls` :500-503, :829, :917;
  - `ResultSet.cls` :1584, :1747, :1899 and :2050-2059.
- Stored text expands at prepare: `query.cls` :4507 and :4566, and `ResultSet.cls` :202 (`%ResolveVariablesInText`).

## Tasks & Acceptance

**Execution:**

- [ ] **Task 0 (re-anchor and measure; no product code).** First run `git rev-parse --show-toplevel` and confirm it is `/Users/jbrandt/git/OcuPilot/.worktrees/epic-20`.
  - **Re-anchor.** After 20.11, 20.32 and 20.33 merge into this branch, re-anchor every planned symbol above, `ReadTool`'s count, and `DeveloperFloor`'s `TOOLS`. Record whether 20.33 shipped `MdxConstructs` under the ruling's contract (its `AnalyticsMdx` tests hold the Spliced row's spellings). If it did, Task 1's detection bullet is a no-op.
  - **Contention.** Run `git diff --stat origin/feature/OCU-1_ocupilot-mvp...origin/OCU-1-epic23`. Any file this story edits beyond add-only lines goes to the lead before Task 1.
  - **Measure on `ocupilot-b-ci`**, removing what you create:
    1. how `%Tokenize` presents a single-quoted string token (with or without its quotes), for the quoted-string rule;
    2. whether `%PrepareMDX` alone of `WITH %PARM P AS 'VALUE:{$Increment(^OcuPilotProbeMdxSplice(352))}' SELECT @P ON 0 FROM [OcuPilotProbeVisits]` defines the node. Record the exact texts the tests use;
    3. the slow statement 20.33 recorded still runs at least 10 s.

    A measurement that contradicts this spec halts the stage with its evidence.
- [ ] **`src/OcuPilot/Port/AnalyticsPort.cls`** (extends 20.33's port):
  - **Detection (option A).** `MDXCONSTRUCTS` gains `%PARM`. `MdxConstructs(text, .found)` matches case-insensitively on the raw text, on the `%Tokenize` token values, and on each quoted string's tokens, recursing at most `MDXSTRINGDEPTH` (3) levels. It is pure and writes nothing, and `found` follows `MDXCONSTRUCTS` order.
  - **`MdxRun(ns, text, row, column, boundSeconds, stopClass, stopKey, .answer, .http, .fault)`.** 20.33's `Work` steps 1-3 move here, with one change: each pass asks `$ClassMethod(stopClass, "MdxStopRequested", stopKey)`. A stopped answer is `{outcome: "stopped", seconds}`, where `seconds` is the whole seconds it ran.
  - **`RefuseFor(which, .http, .fault)`** (public; sibling `SqlPort.RefuseFor`): `"sql"` builds 422 `ANALYTICS.MDX.SQL` from `AnalyticsError`.
  - **The class doc** names the 20.35 clause.
- [ ] **`src/OcuPilot/Api/AnalyticsError.cls`** (add): `MDXSQL` `"ANALYTICS.MDX.SQL"`, 422, with `REASONMDXSQL` (Design Notes › Strings). Add `ReasonFor(pCode)`, sibling of `InteropError.ReasonFor` :515, which answers every `ANALYTICS.*` reason.
- [ ] **`src/OcuPilot/Api/Error.cls`** (add-only): after :1235, `If $Extract(pCode, 1, 10) = "ANALYTICS." Set tReason = ##class(OcuPilot.Api.AnalyticsError).ReasonFor(pCode)`.
- [ ] **`src/OcuPilot/Area/Analytics/MdxQuery.cls`** (20.33): `Work` calls `AnalyticsPort.MdxRun`. Add `MdxStopRequested(pKey)`, which answers the run row's `GuardedCancelRequested`. Behavior is unchanged, and so are 20.33's tests.
- [ ] **`src/OcuPilot/Screen/Tool/ExplorerSqlRead.cls`**:
  - `MaskedRows` becomes public;
  - the credential-column scan at :207-221 becomes the public `RedactedColumns(columns, .masked) As %DynamicArray`, which `Projected` calls;
  - output is unchanged.
- [ ] **`src/OcuPilot/Screen/Tool/AnalyticsMdxRead.cls`** (new; sibling `ExplorerSqlRead`):
  - **Parameters:**
    - `TOOLNAME` `analytics.mdxquery.read`; `KIND` `read`;
    - `DESCRIPTORCLASS` `OcuPilot.Screen.Descriptor.AnalyticsMdxQuery`; `PORTCLASS` `OcuPilot.Port.AnalyticsPort`;
    - `DESCRIPTION` (Design Notes › Strings).
  - **`InputSchema`:**
    - `statement`: string, `maxLength` 100,000;
    - `drill`: object `{row, column}`, integers from 1 to `MDXMAXROWS` and from 1 to `MDXMAXCOLUMNS`, both required, `additionalProperties` false.
  - **`ResultSchema`:**
    - members `namespace`, `outcome` (enum `cells`, `rows`, `error`, `stopped`), `cube`, `columns` (string array), `rows` (an array of string arrays), `rowsAvailable`, `columnsAvailable`, `truncated`, `message`, `seconds`, `redactedColumns`, `rowsSent` and `truncatedFields`;
    - `required` `[namespace, outcome]`, closed.
  - **`PrivilegePairs`** goes through `Gate.RequiredPairs(DESCRIPTORCLASS)`. **`SecretArguments`** declares none.
  - **`View`.** It runs the Always order, then `MdxRun` with `BoundSeconds()` and `$ClassName()`, then `Projected`.
  - **`Projected(ns, answer)`** (public, so the test can drive it):
    - cells: `columns` is `[""]` followed by the column labels, and each row is `[label]` followed by its cells, each as text (`""` when empty). A query with no rows axis gives one row whose label is `""`.
    - `rows`: the columns and rows are masked through `ExplorerSqlRead.RedactedColumns` and `MaskedRows`.
    - `error` and `stopped` pass through.
  - **Seams.** `BoundSeconds()` answers `AnalyticsPort.#MDXSECONDS`. `MdxStopRequested(pKey)` answers 1 when `GuardedSignals` reads stop or abandon, or when the renewal is at least `Limits.#LEASESECONDS` old; for `""` it answers 0.
  - **The class doc** names AD-7, AD-24, AD-36, AD-39, AD-60 and AD-65.
- [ ] **`src/OcuPilot/Screen/Context.cls`** (doc comment only): replace :174-175's "a form page answers `[]`" with "a form page lists only the read tools bound to it (Stories 19.11 and 20.35)".
- [ ] **Server tests:**
  - **`Test/AnalyticsMdx.cls`** (20.33's port test; add-only methods): `MdxConstructs` finds every Spliced spelling and nothing in the Not-a-construct row. This applies only if Task 0 found these missing.
  - **`Test/AnalyticsMdxRoutes.cls`** (20.33; add-only): a `%PARM` statement and a comment-split `%SEARCH` each ask first, with nodes 353 and 354 undefined until confirmed. This applies under the same condition.
  - **`Test/AnalyticsMdxRead.cls`** (new; sibling `SqlAgentRead`; armed by `OCUPILOT_ALLOW_PRINCIPALS` and `OCUPILOT_ALLOW_TEST_PROVIDER`). Setup is `AnalyticsProbe`'s `Remove`, `Enable` and `Create` before all, then `Remove` and `Gone` after all. Its legs:
    - the Cells, Typed drill, Cell drill, Kind/axes, Syntax, No-analytics and Read-only rows;
    - the Spliced row, through `Test/AnalyticsMdxReadFixture` (new: `PORTCLASS` `Test/AnalyticsPortRecorder` (new; sibling `SqlPortFixture`), which counts `MdxPrepare` calls in `^||`);
    - `Projected` on a synthetic listing with a `Password` column;
    - MDX query's context lists `analytics_mdxquery_read`;
    - `Api.Error.ReasonForToolCode("ANALYTICS.MDX.SQL")` equals `REASONMDXSQL`;
    - **a real turn** (`turnprobe`, `/turn?ns=USER`): the Cells and Row cap reads are framed as data, and a `%PARM` call answers code `ANALYTICS.MDX.SQL`, with the step's `reason` equal to the sentence and node 355 undefined.
  - **`Test/AnalyticsMdxReadJob.cls`** (new; armed by `OCUPILOT_ALLOW_PRINCIPALS`):
    - Bound, through the fixture's `BoundSeconds()` of 2;
    - Stop: the test begins a turn (`Turn.GuardedBegin`, as `TurnToolsCase`:118 does), `Caller.Set`s it, and `JOB`s `NavSettleJob.StopAfter`.

    Each checks `stopped`, `%GetQueryStatus` 100, and no USER `%SYS.ProcessQuery` row whose `Routine` starts with `%DeepSee`.
  - **`Test/NavSettleJob.cls`**: add `StopAfter(pKey, pUser, pSeconds)`.
  - **`Test/AnalyticsMdxReadGate.cls`** (new; armed by `OCUPILOT_ALLOW_PRINCIPALS`): P1, P3 and P4 through 20.33's `AnalyticsMdxGate` principals and child-process probe (made reachable), with an op that calls `View` after `Scope.Set("USER")`.
  - **Rosters**, each name read from the instance:
    - `ReadTool`: count +1, and the name in sorted place;
    - `ToolRoundTrip` `REFUSEEMPTY`: `analytics.mdxquery.read:TOOL.ARGUMENTS`;
    - `ToolEmit`: the `ExplorerSqlRead` branch's condition admits `AnalyticsMdxRead`;
    - `DeveloperFloor` `TOOLS`: +1 when the developer principal holds the pairs.
- [ ] **`scripts/ci-throwaway.sh`**: add `# classes: AnalyticsMdxRead, AnalyticsMdxReadGate, AnalyticsMdxReadJob` to the PRINCIPALS block and `# classes: AnalyticsMdxRead` to the TEST_PROVIDER block.
- [ ] **Client (add-only):**
  - `ui/src/app/core/strings.ts` gets `analyticsMdxSqlReason`;
  - EXPERIENCE.md's Fixed strings gets one row;
  - `ui/tools/analytics.test.mjs` pins `REASONMDXSQL` to both;
  - then run `cd ui && npm run test:tools`.
- [ ] **`ui/browser/agent-mdx.browser-spec.mjs`** (new; sibling `agent-sql.browser-spec.mjs`). `before` refuses the live container, requires readiness and a free slot, and runs `AnalyticsProbe`. `after` removes it and arms nothing. Each leg carries its mutation comment, on `analytics/mdx-query?ns=USER`:
  - **AC1:** a scripted turn calls the read. The card shows the rows line and a probe category label.
  - **AC3:** a scripted `%PARM` call (node 356). The card reads "failed — " followed by `analyticsMdxSqlReason`, and `runIris` reads node 356 undefined.
  - **AC9:** `structural` with the refused card shown finds no fresh entry at 1280 light and 1280 dark.
- [ ] **Roster sweep (Rule 30).** Search `src/OcuPilot/Test`, `ui/tools`, `ui/browser` and the `ui/src` specs for the tool count, `REFUSEEMPTY`, `TOOLS`, `MdxConstructs`, `MDXCONSTRUCTS` and `MdxQuery.Work`. Each changed file joins `(loop)`.

**Acceptance Criteria:**

- **AC1 (the criterion: results within the caps; Integration).**
  - **Given** `AnalyticsProbe` in USER and a turn on USER.
  - **When** the turn calls `analytics_mdxquery_read` with a SELECT over `OcuPilotProbeVisits`, then with 2,000 grid members on rows.
  - **Then** the framed `tool_result` carries the vendor's labels and cells. The second carries `rowsSent` equal to the context row cap, `rowsAvailable` 2,000 and `truncated` true. The panel's card shows the rows line.
- **AC2 (drill-through within its cap).**
  - **Given** the cells statement.
  - **When** the read names a cell, or runs `DRILLTHROUGH`.
  - **Then** it answers the vendor's listing for that cell (or the statement), at most 1,000 rows, with credential-named columns redacted.
- **AC3 (refuses code; AD-60, AD-65).**
  - **Given** any Spliced spelling.
  - **When** the read is called, alone or in a turn.
  - **Then** it answers 422 `ANALYTICS.MDX.SQL` before anything is prepared, and the probe nodes stay undefined. The model receives the code, and the card shows the sentence.
- **AC4 (bound and Stop leave nothing running; AD-7).**
  - **Given** the slow query.
  - **When** the bound passes, or the person stops the turn.
  - **Then** the read answers `stopped`, the vendor reports the query finished, and no USER process runs DeepSee code.
- **AC5 (never a write).**
  - **Given** a CREATE, a DROP or three axes.
  - **When** the read is called.
  - **Then** it is refused by its code, nothing runs, and no `SqlRun` row is reserved.
- **AC6 (gate first; AD-29, AD-65).**
  - **Given** HSCUSTOM, HSLIB, P1, P3 or P4.
  - **When** the read is called.
  - **Then** each answer is the matrix row's. P1's refusal names `%DB_USER:WRITE`.
- **AC7 (rostered and reachable).**
  - **Given** the registry.
  - **When** the tool rosters derive.
  - **Then:**
    - `ReadTool`, `ToolRoundTrip`, `ToolEmit` and `DeveloperFloor` hold the tool;
    - MDX query's context lists it;
    - `SurfaceCoverage` stays green with no row for it.
- **AC8 (Integration: the extended siblings).**
  - **Given** `MdxRun` and the masking helpers.
  - **When** 20.33's screen runs and cancels, and the SQL read runs.
  - **Then** 20.33's job, routes and browser tests pass, and so do `SqlAgentRead` and `SqlCredentialMask`.
- **AC9 (structural).**
  - **Given** the refused card on MDX query.
  - **When** the structural check runs.
  - **Then** it finds no fresh entry in either theme.

## Spec Change Log

## Review Triage Log

## Design Notes

**Intent gap (blocking; for the lead and the orchestrator).**

- **Q1, blocking (AD-65, AD-60, AD-11 rule 2).** The chartered refusal is the four words matched as a case-insensitive substring through 20.33's `MdxConstructs`. It does not stop MDX text that runs ObjectScript:
  - **Evidence, measured on `ocupilot-b-ci` (2026-10-14).** `%DeepSee.Query.Parser.%Tokenize` reads `%SE/**/ARCH`, `%SQL/**/RESTRICT`, `RET/**/URN` and `%ORD/**/ER` as `%SEARCH`, `%SQLRESTRICT`, `RETURN` and `%ORDER`, because a comment inside a word is dropped (`Parser.cls`:273-305). A substring match misses all four. Whitespace splits the token, and brackets keep the comment literally.
  - **Evidence, from source, with the `X` measured.** `WITH %PARM P AS 'VALUE:{<ObjectScript>}'` followed by `@P` runs `X "Set %text = <ObjectScript>"` (`query.cls`:5178-5181), and it contains none of the four words. A `%ResolveNamedParm` call on such a value set a global on `ocupilot-b-ci`. It is reached at execute (`constant.cls`:75) and possibly at prepare (`%GetType` :38; inference).
  - **Evidence, from source.** Shared calculated members and named sets, named filters, term lists and pivot variables expand into a query from stores their authors write (`query.cls`:4507/4566, `ResultSet.cls`:202).
  - **Options:**
    - **A (recommended).** One detection, widened. `MdxConstructs` reads the raw text, the vendor's tokens and each quoted string's tokens, and `MDXCONSTRUCTS` gains `%PARM`. The screen asks first for all five, and the agent refuses all five. Stored definitions become a named limit beside `%KPI` and SQL computed dimensions, as their authors' code. The runner applies this to 20.33's plan (Size › seam 1) and to AD-65's splice clause. This spec is written under A.
    - **B.** A, and the read also refuses when the resolved text `%PrepareMDX` returns holds a construct. This closes the pivot-variable path for the four execute-time constructs, but not a `%PARM` arriving through a variable at prepare (inference). It needs one more Task 0 measurement.
    - **C.** As chartered, with the comment spellings and `%PARM` as named limits. This is not recommended: AD-11 assumes the model is compromised, so an injected call would run ObjectScript as the person, with no confirmation.
  - **If B or C is ruled,** the lead amends the intent contract's Spliced row and the detection bullet before re-dispatch.
- **Q2 (apply-and-report).** The charter's "SurfaceCoverage rows" cannot hold. Its tool half is write tools only (`Test/SurfaceCoverage.cls`:36, :655), and a read-tool row reddens it with "is not a write tool -- remove it" (:625). This story adds no screen. Recommended amendment: "its own `ReadTool`, `ToolRoundTrip`, `ToolEmit` and `DeveloperFloor` rows".

**Governing ADs (Rule 6).**

- AD-65: the port, the splice clause and its 20.35 clause.
- AD-60: one sanitizer, and a read never executes code.
- AD-36 and AD-39: what reaches the model. This is the 19.11 precedent widened.
- AD-24: the row cap, the per-reply total, and the screen's context `tools`.
- AD-7: synchronous in the turn job, never mutating of its own, with the vendor's cache as its cost shape.
- AD-29 and AD-8: gate first, with the screen's pairs.
- AD-11: untrusted cells and labels.
- AD-21: the statement is concatenated into nothing.
- AD-16: switched calls.
- AD-31 and AD-33: the lease and the stop signals.
- AD-64: the screen's adjustment applies to the tool through `RequiredPairs`.

Checked and not engaged:

- AD-6, AD-10, AD-15, AD-22 and AD-51 to AD-53: nothing writes.
- AD-41 and AD-42: no background run or spawn.
- AD-5 and AD-19: no screen or store.

**Decisions.**

- **Synchronous, with polling.** `%ExecuteAsynch`, polled by `MdxRun`, gives a bound and a cancel inside the turn job without `JOB` (checker Rule 19). No turn limit cuts a call short: the 600 s wall clock and the 120 s lease are checked only between steps. Polling the signals means the person's Stop reaches the call.
- **Bound.** The bound is `MDXSECONDS` (120), 20.33's cap as chartered.
- **Shape for the model.** One shape of arrays of text serves cells and listings, because the schema subset has no `anyOf`. `Bound` cuts `rows` by the row cap and the total. Cells are cut by the port at 1,000 characters, which stands for AD-24's per-field bound, as `SqlPort`'s cut does for Story 19.11.
- **The model sees the vendor's error text,** as 19.11's SQL read does. It is the agent's own statement echoed back through AD-60, and it is cut.
- **The refusal reaches the card.** The new `ANALYTICS.` branch makes the card show the sentence rather than the generic one.
- **No `maxRows` argument.** The row cap bounds `rows`, and the port reads at most `MDXMAXROWS`.
- **Declined:**
  - an `InjectionSeed` channel: AD-60 needs no change for a new read tool, and AC1's real turn asserts the framing;
  - the screen's prompts are unchanged.

**Named limits.**

- Stored definitions (option A), `%KPI`/`%LOOKUP`, SQL computed dimensions, a cube's listing SQL, and the vendor's `^DeepSee.InitCode`, `AuditCode`, `AuditQueryCode` and `CloseCode` run as the person. They are their authors' code, not the statement's.
- A bound or Stop cancels the vendor's shared key, so the same text running elsewhere stops too.
- A read started near the 600 s wall clock can overrun it by its bound (inference).
- A member name or cell that holds a secret reaches the model, as a SQL value under another name does.
- MDX writes the vendor's cache (AD-7, the 20.33 shape).

**Rule 31.**

- **Extended:** 20.33's loop becomes `AnalyticsPort.MdxRun`; `ExplorerSqlRead`'s masks; `AnalyticsError` with `ReasonFor` (sibling `InteropError`); `Api.Error`'s family branch; `NavSettleJob`; `ToolEmit`'s branch; 20.33's tests and principals; `turnprobe-spec.mjs`.
- **New siblings:** `AnalyticsMdxRead` follows `ExplorerSqlRead`, its test follows `SqlAgentRead`, `AnalyticsMdxReadJob` follows `AnalyticsMdxJob`, and the recorder follows `SqlPortFixture`.
- **Copy:** `MdxStopRequested` repeats three reads of `Loop.Boundary` (:422-460). `Boundary` needs the loop's arguments and writes the stopped step, while the hook only asks.

**Integration (Rule 1), Consumes, Consumed-by (Rule 2).**

- **Integration:**
  - AC1: the turn loop reads the tool and the model receives the framed answer;
  - AC3: the turn and the card receive the refusal;
  - AC8: `MdxQuery.Work` consumes `MdxRun`.
- **Consumes:**
  - from 20.33: `MdxAdmit`, `MdxConstructs`, `MdxPrepare`, `MdxStart`, `MdxStatus`, `MdxCancel`, `MdxDrill`, `MdxAnswer`, the `MDX*` caps, the descriptor, the principals, the grid cube and the splice node;
  - from 20.11: `AnalyticsPort`, `AnalyticsError`, `AnalyticsProbe` and `analytics.cubes.read`, which the description names;
  - from 19.11: the read pattern and the masks;
  - from 4.7: the stop helper.
- **Consumed-by:**
  - `MdxRun`: 20.33's screen. 20.34 may also use it (inference).
  - The read tool: 20.12's Investigate (inference).

**Ledger inbox (Rule 17):** none (`owned_ledger=0`).

**Rule 11.**

- **Epic 23** (`origin/OCU-1-epic23` at `e3c09eb16d1c7b2fad411efe42e9b426e7ea98d2`) touches client shell and Home files only, so there is no overlap.
- **Add-only edits:** `Test/ReadTool.cls`, `strings.ts`, EXPERIENCE.md and `Api/Error.cls`.
- **Unchanged:** `Test/SurfaceCoverage.cls`, `StageTwoTools`, `Screen/Registry.cls`, `Screen/Read.cls`, `Kernel/EntityType.cls` and `Prohibited.cls`.
- **Footprint extensions** (Rule 11 (b)): `Screen/Tool/ExplorerSqlRead.cls`, `Screen/Context.cls` (doc comment), `Api/Error.cls`, `Test/NavSettleJob.cls` and `scripts/ci-throwaway.sh`.

**Spine drafts (Rule 20; the lead writes them at the gate).**

- **AD-65:**
  - the splice clause takes the ruling: under A, five constructs, detected on the vendor's tokens and quoted strings, with stored definitions named;
  - a new 20.35 clause: "The agent's MDX read (`analytics.mdxquery.read`) runs in the turn job through `MdxRun`, under MDX query's pairs, `MdxAdmit` and the `MDX*` caps. It polls the vendor and the turn's stop, abandon and lease, reserves no background run, and refuses the constructs with `ANALYTICS.MDX.SQL`."
- **AD-36:** "The agent's MDX read is a read tool, not a declared read (Story 20.35). Its cells, labels, listing rows and error message reach the model through AD-60, bounded by the `MDX*` limits and AD-24, with listing columns named like credentials reading `[redacted]`. A person's MDX run stays screen-only."
- **AD-39:** the sixth exception adds "and the agent's own MDX read's (Story 20.35)".
- **AD-7:** "So does the agent's MDX read (Story 20.35), in the turn job. By OcuPilot's classification it never mutates."
- **AD-21:** the MDX clause adds "the agent's statement (Story 20.35) the same, with the constructs refused".
- **AD-24:** at origin, "(a form page declares neither, so its list is empty)" becomes "(a form page lists only the read tools bound to it: Stories 19.11 and 20.35)".

**Strings.**

- **`REASONMDXSQL` = `analyticsMdxSqlReason`:** "This query runs server-side code or SQL, which a read never runs; a person can run it on MDX query after confirming."
- **`DESCRIPTION`:** "Run one MDX query in the namespace this turn is scoped to, as the signed-in user, and read its cells, or with drill, one cell's listing. Send one SELECT (columns and rows at most) or DRILLTHROUGH; find cubes with analytics.cubes.read. Text that runs server-side code or SQL (%SEARCH, %SQLRESTRICT, RETURN, %ORDER, %PARM) is refused: ask the person to run it on MDX query. Listing columns named like a credential read [redacted]."

**Weight.** The initial bundle gains one literal and stays at about 1.96 MB (20.33's figure, inference), under the owner's fixed 2500 kB warning. There is no new lazy chunk.

**Size.** One story. Seam 1 (recommended under A): the detection widening and its 20.33 test legs land in 20.33's plan, so this story's first bullet and the conditional test legs become no-ops. A split needs the orchestrator's ruling.

## Verification

**Shared surfaces:**

- `ReadTool`'s count and names, `ToolRoundTrip`'s `REFUSEEMPTY`, `ToolEmit`'s branch, and `DeveloperFloor`'s `TOOLS`;
- MDX query's context `tools`;
- `MDXCONSTRUCTS` and 20.33's ask-first;
- `MdxQuery.Work`;
- `ExplorerSqlRead`'s masks;
- `Api.Error.ReasonForToolCode`;
- the arming rosters;
- the strings table and EXPERIENCE.md's Fixed strings;
- USER's analytics flags and `^OcuPilotProbeMdxSplice` while the probe runs.

*Every test added or changed passes on a fresh environment, in either order.* `AnalyticsProbe` creates and removes everything it asserts on. Each splice leg uses its own node, 351 to 356. The row-cap leg reads the cap at that moment.

**Setup (slot B; never the dev instance `ocupilot-slot-b`):**

- `(loop)` **Load `src`:**
  1. `rsync -a --checksum --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-20/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`
  2. Then, in `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`: `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)`.
- `(loop)` **Before a browser run:** `cd ui && npm run build && docker exec ocupilot-b-ci sh -c 'cd /durable/iris/csp/ocupilot && rm -rf ./*' && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`.

**Commands.** Run each in the foreground with `timeout: 600000`, one at a time, and read each class's result from `%UnitTest_Result`.

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.AnalyticsMdxRead --class OcuPilot.Test.AnalyticsMdxReadGate --class OcuPilot.Test.AnalyticsMdx`. Expected: green.
- `(loop)` The same runner, one class per call: `AnalyticsMdxReadJob`, then `AnalyticsMdxJob`, then `AnalyticsMdxRoutes`. Expected: green.
- `(loop)` The same runner, as one batch: `ReadTool`, `ToolRoundTrip`, `ToolEmit`, `DeveloperFloor`, `SurfaceCoverage`, `SqlAgentRead`, `SqlCredentialMask`, `ExplorerDescriptor`, `TurnNavigate`, `AnalyticsMdxDescriptor`, then each class the sweep changes. Expected: green.
- `(loop)` `cd ui && npm run test:tools`. Expected: green.
- `(loop)` `cd ui && npm run build -- --verbose`. Expected: the prebuild chain green, and the initial bundle about 1.96 MB, under 2500kB.
- `(loop)` `uv run scripts/check-objectscript.py <each changed .cls>`, then `uv run scripts/test_check_objectscript.py`, then `bash scripts/lint-docs.sh`. Expected: clean.
- `(loop)` `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/<file>`, one file per call, after the redeploy: `agent-mdx.browser-spec.mjs`, then `analytics-mdx.browser-spec.mjs`. Expected: green.
- **Lead-owned (the runner's):** the full ObjectScript sweep, `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`, and Rule 30's fresh check.
- **Left to CI:** the full browser suite.

**Planned pinning mutations (Rule 19).** Revert each one byte-identical. Reload, or rebuild and redeploy, the whole tree before the next.

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | `Projected` drops the label column | `AnalyticsMdxRead`'s cells and turn legs, and browser AC1 |
| AC2 | `MdxRun` ignores `drill` | `AnalyticsMdxRead`'s cell-drill leg |
| AC3 | `MdxConstructs` matches the raw text only | `AnalyticsMdxRead`'s comment-split legs |
| AC3 | `MDXCONSTRUCTS` loses `%PARM` | the `%PARM` legs (node 352 defined) and browser AC3 |
| AC3 | `View` prepares before `MdxConstructs` | the recorder leg |
| AC3 | `ReasonForToolCode` loses the `ANALYTICS.` branch | the reason leg and browser AC3 |
| AC4 | `MdxRun` ignores the deadline | `AnalyticsMdxReadJob`'s bound leg |
| AC4 | `MdxStopRequested` answers 0 | `AnalyticsMdxReadJob`'s Stop leg |
| AC5 | Kind accepts CREATE | `AnalyticsMdxRead`'s kind leg |
| AC6 | `View` skips `Screen.Gate.Evaluate` | `AnalyticsMdxReadGate` P4 |
| AC7 | The `ToolRoundTrip` row is removed | `ToolRoundTrip`, alone |
| AC8 | `Work` keeps its own loop, skipping `MdxStopRequested` | `AnalyticsMdxJob`'s cancel leg |
| AC9 | A pale color on the failed line | browser AC9 |

## Auto Run Result

Status: blocked
Blocking condition: intent gap (AD-65, AD-60, AD-11 rule 2). The chartered refusal does not stop MDX text that runs ObjectScript. That refusal is the four words `%SEARCH`, `%SQLRESTRICT`, `RETURN` and `%ORDER`, matched as a case-insensitive substring of the raw text through 20.33's `MdxConstructs`. It fails in two ways. First, the vendor's lexer drops a comment inside a word, so `%SE/**/ARCH` is read as `%SEARCH` (measured on `ocupilot-b-ci`). Second, `WITH %PARM P AS 'VALUE:{…}'` runs `X` on its braces (`query.cls`:5178-5181) and names none of the four words. Two rulings are needed. Q1: what the one detection covers. A is recommended: detect on the vendor's tokens and on each quoted string, and widen the set to `%SEARCH`, `%SQLRESTRICT`, `RETURN`, `%ORDER` and `%PARM`, with stored definitions as a named limit. Q2 (apply-and-report): the charter's `SurfaceCoverage` row cannot exist, because that roster's tool half is write-only.

The plan is fully drafted under option A, and Design Notes › Intent gap holds the evidence and options. Measured at plan time on `ocupilot-b-ci`: `%Tokenize` on the four comment-split spellings, with nothing created. The rest is from vendor source, and `%PARM`'s `X` was measured on `%ResolveNamedParm`, with its global killed afterwards. Once the ruling is made, reset `status` to `draft` (or validate as `ready-for-dev` if A is ruled) and apply Q2's amendment to the 20.35 block.
