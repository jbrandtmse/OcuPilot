---
title: 'Story 20.16: The agent edits rule, DTL and BPL content behind the embedded editors'
type: 'feature'
created: '2026-10-13'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** Story 20.7's editor screens show InterSystems' rule, BPL and DTL editors in a frame, but the agent cannot change what they show. The owner's flow (2026-10-07): "Warn the user that the editor must be saved if needed and then the agent reads current content and proposes the edit in the background and refreshes the page." Under AD-63 OcuPilot never reads the frame, so the agent sees only what is saved.

**Approach:** Each editor screen gets an agent read and an agent-only save of its document's class text. They extend Story 20.21's class source read and class save, and only a class of the editor's kind is admitted. Both tools are listed in the screen's context. The screen's bar, the tools' descriptions and the proposal card say first that the agent works from what is saved. A confirmed save emits a change event, and the editor page reads it and draws a new frame, so the editor shows the new content.

## Boundaries & Constraints

**Always:**

- **Six tools, two abstract bases:**

  | Screen (Story 20.7 descriptor) | Read | Save | Kind base | Noun |
  |---|---|---|---|---|
  | `InteropRuleEditor` | `interop.ruleeditor.source` | `interop.ruleeditor.save` | `Ens.Rule.Definition` | a business rule |
  | `InteropProcessEditor` | `interop.processeditor.source` | `interop.processeditor.save` | `Ens.BusinessProcessBPL` | a business process written in BPL |
  | `InteropTransformEditor` | `interop.transformeditor.source` | `interop.transformeditor.save` | `Ens.DataTransformDTL` | a data transformation written in DTL |

- **The reads** extend `ExplorerClassSource` through an abstract `InteropEditorSource`: the same text, cut, sanitizer and port, bound to the editor screen (`DESCRIPTORCLASS`).
- **The saves** extend `ExplorerClassSave` through an abstract `InteropEditorSave`: the same input (`Names`, `Edits`, `rationale`, `expectedImpact`, `reverse`), the same mint (`ExplorerSaveMint`, unchanged), `Modified` fingerprint, hunk, `DESTRUCTIVE` 1 with no typed name, compile on Confirm (`cuk`), read-back, hold (DW-1882) and agent marker (AD-15). The differences are only these:
  - `SCREENACTIONS` and `SCREENVALUES` are `""`, so the save is agent-only. It declares `SCREENLISTED` 1, so its screen's context lists it.
  - `CONSEQUENCE` is `INTEROP.EDITOR.RELOADS`.
  - `MATCHRULE` names the three editor reads in place of `explorer.class.source` and `explorer.routine.source`.
  - `AgentProblem` asks `##super` first, then `InteropPort.IsCodeOfKind(namespace, name, <kind base>)`. The mint asks it, and Confirm asks it again.
- **Pairs.** Each of the six tools requires the editor screen's effective pairs (`Screen.Gate.RequiredPairs`, AD-64) plus `%Development:USE`, which `AtelierPort` checks (AD-61 rule 1). The save keeps the routines-database WRITE as its argument pair (DW-2242). Each of the three saves also requires `%Ens_Code:WRITE`, the vendor editor's own write resource [AMENDED 2026-10-13, orchestrator ruling at the spec gate: the editor path is never looser than the classic editor's; Task 0 confirms the resource from the vendor source]. A pair set cannot express the vendor's OR list, so a holder of only `%Ens_DTL`, `%Ens_BPL` or `%Ens_Rules*` WRITE is refused, and `%EnsRole_Administrator` (`%Ens_Code:READ` only) is refused the saves, as the vendor editor is read-only for it. Dispatch therefore refuses a missing `%Development:USE` or, for a save, `%Ens_Code:WRITE` by name before any mint. `CLASSICPAGES` stays `""`, because the screen's own `classicPage` is the editor (`Write.cls` :115-124: "not redeclared").
- **Kind check.** `IsCodeOfKind` answers 1 only when `%Dictionary.ClassDefinition:SubclassOf(<base>)`, run while switched to the namespace (AD-16), lists the class and the class is not the base itself. That is the same test `ListClasses` and 20.7's `Coded` apply, so the save admits exactly the classes its editor opens.
  - A namespace without interoperability refuses.
  - So does a dictionary that cannot be read: a failed switch or a failed query sets `pRead` 0.
  - No `OcuPilot.*` class is called while switched. No `Ens.*` type appears in a signature (AD-62 item 12).
- **The warning comes first, three times:**
  - The screen's bar shows `interopEditorAgentNote` beside 20.7's note, before any request.
  - The read's and the save's descriptions tell the model to tell the person, before it reads, that it works from what is saved.
  - The card's consequence `interopEditorSaveOnConfirm` says that confirming drops the editor's unsaved changes.
- **The reload.** The editor page subscribes to `ChangeBus`. A `changed` event whose `type` is `class`, whose `scope` equals the page's namespace, and whose comma-separated `id` holds the page's document id calls the store's `refresh()`, which draws a new frame (20.7's `revision`). OcuPilot still never reads, posts to or navigates the frame (AD-63).
- **Compile verdict.** `AtelierPort.Outcome` counts a compile as failed when a console line reads `Detected <n> errors during compilation` with `n` at least 1, as well as on the status errors it reads today. Measured: a BPL whose generated thread class fails answers 200 with `status.errors` `[]`.
- **The card.**
  - `INTEROP.EDITOR.RELOADS` maps to `interopEditorSaveOnConfirm`.
  - The saved-but-not-compiled banner shows for either code-save consequence.
  - `panel.ts`'s `outputErrors` gate admits a proposal carrying `INTEROP.EDITOR.RELOADS`.
- **Keys.** All three save keys ship `true` (AD-22, the AC).

**Never:**

- No new screen, descriptor, route, row action, read endpoint, entity type, error code or dialog. No edit of `Screen/Registry.cls`, `Screen/Read.cls`, `Kernel/Proposal/Prohibited.cls`, `ExplorerSaveMint.cls`, `Mint.cls`, `Confirm.cls`, `Dispatch.cls`, `Prompt.cls`, `app.routes.ts`, `angular.json`, `screens.generated.ts` (no descriptor change), `.github/workflows/ci.yml`, `ui/tools/ci-shards.mjs`, `ui/tools/ci-timings.json` or `ui/tools/ci.test.mjs`.
- No read of, post to, listener on or navigation of the frame. No call to `%Api.InteropEditors` (AD-62 item 1), including its `Utils.IsSubClass`.
- No typed-name confirmation (Design Notes › Typed name). No compile before Confirm. No whole-text input.
- No change to a person's Save, `explorer.classes.save`'s behavior or 20.7's list reads. The classic-page roster (`ClassicPageGate`) is not joined.
- A probe class never begins with `OcuPilot` (`Prohibited.IsOcuPilotCode` refuses it); probes are `OcuProbe2016*`.

## I/O & Edge-Case Matrix

