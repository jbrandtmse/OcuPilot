---
title: 'Story 20.7: The three embedded vendor editors'
type: 'feature'
created: '2026-10-12'
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

**Problem:** Business rules, Business processes and Data transformations list their classes, but nothing opens one. To change a rule, a BPL or a DTL, a person still leaves for the classic portal. Story 20.13 built the signed-in frame (AD-63), but no screen draws it. It also left three behaviors to the screens:

- the frame's first run in a real browser (DW-2347);
- what a document switch does (DW-2350);
- what shows when the editor moves away by itself (DW-2351).

**Approach:** Add three unlisted editor screens at `<list route>/document/<name>.cls`, each opened from its list's name cell.

- Each screen issues its list's own declared read. It draws `app-interop-editor-frame` only for a row that read answers, and for a process or transformation only when the row is not marked `Coded`. The frame holds InterSystems' rule, BPL or DTL editor, loaded from the instance and signed in through 20.13's hand-off.
- OcuPilot never navigates a drawn frame. A new document, a namespace move or Refresh draws a new frame.
- Measured at this plan, the editors' saved, compiled and invalid notices stay inside the frame. The messages criterion is re-scoped to that (Design Notes › Rule 5 draft).

## Boundaries & Constraints

**Always:**

- **AD-63's five limits hold unchanged, as 20.13 keeps them:**
  1. The frame's only source is `interopEditorSource`.
  2. Normal mode.
  3. Nothing in the frame is read, posted to or listened to.
  4. Sign-out ends the editor's sign-in.
  5. No sandbox.
- **Values the frame gets:**
  - `editor`: fixed per descriptor (`rule-editor`, `bpl-editor`, `dtl-editor`).
  - `namespace`: the namespace the page's read was issued in. It is drawn only while it equals `ScopeService.namespace()`.
  - `document`: the answered row's `Name` with its `.cls` removed, never the route text.
- **One frame per source and revision.** `app-interop-editor-frame` draws a new `<iframe>` element whenever its source or its new `revision` input changes. It never sets `src` again on a frame it has drawn. `src` is still set once, with `Renderer2`.
- **One request.** The page's only request is the list's declared read: `screenReadPath(list, 1000)` through `ApiService.requestJson`, with `scope` pinned to the namespace at the call. The list's own gate applies to it (AD-5). The page makes no other call, and the frame component makes none (AD-20).
- **`Coded` on the port.** `InteropPort.ListClasses` answers a boolean `Coded` on every Processes and Transforms row.
  - It is true when the class does not descend from `Ens.BusinessProcessBPL` (for a transformation, `Ens.DataTransformDTL`) according to `%Dictionary.ClassDefinition:SubclassOf`. That is the dictionary, so it holds whether the class is compiled or not, matching the classic `IsBPL` and `IsDTL`.
  - It is read while switched (AD-16), and nothing is written.
  - Rules rows stay `{Name, Modified}`.
- **Descriptors** follow the shape below. Strings go in `strings.ts` and EXPERIENCE.md's Fixed strings. Contended files take add-only edits (Design Notes › Contended files).

**Never:**

