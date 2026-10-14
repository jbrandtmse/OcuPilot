---
title: 'Story 20.30: The session trace'
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

**Problem:** To follow a message through a production, a person still leaves for the classic Visual Trace (`EnsPortal.VisualTrace`). Story 20.9's message tabs show one header and its contents, never the session around it, and Story 20.6's host test names its session only as text.

**Approach:**

- **Read.** A third message tab, Trace, reads the opened message's whole session through `Port/InteropPort`: a new endpoint `MessageTrace`, two top-level statements, capped.
- **Visual trace.** OcuPilot draws the trace itself, as an SVG sequence diagram, through 20.9's `body` input.
- **The alternative.** Mermaid `sequenceDiagram` text, built in the browser from the same rows.
- **From the host test.** The Test dialog's answer links to its session's trace.

## Boundaries & Constraints

**Always:**

- **Through the port** (AD-29, AD-62 (2)). The read goes through `InteropPort.Invoke`, behind `Admit`.
  - `MessageTrace` takes an explicit `Pairs` branch ahead of the `CODEPAIRS` default: 20.9's message pairs plus `%Ens_MessageTrace:USE`.
  - The pairs come first, then READ on the namespace's globals database. A refusal names the failed pair.
- **SQL** (AD-21, AD-29). Two top-level statements through `SqlRows` (`%ExecDirectNoPriv`), run switched, with every value bound and no nested `TOP`:
  1. the header's `SessionId` by `ID`;
  2. `TOP ?` of that session's headers, `ORDER BY ID`.
- **Ids.** The criterion `message` is a 20.9 message id (`^[1-9][0-9]{0,18}$`), checked by 20.9's own check.
  - An id no header holds, or a header with no `SessionId`, reads as zero rows (AD-37).
  - Any other text is refused 400 `PORT.VALIDATION`, naming `message`.
- **Rows.** `{Message, Step, ID, TimeCreated, Status, Type, Source, Target, BodyClass, SessionId, Error}`, built through 20.9's `MessageRow`.
  - `Step` is a JSON number, 1 to n in `ID` order, and the read's only sort key.
  - Every other value is a string. `TimeCreated` is local time (`LocalStamp`).
- **Drawing** (AD-5 `body`; AD-11 and AD-47).
  - Participants run left to right in first-appearance order: for each row in `Step` order, its source, then its target.
  - There is one arrow per row, in `Step` order. A `Response` arrow is dashed; every other type is solid.
  - An `Error` row is drawn in the error token, and its label carries the error mark.
  - Each arrow is a link to its message's Header tab, built with `entityUrl` and followed in the app.
  - The drawing uses template bindings only. Data reaches it only as attribute values and interpolated text: no `innerHTML`, and no `style` or `id` taken from data. Colors come from tokens, through classes.
- **Mermaid.** Built in the browser from the rows the diagram draws.
  - The text is `sequenceDiagram`, then one `participant` line per participant, then one arrow line per row: `->>` for a request, `-->>` for a response.
  - It follows the id, escape and label rules of the sibling project's `Diagram/Writer.cls` (Design Notes › Mermaid).
  - It has no compression, no correlation and no comment lines.
- **Strings** live in `strings.ts` and in EXPERIENCE.md's Fixed strings, with unique values. Contended files take add-only edits (Design Notes › Contended files).
- **No compile-time interoperability** (AD-62 (12)). `Ens.*` is named only in method bodies, SQL text and strings.

**Never:**

- A call to `%Api.InteropEditors` or a request under `/ui/interop/`. The vendor's message viewer and Visual Trace are not embedded.
- A write of any kind: no tool, governance key, change event or proposal.
- A read of `Ens_Util.Log`, `Ens_Rule.Log` or `Ens_Util.IOLog`, or following `SuperSession`. This is a named limit, stated by the read's note.
- Mermaid built on the server, or a second read for it.
- Edits to:
  - `Screen/Registry.cls`, `Screen/Read.cls`, `Kernel/EntityType.cls`, `Kernel/Proposal/Prohibited.cls`, `Kernel/Governance/Baseline.cls`, `Port/LogSourcePort.cls`;
  - `app.routes.ts`, `angular.json`;
  - `.github/workflows/ci.yml`, `ui/tools/ci-shards.mjs`, `ui/tools/ci-timings.json`, `ui/tools/ci.test.mjs`.
- A new armed test class, or a new principal in `InteropFloorFixture`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Open | Any header of a session (its first, middle or last), on the Trace tab | Every header of that session, in `ID` order, as `Step` 1..n. A header of another session is absent | - |
| Draw | Four rows, three participants, one error response | Columns in first-appearance order. Arrows 1 and 2 solid, 3 and 4 dashed. Arrow 3 in the error token, its label ending with the error mark. Each arrow's `href` is `/ocupilot/interoperability/messages/document/<ID>?ns=<ns>` | - |
| Follow | Click or Enter on an arrow | That message's Header tab, in the same namespace. Ctrl, Meta, Shift or a non-primary button keeps the browser's default | - |
| Self call | Source equals target | A loop on that participant's lifeline. Mermaid `A->>A: …` | - |
| Unnamed | Empty `Source` or `Target` | The SVG labels it `interopTraceNoName`. Mermaid gives it the id `P` (Writer) | - |
| No body | Empty `BodyClass` | The label `interopTraceNoBody`, in both views | - |
| Mermaid | Choose Mermaid text | `<app-code-block>` with the text and its Copy control. Diagram is the default view | - |
| Filter | Text in the command bar's filter | Only the matching rows are drawn, in both views, and the participants come from those rows. No match: `logViewerNoMatches` | - |
| Capped | More headers than `maxRows` | The first `maxRows` by `ID`, `truncated`, and `interopTraceCut` above the drawing | - |
| Gone | An id no header holds, or a header with no session | Zero rows: `interopMessageHeaderEmpty` | - |
| Bad id | `message` not 1 to 19 digits | - | 400 `PORT.VALIDATION`, naming `message` |
| Missing id | No `message` | - | 400 `READ.CRITERION` (`Screen/Read`) |
| Gated | Caller lacks `%Ens_MessageTrace:USE` | The Trace tab stays in the strip, `aria-disabled`, reading "Requires %Ens_MessageTrace:USE". Its read answers 403 with that `failedPair` | - |
| Markup | A config name holding `<script>` | Drawn as the text it is, with no element made of it | - |
| Test answer | Story 20.6's Send test answers a `sessionId` of digits | The dialog shows `interopTestTraceLink`, which opens `interoperability/messages/trace/<sessionId>` in the list's namespace. With no `sessionId`, there is no link | - |

