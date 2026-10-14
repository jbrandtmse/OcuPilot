---
title: 'Story 20.8: The schema viewers and the production configuration diagram'
type: 'feature'
created: '2026-10-13'
status: 'done'
baseline_revision: '86c9fb2939138203e2847f61e2a81b2c108c3e82'
baseline_commit: '86c9fb2939138203e2847f61e2a81b2c108c3e82'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
warnings: [oversized, multiple-goals]
deferred: []
---

<intent-contract>

## Intent

**Problem:** OcuPilot has no way to browse the HL7, X12 and ASTM message schemas, and no way to see a production laid out. For both, a person still leaves for the classic portal. InterSystems ships both as Angular apps under `/ui/interop`: the schema viewer, and the production configuration app (the diagram). Story 20.7 built the signed-in frame, the shared page and the store for the rule, BPL and DTL editors, but nothing draws these two apps.

**Approach:** Two new screens, each drawn by 20.7's editor page and frame under AD-63.

- **Schema viewer.** A listed Interoperability screen, `interoperability/schema-viewer`. It draws InterSystems' schema viewer in place for HL7 v2.x, ASC X12 and ASTM, read-only.
  - The person chooses the schema type in the viewer's own list.
  - Measured at this plan: the viewer's `&ST` document parameter is overwritten before the viewer reads it, so a family cannot be chosen from the URL. The screen therefore sends no document parameter.
- **Configuration diagram.** An unlisted screen, `interoperability/productions/diagram/<production>`, opened from a link on the production's Production items screen.
  - It confirms the production through the Productions list's own read, then draws the production configuration app with `$PRODUCTION`.
  - The app opens its sibling editors in new browser tabs, which OcuPilot leaves as the vendor built them.

## Boundaries & Constraints

**Always:**

- **AD-63's five limits, unchanged, as 20.7 keeps them:**
  1. The frame's only source is `interopEditorSource`.
  2. Normal mode.
  3. Nothing in the frame is read, posted to or listened to.
  4. Sign-out ends the app's sign-in.
  5. No sandbox.
- **The vocabulary grows by two entries, each read on the instance:**
  - `schema-viewer`, with no document parameter. Given a document, the builder answers `null`.
  - `interop-editor`, with `$PRODUCTION`, whose value must match `CLASS_NAME`.
  - Each frame's title comes from its descriptor's label key.
