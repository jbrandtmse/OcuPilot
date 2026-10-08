---
title: "Story 20.19: The agent reads class and routine source"
type: 'feature'
created: '2026-10-08'
status: 'draft'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-20-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The agent cannot read a class's or routine's source: a document's text never reaches a tool (AD-36). The owner reversed that for the source read on 2026-10-08: "Yes it should send the code." (Q2, kept). The agent's saves are Story 20.21 and its creates Story 20.20; this story ships only the read.

**Approach:** one read tool per kind answers one document's text. The text is cut at whole lines so it serializes to at most 60,000 characters, the cut is reported, and the result reaches the model through AD-60's sanitizer like every tool result. There is no on/off switch for the read (owner, 2026-10-08).

## Boundaries & Constraints

**Always:**

- **Names.** The spine's convention is `<area>.<screen>.<verb>`, with `read` for the one read tool per screen. The reads bind to the viewer screens `explorer.class` and `explorer.routine` (descriptors `ExplorerClassDocument`, `ExplorerRoutineDocument`), which carry no read tool today, so they are `explorer.class.read` and `explorer.routine.read`. If the plan finds a reason they cannot be, it names the reason under Design Notes (orchestrator, 2026-10-08).
- **The source read.**
  - Input `{name}`: one document, as the viewer's `name` criterion takes it (maxLength 256).
  - Gate: the viewer's pairs (`Gate.Evaluate`), then the port's own gate.
  - It reads through `AtelierPort.Invoke(<Class|Routine>, "LIST", name, form "udl", namespace Scope.Current())`, as `ExplorerSaveProbe.Document` does.
  - Answer `{name, namespace, lines, linesSent, truncated, text}`.
    - `text` is the first `linesSent` lines joined by LF, kept whole while their JSON-escaped length is at most `SOURCEMAXLENGTH` (60,000). A string's escaped length is `$Length([s].%ToJSON()) - 4`, plus 2 for each LF.
    - A first line longer than that alone is cut to fit.
    - `lines` is the document's line count.
  - A document whose text the instance does not keep (`available` false) answers 404 `PORT.NOTFOUND`.

**Never:**

- No agent save, create or advertised Save: `explorer.classes.save` and `explorer.routines.save` stay person-only and unadvertised until Story 20.21, and `explorer.sqldata.save` is unchanged.
- No change to a person's Save or the editors.
- No governance key for the reads, and no on/off switch.

## I/O & Edge-Case Matrix

Setup: in process as the suite account in `USER`, on probe documents made by `ExplorerSaveProbe` / `ExplorerProbe` (`OcuProbe193`), removed afterwards. The plan adds the routine row and any row its open security-posture check needs.

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Read | `explorer.class.read {name: OcuProbe193.Alpha.cls}` | `text` equals `ExplorerSaveProbe.Source`; `truncated` false; `linesSent` = `lines` | none |
| Read cut | A probe class whose text escapes to more than 60,000 characters, quotes and backslashes included | `truncated` true; `text` is whole lines; serialized `text` at most 60,000; `linesSent` < `lines` | none |
| Read refused | `name` `Bad`; an absent class; a screen pair denied | 400 `PORT.VALIDATION`; 404 `PORT.NOTFOUND`; 403 `AUTH.NOPRIVILEGE` | no read |

</intent-contract>

## Code Map

Server (`src/OcuPilot/`):

- `Screen/Tool/ExplorerSave.cls`: `ADVERTISED` :23, `DESTRUCTIVE` :36, `SettableFields` :50 (keep), `InputSchema` :65-75, `PortQuery` :101 (keep), `StateDiff` :113 (keep `[]`), `WriteOutput` :123. Its header :1-20 says person-only.
- `Screen/Tool/ExplorerClassSave.cls` / `ExplorerRoutineSave.cls`: `DESCRIPTION` :9 ("never offered to the agent").
- `Screen/Tool/ExplorerWrite.cls`: `MintClass` :64 (to override), `SetProblem` :72, `PrivilegePairs` (routines-DB WRITE).
- `Screen/Tool/ExplorerMint.cls` :21-49: the template (validate, normalize the id with `EntityRef.NormalizedId`, clone the args, `##super`).
- `Kernel/Proposal/Mint.cls`:
  - `Mint` :131: fresh read :164-170; `MergeUpdate` :203; `ArgumentProblem` :219; fingerprint projection :283.
  - `StoredArguments` :308 stores the subclass's rewritten args.
  - `ConsequenceOf` :780; `Refuse` :966 (Private, so a subclass may call it); `pProposal` :367-373.
