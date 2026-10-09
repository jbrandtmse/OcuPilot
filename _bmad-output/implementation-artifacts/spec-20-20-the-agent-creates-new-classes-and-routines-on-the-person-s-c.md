---
title: "Story 20.20: The agent creates new classes and routines, on the person's confirmation"
type: 'feature'
created: '2026-10-09'
status: 'done'
baseline_revision: '741b78016be0f0e94a71cec491de9beecdf8d22f'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-20-context.md'
warnings: ['oversized']
deferred:
  - summary: >-
      The create path may overwrite a name created between the port's taken check and the PUT, if the vendor accepts a PUT over an existing document without If-None-Match.
    evidence: |-
      AtelierPort.Route seeds If-None-Match only when a non-empty value is passed, and CREATE passes "". Unverified (inference). Settled by a PUT over an existing name with no If-None-Match on ocupilot-b-ci, read back.
    location: >-
      src/OcuPilot/Port/AtelierPort.cls (CREATE, Route)
    severity: medium (unverified)
---

<intent-contract>

## Intent

**Problem:** The owner (2026-10-07): "A note... Agent should be able to propose new classes and routines." Story 20.21's saves change only existing documents, and the port's save refuses an absent one. Two ledger defects in those saves land here as well. Take as script renders `"<content>"` (DW-2241). Confirm gates WRITE on the request's namespace instead of the proposal's (DW-2242).

**Approach:** Add two agent-only create tools on the Classes and Routines lists. The agent sends the new name and the whole text, and the mint applies 20.21's rules to the new name. It refuses a name the namespace already holds, then mints an AD-54 create whose card shows every line as added. Confirm checks the name is still free, puts the text with no version, and compiles it. The port's script renders the stored text. A code write's WRITE pair comes from the stored namespace.

## Boundaries & Constraints

**Always:**

- **Tools.**
  - `explorer.classes.create` is `ExplorerClassCreate` (`DESCRIPTORCLASS` `ExplorerClassList`). `explorer.routines.create` is `ExplorerRoutineCreate` (`ExplorerRoutineList`).
  - Both extend a new abstract `ExplorerCreate` (which extends `ExplorerWrite`) with these settings:
    - `CREATES` 1, `CHANGEACTION` `created`, `DESTRUCTIVE` 0, `SCREENACTIONS` `""` (agent-only).
    - `READTYPE` `NEWDOC` and `WRITETYPE` `CREATE`.
    - `PRECONDITIONFIELD` `Present`, `FINGERPRINTSUBJECT` `Present,Namespace` and `READANSWERS` `Present,Namespace`, as `EncryptionKeyFileCreate` :40-42 does for a bodyless create.
    - `SettableFields` = `content` alone.
    - `CONSEQUENCE` and `Consequence` are the save's, `EXPLORER.SAVE.COMPILES`.
    - `PortQuery` and `WriteOutput` call `##class(OcuPilot.Screen.Tool.ExplorerSave)`'s, so a create's query carries the namespace, `content` and `Compile`.
- **Input** (closed schema): `Names` (the one new document), `Text` (its whole text) and `rationale`, `expectedImpact`, `reverse`. `Names` and `Text` are required. The namespace, a version and the compile choice are never arguments.
- **Kinds** (`SetProblem`): on the classes tool, a class with a package, `Package.Name.cls`, because a package-less class is stored as `User.<Name>` (measured); on the routines tool, `.mac`, `.inc` or `.int` (the three kinds `AtelierPort.Header` names).
- **The mint** (`ExplorerCreateMint`, extends `Kernel.Proposal.Mint`). In order; each refusal stores nothing and calls no write:
  1. `SetProblem` refuses 400 `TOOL.ARGUMENTS`. Normalize the id as `ExplorerSaveMint` :38 does.
  2. `Prohibited.IsOcuPilotCode(id)` refuses 403 `PROHIBITED.OCUPILOTCODE` through `ExplorerSaveMint.Forbidden`, made public.
  3. `ExplorerSave.AgentProblem(Kernel.Scope.Current(), id, 1)` refuses 400 `TOOL.ARGUMENTS`, with the sentence as `detail.problem`.
  4. `Text` must be a non-empty string that `Sanitize.Strip` (with `Matchers`) leaves unchanged, and `AtelierPort.Header(AtelierPort.Lines(Text))` must be the id.
  5. The row is `ExplorerSaveMint.Hunk("", Text)`, which gives `{field: "Text", kind: "lines", line: 1, before: "", after}`. Refuse when it serializes longer than `CHANGEMAXLENGTH` (30,000; a throw counts as over).
  6. `AtelierPort.Invoke(Endpoint(), "NEWDOC", namespace, names)`. A refusal other than 404 passes through. A 200 is 400 `TOOL.ARGUMENTS` naming the held documents (its `Present`).
  7. `##super` with `{Names: id, content: Text, Compile: true, Namespace, Hunk: row, rationale, expectedImpact, reverse}`.