</intent-contract>

## Code Map

All paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-20`. Lines were read at `aefeba8c83d4554f28aac19c89b139ad9abd0e2b`. Stories 20.8 and 20.9 land first, so Task 0 re-anchors every 20.9 symbol named here. Each is marked **(20.9, planned)**.

**Port, `src/OcuPilot/Port/InteropPort.cls`** (6,226 lines):

- **Declarations.**
  - `ENDPOINTS` :82 (screen-mirror reads it). `ITEMMESSAGEPAIR` `%Ens_MessageHeader:USE` :189.
  - `ENTITYMESSAGE` :524, `MAXROWSKEY` :588, `REASONMESSAGEREQUIRED` "Name the message." :640.
- **Dispatch.**
  - `RuntimeEndpoints` :724-727.
  - `Pairs` :744-779. The default `CODEPAIRS` is at :766-767; ItemMessages' "base plus own pair" branch is the shape to follow.
  - `Serves` :786 (`LIST` serves every endpoint), `Invoke` :884-974, `Admit` :981-1000.
  - `InvokeRuntime` :2625-2684: `maxRows` must be digits, and empty means `SQLMAX`; the queue branch is :2652-2660, and the item parse is at :2661.
- **Reads.**
  - `LocalStamp` :3084.
  - `SqlRows` :3152-3180: `pFound(n)` is a `$ListBuild`, and a fault goes to `pCaught`. The no-nested-`TOP` rule is in its doc at :3148.
  - `MESSAGESQL` :3195, `SQLMAX` :3198.
  - `ListItemMessages` :3233-3263, whose row builder 20.9 extracts as `MessageRow`.
- **(20.9, planned):**
  - the endpoints `Messages`, `MessageHeader` and `MessageContents`;
  - `MESSAGEPAIRS`;
  - the `message` id check and its `InvokeRuntime` branch ahead of the item parse;
  - `MessageRow`, with the search's column order `ID, TimeCreated, %EXTERNAL(Status), %EXTERNAL(Type), SourceConfigName, TargetConfigName, MessageBodyClassName, SessionId, IsError`.

**Read and registry (read only):**

- **`src/OcuPilot/Screen/Read.cls`:**
  - The interop branch is :554-576. It sends `maxRows` as the cap plus 1 (:559), and refuses a missing parent criterion with 400 `READ.CRITERION` (:562-566).
  - `ApplyView` :1523: numbers compare as numbers and text by code unit, so an `ID` string never sorts.
- **`src/OcuPilot/Screen/Registry.cls`:**
  - `TabProblem` :572-620.
  - `TabGroupProblem` :694-780: positions run 1..n, the group is `<parentScope>/document` (:771-773), and every member shares the one criterion (:764-768).
  - The interop read source :1304-1317. `CriteriaProblem` :1681, with hint length at most 300 (:1941).
  - `TABLECOLUMNKINDS` :2627, `TableProblem` :2643 (a read declares a table), `PROMPTGROUPKEYS` :3007.
- **Siblings:**
  - `Screen/Descriptor/InteropItemMessageTab.cls`:13-66 is the shape of a parent-scoped `detail` tab.
  - `Kernel/EntityType.cls`:121 is `interop-message`.

**Tests and rosters (`src/OcuPilot/Test/`):**

- `StageTwoTools.cls` `XData Elsewhere` :120-258 (interop rows :175-196), pinned by `TestTheRosterAndElsewhereAreEveryRegisteredScreen` :408-440.
- `SurfaceCoverage.cls` interop screen rows :226-250. `Descriptor.cls` `XData ReadShapes` :67 (interop rows :196-214), pinned at :227.
- `Navigation.cls`:531-545: the interop count is 22 at :539 and the order is at :540. Position-0 screens sort first, by class name.
- `InteropFloor.cls`:
  - `OPERATORSCREENS` :53 and `OPERATORTOOLS` :56.
  - `TestTheInteroperabilityReadsFollowTheirOwnPairs` :238-259 (the leg shape is at :255-256).
  - `TestEveryOpenScreenMatchesItsClassicPage` :310-348: an open screen declares a pair from its classic page's `RESOURCE`.
- `InteropFloorFixture.cls`:25-34 and :64 hold the four principals. Only `%EnsRole_Operator` and Administrator hold the message pairs.
- `ReadTool.cls`:93-94 (385 tools). `ToolRoundTrip.cls` `REFUSEEMPTY` :94.
- `InteropHostDescriptor.cls`: the `ENDPOINTS` literal :23 and the `RuntimeEndpoints` literal :169, asserted in :166-180.
- `InteropHostTest.cls`:289, :322 and :436 pin the host test's `sessionId`.
- **(20.9, planned):** `InteropMessageRead` (its synthetic-header fixture), `InteropMessageDescriptor`.

**Client (`ui/src/app/`):**

- **Pages.**
  - `shell/detail-page.ts`: strip :62-95, `resolved` :104-121, `open`/`targetRoute` :157-184.
  - `shell/list-page.ts` :80-118, :161-214.
  - **(20.9, planned):** both gain a `body` input; `areas/interoperability/interop-message-contents.ts` and its `.page.ts`.
- **State.**
  - `shell/data-table.ts`: getters :818-858 (`boundHere`, `loaded`, `fault`, `showSkeleton`, `showEmpty`, `emptyTitle`); skeleton and fault markup :217-257; the link `<a [href]>` at :376, built at :682-699; `onLinkClick` :1552-1557.
  - `core/screen-store.ts`: `ScreenStore` :107 (`data` :237, `truncated` :241, `filter` :498); `DEFAULT_MAX_ROWS` is 1000 (:45).
  - `core/refresh.ts`: `fault` :319, `hasLoaded` :324, `readNow` :421.
  - `core/screen-read.ts` `applyView` :108. Its use for a custom body is `areas/logs/log-hub.page.ts`:370-376.
- **Links.** `core/navigation.ts`: `withQuery` :766-774, `NAMESPACE_PARAM` `ns` :749, `entityUrl` :783. `core/entity-id.ts` `encodeEntityId` :69.
- **Building blocks.**
  - `shell/screen-outlet.ts`: `PageLoader` :28; interop rows of `DESCRIPTOR_PAGES` :215-229.
  - `shell/code-block.ts` (`steps` input :34): a `pre` with its own Copy control.
  - The view group: `areas/system-explorer/document-viewer.page.ts`:140-152 (`role="group"`, `viewMenuLabel`, `aria-pressed`), with its state `SourceViewerState` in `document-viewer.store.ts`:122 (`view` :152, `setView` :197).
  - Template-bound SVG: `areas/home/performance-row.ts`:64-74 and `shell/rail-icon.ts`:33-57. No SVG `<a>` exists yet.
  - Tokens: `styles/_tokens.scss` (`--ocu-on-surface` :92, `--ocu-outline` :97, `--ocu-outline-variant` :99, `--ocu-error` :67, `--ocu-secondary` :49, `--ocu-focus-ring` :166). The dark theme is `_theme.scss`:153-224. No `stroke-dasharray` exists yet.
- **Host test.**
  - `core/test-answer.ts`:20-67, where `sessionId` is a string.
  - `areas/interoperability/interop-item-test-dialog.ts`: the result block :183-190, getters :314-332.
  - `interop-item-test.page.ts`:141-162.
  - `core/strings.ts` `interopTest*` :7114-7120. The table ends at :7205-7210.
- **Lint.** `ui/tools/client-lint.mjs` `RULE_FAMILIES` :668-675 includes no hard-coded colors and no literal text nodes or aria labels. It has no innerHTML rule; AD-11 rule 4 is the convention.
- **Budgets.** `ui/tools/strings.test.mjs`:612-615 (bound 3,800). `build-output.test.mjs`:267 (`LAZYCHUNKMAX` 88 kB). `angular.json`:54 (1992kB).

**Tools and browser:**

- `ui/tools/navigation.test.mjs`: the roster :140-413 (interop :371-401) and the tab-strip pin :796-808. `ui/tools/screen-mirror.test.mjs` `owners` :2429-2478.
- `ui/browser/interop-item-test.browser-spec.mjs` (255 lines; armed probe production in `USER`): `structural` :66-87, `openTestTab`, `openDialog`, `before`/`after` :153-177, AC2 :195-217.
- `ui/browser/structural-walk.mjs`:
  - `SKIP` :101-129 and `needsId` :211-213.
  - It collects only `HTMLElement` and `SVGSVGElement` (:336), so nothing inside an SVG is checked.
- Helpers: `list-spec.mjs`:37 and :182; `panel-spec.mjs`:64; `turnprobe-spec.mjs` `runIris` :53 and `markerValue` :81.

**Vendor and sibling (read only):**

- **`irislib/EnsPortal/VisualTrace.cls`:**
  - `RESOURCE` `%Ens_MessageTrace:USE` :10.
  - `GetActualSessionId` :771-775 accepts a message id.
- **`irislib/EnsPortal/SVG/VisualTrace.cls`:**
  - `sqlSESSION` `ORDER BY %ID` :1516-1579.
  - The logs: `Ens_Util.Log` :1598-1603, `Ens_Rule.Log` :1616-1621, the IO log :1643-1671.
- **`irislib/Ens/MessageHeader.cls`:**
  - `NewRequestMessage` :57-72: `SessionId` is the header's own id when the session is new.
  - `NewResponseMessage` :84-116: it keeps the session and swaps source and target.
  - `Index SessionId` :24.
- **`irislib/EnsLib/Testing/Service.cls`:**34-51: `SendTestRequest` answers the service's `%SessionId`.
- **`/Users/jbrandt/git/iris-execute-mcp-v2/src/ExecuteMCPv2/Diagram/Writer.cls`** (MIT, `Copyright (c) 2026 jbrandtmse`):
  - `RegisterParticipant` :158-173, `SanitizeId` :192-213 (the keywords are at :209), `SingleLine` :221-224.
  - The participant lines :60-67, `ArrowLine` :181-187.
  - Excluded: Writer :95-102 and :131-149, `Compressor.cls` and `Correlator.cls`.

## Tasks & Acceptance

**Execution:**

- [ ] **Task 0 (re-anchor, no code).** After 20.8 and 20.9 have merged into this branch, re-read and anchor every **(20.9, planned)** symbol:
  - `MESSAGEPAIRS`, the `message` id check, `MessageRow` and its column order and `Error` values;
  - 20.9's header fixture;
  - the `body` input;
  - `InteropMessageContents`' state getters;
  - the message tab group;
  - `InteropMessageDescriptor`;
  - the strings tail and EXPERIENCE.md :159, :604 and :856;
  - every roster line in this Code Map.

  Then:
  - Run `git diff --stat $(git merge-base HEAD origin/OCU-1-epic18) origin/OCU-1-epic18` over the contended files. It was empty at plan.
  - Confirm on `ocupilot-b-ci` that 20.6's own asynchronous host test (`InteropItemTestSend`) leaves the session rows AC3 asserts. A sync `SendTestRequest` was measured (Design Notes).
- [ ] **`src/OcuPilot/Port/InteropPort.cls`** -- add `MessageTrace` (`LIST`, criterion `message`):
  - Add it to `ENDPOINTS` and `RuntimeEndpoints`.
  - Add `MESSAGETRACEPAIR` `%Ens_MessageTrace:USE`. `Pairs` gives `MessageTrace` `MESSAGEPAIRS` plus that pair, before `CODEPAIRS`.
  - `InvokeRuntime` routes it through 20.9's `message` branch and id check.
  - **`ListMessageTrace`:**
    - `TRACESESSIONSQL` `SELECT SessionId FROM Ens.MessageHeader WHERE ID = ?`. No row, or an empty `SessionId`, means zero rows (200).
    - `TRACESQL` is `SELECT TOP ?`, then 20.9's search columns, then `FROM Ens.MessageHeader WHERE SessionId = ? ORDER BY ID`, bound to `pMax` (or `SQLMAX`) and the session.
    - Each row comes from `MessageRow`, plus `Message` (the criterion) and `Step`. A fault goes to `Mapped(…, "the message's trace failed", …)`.
  - The doc comments state the row shape and the named limit (no event, rule or IO log; no `SuperSession`).
- [ ] **`ui/src/app/core/strings.ts`** (add-only): Design Notes › Strings, before any descriptor or component names them.
- [ ] **`src/OcuPilot/Screen/Descriptor/InteropMessageTraceTab.cls`** (new). It is shaped like 20.9's tabs, and its doc comment names AD-5, AD-29, AD-36, AD-44 and AD-62. The values are in Design Notes › Descriptor. Then run `cd ui && node tools/screen-mirror.mjs`.
- [ ] **`src/OcuPilot/Test/InteropMessageTrace.cls`** (new, unarmed, about 350 lines). It uses the Design Notes › Fixture headers in HSCUSTOM, created per test through 20.9's header fixture with `SessionId` set, and removed with their bodies in `OnAfterOneTest`. Its `Plant(marker)` and `Clear(marker)` class methods are the browser spec's fixture too. Tests:
  - `TestAnyHeaderOpensItsWholeSession`: H1, H3 and H4 each answer H1 to H4 as `Step` 1 to 4, and H5 is absent.
  - `TestTheRowsCarryTheHeaders`: `Type` and `Status` display words, `Error`, `TimeCreated` through `LocalStamp`, `Source`, `Target`, `BodyClass`, `SessionId` and `Message`. `Step` is a JSON number.
  - `TestTheCapTruncates`: `maxRows` 2 through the read route answers `Step` 1 and 2 and `truncated`.
  - `TestAbsentAndMalformedIds`: an unknown id, and a header saved with no session, each answer zero rows. `abc`, `0` and 20 digits are each refused 400 `PORT.VALIDATION` naming `message`. A missing id is 400 `READ.CRITERION`.
  - `TestTheToolAndTheRouteAgree` (AD-36): `interop.messagetrace.read` and the read route answer the same rows.
- [ ] **`src/OcuPilot/Test/InteropMessageDescriptor.cls`** (20.9's): add `TestTheTraceTabJoinsTheMessageGroup`. It checks:
  - the Descriptor table's values and `Registry.Validate` answering `""`;
  - the group in order (document, contents, trace);
  - `NormalizePage("EnsPortal.VisualTrace.zen")` answering `EnsPortal.VisualTrace`;
  - `InteropPort.Pairs("MessageTrace","LIST")` equal to the descriptor's pairs;
  - three prompts.
- [ ] **Rosters**, each row named from the instance:
  - `StageTwoTools` `Elsewhere`: `<screen name="InteropMessageTraceTab"/>`.
  - `SurfaceCoverage`: a `<screen>` row naming `InteropMessageDescriptor`'s new method.
  - `Descriptor.cls` `ReadShapes`: its row.
  - `Navigation.cls`: count +1, at its class-name slot.
  - `ReadTool.cls`: +1 (`interop.messagetrace.read`).
  - `ToolRoundTrip.cls` `REFUSEEMPTY`: `interop.messagetrace.read:READ.CRITERION`.
  - `InteropHostDescriptor` :23 and :169: add `MessageTrace` to both literals.
- [ ] **`src/OcuPilot/Test/InteropFloor.cls`**:
  - `OPERATORSCREENS` gains `InteropMessageTraceTab`, and `OPERATORTOOLS` gains `interop.messagetrace.read`.
  - `TestTheInteroperabilityReadsFollowTheirOwnPairs` gains two legs, on `/screens/interop.messagetrace/read?ns=<ns>&message=1`:
    - `portal` is refused 403, naming `%Ens_MessageHeader:USE`;
    - `operator` reads it (200).
- [ ] **`ui/src/app/areas/interoperability/session-trace.ts`** (new, framework-free). It defines:
  - `traceModel(rows)`: participants in first-appearance order, and arrows in `Step` order with `{id, step, from, to, kind: 'request' | 'response', error, label}`.
  - `traceMermaid(model)`: the Mermaid text by Design Notes › Mermaid.

  The header comment names the harvest: the sibling project iris-execute-mcp-v2's `Diagram/Writer.cls`, MIT.
- [ ] **`ui/src/app/areas/interoperability/session-trace.store.ts`** (new, framework-free): `SessionTraceView`, holding `view()` (`'diagram'` or `'mermaid'`, default `'diagram'`), `setView` and `subscribe`. It is shaped like `SourceViewerState`.
- [ ] **`ui/src/app/areas/interoperability/message-tab-body.ts`** (new): move `InteropMessageContents`' state getters (`loaded`, `fault`, skeleton, empty, empty title and Retry) into an abstract base. 20.9's component and the trace component both extend it. If Task 0 finds them already shared, use that instead.
- [ ] **DW-2434 (ledger inbox, routed by 20.9's code review):** 20.9's `interop-message-contents.ts` repeats `shell/data-table.ts`'s state getters (`boundHere`, `loaded`, `fault`, `showRefusal`, `showSkeleton`, `busy`, `showEmpty`) and its skeleton, refusal and empty markup. When `message-tab-body.ts` takes them, make it the one helper both the body components and `DataTable` use (extend or call it from `data-table.ts`, whose getters keep their names and behavior); if sharing with `DataTable` would couple it to the body inputs, share only between the two bodies and record `Declined DW-2434 for DataTable: <reason>` under Design Notes. Either way the existing data-table and contents specs stay green.
- [ ] **`ui/src/app/areas/interoperability/interop-message-trace.ts`** (new, `app-interop-message-trace`, `OnPush`; inputs `screen`, `store`). It draws:
  - the base's skeleton, fault with Retry, and empty sentence;
  - the view: `applyView(store.data(), read, {filter, sort, direction})`. An empty view of a non-empty read shows `logViewerNoMatches`;
  - `interopTraceCut` (with `store.maxRows()`) when truncated;
  - the view group of 20.9's document viewer: `role="group"` labeled `viewMenuLabel`, with two `aria-pressed` buttons, `interopTraceViewDiagram` and `interopTraceViewMermaid`, reusing `.ocu-source-views` and `.ocu-source-view`;
  - in Diagram view, inside a scroll region, an `<svg role="group" [attr.aria-label]="interopTraceDiagramLabel">` holding the participant heads (a name past 24 characters is cut with an ellipsis, written `'\u2026'` in code (Rule 14); the whole name is in its `<title>`), the lifelines, and one `<a>` per arrow. Each `<a>` has `[attr.href]`, an `aria-label` from `interopTraceArrow`, and a hit area at least 24 px tall, and it wraps the row's `ID`, the line, its head and the label;
  - in Mermaid view, `<app-code-block>` with one text step.

  Each block carries `data-ocu-trace` (`skeleton`, `fault`, `empty`, `nomatch`, `cut`, `diagram` or `mermaid`).
- [ ] **`ui/src/app/shell/in-app-link.ts`** (new): `followInAppLink(event, router, url)`, `onLinkClick`'s body. `data-table.ts` `onLinkClick` keeps its `stopPropagation` and calls it, and the trace arrows and the Test dialog's link use it.
- [ ] **`ui/src/app/areas/interoperability/interop-message-trace.page.ts`** (new): 20.9's Contents page shape, with `<app-detail-page [body]="trace" />`.
- [ ] **`ui/src/app/shell/screen-outlet.ts`** (add-only): an `INTEROP_MESSAGE_TRACE_PAGE` loader and its `DESCRIPTOR_PAGES` row.
- [ ] **`ui/src/app/areas/interoperability/interop-item-test-dialog.ts`**: under the status line, when `answer.sessionId` matches `^[1-9][0-9]{0,18}$`, add `<a data-interop-test-trace [href]>`. It carries `interopTestTraceLink` and points to `entityUrl('interoperability/messages/trace', sessionId, '', router.url)`, followed through `followInAppLink`.
- [ ] **`ui/src/styles/_components.scss`** (add-only): `.ocu-trace-*`. It has:
  - a scroll region (`overflow: auto`);
  - lines and heads in `--ocu-on-surface-variant`, lifelines in `--ocu-outline-variant`, and labels in `--ocu-on-surface`;
  - `.ocu-trace-response` with `stroke-dasharray`, and `.ocu-trace-error` in `--ocu-error`;
  - links with `:focus-visible` in `--ocu-focus-ring`.

  It uses tokens only.
- [ ] **Client tests:**
  - `session-trace.spec.ts` (new): the order (source before target), a self call, empty names, arrow kinds by `Type`, and errors. The Mermaid rules: a keyword gets `_`, a collision `_2` then `_3`, a non-ASCII character `_`, an empty id `P` declared as `participant P`, `;` becomes `#59;`, CR, LF and TAB become a space and the ends are trimmed, `(no body)`, `[ERROR]`, and no ` as ` when the label equals the id. Plus the exact text for the Fixture's rows.
  - `interop-message-trace.spec.ts` (new): each state's block; the hrefs, and a plain click navigating while a Ctrl click does not; a `<script>` name drawn as text; the view switch; aria labels.
  - `interop-item-test-dialog.spec.ts`: the link for a digits `sessionId`, its href and its click; no link for `''`.
  - `in-app-link.spec.ts` (new): modifiers and button.
  - `ui/tools/navigation.test.mjs`: the roster gains the route, and the message group's members, in order, are document, contents and trace.
  - `ui/tools/screen-mirror.test.mjs`: `owners` gains the descriptor, sorted.
