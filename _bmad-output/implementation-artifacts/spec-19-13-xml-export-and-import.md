---
title: 'Story 19.13: XML export and import'
type: 'feature'
created: '2026-10-02'
status: 'done'
baseline_revision: '18d5533c14b180eb1f13a6547008464b8df81014'
baseline_commit: '18d5533c14b180eb1f13a6547008464b8df81014'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-19-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-19-2-compile-delete-export-and-import.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** System Explorer's Classes and Routines lists compile and delete (Story 19.2), but they cannot export code to XML or import it back, which the classic Export and Import dialogs do (catalog rows EX-05 to EX-08; epics.md Story 19.13).

**Approach:** This is Part B of 19.2's spec, built on the write plumbing 19.2 delivered. It adds four action-style tools on `Port/AtelierPort`:

- **Export** of the checked set, to a server file (agent and screen) or to this browser (screen only).
- **Import** of an XML export or one UDL document, from a server file (agent and screen) or a local file (screen only).

Each tool is reached by both callers of the shared operation (AD-53). The design reuses 19.2's measurements. The two things 19.2 deferred to this story (its T0.1 and T0.3) were measured at plan; the results are under Design Notes.

## Boundaries & Constraints

**Always:**

- **One port (AD-61).** Every vendor call goes through `AtelierPort.Invoke`, named only through parameters. `ExportToXMLFile`, `ListDocumentsInXMLFiles` and `LoadXMLFiles` each declare 7 in `MINVERSIONS`. The export's fresh read and every import type are gated on their routes' minimum. On an older instance they are refused 501 `PORT.NOTIMPLEMENTED`, naming both versions, before any vendor call. `REASONVERSION` reads "this operation" in place of "this read". Compile and delete are unaffected.
- **Gates (AD-8, AD-29).** Each tool declares the same pairs its port checks, so a caller without one is refused by name before any port call.
  - An export needs the read pairs alone: `%Development:USE` plus the namespace's READ pairs, and no routines WRITE.
  - An import needs 19.2's `WritePairs`.
  - Either one also needs `PathPort`'s pairs when `root` is sent. A tool declares these through `ArgumentPairs`.
