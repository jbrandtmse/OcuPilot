---
title: 'Story 20.6: Testing hosts and transformations'
type: 'feature'
created: '2026-10-11'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
warnings: [oversized, multiple-goals]
deferred: []
---

<intent-contract>

## Intent

**Problem:** A production's hosts and transformations can still be tested only in the classic portal: the Testing Service page (`EnsPortal.TestingService` and its dialog) sends a request built from the target's message classes, and the Test Transform dialog (`EnsPortal.Dialog.TestTransform`) runs a transformation on pasted input. Nothing in OcuPilot tests either one, so a change cannot be checked here before it is deployed.

**Approach:** Extend `Port/InteropPort` (AD-62) with a host test and a transformation test, each a confirmed proposal for the agent and a person's own action on the screen (AD-53). Part A, the host test, adds a per-host Test tab. Its read lists the request classes the target takes and their fields, and its Send action builds the request from them and sends it through `EnsLib.Testing.Service`. It then shows the session, the status and the response. Part B adds a Test row action to Data transformations: the pasted input is parsed into the transformation's source class, the transformation runs once in process, and the target renders as text. Neither result ever reaches the model (AD-39).

## Boundaries & Constraints

**Always:**

- Every new read and write goes through `InteropPort.Invoke` behind its gate (AD-29, AD-62 (2)). The gate checks the endpoint's pairs, then READ on the namespace's globals database (WRITE for a test), and refuses naming the failed pair. Measured at this plan, `SendTestRequest` and `Transform` check no privilege, so this gate is the whole gate.
- Pairs are the classic pages' checks plus the floor (AD-8, AD-44):
  - Test tab and host test: `%Ens_Portal:USE` and `%Ens_TestingService:USE`.
  - Transformation test: Data transformations' `%Ens_Portal:USE` and `%Ens_Code:READ`, plus the dialog's `%Ens_DTLTest:USE`.
  - Both tests add WRITE on the globals database. Neither adds the routines database.
