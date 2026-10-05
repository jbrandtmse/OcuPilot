---
title: 'Story 18.22: Database and data-element encryption keys'
type: 'feature'
created: '2026-10-04'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The classic Database Encryption and Data Element Encryption pages (`%CSP.UI.Portal.EncryptionDatabase`, `%CSP.UI.Portal.EncryptionManaged`) are still the only place to see which encryption keys are active and to activate or deactivate them. The admin API carries it: `Security.Encryption.Key` (`LIST`, `DATAELEMENTLIST`, `DEACTIVATE`) and `Security.Encryption.File` (`ACTIVATE` with `ActivateDB` or `ActivateMK`). Two ledger items ride along: DW-2059 (the key-id comparison in `Prohibited.DependsOnKey`) and DW-2066 (journal files still needed for recovery).

**Approach:** Add **Database encryption** (Security and secrets, position 9) and **Data element encryption** (10), each a list of the active keys with an Activate action and a Deactivate row action, through four write tools on Story 18.7's `EncryptionPort`. A Task 0 on `ocupilot-b-ci` measures activation first (Community license) and picks real or seam success legs. DW-2059 is settled by measuring the real key-id spellings, and DW-2066 by widening the dependency check to the vendor's own `IsEncKeyInUse`. Encrypting or decrypting an existing database has no admin API route and no classic page, so it is named unreachable, not built.

## Boundaries & Constraints

**Always:**

