---
title: 'Story 21.17: Global export and import'
type: 'feature'
created: '2026-11-15'
status: 'done'
baseline_revision: '66c32ffa5a7a3efd25e86360bed08af22c663430'
baseline_commit: '66c32ffa5a7a3efd25e86360bed08af22c663430'
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
- (c) `ExportToXMLFile` through `AtelierPort.Route` with `["ZZOcuGlb<pid>.GBL"]` answers its XML lines, and answers success with an empty `<Global>` node for an undefined one (measured; see Design Notes).
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

### Review Findings

- [x] [Review] HIGH (orchestrator ruling 2026-11-18, option a; AD-61 rule 5 now records it, spine commit 1017325ca): `AtelierPort.ExportSet` converts a Globals export's failure to 422 `GLOBAL.TOOLARGE` only when the failure is positively the capture-ceiling one, identified by its own signal (not by any 503 from a globals export); every other 503 stays `PORT.UNAVAILABLE` and is logged as a fault as today; the expected too-large refusal writes no `PORT.UNAVAILABLE` fault. Pin both legs: too-large -> 422 with no fault row; a genuine unavailability (a seam forcing a non-ceiling port failure) -> 503 with a fault row; prove the ceiling leg load-bearing with a mutation and write its `mutation:` line.

Code review 2026-11-18 (`50905467e..2b7a65791`, four layers, full-opus). Measured on `ocupilot-ci` over HTTP as a `%Development` holder without `OcuPilotAdmin` or `%All` (with and without `%Admin_FileSystemAccess`) and as `_SYSTEM`, in `HSCUSTOM` and `USER`: export to a server file and to this browser, a replacing import (server file and UTF-8 local file, a 40,000-character and a non-Latin value) all 200 and equal; a `%`-global, an `IRIS.Temp*` global, an OcuPilot-named global in any case and a file holding an ordinary and a `%`-global refused 403 with nothing loaded; an extended reference refused 400 before any load; `GLOBAL.OWNDATA` 403 in three cases on both exports. Without the file-system pair the server-file forms answer 403 `AUTH.NOPRIVILEGE` (AD-21's sixth case).

- [x] [Review][Decision] HIGH (Rule 6): a Globals export whose answer passes the capture answers 422 `GLOBAL.TOOLARGE`, where AD-61 rule 5 says `PORT.UNAVAILABLE` -- the matrix's "Too large" row asks for 422; `Outcome` has already logged a `PORT.UNAVAILABLE` fault, and the remap keys on status 503 [`AtelierPort.cls` `ExportSet`]. Needs the lead: an add-only AD-61 record (recommended, no code change) or the remap dropped with the matrix amended.
- [x] [Review][Patch] MED: `DeveloperFloor`'s roster lacked the two tools (red, run 871) [`Test/DeveloperFloor.cls` `TOOLS`, `HELDWRITES`]
- [x] [Review][Patch] MED: no agent confirm of an unchanged replacing import was shown to load (the DW-2608 symptom) [`Test/GlobalTransfer.cls` `TestAReplacingImportReadsOneSummaryAndIsRefusedWhenTheGlobalMoved`]
- [x] [Review][Patch] MED: the browser spec took the row index before the filtered read answered [`ui/browser/system-explorer-global-transfer.browser-spec.mjs` `selectGlobalRow`]
- [x] [Review][Patch] MED: `DIGEST` failed 500 on a value whose UTF-8 passes the longest string; the dead `<MAXSTRING>` trap removed [`Port/GlobalPort.cls` `VendorTotals`, `WriteDigestBatch`]
- [x] [Review][Patch] MED: no developer-principal test of the new paths [`Test/GlobalWriteDeveloper.cls` `TestADeveloperExportsAndImportsItsOwnGlobalAndIsRefusedAProtectedOne`]
- [x] [Review][Patch] MED: the browser path's non-Latin value was unproven [`ui/browser/system-explorer-global-transfer.browser-spec.mjs`, third test]
- [x] [Review][Patch] LOW: Design Notes record 403 for the matrix's 409 and drop the stale "export of `^OcuPilot*` is not refused" line [this spec]
- [x] [Review][Defer] `Prohibited.ImportedGlobals`' catch keeps an OK status [`Prohibited.cls`] — deferred: pre-existing (21.5), contended file; DW-2731 routed to 21-18
- [x] [Review][Defer] Story 21.18's matrix says 409 for a protected global [spec-21-18] — deferred: another spec; DW-2732 routed to 21-18

Rejected:

- `false` extended reference in a file (`^|"ns"|X`): measured, listed as `|"USER"|X.gbl` and refused 400 before any load.
- `low` published 3,000,000-character limit vs many-node globals: the ruled sentence and the XML bound are the spec's.
- `low` an OcuPilot-named global import gets the code sentence; `DIGEST` reads own globals: the spec judges the import as 19.13's and leaves `DIGEST` unrefused (Design Notes).
- `low` the digest of a replaced global reaches the agent's card: SHA-256 over the framed nodes; no realistic offline guessing by the agent.
- `low` no total bound across a file's globals: each walk is bounded; a file naming many large existing globals is self-inflicted.
- `low` Export drawn enabled on an OcuPilot-named row: refused with its sentence; an up-front kind needs a new string.
- `low` the import arm repeats the class/routine branch and the `.gbl` check: add-only lines in a contended file, the spec's stated reason.
- `low` Globals list moved to `CodeListPage`: recorded under Decided in-stage, no copy.
- `low` registration edits not add-only: Epic 24 has no change pending on either line.
- `low` `GlobalTransfer` at 557 lines: within reach of the 500-line guide.
- `low` Export while the shell's Delete sends: export only reads the global; each write is confirmed.

## Spec Change Log

- 2026-11-18 (runner, rework 1): code review left one HIGH (AD-61 rule 5 vs the matrix's 422); ruled (a) by the orchestrator; re-opened for the narrowed conversion.

- 2026-11-18 (runner, decide): Batches 1 and 2 land in one finalize commit; the pre-commit `screen-mirror.mjs --check` refuses a new descriptor until its client exists (Story 21.14).

## Review Triage Log

- 2026-11-18, orchestrator ruling (option a): the Globals export's too-large answer stays 422 `GLOBAL.TOOLARGE`; AD-61 rule 5 gains an add-only sentence recording it (spine commit 1017325ca); the conversion is narrowed to the capture-ceiling failure in rework 1. No owner veto item: it makes an error answer more accurate.

### 2026-11-18 — Review pass

- verdicts: 7 findings — high 0, medium 2, low 5, false 0, maybe-false 0
- findings:
  - `[medium]` `patch` Agent export accepts one name only (`SetNames`, `SetProblem`) with no test -- added `GlobalTransfer.TestAnExportToThisBrowserAnswersTheLinesAndANameIsOneGlobal` rows for `A,B`, `^A`, empty and one good name; mutation line recorded.
  - `[medium]` `patch` Export to this browser never run for a global -- same new test exports to the browser, kills the global and imports the lines back with the list's local import; mutation line recorded. The test's global omits the long and non-Latin nodes: the test client reads 32,000 characters of an answer and sends non-Latin text as `?`.
  - `[low]` `patch` AC4's "an export is never judged" half had no mutation -- applied `If 0 &&` before the export skip in `Prohibited.Prohibits`, observed red, reverted, line recorded.
  - `[low]` `reject` Matrix row says 409 `PROHIBITED.PROTECTEDGLOBAL` and the tests assert 403 -- 21.5's clause answers 403; the matrix is in the read-only intent contract and a spec edit is not a fix.
  - `[low]` `reject` AC4's `oddDEP` case is checked at the arm only -- both cases reach the same routing; no named harm.
  - `[low]` `reject` (intent-alignment) agent turns are driven in process, not over HTTP -- descriptive; the dispatcher and confirm paths are the ones run.
  - `[low]` `reject` (intent-alignment) the shared code list page skips Compile and Delete for a list with no multi-select -- guarded by `checksRows`; the classes and routines page specs stay green.

### 2026-11-18 — Review pass (rework 1, ceiling signal)

- verdicts: 5 findings — high 0, medium 2, low 3, false 0, maybe-false 0
- findings:
  - `[medium]` `patch` The ceiling signal was set for a capture that could not be ended as well as for an answer above the ceiling -- `Route` now flags an answer above the ceiling (2) apart from a capture that cannot be ended (1, a 503 logged as a fault), and `EndCapture` is a seam the fixture fails.
  - `[medium]` `patch` The non-ceiling leg ran through a fixture `Route` that bypassed `Route` and `Outcome` (verification-gap, intent-alignment) -- replaced by a real capture-end failure and a refused route (403), each with its fault row and no file, plus a `CallCount` of 1.
  - `[low]` `patch` The test's doc comment said the route never runs for the second leg, unasserted -- rewritten to match the asserts.
  - `[low]` `reject` (intent-alignment) a `<MAXSTRING>` from the vendor's own render counts as the ceiling -- it is the signal the live 90,000-node leg raises.
  - `[low]` `reject` (verification-gap) the Auto Run Result lacked this pass -- written at finalize.

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

**Task 0, measured on `ocupilot-ci` (2026-11-18):**

- (a) `xml/load` of a file holding `^ZZOcuGlb<pid>` replaces the global with flags `""` and with `cuk`: a node added after the export is gone, a node killed after it is back, a 40,000-character value and a non-Latin value come back whole.
- (b) `xml/list` names it `<name>.gbl`, in lower case, with `ts` the current time while it is defined: two lists two seconds apart read 09:44:52 and 09:44:54 (DW-2608 reproduces). `ts` is -1 for an undefined global.
- (c) `ExportToXMLFile` through `AtelierPort.Route` with `["<name>.GBL"]` answers the XML lines. For an undefined global it answers success **with** a `<Global>` holding one empty `<Node><Sub>^<name></Sub></Node>`, not without one, so the size read must refuse it before the call, which it does.
- (d) The answer passes the capture ceiling (3,641,144) between 70,000 and 80,000 one-character numeric nodes (210,007 lines pass, 80,000 nodes answer 503), at about 21 characters of node text per node, well under the 3,000,000 bound.

**Decided in-stage (implement):**

- A summary entry keeps the vendor's spelling, `<name>.gbl new` or `<name>.gbl replaces sha256 <digest>`, since `selected` must be the names as listed; the arm reads any case.
- The digest writes each node as the length of its reference, `:`, the reference, the length of its value, `:` and the value, UTF-8 encoded, so no node's text can read as another's framing.
- An export of one of OcuPilot's own names is refused in `GlobalPort`'s `SIZE` read, which every caller's mint, screen action and confirm make before any vendor call: 403 `GLOBAL.OWNDATA`, "OcuPilot's own data cannot be exported." (runner ruling above). The intent contract's matrix is read-only here, so its row is recorded as: an export naming an OcuPilot-stem global, either caller, writes nothing and refuses 403 `GLOBAL.OWNDATA` at mint, screen and confirm, and the vendor's export is not called. The `DIGEST` read, which versions an import, does not refuse it, since an import is judged by the arm.
- An answer the capture refused is 422 `GLOBAL.TOOLARGE` (from 503) for a global's export only. A name in a file that `GlobalPort` cannot read as a global name refuses the preview with that port's 400.
- The Globals list is drawn by the shared code list page (`shell/screen-outlet.ts` maps it there; it was the criteria page before). That page registers neither Compile nor Delete for a list that declares no multi-select, so the shell handler's typed-name Delete stays, and renders its pending dialog through `app-screen-action-dialogs`. Its criteria form is the code list's (a System checkbox in place of the criteria page's any/yes/no select). The handler's `UNDRAWN_ACTIONS` names the four transfer actions, which the page sends.
- The import dialog opens with Compile checked, as for the other lists, and the Globals list sends it as the dialog holds it.
- `ExplorerGlobalExport` and `ExplorerGlobalImport` keep the classic Export and Import dialog pages (`CLASSICPAGES`), and both join the classic-gate rosters (`ClassicPageGate`, `MappingDescriptor`).
- `ExplorerTransfer`'s new test makes its global in `USER`, the namespace its other tests probe; `GlobalTransfer` makes its in `HSCUSTOM`.

**Decided in-stage (code review):** the matrix's "Code or `%` global" row reads 403, not 409: every refusal of a protected global answers 403 `PROHIBITED.PROTECTEDGLOBAL`, or 403 `PROHIBITED.OCUPILOTCODE` for an OcuPilot-named one, as Story 21.5's arm does on every caller (measured on `ocupilot-ci`, 2026-11-18).

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

Observed (each applied on `ocupilot-ci`, red, reverted byte-identical by `cmp` against a copy, source reloaded or bundle rebuilt and redeployed):

- mutation: AC1 skip `WholeLines` for a global in `AtelierPort.ExportSet` -> `GlobalTransfer.TestAGlobalRoundTripsThroughTheScreenAndTheAgent` red on both "every node is as it was" rows, and `TestAReplacingImportReadsOneSummaryAndIsRefusedWhenTheGlobalMoved` red on "the global is the file's".
- mutation: AC2 replace the `GlobalDocs` size read in `ExportSet` for a global with `$$$OK` -> `GlobalTransfer.TestAnExportOfAMissingOwnOrOversizedGlobalIsRefusedBeforeTheVendor` red on its three port rows, answering 500 `INTERNAL` where the read would have refused (the mint and the screen refuse through the fresh read, which this leaves).
- mutation: AC3 take the vendor's `ts` for a `.gbl` document in `AtelierPort.Examine` (`If 0 && ..IsGlobalDocument`) -> `GlobalTransfer.TestAReplacingImportReadsOneSummaryAndIsRefusedWhenTheGlobalMoved` and `TestAGlobalTooLargeToReplaceRefusesThePreviewAndTheWrite` red, and `ExplorerTransfer.TestAnImportReplacingAGlobalReadsOneSummaryTwice` red on its equal-previews assertion.
- mutation: AC3 digest the references without the values in `GlobalPort.VendorTotals` -> `GlobalTransfer.TestAReplacingImportReadsOneSummaryAndIsRefusedWhenTheGlobalMoved` red (the confirm loads over a moved node) and `TestTheSizeAndTheDigestReadTheWholeGlobal` red on the value-edit and known-answer rows.
- mutation: AC4 `If 0 &&` before the `global` import routing in `Prohibited.Prohibits` -> `GlobalTransfer.TestAnImportOfACodeOrPercentGlobalIsRefusedAndAnExportIsNeverJudged` red on the `oddDEP`, own-stem, list and agent rows (the `%` global is then loaded, which the test's teardown kills).
- mutation: AC5 `onOpenExport` reads the checked set for every list in `code-list.page.ts` -> `code-list.page.spec.ts` "Export acts on the one selected global" red, and `system-explorer-global-transfer.browser-spec.mjs` AC5 red (no export dialog opens), after `npm run build` and the redeploy.
- mutation: AC2 skip the XML length check after the export in `ExportSet` (`If 0 &&`) -> `GlobalTransfer.TestAnAnswerTheCaptureRefusedOrXmlAboveTheBoundIsTooLarge` red on the canned 3,150,000-character leg (the file is written).
- mutation: AC2 never set the ceiling signal (`Set pCeiling = 0` in `Outcome`) -> `GlobalTransfer.TestAnAnswerTheCaptureRefusedOrXmlAboveTheBoundIsTooLarge` (live 90,000-node leg, 503) and `TestOnlyTheCaptureCeilingIsTooLargeAndAnyOtherPortFailureStaysUnavailable` red (run 911); count a capture that cannot be ended as the ceiling (`Set tOverflow = 2` in `Route`'s `exEnd` catch) -> the second test red alone on the capture-end leg (run 908); set the ceiling for any failed call (`If $$$ISERR(tSC) Set pCeiling = 1` at the end of `Route`) -> the second test red alone (run 909); log the ceiling's fault although the caller owns it (`If 1 Do ..LogFault` in `Outcome`) -> the second test red alone on the empty-log row (run 910); each reverted byte-identical by `cmp`, reloaded, green (run 912).
- mutation: AC2 drop the bound check in `GlobalPort.VendorTotals` -> `TestTheSizeAndTheDigestReadTheWholeGlobal`, `TestAGlobalTooLargeToReplaceRefusesThePreviewAndTheWrite` and `TestAnExportOfAMissingOwnOrOversizedGlobalIsRefusedBeforeTheVendor` red; count only the values -> the exact-bound rows red.
- mutation: AC2 (own data) drop the own-stem refusal in `GlobalPort.GlobalTotals` -> `TestTheSizeAndTheDigestReadTheWholeGlobal` and `TestAnExportOfAMissingOwnOrOversizedGlobalIsRefusedBeforeTheVendor` red (the missing global answers 404 in its place).
- mutation: AC1 drop `.GBL` from the script's names in `AtelierPort.Snippet` -> `GlobalTransfer.TestTheTransfersRenderTheirScripts` red.
- mutation: the import key (Governance) `explorer.globals.import` `true` in `Baseline` -> `GlobalTransfer.TestTheToolsDeclareTheirWritePathAndTheImportKeyShipsOff` red on the baseline and dispatch rows.
- mutation: AC5 (Delete stays the handler's) `checksRows` true in `CodeListPage` -> `code-list.page.spec.ts` "Delete stays the shell handler's" red.
- mutation: AC1 (export to this browser) answer `[]` for the no-file branch's lines in `AtelierPort.ExportSet` -> `GlobalTransfer.TestAnExportToThisBrowserAnswersTheLinesAndANameIsOneGlobal` red alone.
- mutation: AC1 (one name) `If 0 &&` before the `Globals` case in `AtelierPort.SetNames` -> that test and five more in `GlobalTransfer` red.
- mutation: AC4 (an export is never judged) `If 0 &&` before the export skip in `Prohibited.Prohibits` -> `GlobalTransfer.TestAnImportOfACodeOrPercentGlobalIsRefusedAndAnExportIsNeverJudged` red alone.
- mutation: (shared surface) `DeveloperFloor`'s roster as committed, without the two tools -> `TestTheToolsTheDeveloperHoldsAreTheDeclaredRoster` red (run 871); with them green (run 873).
- mutation: AC3 `If 0 &&` before `IsGlobalDocument` in `AtelierPort.Examine` -> also the agent's confirm a second later in `GlobalTransfer.TestAReplacingImportReadsOneSummaryAndIsRefusedWhenTheGlobalMoved` red (run 877).
- mutation: AC3 one UTF-8 conversion per batch in `GlobalPort.WriteDigestBatch` -> `GlobalTransfer.TestTheSizeAndTheDigestReadTheWholeGlobal` red on the wide-value row alone (run 876).
- mutation: AC1 (developer) `GlobalTotals` requires `OcuPilotAdmin:USE` for `SIZE` -> `GlobalWriteDeveloper.TestADeveloperExportsAndImportsItsOwnGlobalAndIsRefusedAProtectedOne` red (run 892).
- mutation: AC1 (browser, non-Latin) `explorer-import-dialog.ts` reads the file as `iso-8859-1` -> `system-explorer-global-transfer.browser-spec.mjs` third test red (`0:8`), after the build and redeploy.

## Auto Run Result

Status: done
Blocking condition: none

Rework 1 (AD-61 rule 5): a Globals export answers 422 `GLOBAL.TOOLARGE` only for an answer above the capture's ceiling, which `Route` flags apart from a capture that cannot be ended; that and every other port failure keep 503 or their own status with their fault row, and the ceiling writes none. `AtelierPort` (`Route`, `Outcome`, `ExportSet`, an `EndCapture` seam), `AtelierPortFixture` and `GlobalTransfer` (11 tests, green; `AtelierPortDocument`, `AtelierPortTransfer`, `AtelierPortWrite`, `AtelierPort`, `ExplorerTransfer` green; `check-objectscript` 0) changed; four mutations observed red and reverted. Both review items closed above; two medium patched, no high; follow-up review not recommended. Residual risk: the live HTTP leg runs in another process, so its fault row is read only on the canned legs.

Review pass 2026-11-18: no high; two medium and one low patched (tests and mutation lines for the export to this browser, the one-name rule and the export skip in the arm; `GlobalTransfer` now 10 tests, green, three further mutations observed red and reverted byte-identical); four low rejected with reasons in the Review Triage Log. `check-objectscript` 0 problems and `lint-docs` clean after the patches. Follow-up review not recommended. Residual risk: the browser leg of the export and local import is proved for Latin-1 values only, because the test client sends non-Latin text as `?` (inference: a real browser sends UTF-8). The runner owns the full ObjectScript sweep, smoke, and the `ci-timings.json` refresh.

Implement pass (both batches, one finalize commit): Task 0 measured (Design Notes). Server: `GlobalPort` `SIZE` and `DIGEST`, `GlobalError` `TOOLARGE` and `OWNDATA`, `AtelierPort`'s `Globals` endpoint (export read, bound, script form, `.gbl` versioned by digest), the arm's export and import routing, two tools, the descriptor's row actions and the baseline keys. Client: the Globals list drawn by the shared code list page (export on the selected row, screen-level import, the handler's typed-name Delete kept), the label, the two sentences in EXPERIENCE.md and `strings.ts`, the regenerated mirror and a browser spec. Verified on `ocupilot-ci`: `GlobalTransfer` 9, `ExplorerTransfer` 12 and every roster class the story touches green one at a time; `check-objectscript` 0 problems, `test_check_objectscript` 163 OK, `lint-docs` clean; `test:tools` 2314, `test:components` 3568, `npm run build` (initial 2.12 MB) and the three browser specs green; thirteen mutations observed red and reverted byte-identical. The intent contract's matrix is read-only here, so the `GLOBAL.OWNDATA` row is recorded under Design Notes.
