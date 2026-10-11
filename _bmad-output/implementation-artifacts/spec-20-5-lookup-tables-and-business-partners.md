---
title: 'Story 20.5: Lookup tables and business partners'
type: 'feature'
created: '2026-10-11'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
warnings: [oversized, multiple-goals]
deferred:
  - summary: >-
      Business partners' save and remove are this story's stated partial (the AC: "save and remove need custom endpoints, and the read-only half ships first"); Design Notes › Business partners' save and remove carries the charter the lead numbers.
    evidence: |-
      epics.md Story 20.5's second AC and the Epic 20 preamble name business-partner save and remove among the rows that ship read-only first; catalog row IO-14.
      Read at this plan: EnsPortal.BusinessPartners declares no EDITRESOURCE, renames by %DeleteId then %Save with no transaction, removes with no check of items naming the partner, and audits nothing.
    location: >-
      src/OcuPilot/Port/InteropPort.cls
    severity: med
---

<intent-contract>

## Intent

**Problem:** A production's reference data still lives only in the classic portal: its lookup tables (`EnsPortal.LookupSettings`, which rules and transformations read through `Lookup()`) and its business partners (`EnsPortal.BusinessPartners`). Nothing in OcuPilot lists, edits, imports or exports a lookup table, or shows a partner.

**Approach:** Extend `Port/InteropPort` (AD-62) with three list endpoints (`LookupTables`, `LookupEntries`, `BusinessPartners`), one-object reads composed for each write, and the lookup writes: add, set and remove an entry, delete a table, and import and export a table, each a confirmed proposal for the agent and a person's own action on the screen (AD-53, AD-55). A table is created by adding its first entry. Business partners ship read-only, the AC's stated partial. Every screen's read tool derives from its descriptor (FR-80).

## Boundaries & Constraints

**Always:**

- Every new read and write goes through `InteropPort.Invoke` behind its gate (AD-29, AD-62 (2)): the endpoint's pairs, then READ on the namespace's globals database, or WRITE for a lookup write. Measured at this plan, the vendor's lookup and partner calls check no privilege, so this gate is the whole gate.
- Pairs are the classic pages' checks. Lookup reads use `%Ens_Portal:USE` and `%Ens_LookupTables:READ`. Lookup writes add `%Ens_LookupTables:WRITE` (the page's `EDITRESOURCE`). Business partners use `%Ens_Portal:USE` and `%Ens_ProductionConfig:READ`. Every refusal names its pair (AD-8, AD-44).
- The port calls the vendor's own classes, in the caller's process, switched by explicit save and restore (AD-16). It never calls `%Api.InteropEditors.*`, and calls no `OcuPilot.*` class while switched. The lookup calls are `Ens.Util.LookupTable`'s `%UpdateValue`, `%RemoveValue`, `%ClearTable` and `getTimestamp`, and `$System.OBJ`'s export and load of one `.LUT` document, as the classic page and its Import dialog call them.
- Every lookup write takes the vendor's own table lock, as the classic page's save does: `Lock +^Ens.LookupTable(<table>):3`, released after the write (`EnsPortal/LookupSettings.cls`:282). The write also takes AD-34's per-target hold.
- Before any vendor call, the port refuses by name whatever the vendor would answer as a silent success or would get wrong (AD-62 (5)): a key the table holds (on add), a value the entry already holds (on set), a table held in another letter case, a namespace under source control, and a held vendor lock.
- Table names, keys, values, descriptions and contact fields are untrusted content and reach the model only through AD-60. An entry whose key matches the credential pattern (`Kernel.Audit.Log.IsCredentialName`) is answered with an empty `Value` and `Secret` true, and an add or set of such a key is refused before any vendor call, from both callers. This is 20.22's rule for item settings, applied to keys.
- A write records OcuPilot's own `ConfigChange` audit row from either caller, through `AuditRuntime`, because the vendor records none (measured). The row never carries a value.
- Edits to files Epic 18 is changing are add-only: roster rows, list entries, and the count pins that move with them (Design Notes › Contended files).

**Never:**

- No business-partner save, rename or remove (the stated partial), and no empty-table create (Design Notes › Decisions).
- No `%Api.InteropEditors.*`, no `Ens.Util.LookupTable.%Import` merge (the legacy form without a forced name), no SQL on `Ens_Util.LookupTable`, and no direct `Set` or `Kill` of a vendor global.
- No load of anything but the one `.LUT` document an import was reviewed with. Classes, routines and other documents in a file are refused, never loaded.
- No edit to `Screen/Registry.cls`, `ui/tools/screen-mirror.mjs` or `navigation.ts`, and no `angular.json` edit without the gate's ruling (Design Notes › Gate questions, Q2).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Lookup tables | The namespace's tables | One row per table, `Name` and `Modified` (the vendor's `$ZTS` stamp in the reader's local time), by name; a name opens its entries | — |
| Entries | `table` criterion | One row per entry in the vendor's subscript order, `Table, Key, Value, Secret`; a credential-named key reads `Value` "" and `Secret` true | Unknown table: 404 `PORT.NOTFOUND`; no criterion: 400 |
| Add entry (and New table) | `Table, Key, Value`; the entry is absent | `%UpdateValue(T,K,V,1)`; a table absent until now is created with this entry | Key held: 409 `INTEROP.LOOKUP.TAKEN`; table held in another case: 409 `INTEROP.LOOKUP.TABLECASE`; credential key: 409 `INTEROP.LOOKUP.SECRET`; bad name, key or value: 422 |
| Set value | An entry and a new value (empty allowed) | `%UpdateValue(T,K,V,0)` | Same value: 409 `INTEROP.LOOKUP.SAME`; credential key: 409 `SECRET`; absent: 404 |
| Remove entry | An entry | `%RemoveValue(T,K)`. Removing a table's last entry removes the table (measured), and the card and dialog say so | Absent: 404 |
| Delete table | A table | `%ClearTable(T)`; every entry goes | Absent: 404 |
| Any lookup write | Namespace under source control, or the vendor lock held past 3 s | Nothing written | 409 `INTEROP.LOOKUP.SOURCECONTROL` or `INTEROP.LOOKUP.LOCKED` |
| Export | A table; a server file (`root`, `path`) or the browser | The vendor's export of that one `.LUT` document, the classic page's form | Browser text over 3,000,000 characters: 409 `INTEROP.LOOKUP.TOOLARGE`; `PATH.*` from PathPort |
| Import | An export file (local text or server file) and the table it holds | That table is replaced, or created, with the file's entries; keys the file lacks are removed | Not exactly one `.LUT` document with at least one entry, or anything else in the file, or the legacy form: 409 `INTEROP.LOOKUP.IMPORTSHAPE`; file or table changed since review: 409 `INTEROP.LOOKUP.IMPORTCHANGED` |
| Business partners | The namespace's partners | One row per partner, `Name, Description` and both contacts' `Contact, Title, Email, Phone, Mobile, Notes`; no row action | — |
| Gate | A caller missing one declared pair | Refused before any vendor call | 403 naming the pair |
| Namespace | No interoperability | Refused | 409 `INTEROP.NAMESPACE` |

</intent-contract>

## Code Map

### Port (`src/OcuPilot/Port/InteropPort.cls`, 3423 lines)

