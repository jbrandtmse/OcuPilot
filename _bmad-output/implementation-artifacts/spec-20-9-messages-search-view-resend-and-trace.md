---
title: 'Story 20.9: Messages - search, view, resend and trace'
type: 'feature'
created: '2026-10-13'
status: 'done'
baseline_revision: 'a772580fb1ab78f68ef6de7c31469150121b3e1f'
baseline_commit: 'a772580fb1ab78f68ef6de7c31469150121b3e1f'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
warnings: [oversized, multiple-goals]
deferred:
  - summary: >-
      client-lint has no rule against `[innerHTML]`, so the Contents block's text-only drawing is pinned by its component spec and the browser leg alone.
    evidence: |-
      Measured on ocupilot-b-ci's tree: binding the block's text through `[innerHTML]` left `node tools/client-lint.mjs` clean; interop-message-contents.spec.ts and the browser AC3 went red.
    location: >-
      ui/tools/client-lint.mjs
    severity: low
  - summary: >-
      The Contents block ignores the command bar's filter and draws no Max rows control, so a message past the read's 1,000-line cap cannot be widened from the screen.
    evidence: |-
      The block draws the store's rows as read. The filter and the cap are the data table's own controls, which the `body` input replaces.
    location: >-
      ui/src/app/areas/interoperability/interop-message-contents.ts
    severity: low
  - summary: >-
      A failed view audit never failing the read is pinned by construction (a Try/Catch), not by a test.
    evidence: |-
      `$System.Security.Audit` drops an unregistered event silently, and `Ens.Util.Auditing.AuditViewMessage` has no input that makes it fail, so no test can reach the catch without a seam the port does not otherwise need.
    location: >-
      src/OcuPilot/Port/InteropPort.cls (AuditViewHere)
    severity: low
---

<intent-contract>

## Intent

**Problem:** A person investigating an incident still leaves for the classic Message Viewer (`EnsPortal.MessageViewer`) to find a message, read its header and contents, follow its session or resend it. OcuPilot shows only an item's newest headers (Story 20.4's Messages tab), with no search, no way to open a message and no contents.

**Approach (this spec is Part A; Design Notes › Split asks the orchestrator to move the trace and the resends to two stories):**

- **Search.** A listed screen, Messages, searches `Ens.MessageHeader` through `Port/InteropPort` by time window, status, type, source, target, body class, session and error flag. Rows are newest first and capped.
- **View.** Each row opens a parent-scoped tab group with two tabs.
  - Header lists the header's properties.
  - Contents shows the body as text, drawn by OcuPilot's own read-only renderer: the custom half the epic ships read-only first. The read records the vendor's own ViewContents audit event, as the classic Contents pane does.
- **Queue messages** (Stories 20.4 and 20.23) links each waiting message to its Header tab.
- **Saved searches** are not offered: no vendor saved search is one OcuPilot's search can run (Design Notes › Saved searches; Q2).
- **Part B (the session trace) and Part C (resend and edit-and-resend)** are chartered in Design Notes › Split.

## Boundaries & Constraints

**Always:**

- **Through the port.** Every read goes through `InteropPort.Invoke`, behind `Admit` (AD-29, AD-62 (2)).
  - The pairs come first, then READ on the namespace's globals database. A refusal names the failed pair.
  - The three endpoints take explicit `Pairs` branches ahead of the `CODEPAIRS` default.
- **SQL (AD-21, AD-29).**
  - Every statement over `Ens.MessageHeader` runs through `SqlRows` (`%ExecDirectNoPriv`), switched, with every value bound.
  - A WHERE fragment is a fixed string chosen by which criteria are present. No caller value is ever concatenated into SQL.
  - No statement nests a query that carries `TOP`. The window's ID bounds are separate top-level statements.
- **Message ids.** A message id is the header's `ID`, kept exactly: `^[1-9][0-9]{0,18}$` (AD-13).
  - An id no header holds reads as zero rows (AD-37).
  - Any other text is refused 400 `PORT.VALIDATION`, naming the criterion.
- **Contents.** The body is opened switched, and rendered only as text: `RenderTargetHere`'s kinds plus a character stream.
  - At most `TESTOUTPUTMAX` (1,000,000) characters. A line is cut at 4,000 characters with `TESTCUT`.
  - At most the read's row cap of lines, then `truncated`.
  - Text reaches the screen only as interpolated text (AD-11) and the model only through the sanitizer (AD-60).
- **Audit.** Each Contents read that opens a body calls `Ens.Util.Auditing.AuditViewMessage("OcuPilot", <header>, <body class>, <body id>)` before rendering.
  - It skips `Ens.AlarmRequest` and `Ens.AlarmResponse`, as `EnsPortal.MessageContents` does.
  - A failed audit never fails the read.
- **No compile-time interoperability** (AD-62 (12)). `Ens.*` is named only in method bodies and strings. No `OcuPilot.*` class is called while switched: the local-to-UTC conversion runs before the switch.
- **Descriptors.**
  - The three descriptors follow Tasks › Descriptors.
  - Strings live in `strings.ts` and EXPERIENCE.md's Fixed strings, with values unique.
  - Contended files take add-only edits (Design Notes › Contended files).

**Never:**