- [ ] **EXPERIENCE.md** (add-only), then run `cd ui && npm run test:tools`:
  - :159 (the Interoperability entry) gains: "A message's Trace tab draws its session as a sequence diagram, each arrow opening its message, with Mermaid text as the alternative; a host test's answer opens its session's trace (Story 20.30)."
  - :604 gains the Story 20.30 clause, listing Design Notes › Strings.
  - :856 gains: "the message Trace tab (Story 20.30) is a `detail` tab whose rows draw as a sequence diagram, or as Mermaid text; empty is the Header tab's 'no longer exists' sentence, and a session longer than the cap ends with its cut note".
- [ ] **`ui/browser/interop-message-trace.browser-spec.mjs`** (new). `before` refuses `LIVE_CONTAINER` and requires readiness `installed`.
  - It plants the Fixture through `runIris` with `InteropMessageTrace.Plant`. `after` calls `Clear` and asserts that none is left.
  - **Tests**, each with its mutation comment:
    1. AC1;
    2. AC2;
    3. the AC4 structural and SVG legs at 1280 light, 720 light and 1280 dark;
    4. the gone id.
- [ ] **`ui/browser/interop-item-test.browser-spec.mjs`**: a new AC3 test after AC2. It reuses `openTestTab`, `openDialog` and the AC2 send.
- [ ] **`ui/browser/structural-walk.mjs` `SKIP`** (add-only): `interoperability/messages/trace`, because a fresh instance holds no message; `interop-message-trace.browser-spec.mjs` walks it on the session it plants.
- [ ] **Roster sweep (Rule 30).** Search `src/OcuPilot/Test`, `ui/tools`, `ui/browser` and the `ui/src` specs for any assertion on:
  - the interop screen count or order;
  - the message tab group;
  - `InteropPort`'s endpoint list;
  - the read-tool count;
  - `data-table.ts`'s `onLinkClick`;
  - the Test dialog's result block.

  Each changed file joins the `(loop)` set.

