---
title: 'Story 21.3: Startup, memory and compatibility settings'
type: 'feature'
created: '2026-11-15'
status: 'done'
baseline_revision: 'af15d1c923c6a5aa10d84d2e31cf020851396de7'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred:
  - summary: >-
      The reused interop setting dialog tells the person to leave the field empty to clear the value for every non-boolean setting, which is wrong for integer and choice settings.
    evidence: |-
      config-settings.page.ts opens InteropItemSettingDialog unedited; an empty value for an integer or choice setting is refused 400 CONFIG.SETTING.VALUE. A fix needs a dialog input or a new string, and the dialog is an Epic 24 file.
    location: >-
      ui/src/app/areas/interoperability/interop-item-setting-dialog.ts
    severity: low
---

<intent-contract>

## Intent

**Problem:** The instance's startup, memory and compatibility configuration (`Config.Startup`, `Config.config`, `Config.Miscellaneous`) has no screen and no route in OcuPilot. An operator who wants to read or change one of these settings, or to know whether a change waits for a restart, has to use the classic Memory and Startup page and its Startup, Advanced Memory and Compatibility tables.

**Approach:** Add one gated port, `ConfigPort`, and three OS management screens: Startup settings, Memory settings and Compatibility settings. Each is a table of one class's settings with its value and whether a change takes effect only at the next restart. Each has one row action, Set value: a write with two callers (AD-53), a person's dialog and a confirmed agent proposal. The Memory and Startup page's settings are rows of these tables, so no separate form is built. The restart statement comes from the vendor's own source for each setting (Design Notes).

## Boundaries & Constraints

**Always:**

