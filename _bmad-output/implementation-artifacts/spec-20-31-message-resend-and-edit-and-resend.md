---
title: 'Story 20.31: Message resend and edit-and-resend'
type: 'feature'
created: '2026-10-13'
status: 'done'
baseline_revision: '2f564cff76bc6fd62f3aae5aac07fac7b8c8f181'
baseline_commit: '2f564cff76bc6fd62f3aae5aac07fac7b8c8f181'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-20-9-messages-search-view-resend-and-trace.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-20-23-queue-and-job-actions.md'
warnings: [oversized, multiple-goals]
deferred: []
---

<intent-contract>

## Intent

**Problem:** To retry a failed exchange, a person still leaves for the classic Resend and Edit and Resend pages (`EnsPortal.MessageResend`, `EnsPortal.MessageResendEdit`). Those pages resend any number of messages with no dry run. Story 20.9's Messages list and Header tab only read.

**Approach:**

- **Two write tools, each reached by two callers** (AD-53), action-style over a fresh read that `Port/InteropPort` composes (AD-51, AD-62). Both reach `Ens.MessageHeader.ResendDuplicatedMessage` in process.
  - **Resend** (`interop.messages.resend`) takes a set of 1 to 100 message ids.
  - **Edit and resend** (`interop.messageheader.editresend`) takes one message id and the changed fields of its body.
- **The double gate.** The dry run is the fresh read's per-message verdicts. It sends nothing.
  - **The agent:** its proposal card is the dry run, and Confirm executes.
  - **A person:** a dialog fetches the same rows through a new `POST /screens/:screen/dryrun`. The person then confirms with the typed name, and the action carries the reviewed digest. The port refuses the action when the verdicts moved after the review.
- **Surfaces.** The Messages list gets multi-select Resend. The Header tab gets Resend and Edit and resend, through a page of its own.

## Boundaries & Constraints

**Always:**

- **Through the port** (AD-29, AD-62 (2), (3)). Every read and write goes through `InteropPort.Invoke`, switched, with no `OcuPilot.*` call while switched.
  - **The gate runs first, in this order:**
    1. the endpoint's pairs;
    2. the tool's own pairs;
    3. WRITE on the namespace's globals database.
  - Each refusal names its pair.
  - **The tools declare the same pairs**, and each is refused by name before any port call (AD-8):
    - **Resend:** `%Ens_MessageResend:USE`.
    - **Edit and resend:** `%Ens_MessageContent:USE`, `%Ens_MessageResend:USE` and `%Ens_MessageEditResend:USE`.
- **Verdicts.** The verdicts are judged before any vendor call (AD-62 (5)). A namespace with no running production is refused 409 `INTEROP.PRODUCTION.NOTRUNNING` as a whole. Each message then reads exactly one verdict, checked in this order:
  1. `gone`: no header has the id.
  2. `nobody`: the header names a body class and id, but the body no longer exists.
  3. `targetoff`: a request whose target is not an enabled item of the running production. Measured: the vendor queues such a request and answers OK.
  4. `noreplyqueue`: a response whose reply queue no longer exists.
  5. `resend`: anything else.
- **The set** is canonical per AD-13: every id matches `^[1-9][0-9]{0,18}$`, each is named once, and they run in ascending order (`interop-message:integerset`).
  - The set holds at most `RESENDMAX` (100) ids.
  - A set over the cap, or holding a malformed member, is refused 400 naming `Messages`. It is never truncated.
- **What Confirm sends.** Confirm resends exactly the messages whose reviewed verdict is `resend`, in ascending ID order, and nothing else.
  - **Agent caller:** the fingerprint covers `Verdicts`, `Production` and `Namespace`.
  - **Person caller:** sends `Reviewed`, the dry run's `Digest`. A digest that differs from the fresh read's is refused 409 `INTEROP.RESEND.CHANGED`, with nothing sent.
  - **A vendor error on one message** is recorded on that message, and the rest still go, as the classic page does.
