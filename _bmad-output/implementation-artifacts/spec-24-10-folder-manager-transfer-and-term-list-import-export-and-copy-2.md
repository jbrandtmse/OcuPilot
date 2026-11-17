---
title: 'Story 24.10: Folder manager transfer and term-list import, export and copy (Batch 2: the folder manager)'
type: 'feature'
created: '2026-11-17'
status: 'done'
baseline_revision: '85c9187f55ceee75060e1cc694bb9aff64ea30c3'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-10-folder-manager-transfer-and-term-list-import-export-and-copy.md'
warnings: ['oversized']
deferred:
  - summary: >-
      The port's AdmitRead (READ on the folder item database, for the export) has no negative test.
    evidence: |-
      A probe principal holding the Folder Manager's pairs and the file system's resource but no %DB_USER right was refused by the namespace gate (NS.DENIED, failedPair %DB_USER:READ) before AdmitRead ran, so the check is reachable only where ^DeepSee.FolderItemD is mapped to a database other than the namespace's default. Pinning it needs a mapped layout or a gate seam.
    location: >-
      src/OcuPilot/Port/AnalyticsPort.cls AdmitRead
    severity: low (unverified)
  - summary: >-
      The locked-and-hidden branch of ReadFolderItem (code 3 with %CheckResource false, read as 2) is not exercised.
    evidence: |-
      Every test runs as an account holding every resource, so %CheckResource is always true; a locked item whose resource the caller lacks would need a probe principal and a resource-bound item.
    location: >-
      src/OcuPilot/Port/AnalyticsPort.cls ReadFolderItem
    severity: low (unverified)
---

<intent-contract>

## Intent

**Problem:** Folder items (pivots, dashboards and the other items the Folder items screen lists, Story 20.11) can be listed in OcuPilot, but they cannot be exported, imported or deleted there. The classic Folder Manager does all three, and its import loads and compiles any class or routine the file holds. This is the story's first criterion: "**Given** the folder manager's export, import and delete **When** each runs **Then** it round-trips over its backing class." Batch 1 (the term lists, spec `…-copy.md`, `done`) is not re-planned.

**Approach:** Extend `AnalyticsPort`'s `FolderItems` endpoint, Batch 1's transfer helpers and the Folder items screen with three tools. Each is reached by the person's row actions and by the agent's confirmed proposals (AD-53). The backing class is `%DeepSee.UserLibrary.Utils`.

- `analytics.folderitems.export`: the vendor's own `%Export` XML of one item, to a server file (`root`, `path`) or to this browser.
- `analytics.folderitems.import`: creates every folder item a file holds, from a server file or a file this browser reads, all or none.
- `analytics.folderitems.delete`: `%DeleteFolderItem` of one item. It is destructive.

## Boundaries & Constraints

**Always:**

- **Gate.** Before any vendor call: `FOLDERPAIRS`, the namespace's shape and analytics on (AD-65), then the vendor's own `%CheckResource()`. An item the caller cannot see is absent, as in the list.
  - Import and delete also need WRITE on the database `^DeepSee.FolderItemD` maps to. That database must be read-write and journaled: Batch 1's `AdmitTermList`, generalized.
  - Export reads only: READ on that database, plus `%Admin_FileSystemAccess:USE`, as Batch 1's export.
- **Files: AD-21's sixth case only, as Batch 1.** The export is an overwriting `file` whose directory must exist. The import's file is a `source`. A local file's `fileName` and `content` are screen values only. The bound is `AtelierPort.MAXIMPORTCHARACTERS`; a larger text is refused 409 `TOOLARGE`, and so is a file holding more than 100 items.
- **Import reads the file before it writes.** A side-effect-free parse (`%XML.TextReader`) accepts exactly two shapes:
  - one folder-item element as the root, which is what the export writes;
  - an `Export` root whose every child is a `Document` named `*.DFI` holding one folder-item element, which is the classic page's export.

  A folder-item element is an XML name from `%GetFolderItemClasses`. Anything else is 409 `IMPORTSHAPE`: a class, a routine, another document type, a `folder` element, or no item at all. The write is `%Import(stream, 0, 0)` inside one `TSTART`/`TCOMMIT`, rolled back on any failure. It never calls `$system.OBJ.Load`, never compiles, never replaces and never kills.