- Any query parameter beyond `$NAMESPACE` and the editor's document parameter: no `VSCODE`, `NEW` or `READONLY`.
- An editor drawn with no document.
- Any read, write, post or listener on the frame, or on vendor storage keys. `api.test.mjs`'s bans stay as they are.
- Any change to the content-security policy, `StaticHandler`, `index.html`, its nonce, any header, the token store, `Session` or CORS.
- A call to `%Api.InteropEditors` by OcuPilot (AD-62 (1)).
- A vendor file copied into the repository, the bundle or the package.
- A leave guard or confirmation dialog on these screens (Design Notes › DW-2350).
- A new write tool, governance key, entity type, read tool or area.
- Edits to any of: `Screen/Registry.cls`, `Screen/Read.cls`, `Kernel/Proposal/Prohibited.cls`, `app.routes.ts`, `angular.json`, `.github/workflows/ci.yml`, `ui/tools/ci-shards.mjs`, `ui/tools/ci-timings.json`, `ui/tools/ci.test.mjs`.
- Edits to the three lists' table columns, row actions, prompts or empty states. Story 20.27 owns Data transformations' Test action.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Rule | A Business rules row `P.Rule.cls` in HSCUSTOM, opened from its name cell | Route `interoperability/rules/document/P.Rule.cls`. The page reads `interop.rules`. One frame, src `/ui/interop/rule-editor/index.html?$NAMESPACE=HSCUSTOM&rule=P.Rule`. The editor's empty-body login answers 200, and its `GET /api/interop-editors/v7/HSCUSTOM/rules/P.Rule` answers 200 | - |
| BPL, DTL | A row with `Coded` false | The same, with `bpl-editor`/`&BP=` or `dtl-editor`/`&DTL=` | - |
| Coded | `Coded` true (`EnsLib.HL7.MsgRouter.RoutingEngine.cls`, `EnsLib.ITK.AdapterKit.Transform.PHDEToXMLDETransform.cls`) | No frame, and no request under `/ui/interop/` or `/api/interop-editors/`. The screen shows its coded sentence | The vendor's read of either answers 400 (measured) |
| Gone | An id the read does not answer: deleted, never created, another namespace, or beyond the 1,000-row cap | No frame, and no editor request. The descriptor's empty sentence | - |
| Refused | The list's verdict is denied, or its read answers 403 with `failedPair` | No frame. "Requires <pair>" | - |
| Fault | Any other non-ok answer | No frame. "request refused" with Retry | Retry reads again |
| Save | The person saves in the DTL editor | Inside the frame: "<class> saved." No message to the shell or the frame. The list's Modified moves at its next fetch | - |
| Compile | The person compiles | The editor's own notice ("<class> compiled successfully"; the rule editor's Compile saves too: "Rule saved and compiled."). No message | A class that does not compile: the editor's notice carries the compiler's text. No message |
| Document switch | The route id changes on the drawn screen (a typed URL, or the agent's navigation) | A new frame element with the new source, and the old element removed. Its unsaved changes are dropped, and the editor's alert does not show | A late answer for the old id is ignored |
| Namespace move | The scope moves to another namespace | The frame goes at once. The read runs again there: a new frame if the row is found, otherwise gone | - |
| Refresh | The person chooses Refresh, for example after the editor's own Back to standard UI | The read runs again, and a new frame is drawn at the screen's own source | - |
| Sign-out | Sign out from the account menu | No frame and no editor key. The editor's login, access token and refresh token each answer 401 | - |

</intent-contract>

## Code Map

All paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-20`. Line numbers were read at `69d3f7d6`. Story 20.27 lands first and edits `InteropPort.cls`, `InteropTransformList.cls`, `screen-outlet.ts`, `strings.ts` and EXPERIENCE.md, so anchor those files by symbol.

### Built by 20.13 (consume; DW-2350 changes the frame)

- **`ui/src/app/core/vendor-frame.ts`** (68 lines).
  - `CLASS_NAME` :25 and `NAMESPACE_NAME` :28.
  - `INTEROP_EDITORS` :43-47.
  - `interopEditorSource` :61-68, which answers `null` for a refused shape.
- **`ui/src/app/areas/interoperability/interop-editor-frame.ts`** (135 lines).
  - Template :67-74, drawn only when `drawn` is true.
  - `source` :95-99 draws only while the namespace is the scope's.
  - `syncSource` :124-134 sets `src` with `Renderer2` once per element and address. Today it sets it again on the same element when the source changes.
  - The doc comment :19-50 ends with "A source set again ... is the consumer's to arrange".
  - Host-filling styles :54-66.
- **`interop-editor-frame.spec.ts`** (275 lines).
  - :149 pins today's set-again-on-the-same-frame behavior. It changes.
  - :165 is once per address, :203 is listeners, :255 is storage.
- **`ui/tools/vendor-frame.test.mjs`**:
  - :164-175: the text `/ui/interop` may appear only in `core/vendor-frame.ts`.
  - :206-223: exactly one `renderer.setAttribute(frame, 'src', source)` in the component, and no `[src]` binding or sanitizer bypass.
- **`ui/tools/api.test.mjs`**:706-727 `FORBIDDEN`. It scans all of `ui/src`, specs included.
- **`ui/browser/interop-editor-spec.mjs`** (386 lines):
  - `EDITOR_APPS` :46-50 and `DEFAULT_FRAME_SELECTOR` `'app-screen-outlet iframe'` :53.
  - `until` :61.
  - `watchEditorTraffic`, `watchPolicyViolations` and `armMessageCounters`.
  - `assertSignedInSilently({..., frameSelector, documentStatus})` :207.
  - `editorSessionControls`, `signOutThroughMenu` and `assertSignOutEndsEditors`.
- **`ui/browser/interop-editor-frame.browser-spec.mjs`**: 20.13's harness spec. It stays, re-run unchanged.

### Screens, routes and pairing (client)

- **Name-cell chain**, `shell/data-table.ts`:646-664: `rowTargetScreen ?? … ?? documentScreenFor(list) ?? …`. The link is `${route}/${encodeEntityId(name)}` (:679).
- **`core/navigation.ts`**:
  - `DOCUMENT_ROUTE_SUFFIX` :296, `documentScreenFor` :302-306 (built, unlisted, id-keyed) and `listForDocumentScreen` :309-314.
  - `ownIdSegment(screen, url)` :459, `formatRequires` :687, `screenForUrl` :807.
- **Today, the code lists' name cells link to the list's own id route** (`parentScope ""`) and only reselect the row. A screen at `<list>/document` takes the link over with no edit to the list.
- **The locator links a `/document` screen back to its list** (`shell/locator-bar.ts`:357).
- **Routes are generated** (`app.routes.ts`:82-111). An id-keyed screen gets `<route>/:id`. No hand edit.
- **Page reuse.** `provideRouter` has no reuse strategy (`src/main.ts`:270), so an id change keeps the page. Follow the id on `NavigationEnd`, as `areas/system-explorer/source-editor.page.ts`:151-158 does.
- **`shell/screen-outlet.ts`**:
  - A shared loader constant (`SERVICE_EDITOR_PAGE` :71) is named by several entries (:127, :129).
  - `DESCRIPTOR_PAGES` :90-221, interop rows :212-220.
  - `ARCHETYPE_PAGES['viewer (source)']` is the class viewer. A `DESCRIPTOR_PAGES` entry overrides it per descriptor.
- **Reading another screen's read:**
  - `core/screen-read.ts` `screenReadPath` :177-193.
  - `core/api.ts`:70-74: a per-call `scope`.
  - `areas/os-management/database-details.page.ts`:478-507: verdict first, then a 403's `detail.failedPair`, otherwise a fault.
  - `areas/system-explorer/source-editor.store.ts`:303-311: the scoped `requestJson` wrapper and a generation guard.
- **Sibling pages:**
  - `source-editor.page.ts` (309 lines): `screenForUrl` :137, `ownIdSegment` :294-298, a gone note and a refusal banner.
  - `document-viewer.page.ts`: its fault strip :162-166 is `connectivityRequestRefused` with `actionRetry`.
  - Skeleton bars: `process-details.page.ts`:88-89 (`ocu-skeleton-bar`).
- **Height chain:** `styles/_components.scss`:723-755 (`.ocu-screen-outlet` is a flex column) and :6054-6060, which explains why a page host must be a column flex item that fills the outlet.
- **Strings:**
  - Labels reuse `interopRuleEditorTitle`, `interopBplEditorTitle` and `interopDtlEditorTitle` (`strings.ts`:7070-7074).
  - Also reused: `actionRefresh` :137, `actionRetry` :133, `connectivityRequestRefused` :81, `privilegeRequiresResource` :273.
  - The list keys are at :6416-6458.
- **Bundle:** `ui/tools/build-output.test.mjs` `LAZYCHUNKMAX` 88,000 (:267), loader shape :300-316, page selectors lazy :324-363. `angular.json`:51-57 `maximumWarning` 1992kB.

### Port and descriptors (server)

- **`src/OcuPilot/Port/InteropPort.cls` `ListClasses`** :995-1049, at `69d3f7d6`.
  - It walks `%Dictionary.ClassDefinition:SubclassOf` for `Ens.BusinessProcess`, `Ens.DataTransform` or `Ens.Rule.Definition`, less `Ens.BusinessProcessBPL` and `Ens.DataTransformDTL`, switched.
  - Rows are `{Name: <class>.cls, Modified}`, and `Modified` is the definition's `TimeChanged`.
  - The route projects rows to `read.fields` (`Screen/Read.cls`:754, :1428), so `Coded` must also be declared.
- **`src/OcuPilot/Screen/Descriptor/InteropRuleList.cls`**, **`InteropProcessList.cls`** and **`InteropTransformList.cls`**:
  - Doc comment :7-9: "declares no action: editing … stays on the classic page".
  - `read.fields` `["Name","Modified"]` :49.
  - 20.27 adds `rowActions`/`emptyAgentKey` on Transforms.
- **Templates:**
  - `ExplorerClassDocument.cls`: `viewer (source)` at `…/classes/document`.
  - `ExplorerClassEditor.cls`: no read, `context` `[]`, three reused prompts, `toolIdentifier` `explorer.classeditor`.
- **`Screen/Archetype.cls`**:65-81. `viewer (source)` is link-out `none`.

### Tests and rosters (read at `69d3f7d6`)

- **`Test/InteropDescriptor.cls`** (433 lines). `TestTheCodeListsReadThroughThePort` :248-282 reads the three endpoints in HSCUSTOM. It is armed (`scripts/ci-throwaway.sh`:433) and stays armed.
- **`Test/StageTwoTools.cls`**:
  - `Elsewhere` rows :116-248, interop rows :169-187.
  - New rows go before `InteropProcessList` :182, `InteropRuleList` :186 and `InteropTransformList` :187.
  - The load-bearing test is `TestTheRosterAndElsewhereAreEveryRegisteredScreen` :393.
- **`Test/SurfaceCoverage.cls`**: interop screen rows :226-245. The sets are derived (:618-631), so no count literal changes.
- **`Test/Navigation.cls`**:534-537: interop `screens.%Size()` 19 and its order. Position-0 screens sort first, by class name.
- **`Test/InteropFloor.cls`**:62 `ADMINISTRATORSCREENS`. `TestEveryOpenScreenMatchesItsClassicPage` :310-352 needs the classic page's `RESOURCE` to share a member with the screen. `EnsPortal.RuleEditor`, `BPLEditor` and `DTLEditor` each list `%Ens_Code:READ` (`irislib/EnsPortal/{RuleEditor:13,BPLEditor:16,DTLEditor:14}.cls`).
- **Unchanged, checked:**
  - `Test/Descriptor.cls` `ReadShapes` :194-196 pins filter, sort and column kinds, not fields.
  - `InteropDescriptor` `SCREENS` :41 and its four-screen test :139.
  - `InteropFloorOwnPairs`, `ReadTool`, `ToolNavigate`, `ScreenAccessWire` and the `EntityType` count are each derived or unaffected.
- **Client rosters:**
  - `ui/tools/navigation.test.mjs`:365-390 is the ordered built-route roster. :757-775 is 20.4's pairing test, the precedent for a `documentScreenFor` assertion.
  - `ui/tools/screen-mirror.test.mjs`:2448-2496 is the `ownPrivileges` owners list.
- **Browser:**
  - `ui/browser/structural-walk.mjs`: `SOURCE_VIEWER_IDS` :88-91 and `SKIP` :97-122. `needsId` :204 is true for `viewer (source)`.
  - `interop-item-test.browser-spec.mjs`:60-88 is the per-spec `structural` helper (DW-1337 at 1280 light, 720 light and 1280 dark).
  - `list-spec.mjs`: `ROW_SELECTOR` :28, `waitForRows` :37, `clickRowCentre(page, {text, link: true})` :182.
  - `panel-spec.mjs`: `signedInAt` and `openFromSideBar`.
  - `turnprobe-spec.mjs`:53 `runIris`.
  - Story 20.27's `interop-transform-test.browser-spec.mjs` shows the probe create and remove pattern.

### Vendor (read only)

- In each bundle (`irisui/ui/interop/{rule,dtl,bpl}-editor/main.*.js`), every `window.parent.postMessage({direction:"vscode", type: saved|compiled|changed|badrule|baddtl|badbpl|userAction|compatible}, "*")` is gated on `vscodeMode`.
- In normal mode the editors show snackbars instead: `SAVED`, `SAVED_AND_COMPILED`, `COMPILE_SUCCESS`, `COMPILE_FAIL` with the error summary, `SAVE_FAIL`. BPL shows a compile failure in a dialog.
- The classic lists link only BPL and DTL classes: `EnsPortal/BusinessProcesses.cls`:82-96 and :300, and `EnsPortal/DataTransformations.cls`:103 and :163-175. Any other row gets "you must edit it in Studio".
- `EnsPortal/Rules.cls`:222 opens a new rule with `&NEW=1`, a parameter outside AD-63's vocabulary.

## Tasks & Acceptance

**Execution:**

- [ ] **Task 0 (re-anchor, no code).** After 20.27 has merged into this branch, re-read `ListClasses`, `InteropTransformList.cls`, `screen-outlet.ts`'s interop rows and EXPERIENCE.md :159 and :604, and anchor this story's edits to what is there. Everything else this plan depends on was measured at the plan (Design Notes › Measured).
- [ ] `src/OcuPilot/Port/InteropPort.cls` `ListClasses`, extended in place:
  - While switched, collect into a local set the names `SubclassOf` answers for `Ens.BusinessProcessBPL` (Processes) or `Ens.DataTransformDTL` (Transforms).
  - Answer each row with `Coded` as a boolean, true when the name is not in that set.
  - Rules rows are unchanged.
  - Update the doc comment's row shape. No `Ens.*` type enters a signature (AD-62 item 12).
- [ ] `InteropProcessList.cls` and `InteropTransformList.cls`: add `"Coded"` to `read.fields` after `Modified`. Context, table, sort and filter are unchanged. In all three list descriptors' doc comments, replace the "declares no action: editing … stays on the classic page" sentence with: the name cell opens the class in its editor screen (Story 20.7), and actions stay off the list (except 20.27's Test).
- [ ] New `src/OcuPilot/Screen/Descriptor/InteropRuleEditor.cls`, `InteropProcessEditor.cls` and `InteropTransformEditor.cls`, shaped like `ExplorerClassEditor.cls`, with a doc comment naming AD-63, AD-5 and AD-44.

  | Key | Rule editor | Process editor | Transform editor |
  |---|---|---|---|
  | `route` | `interoperability/rules/document` | `interoperability/processes/document` | `interoperability/transforms/document` |
  | `labelKey` | `interopRuleEditorTitle` | `interopBplEditorTitle` | `interopDtlEditorTitle` |
  | `emptyStateKey` | `interopRuleEditorEmpty` | `interopBplEditorEmpty` | `interopDtlEditorEmpty` |
  | `classicPage` | `EnsPortal.RuleEditor` | `EnsPortal.BPLEditor` | `EnsPortal.DTLEditor` |
  | `toolIdentifier` | `interop.ruleeditor` | `interop.processeditor` | `interop.transformeditor` |

  Every other key is the same on all three:
  - `area` `interoperability`, `sideBarPosition` 0, `archetype` `viewer (source)`, `built` true, `refreshes` false.
  - `privileges` `[%Ens_Portal:USE, %Ens_Code:READ]`, `ownPrivileges` `[%Ens_Code:READ]`.
  - `entityType` `class`, `scope` `namespace`, `parentScope` `""`, `id` single.
  - No read, table, actions or `commandAliases`.
  - `context` `{fields: [], secretFields: []}`.
  - Three `promptGroupGettingStarted` prompts (`interop<Rule|Bpl|Dtl>EditorPrompt1..3`).
- [ ] `src/OcuPilot/Test/InteropEditorDescriptor.cls` (new, about 150 lines, unarmed, read-only):
  - `TestTheThreeEditorScreensRegister`: each declaration carries the table's values. `Registry.Validate` passes. Its classic page equals `%SYS.Portal.Resources.NormalizePage("<page>.zen")`, read in `%SYS` by explicit save and restore.
  - `TestEachClassicEditorSharesTheScreensPair`: the classic page's compiled `RESOURCE` names `%Ens_Code:READ`.
- [ ] `src/OcuPilot/Test/InteropDescriptor.cls` `TestTheCodeListsReadThroughThePort` (extend):
  - Every Processes and Transforms row carries a boolean `Coded`.
  - `EnsLib.HL7.MsgRouter.RoutingEngine.cls` and `EnsLib.ITK.AdapterKit.Transform.PHDEToXMLDETransform.cls` read true.
  - `EnsLib.Background.Process.ExportMessageSearch.cls` and `Ens.Util.DTL.Audit.MessageView.cls` read false.
  - Rules rows carry no `Coded`.
- [ ] Rosters, each row named from the instance:
  - `Test/StageTwoTools.cls` `Elsewhere`: three rows, sorted.
  - `Test/SurfaceCoverage.cls`: three `<screen>` rows naming `InteropEditorDescriptor`'s `TestTheThreeEditorScreensRegister` with `corpus="one declaration test pins all three Story 20.7 editor screens in one loop"`.
  - `Test/Navigation.cls`:536-537: 19 becomes 22. In the order list, the process editor goes after `lookup-tables/entries`, and the rule and transform editors after `queues/messages`.
  - `Test/InteropFloor.cls` `ADMINISTRATORSCREENS`: the three, sorted.
- [ ] `ui/src/app/core/strings.ts` (add-only): the fifteen literals in Design Notes › Strings. Then regenerate `ui/src/app/core/screens.generated.ts` with `cd ui && node tools/screen-mirror.mjs`.
- [ ] `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`:
  - :604, appended with no new line: the fifteen literals with a Story 20.7 clause.
  - :159, after the Interoperability sentence: "A Business rules, Business processes or Data transformations name cell opens the class in InterSystems' rule, BPL or DTL editor, in place (Story 20.7)."
  - Then run `cd ui && npm run test:tools`.
- [ ] `ui/src/app/areas/interoperability/interop-editor-frame.ts` (DW-2350):
  - Add `revision = input(0)`.
  - Draw the frame inside `@for` over a one-element list keyed by `revision` and source. A change of either then removes the element and creates a new one, and `syncSource` sets `src` once on it.
  - Replace the doc comment's last sentence: the component never navigates a drawn frame; a new source or revision is a new frame.
- [ ] `interop-editor-frame.spec.ts`:
  - Rewrite :149 as: a document, namespace or editor change draws a different element carrying the new `src`, and the old one is detached.
  - Add: a `revision` change draws a new element at the same `src`.
  - The other tests stay.
- [ ] `ui/src/app/areas/interoperability/interop-editor.store.ts` (new, framework-free, AD-19). `InteropEditorState` holds `phase` (`loading | open | gone | coded | refused | fault`), `document`, `namespace`, `revision` and `failedPair`.
  - **`open(id, namespace)`** checks the list's verdict first. A denied verdict is `refused` with its pair, and nothing is sent.
  - Otherwise it reads `screenReadPath(list, EDITOR_READ_ROWS = 1000)` with that `scope`, finds the row whose `Name` equals `id` exactly, and answers one of:
    - `gone` when no row matches, or the id lacks `.cls`;
    - `coded` when `Coded` is true;
    - otherwise `open`, with `document` = the id less `.cls` and `revision` + 1.
  - A 403 is `refused` naming `detail.failedPair`. Any other failure is `fault`.
  - A generation counter drops a late answer.
  - **`refresh()`** reads again for the same id and namespace.
- [ ] `ui/src/app/areas/interoperability/interop-editor.page.ts` (new, `app-interop-editor-page`, `OnPush`):
  - **Wiring.**
    - It maps its descriptor to its editor.
    - It finds its screen with `screenForUrl`, its list with `listForDocumentScreen` and its id with `ownIdSegment`.
    - It opens again on `NavigationEnd` and on a scope change.
  - **Drawing.** Its host is a column flex item that fills the outlet (`_components.scss`:6054-6060's reason). It draws:
    - `loading`: skeleton bars in an `aria-busy` region;
    - `open`: a bar with the note and Refresh (`actionRefresh`), above `<app-interop-editor-frame [editor] [namespace] [document] [revision]>`, which fills the remaining height;
    - `gone`: `STRINGS[screen.emptyStateKey]`;
    - `coded`: the editor's coded sentence;
    - `refused`: `formatRequires(STRINGS.privilegeRequiresResource, pair)`;
    - `fault`: `connectivityRequestRefused` with Retry.
  - Each block carries a `data-ocu-editor` attribute (`note`, `refresh`, `gone`, `coded`, `refused` or `fault`).
  - It never draws an `<iframe>` itself.
- [ ] `ui/src/app/shell/screen-outlet.ts`: an `INTEROP_EDITOR_PAGE` loader constant, then three `DESCRIPTOR_PAGES` entries naming it, after the interop rows.
- [ ] `ui/tools/interop-editor-store.test.mjs` (new, sibling of `database-details-store.test.mjs`): the matrix's open, coded, gone, refused (verdict and 403), fault, stale-answer, refresh and namespace rows, against a stubbed `requestJson`.
- [ ] `ui/src/app/areas/interoperability/interop-editor.page.spec.ts` (new):
  - Each phase draws its block.
  - `open` draws one `app-interop-editor-frame` with the editor, namespace, `document` without `.cls`, and revision.
  - Refresh bumps the revision.
  - An id change opens the new document.
- [ ] `ui/tools/navigation.test.mjs`:
  - The roster gains the three routes, in Navigation.cls's order.
  - A pairing test after :775 asserts `documentScreenFor` of each list is its editor screen, and `listForDocumentScreen` is the inverse.
- [ ] `ui/tools/screen-mirror.test.mjs`:2448-2496: add the three to the `ownPrivileges` owners, sorted.
- [ ] `ui/browser/structural-walk.mjs`:
  - `SOURCE_VIEWER_IDS` gains `interoperability/processes/document: 'EnsLib.Background.Process.ExportMessageSearch.cls'` and `interoperability/transforms/document: 'Ens.Util.DTL.Audit.MessageView.cls'`. Both are core classes in every interop namespace, measured 200 in their editors.
  - `SKIP` gains `interoperability/rules/document`: "HSCUSTOM holds no business rule, so the walk has no rule to open; interop-editors.browser-spec.mjs walks it on the probe rule it creates".
  - Any fresh baseline entry is fixed or appended, as the file says.
- [ ] `ui/browser/interop-editors.browser-spec.mjs` (new). `before` refuses `LIVE_CONTAINER` and requires readiness `installed`.
  - **Fixtures.** Through `runIris` in HSCUSTOM, `before` creates `OcuPilotProbe.EditorScreen.Rule` (a routing rule), `.Process` (BPL) and `.Transform` (DTL), each compiled, plus `.Broken`, a DTL loaded without compiling whose `<code>` does not compile. It records `^EnsPortal.Settings(<user>,"LastDTL")` and `"LastBP"`.
  - **`after`** deletes the package and restores both nodes. Each test signs in its own context.
  - **Tests**, each carrying its leg's mutation comment (Verification › Planned pinning mutations):
    1. **AC1**, per editor, from the list's name cell.
    2. **AC1's walk**: `structural` for each screen. No fresh entries.
    3. **AC2**: save, compile and the broken compile.
    4. **AC3**: gone and coded.
    5. **AC4**: the editor moves away, Refresh draws it again, and an in-screen switch draws a new frame.
    6. **AC5**: sign-out.
- [ ] **DW-2347:** the browser spec's tests 1, 2 and 6 (AC1, AC5).
- [ ] **DW-2350:** the frame task, its spec, AC4, and Design Notes › DW-2350.
- [ ] **DW-2351:** Refresh, the note, AC4, and Design Notes › DW-2351.
- [ ] **Roster sweep (Rule 30).** Search `src/OcuPilot/Test`, `ui/tools`, `ui/browser` and the `ui/src` specs for any assertion about the interop screen count or order, the code lists' read fields, or `interop-editor-frame`'s set-again behavior. Each changed file joins the `(loop)` set.

**Acceptance Criteria:**

- **AC1 (in place, from the instance, signed in through the hand-off; DW-2347).**
  - **Given** the signed-in shell on `ocupilot-b-ci` and the spec's probe rule, BPL process and DTL transformation in HSCUSTOM.
  - **When** the person opens each from its list's name cell.
  - **Then:**
    - the route is `<list>/document/<class>.cls`;
    - one `app-interop-editor-frame iframe` is drawn, with `src` equal to `interopEditorSource(<editor>, 'HSCUSTOM', <class>)`;
    - `assertSignedInSilently` holds for it with `documentStatus: 200`;
    - every request the frame makes under `/ui/interop/` is `/ui/interop/<that editor>/…` on the instance's origin and is answered by it;
    - at 1280×900 the frame's box equals its host's box (±1 px), the host ends at `.ocu-screen-outlet`'s bottom edge (±1 px), and the frame is at least 400 px tall;
    - the locator's screen segment links to the list;
    - `structural` finds no fresh entry at 1280 light, 720 light or 1280 dark.
- **AC2 (the editors' notices; the re-scoped messages criterion).**
  - **Given** the probe DTL's editor screen.
  - **When** the person types in Transform Settings' Description and saves, then compiles.
  - **Then:**
    - the frame shows the editor's "<class> saved." and then "<class> compiled successfully";
    - `armMessageCounters` reads no message in the shell or the frame;
    - on returning to Data transformations, the probe's Modified equals `$ZDateTime` of the class definition's `TimeChanged`, read on the instance, and differs from its value before the save.
  - **And given** `.Broken`, when the person chooses Compile, then the frame shows the editor's notice containing "error occurred while compiling", and no message.
- **AC3 (gone and coded).**
  - **Given** `interoperability/transforms/document/OcuPilotProbe.EditorScreen.Absent.cls` and `interoperability/processes/document/EnsLib.HL7.MsgRouter.RoutingEngine.cls`.
  - **When** each opens.
  - **Then** there is no `iframe` and no request under `/ui/interop/` or `/api/interop-editors/`. The screen shows "This data transformation no longer exists." and "This business process is written as a class, not in BPL, so the BPL editor cannot open it." respectively.
  - **And** the port test pins `Coded` for both kinds.
- **AC4 (OcuPilot never navigates a drawn frame; DW-2350, DW-2351).**
  - **Given** the probe DTL's screen and a handle on its frame element.
  - **When** the person chooses the editor's own "Back to standard UI", **then** the frame shows `/csp/hscustom/EnsPortal.DTLEditor.zen…`, and the screen's route and note are unchanged.
  - **When** the person then chooses Refresh, **then** the old element is detached, and a new one with the builder's `src` shows the DTL editor again.
  - **When** the route moves in-app to `…/transforms/document/Ens.Util.DTL.Audit.MessageView.cls`, **then** a new element with that source replaces the old one.
  - **And** the component spec pins a new element for each document, namespace and revision change.
- **AC5 (sign-out on the real screen; DW-2347).**
  - **Given** the probe DTL's screen, signed in, and the editor's held tokens.
  - **When** the person signs out from the account menu.
  - **Then** `assertSignOutEndsEditors` holds.
- **AC6 (declared, gated, rostered).**
  - **Given** the three descriptors.
  - **When** the instance validates them and the build regenerates the mirror.
  - **Then:**
    - each validates on the instance and in the mirror, with the table's values;
    - each list's `documentScreenFor` is its editor;
    - each is unlisted, carries three prompts, and is in the `Elsewhere` block, which reddens alone when a row is removed;
    - the Interoperability navigation carries 22 screens in the pinned order;
    - `InteropFloor` shows the Administrator role opening the three, while Operator and Monitor, who lack `%Ens_Code:READ`, open none.

## Spec Change Log

- 2026-10-13, spec gate (runner): Rule 5 amendment applied to `epics.md` Story 20.7's second criterion (apply-and-report; the owner's 2026-10-07 decision moved it here). Original: "Given the editors' own messages - saved, compiled, invalid, When they are exchanged, Then the contract is established against a live editor, because it was never exercised." Amended: the Design Notes' proposed wording, verbatim. The Rule 20 drafts are written: AD-63's named consequence, AD-62 item 13 (`Coded`), AD-44's Story 20.7 `CLASSICPAGES`, and the EXPERIENCE.md :856 state-matrix exception. DW-2376 (decision-pending) asks the owner whether a later story adds a leave guard; this spec does not depend on the answer.

## Review Triage Log

## Design Notes

**Governing ADs:**

- **AD-63**, all five limits and its named consequence. This story writes the measured notices sentence (spine draft below).
- **AD-47** and **AD-28**: the origin, the policy and the sign-out path are unchanged. **NFR-3.**
- **AD-62**: item 1 (OcuPilot calls nothing of `%Api.InteropEditors`), item 3 (switched), item 8 (`Coded` is a field, not a criterion) and item 12.
- **AD-5**: three descriptors; a page issuing another built screen's read; one shared loader line set; the name cell's `<list>/document` pairing.
- **AD-44**: the classic editor pages; custom resources.
- **AD-8** and **AD-64**: the list's pairs; each screen is adjustable.
- **AD-13**: the id is `<class>.cls`, one segment.
- **AD-16**: switched read.
- **AD-19**: framework-free store, `OnPush`.
- **AD-20**: one absolute read; the frame component makes no call.
- **AD-21**: no path from text.
- **AD-24**: no context field; the route id reaches screen context as `id`.
- **AD-11**: `src` through `Renderer2`; sentences drawn as text.

Checked and not engaged:

- AD-22 and AD-53 (no write, tool or key);
- AD-10, AD-15, AD-36 (no new read);
- AD-43 (Refresh is manual; no auto-refresh);
- AD-57.

**Measured at this plan on `ocupilot-b-ci`** (2026-10-12). The bundle was `main-HWTCU35R.js`, at `31e2f7b0`. Frames were harness-mounted in the signed-in shell, and the probe acted as the person. The probe packages (`OcuPilotProbe.Edit207*`) and the `LastDTL` node they caused were removed afterwards and verified.

- **Saved, compiled and invalid in normal mode.** No message reached the shell or the frame in any case.

  | Action | Request | The editor's own notice | On the instance |
  |---|---|---|---|
  | DTL Save | `PUT …/dtl/<c>` 200 | "<c> saved." | Definition `TimeChanged` moved, `IsUpToDate` 0. The list's Modified moved from 06:12:39 to 06:25:14 |
  | DTL Compile | `PUT …/dtl/compile/<c>` 200 | "<c> compiled successfully" | Compiled `TimeChanged` moved |
  | BPL Compile | `PUT …/bpl/compile/<c>` 200 | "<c> compiled successfully" | - |
  | Rule Compile (saves too) | `PUT …/rules/<c>` and `PUT …/rules/compile/<c>`, both 200 | "Rule saved and compiled." | - |
  | Uncompilable DTL, Compile | `PUT …/compile` 500 | "An error occurred while compiling class '<c>' (… #1054 …)" | - |
  | Absent document, any editor | `GET …/<kind>/<c>` 404 | None: an empty editor | - |
  | Coded process or transformation | `GET …` 400 | - | - |

  The bundle's `saved`, `compiled`, `changed` and `bad*` posts are `vscodeMode`-only.
- **Unsaved changes in a dirty DTL editor:**
  - Setting `src` again raised its `beforeunload` alert, and dismissing the alert kept the document.
  - Removing the frame raised nothing.
  - A tab reload raised the alert.
- **History.**
  - Setting `src` again added entries: rule 3→5, BPL 4→7.
  - After a fresh load, Back moved the frame first: the rule editor once, DTL and BPL twice. The shell moved after that.
- **Self-navigation.**
  - DTL's and BPL's "Back to standard UI" loaded `/csp/hscustom/EnsPortal.{DTL,BPL}Editor.zen?…` into the frame, adding one entry. The shell was unchanged.
  - DTL and BPL each show a Namespace button.
  - The rule editor's logo goes to `UtilHome.csp` (bundle, 20.13).
- **The lists in HSCUSTOM:**
  - Business rules: 0 rows.
  - Business processes: 67 rows. Only 5 vendor classes are BPL (`EnsLib.Background.Process.ExportMessageSearch` and four others).
  - Data transformations: 646 rows. 2 are not DTL (the two ITK transforms).
- **`NormalizePage`** answers `EnsPortal.RuleEditor`, `EnsPortal.BPLEditor` and `EnsPortal.DTLEditor` for the `.zen` pages.
- **An uncompiled DTL** is listed by the Transforms read and is in `SubclassOf("Ens.DataTransformDTL")`, so `.Broken` reads `Coded` false and opens in the DTL editor.

**Rule 5 draft (for the lead; the owner's 2026-10-07 decision moved this here).**

- **Original** (`epics.md`, Story 20.7, second criterion): "**Given** the editors' own messages - saved, compiled, invalid **When** they are exchanged **Then** the contract is established against a live editor, because it was never exercised."
- **Proposed:** "**Given** a rule, BPL or DTL editor on its OcuPilot screen, in normal mode **When** the person saves, compiles, or compiles a class that does not compile **Then** the editor reports it in its own notice inside the frame, no message reaches OcuPilot's shell or the frame, and OcuPilot shows the result only through its own reads (the list's Modified after its next fetch); and a class OcuPilot's read does not answer, or a process or transformation written as a class, opens no editor and shows the screen's own sentence."
- **Measurement:** the table above. It is pinned by AC2 and AC3.
- **Tier:** apply-and-report. It restates the observable, and the intent (what the live editor exposes, established and pinned) is unchanged. No `?VSCODE=1`, `postMessage` sign-in or pre-written storage is used or proposed.

**Decisions:**

- **Route and pairing: `<list>/document`.** `documentScreenFor` makes every name cell open the editor, and the locator links back to the list, with no edit to the lists' linking.
  - *Rejected, `rowTarget` with `unless: "Coded"`:* it would withhold a coded row's link, as the classic list does. But the locator's screen segment would then point at the editor's own bare route, which reads no document. A process or transformation written as a class therefore opens its screen's coded sentence instead.
- **Archetype `viewer (source)`.** It shows one document at `<list>/document/<id>`. Its state-matrix row (skeleton, gone sentence, error, refusal, manual refresh) fits, and the DW-1337 walk opens it with an id.
  - *Rejected, `detail`:* the walk opens it with no id.
  - *Rejected, a new archetype:* it needs a vocabulary, matrix and page change for no difference in behavior.
- **`Coded` on the list reads.** The editor screen needs the classic `IsBPL`/`IsDTL` answer from a read OcuPilot answered. The vendor's own read of a coded class answers 400. The list reads already enumerate the same dictionary.
- **The read cap.** The page reads the list with `maxRows` 1000, the read route's ceiling, which is the most the list itself shows. HSCUSTOM's largest list is 646 rows.
- **DW-2350, the switches.** Each is chosen for one reason: the screen and the frame never disagree, and OcuPilot adds no history entry of its own.

  | Switch | What OcuPilot does | The editor's unsaved-changes alert |
  |---|---|---|
  | A new id on the drawn screen | A new frame | Not shown; changes dropped |
  | Namespace move | The frame goes at once; a new frame after the new read | Not shown |
  | Refresh | A new frame | Not shown |
  | Leaving the screen, any way | Page and frame destroyed | Not shown |
  | Sign-out, or session end | The shell withholds the screen | Not shown; the sign-in ends anyway |
  | Tab close or reload | - | Shown by the browser (measured) |

  - *Rejected, setting `src` again on the drawn frame:* it keeps the alert for the in-screen switch only. It also adds history entries, so Back moves the frame, and a dismissed alert leaves the old document under the new route.
  - *Rejected, an always-asking leave dialog:* OcuPilot cannot know whether the editor holds changes. `core/form-dirty.ts` records why a dialog on every navigation is one nobody reads.
  - The screen's note asks the person to save first.
- **DW-2351, the editor moving away unseen.** It can move through its logo, Back to standard UI, its own New, Open and Save As, its Namespace and Settings, and Back through its own history entries. The screen keeps naming its own document (route and locator) and never reads the frame. Refresh draws the screen's document again (AC4).
  - Back moving the frame first is a named limit. The locator's list link returns to the list in one step.
- **Handed over by 20.13: the vendor's sign-in form after a login ended elsewhere.** No code. OcuPilot's next request shows the session-ended card and withholds the frame. That request can be the navigation map or Refresh's read. OcuPilot never fills or reads the form (AD-63's named consequence).
- **No `NEW=1` and no empty editor.** A new rule, BPL or DTL is created with the editor's own New, inside a frame opened on any document. The vocabulary stays closed.

**Strings (fifteen literals, add-only).** The strings count goes from about 3,295 (after 20.27) to about 3,310, under the 3,350 point that triggers raising the bound.

- Empty:
  - `interopRuleEditorEmpty` "This business rule no longer exists."
  - `interopBplEditorEmpty` "This business process no longer exists."
  - `interopDtlEditorEmpty` "This data transformation no longer exists."
- Coded:
  - `interopBplEditorCoded` "This business process is written as a class, not in BPL, so the BPL editor cannot open it."
  - `interopDtlEditorCoded` "This data transformation is written as a class, not in DTL, so the DTL editor cannot open it."
- Note: `interopEditorNote` "OcuPilot does not see inside this editor: save your changes there before you leave this page, and choose Refresh to open the document again."
- Prompts:
  - Rules: "Summarize what this business rule decides.", "Which targets does this rule send messages to?", "Which conditions does this rule test, in order?"
  - BPL: "Summarize what this business process does.", "Which business operations does this process call?", "Where does this process handle errors?"
  - DTL: "Summarize what this data transformation maps.", "Which target fields does this transformation set, and from what?", "How do I test this transformation?"
- Labels reuse the three frame titles.

**Weight.** The page, the store and the frame component land in one lazy chunk, about 10 to 14 kB (inference), under 88 kB. The initial bundle gains the strings, three mirror entries and the loader lines, about 5 kB (inference), against about 1.90 MB after 20.27 and `maximumWarning` 1992kB. No page is made eager, and nothing is re-based.

**Spine and UX drafts (Rule 20; the lead writes them at the gate):**

- **AD-63, named consequence.** Replace "Story 20.7 re-scopes that criterion at its spec gate." with: "Measured at Story 20.7's plan: in normal mode the editors show their saved, compiled and compile-failure notices inside the frame and send no message, and an editor asked for a class it cannot open shows an empty editor. Story 20.7's screens open an editor at `<list>/document/<name>.cls` only for a class the list's own read answers (a process or transformation not marked `Coded`). They never navigate a drawn frame: a new document, a namespace move or Refresh draws a new frame, so the editor's unsaved-changes alert does not show (measured: it shows when the source is set again and not when the frame is removed), and the screen asks the person to save first. The editor can still move away from what its screen shows, unseen (its logo, Back to standard UI, its own Open, Namespace and Settings, and the history entries DTL and BPL push); Refresh opens the screen's document again."
- **AD-62, a Story 20.7 clause:** "The Processes and Transforms lists answer `Coded`, true for a class that does not descend from `Ens.BusinessProcessBPL` or `Ens.DataTransformDTL` in the dictionary (the classic lists' `IsBPL` and `IsDTL`). The vendor's editors answer 400 for such a class (measured)."
- **AD-44, a Story 20.7 clause:** "The rule, BPL and DTL editor screens declare `EnsPortal.RuleEditor`, `EnsPortal.BPLEditor` and `EnsPortal.DTLEditor` (`NormalizePage`, measured)."
- **EXPERIENCE.md, state-matrix exceptions (:856), appended:** "the three Interoperability editors (Story 20.7) are `viewer (source)` screens whose content is the vendor's editor in a frame: empty is the screen's 'no longer exists' sentence, a process or transformation written as a class shows its sentence instead of an editor, and refreshing is Refresh, which opens the document in a new frame."

**Integration, Consumes, Consumed-by (Rules 1 and 2):**

- **Integration:** the three screens consume 20.13's builder, frame and browser helper against the real instance (AC1, AC4, AC5).
- **Consumes:**
  - 20.13: `interopEditorSource`, `app-interop-editor-frame` and `interop-editor-spec.mjs`;
  - 20.2: `ListClasses` and the three list reads;
  - 20.29: the loader maps;
  - 19.x: `listForDocumentScreen` and `screenReadPath`.
- **Consumed-by:**
  - 20.16: its "reload the editor" is this page's Refresh path, a new `revision` (inference);
  - 20.8: the schema viewers and the diagram reuse the frame's `revision` and the page shape (inference);
  - 20.10: source control inside these frames.

**Ledger inbox (Rule 17):**

- **DW-2347:** the browser spec's AC1 and AC5 legs, including the host-filling assertion.
- **DW-2350:** the frame task, its spec rewrite, AC4 and the switch table.
- **DW-2351:** Refresh, the note, AC4 and the named limits.

**Rule 31 (extend, don't copy):**

- `ListClasses` is extended in place.
- The page is its own component beside `source-editor.page.ts` and `document-viewer.page.ts`. Its content is a vendor frame with no read of its own, and it reuses `screenReadPath`, `listForDocumentScreen`, `ownIdSegment`, `formatRequires`, the skeleton classes and the fault strip.
- The store follows `SourceEditorState`'s scoped read and generation guard as a new class. Its states differ, and the source editor's store is Epic 19's.
- The frame component is changed, not wrapped.
- The browser spec reuses `interop-editor-spec.mjs`, `list-spec.mjs` and `panel-spec.mjs`, and keeps the per-spec `structural` helper (the convention about 20 specs share).
- The `Coded` assertions extend `InteropDescriptor`'s port test. The descriptor test is a new class only because `InteropDescriptor` is near its 500-line limit.

**Contended files (Rule 11).** `origin/OCU-1-epic18` (`afe665b1`) is not an ancestor of this branch. Its diff touches these files of this story's:

- `Test/StageTwoTools.cls`: its Roster block and `UNADVERTISED`. This story adds `Elsewhere` rows.
- `Test/SurfaceCoverage.cls`: one tool row. This story adds screen rows.
- `strings.ts`, EXPERIENCE.md and the spine.

Each of this story's edits there is add-only.

It does not touch `Test/Navigation.cls`, `Test/InteropFloor.cls`, `screens.generated.ts` (regenerated at the forward merge), `screen-outlet.ts`, `navigation.test.mjs` or `screen-mirror.test.mjs`. Security surfaces (content-security policy, `frame-src`, `index.html`, nonce, headers, `api.test.mjs`'s bans) are untouched. No Rule 11 ask.

**Named limits:**

- A class beyond the read's 1,000 rows reads as gone. The list cannot show it either.
- Any OcuPilot navigation drops the editor's unsaved changes without its alert. The note says so.
- The editor can move away unseen. For DTL and BPL, Back moves the frame first.
- The editor's notices exist only inside the frame. OcuPilot neither relays nor records them.
- A coded row's name cell opens a screen that explains, rather than no link.

## Verification

**Shared surfaces:**

- the Interoperability navigation roster (count and order) in `Test/Navigation.cls` and `navigation.test.mjs`;
- `StageTwoTools`' `Elsewhere`, `SurfaceCoverage`'s screen rows and `InteropFloor`'s `ADMINISTRATORSCREENS`;
- `screen-mirror.test.mjs`'s `ownPrivileges` owners;
- the Processes and Transforms read fields;
- the structural walk's `SOURCE_VIEWER_IDS`, `SKIP` and its baseline;
- `interop-editor-frame`'s redraw behavior;
- the strings table and EXPERIENCE.md :159 and :604;
- the built-screen count that Screen permissions derives (185 to 188).

*Every test added or changed passes on a fresh environment, in either order.* The browser spec creates and removes its own probes and restores the two `^EnsPortal.Settings` nodes. The ObjectScript classes read vendor classes only.

**Setup (slot B; never the dev instance `ocupilot-slot-b`):**

- **Load `src`:**
  1. Run `rsync -a --checksum --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-20/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`.
  2. In `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`, run `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)`.
- **Before any browser run:** `cd ui && npm run build && docker exec ocupilot-b-ci sh -c 'cd /durable/iris/csp/ocupilot && rm -rf ./*' && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`.

**Commands.** Run each in the foreground with `timeout: 600000`, one at a time. Read each class's result from `%UnitTest_Result`.

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.InteropEditorDescriptor --class OcuPilot.Test.InteropDescriptor --class OcuPilot.Test.StageTwoTools --class OcuPilot.Test.SurfaceCoverage --class OcuPilot.Test.Navigation --class OcuPilot.Test.InteropFloor`. Expected: green (about 20 s by `ci-timings.json`).
- `(loop)` the same runner with `OcuPilot.Test.Descriptor`, `OcuPilot.Test.CompileWithoutInterop`, `OcuPilot.Test.InteropFloorOwnPairs`, `OcuPilot.Test.ToolNavigate`, `OcuPilot.Test.ScreenAccessWire`, and every class the roster sweep changes. Expected: green (about 60 s).
- `(loop)` `cd ui && npm run test:tools`, then `cd ui && npm run test:components`. Expected: green.
- `(loop)` `cd ui && npm run build -- --verbose`. Expected: the prebuild chain is green, the new chunk is under 88 kB, and the initial total is under 1992kB. Record both.
- `(loop)` `uv run scripts/check-objectscript.py <each changed .cls>` and `bash scripts/lint-docs.sh`. Expected: clean.
- `(loop)` `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/<file>`, one file per call, after the redeploy. Expected: green.
  - `interop-editors.browser-spec.mjs`
  - `interop-editor-frame.browser-spec.mjs`
  - `interop-productions.browser-spec.mjs`
  - `a11y-structural-invariants.browser-spec.mjs` (about 422 s, plus the two new screens)