- **Where the diagram's production comes from.** The diagram draws a production only after the Productions list's declared read answers a row whose `Name` equals the route id exactly. It reads with `screenReadPath(list, 1000)` and `scope` pinned (AD-5's "a page may issue another built screen's read"). The list's verdict is checked first. The `Name` sent is the row's own.
- **The schema viewer issues no request of its own.** The screen gate decides whether it mounts. Refresh and a namespace move each draw a new frame.
- **OcuPilot never navigates a drawn frame.** A new document, a namespace move or Refresh draws a new element (20.7's `revision`).
- **Classic pages.**
  - The schema viewer replaces three classic pages and honors each page's custom resource (AD-44). Its descriptor declares `EnsPortal.HL7.SchemaMain`, and its class's `CLASSICPAGES` names the X12 and ASTM pages. `Screen.Gate.RequiredPairs` unions each page's custom resource, as a write tool's `CLASSICPAGES` does.
  - The diagram declares `EnsPortal.ProductionConfig`.
- **Pairs.**
  - Schema viewer: `%Ens_Portal:USE` and `%Ens_EDISchema:READ`, with `%Ens_EDISchema:READ` as its own pair.
  - Diagram: the Productions list's set, `%Ens_Portal:USE` and `%Ens_ProductionConfig:READ`, with `%Ens_ProductionConfig:READ` as its own pair.
- **Edits.** Strings go in `strings.ts` and EXPERIENCE.md's Fixed strings. Contended files take add-only edits (Design Notes › Contended files).

**Never:**

- Any query parameter beyond `$NAMESPACE` and the app's own document parameter: no `VSCODE`, `READONLY`, `NEW`, `HOST` or `&ST`.
- A `postMessage`, a pre-written storage key, a sandbox, an `allow` attribute, or any read of the frame or of vendor storage keys. `api.test.mjs`'s bans stay as they are.
- Any change to the content-security policy, `StaticHandler`, `index.html`, any header, the token store, `Session` or CORS.
- A call to `%Api.InteropEditors` by OcuPilot (AD-62 item 1).
- A vendor file copied into the repository, the bundle or the package.
- A new write tool, governance key, read tool, read, entity type or area.
- A leave guard or a confirm dialog.
- A change to where the Productions name cell links: it stays Production items.
- Edits to any of: `Screen/Registry.cls`, `Screen/Read.cls`, `Kernel/Proposal/Prohibited.cls`, `Kernel/EntityType.cls`, `app.routes.ts`, `angular.json`, `.github/workflows/ci.yml`, `ui/tools/ci-shards.mjs`, `ui/tools/ci-timings.json`, `ui/tools/ci.test.mjs`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Schema viewer opens | Side bar › Interoperability › Schema viewer, scoped to HSCUSTOM | One frame, src `/ui/interop/schema-viewer/index.html?$NAMESPACE=HSCUSTOM`. The viewer's empty-body login answers 200, and it lists ASC X12's categories. The bar shows the note and Refresh | - |
| The three families | The person picks HL7 v2.x, then ASTM, in the viewer's own list | Each lists its categories (the instance's `^EnsHL7.Schema`, `^EnsEDI.X12.Schema` and `^EnsEDI.ASTM.Schema` category counts). Apart from the login, every request the frame makes is a GET | - |
| `&ST` is ignored | A harness frame at the classic pages' own address form, `?%24NAMESPACE=HSCUSTOM&%26ST=HL7+v2.x` | The viewer shows ASC X12, and its address ends `&%26ST=` | The measured vendor contract, pinned (AC2) |
| Diagram opens | The Production items screen of `OcuPilotProbe.Interop.Production` in USER › Configuration diagram | Route `interoperability/productions/diagram/OcuPilotProbe.Interop.Production`. The page reads `interop.productions`. One frame, src `/ui/interop/interop-editor/index.html?$NAMESPACE=USER&$PRODUCTION=OcuPilotProbe.Interop.Production`. The app's `GET …/v7/USER/productions/<it>` answers 200, and its four items show | - |
| Sibling editor | In the diagram, BPL Editor's panel menu › Open in New Tab | A new browser tab at `/ui/interop/bpl-editor/index.html?$NAMESPACE=USER&BP=…`, signed in. The shell's route and the screen's frame element are unchanged | Its copy of the tab's pair is revoked at sign-out |
| Gone | `interoperability/productions/diagram/OcuPilotProbe.Interop.Absent` | No frame, and no request under `/ui/interop/` or `/api/interop-editors/`. "This production no longer exists." | - |
| Refused (diagram) | The Productions verdict is denied, or its read answers 403 with `failedPair` | No frame. "Requires <pair>". The schema viewer has no read: the screen gate refuses it before it mounts | - |
| Fault (diagram) | Any other non-ok answer | No frame. "request refused" with Retry | Retry reads again |
| Refresh | Refresh on either screen | A new frame element at the same src. The old one is detached | - |
| Namespace move | The scope moves | Schema viewer: a new frame in the new namespace. Diagram: the frame goes at once and the read runs again there | Absent there: gone |
| Sign-out | Account menu › Sign out, on either screen | No frame and no `Schema_Viewer-` or `Interop-Editors-` key. The app's login, access token and refresh token each answer 401 | - |

</intent-contract>

## Code Map

All paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-20`. Line numbers were read at `c245652c`. Story 20.16 (ready for development) edits the editor page, its store, `strings.ts`, EXPERIENCE.md and their tests, so anchor those files by symbol (Task 0).

### Shared embed pieces (20.13, 20.7): extend

- **`ui/src/app/core/vendor-frame.ts`** (68 lines):
  - `CLASS_NAME` :25 and `NAMESPACE_NAME` :28.
  - `InteropEditor` :31 and `InteropEditorTitleKey` :34.
  - `INTEROP_EDITORS` :43-47.
  - `interopEditorSource` :61-68. It appends `&<parameter>=<encoded document>` when a document is named.
- **`ui/src/app/areas/interoperability/interop-editor-frame.ts`**:
  - `editor`, `namespace`, `document` and `revision` inputs (:82-91).
  - `source` is null unless the namespace is the scope's (:99-103).
  - Its slot key is `${revision}|${source}` (:106-109).
  - The title is `STRINGS[INTEROP_EDITORS[editor].titleKey]` (:127-129).
  - `src` is set once through `Renderer2` (:131-136).
  - Nothing changes but the widened type.
- **`ui/src/app/areas/interoperability/interop-editor.page.ts`** (272 lines):
  - `EditorKind {editor, codedKey}` :14-17, `EDITOR_KINDS` :20-24 and `kindFor` :34.
  - The constructor (:146-183) finds the screen with `screenForUrl`, its list with `listForDocumentScreen` (:148) and its kind. If any is null it draws nothing.
  - The bar holds `data-ocu-editor="note"` with `STRINGS.interopEditorNote`, and Refresh (:105-108).
  - `goneText` :240, `codedText` :245, `routeId`/`ownIdSegment` :260 and `openFromRoute` :264.
- **`interop-editor.store.ts`** (195 lines):
  - `InteropEditorDeps {api, list, verdict}` :37-44 and `DOCUMENT_EXTENSION = '.cls'` :34.
  - `read()` :146-181 checks the verdict, then answers `gone` unless the id ends in `.cls` (:154). It reads `screenReadPath(list, EDITOR_READ_ROWS)` with `scope`, matches `Name === id` (:52-54, :166), answers `Coded` → `coded` (:169), and strips the extension (:170).
  - `settle('open')` bumps `revision` (:188).
- **`ui/src/app/shell/screen-outlet.ts`**: `INTEROP_EDITOR_PAGE` :75. The 20.7 rows are in `DESCRIPTOR_PAGES` :227-229, and the map closes at :230.
- **`ui/src/app/core/navigation.ts`**:
  - `documentScreenFor` :302 and `listForDocumentScreen` :309.
  - `childListFor` :329. `isChildListOf` (:338-348) excludes only the `detail` archetype, and SCREENS is sorted by class name (`ui/tools/screen-mirror.mjs`:501).
  - `parentListFor` :383, `ownIdSegment` :459, `screenForDescriptor` :479, `hasIdRoute` :637, `withQuery` :766.
- **`ui/src/app/shell/data-table.ts`**:655-671 is the name-cell chain: `rowTarget`, editor, document, detail, child list. Productions today resolves to `childListFor` → `InteropItemList`.
- **The sibling link pattern** is in `ui/src/app/areas/tasks/details.page.ts`:
  - `<nav>` with `a.ocu-details-link` (:111-119);
  - `historyUrl()` builds `withQuery(\`${route}/${encodeEntityId(id)}\`)` (:267-274);
  - `historyHref` uses `prepareExternalUrl` (:287);
  - `onOpenHistory` uses `navigateByUrl` (:311-316).
- **`ui/src/app/areas/interoperability/interop-item-list.page.ts`** (84 lines):
  - The template is `<app-list-page />` plus the add dialog (:36-39).
  - `production` reads the list's one criterion with `parentCriteria` (:69-74).

### Server

- **`src/OcuPilot/Screen/Gate.cls`**:
  - `RequiredPairs` :237-257 unions `ClassicResource($ClassMethod(pDescriptor, "ClassicPage"))` at :249-250.
  - `WithClassicPages(pPairs, pPages)` :381-393 is the write tools' union, with no duplicates.
  - `ClassicResource` is at :579.
- **`src/OcuPilot/Screen/Access.cls`**: `ClassicResourceOf` :89-92 feeds Screen permissions' `ClassicResource` column (:79) and `SEPARATOR` (:17).
- **`src/OcuPilot/Screen/Descriptor/Base.cls`**: `ClassicPage()` :390. It has no `CLASSICPAGES` parameter today.
- **Descriptor templates:**
  - `InteropRuleEditor.cls`: 48 lines, the unlisted `viewer (source)` template.
  - `ExplorerCompare.cls`: listed, `id` `none`, no read, `emptyStateKey` `""`.
  - A declaration with no read may leave `emptyStateKey` empty (`Registry.cls`:2696).
  - `"entityType": ""` is allowed (e.g. `Dashboard.cls`).
  - A built `parentScope` must name a built screen with an id (`Registry.cls`:3861-3891). The `read.criteria` rules apply only with a read (:1691, :1741).
- **`InteropProductionList.cls`**:
  - route `interoperability/productions`, privileges :31, `ownPrivileges` :32;
  - read `{"port":"interop","endpoint":"Productions","type":"LIST"}` :50;
  - `toolIdentifier` `interop.productions` :67.
  - Its rows are `{Name, Status, LastStartTime, LastStopTime}`, and `Name` carries no `.cls` (`Port/InteropPort.cls` `ListProductions` :1006-1047).
- **`Screen/Area.cls`:89**: Interoperability's set is `%Ens_Portal:USE`.

### Tests and rosters

- **`src/OcuPilot/Test/InteropEditorDescriptor.cls`** (99 lines):
  - `SCREENS` :11, `PAIRS` :14 and `OWNPAIRS` :16;
  - `TestTheThreeEditorScreensRegister` :25 and `TestEachClassicEditorSharesTheScreensPair` :62;
  - `NormalizedPage` :85.
- **`src/OcuPilot/Test/ScreenGate.cls`**: its `ClassicResource` answers `^||OcuPilotGateClassic(page)` (:94-98). `Reset()` clears it. It writes no store.
- **`Test/StageTwoTools.cls`**: the `Elsewhere` block runs :120-257, interop rows :175-196, alphabetical.
- **`Test/SurfaceCoverage.cls`**: interop screen rows :226-250, with the 20.7 rows at :248-250.
- **`Test/Navigation.cls`**:
  - :539 asserts `22`;
  - :540 is the order: position 0 first, by class name, then side-bar order;
  - :531-535 is the comment.
- **`Test/InteropFloor.cls`**: `OPERATORSCREENS` :53 and `ADMINISTRATORSCREENS` :62 (doc comments :47-61). `TestEveryOpenScreenMatchesItsClassicPage` :310.
- **`ui/tools/vendor-frame.test.mjs`** (238 lines):
  - `EDITORS`/`PARAMETER` :32-33;
  - the vocabulary deepEqual :51-60;
  - `'schema-viewer'` as a refused editor :91;
  - the `/ui/interop` scan :164-175;
  - the Renderer2 scan :212.
- **`interop-editor-frame.spec.ts`**: `{editor: 'schema-viewer'}` draws no frame (:130).
- **`interop-editor.page.spec.ts`**: `KINDS` :33-55, and the one-page test :155.
- **`ui/tools/interop-editor-store.test.mjs`**: 314 lines.
- **`ui/tools/navigation.test.mjs`**:
  - the ordered built-route roster :130-141, interop slice :371-401;
  - Productions name cell → items :772;
  - 20.7's pairing test :826-836.
- **`ui/tools/screen-mirror.test.mjs`**: `ownPrivileges` owners :2447-2478.
- **`ui/tools/strings.test.mjs`**:610-613: the bound is 3,400, and the next raise is due when the count is within 50 (Q3 ruling, :606-609). The count is 3,371 after 20.7.
- **`ui/browser/structural-walk.mjs`**:
  - `SOURCE_VIEWER_IDS` :87-95;
  - `SKIP` :101-129, with 20.7's `rules/document` entry at :126-128;
  - `needsId` :211-213 is true for every `viewer (source)`.
- **`ui/browser/interop-editor-spec.mjs`**:
  - `EDITOR_APPS` :48-52 (`prefix`, `segment`);
  - `assertSignedInSilently` :208, which reads `${EDITOR_API}v7/<ns>/<segment>/<document>`;
  - `assertSignOutEndsEditors` :373, whose key filter is `key.includes('_Editor-')` (:375);
  - `readEditorTokens` :154.
- **`ui/browser/interop-editors.browser-spec.mjs`**: 20.7's spec. It shows the per-spec `structural` helper (:229), the `SETTINGS` record and restore (:135), and the `runIris` fixtures.
- **`src/OcuPilot/Test/ProductionProbe.cls`**:
  - USER; `Create()` :163 and `AddItem(name, class, pool, enabled, setting, value)` :203;
  - `Remove()` :635, which also drops `^Ens.Configuration("csp","LastProduction")` when it names the probe;
  - `Gone()` :615 and `CheckOwn()` :155.
  - The browser specs reach it through `runIris`.

### Vendor (read only)

- **`irisui/ui/interop/schema-viewer/main.21f063f8a7b4829f.js`** (`schemaviewer-core-dbp-web` 0.1.1-683157):
  - The types are `zs="ASC X12"`, `aT="ASTM"` and `Xc="HL7 v2.x"`, and `schemaTypes=[zs,aT,Xc]`. Off IRIS for Health it is `[zs]`.
  - `ngOnInit` reads `$NAMESPACE` and `get("&ST")`.
  - `GO.updatedURLSub=new qe.t("")`. The header subscribes to it, so `updateURL("")` runs before `get("&ST")`.
  - It also reads and writes `&C`, `&S` and `&DT` through `pushState`.
  - The header template draws only the schema-type select. Its Import, Export, New and Delete buttons are defined, but the template never draws them.
- **`irisui/ui/interop/interop-editor/main.d66e459fccd7eab0.js`** (`interop-core-dbp-web` 1.14.1):
  - It reads `$PRODUCTION`, and has no `get("HOST")`.
  - `appPanels` are `prodConfig`, `rule`, `DTL`, `BPL`, `MV`, `T`, `Q`, `J` and `L`.
  - The panel menu offers Open Top, Open Bottom, Open Full, Open in New Tab and Hide.
  - `openEditor(t)` calls `window.open(<server>/ui/interop/<editor>/index.html?…, "_blank")`. Queue, Jobs and Log open `EnsPortal.*.zen` with `target=_new`.
- **Classic `RESOURCE` values:**
  - `EnsPortal.HL7.SchemaMain`, `EnsPortal.EDI.X12.SchemaMain` and `EnsPortal.EDI.ASTM.SchemaMain`: `%Ens_EDISchema:READ` (inherited; read on the instance).
  - `EnsPortal.ProductionConfig` and `EnsPortal.Productions`: `%Ens_ProductionConfig:READ`.
  - The vendor API's `readSchemas` is `$SYSTEM.Security.Check("%Ens_EDISchema","READ")` (`%Api.InteropEditors.Utils` :2894).

## Tasks & Acceptance

**Execution:**

- [ ] **Task 0 (re-anchor, no code).** If 20.16 has merged into this branch:
  - Re-read `interop-editor.page.ts`, `interop-editor.store.ts`, their tests, `strings.ts`'s interop editor keys, and EXPERIENCE.md :159, :604 and :856. Anchor this story's edits to what is there.
  - Show its `data-ocu-editor="agent"` line only for the three editor kinds (a kind flag). Pin that in the page spec.
  - If 20.16 has not merged, the lead routes one acceptance bullet to 20.16: "its agent line shows only on the rule, BPL and DTL editor kinds".
- [ ] `ui/src/app/core/vendor-frame.ts`:
  - Widen `InteropEditor` with `'schema-viewer' | 'interop-editor'`, and `InteropEditorTitleKey` with `'interopSchemaViewerTitle' | 'interopProductionDiagramTitle'`.
  - Add `'schema-viewer': {parameter: '', titleKey: 'interopSchemaViewerTitle'}` and `'interop-editor': {parameter: '$PRODUCTION', titleKey: 'interopProductionDiagramTitle'}`.
  - `interopEditorSource` answers `null` for a non-empty document when the entry's parameter is `''`.
  - The doc comment names both and the measured `&ST` reason in one sentence.
- [ ] `src/OcuPilot/Screen/Descriptor/Base.cls`: add `Parameter CLASSICPAGES = "";`. Its doc says these are further classic pages the screen replaces beyond `classicPage`: normalized class names, comma-separated, each one's custom resource unioned by `RequiredPairs` (AD-44).
- [ ] `src/OcuPilot/Screen/Gate.cls` `RequiredPairs`:
  - After the `ClassicPage` union, add `Set tPairs = ..WithClassicPages(tPairs, $Parameter(pDescriptor, "CLASSICPAGES"))`.
  - Extend the doc comment by one sentence.
  - Existing screens answer exactly as today.
- [ ] `src/OcuPilot/Screen/Access.cls` `ClassicResourceOf`: the custom resources of `ClassicPage` and of each `CLASSICPAGES` page, unique, joined by `SEPARATOR`.
- [ ] New `src/OcuPilot/Screen/Descriptor/InteropSchemaViewer.cls` and `InteropProductionDiagram.cls`.
  - Each doc comment names AD-63, AD-5 and AD-44 and the measured reason for its shape.
  - Both: area `interoperability`, archetype `viewer (source)`, `built` true, `refreshes` false, `scope` `namespace`, no read, table, actions or context fields, and three `promptGroupGettingStarted` prompts.

  | Key | Schema viewer | Configuration diagram |
  |---|---|---|
  | `route` | `interoperability/schema-viewer` | `interoperability/productions/diagram` |
  | `labelKey` | `interopSchemaViewerTitle` | `interopProductionDiagramTitle` |
  | `sideBarPosition` | 10 | 0 |
  | `privileges` | `%Ens_Portal:USE`, `%Ens_EDISchema:READ` | `%Ens_Portal:USE`, `%Ens_ProductionConfig:READ` |
  | `ownPrivileges` | `%Ens_EDISchema:READ` | `%Ens_ProductionConfig:READ` |
  | `entityType` | `""` | `production` |
  | `parentScope` | `""` | `interoperability/productions` |
  | `id` | `{kind: none}` | `{kind: single}` |
  | `emptyStateKey` | `""` | `interopProductionDiagramEmpty` |
  | `commandAliases` | `schema viewer`, `hl7 schemas`, `x12 schemas`, `astm schemas` | none |
  | prompts | `interopSchemaViewerPrompt1..3` | `interopProductionDiagramPrompt1..3` |
  | `classicPage` | `EnsPortal.HL7.SchemaMain` | `EnsPortal.ProductionConfig` |
  | `Parameter CLASSICPAGES` | `EnsPortal.EDI.X12.SchemaMain,EnsPortal.EDI.ASTM.SchemaMain` | - |
  | `toolIdentifier` | `interop.schemaviewer` | `interop.productiondiagram` |

- [ ] `ui/src/app/core/strings.ts` (add-only): the eleven literals in Design Notes › Strings. Then run `cd ui && node tools/screen-mirror.mjs`.
- [ ] EXPERIENCE.md:
  - :159: append " · Schema viewer (Story 20.8)" to the Interoperability side-bar list. After 20.7's sentence, add: "Schema viewer shows InterSystems' HL7 v2.x, ASC X12 and ASTM schema viewer in place, read-only; a Production items screen links its production's Configuration diagram, InterSystems' production configuration app in place, whose own editors open in new browser tabs (Story 20.8)."
  - :604: the eleven literals, with a Story 20.8 clause.
  - If `strings.test.mjs` is still bounded at 3,400, raise it to 3,800 and add one comment line (the Q3 rule).
  - Then run `cd ui && npm run test:tools`.
- [ ] `interop-editor.store.ts`:
  - `InteropEditorDeps` gains `extension` (default `DOCUMENT_EXTENSION`), and `list` may be `null`.
  - With `list` null, `read()` settles `open` with document `''` and sends nothing.
  - With `extension` `''`, it requires only a non-empty id, matches `Name === id`, and opens with `Name` as given.
  - `Coded` is unchanged.
  - The doc comment states the two modes in one sentence each.
- [ ] `interop-editor.page.ts`:
  - `EditorKind` gains `listFrom: 'document' | 'parent' | 'none'`, `extension` and `noteKey`. The three editors keep `document`, `.cls` and `interopEditorNote`.
  - `InteropSchemaViewer` maps to `{editor: 'schema-viewer', listFrom: 'none', noteKey: 'interopSchemaViewerNote'}`.
  - `InteropProductionDiagram` maps to `{editor: 'interop-editor', listFrom: 'parent', extension: '', noteKey: 'interopProductionDiagramNote'}`.
  - The constructor resolves the list by `listFrom`: `listForDocumentScreen`, `parentListFor`, or none. A `none` kind still builds its store.
  - The note reads `STRINGS[kind.noteKey]`.
  - Update the doc comment.
- [ ] `ui/src/app/shell/screen-outlet.ts`: two `DESCRIPTOR_PAGES` entries naming `INTEROP_EDITOR_PAGE`, after :229.
- [ ] `interop-item-list.page.ts`:
  - Above `<app-list-page />`, add `<nav class="ocu-interop-item-links">` with an `a.ocu-details-link` whose text is `interopProductionDiagramTitle`.
  - Its href is `withQuery` of `<diagram route>/<encodeEntityId(production)>`, the diagram route from `screenForDescriptor`. Click goes through `navigateByUrl`, as Task details' `onOpenHistory` does.
  - The nav is drawn only while `production` is non-empty and the diagram is declared. The host keeps the flex column.
- [ ] Client tests:
  - **`ui/tools/interop-editor-store.test.mjs`**:
    - no-list mode: opens with no request, Refresh bumps the revision;
    - `extension: ''`: a bare name opens, an absent one is gone, an empty id is gone, a stale answer is dropped.
  - **`interop-editor.page.spec.ts`**:
    - the schema viewer draws one frame with editor `schema-viewer` and no document, plus its note;
    - the diagram reads the parent list and draws `interop-editor` with the bare production name;
    - Refresh bumps both;
    - the editors' note is unchanged.
  - **`interop-editor-frame.spec.ts`**:
    - :130's refused example becomes `message-viewer`;
    - add draws for `schema-viewer` (title "Schema viewer") and `interop-editor` (src with `$PRODUCTION`).
  - **`ui/tools/vendor-frame.test.mjs`**:
    - the vocabulary is five entries with the parameters `rule`, `DTL`, `BP`, `''` and `$PRODUCTION`;
    - `schema-viewer` with a document is `null`, and without one ends at `$NAMESPACE`;
    - `$PRODUCTION` is encoded;
    - :91's refused example becomes `message-viewer`.
  - **`ui/tools/navigation.test.mjs`**:
    - the roster gains both routes;
    - add a 20.8 pairing test: `childListFor(Productions)` is Production items, `documentScreenFor(Productions)` is null, `detailScreenFor(Productions)` is null, and `parentListFor(diagram)` is Productions.
  - **`ui/tools/screen-mirror.test.mjs`**: both descriptors join the `ownPrivileges` owners, sorted.
- [ ] `src/OcuPilot/Test/InteropEditorDescriptor.cls` (extend; header gains one sentence):
  - **`TestTheViewerScreensRegister`**:
    - each declaration carries the table's values, and `Registry.Validate` passes;
    - each classic page equals `NormalizedPage("<page>.zen")`;
    - each `CLASSICPAGES` page normalizes to itself.
  - **`TestEachViewerClassicPageSharesTheScreensPair`**: each declared page's compiled `RESOURCE` names the screen's own pair.
  - **`TestTheSchemaViewerHonorsEveryClassicPage`**, through `OcuPilot.Test.ScreenGate`:
    - unarmed, `RequiredPairs` is the declared set;
    - armed with `^||OcuPilotGateClassic(<page>) = "OcuProbe208"` for each of the three pages in turn, it adds `OcuProbe208:USE`.
    - `Reset()` runs before and after.
- [ ] Rosters, each row named from the instance:
  - `StageTwoTools` `Elsewhere`: two rows, sorted.
  - `SurfaceCoverage`: two `<screen>` rows naming `InteropEditorDescriptor`'s `TestTheViewerScreensRegister`, with `corpus="one declaration test pins both Story 20.8 viewer screens in one loop"`.
  - `Navigation.cls`: 22 becomes 24. `productions/diagram` goes after `processes/document`, and `schema-viewer` goes last. The comment gains "Story 20.8".
  - `InteropFloor`: `InteropSchemaViewer` joins `ADMINISTRATORSCREENS`, and `InteropProductionDiagram` joins `OPERATORSCREENS`. Each doc comment gains one sentence.
- [ ] `ui/browser/structural-walk.mjs`:
  - `needsId` becomes `parentScope !== '' || (viewer archetype && screen.id.kind !== 'none')`. Grep for other callers first.
  - `SKIP` gains `interoperability/productions/diagram`: "HSCUSTOM holds no production, so the walk has no production to open; interop-viewers.browser-spec.mjs walks it on the probe production it creates".
- [ ] `ui/browser/interop-editor-spec.mjs`:
  - `EDITOR_APPS` gains `'schema-viewer': {prefix: 'Schema_Viewer', segment: 'schemas'}` and `'interop-editor': {prefix: 'Interop-Editors', segment: 'productions'}` (measured).
  - `assertSignOutEndsEditors`' key filter tests every `EDITOR_APPS` prefix followed by `-`.
- [ ] New `ui/browser/interop-viewers.browser-spec.mjs`. Its header follows 20.7's spec. `before` refuses `LIVE_CONTAINER` and requires readiness `installed`.
  - **Fixtures.** Through `runIris`:
    - `ProductionProbe.Create()`, then `AddItem("OcuPilotProbeRouter","EnsLib.MsgRouter.RoutingEngine",1,1,"BusinessRuleName","OcuPilotProbe.Interop.Rule")` and `AddItem("OcuPilotProbeBpl","EnsLib.Background.Process.ExportMessageSearch",1,1)`;
    - record USER's `^EnsPortal.Settings(<user>)` nodes and the highest `Ens.Message.Search` id.
  - **`after`**:
    - restore those nodes;
    - delete the `Ens.Message.Search` rows above the recorded id;
    - kill `^Ens.Message.SearchD` if it was undefined before and holds no row;
    - `Remove()`, and assert `Gone()`.
  - Each test signs in its own context, waits for `waitForMapAnswered`, and carries its mutation comment. The tests are AC1 to AC6.
- [ ] **Roster sweep (Rule 30).** Search `src/OcuPilot/Test`, `ui/tools`, `ui/browser` and the `ui/src` specs for:
  - the Interoperability screen count or order, or its side-bar entries;
  - the `INTEROP_EDITORS` keys, or `'schema-viewer'` as an out-of-vocabulary example;
  - `EDITOR_APPS`;
  - `_Editor-`;
  - `needsId`;
  - the Production items page's DOM.

  Each changed file joins the `(loop)` set.

**Acceptance Criteria:**

- **AC1 (the schema browsers, in place, read-only).**
  - **Given** the signed-in shell on `ocupilot-b-ci`, scoped to HSCUSTOM.
  - **When** the person opens Interoperability › Schema viewer, then picks HL7 v2.x and ASTM in the viewer's own schema list.
  - **Then:**
    - the route is `interoperability/schema-viewer`;
    - one `app-interop-editor-frame iframe` is drawn, with src `interopEditorSource('schema-viewer', 'HSCUSTOM')`;
    - `assertSignedInSilently` holds;
    - ASC X12, HL7 v2.x and ASTM each list as many categories as the instance's schema global holds;
    - apart from the empty-body login, every request the frame makes is a GET;
    - no message reaches the shell or the frame;
    - at 1280×900 the frame fills its host (±1 px) and is at least 400 px tall;
    - `structural` finds no fresh entry at 1280 light, 720 light or 1280 dark, and the walk opens the screen.
- **AC2 (the document-selection parameter, established).**
  - **Given** the builder, and a harness frame at the classic schema pages' own address, `?%24NAMESPACE=HSCUSTOM&%26ST=HL7+v2.x`.
  - **When** the builder is asked for the schema viewer with a document, and the harness frame loads.
  - **Then** the builder answers `null`. The harness frame shows ASC X12, and its address ends `&%26ST=`.
  - The test header says that a red here means the vendor now honors `&ST`.
- **AC3 (the diagram, in place).**
  - **Given** the probe production in USER.
  - **When** the person opens its Production items screen and chooses Configuration diagram.
  - **Then:**
    - the route is `interoperability/productions/diagram/OcuPilotProbe.Interop.Production`;
    - one frame, with src `interopEditorSource('interop-editor', 'USER', 'OcuPilotProbe.Interop.Production')`;
    - `assertSignedInSilently` holds with `documentStatus: 200`;
    - the frame shows the four probe item names;
    - the box clause of AC1 holds;
    - the locator links to Productions;
    - `structural` finds no fresh entry in the three themes.
  - **And** from the Productions list, the probe row's name cell still opens Production items.
- **AC4 (its sibling editors open in new tabs).**
  - **Given** the probe production's diagram screen and a handle on its frame element.
  - **When** the person chooses BPL Editor's panel menu › Open in New Tab.
  - **Then:**
    - a new browser tab opens at `/ui/interop/bpl-editor/index.html?$NAMESPACE=USER&BP=…`;
    - it holds its own `BPL_Editor-` keys, and an `ocupilot.token-pair` equal to the shell's;
    - the shell's URL is unchanged;
    - the handle is still connected, with the same src.
  - **And when** the person signs out in the shell, **then** `POST /api/ocupilot/refresh` with that copy's refresh token in the JSON body answers 401.
- **AC5 (gone and Refresh).**
  - **Given** `interoperability/productions/diagram/OcuPilotProbe.Interop.Absent`, **then** there is no frame, no request under `/ui/interop/` or `/api/interop-editors/`, and the screen shows "This production no longer exists."
  - **Given** either screen open, **when** the person chooses Refresh, **then** the old element is detached and a new one carries the same src.
- **AC6 (sign-out on the real screens).**
  - **Given** each screen, signed in, with the app's held tokens.
  - **When** the person signs out from the account menu.
  - **Then** `assertSignOutEndsEditors` holds.
- **AC7 (declared, gated, rostered).**
  - **Given** the two descriptors.
  - **When** the instance validates them and the build regenerates the mirror.
  - **Then:**
    - each carries the table's values;
    - the Interoperability navigation carries 24 screens in the pinned order;
    - the Productions name cell still pairs with Production items;
    - each screen is in the `Elsewhere` block, which reddens alone when a row is removed;
    - `InteropFloor` shows the Administrator opening both, the Operator opening the diagram and not the schema viewer, and the Monitor opening neither;
    - `RequiredPairs` for the schema viewer adds a custom resource assigned to any of its three classic pages.

## Spec Change Log

- 2026-10-13, spec gate (runner): the Design Notes' Rule 20 drafts are written (AD-63 item 1 and its named consequence, AD-44's screens that replace several classic pages, AD-64 item 2, EXPERIENCE.md :856). The `&ST` behavior is DW-2396, a vendor candidate under the owner's hold (not reported). The `multiple-goals` warning is accepted: both screens share the frame, page and store and are about one story's size. Story 20.16 implements before this story, so Task 0 re-anchors on it.

## Review Triage Log

### 2026-10-14 — Review pass

- verdicts: 20 findings — high 0, medium 5, low 4, false 11, maybe-false 0
- findings:
  - `[medium]` `[patch]` Screen permissions builds `classic` as `${ClassicResource}:USE`, so a screen whose classic pages carry two custom resources shows `A, B:USE` — confirmed at `screen-permissions.page.ts` `openTarget`: the column is now comma-joined (`Access.ClassicResourceOf`) and the page appended one permission to the whole string. Fixed: each resource gets its own `:USE`; page spec row added.
  - `[medium]` `[patch]` Production items page has no component spec; the `NavigationEnd` signal, the href, the modified click and the bare-route case are unpinned (browser AC3 clicks once on a fresh mount) — confirmed: no spec named the page. Fixed: `interop-item-list.page.spec.ts` (5 tests), each leg mutated red.
  - `[false]` `[reject]` AC2's vendor tripwire is green because of the vendor defect it guards — the spec and the dispatch name it a deliberate tripwire; the builder clause carries a recorded mutation, and the harness clause is shown live by the in-test control.
  - `[low]` `[patch]` Mutation claims in test headers that the observed list did not record — each was applied and observed red (store `settle`, `agentNote`, vocabulary parameters, store modes, descriptor own pair and `CLASSICPAGES`), recorded in `## Verification`; the frame spec's header was corrected to the leg that reddens.
  - `[low]` `[reject]` AC7's Operator/Monitor legs, the 24-screen order and AC1's GET-only, box and count clauses have no recorded mutation — Rule 19 asks one demonstrated mutation per AC, and AC1 has two and AC7 has five.
  - `[low]` `[reject]` AC1's `read.length > 0` for ASC X12 is met by the initial load — the per-family claim is carried by the `until` on the category count, and HL7 v2.x and ASTM are read only after being chosen; nothing a user meets.
  - `[medium]` `[patch]` `panelMenuEntry` queries the app's panel bar once, with no wait — confirmed against Rule 19 (acts before the system signals it is ready). Fixed: it waits for the bar (`waitForFunction`) before it clicks.
  - `[false]` `[reject]` AC5's gone leg assumes `OcuPilotProbe.Interop.Absent` is absent — a production by that name would draw a frame and redden the test, so it cannot pass vacuously; `before` creates no such production.
  - `[medium]` `[patch]` The dialog names a malformed pair for two custom resources (restates the first finding) — same fix; the dialog input's doc comment now says the value holds each resource as a pair.
  - `[false]` `[reject]` `Access.ClassicResourceOf` reaches beyond the intent's surfaces — Tasks & Acceptance names the edit and AC7 names the Screen permissions column.
  - `[low]` `[reject]` `InteropFloor.TestEveryOpenScreenMatchesItsClassicPage` reads only `classicPage` — `TestEachViewerClassicPageSharesTheScreensPair` pins all three pages' `RESOURCE` against the screen's own pair.
  - `[medium]` `[patch]` The Items link has no component spec (restates the second finding) — same fix.
  - `[false]` `[reject]` Namespace move, Refused and Fault have no live leg — the spec's ACs pin live legs for Gone, Refresh and Sign out; the page spec pins the rest against the real template.
  - `[false]` `[reject]` The Schema viewer's gate refusal is covered by server rosters — AC7 names exactly those rosters, and the screen has no client refusal to render.
  - `[false]` `[reject]` The gate union is tested through `ScreenGate`'s stand-in — the spec names that seam; the real `%SetCustomResource` leg is `ScreenAccessWire`.
  - `[false]` `[reject]` AC4 asserts OcuPilot's pair copy and not the tab's own `BPL_Editor-*` tokens — the matrix says "its copy of the tab's pair is revoked".
  - `[false]` `[reject]` The sandbox mutation is labeled inference — the spec labels it so, as the prose rules ask.
  - `[false]` `[reject]` An agent class save never reloads the diagram — `shows()` matches the route id against the event's id, the intent names no such trigger, and the agent line is not drawn there.
  - `[false]` `[reject]` Read-only has no code counterpart — the intent measures it as a vendor fact and forbids the parameters that would change it.
  - `[false]` `[reject]` Vendor behavior is pinned only by the browser spec — Rule 3 asks for that real-runtime evidence.

## Design Notes

**Governing ADs:**

- **AD-63**: all five limits and its named consequence (Rule 20 drafts below).
- **AD-47**, **AD-28** and **NFR-3**: the origin, the policy and the sign-out are unchanged. AC4 pins the tab copy's revocation.
- **AD-62**: item 1 (no `%Api.InteropEditors` call by OcuPilot) and item 3.
- **AD-5**: two descriptors; one shared loader; the diagram issues the Productions list's read; adding a screen is a descriptor.
- **AD-44**: classic pages, with one screen honoring three.
- **AD-64**: `RequiredPairs` stays the one reader. Both screens are adjustable.
- **AD-8**: pairs, and narrower audiences.
- **AD-13**: the production id is one segment.
- **AD-16**, **AD-19** (framework-free store), **AD-20** (one absolute read) and **AD-21** (no path from text).
- **AD-24**: no context field. The diagram's route id reaches context as `id`.
- **AD-11**: `src` through `Renderer2`.

Checked and not engaged:

- AD-10, AD-15, AD-22 and AD-53: no write, tool or key.
- AD-30: it governs OcuPilot's write tools.
- AD-29 and AD-36: no new read or SQL.
- AD-43: Refresh is manual.

**Measured at this plan on `ocupilot-b-ci` (2026-10-13).** Frames were harness-mounted in the signed-in shell, and the probe acted as the person. Every probe was removed afterwards and verified: the production, twelve `Ens.Message.Search` rows and their id counter. `^EnsPortal.Settings` and `LastProduction` were unchanged.

- **Schema viewer:**
  - **`&ST` is ignored.** Ten address forms were tried: `%26ST` with each family, none, bare `ST`, a bogus value, `+` encoding, `&C`/`&S`/`&DT`, and USER. Each was tried framed, and three of them also at top level, including the classic pages' exact form. Every one opened on ASC X12.
  - A `pushState` trace shows the namespace write keeping `&ST`. Then `updateSelectedSchemaSub("")` pushes `&%26ST=`, and only after that does the header read `&ST`.
  - **Requests:** the empty-body login (200), `info`, `session/language`, `system-mode` and `schemas/X12/categories`.
  - Picking HL7 v2.x through its own list added `schemas/HL7/categories`. HSCUSTOM holds 14 HL7, 5 X12 and 1 ASTM categories. Opening HL7 2.5 listed its structures.
  - **No writes:** no request besides the login was a write, and no message reached the shell or the frame.
  - **Controls:** the header draws no Import, Export, New or Delete control.
  - **Keys and history:** its keys are `Schema_Viewer-0-*`. History grows by 1 on load and by 1 per choice.
- **Diagram (probe production in USER, with an operation, a service, a routing engine and a BPL item):**
  - **`$PRODUCTION`:** `$PRODUCTION=<class>` gives `GET …/productions/<class>` 200, and the production is drawn with its items and Save. An absent class answers 404 and draws no production. No `$PRODUCTION` draws no production, with the app's own Productions panel.
  - **`HOST`** stays in the address, and the requests match the load without it.
  - **Keys and history:** its keys are `Interop-Editors-0-*`. History grows by 3 per load.
  - **Server state:** each load stores one `Ens.Message.Search` row for the user, through its message panel's `POST …/messages` search.
  - **Open in New Tab:** BPL Editor's menu called `window.open('/ui/interop/bpl-editor/index.html?$NAMESPACE=USER&BP=', '_blank')`. The new tab had `window.opener`, `BPL_Editor-0-*` keys and an `ocupilot.token-pair` key. The shell's URL and the frame were unchanged.
  - No message and no dialog.
- **Roles:**
  - `%EnsRole_Administrator` holds `%Ens_EDISchema:R`.
  - `%EnsRole_Operator` holds `%Ens_Portal:U` and `%Ens_ProductionConfig:R`, and no `%Ens_EDISchema`.
  - `%EnsRole_Monitor` holds neither.
  - `%EnsRole_WebDeveloper` holds `%Ens_EDISchema:RW`.
- **`NormalizePage`** answers each `.zen` page's class name.

**Decisions:**

- **One schema screen, not three.** The viewer cannot be opened on a family by URL in this build, so three screens would each open on ASC X12 under an HL7 or ASTM label. The one screen shows the three browsers through the viewer's own list, which is the AC's "through the embedded viewer".
  - *Rejected, passing `&ST` for later builds:* it is dead today, and it would put an untested parameter in the vocabulary. AC2's tripwire says when to add it.
  - *Rejected, OcuPilot-built schema browsers through `InteropPort`:* the AC asks for the embedded viewer.
- **AD-44 on a screen with three classic pages.** A custom resource on any of the three pages gates the screen, because the viewer shows all three families. `CLASSICPAGES` and `WithClassicPages` are the write tools' mechanism, extended to a descriptor class.
  - *Rejected, declaring HL7's page alone:* it ignores the other two pages' custom resources, against AD-44.
- **The diagram's place.**
  - **Parent-scoped and unlisted, under Productions.** Its id is a production, and its locator returns to Productions.
  - **Opened from a link on Production items**, the screen that already replaces `EnsPortal.ProductionConfig`, by Task details' sibling-link pattern.
  - **Archetype `viewer (source)`, not `detail`.** `detailScreenFor` precedes `childListFor` in the name-cell chain and would take Productions' link. As a child list it sorts after `InteropItemList`, and AC3 and the navigation pairing test pin that.
  - *Rejected, `interoperability/productions/document`:* `documentScreenFor` would move the Productions name cell off Production items, 20.3's behavior.
  - *Rejected, a listed screen with no production:* the app opens empty, and the screen would name nothing.
- **Sibling editors.**
  - **OcuPilot does not control them.** The app opens them through its own `window.open(..., "_blank")`, or as panels inside the frame. OcuPilot can neither redirect them (AD-63 limit 3) nor block them (limit 5).
  - **They stay as the vendor built them.** A new tab is the vendor's standalone editor, signed in from the browser-level login, holding a copy of the pair that sign-out revokes (AD-63's existing consequence, pinned by AC4).
  - *Rejected, routing them to OcuPilot's own editor screens:* it needs a message channel AD-63 forbids.
