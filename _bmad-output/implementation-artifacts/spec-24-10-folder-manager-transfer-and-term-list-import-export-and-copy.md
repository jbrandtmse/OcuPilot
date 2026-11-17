---
title: 'Story 24.10: Folder manager transfer and term-list import, export and copy (planned slice: the term lists)'
type: 'feature'
created: '2026-11-17'
status: 'done'
baseline_revision: 'bb323e74ee6c8c50fb175b1acaa7809ee0d72735'
baseline_commit: 'bb323e74ee6c8c50fb175b1acaa7809ee0d72735'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-2-the-analytics-editors.md'
warnings: ['oversized', 'multiple-goals']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Story 24.2 made the term-list editor, but a term list still cannot be exported, imported or copied from OcuPilot, and the folder manager's export, import and delete are classic-only. The two halves are independent surfaces of different size (Design Notes › Proposed split), so this spec plans the term-list half and proposes where the folder-manager half goes.

**Approach:** Extend 24.2's `AnalyticsPort` term-list writes, its tool base and the Term lists screen with three tools, each reached by the person's actions and the agent's confirmed proposals (AD-53), shaped like Story 20.5's lookup-table transfer:

- `analytics.termlists.export`: the vendor's own CSV (`%ExportCSV`) to a server file (`root`, `path`) or to this browser.
- `analytics.termlists.import`: a new term list from a CSV file, from a server file or a file this browser reads.
- `analytics.termlists.copy`: the classic Save As, as a new list under a new name.

## Boundaries & Constraints

**Always:**

- **24.2's gate and write model, unchanged** (its spec, Boundaries › Always): `TERMLISTPAIRS`, namespace shape, analytics on, database READ. Import and copy also pass `AdmitTermList` (WRITE, read-write, journaled) and run every vendor call in one `TSTART`/`TCOMMIT`, rolled back on any failure. Export reads only: READ on the term-list database, plus the agent's `%Admin_FileSystemAccess:USE`, as 20.5's export.
- **Files are AD-21's sixth case only.** A server file is `root` plus `path` through `PathPort`: the export is an overwriting `file` whose overwrite is a constant and whose directory must exist; the import is a `source`. A local file's `fileName` and `content` are screen values, never in a tool schema, never stored or logged. The text bound is `AtelierPort.MAXIMPORTCHARACTERS`, refused 409 `ANALYTICS.TERMLIST.TOOLARGE`.
- **Create only.** Import and copy create a list that is not held, compared ignoring case; a held name is 409 `ANALYTICS.TERMLIST.TAKEN` before any vendor call. Nothing is overwritten.
- **Import parses before it writes.** The port splits the text into lines (LF, CR dropped, a leading BOM skipped) and parses each with the vendor's `%ParseCSVRecord` on its UTF-8 form. It reads `%%` header lines as `%ImportCSV` does (`NAME`, `CAPTION`, `FIELDLIST`, `PATTERN`, `DESCRIPTION`, `SUBJECTAREA`, `HIDEVALUE`), skips blank lines and lines with no key, and takes record 2 as the value and record f+2 as field f.
  - Every name, field, key and value then passes 24.2's `TermListViolations`, so a breach is 422 naming its rule.
  - A text with no `%%NAME`, or with no entry, is 409 `ANALYTICS.TERMLIST.IMPORTSHAPE`.
  - The write uses 24.2's `VendorTermListCreate` and `VendorTermListSetValue` seams.
- **Reviewed state.** The import's fresh read holds `Name`, `FileEntries`, the text's SHA-256 `Digest` and `Present`. At the write the port re-reads the file, and a digest that moved is 409 `ANALYTICS.TERMLIST.IMPORTCHANGED`. The copy's fresh read holds the source's `Modified` and `Entries` and the new name's `Present`.
- **Audit.** OcuPilot's own `ConfigChange` row for each tool, from either caller (24.2's `AuditWrite`); an agent write also carries its marker (AD-15).
- **Governance (AD-22).** The three keys ship `true`, because none replaces or removes anything. Export's server file names its consequence (`EXPLORER.EXPORT.REPLACES`).
- **Contended files take add-only edits** (Design Notes › Contention).

**Never:**

- `%ImportCSV`. It deletes and recreates a held list, reads lines by the stream's own terminator (measured: a CR LF stream read the whole file as one line) and ignores its own `%SetValue` failures.
- `%ExportCSV` with a caller value, or any file path except a `PathPort` resolution.
- A replace or overwrite of a held list. The classic Import and Save As do overwrite after a confirm, so OcuPilot is stricter here.
- The folder manager's export, import or delete (Design Notes › Proposed split).
- Touching U-34. 24.2's not-journaled refusal keeps every multi-call write all-or-nothing, so no partly applied write exists to audit.
- Edits to `Screen/Read.cls`, `Screen/Registry.cls`, `screen-mirror.mjs`, `Kernel/EntityType.cls`, `app.routes.ts` or the CI files.

## I/O & Edge-Case Matrix

