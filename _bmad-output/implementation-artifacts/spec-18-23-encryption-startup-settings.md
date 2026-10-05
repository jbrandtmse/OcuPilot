---
title: 'Story 18.23: Encryption startup settings'
type: 'feature'
created: '2026-10-05'
status: 'in-progress'
review_loop_iteration: 0
baseline_revision: '2b3e5e243163d8a0bfc37d62bad357d5ebfbbd69'
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The classic Database Encryption page's Configure Startup Settings (`%CSP.UI.Portal.EncryptionDatabase`) is still the only place to choose how the instance activates its database encryption keys at startup, which system databases, journal files and audit log it encrypts, and which active key is the default and the journal key. The admin API carries it as `Security.Encryption.Settings` `GET` and `PUT`. DW-2065 rides along: whether removing a key file's administrator can break unattended activation at startup.

**Approach:** Add an unlisted form, **Encryption startup settings**, reached from Database encryption, with one merge tool on Story 18.7's `EncryptionPort` behind an explicit version gate. Each option states its consequence. An `AuditEncrypt` change takes the destructive treatment on both callers (owner decision 2026-10-05). A Task 0 on `ocupilot-b-ci` runs the reads, refusals and an unchanged `PUT` first, and last the measurements its first run left open (DW-2065's two-administrator restart, and an encrypted audit log at a start that cannot activate the key); it is planned to end with a throwaway rebuild. Every value change in the build's tests runs through a seam. DW-2065's refusal is built only if Task 0 measures that removing the typed administrator breaks unattended activation.

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
  - **`AuditEncrypt` keeps its fresh value unless the person or the proposal changed it**, so a start-mode change never alters it (Decision 1, which restates the orchestrator's ruling). It is read at the write, never carried from the mint, and a proposal that changes it fingerprints the reviewed current value, so a concurrent toggle refuses the confirm (orchestrator conditions 2026-10-05).
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
  - **Interactive key activation is refused while the audit log, IRISSECURITY or IRISTEMP is encrypted, now or at the next start, in both orders** (`PROHIBITED.STARTUPINTERACTIVE`, AD-10's serving-path arm, Decision 8, merge gate 2026-10-05): its sentence, on the start-mode field, is "The audit log, IRISSECURITY or IRISTEMP is encrypted, so every start must activate its key, and with Interactive a start nobody answers on the console does not finish. Keep Unattended, or turn their encryption off first." With any of the three encrypted a start that cannot activate the key aborts into single-user mode (measured for each, `/tmp/epic-18-d7/1823/t0r` r11-r12 and `t0m` m1-m4).
  - A changed default or journal key id must be active.
- **`AuditEncrypt` is treated as `security.auditing.purge` is** (owner decision 2026-10-05):
  - A proposal that changes it is minted `destructive`, through the new effect `AUDIT.ENCRYPTIONCHANGE` in `Prohibited.WeakensByEffect`, and carries that consequence.
  - The form's Save first opens the shared typed-name dialog (`shell/typed-name-dialog.ts`), typed name `IRISAUDIT`. Its body states the measured effect: the change takes effect at the next start, when the audit database is encrypted or decrypted in place, keeping its records. Its advisory says to keep the key file and its administrator available to every start (merge gate 2026-10-05, after Task 0).
  - The screen's Save is not governed.
- **DW-2065 (merge gate 2026-10-05, measurement-gated):** unattended activation stores a hidden generated administrator (`<key id>_1`) the key file's list never names (Task 0). Task 0 removes the typed administrator from a two-administrator key file in Unattended mode and restarts. If the key still activates, DW-2065 closes by-design and no `STARTUPADMIN` check or read is built. If activation breaks, removing that administrator is refused `PROHIBITED.STARTUPADMIN` from either caller, read at the write, and a failed read refuses.
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
| Refused before `PUT` | KMIP with none configured; Unattended with no file; new file without password; a new file with an unlisted administrator; a flag on with None; a flag on with no active key; an inactive key id; Interactive with the audit log, IRISSECURITY or IRISTEMP encrypted or being encrypted, in either order | Refused on its field; zero `PUT` | 422 `ENCRYPTION.STARTUP.KMIPSERVER`, `.KEYFILE`, `ENCRYPTION.KEYFILE.PASSWORD`, `ENCRYPTION.KEYFILE.CREDENTIALS`, `ENCRYPTION.STARTUP.NEEDSSTART`, `.NOKEY`, `.KEYINACTIVE`; 403 `PROHIBITED.STARTUPINTERACTIVE` |
| Version gate | Seam answers the template without `AdminName`/`AdminPassword` | Mint, Save and confirm refused; zero `PUT` | 501 `PORT.NOTIMPLEMENTED` (`REASONSETTINGSVERSION`) |
| Vendor refusal (seam) | Seam answers Task 0's measured codes (startup required, credentials) | Mapped to OcuPilot's sentences; no vendor text sent | 409 `ENCRYPTION.STARTUP.REQUIRED`; 422 credentials (per Task 0) |
| Password secrecy | Writes carrying a marker password | Marker in no log line, ledger row, proposal, store, screen context, answer or DOM after save | none |
| DW-2065 (only if Task 0 finds the removal breaks unattended activation) | Seam reports the startup key file and the administrator whose removal breaks it; and a failed read | Removing that administrator refused on both callers before anything is sent; another administrator is removed | 403 `PROHIBITED.STARTUPADMIN` |
| Link and placement | The story lands | Database encryption shows "Configure startup settings"; the form is unlisted, reached from it | none |

</intent-contract>

## Code Map

**Vendor:**

- `%Api.Admin.Endpoints.Security.Encryption.Settings` (export `/tmp/epic-18-d7/vendor/Settings.cls`, lines after its 4-line banner): `RunPut` :49-102 (`ConfigStart` :82, "answers OK without applying" :78-81, key ids only when defined and saved before the error check :86-97); `ValidateRequest` :124-139.
- Error texts (`/tmp/epic-18-d7/1823/plan/probes.txt`): #1212, #1213 and #1217 refuse turning startup activation off; #1218 and #1235 refuse audit encryption without startup activation or an active key; #1222 "Cannot remove unattended activation administrator from key file"; #1233 refuses a start-mode change.
- `irissys/%CSP/UI/Portal/EncryptionDatabase.cls`: options :102, KMIP only with a `Security.KMIPServer:List` row :157-170, hints :116-123, `doSaveStartup` :378-455 (credentials rule :401-405).
- `$$AdminList^EncryptionKey(file, .sc, flag)`: object code only; `Test/EncryptionProbe.Contents` :178 calls it with flag 1.

**Server** (`src/OcuPilot/`):

- `Port/EncryptionPort.cls` (step 1's plumbing, `f268a30e`): `Invoke`'s `Settings` branch :191-206 precedes the `NamesKeyFile` guard :208. Built: `SettingsGate` :787, `StartupWrite` :811 (fresh read at the write; password cleared after the call), `Wanted` :851 (an omitted flag keeps its fresh value), `StartupProblems` :911, `StartupBody` :997, `StartupMapped` :1041 (maps `STARTUPREQUIRED` only), `KmipNames` :1052, `StartupAdmin` :1107 and `IsStartupAdmin` :1129 (compare the stored, hidden name). Not built: `Snippet`'s `Settings` branches (:1272). Model: `RemoveAdmin` :489.
- `Port/AdminPort.cls`: `PROPERTYFAULTS` :3259 (`Endpoint:code:@field=CODE`), `Snippet` :3446, `RestStep` :3480. `AtelierPort.cls:874-878`: the 501 model.
- `Screen/Tool/JournalSettingsUpdate.cls`: the merge model (`MergeUpdate` :130). `EcpSettingsUpdate.cls:198-203`: a conditional `Consequence`. `AuditPurge.cls`: `AUDIT.PURGEMARKERS` :31. `EncryptionKeyFileRemoveAdmin.cls` `StateRefusal` :52-57 refuses a name the file does not list.
- `Kernel/Proposal/Mint.cls`: `WeakensByEffect` :331, `ConsequenceOf` :758. A merge write's digest is over the payload `MergeUpdate` returns (:286), and `Confirm.cls:726-745` re-runs `MergeUpdate` over the confirm's fresh read and compares: a key the payload omits is not fingerprinted, and a key the arguments set is fingerprinted at its new value.
- `Kernel/Proposal/Prohibited.cls`: `EFFECT*` :131-647, `Codes()` :760 (27), `COVEREDTYPES` :250 (43), fail-closed list :1114, dispatch :1316-1318 to `KeyFile` :2500 (`AdminInFile` `DELETE` → `ReviewedFewOnly` :2514), `WeakensByEffect` :1566 (model `SslWeakening` :4566).
- `Kernel/EntityType.cls:80` (54); `Kernel/EntityRef.cls:59` (28); `Kernel/Governance/Baseline.cls:86`. `Screen/Tool/FieldLists.cls:305-317` derives `Security.Encryption.Settings` (11 rows); `Classification.cls` model :723-734.
- Save and form-read models `Area/OsMgmt/EcpSettingsSave.cls`, `EcpSettingsRules.HandleForm`, `Area/Security/EncryptionKeyFileSave.cls` :146-169; `Api/Router.cls:240-241`, :1769-1781; descriptors `EcpSettings.cls`, `DatabaseEncryption.cls`.
- `Api/EncryptionError.cls`: startup codes and sentences :112-143 (built), not yet in `Codes()` :146 or `ViolationCodes()` :153.

**Client** (`ui/src/app/`):

- Form model `areas/os-management/ecp-settings.page.ts` and `.store.ts` (form read :243-272, changed-only body :344-355, `aria-disabled` choices :144-167); `server-path-picker` (`journal-settings.page.ts:139-148`); `encryption-keys.page.ts` (masked password and `clearDialog` :129-135, :448-457); link model `auditing-config.page.ts:175-179`.
- `shell/typed-name-dialog.ts:94-115`; `shell/screen-outlet.ts:146`; `core/proposal-view.ts:286-296`, :322-380 (pinned in `ui/tools/proposal-view.test.mjs:905-918`); `core/strings.ts` after :5648, reusing `encryptionKeyFileAdminName`, `fieldPassword`, `pathPickerRootLabel`, `pathPickerFileLabel`, `actionSave`, `formTypedNameConfirm`.
- Budgets: `ui/tools/strings.test.mjs:586` (2700, 2634 used); `ui/angular.json:54` (2929kB, pinned at `angular-json.test.mjs:516`). `ui/tools/navigation.test.mjs:252`; `ui/browser/encryption-keys.browser-spec.mjs` (guard :107-110, DW-1337 :174-202).
- EXPERIENCE.md (1036 lines): :168 Security's side-bar row, :173 Dialogs, :364 Fixed strings' Security row, :516 the audit purge row.

**Rosters** (re-derive each count from its class's red): `Test/Descriptor.cls` :67-173 (103), :1747 (54); `ReadTool.cls` :93 (272); `SurfaceCoverage.cls` :57-198 (142), :199-361 (163); `Prohibited.cls` :232 (43); `GovernanceBaseline.cls:15` (36); `Governance.cls:48` (9); `ToolRoundTrip.cls:72` (198); `ToolWrite.cls:80` `AHEADTYPES`; `DraftRegistry.cls:77` (7); `ClassicPageGate.cls` :75 (54), :85 (3); `MappingDescriptor.cls:24` (58); `EncryptionDescriptor.cls:80` (15); the Security pins (28 routes) in `Wire.cls:600`, `WireSecurityRead.cls` :807-1112 and `WireOAuthRead.cls` :275-350; `scripts/ci-throwaway.sh` :329-334 and :536-547, derived in `ui/tools/ci.test.mjs:2157-2177`.

**Test models:** `Test/EncryptionStartupProbe.cls` (built: prefix `OCUPROBESTART`, `NewPassword` :29, `AuditFacts` :38, `Snapshot` :70) over `EncryptionKeyProbe` and `EncryptionProbe` (`SeedKeyFile` :126, `Run` :307, `RunAs` :346, `EncryptionFacts` :421, `LinesAfter` :598); `Test/EncryptionSeamPort.cls` (modes :5-35, `Arm` :217, `ArmCredentials` :289); `EcpSettingsSaveFixture`, `SeamEcpSettingsUpdate`; `EncryptionKeyFileWrite.TestAKeyTheInstanceDependsOnIsNotRemovedOnEitherCaller`.

## Tasks & Acceptance

**Task 0, re-run: the implement stage's first task, before any descriptor, tool or page.** The first run's steps 1-14 (Measured at implement) are not repeated.

Setup:

- `ocupilot-b-ci` only, rebuilt by the runner at 12:31Z from `f268a30e`; the re-plan read it at S0 at 12:45Z (every encryption fact 0 or `""`, `IRISAUDIT` unencrypted, inode 37734, 30,452 events, no probe object). Load the worktree first with `/tmp/epic-18-d7/load-throwaway.sh`.
- Evidence in `/tmp/epic-18-d7/1823/t0r/`, an `rN.txt` script and `rN.out` record per step; results under Measured at implement, AD sentences in `## Spec Change Log`.
- After every write and restart, record `EncryptionFacts`, `AuditFacts` with the oldest audit row, `Security.System`'s `DBEncStartKeyFile`, `DBEncStartUsername` and passphrase length, the key file's size and `sha256sum`, `$$AdminList^EncryptionKey` with flags 0 and 1, and new `messages.log` and `alerts.log` lines.
- A restart is `docker restart -t 120 ocupilot-b-ci`, then the health check, at most 10 minutes.

Steps, in order:

1. **S0:** `Snapshot` and `AuditFacts`, saved under `<ManagerDirectory>Temp/`.
2. **Seed** `start-a.key` under `<ManagerDirectory>ocuprobestart/`: K1 (256 bits) with administrator A (`OcuProbeStartAdmin`), then B and C (`...AdminB`, `...AdminC`) added through `EncryptionPort` `AdminInFile` `POST`; three, so each removal leaves one.
3. **Activate** K1 through `EncryptionPort` `ActivateDB` as A.
4. **Unattended as A** through `EncryptionPort`. Record whether the key file changed and whether either `AdminList` names an administrator beyond A, B and C.
5. **DW-2065, an administrator nobody typed:** remove B through `EncryptionPort`, restart (R1), and record whether K1 activates (`messages.log`'s "Activating encryption key" or "Unable to activate"; `Key` `LIST`).
6. **DW-2065, the typed administrator** (only if R1 activated): remove A, restart (R2), record as step 5.
7. **The `None` reset:** a `PUT` with `None` and every flag `false`. Record what it clears (key file, startup administrator, passphrase) and whether step 4's extra administrator, if any, stays listed. Unless R1 and R2 both activated, go to step 13.
8. **Unattended as C**, as step 4 (if the port sends no credentials because step 7 kept the stored file, record that).
9. **Audit encryption on**, then restart (R3): expected, as measured, `IRISAUDIT` encrypted in place, every record kept.
10. **Startup required:** a `PUT` with `None` and every flag `false` while `IRISAUDIT` is encrypted. Record the vendor's code and status and that no fact moved. If the vendor applies it, record that and skip step 11.
11. **A start that cannot activate the key:** a `PUT` with `Interactive`, `AuditEncrypt` unchanged. If the vendor refuses it, record the code and move `start-a.key` aside in the container instead.
12. **Last, restart (R4)**, at most 10 minutes. Healthy: record whether `IRISAUDIT` is mounted, whether auditing records (OcuPilot's marker and the `%SYS.Audit` count), and the log lines about the audit database. Not healthy: stop probing; record the host copies of `messages.log` and `alerts.log` under `/tmp/ocupilot-b-ci/data/iris/mgr/`, whether IRIS itself started, and `docker inspect`'s state.
13. **Teardown:** move a key file set aside back, remove any probe principal, leave every setting and file a start reads. Then HALT `blocked`, `Task 0 complete; throwaway rebuild needed: <exactly what is left>` (planned). The runner rebuilds, writes the AD sentences and re-dispatches; the build starts at Execution.
14. **Other halts** (`blocked`, record written), `intent gap: observation contradicts the plan: <what>`: R1, R2 or R3 not healthy within 10 minutes (stop at once); a write half-applies or a refused write moves a fact; an `AuditEncrypt` change loses a record; R1 activates and R2 does not, after step 7 and step 13's teardown, in place of step 13's halt (the instance stores no typed name: name the owner's two ways out, OcuPilot recording the typed name at its own Unattended write, or refusing every administrator of the startup key file). Not halts: a vendor refusal, R1 not activating, R4 not healthy.

**Set from the record** (by the re-dispatched build):

- **DW-2065.** R1 and R2 activate: it closes `by-design` (the runner's trailer); delete `STARTUPADMINTYPE`, `StartupAdmin`, `IsStartupAdmin` and their `Invoke` branch, and build nothing marked "DW-2065". R1 does not activate: removing any listed administrator breaks unattended activation, so `IsStartupAdmin` answers true when the resolved file is the stored `DBEncStartKeyFile` and `DBEncStartMode` is Unattended, whatever the administrator, and everything marked "DW-2065" is built.
- **The sentences' bracketed clauses** (the table below).
- **`ENCRYPTION.STARTUP.REQUIRED`'s codes:** each code steps 10-11 measure refusing to turn startup activation off maps to it in `PROPERTYFAULTS`; #1212 and #1213, whose text names the same refusal, map too, labeled `(inference)` where declared.

**Execution (server)** (`src/OcuPilot/`):

- `Port/EncryptionPort.cls` (add-only): `StartupMapped` answers a 500 #5001 on a `PUT` that carried credentials as 422 `ENCRYPTION.KEYFILE.CREDENTIALS` on `AdminPassword` (still logged); `Snippet` renders the `PUT` as one `rest` step with the resolved key file and `"<AdminPassword>"`, and a refusal, the version gate's included, as a `comment` step; DW-2065 as the record sets it. `Port/AdminPort.cls` (add-only): `PROPERTYFAULTS` gains the record's `Settings` codes (`@=`).
- `Screen/Tool/EncryptionStartupUpdate.cls` (new, the `JournalSettingsUpdate` model): `PORTCLASS` `EncryptionPort`; `PERMITTEDFIELDS` the mode, four booleans, KMIP server, both ids and `AdminName`; `EXCLUDEDFIELDS` `DBEncStartKeyFile`; arguments `root`, `path` (in `PortQuery`) and `AdminName`; `ArgumentPairs` adds `%Admin_FileSystemAccess:USE` when a root is sent; no `EXTRAPAIRS`.
  - `MergeUpdate` strips `DBEncStartKeyFile`, and `AuditEncrypt` unless the arguments change it, so the port reads it at the write; when they change it, fingerprints the value the proposal reviewed, so a confirm whose fresh read no longer holds that value is refused target-changed with zero `PUT`. Because the kernel digests the merged payload (:286, `Confirm.cls:726-745`), where a set key holds its new value, the payload also carries the fresh read's `AuditEncrypt` under a key the port never sends and the card never shows as a changed row (spec gate: one concrete mechanism; an equivalent one the reviewer can verify is fine), and the pinning test changes `AuditEncrypt` on the instance between mint and confirm; drops unchanged key ids; keeps `AdminName` and the `AdminPassword` placeholder only for a new Unattended file.
  - `MintClass` `Screen/Tool/EncryptionStartupMint.cls` (new, the `EncryptionKeyActivateMint` model) asks `SettingsGate`, then `StartupProblems` over the merged payload, and answers either fault as it is.
  - `Consequence`, first match: the effect `AUDIT.ENCRYPTIONCHANGE`; the new mode's `ENCRYPTION.STARTUP.NONE`, `.INTERACTIVE`, `.UNATTENDED` or `.KMIP`; `.RESTART` for IRISSECURITY or IRISTEMP; `.JOURNAL` for the journal flag. `InputSchema` says the person types the password at confirm.
- `Area/Security/EncryptionStartupSave.cls` (new): `HandleUpdate` (`PUT /encryption-startup`, the Save through the tool, taking, using and clearing `AdminPassword`, answering `consequence` and `readBack`) and `HandleForm` (`GET /encryption-startup/form`, `{kmipServers}`); `Api/Router.cls` (add-only) routes them, the form route first.
- `Screen/Descriptor/EncryptionStartup.cls` (new, as Boundaries; aliases "encryption startup", "startup settings"); `Kernel/EntityType.cls` `encryption-startup`; `Kernel/EntityRef.cls` `encryption-startup:singleton`.
- `Kernel/Proposal/Prohibited.cls` (add-only): `TYPEENCRYPTIONSTARTUP` joins `COVEREDTYPES` (44), the fail-closed list and the dispatch through `ReviewedFewOnly`, its `PermittedChangeFields` the tool's plus `root`, `path` and `AdminPassword`; `EFFECTAUDITENCRYPTION` = `AUDIT.ENCRYPTIONCHANGE`, which `WeakensByEffect` answers when the payload's `AuditEncrypt` differs from the target's. DW-2065: `KeyFile` also receives the target's composite, and for `AdminInFile` `DELETE` a true `STARTUPADMIN` or a failed read refuses `PROHIBITED.STARTUPADMIN` (`Codes()` 28): "The instance activates its encryption keys at startup from this key file, so its administrators are not removed here."
- `Kernel/Governance/Baseline.cls` (add-only): `"security.encryptionstartup.update": false`. `Screen/Tool/Classification.cls`: every row `ordinary` but `AdminPassword` `secret`, `compare` `{"AdminName": "written"}`; regenerate `ToolFields.cls`.
- `Api/EncryptionError.cls` (add-only): `Codes()` and `ViolationCodes()` list the startup codes; the seven consequence codes (`ENCRYPTION.STARTUP.NONE`, `.INTERACTIVE`, `.UNATTENDED`, `.KMIP`, `.RESTART`, `.JOURNAL`, `AUDIT.ENCRYPTIONCHANGE`) carry the sentences below, published at EXPERIENCE.md:364 in the same words.

**Execution (client)** (`ui/src/app/`):

- `areas/security/encryption-startup.page.ts` and `.store.ts` (new, with specs; `DESCRIPTOR_PAGES`), on the ECP form model:
  - four start-mode radios with their sentences, KMIP `aria-disabled` with "No KMIP server is configured on this instance." while `kmipServers` is empty, else a KMIP server select;
  - Unattended: the stored key file read-only, a `server-path-picker` (`kind` `file`), Administrator name, and a page-local masked Password cleared on save, leave and destroy;
  - four checkboxes with their sentences ("Encrypt IRISSECURITY", "Encrypt IRISTEMP, IRISLOCALDATA and IRISMETRICS", "Encrypt journal files", "Encrypt the audit log"), each `aria-disabled` with its reason while turning it on is refused;
  - default and journal key selects over Database encryption's declared read, `aria-disabled` with "No database encryption key is active." when it is empty;
  - the sticky Save: when `AuditEncrypt` changed, `app-typed-name-dialog` first (verb "Change audit log encryption", target and typed name `IRISAUDIT`, the audit sentence, the advisory); refusals on their fields.
- `areas/security/encryption-keys.page.ts` (add-only): a "Configure startup settings" link on Database encryption only. `core/proposal-view.ts`: the seven codes. `app.ts`: the store's sign-out reset, if root-provided.
- `core/strings.ts` (add-only, each key under its `/** EXPERIENCE.md:n */`; past 2700 literals, the bound becomes 2800 with its history line); regenerate `screens.generated.ts`. `ui/angular.json`: re-base `maximumWarning` under DW-1166 to the measured total; stop and ask above 3800kB.
- **EXPERIENCE.md, in place, keeping 1036 lines** (then `cd ui && npm run test:tools`): :168 adds "the encryption startup settings"; :173 adds "change the audit log's encryption on Encryption startup settings (Story 18.23: the destructive treatment, typed name `IRISAUDIT`)"; :364 adds "; and Encryption startup settings (Story 18.23): …" with every new literal (DW-2065: and the `PROHIBITED.STARTUPADMIN` sentence), tagged `[ADDED <date> - Story 18.23]`; :516 adds the audit sentence and advisory.

**The published sentences** (a bracketed clause is set from the Task 0 record, otherwise left out):

| Option | Sentence |
| --- | --- |
| None | "Keys are not activated at startup. After each start, encrypted databases stay unmounted until someone activates their key on Database encryption." [Step 7 clears the startup administrator and passphrase: "Choosing None discards the instance's stored unattended credential." Keeps them: "The instance keeps its stored unattended credential."] |
| Interactive | "Each start asks for a key file on the instance's console. When nobody answers, as in a container, the instance starts without the key and leaves encrypted databases unmounted." |
| Unattended | "Not recommended. The instance stores a credential of its own for this key file and activates the keys at every start with no one present, so anyone who can start the instance and reach the key file can read encrypted data." [Step 4's `AdminList` names an administrator nobody added: "That credential is an administrator the instance adds to the key file", plus ", which stays there after unattended activation is turned off" when step 7 still lists it, and "."] |
| KMIP | "Each start activates the keys from this KMIP server with no one present." |
| IRISSECURITY, IRISTEMP | "Takes effect at the next restart." |
| Journal | "New journal files are encrypted from the next journal switch or restart. Switch the journal file on Journals to start now." |
| Audit log | "Takes effect at the next start, when the instance encrypts or decrypts the audit database in place; every audit record, the agent's own markers included, is kept." [Step 12, IRIS started and auditing did not record: "While it is encrypted, a start that cannot activate its key starts without auditing." IRIS did not finish starting: "While it is encrypted, a start that cannot activate its key does not finish."] |
| Audit advisory | "Keep the key file and its administrator available to every start." |
| Default key / Journal key | "New encrypted databases use this key." / "New encrypted journal files use this key." |

**Rosters and CI:** extend every roster in Code Map › Rosters (the Security pins gain one unlisted route); `AHEADTYPES` becomes `""`; the armed classes join `ci-throwaway.sh`'s `OCUPILOT_ALLOW_ENCRYPTION_CONFIG` line and the gate class `OCUPILOT_ALLOW_PRINCIPALS`'s, whose comment "never activate or deactivate a key, change no encryption setting" stays true.

**Tests:**

- `Test/EncryptionSeamPort.cls` (add-only modes): `startup` (a `Settings` `PUT` never reaches the vendor, its body key names and `AuditEncrypt` recorded, and applies to a seam-held object that later `GET`s answer and a test may change between mint and confirm; `Key` `LIST` answers 18.22's held list), `startupfails`, `kmip`, `settingsv1`, and (DW-2065) `startupadmin`, `startupadminfails`. Under any other mode only a `PUT` equal to the current settings reaches the vendor (the real leg); any other is answered 500. `Test/SeamEncryptionStartupUpdate.cls` and a Save fixture follow.
- `Test/EncryptionStartupRead.cls` (C1, the reads' pairs); `Test/EncryptionStartupGate.cls` (`OCUPILOT_ALLOW_PRINCIPALS`; each declared pair and the path pair refused by name with zero port calls); `Test/EncryptionStartupDescriptor.cls` (the descriptor, codes and sentences, baseline key, effect, `Snippet`'s branches, `FieldLists`' credential rows).
- `Test/EncryptionStartupWrite.cls` (`OCUPILOT_ALLOW_ENCRYPTION_CONFIG`): the matrix's seam rows on both callers with body key names and read-backs, and the real unchanged `PUT`; **read at the write** (a start-mode proposal's payload has no `AuditEncrypt`, and its confirm sends the held value toggled after the mint); **the reviewed value** (an `AuditEncrypt` proposal's confirm after that toggle is refused with zero `PUT`); facts restored after each test.
- DW-2065: `Test/EncryptionKeyFileWrite.cls` (add-only) `startupadmin` and `startupadminfails` legs on both callers.
- Component specs for the page, store and link; `ui/browser/encryption-startup.browser-spec.mjs` (refuses a non-throwaway; facts unchanged after): the link, the form, the sentences and `aria-disabled` reasons, Unattended's fields, an Unattended Save with no file refused with no `PUT`, the DW-1337 gate in both themes.

**Acceptance Criteria:**

- **C0:** Given `ocupilot-b-ci` at S0, when the implement stage starts, then Task 0's re-run records DW-2065's restarts, the `None` reset, the startup-required code and a start that cannot activate the key with the audit log encrypted, in that order, before any descriptor, tool or page, and ends with the planned rebuild halt; a contradiction halts the story.
- **C1:** Given the form and `security.encryptionstartup.read`, when each reads, then both answer the same nine settings, and no answer, DOM, screen context or tool result carries a password or key material.
- **C2:** Given the four start modes and four flags, when a person opens the form or the agent proposes a change, then each option shows its published sentence, Unattended marked not recommended, KMIP `aria-disabled` with its reason while none is configured, and the card names the change's consequence code.
- **C3:** Given a change, when a person saves it or confirms the agent's proposal, then one `Settings` `PUT` is sent through the seam with the Boundaries' body, `AuditEncrypt` as read at the write unless the change sets it, key ids only when changed, with a read-back.
- **C4:** Given an `AuditEncrypt` change, when the agent proposes it, then the proposal is destructive with the audit consequence, behind `security.encryptionstartup.update` shipping `false`, and its confirm is refused once the reviewed value moves; when a person saves it, the typed-name dialog (`IRISAUDIT`) states the sentence and advisory before any `PUT`, and the Save is not governed.
- **C5:** Given a change the rules refuse, when either caller submits it, then it is refused on its field with zero `PUT`; a vendor refusal arrives as OcuPilot's sentence.
- **C6:** Given a `Settings` template without `AdminName` or `AdminPassword`, when either caller writes, then it is refused 501 `PORT.NOTIMPLEMENTED` with zero `PUT`.
- **C7:** Given a password entered, when a write runs or fails, then no read, log line, ledger row, proposal, store, screen context, answer or DOM holds it after save, and the agent's card asks for it as a masked row.
- **C8 (DW-2065, only if R1 does not activate):** Given the key file the instance activates its keys from in Unattended mode, when either caller removes one of its administrators or the startup read fails, then the removal is refused `PROHIBITED.STARTUPADMIN` with nothing sent, while another key file's administrator is removed.
- **C9:** Given the rosters, when the story lands, then the form is unlisted and reached from Database encryption's link with three prompts, its key is in the baseline `false`, every roster includes the screen and tool, the DW-1337 gate holds in both themes, and EXPERIENCE.md reads 1036 lines.

## Spec Change Log

- 2026-10-05, spec gate (runner): Decisions 1 to 8 confirmed. Decision 1 verified by the runner in the vendor source (`ValidateRequest` builds `RequestValidator(schema, 1)`, exempting only the key ids and the v2 credentials; `RunPut` passes `req.AuditEncrypt` to `ConfigStart`); amendment 9 applied at origin (epics.md :7519, `epic-18-context.md`) and reported to the orchestrator. Spine amendments 1 to 6 written (AD-4, AD-10 two items, AD-13, AD-26, AD-27, AD-44); 7 and 8 wait for Task 0, with ordinals taken from the spine when written.
- 2026-10-05, Task 0 (implement), for the runner. AD sentences from the record (Design Notes › Measured at implement), not applied:
  - **AD-8 (amendment 7):** "**Story 18.23's startup settings** declare Security's set; the write declares no pair beyond it, and the path port's `%Admin_FileSystemAccess:USE` when a root is sent; `STARTUPADMIN` reads under Security's set and `%Admin_FileSystemAccess:USE` (measured on `ocupilot-b-ci`, 2026-10-05: a principal holding exactly Security's two pairs read the settings and the KMIP servers and wrote the unchanged `PUT`)."
  - **AD-15 and AD-53 (amendment 8):** no named case, because every settings `PUT` measured records `%System/%Security/DBEncChange` "Encryption settings modified". The agent's marker records right after an `AuditEncrypt` change and after the next restart (on direction only).
  - **AD-10, intent gap (blocks the story):** the item "Changing the audit log's encryption deletes every audit record" is contradicted for the on direction. Nothing was deleted at once, and the next start encrypted `IRISAUDIT` in place, keeping every record. The owner decides the treatment and the sentence. The off direction needs its own measurement, and a fresh throwaway.
  - **AD-10, DW-2065's item:** unattended activation stores a hidden generated administrator (`<key id>_1`), not the typed one, and the key file's administrator list omits it. As written, the arm refuses only that hidden name, so removing the typed administrator stays permitted and does not affect unattended activation (inference: activation uses the hidden administrator). Decision 7's premise needs the owner's re-read.
- 2026-10-05, runner, after the implement stage's step-17 halt (measured on `ocupilot-b-ci`, evidence `/tmp/epic-18-d7/1823/t0/s14*.out`, `s18x.out`): step 14 ran. `AuditEncrypt` false answered 200 and changed nothing at once (`IRISAUDIT` still encrypted with K1, every record kept). After a graceful restart (12:28:39Z) `messages.log` reads "Decrypting IRISAUDIT database"; `IRISAUDIT` is unencrypted, the same `IRIS.DAT` (inode 12766), the oldest record (05:34:18Z) and the agent's markers kept. So both directions keep every audit record and take effect at the next start, converting the database in place. Also measured: `AdminInFile` `DELETE` of the file's only listed administrator is refused ("A key file keeps at least one administrator"); the hidden startup administrator does not count and is never listed. Steps 15 and 16 were not run; the runner rebuilt the throwaway. Status stays `blocked` until the owner decides `AuditEncrypt`'s treatment and DW-2065's scope (orchestrator clarification). Orchestrator conditions on Decision 1 (2026-10-05): the echoed `AuditEncrypt` is read at the write, never carried from the mint, and a proposal that changes it fingerprints the reviewed current value.
- 2026-10-05, merge gate answers (orchestrator, under the owner's standing grant; reported to the owner), applied to the intent contract by the runner: `AuditEncrypt` option A (treatment kept, consequence and advisory measured, the key-activation line labeled `(inference)` until Task 0 measures it); DW-2065 option A with a measurement gate; the `ENCRYPTION.KEYFILE.PASSWORD` row; the read-at-write and fingerprint conditions. Deletion claim corrected at origin (epics.md :7519, the spine's AD-10, the epic context, `spec-1-3` :108, `Installer.cls`); AD-10's startup-administrator item and AD-27's `STARTUPADMIN` read withdrawn pending the measurement; DW-2095 filed (vendor documentation candidate). Status `blocked` to `draft` for the re-plan.
- 2026-10-05, re-plan spec gate (runner): Decisions confirmed; the reviewed-value fingerprint made concrete (Execution, `MergeUpdate`), since a key the arguments set is digested at its new value; AD-8 written to the spine (measured); the brief's "409" for the last-administrator refusal corrected by the plan to 400 `TOOL.ARGUMENTS`.
- 2026-10-05, Task 0 re-run (implement), for the runner. These are taken from the record (Design Notes › Measured at implement, re-run) and are not applied. Task 0 ended at step 13's planned halt; no step-14 halt was met.
  - **DW-2065, by-design:** R1 and R2 both activated. Unattended activation opens the key file as a hidden generated administrator (`<key id>_N`, one more per Unattended write) that only `$$AdminList^EncryptionKey` with flag 0 names, so removing any listed administrator, the typed one included, leaves it working. Amendment 3 is not written, and AD-10's startup-administrator item and AD-27's `STARTUPADMIN` read stay withdrawn.
  - **AD-10's audit item (amendment 2):** "while it is encrypted, every start needs the key (inference)" becomes "While it is encrypted, a start that cannot activate its key does not finish" (R4: startup aborted in single-user mode).
  - **The sentences' bracketed clauses:** None takes "Choosing None discards the instance's stored unattended credential." (step 7). Unattended takes "That credential is an administrator the instance adds to the key file, which stays there after unattended activation is turned off." (steps 4, 7, 11). The audit log takes the clause above.
  - **`ENCRYPTION.STARTUP.REQUIRED`:** #1217 measured (step 10, vendor 500, logged at severity 2 and reaching `alerts.log`); #1212 and #1213 by their text (inference).
  - **Decision 8 needs a ruling:** with the audit log encrypted, the vendor accepts Interactive (step 11), and the next start with no console does not finish (R4). Interactive's published sentence ("the instance starts without the key") therefore does not hold while `AuditEncrypt` is on. Open: whether a start-mode change away from Unattended (or KMIP) while the audit log is encrypted is refused, takes the destructive treatment, or carries the audit clause.
  - **For DW-2087 and the read-back:** the `None` reset also clears `Security.System`'s persisted default and journal key ids while the running keys stay, and the `Settings` `GET` answers the running ids (step 7).
- 2026-10-05, Decision 8 (merge gate under the owner's standing grant, option A), applied by the runner: Interactive key activation is refused while the audit log, IRISSECURITY or IRISTEMP is encrypted, now or at the next start, in both orders (`PROHIBITED.STARTUPINTERACTIVE`, AD-10's serving-path arm, written to the spine). The runner measured IRISTEMP and IRISSECURITY on `ocupilot-b-ci` (`/tmp/epic-18-d7/1823/t0m`: one real activation, Unattended, the flag on, restart: encrypted in place, healthy; then Interactive, restart: "Failure activating required database encryption key. Startup aborted, entering single user mode."), so the rule carries no inference. Interactive's published sentence gains: "While the audit log, IRISSECURITY or IRISTEMP is encrypted, a start nobody answers does not finish, so Interactive is not offered." The form draws Interactive `aria-disabled` with that reason while one of the three is set, and each of the three checkboxes `aria-disabled` with it while the mode is Interactive. DW-2065 closed by-design (Task 0 re-run); the build deletes the `STARTUPADMIN` plumbing and keeps `KMIPSERVERS`. Task 0 is complete; the throwaway was rebuilt at 13:43Z. The code review's baseline is `2b3e5e24`, this story's first implement pass, so `f268a30e`'s plumbing stays in the reviewed diff. Status `blocked` to `in-progress` for the build.

## Review Triage Log

## Design Notes

**Governing ADs:** AD-2, AD-27, AD-52 (`EncryptionPort` extends `AdminPort`; `KMIPSERVERS` is AD-27's 18.23 case, and `STARTUPADMIN` joins it only on DW-2065's breaking branch); AD-26 (the version gate; nothing queues); AD-3, AD-4 (the merge and its named exception); AD-5, AD-36, AD-44 (one descriptor whose page issues Database encryption's read; no `CLASSICPAGES`); AD-6, AD-34, AD-40, AD-53, AD-55, AD-56 (two callers of one tool, the closed confirm channel over `AdminPassword`); AD-8, AD-29 (Security's pairs, measured); AD-10 (`AUDIT.ENCRYPTIONCHANGE`; `PROHIBITED.STARTUPADMIN` only on the breaking branch); AD-13, AD-14 (the singleton, its change event); AD-15, AD-53 (a vendor event on every settings `PUT`, so no named case); AD-21 (the key file as a sixth-case `source`); AD-22 (one key, `false`); AD-24, AD-35, AD-48 (no secret returned or logged); AD-39; AD-58; AD-59.

**Measured at plan** (read-only on `ocupilot-b-ci`, 2026-10-05 11:08-11:10 UTC; `/tmp/epic-18-d7/1823/plan/probes.txt`):

- `Settings` `GET` under v2: 200 in 5.5-6.7 ms, `{"DBEncStartMode":"None", four false, five ""}`.
- `Security.System`: every encryption property 0 or `""`, `DBEncStartPassphrase` empty, `AuditEnabled` 1. No database or data-element key active. No KMIP server configured. `PendingRestart` 0.
- `IRISAUDIT` at `/durable/iris/mgr/irisaudit/`: not encrypted. Its `IRIS.DAT` is inode 12766, 134,217,728 bytes, modified 2026-10-05 10:52:49Z, born 2026-06-26 18:00:36Z. 222,237 audit events.
- `DATABASE1` is object code only. `%SYSTEM.Security.System`'s key methods are kernel-dispatched (inference).
- **Sources disagree on `AuditEncrypt`'s timing and effect.** `Security.System`'s doc says the audit database is deleted as soon as the property changes. The classic page's hint says it takes effect at the next restart. `MakeIRISAudit` converts the database in place at startup, keeping its data. The official documentation says both. Task 0 measures it (Decision 2).

**Measured at implement** (Task 0 on `ocupilot-b-ci`, 2026-10-05 12:16-12:21 UTC, as `_SYSTEM`; `/tmp/epic-18-d7/1823/t0/`, one `sN.txt` script and `sN.out` record per step). Steps 1-13 ran; step 13 met step 17's contradiction, so 14-16 did not run.

- **1, plumbing:** `EncryptionPort`'s `Settings` `GET`/`PUT` branches, `SettingsGate`, `StartupProblems`, `KMIPSERVERS`, `STARTUPADMIN`; `EncryptionError`'s six startup codes and `REASONSETTINGSVERSION` (not yet in `Codes()`); `Test/EncryptionStartupProbe.cls`. Loaded and compiled clean.
- **2, S0:** as at plan: every encryption fact 0 or `""`, no active key, `IRISAUDIT` unencrypted, inode 12766, 222,237 events, `PendingRestart` 0.
- **3, reads:** `Settings` `GET` through `AdminPort` and through `EncryptionPort` 200 in 0.3-0.6 ms; `KMIPSERVERS` 200 `{Names: []}` in 0.1 ms; `STARTUPADMIN` 200 `false` in 0.7-1 ms. A principal holding exactly Security's two pairs read the first two; `STARTUPADMIN` refused it 403 naming `%Admin_FileSystemAccess:USE` and answered once that pair was added; without `%Admin_Secure:USE` each read is 403 naming it. No read is a declared read yet (no descriptor at Task 0).
- **4, version gate:** the template at API version 2 carries `AdminName` and `AdminPassword`; `SettingsGate` answers OK in 0.3 ms.
- **5, refusals:** all 18 cases (KMIP with none configured or none named, Unattended with no file, a new file with no password, no name, an unlisted administrator or a refused root, a flag on with None, a flag or `AuditEncrypt` on with no active key, an inactive default or journal id, an unknown mode, a flag that is not boolean, a body or query naming a file, a non-object body) answered their code on their field with zero `PUT` (the seam recorded only reads), no log line, no audit row, facts unchanged.
- **6, vendor validation:** a body lacking `AuditEncrypt` answered 400 #40301 (`PORT.VALIDATION`, `PORT.FIELD.REQUIRED` on `AuditEncrypt`), one severity-2 `messages.log` line, nothing changed.
- **7, unchanged `PUT`:** a real leg. 200 in 5 ms, the seven keys sent, no fact changed, one vendor event `%System/%Security/DBEncChange` "Encryption settings modified", audit identity unchanged.
- **8, pairs:** the principal holding exactly Security's two pairs wrote step 7's `PUT` (200, its own `DBEncChange` row). No pair beyond Security's set is needed.
- **9-10:** `start-a.key` seeded (K1 `FFD16635-C0B6-11F1-9289-EE197E2E7394`); its activation through `EncryptionPort` set `DBEncStartMode` 0 to 1 and both key ids to K1, as 18.22 measured (`DBEncChange` "Encryption key(s) activated", `SystemChange`).
- **11, Unattended:**
  - A wrong password answered 500, status #5001 `<FUNCTION>ConfigStart+123^DATABASE1`, logged at severity 2, with nothing changed: facts, `Security.System` and the key file read as before, no audit row.
  - The right one answered 200 in 51 ms. `DBEncStartKeyFile` holds the resolved path exactly as sent and `DBEncStartPassphrase` is set (32 bytes).
  - `DBEncStartUsername` is a **hidden generated name** (`<K1 id>_1`), not the typed one. `AdminInFile` `LIST` and the vendor's own admin list name only the typed administrator.
  - `STARTUPADMIN` answers true for the stored (hidden) name and false for the typed name and for another file.
  - Events: `SystemChange`, `DBEncChange` "Encryption settings modified".
- **12, `AuditEncrypt` on:** 200 in 37 ms (`SystemChange`, `DBEncChange`). At once nothing happened to the audit database: still unencrypted, same file, oldest row (05:34:18) kept. OcuPilot's marker answered 1 just before and just after, and both rows read back. `PendingRestart` 0, no log line.
- **13, restart:** healthy in 26 s. `messages.log`: unattended activation from `start-a.key` (K1 active, default and journal key), then "Encrypting IRISAUDIT database with key K1", a dismount and a mount, "Auditing to ...". `IRISAUDIT` reads `EncryptedDB` 1 with K1, **same inode 12766 and size, every record kept** (oldest row 05:34:18, both step-12 markers present), and a new marker records.
- **Contradiction (step 17):** the audit records survive an `AuditEncrypt` change (off to on) at once and at the next restart, contradicting the owner decision's premise. The on-to-off direction is unmeasured.
- **Left on `ocupilot-b-ci`:** `DBEncStartMode` 2 with `start-a.key` and its hidden administrator, `AuditEncrypt` 1, `IRISAUDIT` encrypted with K1, K1 active as default and journal key, both persisted ids K1, and `<ManagerDirectory>ocuprobestart/` holding `start-a.key` and `start-r.key`. That key file is what the next start activates from, so it must not be removed before a rebuild. The probe principals were removed.
- **Set from the record, for the re-plan:**
  - the credentials refusal is #5001 at 500 on `Settings`, shared with internal faults, so it stays logged (named limit 3) and maps only when the port sent credentials;
  - `ENCRYPTION.STARTUP.REQUIRED`'s vendor codes are unmeasured (#1212, #1213, #1217 read in message text, inference);
  - the tool declares no `EXTRAPAIRS`;
  - the `PUT` has a vendor event, so no AD-15 or AD-53 named case;
  - the marker survives the on change;
  - the seam's `STARTUPADMIN` fixture is the hidden name.
- **14 (runner, after the halt; `s14.out`, `s14r.out`, `s18x.out`):** `AuditEncrypt` false answered 200 in 38 ms and changed nothing at once. After a graceful restart `messages.log` reads "Decrypting IRISAUDIT database", and `IRISAUDIT` is unencrypted in the same `IRIS.DAT` (inode 12766), its oldest record (05:34:18Z) and the agent's markers kept: both directions take effect at the next start and keep every record. `AdminInFile` `DELETE` of the file's only listed administrator was refused by the vendor and answered 400 `TOOL.ARGUMENTS` ("A key file keeps at least one administrator."); the hidden startup administrator is not listed and does not count.

**Measured at implement, re-run** (Task 0 re-run on `ocupilot-b-ci`, 2026-10-05 13:07-13:22 UTC, as `_SYSTEM`, every write through `EncryptionPort`; `/tmp/epic-18-d7/1823/t0r/`, one `rN.txt` script and `rN.out` record per step, `rNr` after a restart, `restart-RN.txt` per restart). K1 is `D06ECF7F-C0BD-11F1-ADE7-C6B998C71C8F`. The probe passwords were generated at run time, read from the environment, never written to a script, record or log (checked after every step), and removed at step 13.

- **1, S0 (`r1`):** every encryption fact 0 or `""`, no active key, `IRISAUDIT` unencrypted, inode 37734, 22,020,096 bytes, 30,452 events, oldest row 2026-06-26 17:58:25Z, no probe object. Snapshot and audit facts saved as `<ManagerDirectory>Temp/ocuprobestart-r1-s0.json` and `-r1-auditfacts.json`.
- **2-3 (`r2`, `r3`):** `start-a.key` seeded with K1 and A; B and C added through `AdminInFile` `POST` (201 each). Activating K1 as A set `DBEncStartMode` 1 and both persisted ids to K1, as before.
- **4, Unattended as A (`r4`):** 200 in 59 ms. The key file changed (550 to 714 bytes, new `sha256`). `$$AdminList^EncryptionKey` with flag 0 names `<K1>_1` besides A, B and C; flag 1 and `AdminInFile` `LIST` name only A, B and C. `DBEncStartUsername` is `<K1>_1`, passphrase 32 bytes.
- **5, R1 (`r5`, `r5r`):** B removed (200), then R1 healthy in 20 s. `messages.log`: "Using encryption key file .../start-a.key", "Activating encryption key K1", then the default and journal key; `Key` `LIST` answers K1. **R1 activated.**
- **6, R2 (`r6`, `r6r`):** A, the typed administrator, removed (200; C listed, flag 0 also `<K1>_1`), then R2 healthy in 20 s with the same three activation lines. **R2 activated.**
- **7, the `None` reset (`r7`):** 200 in 13 ms. It clears `DBEncStartKeyFile`, `DBEncStartUsername` and the passphrase (32 to 0 bytes), and also `Security.System`'s persisted `DBEncDefaultKeyID` and `DBEncJournalKeyID`. K1 stays active as the running default and journal key, and the `Settings` `GET` still answers K1 for both ids. The key file is unchanged; flag 0 still lists `<K1>_1`.
- **8, Unattended as C (`r8`):** the port sent credentials, because step 7 had cleared the stored file. 200 in 60 ms. A second hidden administrator, `<K1>_2`, is added and stored; `<K1>_1` stays (flag 0: `<K1>_1`, `<K1>_2`, C).
- **9, R3 (`r9`, `r9r`, `r9m`):** `AuditEncrypt` on, 200 in 37 ms, nothing at once. R3 healthy in 20 s: "Encrypting IRISAUDIT database with key K1", a dismount and mount, "Auditing to ...". `IRISAUDIT` reads `EncryptedDB` 1 with K1, same inode and size; the oldest row and all 30,452 rows before the re-run are kept; both step-9 markers are kept, and a marker records after R3. The start set the persisted ids back to K1.
- **10, startup required (`r10`):** `None` with every flag false while `IRISAUDIT` is encrypted. The vendor refused it with #1217 "Cannot disable encryption key activation at startup. Encrypted databases are required at startup: /durable/iris/mgr/irisaudit/" at 500. The port answered 500 `INTERNAL` and logged the status at severity 2, which reached `alerts.log`. No fact moved, no audit row was written, and the key file was unchanged.
- **11, Interactive (`r11`):** applied, 200 in 12 ms, `AuditEncrypt` kept on. Mode 1, the startup key file, administrator and passphrase cleared, persisted ids K1, the hidden administrators still in the file. No key file was set aside.
- **12, R4 (`r12`, `restart-R4.txt`, host copies `r12-messages.log`, `r12-alerts.log`, `r12-container.out`):** not healthy. IRIS did not finish starting. At each of 8 attempts (4 container starts) it logged "Database encryption key activation failed. Failure activating required database encryption key. Startup aborted, entering single user mode." with no "Auditing to" line. The start hook read "Sign-on inhibited", and the container exited 1 after `on-failure:3`. Probing stopped.
- **13, teardown (`r13`):** no key file was set aside, and this re-run created no probe principal. The password file was removed, so no credential that opens `start-a.key` remains.
- **Probe note:** `AuditFacts`' `count` (`COUNT(*)` on `%SYS.Audit`) did not move as rows were added, and a `WHERE Event = 'AgentWrite'` read returned no rows that a time-range scan found, so the markers were read back by time range (inference: both read a structure the audit writer does not keep current).
- **Left on `ocupilot-b-ci` against S0:** exited, unhealthy, `RestartCount` 3. Every start aborts in single-user mode. Persisted settings: `DBEncStartMode` 1 (Interactive), `AuditEncrypt` 1, `DBEncDefaultKeyID` and `DBEncJournalKeyID` K1, startup key file, administrator and passphrase empty, the other flags 0. `IRISAUDIT` is encrypted with K1. `<ManagerDirectory>ocuprobestart/` holds the marker and `start-a.key` (K1; C listed; `<K1>_1` and `<K1>_2` hidden). `<ManagerDirectory>Temp/` holds the two `ocuprobestart-r1-*.json` files. `alerts.log` and `messages.log` hold the #1217 line. There are no probe principals.

**Decisions:**

1. **`AuditEncrypt` is always sent, as read at the write unless the change sets it.** The vendor requires it in every `PUT` (400 #40301, step 6) and passes it to `ConfigStart` whatever it holds, so only sending the value read at the write keeps a start-mode change from altering it. The payload omits it unless the proposal changes it, and a proposal that changes it fingerprints the value it reviewed (orchestrator conditions 2026-10-05).
2. **Task 0's re-run makes one real activation and up to four graceful restarts, on `ocupilot-b-ci` only,** each restart's subject set up by the steps before it, and R4, which may not come up, last, so the rebuild is planned. IRISSECURITY, IRISTEMP and journal encryption are never measured.
3. **The audit sentence is measured; the treatment is the owner's** (merge gate option A): the destructive treatment stands with the measured consequence and the advisory, and the key-activation clause comes from R4 or is left out.
4. **The version gate reads the live template**, narrower than `AdminPort`'s v2 check (`InvokeLocated` :1176-1189), on `AtelierPort`'s 501 model.
5. **Key ids go only when changed:** the vendor saves `Security.System` before checking the id's status (:86-97), so a re-sent `""` with no key active would half-apply.
6. **The key file and credentials mirror the classic page:** the file for Unattended only, the credentials for a new Unattended file only.
7. **DW-2065 is measurement-gated.** OcuPilot never sends the hidden startup administrator's name: both callers refuse a name the file does not list, and #1222's text says the vendor refuses removing it (not measured). Open is whether removing a listed administrator breaks unattended activation (R1, R2). Only R1 breaking can be built from stored state, because the instance stores no typed name (step 11); R1 activating while R2 breaks goes to the owner (Task 0 step 14).
8. **No AD-10 arm for Interactive or None on an encrypted instance:** the vendor refuses turning startup activation off while encrypted databases need it (#1217, its text), and Interactive's sentence states the measured restart behavior.

**Named limits:** (1) the read-back does not compare the startup key file, which only the port composes (AD-21); (2) the agent cannot list KMIP server configurations, and none exists here; (3) a vendor refusal the rules did not pre-empt, the credentials refusal (#5001) included, is a 500 logged at severity 2 until DW-2007's grammar; (4) the `AuditEncrypt` typed-name dialog never renders in a browser on a real instance, because no key is active there, so the component spec covers it.

**Proposed amendments** (the runner writes them, taking any ordinal from the spine):

1. **AD-8, now:** the sentence in the Spec Change Log's Task 0 entry (measured at steps 3 and 8), without its `STARTUPADMIN` clause, which joins only with amendment 3.
2. **AD-10's audit item, after the re-run:** "while it is encrypted, every start needs the key (inference)" becomes the audit sentence's step-12 clause, or is removed when step 12 sets none.
3. **Only if R1 does not activate, after the re-run:** AD-10 gains "**The unattended startup key file's administrators** (Story 18.23, DW-2065): while the start mode is Unattended, removing any administrator from the key file the instance activates its keys from is refused `PROHIBITED.STARTUPADMIN`, from either caller, read at the write; a read that fails refuses." AD-27's 18.23 case gains `STARTUPADMIN`: "whether `Security.System`'s `DBEncStartKeyFile` names a given key file while `DBEncStartMode` is Unattended, read in `%SYS` after `%Admin_Secure:USE`; a failure fails the read."
4. AD-15 and AD-53: none (every settings `PUT` records `DBEncChange`).

**Integration ACs:** the form consumes the declared read, `GET /encryption-startup/form` and `PUT /encryption-startup` against `ocupilot-b-ci` (C1, C3, C5; `EncryptionStartupRead`, `EncryptionStartupWrite`, the browser spec); `Mint` consumes `AUDIT.ENCRYPTIONCHANGE` (C4); DW-2065: `Prohibited.KeyFile` consumes `STARTUPADMIN` on `removeadministrator` (C8; `EncryptionKeyFileWrite`).

**Consumes:** 18.22 (Database encryption's page and read, the seam's held keys), 18.7 (`EncryptionPort`, key files, `EncryptionRules`, `EncryptionError`, the probe), 18.1 (`PathPort`, the picker), 18.21 (the form model), 14.2 (the purge treatment), 16.17's read-back, 14.1's `Snippet`. **Consumed-by:** 18.12 (the agent's tool set); Epic 18's burn-down (DW-2087 may lean on the measured `None` reset).

**Ledger inbox (Rule 17):** DW-2065 is addressed by Task 0 steps 2-7 and 14, Set from the record, C8 and the matrix row.

**Footprint (Rule 11):** contended files add-only (Boundaries); for `footprint_extensions`: `Port/EncryptionPort.cls`, `Port/AdminPort.cls`, `Api/EncryptionError.cls`, `Kernel/EntityType.cls`, `Kernel/EntityRef.cls`, `Screen/Tool/Classification.cls`, `areas/security/encryption-keys.page.ts`, `core/proposal-view.ts`, and the new classes, page, store and specs.

**Size:** about Story 18.22's, plus the re-run's rebuild (inference); not split, because every part hangs on the one `Settings` `PUT`.

## Verification

**Setup (slot B):** load with `/tmp/epic-18-d7/load-throwaway.sh` (no restart outside Task 0), never through the MCP loader; every write lands on `ocupilot-b-ci`. One test class per call, the next only once the previous has landed in `%UnitTest_Result`, never re-submitted after a client-side timeout. Before a browser run: `cd ui && npm run build`, copy `dist/ocupilot-ui/browser/.` to `/tmp/ocupilot-b-ci/ui/dist` and `docker cp` it to `ocupilot-b-ci:/durable/iris/csp/ocupilot/`, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci`.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one at a time, 0 failures checked against `%UnitTest_Result`: `EncryptionStartupRead`, `EncryptionStartupWrite`, `EncryptionStartupGate`, `EncryptionStartupDescriptor`, (DW-2065) `EncryptionKeyFileWrite`; and the rosters `Descriptor`, `ReadTool`, `SurfaceCoverage`, `Prohibited`, `GovernanceBaseline`, `Governance`, `ToolDispatch`, `ToolRoundTrip`, `ToolWrite`, `DraftRegistry`, `ClassicPageGate`, `MappingDescriptor`, `Wire`, `WireSecurityRead`, `WireOAuthRead`, `EntityRef`, `EncryptionDescriptor`, `DerivedFields`, `Inventory`.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/encryption-startup.browser-spec.mjs browser/encryption-keys.browser-spec.mjs browser/security.browser-spec.mjs`; pass.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`, `uv run scripts/check-objectscript.py <changed .cls>`, `bash scripts/lint-docs.sh`; clean, EXPERIENCE.md 1036 lines.
- `(once, before dev_complete)`, each green with a non-zero count: the full ObjectScript sweep (`cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci`, one class at a time); `cd ui && npm test && npm run build`; `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`; then no `OCUPROBESTART` file or principal remains and every encryption and audit fact reads as at the build's S0.
- `(CI)` the full browser suite, in CI's three `browser-shard` jobs (Rule 29).

**Planned pinning mutations (Rule 19)** (apply on the throwaway, observe red, revert byte-identical, record a `mutation:` line here):

- C1: the read declares `LIST` for `GET` → `EncryptionStartupRead`'s equality leg.
- C2: KMIP's `aria-disabled` reason dropped (rebuilt) → the page spec and the browser spec; `Consequence`'s `.UNATTENDED` branch dropped → `EncryptionStartupDescriptor`.
- C3: `MergeUpdate` keeps the mint's `AuditEncrypt` → the read-at-the-write leg; unchanged ids kept → the ids leg.
- C4: `WeakensByEffect`'s `AUDIT.ENCRYPTIONCHANGE` branch dropped → the destructive leg; the reviewed value not fingerprinted → the reviewed-value leg; the dialog branch skipped → the page spec.
- C5: `StartupProblems`' active-key check dropped → `ENCRYPTION.STARTUP.NOKEY`'s leg, a `PUT` recorded.
- C6: `SettingsGate` always OK → the `settingsv1` legs, a `PUT` recorded.
- C7: the port writes the `PUT` body to `messages.log` → the marker leg.
- C8 (DW-2065): `KeyFile`'s `STARTUPADMIN` step skipped → the `startupadmin` legs; a failed read answering false → `startupadminfails`.
- C9: the baseline key dropped → `GovernanceBaseline`; the link removed (rebuilt) → `encryption-keys.page.spec.ts` and the browser spec.

## Auto Run Result

Status: blocked
Blocking condition: Task 0 complete; throwaway rebuild needed: `ocupilot-b-ci` has exited 1 (`RestartCount` 3, `on-failure:3` spent) and every start aborts in single-user mode, because `IRISAUDIT` is encrypted with K1 (`D06ECF7F-C0BD-11F1-ADE7-C6B998C71C8F`) while the persisted `DBEncStartMode` is 1 (Interactive) with `AuditEncrypt` 1, both persisted key ids K1, and no startup key file, administrator or passphrase; `<ManagerDirectory>ocuprobestart/` holds `start-a.key` (K1; C listed; `<K1>_1` and `<K1>_2` hidden), whose credentials were removed; `<ManagerDirectory>Temp/` holds `ocuprobestart-r1-s0.json` and `ocuprobestart-r1-auditfacts.json`; `messages.log` and `alerts.log` hold the #1217 line; no probe principal. Recorded branch: DW-2065 by-design (R1 and R2 both activated).

- Task 0 re-run, steps 1-13, on `ocupilot-b-ci` (13:07-13:22Z; evidence `/tmp/epic-18-d7/1823/t0r/`): the record is under Design Notes › Measured at implement, re-run, and the AD sentences and bracketed clauses are in the Spec Change Log's Task 0 re-run entry. It stopped at step 13's planned halt; no step-14 halt was met. Nothing was built past step 1, and no source file changed.
- Open for the runner: Decision 8. While the audit log is encrypted, the vendor accepts Interactive (step 11), and the next start with no console does not finish (R4). Interactive's sentence does not hold while `AuditEncrypt` is on.
- `baseline_revision` stays `2b3e5e24`, this story's first implement pass, so `f268a30e`'s step-1 plumbing stays in the reviewed diff.
- Verified: the record was checked against the evidence (R1 and R2 "Activating encryption key K1", R4's 8 "Failure activating required database encryption key" lines, #1217's text). The evidence carries the passwords only as environment placeholders, and the secret scan of the diff reads 0.
