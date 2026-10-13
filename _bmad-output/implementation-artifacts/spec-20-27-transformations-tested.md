---
title: 'Story 20.27: Transformations tested'
type: 'feature'
created: '2026-10-12'
status: 'in-progress'
baseline_revision: '663eff71f6d0f39290463136332c58560703d22a'
baseline_commit: '663eff71f6d0f39290463136332c58560703d22a'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** A data transformation can be tested only in the classic portal's Test Transform dialog (`EnsPortal.Dialog.TestTransform`). Data transformations in OcuPilot lists them and does nothing else, so a change cannot be checked here before it is deployed.

**Approach:** Extend `Port/InteropPort` (AD-62 item 11, the transformation half Story 20.6 left as its Part B) with a composed `TRANSFORM` read and a `TRANSFORMTEST` write on the `Transforms` endpoint. Pasted text is parsed into the transformation's source class, `Transform` runs once in the request's process, and the target renders as text. It is one operation reached by two callers (AD-53): a Test row action on Data transformations and the agent's `interop.transforms.test` proposal. It is a confirmed write that is not destructive, and its key ships `true`. The output reaches the screen and the card only (AD-39's seventh exception).

## Boundaries & Constraints

**Always:**

- Every new call goes through `InteropPort.Invoke` behind `Admit` (AD-29, AD-62 item 2). The pairs are Data transformations' `CODEPAIRS` (`%Ens_Portal:USE`, `%Ens_Code:READ`) plus `%Ens_DTLTest:USE` for `TRANSFORM` and `TRANSFORMTEST`, then WRITE on the namespace's globals database for the write. No routines database (`IsTestWrite`). The vendor checks no privilege (measured, 20.6), so this gate is the whole gate.
- **Listed.** The id is a Data transformations row's `Name`, `<class>.cls`, kept exactly (AD-13).
  - Listed means `ListClasses`' predicate: a `SubclassOf` `Ens.DataTransform` other than `Ens.DataTransformDTL`.
  - To run, the class must also be compiled in the namespace.
  - Anything else, with or without the action key, is 404 `PORT.NOTFOUND`.
- **Formats, judged before any vendor call** (`%Extends` on the declared class, in this order, for the source and for the target):
  1. Record Map or batch (`EnsLib.RecordMap.Base`, `.Batch`, `.ComplexBase` or `.ComplexParent`): refused, even though most of these classes are `%XML.Adaptor` (measured).
  2. Virtual document (`EnsLib.EDI.Document`, which also covers segments and `EnsLib.EDI.XML.Document`): kind `document`.
  3. `%XML.Adaptor`: kind `xml`.
  4. Anything else, including a class not compiled in the namespace: refused.
  - Refusal codes: 409 `INTEROP.TRANSFORM.SOURCEFORMAT`, then `TARGETFORMAT`.
- **Content.**
  - The port's composed read refuses `content` that is empty or over `AtelierPort.#MAXIMPORTCHARACTERS` with 422 `INTEROP.TRANSFORM.CONTENT` on `content`. The screen's value reaches it unjudged when it is a string.
  - The agent's `content` is 1 to `ExplorerSave.#CHANGEMAXLENGTH` characters; otherwise it is refused `TOOL.ARGUMENTS` before the mint.
- **The run** follows the classic dialog's calls (`TestTransform.cls`:449-569) and the hidden reader's parsers.
  - All vendor work runs switched by explicit save and restore (AD-16), inside the output capture `PerformTest` opens: parse, target creation, `Transform`, render and cleanup. Only the port's own `...Here` methods run while switched, never another `OcuPilot.*` class (AD-62 item 3).
  - **Parse.** A document source uses `$ClassMethod(SourceClass, "ImportFromString", content, .tSC)` and is then made immutable (`IsMutable` 0), as `Ens.Util.Serialized.Reader` does. An XML source must start with `<` after leading blanks, then goes through `Ens.Util.XML.Reader.ObjectFromString(.source, content, SourceClass)`. A parse that answers an error, or no object, is status `input`.
  - **Target.** For `create="existing"`, the target is `$ClassMethod(TargetClass, "%New")` with no argument. Otherwise none is passed.
  - **Transform.** `New process, context`, then `$ClassMethod(Name, "Transform", source, .target)`. An error status, or a fault the port traps, is status `transform`.
  - **Render.**
    - `EnsLib.EDI.XML.Document`: `OutputToLibraryStream(stream, "wt")`.
    - Another `EnsLib.EDI.Segmented` document: `OutputToLibraryStream(stream, separators)`, with the separators built as `TestTransform.cls`:527-532 builds them.
    - Another document: `OutputToLibraryStream(stream)`.
    - `%XML.Adaptor`: `%XML.Writer` with `Indent` 1, `OutputToStream` and `RootObject`.
    - Each writes into a `%Stream.TmpCharacter`, from which at most `TESTOUTPUTMAX` + 1 characters are read.
    - No target object, a render error, or a target that is neither kind is status `output`.
  - **Cleanup.** A source or target that gained an `%Id()` is deleted (`%Delete(%Oid())`) before the answer, whatever the status. A failed delete is logged without content and does not change the answer.
- **The answer** is 200 `{status, sourceClass, targetClass, lines, console, errors}`.
  - `status` is one of `done | input | transform | output`, and `errors` is true for the last three.
  - `lines` holds the target's text, or the status's error text. `console` holds what the vendor calls wrote to the device.
  - Both go through `AddTestLines` after the restore, sharing one `TESTOUTPUTMAX` total, the last cut marked `TESTCUT`.
  - The HTTP answer stays a JSON envelope.