- **Writes inside the diagram.** The person may change and save configuration, and start or stop the production, as themselves, through the vendor's API and its checks, as 20.7's editors save. OcuPilot's write path, governance and agent switches do not reach the frame (inference from AD-30's scope).
- **The vendor state the diagram creates.** Each load stores an `Ens.Message.Search` row for the person, as the app does from the classic portal. The browser spec removes its own rows.

**Rule 20 drafts (for the lead, at the spec gate):**

- **AD-63 item 1**, after "(`rule`, `DTL`, `BP`; Story 20.13, measured)": "the production configuration app's `$PRODUCTION`, and none for the schema viewer, whose `&ST` its own first address write clears before it is read, so it opens on ASC X12 (Story 20.8, measured)".
- **AD-63 named consequence**, a Story 20.8 clause: "Story 20.8's Schema viewer has no read, and its Configuration diagram draws a production only for a row the Productions list's read answers. The diagram app opens its sibling editors and the classic Queue, Jobs and Log pages in new browser tabs without `noopener`, or as panels inside the frame, and stores a message-search row for the person on each load (measured)."
- **AD-44**, a Story 20.8 clause: "A screen that replaces more than one classic page names the further pages in its descriptor class's `CLASSICPAGES`, as a write tool does, and `Screen.Gate.RequiredPairs` unions each one's custom resource. The Schema viewer declares `EnsPortal.HL7.SchemaMain` and names `EnsPortal.EDI.X12.SchemaMain` and `EnsPortal.EDI.ASTM.SchemaMain`. The Configuration diagram declares `EnsPortal.ProductionConfig`."
- **AD-64 item 2**: "then unions the classic page's custom resource (AD-44)" becomes "then unions the custom resource of each classic page the screen replaces (AD-44)".
- **EXPERIENCE.md :856**, appended: "the Schema viewer (Story 20.8) is a `viewer (source)` screen with no read: it shows no skeleton, empty sentence or refusal of its own, and refreshing is Refresh; the Configuration diagram behaves as the Interoperability editors, with its 'no longer exists' sentence."