**Acceptance Criteria:**

- **AC1 (the visual trace).**
  - **Given** the Fixture's session in HSCUSTOM on `ocupilot-b-ci`.
  - **When** the person opens H1 from Messages, then its Trace tab.
  - **Then:**
    - the route is `interoperability/messages/trace/<H1>`;
    - the heads' `<title>`s read `<m>Svc`, `<m> Proc;1` and `<m>Op`, in that order (each drawn name is cut at 24 characters);
    - four arrows follow in `ID` order, each labeled with its `ID` and body class;
    - arrows 1 and 2 are solid, and 3 and 4 dashed (computed `stroke-dasharray`);
    - arrow 3 carries the error class and `[ERROR]`;
    - H5 is absent;
    - following arrow 2 opens `interoperability/messages/document/<H2>`, whose `ID` row reads H2.
  - **And** `InteropMessageTrace` shows that any header of the session answers the same rows.
- **AC2 (the generated alternative).**
  - **Given** that trace.
  - **When** the person chooses Mermaid text.
  - **Then** the code block's text equals Design Notes › Mermaid's expected text for the Fixture, and its Copy control is present.
  - **And** `session-trace.spec.ts` pins each id and escape rule.
- **AC3 (from the host test; Integration, Rule 1).**
  - **Given** the probe production's echo operation in `USER` (`interop-item-test.browser-spec.mjs`).
  - **When** the person sends a test, and the answer is done, and follows its trace link.
  - **Then:**
    - the route is `interoperability/messages/trace/<sessionId>?ns=USER`;
    - the first arrow's `ID` equals the `sessionId`, and it runs from `EnsLib.Testing.Service` to `EnsLib.Testing.Process`;
    - the first three heads are `EnsLib.Testing.Service`, `EnsLib.Testing.Process` and `OcuPilotProbeEchoOp`.