- **Task 0 runs first, on `ocupilot-b-ci` only**, before any descriptor, tool or page (Tasks › Task 0). Probe objects use the prefix `OCUPROBEACT`, which no other suite's prefix matches and which matches none of theirs (`OCUPROBE1822` would fall under Story 18.2's `OCUPROBE182`). That means key files and the probe database under `<ManagerDirectory>ocuprobeact/`, and principals `OcuProbeAct*`. Task 0 restores S0 (18.7's definition: `EncryptionProbe.Snapshot` plus the audit event count) and halts on any listed contradiction.
- **Screens** (Security and secrets; privileges `%Admin_Secure:USE`, `%DB_IRISSYS:READ`, no own pair; three prompts each; no auto-refresh; `id` `{"kind": "none"}`):

  | Descriptor | Route | Archetype | Pos | Entity type (singleton) | Read | `classicPage` | `toolIdentifier` |
  | --- | --- | --- | --- | --- | --- | --- | --- |
  | `DatabaseEncryption` | `security/database-encryption` | `list` | 9 | `database-encryption-keys` | admin `Security.Encryption.Key` `LIST`: `Id`, `KeyLen`, `IsDefault` | `%CSP.UI.Portal.EncryptionDatabase` | `security.databaseencryption` |
  | `DataElementEncryption` | `security/data-element-encryption` | `list` | 10 | `data-element-encryption-keys` | admin `Security.Encryption.Key` `DATAELEMENTLIST`: `Id` | `%CSP.UI.Portal.EncryptionManaged` | `security.dataelementencryption` |

  Each declares `primaryAction` `activate`, `rowActions` `deactivate`, and `secretArguments` `["AdminPassword"]`.
- **Tools** (on `Port/EncryptionPort`; action-style with port-built bodies, AD-51 and AD-56 (i); every governance key `false`; advertised; no `CLASSICPAGES`, since each descriptor's own classic page performs its tools' operations). Each targets its descriptor's singleton: scope `instance`, id `SYSTEM`, the `LicenseKeyActivate` model.

  | Tool | Vendor call | Arguments; secrets | Kind |
  | --- | --- | --- | --- |
  | `security.databaseencryption.activate` | `File` `ACTIVATE`, `{Action: "ActivateDB", AdminName, AdminPassword}` | `root`, `path`, `AdminName`; `AdminPassword` | action, secret body |
  | `security.databaseencryption.deactivate` | `Key` `DEACTIVATE` `id`=`KeyId`, `{Action: "DeactivateDB", AdminName: "", AdminPassword: ""}` | `KeyId` | action, composed body, `DESTRUCTIVE` |
  | `security.dataelementencryption.activate` | `File` `ACTIVATE`, `{Action: "ActivateMK", AdminName, AdminPassword}` | as the database activate | action, secret body |
  | `security.dataelementencryption.deactivate` | `Key` `DEACTIVATE`, `{Action: "DeactivateMK", AdminName: "", AdminPassword: ""}` | `KeyId` | action, composed body, `DESTRUCTIVE` |

  - `Action` is each tool's constant (`ACTION` parameter, sent in the port query by `PortQuery`), never a caller value.
  - The vendor validates that `DEACTIVATE`'s `AdminName` and `AdminPassword` are present and never reads them (read in the vendor source), so the port sends them empty, and Task 0 confirms that.
  - `KeyId` is named as in 18.7, because an argument named exactly `Key` matches the credential pattern.
- **The key file is a sixth-case `source` (AD-21).** `EncryptionPort` resolves `root` + `path` through `PathPort` at the mint and again at the write. Each activate tool declares `PathPort`'s `%Admin_FileSystemAccess:USE` as an extra pair. `AdminPort`'s `PATHRESOLVED` guard stays as it is: no caller ever sends `file`.
- **Rules before any vendor call, on both callers.** `root` and `path` are present, and the file is a key file. `AdminName` and `AdminPassword` follow `EncryptionRules` (a listed administrator, a password of at least 3 characters). An activation is refused when every key in the file is already active. A deactivation is refused for a `KeyId` the active list does not hold. A database deactivation is refused for the default key while another key is active, unless Task 0 shows the vendor allows that.
- **Secrets are write-only** (AD-35, AD-36, AD-56). `AdminPassword` is never stored in a proposal, the ledger, screen context, a store or a log line, never queued, and rendered `"<AdminPassword>"` in a copy-out draft. The agent's card carries a masked row for it, so the person types it at confirm. No read answers key material: only `Id`, `KeyLen` and `IsDefault` are read.
- **Self-protection.** No new AD-10 arm. The vendor's own refusals of a key in use are mapped to OcuPilot's sentences: a key a mounted encrypted database uses, a key the journal needs, and a default or journal key while another key is active. Task 0 halts if the vendor deactivates a key a mounted encrypted database uses.
  - DW-2066: `Prohibited.DependsOnKey` (18.7's key-removal arm) also refuses a key the vendor's `%SYS.Journal.System.IsEncKeyInUse` reports in use. It reads that through `EncryptionPort`'s new `JOURNALUSE` type, and a failed read refuses.
- **Error codes** go in `Api/EncryptionError.cls`. `Api/Error.cls` already dispatches `ENCRYPTION.` and gains nothing.
- **Placement.** Security's side bar gains "Database encryption" (9) and "Data element encryption" (10), in the classic menu's order. EXPERIENCE.md is edited in place and keeps **1035** lines.
- **Each test class stands alone** on a fresh stock instance, in any order. It ends with no probe key active, every `Security.System` encryption property as it found it, and no probe file, database or principal left. No test ever leaves a key active.
- **Contended files are edited add-only** (Epic 19 runs on slot A). These are `Kernel/Governance/Baseline.cls`, `Kernel/Proposal/Prohibited.cls` (one-line lists, the dispatch and `DependsOnKey`), `Test/Prohibited.cls`, `Test/ReadTool.cls`, `Screen/Tool/Classification.cls`, `ui/src/app/core/strings.ts`, `ui/tools/strings.test.mjs`, `ui/angular.json` with `ui/tools/angular-json.test.mjs`, and EXPERIENCE.md, whose lines 168, 173, 364 and 490 do not overlap Epic 19's lines 601 and 690.
  - `screens.generated.ts` and `ToolFields.cls` are regenerated, never hand-merged.
  - Not touched: `Screen/Gate.cls`, `Api/Error.cls`, `core/navigation.ts`, `shell/command-box.ts`.
- **`strings.ts` holds each value under one key.** Reuse these keys: `encryptionKeyFileColumnId` ("Key ID"), `encryptionKeyFileColumnKeyLen` ("Key length (bits)", if Task 0 measures bits), `tableColumnDefault`, `encryptionKeyFileAdminName`, `fieldPassword`, `actionCancel`, `pathPickerRootLabel`, `pathPickerFileLabel` and `encryptionKeyFileCredentials`.

**Never:**

- No encrypting or decrypting of an existing database. No encrypted-database create: Story 18.3's create does not offer it, although `POST /database-dir` takes `Encrypted` and `EncryptionKeyID`.
- No `Security.Encryption.Settings` `PUT`, Set Default or Set Journal (Story 18.23). No restart of any instance, and no write to `ocupilot-slot-b`.
- No `%Api.Admin.*` name outside `AdminPort` and its subclasses. No `^EncryptionKey`, `Security.System` or `$SYSTEM.Security.System` write in product code; test-only seeding and cleanup in `%SYS` are allowed.
- No spine or epics.md edit in the implement stage. Task 0 records each AD sentence in `## Spec Change Log` for the runner.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
| --- | --- | --- | --- |
| Read both lists | Stock instance; then a probe key active (real branch) | Screen and `security.databaseencryption.read` / `security.dataelementencryption.read` answer the same rows (`[]`, then the probe key's `Id`, bit length and default flag) | none |
| Activate (database) | Probe key file `act-a.key`, `OcuProbeActAdmin`, the right password, by the dialog and by a confirmed proposal | One `File` `ACTIVATE`; the key is listed; the card states `ENCRYPTION.KEY.ACTIVATE`; read-back `written` (`AdminPassword`) | none |
| Activate refused | Missing file; a text file; a wrong password; every key in the file already active; no `%Admin_FileSystemAccess:USE` | Refused on its field or by name, with nothing activated | `PATH.NOFILE`; 422 `ENCRYPTION.KEYFILE.UNREADABLE`; 422 `ENCRYPTION.KEYFILE.CREDENTIALS`; 400 `TOOL.ARGUMENTS` (all active); 403 `AUTH.NOPRIVILEGE` |
| Deactivate (database) | The typed-name dialog (typed name is the key's `Id`) or a confirmed proposal | One `Key` `DEACTIVATE`; the key leaves the list; read-back gone | none |
| Deactivate refused | A key not active; the default key with another active; a key a mounted encrypted probe database uses | Refused, the key still active, no vendor text sent | 400 `TOOL.ARGUMENTS` (not active, default); 409 `ENCRYPTION.KEY.INUSE` |
| Data element | `act-c.key` (two keys) activated, then each deactivated | `DATAELEMENTLIST` lists both, then neither | as the database rows |
| License | Task 0 finds activation refused on Community | Every success leg runs through the seam; the real leg pins the refusal | 422 `ENCRYPTION.KEY.LICENSE` (only if measured) |
| Password secrecy | Writes carrying a marker password | No log line, ledger row, proposal, store, screen context, DOM after close or answer carries the marker | none |
| DW-2066 (seam) | The seam reports a journal file needed for recovery uses the key being removed from a key file | 18.7's `removekey` is refused on both callers before anything is sent; a failed `JOURNALUSE` read refuses too | 403 `PROHIBITED.OCUPILOTKEY` |
| Side bar | The story lands | Security lists Database encryption 9th and Data element encryption 10th | none |

</intent-contract>

## Code Map

**Vendor** (exported read-only at `/tmp/epic-18-d7/vendor/`; re-export with `GetTextAsString` in `%SYS` if gone; `^EncryptionKey` is object code only):

- `%Api.Admin.Endpoints.Security.Encryption.File`, `RunActivate`. `file` is required and must exist, else 404 `FileDoesNotExist`. `Action` `ActivateDB` → `$$ActivateDB^EncryptionKey(file, AdminName, AdminPassword)` and `ActivateMK` → `$$ActivateMK^`; any other value is 400. It sets no status on a vendor error, so the error arrives as 500. `ValidateRequest` for `ACTIVATE` requires the keys `Action`, `AdminName` and `AdminPassword`. `%Api.Admin.Util.RequestValidator` checks presence and shape, not emptiness.
- `.Key`:
  - `RunList` builds `[{Id, KeyLen, IsDefault}]` from `GetDBEncKeyIDList()`, `GetDBEncKeyLenList()` and `GetDBEncKeyID()`.
  - `RunDataElementList` (type 10) builds `[{Id}]` from `GetMKEncKeyIDList()`.
  - `RunDeactivate` (type 11) requires `id` (400 without it) and maps `Action` `DeactivateDB` / `DeactivateMK` → `$$DeactivateDB^` / `$$DeactivateMK^EncryptionKey(id)`. `AdminName` and `AdminPassword` are validated present and never read.
- `Port/AdminRoutes.cls:153` (`POST /security/encryption/file/activate`) and `:155` (`POST /security/encryption/key/deactivate`).
- `.Database.SysCRUD`: `RunPost` takes `Encrypted` and `EncryptionKeyID` (Task 0's probe database). `RunList` rows carry `Encrypted` and `EncryptionKeyID`.
- `irissys/%SYS/Journal/System.cls:300` `IsEncKeyInUse(id)`, public:
  - with `DBEncJournal` on, it compares the current file's and the new files' keys (`GetJrnEncKeyID(1)`, `(2)`);
  - it then walks the files from the current one back to the oldest `RequiredForRecovery` names, comparing each file's key exactly.
- Classic pages:
  - `irissys/%CSP/UI/Portal/EncryptionDatabase.cls`: Activate form :83, `ActivateKey` :508, `DeactivateKey` :491 (no password asked), `SetDefaultKey` :543 (Story 18.23's), `DrawIDs` :568 (Deactivate is disabled for the default or journal key unless it is the last key, :602-604), empty text :146.
  - `EncryptionManaged.cls`: `$$$MAXNUMMKENCKEYS` :95, `ActivateKey` :223, `DeactivateKey` :279, empty text :88.
  - Both `RESOURCE` `%Admin_Secure`.

**Ports:**

- `Port/EncryptionPort.cls` (601 lines):
  - `Invoke` branches :111-161, `Named` :166, `Source` :184, `Administrators` :194, `Keys` :223, `List` :254, `ReadKeyFile` :281.
  - `CreateFile` :307 is the secret-body model: values held in locals cleared after `Call`.
  - `Values` :465, `Listed` :487, `Mapped` :501, `Violation` :516, `Arguments` :526, `Absent` :532, `Snippet` :551-598.
- `Port/AdminPort.cls`:
  - `TYPESUFFIXES` :126 (has `DATAELEMENTLIST`), `MUTATINGTYPES` :455 (admits `File/ACTIVATE` and `Key/DEACTIVATE`), `BODYLESSTYPES` :471, `UNLOGGEDREFUSALS` :598.
  - `NamesKeyFile` :616.
  - `CONSTANTBODIES` :759; `COMPOSEDTYPES` is a port's own parameter (`LockPort`, `TaskTransferPort`).
  - `PROPERTYFAULTS` :3253: the `@=` form is a request-level refusal (`ECP.DataServer:456:@=ECP.SERVER.LIMIT`).
- `Port/PathPort.cls` `PAIRS` :50, `Resolve` :269.

**Kernel:**

- `Kernel/EntityType.cls:77` `TYPES` (52, last `encryption-key-file`) and its doc lines :59-70.
- `Kernel/EntityRef.cls:59` `IDRULES` (26; the singletons end with `ecp-settings:singleton`); `RULESINGLETONID` `SYSTEM` :147.
- `Kernel/Governance/Baseline.cls`: the Security block :85-138, with `security.encryptionkeyfile*` at :94-98.
- `Kernel/Proposal/Prohibited.cls`:
  - type lists and dispatch: `COVEREDTYPES` :250 (41), the fail-closed type list :1105, the dispatch :1284-1304 (`ReviewedFewOnly` model :1296), `PermittedChangeFields` :871 (license key :903, key file :908);
  - the key arm: `KeyFile` :2477, `DependsOnKey` :2503-2533, `NormalizedKeyId` :2539, `SameKeyId` :2547, `RowNeedsKey` :2561.

**Screen and tools:**

- `Screen/Registry.cls` `READSOURCETYPES` :1987 (`LIST,GET,UPCOMING,HISTORY,VOLUMELIST`, refused otherwise :1162-1164); `ui/tools/screen-mirror.mjs` `READ_SOURCE_TYPES` (message :1234, the `UPCOMING` rules :1297-1307).
- `Screen/Read.cls` admin branch :543-569, which passes the declared type through.
- `Screen/Area.cls:79`: Security.
- Descriptor models: `EncryptionKeyFile.cls` (one page for two descriptors, row actions, `secretArguments`) and `LicenseKey.cls` (singleton entity).
- Tool models:
  - `EncryptionKeyFileWrite.cls`: `PORTCLASS`, `READTYPE`, `READANSWERS`, `EXTRAPAIRS`, `PrivilegePairs`, `MergeUpdate` plus `StateRefusal`, `ScreenActionDelta`, `StateDiff` (masked secret rows), `PortQuery`.
  - `EncryptionKeyFileRemoveKey.cls`: `DESTRUCTIVE`, `CHANGEACTION` `deleted`, `REMOVALROWS`, `ReadBackGone`, `Consequence`.
  - `LicenseKeyActivate.cls`: the singleton id literal in `InputSchema` :73-82. `Write.cls:543-553` defaults `IdArgument` `Name` / `IdParam` `name`.
  - `TaskExportMint.cls` / `EncryptionKeyFileMint.cls`: a mint that checks a file before minting.
- `Kernel/Proposal/Mint.cls:166`: the mint's fresh read carries only the id parameter. `Operation.cls:216-232`: the confirm's and the screen's reads add `PortQuery`.
- `Area/Security/EncryptionRules.cls` (`Problem`, `Violations`, `Fault`); `Api/EncryptionError.cls` (112 lines: `Codes()` :74, `ViolationCodes()` :81, `FieldOf` :87, `ReasonFor` :98, the state refusals :65-71).

**Client** (`ui/src/app/`):

- `areas/security/encryption-key-file.page.ts` is the model:
  - one page for two descriptors :285-300;
  - the picker :96-105 with a page-local `AllowedDirectoriesStore` :307, :336;
  - page-local dialog values :312-321, cleared by `clearDialog` :631;
  - `send` :604 (`handler.sendFor`), `startRemove` :592 (`handler.startFor`), the ChangeBus re-read :326.
  - Its store is `.store.ts`, whose declared reads are at :188-222.
- `shell/screen-outlet.ts` `DESCRIPTOR_PAGES` :145 (18.7 :218-222).
- `shell/screen-action-handler.ts`: `DESTRUCTIVE_ACTIONS` :379, `DESTRUCTIVE_CONSEQUENCES` :407-445, `TYPED_NAME_ROWS` :479-496, `TYPED_VALUES` :503-506, `PUBLISHED_PROBLEMS` :584-610.
- `core/screen-actions.ts` `DESCRIPTOR_ACTION_LABELS` :151-239.
- `core/proposal-view.ts` consequence codes :282-287 and :362-364.
- `app.ts` injections :355-360 and resets :690-692; `app.spec.ts` :1302-1308, :1463-1466.
- `core/strings.ts`: `} as const` :5639. `ui/tools/strings.test.mjs:586` bound 2700, with 2603 used.
- `ui/angular.json:54` `maximumWarning` 2906kB, pinned at `ui/tools/angular-json.test.mjs:506` (history :485-493).

**EXPERIENCE.md** (`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`, 1035 lines):

- :168 Security's side bar ends "· Encryption key files (Stage 2, Story 18.7); tests, details, ...".
- :173 Dialogs, with 18.7's fragment and the destructive list.
- :364 Fixed strings (18.7's clause ends the row).
- :490 delete bodies (18.7's two Remove sentences).

**Rosters** (current counts; re-derive each change from its class's red, never by hand):

- Descriptors and reads:
  - `Test/Descriptor.cls` `ReadShapes` :67-171 (101) and the entity count :1745 (52);
  - `Test/ReadTool.cls` :93 (266), :94, :112;
  - `Test/SurfaceCoverage.cls` :57-196 (screens) and :197-355 (tools);
  - `Test/ScreenRead.cls:215` (11 exemptions; Database encryption joins, because it is empty on a stock instance).
- Governance and dispatch:
  - `Test/Prohibited.cls:232` (41), :438 and :441 (removal tools' exemptions), :480-483;
  - `Test/GovernanceBaseline.cls:15` (32 `DISABLED`);
  - `Test/Governance.cls:47` `ENCRYPTIONDISABLED` (5), also read by `Test/ToolDispatch.cls:173`;
  - `Test/ToolRoundTrip.cls:72` (194);
  - `Test/ToolEmit.cls:235` (the exemption for 18.7's base).
- Drafts and classic pages:
  - `Test/DraftRegistry.cls:75` `REFUSEDDRAFTS` (5);
  - `Test/ClassicPageGate.cls:75` `OWNPAIRS` (54) and `ENCRYPTIONKEYS` :85;
  - `Test/MappingDescriptor.cls:24` (58).
- `Test/ToolWrite.cls`: `AHEADTYPES` :81 (keeps only `Settings/PUT`), the composed-body rule :1324, the other-port count :1339 (stays 13; `EncryptionPort` extends `AdminPort`).
- Security side-bar pins (26 screens each; positions 9 and 10 append): `Test/Wire.cls:599`, `Test/WireSecurityRead.cls` :807, :957, :985, :1093, :1112, `Test/WireOAuthRead.cls` :275, :295, :315, :331, :350. `Test/WireAreaAnyScreen.cls` :289, :297 (8 listed verdicts).
- `Test/EncryptionDescriptor.cls:80` (`Codes()` 9).
- Client:
  - `ui/tools/navigation.test.mjs` :248-277 and :582-586;
  - `shell/area-verdict.spec.ts` :204-227;
  - `ui/tools/screen-mirror.test.mjs` (read-type vocabulary);
  - `ui/tools/proposal-view.test.mjs` :886-894;
  - `ui/tools/self-protection.test.mjs` :674-707 (`ENCRYPTION_SENTENCES`);
  - `ui/tools/side-bar-pins.test.mjs` `SIDE_BAR_SPECS` :32-52.
- CI: `scripts/ci-throwaway.sh` :533-539 (`OCUPILOT_ALLOW_ENCRYPTION_CONFIG`; its comment says the classes "never activate or deactivate a key") and :326-330 (`OCUPILOT_ALLOW_PRINCIPALS`); `ui/tools/ci.test.mjs` :2086-2207.

**Test models:**

- `Test/EncryptionProbe.cls`: `SeedKeyFile` :126, `SeedPrincipal` :218, `RunAs` :346, `PendingRestart` :394, `EncryptionFacts` :421, `Snapshot` :467, `Diff` :551, `Mint` :651, `Confirm` :677.
- `Test/EncryptionSeamPort.cls`: its modes :5-18, :43, :56-90.
- `Test/EncryptionActionFixture.cls` `ToolFor` :13-21; `Test/EncryptionWriteGateProbe.cls`; `Test/EncryptionKeyMatch.cls`; `Test/EncryptionKeyFileWrite.cls` (`TestAKeyTheInstanceDependsOnIsNotRemovedOnEitherCaller`).
- `ui/browser/encryption-key-file.browser-spec.mjs` :81-141 (throwaway guard, `docker exec` probe calls, facts unchanged) and :177-204 (the DW-1337 gate in both themes).

## Tasks & Acceptance

**Task 0, the implement stage's first task, before any descriptor, tool or page.** Run it on `ocupilot-b-ci` only. Load with `/tmp/epic-18-d7/load-throwaway.sh` (rsync, `LoadDir`, `StartPath`; no restart). Keep evidence under `/tmp/epic-18-d7/1822/t0/`. Record each result under Design Notes › Measured at implement, and each AD sentence in `## Spec Change Log` for the runner. After every write step, re-read `EncryptionFacts`, `PendingRestart` with its reasons, the process list and new `messages.log` lines.

1. **Plumbing** (add-only):
   - `EncryptionPort`'s new branches and types (Execution);
   - `Test/EncryptionKeyProbe.cls` (Tests).
2. **S0.** Take `EncryptionProbe.Snapshot` and the audit event count. The plan read nothing active, no pending restart, Community (Measured at plan).
3. **Reads, timed, as `_SYSTEM`:** `Key` `LIST`, `DATAELEMENTLIST` and `Settings` `GET`.
4. **Seed.** Seed key files `act-a.key` (one 256-bit key, K1), `act-b.key` (K2) and `act-c.key` (two keys), and record each `KeyInFile` `LIST` `Id`.
5. **Activation** through `EncryptionPort` (database):
   - a. `act-a` with a wrong password.
   - b. `act-a` with the right password: status, duration, `Key` `LIST`, `Settings` `GET` (`DBEncDefaultKeyID`, `DBEncJournalKeyID`), `GetDBEncKeyID()`, `GetJrnEncKeyID(1)` and `(2)`, and audit events with auditing on. If this is refused for the license or edition, record the code, take the seam branch and skip to step 10.
   - c. `act-a` again.
   - d. `act-b`.
6. **DW-2059.**
   - Create a probe database under `<ManagerDirectory>ocuprobeact/db/`, encrypted with K2 (test-only `SYS.Database.CreateDatabase` plus mount), and read its `Database.SysCRUD` `LIST` row.
   - Compare byte for byte, for K2, `KeyInFile` `LIST` `Id`, `Key` `LIST` `Id` and the row's `EncryptionKeyID`; and for K1, `KeyInFile` `Id`, `Settings` `DBEncDefaultKeyID` / `DBEncJournalKeyID` and `GetJrnEncKeyID(2)`.
7. **DW-2066.** Run `JOURNALUSE` for K1, K2 and an unknown id, as `_SYSTEM` and through `RunAs` as a principal holding exactly `removekey`'s pairs (`%Admin_Secure:USE`, `%Admin_FileSystemAccess:USE`, `%DB_IRISSYS:READ`, `%Admin_Manage:USE`). Record each answer and duration; if refused, retry adding `%DB_IRISSYS:WRITE` or `%Admin_Operate:USE` alone.
8. **Deactivation** (database), with `{Action: "DeactivateDB", AdminName: "", AdminPassword: ""}`:
   - a. K2 while the probe database is mounted.
   - b. K1 (default) while K2 is active.
   - c. An id that is not active, and a body without `AdminName`.
   - d. Dismount and delete the probe database, then deactivate K2, then K1.
9. **Pairs.** Through `RunAs`, as a principal holding exactly Security's two pairs (plus `%Admin_FileSystemAccess:USE` for an activation), run 5b and 8d. Retry each refused step with `%DB_IRISSYS:WRITE`, `%Admin_Manage:USE` or `%Admin_Operate:USE` alone, reading the facts after each refused attempt, and clean up as `_SYSTEM` after each success.
10. **Data element.** Activate `act-c` (`ActivateMK`), then again; deactivate each key (`DeactivateMK`), then an inactive id. Repeat the activation and one deactivation as the step 9 principal.
11. **Restore, then S2:**
    - deactivate every probe key still active (test-only `$$Deactivate*^EncryptionKey` as a fallback);
    - restore `Security.System` `DBEncDefaultKeyID` and `DBEncJournalKeyID` to S0 (test-only `Security.System.Modify`);
    - if `GetDBEncKeyID()` or `GetJrnEncKeyID(1|2)` still names a probe key, try `$SYSTEM.Security.System.SetDBEncKeyDefault` / `SetJrnEncKey` test-only;
    - remove the probe files, the database and the principals, and clear the monitor if it moved.
    - S2 must equal S0 apart from counters and declared log lines.
12. **HALT** with status `blocked`, blocking condition `intent gap: observation contradicts the plan: <what>`, and nothing built past step 1, if any of these hold:
    - a route answers a 500 or 501 that is not the vendor's own, or answers 202;
    - a write half-applies, or answers 2xx having changed nothing;
    - the vendor deactivates a key a mounted encrypted database uses (an AD-10 gap for the orchestrator);
    - any state that no call in step 11 clears. Stop probing at once and record it; the runner clears the throwaway and re-dispatches, and the build takes the seam branch;
    - a write needs a pair beyond its screen's set, `%Admin_FileSystemAccess:USE` and one candidate;
    - `JOURNALUSE` fails for `removekey`'s principal even with one candidate added;
    - one key's spellings differ between the key file and the instance's journal or database answers;
    - a read takes more than 2 s.

    **Not halts:**
    - activation refused on Community: the seam branch, and the real leg pins the refusal, mapped to `ENCRYPTION.KEY.LICENSE`;
    - the vendor deactivating the default key while another key is active: the default pre-check is dropped.
13. **Set from the record:**
    - the branch (real or seam);
    - each tool's pairs;
    - the vendor status and code each mapped refusal arrives as: credentials, in use, default or journal role, already active, license;
    - whether `IsDefault` gates a deactivation;
    - the `KeyLen` unit (bits keeps the reused label; bytes takes the new label "Key length (bytes)");
    - the DW-2059 outcome (Design Notes › Decision 4);
    - the first-activation consequence sentence, from the step 5b readings;
    - each AD-15 / AD-53 named case where step 5b, 8 or 10 found no vendor event.

**Execution (server)** (`src/OcuPilot/`):

- `Port/EncryptionPort.cls` (add-only branches; names no vendor class except the AD-27 case below):
  - **`DATABASEKEYS` / `DATAELEMENTKEYS`**, the tools' fresh read on `Security.Encryption.File` or `Security.Encryption.Key`. They answer `{Keys: <the Key LIST or DATAELEMENTLIST rows>}`, with `root`, `path`, `AdminName` and `KeyId` each `""` so the merge carries the arguments, as `KEYFILE` does.
  - **`File` `ACTIVATE`**:
    - the query's `root`, `path`, `AdminName` and `Action` (only `ActivateDB` or `ActivateMK`; anything else is 400 `TOOL.ARGUMENTS`) and the body's `AdminPassword`;
    - `EncryptionRules`, then `Source`, then `Administrators` (unreadable refusal), then the name listed (else `ENCRYPTION.KEYFILE.CREDENTIALS`), then the file's keys (`Keys`) against the active list: all active is 400 `TOOL.ARGUMENTS` `REASONKEYSALLACTIVE`;
    - then the body `{Action, AdminName, AdminPassword}` and `Call` with `file` set to the resolved path. The password is cleared right after the call.
    - It maps the vendor's answers through `PROPERTYFAULTS` (Task 0's codes).
    - A public `FileKeys(pRoot, pPath, ...)` serves the activate mint the same checks.
  - **`Key` `DEACTIVATE`**:
    - the query's `KeyId` and `Action` (only `DeactivateDB` or `DeactivateMK`);
    - the active list, where a `KeyId` it does not hold is 400 `TOOL.ARGUMENTS` `REASONKEYINACTIVE`;
    - then `{Action, AdminName: "", AdminPassword: ""}` with `id`=`KeyId`.
    - The vendor's in-use and role answers are 409 `ENCRYPTION.KEY.INUSE` and `ENCRYPTION.KEY.ROLE`, and a license refusal is `ENCRYPTION.KEY.LICENSE` if measured.
  - `Parameter COMPOSEDTYPES = "Security.Encryption.Key/DEACTIVATE"`.
  - **`Key` `JOURNALUSE`** (AD-27 named case; the admin API has no read for it):
    - query `id`; `$System.Security.Check("%Admin_Secure","USE")` first;
    - then `%SYS.Journal.System.IsEncKeyInUse(id)` in `%SYS` (AD-16 save and restore);
    - answers `{InUse}`, and a refusal or throw fails the read.
  - **`Snippet`** mirrors both writes as one `rest` step each, with the resolved file and `"<AdminPassword>"` (`AdminPort.RestStep` masks every credential-pattern name). A refusal renders a `comment` step with its sentence.
- `Kernel/Proposal/Prohibited.cls` (add-only):
  - **DW-2066:** `DependsOnKey` adds, after the configured journal key, `JOURNALUSE` through `pPort` for `pKey`. `InUse` answers 1, and a failed read answers 1.
  - Both new types join `COVEREDTYPES` (43), the fail-closed list and the dispatch through `ReviewedFewOnly`. Their reviewed few in `PermittedChangeFields` are `root`, `path`, `AdminName`, `AdminPassword`; `KeyId` names a row and is fingerprinted, as `removekey`'s is.
  - **DW-2059** per Decision 4.
- `Screen/Tool/EncryptionKeyWrite.cls` (new abstract base) on the `EncryptionKeyFileWrite` model:
  - `PORTCLASS` `EncryptionPort`, `SENDSBODY` 0, `READANSWERS` `Keys,root,path,AdminName,KeyId`, `EXTRAPAIRS`, `PrivilegePairs`;
  - `PortQuery` (arguments plus `Action`), the masked `StateDiff`, `StateRefusal` and `InputSchema`, which describes the `SYSTEM` literal, `root` / `path` as 18.7 words them, `AdminName` and `KeyId`.
- Four tools in `Screen/Tool/`, each with `READTYPE` `DATABASEKEYS` or `DATAELEMENTKEYS` and `FINGERPRINTSUBJECT` / `PRECONDITIONFIELD` `Keys`:
  - **`DatabaseKeyActivate.cls`**:
    - `WRITETYPE` `ACTIVATE`, `SECRETBODY` `AdminPassword`, `SCREENACTIONS` `activate`, `SCREENVALUES` `activate=root:path:AdminName`;
    - `EXTRAPAIRS` `%Admin_FileSystemAccess:USE` plus Task 0's, `MintClass` `EncryptionKeyActivateMint`, `Consequence` `ENCRYPTION.KEY.ACTIVATE`.
  - **`DatabaseKeyDeactivate.cls`**:
    - `WRITETYPE` `DEACTIVATE`, `SCREENACTIONS` `deactivate`, `SCREENVALUES` `deactivate=KeyId`, `FINGERPRINTSUBJECT` `Keys,KeyId`;
    - `DESTRUCTIVE` 1, `CHANGEACTION` `deleted`, `REMOVALROWS` `KeyId`, `ReadBackGone`, `Consequence` `ENCRYPTION.KEY.DEACTIVATE`;
    - `StateRefusal`: not active, `REASONKEYINACTIVE`; default with another key listed, `REASONKEYDEFAULT` (per Task 0).
  - **`DataElementKeyActivate.cls`** and **`DataElementKeyDeactivate.cls`**: the same shapes on the data-element descriptor, with `ActivateMK` / `DeactivateMK`, no default rule, and `Consequence` `ENCRYPTION.KEY.ACTIVATEDATAELEMENT` / `.DEACTIVATEDATAELEMENT`.
- `Screen/Tool/EncryptionKeyActivateMint.cls` (new, the `TaskExportMint` model):
  - before minting, `EncryptionPort.FileKeys` refuses a missing or unreadable file and a file whose keys are all active;
  - it adds the card row `FileKeys` (before `""`, after the file's key ids).
- `Screen/Descriptor/DatabaseEncryption.cls` and `DataElementEncryption.cls` (new), as in Boundaries:
  - table columns: Key ID (`name`), Key length (bits) (`number`), Default (`boolean`); and Key ID alone;
  - empty states "No database encryption key is active." and "No data element encryption key is active.";
  - context fields as the reads, prompts in group `userPromptGroupAccess`;
  - `commandAliases` "database encryption", "activate database key"; "data element encryption".
- `Screen/Registry.cls` and `ui/tools/screen-mirror.mjs` (add-only): `DATAELEMENTLIST` joins the read-source types under `UPCOMING`'s rules (admin only, no `forEach`, no `rowGet`).
- `Kernel/EntityType.cls` (two types with doc lines); `Kernel/EntityRef.cls` (`database-encryption-keys:singleton,data-element-encryption-keys:singleton`).
- `Kernel/Governance/Baseline.cls` (add-only, name order, Security block): the four keys `false`.
- `Screen/Tool/Classification.cls`: the two activate tools, `fieldList` `Security.Encryption.File`, `authored` `AdminPassword: secret`. Then regenerate `ToolFields.cls` (`cd ui && node tools/field-lists.mjs`).
- `Port/AdminPort.cls`: `PROPERTYFAULTS` gains Task 0's `Security.Encryption.File` credentials codes (to `ENCRYPTION.KEYFILE.CREDENTIALS` on `AdminPassword`) and `Security.Encryption.Key` in-use / role codes (`@=`). `UNLOGGEDREFUSALS` gains nothing unless Task 0 measures a status no internal failure shares.
- `Api/EncryptionError.cls` (add-only), codes and sentences:
  - `ENCRYPTION.KEY.INUSE` (409): "A mounted encrypted database, or a journal file the instance still needs, uses this key, so it stays active."
  - `ENCRYPTION.KEY.ROLE` (409): "This key is the default key for new encrypted databases or the key for encrypted journal files. Make another active key the default and the journal key first."
  - `ENCRYPTION.KEY.LICENSE` (422 on the request, as `ECP.LICENSE` is; only if measured): "This instance's license does not allow activating encryption keys."
  - `ENCRYPTION.KEY.ACTIVATE` (consequence): "The keys in this key file become active until they are deactivated or the instance restarts. If no database key was active, the first one also becomes the default key for new encrypted databases and the key for encrypted journal files, and that setting is kept." Task 0's 5b words the second sentence as measured.
  - `ENCRYPTION.KEY.DEACTIVATE` (consequence): "An encrypted database that needs this key cannot be mounted until the key is activated again from a key file."
  - `ENCRYPTION.KEY.ACTIVATEDATAELEMENT` (consequence): "The keys in this key file become available to applications that encrypt data elements, until they are deactivated or the instance restarts."
  - `ENCRYPTION.KEY.DEACTIVATEDATAELEMENT` (consequence): "Data encrypted with this key cannot be read or written until the key is activated again from a key file."
  - State refusals, parameters answered 400 `TOOL.ARGUMENTS`: `REASONKEYINACTIVE` "This key is not active.", `REASONKEYSALLACTIVE` "Every key in this key file is already active.", `REASONKEYDEFAULT` "This is the default key for new encrypted databases while another key is active. Make another active key the default first."
- `Test/AdminInventory.cls` (doc only, Decision 6): `mutating` is AD-3's definition, the four HTTP write runners. Request types a class's own `Run` dispatches, such as `Security.Encryption.Key` `DEACTIVATE`, are admitted by `AdminPort.MUTATINGTYPES` and pinned by `Test/PortFixture`.

**Execution (client)** (`ui/src/app/`):

- `areas/security/encryption-keys.page.ts` and `.store.ts` (new, with specs), registered in `DESCRIPTOR_PAGES` for both descriptors. The page draws the screen's table and its empty state.
  - **Activate key** opens an `app-dialog`:
    - fields: a `server-path-picker` (`kind` `file`, page-local `AllowedDirectoriesStore`), Administrator name (default the signed-in user) and a masked Password;
    - each value is page-local and cleared on close and after success, never in the store;
    - it posts through `handler.sendFor` and shows refusals on their fields.
  - **Deactivate** goes through `handler.startFor` (the typed-name dialog; typed name `Id`).
  - A change event of the screen's entity type re-reads.
- `shell/screen-action-handler.ts` (add-only):
  - `DESTRUCTIVE_ACTIONS` gains `deactivate`;
  - `DESTRUCTIVE_CONSEQUENCES`, `TYPED_NAME_ROWS` (`Id`), `TYPED_VALUES` (`deactivate: 'KeyId'`), and `PUBLISHED_PROBLEMS` the three state refusals.
- `core/screen-actions.ts` labels: Activate key, Deactivate. `core/proposal-view.ts`: the four consequence codes. `app.ts`: the store's injection and sign-out reset, pinned in `app.spec.ts`.
- `core/strings.ts` (add-only), each new key under its `/** EXPERIENCE.md:n */` line. If the literal count passes 2700, raise `ui/tools/strings.test.mjs:586`'s bound to the next hundred. Regenerate `core/screens.generated.ts` (`cd ui && node tools/screen-mirror.mjs`).
- `ui/angular.json`: re-base `maximumWarning` under DW-1166 to the measured total rounded up to the next kB, with its history row. Stop and ask above 3800kB.
- **EXPERIENCE.md, in place, keeping 1035 lines**, then run `cd ui && npm run test:tools`:
  - :168 gains "· Database encryption (Stage 2, Story 18.22) · Data element encryption (Stage 2, Story 18.22)";
  - :173 gains "activate an encryption key from a key file (Story 18.22: a key file location, an administrator name and a masked password, each value page-local and cleared on close)", and the destructive list gains "database encryption key · data element encryption key";
  - :364 gains "; and Database encryption and Data element encryption (Story 18.22): ..." with every new literal, tagged `[ADDED <date> - Story 18.22]`;
  - :490 gains the two Deactivate bodies, each its deactivate consequence sentence, whose typed name is the key identifier.

**Rosters and CI:**

- Extend every roster in Code Map › Rosters. The Security pins grow by two.
- `Test/ScreenRead.cls` exempts `DatabaseEncryption`.
- `Test/ToolWrite.cls` `AHEADTYPES` drops `File/ACTIVATE` and `Key/DEACTIVATE`.
- `scripts/ci-throwaway.sh`: the new armed classes join `OCUPILOT_ALLOW_ENCRYPTION_CONFIG`'s `# classes:` line, whose comment is corrected to say the classes activate and deactivate probe keys and restore them. The gate class joins `OCUPILOT_ALLOW_PRINCIPALS`.

**Tests:**

- `Test/EncryptionKeyProbe.cls` (new; `EncryptionProbe`'s shape, prefix `OCUPROBEACT`):
  - `SeedDirectory`, `SeedKeyFile`, `SeedEncryptedDatabase` / `RemoveDatabase`;
  - `ActiveProbeKeys`, `Restore` (step 11's test-only cleanup), `SeedPrincipal`, `RemoveAll`;
  - delegating `EncryptionFacts`, `Snapshot`, `Diff` and `RunAs` to `EncryptionProbe`.
- `Test/EncryptionSeamPort.cls` (add-only modes):
  - `journalfiles`: `JOURNALUSE` answers `InUse` 1 for the armed key.
  - On the seam branch only: `activation`, where both writes and both fresh reads answer from a seam-held active list without the vendor; and `inuse` / `role`, where `DEACTIVATE` answers the mapped refusal.
  - Seam tool subclasses `SeamDatabaseKeyActivate` (and the other three) plus `EncryptionActionFixture.ToolFor` follow.
- `Test/EncryptionKeyRead.cls`: both screens' reads equal their tools' reads (`[]`, then a probe key on the real branch); no key material in any answer.
- `Test/EncryptionKeyWrite.cls` (`OCUPILOT_ALLOW_ENCRYPTION_CONFIG`):
  - the matrix's activate, deactivate and data-element rows on both callers, real or seam per Task 0, with the read-backs;
  - the refusals with zero vendor writes, and the mounted-database refusal (real branch: a probe database encrypted with a probe key);
  - the marker password's absence everywhere, and the facts restored after each test.
- `Test/EncryptionKeyGate.cls` with `EncryptionWriteGateProbe` (`OCUPILOT_ALLOW_PRINCIPALS`, `OCUPILOT_ALLOW_ENCRYPTION_CONFIG`): each tool's and each read's declared pairs are refused by name with zero port calls, and exactly the declared pairs write.
- `Test/EncryptionKeyDescriptor.cls`: the two descriptors, `EncryptionError`'s new codes and sentences, the four baseline keys `false`, `Snippet`'s branches (placeholders, the `comment` refusal), and `DATAELEMENTLIST` admitted as a read type.
- `Test/EncryptionKeyFileWrite.cls` (add-only): a `journalfiles` leg and a failed-`JOURNALUSE` leg in `TestAKeyTheInstanceDependsOnIsNotRemovedOnEitherCaller` (DW-2066).
- `Test/EncryptionKeyMatch.cls` (add-only): the measured real spellings (DW-2059).
- Component specs: the page and store (reads, the dialog's page-local secret cleared on close and after success, typed-name deactivate, refusals on fields).
- `ui/browser/encryption-keys.browser-spec.mjs` (new; refuses a non-throwaway, joins `SIDE_BAR_SPECS`):
  - Security entries 9 and 10 through `sideBarLabels`; both pages and the Activate dialog, with no password in the DOM after close;
  - on the real branch, activate a probe key file through the dialog, see it listed and deactivate it through the typed-name dialog;
  - the DW-1337 gate in both themes on each page and the dialog; cleanup asserts the facts as found.

**Acceptance Criteria:**

- **B0:** Given `ocupilot-b-ci`, when the implement stage starts, then Task 0 records activation, deactivation, pairs, audit events, the key-id spellings and `JOURNALUSE` before any UI exists. It picks the real or seam branch, and S2 equals S0 apart from declared differences; a contradiction halts the story.
- **B1:** Given the two screens and their read tools, when each reads, then screen and tool answer the same active keys, and no answer, DOM, screen context or tool result carries key material.
- **B2:** Given a key file at an allowed location, when a person activates it through the dialog or the agent's proposal is confirmed with the password typed on the card, then one `File` `ACTIVATE` round-trips through the admin API with its consequence stated. On the seam branch, the success legs pin the seam's recorded call and the real legs pin the refusal. A missing or unreadable file, a wrong password, an all-active file or a missing pair is refused with nothing activated.
- **B3:** Given an active key, when a person deactivates it through the typed-name dialog or a proposal is confirmed, then one `Key` `DEACTIVATE` round-trips and the key leaves the list. A key not active, the default key while another is active (per Task 0), and a key a mounted encrypted database uses are refused with the key still active.
- **B4:** Given a key file, when its keys are activated for data element encryption and each is deactivated, by either caller, then `DATAELEMENTLIST` shows the change after the change event.
- **B5:** Given any password entered, when any write runs or fails, then it is returned by no read and found in no log line, ledger row, proposal, store, screen context, answer or DOM after the dialog closes.
- **B6 (DW-2059):** Given a key OcuPilot's own database depends on, its id spelled as Task 0 measured the instance's database and journal answers, when either caller removes it from a key file, then the removal is refused `PROHIBITED.OCUPILOTKEY` with nothing sent, while a key no protected database uses is removed (`EncryptionKeyFileWrite` through the seam, and `EncryptionKeyMatch` over every measured spelling).
- **B7 (DW-2066):** Given a key that a journal file needed for recovery uses (seam), or a `JOURNALUSE` read that fails, when the key is removed from a key file by either caller, then the removal is refused `PROHIBITED.OCUPILOTKEY` with nothing sent.
- **B8:** Given the rosters, when the story lands, then:
  - Database encryption and Data element encryption are Security's 9th and 10th entries, with three prompts each;
  - the four keys are in the baseline disabled, and every roster includes the screens and tools;
  - the DW-1337 gate holds in both themes, and EXPERIENCE.md reads 1035 lines.

## Spec Change Log

- 2026-10-05, spec gate (runner): Decisions 1 to 7 confirmed. Spine amendments 1 to 4 written (AD-13, AD-36, AD-51 with AD-44, AD-27 with AD-10's key arm); AD-8 (item 5) and AD-15/AD-53 (item 6) wait for Task 0's record. Item 7 corrected at origin (`spec-18-7-encryption.md` :379, `epic-18-context.md` :76). Named limit 3 routed as DW-2085.

## Review Triage Log

## Design Notes

**Governing ADs:**

- AD-2, AD-27, AD-52: `EncryptionPort` extends `AdminPort`. Its one vendor-class call is `JOURNALUSE`'s, a new AD-27 named case.
- AD-26: nothing queues.
- AD-3, AD-51, AD-56 (i): no encryption endpoint publishes a template, so the tools are action-style; the activations carry a secret body and the deactivations a composed one.
- AD-4: no subject.
- AD-5, AD-36, AD-44: one descriptor per screen, one page for two descriptors, the `DATAELEMENTLIST` read type, and each descriptor's classic page.
- AD-6, AD-34, AD-40, AD-53, AD-55: two callers of each tool; the closed confirm channel over `AdminPassword`.
- AD-8, AD-29: the screens' pairs and each tool's measured pairs.
- AD-10: the key arm widened for DW-2066, and no new arm for deactivation. AD-13, AD-14: two singleton types and their change events.
- AD-15, AD-53: vendor events, or named cases per Task 0. AD-21: the key file as a sixth-case `source`. AD-22: four keys `false`.
- AD-24, AD-35, AD-48: no secret returned or logged. AD-39: OcuPilot's own sentences. AD-58: read-backs. AD-59: `Snippet`.

**Measured at plan** (read-only on `ocupilot-b-ci`, 2026-10-05 about 04:45 UTC; nothing written):

- `EncryptionProbe.EncryptionFacts()`: every `Security.System` encryption property empty or 0; no active database or data-element key; `GetJrnEncKeyID(1)` and `(2)` empty; no encrypted database; `PendingRestart` 0.
- The license is "InterSystems IRIS Community", 2026.2 build 221U. The throwaway carries `OCUPILOT_ALLOW_ENCRYPTION_CONFIG=1`.
- Endpoint classes declaring their own request types were queried over `%Dictionary.CompiledParameter`. `Database.Actions`, `Journal.File`, `Security.Audit.Record` and `Security.Encryption.Key` dispatch write types through their own `Run` and read `mutating="0"` in the inventory.
- Read in the vendor docs (inference until Task 0): the first database activation persistently sets the default and the journal key; a default or journal key cannot be deactivated while another key is active; an activation activates every key in the file; up to 256 data-element keys.

**Decisions** (applied in this plan; the runner confirms them at the spec gate):

1. **Each list's tools target one singleton per screen** (`database-encryption-keys`, `data-element-encryption-keys`, id `SYSTEM`). The vendor keeps one set of active keys per kind. The tool's target type is its descriptor's entity type (`Mint.cls:154`), so an activation (named by a key file) and a deactivation (named by a key) share one target. That serializes every change to the set under AD-34's lock, and one change event re-reads the screen.
2. **Database deactivation pre-checks the default key** while another key is active, as the classic page draws it disabled. That keeps a vendor refusal from being logged at severity 2. In-use refusals cannot be pre-checked without `%Admin_Manage:USE` (the database list's pair), so they reach the vendor and are logged (Named limit 1).
3. **DW-2066 is real by construction (inference).** `DBEncJournalKeyID` names the key for new journal files, while older files still needed for recovery keep their own key. So `DependsOnKey` asks the vendor's own check, which walks exactly those files. No instance here encrypts its journal, so the arm is pinned through the seam.
4. **DW-2059.** If every measured spelling of one key is byte-identical and holds only hex digits, `-`, `{` and `}`, the normalized comparison is confirmed: there is no code change, and the measured spelling joins `EncryptionKeyMatch`. If a spelling holds any other character, `NormalizedKeyId` narrows to upper-casing and dropping only `-`, `{` and `}`. Differing spellings halt (step 12), because `IsEncKeyInUse` compares exactly.
5. **Success legs are real unless Task 0 rules them out**, so B2 to B4 round-trip through the admin API. The seam branch is taken only for a license refusal, or after a restart-only leftover.
6. **The inventory's `Key` row is not changed.** Its `mutating` column is AD-3's definition (the class itself defines `RunPut`, `RunPost`, `RunDelete` or `RunPatch`), which Story 2.2's criterion (epics.md :1849) pins with the count sixteen. `Database.Actions`, `Journal.File` and `Security.Audit.Record` write through their own `Run` with `mutating="0"` too. So the wrong claim is "the row misses `DEACTIVATE`": the inventory's doc comment gains the sentence (Execution), and the runner corrects the claim where it was made (Spine amendments, item 7).
7. **The deactivations take the destructive treatment, and the activations do not.** An activation is undone by a deactivation. A deactivation can leave a database unmountable until a key file is found.

**Named limits:**

1. A key in use by a mounted database or the journal, and a wrong activation password, are vendor 500s. They stay logged until the burn-down's code-scoped unlogged grammar (DW-2007) can name their codes.
2. On the seam branch, B1's equality is shown only for an empty list. The screens read through `AdminPort`, which the seam does not reach.
3. Creating an encrypted database is reachable (`POST /database-dir`) but out of this story's criteria (Never). Routed at the spec gate to Epic 18's burn-down as DW-2085.

**Proposed spine amendments (Rule 20).** The runner writes 1 to 5 at the spec gate; Task 0 confirms each `<measured>`, and the implement stage records 6 in `## Spec Change Log`.

1. **AD-13:** "**`database-encryption-keys` and `data-element-encryption-keys` are singletons**, each the instance's set of active keys of its kind (Story 18.22) [AMENDED <date>, Story 18.22 spec gate, Rule 20]."
2. **AD-36:** "`Security.Encryption.Key` `DATAELEMENTLIST` is a further list-shaped type, on an admin source only (Data element encryption, Story 18.22) [AMENDED ...]."
3. **AD-51:** "Story 18.22's case: `EncryptionPort`, which builds `Security.Encryption.File` `ACTIVATE`'s body from the activate tools' declared `AdminName`, their constant `Action` and their secret `AdminPassword` over the resolved key file, and composes `Key` `DEACTIVATE`'s `{Action, AdminName: "", AdminPassword: ""}` (`COMPOSEDTYPES`); it answers their fresh read through port-composed `DATABASEKEYS` and `DATAELEMENTKEYS` types [AMENDED ...]." **AD-44:** "**Story 18.22's tools declare no `CLASSICPAGES`**: `%CSP.UI.Portal.EncryptionDatabase` and `.EncryptionManaged` perform them [AMENDED ...]."
4. **AD-27, a named case:** "**Story 18.22's case, the journal's use of a key**: the admin API has no read for whether a journal file still needed for recovery uses a key, so `EncryptionPort`'s `JOURNALUSE` repeats `%Admin_Secure:USE` and calls `%SYS.Journal.System.IsEncKeyInUse` in `%SYS` [AMENDED ...]." **AD-10's key arm** reads, after "or the journal": "or a journal file the instance still needs for recovery (the vendor's `IsEncKeyInUse`, Story 18.22, DW-2066)".
5. **AD-8:** "**Story 18.22's encryption keys** declare Security's set; the activations also declare `PathPort`'s `%Admin_FileSystemAccess:USE` <and measured>, the deactivations <measured>, each refused by name before any port call (measured on `ocupilot-b-ci`)."
6. **AD-15 (sixteenth) and AD-53 (eighteenth)**, only where Task 0 finds no vendor event for an activation or a deactivation. **AD-2**, only if Task 0 adds an `UNLOGGEDREFUSALS` entry.
7. **Correct at origin (not the spine):** the runner replaces "the inventory's `Key` `mutating="0"` misses `DEACTIVATE`" in `epic-18-context.md` and in `spec-18-7-encryption.md`'s Design Notes with Decision 6's sentence.

**Integration ACs.** New: `EncryptionPort`'s four types and two write branches, `EncryptionKeyWrite`, `EncryptionKeyActivateMint`, the page and store.

- The page consumes both declared reads, and the dialog and row action consume `POST /screens/:screen/action`, against `ocupilot-b-ci` (B1 to B4; `EncryptionKeyRead`, `EncryptionKeyWrite`, the browser spec).
- `Prohibited.DependsOnKey` consumes `JOURNALUSE` on 18.7's `removekey` path (B7; `EncryptionKeyFileWrite`).

**Consumes:**

- 18.7: `EncryptionPort`, key files, `EncryptionRules`, `EncryptionError`, the probe and the seam;
- 18.1: `PathPort` and its picker;
- 18.6: the secret-body and singleton models;
- 16.17's read-back, 14.1's `Snippet`, 14.2's baseline.

**Consumed-by:**

- 18.23: its startup settings are reached from Database encryption, and it sets the default and journal keys among the active keys;
- 18.12: the agent's grown tool set.

**Ledger inbox (Rule 17):** DW-2059 is addressed by Task 0 step 6, Decision 4 and B6. DW-2066 is addressed by Task 0 step 7, Decision 3, the `DependsOnKey` task and B7.

**Footprint (Rule 11).** Contended files are edited add-only (Boundaries). New or outside the listed set, for `footprint_extensions`:

- `Port/EncryptionPort.cls`, `Port/AdminPort.cls` (`PROPERTYFAULTS`), `Api/EncryptionError.cls`;
- `Screen/Registry.cls`, `ui/tools/screen-mirror.mjs`;
- `Kernel/EntityType.cls`, `Kernel/EntityRef.cls`;
- `Test/AdminInventory.cls` (doc only), `Test/ScreenRead.cls`, `scripts/ci-throwaway.sh`;
- the new classes, page, store and spec.

**Size.** Two descriptors sharing one page, four write tools on an existing port, one mint class, a port extension of four types and two write branches, and one DW-2066 kernel line. About Story 18.21's size (inference).

## Verification

**Setup (slot B):**

- Load with `/tmp/epic-18-d7/load-throwaway.sh`, with no restart, never through the MCP loader. Every write lands on `ocupilot-b-ci`, on `OCUPROBEACT` files, the probe database and principals, and restored encryption facts.
- Run one test class per call, and send the next only once the previous has landed in `%UnitTest_Result`. Never re-submit after a client-side timeout. The container already carries `OCUPILOT_ALLOW_ENCRYPTION_CONFIG=1` and `OCUPILOT_ALLOW_PRINCIPALS=1`.
- Before any browser run: `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci` exported.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one at a time. Expected: 0 failures, with totals checked against `%UnitTest_Result`.
  - The story's classes: `EncryptionKeyRead`, `EncryptionKeyWrite`, `EncryptionKeyGate`, `EncryptionKeyDescriptor`, `EncryptionKeyFileWrite`, `EncryptionKeyMatch`.
  - The rosters: `Descriptor`, `ReadTool`, `SurfaceCoverage`, `ScreenRead`, `Prohibited`, `GovernanceBaseline`, `Governance`, `ToolDispatch`, `ToolRoundTrip`, `ToolEmit`, `ToolWrite`, `DraftRegistry`, `ClassicPageGate`, `MappingDescriptor`, `Wire`, `WireSecurityRead`, `WireOAuthRead`, `WireAreaAnyScreen`, `EntityRef`, `EncryptionDescriptor`, `Inventory`.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/encryption-keys.browser-spec.mjs browser/encryption-key-file.browser-spec.mjs browser/security.browser-spec.mjs`. Expected: pass.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`, then `uv run scripts/check-objectscript.py <changed .cls>` and `bash scripts/lint-docs.sh`. Expected: clean, with `wc -l` on EXPERIENCE.md reading 1035.
- `(once, before dev_complete)`, each green with a non-zero count:
  1. the full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci`, one class at a time;
  2. `cd ui && npm test && npm run build`;
  3. `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`;
  4. afterwards no `OCUPROBEACT` file, database or principal remains, and every encryption fact reads as at S0.
- `(CI)` The full browser suite runs in CI's three `browser-shard` jobs (Rule 29).

**Planned pinning mutations (Rule 19).** Apply each on the throwaway, observe red, revert byte-identical, and record a `mutation:` line here:

- B1: the Database encryption read declares `GET` instead of `LIST` → `EncryptionKeyRead`'s equality leg red. `DATAELEMENTLIST` dropped from `READSOURCETYPES` → `EncryptionKeyDescriptor` red.
- B2: `EncryptionPort`'s activation sends the caller's `path` unresolved → the write's location leg red. The all-active check dropped → its refusal leg red, with an `ACTIVATE` recorded.
- B3: `DatabaseKeyDeactivate.StateRefusal` admits an inactive key → the not-active leg red, with a `DEACTIVATE` sent. The in-use mapping dropped → the mounted-database leg red, with vendor text or an `INTERNAL` code.
- B4: `DataElementKeyActivate` `ACTION` set to `ActivateDB` → the data-element leg red.
- B5: `EncryptionPort`'s activation logs its body → the marker leg red.
- B6: `NormalizedKeyId` back to an exact comparison, with the seam naming the key in its measured spelling → `EncryptionKeyMatch` and `EncryptionKeyFileWrite`'s protected leg red.
- B7: `DependsOnKey`'s `JOURNALUSE` step removed → the `journalfiles` leg red on both callers; its failed read answering 0 → the failed-read leg red.
- B8: `security.databaseencryption.deactivate` dropped from `Baseline` → `GovernanceBaseline` red. `DataElementEncryption` `sideBarPosition` 0 → `Wire` and `navigation.test.mjs` red. The dialog's password clear dropped (rebuilt, redeployed) → the page spec and the browser spec red.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

- Planned only (halt after planning). Read-only probes of `ocupilot-b-ci` and the vendor exports at `/tmp/epic-18-d7/vendor/`; nothing written to any instance. The plan stage wrote `/tmp/epic-18-d7/load-throwaway.sh` (the throwaway loader, since `/tmp/epic-18-d6/` is gone); it has not been run.