- Header :1-50 (write list and seam list), `ENDPOINTS` :60 (read by `ui/tools/screen-mirror.mjs`:1084 and pinned literally at `Test/InteropHostDescriptor.cls`:22), endpoint constants :62-104.
- Pair sets :109-157: `PRODUCTIONPAIRS` :109 serves Business partners as it is. `READPERMISSION` and `WRITEPERMISSION` :160/:166. Type constants :176-250, query keys :254-334.
- Write predicates `IsWrite` :415, `IsItemWrite` :421, `IsSettingWrite` :428 and `IsRuntimeWrite` :436. The `tWrite` expression is duplicated at :603 and :679, so a new predicate joins both.
- `Pairs` :463, `Serves` :498, `Invoke` :592 (dispatch :609-620), `Admit` :675 (routines-database WRITE only for item and setting writes, :689).
- Siblings to copy from:
  - `ReadItem` :1259: an add's inverted read (404 is success; a held name is `TAKEN`).
  - `SourceControlled` :933, a seam.
  - `Refuse`, `Conflict`, `Absent`, `Deny`, `Unavailable` and `Fail` :2188-2233; `Statused` :2135 and `Mapped` :2162 (`<PROTECT>` becomes 403).
  - `AuditRuntime` :3239, reused as it is.
  - `LocalStamp` :2710, which takes a UTC `YYYY-MM-DD HH:MM:SS.fff` string.
  - `SnippetForm` :3251, `Snippet` :3271, `Literal` :3414.
- `src/OcuPilot/Port/PathPort.cls`: `PAIRS` :50 and `Resolve(root, path, kind, …, pOverwrite)` :269 (Part B).
- `src/OcuPilot/Port/AtelierPort.cls`: `ROOTKEY`/`PATHKEY` :388/:390, `MAXIMPORTCHARACTERS` 3,000,000 :419, and the import file read :2097-2160 (Part B).

### Tools (`src/OcuPilot/Screen/Tool/`)

- `InteropAction.cls` (140 lines): `WRITERESOURCE`, `ROUTINESDATABASE`, `STATEMARKER`, `CONSEQUENCECODE`, `PrivilegePairs`, `PortQuery`, `ArgumentNamespace`.
- The siblings each new tool extends or copies:

  | New tool | Sibling | What it shares |
  |---|---|---|
  | entry add | `InteropItemAdd.cls` | `CREATES`, `SENDSBODY`, `FieldRows`, `ComposeCreate`, `READBACKTOOL`, `PortQuery` always asking for the add |
  | entry set | `InteropSettingSet.cls` | `SCREENVALUES`/`SCREENEMPTY` `set=Value`, `READBACKFIELDS` `Value`, `FieldRows` |
  | entry remove | `InteropItemRemove.cls` | `DESTRUCTIVE`, `CONSEQUENCECODE`, removal rows in `StateDiff` |
  | the mint | `InteropSettingMint.cls`/`InteropItemMint.cls` | composite id from `NAMESPACEARGUMENT` plus `IdArgument` |
  | export and import (Part B) | `ExplorerExport.cls`, `ExplorerImport.cls`, `ExplorerExportMint.cls`, `ExplorerImportMint.cls` | `FilePairs`, `ScreenActionDelta`, `BROWSERACTION`; `TaskExport.AddFileArguments` and `FileProblem` |

- `InteropSettingAction.cls` `SecretProblem` :101 is the secret-name rule to mirror on a key.

### Save route

- `src/OcuPilot/Area/Interop/ItemSave.cls`: Production items' Add on `POST /interop/items`. It runs the gate, the hold (`Operation.HoldTool`, DW-1882), `Unexpected`, `ProductionHeld`, `AddViolations`, `Absent` (409 `ITEMTAKEN`), `ComposeCreate`, `Prohibited`, the port write and `ReadBack.ForSave`.
- `src/OcuPilot/Api/Router.cls`: route :264, thin `Call` method :1863.

### Registries