- **Create only.** If any item the file names is held in any case or visibility (`%FolderItemExists` ≠ 0), the import is refused 409 `TAKEN` before any write.
- **Reviewed state.**
  - The import's fresh read holds `Items` (the full names), `Count`, the text's `Digest` and `Present`. At the write the file is read again, and a moved digest is 409 `IMPORTCHANGED`.
  - The delete's fresh read holds `Name`, `Type`, `Owner`, `Modified` and `Locked`. A locked item is 409 `LOCKED`; an absent one is 404 `ABSENT`.
- **Audit and keys.** OcuPilot's own `ConfigChange` row for each write, from either caller (AD-15). `export` and `import` ship `true`; `delete` ships `false` (AD-22). The delete's card and row action use the typed-name confirm, with the consequence named.
- **Prohibited and self-protection.** `Prohibited` covers `folder-item` for the three verbs, as it does `term-list`. OcuPilot holds no folder item, so nothing is prohibited.
- **Contended files take add-only edits** (Design Notes › Contention).

**Never:**

- `$system.OBJ.Load`/`LoadStream` with a load or compile flag. `%Import` with `pReplace` 1 or `pKill` 1. `%XML.Reader` in a read: it creates the folder it reads (measured).
- `$system.OBJ.Export` of `.DFI` documents: an item whose name holds `-` exports as an empty file with an OK status (measured).
- Container classes, folder (as opposed to item) export, import or delete, the `$TRASH` move, and term lists (Batch 1).
- Edits to `Screen/Read.cls`, `Screen/Registry.cls`, `screen-mirror.mjs`, `Kernel/EntityType.cls`, `app.routes.ts` or the CI files.

## I/O & Edge-Case Matrix

Rows run in USER on `ocupilot-b-ci` only, on items under the test's own marker folder. Server files go in a directory the test makes and removes (`ExplorerTransferProbe`'s pattern).

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Export to file | A dashboard whose title holds `"`, `&`, `<` and `é` | The file is `%Export`'s XML. The answer is `{Name, Namespace, root, path}` | - |
| Export to browser | Same item | The answer's `lines` are the XML | Past the bound: `TOOLARGE` |
| Round trip | Export, delete, then import the export | `%Export` of the re-created item equals the first export, apart from `timeModified` | - |
| Classic file | A `$system.OBJ.ExportToStream` of two `.DFI` documents | Both items are created | - |
| Mixed file | A `.cls` and a `.DFI` document in one export | No class is defined, no item is created | 409 `IMPORTSHAPE` |
| Taken | One item of the file is held in another case | Nothing is written | 409 `TAKEN` |
| Changed | The server file is rewritten between mint and confirm | Nothing is written | 409 `IMPORTCHANGED` |
| Partial failure | The seam reports failure after `%Import` of a two-item file into a new folder has returned | No item and no new folder remain | Rolled back; write fails |
| Delete | An unlocked item | `%FolderItemExists` reads 0 afterwards; the read-back reads it gone | - |
| Delete refused | A locked item; an absent item | Nothing is deleted | 409 `LOCKED`; 404 `ABSENT` |
| Gate | No `%Development:USE`; a read-only or unjournaled database | Refused before any vendor call | 403 naming the pair; 409 `READONLY` / `NOTJOURNALED` |
| Path | A `root` that is not allowed, or a `path` with `..` | Nothing is written | `PathPort`'s `PATH.*`, on its field |

</intent-contract>

## Code Map

Paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-24` (HEAD `37b3429e6`).

- **`src/OcuPilot/Port/AnalyticsPort.cls`** (3,558 lines), the port this batch extends:
  - `Serves` :400, `IsTermListWrite`/`IsTermListTransfer`/`ChangesTermLists`/`IsTermListType` :410-:437 (add `folder-item` siblings), `Invoke` :477 (its write flag and routing), `Collect` FolderItems :723 (the row the single read reuses).
  - Batch 1's helpers, which this batch lifts so that both endpoints share them (Rule 2; Batch 1's `wontfix-accepted` named this reopen): `AdmitTermList` :2288 / `AdmitTermListRead` :2820 (take the global and its two codes), `TermListExportFile` :2836, `CheckTermListExport` :2855 (take the endpoint), `TermListImportText` :2880 (take the too-large code) and `TextDigest` :2911.
  - The write pattern: `InvokeTermList` :2635, `PerformTermList` :2707, `PerformExport` :3117, `VendorTermListExport` :3163, `CreateRefusal` :3215, `ReadImportFile` :3277, `PerformImport` :3307, `AuditWrite` :2106.
  - Script forms (AD-59): `SnippetForm` :2126, `Snippet` :2138 and `TransferSnippet` :2215.
- **`src/OcuPilot/Api/AnalyticsError.cls`**: new codes `ANALYTICS.FOLDERITEM.{TAKEN,ABSENT,LOCKED,READONLY,NOTJOURNALED,TOOLARGE,IMPORTSHAPE,IMPORTCHANGED}`, beside :150-:162, the reason map :198 and the roster :227.
- **Tools, in `src/OcuPilot/Screen/Tool/`:**
  - New base `AnalyticsFolderItemAction` extends `AnalyticsAction`. It is the sibling of `AnalyticsTermListAction`: `DESCRIPTORCLASS` is `AnalyticsFolderItemList`, `DESTINATIONGLOBAL` is `^DeepSee.FolderItemD`, `CLASSICPAGES` is `%DeepSee.UI.FolderManager` and `READTYPE` is `FOLDERITEM`.
  - `AnalyticsFolderItemExport`, `AnalyticsFolderItemImport` and `AnalyticsFolderItemDelete` take the shapes of `AnalyticsTermList{Export,Import,Delete}.cls`.
  - The export reuses `AnalyticsTermListExportMint` once `CheckTermListExport` takes the endpoint. `TaskExport.AddFileArguments` / `FileProblem` and `ExplorerExport.FilePairs` handle the file arguments.
- **`src/OcuPilot/Screen/Descriptor/AnalyticsFolderItemList.cls`**: `rowActions` gains `export`, `export-browser`, `import`, `import-local` and `delete`, as `AnalyticsTermListList.cls` :29 does. Its doc's "It offers no action" is replaced.
- **`src/OcuPilot/Kernel/Governance/Baseline.cls`**: three keys after :270. **`Kernel/Proposal/Prohibited.cls`**: `folder-item` joins the term-list arms at :767, :1286, :1455, :1539, :1655 (the import's targetless arm), :1696 and :1907.
- **Client:**
  - New `ui/src/app/areas/analytics/folder-item-list.page.ts`, the twin of `term-list-list.page.ts` :1-:363: `ExplorerExportDialog`, `ExplorerImportDialog`, `saveText` and `TASK_IMPORT_ACTION_ID`. Lazy-registered in `ui/src/app/shell/screen-outlet.ts` :279.
  - In `ui/src/app/shell/screen-action-handler.ts`: the typed-name and confirm lists :156, `UNDRAWN_ACTIONS` :524, the consequences :712 and the typed names :805.
  - Labels in `ui/src/app/core/screen-actions.ts` :199, and `ui/src/app/core/strings.ts`.
- **Tests:**
  - `Test/AnalyticsTermListTransfer.cls`, `AnalyticsTermListTransferEdge.cls` and `AnalyticsTermListGate.cls` guard the lifted helpers.
  - `Test/ExplorerTransferProbe.cls` (`MakeDirectory`, `RemoveDirectory`) is the file pattern.
  - `ui/browser/analytics.browser-spec.mjs` :52/:237 already drives Folder items.
- **EXPERIENCE.md** (`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/`): a new Fixed-strings row after :609.
- **Vendor (read only):**
  - `irislib/%DeepSee/UserLibrary/Utils.cls`: `%DeleteFolderItem` :311 (it deletes only while `%FolderItemExists` = 1, and answers OK with count 0 otherwise), `%Export` :734 and `%Import` :809.
  - `FolderItem.cls`: `documentNameGet` :109, `%CheckResource` :160 and the global :341.
  - `irislib/%DeepSee/UI/FolderManager.cls`: `ExportItems` :869, `ImportItems` :1049, `DeleteItems` :1098 and `SaveFileImportToDisk` :1566.
  - `irislib/%DeepSee/UI/FolderItemDocument.cls`: a `.DFI` body is `%Export`'s XML, and its `ImportStream` :42 is `%Import(...,1,...)`.

## Tasks & Acceptance

**Execution:**

- [ ] `src/OcuPilot/Port/AnalyticsPort.cls`:
  - lift Batch 1's helpers (above), keeping the term-list behavior byte-for-byte; their tests are the guard;
  - add the `FolderItems` reads `FOLDERITEM`, `EXPORTITEM` (the item, echoing `root`/`path`) and `IMPORTFILE`;
  - add the writes `EXPORT`, `IMPORT` and `DELETE`, routed by endpoint, the import's parse (`FolderItemsInText`), the vendor seams `VendorFolderItem{Export,Import,Delete}` (24.2's seam pattern, so a test can fail the import after the vendor call) and the script forms;
  - add `COMPOSEDTYPES` rows for `FolderItems`.
- [ ] `src/OcuPilot/Api/AnalyticsError.cls`: the eight codes, with the proposed strings.
- [ ] `src/OcuPilot/Screen/Tool/AnalyticsFolderItem{Action,Export,Import,Delete}.cls`. `AnalyticsTermListExportMint.cls` passes the tool's `Endpoint()` to the lifted export check, so both exports use it.
- [ ] The descriptor, `Baseline.cls`, `Prohibited.cls`, the client page and maps, `strings.ts` and the EXPERIENCE.md row.
- [ ] Tests:
  - new `Test/AnalyticsFolderItemTransfer.cls`: the matrix, both callers, the seam's partial failure, audit, the script forms and AC6;
  - new `Test/AnalyticsFolderItemGate.cls`, armed by `OCUPILOT_ALLOW_PRINCIPALS` and rostered in `scripts/ci-throwaway.sh` (contended: add-only): pairs, `READONLY`, `NOTJOURNALED`;
  - extend `ui/browser/analytics.browser-spec.mjs`: export to this browser, a local import and a typed-name delete;
  - a component spec for the new page;
  - every roster under Shared surfaces.

**Acceptance Criteria:**

- **AC1 (export, both callers).** Given an item in USER. When the person exports it to a server file and to this browser, and the agent's `analytics.folderitems.export` proposal is confirmed. Then the file and the saved text each hold the item's `%Export` XML, and the answer to the screen carries only the file or the lines (AD-39, fifth exception).
- **AC2 (import, both callers; round trip).** Given an export written by AC1 and by the classic page's form. When it is imported after the item is deleted, from a local file by the person and from a server file by the agent. Then `%Export` of each re-created item equals its first export, apart from `timeModified`, and Folder items lists it.
- **AC3 (delete, both callers).** Given an item. When the person's typed-name Delete runs, and the agent's proposal is confirmed with the delete key turned on by the test and restored after. Then `%FolderItemExists` reads 0 and the write records its change. Given the key at its shipped `false`, when the agent proposes the delete, then governance refuses it.
- **AC4 (refusals before the vendor).** Given each refusal row of the matrix. When it is attempted from either caller. Then it answers that row's code and sentence, and a snapshot of `^DeepSee.FolderItemD` and `^DeepSee.FolderD` taken around the attempt is unchanged.
- **AC5 (never code).** Given the mixed file. When it is imported by either caller. Then `%Dictionary.ClassDefinition` holds no class of that name and no item is created.
- **AC6 (Integration, Rule 1).** Given an item the agent's import created. When `GET /screens/analytics.folderitems/read` and the read tool `analytics.folderitems` run. Then both answer its row.
- **AC7 (declared, governed, audited, rostered).** Given the three tools. When the roster tests run. Then each tool declares `write`, the port and `%DeepSee.UI.FolderManager`; `Baseline.cls` holds the export and import keys at `true` and the delete key at `false`; each write records `ConfigChange`; and `SurfaceCoverage`, `GovernanceBaseline`, `ClassicPageGate`, `MappingDescriptor` and `DraftRegistry` hold their rows, where removing one row reddens that test alone.
- **AC8 (leaves USER as found).** When any new or changed test ends, no marker item, folder, probe file or directory remains.

## Spec Change Log

- 2026-11-17, spec gate: the runner kept decisions 1 and 2 (import refuses non-folder-item content; create-only), the proposed strings, and the proposed spine lines for the owner's attended update (veto item U-106).

## Review Triage Log

### 2026-11-17 - Review pass

- verdicts: 13 findings - high 0, medium 3, low 6, false 2, maybe-false 2
- findings:
  - `[medium]` `[patch]` Hidden items (`%FolderItemExists` 2) never exercised - added `AnalyticsFolderItemEdge.TestAnItemTheCallerCannotSeeIsAbsentAndItsNameIsTaken` over a seam that answers an item hidden; mutation recorded.
  - `[medium]` `[patch]` Folder import's text bound never tested with the folder code - added the over-bound (local, server, composed read, write) and at-bound legs.
  - `[medium]` `[patch]` "Never pKill" guarded only by a source-text regex - added a bystander item that must survive an import; mutation recorded.
  - `[maybe-false]` `[defer]` The port's `AdmitRead` has no negative test - a principal without READ on `^DeepSee.FolderItemD`'s database is refused first by the namespace gate (measured: `NS.DENIED` naming `%DB_USER:READ`), so the check is reachable only where the folder item global is mapped to another database; deferred with the evidence.
  - `[low]` `[patch]` Import and delete cards unasserted - added the card legs to `AnalyticsFolderItemEdge`.
  - `[low]` `[patch]` Two test comments claimed a `TYPED_NAME_ROWS` mutation reddens a test - comments corrected; the entry stays unpinned, as recorded above.
  - `[low]` `[reject]` `TYPED_NAME_ROWS` entry unpinned - the dialog types the name whether or not the entry is declared, as for the term lists; no user-visible harm.
  - `[low]` `[reject]` Several AC legs have no `mutation:` line of their own - Rule 19 asks one per AC; AC3, AC4 and AC7 each have one above.
  - `[low]` `[reject]` Component spec `settle()` waits on fixed sleeps - jsdom only, no flake seen, fix adds machinery.
  - `[low]` `[reject]` AC5 and the classic file are driven at the port only - the routes call the same port methods, which the route legs cover for the `%Export` form.
  - `[maybe-false]` `[defer]` A locked item hidden from the caller reads 2 through the `%CheckResource` guard in `ReadFolderItem`; the test caller holds every resource, so the guard is unexercised.
  - `[false]` `[reject]` Intent audit: the port's delete does not compare `Modified` - the reviewed state is the proposal fingerprint (`Name,Type,Owner,Modified,Locked,Namespace`), which the confirm compares.
  - `[false]` `[reject]` Intent audit: `ci-throwaway.sh` is a CI file - the spec names it as an add-only edit; the edit adds one roster line.

## Design Notes

**Measured** (plan, 2026-11-17, `ocupilot-b-ci`, USER; the probe classes, items, folders and `/tmp/e2410b/` were removed):

- `%Export(name, stream, 0)` wrote the item as one XML element. `$system.OBJ.ExportToStream("<doc>.DFI")` wrapped the same element in `Export`/`Document`.
- `%Import(stream, 0, 0)` re-created the item from either form, and a title holding `"`, `&` and `<` survived. Over a held name it answered `#5001 … not replacing` and saved nothing.
- A file holding a `.cls` and a `.DFI`: `%Import` created only the item, and `Z2410.Evil` stayed undefined. `LoadStream(…, "-d", …, listonly 1)` listed both and loaded neither.
- `%Import` with a forced name in a new folder, inside `TSTART` then `TROLLBACK`, left neither the item nor the folder.
- Enumerating with `%XML.Reader` (Correlate, `Next`) created the item's folder. `%XML.TextReader` did not.
- An item named `zz2410-b.dashboard`: its `documentName` maps back to `zz2410/b.dashboard`. Its `.DFI` export is a 244-character `Export` with no document and an OK status. Its `%Export` round-trips.
- `%DeleteFolderItem` of an absent item answered OK with count 0.
- `%SYS.Audit` held 31,278 rows before and after every export, import and delete, so the vendor audits none of them. OcuPilot's own `ConfigChange` row is the record.