- A call to `%Api.InteropEditors`, or a request under `/ui/interop/` (AD-62 (1)). The vendor's message viewer is not embedded (Design Notes › Decisions).
- A write of any kind: no tool, governance key, change event or proposal. Resend and edit-and-resend are Part C.
- `Ens.Message.Search`, `Ens.Message.Utils` (`[Hidden]`) or either saved-search store.
- An edit control on the Contents tab.
- Edits to any of: `Screen/Read.cls`, `Kernel/EntityType.cls`, `Kernel/Proposal/Prohibited.cls`, `Kernel/Governance/Baseline.cls`, `Port/LogSourcePort.cls`, `app.routes.ts`, `angular.json`, `.github/workflows/ci.yml`, `ui/tools/ci-shards.mjs`, `ui/tools/ci-timings.json`, `ui/tools/ci.test.mjs`.
- A new armed test class.
- An edit to `Screen/Registry.cls` beyond `CriteriaProblem`'s searchable-endpoint clause, or to `ui/tools/screen-mirror.mjs` beyond its twin `criteriaProblem` and the `SEARCHENDPOINTS` reader.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Search | Messages in HSCUSTOM, with the default window (24 h) | Rows `{ID, TimeCreated, Status, Type, Source, Target, BodyClass, SessionId, Error}`, newest first. `TimeCreated` is local (`LocalStamp`) | - |
| Narrowed | `status` Error, `type`, `source`, `target`, `bodyClass`, `session`, `errors` yes or no, each alone or together | Only headers matching every given criterion | - |
| Window | `beginDateTime` and `endDateTime`, local | Headers between the first ID at or after the start and the last ID at or before the end (the classic viewer's conversion) | No header on one side means zero rows |
| Capped | More matches than `maxRows` | The newest `maxRows`, with `truncated` | - |
| Bad criterion | `session` not digits, `bodyClass` not a class name, or `beginDateTime` empty | Nothing is read | 400 `PORT.VALIDATION`, naming the criterion. A choice or datetime form is refused by `Screen/Read` |
| Open | A row's ID cell | `interoperability/messages/document/<ID>`. Header rows `{Message, Position, Name, Value}` for the 23 properties in Design Notes › Header, in order | - |
| Gone | An id no header holds | Header: "This message no longer exists." Contents: its empty sentence | - |
| Bad id | `message` not digits | - | 400 `PORT.VALIDATION`, naming `message` |
| XML body | `Ens.StringRequest` (or any `%XML.Adaptor`) | Contents rows `{Message, Line, Text}`: indented XML, one line per row. One `%Ensemble/%Message/ViewContents` audit row | - |
| Document body | An HL7 message | Its segments as lines, the classic raw view (`SeparatorsHere`) | - |
| Stream body | A character stream class | Its text as lines | - |
| No body | Empty body class or id, or a body that no longer opens | Zero rows, and no audit | - |
| Not text | A binary stream, or an object that is neither a document, `%XML.Adaptor` nor a character stream | - | 409 `INTEROP.MESSAGE.CONTENTS`: "OcuPilot cannot show this message body as text." The vendor's audit was already written |
| Long | A line over 4,000 characters, or more lines than the cap | That line ends `TESTCUT`. The first `maxRows` lines, with `truncated`, and the screen's cut note | - |
| Gated | Caller lacks `%Ens_MessageContent:USE` | The Contents tab stays in the strip, `aria-disabled` with "Requires %Ens_MessageContent:USE". Its read answers 403 with that `failedPair` | - |
| Queue link | A Queue messages row | Its `MessageId` cell opens that message's Header tab, in the list's namespace | - |

</intent-contract>

## Code Map

All paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-20`. Lines were read at `a3a49d759affeea6b4c8307d8dfa8224b9df3764`. Stories 20.16 and 20.8 land first, so anchor `screen-outlet.ts`, `strings.ts`, EXPERIENCE.md, the rosters and the strings bound by symbol (Task 0).

**Port, `src/OcuPilot/Port/InteropPort.cls` (6,178 lines):**

- **Declarations.**
  - `ENDPOINTS` :82, `ENDPOINTITEMMESSAGES` :121.
  - `PRODUCTIONPAIRS` :147, `ITEMMESSAGEPAIR` `%Ens_MessageHeader:USE` :189.
  - `XMLDOCUMENT`, `SEGMENTEDDOCUMENT` and `XMLADAPTOR` :378-382; `TESTOUTPUTMAX` :413, `TESTCUT` :416.
  - `REASONITEMIDREQUIRED` :636, the shape of a reason.
- **Dispatch.**
  - `RuntimeEndpoints` :724.
  - `Pairs` :744-779. Its last branch gives any unlisted endpoint `CODEPAIRS`, so new endpoints need branches before it.
  - `Serves` :786, `Invoke` :884, `Admit` :981-1000.
  - `Mapped` :2487, `Refuse` :2521, `Absent` :2543.
  - `InvokeRuntime` :2577-2640. `maxRows` is validated at :2586, and the queue branch :2600 is the shape for a criterion read.
- **Reads.**
  - `LocalStamp` :3036, which delegates to `LogSourcePort.LocalFromUtc`.
  - `SqlRows` :3104-3133.
  - `MESSAGESQL` :3147 and `SQLMAX` :3150.
  - `ListItemMessages` :3185-3215: its row builder :3204-3213 is the one to share.
  - `HeaderFacts` :3314, a header opened by id.
  - `CollectResponseHere` :5430, which uses `OutputToString` for a document.
  - `RenderTargetHere` :5843-5868: EDI XML is indented, a segmented document is the raw view, any other document is its library stream, `%XML.Adaptor` goes through `%XML.Writer` (indent 1), and anything else is an error status. It caps at `TESTOUTPUTMAX`.
- **Local time to UTC:** `Kernel/Audit/Ledger.cls` `LocalToUtc` :920 answers `YYYY-MM-DDTHH:MM:SSZ` from the `DATETIMEFORM` local value. Header `TimeCreated` is stored as UTC `YYYY-MM-DD HH:MM:SS.fff` (measured).
- **Errors:** `src/OcuPilot/Api/InteropError.cls` (581 lines). Groupings: `Codes` :396, `RuntimeCodes` :439, `ReasonFor` :501. `Api/Error.cls` delegates to it at :1235 and :1448. `Error.cls` holds 989 of 1,000 parameters, so no code goes there.

**Descriptors (`src/OcuPilot/Screen/Descriptor/`):**

- **`InteropItemMessageTab.cls`** (Story 20.4): read `interop/ItemMessages/LIST`. It is the sibling of the new search's rows.
- **`InteropQueueMessageList.cls`** (Story 20.4; archetype `list`, `parentScope` `interoperability/queues`): its name column is `MessageId` (:55), and today it links nowhere.
  - `Screen/Registry.cls`:3933 allows `rowTarget` on a `list` only, and `RowTargetPairsOwnSurface` :4126 finds no surface of its own.
  - The item tabs are `detail`, so they cannot take one.
- **`InteropItemStatusTab.cls`**: the shape for a parent-scoped tab group head, at `<list>/document`, opened by `documentScreenFor`.
- **`InteropMonitorList.cls`**:64: the shape for `rowTarget`.
- **`AuditList.cls`**:118-162: the `list (server criteria)` shape.
  - `datetime` criteria take `defaultHoursAgo` and the `DATETIMEFORM` local form (`Screen/Read.cls`:148-154, :1158).
  - A `choice` criterion's value is checked against its `options`.
  - `ExplorerSearch` shows `yes`/`no` choices.

**Client (`ui/src/app/`):**

- **`shell/detail-page.ts`** (189 lines): the tab strip over `<app-list-page />` (:80-95). It is the only drawer of a strip.
- **`shell/list-page.ts`** (339 lines). It binds the read (:161-200) and draws banners, the refusal and the note. It draws `<app-data-table>` only when the screen declares both a read and a table (:162).
- **`shell/data-table.ts`**: the skeleton (:222-227), the fault strip with Retry (:234-235), `loaded`, `fault` and empty (:827-857), and `emptyStateView`. Rows are a fixed 36 px, so a long line cannot be read in a cell (`styles/_components.scss`:2161).
- **`areas/interoperability/interop-item-test.page.ts`**:39-55: a page wrapping `<app-detail-page />`, with the host flex column.
- **`shell/screen-outlet.ts`**:
  - `ARCHETYPE_PAGES` :52. `list (server criteria)` loads `logs/audit.page`, the generic criteria page, and `detail` loads `shell/detail-page`.
  - `INTEROP_EDITOR_PAGE` :75; `DESCRIPTOR_PAGES` :93, interop rows :216-229.
- **`core/strings.ts`** (7,220 lines). Reused: `interopItemTabMessages` 'Messages' :6687, `interopColumnId` :6707, `logViewerColumnMessage` 'Message' :1298, `errorLogColumnValue` 'Value' :556, `errorLogColumnText` 'Error' :538, `tableColumnType` :385, `auditCriteriaBegin`/`End` :508/:510.
- **Budgets:**
  - `ui/tools/strings.test.mjs`:610-613: the bound is 3,400, the count is 3,371, and the raise rule is at :606.
  - `ui/tools/build-output.test.mjs`:267: `LAZYCHUNKMAX` 88 kB.
  - `ui/angular.json`:54: `maximumWarning` 1992kB.
- **`ui/tools/interop.test.mjs`** pins each `INTEROP.*` sentence equal to its `strings.ts` value.

**Tests and rosters:**

- **`src/OcuPilot/Test/`:**
  - `StageTwoTools.cls` `XData Elsewhere` :120-258.
  - `SurfaceCoverage.cls`: interop screen rows :226-250.
  - `Navigation.cls`:531-543: the interop count of 22 at :539 and the order at :540. Position-0 screens sort first, by class name.
  - `InteropFloor.cls`:
    - `OPERATORSCREENS`/`TOOLS` :53/:56, `ADMINISTRATORSCREENS`/`TOOLS` :62/:65.
    - `TestTheInteroperabilityReadsFollowTheirOwnPairs` :238 (armed; its principals hold the stock roles).
    - `TestEveryOpenScreenMatchesItsClassicPage` :310.
  - `ReadTool.cls`:93-94: the tool count and names.
  - `ToolRoundTrip.cls`:93: `REFUSEEMPTY`.
  - `InteropHostDescriptor` `TestTheNineDeclarationsRegister`, which pins 20.4's declarations, `InteropQueueMessageList` among them.
  - `InteropHostRead` (armed) is the only class that creates messages today, through `ProductionProbe` in `USER`.
- **`ui/tools/`:**
  - `navigation.test.mjs`: the built-route roster :365-390 and the `rowTarget` pins :783-794.
  - `screen-mirror.test.mjs`:2448-2496: the `ownPrivileges` owners.
- **`ui/browser/`:**
  - `interop-queue-job-actions.browser-spec.mjs` (447 lines; armed probe production in `USER`, two messages waiting):
    - `openItemTab` :170;
    - `rowAction` :156 selects on cell 1, not on the name cell;
    - the queue messages leg :286-317 reaches `interoperability/queues/messages/` through the queue's link.
  - `structural-walk.mjs`: `SKIP` :101-131 and `needsId` :211.
  - `turnprobe-spec.mjs`:53 `runIris`.
  - `list-spec.mjs`: `waitForRows` :37 and `clickRowCentre` :182.
  - `panel-spec.mjs`:64 `signedInAt`.
  - `interop-item-test.browser-spec.mjs`:66: the per-spec `structural` helper.

**Vendor (read only; `irislib/`):**

- **The viewer.** `EnsPortal/MessageViewer.cls`:15 sets `RESOURCE` `%Ens_MessageHeader:USE`. Its tabs check `%Ens_MessageContent`, `%Ens_MessageTrace`, `%Ens_MessageExport` and `%Ens_MessageResend` (:37, :267-269).
- **The search.** `EnsPortal/MsgFilter/Assistant.cls`:132-250 and :562-742 build the search SQL. :618-628 turn the time window into ID bounds: `SELECT TOP 1 %ID … WHERE TimeCreated >= ? ORDER BY TimeCreated ASC, %ID ASC`, and the mirror with `<=` and `DESC`.
- **The contents.** `EnsPortal/MessageContents.cls` has no `RESOURCE`. It checks `%Ens_MessageContent:USE` (:328-360) and audits at :405-409.
- **The audit.** `Ens/Util/Auditing.cls`:19 `AuditViewMessage` is public and writes `%Ensemble/%Message/ViewContents`.
- **The header.** `Ens/MessageHeader.cls`:12-28: the indices are bitmap on Status, Source, Target and BodyClass, standard on TimeCreated, TimeProcessed, SessionId and BodyId. `IsError` and `Type` are not indexed.

## Tasks & Acceptance

**Execution:**

- [x] **Task 0 (re-anchor, no code).** After 20.16 and 20.8 have merged into this branch, re-read and anchor this story's edits to what is there:
  - `screen-outlet.ts`'s interop rows;
  - the end of `strings.ts` and `strings.test.mjs`'s bound;
  - EXPERIENCE.md :159, :604 and :856;
  - `Navigation.cls`'s interop count and order;
  - `StageTwoTools`' `Elsewhere`;
  - `SurfaceCoverage`'s screen rows;
  - `InteropFloor`'s rosters;
  - `ReadTool`'s count;
  - `navigation.test.mjs`'s roster;
  - the highest Interoperability `sideBarPosition` (20.8 takes 10).
  
  If the strings bound still reads 3,400 and this story would cross it, raise it to 3,800 under the same ruling, with one comment line.
- [x] **`src/OcuPilot/Port/InteropPort.cls`** -- three `LIST` endpoints, `Messages`, `MessageHeader` and `MessageContents`:
  - Add them to `ENDPOINTS` and `RuntimeEndpoints`, and to `Serves` for `LIST` only.
  - Add `MESSAGEPAIRS` `%Ens_Portal:USE,%Ens_MessageHeader:USE` (reuse `ITEMMESSAGEPAIR`) and `MESSAGECONTENTPAIR` `%Ens_MessageContent:USE`. `Pairs` takes explicit branches before the `CODEPAIRS` default.
  - `InvokeRuntime` routes the three before the item parse, as the queue branch does.
  - Shared row builder. Extract `ListItemMessages`' row builder into one `MessageRow` that both callers use. The search adds `Type` and `Error`; the item rows keep their fields.
  - **`ListMessages`**:
    - Validate first: `session` digits, `bodyClass` matching the class-name shape (`CollectResponseHere`'s regex), and `beginDateTime` required. Convert the window with `Ledger.LocalToUtc`, then to the stored form.
    - Then the two ID-bound statements, as `Assistant.cls`:618-628 runs them. Either bound finding nothing means zero rows.
    - Then `SELECT TOP ? ID, TimeCreated, %EXTERNAL(Status), %EXTERNAL(Type), SourceConfigName, TargetConfigName, MessageBodyClassName, SessionId, IsError FROM Ens.MessageHeader WHERE ID >= ?`, plus fixed fragments in a fixed order for each criterion given, then `ORDER BY ID DESC`:
      - `ID <= ?`, `Status = ?` (the logical value from a fixed map of the nine display words), `Type = ?` (1 or 2);
      - `SourceConfigName = ?`, `TargetConfigName = ?`, `MessageBodyClassName = ?`, `SessionId = ?`, `IsError = ?`.
  - **`ReadMessageHeader`**: one `SqlRows` statement by `ID`, giving the 23 rows of Design Notes › Header.
    - Enumerations are read with `%EXTERNAL` and stamps through `LocalStamp`.
    - `ErrorStatus` becomes `$System.Status.GetErrorText`, or `""` when it is OK.
    - `Position` (1 to 23) and `Line` are JSON numbers, so the read order is the sort order. Every other value is a string.
  - **`ReadMessageContents`**:
    - Read the header's body class and id (bound SQL), then switched:
      - open the body;
      - audit (the Always rule);
      - render a character stream directly, or anything else through `RenderTargetHere` (extend its doc comment to name the second caller).
    - Then split on `$C(13,10)`, `$C(10)` or `$C(13)`, cut each line at `CONTENTLINEMAX` 4,000 with `TESTCUT`, and answer at most `maxRows` rows.
    - A body that is not text is refused 409 `INTEROP.MESSAGE.CONTENTS`.
  - Doc comments state each row shape.
- [x] **`src/OcuPilot/Api/InteropError.cls`**: `MESSAGECONTENTS` `INTEROP.MESSAGE.CONTENTS` (409) and `REASONMESSAGECONTENTS`, its sentence, joined to `Codes` and `ReasonFor` (the `QUEUEEMPTY` :201-203 shape). `ui/tools/interop.test.mjs` `SENTENCES` gains `['REASONMESSAGECONTENTS', 'interopRefusalMessageContents']`.
- [x] **Descriptors** (new, shaped like their siblings; each doc comment names AD-5, AD-29, AD-36 and AD-62). For all three:
  - `area` `interoperability`, `built` true, `refreshes` false, `entityType` `interop-message`, `scope` `namespace`, `id` single;
  - no actions, no `commandAliases`;
  - `classicPage` `EnsPortal.MessageViewer`;
  - three prompts each, from Design Notes › Strings.

  | Key | `InteropMessageList` | `InteropMessageHeaderTab` | `InteropMessageContentsTab` |
  |---|---|---|---|
  | `route` | `interoperability/messages` | `interoperability/messages/document` | `interoperability/messages/contents` |
  | `labelKey` | `interopItemTabMessages` | `logViewerColumnMessage` | `interopMessageContentsLabel` |
  | `sideBarPosition` | next free (11 after 20.8) | 0 | 0 |
  | `archetype` | `list (server criteria)` | `detail` | `detail` |
  | `privileges` | `%Ens_Portal:USE`, `%Ens_MessageHeader:USE` | same | same plus `%Ens_MessageContent:USE` |
  | `ownPrivileges` | `%Ens_MessageHeader:USE` | same | `%Ens_MessageHeader:USE`, `%Ens_MessageContent:USE` |
  | `parentScope` | `""` | `interoperability/messages` | `interoperability/messages` |
  | read | `interop/Messages/LIST`, criteria below | `interop/MessageHeader/LIST`, criterion `message` | `interop/MessageContents/LIST`, criterion `message` |
  | fields | `ID, TimeCreated, Status, Type, Source, Target, BodyClass, SessionId, Error` | `Message, Position, Name, Value` | `Message, Line, Text` |
  | filter | `Status, Type, Source, Target, BodyClass, SessionId` | `Name, Value` | `Text` |
  | table | ID (`name`), TimeCreated, Status (`status`), Type, Source, Target, BodyClass (`identifier`), SessionId (`identifier`), Error (`status`) | Name (`name`), Value (`text`) | Line (`name`), Text |
  | sort default | `TimeCreated` desc | `Position` asc | `Line` asc |
  | `tab` | - | group `interoperability/messages/document`, position 1, `interopMessageTabHeader` | same group, position 2, `interopMessageTabContents` |
  | `emptyStateKey` | `interopMessagesEmpty` | `interopMessageHeaderEmpty` | `interopMessageContentsEmpty` |
  | `toolIdentifier` | `interop.messages` | `interop.messageheader` | `interop.messagecontents` |

  - **The list's criteria** reuse 20.4's and Audit's labels:
    - `beginDateTime` (`datetime`, `defaultHoursAgo` 24) and `endDateTime`;
    - `status` (`choice`: Created, Queued, Delivered, Discarded, Suspended, Deferred, Aborted, Error, Completed);
    - `type` (`choice`: Request, Response);
    - `source`, `target` (`text`, `maxLength` 128) and `bodyClass` (`text`, `maxLength` 220), the header's own `MAXLEN`s (`Ens/MessageHeaderBase.cls`:46-67);
    - `session` (`text`, `maxLength` 19);
    - `errors` (`choice` `yes`/`no`, label `interopMessagesCriterionErrors`).
  - **The tabs' criterion** is `message` (`text`, `maxLength` 19, label `interopColumnId`, hint "One message, as interop.messages.read answers its ID.").
  - **Context.** List: the fields less `Error`. Header: `Name`, `Value`. Contents: `Line`, `Text`.
- [x] **`InteropQueueMessageList.cls`**: add `"rowTarget": {"route": "interoperability/messages/document", "field": "MessageId"}`, and one doc-comment sentence saying a waiting message's id opens it (Story 20.9).
- [x] **`src/OcuPilot/Test/InteropMessageRead.cls`** (new, unarmed, about 400 lines). Each test creates synthetic `Ens.MessageHeader` rows in HSCUSTOM whose source carries a per-run marker (Design Notes › Fixture) and deletes them, with their bodies, in `OnAfterOneTest`.
  - Every criterion narrows alone and together. Rows come newest first.
  - The window bounds, including a header created two days earlier and left out by the default window.
  - `maxRows` 2 gives `truncated` through the read route.
  - Each malformed criterion is refused by name, and `beginDateTime` empty is refused.
  - The Header rows: 23 names in order, local stamps, `ErrorStatus` text.
  - An unknown id gives zero rows, and a malformed id gives 400.
  - The read route and the read tool answer the same rows (AD-36).
- [x] **`src/OcuPilot/Test/InteropMessageContents.cls`** (new, unarmed, about 300 lines), with the same fixture plus `OcuPilotProbe.Msg209.Plain` (a compiled `%Persistent` class with one property, removed after). It covers:
  - the XML, HL7, character stream, binary stream, no-body, not-text, long-line and over-cap rows of the matrix;
  - one `%Ensemble/%Message/ViewContents` row newer than the read, whose Description is `OcuPilot` and whose event data names the header (read in `%SYS` by explicit save and restore; match the newest rows in code, Design Notes › Measured);
  - no such row for a header with no body.
- [x] **`src/OcuPilot/Test/InteropMessageDescriptor.cls`** (new, read-only):
  - `TestTheThreeDeclarationsRegister`: the table's values, `Registry.Validate`, and `NormalizePage("EnsPortal.MessageViewer.zen")`.
  - `TestTheClassicPageSharesTheScreensPair`.
  - `TestThePortDeclaresEachScreensPairs`: `InteropPort.Pairs` of each endpoint equals its descriptor's pairs.
  - `TestTheQueueMessagesListLinksToTheMessage`: the `rowTarget`, and that its route is a built screen.
- [x] **Rosters**, each row named from the instance:
  - `StageTwoTools` `Elsewhere`: three rows, sorted.
  - `SurfaceCoverage`: three `<screen>` rows naming `InteropMessageDescriptor`'s first test, with `corpus="one declaration test pins all three Story 20.9 message screens in one loop"`.
  - `Navigation.cls`: the count +3 at the pinned order.
  - `ReadTool.cls`: +3 tools.
  - `ToolRoundTrip.cls` `REFUSEEMPTY`: `interop.messageheader.read:READ.CRITERION` and `interop.messagecontents.read:READ.CRITERION`.
  - `InteropHostDescriptor`: `InteropQueueMessageList`'s new `rowTarget`, if it pins it.
- [x] **`src/OcuPilot/Test/InteropFloor.cls`**:
  - `OPERATORSCREENS` gains the list and Header tab, and `OPERATORTOOLS` their tools.
  - `ADMINISTRATORSCREENS` gains the Contents tab, and `ADMINISTRATORTOOLS` its tool.
  - `TestTheInteroperabilityReadsFollowTheirOwnPairs` gains four legs:
    - the `%Ens_Portal` holder is refused `interop.messages` naming `%Ens_MessageHeader:USE`;
    - the Operator reads `interop.messages` (200);
    - the Operator is refused `interop.messagecontents?message=1` naming `%Ens_MessageContent:USE`;
    - the Administrator reads it (200).
- [x] **`ui/src/app/core/strings.ts`** (add-only): Design Notes › Strings. Then run `cd ui && node tools/screen-mirror.mjs`.
- [x] **`ui/src/app/shell/list-page.ts`** and **`shell/detail-page.ts`**: add an optional `body` input (a component type, default `null`).
  - When it is set, `ListPage` renders that component with `screen` and `store` inputs (`NgComponentOutlet`) in place of `<app-data-table>`. Banners, refusal, note, binding, refresh and the id-change re-read are unchanged.
  - `DetailPage` passes its own `body` to both of its `<app-list-page>`.
  - Conditions stay paren-free member references (`client-lint.mjs`).
- [x] **`ui/src/app/areas/interoperability/interop-message-contents.ts`** (new, `app-interop-message-contents`, `OnPush`; inputs `screen`, `store`). It follows `DataTable`'s `loaded`, `fault` and empty getters and draws:
  - skeleton bars in an `aria-busy` region until the first answer;
  - a non-banner fault: `connectivityRequestRefused` with Retry;
  - zero rows: the screen's empty sentence (`emptyStateView`);
  - rows: one `<pre class="ocu-message-contents" tabindex="0">` with the label `interopMessageContentsLabel`, holding each row's `Text` as interpolated text, one line per row;
  - `store.truncated()`: `interopMessageContentsCut` above it.
  
  Each block carries `data-ocu-contents` (`skeleton`, `fault`, `empty`, `text` or `cut`).
- [x] **`ui/src/app/areas/interoperability/interop-message-contents.page.ts`** (new, `app-interop-message-contents-page`): the host flex column of `interop-item-test.page.ts`, with template `<app-detail-page [body]="contents" />`.
- [x] **`ui/src/app/shell/screen-outlet.ts`** (add-only): an `INTEROP_MESSAGE_CONTENTS_PAGE` loader, and its `DESCRIPTOR_PAGES` entry for `InteropMessageContentsTab`. The list and Header use their archetype pages.
- [x] **`ui/src/styles/_components.scss`**: `.ocu-message-contents`, with:
  - the code type tokens;
  - `white-space: pre-wrap` and `overflow-wrap: anywhere`;
  - scrolling inside the panel as a flex item;
  - tokens only, so both themes hold.
- [x] **Client tests:**
  - `interop-message-contents.spec.ts` (new): each state draws its block; a line holding `<script>` renders as text; the cut note shows when truncated.
  - `list-page.spec.ts` and `detail-page.spec.ts` (extend, or create beside them if absent): a `body` draws that component with the screen and store and no table; no `body` draws the table as before.
  - `ui/tools/navigation.test.mjs`: the roster gains three routes. A pairing test asserts that `documentScreenFor` of the list is the Header tab, and that Queue messages' `rowTarget` is `{route: 'interoperability/messages/document', field: 'MessageId'}`.
  - `ui/tools/screen-mirror.test.mjs`: the three join the `ownPrivileges` owners, sorted.
- [x] **EXPERIENCE.md** (add-only), then run `cd ui && npm run test:tools`:
  - :159: "Interoperability's Messages searches message headers; a message opens to its Header and Contents tabs (Story 20.9)."
  - :604: the Story 20.9 clause listing Design Notes › Strings.
  - :856: "the message Contents tab (Story 20.9) is a `detail` tab whose rows draw as one block of text lines, not a table; empty is its sentence and a long message ends with its cut note".
- [x] **`ui/browser/interop-messages.browser-spec.mjs`** (new). `before` refuses `LIVE_CONTAINER` and requires readiness `installed`.
  - **Fixtures.** Through `runIris` in HSCUSTOM, it creates the Fixture headers and records their ids. `after` deletes them and their bodies and checks that none is left.
  - **Tests**, each carrying its mutation comment:
    1. AC1;
    2. AC2;
    3. AC3;
    4. the structural legs: `structural` on the list, Header and Contents, at 1280 light, 720 light and 1280 dark.
- [x] **`ui/browser/interop-queue-job-actions.browser-spec.mjs`**: a new AC4 test, placed before the first test that aborts.
  - It signs in its own context, opens the probe queue's Queue messages, and takes the first listed `MessageId`.
  - It follows that id's link and asserts the Header tab, then opens the Contents tab and asserts the probe message's body draws as XML text from USER.
- [x] **`ui/browser/structural-walk.mjs`** `SKIP`: the two tabs, with the reason "a fresh instance holds no message; interop-messages.browser-spec.mjs walks them on the headers it creates". Fix or append any fresh baseline entry, as the file says.
- [x] **Roster sweep (Rule 30).** Search `src/OcuPilot/Test`, `ui/tools`, `ui/browser` and the `ui/src` specs for any assertion on:
  - the interop screen count or order;
  - `InteropQueueMessageList`'s declaration or its `MessageId` cell;
  - `ListPage`'s or `DetailPage`'s template;
  - the read-tool count.
  
  Each changed file joins the `(loop)` set.

**Acceptance Criteria:**

- **AC1 (search through the port).**
  - **Given** the signed-in shell on `ocupilot-b-ci` and the Fixture's headers in HSCUSTOM.
  - **When** the person opens Messages from the side bar and searches by the Fixture's source with the default window.
  - **Then:**
    - the list shows exactly the three Fixture headers of the window, newest first, with their Status, Type, Source, Target, BodyClass and SessionId;
    - status Error, then `errors` yes, each show only the error header;
    - the session shows its two headers;
    - a begin after the second leaves only the third;
    - no request goes to `/api/interop-editors/` or under `/ui/interop/`.
  - **And** `InteropMessageRead` shows the read tool and the read route answer the same rows.
  - Saved searches are not offered (Q2).
- **AC2 (the viewer's Header).**
  - **Given** the list.
  - **When** the person opens the error header's ID cell.
  - **Then:**
    - the route is `interoperability/messages/document/<id>`;
    - the strip reads Header and Contents;
    - the Header tab lists the 23 properties in order, with `ErrorStatus` reading the probe's error text, `IsError` reading 1 and `TimeCreated` in local time.
  - **And given** an id no header holds, **then** the screen reads "This message no longer exists."
- **AC3 (contents, rebuilt and read-only).**
  - **Given** the Contents tab of the XML probe, the HL7 probe and the no-body probe.
  - **When** each opens.
  - **Then:**
    - the XML probe draws its indented XML, its `<&>` shown literally;
    - the HL7 probe draws its segments one per line, its long segment ending `TESTCUT`;
    - the no-body probe shows "This message has no contents to show.";
    - no control edits the text.
  - **And** `InteropMessageContents` pins the vendor's ViewContents audit row for a read that opened a body, and none for the no-body one.
- **AC4 (Queue messages link to the message; Integration, Rule 1).**
  - **Given** the armed probe production's queue in `USER`, with messages waiting (`interop-queue-job-actions.browser-spec.mjs`).
  - **When** the person opens the first listed `MessageId` on Queue messages.
  - **Then** the route is `interoperability/messages/document/<that id>` in `USER`, and its Header tab's `ID` row reads that id and its `TargetConfigName` row the probe operation.
- **AC5 (declared, gated, rostered).**
  - **Given** the three descriptors.
  - **When** the instance validates them and the build regenerates the mirror.
  - **Then:**
    - each validates with the table's values;
    - each is in `Elsewhere`, which reddens alone when a row is removed;
    - each carries three prompts;
    - the Interoperability navigation gains 3 in the pinned order;
    - `InteropFloor` shows the Operator opening the list and the Header tab and refused the Contents tab naming `%Ens_MessageContent:USE`, and the Administrator opening all three;
    - `structural` finds no fresh entry on the three screens in 1280 light, 720 light and 1280 dark.

### Review Findings

Code review 2026-10-14 (re-run from the start; layers `full-opus`).

- [x] [Review][Patch][High] The Contents text can reach 1,000,001 characters against AD-62 item 15's 1,000,000 [src/OcuPilot/Port/InteropPort.cls:3634] -- rework: in `ReadMessageContents`, right after `If tOutcome '= "text" Quit $$$OK` and before the CR/LF normalisation, add `If $Length(tText) > ..#TESTOUTPUTMAX Set tText = $Extract(tText, 1, ..#TESTOUTPUTMAX) _ ..#TESTCUT`. Leave the shared `StreamText` (:6316) alone: Story 20.27's `AddTestLines` relies on its +1 read. In `InteropMessageContents.TestTheTextIsCutAtItsOverallCapAndTheLinesAtTheRowCap` (:244) the 1,000 lines of 999 characters and a LF fill the cap exactly, so row 1,001 becomes `..#CUT` alone (was `"x" _ ..#CUT`, :258); its `Mutation` note and the `## Verification` line "`StreamText` reads 2,000,000 characters" become "`ReadMessageContents` without its `TESTOUTPUTMAX` cut -> that test (row 1,001 reads `x ... [cut]`)".
- [x] [Review][Patch] The Contents block ignored the command bar's filter and sort, while the agent's context applied them [ui/src/app/areas/interoperability/interop-message-contents.ts:147]
- [x] [Review][Patch] `UtcAgo` threw `<ILLEGAL VALUE>` from 23:00 to 24:00 UTC (no forward roll) [src/OcuPilot/Test/InteropMessageRead.cls:60]
- [x] [Review][Patch] `StoreHeader` stamped `TimeCreated` and `TimeProcessed` by two clock reads (a millisecond flake), and the two were never told apart [src/OcuPilot/Test/InteropMessageRead.cls:98]
- [x] [Review][Patch] The window legs depended on no other header in HSCUSTOM at 24 h-23 h 50 min, 30-25 min and 15-10 min ago; every bound is now a second a fixture header was made in (`Opening`, `LocalSecond`), in `InteropMessageRead`, `InteropMessageRows` and browser AC1's begin leg [src/OcuPilot/Test/InteropMessageRead.cls:250]
- [x] [Review][Patch] Rule 2: `InteropMessageContents.Views`/`Now` copied `AuditEvent.RowsCarrying`/`Now`; `RowsCarrying` takes the source, type and description now [src/OcuPilot/Test/AuditEvent.cls:129]
- [x] [Review][Patch] Rule 2: `OpenBodyHere` repeated `CollectResponseHere`'s open block, and `CLASSNAMEPATTERN` sat beside six inline copies; all share the parameter and the opener [src/OcuPilot/Port/InteropPort.cls:3541]
- [x] [Review][Patch] Rule 2: `interopSearchEndpoints` copied `parseInteropEndpoints`, which takes the pattern now [ui/tools/screen-mirror.mjs:1111]
- [x] [Review][Patch] Rule 19: the queue spec's "AC1 in USER" could read the opening read's rows before the Search answered [ui/browser/interop-queue-job-actions.browser-spec.mjs:309]
- [x] [Review][Patch] A stream id no longer held opened as an empty stream and wrote a ViewContents row (matrix: no body, no audit) [src/OcuPilot/Port/InteropPort.cls:3547]
- [x] [Review][Patch] The Header tab's sort menu offered Name alone, and a chosen Name sort persisted with no way back to the classic order [src/OcuPilot/Screen/Descriptor/InteropMessageHeaderTab.cls:47]
- [x] [Review][Patch] The item Messages rows' `Production` and `Item` values were pinned by no test after the `MessageRow` extraction [src/OcuPilot/Test/InteropHostRead.cls:329]
- [x] [Review][Patch] The focusable `pre` carried `aria-label` with no role [ui/src/app/areas/interoperability/interop-message-contents.ts:58]
- [x] [Review][Patch] Literal counts outside a roster (Rule 30): the Messages choice option counts and `*-3` [ui/src/app/areas/logs/audit.page.spec.ts:288, src/OcuPilot/Test/InteropTestDescriptor.cls:136]
- [x] [Review][Patch] `TestThePortServesTheNineEndpointsAndTheirPairs` pinned twelve; renamed `...RuntimeEndpoints...` [src/OcuPilot/Test/InteropHostDescriptor.cls:166]
- [x] [Review][Patch] Browser AC1's comment claimed dropping `AuditSearch.adopt` reddens it; a fresh context has no earlier search [ui/browser/interop-messages.browser-spec.mjs:231]
- [x] [Review][Patch] EXPERIENCE.md :856 said a long message "ends with" its cut note (it is drawn above, for the row cap) and left Messages out of the server-search screens [EXPERIENCE.md:856]
- [x] [Review][Defer] A message cut at the 1,000,000-character cap shows no cut note, so lines after the cut vanish unannounced [src/OcuPilot/Port/InteropPort.cls:3634] -- deferred: DW-2433, escalated owner=burndown (the fix needs a port cut flag through `Screen/Read.cls`, on the Never list)
- [x] [Review][Defer] Rule 31: the Contents block copies DataTable's state getters and markup [ui/src/app/areas/interoperability/interop-message-contents.ts] -- deferred: DW-2434, routed to 20-30-the-session-trace
- [x] [Review][Defer] A malformed criterion reads as the generic "request refused" [ui/src/app/shell/data-table.ts:235] -- deferred: occurrence on DW-2188 (the Fault carries no reason)
- [x] [Review][Defer] Frontmatter `deferred:` items -- DW-2435 (no `[innerHTML]` lint rule, wontfix-accepted), DW-2436 (no Max rows control, wontfix-accepted; the filter half is patched above), DW-2437 (the view audit's failure path, wontfix-theoretical)

Rejected:

- The not-text 409 draws `connectivityRequestRefused` with Retry, each Retry another ViewContents row -- spec-bound (Tasks name that block); each Retry is a view the vendor audits too.
- A file-stream body names any file IRIS can read -- low; the classic pane opens the body the same way (`EnsPortal.MessageContents`:139), and it needs a principal who can write header rows.
- `interoperability/messages/<id>` opens an empty audit-event dialog -- low; reached only by a pasted URL or an agent opening the list with an id; the guard belongs to the shared page.
- `AuditSearch.adopt` resets the audit search after a visit to another server-criteria screen -- low; per-screen search state is more than a direct fix, and the reset replaces a cross-screen leak.
- A `<PROTECT>` on the body's open reads as no rows -- low, theoretical: `Admit` checks READ on the namespace's globals database.
- A document that fails to render reads 409 not-text, its vendor error dropped -- low and rare; the fix adds branches.
- The catch path drops the body object in the install namespace -- maybe-false: nothing shows a close in another namespace failing; low if true.
- A DST fall-back hour interleaves rows sorted by local text -- low, once a year; the default sort is specified.
- The whole body is rendered before the cut -- low; a bounded writer is more than a direct fix, and the renderer is Story 20.27's.
- `ErrorStatus` text resolves in the install namespace -- low; measured, an `<Ens>` status still carries its text in `%SYS`.
- The list context leaves `Error` out -- spec-bound (Tasks: "the fields less `Error`").
- `SessionId` sorts as text -- low; equal sessions still group, and the string shape is pinned.
- A begin's fraction is widened to its whole second -- low, sub-second.
- `navigation.test.mjs`'s side-bar order and `InteropDescriptor`'s sentence list are literal -- they are the roster pins (Rule 30's exception).
- `RemoveAll` takes every marker header, not this run's -- low; one test run in flight, by policy.
- `InteropMessageRead.cls` runs past the 500-line guide -- low.
- The Auto Run Result's counts and the frontmatter `status` are stale -- the fix edits the spec under review.

## Spec Change Log

- 2026-10-13, spec gate (runner): the orchestrator ruled Q1 A (Parts B and C are Stories 20.30 and 20.31, chartered in `epics.md` with their criteria verbatim; order 20.9, 20.30, 20.31, then 20.10) and Q2 A (no saved searches, a named limit; DW-2398 with its reopen_if). `epics.md` Story 20.9 is amended under Rule 5. The Rule 20 drafts are written (AD-62 item 15, AD-8, AD-44, AD-5).
- 2026-10-14, implement intent gap (runner ruling): the registry and `screen-mirror.mjs` refuse criteria on an unparented `interop` read (AD-36 as amended at 20.3), so the Messages list could not register under the Never list. Epic 18's branch changes no code file (its diff against feature is planning files only), so `Screen/Registry.cls` is a shared file, not a contended one. The Never is lifted for `CriteriaProblem` and its twin `criteriaProblem`, through one `InteropPort` parameter, `SEARCHENDPOINTS`; `Test/CriteriaCorpus.cls` gains its cases; `ui/src/app/areas/logs/audit.page.ts`, `audit.store.ts` and `audit.page.spec.ts` (the shared `list (server criteria)` page) are a footprint extension. AD-36 and AD-62 item 15 name the parameter. The Header `Name` and Contents `Line` columns are kind `name`, because a tab's table needs one.
- 2026-10-14: re-opened for rework iteration 1 (code review re-run left one HIGH, the Contents cap; see Review Findings).

## Review Triage Log

### 2026-10-14 — Review pass

- verdicts: 15 findings — high 0, medium 2, low 13, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` The `source` and `target` criteria were never shown to narrow: every fixture header shared one source and target — patched: the fixture's fifth header (`StoreFullHeader`) has its own, `TestEveryCriterionNarrowsAloneAndTogether` gained the source-alone and target-alone legs, and browser AC1 and AC2 now wait on a narrowing that happens (mutation lines added).
  - `[medium]` `[patch]` The default-window legs depended on no earlier recent header in the store (a header with a lower id moved the window's first bound below Old) — patched: the fifth header anchors the bound ten minutes after the window opens; the class stays green with a three-hour-old header stored and goes red without the anchor.
  - `[low]` `[patch]` Contents (and the Messages search) were never run against a namespace other than the install one — patched for Contents: the queue spec's AC4 test opens the probe message's Contents tab in USER; removing the switch reddens it. The search shares `SqlRows` with the Header read AC4 already runs in USER.
  - `[low]` `[patch]` Header values were pinned for 11 of 23 properties and the order assertion read the port's own list — patched: the order is a literal and the fifth header carries a distinct value for every property, asserted by name.
  - `[low]` `[patch]` The no-error leg passed when no `ErrorStatus` row came back — patched: the sentinel is `unread`.
  - `[low]` `[patch]` The default-window leg used a substring test that passed on an error answer — patched: it asserts the three ids.
  - `[low]` `[patch]` `If '$IsObject(...) Quit` guards skipped assertions silently on a 200 with no object — patched: an `AssertTrue` stands before each guard in `InteropMessageRead` and `InteropMessageContents`.
  - `[low]` `[reject]` Sub-assertions (no editors request, absent-id sentence, no edit control, three prompts) carry no `mutation:` line of their own — Rule 19 scopes one mutation to an AC's pinning test, and each AC has one; a rejected low not worth a line per assertion.
  - `[low]` `[reject]` The not-text 409 reaches a person as `connectivityRequestRefused` with Retry, not its sentence — Tasks specify that block for a non-banner fault, a binary body is rare, and the sentence is the agent's and the API's; the fix adds a state to a specified component.
  - `[low]` `[reject]` The gated Contents tab's strip is not asserted for this screen — `detail-page.spec.ts` pins `aria-disabled` and "Requires <pair>" for any gated tab, and `InteropFloor` pins the Operator's verdict and 403 naming `%Ens_MessageContent:USE`.
  - `[low]` `[patch]` The switched-namespace divergence the audit raised — same root cause and same patch as the third row (the port's own helpers run switched, as Story 20.27's `RenderTargetHere` does).
  - `[low]` `[reject]` The item Messages and Queue tabs do not link to a message — the Approach names Queue messages alone, and a link from a `detail` tab needs `Screen/Registry.cls`, which the Never list bars; a named limit in Design Notes.
  - `[low]` `[reject]` The 1,000,000-character cap sets no `truncated` and no cut note, only the inline `TESTCUT` — the Long row asks the note for rows past `maxRows`; a flag for the character cap needs a port-level change to the generic row cap.
  - `[low]` `[reject]` No Story 20.9 test touches the sanitizer clause (AD-60) — no new model-bound path: the Contents rows reach the model through the existing context pipeline, which has its own tests.
  - `[low]` `[reject]` The no-editors-request guard runs on the search screen only — the Header and Contents tabs add no request path of their own, and AC1 states the guard on the search.

### 2026-10-14 -- Code review (re-run)

- verdicts: 41 findings -- high 1, medium 9, low 14, rejected 17 (one maybe-false); the four layers ran blind, and the halted pass's 24 notes reconcile to a finding or a rejected line each
- the HIGH (the 1,000,001-character Contents text) is left for the rework with its exact fix; every MED is patched but DW-2433 (escalated); LOWs patched, routed (DW-2434) or closed (DW-2435..2437, DW-2188 occurrence)
- the item-row gap (verification-gap) was half false: `InteropHostRead.TestEachScreenAndToolAnswerTheSameRowsAsThePort` already reddens when `Production` and `Item` go missing; their values were unpinned, and are now
- footprint extension: `src/OcuPilot/Test/AuditEvent.cls` (Epic 11's helper; `RowsCarrying` gains trailing optional arguments, its 60 callers unchanged)

### 2026-10-14 -- Review pass (rework 1)

- verdicts: 7 findings -- high 0, medium 0, low 6, false 1, maybe-false 0
- findings:
  - `[low]` `[patch]` The cap comparison's boundary (a text of exactly 1,000,000 characters and one of 1,000,001) was pinned by no test, so an off-by-one in the new line ships green -- patched: `TestATextAtTheCapIsWholeAndOneCharacterOverIsCut`, with the `CapStream` helper the cap test shares; two `mutation:` lines, each demonstrated red alone.
  - `[low]` `[reject]` The cap test's row-cap leg cannot observe `ReadMessageContents`'s own `tTop` bound -- this pass did not change it; the row cap a person sees is `Screen/Read`'s trim, pinned by the `2|1` leg, and the port's bound only limits memory before that trim.
  - `[false]` `[reject]` The `TESTCUT` marker sits outside the 1,000,000 characters (a text of 1,000,010) -- `AddTestLines` cuts the same way and a cut line is 4,000 characters plus the marker; the clause counts the text.
  - `[low]` `[reject]` `carried` The 1,000,000-character cut sets no `truncated` and shows no cut note -- DW-2433, escalated at the first re-run; the fix needs `Screen/Read.cls`, on the Never list.
  - `[low]` `[reject]` An XML or HL7 body over the cap has no test of its own -- every kind reaches the one line through `tText`, the stream leg reddens when the line goes, and a megabyte HL7 fixture exercises the same line.
  - `[low]` `[reject]` A cut between a CR and its LF leaves the CR, which the normalisation turns into a line end before the marker -- cosmetic, and only for a CRLF body cut exactly there.
  - `[low]` `[reject]` `carried` No test touches the sanitizer clause for the Contents rows -- no new model-bound path; the existing context pipeline has its own tests.

## Design Notes

**Governing ADs.**

- **AD-62**: items 1 (no `%Api.InteropEditors`), 2 (gate first), 3 (switched; no `OcuPilot.*` while switched), 8 (ids kept exactly) and 12 (no compile-time interoperability). Item 15 is drafted below.
- **AD-29**: the port's own gate, `%ExecDirectNoPriv` after it, and no nested `TOP`.
- **AD-8** and **AD-64**: every-pair gating, the narrower audiences named below, and the three screens adjustable.
- **AD-5**: three descriptors, a parent-scoped tab group at `<list>/document`, one `rowTarget`, a page through one loader line, and the `body` extension.
- **AD-36** and **AD-37**: a uniform capped read, the same for screen and tool; a gone message is zero rows.
- **AD-21**: values are bound, and fragments are chosen by presence.
- **AD-13**: the id is one segment.
- **AD-44**: the classic page is `EnsPortal.MessageViewer`.
- **AD-11** and **AD-60**: contents drawn as text, and sanitized for the model.
- **AD-19**, **AD-20** and **AD-24**: the client stores, one absolute read, and the declared context.
- **AD-47**: unchanged.

Checked and not engaged in Part A:

- AD-14, AD-15, AD-22, AD-51 and AD-53 (no write; Part C's);
- AD-63 (no embed; Decisions);
- AD-43 (manual refresh).

**Measured at this plan on `ocupilot-b-ci`** (2026-10-13, image 2026.2). Every probe row and the probe user were removed and verified. The two ViewContents audit rows the probes wrote stay, as audit rows do.

- **Roles** (direct resources):
  - `%EnsRole_Operator` holds `%Ens_MessageHeader:U`, `%Ens_MessageResend:U` and `%Ens_MessageTrace:U`.
  - `%EnsRole_Administrator` holds `%Ens_MessageContent:U`, `%Ens_MessageEditResend:U` and `%Ens_MessageExport:U`, and is granted `%EnsRole_Operator`.
  - `%EnsRole_WebDeveloper` holds `%Ens_MessageContent:U` and `%Ens_MessageEditResend:U`.
  - `%EnsRole_Monitor` holds none of them.
- **`NormalizePage`** answers `EnsPortal.MessageViewer`, `.MessageContents`, `.VisualTrace`, `.MessageResend` and `.MessageResendEdit` for their `.zen` pages.
- **Audit events.** `%Ensemble/%Message/ViewContents` and `%Ensemble/%Message/Resend` are enabled, and auditing is on.
  - `AuditViewMessage("OcuPilot plan 20.9 probe", …)` answered 1 and wrote a ViewContents row with that Description.
  - A `%SYS.Audit` query `WHERE Event = 'ViewContents'` answered no row, while the newest-rows query listed it (cause unknown).
- **A fresh throwaway holds no message header** in HSCUSTOM, USER or HSLIB, so every test creates its own.
- **Synthetic headers.**
  - A header saved with `%New`/`%Save` and no production reads back through `%ExecDirectNoPriv`.
  - `%EXTERNAL` gives Status `Completed`/`Error`, Type `Request`, Priority `Async`, Invocation `Queue` and business types `BusinessService`/`BusinessOperation`.
  - `ErrorStatus` reads as a `%Status` list.
  - `SessionId` is not set by the save.
  - An `Ens.StringRequest` renders through `%XML.Writer` (indent 1) as `<StringRequest>` with a CDATA `StringValue`.

**Decisions:**

- **Contents: a rebuilt, read-only renderer, not the embedded viewer.**
  - `RenderTargetHere` already renders every document kind and `%XML.Adaptor` (Story 20.27). `Ens.MessageBody` and `Ens.StreamContainer` are both `%XML.Adaptor`, so most bodies are covered.
  - A message cannot be addressed in the vendor app (below).
- **The vendor's message viewer is not embedded.** Measured in its bundle (`main.555a609aecbe10b3.js`, live 200 on 52777):
  - It reads only `$NAMESPACE` and `SESSIONID`; `SESSIONID` opens a session's trace full height. No parameter opens one message.
  - Every load runs a default search that stores an `Ens.Message.Search` row. A namespace change pushes a history entry, and an unknown namespace silently falls to the first.
  - Its Resend sends any number of selected messages, in requests of 300, with no dry run. That would bypass the double gate and cap the story's second criterion requires (Part C).
  - Part B's charter draws its own trace for the same reasons.
- **Saved searches (Q2).** The instance keeps two stores, each tied to its own search engine:
  - **`EnsPortal.MsgFilter.SavedSearch`**: shared by every user of the namespace, a Zen filter object with Body, SearchTable and VDoc terms.
  - **`Ens.Message.SavedSearch`**: per user, keyed `(Username, Name)`. Its criteria are a tree run by `Ens.Message.Search`, which runs on a work queue and stores a row for each run. `CompileCriteria` concatenates a header field unvalidated (`Search.cls`:450-452).
  - **What follows.** OcuPilot's search is bound header SQL. Running either kind of saved search means adopting that engine, and listing ones OcuPilot cannot run would mislead. So this story offers none.
- **Header rows as `{Position, Name, Value}`**, which is the Settings tab's shape plus the classic pane's order. The table's 36 px rows show the whole of every header value except a long `ErrorStatus`, which the agent and screen context still carry whole.
- **The Contents tab draws text, not a table.** A table's fixed 36 px rows cut every long segment. The `body` input keeps everything `ListPage` does (binding, refusal, refresh and the id-change re-read) and swaps only the body. The same extension is the Trace tab's (Part B).
  - *Rejected:* a `code` column kind. It edits `Screen/Registry.cls`, which is contended.
  - *Rejected:* a custom page re-binding the read. It copies `ListPage`.
- **The window's ID bounds** use the classic viewer's own conversion, so a 24-hour search reads only that day's ID range. `beginDateTime` is required at the port: the screen always sends its default, and a tool call that clears it is refused rather than scanning the table.
- **Synthetic headers for this story's own tests.** No production is needed to read, so the new classes stay unarmed. AC4 alone needs a real production, and it extends the armed spec that already runs one.

**Split (`multiple-goals`; recommended).** This story is four capabilities. The seams are clean:

- **Part A (this spec)** is reads and the read-only renderer: the story's first and fourth criteria.
- **Part B, "The session trace"** (the story's third criterion).
  - **Screen.** A third tab, `interoperability/messages/trace` (position 3), with `%Ens_MessageHeader:USE` and `%Ens_MessageTrace:USE`, classic page `EnsPortal.VisualTrace`. The Operator holds both.
  - **Read.** Endpoint `MessageTrace` `LIST` `message`: two top-level statements, the header's `SessionId` and then the session's headers by `ID`, capped. The vendor's route resolves any header to its session; the classic trace reads the whole session plus `Ens_Util.Log`, `Ens_Rule.Log` and IOLog with no cap.
  - **Drawing.** OcuPilot draws the visual trace itself as an SVG sequence diagram through the `body` input:
    - participants in first-appearance order;
    - one arrow per header, request solid and response dashed, errors marked;
    - each arrow a link to its message.
    - The generated alternative is Mermaid `sequenceDiagram` text from the same rows, following the sibling's `Diagram/Writer.cls` id and escape rules (`/Users/jbrandt/git/iris-execute-mcp-v2`, MIT, the owner's) without its compression and correlation.
  - **From the host test.** 20.6's host test answers a `sessionId`. A session id is its first header's `ID` (inference, from the vendor's trace query; measure at Part B's Task 0), so the test answer links to the trace.
- **Part C, "Message resend and edit-and-resend"** (the story's second criterion).
  - **The vendor call.** `Ens.MessageHeader.ResendDuplicatedMessage(id, .new, target, body, source, headOfQueue)` checks no privilege. It needs a running production and a running target queue, refuses retargeting a response, and keeps the session (`Resent` +1, Description "Resent <id>"). It audits `%Ensemble/%Message/Resend` on the new header, which is enabled.
  - **OcuPilot's side.** OcuPilot gates `%Ens_MessageResend:USE`, and `%Ens_MessageEditResend:USE` for an edit.
  - **The double gate.** The agent's proposal is the dry run: per-message verdicts, nothing sent. A person's action is a dialog showing the same dry run, then Confirm. Confirm executes.
  - **The cap.** At most 100 messages per action, refused beyond, never truncated, as the sibling's `MessageResend.cls` does.
  - **Edit.** Edit-and-resend is one message, the contents renderer's action half: a body saved as a clone, as `%ProcessSubmit` does.
  - **Rest.** It uses the list's multi-select and the Header tab. Its key posture and fixture (`ProductionProbe`, armed) are its own gate's.
- **Order:** 20.9, then Part B, then Part C, then 20.10. 20.12 needs C's resend.

**Gate questions (for the orchestrator):**

- **Q1, split.**
  - (A) Three stories, in the order above, with Parts B and C numbered by the lead. Rule 5 ask-first: it defers the story's second and third criteria. Recommended.
  - (B) Two stories: Part A plus B, then C.
  - (C) One story.
  - Under (B) or (C), the lead re-opens this spec to `draft` for a re-plan that adds the parts.
- **Q2, saved searches.**
  - (A) None, a named limit, as planned. Recommended.
  - (B) List the person's own `Ens.Message.SavedSearch` rows as a criterion, and run those made only of basic header criteria, refusing the rest by name. This adds a read and a criteria translator (inference: about half a day).

**Rule 5 draft (Q1 A; for `epics.md` Story 20.9).** This story keeps its title and its first and fourth criteria. The second (resend) and third (trace) move to two new stories, each carrying its criterion verbatim, inserted after 20.9 and before 20.10 in `story_order`.

**Spine and UX drafts (Rule 20; the lead writes them at the gate):**

- **AD-62, item 15:** "Message reads (Story 20.9). `InteropPort` gains `Messages` (`LIST`, criteria `beginDateTime` (required), `endDateTime`, `status`, `type`, `source`, `target`, `bodyClass`, `session`, `errors`), `MessageHeader` and `MessageContents` (`LIST`, criterion `message`, the header `ID`).
  - **Reading.** Each reads `Ens.MessageHeader` with `%ExecDirectNoPriv` after the gate, the window turned into ID bounds by two top-level statements as the classic viewer does.
  - **Contents.** Rendered by the port as text (EDI as the raw view or indented XML, `%XML.Adaptor` through `%XML.Writer`, a character stream as read), at most 1,000,000 characters, lines cut at 4,000, refusing any other body `INTEROP.MESSAGE.CONTENTS`.
  - **Audit.** Each contents read that opens a body records the vendor's own `%Ensemble/%Message/ViewContents` through `Ens.Util.Auditing.AuditViewMessage`, as the classic Contents pane does.
  - **Saved searches.** None are offered: each vendor store belongs to its own search engine."
- **AD-8, a Story 20.9 clause:** "The message reads require `%Ens_MessageHeader:USE`, and Contents also `%Ens_MessageContent:USE`. `%EnsRole_Operator` holds the first, and `%EnsRole_Administrator` and `%EnsRole_WebDeveloper` the second (measured)."
- **AD-44, a Story 20.9 clause:** "The Messages list and its Header and Contents tabs declare `EnsPortal.MessageViewer` (`NormalizePage`, measured); `EnsPortal.MessageContents` declares no `RESOURCE`."
- **AD-5, a clause:** "A `detail` tab's page may give `DetailPage` a `body` component that draws the rows in place of the table, with everything else `ListPage` does unchanged (Story 20.9's Contents tab)."
- **EXPERIENCE.md:** :159, :604 and :856, as Tasks says.

**Strings (about 18 new literals, add-only; values checked unique at Task 0):**

- **List:**
  - `interopMessagesEmpty` "No message matches these criteria."
  - `interopMessagesCriterionErrors` "Marked as an error"
  - Prompts: "Which messages ended in error in the last hour?", "Which business host sent the most messages today?", "Show the messages of the newest session in the order they were sent."
- **Header:**
  - `interopMessageTabHeader` "Header"
  - `interopMessageHeaderEmpty` "This message no longer exists."
  - Prompts: "Why did this message fail?", "Which host sent this message, and which received it?", "Was this message answered, and when?"
- **Contents:**
  - `interopMessageContentsLabel` "Message contents"
  - `interopMessageTabContents` "Contents"
  - `interopMessageContentsEmpty` "This message has no contents to show."
  - `interopMessageContentsCut` "OcuPilot shows the first part of this message; the rest is cut."
  - `interopRefusalMessageContents`, the `INTEROP.MESSAGE.CONTENTS` sentence: "OcuPilot cannot show this message body as text."
  - Prompts: "Summarize what this message says.", "Which fields of this message are empty?", "Does anything in this message look malformed?"

**Header (23 rows, this order):** ID, Type, Priority, Invocation, TimeCreated, TimeProcessed, Status, IsError, ErrorStatus, SourceConfigName, TargetConfigName, SourceBusinessType, TargetBusinessType, SessionId, SuperSession, CorrespondingMessageId, BusinessProcessId, TargetQueueName, ReturnQueueName, MessageBodyClassName, MessageBodyId, Description, Resent.

**Fixture.** The marker is `OcuPilotProbe209` plus a run token. Each test creates in HSCUSTOM, in this order, because the window works on ID bounds and IDs must rise with `TimeCreated`:

- **Old:** a Completed header created two days ago.
- **Other:** created right after Old and 85,800 seconds ago (ten minutes after the default window opens), with source `<marker>SrcOther`, target `<marker>OpOther` and a distinct value for every other header property. It holds the default window's first ID bound inside the fixture and is the header a search by `<marker>Src` or `<marker>Op` must leave out. Its id is the fixture's fifth (`$ListBuild(old, xml, hl7, none, other)`).
- **XML:** `Ens.StringRequest` (`StringValue` holds the marker and `<&>`), Completed, Request, created 30 minutes ago, with its session equal to its own id.
- **HL7:** an `EnsLib.HL7.Message` read from ASCII text through a character stream (DW-2378's path), with a PID segment of 5,000 characters. Error, `IsError` 1 with an `ErrorStatus`, created 20 minutes ago, in the first header's session.
- **No body:** a Response, created 10 minutes ago.

Every header but Other has source `<marker>Src` and target `<marker>Op`.

**Integration, Consumes, Consumed-by (Rules 1 and 2):**

- **Integration:** AC4. The consumer is Queue messages (Stories 20.4 and 20.23), whose link opens this story's Header tab on a real production. The `body` input's first consumer is this story's Contents tab; Part B's Trace tab is the next.
- **Consumes:**
  - 20.4: `SqlRows`, `MESSAGESQL`'s row and `LocalStamp`, `interop-message`, and Queue messages.
  - 20.27: `RenderTargetHere`.
  - 19.x: `list (server criteria)`, the tab group, `documentScreenFor` and `Ledger.LocalToUtc`.
- **Consumed-by:**
  - Part B: the tab group, the `body` input and `SessionId`.
  - Part C: the list and the Header tab, as its resend's surfaces.
  - 20.12: its workflows and Investigate read messages through these tools.

**Rule 31 (extend, don't copy):**

- `ListMessages` shares `SqlRows`, `LocalStamp` and the extracted `MessageRow` with `ListItemMessages`. Only its SQL is new, because the criteria differ.
- `ReadMessageHeader` is SQL through `SqlRows`, not `HeaderFacts`' open, because `%EXTERNAL` answers the display words in one statement.
- `ReadMessageContents` calls `RenderTargetHere`, and adds only the stream branch.
- The time conversion reuses `Ledger.LocalToUtc`.
- The body component follows `DataTable`'s getters and the shared skeleton and fault classes.
- The tests reuse `runIris`, `list-spec.mjs`, `panel-spec.mjs`, the per-spec `structural` helper and InteropFloor's principals.
- New test classes, because `InteropHostRead` (673 lines) and `InteropDescriptor` (470) are at or over the 500-line guide.

**Contended files (Rule 11).** `origin/OCU-1-epic18` (`ad0fb51f`) is an ancestor of the feature branch; it carries no unmerged change today. This story's edits to these files are add-only: `Test/StageTwoTools.cls`, `Test/SurfaceCoverage.cls`, `Test/ReadTool.cls`, `Test/ToolRoundTrip.cls`, `screens.generated.ts` (regenerated), `strings.ts`, `screen-outlet.ts`, EXPERIENCE.md, the side-bar specs and the spine. No Rule 11 ask.

`shell/list-page.ts` and `shell/detail-page.ts` are outside the contended list. If Story 18.38 lands an edit to either first, re-anchor at the forward merge.

**Named limits:**

- Saved searches are not offered (Q2).
- Extended criteria (body property, search table, virtual-document path) stay in the classic viewer.
- Source, target and body class match in any letter case, as the item Messages tab does (column collation).
- A search filtered only by error flag or type over a long window reads every header in its ID range, because neither column is indexed.
- The window is the classic viewer's ID-bound conversion, so a header whose `TimeCreated` runs against its ID order (a clock change) can fall in or out of a window as it does there.
- Contents show at most 1,000,000 characters and the read's row cap of lines, each cut at 4,000. A binary body, or one that is not text, is refused with its sentence after the vendor's audit row is written.
- The Header table cuts a long `ErrorStatus` in its cell; the read and the context carry it whole.
- Only Queue messages links to a message. The item tabs are `detail` screens, which may not declare a `rowTarget` (`Screen/Registry.cls`:3933, contended), and the job rows already link their process.
- Message Bank and Sequence Manager searches are not covered.
- The trace, resend and edit-and-resend are Parts B and C.

**Ledger inbox (Rule 17):** none (`slice` empty).

## Verification

**Shared surfaces:**

- the Interoperability navigation roster (`Navigation.cls`, `navigation.test.mjs`);
- `StageTwoTools`' `Elsewhere`, `SurfaceCoverage`'s screen rows and `InteropFloor`'s rosters;
- the `ReadTool` and `ToolRoundTrip` rosters;
- `screen-mirror.test.mjs`'s `ownPrivileges` owners;
- `InteropQueueMessageList`'s declaration (now with `rowTarget`) and its `MessageId` cell;
- `ListPage` and `DetailPage`'s templates;
- the structural walk's `SKIP` and baseline;
- the strings table and EXPERIENCE.md :159, :604 and :856;
- the built-screen count that Screen permissions derives (+3).

*Every test added or changed passes on a fresh environment, in either order.* Every message a test reads is one it created, found by its marker, and removed after. No test asserts on a header store being empty.

**Setup (slot B; never the dev instance `ocupilot-slot-b`):**

- **Load `src`:**
  1. Run `rsync -a --checksum --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-20/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`.
  2. In `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`, run `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)`.
- **Before any browser run:** `cd ui && npm run build && docker exec ocupilot-b-ci sh -c 'cd /durable/iris/csp/ocupilot && rm -rf ./*' && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`.

**Commands.** Run each in the foreground with `timeout: 600000`, one at a time. Read each class's result from `%UnitTest_Result`.

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.InteropMessageRead --class OcuPilot.Test.InteropMessageContents --class OcuPilot.Test.InteropMessageDescriptor`. Expected: green.
- `(loop)` The same runner with `OcuPilot.Test.InteropFloor`, `OcuPilot.Test.StageTwoTools`, `OcuPilot.Test.SurfaceCoverage`, `OcuPilot.Test.Navigation`, `OcuPilot.Test.ReadTool`, `OcuPilot.Test.ToolRoundTrip`, `OcuPilot.Test.InteropHostDescriptor`, `OcuPilot.Test.Descriptor`, `OcuPilot.Test.CompileWithoutInterop`, `OcuPilot.Test.InteropFloorOwnPairs`, `OcuPilot.Test.ScreenAccessWire`, `OcuPilot.Test.ToolNavigate` and every class the sweep changes. Expected: green (about 85 s by `ci-timings.json`).
- `(loop)` `cd ui && npm run test:tools`, then `cd ui && npm run test:components`. Expected: green.
- `(loop)` `cd ui && npm run build -- --verbose`. Expected: the prebuild chain is green, the new chunk is under 88 kB, and the initial total is under 1992kB. Record both.
- `(loop)` `uv run scripts/check-objectscript.py <each changed .cls>` and `bash scripts/lint-docs.sh`. Expected: clean.
- `(loop)` `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/<file>`, one file per call, after the redeploy. Expected: green.
  - `interop-messages.browser-spec.mjs`
  - `interop-queue-job-actions.browser-spec.mjs`
  - `a11y-structural-invariants.browser-spec.mjs` (about 445 s)
- **Lead-owned (the runner's):**
  - the full ObjectScript sweep;
  - `cd ui && npm test`;
  - `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`;
  - Rule 30's fresh check.
- **Left to CI:** the full browser suite.

**Planned pinning mutations (Rule 19).** Revert each byte-identical. Reload, or rebuild and redeploy, before the next.

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | `ListMessages` drops the `Status = ?` fragment | `InteropMessageRead`'s status leg, and the browser AC1 Error leg |
| AC1 | `ListMessages` skips the lower ID bound | The default-window legs (the two-day-old header returns) |
| AC1 | The list's read is pointed at `ItemMessages` | `InteropMessageDescriptor`, and the browser AC1 (refused for a missing item) |
| AC2 | `ReadMessageHeader` reads `TimeCreated` raw, without `LocalStamp` | `InteropMessageRead`'s stamp leg |
| AC2 | The Header tab's route is moved off `/document` | `navigation.test.mjs`'s pairing test, and the browser AC2 |
| AC3 | `ReadMessageContents` stops cutting lines | `InteropMessageContents`' long-line leg, and the browser AC3 HL7 leg |
| AC3 | The `AuditViewMessage` call is removed | `InteropMessageContents`' audit leg, alone |
| AC3 | The body component renders `Text` through `[innerHTML]` | `interop-message-contents.spec.ts`'s `<script>` test, and `client-lint` |
| AC3 | `ListPage` ignores `body` | The list-page and detail-page specs, and the browser AC3 (no `pre`) |
| AC4 | `InteropQueueMessageList`'s `rowTarget` is removed | The queue spec's AC4 test, `navigation.test.mjs`, and `InteropMessageDescriptor` |
| AC5 | `%Ens_MessageContent:USE` is dropped from the Contents descriptor and from `Pairs` | `InteropFloor`'s Operator legs, and `InteropMessageDescriptor` |
| AC5 | One `Elsewhere` row is removed | `StageTwoTools` `TestTheRosterAndElsewhereAreEveryRegisteredScreen`, alone |

**Mutations run (Rule 19).** Each applied, observed red on `ocupilot-b-ci` (ObjectScript recompiled by a full reload, the bundle rebuilt and redeployed for a client mutation), and reverted byte-identical (the file's sha256 compared before and after).

- mutation: `InteropPort.ListMessages` without its `Status = ?` fragment -> `InteropMessageRead.TestEveryCriterionNarrowsAloneAndTogether` (the status and combined legs), and the browser AC1
- mutation: `ListMessages` without its `IsError = ?` fragment -> `InteropMessageRead.TestEveryCriterionNarrowsAloneAndTogether` (the errors legs)
- mutation: `ListMessages` binds the lower ID bound 0 -> `TestEveryCriterionNarrowsAloneAndTogether` and `TestTheWindowIsTheIdRangeBetweenTheBounds` (the default window returns the two-day-old header)
- mutation: `ListMessages` without `.999` on the end bound -> `TestTheWindowIsTheIdRangeBetweenTheBounds` (the end-second leg)
- mutation: `ListMessages` always asks for `SQLMAX` -> `TestACapTruncatesThroughTheReadRoute`
- mutation: `ListMessages` without its session check -> `TestEachMalformedCriterionIsRefusedByName`
- mutation: two words of `STATUSWORDS` swapped -> `TestTheStatusAndTypeWordsAreTheVendorsOwn` and the status legs of `TestEveryCriterionNarrowsAloneAndTogether`
- mutation: `ReadMessageHeader` reads `TimeCreated` without `LocalStamp` -> `TestTheHeaderReadsTwentyThreePropertiesInOrder`
- mutation: `InvokeRuntime` without its message-id shape check -> `TestAnUnknownIdIsNoRowsAndAMalformedIdIsRefused` (every malformed leg, on both endpoints)
- mutation: the search's `source` criterion renamed in `InteropMessageList` -> `TestTheReadRouteAndTheReadToolAnswerTheSameRows`
- mutation: `InteropMessageList` reads `ItemMessages` -> `InteropMessageDescriptor.TestTheThreeDeclarationsRegister` (and `Registry.Validate`, which refuses the criteria off a searchable endpoint), and the browser AC1
- mutation: `InteropMessageHeaderTab` route moved off `/document` -> `InteropMessageDescriptor` (`TestTheThreeDeclarationsRegister`, `TestTheQueueMessagesListLinksToTheMessage`); in `screens.generated.ts`, `navigation.test.mjs` (the pairing test and the side-bar test) and the browser AC2
- mutation: `ReadMessageContents` stops cutting lines -> `InteropMessageContents.TestTheHl7BodyIsItsSegmentsAndALongLineIsCut`, and the browser AC3
- mutation: `AuditViewMessage` call removed -> `InteropMessageContents.TestTheXmlBodyIsIndentedXmlAndItsViewIsAudited` and `TestABodyThatIsNotTextIsRefusedAfterItsViewIsAudited`, alone (every text leg stays green)
- mutation: no CRLF or CR normalization in `ReadMessageContents` -> `TestACharacterStreamIsItsTextSplitOnAnyLineEnd` and the XML line legs
- mutation: `ContentsText` reads a binary stream as text -> `TestABodyThatIsNotTextIsRefusedAfterItsViewIsAudited`
- mutation: `ContentsText` audits before it opens the body -> `TestAMessageWithNothingToShowReadsAsNoRowsAndRecordsNoView`
- mutation: `ReadMessageContents` without its `TESTOUTPUTMAX` cut -> `TestTheTextIsCutAtItsOverallCapAndTheLinesAtTheRowCap` (row 1,001 reads `x ... [cut]`)
- mutation: `ReadMessageContents`' length test `>=` instead of `>` -> `TestATextAtTheCapIsWholeAndOneCharacterOverIsCut` (exact-cap leg), alone
- mutation: `ReadMessageContents`' length test `> TESTOUTPUTMAX + 1` instead of `> TESTOUTPUTMAX` -> `TestATextAtTheCapIsWholeAndOneCharacterOverIsCut` (one-over leg), alone
- mutation: `AuditViewHere` without its alarm test -> `TestAnAlarmBodyIsReadAndItsViewIsNotAudited`
- mutation: `rowTarget` removed from `InteropQueueMessageList` -> `InteropMessageDescriptor.TestTheQueueMessagesListLinksToTheMessage`; its field changed in `screens.generated.ts` -> `navigation.test.mjs`'s Story 20.9 test; `rowTarget` null in the bundle -> the queue spec's AC4 test
- mutation: the Contents pair dropped from `Pairs` alone -> `InteropMessageDescriptor.TestThePortDeclaresEachScreensPairs`; dropped from `Pairs` and the Contents descriptor -> `InteropFloor` (four tests, the Operator-refused Contents leg among them) and `InteropMessageDescriptor`
- mutation: `MESSAGEPAIRS` and `InteropMessageList` reduced to `%Ens_Portal:USE` -> `InteropFloor` (four tests, the portal-holder Messages leg among them)
- mutation: `%Ens_MessageHeader:READ` declared as the list's own pair -> `InteropMessageDescriptor.TestTheClassicPageSharesTheScreensPair`
- mutation: the `InteropMessageList` row removed from `StageTwoTools` `Elsewhere` -> `StageTwoTools.TestTheRosterAndElsewhereAreEveryRegisteredScreen`, alone
- mutation: `Registry.CriteriaProblem` back to refusing every unparented interop criteria block -> `ReadTool.TestEveryCriteriaCorpusCaseGetsItsSentence` and `InteropMessageDescriptor`; the same in `screen-mirror.mjs` -> `screen-mirror.test.mjs`
- mutation: `InteropPort.SEARCHENDPOINTS` emptied (`""`) -> `InteropMessageDescriptor` (`TestTheThreeDeclarationsRegister`, `TestThePortDeclaresEachScreensPairs`) and `ReadTool` (`TestEveryCriteriaCorpusCaseGetsItsSentence`, `TestEveryDeclarationCorpusCaseGetsItsSentence`); in `screen-mirror.test.mjs`, `criteriaProblem returns every sentence OcuPilot.Test.CriteriaCorpus declares` and the checked-in mirror test (the generator refuses the Messages criteria)
- mutation: `ReasonFor` without `INTEROP.MESSAGE.CONTENTS` -> `InteropDescriptor.TestEveryInteropErrorCodeResolvesToItsSentence` and `InteropMessageContents.TestABodyThatIsNotTextIsRefusedAfterItsViewIsAudited`; the sentence changed in `strings.ts` -> `interop.test.mjs`
- mutation: the Contents block binds its text through `[innerHTML]` -> `interop-message-contents.spec.ts` and the browser AC3 (`client-lint` stays clean, a deferred note)
- mutation: `ListPage.drawsBody` always false -> `list-page.spec.ts`'s Story 20.9 test, and the browser AC3; always true -> that test and the table specs
- mutation: `[body]="body()"` dropped from either `app-list-page` of `DetailPage` -> `detail-page.spec.ts`'s Story 20.9 test
- mutation: `showSkeleton`, the `isBannerFault` test, `showEmpty`, `cut` or the descriptor comparison of `boundHere` altered in the Contents block -> that state's test in `interop-message-contents.spec.ts`
- mutation: the marker checkbox or the names hint drawn for every screen, or `AuditSearch.adopt` dropped -> `audit.page.spec.ts`'s two Story 20.9 tests
- mutation: `.ocu-message-contents` given its own surface as its text color -> the browser structural test (contrast on the Contents tab)
- mutation: `ListMessages` without its `SourceConfigName = ?` fragment -> `InteropMessageRead.TestEveryCriterionNarrowsAloneAndTogether` and `TestTheWindowIsTheIdRangeBetweenTheBounds`, and the browser AC1 and AC2; without its `TargetConfigName = ?` fragment -> `TestEveryCriterionNarrowsAloneAndTogether` alone
- mutation: `HEADERSQL` with `%EXTERNAL(Priority)` and `%EXTERNAL(Invocation)` swapped -> `InteropMessageRead.TestTheHeaderReadsTwentyThreePropertiesInOrder` alone (its all-properties leg)
- mutation: (review) `InteropMessageRead.Opening` answers `LocalAgo(86400)`, with headers of another source stored in HSCUSTOM 23 h 55 min, 27 min and 12 min ago -> `TestEveryCriterionNarrowsAloneAndTogether` and `TestTheWindowIsTheIdRangeBetweenTheBounds`; as written, `InteropMessageRead` and `InteropMessageRows` are green with those headers stored
- mutation: `Set $NAMESPACE = pNamespace` removed from `ContentsText` -> the queue spec's AC4 test (its Contents leg reads the probe message in USER)
- (QA) test file added: `src/OcuPilot/Test/InteropMessageRows.cls` (unarmed, 3 tests, green on `ocupilot-b-ci` beside `InteropMessageRead`, `InteropMessageContents`, `InteropMessageDescriptor` and `ReadTool` after the reverts below).
- (QA) test files extended: `ui/browser/interop-messages.browser-spec.mjs` (AC5: an Operator and the Contents tab's gate), `ui/browser/interop-queue-job-actions.browser-spec.mjs` (Messages searched in USER), `ui/src/app/areas/interoperability/interop-message-contents.spec.ts` (an empty line stays a line).
- (QA) Each mutation below was applied, observed red on `ocupilot-b-ci` (ObjectScript reloaded, client specs run on the working tree, the browser specs on the deployed bundle), and reverted with the file's sha256 equal to HEAD's.
- (QA) mutation: `ListMessages` without its test that an end with no last header means no rows -> `InteropMessageRows.TestAWindowEndingBeforeEveryHeaderHoldsNoneAndABeginBeforeEveryHeaderOpensAtTheFirst`, alone
- (QA) mutation: `MessageRow` reads `TimeCreated` without `LocalStamp` -> `InteropMessageRows.TestASearchRowCarriesEveryFieldItDeclaresUnderItsOwnNameAndType` (the three row lines)
- (QA) mutation: `MessageRow` leaves the search columns `Type` and `Error` out -> `InteropMessageRows.TestASearchRowCarriesEveryFieldItDeclaresUnderItsOwnNameAndType` (the field legs and the row lines); `InteropMessageRead` (8 tests) stayed green under it, because the route and the tool answer the same missing cell
- (QA) mutation: `InteropMessageList` offers `Defered` for `Deferred` -> `InteropMessageRows.TestEveryChoiceTheFormOffersIsOneThePortTakes` (the status list and that word); `InteropMessageDescriptor` (4 tests) stayed green under it
- (QA) mutation: `Registry.CriteriaProblem` takes every interop endpoint as searchable -> `ReadTool.TestEveryCriteriaCorpusCaseGetsItsSentence` (the Story 20.3 case and the not-searchable case of Story 20.9); the same in `screen-mirror.mjs` (`searches = port === SOURCE_INTEROP`) -> `screen-mirror.test.mjs`' `criteriaProblem returns every sentence OcuPilot.Test.CriteriaCorpus declares` (it stops at the first case, the Story 20.3 one)
- (QA) mutation: `AuditSearch.adopt` without its same-screen early return -> `audit.page.spec.ts` `a return after a Search re-runs that Search`, alone
- (QA) mutation: `AuditPage.hasMarker` always false -> seven Audit tests of `audit.page.spec.ts` (the declared-controls, default-read, marker and arrival tests)
- (QA) mutation: the Contents block filters out rows whose `Text` is empty -> `interop-message-contents.spec.ts` `keeps an empty line an empty line`, alone
- (QA) mutation: `%Ens_MessageContent:USE` dropped from `InteropMessageContentsTab`'s `privileges` and `ownPrivileges` -> `interop-messages.browser-spec.mjs` AC5 (the Operator's Contents tab reads `aria-disabled` false), alone
- (QA) mutation: `ListMessages` reads `HSCUSTOM` whatever namespace the request names -> `interop-queue-job-actions.browser-spec.mjs` `AC1 in USER` (the default read of USER lists no row and the row wait times out)
- (QA) `mutations_demonstrated=11`.
- (review) Each applied on `ocupilot-b-ci` (the three port mutations together on the throwaway's copy of the source, each red at its own leg alone; the worktree untouched), reverted, reloaded and the classes green again; the client one on the working tree, the file's sha256 equal after.
- mutation: (review) the Contents block's `text` draws `store.data()` instead of the store's view -> `interop-message-contents.spec.ts` `draws the lines the command bar's filter and sort leave`, alone
- mutation: (review) `MessageRow` with its production test inverted -> `InteropHostRead.TestEachEndpointAnswersTheProbesRows` (the item's messages leg) and `TestEachScreenAndToolAnswerTheSameRowsAsThePort`
- mutation: (review) `OpenBodyHere` without its `%ExistsId` test -> `InteropMessageContents.TestAMessageWithNothingToShowReadsAsNoRowsAndRecordsNoView` (the stream leg), alone
- mutation: (review) `HEADERSQL` with `TimeCreated` and `TimeProcessed` swapped -> `InteropMessageRead.TestTheHeaderReadsTwentyThreePropertiesInOrder`, alone

## Auto Run Result

Status: done
Blocking condition: none

**This pass (rework 1).** `ReadMessageContents` cuts the text at `TESTOUTPUTMAX` characters and appends `TESTCUT` before it normalises line ends; the shared `StreamText` is unchanged (AD-62 item 15; closes the open High). The cap test expects row 1,001 to be `TESTCUT` alone, and `TestATextAtTheCapIsWholeAndOneCharacterOverIsCut` pins the boundary on both sides.

**Files.** `src/OcuPilot/Port/InteropPort.cls` (the cut); `src/OcuPilot/Test/InteropMessageContents.cls` (the cap test's row and Mutation note, the boundary test, the `CapStream` helper both use); this spec (the item ticked, three `mutation:` lines, the triage entry).

**Review.** 7 findings, 6 low and 1 false: 1 low patched (the boundary test), 6 rejected with their reasons in the Triage Log (2 carried), none deferred. `followup_review_recommended: false` (one low patched).

**Verification (`ocupilot-b-ci`, tree loaded with 0 errors).** `InteropMessageContents` 8, `InteropMessageRead` 8, `InteropMessageRows` 3 and `InteropTransformTest` 7, each green in its own call; `check-objectscript.py` 0 problems; `lint-docs.sh` clean. Mutations on the throwaway's copy, restored after (an `rsync --checksum` dry run empty), the worktree never mutated: the cut removed reddens the cap test alone; `>=` and `> TESTOUTPUTMAX + 1` each redden the boundary test alone, at its own leg.

**Residual risks.** None new. The full ObjectScript sweep, `npm test` and the smoke are the runner's.