- `ConfigPort` checks its declared pairs with `$System.Security.Check` before any vendor call (AD-29). It switches `$NAMESPACE` by save and restore (AD-16). It is the only product class that names `Config.Startup`, `Config.config`, `Config.Miscellaneous`, `Config.CPF` or `SYS.Database.CheckBlockSizeAvailable` for these screens.
- A read lists the class's `Get` array, minus `Comment`/`Comments` and the classic table's exclusions (Design Notes). Each row is `Name`, `Value`, `Kind` (`boolean`, `integer`, `choice`, `text` or `blocksizes`), `Accepts`, `Restart` and `ReadOnly`. `Kind`, the range and the choices come from the compiled property's `RuntimeType`, `MINVAL`, `MAXVAL` and `VALUELIST`, read at call time, plus the named exceptions in Design Notes.
- A set sends a one-key `Modify` array: the named setting and its new value. The vendor keeps every key the array omits (measured, Design Notes). The value is validated by `ConfigSettingRules` before any vendor call, at the mint and again at the write, for both callers.
- A set of a row whose `Restart` is true carries the consequence `CONFIG.SETTING.RESTART`. Its sentence is the existing `encryptionStartupRestart` ("Takes effect at the next restart."). It appears on the proposal card, in the dialog before the Save, and after the Save.
- Each write is a merge write (AD-4 named exception, Design Notes). It declares `ConfigPort` (AD-52), and it is minted, fingerprinted, confirmed once and audited (AD-6, AD-34, AD-15). It reads its row back (`READBACKFIELDS` `Value`, AD-58) and emits one change event (AD-14).
- `Kernel/Governance/Baseline.cls` gets three keys, each `true`: `osmgmt.compatibilitysettings.set`, `osmgmt.memorysettings.set` and `osmgmt.startupsettings.set` (AD-22; no setting change is destructive in `Write.cls`'s sense, and this follows the `ecpsettings.update`/`journalsettings.update` precedent).
- Every read is bounded and reports truncation (AD-36).

**Never:**

- No harvested body (Design Notes), no new route in `Api/Router.cls` (reads and sets go through the generic screen read and screen action routes), and no new call to `Config.Startup`, `Config.config` or `Config.Miscellaneous` outside `ConfigPort` in product code.
- No set of a `ReadOnly` row: a path (AD-21) or a setting that would cut OcuPilot off after the next restart (Design Notes).
- No restart, no `Config.CPF.Activate`, no Windows service auto-start (`Config.WinStartup`), no `^%SYS` write of its own, and no CPF file other than the active one.
- No new `PROHIBITED.*` predicate. `Prohibited.cls` gains only the three entity types as covered types.
- No edit to any interoperability file: the client imports `interop-item-setting-dialog.ts` as it is.
- No user-facing string beyond those ruled in Design Notes.

## I/O & Edge-Case Matrix

All rows are observed through the OcuPilot API on `ocupilot-ci`: the screen read route, the screen action route, and a proposal's confirm.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Startup read | `GET` Startup settings | One row per `Config.Startup.Get` key less the exclusions. `ShutdownTimeout` reads `integer`, 120 to 100000, `Restart` false. `ErrorPurge` and `WebServer` read `Restart` true. `DefaultPort`, `DefaultPortBindAddress`, `WebServer`, `WebServerPort`, `TempDirectory` and `WebServerURLPrefix` read `ReadOnly` true. | none |
| Memory read | `GET` Memory settings | One row per `Config.config.Get` key less the exclusions, `globals4kb`..`globals64kb`, `routines` and `bbsiz` included. `Restart` is `'NoRestartOnActivate(Name)`: `errlog` true, `history` false. The path rows read `ReadOnly` true. | none |
| Compatibility read | `GET` Compatibility settings | One row per `Config.Miscellaneous.Get` key less `ZaMode`. `NullSubscripts` reads `Restart` true. `Undefined` reads `choice` 0, 1, 2. | none |
| Set, no restart | `ShutdownTimeout` 301, `history` 501 or `LineRecall` flipped, by both callers, then restored | The row reads the new value. `readBack` matches. No consequence. Every other key of the class is unchanged. | none |
| Set, restart | `errlog` 501, then restored (armed test only) | Card, dialog and Save answer `CONFIG.SETTING.RESTART`. `Config.CPF.PendingRestart` names `config`/`errlog`. | none |
| Unknown setting | `Name` not in the read | 404 `CONFIG.SETTING.NOTFOUND` at mint and at the port | nothing sent |
| Read-only setting | `DefaultPort`, `TempDirectory` | 409 `CONFIG.SETTING.READONLY` at mint and at the port | nothing sent |
| Bad value | `ShutdownTimeout` 119, 100001, `1.5` or `x`; `LineRecall` 2; `Undefined` 3; `bbsiz` 100; `DBSizesAllowed` without `8192` or with `1024` | 400 `CONFIG.SETTING.VALUE` at mint and at the port | nothing sent |
| Vendor refusal | a value the rules pass and `Modify` refuses | The vendor's status, normalized (AD-39) | nothing stored |
| Governance | key set `false` | An agent proposal is refused by the governance gate. A person's Set value is not governed (AD-22). | structured denial |
| Gate | caller lacks a declared pair; Compatibility without `%Admin_Secure:USE` | 403 `AUTH.NOPRIVILEGE`. No vendor call. | not logged |

</intent-contract>

## Code Map

- `irissys/%CSP/UI/Portal/Config/AdvancedTable.cls:60-110` -- the classic table: `Get(.Properties)`, the exclusions (`:68-73`), `EnsembleAutoStart` only on an interoperability instance (`:76`), the Edit link to `ValueEditor`. `:113-128` maps `Miscellaneous`/`Startup`/memory to the three classes. `RESOURCE` `%Admin_Manage` (`:19`).
- `irissys/%CSP/UI/Portal/Config/ValueEditor.cls` -- the classic row edit. `RESTARTREQUIREDLIST` `NullSubscripts` (`:22-24`). The input from `runtimetype`, `VALUELIST`, `DISPLAYLIST`, `MINVAL`, `MAXVAL` (`:186-215`). `DBSizesAllowed` as block-size checkboxes with 8192 required and `SYS.Database.CheckBlockSizeAvailable` (`:226-256`). The restart note from `Config.config.NoRestartOnActivate` (`:331-357`). `SaveData` is a one-key `Modify` (`:364-396`). `Validate`'s `ListFormat` 0/1 rule (`:409-414`).
- `irissys/%CSP/UI/Portal/MemoryStartup.cls:362-435` -- `SaveData`: `DefaultPort` change and memory changes carry the restart message (`:380-383`, `:417-426`); hints for `routines` 36-65536 and `bbsiz` 256-2147483647 or -1 (`:117-119`).
- `irissys/%CSP/UI/Portal/Application.cls:141,257,258,261` -- menu rows; Compatibility is menu-gated on `%Admin_Secure` (`:257`, `tSecure`).
- `irissys/Config/config.cls:607` (`NoRestartOnActivate`), `irissys/Config/CPF.cls:54-76` (`PendingRestart(.Reasons)`, with `Reasons(n,"Section"|"Property"|"Old"|"New")`), `irissys/Config/CommonSingleMethods.cls:70,113` (`Get`, `Modify`). Bodies are not in the export; behavior is the Task 0 measurements below.
- Port model: `src/OcuPilot/Port/BackupPort.cls` (`PAIRS` :30, `WRITEPAIRS` :34, `GATECLASS` :37, `ENDPOINTS` :53, `TYPELIST`/`TYPEGET` :61-63, `GateClass` :117, `LogFault` :124, `Invoke` :190, `Rows` :238, `Admit` :258, `Deny`/`Refuse`/`Refused`/`Fail` :676-708, `SnippetForm` :710, `Snippet` :721).
- Read source kind, as Story 21.2 added `backup`: `Screen/Read.cls:297-307` (`SOURCE<X>` and the port-class seam), `:454` (allowed list), `:645-655` (dispatch); `Screen/Registry.cls:1223-1224` (allowed ports and message), `:1334-1353` (per-kind shape). The kind is `LIST` only, as `backup` is.
- Set-value model: `Screen/Tool/InteropSettingSet.cls` (`WRITETYPE` `SET`, `SENDSBODY` 1 :18-21, `SCREENACTIONS` :25, `SCREENVALUES` :28, `SCREENEMPTY` :30, `READBACKFIELDS` :33, `ScreenActionDelta` :77, `ArgumentProblem` :89 through `Api/Error.ReasonForViolation`) and its base `InteropSettingAction.cls` (`Consequence` :74, `ArgumentProblem`/`ConfirmProblem` :109-120). `Write.cls`: `SCREENACTIONS` :167, `SCREENVALUES` :238, `SCREENEMPTY` :1074, `ScreenActionValueNames` :749, `ScreenActionDelta` :795. Route `POST /screens/:screen/action` (`Api/ScreenAction.cls` `Handle` :77, `Values` :559).
- Consequence model: `Screen/Tool/EcpSettingsUpdate.cls` `Consequence` :203 (re-reads through the port, answers the code); `Area/OsMgmt/EcpSettingsSave.cls` `Answer` :196-207 (`{readBack, consequence}`); `Api/EcpError.cls:144-146,170,223`. Client: `core/proposal-view.ts:332,465,523`.
- Error model: `Api/BackupError.cls` (pairs :14-61, `ReasonFor` :64, `HttpStatusFor` :81, `SlugFor` :90); `Api/Error.cls:1244` and `:1462` (the `BACKUP.` prefix dispatch, copy for `CONFIG.`).
- Entity types: `Kernel/EntityType.cls:120-129` (`TYPES`; a type with no `IDRULES` entry keeps its id exactly, as `backup-task` does), `Kernel/EntityRef.cls:59`, `Kernel/Proposal/Prohibited.cls` (`COVEREDTYPES`, the `TYPE<X>` parameters, `Prohibits`).
- Client: `ui/src/app/areas/interoperability/interop-item-setting-dialog.ts:110-145` (inputs `title`, `statement`, `multiline`, `defaultShown`; output `submitted`) and `interop-item-setting-list.page.ts` (registers its action with `ScreenActions.register`, sends with `ScreenActionHandler.sendFor`, `shell/screen-action-handler.ts:1766`). `shell/screen-outlet.ts` `DESCRIPTOR_PAGES`; `core/screen-actions.ts` `DESCRIPTOR_ACTION_LABELS`; `core/strings.ts` (`encryptionStartupRestart` :6067, `interopItemSettingSetAction` :6832 "Set value", `agentGovernanceColumnSetting` :821 "Setting", `errorLogColumnValue` :582 "Value", `actionRestart` :6670 "Restart"); `screens.generated.ts` (`node tools/screen-mirror.mjs`).
- `Screen/Area.cls:83` -- `os-management`'s pairs (`%Admin_Operate:USE`, `%Admin_Manage:USE`, `%DB_IRISSYS:READ`). Positions 1-25 are taken; these screens take 26-28.
- Arming: `scripts/ci-throwaway.sh:594-595,857-865` (the `# classes:` block and `OCUPILOT_ALLOW_BACKUP_CONTROL`), `ui/tools/ci.test.mjs:2598+` (roster derived), `:2684+` (`docs/DEVELOPMENT.md:494` must name every variable).
- Test models: `Test/BackupRead.cls`, `Test/BackupRules.cls`, `Test/BackupWrite.cls` (armed, `PreparedPolicyTaken` teardown guard), `Test/EcpProbe.cls:850` (`PendingRestart`), `Test/PortGate.cls:29` (roster) and `:338-352` (`BackupGateSeam`).

## Tasks & Acceptance

**Execution, batch 1 (server; commit when its loop commands are green):**

- Task 0, on `ocupilot-ci`, recorded under Design Notes before code: the four (or more) classic keys from `%SYS.Portal.Resources.NormalizePage` for `Config.Startup`, `Config.Memory`, `Config.Compatibility`, `MemoryStartup` and `Config.ValueEditor`; whether a `Config.*.Modify` needs `%DB_IRISSYS:WRITE` for a non-`%All` caller (else the write pairs are the classic page's); that a one-key `Modify` of `errlog` makes `PendingRestart` name it, and that a `SystemMode` set changes `$SYSTEM.Version.SystemMode()`.
- `src/OcuPilot/Port/ConfigPort.cls` -- new, on `BackupPort`'s shape. `PAIRS`, `WRITEPAIRS`, `COMPATIBILITYPAIRS`; `ENDPOINTS` `Startup`, `Memory`, `Compatibility`; `Invoke` branches `LIST`, `GET` (one row by `Name`) and `SET`; `Rows`; the exclusions, the read-only set and the two restart lists as parameters (Design Notes); `Snippet`/`SnippetForm` (AD-59); overridable `GateClass`/`LogFault`.
- `src/OcuPilot/Area/OsMgmt/ConfigSettingRules.cls` -- new. The matrix refusals, from the row the port answers, asked by the mint and by the port.
- `src/OcuPilot/Api/ConfigError.cls` -- new, on `BackupError`'s model; `Api/Error.cls` gets the `CONFIG.` prefix dispatch at both sites.
- `src/OcuPilot/Screen/Descriptor/StartupSettingList.cls`, `MemorySettingList.cls`, `CompatibilitySettingList.cls` -- new. Read source `config`, columns `Name`, `Value`, `Restart`, row action `set`, positions 26, 27, 28, classic page from Task 0; Compatibility's `ownPrivileges` `%Admin_Secure:USE`.
- `src/OcuPilot/Screen/Tool/ConfigSettingSet.cls` (abstract, on `InteropSettingSet`'s model) and `StartupSettingSet`, `MemorySettingSet`, `CompatibilitySettingSet` -- new. Arguments `Name` and `Value`; `SCREENACTIONS` `set`, `SCREENVALUES` `set=Value`, `SCREENEMPTY` `set=Value` (a text setting may be cleared); `READBACKFIELDS` `Value`; `Consequence` answers `CONFIG.SETTING.RESTART` from the fresh row's `Restart`; `CLASSICPAGES` adds `MemoryStartup` for the memory and startup tools and `ValueEditor` for all three.
- Add-only rows: `Kernel/Governance/Baseline.cls`; `Screen/Read.cls` and `Screen/Registry.cls` (`SOURCECONFIG`); `Kernel/EntityType.cls`, `Kernel/Proposal/Prohibited.cls` (`startup-setting`, `memory-setting`, `compatibility-setting`, covered, no predicate); `Screen/Titles.cls`, regenerated.
- `scripts/ci-throwaway.sh`, `docs/DEVELOPMENT.md:494` -- `OCUPILOT_ALLOW_CONFIG_SETTINGS`, with its `# classes:` line.
- `src/OcuPilot/Test/ConfigSettingRead.cls` (live-safe: three reads, the restart and read-only flags, gate refusals, governance defaults), `ConfigSettingRules.cls` (every refusal row, live-safe, no vendor write), `ConfigSettingWrite.cls` (armed: each matrix set row by both callers; restores every value it changed in `OnAfterOneTest` behind the `PreparedPolicyTaken`-style guard; the restart row writes `errlog` and restores it).
- The shared-surface rosters under Verification, each updated to the new shape.

**Execution, batch 2 (client; commit when its loop commands are green):**

- `ui/src/app/areas/os-management/config-settings.page.ts` with its spec -- one page for the three descriptors: the declared table, and Set value on a row opening `InteropItemSettingDialog` with the row's `Accepts` line and, when `Restart` is true, the restart sentence; the answer's consequence shown after the Save. A `ReadOnly` row has no Set value. Plus `shell/screen-outlet.ts` (three `DESCRIPTOR_PAGES` entries), `shell/screen-action-handler.ts`'s rosters, `core/screen-actions.ts`, `core/proposal-view.ts` (`CONFIG.SETTING.RESTART` to `encryptionStartupRestart`), `core/strings.ts`, `screens.generated.ts` (regenerated).
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` -- the ruled strings into Fixed strings, and the three screens into OS management's side-bar row.
- `ui/browser/config-settings.browser-spec.mjs` -- new. Each screen answers its rows after the answered signal; Set value on `LineRecall` round-trips and is restored; the restart sentence shows in the dialog for `NullSubscripts` (the dialog is canceled, nothing is sent); a read-only row draws no Set value.

**Acceptance Criteria:**

- AC1. Given the three screens and three tools on `ocupilot-ci`, when each read and each set runs through the OcuPilot API, then it round-trips over its backing class: every matrix row from "Startup read" to "Vendor refusal".
- AC2. Given a set of a setting whose vendor source states a restart, when it is proposed, saved or confirmed, then the card, the dialog and the Save answer state "Takes effect at the next restart."; a setting with no such source states nothing.
- AC3. Given a read-only row, when either caller sets it, then it is refused before any vendor call, and the screen offers no Set value on it.
- AC4. Given the default baseline, when the agent proposes any of the three sets, then it mints, and the confirm writes once with one audit marker and a `readBack`. With the key `false` the governance gate refuses it.

## Spec Change Log

## Review Triage Log

### 2026-11-15 - Review pass

- verdicts: 12 findings - high 0, medium 1, low 5, false 3, maybe-false 0 (3 rejected by rule or scope)
- findings:
  - `[medium]` `patch` Truncation of a capped config read is not pinned (AD-36) - fixed: `ConfigSettingRead` asserts a read capped at five answers five rows with `truncated` 1, the port's `maxRows` stops at three and refuses 0, x, -1 and 1.5; mutation observed red.
  - `[low]` `patch` The `SCREENEMPTY` declaration (a text setting may be cleared) is not pinned - fixed: the same test asserts `ScreenActionEmptyNames` and `ScreenActionValueNames` for each tool; mutation observed red.
  - `[low]` `patch` `Accepts` for a text setting is never observed - fixed: `SystemMode` reads `text|Text of up to 32 characters.`. The minimum-only branch has no setting on this build to read (inference), so it stays unpinned.
  - `[low]` `patch` The unknown-setting mint assertion compared nothing about the sentence - fixed in `ConfigSettingRules` and `ConfigSettingWrite`: the mint reads the target first and answers the sibling mints' sentence ("'X' is not present on this instance", as `BackupWrite` pins); the port's own `CONFIG.SETTING.NOTFOUND` is pinned by the rules rows.
  - `[low]` `patch` Page-spec mutations for the dialog and Save halves of AC2 were claimed in comments and not recorded - both applied, each red, reverted byte-identical; recorded in Verification.
  - `[low]` `reject` Browser spec's fixed 500 ms wait before asserting no dialog opened - a negative check has no signal to wait on; the press is synchronous and the dialog opens in the same task, so the wait only widens the window.
  - `[low]` `reject` Four page-spec tests carry no mutation line - each asserts a specific value; the reviewer did not call them unfalsifiable.
  - `[false]` `reject` An armed assertion that `PendingRestart` is unchanged after `history` is not measured - the armed class ran green on `ocupilot-ci` with that assertion, which is the measurement.
  - `[low]` `reject` Stale text in the intent contract's Always bullet and the proposed AD-4 paragraph - the fix is an edit to this spec's read-only contract; the runner ruling under Design Notes supersedes it.
  - `[low]` `defer` The reused `InteropItemSettingDialog` shows "Leave it empty to clear the value." under every non-boolean field, which misleads on integer and choice settings (an empty value is refused 400 `CONFIG.SETTING.VALUE`) - the file belongs to Epic 24's tree and the spec forbids an interop-file edit; recorded in `deferred:`.
  - `[low]` `reject` Intent-alignment: the Save answer's restart sentence is a client banner, as the route's answer carries no consequence - the spec's own client task is the banner, and the browser and component specs observe it at the surface.
  - `[low]` `reject` Intent-alignment: a read-only row's Set value is drawn disabled with a reason, not hidden - the registered-reason convention every other screen uses; the action cannot open the dialog (browser spec).

## Design Notes

**Governing ADs:** AD-4 (merge; the named exception below), AD-21 (no path is set), AD-22 (keys; a person's write is not governed), AD-29 (`ConfigPort`'s gate), AD-36 (bounded reads), AD-52, AD-53, AD-55, AD-56 (declared values), AD-58 (read-back), AD-6, AD-34, AD-15 (proposal, transition, audit), AD-14 (change event), AD-5, AD-44 (descriptors, classic keys), AD-16, AD-59 (namespace, `Snippet`), AD-10 (covered types, no new predicate), AD-39 (vendor text normalized), AD-35 (no secret field exists in these classes; `PasswordHash` holds hash parameters, not a password).

**Restart: the vendor's source for each setting.**

- Memory (`Config.config`): `Config.config.NoRestartOnActivate(Name)`, called at read time, the source the classic `ValueEditor` uses (`:338-342`). Measured on slot A: `errlog`, `routines`, `globals*kb`, `gmheap` and `jrnbufs` need a restart; `bbsiz`, `history`, `locksiz` and `MaxServers` do not. Measured on `ocupilot-ci`: an `errlog` change makes `Config.CPF.PendingRestart` name `config`/`errlog`, so the method and the instance agree for that row.
- Startup (`Config.Startup`): `WebServer` (CPF reference `RACS_WebServer`: "A restart is required for this setting to take effect."), `ErrorPurge` (`RACS_ErrorPurge`: "the change is applied the next time you restart"), `DefaultPort` (the classic Memory and Startup page's restart message, `MemoryStartup.cls:380-383`).
- Compatibility (`Config.Miscellaneous`): `NullSubscripts` (`ValueEditor.cls:22-24`, `RESTARTREQUIREDLIST`).
- Every other Startup and Compatibility setting has no vendor source: each one's CPF reference page (`RACS_<Name>`, all read at plan time) says nothing about a restart, and `ExtendedDatabaseSize`'s page is not published. That silence does not show the setting applies at once (inference). `PendingRestart` does not report Startup or Compatibility changes: `NullSubscripts`, `DefaultPort`, `ErrorPurge` and `SystemMode` changes added no reason to it (measured on `ocupilot-ci`). So the product states a restart only where a source above states one.

**Decided in-stage:**

- No Memory and Startup form. Its settings are rows here: `globals4kb`..`globals64kb`, `routines` and `bbsiz` in Memory settings, and `SystemMode` and `DefaultPort` in Startup settings. Each row is one setting, which the classic table hid only because the form owned it. `Config.WinStartup` auto-start is Windows-only, and this build is Linux, so it is not built (a named limit). The memory and startup tools declare `MemoryStartup` among their `CLASSICPAGES`, so a custom resource on that page still binds (AD-44).
- No harvest. `ExecuteMCPv2.REST.SystemConfig` reads a fixed eleven-key subset of `Config.config`, cannot write `Config.Startup` or `Config.Miscellaneous`, and passes caller-named keys to `Modify` unvalidated. Twenty lines of the port's own `Get`/`Modify` replace it. This is Rule 2's "a copy reads better" case, with nothing copied.
- Exclusions, as the classic table excludes them: `EnableLongStrings`, `OsType`, `Platform`, `PageSizeAlt`, `ZaMode`, `globals2kb` (always 0), `pijdir`, `wijdir` (Journal settings shows `wijdir`), and `EnsembleAutoStart` where the instance is not an interoperability one. The classic exclusions of `DefaultPort`, `bbsiz`, `globals*kb` and `routines` are dropped, because no form owns them here.
- `ReadOnly` rows: every `%Library.SysPath` property (`ConsoleFile`, `VMSConsoleTerminal`, `TempDirectory`, `WebServerURLPrefix`) and the path-valued strings `LibPath`, `Path`, `PythonPath` and `PythonRuntimeLibrary` (AD-21: shown, never set, as a license server's `KeyDirectory` is). Also `DefaultPort`, `DefaultPortBindAddress`, `WebServer` and `WebServerPort`, because changing one cuts OcuPilot off at the next restart: the web gateway reaches the instance through the default superserver (`Prohibited.cls`'s `SERVINGSUPERSERVER` premise), and the private web server serves OcuPilot on this build (measured: `httpd ... Listen 52773` in `ocupilot-ci`). This follows the Superserver screen's `SystemDefault`: shown here and never changed here, with no new predicate. This is stricter than the classic page, so it is a veto item for the runner.
- Value rules beyond the dictionary: `bbsiz` -1 or 256-2147483647; `routines` 0 or 36-65536 (`MemoryStartup.cls:117-119`); `DBSizesAllowed` a comma list of 4096, 8192, 16384, 32768 and 65536 that holds 8192, each `CheckBlockSizeAvailable` (`ValueEditor.cls:226-256`); `ListFormat` 0 or 1 (`ValueEditor.cls:409-414`); `%Library.Boolean` 0 or 1. Everything else follows `MINVAL`, `MAXVAL`, `VALUELIST` and `MAXLEN`, and the vendor's own validation stays the last word.
- The armed restart test writes `errlog` for real and restores it. That leaves the throwaway's pending-restart flag set, because no restore clears it (measured; Story 18.21 measured the same). No test reads the flag except `EcpProbe` and `EncryptionProbe` snapshots, which compare before and after inside one test. The dev instance never runs it (armed).
- Governance keys `true` (see Always).
- **Batch 1 choices.**
  - A set re-sends the complete `Get` array, the excluded and read-only keys as read (measured: a full-array `Modify` with one key changed changes only that key), after the rules judge the value. This is the runner's AD-4 ruling; the Always text's one-key `Modify` is superseded by it.
  - An integer property that declares no `MINVAL` has a lower bound of 0 (stricter than the dictionary; the vendor's own check holds `gmheap` and `locksiz`, the two that declare only a maximum, to it). `bbsiz` -1 and `routines` 0 are accepted beside their ranges, and their `Accepts` line states the range alone ("A whole number from 256 to 2147483647."), because the ruled strings hold no sentence for a range plus one value.
  - A vendor `Modify` refusal of a value the rules passed is answered 400 `CONFIG.SETTING.VALUE`, with the raw status logged (AD-39); no such refusal was found among the settings measured, so a test seam feeds it.
  - The restart consequence is read from the fresh row's `Restart` through the port. The row action route's answer carries no consequence (no route does); the client shows the restart sentence from the row's `Restart`.
  - Three read tools and a confusable group "Configuration settings" carry the screens' `read.label`; Compatibility's own pair is `%Admin_Secure:USE`, so a holder of OS management's pairs without it sees Compatibility settings unavailable.
  - String keys the descriptors name, for batch 2 to add to `strings.ts` and EXPERIENCE.md: `startupSettingsLabel`, `memorySettingsLabel`, `compatibilitySettingsLabel`, `aboutStartupSetting`, `aboutMemorySetting`, `aboutCompatibilitySetting`, `configSettingsEmpty`, `startupSettingsEmptyAgent`, `memorySettingsEmptyAgent`, `compatibilitySettingsEmptyAgent` and `<startup|memory|compatibility>SettingsPrompt1` to `3`. `OcuPilot.Api.ConfigError`'s `REASON*` and `ACCEPTS*` parameters hold the other ruled sentences, to be pinned equal to their `strings.ts` keys.
- **Task 0, measured on `ocupilot-ci` before code (batch 1).**
  - Classic keys from `%SYS.Portal.Resources.NormalizePage`: `%CSP.UI.Portal.Config.Startup`, `%CSP.UI.Portal.Config.Memory`, `%CSP.UI.Portal.Config.Compatibility`, `%CSP.UI.Portal.MemoryStartup` and `%CSP.UI.Portal.Config.ValueEditor`, each answered as spelled and none carrying a custom resource on this instance. The descriptors' `classicPage` names the first three, and the tools' `CLASSICPAGES` add `%CSP.UI.Portal.MemoryStartup` (memory and startup) and `%CSP.UI.Portal.Config.ValueEditor` (all three).
  - A `Modify` of `Config.Startup`, `Config.config` and `Config.Miscellaneous` by a caller holding only `%Admin_Manage:USE` and `%DB_IRISSYS:READ` fails `<PROTECT>` on `^SYS("CONFIG",...)` in each class; the same caller with `%DB_IRISSYS:WRITE` succeeds. So the write pairs add `%DB_IRISSYS:WRITE` (no longer an inference).
  - A full-set `Modify` (every key `Get` answers, 35, 41 and 33 keys, one changed) changed exactly that key in each class and added no pending-restart reason for any other key (AD-4 comply holds; the one-key exception is not needed). An `errlog` change 500 to 501 made `Config.CPF.PendingRestart` answer one reason, `config`/`errlog` old 500 new 501; restoring it added a second reason and cleared none. A `SystemMode` set to `TEST` changed `$SYSTEM.Version.SystemMode()` from empty to `TEST`, and restoring it read empty again. `NullSubscripts` added no reason.
  - `SYS.Database.CheckBlockSizeAvailable` answers 0 for 4096 and 1 for 8192, 16384, 32768 and 65536 on this build. The vendor's own `IsValid` refuses a negative `gmheap` and `locksiz` and passes `ListFormat` 5, `routines` 5 and `bbsiz` 100 (so those three are judged by the rules beyond the dictionary).
- Pairs: reads `%Admin_Manage:USE` and `%DB_IRISSYS:READ` (the classic `RESOURCE`, in `%SYS`); Compatibility adds its own `%Admin_Secure:USE` (classic menu); writes add `%DB_IRISSYS:WRITE`, unless Task 0 measures otherwise (inference from every `Config.*` write in Epics 16 and 18). Stricter is allowed, looser is not.
- The client reuses `InteropItemSettingDialog` by import rather than moving it. Moving it would edit an Epic 24 file, and a second dialog would copy it (Rule 31).

**Proposed AD-4 named exception (Rule 20, for the runner):** "`Config.Startup`, `Config.config` and `Config.Miscellaneous` keep every key a `Modify` array omits (measured at Story 21.3's plan on `ocupilot-ci`: a one-key `Modify` of `ErrorPurge`, `LineRecall` and `history` left every other key unchanged), so a setting's set sends that one key; re-sending the class would re-send every restart-bound key." And add `ConfigPort` to AD-29's Binds.

**Strings, proposed for the spec gate's ruling** (reuse: "Setting", "Value", "Restart", "Set value", "Takes effect at the next restart."):

- Titles: "Startup settings" · "Memory settings" · "Compatibility settings". Entity nouns: "Startup setting" · "Memory setting" · "Compatibility setting".
- Empty: "No settings to show."
- Accepts lines: "0 (off) or 1 (on)." · "A whole number from %1 to %2." · "A whole number of at least %1." · "One of %1." · "Text of up to %1 characters." · "Block sizes from 4096, 8192, 16384, 32768 and 65536, separated by commas; 8192 is required." · "Shown here and never changed here."
- Reasons: `CONFIG.SETTING.NOTFOUND` "There is no setting with that name." · `CONFIG.SETTING.READONLY` "This setting is shown here and never changed here." · `CONFIG.SETTING.VALUE` "This setting does not accept that value."
- Prompts, three per screen: "Which startup settings take effect only after a restart?" · "What does ShutdownTimeout control?" · "Explain the job and process start and halt settings." · "How much memory goes to the database cache for each block size?" · "Which memory settings take effect only after a restart?" · "What do gmheap and locksiz control?" · "What does NullSubscripts change?" · "Which compatibility settings take effect only after a restart?" · "What does the Undefined setting do?". Empty-agent phrases: "change a startup setting" · "change a memory setting" · "change a compatibility setting".

**Extend, don't copy (Rule 2/31):** `ConfigPort` follows `BackupPort`; `ConfigSettingSet` follows `InteropSettingSet` as a sibling, because a subclass would couple OS management to `InteropPort`; `ConfigError` follows `BackupError`; the three set tools are one abstract class and three subclasses that each name an endpoint.

**Integration ACs:** `ConfigPort` is consumed in this story by its three tools and three descriptors (AD-53's two callers). The matrix rows are its integration ACs, observed through the API and the browser spec.
**Consumed-by:** Story 21.4, SQL settings over `Config.SQL` (inference: the same `Get`/`Modify` shape).
**Consumes:** `Screen.Gate`, `Kernel.Fault`, `Screen/Tool/Write`, `AdminPort`'s `Snippet` helpers.

**Ledger inbox:** none.

**Contended paths:** `origin/OCU-1-epic24` has changed none of the shared files named here (checked at plan time). `OCU-1-epic22` has no remote branch. Every shared registration file takes add-only rows.

**Runner rulings at the spec gate (2026-11-15, unattended):**

- AD-4: comply, no amendment. Each set is a merge write that sends the complete property set: read fresh, apply the one change, send every key the tool may set, as AD-4's Rule requires; the four never-set network keys and the read-only path keys are re-sent as read. Task 0 measures on `ocupilot-ci` that a `Modify` re-sending every key unchanged with one key changed adds no pending-restart reason for an unchanged key and changes no other key. If it does, HALT as an `intent gap` naming the measurement: only then is the proposed AD-4 named exception needed, and the runner takes it to the orchestrator. The proposed `ConfigPort` addition to AD-29's Binds stays a proposal for the owner's attended Update (it joins DW-2559).
- Veto item U-47: the four network settings are shown and never set; the three governance keys ship `true`; the proposed strings are kept as written.

## Verification

**Shared surfaces:** the OS management screen roster and positions (`Navigation.cls:539` 57 and :540-548; `WireSecurityRead.cls:620-633`; `WireAreaAnyScreen.cls:271`; `LanguageServerWire.cls:290-297` for Compatibility's own pair; `ui/tools/navigation.test.mjs:246-248,506-508`; `Descriptor.cls:77-79`; `StageTwoTools.cls:138-140`; `ui/tools/screen-mirror.test.mjs:2738`), the tool registry (`ReadTool.cls:93` 423 and :94; `ToolWrite.cls:1326` 66; `ToolRoundTrip.cls:101` where a refusal applies), entity types (`Descriptor.cls:1824` 79; `Prohibited.cls:233`), the read source kinds (`screen-mirror.test.mjs:3138` sixteen; the messages at `AdminPairCorpus.cls:58`, `DocDbDescriptor.cls:59`, `InteropDescriptor.cls:101`, `MetricsDescriptor.cls:61`, `SqlActivityDescriptor.cls:54`), `PortGate.cls:29` and :338-352, `ClassicPageGate.cls:76`, `MappingDescriptor.cls:24`, `SurfaceCoverage.cls:267-274`, `proposal-view.test.mjs:1146-1155`, `ci-throwaway.sh`'s arming roster, `TeardownGuard` (a new armed class's teardown opens with its guard). The implement stage greps `ui/browser`, `ui/tools`, the `ui/src` specs and `src/OcuPilot/Test` for each, and every test it changes joins `(loop)`.
*Every test added or changed passes on a fresh environment, in either order.* Each set test restores the value it found.

**Commands.** One per foreground call, `timeout: 600000`, against `ocupilot-ci` only. Never two test calls in one message.

- `(loop)` `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/4667058b-f052-49c9-b08a-221f7f41dfab/scratchpad/e21u/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` -- expected: `LOADERRORS=0`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.ConfigSettingRead`, one class per call, then each of `ConfigSettingRules`, `ConfigSettingWrite`, `PortGate`, `SurfaceCoverage`, `GovernanceBaseline`, `Governance`, `Prohibited`, `ReadTool`, `ReadDescriptions`, `ToolEmit`, `ToolDispatch`, `ToolRoundTrip`, `ToolWrite`, `Descriptor`, `Navigation`, `ClassicPageGate`, `MappingDescriptor`, `DraftRegistry`, `StageTwoTools`, `Wire`, `WireAreaAnyScreen`, `WireSecurityRead`, `LanguageServerWire`, `TeardownGuard`, `AdminPairCorpus`, `DocDbDescriptor`, `InteropDescriptor`, `MetricsDescriptor`, `SqlActivityDescriptor` -- expected: green.
- `(loop)` `uv run scripts/check-objectscript.py`, `uv run scripts/test_check_objectscript.py`, `bash scripts/lint-docs.sh` -- expected: clean.
- `(loop)` `cd ui && npm run build` and `npm run test:components`; redeploy with `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`; then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/config-settings.browser-spec.mjs` -- expected: green.
- `(once)` `cd ui && npm run test:tools` -- expected: green.
- `(once)`, runner-owned: the full ObjectScript sweep one class per call, `smoke.sh --container ocupilot-ci`, and Rule 30's fresh check. The full browser suite is left to CI.

**Mutations (Rule 19), one per AC, each applied, observed red, reverted (tree identical by `git status --short` and `git diff --stat`), and the reverted source reloaded:**

- AC1: `ConfigPort.BuildRow` drops the `Restart` member -> `ConfigSettingRead` red; `VendorModify` sends the one key alone -> `ConfigSettingRules`' key-list assertion red; `SendProperties` sends no `Modify` -> `ConfigSettingWrite`'s value assertions red (all three observed red and reverted, batch 1).
- AC2: `ConfigSettingSet.Consequence` answers nothing -> `ConfigSettingWrite`'s restart test red (observed, batch 1); the client mapping removed -> `proposal-view.test.mjs` red; one word of a `ConfigError` sentence changed -> `config-settings.test.mjs` red (both observed, batch 2); the page's dialog statement without the restart sentence, and the page's banner after a Save without it -> `config-settings.page.spec.ts` red, one test each (observed). A capped read that loses its extra row (`Screen/Read.cls` asks the port for the cap alone) -> `ConfigSettingRead`'s truncation assertion red; `SCREENEMPTY` emptied -> its empty-names assertion red (observed).
- AC3: `DefaultPort` removed from the read-only set -> `ConfigSettingRules` and `ConfigSettingRead` red (observed, batch 1; never against `ConfigSettingWrite`, which would write it); the page's `set` registration drops its `reason` -> `config-settings.page.spec.ts` and the browser spec's read-only test red (observed after rebuild and redeploy, batch 2).
- AC4: `osmgmt.startupsettings.set` set `false` -> `ConfigSettingRead`'s governance test red; `osmgmt.compatibilitysettings.set` set `false` -> `ConfigSettingWrite`'s dispatch assertions red (observed, batch 1).

## Auto Run Result

Status: done
Blocking condition: none

**Summary.** `ConfigPort` and three OS management screens (Startup, Memory and Compatibility settings, positions 26 to 28) with a Set value write for each, reachable by a person's dialog and by a confirmed agent proposal. A set re-sends the complete property set (the runner's AD-4 ruling; Task 0 measured that it changes only the one key). Restart text comes from the vendor's own source per setting; the four network settings and path settings are shown and never set. Three governance keys ship `true`.

**Files.** New: `Port/ConfigPort`, `Area/OsMgmt/ConfigSettingRules`, `Api/ConfigError`, three descriptors, `Screen/Tool/ConfigSettingSet` and its three subclasses, four test classes (`ConfigSettingRead`, `ConfigSettingRules`, `ConfigSettingWrite` armed, `ConfigGateSeam`), `config-settings.page.ts` with its spec, `ui/tools/config-settings.test.mjs`, `ui/browser/config-settings.browser-spec.mjs`. Add-only rows: `Error`, `EntityType`, `Prohibited`, `Baseline`, `Read`, `Registry`, `Titles`, `strings.ts`, `screens.generated.ts`, `screen-mirror.mjs`, `screen-outlet.ts`, `screen-action-handler.ts`, `screen-actions.ts`, `proposal-view.ts`, `EXPERIENCE.md`, `ci-throwaway.sh` and `docs/DEVELOPMENT.md` (`OCUPILOT_ALLOW_CONFIG_SETTINGS`), and the shared-surface rosters.

**Review.** 12 findings: 5 patched (1 medium, 4 low), 1 deferred, 6 rejected with reasons in the Review Triage Log. Follow-up review recommended: false (one medium patched).

**Verification.** All spec `(loop)` ObjectScript classes green on `ocupilot-ci` (armed `ConfigSettingWrite` with the variable injected); `check-objectscript.py` 0 problems; `lint-docs.sh` clean; `npm run build` clean; `test:components` 3456 pass; `test:tools` 2286 pass; `config-settings.browser-spec.mjs` 4/4 after rebuild and redeploy. Rule 19 mutations recorded in Verification, each observed red and reverted.

**Residual risks.** `Prohibited.cls` long lines also edited by Epic 24: expect a textual union at merge. The throwaway's pending-restart flag holds the armed test's `errlog` reasons. The full ObjectScript sweep, `smoke.sh` and Rule 30's fresh check are the runner's `(once)` items.
