---
title: 'Story 21.14: NLS configured defaults and locale definitions'
type: 'feature'
created: '2026-11-15'
status: 'draft'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The instance's NLS configured defaults (classic `NLSConfigDefs`) and its locale definitions (classic `NLS`, with the properties editor `NLSEdit`) have no screen, no route and no tool in OcuPilot. An operator who wants to see which tables the instance defaults to, or to validate, install, load a table from or delete a locale, has to use the classic portal.

**Approach (conditional on the split ruling below):** Add an `NLSDefaults` settings endpoint to Story 21.3's `ConfigPort` (every table row read-only; the one settable row is the locale-format switch), and a new `LocalePort`, on `BackupPort`'s shape, for the locale list and its actions: Validate (a read), Install, Load table and Delete. Each write is reached by a person's action and a confirmed agent proposal (AD-53). Copy and the properties editor go to a new sibling, Story 21.16.

## Boundaries & Constraints

**Always:** `ConfigPort` and `LocalePort` are the only product classes that name `%SYS.NLS.Table`, `Config.NLS.Locales`, `Config.NLS.Tables` or `^SYS("NLS","Config")`; each gates before any vendor call (AD-29) and switches namespace by save and restore (AD-16). Every write is minted, confirmed once, audited, read back (AD-58) and announced (AD-14). A locale, a table type and a table name are each checked against the instance's own list before any vendor call, so no caller value is passed through unchecked (AD-21). Every read is bounded (AD-36). Install and Delete are destructive and their keys ship `false`.

**Never:** No configured-default table is settable (the classic page sets none). No Copy, no properties edit, no Export or Import (Story 21.16 and Story 21.15). No harvested body: the MCP suite's only locale code is a read of the current locale and the locale names (`ExecuteMCPv2.REST.SystemConfig:173-205`), less than the list needs. No user-facing string beyond those the spec gate rules. OcuPilot's own interface stays English.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Defaults read | `GET` NLS defaults | One row per `%SYS.NLS.Table` category (19) plus `LocaleFormat`; `Value` the effective table, `Source` `config` or `locale`; table rows `ReadOnly` | none |
| Locale-format set | `LocaleFormat` 1, by both callers, then restored | `^SYS("NLS","Config","LocaleFormat")` reads 1, the current locale is reloaded, `readBack` matches | none |
| Locales read | `GET` locales | One row per `Config.NLS.Locales:List` entry (36 on slot A): `Name`, `Description`, `Current`, `Custom` (name starts `y`) | none |
| Validate | a listed locale | `{Valid, Errors[], Warnings[]}` from `IsValid` and `IsLoadable`; nothing written | 404 for an unlisted name |
| Install | a listed locale, key `true` | it becomes current; the answer names the old and new IRISTEMP collation | 409 `LOCALE.NOTINSTALLABLE` with the vendor's errors when `IsInstallable` refuses |
| Load table | a locale, a table type, a name from that locale's `Tables` query | the vendor loads it | 400 `LOCALE.TABLE` for a type or name not in the list |
| Delete | a custom, non-current locale, key `true` | it is gone; read-back reads 404 | 409 `LOCALE.SYSTEM` for a system locale, 409 `LOCALE.CURRENT` for the current one |

## Runner rulings at the plan halt

(Empty until the runner rules on the questions under Design Notes.)

## Runner rulings at the plan halt (2026-11-15, unattended)

- **Q1 split (decide, option A modified):** this story keeps the configured defaults (every table row read-only, the locale-format switch settable) and the locale list with Validate (a read), Install and Delete on a new `LocalePort`, plus the English criterion. Copy, the locale properties editor and **Load table** move to new Story 21.16 Custom locales (inserted in `epics.md`).
- **Q2 (decide):** Load table is not built here. It needs a named AD-51 case for `LocalePort`, and AD-51 is cited by Epic 24's in-flight specs, so the runner may not amend it unattended (doctrine U7/U14); it goes to Story 21.16, whose plan takes the question to the orchestrator.
- **Q3 (veto U-56):** Install is a destructive, typed-confirm write whose key ships `false`; `IsInstallable` errors refuse at mint and port; the consequence names the cached-query purge and the IRISTEMP collation change. If Task 0 shows installing another locale breaks OcuPilot, HALT as an intent gap (that would need a new AD-10 entry).
- **Strings (veto U-56):** the strings under Design Notes are kept as planned.

