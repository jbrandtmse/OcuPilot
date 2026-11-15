---
title: 'Story 21.13: DDL mappings'
type: 'feature'
created: '2026-11-15'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The instance's SQL DDL mappings (the classic System-defined and User-defined DDL Mappings pages, `Config.SqlSysDatatypes` and `Config.SqlUserDatatypes`) have no screen, no route and no tool in OcuPilot. An operator who wants to see or change how a DDL type name maps to a datatype class has to use the classic portal.

**Approach:** Extend Story 21.3's `ConfigPort` with two named-entry endpoints whose rows keep the settings-table shape (`Name` is the DDL type, `Value` its datatype class), and add the request types `CREATE` and `DELETE` beside `SET`. Two list screens on the shared settings page: user mappings take New mapping, Set value and Delete; system mappings take Set value and Delete, as the classic page offers. Each write is reached by a person's action or Save and by a confirmed agent proposal (AD-53, AD-55).

## Boundaries & Constraints

**Always:** `ConfigPort` is the only product class that names `Config.SqlSysDatatypes` or `Config.SqlUserDatatypes`; it gates before any vendor call (AD-29) and switches namespace by save and restore (AD-16). A set sends the complete property set `Get` answered with `Datatype` changed (AD-4). Every write is minted, confirmed once, audited, read back (AD-58) and announced (AD-14); a create fingerprints the name's absence (AD-54). The name and the datatype are judged by `ConfigSettingRules` at the mint, at the Save and at the port. A caller's name is never passed to the vendor's `List` query, whose `Names` argument is a pattern. Every read is bounded (AD-36). Both delete keys ship `false`, and both deletes are destructive.

**Never:** No system-mapping create (the classic page offers none). No `Comments` edit (the classic page hides it; `Get` answers none, measured). No harvested body. No new `PROHIBITED.*` predicate (Design Notes, Self-protection). No user-facing string beyond those the spec gate rules. OcuPilot's own interface stays English.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| System read | `GET` system mappings | One row per `Config.SqlSysDatatypes` entry (100 on slot A), `{Name, Value, Kind, Accepts, Restart, ReadOnly, Purges}`, `Kind` `datatype`, `Restart`, `ReadOnly`, `Purges` false | none |
| User read | `GET` user mappings | One row per `Config.SqlUserDatatypes` entry (0 on slot A); the empty state | none |
| Create | `ZZOCU<job>` → `%Library.String(MAXLEN=%1)`, by both callers | The row reads the datatype; `readBack` matches; every other row unchanged; removed after | none |
| Set | a user or system row, by both callers, then restored | The row reads the new datatype; every other row unchanged | none |
| Delete | a user row; a system row restored by vendor `Create` in teardown | The row is gone; read-back reads 404 | none |
| Name taken | create of a held name | nothing sent | 409 `CONFIG.MAPPING.TAKEN` at Save, mint and port |
| Bad input | name with `=`, `,`, `*`, `^`, a control character, edge spaces, or over 64; datatype not class-shaped or over 256 | nothing sent | 422 on the field at Save; 400 `CONFIG.SETTING.VALUE` / `CONFIG.MAPPING.NAME` at mint and port |
| Absent | set or delete of a name the list does not hold | nothing sent | 404 `CONFIG.SETTING.NOTFOUND` |
| System create | `CREATE` on `SystemDDL` | nothing sent | 501 `PORT.NOTIMPLEMENTED`; no tool, no action |

</intent-contract>

## Code Map

