---
title: 'Story 18.23: Encryption startup settings'
type: 'feature'
created: '2026-10-05'
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

**Problem:** The classic Database Encryption page's Configure Startup Settings (`%CSP.UI.Portal.EncryptionDatabase`) is still the only place to choose how the instance activates its database encryption keys at startup, which system databases, journal files and audit log it encrypts, and which active key is the default and the journal key. The admin API carries it as `Security.Encryption.Settings` `GET` and `PUT`. DW-2065 rides along: removing the key file administrator that unattended activation opens the startup key file as is not refused.

**Approach:** Add an unlisted form, **Encryption startup settings**, reached from Database encryption, with one merge tool on Story 18.7's `EncryptionPort` behind an explicit version gate. Each option states its consequence. An `AuditEncrypt` change takes the destructive treatment on both callers (owner decision 2026-10-05). A Task 0 on `ocupilot-b-ci` runs the reads, refusals and an unchanged `PUT` first, and last one real activation to time `AuditEncrypt`'s deletion; it is planned to end with a throwaway rebuild. Every value change in the build's tests runs through a seam. DW-2065 adds an AD-10 refusal to 18.7's administrator removal.

## Boundaries & Constraints

**Always:**

- **Task 0 runs first, on `ocupilot-b-ci` only**, before any descriptor, tool or page (Tasks › Task 0). Probe objects use the prefix `OCUPROBESTART`: key files under `<ManagerDirectory>ocuprobestart/`, principals `OcuProbeStart*`. No other suite's prefix matches it and it matches none (`OCUPROBE1823` would fall under Story 18.2's `OCUPROBE182`).
- **Screen** (Security and secrets; unlisted, `sideBarPosition` 0; reached from Database encryption's "Configure startup settings" link):

  | Descriptor | Route | Archetype | Entity type (singleton, id `SYSTEM`) | Read | `classicPage` | `toolIdentifier` |
  | --- | --- | --- | --- | --- | --- | --- |
  | `EncryptionStartup` | `security/database-encryption/startup` | `form-page` | `encryption-startup` | admin `Security.Encryption.Settings` `GET`: `DBEncStartMode`, `DBEncJournal`, `DBEncIRISSecurity`, `DBEncIRISTemp`, `AuditEncrypt`, `DBEncStartKMIPServer`, `DBEncStartKeyFile`, `DBEncDefaultKeyID`, `DBEncJournalKeyID` | `%CSP.UI.Portal.EncryptionDatabase` | `security.encryptionstartup` |

  - Privileges: Security's `%Admin_Secure:USE` and `%DB_IRISSYS:READ`, with no own pair.
  - `id` `{"kind": "single"}`, `secretArguments` `["AdminPassword"]`, three prompts (`userPromptGroupAccess`), and no auto-refresh.
  - The page also issues Database encryption's declared read for the active keys (AD-5).
- **Tool** `security.encryptionstartup.update` (`Screen/Tool/EncryptionStartupUpdate.cls`):
  - merge write on `EncryptionPort` (`READTYPE` `GET`, `WRITETYPE` `PUT`, `SENDSBODY` 1);
  - advertised, governance key `false`, no `CLASSICPAGES`;
  - its second caller is the form's Save, `PUT /api/ocupilot/encryption-startup` (AD-55).
- **The body** (AD-4, the vendor's own `RunPut` and `ValidateRequest`, read in source):
  - **Always sent:** `DBEncStartMode`, the four booleans, `AuditEncrypt`, `DBEncStartKMIPServer` and `DBEncStartKeyFile`, as the fresh read holds them with the change applied. The vendor requires all seven.
  - **`AuditEncrypt` keeps its fresh value unless the person or the proposal changed it**, so a start-mode change never alters it (Decision 1, which restates the orchestrator's ruling).
  - **Sent only when changed:** `DBEncDefaultKeyID` and `DBEncJournalKeyID`, each the id of an active database key.
  - **`DBEncStartKeyFile` is composed by the port, never by a caller** (AD-21's sixth case, a `source`). For Unattended it is `root` + `path` resolved through `PathPort`, or the stored file when neither is sent; for every other mode it is `""`, as the classic page sends.
  - **`AdminName` and secret `AdminPassword`** are sent only for Unattended with a key file that is not the stored one, as the classic page asks (`:401-405`).
- **Explicit version gate** (the epics criterion): `EncryptionPort` refuses the `PUT`, at the mint, the Save and the confirm, unless the endpoint's own body template (`AdminPort.Template`, built at API version 2) carries both `AdminName` and `AdminPassword`. The refusal is 501 `PORT.NOTIMPLEMENTED` with `EncryptionError.REASONSETTINGSVERSION`, sent with zero `PUT`. A test pins it.
- **Rules before any vendor call, on both callers**, each a violation on its field with nothing sent:
  - KMIP needs a configured KMIP server named in `DBEncStartKMIPServer`.
  - Unattended needs a key file.
  - A new key file needs an administrator listed in it and a password (`EncryptionRules`).
  - Turning on `DBEncJournal`, `DBEncIRISSecurity`, `DBEncIRISTemp` or `AuditEncrypt` needs a start mode other than None. This covers the vendor's silent no-op (`RunPut`'s own comment) and #1218.
  - The same flags need an active database key (#1235).
  - A changed default or journal key id must be active.
- **`AuditEncrypt` is treated as `security.auditing.purge` is** (owner decision 2026-10-05):
  - A proposal that changes it is minted `destructive`, through the new effect `AUDIT.ENCRYPTIONCHANGE` in `Prohibited.WeakensByEffect`, and carries that consequence.
  - The form's Save first opens the shared typed-name dialog (`shell/typed-name-dialog.ts`), typed name `IRISAUDIT`. Its body says every audit record, the agent's own markers included, is deleted; its advisory suggests copying or purging on Auditing first.
  - The screen's Save is not governed.
- **DW-2065 (owner, binding):** removing an administrator from a key file is refused `PROHIBITED.STARTUPADMIN` from either caller when the instance's stored startup key file is that file and its stored startup administrator is that administrator, read at the write. A read that fails also refuses.
- **Secrets are write-only** (AD-35, AD-56). `AdminPassword` is:
  - never returned, never stored in a proposal, the ledger, screen context, a store or a log line, and never queued;
  - rendered `"<AdminPassword>"` in a copy-out draft;
  - typed by the person on the agent's card (a masked row, required whenever the payload carries it) or into the form's page-local masked field, cleared on save, leave and destroy.
- **Error codes** go in `Api/EncryptionError.cls`; `Api/Error.cls` gains nothing. `PROHIBITED.STARTUPADMIN` lives in `Kernel/Proposal/Prohibited.cls` beside the other `PROHIBITED.*` codes, its sentence published in EXPERIENCE.md's Fixed strings and pinned.
- **Each test class stands alone** on a fresh stock instance and ends with `EncryptionProbe.EncryptionFacts` (`DBEncStartMode` included) and the audit facts (event count delta aside, `IRISAUDIT`'s file identity and `EncryptedDB`) as it found them. No probe file or principal may remain.
- **Contended files are edited add-only** (Epic 19 runs on slot A):
  - kernel and registry: `Kernel/Proposal/Prohibited.cls`, `Kernel/Governance/Baseline.cls`, `Api/Router.cls`;
  - client: `core/strings.ts`, `shell/screen-outlet.ts`, `ui/angular.json` with its test;
  - EXPERIENCE.md: lines 168, 173, 364 and 516 only;
  - CI: the test rosters, `scripts/ci-throwaway.sh`, `ui/tools/navigation.test.mjs`.

  `screens.generated.ts` and `ToolFields.cls` are regenerated, never hand-merged. Not touched: `Screen/Registry.cls`, `Screen/Read.cls`, `ui/tools/screen-mirror.mjs`, `shell/screen-action-handler.ts`, `core/screen-actions.ts`, `Api/Error.cls`.

**Never:**

- No test or build leg changes a startup setting on any real instance except Task 0's ordered legs on `ocupilot-b-ci`. Every value change in a test class runs through `Test/EncryptionSeamPort`.
- No restart except Task 0's graceful `docker restart -t 120 ocupilot-b-ci` to measure a restart-time effect, and never `down`, `up` or a rebuild. No write to `ocupilot-slot-b`.
- No KMIP server configuration, no IRISSECURITY, IRISTEMP or journal encryption on any instance; their consequences come from the classic page's hints and the vendor documentation (read).
- No `%Api.Admin.*` name outside `AdminPort` and its subclasses. No `Security.System`, `^EncryptionKey` or `%SYS.Audit.Erase` call in product code except the AD-27 reads below; test-only seeding and cleanup in `%SYS` are allowed.
- No spine or epics.md edit in the implement stage; Task 0 records each AD sentence in `## Spec Change Log` for the runner.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
| --- | --- | --- | --- |
| Read | Stock instance | Screen and `security.encryptionstartup.read` answer one row: mode `None`, four `false`, five `""`. No password in any answer | none |
| Start mode (seam) | Interactive, then Unattended with probe file, administrator and typed password, then KMIP with an armed server, by Save and by confirmed proposal | One `Settings` `PUT` each. Body keys as Boundaries list; `AuditEncrypt` equals the fresh read; credentials only on the new-file Unattended leg; read-back `matches` | none |
| Encryption flags (seam) | Journal, IRISSECURITY, IRISTEMP on, with a seam-active key and Interactive | One `PUT`; each flag's consequence code on the card | none |
| Default and journal key (seam) | Two seam-active keys; choose the other as default, then as journal key | `PUT` carries only the changed id | none |
| Audit encryption (seam) | `AuditEncrypt` true with Unattended and a seam-active key | Proposal `destructive`, consequence `AUDIT.ENCRYPTIONCHANGE`; Save opens the typed-name dialog first, the `PUT` only after `IRISAUDIT` is typed | none |
| Refused before `PUT` | KMIP with none configured; Unattended with no file; new file without password or with an unlisted administrator; a flag on with None; a flag on with no active key; an inactive key id | Refused on its field; zero `PUT` | 422 `ENCRYPTION.STARTUP.KMIPSERVER`, `.KEYFILE`, `ENCRYPTION.KEYFILE.CREDENTIALS`, `ENCRYPTION.STARTUP.NEEDSSTART`, `.NOKEY`, `.KEYINACTIVE` |
| Version gate | Seam answers the template without `AdminName`/`AdminPassword` | Mint, Save and confirm refused; zero `PUT` | 501 `PORT.NOTIMPLEMENTED` (`REASONSETTINGSVERSION`) |
| Vendor refusal (seam) | Seam answers Task 0's measured codes (startup required, credentials) | Mapped to OcuPilot's sentences; no vendor text sent | 409 `ENCRYPTION.STARTUP.REQUIRED`; 422 credentials (per Task 0) |
| Password secrecy | Writes carrying a marker password | Marker in no log line, ledger row, proposal, store, screen context, answer or DOM after save | none |
| DW-2065 (seam) | Seam reports the stored startup key file and administrator as the probe file's listed administrator; and a failed read | Removing that administrator refused on both callers before anything is sent; another administrator is removed | 403 `PROHIBITED.STARTUPADMIN` |
| Link and placement | The story lands | Database encryption shows "Configure startup settings"; the form is unlisted, reached from it | none |

</intent-contract>

## Code Map

**Vendor** (exported at `/tmp/epic-18-d7/vendor/Settings.cls`; file lines, first 4 are a banner; re-export with `GetTextAsString` in `%SYS` if gone):

- `%Api.Admin.Endpoints.Security.Encryption.Settings`: `ResourcesOR` `%Admin_Secure` :17-20.
  - `RunGet` :22-47: mode as `None`, `Interactive`, `Unattended`, `KMIP`; booleans; KMIP server and key file stored; key ids from the running `GetDBEncKeyID()` and `GetJrnEncKeyID(2)`; no `DBEncStartUsername`.
  - `RunPut` :49-102: credentials from the body under v2. `$$ConfigStart^DATABASE1(mode, DBEncJournal, DBEncIRISSecurity, DBEncIRISTemp, keyFile, adminName, adminPassword, AuditEncrypt)` :82. KMIP passes `DBEncStartKMIPServer` as the key file :73-75. The "answers OK without applying" comment is at :78-81. Key ids are set by `SetDBEncKeyDefault` and `SetJrnEncKey` only `If req.%IsDefined(...)` :86-96, with `sys.%Save()` before the error check :97.
  - `RequestBodySchema` :104-122 adds `AdminName` and `AdminPassword` only `If ..ApiVersion >= 2`.
  - `ValidateRequest` :124-139: `RequestValidator(schema, 1)`, every field required except the key ids and credentials. A missing `AuditEncrypt` is `MissingRequestBodyField`, 400 (`/tmp/epic-18-d7/vendor/%Api.Admin.Util.RequestValidator.raw`:108-118).
- `Security.Encryption.Key` has no default or journal type, so the `Settings` `PUT` is the only route for them.
- `irissys/%CSP/UI/Portal/EncryptionDatabase.cls` (`RESOURCE` `%Admin_Secure` :20):
  - options :102 (`Unattended (NOT RECOMMENDED)`); KMIP only when `Security.KMIPServer:List` has a row :157-170;
  - hints :116-123 and the audit warning :212;
  - `doSaveStartup` :378-455 (None sends all four flags 0); credentials rule :401-405; `SaveStartup` :525-541; `SetDefaultKey` :543-563.
- `irissys/Security/System.cls`:
  - `AuditEncrypt` :32-41 (deleted as soon as modified, either direction);
  - `DBEncIRISTemp` :120, `DBEncIRISSecurity` :129, `DBEncJournal` :149, `DBEncStartMode` :158-159 (Internal);
  - `DBEncStartKeyFile` :162, `DBEncStartUsername` :165, `DBEncStartPassphrase` :168, `DBEncStartKMIPServer` :171.
- `irissys/%SYS/Audit.cls:883-985` `Erase(Flags)` (no readable caller); `irissys/%SYS/DATABASE.int:686-800` `MakeIRISAudit` (converts in place at startup, keeping data).
- `irissys/Security/KMIPServer.cls:149` query `List`.
- Error texts measured on the throwaway: #1212, #1213, #1217, #1218, #1222, #1223, #1231, #1233-#1235, #1238 (`/tmp/epic-18-d7/1823/plan/probes.txt`).

**Ports** (`src/OcuPilot/Port/`):

- `EncryptionPort.cls` (916 lines):
  - `Invoke` :151-217. The `NamesKeyFile` guard at :159 refuses a body carrying a non-empty `DBEncStartKeyFile`, so the tool's body never carries it.
  - The `Activate` branch :171 is the secret-body model; `JournalUse` :566-595 is the AD-27 `%SYS`-read model; `Resolve` :129, `Source` :240, `Administrators` :250, `Keys` :279, `ActiveKeys` :523, `Values` :734, `Listed` :756, `Mapped` :770.
  - `Snippet` / `KeySnippet` are in the file's tail (:777-916).
- `AdminPort.cls`:
  - `Template` :1396 constructs the endpoint at `APIVERSION` 2 (:65), and `TemplateMethod` :1366;
  - `NamesKeyFile` :615-636 (refuses `DBENCSTARTKEYFILE` when non-empty), `InvokeLocated` :1170-1195, `MUTATINGTYPES` :455 (already holds `Security.Encryption.Settings/PUT`);
  - `UNLOGGEDREFUSALS` :598, `PROPERTYFAULTS` :3259 (`@=` request-level form);
  - `Snippet` :3446, `RestStep` :3480.
- `AtelierPort.cls:874-878`: the 501 `PORT.NOTIMPLEMENTED` version refusal model.
- `JournalPort.cls`: `Without` :368 and `SHOWNONLYKEYS` :80, the model for stripping keys from the fresh read.

**Tool and kernel models:**

- `Screen/Tool/JournalSettingsUpdate.cls` is the merge model: `PERMITTEDFIELDS`/`EXCLUDEDFIELDS`, `MergeUpdate` stripping keys, `ArgumentProblem`/`ConfirmProblem`, `DerivedFields`, `PortQuery`, `Consequence`, `PrivilegePairs`, `ArgumentPairs` for the path port's pair.
- `Screen/Tool/EcpSettingsUpdate.cls:198-203`: a conditional `Consequence`.
- `Screen/Tool/AuditPurge.cls`: `DESTRUCTIVE`, `AUDIT.PURGEMARKERS` :31, key `false` at `Kernel/Governance/Baseline.cls:86`.
- `Screen/Tool/Write.cls`: `DESTRUCTIVE` :52, `Destructive()` :523, `SecretArguments` :578, `SecretFieldNames` :601, `ChannelSecretNames` :632.
- `Kernel/Proposal/Mint.cls:316-338`: `WeakensByEffect` at :331 sets `tEffect`; `destructive` and `ConsequenceOf` :758 follow.
- `Kernel/Proposal/Confirm.cls`: governance :318, `WithSecrets` :436 and :758, apply :459. `Kernel/Proposal/Operation.cls`: `Gate` :362 (no governance for a screen), `ApplyAt` :437.
- `Kernel/Proposal/Prohibited.cls`:
  - `EFFECT*` parameters :131-647 (model `EFFECTNOPEERCHECK` :236), `OCUPILOTKEY` :523, `OCUPILOTKEYREASON` :527, `KEYREMOVALENDPOINT` :530;
  - `Codes()` :760 (27), `ReasonFor` :768;
  - `PermittedChangeFields` :879 (key file :916), `Prohibits` :1103, the fail-closed type list :1114, `COVEREDTYPES` :250 (43);
  - the dispatch :1316-1318 to `KeyFile` :2500 (`AdminInFile` `DELETE` falls to `ReviewedFewOnly` :2514), `DependsOnKey` :2528 (its `Settings` `GET` :2552);
  - `WeakensByEffect` :1566 (model `SslWeakening` :4566).
- `Kernel/EntityType.cls:80` `TYPES` (54, last `data-element-encryption-keys`); `Kernel/EntityRef.cls:59` `IDRULES` (28; singletons end `data-element-encryption-keys:singleton`).
- `Kernel/Governance/Baseline.cls:94-102`, the encryption keys, all `false`.
- `Screen/Tool/FieldLists.cls:305-317` already derives `Security.Encryption.Settings` (11 rows with `AdminName`, `AdminPassword`). `Screen/Tool/Classification.cls` has no entry; the model is `osmgmt.ecpsettings.update` :723-734, and the `compare` vocabulary includes `written` (:13-17). Regenerate with `cd ui && node tools/field-lists.mjs`.
- `Area/OsMgmt/EcpSettingsSave.cls` (Save, `Consequence` read :130) and `EcpSettingsRules.HandleForm` (form read); `Area/Security/EncryptionKeyFileSave.cls` (a Save carrying `AdminPassword` :27, :117, :146-169).
- `Api/Router.cls:240-241` and `:1769-1781` (the ECP routes and thin `Call=` targets).
- `Api/EncryptionError.cls` (155 lines): `Codes()` :111 (15), `ViolationCodes()` :118 (6), `FieldOf` :124, `ReasonFor` :135. `Area/Security/EncryptionRules.cls`: `NAMEFIELDS` :23, `PASSWORDFIELDS` :25, `Violations` :32, `Fault` :95.
- `Screen/Descriptor/EcpSettings.cls` (form-page singleton over an admin `GET`) and `DatabaseEncryption.cls` (Security pairs, `secretArguments`).

**Client** (`ui/src/app/`):

- `areas/os-management/ecp-settings.page.ts` and `.store.ts` are the form model:
  - read with the form read in parallel (store :243-272);
  - dirty state :375-381, changed-only body :344-355, `PUT` :312-333;
  - refusals on fields :186-188 and :320-321, the sticky bar (page :171-188), the leave guard (:190-196);
  - an `aria-disabled` choice with its reason (page :144-167 and :315-375).
- `areas/os-management/journal-settings.page.ts`: the `server-path-picker` (:139-148, `AllowedDirectoriesStore` :306-307); `shell/server-path-picker.ts:110-131`.
- `areas/security/encryption-keys.page.ts`:
  - template :69-147; route follow :428-437 (`databaseKeys` :220-222); the masked password and `clearDialog` :129-135 and :448-457.
  - The cross-link model is `areas/security/auditing-config.page.ts:175-179` and :416-458 (`withQuery`, `core/navigation.ts:696`).
- `shell/typed-name-dialog.ts:94-115`: `verb`, `target`, `consequence`, `advisory`.
- `shell/screen-outlet.ts`: `DESCRIPTOR_PAGES` :146, with 18.22's entries at :225-226.
- `core/proposal-view.ts`: consequence codes :286-296, `consequenceSentence` :322-380, masked and optional secrets :604-646. `ui/tools/proposal-view.test.mjs:905-918` pins each code to its tool's parameter.
- `app.ts` :362-363, :692-696 and `app.spec.ts` :1310-1316, :1475-1481 (the store model). The write-only password models are `areas/security/ssl-form.store.ts:301`, :493-497.
- `core/strings.ts`:
  - 18.22's block :5584-5648 (append after it, not at `} as const` :5712);
  - reused keys: `encryptionKeyFileAdminName` :5494, `fieldPassword` :297, `pathPickerRootLabel` :826, `pathPickerFileLabel` :830, `actionSave` :111, `actionCancel` :109, `formSaved` :281, `formLeaveWithoutSaving` :285, `encryptionKeyFileColumnId` :5474, `formTypedNameConfirm`.
- `ui/tools/strings.test.mjs:586`: bound 2700, with 2634 used on this branch and about 2650 after Epic 19's merge. `ui/angular.json:54` `maximumWarning` 2929kB, pinned at `ui/tools/angular-json.test.mjs:516` (history :499-503). `maximumError` is 4000kB.
- `ui/tools/navigation.test.mjs:248-279`: built-screens roster (the unlisted Security routes in descriptor-class order, `EncryptionStartup` after `security/encryption-key-file/create` :252); `:585-589` the listed literal (unchanged).
- `ui/browser/encryption-keys.browser-spec.mjs` (guard :107-110, facts :100-105 and :130-140, DW-1337 :174-202) and `ui/browser/ecp-settings.browser-spec.mjs` (Save capture :277-303, refusal :306-320).

**EXPERIENCE.md** (`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`, 1036 lines):

- :168 Security's side-bar row, ending "...copy/purge and the OAuth editors attach to existing screens |";
- :173 Dialogs;
- :364 Fixed strings' Security row, with 18.22's clause last;
- :516 the audit purge row.

**Rosters** (current counts; re-derive each change from its class's red, never by hand):

- Descriptors and reads:
  - `Test/Descriptor.cls`: `ReadShapes` :67-173 (103), entity count :1747 (54);
  - `Test/ReadTool.cls`: :93 (272), :94, :112;
  - `Test/SurfaceCoverage.cls`: screens :57-198 (142), tools :199-361 (163).
- Governance:
  - `Test/Prohibited.cls`: :232 (43), :438, :480-483;
  - `Test/GovernanceBaseline.cls:15` (36 disabled);
  - `Test/Governance.cls:48` `ENCRYPTIONDISABLED` (9), read by `Test/ToolDispatch.cls:173`.
- Tools:
  - `Test/ToolRoundTrip.cls:72` (198);
  - `Test/ToolWrite.cls:80` `AHEADTYPES` (`Security.Encryption.Settings/PUT`, emptied by this story);
  - `Test/DraftRegistry.cls:77` (7).
- Classic pages and codes:
  - `Test/ClassicPageGate.cls` :75 (54), :85 (3);
  - `Test/MappingDescriptor.cls:24` (58);
  - `Test/EncryptionDescriptor.cls:80` (`Codes()` 15).
- Security pins (28 routes each, unlisted first, alphabetical; the new route joins):
  - `Test/Wire.cls:600`;
  - `Test/WireSecurityRead.cls` :807, :957, :985, :1093, :1112;
  - `Test/WireOAuthRead.cls` :275, :295, :315, :331, :350.
- CI: `scripts/ci-throwaway.sh` `OCUPILOT_ALLOW_ENCRYPTION_CONFIG` :536-547 and `OCUPILOT_ALLOW_PRINCIPALS` :329-334; `ui/tools/ci.test.mjs:2157-2177` derives the `# classes:` rosters.

**Test models:**

- `Test/EncryptionProbe.cls`: `SYSTEMPROPERTIES` :42 (has `AuditEncrypt`, `DBEncStartMode`, the KMIP server, the key file, both ids); `SeedKeyFile` :126, `SeedPrincipal` :218, `RunAs` :346, `PendingRestart` :394, `EncryptionFacts` :421 (`DBEncStartUsernameSet` :432), `Snapshot` :469, `Diff` :553.
- `Test/EncryptionKeyProbe.cls`: `RESTOREDPROPERTIES` :31, `Restore` :177.
- `Test/EncryptionSeamPort.cls`: modes :5-35, `Call` :43, `Invoke` :88, `Arm` :217, `ArmCredentials` :289, the activation guard in `Call`. `Test/SeamEncryptionKeyFileRemoveAdmin.cls` overrides only `PORTCLASS`; `Test/EncryptionActionFixture.ToolFor` :13-21.
- `Test/EcpSettingsSaveFixture.cls` and `Test/SeamEcpSettingsUpdate.cls` (a Save's seam); `Test/EncryptionKeyFileWrite.cls` `TestAKeyTheInstanceDependsOnIsNotRemovedOnEitherCaller` (DW-2065's legs join beside it).

## Tasks & Acceptance

**Task 0, the implement stage's first task, before any descriptor, tool or page.**

Setup:

- Run it on `ocupilot-b-ci` only. Load with `/tmp/epic-18-d7/load-throwaway.sh` (rsync, `LoadDir`, `StartPath`; no restart), so a restart's start hook compiles the same source.
- Keep evidence under `/tmp/epic-18-d7/1823/t0/`. Record each result under Design Notes › Measured at implement, and each AD sentence in `## Spec Change Log` for the runner.
- After every write step, re-read: `EncryptionFacts`; the audit facts (`SELECT COUNT(*) FROM %SYS.Audit`, `IRISAUDIT`'s `EncryptedDB`, `docker exec ocupilot-b-ci stat -c '%i %s %Y %W'` of its `IRIS.DAT`, the newest `AuditChange` row); `PendingRestart`; and new `messages.log` and `alerts.log` lines.

*Part A, reads and non-destructive steps:*

1. **Plumbing** (add-only): `EncryptionPort`'s `Settings` `PUT` branch with the version gate and the rules; `STARTUPADMIN` and `KMIPSERVERS` (Execution); `Test/EncryptionStartupProbe.cls` (Tests).
2. **S0.** Take `EncryptionProbe.Snapshot` plus the audit facts. The plan read everything at S0, with an audit count of 222,237 and `IRIS.DAT` inode 12766 (Measured at plan).
3. **Reads, timed.** `Settings` `GET` through `AdminPort` and through the declared read, `KMIPSERVERS` and `STARTUPADMIN` for a probe file. Run each as `_SYSTEM` and through `RunAs` as a principal holding exactly Security's two pairs, plus `%Admin_FileSystemAccess:USE` for `STARTUPADMIN` (`removeadministrator`'s pairs).
4. **Version gate.** `AdminPort.Template("Security.Encryption.Settings")` carries `AdminName` and `AdminPassword`.
5. **Refusals before any `PUT`**, through `EncryptionPort`, each with `Settings` `PUT` never reaching the vendor (facts unchanged):
   - every refused row of the I/O matrix that needs no active key;
   - an unknown mode.
6. **The vendor's validation**: a `PUT` body lacking `AuditEncrypt`, sent test-only through `AdminPort`. Expected: 400 `MissingRequestBodyField`, nothing changed (Decision 1).
7. **The unchanged `PUT`**: the complete body as read (`None`, four `false`, `""` ×2, no credentials, no ids). Record status, duration, facts, audit rows and the audit identity.
8. **Pairs** on step 7's `PUT` through `RunAs`:
   - start with exactly Security's two pairs; retry a refused attempt adding `%DB_IRISSYS:WRITE`, `%Admin_Manage:USE` or `%Admin_Operate:USE` alone;
   - re-read the facts after each refused attempt.

*Part B, destructive and restart-time; last, ordered as written:*

9. **Seed** `start-a.key` (one 256-bit key K1, administrator `OcuProbeStartAdmin`) under `<ManagerDirectory>ocuprobestart/`.
10. **The one real activation**: K1 through `EncryptionPort` `ActivateDB` as `_SYSTEM`. Expected: `DBEncStartMode` 0 to 1, as 18.22 measured.
11. **Unattended**: a `PUT` through `EncryptionPort` with `root`/`path` for `start-a.key`, `AdminName` `OcuProbeStartAdmin` and its password, `AuditEncrypt` unchanged. Record:
    - the `GET`;
    - `Security.System`'s `DBEncStartKeyFile`, `DBEncStartUsername` (the typed name or a hidden generated one) and whether `DBEncStartPassphrase` is set;
    - `AdminInFile` `LIST` of the file;
    - `STARTUPADMIN` for the stored and for the typed name;
    - the audit rows.
12. **Audit encryption on** (`PUT`, Unattended unchanged). Right after it, record the audit facts and whether OcuPilot's own registered marker event records (`$System.Security.Audit` answers 1 and the row is readable).
13. **Graceful restart**: `docker restart -t 120 ocupilot-b-ci`, then wait for the health check, at most 10 minutes. Record unattended activation (`messages.log`), the active keys and the audit facts.
14. **Audit encryption off**: as step 12. Then **restart**: as step 13.
15. **None**: a `PUT` with `None` and every flag `false`. Record `DBEncStartMode`, the key file, the startup administrator and the passphrase. This is the reset 18.22 lacked (DW-2087's subject).
16. **Teardown, then S2:**
    - deactivate K1 through `EncryptionPort`;
    - restore `DBEncDefaultKeyID` and `DBEncJournalKeyID` to S0 (test-only `Security.System.Modify`);
    - remove the probe files and principals; clear the monitor if it moved.
    - S2 must equal S0 apart from counters and declared log lines.
17. **HALT** with status `blocked` and nothing built past step 1, with the record written, in each of these cases:
    - **Planned:** if S2 differs from S0 in a way no step 16 call clears (expected: the audit database's identity or count), the blocking condition is `Task 0 complete; throwaway rebuild needed: <exactly what is left>`. The runner rebuilds the throwaway and re-dispatches on the recorded branch.
    - **Contradiction:** blocking condition `intent gap: observation contradicts the plan: <what>`, on any of:
      - a route answers a 500 or 501 that is not the vendor's own, or answers 202;
      - a write half-applies, or a refused attempt changes a fact;
      - a refusal of step 5 reaches the vendor;
      - a read takes more than 2 s;
      - a pair beyond Security's set, the path port's pair and one candidate is needed;
      - the restart does not come up healthy within 10 minutes (stop probing at once);
      - **the audit records survive an `AuditEncrypt` change, at once and at the next restart**, because that contradicts the owner decision's premise.
18. **Not halts:**
    - step 6's 400;
    - step 7 changing something step 16 clears (the unchanged `PUT` then has no real leg);
    - a hidden startup administrator;
    - the vendor's own refusal of a step it refuses.
19. **Set from the record:**
    - the audit consequence's timing clause ("at once" or "at the next restart") and its direction;
    - each mapped vendor code;
    - the tool's pairs;
    - whether the unchanged `PUT` is a real leg;
    - each AD-15 and AD-53 named case, where step 7, 11, 12 or 14 found no vendor event;
    - whether the agent's marker survives an `AuditEncrypt` change (AD-15);
    - the seam's fixture shape for `STARTUPADMIN`.

**Execution (server)** (`src/OcuPilot/`):

- `Port/EncryptionPort.cls` (add-only branches):
  - **`Settings` `PUT`**, placed before the `NamesKeyFile` guard. It refuses a body carrying a non-empty `DBEncStartKeyFile` 400 `PATH.NAME`, as the guard does, and composes the vendor body itself, in this order:
    1. the version gate (`SettingsGate`, public, also asked by the tool and the Save);
    2. `StartupProblems` (public; the Boundaries rules, reading `KMIPSERVERS`, the active keys, the stored key file and, for a new file, `Administrators`), answering 422 violations on their fields;
    3. the body. `DBEncStartKeyFile` is composed as Boundaries says; `AdminName`/`AdminPassword` are sent only for a new Unattended file, from the query and the secret body; ids only when changed.
    4. `Call`. The password is cleared right after it. Vendor refusals are mapped through `PROPERTYFAULTS` (Task 0's codes) to 409 `ENCRYPTION.STARTUP.REQUIRED` or 422 credentials.
  - Both new types are keyed on endpoint `Security.Encryption.Settings` (`Invoke`'s branches, before `##super`).
  - **`KMIPSERVERS`** (AD-27 named case): `$System.Security.Check("%Admin_Secure","USE")`, then `Security.KMIPServer:List` in `%SYS` (AD-16 save and restore). It answers `{Names: [...]}`; a refusal or a throw fails the read.
  - **`STARTUPADMIN`** (AD-27 named case): the query's `keyfile` composite (or `root`/`path`) and `admin`. It resolves the file as a `source`, runs the same check, then `Security.System.Get("SYSTEM")` in `%SYS`. It answers `{StartupAdministrator: true}` when `DBEncStartKeyFile` equals the resolved file after `%File.NormalizeFilename` (exact) and `DBEncStartUsername` equals `admin` without case. It never answers the stored name. Any failure fails the read.
  - **`Snippet`**: the `PUT` as one `rest` step with the resolved key file and `"<AdminPassword>"`; a refusal (the version gate included) is a `comment` step with its sentence.
- `Port/AdminPort.cls` (add-only): `PROPERTYFAULTS` gains Task 0's `Security.Encryption.Settings` codes (`@=` request-level). `UNLOGGEDREFUSALS` gains nothing unless Task 0 measures a status no internal fault shares.
- `Screen/Tool/EncryptionStartupUpdate.cls` (new; the `JournalSettingsUpdate` model):
  - Parameters: `PORTCLASS` `EncryptionPort`, `PERMITTEDFIELDS` (the mode, four booleans, KMIP server, both ids, `AdminName`), `EXCLUDEDFIELDS` `DBEncStartKeyFile`.
  - Arguments `root`, `path` (in `PortQuery`) and `AdminName`; `ArgumentPairs` adds `%Admin_FileSystemAccess:USE` when a root is sent; `EXTRAPAIRS` from Task 0.
  - `MergeUpdate`:
    - strips `DBEncStartKeyFile` from the fresh read;
    - drops each key id the arguments leave unchanged;
    - keeps `AdminName` and the `AdminPassword` placeholder only for a new Unattended file, so the card asks for the password exactly then.
  - `MintClass` `Screen/Tool/EncryptionStartupMint.cls` (new; the `EncryptionKeyActivateMint` model) asks `SettingsGate`, then `StartupProblems` over the merged payload, before minting, and answers either fault as it is (501, or 422 on its field). At the confirm and the Save the port's own checks answer the same faults before any `PUT`.
  - `Consequence(payload, privileged, effect)`, in order:
    1. the effect `AUDIT.ENCRYPTIONCHANGE`;
    2. the new mode's `ENCRYPTION.STARTUP.NONE`, `.INTERACTIVE`, `.UNATTENDED` or `.KMIP` when the mode changes;
    3. `ENCRYPTION.STARTUP.RESTART` when IRISSECURITY or IRISTEMP changes;
    4. `ENCRYPTION.STARTUP.JOURNAL` when the journal flag changes;
    5. otherwise `""`.
  - `InputSchema` describes the `SYSTEM` literal, the four modes, the flags, `root`/`path` as 18.7 words them, `AdminName`, the KMIP server and the ids. It says the person types the password at confirm.
- `Area/Security/EncryptionStartupSave.cls` (new; the `EcpSettingsSave`, `EcpSettingsRules.HandleForm` and `EncryptionKeyFileSave` models):
  - `HandleUpdate` for `PUT /encryption-startup`, the Save through the tool, reading `AdminPassword` from the body, using it and clearing it, and answering `consequence` and `readBack`;
  - `HandleForm` for `GET /encryption-startup/form`, answering `{kmipServers}` through `KMIPSERVERS`.
- `Api/Router.cls` (add-only): the two routes, `/encryption-startup/form` before `/encryption-startup`, and their thin `Call=` targets.
- `Screen/Descriptor/EncryptionStartup.cls` (new, as Boundaries): context fields as the read; prompts; `commandAliases` "encryption startup", "startup settings".
- `Kernel/EntityType.cls` (`encryption-startup` with its doc line); `Kernel/EntityRef.cls` (`encryption-startup:singleton`).
- `Kernel/Proposal/Prohibited.cls` (add-only):
  - `TYPEENCRYPTIONSTARTUP` joins `COVEREDTYPES` (44), the fail-closed list and the dispatch through `ReviewedFewOnly`. Its `PermittedChangeFields` are the tool's permitted fields plus `root`, `path` and `AdminPassword`.
  - `EFFECTAUDITENCRYPTION` = `AUDIT.ENCRYPTIONCHANGE`. `WeakensByEffect` answers it for that type when the payload's `AuditEncrypt` differs from the target's.
  - **DW-2065:** the dispatch at :1316-1318 also passes `KeyFile` the target's id (the AD-13 `root`/`path` composite). For `AdminInFile` `DELETE`, `KeyFile` reads `STARTUPADMIN` through the tool's port with that composite as `keyfile` and the payload's `Admin`. A true answer or a failed read refuses `STARTUPADMIN` = `PROHIBITED.STARTUPADMIN`; then the reviewed-few sweep runs as today.
  - Its reason, in `Codes()` (28) and `ReasonFor`: "The instance activates its encryption keys at startup from this key file as this administrator, so the administrator is not removed here."
- `Kernel/Governance/Baseline.cls` (add-only, name order, Security block): `"security.encryptionstartup.update": false`.
- `Screen/Tool/Classification.cls`:
  - `security.encryptionstartup.update`: `fieldList` `Security.Encryption.Settings`, every row `ordinary` except `AdminPassword` `secret`, `compare` `{"AdminName": "written"}`.
  - Then regenerate `ToolFields.cls` (`cd ui && node tools/field-lists.mjs`).
- `Api/EncryptionError.cls` (add-only), codes and sentences, each published in EXPERIENCE.md:364 in the same words:
  - **Field violations** (422):
    - `ENCRYPTION.STARTUP.KMIPSERVER` on `DBEncStartKMIPServer`: "Choose a KMIP server this instance has configured."
    - `ENCRYPTION.STARTUP.KEYFILE` on `path`: "Unattended activation needs a key file."
    - `ENCRYPTION.STARTUP.NEEDSSTART` on the flag: "Turn on key activation at startup before encrypting this."
    - `ENCRYPTION.STARTUP.NOKEY` on the flag: "Activate a database encryption key on Database encryption before encrypting this."
    - `ENCRYPTION.STARTUP.KEYINACTIVE` on the id: "Choose a key that is active on Database encryption."
  - `ENCRYPTION.STARTUP.REQUIRED` (409): "Key activation at startup stays on while encrypted databases, journal files the instance still needs, the audit log or IRISSECURITY depend on it."
  - `REASONSETTINGSVERSION`: "This instance's admin API does not take the startup administrator in the request body, so change these settings on the classic Database Encryption page."
  - **Consequence codes**: `ENCRYPTION.STARTUP.NONE`, `.INTERACTIVE`, `.UNATTENDED`, `.KMIP`, `.RESTART`, `.JOURNAL` and `AUDIT.ENCRYPTIONCHANGE`, each the matching sentence below.

**Execution (client)** (`ui/src/app/`):

- `areas/security/encryption-startup.page.ts` and `.store.ts` (new, with specs), registered in `DESCRIPTOR_PAGES`. The ECP form is the model; the page holds:
  - **Key activation at startup**: four radios, each with its consequence sentence. KMIP is `aria-disabled` with "No KMIP server is configured on this instance." while `kmipServers` is empty; otherwise a KMIP server select.
  - **Unattended**: the stored key file shown read-only; a `server-path-picker` (`kind` `file`, page-local `AllowedDirectoriesStore`); Administrator name; and a masked Password, page-local and cleared on save, leave and destroy, never in the store.
  - **Four checkboxes**:
    - "Encrypt IRISSECURITY";
    - "Encrypt IRISTEMP, IRISLOCALDATA and IRISMETRICS";
    - "Encrypt journal files";
    - "Encrypt the audit log".

    Each has its consequence line. Each is `aria-disabled` with its reason while turning it on is refused (mode None, or no active key).
  - **Default key and journal key**: selects over Database encryption's declared read, `aria-disabled` with "No database encryption key is active." when it is empty.
  - **The sticky Save.** When `AuditEncrypt` changed, Save first opens `app-typed-name-dialog` (verb "Change audit log encryption", target and typed name `IRISAUDIT`, the audit consequence, the advisory). Otherwise it `PUT`s at once.
  - Refusals land on their fields.
- `areas/security/encryption-keys.page.ts` (add-only): on Database encryption only, a "Configure startup settings" link (`ocu-details-links`, the `auditing-config.page.ts` model).
- `core/proposal-view.ts`: the seven consequence codes, mapped to their sentences.
- `app.ts`: the store's injection and sign-out reset, pinned in `app.spec.ts`, if the store is root-provided.
- `core/strings.ts` (add-only, after :5648), each new key under its `/** EXPERIENCE.md:n */`. If the literal count passes 2700, raise `ui/tools/strings.test.mjs:586`'s bound to 2800 with its history line. Regenerate `core/screens.generated.ts` (`cd ui && node tools/screen-mirror.mjs`).
- `ui/angular.json`: re-base `maximumWarning` under DW-1166 to the measured total rounded up to the next kB, with its history row. Stop and ask above 3800kB.
- **EXPERIENCE.md, in place, keeping 1036 lines**, then `cd ui && npm run test:tools`:
  - :168: "the encryption startup settings" joins the list of what attaches to existing screens;
  - :173 gains "change the audit log's encryption on Encryption startup settings (Story 18.23: the destructive treatment, typed name `IRISAUDIT`)";
  - :364 gains "; and Encryption startup settings (Story 18.23): …" with every new literal and the `PROHIBITED.STARTUPADMIN` sentence, tagged `[ADDED <date> - Story 18.23]`;
  - :516 gains the audit-encryption consequence and its advisory.

**The published sentences** (OcuPilot's words; the timing clauses marked † are set by Task 0 step 19):

| Option | Sentence | Source |
| --- | --- | --- |
| None | "Keys are not activated at startup. After each start, encrypted databases stay unmounted until someone activates their key on Database encryption." | |
| Interactive | "Each start asks for a key file on the instance's console. When nobody answers, as in a container, the instance starts without the key and leaves encrypted databases unmounted." | 18.22, measured |
| Unattended | "Not recommended. The instance keeps this administrator's credentials and adds a hidden administrator of its own to the key file, which stays there after unattended activation is turned off, so anyone who can start the instance and reach the key file can read encrypted data." | vendor documentation |
| KMIP | "Each start activates the keys from this KMIP server with no one present." | |
| IRISSECURITY, IRISTEMP | "Takes effect at the next restart." | classic page hint |
| Journal | "New journal files are encrypted from the next journal switch or restart. Switch the journal file on Journals to start now." | |
| Audit log | "Every audit record on this instance, the agent's own audit markers included, is deleted †at once†, and the audit log starts again †encrypted / unencrypted†." | |
| Audit advisory | "Copy the audit records you need to another namespace on Auditing, or purge them, before you change this." | |
| Default key | "New encrypted databases use this key." | |
| Journal key | "New encrypted journal files use this key." | |

**Rosters and CI:**

- Extend every roster in Code Map › Rosters. The Security pins grow by one unlisted route.
- `Test/ToolWrite.cls` `AHEADTYPES` becomes `""`.
- `scripts/ci-throwaway.sh`: the new armed classes join `OCUPILOT_ALLOW_ENCRYPTION_CONFIG`'s `# classes:` line; the gate class joins `OCUPILOT_ALLOW_PRINCIPALS`'s. The comment "never activate or deactivate a key, change no encryption setting" stays true.

**Tests:**

- `Test/EncryptionStartupProbe.cls` (new; prefix `OCUPROBESTART`): `SeedDirectory`, `SeedKeyFile`, `SeedPrincipal`, `RemoveAll`; `AuditFacts` (count, `IRISAUDIT` directory, `EncryptedDB`, size, modified time, newest `AuditChange` row); `Snapshot` and `Diff` over `EncryptionProbe`'s plus `AuditFacts`; delegating `RunAs`.
- `Test/EncryptionSeamPort.cls` (add-only modes):
  - `startup`: `Settings` `PUT` never reaches the vendor; its body key names are recorded; it applies to a seam-held settings object that later `Settings` `GET`s answer. `Key` `LIST` answers 18.22's held list, so ids can be seam-active.
  - `startupfails`: the armed vendor code through `AdminPort.Fail`.
  - `startupadmin` and `startupadminfails`: `STARTUPADMIN` answers true for the armed file and administrator, or fails.
  - `kmip`: `KMIPSERVERS` answers armed names.
  - `settingsv1`: `SettingsGate` sees the v1 template.
  - **Guard:** under any other mode a `Settings` `PUT` reaches the vendor only when its body equals the instance's current settings and Task 0 made the unchanged `PUT` a real leg; any other `PUT` is answered 500 without the vendor.
  - `Test/SeamEncryptionStartupUpdate.cls` and a Save fixture (`EcpSettingsSaveFixture` model) follow.
- `Test/EncryptionStartupRead.cls`:
  - screen read equals tool read;
  - nine fields, no secret;
  - the form read answers `kmipServers` `[]`;
  - each read's pairs.
- `Test/EncryptionStartupWrite.cls` (`OCUPILOT_ALLOW_ENCRYPTION_CONFIG`):
  - the matrix's seam rows on both callers, with body key names and read-backs;
  - **a start-mode change sends `AuditEncrypt` equal to the fresh read** (the ruling's pin);
  - ids only when changed;
  - the audit proposal `destructive` with its consequence;
  - the refusals with zero `PUT`;
  - the version gate on both callers;
  - the marker password's absence everywhere;
  - the real unchanged `PUT` leg only if Task 0 made it one;
  - facts restored after each test.
- `Test/EncryptionStartupGate.cls` (`OCUPILOT_ALLOW_PRINCIPALS`, `OCUPILOT_ALLOW_ENCRYPTION_CONFIG`): the read's, the form read's and the tool's declared pairs, the path pair on a root, each refused by name with zero port calls; exactly the declared pairs write through the seam.
- `Test/EncryptionStartupDescriptor.cls`:
  - the descriptor;
  - `EncryptionError`'s new codes and sentences;
  - the baseline key `false`;
  - the effect and each consequence code;
  - `Snippet`'s branches (placeholder, `comment` refusals);
  - `FieldLists`' `AdminName` and `AdminPassword` rows.
- `Test/EncryptionKeyFileWrite.cls` (add-only), DW-2065: `startupadmin` and `startupadminfails` legs on `removeadministrator`, both callers; another administrator still removed.
- Component specs, covering:
  - the page and store: options, `aria-disabled` reasons, the picker, the page-local password cleared, the changed-only body with `AuditEncrypt` as read, and the typed-name dialog only on an `AuditEncrypt` change;
  - `encryption-keys.page.spec.ts`: the link on Database encryption only.
- `ui/browser/encryption-startup.browser-spec.mjs` (new; refuses a non-throwaway; facts and audit facts unchanged after):
  - the link, the form, each consequence, KMIP and the flags `aria-disabled` with reasons;
  - Unattended revealing the picker, name and masked password;
  - an Unattended Save with no file refused on its field with no `PUT`;
  - the DW-1337 gate in both themes on the form.

**Acceptance Criteria:**

- **C0:** Given `ocupilot-b-ci`, when the implement stage starts, then Task 0 records the reachable subset, the refusals, the unchanged `PUT`, the pairs, the audit events, `AuditEncrypt`'s timing and the startup administrator before any UI exists, in Part A then Part B order; it ends at S0 or with the planned rebuild halt, and a contradiction halts the story.
- **C1:** Given the form and `security.encryptionstartup.read`, when each reads, then both answer the same nine settings, and no answer, DOM, screen context or tool result carries a password or key material.
- **C2:** Given the startup options (None, Interactive, Unattended, KMIP) and the four encryption flags, when a person opens the form or the agent proposes a change, then each option is offered with its consequence stated: Unattended marked not recommended, KMIP `aria-disabled` with its reason while no KMIP server is configured, and the proposal card naming the change's consequence code.
- **C3:** Given a change, when a person saves it or confirms the agent's proposal, then one `Settings` `PUT` is composed and sent through the seam with the Boundaries' body. A start-mode change sends `AuditEncrypt` exactly as the fresh read held it. Key ids go only when changed. The read-back reports the result.
- **C4:** Given an `AuditEncrypt` change, when the agent proposes it, then the proposal is destructive with the audit consequence, behind the key `security.encryptionstartup.update` that ships `false`. When a person saves it, the typed-name dialog (`IRISAUDIT`) states the consequence and the advisory before any `PUT`, and the Save is not governed.
- **C5:** Given a change the rules refuse, when either caller submits it, then it is refused on its field with zero `PUT`, and every vendor refusal arrives as OcuPilot's sentence.
- **C6:** Given an admin API whose `Settings` template lacks `AdminName` or `AdminPassword`, when either caller writes, then the write is refused 501 `PORT.NOTIMPLEMENTED` with zero `PUT`.
- **C7:** Given any password entered, when any write runs or fails, then it is returned by no read and found in no log line, ledger row, proposal, store, screen context, answer or DOM after save, and the agent's card asks for it as a masked row.
- **C8 (DW-2065):** Given a key file the instance activates its keys from at startup, when either caller removes its startup administrator, or the startup read fails, then the removal is refused `PROHIBITED.STARTUPADMIN` with nothing sent, while another administrator is removed.
- **C9:** Given the rosters, when the story lands, then:
  - the form is unlisted and reached from Database encryption's link, with three prompts;
  - its key is in the baseline `false`, and every roster includes the screen and tool;
  - the DW-1337 gate holds in both themes;
  - EXPERIENCE.md reads 1036 lines.

## Spec Change Log

- 2026-10-05, spec gate (runner): Decisions 1 to 8 confirmed. Decision 1 verified by the runner in the vendor source (`ValidateRequest` builds `RequestValidator(schema, 1)`, exempting only the key ids and the v2 credentials; `RunPut` passes `req.AuditEncrypt` to `ConfigStart`); amendment 9 applied at origin (epics.md :7519, `epic-18-context.md`) and reported to the orchestrator. Spine amendments 1 to 6 written (AD-4, AD-10 two items, AD-13, AD-26, AD-27, AD-44); 7 and 8 wait for Task 0, with ordinals taken from the spine when written.

## Review Triage Log

## Design Notes

**Governing ADs:**

- AD-2, AD-27, AD-52: `EncryptionPort` extends `AdminPort`. `STARTUPADMIN` and `KMIPSERVERS` form a new AD-27 named case.
- AD-26: the version gate (Decision 4); nothing queues.
- AD-3, AD-4: a merge over the derived `Settings` field list, with a named exception (amendment 1).
- AD-5, AD-36, AD-44: one descriptor whose page issues Database encryption's declared read; no `CLASSICPAGES`.
- AD-6, AD-34, AD-40, AD-53, AD-55, AD-56: two callers of one tool, and the closed confirm channel over `AdminPassword`.
- AD-8, AD-29: Security's pairs and Task 0's measured pairs.
- AD-10: the `PROHIBITED.STARTUPADMIN` arm and the `AUDIT.ENCRYPTIONCHANGE` effect.
- AD-13, AD-14: the singleton and its change event. AD-15, AD-53: a vendor event, or named cases per Task 0.
- AD-21: the startup key file as a sixth-case `source`. AD-22: one key, `false`.
- AD-24, AD-35, AD-48: no secret returned or logged. AD-39: OcuPilot's own sentences. AD-58: read-backs. AD-59: `Snippet`.

**Measured at plan** (read-only on `ocupilot-b-ci`, 2026-10-05 11:08-11:10 UTC; `/tmp/epic-18-d7/1823/plan/probes.txt`):

- `Settings` `GET` under v2: 200 in 5.5-6.7 ms, `{"DBEncStartMode":"None", four false, five ""}`.
- `Security.System`: every encryption property 0 or `""`, `DBEncStartPassphrase` empty, `AuditEnabled` 1. No database or data-element key active. No KMIP server configured. `PendingRestart` 0.
- `IRISAUDIT` at `/durable/iris/mgr/irisaudit/`: not encrypted. Its `IRIS.DAT` is inode 12766, 134,217,728 bytes, modified 2026-10-05 10:52:49Z, born 2026-06-26 18:00:36Z. 222,237 audit events.
- `DATABASE1` is object code only. `%SYSTEM.Security.System`'s key methods are kernel-dispatched (inference).
- **Sources disagree on `AuditEncrypt`'s timing and effect.** `Security.System`'s doc says the audit database is deleted as soon as the property changes. The classic page's hint says it takes effect at the next restart. `MakeIRISAudit` converts the database in place at startup, keeping its data. The official documentation says both. Task 0 measures it (Decision 2).

**Decisions** (applied in this plan; the runner confirms them at the spec gate):

1. **`AuditEncrypt` is always sent, as the fresh read holds it unless the person or the proposal changed it.** The orchestrator's ruling wants a start-mode change never to touch `AuditEncrypt`, unlike the classic page's None, which sends 0 unconditionally. The ruling's means, leaving the key out of the body, cannot reach that end, for two reasons, both read in source:
   - the vendor's validator requires `AuditEncrypt` in every `PUT` (400 `MissingRequestBodyField`);
   - `RunPut` passes `req.AuditEncrypt` to `ConfigStart` whatever it holds, so an omitted key would arrive as `""`, the classic page's hazard.

   Sending the fresh value is the reading that keeps the ruling's purpose. The pinning test asserts it, and Task 0 step 6 confirms the 400 (amendment 9).
2. **One real activation in Task 0 is acceptable, on `ocupilot-b-ci` only, last.**
   - Only the encrypted direction can answer the timing. Enabling `AuditEncrypt` needs key activation at startup and an active key (#1218, #1235), so the unencrypted-to-unencrypted direction has no subject. `Erase` has no readable caller and `MakeIRISAudit` contradicts it, so source evidence alone cannot settle it.
   - This story's own `PUT` with None is the reset 18.22's halt lacked.
   - Unattended mode makes both restarts non-interactive.
   - The throwaway is runner-owned, and the rebuild is planned (step 17).
   - IRISSECURITY, IRISTEMP and journal encryption are never measured: a failed restart there loses the instance before the audit legs finish.
3. **The audit sentence's timing is measured, its substance is the owner's.** If Task 0 finds the records survive both at once and at the next restart, the owner decision's premise fails and the story halts (step 17); otherwise the sentence takes the measured "at once" or "at the next restart".
4. **The version gate reads the live template.** `AdminPort` already refuses an instance whose admin API is not v2 (`InvokeLocated` :1176-1189). The gate is narrower and explicit: the `PUT` carries credentials in the body only while the endpoint's own template, built at v2, names `AdminName` and `AdminPassword`. Its refusal follows `AtelierPort`'s 501 model with an encryption sentence pointing at the classic page.
5. **The key ids go only when changed.** The vendor calls `SetDBEncKeyDefault` and `SetJrnEncKey` for any id it is sent, and saves `Security.System` before checking their status (S:86-97). Re-sending a running id would rewrite it needlessly, and re-sending `""` with no key active would fail after `ConfigStart` applied, a half-applied write.
6. **Credentials and the key file mirror the classic page.** The key file is sent for Unattended only, as the classic page does (`:378-455`), and the credentials only for a new Unattended file (`:401-405`).
7. **DW-2065 is a sibling code, read without the stored name leaving the port.**
   - `PROHIBITED.OCUPILOTKEY`'s sentence is about data a key encrypts, which an administrator is not, so the arm takes `PROHIBITED.STARTUPADMIN` in AD-10's key family. It lives in `Prohibited.cls`, because `Error.cls` resolves `PROHIBITED.*` through `Prohibited.ReasonFor`.
   - The arm is mode-independent. Choosing Unattended again with the stored file sends no credentials, so a removed startup administrator would break the next unattended start.
   - The vendor's own #1222 suggests it refuses the removal too (inference); the arm refuses first, on the write path.
8. **No AD-10 arm for Interactive or None on an encrypted instance.** The vendor refuses None while encrypted databases are required at startup (#1217), and Interactive's consequence states the measured restart behavior. That follows the owner's "developer tool first" direction.

**Named limits:**

1. The read-back does not compare the startup key file, which only the port composes (AD-21). Task 0 step 11 records whether the vendor stores it as sent.
2. The agent cannot list KMIP server configurations: no read tool answers them, and none exists on any instance here.
3. A vendor refusal of a `PUT` the rules did not pre-empt is a 500 and stays logged at severity 2 until the burn-down's code-scoped unlogged grammar (DW-2007).
4. The typed-name dialog for `AuditEncrypt` never renders in a browser on a real instance, because no key is active there. The component spec covers it, and the shared dialog passes DW-1337 on other screens.

**Proposed amendments.** The runner writes 1 to 8 at the spec gate; Task 0 confirms each `<measured>`; ordinals are taken from the spine when written.

1. **AD-4, named exception:** "**`Security.Encryption.Settings`** (Story 18.23): its merge sends the seven fields the vendor requires as the fresh read holds them with the change applied, `AuditEncrypt` included, so a start-mode change never alters it. `DBEncStartKeyFile` is composed by `EncryptionPort` alone. The key ids are sent only when changed, and the administrator and password only for a new Unattended key file."
2. **AD-10, two items:**
   - **The startup administrator** (Story 18.23, DW-2065): removing from the key file the instance activates its keys from at startup the administrator it activates them as, read at the write, is refused `PROHIBITED.STARTUPADMIN`, from either caller; a read that fails refuses.
   - **Changing the audit log's encryption** deletes every audit record, the agent's markers included. It is permitted at the strongest confirmation (effect `AUDIT.ENCRYPTIONCHANGE`): the agent's proposal is minted destructive with the consequence, and the person's Save asks the typed-name confirmation first (owner decision 2026-10-05).
3. **AD-13:** "**`encryption-startup` is a singleton** (Story 18.23)."
4. **AD-26, after the `Settings` sentence:** "Story 18.23 ships its write behind an explicit version gate: `EncryptionPort` refuses the `PUT` 501 `PORT.NOTIMPLEMENTED` unless the endpoint's own body template, built at API version 2, carries `AdminName` and `AdminPassword`."
5. **AD-27, a named case:** "**Story 18.23's case, the startup settings the admin API does not answer**: `EncryptionPort`'s `KMIPSERVERS` (`Security.KMIPServer:List`) and `STARTUPADMIN` (whether `Security.System`'s `DBEncStartKeyFile` and `DBEncStartUsername` name a given key file and administrator, never the name itself) repeat `%Admin_Secure:USE` and read in `%SYS` (AD-16); a failure fails the read."
6. **AD-44:** "**Story 18.23's tool declares no `CLASSICPAGES`**: `%CSP.UI.Portal.EncryptionDatabase` performs it."
7. **AD-8:** "**Story 18.23's startup settings** declare Security's set; the write also declares `<measured>` and the path port's pair when a root is sent; `STARTUPADMIN` reads under `removeadministrator`'s pairs `<measured>`."
8. **AD-15 and AD-53**, only where Task 0 finds no vendor event; **AD-15** also records whether the agent's marker survives an `AuditEncrypt` change `<measured>`.
9. **epics.md :7519 and `epic-18-context.md:85`, correct at origin (Rule 5, apply-and-report tier, intent unchanged):** replace "the settings merge sends `AuditEncrypt` only when the person or the proposal changed it, so a start-mode change leaves it out of the body, pinned by a test" with "the settings merge sends `AuditEncrypt` as the fresh read holds it unless the person or the proposal changed it, so a start-mode change never alters it, pinned by a test". The reason: the vendor requires the field and passes it to `ConfigStart` whatever it holds (Decision 1).

**Integration ACs.** New: `EncryptionPort`'s `Settings` branch, `KMIPSERVERS`, `STARTUPADMIN` and `SettingsGate`, the tool, the Save, the page and store.

- The form consumes the declared read, `GET /encryption-startup/form` and `PUT /encryption-startup` against `ocupilot-b-ci` (C1, C3, C5; `EncryptionStartupRead`, `EncryptionStartupWrite`, the browser spec).
- `Prohibited.KeyFile` consumes `STARTUPADMIN` on 18.7's `removeadministrator` path (C8; `EncryptionKeyFileWrite`).
- `Mint` consumes the `AUDIT.ENCRYPTIONCHANGE` effect (C4; `EncryptionStartupWrite`).

**Consumes:** 18.22 (Database encryption's page and read, the seam's held keys, the activation measurements), 18.7 (`EncryptionPort`, key files, `EncryptionRules`, `EncryptionError`, the probe), 18.1 (`PathPort` and its picker), 18.21 (the form and form-read model), 14.2 (the purge treatment and baseline), 16.17's read-back, 14.1's `Snippet`.

**Consumed-by:** 18.12 (the agent's grown tool set); Epic 18's burn-down (DW-2087's decision may lean on this story's reset).

**Ledger inbox (Rule 17):** DW-2065 is addressed by Decision 7, the `Prohibited` task, Task 0 step 11, C8 and the matrix row.

**Footprint (Rule 11).** Contended files are edited add-only (Boundaries). New, or outside the listed set, for `footprint_extensions`:

- server: `Port/EncryptionPort.cls`, `Port/AdminPort.cls` (`PROPERTYFAULTS`), `Api/EncryptionError.cls`, `Area/Security/EncryptionStartupSave.cls`, `Kernel/EntityType.cls`, `Kernel/EntityRef.cls`, `Screen/Tool/Classification.cls`;
- client: `areas/security/encryption-keys.page.ts`, `core/proposal-view.ts`;
- the new classes, page, store, specs and browser spec.

**Size.** One form descriptor, one merge tool with a Save and a form route, three port branches and a gate, one effect and one AD-10 arm, a form page and store: about Story 18.22's size, plus Task 0's planned rebuild pass (inference). It is not split, because every part hangs on the one `Settings` `PUT`.

## Verification

**Setup (slot B):**

- Load with `/tmp/epic-18-d7/load-throwaway.sh` (no restart outside Task 0), never through the MCP loader. Every write lands on `ocupilot-b-ci`.
- Run one test class per call, and send the next only once the previous has landed in `%UnitTest_Result`. Never re-submit after a client-side timeout. The container carries `OCUPILOT_ALLOW_ENCRYPTION_CONFIG=1` and `OCUPILOT_ALLOW_PRINCIPALS=1`.
- Before any browser run: `cd ui && npm run build`, then copy `dist/ocupilot-ui/browser/.` to `/tmp/ocupilot-b-ci/ui/dist` (which `StartPath` redeploys) and `docker cp` it to `ocupilot-b-ci:/durable/iris/csp/ocupilot/`, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci` exported.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one at a time. Expected: 0 failures, totals checked against `%UnitTest_Result`.
  - The story's classes: `EncryptionStartupRead`, `EncryptionStartupWrite`, `EncryptionStartupGate`, `EncryptionStartupDescriptor`, `EncryptionKeyFileWrite`.
  - The rosters: `Descriptor`, `ReadTool`, `SurfaceCoverage`, `Prohibited`, `GovernanceBaseline`, `Governance`, `ToolDispatch`, `ToolRoundTrip`, `ToolWrite`, `DraftRegistry`, `ClassicPageGate`, `MappingDescriptor`, `Wire`, `WireSecurityRead`, `WireOAuthRead`, `EntityRef`, `EncryptionDescriptor`, `DerivedFields`, `Inventory`.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/encryption-startup.browser-spec.mjs browser/encryption-keys.browser-spec.mjs browser/security.browser-spec.mjs`. Expected: pass.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`, then `uv run scripts/check-objectscript.py <changed .cls>` and `bash scripts/lint-docs.sh`. Expected: clean, and `wc -l` on EXPERIENCE.md reads 1036.
- `(once, before dev_complete)`, each green with a non-zero count:
  1. the full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci`, one class at a time;
  2. `cd ui && npm test && npm run build`;
  3. `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`;
  4. afterwards no `OCUPROBESTART` file or principal remains, and every encryption and audit fact reads as at the build's S0.
- `(CI)` The full browser suite runs in CI's three `browser-shard` jobs (Rule 29).

**Planned pinning mutations (Rule 19).** Apply each on the throwaway, observe red, revert byte-identical, and record a `mutation:` line here:

- C1: the read declares `LIST` in place of `GET` → `EncryptionStartupRead`'s equality leg red.
- C2: KMIP's `aria-disabled` reason dropped (rebuilt and redeployed) → the page spec and the browser spec red. The `.UNATTENDED` consequence branch dropped from `Consequence` → `EncryptionStartupDescriptor` red.
- C3: `MergeUpdate` sends `AuditEncrypt` `false` on a mode change (the classic page's behavior) → `EncryptionStartupWrite`'s ruling pin red. Unchanged ids kept in the payload → the ids leg red.
- C4: the `AUDIT.ENCRYPTIONCHANGE` branch dropped from `WeakensByEffect` → the destructive leg red. The page's dialog branch skipped → the page spec red.
- C5: `StartupProblems`' active-key check dropped → `ENCRYPTION.STARTUP.NOKEY`'s leg red, with a `PUT` recorded.
- C6: `SettingsGate` answers OK always → the `settingsv1` leg red on both callers, with a `PUT` recorded.
- C7: the port writes the `PUT` body to `messages.log` → the marker leg red.
- C8: `KeyFile`'s `STARTUPADMIN` step skipped → `EncryptionKeyFileWrite`'s `startupadmin` legs red on both callers. Its failed read answering false → the `startupadminfails` leg red.
- C9: `security.encryptionstartup.update` dropped from `Baseline` → `GovernanceBaseline` red. The link removed (rebuilt) → `encryption-keys.page.spec.ts` and the browser spec red.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

- Planned only (Halt after planning). For the runner at the spec gate:
  - Decision 1 restates the orchestrator's `AuditEncrypt` ruling, because the vendor requires the field in every `PUT` and passes it to `ConfigStart` whatever it holds (read in source). Amendment 9 corrects epics.md :7519 and `epic-18-context.md:85` at origin.
  - Amendments 1 to 6 are ready to write; 7 and 8 wait for Task 0.
- Task 0 is planned to end `blocked` with `Task 0 complete; throwaway rebuild needed: <what is left>` after its one real activation and two graceful restarts (step 17). The build then runs on the recorded branch with every value change through the seam.
