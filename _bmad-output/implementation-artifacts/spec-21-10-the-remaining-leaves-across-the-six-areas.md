---
title: 'Story 21.10: The remaining leaves across the six areas'
type: 'feature'
created: '2026-11-15'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-21-context.md'
warnings: ['multiple-goals', 'oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Three Security leaves have no OcuPilot surface: the system-wide security parameters (SS-38, `Security.System`), the mobile phone providers (SS-37, `%SYS.PhoneProviders`) and the audit log export (SS-36, `%SYS.Audit.Export`). Two routed defects ride along: AD-10's KMIP arm does not judge journal encryption (DW-2431), and a mint whose target is longer than 2,200 characters answers 500 instead of a typed refusal (DW-2457).

**Approach:** Each leaf joins the Security slice beside its neighbor, with one descriptor and one port each. The security parameters become a settings table on Story 21.3's `ConfigPort`. The phone providers become a list and form on a new `PhoneProviderPort`, shaped like MFT connections above the port. The export becomes an action on the Auditing screen through `AuditPort`, started as the classic page starts it. DW-2431 widens the KMIP arm under the owner's answer U-30. DW-2457 adds one mint-time check. Planned as four batches (see Tasks).

## Boundaries & Constraints

**Always:**

- One descriptor and one port per screen (AD-5, AD-52). Each port gates before any vendor call (AD-29) and switches to `%SYS` by save and restore (AD-16).
- Every write is one operation reached by two callers (AD-53, AD-55): a confirmed proposal for the agent, a screen action or Save for a person. Each write is fresh-read, minted and fingerprinted (AD-6, AD-51, AD-54), audited (AD-15), read back (AD-58) and announced (AD-14).
- Every new destructive key ships `false` in the baseline (AD-22).
- Each descriptor declares the classic page it replaces (AD-44).
- Reads are bounded and shared by the screen and its tool (AD-36).
- The security parameters read only the roster's 19 names. `Security.System.Get` also answers `PrivateJWKS` and `SMTPPassword` (measured), so its array is never passed through (AD-35).

**Never:**

- No new AD and no AD amendment, except the AD-10 KMIP bullet the runner writes at the spec gate (owner answer U-30). No new `PROHIBITED.*` code.
- No caller-supplied path. The export names its file by root and relative name (AD-21's sixth case), and never overwrites.
- No harvested body (AD-23): the MCP suite's audit export takes a bare file name in a fixed directory, which OcuPilot's path contract replaces.
- No user-facing string beyond those the spec gate rules.
- Nothing runs on `ocupilot` or any slot instance.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Security parameters read | `GET` on the System-wide security screen, or `security.systemsecurity` | One row per roster name: 18 on Linux, 19 with `SSLTelnetServer` on Windows. Each row is `{Name, Value, Kind, Accepts, Restart, ReadOnly}`, and no other `Security.System` property appears. | 403 `AUTH.NOPRIVILEGE` for a caller missing a pair |
| Security parameter set | A settable row (for example `InactiveLimit` to 89, then restored), by either caller | The row reads the new value, `readBack` matches, and every other row is unchanged | none |
| Read-only, unknown, bad value | `RequiredRole`; a name not on the roster; `InactiveLimit` 366 | 409 / 404 / 400, at the mint and again at the port | nothing sent |
| Phone providers read | `GET` on the list, or `security.phoneproviders` | Rows equal `%SYS.PhoneProviders:List` (`Name`, `SMSGateway`). The id is exact-case and percent-encoded (AD-13). | 403 as above |
| Provider create, update, delete | A marker-named provider: created, its gateway changed, then deleted, by either caller | Each change reads back, and the deleted provider is gone from the list | an existing name is 409 at create (AD-54) |
| Provider in use | Delete of a provider that a test-made user names | 409 `PHONEPROVIDER.INUSE` before any vendor call, from both callers | nothing sent |
| Audit export | A root and relative name under an allowed root, plus an optional `ExportBefore` date, by either caller | The vendor's `AuditExport` background task starts. The answer is 202 started, naming the Background tasks row. That row later reads "N items exported." and the file exists. | an existing file, a bad root or name, or a missing directory is refused before the task starts (`PATH.*`, 400 on `Path`) |
| KMIP with journal encryption | Start mode set to KMIP while `DBEncJournal` is set (payload or stored) or the journal-key check answers an error; also `DBEncJournal` set under KMIP | Refused `PROHIBITED.STARTUPKMIP` with the journal sentence, from either caller, before any write | a failed read refuses |
| KMIP with a required database | As today: the audit log, IRISSECURITY or IRISTEMP encrypted | Refused with the existing sentence, which takes precedence when both cases hold | unchanged |
| Overlong target | A write whose target reference is longer than `Propose.TARGETREFMAX` (2,200 characters) | 400 `TOOL.ARGUMENTS`, before the fresh read, with no proposal stored | never 500 |

## Runner rulings at the plan halt (2026-11-15, unattended)

- **Split (decide; 6 of 6 children):** this story keeps SS-38 system-wide security parameters, SS-37 mobile phone providers and SS-36 audit log export, plus DW-2431 and DW-2457. Story 21.19 takes SS-39, PM-24, TM-17, TM-18, WA-15 (DW-2372, DW-2471); 21.20 OS-24, OS-27, LG-12 (DW-1562, DW-1856, DW-2479); 21.21 the owner-gated leaves (SH-26, SH-27, SH-28, PM-23, TM-19, WA-16, OS-25; DW-1850, DW-1280, DW-2348); 21.22 the flakes plus DW-2476 and DW-2202; 21.23 the test-hygiene entries. DW-2214, DW-2367, DW-2473, DW-2355 and DW-2356 are closed as proposed. OS-26, OS-28 and OS-29 are already delivered. The leaf inventory in Design Notes stands as the second criterion's evidence.
- **DW-2431 (owner answer U-30, quoted: "I agree with your recommendations"):** amend AD-10's KMIP bullet so the refusal also judges journal encryption (the runner writes it into the spine at this story's spec gate, citing owner answer U-30); add the refusal, reusing `PROHIBITED.STARTUPKMIP`, with exactly this owner-approved sentence: "Journal encryption is on, or a journal file the instance still needs is encrypted, and OcuPilot cannot check that the KMIP server is reachable and holds its key, so a start that cannot activate it does not finish. Keep Unattended, or make this change on the classic Database Encryption page."
- **SS-38:** if it needs a new AD-10 arm beyond DW-2431's, HALT as an intent gap naming it (no owner answer covers it).

</intent-contract>

## Code Map

- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` -- `EncryptionStartup` (~:3261): Interactive arm, then KMIP (`LeavesKmipRequired` → `LeavesModeRequired`, ~:3309-3328), then the journal arm, which runs only for Interactive (~:3278; `SetsJournalEncryption` ~:3333, `LeavesInteractiveJournal` ~:3344, `StartupJournalRefused` ~:3355). Codes and reasons are at ~:549-594. `ReasonFor` (~:1125) maps one sentence per code. `Prohibits` (~:1505) answers only `pCode`, through `Refuse` (~:5867). `COVEREDTYPES` is at ~:282, and the type guard and `ReviewedFewOnly` branches at ~:1516 and ~:1909.
- `src/OcuPilot/Kernel/Proposal/Mint.cls` -- the target is built at ~:158-162 by `Operation.TargetRefOf`. `GuardedMint`'s error becomes 500 `INTERNAL` at ~:367-371. `Refuse(pProblem)` answers 400 `TOOL.ARGUMENTS` (~:984).
- `src/OcuPilot/Kernel/State/Propose.cls` -- `TARGETREFMAX` 2200 (:84). `GuardedMint` (~:276) stays as the backstop.
- Sites that turn a prohibited code into a sentence: `Kernel/Proposal/Mint.cls` (~:243), `Api/Confirm.cls` (~:146), `Kernel/Proposal/ScreenSave.cls` (~:375), `Area/Security/EncryptionStartupSave.cls`, and `Kernel/Proposal/Impact.cls`, `Draft.cls`, `Findings.cls`. Find them all with `grep -rn "ReasonFor(" src/OcuPilot --exclude-dir=Test`.
- `src/OcuPilot/Port/ConfigPort.cls` -- endpoints `Startup,Memory,Compatibility,SQL,SQLShell,TSQL,ISQL` (:54). `COMPATIBILITYPAIRS` adds `%Admin_Secure:USE` (:48). The rosters for endpoints with no backing class are `SHELLROSTER`/`ISQLROSTER` (:93-95). `READONLY` and `EXCLUDED` are at :131-140. This is the sibling SS-38 extends.
- `src/OcuPilot/Screen/Tool/ConfigSettingSet.cls`, `CompatibilitySettingSet.cls`; `Screen/Descriptor/CompatibilitySettingList.cls`; `Area/OsMgmt/ConfigSettingRules.cls` -- the settings-table siblings: rows, the Set value row action, the value rules.
- `irissys/%CSP/UI/Portal/Parameters.cls` -- the classic page: 19 fields, each 1:1 with a `Security.System` property (:33-53). Page-only limits are `InactiveLimit` 0-365, `InvalidLoginLimit` 0-64 and `PasswordExpirationDays` 0-99999 (:98-100). The page saves with `Security.System.Modify("SYSTEM", .Properties)` (:169-199).
- `src/OcuPilot/Screen/Descriptor/MftConnectionList.cls`, `MftConnectionForm.cls`; `Screen/Tool/MftConnection{Create,Update,Delete}.cls`; `Area/Security/MftConnection{Rules,Save}.cls`; `Api/MftConnectionError.cls`; `Api/Router.cls` (:262-264) -- the above-port sibling for SS-37 (list and form, exact-case name id, `ScreenSave`).
- `src/OcuPilot/Port/BackupPort.cls`, `MirrorPort.cls` -- the dedicated-port sibling for `PhoneProviderPort`: `PAIRS`/`WRITEPAIRS`, the `GateClass` seam, `Invoke`/`Rows`.
- `irissys/%SYS/PhoneProviders.cls` -- `%Persistent`, with `Name` as IdKey (exact case). It has `Create`/`Modify`/`Delete`/`Get`/`Exists` and the `List()` query (:372). Every method checks `%Admin_Secure:USE`. `%OnDelete` refuses with #1447 when `Security.Users.PhoneProvider` names the provider (:360-366). The instance holds 7 providers.
- `src/OcuPilot/Screen/Read.cls` (~:300-333, :489, :714, :1394), `Screen/Registry.cls` (~:1223, the source count), `Kernel/EntityType.cls` (:136) -- the new `phone` read source and the `phone-provider` entity type.
- `src/OcuPilot/Port/AuditPort.cls` -- the `DATABASE` read (the `Enabled` read plus empty argument fields) and `STARTEDHTTP` 202 (:44, ~:96). It is the port SS-36 extends.
- `src/OcuPilot/Screen/Tool/AuditCopy.cls`, `AuditPurge.cls` (`PurgeBefore`, `SCREENVALUES`) -- action siblings on `Screen/Descriptor/AuditingConfig.cls` (row actions :60).
- `src/OcuPilot/Screen/Tool/TaskExport.cls`, `TaskExportMint.cls`, `Port/TaskTransferPort.cls` (~:194-249) -- file naming by root and relative path through `PathPort.Resolve`. A missing directory gives 400 on `path`.
- `irissys/%CSP/UI/Portal/Audit/ActionTemplate.cls` (:106-131), `irissys/%CSP/UI/System/BackgroundTask.cls` (`RunTask` :31, `AuditExport` :917) -- the classic export: `RunTask("AuditExport", ns, .parms)` with `FileName`, `AuditFlag` 0, `BeginDateTime` "", and `EndDateTime` for "older than".
- `src/OcuPilot/Port/BackgroundTaskPort.cls` -- lists the portal's background jobs (`EnumerateTasks`). A row's id is `portal` joined to the job number.
- `src/OcuPilot/Kernel/Governance/Baseline.cls` (:94-122, :272), `Screen/Titles.cls` -- add-only rows.
- Client: `ui/src/app/core/strings.ts`, `screen-actions.ts`, `screens.generated.ts`, `shell/screen-action-handler.ts`, `app.ts`, `areas/security/mft-connection-*.ts` (form sibling), `areas/security/encryption-startup.store.ts` (`STARTUP_MODE_REFUSALS`, which shows the server's `reason`).
- `ui/tools/self-protection.test.mjs` (`KERNEL_REFUSALS` :311, :340-350), `ui/tools/navigation.test.mjs` (Security order ~:335-349, :770), `ui/tools/strings.test.mjs` (literal cap 4200, :611).

## Tasks & Acceptance

**Task 0** runs on `ocupilot-ci` before any code, and its results are recorded under Design Notes. Each item is (inference) until measured:

- (a) The least pairs a caller needs for `Security.System.Modify`: `ConfigPort.WRITEPAIRS` plus `%Admin_Secure:USE`, or also a `%DB_IRISSECURITY` permission. Record the answer as the endpoint's write pairs. Also record whether `Modify` refuses a malformed `PasswordPattern` and accepts `AuditFlags` 1 while `AuditEnabled` is 0.
- (b) The least pairs for `%SYS.PhoneProviders` `Create`/`Modify`/`Delete`, and #1447's text for a provider named by a probe user.
- (c) Whether `RunTask("AuditExport", "%SYS", ...)` started from a confirm request appears in `BackgroundTaskPort`'s list and ends with "N items exported." Also record the job's `$USERNAME`, the pairs it needs (it writes `^IRIS.Temp` in `%SYS`), and how long it takes over the throwaway's audit log.

A pair beyond `%Admin_Secure:USE`, `%Admin_FileSystemAccess:USE` and the `%DB_*` permissions is a HALT `intent gap`.

### Batch 1: the kernel (DW-2431, DW-2457; commit when its loop is green)

- `src/OcuPilot/Kernel/Proposal/Prohibited.cls`:
  - Generalize `LeavesInteractiveJournal` into a private `LeavesModeJournal(pMode, ...)`, keeping both named wrappers, as `LeavesModeRequired` serves both modes.
  - Run the journal judgement for KMIP too, after the databases arm, so a write that hits both gets the existing sentence. Refuse with `STARTUPKMIP`.
  - Add `STARTUPKMIPJOURNALREASON`, holding the owner-approved sentence verbatim.
  - Give `Prohibits` (and `Refuse`) an optional last output, `pReason`. An arm sets it to a variant sentence, and it defaults to `ReasonFor(pCode)`.
  - Update the doc comments of `EncryptionStartup` and the KMIP parameter.
- Every site that renders a `Prohibits` code (Code Map list) uses the answered `pReason` when it is set. The client needs no change: it shows the server's `reason`.
- `src/OcuPilot/Kernel/Proposal/Mint.cls` -- right after `TargetRefOf` succeeds, a target longer than the store's `TARGETREFMAX` answers `..Refuse(problem)` and nothing further runs. The problem text is under Design Notes.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` (line ~364 row, and the Story 18.23 note) and `ui/src/app/core/strings.ts` -- add the owner-approved sentence.
- Tests:
  - `Test/EncryptionStartupDescriptor.cls`: unit legs for `LeavesKmipJournal` in both orders. The reason variant is the parameter, names no caller, and names the classic page.
  - An armed both-callers leg (`OCUPILOT_ALLOW_ENCRYPTION_CONFIG`) for KMIP with journal encryption on. It goes in a new `Test/EncryptionStartupKmipWrite.cls`, because `EncryptionStartupWrite.cls` is already 605 lines. Add the class to `scripts/ci-throwaway.sh`'s roster (add-only).
  - `Test/ProposalTargetKey.cls`: a mint-level leg through a seam tool whose target is longer than the limit. It answers 400 `TOOL.ARGUMENTS`, the seam's fresh read is never called, and no row is stored.
  - `ui/tools/self-protection.test.mjs`: a `KERNEL_REFUSALS` row for the variant sentence.

### Batch 2: System-wide security parameters (SS-38)

- `src/OcuPilot/Port/ConfigPort.cls`:
  - Endpoint `Security` (`SECURITYCLASS = "Security.System"`), with `SECURITYPAIRS = "%Admin_Secure:USE"` added as `COMPATIBILITYPAIRS` is, and Task 0 (a)'s write pairs.
  - A `SECURITYROSTER` in `SHELLROSTER`'s grammar, carrying the 19 names, each with its kind, choices or limits, and settable flag:
    - booleans: `AuditFlags`, `SQLSecurity`, `InvalidLoginAction`, `PercentGlobalWrite`, `WebAppPctAccess`, `ConfigurationSecurityEnabled`, `SecurityDomains`, `AuditEnabled`;
    - the page's integer limits, and `EscalateLoginTimeout`/`EscalateAuthTimeout` from 0;
    - `PasswordPattern` text of at most 64 characters;
    - `DefaultSignatureHash`, a choice of SHA1, SHA256, SHA384 or SHA512.
  - Read-only names: `AuditEnabled`, `ConfigurationSecurityEnabled`, `DefaultSecurityDomain`, `SecurityDomains`, `RequiredRole`, `PasswordValidationRoutine`, `SSLTelnetServer`. `SSLTelnetServer` is listed only on Windows, as the classic page does (`$System.Version.GetOS()`).
  - `LIST`/`GET` read `Security.System.Get` and emit roster names only.
  - `SET` merges the fresh read and sends the settable roster names through `Modify` (AD-4). Read-only names are never sent.
- `src/OcuPilot/Screen/Descriptor/SystemSecuritySettingList.cls` -- new, on `CompatibilitySettingList`'s shape:
  - area `security`, route `security/system-security`, `sideBarPosition` 14;
  - pairs `%Admin_Manage:USE`, `%DB_IRISSYS:READ` and `%Admin_Secure:USE`;
  - `classicPage` `%CSP.UI.Portal.Parameters`, row action `set`, `toolIdentifier` `security.systemsecurity`.
- `src/OcuPilot/Screen/Tool/SystemSecuritySettingSet.cls` -- new, extending `ConfigSettingSet`:
  - `TOOLNAME` `security.systemsecurity.set`, `ENDPOINTNAME` `Security`;
  - `DESTRUCTIVE` 1, with the consequence string.
- Add-only rows:
  - `Kernel/Governance/Baseline.cls`: `security.systemsecurity.set` `false`.
  - `Screen/Titles.cls`.
- Client: `core/strings.ts`, `screen-actions.ts`, `shell/screen-action-handler.ts` (`SCREEN_ACTION_DESCRIPTORS`, `DESTRUCTIVE_ACTIONS`/`DESTRUCTIVE_CONSEQUENCES`), and `screens.generated.ts` (regenerated).
- Tests:
  - `Test/SystemSecuritySettingRead.cls`: the rows equal `Get` for the roster, and no `PrivateJWKS`, `SMTPPassword` or other name appears. Also the gate and the descriptor's page and pairs.
  - `Test/SystemSecuritySettingWrite.cls`, armed as `AuthOptions`' write tests are: both callers set `InactiveLimit` and restore it in `OnAfterOneTest`. A read-only name is 409 and 366 is 400, at the mint and at the port. With the key `false`, the agent is refused.
  - `ui/browser/system-security.browser-spec.mjs`, listed in `ui/tools/side-bar-pins.test.mjs`.

### Batch 3: Mobile phone providers (SS-37)

- `src/OcuPilot/Port/PhoneProviderPort.cls` -- new, on `BackupPort`'s shape:
  - pairs `%Admin_Secure:USE`, `%DB_IRISSYS:READ`, plus Task 0 (b)'s write pairs;
  - endpoint `PhoneProviders`, with types `LIST` (the vendor's `List` query, capped as AD-36 requires), `GET`, `CREATE`, `SET` (`SMSGateway` only) and `DELETE`;
  - `DELETE` first counts users naming the provider, using the vendor's own predicate with the name bound, and refuses 409 `PHONEPROVIDER.INUSE` before any vendor call;
  - absent is 404, and an existing name at create is 409.
- `src/OcuPilot/Api/PhoneProviderError.cls` -- new, on `MftConnectionError`'s shape, with prefix routing in `Api/Error.cls` (add-only).
- `src/OcuPilot/Screen/Descriptor/PhoneProviderList.cls` -- new:
  - area `security`, `sideBarPosition` 15, route `security/phone-providers`, archetype `list`, entity type `phone-provider`;
  - primary action create, row action delete;
  - `classicPage` `%CSP.UI.Portal.PhoneProviders`, `toolIdentifier` `security.phoneproviders`.
- `src/OcuPilot/Screen/Descriptor/PhoneProviderForm.cls` -- new: `form-page`, `classicPage` `%CSP.UI.Portal.PhoneProvider`.
- Tools, new, on MFT's shape, each with `PORTCLASS` `OcuPilot.Port.PhoneProviderPort`:
  - `Screen/Tool/PhoneProviderCreate.cls` (`security.phoneproviders.create`, `CREATES` 1);
  - `PhoneProviderUpdate.cls` (`.update`, `SMSGateway`);
  - `PhoneProviderDelete.cls` (`.delete`, `DESTRUCTIVE` 1, `SCREENACTIONS` "delete").
- `src/OcuPilot/Area/Security/PhoneProviderRules.cls` and `PhoneProviderSave.cls` -- new, extending `ScreenSaveRules`/`ScreenSave`. Both fields are required, 1 to 50 characters. There is no gateway format check, as on the classic page.
- `src/OcuPilot/Api/Router.cls` -- add-only: `GET /phone-provider/form`, `PUT /phone-provider/:id`, `POST /phone-provider`.
- Add-only rows:
  - `Kernel/EntityType.cls`: `phone-provider`.
  - `Kernel/Proposal/Prohibited.cls`: `COVEREDTYPES`, the type guard, change and create field lists `Name,SMSGateway`, and a `ReviewedFewOnly` branch with no predicate.
  - `Screen/Read.cls` and `Screen/Registry.cls`: the `phone` source and banner port.
  - `ui/tools/screen-mirror.mjs`: the `SOURCE_*` constant.
  - `Kernel/Governance/Baseline.cls`: create and update `true`, delete `false`.
  - `Screen/Titles.cls`.
- Client:
  - `areas/security/phone-provider-form.page.ts`, `.store.ts` and `phone-provider-actions.ts`, each with a spec, extending MFT's;
  - `app.ts` routes;
  - `core/strings.ts`, `screen-actions.ts`, `shell/screen-action-handler.ts`, `screens.generated.ts`.
- Tests:
  - `Test/PhoneProviderRead.cls`: the list equals `List`, plus the gate and the descriptor.
  - `Test/PhoneProviderWrite.cls`: both callers create, update and delete a marker provider. The in-use refusal uses a probe user the test makes and removes. An existing name is 409. With the delete key `false`, the agent is refused. Every provider the test makes is removed in `OnAfterOneTest`.
  - `ui/browser/phone-providers.browser-spec.mjs` (create, edit, typed-name delete of its own provider), listed in `side-bar-pins.test.mjs`.

### Batch 4: Audit log export (SS-36)

- `src/OcuPilot/Port/AuditPort.cls`:
  - A composed `EXPORTTYPE` `EXPORT`, answered here, not by the admin API. Its gate adds `%Admin_FileSystemAccess:USE`.
  - It resolves `ExportRoot`/`ExportPath` through `PathPort.Resolve` as a non-overwriting file. A missing directory is 400 `AUDIT.EXPORT.DIRECTORY` on `Path`, worded as the task export's.
  - It then calls `%CSP.UI.System.BackgroundTask.RunTask("AuditExport", "%SYS", .parms, , .job)` with `FileName`, `AuditFlag` 0, `BeginDateTime` "", and `EndDateTime` `ExportBefore` 00:00:00, or "" for every record. No transaction is open at that point.
  - It answers `STARTEDHTTP` with the Background tasks row id. A failed start is a fault.
  - The `DATABASE` read gains `ExportRoot`, `ExportPath` and `ExportBefore`, empty.
- `src/OcuPilot/Screen/Tool/AuditExport.cls` -- new, on `AuditPurge`'s shape:
  - `security.auditing.export`, `READTYPE` `DATABASE`, `WRITETYPE` `EXPORT`, `SENDSBODY` 0;
  - `SCREENACTIONS` "export", `SCREENVALUES` for the three fields, `DESTRUCTIVE` 0;
  - `CLASSICPAGES` `%CSP.UI.Portal.Audit.ExportLog`, plus `%Admin_FileSystemAccess:USE`.
  - The read-back is the started row (as `AuditCopy`'s 202).
- `src/OcuPilot/Screen/Tool/AuditExportMint.cls` -- new, on `TaskExportMint`: it resolves the file before the fresh read.
- `src/OcuPilot/Screen/Descriptor/AuditingConfig.cls` -- add-only: row action `{"id": "export", "selfProtection": ""}`.
- Add-only rows: `Kernel/Governance/Baseline.cls` `security.auditing.export` `true`.
- Client: the export dialog reuses the task export's root and path picker and purge's date field. Also `strings.ts`, `screen-actions.ts`, `screen-action-handler.ts`, and the started toast linking to Background tasks.
- Tests:
  - `Test/AuditExportWrite.cls`, live-safe on a throwaway: both callers export into a directory the test makes under the allowed root. The started row reaches "items exported." within the class's own wait, and the file exists. An existing file, a `..` name and a missing directory are refused before any task starts. The test removes its files.
  - `ui/browser/auditing-write.browser-spec.mjs`: an export leg.

**Acceptance Criteria:**

- AC1 (SS-38). Given `ocupilot-ci`, when System-wide security or `security.systemsecurity` reads, then both answer the same roster rows, equal to `Security.System.Get` for those names, and no other property. When a person's Set value or the agent's confirmed set changes `InactiveLimit`, then the row reads the new value, `readBack` matches, and the agent's write records one AD-15 marker.
- AC2 (SS-37; Integration: `PhoneProviderList` consumes `PhoneProviderPort`). Given the list, when either caller creates, edits and deletes a marker provider, then each change shows on the next read. A provider named by a user is refused `PHONEPROVIDER.INUSE` before any vendor call.
- AC3 (SS-36). Given an allowed root, when either caller exports, then the vendor's background task starts, Background tasks shows its row ending "items exported.", and the file holds the export. No caller value reaches the vendor as a path.
- AC4 (DW-2431). Given journal encryption on, when either caller chooses KMIP at startup (or turns journal encryption on under KMIP), then the write is refused `PROHIBITED.STARTUPKMIP` with the owner-approved sentence before any write.
- AC5 (DW-2457). Given a write whose target exceeds 2,200 characters, when the agent mints it, then it answers 400 `TOOL.ARGUMENTS` before the fresh read, never 500.
- AC6. Given the default baseline, when the agent proposes each new write, then create, update and export mint, and the security set and the provider delete are refused by governance until enabled.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs:**

- AD-4 (merge), AD-5 (descriptor), AD-8 and AD-29 (pairs, gate), AD-10 (the KMIP arm, U-30), AD-13 (ids), AD-14 and AD-15 (event, marker), AD-16 (namespace), AD-21 (sixth case), AD-22 (baseline);
- AD-23 (no harvest), AD-26 (a started write is a success), AD-35 (no secret read), AD-36 (bounded reads), AD-44 (classic pages);
- AD-51, AD-52, AD-53, AD-54, AD-55, AD-58.

**Leaf inventory pointer.** The 21-leaf inventory that split this story is in this spec at commit `1bb9b9fb9b7d0b15c8c5e28191754441c8bd5979`, Design Notes (a). The leaves that moved are planned in 21.19 to 21.23. This story's three backing classes were identified on `ocupilot` (read-only, 2026-11-15), which satisfies the second criterion for them:

- `Security.System` `Get`/`Modify`, which has 79 properties of which the page shows 19;
- `%SYS.PhoneProviders`, with 7 providers on the instance;
- `%SYS.Audit.Export`, reached through `%CSP.UI.System.BackgroundTask.AuditExport`. In `%SYS` it accepts only a date range (`Audit.cls` :1047-1051), and `/api/admin` has no export.

**AD-10 amendment for the spec gate** (owner answer U-30). This text replaces the bullet "A start that cannot finish: KMIP":

> - **A start that cannot finish: KMIP** [AMENDED 2026-10-14, Story 18.48 Task 0, decision rule, Rule 20] (DW-2100) [AMENDED 2026-11-15, Story 21.10 spec gate, owner answer U-30, DW-2431, Rule 20]: a `Security.Encryption.Settings` change to KMIP activation at startup is refused `PROHIBITED.STARTUPKMIP` before any write, from either caller, in two cases. The first is while the audit log, IRISSECURITY or IRISTEMP is encrypted, now or at the next start (read as the Interactive arm reads it). The second is while journal encryption is on (`DBEncJournal` set in the payload or the stored settings), or while `%SYS.Journal.System.OKNoDBEncKeyAtStartup()` answers an error, read as the journal arm reads it, where a failed read refuses. Both orders are covered: KMIP with either set, and setting either under KMIP. Each case carries its own sentence naming the classic page, the databases case first when both hold (owner answer U-30). OcuPilot cannot judge a KMIP server's reach or key list (measured on `ocupilot-ci`, 2026-10-14: KMIP over a server configured for startup at an unreachable host was accepted, and every start aborted into single-user mode). The journal case is judged as the Interactive journal arm is (inference: not measured under KMIP; owner answer U-30). Unattended over a key file is not refused: the vendor refuses a switch to another file while one is configured (#1233), and refuses leaving startup activation while encrypted databases are required (#1217). A first Unattended over a file lacking the default key finished, with the start encrypting IRISTEMP with the file's key (measured).

**SS-38 needs no new AD-10 arm.** A value can cut OcuPilot off only through fields this plan lists read-only (escalated below). `RequiredRole` is the clear case: `CSPSystem` and `UnknownUser` hold no roles on this instance, so a required role would likely refuse every web request and the shell (inference, not measured). If the gate wants any read-only field settable, that needs a new AD-10 arm, which is an owner question, and this story halts there.

**Decided in-stage:**

- SS-38 extends `ConfigPort` (Rule 31: same settings-table shape, rules and Set value). It uses a roster rather than the class's `Get` array, because that array carries secrets.
- SS-37 gets its own port, a copy of `BackupPort`'s shape: no admin route exists, and `%SYS.PhoneProviders` shares nothing with `Config.*`. Above the port it extends MFT's classes.
- SS-36 starts the vendor's own background task, as the classic page does, so it is not bound by the gateway timeout and shows on the Background tasks screen. It is a non-overwriting sixth-case file, which needs no AD-21 record. Only overwriting consumers are recorded there.
- One code, two sentences, through `Prohibits`' optional `pReason`. This follows `WalletRungError.ReasonFor(code, pair)`, the existing per-case sentence.
- DW-2457 is checked once, in `Mint`, after `TargetRefOf`. `ExplorerMint`'s presence read still comes first, and it reads no fresh state for the diff. The problem text is agent-facing and never on screen, because screen actions do not mint: "the target these arguments name is longer than the 2,200 characters a proposal can hold; propose it in smaller parts, for example fewer documents per proposal".
- `AuditFlags` is not coupled to `AuditEnabled`. Task 0 (a) confirms the vendor stores it. The classic page's coupling is page logic.
- Security positions are 14 (System-wide security) and 15 (Mobile phone providers).
- The export's date field is `ExportBefore`, on purge's `PurgeBefore` shape.

**Escalated for the spec gate (veto window, unattended):**

- E1 (security posture, stricter than the classic page). Seven fields are shown and never changed: `RequiredRole` (likely lockout), `PasswordValidationRoutine` (a routine the instance runs: evaluated code, as Story 21.4 ruled), `ConfigurationSecurityEnabled` (a start may stop for a login, inference), `SecurityDomains` and `DefaultSecurityDomain` (they change `$USERNAME`, which OcuPilot's own state keys on, inference), `AuditEnabled` (owned by Auditing), and `SSLTelnetServer` (Windows only, untestable here).
- E2 (security posture). The security parameters set is destructive (the strongest confirmation, as AD-10 treats privilege grants), and its key ships `false`.
- E3 (secret handling). The export file holds what the vendor writes, `EventData` unmasked. AD-35 masks only OcuPilot's own surfaces, and the file is a server file, as the classic page's is. The export never overwrites (stricter than the classic page), and its key ships `true`, as copy's does.
- E4 (stricter). The provider delete is checked for users before the vendor call, and its key ships `false`.

**Strings, escalated for the spec gate's ruling** (proposed wording; nothing is used until ruled):

- System-wide security:
  - title and side-bar entry "System-wide security";
  - set consequence: "This changes how every user on this instance signs in, is locked out, or is checked.";
  - prompts: "Which system-wide security parameters differ from the defaults?" and "How many failed logins disable an account?".
- Mobile phone providers:
  - title and side-bar entry "Mobile phone providers";
  - column "SMS gateway", form labels "Provider name" and "SMS gateway", action "Create provider";
  - empty state "No mobile phone providers on this instance.";
  - `REASONINUSE`: "One or more users name this provider for two-factor text messages, so it cannot be deleted. Change those users' provider first.";
  - delete consequence "Deleting this provider removes it from this instance. This cannot be undone.";
  - prompt: "Which mobile phone providers can users choose for two-factor text messages?".
- Audit export:
  - action "Export";
  - field "Records before" with the hint "Leave empty to export every record.";
  - card consequence "Writes the audit records to a new file on the server.";
  - started: "The export has started. Background tasks shows when it finishes and how many records it wrote.";
  - `AUDIT.EXPORT.DIRECTORY` reuses the task export's sentence.
- DW-2431: the owner-approved sentence (already ruled).

**Integration ACs and linkage (Rules 1 and 2):**

- `PhoneProviderPort` is consumed in this story by `PhoneProviderList`'s read and by the three tools (AC2).
- **Consumed-by:** none planned. The user editor's free-text `PhoneProvider` field could read the list later (inference).
- **Consumes:** `Screen.Gate`, `Screen.Read`, `Kernel.Proposal.Operation`/`ScreenSave`, `PathPort`, `BackgroundTaskPort`'s row id.

**Ledger inbox:** DW-2431 is addressed in Batch 1 (AC4), and DW-2457 in Batch 1 (AC5).

**Contended paths:** `origin/OCU-1-epic24` has add-only changes to `Prohibited.cls`, `Baseline.cls`, `strings.ts`, `Read.cls`, `screen-actions.ts`, `screen-action-handler.ts`, `screens.generated.ts` and `scripts/ci-throwaway.sh` (checked 2026-11-15). This story's edits there are add-only, except `Prohibited.cls`'s encryption region, which Epic 24 does not touch. Epic 22 has no branch.

**Runner ruling at the spec gate (2026-11-15):** the AD-10 KMIP bullet is amended in the spine with the text above (owner answer U-30). E1 to E4 and the escalated strings are kept (veto U-68).

## Verification

**Shared surfaces** (each in the `(loop)` set; the implement stage greps `ui/browser`, `ui/tools`, the `ui/src` specs and `src/OcuPilot/Test` for the old shape):

- Security rosters and pair-order counts: `Navigation` (Security listed 13 to 15), `WireSecurityRead`, `WireAreaAnyScreen`, `ui/tools/navigation.test.mjs`, `side-bar-pins.test.mjs`.
- `LanguageServerWire` and `ui/browser/language-servers.browser-spec.mjs`, unchanged and re-run.
- `Descriptor` (and `EntityType`'s count), `TeardownGuard`, and the read-source count (`Registry`, `screen-mirror.test.mjs` `READ_SOURCE_PORTS`).
- `ReadTool`, `ReadDescriptions` and `ToolWrite`'s counts, plus `Prohibited` (covered types; the encryption arms), `ClassicPageGate`, `MappingDescriptor`, `SurfaceCoverage`, `StageTwoTools`, `ToolRoundTrip`, `PortGate`, `EndpointCoverage` and `GovernanceBaseline`.
- The `AuditingConfig` row actions and the `DATABASE` read's fields (`AuditingUpdate`, `AuditCopy`/`AuditPurge` tests, `auditing-screen` and `auditing-write` specs).
- `self-protection.test.mjs`, `ci.test.mjs` (arming roster), and the EXPERIENCE.md literal cap in `strings.test.mjs`. If the ruled strings cross 4200, the cap rises to 4600 under its protocol.

*Every test added or changed passes on a fresh environment, in either order.*

**Mutations (Rule 19)**, one per AC, each applied, observed red, reverted (tree identical by `git status --short` and `git diff --stat`), and the reverted source reloaded:

- AC1: `RequiredRole` made settable in the roster → `SystemSecuritySettingWrite` red. The roster read replaced by the `Get` array → `SystemSecuritySettingRead` red.
- AC2: the in-use count skipped → `PhoneProviderWrite` red.
- AC3: overwrite passed as 1 → `AuditExportWrite`'s existing-file leg red.
- AC4: the journal judgement left Interactive-only → `EncryptionStartupDescriptor` and `EncryptionStartupKmipWrite` red.
- AC5: the `Mint` length check removed → `ProposalTargetKey` red (500).
- AC6: a key's baseline fallback flipped → `GovernanceBaseline` red.

**Commands.** One per foreground call, `timeout: 600000`, against `ocupilot-ci` only, never two test calls in one message:

- `(loop)` `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/4667058b-f052-49c9-b08a-221f7f41dfab/scratchpad/e21u/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` -- expected: `LOADERRORS=0`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<Class>` -- expected: green. Run once for each of `EncryptionStartupDescriptor`, `EncryptionStartupKmipWrite`, `ProposalTargetKey`, `SystemSecuritySettingRead`, `SystemSecuritySettingWrite`, `PhoneProviderRead`, `PhoneProviderWrite`, `AuditExportWrite`, `AuditingUpdate`, and every shared-surface class above.
- `(loop)` `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/` -- expected: within the 2500/4000 kB budgets.
- `(loop)` `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/<file>.browser-spec.mjs` -- expected: green. One call per file: `system-security`, `phone-providers`, `auditing-write`, `auditing-screen`, `language-servers`.
- `(loop)` `cd ui && npm run test:tools` and `cd ui && npm run test:components` -- expected: green.
- `(loop)` `uv run scripts/check-objectscript.py`, `uv run scripts/test_check_objectscript.py`, `bash scripts/lint-docs.sh` -- expected: clean.
- `(once)` the full ObjectScript sweep over `src/OcuPilot/Test`, before `dev_complete`, one class per call or batches sized from `ui/tools/ci-timings.json` to about 8 minutes -- expected: green. The full browser suite is left to CI (Rule 29).

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
