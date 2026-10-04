---
title: 'Story 18.7: Encryption'
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

**Problem:** The classic portal is still the only place to manage encryption: its four Encryption pages (`%CSP.UI.Portal.EncryptionCreate`, `.EncryptionManage`, `.EncryptionDatabase`, `.EncryptionManaged`) create and manage key files, activate and deactivate database and data-element keys, and set the database-encryption startup options. The admin API carries all of it through five endpoint classes (`Security.Encryption.File`, `.AdminInFile`, `.KeyInFile`, `.Key`, `.Settings`, 13 routes). The story's ledger inbox adds DW-1555 (RSA and symmetric-key wallet secrets, which Story 8.6 shows read-only) and DW-1774 (area side bars pinned as literal lists in browser specs).

**Approach:** Story 18.7 is Part A of a four-part split the orchestrator approved at the spec gate on 2026-10-04: **Encryption key files**, with DW-1774 and a Task 0 that establishes the reachable subset of all 13 routes before any UI. Database and data-element key activation is Story 18.22, the encryption startup settings Story 18.23, and RSA and symmetric-key wallet secrets (DW-1555) Story 18.24; their outlines are kept in this spec at commit `0a3dfe43`. Every instance here runs a Community license; nothing in this story activates a key, changes an encryption setting or needs a restart.

## Boundaries & Constraints

**Always (Part A):**

- **Task 0 runs first, on `ocupilot-b-ci` only**, before any descriptor, tool or page (Tasks › Task 0). Probe objects use the prefix `OCUPROBE187` (key files under the probe directory `<ManagerDirectory>ocuprobe187/`, principals `OcuProbe187*`). It restores what it changes, ends with S2 equal to S0 and halts on any contradiction.
- **Key files only.** Part A writes key files under a probe directory and reads them. It never activates or deactivates a key, never sends a `Security.Encryption.Settings` `PUT` past the vendor's own body validation, never touches a database, the journal, the audit database, OcuPilot's own databases or IRISSYS, and never restarts an instance.
- **Screens** (Security and secrets; each carries three prompts; privileges `%Admin_Secure:USE`, `%Admin_FileSystemAccess:USE`, `%DB_IRISSYS:READ` in that order, with `%Admin_FileSystemAccess:USE` as the own pair, because every read and write names a key file through `PathPort`):

  | Descriptor | Route | Archetype | Pos | Entity type, id | `classicPage` | `toolIdentifier` |
  | --- | --- | --- | --- | --- | --- | --- |
  | `EncryptionKeyFile` | `security/encryption-key-file` | `list (server criteria)` | 8 | `encryption-key-file`, `none` | `%CSP.UI.Portal.EncryptionManage` | `security.encryptionkeyfile` |
  | `EncryptionKeyFileAdminList` | `security/encryption-key-file/administrators` | `list (server criteria)` | 0 | `encryption-key-file`, `none` | `%CSP.UI.Portal.EncryptionManage` | `security.encryptionkeyfileadmins` |
  | `EncryptionKeyFileForm` | `security/encryption-key-file/create` | `form-page` | 0 | `encryption-key-file` | `%CSP.UI.Portal.EncryptionCreate` | none (no read) |

  - `EncryptionKeyFile` reads `{"port":"encryption","endpoint":"Security.Encryption.KeyInFile","type":"LIST"}` over `Id`, `KeyLen`, `Description`; `EncryptionKeyFileAdminList` reads `{"port":"encryption","endpoint":"Security.Encryption.AdminInFile","type":"LIST"}` over `Name`. Both declare the criteria `root` (`text`, `maxLength` 1024, `hint` "An allowed directory exactly as the Allowed directories screen lists it.") and `path` (`text`, `maxLength` 807, `hint` "The key file's name under that directory, up to eight /-separated parts."). One page serves both and issues both reads (AD-5).
  - **Every key-file tool targets the key file**: entity type `encryption-key-file`, scope `instance`, id the AD-13 composite of `root` and `path` as sent (kept exactly; no `IDRULES` entry), the mapping tools' composite model (Story 18.14).
- **Tools** (on `Port/EncryptionPort`; action-style with port-built bodies, AD-51 and AD-56 (i); fresh read the port-composed `KEYFILE` type; every governance key `false`):

  | Tool | Vendor call | Arguments; secrets | Kind |
  | --- | --- | --- | --- |
  | `security.encryptionkeyfile.create` | `File` `POST` | `root`, `path`, `AdminName`, `KeyLen`, `Description`; `AdminPassword` | create (AD-54) |
  | `security.encryptionkeyfileadmins.addadministrator` | `AdminInFile` `POST` | `OldAdminName`, `NewAdminName`; `OldAdminPassword`, `NewAdminPassword` | action |
  | `security.encryptionkeyfileadmins.removeadministrator` | `AdminInFile` `DELETE` | `Admin` | action, `DESTRUCTIVE` |
  | `security.encryptionkeyfile.addkey` | `KeyInFile` `POST` | `AdminName`, `KeyLen`, `Description`; `AdminPassword` | action |
  | `security.encryptionkeyfile.removekey` | `KeyInFile` `DELETE` | `KeyId` (sent as the vendor's `key`; an argument named exactly `Key` would match Conventions › Secrets' credential pattern and be redacted) | action, `DESTRUCTIVE` |