These rows run in USER on `ocupilot-b-ci` only, with lists named by the test's marker. Server files live in a directory the test makes and removes (`ExplorerTransferProbe`'s pattern).

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Export to file | List with fields, keys holding `,`, `"` and `é` | The file is `%ExportCSV`'s UTF-8 text. The answer is `{Name, Namespace, root, path}` | - |
| Export to browser | Same list | The answer's `lines` equal the file's lines | Past the text bound: `TOOLARGE` |
| Round trip | Export the list, delete it, import the export | Header, fields and every value read back through `%ToObj` | - |
| Import local | `import-local` with `fileName` and `content` | The list is created. Read-back `holds`; one `created` change event | - |
| Taken | Import or copy to a name held in another case | Nothing written | 409 `TAKEN` |
| Shape | A file with no `%%NAME`; a key `a^b`; a 32,001-character value | Nothing reaches the vendor | 409 `IMPORTSHAPE`; 422 naming the rule |
| Changed | The server file is rewritten between mint and confirm | Nothing written | 409 `IMPORTCHANGED` |
| Copy | `NewName` for a list with entries | The new list equals the source, except its name and its modification time | - |
| Partial failure | The seam fails the third value write of an import | No list is created. Write fails, no change event | Rolled back |
| Path | `root` not allowed, or `path` with `..` | Nothing written | `PathPort`'s `PATH.*`, on its field |
| Gate | A principal without `%DeepSee_PortalEdit:USE`; a read-only or unjournaled term-list database | Before any vendor call | 403 naming the pair; 409 `READONLY` / `NOTJOURNALED` |

</intent-contract>

## Code Map

Paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-24` (HEAD `91931ecd3`).

- **`src/OcuPilot/Port/AnalyticsPort.cls`**, the port this story extends. It has 2,818 lines.
  - `Serves` :347, `IsTermListWrite` :357 and `IsWrite` :369.
  - `InvokeTermList` :2498 routes types; `PerformTermList` :2564 is the write pattern (shape, read, refusal, transaction, audit, read-back).
  - `TermListViolations` :2227, `TermListFits` :2204, `ReadTermListData` :2387, `HeaderRow` :2430, `AdmitTermList` :2151 and `AuditWrite` :2036.
  - The vendor seams `VendorTermList*` :2695-:2802. Output capture `$$BeginCapture^%SYS.Capture` and `EndCapture` :1929, as `VendorBuild` :1878 uses them.
  - The script form: `SnippetForm` :2056 and `TermListSnippet` :2092. The shared draft registry requires a form for every write (AD-59).
- **The transfer pattern to follow (Story 20.5), in `src/OcuPilot/Port/InteropPort.cls`:**
  - `ImportText` :6964, `ImportShape` :7004 (the digest) and `ImportFile` :7058;
  - `ExportFile` :7189 and `CheckExport` :7208;
  - `ExportTable` :7235 (file or `lines`) and `TransferSnippet` :7312;
  - the keys `ROOTKEY` / `PATHKEY` / `FILENAMEKEY` / `CONTENTKEY` :631-:637 and `IMPORTID` :646.
- **Tools:**
  - `src/OcuPilot/Screen/Tool/InteropLookupTable{Export,ExportMint,Import}.cls` are the shapes: `SCREENACTIONS`, `SCREENVALUES`, `BROWSERACTION`, `REVIEWED`, `PortQuery`, `StateDiff`, `WriteOutput` and `Consequence`.
  - `AnalyticsTermListAction.cls` is the base the three new tools extend. `AnalyticsAction.PrivilegePairs` with `DESTINATIONGLOBAL` gives the pairs.
  - `TaskExport.AddFileArguments` / `FileProblem` and `ExplorerExport.FilePairs` handle the file arguments.
- **`src/OcuPilot/Api/AnalyticsError.cls`**: new codes `TERMLISTTOOLARGE`, `TERMLISTIMPORTSHAPE` and `TERMLISTIMPORTCHANGED`, beside :182 and the roster lists :209.
- **`src/OcuPilot/Screen/Descriptor/AnalyticsTermListList.cls`** :29-30: add the row actions `export`, `export-browser`, `copy`, `import` and `import-local`, as `InteropLookupTableList.cls` :38 does.
- **`src/OcuPilot/Kernel/Governance/Baseline.cls`**: three keys after :267. **`Kernel/Proposal/Prohibited.cls`**: the term-list branch covers the new verbs. OcuPilot holds no term list, so nothing is prohibited.
- **Client:**
  - `ui/src/app/areas/analytics/term-list-list.page.ts`: Export, Import and Copy. Reuse `ExplorerExportDialog`, `ExplorerImportDialog`, `AllowedDirectoriesStore` and `saveText`, as `interop-lookup-table-list.page.ts` :1-:140 does.
  - `term-list.store.ts`.
  - `ui/src/app/shell/screen-action-handler.ts`: `UNDRAWN_ACTIONS` :522 and the lookup row :518.
  - `ui/src/app/core/strings.ts`: the analytics block, about :7820-:8074.
- **Tests:**
  - 24.2's `Test/AnalyticsTermList{Edit,Gate,Routes,Seam}.cls` and `Test/AnalyticsProbe.cls`.
  - `Test/InteropLookupTransfer.cls` and `Test/ExplorerTransferProbe.cls` (the probe directory).
  - `ui/browser/analytics-term-list-editor.browser-spec.mjs`.
- **EXPERIENCE.md** (`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/`): 24.2's Fixed strings row is :607. Add a new row after it.
- **Vendor (read only):**
  - `irislib/%DeepSee/TermList.cls`: `%GetTermListNameFromStream` :194, `%ImportCSV` :240, `%ExportCSV` :370, `%WriteCSVRecord` :472 and `%ParseCSVRecord` :490 (it decodes UTF-8 first).
  - `irislib/%DeepSee/UI/TermListManager.cls`: Save As :791 (a name prompt, then an overwrite confirm) and `%OnSubmit` :950 (an upload of `.csv`, `.xls` or `.xlsx`, overwrite on confirm).
  - `irislib/%DeepSee/UI/TermListExport.cls`: a browser download `<name>.txt` under `%DeepSee_Portal:USE`.

## Tasks & Acceptance

**Execution:**

- [x] **Task 0, on `ocupilot-b-ci` only.** Use USER, marker lists, and a probe directory made and removed by the task. Record the results under Design Notes › Measured.
  1. No vendor audit row for an export, or for the create and value writes an import or copy makes.
  2. A captured `%ExportCSV(name,"",0)` and a file `%ExportCSV(name,file,1)` hold the same lines.
  3. Parsing the export back yields every key, value and field.
- [x] `src/OcuPilot/Port/AnalyticsPort.cls`:
  - read types `EXPORTLIST` (the `TERMLIST` row echoing `root`/`path`), `IMPORTFILE` and `COPYTARGET`;
  - write types `EXPORT`, `IMPORT` and `COPY`, through `InvokeTermList`/`PerformTermList`;
  - `TermListImportText`, `TermListParse`, `TermListExportFile` and `CheckTermListExport`, extending 20.5's methods by their shape;
  - the vendor seams `VendorTermListExport` (capture or file);
  - `TermListSnippet` branches.
- [x] `src/OcuPilot/Api/AnalyticsError.cls`: the three codes with the Proposed strings.
- [x] `src/OcuPilot/Screen/Tool/`:
  - `AnalyticsTermListExport.cls` plus `AnalyticsTermListExportMint.cls`, which extends `InteropLookupTableExportMint`'s order over this port;
  - `AnalyticsTermListImport.cls`;
  - `AnalyticsTermListCopy.cls`.

  Each extends `AnalyticsTermListAction`. Names, values and keys are in Design Notes › Tools.
- [x] The descriptor row actions; `Baseline.cls`; `Prohibited.cls`; the client page, store and maps; `strings.ts`; the new EXPERIENCE.md row.
- [x] Tests:
  - new `Test/AnalyticsTermListTransfer.cls` (the matrix, both callers, the seam's partial failure, audit, the script form);
  - extend `AnalyticsTermListGate.cls` (pairs, `READONLY`, `NOTJOURNALED` for import and copy);
  - extend `ui/browser/analytics-term-list-editor.browser-spec.mjs` (export to the browser, a local import, a copy);
  - update every roster under Verification › Shared surfaces.

**Acceptance Criteria:**

- **AC1 (export, by both callers).** Given a list in USER. When the person uses Export (server file and this browser) and the agent's `analytics.termlists.export` proposal is confirmed. Then the file and the saved text each hold the vendor's export of that list, and the answer to the screen carries only the file or the lines (AD-39's fifth exception).
- **AC2 (import, by both callers).** Given a file a person or agent export wrote. When it is imported after the list is deleted, from a local file by the person and from a server file by the agent. Then `%ToObj` reads every header value, field and value of the original. The import reads back `holds`, and Term lists shows the list.
- **AC3 (copy, by both callers).** Given a list with entries and fields. When the person's Copy and the agent's `analytics.termlists.copy` run with a free name. Then the new list's entries and fields equal the source's, and the source is unchanged.
- **AC4 (refusals before the vendor).** Given each refusal row of the matrix. When it is attempted from either caller. Then it answers that row's code and sentence, and a snapshot of `^DeepSee.TermList` taken around the attempt is unchanged.
- **AC5 (all or nothing).** Given a seam that fails a value write partway through an import or a copy. Then no list is created, and the write reports failure.
- **AC6 (Integration, Rule 1).** Given a list the agent's import created. When `GET /screens/analytics.termlistentries/read` and the read tool `analytics.termlistentries` run for it. Then both answer the file's rows.
- **AC7 (declared, governed, audited, rostered).** The three tools declare `write`, the port and `%DeepSee.UI.TermListManager`. `Baseline.cls` holds the three keys at `true`. Each write records `ConfigChange`. `SurfaceCoverage`, `GovernanceBaseline`, `ClassicPageGate`, `MappingDescriptor` and `DraftRegistry` hold their rows, and removing one row reddens that test alone.
- **AC8 (leaves USER as found).** When any new or changed test ends, no marker list and no probe file or directory remains.

### Review Findings

Code review 2026-11-17 (Batch 1; tier `full-opus`; blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor). Patched in this pass unless stated.

- [x] [Review][Patch] **high** `WholeListSnippet` rendered 1,000 entries, named the rest in a comment and still committed, so an import or copy script made a partial list (AD-59 Prevents). Now a list past `SNIPPETENTRIES` has no script form: `Snippet` answers `[]` and the draft is refused `PROPOSAL.NODRAFT`, as AD-59's 20.20 amendment refuses an over-long draft. Replaces Decided in-stage 11's comment form.
- [x] [Review][Patch] **medium** The export script passed the unresolved relative `path` to `%ExportCSV`; run on `ocupilot-b-ci` it ended not OK. `TransferSnippet` now resolves through `TermListExportFile` and renders the resolved file, or a refusal line.
- [x] [Review][Patch] **medium** The import script rendered whatever the file held at draft time: it now renders `IMPORTCHANGED` when the text is not the reviewed `digest`, and `IMPORTSHAPE` when the file holds another list than the one named, as `PerformImport` refuses.
- [x] [Review][Patch] **medium** The script form's refusal branches were never run: legs added for a copy of an absent list, a changed digest, another list named, a local text that is no export, an export file the write would refuse, a run export script writing under the allowed directory, and a list past the cap.
- [x] [Review][Patch] **medium** AC6's row checks were guarded by `If $IsObject(rows)`: unconditional four-row assertions now precede them for the Entries read and the read tool.
- [x] [Review][Patch] **medium** Refusal legs asserted the status only: the person's second copy and import now pin `409 TAKEN`, the agent's absent export pins the code it answers (`TOOL.ARGUMENTS`, DW-2597 occurrence), and the moved confirm pins 409 with its code.
- [x] [Review][Patch] **low** `PerformCopy`'s doc gave the refusal order wrongly (rules before `TAKEN`); `AnalyticsTermListGate`'s doc said every principal's export is refused for the file resource.
- [x] [Review][Patch] **low** Stale mutation line: `DESTINATIONPERMISSION` = `WRITE` leaves `ToolEmit` green (it derives the pair from the same parameter); corrected under Verification.
- [x] [Review][Defer] **medium** DW-2702 `routed owner=burndown`: 20.5's `InteropPort.TransferSnippet` has the same relative-path script (out of footprint).
- [x] [Review][Defer] **medium** DW-2703 `escalated owner=burndown`: AD-39's fifth exception names XML lines, not this export's CSV lines; a fourth proposed spine line beside U-105's.
- [x] [Review][Dismiss] **low** `wontfix-accepted`: two concurrent creates of one new name are not serialised (copy targets the source, import the literal `import`), and `%CreateTermList` kills a held node. reopen_if=two confirmed creates of the same new term list name both answer 200.
- [x] [Review][Dismiss] **low** `wontfix-accepted`: the copy's draft reads the source live, not against the reviewed `Modified`. reopen_if=a copy draft taken after the source changed renders entries the card did not show.
- [x] [Review][Dismiss] **low** `wontfix-accepted` (Rule 2): `TermListImportText`, `TermListExportFile` and `TextDigest` copy 20.5's private helpers (reason in Decided in-stage 6). reopen_if=Batch 2's folder-manager transfer needs the same import-text, export-file or digest helper.
- Rejected: help string omits the hide-value limit (spec's Proposed string, Decided in-stage 2); local `content` stored (false: `ReadImportFile` answers it empty); capture memory before the bound (theoretical); export's `updated` change action (20.5's precedent); `Prohibited` reuses the lookup's `IMPORT` constant (contended file, equal by design); stale Auto Run Result and Boundaries wording (spec edits); `nothingSent` vs AC2 (AD-58 action-style, Decided in-stage 7); EXPERIENCE row "new name" (contended file, cosmetic); line breaks in values (Decided in-stage 5); empty `NewName` script, subscript-long `NewName` (false: required and `ArgumentProblem`); agent `Name` `import` (the card shows the file's list); export delete race (theoretical); per-part mutations beyond one per AC; `fill` comment leg (unverified, cosmetic); test class over 500 lines (residual risk recorded).

## Spec Change Log

- 2026-11-17, spec gate: blocked -> ready-for-dev on the runner's rulings (U-105); this spec is Batch 1.

## Review Triage Log

### 2026-11-17 - Review pass

- verdicts: 16 findings - high 0, medium 3, low 13, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` Two assertions counted lists through the Edit class's broader marker - patched: they read this class's own `Marked()`.
  - `[medium]` `[patch]` Import size bound and local file-name rule untested - patched: a 3,000,001-character local text (`TOOLARGE`) and a name with a slash (400) join `TestShapeBreachesNeverReachTheVendor`.
  - `[medium]` `[patch]` Guarded `output` assertions passed when `output` was missing - patched: an unconditional `$IsObject` assertion precedes each of the three guarded checks.
  - `[low]` `[patch]` `TermListParse` repeat, keyless and over-long key rules unpinned - patched: a repeated key counts once, a keyless line is skipped, a 256-character key is 422 `KEY`.
  - `[low]` `[reject]` Term lists page refusal wiring untested - the 20.5 lookup page's spec has no refusal leg either, a refused path is a displayed sentence, and the fix is a new component spec.
  - `[low]` `[reject]` `AdmitTermListRead`'s own READ refusal unpinned - the tool-level pairs refuse first on every route, so no caller reaches it without READ.
  - `[low]` `[reject]` Export script form checked as text only - the script is rendered from the same seam call the tests execute; an executed export script adds a second file write for no new claim.
  - `[low]` `[reject]` `ReadCopyTarget` checks only the new name while the write also checks the source's data - a source made through the editor obeys the rules; a vendor-made one fails at confirm with a 422, loudly.
  - `[low]` `[reject]` Line breaks inside a value split into records - the named limit of Decided in-stage 5.
  - `[low]` `[reject]` `ToolEmit` builds its expected pair from the same parameters - `AnalyticsTermListGate` pins the values and the `DESTINATIONPERMISSION` mutation reddened it.
  - `[low]` `[reject]` Intent audit: read-back verdict `nothingSent` where the matrix says `holds` - `holds` is not a verdict; AD-58 gives an action-style write `nothingSent` and the test says the read-back found the list (Decided in-stage 7).
  - `[low]` `[reject]` Intent audit: no test counts the `created` change event - the shared handler publishes it for every confirmed write (`screen-action-handler.ts` AD-14 block) and the browser spec reads the list back after the import.
  - `[low]` `[reject]` Intent audit: export needs `%Admin_FileSystemAccess:USE` for both callers - 20.5's export does the same; recorded as Decided in-stage 9.
  - `[low]` `[reject]` Intent audit: `scripts/ci-throwaway.sh` edited - three added lines (a comment and the `classes:` roster line), which is the add-only edit the spec allows.
  - `[low]` `[reject]` Intent audit: local `content` is in the import's fingerprint subject - the same declaration as 20.5's lookup import; whether the stored proposal keeps the text was not checked (inference).
  - `[low]` `[reject]` Intent audit: matrix rows' run results are not in the diff - the Verification section records them.

