---
title: 'Story 21.17: Global export and import'
type: 'feature'
created: '2026-11-15'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context: ['{project-root}/_bmad-output/implementation-artifacts/spec-21-5-globals-and-the-data-tools.md', '{project-root}/_bmad-output/implementation-artifacts/spec-19-13-xml-export-and-import.md']
warnings: ['oversized']
deferred:
  - summary: 'Story 19.13 import already loads a global from an XML file, and self-protection judges only the document name: an `oddDEF.GBL` or `rOBJ.GBL` holding `OcuPilot...` subscripts (written into OcuPilot''s database through the package mapping), or a `%`-global (written into IRISSYS), is not refused.'
    evidence: 'AtelierPort.Examine keeps every name xml/list answers, with no type filter; Prohibited.Code judges names by OwnNameStems only. Measured read-only on ocupilot 2026-11-15: 31 of the 37 globals in /durable/iris/mgr/ocupilot/ are code globals not named OcuPilot*; GetGlobalDest(HSCUSTOM, %SYS) is /durable/iris/mgr/. The write itself is unmeasured (inference).'
    location: 'src/OcuPilot/Port/AtelierPort.cls Examine; src/OcuPilot/Kernel/Proposal/Prohibited.cls Code / IsOcuPilotCode'
    severity: 'high'
  - summary: 'Story 19.13 import of a file that replaces an existing global reads its version from %RoutineMgr.GetDate, which answers the current time for any existing global, so the reviewed summary changes every second and the write refuses EXPLORER.IMPORT.CHANGED.'
    evidence: 'Measured read-only on ocupilot 2026-11-15: GetDate("ROUTINE.GBL") and GetDate("oddDEF.GBL") both equal $ZDT($H,3); a missing global answers -1. The refusal at the write is inferred from ImportSet''s summary comparison (inference).'
    location: 'src/OcuPilot/Port/AtelierPort.cls Examine / ImportSet; irissys/%Api/Atelier/v7.cls ListDocumentsInXMLFiles'
    severity: 'med'
---

<intent-contract>

## Intent

**Problem:** OcuPilot cannot export a global, and an import that replaces an existing global always refuses as changed (DW-2608), so a global cannot round-trip. The classic Globals page exports and imports globals.

**Approach:** Build on Story 21.5's `GlobalPort`, Globals list and `global` entity type, and reuse Story 19.13's export and import end to end. Two tools on `AtelierPort`, reached from the Globals list by the person and proposed by the agent (AD-53): `explorer.globals.export` exports one global, as the XML document `<name>.GBL`, to a server file or this browser; `explorer.globals.import` is 19.13's import from that list. Before the vendor's `ExportToStream` runs, `AtelierPort` reads the global's presence and size through two new `GlobalPort` reads. An import versions an existing global by a content digest from `GlobalPort` instead of `GetDate`.

## Boundaries & Constraints

**Always:**

