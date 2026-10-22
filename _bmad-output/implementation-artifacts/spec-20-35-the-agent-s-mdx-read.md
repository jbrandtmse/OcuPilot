---
title: 'Story 20.35: The agent''s MDX read'
type: 'feature'
created: '2026-10-14'
status: 'done'
baseline_revision: '3d0323131ca3db453abb5e1193395de04c9f5dd5'
baseline_commit: '3d0323131ca3db453abb5e1193395de04c9f5dd5'
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
- It refuses with 422 `ANALYTICS.MDX.SQL` any statement in which `AnalyticsPort.MdxConstructs` finds text that runs server-side code or SQL, or which it cannot read: on the statement before anything is prepared, and on the variable-resolved text after prepare, before anything runs. That detection is the one the screen's ask-first uses. Under ruling Q1 B (Design Notes › Intent gap), it reads the vendor's own tokens and each string literal's, covers five constructs and fails closed.
- The run polls the vendor up to its time bound, and stops early on the person's Stop. A stopped run leaves nothing running.

## Boundaries & Constraints

**Always:**

- **Gate first (AD-29, AD-65).** Before any vendor call, in this order:
  1. the argument schema;
  2. MDX query's pairs (`Screen.Gate.Evaluate` on its descriptor, including AD-64's adjustment and the classic page's custom resource);
  3. `MdxAdmit` in the turn's namespace (`Kernel.Scope.Current()`);
  4. `MdxConstructs` on the statement;
  5. `MdxPrepare`, with its kind and axes refusals, then its `ask` on the variable-resolved text.

  A refusal names the failed pair.