**Ruled before this plan (runner, U-105).** Batch 2 of 24.10; no split. Batch 1's inference that OcuPilot loads folder-item documents only and never compiles is now measured above.

**Veto items (runner):**

1. **Stricter than classic: import refuses non-item content.** The classic page loads and compiles every class and routine in the file, and applies `folder` definitions. Recommended: refuse with `IMPORTSHAPE`. A container class is a named limit.
2. **Stricter than classic: import creates only.** The classic page replaces items of the same name. Recommended: create only, as Batch 1.
3. **Proposed strings:**
   - Titles: "Export folder item <name>", "Import folder items".
   - Help:
     - "The file holds the folder item's definition, in the XML form the classic Folder Manager imports. A file already at this name is replaced."
     - "The file must hold folder items only, as OcuPilot or the classic Folder Manager exports them. It creates each item it holds; no item of that name may exist."
   - Refusals:
     - "This namespace already holds a folder item with a name in this file. Names are compared without regard to case."
     - "This folder item no longer exists."
     - "This folder item is locked, so it cannot be deleted."
     - "The database that holds this namespace's folder items is read-only, so nothing was written."
     - "Folder items can be changed only in a journaled database, so that a change is never left half done. Journaling is off for the database that holds this namespace's folder items."
     - "This file holds no folder item, or something other than folder items."
   - `TOOLARGE` and `IMPORTCHANGED` reuse Batch 1's sentences.
   - Consequence: "Deleting this folder item removes it for every user, and dashboards that show it can no longer display it. This cannot be undone from OcuPilot."
   - Status lines: "Exported <name>.", "Imported <count> folder items.", "Deleted <name>."
   - Actions: Export, Import and Delete reuse published words.

