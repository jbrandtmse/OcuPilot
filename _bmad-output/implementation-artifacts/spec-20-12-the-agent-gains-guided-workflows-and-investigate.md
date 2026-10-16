---
title: 'Story 20.12: The agent gains guided workflows and Investigate'
type: 'feature'
created: '2026-10-15'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
warnings: [multiple-goals, oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** The agent answers one request at a time. A developer-administrator facing a stuck production has no rehearsed path the agent follows step by step. The iris-execute-mcp-v2 sibling's eleven MCP prompts (the "harvested prompt set") have never been brought into OcuPilot.

**Approach (this spec is Part A, the story's first and third criteria; Design Notes › Split charters Investigate, the second, and asks the orchestrator):**

- **A catalog of guided workflows, as data.** One class holds the workflows as JSON: an id, a purpose, ordered steps naming the read and write tools each uses, and a finish. Adding a workflow means adding an entry, never a code path.
- **Offered as a suggested prompt.** A screen offers a workflow through a suggested prompt whose new `workflow` key names it. Choosing that prompt sends the turn with `workflow` in its body.
- **The workflow chip.** While a workflow is active, the panel shows a chip above the composer: Continue, gated while a proposal is live, and End workflow.
- **The ordinary turn follows the steps.** The loop opens with a synthetic `workflow` call and result beside screen context. The result carries the steps, plus how the person decided the previous turn's proposals.
- **The dispatcher holds two rules in a workflow turn.** It refuses a write the steps do not name, and it refuses a second proposal in the same turn.
- **Writes are unchanged.** Each write is an ordinary proposal through the existing mint, card and Confirm. A workflow is therefore a sequence of confirmations, and every gate still runs at the write.

## Boundaries & Constraints

**Always:**

- **The catalog is data.** It lives in `XData Catalog` of `Kernel/Agent/Workflow.cls`.
  - It holds the nine workflows of Design Notes › Catalog.
  - Each step's tools resolve on the instance as the kind they are listed under.
  - Ids match `^[a-z][a-z0-9]*$`. No id is a harvested prompt name, and no text names an `iris_` tool.
  - All text is ASCII.
- **A workflow write is an ordinary write.** It runs the write tool's `View`, then `Mint.Mint`, the card, and `POST /proposal/:id/confirm`. The prohibited set, governance and both switches are evaluated where they are today: at the call and inside Confirm's transition (AD-40).
- **The turn body's `workflow`.** It is optional. When present it must be a catalog id, otherwise the start answers 422 `WORKFLOW.UNKNOWN` on field `workflow`. It is validated before the reserve, recorded on the turn row at begin, and read from that row by the loop and the dispatcher.
- **What the workflow result carries.** Catalog constants, plus `previous`: the closed-vocabulary facts `{tool, state, closedReason, readBack}` about the proposals of the conversation's turn before, at most 10. It carries no instance text, so it adds no untrusted source (AD-11).
  - It passes `Sanitize.Results` with the screen-context result.
  - It is never advertised. A model call named `workflow` answers `TOOL.UNKNOWN`.
- **The dispatcher's two refusals.** In a workflow turn, a write tool that no step's `writes` names is refused `WORKFLOW.NOTASTEP`. A write call after the turn already holds a proposal is refused `WORKFLOW.ONECHANGE`. Both are tool results, and neither mints anything.
- **Which sends carry the workflow.** Every send while the chip shows carries its id: a typed message, Continue, a suggested prompt, Explain, Fix it and Re-propose.
  - A workflow prompt replaces the active workflow.
  - End workflow, a new conversation and the end of the session clear it.
  - A send that is not accepted changes nothing.
- **Continue.** It is `aria-disabled`, never hidden, while a turn runs or any proposal card is live. Its reason is named. It never confirms, cancels or closes a proposal.
- **Strings and shared files.** New strings go in `strings.ts` and EXPERIENCE.md's Fixed strings, with unique values. Shared files take add-only edits (Design Notes › Contended files).
- **The bundle.** The initial bundle stays under 2500 kB. It measured 1.96 MB; this story is expected to add about 6 kB (inference).

**Never:**

- A new engine, scheduler or background process.
- A turn that waits for a confirm.
- A confirm path other than the existing route.
- A control that confirms or cancels more than one proposal.
- An automatic continue after a confirm.
- A new tool, governance key, route, screen, entity type or descriptor.
- Per-workflow text in the system prompt. `BUILTIN` stays one constant.
- Production `clean` or `killAppData`.
- Workflows for `run-external-backup` or `promote-environment-change`. Their tools do not exist (Design Notes › Named limits).
- Investigate (Part B).
- Edits to `Kernel/Proposal/*`, `Kernel/Governance/*`, `Screen/Read.cls`, `Kernel/EntityType.cls`, `app.routes.ts`, `angular.json`, `.github/workflows/ci.yml`, `ui/tools/ci-shards.mjs`, `ui/tools/ci-timings.json` or `ui/tools/ci.test.mjs`.
- An edit to `Screen/Registry.cls` beyond `SuggestedPromptsProblem`'s `workflow` clause, or to `ui/tools/screen-mirror.mjs` beyond its twin, the catalog reader and the emitted `workflow` member.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Choose | A workflow prompt on a built screen | The POST /turn body carries `workflow`. The chip shows "Guided workflow" and the prompt's text. The first provider request holds the `screen_context` and `workflow` calls, in that order, before the person's message | - |
| No context | Sharing off | The opening message is `WORKFLOWPREAMBLE`, then the `workflow` call alone | - |
| Ordinary turn | No `workflow` | Byte-identical opening messages and dispatch to today's | - |
| Step write | `compileclass` turn calls `explorer.classes.save` | One proposal and one card | - |
| Not a step | The same turn calls `permissions.users.delete` | No proposal | `WORKFLOW.NOTASTEP` tool result |
| Second write | A step write after the turn minted one | No proposal | `WORKFLOW.ONECHANGE` tool result |
| Read-only workflow | `securityposture` turn calls any write | No proposal | `WORKFLOW.NOTASTEP` |
| Continue | The card has been confirmed (or canceled), and Continue is chosen | It sends "Continue the guided workflow." with the workflow. `previous` reads the proposal's `confirmed` (or `canceled`) state and its read-back verdict | - |
| Continue gated | A card is live, or a turn runs | Continue is `aria-disabled` and names "Confirm or cancel the open proposal first." (or the busy reason) | - |
| Unknown id | Body `workflow: "nosuch"`, or a non-string | Nothing is reserved | 422 `WORKFLOW.UNKNOWN`, field `workflow` |
| Unknown prompt | A descriptor prompt with `workflow: "nosuch"` | Refused alike by `Registry.Validate` and `screen-mirror.mjs` | The corpus sentence |
| End | End workflow, a new conversation, or sign-out | The chip goes; the next body has no `workflow` | - |
| Gate at write | A workflow proposal, then a key disabled, read-only, the kill switch, or a self-delete | The Confirm writes nothing | 403 `GOVERNANCE.DISABLED`, `AGENT.READONLY.ENFORCED`, `AGENT.KILLSWITCH.GLOBAL` or `PROHIBITED.CURRENTUSER` |
| Disabled key | `resendmessages` on the default policy | No card | `GOVERNANCE.DISABLED` at the call |

</intent-contract>

## Code Map

All paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-20`. Lines were read at `25e2a15eb7611698899d37229dafc0f83d3dfa2e`. Stories 20.10, 20.11, 20.32, 20.33, 20.35 and 20.34 land first, so re-anchor by symbol (Task 0).

**Turn start and job:**

- **`src/OcuPilot/Api/Turn.cls`.**
  - Field parameters are at :13-21.
  - `HandleStart` :40-177 runs the violations at :58-73, then the conversation owner, the reserve at :129, `tValues` at :143-154, the close of live proposals at :159 and `Job.Start` at :164.
  - `RenderViolation` :613 answers 422 with `detail.violations`. The sibling shape checks are `ConversationViolation` and `MessageViolation` :426.
- **`src/OcuPilot/Api/Error.cls`** holds 989 parameters, so no code goes there. `ReasonForToolCode` :1209-1246 delegates by prefix (:1224-1242), the shape for `WORKFLOW.`. The sibling families are `Api/InteropError.cls`, `Api/LockError.cls` and others.
- **`src/OcuPilot/Kernel/Agent/Job.cls`.** `Start` :40-60 (the `Job` command at :48). `Run` :92-132 calls `Turn.GuardedBegin(..., ContextRoute(pContext))` and then `Loop.Run`.
- **`src/OcuPilot/Kernel/State/Turn.cls`.**
  - Properties run to `Egress` :113. The "Added with no `SCHEMAVERSION` move" note is at :88-91.
  - `GuardedBegin` :325 takes a trailing `pContextRoute`, set at :340-345: the precedent for recording a per-turn value.
  - `GuardedDefinitionOf` :526 is the one-property reader to mirror.

**Loop, prompt and dispatch:**

- **`src/OcuPilot/Kernel/Agent/Loop.cls`.**
  - `Run` :205-376. The opening messages are built at :245-275: preamble, the synthetic `screen_context` `tool_use` (id `ocupilot_screen_context`), and the result plus the person's text through `Sanitize.Results` (:268).
  - Tools are advertised and scoped at :283-289.
  - `TurnDefinition` :156 is the turn-row read precedent.
- **`src/OcuPilot/Kernel/Agent/Prompt.cls`.** `BUILTIN` :22 (about 3,630 characters, ASCII). `CONTEXTPREAMBLE` :34.
- **`src/OcuPilot/Kernel/Agent/Dispatch.cls`.** The header order is at :3-24. Inside `AnswerOne` :182-370:
  - governance at :236-248;
  - for a write tool, the restraint verdict at :250-264, which is where the workflow refusals go;
  - pairs from :266;
  - `ErrorContent`.
- **Proposal and entry state, reused:**
  - `Kernel/State/Propose.cls`: `GuardedCountForTurn` :796 (the one-change count), `GuardedRowsForTurn` :741 and `WireRow` :878 (`tool`, `state`, `closedReason`, `readBack`).
  - `Kernel/State/Entry.cls`: `GuardedTurnKeys` :259; the newest `Seq` is the turn before.
- **The gates at the write (read only).** In `Kernel/Proposal/Confirm.cls`, the prohibited set runs through `Operation.Gate` at :299, governance at :313-326, and restraint at :328-343. `PROHIBITED.CURRENTUSER` is at `Prohibited.cls`:169, applied by `User` :2236-2237.

**Prompts and mirror:**

- **`src/OcuPilot/Screen/Registry.cls`.**
  - `SuggestedPromptsProblem` :630-678; `UnknownKeyProblem` is called at :659 and defined at :3401.
  - `SUGGESTEDPROMPTSMIN` :3007, `PROMPTGROUPKEYS` :3012.
  - The XData read precedent is :3346.
- **`ui/tools/screen-mirror.mjs`.**
  - `extractXData` :109; another class's XData is read at :382-392 (Archetype).
  - `SUGGESTED_PROMPTS_MIN` :2545, `PROMPT_GROUP_KEYS` :2551-2562.
  - `suggestedPromptsProblem` :2572-2597, with the allowed keys at :2584.
  - The interface is emitted at :3853-3856.
- **`ui/src/app/core/screens.generated.ts`** `SuggestedPrompt` :428-431 (generated).
- **`src/OcuPilot/Test/PromptCorpus.cls`** :13-27 holds 13 cases. It is run by `Descriptor.cls`:1546 and `screen-mirror.test.mjs`:794-826.
- **Descriptors gaining a workflow prompt** (each holds three today). The pins to update are in parentheses:
  - `InteropProductionList.cls`:44-46 (`InteropDescriptor.cls`:153 count, :162 group);
  - `InteropMessageList.cls`:44-46 (`InteropMessageDescriptor.cls`:46-49);
  - `Dashboard.cls`:50-52 (`Test/Dashboard.cls`:125 exact list);
  - `RoleList.cls`:61-64;
  - `ExplorerSqlQuery.cls`:43-45 and `ExplorerClassList.cls`:55-57 (`ExplorerDescriptor.cls`:114-128 requires every prompt in `webAppPromptGroupCode`);
  - `NamespaceList.cls`:47-49.

**Client (`ui/src/app/`):**

- **`core/turn.ts`.**
  - `send(message, context)` :1220. Its body is built at :1246-1253, and `context` is omitted when null.
  - `TurnEntry` :348-379. The proposal states are at :163-177.
  - `newConversation` :1607 (the store side at :1617-1630) and `endSession` :1638.
- **`core/suggested-prompts.ts`**:16-36 resolves to text only.
- **`shell/panel.ts`.**
  - The prompt blocks are at :416-436 and :468-488, with the `promptGroups` getter at :1650.
  - Handlers: `onSuggestedPrompt` :1759, `sendWithContext` :2045-2051, `onCardRepropose` :1517-1529 and `onNewConversation` :2116.
  - State: `liveCards` :1361-1369, `busy` :955 and `promptAriaDisabled` :1674.
  - The footer runs :579-629: the warning slot is at :584-597 and the composer label at :598.
- **`shell/context-chip.ts`** is the nearest component. It is spec'd inside `panel.spec.ts` (the Story 4.11 block at :1488), and the slot order is pinned at :374-377.
- **Tests.**
  - `ui/tools/turn.test.mjs`:286-307 pins body fields.
  - `panel.spec.ts`: the Story 11.3 block at :4704 (choosing a prompt at :4794-4810), `fakeTurnApi` :679-690, and the Users-list grouping at :4783-4786 (unchanged).
  - `ui/tools/suggested-prompts.test.mjs`:16-58.
- **Budgets.** `ui/tools/strings.test.mjs`:612-616 bounds the count at 3800 (it reads 3,475). `build-output.test.mjs`:236-258 holds the initial total, against `angular.json`:54 (2500kB).

**Test helpers (`src/OcuPilot/Test/`):**

- **`TurnToolsCase`.** `RunTurn` :110-125 (reserve, begin, `Loop.Run`) and `Reply` :129-143. `TurnLoopProbe.SetDispatchClass` :54 with `ToolDispatchProbe` supplies the fixture registry, which has `probe.counter.write`.
- **`TurnWireFixture`.** `Call` :354, `StartBody` :363, `StartConversation` :374, `AwaitEnd` :384.
- **`TurnProvider`.** `Script` :48, `ToolUseReply` :169, `TextReply` :157, and `Recorded(tag, n, "messages")` :150, which returns the whole messages JSON (:218).
- **The armed pattern** is `ExplorerSaveTurn.cls`:180-238, with its probe class and the governance snapshot at :83-101.
- **Policy and switches.** `GovernanceFixture` `Snapshot` :9, `Restore` :17, `Apply` :58 and `Clear` :166; `Governance.Store` :148 disables one key. `SwitchFixture.SetSwitches` :22 and `Reset` :73.
- **`ScreenGrounding`.** `Statement(n)` :20-31 holds ten statements, asserted one by one at :49-62.
- **Arming rosters** are in `scripts/ci-throwaway.sh`: PRINCIPALS `# classes:` at :241-510 and TEST_PROVIDER at :639-656. `ci.test.mjs`:2366 holds them equal to the declaring classes. An untimed class still shards, at the median (`ci-shards.mjs`:88-93).
- **Browser helpers** (`ui/browser/`): `turnprobe-spec.mjs` (`armProbeDefinition` :213, `scriptReply` :189, `nextTag` :113, `runIris` :53), `panel-spec.mjs` `signedInAt` :70, `proposal-card-spec.mjs` (`proposeFromPanel` :18, `cardViolations`), and `preferences-reset.mjs` `resetGovernancePolicy`. The probe-class shape is in `agent-code-save.browser-spec.mjs`.

**Harvest source (read only).** The prompts are under `/Users/jbrandt/git/iris-execute-mcp-v2/packages/*/src/prompts/*.ts`:

- `iris-interop-mcp`: `recoverStuckProduction`, `resendFailedMessages`, `traceMessageFlow`;
- `iris-ops-mcp`: `checkSystemHealth`, `runExternalBackup`;
- `iris-dev-mcp`: `diagnoseSlowQuery`, `deployAndTestClass`, `objectscriptReview`, `promoteEnvironmentChange`;
- `iris-admin-mcp`: `auditSecurityPosture`, `provisionProjectEnvironment`.

Its license is MIT, "Copyright (c) 2026 jbrandtmse". `ATTRIBUTIONS.md`:35-45 has no row for it, and `ui/licenses/` holds only `iris-table-editor.txt`, pinned by `ui/tools/licenses.test.mjs`.

## Tasks & Acceptance

**Execution:**

- [ ] **Task 0 (re-anchor, no code).** After the earlier Epic 20 stories merge, re-read and anchor these:
  - `Prompt.BUILTIN` and `ScreenGrounding`'s statement count;
  - `Loop.Run`'s opening builder and `Dispatch.AnswerOne`'s write branch;
  - `Error.ReasonForToolCode`'s delegation list;
  - `PromptCorpus`'s cases;
  - the seven descriptors' prompts and their pins;
  - the end of `strings.ts` and the strings bound;
  - EXPERIENCE.md :604, :627, :709 and :798, and DESIGN.md :1113-1144;
  - the two `ci-throwaway.sh` rosters.

  Confirm `Continue`, `End workflow` and `Guided workflow` are unused string values.
- [ ] **`src/OcuPilot/Kernel/Agent/Workflow.cls`** (new). This class holds `XData Catalog` (`application/json`, `{"workflows": [...]}`), per Design Notes › Catalog and the golden example. Its methods:
  - `Lookup(pId, .pFound)`, `Ids()` and `Writes(pId)` (the union of the steps' `writes`);
  - `WriteRefusal(pId, pTool, pMinted)`, which answers `""`, `WORKFLOW.NOTASTEP` or `WORKFLOW.ONECHANGE` (pure);
  - `Previous(pRows)`, which projects wire rows to `{tool, state, closedReason, readBack}` (readBack is the `verdict` or null), at most `PREVIOUSMAX` 10 (pure);
  - `Exchange(pId, pPrevious)`, which answers the result JSON `{workflow, purpose, steps:[{step, say, reads?, writes?}], finish, previous}`.

  Read the XData the way `Registry.cls`:3346 does. The doc comments name AD-11, AD-24 and Design Notes › Spine drafts' new AD.
- [ ] **`src/OcuPilot/Api/WorkflowError.cls`** (new). It holds `WORKFLOW.UNKNOWN`, `WORKFLOW.NOTASTEP` and `WORKFLOW.ONECHANGE`, with their sentences (Design Notes › Strings), plus `Codes()` and `ReasonFor()`. In `Api/Error.cls`, `ReasonForToolCode` gains one delegation line for `WORKFLOW.`.
- [ ] **`src/OcuPilot/Kernel/State/Turn.cls`.**
  - Add `Property Workflow As %String(MAXLEN = 64)` after `Egress`, with the no-`SCHEMAVERSION` note.
  - `GuardedBegin` takes a trailing `pWorkflow` and sets it beside `ContextRoute`.
  - Add `GuardedWorkflowOf(pKey, .pWorkflow)`, shaped like `GuardedDefinitionOf`.
- [ ] **`src/OcuPilot/Api/Turn.cls`.**
  - Add `WORKFLOWFIELD` and `WorkflowViolation(pBody)`. Absent or JSON null passes; a non-string or an id not in `Workflow.Ids()` is `WORKFLOW.UNKNOWN`. It is rendered by `RenderViolation` after `ConversationViolation` (:69-73) and before `Convo.GuardedOwner` (:75).
  - Set `tValues("workflow")`.
  - The header doc names four body fields.
- [ ] **`src/OcuPilot/Kernel/Agent/Job.cls`.** `Start` passes `$Get(pValues("workflow"))`, and `Run` takes a trailing `pWorkflow` and passes it to `GuardedBegin`.
- [ ] **`src/OcuPilot/Kernel/Agent/Loop.cls`.** `Run` reads the turn's workflow once (`GuardedWorkflowOf`). When it is set:
  - It builds `previous` from the conversation's newest entry's turn: `Entry.GuardedTurnKeys`, then `Propose.GuardedRowsForTurn(..., pUser)`, then `Workflow.Previous`.
  - It extends the opening builder (:245-275). The assistant's `tool_use` blocks are `screen_context` (when context is present), then `{id: "ocupilot_workflow", name: "workflow"}`. The user blocks are the results in the same order, then the person's text, through `Sanitize.Results`.
  - The preamble is `CONTEXTPREAMBLE` with context, else `WORKFLOWPREAMBLE`.

  A turn with no workflow builds exactly what it builds today.
- [ ] **`src/OcuPilot/Kernel/Agent/Prompt.cls`.** `BUILTIN` gains Design Notes › Prompt's sentence, after the explain-entry sentences. Add `WORKFLOWPREAMBLE` "Here is the guided workflow the user chose." and its accessor. The header's sentence counts follow.
- [ ] **`src/OcuPilot/Kernel/Agent/Dispatch.cls`.** In `AnswerOne`'s write branch, after the restraint verdict: when `GuardedWorkflowOf(pKey)` is set, read `GuardedCountForTurn(pKey)` and answer `Workflow.WriteRefusal`'s code through `ErrorContent` and `ReasonForToolCode`. A failed read is `TOOL.UNAVAILABLE`, logged. The header's ordered list gains the step.
- [ ] **`src/OcuPilot/Screen/Registry.cls`** (add-only). In `SuggestedPromptsProblem`, the allowed keys gain `workflow`. A present `workflow` must be a non-empty string in `Workflow.Ids()`, else "suggestedPrompts[<i>] names the unknown workflow '<value>'".
- [ ] **`ui/tools/screen-mirror.mjs`.** Its twin reads the ids from `src/OcuPilot/Kernel/Agent/Workflow.cls`'s `XData Catalog` through `extractXData`, applies the same check and sentence, and emits `workflow` on the entry and `readonly workflow?: string` on `SuggestedPrompt`. Then run `cd ui && node tools/screen-mirror.mjs`.
- [ ] **`src/OcuPilot/Test/PromptCorpus.cls`.** Add one case for the unknown-workflow sentence.
- [ ] **The seven descriptors.** Each gains the prompt entries Design Notes › Catalog lists, with `workflow`. Update their pins: `InteropDescriptor`, `InteropMessageDescriptor`, `Test/Dashboard`.
- [ ] **`ui/src/app/core/strings.ts` (add-only) and EXPERIENCE.md/DESIGN.md (add-only)**, per Design Notes › Strings and › UX drafts. Then run `cd ui && npm run test:tools` and fix any citation the inserted rows shift.
- [ ] **`ui/src/app/core/suggested-prompts.ts`.** `PromptGroup.prompts` becomes `readonly {text, workflow: string | null}[]`.
- [ ] **`ui/src/app/core/turn.ts`.**
  - Add `ActiveWorkflow {id, text}`.
  - `send(message, context = null, workflow: ActiveWorkflow | null = null)`: the body carries `workflow: (workflow ?? active).id` when either is set. A `'sent'` outcome with a `workflow` argument makes it active.
  - Add `workflow()` and `endWorkflow()`.
  - `newConversation` and `endSession` clear it.
- [ ] **`ui/src/app/shell/workflow-chip.ts`** (new, `app-workflow-chip`, `OnPush`).
  - Inputs: `text`, `continueDisabled` and `reasonId`. Outputs: `continue` and `end`.
  - It draws the label "Guided workflow", the prompt text, Continue (`aria-disabled` plus `aria-describedby` when disabled), and End workflow.
  - It carries `data-ocu-workflow-chip`.
- [ ] **`ui/src/app/shell/panel.ts`.**
  - The prompt blocks track `prompt.text`.
  - `onSuggestedPrompt(prompt)` passes `{id: prompt.workflow, text}` when set. `sendWithContext` takes an optional workflow argument.
  - Draw `<app-workflow-chip>` between the warning slot and the composer label while `turn.workflow()` is set. Continue is disabled while `busy`, while `liveCards.length > 0` or while the composer is unavailable. The live-card reason is `agentWorkflowContinueWait`.
  - `onWorkflowContinue` sends `agentWorkflowContinueMessage` with context. `onWorkflowEnd` ends the workflow and focuses the composer.
- [ ] **`ui/src/styles/_components.scss`** (add-only). Add `.ocu-workflow-chip`, using the context chip's surface tokens only, so both themes hold.
- [ ] **`ATTRIBUTIONS.md`, `ui/licenses/iris-execute-mcp-v2.txt` (new) and `ui/tools/licenses.test.mjs`.**
  - Add a Harvested code row naming iris-execute-mcp-v2, what is ported (this catalog's steps, adapted from its eleven prompts, and Story 20.30's session-trace diagram rules), "Copyright (c) 2026 jbrandtmse", MIT, and the notice file.
  - Extend the iris-table-editor test into one check per row.
- [ ] **`scripts/ci-throwaway.sh`.** `WorkflowTurn` and `WorkflowGates` join both the PRINCIPALS and TEST_PROVIDER `# classes:` lines.
- [ ] **Tests**, each with its `Mutation` note. Both armed classes create their principal, probe class and definition, and remove them in `OnAfterAllTests` and after each test.
  - **`Test/WorkflowCatalog.cls`** (new, unarmed):
    - The nine ids equal the literal roster.
    - Every `reads` name resolves as `read` and every `writes` name as `write` (`Registry.ResolveWire(WireName(..))`).
    - Every workflow is offered by at least one built screen's prompt.
    - Each `WORKFLOW.*` code resolves to its sentence directly and through `ReasonForToolCode`.
    - `WriteRefusal`'s three answers.
    - `Previous`'s projection and cap.
    - `Exchange`'s members.
  - **`Test/WorkflowLoop.cls`** (new, unarmed; `TurnToolsCase`, whose `RunTurn` gains a trailing `pWorkflow` passed to `GuardedBegin`):
    - The recorded first request's messages: context with a workflow, a workflow alone, and no workflow (unchanged).
    - A model `workflow` call answers `TOOL.UNKNOWN`.
    - In a `securityposture` turn, `probe.counter.write` answers `WORKFLOW.NOTASTEP`, and the counter is unchanged.
  - **`Test/WorkflowTurn.cls`** (new, armed `OCUPILOT_ALLOW_PRINCIPALS` and `OCUPILOT_ALLOW_TEST_PROVIDER`; `ExplorerSaveTurn`'s pattern; `TurnWireFixture.StartBody` gains a trailing `pWorkflow`), covering AC1's server half (two `compileclass` turns, each proposal confirmed over HTTP, the second turn's first request reading `previous` `confirmed`), AC2, and AC4's 422.
  - **`Test/WorkflowGates.cls`** (new, armed alike), covering AC3. Its principal holds `%Development:U` (the class saves) and the pairs `permissions.users.delete` requires, read from the registry (`RequiredPairs`) at Task 0.
  - **`Test/ScreenGrounding.cls`**: `Statement(11)` and its assertion.
  - **Client**:
    - `ui/tools/turn.test.mjs`: `workflow` sent, kept on later sends, cleared by `newConversation` and `endWorkflow`, and not activated by a refused send.
    - `ui/tools/suggested-prompts.test.mjs`: the new shape and a workflow prompt's id.
    - `ui/src/app/shell/workflow-chip.spec.ts` (new).
    - `panel.spec.ts`, Story 20.12 block: choose, Continue, gating, End, and New conversation.
    - `ui/tools/screen-mirror.test.mjs`: the corpus case, and every emitted `workflow` is a catalog id.
  - **`ui/browser/guided-workflow.browser-spec.mjs`** (new). `before` refuses `LIVE_CONTAINER`, and the probe class lives in `USER`. It covers AC1 and AC5's structural legs.
- [ ] **Roster sweep (Rule 30).** Search `src/OcuPilot/Test`, `ui/tools`, `ui/browser` and the `ui/src` specs for assertions on:
  - the seven descriptors' prompts or prompt counts;
  - `SuggestedPrompt` or `promptGroups`' shape;
  - the POST /turn body;
  - the opening messages;
  - `BUILTIN`;
  - the panel footer.

  Each changed file joins the `(loop)` set.

**Acceptance Criteria:**

- **AC1 (a guided workflow runs as a sequence of confirmations; Integration, Rule 1).**
  - **Given** the signed-in shell on `ocupilot-b-ci`, the Classes list in `USER` with the probe class, and a scripted `turnprobe` definition.
  - **When** the person chooses "Fix a class until it compiles, step by step".
  - **Then:**
    - the chip reads "Guided workflow" and that text;
    - `TurnProvider.Recorded` of the first call holds the `workflow` result for `compileclass`, with its steps naming `explorer.classes.save`;
    - the scripted save mints one card, and Confirm saves the class;
    - Continue, `aria-disabled` while the card was live, sends "Continue the guided workflow.";
    - that turn's first request reads `previous` `[{"tool":"explorer.classes.save","state":"confirmed",...}]`;
    - its scripted save mints a second card, confirmed on its own;
    - at no point does one control confirm two cards.
- **AC2 (only the steps' writes, one change per turn).**
  - **Given** a `compileclass` workflow turn over HTTP (`WorkflowTurn`).
  - **When** one reply calls `permissions.users.delete`, then `explorer.classes.save`, then `explorer.classes.save` again.
  - **Then** the results are `WORKFLOW.NOTASTEP`, a minted proposal, and `WORKFLOW.ONECHANGE`, and the turn's view holds exactly one proposal.
  - **And** a read-only workflow refuses every write `WORKFLOW.NOTASTEP` in process (`WorkflowLoop`).
- **AC3 (the gates still run at the write).**
  - **Given** workflow proposals minted in workflow turns (`WorkflowGates`).
  - **When**, before Confirm, `explorer.classes.save` is disabled (`Governance.Store`), read-only is enforced, or the kill switch is set (`SwitchFixture`), and when a `newproject` proposal deletes the turn's own principal.
  - **Then** each Confirm answers 403 `GOVERNANCE.DISABLED`, `AGENT.READONLY.ENFORCED`, `AGENT.KILLSWITCH.GLOBAL` or `PROHIBITED.CURRENTUSER`, the class text and the principal are unchanged, and the policy and switches are restored.
  - **And** with the key disabled before the call, the call answers `GOVERNANCE.DISABLED` and mints nothing.
- **AC4 (the catalog is data, offered and validated).**
  - **Given** the catalog and the seven descriptors.
  - **When** the instance validates them, the build regenerates the mirror, and a start names an unknown workflow.
  - **Then:**
    - `WorkflowCatalog` is green;
    - each descriptor validates and still holds at least three prompts;
    - an unknown prompt workflow gets the same sentence from both engines;
    - the start answers 422 `WORKFLOW.UNKNOWN` on `workflow` and reserves nothing.
- **AC5 (the chip).**
  - **Given** an active workflow.
  - **When** the person ends it, starts a new conversation, or a card is live or a turn runs.
  - **Then:**
    - End and New conversation remove the chip, and the next body has no `workflow`;
    - Continue is `aria-disabled` and names its reason, never hidden;
    - the panel with the chip and a live card passes `cardViolations` (the DW-1337 invariants) at 1280 and 720 in light and dark.

## Spec Change Log

- 2026-10-15, spec gate (runner): the orchestrator ruled Q1 (A, Story 20.36 chartered) and Q2 (A); attribution approved (the iris-execute-mcp-v2 row also credits Story 20.30's diagram port); the spine carries AD-66 and the Story 20.12 clauses in AD-5, AD-11 and AD-24.

## Review Triage Log

## Design Notes

**Governing ADs.**

- **AD-6, AD-34, AD-40 and AD-53**: every workflow write is one proposal through the unchanged mint and Confirm, with every gate at the write, and siblings closed on a confirm.
- **AD-7**: the turn job never mutates, and no turn waits for a confirm.
- **AD-10, AD-22 and AD-30**: unchanged, and evaluated at the call and at Confirm.
- **AD-11**: rule 1 (a synthetic pair, never advertised, no untrusted text) and rule 2 (no model-initiated confirm).
- **AD-24**: the workflow result counts within the context bound; `previous` is not a replay of tool results.
- **AD-60**: the result passes the sanitizer.
- **AD-39**: the `WORKFLOW.*` codes each have a sentence.
- **AD-5**: a prompt's `workflow` key is validated alike in the registry and the mirror.
- **AD-9 and AD-37**: `Turn.Workflow` is protected state, swept with the turn.
- **AD-19**: the client store.
- **AD-41**: the bounds are unchanged.

Checked and not engaged: AD-51 and AD-52 (no new write tools), AD-58 (only its verdict is read), AD-62 and AD-65 (no port change), and AD-63.

**Measured** on `ocupilot-b-ci` (2026-10-15): every one of the 50 tool names in › Catalog resolves through `Registry.ResolveWire(WireName(..))` as listed, 33 `read` and 17 `write`. No other probe ran and nothing was changed.

**Decisions:**

- **A structured prompt plus a declared step list, not an engine.** The turn already chains tool calls (iteration cap 10 by default) and already holds every write gate.
  - The new parts are data (the catalog), one synthetic pair (the explain-entry precedent: OcuPilot's own data in a result, given meaning by one system-prompt sentence) and two dispatcher refusals.
  - What follows the steps is the model. What the instance enforces is the write set and one change per turn (named limit).
- **One change per turn.** A confirm closes live siblings on the same target (AD-34), and a step's write usually depends on the last one's effect. One proposal per workflow turn makes "a sequence of confirmations" a fact of the instance, not of the model.
- **`previous`, closed vocabulary only.** Today the model never learns a proposal's outcome (`Convo.HistoryMessages` replays message and reply only). A workflow needs it. Tool, state, closed reason and read-back verdict are OcuPilot's own closed sets. The target id stays out, so the result adds no untrusted source and AD-11 rule 5's test is unchanged.
- **Offering through suggested prompts.** This reuses the per-screen grammar, the generated mirror and the panel's buttons, with no new route or catalog mirror. 21.6 and later stories offer a workflow by adding a prompt entry.
- **The chip** is the visible sign that the next send is a workflow turn. Continue is a convenience; typing continues too.

**Catalog** (id ← harvested prompt; offered on: group, string key, text; reads; writes). Every step's `say` adapts the harvested prompt's step to the tools listed, in order, and says when a write is proposed. Production `clean` is never offered (`InteropProductionRecover.cls`:10).

1. **`recoverproduction`** ← recover-stuck-production.
   - Offered on `InteropProductionList`: `promptGroupTroubleshooting`, `interopProductionsWorkflowRecover` "Recover a stuck production, step by step".
   - Reads: `interop.productions.read`, `interop.items.read`, `interop.itemstatus.read`, `interop.queues.read`, `interop.monitor.read`, `interop.itemlog.read`, `logs.eventlog.read`.
   - Writes: `interop.productions.recover`, `interop.productions.update`, `interop.productions.restart`.
2. **`resendmessages`** ← resend-failed-messages.
   - Offered on `InteropMessageList`: `promptGroupTroubleshooting`, `interopMessagesWorkflowResend` "Resend failed messages, step by step".
   - Reads: `interop.messages.read`, `interop.messageheader.read`.
   - Writes: `interop.messages.resend`, whose key ships `false`.
3. **`tracemessage`** ← trace-message-flow.
   - Offered on `InteropMessageList`: `promptGroupTroubleshooting`, `interopMessagesWorkflowTrace` "Trace a message through its session, step by step".
   - Reads: `interop.messages.read`, `interop.messageheader.read`, `interop.messagetrace.read`, `interop.itemlog.read`, `logs.eventlog.read`.
   - Writes: none.
4. **`systemhealth`** ← check-system-health.
   - Offered on `Dashboard`: `promptGroupTroubleshooting`, `dashboardWorkflowHealth` "Check this instance's health, step by step".
   - Reads: `osmgmt.dashboard.read`, `osmgmt.systemusage.read`, `osmgmt.journals.read`, `osmgmt.databasefreespace.read`, `osmgmt.licensesummary.read`, `osmgmt.locks.read`, `logs.alerts.read`, `logs.messages.read`.
   - Writes: `osmgmt.localdatabases.update`, `osmgmt.processes.terminate`, `tasks.ondemand.run`.
5. **`securityposture`** ← audit-security-posture.
   - Offered on `RoleList`: `userPromptGroupAccess`, `roleListWorkflowSecurity` "Review the security posture, step by step".
   - Reads: `permissions.users.read`, `permissions.roles.read`, `permissions.services.read`, `security.ssl.read`, `security.auditing.read`, `security.auditsystemevents.read`.
   - Writes: none.
6. **`slowquery`** ← diagnose-slow-query.
   - Offered on `ExplorerSqlQuery`: `webAppPromptGroupCode`, `explorerSqlQueryWorkflowSlow` "Find out why a query is slow, step by step".
   - Reads: `explorer.sqltablestatements.read`, `explorer.sqlcachedqueries.read`, `explorer.sqlindices.read`, `explorer.sqlquery.read`.
   - Writes: none.
7. **`compileclass`** ← deploy-and-test-class.
   - Offered on `ExplorerClassList`: `webAppPromptGroupCode`, `explorerClassListWorkflowCompile` "Fix a class until it compiles, step by step".
   - Reads: `explorer.classes.read`, `explorer.class.source`.
   - Writes: `explorer.classes.save`, `explorer.classes.compile`.
8. **`reviewclass`** ← objectscript-review.
   - Offered on `ExplorerClassList`: `webAppPromptGroupCode`, `explorerClassListWorkflowReview` "Review a class's ObjectScript, step by step".
   - Reads: `explorer.classes.read`, `explorer.class.source`.
   - Writes: none.
9. **`newproject`** ← provision-project-environment.
   - Offered on `NamespaceList`: `promptGroupGettingStarted`, `namespaceListWorkflowProject` "Set up a new project's namespace, step by step".
   - Reads: `osmgmt.localdatabases.read`, `osmgmt.namespaces.read`, `permissions.users.read`, `webapp.list.read`.
   - Writes: `osmgmt.localdatabases.create`, `osmgmt.namespaces.create`, `permissions.users.create`, `webapp.list.create`, `osmgmt.localdatabases.delete`, `osmgmt.namespaces.delete`, `permissions.users.delete`, `webapp.list.delete`.

**Golden example (one entry):**

```json
{"id": "recoverproduction", "purpose": "Recover a production that is troubled, stuck or not processing.",
 "steps": [
  {"say": "Read the production's state and each item's state.", "reads": ["interop.productions.read", "interop.items.read", "interop.itemstatus.read"]},
  {"say": "Find where messages wait and what the logs say.", "reads": ["interop.queues.read", "interop.monitor.read", "interop.itemlog.read", "logs.eventlog.read"]},
  {"say": "When it reads troubled or stuck, propose a recover first.", "writes": ["interop.productions.recover"]},
  {"say": "Read the state again; when it runs, report and stop.", "reads": ["interop.productions.read"]},
  {"say": "When it needs an update propose one; when it is still stuck propose a restart.", "writes": ["interop.productions.update", "interop.productions.restart"]}],
 "finish": "Say what changed and what still needs attention."}
```

**Prompt** (`Statement(11)`, ASCII): "A turn may also open with a workflow result: the guided workflow the user chose, with its purpose, its steps, each naming the read tools (reads) and write tools (writes) it uses, and previous, how the user decided the proposals of the turn before (tool, state, closedReason, readBack). Follow its steps in order from where previous leaves off; propose at most one change in a turn, and only with a tool that a step's writes names, then end the turn by saying what Confirm will change and that Continue resumes the workflow; when the steps are done, or a step finds nothing to change, say what you found and that the workflow is complete."

**Strings** (14 client literals, plus 3 server sentences).

- **Client** (keys in `strings.ts`):
  - `agentWorkflowLabel` "Guided workflow"
  - `agentWorkflowContinue` "Continue"
  - `agentWorkflowEnd` "End workflow"
  - `agentWorkflowContinueMessage` "Continue the guided workflow."
  - `agentWorkflowContinueWait` "Confirm or cancel the open proposal first."
  - the nine prompt texts in › Catalog.
- **Server** (in `WorkflowError`):
  - `WORKFLOW.UNKNOWN` "That guided workflow is not one OcuPilot offers."
  - `WORKFLOW.NOTASTEP` "This guided workflow makes no change with that tool; describe the change instead of proposing it."
  - `WORKFLOW.ONECHANGE` "This turn has already proposed its change; end the turn so the user can confirm it before the next."

**UX drafts (add-only).**

- **EXPERIENCE.md**:
  - after :604, a Fixed strings row for the chip's five strings and one for the nine prompts ("Story 20.12, AD-5" [ADDED 2026-10-15 - Story 20.12]);
  - a `workflow-chip` Component Patterns row after `context-chip` (:627): "above the composer while a guided workflow is active: its label and name, Continue (`aria-disabled` while a turn runs or a proposal is live, naming why) and End workflow; every send while it shows carries the workflow";
  - :709, the footer gains the chip;
  - :798, a new conversation ends the workflow.
- **DESIGN.md**: the footer bullets (:1113-1117) gain the chip, and a `#### workflow-chip` follows `context-chip` (:1142-1144), using its tokens.

**Spine drafts (Rule 20; the lead writes them at the gate):**

- **A new AD (next id), "A guided workflow is a declared step list the turn follows; every write in it is one confirmed proposal".**
  - **Binds:** Story 20.12, Part B, Story 21.6, and every later workflow; AD-6, AD-11, AD-22, AD-24, AD-30, AD-40.
  - **Prevents:** a batch approval; a workflow writing with a tool its steps do not name; a workflow defined by a code path.
  - **Rule:**
    - The catalog is `Kernel/Agent/Workflow`'s `XData Catalog`, and a new workflow is a new entry.
    - A turn names a workflow in `workflow` (422 `WORKFLOW.UNKNOWN`), recorded on the turn row at begin.
    - The loop adds a synthetic `workflow` call and result after screen context. It holds catalog constants and the previous turn's proposals as `{tool, state, closedReason, readBack}`, is never advertised, and is sanitized.
    - Dispatch refuses a write no step names (`WORKFLOW.NOTASTEP`) and a second proposal in the turn (`WORKFLOW.ONECHANGE`).
    - Every write is an ordinary proposal, gated at the write (AD-40).
    - A screen offers a workflow through a prompt's `workflow` key (AD-5).
    - The panel carries it on every send until ended, and no control confirms more than one proposal.
- **AD-5 clause:** "A suggested prompt may name a workflow (`workflow`, a catalog id), refused alike when unknown (Story 20.12)."
- **AD-11 clause:** "A guided-workflow turn adds a synthetic `workflow` call and result beside screen context, built from catalog constants and closed-vocabulary proposal facts; a model call with that name is unknown (Story 20.12)."
- **AD-24 clause:** "A workflow result counts within the total bound; its `previous` is a projection of OcuPilot's proposal rows, not a replay of earlier tool results (Story 20.12)."

**Split (`multiple-goals`; recommended).** Investigate is the story's second criterion. Its seam is clean: it needs this spec's catalog, pair and refusals, and nothing of it is needed here.

- **Part B, "Investigate from an alert or a log entry"** (the second criterion, verbatim):
  - **The control.** An Investigate control sits beside every Explain this entry: the log-viewer rows (alerts.log, messages.log, the event log and the others), the error log's row menu, the audit dialog and the log hub. It extends `core/explain-entry.ts` with a kind, under the same gate.
  - **The turn.** It sends "Investigate the selected entry" with the DW-1838 marker and `workflow: "investigate"`. That is a catalog entry with no writes, offered by no prompt, so every write is refused. Its steps gather related reads, then answer with a Recap and Hypotheses ranked most likely first, each naming its rows in backticks. A row from a citable read is a chip (AD-11's citation clause).
  - **Named limit.** Log-viewer rows (id `none`) are cited as text, not chips. Managed alerts do not exist yet (Story 21.7).
- **Order:** this story, then Part B, then 20.25.

**Gate questions (for the orchestrator):**

- **Q1, split.** *Ruled (A) by the orchestrator, 2026-10-15: Investigate is Story 20.36, chartered.* (A) This spec is Part A, and Part B becomes Story 20.36 after 20.12, before 20.25. Rule 5 ask-first: it defers a criterion. Recommended. (B) One story: the lead re-opens this spec to `draft`, and the re-plan adds Part B.
- **Q2, the set.** *Ruled (A) by the orchestrator, 2026-10-15: all nine, renamed; the two without tools are a named limit until Stories 21.2 and 21.9 land.* (A) The nine above. `run-external-backup` waits for freeze, thaw and backup history (Story 21.2), and `promote-environment-change` for environment diff and promote (Story 21.9). Recommended. (B) Only the four that need this stage's screens (`recoverproduction`, `resendmessages`, `tracemessage`, `slowquery`), with the rest added as data later.

**Rule 5 draft (Q1 A, for `epics.md`).** Story 20.12 keeps its title and its first and third criteria. The second moves verbatim to Story 20.36, inserted after 20.12 in `story_order`.

**Integration, Consumes, Consumed-by (Rules 1 and 2):**

- **Integration:** AC1. The panel's suggested prompt reads the workflow id through the generated mirror and drives a real instance to two confirmed cards.
- **Consumes:**
  - Stories 20.21 and 20.19 (`explorer.classes.save` with its confirm, and `explorer.class.source`);
  - 20.2 and 20.31 (the production and resend writes);
  - 11.3 (the prompt grammar);
  - the turn loop and dispatcher (Epic 4), governance (14.2), the switches (3.7), and AD-10's set.
- **Consumed-by:**
  - Part B (the catalog, pair and refusals);
  - Story 21.6 (extends `slowquery` with its tuning reads and offers it on its screens, by data);
  - Stories 21.2 and 21.9 (add `run-external-backup`, `promote-environment-change` and `compileclass`'s test step, by data).

**Rule 31 (extend, don't copy):**

- The workflow pair extends `Loop.Run`'s one opening builder.
- The refusals reuse `GuardedCountForTurn`; `previous` reuses `GuardedRowsForTurn` and `GuardedTurnKeys`.
- `GuardedWorkflowOf` copies `GuardedDefinitionOf`'s eight-line shape for another column. Two short readers read better than a property-name parameter.
- `WorkflowError` is one more family class, the established shape.
- `RunTurn` and `StartBody` take trailing parameters, so their callers are unchanged.
- `licenses.test.mjs` is generalized, not copied.
- `app-workflow-chip` is a new component, because the context chip has no actions.
- The tests reuse `TurnToolsCase`, `TurnWireFixture`, `TurnProvider`, `GovernanceFixture`, `SwitchFixture`, the probe-class helpers, `turnprobe-spec.mjs`, `proposal-card-spec.mjs` and `preferences-reset.mjs`.

**Contended files (Rule 11).** `git -C ../epic-23 diff --stat origin/feature/OCU-1_ocupilot-mvp...HEAD` touches these files this story also edits: `Screen/Registry.cls`, `screen-mirror.mjs` and its test, `screens.generated.ts`, EXPERIENCE.md, DESIGN.md, the spine and `_components.scss`. This story's edits there are add-only, so forward merges may conflict (inference). No Rule 11 ask.

**Named limits:**

- The model follows the steps. The instance enforces only the write set and one change per turn; reads are not restricted.
- `resendmessages` meets `GOVERNANCE.DISABLED` until an administrator enables its key (AD-22's Story 20.31 clause).
- No `clean`.
- `compileclass` has no test step (Story 21.9), and `slowquery` no show plan (Story 21.6).
- The chip does not survive a reload or a restored conversation.
- `previous` covers the turn before only.
- The ledger does not record a turn's workflow.
- Two synthetic calls in one message reach OpenAI, Gemini and compatible providers through the adapters' existing multi-call conversion (inference).

**Ledger inbox (Rule 17):** none.

## Verification

**Shared surfaces:**

- the seven descriptors' prompts and their pins (`InteropDescriptor`, `InteropMessageDescriptor`, `Test/Dashboard`, `ExplorerDescriptor`);
- the prompt grammar (`PromptCorpus`, both validators, `SuggestedPrompt`), and `promptGroups`' shape;
- `BUILTIN` and `ScreenGrounding`'s statements;
- the POST /turn body;
- the opening messages of a workflow turn;
- the panel footer;
- the strings table, and EXPERIENCE.md :604, :627, :709 and :798;
- the arming rosters in `ci-throwaway.sh`;
- `ATTRIBUTIONS.md` and `ui/licenses/`.

*Every test added or changed passes on a fresh environment, in either order.* Each test makes and removes its own principal, probe class, definition, proposals, policy and switches.

**Setup (slot B, the throwaway only):**

- **Load `src`:** run `rsync -a --checksum --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-20/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`. Then, in `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`, run `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)`.
- **Before any browser run:** `cd ui && npm run build && docker exec ocupilot-b-ci sh -c 'cd /durable/iris/csp/ocupilot && rm -rf ./*' && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`.

**Commands.** Run each in the foreground with `timeout: 600000`, one at a time, and read results from `%UnitTest_Result`.

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.WorkflowCatalog --class OcuPilot.Test.WorkflowLoop --class OcuPilot.Test.WorkflowTurn --class OcuPilot.Test.WorkflowGates`. Expected: green (about 90 s, inference).
- `(loop)` The same runner with `ScreenGrounding`, `Descriptor`, `InteropDescriptor`, `InteropMessageDescriptor`, `Dashboard`, `ExplorerDescriptor`, `TurnLoop`, `TurnTools`, `TurnGrounding`, `TurnWire`, `ToolEmit`, `Governance`, `ExplorerSaveTurn`, `CompileWithoutInterop` and every class the sweep changes. Expected: green (about 220 s by `ci-timings.json`).
- `(loop)` `cd ui && npm run test:tools`, then `cd ui && npm run test:components`. Expected: green.
- `(loop)` `cd ui && npm run build -- --verbose`. Expected: the prebuild chain is green, and the initial total is under 2500kB (about 1.97 MB, inference). Record it.
- `(loop)` `uv run scripts/check-objectscript.py <each changed .cls>` and `bash scripts/lint-docs.sh`. Expected: clean.
- `(loop)` After the redeploy, one file per call: `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/<file>` for `guided-workflow.browser-spec.mjs` and `suggested-prompts.browser-spec.mjs`. Expected: green.
- **Lead-owned (the runner's):** the full ObjectScript sweep, `cd ui && npm test`, `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`, and Rule 30's fresh check.
- **Left to CI:** the full browser suite.

**Planned pinning mutations (Rule 19).** Revert each byte-identical, then reload, or rebuild and redeploy.

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | `Loop.Run` adds no `workflow` pair | `WorkflowLoop`'s shape legs, `WorkflowTurn`, and the browser AC1 |
| AC1 | `previous` is read from the current turn | `WorkflowTurn`'s second-turn leg (no `confirmed`) |
| AC1 | `TurnStore.send` drops `workflow` | `turn.test.mjs`, and the browser AC1 |
| AC2 | The dispatcher's workflow step is removed | `WorkflowLoop`'s NOTASTEP leg, and `WorkflowTurn` |
| AC2 | `WriteRefusal` tests `pMinted > 1` | `WorkflowCatalog`, and `WorkflowTurn`'s one-proposal leg |
| AC3 | `Confirm`'s governance check is skipped | `WorkflowGates`' governance leg |
| AC3 | `Prohibited.User` without its current-user arm | `WorkflowGates`' self-delete leg |
| AC4 | A step names `interop.productions.recoverx` | `WorkflowCatalog`'s resolution leg |
| AC4 | `SuggestedPromptsProblem` accepts any `workflow` (and its twin) | `Descriptor`'s corpus test, and `screen-mirror.test.mjs` |
| AC4 | `WorkflowViolation` always passes | `WorkflowTurn`'s 422 leg |
| AC5 | Continue is not gated on live cards | `panel.spec.ts`' gating test, and the browser AC1 |
| AC5 | `newConversation` keeps the workflow | `turn.test.mjs`, and `panel.spec.ts` |
| AC5 | `.ocu-workflow-chip` takes its surface color as its text | the browser `cardViolations` leg |

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Planned as Part A under the recommended answers to Design Notes › Gate questions Q1 (split) and Q2 (the set), which await the orchestrator at the spec gate.
