---
title: 'Story 19.3: The source editor, with ETag conflict detection'
type: 'feature'
created: '2026-10-02'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-19-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** System Explorer shows a class's or routine's source but cannot change it, so a one-line correction needs VS Code or Studio. The vendor's `PUT doc` re-creates a document deleted since it was read, and overwrites a concurrent change unless the save carries the version it read.

**Approach:** A full-page editor per document kind (`form-page`, at `<list route>/editor/:id`) loads the text through the viewer's declared read. Its Save sends the text and the version it read through the list's screen action route to an unadvertised write tool. `AtelierPort` puts the text with that version as the vendor's `If-None-Match` and refuses a changed version by name, never overwriting it.

## Boundaries & Constraints

**Always:**

- The version sent is the viewer's `document.modified`, seeded in process as `%request.CgiEnvs("HTTP_IF_NONE_MATCH")`. A save never sends `ignoreConflict`.
- AD-61's gate order holds before any vendor call: `%Development:USE`, then the namespace's read pairs, then WRITE on its routines database.
- The text's header (19.13's rule, `AtelierPort.Header`) must name the saved document exactly, and the text holds at most 3,000,000 characters.
- A document absent at the save is refused, never re-created.
- The text is a screen action value. It is never stored, logged or put in a tool schema, a proposal, screen context or the ledger. Compile lines reach the screen only (AD-39's fifth exception).
- `PROHIBITED.OCUPILOTCODE` refuses saving an `OcuPilot*` document, through the existing class/routine arm.
- Leaving with unsaved text asks "Leave without saving?", for a person's navigation and an agent's alike.
- New error codes go in `Api/AtelierError.cls`. Vendor text is logged and never sent.

**Never:**

- No third-party editor library. The editor is a monospaced `<textarea>` on the code surface, without highlighting.
- No agent caller for the save, pending the intent-gap decision in Design Notes: the tools are `ADVERTISED = 0`.
- No new Router route.
- No call to the `work` routes, no `docnames` `filter` and no `POST modified`.
- No creating a document from the editor.
- No client copy of the prohibited-set predicate (AD-10).
- No edit to `Kernel/Proposal/Prohibited.cls`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Save, unchanged since read | text, `version` = current ts | The text is stored. The answer carries `target`, the change event fires, the editor re-reads and shows "Saved" | None |
| Changed by another writer | `version` older than the current ts | 409 `EXPLORER.DOCUMENT.CONFLICT`, unlogged. The instance text is unchanged and the editor keeps the person's text | Banner shows the published sentence |
| Deleted since read | the document is absent | 404 `EXPLORER.DOCUMENT.ABSENT` (existing). Nothing is created | Banner |
| Locked by another process | vendor 423 (#5864) | 409 `EXPLORER.DOCUMENT.LOCKED`, unlogged. Nothing is written | Banner shows "Another process is editing this document." |
| Header names another document or kind | the first line names `Other.cls`, or `.mac` without `[Type=INC]` for an `.inc` | 422 `EXPLORER.SAVE.HEADER`, before any route | Banner |
| Text too long | more than 3,000,000 characters | 400 `EXPLORER.SAVE.TOOLARGE`, before any route | Banner |
| Vendor soft refusal | 200 with `result.status` holding an error (#16021, a source-control refusal) | 422 `EXPLORER.SAVE.REFUSED` with the vendor text logged; #5838, #5883 or #302 is 403 `PORT.ACCESSDENIED` | Banner |
| Saved and compiled | `Compile` "true" | `output {lines, errors}` in the output pane. A compile error does not undo the save | The pane lists the errors |
| `OcuPilot*` document | any save | 403 `PROHIBITED.OCUPILOTCODE`. Nothing is written | Banner shows the published sentence |
| No WRITE on the routines database | a `%Developer` in HSCUSTOM | Refused by name before any port call | Banner names the pair |
| Empty or unchanged text | | Save is drawn `aria-disabled`. The route refuses an empty value | None |

</intent-contract>

## Code Map

- `src/OcuPilot/Port/AtelierPort.cls`:
  - `Invoke` :519 sets the type flags `tSetType`/`tWrite` (~533-535), the served check (~554), and the DOCS/EXPORTDOCS/COMPILE/DELETE branches (~591-615).
  - `MinVersion` :461; `MINVERSIONS` :56 already holds `PutDoc:1`; `COMPOSEDTYPES` :115.
  - `SetNames` :841. `Docs` :876 takes `pNullKeys`, as EXPORTDOCS's `root,path` does. `PresentSet` :933 gives 404 ABSENT.
  - `Lines` :1295 and `Header` :1325 are 19.13's UDL header rule.
  - `ImportSet` :1499 is the precedent: the UDL `PutDoc` call at ~1541-1563, then `Compile` with `IMPORTCOMPILEFLAGS` `cuk` and `pSoft` 1.
  - `Route` :1913 only seeds `%request.Data`; it carries no header.
  - `Outcome` :2038 maps a 409 or 423 to a logged 500 `INTERNAL` today.
  - `SnippetForm` :2166 and `Snippet` :2183. `MAXIMPORTCHARACTERS` :148, `LOCKEDCODE` :197.
- `src/OcuPilot/Port/AtelierRequest.cls` is the JSON request stub. `CgiEnvs` is settable on it (measured).
- `src/OcuPilot/Api/AtelierError.cls` holds the code and reason pairs. 409 uses the CONFLICT slug, as `IMPORTCHANGED` does.
- `src/OcuPilot/Screen/Tool/ExplorerWrite.cls` is the abstract base:
  - parameters `PORTCLASS`, `READTYPE` DOCS, `SENDSBODY` 0, `READANSWERS`, `IDARGUMENT` Names;
  - `PrivilegePairs` :102 adds routines WRITE;
  - `PortQuery` :120;
  - `WriteOutput` :140.
- `src/OcuPilot/Screen/Tool/ExplorerImport.cls` is the template for `SCREENVALUES`, `ScreenActionDelta`, a closed `InputSchema` without `content`, `DESTRUCTIVE` 1 and a port-composed read type. `ExplorerClassImport.cls` is the 16-line concrete pattern.
- `src/OcuPilot/Screen/Tool/Base.cls:50` declares `ADVERTISED`. `Registry.ProviderTools`/`ResolveWire`/`Resolve` and `Screen/Context.cls` drop unadvertised tools, and `ScreenAction.ToolFor` keeps them.
- `src/OcuPilot/Api/ScreenAction.cls` is the AD-53 route (`POST /screens/:screen/action`):
  - `Values` (~480) takes exactly the declared names and refuses an empty value.
  - `Run` takes the AD-34 hold, the fresh read, the prohibited set, `Apply`, read-back and `output`.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` already judges the save. The class/routine branch (~1048-1055) runs `Code(tId)`, and the reason already says "replaced".
- `src/OcuPilot/Screen/Descriptor/ExplorerClassList.cls` and `ExplorerRoutineList.cls`: their `rowActions` gain `save`, declared and never drawn on the list (19.13's `import-local` precedent). `WalletSecretForm.cls` is the template for a `form-page` with no read and no classic page.
- `src/OcuPilot/Kernel/Governance/Baseline.cls` :143-150 holds the explorer lines; the last one has no comma.
- Client:
  - `ui/src/app/areas/system-explorer/document-viewer.store.ts`: `createSourceRead` :225 and `SourceDocument.modified`.
  - `document-viewer.page.ts`: header `<dl>` ~94-97; the text `<pre>` ~127.
  - `code-list.page.ts`/`.store.ts`: the output pane and `compileLinesOf`.
  - `ui/src/app/shell/screen-action-handler.ts`: `sendFor` :1136, `lastOutput`, `lastRefusal`.
  - `ui/src/app/core/form-dirty.ts`, with `os-management/mapping-form.page.ts` as the reference editor (bar ~200-212, guard dialog ~215-225, refusal banner ~313-322).
  - `ui/src/app/app.routes.ts:76-79` attaches `leaveFormGuard` to every `form-page`, and `shell/agent-navigator.ts` answers `NAV.REFUSEDUNSAVED` from it.
  - `ui/src/app/shell/screen-outlet.ts` `DESCRIPTOR_PAGES` :127.
  - `core/navigation.ts` :202 `EDITOR_ROUTE_SUFFIX` is `edit`. The editor avoids it, because `editorScreenFor` would turn the list's name cells into editor links.
  - `.ocu-source-text`, `.ocu-try-it-body` and `.ocu-form-bar` in `ui/src/styles/_components.scss`.

## Tasks & Acceptance

**Execution:**

- [ ] `src/OcuPilot/Port/AtelierPort.cls`:
  - Add `TYPESAVEDOCS` and `TYPESAVE`, and wire them through `Invoke`, `MinVersion` and `COMPOSEDTYPES`. SAVE joins `tWrite`, so it takes `WritePairs`. SAVEDOCS answers `Docs` with `content,version,Compile` as nulls.
  - Add `SaveSet`, in this order:
    1. one name;
    2. length ≤ `MAXIMPORTCHARACTERS`;
    3. `Header(Lines(content))` equal to the name;
    4. `PresentSet`;
    5. `Route PutDoc`, body `{enc:false, content}`, `pSoft` 1, the version as `If-None-Match`;
    6. then, when `Compile` is set, `Route Compile` (`cuk`, `pSoft` 1).

    It answers `{lines, errors}` only when compiled.
  - `Route` gains a trailing optional If-None-Match argument, which seeds `%request.CgiEnvs("HTTP_IF_NONE_MATCH")`.
  - `Outcome` maps `PutDoc` 409 to `DOCUMENTCONFLICT` and 423 to `DOCUMENTLOCKED`, both unlogged. An error under 200 that is not access-denied is `SAVEREFUSED`, logged.
  - `SnippetForm` and `Snippet` gain SAVE:
    - the namespace line;
    - `%Compiler.UDL.TextServices.SetTextFromString` for a class, or `%Routine` for a routine;
    - the text as the placeholder `"<content>"`, never the text;
    - and the `CompileList(name,"cuk")` line when `Compile` is set.
- [ ] `src/OcuPilot/Api/AtelierError.cls`: add `DOCUMENTCONFLICT`, `DOCUMENTLOCKED`, `SAVEHEADER`, `SAVETOOLARGE` and `SAVEREFUSED` with their reasons (Design Notes › Strings). `DOCUMENTLOCKED` reuses `DELETELOCKED`'s sentence.
- [ ] `src/OcuPilot/Screen/Tool/ExplorerSave.cls` (new, abstract, extends `ExplorerWrite`):
  - Parameters: `ADVERTISED` 0, `SCREENACTIONS` `save`, `SCREENVALUES` `save=content:version:Compile`, `READTYPE` SAVEDOCS, `WRITETYPE` SAVE, `DESTRUCTIVE` 1, `CHANGEACTION` `updated`, `PRECONDITIONFIELD` `Modified`.
  - `READANSWERS` and `FINGERPRINTSUBJECT` each hold `Modified,Absent,Namespace,content,version,Compile` (`READANSWERS` also holds `Present`).
  - Methods:
    - `SettableFields`;
    - a closed `InputSchema` of `Names` only;
    - `SetProblem`, which allows exactly one document;
    - `ScreenActionDelta`, which copies the three values with `Compile` as a boolean;
    - `PortQuery`;
    - `StateDiff`, with no rows.
  - `ExplorerClassSave.cls` (`explorer.classes.save`) and `ExplorerRoutineSave.cls` (`explorer.routines.save`) follow `ExplorerClassImport`'s 16-line pattern.
- [ ] `src/OcuPilot/Screen/Descriptor/ExplorerClassList.cls` and `ExplorerRoutineList.cls`: add the row action `{"id":"save","selfProtection":""}`.
- [ ] `src/OcuPilot/Screen/Descriptor/ExplorerClassEditor.cls` and `ExplorerRoutineEditor.cls` (new), modeled on `WalletSecretForm`:
  - routes `system-explorer/classes/editor` and `/routines/editor`;
  - `form-page`, `sideBarPosition` 0, `%Development:USE`;
  - entity type `class`/`routine`, scope `namespace`, id `single`;
  - no read, no table and no row actions; context `{fields:[], secretFields:[]}`;
  - `classicPage` `""` (no classic editor);
  - the viewer's three prompt keys;
  - `toolIdentifier` `explorer.classeditor`/`explorer.routineeditor`.
- [ ] `src/OcuPilot/Kernel/Governance/Baseline.cls`: insert `"explorer.classes.save": false,` and `"explorer.routines.save": false,` before the last line, so the edit is add-only.
- [ ] `src/OcuPilot/Test/AtelierPortSave.cls` (new): the port legs of the matrix on `USER` probe documents `OcuProbe193*` it creates and removes. They cover matching/stale/absent/locked/header/too large/soft refusal/compile, the conflict unlogged, the scripts, and the version gate through the version seam.
- [ ] `src/OcuPilot/Test/ExplorerSave.cls` (new), over HTTP:
  - the screen route saves and answers `target`;
  - a concurrent change is refused and kept;
  - `OCUPILOTCODE`;
  - the key reads `false` and a person's save still succeeds;
  - the unadvertised pin, restored from commit `b147b073`'s `AuditPurge.TestThePurgeIsAbsentFromEveryRosterTheAgentSees`: absent from `ProviderTools`, `ResolveWire`, `Resolve` default and `Context.ScreenTools`, present in `ListTools`, and a model call refused `TOOL.UNKNOWN` with no proposal.
- [ ] `src/OcuPilot/Test/AtelierPortWriteDenial.cls`: a save without routines WRITE is refused by name, using a purpose-built principal.
- [ ] Rosters (Design Notes › Rosters): update each literal the change trips.
- [ ] `ui/src/app/areas/system-explorer/source-editor.store.ts` and `source-editor.page.ts` (new):
  - The store issues `createSourceRead(<viewer>, name, 'udl')` and holds `{text, loaded, version, saving, saved, output, refusal}`. It calls `FormDirty.setDirty` when the text differs from what was loaded, and `sendFor(<list>, 'save', name, {content, version, Compile}, sink, scope)` on Save.
  - On success it clears dirty, shows `savedLine(readBack)`, shows the output lines, and re-reads to adopt the text and version together.
  - On refusal it keeps the text and shows the envelope's reason in an alert banner.
  - The page: the document name and "Last modified"; a `<textarea spellcheck="false" wrap="off">` styled as code-surface text, with an accessible name; the output `pre` with a polite status line; the sticky `ocu-form-bar` (status, "Compile after saving" checked by default, Cancel to the viewer, Save `aria-disabled` while empty, unchanged or saving); the `formLeaveWithoutSaving` dialog.
  - Tab keeps its browser meaning.
- [ ] `ui/src/app/areas/system-explorer/document-viewer.page.ts`: add an "Edit source" link to `<list route>/editor/<encoded id>?ns=` when the form is `udl`, the text is available and the name ends `.cls`, `.mac`, `.inc` or `.int`.
- [ ] `ui/src/app/shell/screen-outlet.ts`: add both editor descriptors to `DESCRIPTOR_PAGES`. Regenerate `screens.generated.ts` with `node tools/screen-mirror.mjs`.
- [ ] `ui/src/app/core/strings.ts`: add the new keys, each with `/** EXPERIENCE.md:593 */`, and move the one citation below :592 (`:2093`, `EXPERIENCE.md:633` → `:634`).
- [ ] `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`: add one Fixed-strings row after :592 for Story 19.3, usage condensed.
- [ ] Tests:
  - `ui/src/app/areas/system-explorer/source-editor.page.spec.ts`, a component spec covering dirty/guard, the disabled Save, success, refusal kept, and the output pane;
  - `ui/browser/system-explorer-editor.browser-spec.mjs`, the AC1-AC4 legs against `ocupilot-a2-ci`, where the "concurrent writer" changes the probe document through `OCUPILOT_BROWSER_CONTAINER`;
  - client rosters: `ui/tools/navigation.test.mjs`, `navigation-wire.test.mjs`, `rail-wire.spec.ts`, `screen-actions.test.mjs`, `self-protection.test.mjs` `ATELIER_REFUSALS`, and `strings.test.mjs`'s literal bound if it is passed.
- [ ] `ui/angular.json` and `ui/tools/angular-json.test.mjs`: rebase `maximumWarning` to the measured build (DW-1166), and stop to ask above 3,800 kB.

**Acceptance Criteria:**

- AC1: Given the class or routine editor opened on a document, when the person saves:
  - Then the request carries the version the editor read as the vendor's `If-None-Match`, the instance holds the new text, and the editor shows "Saved" with the re-read text.
  - And given another writer changed the document after it was read, the save is refused 409 `EXPLORER.DOCUMENT.CONFLICT`, the instance text is unchanged, and the person's text stays in the editor.
- AC2: Given the classic portal has no editor, when this ships, then each editor descriptor declares no classic page and the editor carries no classic link. It is new capability, not parity.
- AC3: Given unsaved text in the editor, when a person or an agent navigates away, then "Leave without saving?" is asked first. The agent's navigation settles `NAV.REFUSEDUNSAVED` unless the person leaves.
- AC4: Given "Compile after saving", when the save succeeds, then the compile's lines appear in the output pane, and they never reach the model, a tool result, a ledger row, a log line or screen context.
- AC5: Given a document deleted since it was read, a locked document, or a text whose header names another document, when the person saves, then the save is refused by name and nothing is created or replaced.
- AC6: Given an `OcuPilot*` document, or a caller without WRITE on the namespace's routines database, when the person saves, then the save is refused (`PROHIBITED.OCUPILOTCODE`, or the failed pair named) before any vendor write.
- AC7: Given the save tools, when the agent's rosters are read, then neither tool appears in the provider tool list, wire dispatch, name resolution or screen context, while their baseline keys read `false` and a person's Save still writes.
- AC8 (Integration, Rule 1): Given a saved document, when the person returns to the class viewer, then `SourceViewerPage` reads the saved text and the new "Last modified" through its own declared read on the real instance.


- **Note (scope).** FR-80 and Epic 19's preamble read toward an agent-authored save; that would be a later story if the owner asks (spec gate, option A, by=merge_gate 2026-10-02).

## Spec Change Log

- 2026-10-02, spec gate (orchestrator, by=merge_gate): option A, the save is screen-only (both tools unadvertised, keys `false`); the drafted spine amendments applied; the `strings.ts` citation shift and the `angular.json` budget line approved, re-checked at edit time (whoever lands second re-measures the budget).

## Review Triage Log

## Design Notes

**Decision required (intent gap; the reason this spec is `blocked`).**

- The tension:
  - Epic 19's preamble ("every write is a confirmed proposal") and FR-80 ("a confirmed write tool arrives with the screen") read toward an advertised save.
  - 19.2's Never ("the agent never authors code") and AD-36/19.1 (source text is screen-only, never in a tool's view) read against it.
- **A (recommended).** Screen-only:
  - `ADVERTISED = 0`, AD-53's named case revived; the key ships `false` and is moot for a person's own write (AD-22).
  - The agent keeps its read tools and 19.2's and 19.13's writes.
- **B.** Advertised:
  - `content` in the input schema (model-authored), a mint carrying a server-computed line diff on the card, the key disabled.
  - For the edit to be informed, it also needs a bounded source read for the model, which amends AD-36, AD-24 and AD-11/AD-60's surface. That is a separate story.
- Everything below is written for A. B would replace `ExplorerSave`'s schema, add a mint and card rows, and drop the restored unadvertised pin.

**Measured on `ocupilot-a2-ci`, 2026-10-02** (USER; `OcuProbe193*` created and all removed; `.cls`, `.mac`, `.inc` and `.int` each checked):

- The `GET doc` `ts`, its `ETag` header, the `action/index` `ts` (the viewer's `modified`) and the `docnames` `ts` are equal.
- `PUT` with `If-None-Match` matching answers 200 with a new `ts`.
- `PUT` with a stale value answers 409, `status.errors` empty, `result.content` the instance's current text, and the text unchanged.
- `PUT` with no `If-None-Match` on an existing document answers 409.
- `ignoreConflict=1` answers 200 and overwrites.
- A stale value on a document deleted since the read answers 201 and re-creates it.
- A lock held by another process answers 423 at once with `result.status` #5864, naming the user and pid; this is not sent.
- Junk text answers 200 with `result.status` #16021, and empty text 200 with #16022; in both, the text is unchanged and `ts` is `""`.
- Malformed UDL and uncompilable code are stored (200).
- A compile (`ck`, `cuk`) leaves the `ts` of a `.cls` and of a `.mac` unchanged.
- A save of identical text keeps the `ts`.
- A read-then-save round trip keeps the line count.
- In process, through `AtelierRequest` with `CgiEnvs("HTTP_IF_NONE_MATCH")` and `%Api.Atelier.v8.PutDoc`: stale 409, matching 200, absent 409. The epic context's inference is now a measurement.
- A class created without a package (`Class OcuProbe193A`) is stored as `User.OcuProbe193A`, and its version checks then compare against `""`. The header rule's exact-name check refuses it.

**ADs.** AD-5, AD-8, AD-10, AD-11 (rule 3), AD-13 (`documentset`), AD-14, AD-19, AD-22, AD-24, AD-34, AD-36, AD-39, AD-44, AD-51, AD-53, AD-55, AD-56 (ii), AD-58 (action-style verdict, inference), AD-59, AD-61.

- The save uses the screen action route, so it holds AD-34's target lock and is ordered with an OcuPilot compile or delete of the same single document (DW-1882 does not apply). A set's canonical id differs (inference).

**Spine amendments for the spec gate (draft).**

- AD-53's unadvertised named case (and AD-8's "none today") names `explorer.classes.save` and `explorer.routines.save`. AD-53's named gaps gain a twelfth: the Save writes with no vendor event (measured by 19.2).
- AD-61:
  - rule 1: the save is a write needing routines WRITE;
  - rule 3: a save seeds `HTTP_IF_NONE_MATCH` with the version read, and never sends `ignoreConflict`;
  - rule 6: `PutDoc` 409 is `EXPLORER.DOCUMENT.CONFLICT` and 423 is `EXPLORER.DOCUMENT.LOCKED`, neither logged. This also turns an import's 423 from a logged 500 into `LOCKED`.
- AD-51: Story 19.3's case, `SAVEDOCS`, and a `PutDoc` body built from the save's declared screen values.
- AD-10's code arm reads "replacing by import or by a save".
- AD-39's fifth exception gains a save's compile lines.
- AD-8's System Explorer paragraph adds the save beside compile, delete and import.

**Strings** (one row, :593):

- "Edit source", "Edit class", "Edit routine", "Compile after saving", "Text of <name>".
- "Someone else changed this document after you opened it, so it was not saved. Copy your changes, then reopen the document to see the current text."
- "The first line no longer names this document, so the text was not saved."
- "The text is longer than 3,000,000 characters, the most one save sends."
- "The instance refused this text, so nothing was saved."
- Reused: "Save", "Cancel", "Saved", "Leave without saving?", "Output", "Another process is editing this document.", and the code sentence.

**Consumes:** 19.1's viewer read and `modified`; 19.2's WRITE gate, `DOCS`, `output` and compile; 19.13's `Lines`/`Header` and its `PUT` path; `FormDirty`; `ScreenActionHandler`. **Consumed-by:** none planned. 19.4 may link a search hit to the editor (inference).

**Footprint (Rule 11).** Checked 2026-10-02 against `.worktrees/epic-18` at `2df15db5`, whose tree is clean.

- **Contended and add-only:**
  - `Baseline.cls` (insert before the last line);
  - `Test/ReadTool`, `ToolRoundTrip`, `Governance`, `GovernanceBaseline`, `SurfaceCoverage`, `ToolDispatch` and `ClassicPageGate` (the last two only if tripped), unioned at merge;
  - `screen-outlet.ts`;
  - `EXPERIENCE.md` (a row after :592; Epic 18 edits :164);
  - `navigation.test.mjs`, `navigation-wire.test.mjs` and `rail-wire.spec.ts`;
  - `screens.generated.ts`, regenerated and never hand-merged.
- **Contended and not add-only (lead approval):**
  - `strings.ts`: added keys, plus the one citation line :2093;
  - `angular.json` and `angular-json.test.mjs`: the budget value; Epic 18 set 2459kB;
  - the spine: the lead's amendments.
- **Not contended:** everything else, including `AtelierPort.cls` and `Prohibited.cls`, which is untouched.
- Re-check `git -C …/epic-18 diff` and `status -s` at edit time.

**Rosters a 19.3 change trips** (19.13's list applies; verify each at implement):

- `ExplorerDescriptor` (method name, tool and write rosters, baseline order, list actions + `save`, `DESCRIPTORS` + two editors);
- `ReadTool` (name roster and count);
- `SurfaceCoverage` (two tool rows, two screen rows);
- `ToolRoundTrip` `REFUSEEMPTY`;
- `GovernanceBaseline` `DISABLED`;
- `Governance` `EXPLORERDISABLED`;
- `ToolWrite` (COMPOSEDTYPES, the port count);
- `DraftRegistry` and `AtelierPortWrite` (`SnippetForm`);
- `Prohibited` :425;
- `DeveloperFloor` `SCREENS` + two editors (`TOOLS` is unchanged: the save needs WRITE);
- `ToolEmit` (`CodeResource():WRITE`);
- client: `self-protection.test.mjs` and `strings.test.mjs`.

## Verification

Load source into `ocupilot-a2-ci` without the MCP tools, and never restart it:

1. `rsync -a --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-19/src/ /tmp/ocupilot-a2-ci/src/`
2. In `docker exec -i ocupilot-a2-ci iris session iris -U HSCUSTOM`, run `$System.OBJ.LoadDir("/opt/ocupilot/src","ck",.tErrors,1)`, then check the status and `tErrors`.

**Run one test-runner call at a time, and wait for each to finish.** Never re-submit after a client-side timeout. Every `OcuProbe193*` document is removed afterwards.

**Commands:**

- `uv run scripts/check-objectscript.py && uv run scripts/test_check_objectscript.py` (loop). Expected: green.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-a2-ci --class OcuPilot.Test.<Class>` (loop), one class per call, for:
  - `AtelierPortSave`, `ExplorerSave`, `AtelierPortWriteDenial`, `AtelierPortWrite`, `AtelierPortTransfer`, `ExplorerDescriptor`, `ExplorerWrite`;
  - `ReadTool`, `ToolRoundTrip`, `SurfaceCoverage`, `DraftRegistry`, `GovernanceBaseline`, `Governance`, `ToolDispatch`, `ToolEmit`, `ToolWrite`, `Prohibited`, `DeveloperFloor`.

  Expected: green.
- `cd ui && npm run test:tools && npx ng test --include 'src/app/areas/system-explorer/**/*.spec.ts'` (loop). Expected: green.
- Browser (loop). Before each run, build and deploy: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-a2-ci:/durable/iris/csp/ocupilot/`. Then run each file alone with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52780 OCUPILOT_BROWSER_CONTAINER=ocupilot-a2-ci node --test --test-concurrency=1 browser/<file>`, for:
  - `system-explorer-editor.browser-spec.mjs`;
  - `system-explorer.browser-spec.mjs`;
  - `a11y-structural-invariants.browser-spec.mjs`.

  Expected: green. The full browser suite is CI's.
- `bash scripts/lint-docs.sh && cd ui && npm run test:tools` (loop, after any EXPERIENCE.md edit). Expected: green.
- `cd ui && npm test` (once, before dev_complete). Expected: green, with the bundle warning rebased.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-a2-ci`, the full ObjectScript sweep, one class at a time (once, before dev_complete). Expected: green apart from the residue 19.2 names.

**Planned mutations (Rule 19)**, one per AC. Record each as `mutation: <change> → <test that reddened>` once observed.

- AC1: the `CgiEnvs` seed dropped from `Route`, so the vendor sees no version → `AtelierPortSave` matching leg (a 409 where a 200 was expected). And `ignoreConflict` sent → the stale leg.
- AC2: `classicPage` set on `ExplorerClassEditor` → `ExplorerDescriptor`.
- AC3: `setDirty(true)` removed from the store → `source-editor.page.spec.ts` guard case.
- AC4: `output` dropped from `ExplorerSave`'s `WriteOutput` → `ExplorerSave` compile leg.
- AC5: `PresentSet` skipped in `SaveSet` → `AtelierPortSave` absent leg. The `Header` check made `If 0` → the header leg.
- AC6: SAVE removed from `tWrite` → `AtelierPortWriteDenial` save leg.
- AC7: `ADVERTISED` 1 → `ExplorerSave` unadvertised pin.
- AC8: the editor's re-read and change event removed → the `system-explorer-editor` browser leg.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

- The ETag path was measured on `ocupilot-a2-ci` (Design Notes). All probe documents were removed.
- Library check: no editor library is needed. A `<textarea>` meets both criteria. `highlight.js`'s `cos` grammar is already in `node_modules` and was left unused.
- Ledger inbox for this key: empty.
