---
title: "Story 20.21: The agent saves edits to existing classes and routines"
type: 'feature'
created: '2026-10-08'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-20-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** System Explorer's two Saves are person-only and unadvertised (AD-53). The owner reversed that on 2026-10-07: "we want to loosen the rule and allow the agent to edit source code (including classes and routines) on user confirmation". Story 20.19 shipped the source reads the agent copies its edits from.

**Approach:** advertise both Saves. The agent sends exact replacements; the mint applies them to the text it reads on the instance, refuses what the agent may not change, and stores the new text plus one changed-lines hunk. The card shows the hunk as a line diff and says the compile runs on Confirm. Confirm writes through the person's Save path, unchanged, and the card says plainly when the save did not compile.

## Boundaries & Constraints

**Always:**

- **Names.** The tools stay `explorer.classes.save` and `explorer.routines.save` on the Classes and Routines lists (their `save` row action).
- **Input** (closed schema): `Names`, exactly one document; `Edits`, 1 to 20 objects `{Old, New}`, required; and `rationale`, `expectedImpact`, `reverse`. `Edits.items` is `{type: object, description}` (`RoleUpdate.InputSchema` :106-108 is the precedent). The text, the version and the compile choice are never arguments.
- **The mint** (`ExplorerSaveMint`), in this order. Each refusal stores nothing and calls no write.
  1. `SetProblem` refuses: 400 `TOOL.ARGUMENTS`. Normalize the id as `ExplorerMint` :26 does.
  2. `Prohibited.IsOcuPilotCode(id)`: 403 `PROHIBITED.OCUPILOTCODE` with `Prohibited.ReasonFor`'s sentence (AD-10, now at the mint as well).
  3. `ExplorerSave.AgentProblem(Kernel.Scope.Current(), id)` (Q1, Q3), 400 `TOOL.ARGUMENTS` with the sentence as `detail.problem`:
     - an empty namespace; `%SYS`; a name beginning with `%`;
     - a destination that is not the namespace's own routines database. A class compares `%SYS.Namespace.GetPackageDest(ns, package)` with `GetRoutineDest(ns)`; a routine compares `GetRoutineDest(ns, name, MAC|INC|INT)`, the type from its extension. An empty answer or a throw refuses.
     - A mapped refusal names the database (the resource of `GetAllNSInfo("^" _ dest)`'s `RoutineDB` without `%DB_`, else "another database") and says the person can save it from the class or routine editor.
  4. Each edit is an object with exactly `Old`, a non-empty string, and `New`, a string. A `New` that `Kernel.Agent.Sanitize.Strip` (with `Matchers`) would change is refused.
  5. Read the document: `AtelierPort.Invoke(DocumentEndpoint(), "LIST")` with `namespace`, `name`, `form` `udl` and `maxRows` 1, as `ExplorerSourceRead.View` :103-121 reads it. A port refusal passes through; `available` false is 404 `PORT.NOTFOUND`.
  6. The text is `content`'s lines joined by LF. Apply the edits in order. Each `Old` must occur exactly once in the current text, compared exactly, never normalized; otherwise refuse, naming the edit, its count and the matching rule (DW-2228, Design Notes).
  7. Refuse a result equal to the read text; one whose JSON-escaped length (`$Length([text].%ToJSON()) - 4`, a throw counting as over) exceeds `AtelierPort.MAXIMPORTCHARACTERS`; and one whose `AtelierPort.Header(AtelierPort.Lines(text))` is not the id.
  8. Build the hunk. Refuse when its row serializes longer than `CHANGEMAXLENGTH` (30,000).
  9. Call `##super` with the arguments rewritten to `{Names: id, content, version, Compile: true, Namespace, Hunk, rationale, expectedImpact, reverse}`. `version` is step 5's `modified`, and `Namespace` is step 3's namespace. The three values take the JSON types `ScreenActionDelta` :80-99 builds.
- **The hunk.** Let A be the old lines (nA) and B the new (nB). `p` counts the leading equal lines and `s` the trailing ones, with `p + s` at most the smaller count. With `f = max(1, p+1-3)`, `before` is A[f .. min(nA, nA-s+3)] and `after` is B[f .. min(nB, nB-s+3)], each line followed by LF. The row is `{field: "Text", kind: "lines", line: f, before, after}`.
- **The diff.** `ExplorerSave.MergeUpdate` returns `Mint.Merge`'s payload with the diff replaced by `[pArgs.Hunk]`, or `[]` without one. The confirm's re-merge therefore matches the mint, and a person's Save (which calls `Mint.Merge` itself, `ScreenAction.cls` :475) is unchanged.
- **At Confirm**: the prohibited set (OcuPilot's own code), then governance and the fingerprint (`Modified`). `ExplorerSave.ConfirmProblem` then asks `AgentProblem(pArgs.Namespace, id)` again. The write is `SAVE`, compiling `cuk`, with `If-None-Match` = `version`. `output` is `{lines, errors}`.
- **The card.**
  - `Consequence` answers `CONSEQUENCE` `EXPLORER.SAVE.COMPILES`, shown as `explorerSaveCompilesOnConfirm`.
  - A `kind: "lines"` row renders as `app-text-diff` inside the existing diff long block, and the summary line's first part reads `proposalSummaryLines`.
  - A confirmed card carrying that consequence, with `outputErrors()` true, shows `explorerSaveNotCompiled` as a warning banner under the read-back, outside every long block.
- `DESTRUCTIVE` stays 1 (the destructive Confirm, no typed name). Both baseline keys become `true` (AD-22, the AC). No new CSS: the card reuses `.ocu-line-diff*` and `.ocu-banner-warning` (DW-1337).

**Never:**

- No change to a person's Save: `ScreenActionDelta`, `PortQuery`, `SCREENVALUES`, `ArgumentProblem`, the source editor and its strings.
- No edit of `Prohibited.cls`, `Api/Error.cls`, `Mint.cls`, `Confirm.cls`, `Dispatch.cls`, `Prompt.cls`, a route, a descriptor, `line-diff.ts` or `code-compare.*`. No new error code.
- `explorer.sqldata.save` stays unadvertised and `false`.
- No compile before Confirm (Q4). Compile lines never reach the model, a tool result, the ledger, a log line or screen context (AD-39's fifth exception).
- No fuzzy, trimmed, case-folded or line-ending-normalized match of `Old`.

## I/O & Edge-Case Matrix

In process as the suite account. Probes are classes `OcuProbe2021.*` and routines `OcuProbe2021Mac.mac` / `OcuProbe2021Inc.inc` in `USER`, made with `ExplorerProbe.MakeClass` / `MakeRoutine` and removed after each test.

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Edit | `explorer_classes_save {Names, Edits:[{Old: <one whole line of the probe>, New: <its change>}]}` | proposal; one row `{field: Text, kind: lines, line, before, after}` with 3 context lines; `destructive` true; consequence `EXPLORER.SAVE.COMPILES`; `requiredPairs` holds `%DB_USER:WRITE`; the model's result carries that row, never the whole text | none |
| Routine | the same on `OcuProbe2021Mac.mac` through `explorer.routines.save` | as Edit | none |
| Confirm | the Edit proposal | the source is the new text; `output.errors` false; one agent marker; ledger row `ok` | none |
| Saved, not compiled | an edit leaving the class uncompilable | confirmed; source is the new text; `output.errors` true | none |
| Changed after the mint | `ExplorerSaveProbe.Rewrite` between mint and Confirm | 409 `TARGETCHANGED`; source is the rewrite | nothing written |
| Bad edit | `Old` absent; `Old` twice; edits changing nothing; an edit renaming the header; `New` holding U+202E; an item `{Old}` | 400 `TOOL.ARGUMENTS`, the problem naming the edit and its rule | no row |
| DW-2228 | a class holding `sk-` + 24 letters; `Old` is that line with `[redacted]` in its place | 400 `TOOL.ARGUMENTS`; the problem says `Old` is matched exactly against the stored text, and a read's copy can differ | no row |
| Too wide | edits at the first and last of a 2,000-line probe (written with `%Compiler.UDL.TextServices.SetTextFromString`, as `ExplorerSaveProbe.Rewrite` :72 does) | 400 `TOOL.ARGUMENTS` (the change exceeds one card) | no row |
| Own code | `OcuPilotProbe2021.Own.cls` (need not exist) | 403 `PROHIBITED.OCUPILOTCODE` | nothing read, no row |
| `%` name | `%Library.String.cls` | 400 `TOOL.ARGUMENTS` | nothing read, no row |
| `%SYS` | `Security.Users.cls`, scope `%SYS` | 400 `TOOL.ARGUMENTS` | nothing read, no row |
| Mapped | `Ens.Director.cls` in `USER` | 400 `TOOL.ARGUMENTS` naming `ENSLIB` and the class editor | nothing read, no row |
| Confirm rule | `ExplorerClassSave.ConfirmProblem("%Foo.cls", {Namespace: "USER"})`; `("Ens.Director.cls", {Namespace: "USER"})` | a problem each | refused at Confirm |

</intent-contract>

## Code Map

Server (`src/OcuPilot/`):

- `Screen/Tool/ExplorerSave.cls` -- `ADVERTISED` :23, `DESTRUCTIVE` :36, `SettableFields` :50, `SetProblem` :57, `InputSchema` :65-75, `ScreenActionDelta` :80, `PortQuery` :101 (keep), `StateDiff` :113 (keep `[]`), `WriteOutput` :123. The header :1-18 says person-only.
- `Screen/Tool/ExplorerClassSave.cls` / `ExplorerRoutineSave.cls` :9 -- `DESCRIPTION` "never offered to the agent".
- `Screen/Tool/ExplorerWrite.cls` -- `MintClass` :64 (override on `ExplorerSave`), `ArgumentProblem` :80 (= `SetProblem`, both callers), `PrivilegePairs` :102 (routines-database WRITE).
- `Screen/Tool/ExplorerMint.cls` :19-48 -- the template: refuse, normalize, clone the args, `##super`.
- `Kernel/Proposal/Mint.cls` -- `Mint` :131; `MergeUpdate` call :203; `ArgumentProblem` :220; `StateDiff` :236; fingerprint projection :283; `StoredArguments` :308 (the rewritten args); `ConsequenceOf` :343/:780; `Merge` :543; `Refuse` :966 and `Internal` :978 (Private: callable from a subclass). The mint asks no prohibited predicate today (`ExplorerWrite.TestOcuPilotsOwnCodeIsRefusedOnBothCallers` mints OcuPilot code).
- `Kernel/Proposal/Confirm.cls` -- hold :274 and release :527 (DW-1882); `FingerprintMatches` :672 (re-merge :728); `ConfirmProblem` :394-406 (400 with `detail.problem`); `output` :519-522.
- `Screen/Tool/Write.cls` -- `MergeUpdate` :365, `ConfirmProblem` :935.
- `Kernel/Proposal/Prohibited.cls` -- `IsOcuPilotCode` :2542, `ReasonFor` :935, `OCUPILOTCODE` :638 (read only).
- `Kernel/Agent/Sanitize.cls` -- `Matchers` :127, `Strip` :147 (a pure helper the registry may name).
- `Port/AtelierPort.cls` -- `Lines` :2142, `Header` :2173, `MAXIMPORTCHARACTERS` :401, `SaveSet` :2459-2511; `ENDPOINTCLASS` :90, `ENDPOINTROUTINE` :93; `DatabaseResources` :677 (the `GetAllNSInfo` idiom).
- `Port/DocDbPort.cls` `IsMapped` :150-165 -- the destination comparison (measured on `ocupilot-b-ci`: in `USER`, `Ens` reads `^/usr/irissys/mgr/enslib/` against `^/durable/iris/mgr/user/`; in `%SYS` every package reads the manager directory; an unknown namespace reads `""`).
- `Screen/Tool/ExplorerImport.cls` :57, :172-175 -- the `CONSEQUENCE` precedent.
- `Kernel/Governance/Baseline.cls` :199-200. `Screen/Tool/ExplorerSqlRun.cls` :13 -- "the agent never authors code".

Client (`ui/src/app/`):

- `core/turn.ts` -- `TurnProposalDiffRow` :184; `parseProposalDiff` :623-639; `numberAt` :475.
- `core/proposal-view.ts` -- `ProposalDiffRow` :35-42; `CONSEQUENCE_EXPLORERIMPORTREPLACES` :216; `consequenceSentence` :420.
- `shell/proposal-card.ts` -- the summary :139-146, the diff long block :148-180 (rows :150-177), the status, read-back and output :340-363, `outputErrors` :481, `diffLines` :699 (already counts a row's lines), `summaryFields` :735-742, the `system-task` warning banner markup :182-190.
- `areas/system-explorer/line-diff.ts` -- `lineDiff`, `hunks`, `changeCounts`, `CONTEXT_LINES` (imports nothing). `code-compare.page.ts` :47-71 (`SIGNS`, `DIRECTIONS`, `segmentViews`) and :140-155 (markup); `shell/panel.ts` :24 is the shell-imports-an-area precedent. Styles `styles/_components.scss` :7615-7675.
- `core/strings.ts` :182-193 (20.17's keys), `explorerCompareUnchanged` :4563. `tools/strings.test.mjs` bound :606-609: 2,960 of 3,000 today.

Test templates:

| Need | Template |
|---|---|
| Agent mint, dispatch, confirm in process | `Test/ExplorerWrite.cls` `MintFor` :81, `DispatchFor` :99, `ConfirmIn` :126, `TestTheAgentCompilesThroughConfirm` :254, `StoredText` :283 |
| Probe documents | `Test/ExplorerProbe.cls` `MakeClass` :26 (`pBroken`), `MakeRoutine` :38, `Exists` :63, `Compiled` :80; `Test/ExplorerSaveProbe.cls` `Source` :48, `ClassText` :62, `Rewrite` :72 |
| A real turn, the provider request recorded | `Test/ExplorerSourceTurn.cls` (arming :50-65, script :123-126, `AwaitEnd`'s view :133, `Recorded` and `Unwrapped` :135-147); `TurnWireFixture.Call` :354 |
| A confirm over HTTP | `Test/ConfirmRoute.cls` `Call` :38, `POST /proposal/<id>/confirm` :105 |
| Browser agent write | `ui/browser/agent-sql.browser-spec.mjs`; `panel-collapse.browser-spec.mjs`; DW-1337 walk: `agent-picker.browser-spec.mjs` :123-145 over `structural-walk.mjs` |

## Tasks & Acceptance

**Execution** (Part 1 server, then Part 2 client; each part's tests with it):

Part 1 -- server.

- `src/OcuPilot/Screen/Tool/ExplorerSave.cls`:
  - `ADVERTISED` 1. Rewrite the header for the two callers.
  - `InputSchema` adds `Edits` (required; items described as in Boundaries).
  - Override `MintClass` to answer `OcuPilot.Screen.Tool.ExplorerSaveMint`.
  - Add `MergeUpdate`, `AgentProblem(pNamespace, pName) As %String` and `ConfirmProblem`.
  - Add `Parameter CONSEQUENCE = "EXPLORER.SAVE.COMPILES"` with `Consequence`, `Parameter CHANGEMAXLENGTH = 30000`, and abstract `DocumentEndpoint()`.
- `src/OcuPilot/Screen/Tool/ExplorerSaveMint.cls` (new, extends `Kernel.Proposal.Mint`) -- `Mint`, the nine steps of Boundaries, with `Hunk` as a pure `ClassMethod` the tests call.
- `ExplorerClassSave.cls` / `ExplorerRoutineSave.cls`:
  - `DocumentEndpoint` answers `ENDPOINTCLASS` / `ENDPOINTROUTINE`.
  - The new `DESCRIPTION`, in order: it proposes a change to one document's text in the turn's namespace, which the user confirms; Confirm saves it and compiles it as the user, and the card shows the outcome, which this tool never answers.
  - It then says to read the text first with `explorer.class.source` / `explorer.routine.source`, and gives the `Edits` rule and DW-2228's sentence (Design Notes).
  - Last, it says which names are refused (`%`, `OcuPilot`, `%SYS`, another database) and that the person can save those from the editor.
- `src/OcuPilot/Kernel/Governance/Baseline.cls` :199-200 -- both `true`.
- `src/OcuPilot/Screen/Tool/ExplorerSqlRun.cls` :13 -- "the agent authors code only through the class and routine saves (Story 20.21)".
- `src/OcuPilot/Test/ExplorerSaveAgent.cls` (new) -- the Edit, Routine, Confirm, Saved-not-compiled and Changed rows through `DispatchFor` and `ConfirmIn`; `StoredText` holds no compile line.
- `src/OcuPilot/Test/ExplorerSaveRules.cls` (new) -- the remaining rows, each asserting no proposal row is added (and, where marked, that nothing is read); `Hunk` legs for `p`, `s` and the context cut.
- `src/OcuPilot/Test/ExplorerSaveTurn.cls` (new, the Integration AC) -- arms and cleans up as `ExplorerSourceTurn` :50-118 does. USERA holds `%Development:U` and `%DB_USER:RW`, and the probe class carries `sk-` plus 24 letters and digits.
  - The scripted model calls `explorer_class_source`, then `explorer_classes_save` twice in one reply: one `Old` holds `[redacted]`, the other is a line copied from the read.
  - The refused call is 400 `TOOL.ARGUMENTS` with the matching rule in its `detail`.
  - The test takes the proposal id from the turn's view (`AwaitEnd`), confirms it over HTTP as USERA (`POST /proposal/{id}/confirm`), then asserts the source and `output`.
  - The recorded provider requests carry the hunk and no compile line.
  - Add `# classes: ExplorerSaveTurn` after `scripts/ci-throwaway.sh` :402 and :535 (add-only).
- Shared-surface edits (Rule 30):
  - `Test/ExplorerSave.cls`:
    - Correct the header :1-8.
    - :203 becomes `TestTheKeysShipEnabledAndAPersonsSaveWrites`, expecting `"1 1 1"`.
    - :232 becomes `TestTheSaveIsOfferedToTheAgent`. The provider list, the dispatch lookup, `Resolve` and each list's context `tools` carry the save, and `Advertised` is 1. A call carrying only `Names` is 400 `TOOL.ARGUMENTS`, with no proposal written.
  - `Test/ExplorerDescriptor.cls`:
    - The doc comment :128-140.
    - :157 inserts `explorer.classes.save:write` and `explorer.routines.save:write` in name order; its message reads "twenty-eight reads and thirteen writes".
    - :158 gains both saves' rows, read from the instance.
    - :167 reads `explorer.classes.save=true` and `explorer.routines.save=true`.
    - :182 becomes `TestTheTwoSavesAreAdvertisedDestructiveWrites`: `advertised` 1, `Advertised` 1, and schema `Names,Edits,rationale,expectedImpact,reverse ["Names","Edits"] 0`.
  - `Test/SurfaceCoverage.cls` :345-352 -- the corpus reads "thirteen writes". :353-354 name the renamed method.
  - `Test/Governance.cls` :34 and `Test/GovernanceBaseline.cls` :15 -- drop both saves from the disabled lists.
  - `Test/ToolEmit.cls` :89 and `Test/ToolSetFull.cls` :193 -- drop "the saves" from the comment.

Part 2 -- client.

- `ui/src/app/core/turn.ts`, `core/proposal-view.ts`:
  - Rows gain optional `kind` (a string) and `line` (a number), copied with no literal.
  - Add `CONSEQUENCE_EXPLORERSAVECOMPILES`, mapped in `consequenceSentence`.
- `ui/src/app/shell/text-diff.ts` (new, `app-text-diff`, standalone, OnPush):
  - Inputs `before`, `after`, `line`, `label`. Each side's lines are its LF pieces, the final empty piece dropped.
  - It renders `code-compare.page.ts` :140-155's markup and classes, its region labeled by `label`.
  - Numbers are offset by `line - 1`. Segments are `hunks(script, CONTEXT_LINES)`, a collapsed run reading `explorerCompareUnchanged`. When `lineDiff` answers null, every before line is removed, then every after line added.
  - Export the pure `hunkCounts(before, after): {removed, added}` (from `changeCounts`, or whole counts on null).
- `ui/src/app/shell/proposal-card.ts`:
  - A `kind === 'lines'` row renders `<app-text-diff>` with the card's name as `label`.
  - `summaryFields` reads `proposalSummaryLines` (the name, `<removed>`, `<added>`) when the card holds such a row.
  - After the read-back, add `<p class="ocu-banner ocu-banner-warning ocu-proposal-card-warning" role="status" data-slot="saved-not-compiled">` when confirmed, the consequence is `EXPLORER.SAVE.COMPILES` and `outputErrors()` is true.
- `ui/src/app/core/strings.ts` -- after :193, three keys each cited `/** EXPERIENCE.md:604 */`:
  - `proposalSummaryLines`: `<name>: lines changed, <removed> removed and <added> added`.
  - `explorerSaveCompilesOnConfirm`: `Confirming saves this text and then compiles it as you. The compile's outcome shows here once it has run.`
  - `explorerSaveNotCompiled`: `Saved, but it did not compile. The saved text is what is now on the instance.`
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`:
  - :604 -- append the three to the strings cell, and to the usage cell "; an agent's class or routine save card: its summary line, its consequence and its saved-but-not-compiled line (Story 20.21) [ADDED 2026-10-08, Story 20.21]".
  - After :716 add one bullet, with no quoted string: "**code change** [ADDED 2026-10-08, Story 20.21]: an agent's class or routine save shows its changed lines, with three lines of context and line numbers, as one line diff in the diff's long block; the summary line counts the lines removed and added; the consequence says the compile runs on Confirm; a confirmed save that did not compile says so under the status line, naming the saved text as what the instance now holds."
- Tests:
  - `ui/src/app/shell/text-diff.spec.ts` and `shell/proposal-card-code.spec.ts` (new): the lines row, the summary form, the consequence, and the saved-not-compiled line shown only when confirmed with the code and `true`.
  - `ui/tools/turn.test.mjs`: `kind` and `line` parsed.
  - `ui/tools/proposal-view.test.mjs` :346: add `['ExplorerSave.cls', CONSEQUENCE_EXPLORERSAVECOMPILES, STRINGS.explorerSaveCompilesOnConfirm]`.
  - `ui/browser/agent-code-save.browser-spec.mjs` (new), on a probe class in `USER`, from scripted turns:
    - a one-line edit's card shows the line diff and the consequence; Confirm saves, and no saved-not-compiled line shows;
    - a breaking edit, confirmed, shows `explorerSaveNotCompiled`, and the instance holds the new text;
    - a 12-line edit's diff starts collapsed under `proposalSummaryLines`, and Confirm works unopened;
    - the live card passes the DW-1337 invariants at wide light, narrow light and wide dark.
    - It waits for the panel's answered signal before it clicks, and removes its probe and proposals in `after`.

**Acceptance Criteria:**

- **AC1 (advertised, enabled).** Given the registry, when the provider list, the dispatch lookup and the Classes and Routines lists' context are built, then each save is an advertised, destructive write; both keys resolve `true`; and `explorer.sqldata.save` stays unadvertised and `false`.
- **AC2 (the card).** Given a minted save, when its card shows, then it shows the hunk as a line diff with line numbers, the consequence that the compile runs on Confirm and as the user, and, when long, the lines summary with Confirm usable unopened.
- **AC3 (changed after the mint).** Given a document changed after the mint, when the save is confirmed, then it is refused 409 and nothing is written.
- **AC4 (compile and marker).** Given a confirmed save, when it completes, then the card shows the compile's lines and outcome. A document that saved but did not compile is said plainly, and one agent marker records the proposal.
- **AC5 (pinned).** Given OcuPilot's own documents and `explorer.sqldata.save`, when this story ships, then each is refused or unchanged (`ExplorerWrite.TestOcuPilotsOwnCodeIsRefusedOnBothCallers`, `SqlDataSaveRoutes` :230).
- **AC6 (mint and Confirm).** Given an `OcuPilot`, `%`, `%SYS` or mapped document, when the agent would mint it, then the mint refuses it before reading, and Confirm's prohibited set or `ConfirmProblem` refuses it again. A mapped refusal names its database and the editor.
- **AC7 (DW-2228).** Given an `Old` that differs from the stored text, including a copy carrying `[redacted]`, when the save is minted, then it is refused and says that `Old` is matched exactly against the stored text.
- **AC8 (Integration).** Given a real turn on `ocupilot-b-ci`, when its proposal is confirmed over HTTP, then the class's source holds the new text, the confirm answers `output`, and no provider request carries a compile line.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs.** AD-53 (the reversal; two callers), AD-10 (the code arm, now also at the mint), AD-6, AD-34 and AD-51 (mint, hold, `Modified` fingerprint, stored args), AD-8 and AD-61 rule 1 (routines-database WRITE), AD-22 (keys), AD-39's fifth exception, AD-15 (marker), AD-58 (read-back `nothingSent`), AD-36, AD-60 and AD-11 (the model's copy, DW-2228), AD-24 (a write result has no `rows`; `CHANGEMAXLENGTH` bounds its one row), AD-19.

**Owner's words and ruling.** "we want to loosen the rule and allow the agent to edit source code (including classes and routines) on user confirmation" (2026-10-07). Orchestrator rulings Q1 (A), Q2 (A), Q3, Q4 (by=merge_gate, 2026-10-08).

**Spine amendments (one line each, for the runner at the spec gate):**

- **AD-53, line 1065:** replace "Until Story 20.21 ships, both Saves stay unadvertised." with: "Story 20.21 advertised both Saves. The agent sends exact replacements, each `Old` matched exactly once against the stored text. The mint applies them and stores the new text and one changed-lines hunk of at most 30,000 characters, and the save always compiles on Confirm. The agent saves only a document stored in its namespace's own routines database, never in `%SYS` and never a `%` name, refused at the mint and again at Confirm before anything is written; a person's Save is unchanged (owner, 2026-10-07: "we want to loosen the rule and allow the agent to edit source code (including classes and routines) on user confirmation"; orchestrator ruling Q1, by=merge_gate, 2026-10-08)."
- **AD-53, same paragraph:** drop "System Explorer's two Saves (Story 19.3)," from "The unadvertised tools today are". Replace "because the agent never authors code" with "because the agent authors code only through the confirmed class and routine saves (Story 20.21)".
- **AD-8, line 218:** drop "System Explorer's two Save tools, Story 19.3 [AMENDED 2026-10-02, Story 19.3 spec gate, Rule 20], " from the unadvertised parenthesis, keeping "today".
- **AD-10, code arm (line 339):** append "An agent's save is refused at its mint as well (Story 20.21)." Q1 is agent-only, so it is AD-53's rule, not AD-10's.

**Decisions.**

- **Exact replacements, not whole text.** The read cuts at 60,000 characters and a provider's output bounds a whole text, so replacements are the input that reaches every line. The mint, never the model, writes the text the card reviews (AD-6).
- **A server hunk, a client rendering.** Prefix and suffix trimming bounds the stored row and the model's result. `app-text-diff` reuses Compare's `line-diff.ts` and styles, imported from the area as `panel.ts` :24 imports one.
- **Agent rules live on the tool.** `ExplorerSaveMint` (the agent's only path) and `ConfirmProblem` (asked only at a proposal's confirm) apply them. AD-10's one home and `ArgumentProblem` (both callers) are untouched.
- **DW-2228's sentence**, in the description and in every match refusal: "Each Old is matched exactly, character for character, against the text this instance stores. The copy explorer.class.source and explorer.routine.source send can differ from it: control and invisible characters are removed, a key-shaped value reads [redacted], and the data delimiter's name is changed. Choose an Old that avoids those places."
- **A `New` the sanitizer would change is refused** (strict side of AC2): a bidirectional override or invisible character would make the reviewed diff read differently from what is saved. A person can still save such text.
- **Refusals are `TOOL.ARGUMENTS` with `detail.problem`**, as `SetProblem`'s and the mint's are. They have no client surface, so no Fixed string (AD-53's publish-once rule covers self-protection sentences drawn by a screen). There is no new code and no `Api/Error.cls` sibling.

**Named limits.**

- At Confirm, the card shows `TOOL.ARGUMENTS`' published reason for a `ConfirmProblem` refusal; the sentence rides `detail.problem`. Only a mapping added within the proposal's ten minutes reaches it, and the fingerprint usually refuses first.
- The text can change between step 5's read and the kernel's `SAVEDOCS` read. The write's `If-None-Match` then refuses 409 `EXPLORER.DOCUMENT.CONFLICT` with nothing written.
- An open source editor is not refreshed. Its next Save is refused as a conflict, never overwritten (`source-editor.store.ts` :15-16).
- The proposal row stores the new text (AD-6 executes from stored arguments) in OcuPilot's protected state. The hunk reaches transcripts, exposure 20.19's read already has.
- The compile outcome after a reload is not shown, as with every compile's output (AD-39).

**Posture:** no further security-posture question. The rulings cover the reach; the one judgment (invisible characters in `New`) is AC2's faithfulness, taken on the strict side.

**Integration ACs (Rules 1, 2).** AC8 is the Integration AC: the confirm route and the panel's card consume the minted save on a real instance.

- **Consumes:** `AtelierPort`'s document read and `SAVE` (19.1, 19.3); 20.19's source reads (the model's `Old`); the kernel mint, hold and confirm; 20.17's long block and summary line; 20.18's screen-named refusal.
- **Consumed-by:** Story 20.20 (creates reuse `AgentProblem`, `app-text-diff` and both compile sentences); Story 20.16 (rule, DTL and BPL edits build on this edit model).

**Rule 11** (checked 2026-10-08: `epic-18` `origin/feature...HEAD` and `status -s`, 18.29 in progress):

| File | Edit | Status |
|---|---|---|
| `Kernel/Governance/Baseline.cls` :199-200 | two values | contended, non-add-only, cleared on union terms (Q2); Epic 18 adds at :84 |
| `Test/SurfaceCoverage.cls` :345-354 | corpus and method names | contended, cleared (Q2); Epic 18 adds at :218 |
| `EXPERIENCE.md` :604, :716 | cells and one bullet | contended, cleared (Q2); Epic 18 rewrites :478 |
| `ui/src/app/core/strings.ts` after :193 | three keys | add-only; Epic 18 adds at :2011 |
| `scripts/ci-throwaway.sh` :402, :535 | two `# classes:` lines | add-only; Epic 18 edits :262 |
| everything else named here | as Tasks | not in Epic 18's diff or working tree |

`Test/ToolRoundTrip.cls` (already `TOOL.ARGUMENTS` for both saves), `ReadTool.cls` and `SaveHoldCoverage.cls` (in Epic 18's working tree) are not edited.

**Ledger and standing rules.** DW-2228 (inbox) closes through AC7, the description, the Rules leg and the Turn leg. DW-1882: no new route; the confirm holds (`Confirm.cls` :274, :527) and the screen route already does. DW-2096: not applicable (ruled at 20.19). FR-80: one descriptor, one port, no derived field list (Atelier). 11.3: no new screen. No new error code.

**Budgets.** Client about +5-10 kB (inference) against the 3,326 kB warning (3,167,529 bytes before). Fixed strings +3: 2,963 of 3,000, 2,967 once 18.29's four merge.

## Verification

**Shared surfaces (Rule 30):**

- the advertised tool set (provider list, dispatch lookup, the Classes and Routines lists' context `tools`) and the System Explorer area roster;
- the governance baseline values;
- Guardrails' confirm list (derived);
- the SurfaceCoverage rows;
- the proposal card (lines row, summary form, consequence, saved-not-compiled line), with strings and EXPERIENCE.md :604;
- the arming rosters.

**Standing criterion (Rule 30):** existing tests that assert a surface this story changes are updated in this story, and every test the story adds or changes passes on a freshly built instance and in either order.

**Setup (slot B):**

- `rsync -a --checksum --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-20/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`.
- Then in `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`, run `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)` and check both the status and `tErrors`.
- Before a browser run: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`.
- One class or spec file per call; never re-submit after a client-side timeout.

**Commands:**

- `(loop)` `uv run scripts/check-objectscript.py` -- 0 problems.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one per call, read back from `%UnitTest_Result`; 0 failed. The classes:
  - new: `ExplorerSaveAgent`, `ExplorerSaveRules`, `ExplorerSaveTurn`;
  - edited: `ExplorerSave`, `ExplorerDescriptor`, `SurfaceCoverage`, `Governance`, `GovernanceBaseline`, `ToolEmit`, `ToolSetFull`;
  - re-run: `ExplorerWrite`, `ExplorerSource`, `ExplorerSourceTurn`, `SqlDataSaveRoutes`, `SqlSave`, `ScreenRefusal`, `Guardrails`, `ToolRoundTrip`, `AtelierPortWriteDenial`, `SaveHoldCoverage`, `ReadTool`, `DeveloperFloor`.
- `(loop)` `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/agent-code-save.browser-spec.mjs browser/panel-collapse.browser-spec.mjs browser/system-explorer-editor.browser-spec.mjs browser/agent-sql.browser-spec.mjs` -- pass.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`, then `bash scripts/lint-docs.sh` -- clean.
- `(once, before dev_complete)`:
  - the full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci`, one class at a time -- 0 failed;
  - `cd ui && npm test && npm run build`, the bundle under the 3,326 kB warning (stop past 3,800 kB);
  - `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` -- pass.
- `(CI)` The full browser suite runs in CI's shards only (Rule 29).

**Planned pinning mutations (Rule 19).** Apply each, observe red, revert to a byte-identical tree, and record a `mutation:` line here.

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | `ExplorerSave.ADVERTISED` 0 | `ExplorerSave` offered leg; `ExplorerDescriptor` roster |
| AC2 | `MergeUpdate` keeps `Mint.Merge`'s rows | `ExplorerSaveAgent` Edit; browser diff leg |
| AC2 | the card ignores `kind` | `proposal-card-code.spec.ts`; browser diff leg |
| AC3 | `FINGERPRINTSUBJECT` drops `Modified` | `ExplorerSaveAgent` Changed |
| AC4 | the saved-not-compiled condition always false | `proposal-card-code.spec.ts`; browser breaking leg |
| AC5 | `Baseline` `explorer.sqldata.save` `true` | `ExplorerDescriptor` baseline leg |
| AC6 | `AgentProblem` answers `""` | `ExplorerSaveRules` `%`, `%SYS`, mapped and Confirm rule rows |
| AC6 | the mint's `IsOcuPilotCode` step removed | `ExplorerSaveRules` Own code |
| AC7 | step 6 compares `$ZConvert(...,"L")` of both sides | `ExplorerSaveRules` DW-2228 and absent legs |
| AC8 | `ExplorerSaveMint` stores `Compile: false` | `ExplorerSaveTurn` output leg |

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Planned only (halt after planning). Oversized (about 33 KB): one goal across server and card. If the implement budget needs two passes, split at the Tasks seam: Part 1 (server, ACs 1, 3, 5-8) then Part 2 (card, ACs 2 and 4). AC2 and AC4 ship only with Part 2, so the plan recommends one story.