- `Screen/Tool/Write.cls`: `MergeUpdate` :365, `ConfirmProblem` :935 (asked at Confirm only, 400 with `detail.problem`).
- `Kernel/Proposal/Confirm.cls`: `Operation.Gate` :299 (Prohibits); `ConfirmProblem` :394-406; `FingerprintMatches` :672 (re-merge :728); `output` :519-522. No stored-argument re-validation.
- `Kernel/Proposal/Prohibited.cls`: `IsOcuPilotCode` :2542 and `ReasonFor` :935, both public; `OCUPILOTCODE` :638. Read only.
- `Kernel/Agent/Dispatch.cls` `Capped` :790-841: a rowless result over the reply budget (65,536 at most) is `TOOL.RESULTTOOLARGE`, after a write's row is stored. Hence `CHANGEMAXLENGTH` and the read's own cut.
- `Port/AtelierPort.cls`:
  - `Invoke` :830, which needs `namespace` in the query for `LIST` :848-853; `Document` :2584-2678 (`content` array, `modified`, `available`).
  - Keys `NAMEKEY` :477, `FORMKEY` :480, `NAMESPACEKEY` :453; endpoints `ENDPOINTCLASS` :90 and `ENDPOINTROUTINE` :93.
  - `Lines` :2142, `Header` :2173, `MAXIMPORTCHARACTERS` :401; `SaveSet` :2459-2511 (header :2484, compile :2496-2503).
- `Port/DocDbPort.cls` `IsMapped` :150-165: the destination comparison.
- `Screen/Tool/ExplorerSqlRead.cls`: the read-tool template (declaration :25-58, pairs :63-66, `ResultSchema` :80-105, `View` :117-190). Registration is by class discovery (`Registry.ToolClasses`), so the class itself is the registration.
- `Screen/Tool/ExplorerImport.cls` :57 and :172-175: the `CONSEQUENCE` precedent.
- `Screen/Context.cls` `ScreenTools` :164-245: the viewer's context lists a read bound to it; the lists' contexts list the saves through their `save` row action.
- `Screen/Tool/ExplorerSqlRun.cls` :13: the doc claim "the agent never authors code".
- `Kernel/Governance/Baseline.cls` :199-200.

Client (`ui/src/app/`):

- `core/turn.ts` `parseProposalDiff` :623-639 (and the `TurnProposalDiffRow` type).
- `core/proposal-view.ts`: `ProposalDiffRow` :35-42; the `CONSEQUENCE_*` constants (`EXPLORERIMPORTREPLACES` :216); `consequenceSentence` :390-477.
- `shell/proposal-card.ts`:
  - summary :139-146, diff long block :148-180 (rows :152-177);
  - status and read-back :335-358, output :359-363;
  - `diffLines` :699-704, `summaryVisible` :723-732, `summaryFields` :735-742.
- `areas/system-explorer/line-diff.ts`:
  - exports `lineDiff`, `hunks`, `changeCounts`, `MAX_EDITS`, `CONTEXT_LINES`; spec `line-diff.spec.ts`.
  - Consumers are `code-compare.store.ts` :13 and `code-compare.page.ts` :14.
  - Markup is at `code-compare.page.ts` :140-155, with `SIGNS` :47, `DIRECTIONS` :50 and `segmentViews` :52-71; the styles are `styles/_components.scss` :7615-7672.
- `core/strings.ts`: 20.17's keys :182-193 (insert beside them); `explorerCompareUnchanged` :4563. `tools/strings.test.mjs`: the bound :606-609, about 2,960 of 3,000 (inference); citation rule :841-886.
- `tools/proposal.test.mjs`: assign no literal to a proposal field.