**Strings (eleven literals, add-only):**

- `interopSchemaViewerTitle` "Schema viewer"
- `interopSchemaViewerNote` "The viewer opens on ASC X12; choose another schema type from its list."
- `interopSchemaViewerPrompt1..3`:
  - "Which HL7 v2.x schema categories does this namespace hold?"
  - "Which segments make up an HL7 2.5 ADT_A01 message?"
  - "How do I add a custom HL7 schema category?"
- `interopProductionDiagramTitle` "Configuration diagram"
- `interopProductionDiagramEmpty` "This production no longer exists."
- `interopProductionDiagramNote` "Leaving this screen, or choosing Refresh to open the production again, discards any change not saved in the diagram."
- `interopProductionDiagramPrompt1..3`:
  - "How do messages flow through this production?"
  - "Which items in this production are disabled?"
  - "Which business operations does this production send to?"

Each value was checked unique against `strings.ts`. The labels double as the frame titles and the Items link text.

**Weight.** The page and store chunk grows by about 1 kB, and the Items page's chunk by less (inference). The initial bundle gains the strings and two mirror entries, about 3 kB (inference), against about 1.91 MB and `maximumWarning` 1992kB. No page becomes eager.

**Integration, Consumes, Consumed-by (Rules 1 and 2):**

- **Integration:** the two screens consume the builder, frame, page, store and browser helpers against the real instance (AC1, AC3 to AC6). `CLASSICPAGES` on a descriptor is consumed in this story by `RequiredPairs` and Screen permissions (AC7).
- **Consumes:**
  - 20.13: `interopEditorSource`, `app-interop-editor-frame` and `interop-editor-spec.mjs`;
  - 20.7: the editor page, store and `revision`;
  - 20.2: the Productions read;
  - 20.3: Production items;
  - 20.29: the loader maps;
  - 18.14 and 9.8: the write tools' `CLASSICPAGES` and Task details' link.
