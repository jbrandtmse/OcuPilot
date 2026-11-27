---
title: 'Story 24.18: PEX, record maps and HL7 authoring (Batch 1: HL7 schemas)'
type: 'feature'
created: '2026-11-26'
status: 'in-review'
baseline_revision: '18345f0a845916be3493e3ac31aa8891b1b481b3'
review_loop_iteration: 0
followup_review_recommended: false
owned_ledger: ''
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-20-5-lookup-tables-and-business-partners.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-17-managed-alerts-logs-the-system-monitor-and-workflow-3.md'
warnings: ['oversized', 'multiple-goals']
deferred: []
---

<intent-contract>

## Intent

**Problem:** OcuPilot shows HL7 schemas only through the vendor's read-only Schema viewer frame. Nobody can create, import, export or delete a custom HL7 schema from OcuPilot, the classic HL7 v2.x Schema Structures page's own actions (`EnsPortal.HL7.SchemaMain`, `EnsPortal.HL7.Dialog.CustomSchema`), and nothing round-trips over `EnsLib.HL7.Schema`. The story's other areas (HL7 schema elements, record maps, PEX) have nothing either.

**Approach:** Batch 1 of five (Design Notes, Batch split). **HL7 schemas** is a list through `InteropPort` with four writes, **New HL7 schema**, **Import**, **Export** and **Delete**. Each write is one operation that the screen and the agent both reach, and the import and export extend the lookup-table family (Story 20.5). "Round-trips" means three things:

- a schema created by either caller reads back from `EnsLib.HL7.Schema` and from the vendor's own `.HL7` document with its base and description;
- a custom schema that is exported, deleted and imported again reads back identical;
- a deleted schema is gone.

## Boundaries & Constraints

**Always:**

- **One port (AD-62).** `InteropPort` gains `Hl7Schemas` with these types:
  - `LIST`;
  - `HL7SCHEMA`, the one-schema fresh read. With `ACTIONKEY` it refuses whatever that write would be refused;
  - `HL7IMPORTFILE`, the import's read, as `IMPORTTABLE`;
  - the writes `ADDHL7SCHEMA`, `IMPORTHL7SCHEMA`, `EXPORTHL7SCHEMA` and `DELETEHL7SCHEMA`.

  Every type name is unique port-wide. The port switches namespace by save and restore and makes no `OcuPilot.*` call while switched, logging included; a fault is logged after the restore. It serves only a namespace where `%Library.InteroperabilityMgr.IsPackageInstalled("HL7")` answers 1, and answers `PORT.NOTIMPLEMENTED` anywhere else.
- **Rows.** The list comes from the vendor's `EnsLib.HL7.Schema:TypeCategories` query, standard schemas first, as the classic list shows them. Each row is `{Category, Base, Description, Standard, Modified, Namespace}`:
  - `Standard` is the vendor's `std` mark;
  - `Modified` is `EnsLib.HL7.SchemaDocument.TimeStamp("<category>.HL7")`.

  The list is capped by `HL7SCHEMASMAX` and reports truncation (AD-36). `HL7SCHEMA` answers the same fields.
- **Gate (AD-29, AD-8).** It runs before any vendor call and before any value is judged, and it is never cached.
  - **Reads:** `%Ens_Portal:USE` and `%Ens_EDISchema:READ`, the classic `RESOURCE` (`EDI/devTemplate.cls:10`, which `SchemaMain.cls:7` extends), then `Admit`.
  - **Add, import and delete:** the read pairs plus `%Ens_EDISchema:WRITE` (`EDITRESOURCE`, `devTemplate.cls:13`; the hyperevents `Import` and `DeleteCategory`, `SchemaMain.cls:1192-1195`; `CustomSchema.cls:14`) and WRITE on the namespace's globals database.
  - **A server file, for an import or an export:** also `PathPort`'s pairs (`%Admin_FileSystemAccess:USE`, `%DB_IRISSYS:READ`), exactly as `interop.lookuptables.import` and `.export` declare them for each of their actions.
  - Plus any pair Task 0 (b) measures.
- **Refusals by name.** Each runs after the gate and before any vendor call, in this order:
  - **Every write:** a namespace under source control, 409 `INTEROP.HL7.SOURCECONTROL` (`SourceControlled`).
  - **Add:**
    - a name that is not 1 to 64 characters of letters, digits, `.`, `_` and `-`, beginning with a letter or digit: 422 `INTEROP.HL7.NAME`;
    - a name the namespace holds in any letter case: 409 `INTEROP.HL7.TAKEN`;
    - a base that is neither empty nor a schema the namespace holds exactly: 422 `INTEROP.HL7.BASE`;
    - a description over 2,000 characters: 422 `INTEROP.HL7.DESCRIPTION`.
  - **Delete:**
    - a schema not held exactly: 404;
    - a standard schema: 409 `INTEROP.HL7.STANDARD`.
  - **Import:**
    - a file that is not exactly one `.HL7` document: 409 `INTEROP.HL7.IMPORTSHAPE`;
    - text over `AtelierPort.MAXIMPORTCHARACTERS`: 409 `INTEROP.HL7.TOOLARGE`;
    - a file whose schema the namespace holds as standard, or which the file marks standard (Task 0 (d)): 409 `INTEROP.HL7.IMPORTSTANDARD`;
    - a schema absent under exactly that name but held in another letter case: 409 `INTEROP.HL7.CASE`;
    - a file or schema that changed since the review: 409 `INTEROP.HL7.IMPORTCHANGED`.
  - **Export:**
    - a schema not held exactly: 404;
    - browser text over the same cap: 409 `INTEROP.HL7.TOOLARGE`;
    - a missing directory: `EXPLORER.EXPORT.DIRECTORY`.
  - **A held lock:** any write that takes the vendor's lock `^EnsHL7.Schema(<category>)` and cannot get it within `LOCKSECONDS` answers 409 `INTEROP.HL7.LOCKED`.
- **The writes**, in the proposal's namespace:
  - **Add.** It runs the classic `CustomSchema.OnWizardCompletion` body (`CustomSchema.cls:163-194`) under the vendor's lock: the base, the description and `time` set as that dialog sets them, then the vendor's own `Ens.Util.Auditing.AuditModifySchema("HL7 "_name, "Created schema based on "_base)`. No vendor method creates an empty schema, so this is a named limit, as the purge settings are.
  - **Delete.** It calls `EnsLib.HL7.SchemaDocument.Delete("<category>.HL7")` under the lock. That call holds the vendor's standard-schema guard and audit.
  - **Import.** It is `ImportText`, `ImportShape`, `ImportFile`, `ReadImportTable` and `PerformImport` extended, not copied. The vendor's `$System.OBJ.LoadStream` with the one `.HL7` document selected reaches `SchemaDocument.ImportStream`, which carries its own transaction and validation and replaces the schema whole.
  - **Export.** It is `ExportFile`, `CheckExport` and `ExportTable` extended: `$System.OBJ.Export` to an allowed-directory file, or `ExportToStream` to the browser, of `<category>.HL7`.
  - **A failure.** Each write is a single operation, as the purge is (Story 24.16): a vendor error status answers 500 `INTERNAL`, never 200, and its audit row reads `completed` false.