- The port calls the vendor's classes in the caller's process, switched by explicit save and restore (AD-16), and calls no `OcuPilot.*` class while switched: vendor values are collected into locals, and rows are built after the restore. Never `%Api.InteropEditors.*` (AD-62 (1)).
  - Host test: `EnsLib.Testing.Service.SendTestRequest` (asynchronous, as the classic dialog calls it), the request class list as the classic dialog builds it (`GetMessageList`, `[Internal]`, the page's own call, as Story 20.5 read `getTimestamp`), and the test's AppData through `Ensemble.inc`'s `$$$EnsRuntimeAppData`, as the dialog polls and kills it.
  - Transformation test: `GetSourceType`, `GetSourceDocType`, `GetTargetType` and `GetTargetDocType`, then `Transform` with `process` and `context` defined empty, as the classic dialog does.
  - Input is parsed by the documented calls the hidden `Ens.Util.Serialized.Reader` dispatches to: a virtual document's own `ImportFromString`, and `Ens.Util.XML.Reader.ObjectFromString` for an `%XML.Adaptor` class.
- Before any vendor call, the port refuses by name whatever the vendor would answer as a silent success or a device write (AD-62 (5)):
  - The production is not running.
  - Testing is not enabled. The vendor then writes `DisplayError` text to the current device (measured).
  - The target is a business service, or is disabled. A disabled target's request waits forever (measured).
  - The request class is one the target does not take.
  - A credential-named field carries a value.
  - The source or target class has no text form OcuPilot reads or writes.
- Every vendor call that can write to the device runs inside the capture `AtelierPort` uses (`$$BeginCapture^%SYS.Capture`, `AtelierPort.cls`:3042-3061): `SendTestRequest`, the parse and `Transform`. The screen action and confirm answers therefore stay JSON.
- Each write finishes in its own request (AD-7). The host test waits at most `TESTWAIT` (15 s, AD-62 (6)'s cap) for its answer, then answers `waiting` with its session id. No spawn site is added.
- A host test result and a transformation test's output, error and console lines reach the screen and the proposal card only, rendered as text (never markup, AD-47). They never reach the model, a tool result, a ledger row, an audit payload, a log line or screen context (a new AD-39 exception).
- A request field whose name matches the credential pattern (`Kernel.Audit.Log.IsCredentialName`) is listed with `Secret` true. A value sent for it is refused from both callers before any vendor call, and the ledger row and the step never carry it (`CallSecretNames`). A response field so named reads blank.
- Each test records OcuPilot's own `ConfigChange` audit row from either caller (`AuditRuntime`, verb `test`), because the vendor records none (read: no audit call in either path). The row never carries a field value, an input, an output or a response.
- Edits to files Epic 18 is changing are add-only: roster rows, list entries, and the count pins that move with them (Design Notes › Contended files).

**Never:**

- No server file or path as input (AD-21): pasted text only, and no file picker.
- No production setting write. Testing is enabled in the classic production settings, as the classic page also requires.
- Record Map, batch and other non-XML sources are refused `SOURCEFORMAT`.
- No `aux`, `process` or `context` values.
- No synchronous `SendTestRequest`: its `SendRequestSync` waits forever.
- No new Save route, no new entity type, and no edit to `Screen/Registry.cls`, `Screen/Read.cls`, `ui/tools/screen-mirror.mjs`, `navigation.ts` or `angular.json` (unless DW-1166's re-base applies).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Test tab | `item` criterion, a BP or BO | One row per settable field of each request class the target takes: `Production, Item, RequestClass, Kind, Field, Type, Required, MaxLength, Values, Secret`. The target's own classes come first, then subclasses by name. A virtual-document class gives one `content` row (`Kind` `document`), and a class with no settable field gives one row with an empty `Field` | A business service gives zero rows and the empty state. Unknown item: 404; no criterion: 400 |
| Send, answered | Running, testing enabled, an enabled BP or BO, a request class it takes, valid fields | The request is built and saved, then sent. The answer is `{status: done, sessionId, responseClass, lines, errors: false}`, one `Field: value` line per response field (a document's raw text instead), and the AppData node is removed | — |
| Send, no response | The target answers none | `status: done`, `lines: []`, and the screen and card show the no-response sentence | — |
| Send, failed | The target or routing errors | `status: error`, `errors: true`, the error's text as `lines` | — |
| Send, slow | No answer within `TESTWAIT` | `status: waiting` with `sessionId`. The node is left for the vendor's own stop or start cleanup | — |
| Send refused | Each condition, from both callers | Nothing saved or sent (header count unchanged) | 409 for each: production not running is `INTEROP.PRODUCTION.NOTRUNNING` (reused); `INTEROP.TEST.DISABLED`, `TARGETTYPE`, `TARGETDISABLED`, `REQUESTTYPE`, `SECRET` |
| Send invalid | Unknown field, or a value its `IsValid` refuses, or a required field empty | Nothing sent | 422 `INTEROP.TEST.FIELD` or `INTEROP.TEST.VALUE` on the field; a request the vendor cannot build or save (or a document that does not parse): 422 `INTEROP.TEST.REQUEST` |
| Transform, done | A listed transformation and pasted XML or EDI text | `{status: done, sourceClass, targetClass, lines, console, errors: false}`: the target as indented XML or the document's raw text. Anything the test persisted is deleted | — |
| Transform, failed | Input that does not parse, or a `Transform` error or fault, or output that cannot be written | `status` `input`, `transform` or `output`, `errors: true`, the error's text as `lines` (answered 200: the test ran) | — |
| Transform writes | The transformation writes to the device | The text is in `console`, and the answer stays JSON | — |
| Transform refused | Source, or target, neither EDI nor `%XML.Adaptor`; not a listed transformation; `content` empty or too long | Nothing runs | 409 `INTEROP.TRANSFORM.SOURCEFORMAT` or `TARGETFORMAT`; 404 `PORT.NOTFOUND`; 422 `INTEROP.TRANSFORM.CONTENT` |
| Gate | Caller missing one pair, or READ only on the globals database | Refused before any vendor call | 403 naming the pair |
| Namespace | No interoperability | Refused | 409 `INTEROP.NAMESPACE` |

</intent-contract>

## Code Map

### Port (`src/OcuPilot/Port/InteropPort.cls`, 4,559 lines)

- **Header and registry parameters.**
  - Header :1-55: the write list :1-5, the gate order :13-35, the seam list :50-52.
  - `ENDPOINTS` :65 (pinned at `Test/InteropHostDescriptor.cls`:23, parsed by `screen-mirror.mjs`:1105), and the `ENDPOINT*` constants :67-120.
  - Pair sets :125-185 (`CODEPAIRS` :130). `COMPOSEDTYPES` :152, read by `Test/Prohibited.cls`:438, `Test/ToolWrite.cls`:1321 and `Test/OAuthDelete.cls`:214.
  - Types :204-317; query keys :302-463 (`CONTENTKEY` :327, `ITEMKEY` :383, `ACTIONKEY` :460, `MAXROWSKEY` :463).
- **Predicates and dispatch.**
  - `IsWrite` :554, `IsItemWrite` :560, `IsRuntimeWrite` :575, `IsLookupWrite` :3571.
  - The five-way `tWrite` OR is written twice, `Invoke` :747 and `Admit` :829: a sixth predicate joins both, or both become one helper.
  - `Pairs` :602-634 (write-pair appends :627-632), `Serves` :640-653, `Invoke` :736-818 (dispatch blocks :753-814), `Admit` :825-842 (database pair :836-837, the routines-database rule :838-841).
- **Siblings.**
  - Data transformations' read: `ListClasses` :900-951 (`SubclassOf Ens.DataTransform`, excluding the two bases :904-905; rows `{Name: "<class>.cls", Modified}`; the switch pattern :910-933).
  - Items: `InvokeItems` :1092, `GatherItems` :1318-1359 (`GetBusinessType` :1350, effective `Enabled`), `ItemRow` :1365-1382, `ItemParts` :1678, `ResolveItem` :2467.
  - `ReadItem` :1409 shows a composed read refusing in order.
  - `InvokeLookup` :3678 is the per-family dispatcher shape.
  - `PerformJobAction` :3354-3384 is the action-write template (read, refusal, vendor call, `AuditRuntime`, row).
  - Refusal helpers :2285-2383: `Statused`, `Mapped`, `LogFault`, `Deny`, `Refuse`, `Conflict`, `ConflictFor`, `Absent`, `Unavailable`, `Fail`.
  - `AuditRuntime` :3390-3398 (`VERB*` :369-409); `SnippetForm` :3402, `Snippet` :3423, `RuntimeSnippet` :3463, `Literal` :4550.
- **`src/OcuPilot/Port/AtelierPort.cls`:**
  - `MAXIMPORTCHARACTERS` 3,000,000 at :419, the screen's input bound.
  - The capture at :3042-3061, the sibling for every device-writing vendor call.

### Tools (`src/OcuPilot/Screen/Tool/`)

- `Write.cls` (base):
  - `READSVALUES` :176, `SCREENACTIONS` :167, `SCREENVALUES` :226, `PRECONDITIONCODES` :508, `READBACKFIELDS` :980.
  - `ScreenActionDelta` :740, `InputSchema` :830, `ArgumentProblem` :942.
  - Output is `WriteOutput(pWritten)`, found by reflection in `Kernel/Proposal/Operation.cls`:225-238.
- `InteropAction.cls` (140 lines): `WRITERESOURCE` :41, `DATABASEPERMISSION` :46, `ROUTINESDATABASE` :51, `STATEMARKER` :55, `CONSEQUENCECODE` :59, `PrivilegePairs` :89-116, `PortQuery` :131-139.
- `InteropItemAction.cls`: `MintClass` `InteropItemMint` :50, `PRODUCTIONARGUMENT` :39, `InputSchema` :65, `StateDiff` :87. This is the host-test tool's parent.
- Siblings:
  - `ExplorerSqlRun.cls`: values-composed read, `ScreenActionDelta` :151 (JSON text to an argument), `PortQuery` :197, `WriteOutput` :248-253.
  - `InteropLookupTableImport.cls`: pasted `content` under `SCREENVALUES` :38.
  - `InteropLookupEntryAction.CallSecretNames`: the ledger redaction.
- `ExplorerSave.cls`:54 `CHANGEMAXLENGTH` 30,000 is the agent's bound for a card-sized argument (Stories 20.20 and 20.21).

### Screens and client

- **Descriptors.**
  - `Screen/Descriptor/InteropItemJobTab.cls` is the tab shape to copy: archetype `detail`, `LIST` read, criterion `item` (352), `tab` group `interoperability/productions/items/document` with Jobs at position 6.
  - `InteropTransformList.cls`:17-63: `rowActions` `[]`, entity `class`, toolIdentifier `interop.transforms`. Its no-action shape is pinned at `Test/InteropDescriptor.cls`:164 (`"class||tableReadOnlyEmptyNext"`).
- **Pages.**
  - `ui/src/app/shell/screen-outlet.ts` `DESCRIPTOR_PAGES` :159 (interop :278-283).
  - `areas/interoperability/interop-item-setting-list.page.ts` is a tab page hosting its own dialog: registers at :103, sends at :152.
  - `interop-lookup-table-list.page.ts` reads `lastOutput()` at :278.
  - `ui/src/app/shell/screen-action-handler.ts`: `SCREEN_ACTION_DESCRIPTORS` :67-145, `UNDRAWN_ACTIONS` :386-419, `sendFor` :1467, `lastOutput` :1484.
- **Card output.**
  - `ui/src/app/core/turn.ts` `outputLinesOf` :497 treats any string `outcome` as a SQL answer (:499), so neither test answers an `outcome` member. `outputErrorsOf` :508 reads `lines` and a boolean `errors`.
  - The card draws it through `app-code-block` (`proposal-card.ts`:1109-1114, `shell/code-block.ts`:13-21, text only). `core/sql-answer.ts`:125 `sqlOutcomeLines` is the sibling for a fixed-string status line.
- **Strings.**
  - `ui/src/app/core/strings.ts`: 3,214 literals, bound 3,400 (`ui/tools/strings.test.mjs`:611).
  - `ui/tools/interop.test.mjs`:31-94 `SENTENCES`.
  - EXPERIENCE.md: :159 (the tab order sentence), :173 (dialog list), :604 (last Fixed-strings row; nothing is inserted above it).

### Registries and rosters

- `Kernel/Proposal/Prohibited.cls`: the `class` code arm :1421-1431 judges a transformation test by its name. The `production-item` `ReviewedFewOnly` arm :1676 sweeps the card's fields against `PermittedChangeFields` :1119.
- `Kernel/Governance/Baseline.cls`: interop keys :219-240.
- `Api/InteropError.cls` (124 parameters): `Codes` :334, `ConsequenceCodes` :340, the family lists :346-401, `ReasonFor` :408-473. `Api/Error.cls` holds 989 of 1,000 parameters, so new codes go in `InteropError`.

| Roster | Anchor | Move |
|---|---|---|
| `Test/InteropHostDescriptor.cls` | :23 | `ENDPOINTS` + `ItemTest` |
| `Test/ReadTool.cls` | :93-94 | 365 → 366, + `interop.itemtest.read` |
| `Test/Navigation.cls` | :534-535 | interop screens 18 → 19 and their order |
| `Test/SurfaceCoverage.cls` | screens 220-237, write tools 384-405 | a screen row and two tool rows |
| `Test/InteropFloor.cls` | `ADMINISTRATORSCREENS` :60, `ADMINISTRATORTOOLS` :63 | + `InteropItemTestTab`, `interop.itemtest.read` (measured: `%EnsRole_Administrator` holds `%Ens_TestingService:U`) |
| `Test/InteropDescriptor.cls` | :164 | the transforms list's row action and agent line |
| `Test/ClassicPageGate.cls` :84/:87, `Test/MappingDescriptor.cls` :24 | — | the two tools' `CLASSICPAGES` |
| `Test/ToolRoundTrip.cls` | :91 | two write tools |
| `Test/Descriptor.cls` | `XData ReadShapes` (135 rows, interop :187-204) | + an `InteropItemTestTab` row |
| `ui/tools/navigation.test.mjs` :345-373, `ui/tools/screen-mirror.test.mjs` ~:1394, :2407 | — | route, criteria and own-pair owners |
| `ui/browser/structural-walk.mjs` | `SKIP` :97 | the Test tab route |
| `scripts/ci-throwaway.sh` | after :462 | a `# classes:` line for the new armed classes (held by `ui/tools/ci.test.mjs`) |

Unchanged: `EntityType` (73), `EndpointCoverage`, `SaveHoldCoverage`, `DraftRegistry`, and the disabled-key rosters (both keys ship `true`).

### Fixtures and vendor (read only)

- `src/OcuPilot/Test/ProductionProbe.cls`:
  - USER, package `OcuPilotProbe.Interop`.
  - Entry points: `Create` :163, `AddItem` :203, `Settle` :454, `Remove` :624.
  - It has no transformation, no response-giving operation and no `TestingEnabled`.
- `InteropJobEnd.StartUpdated` :66 waits for a started production's own update.
- `irislib/EnsLib/Testing/Service.cls`: `SendTestRequest` :34. It calls `DisplayError` on failure (:55).
- `EnsLib/Testing/Process.cls`: AppData `Waiting` :25, `Done` :39-46, `Error` :60-63.
- `EnsLib/Testing/Request.cls`.
- `Ens/Director.cls`: `CreateBusinessService` :1451-1530 (the TCP device mode change and outside-job registration are undone in `OnTearDown`); the auto-added testing items only when `TestingEnabled` :765, :869-910.
- `EnsPortal/TestingService.cls`: `RESOURCE` :19, BP and BO only :68-69/:150-177, `GetIsTestingEnabled` :122-139.
- `EnsPortal/Dialog/TestingService.cls`:
  - `GetValidRequestTypeList` :196-231
  - `SaveRequestMessage` :388-442 (`%ValidateObject`, `%Save`)
  - the send :505-509
  - the result render and AppData kill :556-586
- `%CSP/Util/AutoFormGenerator.cls`:42-106: the settable-property rule (datatype, and embedded serial expanded; not references, collections, streams, Internal, Private, MultiDimensional, ReadOnly or Calculated; at most 100).
- `EnsPortal/Dialog/TestTransform.cls`:
  - `RESOURCE` :11
  - types :274-300
  - `create="existing"` :449-459
  - `process` and `context` :466-494
  - the call :502
  - the render :505-569 and :609-636
  - the persisted-object cleanup :571-599
- `Ens/DataTransform.cls`:14-67 and `DataTransformDTL.cls`:31-180 (`Transform` has `PublicList = (process, context)`).
- `Ens/Util/XML/Reader.cls`:166.
- The hidden `Ens.Util.Serialized.Reader` (read from the instance at this plan): its `ObjectFromSerialized` sends an `EnsLib.EDI.Document` subclass to `ImportFromString` and an `%XML.Adaptor` class to `Ens.Util.XML.Reader.ObjectFromString`, and every method is `[Internal]`.

## Tasks & Acceptance

**Execution.** Part A is the host test and Part B the transformation test. The split seam is between them (Design Notes › Split): Part B's tasks, ACs and tests move as one block.

- [ ] **Task 0** (`ocupilot-b-ci` only, through `docker exec`; remove what it creates). Record each item as a `Task 0:` line under Verification:
  - `%SYS.Portal.Resources.NormalizePage` spells `EnsPortal.TestingService`, `EnsPortal.Dialog.TestingService` and `EnsPortal.Dialog.TestTransform` as written.
  - Find the read that tells whether the running production has registered the testing service, the condition `CreateBusinessService` checks. Prefer a documented one, such as `Ens.Util.Statistics:EnumerateHostStatus` listing `EnsLib.Testing.Service`. If none answers, use `$$$DispatchNameToConfigName("EnsLib.Testing.Service")` from `Ensemble.inc`, as the vendor does. Either way, a vendor status of `EnsErrBusinessDispatchNameNotRegistered` naming the service also maps to `INTEROP.TEST.DISABLED`.
  - Inside the screen action route, `SendTestRequest` under the capture leaves the HTTP answer intact JSON, both when it succeeds and when it fails with `DisplayError`. If the capture cannot coexist with `CreateBusinessService`'s device change, the port makes the three documented calls `SendTestRequest` makes (`EnsLib.Testing.Request`, `Ens.Director.CreateBusinessService`, `ProcessInput` with `%SessionId`) without `DisplayError`. Record which.
  - A transformation's device write is captured, and the route answer stays JSON.
  - An X12 target renders through the call the classic page uses (`TestTransform.cls`:505-569).

**Part A: the host test.**

- [ ] `src/OcuPilot/Port/InteropPort.cls` (extend):
  - **Endpoint.** `ItemTest`, which joins `ENDPOINTS` and `Serves` with `LIST`, `TESTTARGET` (read, composed) and `SENDTEST` (write). Its pairs are `TESTPAIRS` = `%Ens_Portal:USE,%Ens_TestingService:USE`.
  - **Predicate.** `IsTestWrite` joins both `tWrite` lines, or the shared helper. WRITE on the globals database, no routines database. `COMPOSEDTYPES` gains `ItemTest/SENDTEST`.
  - **Keys.** `REQUESTCLASSKEY` `requestClass` and `FIELDSKEY` `fields`.
  - **`LIST`** (`item` criterion through `ItemParts` and `ResolveItem`): the item's class from the stored production, then its request classes, built as `GetValidRequestTypeList` does.
    - A BP or BO (`GetBusinessType`) yields rows as the matrix says, with fields from the class dictionary only (AutoFormGenerator's rule, at most 100 per class, serial fields dotted). Any other type yields zero rows.
    - It is capped at `maxRows` and the read bounds (AD-36). It runs no request class's code and writes nothing.
  - **`TESTTARGET`** answers `{Namespace, Production, Name, Type, Enabled, State, Testing, RequestClass, Kind, Fields, RequestValid}`, where `Fields` is the values' canonical JSON.
    - With `ACTIONKEY`, it refuses in this order: production not running (`INTEROP.PRODUCTION.NOTRUNNING`, also when the running production is another); `DISABLED`; `TARGETTYPE`; `TARGETDISABLED`; `REQUESTTYPE`; `SECRET`.
    - Violations are 422 `FIELD` and `VALUE`: an unknown or unsettable member; a value whose `<Prop>DisplayToLogical`, then `<Prop>IsValid`, fails; a required field left empty. A document class takes exactly one member, `content`.
  - **`SENDTEST`** (`PerformTest`): re-run the composed read and its refusals, then build the request.
    - **Build.** For an object class: `%New()`, set each field (serial fields by their path), `%ValidateObject()`. For a document class: `ImportFromString(content)`. Then `%Save()`. Any failure is 422 `INTEROP.TEST.REQUEST`, with the vendor text in the log only.
    - **Send.** Under the capture, `SendTestRequest(Name, request, , .session)` through a seam `VendorSendTest`.
    - **Wait.** Poll the session's AppData top node every 250 ms up to `TestWait()` (a seam, `TESTWAIT` 15).
    - **Done.** Open the response from its `response` `$LB(class, id)`. Collect each datatype or serial field's value, or a document's `OutputToString`. Credential-named fields read blank, values are capped at 1,000 characters and the total at 1,000,000, marked cut. Then kill the node.
    - **Error.** The `error` status text, then kill the node.
    - **Waiting.** Leave the node.
    - **Finish.** Restore the namespace, compose the result, then `AuditRuntime("test", "production-item", id, {Namespace, Production, Item, RequestClass, SessionId, Status})`.
  - **Snippet.** `TestSnippet` renders the namespace switch, the request's build lines through `Literal`, the `%Save`, and the `SendTestRequest` call. It is wired through `SnippetForm` and `Snippet` (AD-59).
  - **Header.** The write and seam lists gain the host test, `VendorSendTest` and `TestWait`.
- [ ] `src/OcuPilot/Api/InteropError.cls`: `TestCodes()` and `TestPreconditionCodes()` join `Codes()` and `ReasonFor`.
  - Refusals:
    - `INTEROP.TEST.DISABLED`: "Testing is not enabled for this production. Turn on Testing Enabled in the classic production settings, then update the production."
    - `TARGETTYPE`: "Only a business process or a business operation takes a test request."
    - `TARGETDISABLED`: "This item is disabled, so a test request would wait in its queue with no answer. Enable it first."
    - `REQUESTTYPE`: "This host does not take that request class. Its Test tab lists the ones it takes."
    - `SECRET`: "This field names a credential, so OcuPilot sends no value for it. Leave it empty, or test in the classic Testing Service page."
  - Violations:
    - `FIELD`: "The request class has no such field that a test can set."
    - `VALUE`: "This value does not fit the field, or the field is required."
    - `REQUEST`: "The request could not be built from these values."
  - Consequence `INTEROP.TEST.SENDS`, which joins `ConsequenceCodes()`: "A test sends a real message through the running production. The target runs it, and anything it sends on, to another host or outside this instance, is sent too. The test's messages stay in the message store."
- [ ] `src/OcuPilot/Screen/Tool/InteropItemTestSend.cls` (new), `interop.itemtest.send`, extends `InteropItemAction`:
  - Declarations:
    - `DESCRIPTORCLASS` `InteropItemTestTab`, `READTYPE` `TESTTARGET`, `WRITETYPE` `SENDTEST`, `READSVALUES` 1, `SENDSBODY` 0
    - `SCREENACTIONS` `test`, `SCREENVALUES` `test=requestClass:fields`, `ROUTINESDATABASE` 0
    - `WRITERESOURCE` `%Ens_TestingService` and `WRITEPERMISSION` `USE`
    - `STATEMARKER` `Testing`, `STATEFIELD` and `PRECONDITIONFIELD` `State`
    - `FINGERPRINTSUBJECT` `Namespace,Production,Name,Type,Enabled,State,Testing,RequestClass,Kind,Fields`
    - `PRECONDITIONCODES` the six refusals, `CONSEQUENCECODE` `INTEROP.TEST.SENDS`, `DESTRUCTIVE` 0
    - `CLASSICPAGES` `EnsPortal.Dialog.TestingService`, `CHANGEACTION` `updated`
  - Agent arguments are `Production`, `Name`, `RequestClass` and `Fields`, an object of strings whose JSON is at most `ExplorerSave.#CHANGEMAXLENGTH` characters (`ArgumentProblem`). The screen's `fields` text is at most `AtelierPort.#MAXIMPORTCHARACTERS` (`ScreenActionDelta`, as `ExplorerSqlRun`'s parameters).
  - `StateDiff` rows are `RequestClass` and `Fields` only, so `PermittedChangeFields("production-item")` gains them (add-only, `Prohibited.cls`).
  - `CallSecretNames` names `Fields` when any member is credential-named.
  - `WriteOutput` answers `{status, sessionId, responseClass, lines, errors}`, never `outcome`.
- [ ] `src/OcuPilot/Screen/Descriptor/InteropItemTestTab.cls` (new), copying `InteropItemJobTab`'s shape:
  - route `interoperability/productions/items/test`, `tab` position 7 with label "Test", archetype `detail`, parent `interoperability/productions/items`
  - privileges `TESTPAIRS`, `ownPrivileges` `%Ens_TestingService:USE`, entity `production-item`
  - `primaryAction` `test`, read `ItemTest` `LIST` with the matrix's fields, criterion `item`
  - columns Request class, Field, Type, Required, Max length, Values and Secret
  - three suggested prompts, an empty state, an agent line
  - `classicPage` `EnsPortal.TestingService`, `toolIdentifier` `interop.itemtest`, no refresh
- [ ] `src/OcuPilot/Kernel/Governance/Baseline.cls` (append): `"interop.itemtest.send": true`.
- [ ] Client:
  - `areas/interoperability/interop-item-test.page.ts` hosts the tab's table and the dialog, and registers `test` as undrawn. `DESCRIPTOR_PAGES` gains a row.
  - `interop-item-test-dialog.ts`:
    - a request-class select over the tab's rows
    - one field per row, with `Values` as a select, `MaxLength` as the bound and a `Secret` field drawn disabled with its sentence
    - a `document` class gets one multi-line field
    - Send through `handler.sendFor('test', item, {requestClass, fields})`
  - The result renders in the dialog from `lastOutput()`: the status sentence (strings), the session id, and the lines through `app-code-block` or `<pre>` interpolation, never markup.
  - `core/test-answer.ts` (new, sibling of `core/sql-answer.ts`) maps a test output's `status` to its fixed sentence followed by `lines`. `outputLinesOf` gains that branch (add-only) for an output carrying a string `status` and a `lines` array.
  - `screen-action-handler.ts` (add-only): `SCREEN_ACTION_DESCRIPTORS` and `UNDRAWN_ACTIONS`.
  - `strings.ts` (add-only) and the regenerated `screens.generated.ts`.
- [ ] `src/OcuPilot/Test/InteropTestFixture.cls` (new, not a TestCase). It extends or calls `ProductionProbe` without changing `Create`'s loop, so that probe's consumers stay unchanged. It:
  - creates in `OcuPilotProbe.Interop` a request class `TestRequest` (an `Ens.Request` with `Text` (`MAXLEN` 50), `Count` (`%Integer`), `Kind` (`VALUELIST`), `Password`, `Address` (serial `TestAddress`, with `City`), and a `%OnNew` that sets `^OcuPilotProbeInteropNew`), an `EchoOp` that answers `Ens.StringResponse` `echo:<Text>` for it and for `Ens.StringRequest`, and Part B's DTLs
  - adds `EchoOp` to the probe production through `ProductionProbe.AddItem`
  - sets and clears the stored production's `TestingEnabled` the way `AddItem` changes stored configuration
  - removes all of it in teardown, `^OcuPilotProbeInteropNew` included
  - A test starts the production through the port and waits on `InteropJobEnd.StartUpdated` and on the testing service's registration before it sends.
- [ ] Tests (new, each under about 500 lines, one class per call, armed with the interop block):
  - **`Test/InteropTestDescriptor.cls`:**
    - the tab, the three tools and their declarations
    - `Pairs`, `Serves`, `ENDPOINTS`, keys `true`, the code lists
    - both `Snippet` forms, with a quote and a control character kept inside the literal
    - `CallSecretNames`
    - `WriteOutput` never answering `outcome`
  - **`Test/InteropHostTest.cls`:**
    - the tab's rows through the port, the screen read route and the read tool (same rows): serial, `VALUELIST`, `MAXLEN`, required, `Secret`; the service's zero rows
    - the reads leave the stored production and the message store unchanged
    - the person's send and the agent's mint and confirm, over HTTP: response lines, session id, AppData node gone, the item's Messages tab listing the session's messages, the `ConfigChange` row without a field value, the change event
    - a target with no response; the `waiting` leg, at the port through `InteropItemSeam` (which overrides `TestWait` to 1, armed as its other seams are) against the probe op hanging 5 s (`ProductionProbe.SetHang`), elapsed under 3 s
  - **`Test/InteropHostTestRefusals.cls`:**
    - each refusal and violation from both callers, with the message header count and the `TestRequest` extent unchanged
    - a confirm refused target-changed after the item is disabled between mint and confirm
    - at the port through `InteropItemSeam`, a `VendorSendTest` that writes to the device and fails: the port answers the mapped refusal, and the captured text is logged (`LogFault`), never answered
  - **`Test/InteropTestGate.cls`** (reusing `InteropItemGate`'s `FailedPair` and `LegText`): a principal holding exactly each surface's pairs reads, sends and runs; dropping each pair, or holding READ only on the globals database, is refused by name before any vendor call, through the port, the tools and the screen routes (both parts).
- [ ] Roster sweep (Rule 30): every row of the roster table. Each changed file joins the `(loop)` set.
- [ ] `ui/browser/interop-item-test.browser-spec.mjs` (new). `before` and `after` follow `interop-items`', each test arranging its own production state. After `waitForMapAnswered`:
  1. An item's name cell opens its tabs, and Test lists the echo op's request classes.
  2. Send builds the request from the fields and shows `echo:` in the result. A `Text` of `<b>x</b>` shows literally: no `b` element is drawn.
  3. A credential field is drawn disabled.

**Part B: the transformation test.**

- [ ] `InteropPort.cls` (extend):
  - **Types and pair.** `Transforms` serves `TRANSFORM` (read, composed) and `TRANSFORMTEST` (write). The pair `DTLTESTPAIR` `%Ens_DTLTest:USE` is added to `CODEPAIRS` for both. `IsTestWrite` gains `TRANSFORMTEST`, and `COMPOSEDTYPES` gains `Transforms/TRANSFORMTEST`.
  - **`TRANSFORM`** answers `{Namespace, Name, SourceClass, SourceDocType, TargetClass, TargetDocType, Create, Source, content}` for a class `ListClasses` lists (else 404), through the classic dialog's four calls. `Source` is `document` (an `EnsLib.EDI.Document`) or `xml` (an `%XML.Adaptor`).
    - With `ACTIONKEY`, it refuses `SOURCEFORMAT`, then `TARGETFORMAT` (the same test on the target).
    - `content` must be 1 to `MAXIMPORTCHARACTERS` characters (`CONTENT`).
  - **`TRANSFORMTEST`** (`PerformTransformTest`): re-run the composed read, then do the rest switched and under the capture:
    - **Parse.** A document source's `ImportFromString`, or `Ens.Util.XML.Reader.ObjectFromString(.source, content, SourceClass)`.
    - **Target.** For `create="existing"`, as the classic page creates it.
    - **Run.** `New process, context`, set both `""`, then `$ClassMethod(Name, "Transform", source, .target)`. A fault is trapped as status `transform`.
    - **Render.** A document's `OutputToString` (or the classic page's call, Task 0), or `%XML.Writer` with `Indent` 1 through `OutputToString`/`RootObject`, split into lines and capped at 1,000,000 characters, marked cut.
    - **Clean up.** Delete a source or target that gained an `%Id()` during the test.
    - **Finish.** Restore, compose `{status, sourceClass, targetClass, lines, console, errors}`, then `AuditRuntime("test", "class", Name, {Namespace, SourceClass, TargetClass, Status})`.
  - **Snippet.** `TestSnippet` gains the parse, the `Transform` call and the render.
- [ ] `InteropError.cls`:
  - `INTEROP.TRANSFORM.SOURCEFORMAT`: "OcuPilot reads a pasted source only as an HL7 or other EDI document's text, or as XML. This transformation's source is neither, so test it in the classic portal."
  - `TARGETFORMAT`: "OcuPilot shows a target only as an EDI document's text or as XML. This transformation's target is neither, so test it in the classic portal."
  - `CONTENT` (violation): "Paste the source message, at most 3,000,000 characters."
  - Consequence `INTEROP.TRANSFORM.RUNS`: "The transformation's code runs on this instance as you, on the input shown. Whatever it writes or sends, it writes or sends."
- [ ] `src/OcuPilot/Screen/Tool/InteropTransformTest.cls` (new), `interop.transforms.test`, extends `InteropAction`:
  - Declarations:
    - `DESCRIPTORCLASS` `InteropTransformList`, `READTYPE` `TRANSFORM`, `WRITETYPE` `TRANSFORMTEST`, `READSVALUES` 1, `SENDSBODY` 0
    - `SCREENACTIONS` `test`, `SCREENVALUES` `test=content`, `IdArgument` `Name` (the list's `<class>.cls`)
    - `WRITERESOURCE` `%Ens_DTLTest` and `USE`, `DATABASEPERMISSION` WRITE
    - `STATEMARKER` and `PRECONDITIONFIELD` `SourceClass`
    - `FINGERPRINTSUBJECT` `Namespace,Name,SourceClass,SourceDocType,TargetClass,TargetDocType,content`
    - `PRECONDITIONCODES` the two formats, `CONSEQUENCECODE` `INTEROP.TRANSFORM.RUNS`, `DESTRUCTIVE` 0
    - `CLASSICPAGES` `EnsPortal.Dialog.TestTransform`
  - The agent's `content` is at most `CHANGEMAXLENGTH`.
  - `StateDiff` rows are `Transform`, `Source`, `Target` and `Input`.
  - `WriteOutput` answers the result, never `outcome`.
- [ ] `src/OcuPilot/Screen/Descriptor/InteropTransformList.cls` (in place, Epic 20's own): `rowActions` `[test]`, and its table's `emptyNextKey` `tableReadOnlyEmptyNext` (:59) becomes an `emptyAgentKey` of its own (:60). Data transformations becomes write-capable, so its empty state gains the line inviting the agent.
- [ ] `InteropPort` gains nothing else on `ListClasses`: its rows and Business processes are unchanged.
- [ ] `Kernel/Governance/Baseline.cls` (append): `"interop.transforms.test": true`.
- [ ] Client:
  - `areas/interoperability/interop-transform-list.page.ts` (new) hosts `<app-list-page />` and the dialog, and registers `test`. `DESCRIPTOR_PAGES` gains a row.
  - `interop-transform-test-dialog.ts` has the transformation's name, one multi-line Input with a sentence naming the formats, and Run. The result shows its source and target class, the status sentence, and the lines and console through `app-code-block`.
  - `test-answer.ts` covers its statuses.
  - The handler maps and strings follow as in Part A.
- [ ] `InteropTestFixture` adds `OcuPilotProbe.Interop.Dtl` (`TestRequest` to `Ens.StringResponse` `out:<Text>`; for `Text` `fail` a `<code>` returning an error, for `write` a `<code>` that writes a line to the device, for `save` a `<code>` that saves its target) and `Hl7Dtl` (`EnsLib.HL7.Message` `2.5:ADT_A01` copy, setting `MSH:SendingApplication`).
- [ ] Tests:
  - **`Test/InteropTransformTest.cls`** (new, armed). Each leg goes through the screen route and through the agent's mint and confirm over HTTP:
    - XML and HL7 runs whose output lines are the target
    - the `fail`, `write`, `save` and unparsable legs
    - `SOURCEFORMAT`, `TARGETFORMAT`, `CONTENT` and not-a-transformation, with no `Transform` call
    - the `ConfigChange` row with no content
    - the message body tables unchanged
    - the `TRANSFORM` read writing nothing
  - Part B's legs join `InteropTestDescriptor` and `InteropTestGate`.
- [ ] `ui/browser/interop-transform-test.browser-spec.mjs` (new): Data transformations lists the probe DTL; Test opens the dialog; pasted XML runs and shows `out:`; the `fail` input shows the error lines.
- [ ] `EXPERIENCE.md`, no line inserted above :604:
  - :159's tab order gains " · Test", and the sentence says Data transformations' rows can be tested.
  - :173 gains "send a test request to a business process or operation (an item's Test tab, Story 20.6: the request class, its fields and the result)" and "test a data transformation (Data transformations, Story 20.6: pasted input, Run, and the output)".
  - :604 gains a Story 20.6 clause naming every new literal.
  - Then run `cd ui && npm run test:tools`.

**Acceptance Criteria:**

- **AC1 (request built from the target's schema, integration):** Given the probe production's echo operation in USER on `ocupilot-b-ci`, when its Test tab renders, then the rows list each request class the operation takes with its settable fields, and the port, the screen read route and `interop.itemtest.read` answer the same rows. A business service lists none.
- **AC2 (host test, both callers):** Given the probe production running with testing enabled, when a person sends a request built in the Test dialog, and when the agent proposes one and the person confirms, then:
  - one `EnsLib.Testing.Service` test is sent per action, and the dialog and the card show its session id, its status and the response's fields
  - the item's Messages tab lists that session's messages
  - a `ConfigChange` row records the test with no field value
- **AC3 (host refusals):** Given each host refusal and violation of the matrix, when either caller attempts it, then it is refused by its code before any vendor call and no message header is added.
- **AC4 (bounded wait):** Given a target that does not answer within `TESTWAIT`, when it is tested, then the request answers `waiting` with the session id within the cap.
- **AC5 (transformation test, both callers):** Given a probe transformation and pasted XML or HL7, when a person runs the test, and when the agent proposes it and the person confirms, then:
  - the transformation runs once in the caller's process, and its target renders as text in the dialog and on the card
  - the card shows the input and the consequence before Confirm
  - nothing the test parsed or produced is left stored
  - the key ships `true`
- **AC6 (transformation outcomes):** Given input that does not parse, a transformation that fails, or one that writes to the device, when it is tested, then the status and lines say so, and the HTTP answer stays a JSON envelope.
- **AC7 (gates):** Given a principal missing one declared pair of a new surface, or holding READ only on the globals database, when it reads, sends or runs, then it is refused naming that pair before any vendor call. A principal holding exactly the pairs succeeds (the vendor checks nothing, measured).
- **AC8 (results are screen data only):** Given a host result and a transformation's output, when either is shown, then it renders as text, never markup. It reaches no turn's model messages, ledger row, audit payload, log line or screen context.
- **AC9 (reads change nothing):** Given the Test tab read and the composed `TESTTARGET` and `TRANSFORM` reads, when they run, then the stored production, the message store and `^EnsHL7.Segment` are unchanged.

## Spec Change Log

- 2026-10-12, spec gate (lead): rulings under Design Notes › Gate rulings (Q1 asked, `GetMessageList` documented-first); spine drafts written.

## Review Triage Log

## Design Notes

**Governing ADs:**

- AD-62 (the port, its gate and calls)
- AD-29 and AD-8 (pairs and narrower audiences), AD-44 (classic pages)
- AD-13 (`production-item` and `class` ids, reused), AD-36 (the tab's read), AD-24 and AD-60 (the tab rows' bounds and sanitizer)
- AD-35 (credential-named fields)
- AD-22 (both keys `true`), AD-6 and AD-51 (port-composed fresh reads, a port-built vendor call, declared fingerprint subjects), AD-53 and AD-56 (two callers, declared screen values)
- AD-58 (`nothingSent`), AD-59 (snippets)
- AD-10 (the `production-item` reviewed-few sweep; the `class` code arm judges a transformation by name)
- AD-14 (change events), AD-15 (OcuPilot's own audit row), AD-34 (the per-target hold, taken in the shared `Operation`)
- AD-16 (the switch), AD-7 (each write in its request; the bounded wait)
- AD-5 and AD-3 (descriptors, derived lists), AD-64 (the tab is adjustable), AD-43 (no refresh), AD-30 and AD-40 (the agent's switches gate only its caller)
- AD-39 (a new exception for test results), AD-47 and AD-11 (rendered as text, never evaluated), AD-21 (pasted text only, no path)

Checked and not engaged: AD-26 and AD-27 (no admin API, no 202 path), AD-57 (no try-it console; its "the response is data" rule is mirrored by the AD-39 exception), AD-54 (no create), AD-55 (no Save route, so DW-1882's `SaveHoldCoverage` is unchanged), AD-63 (no embed). DW-2096 is not engaged: there is no statement text, and a credential-named field is refused before any snippet could carry it.

**Measured at this plan on `ocupilot-b-ci`.** In USER: a probe production with testing enabled, an echo operation (enabled and disabled copies), two DTLs, and a principal holding `%Ens_Portal:U` and `%DB_USER:RW`. All were removed afterwards, with every message, log row, AppData node, class, user and role they made.

- **The vendor checks no privilege.** The principal, holding neither test resource, ran `SendTestRequest` (answered `echo:t1`) and `Transform`.
- **AppData.** A test's top node reads `Waiting`, then `Done` or `Error`, with `time`, `error` and `response` (`$LB(class, id)`).
- **What a test leaves.** One test left 3 headers, the saved request body and the `EnsLib.Testing.Request` wrapper.
- **Disabled target.** The session stayed `Waiting`, with 2 headers and the message in its queue.
- **Unknown target.** `SendTestRequest` returned OK, and the session turned `Error` later (`ErrBusinessDispatchNameNotRegistered`).
- **Stopped production.** `SendTestRequest` returned `ErrBusinessDispatchNameNotRegistered` for `EnsLib.Testing.Service`, and `DisplayError` wrote that text to the current device.
- **Transformation, XML source.** `Ens.Util.XML.Reader.ObjectFromString` into `Ens.StringRequest`, the transform and `%XML.Writer` persisted nothing. Non-XML input answered #6301.
- **Transformation, HL7 source.** `ImportFromString` wrote one node per process in `^EnsHL7.Segment`, which stayed after the objects went, and process-private `^||EnsHL7.OpenSegment` nodes, which went. `OutputToString` rendered the transformed message.
- **Stock roles.** `%EnsRole_Administrator` holds `%Ens_Code:R`, `%Ens_DTLTest:U` and `%Ens_TestingService:U`. `%EnsRole_WebDeveloper` holds `%Ens_Code:RW` and both test resources. `%EnsRole_Operator` and `%EnsRole_Monitor` hold neither.
- **Message body classes.** Non-abstract message body classes: USER 91 (7 virtual documents), HSCUSTOM 326.

**Decisions:**

- **Posture** (each equal to the classic page or stricter, so no owner question; the lead's gate may still rule):
  - **Host test.** The classic page needs `%Ens_TestingService:USE`, a running production and its Testing Enabled. OcuPilot adds the floor pair and WRITE on the globals database, which the test's `%Save` needs. It also refuses a disabled target, a request class outside the target's list, and a target that is not the running production's BP or BO, all of which the classic dialog sends unchecked (inference from its source, `Dialog/TestingService.cls`:501-505).
  - **Transformation test.** The classic dialog needs `%Ens_DTLTest:USE` and runs any class with a compiled `Transform`. OcuPilot adds `%Ens_Code:READ` and WRITE on the globals database, and runs only a listed `Ens.DataTransform` subclass.
- **Not destructive, keys ship `true` (AD-22).** Neither test deletes or replaces anything. The host test needs the production's own Testing Enabled, the operator's opt-in, and the transformation test runs existing code on the agent's input. Each card carries a consequence sentence naming the real effect: a sent message, and code that runs as the person.
- **The result never reaches the model.** This follows Stories 19.6 and 19.11: the output rides the confirm response to the card only (`Confirm.cls`:518-521), and a new AD-39 exception names it. The agent sees its proposal confirmed, not the output.
- **Pasted input, documented parsers.** The classic dialog's parser is `[Hidden]` and `[Internal]`. OcuPilot calls the two documented methods it dispatches to. Record Map, batch and other non-XML sources are a named narrower audience (`SOURCEFORMAT`).
- **The tab lists fields, not one row per class.** A router takes any persistent message (`%Persistent`), so its list is every message class the namespace holds. Past the read's bound the list is cut and says so (AD-24), with the target's own classes first. This is a named limit.
- **The visual trace is Story 20.9's.** The result shows the session id that the trace needs.
- **Rule 31:**
  - `InteropItemTestSend` extends `InteropItemAction` (composite id, the mint, the production argument).
  - `InteropTransformTest` extends `InteropAction`.
  - `PerformTest` and `PerformTransformTest` follow `PerformJobAction`'s order and reuse `AuditRuntime`, `Literal` and the refusal helpers.
  - The capture is `AtelierPort`'s mechanism, called the same way rather than copied as code.
  - `ScreenActionDelta` follows `ExplorerSqlRun`'s JSON-text argument, and `CallSecretNames` follows `InteropLookupEntryAction`'s.
  - The fixture calls `ProductionProbe.AddItem` and `InteropJobEnd.StartUpdated`.
  - `test-answer.ts` is a sibling of `sql-answer.ts`, because the two outputs differ in shape.
- **No new error code in `Api/Error.cls`** (989 of 1,000).

**Split (`multiple-goals`; recommended).** Part A, the host test, is a tab, its read, a dynamic request form, a send and a bounded wait over AppData. Part B, the transformation test, is a row action, a composed read, a parse, the run and the render. The seam is clean: they share only `IsTestWrite`, the code family, the AD-39 exception and `test-answer.ts`, which Part A introduces and Part B extends. Each part brings two or three ObjectScript test classes and a browser spec. Story 20.5, kept as one story, reached 95 KB of spec and 65 review rows.

**Gate question (for the orchestrator):**

- **Q1, split:** (A) Part B becomes its own story, numbered by the lead (Rule 5 ask-first, because it defers the second AC). Recommended. (B) One story. Without a ruling, this spec stays one story: Part A first, then Part B.

**Gate rulings (lead, 2026-10-12):**

- Q1: asked of the orchestrator. Until it rules, this spec stays one story: Part A first, then Part B. If the handoff or the review finds the story oversized, HALT `blocked` with `split: Part B` so the lead charters it.
- `GetMessageList`: prefer listing the target's request classes from documented class metadata (the class dictionary), as AD-62 item 1 asks. Call the dialog's `[Internal]` `GetMessageList` only if that proves infeasible, and say why in Auto Run Result; AD-62 item 11 names that call as a limit.
- The spine drafts are written: AD-62 item 11, AD-51, AD-39's seventh exception, AD-36, AD-44, AD-8, AD-15 and AD-7.
- Bundle: no re-base expected. If the build crosses `maximumWarning` (3527kB), re-base under DW-1166 as Story 20.5 did.

**Spine drafts (Rule 20; the runner writes them at the spec gate):**

- **AD-62 item 11, "Host and transformation tests (Story 20.6)":**
  - `InteropPort` gains `ItemTest` (`LIST` with one `item` criterion, `TESTTARGET`, `SENDTEST`), and `Transforms` gains `TRANSFORM` and `TRANSFORMTEST`.
  - The host test calls `EnsLib.Testing.Service.SendTestRequest` asynchronously, reads the request class list through the classic dialog's `[Internal]` `GetMessageList`, and reads and clears the test's `$$$EnsRuntimeAppData`, as the classic dialog does. It waits at most 15 s, then answers `waiting`.
  - The transformation test parses pasted text with a virtual document's `ImportFromString` or `Ens.Util.XML.Reader.ObjectFromString`, never the `[Hidden]` serialized reader, and runs `Transform` in process with empty `process` and `context`.
  - Both refuse by name, before any vendor call, the conditions the vendor answers silently or writes to the device about, and run their vendor calls inside the output capture. Neither is destructive.
- **AD-51:** "Story 20.6's case: `InteropPort` builds a host test's request from the tool's declared `RequestClass` and `Fields`, and a transformation test's source from its declared `content`, and answers their fresh reads through port-composed `TESTTARGET` and `TRANSFORM` types."
- **AD-39, the seventh exception:** "A host test's response and error lines, and a transformation test's output, error and console lines (Story 20.6), reach the screen and the proposal card only, as text, and never the model, a tool result, a ledger row, an audit payload, a log line or screen context."
- **AD-36:** the Test tab is a parent-scoped `interop` list (`item`) of request-class fields, read from the class dictionary. A credential-named field reads `Secret` true.
- **AD-44:** the Test tab declares `EnsPortal.TestingService`. The tools' `CLASSICPAGES` are `EnsPortal.Dialog.TestingService` and `EnsPortal.Dialog.TestTransform`.
- **AD-8:**
  - `%EnsRole_Administrator` and `%EnsRole_WebDeveloper` hold both test resources.
  - Both tests need WRITE on the globals database, and the transformation test needs `%Ens_Code:READ`: each is a named narrower audience than the classic dialog's.
- **AD-15:** "Named case 2026-10-11 (Story 20.6): host and transformation tests record OcuPilot's own `ConfigChange` from either caller."
- **AD-7:** the HL7 parse writes the vendor's per-process `^EnsHL7.Segment` node, as the classic dialog's parse does. A transformation's own code has no cap beyond the gateway's timeout (named limit).

**Integration ACs, Consumes, Consumed-by:**

- Integration: AC1, AC2 and AC5 run against `ocupilot-b-ci` through the screen routes, the agent's mint and confirm, and the browser specs. AC2's Messages-tab leg is Story 20.4's consumer reading what this story's write leaves.
- Consumes:
  - 20.2: the port, Data transformations, `CODEPAIRS`
  - 20.3: `InteropItemAction`, `InteropItemMint`, `ItemParts`, `ResolveItem`, the gate helpers
  - 20.4: the tab group and the Messages tab
  - 20.22: the secret-name rule
  - 20.23: `AuditRuntime`
  - 19.6 and 19.11: `WriteOutput` and the card output
  - 20.17: card collapse
  - `AtelierPort`'s capture
- Consumed-by:
  - 20.9, which renders the session id's visual trace
  - 20.12, whose guided workflows may propose a test (inference)
  - 20.16, whose DTL edits a test can check (inference)

**Ledger inbox (Rule 17):** empty.

**Contended files (Rule 11).** `origin/OCU-1-epic18`'s tip is already an ancestor of this branch, so nothing contended has moved since the merge base. A local, unpushed `OCU-1-epic18` changes `Test/ReadTool.cls`'s count, `Test/Descriptor.cls`, `Test/SurfaceCoverage.cls`, `screens.generated.ts`, `strings.ts` and one EXPERIENCE.md line, all by additions the forward merge sums (Rule 22).

This story's edits to `Prohibited.cls` (`PermittedChangeFields` entries), `Baseline.cls`, `strings.ts`, `screen-action-handler.ts`, `turn.ts`, EXPERIENCE.md, `ci-throwaway.sh` and the roster tests are additions or count pins. In-place edits are Epic 20's own: the port, `InteropError`, `InteropTransformList`, `InteropFloor`, `InteropDescriptor` and `Navigation.cls`.

**Strings and weight.**

- **Strings:** about 55 literals (Part B about 20), taking the count from 3,214 to about 3,270. That stays under the 3,350 point that triggers raising the 3,400 bound.
- **Weight:** about +20 to 30 kB, a page, two dialogs, the mirror and strings (inference). That is on 3,358,630 bytes against `maximumWarning` 3,527 kB, so no re-base is expected. If the built total crosses, apply DW-1166: 5% above the measured total in `angular.json` and the pin in `ui/tools/angular-json.test.mjs`. Stop above 3,800 kB.

## Verification

**Shared surfaces:**

- the item tab strip (+Test) and the navigation count, 18 to 19
- the interop `ENDPOINTS` literal and the read-tool roster (+1)
- Data transformations' row actions and empty state
- `SurfaceCoverage`, `ToolRoundTrip`, `ClassicPageGate` and `MappingDescriptor`'s classic roster
- the governance baseline (+2 keys, both `true`)
- `Prohibited`'s `production-item` permitted fields
- the `InteropFloor` administrator rosters
- `InteropDescriptor`'s transforms pin
- the screen mirror's criteria and own-pair owners
- the structural walk's `SKIP`
- the Fixed-strings row, the dialog list and the tab-order sentence
- the arming lines in `ci-throwaway.sh` and `ci.test.mjs`
- the stored probe production's `TestingEnabled`, which the fixture sets and clears

*Existing tests that assert a surface this story changes are updated in this story. Every test the story adds or changes passes on a freshly built instance, in either order.*

**Setup (slot B):**

- `rsync -a --checksum --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-20/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`
- Then, in `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`, run `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)`.
- Before a browser run: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`.
- Never use the dev instance `ocupilot-slot-b`.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one class per call (`timeout: 600000`), each read from `%UnitTest_Result`:
  - new: `InteropTestDescriptor`, `InteropHostTest`, `InteropHostTestRefusals`, `InteropTestGate`, and Part B's `InteropTransformTest`
  - changed or consuming: `InteropHostDescriptor`, `InteropDescriptor`, `Descriptor`, `ReadTool`, `Navigation`, `SurfaceCoverage`, `InteropFloor`, `InteropFloorOwnPairs`, `ClassicPageGate`, `MappingDescriptor`, `ToolRoundTrip`, `GovernanceBaseline`, `Prohibited`, `InteropItemControl`, `InteropHostRead`, and every other class the sweep changes
- `(loop)` `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/<file>`, one file per call: `interop-item-test.browser-spec.mjs`, Part B's `interop-transform-test.browser-spec.mjs`, `interop-host-tabs.browser-spec.mjs`, and `a11y-structural-invariants.browser-spec.mjs` (DW-1337, both themes).
- `(loop)` expected clean:
  - `cd ui && npm run test:tools && npm run test:components`
  - `uv run scripts/check-objectscript.py <changed .cls>`
  - `bash scripts/lint-docs.sh`
- Runner-owned, not the implement stage's:
  - the full ObjectScript sweep on `ocupilot-b-ci`, one class per call
  - `cd ui && npm test && npm run build`, with the bundle measured against the weight note
  - `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`
  - Rule 30's fresh check
- `(CI)` the full browser suite.

**Planned pinning mutations (Rule 19):**

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | `LIST` drops subclasses, or the serial expansion | `InteropHostTest`'s rows leg |
| AC1 | A credential-named field reads `Secret` false | the same test's secret row, and the descriptor's `CallSecretNames` leg |
| AC2 | `PerformTest` skips the response read | `InteropHostTest`'s person and agent legs (no `echo:` line) |
| AC2 | `AuditRuntime` not called | `InteropHostTest`'s audit leg |
| AC2 | The AppData node is not killed | `InteropHostTest`'s node-gone leg |
| AC3 | The `TARGETDISABLED` check dropped | `InteropHostTestRefusals`' disabled leg (the session waits; a header is added) |
| AC3 | The `SECRET` check dropped | its leg, from both callers |
| AC3 | The testing-registered check dropped | the disabled-testing leg: the request is saved before the vendor refuses, so the `TestRequest` extent grows |
| AC4 | `TestWait` ignored (an unbounded wait) | the `waiting` leg: the answer is `done` after the hang, past its elapsed bound |
| AC5 | `Transform` called twice, or the XML render skipped | `InteropTransformTest`'s XML leg |
| AC5 | The cleanup of a persisted target dropped | the `save` leg's `Ens.StringResponse` extent assertion |
| AC6 | The capture removed around `Transform` | the `write` leg (the route answer is not JSON) |
| AC7 | `%Ens_TestingService:USE` dropped from `TESTPAIRS` | `InteropTestGate`'s port and route legs |
| AC7 | `DTLTESTPAIR` not appended | the same test's transformation legs |
| AC8 | `WriteOutput` answers `outcome` | the descriptor's `outcome` leg, and the card leg in a component spec of `test-answer.ts` |
| AC8 | The dialog renders lines through `innerHTML` | the browser spec's text-only assertion |
| AC9 | `LIST` calls `%New()` on a request class | `InteropHostTest`'s snapshot leg (the probe class's `%OnNew` marker global) |

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

**Plan summary.** The vendor's host-test and transformation-test paths were read, and measured on `ocupilot-b-ci`: USER, a probe production with testing enabled, two DTLs and a principal holding neither test resource, all removed afterwards.

- Neither `SendTestRequest` nor `Transform` checks a privilege.
- A disabled target's test waits forever, and a stopped production's test writes `DisplayError` to the device.
- An XML parse persists nothing, and an HL7 parse leaves one vendor segment-counter node per process.

The plan extends `InteropPort` with a per-host Test tab and a send (Part A), and a Data transformations Test action (Part B). Both are confirmed writes that are not destructive, with keys `true`, and their results reach the screen and card only, under a new AD-39 exception. The spec is flagged `oversized` and `multiple-goals`. The split question (Q1) and the spine drafts are in Design Notes.