- **Consumed-by:**
  - 20.9: the message viewer embed reuses the vocabulary and a page kind (inference);
  - 20.10: source control inside these frames;
  - 20.16: the per-kind agent line (Task 0).

**Ledger inbox (Rule 17):** none.

**Rule 31 (extend, don't copy):**

- The vocabulary, frame, page, store, `EDITOR_APPS`, `assertSignOutEndsEditors`, `InteropEditorDescriptor`, `WithClassicPages` and the `ScreenGate` seam are each extended, not copied.
- The Items link copies Task details' link shape. It is twelve lines in another area's page, and there is no shared link component to extend.
- The browser spec keeps the per-spec `structural` helper, the convention 20.7 follows.

**Contended files (Rule 11).** `origin/OCU-1-epic18` (`ad0fb51f`) is an ancestor of this branch.

- Epic 18's local head touches the spine, EXPERIENCE.md :379, `Test/Descriptor.cls` and `strings.ts` near :1306.
- This story adds to `strings.ts` and EXPERIENCE.md :159 and :604. It adds rows to `StageTwoTools` and `SurfaceCoverage`, and lines to `screen-outlet.ts`.
- `screens.generated.ts` is regenerated, and the spine is the lead's.
- No Rule 11 ask.
- Within this epic, 20.16 shares the page, store, strings and their tests. Task 0 orders it.

**Named limits:**

- The schema viewer opens on ASC X12 and names nothing on its screen. The person chooses the family inside it.
- The apps can move away unseen: their logo, Back to standard UI, namespace and production switches, and Back through the entries they push. Refresh opens the screen's own address again.
- Any OcuPilot navigation drops the diagram's unsaved changes without its alert. The note says so (DW-2376's ruling).
- A production beyond the read's 1,000 rows reads as gone.
- The Production items link is the diagram's only entry besides a typed URL or the agent.