## Design Notes

**Ruled at the spec gate (runner, veto item U-105).** No split: the lineage is at `split_children`, and moving the folder-manager criterion is owner-only. Story 24.10 keeps both criteria and is delivered in two batches. Batch 1 is this spec (the term lists). Batch 2, the folder manager's export, import and delete, is planned in a second spec for this story key after Batch 1's code head is committed. The story reaches `done` only when both batches have. Question 2 is kept (server-file variants), the proposed strings are kept, and the proposed spine lines stay here for the owner's attended update; the code complies without a spine edit (the U-87 precedent).

**Proposed split (intent gap, Rule 5 tier 2: for the runner).** The story holds two independent surfaces. Each is about the size of Story 20.5's whole lookup transfer, and 24.2's six tools alone ran oversized.

- **Recommended:** 24.10 keeps "term-list import, export and copy", this spec. The folder manager's criterion moves word for word to a new sibling, "Folder manager export, import and delete", after 24.23.
- **The limit.** Story 21.8's lineage (24.2 and 24.10 to 24.14) already counts 6, `unattended.yaml`'s `split_children` limit. A seventh needs the owner.
- **Within the limit:** move the criterion to the not-yet-planned 24.11, retitled "Listing groups and the folder manager's export, import and delete". This is likely to be re-split at its own plan. One oversized story is rejected.