- `irissys/%CSP/UI/Portal/Config/SQLDataTypes.cls` -- the classic list: `RESOURCE` `%Admin_Manage` (:22); `Subject` `SystemDataTypes`|`UserDataTypes` picks the class (:70-79); columns `Name`, `Datatype`, `Comments` hidden (:49-51); Edit and Delete on both subjects (:52-53); Create only for user (:132-135).
- `irissys/%CSP/UI/Portal/Config/SQLDataType.cls` -- the edit form: `Name`, `Datatype`, both required (:41-55); the save sends `Datatype` alone (:73-77). `irissys/%CSP/UI/Portal/Config/AdvancedEdit.cls:64-87` (`Modify(PID,.Properties)` or `Create(Name,.Properties)`), `AdvancedList.cls:84-101` (`Delete(Name)`).
- `irissys/Config/SqlUserDatatypes.cls:54,90` and `SqlSysDatatypes.cls` (same shape) -- `Datatype` `%String(MAXLEN=256, MINLEN=1)` required; `List` query `Name,Datatype,Comments`, `Names` is a pattern (`*`, `,`). `irissys/Config/CommonProperties.cls:47` -- `Name` `MAXLEN` 64 `MINLEN` 1; `Comments` is CPF comment lines (:14). `irissys/Config/CommonMultipleMethods.cls:43,71,96,109,144` -- `Create`, `Delete`, `Exists`, `Get`, `Modify`.
- **Measured (read-only, slot A, 2026-11-15):** system 100 mappings, user 0; `Get("VARCHAR")` answers `Datatype` only; lookup is case-sensitive (`Get("varchar")` #420); longest name 30, longest datatype 100; every system datatype matches `%?[A-Za-z][A-Za-z0-9.]*(\(.*\))?` and no name holds `=` or lower case; `NormalizePage` keeps both classic keys as spelled; neither carries a custom resource.
- **Port to extend:** `src/OcuPilot/Port/ConfigPort.cls` -- `ENDPOINTS` :54, `WRITETYPES` :117, `Serves` :195, `VendorClass` :203, `IsRoster` :214, `Invoke` :228, `Collect` :332, `BuildRow` :376, `Limits` :401, `AcceptsOf` :450, `IsReadOnly` :467, `NeedsRestart` :479, `SetValue` :509, `Apply` :534, `PurgeAfterSet` :743 (a no-op for a non-purging row), `VendorModify`/`ReadProperties`/`SendProperties` seam :793-844, `SnippetForm`/`Snippet` :879-907.
- **Rules and copy:** `src/OcuPilot/Area/OsMgmt/ConfigSettingRules.cls` (`Code` :22, `ValueHolds` :34, `WriteProblem` :71); `src/OcuPilot/Api/ConfigError.cls` (codes :16-38, Accepts sentences :42-54).
- **Tools to extend:** `src/OcuPilot/Screen/Tool/ConfigSettingSet.cls` (set, `Consequence` :134, `AfterWrite` :151, `PrivilegePairs` :176) and `SqlSettingSet.cls` (subclass shape). Create and delete mechanics: `InteropLookupEntryAdd.cls` (`CREATES`, `ComposeCreate`, `CreatedId`) and `InteropLookupEntryRemove.cls` (`DESTRUCTIVE`, `FINGERPRINTSUBJECT`, `PRECONDITIONFIELD`, `REMOVALROWS`, `StateDiff`). `Kernel/Proposal/Mint.cls:19,175` -- a create's 404 proceeds.
- **Screen Save to extend:** `src/OcuPilot/Area/Interop/ItemSave.cls` (`HandleCreate` :100, `Create` :151, `Absent` :208, `Gate` :321) and its no-parent subclass `PartnerSave.cls` (`PRODUCTIONMEMBER` ""); `Api/Router.cls:274,1938` (the route-and-thin-target pair to copy).
- **Descriptor shape:** `src/OcuPilot/Screen/Descriptor/SqlSettingList.cls`.
- **Client:** `ui/src/app/areas/os-management/config-settings.page.ts` (`SERVED_LISTS` :24, `CONFIG_SET_ACTION` :35, `onOpen` :172, `onSet` :209); the add-dialog model `areas/interoperability/interop-lookup-entry-dialog.ts` and its store's post; `shell/screen-action-handler.ts` (`UNDRAWN_ACTIONS` :459, `DESTRUCTIVE_ACTIONS` :592, `DESTRUCTIVE_CONSEQUENCES` :620), `shell/screen-outlet.ts:172`, `core/screen-actions.ts:186`, `core/proposal-view.ts`, `core/strings.ts`, `core/screens.generated.ts`.
- `ui/tools/screen-mirror.mjs:1226` -- `configEndpoints()` parses `ConfigPort.ENDPOINTS`. Arming: `scripts/ci-throwaway.sh` (`OCUPILOT_ALLOW_CONFIG_SETTINGS`, `# classes:` line). Seams fixture: `src/OcuPilot/Test/ConfigGateSeam.cls`.

## Tasks & Acceptance

**Execution, batch 1 (server; commit when its loop commands are green):**

- Task 0, on `ocupilot-ci`, recorded under Design Notes before code, every probe restored: (a) `Create`, `Modify` and `Delete` on each class by a caller holding only `PAIRS` fail and with `WRITEPAIRS` succeed; (b) none adds a `Config.CPF.PendingRestart` reason; (c) the vendor's answers to a held name, a name with `=`, `,` or `*`, a 65-character name, an empty datatype, a datatype naming no class, and an absent delete; (d) a deleted system mapping restored by `Config.SqlSysDatatypes.Create` reads back identical and the count returns; (e) with `VARCHAR(%1)`'s datatype changed, `smoke.sh --container ocupilot-ci` and `ConfigSettingRead` stay green (`ocupilot-ci` loads the test classes, so `ConfigSettingRead` runs there); red means `## Clarification Needed` naming it; (f) in `USER`, a `CREATE TABLE` naming a fresh user mapping maps it, and after its delete the same statement's answer (for the delete sentence); the table is dropped.
- `src/OcuPilot/Port/ConfigPort.cls` -- `ENDPOINTS` adds `SystemDDL`, `UserDDL` (`VendorClass` answers each class); `WRITETYPES` `SET,CREATE,DELETE`; `Serves`: `CREATE` only on `UserDDL`, `DELETE` only on the two DDL endpoints. A named family: `Collect` lists through the class's `List` query with `*` (all) or reads one row by `Get(name)`, never `List(name)`; rows `Kind` `datatype`, `Accepts` the datatype sentence, `ReadOnly`, `Restart`, `Purges` false. `SET` reads the row and sends `Get`'s set with `Datatype` changed through a `SendEntry` seam. `CREATE`: row absent else 409 `CONFIG.MAPPING.TAKEN`, then rules, then `CreateEntry` seam; answers `{Name, Value}`. `DELETE`: row present else 404, then `DeleteEntry` seam; answers `{Name}`. A vendor refusal is logged (AD-39) and answers 400 `CONFIG.SETTING.VALUE`. `Snippet` renders `Get`/`Modify`, `Create` and `Delete` with literal arguments (AD-59).
- `src/OcuPilot/Area/OsMgmt/ConfigSettingRules.cls` -- kind `datatype` (the measured pattern, 1-256 characters); `NameCode(name)` for a create (1-64 characters, no `=`, `,`, `*`, `^`, control character or edge space) answering `CONFIG.MAPPING.NAME`; `WriteProblem` asks it for a create tool.
- `src/OcuPilot/Api/ConfigError.cls` -- `MAPPINGTAKEN`, `MAPPINGNAME`, `MAPPINGDELETE` (consequence) with ruled reasons; `ACCEPTSDATATYPE`.
- `src/OcuPilot/Screen/Tool/` -- new `DdlSystemMappingSet`, `DdlUserMappingSet` (ConfigSettingSet subclasses); `DdlUserMappingCreate` (ConfigSettingSet with `CREATES` 1, `WRITETYPE` `CREATE`, `SCREENACTIONS`, `SCREENVALUES` and `SCREENEMPTY` empty (its screen caller is the Save route), `CreatedId` the name); `DdlMappingDelete` (abstract ConfigSettingSet: `WRITETYPE` `DELETE`, no body, `DESTRUCTIVE`, `SCREENACTIONS` `delete` with `SCREENVALUES`, `SCREENEMPTY` and `READBACKFIELDS` empty (the read-back reads the row gone), fingerprint and removal rows `Name,Value`, precondition `Value`, consequence `CONFIG.MAPPING.DELETE`) with `DdlSystemMappingDelete`, `DdlUserMappingDelete`. `CLASSICPAGES` `%CSP.UI.Portal.Config.SQLDataTypes,%CSP.UI.Portal.Config.SQLDataType`.
- `src/OcuPilot/Screen/Descriptor/DdlSystemMappingList.cls`, `DdlUserMappingList.cls` -- on `SqlSettingList`'s shape: source `config`, endpoints above; the next two free OS management positions (34 and 35 after Story 21.12's 33); routes `os-management/system-ddl-mappings`, `user-ddl-mappings`; entity types `system-ddl-mapping`, `user-ddl-mapping`; tools `osmgmt.systemddlmappings`, `osmgmt.userddlmappings`; row actions `set`, `delete`; columns `Name`, `Value` (labeled Datatype); `classicPage` `%CSP.UI.Portal.Config.SQLDataTypes`; pairs `%Admin_Manage:USE`, `%DB_IRISSYS:READ`.
- `src/OcuPilot/Area/OsMgmt/DdlMappingSave.cls` -- new, extends `ItemSave` with no parent (`PartnerSave`'s shape): `CREATETOOL` `DdlUserMappingCreate`, `DESCRIPTORCLASS` `DdlUserMappingList`, members `Name` and `Value`, `Violations` from `ConfigSettingRules`, `TAKENCODE`/`TAKENREASON` pinned to `ConfigError`. `src/OcuPilot/Api/Router.cls` -- add-only `POST /config/ddl-mappings` and its thin target.
- Add-only rows: `Kernel/Governance/Baseline.cls` (`osmgmt.systemddlmappings.set` `true`, `.delete` `false`; `osmgmt.userddlmappings.create` `true`, `.set` `true`, `.delete` `false`); `Kernel/EntityType.cls` and `Kernel/Proposal/Prohibited.cls` (two covered types, no predicate); `Screen/Titles.cls` regenerated; `scripts/ci-throwaway.sh` (`DdlMappingWrite` on the config-settings `# classes:` line).
- `src/OcuPilot/Test/DdlMappingRead.cls` (live-safe: both reads, row shape, `Get` not `List` for a named read, gate refusals, governance defaults, `Serves`, read-source cases), `DdlMappingRules.cls` (live-safe, `ConfigGateSeam`: every refusal at mint, Save and port, the three seams' arguments, the snippets), `DdlMappingWrite.cls` (armed: the matrix's writes by both callers, marker names `ZZOCU<job>`, each restored in `OnAfterOneTest` behind the `PreparedPolicyTaken` guard). Each creates what it asserts on.
- The shared-surface tests under Verification, each to the new shape.

**Execution, batch 2 (client; commit when its loop commands are green):**

- `ui/src/app/areas/os-management/config-settings.page.ts` with its spec -- the two descriptors in `SERVED_LISTS`; New mapping (user list only, registered by the page) opens a new `ddl-mapping-dialog.ts` (Name and Datatype, with its spec) that posts to the Save route; refusals stay on their field. `shell/screen-outlet.ts`, `shell/screen-action-handler.ts` (`set` and `create` undrawn, the two delete consequences), `core/screen-actions.ts` (labels), `core/proposal-view.ts` (`CONFIG.MAPPING.DELETE`), `core/strings.ts`, `screens.generated.ts`.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` -- the ruled strings into Fixed strings; the two screens into OS management's side-bar row (add-only).
- `ui/browser/ddl-mappings.browser-spec.mjs` -- both screens answer rows after the answered signal; New mapping creates `ZZOCU<n>`, Set value changes it, Delete (typed name) removes it; a held name shows `CONFIG.MAPPING.TAKEN` in the dialog; the system list offers no New mapping.

**Acceptance Criteria:**

- AC1. Given the user mappings screen and tools on `ocupilot-ci`, when a mapping is created, its datatype set and it is deleted, each by both callers, then each round-trips over `Config.SqlUserDatatypes`: the row reads what was sent, `readBack` matches (gone after a delete), and every other row is unchanged.
- AC2. Given the system mappings screen, when a system mapping's datatype is set and a system mapping is deleted, each by both callers, then each round-trips over `Config.SqlSysDatatypes` and is restored; no surface, tool or port type creates a system mapping.
- AC3. Given a held name, an absent name, or a name or datatype the rules refuse, when either caller writes, then the matrix's refusal answers before any vendor call, and a refused Save shows it on its field.
- AC4. Given the default baseline, when the agent proposes each write, then create and set mint and confirm once with one audit marker and a `readBack`; each delete is refused by governance, and with its key `true` mints destructive with the delete consequence and confirms once.
- AC5. Given these mappings configure the server's SQL DDL rather than OcuPilot's own interface, when both screens and their dialogs render, then every label, Accepts line, refusal and consequence is an English `strings.ts` value pinned equal to its `ConfigError` sentence.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs:** AD-4 (a set sends `Get`'s complete set, measured as `Datatype` alone), AD-6, AD-10 (two covered types, no predicate), AD-13 (names with spaces and parentheses travel percent-encoded in one segment), AD-14, AD-15, AD-16, AD-21 (no path; no caller value reaches a `List` pattern), AD-22 (create and set `true`, deletes `false`), AD-29, AD-34, AD-35 (no field holds a credential), AD-36, AD-39, AD-44, AD-52, AD-53, AD-54, AD-55, AD-56, AD-58, AD-59.

**Extend, don't copy (Rule 2/31):** extends `ConfigPort` (a named-entry family beside its single-section and roster families), `ConfigSettingRules`, `ConfigError`, `ConfigSettingSet` (all five tools subclass it, the create and the delete following `InteropLookupEntryAdd`/`Remove`'s parameters), `ItemSave` (no-parent Save, as `PartnerSave`), `SqlSettingList` and `config-settings.page.ts`. The new dialog copies `interop-lookup-entry-dialog.ts`'s field markup rather than extending it: that dialog is bound to its own store and table semantics. Tests are new classes because the 21.3 and 21.4 classes are near the 500-line guide.

**Self-protection.** Product code runs no DDL (`CREATE`, `ALTER`, `CAST` absent from `src/OcuPilot` outside `Test/`, grep), so no mapping change reaches OcuPilot's own SQL (inference); Task 0 (e) measures it. No predicate is added.

**Decided in-stage:**

- Rows keep `ConfigPort`'s shape (`Value` is the datatype), so the read tool, the rules, the Set value dialog and the set tool are reused unchanged; the column is labeled Datatype.
- The datatype is held to the shape every system mapping has (measured), stricter than the classic page's required-only check; the name refuses `=`, `,`, `*`, `^`, control characters and edge spaces, stricter than the classic page, because `,` and `*` are the `List` query's pattern syntax and `=` the CPF line's separator (inference).
- The screen's create goes through a Save route because no screen action carries a create (AD-55, `ExplorerCreate`).
- No restart: Task 0 (b) confirms; `Restart` is false on both lists.

**Escalated for the spec gate's ruling:**

- **System mappings writable (recommended) or read-only.** The runner's brief calls the system mappings read-only. The AC ("round-trips over its backing class"), catalog row SA-33 ("edit / delete", write-confirm) and the classic page all offer edit and delete, and no self-protection reason is known, so this plan keeps them, behind a destructive delete whose key ships `false`. Read-only would drop SA-33's writes, which is owner scope (U5); it would remove `DdlSystemMappingSet`, `DdlSystemMappingDelete` and two baseline keys.
- **Strings** (reuse: "Name", "Set value", "Delete", 21.3's refusal sentences): titles "System DDL mappings" · "User DDL mappings"; entity nouns "system DDL mapping" · "user DDL mapping"; column "Datatype"; action "New mapping"; dialog title "New DDL mapping"; field labels "Name" · "Datatype"; empty states "No system DDL mappings." · "No user DDL mappings."; empty-agent phrases "change a system DDL mapping" · "add a user DDL mapping"; `ACCEPTSDATATYPE` "A datatype class name, with its parameters in parentheses if it takes any, of up to 256 characters."; `CONFIG.MAPPING.TAKEN` "This instance already holds a user DDL mapping of that name."; `CONFIG.MAPPING.NAME` "A name is 1 to 64 characters, with no =, comma, *, ^, control character, or space at either end."; `CONFIG.MAPPING.DELETE` (both lists' delete consequence, final wording after Task 0 (f)) "DDL that names this type no longer maps it to this datatype."; prompts "Which DDL type maps to %Library.String?" · "What does VARCHAR map to?" · "Which user DDL mappings does this instance have?" · "How do I map a new DDL type to a class?".

**Integration ACs:** the two endpoints are consumed in this story by their descriptors, five write tools and the Save route (AD-53's two callers); AC1-AC4 observe them through the API and the browser. **Consumed-by:** none known. **Consumes:** Story 21.3/21.4's `ConfigPort`, rules, error, set tool and page; Story 20.26's no-parent `ItemSave`; `Screen.Gate`, `Kernel.Fault`, `Screen/Tool/Write`.

**Ledger inbox:** none.

**Contended paths:** no Epic 22 or Epic 24 commit beyond feature touches a file named here (checked at plan time). Epic 24's worktree holds uncommitted edits to `EXPERIENCE.md`, `ci-throwaway.sh`, `Baseline.cls`, `Prohibited.cls`, `Screen/Read.cls`, `Test/ClassicPageGate.cls` and `Test/Descriptor.cls`; this story's edits there are add-only rows. `ItemSave` is subclassed, never edited.

**Runner ruling at the spec gate (2026-11-15):** system mappings stay editable and deletable as planned (the runner's brief that called them read-only is withdrawn), deletes destructive with keys off; the escalated strings are kept as planned (veto U-55). If the strings take EXPERIENCE.md past the literal cap, raise it by 400 under the file's protocol and report it.

## Verification

**Shared surfaces:** OS management roster, positions and visible or unavailable sets (`Navigation`, `WireSecurityRead` rosters and pair-order counts, `WireAreaAnyScreen`, `LanguageServerWire` and `ui/browser/language-servers.browser-spec.mjs`, `ui/tools/navigation.test.mjs`, `Descriptor`, `StageTwoTools`, `ui/tools/screen-mirror.test.mjs`); the tool registry (`ReadTool` registry size, `ReadDescriptions`, `ToolWrite` other-port count, `ToolRoundTrip`, `ToolDispatch`, `ToolEmit`); entity types (`Descriptor`, `Prohibited` covered types); the `config` row shape and endpoint roster (`ConfigSettingRead`, `ConfigSettingRules`, `ConfigSettingMint`, `ConfigSettingWrite`, `SqlSettingRead`); `PortGate`, the read-source count, `ClassicPageGate`, `MappingDescriptor`, `SurfaceCoverage`, `GovernanceBaseline`, `TeardownGuard`, `proposal-view.test.mjs`, `ci.test.mjs` (arming roster), and the EXPERIENCE.md literal cap in `ui/tools/strings.test.mjs` (4200; a crossing is reported for the runner's ruling, never re-based in-stage). The implement stage greps `ui/browser`, `ui/tools`, the `ui/src` specs and `src/OcuPilot/Test` for each; every test it changes joins `(loop)`.
*Every test added or changed passes on a fresh environment, in either order.* Each write test creates its own `ZZOCU<job>` mapping or restores the system row it changed.

**Commands.** One per foreground call, `timeout: 600000`, against `ocupilot-ci` only; never two test calls in one message.

- `(loop)` `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/4667058b-f052-49c9-b08a-221f7f41dfab/scratchpad/e21u/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` -- expected: `LOADERRORS=0`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.DdlMappingRead`, one class per call, then each of `DdlMappingRules`, `DdlMappingWrite`, `ConfigSettingRead`, `ConfigSettingRules`, `ConfigSettingMint`, `ConfigSettingWrite`, `SqlSettingRead`, `PortGate`, `SurfaceCoverage`, `GovernanceBaseline`, `Governance`, `Prohibited`, `ReadTool`, `ReadDescriptions`, `ToolEmit`, `ToolDispatch`, `ToolRoundTrip`, `ToolWrite`, `Descriptor`, `Navigation`, `ClassicPageGate`, `MappingDescriptor`, `DraftRegistry`, `StageTwoTools`, `Wire`, `WireAreaAnyScreen`, `WireSecurityRead`, `LanguageServerWire`, `TeardownGuard` -- expected: green.
- `(loop)` `uv run scripts/check-objectscript.py`, `uv run scripts/test_check_objectscript.py`, `bash scripts/lint-docs.sh` -- expected: clean.
- `(loop)` `cd ui && node --test tools/config-settings.test.mjs tools/strings.test.mjs` and every `ui/tools` test the sweep changes -- expected: green.
- `(loop)` `cd ui && npm run build` and `npm run test:components`; redeploy with `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`; then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/ddl-mappings.browser-spec.mjs browser/language-servers.browser-spec.mjs` -- expected: green.
- `(once)` `cd ui && npm run test:tools` -- expected: green.
- `(once)`, runner-owned: the full ObjectScript sweep one class per call, `smoke.sh --container ocupilot-ci`, and Rule 30's fresh check. The full browser suite is left to CI.

**Mutations (Rule 19), one per AC, each applied, observed red, reverted byte-identical and the reverted source reloaded, then recorded here by the implement stage as `mutation: <change> -> <test red>`:** AC1 `SendEntry` sends the fresh read's datatype instead of the new one; AC2 `Serves` admits `CREATE` on `SystemDDL`; AC3 `Collect` reads a named row through `List(name)`, or the name rule admits `*`; AC4 `osmgmt.userddlmappings.delete` `true` in `Baseline`; AC5 one word of `CONFIG.MAPPING.TAKEN` changed in `strings.ts`.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Plan pass: spec written from read-only probes on slot A (`ocupilot`); nothing ran against `ocupilot-ci`. One question escalated for the spec gate (system mappings writable, recommended, or read-only as the brief says) and the new strings listed under Design Notes.