- **One port per vendor API.** The XML routes stay `AtelierPort`'s (AD-61), under 19.13's AD-51 case (`EXPORTDOCS`, `EXPORT`, `IMPORTTARGET`, `PREVIEW`, `IMPORT`). OcuPilot's own reads of a global's nodes stay in `GlobalPort` (21.5), which `AtelierPort` reaches as it reaches `PathPort`; the vendor's XML routes read and load them inside `AtelierPort`, as for 19.13.
- **Bounded before the work (AD-36).** An export reads presence and size through `GlobalPort` at the fresh read and again at the write, before `ExportToXMLFile` runs. The size is the total characters of every node's `$Name` reference and value, root node included, walked in `$Query` order and stopped past the bound. The bound is `AtelierPort.MAXIMPORTCHARACTERS` (3,000,000), so whatever exports also imports. An export whose XML exceeds that bound, or whose answer exceeds the capture, writes nothing.
- **Version of an existing global (DW-2608).** For each `.gbl` document (any case) an import lists, `Examine` ignores the vendor's `ts`. It reads `GlobalPort`'s digest of the global in the import's namespace. An undefined global reads `<name> new`, and a defined one reads `<name> replaces sha256 <digest>`. The digest is SHA-256 over every node's reference, value length and value, UTF-8 encoded. A global over the bound refuses the preview and the write.
- **Self-protection (AD-10, unchanged text).** An export only reads and is not judged, as for classes and routines. The Globals list's import is judged exactly as 19.13's import, including 21.5's `.gbl` import clause.
- **Output (AD-39's fifth exception)** is 19.13's: export lines and import console lines reach the screen and the card only.
- **Governance (AD-22).** `explorer.globals.export` is not destructive, with key `true`. `explorer.globals.import` is destructive, with key `false`.

**Never:**

- No new AD entry, no new port, no new entity type, no new screen.
- No `.go`, `.gsa` or `.gof` format; the export is XML only.
- No change to 19.13's export or import behavior for classes and routines, except DW-2608's version of a `.gbl` document.
- No export of a set: one global per export. No `/mergeglobal`.
- No user-facing string beyond those the spec gate rules.

## I/O & Edge-Case Matrix

The routes are `POST /screens/explorer.globals/action` and `POST /proposal/:id/confirm`. The test's global is `^ZZOcuGlb<pid>`.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Export, server file | row `export`, values `{root, path}` | the file holds the vendor's XML of `ZZOcuGlb<pid>.GBL`; 200 `{root, path}` | `PATH.*`, `EXPLORER.EXPORT.DIRECTORY` as 19.13 |
| Export, this browser | row `export-browser` | `output {lines}`, saved as `<NAMESPACE>-export.xml` | as below |
| Agent export | `explorer.globals.export {Names, root, path}` | card `Documents` `ZZOcuGlb<pid>.GBL`; confirm writes the file | none |
| Missing global | the global is undefined | nothing exported; `ExportToXMLFile` is never called | 404 `GLOBAL.NOTFOUND` at mint, screen and confirm |
| Too large | node text above 3,000,000 characters; or XML above 3,000,000, or an answer above the capture | nothing written; in the first case no vendor call | 422 `GLOBAL.TOOLARGE` |
| Import, new global | Globals list `import` of a file holding an undefined global | summary `<name>.GBL new (sha256 …)`; loaded | none |
| Import replacing (DW-2608) | the same file, the global defined | summary `<name>.GBL replaces sha256 <digest> (sha256 …)`, equal across two previews a second apart; confirm loads it; the global equals the file's (Task 0 (a)) | none |
| Global moved | a node changed after the preview | nothing loaded | 409 `EXPLORER.IMPORT.CHANGED` |
| Existing global too large | the replaced global's node text above the bound | nothing loaded | 422 `GLOBAL.TOOLARGE` at preview and write |
| Code or `%` global | Globals list import of `oddDEP.GBL` or `%ZZOcuGlb<pid>.GBL` | nothing loaded | 409 `PROHIBITED.PROTECTEDGLOBAL` (21.5's clause) |
| Key off | agent's `explorer.globals.import`, default baseline | governance refusal; tool stays advertised | as every key-off write |

## Re-plan basis (2026-11-15)

Story 21.5 is planned (ready-for-dev, its spec final) and the owner allowed its AD-10 `PROHIBITED.PROTECTEDGLOBAL` arm with an import clause, now in the spine (owner answer U-59). Re-plan this story on 21.5's declared `GlobalPort`, Globals list (export as a row action), `global` entity type and the arm, reusing Story 19.13's export and import tools, server-file handling and dialogs. DW-2608 (routed here) is this story's to fix. Any new AD entry is not covered by an owner answer: if one is needed, HALT as an intent gap naming it.

</intent-contract>

## Code Map

**Precondition:** Story 21.5 is `done` on this branch. It provides `Port/GlobalPort.cls` (`Globals` endpoint, `ParseReference`, the name pattern, the `<PROTECT>` → 403 mapping), `Api/GlobalError.cls` (`GLOBAL.NOTFOUND`), `Screen/Descriptor/ExplorerGlobalList.cls`, the `global` entity type, and `Prohibited`'s `Global` arm with its `.gbl` import clause. Read them before Task 1. If any is missing, HALT.

- `src/OcuPilot/Port/AtelierPort.cls` (anchors as of `f348a9b00`):
  - `COMPOSEDTYPES` :388; `MAXIMPORTCHARACTERS` :429; `CAPTURECEILING` :543.
  - `Invoke` :874: `tSetType` :888, `tImportType` :889, `tServed` :911, the import branch :925, the set branch :948.
  - `MinVersion` :803 (already 7 for both type groups); `SetNames` :1758 (pattern by endpoint).
  - `Docs` :1793 and `PresentSet` :1850 (docnames; no globals); `PathPortClass` :1975 (the port-to-port precedent).
  - `CheckExport` :1984, `ExportFile` :2008, `ExportSet` :2033, `WholeLines` :2086, `WriteLines` :2104.
  - `Examine` :2313 (the `ts` read :2353), `Preview` :2401, `ImportSet` :2439 (summary compare :2454).
  - `Route` overflow :3110-3152; `SnippetForm` :3376.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls`: the class/routine branch :1543-1553 (export skip :1545, import via `ImportedNames` :1552); `EXPORTWRITETYPE` :796; `IMPORTTARGET` :803; `ImportedNames` :2844 takes each entry's first word, so the new entry form parses unchanged.
- `src/OcuPilot/Screen/Tool/`:
  - `ExplorerExport.cls` and `ExplorerExportMint.cls` (19.13's export; `IDARGUMENT` `Names`, `SetProblem` through `AtelierPort.SetNames`).
  - `ExplorerImport.cls` and `ExplorerImportMint.cls` (literal `import` id; `PREVIEW` in `ScreenActionDelta`).
  - `ExplorerClassExport.cls` and `ExplorerClassImport.cls` are a concrete tool's whole shape.
- **Vendor:** `irissys/%Api/Atelier/v7.cls`: `ExportToXMLFile` :171 runs `$SYSTEM.OBJ.ExportToStream` whole; `ListDocumentsInXMLFiles` :468 takes `ts` from `GetDate`. The classic `%CSP.UI.Portal.Dialog.Export` and `Import` serve the Globals page too (their headers). The classic export writes `.go`/`.gsa` files, not XML.
- **Client** (`ui/src/app/`):
  - `areas/system-explorer/code-list.page.ts`: action ids :38-44; registration :336-337; `onOpenExport` :541 over `checkedNames()` :649; `onExport` :566 and `onImport` :589.
  - `shell/screen-outlet.ts` :215 maps the server-criteria lists to `CodeListPage`.
  - `core/screen-actions.ts` :293-294 `DESCRIPTOR_ACTION_LABELS`.
  - `shell/data-table.ts` :948-980: the row menu acts on `store.selection()[0]`.
- **Tests to model on:** `src/OcuPilot/Test/ExplorerTransfer.cls` (424 lines; screen and agent legs, its probe directory through the `PROBE` class); `Test/AtelierPortTransfer.cls`; `ui/browser/system-explorer-transfer.browser-spec.mjs`.

## Tasks & Acceptance

**Task 0, on `ocupilot-ci` (implement stage, before code):** record each result under Design Notes and remove every probe global and file. Each item is (inference) until measured.

- (a) `xml/load` of a file holding `^ZZOcuGlb<pid>`, with flags `""` and `cuk`, replaces the global: a node absent from the file is gone afterwards.
- (b) `xml/list` names it `ZZOcuGlb<pid>.GBL`, with `ts` the current time when it is defined (DW-2608 reproduces: two previews a second apart differ).
- (c) `ExportToXMLFile` through `AtelierPort.Route` with `["ZZOcuGlb<pid>.GBL"]` answers its XML lines, and answers success with no `<Global>` for an undefined one.
- (d) The size of a many-short-node global at which the answer passes the capture ceiling.

**Batch 1, server (commit when its loop commands are green):**

- `src/OcuPilot/Port/GlobalPort.cls` (add-only) -- two `Globals` read types, gated as 21.5's reads, each a bounded `$Query` walk from the whole global (`ParseReference` of `^<name>`) in the target namespace: `SIZE` answers `{Name, Defined, Characters}`, refusing 404 `GLOBAL.NOTFOUND` when undefined and 422 `GLOBAL.TOOLARGE` past the bound; `DIGEST` answers `{Name, Defined, Digest}`, `Defined` 0 with `Digest` `""` when undefined, and 422 `GLOBAL.TOOLARGE` past the bound. One private walk serves both; write the digest input in batches of about 32,000 characters (measured 0.39 s for 3,000,000 characters, against 2.6 s writing node by node). The bound is `##class(OcuPilot.Port.AtelierPort).#MAXIMPORTCHARACTERS`.
- `src/OcuPilot/Api/GlobalError.cls` (add-only) -- `GLOBAL.TOOLARGE`, 422, with the ruled sentence.
- `src/OcuPilot/Port/AtelierPort.cls` -- `ENDPOINTGLOBALS` `Globals` and `GlobalPortClass()`:
  - `Invoke` serves `Globals` for `EXPORTDOCS`, `EXPORT` and the three import types only; every other type is 501.
  - `SetNames(Globals, …)` admits exactly one name matching `GlobalPort`'s pattern and answers `$ListBuild(<name>.GBL)`.
  - `EXPORTDOCS` for `Globals` reads `SIZE` instead of `Docs`, answering `Docs`' shape: `Present` `<name>.GBL`, `Modified` and `Absent` `""`, `Namespace`, `root` and `path` null. Its refusals are answered unchanged.
  - `ExportSet` for `Globals` reads `SIZE` in place of `PresentSet`. After the route, an XML whose line lengths plus line feeds exceed `MAXIMPORTCHARACTERS`, or an answer the capture refused, is 422 `GLOBAL.TOOLARGE`; nothing is written.
  - `Examine` versions each `.gbl` document through `DIGEST` (DW-2608), and its refusal refuses the preview.
  - `COMPOSEDTYPES` and `SnippetForm` gain `Globals/EXPORT` and `Globals/IMPORT`.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` (add-only lines before 21.5's `Global` arm) -- a `global` target whose tool's write type is `EXPORT` is not judged. A `global` target whose tool is an import (`IMPORT` write type, id `import`) is judged as the class/routine import branch judges it, 21.5's `.gbl` clause included.
- `src/OcuPilot/Screen/Tool/ExplorerGlobalExport.cls` (new) -- `Extends ExplorerExport`; `explorer.globals.export`; `DESCRIPTORCLASS` `ExplorerGlobalList`; `Endpoint()` `Globals`. `InputSchema` describes `Names` as one global's name, as the Globals list reports it, without `^`.
- `src/OcuPilot/Screen/Tool/ExplorerGlobalImport.cls` (new) -- `Extends ExplorerImport`; `explorer.globals.import`; `DESCRIPTORCLASS` `ExplorerGlobalList`; `Endpoint()` `Globals`.
- `src/OcuPilot/Screen/Descriptor/ExplorerGlobalList.cls` (add-only) -- `rowActions` `export`, `export-browser`, `import`, `import-local`.
- `src/OcuPilot/Kernel/Governance/Baseline.cls` (add-only) -- `explorer.globals.export: true`, `explorer.globals.import: false`.
- `src/OcuPilot/Test/GlobalTransfer.cls` (new) -- each test makes and kills its own `^ZZOcuGlb<pid>` and removes its own files under `<manager directory>OcuProbe2117/`:
  - `SIZE` and `DIGEST`: digest equal across reads and changed by any value edit; bound refusals with a global over 3,000,000 characters.
  - Export through the screen and the agent: missing (404, no vendor call), too large, and an XML over the bound with node text under it (many short nodes).
  - Round trip, AC1.
  - DW-2608: replace import, moved global, and existing-too-large.
  - Prohibited: `explorer.globals.export` of an own-stem name is not prohibited; `explorer.globals.import` whose `documents` hold `oddDEP.GBL new` is `PROHIBITED.PROTECTEDGLOBAL`.
- `src/OcuPilot/Test/ExplorerTransfer.cls` -- one test: a Routines list import of a file holding the test's existing global previews the same summary twice, a second apart, and imports (DW-2608 on 19.13's own tools).
- Every shared-surface test under Verification, updated to the new shape.

**Batch 2, client (commit when its loop commands are green):**

- The page that draws the Globals list (`CodeListPage` when `shell/screen-outlet.ts` maps `ExplorerGlobalList` to it) -- `export` takes the selected row as its one name when the screen declares no `multiSelect`; the dialogs, sends and done lines are 19.13's. If 21.5 delivered another page, it registers the same two actions and shares the dialog and send code with `CodeListPage` rather than copying it.
- `core/screen-actions.ts` (add-only) -- `export` label `STRINGS.taskExportAction` for `ExplorerGlobalList`; `core/screens.generated.ts` regenerated.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` (add-only) -- the ruled strings into Fixed strings; `core/strings.ts` only where a mirror test needs one.
- `ui/browser/system-explorer-global-transfer.browser-spec.mjs` (new) -- each step waits for the answered signal: the spec's own global's row Export to a server file reports done; the screen's Import of that file, after the spec kills the global, restores it (read back through the node view); a local import of a file holding `%ZZOcuGlb<pid>` shows the protected-global sentence.

**Acceptance Criteria (epics.md, verbatim):**

- Given global export and import, when each runs, then it round-trips, every write a confirmed proposal.

**Acceptance Criteria (this plan):**

- AC1. Given the test's own global, holding a plain value, a `$List` value, a value over 32,000 characters and a non-Latin value, when it is exported from the Globals list to a server file, killed, and imported from the Globals list, and again when the agent proposes both and the person confirms each, then a `$Query` walk of the global equals the original.
- AC2. Given an undefined global, or one past the bound, when either caller exports it, then it is refused `GLOBAL.NOTFOUND` or `GLOBAL.TOOLARGE` before `ExportToXMLFile` is called, and no file is written.
- AC3 (DW-2608). Given an import that replaces an existing global, when it is previewed twice and confirmed, then both previews read the same summary and the import loads. When a node changes between the preview and the confirm, it is refused `EXPLORER.IMPORT.CHANGED` with nothing loaded.
- AC4. Given the Globals list's import of a file holding a code global or a `%`-global, when either caller imports it, then it is refused `PROHIBITED.PROTECTEDGLOBAL` before anything loads. An export of a global is never judged by the arm.
- AC5. Given the browser, when the person exports the spec's global from its row and imports the file back, then the global's nodes read back as exported (Rule 3).

## Spec Change Log

- 2026-11-18 (runner, decide): Batches 1 and 2 land in one finalize commit; the pre-commit `screen-mirror.mjs --check` refuses a new descriptor until its client exists (Story 21.14).

## Review Triage Log

## Design Notes

**Governing ADs:** AD-6, AD-8, AD-10, AD-13, AD-14, AD-21 (sixth case), AD-22, AD-29, AD-36, AD-39 (fifth exception: "an export's XML lines answered to this browser"), AD-44, AD-51 (19.13's `AtelierPort` case), AD-52, AD-53, AD-59, AD-61.

**No AD entry is needed:**

- The export is 19.13's AD-51 case, which builds `ExportToXMLFile`'s body from the document set through `EXPORTDOCS`. A one-global set is `<name>.GBL`.
- The import is the same case, unchanged.
- AD-61 is kept: `AtelierPort` stays the only class naming `%Api.Atelier.*`. `SIZE` and `DIGEST` are `GlobalPort` reads that `AtelierPort` calls, as it calls `PathPort`, so neither is a call outside Atelier's routes.
- AD-10 is kept: 21.5's arm judges "a write to a global" and an export writes none. Its import clause is applied unchanged to the third import tool.
- Running `ExportToStream` from `GlobalPort` instead was rejected, because it would be a new `GlobalPort` write case (a new AD-51 entry).

**Measured read-only on slot A `ocupilot` (2026-11-15):**

- `ShowQualifiers`: `/mergeglobal` "If importing a global from XML file merge the global with existing data", default 0, with no system or namespace default qualifiers set. So a load replaces the global (inference until Task 0 (a)).
- Export XML shape: nested `<Node><Sub>…</Sub>`, with `<Data>` or `<DataBase64>` per value.
- XML size against node text: 701/388 (3 nodes), 1,951/1,684 (31 nodes), 6,427,165/6,101,139 (98,352 nodes), so a node costs about 3 to 35 characters beyond its text.
- A bounded walk of `^EnsHL7.Description` stopped at 3,000,023 characters and 49,903 nodes in 0.229 s. The batched digest of the same walk took 0.392 s.
- Earlier: `GetDate` answers the current time for an existing global and -1 for a missing one.

**Decided in-stage:**

- The intent contract was rewritten from the blocked plan's evidence-only version; its Re-plan basis is kept verbatim.
- Both `deferred:` items were harvested already, as DW-2607 (Story 21.5, its import clause) and DW-2608 (here).
- One global per export, as a row action (the runner's direction); the classic page's multi-global and `.go` formats are not built.
- The bound is the import's own 3,000,000, so every export imports back. Past it, an import that would replace an existing global is refused rather than left unversioned. Before this story every such import refused `CHANGED`.
- The Globals list's import is 19.13's operation unchanged: it imports every document the file holds, all listed in the reviewed summary, and it asks routines WRITE as AD-61 rule 1 states. That is stricter than a globals-only import needs.
- Done and dialog lines reuse 19.13's "1 document" strings, since a global exports as one document, `<name>.GBL`.
- An export of `^OcuPilot*` is not refused: it reads only what the caller's database READ allows, as the classic page does and as 21.5's node view does (AD-9 keeps the data behind its resource).
- Tests are not armed: each makes and kills its own global and files.

**Strings, escalated for the spec gate's ruling:**

- `GLOBAL.TOOLARGE`: "This global is too large for OcuPilot to export or replace: the most is 3,000,000 characters."
- The reviewed-summary entry for a replaced global, shown in the import card's `documents` row: `<name>.GBL replaces sha256 <digest>`.

**Extend, don't copy (Rules 2 and 31):**

- The two tools subclass `ExplorerExport` and `ExplorerImport`.
- `AtelierPort` reaches `GlobalPort` as it reaches `PathPort` (`GlobalPortClass`).
- `SIZE` and `DIGEST` share one walk with each other, and with 21.5's `ParseReference` and name pattern.
- The client reuses `ExplorerExportDialog`, `ExplorerImportDialog` and `CodeListPage`'s sends.

**Integration ACs.** The new `GlobalPort` reads are consumed in this story by `AtelierPort`'s export and import (AC2 and AC3, through HTTP and the agent).

- **Consumes:** Story 21.5's `GlobalPort`, `GlobalError`, `ExplorerGlobalList`, the `global` entity type and the `Global` arm with its import clause; Story 19.13's tools, mints, dialogs and `AtelierPort` types.
- **Consumed-by:** none planned. Story 21.18 adds to `GlobalPort` beside these reads and uses neither.

**Ledger inbox:** DW-2608 is addressed by the `Examine` task, the matrix row, AC3 and the two DW-2608 tests.

**Contended paths (checked 2026-11-15):** `origin/OCU-1-epic24` has no commit beyond feature on any file named here. Its worktree holds only an untracked `Test/InteropStartupWire.cls`. No Epic 22 branch or worktree exists. Edits to registration files (`Baseline`, `Prohibited`, `screen-actions.ts`, EXPERIENCE.md) stay add-only. Story 21.18 also adds to `GlobalPort` and `GlobalError`; both are add-only.

**Runner ruling at the spec gate (2026-11-15):** export of a global whose name begins with one of OcuPilot's name stems is refused from either caller before any vendor call, stricter than the classic page (AD-35: OcuPilot's stored state includes protected settings), with the sentence "OcuPilot's own data cannot be exported." under a `GLOBAL.OWNDATA` code (a read refusal, not an AD-10 arm, which covers writes); add a matrix row and a test. The other escalated strings and the in-stage choices are kept (veto U-64). Implement after Story 21.5.

## Verification

**Shared surfaces:**

- The System Explorer import and export tests: `ExplorerTransfer`, `AtelierPortTransfer`, `AtelierPortWrite`'s `SnippetForm` pins, `DraftRegistry`.
- The browser specs `system-explorer-transfer` and 21.5's `system-explorer-globals`.
- Rosters: `Navigation`, `Descriptor`, `ExplorerDescriptor` (names, writes, baseline keys, actions), `ReadTool`'s size (+2), `ToolWrite`'s counts (+2 on `AtelierPort`), `Prohibited`, `SurfaceCoverage` (+2 rows), `ToolRoundTrip`, `ToolDispatch`, `ToolEmit`, `PortGate` (`GlobalPort` +2 types, `AtelierPort` +1 endpoint), `EndpointCoverage`, `GovernanceBaseline` (+2 keys), `Governance`, `ClassicPageGate`, `MappingDescriptor`.
- `ui/tools/screen-mirror.test.mjs`, and `ui/tools/strings.test.mjs` with the EXPERIENCE.md literal cap 4200 (if crossed, raise it by 400 under the file's protocol and report it).

The implement stage greps `ui/browser`, `ui/tools`, the `ui/src` specs and `src/OcuPilot/Test` for each; every test it changes joins `(loop)`.

*Every test added or changed passes on a fresh environment, in either order.* Each test makes, asserts on and removes its own marker-named global and files.

**Commands** (one per foreground call, `timeout: 600000`, against `ocupilot-ci` only, never two test calls in one message):

- `(loop)` `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/b708a79b-b765-42ec-adea-dbc87acf6251/scratchpad/e21u/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` -- expected `LOADERRORS=0`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.GlobalTransfer`, then the same, one class per call, for `ExplorerTransfer`, `AtelierPortTransfer`, `AtelierPortWrite`, `GlobalRead`, `GlobalWrite`, `Prohibited`, `PortGate`, `SurfaceCoverage`, `EndpointCoverage`, `ExplorerDescriptor`, `Descriptor`, `Navigation`, `ReadTool`, `ToolWrite`, `ToolRoundTrip`, `ToolDispatch`, `ToolEmit`, `DraftRegistry`, `GovernanceBaseline`, `Governance`, `ClassicPageGate`, `MappingDescriptor` -- expected green.
- `(loop)` `uv run scripts/check-objectscript.py`; `uv run scripts/test_check_objectscript.py`; `bash scripts/lint-docs.sh` -- expected clean.
- `(loop)` `cd ui && node --test tools/strings.test.mjs tools/screen-mirror.test.mjs` plus every `ui/tools` test the sweep changes -- expected green.
- `(loop)` `cd ui && npm run build && npm run test:components`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, then `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/system-explorer-global-transfer.browser-spec.mjs browser/system-explorer-transfer.browser-spec.mjs browser/system-explorer-globals.browser-spec.mjs` -- expected green.
- `(once)` `cd ui && npm run test:tools` -- expected green.
- `(once)`, runner-owned: the full ObjectScript sweep one class per call, `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS`, and Rule 30's fresh check. The full browser suite is left to CI.

**Mutations (Rule 19)** -- apply, observe red, revert byte-identical, reload, record `mutation: <change> -> <test red>`:

- AC1: drop `WholeLines` from the `Globals` export (the long value breaks).
- AC2: skip the `SIZE` read in `ExportSet` for `Globals`.
- AC3: take the vendor `ts` for `.gbl` again in `Examine`; separately, digest references without values.
- AC4: drop the `global` import routing in `Prohibited`.
- AC5: send the Globals export with the checked set instead of the selected row.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Re-plan on Story 21.5's design: export and import through 19.13's `AtelierPort` case, with presence, size and digest read through two new `GlobalPort` types; no AD entry needed; DW-2608 addressed. Probes were read-only on slot A `ocupilot`; nothing ran against `ocupilot-ci`.