- **An edit saves a clone, never a changed original.**
  - **An object body:** `%ConstructClone` of the original, then each changed field set along its path (20.6's field model), then `%ValidateObject`.
  - **An `EnsLib.HL7.Message` body**, as the vendor's edit does:
    1. clone it, keeping `ParentId`;
    2. `Clear()`;
    3. set `Source` to the original's plus `"; Edited copy of <id>"`;
    4. parse the text with `ImportFromLibraryStream` over a `%Stream.TmpCharacter`;
    5. set `Separators`, then `CopyValues`.
  - The vendor saves the clone as the new header's body.
- **Audit and posture** (AD-15, AD-22).
  - The vendor audits every new header with `%Ensemble/%Message/Resend` (measured), so OcuPilot records no `ConfigChange`. An agent write still carries the marker.
  - The edit's fresh read opens the body, so it records `%Ensemble/%Message/ViewContents` through `AuditViewMessage`, as 20.9's Contents read does.
  - Both tools are `DESTRUCTIVE` 1: a delivered copy cannot be undone by proposing the opposite (`Screen/Tool/Write.cls` `DESTRUCTIVE`). Both governance keys ship `false`.
  - A person's action is never asked of governance (AD-53).
- **Each write finishes in its own request** (AD-7). Measured: 100 resends took 12 ms.
- **Untrusted text.** Message names, field values and vendor error text reach a dialog or card only as interpolated text (AD-11). They reach the model only through the sanitizer (AD-60).
- **Contended files take add-only edits** (Design Notes › Contended files).

**Never:**

- No new target, no head of queue, and no "resend every match" filter. These are named limits.
- No edit of any document kind other than HL7 v2 (X12, EDIFACT, ASTM, EDI XML), of a stream, collection or object property, or of a body whose class name begins `OcuPilot` in any case. All of these are refused `INTEROP.EDIT.NOTEDITABLE`.
- No call to `ResendMessageBatch`, `Ens.Message.Search`, `ResubmitMessage`, `%ProcessSubmit` or `%Api.InteropEditors.*`. No write to a vendor global.
- No edit to `Screen/Registry.cls`, `Screen/Read.cls`, `Kernel/EntityType.cls`, `Kernel/Proposal/Prohibited.cls`, `Port/LogSourcePort.cls`, `app.routes.ts`, `angular.json`, `.github/workflows/ci.yml`, `ui/tools/ci-shards.mjs`, `ui/tools/ci-timings.json` or `ui/tools/ci.test.mjs`.
- No new screen, entity type, area or read endpoint.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Dry run | Messages list, checked `11,13,12`, all `resend` | Rows: one `Messages` row, one line per id ascending, `<ID> · <Source> → <Target>: <verdict sentence>`. `review.Digest`. Nothing sent, header count unchanged | - |
| Mixed | One `gone`, one `targetoff`, two `resend` | Four lines. The typed name is `2`. Confirm sends the two `resend` messages | - |
| None | No member reads `resend` | Nothing to confirm | Mint and dry run: 400 `TOOL.ARGUMENTS`, problem = `INTEROP.RESEND.NONE`'s sentence plus each line. At the write: 409 `INTEROP.RESEND.NONE` |
| Sent | Confirm | Each new header: same `SessionId`, `Resent` = session max + 1, Description `Resent <id>`, the same body. Output lines `<id>: resent as <new>`. Change event `interop-message` `created` | A vendor error on one gives `<id>: not resent: <text>`, and the rest go |
| Changed | Person's `Reviewed` differs from the fresh `Digest` (a target disabled after the review) | Nothing sent | 409 `INTEROP.RESEND.CHANGED` |
| Agent moved | The fingerprint differs at Confirm | Proposal closed target-changed, nothing sent | AD-6 |
| Stopped | No running production | - | 409 `INTEROP.PRODUCTION.NOTRUNNING`, before any vendor call |
| Over cap | 101 distinct ids, or a member like `0x1` | Nothing read | Mint: 400 `TOOL.ARGUMENTS`. Route and port: 400 `PORT.VALIDATION`, naming `Messages`. The command bar draws Resend refused, "Check at most 100 rows" |
| Edit form | Dry run of `editresend` with no fields | `review.Form`: the body's editable fields in 20.6's Test-tab row shape plus `Value`. A secret-path field's `Value` is `""`. An HL7 body is one `content` field, the raw view | - |
| Edit object | `Ens.StringRequest`, `{"StringValue":"new"}` | One `Body` row: `StringValue: old` → `StringValue: new`. Confirm: a new body (clone) with the new value is the new header's body. The original body is unchanged | - |
| Edit HL7 | Changed `content` text | `Body` row before and after are `ExplorerSaveMint.Hunk(old, new)`. The clone keeps `DocType`, its `Source` ends `; Edited copy of <id>`, and it carries the new segments | A text the parser refuses: 422 naming `content` |
| Edit refused | Unknown field / secret-path field / invalid value / no change / other body kind | - | 422 `INTEROP.EDIT.FIELD` / `.SECRET` / `.VALUE` naming the field. 409 `INTEROP.EDIT.NOCHANGE`. 409 `INTEROP.EDIT.NOTEDITABLE` |
| Edit verdict | The message reads anything but `resend` | - | `gone`: 404 `PORT.NOTFOUND`, unlogged. Any other: 400 `TOOL.ARGUMENTS` with the NONE problem for that one line |
| Gated | Caller lacks a declared pair | Nothing read past the gate | 403 naming the pair. The action is drawn `aria-disabled` with "Requires …" |
| Key | Agent call while the key is `false` | Denied structured result (AD-22) | Never asked for a person's action |

</intent-contract>

## Code Map

All paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-20`. Lines were read at `37342632161078b5d98ec85e2c1d0bfd198a93f2`. Stories 20.9 and 20.30 land first, so Task 0 re-anchors every 20.9 symbol (marked **(20.9)**) on their shipped code.

**Port, `src/OcuPilot/Port/InteropPort.cls`** (6,226 lines):

- **Declarations:**
  - `COMPOSEDTYPES` :181, which edit's write type joins.
  - `TESTOUTPUTMAX` :413 and `DOCUMENTFIELD` "content" :424.
  - `DIGESTKEY` (20.23).
  - **(20.9):** `MESSAGEPAIRS`, the `Messages` endpoint, the `message` id check and `MessageRow`.
- **Type predicates:**
  - `IsRuntimeWrite` :704 and `IsAnyWrite` :717. `Admit` gives WRITE on the globals database to `IsAnyWrite`.
  - `Pairs` :744-779 appends `%Ens_ProductionRun:USE` for the production `IsWrite` types, so the new type names must not reuse one.
  - `Serves` :786 and `Invoke` :884. `InvokeRuntime` :2625 dispatches to `InvokeTyped` :3308, with `IDKEY`, `ACTIONKEY` and `pType`.
- **20.23's write shape to follow:** `RuntimeRefusal` :3277, `PerformRuntime` :3437, `PerformAbortMessage` :3466, and the digest refusal `QUEUECHANGED` (:3505).
- **Scripts:** `SnippetForm` :3639, `Snippet` :3662, `RuntimeSnippet` :3706 and `Literal` :6217.
- **Reuse:**
  - `SqlRows` :3152 and `HeaderFacts` :3362 (it opens a header).
  - `ResolveItem` :2690, the item line including its effective `Enabled`.
  - `ReadState` :1179, the production's facts (its `word` is `Running`).
  - `SecretPath` :5007.
  - `IsDocumentClassHere` :4854 and `ClassFieldsHere` :4943 (the classic form's settable fields; a virtual document is one `content` field).
  - `ParseTestFields` :5121, `CanonicalFields` :5150 (drops empty members), `BuildTestRequestHere` :5388 (its field loop :5409-5432) and `RenderTargetHere` :5891 (the raw view).
- **`Api/InteropError.cls`** (581 lines): `Codes` :396, `ConsequenceCodes` :402, `RuntimeCodes` :439, `PreconditionCodes` :494 and `ReasonFor` :501. `NOTRUNNING` is at :35-37.

**Tools (`src/OcuPilot/Screen/Tool/`):**

- **`InteropAction.cls`** (the parent):
  - `READSVALUES` 1, `SENDSBODY` 0 and `DESTRUCTIVE` :35.
  - `WRITERESOURCE`/`WRITEPERMISSION` :41-43 (one own pair).
  - `STATEMARKER` :55, `CONSEQUENCECODE` :59, `IdArgument` :62, `PrivilegePairs` :89-116 and `PortQuery` :131.
- **`InteropQueueAbort.cls`**: `DESTRUCTIVE` 1, and `PortQuery` :63-67 passes the payload's `Digest` as `DIGESTKEY`.
- **`InteropItemTestSend.cls`**: `SCREENVALUES` :40, `ScreenActionDelta` :145-175 (3,000,000 cap), `ArgumentProblem` :196-223 (30,000 cap, `ExplorerSave.CHANGEMAXLENGTH`) and `WriteOutput` :267.
- **`ProcessBroadcast.cls`** with `ProcessBroadcastMint.cls`: the set-target precedent.
  - `MintClass` refuses an over-cap set before any read.
  - `StateDiff` :236-266 gives one state row for the set.
- **`ExplorerSaveMint.Hunk(old, new)`**: the changed-lines hunk, also reused by `InteropTransformTest` :125.
- **`Write.cls`**:
  - `DESTRUCTIVE` :42-52 ("a change whose effect the user cannot simply undo by proposing the opposite").
  - `FINGERPRINTSUBJECT` :76-97, `CHANGEACTION` :126-134, `SCREENACTIONS` :153-167, `READSVALUES` :175-182, `SCREENVALUES` :224-232, `SCREENOPTIONAL` :234-238 and `PRECONDITIONCODES` :507-514.

**Routes and kernel:**

- **`Api/ScreenAction.cls`**:
  - `Preview` :126 calls `Resolve` :140-212 with `pPreviewOnly`.
  - `Run` :221 stops before the prohibited set and answers `{tool, targetRef, fresh, payload, diff}` (:361-368). The preview holds nothing and writes nothing.
- **`Api/ScreenImpact.cls`**: the GET precedent for a handler.
- **`Api/Router.cls`**: routes :145-147, and the `ScreenImpact` call target :932.
- **`Kernel/EntityRef.cls`**: `IDRULES` :59 has no `interop-message` pair today, so the type is kept exactly. `RULEINTEGERSET` is the process set's rule.
- **`Kernel/Proposal/Prohibited.cls`** (not edited):
  - `COVEREDTYPES` :268 already holds `interop-message`.
  - Its branch :1713-1716 calls `ReviewedFewOnly`.
  - `Changed()` admits only the `STATEFIELD` and `FINGERPRINTSUBJECT` names (`SkippedFields` :5387-5405). So every diff row's field must be one of those.
- **`Kernel/Governance/Baseline.cls`**: `interop.*` :220-246. The last line has no trailing comma.
- **`Kernel/Audit/Event.cls` `Record`** :194 is not used. The vendor audits a resend.

**Descriptors (20.9):**

- `Screen/Descriptor/InteropMessageList.cls` (`list (server criteria)`, `toolIdentifier` `interop.messages`).
- `InteropMessageHeaderTab.cls` (`detail`, id `single`, at `interoperability/messages/document`).
- **The multi-select key:** `multiSelect` `{action, max}`.
  - `Registry.cls`: `MULTISELECTKEYS` :3981, `MULTISELECTARCHETYPES` :3984 (which includes `list (server criteria)`) and `MULTISELECTMAX` 1000 :3987.
  - Precedent: `ExplorerClassList.cls`:89.
- **A screen with a row action** needs `emptyAgentKey` set and `emptyNextKey` `""` (`Registry.cls` `TableProblem`). `InteropItemTestTab.cls`:36-37 shows a tab declaring `primaryAction` and a page-drawn action.

**Client (`ui/src/app/`):**

- **`shell/screen-action-handler.ts`** (1,634 lines):
  - The maps: `SCREEN_ACTION_DESCRIPTORS` :67-145, `CHECKED_SET_DIALOGS` :359 (typed `'broadcast'` only), `UNDRAWN_ACTIONS` :390-427, `DESTRUCTIVE_ACTIONS` :489 and `DESTRUCTIVE_CONSEQUENCES` :517-584.
  - `PendingKind` :865.
  - The paths: `startFor` :1152-1230, `startCheckedSet` :1247-1256, `impactFor` :1377-1389, `send` :1420-1434 and `sendFor` :1502.
- **`shell/screen-action-dialogs.ts`** :33-88.
- **`shell/typed-name-dialog.ts`** (198 lines): inputs `verb`, `target`, `consequence`, `advisory` and `flagLabel` (:93-106).
- **`core/multi-select.ts`**: `checkedSetTarget` :51 (joins the keys, then `normalizeEntityId`) and `checkedSetReason` :43.
- **`areas/interoperability/interop-item-test-dialog.ts`**:
  - Inputs `item`, `rows`, `sending`, `refusal`, `violations` and `answer` (:204-224).
  - It emits `TestRequest {requestClass, fields}`. The rows are the Test tab's `{RequestClass, Kind, Field, Type, Required, MaxLength, Values, Secret}`.
- **`interop-item-test.page.ts`**:60-130: the page-registered action pattern (`actions.register`, route criteria, `sendFor`).
- **`shell/screen-outlet.ts`**: the `DESCRIPTOR_PAGES` loaders. `screen-outlet.spec.ts` pins the map.
- **Labels and codes:** `core/screen-actions.ts` `ACTION_LABELS` :112-147. `core/proposal-view.ts`: the `INTEROP.*` consequence constants :376-399 and `consequenceSentence` :444-554.
- **`core/strings.ts`** ends :7209. The bound is 3,800 (`ui/tools/strings.test.mjs`:612-615). The count is 3,374 before 20.9 and 20.30.
- **EXPERIENCE.md**: the Dialogs line :173, the last Fixed-strings row :604, and `confirm-dialog` :636.

**Tests, fixture and rosters:**

- **`Test/ProductionProbe.cls`** (`USER`):
  - `Create` :163, `AddItem` :203, `Send` :360, `Settle` :465, `Gone` :615 and `Remove` :635.
  - `Remove` deletes headers and logs by the `OcuPilotProbe` prefix only, so it leaves the `Ens.ScheduleService` header and every body (DW-2408).
- **Other fixtures and helpers:**
  - `Test/InteropTestFixture.cls`: an HL7 `DOCUMENTTEXT`, and `Remove` deletes bodies.
  - `Test/InteropItemControl`: `MintAs` :269 and `ConfirmHttp` :293.
  - `Test/InteropQueueActions`: `Through` :210, `AuditRows` :189 and `EnableKey` :136.
  - `Test/InteropHostTest.Send` :110 (a screen action with values).
  - `Test/ImpactRoute.cls`, the route-test precedent.
- **Arming.** An armed class declares `Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS"` (`InteropQueueActions.cls`:18). `scripts/ci-throwaway.sh` lists the interop armed classes at :439-492 (`# classes:` lines).

**Rosters a new write tool moves:**

| File | Anchor | Value now |
|---|---|---|
| `ToolWrite` | :1338 | 49 other-port writes |
| `ReadTool` | :93-94 | 385 tools (20.9 and 20.30 add 4) |
| `ToolRoundTrip` | `REFUSEEMPTY` :94 | - |
| `SurfaceCoverage` | write rows :408-424 | - |
| `ToolEmit` | interop branch :254 | - |
| `ClassicPageGate` | `OWNPAIRS` :75, with the count in the message at :160 | - |
| `MappingDescriptor` | `CLASSICROSTER` :24 | - |
| `GovernanceBaseline` | `DISABLED` :15 | - |
| `Governance` | :45, :48, :171-172 | - |
| `ToolDispatch` | :175-184 | - |
| `Test/Prohibited` | the composed `$Case` :438-456 | - |
| `EndpointCoverage` | the action route's row :108 | - |
| `Test/EntityRef` | IDRULES legs :207-258 | - |

**Vendor (read only):**

- **`Ens/MessageHeader.cls`:**
  - `ResendDuplicatedMessage` :443-455 checks no privilege. It sets `Resent` (:446-451) and audits the **new** header (:454).
  - `NewDuplicatedMessage` :457-502 makes these checks, in order:
    - not running (:459);
    - an unopenable header (:462);
    - a request target with no queue name (:471-473);
    - a response sent to a new target, and a reply queue that no longer exists (:476-477).
  - A non-object `pNewBody` is a body id. An object body is `%Save`d (:488-496).
- **`EnsLib/HL7/Util/MsgBodyMethods.cls` `%ProcessSubmit`**:158-197: the HL7 clone and parse sequence.
- **`Ens/Util/MessageBodyMethods.cls`**:158-169: other bodies are cloned, saved, then form values applied.
- **`EnsPortal/MessageResend.cls`**:
  - `RESOURCE` `%Ens_MessageResend:USE` :15, `EDITRESOURCE` `%Ens_MessageEditResend:USE` :18.
  - `ReallyResend` :361-386 continues past failures.
  - Edit takes exactly one message (:434-437).
- **`EnsPortal/MessageResendEdit.cls`**: `RESOURCE` `%Ens_MessageEditResend:USE` :16.
- **`Ens/Util/Auditing.cls`**: `AuditResendMessage` :104 and `AuditViewMessage` :19. There is no edit variant.

## Tasks & Acceptance

**Execution:**

- [x] **Rework 1 (the only open work in this section; every item below it shipped in `18c88e71` and `080df411`, and its box was never ticked).** Close the open HIGH under `### Review Findings` as its **Lead ruling** says. Of the spine, read AD-6, AD-13, AD-34 and the Consistency Conventions rows on `Kernel.State` writes and "When `SCHEMAVERSION` moves".
  - **`src/OcuPilot/Kernel/State/Propose.cls`:**
    - `TargetRef` becomes `MAXLEN = 2200`.
    - `TargetKey` is new: stored, `SqlComputed`, `SqlComputeOnChange = TargetRef`, `MAXLEN = 64`, equal to `TargetLockKey(TargetRef)`.
    - `Index ProposalTargetIdx On (TargetKey As Exact, State)`.
    - The sibling cancel in `GuardedClaimAndClose`, and every other query or `Exists`-style read on that index (search the repository for `ProposalTargetIdx` and for SQL over `TargetRef`), filters by `TargetKey` and then by the exact `TargetRef`, as it matches today (the canonical and the stored spelling).
    - The Storage section stays the compiler's.
  - **`src/OcuPilot/Install/Installer.cls`:** `src/OcuPilot` holds no index rebuild today. Add one install step, idempotent and run on every install, that gives each stored `Proposal` row its `TargetKey` and builds `ProposalTargetIdx` for the stored rows. It reaches the protected table through a guarded `Propose` class method (AD-9), and it is named in the failing-step vocabulary.
  - **Design Notes:** one entry saying whether `SCHEMAVERSION` moves, and why.
  - **Tests (one class per call; each about 500 lines or fewer):**
    - `InteropResendLimits.TestTheAgentsCardCarriesTheWholeCapOfAHundredMessages` goes green as written.
    - A leg with 100 nineteen-digit ids, at the store and, where the tool admits it, through the agent's mint.
    - A new self-contained store class: a sibling cancel finds its sibling by the exact target and leaves a different target alone; a row stored before the change (`TargetKey` unset) is found by the sibling cancel after the install step; a second run of the step changes nothing.
    - Each pinning test gets its `mutation:` line under Verification.
- [ ] **Task 0 (re-anchor and measure; no product code).** This task runs on `ocupilot-b-ci` only. Record each result as a `Task 0:` line under Verification. A result that disagrees with Design Notes › Measured is HALT `intent gap`.
  - **Re-anchor on 20.9's and 20.30's shipped code:**
    - `InteropMessageList` and `InteropMessageHeaderTab`, as declared;
    - `MESSAGEPAIRS`, the id check, `MessageRow` and the `Messages` `InvokeRuntime` branch;
    - `InteropMessageDescriptor`'s "no action" pins;
    - the end of `strings.ts` and the strings bound;
    - EXPERIENCE.md :173 and :604;
    - `screen-outlet.ts`, and whether the Header tab already has a page of its own (if it does, extend that page instead of adding one);
    - every roster row in the Code Map table.
  - **Least privilege.** A principal holding exactly resend's pairs (`%Ens_Portal:U`, `%Ens_MessageHeader:U`, `%Ens_MessageResend:U`, `%DB_USER:RW`) completes a resend through the port. Do the same for edit and its pairs. With `%DB_USER:R` instead, the port refuses naming `%DB_USER:WRITE`.
  - **Reply queue.** A synthetic response header whose `TargetQueueName` names no queue reads `noreplyqueue` through the port's predicate (`Ens.Queue.Exists`), and the vendor answers "Target reply queue … no longer exists".
  - **Disabled target.** A disabled item's request reads `targetoff` through `ResolveItem`'s effective `Enabled`.
  - `NormalizePage` spells `EnsPortal.MessageResend` and `EnsPortal.MessageResendEdit` as written.
  - *(after code)* One HTTP confirm per new tool answers exactly one envelope.
- [ ] **`src/OcuPilot/Kernel/EntityRef.cls`**: append `,interop-message:integerset` to `IDRULES` (add-only). Then run `cd ui && node tools/screen-mirror.mjs`.
  - A single id stays as it is.
  - 20.9's read criterion is not a target, so its check is unchanged.
- [ ] **`src/OcuPilot/Screen/Tool/Write.cls`** (add-only):
  - `Parameter DRYRUN As BOOLEAN = 0`. A doc comment says a tool declaring it answers the dry-run route.
  - `ClassMethod DryRunReview(pFresh As %DynamicObject) As %DynamicObject`, which answers `{}`.
- [ ] **`src/OcuPilot/Api/ScreenAction.cls`**: add a public `DryRun(pDescriptor, pBody, Output pPreview)`. Nothing else in the file changes.
  1. It finds the tool through `ToolFor`. An undeclared action, or a tool that does not declare `DRYRUN`, answers `NotFound()` before any read.
  2. Otherwise it calls `Resolve(pDescriptor, pBody, 1, "", .pPreview)`.
  3. It then sets `pPreview.review` to the tool's `DryRunReview(pPreview.fresh)`.
- [ ] **`src/OcuPilot/Api/ScreenDryRun.cls`** (new, shaped like `ScreenImpact`): handles `POST /screens/:screen/dryrun` with the action route's body `{action, id, values?}`.
  - An unreadable body or a missing `action` answers 400 `TOOL.ARGUMENTS`.
  - A secret value is refused, as `Preview` refuses it.
  - Otherwise it calls `DryRun` and answers `{rows, review}`: `rows` is the preview's `diff`, and `review` is the preview's `review`.
  - It holds nothing, writes nothing and asks no prohibited set.
- [ ] **`src/OcuPilot/Api/Router.cls`** (add-only): `<Route Url="/screens/:screen/dryrun" Method="POST" Call="ScreenDryRun"/>` beside :147, and its thin call target beside :932.
- [ ] **`src/OcuPilot/Port/InteropPort.cls`**:
  - **Types:** read types `RESEND` and `EDIT`, and write types `RESENDMESSAGES` and `EDITRESEND`, all on the `Messages` endpoint.
    - `IsMessageWrite(pType)` joins `IsAnyWrite`, giving WRITE on the globals database and no routines database.
    - `Serves` admits the four types on `Messages`.
    - `EDITRESEND` joins `COMPOSEDTYPES`.
  - **Pairs:**
    - `Pairs("Messages", RESEND|RESENDMESSAGES)` is `MESSAGEPAIRS` plus `RESENDPAIR` `%Ens_MessageResend:USE`.
    - `EDIT|EDITRESEND` adds `%Ens_MessageContent:USE`, `RESENDPAIR` and `EDITRESENDPAIR` `%Ens_MessageEditResend:USE`, in that order.
  - **`RESENDMAX` 100.** `MessageSet(pText, Output pIds)` checks the canonical set, as the Always rule states (400 `PORT.VALIDATION`, naming `Messages`).
  - **`MessageVerdict(pType, pExists, pBodyGone, pEnabledTarget, pReplyQueue)`** is pure. It answers one of the five verdicts in the Always order. Both the reads and the writes use it.
  - **`RESEND` read** (`READSVALUES`):
    - `ReadState` first, refusing NOTRUNNING.
    - Then, per id, the facts read switched. `HeaderFacts` gains these outputs, which its callers ignore: the header's type, source, target, body class and id, whether the body exists, and its reply queue.
    - The target's `Enabled` comes from `ResolveItem` in the running production.
    - It answers `{Namespace, Production, Messages: [{ID, Type, Source, Target, Verdict}], Verdicts, Eligible, Digest}`:
      - `Verdicts` is `id=verdict` joined by `,` in ID order.
      - `Digest` is a pure SHA-256 hex over `Production|Verdicts`.
  - **`EDIT` read** (`READSVALUES`, from `Message` and `Fields`):
    - It gives the `RESEND` facts for one message, refusing a gone header 404 `PORT.NOTFOUND`, unlogged.
    - It opens the body switched and records `AuditViewMessage("OcuPilot", …)`. Alarm messages are skipped, and a failed audit never fails the read.
    - **The body kind:**
      - `Kind` `document` only for `EnsLib.HL7.Message`, whose `content` is `RenderTargetHere`'s raw view.
      - Otherwise `Kind` `object`: `ClassFieldsHere`' fields, with each current logical value read along its path.
      - Anything else is refused 409 `INTEROP.EDIT.NOTEDITABLE`: another document kind, no body, a stream, a non-`%Persistent` class, a class name starting `OcuPilot`, or a document over `TESTOUTPUTMAX`.
    - **The supplied fields.** It parses `Fields` with `ParseTestFields`. It refuses with 422 `INTEROP.EDIT.FIELD` (unknown path), `.SECRET` (a `SecretPath` field supplied), `.VALUE` (a value its datatype's `IsValid` refuses) or the parser's refusal on `content`.
    - **Changes.** `Changed` lists the supplied paths whose value differs from the current one. A document is compared by the raw view of the parsed text.
    - It answers `{Namespace, Production, Message, Type, Source, Target, BodyClass, Kind, Verdict, Form: [{RequestClass, Kind, Field, Type, Required, MaxLength, Values, Secret, Value}], Fields, Changed, Before, After, Original, Digest}`:
      - `Before`/`After` are the changed fields as `<path>: <value>` lines, or `Hunk`'s two texts for `content`.
      - `Original` is a SHA-256 over the current form.
      - `Digest` is a SHA-256 over `Verdict|Original`.
  - **`RESENDMESSAGES` write**, switched by explicit save and restore:
    1. Re-read and re-judge.
    2. A `DIGESTKEY` that differs from the fresh `Digest` gives 409 `INTEROP.RESEND.CHANGED`.
    3. `Eligible` 0 gives 409 `INTEROP.RESEND.NONE`.
    4. Then `ResendDuplicatedMessage(id, .tNew)` for each `resend` id in ascending order. An error status is recorded and the loop continues.
    - The answer is `{Namespace, Resent, Failed, Messages: [{ID, NewId}|{ID, Error}]}`.
  - **`EDITRESEND` write:**
    1. Re-read, then check the digest and the verdict as above.
    2. `Changed` empty gives 409 `INTEROP.EDIT.NOCHANGE`.
    3. Build the clone. For an object, call `ApplyFieldsHere`, extracted from `BuildTestRequestHere`'s field loop (which now calls it too), on `%ConstructClone(0)`, then `%ValidateObject`. For HL7, follow the Always sequence.
    4. Call `ResendDuplicatedMessage(id, .tNew, "", tClone)`.
    - If the vendor errors after the clone was saved, the port deletes the clone when no header names it.
    - The answer is `{Namespace, Message, NewId, BodyClass, BodyId}`.
  - **`VerdictSentence(pVerdict)`** answers each verdict's sentence (Design Notes › Codes).
  - **Scripts.** Add `SnippetForm`/`Snippet` branches, rendered from the stored payload through `Literal` (AD-59):
    - resend: one `ResendDuplicatedMessage(<id>, .tNew)` line per reviewed `resend` id;
    - edit: the open, the clone, each changed field (or the HL7 sequence with the text literal), and the resend.
    - A snippet never carries a secret-path field, because the mint refuses one.
  - **Doc comments** state each row shape. The header doc names the two writes.
- [ ] **`src/OcuPilot/Api/InteropError.cls`**: add the codes and sentences in Design Notes › Codes, joined to `Codes`, `RuntimeCodes`, `ConsequenceCodes` and `ReasonFor`. Add each to `ui/tools/interop.test.mjs` `SENTENCES`.
- [ ] **Tools** (new). Each `DESCRIPTION` says that it only proposes, how to name the target, the cap and what is refused.
  - **`Screen/Tool/InteropMessageAction.cls`** (abstract, extends `InteropAction`):
    - Parameters: `DESTRUCTIVE` 1, `DRYRUN` 1, `WRITERESOURCE` `%Ens_MessageResend`, `WRITEPERMISSION` `USE`, `CLASSICPAGES` `EnsPortal.MessageResend` and `CHANGEACTION` `created`.
    - `Endpoint` is `Messages`.
    - `PortQuery`: after `##super`, it sets `DIGESTKEY` from the payload's `Reviewed` when present, else from its `Digest` (InteropQueueAbort's one-line shape).
    - `DryRunReview` answers `{Digest}`.
  - **`InteropMessageResend.cls`** (`interop.messages.resend`):
    - Parameters: `DESCRIPTORCLASS` `InteropMessageList`, `READTYPE` `RESEND`, `WRITETYPE` `RESENDMESSAGES`, `SCREENACTIONS` `resend`, `SCREENVALUES` `resend=Reviewed`, `STATEMARKER` `Verdicts`, `STATEFIELD` `Messages`, `PRECONDITIONFIELD` `Verdicts`, `FINGERPRINTSUBJECT` `Verdicts,Production,Namespace`, `PRECONDITIONCODES` `INTEROP.PRODUCTION.NOTRUNNING,INTEROP.NAMESPACE` and `CONSEQUENCECODE` `INTEROP.MESSAGE.RESEND`.
    - `IdArgument` is `Messages`.
    - **`MintClass`** (ProcessBroadcastMint's shape) refuses a set that is empty, over 100, malformed or carrying `Reviewed`, with 400 `TOOL.ARGUMENTS`, before any read.
    - **`StateDiff`** gives one `Messages` row, `before` `""` and `after` the lines. With `Eligible` 0, `pProblem` is the NONE sentence plus the lines.
    - **`WriteOutput`** gives `{lines}`.
  - **`InteropMessageEditResend.cls`** (`interop.messageheader.editresend`):
    - Parameters: `DESCRIPTORCLASS` `InteropMessageHeaderTab`, `READTYPE` `EDIT`, `WRITETYPE` `EDITRESEND`, `SCREENACTIONS` `editresend`, `SCREENVALUES` `editresend=fields:Reviewed`, `CLASSICPAGES` `EnsPortal.MessageResend,EnsPortal.MessageResendEdit`, `STATEMARKER` `Verdict`, `STATEFIELD` `Body`, `PRECONDITIONFIELD` `Verdict`, `FINGERPRINTSUBJECT` `Verdict,Original,Namespace`, `PRECONDITIONCODES` `INTEROP.PRODUCTION.NOTRUNNING,INTEROP.NAMESPACE,INTEROP.EDIT.NOTEDITABLE` and `CONSEQUENCECODE` `INTEROP.MESSAGE.EDITRESEND`.
    - `IdArgument` is `Message`.
    - **`PrivilegePairs`** declares the port's pairs in the port's order: the endpoint's, then `%Ens_MessageContent:USE`, `%Ens_MessageResend:USE` and `%Ens_MessageEditResend:USE`, then WRITE on the globals database, then the classic pages'.
    - **`ArgumentProblem`** caps `Fields` at `ExplorerSave.CHANGEMAXLENGTH` (30,000) and refuses an agent's `Reviewed`.
    - **`ScreenActionDelta`** maps `fields` to `Fields` (at most `AtelierPort.MAXIMPORTCHARACTERS`) and `Reviewed` to itself.
    - **`StateDiff`** gives one `Body` row from `Before`/`After`. A non-`resend` verdict sets `pProblem`.
    - **`DryRunReview`** adds `Kind` and `Form`.
- [ ] **Descriptors (20.9's, edited in place):**
  - **`InteropMessageList`:**
    - `rowActions` `[{"id":"resend"}]` and `multiSelect` `{"action":"resend","max":100}`;
    - `emptyNextKey` `""` and `emptyAgentKey` `interopMessagesEmptyAgent`;
    - one doc sentence: the checked rows resend after a dry run (Story 20.31).
  - **`InteropMessageHeaderTab`:**
    - `primaryAction` `resend`, and `rowActions` `resend` and `editresend`;
    - `emptyNextKey` `""` and `emptyAgentKey` `interopMessagesEmptyAgent` (ProcessDetails' precedent of reusing the list's key);
    - one doc sentence.
- [ ] **`Kernel/Governance/Baseline.cls`** (add-only): append `"interop.messages.resend": false` and `"interop.messageheader.editresend": false`.
- [ ] **Client:**
  - **`shell/typed-name-dialog.ts`:** an optional `review` input (`readonly string[]`, default `[]`). It is drawn above the consequence as a `<ul class="ocu-dialog-review" data-ocu-review>` of interpolated lines, scrolling inside the dialog. Empty draws nothing, as before.
  - **`shell/screen-action-handler.ts`:**
    - `DRY_RUN_ACTIONS` lists `InteropMessageList` `resend` and `InteropMessageHeaderTab` `editresend`.
    - `dryRunFor(descriptor, action, id, values?)` POSTs the dry-run route as `impactFor` reads impact.
    - `CHECKED_SET_DIALOGS` gains `[InteropMessageList]: {resend: 'dry-run'}` and its type widens.
    - `startCheckedSet` handles `'dry-run'`:
      1. Read the dry run.
      2. On a refusal, show the list's banner.
      3. Otherwise open `typed-name` with `review` set to the row's lines, `target` set to the eligible count (the id when one message is checked), and the consequence `INTEROP.MESSAGE.RESEND`'s sentence.
      4. Keep `review.Digest` in the pending entry, and send it as `values {Reviewed}` on confirm.
    - Export a `startDryRun(descriptor, action, id, values?)` that pages call.
    - `SCREEN_ACTION_DESCRIPTORS` gains both descriptors.
    - `UNDRAWN_ACTIONS` gains `InteropMessageHeaderTab: ['resend', 'editresend']`.
    - `DESTRUCTIVE_CONSEQUENCES` maps both actions.
    - Everything else is unchanged.
  - **`shell/screen-action-dialogs.ts`**: pass `review` through.
  - **`areas/interoperability/interop-item-test-dialog.ts`:**
    - Optional inputs `heading`, `submitLabel` and `values` (a prefill keyed by field path). Their defaults keep the Test dialog byte-identical.
    - Outputs are unchanged.
  - **`areas/interoperability/interop-message-header.page.ts`** (new): the host flex column of `interop-item-test.page.ts` over `<app-detail-page />`. It registers two actions for the route's message id:
    - `resend`: `handler.startDryRun(InteropMessageList, 'resend', id)`.
    - `editresend`:
      1. a dry run with no fields;
      2. the extended Test dialog over `review.Form`, with `heading` `interopEditResendHeading`, `submitLabel` `interopEditResendReview` and `values` from `Form`;
      3. on submit, the dry run with `{fields: <changed only>}` runs while the form stays open. A refusal or a field violation stays in the form.
      4. On success the form closes and the typed-name review opens, typed name the id.
      5. Confirm sends the same values plus `Reviewed`.
    - Dialogs never stack.
    - `startDryRun` keeps the values it previewed with and adds `Reviewed` on confirm, for both actions.
  - **`shell/screen-outlet.ts`** (add-only): the Header page's loader line.
  - **`core/screen-actions.ts`**: `ACTION_LABELS` `resend` "Resend" and `editresend` "Edit and resend".
  - **`core/proposal-view.ts`**: the two consequence codes.
  - **`core/strings.ts`** (add-only): Design Notes › Strings. Then regenerate the mirror.
  - **`styles/_components.scss`**: `.ocu-dialog-review`, which uses tokens only.
- [ ] **EXPERIENCE.md** (add-only, each with `[ADDED 2026-10-13 - Story 20.31]`), then `cd ui && npm run test:tools`:
  - **:173**, before "Everything else":
    > `· resend messages (the Messages list's checked rows or one message's Header tab, Story 20.31: the dry run's verdict for each message, then the destructive treatment, typed name the count to be resent or the message id) · edit and resend a message (its Header tab, Story 20.31: the body's fields, then the dry run, then the destructive treatment, typed name the message id; the two dialogs follow one another, never stack)`
  - **:604**: the Story 20.31 clause carrying every new literal.
- [ ] **`Test/ProductionProbe.cls`** (add-only):
  - `HighWater()` answers USER's highest `Ens.MessageHeader` and `Ens_Util.Log` ids.
  - `SweepSince(pMark)` deletes, in USER, every header above the mark with its persistent body, and every log row above the mark. It answers what is left above the mark.
  - `StoredRequest(pBody, pTarget, Output pId)` saves a body and a request header through `Ens.MessageHeader.NewRequestMessage` from `OcuPilotProbeSvc`, `Completed`.
  - `StoredResponse(pRequestId, pQueue, Output pId)` saves the response header through `NewResponseMessage`, its `TargetQueueName` set to `pQueue`.
- [ ] **Tests (new; one class per call; each about 500 lines or fewer):**
  - **Hermeticity.** Each armed class records `HighWater` in `OnBeforeAllTests`. It removes the probe (`Settle`, `Remove`) and calls `SweepSince` in `OnAfterAllTests`, and asserts nothing is left above the mark. It restores governance.
  - **`Test/InteropResendDescriptor.cls`** (unarmed):
    - The two tools' shapes: names, types, `DESTRUCTIVE`, `DRYRUN`, pairs in order, `CLASSICPAGES`, subjects, codes, each key `false` in the baseline, and `IdArgument`.
    - The descriptors' actions, `multiSelect.max` equal to `RESENDMAX`, and both `emptyAgentKey`s.
    - `Serves` and `Pairs` per type.
    - The `MessageVerdict` matrix (all 5 verdicts and the order) and the `MessageSet` refusals (empty, 101, `0x1`, duplicates folded).
    - The digest's order sensitivity, every code through `ReasonFor` and `Api/Error.ReasonForViolation`, the snippet forms, and `EntityRef.Canonical("interop-message","13,2,13")` = `2,13`.
  - **`Test/DryRunRoute.cls`** (unarmed, `ImpactRoute`'s shape):
    - a missing `action` gives 400;
    - a tool without `DRYRUN` gives 404;
    - a secret value is refused;
    - the answer is `{rows, review}`;
    - the target hold is free afterwards and no row was written.
  - **`Test/InteropResend.cls`** (armed): the probe running, with messages from `Send` and `StoredRequest`.
    - Mint, then HTTP confirm (key enabled through `GovernanceFixture`): nothing is sent at mint, Confirm sends, and the new headers' `SessionId`, `Resent` and Description are checked. There is one vendor `Resend` audit row per new header, newer than the test, naming its id.
    - The marker and the change event.
    - The screen route plus the dry-run route, with `Reviewed`, and CHANGED when a target is disabled between them.
    - The mixed verdicts, including `noreplyqueue` from `StoredResponse`. NONE.
    - NOTRUNNING with the production stopped.
    - 101 ids refused with nothing sent.
    - Target-changed closure.
    - Integration: 20.30's `interop.messagetrace.read` of the original answers the new header's `ID` in the same session.
  - **`Test/InteropEditResend.cls`** (armed):
    - An `Ens.StringRequest` edit through both callers: the clone carries the new `StringValue`, the original is unchanged, and the new header names the clone.
    - An HL7 edit (`InteropTestFixture.DOCUMENTTEXT`): `DocType` kept, `Source` annotated, segments replaced.
    - Refusals: NOTEDITABLE (an X12 body, and a body class starting `OcuPilot`), NOCHANGE, FIELD, SECRET and VALUE, each sending nothing.
    - One `ViewContents` row per edit read that opened a body.
  - **`Test/InteropResendGate.cls`** (armed, principals): reuse `InteropItemGate`'s helpers through a parameter, as `InteropSettingGate` does.
    - Each missing pair is refused by name through the port, the mint, Confirm, the action route and the dry-run route.
    - A principal holding exactly each tool's pairs completes it.
  - Add one `# classes:` line in `scripts/ci-throwaway.sh` for the three armed classes.
- [ ] **Rosters** (each row named from the instance):
  - `ToolWrite` 49→51, plus a clause;
  - `ReadTool` +2;
  - `ToolRoundTrip` `REFUSEEMPTY` `interop.messages.resend:TOOL.ARGUMENTS` and `interop.messageheader.editresend:TOOL.ARGUMENTS`;
  - two `SurfaceCoverage` write rows naming `InteropResend`/`InteropEditResend` tests;
  - `ToolEmit`'s interop branch;
  - `ClassicPageGate` `OWNPAIRS` and its count;
  - `MappingDescriptor` `CLASSICROSTER`;
  - `GovernanceBaseline` `DISABLED`;
  - `Governance` and `ToolDispatch` (a new `INTEROPMESSAGEDISABLED`, used as the others are);
  - `Test/Prohibited`'s composed `$Case` (`"interop.messageheader.editresend"`);
  - an `EndpointCoverage` probe row for the new route (the action route's row shape);
  - `Test/EntityRef` (the new pair);
  - 20.9's `InteropMessageDescriptor` (the declarations now carry actions).
- [ ] **Client tests:**
  - `typed-name-dialog.spec.ts`: `review` draws lines as text (a `<script>` line stays text), and no `review` draws as before.
  - `interop-item-test-dialog.spec.ts`: prefill and heading.
  - `screen-action-handler.spec.ts`:
    - the checked set reads the dry run before any dialog, a refusal is the banner, and confirm sends `Reviewed`;
    - `interop-message-header.page.spec.ts`: both actions register, and edit runs form, then review, then send.
  - `screen-outlet.spec.ts`: the new loader.
- [ ] **`ui/browser/interop-message-resend.browser-spec.mjs`** (new; refuses `LIVE_CONTAINER`). `before` records the mark, then creates and starts the probe in USER through `runIris`, with a disabled item added by `AddItem(…, 0)` for the `targetoff` message. `after` removes the probe and sweeps from its mark. Every step waits for the screen's answered signal. Each test carries its mutation comment:
  1. AC1;
  2. AC4's person legs;
  3. AC5;
  4. AC8 in the Trace tab;
  5. `structural` with the review dialog open at 1280 light and 720 light.
- [ ] **Roster sweep (Rule 30):** grep `src/OcuPilot/Test`, `ui/tools`, `ui/browser` and the `ui/src` specs for the two descriptors' declarations, `IDRULES`, the typed-name dialog's inputs, `CHECKED_SET_DIALOGS`/`PendingKind`, the Router's routes and every roster above. Each file changed joins the `(loop)` set.

**Acceptance Criteria:**

- **AC1 (a person's dry run, then confirm, from the list).**
  - **Given** the probe production running in USER, three probe messages, and a fourth whose target item is disabled.
  - **When** the person checks the four on Messages and chooses Resend.
  - **Then:**
    - the dialog lists four lines with their verdicts, and USER's header count is unchanged;
    - Resend stays `aria-disabled` until `3` is typed;
    - after Resend, the list re-fetches and shows three new headers, each `Resent <id>` in its original's session;
    - the dialog lists `<id>: resent as <new>` for each.
- **AC2 (the bounded cap).**
  - **Given** 101 checked rows.
  - **When** Resend is chosen.
  - **Then** it is drawn refused with "Check at most 100 rows". A direct action call and an agent call naming 101 ids are refused 400 naming `Messages`, and nothing is read or sent.
- **AC3 (the agent's dry run is its proposal).**
  - **Given** the key enabled.
  - **When** the agent proposes resending two messages.
  - **Then:**
    - the card shows the `Messages` row with both verdicts, and nothing is sent;
    - Confirm sends both, with the marker and the change event;
    - a target disabled after the mint closes the proposal target-changed, with nothing sent;
    - with the key at its shipped `false`, the call is denied.
- **AC4 (the review binds a person's Confirm).**
  - **Given** a reviewed dry run.
  - **When** a target is disabled before Resend.
  - **Then** the action answers 409 `INTEROP.RESEND.CHANGED`, nothing is sent, and the dialog shows the sentence. The same holds from the Header tab, typed name the id.
- **AC5 (edit and resend).**
  - **Given** an `Ens.StringRequest` message open on its Header tab.
  - **When** the person chooses Edit and resend, changes `StringValue`, reviews the `Body` row, types the id and confirms.
  - **Then:**
    - a new header in the same session names a new body holding the new value;
    - the original header and body are unchanged;
    - `InteropEditResend` pins the HL7 path and each refusal in the matrix.
- **AC6 (gated and audited).**
  - **Given** the two tools.
  - **When** each runs.
  - **Then:**
    - each missing pair is refused by name on every path (`InteropResendGate`);
    - the vendor's `Resend` row names each new header;
    - the edit's read writes one `ViewContents` row;
    - OcuPilot writes no `ConfigChange`.
- **AC7 (declared, rostered, posture).**
  - **Given** the build and the instance.
  - **When** the rosters and the mirror are read.
  - **Then:**
    - both keys read `false` in the baseline;
    - `ToolWrite` counts 51 other-port writes;
    - every Code Map roster holds its new rows;
    - the mirror carries `interop-message:integerset` and the list's `multiSelect`;
    - removing either `SurfaceCoverage` row reddens it alone.
- **AC8 (Integration, Rule 1; Story 20.30's trace consumes the resend).**
  - **Given** a message resent through this story.
  - **When** its Trace tab opens (20.30).
  - **Then** the diagram holds an arrow for the new header's `ID` in the original's session, and `interop.messagetrace.read` answers that row.

### Review Findings

Code review, 2026-10-15 (four layers, `full-opus`; Rule 6, Rule 3 and Rule 31 checked). Open: none.

- [x] [Review][Patch] **HIGH (AD-6, AD-13, AC2, AC3): the agent's proposal of a long set cannot be stored** [src/OcuPilot/Kernel/State/Propose.cls:82,232] — the target `interop-message|<ns>|<ids>` is the canonical set, and `ProposalTargetIdx On (TargetRef As Exact, State)` overflows the global subscript near 455 characters (`<SUBSCRIPT>%SaveData+35`, 500 `INTERNAL`; run 881, 100 four-digit ids), while `TargetRef` is `MAXLEN = 512` and 100 ids of up to 19 digits need about 2,040. The person's route stores no proposal and sends 100. **(a) is not tool-local**: the mint keys the target by the kernel (`Kernel/Proposal/Mint.cls:154` → `Operation.TargetRefOf`, no tool hook), and Confirm and the draft read the port's id back from the stored `TargetRef` (`Confirm.cls:687`, `Draft.cls:144`), and the person's hold keys by the same `EntityRef` rule (`Api/ScreenAction.cls:228-232`). So a bounded identity needs a new `EntityRef` rule mirrored in the client, a confirm and draft path that read the ids from the payload, and a person's route that keeps the raw ids. Otherwise the agent and the person hold two different locks on one set (AD-34). **Recommended fix, (b):** in `Propose.cls`, widen `TargetRef` to `MAXLEN = 2200`, add a stored computed `TargetKey` (`TargetLockKey(TargetRef)`, 64 hex), key `ProposalTargetIdx On (TargetKey As Exact, State)`, and filter the sibling cancel in `GuardedClaimAndClose` by `TargetKey` plus the exact `TargetRef`. Then rebuild the index for stored rows (proposals live 10 minutes) and turn `InteropResendLimits.TestTheAgentsCardCarriesTheWholeCapOfAHundredMessages` green, with a 19-digit-id leg. **(c)** (a 400 naming `Messages` for a set whose target does not fit) needs a Rule 5 amendment of AC2 and AC3 and is the orchestrator's call.
  - **Lead ruling (rework 1):** take (b). It is inside Epic 20's footprint (`Kernel/**`) and no in-flight epic edits `Propose.cls`. Keep `TargetRef` exact and readable (Confirm and the draft still read it); the digest key only bounds the index subscript. Stored rows must keep working after an upgrade: read how the installer handles a changed index on a `Kernel.State` class (search `src/OcuPilot/Install` for `%BuildIndices` or index rebuilds, and the spine's "When `SCHEMAVERSION` moves" convention), rebuild `ProposalTargetIdx` there for existing rows, and say in Design Notes whether `SCHEMAVERSION` moves (a computed property every existing row reads safely after the rebuild does not move it). Pin it: the red `TestTheAgentsCardCarriesTheWholeCapOfAHundredMessages` goes green, a leg with 100 nineteen-digit ids is added, a sibling cancel still finds its sibling by the exact target, and an existing proposal row written before the change is still found after the rebuild.
- [x] [Review][Patch] `RunScript` returned OK whatever the drafted script's `tSC` read, and left the script's variables in the process [src/OcuPilot/Test/InteropResendCase.cls:171]
- [x] [Review][Patch] A session's header count read 1 for a session with no new header (`$Length("", ";")`) [src/OcuPilot/Test/InteropResend.cls:181,320; src/OcuPilot/Test/InteropResendLimits.cls:106]
- [x] [Review][Patch] An edit that clears a field was never round-tripped through the stored `Fields` [src/OcuPilot/Test/InteropResendLimits.cls]
- [x] [Review][Patch] The browser spec acted on Messages rows before the source search answered [ui/browser/interop-message-resend.browser-spec.mjs:135]
- [x] [Review][Patch] The edit tool repeated the host test's `Fields` checks, parse and query (Rule 31; `InteropItemTestSend` now shares `FieldsProblem`, `FieldsFromText`, `FieldsQuery`) [src/OcuPilot/Screen/Tool/InteropMessageEditResend.cls]
- [x] [Review][Patch] `MessageSet` repeated `EntityRef.PlainIntegerSet`'s ordering and `QueueDigest` repeated `Sha256Hex` (Rule 31) [src/OcuPilot/Port/InteropPort.cls:3807,4672]
- [x] [Review][Patch] `DryRunRoute`'s "held no target" leg could not fail, because the agent's mint takes no hold [src/OcuPilot/Test/DryRunRoute.cls:78]
- [x] [Review][Patch] The Messages empty state read "Or ask the agent: Or ask the agent to find and resend messages.." [ui/src/app/core/strings.ts:7476; EXPERIENCE.md :604]
- [x] [Review][Patch] A document edit's review drew an empty `- ` and `+ ` line, because each hunk line ends in a line feed [ui/src/app/shell/screen-action-handler.ts reviewLinesOf]
- [x] [Review][Patch] `RunningProduction` read a status the vendor could not read as not running (409) [src/OcuPilot/Port/InteropPort.cls:3870]
- [x] [Review][Patch] `MessageSnippet` rendered every id of a set with no verdicts, against AD-62 (17) [src/OcuPilot/Port/InteropPort.cls:4561]
- [x] [Review][Patch] Two `InteropResendGate` doc comments claimed checks the tests do not make [src/OcuPilot/Test/InteropResendGate.cls:166,227]
- [x] [Review][Patch] `RemoveBodyClasses` ignored the `%KillExtent` and `DeletePackage` statuses [src/OcuPilot/Test/InteropResendFixture.cls:278]
- [x] [Review][Patch] `ScreenDryRun`'s doc claimed the action route's envelope for every refusal; an unreadable body differs [src/OcuPilot/Api/ScreenDryRun.cls:4]
- [x] [Review][Patch] EXPERIENCE.md :173 named no outcome after a confirmed review [EXPERIENCE.md :173]
- [x] [Review][Defer] The other Epic 20 interop empty states garble the same way [ui/src/app/core/strings.ts:6635-7279] — deferred: pre-existing in 20.3 to 20.27, DW-2452 routed burndown
- [x] [Review][Defer] `ScreenDryRun.Handle` repeats `ScreenAction.Handle`'s body preamble [src/OcuPilot/Api/ScreenDryRun.cls:17] — deferred: the spec kept `ScreenAction` add-only, DW-2453 wontfix-accepted

**Rejected:**

- No in-flight guard after a confirmed review, and an empty outcome on `installing`: low. The window is one request, and a second send needs a new review, the typed count and a confirm.
- The Header tab's Resend is served by the Messages route: by design, because the Task has the page call `startDryRun(InteropMessageList, …)`.
- The NONE banner shows only the published sentence: by design. The list's banner is the refusal sentence.
- `targetoff` is read from the stored configuration and implicit hosts: by design (the verdict is defined over the production's items). A target the vendor then refuses reads `not resent: <text>`.
- `EditCloneHere` after a vendor throw, its `%DeleteId` status and no `%EXACT`: theoretical. The vendor answers statuses, and class names differ by more than case.
- `<PROTECT>` after earlier resends, and an action without `Reviewed`: closed in the implement review.
- A clone that fails validation or save answers 500: low. Each value is validated at the read.
- HL7 `DocType` kept after an MSH-9 change: false. The vendor's `%ProcessSubmit` (`MsgBodyMethods.cls:158-197`) keeps it, as the spec requires.
- `007` admitted for a person, refused for the agent: low. Only a hand-written body reaches it, and AD-13 names `007` and `7` one entity.
- A Header-tab resend unchecks the Messages rows, a review in flight across a cancel and reopen, and an outcome for an unmounted list: low and rare; each fix adds a guard.
- AC7's mirror leg has no mutation line: false. Rule 19 asks one per AC, and AC7 has three.
- `DRY_RUN_ACTIONS` is not pinned to the server: low, because no other `DRYRUN` tool exists.
- `Original` omits properties the form does not show, one edit records several `ViewContents` rows, and the empty state invites a key that ships off: each by design (spec Design Notes, Always and Strings).
- Copied `EnableKey` and the gate's own helpers: low. They are test-only, and the pattern is shared by three interop suites.

**Rework re-review 1, 2026-10-15** (four layers, `full-opus`, over `2f564cff..a61b3b8f`; Rule 6, Rule 3 and Rule 31 checked). The HIGH above is closed: `InteropResendLimits` 8 of 8 (run 1168) and `ProposalTargetKey` 7 of 7 (run 1167) on `ocupilot-b-ci`. Open: none.

- [x] [Review][Patch] A failed index build was never repaired: the build ran only when the run had given a row its key, after the keys were committed, so a run that stopped in the build left the next run nothing to do [src/OcuPilot/Kernel/State/Propose.cls:598]
- [x] [Review][Patch] No test pinned the declaration order that keeps an older row's columns in their data slots [src/OcuPilot/Test/ProposalTargetKey.cls:309]
- [x] [Review][Patch] `TARGETREFMAX` and `LongRef` called 100 ids of 19 digits the longest target a tool names; a document set can be longer [src/OcuPilot/Kernel/State/Propose.cls:80; src/OcuPilot/Test/ProposalTargetKey.cls:69]
- [x] [Review][Patch] The 19-digit confirm leg asserted no line of its answer [src/OcuPilot/Test/InteropResendLimits.cls:158]
- [x] [Review][Patch] The 512-cut `mutation:` line said "alone"; three `ProposalTargetKey` tests also go red [## Verification]
- [x] [Review][Defer] `SCHEMAVERSION` stays 1, so a reinstall of 1.0.12 over a volume this code wrote is admitted, and 1.0.12 cannot file a long-target row [src/OcuPilot/Install/Installer.cls:81] — deferred: DW-2456 escalated to the decision sheet
- [x] [Review][Defer] A target over 2,200 characters, such as a long explorer document set, fails the mint with 500 `INTERNAL` [src/OcuPilot/Kernel/State/Propose.cls:283] — deferred: pre-existing (near 455 characters before the rework), DW-2457 escalated to the decision sheet

**Rejected (rework re-review 1):**

- `GuardedBuildIndices` queues the build on `$SYSTEM.WorkMgr`, against AD-9's no-spawn rule: false. The work queue records the caller's security context for each work unit, and `%BuildIndexInternal` waits in `Sync` before the frame unwinds, so no role outlives the frame.
- The legacy-row tests file a null-key index entry that a real older row lacks: false for the outcome. The candidate read `TargetKey IS NULL` reads the master map (EXPLAIN on `ocupilot-b-ci`), so it finds an older row with no entry the same way.
- The build takes no locks: low. The sibling cancel re-tests every condition against the master row (EXPLAIN), so a stale entry closes nothing, and an install while requests are served is AD-38's accepted window.
- The five store tests share the production-install arming: low. Every CI shard and throwaway arms the class.
- Three fixture self-checks cannot fail: low. They guard the fixture, and the unscoped-row skip is pinned by the second run's count.
- Rework 1 ticked no task box and replaced the Auto Run Result: low, and the fix edits the spec under the `oversized` rule.
- The rework's run left out the other classes that run `Install`: false. The full sweep is the runner's (Verification, Lead-owned); `InstallTarget` read 7 of 7 here.

## Spec Change Log

- 2026-10-14, spec gate (runner): Q1 is answered as recommended (one story: no split, so nothing is deferred), and Q2's named limits are accepted (a new target, head of queue, resend of every match, and editing X12, EDIFACT or ASTM bodies are out of scope; the criterion's double gate and cap hold for what ships). Both keys ship `false`, as the orchestrator's 2026-10-13 guidance and AD-22 direct. The Rule 20 drafts are written (AD-62 item 17, AD-53, AD-51, AD-8, AD-44, AD-13, AD-22).
- 2026-10-15: re-opened for rework iteration 1 (code review's one HIGH, the long-set proposal target; lead ruling (b) under Review Findings).

## Review Triage Log

### 2026-10-15 — Review pass

- verdicts: 25 findings — high 0, medium 5, low 16, false 4, maybe-false 0
- findings:
  - Verification-gap layer:
    - `[medium]` `[patch]` The edit form's `Value` for a credential-named field, and the `Fields` echo, are not asserted — read the test: it collected `Field` and `Secret` only. Asserted both in `TestEveryFieldShapeIsEditedOnACloneAndTheOriginalIsLeftAlone`; each mutation reddens it alone.
    - `[medium]` `[patch]` `Original` binds no review: no test changes the body between review and send — added `TestABodyEditedAfterTheReviewIsRefusedForThePersonAndTheAgent` (person CHANGED, agent target-changed); the mutation reddens it alone.
    - `[medium]` `[patch]` The clean-up of a copy the vendor refused after the save never ran: `RefuseEditAfterSave` had no caller — added `TestACopyTheVendorRefusedAfterTheSaveIsDeleted` over the seam, counting bodies and headers; the mutation reddens it alone.
    - `[medium]` `[patch]` The HL7 branch of the edit's copy-out script has no test — added `TestTheCopyOutDraftOfAnHl7EditRendersItsScriptAndRunningItDoesTheSame`, which runs the script and compares segments, source and original; the mutation reddens it alone.
    - `[low]` `[patch]` A stopped production is not tested for the edit read, review and write — added `TestAStoppedProductionIsRefusedByTheEditReadReviewAndWrite`; the mutation reddens it alone.
    - `[medium]` `[patch]` "OcuPilot writes no ConfigChange" is pinned for resend only, by an id-exact match, with no mutation line — both agent tests now count `ConfigChange` rows naming `interop-message` since their start; a mutation per write reddens each test alone.
    - `[low]` `[patch]` The over-cap 400 is asserted by code only — the port, review and action legs now assert the sentence naming `Messages` and the cap, and a 101-id action call is refused; the mutation reddens the test alone.
    - `[low]` `[patch]` The governance test relies on a policy it did not set — it now asserts that no stored policy overrides the baseline, as `ToolDispatch` does.
    - `[low]` `[patch]` `HighWater` swallows a failed read, so the sweep can delete every row in USER — it answers `""` on a failed read, `SweepSince` deletes nothing for a mark that is not `<digits>|<digits>`, and the suite and the browser spec refuse to start without a mark.
    - `[low]` `[reject]` The AC3 mutation does not isolate the target-changed leg — the recorded mutation reddens that test among eight; isolation is not what Rule 19 asks, and a narrower mutation would also redden the person's digest legs.
    - `[false]` `[reject]` An assertion in `audit.page.spec.ts` cannot observe the dry run — the cited `paths.at(-1)` assertion fails on any further read after the opening one; the dry run is held by the dialog and review-line assertions that follow it.
    - `[low]` `[reject]` AC2's client leg has no recorded mutation — AC2 has one (`RESENDMAX` 1000, reddening the descriptor and the 101 leg), and `screen-action-handler-resend.spec.ts` names the descriptor mutation at its assertion.
    - `[low]` `[reject]` A person's action without `Reviewed` skips the review gate — by design: the dry run and the action share one value rule, so `Reviewed` must be optional, and a caller of the REST route holds the privileges the classic page needs without any review. Closing it would change specified behavior.
    - `[false]` `[reject]` `MessageVerdict` treats every non-`Request` type as a response — the vendor's `NewDuplicatedMessage` branches `If Type = Request ... Else { reply queue check }`, so `Terminate` is judged by the vendor as the code judges it.
    - `[low]` `[patch]` A stream body may leave data in USER after the sweep — confirmed, and wider: the sweep read the body class from an index, which returns it upper-case (`%STREAM.GLOBALCHARACTER`), so no body of any class was ever deleted. It now reads the class from the header and deletes persistent and stream bodies; probed on the throwaway (stream and `Ens.StringRequest` counts fall back).
    - `[low]` `[patch]` Test comments mislabel their ACs, and the gate's mutation text names `ScreenAction.DryRun` — comments now cite the spec's numbering, and the pair gate is named at `ScreenAction.Run`.
    - `[false]` `[reject]` `DryRunRoute` differs from the spec's list — the answering leg needs the running production, so the class is armed; no tool that declares a dry run declares a secret, and the shared guard is pinned by `ImpactRoute`. No bad outcome.
  - Intent-alignment layer:
    - `[low]` `[reject]` The command bar's "Check at most 100 rows" is tested at function level only — the screen's declaration is pinned by `screen-action-handler-resend.spec.ts` and the bar's rendering of a checked-set reason is shared code with its own specs; a test of the bar would add no unique coverage.
    - `[low]` `[reject]` The Gated row's "drawn `aria-disabled` with Requires" is not drawn on the row action — the agent's proposal card draws it from the tool's declared pairs (`privilegeProposalMissing`), and a person's press is refused 403 naming the pair (`InteropResendGate`); no row action in the client is pre-disabled by pair, so a pre-disable would be a new server-computed surface.
    - `[low]` `[reject]` The double gate is server-enforced only when `Reviewed` is supplied — same root as the verification-gap row on a person's action without `Reviewed`; closed by design there.
    - `[low]` `[reject]` A named stream, collection or object property answers `INTEROP.EDIT.FIELD`, not `.NOTEDITABLE` — the form lists no such property, so naming one is naming a path that is no field; both refuse with nothing sent, and a branch for the other code adds surface for one sentence.
    - `[false]` `[reject]` `Terminate` reads as a response — same claim as the verification-gap row; the vendor treats it so.
    - `[low]` `[reject]` The browser edit covers an `Ens.StringRequest` only — the spec names that body for AC5's browser leg and `InteropEditResend` pins the HL7 path.
    - `[low]` `[reject]` The browser spec runs as the all-privilege account — the gate is pinned for restricted principals at the port, the tools and both routes (`InteropResendGate`); the browser leg checks the screens.
    - `[low]` `[reject]` A vendor `<PROTECT>` stops the write with 403 instead of continuing — a privilege fault repeats for every message, and the gate has already asked for WRITE on the globals database; the case is not reachable with the gate in place.

### 2026-10-15 — Code review (cr stage)

- verdicts: 42 raw findings (41 from the layers, and QA's HIGH) in 37 entries — high 1 (open), medium 9, low 8, rejected 19 (false 2).
- open: the HIGH in `### Review Findings` (proposal target overflow). Fix (b) is recommended because (a) is not tool-local; (c) is a Rule 5 ask.
- patched: 15 (medium 8, low 7). Ledger: DW-2452 (medium, routed burndown) and DW-2453 (low, wontfix-accepted).
- verified on `ocupilot-b-ci` (tree reloaded, bundle redeployed):
  - green: `InteropResendDescriptor` 8, `InteropResend` 9, `InteropEditResend` 13, `DryRunRoute` 2 and `InteropResendGate` 4;
  - `InteropResendLimits` 7, red only on the open HIGH;
  - the host-test suites `InteropHostTest` 12, `InteropHostTestEdges` 5 and `InteropHostTestRefusals` 7, and `InteropQueueActions` 10;
  - `test:tools` 2026, `test:components` 3238, `build`, and `interop-message-resend` 5 of 5.

### 2026-10-15 — Review pass (rework 1, follow-up)

- verdicts: 14 findings — high 0, medium 1, low 10, false 3, maybe-false 0
- findings:
  - Verification-gap layer:
    - `[low]` `[reject]` The sibling cancel's `TargetKey` conjunct is not pinned (dropping it closes the same rows) — it is the index-use predicate, and the previous index was likewise not plan-pinned; the fix adds a SQL-text seam to a production class for a performance property on a table of ten-minute rows.
    - `[low]` `[reject]` A failing `EnsureProposalTargetKeys` is not pinned to fail the install naming the step — the step follows the pattern of the other install steps, of which two have a failure pin; a fault needs an `Installer` subclass seam.
    - `[low]` `[patch]` The step's report lines are unasserted — `TestARowStoredBefore...` asserts the first run's `Gave` line and `TestASecondRunOfTheStepChangesNothing` the third run's `already carries` line; swapping the branches reddens both.
    - `[medium]` `[patch]` A target over `TARGETREFMAX` is stored cut (probed on `ocupilot-b-ci`: 3,000 characters stored as 2,200, mid-name, status OK), where it failed before the widening; `ExplorerWrite` names up to 100 documents, so a set over 2,200 characters is reachable — `GuardedMint` now refuses it with an error (the mint answers 500 `INTERNAL`, as it did), and a new test pins the limit and one more; the mutation reddens it alone.
    - `[low]` `[patch]` `ProposalTargetKey` asserted `$Length(tRef) > 0` for the short target, which cannot fail — it now asserts `< 400` for the short and `> 2000` for the long.
    - `[low]` `[patch]` No mutation line for the unscoped-row skip — applied and read red in `TestASecondRunOfTheStepChangesNothing`, alone; the line is under Verification.
    - `[low]` `[patch]` The Rework 1 run record named 16 classes against the search's 110 — all 110 classes that hold a test ran green after the patches; the record says so.
  - Intent-alignment layer:
    - `[false]` `[reject]` The diff edits shared files the intent does not list — `Propose.cls`, `Installer.cls` and `Base.cls` are in none of the intent's Never or add-only lists, and the lead ruling (b) places the fix in `Kernel/**`.
    - `[low]` `[reject]` The tests exercise the store, not the person's route, the draft or other tools — the person's route stores no proposal, the draft reads `TargetRef` whole, and the 110-class run drives the changed sibling cancel through other tools' confirms.
    - `[low]` `[reject]` `Ledger.Target` is cut at 256 — pre-existing for every tool and untouched; the outcome lines name each message.
    - `[false]` `[reject]` The cut ceiling of 2,200 against the largest resend target — 1,999 characters of ids plus the type, separators and a namespace name come to about 2,080 (inference: a namespace name is at most 64 characters), and a longer target is now refused.
    - `[low]` `[reject]` Rows stored before the change are not found until the step has run — documented at `TargetKey`; the step runs before `installed` is recorded, and a row lives ten minutes.
    - `[false]` `[reject]` No step roster to update — an observation, no bad outcome.
    - `[low]` `[reject]` `ProposalTargetKey` has no entry in `ci-timings.json` — the merge gate refreshes the file, and `ui/tools/ci.test.mjs` (green) holds the class equal to its arming line.

### 2026-10-15 — Code review (rework re-review 1)

- scope: `2f564cff..a61b3b8f`. The open HIGH (long-set proposal target) is closed by ruling (b): `TestTheAgentsCardCarriesTheWholeCapOfAHundredMessages` and the 19-digit leg are green.
- verdicts: 24 raw findings in 15 entries — high 0, medium 4, low 8, false 3.
- patched: 5 (medium 2, low 3).
  - The build in `GuardedRebuildTargetKeys` now runs before any key is written, and only while a scoped row lacks its key, so a run that stops in the build or between the writes is finished by the next. On success the end state is the same in either order, and a failed build needs a fault seam, as the step's own failure does (above), so no test separates the orders. Its three `mutation:` lines were re-applied under the new order and each reddened its test alone (runs 1163, 1164 and 1165).
  - Slot roster test, the corrected `TARGETREFMAX` and `LongRef` comments, the confirm leg's answer line, and the 512-cut `mutation:` line.
- deferred: 2 medium, both `escalated owner=burndown` for the decision sheet — DW-2456 (`SCHEMAVERSION` and the downgrade direction) and DW-2457 (a target over 2,200 characters answers 500 `INTERNAL`).
- rejected: 8 (false 3, low 5), each with its reason under Review Findings.
- verified on `ocupilot-b-ci` (tree reloaded after the patches, every mutation reverted by syncing the worktree, compiled storage read back in declaration order):
  - green: `ProposalTargetKey` 7 (run 1167), `InteropResendLimits` 8 (run 1168), `ProposalSpelling` 5, `ExplorerWrite` 10, `TaskWire` 6 and `InstallTarget` 7;
  - `check-objectscript` clean.

## Design Notes

**Governing ADs:**

- **AD-62:** items 2, 3, 5, 6 and 12, items 15 and 16 as consumed, and item 17 (drafted below).
- **AD-51:** the port-composed `RESEND`/`EDIT` reads, the declared fingerprint subjects, and the reviewed digest.
- **AD-53:** two callers, plus the dry-run route, drafted below.
- **AD-22:** both keys `false`.
- **AD-10:** `interop-message` is already `ReviewedFewOnly`, and no self-protection target exists. OcuPilot runs no production.
- **AD-15:** the vendor audits. **AD-14:** `created`.
- **AD-6** and **AD-34:** the set is one canonical target, held by both callers.
- **AD-52:** `InteropPort` is the declared port.
- **AD-56:** only declared values; `Reviewed` is the person's only.
- **AD-7:** one request.
- **AD-8:** pairs.
- **AD-44:** classic pages.
- **AD-29:** the gate.
- **AD-13:** the integerset rule.
- **AD-58:** the read-back is `nothingSent`, as for 20.23.
- **AD-59:** snippets.
- **AD-11** and **AD-60:** untrusted text.

Checked, with nothing to add: AD-21 (no path), AD-26, AD-27, AD-47 and AD-63.

**Measured at this plan on `ocupilot-b-ci`** (2026-10-13 and 14 UTC, USER, probe production; image 2026.2). The probe was created, run and removed:

- **Removal.** Every header, log row, `Ens.Request` and HL7 body was deleted, and the removal verified: 0, 0, 0 and 0, with `Gone()` reading 1, no production and no queue.
- **What stays.** 103 `%Ensemble/%Message/Resend` audit rows stay on the throwaway, as audit rows do.

- **The new header.** A resend kept the session (13).
  - The new header read `Resent` 1 (session max + 1), Description `Resent 13`, `CorrespondingMessageId` `""`, and the **same body id** as the original.
  - The original was unchanged.
- **Timing.** The first resend took 51 ms, and 100 more took 12 ms in total.
- **Audit.** One `%Ensemble/%Message/Resend` row per resend, naming the new header id, its body class and id, and the session. The query `WHERE Event='Resend'` found all 101 rows.
- **A disabled target.** `EnableConfigItem(op,0,1)` left the item's `QueueName` set. The resend answered OK and the message waited in its queue until the item was enabled again. This is the silent success the `targetoff` verdict refuses.
- **The vendor's answers:**
  - an unknown id: `ERROR #5809 … Ens.MessageHeader … '999999'`;
  - an unknown new target: `Target config item 'NoSuchItem' is not running`;
  - a stopped production: `<Ens>ErrProductionNotRunning`.
- **HL7.** The clone, `Clear()`, `ImportFromLibraryStream` over `%Stream.TmpCharacter`, `Separators`, `CopyValues` and `%Save` gave a new body id. It kept `DocType` `2.5:ADT_A01` and carried the new PID, and the original was unchanged.
  - `Clear()` empties `Source`, so the annotation is set after it, as the vendor does.
  - A resend with that body made the new header name it (`EnsLib.HL7.Message:2`).
- **Not measured here** (Task 0): least privilege, the reply queue, and `targetoff` through `ResolveItem`.

**Decisions:**

- **The person's double gate is a route, not a dialog-only check.** `ScreenAction.Preview` already resolves an action and stops before the write, computing the very `diff` the agent's card shows. The route returns it, so "the same dry run" holds by construction.
  - *Rejected:* `GET …/impact`, because a query string cannot carry an edited body.
  - *Rejected:* a dialog-side diff, because only the instance can judge the verdicts and parse the text.
- **The review binds Confirm through a digest.** It is the agent's stored `Digest` or the person's `Reviewed`, as 20.23's abort-all binds the agent. Without it, a person's Confirm would act on fresh verdicts the person never saw.
- **Partial sets resend the eligible members.** The other lines say why they are not resent, as the classic page and the sibling continue per message. A set with none eligible is refused, with the reasons in the problem text.
- **Keys `false`.** A resend delivers a copy that cannot be recalled, which is `Write.cls`'s definition of destructive. The sibling marks it `destructiveHint` and disabled too. Edit is at least as guarded: it needs every resend pair plus edit and contents. So 20.12's resend workflow needs an administrator to enable the key first (named).
- **Edit kinds.** HL7 v2 documents are edited as the vendor's edit page does. Object bodies follow its AutoForm rule, which 20.6's `ClassFieldsHere` already encodes. Other document kinds have vendor-specific copy rules (X12 copies `ParentId`, `Source`, `OriginalDocId` and `Envelope`), unmeasured here, so they are a named limit.
- **The Header tab's actions are page-drawn**, as 20.6's Test tab is. Its rows are properties, not messages, so a row action has no row to name.
- **`interop-message:integerset`** makes `13,12` and `12,13` one target, as the process and document sets are. A single valid id is unchanged.
- **`SCHEMAVERSION` does not move for `Propose.TargetKey`.** Every older row reads the new column as unset, and `Installer.EnsureProposalTargetKeys` gives it a value on every install before the install records `installed`, so no stored row changes meaning. A migration step runs once per version and this step is idempotent, so it is an install step. `TargetKey` is declared after every other property because the class has no Storage section: the compiler numbers data slots by declaration order, and a property declared earlier shifts every later column of every stored row (measured on `ocupilot-b-ci`: `State` read `0` until the property moved to the end).

**Codes** (each published once, in EXPERIENCE.md :604 and `strings.ts`):

- `INTEROP.RESEND.NONE` (409): "None of these messages can be resent now."
- `INTEROP.RESEND.CHANGED` (409): "These messages changed after they were reviewed, so nothing was resent. Review them again."
- `INTEROP.EDIT.NOTEDITABLE` (409): "OcuPilot can edit an HL7 v2 message or the plain fields of a message object, not this message's body. Use the classic Edit and Resend page for it."
- `INTEROP.EDIT.NOCHANGE` (409): "This edit changes nothing in the message. Use Resend to send it again as it is."
- `INTEROP.EDIT.FIELD` (422): "The message body has no such field that an edit can set."
- `INTEROP.EDIT.SECRET` (422): "This field names a credential, so OcuPilot does not change it."
- `INTEROP.EDIT.VALUE` (422): "This value is not valid for the field."
- **Consequences:**
  - `INTEROP.MESSAGE.RESEND`: "Resending sends each message marked to be resent to its target again, as a new message in the same session. A message that was already delivered is delivered twice. It cannot be undone."
  - `INTEROP.MESSAGE.EDITRESEND`: "Edit and resend saves the edited body as a new copy and sends it to the message's target as a new message in the same session. The original message and body stay as they were. It cannot be undone."
- **Verdict sentences:**
  - `resend` "will be resent"
  - `gone` "no longer exists"
  - `nobody` "its body no longer exists"
  - `targetoff` "its target is not an enabled item of the running production"
  - `noreplyqueue` "the queue its reply would go to no longer exists"

**Strings** (about 25 literals; values checked unique at Task 0):

- The seven code sentences, two consequences and five verdicts above.
- The labels "Resend" and "Edit and resend".
- The dialogs' consequences are the two consequence sentences' own keys. Strings hold no second copy, because values are unique.
- `interopEditResendHeading` "Edit and resend message", and `interopEditResendReview` "Review".
- `interopResendOutcome` "resent as", and `interopResendFailed` "not resent".
- `interopMessagesEmptyAgent` "Or ask the agent to find and resend messages."

**Spine and UX drafts (Rule 20; the runner writes them at the gate):**

- **AD-62, item 17**, "Resend and edit-and-resend (Story 20.31)":
  - `InteropPort` gains `RESEND`/`RESENDMESSAGES` and `EDIT`/`EDITRESEND` on `Messages`. Each is action-style over its port-composed read and calls `Ens.MessageHeader.ResendDuplicatedMessage` in process, which checks no privilege.
  - Before any vendor call, the port refuses a stopped production and judges each message: gone, a body no longer present, a request whose target is not an enabled item of the running production (measured: the vendor queues it and answers OK), or a response whose reply queue no longer exists.
  - It resends exactly the reviewed `resend` members, at most 100 per action, refused beyond and never truncated, in ascending ID order, continuing past a vendor failure.
  - An edit saves a clone of the original body with the changed fields applied (an HL7 v2 document as the vendor's edit does) and resends the original with it. Its read records `ViewContents`.
  - Both are destructive. The vendor audits each new header.
- **AD-53, a clause:** "A screen action whose tool declares `DRYRUN` is reviewed through `POST /screens/:screen/dryrun`, which resolves it as the action route does and stops before the write, answering the rows the agent's card shows. The person's action then carries the reviewed digest, and the port refuses it when the verdicts moved (Story 20.31)."
- **AD-51, a case:** "`InteropPort` answers the resend tools' fresh reads through port-composed `RESEND` and `EDIT` types, takes the reviewed digest from the stored payload or the person's `Reviewed`, and builds the edited body from the declared `Fields`."
- **AD-8, a clause:** "Resend requires `%Ens_MessageResend:USE`, and edit also `%Ens_MessageContent:USE` and `%Ens_MessageEditResend:USE`, with WRITE on the globals database (Task 0 measured)."
- **AD-44, a clause:** "The resend tools declare `EnsPortal.MessageResend`, and edit `EnsPortal.MessageResendEdit` too."
- **AD-13, a clause:** "`interop-message` takes the integerset rule (Story 20.31)."
- **AD-22, a note:** "Both resend keys ship `false`."
- **EXPERIENCE.md:** :173 and :604, as Tasks says.

**Integration, Consumes, Consumed-by (Rules 1 and 2):**

- **Integration:** AC8. 20.30's trace reads this story's new header in its session, on a real production. The dry-run route's consumers in this story are its two dialogs.
- **Consumes:**
  - from 20.9: the list, the Header tab, `MESSAGEPAIRS`, the id check and `RenderTargetHere`'s raw view;
  - from 20.30: `interop.messagetrace.read`;
  - from 20.6: `ClassFieldsHere`, `ParseTestFields`, `SecretPath`, the field loop and the Test dialog;
  - from 20.23: the action-write shape and `DIGESTKEY`;
  - 16.6's set target, 19.x's `Preview`, `ExplorerSaveMint.Hunk` and `ProductionProbe`.
- **Consumed-by:**
  - 20.12, whose resend-failed-messages workflow proposes `interop.messages.resend` (its key enabled first);
  - any later `DRYRUN` tool.

**Rule 31 (extend, don't copy):**

- **Tools:** both extend `InteropMessageAction`, which extends `InteropAction`. `PortQuery` repeats `InteropQueueAbort`'s one line, which reads better than a parent switch every interop tool would carry.
- **Port:**
  - `ApplyFieldsHere` is extracted from `BuildTestRequestHere` and shared.
  - `ClassFieldsHere`, `ParseTestFields`, `SecretPath`, `RenderTargetHere`, `ResolveItem`, `ReadState` and `SqlRows` are reused.
  - `CanonicalFields` gains a keep-empty flag, because an edit may clear a field.
  - `MessageVerdict` sits beside `RuntimeRefusal`, because its inputs differ.
- **Routes:** the dry-run route reuses `Resolve`, through one public wrapper.
- **Client:**
  - The typed-name dialog and the Test dialog gain inputs rather than being copied.
  - The page follows `interop-item-test.page.ts`.
  - The handler's dry run mirrors `impactFor`.
- **Tests** reuse `MintAs`, `ConfirmHttp`, `InteropItemGate`, `GovernanceFixture`, `ImpactRoute`'s shape and `ProductionProbe`. They are new classes because the siblings are at about 500 lines.

**Contended files (Rule 11).** `origin/OCU-1-epic18` (`5fa674b7`, merge base `6c24da93`) carries no unmerged change to any file below.

- **Add-only edits:**
  - `Kernel/Governance/Baseline.cls`;
  - `Test/ReadTool.cls`, `Test/SurfaceCoverage.cls`, `Test/ToolRoundTrip.cls`, `Test/ToolWrite.cls`;
  - `strings.ts`, `screen-actions.ts`, `screen-outlet.ts`, `screens.generated.ts` (regenerated);
  - EXPERIENCE.md and the spine.
- **Shared files outside the contended list,** also add-only: `Kernel/EntityRef.cls`, `Screen/Tool/Write.cls`, `Api/ScreenAction.cls` and `Api/Router.cls`.
- **Footprint extensions:** `Api/Router.cls`, `Api/ScreenAction.cls`, `Api/ScreenDryRun.cls`, `Kernel/EntityRef.cls`, `Screen/Tool/Write.cls`, `shell/typed-name-dialog.ts`, `shell/screen-action-handler.ts`, `shell/screen-action-dialogs.ts`, `Test/EndpointCoverage.cls` and `Test/EntityRef.cls`.
- **No Rule 11 ask.**

**Split (`multiple-goals`).** The seam is edit-and-resend:

- **It would move to a following story:** `EDIT`/`EDITRESEND`, `InteropMessageEditResend`, `ApplyFieldsHere`, the edit codes, the Test dialog's inputs, the Header page's `editresend`, `InteropEditResend`, and AC5.
- **This story would keep** resend and the shared plumbing: the route, the digest, the dialog review, the verdicts, the gate and the fixture.
- **The recommendation is not to split.** The plumbing is most of the work, and both halves fit the epic's story sizes (20.22, 20.23 and 20.27).

**Gate questions (for the orchestrator; neither blocks):**

- **Q1, split.**
  - (A) Keep one story. Recommended.
  - (B) Split at the seam above. The lead moves the edit tasks into a story after this one.
- **Q2, resend options and edit kinds.**
  - (A) As planned. No new target, no head of queue and no filtered resend. Edit only HL7 v2 documents and object fields. Each is a named limit. Recommended.
  - (B) Add head of queue (one value, small) and a new target (one value, plus a response verdict).
  - (C) Add X12, EDIFACT and ASTM edits, each to be measured.

**Named limits:**

- No new target, head of queue or "resend all matching". The agent reads ids first, at most 100.
- Edit covers HL7 v2 documents and the fields AutoForm offers. A document over 1,000,000 characters is refused.
- Two overlapping but different sets are two targets. Both may resend a shared message, as the classic page lets two people do.
- A message to an enabled but temporarily stopped item waits in its queue.
- The reply to a resent synchronous request goes to its caller's reply queue. When that caller no longer waits, the vendor discards the reply (inference, read in `Ens.Queue.EnQueue`).
- 20.12's workflow needs the key enabled.

**Ledger inbox (Rule 17):** none (`slice` is empty).

## Verification

**Shared surfaces:**

- the tool rosters: `ReadTool`, `ToolRoundTrip`, `ToolEmit`, `SurfaceCoverage`, and `ToolWrite`'s other-port count, 49→51 (DW-2407);
- `ClassicPageGate`, `MappingDescriptor`, `GovernanceBaseline`, `Governance`, `ToolDispatch` and `Test/Prohibited`'s composed `$Case`;
- `EndpointCoverage`, `Test/EntityRef` and the mirror's id rules;
- 20.9's `InteropMessageDescriptor` declarations;
- the handler maps, the typed-name and Test dialogs' inputs, and `screen-outlet`'s map;
- the strings table and EXPERIENCE.md :173 and :604.

Not moved: `InteropFloor` (no principal holds a write tool; confirm in the sweep), `StageTwoTools` (no new screen) and `Kernel/Proposal/Prohibited.cls`.

*Every test added or changed passes on a fresh environment, in either order.* Every message a test reads is one it made. It is removed by the class's own mark, and no test asserts on a store being empty.

**Setup (slot B; never the dev instance `ocupilot-slot-b`):**

- **Load `src`:**
  1. Run `rsync -a --checksum --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-20/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`.
  2. In `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`, run `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)`.
- **Before any browser run:** `cd ui && npm run build && docker exec ocupilot-b-ci sh -c 'cd /durable/iris/csp/ocupilot && rm -rf ./*' && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`.

**Commands.** Run each in the foreground with `timeout: 600000`, one at a time. Read each class's result from `%UnitTest_Result`.

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<Class>`, one call per class:
  - `InteropResendDescriptor`, `DryRunRoute`, `InteropResend`, `InteropEditResend` and `InteropResendGate`;
  - then `ToolWrite`, `ReadTool`, `ToolRoundTrip`, `SurfaceCoverage`, `ToolEmit`, `ClassicPageGate`, `MappingDescriptor`, `GovernanceBaseline`, `Governance`, `ToolDispatch`, `Prohibited`, `EndpointCoverage`, `EntityRef`, `InteropMessageDescriptor`, `InteropFloor`, `CompileWithoutInterop`, `ImpactRoute` and every class the sweep changes.
  - Expected: green.
- `(loop)` `cd ui && npm run test:tools`, then `cd ui && npm run test:components`. Expected: green.
- `(loop)` `cd ui && npm run build -- --verbose`. Expected: the prebuild chain is green, the Header page's chunk is under 88 kB, and the initial total is under 1992kB. Record both.
- `(loop)` `uv run scripts/check-objectscript.py <each changed .cls>` and `bash scripts/lint-docs.sh`. Expected: clean.
- `(loop)` `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/<file>`, one file per call, after the redeploy. Expected: green.
  - `interop-message-resend.browser-spec.mjs`
  - `interop-messages.browser-spec.mjs` (20.9's)
- `(loop)` Rework 1, after the `src` reload and with `ci-runner.mjs --class` repeated per call, in batches of about 8 minutes (`ui/tools/ci-timings.json`): `InteropResendLimits`, `InteropResend`, `InteropEditResend`, `DryRunRoute`, the new store class, every class under `src/OcuPilot/Test` that names `Kernel.State.Propose`, `GuardedClaimAndClose` or `ProposalTargetIdx`, and the installer's upgrade classes (`Installer`, `Version`, `MigrateFault`, `InstallMark`, `ContainerStartNamespace`). Expected: green.
- **Lead-owned (the runner's):** the full ObjectScript sweep, `cd ui && npm test`, `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`, and Rule 30's fresh check.
- **Left to CI:** the full browser suite.

**Planned pinning mutations (Rule 19).** Revert each byte-identical. Reload, or rebuild and redeploy, before the next.

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | `MessageVerdict` returns `resend` for a disabled target | `InteropResend`'s mixed leg, and the browser AC1 (four sent) |
| AC1 | The handler opens the typed-name dialog without the dry run | `screen-action-handler.spec.ts`, and the browser AC1 (no review lines) |
| AC2 | `RESENDMAX` 1000 | `InteropResendDescriptor` (descriptor max equals port max), and `InteropResend`'s 101 leg |
| AC3 | `FINGERPRINTSUBJECT` drops `Verdicts` | `InteropResend`'s target-changed leg |
| AC4 | The write ignores `DIGESTKEY` | `InteropResend`'s CHANGED leg, and the browser AC4 |
| AC5 | `EDITRESEND` saves the edit onto the original body | `InteropEditResend`'s "original unchanged" leg, and the browser AC5 |
| AC5 | The HL7 path skips `Clear()` | `InteropEditResend`'s HL7 segments leg |
| AC6 | `RESENDPAIR` is removed from `Pairs` | `InteropResendGate`, alone |
| AC6 | `AuditViewMessage` is removed from `EDIT` | `InteropEditResend`'s audit leg, alone |
| AC7 | One `SurfaceCoverage` row is removed | `SurfaceCoverage`, alone |
| AC7 | A key ships `true` | `InteropResendDescriptor` and `GovernanceBaseline` |
| AC8 | `RESENDMESSAGES` answers each id as resent without calling the vendor | `InteropResend`'s trace leg, and the browser AC8 |

**Task 0 results (implement pass, `ocupilot-b-ci`).**

- Task 0: re-anchored on the shipped 20.9 and 20.30 code. `InteropMessageList` and `InteropMessageHeaderTab` declared no action, `MESSAGEPAIRS`, the id check, `MessageRow`, the `Messages` `InvokeRuntime` branch and `InteropMessageDescriptor`'s no-action pins read as the Code Map names them. The Header tab had no page of its own (`screen-outlet.ts` held no entry for it), so `interop-message-header.page.ts` is new. `strings.ts` held 3,478 literals and holds 3,499 now, under the bound of 3,800, and all 21 new values were unique. EXPERIENCE.md :173 and :604 now hold the story's clauses.
- Task 0: least privilege. A principal holding `%DB_USER:RW` and the code database's READ, and no Ensemble resource, completes the vendor's `Ens.MessageHeader.ResendDuplicatedMessage` (new header 1195): the vendor checks no privilege. Through the port, `InteropResendGate` shows the exact principal completing resend and edit with the pairs the plan names, and `OcuS31NoWrite` (`%DB_USER:R`) refused naming `%DB_USER:WRITE`.
- Task 0: reply queue. A response header whose `TargetQueueName` names no queue reads `noreplyqueue` through the port (`InteropResend.TestEachMessageIsJudgedAndOnlyTheOnesThatCanGoAreSent`), and the vendor answers `ERROR <Ens>ErrGeneral: Target reply queue 'OcuPilotProbeNoQueue' no longer exists`.
- Task 0: a disabled item's request reads `targetoff` through `GatherItems`' effective `Enabled`, which is the production-item read the port already composes; the plan named `ResolveItem`, whose result is for one item and needs a production id.
- Task 0: `%SYS.Portal.Resources.NormalizePage` spells `EnsPortal.MessageResend` and `EnsPortal.MessageResendEdit` as the tools declare them (`InteropResendDescriptor.TestTheTwoToolsDeclareWhatThePlanNames`).
- Task 0: one HTTP confirm per new tool answers exactly one envelope (`InteropResend.TestTheAgentsResendConfirmsOverHttp` and `InteropEditResend.TestTheAgentsEditAndResendConfirmsOverHttp` count `}{` in the raw body).
- build: `npm run build -- --verbose` is green through the seven prebuild checkers. The Header page's chunk is 5.11 kB raw (1.92 kB transferred), against the 88 kB bound. The initial total is 1.96 MB raw (349.57 kB transferred), against 1992 kB. No 2500 kB warning.

**Demonstrated mutations (Rule 19, implement pass).** Each was applied on `ocupilot-b-ci`, read red, and reverted byte-identical (checked by SHA-256); an ObjectScript one reloaded the whole tree, a client one rebuilt and redeployed the bundle for the browser leg.

- mutation: AC1, `MessageVerdict` reads `resend` for a disabled target -> `InteropResend` (five tests: the mixed, none-to-send, target-changed, person and draft legs), `InteropResendDescriptor.TestTheVerdictMatrixAndItsOrder`, and browser AC1 (the fourth line reads will-be-resent).
- mutation: AC1, `startDryRun` opens the typed-name dialog without the dry run -> `screen-action-handler-resend.spec.ts` (four tests), and browser AC1 (no review lines: the wait for `[data-ocu-review] li` times out).
- mutation: AC2, `RESENDMAX` 1000 -> `InteropResendDescriptor` (`TestTheMessageSetAndItsDigest`, `TestTheScreensDeclareTheirActionsAndTheCap`) and `InteropResend.TestASetOverTheCapOrMalformedIsRefusedWholeAndNothingIsSent`.
- mutation: AC3, `FINGERPRINTSUBJECT` drops `Verdicts` -> `InteropResend`, eight of its nine tests, the target-changed one among them. The tool cannot read its own state marker without the subject, so the dry run answers `INTERNAL`; the mutation fails closed.
- mutation: AC4, the write ignores `DIGESTKEY` -> `InteropResend.TestThePersonsResendIsReviewedThenSentAndRefusedWhenTheVerdictsMove`, `InteropEditResend.TestThePersonsEditAndResendReviewsTheFormThenTheChange`, and browser AC4.
- mutation: AC5, the edit is saved onto the original body (`tClone = tOriginal`) -> `InteropEditResend` (the agent's, the person's and the every-shape tests, the last on the embedded city), and browser AC5.
- mutation: AC5, the HL7 path skips `Clear()` -> `InteropEditResend.TestAnHl7MessageIsEditedThroughItsContent`, alone: the dropped PID segment stays on the copy.
- mutation: AC6, `RESENDPAIR` removed from the resend branch of `Pairs` -> `InteropResendGate.TestEachMissingPairIsRefusedByNameThroughThePort`, and also `InteropResendDescriptor.TestThePortServesTheFourTypesAndAsksTheirPairs`, which pins the pair lists.
- mutation: AC6, `AuditViewHere` removed from `EditBodyFacts` -> `InteropEditResend.TestEachEditReadThatOpensABodyIsAuditedOnce` and `TestWhatCannotBeEditedIsRefusedWithNothingSent`.
- mutation: AC7, one `SurfaceCoverage` row removed -> `SurfaceCoverage.TestEveryWriteToolHasACoverageRowAndBack`, alone (`ToolWrite` and `ReadTool` stayed green).
- mutation: AC7, `interop.messages.resend` ships `true` -> `InteropResendDescriptor.TestTheTwoToolsDeclareWhatThePlanNames`, `GovernanceBaseline.TestThePurgeIsTheOneDisabledLine` and `Governance.TestTheDefaultEnablesEveryWriteButTheBaselineDisabled`.
- mutation: AC8, `PerformResend` answers each id as resent without calling the vendor -> `InteropResend` (the vendor-refusal, the agent's and the person's tests), and browser AC8.
- mutation: the typed-name review drawn through `innerHTML` -> `typed-name-dialog.spec.ts`'s review test. `keepSelection` dropped from the Header page's store subscription -> `interop-message-header.page.spec.ts`'s selection test. The Test dialog's `values` prefill dropped -> `interop-item-test-dialog-edit.spec.ts` (two tests).
- mutation: structural, `.ocu-dialog-review`'s `color` set to its own background -> the browser structural leg (a contrast entry). A `width: 2000px` on the list did not redden it: the dialog scrolls its content, so that was not kept as the mutation.

**Review-pass mutations (Rule 19).** Each was applied on `ocupilot-b-ci` to `InteropPort.cls` (reloaded whole), read red, and reverted byte-identical (SHA-256 `233b032d...` before and after).

- mutation: AC5, `ReadEdit` shows a credential-named field's stored value in the form -> `InteropEditResend.TestEveryFieldShapeIsEditedOnACloneAndTheOriginalIsLeftAlone`, alone. `ReadEdit` echoing a credential-named member of `Fields` -> the same test, alone.
- mutation: AC4, `ReadEdit` sets `Original` to `""` -> `InteropEditResend.TestABodyEditedAfterTheReviewIsRefusedForThePersonAndTheAgent`, alone.
- mutation: AC5, `EditCloneHere` keeps the copy the vendor refused after the save -> `InteropEditResend.TestACopyTheVendorRefusedAfterTheSaveIsDeleted`, alone.
- mutation: AD-59, `MessageSnippet` drops the `Clear()` line of its document branch -> `InteropEditResend.TestTheCopyOutDraftOfAnHl7EditRendersItsScriptAndRunningItDoesTheSame`, alone.
- mutation: AC1, `ReadEdit` drops its not-running refusal -> `InteropEditResend.TestAStoppedProductionIsRefusedByTheEditReadReviewAndWrite`, alone.
- mutation: AC6, `PerformResend` and `PerformEditResend` each record an OcuPilot `ConfigChange` row -> `InteropResend.TestTheAgentsResendConfirmsOverHttp` and `InteropEditResend.TestTheAgentsEditAndResendConfirmsOverHttp`, each alone.
- mutation: AC2, `ReadResend` refuses a set naming `message` in place of `Messages` -> `InteropResend.TestASetOverTheCapOrMalformedIsRefusedWholeAndNothingIsSent`, alone.

**QA pass (Rule 19).** Each ObjectScript mutation was applied on `ocupilot-b-ci` with the tree reloaded, and each client one under `ng test --include <spec>`; every one read red and was reverted byte-identical (SHA-256 before and after).

- (QA) tests added, all armed and listed on the `# classes:` line of `scripts/ci-throwaway.sh` (`ui/tools/ci.test.mjs` DW-1276 holds the line equal to the classes that declare the variable): `src/OcuPilot/Test/InteropResendLimits.cls` (6 tests: the cap at 100 and 101 on real messages, a forged or foreign digest, each key off then on then put back, the outcome line of a refused message), `src/OcuPilot/Test/InteropResendSweep.cls` (2 tests: the sweep of `ProductionProbe`), and two tests added to `src/OcuPilot/Test/InteropEditResend.cls` (now 13: a forged or foreign digest for the edit, and an edit refused at the review and at the mint).
- (QA) `InteropResendLimits.TestTheAgentsCardCarriesTheWholeCapOfAHundredMessages` is red on the shipped code: the agent's mint of 100 messages answers `INTERNAL` because the proposal target (type, scope and the ids) exceeds the proposal store's index subscript. The same test is green with 60 messages, so its assertions are sound; a mutation does not apply to a test that is red unmutated.
- (QA) mutation: AC2, `RESENDMAX` 99, and again 101 -> `InteropResendLimits.TestAHundredMessagesGoAndAHundredAndOneAreRefusedWholeWithNothingSent`.
- (QA) mutation: AC4, `ReadResend` compares the first 8 characters of the digest -> `InteropResendLimits.TestAForgedTruncatedOrForeignDigestIsRefusedAndOnlyTheReviewedOneSends`, alone.
- (QA) mutation: AC4, `ReadEdit` compares the first 8 characters of the digest -> `InteropEditResend.TestAForgedTruncatedOrForeignDigestIsRefusedForTheEditAndOnlyTheReviewedOneSends`, alone.
- (QA) mutation: AC5, `ReadEdit` drops the credential-named test of its object branch -> `InteropEditResend.TestWhatAnEditRefusesIsRefusedTheSameAtTheReviewAndTheMint` and `TestWhatCannotBeEditedIsRefusedWithNothingSent`; `InteropMessageEditResend.PortQuery` drops the action key (the review and the mint read leniently) -> `TestWhatAnEditRefusesIsRefusedTheSameAtTheReviewAndTheMint` and `TestThePersonsEditAndResendReviewsTheFormThenTheChange`, while the port-level test stays green.
- (QA) mutation: AC3, `interop.messages.resend` ships `true` -> `InteropResendLimits.TestTheResendKeyAloneDecidesWhetherTheAgentMintsAndAPersonIsNeverAsked`, alone; `interop.messageheader.editresend` ships `true` -> `TestTheEditKeyAloneDecidesWhetherTheAgentMintsAndAPersonIsNeverAsked`, alone.
- (QA) mutation: AC1, `InteropMessageAction.WriteOutput` reads every entry as sent -> `InteropResendLimits.TestAVendorRefusalReadsNotResentWithTheVendorsTextOnTheOutcome`, alone.
- (QA) mutation: AC7, one class dropped from the `# classes:` line -> `ui/tools/ci.test.mjs` DW-1276, alone.
- (QA) mutation: `SweepSince` reads the body class in upper case -> `InteropResendSweep.TestTheSweepRemovesWhatAboveTheMarkAndKeepsWhatAHeaderBelowItNames`, alone; deletes a body without asking whether a header still names it -> the same test, alone; accepts any mark -> `InteropResendSweep.TestAMarkThatIsNotAPairOfNumbersSweepsNothing`, alone.
- (QA) mutation: client, each reverted byte-identical: `OutcomeDialog` drops `(closed)` -> `outcome-dialog.spec.ts` closes-on-Close, alone; draws the list for a refusal -> its refusal test, alone; draws a line through `innerHTML` -> its text test, alone; the Header page sends every field in place of the changed ones -> `interop-message-header.page.spec.ts` changed-fields test, alone; the Header page leaves the form open for the review -> the same test, alone; `DESCRIPTOR_PAGES` drops the Header tab -> `screen-outlet.spec.ts` Header-page test, alone; `dryRunFor` drops the `DRY_RUN_ACTIONS` test -> `screen-action-handler-resend.spec.ts` listed-actions test, alone; the mirror declares `max` 101 -> `screen-action-handler-resend.spec.ts` cap test, alone.

**Code-review pass (Rule 19).** Each mutation was applied on `ocupilot-b-ci`, with the whole tree reloaded (or, for the client, under `ng test --include`). Each read red and was reverted byte-identical (SHA-256 checked).

- (CR) mutation: AC5, `CanonicalFields` ignores its keep-empty flag -> `InteropResendLimits.TestAnEditThatClearsAFieldSendsACopyWithTheFieldEmpty`, alone beside the open HIGH's test.
- (CR) mutation: AD-59, `MessageSnippet` renders each resend line behind `If 0` -> `InteropResend.TestTheCopyOutDraftOfAResendRendersItsScriptAndRunningItDoesTheSame`, alone (each session gained 0); ends the resend script with an error status -> the same test, alone ("the script runs").
- (CR) mutation: AD-34, `ScreenAction.Run` takes the hold for a preview too -> `DryRunRoute.TestTheAnswerIsRowsAndReviewAndTheRowsAreTheAgentsCardRows`, alone.
- (CR) mutation: client, `reviewLinesOf` splits a text without ending its closing line feed -> `screen-action-handler-resend.spec.ts` document-edit test, alone.

**Rework 1 pass (Rule 19).** Each mutation was applied to the copy of the tree on `ocupilot-b-ci`, the tree reloaded, and reverted by syncing the worktree back (the proposal index rebuilt); the worktree files were never touched, and SHA-256 of the changed files matched before and after.

- mutation: AD-6/AD-13, `ProposalTargetIdx` keyed by `TargetRef` again -> `ProposalTargetKey` (`TestTheKeyIsTheDigestOfTheTargetAndALongTargetIsStoredWhole`, the sibling-cancel test and the legacy-row test) and `InteropResendLimits` (`TestTheAgentsCardCarriesTheWholeCapOfAHundredMessages` and the 19-digit leg).
- mutation: AD-34, the sibling update's `%EXACT(TargetRef)` test made always true -> `ProposalTargetKey.TestASiblingCancelClosesItsSiblingsByTheExactTargetAndLeavesOthersAlone`, alone.
- mutation: AD-17, `EnsureProposalTargetKeys` a no-op -> `ProposalTargetKey.TestARowStoredBeforeTheKeyExistedIsFoundBySiblingCancelOnceTheStepHasRun` and `TestTheProductionInstallGivesAStoredProposalItsKey`.
- mutation: AD-17, `GuardedRebuildTargetKeys` skips `GuardedBuildIndices` -> `TestARowStoredBeforeTheKeyExistedIsFoundBySiblingCancelOnceTheStepHasRun`, alone (the entry the old definition left stays).
- mutation: AD-17, `GuardedRebuildTargetKeys` builds the index on every run -> `ProposalTargetKey.TestASecondRunOfTheStepChangesNothing`, alone.
- mutation: AD-17, `Install` no longer calls `EnsureProposalTargetKeys` -> `ProposalTargetKey.TestTheProductionInstallGivesAStoredProposalItsKey`, alone.
- mutation: AC2/AC3, `GuardedMint` cuts the stored target at 512 -> `InteropResendLimits.TestAHundredIdsOfNineteenDigitsAreMintedStoredWholeAndConfirmedForTheAgent`, alone in its class (the confirm 409s, nothing is sent and no answer line comes back), and `ProposalTargetKey`'s `TestTheKeyIsTheDigestOfTheTargetAndALongTargetIsStoredWhole`, `TestASiblingCancelClosesItsSiblingsByTheExactTargetAndLeavesOthersAlone` and `TestATargetOverTheLimitIsRefusedAtTheMintAndTheLimitItselfIsStoredWhole` (code review, runs 1161 and 1162).
- mutation: Conventions › new properties on a stored class, `TargetKey` declared directly after `TargetRef` -> `ProposalTargetKey.TestARowStoredBeforeTheKeyKeepsEachColumnInItsSlot` (slot 9 read `TargetKey`; code review, the method run alone so no stored row was written under the moved layout).
- mutation: AD-6, `GuardedMint` cuts a target over `TARGETREFMAX` in place of refusing it -> `ProposalTargetKey.TestATargetOverTheLimitIsRefusedAtTheMintAndTheLimitItselfIsStoredWhole`, alone.
- mutation: AD-17, `EnsureProposalTargetKeys` reports its two outcomes swapped -> `ProposalTargetKey.TestARowStoredBeforeTheKeyExistedIsFoundBySiblingCancelOnceTheStepHasRun` and `TestASecondRunOfTheStepChangesNothing`.
- mutation: AD-17, `GuardedRebuildTargetKeys` no longer skips a row with no target -> `ProposalTargetKey.TestASecondRunOfTheStepChangesNothing`, alone (the row is written and the index rebuilt on every run).
- Rework 1: on `ocupilot-b-ci` (tree reloaded after the review patches), green: the four resend classes, `ProposalTargetKey` 6, `Installer` 27, `Version` 19, `InstallMark` 6, `ContainerStartNamespace` 5, and every class under `src/OcuPilot/Test` that holds a test and names `Kernel.State.Propose`, `GuardedClaimAndClose` or `ProposalTargetIdx`: 110 classes and 996 tests in all. `MigrateFault` and five other classes of that search are fixtures and hold no test. `test:tools` 2033, `check-objectscript` and `lint-docs` clean.

## Auto Run Result

Status: done
Blocking condition: none

**This pass (rework 1).** Closes the one HIGH, the agent's proposal of a long resend set, by the lead's ruling (b).

- **Store.** `Kernel/State/Propose.cls`: `TargetRef` is `MAXLEN = 2200` (`TARGETREFMAX`), a stored computed `TargetKey` (`TargetLockKey(TargetRef)`, declared last because the class has no Storage section) keys `ProposalTargetIdx`, and the sibling cancel in `GuardedClaimAndClose` filters by the key of either spelling and then by the exact `TargetRef`. `GuardedMint` refuses a target over the limit and `GuardedRebuildTargetKeys` gives older rows their key. `Kernel/State/Base.cls` gains `GuardedBuildIndices`.
- **Install.** `Install/Installer.cls`: `EnsureProposalTargetKeys` runs on every install, idempotent. `SCHEMAVERSION` does not move (Design Notes).
- **Tests.** `Test/ProposalTargetKey.cls` (new, 6 tests, armed in `scripts/ci-throwaway.sh`) and `InteropResendLimits.TestAHundredIdsOfNineteenDigitsAreMintedStoredWholeAndConfirmedForTheAgent`; `TestTheAgentsCardCarriesTheWholeCapOfAHundredMessages` is green.
- **Review.** 14 findings: patched 5 (medium 1, low 4), deferred 0, rejected 9 (false 3, low 6), each with its reason in the Review Triage Log. The medium: a target over the limit was stored cut, and is now refused.
- **Verification (`ocupilot-b-ci`, tree reloaded after the patches).** 110 classes and 996 tests green (the search in `## Verification`), `test:tools` 2033, `check-objectscript` and `lint-docs` clean. Mutations are the Rework 1 lines under Verification, each reverted byte-identical.
- **Follow-up review recommended: false.** This pass patched no HIGH.
- **Residual risks.** A tool that names more than 2,200 characters of target gets a 500 `INTERNAL` at the mint, as every target over about 455 characters did before; `ExplorerWrite` can reach it with a long document set. `ci-timings.json` has no entry for `ProposalTargetKey`. The full ObjectScript sweep, `npm test`, the smoke and Rule 30's fresh check are the runner's.