</intent-contract>

## Code Map

- `irissys/%CSP/UI/Portal/NLSConfigDefs.cls:102-215` -- the configured-defaults page: display only (`RESOURCE` `%Admin_Manage` :21). Each row is `%SYS.NLS.Table("Config")`'s property, else the current locale's (`Config.NLS.Locales.OpenCurrent()`); 17 table rows (it omits `DSMDDP`, `DTMDCP`), `CSP` defaulting to `UTF8` (:186-187), and "Load from locale?" from `^SYS("NLS","Config","LocaleFormat")` (:198-200).
- `irissys/%SYS/NLS/Table.cls:7-123` -- 19 categories; "Changes to a Config object will only affect the next system reboot" (:70-72). Category to locale property: `Process`/`TranZCVT`, `IRISTerminal`/`TranProgrammer`, `OtherTerminal`/`TranTerminal`, `File`/`TranSequential`, `Magtape`/`TranMagTape`, `TCPIP`/`TranTCP`, `DSMDDP`/`TranDDP`, `DTMDCP`/`TranDTMDCP`, `SystemCall`/`TranSystemCall`, `Printer`/`TranPrinter`, `PatternMatch`/`PatternTable`, `Identifier`/`IdentifierTable`, `Uppercase`/`UpperCaseTable`, `Lowercase`/`LowerCaseTable`, `Titlecase`/`TitleCaseTable`, `Accent`/`AccentTable`, `Collation`/`CollationTable`, `XYAction`/`XYTable`.
- `irissys/%CSP/UI/Portal/NLS.cls` -- the locale page (`RESOURCE` `%Admin_Manage` :21): the locale-format switch (`ReloadDefault` :550-556, writes the node and reloads the locale); Validate (`DrawResult` :480-500, `Compile` then `IsLoadable`); Install (`ValidateInstall` :560-581 refuses on `IsInstallable` errors and shows warnings; `InstallNow` :584-606 reports an IRISTEMP collation change; the cached-query purge warning :233); Load Table (type list :140-143, names from `Config.NLS.Locales:Tables` :445-460, `Config.NLS.Tables.Load` :615-621); Delete (offered only for a `y` locale that is not current, :203-208, `DeleteNow` :528-533). Copy (:497-525), Export (:535-548) and Properties (`NLSEdit`) are not this story's.
- `irissys/Config/NLS/Locales.cls` -- bodies not exported (deployed); `Get` :374, `Delete` :307, `Install` :493, `IsInstallable`, `IsLoadable`, `IsValid`, `Reload` ("activate changes in configured defaults"), `OpenCurrent`; queries `List` (`Name,Description`) and `Tables(Locale,Type,BuiltIn=0)`. Data in `^SYS("NLS","LocalesD")` (`IRISSYS`). Only `y` locales survive an upgrade (:14-19).
- `irissys/Config/NLS/Tables.cls:333-340` -- `Load(loc,typ,nam)`: "If loc = current locale, changes defaults if necessary".
- **Measured (read-only, slot A, 2026-11-15):** 36 locales, all Unicode (`w`), none custom; current `enuw`; no configured default set (all 19 empty); `LocaleFormat` undefined; `Get("enuw")` answers 56 properties, no credential; `enuw`'s `Tables` query: `XLT` 17, `LowerCase`, `UpperCase`, `TitleCase`, `Pattern`, `Ident` 1 each, `Collation` and `XY` 0; `Config.NLS.Tables:List` 241 tables, none custom; `NormalizePage` keeps `%CSP.UI.Portal.NLS`, `.NLSEdit`, `.NLSConfigDefs` as spelled; `%SYS_Portal.Resources` holds no row for them.
- **Ports to extend or copy:** `src/OcuPilot/Port/ConfigPort.cls` (`ENDPOINTS` :54, roster family `SHELLROSTER` :93, `RosterOf` :546, `CollectRoster` :616, `RosterValue` :630, `SendNode` :677, `PurgeAfterSet` as the after-write hook); `src/OcuPilot/Port/BackupPort.cls` (list plus action types, `PAIRS`/`WRITEPAIRS`, seams) for `LocalePort`.
- **Tools:** `Screen/Tool/ConfigSettingSet.cls` and `SqlShellSettingSet.cls` (the set); `Screen/Tool/BackupAction.cls` and its subclasses (action tools); `InteropLookupEntryRemove.cls` (destructive delete parameters).
- **Client:** `ui/src/app/areas/os-management/config-settings.page.ts` (the defaults screen); the backup screen's page for the list-with-actions shape; `shell/screen-action-handler.ts`, `shell/screen-outlet.ts`, `core/screen-actions.ts`, `core/proposal-view.ts`, `core/strings.ts`, `screens.generated.ts`. `ui/tools/screen-mirror.mjs:1226` parses `ConfigPort.ENDPOINTS`.
- Product code calls no `$ZDATE`, `$ZDATETIME`, `$ZTIME` or `$FNUMBER` without a format argument (grep of `src/OcuPilot` outside `Test/`).