- **The tools (AD-3, AD-6, AD-10, AD-14, AD-22, AD-34, AD-51 to AD-55, AD-58, AD-59).** All four declare `WRITERESOURCE` `%Ens_EDISchema` and `CLASSICPAGES` `EnsPortal.HL7.SchemaMain`; the add also names `EnsPortal.HL7.Dialog.CustomSchema`.
  - `interop.hl7schemas.add` is a create (AD-54) that fingerprints the name's absence in any case.
    - Values: `Name`, `Base` (optional) and `Description` (optional).
    - Read-back compares `Base` and `Description` through `HL7SCHEMA`.
    - Key `true`.
    - The New dialog saves through `POST /interop/hl7-schemas` (AD-55, sibling `WorkflowRoleSave`).
  - `interop.hl7schemas.import` copies `InteropLookupTableImport`'s shape: actions `import` and `import-local`, `DESTRUCTIVE`. Key `false`.
  - `interop.hl7schemas.export` copies `InteropLookupTableExport`'s shape: actions `export` and `export-browser`. Key `true`.
  - `interop.hl7schemas.delete` is `DESTRUCTIVE` with a typed name.
    - `FINGERPRINTSUBJECT` is `Category,Base,Description,Standard,Modified,Namespace`, so any change to the schema after the review closes the proposal as moved.
    - Key `false`.

  Each tool is classified in `ConfirmNamespaceRoster` and `DraftRegistry`. Each script form shape-checks every value and renders no draft when one fails; otherwise it renders the switch, each refusal as a one-line guard, and the vendor call, and runs none of them. A screen action mints nothing and is not gated by read-only or the kill switch.
- **Namespace at confirm (AD-52).** Every stored proposal carries `Namespace`. Every confirm-time judgment runs there, whichever namespace the confirm is sent from: the fresh read, the source-control test, the taken test, the base, the standard mark, the file's digest and the vendor call.
- **Audit (AD-15).** The agent's write carries the agent's marker.
  - **Add and delete** keep the vendor's own `%Ensemble/%Schema/Modify` row (registered and enabled on `ocupilot-b-ci`, read at plan).
  - **Import and export**, which the vendor does not audit, record OcuPilot's own `ConfigChange` through `AuditRuntime` from either caller, after the restore. The row names the namespace, the schema, the destination or source kind and `completed`, and never the file's text or a description.
  - Task 0 (a) confirms each.
- **Bounds.** `HL7SCHEMASMAX` (provisional 1,000; Task 0 (e) sets it) is boundary-tested at the cap and one over through a seam. `LOCKSECONDS` is 3, the classic page's lock wait.
- **README.** Two `false` keys raise the switched-off count from one hundred and six to one hundred and eight. The off list gains this batch's clause (veto item 1) in the same commit, held by `interop.test.mjs`.
- **Rosters.** `interop-hl7-schema` goes after feature's last entries in `TYPES` and `COVEREDTYPES` (`ReviewedFewOnly`: OcuPilot owns no HL7 schema). Its `Prohibited.cls` terms are appended, and a pinning test shows that no earlier type reaches a different arm. Every pinned roster is in the Code Map.

**Never:**

- Writes outside the four named routes:
  - any element write (Batch 2);
  - `SchemaXML.Import` with a path a caller names;
  - a write to `^EnsPortal.Settings`;
  - the source-control hooks (the namespace is refused instead);
  - any `EnsPortal.*` call in product code;
  - a standard schema changed or deleted by any path.