- **AC4 (declared, gated, rostered, drawn accessibly).**
  - **Given** the descriptor and the tab.
  - **When** the instance validates it, the build regenerates the mirror, and the browser draws it.
  - **Then:**
    - it validates with Design Notes › Descriptor's values;
    - the strip reads Header, Contents and Trace;
    - it is in `Elsewhere`, which reddens alone when the row is removed;
    - it carries three prompts;
    - navigation gains 1 at its slot;
    - `InteropFloor` shows the Operator opening it and its read, and `portal` refused naming `%Ens_MessageHeader:USE`;
    - `TestEveryOpenScreenMatchesItsClassicPage` holds `%Ens_MessageTrace:USE`;
    - `structural` finds no fresh entry at 1280 light, 720 light and 1280 dark;
    - in both themes, every `<a>` in the SVG has a non-empty `aria-label`, is reached by Tab, and has a hit area at least 24 px tall; each label's `fill` equals the panel text's computed color; the error arrow's stroke equals `--ocu-error`'s computed color; and the light and dark values differ.

## Spec Change Log

- 2026-10-14, spec gate (runner): the Rule 20 drafts are written (AD-62 item 16, AD-8, AD-44). The fixture leak the plan measured in Story 20.6's browser spec is DW-2408, routed to the burn-down.
- 2026-10-14, lead (Rule 17 (1b)): DW-2434 routed here by 20.9's code review; added as a Tasks item beside `message-tab-body.ts`.