## Tasks & Acceptance

Not planned: held for the split ruling. The re-plan writes them from this Code Map in two batches (server, client), following Story 21.13's task list file for file, with this Task 0 on `ocupilot-ci`, every probe restored, recorded under Design Notes before code:

- (a) `Config.NLS.Locales.Delete`, `Install`, `Config.NLS.Tables.Load` and a write of `^SYS("NLS","Config","LocaleFormat")` by a caller holding only `PAIRS` fail, and with `WRITEPAIRS` succeed (inference: `%DB_IRISSYS:WRITE` suffices).
- (b) `IsValid` and `IsLoadable` change nothing (checksum `^SYS("NLS")` and `^%nls` before and after), and `Compile` does or does not (inference: it writes).
- (c) Install `deuw`, then `smoke.sh --container ocupilot-ci` and `ConfigSettingRead`, then install `enuw` again: the IRISTEMP collation and the smoke result each time (inference: OcuPilot keeps working). Red means `## Clarification Needed` proposing a prohibited predicate.
- (d) `LocaleFormat` 1 then `Config.NLS.Locales.Reload()`: whether `Reload` matches the classic page's `Locale^NLSLOAD`, and the smoke result.
- (e) `Load` of an `XLT` table into the current locale: what changes, and the smoke result.
- (f) A custom locale made by vendor `Create` from `enuw`'s `Get` set is listed `Custom`, deletes, and leaves no `Tables` row.

## Spec Change Log

- 2026-11-15 (lead): plan halt ruled (split, Q2, Q3); status reset to draft for re-plan.

## Review Triage Log

## Design Notes

**Why this halts (size).** The story's AC covers SA-26 (configured defaults, a read) and SA-27 (locale definitions, catalog size L): two classic pages and an editor with seven save groups and I/O table add and remove, over three vendor classes. Planned whole, that is three screens, about ten write tools (Install, Load table, Delete, the locale-format switch, Copy, the editor's scalar set, its eight table lists, and I/O table add, set and remove) and a new port. Story 21.13, with two screens and five tools, is already `oversized`; the plan rules' guide is about eight tools or fifteen files.

**Q1, split (recommended A).** Siblings numbered after Epic 21's highest story, 21.15:

- **A.** **21.14, NLS configured defaults and locale definitions** (keeps its key and title): the configured-defaults screen (every table row read-only, the locale-format switch settable) and the locale list with Validate, Install, Load table and Delete. Takes the first AC for "the NLS configured defaults" and the locale list, and the English AC. **21.16, Custom locales** (new, planned after 21.15): Copy (create a `y` locale from any locale) and the locale properties editor (the seven groups and I/O table add and remove, `y` locales only, as the classic page allows). Takes the first AC for "the locale definitions editor", and the English AC. Its AD-4 question (a `Modify` that receives table lists as subscripted arrays) is measured at its plan.
- **B.** Keep everything in 21.14 as three committable batches (defaults, list actions, editor). About ten write tools: beyond the guide.

**Q2, Load table takes a caller's choice (veto window, AD amendment).** AD-51 allows a port to build a vendor call from a tool's declared non-secret arguments only as a named entry. Proposed entry: "`LocalePort`, which builds `Config.NLS.Tables.Load`'s type and name from the load tool's declared `TableType` and `TableName`, each refused unless the target locale's own `Tables` query lists it (Story 21.14)". Alternative: Load table moves to 21.16 or is not built.