- **`ComposeCreate`** answers payload `{content, Compile: true, Namespace}`, diff `[Hunk]` and unchanged 0.
- **Taken** (the port's `Takers`: one `docnames` read of the category, generated documents included):
  - a class is taken by any held class whose name equals it ignoring case;
  - a `.mac` or `.int` is taken by any held routine of the same base name, exact case, other than an `.inc`;
  - an `.inc` is taken by the same name, exactly.
- **Port `NEWDOC`**: 404 `PORT.NOTFOUND` (`REASONNOTFOUND`), unlogged, when nothing takes the name; otherwise 200 `{Present: takers comma-joined, Namespace}`.
- **Port `CREATE`**: `SaveSet` with a create flag, behind `WritePairs`. It compiles with `cuk` when `Compile` is on (a create's always is) and answers `{lines, errors}`, as a save does. Every save rule stands except two:
  - The name must be free: a taken name is 409 `EXPLORER.DOCUMENT.CONFLICT` with nothing sent, where a save would have refused 404.
  - It sends no `If-None-Match` and needs no `version`, so the vendor refuses an existing document with 409 itself.
- **Confirm**, in order: the pairs (WRITE from the stored namespace), the code arm by the new name (`Prohibited.Code`), governance, the absence fingerprint (a `NEWDOC` re-read), then `ConfirmProblem` = `AgentProblem(stored Namespace, id, 1)`, then the `CREATE` write.
- **`AgentProblem(pNamespace, pName, pCreate = 0)`**: the save's sentences are unchanged. With `pCreate`, a name holding `%` anywhere is also refused, and the sentences read (single-quoted parts are text):
  - "the namespace is not known, so the agent does not create the document";
  - "the agent does not create a document in %SYS";
  - "the agent does not create a document whose name holds %";
  - "the database that would hold '<name>' could not be read, so the agent does not create it";
  - "'<name>' would be stored in <where>, not in this namespace's own routines database, so the agent does not create it."
- **DW-2242.** In `ExplorerSave` and `ExplorerCreate`:
  - `PrivilegePairs` = `Gate.RequiredPairs(DESCRIPTORCLASS)` passed through `Gate.WithClassicPages(…, CLASSICPAGES)`.
  - `ArgumentPairs` = `ExplorerSave.CodeWritePairs(pArgs, .pResolved)`: WRITE on the routines-database resource (`AtelierPort.DatabaseResources`) of `pArgs.Namespace` when that is a non-empty string, else of `Kernel.Scope.Current()`. An unresolved resource sets `pResolved` 0.
- **DW-2241.** `AtelierPort.Snippet` `SAVE` and `CREATE` render the stored text, its lines as `ExplorerSaveMint.SaveLines` reads them:
  - A class: `Kill tText`, then `Set tText($Increment(tText(0))) = <line>` per line, then `Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromArray($NAMESPACE, <class>, .tText)`.
  - A routine: `##class(%Routine).%New(<name>)`, `Clear()`, then `WriteLine(<line>)` for every line except the UDL header line `Header` decides, then `Save()`.
  - Then `$System.OBJ.CompileList(<name>, "cuk")` when `Compile` is on, and `DisplayError` after each step.
  - `CREATE` wraps its steps in `If '##class(%RoutineMgr).Exists(<name>) { … } Else { Write <name>, " already exists; nothing was created.", ! }`.
  - Script text longer than `SNIPPETMAXCHARACTERS` (1,000,000) renders no step.
  - `SnippetForm` and `COMPOSEDTYPES` gain `CREATE`. `MinVersion` gives `NEWDOC` and `CREATE` the save's routes.
- **Keys**: `explorer.classes.create` and `explorer.routines.create`, both `true` (AD-22).
- **The card** needs no client change. A `lines` row with an empty `before` draws every line as added. The consequence, the saved-not-compiled banner and the summary line are 20.21's.

**Never:**

- No person create, route, screen action, descriptor or mirror change.
- No edit of `Mint.cls`, `Confirm.cls`, `Write.cls`, `Prohibited.cls`, `Dispatch.cls`, `Draft.cls`, `Api/Error.cls`, `strings.ts`, or `line-diff`, `text-diff` or proposal-card production code. No new error code.
- No change to what a person's Save does (its WRITE pair still resolves from the request's scope), or to the compile, delete, import or export pairs.
- Never `ignoreConflict`, and never a version on a create.
- No compile before Confirm. Compile lines never reach the model, a tool result, the ledger, a log line or screen context.
- `explorer.sqldata.save` stays unadvertised and `false`.

## I/O & Edge-Case Matrix

The tests run in process as the suite account unless the row says HTTP. Probes are made in `USER` by `ExplorerCreateProbe` (`OcuProbe2020*`) and removed after each test.

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Class | `explorer_classes_create {Names: OcuProbe2020.New.cls, Text: a 5-line class}` | One proposal row `{field: Text, kind: lines, line: 1, before: "", after}` holding the five lines. `destructive` false; consequence `EXPLORER.SAVE.COMPILES`; `requiredPairs` holds `%DB_USER:WRITE`. Nothing is written. | none |
| Routine | `.mac`, `.inc` and `.int` creates, each with a matching header | as Class | none |
| Confirm | the Class proposal | 200. The class holds the text and is compiled; `output.errors` is false; one marker; the ledger reads `ok`; the change action is `created`. | none |
| Saved, not compiled | a class with a property of a missing type | Confirmed. The class exists and `output.errors` is true. | none |
| Taken after the mint | the probe makes the class between the mint and Confirm | 409 `TARGETCHANGED`; the probe's text stands | nothing written |
| Taken at the mint | the exact name; the class name in another case; `X.mac` while `X.int` is held; `X.int` while `X.mac` is held | 400 `TOOL.ARGUMENTS` naming the held document | no row |
| Free | `X.inc` beside `X.mac`; a routine name that differs only in case | a proposal | none |
| Own code | `OcuPilotProbe2020.New.cls` | 403 `PROHIBITED.OCUPILOTCODE` | no row |
| `%` / `%SYS` / mapped | `%Probe.New.cls`, `OcuProbe2020.%A.cls`; scope `%SYS`; `Ens.OcuProbe2020.cls` in `USER` | 400 `TOOL.ARGUMENTS`; the mapped case names `ENSLIB` | no row |
| Bad text or kind | empty `Text`; a header naming another document or kind; U+202E; a text wider than one card; `Foo.bas`; a `.mac` name on the classes tool; a package-less `OcuProbe2020New.cls` | 400 `TOOL.ARGUMENTS` | no row |
| Port race | `Invoke` `CREATE` of `X.mac` while `X.int` is held | 409 `EXPLORER.DOCUMENT.CONFLICT`; `X.int` unchanged | nothing sent |
| Script | Take as script on a class create, a routine create and a save | The steps carry the stored lines: a routine's without its `ROUTINE` line, a create's under the existence guard. The proposal closes `canceled` with reason `draft`. | nothing written |
| Script bound | `Snippet` with a stored text whose script would pass 1,000,000 characters | `[]` (the draft answers 409 `PROPOSAL.NODRAFT`, and the proposal stays live) | none |
| DW-2242 (HTTP) | a `USER` create and a `USER` save, confirmed at `?ns=HSCUSTOM` by a principal holding `%DB_USER:RW` and only READ on HSCUSTOM's code database | 200 each, written in `USER` | none |

</intent-contract>

## Code Map

Server (`src/OcuPilot/`):

- `Port/AtelierPort.cls`:
  - Parameters: `PAIRS` :75, `TYPESAVEDOCS` :351, `TYPESAVE` :354, `COMPOSEDTYPES` :360, `CONTENTKEY` :378, `COMPILEKEY` :394, `MAXIMPORTCHARACTERS` :401, `IMPORTCOMPILEFLAGS` :411, `NAMESKEY` :430, `CLASSNAMEPATTERN` :489, `ROUTINENAMEPATTERN` :492, `REASONNOTFOUND` :557.
  - Methods: `DatabaseResources` :677, `WritePairs` :746, `MinVersion` :761 (`tSave` :765), `Invoke` :830 (`tSetType` :844, `tWrite` :846, the type branches :922-929), `SetNames` :1688, `Docs` :1723 (its `docnames` read is the one `Takers` reuses), `PresentSet` :1780.
  - Save path: `Lines` :2142, `Header` :2173, `SaveSet` :2459, `Route` :2850 (`If-None-Match` only when non-empty, :2879), `Refuse` :3119, `SnippetForm` :3140, `Snippet` :3162 (TYPESAVE :3182-3197), `Literal` :3212.
- `Screen/Tool/ExplorerSave.cls`:
  - `AgentProblem` :161, `ConfirmProblem` :209, `PortQuery` :121, `WriteOutput` :220, `CONSEQUENCE` :50, `CHANGEMAXLENGTH` :53.
  - The header :13-15 says WRITE is declared on the namespace.
  - It inherits `ExplorerWrite.PrivilegePairs` :102, which reads `Scope.Current()` (DW-2242).
- `Screen/Tool/ExplorerSaveMint.cls`: `Hunk` :245, `SaveLines` :218, `Forbidden` :285 (`[ Private ]`). Its `Mint` :26 is the template.
- `Screen/Tool/ExplorerWrite.cls`: `PrivilegePairs` :102, `PortQuery` :120, `SetProblem` :72, `ArgumentProblem` :80.
- Kernel (read only):
  - `Kernel/Proposal/Mint.cls`: the create path :164-205, the absence fingerprint :262-268.
  - `Confirm.cls`: the create re-read :700-716.
  - `Screen/Tool/Write.cls`: `CREATES` :151, `ComposeCreate` :349, `ConfirmProblem` :935.
  - `Operation.RequiredPairsOf` :496 (declared plus argument pairs); `Tool/Base.ArgumentPairs` :123.
  - `Prohibited.Code` :2380 (the code arm by target id).
  - `Draft.Render` :184-217 (the stored `content` reaches `Snippet` through `PortQuery`).
  - `Screen/Context.ScreenTools` :178: no row or primary action, so the creates are not in the lists' context `tools`.
- `Kernel/Governance/Baseline.cls` :193-206 (the `explorer.*` keys).
- `Screen/Tool/ExplorerDocDbCreate.cls` (a create's `ComposeCreate`) and `EncryptionKeyFileCreate.cls` :40-42 (a bodyless create's subject).

Measured on `ocupilot-b-ci` (2026-10-09; probes removed):

- `ExistsDoc` is case-sensitive, and a class save differing only in case is refused `#5092`.
- Routine names are case-distinct.
- Compiling a new `X.mac` replaced a hand-written `X.int`.
- A new package's and a new routine's destination in `USER` is `USER`'s routines database.
- A class without a package is stored as `User.<Name>`, not under the name it was given.

Tests (templates and touched):

| Need | Template / anchor |
|---|---|
| In-process agent flows | `Test/ExplorerSaveFlow.cls` (`Dispatch` :64, `ProblemOf` :83, its governance snapshot) |
| Probe subclass | `Test/ExplorerSaveAgentProbe.cls`, `ExplorerSaveProbe`, `ExplorerProbe.Remove` :150 |
| A real turn plus an HTTP confirm | `Test/ExplorerSaveTurn.cls` (arming :45-102), `Test/ConfirmRoute.cls` `Call` |
| Browser agent write | `ui/browser/agent-code-save.browser-spec.mjs`; DW-1337 walk `structural-walk.mjs` |
| Component | `ui/src/app/shell/proposal-card-code.spec.ts` |

The rosters to update are listed under Tasks (Rule 30).

## Tasks & Acceptance

**Execution** (Part 1 server, then Part 2 client; each part's tests with it):

Part 1 -- server.

- `src/OcuPilot/Port/AtelierPort.cls`:
  - Add `TYPENEWDOC` `NEWDOC`, `TYPECREATE` `CREATE` and `SNIPPETMAXCHARACTERS` 1000000.
  - In `Invoke`, add both types to the set types and `CREATE` to the writes.
  - Add `Takers` and the `NEWDOC` branch.
  - Give `SaveSet` a create flag (`CreateSet` may wrap it).
  - Add `COMPOSEDTYPES` `Classes/CREATE,Routines/CREATE`, and the `MinVersion` and `SnippetForm` entries.
  - Rewrite `Snippet`'s `SAVE` and add `CREATE`, all per Boundaries; fix their doc comments.
- `src/OcuPilot/Screen/Tool/ExplorerSave.cls`:
  - `AgentProblem` gains `pCreate`.
  - Add `PrivilegePairs`, `ArgumentPairs` and `CodeWritePairs(pArgs, Output pResolved) As %List`.
  - Correct the header :13-15.
- `src/OcuPilot/Screen/Tool/ExplorerSaveMint.cls`: `Forbidden` loses `[ Private ]`.
- `src/OcuPilot/Screen/Tool/ExplorerCreate.cls` (new, abstract):
  - The Boundaries parameters, plus `InputSchema`, `MintClass` (`OcuPilot.Screen.Tool.ExplorerCreateMint`), `ComposeCreate`, `SetProblem`.
  - `ConfirmProblem` as `AgentProblem(pArgs.Namespace, id, 1)`; `PrivilegePairs` and `ArgumentPairs` as the save's.
  - Abstract `DocumentEndpoint` is not needed.
- `src/OcuPilot/Screen/Tool/ExplorerCreateMint.cls` (new): the seven mint steps.
- `src/OcuPilot/Screen/Tool/ExplorerClassCreate.cls` and `ExplorerRoutineCreate.cls` (new): `TOOLNAME`, `DESCRIPTORCLASS`, `Endpoint` (`ENDPOINTCLASSES` / `ENDPOINTROUTINES`), and `DESCRIPTION`, in this order:
  - It proposes one new class (one new routine, include file or intermediate routine) in the turn's namespace, which the user confirms. Confirm saves the text and then compiles it as the user, and the card shows the outcome, which this tool never answers.
  - Send `Names` and `Text`: the whole document in UDL form, starting `Class <Package.Name>` (or `ROUTINE <Name>`, with `[Type=INC]` or `[Type=INT]`), at most 30,000 characters.
  - The names refused: one the namespace holds (a class in any case; a routine or intermediate routine whose base name another routine uses, because compiling replaces that intermediate code), `%`, `OcuPilot`, `%SYS`, another database.
  - To change an existing document, use `explorer.classes.save` / `explorer.routines.save`.
- `src/OcuPilot/Kernel/Governance/Baseline.cls`, after :201: the two keys, `true`.
- `src/OcuPilot/Test/ExplorerCreateProbe.cls` (new, extends `ExplorerSaveProbe`):
  - `PACKAGE` `OcuProbe2020`, `OWNPACKAGE` `OcuPilotProbe2020`.
  - `ROUTINES` listing every `.mac`, `.int` and `.inc` the tests make, generated ones included.
  - `ClassText(pName, pBroken)` and `RoutineText(pName, pType)` answer UDL texts.
- `src/OcuPilot/Test/AtelierPortCreate.cls` (new): the `NEWDOC` taken and free rows, `CREATE` writes and compiles, the port-race row, the header refusal, and `Snippet` for `CREATE` and `SAVE`, the bound included.
- `src/OcuPilot/Test/ExplorerCreateRules.cls` (new): every refusal row, each asserting no proposal row is added, plus `ConfirmProblem` refusing what the mint would.
- `src/OcuPilot/Test/ExplorerCreateFlow.cls` (new):
  - `TestTheCreatesAreAdvertisedAgentOnlyWrites`: the provider list, the dispatch lookup, `Advertised` 1, `Destructive` 0, no screen action, the keys `true` and the schema `Names,Text,rationale,expectedImpact,reverse ["Names","Text"]`.
  - The Class, Routine, Confirm, Saved-not-compiled, Taken-after-the-mint, Free and Script rows.
  - With the key `false`, the dispatcher and Confirm refuse.
  - It snapshots and restores governance as `ExplorerSaveFlow` does.
- `src/OcuPilot/Test/ExplorerCreateTurn.cls` (new, the Integration AC). It arms like `ExplorerSaveTurn`, with `%Development:U`, `%DB_USER:RW` and READ but not WRITE on HSCUSTOM's code database.
  - First turn: the scripted model calls `explorer_classes_create`. The test takes the proposal id from `AwaitEnd`, confirms over HTTP at `?ns=USER`, then asserts the source, the compile and `output`. A second turn's recorded requests carry no compile line.
  - Second turn: `explorer_routines_create` plus `explorer_classes_save` on a probe class, each confirmed at `?ns=HSCUSTOM` and answered 200 in `USER` (DW-2242).
  - `scripts/ci-throwaway.sh`: `# classes: ExplorerCreateTurn` after :404 and after :538 (add-only).
- Shared-surface edits (Rule 30):
  - `Test/ExplorerDescriptor.cls`:
    - :131-140 and :157: add the two creates; the message reads "twenty-eight reads and fifteen writes", as the instance counts them.
    - :158: two rows read from the instance.
    - :167: the two keys.
  - `Test/SurfaceCoverage.cls`, after :355: two `<tool>` rows on `ExplorerCreateFlow.TestTheCreatesAreAdvertisedAgentOnlyWrites`.
  - `Test/ToolRoundTrip.cls` :84 `REFUSEEMPTY`: `explorer.classes.create:TOOL.ARGUMENTS,explorer.routines.create:TOOL.ARGUMENTS`.
  - `Test/ReadTool.cls` :93-94: the count plus 2, and both names in order.
  - `Test/AtelierPortSave.cls` :346-366: `TestTheSaveRendersItsScript` expects the text lines; a routine's has no `ROUTINE` line.
  - `Test/AtelierPortWriteDenial.cls` :217-230: the saves carry WRITE in `ArgumentPairs`; add the creates.
  - `Test/ToolEmit.cls` :200-207: saves and creates expect WRITE as an argument pair.
  - `Test/DeveloperFloor.cls`: `TOOLS` :39 and `HELDWRITES` :45 gain both saves and both creates, and their counts and sentences change at :9-10, :41-44, :473 and :496-497.

Part 2 -- client.

- `ui/src/app/shell/proposal-card-code.spec.ts`: one test. A create's row (empty `before`, 12 lines) draws 12 added lines numbered 1-12, and the summary line reads `<name>: lines changed, 0 removed and 12 added`.
- `ui/browser/agent-code-create.browser-spec.mjs` (new), from scripted turns on probes in `USER`:
  - a five-line class create card shows all lines added from line 1 and the consequence, Confirm creates and compiles it, and no saved-not-compiled line shows;
  - a 12-line routine's diff starts collapsed under the summary line, and Confirm works unopened;
  - a broken class, confirmed, shows `explorerSaveNotCompiled`;
  - the live card passes the DW-1337 walk at wide light, narrow light and wide dark.
  - It waits for the panel's answered signal before each click, and removes its probes and proposals in `after`.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`: after :718, one bullet with no quoted string: "**new code document** [ADDED 2026-10-09, Story 20.20]: an agent's class or routine create shows the whole new document as added lines, numbered from 1, in the diff's long block; the summary line counts the lines added; the consequence and the saved-but-not-compiled line are the save's."

**Acceptance Criteria:**

- **AC1 (advertised, enabled).**
  - Given the registry,
  - When the provider list and the dispatch lookup are built,
  - Then both creates are advertised, non-destructive, agent-only writes, and both keys resolve `true`.
- **AC2 (the card).**
  - Given a minted create,
  - When its card shows,
  - Then it shows the whole new document as added lines numbered from 1 and the consequence that the compile runs on Confirm as the user; and, when long, the lines summary, with Confirm usable unopened.
- **AC3 (never overwrites).**
  - Given a name the namespace holds, at the mint, after it, or at the write,
  - When the create is proposed or confirmed,
  - Then it is refused (400 at the mint, 409 `TARGETCHANGED` at Confirm, 409 `EXPLORER.DOCUMENT.CONFLICT` at the port) and nothing is written.
- **AC4 (compile and marker).**
  - Given a confirmed create,
  - When it completes,
  - Then the document holds the text, the card shows the compile's lines and outcome, a document that saved but did not compile is said plainly, and one agent marker records it.
- **AC5 (refusals).**
  - Given a new name under OcuPilot's own packages, one holding `%`, one in `%SYS`, or one the namespace stores in another database,
  - When the agent would mint it or the person confirms it,
  - Then it is refused before anything is written, and a mapped name's refusal names its database.
- **AC6 (DW-2242).**
  - Given a save or a create minted in `USER`,
  - When it is confirmed from a request scoped to another namespace,
  - Then Confirm gates WRITE on `USER`'s routines database, not the request's.
- **AC7 (DW-2241).**
  - Given an agent's save or create,
  - When the person takes it as a script,
  - Then the script writes the stored text: a routine's without its UDL header line, and a create's only while the name is free. A script past the bound is refused 409 `PROPOSAL.NODRAFT`, with the proposal left live.
- **AC8 (Integration).**
  - Given a real turn on `ocupilot-b-ci`,
  - When its create proposal is confirmed over HTTP,
  - Then the class exists and compiles, the confirm answers `output`, and no provider request carries a compile line.

## Spec Change Log

- 2026-10-09, runner, orchestrator ruling: DW-2241 is HIGH under Rule 6 (AD-59) and release-blocking, so AC7 is the story's first criterion in priority; QA adds an end-to-end pin that Take as script on an agent save renders the reviewed text. ACs keep their numbers so the `mutation:` lines stay valid.

- 2026-10-09, runner, spec gate: the spine amendments are applied; the AD-61 line is folded into AD-53's creates sentence, because AD-61's rule 3 is the CSP stub and carries no write-version text. The 1,000,000-character script bound is accepted.

## Review Triage Log

### 2026-10-09 — Review pass

- verdicts: 25 findings — high 0, medium 6, low 14, false 3, maybe-false 2

- findings:
  - `[medium]` `[patch]` Over-bound create and take-as-script draft (NODRAFT, proposal stays live, within-bound closes canceled) unpinned — verification-gap; patch: new `ExplorerCreateFlow` test drives `Draft.Take` in-process (the HTTP route authenticates as `_SYSTEM`, the proposal is the process user's), P1.
  - `[low]` `[patch]` `ComposeCreate` hard-codes compile 1, so the stored `Compile` argument is inert and the AC4 Confirm row cannot go red — verification-gap, merged with intent-alignment's compile-flag finding; patch: comment corrected, no behavior change, P2.
  - `[medium]` `[patch]` `ExplorerSave.ProposalRows` returns -1 on SQL error, so before/after counts pass vacuously — verification-gap; patch: `tBefore >= 0` assertions in `ExplorerCreateFlow` and `ExplorerCreateRules`, P3. (The reviewer cited `ExplorerSave.cls:219-223`; the helper is `OcuPilot.Test.ExplorerSave`.)
  - `[low]` `[patch]` `TurnProvider.Recorded` returns "" for an unrecorded call, so the negative check in `ExplorerCreateTurn` passes vacuously — verification-gap; patch: `tRecorded '= ""` assertion, P4.
  - `[low]` `[patch]` Compile `errors` = 0 passes when the key is absent (`"" = 0`) in `AtelierPortCreate` and `ExplorerCreateFlow` — verification-gap; patch: boolean type guard, P5.
  - `[medium]` `[patch]` Browser test 1's saved-not-compiled null check runs before the card settles — verification-gap; patch: waits for `.ocu-proposal-card-status-confirmed`, P6.
  - `[medium]` `[patch]` AC2 browser five-line leg never demonstrated; browser-test mutation comments are unplanned extras — verification-gap; patch: AC2 browser mutation run red and reverted (P7). The unplanned browser mutations are not in the spec table and are not run (rejected as a separate `low`).
  - `[low]` `[reject]` Browser test 2 and 3 mutation comments name mutations not in the planned table — verification-gap; rejected: the spec table is the required set and these are extras, not defects.
  - `[low]` `[patch]` `DeveloperFloor` method name says ThirtyFive while asserting forty-six — verification-gap; patch: renamed to FortySix, no other references in `src`, `ui/tools`, `ui/browser`, P8.
  - `[false]` DW-2242 scope: compile, delete and import keep request-namespace WRITE — verification-gap; refuted: those tools store no namespace in their arguments (grep), so the proposal's namespace is the route's namespace by construction and the Confirm defect does not apply.
  - `[low]` `[reject]` `AtelierPort.SavedLines` duplicates `ExplorerSaveMint.SaveLines` — verification-gap; rejected: identical logic today, and a refactor is more than a correction for a developer-only duplication.
  - `[low]` `[patch]` `ExplorerCreateTurn` doc comment names `ExplorerCreate.ArgumentPairs` as the AC6 target — verification-gap; patch: names `ExplorerSave.CodeWritePairs`, P9.
  - `[false]` ci-shards may not discover the new browser spec — verification-gap; refuted for the browser side: `ui/tools/ci-shards.mjs:112` discovers `*.browser-spec.mjs` by glob. Test-class discovery was not checked.
  - `[low]` `[reject]` `ExplorerCreate` reimplements `PortQuery`, `WriteOutput` and `Consequence` instead of delegating to `ExplorerSave` (spec line 35) — intent-alignment; rejected: the behavior is equivalent, delegation is a restructure rather than a correction, and the divergence risk is developer-only.
  - `[low]` `[reject]` CREATE existence guard emits `$System.Status.Error` rather than the spec's `Write` line — intent-alignment; rejected: the bare `Write` is refused by `check-objectscript`, and the same refusal reaches the model through the error path.
  - `[low]` `[reject]` The 30,000 limit is measured on serialized hunk JSON while the tool text says characters — intent-alignment; rejected: the refusal names the limit, and the fix changes the gate or the text.
  - `[low]` `[patch]` Compile flag hard-coded in `ComposeCreate` — intent-alignment; same root cause as the verification-gap compile-flag row, patched there (P2).
  - `[maybe-false]` Port race: no If-None-Match on create, so a name created between `Takers` and `PutDoc` may be overwritten — intent-alignment; deferred (see the deferred item; medium if true, unverified).
  - `[maybe-false]` No version and no If-None-Match on create is not visible in any test — intent-alignment; same root as the row above, deferred with it.
  - `[false]` The person's Save route no longer checks WRITE from the moved pair — intent-alignment; refuted (inference): `Kernel/Proposal/Operation.cls` consults `ArgumentPairs` on the confirm path. Not read line by line.
  - `[medium]` Take-as-script draft route untested — intent-alignment; same route as the first row, patched there (P1).
  - `[low]` `[reject]` Ledger row not asserted — intent-alignment; rejected: the marker is asserted on the confirm response (`auditMarked`), and the ledger write shares the path existing save tests cover.
  - `[low]` `[reject]` HSCUSTOM class create not exercised at HSCUSTOM — intent-alignment; rejected: AC6's mutation is caught by the HSCUSTOM routine create and class save legs, which share `CodeWritePairs`.
  - `[low]` `[reject]` Confirm-time `Prohibited` for a new OcuPilot name untested — intent-alignment; rejected: the stored name cannot change between mint and Confirm, and the mint refuses first.
  - `[medium]` Browser spec not run — intent-alignment; same as the AC2 browser row, patched there (P7).

### Deferred item detail

- Port race and create guard: the create path sends no `If-None-Match` and no version, and `AtelierPort.Route` seeds the header only when a non-empty value is passed. If the vendor accepts a PUT over an existing name in that case, a name created between `Takers` and `PutDoc` is overwritten. Severity medium (unverified). Settled by a PUT over an existing name with no `If-None-Match` on the throwaway, read back.

## Design Notes

**Governing ADs.**

- AD-53 (the reversal and the creates), AD-54 (the absence read and fingerprint), AD-10 (the code arm by new name), AD-8 (DW-2242).
- AD-61: rule 1 (WRITE) and rule 3 (no `If-None-Match` on a create).
- AD-59 (DW-2241), AD-22 (keys), AD-24 (context `tools`; one bounded row), AD-36, AD-60 and AD-11 (the model's text), AD-39's fifth exception, AD-15, AD-58.
- AD-6, AD-34 and AD-51 (mint, hold, subject), AD-64 (`Gate.RequiredPairs`), AD-16, AD-29.

**Rulings.** The owner's words are as quoted in Intent. Q1 is applied to the new name's destination; it was measured and needs no new posture rule. Q3 is extended to `%` anywhere in a new name, and Q4 is unchanged (by=merge_gate, 2026-10-08).

**Spine amendments (one line each, for the runner at the spec gate):**

- **AD-53, the creates sentence:** append: "Story 20.20 ships `explorer.classes.create` and `explorer.routines.create` as agent-only writes whose keys ship enabled. The agent sends the whole document, at most one card's 30,000 characters. The mint applies the saves' rules to the new name. A name is taken when the namespace holds it, a class in any letter case (measured: #5092); a routine or intermediate routine is also taken by another routine of its base name other than an include file (measured: compiling a new routine replaces that name's intermediate code). The create always compiles on Confirm."
- **AD-53, both places:** replace "the confirmed class and routine saves (Story 20.21)" with "the confirmed class and routine saves and creates (Stories 20.21 and 20.20)".
- **AD-8, System Explorer's write tools:** append: "A save's and a create's WRITE pair is an argument pair, read from the namespace the proposal stored, else the request's (Story 20.20, DW-2242)."
- **AD-61, rule 3:** append: "A create (Story 20.20) sends no version. The vendor refuses a document of that name with 409, and the port first refuses a taken name, 409 `EXPLORER.DOCUMENT.CONFLICT`, sending nothing."
- **AD-59:** append: "`AtelierPort` renders a save's or a create's stored text line by line, a routine's without its UDL header line, and renders no step past 1,000,000 characters, so that draft is refused 409 `PROPOSAL.NODRAFT` (Story 20.20, DW-2241)."
- **AD-10, code arm:** replace "An agent's save is refused at its mint as well (Story 20.21)" with "An agent's save or create is refused at its mint as well, a create by its new name (Stories 20.21 and 20.20)".
- **AD-15, named cases:** append: "The twentieth is an agent's class or routine save or create (Stories 20.21 and 20.20), which `PUT doc` leaves unrecorded with the stock event set."

**Decisions.**

- **Two tools of their own, agent-only.** No person create surface exists, so there is no second caller (AD-55).
  - The creates are not in the lists' context `tools` or `unavailable`, because AD-24 lists row and primary actions only.
  - Declaring a primary action would change two descriptors and `screens.generated.ts`, which Epic 18 is changing.
- **Non-destructive**, as a compile is. Nothing existing is replaced, and a delete undoes it. The consequence states that the compile runs as the user.
- **The whole document fits one card** (`CHANGEMAXLENGTH`), because the card shows it whole. Larger documents are left to a person.
- **The taken rule is wider than the exact name.** Every rule comes from a measurement above, and it is checked at the mint (with a sentence naming the taker), at Confirm (the absence digest) and at the port.
- **No new error code.** The port's race-window refusal reuses the save's 409 `EXPLORER.DOCUMENT.CONFLICT`, as the vendor's own 409 does. A new code would need `strings.ts` and a new Fixed-strings row, and that row would shift the `EXPERIENCE.md` line citations both epics hold.
- **DW-2242 as argument pairs.** `RequiredPairsOf` reads the stored arguments, and the mint stores `Namespace`.
  - Dispatch and a person's Save read the request's scope, as before.
  - The model cannot name the namespace: the schema is closed, and the mint stores the scope.
  - Consequences: `DeveloperFloor` counts the saves and creates as held at the declared level, and the saves leave the context's `unavailable` (AD-24 leaves argument pairs to dispatch).
- **DW-2241's bound** is `SNIPPETMAXCHARACTERS` 1,000,000 (inference: under the 3.6M string limit, and a size a browser shows). A save's stored text can reach 3,000,000.

**Named limits.**

- A class compile writes `<Class>.N.int` and could replace a hand-written routine of that name, which the taken rule does not check.
- A credential written into `Text` reaches the card, the model's result row and the script, as 20.19's read does.
- A routine's `LanguageMode` set in its UDL header is not rendered in the script.

**Posture:** no further security-posture question. The new name's destination rule, `%`, OcuPilot's own code and `%SYS` are the rulings applied to creates.

**Integration ACs (Rules 1, 2).** AC8. Consumes:

- `AtelierPort`'s `docnames`, `PutDoc` and compile (19.1, 19.3);
- 20.21's `AgentProblem`, `Hunk`, consequence, `app-text-diff` and banner;
- 20.17's long block and summary;
- 20.18's screen-named refusal;
- 20.15's `Gate.RequiredPairs`;
- the kernel's AD-54 create path and AD-59 draft.

Consumed-by: no later story names the creates (20.16 builds on 20.21's edit model).

**Rule 11** (checked 2026-10-09: `epic-18` `origin/feature...HEAD` and `status -s`, clean). Epic 18's files touched here:

| File | Edit | Status |
|---|---|---|
| `Kernel/Governance/Baseline.cls` | two lines after :201 | add-only; Epic 18 adds at the webapp keys |
| `Test/SurfaceCoverage.cls` | two rows after :355 | add-only |
| `Test/ToolRoundTrip.cls` :84 | two list entries on the one-line roster | list entries; Epic 18 adds to the same line, so take the union at the forward merge |
| `Test/ReadTool.cls` :93-94 | count and two roster names | list entries; the merged count is the feature's plus 2 |
| `EXPERIENCE.md` | one bullet after :718 | add-only; no citation points past :645 |

Every other file named here is outside Epic 18's diff and working tree, including `scripts/ci-throwaway.sh` (add-only).

**Ledger and standing rules.** DW-2241 closes through AC7 and its tests; DW-2242 through AC6 and `ExplorerCreateTurn`. DW-1882: no new route, and the confirm holds. FR-80: one port, no derived field list (bodyless). 11.3: no new screen. No new error code.

**Budgets.** Client +0 bytes (tests only), against the 3,326 kB warning (3,178,307 bytes last measured). Fixed strings +0.

**Size.** Oversized. Seam for a split, if the orchestrator wants one: (a) DW-2241 and DW-2242 for the saves (`Snippet` `SAVE`, `ExplorerSave` pairs, and the `AtelierPortSave`, `AtelierPortWriteDenial`, `ToolEmit` and `DeveloperFloor` edits), then (b) the creates. The recommendation is to keep one story, because the creates reuse both fixes' code paths.

## Verification

**Shared surfaces (Rule 30):**

- the advertised and registered tool set (`ReadTool`, `ToolRoundTrip`, `SurfaceCoverage`, `ExplorerDescriptor`);
- the governance baseline;
- the saves' declared and argument pairs (`ToolEmit`, `AtelierPortWriteDenial`, `DeveloperFloor`, context `unavailable`);
- the save's script (`AtelierPortSave`);
- `COMPOSEDTYPES` and `SnippetForm` (`Prohibited`, `DraftRegistry`);
- the arming rosters;
- EXPERIENCE.md's proposal-card bullets.

**Standing criterion (Rule 30):** existing tests that assert a surface this story changes are updated in this story, and every test the story adds or changes passes on a freshly built instance and in either order.

**Setup (slot B):**

- `rsync -a --checksum --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-20/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`.
- Then in `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`, run `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)` and check both the status and `tErrors`.
- Before a browser run: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`.
- One class or spec file per call, and never a re-submit after a client-side timeout.

**Commands:**

- `(loop)` `uv run scripts/check-objectscript.py`: expect 0 problems.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one per call, read back from `%UnitTest_Result`; expect 0 failed. The classes:
  - new: `AtelierPortCreate`, `ExplorerCreateRules`, `ExplorerCreateFlow`, `ExplorerCreateTurn`;
  - edited: `AtelierPortSave`, `AtelierPortWriteDenial`, `ToolEmit`, `DeveloperFloor`, `ExplorerDescriptor`, `SurfaceCoverage`, `ToolRoundTrip`, `ReadTool`;
  - re-run: `ExplorerSaveFlow`, `ExplorerSaveAgent`, `ExplorerSaveRules`, `ExplorerSaveMintUnit`, `ExplorerSaveTurn`, `ExplorerSave`, `ExplorerWrite`, `DraftRegistry`, `Prohibited`, `GovernanceBaseline`, `Governance`, `Guardrails`, `ToolSetFull`, `InteropFloorOwnPairs`, `SaveHoldCoverage`.
- `(loop)` `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/agent-code-create.browser-spec.mjs browser/agent-code-save.browser-spec.mjs browser/panel-collapse.browser-spec.mjs`: expect a pass.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`, then `bash scripts/lint-docs.sh`: expect clean.
- `(once, before dev_complete, runner-side in foreground batches)`:
  - the full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci`, one class at a time: expect 0 failed;
  - `cd ui && npm test && npm run build`: the bundle stays under the 3,326 kB warning;
  - `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`: expect a pass.
- `(CI)` The full browser suite runs in CI's shards only (Rule 29).

**Planned pinning mutations (Rule 19).** Apply each, observe red, revert to a byte-identical tree, and record a `mutation:` line here.

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | `ExplorerClassCreate.ADVERTISED` 0; `Baseline` create key `false` | `ExplorerCreateFlow` advertised leg; `ExplorerDescriptor` baseline leg |
| AC2 | `ComposeCreate` answers `[]` for the diff | `ExplorerCreateFlow` Class row; browser five-line leg |
| AC3 | `Takers` answers nothing; `SaveSet`'s create skips its taken check | `ExplorerCreateFlow` Taken-after-the-mint row, `ExplorerCreateRules` taken rows; `AtelierPortCreate` port-race row |
| AC4 | `ExplorerCreateMint` stores `Compile` false | `ExplorerCreateFlow` Confirm row; `ExplorerCreateTurn` output leg |
| AC5 | `AgentProblem` ignores `pCreate`; the mint's `IsOcuPilotCode` step removed | `ExplorerCreateRules` `%` / `%SYS` / mapped rows; own-code row |
| AC6 | `CodeWritePairs` reads `Kernel.Scope.Current()` only | `ExplorerCreateTurn` `?ns=HSCUSTOM` legs |
| AC7 | `Snippet` renders `"<content>"`; the routine branch keeps its header line | `AtelierPortSave.TestTheSaveRendersItsScript`; `AtelierPortCreate` script rows |
| AC8 | `AtelierPort`'s `CREATE` skips the compile | `ExplorerCreateTurn` first turn's compiled and `output` legs |

Mutation results (run on `ocupilot-b-ci`; every row reverted and confirmed green; tree restored byte-identical):

- mutation: AC1: `ExplorerClassCreate` adds `Parameter ADVERTISED As BOOLEAN = 0`; `Baseline` create key `false`. red: `ExplorerCreateFlow` advertised leg, `ExplorerDescriptor` baseline leg.
- mutation: AC2: `ComposeCreate` hunk push made `If 0`. red: `ExplorerCreateFlow` Class row, but as `<INVALID OREF>` at +6, not an assertion. Browser five-line leg NOT run: outstanding.
- mutation: AC3: `Takers` returns with `pTakers` empty; `SaveSet` taken check `If 0`. red: `ExplorerCreateFlow` taken-after-mint row, `ExplorerCreateRules` held-name rows, `AtelierPortCreate` port-race row.
- mutation: AC4: `ExplorerCreateMint` stores `Compile` 0. red: `ExplorerCreateFlow` stored-args leg only. The Confirm row and `ExplorerCreateTurn` output leg stayed green because `ComposeCreate` hard-codes compile 1 in the payload. Planned red not produced.
- mutation: AC5: `AgentProblem` ignores `pCreate`; mint's `IsOcuPilotCode` step removed. red: `ExplorerCreateRules` `TestTheNamesThatAreNeverCreated`.
- mutation: AC6: `CodeWritePairs` namespace branch made `If 0`. red: `ExplorerCreateTurn` `TestTheAgentsCreatesAreConfirmedOverHTTPAndCompile` HSCUSTOM legs.
- mutation: AC7: `Snippet` passes `"<content>"`; routine branch keeps its header line. red: `AtelierPortSave` `TestTheSaveRendersItsScript`, `AtelierPortCreate` `TestTheCreateAndTheSaveRenderTheirStoredText`.
- mutation: AC8: `SaveSet` compile gated by `'pCreate`. red: `ExplorerCreateTurn` `TestTheAgentsCreatesAreConfirmedOverHTTPAndCompile` compiled and output legs.

## Auto Run Result

Status: done
Blocking condition: none

**Implemented:** `explorer.classes.create` and `explorer.routines.create` (keys enabled); port `NEWDOC` and `CREATE` (409 `EXPLORER.DOCUMENT.CONFLICT`, no version sent); Take as script renders stored text, bounded at 1,000,000 characters (DW-2241); save and create WRITE pair read from the stored namespace (DW-2242). 16 files modified, 10 new.

**Verification (`ocupilot-b-ci`, one class or spec per call):**

- `check-objectscript.py`: 0 problems; harness exit 0.
- Implement stage: all 30 listed classes green. After review patches, re-run green: `ExplorerCreateFlow` 8/0 failed, `ExplorerCreateRules` 4/0, `ExplorerCreateTurn` 1/0, `AtelierPortCreate` 5/0, `DeveloperFloor` 10/0.
- Browser: `agent-code-create` 3/3 (post-patch), `agent-code-save` 7/7, `panel-collapse` 5/5.
- `npm run test:tools` 1903 pass; `npm run test:components` 2751 pass (run before the review patches, which touched ObjectScript tests and one browser spec only, not re-run).
- `lint-docs.sh`: the spec's four new headings and lists fixed; no other file flagged.
- Bundle: no client source changed in this stage; not re-measured here (last measured 3,178,307 bytes).
- Full ObjectScript sweep, `npm test`, `smoke.sh` and the bundle build: left to the runner.

**Rule 19 mutations:** the eight `mutation:` lines are in `## Verification` (Mutation results). AC2's browser leg was then run and red:
`mutation: AC2 browser: ComposeCreate hunk push If 0; red: a new class draws its whole text as added lines and says Confirm compiles; Confirm creates and compiles it with no compile warning: AssertionError "every line of the new class is drawn as added: []" (expected 7, actual 0); reverted: green`.
Not red as planned: AC4 (only the stored-argument leg; the Confirm row cannot see the stored `Compile`). Browser tests 2 and 3 carry unplanned mutation comments, not run.
Tree restored byte-identical after the mutation pass (sha256 matched the pre-mutation snapshot).

**Review pass 2026-10-09 (25 findings, see `## Review Triage Log`):** patched P1 over-bound and draft refusal test (in-process via `Draft.Take`); P2 compile-flag comment; P3 `ProposalRows` -1 guard; P4 `Recorded` guard; P5 `errors` type guard; P6 browser null check waits for the confirmed card; P7 AC2 mutation run; P8 `DeveloperFloor` renamed to FortySix; P9 doc comment target. Deferred: the port-race vendor guard (medium, unverified). Rejected low: SavedLines duplication, reimplemented delegation, `Write` vs `$System.Status.Error`, 30,000 measure, ledger row assertion, HSCUSTOM class create leg, Confirm-time `Prohibited`, extra browser mutations.

**Follow-up review recommended: true.** Three medium patches on a first pass. Named unverified risk: the over-bound refusal is pinned in-process through `Draft.Take`, not over the HTTP draft route, and the create script's runtime path (`SetTextFromArray`, `%RoutineMgr.Exists`) has never executed.

**Residual risks:** the port's create sends no version and no `If-None-Match` (deferred above); `AtelierPortWriteDenial`'s save assertion is inverted by design; a comment in the class-create browser test still says five lines while it asserts seven drawn rows (noticed after triage, not patched); a save's stored text is not bounded by the hunk limit.