## Review Triage Log

## Design Notes

**Governing ADs.**

- **AD-62**: items 1 (no `%Api.InteropEditors`), 2 (gate first), 3 (switched; no `OcuPilot.*` while switched), 8 (ids kept exactly), 12 (no compile-time interoperability) and 15 (20.9's reads). Item 16 is drafted below.
- **AD-29**: the port's own gate, `%ExecDirectNoPriv` after it, and no nested `TOP`.
- **AD-8** and **AD-64**: every pair is required; the tab is adjustable; the port's pairs are not.
- **AD-44**: the classic page is `EnsPortal.VisualTrace`.
- **AD-5**: one descriptor in a parent-scoped tab group; a page through one loader line; the `body` input (20.9's clause).
- **AD-36** and **AD-37**: one capped read for screen and tool; a gone message reads as zero rows.
- **AD-21** and **AD-13**: values are bound; an id is one segment.
- **AD-11** and **AD-47**: data reaches the SVG and the Mermaid text only as bound values and interpolated text; there is no runtime evaluation. **AD-60**: the read tool's rows go through the sanitizer.
- **AD-19** and **AD-24**: the framework-free state and the declared context.

Checked and not engaged: AD-14, AD-15, AD-22, AD-51 and AD-53 (no write); AD-63 (no embed); AD-43 (manual refresh).

**Measured at this plan on `ocupilot-b-ci`** (2026-10-13, image 2026.2). Every probe row was removed, and the removal was verified: zero headers and zero `Ens_Util.Log` rows in USER and HSCUSTOM, with the production stopped.

- **`NewRequestMessage` and `NewResponseMessage`.** In HSCUSTOM, a new request's `SessionId` read its own `ID`, and `NewResponseMessage` kept the session and swapped source and target.
  - Through `%ExecDirectNoPriv`, `SELECT SessionId … WHERE ID = ?`, then `SELECT TOP ? ID, TimeCreated, %EXTERNAL(Type), %EXTERNAL(Status), … WHERE SessionId = ? ORDER BY ID`, answered `Request`/`Completed` and `Response`/`Error` in ID order.
  - An unknown id answered no row.
- **A host test's session id is its first header's `ID`.** This settles the charter's inference.
  - With the probe production in USER (`ProductionProbe` plus `InteropTestFixture`), `EnsLib.Testing.Service.SendTestRequest(…, .sid, 1)` answered session 2.
  - Its headers, in ID order, were:
    1. 2 Request `EnsLib.Testing.Service`→`EnsLib.Testing.Process`;
    2. 3 Request →`OcuPilotProbeEchoOp`;
    3. 4 Response;
    4. 5 Response →`EnsLib.Testing.Service`.
  - All four were `Queue`.
- **An observation for the lead (not this story's).** `ProductionProbe.Settle`, followed by both `Remove`s, left three headers in USER, which this plan then deleted: the start-up `Ens.ScheduleService` header, and each session's last `EnsLib.Testing.Process`→`EnsLib.Testing.Service` response. It also left the production's `Ens_Util.Log` rows. `interop-item-test.browser-spec.mjs`'s `after` uses the same calls (a hermeticity candidate for the ledger).
- **The vendor** (read): Visual Trace takes a message or session id, orders by `%ID`, and adds the event, rule and IO logs uncapped. It never follows `SuperSession`.

**Decisions:**

- **Mermaid is built in the browser** from the rows the diagram draws: the same filter, cap and labels, with no second read and no new endpoint. The sibling's rules are about 30 lines, ported to TypeScript.
  - *Rejected:* building it on the server. It needs a non-row answer outside AD-36's read shape, or a second endpoint.
- **`Step` is the sort key.** `ApplyView` compares strings by code unit, so an `ID` string would sort `10` before `9`. `ID` stays an exact string (AD-13), as 20.9's `Position` and `Line` are JSON numbers.
- **Arrows follow `Type`.** A `Response` is dashed and anything else solid, as the charter says. Writer's arrows follow `Invocation` through its `Correlator`, which is excluded.
- **The labels are Writer's:** the body class, or "(no body)", then " [ERROR]". The SVG adds the row's `ID` in the left gutter and in the link's accessible name.
- **The read's note** states the named limit to the person and the agent (AD-36 `read.note`).
- **Links** use `entityUrl` and a shared `followInAppLink`, the table's own behavior. The target screen gates itself, as a table's row link does.
- **No attribution row.** The sibling is the owner's own work (`Copyright (c) 2026 jbrandtmse`), as every earlier harvest from the four sibling projects is (`ATTRIBUTIONS.md`:77-79). The ported module's header names its source, as `ATTRIBUTIONS.md` asks of a port.

**Mermaid (Writer's rules, as ported).**

- **Id.**
  - Each character outside `[A-Za-z0-9_.]` becomes `_`, by UTF-16 code unit. An empty id becomes `P`.
  - An id equal, in any letter case, to one of Writer :209's 27 keywords gets a trailing `_`.
  - A taken id gets `_2`, then `_3`, and so on, in registration order. The same name always has the same id.
- **Text.** CR, LF and TAB become a space, then both ends are trimmed of whitespace, then `;` becomes `#59;`. Nothing else is escaped.
- **Lines.**
  - `participant <id>` when the escaped name equals the id or is empty; otherwise `participant <id> as <escaped name>`.
  - Then `<from><arrow><to>: <label>`.
  - The lines are joined by `\n`, with no trailing newline.
- **Expected for the Fixture.** `<m>` is the marker plus its token, all `[A-Za-z0-9]`:

  ```text
  sequenceDiagram
  participant <m>Svc
  participant <m>_Proc_1 as <m> Proc#59;1
  participant <m>Op
  <m>Svc->><m>_Proc_1: Ens.StringRequest
  <m>_Proc_1->><m>Op: (no body)
  <m>Op-->><m>_Proc_1: (no body) [ERROR]
  <m>_Proc_1-->><m>Svc: Ens.StringResponse
  ```

**Fixture.** The marker is `OcuPilotProbe2030` plus a run token. In HSCUSTOM, in this order, all `TimeCreated` within the last hour, saved through 20.9's header fixture:

- **H1:** a Request, `<m>Svc` → `<m> Proc;1`, body `Ens.StringRequest`, Completed, its session equal to its own id.
- **H2:** a Request, `<m> Proc;1` → `<m>Op`, no body, Completed, in H1's session.
- **H3:** a Response, `<m>Op` → `<m> Proc;1`, no body, Error, `IsError` 1 with an `ErrorStatus`, in H1's session.
- **H4:** a Response, `<m> Proc;1` → `<m>Svc`, body `Ens.StringResponse`, Completed, in H1's session.
- **H5:** a Request, `<m>Svc` → `<m>Op`, in its own session.

**Descriptor (`InteropMessageTraceTab`).**

| Key | Value |
|---|---|
| `route`, `labelKey` | `interoperability/messages/trace`, `interopMessageTraceLabel` |
| `area`, `archetype`, `sideBarPosition` | `interoperability`, `detail`, 0 |
| `built`, `refreshes`, `refreshRates` | true, false, `[]` |
| `privileges` | `%Ens_Portal:USE`, `%Ens_MessageHeader:USE`, `%Ens_MessageTrace:USE` |
| `ownPrivileges` | `%Ens_MessageHeader:USE`, `%Ens_MessageTrace:USE` |
| `entityType`, `scope`, `id` | `interop-message`, `namespace`, single |
| `parentScope` | `interoperability/messages` |
| read | `interop/MessageTrace/LIST`; criterion `message` (`text`, `maxLength` 19, label `interopColumnId`, hint "One message, as interop.messages.read answers its ID; the trace is that message's whole session."); `note` `interopMessageTraceNote` |
| fields | `Message, Step, ID, TimeCreated, Type, Status, Source, Target, BodyClass, Error, SessionId` |
| filter, sort | `Type, Status, Source, Target, BodyClass`; `{fields: [Step], default: Step, direction: asc}`; paging `cap` |
| table | ID (`name`, `interopColumnId`), TimeCreated (`journalColumnCreated`), Type (`tableColumnType`), Status (`status`, `taskHistoryColumnStatus`), Source (`auditEventFieldSource`), Target (`agentLedgerColumnTarget`), BodyClass (`identifier`, `interopColumnBodyClass`); `emptyNextKey` `tableReadOnlyEmptyNext` |
| `tab` | group `interoperability/messages/document`, position 3, `interopMessageTabTrace` |
| `emptyStateKey` | `interopMessageHeaderEmpty` (20.9's) |
| context | `Step, ID, TimeCreated, Type, Status, Source, Target, BodyClass, Error` |
| prompts | `promptGroupTroubleshooting` ×3, below |
| `classicPage`, `toolIdentifier` | `EnsPortal.VisualTrace`, `interop.messagetrace` |

The table is declared because a read declares one (`TableProblem`). The `body` draws in its place.

**Strings (15 new literals, add-only; values checked unique at plan):**

- `interopMessageTraceLabel` "Session trace"
- `interopMessageTabTrace` "Trace"
- `interopMessageTraceNote` "OcuPilot draws this session's messages. The classic Visual Trace also shows its event, rule and I/O log entries."
- `interopTraceDiagramLabel` "Sequence diagram of this session"
- `interopTraceViewDiagram` "Diagram"
- `interopTraceViewMermaid` "Mermaid text"
- `interopTraceArrow` "Message <id>: <type> from <source> to <target>, <status>"
- `interopTraceNoBody` "(no body)"
- `interopTraceErrorMark` "[ERROR]"
- `interopTraceNoName` "(no name)"
- `interopTraceCut` "OcuPilot draws the first <n> messages of this session."
- `interopTestTraceLink` "Open this session's trace"
- Prompts:
  - `interopMessageTracePrompt1` "What happened in this session, step by step?"
  - `interopMessageTracePrompt2` "Which host in this session reported the error?"
  - `interopMessageTracePrompt3` "How long did this session take from its first message to its last?"

**Reused keys:**

- the table and criterion labels above;
- `interopMessageHeaderEmpty` (20.9);
- `viewMenuLabel`, `logViewerNoMatches`, `connectivityRequestRefused`, `actionRetry` and `privilegeRequiresResource`.

**Spine drafts (Rule 20; the lead writes them at the gate):**

- **AD-62, item 16:** "The session trace (Story 20.30). `InteropPort` gains `MessageTrace` (`LIST`, criterion `message`, a header `ID`).
  - **Reading.** Two top-level statements read the header's `SessionId`, then that session's headers in `ID` order, capped, with `%ExecDirectNoPriv` after the gate. A header no row holds, or one with no session, reads as zero rows.
  - **Pairs.** `%Ens_MessageHeader:USE` and `%Ens_MessageTrace:USE` (`EnsPortal.VisualTrace`'s `RESOURCE`).
  - **Drawing.** OcuPilot draws the trace itself, as template-bound SVG, and builds its Mermaid text in the browser from the same rows.
  - **Not read.** The event, rule and IO logs and `SuperSession` are not read (named limit; the read's note)."
- **AD-8, a Story 20.30 clause:** "The trace also requires `%Ens_MessageTrace:USE`, which `%EnsRole_Operator` holds."
- **AD-44, a Story 20.30 clause:** "The Trace tab declares `EnsPortal.VisualTrace` (`NormalizePage`, measured by 20.9)."
- **EXPERIENCE.md:** :159, :604 and :856, as Tasks says.

**Integration, Consumes, Consumed-by (Rules 1 and 2):**

- **Integration:** AC3. The consumer is 20.6's Test dialog: its answer's link opens this story's trace of a real session.
- **Consumes:**
  - from 20.9: the message tab group, the `body` input, `MESSAGEPAIRS`, the id check, `MessageRow`, its header fixture and `interopMessageHeaderEmpty`;
  - from 20.4: `SqlRows`, `LocalStamp` and `interop-message`;
  - from 20.6: the answer's `sessionId`, the Test dialog and the probe fixture.
- **Consumed-by:**
  - 20.12, whose Investigate cites a session's rows through `interop.messagetrace.read`;
  - 20.31, whose resend keeps the session, so a resent message appears in its trace.

**Rule 31 (extend, don't copy):**

- `ListMessageTrace` shares `SqlRows`, `LocalStamp`, `MessageRow`, 20.9's id check and its `InvokeRuntime` branch. Only its two statements are new.
- The trace body extends the base extracted from 20.9's Contents component.
- `SessionTraceView` copies `SourceViewerState`'s shape (about 20 lines), because that class carries the source viewer's own view keys and document rules.
- The trace page is a copy of 20.9's Contents page shape (about 10 lines). One page per body is the loader-map pattern, and a generic page keyed by descriptor would read worse.
- `followInAppLink` is extracted from `data-table.ts` and shared by three callers.
- The tests reuse 20.9's header fixture, `runIris`, `list-spec.mjs`, `panel-spec.mjs`, the per-spec `structural` helper and InteropFloor's principals.
- `InteropMessageTrace` is a new class, because 20.9's `InteropMessageRead` is planned at about 400 lines.

**Contended files (Rule 11).** `origin/OCU-1-epic18` (`5fa674b7`) carries no unmerged change to any file below (merge base `6c24da93`). This story's edits to them are add-only:

- `Test/StageTwoTools.cls`, `Test/SurfaceCoverage.cls`, `Test/Descriptor.cls`, `Test/ReadTool.cls`, `Test/ToolRoundTrip.cls`;
- `screens.generated.ts` (regenerated), `strings.ts`, `screen-outlet.ts`;
- EXPERIENCE.md, the side-bar specs and the spine.

There is no Rule 11 ask. `data-table.ts` (`onLinkClick`'s body moves) and `_components.scss` are outside the contended list.

**Footprint extension:** `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` (add-only, as 20.9's).

**Named limits:**

- The trace draws the session's first `maxRows` headers by `ID` (1,000 by default). A later header is not drawn, and the cut note says so.
- Event, rule and IO log entries and super-sessions stay in the classic Visual Trace (the read's note).
- A header saved with no `SessionId` reads as zero rows. The vendor always sets one.
- No stock role holds `%Ens_MessageHeader:USE` without `%Ens_MessageTrace:USE`. So the trace pair's refusal is pinned by declaration (descriptor equals port pairs) and by the classic-page parity test, not by a principal.
- A long participant name is cut in its head. Its `<title>` and the link names carry it whole.

**Ledger inbox (Rule 17):** none (`slice` is empty).

## Verification

**Shared surfaces:**

- the Interoperability navigation roster (`Navigation.cls`, `navigation.test.mjs`);
- the message tab group (+1 member);
- `StageTwoTools`' `Elsewhere`, `SurfaceCoverage`'s screen rows, `Descriptor`'s `ReadShapes` and `InteropFloor`'s rosters;
- the `ReadTool` and `ToolRoundTrip` rosters;
- `InteropHostDescriptor`'s endpoint literals;
- `screen-mirror.test.mjs`'s `owners`;
- `data-table.ts`'s link click;
- the Test dialog's result block;
- the structural walk's `SKIP`;
- the strings table and EXPERIENCE.md :159, :604 and :856;
- the built-screen count that Screen permissions derives (+1).

*Every test added or changed passes on a fresh environment, in either order.* Every message a test reads is one it created, found by its marker, and removed after. No test asserts on a header store being empty.

**Setup (slot B; never the dev instance `ocupilot-slot-b`):**

- **Load `src`:**
  1. Run `rsync -a --checksum --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-20/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`.
  2. In `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`, run `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)`.
- **Before any browser run:** `cd ui && npm run build && docker exec ocupilot-b-ci sh -c 'cd /durable/iris/csp/ocupilot && rm -rf ./*' && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`.

**Commands.** Run each in the foreground with `timeout: 600000`, one at a time. Read each class's result from `%UnitTest_Result`.

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.InteropMessageTrace --class OcuPilot.Test.InteropMessageDescriptor --class OcuPilot.Test.InteropMessageRead`. Expected: green.
- `(loop)` The same runner with `OcuPilot.Test.InteropFloor`, `StageTwoTools`, `SurfaceCoverage`, `Descriptor`, `Navigation`, `ReadTool`, `ToolRoundTrip`, `InteropHostDescriptor`, `CompileWithoutInterop`, `InteropFloorOwnPairs`, `ScreenAccessWire`, `ToolNavigate` and every class the sweep changes, in batches of about 8 minutes by `ci-timings.json`. Expected: green.
- `(loop)` `cd ui && npm run test:tools`, then `cd ui && npm run test:components`. Expected: green.
- `(loop)` `cd ui && npm run build -- --verbose`. Expected: the prebuild chain is green, the trace chunk is under 88 kB, and the initial total is under 1992kB. Record both.
- `(loop)` `uv run scripts/check-objectscript.py <each changed .cls>` and `bash scripts/lint-docs.sh`. Expected: clean.
- `(loop)` `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/<file>`, one file per call, after the redeploy. Expected: green.
  - `interop-message-trace.browser-spec.mjs`
  - `interop-item-test.browser-spec.mjs`
  - `interop-messages.browser-spec.mjs` (20.9's; the strip changed)
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
| AC1 | `TRACESQL` reads `WHERE ID = ?` in place of the session | `InteropMessageTrace` `TestAnyHeaderOpensItsWholeSession`, and browser AC1 |
| AC1 | `TRACESQL` orders `ID DESC` | The `Step` order leg, and browser AC1's arrow order |
| AC1 | `Step` is set as a string | `TestTheRowsCarryTheHeaders`' number leg |
| AC1 | `traceModel` registers the target before the source | `session-trace.spec.ts`'s order test, and browser AC1's heads |
| AC1 | The body ignores `kind` (every arrow solid) | `interop-message-trace.spec.ts`, and browser AC1's dashed leg |
| AC1 | The arrow link targets `messages/trace` | The component spec's href test, and browser AC1's follow leg |
| AC2 | The `;` escape is dropped | `session-trace.spec.ts`, and browser AC2 |
| AC2 | The keyword suffix is dropped | `session-trace.spec.ts`'s keyword test, alone |
| AC3 | The dialog link uses `responseClass` in place of `sessionId` | The dialog spec, and `interop-item-test` AC3 |
| AC4 | `%Ens_MessageTrace:USE` is dropped from the descriptor and from `Pairs` | `InteropFloor` `TestEveryOpenScreenMatchesItsClassicPage`, and `InteropMessageDescriptor` |
| AC4 | The `Elsewhere` row is removed | `StageTwoTools` `TestTheRosterAndElsewhereAreEveryRegisteredScreen`, alone |
| AC4 | `.ocu-trace-error` loses `--ocu-error` | The browser spec's token leg |
| Matrix | `ListMessageTrace` binds `SQLMAX` in place of `pMax` | `TestTheCapTruncates` |

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Planned against Story 20.9's spec, with Task 0 re-anchoring on 20.9 as built. The charter's inference (a session id is its first header's `ID`) was measured at this plan. The Rule 20 drafts are in Design Notes.