**Q3, Install (veto window).** Recommended: destructive, key `false`, typed-name confirm; an `IsInstallable` error refuses at mint and port (409 `LOCALE.NOTINSTALLABLE`, the vendor's errors in `detail`); its warnings ride the card's detail; the consequence sentence names the cached-query purge and the possible IRISTEMP collation change, as the classic page does. If Task 0 (c) breaks OcuPilot, Install becomes a prohibited action instead, by a new AD-10 entry (escalated then).

**Decided in-stage (stricter than the brief):**

- Every configured-default table row is read-only, not only `Process`, `CSP` and `Collation`: the classic page sets none (`NLSConfigDefs` is display only) and catalog row SA-26 is a read. All 19 categories are listed, `DSMDDP` and `DTMDCP` included; `CSP` reads `UTF8` when neither source sets it, as the classic page shows.
- `LocaleFormat` is settable, because the classic locale page sets it; after a changed value the port calls `Config.NLS.Locales.Reload()` (the supported call; Task 0 (d) compares it with the classic page's routine), on 21.4's after-write hook. No product format reads the locale's formats (grep above), so it cannot change OcuPilot's own output (inference; Task 0 (d)).
- Validate is a read: `IsValid` and `IsLoadable`, no `Compile`, so it writes nothing (inference; Task 0 (b)). A `y` locale edited in 21.16 is compiled by that story's write, not by Validate.
- Delete is refused for a system locale and for the current locale, as the classic page disables it for both.
- `LocalePort` is a new sibling, not a `ConfigPort` family: locale rows are not settings rows, and its action types follow `BackupPort`'s shape. The defaults endpoint fits `ConfigPort`'s roster family (`SHELLROSTER`), which it extends.
- OS management positions 36 and 37 (after 21.13's 34 and 35); routes `os-management/nls-defaults`, `os-management/locales`; entity types `nls-default`, `locale`; tools `osmgmt.nlsdefaults` (`.set` `true`) and `osmgmt.locales` (`.install` `false`, `.delete` `false`, `.loadtable` `true`); classic pages `%CSP.UI.Portal.NLSConfigDefs` (its set also names `%CSP.UI.Portal.NLS`) and `%CSP.UI.Portal.NLS`.

**Governing ADs:** AD-4 (`LocaleFormat` is one node; no `Modify` in this share), AD-6, AD-10, AD-13, AD-14, AD-15, AD-16, AD-21, AD-22, AD-29, AD-34, AD-35 (no locale property holds a credential; `Get("enuw")` read by name), AD-36, AD-39, AD-44, AD-51 (Q2), AD-52, AD-53, AD-56, AD-58, AD-59.

**Strings, escalated for the spec gate's ruling** (reuse: "Name", "Value", "Description", "Set value", "Delete", 21.3's refusal sentences): titles "NLS configured defaults" · "Locale definitions"; entity nouns "NLS configured default" · "locale"; columns "Source" · "Current" · "Custom"; source values "Configured" · "From the locale"; actions "Validate" · "Install" · "Load table"; dialog labels "Table type" · "Table name"; Validate answers "This locale is valid." · "This locale has problems:"; `LOCALE.NOTINSTALLABLE` "This locale cannot be installed on this instance."; `LOCALE.SYSTEM` "A locale InterSystems ships cannot be deleted; only a custom locale, whose name starts with y, can."; `LOCALE.CURRENT` "The current locale cannot be deleted."; `LOCALE.TABLE` "Choose a table type and a table this locale lists."; consequences: Install "Installing makes this locale the instance's current locale, purges every cached query, and can change IRISTEMP's default collation." · Delete "The locale and its definition are removed from this instance." · Load table "Loading a table into the current locale can change this instance's default for that table type until the next restart." (inference; Task 0 (e) fixes the wording) · LocaleFormat "Changing this reloads the current locale, so new processes take its date, time and number formats." ; empty-agent phrases "change an NLS configured default" · "install a locale"; prompts "Which collation does this instance use by default?" · "Which locale is current?" · "Is this locale valid?" · "Which tables can this locale load?".

**Extend, don't copy (Rule 2/31):** extends `ConfigPort` (a roster endpoint), `ConfigSettingRules`, `ConfigError`, `ConfigSettingSet` and `config-settings.page.ts`; `LocalePort` copies `BackupPort`'s structure, because a shared base would couple two vendor families that diverge; its tools subclass a new `LocaleAction` on `BackupAction`'s shape, and Delete takes `InteropLookupEntryRemove`'s destructive parameters.

**Integration ACs:** both endpoints are consumed in this story by their descriptors and write tools (AD-53's two callers). **Consumed-by:** Story 21.16 (Copy and the editor reach their target through `LocalePort`). **Consumes:** Story 21.3/21.4's `ConfigPort`, rules, error, set tool and page; Story 21.2's `BackupPort` shape; `Screen.Gate`, `Kernel.Fault`, `Screen/Tool/Write`.

**Ledger inbox:** none.

**Contended paths:** Epic 22 has no remote branch or worktree. Epic 24's worktree holds uncommitted edits to `EXPERIENCE.md`, `ci-throwaway.sh`, `Baseline.cls`, `Prohibited.cls`, `Screen/Read.cls`, `Test/ClassicPageGate.cls` and `Test/Descriptor.cls`; this story's edits there are add-only rows. No Epic 24 commit beyond feature touches a file named here (checked at plan time).

**Context cache:** `epic-21-context.md` reused as the runner directed, although the spine and `EXPERIENCE.md` are newer than it (21.4's merges).

## Verification

Not planned (held for the ruling). The re-plan follows Story 21.13's shape: `(loop)` the story's own classes (`NlsDefaultRead`, `LocaleRead`, `LocaleRules`, armed `LocaleWrite` under `OCUPILOT_ALLOW_CONFIG_SETTINGS`) and every shared-surface class on `ocupilot-ci`, one per call; `(once)` `npm run test:tools`; the full ObjectScript sweep is the runner's; the full browser suite is CI's.

**Shared surfaces (for the re-plan, each in `(loop)`):** OS management rosters and pair-order counts (`WireSecurityRead`); `LanguageServerWire` and `ui/browser/language-servers.browser-spec.mjs`; `Navigation`, `Descriptor`, `TeardownGuard`; the read-source count, `ReadTool`'s registry size, `ToolWrite`'s other-port count; `Prohibited`'s covered types; `ClassicPageGate`, `MappingDescriptor`, `SurfaceCoverage`, `ToolRoundTrip`; `PortGate`, `GovernanceBaseline`, `ConfigSettingRead` and the `config` endpoint roster, `ui/tools/navigation.test.mjs`, `ui/tools/screen-mirror.test.mjs`, `ci.test.mjs`'s arming roster, `proposal-view.test.mjs`; and the EXPERIENCE.md literal cap in `ui/tools/strings.test.mjs` (4200; if this story's strings cross it, raise it by 400 under the file's protocol and report it).
*Every test added or changed passes on a fresh environment, in either order.* Each write test creates its own `y` locale, or restores the current locale and `LocaleFormat` it found.

## Auto Run Result

Status: blocked
Blocking condition: intent gap -- Story 21.14 is too large for one implement pass: SA-26 plus SA-27 (catalog size L) is three screens, about ten write tools and a new port, against a guide of about eight tools that Story 21.13's five tools already strain. Recommended split (Q1 A): 21.14 keeps the configured defaults (every table row read-only, the locale-format switch settable) and the locale list with Validate (a read), Install (destructive, key off), Load table and Delete (destructive, key off) on a new LocalePort, plus the English AC; new Story 21.16 "Custom locales" takes Copy and the locale properties editor (seven groups, I/O table add and remove, y locales only), plus the English AC. Also asked: Q2 Load table needs a named AD-51 entry for LocalePort building Config.NLS.Tables.Load's type and name from declared arguments checked against the locale's own Tables query (veto window); Q3 Install as a destructive, typed-confirm write with key false, IsInstallable errors refusing at mint and port, and a consequence naming the cached-query purge and the IRISTEMP collation change (veto window). New strings listed under Design Notes.

Investigation is in the Code Map. Probes were read-only on slot A (`ocupilot`): locale list and `Get`, `%SYS.NLS.Table("Config")`, `Tables` queries, `NormalizePage`; nothing ran against `ocupilot-ci`.