**Decided in-stage (plan).**

1. The export is `%Export`, not the classic `.DFI` form (measured: the `.DFI` form loses names holding `-`). The import still reads both forms.
2. A browser export saves `<name>.xml`, with `/`, space and `.` mapped as the classic page maps them. The import accepts `.xml`.
3. Delete is permanent (`%DeleteFolderItem`), as the classic page's Delete button. The row icon's `$TRASH` move is not built.
4. At most 100 items per import, counted before any write and refused `TOOLARGE`.
5. A locked item is refused, where the classic page silently skips it (read from the vendor source, not measured).
6. `%Import` runs each item class's own `%OnAfterImport`. That is code already on the instance, never file content, and a named limit (inference).

**Proposed spine lines (Rule 20; for the owner's attended update, never written by this run):**

- **AD-65:** the calls `%DeepSee.UserLibrary.Utils` `%Export` (to a resolved file or a stream), `%Import(stream,0,0)` and `%DeleteFolderItem`, plus `%FolderItemExists`. Never `$system.OBJ.Load` or `%XML.Reader` in a read.
- **AD-21:** Batch 2's consumers of the sixth case: the export is an overwriting `file`, the import's file a `source`, and the local text a screen value.
- **AD-51:** `AnalyticsPort`'s `EXPORTITEM`, `IMPORTFILE` and `FOLDERITEM` as port-composed reads.

**Governing ADs (Rule 6):**

- AD-65 and AD-29/AD-8 (the gate); AD-21 (the files).
- The write path: AD-6, AD-34, AD-51, AD-52, AD-53, AD-54 (import is a create), AD-56, AD-58, AD-14 and AD-10.
- AD-15 (audit), AD-22 (keys), AD-16 (the namespace switch), AD-39 (the export's lines reach the screen only), AD-44, AD-59 (script forms) and AD-11/AD-60 (file text is untrusted).

**Extend, don't copy (Rules 2, 31):**

- The port's writes extend `PerformTermList`'s pattern.
- The transfer helpers are lifted from Batch 1, not copied.
- The tools are siblings of the term-list tools over a new base, because their wording and rows differ.
- The export mint is reused. The page is `term-list-list.page.ts`'s twin: if more than the dialog wiring would repeat, lift it into a shared helper.

**Integration (Rules 1, 2).** Integration AC: AC6.

- Consumes: 20.11's list, 24.2's port and tool base, Batch 1's helpers and mint, 19.13's dialogs, `PathPort`, and the kernel's proposal, governance and audit.
- Consumed-by: 24.20 (undo snapshots and reverts these writes).

**Ledger inbox (Rule 17):** none owned (`owned_ledger=0`).

**Contention.** Among this batch's files, Epic 21's branch has changed only `scripts/ci-throwaway.sh` ("contended: add-only"). The shared rosters take append-only edits.

## Verification

**Shared surfaces:**

- the Folder items descriptor's row actions and the client action maps;
- `SurfaceCoverage`, `GovernanceBaseline`, `Governance`, `Prohibited`, `ClassicPageGate`, `MappingDescriptor`, `ReadTool`, `ToolWrite`, `ToolRoundTrip`, `ToolEmit`, `ToolDispatch` and `DraftRegistry`;
- `AnalyticsDescriptor`, `Descriptor`, `screen-mirror.test.mjs` and `analytics.test.mjs`, wherever they assert that Folder items has no action;
- the `AnalyticsError` rosters, `strings.ts`, the EXPERIENCE.md row and the `ci-throwaway.sh` arming roster.

*Every test added or changed passes on a fresh environment, in either order.*

**Setup (`ocupilot-b-ci` only; never `ocupilot-slot-b`):** `(loop)` 24.2's load recipe (`rsync` `src/` to `/Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`, then `LoadDir` in HSCUSTOM). Rebuild and copy the bundle in before any browser run.

**Commands** (each in the foreground, `timeout: 600000`, one test call at a time):

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.AnalyticsFolderItemTransfer`. Then, one call each: `AnalyticsFolderItemGate`, `AnalyticsTermListTransfer`, `AnalyticsTermListTransferEdge` and `AnalyticsTermListGate`. Expected: green.
- `(loop)` One call per roster class under Shared surfaces. Expected: green.
- `(loop)` `cd ui && npm run test:tools && npm run test:components && npm run build`. Expected: green, with the initial bundle under 2,500 kB.
- `(loop)` `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh`. Expected: clean.
- `(loop)` `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/analytics.browser-spec.mjs`. Expected: green.
- `(once)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17` for k = 1 to 17, one per call. Expected: green. The full browser suite is left to CI.

**Pinning mutations (Rule 19), planned:**

- AC1: the export writes no file → the file leg.
- AC2: the import seam returns OK without calling `%Import` → the round-trip and classic-file legs.
- AC3: the delete seam is skipped → the delete leg.
- AC4: the taken check is made `If 0` → the taken leg.
- AC5: the shape check admits a `Class` child → the mixed-file leg.
- AC6: the import never commits → the integration leg.
- AC7: one `SurfaceCoverage` row is removed → that test alone.
- AC8: the probe directory is left behind → `OnAfterAllTests`.

**Mutations run (Rule 19)** on `ocupilot-b-ci` (the throwaway's source copy, reloaded and compiled with its subclasses; each reverted by `rsync --checksum` and `diff -r`, byte-identical; client ones in the worktree, reverted by `cmp`, rebuilt and redeployed):

- mutation: `VendorFolderItemExport` ignores its file -> `AnalyticsFolderItemTransfer` `TestAnExportWritesTheVendorsXmlToAFileAndToTheBrowser` (file, escaping and lines legs) went red.
- mutation: `VendorFolderItemImport` answers OK without `%Import` -> `TestAnExportImportsBackAsTheSameItem` and `TestTheClassicPagesFileImportsBothItems` went red.
- mutation: `VendorFolderItemDelete` skips `%DeleteFolderItem` -> `TestADeleteRemovesAnUnlockedItemAndRefusesALockedOrAbsentOne` went red.
- mutation: the taken check of `PerformFolderImport` made `If 0 &&` -> `TestATakenNameAndAChangedFileWriteNothing` went red alone; its digest comparison made `If 0 &&` -> the changed legs of the same test went red.
- mutation: `FolderItemsInText` taking a document not named `*.DFI`, a `Document` with no item and a non-item child of a `Document` as no breach (three guards, each alone left the leg green) -> `TestAFileThatHoldsMoreThanFolderItemsCreatesNothing` (the mixed file) went red.
- mutation: `PerformFolderImport` rolls back in place of `TCOMMIT` -> `AnalyticsFolderItemRoutes` `TestTheAgentsThreeProposalsConfirmAndTheImportedItemReads` (the screen's read, AC6) and the person's import legs went red; its `TROLLBACK` made `If 0 {` -> `TestAnImportThatFailsAfterTheVendorReturnedLeavesNothing` went red alone.
- mutation: `PerformFolderDelete`'s locked check made `If 0 &&` and `PerformFolderExport`'s `AuditWrite` dropped -> `TestADeleteRemovesAnUnlockedItemAndRefusesALockedOrAbsentOne` and `TestEachWriteIsAudited` went red.
- mutation: the delete's `%DeleteFolderItem` dropped from `FolderItemSnippet` -> `TestEachWritesScriptFormMakesTheSameChange` went red.
- mutation: `AdmitJournaled`'s journal refusal made `If 0 &&` -> `AnalyticsFolderItemGate` `TestAReadOnlyOrUnjournaledDatabaseIsRefusedBeforeAnyVendorCall` (nonjournaled legs) went red.
- mutation: `AnalyticsFolderItemExport.WriteOutput` answers nothing and the import arm of `Prohibited` removed -> the person's export and the agent's import legs of `AnalyticsFolderItemRoutes` went red.
- mutation: the import row removed from `SurfaceCoverage`, the export row from `ClassicPageGate.OWNPAIRS`, the import entry from `MappingDescriptor.CLASSICROSTER`, and `analytics.folderitems.export` shipped `false` in `Baseline.cls` -> each of those four tests went red, alone.
- mutation: `Sweep` of `AnalyticsFolderItemTransfer` no longer deleting an item -> its `OnAfterAllTests` went red.
- mutation (client): `endSend` reading `root` for the path, the import count read as `'0'`, the bus test on `'created'` and `exportFileName` keeping `/`, each alone -> `folder-item-list.page.spec.ts` went red (four tests); `'export'` dropped from the Folder items' `UNDRAWN_ACTIONS` entry -> `screen-action-handler-folderitem.spec.ts` went red; the Folder items' `DESTRUCTIVE_CONSEQUENCES` entry dropped, rebuilt and redeployed -> `analytics.browser-spec.mjs` (the Story 24.10 test, its row menu) went red, and green after the revert, rebuild and redeploy. The `TYPED_NAME_ROWS` entry dropped left the handler spec and the browser spec green: the dialog types the item's name whether or not the entry is declared, so that entry is unproven by any mutation (the spec's Code Map lists it, as it does for the term lists').

- mutation (review pass, `AnalyticsFolderItemEdge`, throwaway source copy reloaded, reverted by `rsync --checksum` and `diff -r`, byte-identical): `FolderItemVisible` answering 1 for 2 -> `TestAnItemTheCallerCannotSeeIsAbsentAndItsNameIsTaken` went red; the vendor import's `pKill` argument made 1 -> `TestAnImportLeavesEveryOtherItemAsItWas` went red; `FolderItemImportFile` passing the term list's too-large code -> `TestAnImportFilePastTheTextBoundIsTooLargeAndOneAtTheBoundIsRead` went red; `AnalyticsFolderItemImport.StateDiff` pushing no `Items` row -> `TestTheImportsAndTheDeletesCardsNameWhatTheyActOn` went red.

## Auto Run Result

Status: done
Blocking condition: none

Batch 2 of Story 24.10 is implemented: the folder manager's export, import and delete over `%DeepSee.UserLibrary.Utils`, reachable by the person's row actions and by the agent's confirmed proposals.

- **Port, errors, tools, governance:** `AnalyticsPort` gains the `FolderItems` reads `FOLDERITEM`, `EXPORTITEM` and `IMPORTFILE`, the writes `EXPORT`, `IMPORT` and `DELETE`, the import's `%XML.TextReader` parse (`FolderItemsInText`), the `VendorFolderItem*` seams and the script forms; Batch 1's helpers are lifted (`AdmitJournaled`, `AdmitRead`, `ExportFile`, `CheckExport`, `ImportText`, `Utf8Stream`). `AnalyticsError` has the eight codes. New tools `AnalyticsFolderItem{Action,Export,Import,Delete}`; `Baseline.cls` ships export and import `true` and delete `false`; `Prohibited` covers `folder-item`.
- **Client:** new `folder-item-list.page.ts` and `transfer-actions.ts` (lifted from the term list page), the action, outlet and proposal maps, `strings.ts`, regenerated `screens.generated.ts`, and the EXPERIENCE.md strings row.
- **Tests:** `AnalyticsFolderItemTransfer` (11), `AnalyticsFolderItemRoutes` (4), `AnalyticsFolderItemGate` (2), and from the review pass `AnalyticsFolderItemEdge` (4) with `AnalyticsFolderItemHiddenSeam`; the roster classes, `analytics.test.mjs`, two component specs and the browser spec are updated; `ci-throwaway.sh` gains one add-only roster line.
- **Review:** 13 findings, no high. Patches applied: 3 medium (hidden items, the folder import's text bound, a bystander item that must survive an import) and 2 low (card rows, two false comments), each with a recorded mutation. Deferred: 2 (the export's `AdmitRead` is shadowed by the namespace gate, the locked-and-hidden branch). Rejected: 6, with reasons in the Review Triage Log. Follow-up review recommended: the three patched mediums are new tests over unchanged product code, so the unverified risk is limited to those tests' hermeticity on a fresh instance.
- **Verification:** the (loop) classes and rosters green on `ocupilot-b-ci`; `npm run test:tools` 2,299 green; `npm run test:components`, `npm run build` (initial bundle 2.10 MB) and `analytics.browser-spec.mjs` green before the review pass, whose client edits were comments only; `check-objectscript` and `lint-docs` clean; the (once) sweep, shards 1 to 17 of 17, green after the last patch.
- **Residual risks:** `analyticsFolderItemsEmptyAgent` (`'import folder items'`, the Folder items empty-state hint the registry now requires) is a string outside the proposed set, held as a veto item for the owner's wording. Epic 21 also changed `Baseline.cls`, `Prohibited.cls`, the roster tests (`ToolWrite`, `ReadTool`, `ToolEmit`, `Governance`, `GovernanceBaseline`, `SurfaceCoverage`, `Prohibited`, `ToolRoundTrip`), `strings.ts`, `screens.generated.ts`, `screen-outlet.ts` and `ci-throwaway.sh`; the roster counts (93 to 96, 479 to 482) and the `strings.ts` line cite will conflict at integrate-forward.