- `Kernel/EntityType.cls` `TYPES` :115 (70 entries, pinned at `Test/Descriptor.cls`:1775).
- `Kernel/Proposal/Prohibited.cls`:
  - `COVEREDTYPES` :259, interop `TYPE*` parameters :654-673, and the fail-closed exclusion :1360.
  - `PermittedChangeFields` :1108 (`production-item-setting`'s `Value` :1123) and `PermittedCreateFields` :1245 (`production-item` :1279).
  - The `ReviewedFewOnly` arms :1644-1674.
- `Kernel/Governance/Baseline.cls`: interop keys :219-234.
- `Api/InteropError.cls` (359 lines): codes as `Parameter X` plus `REASONX`; `Codes` :250, `ConsequenceCodes` :256, the family lists :262-296, `ReasonFor` :308. `Api/Error.cls` holds 989 of 1,000 parameters, so new codes go here. `ui/tools/interop.test.mjs`:29 `SENTENCES` pins each reason to `strings.ts` and to EXPERIENCE.md.

### Screens and client

- Descriptor shapes to copy: `Screen/Descriptor/InteropItemList.cls` (a list with `primaryAction` and `rowActions`, parent-scoped, composite id) and `InteropItemSettingList.cls` (criterion shape :48-66; `set` and `reset`).
- Interoperability side bar: positions 1-7 are Productions to Jobs (`InteropJobList.cls`:20).
- `ui/src/app/shell/screen-outlet.ts` `DESCRIPTOR_PAGES` :156 (interop :273, :275).
- `ui/src/app/shell/screen-action-handler.ts`: `SCREEN_ACTION_DESCRIPTORS` :67 (interop :123-139), `UNDRAWN_ACTIONS` :375 (`set` :400), `DESTRUCTIVE_CONSEQUENCES` :491 (:544-550), `TYPED_NAME_ROWS` :585 (:618-624), `sendFor` :1442.
- `ui/src/app/areas/interoperability/`:
  - `interop-item-list.page.ts`, `interop-item-add.store.ts` (:175-229 the POST; :217 the event naming its tool) and `interop-item-add-dialog.ts`
  - `interop-item-setting-list.page.ts` (:103 registers `set`; :152 `sendFor`) and `interop-item-setting-dialog.ts`
- Part B client:
  - `areas/system-explorer/explorer-export-dialog.ts`
  - `explorer-import-dialog.ts` (`FileReader` :158-175, cap :9)
  - `code-list.page.ts` :572/:578/:597
  - `core/csv.ts` `saveText` :93, `shell/server-path-picker.ts`, `core/screen-actions.ts` :49
- `ui/src/app/core/strings.ts`: interop block :6249-6596, every key citing `/** EXPERIENCE.md:604 */`. Literal count 3,144; bound 3,400 at `ui/tools/strings.test.mjs`:610-611.
- EXPERIENCE.md anchors:
  - :159, the Interoperability side-bar sentence
  - :173, the dialog list
  - :604, the last Fixed-strings row (210 citations, so nothing is inserted above it)
  - :896, auto-refresh (unchanged)

### Tests and rosters

- Templates:
  - `Test/InteropItemDescriptor.cls`, `InteropItemControl.cls` (create and remove round trips) and `InteropItemRefusals.cls`
  - `InteropSettingControl.cls` (keyed set)
  - `InteropItemGate.cls` with `InteropItemSeam.cls` (`Arm(, pSourceControlled)` :14, `SourceControlled` :104)
  - `InteropHostRead.cls` (snapshot-unchanged leg)
- Rosters this story moves:

| File | Anchor | What |
|---|---|---|
| `Test/InteropHostDescriptor.cls` | :22 | the `ENDPOINTS` literal |
| `Test/Descriptor.cls` | :1775 | entity types 70 → 73 |
| `Test/ReadTool.cls` | :93-94 | 355 → 358 and the sorted names |
| `Test/Navigation.cls` | :531-532 | interop screens 15 → 18 and their order |
| `Test/SurfaceCoverage.cls` | screens :219-233, tools :380-394 | a row per screen and write tool |
| `Test/InteropFloor.cls` | :42-62 | what each role holds (Design Notes › Decisions) |
| `Test/GovernanceBaseline.cls` :15, `Governance.cls` :42-45, `ToolDispatch.cls` :174-182, `ClassicPageGate.cls` :75/:84/:157 | — | disabled keys and `CLASSICPAGES` tools |
| `Test/ToolRoundTrip.cls` | :86-90 | new tools |
| `Test/EndpointCoverage.cls` | :276 | probe row for the new route |
| `Test/SaveHoldCoverage.cls` | :20, :29, :95-98 | `HeldLeg` for the new route |
| `Test/DraftRegistry.cls` | :46-60 | target-id shapes if needed |
| `ui/tools/navigation.test.mjs` | :345-373 | route roster |
| `ui/tools/screen-mirror.test.mjs` | ~:1394-1401, :2407-2436 | criteria owners and own-privilege owners |
| `ui/browser/structural-walk.mjs` | `SKIP` :97 (:104-116) | the entries route |
| `scripts/ci-throwaway.sh` | :416-442 | `# classes:` arming lines, held by `ui/tools/ci.test.mjs`:2366 |

### Vendor (read only)

- `irislib/Ens/Util/LookupTable.cls`:
  - storage `^Ens.LookupTable(Table,Key)=Value` :342-352
  - top node `$LB(timestamp, isSystemCreated)` :293/:305
  - `%ClearTable` :29, `%ExistsTable` :37, `%UpdateValue` :222, `%RemoveValue` :262, `getTimestamp` :297 (`[Internal]`, read by the classic page and the vendor's `.LUT` document), query `Enumerate` :309
  - triggers :270-287
- `irislib/Ens/Util/LookupTableDocument.cls`: `Load` :22 (`%Export`), `ImportStream` :34-60 (`%Import` with the forced name, which replaces the table), `Delete` :71 (`%ClearTable`).
- `irislib/EnsPortal/LookupSettings.cls`:
  - `RESOURCE` :10, `EDITRESOURCE` :13, `GetHyperEventResources` :1297-1305
  - load :204 (the momentary lock; entries by `$Order`)
  - save :271-362 (lock :282, timestamp check :288-294, source control :296, zero rows :307-308)
  - delete :723, export `$system.OBJ.Export(T.LUT, file, "-d")` :1139, import through `EnsPortal.Dialog.Import?TYPE=Lookup` :955
- `irislib/EnsPortal/Dialog/Import.cls`: `RESOURCE` :20, `ImportResults` `$System.OBJ.Load(…,.SelectedItems)` :49, no audit (:42).
- `irislib/Ens/Config/BusinessPartner.cls`:
  - IdKey `PartnerName` :20, properties :24-33
  - query `List` :35-38 (`PartnerName, Description, PrimaryContact, Phone`)
  - contacts in `BusinessPartnerContact.cls`:12-27
- `irislib/EnsPortal/BusinessPartners.cls`: `RESOURCE` :13, no `EDITRESOURCE`, `SaveItem` :318, `DeleteID` :275.
- `irislib/Ens/Util/FunctionSet.cls`:44-46: `Lookup()` reads `$G(^Ens.LookupTable(table,value),default)` with no cache, so a change acts on the next call.

## Tasks & Acceptance

**Execution.** The split seam is between Part A and Part B (Design Notes › Split): Part B's tasks, its two ACs and its tests move as a block.

- [ ] **Task 0** (`ocupilot-b-ci` only, through `docker exec`). Record each item as a `Task 0:` line under Verification:
  - `NormalizePage` spells `EnsPortal.LookupSettings`, `EnsPortal.BusinessPartners` and `EnsPortal.Dialog.Import` as written.
  - `%ExistsTable(name, 1, , .match)` answers a case-variant of an existing table whose prefix is shared by another table, without an error. The source's upper-case branch can fall off without a `Quit`. If it errs, `TABLECASE` walks `Enumerate` comparing `$ZConvert(…, "U")`, bounded by the table count.
  - `LocalStamp` gets `$ZDateTime(getTimestamp, 3, , 3)` (the stamp is `$ZTS`, UTC, measured).
  - Part B: the screen action route accepts an import's target table that does not yet exist.

**Part A: lookup tables, entries and business partners.**

- [ ] `src/OcuPilot/Port/InteropPort.cls` (extend):
  - `ENDPOINTS` gains `LookupTables,LookupEntries,BusinessPartners`.
  - Pair sets:
    - `LOOKUPPAIRS` = `%Ens_Portal:USE,%Ens_LookupTables:READ` for both lookup endpoints
    - Business partners take `PRODUCTIONPAIRS`
    - `LOOKUPWRITEPAIR` = `%Ens_LookupTables:WRITE`
  - Types:
    - reads `LOOKUPTABLE` and `LOOKUPENTRY`
    - writes `ADDENTRY`, `SETENTRY`, `REMOVEENTRY` and `DELETETABLE`
    - `TABLEKEY` = `table`, the entries list's criterion
  - `IsLookupWrite` joins both `tWrite` lines (:603, :679); no routines database.
  - `Serves`:
    - `LookupTables`: `LIST`, `LOOKUPTABLE`, `DELETETABLE`
    - `LookupEntries`: `LIST`, `LOOKUPENTRY`, `ADDENTRY`, `SETENTRY`, `REMOVEENTRY`
    - `BusinessPartners`: `LIST`
  - `Invoke` sends the two lookup endpoints to one dispatcher, `InvokeLookup`, beside `InvokeItems`, checking `maxRows` as the others do. Partners go to `ListPartners`.
  - Reads:
    - Tables come from `Enumerate` and `getTimestamp`, with `Modified` through `LocalStamp`.
    - Entries are walked by `$Order` under the table, as the classic load does, capped at `maxRows`. Each row carries `Table`.
    - `LOOKUPTABLE` answers `{Name, Entries, Modified, Namespace}`.
    - `LOOKUPENTRY` answers `{Table, Key, Value, Secret, Namespace}`. It carries no count, so another entry's change never moves a set's merge fingerprint.
    - Partners come from the `List` query plus `%OpenId` per surviving row for the contacts.
  - Composed refusals (`ACTIONKEY`), in this order:
    1. `SOURCECONTROL` for any lookup write (`SourceControlled`).
    2. For `ADDENTRY`: present is `TAKEN`, otherwise absent is success (404 inverted as `ReadItem` does); a table absent exactly but held in another case is `TABLECASE`; a credential key is `SECRET`.
    3. For `SETENTRY`: `SECRET`.
  - Writes (`PerformLookup`): under `Lock +^Ens.LookupTable(T):3` (not got: `LOCKED`), re-read, then the vendor call.
    - `SETENTRY` with an unchanged value is `SAME`.
    - `ADDENTRY` and `SETENTRY` run `LookupViolations` again.
    - Release the lock, restore the namespace, then `AuditRuntime(verb, type, id, {Namespace, Table, Key?, Entries?})` with the verbs `add`, `set`, `remove` and `delete`.
    - Answer the re-read row, or after a remove the stub `{Table, Key, Namespace}`, and after a delete `{Name, Namespace, Entries: 0}`.
  - `LookupViolations(table, key, value, Output violations)`, public for the Save route:
    - `Table` 1-255 characters, no control character (`INTEROP.LOOKUP.TABLENAME`)
    - `Key` 1-255 characters, no control character (`INTEROP.LOOKUP.KEY`)
    - `Value` at most 32,000 characters (`INTEROP.LOOKUP.VALUE`)
    - These are the vendor's `MAXLEN`s, measured (255 + 220 subscripts fit).
  - Snippets: a `SnippetForm` arm and `LookupSnippet` rendering each write's vendor call with `Literal` (lock, call, unlock).
  - Header: the write and seam lists gain the lookup writes and the new seam `LockTable`.
- [ ] `src/OcuPilot/Api/InteropError.cls`: `LookupCodes()` and `LookupPreconditionCodes()` join `Codes()` and `ReasonFor`.
  - Refusals: `TAKEN`, `TABLECASE`, `SAME`, `SECRET`, `SOURCECONTROL` and `LOCKED`, each `INTEROP.LOOKUP.*`.
  - Violations: `TABLENAME`, `KEY` and `VALUE`.
  - Consequences, which join `ConsequenceCodes()`:
    - `REMOVE`: "Removing this entry cannot be undone from OcuPilot. When it is the table's last entry, the table is removed too."
    - `DELETE`: "Deleting this lookup table removes every entry in it. Rules and transformations that read it then get their default value."
- [ ] `src/OcuPilot/Kernel/EntityType.cls` (append): `lookup-table` (its name), `lookup-entry` (`[Table, Key]`) and `business-partner` (its name), each kept exactly, with a class-comment line each.
- [ ] `src/OcuPilot/Kernel/Proposal/Prohibited.cls` (add-only): `lookup-table` and `lookup-entry` join `COVEREDTYPES`, the `TYPE*` parameters and the exclusion :1360, each with a `ReviewedFewOnly` arm. `PermittedChangeFields("lookup-entry")` is `Value`; `PermittedCreateFields("lookup-entry")` is `Table, Key, Value, Namespace`. OcuPilot stores nothing in `^Ens.LookupTable` (grep: 0), so no self-protection arm exists (AD-10).
- [ ] Tools (new, `src/OcuPilot/Screen/Tool/`):
  - `InteropLookupEntryAction` (abstract, extends `InteropAction`):
    - descriptor `InteropLookupEntryList`, `WRITERESOURCE` `%Ens_LookupTables`, `READTYPE` `LOOKUPENTRY`, `STATEMARKER` `Secret` (the read answers it, and no argument carries it)
    - `MintClass` `InteropLookupEntryMint`, `IdArgument` `Key`, `Endpoint` `LookupEntries`
    - `ArgumentProblem` and the confirm's repeat of it run the key's `SECRET` rule for an add and a set
  - `InteropLookupEntryMint` extends `InteropItemMint`, as `InteropSettingMint` does: `NAMESPACEARGUMENT` `Table`, with the descriptions and separator nouns of a table and a key.
  - `InteropLookupEntryAdd`, `interop.lookupentries.add`:
    - `CREATES`, `SENDSBODY`, `WRITETYPE` `ADDENTRY`, `CHANGEACTION` `created`
    - `FieldRows` `Value`; `PortQuery` always asks for the add
    - `READBACKFIELDS` `Value`, `READBACKTOOL` the set
    - `PRECONDITIONCODES` the add's refusals; key `true`
  - `InteropLookupEntrySet`, `interop.lookupentries.set`:
    - `SENDSBODY`, `WRITETYPE` `SETENTRY`, `SCREENACTIONS` `set`
    - `SCREENVALUES` and `SCREENEMPTY` `set=Value`, `READBACKFIELDS` `Value`; key `true`
  - `InteropLookupEntryRemove`, `interop.lookupentries.remove`:
    - `WRITETYPE` `REMOVEENTRY`, `SCREENACTIONS` `remove`, `DESTRUCTIVE`
    - `FINGERPRINTSUBJECT` `Value`, `CONSEQUENCECODE` `INTEROP.LOOKUP.REMOVE` (static: its sentence covers the last entry); key `false`
  - `InteropLookupTableDelete`, `interop.lookuptables.delete` (extends `InteropAction`):
    - descriptor `InteropLookupTableList`, `WRITERESOURCE` `%Ens_LookupTables`, `READTYPE` `LOOKUPTABLE`, `WRITETYPE` `DELETETABLE`
    - `STATEMARKER` `Modified`, `SCREENACTIONS` `delete`, `DESTRUCTIVE`
    - `FINGERPRINTSUBJECT` `Entries,Modified`, `CONSEQUENCECODE` `INTEROP.LOOKUP.DELETE`, `IdArgument` `Name`; key `false`
    - `StateDiff` shows `Name` and `Entries` as removed rows, as `InteropItemRemove`'s does; the entry remove's shows `Key` and `Value`
  - None declares `CLASSICPAGES`: each is performed on `EnsPortal.LookupSettings` itself (AD-44).
- [ ] `src/OcuPilot/Area/Interop/ItemSave.cls` (in place, Epic 20's own) becomes extensible, with item behavior unchanged:
  - `ParentHeld(namespace, parent)` and `Violations(namespace, parent, name, fields, .v)` become overridable class methods wrapping today's `ProductionHeld` and `AddViolations` calls.
  - Parameters `TAKENCODE` and `TAKENREASON` replace the literal `ITEMTAKEN` in `Absent`. `PARENTEMPTYCODE` and `NAMEEMPTYCODE` replace the two codes `Create` gives an empty member (today `PORT.FIELD.SHAPE` and `INTEROP.ITEM.NAME`).
- [ ] `src/OcuPilot/Area/Interop/LookupEntrySave.cls` (new, extends `ItemSave`): `POST /interop/lookup-entries`.
  - `CREATETOOL` `InteropLookupEntryAdd`, `DESCRIPTORCLASS` `InteropLookupEntryList`; members `Table` and `Key` through the two member parameters.
  - `ParentHeld` answers 1, because a missing table is created.
  - `Violations` calls `LookupViolations`. `TAKENCODE` is `INTEROP.LOOKUP.TAKEN`, and the empty-member codes are `INTEROP.LOOKUP.TABLENAME` and `INTEROP.LOOKUP.KEY`.
  - `Api/Router.cls` (add-only): the route after :264 and a thin `InteropLookupEntryCreate`.
- [ ] `src/OcuPilot/Kernel/Governance/Baseline.cls` (append after :234): the four keys as above.
- [ ] Descriptors (new, `src/OcuPilot/Screen/Descriptor/`). Each has area `interoperability`, scope `namespace`, three suggested prompts, a table, context fields, `classicPage`, no refresh, and its `toolIdentifier`. Privileges are the endpoint's pairs, and `ownPrivileges` those less `%Ens_Portal:USE`.
  - `InteropLookupTableList`:
    - route `interoperability/lookup-tables`, `sideBarPosition` 8, `list`
    - entity `lookup-table`, single (`Name`), `secondaryEntityTypes` `["lookup-entry"]`, so an entry change re-reads the list
    - `primaryAction` `add` (New table), `rowActions` `[delete]`
    - read `LookupTables` `[Name, Modified]`; `EnsPortal.LookupSettings`; `interop.lookuptables`
  - `InteropLookupEntryList`:
    - route `interoperability/lookup-tables/entries`, position 0, `list`, `parentScope` `interoperability/lookup-tables`
    - criterion `table` (text, 255, a hint naming `interop.lookuptables.read`'s `Name`)
    - entity `lookup-entry`, composite `[Table, Key]`, `primaryAction` `add`, `rowActions` `[set, remove]`
    - read `LookupEntries` `[Table, Key, Value, Secret]`; `EnsPortal.LookupSettings`; `interop.lookupentries`
  - `InteropBusinessPartnerList`:
    - route `interoperability/business-partners`, position 9, `list`
    - entity `business-partner`, single (`Name`), no actions; read-only, so it declares `table.emptyNextKey` and no `emptyAgentKey` (`Registry` :2695)
    - read `BusinessPartners` with the matrix's fields; columns Name, Description, Primary contact, Phone and Email
    - `EnsPortal.BusinessPartners`; `interop.businesspartners`
- [ ] Client:
  - `areas/interoperability/interop-lookup-table-list.page.ts` hosts `<app-list-page />` and the entry dialog in New-table mode, and registers `add`.
  - `interop-lookup-entry-list.page.ts` hosts the entry dialog in add mode and the set dialog; it registers `add` and `set`, and `set` is undrawn.
  - `interop-lookup-entry-dialog.ts` with `interop-lookup-entry.store.ts`, `POST /api/ocupilot/interop/lookup-entries`:
    - publishes a `created` event naming `interop.lookupentries.add`
    - reuses `violationsOf`/`reasonForField` and the item add store's POST-and-publish core
    - when more than that core would be copied, the core is lifted into one function both stores call
  - Set value reuses `interop-item-setting-dialog.ts`, its title and label made inputs. Where a value can be long, a multi-line field is used.
  - `DESCRIPTOR_PAGES` gains two rows.
  - `screen-action-handler.ts` (add-only):
    - both lists join `SCREEN_ACTION_DESCRIPTORS`
    - `set` goes into `UNDRAWN_ACTIONS`
    - `DESTRUCTIVE_CONSEQUENCES` gains the two consequences
    - `TYPED_NAME_ROWS` names `Name` for a table and `Key` for an entry
  - `strings.ts` (add-only): titles, empty states, agent lines, prompts, column labels, the `table` criterion, dialog strings, and the refusal and consequence sentences. Existing values are reused.
  - Regenerate `screens.generated.ts`.
- [ ] `EXPERIENCE.md`, no line inserted above :604:
  - :159 gains " · Lookup tables · Business partners", and that a table's name opens its entries.
  - :173 gains the entry dialog (New table and Add entry) and Set entry value, and the table delete and entry remove join the delete confirmations.
  - :604 gains a Story 20.5 clause with every new literal.
  - Then `cd ui && npm run test:tools`.
- [ ] Tests (new, each under about 500 lines, one class per call). The fixtures create their own tables (`OcuProbe205*`) and partner in USER and remove them in `OnAfterAllTests`:
  - `Test/InteropLookupDescriptor.cls`:
    - the three declarations, their three read tools and the four write tools, with `Pairs`, `Serves` and `ENDPOINTS`
    - the key defaults and the codes' lists
    - every write's `Snippet` form
    - `LookupViolations`' bounds at 255/256 and 32,000/32,001
  - `Test/InteropLookupRead.cls`:
    - each list's rows, through the port, the screen read route and the read tool, which answer the same rows
    - `maxRows`, `Modified` local, the credential key's empty `Value`, and 404/400/409
    - partners with their contacts
    - AC7's snapshot: `^Ens.LookupTable` and `^Ens.Config.BusinessPartnerD` equal before and after every read
  - `Test/InteropLookupControl.cls`: for add (Save route and agent), set (row action and agent), remove (row action and agent, including the last entry taking the table), and delete (row action and agent):
    - read-back verdicts
    - the change event's triple
    - the `ConfigChange` audit row carrying no value
    - a confirm refused target-changed after an out-of-band `%UpdateValue`
  - `Test/InteropLookupRefusals.cls`: each matrix refusal from both callers, with nothing written:
    - `SOURCECONTROL` via `InteropItemSeam.Arm(, 1)`
    - `LOCKED` via the `LockTable` seam
  - `Test/InteropLookupGate.cls` (armed under `OCUPILOT_ALLOW_PRINCIPALS`, reusing `InteropItemGate`'s `FailedPair` and `LegText` as `InteropHostGate` does):
    - a principal holding exactly each endpoint's or tool's pairs reads or writes
    - dropping each pair, or holding READ only on the globals database, is refused by name before any vendor call, through the port and through the screen routes
- [ ] Roster sweep (Rule 30). Every row of the Code Map's roster table, the arming lines for the new classes, and the `ItemSave` refactor's consumers (`InteropItemControl`, `SaveHoldCoverage`) join the targeted set.
- [ ] `ui/browser/interop-lookup-tables.browser-spec.mjs` (new). `before` and `after` follow `interop-items`'. Every step waits for `waitForMapAnswered` and its rows:
  1. New table creates a table with its first entry.
  2. Its name opens the entries.
  3. Add, Set value and Remove (typing the key) each change the rows.
  4. Delete (typing the table's name) removes it from the list.
  5. Business partners lists the probe partner, with no action trigger.

**Part B: import and export.**

- [ ] `InteropPort.cls` (extend):
  - Types: reads `IMPORTTABLE`; writes `IMPORT` and `EXPORT`, served on `LookupTables`.
  - `EXPORT`:
    - Gate: `LOOKUPPAIRS` plus READ on the globals database.
    - With `root` and `path`: `PathPort.Resolve(…, "file", , , 1)` (an overwriting consumer, constant), then `$System.OBJ.Export(T_".LUT", file, "-d")`.
    - Without them: `$System.OBJ.ExportToStream(T_".LUT", .s, "-d")` answered as lines. Over 3,000,000 characters is `TOOLARGE`.
    - Audit verb `export`.
  - `IMPORTTABLE`, composed from the values: the file's text (`content`, or the resolved `source` read as UTF-8, both capped at `AtelierPort.#MAXIMPORTCHARACTERS`) yields `{Table, FileEntries, Digest, Present, Entries, Modified, Namespace, root, path, fileName}`.
    - `$System.OBJ.LoadStream(…, listonly 1)` must list exactly `<Table>.LUT`, else `IMPORTSHAPE`. This also refuses the legacy `<lookupTable>` form, which the lister rejects (measured: #6301).
    - `FileEntries` is counted with `%XML.TextReader` and must be at least 1.
    - `Digest` is the SHA-256 of the text.
  - `IMPORT`:
    - Gate: `LOOKUPWRITEPAIR` plus WRITE on the globals database; `SOURCECONTROL`; the vendor lock.
    - The re-composed read must give the reviewed `Digest`, `Entries` and `Modified`, else `IMPORTCHANGED`.
    - Then `$System.OBJ.LoadStream(text, "-d", .err, .loaded, 0, T_".LUT")`, which reaches the `.LUT` document's `ImportStream` and replaces the table (measured).
    - Audit verb `import`.
  - Snippets for both.
- [ ] `InteropError.cls`: `IMPORTSHAPE`, `IMPORTCHANGED` and `TOOLARGE`; consequence `IMPORT`: "Importing replaces the table's entries with the file's, and entries the file does not hold are removed."
- [ ] Tools:
  - `InteropLookupTableExport`, `interop.lookuptables.export`:
    - `SCREENACTIONS` `export,export-browser`, `SCREENVALUES` `export=root:path`, `BROWSERACTION`
    - `ArgumentPairs` through `ExplorerExport.FilePairs`, `FileProblem`/`AddFileArguments` through `TaskExport`
    - a mint resolving the file first (extend `ExplorerExportMint` where its body names no `AtelierPort` member, else a sibling with the reason)
    - not destructive; key `true`
  - `InteropLookupTableImport`, `interop.lookuptables.import`:
    - `SCREENACTIONS` `import,import-local`, `SCREENVALUES` `import=root:path,import-local=fileName:content`
    - the agent's schema names `Name`, `root` and `path` only
    - `READTYPE` `IMPORTTABLE`, `FINGERPRINTSUBJECT` `Namespace,root,path,fileName,Table,FileEntries,Digest,Present,Entries,Modified`
    - `DESTRUCTIVE`; `CLASSICPAGES` `EnsPortal.Dialog.Import`; key `false`
  - The target is the table the file names. The page reads it from the file's `<Document name="….LUT">`, and the port refuses a target the file does not hold.
- [ ] Client:
  - The tables list registers a screen-level Import and a row action Export. Both reuse the Explorer export and import dialogs, their Explorer wording made inputs.
  - Export to the browser saves `<Table>.xml` through `saveText`.
  - `strings.ts`, `EXPERIENCE.md` :173/:604 and the handler maps as in Part A.
- [ ] `Test/InteropLookupTransfer.cls` (new, armed as its siblings are):
  - export to a server file and to the browser
  - export, delete, import from the server file and from local text, restoring the same entries
  - keys the file lacks are removed
  - each `IMPORTSHAPE` case: two tables, a class document, the legacy form, zero entries
  - `IMPORTCHANGED` after the file changes
  - `TOOLARGE`
  - PathPort's pairs required only for a server file
  - the agent's mint and confirm for both tools
  - Plus `ui/browser/interop-lookup-transfer.browser-spec.mjs`: browser export, then local import.

**Acceptance Criteria:**

- **AC1 (lists, integration):** Given probe tables and entries in USER on `ocupilot-b-ci`, when Lookup tables and a table's entries render, then both read through `InteropPort`, and the screen read route and each read tool answer the same rows. A table's name opens its entries, and an entry whose key matches the credential pattern reads an empty value with `Secret` true.
- **AC2 (edit, both callers):** Given a table, when a person adds an entry, changes its value or removes it, or creates a new table with its first entry, and when the agent proposes each and the person confirms, then each is one operation through `InteropPort` under the vendor's table lock. Each answers a read-back, publishes a change event on which Lookup tables re-reads, and records a `ConfigChange` row with no value. Removing a table's last entry removes the table, as the card and the dialog say.
- **AC3 (delete):** Given a table, when a person deletes it, typing its name, or confirms the agent's proposal, then the table and every entry are gone. The key ships `false`, the card shows the entry count, and a table changed after the mint refuses the confirm.
- **AC4 (refusals):** Given each refusal row of the matrix, when either caller attempts it, then it is refused by its code before any vendor call and nothing is written.
- **AC5 (gates):** Given a principal missing one declared pair of a new screen or tool, or holding READ only on the globals database, when it reads or writes, then it is refused naming that pair before any vendor call. A principal holding exactly the pairs succeeds, because the vendor checks nothing (measured).
- **AC6 (business partners):** Given a probe partner, when Business partners renders, then it lists through `InteropPort` with both contacts. Its read tool answers the same rows, and it offers no save or remove (the stated partial).
- **AC7 (reads change nothing):** Given every new read, when it runs, then `^Ens.LookupTable` (timestamps included) and the partner globals are unchanged.
- **AC8 (export, Part B):** Given a table, when it is exported to the browser or to a server file, then the file is the vendor's export of that one `.LUT` document, and a server file is named by a root and a relative name (AD-21's sixth case). Export, then delete, then import restores the same entries.
- **AC9 (import, Part B):** Given an export file holding exactly one lookup table with entries, when it is imported from local text, from a server file, or by the agent's confirmed proposal, then that table is replaced or created with the file's entries. A file holding anything else is refused `IMPORTSHAPE` before any write, a file or table that changed since review is refused `IMPORTCHANGED`, and the key ships `false`.

## Spec Change Log

- 2026-10-11, spec gate (lead): rulings recorded under Design Notes › Gate rulings (Q1 asked, Q2 under DW-1166, Q3 (A), partners chartered as Story 20.26 / DW-2324); Part A spine drafts written.

## Review Triage Log

## Design Notes

**Governing ADs:** AD-62 (the port), AD-29 (its gate), AD-8 (pairs), AD-44 (classic pages), AD-13 (ids), AD-36 (reads), AD-24 and AD-60 (bounds, untrusted values), AD-35 (credential-named keys), AD-22 (keys), AD-6 (proposals), AD-51 (action-style remove and delete), AD-54 (the add creates), AD-53 and AD-55 (two callers, the Save route), AD-56 (declared screen values, an empty value), AD-58 (read-back), AD-59 (snippets), AD-10 (covered types, no self-protection target), AD-14 (change events), AD-15 (own audit row), AD-34 (per-target hold), AD-16 (namespace switch), AD-7 (reads write nothing; each write in its request), AD-5 and AD-3 (descriptor, field rows), AD-64 (the new screens are adjustable), AD-43 (none refreshes), AD-30 and AD-40 (the agent's switches gate only the agent's caller). Part B adds AD-21 (sixth-case consumers; local text as a screen value) and AD-39 (export lines as screen output). Checked and not engaged: AD-26 and AD-27 (no admin API call, no async path), AD-47 (an export is saved from text with no evaluation), AD-57 (no try-it console).

**Measured at this plan on `ocupilot-b-ci`.** In USER, two principals were created and deleted with every table, partner, class and file the probe made. `RW` held `%Ens_Portal:U` and `%DB_USER:RW`; `R` held `%Ens_Portal:U` and `%DB_USER:R`.

- `^Ens.LookupTable` and `^Ens.Config.BusinessPartnerD` map to each namespace's default globals database, both in USER and in HSCUSTOM.
- USER holds the vendor-seeded `%IRIS_X12ReplyType` (isSystemCreated 1), which `EnsLib.EDI.X12.Document` reads as an override.
- The vendor checks no privilege. `RW` ran `%UpdateValue`, `%RemoveValue`, `$System.OBJ.ExportToStream`, `LoadStream` (list and selected load), `LookupTableDocument.ImportStream`, `%Import` and the partner `List` query. `R`'s remove raised `<PROTECT>` (#5521 SQLCODE -415) and wrote Protect audit rows.
- The vendor audits nothing. Auditing is on, yet no row other than `%System/%Security/Protect` was recorded for any write.
- On entries:
  - The stamp is `$ZTS` (`67854,61054.850048679`) and moves on add and remove.
  - Removing a table's last entry removes the table (`$D` 0).
  - A missing key answers #5810, and `%UpdateValue(…,0)` on a missing key answers #5809.
  - An empty value is stored.
  - A key of 256 characters or a value of 32,001 is refused #7201. A 220-character table with a 255-character key is stored.
  - `%ExistsTable(…,1)` answers a case-variant match and an absent name.
- On export and import:
  - Export answers `<Export><Document name="T.LUT"><lookupTable><entry table key>…`, works for names with a space or a non-ASCII letter, and escapes `<`, `&` and quotes.
  - `LoadStream` with listonly lists a class and a `.LUT` side by side. A selected load of the `.LUT` alone loads no class, and it replaces the table: keys absent from the file are removed.
  - The legacy `<lookupTable>` file fails listing (#6301).
  - `%Import` of an empty `<lookupTable>` with a forced name removes the table.

**Decisions:**

- **A table is created with its first entry.** One create tool, one Save route and one dialog serve both New table and Add entry. An empty table has no effect at run time, because `Lookup()` answers its default either way. The classic page's New also writes nothing until Save. An empty-table create needs the vendor's `[Internal]` `updateTimestamp` (gate Q3).
- **The last entry's removal removes the table**, as the vendor's `%RemoveValue` does (measured). The consequence sentence says so. A kept empty table would also need `updateTimestamp`.
- **Per-entry writes, not a whole-table save.** Each proposal is one entry (AD-6). The vendor lock orders OcuPilot's write with a classic save: without it, a classic save already past its stamp check would remove a key OcuPilot had just added. The stamp moves on every write, so a classic editor that loaded before the write is refused its save with the vendor's "timestamp".
- **Secret keys.** The epic's standing secret-name rule applies to entry keys (AD-35). Export and import carry the file's text and show only counts. They never display or store a value, so they are not refused.
- **Pairs and roles.** These are read from the instance:
  - `%EnsRole_Operator` holds `%Ens_LookupTables:R` and `%Ens_ProductionConfig:R`, so it opens the three screens and their read tools.
  - `%EnsRole_Administrator` and `%EnsRole_WebDeveloper` hold `:W`, so they open the lookup writes too.
  - `%EnsRole_Monitor` holds neither, and `InteropFloor`'s rosters move to match.
  - The classic Import dialog's OR list (`%Ens_LookupTables:WRITE,%Ens_ViewFileSystem:USE`) cannot be a pair set. The import declares `%Ens_LookupTables:WRITE`, plus PathPort's pairs for a server file. A holder of only `%Ens_ViewFileSystem` is a narrower audience (AD-62 (7)'s named-limit family).
- **No new error code** in `Api/Error.cls`; all codes go in `InteropError` (#5290 headroom: 11).
- **DW-1882:** the new Save route takes the hold on the add's composite id, through `ItemSave`. **DW-2096** is not engaged, because there is no statement text.
- **Rule 31:**
  - `LookupEntrySave` extends `ItemSave`, and `InteropLookupEntryMint` extends `InteropItemMint`.
  - The tools extend `InteropAction`, copying their siblings' parameter shapes, which are declarations rather than code.
  - The export and import call `ExplorerExport.FilePairs` and `TaskExport.FileProblem`/`AddFileArguments`.
  - The Set dialog and the Explorer transfer dialogs are reused. `AuditRuntime` and `LocalStamp` are reused as they are.
  - `InvokeLookup` copies `InvokeItems`' dispatch shape for a new row family, as `InvokeRuntime` did (20.4).

**Split (`multiple-goals`; recommended).** Part A is the reads, the entry writes and the delete. Part B is import and export: two tools, PathPort, local text, file-shape rules and two dialogs, with `IMPORTTABLE`, `IMPORT`, `EXPORT`, AC8, AC9, `InteropLookupTransfer` and the transfer browser spec. The seam is clean: Part A ships no file path and no load. Recommendation: Part B becomes its own story, numbered by the lead, through an orchestrator ruling (Rule 5 ask-first, because it defers part of an AC), and this spec drops Part B's block. Without the split, this spec implements both, Part A first.

**Business partners' save and remove (the stated partial).** These need a new charter, which the lead numbers: "Business partners saved and removed". From this plan's reading:

- A create, an update and a delete would go through `InteropPort` on `Ens.Config.BusinessPartner` (`%New`/`%Save`, `%DeleteId`), with a form of the partner's 13 fields.
- **Posture question for that charter:**
  - The classic page has no `EDITRESOURCE`, so any `%Ens_ProductionConfig:READ` holder saves and removes there (inference from source; measure).
  - Recommendation: declare `%Ens_ProductionConfig:WRITE`.
- The vendor renames by deleting and then creating, with no transaction. A rename would be refused, or done in one transaction.
- A remove checks no item whose `BusinessPartner` setting names the partner. The port would read those items and refuse or warn.
- Nothing is audited, so OcuPilot records its own `ConfigChange`. `%Save` also stamps `^Ens.Configuration("sdd","Ens.Config.BusinessPartner","time")`.
- This is not carried here: it is three tools, a form and a posture question.

**Gate questions (for the orchestrator, each with a recommendation):**

- **Q1, split:** (A) split Part B as above, recommended; (B) one story.
- **Q2, bundle budget:** expected +25 to 35 kB for Part A and about +10 kB for Part B (inference: three mirrored descriptors, about 75 strings, two pages, two dialogs and a store). That is on 3,295,800 bytes (Story 20.23) against `maximumWarning` 3326 kB (3,326,000 bytes), so the build likely crosses. `angular.json` is a contended file and the edit is not add-only.
  - (A) Re-base `maximumWarning` (DW-1166) to 3376 kB in this story. Recommended.
  - (B) Accept the warning until the lazy-load story.
  - (C) The implement stage stops at the measured number.
  - Without a ruling, implement does not edit `angular.json`. It records the number in Auto Run Result and goes on.
- **Q3, empty tables:** (A) first-entry create, as planned, recommended; (B) also an empty-table create and a kept empty table, through the vendor's `[Internal]` `updateTimestamp`, as the classic page's save of no rows does (`LookupSettings.cls`:307-308).

**Gate rulings (lead, 2026-10-11):**

- Q1: asked of the orchestrator. Until it rules, this spec stays one story: Part A first, then Part B.
- Q2: the orchestrator's standing DW-1166 ruling applies. If the built initial total crosses `maximumWarning`, set it to 5% above the measured total, rounded up to the kB, in `angular.json` and in the pinned literal and its comment in `ui/tools/angular-json.test.mjs`, as Story 20.17's raise did. The commit message states the measured bytes and the reason. Stop and return blocked above 3800 kB.
- Q3: (A), first-entry create.
- Business partners' save and remove: chartered as Story 20.26 and ledgered as DW-2324 (`routed owner=20-26-business-partners-saved-and-removed`). The frontmatter `deferred:` item is that entry.
- Spine: the Part A drafts are written (AD-62 item 10, AD-13, AD-36, AD-15, AD-44, AD-8, AD-10). The Part B drafts (AD-62's import and export sentence, AD-21, AD-44's import page) wait for Q1.

**Spine drafts (Rule 20; the runner writes them at the spec gate):**

- **AD-62:** "Story 20.5:
  - `InteropPort` gains `LookupTables` (`LIST`, `LOOKUPTABLE`, `DELETETABLE`), `LookupEntries` (`LIST` with one `table` criterion, `LOOKUPENTRY`, `ADDENTRY`, `SETENTRY`, `REMOVEENTRY`) and `BusinessPartners` (`LIST`), calling `Ens.Util.LookupTable` under the vendor's own table lock (`^Ens.LookupTable(<table>)`, 3 s) as the classic page's save takes it.
  - The vendor's lookup and partner calls check no privilege and audit nothing (measured), so the pairs are the classic pages' (`%Ens_LookupTables:READ`/`WRITE`, `%Ens_ProductionConfig:READ`), and each write records OcuPilot's own `ConfigChange`.
  - A namespace under source control refuses every lookup write.
  - A table is created with its first entry, and removing its last entry removes it (measured).
  - Business-partner save and remove are a later story."

  Part B adds `IMPORTTABLE`, `IMPORT` and `EXPORT`: one `.LUT` document per file, through `$System.OBJ` export and a selected load.
- **AD-13:** `lookup-table` (the table's name), `lookup-entry` (`[Table, Key]`) and `business-partner` (the partner's name), each kept exactly.
- **AD-36:**
  - Lookup entries is a parent-scoped `interop` list (`table`).
  - An entry whose key matches the credential pattern is answered with an empty value and `Secret` true, which is Story 20.22's rule applied to keys.
- **AD-15:** "Named case 2026-10-11 (Story 20.5): lookup-table writes record OcuPilot's own `ConfigChange` from either caller."
- **AD-44:** the lookup screens and tools declare `EnsPortal.LookupSettings`, the partners screen `EnsPortal.BusinessPartners`, and the import (Part B) `EnsPortal.Dialog.Import`.
- **AD-8:**
  - `%EnsRole_Operator` opens Lookup tables, a table's entries and Business partners.
  - The lookup writes need `%Ens_LookupTables:WRITE`.
  - The import's OR-listed classic resource is a named narrower audience.
- **AD-21 (Part B):** the lookup export is an overwriting sixth-case file whose overwrite is a constant; the import is a `source`.
- **AD-10:** `lookup-table` and `lookup-entry` are covered, `ReviewedFewOnly`.

**Integration ACs, Consumes, Consumed-by:**

- Integration: AC1 to AC6 run against `ocupilot-b-ci` through the screen routes, the Save route, the agent's mint and confirm, and the browser spec.
- Consumes: 20.2 (the port, `PRODUCTIONPAIRS`), 20.3 (`ItemSave`, `InteropItemMint`, `InteropItemSeam`, the item gate helpers), 20.22 (the secret-name rule, the Set dialog), 20.23 (`AuditRuntime`), 19.13 (the transfer tools and dialogs, Part B) and 18.1 (PathPort, Part B).
- Consumed-by:
  - 20.12, whose guided workflows may propose entry changes (inference)
  - the business-partners charter above
  - 20.16, whose rule and DTL edits read lookup tables by name (inference)

**Ledger inbox (Rule 17):** empty.

**Contended files (Rule 11).** Epic 18 is ahead on `Prohibited.cls`, `screens.generated.ts`, `strings.ts`, `screen-action-handler.ts`, EXPERIENCE.md and `ci-throwaway.sh` (`origin/OCU-1-epic18`, 6 contended files since the merge base). None of its hunks is a line this story changes. This story's edits there append list entries, roster rows and the count pins that move with them, and the forward merge sums them (Rule 22). `Router.cls`, `EntityType.cls`, `Baseline.cls` and the roster tests receive additions only. In-place edits are Epic 20's own: the port, `InteropError`, `ItemSave`, `interop-item-add.store.ts`, `interop-item-setting-dialog.ts`, `InteropFloor` and `Navigation.cls`.

**Strings and weight.** About 75 literals (Part B about 20), taking the count from 3,144 to about 3,220, under the 3,350 point that triggers a raise of the 3,400 bound. Weight: gate Q2.

## Verification

**Shared surfaces:**

- the rail's Interoperability side bar, 7 to 9 listed, and the navigation count, 15 to 18
- entity types, 70 to 73 (`node tools/screen-mirror.mjs --check`)
- the interop `ENDPOINTS` literal and the read-tool roster (+3)
- `SurfaceCoverage`
- the governance baseline (+4 keys, 2 `false`; Part B +2, 1 `false`) and the disabled-key rosters (`GovernanceBaseline`, `Governance`, `ToolDispatch`, `ClassicPageGate`)
- `ToolRoundTrip`, `EndpointCoverage`, `SaveHoldCoverage` and `DraftRegistry`
- `Prohibited`'s covered types
- the `InteropFloor` role rosters
- `ItemSave`'s refactor, under Production items' Add
- the Fixed-strings row, the dialog list and the side-bar sentence
- the structural walk's `SKIP`
- the arming lines in `ci-throwaway.sh` and `ci.test.mjs`

*Existing tests that assert a surface this story changes are updated in this story, and every test the story adds or changes passes on a freshly built instance and in either order.*

**Setup (slot B):**

- `rsync -a --checksum --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-20/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`
- Then, in `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`, run `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)`.
- Before a browser run: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`.
- Never use the dev instance `ocupilot-slot-b`.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one class per call (`timeout: 600000`), each read from `%UnitTest_Result`:
  - new: `InteropLookupDescriptor`, `InteropLookupRead`, `InteropLookupControl`, `InteropLookupRefusals`, `InteropLookupGate`, and Part B's `InteropLookupTransfer`
  - changed or consuming: `InteropHostDescriptor`, `Descriptor`, `ReadTool`, `Navigation`, `SurfaceCoverage`, `InteropFloor`, `InteropFloorOwnPairs`, `GovernanceBaseline`, `Governance`, `ToolDispatch`, `ClassicPageGate`, `ToolRoundTrip`, `EndpointCoverage`, `SaveHoldCoverage`, `DraftRegistry`, `InteropItemControl`, `InteropItemRefusals`, and every other class the sweep changes
- `(loop)` `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/<file>`, one file per call: `interop-lookup-tables.browser-spec.mjs`, Part B's `interop-lookup-transfer.browser-spec.mjs`, `interop-items.browser-spec.mjs`, and `a11y-structural-invariants.browser-spec.mjs` (DW-1337, both themes).
- `(loop)` expected clean:
  - `cd ui && npm run test:tools && npm run test:components`
  - `uv run scripts/check-objectscript.py <changed .cls>`
  - `bash scripts/lint-docs.sh`
- Runner-owned, not the implement stage's:
  - the full ObjectScript sweep on `ocupilot-b-ci`, one class per call
  - `cd ui && npm test && npm run build`, with the bundle measured against gate Q2
  - `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`
  - Rule 30's fresh check
- `(CI)` the full browser suite.

**Planned pinning mutations (Rule 19):**

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | The entries read ignores the `table` criterion | `InteropLookupRead`'s entries leg |
| AC1 | The credential key answers its value | `InteropLookupRead`'s secret leg |
| AC1 | The entries list loses `parentScope` | `navigation.test.mjs`' name-cell leg |
| AC2 | The write skips the vendor lock | `InteropLookupRefusals`' `LOCKED` leg |
| AC2 | `AuditRuntime` not called | `InteropLookupControl`'s audit leg |
| AC2 | The tables list loses `secondaryEntityTypes` | the browser New-table leg, `navigation.test.mjs` |
| AC3 | `DELETETABLE` calls `%RemoveValue` on the first key only | `InteropLookupControl`'s delete leg |
| AC3 | `FINGERPRINTSUBJECT` without `Modified` | the target-changed leg |
| AC4 | `SAME` check dropped | `InteropLookupRefusals`' same-value leg |
| AC4 | `TABLECASE` check dropped | its leg |
| AC5 | `%Ens_LookupTables:WRITE` dropped from `LOOKUPWRITEPAIR` | `InteropLookupGate`'s write legs |
| AC6 | Partners answer no contact fields | `InteropLookupRead`'s partner leg |
| AC7 | `LOOKUPTABLE` removes and re-adds the table's first entry (`%RemoveValue`, then `%UpdateValue`) | `InteropLookupRead`'s snapshot leg (the stamp moves) |
| AC8 | Export writes the legacy `%Export` form | `InteropLookupTransfer`'s round-trip leg |
| AC9 | The listing check is skipped (the class document is loaded) | `InteropLookupTransfer`'s class-document leg |

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

**Plan summary.** The vendor was read and measured on `ocupilot-b-ci` (USER, two principals, every probe object removed). The vendor's lookup and partner calls check no privilege and audit nothing. Removing a table's last entry removes it. Export and selected load round-trip one `.LUT` document. The plan extends `InteropPort` with three lists and four lookup writes (Part A), plus import and export (Part B). Business partners are read-only, with a charter for their save and remove. Flagged `oversized` and `multiple-goals`. Three gate questions (split, bundle budget, empty tables) and the spine drafts are in Design Notes.