- Logging a file's text, a description or a vendor status text (`LogFault` gets a fixed message and the codes).
- `Set $ROLES`, `AddRoles` or `New $ROLES` (a vendor call that changes `$ROLES` is a HALT).
- Batches 2 to 5's surfaces; the README's Interoperability paragraph (the story's last batch); a spine edit.
- `src/OcuPilot/Api/Error.cls` (frozen; codes go in `InteropError.cls`); `ui/angular.json`; `ui/vitest-base.config.mjs`.
- Contended files beyond add-only edits:
  - `scripts/ci-throwaway.sh` beyond add-only `# classes:` lines, and never its bring-up retry block;
  - `Prohibited.cls` beyond appended terms and new arms;
  - `shell/screen-action-handler.ts`, `shell/warning-dialog.ts` and `shell/screen-action-dialogs.ts` beyond add-only map entries.

## I/O & Edge-Case Matrix

Route namespace USER. The probes are custom schemas `OcuProbe2418*`, made by the fixture with the classic dialog's sets in both namespaces. USER and HSCUSTOM each hold the 14 standard schemas and no custom one (read at plan).

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| List | Two probes, one based on 2.5 | All 16 listed, standard first; `Base`, `Standard` as held | - |
| Add, both callers | A free name, base 2.5.1 and a description from the screen; no base from the agent | Each reads back as sent from the list and the `.HL7` export; one vendor `Modify` row each | - |
| Round trip | Export a probe to the browser, delete it, import the text locally | Reads back identical (the export again equals the first) | - |
| Server file | Export to an allowed directory; import that file from the agent | Same round trip; one `ConfigChange` each, no text in it | - |
| Delete, both callers | A probe; then 2.5 | Probe gone; card destructive; 2.5 untouched | 409 `.STANDARD` |
| Add values | `a b`, `-x`, 65 characters, `ocuprobe2418a` while `OcuProbe2418a` is held, base `nope`, a 2,001-character description | Refused; nothing written | 422 `.NAME` / `.BASE` / `.DESCRIPTION`; 409 `.TAKEN` |
| Import shapes | A file with a class; with two schemas; 3,000,001 characters; an exported 2.5 | Refused; nothing loaded | 409 `.IMPORTSHAPE` / `.TOOLARGE` / `.IMPORTSTANDARD` |
| Import case | A file holding `OCUPROBE2418A` while `OcuProbe2418a` is held | Refused | 409 `.CASE` |
| Changed | A probe changed after the agent's import or delete was minted | Confirm refused, nothing written | `PROPOSAL.TARGETCHANGED` / 409 `.IMPORTCHANGED` |
| Source control | The seam reads the namespace as source-controlled | Every write refused, through the mint, the Save route and the screen action | 409 `.SOURCECONTROL` |
| Locked | The seam's lock answers 0 | Nothing written | 409 `.LOCKED` |
| Gate | No `%Ens_EDISchema:READ`; no `:WRITE` (add, import, delete); no database WRITE; no `%Admin_FileSystemAccess:USE` for a server file | Refused before any vendor call | 403 naming the pair |
| Vendor error | The seam answers an error status | Never 200; audit `completed` false; no vendor text logged | 500 `INTERNAL` |
| Confirm elsewhere | Add, import and delete minted in USER, confirmed with `?ns=HSCUSTOM`, HSCUSTOM holding a same-named probe | Each acts in USER only; the add is not refused `.TAKEN`; HSCUSTOM's probe unchanged | - |
| Cap | Seam cap at the count held plus one: one probe, then two | Listed; then listed at the cap with truncation | - |
| Script | Each draft; a bad name, base or file name | Renders the switch, guards and vendor call, runs nothing; a bad value renders no draft | - |

</intent-contract>

## Code Map

Paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-24` (HEAD `7da116ffbfcc44aa3ba0ec274c3c22dadcc459dc`). At plan, `origin/OCU-1-epic21` is not ahead of feature, so Epic 21 marks no file. Re-check before editing, and keep every roster add-only.

- **`Port/InteropPort.cls`** (16,405 lines). The sibling is the lookup-table family; extend it (Rule 31).
  - Lookup pieces: `LOOKUPPAIRS`/`LOOKUPWRITEPAIR` :271/:274, `IsLookupWrite` :7342, `LockTable` :7350, `ImportText` :7868 (generalize its too-large code by an argument), `ImportShape` :7908 (generalize its `LUTEXTENSION` suffix and entry count by an argument), `ImportFile` :7962, `ReadImportTable` :7981, `PerformImport` :8020, `ExportFile` :8093, `CheckExport` :8112, `ExportTable` :8139, `LookupSnippet` :14103.
  - Port-wide entry points: `ENDPOINTS` :128, `IsAnyWrite` :1223, `Pairs` :1253, `Serves` :1352, `Invoke` :1481, `Admit` :1652, `SourceControlled` :1984, `LogFault` :3860, `Refuse` :3874, `AuditRuntime` :7034, `SnippetForm` :7046, `Snippet` :7086.
  - The workflow role create shape: `PerformWorkflowRole` :11190.
- **Vendor (read-only, read at plan).**
  - `irislib/EnsPortal/HL7/SchemaMain.cls`: list :260-274, `DeleteCategory` :712-740, `CanDeleteCategory` :879-882, `Import` :894-914, `ExportCategory` :916-921, `GetHyperEventResources` :1188-1196.
  - `irislib/EnsPortal/HL7/Dialog/CustomSchema.cls`: fields :43-52, client rules :69-140, `OnWizardCompletion` :163-194.
  - `irislib/EnsLib/HL7/SchemaDocument.cls`: `ImportStream` :37-64, `Delete` :67-77, `TimeStamp` :82, `Exists` :97.
  - `irislib/EnsLib/HL7/Schema.cls`: `TypeCategories` :139-162.
  - `irislib/EnsLib/HL7/SchemaXML.cls`: `endDocument` merge and lock :876-919.
  - `irislib/Ens/Util/Auditing.cls`: `AuditModifySchema` :271.
  - `irislib/%Library/EnsembleMgr.cls`: event `%Ensemble/%Schema/Modify` :4067.
  - Measured at plan on `ocupilot-b-ci`, read-only:
    - `^EnsHL7.Schema`, `^EnsHL7.Description` and `^EnsHL7.Annotation` map to each namespace's own database;
    - neither namespace is source-controlled;
    - the audit event exists and is enabled, with auditing on.
- **`Api/InteropError.cls`.**
  - Codes `HL7SOURCECONTROL`, `HL7NAME`, `HL7TAKEN`, `HL7BASE`, `HL7DESCRIPTION`, `HL7STANDARD`, `HL7IMPORTSHAPE`, `HL7IMPORTSTANDARD`, `HL7IMPORTCHANGED`, `HL7CASE`, `HL7TOOLARGE` and `HL7LOCKED`, beside the workflow block (:611-631).
  - Consequences `HL7DELETE` and `HL7IMPORT`.
  - `Hl7Codes` and `Hl7PreconditionCodes` beside `WorkflowCodes` :1099, joined into `Codes` :972 and `ConsequenceCodes` :978, with `ReasonFor` arms :1242.
- **Tools (new, `Screen/Tool/`).**
  - `InteropHl7SchemaAction` (abstract): `DESCRIPTORCLASS`, `READTYPE` `HL7SCHEMA`, `READANSWERS`, `Endpoint`, `TargetName`.
  - `InteropHl7SchemaAdd`: as `InteropWorkflowRoleAdd` (`CREATES`, `SENDSBODY`, `ComposeCreate` adding `Namespace`, `CreatedId`, `READASKSACTION`, `READBACKFIELDS` `Base,Description`).
  - `InteropHl7SchemaImport`: as `InteropLookupTableImport`, with `REVIEWED` `Digest`, `Present` and `Modified`.
  - `InteropHl7SchemaExport`: as `InteropLookupTableExport`, with `BROWSERACTION` `export-browser`.
  - `InteropHl7SchemaDelete`: as `InteropLookupTableDelete`, with `REMOVALROWS` `Category,Base,Description`.
- **Save route (new).** `Area/Interop/Hl7SchemaSave.cls` extends `ItemSave` as `WorkflowRoleSave.cls` does. `Api/Router.cls` gains a `Route` beside :304 and its `Call=` target beside :2155.
- **Descriptor (new).** `Screen/Descriptor/InteropHl7SchemaList.cls`, modeled on `InteropLookupTableList.cls`:
  - route `interoperability/hl7-schemas`, side bar 30 (after the System monitor's 29), `list`, scope `namespace`;
  - entity `interop-hl7-schema`, id `single` on `Category`, sort as read;
  - primary `add`, page action `import`, row actions `export`, `delete`;
  - `privileges` `%Ens_Portal:USE`, `%Ens_EDISchema:READ`; `ownPrivileges` `%Ens_EDISchema:READ`;
  - `classicPage` `EnsPortal.HL7.SchemaMain` (also the Schema viewer's; several screens already share one);
  - `toolIdentifier` `interop.hl7schemas`.

  Columns reuse `tableColumnName` (Category), `tableColumnDescription` and `analyticsColumnModified`.
- **Kernel.**
  - `Kernel/EntityType.cls`: `interop-hl7-schema` after `interop-workflow-task` in `TYPES` :195, with its doc beside :134.
  - `Kernel/Governance/Baseline.cls`: four keys, in name order.
  - `Kernel/Proposal/Prohibited.cls`, append-only:
    - `TYPEINTEROPHL7SCHEMA` after :943;
    - `COVEREDTYPES` :352, last;
    - the uncovered chain extended at its end;
    - `PermittedCreateFields` (`Name`, `Base`, `Description`) and a create branch, as the workflow role's;
    - a `ReviewedFewOnly` arm after the workflow task's.
- **Client (`ui/src/app/`).**
  - New files under `areas/interoperability/`, with specs: `interop-hl7-schema-list.page.ts` (sibling `interop-lookup-table-list.page.ts`) and `interop-hl7-schema-dialog.ts` (sibling `interop-workflow-role-dialog.ts`; extend, or record why a copy reads better). The import and export dialogs reuse the lookup transfer components (`interop-lookup-table-transfer`) by parameter, not by copy.
  - `shell/screen-outlet.ts` beside :287.
  - `shell/screen-action-handler.ts`, add-only:
    - the typed-name list beside :143;
    - page actions beside :724 (`export`, `export-browser`, `import`, `import-local`);
    - consequences beside :975;
    - the typed field beside :1110.
  - `core/screen-actions.ts` beside :343; `core/proposal-view.ts` beside the lookup entries; `core/strings.ts` after :10135.
  - Regenerate `screens.generated.ts` and `Screen/Titles.cls` with `ui/tools/screen-mirror.mjs`.
- **Tests (new).** The principal legs are armed by `OCUPILOT_ALLOW_PRINCIPALS`, with one add-only `# classes:` line in `scripts/ci-throwaway.sh`. Each class stays under 500 lines.
  - Case `Test/InteropHl7Case.cls`. It refuses to start while either namespace holds a custom schema that is not its probe, and drops probes and principals in both namespaces before and after every test.
  - Fixture `Test/InteropHl7Fixture.cls`: `Probe` with the classic sets, `DropProbes` by marker in both namespaces, and principals as `InteropAlertFixture`.
  - Seam `Test/InteropHl7Seam.cls` extends `InteropPort`: the cap, the vendor status, a throw, `SourceControlled` answered true, the lock answered 0, and an `Hl7Here` hook inside each switched block.
  - Classes:
    - `InteropHl7SchemaList`: list, cap, readers;
    - `InteropHl7SchemaControl`: add and delete from both callers, read-back, audit rows, drafts;
    - `InteropHl7SchemaTransfer`: both round trips, local and server file;
    - `InteropHl7SchemaRefusals`: values, shapes, case, changed, source control through all three routes, locked, vendor error, nothing logged while switched, no text logged;
    - `InteropHl7SchemaGate`: principals;
    - `InteropHl7SchemaElsewhere`.
  - Browser `ui/browser/interop-hl7-schemas.browser-spec.mjs`, siblings `interop-lookup-tables` and `interop-lookup-transfer`.
- **Rosters (Rule 30).** Re-grep `interop.lookuptables`, `InteropLookupTable`, `interop.workflowroles`, `interop-workflow-task` and `SystemMonitor` across `src/OcuPilot/Test`, `ui/tools`, `ui/browser`, `ui/src` and `scripts/`. The rosters are:
  - `ConfirmNamespaceRoster` `CHECKEDFLOOR` :34 (163; set it to the count the walk asks);
  - `DraftRegistry` `ARGUMENTVALUES` :71 and `TYPEDTARGETIDS` :60;
  - `EndpointCoverage`; `SaveHoldCoverage`; `ToolWrite`; `Descriptor`; `SurfaceCoverage`; `StageTwoTools`; `InteropFloor`;
  - `GovernanceBaseline` (`DISABLED`); `Governance`; `Prohibited`; `ReadTool`; `ReadDescriptions`; `ToolRoundTrip`; `ToolEmit`;
  - `ClassicPageGate`; `MappingDescriptor`; `CompositeMintSweep`; `DryRunRoute`; `InteropDescriptor`; `Navigation`; `InteropHostDescriptor` (`ENDPOINTS`);
  - `ui/tools/interop.test.mjs` (sentence rows; the count, :409, and an off-list assertion beside :411); `screen-mirror.test.mjs`; `navigation.test.mjs`; `ci.test.mjs`.

  After any union with feature or Epic 21, check the entity-type order against every pinned assertion.
- **`README.md`** :164 (the count) and :184 (the off list). **EXPERIENCE.md**: one Fixed strings row after the workflow tasks row, once the strings are ruled.

## Tasks & Acceptance

**Execution:**

- [ ] **Task 0.** Run it on `ocupilot-b-ci` only, in USER and HSCUSTOM, with auditing on. Remove every probe schema, file, user and role afterwards; never write a standard schema. Record the results under Design Notes, Measured.
  - (a) Each of the four writes on a probe writes only the namespace's own database (journal read by process id; name the globals). Read the vendor audit rows, with a positive control: `Modify` for add and delete, and what import and export write. `$ROLES`, `$USERNAME` and `$NAMESPACE` read the same before and after, for a principal without `%All` and for `_SYSTEM`. The list read writes nothing.
  - (b) A principal holding `%Ens_Portal:U`, `%Ens_EDISchema:R` and `%DB_USER:R` reads the list, `HL7SCHEMA` and a browser export. With `%Ens_EDISchema:W` and `%DB_USER:RW`, each write succeeds. Record what the vendor answers with `%DB_USER:R`, and whether `$System.OBJ.LoadStream` or `ExportToStream` of a `.HL7` document asks any other pair, such as `%Development:USE`. Name any further pair.
  - (c) A schema made by the classic sets, with a base and with none, is listed by `TypeCategories` with its base and description, and `ExportToStream("<name>.HL7")` exports it.
  - (d) The import:
    - `LoadStream` list-only lists exactly `<name>.HL7` for an exported probe; record what it lists for a raw `<Category>` file, a file with a class, and a file with two schemas;
    - a selected load replaces a probe whole, so an element the file lacks is gone;
    - read how an exported standard schema (2.5, export only) marks itself, and whether loading that text renamed to a probe name sets the probe's `std` mark;
    - the export, delete and import round trip reads back identical.
  - (e) `TypeCategories`' time with 1,000 and 2,000 probes. The cap is the larger whose read ends within 5 s here (7.5 s on CI at 1.5 times), and never above 2,000.
  - (f) A lock held on `^EnsHL7.Schema(<probe>)` by another process makes each write wait and refuse, and the vendor import takes that lock.
  - **HALT `blocked`** in any of these cases:
    - a read writes data;
    - a vendor call leaves `$ROLES`, `$USERNAME` or `$NAMESPACE` changed (AD-9);
    - a write reaches outside the namespace's database, other than the audit row;
    - (b) needs a pair that escalates (`## Clarification Needed`: security posture);
    - (d) finds an import can mark a schema standard in a way the port cannot detect before the load (`intent gap`);
    - the add's vendor `Modify` row is absent (`intent gap: audit`);
    - 1,000 does not fit (e).
- [ ] `src/OcuPilot/Port/InteropPort.cls`, `src/OcuPilot/Api/InteropError.cls`: the endpoint, the gate, the list, the reads, the four writes, the snippets and the codes. One port, with the lookup family extended.
- [ ] `src/OcuPilot/Screen/Tool/InteropHl7Schema*.cls`, `Area/Interop/Hl7SchemaSave.cls`, `Api/Router.cls`, the descriptor, `EntityType.cls`, `Baseline.cls` and `Prohibited.cls`: the tools, the Save route, the screen, the type, the keys and the terms.
- [ ] `ui/src/app/areas/interoperability/interop-hl7-schema-*` (page, dialog and specs), with the add-only maps, the strings and the outlet registration. Regenerate the mirror and titles. Add the EXPERIENCE.md row, and the `README.md` count and off-list clause with `ui/tools/interop.test.mjs`'s assertion.
- [ ] `src/OcuPilot/Test/InteropHl7*.cls`, `ui/browser/interop-hl7-schemas.browser-spec.mjs`, the `# classes:` line, and the rosters the sweep names: the matrix, in either order.

**Acceptance Criteria:**

- **AC1 (list).** Given USER's probes, when a person opens HL7 schemas and the agent reads it, then each lists every standard schema and exactly the probes, with base, description, standard mark and modified time.
- **AC2 (add, both callers).** Given free names, when a person's New HL7 schema and the agent's confirmed add each run, then:
  - each schema reads back from the list and from its `.HL7` export with the base and description sent;
  - each write leaves one vendor `Modify` row.
- **AC3 (round trip).** Given a probe, when it is exported (browser, then a server file), deleted and imported (local file, then the agent's server file), then:
  - it reads back identical each time;
  - each import and export leaves one `ConfigChange` holding no text.
- **AC4 (delete).** Given a probe and a standard schema, when either caller deletes each, then the probe is gone, and the standard schema is refused and untouched.
- **AC5 (refusals and gate).** Given each refusal row of the matrix, when either caller writes, then:
  - the named code answers before any vendor call;
  - nothing is written;
  - no log line carries a file's text, a description or a vendor text.
- **AC6 (vendor error).** Given the seam's error status, when either caller writes, then the answer is 500 `INTERNAL`, never 200, and the audit row reads `completed` false.
- **AC7 (the proposal's namespace; Integration, Rule 1).** Given a same-named probe in USER and HSCUSTOM, when each agent write is minted in USER and confirmed from HSCUSTOM, then it acts in USER only and HSCUSTOM's probe is unchanged.
- **AC8 (rosters, script, switched).** Given the four tools, when `ConfirmNamespaceRoster`, `DraftRegistry` and `Prohibited` run, then:
  - each is green with its rows, and red with one removed;
  - each draft renders, and renders nothing for a bad value;
  - nothing is logged while switched.
- **AC9 (README).** Given the two `false` keys, when `interop.test.mjs` runs, then the README's count and off-list clause hold, and the test is red with the count one less.
- **AC10 (browser).** Given a fresh instance, when a person creates a schema based on 2.5.1, exports it to this browser, deletes it (typing its name) and imports the saved file, then the list shows each change.
- **AC11 (fresh, either order).** Given any new or changed test, run first on a fresh instance in either order, when it ends, then no probe schema, file or principal remains in either namespace.

## Spec Change Log

## Review Triage Log

### 2026-11-26 — Review pass (implement stage)

- verdicts: 11 findings — high 0, medium 5, low 6, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` a server-file export's `ConfigChange` row asserted nowhere — added to `InteropHl7SchemaTransfer`; mutation recorded.
  - `[medium]` `[patch]` a schema changed between an agent delete's mint and confirm never exercised — `TestADeleteMintedBeforeTheSchemaChangedIsClosedAsMoved` added to `InteropHl7SchemaControl`.
  - `[low]` `[patch]` the delete script's standard guard is pinned by rendered text only (the vendor refuses in the run) — the test header no longer claims a red.
  - `[medium]` `[patch]` the export and the later switched blocks missing from the vendor-error and nothing-logged tests — export legs and `TestAFaultInAnyLaterSwitchedBlockIsLoggedOnceInTheCallersNamespace` added to `InteropHl7SchemaRefusals`.
  - `[medium]` `[patch]` the vendor lock's release asserted nowhere — the seam counts each lock and release, and the refusals test asserts they match.
  - `[medium]` `[defer]` no principal runs a real import write or a server-file action without `%Admin_FileSystemAccess:USE` — the pairs are PathPort's and the lookup gate pins that path; a one-schema file for the `All` principal is a cheap later addition.
  - `[low]` `[reject]` `AuditModifySchema`'s status is unread in `Hl7VendorWrite` — the classic dialog ignores it too, and the write has already happened.
  - `[low]` `[reject]` `VendorRows` reads a one-second window — the probe names are unique per test and the count loops until the expected number.
  - `[low]` `[reject]` import and export are `rowActions` while the spec's Code Map says page action — the lookup-table descriptor, the sibling, declares them the same way.
  - `[low]` `[reject]` the intent text says the vendor does not audit an import, which Task 0 measured wrong — recorded under Measured; the intent block is read-only and the AD-15 amendment line is the lead's.
  - `[low]` `[reject]` `Hl7Facts` fault after a successful add answers 200 with a logged line — the write already happened and the answer's re-read is best effort; recorded under Decided in-stage.

## Veto items

Each is the lead's to take to the veto gate; the recommended option is first.

1. **New user-facing strings.** These are reused, and each reads true here:
   - "Name" (`tableColumnName`), "Description" (`tableColumnDescription`), "Modified" (`analyticsColumnModified`), "Yes"/"No";
   - "Import" (`actionImport`), "Export" (`taskExportAction`), "Delete" (`actionDelete`), "Save", "Cancel";
   - "A file on the server" · "This browser" · "A file on this computer" · "There is no such directory under that allowed directory." (EXPERIENCE.md:591);
   - "A file already at this name is replaced." (:319);
   - "A description is at most 2,000 characters." (Story 24.17 Batch 3b).

   New:
   - Labels and titles: "HL7 schemas" · "New HL7 schema" · "Base schema" · "Standard" · "Import an HL7 schema" · "Export HL7 schema <schema>" · "Delete HL7 schema <schema>".
   - Help line: "A custom HL7 schema adds its own message types, structures and code tables to the schema it is based on."
   - Consequences:
     - `HL7DELETE`: "Deleting this HL7 schema removes everything it defines. Schemas based on it, and items and rules that name it, can no longer find it. It cannot be restored from OcuPilot."
     - `HL7IMPORT`: "Importing replaces this namespace's HL7 schema of the same name with the file's, and anything the file does not define is removed."
   - Done lines: "Exported HL7 schema <schema> to <path>." · "Saved HL7 schema <schema> as <file>." · "Imported the HL7 schema in <file>."
   - Refusals:
     - `SOURCECONTROL` "This namespace uses source control, so change HL7 schemas in the classic HL7 Schema Structures page."
     - `NAME` "An HL7 schema name is 1 to 64 letters, digits, periods, underscores and hyphens, and begins with a letter or digit."
     - `TAKEN` "This namespace already has an HL7 schema with that name, in some letter case."
     - `BASE` "Choose a base schema this namespace holds, or none."
     - `STANDARD` "This is a standard HL7 schema, which the instance provides, so it cannot be changed or deleted."
     - `IMPORTSHAPE` "An import file must hold exactly one HL7 schema and nothing else, in the form the Export action writes."
     - `IMPORTSTANDARD` "This file holds a standard HL7 schema, which the instance provides, so it is not imported."
     - `IMPORTCHANGED` "The file or the schema changed after the import was reviewed, so nothing was imported. Review the import again."
     - `CASE` "An HL7 schema whose name differs from this one only in letter case already exists. Use its spelling, or choose another name."
     - `TOOLARGE` "An HL7 schema file holds at most 3,000,000 characters, and this one holds more."
     - `LOCKED` "Someone else is changing this HL7 schema right now, so nothing was written. Try again in a moment."
   - Empty state: "This namespace has no HL7 schemas." Agent phrase: "create a custom HL7 schema".
   - Prompts: "Which HL7 schemas here are custom, and what is each based on?" · "Which custom HL7 schema changed most recently?" · "Create a custom HL7 schema based on 2.5.1."
   - README off-list clause, after "deleting or importing a lookup table,": "importing or deleting a custom HL7 schema,". The count becomes "One hundred and eight".
2. **Security posture: files.**
   - The classic Export writes any server path with `%Ens_EDISchema:READ` alone (`SchemaMain.cls:916-921`, no other check).
   - The classic Import reads any server path behind `%Ens_EDISchema:WRITE`, with `%Ens_ViewFileSystem:USE` checked only in the client (`SchemaMain.cls:18`, `:435`).
   - Here a server file is an allowed directory behind `PathPort`'s pairs (`%Admin_FileSystemAccess:USE`, `%DB_IRISSYS:READ`), as the lookup tables' import and export already are (AD-21's sixth case). That is stricter than the classic page.
   - Alternative: none, since AD-21 forbids a free path.
3. **Security posture: the rest.** The other pairs equal the classic page's: `%Ens_EDISchema:READ` for reads, `:WRITE` for add, import and delete, plus the portal's `%Ens_Portal:USE` and the database pair (`Template/standardPage.cls:441-448`). The database WRITE pair is the classic posture made explicit (inference until Task 0 (b)).
4. **Values narrower than the classic page.**
   - A name of at most 64 characters from a fixed set, refused when held in any letter case. The classic client rule also lets `!`, `-` and other characters through, and checks only an exact match.
   - A base that must be held exactly, or none.
   - An import may never replace or create a standard schema; the classic Import has no such guard (`SchemaXML.cls:876-919`).
   - A raw `<Category>` file is refused if Task 0 (d) shows the vendor's lister does not take it. The classic Import reads one.

   Alternative: the classic page's rules.
5. **Governance keys and confirms.**
   - `interop.hl7schemas.add` and `.export` ship `true`.
   - `.import` and `.delete` ship `false`. Both are destructive and cannot be undone from OcuPilot.
   - Delete asks for the typed name and states `HL7DELETE`; the import dialog and card state `HL7IMPORT`.

   Alternative: `.import` `true`.
6. **AD amendments.** These are written at story end by the lead, add-only, as `[AMENDED <date>, Story 24.18, Rule 20]`.
   - AD-62, the next item: "**HL7 schemas** (Story 24.18). `InteropPort` gains `Hl7Schemas` over the namespace's HL7 schemas (`EnsLib.HL7.Schema:TypeCategories`), behind `%Ens_Portal:USE` and `%Ens_EDISchema:READ`, the classic page's `RESOURCE`, and four writes behind `%Ens_EDISchema:WRITE` and WRITE on the namespace's globals database. A create sets the vendor's schema globals as the classic New dialog does (a named limit: no vendor method creates an empty schema). A delete calls `EnsLib.HL7.SchemaDocument.Delete`. An import and an export move one `.HL7` document through `$System.OBJ`, as the lookup tables' do (item 10). A standard schema is never deleted or replaced, a name held in any letter case is refused, and a namespace under source control refuses every write."
   - AD-22: "**Story 24.18's Batch 1 keys:** `interop.hl7schemas.import` and `interop.hl7schemas.delete` ship `false`; `interop.hl7schemas.add` and `interop.hl7schemas.export` ship `true`."
   - AD-15, named case: "**An HL7 schema import or export** (Story 24.18), which the vendor does not audit, records OcuPilot's own `ConfigChange` from either caller, never the file's text; a create and a delete keep the vendor's own `%Ensemble/%Schema/Modify` row."
   - AD-21, sixth case: "**Story 24.18's consumers of the sixth case:** the HL7 schema export is an overwriting `file` consumer whose overwrite is a constant, and its import a `source`; a local file's text is a screen action value."

There is no new dependency, no privilege, role or access grant, and nothing is written into another namespace.

**Lead rulings at the spec gate (2026-11-26; filed as an INBOX veto item, binding unless the orchestrator reverses them).** Every veto item is kept as recommended:

- **V1:** kept, every quoted string. If Task 0 measures a consequence sentence untrue, HALT with `## Clarification Needed`; never reword it in-stage. The README count is derived from the Baseline on the tree you commit, never typed from this plan.
- **V2:** kept: server files only through an allowed directory behind `PathPort`'s pairs (AD-21's sixth case), stricter than the classic page.
- **V3:** kept, the classic page's pairs made explicit with the namespace database pair.
- **V4:** kept, the narrower values (the name set, the exact base, no standard schema replaced or created, the raw-`<Category>` refusal if Task 0 (d) requires it).
- **V5:** kept: `.add` and `.export` ship `true`; `.import` and `.delete` ship `false`, destructive, the delete asking for the typed name.
- **V6:** kept for story end; the lead writes the lines.

## Design Notes

**Batch split.** Each batch has its own spec, `-2` onward, and its own commit series. They are ordered by size, the smallest complete area first.

1. **HL7 schemas** (this spec). It covers the classic HL7 v2.x Schema Structures page's own actions; the vendor's Schema viewer stays the browser.
2. **HL7 schema elements.** A custom schema's message types, message structures, segment structures, data structures and code tables.
   - Each is listed, with add, edit and delete through the classic dialogs' bodies (`CustomMessageType`, `SchemaDocumentStructure.PutNewMessageOnServer`, `CustomSegmentStructure`, `CustomDataStructure`, `CustomCodeTable`), each in its own transaction with `addDefaultCategories` and `BuildCategoryMaps`, and a rollback on every failure.
   - A standard schema is read-only.
   - The pairs are this batch's.
   - Its plan may split code tables and message types from the three structure editors, whose delimited formats are larger.
3. **Record maps.**
   - The list (`EnsLib.RecordMap.RecordMap:List`).
   - The map editor over `EnsLib.RecordMap.Model.Record` (`LoadFromClass`/`SaveToClass`, with the editor's stale-`Timestamp` check).
   - Generate (`EnsLib.RecordMap.Generator.GenerateObject`, which compiles), with Story 24.11's class-write helpers lifted beside `Kernel/SourceDocument` rather than copied.
   - Delete (`DeleteRecordMap` with its two options) and the simple batch class.
   - The pairs: the classic pages' `RESOURCE` is the OR list `%Ens_Code:READ,%Ens_RecordMap:READ` (`RecordMaps.cls:15`; the Zen controller passes on the first held, `%ZEN/Controller.cls:34-52`). No shipped role holds `%Ens_RecordMap` (read at plan), so the batch declares `%Ens_Code`, a narrower audience as AD-62 item 7 accepts, plus WRITE on the routines database for a write. That is a veto item at its gate.
4. **Complex record maps, the CSV wizard and record map transfer.**
   - `EnsLib.RecordMap.Model.ComplexBatch` and `ComplexGenerator.Generate` (which writes `^oddDEF` directly; its Task 0 measures it).
   - The CSV wizard's sample is local file text or an allowed-directory source (AD-21).
   - Record map import and export are `.cls` documents.
5. **PEX.**
   - The list (`EnsLib.PEX.Utils:EnumeratePEXComponents`), and remove (`DeleteComponentProxy`, dictionary only).
   - Register and update (`RegisterComponent`, which calls an external language server). Bounce is never offered, because `%SYS.Ensemble.BounceExternalLanguageServer` adds `%Manager` to `$ROLES` (`Ensemble.cls:588-593`).
   - The classpaths are server paths outside AD-21's sixth case, so its plan brings an AD-21 amendment or a narrower register to the veto gate.
   - At plan, `ocupilot-b-ci` has Java and `javac`, and no `iris.pex` Python package was found.
   - The pairs: `%Ens_Code:WRITE` (`PEXComponents.cls:24`, no `EDITRESOURCE`) and WRITE on the routines database.

   The README's Interoperability paragraph comes with it.

**Decided in-stage (plan).**

1. Epic context recompiled, because the planning files were newer. It is left uncommitted for the lead, since this dispatch commits the spec alone.
2. HL7 schemas come first, not record maps (the prompt's example order). It is the smallest area complete on its own: one page with four writes, no compile, no class write, and no server path beyond the allowed-directory form the lookup tables already use. Record maps compile and generate classes, and PEX needs an external server and an AD-21 decision.
3. The list is OcuPilot's own, because the Schema viewer is a vendor frame OcuPilot never reaches into (AD-63). Both screens name `EnsPortal.HL7.SchemaMain`, so a custom resource on it gates both (AD-44).
4. The add takes the classic dialog's body and its audit call (the epic's "handler bodies are taken"). It does not take its `^EnsPortal.Settings` write or the source-control hooks: a source-controlled namespace is refused, as the lookup, partner, schedule and workflow families do.
5. Import and export are the lookup tables' two-source and two-destination shapes, extended through arguments rather than copied (Rule 31). The import is the vendor's own document load, so its transaction and validation are the vendor's.
6. The tool is named `delete`, as the classic page's button and the lookup table's tool are.
7. A description is judged by the published 2,000-character rule (Story 24.17 Batch 3b), so it adds no new string. A delete of a schema another schema is based on is not refused, as the classic page does not refuse it; the consequence says so.
8. The `PORT.NOTIMPLEMENTED` answer for a namespace without the HL7 package reuses an existing code and sentence (inference: never reached on IRIS for Health).
9. Siblings (Rule 31):
   - the lookup-table family (port, tools, transfer dialogs, browser specs);
   - `InteropWorkflowRoleAdd` and `WorkflowRoleSave` (create and Save route);
   - `InteropAlertFixture` (principals);
   - the workflow case and seam shape.

**Measured (Task 0, implement stage, `ocupilot-b-ci`, USER and HSCUSTOM, auditing on).** Probes were removed afterwards, and USER and HSCUSTOM hold the 14 standard schemas and no custom one.

- **(a) Footprint and audit.** Read by process id from the journal:
  - an add writes `^EnsHL7.Schema(<name>,"base"|"time")` and `^EnsHL7.Description(<name>)` in the namespace's own database (HSCUSTOM wrote HSCUSTOM's) and one audit row;
  - a delete kills `^EnsHL7.Schema(<name>)` and `^EnsHL7.Description(<name>)` and writes one audit row;
  - an import writes the same three nodes inside `BeginTrans`/`CommitTrans`, and one audit row;
  - an export, to a stream or a file, and the list read write nothing.
  - The vendor's `%Ensemble/%Schema/Modify` row "HL7 <name>" is written for the add (the positive control), the delete and the import ("Schema saved"); an export writes none. **The plan's "the vendor does not audit an import" is wrong: it audits one**, so an import leaves the vendor's row and OcuPilot's own.
  - `$ROLES`, `$USERNAME` and `$NAMESPACE` read the same before and after, for `_SYSTEM` (`%All,OcuPilotAdmin`) and for a principal without `%All`, across all four writes and both exports.
- **(b) Privileges.** A principal holding `%Ens_Portal:U`, `%Ens_EDISchema:R` and `%DB_USER:R` reads the list and one schema and exports to a stream and a file; each write answers `<PROTECT>` on `^EnsHL7.Schema(...)`. With `%Ens_EDISchema:W` and `%DB_USER:RW` each write succeeds, the audit call included. No other pair is asked (no `%Development:USE`; a server file's pairs are PathPort's). A principal without `%Ens_EDISchema` but with `%DB_USER:R` reads and exports too, so the port's gate is the whole gate and its database WRITE pair is load-bearing.
- **(c) Classic sets.** A schema made with a base and one with none are both listed by `TypeCategories` with base and description, and `ExportToStream("<name>.HL7")` exports each; a bare one exports `<Category name="...">` alone.
- **(d) Import.**
  - Listing: list-only `LoadStream` lists exactly `<name>.HL7` for an exported probe; a raw `<Category>` file is refused by the lister ("does not appear to be an IRIS exported file"); a file with a class lists `<Class>.cls` and the `.HL7`; a file with two schemas lists two.
  - Load: a selected load replaces the schema whole (an element the file lacks is gone, one it holds is kept), and the document's name governs when the `Category`'s differs.
  - Standard mark: an exported standard schema marks itself `std="1"` (2.5's export is 897,691 characters), and loading text with `std="1"` under a probe name sets the probe's `std` mark, which the vendor's delete then refuses. That is detectable before the load, from the `Category` element's `std` attribute, so the port refuses it (`IMPORTSTANDARD`) and no (d) halt applies. A `Document` holding two `Category` elements is refused by the vendor (not well-formed); the port also refuses it by count.
  - Round trip: an export, delete and import reads back identical, the export again equalling the first but for the `Export` element's `ts`. The import qualifies an element's reference to the base (`structure='ADT_A01'` becomes `'base:ADT_A01'`), so a schema that holds elements is not byte-identical after a round trip; this batch's probes hold none.
- **(e) Cap.** `TypeCategories` with 1,000 probes (1,019 rows) read in 0.335 s and with 2,000 (2,019 rows) in 1.32 s. `HL7SCHEMASMAX` is 2,000.
- **(f) Lock.** `Lock +^EnsHL7.Schema(<probe>):3` answers 0 after 3.01 s while another process holds it. The vendor's load asks that lock with no timeout and was still waiting after 6 s, finishing once the lock was released; the vendor's delete and the classic sets take no lock.

**Decided in-stage (implement).**

1. The lookup transfer primitives are generalized by argument rather than copied: `ImportText` (`pTooLargeCode`), `ImportShape` (`pSuffix`, `pElement`, `pFlagAttribute`, `pFlagged`), `CheckExport` (`pEndpoint`), the lookup import tool's `ScreenActionDelta` and `PortQuery` (boolean reviewed values), and the lookup export mint (the endpoint). `ReadHl7Import`, `PerformHl7Import` and `ExportHl7Schema` are siblings of the lookup read, perform and export, since their facts, lock and refusals differ.
2. `InteropHl7SchemaDelete`, `Export` and `Import` extend the lookup tools; `InteropHl7SchemaAdd` extends `InteropHl7SchemaAction`, which extends `InteropWorkflowAction` for its mint, argument problem and name sentence. The add's read-back re-reads through the export tool, whose read asks no write.
3. The export and import are bodyless composed types (`COMPOSEDTYPES`), and `Prohibited` gains `HL7IMPORTWRITETYPE` and an arm, after the lookup tables' import arm, that reads no target, since an import's target read needs its file.
4. An add and a delete record no row of OcuPilot's own when they succeed (the vendor's row stands); one that failed after the vendor call was attempted records one with `completed` false, so AC6 reads on all four writes.
5. A name outside the add's rule is not read, exported, deleted or imported: 404 (a schema created in the classic page with a space in its name is listed and is not managed here).
6. The export tool declares `%Ens_EDISchema` at READ as its own pair.
7. The agent's mint judges a new name through the kernel's id check (422 `INTEROP.HL7.NAME`) and the base and description as `TOOL.ARGUMENTS` naming the published sentence; the Save route judges all three as 422 violations.
8. No `# classes:` line is added to `scripts/ci-throwaway.sh`: the new classes inherit the arming variable from `InteropWorkflowCase`, which the roster already lists, and `ci.test.mjs` is green.
9. The seam extends the workflow seam and the fixture the workflow fixture, so the mode global, the log and the child-process principals are shared; the nothing-logged test gained a leg that logs nothing on success, since a log line after the fault hook was otherwise undetected.
10. The client page and the lookup page share one transfer flow class (`interop-transfer.flow.ts`) instead of a second copy; the dialog has its own small store.
11. An add or an import whose vendor write succeeded answers 200 when only the answer's re-read faults; the fault is logged once, after the restore.

**Governing ADs (Rule 6).** AD-3, AD-6, AD-7, AD-8, AD-10, AD-11, AD-13, AD-14, AD-15, AD-16, AD-21, AD-22, AD-29, AD-34, AD-36, AD-44, AD-51, AD-52, AD-53, AD-54, AD-55, AD-56, AD-58, AD-59, AD-60, AD-62, AD-63.

Not engaged: AD-9 (no vendor call here adds a role; a change is a HALT), AD-23, AD-35, AD-61 (no Atelier route: the documents move through `$System.OBJ`, as the lookup tables' do), AD-65 and AD-66.

**Integration and linkage (Rules 1, 2).** The Integration ACs are AC7, where the kernel's confirm consumes the stored proposal in its own namespace, and AC1's agent leg, through the derived read tool.

- **Consumes:** the lookup-table family, `InteropAction`, `PathPort`, and the kernel's proposal, confirm, governance and audit.
- **Consumed-by:** Batch 2's element editors, which act on the custom schemas this batch creates.

**Ledger inbox (Rule 17).** `LEDGER slice 24-18-pex-record-maps-and-hl7-authoring` was empty at plan; `owned_ledger=0`.

## Verification

**Commands.** Make one `ci-runner` call per message, against `ocupilot-b-ci` only.

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.InteropHl7SchemaList`, then the same for `InteropHl7SchemaControl`, `InteropHl7SchemaTransfer`, `InteropHl7SchemaRefusals`, `InteropHl7SchemaGate`, `InteropHl7SchemaElsewhere`, `InteropLookupTransfer`, `ConfirmNamespaceRoster`, `DraftRegistry`, `Prohibited`, `GovernanceBaseline`, `ClassicPageGate`, and every class the roster sweep changes. Expected: green, and new classes green on their first run.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`. Expected: green.
- `(loop)` Build and redeploy, then run the two specs:
  - `cd ui && npm run build`;
  - `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`;
  - `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/interop-hl7-schemas.browser-spec.mjs browser/interop-lookup-transfer.browser-spec.mjs`.

  Expected: green.
- `(once)` The full ObjectScript sweep: `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17` for k = 1 to 17, one call each. Expected: green. The full browser suite is left to CI.
- `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh`. Expected: clean.

**Shared surfaces:**

- the Interoperability side bar;
- the entity-type vocabulary and `COVEREDTYPES`;
- the governance baseline and the README count;
- the read-tool, coverage, draft, dry-run, classic-page, confirm-namespace and write rosters;
- `InteropError`'s code lists;
- the lookup import and export methods this batch generalizes;
- `interop.test.mjs`'s sentence rows and `screen-mirror.test.mjs`;
- the arming roster;
- both namespaces' HL7 schemas.

**Hermeticity.** Every test added or changed passes on its first run on a fresh instance, in either order. It makes its own probes and files, asserts on them by marker, drops them in both namespaces, and removes any principal it made.

**Mutations.** Each AC's pinning test is shown red on `ocupilot-b-ci`, with `src` reloaded with subclasses and then reverted byte-identical. Client mutations run on a rebuilt, redeployed bundle or in the component runner. The implement stage records each as `mutation: <change> -> <test red>`. Planned:

- AC1: the `Standard` mark dropped from the row → `InteropHl7SchemaList` red.
- AC2: the add skips `Description` → `InteropHl7SchemaControl` red (read-back leg).
- AC3: the import's selected-document array is left empty → `InteropHl7SchemaTransfer` red.
- AC4: the port's standard refusal removed (the vendor's own guard then answers) → `InteropHl7SchemaControl` red on its 409 `INTEROP.HL7.STANDARD` assertion.
- AC5: the `TAKEN` test made exact-case → `InteropHl7SchemaRefusals` red; a log line inside the switched block → red.
- AC6: the vendor status ignored → `InteropHl7SchemaRefusals` red.
- AC7: `FINGERPRINTSUBJECT` without `Namespace` → `InteropHl7SchemaElsewhere` red.
- AC8: the `DraftRegistry` row removed → red; the new `Prohibited` arm placed before an earlier one → `Prohibited` red.
- AC9: the README count left at one hundred and six → `interop.test.mjs` red.
- AC10: the dialog sends no base → the browser spec red.
- AC11: `DropProbes` skipped → `InteropHl7SchemaElsewhere`'s after-all check red.

Run on `ocupilot-b-ci` (each reverted `cmp`-identical to a copy taken before, the port and every subclass reloaded, and the test green again):

- mutation: AC1 `Hl7SchemaRow` sets `Standard` to 0 -> `InteropHl7SchemaList` `TestTheListHoldsTheStandardSchemasThenEachProbe` red.
- mutation: AC2 `Hl7VendorWrite` skips the description -> `InteropHl7SchemaControl` `TestAddFromBothCallersReadsBackAsSent` red.
- mutation: AC3 `Hl7VendorLoad` selects another document -> `InteropHl7SchemaTransfer` both round trips red.
- mutation: AC4 `Hl7WriteToken` and `ReadHl7Schema` drop the standard refusal -> `InteropHl7SchemaControl` `TestDeleteFromBothCallersAndAStandardSchemaIsRefused` red on its 409 legs.
- mutation: AC5 `Hl7FactsHere` matches the name exactly -> `InteropHl7SchemaRefusals` `TestAddValuesTheNamespaceCannotTakeAreRefusedByName` and the import case leg red; a `LogFault` line inside `ListHl7Schemas`' switched block -> `TestNothingIsLoggedWhileTheNamespaceIsSwitched` red.
- mutation: AC6 `PerformHl7Schema` ignores the vendor status -> `InteropHl7SchemaRefusals` `TestALockASourceControlledSeamAndAVendorErrorNeverAnswer200` red.
- mutation: AC7 `InteropHl7SchemaDelete.FINGERPRINTSUBJECT` without `Namespace` -> `InteropHl7SchemaElsewhere` `TestEachAgentWriteActsWhereItWasMintedWhateverNamespaceConfirms` red (`PROPOSAL.TARGETCHANGED`).
- mutation: AC8 the `DraftRegistry` row removed -> `TestNoSecretReachesAnyRenderedScript` red; the `Prohibited` HL7 arm made unconditional -> seven `Prohibited` tests red; `ConfirmNamespaceRoster.CHECKEDFLOOR` above the 170 tools walked -> red.
- mutation: AC9 the README count one less -> `interop.test.mjs` red.
- mutation: AC10 the dialog's store sends no base, on a rebuilt and redeployed bundle -> `interop-hl7-schemas.browser-spec.mjs` AC10 red (the Save carries no `Base`).
- mutation: AC11 `DropSchemas` returns at once -> every `InteropHl7SchemaElsewhere` test red on its after-test removal check.
- mutation: AC4/AC5 `InteropHl7SchemaDelete.FINGERPRINTSUBJECT` narrowed to `Category,Namespace` -> `InteropHl7SchemaControl` `TestADeleteMintedBeforeTheSchemaChangedIsClosedAsMoved` and the delete legs red (`PROHIBITED.UNCOVEREDFIELD`).
- mutation: AC5 both `Hl7Unlock` calls removed from `PerformHl7Schema` -> `InteropHl7SchemaRefusals` `TestALockASourceControlledSeamAndAVendorErrorNeverAnswer200` red on its lock-count leg.
- mutation: AC6 the export's vendor-status test removed -> the same test red on its export legs.
- mutation: AC3 the export's `AuditRuntime` call skipped for a server file -> `InteropHl7SchemaTransfer` `TestTheServerFileRoundTripThroughTheAgentRestoresTheSchema` red on its export-row legs.

## Auto Run Result

Status: in-review
Blocking condition: none

**Implement pass (Batch 1).** HL7 schemas: `InteropPort` `Hl7Schemas` (list, one-schema read, import read, add, import, export, delete), the Save route, four tools, the descriptor, the client page and dialog, 12 codes, 4 governance keys (add and export `true`; import and delete `false`, README count one hundred and eight), the `Prohibited` terms, and the rosters. The lookup transfer primitives are extended by argument. Verified on `ocupilot-b-ci`:

- New classes `InteropHl7SchemaList`, `Control`, `Transfer`, `Refusals`, `Gate`, `Elsewhere` green (the review pass added two tests and more assertions to `Control`, `Refusals` and `Transfer`). Every AC has a `mutation:` line above.
- Full sweep, 17 shards, 934 classes, 6,969 tests: shards 1 to 4, 6, 8 to 14, 16 and 17 green. Shard 7's `InteropHl7SchemaGate` held a stale `CLASSICPAGES` expectation for the add and shard 15's `ToolDispatch` lacked the two new baseline-off keys; both fixed and re-run green on their own (2 of 2, 19 of 19).
- **Red, not touched by this batch:** shard 5's `LogHubErrors.TestASeededErrorReadsInTheHubsForm` (455 tests, 1 failed), and red again on one diagnostic re-run and one diagnostic copy that printed `size=1 trunc=0` for the cap-of-one read, at 00:17Z to 00:23Z. Neither it nor `LogSourcePort` is in the diff. (inference) The accumulated error log of this long-lived throwaway, or the UTC midnight rollover, is the cause; a fresh CI leg has neither.
- Client: `npm run test:tools` 2,428 of 2,428, `npm run test:components` 4,135 of 4,135, `node --test tools/ci.test.mjs` 109 of 109, `npm run build` green. Browser on a rebuilt, redeployed bundle: `interop-hl7-schemas` 2 of 2, `interop-lookup-transfer` and `interop-lookup-tables` 5 of 5. Smoke `executed=49 passed=49 failed=0`. `check-objectscript.py` 0 problems, `lint-docs.sh` 0 issues.
- Review pass: 11 findings, 5 patched, 1 deferred, 5 rejected (Review Triage Log). Task 0 found the vendor audits an import (the intent's AD-15 line says it does not); both rows are written.

**Plan.** This is Batch 1 of five: HL7 schemas, a list with add, import, export and delete through `InteropPort`, each reached by the screen and the agent. The proposal keeps its namespace, and every judgment at confirm runs there. Veto items 1 to 6, the batch split and the decided-in-stage list are under Design Notes. Read-only checks ran on `ocupilot-b-ci` (52777, image `irishealth-community:2026.2`):

- USER and HSCUSTOM hold the 14 standard HL7 schemas and no custom one, no user record map and no PEX proxy;
- the HL7 globals map to each namespace's own database;
- neither namespace is source-controlled;
- `%Ensemble/%Schema/Modify` is enabled;
- `%Ens_RecordMap` is held by no shipped role;
- Java and `javac` are present, and no `iris.pex` Python package was found.

Nothing was written to the instance.