- **Server files (AD-21's sixth case)** are resolved again at the write. No answer carries a path other than the caller's own `root` and `path`.
  - The export is an overwriting `file` consumer, and its overwrite is a constant. A name whose directory does not exist is refused 400 `EXPLORER.EXPORT.DIRECTORY` on `path`.
  - The import is a `source`, read as UTF-8 text.
- **A local file is the screen's alone.**
  - It travels as the screen action values `fileName` and `content`, never in a tool's input schema.
  - It is never stored, logged or put on a ledger row.
  - `content` holds at most 3,000,000 characters, and a server file is held to the same limit. Above it, the port answers 400 `EXPLORER.IMPORT.TOOLARGE`, and the page refuses a larger file before sending it.
- **An import reads before it writes.**
  - An `.xml` file is listed with `xml/list` first. A per-file `status`, or no documents, is refused 422 `EXPLORER.IMPORT.UNREADABLE` before `xml/load` runs: 19.2 measured that malformed XML leaves a stub class otherwise. `xml/load` then sends `selected` as the listed names, spelled as the list spells them, with `flags` `cuk` when `Compile` is true and `""` otherwise.
  - A `.cls`, `.mac`, `.inc` or `.int` file is one UDL document, named from its header (Design Notes). It is sent as `PUT doc/<name>?ignoreConflict=1`, followed by a compile with `cuk` when `Compile` is true.
  - Any other extension, or a header that does not parse, is `UNREADABLE`.
- **The reviewed `documents`.** The port's `PREVIEW` answers a canonical summary of what the file would do.
  - Both callers carry it. The agent's mint stores it. The screen's `ScreenActionDelta` reads it through the port, and leaves it empty when `PREVIEW` refuses, so that the write answers that refusal itself.
  - The write refuses 409 `EXPLORER.IMPORT.CHANGED` unless the summary it reads at the write equals the one carried.
  - The prohibited arm judges the names in that summary.
- **Self-protection (AD-10).**
  - An import whose `documents` names a document whose name begins with `OcuPilot` is refused `PROHIBITED.OCUPILOTCODE`, on both callers.
  - An export only reads, so the arm does not judge it.
  - The reason becomes "This is OcuPilot's own code. It cannot be compiled, deleted or replaced from OcuPilot."
- **Output (AD-39's fifth exception, as amended under Design Notes).** These go to the screen and the proposal card only. They never reach the model, a tool result, a ledger row, a log line or screen context.
  - An import answers `output {imported, lines, errors}`. `errors` is true when the compile reports an error or a file carries a `status`. A file `status`'s vendor text is logged, never sent.
  - An export to this browser answers `output {lines}`, which are the XML lines.
  - An export to the server answers `output {root, path}`.
- **Governance (AD-22).**
  - The export keys are `true`. Export is not destructive.
  - The import keys are `false`, and import is destructive, because an import silently replaces existing code (measured in 19.2).
- **Probes run only on `ocupilot-a2-ci`**, against documents and files the probe created itself, and remove exactly those.
  - Classes go in package `OcuProbe1913` and its own-code twin `OcuPilotProbe1913`. Routines are named `OcuProbe1913*`.
  - Files go under `<manager directory>OcuProbe1913/`.

**Never:**

- Do not call the `work` routes, send `docnames`' `filter`, or call `POST modified` (AD-61 rule 7). Do not accept a caller path, or a `fileName` holding `/`, `\` or a control character.
- Do not put `content`, `fileName` or `documents` in a tool's input schema.
- Do not add a third-party library. Do not add new code to `Api/Error.cls`; new codes go in `Api/AtelierError.cls`.
- Do not add a `FILEDEVICEROUTES` entry (T0.1).
- Do not read classic `%RO` files. Do not cap an import's document count: it imports every document the file holds. Do not export a set above 100.
- Do not insert into EXPERIENCE.md above line 591, apart from the in-place edits at :173 and :590. Do not touch DESIGN.md.
- Do not write to `ocupilot`, any `ocupilot-slot-*`, `ocupilot-b-ci` or `iris-community-edition`. Do not restart or tear down `ocupilot-a2-ci`.

## I/O & Edge-Case Matrix

The routes are `POST /screens/explorer.classes/action` (or `explorer.routines`) and `POST /proposal/:id/confirm`. The export's id is the checked set (AD-13's `documentset`), and the import's id is the literal `import`.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Export to a server file | action `export`, values `{root, path}` | 200 `{action:"updated", readBack:{verdict:"nothingSent"}, output:{root, path}}`. The file holds the vendor's XML lines as UTF-8, LF-terminated, and an existing file is replaced. | `PATH.*` as `PathPort` answers them; `EXPLORER.EXPORT.DIRECTORY` on `path` |
| Export to this browser | action `export-browser`, no values (screen only) | No file is written. `output {lines}`, which the page saves as `<NAMESPACE>-export.xml`. | Above the capture ceiling, 503 `PORT.UNAVAILABLE` |
| Export with a document missing | the set names a document the namespace does not hold | 404 `EXPLORER.DOCUMENT.ABSENT` from the fresh read, at the mint, the screen action and the confirm. Nothing is exported (#6308 would void the whole export). | none |
| Import XML from a server file | action `import`, values `{root, path, Compile:"true"}` | `xml/list`, then `xml/load` with `selected` set to the listed names and `cuk`. 200, `output {imported, lines, errors:false}`. | A file `status` or no documents gives 422 `UNREADABLE`; nothing is loaded and no stub is left. |
| Import a local file | action `import-local`, values `{fileName, content, Compile}` | As for a server file, from the sent text | `content` over 3,000,000 characters gives 400 `TOOLARGE`; a malformed `fileName` gives 400 `PORT.VALIDATION`. |
| Import a UDL document | a `.cls`, `.mac`, `.inc` or `.int` file | The header names the document. The `PUT` answers 201 (new) or 200 (replaced), then a compile runs when asked. `output {imported:[name], lines, errors}`. | A header that does not parse gives 422 `UNREADABLE`; nothing is put. |
| Imported code does not compile | a file whose code fails to compile | 200. The documents are written, `errors` is true, and `lines` carry the errors. The file `status` text is logged. | not a fault |
| Agent import (AC3) | `explorer.classes.import {Id:"import", root, path, Compile}`, with the key enabled | The mint stores `documents`, for example `A.cls replaces 2026-10-02 08:59:19.69, B.cls new (sha256 <digest>)`. The card shows the rows `root`, `path`, `documents` and `Compile`, and the consequence `EXPLORER.IMPORT.REPLACES`. Confirm loads exactly those documents. | With the baseline in force, governance refuses it and the tool stays advertised. |
| File changed | at the write, the file's documents, or the version of a document it replaces, differ from `documents` | 409 `EXPLORER.IMPORT.CHANGED`; nothing is loaded | none |
| OcuPilot's own code | an import file holding `OcuPilotProbe1913.Own.cls` | 403 `PROHIBITED.OCUPILOTCODE` on both callers; nothing changes. An export of that class succeeds. | none |
| No routines WRITE | the caller holds the read pairs but not `<routines resource>:WRITE`, and imports | 403 `AUTH.NOPRIVILEGE` naming that pair, with no vendor call. A `%Development`-only holder exports to this browser. | none |
| Server file without the file pairs | `root` sent; the caller lacks `%Admin_FileSystemAccess:USE` | 403 naming that pair, before any port call | none |
| Old instance (AC2) | the version seam answers 6 | Export and import answer 501 "This instance's source code API answers version 6, and this operation needs version 7 or later." before any call. Compile and delete still run. | The dialog shows the reason |

</intent-contract>

## Code Map

### Server (anchors are on this branch)

- `src/OcuPilot/Port/AtelierPort.cls`
  - `MINVERSIONS` :46; the type parameters :78-89 (`COMPOSEDTYPES` :89); `CAPTURECEILING` :167; `FILEDEVICEROUTES` :175, which stays as it is; `REASONVERSION` :188.
  - `WritePairs` :351; `MinVersion` :362, whose route map is at :364.
  - `Invoke` :408: `tSetType` and `tWrite` :422-423, `tServed` :442, the set dispatch :456-472.
  - `Docs` :733 answers the compile's keys as `null` at :775-777, the precedent for the export read's `root` and `path`.
  - `PresentSet` :789, `AbsentRefusal` :801, `CompileFlags` :825, and `CompileSet` :835, whose soft `Route` call is at :854.
  - `Route` :1212 takes a string body (`SetJsonBody` :1231). `Outcome` :1337 has its `pSoft` branch at :1390.
  - `SnippetForm` :1464 and `Snippet` :1477.
- `src/OcuPilot/Port/AtelierRequest.cls` `SetJsonBody` writes one string into a `%CSP.CharacterStream`.
- `src/OcuPilot/Port/PathPort.cls`: `Resolve` :266 with its `pOverwrite` argument; `KINDFILE` :62, `KINDSOURCE` :66 and `PAIRS` :47.
- `src/OcuPilot/Port/TaskTransferPort.cls` is the file-consumer precedent:
  - `Locate` :215 and `ExportFile` :236, which holds the directory check;
  - `Export` :274, which deletes its own file when the vendor call fails;
  - `Import` :306, which holds the `CHANGED` comparison.
- `src/OcuPilot/Api/AtelierError.cls` already holds `DOCUMENTABSENT` and the three import codes with their sentences.
- `src/OcuPilot/Screen/Tool/`:
  - `ExplorerWrite.cls`: `PrivilegePairs` :102-113 adds routines WRITE; it also holds `PortQuery` and `WriteOutput`.
  - `ExplorerCompile.cls`: `SCREENVALUES`, and `ScreenActionDelta` and `PortQuery` overrides, the precedent for passing values.
  - `ExplorerMint.cls`: set check, fresh read, absent refusal, then the kernel mint.
  - `TaskExport.cls`: `AddFileArguments`, `FileProblem`, `Consequence`, `PrivilegePairs`.
  - `TaskImport.cls` and `TaskImportMint.cls` :29-42: the literal `import` id, and `tasks` read at the mint, stored and compared at the write.
  - `ExplorerClassCompile.cls` is a concrete tool's shape.
- `src/OcuPilot/Screen/Tool/Write.cls`
  - `SCREENACTIONS` :167 and `ScreenActionIds` :366; `SCREENVALUES` :217 and `ScreenActionValueNames` :627.
  - `ScreenActionDelta` :655, whose contract allows it to read through the tool's own port.
  - `Base.cls` `ArgumentPairs` :123. `LocalDatabaseUpdateFile` declares `PathPort`'s pairs only when an argument is sent, the precedent for the file pairs here.
- `src/OcuPilot/Api/ScreenAction.cls` constrains the design in three places:
  - `Values` (~:469) requires every declared value, each a non-empty string, so each value set needs its own action id.
  - `Body` (~:433-463) projects the payload to `FINGERPRINTSUBJECT`, and `Operation.Query` (:222) builds the port query from that payload, so every value the port needs is in the subject.
  - `output` is set at :377-380.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls`: `OCUPILOTCODEREASON` :445, class/routine routing :1038-1041, `Code` :1926, `IsOcuPilotCode` :1941, `OwnNameStems` :2285.
- `src/OcuPilot/Kernel/Proposal/ReadBack.cls` `KindOf` :206-218: an action write that reads back present is `nothingSent`.
- `src/OcuPilot/Kernel/Governance/Baseline.cls` :143-146 holds 19.2's explorer lines; `"tasks.schedule.import": false` :131 is the precedent for a disabled import.
- `src/OcuPilot/Screen/Descriptor/ExplorerClassList.cls` and `ExplorerRoutineList.cls`: `rowActions` and `multiSelect`.

### Vendor

- The XML routes in `irissys/%Api/Atelier/v7.cls` :171, :307 and :468.
  - `xml/list` and `xml/load` always take the file's lines as `content` in the body. `file` is only a label, so the port reads a server file itself.
  - `xml/list` answers each document's `ts` as the instance's own version, or -1 when the instance does not hold it.
- `PutDoc` is in `irissys/%Api/Atelier/v1.cls` :926 and v2 :396.
- The classic dialogs `irissys/%CSP/UI/Portal/Dialog/Export.cls` and `Import.cls` each declare `RESOURCE` `%Development:USE`.
- The rest is 19.2's spec, Code Map › Vendor and its M1-M8.

### Client (`ui/src/app/`)

- `areas/system-explorer/code-list.page.ts`:
  - action ids :24-25; dialogs imported at :104, and the template's dialogs :167-178;
  - open-state signals :206-209; `register` :249-250 and `stop` :260-261;
  - the compile send pins `scope` :396-405; handlers :376-436;
  - the `checkedNames()` guard :442-454.
  - The explorer lists are not in the handler's `SCREEN_ACTION_DESCRIPTORS`. An action id the page does not register is never drawn, so `export-browser` and `import-local` need no `UNDRAWN_ACTIONS` entry.
- `areas/system-explorer/code-list.store.ts` `CodeListWrite` :256-386: the `kind` union :257 and :364, `lines`, `summary`, `status`.
- `areas/system-explorer/explorer-compile-dialog.ts` is the dialog shape: `app-dialog`, a `count` input, and the outputs `confirmed` and `cancelled`.
- `areas/tasks/task-schedule.page.ts`: `register` for row Export and screen-level Import :153-154; dialogs :86-108; `AllowedDirectoriesStore` :124 loaded in `openDialog` :228-234; `showRefusal` :254-266, which routes `PATH.*` with `reasonForField` (`core/violations.ts` :67).
- `areas/tasks/task-export-dialog.ts` and `task-import-dialog.ts`: the inputs `store`, `rootReason`, `pathReason`, `refusal` and `sending`, and the outputs `submitted` and `cancelled`.
- `shell/server-path-picker.ts` :113 takes `kind` `file`.
- `areas/security/x509-form.page.ts` :134 and :553-572 read a local file with `FileReader`; there is no `accept` attribute or size check there.
- `core/csv.ts` `saveCsv` :76 fixes the type to `text/csv`.
- `core/screen-actions.ts`: `TASK_IMPORT_ACTION_ID` :49, keyed per descriptor and labeled `actionImport` (:106), so reusing it needs no shell edit; `DESCRIPTOR_ACTION_LABELS` :201-203.
- `core/proposal-view.ts`: `CONSEQUENCE_TASKEXPORTREPLACES` :202, and its branch in `consequenceSentence` :245.
- `shell/proposal-card.ts` :303-305 and :854-861 render any `output.lines` unchanged (fed through `core/turn.ts` :470-474).
- `core/strings.ts`: the explorer keys end at `explorerDeleteFailed` :4293. `explorerRefusalOcuPilot` is :4277 and `explorerImportChanged` :4283.
- `ui/angular.json` :54 sets the 2433kB warning, pinned by `ui/tools/angular-json.test.mjs` :410.

### Rosters a 19.13 change trips

Each is listed with its current literal and what moves it:

- `src/OcuPilot/Test/ExplorerDescriptor.cls` (method :113):
  - :127 is the name roster;
  - :128 has one entry per write, `name:List/Port/Endpoint/WriteType/Destructive/Subject/Precondition`;
  - :137 lists the baseline keys in the baseline's line order;
  - :142 holds the descriptors' actions and `multiSelect`.
- `Test/ReadTool.cls`: :93 reads 200 tools with 127 writes; :94 is the name roster; its message says 133 class tools.
- `Test/SurfaceCoverage.cls`: a coverage row per tool, beside :277-280; :277-280 also cites `ExplorerDescriptor`'s method name.
- `Test/ToolWrite.cls` :1325 counts other ports as 5.
- `Test/ToolRoundTrip.cls` :54: `REFUSEEMPTY`.
- `Test/GovernanceBaseline.cls`: `DISABLED` :13 in baseline line order, plus the doc at :4-5 and the message at :69.
- `Test/Governance.cls` :32 `EXPLORERDELETES`, read at :117 and :121; `Test/ToolDispatch.cls` :167 reads it.
- `Test/DeveloperFloor.cls`: `TOOLS` :35, the "no held tool is a write" assertion :427, and "the declared ten" :429.
- `Test/ToolEmit.cls` :200-207 expects every `ExplorerWrite` subclass to add `CodeResource():WRITE`. Export does not.
- `Test/DraftRegistry.cls` :122 and :141: every write type needs a `SnippetForm`.
- `Test/AtelierPortWrite.cls`: `SnippetForm` pins :254 and the snippet text :261-268.
- `Test/Prohibited.cls` :425: the count of composed settable arguments per tool, where the default is 1.
- `Test/ClassicPageGate.cls` `OWNPAIRS` :70 and its comment at :473-474.
- `Test/MappingDescriptor.cls`: `CLASSICROSTER` :22, and "exactly the thirty-seven tools" :117.
- `ui/tools/screen-mirror.test.mjs` :856 deep-equals the `multiSelect`.
- `ui/tools/self-protection.test.mjs`: `KERNEL_REFUSALS` :282 (the code sentence, equal in three places) and `ATELIER_REFUSALS` :502-511.
- `ui/tools/strings.test.mjs`: the literal-count bound :575, which is 2,000 at most; and :598, where every new `strings.ts` value must be quoted in EXPERIENCE.md.
- `ui/tools/proposal-view.test.mjs` :258-260 pins the consequence codes.

## Tasks & Acceptance

**Execution:**

1. `src/OcuPilot/Api/AtelierError.cls`:
   - add `EXPORTDIRECTORY` (`EXPLORER.EXPORT.DIRECTORY`), with the sentence "There is no such directory under that allowed directory.";
   - reword `REASONIMPORTCHANGED` in place to "The file, or a document it would replace, has changed since this import was proposed.".

   Both reasons are Fixed strings.
2. `src/OcuPilot/Port/AtelierRequest.cls`: `SetJsonBody` also accepts a `%DynamicAbstractObject`, written with `%ToJSON(stream)`. A body of file lines therefore never becomes one string.
3. `src/OcuPilot/Port/AtelierPort.cls`, on both list endpoints. Each type below is served by `Invoke`.
   - **`EXPORTDOCS`**: `Docs` with `root` and `path` answered `null` beside the `DOCS` keys.
   - **`EXPORT`**, in this order:
     - the read pairs (`NamespacePairs`);
     - `PresentSet`;
     - when `root` or `path` is sent, `CheckExport`'s resolve plus the directory check, then `ExportToXMLFile` over the set, then the lines written to the file. A file the call created is deleted on failure, as `TaskTransferPort.Export` does. It answers `{root, path}`;
     - otherwise it answers `{lines}`.
   - **`CheckExport(root, path)`**, public, for the mint.
   - **`IMPORTTARGET`**: it answers `{Namespace, root, path, fileName, content, documents}` empty, with `Compile` `null`, for the id `import`, and 404 for any other id. It makes no vendor call.
   - **`PREVIEW`**:
     - It reads the source: `root`+`path` (`Resolve` as `KINDSOURCE`, UTF-8) or `fileName`+`content`. Both or neither is 400 `PORT.VALIDATION`.
     - A `fileName` is 1 to 255 characters, holds no `/`, `\` or control character, and ends, in any case, in `.xml`, `.cls`, `.mac`, `.inc` or `.int`.
     - Text above 3,000,000 characters is refused `TOOLARGE`.
     - The text is split on LF, with a trailing CR and a leading U+FEFF stripped.
     - It answers `{documents, count}`: from `xml/list` for `.xml`, and from the header plus a `Docs` read for UDL.
   - **`IMPORT`**:
     - `WritePairs`, then the same source read, then the summary at the write compared with the carried `documents`, refused `CHANGED` when they differ.
     - Then `LoadXMLFiles` with `selected`, or `PutDoc` followed by `CompileSet`'s route when `Compile` is on.
     - It answers `{imported, lines, errors}`. A file `status` is logged and sets `errors`; it is not a fault (AD-61 rule 6 as amended).
   - Refusals and their slugs:
     - `UNREADABLE` is 422 on `VALIDATIONFAILED`, as `TASK.IMPORT.FILE` is;
     - `CHANGED` is 409 on `CONFLICT`;
     - `TOOLARGE` is 400 on `BADREQUEST`;
     - `EXPLORER.EXPORT.DIRECTORY` is a 400 violation on `path`, as `TaskTransferPort.Violation` builds it.
   - `MINVERSIONS` gains `ExportToXMLFile:7,ListDocumentsInXMLFiles:7,LoadXMLFiles:7,PutDoc:1`. The route map in `MinVersion` gives `EXPORTDOCS` and `EXPORT` the export route, and `IMPORTTARGET`, `PREVIEW` and `IMPORT` all four import routes.
   - `COMPOSEDTYPES` gains the four `endpoint/EXPORT` and `endpoint/IMPORT` pairs. `REASONVERSION` says "this operation". `Route` passes an object body through to step 2's form.
   - `SnippetForm` and `Snippet` (AD-59) render:
     - `EXPORT` as `##class(%File).NormalizeFilename(path, root)` followed by `$System.OBJ.Export(names, file, "-d")`;
     - `IMPORT` as that file followed by `$System.OBJ.Load(file, flags)`.

     Every value is a literal.
4. `src/OcuPilot/Kernel/Proposal/Prohibited.cls`:
   - In the `Code` path (:1038-1041), a tool whose write type is `EXPORT` is not judged.
   - For the target `import`, the arm judges each name in the payload's `documents`: the text before the first space of each `", "` piece.
   - `OCUPILOTCODEREASON` changes to "…cannot be compiled, deleted or replaced from OcuPilot."
5. `src/OcuPilot/Screen/Tool/`. Each class is listed with its role.
   - **`ExplorerExport.cls`** (abstract, extending `ExplorerWrite`):
     - `READTYPE` `EXPORTDOCS`, `WRITETYPE` `EXPORT`, `DESTRUCTIVE` 0, `CHANGEACTION` `updated`;
     - `READANSWERS` `Present,Modified,Absent,Namespace,root,path`; `SettableFields` `root,path`;
     - subject `Present,Absent,Namespace,root,path`; precondition `Present`;
     - `SCREENACTIONS` `export,export-browser` and `SCREENVALUES` `export=root:path`. `ScreenActionDelta` answers `root` and `path` unresolved for `export`, and no arguments for `export-browser`;
     - `CLASSICPAGES` `%CSP.UI.Portal.Dialog.Export`;
     - `CONSEQUENCE` `EXPLORER.EXPORT.REPLACES`;
     - `PrivilegePairs` holds the screen's pairs plus the classic pages, with no routines WRITE. `ArgumentPairs` is `PathPort.PAIRS` when `root` is a non-empty string;
     - `root` and `path` are required in the schema (`TaskExport.AddFileArguments` and `FileProblem`, as `TaskImport` reuses them);
     - `PortQuery` passes `root` and `path`. The state row is `Documents`;
     - its mint is `ExplorerExportMint`.
   - **`ExplorerExportMint.cls`** (extending `ExplorerMint`): `FileProblem`, then `AtelierPort.CheckExport`, then the superclass.
   - **`ExplorerImport.cls`** (abstract, extending `ExplorerWrite`):
     - `IDARGUMENT` `Id`, with the literal `import`;
     - `READTYPE` `IMPORTTARGET`, `WRITETYPE` `IMPORT`, `DESTRUCTIVE` 1, `CHANGEACTION` `created`;
     - `READANSWERS` and subject `Namespace,root,path,fileName,content,documents,Compile`; `SettableFields` the same less `Namespace`; precondition `documents`;
     - `SCREENACTIONS` `import,import-local` and `SCREENVALUES` `import=root:path:Compile,import-local=fileName:content:Compile`;
     - `CLASSICPAGES` `%CSP.UI.Portal.Dialog.Import`;
     - `CONSEQUENCE` `EXPLORER.IMPORT.REPLACES`;
     - `ArgumentPairs` as for export;
     - its schema holds `Id`, `root`, `path` and `Compile`, each required. `ArgumentProblem` checks `root`, `path` and `Compile` in place of `ExplorerWrite`'s set check, which would refuse the literal `import`;
     - `ScreenActionDelta` maps the values (`Compile` from `"true"` or `"false"`), then asks `PREVIEW` for `documents` in the fresh read's `Namespace`;
     - `PortQuery` passes every subject value (`Compile` as 1 or 0). There is no state row;
     - its mint is `ExplorerImportMint`.
   - **`ExplorerImportMint.cls`** (extending `Kernel.Proposal.Mint`, as `TaskImportMint` does): `FileProblem` and `Compile` checks, then the id set to `import`, then `PREVIEW` in `Scope.Current()`'s namespace, whose refusal is answered unchanged. `documents` is set before the superclass runs.
   - **`ExplorerClassExport`**, **`ExplorerRoutineExport`**, **`ExplorerClassImport`** and **`ExplorerRoutineImport`**: `TOOLNAME` `explorer.{classes,routines}.{export,import}`, the descriptor, the description and `Endpoint`. Each description says that the tool proposes; that the agent never sees the output; that a server file is named by `root` and `path`; and, for import, that it replaces same-named documents.
6. `ExplorerClassList.cls` and `ExplorerRoutineList.cls`:
   - `rowActions` gains `export`, `export-browser`, `import` and `import-local`;
   - `multiSelect.extraActions` becomes `["delete","export"]`;
   - update both class doc paragraphs;
   - regenerate `ui/src/app/core/screens.generated.ts`.
7. `Kernel/Governance/Baseline.cls`: append `explorer.classes.export` and `explorer.routines.export` as `true`, and `explorer.classes.import` and `explorer.routines.import` as `false`.
8. Client.
   - **`core/csv.ts`**: add `saveText(doc, text, fileName, type)`. `saveCsv` is unchanged.
   - **`core/proposal-view.ts`**: two codes:
     - `EXPLORER.EXPORT.REPLACES` reads `STRINGS.taskExportReplaces`;
     - `EXPLORER.IMPORT.REPLACES` reads the new import consequence.
   - **`core/screen-actions.ts`**: the label for `export` on both lists.
   - **`areas/system-explorer/explorer-export-dialog.ts`**: a server file or this browser.
   - **`areas/system-explorer/explorer-import-dialog.ts`**:
     - a server file, or a local file read with `FileReader`, accepting `.xml,.cls,.mac,.inc,.int`;
     - a Compile checkbox, checked by default;
     - the consequence line;
     - a file above 3,000,000 characters refused with the `TOOLARGE` sentence before anything is sent.

     Both dialogs follow the task dialogs' inputs: `store`, the field reasons, `refusal` and `sending`. The page owns one `AllowedDirectoriesStore`, loaded when either dialog opens, as the task schedule page does.
   - **`code-list.page.ts`**:
     - register `export` as a checked-set action, and Import through `TASK_IMPORT_ACTION_ID`;
     - pin `scope` at the send;
     - send `export` or `export-browser` over the checked set, or `import` or `import-local` with the target `import`;
     - on an export to this browser, save `output.lines` joined by LF through `saveText` as `<NAMESPACE>-export.xml`;
     - show the import's names and lines in the output pane with a status line;
     - route `PATH.*` onto the picker's fields and show other refusals, the version one included, in the dialog;
     - widen the `checkedNames()` guard to cover the new dialogs.
   - **`code-list.store.ts`**: widen `CodeListWrite`'s `kind` to `export` and `import`.
   - **DW-1932**: the Routines list's delete warnings drop the persistent-class sentence (two new keys).
9. `core/strings.ts` gets new keys only, appended after :4293, plus the two in-place sentence edits (:4277, :4283). The copy for each is under Design Notes.
10. EXPERIENCE.md:
    - :173's closed dialog set gains "export documents and import documents (the checked rows, or a file, on Classes and Routines, Story 19.13)" in place;
    - :590's two sentences are edited in place;
    - new Fixed-strings rows go after :590;
    - move every citation the suites hold;
    - run `bash scripts/lint-docs.sh` and `cd ui && npm run test:tools`.
11. Rosters: update each one under Code Map › Rosters, with every new name read from the instance.
    - `DeveloperFloor.TOOLS` gains the two export tools, and :427 becomes "the writes held are exactly the two exports".
    - `ToolEmit` exempts the export tools from `CodeResource():WRITE`.
    - `ExplorerDescriptor`'s method becomes `TestTheAreaHoldsFourReadsAndEightWrites`.
    - Rebase the bundle warning if the build exceeds it (DW-1166).
12. Tests. Each class stays at about 500 lines or fewer.
    - **New `Test/ExplorerTransferProbe.cls`**: `ExplorerProbe` with `OcuProbe1913` parameters, plus helpers that make and remove `<manager directory>OcuProbe1913/`.
    - **New `Test/AtelierPortTransfer.cls`** (in process, live vendor in USER, with the `HighestVersion` seam):
      - every port row of the matrix;
      - the UDL header rule, each example under Design Notes plus a header that does not parse;
      - `selected` sent as listed;
      - the version legs at 6, where compile and delete still read;
      - `Snippet` for each new type;
      - the namespace restored.
    - **New `Test/ExplorerTransfer.cls`** (HTTP and agent):
      - AC1's server round trip and its browser-to-local round trip, through screen actions;
      - the agent's export and import mint and confirm, with the import key enabled through its stored setting and then restored, as `GovernanceRestore` does;
      - `OCUPILOTCODE` on both callers, and the export of an own-code class allowed;
      - `UNREADABLE` leaving no stub; `CHANGED`;
      - the tool result and the ledger free of output.
    - **`Test/AtelierPortWriteDenial.cls`** (already armed): add import refused without routines WRITE; a `%Developer` importing in USER and refused in HSCUSTOM; and that principal exporting to the browser in HSCUSTOM.
    - **`code-list.page.spec.ts`**: both dialogs, scope pinning, the saved name, the local-size refusal, and the version refusal shown.
    - **`ui/tools/proposal-view.test.mjs`** and the `core/csv` test: the new codes and `saveText`.
    - **New `ui/browser/system-explorer-transfer.browser-spec.mjs`**:
      - USER probe documents created in setup;
      - a server export, then a delete, then a server import, with the rows back;
      - a local import through the file input;
      - the two dialogs walked by `structural()`, light and dark.

- [x] [CI] browser shard 1/3, run 37012695762 (head 1291b759): `ui/browser/system-explorer-transfer.browser-spec.mjs:182` timed out waiting for `input[data-explorer-import-file]` -- intermittent: the implement head's run passed it, and one of four local runs on `ocupilot-a2-ci` failed the same way (36 s) right after a redeploy. Find the race (the dialog's source switch and the local-file input's rendering, the spec's wait, or the review's `setSource` change at `explorer-import-dialog.ts`), fix it at its cause in the dialog or the spec, and prove it with five consecutive green runs of that spec file on `ocupilot-a2-ci` against a rebuilt and redeployed bundle, one run per call. Write or update its `mutation:` line.

**Acceptance Criteria:**

- **AC1 (epic criterion 1, 19.2's AC4 verbatim).** Given probe documents exported to a server file, when they are deleted and then imported from that file, then each document's `GET doc` source equals what it was before. The same holds for an export to this browser imported as a local file. Each write goes through a confirmed proposal from the agent, or through the screen's own action.
- **AC2 (epic criterion 2, 19.2's AC5).** Given an instance whose highest Atelier version is below 7, when export or import runs, then the dialog shows "…answers version 6, and this operation needs version 7…" and nothing was sent. Compile and delete still run.
- **AC3 (Integration, Rule 1).** Given a turn on Classes, when the agent calls `explorer.classes.export` and then, with its key enabled, `explorer.classes.import` on that file, then:
  - each card names the documents, the file and the consequence;
  - confirming writes and then loads them;
  - neither tool result holds an XML or console line.
- **AC4 (gate).** Given a caller with the read pairs and no routines WRITE, when it imports, then it is refused 403 naming that pair, and no document changes. Given a caller without `%Admin_FileSystemAccess:USE`, when it sends `root`, then it is refused naming that pair. Given a `%Development`-only caller, when it exports to this browser, then the export succeeds.
- **AC5 (self-protection).** Given a file holding an `OcuPilot*` document, when either caller imports it, then the answer is `PROHIBITED.OCUPILOTCODE` and nothing changes.
- **AC6 (read before write).** Given an unreadable file, when it is imported, then the answer is `UNREADABLE` and no document, stub included, is created. Given a file or a replaced document changed after `documents` was read, when the write runs, then the answer is `CHANGED` and nothing is loaded.
- **AC7 (registry).** Given the registry after this story, when `ExplorerDescriptor` enumerates `explorer.*`, then it finds four reads and eight writes, the import keys disabled and the export keys enabled. `DeveloperFloor` finds that its writes are exactly the two exports, and the structural walk adds no `structural-baseline.json` entry.

### Review Findings

Code review 2026-10-02 (full-opus; blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor): 64 rows, 15 entries (high 1, med 7, low 7), all patched; 45 rows rejected. Design Notes › The summary and the matrix's AC3 example predate entry 1's digest note.

- [x] [Review][Patch] high, fix-risk med (the summary changes form, every pin on it moves), in-story, AD-6/AC6: `CHANGED` compared names and replaced versions only, so a server file rewritten after the review with the same names loaded code nobody reviewed; the summary now ends ` (sha256 <digest of the file's lines>)` [src/OcuPilot/Port/AtelierPort.cls:1444]
- [x] [Review][Patch] med, fix-risk med (output changes for long lines only), in-story, AC1: the vendor's export answers a line over 32,000 characters as pieces (measured: 40,033 as 32,000 + 8,033), so the file and the browser's lines broke it; `WholeLines` rejoins them [src/OcuPilot/Port/AtelierPort.cls:1169]
- [x] [Review][Patch] med, fix-risk low (test-only), in-story, AC6: no leg rewrote the file after the review; added at the port and on the agent's confirm [src/OcuPilot/Test/ExplorerTransfer.cls:305]
- [x] [Review][Patch] med, fix-risk low (test-only), in-story, AC3: the agent's calls were pinned at the tool's `View`; both now go through `Dispatch.Answer` (governance, schema, pairs, the model's tool result) [src/OcuPilot/Test/ExplorerTransfer.cls:208]
- [x] [Review][Patch] med, fix-risk low (test-only), in-story: a UDL import over an existing document (`ignoreConflict=1`) had no test [src/OcuPilot/Test/AtelierPortTransfer.cls:243]
- [x] [Review][Patch] med, fix-risk low (test-only), in-story: a UDL import with Compile off was never checked to skip the compile [src/OcuPilot/Test/AtelierPortTransfer.cls:304]
- [x] [Review][Patch] med, fix-risk low (test and fixture seam), in-story: `ExportSet`'s cleanup after a failed write had no test [src/OcuPilot/Test/AtelierPortTransfer.cls:399]
- [x] [Review][Patch] med, fix-risk low (test-only), in-story: `TestAnExportWritesTheVendorsLines` compared two exports whose `Export` element stamps its second, red when they straddle one (run 1826); compared unstamped [src/OcuPilot/Test/AtelierPortTransfer.cls:115]
- [x] [Review][Patch] low, fix-risk low, in-story: the matrix row "export above the capture ceiling: 503" had no pin on the export path [src/OcuPilot/Test/AtelierPortTransfer.cls:381]
- [x] [Review][Patch] low, fix-risk low, in-story: the import dialog kept a local file across a source switch and sent it under an empty input [ui/src/app/areas/system-explorer/explorer-import-dialog.ts:143]
- [x] [Review][Patch] low, fix-risk low, in-story: the Routines list's Export label had no test [ui/tools/screen-actions.test.mjs:133]
- [x] [Review][Patch] low, fix-risk low, in-story: the "Beta's version" assertion passed when the read answered nothing [src/OcuPilot/Test/AtelierPortTransfer.cls:160]
- [x] [Review][Patch] low, fix-risk low, in-story: the export tools told the model the XML "is shown to the user"; the agent's export writes the file [src/OcuPilot/Screen/Tool/ExplorerClassExport.cls:9]
- [x] [Review][Patch] low, fix-risk low, in-story: `TYPEEXPORTDOCS` called `root` and `path` empty (they are `null`) and `DOCUMENTSKEY` cited no such method [src/OcuPilot/Port/AtelierPort.cls:98]
- [x] [Review][Patch] low, fix-risk low, in-story: `TASK_IMPORT_ACTION_ID`'s and the command bar's comments named Task schedule alone [ui/src/app/core/screen-actions.ts:44]

Rejected:

- `false`: CSP or global items in an XML file pass the code arm (4 rows) — probed: `xml/list` names OcuPilot's served files `ocupilot/<file>` and its globals `OcuPilot*.gbl`, both refused.
- `false`: `LoadXMLFiles` answering no entry reads as success — the route pushes one entry per file sent (v7 :307).
- `false`: the code arm keys import on the target literal — the port refuses another id for import types, and `import` fails `SetNames` for a set.
- `false`: `CheckExport` does not check as `ExportSet` does — it checks the file the same way; pairs and version are the mint's fresh read.
- `false`: `Invoke`'s refusal list is incomplete — it names the methods that document their codes.
- `low`, spec-bound: Compile off sends `""`, not `-c` (2 rows) — the intent specifies `""`; real only where default qualifiers compile.
- `low`, spec-bound: a local file near the limit can pass the longest string as JSON (2 rows) — named limitation.
- `low`, spec-bound: an export of 3.0–3.6 million characters re-imports `TOOLARGE`, and a large set reaches the ceiling (2 rows) — both limits are the spec's.
- `low`, spec-bound: one request loads and compiles a file — named limitation (504).
- `low`, spec-bound: "with compile errors" also covers a save error or a file status (2 rows); no singular forms (2 rows); "proposed" on the screen path — specified copy.
- `low`: FileReader race, no `onerror`, no pre-read size check (3 rows) — two picks inside one read or a failing read; each fix adds a guard.
- `low`, spec-bound: UTF-8 whatever the declaration; no preview on the screen (2 rows, AD-53's dialog review); no document cap; no running status for export; `created` on `import` and `updated` for export (3 rows, `TaskImport`'s precedent); a `/* */` banner is `UNREADABLE`; `saveText` beside an unchanged `saveCsv`.
- `low`: EXPERIENCE.md :589-:590 markers, and the +2 citation drift (pre-existing) (2 rows).
- `low`: radios without a group name; `overflow-wrap` on a file input; no final line feed in the browser file; schema descriptions and file keys declared twice (2 rows); routine tools not minted; no browser download leg; an unasserted setup export; the status line's root join (Task schedule's precedent).
- `low`: a locked document's `PUT` answers 500; an export a few kilobytes under the ceiling can fail at the response write (shared `Api/Response`) — rare, each fix adds a branch.

Code review 2026-10-02, rework re-review of `18d5533c..fb7be227` (full-opus; four layers): 27 rows, 11 entries (high 0, med 0, low 8, false 3); 3 patched, 8 rejected. The `[CI]` item is fixed at its cause in the spec. The held-read harness now proves the wait (below).

- [x] [Review][Patch] low, fix-risk low (tracking line), in-story, Rule 19: the recorded mutation reddens with the old wait too, so the wait had no discriminating red. A held-read harness reddens the pre-rework wait and leaves `pickerRoot` green [spec `## Verification`, `[CI]` block]
- [x] [Review][Patch] low, fix-risk low, in-story: the rework triage row said `baseline_commit` marks the story; both baselines are `18d5533c`. Corrected at its origin [spec `## Review Triage Log`, rework row 5]
- [x] [Review][Patch] low, fix-risk low, in-story: DW-1946 gives 64 px for both dialogs, but only the import dialog was measured. A trailer now labels the export figure (inference) [deferred-work.md DW-1946]

Rejected:

- `false`: the green-run counts disagree — the five runs are recorded under `## Verification`; "one more" is a sixth, later run.
- `false`: the wait relies on an unstated ordering — `openTransfer` calls `load()`, which sets `loading` synchronously before the dialog's first render, so a stale picker cannot satisfy `pickerRoot`.
- `false`: three copies of the open-then-wait pattern, and the third has no title wait — the selector is scoped to `.ocu-dialog-body`, and the previous dialog is closed (`dialogOpen()` guard).
- `low`: the product's layout shift remains, the in-story fixes were not weighed, and the rejection rests on an unmeasured likelihood (3 rows) — this is DW-1946 (`wontfix-accepted`). The dialogs are outside the rework range, and the defect is not HIGH.
- `low`: the cycle log's `dev_complete` reads `review_loop_iteration=1` against the frontmatter's 0, and `deferred=0` sits beside DW-1946 `by=harvest`. Both are the lead's log and ledger lines.
- `low`: DW-1946's `reopen_if` is a report, not a probe; it does not name the spec; the task dialogs may share the cause (maybe-false). The entry is terminal and append-only.
- `low`: the cause is stated several times in an oversized spec (2 rows) — partly consolidated by the first patch above; the triage rows and the Auto Run Result are the stage's own records.
- `low`: `pickerRoot` times out bare, before the assertion message or a refusal sentence can show (2 rows); the `[CI]` item names `setSource` for `onSource`. Each is cosmetic.

## Spec Change Log

- 2026-10-02, rework iteration 1 (trigger ci): run 37012695762 red on the transfer browser spec's local-file input wait; one `[CI]` item re-opens the story.

- 2026-10-02, spec gate (lead; footprint by the orchestrator, by=merge_gate): the eight spine amendments applied as tier-1. Option (A) approved for the six roster files Epic 18's 18.16 also edits: proceed now; whichever story reaches feature second unions them at its forward merge (count literals summed from the merged code, sorted lists merged) and re-runs those six classes one at a time before pushing. `Prohibited.cls` hunks approved as disjoint. DW-1932 routed here.

## Review Triage Log

### 2026-10-02 — Review pass

- verdicts: 28 findings — high 0, medium 8, low 6, false 14, maybe-false 0
- findings:
  - `[medium]` `[patch]` A server file over 3,000,000 characters has no test — leg added to `AtelierPortTransfer.TestAFileIsCheckedBeforeAnyRoute` (400 `TOOLARGE`, no route); red under the disabled check (run 1818).
  - `[medium]` `[patch]` A UDL import whose compile fails is never tested for `errors` — `AtelierPortTransfer.TestAUdlFileThatDoesNotCompileIsPutWithErrors` added on the live vendor; red under the disabled flag (run 1818).
  - `[medium]` `[patch]` The code arm is tested with a one-name summary only — `ExplorerTransfer.TestTheCodeArmReadsEveryNameAnImportReviewed` added (own document second of three); red with `ImportedNames` reading one entry (run 1409).
  - `[medium]` `[patch]` The import dialog never shows an instance refusal in a test (AC2's import half) — page-spec leg added for the 501 sentence and a `PATH.*` on the picker; red with `shownRefusal` answering `localRefusal()` alone.
  - `[low]` `[patch]` The Routines set-delete warning (DW-1932) has no test — page-spec leg added; red with the Classes sentence restored.
  - `[medium]` `[patch]` The agent's mints never refuse a bad file in a test — `ExplorerTransfer.TestTheMintsRefuseTheFileTheWriteWould` added (export `DIRECTORY` on `path`, import `PATH.NOFILE`); both legs red with the checks removed (run 1819).
  - `[medium]` `[patch]` The import's file-pair gate has no test — `AtelierPortWriteDenial.TestAnImportOfAServerFileWithoutTheFilePairIsRefusedByName` added; red with `ArgumentPairs` answering `""` (run 1410).
  - `[low]` `[patch]` Nothing checks that the import schema leaves out the local file — `ExplorerTransfer.TestTheImportSchemaAdvertisesNoLocalFile` added (a direct assertion, so patched rather than deferred).
  - `[false]` `[reject]` AC2's compile-and-delete clause has no `mutation:` line — Rule 19 asks one demonstrated mutation per AC; AC2 has three.
  - `[false]` `[reject]` AC3's card and confirm clauses have no `mutation:` line — AC3's pinning test has its recorded mutation (run 1392).
  - `[false]` `[reject]` AC4's file-pair and browser-export clauses have no `mutation:` line — AC4 has recorded mutations (runs 1394, 1395, 1410).
  - `[false]` `[reject]` AC7's floor and structural clauses have no `mutation:` line — AC7 has its recorded mutation (runs 1399, 1400).
  - `[false]` `[reject]` The agent legs call `View` and `Confirm` in process, not dispatch — dispatch's refusal of both import tools at the baseline and the tool staying advertised are pinned by `ToolDispatch` (`EXPLORERDISABLED`); `View` is dispatch's own call target, as in 19.2.
  - `[false]` `[reject]` Several matrix rows are tested at the port, not the screen route — the port is the one seam both callers reach (AD-61), the route adds no logic on these paths, and version 6 is reachable only through the version seam.
  - `[false]` `[reject]` The capture ceiling's 503 has no new test — the ceiling is `Route`'s, pinned for every route by `AtelierPortDocument`; the export adds no code on that path.
  - `[medium]` `[patch]` `TOOLARGE` for a server file is unreached — same root cause and fix as the first row.
  - `[false]` `[reject]` `EXPLORER.DOCUMENT.ABSENT` at the confirm is untested — the confirm's write is the port's `EXPORT`, whose absent refusal `AtelierPortTransfer.TestAnExportWritesTheVendorsLines` pins; the screen and the mint are pinned by `TestAnExportNamingAMissingDocumentIsRefused`.
  - `[medium]` `[patch]` A real compile failure is covered only by canned routes — same root cause and fix as the second row.
  - `[low]` `[patch]` UTF-8 is not distinguished, since the probes are ASCII — `AtelierPortTransfer.TestFilesAreReadAndWrittenAsUtf8` added (a server file read and an export written, checked as bytes).
  - `[low]` `[reject]` `CHANGED` compares the summary, so a content-only change goes undetected — the matrix row and Design Notes › The summary define the comparison; a content hash is a spec change, and the sentence shows only when the summary differs.
  - `[low]` `[reject]` "Never stored or logged" for a local file has no test — `ScreenAction` writes no ledger row and logs no value, and the agent half is pinned by the closed-schema leg; a log-scraping test adds machinery for a property no path violates.
  - `[false]` `[reject]` The agent's own-code import is refused at the confirm, not at the mint — the intent asks for the refusal on both callers, and 19.2's compile and delete refuse at the same `Operation.Gate` point.
  - `[false]` `[reject]` Every import type is gated at 7, a UDL import too — AC2 requires import to answer the version-7 sentence; the diff implements that reading.
  - `[false]` `[reject]` A failed `PUT` also sets `errors` — no bad outcome: the document is left out of `imported` and the vendor text is logged.
  - `[false]` `[reject]` EXPERIENCE.md is edited above :591 — the in-place citation moves are required by inserted rows; the one wrong move (`prd.md` :698) was reverted at verify.
  - `[low]` `[patch]` `AtelierPortWriteDenial`'s new legs name 19.2's probe package and a file directly under the manager directory — the refused export's file moved to `OcuProbe1913/denied.xml`; the class keeps its own probe package, which its setup and teardown remove.
  - `[false]` `[reject]` A failed `PUT` logs the document's name — the spec sends a file `status`'s vendor text to the log; the `PUT` error is that channel, and the name is the caller's own file's.
  - `[false]` `[reject]` DW-1932 sits outside the intent — Task 8 and the spawn prompt route it here.

### 2026-10-02 — Review pass (rework iteration 1, `[CI]`)

- verdicts: 5 findings — high 0, medium 0, low 3, false 2, maybe-false 0
- findings:
  - `[low]` `[reject]` The dialogs' source radios still move up when the allowed-directories read lands, so a click during the read can hit the root `<select>` — a human click inside a local read's window is unlikely, and the fix reserves the shared picker's loading height or re-anchors the shared dialog (new layout rules on shared components); reopen_if a user reports a misclick on the import or export source.
  - `[low]` `[reject]` Same root cause, read as the screen's promise (intent reading R2): no test watches the dialog during the read — as the row above.
  - `[false]` `[reject]` The timing fix has no recorded red — the held-read diagnostic reproduced the miss every time and hit after the picker was drawn; a race cannot redden deterministically by reverting the wait, and the `[CI]` item asks five consecutive greens, recorded.
  - `[low]` `[reject]` carried — AC1's browser half is not driven through the page's save and file input with source equality — same claim as the logged "no browser download leg" row; this diff does not touch it.
  - `[false]` `[reject]` The `[CI]` box is open, the old result reads done, and the two baselines differ — the run's in-flight state: finalize ticks the item and writes the result, and the lead points both baselines at the rework for the scoped re-review.

## Design Notes

**Governing ADs:**

- AD-61 (rules 1, 2, 3, 5, 6, 7);
- AD-21 (sixth case), AD-10, AD-39, AD-22;
- AD-44, AD-51, AD-6, AD-53, AD-55, AD-56, AD-58, AD-59;
- AD-8, AD-13, AD-14, AD-15, AD-29, AD-34, AD-36.

**Measured at plan** (`ocupilot-a2-ci`, 2026-10-02). The probes were a capture probe class in HSCUSTOM plus USER documents `OcuProbe1913.{A,B,C,Bad,Bad2}.cls` and `OcuProbe1913{R,S}.mac`, `I.inc` and `T.int`. All were removed, and USER holds no `OcuProbe1913*` document.

- **T0.1.** The three XML routes, called as `AtelierPort.Route` calls them (fresh stubs, `%SYS.Capture`, the namespace switched around the call), each ran in 10 background jobs of 20 calls: export, list, load with `ck`, and load with `""`. That is 800 calls, with 0 process deaths and all 200. `messages.log` has no signal line. So no `FILEDEVICEROUTES` entry is needed.
- **T0.3.** `PUT doc/<header name>?ignoreConflict=1` answered as follows, and USER gained exactly the named documents:
  - 201 for a class whose `Class` line follows `Include` and `///` lines;
  - 201 for `ROUTINE OcuProbe1913S`, saved as `.mac`;
  - 201 for `ROUTINE …I [Type=INC]` and `[Type=INT]`;
  - 200 for an overwrite.

  The UDL a `.mac` read answers starts `ROUTINE <name>`, with no type.
- **Audit.** With auditing on, three exports recorded no audit row (the latest row was before the run). 19.2's M8 found the same for load and PUT.
- **Vendor details:**
  - `selected` accepts the list's `OcuProbe1913R.MAC`, and `imported` answers it the same way.
  - A load whose compile fails answers 200, names the document in `imported`, sets the file's `status` to `ERROR #5475…`, and its console lines carry the error.
  - A `PUT` of code that does not compile answers 201.
  - `xml/list` answers `ts` -1 for a document the instance lacks.
- **Size.** A real XML export of 77 classes (777,305 characters) is 836,715 as JSON, a ratio of 1.0764. So a 3,000,000-character file fits the 3,641,144-character string inside the screen action's payload.

**The UDL header rule.** Lines before the header are skipped when they are blank, `///…`, a `/* … */` comment, `Include …`, `IncludeGenerator …` or `Import …` [AMENDED 2026-10-02, Story 19.3 code review: the `/* … */` skip]. Keywords match in any case. The name must match the port's class or routine pattern.

```text
Class Pkg.Name Extends %RegisteredObject   -> Pkg.Name.cls
ROUTINE Name                               -> Name.mac
ROUTINE Name [Type=INC]                    -> Name.inc   ([Type=INT] -> Name.int)
anything else                              -> EXPLORER.IMPORT.UNREADABLE
```

**The summary.** One entry per document, sorted by code point and joined by `", "`. Each entry reads `<name> new`, or `<name> replaces <ts>`, where `ts` is the instance's own version: from `xml/list` for XML, from `Docs` for UDL. Because a replaced document's version is in it, a change on the instance between review and write refuses `CHANGED`, so the import never replaces a version nobody reviewed (AD-6). The summary ends with ` (sha256 <digest>)`, the digest of the file's lines, so a file whose text changed after review refuses `CHANGED` even when its document names did not.

**Why two action ids per tool.** `ScreenAction.Values` admits exactly the declared values, each non-empty. A server file and a local file, or a file and this browser, are therefore separate actions of one tool. The page never registers the second id of each pair, so it is never drawn.

**Copy, for the Fixed-strings rows:**

- Labels: "Export"; "Export <n> documents"; "Export 1 document"; "A file on the server"; "This browser"; "Import"; "A file on this computer"; "Compile imported documents".
- Outcomes:
  - "Exported <n> documents to <path>.";
  - "Saved <n> documents as <file>.";
  - "Importing <file>";
  - "Imported <n> documents.";
  - "Imported <n> documents, with compile errors.".
- Consequence: "Importing replaces each document of the same name in this namespace, without asking."
- DW-1932, for the Routines list:
  - "The routine's source and compiled code are removed and cannot be restored from OcuPilot.";
  - "Deletes <n> documents. Each one's source and compiled code are removed and cannot be restored from OcuPilot."

**Proposed spine amendments**, for the lead's spec gate (Rule 20):

1. **AD-61.**
   - Rule 2: the XML routes `ExportToXMLFile`, `ListDocumentsInXMLFiles` and `LoadXMLFiles` need version 7. An export's fresh read and every import type are gated on their routes, so on an older instance the mint, the screen's action and the write are each refused before any call (Story 19.13).
   - Rule 1: "A write the port carries (compile, delete, import)…; an export needs the read pairs alone."
   - Rule 3: a body the port builds is written to the stub's content stream, never held as one string.
   - Rule 5: the XML routes need no file device (T0.1).
   - Rule 6: "…except inside a compile's or an import's output…".
2. **AD-21's sixth case: Story 19.13's consumers.**
   - System Explorer's export is an overwriting `file` consumer whose overwrite is a constant, and it refuses a name whose directory does not exist.
   - Its import is a `source`, read by the port as UTF-8 text of at most 3,000,000 characters.
   - A local file's text is a screen action value, never a path and never in a tool's schema.
3. **AD-15, an eleventh case, and AD-53, an eleventh named gap.** Exporting or importing a class or routine records no vendor event with the stock event set: export was measured with auditing on, 2026-10-02, and load and PUT by 19.2's M8. The classic dialogs' `%System/%SMPExplorer/Export` and `Import` events are disabled by default (19.2's T0.5).
4. **AD-39's fifth exception.** It covers a compile's and an import's console lines, an import's imported names, and an export's XML lines answered to this browser.
5. **AD-10's code arm.** It adds importing a file whose reviewed documents name one, where the port loads exactly the reviewed documents. An export only reads, and is not refused. The sentence is as above.
6. **AD-51, a new named case.** `AtelierPort` builds `ExportToXMLFile`'s body from the set, and the import's list, load and PUT bodies from the file it resolves or the screen's text. It answers the fresh reads through the port-composed `EXPORTDOCS` and `IMPORTTARGET`, and the reviewed documents through `PREVIEW`.
7. **AD-44, Story 19.13's `CLASSICPAGES`.** Export declares `%CSP.UI.Portal.Dialog.Export`, and import declares `%CSP.UI.Portal.Dialog.Import`.
8. **AD-8's System Explorer paragraph.** Import also declares the routines WRITE pair. Export declares no pair beyond the screen's own, so a `%Developer` exports to this browser.

**Integration ACs (Rules 1 and 2).** AC3 is the integration criterion.

- **Consumes:**
  - 19.2's `ExplorerWrite`, `ExplorerMint`, `Docs`, `PresentSet`, `AbsentRefusal`, `documentset`, the `output` channel and the `OCUPILOTCODE` arm;
  - `PathPort`;
  - `Kernel/Proposal` (Mint, Confirm, Operation, Prohibited, ReadBack);
  - `Api/ScreenAction`, the governance gate, `server-path-picker` and `AllowedDirectoriesStore`.
- **Consumed-by:** Story 19.3 may reuse the UDL header rule and the `PUT` path for its save (inference). No other story is planned.

**Ledger inbox.** This story owns no ledger entry. DW-1932's `reopen_if` is met, because this story adds dialogs to the Routines list. Task 8 addresses it, and the lead appends its trailer.

**Footprint (Rule 11).** Checked 2026-10-02. `epic-23` has no diff. `epic-18` (18.16) has only uncommitted changes and one pending implement. Every file below except those under "Not contended" is edited by this story.

- **Contended and not strictly add-only; approved at the spec gate (option A, by=merge_gate): edit now, and the second to reach feature unions these lines at its forward merge and re-runs the six roster classes.** Re-check `git -C /Users/jbrandt/git/OcuPilot/.worktrees/epic-18 diff` plus `status -s` at edit time.
  - `Kernel/Proposal/Prohibited.cls`: :445, :1038-1041 and :1926-1940. Epic 18's hunk is at :2144 and is disjoint.
  - `Test/GovernanceBaseline.cls` :13: the same `DISABLED` line as Epic 18's hunk at :9-15.
  - `Test/ReadTool.cls` :93-94: the same lines as Epic 18's hunk at :90-97.
  - `Test/ToolRoundTrip.cls` :54: the same line as Epic 18's hunk at :50-57.
  - `Test/Governance.cls` :32, :117 and :121, next to Epic 18's hunks at :28-36 and :111-117.
  - `Test/ToolDispatch.cls` :167, next to Epic 18's hunk at :164-170.
  - `Test/ClassicPageGate.cls` :70, next to Epic 18's hunk at :67-73.
- **Contended and add-only:**
  - `Kernel/Governance/Baseline.cls`: appended at :146. Epic 18's hunk is at :48.
  - `Test/SurfaceCoverage.cls`: rows beside :277-280. Epic 18's hunk is at :274-282, so they are adjacent.
- **Not contended:** everything else. That includes the non-additive edits to `AtelierPort.cls`, `AtelierRequest.cls`, `AtelierError.cls`, the two descriptors, `code-list.page.ts` and `.store.ts`, `csv.ts`, `proposal-view.ts`, `screen-actions.ts`, `strings.ts`, EXPERIENCE.md, and the explorer, floor, emit, draft, mapping and mirror tests.
- **Bundle:** expect a rebase under DW-1166. Stop above 3,800 kB.

**Named limitations.**

- An export larger than about 3.6 million characters answers `PORT.UNAVAILABLE`.
- A local file's text sits inside the screen action's JSON payload. If its JSON form passes the instance's longest string, which only text dense in quotes, backslashes or control characters can do within 3,000,000 characters, the action answers 500 (inference).
- An import loads every document the file holds, of any type, and silently replaces same-named documents; the consequence line says so. A UDL file holds one document.
- A large import with compile that outlasts the gateway's 60 s answers 504 while the instance completes it (inference).

**Sizing.** One implement pass, comparable to 19.2's Part A. If it must split, the seam is (a) export, and (b) import.

## Verification

Load source into `ocupilot-a2-ci` without the MCP tools, and never restart it:

1. `rsync -a --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-19/src/ /tmp/ocupilot-a2-ci/src/`
2. In `docker exec -i ocupilot-a2-ci iris session iris -U HSCUSTOM`, run `$System.OBJ.LoadDir("/opt/ocupilot/src","ck",.tErrors,1)`, and check both the status and `tErrors`.

**Run one test-runner call at a time, and wait for each to finish.** Never re-submit after a client-side timeout. Every probe document and file is removed afterwards.

**Commands:**

- `uv run scripts/check-objectscript.py && uv run scripts/test_check_objectscript.py` (loop). Expected: green.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-a2-ci --class OcuPilot.Test.<Class>` (loop), one class per call. Expected: green. The classes:
  - `AtelierPortTransfer`, `ExplorerTransfer`, `AtelierPortWriteDenial`, `AtelierPortWrite`, `AtelierPort`, `ExplorerWrite`, `ExplorerDescriptor`;
  - `ReadTool`, `ToolRoundTrip`, `SurfaceCoverage`, `DraftRegistry`, `GovernanceBaseline`, `Governance`, `ToolDispatch`, `ToolEmit`, `ToolWrite`;
  - `Prohibited`, `ClassicPageGate`, `MappingDescriptor`, `DeveloperFloor`.
- `cd ui && npm run test:tools && npx ng test --include 'src/app/areas/system-explorer/**/*.spec.ts'` (loop). Expected: green.
- Browser (loop). Before each run, build and deploy: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-a2-ci:/durable/iris/csp/ocupilot/`. Then run each file alone with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52780 OCUPILOT_BROWSER_CONTAINER=ocupilot-a2-ci node --test --test-concurrency=1 browser/<file>`, for:
  - `system-explorer-transfer.browser-spec.mjs`;
  - `system-explorer-write.browser-spec.mjs`;
  - `a11y-structural-invariants.browser-spec.mjs`.

  Expected: green, with `structural-baseline.json` unchanged. The full browser suite is CI's.
- `bash scripts/lint-docs.sh && cd ui && npm run test:tools` (loop, after any EXPERIENCE.md edit). Expected: green.
- `cd ui && npm test` (once, before dev_complete). Expected: green, with the bundle warning rebased if the build is over it.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-a2-ci`, the full ObjectScript sweep, one class at a time (once, before dev_complete). Expected: green apart from the residue 19.2's verification names (DW-1425/DW-1468, DW-1759).

**Planned mutations (Rule 19)**, one per AC. Record each as `mutation: <change> → <test that reddened>` as it is observed.

- mutation: AC1, the last exported line removed before `WriteLines` in `AtelierPort.ExportSet` → `ExplorerTransfer.TestTheServerRoundTripRestoresEachDocument` (run 1388), `AtelierPortTransfer.TestAnExportWritesTheVendorsLines` (run 1389).
- mutation: AC1, `content` dropped from `ExplorerImport.ScreenActionDelta`'s value copy → `ExplorerTransfer.TestTheBrowserRoundTripRestoresEachDocument` (run 1390).
- mutation: AC2, `ExportToXMLFile:1` in `MINVERSIONS` → `AtelierPortTransfer.TestAnOlderInstanceRefusesEveryTransfer` (run 1391).
- mutation: AC2, `ExplorerExportDialog`'s refusal rendered on `sending()` instead of `hasRefusal` → `code-list.page.spec.ts` "AC2: a refused export shows the instance's sentence in the dialog".
- mutation: AC3, `output` set on the proposal after `ExplorerImportMint.Mint` → `ExplorerTransfer.TestTheAgentExportsAndImportsThroughConfirm` (run 1392).
- mutation: AC4, `ExplorerExport`'s `PrivilegePairs` given to `ExplorerImport` → `AtelierPortWriteDenial.TestTheToolsDeclareTheRequestNamespacesWritePair` (run 1394); with the port's import write pair also dropped from `AtelierPort.Invoke`'s `tWrite` → `TestAnImportWithoutWriteIsRefusedByName` and `TestADeveloperImportsInUserAndExportsAnywhere` (run 1395).
- mutation: AC5, `Prohibited.Prohibits` arm called on `tId` without the `import` branch → `ExplorerTransfer.TestAnImportOfOcuPilotsOwnCodeIsRefusedOnBothCallers` (run 1396).
- mutation: AC6, `Examine` skipped for an XML file in `AtelierPort.ImportSet` → `ExplorerTransfer.TestAnUnreadableOrChangedFileLoadsNothing`, unreadable leg (run 1397).
- mutation: AC6, the `CHANGED` comparison in `AtelierPort.ImportSet` made `If 0` → `ExplorerTransfer.TestAnUnreadableOrChangedFileLoadsNothing`, changed leg (run 1398).
- mutation: AC7, `"explorer.classes.import": true` in `Baseline.cls` → `ExplorerDescriptor.TestTheAreaHoldsFourReadsAndEightWrites` (run 1399), `ExplorerTransfer.TestTheBaselineShipsTheImportsDisabled` (run 1400).
- mutation: AC2, `ExplorerImportDialog.shownRefusal` answering `localRefusal()` alone → `code-list.page.spec.ts` "AC2: a refused import shows the instance's sentence in the import dialog…".
- mutation: AC4, `ExplorerImport.ArgumentPairs` answering `""` → `AtelierPortWriteDenial.TestAnImportOfAServerFileWithoutTheFilePairIsRefusedByName` (run 1410).
- mutation: AC5, `Prohibited.ImportedNames` reading only the summary's first entry → `ExplorerTransfer.TestTheCodeArmReadsEveryNameAnImportReviewed` (run 1409).
- mutation: AC6 and the matrix, `If tTooLarge` and `If tCompileErrors` disabled in `AtelierPort` → `AtelierPortTransfer.TestAFileIsCheckedBeforeAnyRoute` and `TestAUdlFileThatDoesNotCompileIsPutWithErrors` (run 1818); the `CheckExport` call and the preview's refusal check removed from the two mints → `ExplorerTransfer.TestTheMintsRefuseTheFileTheWriteWould`, both legs (run 1819).
- mutation (review): AC6, the digest note dropped from `AtelierPort.Examine` → `AtelierPortTransfer.TestAnXmlImportLoadsWhatItsPreviewNamed` "a file whose text changed under the same documents is refused" (run 1833) and `ExplorerTransfer.TestAnUnreadableOrChangedFileLoadsNothing` "the confirm of a file rewritten after the mint is refused as changed" (run 1835).
- mutation (review): AC1, `AtelierPort.WholeLines` answering the vendor's lines unchanged → `AtelierPortTransfer.TestALongLineIsExportedWhole` (run 1840).
- mutation (review): AC3, `Compile` dropped from `ExplorerImport.InputSchema` → `ExplorerTransfer.TestTheAgentExportsAndImportsThroughConfirm` "the agent's import call is minted through the dispatcher" (run 1834).
- mutation (review): matrix, in one recompile of `AtelierPort`: `ignoreConflict` renamed → `TestAUdlFileIsPutAndCompiled` "a second text of the class replaces it"; the UDL compile made unconditional → `TestFilesAreReadAndWrittenAsUtf8` "without compiling"; `ExportSet`'s delete disabled → `TestAFailedExportWriteDeletesOnlyTheFileItCreated` first leg; `ExportSet` carrying on after a failed route → `TestAnExportAboveTheCeilingIsUnavailable` (all `AtelierPortTransfer`, run 1832); its `tAbsent` guard dropped → the cleanup test's second leg (run 1833).
- mutation (review): `ExplorerImportDialog.onSource` keeping `local` → `code-list.page.spec.ts` "a local file read before the source was switched away and back is not sent…"; `export` dropped from `ExplorerRoutineList`'s labels → `tools/screen-actions.test.mjs`. Every mutation reverted with the tree byte-identical; final runs green: `AtelierPortTransfer` 1841, `ExplorerTransfer` 1842, `AtelierPortWriteDenial` 1843, `AtelierPortWrite`, `npm run test:tools` 1772/1772, system-explorer specs 34/34, `system-explorer-transfer` browser spec on the rebuilt bundle.

**`[CI]` run 37012695762.** Cause: the import dialog opens with the allowed-directories read in flight; its answer grows the picker and re-centres the dialog, moving the source radio up 64 px, so a click whose point is taken before the answer and pressed after it lands on the picker's `<select>` and the file input never renders. Fix: the local leg presses the radio once `pickerRoot` has drawn the picker. No client code changed.

- mutation: AC1, `ExplorerImportDialog.onSource` setting the source to `server` whatever was chosen → `system-explorer-transfer.browser-spec.mjs` red at its file-input wait (:240) on the rebuilt bundle; reverted byte-identical (blob d832e765), rebuilt to the same `main-EUGSEAEJ.js`, redeployed. It pins AC1's local leg, not the wait.
- mutation (review), the wait: a scratch harness held the `security.alloweddirectories` read and released it when `page.mouse.click` was entered, after the click point was taken (else after 1.5 s). With the pre-rework radio wait restored → red at the file-input wait, the radio's top 397 → 333 px; with `pickerRoot` → green. The spec file was restored byte-identical (blob 656b3d0d), and HEAD ran green on the redeployed `main-EUGSEAEJ.js` beforehand.
- Five consecutive runs of `system-explorer-transfer.browser-spec.mjs` on `ocupilot-a2-ci` against that bundle, one per call: 1/1 green each (6.7-6.8 s). System-explorer component specs 34/34.

## Auto Run Result

Status: done
Blocking condition: none

**Rework iteration 1 (`[CI]`, run 37012695762).** Change: the transfer browser spec's local leg waits for the import dialog's drawn picker (`pickerRoot`) before pressing the local-source radio, since the allowed-directories answer re-centres the dialog and moved the radio under a click taken before it (`ui/browser/system-explorer-transfer.browser-spec.mjs` :236-238); no client or server code changed. Review (verification-gap, intent-alignment): 5 findings, none patched or deferred; 3 low rejected (the product's layout shift during the read, twice; AC1's browser half carried) and 2 false, reasons in the triage log. Follow-up review: false (follow-up pass, no high patched). Verification: the mutation and five consecutive green runs under `## Verification`; system-explorer component specs 34/34; one more green run after a rebuild and redeploy (`main-EUGSEAEJ.js`). Residual risk: the dialogs' radios move when the directory read lands (rejected low, reopen_if in the triage log).

**Change.** Export of the checked set (to a server file, or to this browser) and import of an XML export or one UDL document (from a server file, or a local file) on the Classes and Routines lists, through `AtelierPort`'s new `EXPORTDOCS`, `EXPORT`, `IMPORTTARGET`, `PREVIEW` and `IMPORT` types and four action-style tools reached by the agent and the screen; the import reads before it writes, refuses `CHANGED` against its reviewed summary, and is refused `OCUPILOTCODE` for OcuPilot's own documents; DW-1932's Routines delete sentences.

**Files.**

- Port: `Port/AtelierPort.cls` (the five types, file resolve, UDL header rule, summary, script forms), `Port/AtelierRequest.cls` (object body), `Api/AtelierError.cls` (`EXPLORER.EXPORT.DIRECTORY`, `CHANGED` reworded).
- Tools: `Screen/Tool/ExplorerExport.cls`, `ExplorerExportMint.cls`, `ExplorerImport.cls`, `ExplorerImportMint.cls`, `Explorer{Class,Routine}{Export,Import}.cls`.
- Kernel: `Kernel/Proposal/Prohibited.cls` (export not judged, import judged by its summary's names, reason), `Kernel/Governance/Baseline.cls` (export keys on, import keys off).
- Descriptors: `ExplorerClassList.cls`, `ExplorerRoutineList.cls` (four row actions, `export` extra action); `ui/src/app/core/screens.generated.ts` regenerated.
- Client: `explorer-export-dialog.ts`, `explorer-import-dialog.ts` (new); `code-list.page.ts`, `code-list.store.ts`, `core/csv.ts` (`saveText`), `core/proposal-view.ts`, `core/screen-actions.ts`, `core/strings.ts`, `styles/_components.scss`; `ui/angular.json` warning 2447kB (measured 2,446,524 bytes).
- Tests: `Test/AtelierPortTransfer.cls`, `ExplorerTransfer.cls`, `ExplorerTransferProbe.cls` (new); `AtelierPortWriteDenial.cls`, `AtelierPortFixture.cls`; roster updates in `ReadTool`, `ToolWrite`, `ToolRoundTrip`, `GovernanceBaseline`, `Governance` (`EXPLORERDELETES` is now `EXPLORERDISABLED`), `ToolDispatch`, `DeveloperFloor`, `ToolEmit`, `Prohibited`, `ClassicPageGate`, `MappingDescriptor`, `SurfaceCoverage`, `ExplorerDescriptor`; `code-list.page.spec.ts`; `ui/browser/system-explorer-transfer.browser-spec.mjs` (new); `ui/tools/{csv,proposal-view,screen-mirror,self-protection,angular-json}.test.mjs`.
- Docs: EXPERIENCE.md :173 and :590 in place, rows :591-592, citations above :590 moved by 2.

**Review.** 28 findings (triage log): 12 patched, all test-side (8 medium, 4 low), each patched leg's red observed under a named mutation; 16 rejected with their reasons in the log; none deferred. Before review, the matrix audit added two legs (an XML file listing no document; an export naming a missing document at the screen and the mint), and one wrong citation move (`prd.md` :698) was reverted. Follow-up review: false (patched: high 0, medium 8 in 6 entries, low 4); every patch is a test whose mutation was demonstrated, so no unverified risk can be named.

**Verification.** `check-objectscript` 0 problems, its harness 144/144; `lint-docs` and `check-prose` clean; `npm run test:tools` 1772/1772; `npm test` 1772 + 2098 component tests (155 files); `ng test` system-explorer 33/33; browser `system-explorer-transfer`, `system-explorer-write`, `a11y-structural-invariants` green on the final bundle with `structural-baseline.json` unchanged (handoff pass; no client source changed since). Full ObjectScript sweep on `ocupilot-a2-ci` after a clean `LoadDir`: 407 classes, 3,351 tests, 0 failed, every class in exactly one of 30 sequential legs (`ci-shards check`); no residue. `AtelierPortTransfer` (run 1820) and `ExplorerTransfer` (run 1821) re-run green after the last mutation revert. No probe document, file or enabled import key left on the throwaway.

**Residual risks.** `CHANGED` compares the reviewed summary, so a server file whose content changes with the same documents imports unreviewed content (by design, Design Notes › The summary). Named limitations stand (export above about 3.6 million characters; a local file dense in escapes; a 504 on a long compile).

**Merge notes (Rule 11).** The bundle-warning literal (`ui/angular.json` :54 and its pin) is also raised by Epic 18's 18.16: re-measure at the forward merge. Contended rosters to union then: `GovernanceBaseline`, `ReadTool`, `ToolRoundTrip`, `Governance` (renamed parameter), `ToolDispatch`, `ClassicPageGate`; add-only: `Baseline.cls`, `SurfaceCoverage.cls`; adjacent: `proposal-view.ts`, `strings.ts`, EXPERIENCE.md; regenerate `screens.generated.ts`.

QA pass (19.13): no test added, every AC and matrix row already holds a real-runtime pin. The Rule 19 mutation lines above stand.

- mutation: AC7 (QA, re-demonstrated), `"explorer.classes.import": true` in `Baseline.cls` -> `ExplorerTransfer.TestTheBaselineShipsTheImportsDisabled` and `TestTheAgentExportsAndImportsThroughConfirm` (run 1824); reverted byte-identical (sha1 52337c84), recompiled, `ExplorerTransfer` green again.