Test templates:

| Need | Template |
|---|---|
| Agent mint and confirm, in process | `Test/ExplorerWrite.cls` `MintFor` :81, `DispatchFor` :99, `ConfirmIn` :126, `TestTheAgentCompilesThroughConfirm` :254 |
| Probe documents | `Test/ExplorerSaveProbe.cls` (`Document`, `Version` :39, `Source` :48, `ClassText` :62, `Rewrite` :72); `Test/ExplorerProbe.cls` `MakeClass` :26 (`pBroken`), `MakeRoutine` :38, `Remove` :150 |
| Turn over the wire, provider request recorded | `Test/SqlAgentRead.cls` `TestATurnReadsRowsFramedAsData` :299; `TurnProvider` `Script` :48, `Recorded` :150, `ToolUseReply` :169 |
| Seeded-injection source | `Test/InjectionSeed.cls` `Plant` :168 (`h` :198), `Remove` :227 (`h` :244), `ReadCall` :623 (`h` :640); `Test/InjectionChannels.cls` `TestClassDescription` :261 |
| Browser agent write on Explorer | `browser/agent-sql.browser-spec.mjs`; `browser/system-explorer-editor.browser-spec.mjs` :50-82; `browser/panel-collapse.browser-spec.mjs` :78-157, :345-437 |

## Tasks & Acceptance

**Execution** (in dependency order):

- **Part A: the source read.**
  - `src/OcuPilot/Screen/Tool/ExplorerSourceRead.cls` (new, abstract, extends `Tool.Base`, `KIND` read).
    - `SOURCEMAXLENGTH` 60000; `InputSchema`, `PrivilegePairs` (`Gate.RequiredPairs(..#DESCRIPTORCLASS)`), `SecretArguments` (declared none), `ResultSchema` (closed; all six members required).
    - `View` as Boundaries says, following `ExplorerSqlRead.View`'s refusal shapes.
    - `ClassMethod Endpoint()` abstract.
  - `ExplorerClassSource.cls` (`explorer.class.source`, `ExplorerClassDocument`, `ENDPOINTCLASS`) and `ExplorerRoutineSource.cls` (`explorer.routine.source`, `ExplorerRoutineDocument`, `ENDPOINTROUTINE`), both new.
    - Each `DESCRIPTION` names its viewer, says the text is cut and `truncated` reports it, and says to copy each `Old` from this text before proposing a save.
- **Part B, server.**
  - `src/OcuPilot/Screen/Tool/ExplorerSave.cls`:
    - `ADVERTISED` 1; header rewritten.
    - `InputSchema` adds `Edits` (array, `minItems` 1, `maxItems` 20, items `{type: object, description}`; `RoleUpdate.InputSchema` :100-110 is the precedent).
    - `MintClass` answers `OcuPilot.Screen.Tool.ExplorerSaveMint`.
    - Add `MergeUpdate`, `AgentProblem(pNamespace, pName) As %String`, `ConfirmProblem`, `Parameter CONSEQUENCE = "EXPLORER.SAVE.COMPILES"` with `Consequence`, `CHANGEMAXLENGTH` 30000, and `ClassMethod DocumentEndpoint()` (Class or Routine for the subclass).
  - `src/OcuPilot/Screen/Tool/ExplorerSaveMint.cls` (new, extends `Kernel.Proposal.Mint`): `Mint`, as the seven steps in Boundaries.
  - `ExplorerClassSave.cls` / `ExplorerRoutineSave.cls`: the agent-facing `DESCRIPTION`, as `ExplorerClassCompile`'s :9 is written. It names the source read, says the output is shown on the card and never to the agent, and says `%` and `OcuPilot` names are refused.
  - `src/OcuPilot/Kernel/Governance/Baseline.cls` :199-200: `true`.
  - `src/OcuPilot/Screen/Tool/ExplorerSqlRun.cls` :13: "the agent authors code only through the class and routine saves (Story 20.19)".