What the new story inherits (measured from the classic source, read only):

- `%DeepSee.UI.FolderManager` asks `%DeepSee_Admin` or `%Development`.
- Export writes each item's `.DFI` (`$system.OBJ.Export`) to a server directory the page takes as a typed path. With "container class", it saves and compiles a `%DeepSee.UserLibrary.Container` class, exports it (to the server or as a browser download) and deletes it.
- Import runs `$system.OBJ.Load(file,"c")` first: it loads and compiles any class or routine in the file. Only on failure does it fall back to `%DeepSee.UserLibrary.Utils.%Import(file,1)`, which replaces items of the same name.
- Delete is `%DeleteFolderItem` per selected item; the row icon moves an item to `$TRASH` or deletes a folder for all users.

OcuPilot's posture there must load folder-item documents only, never compile, and refuse the container form, as 20.5 refused classes (inference).

**Question 2 (veto: file reach).** The classic term-list page offers only a browser download and an upload, so this plan's server-file variants go beyond it.

- **Recommended:** keep them. They follow every transfer since Story 16.4 (20.5, 19.13, 21.15, 21.19): `PathPort`'s pairs and the allow-list are the fence, and they are the agent's only way to export or import.
- **Alternative:** browser and local only, with export and import made person-only. That takes an AD-53 unadvertised entry (owner-only) and leaves the agent copy alone.

**Governing ADs (Rule 6).**

- AD-65 is the port, and AD-21's sixth case covers the files.
- The write path:
  - AD-6 and AD-34 (proposal and confirm);
  - AD-51 (action writes, with port-composed reads);
  - AD-52 (the port declaration);
  - AD-53 and AD-56 (two callers, and the screen values);
  - AD-54 (import and copy are creates);
  - AD-58 (read-back), AD-14 (the change event) and AD-10 (prohibited review).
- AD-15 is audit, AD-22 the keys, AD-29 and AD-8 the gate, and AD-16 the namespace switch.
- AD-39 (fifth exception): the export's lines reach the screen only.
- AD-44: `%DeepSee.UI.TermListManager`.
- AD-11 and AD-60: file text is untrusted.
- AD-23 is not engaged, because the MCP suite has no term-list handler (24.2, measured).

**Proposed spine lines (Rule 20; for the runner, never written by this run):**

- **AD-21:** "Story 24.10's consumers of the sixth case: the term-list export is an overwriting `file` consumer whose overwrite is a constant and refuses a missing directory; the import's file is a `source`; local text is a screen value."
- **AD-51:** a named entry for `AnalyticsPort`. Its port-composed `EXPORTLIST`, `IMPORTFILE` and `COPYTARGET` reads, and an import refused when the text no longer yields the reviewed digest. Epic 21's runner treated an AD-51 entry as owner-only (U-58).
- **AD-65:** the calls `%ExportCSV` (to a resolved file, or inside an output capture) and `%ParseCSVRecord`.

**Decided in-stage (plan).**

1. Import composes through 24.2's seams, not `%ImportCSV` (Never). The list's modification time is the import's, not the file's `%%MODDATE`, because setting that node would be a third direct node write outside 24.2's two.
2. The export is the vendor's own, so it carries no `%%HIDEVALUE` (measured). This is a named limit. An import reads the flag when a file carries it.
3. A browser export saves `<name>.csv`. The import accepts `.csv` and `.txt`, so it also takes the classic page's `<name>.txt` download.
4. Duplicate keys in a file: the later line wins, as `%SetValue` does, and `FileEntries` counts distinct keys.
5. Values holding a line break do not survive the vendor's CSV. This is a named limit.

**Decided in-stage (implement).**