- **The key file is a sixth-case location (AD-21).** The create resolves `root` + `path` through `PathPort` as a `file` that never overwrites (`PATH.EXISTS`) and refuses a directory that does not exist (`ENCRYPTION.KEYFILE.DIRECTORY`) before any vendor call, because the vendor otherwise creates the directory chain. Every other key-file call resolves it as a `source`. The port re-resolves at the write. `AdminPort` refuses a caller's `file` query or `File` / `DBEncStartKeyFile` body value on any `Security.Encryption.*` call unless it arrives through `EncryptionPort` (`PATH.NAME`, no vendor call), closing today's generic admission of `AdminInFile` and `KeyInFile` `LIST`.
- **Rules before any vendor call, on both callers:** `KeyLen` 128, 192 or 256; administrator names non-empty and at most the length Task 0 measures (the classic pages cap them at 50); passwords non-empty; `NewAdminName` not already listed; `Admin` and `KeyId` listed; the last administrator never removed.
- **Secrets are write-only** (AD-35, AD-36, AD-56): `AdminPassword`, `OldAdminPassword` and `NewAdminPassword` are declared in the descriptors' `secretArguments`, never stored in a proposal, the ledger, screen context, a store or a log line, never queued (no encryption type queues), and rendered as `"<Name>"` in a copy-out draft. Key material never leaves the instance: the vendor generates every key, and only `Id`, `KeyLen` and `Description` are read.
- **Self-protection (AD-10):** `removekey` is refused `PROHIBITED.OCUPILOTKEY`, from either caller, when the key is the encryption key of OcuPilot's own database, the install namespace's globals or routines database, one of the seven protected databases (Prohibited's `OwnDatabaseNames`), or the instance's journal encryption key (`Settings` `DBEncJournalKeyID`), read at the write; a read that fails refuses.
- **Placement:** Security's side bar gains "Encryption key files" at position 8 (after Allowed directories at 7). EXPERIENCE.md is edited in place and keeps **1019** lines (measured; the dispatch's 1006 is stale).
- **Error codes** go in `Api/EncryptionError.cls`; `Api/Error.cls` (at 989 of the compiler's 1,000 parameters) gains only its two `ENCRYPTION.` dispatch lines. The prohibited code and its sentence live in `Kernel/Proposal/Prohibited.cls`.
- **DW-1774:** every browser spec that reads `ocu-side-bar-label` takes an area's listed labels from one helper, `ui/browser/side-bar-spec.mjs`, derived from the screen mirror; `ui/tools/navigation.test.mjs` keeps the one literal per area; a tool test fails on a spec that pins an entry count.
- **Each test class stands alone** on a fresh stock instance, in any order: it creates and removes its own probe directory, key files and principals, and asserts no key is activated and no `Security.System` encryption property moved after it.
- **Contended files are add-only** (Epic 19 is concurrent on slot A); one-line list members and roster counts are unioned by whichever story reaches the feature branch second: `Api/Router.cls`, `Kernel/Governance/Baseline.cls`, `Kernel/Proposal/Prohibited.cls`, `Screen/Gate.cls` (no edit expected), `Screen/Tool/Classification.cls` (only if `field-lists.mjs --check` asks), `scripts/ci-throwaway.sh`, `ui/angular.json`, `ui/src/app/core/strings.ts`, `ui/src/app/core/navigation.ts` (no edit expected), `ui/src/app/core/screen-actions.ts`, `ui/src/app/shell/command-box.ts` (no edit expected), EXPERIENCE.md, and the rosters `ReadTool`, `SurfaceCoverage`, `Wire`, `PortGate`, `Governance`, `GovernanceBaseline`, `ToolDispatch`, `ToolEmit`, `ToolRoundTrip`, `ClassicPageGate`, `MappingDescriptor`, `Test/Prohibited.cls`. `screens.generated.ts` and `ToolFields.cls` are regenerated, never hand-merged.
- **`strings.ts` holds each value under one key.** Reuse `tableColumnDescription`, `tableColumnName`, `fieldPassword`, `ldapFieldPasswordConfirm`, `actionRemove`, `actionCreate`, `actionSave`, `actionCancel`, `homeSuggestedOpen` ("Open"), `pathPickerRootLabel`, `pathPickerFileLabel`.

**Never:**

- No key activation or deactivation, no `Security.Encryption.Settings` write, no database encryption or conversion, no audit, journal, IRISTEMP or IRISSECURITY encryption change, no restart, no license change, on any instance (Stories 18.22 and 18.23 plan those, each behind its own Task 0).
- No server path from a caller other than `root` + `path` through `PathPort`; no key file directly in `<ManagerDirectory>` or in OcuPilot's served directory (PathPort refuses both).
- No `%Api.Admin.*` name outside `AdminPort` and its subclasses; no direct `^EncryptionKey`, `%SYSTEM.Security` or `Security.System` write in product code (test-only `%SYS` seeding of probe key files is allowed).
- No spine or epics.md edit in the implement stage; Task 0 records each AD sentence in `## Spec Change Log` for the runner.
- No auto-refresh on either screen (AD-43's roster is unchanged).
- Database encryption, data-element encryption, the startup settings and wallet secrets are Stories 18.22, 18.23 and 18.24, not this story.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
| --- | --- | --- | --- |
| Open a key file | A probe file with administrator `OcuProbe187Admin` and one 256-bit key | Both reads, on screen and through `security.encryptionkeyfile.read` / `security.encryptionkeyfileadmins.read`, answer the same rows: one administrator, one key with its `Id`, bit length and description | none |
| Bad location | No `root` or `path`; a missing file; a probe text file that is not a key file; a raw `file` sent to `AdminPort` | Refused before any vendor call (the raw `file`), or on the field; nothing read | 400 `READ.CRITERION`; `PATH.NOFILE`; 422 `ENCRYPTION.KEYFILE.UNREADABLE`; 400 `PATH.NAME` |
| Create | `ocuprobe187/probe-a.key`, administrator, password, 256 bits, description, by the form's Save and by a confirmed proposal | One `File` `POST`; the file lists one 256-bit key and the administrator; read-back `written` (`AdminPassword`); no key activated; `Security.System` unchanged | none |
| Create refused | An existing name; a missing directory; a name directly in `<ManagerDirectory>`; `KeyLen` 100; an empty name or password | Refused on the field, no vendor call | `PATH.EXISTS`, `ENCRYPTION.KEYFILE.DIRECTORY`, `PATH.MANAGER`, `ENCRYPTION.KEYFILE.KEYLEN`, `.ADMINNAME`, `.PASSWORD` |
| Add an administrator | Correct existing credentials and a new name, through the dialog and a confirmed proposal | One `AdminInFile` `POST`; the new name is listed; read-back `written` | none |
| Administrator refused | The new name already listed; a wrong existing password | Refused (the first before any call, the second by the vendor) with the file unchanged | 400 `TOOL.ARGUMENTS` (taken); 422 `ENCRYPTION.KEYFILE.CREDENTIALS` |
| Remove an administrator | The typed-name dialog, or a confirmed proposal | One `AdminInFile` `DELETE`; the name leaves the list; read-back `notFound` | none |
| Last or absent administrator | The only administrator; a name gone since the read | Refused, nothing sent | 400 `TOOL.ARGUMENTS` (last); target changed |
| Add a key | Correct credentials, 128 bits | One `KeyInFile` `POST`; one more key listed; the card and dialog state `ENCRYPTION.KEYFILE.NEWKEY` | 422 `ENCRYPTION.KEYFILE.CREDENTIALS` on a wrong password |
| Remove a key | The typed-name dialog (typed name is the key's `Id`), or a confirmed proposal | One `KeyInFile` `DELETE`; the key leaves the list; the dialog and card state `ENCRYPTION.KEYFILE.REMOVEKEY` | target changed when gone |
| Protected key (seam) | The seam reports OcuPilot's own database encrypted with the key being removed | Refused on both callers before anything is sent | 403 `PROHIBITED.OCUPILOTKEY` |
| Password secrecy | Writes carrying a marker in each password | No log line, ledger row, proposal, store, screen context or answer carries the marker | none |
| Missing pair | Each tool, the Save and each read without a declared pair | 403 naming the pair, zero port calls; the side-bar entry listed unavailable without `%Admin_FileSystemAccess:USE` | `AUTH.NOPRIVILEGE` |
| Side bar | The story lands | "Encryption key files" is Security's eighth entry; every browser side-bar assertion derives its labels from the mirror | none |

</intent-contract>

## Code Map

**Vendor** (read-only exports in `/tmp/epic-18-d6/187/vendor/`; re-export with `GetTextAsString` in `%SYS` if gone; every encryption class's `ResourcesOR()` is `%Admin_Secure`, none overrides `ShouldRunAsync`, none queues):

- `%Api.Admin.Endpoints.Security.Encryption.File`: `RunActivate` (`file` query must exist, else 404 before `ActivateDB^`/`ActivateMK^EncryptionKey`); `RunPost` (refuses a `KeyLen` other than 128/192/256 with 400; **creates the directory chain** when the directory is missing; `$$Create^EncryptionKey(File, AdminName, AdminPassword, KeyLen/8, .sc, "2.0", Description)`; 201 with the new key id only in a `Location` header); `ValidateRequest` (POST body `{File, AdminName, AdminPassword, KeyLen, Description}`, ACTIVATE `{Action, AdminName, AdminPassword}`, every key required).
- `.AdminInFile`: `ValidateQueryParams` (`file` required and must exist, else 404 — an existence oracle for any path); `RunList` answers `[{Name}]`; `RunDelete` (`admin`; 404 on #1204, 409 on #1210 last administrator; no password); `RunPost` (`{OldAdminName, OldAdminPassword, NewAdminName, NewAdminPassword}`; 409 on #1205; any other error keeps the default status).
- `.KeyInFile`: `RunList` answers `[{Id, KeyLen, Description}]`; `RunDelete` (`key`; 404 on #1221; "allows you to delete even if it is the last key in the file"; no password); `RunPost` (`{AdminName, AdminPassword, Description, KeyLen}`, 201 with no id).
- `.Key` (`LIST` `[{Id, KeyLen, IsDefault}]`, `DATAELEMENTLIST` (type 10) `[{Id}]`, `DEACTIVATE` (type 11) through its own `Run`) and `.Settings` (`GET`, `PUT` through `ConfigStart^DATABASE1`; under API version 1 only, `RunPut` reads `AdminName`/`AdminPassword` from request headers, otherwise from the body, its only `%request` use) are Stories 18.22 and 18.23's; Part A reaches them only in Task 0's reachability probes.
- `^EncryptionKey` and `^DATABASE1` ship as object code only (`$D(^ROUTINE)` 0, `$D(^rOBJ)` 11, read on `ocupilot-b-ci`), so their own checks are measured, never read.
- Classic pages (`irissys/%CSP/UI/Portal/`): `EncryptionCreate.cls` (Key File free text plus Browse, Administrator Name defaulting to `$USERNAME`, Password and Confirm, Cipher Security Level 16/24/32 shown as 128/192/256-bit default 256, Key Description; Save calls `$$Create^EncryptionKey` :212; the NOTE and WARNING texts :229-259); `EncryptionManage.cls` (`LoadFile` :282-301; the two tables :304-368; Delete admin drawn only with more than one administrator :313; Delete key on every row with its loss warning :175-176); `Dialog/EncAddAdmin.cls` (add administrator or add key; texts :46-62, :107-110; calls :135-136); `Application.cls:116-124` (the Encryption menu: four items, `%Admin_Secure` plus `%DB_IRISSYS` READ). All `RESOURCE` `%Admin_Secure`, none Hidden, each `NormalizePage` answers its class name, no custom resource assigned (read on `ocupilot-b-ci`).

**Ports** (`src/OcuPilot/Port/`):

- `AdminPort.cls`: `APIVERSION` 2 :65; `TYPESUFFIXES` :123; `MUTATINGTYPES` :441 (122 pairs, doc paragraphs :125-440, the last :435-440); `BODYLESSTYPES` :457; `CHECKTYPES` :528; `UNLOGGEDREFUSALS` :580 (`Lock/DELETE/409,License.Key/PUT/400`); `QUEUEDWRITES` :733; `Invoke` :1099, `InvokeLocated` :1108, the 501 for an unadmitted type :1136; `EndpointClass` :1295; `HoldsPair` :1507; `EndpointType` :2749; `ImplementsRead` :2786; `RunSequence` :2817 (stub request :2831-2840, endpoint built :2843); `Sequence` :2876 (queue guards :2911-2944); `Fail` :3039; `LoggedStatus` :3073; `SecretValues` :3092 (masks every credential-pattern name: `AdminPassword`, `OldAdminPassword`, `NewAdminPassword` match, `AdminName` does not); `Refuse` :3110; `Snippet` :3372; `RestStep` :3406. No encryption write is admitted today (501); `Key/LIST`, `Settings/GET`, `KeyInFile/LIST` and `AdminInFile/LIST` are admitted generically, the last two with a raw `file`.
- `PathPort.cls`: `PAIRS` :50 (`%Admin_FileSystemAccess:USE,%DB_IRISSYS:READ`); kinds `KINDFILE` :65, `KINDSOURCE` :69; `Roots` :156; `Resolve(pRoot, pPath, pKind, pRootField, pPathField, .pResolved, .pHttpStatus, .pFault, pOverwrite=0, pVendorWrites=0)` :269 (order: gate, name, root, containment, manager/served refusals, `PATH.NOFILE` :334-338, `PATH.EXISTS` :340-347); codes in `Api/Error.cls` :388-463. No production consumer resolves a non-overwriting file yet (pinned only by `Test/PathPort.cls:266-291`).
- `TaskTransferPort.cls`: the file-consumer model — `CheckExport` :186 (mint-time), `Locate` :215, `ExportFile` :236 (parent-directory refusal :240-243, cleanup of a file a failed call created :290); the import's `source` resolution :223.
- `LicensePort.cls`: the secret-body model — `Call` :42 (the one vendor call and the seam point), `Invoke` :49, `Validate` :71 (refusals before any call, vendor text never read), `Activate` :152 (body built by the port, secret held in locals cleared right after use :160-169), `Snippet` :218.
- `EcpPort.cls`: `Call` :114, `Invoke` :130, `Snippet` :530 (a `comment` step for a branch the port refuses :535).

**Read executor and registry:**

- `Screen/Read.cls`: source parameters :154-239 (`SOURCEATELIER` :239); the source vocabulary :346; the per-port branches :356-446 (the `atelier` branch :431, the model for a criteria-carrying port read through `SeedCriteria`); `PathPortClass()`/`AtelierPortClass()` seam methods.
- `Screen/Registry.cls`: the source-port vocabulary and its message :1142-1143; criteria permitted only for `admin`, `mgmnt`, `atelier`, `timeline` :1551. `ui/tools/screen-mirror.mjs`: `SOURCE_ATELIER` :946 and its vocabulary.
- `Screen/Descriptor/ExplorerSearch.cls`: the `list (server criteria)` model (text criteria, `id` `none`). `AllowedDirectoryList.cls:26-32`: the Security own-pair model (`%Admin_FileSystemAccess:USE`). `SslConfigList.cls:48`: Security's set. `Screen/Area.cls:79`: Security, rail 7, `%Admin_Secure:USE`, `%DB_IRISSYS:READ`.

**Tool models** (`src/OcuPilot/Screen/Tool/`):

- `TaskExport.cls`: `root`/`path` arguments (`AddFileArguments` :113-120, `FileProblem` :137, `PortQuery` :167, `SCREENVALUES` :32, `WRITERESOURCE` :60, `StateDiff` :176, `CONSEQUENCE` :65).
- `LicenseKeyActivate.cls` and `UserPassword.cls`: `SECRETBODY`, `SENDSBODY` 0, `SCREENVALUES`, `FINGERPRINTSUBJECT`, `DESTRUCTIVE`. `X509Import.cls:44-49` and `SslUpdate.cls:43-45`: secrets beside ordinary arguments (`COMPOSEDSECRETS`, the masked `StateDiff` row :93-111).
- Mapping tools (Story 18.14, `Screen/Tool/*Mapping*.cls`): a composite target from two arguments. `EcpSslConnectionDelete.cls`: a `StateDiff` refusal on a row's state, `REMOVALROWS`, `CHANGEACTION` `deleted`. `LicenseServerCreate.cls` / `LicenseServerSave.cls` (`Area/OsMgmt/`): a create's Save through the tool (AD-55).
- `Write.cls`: `DESTRUCTIVE` :52, `READTYPE` :57, `WRITETYPE` :62, `SENDSBODY` :67, `FINGERPRINTSUBJECT` :97, `PRECONDITIONFIELD` :105, `PORTCLASS` :114, `CLASSICPAGES` :124, `CHANGEACTION` :134, `CREATES` :151, `SCREENACTIONS` :167, `READANSWERS` :180, `SECRETBODY` :207, `SCREENVALUES` :217, `ReadBackGone` :279, `PRECONDITIONCODES` :483. `Base.cls:50` `ADVERTISED`.
- `Kernel/Proposal/ReadBack.cls`: `KindOf` :206 (delete, then create, then merge, then secret, then action); `Of` :77-147 (a create comparing no derived field reports its secrets `written`; a delete consults `ReadBackGone`).

**Kernel:**

- `Kernel/EntityType.cls:75` `TYPES` (51, last `ecp-ssl-connection`); `Kernel/EntityRef.cls:59` `IDRULES` (26).
- `Kernel/Proposal/Prohibited.cls`: `COVEREDTYPES` :250 (40), the type guard :1085, the reason list :737 and map :771 (`OCUPILOTDATABASE` :383-388 is the parameter and sentence model), `Database` arm :2303-2360, `OwnDatabaseNames` :2384, `OwnDatabaseDirectories` (reads through the tool's port).
- `Kernel/Governance/Baseline.cls`: keys :20-172, Security block :85-133 (wallet keys `security.secrets.*` :125-127).
- `Api/Error.cls`: the prefix dispatch in `ReasonForToolCode` :1225-1226 and `ReasonForViolation` :1424-1425 (add one `ENCRYPTION.` line at each). `Api/LicenseError.cls` (`Codes()` :54, `ViolationCodes()` :61, `FieldOf` :67, `ReasonFor` :78) is the area error class model.
- `Database.SysCRUD` `LIST` answers each database's `Encrypted` and `EncryptionKeyID` (measured at plan); the Databases list declares `%Admin_Manage:USE`, `%DB_IRISSYS:READ` (`DatabaseList.cls:71`).

**Client** (`ui/src/app/`):

- `shell/server-path-picker.ts:108-122` (`store`, `kind` `'directory' | 'file'`, `root`, `path`, `rootReason`, `pathReason`); `core/allowed-directories.ts` (its store); `areas/tasks/task-schedule.page.ts` (owns the store :124, loads it :233, sends `{root, path}` :247, routes refusals :257-260).
- `areas/os-management/license-key.page.ts` (the `app-dialog` with page-local secret text cleared on close); `areas/security/wallet-secret-form.page.ts` (the masked field); `areas/os-management/license-server-form.page.ts` and `.store.ts` (the create form and Save model).
- `shell/screen-outlet.ts` `DESCRIPTOR_PAGES` :143-235 (last Epic 18 entry `EcpSettings` :215); `shell/screen-action-handler.ts` `DESTRUCTIVE_ACTIONS` :366, `DESTRUCTIVE_CONSEQUENCES` :394-429, `WARNING_CONSEQUENCES` :484-510, `PUBLISHED_PROBLEMS` :554-575; `core/screen-actions.ts` `DESCRIPTOR_ACTION_LABELS` :151-228; `core/proposal-view.ts` consequence codes :142-280; `app.ts` injections :250-376, sign-out resets :608-748.
- `core/strings.ts`: `} as const` :5394; `ui/tools/strings.test.mjs` literal bound :582 (2500; 2486 used, measured), one key per value :626, citations :816-861.
- `core/navigation.ts:133` `listedScreensForArea`; `ui/browser/gate.browser-spec.mjs:52-53` imports `STRINGS` and `SCREENS` from the TypeScript sources (the helper's model).
- `ui/angular.json:54` `maximumWarning` 2805kB, pinned at `ui/tools/angular-json.test.mjs:489` (history :475-476).

**EXPERIENCE.md** (`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`, 1019 lines): :168 Security and secrets' side bar (`| Security and secrets | SSL/TLS · X.509 · LDAP / Kerberos · Wallet · OAuth 2.0 · Auditing | Allowed directories (Stage 2, Story 18.1); tests, details, copy/purge and the OAuth editors attach to existing screens |`); :173 Dialogs; :364 the Wallet and Allowed directories Fixed strings row; :490 the delete bodies for credential, secret, SSL and LDAP; :416 the wallet read-only sentences (Story 18.24's).

**Rosters a listed screen, tool, route, type, key or classic page trips** (current counts; re-derive each change from its class's red, never by hand):

- ObjectScript (`src/OcuPilot/Test/`): `Descriptor.cls` `ReadShapes` :67-169 (99 rows), entity count :1743 (51), Security own-pair list :1916 and :1941 (14); `ReadTool.cls` :93 (258), :94, :112; `SurfaceCoverage.cls` screens :57-193, tools :194-346; `EndpointCoverage.cls` :76-257; `Navigation.cls` :431; `PortGate.cls:29` (30 ports); `PortFixture.cls:21` (123); `Prohibited.cls:232` (40); `GovernanceBaseline.cls:15` (`DISABLED` 26); `Governance.cls` group parameters :17-47; `ToolRoundTrip.cls:70` (186); `ToolEmit.cls:420`; `DraftRegistry.cls` :37-68; `ClassicPageGate.cls:75` (`OWNPAIRS` 51, assert :150); `MappingDescriptor.cls:23` (55); `ScreenRead.cls:215` (11 exemptions); `ToolWrite.cls` :1324, :1326; `Wire.cls:598`; `WireSecurityRead.cls` :807, :957, :985, :1093, :1112; `WireOAuthRead.cls` :275-350; `WireAreaAnyScreen.cls` :289, :297; `EntityRef.cls`.
- Client: `ui/tools/navigation.test.mjs` :135-322 (built routes, Security :249-274) and :579-583 (Security's listed routes); `navigation-wire.test.mjs`; `shell/rail-wire.spec.ts` (unlisted screens sort first by class name, :95-96); `shell/area-verdict.spec.ts` :208-221, :275-283; `screen-mirror.test.mjs` :2333-2361 (own-pair descriptors); `proposal-view.test.mjs`.
- Browser side-bar pins (DW-1774), each converted to the helper: Security — `security.browser-spec.mjs` :277-282, :389-400, :457-468; `ssl.browser-spec.mjs` :226-230; `oauth.browser-spec.mjs` :296-297, :517-528; `permissions-effective.browser-spec.mjs` :483-494, :510-513. Permissions — `permissions.browser-spec.mjs` :274-279. Tasks — `tasks.browser-spec.mjs` :1209-1212, `background-tasks.browser-spec.mjs` :180-184. Web applications — `web-sessions.browser-spec.mjs:223`. OS management — `remote-databases.browser-spec.mjs` :300-324, `license-usage.browser-spec.mjs` :131-158, and the `entries.length, 19` pins in `journals` :279-282, `journal-settings` :229-231, `ecp-settings` :227-228, `ecp-data-servers` :373-374, `license-servers` :250-251, `license-key` :219-220, `ecp-application-servers` :226-227. Prefix slices (`local-databases` :496, `namespaces` :379, `rest-apis` :114) and `guardrails` :109-110 are safe.
- CI: `scripts/ci-throwaway.sh` has 19 `OCUPILOT_ALLOW_*` variables (`PRINCIPALS` :217-326, `ECP_CONFIG` :522-527 the latest); none arms encryption. `ui/tools/ci.test.mjs:2177-2207` derives each roster from the classes that declare the variable (floor 7 at :2195).

**Test models:** `Test/LicenseProbe.cls` (`SeedPrincipal` :184, `RemoveAll` :212, `Run` :297, `RunAs` :330, `Snapshot` :483, `Diff` :584, `LineCount` :614, `LinesAfter` :629); `Test/LicenseSeamPort.cls` (`Call` :18, `Arm` :58, `Calls` :70, `Writes` :80, `BodyOf` :92); `Test/SeamLicenseKeyActivate.cls` and `Test/LicenseActionFixture.cls` (a seam tool and `ToolFor`); `Test/LicenseKey.cls` :48-58, :140-186 (call order, the marker's absence from `messages.log` and `alerts.log`); `ui/browser/license-key.browser-spec.mjs` (throwaway guard, dialog gate in both themes).

## Tasks & Acceptance

### Part A: Encryption key files (Story 18.7)

**Task 0, the implement stage's first task, before any descriptor, tool or page.** Run it on `ocupilot-b-ci` only, loading with `/tmp/epic-18-d6/load-throwaway.sh` (no restart). Keep evidence under `/tmp/epic-18-d6/187/t0/`. Record each result under Design Notes › Measured at implement, and each AD sentence in `## Spec Change Log` for the runner.

1. **Plumbing** (add-only):
   - `Port/AdminPort.cls`: `MUTATINGTYPES` gains `Security.Encryption.File/POST`, `Security.Encryption.File/ACTIVATE`, `Security.Encryption.Key/DEACTIVATE`, `Security.Encryption.AdminInFile/POST`, `Security.Encryption.AdminInFile/DELETE`, `Security.Encryption.KeyInFile/POST`, `Security.Encryption.KeyInFile/DELETE` and `Security.Encryption.Settings/PUT`, with one doc paragraph (Stories 18.22 and 18.23 declare the tools for the third, fourth and last); `BODYLESSTYPES` gains the two `DELETE`s; `TYPESUFFIXES` gains `DATAELEMENTLIST`; `Parameter PATHRESOLVED = 0` and the guard: a `Security.Encryption.*` call carrying a `file` query parameter, a `File` body member or a non-empty `DBEncStartKeyFile` is refused 400 `PATH.NAME` before any vendor call unless `..#PATHRESOLVED`. `Test/PortFixture.cls:21` follows.
   - `Port/EncryptionPort.cls` (new, extends `AdminPort`, `PATHRESOLVED` 1): `Call` (the one vendor call, the seam point), `Resolve` (`root` + `path` through `PathPort`, as a `file` with overwrite 0 or a `source`), and the `KEYFILE` and resolved `LIST` branches of Execution (server).
   - `Test/EncryptionProbe.cls` (new, the `LicenseProbe` model): `SeedDirectory` / `RemoveDirectory` (`<ManagerDirectory>ocuprobe187/`, created only when absent and marked), `SeedKeyFile` (test-only `%SYS` seeding through `$$Create^EncryptionKey`), `SeedTextFile`, `SeedPrincipal`, `RemoveAll`, `Run`, `RunAs`, `Snapshot`, `Diff`, `LineCount`, `LinesAfter`.
2. **Take S0.** It holds: every `Security.System` encryption property (`DBEncStartMode`, `DBEncJournal`, `DBEncIRISSecurity`, `DBEncIRISTemp`, `AuditEncrypt`, `DBEncStartKMIPServer`, `DBEncStartKeyFile`, `DBEncDefaultKeyID`, `DBEncJournalKeyID`, and whether a startup username is stored); the activated database and data-element keys; `GetDBEncKeyID()` and the journal key; the encrypted-database count; `Config.CPF.PendingRestart` and its reasons (known: 1, with two `MaxServerConn` reasons); the audit event count; the `messages.log` and `alerts.log` line counts and the monitor state; the process count; whether the probe directory exists; OcuPilot's own objects.
3. **Reads, timed, through `AdminPort` as `_SYSTEM`:** `Settings` `GET`, `Key` `LIST`, `Key` `DATAELEMENTLIST`; then, after step 4a, `KeyInFile` and `AdminInFile` `LIST` of the probe file through `EncryptionPort` (keys, JSON types, the `KeyLen` unit: bits or bytes).
4. **Key-file writes on probe files under `ocuprobe187/`:**
   - a. `File` `POST` through `EncryptionPort` (`probe-a.key`, `OcuProbe187Admin`, a probe password, 256, `OCUPROBE187 A`): status, answer, whether the port sees the `Location` header, duration, the file's existence and size, both lists of it, audit events, `messages.log` lines; no key activated, no `Security.System` change, no new `PendingRestart` reason.
   - b. `KeyLen` 128 and 192 accepted (`probe-b`, `probe-c`); through `EncryptionPort.Call` past the port's rules: `KeyLen` 100, an empty `AdminName`, an empty `AdminPassword`, a 51- and a 200-character `AdminName`, a 1,000-character `Description`: each answer.
   - c. Through `Call`: `File` `POST` at `probe-a.key`, which exists (is it overwritten, and does its key `Id` change?); `File` `POST` at `ocuprobe187/missing/probe-d.key` (does the vendor create the directory?). Remove whatever either created that S0 lacks.
   - d. `AdminInFile` `POST` adding `OcuProbe187Admin2` with the right existing password, with a wrong one, and with an existing new name: status and vendor code of each.
   - e. `AdminInFile` `DELETE` of `OcuProbe187Admin2`, then of the last administrator, then of an absent name.
   - f. `KeyInFile` `POST` adding a 128-bit key with the right password and with a wrong one.
   - g. `KeyInFile` `DELETE` of the added key, of an absent key, and of the only key in `probe-c.key`.
   - h. `KeyInFile` and `AdminInFile` `LIST` of a missing file and of `ocuprobe187/not-a-key.txt` (seeded text): status and code.
   - i. `AdminPort.Invoke` (not `EncryptionPort`) with a raw `file`: refused `PATH.NAME` with no vendor call.
5. **Reachability without effect** (each must stop at the vendor's own validation or file check, before any activation, deactivation or settings change): `File` `ACTIVATE` through `Call` with `file` naming `ocuprobe187/absent.key` (checked absent first) and a complete body (expected 404 from `RunActivate` before `ActivateDB^`); `Key` `DEACTIVATE` with no `id` (expected 400); `Settings` `PUT` with body `{}` (expected 400 from `ValidateRequest`). Re-read S0's encryption facts after each.
6. **Audit:** with auditing on, the vendor events steps 4a to 4g wrote.
7. **Pairs**, through `RunAs` with the install namespace's code read, as a principal holding exactly `%Admin_Secure:USE`, `%Admin_FileSystemAccess:USE` and `%DB_IRISSYS:READ`: steps 3's file reads, 4a, 4d, 4e, 4f, 4g. Repeat each refused step with each candidate alone: `%DB_IRISSYS:WRITE`, `%Admin_Manage:USE`, `%Admin_Operate:USE`; then each step without `%Admin_FileSystemAccess:USE`. Also, for the `removekey` arm's reads: `Database.SysCRUD` `LIST`, `Settings` `GET` and the reads `OwnDatabaseNames` / `OwnDatabaseDirectories` make, with Security's set alone and with `%Admin_Manage:USE` added.
8. **Cleanup proof:** `RemoveAll`, then S2. It must equal S0 apart from counters, declared `messages.log` lines and the monitor state (cleared with `$SYSTEM.Monitor.Clear()` if it moved).
9. **HALT** with status `blocked`, blocking condition `intent gap: observation contradicts the plan: <what>`, and nothing built past step 1, if any of these hold (record step 7's evidence first for a pair halt):
   - a route cannot be reached through `AdminPort` (a 500 or 501 that is not the vendor's own answer) or answers 202;
   - any step activates or deactivates a key, changes a `Security.System` encryption property, adds a `PendingRestart` reason, changes the journal or audit encryption state, or changes any S0 fact beyond the probe directory: stop at once, tell the runner, never restart the container;
   - a step 5 probe answers 2xx or reaches past the vendor's file or body check;
   - a key-file write starts a process, or writes a `messages.log` line above severity 0 beyond OcuPilot's own lines for refused probes;
   - a read takes more than 2 s;
   - a write needs a pair outside the screen's set, `%DB_IRISSYS:WRITE` and, for `removekey`, `%Admin_Manage:USE`;
   - S2 differs from S0 beyond the declared differences.
   **Not a halt:** if step 4a is refused for the license or edition, every key-file success path runs through `EncryptionSeamPort`'s `created` mode, the real legs pin the refusal, and the refusal is recorded.
10. **Otherwise, set from the record:** each tool's pairs; the administrator-name and description limits `EncryptionRules` enforces; the `KeyLen` unit the table labels; the vendor status and code each mapped refusal arrives as (credentials, taken, last, absent, unreadable); which of them `UNLOGGEDREFUSALS` can name by endpoint, type and status (Design Notes › Decision 6); each AD-15 / AD-53 named case where step 6 found no vendor event.

**Execution (server)** (`src/OcuPilot/`):

- `Port/EncryptionPort.cls` (new; names no vendor class):
  - **`Invoke`** branches, each resolving `root` and `path` from the query first (a missing one is 400 `READ.CRITERION` on a read and `TOOL.ARGUMENTS` on a write), then sending `file` as the resolved path:
    - `KeyInFile` / `AdminInFile` `LIST`: resolved as a `source`; a vendor error on a file that is not a key file is 422 `ENCRYPTION.KEYFILE.UNREADABLE` on `path`.
    - `KEYFILE` (port-composed, the fresh read of every key-file tool): resolved as a `source`; `PATH.NOFILE` answers 404 `PORT.NOTFOUND`, unlogged (the create's AD-54 absence); otherwise both lists, answered as `{Administrators:[<name>], Keys:[{Id, KeyLen, Description}]}`.
    - `File` `POST`: `EncryptionRules` first; resolved as a `file` with overwrite 0; a missing parent directory is 422 `ENCRYPTION.KEYFILE.DIRECTORY` on `path`; the body `{File, AdminName, AdminPassword, KeyLen, Description}` built by the port from the declared arguments and the secret, the password held in a local cleared right after `Call`.
    - `AdminInFile` `POST` / `DELETE` and `KeyInFile` `POST` / `DELETE`: resolved as a `source`; bodies `{OldAdminName, OldAdminPassword, NewAdminName, NewAdminPassword}` and `{AdminName, AdminPassword, Description, KeyLen}`, queries `admin` and `key`; the vendor's wrong-credentials answer (Task 0) is 422 `ENCRYPTION.KEYFILE.CREDENTIALS` on the password field, #1205 is `TOOL.ARGUMENTS` with the taken sentence, #1210 the last sentence, #1204 and #1221 404 `PORT.NOTFOUND`.
    - Every other encryption type passes to `##super` unchanged.
  - **`Snippet`** mirrors every branch (AD-59): a refusal renders one `comment` step with its sentence; each write one `RestStep` addressed from `AdminRoutes`, every password rendered `"<Name>"` and the key file as the resolved path.
- `Area/Security/EncryptionRules.cls` (new): `Problem(pArgs)` over `KeyLen`, the names, the passwords and (per Task 0) `Description`, each violation named by its argument; used by the port, the tools' `ArgumentProblem` and the Save.
- `Area/Security/EncryptionKeyFileSave.cls` (new, the `LicenseServerSave` model): `POST /encryption-key-file` through `security.encryptionkeyfile.create` (AD-55), top-level keys `root`, `path`, `AdminName`, `KeyLen`, `Description`, `AdminPassword` only (else 400 `PORT.FIELD.UNEXPECTED`), the secret under `EncryptionKeyFile`'s `secretArguments`; a port fault becomes a violation on its field; answers the read-back and the new key's `Id` from the re-read `KEYFILE`; `Cache-Control: no-store`.
- `Api/Router.cls` (add-only): `POST /encryption-key-file` at the UrlMap tail, with its thin wrapper.
- `Screen/Read.cls` (add-only): `Parameter SOURCEENCRYPTION = "encryption"`, the vocabulary at :346, a branch that seeds the criteria (`SeedCriteria`) and calls `EncryptionPortClass()`'s `Invoke` with `maxRows` the cap plus one, and `EncryptionPortClass()`. `Screen/Registry.cls` (add-only): `encryption` joins the source vocabulary :1142-1143 and the criteria-permitted ports :1551. `ui/tools/screen-mirror.mjs` follows (`SOURCE_ENCRYPTION`).
- `Screen/Descriptor/EncryptionKeyFile.cls`, `EncryptionKeyFileAdminList.cls`, `EncryptionKeyFileForm.cls` (new), as in Boundaries:
  - `EncryptionKeyFile`: `primaryAction` `create`, `rowActions` `addkey` and `removekey`; `secretArguments` `["AdminPassword"]`; table columns Key identifier (`identifier`), Bit length (`number`), Description (`text`), with its two empty-state keys; context fields `Id`, `KeyLen`, `Description`; `secondaryEntityTypes` none.
  - `EncryptionKeyFileAdminList`: `rowActions` `addadministrator` and `removeadministrator`; `secretArguments` `["OldAdminPassword","NewAdminPassword"]`; one column Administrator (`name`).
  - `EncryptionKeyFileForm`: no read, no action; three prompts.
- `Screen/Tool/` (new; each `PORTCLASS` `EncryptionPort`, `READTYPE` `KEYFILE`, `READANSWERS` `Administrators,Keys`, `SENDSBODY` 0, `ADVERTISED` 1, the target in Boundaries (on a screen action `root` and `path` are decoded from the target's composite id, as the mapping tools decode theirs, so no `SCREENVALUES` names them), the arguments in `InputSchema` with each argument's shape and limit stated in prose, `PortQuery` carrying the non-secret arguments, `ArgumentProblem` through `EncryptionRules`):
  - `EncryptionKeyFileCreate.cls`: `DESCRIPTORCLASS` `EncryptionKeyFile`, `WRITETYPE` `POST`, `CREATES` 1, `SECRETBODY` `AdminPassword`, `CLASSICPAGES` `%CSP.UI.Portal.EncryptionCreate`, `Consequence` `ENCRYPTION.KEYFILE.NEWKEY`; a name taken since the mint reads present at the confirm's re-read and closes the proposal as target-changed (AD-54), and the write's own resolution refuses it `PATH.EXISTS`; `StateDiff` rows Location, Administrator, Bit length, Description and a masked Password row.
  - `EncryptionKeyFileAddAdmin.cls`: `DESCRIPTORCLASS` `EncryptionKeyFileAdminList`, `WRITETYPE` `POST`, `SECRETBODY` `OldAdminPassword,NewAdminPassword`, `SCREENACTIONS` `addadministrator`, `SCREENVALUES` `addadministrator=OldAdminName:NewAdminName`, `READANSWERS`, `PRECONDITIONFIELD` and `FINGERPRINTSUBJECT` `Administrators`, `CLASSICPAGES` `%CSP.UI.Portal.Dialog.EncAddAdmin`; `StateDiff` refuses a listed `NewAdminName` with `REASONADMINTAKEN`.
  - `EncryptionKeyFileRemoveAdmin.cls`: `DESCRIPTORCLASS` `EncryptionKeyFileAdminList`, `WRITETYPE` `DELETE`, `SCREENACTIONS` `removeadministrator`, `SCREENVALUES` `removeadministrator=Admin`, `FINGERPRINTSUBJECT` `Administrators`, `DESTRUCTIVE` 1, `CHANGEACTION` `deleted`, `REMOVALROWS` `Admin`; `StateDiff` refuses an unlisted name (`REASONADMINABSENT`) and the last administrator (`REASONADMINLAST`); `ReadBackGone` when `Admin` is no longer listed.
  - `EncryptionKeyFileAddKey.cls`: `DESCRIPTORCLASS` `EncryptionKeyFile`, `WRITETYPE` `POST`, `SECRETBODY` `AdminPassword`, `SCREENACTIONS` `addkey`, `SCREENVALUES` `addkey=AdminName:KeyLen:Description`, `FINGERPRINTSUBJECT` `Keys`, `CLASSICPAGES` `%CSP.UI.Portal.Dialog.EncAddAdmin`, `Consequence` `ENCRYPTION.KEYFILE.NEWKEY`.
  - `EncryptionKeyFileRemoveKey.cls`: `DESCRIPTORCLASS` `EncryptionKeyFile`, `WRITETYPE` `DELETE`, `SCREENACTIONS` `removekey`, `SCREENVALUES` `removekey=KeyId`, `FINGERPRINTSUBJECT` `Keys`, `DESTRUCTIVE` 1, `CHANGEACTION` `deleted`, `REMOVALROWS` `KeyId`, `Consequence` `ENCRYPTION.KEYFILE.REMOVEKEY`, `EXTRAPAIRS` per Task 0 (expected `%Admin_Manage:USE`); `StateDiff` refuses an unlisted key (`REASONKEYABSENT`); `ReadBackGone` when `KeyId` is no longer listed.
  - Each tool's `PrivilegePairs`: the screen's three plus `EXTRAPAIRS` per Task 0, refused by name before any port call.
- `Api/EncryptionError.cls` (new, the `LicenseError` shape: `Codes()`, `ViolationCodes()`, `FieldOf`, `ReasonFor`); `Api/Error.cls` gains one `ENCRYPTION.` line at each dispatch (add-only). Codes and sentences:
  - `ENCRYPTION.KEYFILE.VALIDATION` (422 envelope): "The key file request was refused."
  - `ENCRYPTION.KEYFILE.DIRECTORY` (`path`): "Choose a folder that already exists for the key file."
  - `ENCRYPTION.KEYFILE.KEYLEN` (`KeyLen`): "Choose 128, 192 or 256 bits."
  - `ENCRYPTION.KEYFILE.ADMINNAME` (`AdminName`, `OldAdminName`, `NewAdminName`): "Enter an administrator name of up to <limit> characters." with Task 0's limit written in.
  - `ENCRYPTION.KEYFILE.PASSWORD` (each password field): "Enter the password."
  - `ENCRYPTION.KEYFILE.DESCRIPTION` (`Description`), only if Task 0 step 4b finds a vendor limit: "Use up to <limit> characters." with that limit written in.
  - `ENCRYPTION.KEYFILE.CREDENTIALS` (`AdminPassword`, `OldAdminPassword`): "That administrator name and password do not open this key file."
  - `ENCRYPTION.KEYFILE.UNREADABLE` (`path`): "This file is not an encryption key file."
  - `ENCRYPTION.KEYFILE.NEWKEY` (consequence): "The new key is unique: no existing encrypted database or file can use it. If every key file containing it is lost, all data encrypted with it is permanently inaccessible. Make a backup copy of the key file."
  - `ENCRYPTION.KEYFILE.REMOVEKEY` (consequence): "If this is the only key file containing this key, all data encrypted with this key will be permanently inaccessible."
  - State refusals, held as parameters and answered as 400 `TOOL.ARGUMENTS` with `detail.problem`: `REASONADMINTAKEN` "This key file already has an administrator of that name.", `REASONADMINLAST` "A key file keeps at least one administrator.", `REASONADMINABSENT` "This administrator is not in this key file.", `REASONKEYABSENT` "This key is not in this key file."
- `Kernel/Proposal/Prohibited.cls` (add-only): `encryption-key-file` joins `COVEREDTYPES` and the guard at :1085 through `ReviewedFewOnly` (create fields `root,path,AdminName,KeyLen,Description,AdminPassword`; change fields `OldAdminName,NewAdminName,OldAdminPassword,NewAdminPassword,AdminName,AdminPassword,KeyLen,Description,Admin,KeyId`, adjusted only as `Test/Prohibited` requires: every declared secret among its type's reviewed fields); `Parameter OCUPILOTKEY = "PROHIBITED.OCUPILOTKEY"` with `OCUPILOTKEYREASON` "OcuPilot or the instance itself depends on data this key encrypts, so it is not removed from a key file here.", joining the list at :737 and the map at :771; the arm `KeyRemoval`, evaluated for `removekey` inside AD-34's transition, reading through the tool's port `Database.SysCRUD` `LIST` (each directory's `EncryptionKeyID`), `OwnDatabaseDirectories` and `Settings` `GET` (`DBEncJournalKeyID`), refusing when `KeyId` is one of them and when any read fails.
- `Kernel/EntityType.cls` (`encryption-key-file`, with its doc line); `Kernel/Governance/Baseline.cls` (add-only, in name order in the Security block): `security.encryptionkeyfile.addkey`, `.create`, `.removekey`, `security.encryptionkeyfileadmins.addadministrator`, `.removeadministrator`, each `false`.
- `Port/AdminPort.cls` `UNLOGGEDREFUSALS`, per Decision 6: the measured endpoint/type/status entries for a refusal `EncryptionPort` maps to a field (a wrong password, a taken or last administrator) where the status is not shared with an internal failure.

**Execution (client)** (`ui/src/app/`):

- `areas/security/encryption-key-file.page.ts` and `.store.ts` (new, with specs), registered in `DESCRIPTOR_PAGES` for `EncryptionKeyFile` and `EncryptionKeyFileAdminList`:
  - a `server-path-picker` (`kind` `file`) and Open (`homeSuggestedOpen`), which issues both declared reads with `{root, path}` as criteria; the picker's refusals render on its fields;
  - "Administrators in this key file" and "Encryption keys in this key file" tables; Remove on each row (the typed-name destructive dialog: the administrator's name, or the key's `Id` with `ENCRYPTION.KEYFILE.REMOVEKEY`'s body); Remove drawn `aria-disabled` with `REASONADMINLAST` while one administrator is listed;
  - Add administrator and Add key open `app-dialog`s with masked password fields (existing name and password, new name, password and confirm; or name, password, cipher level and description), each value in a page-local signal cleared on close and after success, never in the store; a password mismatch is refused in the dialog;
  - Create key file navigates to the form (`encryption-key-file-actions.ts`); a change event re-reads both lists.
- `areas/security/encryption-key-file-form.page.ts` and `.store.ts` (new, with specs; the license server form model): the picker (`kind` `file`), Administrator name (default the signed-in user), Password and Confirm, Cipher security level (128, 192, 256 bits, default 256), Key description; sticky Save to `POST /api/ocupilot/encryption-key-file`; refusals on their fields; the unsaved-changes guard; after the Save, "New encryption key ID: <id>", the `NEWKEY` sentence, "This key has not been activated.", and the classic page's recommendations in plain form (add an emergency recovery administrator; make a backup copy of the key file; store it with a written record of the recovery password in a secure place).
- `shell/screen-outlet.ts`, `shell/screen-action-handler.ts` (add-only): the descriptors' constants; `DESTRUCTIVE_ACTIONS` gains `removeadministrator` and `removekey`; `DESTRUCTIVE_CONSEQUENCES` their bodies; `PUBLISHED_PROBLEMS` the four state refusals. `core/screen-actions.ts` `DESCRIPTOR_ACTION_LABELS`: Create key file, Add administrator, Add key, Remove. `core/proposal-view.ts`: `ENCRYPTION.KEYFILE.NEWKEY` and `.REMOVEKEY`. `app.ts`: both stores' injections and sign-out resets, pinned in `app.spec.ts`.
- `core/strings.ts` (add-only, after :5393), each new key under its `/** EXPERIENCE.md:n */` line, reusing the keys in Boundaries; raise `ui/tools/strings.test.mjs:582`'s bound to the measured literal count rounded up to the next hundred. Regenerate `core/screens.generated.ts` (`cd ui && node tools/screen-mirror.mjs`).
- `ui/angular.json`: re-base `maximumWarning` under DW-1166 to the measured initial total rounded up to the next kB, with its history row, if the build crosses 2805kB; stop and ask above 3800kB.
- **EXPERIENCE.md, in place, keeping 1019 lines,** then `cd ui && npm run test:tools`:
  - :168 gains "· Encryption key files (Stage 2, Story 18.7)" in the Stage 2 column.
  - :173 gains "add an administrator to an encryption key file · add a key to an encryption key file (Story 18.7: masked password fields, each value page-local and cleared on close)", and the delete list gains "encryption key file administrator · key in an encryption key file".
  - :364 gains "; and Encryption key files (Story 18.7): …", tagged `[ADDED <date> - Story 18.7]`, with every new literal: the screen, form and entity labels, the two table titles and three column labels, the action labels, the dialog titles ("Add an administrator", "Add an encryption key") and field labels, the form's labels, options and hints, the after-Save lines and recommendations, the error and state sentences, `PROHIBITED.OCUPILOTKEY`'s sentence, the two empty states ("Open a key file to see its administrators." and "Open a key file to see its keys.") and the nine prompts.
  - :490 gains "; then Remove on an encryption key file administrator (Story 18.7): "Removing this administrator means its name and password no longer open this key file. This cannot be undone." and Remove on a key in an encryption key file, whose typed name is the key identifier: "If this is the only key file containing this key, all data encrypted with this key will be permanently inaccessible. This cannot be undone.""

**DW-1774** (the fix):

- `ui/browser/side-bar-spec.mjs` (new; registers no test, outside the `*.browser-spec.mjs` glob): `sideBarLabels(areaKey)` answers `listedScreensForArea(areaKey).map(s => STRINGS[s.labelKey])`, imported from the TypeScript sources as `gate.browser-spec.mjs` does.
- Every pin in Code Map › Browser side-bar pins: a listed-label assertion becomes `deepEqual(labels, sideBarLabels(<area>))`; an `entries.length, 19` pin becomes that plus its index check through the helper; a gated-entry list keeps its exact `{label, verdict}` pairs only for the entries its leg is about and asserts the order through the helper.
- `ui/tools/side-bar-pins.test.mjs` (new): every `ui/browser/*.browser-spec.mjs` that reads `ocu-side-bar-label` imports `./side-bar-spec.mjs`, and none asserts an entry count against a number literal (`/entries\.length,\s*\d/`).
- `ui/tools/navigation.test.mjs` keeps its literal listed and built routes per area (the one deliberate literal, run by every story's `test:tools`); this story adds its routes there.

**Rosters and CI:** extend every roster in Code Map › Rosters (Security's own-pair rosters gain the three descriptors; position-0 descriptors sort by class name, so `EncryptionKeyFileAdminList` and `EncryptionKeyFileForm` sort before `LdapConfigForm`). `Test/ScreenRead.cls:215` exempts both list descriptors (their read needs criteria). `scripts/ci-throwaway.sh` (add-only): `OCUPILOT_ALLOW_ENCRYPTION_CONFIG` with its `# classes:` line for the classes that write key files, and the gate class on `OCUPILOT_ALLOW_PRINCIPALS`'s lines.

**Tests:**

- `Test/EncryptionProbe.cls`: Task 0's helper, run before all tests, after each and after all.
- `Test/EncryptionSeamPort.cls` (an `EncryptionPort` subclass; armed per test): records each call's endpoint, type and body key names (never a secret's value) without reaching the vendor in its armed modes: `protected` (answers a `Database.SysCRUD` row for OcuPilot's own database directory whose `EncryptionKeyID` is the probe key's `Id`), and `created` (only if Task 0 finds key-file creation refused for the license), in which every key-file route answers from a canned key file the seam holds, never the vendor. Seam tool subclasses and a fixture `ToolFor` follow `SeamLicenseKeyActivate` / `LicenseActionFixture`.
- `Test/EncryptionKeyFileRead.cls`: both reads on screen and tool answer the same rows of a seeded file; missing criteria, a missing file and a text file refused; a raw `file` to `AdminPort` refused with no vendor call; no key material in any answer.
- `Test/EncryptionKeyFileWrite.cls` (`OCUPILOT_ALLOW_ENCRYPTION_CONFIG`): the matrix's write rows on both callers with real vendor writes on probe files, the read-backs, the refusals with zero vendor calls, the self-protection leg through the seam, the password marker's absence from `messages.log`, `alerts.log`, the ledger, the proposal row and every answer, and S0's encryption facts unchanged after each test.
- `Test/EncryptionWriteGate.cls` with `EncryptionWriteGateProbe.cls` (`OCUPILOT_ALLOW_PRINCIPALS`, `OCUPILOT_ALLOW_ENCRYPTION_CONFIG`): each tool's, the Save's and each read's declared pairs refused by name with zero port calls; the entry listed unavailable without `%Admin_FileSystemAccess:USE`; exactly the declared pairs write.
- `Test/EncryptionDescriptor.cls`: the three descriptors (routes, positions, pairs, own pair, classic pages, prompts, entity type, criteria and hints), `EncryptionError`'s codes and sentences, the five baseline keys `false`, `PROHIBITED.OCUPILOTKEY`'s sentence equal to EXPERIENCE.md's published copy, `EncryptionPort.Snippet`'s branches, and the `AdminPort` `file` guard.
- Component specs: the key file page and store (reads, dialogs' page-local secrets, last-administrator gating, refusals on fields), the form page and store, the actions; `self-protection` is not used (the last-administrator rule is page-level).
- `ui/browser/encryption-key-file.browser-spec.mjs` (new; refuses a non-throwaway as `license-key.browser-spec.mjs` does): Security's eighth entry; create a probe directory over `docker exec`, create a key file through the form, open it, add an administrator and a key through the dialogs, remove the key and the administrator through the typed-name dialog, an existing name refused on the field, no password in the DOM after each step, the DW-1337 gate in both themes on the page, the form and each dialog; cleanup over `docker exec` leaves no probe directory.

**Acceptance Criteria (Part A):**

- **A0:** Given `ocupilot-b-ci`, when the implement stage starts, then Task 0 records the payloads, durations, effects, pairs and audit events of the key-file routes and the reachability of all 13 encryption routes before any descriptor, tool or page exists; no key is activated or deactivated, no encryption setting moves, and S2 equals S0 apart from the declared differences. A contradiction halts the story.
- **A1:** Given a key file at an allowed location, when Encryption key files opens it and the two read tools run with the same `root` and `path`, then each answers the same rows (administrators; keys with identifier, bit length and description), and no answer, DOM, screen context or tool result carries key material or a password.
- **A2:** Given a new location in an existing folder, when a person saves the create form or the agent's proposal is confirmed, then one `File` `POST` creates the file with one key of the chosen length and the named administrator, the screen states the new key's identifier and the backup consequence, and no key is activated; an existing name, a missing folder, a name in the manager directory, a bad length or an empty name or password is refused on its field with nothing sent.
- **A3:** Given a key file, when an administrator is added with the right existing credentials or removed, by either caller, then the vendor write round-trips and the list shows the change after the change event; a taken name, a wrong password, the last administrator and a name gone since the read are refused with the file unchanged.
- **A4:** Given a key file, when a key is added or removed by either caller, then the vendor write round-trips with its consequence stated; removing a key that encrypts OcuPilot's own database, the install namespace's databases, a protected database or the journal is refused `PROHIBITED.OCUPILOTKEY` on both callers with nothing sent.
- **A5:** Given a caller lacking a declared pair, or a raw `file` sent to `AdminPort`, when either caller reads or writes, then it is refused (403 naming the pair, or `PATH.NAME`) with zero vendor calls.
- **A6:** Given the rosters and DW-1774, when the story lands, then Encryption key files is Security's eighth entry with three prompts on each of its three screens, the five keys are in the baseline disabled, every roster includes the screens and tools, every browser side-bar assertion derives its labels from the mirror and `side-bar-pins.test.mjs` refuses a count pin, the DW-1337 gate holds in both themes, and EXPERIENCE.md reads 1019 lines.

## Spec Change Log

- 2026-10-04, spec gate (runner, per the orchestrator merge gate): split approved (18.7 key files; 18.22 key activation; 18.23 startup settings; 18.24 wallet secrets, DW-1555 re-owned); Decisions 1 to 7 confirmed, Decision 3's keys built `false` pending the owner's AD-22 answer, Decision 6's grammar left to the burn-down; amendments 1 to 7 written to the spine and epics.md; the outlines of 18.22 to 18.24 removed (kept at `0a3dfe43`); status `blocked` to `ready-for-dev`.

## Review Triage Log

## Design Notes

**Governing ADs (Part A):**

- AD-2, AD-27, AD-52: `EncryptionPort` extends `AdminPort` and names no vendor class; every call is an admin API route, so no AD-27 case. AD-26: nothing queues (no `ShouldRunAsync` override, no self-queue).
- AD-3: no encryption key-file endpoint publishes a template, so every tool is action-style with declared arguments (AD-51), and no field list is derived.
- AD-5, AD-36, AD-44: one descriptor per screen; one page issuing two declared reads; the classic pages and `CLASSICPAGES`.
- AD-6, AD-34, AD-40, AD-53, AD-55, AD-56: each tool's two callers; the closed confirm channel over the declared secrets; the create's Save through the tool.
- AD-8, AD-29: the own pair and each tool's measured pairs, refused by name before any port call.
- AD-10: the `PROHIBITED.OCUPILOTKEY` arm (Decision 4). AD-13, AD-14: one entity type, its composite id, its change events.
- AD-15, AD-53: vendor events, or named cases per Task 0. AD-21: the key file's sixth-case resolution and `AdminPort`'s guard. AD-22: the baseline. AD-24, AD-35, AD-48: secrets never returned or logged. AD-39: OcuPilot's own sentences. AD-54: the create's absence read. AD-58: read-backs. AD-59: `Snippet`.

**Measured at plan** (read-only on `ocupilot-b-ci`, 2026-10-04; nothing written; no admin API write):

- **The v2 pin is what makes `Security.Encryption.Settings` reachable, not what excludes it.** Its `RunPut` reads `AdminName`/`AdminPassword` from request headers only under API version 1 and from the body otherwise; the body template adds them from version 2; that is the class's only `%request` use, so it needs no CSP state under OcuPilot's pin (read in the vendor source). The inventory's `csp="request"` comes from a scan that matched the version-1 branch, and its `Key` `mutating="0"` misses `DEACTIVATE`, which runs through `Key`'s own `Run` (Story 18.22 corrects it).
- Through `AdminPort` as `irisowner` (`%All`): `Settings` `GET` 200 in 0.6 ms (`DBEncStartMode` "None"; `DBEncJournal`, `DBEncIRISSecurity`, `DBEncIRISTemp`, `AuditEncrypt` false; the KMIP server, key file and both key ids ""); `Key` `LIST` 200 `[]` in 2.0 ms; `Key` `DATAELEMENTLIST` 501 (not in `TYPESUFFIXES`); `Key` `GET` 200 `{}` (the base `RunGet`); `Database.SysCRUD` `LIST` 200 in 4.4 ms, each row carrying `Encrypted` and `EncryptionKeyID`. `messages.log` and the monitor state did not move.
- State: every `Security.System` encryption property off or empty; no activated database or data-element key; 0 of 14 databases encrypted; 0 KMIP server configurations; `PendingRestart` 1 with the two known `MaxServerConn` reasons.
- License: no readable source checks a license for encryption (the five endpoints, the four classic pages, the portal menu, `%SYSTEM.Encryption`); `$SYSTEM.License.GetFeature(0..29)` names no encryption feature; the Community limits page names mirroring, ECP, sharding and API Manager as excluded, so encryption is not license-gated (inference; Task 0 step 4a measures).
- `^EncryptionKey` and `^DATABASE1` are object code only. The classic pages: `RESOURCE` `%Admin_Secure`, none Hidden, `NormalizePage` answers each class name, the `%SYS.Portal.Resources:List` query answered no row.

**Decisions** (confirmed by the orchestrator at the spec gate, 2026-10-04, by=merge_gate):

1. **Placement: Security and secrets, one listed entry.** The classic Encryption menu requires exactly Security's set (`%Admin_Secure` plus `%DB_IRISSYS` READ). The two key-file pages become one listed screen, Encryption key files (8), with the create as an unlisted form, as every OcuPilot create is reached from its list; Story 18.22 adds Database encryption (9) and Data element encryption (10) in the classic menu's order.
2. **The key-file screens declare `%Admin_FileSystemAccess:USE` as their own pair**, narrower than the classic page, because their read resolves a path through `PathPort` (AD-29: a screen that passes its gate must not then fail inside the port); Security's set is unchanged (AD-8's own-pair rule), as Allowed directories already does.
3. **Every key-file tool is advertised and its governance key ships `false`.** Epic 18's preamble makes encryption changes default to disabled. These keys merge after 2026-10-04, so under AD-22 the owner decides how new keys enter; the orchestrator has put that question to the owner and confirms or relays the answer before 18.7 merges. Build them `false`, the conservative default. The agent never holds key material (the vendor generates every key) and a password is typed by the person on the card, as for `permissions.users.password`.
4. **A new AD-10 arm for key removal.** Removing a key from a key file cannot lose data at once (the key stays activated in memory), but if that file holds the last copy, OcuPilot's own database or a protected system database encrypted with it cannot mount after the next start, and journal files encrypted with it cannot be recovered. Which other files hold a copy is unknowable, so the arm refuses removal of any key that encrypts those databases or the journal (read at the write); every other removal stays permitted at the destructive treatment with the vendor's own loss sentence, as the owner's "developer tool first" direction asks. On a stock instance no database is encrypted, so the arm is pinned through the seam.
5. **No password for the removes, as the vendor and the classic page require none.** OcuPilot's gate (Security's set plus the file-system pair) is the check, and the vendor refuses removing the last administrator.
6. **Refusal logging.** A refusal the vendor answers with a distinct status OcuPilot maps to a field (409 taken and last administrator) joins `UNLOGGEDREFUSALS` by endpoint, type and status. A wrong password most likely arrives as a 500 shared with internal failures (inference; Task 0 step 4d measures), which today's list cannot name without silencing real faults; it stays logged, a named limit, until DW-2007's code-scoped entry (decided at the merge gate, built by Epic 18's burn-down) can name its vendor code. The orchestrator ruled the code-scoped grammar stays with the burn-down.
7. **DW-1774 is fixed by derivation, with one literal kept where every story runs it.** Browser specs read an area's labels from the mirror, so a screen-adding story changes no spec it does not run; `navigation.test.mjs` keeps the literal per area, so a wrong `sideBarPosition` still fails a test every story runs (`test:tools`). The lighter variant (labels derived, verdicts asserted only for each leg's subject) avoids a second copy of AD-8's gate rule in the tests.
8. **DW-1555 moves to Story 18.24**, its own story, and is re-owned there: it changes about 30 to 38 files on an independent surface (the Wallet screens), and its product calls (replace versus delete and create; whether imports are advertised; whether public material may be read) are its own.

**Named limits:**

1. `^EncryptionKey` is object code, so what it refuses (an existing file on create, a password policy) is known only from Task 0's measurement; PathPort's `PATH.EXISTS` and the directory refusal keep the two measured hazards (overwrite, directory creation) unreachable.
2. Whether another key file holds a copy of a key is unknowable; `ENCRYPTION.KEYFILE.REMOVEKEY` states the consequence, and the AD-10 arm covers only the self-protection cases.
3. A wrong password, and a chosen file that is not a key file, each log one line and raise the instance's alert state until the code-scoped unlogged entry lands (Decision 6; inference until Task 0 step 4d and 4h measure the statuses).

**Spine and planning amendments (Rule 20; the runner wrote 1 to 7 at the spec gate on 2026-10-04; 8 and 9 come from Task 0, and Task 0 confirms each `<measured>`):**

1. **AD-26, correcting at origin** the sentence "`Security.Encryption.Settings` is excluded by the v2 pin." to: "`Security.Encryption.Settings` touches `%request` only under API version 1, which reads its administrator credentials from request headers; under the v2 pin they travel in the body, so it needs no CSP state (read in the vendor source at Story 18.7's plan) [AMENDED <date>, Story 18.7 spec gate, Rule 20]." The same sentence is corrected in Story 18.7's first acceptance criterion in epics.md (:7212).
2. **AD-21, after the license-key sentence:** "**An encryption key file is a sixth-case location** (Story 18.7): a create names a new file that never overwrites and whose directory must already exist, because the vendor would otherwise create the directory chain; every other key-file call names an existing file as a `source`. `AdminPort` refuses a caller's `file`, `File` or `DBEncStartKeyFile` on any `Security.Encryption.*` call unless it arrives through `EncryptionPort`, which resolves it through `PathPort` at the call [AMENDED <date>, Story 18.7 spec gate, Rule 20]."
3. **AD-36, after the license sentence:** "**A declared read may name the encryption port** (Story 18.7): its `root` and `path` criteria name an existing key file, resolved by `EncryptionPort` through `PathPort` as a `source` at each read; a key file's administrators and its keys' identifiers, lengths and descriptions are row fields, and no read answers key material [AMENDED <date>, Story 18.7 spec gate, Rule 20]."
4. **AD-51, after Story 18.20's case:** "Story 18.7's case: `EncryptionPort`, which builds `Security.Encryption.File`, `AdminInFile` and `KeyInFile` bodies and queries from the key-file tools' declared arguments and the resolved key file, and answers their fresh read through a port-composed `KEYFILE` type [AMENDED <date>, Story 18.7 spec gate, Rule 20]." **AD-56 (i)** gains: "A port-built body (AD-51) may carry the tool's declared secrets beside the arguments it is built from, kept exactly as a secret-only body's (Story 18.7's key-file passwords) [AMENDED <date>, Story 18.7 spec gate, Rule 20]."
5. **AD-13, after the ECP sentence:** "**An `encryption-key-file` id is the composite of its `root` and `path`, kept exactly** (Story 18.7) [AMENDED <date>, Story 18.7 spec gate, Rule 20]."
6. **AD-44, after Story 18.21's sentence:** "**Story 18.7's `CLASSICPAGES`**: the key-file create declares `%CSP.UI.Portal.EncryptionCreate`, and the administrator and key adds `%CSP.UI.Portal.Dialog.EncAddAdmin`; the removes, performed on `%CSP.UI.Portal.EncryptionManage` itself, declare none [AMENDED <date>, Story 18.7 spec gate, Rule 20]."
7. **AD-10, a new arm:** "**Keys OcuPilot or the instance depends on** (Story 18.7): removing from a key file a key that encrypts OcuPilot's own database, the install namespace's globals or routines database, one of the seven protected databases, or the journal, read at the write, is refused `PROHIBITED.OCUPILOTKEY`, from either caller; a read that fails refuses. Every other key removal is permitted at the destructive treatment [AMENDED <date>, Story 18.7 spec gate, Rule 20]."
8. **AD-8, after Story 18.21's paragraph:** "**Story 18.7's Encryption key files declare `%Admin_FileSystemAccess:USE` as their own pair** beside Security's set, because their read resolves a key file through `PathPort`; the key-file writes declare <measured pairs>, and `removekey` also declares <measured pair> for its self-protection read; each is refused by name before any port call [AMENDED <date>, Story 18.7 Task 0, Rule 20]."
9. **AD-15 and AD-53**, only where Task 0 step 6 finds no vendor event: "Creating an encryption key file, adding or removing its administrators or keys (Story 18.7): no vendor event records it with auditing on <measured>." The AD-53 ordinal is the next after both Epic 18's and Epic 19's lists.

**Integration ACs.** `EncryptionPort`, `EncryptionRules`, `EncryptionKeyFileSave`, the `encryption` read source and `side-bar-spec.mjs` are new; each consumer is in this story:

- The key file page consumes the `encryption` read source for both lists on `ocupilot-b-ci` (A1; `EncryptionKeyFileRead`, the browser spec).
- The form consumes `POST /encryption-key-file` and the dialogs consume `POST /screens/:screen/action`, each against real probe files (A2 to A4; `EncryptionKeyFileWrite`, the browser spec).
- Every converted browser spec consumes `side-bar-spec.mjs` (A6; `side-bar-pins.test.mjs` and CI's browser shards).

**Consumes:** 18.1 (`PathPort` and its picker), 16.4 (`TaskTransferPort`'s file-consumer model), 18.6 (`LicensePort`'s secret body, the seam and probe shape), 18.3 (Prohibited's protected database set), 18.14 (composite targets), 19.4/19.5 (`list (server criteria)` over a criteria-carrying port), 16.17's read-back, 14.1's `Snippet`, 14.2's baseline. **Consumed-by:** Story 18.22 (activation names a key file as a `source` through `EncryptionPort`), Story 18.23 (the unattended startup key file), Stories 18.8 and 18.9 (the side-bar helper), 18.12 (the agent's grown tool set).

**Ledger inbox (Rule 17):** DW-1774 is addressed in Part A (the helper, every conversion, the guard test). DW-1555 was re-owned to `18-24-rsa-and-symmetric-key-wallet-secrets` at the spec gate (Decision 8). `ledger.sh slice 18-7-encryption` holds DW-1774 alone.

**Footprint (Rule 11).** Every contended file is edited add-only (Boundaries). New or outside the listed set, for `footprint_extensions`: `Port/EncryptionPort.cls`, `Port/AdminPort.cls`, `Area/Security/EncryptionRules.cls`, `EncryptionKeyFileSave.cls`, `Api/EncryptionError.cls`, `Api/Error.cls` (two dispatch lines), `Screen/Read.cls`, `Screen/Registry.cls`, `ui/tools/screen-mirror.mjs`, `ui/browser/side-bar-spec.mjs`, `ui/tools/side-bar-pins.test.mjs`, and the seventeen converted browser specs.

**Size (Part A).** Three descriptors (two sharing one page), five write tools and two read tools, one new port, one read source, two area classes, a form page and store, a page and store with two dialogs, the side-bar helper with seventeen spec conversions; about Story 18.6 Part A's size plus DW-1774 (inference).

## Verification

**Setup (slot B, Part A):**

- Load with `/tmp/epic-18-d6/load-throwaway.sh`, with no restart, never through the MCP loader. Every write lands on `ocupilot-b-ci`, in `OCUPROBE187` probe directories and on `OcuProbe187*` principals only.
- One test class per call; send the next only once the previous has landed in `%UnitTest_Result`; never re-submit after a client-side timeout.
- Arm per call with `docker exec -e OCUPILOT_ALLOW_ENCRYPTION_CONFIG=1 -e OCUPILOT_ALLOW_PRINCIPALS=1`.
- Before any browser run: `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci` exported.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one at a time; expected 0 failures, totals checked against `%UnitTest_Result`.
  - The story's classes: `EncryptionKeyFileRead`, `EncryptionKeyFileWrite`, `EncryptionWriteGate`, `EncryptionDescriptor`.
  - The rosters: `Descriptor`, `ReadTool`, `SurfaceCoverage`, `EndpointCoverage`, `Navigation`, `Wire`, `WireSecurityRead`, `WireOAuthRead`, `WireAreaAnyScreen`, `PortGate`, `ClassicPageGate`, `MappingDescriptor`, `DraftRegistry`, `ToolRoundTrip`, `ToolWrite`, `Prohibited`, `GovernanceBaseline`, `Governance`, `ToolDispatch`, `ToolEmit`, `EntityRef`, `ScreenRead`.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/encryption-key-file.browser-spec.mjs` and every browser spec DW-1774 converts (Code Map › Browser side-bar pins); expected pass.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`, then `uv run scripts/check-objectscript.py <changed .cls>` and `bash scripts/lint-docs.sh`; expected clean, and `wc -l` on EXPERIENCE.md reads 1019.
- `(once, before dev_complete)`, each green with a non-zero count:
  1. the full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci`, one class at a time;
  2. `cd ui && npm test && npm run build`;
  3. `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`;
  4. afterwards no `OCUPROBE187` directory, key file or principal remains; every `Security.System` encryption property, the activated keys, the `PendingRestart` reasons and the monitor state read as at S0.
- `(CI)` The full browser suite runs in CI's three `browser-shard` jobs (Rule 29).

**Planned pinning mutations (Rule 19).** Apply each on the throwaway, observe red, revert byte-identical, and record a `mutation:` line here:

- A1: the `encryption` branch passes the caller's `path` unresolved → `EncryptionKeyFileRead`'s resolution leg red; `KEYFILE` adds a key's raw material member → the no-key-material leg red.
- A2: `EncryptionPort`'s create resolves with overwrite 1 → `EncryptionKeyFileWrite`'s existing-name leg red with a `POST` recorded; the missing-directory refusal dropped → its leg red.
- A3: `EncryptionKeyFileAddAdmin.StateDiff` admits a listed name → the taken-name leg red with a `POST` sent; `EncryptionKeyFileRemoveAdmin.StateDiff` admits the last administrator → the last-administrator leg red.
- A4: the `KeyRemoval` arm dropped from the guard → the seam's protected-key leg red on both callers.
- A5: `AdminPort`'s `PATHRESOLVED` guard removed → `EncryptionDescriptor`'s raw-`file` leg red; a tool's `PrivilegePairs` drops `%Admin_FileSystemAccess:USE` → `EncryptionWriteGate` red.
- A6: `security.encryptionkeyfile.removekey` dropped from the baseline → `GovernanceBaseline` red; `EncryptionKeyFile` `sideBarPosition` 0 → `Navigation` and `navigation.test.mjs` red; a literal `entries.length, 19` restored in one OS management spec → `side-bar-pins.test.mjs` red.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

- **Planned:** Part A, Encryption key files with DW-1774 and the 13-route reachability Task 0 (Boundaries, matrix, Code Map, Task 0 with its halt conditions, server and client execution, rosters, tests, ACs A0-A6, Verification in Rule 29's shape, planned mutations), self-reviewed against the READY-FOR-DEVELOPMENT standard.
- **Spec gate:** the orchestrator approved the split and Decisions 1 to 7 on 2026-10-04; the runner wrote amendments 1 to 7 and trimmed the other parts' outlines.
- **Measured at plan:** read-only on `ocupilot-b-ci` (Design Notes › Measured at plan); no write to any instance, no admin API write, no activation, no restart. EXPERIENCE.md reads 1019 lines on this tree.