- **Part B, client.**
  - `ui/src/app/areas/system-explorer/line-diff.ts` and `line-diff.spec.ts`: `git mv` to `ui/src/app/core/`, and update the two `code-compare` imports.
    - Add `lineCounts(before, after): {removed, added}`, which falls back to whole-hunk counts when `lineDiff` answers null.
  - `ui/src/app/core/turn.ts` and `proposal-view.ts`: rows gain optional `kind` (a string) and `line` (a number), copied with no literal.
    - Add `CONSEQUENCE_EXPLORERSAVECOMPILES`, mapped in `consequenceSentence`.
  - `ui/src/app/shell/text-diff.ts` (new, `app-text-diff`, OnPush): inputs `before`, `after`, `line`.
    - It renders the compare page's markup and classes; numbers are offset by `line - 1`; segments go through `hunks(..., CONTEXT_LINES)` with `explorerCompareUnchanged`.
    - When `lineDiff` is null, every before line is removed, then every after line is added.
  - `ui/src/app/shell/proposal-card.ts`:
    - A `kind === 'lines'` row renders `app-text-diff`, and `diffLines` counts its before and after lines.
    - `summaryFields` reads `proposalSummaryLines` when the card holds a lines row.
    - Add `savedNotCompiled` and `<p class="ocu-proposal-card-saved-not-compiled" data-slot="saved-not-compiled">` after the read-back. Add its token-only rule in `ui/src/styles/_components.scss`.
  - `ui/src/app/core/strings.ts`: after :193, add three keys, each cited `EXPERIENCE.md:604`, the middle dot authored as `·` (Rule 14):
    - `proposalSummaryLines`: `<name>: <n> lines removed · <m> lines added`;
    - `explorerSaveCompilesOnConfirm`: `Confirming saves this text and then compiles it as you. The compile's outcome shows here once it has run.`;
    - `explorerSaveNotCompiled`: `Saved, but it did not compile. The saved text is what is now on the instance.`
    - In the same change, append the three to EXPERIENCE.md :604's strings cell and "; an agent's class or routine save card: its consequence, compile-failure and summary lines (Story 20.19) [ADDED 2026-10-08, Story 20.19]" to its usage cell. Run `npm run test:tools`.
- **Tests (new).** Each is at most about 500 lines, with no `Test*` property.
  - `Test/ExplorerSource.cls` (in process): the Read, Read cut and Read refused rows. Also: both tools are advertised read tools with their viewer's pairs, and the viewer's context `tools` carries each.
  - `Test/ExplorerSourceTurn.cls` (the Integration AC):
    - A scripted turn calls `explorer_class_source` on a probe class carrying a provider-key shape (`sk-` plus 20 characters).
    - The recorded provider request's tool_result is wrapped in `<ocupilot-data>`, carries the class's text, and reads `[redacted]` for the key.
    - It declares and arms what `SqlAgentRead` does; add it to `scripts/ci-throwaway.sh`'s TEST_PROVIDER block (:521-533), and to the PRINCIPALS block (before :402) if it makes a principal. Both are new `# classes:` lines.
  - `Test/ExplorerSaveAgent.cls`: the Edit, Routine, Confirm, Saved-not-compiled and Changed rows.
  - `Test/ExplorerSaveRules.cls`: the Bad edit, Too wide, Own code, `%` name, [Q1] System code and Confirm rule rows.
  - `ui/browser/agent-code-edit.browser-spec.mjs`, against a probe class in `USER`:
    - a one-line edit card shows the line diff and the consequence sentence; Confirm saves, and no saved-not-compiled line shows;
    - a breaking edit, confirmed, shows `explorerSaveNotCompiled` and the instance holds the new text;
    - a 12-line edit collapses with the summary `<name>: 12 lines removed · 12 lines added`, and Confirm is enabled without opening it.
    - It removes its probe and proposals in `after`.
  - `ui/src/app/shell/text-diff.spec.ts`.