## Verification

**Shared surfaces:**

- the Interoperability navigation roster: count, order and side bar (`Test/Navigation.cls`, `navigation.test.mjs`);
- the Productions name-cell pairing;
- `StageTwoTools`' `Elsewhere`, `SurfaceCoverage`'s screen rows, and `InteropFloor`'s `OPERATORSCREENS` and `ADMINISTRATORSCREENS`;
- `screen-mirror.test.mjs`'s `ownPrivileges` owners;
- the `INTEROP_EDITORS` vocabulary and its refused examples;
- `EDITOR_APPS` and the sign-out key filter;
- the structural walk's `needsId` and `SKIP`;
- `RequiredPairs` and Screen permissions' `ClassicResource` column;
- the Production items page's DOM;
- the strings table, its bound, and EXPERIENCE.md :159 and :604;
- the built-screen count Screen permissions derives (190);
- USER's `Ens.Message.Search` rows.

*Every test added or changed passes on a fresh environment, in either order.* The browser spec creates and removes its own probe production and rows, and restores USER's `^EnsPortal.Settings` nodes. The ObjectScript tests write nothing: the `ScreenGate` seam is process-private.

**Setup (slot B; never the dev instance `ocupilot-slot-b`):**

- **Load `src`:**
  1. Run `rsync -a --checksum --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-20/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`.
  2. In `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`, run `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)`.
