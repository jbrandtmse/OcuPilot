---
title: 'Story 19.2: Compile, delete, export and import'
type: 'feature'
created: '2026-10-01'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-19-context.md'
warnings: ['oversized', 'multiple-goals']
deferred: []
---

<intent-contract>

## Intent

**Problem:** System Explorer is read-only. A developer can browse a namespace's classes and routines but cannot compile, delete, export or import them, which the classic Classes and Routines pages do (catalog rows EX-05 to EX-08).

**Approach:** Add the area's first write tools on `Port/AtelierPort`: compile, delete, XML export and import for each of the Classes and Routines lists. Each tool is reached by two callers, the agent's confirmed proposal and the list's own action (AD-53, AD-55), over the checked rows. The screen streams compile output one document per request. Export and import reach server files through `PathPort`, and the browser through the action's answer and the request body.

The work splits at a seam. **Part A** is compile, delete, DW-1922 and the write plumbing, and is this story. **Part B**, export and import (AC4, AC5), moved to Story 19.13 at the spec gate (split 2026-10-02, by=merge_gate); every item marked `[B]` or `(19.13)` below is that story's, not this one's.

## Boundaries & Constraints

**Always:**

- **One port.** Every write goes through `AtelierPort.Invoke`, which calls `%Api.Atelier.v<min(N,8)>`'s route methods by the AD-61 recipe and names them only through parameters. The literal `%Atelier` stays out of `src/` and `ui/`.
- **The port gates before any vendor call (AD-29, measured).** Compile, delete and import require the read pairs (AD-61 rule 1) plus WRITE on the namespace's routines-database resource. Export requires the read pairs alone, plus `PathPort`'s pairs for a server file. The source code API checks no WRITE itself. It answers a missing privilege as a soft error (#5838, #5883, #302) and never as `<PROTECT>`.
- **The tools declare those pairs.** The WRITE pair is resolved in `PrivilegePairs` for `Kernel.Scope.Current()`'s namespace, which outside a request is `$Namespace`. `PathPort`'s pairs come from `ArgumentPairs`, only when `root` is sent. So the mint and the screen action refuse a caller without them by name before any port call (AD-8).
- **Every agent write is a proposal (AD-6).** Each tool is action-style (AD-51, `SENDSBODY` 0). The port builds the vendor body from the tool's declared arguments, and each tool declares a fingerprint subject over the fresh read. The prohibited set, the per-target lock (AD-34), the read-back (AD-58), the change event, the marker and the ledger are the shared operation's (`Kernel/Proposal/Operation.cls`).
- **Targets are sets.** A compile, delete or export target is a set of document names, joined by commas into one id under the `class` or `routine` entity type (AD-13). An import's target is the literal `import`, as `TaskImport`'s is. A set holds at most 100 documents, on both callers.
- **Vendor console text reaches the screen only.** A compile's or import's console lines travel as `output` on the screen action's answer and the confirm's answer, are rendered as text on the code surface, and never reach the model, a tool result, a ledger row, a log line or screen context (the AD-39 exception proposed under Design Notes).
- **Governance (AD-22).** `Kernel/Governance/Baseline.cls` gains this story's four keys in the same change: the compile keys `true`, the delete keys `false`. Story 19.13 adds the export keys `true` and the import keys `false` (an import silently replaces existing code, measured).
- **Self-protection (AD-10).** A delete, a compile, or an import touching a document whose name begins with `OcuPilot` (case-insensitive), in any namespace, is refused `PROHIBITED.OCUPILOTCODE` on both callers. For an import, the documents checked are the ones the file holds, read at the write.
- **The XML routes carry the version gate.** `ExportToXMLFile`, `ListDocumentsInXMLFiles` and `LoadXMLFiles` each declare a minimum of 7 in `MINVERSIONS`. An older instance is refused 501 `PORT.NOTIMPLEMENTED`, naming both versions, before any call (AD-61 rule 2).
- **Server files follow `PathPort` (AD-21, sixth case).** Export is an overwriting `file` consumer, with the overwrite a constant; import is a `source`. Both resolve again at the write.
- **Every probe and test that writes runs on `ocupilot-a2-ci`, against documents it created itself.** Class probes go in package `OcuProbe192`, routine probes in `OcuProbe192*`.

**Never:**

- No call to `work` (`QueueAsync`/`PollAsync`/`CancelAsync`). Its poll checks no owner, and its queue also runs a caller-named routine (`testrtn`), measured.
- No `docnames` `filter`, and no `POST modified` (AD-61 rule 7). No caller-supplied path. No new third-party library, and no new code in `Api/Error.cls`: new codes go in `Api/AtelierError.cls`.
- No free-text compiler flags. The flags are always `c` plus three booleans: `k` keep generated source, `b` compile dependents, `u` skip up-to-date.
- No `content` argument in a tool's input schema. A local file's content is a screen-only value, and the agent never authors code.
- Never insert into EXPERIENCE.md above line 589 or into DESIGN.md. Fixed-strings rows are appended after :588 and the new dialogs join the closed set at :173 in place, with every citation the suites hold moved (`npm run test:tools`).
- Never write to `ocupilot`, any `ocupilot-slot-*`, `ocupilot-b-ci` or `iris-community-edition`, and never restart or tear down `ocupilot-a2-ci`.

## I/O & Edge-Case Matrix

Routes are `POST /screens/explorer.classes/action` (or `explorer.routines`) and `POST /proposal/:id/confirm`.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Compile, one document | action `compile`, id `OcuProbe192.Sub.cls`, values `{KeepSource:true, CompileDependents:false, SkipUpToDate:true}` | 200 `{action:"updated", target, readBack:{verdict:"nothingSent"}, output:{lines:[…], errors:false}}`. The vendor received `flags=cuk` | none |
| Compile with errors | a probe class with a syntax error | 200, `output.errors` true, and every error line is in `output.lines`. `status.errors` holds only the first error, so `lines` is the source (measured) | not a fault |
| Screen compile, N checked | 12 rows checked, Compile confirmed | 12 sequential actions, one id each, in list order. The output pane appends each answer's lines as it arrives, the status line reads "Compiling 3 of 12 · <name>", and a summary line ends it. Stop sends no further request | an error answer is written into the pane and the sequence continues |
| Agent compile (AC3) | `explorer.classes.compile {Names:"A.cls,B.cls", KeepSource, CompileDependents, SkipUpToDate}` in a turn | A proposal whose diff names the documents and the flags. Confirm compiles both in one call and answers `output`, which the card renders as text | the model's tool result holds no console line |
| Delete set | action `delete`, id `A.cls,B.cls` (canonical: unique, sorted by code point) | Source and compiled code are removed. A persistent class's data globals stay (measured, as on the classic page). `output.documents[]` is `{name, deleted, reason}`, the read-back verdict is `notFound`, and the list re-fetches | none |
| Delete, one item refused | the vendor answers an item 5883, 302 or 5864 | 200 with that item `deleted:false` and a port-owned reason; the vendor text is logged. The read-back verdict is `present` (`ReadBackGone` false while any name survives) | not a fault |
| Document gone | a named document is absent at the fresh read (mint or write) | 404 `EXPLORER.DOCUMENT.ABSENT` naming it. Nothing is sent | none |
| No routines WRITE | the caller holds the read pairs but not `<routines resource>:WRITE` | 403 `AUTH.NOPRIVILEGE`, `detail.failedPair` naming that pair, with no vendor call. A `%Developer` passes in `USER` (`%DB_USER:RW`) and is refused in `HSCUSTOM` | none |
| OcuPilot's own code | any target, or any document an import file holds, whose name begins with `OcuPilot` | 403 `PROHIBITED.OCUPILOTCODE`, on both callers. Nothing changes | none |
| Delete key disabled | the agent calls `explorer.classes.delete` with the baseline in force | Refused by the governance gate: a structured result, and the tool stays advertised (AD-22) | none |
| Set too large | more than 100 names | 400 `TOOL.ARGUMENTS` (mint) or `PORT.VALIDATION` (port), before any call | none |
| (19.13) Export, server file | action `export`, values `{destination:"server", root, path}` | The vendor `xml/export` lines are written as UTF-8 to the resolved file, replacing an existing one. `output` is `{file:"<relative name>"}` | `PATH.ROOT`/`PATH.NAME` per `PathPort` |
| (19.13) Export, this browser | values `{destination:"browser"}` (screen only; the agent schema admits `server` alone) | No file is written. `output` is `{name:"<namespace>-export.xml", lines:[…]}`, which the page saves | an answer above the capture ceiling is 503 `PORT.UNAVAILABLE` |
| (19.13) Export, one name missing | a set naming a deleted document | `EXPLORER.DOCUMENT.ABSENT` from the fresh read. The vendor would void the whole export (#6308, measured) | none |
| (19.13) Import, server file | `{source:"server", root, path, compile:true}`, an `.xml` export | `xml/list` first: a per-file error or zero documents is refused `EXPLORER.IMPORT.UNREADABLE` before `xml/load` (malformed XML leaves a stub class otherwise, measured). Then `xml/load` with `selected` set to the listed names and `flags` `cuk` or `""`. `output` is `{imported:[…], lines:[…]}` | none |
| (19.13) Import changed | the agent's file holds different documents at the confirm | 409 `EXPLORER.IMPORT.CHANGED`; nothing is loaded | none |
| (19.13) Import, local file | the screen sends `{source:"local", fileName, content}` (≤ 3,000,000 characters; the page refuses larger files first) | As for a server file, from the sent text | 400 `EXPLORER.IMPORT.TOOLARGE` |
| (19.13) Import, UDL document | a `.cls`, `.mac`, `.inc` or `.int` file | The document name is read from its header line (`Class <name>` or `ROUTINE <name>`), then `PUT doc/<name>?ignoreConflict=1`, then a compile when asked. A header that does not parse is `EXPLORER.IMPORT.UNREADABLE` | none |
| (19.13) Old instance | the version seam answers 6 | Export and import answer 501 `PORT.NOTIMPLEMENTED`, "…answers version 6, and this … needs version 7…", with no call. Compile and delete are unaffected | the dialog shows the reason |
| DW-1922 | Routines viewer, `EnsJob.mac` (object code only) | 200. The routine row is present, and `document.available` false with `reason:"objectonly"`. The viewer says the instance holds only the routine's object code. A truly missing name stays 404 `PORT.NOTFOUND` | the two 404 bodies differ: `result.status` "" with `ts` "" against #16005 (measured) |

</intent-contract>

## Code Map

### Server

- `src/OcuPilot/Port/AtelierPort.cls` (1,084 lines). Members it gains or changes:
  - `Invoke` :338. Its type check :386 admits only `LIST`.
  - `MINVERSIONS` :42 and `MinVersion` :300, which pick routes by endpoint.
  - `Route` :861, which handles only the `pArg` and `pParams` shapes.
  - `Outcome` :981, which keeps `result` and drops `console`.
  - `Document` :610, where DW-1922's 404 lands.
  - `NamespacePairs` :281 and `DatabaseResources` :233, which carry `RoutineDB.Resource`.
  - `SnippetForm` and `Snippet` :1073-1082, which answer nothing for any write today. `Test/DraftRegistry.cls` :122 and :214 enforce them.
- `src/OcuPilot/Port/AtelierRequest.cls` holds the JSON body stub, which suits compile, delete, export, list and load.
- `src/OcuPilot/Screen/Tool/Write.cls`:
  - parameters: `DESTRUCTIVE` :52, `READTYPE` :57, `WRITETYPE` :62, `FINGERPRINTSUBJECT` :97, `PORTCLASS` :114, `SCREENACTIONS` :167, `SCREENVALUES` :217;
  - hooks: `PortQuery` :440, `ReadBackGone` :279, `FieldRows` :680, which emits no fields for a bodyless tool.
  - `Screen/Tool/Base.cls` holds `PrivilegePairs` :92 and `ArgumentPairs` :123.
- Precedents in `src/OcuPilot/Screen/Tool/`:
  - `TaskExport.cls` and `TaskImport.cls`, with `TaskImportMint.cls` :29-42: file arguments, a literal `import` target, and a reviewed summary in the fingerprint.
  - `ProcessBroadcast.cls`: a set target and `StateDiff` :237-266.
  - `LockRemove.cls`: destructive, `deleted`.
- `src/OcuPilot/Port/TaskTransferPort.cls`:
  - `EXPORTOVERWRITES` :69, `CheckExport` :186, `Locate` :215 into `PathPort.Resolve`;
  - the `CHANGED` refusal :306-321;
  - `COMPOSEDTYPES`, which `Test/Prohibited.cls` :401 reads.
- `src/OcuPilot/Kernel/Proposal/Operation.cls`: `Hold` :57, `Read` :297, `Gate` :343, `Apply`/`ApplyAt` :402/:418.
- The write is applied, and its answer composed, in two places:
  - the screen path, `src/OcuPilot/Api/ScreenAction.cls` `Run` :220-380: `Apply` :346, the answer :370-378;
  - the confirm path, `src/OcuPilot/Kernel/Proposal/Confirm.cls`: `ApplyAt` :459, the answer :840-866.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls`:
  - `COVEREDTYPES` :250 lacks `class` and `routine`, so their writes are refused `UNCOVERED` today;
  - `Codes` :658, `ReasonFor` :666, `Prohibits` :984 with its type routing at :995;
  - `OwnNameStems` :2227 and `OWNGLOBALPREFIX` :429.
- `src/OcuPilot/Kernel/EntityRef.cls`: `IDRULES` :59, `IDRULENAMES` :64, `NormalizedId` :273. The precedents are `process:integerset` and `database:directoryset`.
- `src/OcuPilot/Screen/Registry.cls`:
  - `MultiSelectProblem` :3703-3790, with its sentences pinned by `Test/MultiSelectCorpus.cls`;
  - :2458-2466, which require a write-capable list's `table.emptyNextKey` to be `""` and its `emptyAgentKey` to be non-empty. `ExplorerClassList.cls` :72-73 is the reverse today.
- `src/OcuPilot/Screen/Descriptor/ExplorerClassList.cls` and `ExplorerRoutineList.cls` gain `rowActions`, a `primaryAction` (import), `multiSelect` and the empty-state keys.
- `src/OcuPilot/Kernel/Governance/Baseline.cls` :17-143 takes the keys, and `Test/GovernanceBaseline.cls` :12 its `DISABLED` list.
- `src/OcuPilot/Port/PathPort.cls`: `PAIRS` :47, `KINDFILE` :62 and `KINDSOURCE` :66.

### Vendor (measured on `ocupilot-a2-ci`, or read; anchors are `irissys/%Api/Atelier/vN.cls`)

- **`Compile`, v1 :1576.**
  - One `CompileList` call. `flags` defaults to `cuk`; `source=0` skips the storage re-read.
  - It always answers 200. `status.errors` carries only the first error.
  - `result.content` lists only classes whose storage changed.
  - Under the outer `%SYS.Capture`, 800 calls ran with no process death, so the route needs no `FILEDEVICEROUTES` entry.
- **`DeleteDocs`, v1 :1384.**
  - Body: an array of names. It answers 200 with `[{name, db, status}]`, takes no lock, and gives a held document a per-item #5864.
  - It deletes `.cls` with no `e` flag, so a class's data is kept. A `.mac` delete also removes its `.int` and `.obj`.
- **v7 XML routes.**
  - `ExportToXMLFile` :171 returns `result.content` lines. One missing name voids the whole export (#6308).
  - `ListDocumentsInXMLFiles` :468 answers `{file, documents:[{name, ts}], status}`, where `ts` is -1 for an absent document and routine names come back as `.MAC`.
  - `LoadXMLFiles` :307 takes `flags` raw: `""` loads without compiling and `ck` compiles. It honors `selected`, overwrites silently, and leaves a stub on malformed XML.
- **`PutDoc`, v2 :396.** It answers 201 for a new document and 200 for an overwrite.
  - With `ignoreConflict=1` it overwrites.
  - Content naming another class creates that class, with #16023.
- **Classic portal.**
  - Delete runs on `%CSP.UI.Portal.ClassList` and `RoutineList` themselves.
  - Compile runs on `%CSP.UI.Portal.Dialog.Compile`, export on `.Dialog.Export` and import on `.Dialog.Import`. Each dialog declares `RESOURCE` `%Development:USE`.
  - Its write rule is `GetRoutinePermission($namespace)["WRITE"`.
  - It audits under `%System/%SMPExplorer/{Change,Export,Import}`.

### Client

- `ui/src/app/areas/system-explorer/code-list.page.ts` (266 lines) imports only `DataTable` today: no dialog host and no status line. `ListPage` hosts the action dialogs at `shell/list-page.ts` :110. Its store is `code-list.store.ts` (186 lines). The viewer is `document-viewer.page.ts`, with its `<pre class="ocu-source-text">` at :126.
- `ui/src/app/shell/screen-action-handler.ts`:
  - `CHECKED_SET_DIALOGS` :228 serves only `broadcast`;
  - `UNDRAWN_ACTIONS` :252, `DESTRUCTIVE_ACTIONS` :317, `startCheckedSet` :892;
  - the Namespaces page registers its own Copy mappings dialog: that is the page-owned dialog precedent.
- `ui/src/app/core/multi-select.ts`, plus `shell/data-table.ts` :668-719, `command-bar.ts` :453 and `command-box.ts` :534.
- `ui/src/app/core/entity-ref.ts` :89-116 and `ui/tools/screen-mirror.mjs` :162 (`IMPLEMENTED_ID_RULES`) and :2443-2500 (`multiSelectProblem`).
- Dialogs and helpers:
  - `shell/typed-name-dialog.ts` is the destructive confirm;
  - `shell/server-path-picker.ts` :113 is the file picker, used by `areas/tasks/task-export-dialog.ts` and `task-import-dialog.ts`;
  - `areas/security/x509-form.page.ts` :134, :166 and :565 read a local file with `FileReader`;
  - `core/csv.ts` :76 is the client-side save;
  - `shell/code-block.ts`; `shell/proposal-card.ts`.

### Rosters a new write tool trips

- `Test/ExplorerDescriptor.cls` :111-138 (`TestTheAreaIsReadOnly`, a tripwire to replace).
- `Test/ReadTool.cls` :93-94 (196 tools, 123 writes).
- `Test/ToolRoundTrip.cls` :53, `Test/SurfaceCoverage.cls` :54+ and `Test/DraftRegistry.cls`.
- `Test/Prohibited.cls` :219 (covered types), :401-412 (composed types), :687 (24 codes).
- `Test/PortGate.cls` :28, `Test/DeveloperFloor.cls` :35 (ten tools, none a write), and `Test/EntityRef.cls` :212-258.
- `ui/tools/screen-mirror.test.mjs` :196-223, :322, :843 (ProcessList as the only multi-select) and :2605+.
- `ui/tools/self-protection.test.mjs` :253-293 (`KERNEL_REFUSALS`), `ui/tools/strings.test.mjs` :580/:604, `ui/tools/ci.test.mjs` :2091 and `scripts/ci-throwaway.sh` :284-289.

## Tasks & Acceptance

**Execution:**

- **Task 0, on `ocupilot-a2-ci` only, before the port code.** Write the results under Design Notes › Measured at plan, beneath the plan's own lines.
  - T0.1: (19.13) for the XML routes under `%SYS.Capture`; not this story.
  - T0.2: time the `DOCS` fresh read over `docnames` filtered to a set, on HSCUSTOM. Above 0.5 s, `DOCS` reads `HEAD doc/<name>` per name instead: its ETag is `ts`, and 404 means absent.
  - T0.3: (19.13) the UDL import check; not this story.
  - T0.4: compile an `.inc`. If it answers an error, the page leaves `.inc` rows out of a compile sequence, as the classic page does.
  - T0.5: record whether `%System/%SMPExplorer/*` is enabled by default. This changes only the wording of amendment 6.
- **[A] `src/OcuPilot/Port/AtelierPort.cls`.**
  - Types on `Classes` and `Routines`: `DOCS` (fresh read), `COMPILE`, `DELETE`, `EXPORT`, `PREVIEW` (the import's fresh read) and `IMPORT`.
  - `DOCS` answers `{Present, Modified, Absent}` as canonical strings, from one `docnames` call (with `generated=1`) filtered to the set.
  - The write gate gives `WritePairs(namespace)`: READ pairs plus `<routines resource>:WRITE`.
  - `Outcome` carries `console`. A compile's errors are its output. Delete items are mapped to port-owned reasons. Elsewhere #5838/#5883/#302 are `PORT.ACCESSDENIED`.
  - `MINVERSIONS` is keyed per route. `COMPOSEDTYPES` names every write type. `SnippetForm` and `Snippet` render each route call (AD-59).
  - Routine `Document` maps the object-only 404 to `available:false`, `reason:"objectonly"` (DW-1922).
- **[A] `src/OcuPilot/Api/AtelierError.cls`, new.** It holds `EXPLORER.DOCUMENT.ABSENT`, `.IMPORT.UNREADABLE`, `.IMPORT.CHANGED` and `.IMPORT.TOOLARGE`, each with its reason. Each reason is a Fixed string.
- **[A] Tools, under `src/OcuPilot/Screen/Tool/`.** One class per tool. The two of a verb share an abstract base: `ExplorerCompile` over `ExplorerClassCompile` and `ExplorerRoutineCompile`, and likewise `ExplorerDelete`, `ExplorerExport` and `ExplorerImport`. `ExplorerImportMint` is the import's mint.
  - `explorer.{classes,routines}.compile`:
    - `READTYPE` `DOCS`, `WRITETYPE` `COMPILE`, `CHANGEACTION` `updated`, not destructive;
    - arguments `Names`, `KeepSource`, `CompileDependents`, `SkipUpToDate`;
    - subject `Present,Absent,KeepSource,CompileDependents,SkipUpToDate`;
    - `CLASSICPAGES` `%CSP.UI.Portal.Dialog.Compile`.
  - `explorer.{classes,routines}.delete`:
    - `DELETE`, `deleted`, `DESTRUCTIVE` 1, subject `Modified,Absent`;
    - `ReadBackGone` re-reads `DOCS`.

  Each tool's:
  - `PrivilegePairs` is `%Development:USE` plus the scope namespace's routines WRITE pair (export: `%Development:USE` alone);
  - `ArgumentProblem` refuses an empty set or one above 100;
  - `StateDiff` is one row naming the documents, plus the flags;
  - output hook answers `output` from the written result.
- **[A] `Api/ScreenAction.cls` :370-378 and `Kernel/Proposal/Confirm.cls` :840-866.** Both are add-only. When the tool answers an `output`, add it to the answer. It is never stored or logged, and never put on the ledger.
- **[A] `Kernel/Proposal/Prohibited.cls`.**
  - Add `class,routine` to `COVEREDTYPES`, route them in `Prohibits`, and add the `OCUPILOTCODE` arm over `OwnNameStems`.
  - For import, the arm checks the resolved file's documents.
  - Add the code to `Codes` and `ReasonFor`, with its reason as a Fixed string.
- **[A] `Kernel/EntityRef.cls`, `ui/src/app/core/entity-ref.ts` and `ui/tools/screen-mirror.mjs` :162.** Add a `documentset` rule for `class` and `routine`: comma-split, drop empty pieces, keep unique, sort by code point. A single value is kept as is, the literal `import` included. Pin it in `Test/EntityRef.cls` and `screen-mirror.test.mjs`.
- **[A] multi-select, across `Screen/Registry.cls`, `screen-mirror.mjs`, `Test/MultiSelectCorpus.cls`, `core/multi-select.ts`, the command bar, the command box and the handler.**
  - Admit `extraActions`: further `rowActions` that act on the checked set.
  - Make `eligible` and `ineligibleKey` optional, as a pair; when absent, every row is checkable.
  - `ProcessList` is unchanged.
  - Update the pin at `screen-mirror.test.mjs` :843.
- **[A] Descriptors.**
  - Each list declares:
    - `rowActions` compile and delete (19.13 adds export, and import as the `primaryAction`);
    - `multiSelect {action:"compile", extraActions:["delete"], max:100}`;
    - the write-capable empty-state keys.
  - Regenerate `ui/src/app/core/screens.generated.ts`.
- **[A] `Kernel/Governance/Baseline.cls`.** Add the four compile and delete keys, and the delete keys to `GovernanceBaseline.DISABLED`.
- **[A] Client, `code-list.page.ts` and `.store.ts`.** The page owns its dialogs and output pane, registered the way the Namespaces page registers Copy mappings.
  - The compile dialog has three checkboxes: keep source on, dependents off, skip up-to-date on.
  - The sequence runs one action per checked document in list order. A framework-free store holds the queue, the stop flag and the lines (AD-19).
  - The output pane is `<pre tabindex=0>` on the code surface with a polite live status line.
  - Delete opens `typed-name-dialog`. One document is confirmed by typing its name; a set by typing the count.
  - It shows the per-document results.
- **[A] `shell/proposal-card.ts`.** Render `output.lines` in `code-block` when present.
- **[A] `document-viewer.page.ts`.** Render DW-1922's sentence.
- **[B, Story 19.13; not this story] `AtelierPort` `EXPORT`.**
  - It locates the file through `PathPort` as `KINDFILE`, with overwrite a constant, and writes the lines as UTF-8.
  - `destination` `browser` writes nothing and answers the lines.
- **[B, Story 19.13; not this story] `AtelierPort` `PREVIEW`/`IMPORT`.**
  - The source comes from `PathPort` (`KINDSOURCE`) or the screen's `content`, refused above 3,000,000 characters.
  - An `.xml` file goes through `xml/list`, which refuses `UNREADABLE`, then `xml/load` with `selected`.
  - A UDL file goes through header parse, `PUT doc?ignoreConflict=1`, then `COMPILE` when asked.
  - `PREVIEW` answers `documents`, a canonical "name new" or "name replaces <ts>" summary.
- **[B, Story 19.13; not this story] Export tools, `explorer.{classes,routines}.export`.**
  - `EXPORT`, `updated`, not destructive.
  - Arguments: `Names`, `destination`, `root` and `path`. The schema enum is `["server"]`; the screen also sends `browser`.
  - Subject: `Present,Absent,destination,root,path`.
  - `CLASSICPAGES`: `.Dialog.Export`.
- **[B, Story 19.13; not this story] Import tools, `explorer.{classes,routines}.import`.**
  - `PREVIEW`/`IMPORT`, `created`, `DESTRUCTIVE` 1.
  - Arguments: `root`, `path` and `compile`. `SCREENVALUES` adds `source`, `fileName` and `content`. The mint refuses `content` with `TOOL.ARGUMENTS`.
  - A mint class stores `documents`, as `TaskImportMint` does. The subject is `root,path,documents`, and the port refuses `CHANGED`.
  - `ArgumentPairs` adds `PathPort.PAIRS` only when `root` is sent.
  - `CLASSICPAGES`: `.Dialog.Import`.
- **[B, Story 19.13; not this story] Client.**
  - The export dialog offers a server file (`server-path-picker`, kind file) or this browser, which saves the answer's lines like `csv.ts`.
  - The import dialog offers a server file or a local file (`FileReader`, accepting `.xml,.cls,.mac,.inc,.int`), plus a compile checkbox, on by default. A refused version is shown in the dialog.
- **[A+B] Strings and docs.**
  - `strings.ts` gets new keys only. EXPERIENCE.md gets Fixed-strings rows after :588: labels, flags, the dialogs, the reasons, the count prompt and the output status lines. The closed dialog set at :173 names the compile, export and import dialogs.
  - Run `bash scripts/lint-docs.sh` and `cd ui && npm run test:tools`.
- **[A+B] Rosters.** Update each roster in the Code Map list, with every new name read from the instance.
  - Replace `ExplorerDescriptor.TestTheAreaIsReadOnly` with a roster test: the four reads plus four writes, each key's baseline value, and the descriptors' actions.
  - (19.13) `DeveloperFloor.TOOLS` gains the two export tools. Its "none is a write" assertion becomes "its writes are exactly the two exports": a `%Developer` lacks `%DB_HSCUSTOM:WRITE`, so compile, delete and import stay unheld.
  - The new arming classes get their `# classes:` line.
- **New tests**, each class at most about 500 lines:
  - `Test/AtelierPortWrite.cls` (in process, with the `ImplClass`/`HighestVersion` seams): every [A] matrix row; `work` never called; the namespace restored; `Snippet` per type.
  - `Test/AtelierPortWriteDenial.cls`, with real principals armed under `OCUPILOT_ALLOW_PRINCIPALS`:
    - routines READ without WRITE is refused by name;
    - routines RW succeeds;
    - a `%Developer`-role principal compiles and deletes a probe in `USER`, and is refused in `HSCUSTOM`.
  - `Test/ExplorerWrite.cls` (HTTP):
    - screen compile and delete on probe documents in `USER`, created by the test in setup;
    - agent mint and confirm for compile and delete. The delete key is enabled through its stored setting and restored, as `Test/GovernanceRestore.cls` does;
    - `OCUPILOTCODE` on both callers.
  - (19.13) `Test/ExplorerImportExport.cls`: the server and local round trip with source compared through `GET doc`, `UNREADABLE` with no stub left, `CHANGED`, UDL, and the version seam at 6.
  - `code-list.page.spec.ts`: the sequence, Stop, the error line, and the typed count.
  - `proposal-card.spec.ts`: `output` rendered as text.
  - `ui/browser/system-explorer-write.browser-spec.mjs`: probe documents created in setup, then compile with streamed lines, delete, and the probe gone. Its `structural()` walk covers the new dialogs, light and dark.

**Acceptance Criteria:**

- **AC1 (criterion 1).** Given documents checked on Classes or Routines, when Compile runs with chosen flags, then:
  - each document compiles with `c` plus exactly those flags;
  - its console lines appear in the output pane as its answer arrives, before the next document's;
  - Stop sends no further request.
- **AC2 (criteria 2, delete).** Given checked documents, when Delete is confirmed by typing their name or count, then they read back absent and the list re-fetches without them. Given the agent's `delete` proposal, when it is confirmed after the key is enabled, then the same holds. With the baseline in force, the agent's call is refused by governance.
- **AC3 (Integration, Rule 1).** Given a turn on Classes, when the agent calls `explorer.classes.compile`, then the minted card names the documents and flags. Confirming compiles them and shows the console on the card. The turn's tool result holds no console line.
- **AC4 (criteria 2, export and import) [SPLIT to 19.13].** Given probe documents exported to a server file, when they are deleted and then imported from that file, then each document's `GET doc` source equals what it was before. The same holds for an export to this browser imported as a local file. Each write goes through a confirmed proposal from the agent, or the screen's own action.
- **AC5 (criterion 3) [SPLIT to 19.13].** Given an instance whose highest Atelier version is below 7, when export or import runs, then the dialog shows "…answers version 6, and this … needs version 7…" and nothing was sent. Compile and delete still run.
- **AC6 (gate).** Given a principal holding the read pairs without routines WRITE, when it compiles, deletes or imports, then it is refused 403 naming `<routines resource>:WRITE`, and no document changes.
- **AC7 (self-protection).** Given any `OcuPilot*` document, or an import file holding one, when either caller compiles, deletes or imports it, then the answer is `PROHIBITED.OCUPILOTCODE` and nothing changes.
- **AC8 (DW-1922).** Given `EnsJob.mac` in HSCUSTOM, when its viewer opens, then it states that only object code is installed, and does not show the empty state for a missing document.
- **AC9.** Given the registry after this story, when `ExplorerDescriptor` enumerates `explorer.*`, then it finds four reads and four writes, the delete keys disabled, and the structural walk adds no `structural-baseline.json` entry.

## Spec Change Log

- 2026-10-02, spec gate (orchestrator, by=merge_gate): split approved. This story is Part A (AC1-AC3, AC6-AC9); Part B (AC4, AC5, the `[B]` items and `(19.13)` rows) is Story 19.13. The `Prohibited.cls` edits approved with disjoint hunks. The lead applied amendments 1-5 and 7-10 for Part A to the spine; amendment 6's wording follows T0.5 and lands at ship.

## Review Triage Log

## Design Notes

**Governing ADs:**

- AD-61 (the port);
- AD-5, AD-6, AD-7, AD-8, AD-10, AD-12, AD-13, AD-14, AD-15;
- AD-21 (sixth case), AD-22, AD-29, AD-34, AD-36, AD-39, AD-44;
- AD-51, AD-52, AD-53, AD-55, AD-56, AD-58, AD-59.

**Streaming, within AD-7 and AD-12.** The screen compiles a selection as one screen action per document, sent in sequence, and appends each answer's `output.lines` as it lands.

- Each compile is a complete write in its own foreground request (AD-7).
- Each request answers exactly one envelope (AD-12).
- No new channel, store or job exists.
- The gateway bound is one document's compile. That measured 0.7–33 ms, against the gateway's 60 s (`Server_Response_Timeout`, read).

Per-document requests reach the same end state as one call over the set, in any order: a subclass's compile also compiles its stale superclass (measured, M2). Finer granularity is not on offer: even the vendor's own async route delivers one class's lines only when that class ends (M3). The agent's confirm is one call over at most 100 documents (50 classes measured 37–40 ms).

**Measured at plan** (`ocupilot-a2-ci`, 2026-10-01, probe documents in `USER`, all removed):

- **M1.** Compile under the capture: 0 deaths in 800 calls; through a file device, 0 in 200.
- **M7.** Without `%DB_USER` WRITE:
  - compile answered 200 with #302;
  - PUT answered 400 with #5883;
  - `DELETE docs` answered 200, #5883 per item;
  - load answered 200, #6301 wrapping #5883;
  - nothing changed.

  `%Development:USE` plus `%DB_USER:RW` sufficed. `xml/export` and `xml/list` answer even without `%Development`.
- **M8.** With the default event set, compile, delete, load and PUT record no audit row. `%System/%System/RoutineChange`, disabled by default, records a compile only.

**Proposed spine amendments**, for the lead's spec gate (Rule 20):

1. **AD-61.**
   - Rule 1 gains the write gate.
   - Rule 6: the API answers privilege and read-only refusals as soft errors (#5838, #5883, #302) and never as `<PROTECT>`. They are `PORT.ACCESSDENIED`, except inside a compile's output and a delete's per-item results.
   - Rule 7: the `work` routes are never used.
   - Rule 5: name any T0.1 route.
2. **AD-39:** a fifth exception. Compile and import console lines reach the screen and the proposal card only, as text.
3. **AD-10:** the OcuPilot's-own-code arm, by effect: deleting, failing to compile, or replacing the code that serves OcuPilot's addresses (AD-9). Compile is included, since the inference that a failed compile leaves runtime behind is untested.
4. **AD-13:** `class` and `routine` ids may name a document set.
5. **AD-5:** `multiSelect.extraActions`, and an optional `eligible`.
6. **AD-15 and AD-53:** named cases for compile, delete, load, PUT and export, which record no vendor event by default (measured), while the classic dialogs record `%SMPExplorer` events (read).
7. **AD-8:** the write tools declare routines WRITE beyond the screen's set (measured).
8. **AD-21:** the explorer export is an overwriting file consumer; the import is a source.
9. **AD-44:** the `CLASSICPAGES` above.
10. **AD-51:** a new named case: `AtelierPort` builds each vendor body from the declared arguments.

**Integration ACs (Rules 1 and 2).** AC3 is the integration criterion.

- **Consumes:** `AtelierPort`'s read recipe; `Kernel/Proposal` (Mint, Confirm, Operation, Prohibited, ReadBack); `PathPort`; `Api/ScreenAction`; the governance gate; the shared data table and multi-select.
- **Consumed-by:**
  - 19.3 reuses `DOCS`, the `documentset` rule and the `output` channel for its save-and-compile;
  - 19.4 reuses the write gate;
  - 19.8's staging may reuse `extraActions` (inference).

**Ledger inbox.** DW-1922 is addressed by AC8 and its matrix row. The list is unchanged, because the classic page lists these rows too (inference). The rows' `Database` is the vendor's mis-attribution (it upper-cases the routine name), and `DeveloperFloor`'s USER own-database leg still reads those rows. That leg stays green and is left as is.

**Footprint (Rule 11).** The concurrent worktrees were checked on 2026-10-01. `epic-18` had no diff. `epic-23` is running.

- **Contended and not strictly add-only; approved by the orchestrator at the spec gate with disjoint hunks (by=merge_gate 2026-10-02).** Re-check `git -C /Users/jbrandt/git/OcuPilot/.worktrees/epic-23 diff` plus `status -s` at edit time; if Epic 23's hunks reach these lines, HALT `blocked`. `COVEREDTYPES` (:250) is a one-line shared list: a forward merge unions it.
  - `Kernel/Proposal/Prohibited.cls`: one-line edits at :250, :658 and :995, plus an appended arm. Epic 23's uncommitted hunks are at :4134-4187.
  - `Test/Prohibited.cls`: :219 and :687. Epic 23's committed hunks are at :9-54.
- **Contended and add-only:** `scripts/ci-throwaway.sh` (`# classes:` lines; epic-23 edits :264), `Baseline.cls`, `strings.ts`, EXPERIENCE.md, `ci.test.mjs` and `SurfaceCoverage.cls`.
- **Not contended:** everything else, including the non-additive edits to `Registry.cls`, `screen-mirror.mjs`, `multi-select.ts`, `ScreenAction.cls`, `Confirm.cls` and `ReadTool.cls` :93-94.
- **Bundle:** expect a re-base of `maximumWarning` (DW-1166). Stop above 3,800 kB.

**Split (the lead's question).** This is more than one implement pass: eight tools, a multi-select amendment, two dialogs with file transfer, and about fifteen roster edits. Recommendation:

- 19.2 keeps Part A: AC1–AC3 and AC6–AC9, with AC2's delete.
- A new 19.13, "XML export and import", takes Part B: AC4 and AC5, the `EXPORT`/`PREVIEW`/`IMPORT` types and the four export and import tools. Its plan reuses this spec's measurements.

Narrowing scope is an ask-first decision (Rule 5). Unsplit, this spec is complete.

**Named limitations.**

- Output arrives per document.
- A compile with dependents (`b`) that runs past the gateway's 60 s answers 504 while the instance completes it (inference).
- An export larger than about 3.6 million characters is `PORT.UNAVAILABLE`.
- Import reads XML exports and single UDL documents. It does not read classic `%RO` routine files, for which the API has no route, and it imports every document the file holds.

## Verification

Load source into `ocupilot-a2-ci` without the MCP tools, and never restart it. Run `rsync -a --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-19/src/ /tmp/ocupilot-a2-ci/src/`. Then, in `docker exec -i ocupilot-a2-ci iris session iris -U HSCUSTOM`, run `$System.OBJ.LoadDir("/opt/ocupilot/src","ck",.tErrors,1)`, checking both the returned status and `tErrors`.

**One test-runner call at a time, ever.** Run one class or one spec file per call and wait for it to finish. Never re-submit after a client-side timeout. Every probe document is removed.

**Commands:**

- `uv run scripts/check-objectscript.py && uv run scripts/test_check_objectscript.py` (loop): expected green.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-a2-ci --class <Class>` (loop), one class per call. Expected green. The classes:
  - `OcuPilot.Test.AtelierPortWrite`, `AtelierPortWriteDenial`, `ExplorerWrite`, `ExplorerImportExport` and `ExplorerDescriptor`;
  - `AtelierPort` and `AtelierPortDocument`;
  - `PortGate`, `ReadTool`, `ToolRoundTrip`, `SurfaceCoverage`, `DraftRegistry`, `GovernanceBaseline`, `Prohibited`, `EntityRef` and `DeveloperFloor`.

  Planned mutations:
  - AC1: send `flags` without `k` → `ExplorerWrite` reddens. Empty `output` on the screen answer → `code-list.page.spec.ts` reddens.
  - AC2: `ReadBackGone` always true → `ExplorerWrite`'s survivor leg reddens.
  - AC3: copy `output` into the dispatch result → `ExplorerWrite`'s turn leg reddens.
  - AC4: export with `selected` empty → `ExplorerImportExport`'s round trip reddens.
  - AC5: `MINVERSIONS` of 1 for the XML routes → the version leg reddens.
  - AC6: drop `WritePairs` → `AtelierPortWriteDenial` reddens.
  - AC7: drop the arm → `ExplorerWrite`'s `OCUPILOTCODE` legs redden.
  - AC8: map the object-only 404 back to `NOTFOUND` → `AtelierPortDocument` reddens.
- `cd ui && npm run test:tools` and `npx ng test --include 'src/app/areas/system-explorer/**' --include src/app/shell/proposal-card.spec.ts` (loop): expected green.
- Before each browser run (loop): `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-a2-ci:/durable/iris/csp/ocupilot/`. Then run each file alone: `OCUPILOT_BROWSER_ORIGIN=http://localhost:52780 OCUPILOT_BROWSER_CONTAINER=ocupilot-a2-ci node --test --test-concurrency=1 browser/<file>`, for `system-explorer-write.browser-spec.mjs`, `system-explorer.browser-spec.mjs` and `a11y-structural-invariants.browser-spec.mjs`. Expected green, with `structural-baseline.json` unchanged. The full browser suite is CI's.
- `bash scripts/lint-docs.sh && cd ui && npm run test:tools` (loop, after any EXPERIENCE.md edit): expected green.
- `cd ui && npm test` (once, before dev_complete): expected green, with the bundle re-based if it is over the warning.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-a2-ci`, the full ObjectScript sweep, one class at a time (once, before dev_complete). Expected green apart from residue named in 19.1's run (DW-1425/DW-1468, DW-1759).

Record one `mutation: <change> → <test that reddened>` line per AC here as each is observed (Rule 19).

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