- **The detection** (ruling Q1 B; Story 20.33's `MdxConstructs`, reused and never copied). It is case-insensitive and reads:
  - the vendor lexer's tokens, in which a comment inside a word is dropped as the vendor drops it and a bracketed name is unquoted;
  - the tokens of every string literal (`%MDX("…")`), read the same way to `MDXSTRINGDEPTH` levels; a single-quoted span (`WITH … AS '…'`) is already in the token stream.

  `MDXCONSTRUCTS` is `%SEARCH,%SQLRESTRICT,RETURN,%ORDER,%PARM`. It fails closed: a blank text, a text the lexer refuses, or a literal deeper than `MDXSTRINGDEPTH` is refused as if a construct were found. A statement refused on its own text is never prepared; one refused on its resolved text has been prepared, which executes nothing (measured by Story 20.33), and is never run. Stored definitions (shared calculated members, named filters) are a named limit the detector never reads (DW-2451).
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
- Production hands no pivot variables to `%PrepareMDX`: the tool's `Variables()` seam answers none, and only a test fixture overrides it. `CREATE`, `DROP` and three or more axes are refused.
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
| Spliced | Each of `%SEARCH`, `%SQLRESTRICT`, `RETURN`, `%ORDER BY` and `WITH %PARM P AS 'VALUE:{…}'` + `@P`, in mixed case; `/**/` inside each of the five words; `%SEARCH` split by a `--` and by a `//` line comment; `%SE/**/ARCH` inside a `%MDX("…")` literal and inside `WITH MEMBER … AS '…'`. Each `%SEARCH` spelling's braces define its own node (351 to 356), and the `%PARM` text names node 357 | Nothing is prepared (the recorder port saw no `MdxPrepare`), and every node stays undefined | 422 `ANALYTICS.MDX.SQL` |
| Unreadable | `SELECT FROM [OcuPilotProbeVisits` (an unterminated bracket the lexer refuses) | Nothing is prepared | 422 `ANALYTICS.MDX.SQL` |
| Resolved | Through the fixture whose `Variables()` hands `v` the `%SEARCH` text for node 358: a SELECT over `OcuPilotProbeVisits` `… WHERE $variable.v` | One prepare is recorded, nothing runs, and node 358 stays undefined | 422 `ANALYTICS.MDX.SQL` |
| Not a construct | `[%SE/**/ARCH]` as a bracketed name, or a plain SELECT | Detection finds none, and the statement proceeds to prepare | - |
| Kind / axes | `CREATE MEMBER …`, `DROP …`, or three axes | Nothing runs | 422 `ANALYTICS.MDX.KIND` / `ANALYTICS.MDX.AXES` |
| Syntax | `SELEKT FROM [OcuPilotProbeVisits]` | `{outcome: "error", message}` with the vendor's text, at most 1,000 characters | - |
| Bound | The slow grid query through the fixture whose `BoundSeconds()` is 2 | `{outcome: "stopped", seconds: 2}`. `%GetQueryStatus` reads 100, and no USER process runs `%DeepSee` code | - |
| Stop | The slow query, with the test's turn stop requested after 1 s | `stopped` within `MDXSETTLESECONDS` + 2 s, with the same checks | - |
| No analytics | Scope HSCUSTOM | No vendor call | 409 `ANALYTICS.NAMESPACE` |
| Read-only cache | Scope HSLIB | No vendor call | 409 `ANALYTICS.MDX.READONLY` |
| No WRITE | P1 (`%DB_USER:R`, `%Development:USE`) | Refused before any vendor call | 403 `AUTH.NOPRIVILEGE`, `failedPair` `%DB_USER:WRITE` |
| No pair | P4 (`%DB_USER:RW`, no `%Development`) | Refused | 403 naming `%Development:USE` |
| No SQL grant | P3 (RW, `%Development`, no SELECT on the source) drills a cell | `{outcome: "error", message}` carrying the vendor's SQLCODE -99 text | - |

</intent-contract>

## Code Map

All paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-20`. Line numbers were read at `c079f81c86bf8473a7398ce26793329c96646576`. Stories 20.11, 20.32 and 20.33 land first; their symbols are marked **(20.11, planned)** and **(20.33, planned)**, and Task 0 re-anchors them.

### The sibling: the agent's SQL read (Story 19.11)

- **`src/OcuPilot/Screen/Tool/ExplorerSqlRead.cls`** (257 lines): `TOOLNAME` :28, `KIND` :30, `DESCRIPTION` :32, `DESCRIPTORCLASS` :35, `PORTCLASS` :39 (a fixture seam), `MASK` :45; `InputSchema` :49, `PrivilegePairs` :63 (`Screen.Gate.RequiredPairs`), `SecretArguments` :70, `ResultSchema` :80; `View` :117 (arguments again :125, the screen gate :131-137, the namespace from `Kernel.Scope.Current()` :148, port calls through `$ClassMethod(tPort, …)`); private `Projected` :191, whose credential-column scan is :207-222; private `MaskedRows` :230.
- **`Screen/Tool/Base.cls`**: `ArgumentsRefusal` :146, `InternalRefusal` :158. **`Screen/Tool/Registry.cls`**: `ToolClasses` :797-837 leaves out `OcuPilot.Test.*`, so a fixture subclass is never registered; `SchemaProblem` :862 admits no `anyOf`; the listing cache rebuilds on the compile signature.
- **`Screen/Context.cls` `ScreenTools`** :179 lists every advertised read tool bound to a screen (:193-199), but its doc at :174-175 says a form page answers `[]`.
- **Dispatch and bounds:** `Kernel/Agent/Dispatch.cls` runs `Bound` when the result has a `rows` array (:334-343), else `Capped` :792; `ErrorContent` :753 sends `{code, detail}`, never the reason. `Kernel/Agent/Bound.cls` keeps a payload's own larger `rowsAvailable` (:40-41), cuts rows by the row cap and the total, and cuts fields only in object rows, so arrays of text pass uncut. The AD-60 sanitizer runs in `Kernel/Agent/Loop.cls` :733.
- **Turn signals:** `Loop.Boundary` :417-460 reads stop, abandon and the lease (`$Parameter(tLimits, "LEASESECONDS")` :460; `Limits.cls` :25, 120) only between steps. `Kernel/State/Turn.cls`: `GuardedBegin` :325, `GuardedRequestStop` :438, `GuardedSignals` :507. `Kernel/Proposal/Caller.cls`: `Set` :20, `TurnKey` :26 (`""` outside a turn).
- **The card:** `Api/Error.cls` `ReasonForToolCode` :1211; the family branches end at `WALLETRUNG.` :1242; the sibling `Api/InteropError.cls` `ReasonFor` :590. `ui/src/app/shell/tool-call-card.ts` shows the failed line and the rows line.
- **The checker:** `scripts/check-objectscript.py` `API_REACH_PREFIXES` :915 and :953-959 refuse any `OcuPilot.Api.*` but `Api.Error` under `Screen/Tool/`. `Port/SqlPort.cls` `RefuseFor` :1226 is how a tool gets a fault.

### Analytics (planned; spec-20-33 cycle 3)

- **`src/OcuPilot/Port/AnalyticsPort.cls` (20.11, 20.33, planned):** 20.11's `Admit`, private `Deny`, `Refuse` and `Conflict`, the `<PROTECT>` mapping; 20.33's `MDXPAIRS`, the `MDX*` limits, `MDXCONSTRUCTS`, `MDXSTRINGDEPTH`, `MDXCONSEQUENCE`, `MdxAdmit(ns)`, `MdxConstructs(text, .found, .unread)`, `MdxPrepare(ns, text, .rs, .answer, .http, .fault, .ask, .found, .variables)`, `MdxStart`, `MdxStatus`, `MdxCancel`, `MdxDrill`, `MdxAnswer(ns, rs, seconds)` (spec-20-33 :217-234). Every vendor call switches namespace by save and restore and calls no `OcuPilot.*` class while switched.
- **`Api/AnalyticsError.cls` (20.11, 20.33, planned):** `NAMESPACE` and the eight `MDX*` codes, no `MDXSQL` (spec-20-33 :216).
- **`Area/Analytics/MdxQuery.cls` (20.33, planned):** `Work`'s run loop, steps 1-3, and the seams `BoundSeconds()` and `Variables()` (spec-20-33 :251-256).
- **`Screen/Descriptor/AnalyticsMdxQuery.cls` (20.33, planned):** a `form-page` with no read, `toolIdentifier` `analytics.mdxquery`, `privileges` `[%DeepSee_Portal:USE, %Development:USE]`.
- **Tests (planned):** 20.11's `AnalyticsProbe` (`Enable`, `Create("_SYSTEM")`, `Remove`, `Gone`) and `AnalyticsGate`; 20.33's grid cube, slow query, `^OcuPilotProbeMdxSplice` (nodes 1-5 and 10 are 20.33's), `AnalyticsMdx`, `AnalyticsMdxJob`, `AnalyticsMdxRoutes`, `AnalyticsMdxGate` (P1, P3, P4), `AnalyticsMdxDescriptor`, `AnalyticsMdxFixture`; 20.11's `ui/tools/analytics.test.mjs` and 20.33's `ui/browser/analytics-mdx.browser-spec.mjs`.

### Tests and rosters to extend

- `Test/SqlAgentRead.cls` (arming :18-20 and :59; `Scope.Set`/`Clear` :95, :102, :162-168; the real-turn pattern `TestATurnReadsRowsFramedAsData` :299-336) and `Test/SqlCredentialMask.cls` :135.
- `Test/ReadTool.cls` :93 (the count, 392 at this commit) and :94 (the sorted names).
- `Test/ToolRoundTrip.cls` `REFUSEEMPTY` :96.
- `Test/ToolEmit.cls` `TestEveryLiveToolRequiresItsScreensPairs` :158: the `ExplorerSqlRead` branch :380, and :412 fails a tool of an unknown source.
- `Test/DeveloperFloor.cls` `TOOLS` :41, compared at :499 ("forty-seven").
- `Test/NavSettleJob.cls` `StopWhenPending` :35; `Test/TurnToolsCase.cls` :118 (`Turn.GuardedBegin`).
- `Test/SurfaceCoverage.cls` :627 reddens a read tool given a row ("… -- remove it").
- `scripts/ci-throwaway.sh`: the `OCUPILOT_ALLOW_PRINCIPALS` `classes:` lines (`SqlAgentRead` :261, the variable :511) and the `OCUPILOT_ALLOW_TEST_PROVIDER` block (:651, :657).
- `ui/browser/agent-sql.browser-spec.mjs` and `turnprobe-spec.mjs` (`armProbeDefinition`, `scriptReply`, `runIris`, `requireFreeSlot`). `ui/tools/self-protection.test.mjs` :643 pins `REASONSQLCHANGES` to `explorerSqlChangesReason`, the shape of this story's pin.

### Vendor (read only; measured by Story 20.33, spec-20-33 :453-462)

- `Query/Parser.cls` `%Tokenize` :99 drops a comment inside an unquoted word and refuses an unterminated `[` or `"`; `ResultSet.cls` `%PrepareMDX` :159 returns the resolved text as its third argument and executes no `%SEARCH`; a braced `%PARM` fails prepare on this build.

## Tasks & Acceptance

**Execution:**

- [x] **Task 0 (re-anchor and measure; no product code).** Run `git rev-parse --show-toplevel` and confirm `/Users/jbrandt/git/OcuPilot/.worktrees/epic-20`.
  - **Re-anchor** every planned symbol above after 20.11, 20.32 and 20.33 merge, plus `ReadTool`'s count and names, `DeveloperFloor`'s `TOOLS` and `REFUSEEMPTY`.
  - **Confirm the detector.** 20.33 shipped `MdxConstructs(text, .found, .unread)` and `MdxPrepare`'s `ask`, `found` and `variables` as its cycle 3 spec says, with `AnalyticsMdx`'s obfuscation and fail-closed cases green. If it did not, halt to the lead with the evidence: this story builds no copy.
  - **Contention.** Run `git diff --stat origin/feature/OCU-1_ocupilot-mvp...origin/OCU-1-epic23`. A file this story edits beyond add-only lines goes to the lead before Task 1.
  - **Measure on `ocupilot-b-ci`**, removing what you create: the slow statement 20.33 recorded still runs at least 10 s through `MdxRun`; record each test text and its node.

  A measurement that contradicts this spec halts the stage with its evidence.
- [x] **`src/OcuPilot/Port/AnalyticsPort.cls`** (extends 20.33's port):
  - **`MdxRun(ns, rs, row, column, boundSeconds, stopClass, stopKey, .answer, .stopped, .http, .fault)`.** 20.33's `Work` steps 1-3 move here unchanged but for the hook: each 0.1 s pass calls `MdxStatus`, then, unswitched (AD-16), `$ClassMethod(stopClass, "MdxStopRequested", stopKey)`. At the bound or on the hook it calls `MdxCancel`, waits up to `MDXSETTLESECONDS` for 100, answers `{outcome: "stopped", seconds}` (whole seconds run), and sets `stopped` to `"bound"` or `"request"` (else `""`). A drill's listing call keeps 20.33's `$System.Alarm` bound.
  - **`RefuseFor(which, .http, .fault)`** (public, over the private `Refuse`; sibling `SqlPort.RefuseFor` :1226): `"sql"` builds 422 `ANALYTICS.MDX.SQL`, and `"input"` 400 `ANALYTICS.MDX.INPUT` (a drill of a statement whose answer has no cells).
  - **The class doc** names the 20.35 clause.
- [x] **`src/OcuPilot/Api/AnalyticsError.cls`** (add): `MDXSQL` `"ANALYTICS.MDX.SQL"`, 422, with `REASONMDXSQL` (Design Notes › Strings), and `ReasonFor(pCode)`, sibling of `InteropError.ReasonFor` :590, answering every `ANALYTICS.*` reason (extend it if 20.33 added one).
- [x] **`src/OcuPilot/Api/Error.cls`**: no edit; Story 20.33 shipped the `ANALYTICS.` branch of `ReasonForToolCode` and `AnalyticsError.ReasonFor`.
- [x] **`src/OcuPilot/Area/Analytics/MdxQuery.cls`** (20.33): `Work` calls `AnalyticsPort.MdxRun` with `$ClassName()` and the run key; `stopped` `"request"` ends `canceled`, `"bound"` ends `stopped`. Add `MdxStopRequested(pKey)`, answering `SqlRun.GuardedCancelRequested`. Behavior and 20.33's tests are unchanged.
- [x] **`src/OcuPilot/Screen/Tool/ExplorerSqlRead.cls`**: `MaskedRows` becomes public; the scan at :207-222 becomes the public `RedactedColumns(columns, .masked) As %DynamicArray`, which `Projected` calls. Output is unchanged.
- [x] **`src/OcuPilot/Screen/Tool/AnalyticsMdxRead.cls`** (new; sibling `ExplorerSqlRead`):
  - **Parameters:** `TOOLNAME` `analytics.mdxquery.read`; `KIND` `read`; `DESCRIPTORCLASS` `OcuPilot.Screen.Descriptor.AnalyticsMdxQuery`; `PORTCLASS` `OcuPilot.Port.AnalyticsPort`; `DESCRIPTION` (Design Notes › Strings).
  - **`InputSchema`:** `statement` (required string, `maxLength` 100,000); `drill`, a bare object (an advertised schema admits no nested `properties`, which refused every turn when tried) whose `row` and `column` are whole numbers from 1 to `MDXMAXROWS` and from 1 to `MDXMAXCOLUMNS`, both required and nothing else, checked by the public `DrillProblem` before the gate (400 `TOOL.ARGUMENTS`).
  - **`ResultSchema`:** `namespace`, `outcome` (enum `cells`, `rows`, `error`, `stopped`), `cube`, `columns` (strings), `rows` (arrays of strings), `rowsAvailable`, `columnsAvailable`, `truncated`, `message`, `seconds`, `redactedColumns`, `rowsSent` and `truncatedFields`; `required` `[namespace, outcome]`, closed.
  - **`PrivilegePairs`** through `Gate.RequiredPairs(DESCRIPTORCLASS)`; **`SecretArguments`** declares none.
  - **`View`.** The Always order, every port call through `$ClassMethod(..#PORTCLASS, …)`: `MdxConstructs` answering 1 is `RefuseFor("sql")`; `MdxPrepare` with `..Variables()`, whose error answer returns 200 with `namespace`, and whose `ask` 1 is `RefuseFor("sql")`; then `MdxRun` with `..BoundSeconds()`, `$ClassName()` and `Caller.TurnKey()`; then `Projected`.
  - **`Projected(ns, answer)`** (public): cells give `columns` `[""]` then the column labels, and each row `[label]` then its cells as text (`""` when empty), one row labeled `""` when there is no rows axis; `rows` are masked through `ExplorerSqlRead.RedactedColumns` and `MaskedRows`; `error` and `stopped` pass through.
  - **Seams:** `BoundSeconds()` answers `AnalyticsPort.#MDXSECONDS`; `Variables(.variables)` answers none; `MdxStopRequested(pKey)` answers 1 when `GuardedSignals` reads stop or abandon, the renewal is at least the limits class's `LEASESECONDS` old or absent, or the signals cannot be read (as `Loop.Boundary` stops), and 0 for `""`.
  - **The class doc** names AD-7, AD-24, AD-36, AD-39, AD-60 and AD-65.
- [x] **`src/OcuPilot/Screen/Context.cls`** (doc only): :174-175's "a form page … answers `[]`" becomes "a form page lists only the read tools bound to it (Stories 19.11 and 20.35)".
- [x] **Server tests** (each probe class: `AnalyticsProbe` `Remove`, `Enable`, `Create` before all; `Remove` and `Gone` after all; each splice leg its own node):
  - **`Test/AnalyticsMdxRead.cls`** (new; sibling `SqlAgentRead`; armed `OCUPILOT_ALLOW_PRINCIPALS`): the Cells, Typed drill, Cell drill, Kind/axes, Syntax, No-analytics and Read-only rows; the Spliced, Unreadable, Resolved and Not-a-construct rows through `Test/AnalyticsMdxReadFixture` (asserting the recorder's prepare count and each node); `Projected` on a synthetic listing with a `Password` column; MDX query's context lists `analytics_mdxquery_read`; `Api.Error.ReasonForToolCode("ANALYTICS.MDX.SQL")` equals `REASONMDXSQL`.
  - **`Test/AnalyticsMdxReadFixture.cls`** (new; extends the tool): `PORTCLASS` `OcuPilot.Test.AnalyticsPortRecorder`, `BoundSeconds()` 2, `Variables()` handing `v` the node-358 `%SEARCH` text.
  - **`Test/AnalyticsPortRecorder.cls`** (new; sibling `SqlPortFixture`): counts `MdxPrepare` calls in `^||OcuPilotMdxPrepares`, then calls the port's own.
  - **`Test/AnalyticsMdxReadTurn.cls`** (new; armed `OCUPILOT_ALLOW_PRINCIPALS` and `OCUPILOT_ALLOW_TEST_PROVIDER`; the `SqlAgentRead` :299-336 pattern, `/turn?ns=USER`): the Cells and Row cap reads arrive framed as data; a `%SEARCH` call (node 359) answers code `ANALYTICS.MDX.SQL`, the step's `reason` is the sentence, and the node stays undefined.
  - **`Test/AnalyticsMdxReadJob.cls`** (new; armed `OCUPILOT_ALLOW_PRINCIPALS`; sibling `AnalyticsMdxJob`): Bound through the fixture; Stop with a turn begun (`Turn.GuardedBegin`, as `TurnToolsCase` :118), `Caller.Set`, and `JOB` `NavSettleJob.StopAfter`. Each checks `stopped`, `%GetQueryStatus` 100, and no USER `%SYS.ProcessQuery` row whose `Routine` starts with `%DeepSee`.
  - **`Test/NavSettleJob.cls`**: add `StopAfter(pKey, pUser, pSeconds)` beside `StopWhenPending` :35.
  - **`Test/AnalyticsMdxReadGate.cls`** (new; armed `OCUPILOT_ALLOW_PRINCIPALS`): P1, P3 and P4 on `AnalyticsMdxGate`'s principals (read from its parameters), through a child-process probe of its own after `AnalyticsGate`'s (`AnalyticsMdxGate` has none), which calls `View` after `Scope.Set("USER")`; plus an AD-64 adjustment leg.
  - **Rosters**, each name read from the instance: `Test/ReadTool.cls` :93-94 (+1, the name in sorted place); `Test/ToolRoundTrip.cls` `REFUSEEMPTY` gains `analytics.mdxquery.read:TOOL.ARGUMENTS`; `Test/ToolEmit.cls` :380's condition admits `OcuPilot.Screen.Tool.AnalyticsMdxRead`; `Test/DeveloperFloor.cls` `TOOLS` +1 (20.33 puts MDX query in `SCREENS`, so the developer holds its pairs) and :499's count.
- [x] **`scripts/ci-throwaway.sh`**: a PRINCIPALS `# classes: AnalyticsMdxRead, AnalyticsMdxReadGate, AnalyticsMdxReadJob, AnalyticsMdxReadTurn` line and a TEST_PROVIDER `# classes: AnalyticsMdxReadTurn` line.
- [x] **Client (add-only):** `ui/src/app/core/strings.ts` `analyticsMdxSqlReason`; one Fixed strings row in `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`; `ui/tools/analytics.test.mjs` pins `REASONMDXSQL` to both; then `cd ui && npm run test:tools`.
- [x] **`ui/browser/agent-mdx.browser-spec.mjs`** (new; sibling `agent-sql.browser-spec.mjs`). `before` refuses the live container, requires readiness and a free slot, and runs `AnalyticsProbe`; `after` removes it and asserts `Gone`. On `analytics/mdx-query?ns=USER`, each leg with its mutation comment:
  - **AC1:** a scripted turn calls the read; the card shows the rows line and a probe category label.
  - **AC3:** a scripted `%SEARCH` call (node 360); the card reads "failed — " then `analyticsMdxSqlReason`, and `runIris` reads node 360 undefined.
  - **AC9:** `structural` with the refused card shown finds no fresh entry at 1280 light and 1280 dark.
- [x] **Roster sweep (Rule 30).** Search `src/OcuPilot/Test`, `ui/tools`, `ui/browser` and the `ui/src` specs for the tool count, `REFUSEEMPTY`, `TOOLS`, `MdxQuery.Work`, `MaskedRows` and `analytics_mdxquery`. Each changed file joins `(loop)`.

**Acceptance Criteria:**

- **AC1 (the criterion: results within the caps; Integration).** **Given** `AnalyticsProbe` in USER and a turn on USER, **when** the turn calls `analytics_mdxquery_read` with a SELECT over `OcuPilotProbeVisits`, then with 2,000 grid members on rows, **then** the framed `tool_result` carries the vendor's labels and cells; the second carries `rowsSent` equal to the context row cap, `rowsAvailable` 2,000 and `truncated` true; the panel's card shows the rows line.
- **AC2 (drill-through within its cap).** **Given** the cells statement, **when** the read names a cell or runs `DRILLTHROUGH`, **then** it answers the vendor's listing for that cell (or the statement), at most 1,000 rows, credential-named columns redacted.
- **AC3 (refuses code, fail closed; AD-60, AD-65).** **Given** any Spliced spelling, the Unreadable text or the Resolved statement, **when** the read is called, alone or in a turn, **then** it answers 422 `ANALYTICS.MDX.SQL`, before any prepare for the first two and after a prepare that runs nothing for the third, and every probe node stays undefined; the model receives the code and the card shows the sentence.
- **AC4 (bound and Stop leave nothing running; AD-7).** **Given** the slow query, **when** the bound passes or the person stops the turn, **then** the read answers `stopped`, the vendor reports the query finished, and no USER process runs DeepSee code.
- **AC5 (never a write).** **Given** a CREATE, a DROP or three axes, **when** the read is called, **then** it is refused by its code, nothing runs, and no `SqlRun` row is reserved.
- **AC6 (gate first; AD-29, AD-65).** **Given** HSCUSTOM, HSLIB, P1, P3 or P4, **when** the read is called, **then** each answer is the matrix row's, and P1's refusal names `%DB_USER:WRITE`.
- **AC7 (rostered and reachable).** **Given** the registry, **when** the tool rosters derive, **then** `ReadTool`, `ToolRoundTrip`, `ToolEmit` and `DeveloperFloor` hold the tool, MDX query's context lists it, and `SurfaceCoverage` stays green with no row for it.
- **AC8 (Integration: the extended siblings).** **Given** `MdxRun` and the masking helpers, **when** 20.33's screen runs and cancels and the SQL read runs, **then** 20.33's job, routes and browser tests pass, and so do `SqlAgentRead` and `SqlCredentialMask`.
- **AC9 (structural).** **Given** the refused card on MDX query, **when** the structural check runs, **then** it finds no fresh entry in either theme.

- [x] **DW-2490 (ledger; routed by Story 20.33's review, 2026-10-21; unverified):** `MdxStatus` reads the vendor's status 100 as done without its pending-results flag, so a plugin-computed cell may be read before it is computed. This story polls `MdxStatus` too. Measure it first: run a statement over a `%KPI("%DeepSee.Median")` measure through the run and read its cell at the first status 100. If the cell can be read before it is computed, honor the pending flag in `MdxStatus` and pin it with a demonstrated mutation. If it cannot, record the measurement under `## Verification`, and the lead closes the entry at adjudication.

### Review Findings

Code review, 2026-10-21 (four layers on the full-opus tier, diff `3d032313` to the working tree; each patch verified on `ocupilot-b-ci`, mutations in Verification).

- [x] [Review][Patch] MED: after a bound or a Stop, `Settle` waited on `MdxStatus`, which now updates a plug-in's pending cells and answers 99, while the vendor's `%CancelQuery` returns at once for a query it already reports 100; a Stop or the bound in the pending phase waited up to `MDXSETTLESECONDS` while the cells went on computing, for the read and for MDX query's Cancel. `Settle` now reads the vendor's own status (`MdxStatus(..., 0)`) [src/OcuPilot/Port/AnalyticsPort.cls:1330]
- [x] [Review][Patch] MED (Rule 19, hermeticity): the read-level Stop leg posted its stop on a fixed one-second timer, and a stop that lands before `MdxStart` ends the read unstarted, so `VendorStatus` reads 0 on correct code; QA's turn Stop leg waited for any `%DeepSee` process in USER, which the turn job's own prepare satisfies. Both now wait until the vendor reports the query started (status 10 to 99) [src/OcuPilot/Test/NavSettleJob.cls:56]
- [x] [Review][Patch] The hook leg's never-renewed assertion ran with the stop signal set, so it could not fail; it now runs before the stop is requested [src/OcuPilot/Test/AnalyticsMdxReadJob.cls:173]
- [x] [Review][Patch] `columnsAvailable`'s description did not say the label column is not counted, while `columns` carries it [src/OcuPilot/Screen/Tool/AnalyticsMdxRead.cls:121]
- [x] [Review][Patch] `ToolRoundTrip`'s `REFUSEEMPTY` doc block had no line for this story's row [src/OcuPilot/Test/ToolRoundTrip.cls:98]
- [x] [Review][Patch] The browser AC9 leg's mutation comment named the contrast mutation only, not the wrap rules' [ui/browser/agent-mdx.browser-spec.mjs:214]
- [x] [Review][Defer] The stop hook reads no kill switch, enforced read-only or privilege, so those act at the next step [src/OcuPilot/Screen/Tool/AnalyticsMdxRead.cls:252] — deferred: DW-2494, by-design (AD-30 re-reads them between steps; the Seams bullet names stop, abandon and lease)
- [x] [Review][Defer] One `ANALYTICS.MDX.SQL` with no detail answers a construct, an unreadable text and a blank one alike [src/OcuPilot/Screen/Tool/AnalyticsMdxRead.cls:185] — deferred: DW-2495, by-design (ruling Q1 B and Design Notes › Strings fix the refusal and the description)
- [x] [Review][Defer] Rule 2: the `Screen.Gate.Evaluate` refusal block is its third copy, beside `ExplorerSqlRead` and `ExplorerSourceRead` [src/OcuPilot/Screen/Tool/AnalyticsMdxRead.cls:171] — deferred: DW-2496, wontfix-accepted (the sibling's six-line idiom; unifying it edits `Base.cls` and two other tools)

Rejected:

- `low`: one `%UpdatePendingResults` pass runs with no alarm, so a large plug-in answer can overrun the bound by a pass -- the vendor's own synchronous execute loops the same call, an alarm inside the vendor's update could lose a cell (inference), and the Auto Run Result's residual risk names it; the fix adds an alarm path.
- `low`: a pending plug-in cell that never completes keeps `MdxStatus` at 99 until the bound -- `%GetKPIValue` answers a plug-in's error as the cell's value with `$$$OK` (`%DeepSee.AbstractKPI`), which clears the pending node; only a lost KPI agent leaves it, and the read still ends at its bound.
- `low` (maybe-false): a stopped plug-in read leaves the KPI's queued `COMPUTEKPI` task running on the vendor's agents -- that task group is the vendor's, outside the query's own groups, MDX query's Cancel left it the same before this story, and `%KPI` is a named limit; it would only be low.
- `low`: an exception in the poll loop unwinds `MdxRun` without canceling the vendor's query -- `MdxStatus` traps its errors and both hooks read through status-returning guarded methods; unlikely, and the fix adds a guard.
- `low`: the stop hook reads `Limits.#LEASESECONDS` where `Loop.Boundary` reads its overridable `LimitsClass()` -- equal in production; only a test limits class tells them apart.
- `false`: a typed DRILLTHROUGH's start and a listing's read do not poll Stop -- Design Notes names it a limit and `MdxRun`'s doc says so; the bound's alarm ends both.
- `false`: the failed-card wrap rules change every failed card with no DESIGN.md amendment and no Shared surfaces entry -- DESIGN.md's `tool-call-card` (status at the right, label type) still holds and says nothing of a long reason's overflow, which every failed card had; the specs that read the warning status (`proposal-privilege`, `auditing-write`, `users-write`, `proposal-demo`, `refused-tool`, `turn`) assert its text, never its geometry; the Auto Run Result reports the file.
- `false`: a bound stop answers the bound, not the seconds run -- at the bound they are equal to the poll's tenth of a second, and the matrix's Bound row pins `seconds: 2`, as 20.33's run answers.
- `false`: the EXPERIENCE.md sentence joined the shared Fixed strings row, not a new row -- it is in Fixed strings, in the row 20.33's MDX strings and `strings.ts`'s `EXPERIENCE.md:604` citations name.
- `low`: the intent's "new `ANALYTICS.` branch" and Rule 11's `Api/Error.cls` entries, the Change Log's missing Tasks rewrites, the Auto Run Result's pre-QA counts, and the Tasks bullet's "whole seconds run" for a bound stop -- the fix is a spec edit.

## Spec Change Log

- 2026-10-15, lead: the orchestrator ruled Q1 (B, fail closed): 20.33's `MdxConstructs` reads tokens and quoted strings' tokens, covers the four plus `%PARM`, runs again on the variable-resolved text after prepare, and fails closed (the agent refuses with `ANALYTICS.MDX.SQL`); this story reuses it and builds no copy; stored definitions are a named limit (DW-2451). Q2 applied: no `SurfaceCoverage` row (that roster compares write tools only); `ReadTool`, `ToolRoundTrip`, `ToolEmit` and `DeveloperFloor` carry the tool. Back to `draft` for a re-plan after 20.33's amendment.
- 2026-10-15, spec gate (runner, cycle 2): the plan's intent-contract edits carry ruling Q1 B and are accepted as written (Approach bullet 2, the gate steps and detection bullet, the pivot-variable Never bullet, the Spliced, Unreadable, Resolved and Syntax rows); the spine carries the Story 20.35 clauses (AD-65, AD-36, AD-39, AD-7, AD-21, and AD-24 corrected at origin).

- 2026-10-21, implement (slot B): `drill` made a bare object (the emitted subset admits no nested `properties`), `Api.Error` left unedited (shipped by 20.33), and the mutation table replaced with the demonstrated one (AC6 and AC8 rows corrected).

## Review Triage Log

### 2026-10-21 -- Review pass

- verdicts: 21 findings (the verification-gap layer 9, the intent-alignment layer 11, the lead's own read 1) -- high 0, medium 0, low 12, false 9, maybe-false 0
- findings:
  - `[low]` `[patch]` `DrillProblem`'s integer, type and maximum branches have no test -- real: the drill cases sent only a missing column, a row of 0 and a stray key. Fixed: `TestTheArgumentsAreValidatedFirst` gains 1.5, `"1"`, and a row and a column one above the port's caps (derived from the port); removing the integer and maximum checks reddens that test alone, and the tool file's blob hash is identical after the revert.
  - `[low]` `[reject]` `MdxStatus`'s pending update runs outside the bound and Stop, and its error branch is untested -- measured on `ocupilot-b-ci`: one pass over 2,000 `%DeepSee.Median` cells of the 50,000-fact grid took 1.11 s (6.4 s from start to status 100), so a bound or Stop waits one pass; the vendor's own synchronous execute loops the same call, and a plug-in's code is the person's, a named limit. A seam for the error branch costs more than the branch.
  - `[low]` `[reject]` AC6's HSCUSTOM and P4 legs, and AC7's context-listing leg, have no mutation of their own -- Rule 19 asks one demonstrated mutation per AC: AC6 has three (`Evaluate`, the cache WRITE check, the read-only check) and AC7 has the roster row. Skipping `View`'s `MdxAdmit` would prepare the HSCUSTOM statement and redden the recorder count; the P4 test's header says why no single mutation reddens it (two layers refuse).
  - `[low]` `[patch]` AC9's mutation row pins contrast, not the wrap rules the story added -- real: the shared card's rules had no mutation of their own. Fixed: the wrap rules were removed, the bundle rebuilt and redeployed, and browser AC9 went red (`474px past its containing block`); reverted (blob hash identical), rebuilt and redeployed, green. The row is in `## Verification`.
  - `[low]` `[reject]` The Stop leg is armed by a fixed one-second timer on a hand-built turn -- the matrix row says "requested after 1 s"; either landing (before the start, or in the poll) ends `stopped` with seconds below the bound, nothing running, and `AnalyticsMdxJob`'s cancel legs pin the shared loop.
  - `[low]` `[reject]` `MdxStopRequested`'s unreadable-signal branch is untested -- reaching it needs a broken turn store; the branch copies `Loop.Boundary`'s stop on a failed read, and a seam costs more than the branch.
  - `[low]` `[reject]` The blank statement's "before the gate" ordering is not pinned -- moot: the blank pre-check was removed (see the intent-alignment blank row).
  - `[low]` `[reject]` `AnalyticsMdxReadJob` and `AnalyticsMdxReadGate` do not sweep stale state before each test -- each test creates and removes its own turn or adjustment; a crashed earlier run leaves state that turns the next run red, never green.
  - `[low]` `[reject]` The `request` branch of `MdxQuery.Process` is an equivalent mutant -- the store ends a row whose cancel flag is set `canceled` whatever `Work` finishes it with; 20.33's behavior is unchanged.
  - `[false]` `[reject]` Only three statements run through a real turn -- the matrix runs its rows "through the tool's `View`" and asks a real turn only for the row cap; AC1 and AC3 add turn legs.
  - `[false]` `[reject]` The Stop test begins its turn by hand -- the stop hook reads the signals a real turn sets (`GuardedSignals`), and `Loop.Run` stashes the key `Caller.TurnKey()` returns.
  - `[false]` `[reject]` Stop does not reach a listing's read or a DRILLTHROUGH's start -- a named limit in Design Notes; the bound's alarm ends both, and `AnalyticsMdxJob` pins them.
  - `[false]` `[reject]` The credential-column leg feeds `Projected` a synthetic answer -- the matrix row reads "a listing answer with a column named `Password`", and the probe cubes have no such column.
  - `[low]` `[patch]` A blank statement answers 400 `ANALYTICS.MDX.INPUT` before the gate, where the intent's fail-closed text refuses it as a construct (422 `ANALYTICS.MDX.SQL`) -- real deviation, cosmetic effect. Fixed: the pre-check is removed, so a blank text reaches the detector after the gate; `RefuseFor("input")` stays for a drill of a statement with no cells; the test, the class docs and this spec's text now say so.
  - `[false]` `[reject]` `drill` is a bare object checked by `DrillProblem`, a second layer beside the schema -- forced: the registry's emitted subset admits no nested `properties` (tried: every turn failed `TURN.UNAVAILABLE`); the check runs in the argument step before the gate.
  - `[false]` `[reject]` `MdxStatus` waits for plug-in cells, a change outside the intent -- the DW-2490 item in Tasks directs it, and the measurement showed `@Computing 0.00%` cells at status 100.
  - `[low]` `[reject]` The failed-card wrap rules in `_components.scss` apply to every failed tool card -- needed for AC9 (a 140-character sentence ran 474 px past the card), scoped to the warning status, and `turn` (10) and `refused-tool` (1) browser specs are green; the rest of the browser suite is CI's. Reported as a footprint extension.
  - `[false]` `[reject]` `MaskedRows` is public and `RedactedColumns` is new -- both are Tasks items (Rule 31).
  - `[false]` `[reject]` No `Api/Error.cls` edit for the new `ANALYTICS.` branch -- Story 20.33 shipped the branch; the task records "no edit".
  - `[false]` `[reject]` None of the files the intent forbids is touched; `scripts/ci-throwaway.sh` gains the four classes' arming lines, as Tasks says.
  - `[low]` `[patch]` (lead) `AnalyticsPort.Settle` kept `MdxCancel`'s status in a variable it never read -- replaced by `Do ..MdxCancel(...)`, as 20.33's `Stop` called it.

## Design Notes

**Intent gap (resolved).** Orchestrator ruling Q1 B, fail closed (2026-10-15): 20.33's `MdxConstructs`, before prepare and on the resolved text after it, is this read's one refusal; Q2 applied.

**Governing ADs (Rule 6).**

- AD-65: the port, the splice clause (ruling Q1 B) and the 20.35 clause drafted below.
- AD-60: one sanitizer, and a read never executes code.
- AD-36 and AD-39: what reaches the model, the 19.11 precedent widened.
- AD-24: the row cap, the per-reply total, and the screen's context `tools`.
- AD-7: synchronous in the turn job, never mutating of its own, the vendor's cache as its cost shape.
- AD-29, AD-8 and AD-64: gate first, with the screen's pairs and adjustment.
- AD-11: untrusted cells and labels. AD-21: the statement is concatenated into nothing.
- AD-16: switched calls; the stop hook runs only unswitched. AD-31 and AD-33: the lease and the stop signals.

Checked and not engaged: AD-6, AD-10, AD-15, AD-22 and AD-51 to AD-53 (nothing writes); AD-41 and AD-42 (no background run or spawn); AD-5 and AD-19 (no screen or store).

**Decisions.**

- **Synchronous, with polling.** `%ExecuteAsynch`, polled by `MdxRun`, gives a bound and a cancel inside the turn job without `JOB`. No turn limit cuts a call short (the 600 s wall clock and the 120 s lease are checked between steps), so polling the signals is what lets Stop reach the call.
- **One refusal, two checks, no copy.** The tool calls `MdxConstructs` before prepare and reads `MdxPrepare`'s `ask` after it; either, `unread` included, is `ANALYTICS.MDX.SQL`. The `Variables()` seam exists so a test can reach the second check, as 20.33's does.
- **Shape for the model.** Arrays of text serve cells and listings, because the schema subset has no `anyOf`. `Bound` cuts rows and keeps the port's own `rowsAvailable`; the port's 1,000-character cell cut stands for AD-24's per-field bound, as `SqlPort`'s does for 19.11.
- **The model sees the vendor's error text,** cut, as 19.11's SQL read does: it is the agent's own statement echoed back through AD-60.
- **The card shows the sentence** through the new `ANALYTICS.` branch. No `maxRows` argument: the row cap bounds `rows`, and the port reads at most `MDXMAXROWS`.
- **Declined:** an `InjectionSeed` channel (AD-60 needs no change for a new read tool; the turn test asserts the framing); new screen prompts.
- **Measurement.** None new: 20.33's plans measured the tokenizer, the fail-closed texts, where `%SEARCH` runs, the braced `%PARM` and the resolved text (spec-20-33 :453-462). Nothing was created on `ocupilot-b-ci` at this plan.

**Named limits.**

- Stored definitions (shared calculated members, named filters; DW-2451), `%KPI`/`%LOOKUP`, SQL computed dimensions, a cube's listing SQL, and the vendor's `^DeepSee.InitCode`, `AuditCode`, `AuditQueryCode` and `CloseCode` run as the person: their authors' code, not the statement's.
- Fail closed refuses a statement that only fails the lexer (an unterminated bracket, `3rd`) or names a member `[RETURN]`.
- A bound or Stop cancels the vendor's shared key, so the same text running elsewhere stops too.
- Stop does not reach a drill-through's listing call, which waits in the caller; 20.33's alarm ends it at the bound.
- A read started near the 600 s wall clock can overrun it by its bound (inference).
- A member name or cell that holds a secret reaches the model, as a SQL value under another name does. MDX writes the vendor's cache (AD-7).

**Rule 31.**

- **Extended:** 20.33's `MdxConstructs` and `MdxPrepare`'s `ask` (called, never copied); 20.33's loop as `AnalyticsPort.MdxRun`; `ExplorerSqlRead`'s masks; `AnalyticsError` with `ReasonFor` (sibling `InteropError`); `Api.Error`'s family branch; `NavSettleJob`; `ToolEmit`'s branch; 20.33's principals; `turnprobe-spec.mjs`.
- **New siblings:** `AnalyticsMdxRead` follows `ExplorerSqlRead`, its tests `SqlAgentRead` and `AnalyticsMdxJob`, the recorder `SqlPortFixture`.
- **Copies:** `MdxStopRequested` repeats three reads of `Loop.Boundary` (:422-460), which needs the loop's arguments and writes the stopped step, while the hook only asks. `Variables()` repeats `MdxQuery.Variables()`'s one line, because the fixture overrides the tool, not the slice.

**Integration (Rule 1), Consumes, Consumed-by (Rule 2).**

- **Integration:** AC1 (the turn loop reads the tool and the model receives the framed answer); AC3 (the turn and the card receive the refusal); AC8 (`MdxQuery.Work` consumes `MdxRun`; the SQL read consumes `RedactedColumns`).
- **Consumes:** 20.33's `MdxAdmit`, `MdxConstructs`, `MdxPrepare`, `MdxStart`, `MdxStatus`, `MdxCancel`, `MdxDrill`, `MdxAnswer`, the `MDX*` caps, the descriptor, the principals, the grid cube and the splice node; 20.11's `AnalyticsPort`, `AnalyticsError`, `AnalyticsProbe` and `analytics.cubes.read` (named by the description); 19.11's read pattern and masks; 4.7's stop helper.
- **Consumed-by:** `MdxRun`, 20.33's screen (20.34 may use it, inference); the read tool, 20.12's Investigate (inference).

**Ledger inbox (Rule 17):** none (`owned_ledger=0`).

**Rule 11.** `origin/OCU-1-epic23` at `a555c2a8af4c14acd488a461d10a5620f28c33a4` edits `Test/ReadTool.cls` (doc comments at :302, not :93-94) and EXPERIENCE.md (the data-table section, not Fixed strings): no overlap. Add-only here: `Test/ReadTool.cls`, `strings.ts`, EXPERIENCE.md and `Api/Error.cls`. Unchanged: `Test/SurfaceCoverage.cls`, `StageTwoTools`, `Screen/Registry.cls`, `Screen/Read.cls`, `Kernel/EntityType.cls`, `Prohibited.cls`. Footprint extensions (Rule 11 (b)): `Screen/Tool/ExplorerSqlRead.cls`, `Screen/Context.cls` (doc), `Api/Error.cls`, `Test/NavSettleJob.cls`, `scripts/ci-throwaway.sh`.

**Spine drafts (Rule 20; the lead writes them).** AD-65's splice clause already carries ruling Q1 B.

- **AD-65, a 20.35 clause:** "The agent's MDX read (`analytics.mdxquery.read`, Story 20.35) runs in the turn job through `MdxRun`, under MDX query's pairs, `MdxAdmit` and the `MDX*` caps. It polls the vendor and the turn's stop, abandon and lease, reserves no background run, and refuses with `ANALYTICS.MDX.SQL` a statement `MdxConstructs` finds a construct in or cannot read, before prepare, and one whose resolved text `MdxPrepare` asks for, after it."
- **AD-36:** "The agent's MDX read is a read tool, not a declared read (Story 20.35). Its cells, labels, listing rows and error message reach the model through AD-60, bounded by the `MDX*` limits and AD-24, listing columns named like credentials reading `[redacted]`. A person's MDX run stays screen-only."
- **AD-39:** the sixth exception adds "and the agent's own MDX read's (Story 20.35)".
- **AD-7:** "So does the agent's MDX read (Story 20.35), in the turn job; by OcuPilot's classification it never mutates."
- **AD-21:** the MDX clause adds "the agent's statement (Story 20.35) the same, with the constructs refused".
- **AD-24, at origin:** "(a form page declares neither, so its list is empty)" becomes "(a form page lists only the read tools bound to it: Stories 19.11 and 20.35)".

**Strings.**

- **`REASONMDXSQL` = `analyticsMdxSqlReason`:** "This query may run server-side code or SQL, which the agent's read never runs; you can run it yourself on MDX query after confirming."
- **`DESCRIPTION`:** "Run one MDX query in the namespace this turn is scoped to, as the signed-in user, and read its cells, or with drill, one cell's listing. Send one SELECT (columns and rows at most) or DRILLTHROUGH; find cubes with analytics.cubes.read. Text that runs server-side code or SQL (%SEARCH, %SQLRESTRICT, RETURN, %ORDER, %PARM), or that cannot be read as MDX, is refused: ask the person to run it on MDX query. Listing columns named like a credential read [redacted]."

**Weight.** The initial bundle gains one literal on 20.33's about 1.96 MB (inference), under the owner's fixed 2500 kB warning; no new lazy chunk.

**Size.** One story; cycle 1's seam (the detection) now lands in 20.33, so no split is recommended.

## Verification

Shared surfaces: `ReadTool`'s count and names, `REFUSEEMPTY`, `ToolEmit`'s branch, `DeveloperFloor`'s `TOOLS`; MDX query's context `tools`; `MdxQuery.Work`; `ExplorerSqlRead`'s masks; `Api.Error.ReasonForToolCode`; the arming rosters; the strings table and EXPERIENCE.md's Fixed strings; USER's analytics flags and `^OcuPilotProbeMdxSplice` nodes 351-360 while the probe runs.

*Every test added or changed passes on a fresh environment, in either order.* `AnalyticsProbe` creates and removes everything it asserts on, each splice leg uses its own node, and the row-cap leg reads the cap at that moment.

**Setup (slot B; never the dev instance `ocupilot-slot-b`):**

- `(loop)` **Load `src`:** `rsync -a --checksum --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-20/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`, then in `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`: `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)`.
- `(loop)` **Before a browser run:** `cd ui && npm run build && docker exec ocupilot-b-ci sh -c 'cd /durable/iris/csp/ocupilot && rm -rf ./*' && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`.

**Commands.** Each in the foreground with `timeout: 600000`, one at a time; read each class's result from `%UnitTest_Result`. A class that waits on slow queries runs alone.

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.AnalyticsMdxRead`, then the same runner, one class per call (each builds the probe cube and has no recorded timing): `AnalyticsMdxReadGate`, `AnalyticsMdxReadTurn`, `AnalyticsMdxReadJob`, `AnalyticsMdx`, `AnalyticsMdxJob`, `AnalyticsMdxRoutes`. Expected: green.
- `(loop)` The same runner, one batch (about 50 s in `ui/tools/ci-timings.json`): `ReadTool`, `ToolRoundTrip`, `ToolEmit`, `DeveloperFloor`, `SurfaceCoverage`, `SqlAgentRead`, `SqlCredentialMask`, `ExplorerDescriptor`, `AnalyticsMdxDescriptor`; then each class the sweep changes, in batches of about 8 minutes. Expected: green.
- `(loop)` `cd ui && npm run test:tools`. Expected: green.
- `(loop)` `cd ui && npm run build -- --verbose`. Expected: the prebuild chain green; the initial bundle about 1.96 MB, under 2500 kB.
- `(loop)` `uv run scripts/check-objectscript.py <each changed .cls>`, `uv run scripts/test_check_objectscript.py`, `bash scripts/lint-docs.sh`. Expected: clean.
- `(loop)` After the redeploy, one file per call: `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/agent-mdx.browser-spec.mjs`, then the same for `browser/analytics-mdx.browser-spec.mjs`. Expected: green.
- **Lead-owned (the runner's):** the full ObjectScript sweep, `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`, and Rule 30's fresh check. **Left to CI:** the full browser suite.

**Pinning mutations (Rule 19), each demonstrated on `ocupilot-b-ci`:** applied, the whole `src` tree reloaded (the bundle rebuilt and redeployed for the client one), the named test red, then reverted with the file's git blob hash equal before and after.

| AC | Mutation | Red |
|---|---|---|
| AC1 | `Projected` drops the label column | `AnalyticsMdxRead` cells and plug-in legs, `AnalyticsMdxReadTurn`, browser AC1 |
| AC2 | `MdxRun` ignores `drill` | `AnalyticsMdxRead` cell-drill leg, `AnalyticsMdxReadGate` writer leg |
| AC3 | `View` skips `MdxConstructs` | all 15 spellings, the unreadable and the blank legs (a prepare recorded) |
| AC3 | `View` ignores `MdxPrepare`'s `ask` | the Resolved leg (node 358 defined, no 422) |
| AC3 | `View` refuses on `found` only | the Unreadable legs |
| AC3 | `ReasonForToolCode` loses the `ANALYTICS.` branch | the sentence leg, `AnalyticsMdxReadTurn`, browser AC3 |
| AC3 | the tool also refuses the text `[%SE/**/ARCH]` | the Not-a-construct leg |
| AC4 | `Waited` ignores the deadline | `AnalyticsMdxReadJob` bound leg (150 s) |
| AC4 | `AnalyticsMdxRead.MdxStopRequested` answers 0, or loses its lease test | `AnalyticsMdxReadJob` Stop leg and hook leg |
| AC5 | Kind accepts CREATE and DROP | `AnalyticsMdxRead` kind leg |
| AC6 | `View` skips `Screen.Gate.Evaluate` | `AnalyticsMdxReadGate` adjustment leg only: P4 stays green because `MdxAdmit` repeats `MDXPAIRS` |
| AC6 | `MdxAdmit` skips the cache WRITE check; skips the read-only check | `AnalyticsMdxReadGate` P1 leg; `AnalyticsMdxRead` HSLIB leg |
| AC7 | The `ToolRoundTrip` row is removed | `ToolRoundTrip`, alone |
| AC8 | `MdxQuery.MdxStopRequested` answers 0 | `AnalyticsMdxJob` cancel legs (6 red). `Work` mapping `request` to `stopped` reddens nothing: the store ends a row whose cancel flag is set `canceled` whatever `Work` finishes it with |
| AC9 | The failed status word takes the card's own background color | browser AC9 (contrast, both themes) |
| AC9 | The wrap rules are removed from `_components.scss` (`overflow-wrap`, `text-align`, and the `:has` rule's `flex` and `min-width`) | browser AC9 (`app-tool-call-card>span.ocu-tool-call-status: 474px past its containing block`) |
| DW-2490 | `MdxStatus` drops the pending branch | `AnalyticsMdx` and `AnalyticsMdxRead` plug-in legs (`@Computing 0.00%`) |
| - | `RedactedColumns` dropped; `DrillProblem` skipped, or only its integer and maximum checks; schema check skipped; `MdxPrepare`'s error answer ignored; the sentence changed on one side | the credential, drill, argument, syntax and `analytics.test.mjs` legs |

**QA additions (Rule 19), each demonstrated on `ocupilot-b-ci` with the whole `src` tree reloaded and the file's blob hash equal before and after.**

- (QA) `src/OcuPilot/Test/AnalyticsMdxReadTurn.cls`: `TestATurnDrillsIntoACellAndAListingIsCutToTheContextRowCap` and `TestThePersonsStopEndsAReadInATurnAndLeavesNothingRunning` (the class holds 4 tests).
- (QA) `src/OcuPilot/Test/AnalyticsMdxRead.cls`: `TestAVendorErrorLongerThanTheCellBoundIsCut` (the class holds 15 tests).
- mutation: `MdxRun` ignores `drill` (`Set pRow = ""`) -> `AnalyticsMdxReadTurn` drill leg, alone in its class.
- mutation: `AnalyticsMdxRead.MdxStopRequested` answers 0 -> `AnalyticsMdxReadTurn` stop leg, alone in its class (the turn is still running 41 s after the stop is posted).
- mutation: `AnalyticsPort.ErrorAnswer` answers the vendor's whole text -> `AnalyticsMdxRead` long-error leg, alone in its class.
- Final runs on the reloaded tree: `AnalyticsMdxRead` 15, `AnalyticsMdxReadGate` 4, `AnalyticsMdxReadTurn` 4, `AnalyticsMdxReadJob` 3, `AnalyticsMdx` 15, `AnalyticsMdxJob` 13, `AnalyticsMdxRoutes` 9, `AnalyticsMdxGate` 2, the roster batch 84, `npm run test:tools` 2,113, browser `agent-mdx` 3 and `analytics-mdx` 11, all green.

**Code review additions (Rule 19), on `ocupilot-b-ci` with the whole `src` tree reloaded and the tool's blob hash equal before and after each mutation.**

- (review) mutation: `AnalyticsMdxRead.MdxStopRequested` answers 0 for a turn never renewed -> `AnalyticsMdxReadJob` hook leg ("a turn that was never renewed asks"), alone in its class (run 203).
- (review) mutation: `AnalyticsMdxRead.MdxStopRequested` answers 0 -> `AnalyticsMdxReadJob` Stop leg (`seconds` 2: the stop, posted once the vendor reported the query started, never reached it) and hook leg (run 204).
- (review) QA's turn Stop leg now waits on the vendor's status too; its `mutation:` line above was not re-run.
- (review) `Settle`'s wait on the vendor's own status has no pin of its own: landing a Stop inside a plug-in's pending window is timing-bound.
- (review) Final runs on the reloaded tree: `AnalyticsMdxReadJob` 3 (run 202), `AnalyticsMdxReadTurn` 4 (205), `AnalyticsMdxJob` 13 (206), `AnalyticsMdx` 15 (207), `AnalyticsMdxRead` 15 (208), all green.

**Implement record (slot B, HEAD `3d032313`).**

- **Task 0.** `MdxConstructs`, `MdxPrepare`'s `ask`, `found` and `variables`, and `AnalyticsMdx` (14 green) are as 20.33 shipped them. The plan's `Work` steps 1-3 are `MdxQuery.Process`, `Execute`, `Stop` and the drill and listing branches, now `AnalyticsPort.Ran`, `Waited`, `Settle` and `StoppedAnswer` (`Alarmed`, `AlarmSeconds`, `MDXPOLLPAUSE` moved with them). `Asked` is `MdxQuery.MdxStopRequested`. `AnalyticsError.ReasonFor` and `Api.Error`'s branch were shipped; the tool count was 399, now 400; `DeveloperFloor`'s declared tools were fifty-two, now fifty-three. A stop reports `seconds` as the bound for `bound` (20.33's tests read 2 and 0.5) and the whole seconds run for `request`. The slow grid statement ran 150 s with the deadline mutated. Probe nodes: 351-356 the `%SEARCH` spellings, 357 `%PARM`, 358 the resolved text, 359 the turn leg, 360 the browser leg.
- **Decisions.** (1) `drill` is a bare object (see Tasks). (2) A signal read that fails stops the read, as `Loop.Boundary` stops the turn. (3) A failed card's status wraps (`_components.scss`, scoped to `.ocu-tool-call-status-warning`): the 140-character sentence ran 474 px past the card in the structural walk, so AC9 failed before the change. (4) The stop leg's statement is the bound leg's crossjoin with its dimensions swapped, because a completed run is answered from the vendor's cache.
- **DW-2490: real.** A `%KPI("%DeepSee.Median", ...)` statement is reported 100 with `pPendingResults` 1, its cells reading `@Computing 0.00%`; `%UpdatePendingResults` cleared it in three passes to 47.5. `MdxStatus` now updates the pending results and answers 99 until none remain.
- **Bundle.** Initial total 2.00 MB raw, 355.04 kB estimated transfer, under the 2,500 kB warning.
- **Runs (all green).** `AnalyticsMdxRead` 14, `AnalyticsMdxReadGate` 4, `AnalyticsMdxReadJob` 3, `AnalyticsMdxReadTurn` 2, `AnalyticsMdx` 15, `AnalyticsMdxJob` 13, `AnalyticsMdxRoutes` 9, `AnalyticsMdxGate` 2, the roster batch (84 tests), 22 registry-dependent classes, `npm run test:tools` 2,113, `agent-mdx` and `analytics-mdx` browser specs (3 and 11), the checker (146 harness tests) and `lint-docs.sh`.

## Auto Run Result

Status: done
Blocking condition: none

**Summary.** `analytics.mdxquery.read` is a read tool bound to MDX query. It runs one MDX statement in the turn job through the new `AnalyticsPort.MdxRun`, which the screen's background run now shares (`MdxQuery.Work` calls it with a stop hook). It refuses with 422 `ANALYTICS.MDX.SQL` a statement `MdxConstructs` finds a construct in or cannot read, before the prepare, and one whose resolved text `MdxPrepare` asks for, after it. The run polls the vendor, the turn's stop and abandon signals and the lease, and a bound or a stop leaves nothing running. DW-2490 was real and is fixed: `MdxStatus` now updates a plug-in's pending cells and answers 99 until none remain.

**Files changed.**

- Product: `Port/AnalyticsPort.cls` (`MdxRun`, `RefuseFor`, the pending update in `MdxStatus`), `Api/AnalyticsError.cls` (`MDXSQL`), `Area/Analytics/MdxQuery.cls` (calls `MdxRun`, `MdxStopRequested`), `Screen/Tool/AnalyticsMdxRead.cls` (new), `Screen/Tool/ExplorerSqlRead.cls` (`RedactedColumns`, public `MaskedRows`), `Screen/Context.cls` and `Screen/Descriptor/AnalyticsMdxQuery.cls` (docs).
- Tests: `AnalyticsMdxRead`, `AnalyticsMdxReadFixture`, `AnalyticsPortRecorder`, `AnalyticsMdxReadGate`, `AnalyticsMdxReadJob`, `AnalyticsMdxReadTurn` (new); `AnalyticsMdx` (plug-in leg), `AnalyticsMdxJob` (mutation lines), `NavSettleJob` (`StopAfter`), the `ReadTool`, `ToolRoundTrip`, `ToolEmit` and `DeveloperFloor` rosters.
- Client and scripts: `strings.ts`, EXPERIENCE.md (one Fixed strings row), `ui/tools/analytics.test.mjs`, `ui/browser/agent-mdx.browser-spec.mjs` (new), one comment in `ui/browser/analytics-mdx.browser-spec.mjs`, `scripts/ci-throwaway.sh` (arming lines), `ui/src/styles/_components.scss` (the failed card's wrap).
- Footprint extensions beyond the spec's list: `ui/src/styles/_components.scss`, `Screen/Descriptor/AnalyticsMdxQuery.cls` (doc), `Test/AnalyticsMdxJob.cls` (mutation lines), `Test/AnalyticsMdx.cls` (one test).

**Review.** 21 findings: 4 low patched, 8 low rejected, 9 false rejected, none deferred (`deferred: []`); rows and reasons are in the triage log. Follow-up review recommended: false (no high, no medium patched).

**Verification.** On `ocupilot-b-ci` after the last reload, one class per call and each run read from `ci-runner`: `AnalyticsMdxRead` 14, `AnalyticsMdxReadGate` 4, `AnalyticsMdxReadJob` 3, `AnalyticsMdxReadTurn` 2, `AnalyticsMdx` 15, `AnalyticsMdxJob` 13, `AnalyticsMdxRoutes` 9, `AnalyticsMdxGate` 2, all green; the roster batch (`ReadTool`, `ToolRoundTrip`, `ToolEmit`, `DeveloperFloor`, `SurfaceCoverage`, `SqlAgentRead`, `SqlCredentialMask`, `ExplorerDescriptor`, `AnalyticsMdxDescriptor`) 84 green before the blank-statement patch, which touches none of them. `npm run test:tools` 2,113 pass; `npm run build` passes its prebuild chain with an initial total of 2.00 MB (355.04 kB estimated transfer), under the 2,500 kB warning; `check-objectscript` 0 problems, `test_check_objectscript` 146 pass, `lint-docs.sh` clean; browser `agent-mdx` 3, `analytics-mdx` 11, `refused-tool` 1 green on the final bundle. Mutations are in `## Verification`. The full ObjectScript sweep, `smoke.sh`, Rule 30's fresh check and the full browser suite are the runner's and CI's.

**Residual risk.** A plug-in pass longer than a second delays a bound or a Stop by that pass (measured 1.11 s for 2,000 Median cells; a plug-in's code is the person's). `MdxQuery.Process`'s `request` branch ends the row as before, but the store would end it `canceled` anyway, so that branch is not separately testable.
