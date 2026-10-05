---
title: 'Story 19.11: The agent gains guarded SQL and a picker'
type: 'feature'
created: '2026-10-05'
status: 'done'
baseline_revision: '679cbf1fa9f10e5ec02e40e79cae234bb8c201f8'
baseline_commit: '679cbf1fa9f10e5ec02e40e79cae234bb8c201f8'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-19-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-19-6-the-query-console-and-its-dml-and-ddl-guard.md'
warnings: ['multiple-goals', 'oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Every turn uses the one default agent definition, so an operations agent and a developer agent cannot both be offered. And the agent cannot use SQL: the console's guarded tool (Story 19.6) is unadvertised, and a query's rows never reach the model.

**Approach:** The panel header gains a picker among enabled definitions. The pick is a per-user preference (AD-50), resolved on the instance at every turn start and by every reader that today assumes the default. The agent gets a new read tool, `explorer.sqlquery.read`, for queries, which runs the console's own checks in the turn job. `explorer.sqlquery.run` is advertised for mutating statements, which become confirmed proposals whose card shows the statement's real guard (DW-2004). Its governance key stays `false`.

## Boundaries & Constraints

**Always:**

- **The definition in force** for a user is their pick while it names an enabled definition, else the default (`ResolveDefault`). It is resolved once per turn start, frozen on the turn (`Turn.DefinitionId`), and used by:
  - the turn's verdict, the step boundary and dispatch;
  - the proposal's stamp, which Confirm judges;
  - the context chip, the restraint footer, Guardrails and the replay.
  - The provider call, the iteration limit, the system prompt override and retention already read the turn's own definition (`Loop.cls`, `Entry.DefinitionId`).
- **The pick** is the `shell` member `agentDefinition` in `Kernel/State/Pref`, written through `POST /account/preferences`.
  - Its value is a definition id. A write naming a definition that does not exist or is disabled is refused 422 `PREFERENCES.CHOICE` before any store write.
  - A pick never moves the default marker and writes no audit event.
- **Restraint still binds whatever is picked:** the kill switch (instance and per-user), enforced read-only and per-user read-only (Story 14.5) take precedence over the picked definition's own flag, through `Kernel.Restraint.Verdict` unchanged.
- **One conversation, one definition.** A turn replays only earlier entries that ran with its own definition (an entry with no recorded definition still replays). The panel starts a new conversation when the person picks another definition while the current one has turns.
- **`explorer.sqlquery.read`** (new, `KIND` read, `DESCRIPTORCLASS` `ExplorerSqlQuery`) runs in the turn job, in the turn's namespace (`Kernel.Scope`), as the user. In order:
  1. the screen's pairs;
  2. `SqlPort.InputProblem(statement, parameters, maxRows)`, refused 400 `EXPLORER.SQL.INPUT`;
  3. `Area.Explorer.SqlConsole.Check`: `SqlPort.Classify` (gate, password, prepare with `%Prepare(text,1)`, refused groups, DDL privilege), then `Prohibited.SqlStatement`;
  4. a prepare error is answered as its `error` outcome;
  5. a mutating kind is refused 422 `EXPLORER.SQL.CHANGES`;
  6. a value-count mismatch is refused 422 `EXPLORER.SQL.PARAMETERS`;
  7. then `SqlPort.Run` in `query` mode.
- **The read's answer** is `{namespace, kind, statementType, tables, outcome, columns, rows, truncated, redactedColumns}`, or the `error` (`sqlcode`, `message`) or `stopped` (`seconds`) outcome.
  - Every cell of a column whose name matches `Kernel.Audit.Log.IsCredentialName` reads `[redacted]`.
  - The dispatcher's AD-24 bound and AD-60's sanitizer apply as to every read tool.
  - `maxRows` is 1 to 1,000, default 200.
- **`explorer.sqlquery.run` is advertised.** Its baseline key stays `"explorer.sqlquery.run": false` (AD-22), so at the baseline the agent's call answers `GOVERNANCE.DISABLED` and mints nothing.
- **The run's agent schema** requires `Target`, the literal `sql`, which the mint sets whatever is sent. Its mint (`ExplorerSqlRunMint`) runs `SqlPort.InputProblem` (400 `EXPLORER.SQL.INPUT`) and `SqlConsole.Check` first, and refuses:
  - a prepare error: 422 `EXPLORER.SQL.NOTPREPARED`, `detail {sqlcode}`;
  - a query: `EXPLORER.SQL.READS`;
  - a code-carrying statement (types 35–38, 43 and 67, or text containing `COMPUTECODE` in any case): 422 `EXPLORER.SQL.AGENTCODE`;
  - a value-count mismatch: `EXPLORER.SQL.PARAMETERS`.
- **DW-2004.** The run declares `READSVALUES` 1. Both the mint (its arguments) and a screen action (its declared values) pass through `PortQuery` into the `GUARD` read, as Confirm's re-read already does. All three callers therefore read one guard, and the fingerprint covers the statement's real `Kind`, `StatementType` and `Tables`.
- **The card** shows the statement, its values, `Kind`, `StatementType` and `Tables`, with the destructive treatment and no typed name. Its consequence is the console's sentence for the kind. After Confirm it shows the run's status line, plus the SQLCODE and message for an `error` outcome.
- Every IRIS MCP call uses `server: "ocupilot-slot-a"`. Every configuration-changing probe runs on `ocupilot-a2-ci`, one test class per call.

**Never:**

- Change a shipped baseline value. `explorer.sqlquery.run` and `explorer.sqldata.save` stay `false`, and `explorer.sqldata.save` stays unadvertised (AD-36: row values never reach the model; DW-2057 stays theoretical).
- A turn that executes a mutating kind. A background run reached by the agent (19.15). Explain plan for the agent.
- Caller SQL through `action/query` or `AtelierPort`. `%Prepare(…,0)`. A value spliced into text. A SQL parser, or any text rule beyond `COMPUTECODE` and 19.6's two.
- The statement's text or values in the marker, a log line or the audit payload. A run's rows, SQLCODE or message in the ledger, the marker, a log line or the audit payload: the read's answer reaches the model and the turn's own tool step (AD-33) alone. A person's console run's rows reaching the model or screen context.
- A new route. An edit to `Api/Error.cls`. A new dialog. The pick in browser storage. A pick moving the default marker. A turn body naming a definition.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Agent query | `explorer.sqlquery.read` `{statement: "SELECT Name, Num FROM OcuProbe196.Granted WHERE Num > ?", parameters: ["0"], maxRows: 2}`, turn in USER | `outcome rows`, `kind query`, `statementType 1`, the table in `tables`, two rows, `truncated` true, the tool_result framed `<ocupilot-data>` | None |
| Bound, not spliced | value `' OR ''='` | `rows` empty | None |
| Credential column | a probe column `ApiToken`, selected under its own name | its cells `[redacted]`; `redactedColumns` names it | None |
| Not prepared | a syntax error, or a principal holding SELECT on `Granted` alone reading `Hidden` | read: `outcome error`, `sqlcode` (-99 for the principal), no row; run's mint: 422 `EXPLORER.SQL.NOTPREPARED` `detail.sqlcode`, no proposal | Tool error result |
| Change sent to the read | UPDATE, CREATE TABLE, CALL, an unclassified type | 422 `EXPLORER.SQL.CHANGES`; nothing executed; table unchanged | Tool error result |
| Query sent to the run | `SELECT …` to `explorer.sqlquery.run` | 422 `EXPLORER.SQL.READS` at mint; no proposal | Tool error result |
| Code from the agent | CREATE FUNCTION / PROCEDURE / METHOD / QUERY / TRIGGER / AGGREGATE; `CREATE TABLE … COMPUTECODE {…}` | 422 `EXPLORER.SQL.AGENTCODE` at mint; the console still asks its confirmation and runs it | Tool error result |
| Refused groups | session, administration, server-file, password statements on either tool | 19.6's codes; the password refused before any prepare | Tool error result |
| OcuPilot's own | `%All` in the install namespace: `SELECT ID FROM OcuPilot_Kernel_State.Proposal`, or a view over it | 403 `PROHIBITED.OCUPILOTSQL` on the read and at the run's mint | Tool error result |
| Governed | key `false`; the agent proposes `UPDATE OcuProbe196.Granted SET Num = 3` | `{"code":"GOVERNANCE.DISABLED"}`; no proposal; table unchanged | Tool error result |
| Moved under the card | key enabled; minted UPDATE; its table dropped before Confirm | Confirm refused target-changed (fingerprint over `Tables`); nothing runs | Card state |
| Pick write | `{kind: shell, action: set, name: agentDefinition, value: <disabled or absent id>}` | 422 `PREFERENCES.CHOICE`; nothing stored | Field reason |
| Stale pick | stored pick later disabled or deleted | turn, chip and header use the default; re-enabled, the pick applies again | None |
| One or no definition | one enabled definition; none enabled | header names it as text, no menu; configuration-empty state unchanged | None |

</intent-contract>

## Code Map

Paths are under `src/OcuPilot/` or `ui/` unless given in full. Line numbers were read at HEAD `e8ee7445`.

- **Definitions and the turn:**
  - `Kernel/State/Agent.cls`: `ResolveDefault` :627–633 (enabled default or `""`), `GuardedRebalanceDefault` :650, `ScreenRow` :503 (the six-key projection), `GuardedVersion`, `%ExistsId`.
  - `Api/Turn.cls`: `HandleStart` :40. It calls `Restraint.Resolved` at :84 and resolves the default again at :93, then `GuardedReserve(…, tDefinitionId)` at :127 and `tValues("definitionId")` at :144.
  - `Kernel/Restraint.cls`: `Verdict(user, definitionId)` :89, unchanged. `Resolved` :206–215 wraps `ResolveDefault` and is called by Turn.cls:84, `Kernel/Agent/Loop.cls:76-79` (step boundary), `Api/Switches.cls:389` (footer) and `Kernel/Shell/Guardrails.cls:45`.
  - `Kernel/Agent/Dispatch.cls:246`: the write restraint already uses the turn's `pDefinitionId`.
  - `Kernel/Proposal/Mint.cls`: `DefinitionInForce` :773–779 stamps `ResolveDefault`, called at :343–349. The fresh-read query is seeded with the id alone at :165–167. `ArgumentProblem` is at :217 and `ConsequenceOf` at :758.
  - `Kernel/Proposal/Confirm.cls`: :331 judges the proposal's stamped definition, and `DefinitionMoved` is :625–638.
  - `Kernel/Proposal/Caller.cls`: `Set(pTurnKey, pConvKey)` :20, set at `Loop.cls:140`.
  - `Kernel/State/Convo.cls`: `HistoryMessages` :249–281 reads `Entry.GuardedRows` and is called at `Loop.cls:151`. `Entry.DefinitionId` is at Entry.cls:79.
  - `Api/Context.cls`: `Body` :100–134 resolves the default at :109 and answers `{share, shareDefault, userChoice, contextRowCap, provider, endpointHost, leavesInstance}`.
  - `Api/Definitions.cls`: `HandleList` :175 is open past the floor (`SelectionProjection` :1547).
- **The preference store:**
  - `Kernel/State/Pref.cls`: `KINDSHELL` :90, members :94–115, `IsShellMember` :376–383, `IsThemeValue` :387, `GuardedValue` :355.
  - `Api/Preferences.cls`: the name gate :201, value :205, the theme choice :210 (`PREFERENCESCHOICE`, a generic reason, reused).
- **SQL:**
  - `Port/SqlPort.cls`: `IDKEY`/`IDVALUE` :67–69, `TYPESDDL` :140, `DDLPRIVILEGES` :129, `Mutating` :338, `Classify` :410, `Run` :503 (its `query` mode treats a mutating kind as a 500, :530), `Invoke` :613 (`GUARD` reads `query("statement")` alone, :640–655), `RunAnswer` :794 (rows are arrays), `ErrorAnswer` :827.
  - `Area/Explorer/SqlConsole.cls`: `Check` :151 (Classify, then `Prohibited.SqlStatement`) and `ErrorOutcome` :180, both public. The `HandleRun` order is :36–75.
  - `Screen/Tool/ExplorerSqlRun.cls`: the parameters :24–70 (`DESCRIPTION` :28 says "never offered to the agent"), `PrivilegePairs` :91, `InputSchema` :103, `PortQuery` :165, `StateDiff` :178 (rows Kind and Tables), `WriteOutput` :203.
  - `Screen/Tool/ExplorerImport.cls` and `ExplorerImportMint.cls` are the exemplar of a literal target set by its own `MintClass` before `##super`.
  - `Screen/Tool/Write.cls`: `MintClass` :515, `View` :827–851 (requires the id argument), `ArgumentProblem` :877.
  - `Screen/Tool/Base.cls`: `ADVERTISED` :50, `KIND` :30.
  - `Api/ScreenAction.cls`: :274 reads with an empty payload (DW-2004), the delta at :291, and `Body` :434–468.
  - `Kernel/Proposal/Operation.cls`: `Query` :222–228 (`PortQuery` over a payload) and `ReadAt` :251.
  - `Kernel/Proposal/Prohibited.cls`: `SqlStatement` :2122 and `SqlRun` :2153, unchanged.
  - `Api/AtelierError.cls`: the SQL codes :103–185 (code and reason pairs).
- **Standalone read exemplar:** `Screen/Tool/ErrorRead.cls` (extends `Base`, own `View` :138). Registration is discovery (`Registry.ToolClasses` :649): the name pattern is :33, and `ProviderTools` :284–300 requires a description, a `SecretArguments` declaration and both schemas.
- **Dispatch and bounds:**
  - `Kernel/Agent/Dispatch.cls`: `AnswerOne` :179. A read skips governance (`Kernel/Governance/Policy.cls:88-91`) and restraint (:244).
  - Bounding is at :321–330: `Kernel/Agent/Bound.cls:32`, where array rows get no per-field cut (:68–70); the row cap and the total cap apply.
  - `Kernel/Agent/Sanitize.Results` :38, called at `Loop.cls:625`.
  - `ErrorContent` :731 carries `code` and `detail` to the model.
  - `Kernel/Audit/Log.cls`: `IsCredentialName` :179.
- **Client:**
  - `shell/panel.ts`: the header :258–285 (the busy reason `agentNewConversationLockedReason`), `onNewConversation` :2004, `proposalView` :1055–1072, and the chip gate :1780.
  - `shell/command-bar.ts:230-258` is the `menuitemradio` menu pattern to follow.
  - `core/agent-status.ts`: `rowsOf`/`isEnabled` :268–277, and the stale anchor at :15 (it says `Definitions.cls:125`; `HandleList` is :175).
  - `core/agent-context.ts`: facts :27–42, `load` :186–211, re-read on change events :286–290.
  - `core/account-preferences.ts`: `SHELL_*` :55–77 and `setValue` :388–419.
  - `core/turn.ts`: `outputLinesOf` :470 (reads `output.lines` alone), used at :1385.
  - `core/proposal-view.ts`: `consequenceSentence` :322–380, and `remoteListSentence` :241 / `journalSentence` :308 for a sentence filled from the view.
  - `shell/proposal-card.ts`: consequence :255–264, filled slots :266–286, output block :327.
  - `areas/system-explorer/sql-query.store.ts`: `statusLineFor` :173 and the `SqlAnswer` parse `answerOf`.
  - `core/strings.ts`: the last key is :5761 and `} as const` :5762. Reuse `tableColumnDefault` :540, `agentNewConversationLockedReason` :209 and `explorerSqlConfirm*` :5106–5112.
- **Tests and rosters to follow:**
  - `Test/DocDbWrite.cls:267-306`: governed, then enabled through `GovernanceFixture`, then minted and confirmed.
  - `Test/DeveloperFloorTurn.cls`: a real turn with `TurnWireFixture`.
  - `Test/TurnWireFixture.cls`: `EnsureDefinition` :224 and `EnsureLocalDefinition` (a second enabled `turnprobe` definition), `MarkedDefault`, `RemoveDefinition`, `StartConversation`, `StartBody`, `AwaitEnd`.
  - `Test/TurnProvider.cls`: `ToolUseReply` :169 and `Recorded` :150.
  - `Test/SqlConsoleProbe.cls`: `Make`/`Remove`, `EnsurePrincipals`, `ProbeAs`.
  - `Test/InjectionChannels.cls`: one method per source, e.g. `TestStatementLiteral` :300.
  - `ui/browser/turnprobe-spec.mjs`: `runIris`.
  - `ui/browser/definitions.browser-spec.mjs` and `system-explorer-sql-query.browser-spec.mjs`.
- **Budgets:**
  - `ui/angular.json:54` is `2943kB`, pinned at `ui/tools/angular-json.test.mjs:523`.
  - `ui/tools/strings.test.mjs:585-588` caps the table at 2,700, and values must be unique (:771). `ui/tools/self-protection.test.mjs` `ATELIER_REFUSALS` :511 requires each SQL reason to equal a `strings.ts` value, to appear in Fixed strings, and to omit the word "agent" (:553–559).

## Tasks & Acceptance

**Execution:**

- [ ] **Task 0** (`ocupilot-a2-ci`; probe class `OcuProbe1911.Fn` with an SQL function that sets `^OcuProbe1911`, removed after and checked gone). Through `explorer.sqlquery.read` in a stub turn as `_SYSTEM`, select the function, and record whether the global was set. That is AD-7's named limit, measured. Write one line in Design Notes.
- [ ] `Kernel/State/Agent.cls`: add `ResolveFor(pUserName, Output pId)`. It answers the user's `agentDefinition` pick while that names an enabled definition, else `ResolveDefault`.
- [ ] `Kernel/State/Pref.cls`: add `SHELLAGENTDEFINITION = "agentDefinition"` to `IsShellMember`.
- [ ] `Api/Preferences.cls`: a `set` of that member whose value is not an existing enabled definition's id is refused 422 `PREFERENCES.CHOICE`, beside the theme check.
- [ ] `Kernel/Restraint.cls`: `Resolved` resolves through `ResolveFor`. Update its doc.
- [ ] `Api/Turn.cls`: resolve once with `ResolveFor`, then compute the verdict as `Verdict(user, id)` with that same id. Keep the empty answer's 503 `PROVIDER.UNCONFIGURED`.
- [ ] `Kernel/Agent/Loop.cls`:
  - the step boundary's `Restraint` (:76) takes the turn's `pDefinitionId`;
  - `HistoryMessages` is called with it (:151).
- [ ] `Kernel/State/Convo.cls`: `HistoryMessages` takes an optional definition id and leaves out an entry whose recorded `DefinitionId` is a different non-empty id. `GuardedRows`' wire stays unchanged.
- [ ] `Kernel/Proposal/Mint.cls`:
  - `DefinitionInForce` stamps the turn's own `DefinitionId` (by `pTurnKey`), falling back to `ResolveDefault` for a turn row with none;
  - after seeding the id (:166), a tool declaring `READSVALUES` has `PortQuery(pArgs, .tQuery)` applied.
- [ ] `Api/Context.cls`: resolve through `ResolveFor`, and add `definition` to the answer: `{id, name}`, or `null` when none is in force.
- [ ] `Screen/Tool/Write.cls`: add `Parameter READSVALUES As BOOLEAN = 0`, documented.
- [ ] `Api/ScreenAction.cls`: for a `READSVALUES` tool, the fresh read (:274) passes the action's declared values as its payload JSON.
- [ ] `Port/SqlPort.cls`:
  - `CODETYPES = "35,36,37,38,43,67"`;
  - `CarriesCode(pType, pText)`: a type in `CODETYPES`, or `COMPUTECODE` in the text in any case.
- [ ] `Api/AtelierError.cls` (add-only): `EXPLORER.SQL.CHANGES`, `.AGENTCODE` and `.NOTPREPARED`, with the reasons in Design Notes › Strings.
- [ ] `Screen/Tool/ExplorerSqlRun.cls`:
  - drop `ADVERTISED`, add `READSVALUES` 1, and `MintClass` → `ExplorerSqlRunMint`;
  - rewrite `DESCRIPTION` and the class doc;
  - `InputSchema` adds `Target` (required, "Send the literal 'sql'");
  - `StateDiff` adds a `StatementType` row;
  - `Consequence(pPayload)` maps the payload's `Kind` to `EXPLORER.SQL.CHANGESROWS` (dml), `.CHANGESSCHEMA` (ddl), `.RUNSPROCEDURE` (call) or `.UNDECLARED` (other).
- [ ] `Screen/Tool/ExplorerSqlRunMint.cls` (new, extends `Kernel.Proposal.Mint`), as `ExplorerImportMint` does. In order:
  - `SqlPort.InputProblem`, refused 400 `EXPLORER.SQL.INPUT`;
  - `SqlConsole.Check` in `Kernel.Scope.Current()`, with its fault answered unchanged;
  - the four refusals in Boundaries;
  - the target set to `SqlPort.IDVALUE`;
  - `##super`.
- [ ] `Screen/Tool/ExplorerSqlRead.cls` (new, extends `Screen/Tool/Base`):
  - `TOOLNAME` `explorer.sqlquery.read`, `KIND` read, `DESCRIPTORCLASS` `ExplorerSqlQuery`;
  - `PrivilegePairs` as the run's;
  - `InputSchema` `{statement` (required), `parameters[]`, `maxRows}`;
  - `SecretArguments` declared empty;
  - a result schema, and a `View` that runs the order in Boundaries.
- [ ] `ui/src/app/core/sql-answer.ts` (new): move `SqlAnswer`, `answerOf` and `statusLineFor` out of `sql-query.store.ts`, which re-imports them. Add `sqlOutcomeLines(output)`: the status line, plus the message for an `error` outcome.
- [ ] `ui/src/app/core/turn.ts`: `outputLinesOf` answers `sqlOutcomeLines` for an `output` carrying `outcome`.
- [ ] `ui/src/app/core/proposal-view.ts` (add-only): the four SQL consequence codes map to `explorerSqlConfirmDml|Ddl|Call|Other`, with the DML sentence's `<tables>` filled from the view's `Tables` row through a function, as `remoteListSentence` does. `ui/src/app/shell/proposal-card.ts` gets that sentence's own `@if` slot beside :266–286, as the remote-list and journal sentences have.
- [ ] `ui/src/app/core/agent-status.ts`: keep the enabled rows as `options()`, `{id, name, provider, model, isDefault}`. Correct the :15 anchor.
- [ ] `ui/src/app/core/agent-context.ts`: parse `definition`.
- [ ] `ui/src/app/core/account-preferences.ts`: export `SHELL_AGENT_DEFINITION`.
- [ ] `ui/src/app/shell/agent-picker.ts` (new, standalone, OnPush), placed in `panel.ts`'s header between the title and New conversation:
  - with two or more options, a text button naming the definition in use, its accessible name "Agent definition: <name>";
  - it opens a `role="menu"` of `menuitemradio` items, each with the name, a second line "<provider> · <model>", and `tableColumnDefault` on the marked one;
  - `aria-checked` is set on the one in use, and keys and Escape work as the command bar's menu;
  - with one option, the name renders as text;
  - while a turn runs, the button is `aria-disabled` with `agentNewConversationLockedReason`.
- [ ] `ui/src/app/shell/panel.ts`, on a choice:
  1. `setValue('shell', SHELL_AGENT_DEFINITION, id)`;
  2. on success, when the conversation has turns, the New conversation path;
  3. then `AgentContext.load()`.
  - A refusal re-reads `AgentStatus` and `AgentContext`.
- [ ] `ui/src/app/core/strings.ts` (end) and `ui/src/styles/_components.scss` (add-only, tokens only): the five literals in Design Notes › Strings.
- [ ] EXPERIENCE.md (`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/`):
  - in place: :153 and :624 add the picker to the panel's parts;
  - :702 adds the picker to the Header row with one sentence on its behavior;
  - :626 says the chip names the definition in use, the person's pick while it is enabled, else the default;
  - :149 adds "chosen in the panel's picker (Story 19.11)";
  - add one Fixed-strings row after :603.
- [ ] `scripts/ci-throwaway.sh` (add-only): a `classes:` line for each new class that declares an arming variable.
- [ ] `ui/angular.json` and `ui/tools/angular-json.test.mjs:523`: re-base `maximumWarning` to the measured build rounded up to the next kB (DW-1166). Stop and ask above 3,800 kB.
- [ ] Tests (ObjectScript, new):
  - `Test/SqlAgentRead.cls` (the read, its refusals, the mask, a principal's -99, and one stub turn whose recorded `tool_result` carries the framed rows);
  - `Test/SqlAgentWrite.cls` (advertised rosters, governed then enabled, mint refusals, card rows and consequence, confirm, target-changed, the screen action's guard, marker without text);
  - `Test/AgentPick.cls` (pick validation, `ResolveFor` fallback, the context answer, the footer and Guardrails, the mint stamp, no marker move and no audit row);
  - `Test/AgentPickTurn.cls` (real turns: the picked definition's endpoint, egress, the replay filter, restraint precedence).
  - Add source (o) to `Test/InjectionSeed.cls` and `Test/InjectionChannels.cls`: a probe row holding the seed, read through `explorer.sqlquery.read`.
- [ ] Rosters, which trip on the advertised run and the new read; verify each at edit time:
  - `SqlConsoleWrite.TestTheRunIsAbsentFromEveryRosterTheAgentSees`, inverted and renamed;
  - `SqlPort.cls:230` ("101");
  - `ExplorerDescriptor` :141 (rosters, not the method name: DW-2093) and :266/:290 (`ScreenTools`);
  - `ReadTool` :93–94, `DeveloperFloor` `TOOLS`/`HELDWRITES` and the count words;
  - `ToolRoundTrip` `REFUSEEMPTY`, `ClassicPageGate` :220–227, `Governance`, `DraftRegistry`, `Guardrails`, `PrefState.TestTheShellMemberSetIsClosed`;
  - `TurnContext`, `EgressLine`, `Restraint.TestResolvedAnswersTheVerdictForTheDefinitionInForce`;
  - the stale "none ships today" comments in `ToolEmit` :89 and `ToolSetFull` :193;
  - client: `agent-context`, `agent-status`, `account-preferences` (:527), `proposal-view`, `strings`, `self-protection` (`ATELIER_REFUSALS` +3), `citations`.
- [ ] Client tests: `shell/agent-picker.spec.ts` (new), `panel.spec.ts`, `proposal-card` spec, `sql-query.page.spec.ts`, and the `ui/tools` test beside `outputLinesOf`.
- [ ] Browser specs (new):
  - `ui/browser/agent-picker.browser-spec.mjs`: two enabled `turnprobe` definitions through `runIris`; pick, header, chip, egress line, reload; DW-1337 on the open menu in both themes; the pick is cleared in `after`.
  - `ui/browser/agent-sql.browser-spec.mjs`: the key enabled through `GovernanceFixture`; a stub turn proposes an UPDATE; the card's rows and sentence; Confirm; the table read back; the key restored.

- [ ] `src/OcuPilot/Api/Definitions.cls` :5-10 (lead, spec gate): correct the class header in place, so it names the floor as it stands since Story 19.12 (`%Development` admitted) and lists every projected key, `id` included. Comment only.

**Acceptance Criteria:**

- **AC1 (Integration):** Given two enabled definitions on the throwaway with A the default, when a person picks B in the panel header, then:
  - the header names B;
  - the context chip shows B's provider and host;
  - the next turn's provider call goes to B's endpoint, which the stub records under B's model tag;
  - its egress line names B's provider and host.
- **AC2:** Given a pick, when the person reloads or signs in again, then the pick holds. Another user's turns still use the default. The Definitions list's Default column is unchanged, and no audit event is written.
- **AC3:** Given a pick whose definition is then disabled or deleted, when a turn starts, then the turn, the chip and the header use the default. Re-enabled, the pick applies again.
- **AC4 (restraint, ruling 3):**
  - Given a read-only default and a picked read/write definition, when the turn proposes a write, then it mints, and Confirm judges it by the picked definition.
  - Given the same pick with enforced read-only, the user's own read-only (14.5) or the kill switch on, when the turn runs, then the write is blocked or the turn refused, exactly as without a pick.
- **AC5:** Given a conversation with turns, when the person picks another definition, then a new conversation starts and its live proposals are canceled. A turn in a conversation whose earlier entries ran under another definition replays none of them (`TurnProvider.Recorded`).
- **AC6:**
  - Given one enabled definition, when the panel renders, then the header names it as text with no menu.
  - Given a running turn, when the person reaches the picker, then it is `aria-disabled` with "Stop the turn first" and choosing is impossible.
  - Given the header and the open menu, when DW-1337's invariants are checked in light and dark, then both pass.
- **AC7:** Given a turn on SQL query in USER, when the agent calls `explorer.sqlquery.read` with a SELECT and values, then the provider's next request carries the columns and rows as a framed `tool_result`:
  - bound values;
  - at most `maxRows` rows and the AD-24 cap;
  - cells cut at 1,000 characters;
  - truncation reported;
  - credential-named columns `[redacted]`.
- **AC8:** Given `explorer.sqlquery.run`, when the provider tool list, the dispatch lookup and SQL query's screen context are read, then the run and the read are in each. With the key at its baseline `false`, the agent's UPDATE answers `GOVERNANCE.DISABLED` and the table is unchanged.
- **AC9 (DW-2004):** Given the key enabled, when the agent proposes `UPDATE OcuProbe196.Granted SET Num = 3`, then:
  - the card shows the destructive treatment, no typed name, the statement, values, `Kind` dml, `StatementType` 3, the table, and "It changes rows in <tables>, and cannot be undone from OcuPilot.";
  - Confirm changes the table once and the card shows "<n> rows changed";
  - a marker carrying no statement text and a ledger row record it;
  - a person's console Run of the same statement reads the same guard on its fresh read.
- **AC10:** Given the agent's tools, when a code-carrying statement is proposed, then it is refused `EXPLORER.SQL.AGENTCODE` with nothing minted, while the console still runs it after its confirmation.
- **AC11 (AD-11 rule 5):** Given a probe row holding the seeded instruction, when the agent reads it through `explorer.sqlquery.read`, then the turn makes no proposal and no navigation, and posts only to its definition's endpoint.
- **DW-1964:** Given a principal granted SELECT on `Granted` alone, when its agent reads `Hidden` or proposes a change to it, then the read answers SQLCODE -99 with no row, and the mint is refused `EXPLORER.SQL.NOTPREPARED`. A source pin shows neither new class names `AtelierPort` nor `action/query`.

## Spec Change Log

- 2026-10-05, lead (spec gate): the plan's decisions are accepted tier-1 and the twelve spine drafts are written (AD-7, AD-8, AD-15 seventeenth case, AD-21, AD-24, AD-36, AD-39, AD-42, AD-50, AD-51, AD-53, AD-61; AD-8's and AD-53's unadvertised lists corrected at origin against `ADVERTISED = 0`). Task added: `Api/Definitions.cls`'s stale header. DW-2096 and DW-2093 take occurrences, not tasks (owner's sheet; the epic's burn-down).

## Review Triage Log

### 2026-10-05 — Review pass

- verdicts: 14 findings — high 0, medium 3, low 8, false 1, maybe-false 2
- findings:
  - `[medium]` `[patch]` DDL, CALL and undeclared consequence mapping never run — added `SqlAgentWrite.TestTheConsequenceNamesTheKindOfStatement` (DDL mint plus the four kinds); mutation recorded (run 1641 red).
  - `[medium]` `[patch]` AC5 client leg (pick with turns starts a new conversation) untested — added a `panel.spec.ts` case; mutation applied, red, reverted.
  - `[medium]` `[patch]` AC4 per-user read-only with a pick untested — added a leg to `AgentPick.TestAPickedDefinitionIsStampedAndStillRestrained` (`AGENT.READONLY.USER`).
  - `[low]` `[patch]` stale doc-comment mutation naming a `Verdict` change the spec says had nothing to skip — comment now names only the stamp leg as load-bearing.
  - `[low]` `[reject]` `AgentPick.OwnAuditRows = 0` has no positive control — the audit source is registered by the installer and `AgentPick`'s own mutation of the default-marker leg shares the setup; a fix adds a second audit probe for no everyday risk.
  - `[low]` `[reject]` DW-1337 openMenuViolations has no positive control — the gate caught the real overflow during implement (menu moved to the panel); an added control is more complexity than the risk warrants.
  - `[low]` `[reject]` client mutations written, not applied for `proposal-view`, `turn`, `sql-answer`, `proposal-card`, picker `locked()` — each suite is exercised by its executed tests; the notes name the mutation; low and no everyday harm.
  - `[low]` `[reject]` source-text assertions on `.cls` literals — the spec asks for the source pin; behavior is pinned separately.
  - `[low]` `[reject]` `TestAPrincipalWithoutThePrivilege...` lacks a positive prepared leg — the `Granted` UPDATE minted by the same fixtures in `SqlAgentWrite` covers it.
  - `[low]` `[reject]` `Loop.TurnDefinition` and `Turn.GuardedDefinitionOf` lack direct tests — covered through `AgentPickTurn`; the extra row read is harmless.
  - `[low]` `[reject]` `panel.ts` `agentInForce` fallback uncovered — negligible.
  - `[false]` `[reject]` `ReadTool` "one hundred and sixty-five" sentence inconsistent — pre-existing and untouched by this diff.
  - `[maybe-false]` `[reject]` Intent audit: `Mint.DefinitionInForce` falls back to `ResolveDefault` with no turn key — the agent path always carries a turn key; a mint with none has no turn to pick for, and the fallback is the spec's own.
  - `[maybe-false]` `[reject]` Intent audit: `Restraint.Resolved` now honours the pick while `Verdict` is unchanged — `Resolved` feeds the footer and Guardrails, which the contract lists as readers of the pick.

## Design Notes

**Decisions (ruled, or the plan's under the rulings):**

- **One read tool and one write tool, not a kind-split (ruling 2; AD-3/AD-22, AD-30, AD-53).**
  - A tool's kind is fixed at definition (`Base.KIND`, `Registry.KindProblem`).
  - A tool whose kind followed the statement would be a write. That would put the agent's queries behind the run's `false` key, under the read-only preset, and under AD-30's restraint, which `Dispatch` applies to writes alone.
  - As a read, `explorer.sqlquery.read` stays available under read-only, and no key governs it (`Policy.Resolve`: a read is always allowed).
  - AD-53 holds: the run is still the one operation behind the console's confirmed Run and the agent's confirm. The read calls the console run route's own checks (`SqlConsole.Check`, then `Run` in `query` mode), so the agent's query and the person's Run cannot diverge.
  - Like `logs.applicationerrors.read`, the read is a standalone tool, not a declared read (AD-36).
- **The key stays `false` (ruling 1).** No key is added: a read has none.
- **AD-7's limit (DW-2003) is stated, not closed.**
  - The read runs only the `query` kind, and SqlPort rolls back a transaction a run leaves open.
  - A function or procedure the query calls still runs as the user in the turn job and can change state (Task 0 measures it). The SQL index row its prepare writes is AD-7's fifth shape.
  - Closing the limit would need a SQL parser, which 19.6 rules out. A rolled-back wrapper was rejected unmeasured, because it would also roll back cached-query compile writes (inference).
  - The instance's EXECUTE privilege remains the gate. That is the same limit the console and the classic page carry.
  - **Task 0, measured on `ocupilot-a2-ci`:** a query selecting an SQL function that sets `^OcuProbe1911` set the global (value 1). It ran through `SqlPort.Run` in `query` mode as the session user, not through a stub turn, so the turn job's own identity is not separately measured. The function and the global were removed afterwards.
- **Rows to the model (ruling 2).**
  - They pass AD-24's bound (the row cap and 65,536 in total; SqlPort's own 1,000-character cell cut stands for the per-field bound, since `Bound` does not cut array rows) and AD-60's sanitizer, as untrusted content (AD-11).
  - Added as a backstop that can only add redaction: every cell of a column whose name matches the Conventions › Secrets pattern is masked.
  - Named limit: an arbitrary table has no classification (AD-3), so a secret under another name, an alias or an expression reaches the model.
  - The agent's query reads whatever its caller's SQL privileges read, `INFORMATION_SCHEMA`'s statement tables included. AD-61 rule 7 binds OcuPilot's own statement reads, not a caller's statement, and DW-2096 is the pending decision on a credential literal in statement text.
- **What the agent supplies.** `statement`, `parameters` (an array of strings) and `maxRows`, in the turn's namespace. The run also takes the literal `Target`.
- **Code-carrying DDL is refused for the agent** (AD-53's product call: "the agent never authors code"). This covers types 35–38, 43 and 67, plus a `COMPUTECODE` field, which carries ObjectScript in a CREATE or ALTER TABLE. It is a third fail-closed text rule, for the agent only.
- **A confirmed statement's SQL error stays `output` (as 19.6).** The confirm answers OK with the outcome. The card shows the status line, and the SQLCODE and message. The marker carries no statement text (its target is `(class, <ns>, sql)`). The ledger keeps the tool call's `Arguments` as it does for every tool, the statement among them because the model wrote it, and never the run's rows, SQLCODE or message (AD-39's sixth exception).
- **The target stays `(class, <ns>, sql)` (AD-13, AD-34).** Statements in one namespace depend on each other through its schema, so a confirm cancels its siblings and the agent proposes the next one against the moved schema.
- **The picker (ruling 3; AD-42, AD-50).**
  - The pick is a `shell` member, the smaller of the two AD-50 precedents. It needs no new kind, route or `ConfigGate` row.
  - Resolution is on the instance, at turn start and in the context route. The client never names the definition, so the chip, the header and the turn cannot disagree (AD-42's "cannot disagree" invariant).
  - "One conversation, one definition" keeps data a turn sent to one provider (a marked-local model, say) from replaying to another (AD-42's purpose).
  - FR-24 already lets every user see definitions for selection, and per-user read-only (14.5) is the administrator's per-user control.
- **DW-2004 is closed by `READSVALUES`, not by editing the screen action's order.** Other tools' screen-action deltas need their fresh read first (`ExplorerImport`). Confirm's re-read already passes the payload through `PortQuery`, while the mint seeds its read with the id alone (Mint.cls:165–167), so today's agent mint would read an empty guard and every proposal would close target-changed (inference).

**Strings** (5 literals; 2,659 + 5 of 2,700, no cap raise). One Fixed-strings row after :603:

- "Agent definition: <name>"
- "<provider> · <model>"
- CHANGES: "This statement changes something, so it is proposed and runs only once a person confirms it."
- AGENTCODE: "A statement that creates a function, method, procedure, query, trigger or aggregate, or a COMPUTECODE field, carries code, which a person writes and runs on SQL query."
- NOTPREPARED: "The instance did not prepare this statement, so it is not proposed; its SQLCODE says why."

Where: the panel header's picker (Story 19.11) and the SQL tools' refusals. The four consequence sentences and "Default", "Stop the turn first", "<n> rows changed", "Done", "SQLCODE <code>" and the stopped lines are reused.

**Bundle:** the picker and the card's SQL slot cross the 2943kB warning, so re-base it to the measured build (DW-1166). The addition is well under 3,800 kB (inference: about 5–10 kB).

**Spine amendments (drafts, for the lead's gate, Rule 20):**

- **AD-8** (correct at origin): "save the unadvertised tools AD-53 names (today System Explorer's two Save tools (Story 19.3), License key's activation (Story 18.6) and the data browser's save (Story 19.8); Story 14.2 advertised `security.auditing.purge` and Story 19.11 `explorer.sqlquery.run`, each behind a governance key disabled by default)".
- **AD-53** (ordinal clash): replace "Story 14.2 did so … The third is License key's activation" and the 19.6/19.8 ordinals with: "The unadvertised tools today are System Explorer's two Saves (Story 19.3), License key's activation (Story 18.6) and `explorer.sqldata.save` (Story 19.8). `explorer.sqlquery.run` (Story 19.6) was advertised by Story 19.11 with its key still `false` (AD-22 changes no shipped value), and for the agent it refuses a statement that carries code (`EXPLORER.SQL.AGENTCODE`)."
- **AD-42:** "The chip forecasts the next turn from the caller's definition in force: their pick (AD-50) while it names an enabled definition, else the default. The line reports the turn that ran, so after a pick or a marker move they may differ for an earlier turn." Then: "Moving the default marker … selects the endpoint and credential a turn uses for every user without an enabled pick; a pick is a preference, moves no marker and is not audited."
- **AD-15**, the seventeenth named case: "an agent-proposed SQL statement (`explorer.sqlquery.run`, Story 19.11): the vendor records no event (AD-53's named gap fifteen), so the agent's marker is that write's only record, and it carries no statement text."
- **AD-7:**
  - the fifth shape adds "So does each distinct statement the agent's SQL read prepares in a turn (Story 19.11)";
  - new: "**The agent's SQL read runs in the turn job and never mutates by OcuPilot's classification**: only the `query` kind runs. A function or procedure the query calls runs as the user and can change state (AD-21's named limit, DW-2003; measured by Story 19.11's Task 0)."
- **AD-21**, the console case: "So does the agent's statement through `explorer.sqlquery.read` and `.run` (Story 19.11), with the same named limit."
- **AD-24:** "A conversation's earlier turns reach the model as their user message and final reply only, and only those that ran with the turn's own definition (an entry with none recorded included) (Story 19.11)."
- **AD-36:** "**The agent's own SQL query is a read tool, not a declared read** (`explorer.sqlquery.read`, Story 19.11): its rows, SQLCODE and message reach the model, bounded by AD-24 and through AD-60, and the turn's own tool step (AD-33), as every read tool's result does; every cell of a column the credential pattern names is masked. Named limit: an arbitrary table carries no classification (AD-3). A console run's and a data browser page's payloads stay screen-only."
- **AD-39**, the sixth exception: append "except the agent's own query's answer (Story 19.11, AD-36)".
- **AD-50:** "The agent definition a user picks is the `shell` member `agentDefinition`, a definition id validated at its write and resolved at every turn start and context read (Story 19.11)."
- **AD-51:** "**A tool may declare that its fresh read is composed from its own values** (`READSVALUES`, Story 19.11): the mint passes its arguments and a screen action its declared values through `PortQuery`, as Confirm's re-read passes the stored payload. `explorer.sqlquery.run` declares it (DW-2004)."
- **AD-61**, Story 19.6's case: append "Story 19.11's agent tools reach `SqlPort` through the console's own checks (`SqlConsole.Check`), the read in the turn job and the run through the write path."

**ADs:** AD-3, AD-6, AD-7, AD-8, AD-9, AD-10, AD-11, AD-13, AD-15, AD-21, AD-22, AD-24, AD-30, AD-31, AD-33, AD-34, AD-35, AD-36, AD-39, AD-40, AD-41, AD-42, AD-50, AD-51, AD-52, AD-53, AD-58, AD-59, AD-60, AD-61.

**Integration ACs:** AC1, which drives the turn job, the chip and the browser on the real instance; and AC9, which drives the card and Confirm in the browser.

**Consumes:**

- `SqlPort`, `SqlConsole.Check`, `Prohibited.SqlStatement`;
- the governance gate and `GovernanceFixture`;
- `Restraint.Verdict`, `Pref`, `/account/preferences`, `/agent/definitions`, `/agent/context`, `ProviderPort.EgressOf`;
- `TurnWireFixture`, `TurnProvider`, the proposal card.

**Consumed-by:** none planned. CP-36's per-area named agents and About bubble are unplanned.

**Footprint (Rule 11).** Checked against `.worktrees/epic-18` at `b389a30be6cc8264b503acfc3ef56c68009dcbf0` (diff and `status -s`; 18.23 in rework, 18.24 is wallet secrets).

- **Contended, add-only:** `strings.ts`, `proposal-view.ts`, `_components.scss`, `AtelierError.cls`, `scripts/ci-throwaway.sh`, the roster rows in `SurfaceCoverage`, `ToolEmit`, `ToolRoundTrip`, `Governance` and `DraftRegistry`, and the Fixed-strings row after :603.
- **Contended, not add-only (for the lead):**
  - `ReadTool`'s count (both epics add a read);
  - `ui/angular.json` with its test (both re-base);
  - EXPERIENCE.md :153, :624, :626, :702 and :149, edited in place;
  - the spine.
- **Not contended:** `Baseline.cls` (unchanged) and `Prohibited.cls` (unchanged). Epic 18 touches no definition, panel, preference, turn or mint file.
- **Outside `paths_hint`** (`footprint_extensions`): EXPERIENCE.md and `scripts/ci-throwaway.sh`.

**Ledger inbox:** DW-2004 is addressed by AC9 and the `READSVALUES` task.

**Ledger candidates for the lead:**

- DW-2096 occurrence: the agent's SQL read can return statement text from `INFORMATION_SCHEMA`.
- DW-2093 occurrence: the counts move again (26 reads, 11 writes), and the method keeps its name.
- Low, `wontfix` or burn-down: `Api/Definitions.cls:5-10`'s header omits `%Development` and lists five projection keys without `id`.

## Verification

Load source into `ocupilot-a2-ci` and never restart it:

1. `rsync -a --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-19/src/ /tmp/ocupilot-a2-ci/src/`
2. In `docker exec -i ocupilot-a2-ci iris session iris -U HSCUSTOM`, run `$System.OBJ.LoadDir("/opt/ocupilot/src","ck",.tErrors,1)`, then check the status and `tErrors`.

**Stateful test classes run one at a time**, each landing in `%UnitTest_Result` before the next. Never re-submit after a client-side timeout. Every probe definition, principal, table, function, global and governance setting is removed or restored and checked. Any `.env.local` key stays unused: the tests are stub-based.

**Commands:**

- `uv run scripts/check-objectscript.py && uv run scripts/test_check_objectscript.py` (loop): expected green.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-a2-ci --class OcuPilot.Test.<Class>` (loop), one class per call: expected green. Run it for:
  - `SqlAgentRead`, `SqlAgentWrite`, `AgentPick`, `AgentPickTurn`, `InjectionChannels`;
  - `SqlConsoleWrite`, `SqlPort`, `SqlPortLive`, `SqlConsoleRoutes`;
  - `ExplorerDescriptor`, `ReadTool`, `DeveloperFloor`, `ToolRoundTrip`, `ClassicPageGate`, `Governance`, `GovernanceBaseline`, `DraftRegistry`, `Guardrails`;
  - `PrefState`, `PreferencesWire`, `Restraint`, `ReadOnlyForYou`, `TurnContext`, `TurnWire`, `EgressLine`, `EgressLocal`, `AgentWireSecurity`.
- `cd ui && npm run test:tools && npx ng test --include 'src/app/shell/**/*.spec.ts' --include 'src/app/areas/system-explorer/**/*.spec.ts'` (loop): expected green.
- Browser (loop). Build and deploy first: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-a2-ci:/durable/iris/csp/ocupilot/`. Then run each file alone with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52780 OCUPILOT_BROWSER_CONTAINER=ocupilot-a2-ci node --test --test-concurrency=1 browser/<file>`, for `agent-picker`, `agent-sql`, `context-chip`, `panel`, `system-explorer-sql-query` and `a11y-structural-invariants` (`.browser-spec.mjs`): expected green. The full browser suite is CI's.
- `bash scripts/lint-docs.sh && cd ui && npm run test:tools` (loop, after the EXPERIENCE.md edit): expected green.
- `cd ui && npm test` (once, before dev_complete): expected green, with the budget re-based.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-a2-ci`, the full ObjectScript sweep, one class at a time (once, before dev_complete): expected green apart from the known `WireSecurityRead` (DW-1554) and `Retention` (DW-1929) residue.

**Mutations (Rule 19)**, each applied on `ocupilot-a2-ci` with the class and its descendants recompiled, observed red, reverted byte-identical (compared with `cmp`) and recompiled:

- mutation: AC1: `Api/Turn.cls` resolves `ResolveDefault` again. Red: `AgentPickTurn` 3 of 3 (run 1591).
- mutation: AC2: the `agentDefinition` write also calls `SetDefaultGuarded`. Red: `AgentPick.TestAPickIsValidatedStoredAndMovesNothing` (run 1592).
- mutation: AC3: `ResolveFor` skips the enabled check. Red: `AgentPick` 2 of 5 (run 1594); `AgentPickTurn` stays green, so the disabled-pick leg lives in `AgentPick`.
- mutation: AC4: `Mint.DefinitionInForce` no longer reads the turn's definition. Red: `AgentPick.TestAPickedDefinitionIsStampedAndStillRestrained` (run 1596). `Restraint.Resolved` back to `ResolveDefault`. Red: `AgentPick.TestTheFooterAndGuardrailsReadThePick` (run 1597). `Verdict` takes no definition-dependent per-user source, so the planned second mutation had nothing to skip.
- mutation: AC5: the `HistoryMessages` filter removed. Red: `AgentPickTurn.TestAConversationDoesNotReplayAnotherDefinitionsTurns` (run 1598).
- mutation: AC6: the one-option text branch removed from `agent-picker.ts`. Red: `agent-picker.spec.ts` "one enabled definition reads as its name". The bundle was not involved, so no redeploy applies.
- mutation: AC7: the `IsCredentialName` mask disabled. Red: `SqlAgentRead` 2 of 7 (run 1601). The first value spliced into the text. Red: `TestAQueryAnswersRowsWithItsValuesBound` (run 1602).
- mutation: AC8: `ADVERTISED` 0 on the run. Red: `SqlConsoleWrite` 2 of 6 (run 1603) and `ExplorerDescriptor` 2 of 15 (run 1604).
- mutation: AC9: `READSVALUES` 0. Red: `SqlAgentWrite` 3 of 4 (run 1605).
- mutation: AC9 consequence: `Consequence` answers the data-change code for every kind. Red: `SqlAgentWrite` 2 of 5 (run 1641); the reverted tree is green.
- mutation: AC5 client: delete the `onNewConversation()` call in `panel.ts` `onChooseAgent`. Red: `panel.spec.ts` "picking another definition while the conversation has turns starts a new conversation".
- mutation: AC10: `CarriesCode` answers 0 for the type test. Red: `SqlAgentWrite` 3 of 4 (run 1606).
- mutation: AC11: `Loop` adds the last tool_result blocks to the system prompt. Red: `InjectionChannels` 16 of 16 (run 1607), including the SQL row source; the reverted tree is green (run 1608).
- mutation: DW-1964: `%Prepare(text, 0)` in `SqlPort.Prepared`. Red: `SqlAgentRead.TestAnUnpreparedStatementIsAnErrorOutcome` (run 1599) and `SqlAgentWrite` 2 of 4 (run 1600).
- mutation: client cases: each of `proposal-view.test.mjs`, `turn.test.mjs`, `sql-answer.test.mjs`, `proposal-card.spec.ts` and `panel.spec.ts` carries its own `Mutation (Rule 19)` note; they are written, not applied, because a client mutation needs a rebuild and redeploy each.

## Auto Run Result

Status: done
Blocking condition: none

**Summary.** The agent gains `explorer.sqlquery.read` (a standalone read tool: `SqlConsole.Check`, then `SqlPort.Run` in `query` mode, credential-named columns masked, `[redacted]` named in `redactedColumns`) and advertises `explorer.sqlquery.run` (key stays `false`, `ExplorerSqlRunMint` refuses input, unprepared, a read, code, bad value counts), with `READSVALUES` composing its fresh read from its own values (DW-2004). The panel header gains a per-user agent picker; the pick is the `shell` member `agentDefinition`, resolved on the instance by `Agent.ResolveFor` at turn start, frozen on the turn, and read back by the proposal stamp, the step boundary, the restraint and the replay filter.

**Task 0.** Recorded in Design Notes: the function set the global.

**Measures.** Initial bundle 2,953,622 bytes (JS 2,749,972 and CSS 203,650); `maximumWarning` re-based from 2943kB to 2954kB in `ui/angular.json` and `ui/tools/angular-json.test.mjs`, under the 3,800 kB stop. Strings: 5 new Fixed-strings rows (2,664 literals by the table; `STRINGS` holds 2,665 keys), under the 2,700 cap.

**Verification** (all on `ocupilot-a2-ci`, current `src/` loaded first). ObjectScript, one class per call, run ids from `%UnitTest_Result` via `ci-runner`: `SqlAgentRead` 7 (1609), `SqlAgentWrite` 4 (1614), `AgentPick` 5 (1611), `AgentPickTurn` 3 (1612), `InjectionChannels` 16 (1608), `SqlConsoleWrite` 6 (1615), `SqlPort` 11 (1616), `ExplorerDescriptor` 15 (1617), `ReadTool` 28 (1618), `ToolRoundTrip` 2 (1619), `ToolEmit` 11 (1620), `DeveloperFloor` 10 (1621), `SurfaceCoverage` 4 (1622), `SqlPortLive` (1623), `SqlConsoleRoutes` (1624), `ClassicPageGate` (1625), `Governance` (1626), `GovernanceBaseline` (1627), `DraftRegistry` (1628), `Guardrails` (1629), `PrefState` (1630), `PreferencesWire` (1631), `Restraint` (1632), `ReadOnlyForYou` (1633), `TurnContext` (1634), `TurnWire` (1635), `EgressLine` (1636), `EgressLocal` (1637), `AgentWireSecurity` (1638): all green. The full ObjectScript sweep was not run (Rule 29). `check-objectscript` 0 problems and its harness 146 tests green. Client: `npm test` green (1,836 tools tests; 2,497 component tests in 193 files). Browser, each file alone: `agent-picker` 2, `agent-sql` 1, `context-chip` 8, `panel` 12, `system-explorer-sql-query` 3, `a11y-structural-invariants` 12, plus `egress-line` 4 and `governance` 1: all green. Mutations: see Verification.

**Rosters updated outside the file list:** `ExplorerDescriptor` (counts, writers, context tools), `ReadTool` (277), `DeveloperFloor` (TOOLS), `ToolRoundTrip` (REFUSEEMPTY), `ToolEmit` (SQL read branch), `SqlPort` (advertised 101), `SqlConsoleWrite` (advertised legs), `SqlConsoleProbe`, `InjectionSeed` and `InjectionChannels` (source o), `self-protection.test.mjs` (three refusals), `scripts/ci-throwaway.sh` (`AgentPickTurn` and `SqlAgentRead` in the principals and test-provider rosters), `Api/Definitions.cls` header, EXPERIENCE.md rows (:149, :153, :604, :624, :626, :702) and the `:644` citation that moved to `:645`.

**Review pass (implement stage).** Verification-gap and intent-alignment layers: 14 findings (medium 3, low 8, false 1, maybe-false 2). Patched 3 medium: a DDL/CALL consequence test (`SqlAgentWrite.TestTheConsequenceNamesTheKindOfStatement`, run 2120 green), a per-user read-only leg in `AgentPick` (run 1640 green), and the AC5 `panel.spec.ts` case (mutation applied, red, reverted); one stale doc comment fixed. Ten rejected with reasons in the Review Triage Log. Follow-up review recommended (two or more medium patched); named unverified risk: the client-side mutations for `proposal-view`, `turn`, `sql-answer`, `proposal-card` and the picker's `locked()` guard are written but not applied.

**Sweep (once, before finalize).** `ci-runner` over all ObjectScript classes on `ocupilot-a2-ci`: 476 classes, 3,848 tests. Red: the five encryption write classes (empty, unarmed `OCUPILOT_ALLOW_ENCRYPTION_CONFIG`) and `WireSecurityRead` (DW-1554), all known residue. `SqlAgentWrite` and `SqlConsoleWrite` read the instance-wide ledger and failed on two rows the new consequence test left; the test now deletes its turn's ledger rows and both classes are green on re-run (runs 2120 and 2122). `check-objectscript` 0 problems; `npm run test:tools` 1,836 pass; `lint-docs` clean.

**Deferred or open.** The client-side mutations in `proposal-view`, `turn`, `sql-answer`, `proposal-card` and `panel` tests are written in the tests, not applied (each needs a rebuild and redeploy). The picker menu is positioned against the panel, not its own control, so the DW-1337 overflow gate holds at 720 and 1280.