Server rows run in process as the suite account. Probes `OcuProbe2016.Rule`, `.Process` and `.Transform` are compiled in `USER` (Design Notes › Probes) and removed with every generated class.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Edit (each kind) | `interop.transformeditor.save {Names: "OcuProbe2016.Transform.cls", Edits: [{Old, New}]}` (likewise rule and process) | Proposal with one `{field: Text, kind: lines, line, before, after}` row; `destructive` true; consequence `INTEROP.EDITOR.RELOADS`; `requiredPairs` holds `%Development:USE` and `%DB_USER:WRITE` | - |
| Confirm | The Edit proposal | Source is the new text; `output.errors` false; one agent marker; ledger `ok`. The confirm's target is type `class`, scope `USER`, id `OcuProbe2016.Transform.cls`, action `updated` | - |
| Changed after the mint | `ExplorerSaveProbe.Rewrite` between mint and Confirm | 409 `TARGETCHANGED` | Nothing written |
| BPL saved, not compiled | An edit adding `<code><![CDATA[ Set x = (1 ]]></code>` to the BPL | Confirmed; source is the new text; `output.errors` true | - |
| Wrong kind | Transform save on `OcuProbe2016.Process.cls`; process save on `OcuProbe2016.Transform.cls`; rule save on a plain class | 400 `TOOL.ARGUMENTS`, `detail.problem` naming the kind and `explorer.classes.save` | No row; nothing read |
| Coded process | Process save on `OcuProbe2016.Coded.cls` (extends `Ens.BusinessProcess`, not BPL) | 400 `TOOL.ARGUMENTS` (not a BPL) | No row |
| Mapped | Process save on `EnsLib.Background.Process.ExportMessageSearch.cls` in `USER` | 400 `TOOL.ARGUMENTS` naming `ENSLIB` (`##super`'s sentence) | No row; nothing read |
| Own code, `%`, `%SYS` | `OcuPilotProbe2016.Transform.cls` (need not exist); `%Library.String.cls`; `Security.Users.cls` with scope `%SYS` | 403 `PROHIBITED.OCUPILOTCODE`; 400 `TOOL.ARGUMENTS`; 400 `TOOL.ARGUMENTS` | No row; nothing read |
| Confirm rule | `InteropTransformEditorSave.ConfirmProblem("OcuProbe2016.Process.cls", {Namespace: "USER"})` | A non-empty problem | Refused at Confirm |
| No interoperability | `IsCodeOfKind` with a namespace that does not report interoperability, or an unknown namespace | 0, with `pRead` 0 | The save refuses: it cannot read the kind |
| Context | Screen context for route `interoperability/transforms/document/OcuProbe2016.Transform.cls`, namespace `USER` | `tools` = `["interop_transformeditor_source", "interop_transformeditor_save"]`. The explorer viewer, editor and list contexts are unchanged | - |
| Missing pair | A principal with the editor pairs and `%DB_USER:RW` but no `%Development:USE` | 403 `AUTH.NOPRIVILEGE`, `detail.failedPair` `%Development:USE`, before any mint | No row |
| Missing vendor write (a save) | A principal with the editor pairs, `%Development:USE` and `%DB_USER:RW`, holding `%Ens_Code:READ` only | 403 `AUTH.NOPRIVILEGE`, `detail.failedPair` `%Ens_Code:WRITE`, before any mint | No row |
| Reload (client) | A `changed` event `{type: class, scope: <page ns>, id: <route id>}` on the open editor | `refresh()`: `revision` + 1, a new frame element | A different id, namespace or type does nothing |

</intent-contract>

## Code Map

All paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-20`. Lines were read at `f0f544e9`. Story 20.7 lands first, so anchor its files by symbol.

### Built by 20.21 and 20.19 (extend)

- **`src/OcuPilot/Screen/Tool/ExplorerSave.cls`** (283 lines):
  - `ADVERTISED` :24, `SCREENACTIONS` :27, `SCREENVALUES` :29, `DESTRUCTIVE` :37.
  - `FINGERPRINTSUBJECT` :48, `CONSEQUENCE` :51, `MATCHRULE` :57.
  - `PrivilegePairs` :74-79 (the screen's pairs plus `CLASSICPAGES`), `ArgumentPairs`/`CodeWritePairs` :85-102.
  - `InputSchema` :114-131. The `Edits` description at :123 names `explorer.class.source or explorer.routine.source` as a literal.
  - `AgentProblem` :198-250, `ConfirmProblem` :256-265 (calls `..AgentProblem`, so an override applies at both points), `Consequence` :278.
- **`ExplorerClassSave.cls`** (22 lines): `TOOLNAME`, `DESCRIPTORCLASS`, `DESCRIPTION` :10, `Endpoint`, `DocumentEndpoint`.
- **`ExplorerSaveMint.cls`**: unchanged. :46 asks `$ClassMethod(pToolClass, "AgentProblem", …)`, :79 reads `$Parameter(pToolClass, "MATCHRULE")`, and :106 reads `CHANGEMAXLENGTH`.
- **`ExplorerClassSource.cls`** (32 lines): `TOOLNAME` :9, `DESCRIPTION` :11, `DESCRIPTORCLASS` :14 ("the viewer whose pairs this tool requires and whose context lists it"), `NAMEHINT` :17.
- **`ExplorerSourceRead.cls`**: `PrivilegePairs` :53-56 (the descriptor's pairs only). `View` :84-144 runs the schema, then `Gate.Evaluate(DESCRIPTORCLASS)` :98, then the port read.
- **Precedents:**
  - `ExplorerCreate.cls` :20-23 is the agent-only `SCREENACTIONS ""`, pinned by `ExplorerCreateFlow.cls`:94.
  - `ExplorerCreate.cls` :166-168 shows `Consequence` delegation.

### Kernel and registry (read; two small edits)

- **`Screen/Tool/Write.cls`**: `CLASSICPAGES` :115-124, `CHANGEACTION` :134, `SCREENACTIONS` :167. `SCREENLISTED` is added beside `SCREENACTIONS`.
- **`Screen/Context.cls` `ScreenTools`** :164-249:
  - The write group is "carries a declared row action, or creates on a screen with a primary action" (:192-209).
  - `BoundTo` :302-309. Reads bound to a descriptor are always listed.
  - 20.7's editors declare no action, so an agent-only write is not listed today.
  - Pins that must stay green: `Test/ScreenGrounding.cls`, `Test/ExplorerSource.cls`:219-224 and `Test/ExplorerDescriptor.cls`:224-225.
- **Discovery and the starting set:**
  - `Screen/Tool/Registry.cls` `ToolClasses` :797-837 scans non-abstract subclasses of `Tool.Base`. The `TOOLNAME` pattern is :46.
  - `Kernel/Agent/Loop.cls`:121-138 builds the starting set: `shell_*` plus the context `tools`.
- **`Kernel/Agent/Dispatch.cls`**:236-304: governance, restraint, `RequiredPairs`, then `AUTH.NOPRIVILEGE`. The screen is named only when a screen pair is missing (20.18).
- **The confirm:**
  - `Kernel/Proposal/Confirm.cls` hold :270-282, `ConfirmProblem` :390-406, `output` :517-522.
  - `Operation.TargetRefOf` :67-70 makes the target type the descriptor's `class` and the scope the mint's namespace. An editor save and an explorer save of one class therefore share one hold and one sibling set (inference).
- **`Kernel/Proposal/Prohibited.cls`**:1435-1444: the code arm is keyed by entity type `class`, so it applies with no edit.
- **`Kernel/Governance/Baseline.cls`**:17-245. The last line, :243 `"interop.transforms.test": true`, has no trailing comma.

### Ports

- **`Port/AtelierPort.cls`**:
  - `PAIRS` :75 (`%Development:USE`), `Invoke` :852-996.
  - `SaveSet` :2500-2564: the compile result `{lines, errors}` at :2549-2557.
  - `Outcome` :3133-~3200: the soft branch sets `pErrors = ($$$ISERR(pCallSC) || (tErrors '= ""))`. This is the line that changes. It serves `CompileSet` :1879, import :2465 and save :2556.
- **`Port/InteropPort.cls`**:
  - `ListClasses` :1049-1103 is the `SubclassOf` scan while switched.
  - `TransformFactsHere` :5677-5700 is the same scan for one class, private, already switched.
  - :33-35: nothing of OcuPilot is called while switched.
  - It is contended with Epic 18's 18.37 (ready-for-dev), so the new method is add-only.

### Client

- **Change events:**
  - `core/change-bus.ts`:50-82 is the payload `{kind, type, scope, id, action, proposalId, readBack?, tool?}`.
  - `core/turn.ts`:1452-1461 publishes it on a confirmed 200.
  - Precedents: `areas/tasks/task-editor.page.ts`:156-160 (a page subscription) and `areas/system-explorer/code-compare.store.ts`:144-151 (`names(event)`: scope, type, comma-separated ids).
- **The card:**
  - `core/proposal-view.ts`:223 `CONSEQUENCE_EXPLORERSAVECOMPILES`; `consequenceSentence` :435-543 (:467).
  - `shell/proposal-card.ts`: the lines row :152-154, the banner :365-374, and `savedNotCompiledVisible` :1046-1048, an exact equality on one code.
  - `shell/panel.ts`:1161: `outputErrors` only for `explorer.` tools.
  - Pins: `panel.spec.ts`:3602-3629, `proposal-card-code.spec.ts`, `proposal-card-code-states.spec.ts`:82-102, and `ui/tools/proposal-view.test.mjs`:347-361 (rows `[file, constant, sentence]`, read from `Parameter CONSEQUENCE = "…"` in the tool file).
- **Strings:**
  - `core/strings.ts`:186-199 holds the 20.21 keys, each `/** EXPERIENCE.md:604 */`.
  - `ui/tools/strings.test.mjs`:606-613 is the bound: 3,341 literals of 3,400 at this plan, before 20.7's fifteen.
  - EXPERIENCE.md: Fixed strings :250-604, the proposal-card "code change" bullet :718, Dialogs :171-173.
- **Toasts:** `core/toasts.ts`:188-196 and `core/navigation.ts` `screenForChange` :597-607. The editor is not a list (`ownerListFor`), so a confirm on the editor still raises a toast that links to a `class` list (inference; Named limits).
- **20.7's files** (anchor by symbol at Task 0):
  - `areas/interoperability/interop-editor.store.ts` (`open`, `refresh`, `revision`, generation guard) and `interop-editor.page.ts` (the bar with `data-ocu-editor="note"` and `"refresh"`).
  - `interop-editor-frame.ts` (`revision`).
  - Tests: `ui/tools/interop-editor-store.test.mjs`, `interop-editor.page.spec.ts` and `ui/browser/interop-editors.browser-spec.mjs`.

### Test templates

| Need | Template |
|---|---|
| Mint, dispatch, confirm in process | `Test/ExplorerWrite.cls` `MintFor` :81, `DispatchFor` :99, `ConfirmIn` :126, `StoredText` :283; `Test/ExplorerSaveFlow.cls` `Dispatch` :65, `CodeOf` :72, `ProblemOf` :84, `Refused` :103 |
| Rewrite after the mint | `Test/ExplorerSaveProbe.cls` `Source` :48, `Rewrite` :72, `HoldLock` :80 |
| A real turn | `Test/ExplorerSaveTurn.cls`: arming and grants :50-118, turn :180-238 (`TurnProvider.Script`, `ToolUseReply`, `TextReply`, `AwaitEnd`, `ResultsOf`, `POST /proposal/{id}/confirm`) |
| Probe principals missing a pair | `Test/InteropTransformTestGate.cls` |
| USER interop probes | `Test/InteropTransformFixture.cls` |
| Arming | `scripts/ci-throwaway.sh` `# classes:` lines :485-488 (`OCUPILOT_ALLOW_PRINCIPALS`) and :624-626 (`OCUPILOT_ALLOW_TEST_PROVIDER`); `ui/tools/ci.test.mjs` derives both sides, with no edit |
| Browser agent save | `ui/browser/agent-code-save.browser-spec.mjs`: `before`/`after` :67-90, `scriptReply`/`saveReply` :151-160, `proposeSave` :163-168, `cardViolations` :176-202; `turnprobe-spec.mjs` (`runIris` :53-65, `armProbeDefinition` :213); `panel-spec.mjs` `signedInAt` :64; `interop-editor-spec.mjs` `until` :62, `watchEditorTraffic` :90 |

### Rosters (each value read from the instance, never recalled)

- **`Test/ReadTool.cls`**:93-94: the literal 376, the sorted name list and "one hundred and ninety-four write tools". Add six tools and three writes; Epic 18's additions are summed at the forward merge.
- **`Test/ToolRoundTrip.cls`**:93 `REFUSEEMPTY`: six `tool:CODE` entries, as `explorer.classes.save` and `explorer.class.source` have.
- **`Test/SurfaceCoverage.cls`**:383-414: three `<tool>` rows, for writes only. `explorer.classes.save` :383 is the shape.
- **`Test/Prohibited.cls`**:456: the composed-tool `$Case` gains `"interop.ruleeditor.save": 3` and the two others, read from the instance.
- **`Test/ToolEmit.cls`**: a branch before :200 and before :364 expects the editor tools' pairs, the screen's plus `%Development:USE`.
- **Re-run, unchanged by design:**
  - `InteropFloor` (`ADMINISTRATORTOOLS` :56-65 and :354-389; those principals hold no `%Development:USE`) and `DeveloperFloor`;
  - `GovernanceBaseline` (it lists disabled keys only);
  - `ScreenGrounding`, `ExplorerSource` and `ExplorerDescriptor`.

## Tasks & Acceptance

**Execution:**

**Task 0 (re-anchor, no code).** After 20.7 has merged into this branch:

- Read its three descriptors, `interop-editor.store.ts`, `interop-editor.page.ts`, `interop-editor-frame.ts` and their tests. Anchor this story's page and store edits to them.
- Confirm that the descriptors' `entityType` is `class`, their `scope` is `namespace`, they declare no action, and their `toolIdentifier`s are as in Boundaries.
- Re-read `InteropPort.cls`'s tail once 18.37 has merged, if it has.
- Read the vendor editors' write check (the hidden `Utils.GetPrivileges` the plan measured, and the API's save and compile routes) and confirm that `%Ens_Code:WRITE` is the resource that admits a save and is held by `%EnsRole_Developer`. If the vendor requires something stricter for a kind, add that too; never declare less (orchestrator ruling 2026-10-13). Record the reading in one line under Design Notes.

**Part 1, server:**

- [ ] **`src/OcuPilot/Port/InteropPort.cls`** (add-only): `ClassMethod IsCodeOfKind(pNamespace As %String, pName As %String, pBase As %String, Output pRead As %Boolean) As %Boolean`, as Boundaries › Kind check describes.
  - The namespace check uses the port's existing interoperability test, before any switch.
  - Explicit save and restore, with the restore first in `Catch`.
  - The doc comment states the caller contract.
- [ ] **`src/OcuPilot/Port/AtelierPort.cls`**:
  - Add the pure `ConsoleCountsErrors(pConsole) As %Boolean`: 1 when any string line matches `^Detected [1-9][0-9]* errors? during compilation`.
  - `Outcome`'s soft branch ORs it into `pErrors`.
  - Doc comment: a class whose generated class fails answers no status error (measured).
- [ ] **`src/OcuPilot/Screen/Tool/Write.cls`**: add `Parameter SCREENLISTED As BOOLEAN = 0;`. The doc says: an agent-only write its bound screen's context lists although no screen action carries it.
- [ ] **`src/OcuPilot/Screen/Context.cls` `ScreenTools`**:
  - The write group also takes a bound, advertised write whose class has `SCREENLISTED` 1 (`$Parameter`).
  - Update the doc comment's write-group sentence.
- [ ] **`src/OcuPilot/Screen/Tool/ExplorerSave.cls`**:
  - Add `Parameter READWITH = "explorer.class.source or explorer.routine.source";`.
  - Use it in the `Edits` description at :123, so the default text is byte-identical.
- [ ] **New `src/OcuPilot/Screen/Tool/InteropEditorSave.cls`**, `[ Abstract ]`, extending `ExplorerClassSave`:
  - `SCREENACTIONS ""`, `SCREENVALUES ""`, `SCREENLISTED 1`, `CONSEQUENCE "INTEROP.EDITOR.RELOADS"`.
  - `KINDBASE` and `KINDNOUN` set per subclass. `READWITH` names the subclass's read. `MATCHRULE` is rewritten to name the three editor reads.
  - A `WARN` parameter holding the warning sentence (Design Notes).
  - `PrivilegePairs`: `##super`, plus `%Development:USE` and `%Ens_Code:WRITE` once each (the reads keep `%Development:USE` only).
  - `AgentProblem(pNamespace, pName, pCreate)`: `##super`, then the kind check. `pRead` 0 gives "whether '<name>' is <noun> could not be read, so the agent does not save it". A class not of the kind gives "'<name>' is not <noun> in namespace <ns>, so this editor's save does not change it; explorer.classes.save changes other classes".
- [ ] **New concrete saves** `InteropRuleEditorSave.cls`, `InteropProcessEditorSave.cls` and `InteropTransformEditorSave.cls`. Each sets `TOOLNAME`, `DESCRIPTORCLASS` (20.7's descriptor), `KINDBASE`, `KINDNOUN`, `READWITH` and `DESCRIPTION`. The description gives, in order:
  1. what it proposes and that the user confirms;
  2. that Confirm saves, compiles as the user and opens the document again in the editor, dropping unsaved changes;
  3. the `WARN` sentence;
  4. to read first with its read, then the `Edits` rule and the match rule;
  5. what is refused (another kind, `%`, OcuPilot, `%SYS`, another database).
- [ ] **New `src/OcuPilot/Screen/Tool/InteropEditorSource.cls`**, `[ Abstract ]`, extending `ExplorerClassSource`: `PrivilegePairs` is `##super` plus `%Development:USE` once.
- [ ] **New concrete reads** `InteropRuleEditorSource.cls`, `InteropProcessEditorSource.cls` and `InteropTransformEditorSource.cls`, each setting `TOOLNAME`, `DESCRIPTORCLASS`, `NAMEHINT` and `DESCRIPTION`. The description says:
  - it reads the class text the screen's editor shows, as saved on the instance, whose XData holds the rule, BPL or DTL;
  - then the `WARN` sentence;
  - then the cut and the "call alone" sentences, as `ExplorerClassSource`'s description gives them.
- [ ] **`src/OcuPilot/Kernel/Governance/Baseline.cls`**: append the three save keys as `true`, adding the comma on :243.
- [ ] **New `src/OcuPilot/Test/InteropEditorProbe.cls`** (helper, not a test):
  - `Make(pKind, pPackage)` writes and compiles the Design Notes probe of each kind in `USER`, plus a coded process.
  - `Broken(pName)` returns the text with an uncompilable `<code>`.
  - `Remove(pPackage)` deletes the package with every generated class, kills `^IRIS.TempEnsRule("class",<rule>)`, and verifies absence.
  - It reuses `ExplorerSaveProbe.Rewrite` and `Source`.
- [ ] **New `src/OcuPilot/Test/InteropEditorTools.cls`**:
  - Each tool's name, kind, `Advertised` 1 and binding.
  - The three keys resolve `true`.
  - Each read's required pairs equal the screen's plus `%Development:USE`; each save's equal the screen's plus `%Development:USE` and `%Ens_Code:WRITE` (the save adds the routines WRITE as an argument pair). Update `ToolEmit`'s branch, `InteropFloor`'s and `DeveloperFloor`'s rosters, and any other roster that lists the saves' pairs, to the added pair.
  - Each description holds the `WARN` sentence.
  - `ScreenTools` of each editor is exactly its read and its save, while `ExplorerClassList`'s, `ExplorerClassDocument`'s and `ExplorerClassEditor`'s are unchanged.
  - `IsCodeOfKind` holds for the matrix's kinds, with `pRead` 0 for `%SYS` and an unknown namespace.
- [ ] **New `src/OcuPilot/Test/InteropEditorSave.cls`**: the matrix's Edit (three kinds), Confirm (the stored text, `output`, the marker, the ledger and the confirm's target), Changed after the mint, and BPL saved-not-compiled rows, through `DispatchFor` and `ConfirmIn`.
- [ ] **New `src/OcuPilot/Test/InteropEditorSaveRules.cls`**: the matrix's Wrong kind, Coded, Mapped, Own code, `%`, `%SYS` and Confirm rule rows. Each asserts that no proposal row is added and, where marked, that nothing is read.
- [ ] **New `src/OcuPilot/Test/InteropEditorSaveGate.cls`** (armed `OCUPILOT_ALLOW_PRINCIPALS`): probe principals, each missing one pair, signed in as `InteropTransformTestGate` does:
  - without `%Development:USE`: `failedPair` `%Development:USE`, before any mint;
  - holding `%Ens_Code:READ` but not WRITE: `failedPair` `%Ens_Code:WRITE`, before any mint;
  - without `%Ens_Code:READ`: refused naming the editor screen (20.18);
  - without `%DB_USER:WRITE`: the argument pair.
  - No row in any case.
- [ ] **New `src/OcuPilot/Test/InteropEditorSaveTurn.cls`** (armed as `ExplorerSaveTurn` is). This is the Integration AC.
  - The `TurnWireFixture` principal holds `%Development:U`, `%DB_USER:RW`, `%Ens_Portal:U` and `%Ens_Code:RW`.
  - The turn posts screen context for `interoperability/transforms/document/OcuProbe2016.Transform.cls` in `USER`.
  - The scripted model calls `interop_transformeditor_source`, then `interop_transformeditor_save` with an `Old` copied from the read.
  - Assert:
    - the first recorded provider request's starting tools hold both wire names;
    - the proposal confirms over HTTP as the principal;
    - the source holds the new text and the answer carries `output`;
    - no provider request carries a compile line.
- [ ] **`src/OcuPilot/Test/AtelierPortSave.cls`**: a pure leg for `ConsoleCountsErrors`, using the measured console lines (BPL failure 1, DTL failure 1, success 0, a non-array 0).
- [ ] **`scripts/ci-throwaway.sh`**: add-only `# classes: InteropEditorSaveGate, InteropEditorSaveTurn` after :488, and `# classes: InteropEditorSaveTurn` after :626.
- [ ] **Rosters** (Code Map › Rosters): `ReadTool`, `ToolRoundTrip`, `SurfaceCoverage` (rows naming `InteropEditorSave`'s Edit test, `corpus="one loop pins all three Story 20.16 editor saves"`), `Prohibited` and `ToolEmit`.

**Part 2, client:**

- [ ] **`ui/src/app/core/proposal-view.ts`**:
  - Add `CONSEQUENCE_INTEROPEDITORRELOADS = 'INTEROP.EDITOR.RELOADS'` and its `consequenceSentence` branch.
  - Export `CODESAVECONSEQUENCES`, a set of the two code-save codes.
- [ ] **`ui/src/app/shell/proposal-card.ts`**: `savedNotCompiledVisible` tests membership of `CODESAVECONSEQUENCES`.
- [ ] **`ui/src/app/shell/panel.ts`**:1161: also pass `outputErrors` when the proposal's consequence is `CONSEQUENCE_INTEROPEDITORRELOADS`.
- [ ] **`ui/src/app/core/strings.ts`** (add-only, `/** EXPERIENCE.md:604 */`): `interopEditorAgentNote` and `interopEditorSaveOnConfirm` (Design Notes › Strings).
  - If `strings.test.mjs`'s literal count is then within 50 of its bound, raise the bound to 3,800, as its comment at :606-609 rules.
- [ ] **20.7's `interop-editor.store.ts`**: add the pure `shows(event: ChangeEvent): boolean`, true for the Reload row's event while the store holds a document and namespace.
- [ ] **20.7's `interop-editor.page.ts`**:
  - Subscribe to `ChangeBus` (task-editor's shape), call `store.refresh()` when `shows(event)` is true, and unsubscribe on destroy.
  - In the bar, after the note, add `<p data-ocu-editor="agent">` showing `interopEditorAgentNote`.
- [ ] **Unit tests:**
  - `ui/tools/interop-editor-store.test.mjs`: `shows` legs (match; other id, namespace, type and kind; a comma set).
  - `interop-editor.page.spec.ts`: the agent line renders in the `open` phase; a matching event bumps the revision and draws a new frame; a non-matching one does not.
  - `proposal-card-code-states.spec.ts`: the banner for the new code.
  - `panel.spec.ts`: the widened gate.
  - `ui/tools/proposal-view.test.mjs`: the row `['InteropEditorSave.cls', CONSEQUENCE_INTEROPEDITORRELOADS, STRINGS.interopEditorSaveOnConfirm]`.
- [ ] **New `ui/browser/agent-editor-save.browser-spec.mjs`** (template `agent-code-save`):
  - `before` refuses `LIVE_CONTAINER`, requires readiness, arms `turnprobe`, allows writes, resets governance, drops proposals and writes `OcuProbe2016Ui.Transform` compiled in `USER` (`InteropEditorProbe.Make`). It records `^EnsPortal.Settings(<user>,"LastDTL")`.
  - `after` drops proposals, removes the probe package (`InteropEditorProbe.Remove`), restores the node and disarms.
  - Each test signs in at `/ocupilot/interoperability/transforms/document/<probe>.cls?ns=USER` and waits for the frame before acting.
  - Tests: AC1's bar leg, AC2, AC3 and AC6's browser leg, and the DW-1337 walk of the live card at 1280 light, 720 light and 1280 dark.

**Part 3, documents:**

- [ ] **EXPERIENCE.md** (add-only), then `cd ui && npm run test:tools`:
  - :604: append the two literals with a Story 20.16 clause.
  - :718: append "An agent's save behind an Interoperability editor (Story 20.16) shows the same line diff; its consequence says the editor opens the document again and drops changes not saved there, and the editor then shows the saved text."
  - 20.7's editor-screen sentences (:159 and the :856 exception): append "its bar also says the agent reads only what is saved (Story 20.16)".
- [ ] **The roster sweep (Rule 30).** Search `src/OcuPilot/Test`, `ui/tools`, `ui/browser` and the `ui/src` specs for assertions on:
  - the tool count or lists;
  - a context `tools` list;
  - `savedNotCompiledVisible`'s single code and `panel.ts`'s `explorer.` gate;
  - a compile's `errors` with a console that reports errors;
  - `ExplorerSave`'s `Edits` description.

  Each changed file joins the `(loop)` set.

**Acceptance Criteria:**

- **AC1 (warned first, then read, then proposed).**
  - **Given** the probe DTL open in its editor screen in `USER`, signed in.
  - **When** the screen renders, before any turn, **then** its bar shows `interopEditorAgentNote` beside the note.
  - **And when** a turn runs there, **then** its screen context's `tools` are exactly that editor's read and save, and both descriptions carry the `WARN` sentence.
  - **And** the scripted turn reads with `interop_transformeditor_source` and proposes with `interop_transformeditor_save`.
  - **And** the warnings the product guarantees are the bar line (before any request) and the card's consequence (before the write, AC2). The model's own warning is what the descriptions ask for, and the once-only live check records what one reply did, as evidence rather than a gate.
- **AC2 (a confirmed proposal with the diff and the marker, refused when changed).**
  - **Given** a minted editor save.
  - **When** its card shows, **then** it shows the lines diff and `interopEditorSaveOnConfirm`.
  - **When** it is confirmed, **then** the class holds the new text, the confirm answers `output`, one agent marker and an `ok` ledger row are written, and the card reads confirmed.
  - **And given** the class rewritten after the mint, **when** it is confirmed, **then** it is refused 409 `TARGETCHANGED` and the stored text is the rewrite.
- **AC3 (the editor reloads and shows the new content).**
  - **Given** the probe DTL's editor screen with a handle on its frame element.
  - **When** the agent's save of that class is confirmed from the panel.
  - **Then:**
    - the old element is detached, and a new element is drawn with the same `src`;
    - the new frame's own document read (`GET /api/interop-editors/v7/USER/dtl/<class>`) answers 200 carrying the new value;
    - the frame's rendered text contains that value. The DTL editor lists action values in its actions table (`actionsTableGrid`, read in the bundle; inference).
- **AC4 (the key and the confirmation).**
  - **Given** the baseline and the three tools.
  - **When** this story ships.
  - **Then** each save key resolves `true`, and the proposal is the save's destructive confirmation with no typed name. The finding on a typed name is recorded under Design Notes.
- **AC5 (only its own kind, and only where the agent may save).**
  - **Given** a class of another kind, a coded process, a mapped vendor class, an OcuPilot class, a `%` name or `%SYS`.
  - **When** the agent would mint an editor save.
  - **Then** it is refused before anything is read where the matrix says so, and Confirm's rule refuses a class that is not of the kind.
- **AC6 (a BPL that did not compile says so).**
  - **Given** an editor save that makes the BPL's generated thread class fail to compile.
  - **When** it is confirmed.
  - **Then** `output.errors` is true and the card shows `explorerSaveNotCompiled`. On the transform screen, the browser leg confirms a breaking DTL edit and sees the banner and a new frame.
- **AC7 (Integration).**
  - **Given** a real turn on `ocupilot-b-ci`.
  - **When** its proposal is confirmed over HTTP.
  - **Then** the class holds the new text, the starting tools carried both editor tools, and no provider request carries a compile line (`InteropEditorSaveTurn`).
- **AC8 (pairs refused by name).**
  - **Given** a principal missing `%Development:USE`, `%Ens_Code:READ`, `%Ens_Code:WRITE` (a save) or the routines-database WRITE.
  - **When** it calls the save.
  - **Then** dispatch refuses by name before any mint, naming the editor screen for the screen pair, and writes no row.

## Spec Change Log

- 2026-10-13, spec gate (runner): the orchestrator ruled Q1 the other way (B): the three saves also require `%Ens_Code:WRITE`, the vendor editor's write resource, confirmed from the vendor source at Task 0. The Pairs bullet, the matrix, Task 0, the save's `PrivilegePairs`, the tools and gate tests, the turn principal, AC8, the named limits and the mutation table carry it. The Rule 20 drafts are written into the spine with it.

## Review Triage Log

## Design Notes

**Governing ADs:**

- **AD-53**: the agent authors code through confirmed class saves, held to 20.21's rules. This story adds three.
- **AD-63**: a new frame, never a navigated one; nothing crosses.
- **AD-24**: the context's `tools`.
- **AD-61**: the pairs, and the compile verdict in rule 6.
- **AD-62**: items 1, 3 and 12, and the kind predicate.
- **AD-22**: keys.
- **AD-6, AD-34 and AD-51**: mint, hold and fingerprint.
- **AD-15**: marker.
- **AD-14**: the change event; the page re-reads.
- **AD-10**: the code arm, by entity type.
- **AD-8 and AD-64**: pairs; a tool's own extra pair is not adjustable.
- **AD-5**: binding.
- **AD-11 and AD-60**: reads pass the sanitizer.
- **AD-39**: the fifth exception, compile lines.
- **AD-44**: no `CLASSICPAGES`.
- **AD-58**: read-back. **AD-19**: framework-free store.
- Checked, not engaged: AD-36 (no declared read), AD-43 (no auto-refresh), AD-57.

**Measured on `ocupilot-b-ci` (2026-10-13; IRIS for Health 2026.2 build 221U).** Probes `OcuProbe2016.*` were made in HSCUSTOM and removed, generated classes and the `^IRIS.TempEnsRule` node included, and their absence was verified.

| What | Answer |
|---|---|
| `IsEnsembleNamespace` HSCUSTOM, USER | 1, 1; each probe package's destination is the namespace's own routines database |
| Probe compile | DTL and rule generate no class. BPL generates `.Context`, `.Thread1` and six collection classes, and adds a `Storage Default` block to its own text |
| `SubclassOf` per call | DTL base 645 rows, 3.39 ms; BPL 6 rows, 0.15 ms; rule 1 row, 0.09 ms. `%Extends` needs a compiled class; the dictionary walk holds uncompiled, as 20.7's `Coded` does |
| Atelier `PUT doc` | A stale or missing version answers 409. The read version answers 200. `cuk` compile answers 200 |
| Vendor GET after an Atelier save (`/api/interop-editors/v7/<ns>/{dtl,bpl,rules}/<c>`) | 200 with the edited value. The vendor reads the class definition's XData, never the compiled class |
| A DTL whose `<code>` does not compile | `status.errors` carries #5475. The vendor GET answers the new saved text. The old compiled code is gone: `Transform()` raised `<SYNTAX>` |
| The same in a BPL | **200, `status.errors` `[]`.** The console carries `ERROR: …Thread1.cls…` and `Detected 1 errors during compilation in 0.191s.` |
| Vendor save of an unchanged model | DTL adds `Parameter GENERATEEMPTYSEGMENTS = 0;`. BPL reorders `Storage` and requotes attributes. The vendor saves XData plus parameters, `Description` and `DependsOn` through `%Dictionary`, with no compile |
| Vendor privileges (hidden `Utils.GetPrivileges`) | Write: `%Ens_Code` or `%Ens_DTL`/`%Ens_BPL`/`%Ens_Rules*` WRITE, and `RoutinePermissionCheck("WRITE")`. No `%Development` check; the web app grants it through `%EnsRole_InteropEditorsAPI` |
| Stock roles | `%EnsRole_Developer`: `%Development:U` through `%Developer`, and `%Ens_Code:RW`. `%EnsRole_Administrator`: `%Ens_Code:R` only. `%Developer`: no `%Ens_*` |
| Sizes | The largest vendor DTL is 80,995 characters. Every rule, BPL and DTL in HSCUSTOM is mapped (642 HSLIB, 7 ENSLIB, no rule), so the agent saves only a namespace's own documents |

**Decisions:**

- **New tools, not `explorer.classes.save` alone.** The story's own key and the editor-specific consequence need a tool of their own. So do the kind check (otherwise the editor's tool is a second, separately governed path to every class) and the screen-named refusal (20.18). `explorer.classes.save` stays a way to change the same class.
- **Reads per editor.** A turn starts with the screen context's tools. Bound reads are always listed, so the model reads and saves without a discovery round trip.
  - The read has no kind check: it reaches exactly what `explorer.class.source` reaches, under the same port gate.
  - *Rejected:* the saves' descriptions pointing at `explorer.class.source`, which costs one `shell.tools.find` call per edit.
- **`SCREENLISTED`, opt-in.** `ScreenTools` lists writes behind declared actions. The editors declare none, and no person's action exists for an agent-only save.
  - *Rejected:* a general "a screen with no action lists every bound write" rule. `Write.cls` defaults `SCREENACTIONS` to `""`, so an unknown number of tools would join other screens' contexts.
- **Extends `ExplorerClassSave`, not `InteropAction`** (Rule 31). The write is a class save through `AtelierPort` (`SAVEDOCS`/`SAVE`, `Names`, a version, a body). `InteropAction` fixes `InteropPort`, `Name`, a body-less action and `%Ens_ProductionConfig:WRITE`.
- **The kind predicate in `InteropPort`**, beside `ListClasses` and `TransformFactsHere`, as an add-only public method. *Not* a refactor of `TransformFactsHere`, which is 20.27's and private in a file 18.37 is changing. The scan is the same idiom; the shapes differ (set and facts against one answer).
- **The compile verdict is fixed at the port.** It changes every compile's `errors` (save, compile, import) for a class whose generated class fails. That is a correction, and 20.21's saves gain it.
- **Typed name: none.** Searched for a concrete reason:
  - A failed compile leaves the class's running code broken. That holds for every class save, not only DTL or BPL (measured on the DTL).
  - DTL and BPL `<code>` runs in production jobs. So does any class a production calls.
  - The person can make the same change in the vendor editor with a plain Save.
  - So DTL and BPL edits carry no risk the class save lacks. The confirmation stays the save's: destructive, no typed name, which EXPERIENCE.md requires of an agent card.
- **The warning is deterministic before the read and before the write, and asked of the model as well.** It cannot be one runtime gate before the read, because OcuPilot cannot know whether the editor is dirty (AD-63).
  - If the person saves the editor after the mint, Confirm is refused 409 `TARGETCHANGED`, nothing is dropped, and the agent proposes again.
  - The bar line, the description sentence and the card sentence are each pinned.
  - The model's behavior is checked once live.
- **AC3's rendered-text leg rests on the DTL editor drawing action values as text** (inference). If the implement stage finds it does not, the leg is restated to what the editor does draw for the edited action, under Rule 5's apply-and-report tier. The document-read leg stays.
- **No dialog** (EXPERIENCE.md :173 unchanged). The bar line is static text, and the consequence is card text; neither is a dialog or a person's pre-write warning.

**Strings (two literals, add-only):**

- `interopEditorAgentNote`: "The agent reads only what is saved: save your changes here before you ask it for a change, because confirming its change opens the document again."
- `interopEditorSaveOnConfirm`: "Confirming saves this text and then compiles it as you, and the editor opens the document again, dropping any changes not saved there. The compile's outcome shows here once it has run."
- `WARN` (server, model-facing, pinned by `InteropEditorTools`): "The editor may hold changes that are not saved, which you cannot see: before you read or change the document, tell the person you work from what is saved and ask them to save the editor first, because confirming your change opens the document again and drops its unsaved changes."

**Probes** (in `USER`; the server package is `OcuProbe2016`, the browser's `OcuProbe2016Ui`). The DTL: `Class <pkg>.Transform Extends Ens.DataTransformDTL [ DependsOn = (Ens.StringRequest, Ens.StringResponse) ]`, with an XData `DTL` `<transform sourceClass='Ens.StringRequest' targetClass='Ens.StringResponse' create='new' language='objectscript'>` holding `<assign value='source.StringValue' property='target.StringValue' action='set'/>`. The BPL is a `<process>` with request `Ens.Request`, response `Ens.Response`, one context property, one `<assign>` and one `<trace>`. The rule extends `Ens.Rule.Definition` with `RuleAssistClass = "EnsLib.MsgRouter.RuleAssist"` and one `<send target=…>`. The coded process extends `Ens.BusinessProcess`.

**Posture question for the orchestrator** (the plan builds A; it does not halt):

| Q | Options | Recommended |
|---|---|---|
| Q1: should the editor saves also require `%Ens_Code:WRITE`, the vendor editor's write resource? | **A** No. The save's reach is the class save's (`%Development:USE`, routines-database WRITE) plus the editor screen's pairs. The same person reaches the same class through `explorer.classes.save` anyway, and the convention declares extra pairs only where a run measured the port needing them. **B** Yes, as a single pair (narrower than the vendor's OR list). It refuses `%EnsRole_Administrator`, which the vendor editor makes read-only, and a holder of only `%Ens_DTL`, `%Ens_BPL` or `%Ens_Rules` | A (plan). **Ruled B by the orchestrator, 2026-10-13**: the editor path is never looser than the classic editor's; stricter is the orchestrator's call, looser would be the owner's. |

**Spine and UX drafts (Rule 20; the lead writes them at the gate):**

- **AD-53**, after the Story 20.20 sentence: "Story 20.16 adds three agent-only class saves bound to the rule, BPL and DTL editor screens (`interop.ruleeditor.save`, `interop.processeditor.save`, `interop.transformeditor.save`). Each is held to Story 20.21's rules and admits only a class its editor opens (a subclass of `Ens.Rule.Definition`, `Ens.BusinessProcessBPL` or `Ens.DataTransformDTL` in the dictionary), checked at the mint and again at Confirm. Their keys ship enabled, and each confirms as the class save does."
- **AD-63**, appended to the named consequence: "Story 20.16: a confirmed agent save of the screen's document draws a new frame as Refresh does, through the page's own change-event read (AD-14), so the editor shows the saved text. The screen's bar says the agent reads only what is saved, and the card says confirming drops the editor's unsaved changes."
- **AD-24**, the `tools` member: "…and of the write tools behind its declared row actions and primary action, plus a bound agent-only write that declares `SCREENLISTED` (Story 20.16's editor saves, on screens that declare no action)".
- **AD-61 rule 6**, appended: "A compile is also failed when its console reads `Detected <n> errors during compilation` with n above zero, because a class whose generated class fails answers 200 with no status error (measured at Story 20.16's plan on a BPL)."
- **AD-62**, a Story 20.16 clause: "`InteropPort.IsCodeOfKind` answers whether a class descends from a rule, BPL or DTL base in a namespace's dictionary, switched, as `ListClasses` and `Coded` read it; the editor saves ask it at the mint and at Confirm."
- **EXPERIENCE.md**: the three Part 3 appends.

**Integration, Consumes, Consumed-by (Rules 1 and 2):**

- **Integration ACs:** AC7 (a real turn consumes the context listing, the read and the save, and the confirm route writes) and AC3 (the editor page consumes the confirm's change event and draws a new frame on the real instance).
- **Consumes:**
  - **20.7:** the three descriptors, the page, the store's `refresh()` and `revision`, and the frame. The hook is add-only: one subscription, one pure matcher, one bar line.
  - **20.21:** `ExplorerClassSave`, `ExplorerSaveMint`, `AgentProblem`, the hunk, the card's lines row and `explorerSaveNotCompiled`.
  - **20.19:** `ExplorerClassSource`.
  - **20.17:** the long-block collapse of a long hunk.
  - **20.18:** the screen-named refusal and the context's `unavailable` member.
  - **19.x:** `AtelierPort`.
- **Consumed-by:**
  - 20.12: a guided workflow may propose an editor save (inference).
  - 20.10: source-control hooks run on these saves too, through Atelier (inference).
  - 20.27's transformation test can check a DTL the agent changed (inference; no code).

**Rule 31 (extend, don't copy).** Every new class subclasses its sibling, adding parameters and three small overrides. `READWITH` makes `ExplorerSave`'s description reachable rather than copied. `SCREENLISTED` is a hook in the parent. The store's `shows` follows `code-compare.store.ts`'s `names(event)` as its own method, because the stores differ. The browser spec follows `agent-code-save`'s helpers. The kind scan repeats `TransformFactsHere`'s idiom for the reason given above.

**Rule 11.** At this plan, `origin/OCU-1-epic18` (`6ec2d9db`) is an ancestor of this branch, so Epic 18 has no committed diff beyond it. In flight is 18.37 (ready-for-dev), whose spec names `Port/InteropPort.cls`, `Screen/Read.cls`, `Screen/Registry.cls` and the navigation and mirror tests. This story touches these contended files only add-only:

- `InteropPort.cls`: one new method;
- `Baseline.cls`: three keys, plus the comma on the last line, as 20.27 did;
- `SurfaceCoverage.cls`, `ToolRoundTrip.cls` and `ReadTool.cls`: rows, with the count summed at the merge per the epic context;
- `strings.ts`, EXPERIENCE.md and the spine.

`Context.cls`, `Write.cls`, `ExplorerSave.cls`, `AtelierPort.cls`, `ToolEmit.cls`, `Test/Prohibited.cls`, `panel.ts`, `proposal-card.ts` and `proposal-view.ts` are not on the contended list. No Rule 11 ask.

**Named limits:**

- OcuPilot cannot see whether the editor holds unsaved changes; the warnings say so.
- The saves require `%Ens_Code:WRITE`, one pair where the vendor admits an OR list, so a holder of only `%Ens_DTL`, `%Ens_BPL` or `%Ens_Rules*` WRITE, whom the classic editor admits, is refused (stricter, by the orchestrator's ruling).
- A change confirmed while the editor is dirty drops those changes when the frame is redrawn, without the editor's alert (20.7's measurement).
- Only the open tab's editor reloads. Another tab's editor, and System Explorer's source editor, are not refreshed. An OcuPilot save from them is refused as a conflict. So is a DTL or BPL vendor save, which answers 409 on a newer `TimeChanged` (read in the hidden v3 and v4 source). The rule save's check runs the other way, so a stale rule editor in another tab can overwrite (inference).
- A save that does not compile leaves the class's running code broken until it is fixed (measured, DTL); the card says it did not compile.
- An edit may change the class's superclasses; the card shows it, and the screen then shows its coded or gone sentence.
- Lines past the read's 60,000-character cut cannot be quoted as an `Old` (DW-2243).
- A confirm on the editor screen still raises a toast that links to a `class` list (inference).
- The compile verdict reads the English console line; a localized compiler message falls back to the status errors (inference).

**Weight.** Shell chrome (`proposal-view.ts`, `proposal-card.ts`, `panel.ts`, `strings.ts`) adds about 1 kB to the initial bundle (inference), against about 1.90 MB after 20.27 and 20.7's ~5 kB, with `maximumWarning` 1992kB. The editor chunk grows by under 1 kB and stays under 88 kB. No page becomes eager.

**Size.** About 20.21's size. No split is recommended. If the lead splits, the one seam that stands alone is AC6's compile verdict, which could land first.

**Ledger.** This story owns no entries. DW-1882 (the hold) and AD-15 (the marker) are inherited. DW-2096 does not apply: there is no statement text.

## Verification

**Shared surfaces:**

- The tool registry: `ReadTool`'s count and names, `ToolRoundTrip`'s `REFUSEEMPTY`, `SurfaceCoverage`'s tool rows, `Test/Prohibited.cls`'s composed roster and `ToolEmit`'s branches.
- The governance baseline (three keys).
- The three editor screens' context `tools`, with the explorer screens' lists pinned unchanged.
- Every compile's, import's and save's `output.errors` (`AtelierPort.Outcome`).
- `ExplorerSave`'s `Edits` description (byte-identical by default).
- The proposal card's code-save consequence set, its saved-not-compiled banner and `panel.ts`'s `outputErrors` gate.
- 20.7's editor page and store (the change-event refresh, the bar line).
- The strings table and its bound, and EXPERIENCE.md :604, :718, :159 and :856.

*Every test added or changed passes on a fresh environment, in either order.* Each class and the browser spec make and remove their own `OcuProbe2016*` probes, generated classes and rule cache node, restore the two `^EnsPortal.Settings` nodes, and set or restore the governance policy they rely on.

**Setup (slot B; never the dev instance `ocupilot-slot-b`):**

- **Load `src`:**
  1. Run `rsync -a --checksum --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-20/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`.
  2. In `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`, run `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)` and check both the status and `tErrors`.
- **Before a browser run:** `cd ui && npm run build && docker exec ocupilot-b-ci sh -c 'cd /durable/iris/csp/ocupilot && rm -rf ./*' && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`.
- **Running tests:** one runner call at a time, each in the foreground with `timeout: 600000`. Read results back from `%UnitTest_Result`. Never re-submit after a client-side timeout.

**Commands:**

- `(loop)` `uv run scripts/check-objectscript.py <each changed .cls>` and `bash scripts/lint-docs.sh`. Expected: clean.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.InteropEditorTools --class OcuPilot.Test.InteropEditorSave --class OcuPilot.Test.InteropEditorSaveRules --class OcuPilot.Test.AtelierPortSave`. Expected: 0 failed.
- `(loop)` The same runner with `--class OcuPilot.Test.InteropEditorSaveGate`, then, as its own call, `--class OcuPilot.Test.InteropEditorSaveTurn`. Expected: 0 failed.
- `(loop)` The same runner with `ReadTool`, `ToolRoundTrip`, `SurfaceCoverage`, `Prohibited`, `ToolEmit`, `GovernanceBaseline` and `Governance` (about 45 s by `ci-timings.json`). Expected: 0 failed.
- `(loop)` The same runner with `ScreenGrounding`, `ExplorerSource`, `ExplorerDescriptor`, `InteropFloor`, `InteropFloorOwnPairs`, `DeveloperFloor`, `ExplorerSave`, `ExplorerSaveFlow`, `ExplorerSaveRules` and `ExplorerSaveMintUnit` (about 110 s). Expected: 0 failed.
- `(loop)` The same runner with `ExplorerSaveTurn`, `InteropEditorDescriptor`, `InteropDescriptor`, `CompileWithoutInterop`, `Guardrails`, `ToolSetFull`, and every class the roster sweep changed. Expected: 0 failed.
- `(loop)` `cd ui && npm run test:tools`, then `cd ui && npm run test:components`. Expected: green.
- `(loop)` `cd ui && npm run build -- --verbose`. Expected: the prebuild chain is green, the editor chunk is under 88 kB, and the initial total is under 1992kB. Record both.
- `(loop)` After the redeploy, one file per call: `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/<file>`. Expected: green.
  - `agent-editor-save.browser-spec.mjs`
  - `interop-editors.browser-spec.mjs`
  - `agent-code-save.browser-spec.mjs`
- `(once)` **One live turn**, on `claude-haiku-5-5` (owner decision 2026-10-12).
  - On `ocupilot-b-ci`, configure an Anthropic provider. Read the key from `/Users/jbrandt/git/OcuPilot/.env.local` at the point of use; never print, copy or log it.
  - On a probe DTL's editor screen in `USER`, ask: "Make this transformation add -live to the end of the value it sets."
  - Record whether the reply tells the person to save the editor before or with its first read, which tools it calls, and whether its proposal mints. Do not confirm it.
  - Remove the provider and the probe afterwards, and record the observation under this section.
- **Lead-owned (the runner's, not the implement stage's):** the full ObjectScript sweep, `cd ui && npm test`, `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`, and Rule 30's fresh check.
- **Left to CI:** the full browser suite.

**Planned pinning mutations (Rule 19).** Revert each to a byte-identical tree. Reload, or rebuild and redeploy, before the next.

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | The page omits the agent line | `interop-editor.page.spec.ts`; the browser bar leg |
| AC1 | `InteropEditorSave.WARN` loses "tell the person you work from what is saved" | `InteropEditorTools` description leg |
| AC1, AC7 | `Context.ScreenTools` ignores `SCREENLISTED` | `InteropEditorTools` context leg; `InteropEditorSaveTurn` starting-tools leg |
| AC2 | `InteropEditorSave` overrides `FINGERPRINTSUBJECT` without `Modified` | `InteropEditorSave` changed-after-mint leg |
| AC2 | `consequenceSentence` drops the new branch | `proposal-view.test.mjs` row; the browser card leg |
| AC3 | `shows()` compares the id case-folded with the namespace ignored, or always answers false | `interop-editor-store.test.mjs`; the browser reload leg (the old handle stays connected) |
| AC4 | `Baseline` `interop.transformeditor.save` is `false` | `InteropEditorTools` keys leg |
| AC5 | `InteropEditorSave.AgentProblem` skips the kind check | `InteropEditorSaveRules` wrong-kind, coded and Confirm-rule legs |
| AC5 | `IsCodeOfKind` stops excluding the base class | `InteropEditorTools` predicate leg (the base `Ens.DataTransformDTL` reads 1) |
| AC6 | `ConsoleCountsErrors` answers 0 | `AtelierPortSave` console leg; `InteropEditorSave` BPL leg |
| AC6 | `savedNotCompiledVisible` keeps its single code | `proposal-card-code-states.spec.ts`; the browser breaking leg |
| AC8 | `InteropEditorSave.PrivilegePairs` drops `%Development:USE` | `InteropEditorSaveGate` first leg (the refusal moves to the port); `ToolEmit` branch |
| AC8 | `InteropEditorSave.PrivilegePairs` drops `%Ens_Code:WRITE` | `InteropEditorSaveGate`'s vendor-write leg; `InteropEditorTools`' pairs leg |

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