- **Before any browser run:** `cd ui && npm run build && docker exec ocupilot-b-ci sh -c 'cd /durable/iris/csp/ocupilot && rm -rf ./*' && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`.

**Commands.** Run each in the foreground with `timeout: 600000`, one at a time. Read each class's result from `%UnitTest_Result`.

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.InteropEditorDescriptor --class OcuPilot.Test.StageTwoTools --class OcuPilot.Test.SurfaceCoverage --class OcuPilot.Test.Navigation --class OcuPilot.Test.InteropFloor`. Expected: green, about 15 s by `ci-timings.json`.
- `(loop)` the same runner with `OcuPilot.Test.Descriptor`, `OcuPilot.Test.CompileWithoutInterop`, `OcuPilot.Test.InteropFloorOwnPairs`, `OcuPilot.Test.ToolNavigate`, `OcuPilot.Test.ScreenAccessWire`, `OcuPilot.Test.ScreenAccessGate`, `OcuPilot.Test.ClassicPageGate`, and every class the sweep changes. Expected: green, about 65 s.
- `(loop)` `cd ui && npm run test:tools`, then `cd ui && npm run test:components`. Expected: green.
- `(loop)` `cd ui && npm run build -- --verbose`. Expected: the prebuild chain is green, every lazy chunk is under 88 kB, and the initial total is under 1992kB. Record both.
- `(loop)` `uv run scripts/check-objectscript.py <each changed .cls>` and `bash scripts/lint-docs.sh`. Expected: clean.
- `(loop)` `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/<file>`, one file per call, after the redeploy. Expected: green.
  - `interop-viewers.browser-spec.mjs`
  - `interop-editors.browser-spec.mjs`
  - `interop-editor-frame.browser-spec.mjs`
  - `interop-items.browser-spec.mjs`
  - `a11y-structural-invariants.browser-spec.mjs` (about 445 s)
- **Lead-owned (the runner's):** the full ObjectScript sweep, `cd ui && npm test`, `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`, and Rule 30's fresh check.
- **Left to CI:** the full browser suite.

**Planned pinning mutations (Rule 19).** Revert each one byte-identical. Reload, or rebuild and redeploy, before the next.

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | The page maps `InteropSchemaViewer` with `listFrom: 'document'` | The page spec, and the browser AC1 (no frame) |
| AC1 | `structural-walk.mjs` `needsId` restored to every `viewer (source)` | The walk fails the schema viewer as unresolved |
| AC2 | The builder appends `&%26ST=<document>` for `schema-viewer` | `vendor-frame.test.mjs`, and the browser AC2 builder clause |
| AC3 | The store requires `.cls` for every kind | The store test's bare-name row, and the browser AC3 (gone) |
| AC3 | `InteropProductionDiagram` declared `detail` | `navigation.test.mjs`'s 20.8 pairing test, and the browser AC3's Productions clause |
| AC4 | The frame component sets `sandbox="allow-scripts allow-same-origin"` | The browser AC4: no tab opens, or the sign-in fails first (inference) |
| AC5 | The store opens a row the read did not return | The store test, and the browser AC5 gone leg |
| AC5 | The frame's `@for` tracks a constant key | The frame spec, and the browser Refresh leg |
| AC6 | `Session.signOut()` posts `/logout` with `credentials: 'omit'` | The browser AC6 for both screens (the app's login, access token and refresh token are not refused), and AC4's revoke clause |
| AC7 | One `Elsewhere` row removed | `StageTwoTools` `TestTheRosterAndElsewhereAreEveryRegisteredScreen`, alone |
| AC7 | `RequiredPairs` without the `CLASSICPAGES` line | `TestTheSchemaViewerHonorsEveryClassicPage` |
| AC7 | `%Ens_EDISchema:READ` dropped from the schema viewer | `InteropEditorDescriptor`, and `InteropFloor`'s Administrator roster |

**Mutations observed (Rule 19).** Each was applied, read red, and reverted byte-identical (`git status --short` and `git diff --stat` unchanged); ObjectScript was recompiled on `ocupilot-b-ci` and the bundle rebuilt and redeployed before each browser read.

- mutation: the page maps `InteropSchemaViewer` with `listFrom: 'document'` -> the page spec (3 tests) and browser AC1 (no frame: the frame wait times out).
- mutation: `needsId` restored to every `viewer (source)` -> browser AC1's walk clause ("opens the Schema viewer at its bare route").
- mutation: the builder appends `&%26ST=<document>` for `schema-viewer` -> `vendor-frame.test.mjs`'s schema viewer test and browser AC2's builder clause. The vendor tripwire (a harness frame at `&%26ST=HL7+v2.x` opens on ASC X12) cannot be reddened from here; its read is shown live by choosing HL7 v2.x in the harness frame's own list.
- mutation: the store requires `.cls` for every kind -> the store test's two bare-name tests and browser AC3 (no frame at the builder's address).
- mutation: `InteropProductionDiagram` declared `detail` (mirror regenerated) -> `navigation.test.mjs`'s 20.8 pairing test and browser AC3 (the name cell opens the diagram, so `openItems` times out).
- mutation: the frame component sets `sandbox="allow-scripts allow-same-origin"` -> browser AC4 times out before a tab opens (inference: the app does not sign in under a sandbox).
- mutation: the store opens a row the read did not return -> the store test (6 tests) and browser AC5's gone leg.
- mutation: the frame's `@for` tracks `$index` -> the frame spec (4 tests) and both of browser AC5's Refresh legs.
- mutation: `Session.signOut()` posts `/logout` with `credentials: 'omit'` -> browser AC6 on both screens. AC4's revoke clause stays green under it, because the Bearer alone revokes OcuPilot's pair; that clause is shown live by removing the sign-out step from the test (the copy's refresh answers 200, not 401).
- mutation: one `Elsewhere` row removed -> `StageTwoTools` `TestTheRosterAndElsewhereAreEveryRegisteredScreen`, alone (1 of 4).
- mutation: `RequiredPairs` without the `CLASSICPAGES` line -> `TestTheSchemaViewerHonorsEveryClassicPage` (the X12 and ASTM legs).
- mutation: `%Ens_EDISchema:READ` dropped from the schema viewer -> `InteropEditorDescriptor` (3 of 5) and `InteropFloor` (2 of 7, the Administrator roster among them).
- mutation: `Access.ClassicResourceOf` reads only `classicPage`, or drops its duplicate test -> `ScreenAccessWire` `TestTheSchemaViewersRowNamesTheResourceOfEveryClassicPage`.
- mutation: `parentIdSegment` answers `''` -> `navigation.test.mjs` (2 tests) and the page spec's diagram tests (6).
- mutation: the Items link's click does not navigate -> browser AC3.
- mutation: the store's `settle` stops bumping the revision on `open` -> the page spec (5: Refresh, the change reload, and 20.8's two Refresh tests) and the store test (7).
- mutation: `VIEWER` maps `agentNote: true` -> the page spec (3, the agent-line test among them).
- mutation: the vocabulary gives `schema-viewer` the parameter `ST` -> `vendor-frame.test.mjs` (2) and the frame spec's refused-source test; the diagram's parameter renamed -> `vendor-frame.test.mjs` (4) and the frame spec's 20.8 draw test.
- mutation: the store reads a list when it has none -> the store test's no-list row. The page spec cannot show it: the unguarded read does not type-check.
- mutation: the store requires `.cls` whatever the extension -> the store test (2) and the page spec's diagram tests (6).
- mutation: the store opens a row the read did not return -> the store test (6) and the page spec (6).
- mutation: the Items page's link omits the production id (3), ignores `NavigationEnd` (the move leg), ignores modifier keys (the click leg) or is drawn whatever the route names (the bare-route leg) -> `interop-item-list.page.spec.ts`.
- mutation: the Screen permissions page appends the permission to the whole `ClassicResource` column -> its two-resource test.
- mutation: the Schema viewer declares `%Ens_EDISchema:USE` as its own pair -> `InteropEditorDescriptor` (3 of 5); its `CLASSICPAGES` emptied -> `TestTheViewerScreensRegister` and `TestTheSchemaViewerHonorsEveryClassicPage` (2 of 5).
- mutation: AC4's test does not sign out in the shell -> the copy's refresh answers 200, not 401.
- (QA) mutation: `Screen.Gate.RequiredPairs` without its `CLASSICPAGES` line -> `InteropEditorDescriptor` `TestTheSchemaViewerHonorsEveryClassicPage` (the X12 and the ASTM leg, each at "added" and "at USE") and `ScreenAccessWire` `TestTheSchemaViewersRowNamesTheResourceOfEveryClassicPage` (Effective, with a real `%SetCustomResource`). The descriptor test now reads the third pair with `$ListGet`, so every page reports instead of the first red ending the loop.
- (QA) mutation: a viewer that honors `&ST`, simulated for AC2's harness frame by a scratch copy of the spec that answers the viewer's own `get("&ST")` with `HL7 v2.x` (`page.evaluateOnNewDocument`) -> browser AC2's chosen-type assertion (expected `ASC X12`, shown `HL7 v2.x`). The tripwire is live; the scratch copy is deleted.
- (QA) mutation: the page's `goneText` reads the rule editor's empty key (bundle rebuilt and redeployed) -> browser AC5's gone leg on the sentence, and the page spec (5 tests, the diagram's two among them).
- (QA) mutation: `restoreSearch` does nothing (scratch copy of the spec, AC3 alone) -> the `after` hook's "message-search store in USER is as it was" (`{data: 11, counter: '1', max: 1}` against `{data: 0, counter: '', max: 0}`). The leftover row was removed by hand.
- (QA) mutation: the store ignores a denied verdict, or does not refuse a 403 that names its pair -> the page spec's two "Requires <pair>" tests, each time; `refresh()` does nothing -> the page spec (8, the diagram's Retry and Refresh among them); the page ignores a namespace move -> the page spec (4, the Schema viewer's and the diagram's among them).
- (QA) mutation: `.ocu-interop-editor-frame` is 300 px tall (bundle rebuilt and redeployed) -> browser AC1 `assertFillsHost`; a scratch copy of the spec makes the viewer's frame send one POST -> browser AC1 "apart from its empty-body login, every request the frame made is a GET".
- (QA) mutation: the Schema viewer's `sideBarPosition` 10 becomes 3 -> `Navigation` `TestThePayloadCarriesEveryAreaWithAVerdict` (positions 17 to 24); the diagram's pair set names `%Ens_Code:READ` in place of `%Ens_ProductionConfig:READ` -> `InteropFloor` (2 of 7, the Operator roster among them).
- (QA) Every (QA) mutation was reverted byte-identical and recompiled, or rebuilt and redeployed. On the rebuilt `ocupilot-b-ci`, `InteropFloorTurn`, `InteropEditorSaveTurn` and `ExplorerSaveTurn` (1 test each, status 1 in `%UnitTest_Result`) and `screen-permissions-agent.browser-spec.mjs` (2) are green; `interop-viewers` is green whole (11) and with AC1, AC4 and AC6 each run alone. No test file was added; `InteropEditorDescriptor.cls` has one edited line.

**Measured.** `npm run build`: initial total 1.93 MB (warning 1992 kB), largest lazy chunk `data-browser-page` 83.33 kB (ceiling 88 kB), `interop-editor-page` 11.11 kB, `interop-item-list-page` 14.30 kB.

## Auto Run Result

Status: done
Blocking condition: none

**Implementation (2026-10-14).** Both screens draw through 20.7's page, store and frame. The client grows the vocabulary by `schema-viewer` and `interop-editor`, the store a no-list and a bare-name mode, and the page a kind table. `CLASSICPAGES` is read by `Gate.RequiredPairs` and Screen permissions. Production items links the diagram. The spec's Task 0 was applied: 20.16 had merged, and its agent line shows on the three editors only. One deviation: `parentIdSegment` in `core/navigation.ts` reads the diagram's route id, because `ownIdSegment` answers `''` for a parent-scoped screen.

- **Server:** `Screen/Descriptor/Base.cls`, `Screen/Gate.cls`, `Screen/Access.cls`, the two new descriptors.
- **Client:** `vendor-frame.ts`, `navigation.ts`, `strings.ts`, `screens.generated.ts`, `screen-outlet.ts`, the editor page and store, `interop-item-list.page.ts`, EXPERIENCE.md :159 and :604.
- **Tests:** the descriptor, roster and `ScreenAccessWire` classes; the page, frame and new Items page specs; the store, vendor-frame, navigation and mirror tests; `interop-viewers.browser-spec.mjs` and the two browser helpers.

**Review.** Twenty findings: 6 rows patched in 4 entries (three medium: Screen permissions' multi-resource column, the Items page spec, the panel-bar wait; one low: the mutation-claim cleanup), 14 rejected (11 false, 3 low; reasons in the log). Follow-up review recommended: true. The unreviewed risk is the lead-written Items page spec and the Screen permissions column change, which sit outside the story's declared footprint (report as `footprint_extensions`: `screen-permissions.page.ts`, its dialog comment and spec).

**Verification, all on `ocupilot-b-ci`.** The ObjectScript (loop) sets are green (12 classes; `InteropEditorDescriptor` rerun after the last mutation). `test:tools` 1997 and `test:components` 3120 after the review patches; the build prechain is green (initial 1.93 MB, largest lazy chunk 83.33 kB, `interop-editor-page` 11.11 kB); `check-objectscript` and `lint-docs` are clean. Browser specs green: `interop-viewers` (11) and `screen-permissions` after the review patches; `interop-editors`, `interop-editor-frame`, `interop-items` and `a11y-structural-invariants` before them. Every `mutation:` line in `## Verification` was applied, observed red and reverted byte-identical.

**Residual risks.** `InteropFloorTurn` fails on this throwaway with `PROVIDER.TLS`; `InteropEditorSaveTurn`, `ExplorerSaveTurn` and `screen-permissions-agent.browser-spec.mjs` fail in their turn the same way (inference). The throwaway was started before the 18.40 and 18.41 merge, and OcuPilot's provider TLS configuration is restored at start (inference). Re-run them on a fresh throwaway. The lead's full sweep, `npm test`, smoke and Rule 30 fresh check were not run. A subagent ran `pkill -f "Google Chrome for Testing"` once to clear its own orphaned Chrome, which could have ended another agent's browser.