6. The transfer helpers are copies on `AnalyticsPort` (`TermListImportText`, `TermListExportFile`, `TextDigest`), not lifted: 20.5's are `Private` and carry Interop's codes. The text read (`AtelierPort.ReadText`) and the path resolve (`PathPort`) are shared.
7. Import and copy are action-style (`CREATES` 0) with change action `created`: AD-54's absence read cannot carry the file's digest, so the taken name is the read's own refusal (409 `TAKEN`) and the read-back verdict is `nothingSent`, not `matches`. The agent's confirm answers `createdId` with the new name; a person's action answers the target the person sent (the source, or `import`), since the screen action carries no created id. The Term lists screen re-reads on any `term-list` event.
8. The port declares `COMPOSEDTYPES` `TermLists/EXPORT,TermLists/IMPORT,TermLists/COPY` (the query-carried arguments), and `Prohibited` reads no target for an import, as for 20.5's.
9. `AnalyticsAction` gained `DESTINATIONPERMISSION` (default `WRITE`) and `FILERESOURCE` (default none). The export sets `READ` and `%Admin_FileSystemAccess:USE`, which both callers face, Export to this browser included, as 20.5's export does.
10. The proposal card's rows are data field names (`root`, `path`, `NewName`, `Entries`, `File`, `Name`), so no new label is published. An import's screen answer carries `output.Name` (screen only) for its status line.
11. Import trims each data line's whitespace and reads only leading `%%` lines as header, as `%ImportCSV` does. A script form (AD-59) of an import or copy renders the create and one value write per entry and field in one transaction, at most `SNIPPETENTRIES` (1,000) entries with the rest named in a comment; an export's is `%ExportCSV`.

**Tools.**

| Tool | Kind | Id / values | Screen actions | Key |
|---|---|---|---|---|
| `analytics.termlists.export` | action | `Name`; `root`, `path` (agent: required) | `export` (`root:path`), `export-browser` | `true` |
| `analytics.termlists.import` | create | `Name` the file must hold; `root`, `path` | `import` (`root:path`), `import-local` (`fileName:content`) on target `import` | `true` |
| `analytics.termlists.copy` | create | `Name` (source), `NewName` | `copy` (`NewName`) | `true` |

**Proposed strings (veto item).**

- Actions: "Export", "Import", "Copy term list".
- Titles: "Export term list <name>", "Import a term list", "Copy term list <name>".
- Labels: "Name of the copy".
- Help:
  - "The file holds the term list's properties and every entry, in the CSV form the classic Term List Manager exports. A file already at this name is replaced."
  - "The file must be a term list export. It creates the term list it names; a term list of that name must not exist."
- Refusals:
  - "This file is not a term list export, or it holds no entry."
  - "The file changed after it was reviewed, so nothing was imported."
  - "The file is larger than OcuPilot imports or exports."
- Status lines: "Exported <name>.", "Imported <name>.", "Copied <name> to <new>."

**Extend, don't copy (Rules 2, 31).**

- The port's writes extend `PerformTermList`, its gates and seams.
- The transfer helpers extend 20.5's `ImportText`/`ExportFile`/`CheckExport` shape. Each is a copy on `AnalyticsPort` because those methods are `Private` on `InteropPort` (AD-62's port) and their refusal codes are Interop's.
  - Better still: lift the code-agnostic halves (the text read with its source checks, and the export-file resolve with the directory check) into `PathPort` or a shared helper taking the refusal code, and call them from both ports. This is the implementer's choice, recorded in the spec.
- The mint extends `InteropLookupTableExportMint`'s order. The dialogs are 19.13's, reused.

**Integration (Rules 1, 2).** Integration AC: AC6.

- Consumes:
  - 24.2: the port, tools, seams, descriptors and probe;
  - 20.5 and 19.13: the transfer pattern and dialogs;
  - `PathPort`;
  - the kernel's proposal, governance and audit.
- Consumed-by: the folder-manager sibling (its transfer reuses these helpers), and 24.20 (undo snapshots and reverts these creates).

**Ledger inbox (Rule 17):** none owned (`owned_ledger=0`).

**Contention.** `git log origin/OCU-1-epic21 ^origin/feature/OCU-1_ocupilot-mvp` touches, among this story's files, only `scripts/ci-throwaway.sh`: "(contended: add-only)", if a new armed class joins its roster. The shared rosters (`SurfaceCoverage`, `GovernanceBaseline`, `ClassicPageGate`, `MappingDescriptor`, `ReadTool`, `ToolWrite`, `ToolRoundTrip`, `Baseline.cls`, `Prohibited.cls`) take append-only edits, re-checked before implement.

**Measured** (plan, 2026-11-17, `ocupilot-b-ci`, USER; every list and the `/tmp/e2410probe/` directory removed):

- `%ExportCSV(name,file,1)` wrote UTF-8 `%%NAME`, `%%CAPTION`, `%%FIELDLIST`, `%%DESCRIPTION` and `%%MODDATE`, then one quoted CSV line per key. It wrote no `%%HIDEVALUE` for a list whose flag is 1.
- `%ImportCSV(<file name>, ...)` failed at `%File.Open` on this build. Given a `%Stream.TmpCharacter` copied from that file, it created the list with only `name` and `modDate`, because the stream's CR LF terminator read the file as one line.
- A captured `%ExportCSV(name,"",0)` of a 10,000-entry, two-field list answered 10,005 lines, 285,672 characters, in 0.17 s. 30,000 `%SetValue` calls in one transaction took 0.03 s.

**Measured** (Task 0, 2026-11-17, `ocupilot-b-ci`, USER; the list, the probe class and `/tmp/e2410probe/` removed):

- `%SYS.Audit` held 30,796 rows before and after `%ExportCSV` to a file and inside a capture, so the export is unaudited as the create and value writes are (24.2). OcuPilot's own `ConfigChange` row is the record.
- A list with a comma and a double quote in its caption, a comma and a double quote in two keys, and an accented key exported to a UTF-8 file of 173 bytes; the capture's ten lines equal the file's ten lines read as UTF-8.
- `%ParseCSVRecord` of each file line, encoded to UTF-8 first, gave the header values, the keys `a,b`, `q"k` and `u` plus the accented letter, and every value and field.