- **Tests (edited; the shared surfaces):**
  - `Test/ExplorerSave.cls`:
    - :201-216 becomes `TestTheKeysShipEnabledAndAPersonsSaveWrites`, expecting "1 1 1".
    - :226-279 becomes `TestTheSaveIsOfferedToTheAgent`: the provider list, the dispatch lookup, `Resolve` and the Classes list's context carry the save; a save carrying only `Names` is 400 `TOOL.ARGUMENTS` with no row.
    - Correct the header :7-8.
  - `Test/ExplorerDescriptor.cls`:
    - :142 becomes `TestTheAreaAdvertisesItsReadsAndWrites`; :157 gains the two saves and the two source reads ("twenty-eight reads and thirteen writes"); :158 gains both saves.
    - :167 reads `=true` for both saves.
    - :177-199 becomes `TestTheTwoSavesAreAdvertisedDestructiveWrites`: `advertised` 1, declarations `1/...`, schema `Names,Edits,...`.
  - `Test/SurfaceCoverage.cls` :345-354: the ten rows name the renamed methods.
  - `Test/Governance.cls` :30-34 and `Test/GovernanceBaseline.cls` :15: drop both saves from the disabled lists.
  - `Test/ReadTool.cls` :93-94: 315 becomes 317, with both names in order.
  - `Test/ToolEmit.cls`: an `ElseIf` for `ExplorerSourceRead` subclasses beside :313-317; drop "the saves" from :89.
  - `Test/ToolSetFull.cls` :193: drop "the saves".
  - `Test/ToolRoundTrip.cls` :83: add `explorer.class.source:TOOL.ARGUMENTS,explorer.routine.source:TOOL.ARGUMENTS`.
  - `Test/DeveloperFloor.cls` :39 and :494-495: add both source reads ("forty-two").
  - `Test/InjectionSeed.cls`: a source `p` (the `h` probe class, read through `explorer_class_source`). `Test/InjectionChannels.cls`: `TestClassSourceText` beside :261.
  - Client: `proposal-card.spec.ts` (the lines row, the summary form, `savedNotCompiled` only with the code, confirmed and `errors` true), `tools/proposal-view.test.mjs` (the mapping; the code is read from `ExplorerSave.cls`) and `tools/turn.test.mjs` (`kind` and `line` parsed).

**Acceptance Criteria:**

- **AC1 (advertised, offered, enabled).**
  - **Given** the two saves and the two source reads,
  - **when** the provider list, the dispatch lookup and the screen contexts are built,
  - **then** each is present: the saves on the Classes and Routines lists, the reads on the two viewers. Both save keys resolve `true`, and `explorer.sqldata.save` stays unadvertised and `false`.
- **AC2 (the source read, Q2).**
  - **Given** a document,
  - **when** the agent reads it,
  - **then** it gets the whole text or its first whole lines within 60,000 escaped characters, with `truncated` saying which, and the model receives it through AD-60's sanitizer.
- **AC3 (the card).**
  - **Given** a minted save,
  - **when** its card shows,
  - **then** it shows the whole change as a line diff with line numbers, the consequence that the compile runs on Confirm, the destructive Confirm, and (when long) the lines summary.
- **AC4 (changed after the mint).**
  - **Given** a document changed after the mint,
  - **when** the save is confirmed,
  - **then** it is refused 409 and nothing is written.
- **AC5 (compile and marker).**
  - **Given** a confirmed save,
  - **when** it completes,
  - **then** the card shows the compile's output and outcome, saying plainly when it saved but did not compile, and one agent marker records the proposal.
- **AC6 (pinned refusals).**
  - **Given** OcuPilot's own documents, `%` names, [Q1] system code, and `explorer.sqldata.save`,
  - **when** this story ships,
  - **then** each is refused or unchanged as the matrix and `SqlSave` :164-171 and `SqlDataSaveRoutes` :226-233 state.
- **AC7 (at the mint and at Confirm).**
  - **Given** an `OcuPilot` or `%` name,
  - **when** the agent would mint it,
  - **then** the mint refuses it, and Confirm's `Prohibited` or `ConfirmProblem` refuses it again.
- **AC8 (Integration).**
  - **Given** a scripted turn and a scripted card in a real browser,
  - **when** they run on `ocupilot-b-ci`,
  - **then** the provider request carries the sanitized source, and the panel's card saves and reports as AC3 and AC5 state.

## Spec Change Log