- **Never reaches anything else.** The output, error and console lines reach the screen and the proposal card only, as text and never markup (AD-39's seventh exception, AD-47, AD-11). They never reach the model, a tool result, a ledger row, an audit payload, a log line or screen context. No `LogFault` call carries content, lines or console.
- **Audit.** Each run records OcuPilot's own `ConfigChange` from either caller: `AuditRuntime("test", "class", Name, {namespace, sourceClass, targetClass, status})`. It never carries content or lines (AD-15).
- **Contended files.** Edits to files Epic 18 also changes are add-only (Design Notes › Contended files).

**Never:**

- No file picker, server path or upload (AD-21). Pasted text only, and no `aux`, `process` or `context` values.
- No `Include Ensemble`, and no `Ens*`/`EnsLib*` type in any shipped signature, superclass or property (AD-62 item 12, `CompileWithoutInterop`).
- No call to the `[Hidden]` `Ens.Util.Serialized.Reader`, to `OutputHTMLZen` or to `%Api.InteropEditors.*`.
- No new entity type, no new screen or descriptor read, and no edit to `Kernel/Proposal/Prohibited.cls`, `Screen/Registry.cls`, `Screen/Read.cls`, `app.routes.ts`, `angular.json`, `.github/workflows/ci.yml`, `ui/tools/ci-shards.mjs`, `ui/tools/ci-timings.json` or `ui/tools/ci.test.mjs`.
- No edit to the Data transformations list's rows, read or three suggested prompts.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Run, XML | A listed XML-to-XML transformation, `<StringRequest><StringValue>x</StringValue></StringRequest>` | `done`, `lines` = the target as indented XML, `console` `[]`. `Transform` runs once | - |
| Run, document | An HL7 ADT_A01 or an X12 interchange for a copy transformation | `done`, one line per segment as the classic raw view writes it (`MSH\|^~\&\|PROBEAPP\|…`, `ISA*…`). The HL7 and X12 document extents equal their counts before | - |
| Existing target | `create="existing"` | The target starts from `%New()` with no argument | - |
| Device write | The transformation writes a line | The line is in `console`, and the answer stays JSON | - |
| Input does not parse | XML of another root; text that is not XML; EDI text the vendor turns into no document | `input`, `errors` true, the vendor's error text as `lines` (none when it gave only an empty result) | - |
| Transform fails | An error status; a fault that escapes `Transform` | `transform`, `errors` true, the error text | - |
| Output not written | The transformation leaves no target | `output`, `errors` true | - |
| Stored objects | The transformation saves its target; an X12 parse saves the interchange | Deleted before the answer. Extents back to their counts before | A failed delete is logged, never with content |
| Refused format | Source or target a Record Map, a batch, or neither kind | Nothing parsed or run | 409 `INTEROP.TRANSFORM.SOURCEFORMAT` / `TARGETFORMAT` |
| Not listed | Not compiled, not a subclass, a base class, or an id without `.cls` | Nothing runs | 404 `PORT.NOTFOUND` |
| Content | Empty, or over the caller's bound | Nothing runs | Screen: 422 `INTEROP.TRANSFORM.CONTENT` on `content`. Agent, empty or over 30,000: `TOOL.ARGUMENTS` |
| OcuPilot's own name | A transformation whose name begins `OcuPilot` | Nothing runs | `PROHIBITED.OCUPILOTCODE` (the existing `class` arm) |
| Gate | Missing one pair, or READ only on the globals database | Refused before any vendor call | 403 naming the pair |
| Namespace | No interoperability | Refused | 409 `INTEROP.NAMESPACE` |

</intent-contract>

## Code Map

All paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-20`. The line numbers were read at `892c89d0`.

### Port: `src/OcuPilot/Port/InteropPort.cls` (5,600 lines; no `Include`)

- **Header and parameters.**
  - Header: write list 1-6, host-test paragraph 52-60, seam list 61-64.
  - Endpoints: `ENDPOINTS` 74 (pinned at `Test/InteropHostDescriptor.cls`:23, unchanged), `ENDPOINTTRANSFORMS` 80 (`"Transforms"`).
  - Pairs: `CODEPAIRS` 144, `TESTPAIRS` 167. `COMPOSEDTYPES` 172 (read by `Test/Prohibited.cls`:438).
  - Types and keys: `TYPETESTTARGET` 345, `TYPESENDTEST` 348, `CONTENTKEY` 407 (`content`; reuse it), `IDKEY` 536, `ACTIONKEY` 540.
  - Test bounds: `TESTOUTPUTMAX` 371, `TESTCUT` 374, `DOCUMENTBASE` 380.
  - Audit names: `ENTITYITEM` 388, `VERBTEST` 390. There is no `ENTITYCLASS` yet.
- **Dispatch.**
  - `IsTestWrite` 664 (`Quit pType = ..#TYPESENDTEST`). `IsAnyWrite` 670 is the one OR, used by `Invoke` at 845 and `Admit` at 931.
  - `Pairs` 697: `Transforms` gets `CODEPAIRS` by the fall-through at 719-720, and write pairs append at 724-729.
  - `Serves` 737: the `ItemTest` arm is at 748, and 749 answers 0 for any other endpoint, so `Transforms` serves only `LIST` today.
  - `Invoke` 834: `ItemTest` dispatches at 859-862. `LIST` reaches `ListClasses` at 885. Anything else falls to the production-state path at 890-914, so the new dispatch goes before 863.
  - `Admit` 927: globals database READ, or WRITE for any write, at 938-939. The routines database only for item and setting writes (941-944).
- **Siblings to extend.**
  - `ListClasses` 995-1049: the listed predicate, through the `SubclassOf` query and its exclusions at 1007-1008.
  - `InvokeItemTest` 4677: the dispatcher shape.
  - `PerformTest` 5463: read and refuse, then capture (`$$BeginCapture^%SYS.Capture` 5478), switch, vendor calls, restore, end the capture (5493), map the result, `AuditRuntime`.
  - `EndTestCapture` 5382: joins the captured lines into one text with no separator (DW-2345, a third copy, accepted).
  - `AddTestLines` 5405: pure. It splits on CR/LF and caps the total.
- **Helpers.**
  - Refusals: `Violations` 1330, `Statused` 2389, `Mapped` 2416, `LogFault` 2436, `Deny` 2442, `Refuse` 2450, `Conflict` 2459, `Absent` 2472 (404 `PORT.NOTFOUND`), `Fail` 2487.
  - Script form: `AuditRuntime` 3495, `SnippetForm` 3507, `Snippet` 3529, `TestSnippet` 5534, `Literal` 5591.
- **Ens references.** The port reaches Ens classes only by `##class(Ens…)` in method bodies or `$ClassMethod` (for example 968 and 4670). No signature carries an Ens type.
- **Bounds in other classes.** `src/OcuPilot/Port/AtelierPort.cls`:419 `MAXIMPORTCHARACTERS` (3,000,000). `src/OcuPilot/Screen/Tool/ExplorerSave.cls`:54 `CHANGEMAXLENGTH` (30,000).

### Errors: `src/OcuPilot/Api/InteropError.cls` (540 lines, 142 parameters)

- The pattern is `TESTREQUEST` 363 plus `REASONTESTREQUEST` 365.
- `Codes()` 374, `ConsequenceCodes()` 380 (`TESTSENDS` 368), `TestCodes()` 440, `TestPreconditionCodes()` 449, `ReasonFor` 464.
- `Api/Error.cls`:1447 routes every `INTEROP.*` code here. `Error.cls` holds 989 of its 1,000 parameters, so nothing goes there.

### Tools: `src/OcuPilot/Screen/Tool/`

- **`InteropAction.cls`** (140 lines), the parent:
  - Defaults: `READSVALUES` 1, `SENDSBODY` 0, `DATABASEPERMISSION` `WRITE`, `ROUTINESDATABASE` 0, `STATEMARKER` 55.
  - `IdArgument` 62 is `Name`.
  - `PrivilegePairs` 89 builds the screen pairs, then `WRITERESOURCE`, then the globals database, then the classic pages.
  - `PortQuery` 131 sets `ACTIONKEY` when the payload lacks `STATEMARKER`.
- **`InteropItemTestSend.cls`** (280 lines), the sibling whose shape this tool follows:
  - Parameters 22-78. `InputSchema` 97, `StateDiff` 113, `MergeUpdate` 133 (fresh read as payload), `ScreenActionDelta` 145 (screen bound `MAXIMPORTCHARACTERS`), `PortQuery` 181.
  - `ArgumentProblem` 196 reads `ExplorerSave.#CHANGEMAXLENGTH` at 210. `ConfirmProblem` 227. `WriteOutput` 267 never answers `outcome`.
  - It declares no `READBACKFIELDS`, so it reads back `nothingSent` (`Kernel/Proposal/ReadBack.cls`:47).
- **`InteropLookupTableImport.cls`**:38 is the single-name tool with a pasted `content` screen value.
- **`ExplorerSaveMint.Hunk`** 242 builds the card's changed-lines row `{field, kind: "lines", line, before, after}`. The Input row reuses it.
- **`Write.cls`**: `FINGERPRINTSUBJECT` 97 (it must carry `PRECONDITIONFIELD`, and every name must be one `READANSWERS` declares), `PRECONDITIONFIELD` 105, `READANSWERS` 189, `SCREENVALUES` 226, `PRECONDITIONCODES` 508. The guard is `Screen/Registry.cls`:2886.
- **Output path.** `Kernel/Proposal/Operation.cls`:225-230 finds `WriteOutput` by reflection. `Confirm.cls`:520-521 and `Api/ScreenAction.cls`:418-419 answer `output`. The prohibited set is evaluated at `ScreenAction.cls`:370 and `Confirm.cls`:299.

### Descriptor, governance, prohibited set

- **`src/OcuPilot/Screen/Descriptor/InteropTransformList.cls`** (66 lines):
  - Its doc comment says "declares no action" (7-9).
  - Route `interoperability/transforms` (20), privileges `CODEPAIRS` (28), entity `class` (30), `rowActions` `[]` (36), three prompts (40-44).
  - `emptyNextKey` `tableReadOnlyEmptyNext` (59), `emptyAgentKey` `""` (60), `toolIdentifier` `interop.transforms` (62).
  - Target shape: `InteropQueueList.cls`:29 and :54-55.
- **`src/OcuPilot/Kernel/Governance/Baseline.cls`**:241 holds `"interop.itemtest.send": true`, the last key. Append after it, adding a comma to 241.
- **`src/OcuPilot/Kernel/Proposal/Prohibited.cls`** (read only):
  - The `class` arm (1421-1431) calls `Code` (2551), and `IsOcuPilotCode` (2718) refuses a name beginning with the `ocupilot` stem, in any case. No field sweep runs for `class`.
  - So a probe named `OcuPilotProbe.*` is refused. The fixture uses `OcuProbeDtl` (the Explorer tests' `OcuProbe192` precedent).

### Fixtures and tests (Story 20.6's, to extend or call)

- **`src/OcuPilot/Test/InteropTestFixture.cls`** (357 lines, no DTL):
  - Package `OcuPilotProbe.Interop`.
  - `Create` 136 shows the class-creation idiom: `%Compiler.UDL.TextServices.SetTextFromString` at 142, then `CompilePackage("ck-d")` at 149.
  - `ProductionProbe.Remove` (635) deletes only the `OcuPilotProbe*` packages (651-652).
- **`src/OcuPilot/Test/InteropItemSeam.cls`** (180 lines) extends the port. It overrides `LogFault` (169) and adds `Logged` (175).
- **`src/OcuPilot/Test/InteropItemControl.cls`**: `Call` 99 (`POST /screens/<tool>/action`), `MintAs` 269, `ConfirmHttp` 293, `LedgerCount` 304.
- **`src/OcuPilot/Test/AuditEvent.cls`**: `Now` 165 and `RowsCarrying` 127.
- **`InteropHostTest.cls`** (520 lines): the agent leg at 333 reads back the stored proposal, steps and turn after the confirm.
- **`InteropTestDescriptor.cls`** (269 lines): the tab and tool declarations at 58-121, the codes at 152, the script at 181, the bounds at 218, outcome at 257. It has room for the Part B legs.
- **`InteropTestGate.cls`** (394 lines) does not fit the new legs:
  - Its parameters are item-specific: `PRINCIPALS` 42, `LEGS` 45, `EXPECTED` 50.
  - `ProbeAs` 272 (a JOB, then `WaitMsg`), `Probe` 300 (logs in, runs the legs), `EnsurePrincipals` 357 (an instance method).
  - `InteropItemGate`'s `FailedPair` (309), `LegText` (367) and `FaultText` are class methods.

### Rosters a new write tool on this existing screen moves

| File:line | Now | Change |
|---|---|---|
| `src/OcuPilot/Test/SurfaceCoverage.cls`:413 | 222 `<tool>` rows | + `interop.transforms.test` |
| `src/OcuPilot/Test/ReadTool.cls`:93-94 | 374 names, sorted | 375, inserted after `interop.transforms.read` |
| `src/OcuPilot/Test/ToolWrite.cls`:1338 | `tOtherPorts` 45 ("forty-five") | 46 |
| `src/OcuPilot/Test/ToolRoundTrip.cls`:92 | `REFUSEEMPTY` | + `interop.transforms.test:TOOL.ARGUMENTS` |
| `src/OcuPilot/Test/ToolEmit.cls`:226, :258, :268 | 20.6's tool has its own branch (226). The lookup branch (258) keys on the `InteropLookup` descriptor prefix. The generic branch (268) lacks the globals-database pair | the new tool gets a branch like 226's, expecting the screen pairs, `%Ens_DTLTest:USE`, the globals database's WRITE and the classic page |
| `src/OcuPilot/Test/ClassicPageGate.cls`:75, :160 | 82 `OWNPAIRS` ("eighty-two") | + `interop.transforms.test=%Ens_DTLTest:USE\|%DB_HSCUSTOM:WRITE`; 83 |
| `src/OcuPilot/Test/MappingDescriptor.cls`:24, :119 | `CLASSICROSTER`, sorted ("eighty-one") | + `interop.transforms.test=EnsPortal.Dialog.TestTransform`; 82 |
| `src/OcuPilot/Test/InteropDescriptor.cls`:163-165 | Transforms shares `"class\|\|tableReadOnlyEmptyNext"` with Processes and Rules | Transforms gets its own branch (`test`, `interopTransformsEmptyAgent`) |
| `src/OcuPilot/Test/Prohibited.cls`:438, :456 | composed check; settable `$Case` defaults to 1 | none: one settable field (`content`), and `COMPOSEDTYPES` gains the type |

**Unchanged, checked:**

- `StageTwoTools`' `Elsewhere` block (114) lists screens. `InteropTransformList` is already at :187, and no screen is added. Its `TestEachDeclaredActionResolvesToExactlyOneWriteTool` (304) binds `test` to the new tool.
- `InteropFloor` (no principal holds a write tool, 378-381; the globals WRITE keeps it so), `InteropFloorOwnPairs`, `EndpointCoverage`, `SaveHoldCoverage`, `Navigation`, `Descriptor`'s read shapes, `GovernanceBaseline` (no count pin), `EntityType`.
- **Arming:** `scripts/ci-throwaway.sh`'s interop block is 428-484, with 20.6's `# classes:` lines at 475 and 479. `ui/tools/ci.test.mjs` derives its rosters from them (2285, 2348).

### Client: `ui/src/app/`

- **`shell/screen-outlet.ts`** (425 lines): `DESCRIPTOR_PAGES` 79-210, interop rows 202-209. Data transformations has no entry, so it renders through `ARCHETYPE_PAGES.list` (51).
- **Interoperability pages** (`areas/interoperability/`):
  - `interop-item-test.page.ts` (163): registers `test` at 90, `onOpen` 117-128, `onSend` 141-162.
  - `interop-item-test-dialog.ts` (366): textarea 145-157, banner 99-101, result 183-190, steps 331-333.
  - `interop-item-setting-list.page.ts` (165): `register` 103, `onOpen` from `store.selection()[0]` (112-130), stale-answer guard 155. This is the closest list-row sibling.
  - `interop-lookup-table-list.page.ts` (351) hosts `<app-list-page />` and its dialogs (110-142, `nameOf` 344-350).
- **`core/test-answer.ts`** (73): `testAnswerOf` 35-48 requires a string `sessionId`, so it never reads a transformation answer. Also `testStatusLine` 51 and `testOutcomeLines` 69. Its test is `ui/tools/test-answer.test.mjs` (55).
- **`core/turn.ts`**: `outputLinesOf` 500-506 (the test branch at 503). `outputErrorsOf` 512-516 answers a boolean for any `lines` plus `errors` output. Its test is `ui/tools/turn.test.mjs`.
- **`shell/proposal-card.ts`**:
  - `summaryOutcomeVisible` and `summaryOutcome` (796-804) then read a confirmed host test's card as "Compiled" or "compile errors" whenever the card's summary line shows (`summaryVisible` 745-754).
  - The output block is at 375-378. Changed-lines rows are at 150-186. `core/long-blocks.ts`:8 sets the eight-line collapse.
- **`core/proposal-view.ts`**: `consequenceSentence` 433, with `INTEROP.TEST.SENDS` at 386 and 537.
- **`shell/screen-action-handler.ts`** (1603): `SCREEN_ACTION_DESCRIPTORS` 67-146 (20.6 at 144-145), `UNDRAWN_ACTIONS` 388-423 (421-422), `sendFor` 1471, `lastOutput` 1488, `lastRefusal` 1505.
- **`core/screen-actions.ts`**:166 `DESCRIPTOR_ACTION_LABELS`. Row menus show a registered action (`shell/data-table.ts`:905).
- **`core/strings.ts`**:
  - Reuse `serverFlagTest` 'Test' (1285, as 20.6's tab label does), `actionRun` 'Run' (115) and `actionCancel`.
  - Existing transforms keys are at 6418-6452, and 20.6's keys at 7016-7068.
  - Every value must be unique and published (`ui/tools/strings.test.mjs`:611 bounds the table at 3,400, raised within 50 of it; :796-801 checks uniqueness).
- **Pins in `ui/tools/`**:
  - `interop.test.mjs` `SENTENCES` 31-103 pins each server sentence to its key and to EXPERIENCE.md.
  - `screen-mirror.mjs`:3087-3104 requires a write-capable table to have `emptyNextKey` `''` and its own `emptyAgentKey`.
  - `build-output.test.mjs`: `LAZYCHUNKMAX` 88,000 bytes (267); every `*.page.ts` selector must sit in a lazy chunk (318-345).
  - `angular.json` has `maximumWarning` 1992kB (54).

### Browser and UX

- `ui/browser/interop-item-test.browser-spec.mjs` (255):
  - `before` and `after` through `runIris` (`turnprobe-spec.mjs`:53) at 153-175, on a `-ci` container only.
  - The DW-1337 walk `structural(page, route)` at 66-88 runs at 1280 light, 720 light and 1280 dark. The same local helper appears in about 20 specs.
  - The text-only assertion is at 194-212.
- `ui/browser/interop-lookup-transfer.browser-spec.mjs` and `interop-queue-job-actions.browser-spec.mjs` run a list row action that opens a dialog.
- Helpers: `list-spec.mjs` (`ROW_SELECTOR`, `clickRowCentre`, `waitForRows`), `namespace-features.mjs`:62 (`waitForMapAnswered`), `panel-spec.mjs`:64 (`signedInAt`).
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`:
  - :159 is the Interoperability sentence. It ends with the item tab order and 20.6's Test-tab clause.
  - :173 is the dialog list, with 20.6's "send a test request …" entry.
  - :604 is the last Fixed-strings row, ending with 20.6's and 20.13's clauses. Insert no line above it.

### Vendor (read only)

- **`irislib/EnsPortal/Dialog/TestTransform.cls`**:
  - `existing` target 449-458. `process`/`context` 466-467. The call at 502.
  - Render 505-569: EDI XML 510; segmented raw view 520-533; non-segmented 525; `%XML.Adaptor` 557-564; "neither" 567.
  - Deferred cleanup 571-599 (`EnsPortal/SessionEvents.cls`:120-136).
- **The hidden `Ens.Util.Serialized.Reader`** (read from the instance at this plan):
  - `ObjectFromSerialized` sends an `EnsLib.EDI.Document` class to `ImportFromString(pData, .tSC)`, with the status second for every family, then sets `IsMutable` 0.
  - It sends an `%XML.Adaptor` class to `Ens.Util.XML.Reader.ObjectFromString` once the first non-blank character is `<`. A failed XML parse falls back to the Record Map and batch parsers.
- **`irislib/Ens/DataTransform.cls`**: every subclass answers `GetSourceType`, `GetTargetType(.create)`, `GetSourceDocType` and `GetTargetDocType`. A non-DTL class takes them from its `Transform` formal spec, with `create` `""` (treat it as `new`).

## Tasks & Acceptance

**Execution:**

- [x] **Task 0**, on `ocupilot-b-ci` only through `docker exec`. Remove what you create, then record each result as a `Task 0:` line under Verification.
  - (a) Through the screen route, the `write` leg's answer is a JSON envelope whose `console` holds the line.
  - (b) An `EnsLib.EDI.XML.Document` source parses through its `ImportFromString`, and an EDI XML target renders through `OutputToLibraryStream(stream, "wt")`. Use a throwaway DTL in `OcuProbeDtl`, then delete it.
  - (c) The X12 interchange the fixture uses parses, and its source and target `%Delete` leave the `EnsLib_EDI_X12.Document` count at its count before.
- [x] `src/OcuPilot/Api/InteropError.cls` (extend). Add `TransformCodes()` and `TransformPreconditionCodes()`, join them into `Codes()` and `ReasonFor`, and add the consequence to `ConsequenceCodes()`. The sentences:
  - `INTEROP.TRANSFORM.SOURCEFORMAT`: "OcuPilot reads a pasted source only as an HL7 or other EDI document's text, or as XML. This transformation's source is neither, so test it in the classic portal."
  - `INTEROP.TRANSFORM.TARGETFORMAT`: "OcuPilot shows a target only as an EDI document's text or as XML. This transformation's target is neither, so test it in the classic portal."
  - `INTEROP.TRANSFORM.CONTENT` (violation): "Paste the source message, at most 3,000,000 characters."
  - Consequence `INTEROP.TRANSFORM.RUNS`: "The transformation's code runs on this instance as you, on the input shown. Whatever it writes or sends, it writes or sends."
- [x] `src/OcuPilot/Port/InteropPort.cls` (extend), per Boundaries:
  - **Types and pair.**
    - `TYPETRANSFORM` `TRANSFORM` (read, composed) and `TYPETRANSFORMTEST` `TRANSFORMTEST` (write).
    - `DTLTESTPAIR` `%Ens_DTLTest:USE`, appended in `Pairs` for both types.
    - `IsTestWrite` gains `TRANSFORMTEST`. `COMPOSEDTYPES` gains `Transforms/TRANSFORMTEST`.
    - `Serves` gains a `Transforms` arm before 749, and `Invoke` an `InvokeTransformTest` dispatch before 863.
    - `ENTITYCLASS` `class`.
  - **`TRANSFORM`** (`ReadTransform`). It answers `{Namespace, Name, SourceClass, SourceDocType, SourceKind, TargetClass, TargetDocType, TargetKind, Create, content}`, with kinds `document | xml | recordmap | other`, through the four `Get…` calls and `%Extends`, made while switched. It writes nothing and calls no `Transform`.
    - A class that is not listed or not compiled is 404.
    - With `ACTIONKEY`, it then refuses in order: `SOURCEFORMAT`, `TARGETFORMAT`, then 422 `CONTENT`.
  - **`TRANSFORMTEST`** (`PerformTransformTest`, after `PerformTest`'s order). Re-run the composed read and its refusals. Then, under the capture and switched, parse, target, run, render and clean up through the port's own `...Here` methods. Then restore and compose the answer. Then `AuditRuntime(VERBTEST, ENTITYCLASS, Name, effects)`.
  - **Capture lines.** `EndTestCapture` gains an optional `Output` `%DynamicArray` of the captured lines. Its text answer is unchanged for `PerformTest`.
  - **Snippet.** `SnippetForm` and `Snippet` route `Transforms/TRANSFORMTEST` to a new `TransformSnippet`. It writes the namespace switch, the parse with `Literal(content)`, the target for `existing`, the `Transform` call and the render, each value a literal (AD-59).
  - **Header.** The header's write list gains the transformation test.
- [x] `src/OcuPilot/Screen/Tool/InteropTransformTest.cls` (new), `interop.transforms.test`, extends `InteropAction`.
  - **Declarations:**
    - `DESCRIPTORCLASS` `InteropTransformList`, `READTYPE` `TRANSFORM`, `WRITETYPE` `TRANSFORMTEST`.
    - `SCREENACTIONS` `test`, `SCREENVALUES` `test=content`.
    - `WRITERESOURCE` `%Ens_DTLTest`, `WRITEPERMISSION` `USE` (the database permission stays `WRITE`).
    - `STATEMARKER` and `PRECONDITIONFIELD` `SourceClass`, `READANSWERS` as the read answers.
    - `FINGERPRINTSUBJECT` `Namespace,Name,SourceClass,SourceDocType,SourceKind,TargetClass,TargetDocType,TargetKind,Create,content`.
    - `PRECONDITIONCODES` the two formats plus `INTEROP.NAMESPACE`, `CONSEQUENCECODE` `INTEROP.TRANSFORM.RUNS`, `DESTRUCTIVE` 0, `CLASSICPAGES` `EnsPortal.Dialog.TestTransform`.
  - **Description.** `DESCRIPTION` and `NameDescription` say the output is shown to the person only and is not returned to the agent.
  - **Arguments.**
    - `InputSchema` adds a required `content` (`maxLength` `CHANGEMAXLENGTH`, naming the formats).
    - `ArgumentProblem` and `ConfirmProblem` accept 1 to `CHANGEMAXLENGTH` characters.
    - `ScreenActionDelta` requires `content` to be a string and leaves its length to the port's 422 `CONTENT`, so the dialog shows the refusal on Input.
    - `PortQuery` adds `CONTENTKEY`. `MergeUpdate` follows the sibling. `SettableFields` is `content`.
  - **`StateDiff`.** The rows are `Transform` (Name), `Source` and `Target` (class, then doc type in parentheses when set), and `Input`, which is `ExplorerSaveMint.Hunk("", content)` with the field renamed and CR line ends normalized.
  - **`WriteOutput`.** It answers `{status, sourceClass, targetClass, lines, console, errors}` and never `outcome`.
- [x] `src/OcuPilot/Screen/Descriptor/InteropTransformList.cls` (in place, Epic 20's own):
  - `rowActions` `[{"id":"test","selfProtection":""}]`.
  - `emptyNextKey` `""` and `emptyAgentKey` `interopTransformsEmptyAgent`.
  - Reword the doc comment at 7-9. The prompts, read and pairs are unchanged.
- [x] `src/OcuPilot/Kernel/Governance/Baseline.cls` (append): `"interop.transforms.test": true`.
- [x] `src/OcuPilot/Test/InteropTransformFixture.cls` (new, not a `TestCase`). It creates in `USER`, with `InteropTestFixture.Create`'s idiom, the package `OcuProbeDtl` and nothing named `OcuPilot…` except `OcuPilotProbe.OwnDtl`:
  - `Xml`: `Ens.StringRequest` to `Ens.StringResponse`, `out:<value>`, with a `<code>` that increments `^OcuProbeDtlRuns`. Per value:
    - `fail` sets `tSC` to an error (the DTL's status variable, measured);
    - `write` writes `probe-device-line`;
    - `save` saves the target;
    - `none` sets `target` to `""`.
  - `Existing`: `create="existing"`, appending to the target's value.
  - `Hl7`: `2.5:ADT_A01` copy, setting `{MSH:SendingApplication}` to `PROBEAPP`.
  - `X12`: a copy.
  - `Raw`: an `Ens.DataTransform` whose own `Transform` raises `<DIVIDE>`.
  - `Batch`: source `EnsLib.RecordMap.SimpleBatch`. `FromStream` and `ToStream`: `%Stream.GlobalCharacter` as the source, and as the target.
  - `OcuPilotProbe.OwnDtl`: a copy of `Xml`, used for the prohibited leg.
  - Entry points:
    - `Create` and `Remove`. `Remove` deletes the classes and `^OcuProbeDtlRuns`, and verifies they are gone.
    - `Runs()`.
    - `Counts()`: the `Ens.StringRequest`, `Ens.StringResponse`, `EnsLib_HL7.Message` and `EnsLib_EDI_X12.Document` extents.
    - The sample texts (XML, an ADT_A01, an X12 interchange).
- [x] Tests (new, armed, each under about 500 lines, one class per run):
  - **`src/OcuPilot/Test/InteropTransformTest.cls`** (AC1-AC3, AC6, AC7). For each leg, the person's screen route and the agent's mint and confirm over HTTP (`InteropItemControl`):
    - the XML, HL7, X12 and `existing` runs, with lines, classes and `Runs()` +1 per action;
    - the minted proposal's rows (with `Input`) and consequence code;
    - the `ConfigChange` row with no content;
    - `Counts()` unchanged;
    - after the confirm, the stored proposal, steps and turn hold no output line, with the input as the liveness control;
    - the change event;
    - a `TRANSFORM` read leaves `Runs()` and `Counts()` unchanged.
  - **`src/OcuPilot/Test/InteropTransformTestRefusals.cls`** (AC4, AC5):
    - the `input` (two XML shapes, HL7 text with no `MSH`), `fail`, `Raw`, `none`, `write` and `save` legs;
    - at the port through `InteropItemSeam`, `Logged()` holds no error or console line;
    - every refusal of the matrix from both callers where both reach it, each leaving `Runs()` and `Counts()` unchanged;
    - the agent's content over 30,000 is `TOOL.ARGUMENTS`.
  - **`src/OcuPilot/Test/InteropTransformTestGate.cls`** (AC8), `OcuP2027*` principals:
    - Exactly `%Ens_Portal:U`, `%Ens_Code:R`, `%Ens_DTLTest:U` and `%DB_USER:RW` lists, reads and runs.
    - Each missing pair, or READ only on the globals database, is refused by name through the port, on the tool's pairs and on the screen route, with `Runs()` unchanged.
    - Without `%Ens_DTLTest` it still lists.
    - It reuses `InteropItemGate`'s `FailedPair`, `LegText` and `FaultText`. Its `Probe` and `EnsurePrincipals` follow `InteropTestGate`'s (Design Notes › Rule 31).
  - **`src/OcuPilot/Test/InteropTestDescriptor.cls`** (extend): the tool's declarations, `Pairs`, `Serves`, `COMPOSEDTYPES`, the key `true`, the codes resolving, `TransformSnippet` keeping a quote and a CR inside literals, and `WriteOutput` never answering `outcome`.
- [x] Roster sweep (Rule 30): every row of the roster table, plus anything a search of `src/OcuPilot/Test`, `ui/tools`, `ui/browser` and the `ui/src` specs finds asserting the transforms list's no-action shape. Each changed file joins the `(loop)` set.
- [x] `scripts/ci-throwaway.sh`: a `# classes:` line in the interop block after 479 naming the three new armed classes.
- [x] Client (every path below is under `ui/src/app/` unless it starts with `ui/`):
  - **`core/test-answer.ts`** (extend):
    - `transformAnswerOf`, which reads only a status of the four with a string `sourceClass` and arrays `lines` and `console`;
    - `transformStatusLine`;
    - `transformOutcomeLines`: the status sentence, then the lines, then, when non-empty, the console label and the console lines.
  - **`core/turn.ts`** (add-only):
    - `outputLinesOf` gains the transformation branch after the host-test one.
    - `outputErrorsOf` answers `null` for a host or transformation test answer, so a test card never reads as a compile.
  - **`core/proposal-view.ts`**: `INTEROP.TRANSFORM.RUNS` maps to its sentence.
  - **Maps.**
    - `core/screen-actions.ts`: `{ test: STRINGS.serverFlagTest }`.
    - `shell/screen-action-handler.ts` (add-only): the descriptor in `SCREEN_ACTION_DESCRIPTORS`, and `['test']` in `UNDRAWN_ACTIONS`.
  - **`areas/interoperability/interop-transform-list.page.ts`** (new, `app-interop-transform-list-page`):
    - It hosts `<app-list-page />` and the dialog, and registers `test`.
    - It opens on the selected row (the setting-list sibling's `onOpen`).
    - It sends `sendFor(…, 'test', id, {content}, {setRefusal: () => undefined})`, ignores a stale answer, and reads `transformAnswerOf(lastOutput())`.
    - A violation on `content` shows on Input; any other reason shows in the banner.
  - **`areas/interoperability/interop-transform-test-dialog.ts`** (new):
    - The title, the RUNS sentence, Input (a textarea with the formats sentence), and Run, `aria-disabled` while sending.
    - The result: the source and target class, the status sentence (the error style when `errors`), and the lines and the console, each through `app-code-block`, as text.
  - **`shell/screen-outlet.ts`**: one `DESCRIPTOR_PAGES` loader line after 209.
  - **Strings and mirror.** `strings.ts` (add-only) for the literals of Design Notes › Fixed strings, then the regenerated `screens.generated.ts`.
  - **Specs.**
    - `ui/tools/test-answer.test.mjs`, `ui/tools/turn.test.mjs`, and `ui/tools/interop.test.mjs` (`SENTENCES` + 4).
    - `areas/interoperability/interop-transform-list.page.spec.ts` and `areas/interoperability/interop-transform-test-dialog.spec.ts`: the page registers `test`, opens on the selection, sends `content`, ignores a stale answer, and draws the answer and a refusal; the dialog's lines are text.
    - `shell/proposal-card.spec.ts`: the RUNS sentence, and a confirmed test card whose summary line shows no compile outcome.
- [x] `ui/browser/interop-transform-test.browser-spec.mjs` (new; `before`/`after` create and remove the fixture through `runIris`). After `waitForMapAnswered`:
  1. Data transformations (`?ns=USER`) lists `OcuProbeDtl.Xml.cls`. Its row's Test opens the dialog.
  2. Pasted XML runs and shows the done sentence and `out:x`. The `fail` value shows the failure sentence and `probe-fail`.
  3. Pasting `<b>x</b>` shows the input sentence with the text literal, and no `b` element is made.
  4. With the dialog open and answered, the DW-1337 walk (the local `structural` helper) finds no entry beyond the baseline.
- [x] `EXPERIENCE.md` (no line inserted above :604):
  - :159 gains "; a Data transformations row's Test runs the transformation once on a pasted message (Story 20.27)".
  - :604 gains a Story 20.27 clause naming every new literal.
  - The :173 dialog entry is the spec gate's (Design Notes › For the spec gate).
  - Then run `cd ui && npm run test:tools`.

**Acceptance Criteria:**

- **AC1 (run, both callers, integration):** Given `OcuProbeDtl.Xml` in `USER` on `ocupilot-b-ci` and pasted XML, when a person runs Test from Data transformations, and when the agent proposes `interop.transforms.test` and the person confirms, then:
  - each action runs `Transform` once;
  - the screen answer and the confirm answer are JSON envelopes whose `output` is `done` with `sourceClass`, `targetClass` and the target as indented XML holding `out:x`;
  - a `ConfigChange` row records the test with no content.
- **AC2 (documents and cleanup):** Given HL7 ADT_A01 text for `OcuProbeDtl.Hl7`, an X12 interchange for `OcuProbeDtl.X12`, and the `save` value, when each is tested, then:
  - the lines are the target's raw text one segment per line (`MSH|^~\&|PROBEAPP|`, `ISA*`);
  - the HL7, X12 and `Ens.StringResponse` extents equal their counts before.
- **AC3 (the card before Confirm):** Given the agent's proposal, when it is minted and its card renders, then:
  - it shows Transform, Source, Target and the Input as a changed-lines block, and the consequence sentence;
  - the governance key reads `true`.
- **AC4 (outcomes):** Given input that does not parse, a failing transformation, one whose fault escapes `Transform`, one that leaves no target, and one that writes to the device, when each is tested, then:
  - the answer is 200 with status `input`, `transform` or `output` and `errors` true, or `done` with the line in `console`;
  - no error or console line reaches the log.
- **AC5 (refusals):** Given each refusal row of the matrix, when either caller attempts it, then it is refused by its code before any parse or `Transform` (`Runs()` and `Counts()` unchanged).
- **AC6 (screen data only):** Given a confirmed test, when its stored proposal, steps, turn, ledger row and audit row are read, and when the dialog shows a line that holds markup, then:
  - none of them holds an output or console line;
  - the line is drawn as text, with no element made of it.
- **AC7 (reads change nothing):** Given the `TRANSFORM` read with and without `ACTIONKEY`, when it runs, then `Runs()` and every extent of `Counts()` are unchanged.
- **AC8 (gates):** Given a principal missing one declared pair, or holding READ only on the globals database, when it reads or runs, then it is refused naming that pair before any vendor call. A principal holding exactly the pairs runs the test.
- **AC9 (the screen):** Given Data transformations in `USER`, when a person selects the probe row and runs Test, then the dialog shows the result, and the screen and dialog pass the DW-1337 walk in both themes.

### Review Findings

Code review 2026-10-13 (four layers, full-opus; 34 rows, 20 entries). Each entry: severity, fix-risk, disposition.

- [x] [Review][Patch] HIGH, AD-21: pasted XML named a file the parser opened. An EDI XML message's `<!DOCTYPE … SYSTEM "file:…">` was read, and an entity it declared inlined a server file into the shown target (measured); the XML reader opened DTD and `xsi:noNamespaceSchemaLocation` files. Story 20.6's send had the same path. Fix-risk low. Fixed: `PastedXmlHere` (refuses a document type, reads from the first `<`), `%XML.SAX.NullEntityResolver` for the XML reader, used by `ParseSourceHere` and `BuildTestRequestHere` [src/OcuPilot/Port/InteropPort.cls]
- [x] [Review][Patch] HIGH, AD-59: `TransformSnippet` did not mirror the run (EDI XML text as pasted, no `%Delete`, unset `process`/`context`). Fix-risk low. Fixed, with `TestSnippet`'s EDI XML twin [src/OcuPilot/Port/InteropPort.cls]
- [x] [Review][Patch] MED: `$ZStrip(…,"<W")` kept a leading CR/LF and the XML reader got the unstripped text, so XML pasted after a line end, or a declaration after one, was refused. Fix-risk low. Fixed in `PastedXmlHere` [src/OcuPilot/Port/InteropPort.cls]
- [x] [Review][Patch] MED: `AddTestLines` split with an indexed `$Piece` per line, which is quadratic (160,000 lines took 16.4 s, QA). Fix-risk low. Fixed with a linear `$Find` walk [src/OcuPilot/Port/InteropPort.cls]
- [x] [Review][Patch] MED, Rule 19: the refusal legs' `Runs()` checks could not fail, because only the XML probe counted runs. Fix-risk low. Every probe transformation now counts [src/OcuPilot/Test/InteropTransformFixture.cls]
- [x] [Review][Patch] MED, Rule 19: two audit counts relied on an earlier test's row falling outside the time window. Fix-risk low. Both are now before/after deltas [src/OcuPilot/Test/InteropTransformTest.cls, InteropTransformTestRefusals.cls]
- [x] [Review][Patch] MED: the run's end was not announced (WCAG 4.1.3). Fix-risk low. The dialog keeps a mounted `role="status"` region. Story 20.6's dialog has the same gap: DW-2379, routed to burndown [ui/src/app/areas/interoperability/interop-transform-test-dialog.ts]
- [x] [Review][Defer] MED: HL7 `ImportFromString` translates already-decoded text again, so U+0151 reads `?` (measured). The classic dialog hands HL7 a stream. Spec-bound, because AD-62 item 11 names `ImportFromString`: DW-2378, decision-pending, owner burndown
- [x] [Review][Patch] LOW: `Transform` called without `aux`, which the classic dialog passes empty. Fixed [src/OcuPilot/Port/InteropPort.cls]
- [x] [Review][Patch] LOW: the shared `TESTOUTPUTMAX` bound across lines and console was untested. Added `TestTheConsoleSharesTheOutputBoundWithTheTarget` and the `noisy` value [src/OcuPilot/Test/InteropTransformTestRefusals.cls]
- [x] [Review][Patch] LOW: the Task's agent legs for HL7 and X12 were missing. Added [src/OcuPilot/Test/InteropTransformTest.cls]
- [x] [Review][Patch] LOW: four small fixes. `ReadTool`'s count message is corrected. The vacuous summary assertion is dropped from `panel.spec.ts`. The gate test's wrong mutation claim is corrected and the mutation was run. `InteropTestDescriptor`'s failed setup now removes its fixtures [src/OcuPilot/Test/ReadTool.cls, ui/src/app/shell/panel.spec.ts, src/OcuPilot/Test/InteropTransformTestGate.cls, src/OcuPilot/Test/InteropTestDescriptor.cls]
- [x] [Review][Patch] LOW: the port header said every object that gained an `%Id()` is deleted, but the run deletes the source and target. The header is corrected. AD-62 item 11 carries the same claim, which is the lead's to correct (Rule 20) [src/OcuPilot/Port/InteropPort.cls]
- [x] [Review][Defer] LOW, Rule 2: `InteropTransformMint` is a third copy of the ArgumentProblem-first preamble: DW-2380, wontfix-accepted
- [x] [Review][Defer] LOW, Rule 2: the gate class copies `ExpectedFor`, `ProbeAs` and the removal loop: DW-2381, wontfix-accepted
- [x] [Review][Defer] LOW: 20.6's send guard is pinned only through its script form: DW-2382, wontfix-accepted
- [x] [Review][Defer] LOW: a near-bound message whose JSON escaping passes the string limit answers 500 on the screen route: DW-1949, occurrence

Rejected:

- By design: the test publishes `updated`. The spec's AC1 test list names the change event, as 20.6 does.
- By design: no time bound. AD-7 names the transformation's own code as unbounded.
- By design: `turn.ts` keeps two import lines from `test-answer.ts`, because its edits are add-only (Contended files).
- Rejected LOW: a transformation returning its stored source as target makes a second `%Delete` fail and log a line. This is unlikely, and the fix adds a guard.
- Rejected as theoretical: an unbalanced `TSTART` in a transformation's own code.
- Rejected: two spec-text findings. The Auto Run Result's stale risk line, and the Parse bullet that does not name the stricter XML rule, are the lead's to amend.

### Fresh check red (2026-10-13) - rework iteration 1

- [ ] [Smoke] **DW-2383: the item Messages read fails for a principal without SQL privilege on a cold cached query.** On a freshly built `ocupilot-b-ci` the full sweep (625 classes) had one red class, `InteropHostGate` (3 of 3; Story 20.4's): every `ItemMessages` leg answered `INTERNAL`, logged as `ERROR #5540: SQLCODE: -99 Message: User OcuP204Ex7 is not privileged for the operation` (`interopport`, "the item's messages failed"). Alone, after other classes had run the read as a privileged user, it was green; after `$SYSTEM.SQL.Purge()` in `USER` it was red again (reproduced). The Log read (`LOGSQL`, one table) is not affected; `MESSAGESQL`'s `IN (... UNION ...)` subquery under `%ExecDirectNoPriv` is the suspect (inference). Fix it in the product (`InteropPort`), so the first read after a start or a purge, by a principal holding only the endpoint's pairs, answers its rows; keep the rows, order and cap the Messages tab shows today. Check every other `%ExecDirectNoPriv` statement in `InteropPort` for the same shape and fix any that share it. Pin it with a test that removes the statement's cached query (or purges `USER`'s) before an unprivileged read, red on the old statement. `InteropHostGate`, `InteropHostRead` and the classes that read item messages must stay green.

## Spec Change Log

- 2026-10-13, spec gate (runner): the Design Notes' Rule 20 drafts are written: AD-62 item 11's transformation half, AD-7's three Story 20.27 named limits, and the EXPERIENCE.md :173 dialog entry.
- 2026-10-13, code review (runner): the Parse bullet's XML rule is stricter than planned (AD-21, review HIGH): pasted XML is read from its first `<`, a declared document type is refused, and no entity or schema is resolved (`InteropPort.PastedXmlHere`, shared with Story 20.6's send). AD-62 item 11 records it; the run deletes the source and target it stored. EXPERIENCE.md's polite `role="status"` list names both test results.

## Review Triage Log

### 2026-10-13 -- Review pass

- verdicts: 22 findings -- high 0, medium 3, low 10, false 9, maybe-false 0
- findings:
  - `[medium]` `[patch]` Verification gap: the output bound and the cut marker are untested for the transformation test -- probing showed a target past the bound was cut silently, because line ends are not in the line total `AddTestLines` keeps, so the `MAX + 1` read never tripped it. `RenderTargetHere` now appends `TESTCUT` when the stream is not at its end; `TestATargetPastTheBoundIsCutAndMarked` added, mutation recorded.
  - `[low]` `[reject]` The failed-delete path (logged without content, answer unchanged) has no test -- it needs a persistent probe target whose `%Delete` fails and an extent cleanup, past the 15-line bar; the log call passes a fixed message and the vendor's status, and the delete status never reaches the answer. `reopen_if`: a probe target's delete is seen to fail on an instance.
  - `[medium]` `[patch]` The four Record Map bases and the refusal order are unpinned (only `Batch` was) -- probe record classes for `Base`, `ComplexBase` and `ComplexParent` (with the XML adaptor, as a generated record has), a stream on both sides, and `TestAFormatIsRefusedBeforeTheMessageIsJudged` added; mutations recorded.
  - `[medium]` `[patch]` A listed but never compiled class answering 404 is untested (the matrix's "not compiled") -- `OcuProbeDtl.Uncompiled` is stored and left uncompiled; both callers' rows added; mutation recorded.
  - `[low]` `[patch]` The new 501 arms (`InvokeTransformTest`, and `InvokeItemTest`'s narrowed guard) are untested -- two port-direct legs added in `TestAnUnlistedReadIsAbsentAndAForeignActionKeyIsNotImplemented`; mutations recorded.
  - `[low]` `[patch]` `ConfirmProblem` and `ScreenActionDelta` have no direct test -- `InteropTestDescriptor.TestTheTransformToolsConfirmAndScreenHooksJudgeTheMessage` added; mutations recorded.
  - `[low]` `[reject]` The EDIFACT terminator branch of `SeparatorsHere` is unpinned -- it mirrors the classic dialog's lines 527-532 and needs an EDIFACT probe document; no `HSCUSTOM` transformation was found to need it. `reopen_if`: an EDIFACT target's raw view loses its terminators.
  - `[low]` `[patch]` Unrecorded mutations -- the `save` leg and the READ-only clause of AC8 each named a mutation never observed; both were run and recorded. The AC3 key, AC5 prohibited and not-listed legs and AC6 absence legs sit under ACs that already have recorded mutations, and Rule 19 asks one per AC.
  - `[low]` `[patch]` `Counts()` equality could compare two unreadable extents -- `TestTheExtentsTheLegsCompareAreReadable` asserts all four read a count; mutation recorded.
  - `[low]` `[patch]` The card-summary pin sits on `outputErrorsOf`, which the panel does not feed to a non-explorer card (`ui/src/app/shell/panel.ts:1161` passes `null`), and the spec's comment said it does -- the comment is corrected. The Design Notes' premise that the 20.6 card read "Compiled" is the origin, and fixing it means editing the spec, which this pass does not do.
  - `[low]` `[patch]` The browser spec's mutation comment names `PerformTransformTest` for calling `Transform` twice -- it is called in `RunTransformHere`; comment corrected.
  - `[false]` `[reject]` `outputErrorsOf` changes the 20.6 host-test card behavior and drops two old assertions -- the change is specified (Tasks, Client, `turn.ts`), and `panel.ts:1161` already nulls `outputErrors` for every non-explorer tool, so no shipped card changes.
  - `[false]` `[reject]` Descriptor `emptyNextKey` and `emptyAgentKey` changed beyond the intent -- listed under Tasks; `screen-mirror.mjs:3087-3104` requires a write-capable table to have `emptyNextKey ''` and its own `emptyAgentKey`.
  - `[false]` `[reject]` New `InteropTransformMint` class beyond the spec -- the intent refuses the agent's `content` as `TOOL.ARGUMENTS` before the mint, and `Mint.cls` reads the port first, which answers 422; the subclass runs `ArgumentProblem` first and defers to `##super`.
  - `[false]` `[reject]` `EndTestCapture` widened and `InvokeItemTest`'s guard narrowed -- the first is listed under Tasks; the second is needed because `IsTestWrite` now covers `TRANSFORMTEST`, and now has its 501 leg.
  - `[false]` `[reject]` `InteropTestGate` refactored to a shared `CreatePrincipals` -- the Design Notes prefer it, and `InteropTestGate` runs green.
  - `[false]` `[reject]` In-place edits to shared lines (`COMPOSEDTYPES`, `IsTestWrite`, `OWNPAIRS`, Baseline's last key, count pins) -- each is listed under Tasks, and none is a file Epic 18 changes beyond the add-only pins.
  - `[false]` `[reject]` The agent's not-listed refusal reads 400 `TOOL.ARGUMENTS`, not 404 -- `Mint.cls` maps an absent target to its refusal for every tool, and nothing parses or runs.
  - `[low]` `[patch]` The no-action-key 404 has no test -- the first leg of `TestAnUnlistedReadIsAbsentAndAForeignActionKeyIsNotImplemented`; mutation recorded.
  - `[low]` `[reject]` Intent clauses with no behavioral assertion (the EDI XML and plain-document renders, XML with leading blanks, an existing document target, `IsMutable` 0, audit rows for non-`done` statuses, no screen-context leak) -- each is a few lines that mirror the vendor's reader or the classic dialog; the cut marker, failed delete and extents parts are the rows above. `reopen_if`: one of these branches is found wrong on an instance.
  - `[false]` `[reject]` The agent's `OcuPilot`-named refusal comes at the confirm, not the mint -- the matrix names the existing `class` arm, which the Code Map places at `ScreenAction.cls:370` and `Confirm.cls:299`.
  - `[false]` `[reject]` Sub-readings (refusals only with the action key, an audit row for every answered request, metadata calls before the format judgement) -- each matches the Tasks wording; no divergence.

## Design Notes

**Governing ADs:**

- AD-62: items 2, 3, 5, 6, 11 and 12.
- AD-39: the seventh exception.
- Pairs, ids and the vendor's calls: AD-29, AD-8, AD-44, AD-13, AD-16, AD-21.
- The write's shape: AD-51 (Story 20.6's case: a source from declared `content`, fresh read `TRANSFORM`), AD-53, AD-56, AD-6, AD-52.
- What the write leaves and says: AD-15 (the 2026-10-12 named case), AD-14, AD-58 (`nothingSent`), AD-59.
- Agent and governance: AD-22 (key `true`, not destructive), AD-10 (reviewed below), AD-30 and AD-40.
- Rendering and the client: AD-11 and AD-47 (text only), AD-5 (a page is one loader line, as built in 20.29), AD-19.
- AD-7: the named limits at line 223.

Checked and not engaged: AD-36 (no new declared read), AD-26, AD-27, AD-54, AD-55, AD-57, AD-63, AD-64 (the list's pairs stay adjustable as before).

**Measured at this plan on `ocupilot-b-ci`** (`USER`; every probe class and row removed and verified):

- **Record Maps.**
  - A generated Record Map record class extends `%XML.Adaptor`, and so do `EnsLib.RecordMap.Batch` and `SimpleBatch`.
  - `ComplexBatch` descends from `ComplexParent`, not `ComplexBase`.
  - So the format test checks the Record Map family first.
- **Segments and EDI XML.** HL7 and X12 segments extend `EnsLib.EDI.Document` and parse and render through the same calls. `EnsLib.EDI.XML.Document` is both EDI and `%XML.Adaptor`.
- **Parsing.**
  - `ImportFromString` takes its status second in every family.
  - HL7 and X12 garbage or empty text answers no object with status OK. Non-HL7 text also writes a vendor Event Log warning that quotes it.
  - An XML root mismatch answers `ErrNoObjFromString` echoing the input.
- **DTL code.** A DTL `<code>` action's status variable is `tSC`. `1/0` inside a DTL is caught, answered as `ErrException`, and logged by the vendor. The generated `Transform` checks no privilege.
- **Stored objects.**
  - An X12 parse saves the interchange (3 rows), and a copy saves 3 more. Deleting each parent cascades.
  - The vendor leaves one changed segment's node and its id counters.
  - HL7 and XML runs store nothing.
  - A saved target was deleted back to the extent's count before.
- **Existing targets.** With no target, `Transform` answers "No existing target object". The classic `%New` argument shows up in `Ens.StringResponse.StringValue`.
- **Capture.** The capture holds a DTL's device write (`["probe-device-line"]`), and nothing reached the device.
- **The list.**
  - `USER` lists 4 transformations; `HSCUSTOM` lists 646.
  - 621 are testable: 594 XML to XML, 22 EDI to XML, and 5 EDI to EDI.
  - Segment ones (22) are admitted under the rule above.
  - 3 are refused for format: 2 ITK transformations whose target is a stream, and `Ens.SSH.InteractiveAuth.DTL`.
  - In `HSCUSTOM`, 529 use `create="existing"`.
- **Roles.** `%EnsRole_Administrator` and `%EnsRole_WebDeveloper` hold `%Ens_DTLTest:U` (and `%EnsRole_Developer` holds it through WebDeveloper), together with `%Ens_Code:R` or `RW`.

**Decisions:**

- **Posture.** The audience is narrower than the classic dialog's, which needs `%Ens_DTLTest:USE` and runs any class with a compiled `Transform`. OcuPilot adds `%Ens_Code:READ` and WRITE on the globals database, and runs only a listed `Ens.DataTransform` subclass. This matches AD-8's Story 20.6 amendment, so it raises no owner question.
- **`existing` target.** It is created with `%New()` and no argument. The classic dialog's argument would put its own marker text into a plain target's first property (measured), so the output would show text the input never held. The classic dialog does the same as OcuPilot for a document target, which no `HSCUSTOM` transformation uses.
- **Segments admitted.** Like the classic dialog, a sub-transformation of segments is testable (22 in `HSCUSTOM`).
- **The raw view, not the HTML table.** The output is text (AD-47). For a segmented document, the classic separators put one segment on each line.
- **Cleanup now, not at session end.** The classic dialog defers deletion to the web session's end. OcuPilot deletes in the same request, with the same `%Delete`.
- **The 20.6 card summary.** A confirmed host test card with a long output reads "Compiled" or "compile errors" (`outputErrorsOf` answers a boolean for any test answer). This story fixes it for both tests, since it adds the second test output that would hit it. It is fixed here, so there is no ledger entry.
- **Fixed strings (new literals, about 15).** The count goes from about 3,280 to about 3,295, under the 3,350 point that triggers raising the bound.
  - `interopTransformsEmptyAgent`: "Ask the agent why no data transformation is listed here."
  - The dialog title "Test <transform>", the label "Input" and the formats sentence "Paste the source message: an HL7, X12 or other EDI document's text, or XML for the transformation's source class."
  - The labels "Source class", "Target class" and "Console".
  - The four status sentences:
    - "The transformation ran, and its target is below."
    - "The input did not parse as the source class."
    - "The transformation failed."
    - "The transformation ran, but its target could not be shown as text."
  - The three refusals and the RUNS consequence (server sentences, above).
  - Reused: `serverFlagTest` (Test), `actionRun`, `actionCancel`.
- **Weight.** The page and dialog land in one lazy chunk, about 12 to 15 kB (20.6's pair is 12,037 bytes), under the 88 kB ceiling. The initial bundle gains only the strings, the answer reader and two map entries, about 2 to 4 kB (inference), against 1,896,272 bytes and `maximumWarning` 1992kB. There is no re-base, and no page is made eager.
- **Rule 31 (extend, do not copy):**
  - The tool extends `InteropAction`, with `InteropItemTestSend`'s shape.
  - `PerformTransformTest` follows `PerformTest`'s order. It reuses `AddTestLines`, `TESTOUTPUTMAX`, `TESTCUT`, the capture, `AuditRuntime`, `VERBTEST`, `Literal` and the refusal helpers, and extends `EndTestCapture` rather than adding a fourth capture-end loop.
  - The Input row reuses `ExplorerSaveMint.Hunk`.
  - `test-answer.ts` is extended rather than given a sibling module.
  - The dialog is its own component: one input, against the host dialog's field form. It reuses `Dialog`, `CodeBlock` and the answer module.
  - The gate class reuses `InteropItemGate`'s helpers. Its `Probe` legs and principals differ from `InteropTestGate`'s item-specific constants, so making `EnsurePrincipals` a class method taking the spec is preferred; if it is copied instead, the commit says why.
  - The browser spec keeps the per-spec `structural` helper, the convention about 20 specs share. Unifying it would touch other epics' specs.
- **AD-10 review.** The `class` arm judges the transformation by name, so an `OcuPilot*`-named one is refused with the existing self-protection sentence, which speaks of compile, delete or replace. OcuPilot ships no transformation, so only a user's own `OcuPilot*` class reaches it (named limit). No new prohibited entry.
- **Size.** This is one story, about the size of 20.6's Part A. No split is recommended: both callers and the screen make up the one AC.

**Named limits** (for AD-7 and AD-62 item 11, beyond the HL7 `^EnsHL7.Segment` node and the gateway timeout already named):

- An X12 parse saves rows the test deletes, and the vendor keeps a changed segment's storage node and its id counters.
- The vendor's Event Log keeps what it logs during a test: the parse warning that quotes non-HL7 text, and a DTL's trapped exception.
- A segment parse answers an object for any text, so it cannot report bad input.

**For the spec gate (Rule 20 drafts; the lead writes them):**

- **AD-62 item 11, the transformation half.**
  - The source and target are judged before any vendor call, in order: Record Map or batch refused; virtual document (segments and EDI XML included); `%XML.Adaptor`; anything else refused.
  - A parsed document is made immutable.
  - `create="existing"` targets come from `%New()` with no argument.
  - The target renders as the classic dialog's raw view or as indented XML.
  - Objects that gained an `%Id()` are deleted in the same request.
- **AD-7's Story 20.27 named limits.** Add the three limits above.
- **EXPERIENCE.md :173 dialog list.** Add "test a data transformation (Data transformations' Test, Story 20.27: the transformation's name as the title, one multi-line Input with the sentence naming the formats, the sentence that its code runs as you, Run, and the result: the source and target class, a status sentence, and the target's text and what the transformation wrote, drawn as text) [ADDED 2026-10-12 - Story 20.27]".

**Integration, Consumes, Consumed-by:**

- Integration: AC1, AC2 and AC9 run against `ocupilot-b-ci` through the screen route, the agent's mint and confirm, and the browser.
- Consumes:
  - 20.6: `IsTestWrite`, the capture and `EndTestCapture`, `AddTestLines`, `AuditRuntime` verb `test`, `test-answer.ts`, `InteropItemSeam`, `InteropItemGate`'s helpers, and the AD-39 exception.
  - 20.2: `ListClasses`, `CODEPAIRS` and the Data transformations descriptor.
  - 20.21: `ExplorerSaveMint.Hunk`. 20.17: card collapse. 20.29: the loader maps.
- Consumed-by (inference): 20.16, whose DTL edits a test can check, and 20.12, whose workflows may propose one.

**Ledger inbox (Rule 17):** empty. For the lead: DW-2361 (`burndown`, context only) means this story's switched path is held by convention and code review, not by the probe-namespace guard. DW-2345 stays terminal: `EndTestCapture` is extended, not copied again.

**Contended files (Rule 11).** `origin/OCU-1-epic18` (`0ffa1c7b`) is an ancestor of this branch. Local, unpushed Epic 18 commits touch only the spine (AD-37) among the files this story edits.

- This story's edits to shared files are additions or count pins:
  - `SurfaceCoverage`, `ReadTool`'s count and name, `strings.ts`, and the `screen-outlet.ts` loader line;
  - EXPERIENCE.md clauses appended inside :159 and :604;
  - the spine drafts (the lead's).
- `screens.generated.ts` changes Data transformations' own generated entry (Epic 20's descriptor) and is regenerated at the forward merge.
- No Rule 11 ask.

## Verification

**Shared surfaces:**

- Data transformations' row actions and empty state, and the generated mirror's entry for it.
- `InteropDescriptor`'s transforms pin.
- The tool rosters: `SurfaceCoverage`, `ReadTool`'s count and names, `ToolWrite`'s other-port count, `ToolRoundTrip`, `ToolEmit`, `ClassicPageGate` (count and own pairs), `MappingDescriptor`'s classic roster.
- The governance baseline (+1 key, `true`).
- The port's `IsTestWrite`, `COMPOSEDTYPES` and `EndTestCapture`.
- The card's test-output summary.
- The Fixed-strings row and the :159 sentence.
- The arming lines in `ci-throwaway.sh`.

*Every test added or changed passes on a fresh environment, in either order. The new classes use no probe production, and `InteropTransformTest` must pass as the first class on a fresh instance.*

**Setup (slot B; never the dev instance `ocupilot-slot-b`):**

- Load `src`: `rsync -a --checksum --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-20/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`, then in `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM` run `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)`.
- Before any browser run: `cd ui && npm run build && docker exec ocupilot-b-ci sh -c 'cd /durable/iris/csp/ocupilot && rm -rf ./*' && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`.

**Commands.** Run each in the foreground with `timeout: 600000`, one at a time. Read each class's result from `%UnitTest_Result`. The runner reports `0 with probe leftovers`.

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.InteropTestDescriptor --class OcuPilot.Test.InteropTransformTest --class OcuPilot.Test.InteropTransformTestRefusals --class OcuPilot.Test.InteropTransformTestGate`. Expected: green.
- `(loop)` the same with `InteropHostTest`, `InteropHostTestRefusals`, `InteropHostTestEdges` and `InteropTestGate` (about 100 s by `ci-timings.json`). Expected: green, because `EndTestCapture` and `IsTestWrite` changed under them.
- `(loop)` the same with `InteropDescriptor`, `SurfaceCoverage`, `ReadTool`, `ToolWrite`, `ToolRoundTrip`, `ToolEmit`, `ClassicPageGate`, `MappingDescriptor`, `Prohibited` and `GovernanceBaseline`. Expected: green.
- `(loop)` the same with `StageTwoTools`, `InteropFloor`, `InteropFloorOwnPairs`, `CompileWithoutInterop`, `Descriptor`, and every other class the sweep changes. Expected: green.
- `(loop)` `cd ui && npm run build -- --verbose`. Expected: the prebuild chain green, the new chunk under 88 kB, and the initial total under 1992kB. Record both.
- `(loop)` `cd ui && npm run test:tools`, then `cd ui && npm run test:components`. Expected: green.
- `(loop)` `uv run scripts/check-objectscript.py <each changed .cls>` and `bash scripts/lint-docs.sh`. Expected: clean.
- `(loop)` `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/<file>`, one file per call, after the redeploy: `interop-transform-test.browser-spec.mjs`, `interop-item-test.browser-spec.mjs`, and `a11y-structural-invariants.browser-spec.mjs` (about 405 s). Expected: green.
- **Lead-owned (the runner's, not the implement stage's):** the full ObjectScript sweep, `cd ui && npm test`, `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`, and Rule 30's fresh check.
- **Left to CI:** the full browser suite.

**Planned pinning mutations (Rule 19; revert each byte-identical, reload or rebuild and redeploy before the next):**

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | `Transform` called twice, or the XML render skipped | `InteropTransformTest` XML legs (`Runs()` +2, or no `out:x`) |
| AC1 | `PerformTransformTest` drops `AuditRuntime` | its audit legs |
| AC2 | Segments rendered without the classic separators | the HL7 leg (one line instead of segments) |
| AC2 | Cleanup deletes the target only | the X12 leg's extent |
| AC3 | `StateDiff` drops `Input`, or the consequence code is cleared | the mint legs, and the proposal-card spec |
| AC4 | The trap around `Transform` removed | the `Raw` leg (500, not 200 `transform`) |
| AC4 | The capture closed before `Transform` | the `write` leg (`console` empty) |
| AC4 | `LogFault` given the error lines | the seam leg's `Logged()` check |
| AC5 | The Record Map check dropped | the `Batch` leg (parsed as XML, not 409 `SOURCEFORMAT`) |
| AC5 | `CONTENT` checked after the parse | the empty-content leg (`Runs()` moves) |
| AC6 | `Confirm` records the output as the read-back, or `WriteOutput` adds `outcome` | the stored-text leg, and `InteropTestDescriptor`'s outcome test |
| AC6 | The dialog draws lines through `innerHTML` | the dialog spec, and the browser text-only test |
| AC7 | `ReadTransform` calls `Transform` | the read leg's `Runs()` |
| AC8 | `DTLTESTPAIR` not appended | `InteropTransformTestGate`'s port and route legs |
| AC9 | The page does not register `test` | the page spec, and the browser spec's step 1 |
| card | `outputErrorsOf` reads a test answer again | the proposal-card summary spec |

**Recorded (implement pass).**

- Task 0 (a): the screen route's `write` leg answers 200 as one JSON envelope, `console` `["probe-device-line"]` and the indented target in `lines`; held by `InteropTransformTestRefusals.TestEachOutcomeIsAnswered200WithItsStatus`.
- Task 0 (b): an `EnsLib.EDI.XML.Document` source parsed through `ImportFromString` (status OK, an object), a `create='copy'` DTL ran on it, and `OutputToLibraryStream(stream, "wt")` wrote `<root>` with `<a>1</a>` and `<b>two</b>` indented on their own lines; nothing was stored. The probe DTL is deleted.
- Task 0 (c): the fixture's X12 interchange parsed and its copy transformed; `EnsLib_EDI_X12.Document` read 6 before, 12 with source and target alive, and 6 after `%Delete(%Oid())` of each.
- mutation: AC1, a second `Transform` call in `RunTransformHere` -- `InteropTransformTest` reddens its run-count legs (person, agent) and the existing and X12 legs; the rendered text blanked -- the person, agent, HL7 and X12 legs redden.
- mutation: AC1, `AuditRuntime` dropped from `PerformTransformTest` -- the person's and the agent's audit legs redden.
- mutation: AC2, `RenderTargetHere` without the classic separators -- the X12 leg reddens; the HL7 leg stays green, because HL7's default output is carriage-return separated and the line split reads it as lines.
- mutation: AC2, cleanup deleting the target only -- the X12 extent leg reddens.
- mutation: AC3, `StateDiff` without the `Input` row -- the card leg and `InteropTestDescriptor.TestTheTransformAnswerNeverCarriesAnOutcome` redden; `CONSEQUENCECODE` cleared -- the consequence leg reddens; the card spec's RUNS mapping dropped -- the RUNS test reddens.
- mutation: AC4, the single `Catch` of `RunTransformHere` rethrowing -- the `Raw` leg answers 500 and the log leg reddens.
- mutation: AC4, the capture ended before `RunTransformHere` -- the `write` leg's console reddens.
- mutation: AC4, `LogFault` handed the error text -- `TestNothingTheRunWroteReachesTheLog` reddens.
- mutation: AC5, the Record Map check removed from `FormatKindHere` -- the `Batch` leg reddens for both callers.
- mutation: AC5, the content check removed from `ReadTransform` (the whole, then the upper bound alone) -- the empty and over-bound legs redden.
- mutation: AC6, `WriteOutput` adding `outcome` -- `InteropTestDescriptor.TestTheTransformAnswerNeverCarriesAnOutcome` reddens; `Confirm` recording the output as the read-back -- the stored-text leg of `TestTheAgentsRunConfirmsOverHttp` reddens.
- mutation: AC6, the dialog drawing its lines through `innerHTML` -- the dialog spec reddens (a `b` element is made) and the browser spec's AC6 test reddens (the text `<b>x</b>` reads `x`).
- mutation: AC7, `TransformFactsHere` running `Transform` -- `TestAReadRunsNothingAndStoresNothing` and the run-count legs redden.
- mutation: AC8, `DTLTESTPAIR` not appended in `Pairs` -- the missing-dialog principal's `TRANSFORM` and `TRANSFORMTEST` port legs redden; the route legs stay green, because the tool's own pairs refuse first.
- mutation: AC9, the page not registering `test` -- 8 of the page spec's 9 tests redden and all four browser tests redden (the row menu never offers Test).
- mutation: card, `outputErrorsOf` reading a test answer again -- `proposal-card.spec.ts`'s summary test, `test-answer.test.mjs` and `turn.test.mjs` redden; `transformAnswerOf` accepting a non-array `lines` -- `test-answer.test.mjs` reddens.
- Task 0 and the mutations ran on `ocupilot-b-ci`; every mutated file was restored byte-identical and reloaded or rebuilt and redeployed before the next.
- Sizes: the new lazy chunk `interop-transform-list-page` is 8,018 bytes (`LAZYCHUNKMAX` 88,000); the initial total is 1,899,692 bytes in 20 files (`maximumWarning` 1992kB); the string table holds 3,326 literals against the bound of 3,400.
- mutation: AC2, `RunTransformHere` deleting nothing -- `InteropTransformTestRefusals.TestAStoredTargetIsDeletedBeforeTheAnswer` reddens.
- mutation: AC4, `RenderTargetHere` without the cut marker for a stream it did not read to the end -- `TestATargetPastTheBoundIsCutAndMarked` reddens.
- mutation: AC5, `ComplexBase` dropped from `RECORDMAPBASES` -- the `RmComplexBase` leg reddens for both callers; `content` judged before the formats -- `TestAFormatIsRefusedBeforeTheMessageIsJudged` reddens; the target judged before the source -- the `StreamBoth` legs redden; `'tFacts("compiled")` dropped from the absence check -- the `Uncompiled` legs redden; the absence check made to apply only with an action -- the no-action 404 leg of `TestAnUnlistedReadIsAbsentAndAForeignActionKeyIsNotImplemented` reddens; the 501 arm of `InvokeTransformTest` removed, and `InvokeItemTest`'s guard compared with `IsTestWrite` again -- its two 501 legs redden.
- mutation: AC5, `ConfirmProblem` answering no problem and `ScreenActionDelta` carrying a number -- `InteropTestDescriptor.TestTheTransformToolsConfirmAndScreenHooksJudgeTheMessage` reddens; an extent of `Counts` that does not exist -- `InteropTransformTest.TestTheExtentsTheLegsCompareAreReadable` reddens.
- mutation: AC8, `Admit` asking READ instead of WRITE on the globals database for a write -- `InteropTransformTestGate.TestEachMissingPairIsRefusedByNameThroughThePort` reddens for the `NoRead` and `NoWrite` principals.
- Review pass: the three Record Map bases, a stream on both sides and a stored but uncompiled class are probe transformations of the fixture, and the output past `TESTOUTPUTMAX` now ends in `TESTCUT` however many line ends the read held. Each mutation was reverted byte-identical and the tree reloaded before the next.
- (QA) tests added to existing files, no new file: `InteropTransformTestRefusals` (`TestAnOversizedTargetIsCutAndMarkedInTheAgentsConfirm`, `TestEveryStatusOfARunIsAudited`, `TestAnEdiXmlSourceNeverOpensThePastedTextAsAFile`), `InteropTransformTest` (`TestAnEdiXmlDocumentIsParsedAsADocumentAndShownAsIndentedXml`, and an EDI XML case in `TestAReadRunsNothingAndStoresNothing`), `InteropTransformFixture` (the `big` value of `OcuProbeDtl.Xml`, and `OcuProbeDtl.EdiXml`), `ui/tools/turn.test.mjs` and `ui/src/app/shell/proposal-card.spec.ts` (an answer at the output bound reaches the outcome and the card whole).
- (QA) defect closed in `InteropPort.ParseSourceHere`: `EnsLib.EDI.XML.Document` opens text with no `<` in its first four characters as a file name, so a pasted server path as the source of an EDI XML transformation was read and its body shown (AD-21). XML text, an EDI XML document's included, is now refused `input` unless its first non-blank character is `<`, and the document is handed the text from there.
- mutation: (QA) AC4, `WriteOutput` handing the answer its first thousand lines -- `TestAnOversizedTargetIsCutAndMarkedInTheAgentsConfirm` reddens, and `TestATargetPastTheBoundIsCutAndMarked` (one line) stays green.
- mutation: (QA) AC6, `transformOutcomeLines` keeping the first thousand lines -- the `turn.test.mjs` output-bound test and the card spec's output-bound test redden; the card's `outputSteps` cut at 100,000 characters -- the card spec's test reddens alone.
- mutation: (QA) AC4, `AuditRuntime` only when the status is `done` -- `TestEveryStatusOfARunIsAudited` reddens for all four statuses.
- mutation: (QA) AC5, the XML check dropped for a virtual document in `ParseSourceHere` -- `TestAnEdiXmlSourceNeverOpensThePastedTextAsAFile` reddens (the file's body is in the answer) and the blanks legs of `TestAnEdiXmlDocumentIsParsedAsADocumentAndShownAsIndentedXml` redden.
- mutation: (QA) AC2, `FormatKindHere` judging an XML adaptor before a virtual document -- the EDI XML case of `TestAReadRunsNothingAndStoresNothing` and the EDI XML run test redden; `RenderTargetHere` without `"wt"` for EDI XML -- the EDI XML run test reddens.
- (QA) after: the four story classes (35 tests, `InteropTestDescriptor` 13, `InteropTransformTest` 7, `InteropTransformTestRefusals` 12, `InteropTransformTestGate` 3), `turn.test.mjs` and `test-answer.test.mjs` (100) and the card spec (76) are green, and the story's browser spec passes 4 of 4; each mutated file was restored byte-identical and reloaded before the next.
- mutation: (CR) AD-21. The document type check dropped from `PastedXmlHere` reddens `TestAnEdiXmlSourceNeverOpensThePastedTextAsAFile`: the EDI XML leg shows the file's body. The entity resolver dropped from `ParseSourceHere` makes its schema leg `done`, which reddens it.
- mutation: (CR) AC2. `PastedXmlHere` stripping blanks alone reddens the line-end legs of `TestAnEdiXmlDocumentIsParsedAsADocumentAndShownAsIndentedXml` and the XML declaration leg.
- mutation: (CR) AD-59. `TransformSnippet` and `TestSnippet` handing on the message as pasted redden the EDI XML and refusal legs of both `InteropTestDescriptor` script tests.
- mutation: (CR) AC4. Resetting the count before the console in `PerformTransformTest` reddens `TestTheConsoleSharesTheOutputBoundWithTheTarget`.
- mutation: (CR) AC5. The `TARGETFORMAT` refusal dropped from `ReadTransform` reddens the `ToStream` legs, including "no refusal ran a transformation", now that every probe counts its runs.
- mutation: (CR) AC8. Naming `%Ens_TestingService` as the tool's `WRITERESOURCE` reddens the screen-route and tool-pair rows of `InteropTransformTestGate`.
- mutation: (CR) a11y. The dialog's status region without `role` reddens "announces the end of a run".
- (CR) after: on `ocupilot-b-ci` the following are green: `InteropTestDescriptor` (13), `InteropTransformTest` (7), `InteropTransformTestRefusals` (13), `InteropTransformTestGate` (3), `InteropHostTest` (12), `InteropHostTestRefusals` (7), `InteropHostTestEdges` (5), `InteropTestGate` (5), `ReadTool` (28) and `CompileWithoutInterop` (7). `test:tools` (1,964) and `test:components` (3,013) are green, and the story's browser spec passes 4 of 4 on the rebuilt bundle. Each mutation was reverted byte-identical and the tree reloaded.

## Auto Run Result

Status: done
Blocking condition: none

**Implemented.** The `Transforms` endpoint of `InteropPort` gains the composed `TRANSFORM` read and the `TRANSFORMTEST` write, with `%Ens_DTLTest:USE` and WRITE on the globals database as its gate, the format judgement before any vendor call, the parse, run, render and same-request cleanup inside the output capture, and OcuPilot's own audit row. The agent's `interop.transforms.test` (with its own mint for the argument bound) and Data transformations' Test row action reach it; the key ships `true`. The client adds the lazy page and dialog, the answer reader, the card sentence, the maps, the fixed strings and the regenerated mirror. `EXPERIENCE.md` :159 and :604 gain their clauses.

**Files.** `Port/InteropPort.cls` (the types, read, test, snippet, capture lines); `Api/InteropError.cls` (4 codes); `Screen/Tool/InteropTransformTest.cls` and `InteropTransformMint.cls` (new); `Screen/Descriptor/InteropTransformList.cls`, `Kernel/Governance/Baseline.cls`; tests `InteropTransformFixture`, `InteropTransformTest`, `InteropTransformTestRefusals`, `InteropTransformTestGate` (new) and the roster classes (`SurfaceCoverage`, `ReadTool`, `ToolWrite`, `ToolRoundTrip`, `ToolEmit`, `ClassicPageGate`, `MappingDescriptor`, `InteropDescriptor`, `InteropTestDescriptor`, `InteropTestGate`); `scripts/ci-throwaway.sh` (arming line); client `interop-transform-list.page.ts` and `interop-transform-test-dialog.ts` with their specs, `test-answer.ts`, `turn.ts`, `proposal-view.ts`, `screen-actions.ts`, `screen-action-handler.ts`, `screen-outlet.ts`, `strings.ts`, `screens.generated.ts`, the page, panel and card specs, three `ui/tools` tests, and `ui/browser/interop-transform-test.browser-spec.mjs`.

**Review.** Two layers ran (verification-gap, intent-alignment); 22 findings, none high. Patches applied: 3 medium and 7 low, among them a real defect (a target past `TESTOUTPUTMAX` was cut with no marker) fixed in `RenderTargetHere`. No item is deferred. Rejected: 3 low (the failed-delete, EDIFACT terminator and unasserted-branch gaps, each with a `reopen_if`) and 9 false, each with its reason in the Review Triage Log. Follow-up review recommended: true. The named unverified risk is the oversized answer (about 1 MB of JSON) through the agent's confirm and the proposal card; only the person's screen route is tested at that size.

**Verification.** On `ocupilot-b-ci`, after the patches: the four story classes (31 tests), the host test classes (29), the roster classes (123) and the floor, compile-without-interop and descriptor classes (79) are green, `InteropTransformTest` first on a fresh instance. The build chain is green; `test:tools` passes 1,963 and `test:components` 3,011 (241 files); `check-objectscript.py` and `lint-docs.sh` are clean. The new browser spec passes 4 of 4, and `interop-item-test` and `a11y-structural-invariants` passed on the same bundle before the patches, which changed no client source. Every mutation is recorded under Verification and was reverted byte-identical. The new lazy chunk is 8,018 bytes (ceiling 88,000); the initial total is 1,899,692 bytes in 20 files (warning 1992kB); the string table holds 3,326 literals against its bound of 3,400.

**Residual risks.** The lead-owned items are not run here: the full ObjectScript sweep, `npm test` end to end, `smoke.sh`, Rule 30's fresh check. The string table is 74 below its bound, and Epic 18's additions may need the lead to raise it. `ci-timings.json` has no entry for the three new armed classes or the new browser spec. The Design Notes' premise that the 20.6 card read "Compiled" does not hold for the shipped panel (`panel.ts:1161` nulls `outputErrors` for non-explorer tools); the `outputErrorsOf` change is defensive.