## Verification

**Shared surfaces:**

- the Term lists descriptor's row actions and the client action maps;
- `SurfaceCoverage`, `GovernanceBaseline` and `Governance`;
- `Prohibited` covered verbs;
- `ClassicPageGate`, `MappingDescriptor`, `ReadTool`, `ToolWrite`, `ToolRoundTrip`, `ToolEmit`, `ToolDispatch` and `DraftRegistry`;
- the `AnalyticsError` code rosters;
- `strings.ts` and the new EXPERIENCE.md row;
- the `ci-throwaway.sh` arming roster, if a class is armed.

*Every test added or changed passes on a fresh environment, in either order.*

**Setup (`ocupilot-b-ci` only; never `ocupilot-slot-b`):**

- `(loop)` 24.2's load recipe: `rsync` `src/` to `/Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`, then `LoadDir` in HSCUSTOM.
- `(loop)` Before any browser run, rebuild and copy the bundle in, as in 24.2's Verification.

**Commands.** Run each in the foreground with `timeout: 600000`, one test call at a time.

- `(loop)` One call each: `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.AnalyticsTermListTransfer`, then `--class OcuPilot.Test.AnalyticsTermListGate`, `AnalyticsTermListEdit` and `AnalyticsTermListRoutes`. Expected: green.
- `(loop)` One call per class: every roster class under Shared surfaces. Expected: green.
- `(loop)` `cd ui && npm run test:tools && npm run test:components && npm run build`. Expected: green, with the initial bundle under 2,500 kB.
- `(loop)` `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh`. Expected: clean.
- `(loop)` `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/analytics-term-list-editor.browser-spec.mjs`. Expected: green.
- `(once)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17` for k = 1 to 17, one per call. Expected: green. The full browser suite is left to CI.

**Pinning mutations (Rule 19), planned:**

- AC1: the export skips its file → the file leg.
- AC2: `TermListParse` drops record f+2 → the round-trip leg.
- AC3: the copy skips field values → the copy leg.
- AC4: the import skips the taken check → the taken leg.
- AC5: the `TROLLBACK` is removed from the import → the partial-failure leg.
- AC6: the import writes no `%SetValue` for fields → the integration leg.
- AC7: one `SurfaceCoverage` row is removed → that test alone.
- AC8: the probe directory is left behind → `OnAfterAllTests`.

**Mutations run (Rule 19)** on `ocupilot-b-ci`, each reverted byte-identically (`cmp` against the saved copy) and the tree reloaded:

- mutation: the export passes no file to `VendorTermListExport` -> `AnalyticsTermListTransfer` `TestAnExportWritesTheVendorsCsvToAFileAndToTheBrowser` (file, quoting and lines legs) went red.
- mutation: the text bound dropped in `VendorTermListExport` -> `TestAnExportToTheBrowserPastTheTextBoundIsRefused` went red.
- mutation: the digest comparison of `PerformImport` made `If 0` -> `TestAFileChangedAfterItsReviewWritesNothing` went red.
- mutation: `AdmitTermList`'s journal refusal made `If 0` -> `TestTheDestinationRefusesAnImportAndACopyButNotAnExport` (nonjournaled legs) went red.
- mutation: `PerformExport`'s `AuditWrite` dropped -> `TestEachTransferIsAudited` and the agent's export leg went red.
- mutation: `TermListParse` sets every field value empty -> the round trip, local import, agent import (integration, `Region: West`) and person legs went red.
- mutation: `CreateRefusal`'s held check made `If 0` -> the taken legs and the agent's taken mint went red.
- mutation: the field value write of `WriteWholeList` skipped -> the copy, round trip, local and agent legs went red; the `TROLLBACK` of the same method made `TCOMMIT` -> `TestAFailedValueWriteRollsAnImportAndACopyBack` went red; the field write of `WholeListSnippet` skipped -> `TestEachTransfersScriptFormMakesTheSameChange` went red.
- mutation: `NameShaped` admits `^` -> `TestShapeBreachesNeverReachTheVendor` (key leg) went red.
- mutation: the export tool's output lines emptied -> `TestThePersonsExportImportAndCopy` (browser leg) went red; the `Prohibited` import early-out removed -> the person's and the agent's import legs went red; `AnalyticsTermListTransfer.Sweep` stops deleting -> its `OnAfterAllTests` went red.
- mutation: the export's `DESTINATIONPERMISSION` set to `WRITE` -> `AnalyticsTermListGate` `TestEachTransferIsRefusedNamingTheFailedPair` went red (`ToolEmit` stays green: it derives the pair from the same parameter, re-run in review); `FILERESOURCE` ignored in `AnalyticsAction.PrivilegePairs` -> `ToolEmit` went red.
- mutation: the import row removed from `SurfaceCoverage`, the copy row from `MappingDescriptor.CLASSICROSTER`, the export row from `ClassicPageGate.OWNPAIRS`, and `analytics.termlists.export` shipped `false` in `Baseline.cls` -> each of those four tests went red, alone.
- mutation (client): the copy dialog's value renamed from `NewName`, the page's `fill` without its global flag, `exportFileName` keeping `/`, and `'copy'` and `'export'` dropped from the Term lists' `UNDRAWN_ACTIONS` entry -> `term-list-copy-dialog.spec.ts`, `term-list-list.page.spec.ts` and `screen-action-handler-termlist.spec.ts` went red; the dialog's `Name` violation read removed -> its rule leg went red; the copy dialog's value renamed again, rebuilt and redeployed -> `analytics-term-list-editor.browser-spec.mjs` (the copy test) went red, and green after the revert, rebuild and redeploy.
- mutation (review pass): `TermListParse`'s repeated-key lookup made `If 0 &&` -> `TestShapeBreachesNeverReachTheVendor` went red; reverted byte-identically and reloaded.
- (QA) `src/OcuPilot/Test/AnalyticsTermListTransferEdge.cls` (new, armed by `OCUPILOT_ALLOW_PRINCIPALS`, rostered in `scripts/ci-throwaway.sh`): replacement of an existing export file, the server file's text bound and the limit, the import's parse rules, the person's refusals on their field.
- (QA) `ui/src/app/areas/analytics/term-list-list.page.transfer.spec.ts` (new): the Term lists page's registrations, refusal wiring, status lines and local import.
- mutation (QA): the local text bound dropped in `TermListImportText` -> `AnalyticsTermListTransfer` `TestShapeBreachesNeverReachTheVendor` (local text leg) went red; the local file-name slash check dropped -> its file-name leg went red; the export tool's `WriteOutput` answering nothing -> the unconditional output assertions of the person's and the agent's legs went red.
- mutation (QA): `EXPORTOVERWRITES` set to 0 -> `AnalyticsTermListTransferEdge` `TestAnExportReplacesAFileAlreadyAtItsName` went red.
- mutation (QA): the server file's too-large branch of `TermListImportText` made `If 0` -> `TestAnImportFilePastTheTextBoundIsRefusedAndOneAtTheBoundIsRead` (server legs) went red; the local comparison made `>=` -> its limit leg went red.
- mutation (QA): `TermListParse` never ending the header, keeping an entry line's blank space and keeping a repeated key's first line, each alone -> `TestTheImportReadsHeadersBlanksRepeatedKeysAndColumns` went red.
- mutation (QA): the export tool's `ScreenActionDelta` sending only `root` -> `TestThePersonsRefusalsNameTheirFieldAndWriteNothing` went red.
- mutation (QA): the edge class's `Sweep` no longer deleting -> its `OnAfterAllTests` went red; reverted and rerun green, no marker list left in `USER`.
- mutation (QA, client): `endSend` reading another field than `path`, dropping `refused.reason`, the copy status without `<new>` and the `copy` registration removed, each alone -> `term-list-list.page.transfer.spec.ts` went red. Each server mutation was reverted byte-identically (`cmp`) and reloaded into `ocupilot-b-ci`; each client one was reverted byte-identically.
- mutation (review): `TransferSnippet` passing the unresolved `path` to `%ExportCSV` -> `TestEachTransfersScriptFormMakesTheSameChange` (export script legs) went red; `WholeListSnippet`'s cap check made `If 0 &&` -> its past-the-cap leg went red; the import script's digest check made `If 0 &&` -> its changed-digest leg went red; its named-list check made `0 &&` -> its other-list leg went red. Each mutated only in `ocupilot-b-ci`'s source copy, reverted byte-identically (`cmp`) and reloaded; `AnalyticsTermListTransfer` (16), `AnalyticsTermListGate` (4) and `AnalyticsTermListTransferEdge` (4) green after.

## Auto Run Result

Status: done
Blocking condition: none

**Summary.** Batch 1 of Story 24.10 (the term lists): export, import and copy on `AnalyticsPort`, three tools plus the export mint, three error codes, three governance keys at `true`, the Term lists page's Export, Import and Copy, and the EXPERIENCE.md row. Batch 2 (the folder manager) is not built; the story reaches `done` only when it is.

**Files changed.**

- `src/OcuPilot/Port/AnalyticsPort.cls`: the read types `EXPORTLIST`, `IMPORTFILE`, `COPYTARGET` and the writes `EXPORT`, `IMPORT`, `COPY`, with the parse, digest, export-file and seam helpers.
- `src/OcuPilot/Screen/Tool/AnalyticsTermList{Export,ExportMint,Import,Copy}.cls` and `AnalyticsAction.cls`: the tools and two defaulted parameters.
- `AnalyticsError.cls`, `Baseline.cls`, `Prohibited.cls`, `AnalyticsTermListList.cls`: the codes, keys, import arm and row actions.
- `ui/src/app/areas/analytics/term-list-list.page.ts`, `term-list-copy-dialog.ts`, `strings.ts`, `screen-action-handler.ts`, `screen-actions.ts`, `screens.generated.ts`: the client.
- `Test/AnalyticsTermListTransfer.cls` (new), the extended gate, seam and roster classes, `analytics.test.mjs`, the browser spec, and `scripts/ci-throwaway.sh` (add-only roster line).

**Review.** Patches applied: 4 (3 medium, 1 low), all test additions in `AnalyticsTermListTransfer`. Deferred: none. Rejected: 12 lows, each with its reason in the Review Triage Log.

**Follow-up review recommended: true.** Three medium patches landed. Unverified risk: the new size-bound, file-name and unconditional-output assertions have no recorded mutation, and the Term lists page's refusal wiring has no test.

**Verification.** `check-objectscript` and `lint-docs` clean; `test:tools` 2,296 and `test:components` 3,524 green; `npm run build` green; the browser spec 4 of 4 on the redeployed bundle; `AnalyticsTermListTransfer` (16), `Gate`, `Edit`, `Routes` green; the full ObjectScript sweep, shards 1 to 17, green on `ocupilot-b-ci`. The review pass's mutation is recorded under Verification.

**Residual risks.** `AnalyticsTermListTransfer.cls` is about 690 lines. `ci-timings.json` has no row for the new class. The proposed spine lines (AD-21, AD-51, AD-65) stay for the owner.