- **Lead-owned (the runner's, not the implement stage's):** the full ObjectScript sweep, `cd ui && npm test`, `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`, and Rule 30's fresh check.
- **Left to CI:** the full browser suite.

**Planned pinning mutations (Rule 19).** Revert each byte-identical. Reload, or rebuild and redeploy, before the next.

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | The page passes `document` with its `.cls` kept | The browser spec's AC1 (the document read answers 404, not 200), and the page spec |
| AC1 (DW-2347) | The frame component's `:host` loses `height: 100%` | The AC1 box assertion (the frame is 150 px tall) |
| AC2 | `ListClasses` reads `Modified` from the compiled class rather than the definition | The AC2 Modified leg (a save without compile leaves it unchanged) |
| AC2 | `interopEditorSource` appends `&VSCODE=1` | The AC2 message leg (`compatible` is posted and no login happens), and `vendor-frame.test.mjs` |
| AC3 | The page draws the frame from the route id without checking the row | The AC3 gone leg (an `iframe`, and a `/ui/interop/` request), and the store test |
| AC3 | `ListClasses` answers `Coded` false for every row | The port test's two true rows, and the AC3 coded leg |
| AC4 | The component's `@for` tracks a constant key (it keeps the element) | `interop-editor-frame.spec.ts`'s redraw tests, and the browser Refresh leg (the old handle stays connected and shows the Zen page) |
| AC4 | The store drops its generation check | The store test's stale-answer row |
| AC5 | `Session.signOut()` posts `/logout` with `credentials: 'omit'` | The AC5 leg (the editor's login answers 200) |
| AC6 | One editor's route is moved off `/document` | `navigation.test.mjs`'s pairing test, and `InteropEditorDescriptor` |
| AC6 | One `Elsewhere` row is removed | `StageTwoTools` `TestTheRosterAndElsewhereAreEveryRegisteredScreen`, alone |
| AC6 | `%Ens_Code:READ` is dropped from one editor | `InteropEditorDescriptor`, and `InteropFloor`'s Administrator roster |

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