- 2026-10-08, runner, orchestrator rulings on the first plan (by=merge_gate, feature 2bc6d842): Q3 split. This spec keeps Part A, the source read; Part B (the saves) is Story 20.21, which reads the first plan at `git show eda69374:_bmad-output/implementation-artifacts/spec-20-19-the-agent-edits-existing-classes-and-routines-on-the-person.md`. Q1 A and Q2 A are 20.21's. The read tools are named by the spine's convention. Status reset to draft for a re-plan.

## Review Triage Log

## Design Notes

**Governing ADs.**

- AD-53 (the reversal, and two callers of one operation) and AD-36 (a document's text was screen-only).
- AD-24, whose per-field bound does not reach a rowless result.
- AD-60 and AD-11: untrusted source, the seeded-injection source `p`, and the prompt unchanged.
- AD-6, AD-34 and AD-51: the mint, the hold, the fingerprint over `Modified`, and the stored args.
- AD-10 (the code arm, also at the mint), AD-8 and AD-61 rule 1 (routines-database WRITE), AD-22 (the keys).
- AD-39's fifth exception, AD-15 (the marker), AD-58 (the read-back), AD-7 (no new shape: `explorer.class.read` already reads through the same port read in a turn) and AD-19.

**Owner's words for the spec gate.** "Yes it should send the code." (2026-10-08, relayed by the Planner.) AD-36 should carry it.

**Proposed amendments (one line each, for the runner at the spec gate).**

- **AD-36, L717:** replace "A document's whole text stays the screen-only payload beside the rows and never reaches a tool." with "A document's whole text stays the screen-only payload beside the rows; the agent's source read (`explorer.class.source`, `explorer.routine.source`, Story 20.19) is the one tool that returns it, as whole lines escaping to at most 60,000 characters with the cut reported, through AD-60 (owner, 2026-10-08: "Yes it should send the code.")."
- **AD-24:** "The source read's `text` is bounded by AD-36's 60,000-character cut in place of the per-field bound (Story 20.19)."
- **AD-53:**
  - replace "Until Story 20.19 ships, both Saves stay unadvertised." with "Story 20.19 advertised both Saves: the agent sends exact replacements, the mint applies them on the instance and stores a changed-lines hunk, and the save always compiles."
  - Drop "System Explorer's two Saves (Story 19.3)" from the unadvertised list.
  - Replace "because the agent never authors code" with "because the agent authors code only through the confirmed class and routine saves (Story 20.19)".
- **AD-8:** drop "System Explorer's two Save tools, Story 19.3" from the unadvertised parenthesis.
- **AD-10, the code arm:** "An agent's save is refused at the mint as well, and the agent is refused every `%` name [Q1: and a document outside its namespace's own routines database, or in `%SYS`] at the mint and at Confirm (Story 20.19); a person's Save is unchanged."
- **EXPERIENCE.md `### proposal-card`, after :717:** "**code change** [ADDED 2026-10-08, Story 20.19]: an agent's save of a class or routine shows its changed lines, with three lines of context and line numbers, as one line diff in the diff's long block; the consequence line says the compile runs on Confirm, and a confirmed save whose compile failed says so under the status line, naming the saved text as what the instance now holds." Write it with no quoted string, then run `npm run test:tools`.

**Decisions.**

- **Exact replacements, not whole text.** The read is cut at 60,000 characters, and a provider's output cap bounds a whole text, so replacements are the only input that reaches every line of a long document the mint can read whole. The mint, never the model, writes the text the card reviews (AD-6).
- **A server hunk, a client rendering.** Prefix and suffix trimming bounds the stored row and the model's result. `line-diff.ts`, moved to `core/` because the shell is not an area, draws it exactly as Compare does.
- **Agent rules live on the tool.** `ExplorerSaveMint` (the agent's only path) and `ConfirmProblem` (reached only by a proposal) apply them, and AD-10's one home is untouched.
- **Named limit.** A save's result shares the reply budget with the other calls of one model reply. Past it, the row is stored and the model reads `TOOL.RESULTTOOLARGE`, as it does for every write today.

**Questions for the orchestrator** (the plan builds each recommended option; Q1 blocks).

| # | Question | Options | Recommended |
|---|---|---|---|
| Q1 (posture, blocking) | AC6 says the system classes stay refused, which holds today only where their database is read-only. In `%SYS`, `Security.*`, `Config.*`, `SYS.*` and other non-`%` system code is stored in IRISSYS, mounted read-write (measured on `ocupilot-b-ci`: both packages' destination is the manager directory, `ReadOnly` 0). A person's Save already replaces them with `%Development:USE` and `%DB_IRISSYS:WRITE`, and an agent save would too. `%SYS` is a selectable scope (inference: no exclusion in `Scope` or `AtelierPort`). | **A** The agent saves only a document stored in its namespace's own routines database, and never in `%SYS`, at the mint and at Confirm. That also refuses ENSLIB/HSLIB library classes before any write, and packages mapped from another database. A person's Save is unchanged. **B** Refuse the agent `%SYS` only; read-only libraries stay the vendor's refusal at Confirm. **C** No new rule; AC6 reworded to "where their database is read-only". | A |
| Q2 (Rule 11) | Non-add-only edits to files Epic 18 is changing. `Baseline.cls` :199-200 (values; Epic 18 adds at :84). `SurfaceCoverage.cls` :345-354 (method names; Epic 18 adds at :218). `ToolRoundTrip.cls` :83 (**the same line** Epic 18 rewrites, so the forward merge conflicts textually; resolve it as the union). EXPERIENCE.md :604 (cells; Epic 18 is at :478). | **A** clear them on union terms. **B** hold this story until Epic 18 merges. | A |
| Q3 (size) | The spec is past the template's budget, and implement runs on Haiku. | **A** one story, as planned. **B** two: the source read first (Part A, AC2 and its rows; AD-36 and AD-24), then the saves (Part B). Each half ships alone. | B |

**Integration ACs (Rules 1 and 2).**

- **Consumes:** `AtelierPort`'s document read and `SAVE` (Stories 19.1, 19.3); the kernel mint and confirm; 20.17's long block and summary line; 20.18's screen-named refusal (`explorer.classes`, `explorer.class`). AC8 exercises them on a real instance.
- **Consumed-by:**
  - Story 20.20: creates reuse `AgentProblem`, the source read, `app-text-diff` and both compile sentences.
  - Story 20.16: rule, DTL and BPL edits build on the agent's source edits.

**Rule 11** (checked 2026-10-08 against `epic-18` `origin/feature...HEAD` and `status -s`):

| File | Edit | Status |
|---|---|---|
| `Kernel/Governance/Baseline.cls` | two values | CONTENDED, non-add-only (Q2) |
| `Test/SurfaceCoverage.cls` | ten rows' method | CONTENDED, non-add-only (Q2) |
| `Test/ToolRoundTrip.cls` :83 | two entries | CONTENDED, same line (Q2) |
| EXPERIENCE.md :604 | cells | CONTENDED, non-add-only (Q2) |
| `ui/src/app/core/strings.ts` | three keys after :193 | add-only (Epic 18 adds at :2002) |
| `scripts/ci-throwaway.sh` | new `# classes:` lines | add-only (Epic 18 is at :262) |
| `Test/ReadTool.cls` :93-94 | count and list | shared, not in Epic 18's diff |

**Ledger and standing rules.**

- The inbox is empty.
- DW-1882: no new route; the confirm and the screen action route already hold, and `SaveHoldCoverage` exempts both for that hold.
- Declined DW-2096: it masks statement text the instance records, while a document's source is the code itself, which reaches the model through AD-60 as ruled (Q2).

**Budgets.**

- Bundle: about +5-10 kB (inference): `app-text-diff`, and the line diff moving into the initial bundle if Compare is lazy. Stop above 3,800 kB.
- Fixed strings: +3, about 2,963 of 3,000 (inference).

**Posture:** the plan finds one further question, Q1.

## Verification

**Shared surfaces (Rule 30):**

- the advertised tool set (two saves, two reads), and the Classes and Routines lists' and viewers' context `tools`;
- the Guardrails confirm list (derived);
- the baseline values;
- the proposal card (lines row, consequence, saved-not-compiled line, summary form);
- the line-diff module path;
- the seeded-injection sources;
- the SurfaceCoverage rows;
- EXPERIENCE.md :604.

**Standing criterion (Rule 30):** existing tests that assert a surface this story changes are updated in this story, and every test the story adds or changes passes on a freshly built instance and in either order.

**Setup (slot B):**

- Sync with `rsync -a --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-20/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`.
- Load in `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM` with `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)`, checking both the status and `tErrors`.
- Before a browser run: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`.
- Run one class or spec file per call, and never re-submit after a client-side timeout.

**Commands:**

- `(loop)` `uv run scripts/check-objectscript.py <changed .cls>`: expected clean.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one per call. Expected: 0 failed, read from `%UnitTest_Result`. The classes:
  - new: `ExplorerSource`, `ExplorerSourceTurn`, `ExplorerSaveAgent`, `ExplorerSaveRules`;
  - edited: `ExplorerSave`, `ExplorerDescriptor`, `SurfaceCoverage`, `Governance`, `GovernanceBaseline`, `ReadTool`, `ToolEmit`, `ToolSetFull`, `ToolRoundTrip`, `DeveloperFloor`, `InjectionChannels`;
  - re-run: `ExplorerWrite`, `SqlSave`, `SqlDataSaveRoutes`, `ScreenRefusal`, `Guardrails`, `AtelierPortWriteDenial`, `SaveHoldCoverage`.
- `(loop)` `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/agent-code-edit.browser-spec.mjs browser/system-explorer-editor.browser-spec.mjs browser/system-explorer-find.browser-spec.mjs browser/panel-collapse.browser-spec.mjs`: expected pass.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`, then `bash scripts/lint-docs.sh`: expected clean.
- `(once, before dev_complete)`:
  1. the full ObjectScript sweep, one class at a time;
  2. `cd ui && npm test && npm run build`, with the bundle under the 3326 kB warning, and a stop if it passes 3,800 kB;
  3. `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`.
- `(CI)` The full browser suite runs in CI's shards only (Rule 29).

**Planned pinning mutations (Rule 19).** Apply each, observe red, revert to a byte-identical tree, and record a `mutation:` line here.

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | `ExplorerSave.ADVERTISED` 0 | `ExplorerSave` offered leg; `ExplorerDescriptor` |
| AC2 | the cut ignores escaping (raw `$Length`) | `ExplorerSource` Read cut |
| AC3 | `MergeUpdate` keeps `Mint.Merge`'s rows | `ExplorerSaveAgent` Edit; browser diff leg |
| AC4 | `FINGERPRINTSUBJECT` drops `Modified` | `ExplorerSaveAgent` Changed |
| AC5 | `savedNotCompiled` always false | `proposal-card.spec.ts`; browser breaking leg |
| AC6 | `AgentProblem` answers `""` | `ExplorerSaveRules` `%` and [Q1] rows |
| AC7 | the mint's `IsOcuPilotCode` step removed | `ExplorerSaveRules` Own code |
| AC8 | `Kernel/Agent/Loop.cls` :638 hands the results on without `Sanitize.Results` | `ExplorerSourceTurn` (wrapper and `[redacted]` legs) |

## Auto Run Result

Status: blocked
Blocking condition: intent gap: Q1 (security posture) — AC6 says the system classes stay refused, but in `%SYS` the non-`%` system classes and routines (`Security.*`, `Config.*`, `SYS.*`) live in IRISSYS, mounted read-write (measured on `ocupilot-b-ci`), so a person's Save already replaces them and an agent save would too. Options: A (recommended) the agent saves only documents stored in its namespace's own routines database and never in `%SYS`, at the mint and at Confirm, a person's Save unchanged; B refuse the agent `%SYS` only; C no new rule, AC6 reworded to read-only databases.

The plan is complete with option A built in (marked [Q1]). Q2 asks the runner to clear four contended non-add-only edits on union terms; `ToolRoundTrip.cls` :83 is the line Epic 18 rewrites. Q3 recommends splitting the story into the source read, then the saves.
