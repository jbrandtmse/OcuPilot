---
title: 'Story 21.4: NLS locales and SQL settings'
type: 'feature'
created: '2026-11-15'
status: 'in-progress'
baseline_revision: '6108728a37aabfa0530335c247643351a32a5fbe'
baseline_commit: '6108728a37aabfa0530335c247643351a32a5fbe'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred:
  - summary: >-
      A failed cached-query purge after a changed purge key is pinned only at the port, not through the screen route, the agent confirm or the dialog.
    evidence: |-
      PurgeFails/PurgeCachedQueries appear only in ConfigGateSeam and SqlSettingRules; a confirm or screen-action case with a failing purge would settle whether the audit marker and the person's error display hold.
    location: >-
      src/OcuPilot/Test/SqlSettingWrite.cls
    severity: medium (unverified)
  - summary: >-
      The real SendTsql refusal prefix check (a setter answer starting Invalid) has no test; the seam's own override bypasses it.
    evidence: |-
      SqlSettingRules reaches the 400 through ConfigGateSeam.VendorRefuses; the rules refuse bad values first, so only a vendor-side change reaches the branch. A test that drives the real setter with a value the rules admit and the vendor refuses would settle it.
    location: >-
      src/OcuPilot/Port/ConfigPort.cls:725
    severity: low
---

<intent-contract>

## Intent

**Problem:** The instance's SQL and object settings (the classic SQL page and its SQL Shell tab, TSQL Compatibility, ISQL Compatibility) have no screen and no route in OcuPilot. An operator who wants to read or change them has to use the classic portal.

**Approach (conditional on the split ruling below):** Extend Story 21.3's `ConfigPort` with endpoints for `Config.SQL`, the SQL Shell settings, the TSQL settings and the ISQL settings, each a settings-table screen with one row action, Set value, reached by a person's dialog and a confirmed agent proposal (AD-53), exactly as Startup, Memory and Compatibility settings are.

## Boundaries & Constraints

**Always:** `ConfigPort` is the only product class that names `Config.SQL`, `%SYSTEM.TSQL` or the `^%SYS` setting nodes for these screens; it gates before any vendor call (AD-29) and switches namespace by save and restore (AD-16). Each set is a merge write (AD-4), minted, confirmed once, audited, read back (AD-58) and announced (AD-14). The value is judged by `ConfigSettingRules` at the mint and at the port. Every read is bounded (AD-36).

**Never:** No setting that holds a path (AD-21) or evaluated code, or that could cut OcuPilot off or break its own SQL, is settable (Design Notes). No new route in `Api/Router.cls`. No harvested body. No new `PROHIBITED.*` predicate. No user-facing string beyond those the spec gate rules. OcuPilot's own interface stays English.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| SQL read | `GET` SQL settings | One row per `Config.SQL.Get` key (46 on slot A), each `Name`, `Value`, `Kind`, `Accepts`, `Restart`, `ReadOnly` | none |
| TSQL read | `GET` TSQL settings | Dialect, ANSI_NULLS, CASEINSCOMPARE, QUOTED_IDENTIFIER, EQUAL_LITERAL_REPLACEMENT, OWNER_AS_SCHEMA, TRACE, with the vendor defaults when unset | none |
| ISQL read | `GET` ISQL settings | DELIMIDENT, TRACE, FUNCTIONRETURNSSET, RESERVEDWORDPREFIX | none |
| Set | a settable row, by both callers, then restored | The row reads the new value, `readBack` matches, every other key unchanged | none |
| Read-only, unknown, bad value | as Story 21.3's matrix | 409 / 404 / 400 at mint and port | nothing sent |

## Runner rulings at the plan halt (2026-11-15, unattended)

- **Split (decide):** this story is now SQL settings only: the SQL settings with the SQL Shell tab, TSQL and ISQL, on `ConfigPort`, plus the English-interface criterion. DDL mappings are Story 21.13, the NLS configured defaults and the locale definitions editor Story 21.14, locale and table import Story 21.15 (inserted in `epics.md`, planned next in that order). The sprint key stays `21-4-nls-locales-and-sql-settings`; the title is not changed.
- **Q2 (decide):** ISQL and SQL Shell settings, which have no backing class, are written only at the fixed list of `^%SYS` entries the classic page writes; TSQL goes through `%SYSTEM.TSQL`. No caller value names a node.
- **Q3 (veto U-50):** after a confirmed write that changes one of the six keys the classic page purges for, purge every namespace's cached queries as the classic page does, and state it on screen with the sentence this plan proposes.
- **Q4 (veto U-50):** every `Config.SQL` key is listed; only the keys the classic page offers are settable; `ExtrinsicFunctions`, `QueryProcedures`, `AllowRowIDUpdate`, `ECPSync`, `IdTrxFrom`, `IdTrxTo`, `DelimitedIds`, `DefaultSchema` and the SQL Shell's `EscapeCondition`, `DisplayPath` and `DisplayFile` are read-only. Task 0 checks on `ocupilot-ci` whether `DelimitedIds` and `DefaultSchema` would break OcuPilot's own SQL and records it.

</intent-contract>

## Code Map

- `irissys/%CSP/UI/Portal/SQL/Configure/SQL.cls` -- the classic page: `RESOURCE` `%Admin_Manage` (:23); tabs SQL and SQL Shell (:57); the SQL tab's offered fields (:67-138, `Comment` hidden :67) and the SQL Shell tab's (:149-183). Classic key `%CSP.UI.Portal.SQL.Configure.SQL` (measured, slot A).
- `irislib/%CSP/UI/Portal/SQL/Utils.cls:506-640` -- `GetConfigSQLProperties` (six booleans shown inverted :511-513; shell nodes and their display mapping :516-528) and `SaveConfigSQLProperties` (the 27 `Config.SQL` keys it writes :569-597, `IgnoreRedundant` fanned to seven `DDLNo*` :569-576, the purge trigger keys :562-567, the 13 `^%SYS("sql","shell",*)` writes :606-618, the background purge :620-628).
- `irislib/%SQL/Shell.cls:341-369` -- the shell's own defaults for each node when unset (the effective value the row reads). It reads `MessageMode`; the classic page writes `MessagesMode` (vendor mismatch, Design Notes). `EscapeCondition` is `xecute`d (:371-373).
- `irislib/%SYSTEM/SQL.cls:1870` -- `PurgeQueries({"allNamespace":1})`, the supported synchronous call over `PurgeAllNamespaces^%SYS.SQLSRV` (the classic page's background task, `irislib/%CSP/UI/System/BackgroundTask.cls:967`, calls the same routine).
- `irissys/Config/SQL.cls:45-229` -- 46 properties; `Get` on slot A answered all 46 (measured). Integer limits: `LockTimeout` 0-32767, `TimePrecision` 0-9, `HNSWLIBMemoryLimit` 0-2147483647 with initial -1 ("use default", :160-166); `TODATEDefaultFormat` `MAXLEN` 32 `MINLEN` 1; `DefaultSchema` `MAXLEN` 128.
- `irissys/%CSP/UI/Portal/SQL/Configure/TSQL.cls:41-44,70-98` -- four fields, classic defaults (`DIALECT` Sybase, flags OFF). `irislib/%SYSTEM/TSQL.cls:18-230` -- getters (`GetAnsiNulls` etc. answer `"<dialect>, <flag>"`; `GetTrace`, `GetOwnerAsSchema` answer `ON`/`OFF`) and setters, which return the previous value or a string starting `Invalid`, and each flag setter rewrites `DIALECT` from its argument. Measured on slot A: `GetDialect()` empty, flags `OFF`, `EQUAL_LITERAL_REPLACEMENT` `ON`, `TRACE` and `OWNER_AS_SCHEMA` `OFF`.
- `irissys/%CSP/UI/Portal/SQL/Configure/ISQL.cls:41-44,70-96` -- four `^%SYS("xsql","informix",*)` nodes, defaults 0, 0, 1 and empty.
- Slot A holds no `^%SYS("sql","shell")`, `^%SYS("tsql")` or `^%SYS("xsql")` node (measured).
- **Model to extend:** `src/OcuPilot/Port/ConfigPort.cls` (`ENDPOINTS` :46, `VendorClass` :154, `Invoke` :171, `Collect` :275, `BuildRow` :314, `Limits`/`LimitsOf` :337/:354, `AcceptsOf` :384, `IsReadOnly` :401, `NeedsRestart` :412, `SetValue` :438, `VendorModify` :465, `SendProperties` seam :501, `Snippet` :560); `Area/OsMgmt/ConfigSettingRules.cls`; `Api/ConfigError.cls` (`SETTINGRESTART` :30 is the consequence model); `Screen/Tool/ConfigSettingSet.cls` (`READANSWERS` :44, `CONSEQUENCECODE` :59, `Consequence` :128) and its three subclasses; `Screen/Descriptor/StartupSettingList.cls` (the descriptor shape); `ui/src/app/areas/os-management/config-settings.page.ts` (`statement` :165, after-Save note :191); `core/proposal-view.ts:406`. Story 21.3's spec Code Map names every other sibling.
- `ui/tools/screen-mirror.mjs:1226` -- `configEndpoints()` parses `ConfigPort.ENDPOINTS`, so the mirror follows the parameter.
- Arming: `scripts/ci-throwaway.sh:866-871` (`OCUPILOT_ALLOW_CONFIG_SETTINGS`, `# classes: ConfigSettingWrite`).

## Tasks & Acceptance

**Execution, batch 1 (server; commit when its loop commands are green):**

- Task 0, on `ocupilot-ci`, recorded under Design Notes before code: (a) a `Config.SQL.Modify` and a write to each node family by a caller holding only `PAIRS` fails, and by one holding `WRITEPAIRS` succeeds; (b) a full-set `Config.SQL.Modify` with one key changed changes only that key and adds no `Config.CPF.PendingRestart` reason; (c) `$SYSTEM.SQL.PurgeQueries({"allNamespace":1})` by a `WRITEPAIRS` caller removes a cached query prepared in another namespace, and its duration; if it needs any pair beyond `WRITEPAIRS`, HALT `intent gap` naming it; (d) with `DelimitedIds` 0, then with `DefaultSchema` changed, each restored after: whether `smoke.sh --container ocupilot-ci` and `ConfigSettingRead` stay green (recorded only; both stay read-only); (e) whether either classic key carries a custom resource.
- `src/OcuPilot/Port/ConfigPort.cls` -- `ENDPOINTS` adds `SQL`, `SQLShell`, `TSQL`, `ISQL`. `SQL` is a `Config.*` endpoint (`VendorClass` answers `Config.SQL`; `Get`/full-set `Modify` as now). `SQLShell` and `ISQL` are node endpoints over a fixed roster parameter per endpoint (name, node, kind, display-to-stored choices, default; Design Notes); `TSQL` reads through the getters and sets through the four setters. `Collect`, `Limits`, `IsReadOnly`, `NeedsRestart` (false for all four), `SetValue`, `Snippet` branch on the endpoint's family. Every row gains `Purges` (true only for `PURGESQL`'s keys). `IsReadOnly` for `SQL` is "not in `SETTABLESQL`". After a successful `SQL` set that changes a `PURGESQL` key, `PurgeCachedQueries()` (an overridable seam) runs; its failure is logged (AD-39) and answers 500 `INTERNAL`, the setting stays changed. `LimitsOf` adds `HNSWLIBMemoryLimit` 0-2147483647 with sentinel -1.
- `src/OcuPilot/Area/OsMgmt/ConfigSettingRules.cls` -- judges node and TSQL rows from the limits the port answers for them; no other change.
- `src/OcuPilot/Api/ConfigError.cls` -- consequence `SETTINGPURGE` `CONFIG.SETTING.PURGE` with `REASONSETTINGPURGE` (the ruled sentence).
- `src/OcuPilot/Screen/Tool/ConfigSettingSet.cls` -- `READANSWERS` adds `Purges`; `Consequence` answers `CONFIG.SETTING.RESTART` for `Restart`, else `CONFIG.SETTING.PURGE` for `Purges`. New subclasses `SqlSettingSet`, `SqlShellSettingSet`, `TsqlSettingSet`, `IsqlSettingSet`, each naming its endpoint; `CLASSICPAGES` as their descriptors.
- `src/OcuPilot/Screen/Descriptor/SqlSettingList.cls`, `SqlShellSettingList.cls`, `TsqlSettingList.cls`, `IsqlSettingList.cls` -- new, on `StartupSettingList`'s shape: source `config`, endpoints above, positions 29-32, routes `os-management/sql-settings`, `sql-shell-settings`, `tsql-settings`, `isql-settings`; entity types `sql-setting`, `sql-shell-setting`, `tsql-setting`, `isql-setting`; tools `osmgmt.sqlsettings`, `osmgmt.sqlshellsettings`, `osmgmt.tsqlsettings`, `osmgmt.isqlsettings`; columns `Name`, `Value` (no `Restart`: always false); `classicPage` `%CSP.UI.Portal.SQL.Configure.SQL` (SQL and SQL Shell), `.TSQL`, `.ISQL`; pairs `%Admin_Manage:USE`, `%DB_IRISSYS:READ`.
- Add-only rows: `Kernel/Governance/Baseline.cls` (`osmgmt.sqlsettings.set`, `osmgmt.sqlshellsettings.set`, `osmgmt.tsqlsettings.set`, `osmgmt.isqlsettings.set`, each `true`); `Kernel/EntityType.cls` and `Kernel/Proposal/Prohibited.cls` (four covered types, no predicate); `Screen/Titles.cls` regenerated; `scripts/ci-throwaway.sh` (`SqlSettingWrite` on the `OCUPILOT_ALLOW_CONFIG_SETTINGS` `# classes:` line and its comment).
- `src/OcuPilot/Test/SqlSettingRead.cls` (live-safe: the four reads, the settable and read-only rosters, `Purges`, `Restart` false, shell values derived by the test from the node and its default, gate refusals, governance defaults, the read-source cases), `SqlSettingRules.cls` (live-safe, seams only: every refusal at mint and port, the TSQL dialect argument, the purge seam's call and its failure), `SqlSettingWrite.cls` (armed: below; restores each value and each node's defined state in `OnAfterOneTest` behind the `PreparedPolicyTaken` guard).
- The shared-surface tests under Verification, each to the new shape.

**Execution, batch 2 (client; commit when its loop commands are green):**

- `ui/src/app/areas/os-management/config-settings.page.ts` with its spec -- the four descriptors; the dialog's statement adds the purge sentence when `Purges` is true, and the after-Save note states it. `shell/screen-outlet.ts`, `shell/screen-action-handler.ts`, `core/screen-actions.ts` (four entries each, `set` reusing "Set value"), `core/proposal-view.ts` (`CONFIG.SETTING.PURGE` to the sentence), `core/strings.ts`, `screens.generated.ts`.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` -- the ruled strings into Fixed strings; the four screens into OS management's side-bar row (add-only).
- `ui/browser/config-settings.browser-spec.mjs` -- each new screen answers rows after the answered signal; Set value on `SaveMAC` round-trips and is restored; the dialog for `FastDistinct` states the purge sentence (canceled, nothing sent); `DefaultSchema` and `EscapeCondition` draw no Set value.

**Acceptance Criteria:**

- AC1. Given the four screens and tools on `ocupilot-ci`, when each read and each set runs through the OcuPilot API by both callers, then it round-trips over its backing source: `Config.SQL` (`SaveMAC` flipped), a shell node written with its stored code (`SelectMode` Display stores 2), a TSQL flag through `%SYSTEM.TSQL` with the stored dialect unchanged (`ANSI_NULLS` ON), and an ISQL node (`DELIMIDENT` 1); each reads back, every other key and node is unchanged, and each is restored.
- AC2. Given a set that changes `AdaptiveMode`, `AutoParallel`, `FastDistinct`, `ODBCVarcharMaxlen` or `ParameterSampling`, when it is confirmed or saved, then every namespace's cached queries are purged, and the card, the dialog and the Save answer state the purge sentence; a set of any other key purges nothing and states nothing; a purge failure answers 500 `INTERNAL` with the setting changed.
- AC3. Given a read-only row (every `Config.SQL` key outside `SETTABLESQL`, `EscapeCondition`, `DisplayPath`, `DisplayFile`, the three TSQL rows the classic page omits), when either caller sets it, then 409 `CONFIG.SETTING.READONLY` before any vendor call or node write, and the screen offers no Set value; a name outside the roster is 404 and no node is named by it.
- AC4. Given the default baseline, when the agent proposes any of the four sets, then it mints and the confirm writes once with one audit marker and a `readBack`; with the key `false` the governance gate refuses it.
- AC5. Given these settings configure the server's SQL rather than OcuPilot's own interface, when the four screens render, then every label, Accepts line and consequence is an English `strings.ts` value, pinned equal to its `ConfigError` sentence.

### Review Findings

- [ ] [Smoke] `SqlSettingWrite.TestAChangedPurgeKeyPurgesEveryNamespaceAndAnotherKeyPurgesNothing` is order-dependent: it is red on CI run 43748408456's instance shard 2/8 and on the runner's local sweep shard 9/20, where it ran right after `SqlDataRoutes` (and `Secret`), and green alone and on a fresh instance. Failing asserts: +7 (the screen's change of `ParameterSampling` did not purge the other namespace's cached query: `Cached()` not 0) and +11 (the agent's confirmed change likewise). Find the cause on `ocupilot-ci` by running `SqlDataRoutes` then `SqlSettingWrite`, one call each; fix the product if the purge is really skipped (for example the after-write purge's 'value differs' check reading a stale or already-changed value), or make the test create and assert on its own state if the test is what depends on another class's leftovers. Name the cause, `(inference)` where unproved; then `SqlDataRoutes` then `SqlSettingWrite` green, and `SqlSettingWrite` alone green.

Code review 2026-11-15 (full-opus; four layers): 38 rows grouped into 24 entries (1 high, 1 medium, 20 low, 1 false, 1 maybe-false); 6 patched, 5 ledgered, 13 rejected.

- [x] [Review][Patch] (high) A confirmed agent write whose purge failed got no AD-15 marker, and `SqlSettingWrite` was red: the purge moved out of `SetValue` into `ConfigSettingSet.AfterWrite` -> `ConfigPort.PurgeAfterSet` (gated, re-reads, purges when changed, 500 `INTERNAL` on failure) [src/OcuPilot/Port/ConfigPort.cls, src/OcuPilot/Screen/Tool/ConfigSettingSet.cls]
- [x] [Review][Patch] (low) The script showed a purge for any purge key, and the TSQL setter lookup was copied: the purge is the tool's `SnippetAfter`, only when the draft's diff changes `Value`; `TsqlSetter` shared [src/OcuPilot/Port/ConfigPort.cls]
- [x] [Review][Patch] (low) The browser `after` hook could skip the `SaveMAC` restore [ui/browser/config-settings.browser-spec.mjs]
- [x] [Review][Patch] (low) The refused-set test sent new values to read-only keys: each is sent its current value [src/OcuPilot/Test/SqlSettingWrite.cls]
- [x] [Review][Patch] (low) Doc comments in `SqlSettingList`, `TsqlSettingList` and `SqlSettingRead.ShellStored` [src/OcuPilot/Screen/Descriptor, src/OcuPilot/Test/SqlSettingRead.cls]
- [x] [Review][Patch] (low) The TSQL and SQL Shell tool descriptions said a boolean takes 1 or 0 [src/OcuPilot/Screen/Tool/TsqlSettingSet.cls, SqlShellSettingSet.cls]
- [x] [Review][Defer] (medium) An applied write whose after-write step fails answers an error, so no change event and a stale row (shared kernel and handler) — DW-2601, routed burndown
- [x] [Review][Defer] (low) Choice settings take free text in the dialog — DW-2602, wontfix-accepted
- [x] [Review][Defer] (low) Config-source validation text names three families (contended files) — DW-2603, wontfix-accepted
- [x] [Review][Defer] (low) EXPERIENCE.md 21.4 clause separator (contended line) — DW-2604, wontfix-accepted
- [x] [Review][Defer] (low) Empty `TODATEDefaultFormat` vendor refusal not driven through a real `Modify` — DW-2605, wontfix-accepted

Rejected:

- (low) A retry of the same value does not purge again after a failed purge: `PurgeQueries` fails only by a thrown error, and a retry path adds a branch.
- (low) The client decides the purge note from the dialog's value, so a concurrent change can mislead it: concurrent edits only; the server decides the purge.
- (low) A TSQL flag set stores `DIALECT` Sybase, and AC1's wording: ruled U-51; a wording fix edits the spec.
- (low) The dialect read and the flag setter can race: theoretical, two writers on `^%SYS("tsql")` at once.
- (false) `RosterLine` reads an undefined setter: only settable entries render, and each has one (the shared helper now guards it anyway).
- (low) `MessagesMode` has no effect in the shell: ruled Q2.
- (low) A partial purge reads as success: vendor behavior inside `PurgeAllNamespaces`.
- (low) The script reads the stored dialect with no gate: the mint already gated the caller and the dialect is not sensitive.
- (low) A read-only SQL key renders a script outside the mint: unreachable, the mint refuses first.
- (low) The script does not check `tSC` between lines: the copy-out style of every 21.3 script.
- (low) Free-text shell and ISQL nodes get no vendor check: the classic page writes them as-is (Q2).
- (maybe-false) `HNSWLIBMemoryLimit` -1 may not land: would be low; a real `Modify` of -1 would settle it.
- (low) Spec record, matrix and deferred list are stale: the fix edits the spec under review.

## Spec Change Log

- 2026-11-15, rework 1 (lead): re-opened for an order-dependent red in the purge test (CI and the local sweep).

- 2026-11-15 (lead): plan halt ruled (split, Q2-Q4); status reset to draft for re-plan.
- 2026-11-15 (re-plan): the intent matrix's `Config.SQL` key count corrected from 47 to 46 (re-measured on slot A: `Get` answers 46 keys, the class declares 46).

## Review Triage Log

### 2026-11-15 — Review pass

- verdicts: 15 findings — high 0, medium 2, low 10, false 1, maybe-false 2
- findings:
  - `[medium]` `[patch]` SqlSettingWrite's "every other node reads as before" compared against a snapshot the teardown had just restored, so it could not fail — added a per-set fingerprint of every other node (`Nodes(pSkip)`) in `RoundTrip` after the screen's and the agent's set; a sibling-node write in the ISQL branch turns `TestASetRoundTripsOverEachBackingSourceOnBothCallers` red, reverted and reloaded.
  - `[low]` `[patch]` Page spec had no case for a Save that sends the purging key's current value, so a false purge sentence could ship — added `states no purge sentence after a Save that sends the value the purging setting already holds`; dropping `&& value !== target.current` turns it red, reverted.
  - `[medium]` `[defer]` A failed purge is tested only at the port — deferred (maybe-false at the callers; needs a seam-backed confirm fixture).
  - `[low]` `[patch]` Browser cancel test never changed the value, so a spurious send of the unchanged value stayed green — the dialog's value is toggled before Cancel; spec green on the redeployed bundle.
  - `[low]` `[defer]` The real `SendTsql` refusal prefix is untested — unreachable through the rules; deferred.
  - `[low]` `[patch]` The last purge assertion lacked a `tPrepared > 0` guard — guard added.
  - `[low]` `[reject]` `SqlSettingRead.TsqlShown` restates `ConfigPort.TsqlValue` — the armed round trip reads independently; not worth the added structure.
  - `[false]` `[reject]` `RosterEntry` reads past the list after the loop falls through — measured on `ocupilot-ci`: an unknown name answers `""` and a known one its entry.
  - `[maybe-false]` `[reject]` Self-protection (inference) rests on a grep; 25 non-test classes use SQL — the settable keys concern DDL, `TO_DATE`/`GETDATE`, TSQL and the shell; a grep for those outside `Test/` finds only `ConfigPort`, `SqlPort` and one descriptor; low if true.
  - `[maybe-false]` `[reject]` Shell rows read the system defaults, not a user's own shell list — the classic page writes the same nodes (ruled, Q2); low if true.
  - `[low]` `[reject]` `MessagesMode` is written where the classic page writes it, though the shell reads `MessageMode` — ruled (Q2's fixed list).
  - `[low]` `[reject]` The TSQL first-flag dialect side effect is not stated on screen — ruled kept (U-51); no new string.
  - `[low]` `[reject]` `PURGESQL` lists `DefaultSchema`, which can never fire — as ruled; AC2 names five keys.
  - `[low]` `[reject]` Browser spec sets no shell, TSQL or ISQL value — `SqlSettingWrite` covers both callers on every family.
  - `[low]` `[reject]` No mutation names the browser-visible Save note — the page spec's mutation lines cover the note and the dialog sentence.

## Design Notes

**Governing ADs:** AD-4 (full-set `Modify`, as Story 21.3 measured and the runner ruled; one node per shell or ISQL setting, so no omitted key), AD-6, AD-34, AD-15, AD-14, AD-10 (four covered types, no predicate), AD-16, AD-21 (`DisplayPath`, `DisplayFile` never set; the shell's `Path` is a schema search path, not a file path), AD-22 (keys `true`; a person's set is not governed), AD-29, AD-35 (every listed key rechecked by name and type: none holds a credential), AD-36, AD-39, AD-44, AD-52, AD-53, AD-56, AD-58, AD-59 (each family's snippet: `Get`/`Modify` plus the purge line for a purge key; `Set ^%SYS(...)` with literal subscripts; `$SYSTEM.TSQL.Set*`).

**Settable sets (Q4).** `SETTABLESQL`, the classic page's offered keys less `DefaultSchema`: `AdaptiveMode`, `AutoParallel`, `AutoStatsForEfficientSamplingTableOnly`, `AutoStatsForFixedStatsTable`, `AutoStatsForRemoteGlobalTable`, `ClientMaxIdleTime`, `DDLNo30`, `DDLNo201`, `DDLNo307`, `DDLNo311`, `DDLNo315`, `DDLNo324`, `DDLNo333`, `DisableNLSCollationMismatchLogging`, `FastDistinct`, `HNSWLIBMemoryLimit`, `IdKey`, `LockThreshold`, `LockTimeout`, `ODBCVarcharMaxlen`, `ParameterSampling`, `SaveMAC`, `TCPKeepAlive`, `TimePrecision`, `TODATEDefaultFormat` (25). An allow-list, so a key a later build adds is read-only until named. Shell: all 13 nodes but `EscapeCondition` (evaluated code), `DisplayPath`, `DisplayFile` (paths). TSQL: `DIALECT`, `ANSI_NULLS`, `CASEINSCOMPARE`, `QUOTED_IDENTIFIER`. ISQL: all four.

**Self-protection.** Product code runs no DDL, no `TO_DATE`/`GETDATE`, and no SQL DML on its own tables, and does not use `%SQL.Shell`, TSQL or ISQL (grep of `src/OcuPilot` outside `Test/`), so no settable key reaches OcuPilot's own SQL (inference). `DelimitedIds` and `DefaultSchema` could (inference: a double-quoted identifier becomes a literal; an unqualified name resolves elsewhere), so they are read-only by Q4; Task 0 (d) records whether they would. No setting here cuts OcuPilot off: none is a network or service setting.

**Decided in-stage:**

- Four screens, not tabs: the SQL Shell tab is its own screen beside SQL, sharing the classic page key, as other descriptors share one (OS management positions 29-32, after 21.3's 26-28).
- Rows show each key as stored under its vendor name; the classic page's six inverted checkboxes are not inverted here.
- Each `DDLNo*` key is its own settable row; the classic page's one `IgnoreRedundant` box sets all seven alike.
- `Comment` is read-only: the classic page hides its box (`SQL.cls:67`), so it is not offered (Q4).
- The three TSQL rows the classic page omits are listed read-only, by Q4's rule.
- Shell rows read the shell's own default when a node is unset (`%SQL.Shell:355-369`), and choices use the classic page's names: `SelectMode` Logical/ODBC/Display = 0/1/2; `ColAlign` Delimiter/Header/Data = 0/1/2; `DisplayMode` CURRENTDEVICE/XML/HTML/PDF/TXT/CSV = -1/0/1/2/99/100; `EchoMode`, `MessagesMode` On/Off = 1/0; `ExecuteMode` Immediate/Deferred = 1/0; `Dialect` IRIS/MSSQL/Sybase stored as named. `MessagesMode` is written where the classic page writes it, although the shell reads `MessageMode` (Q2's fixed list).
- TSQL rows read the getters' answers (flag after `", "`); an unset `DIALECT` reads empty. A flag set passes the stored dialect, or `Sybase` when none is stored, as the classic page saves its shown default; so the first flag set on such an instance also stores `DIALECT` Sybase, which `%TSQL.Manager` already assumes when unset (`:42`). A setter answer starting `Invalid` is a vendor refusal, 400 `CONFIG.SETTING.VALUE`, logged.
- ISQL rows read the classic page's defaults when unset (0, 0, 1, empty).
- The purge runs in the write's own request through `PurgeQueries`, not a background job, and only when the value changes, as the classic page purges; `DefaultSchema` is in `PURGESQL` but never set.
- `HNSWLIBMemoryLimit` accepts -1 beside its range; its Accepts line states the range alone, as 21.3 does for `bbsiz`.
- No restart: no vendor source or classic page states one for these settings; `Restart` is false on all four.
- One armed write class under 21.3's variable, so the arming roster gains a class, not a variable.

**Strings, escalated for the spec gate's ruling** (reuse: "Setting", "Value", "Set value", "No settings to show.", 21.3's Accepts and refusal sentences):

- Admitted by Q3, proposed: `CONFIG.SETTING.PURGE` "Changing this setting purges the cached queries in every namespace."
- New, not decided in-stage: titles "SQL settings" · "SQL Shell settings" · "TSQL settings" · "ISQL settings"; entity nouns "SQL setting" · "SQL Shell setting" · "TSQL setting" · "ISQL setting"; empty-agent phrases "change a SQL setting" · "change a SQL Shell setting" · "change a TSQL setting" · "change an ISQL setting"; prompts "Which SQL settings purge the cached queries when they change?" · "What does LockThreshold control?" · "Which SQL settings are shown and never changed here?" · "Which settings does the SQL Shell start with?" · "What does the SQL Shell's SelectMode change?" · "What does ExecuteMode do in the SQL Shell?" · "Which TSQL dialect does this instance use?" · "What does ANSI_NULLS change for TSQL?" · "What does QUOTED_IDENTIFIER control?" · "What does DELIMIDENT change?" · "What does RESERVEDWORDPREFIX do?" · "Which ISQL settings are on?".

**Extend, don't copy (Rule 2/31):** extends `ConfigPort`, `ConfigSettingRules`, `ConfigError`, `ConfigSettingSet` and `config-settings.page.ts`; four tool subclasses and four descriptors on 21.3's siblings; tests follow `ConfigSettingRead`/`Rules`/`Write`, as new classes because each 21.3 class is near the 500-line guide.

**Integration ACs:** `ConfigPort`'s new endpoints are consumed in this story by their four descriptors and four set tools (AD-53's two callers); AC1-AC4 observe them through the API and the browser. **Consumed-by:** none known. **Consumes:** Story 21.3's `ConfigPort`, rules, error, set-tool and page siblings; `Screen.Gate`, `Kernel.Fault`, `Screen/Tool/Write`.

**Ledger inbox:** none.

**Contended paths:** `origin/OCU-1-epic24` has no commit on any file named here beyond the feature branch; its worktree holds uncommitted edits to `EXPERIENCE.md`, `ci-throwaway.sh`, `Baseline.cls`, `Prohibited.cls`, `proposal-view.ts` and `screen-actions.ts`, so this story's edits there are add-only rows (checked at plan time). `OCU-1-epic22` has no remote branch.

**Measurements (read-only, slot A, 2026-11-15):** `Config.SQL.Get` 46 keys; the three `%SYS.Portal.Resources.NormalizePage` keys as spelled above; the TSQL getters as in the Code Map; no shell, TSQL or ISQL node stored. Nothing ran against `ocupilot-ci`.

**Task 0, measured on `ocupilot-ci` (implement, 2026-11-15), every probed setting restored and confirmed:**

- A `Config.SQL.Modify`, `%SYSTEM.TSQL.SetAnsiNulls` and a write to `^%SYS("sql","shell")` and to `^%SYS("xsql","informix")` by a caller holding `%Admin_Manage:USE` and `%DB_IRISSYS:READ` alone each fail `<PROTECT>`; the same caller with `%DB_IRISSYS:WRITE` succeeds in all four. So `WRITEPAIRS` is the write set for every family.
- A full-set `Modify` (46 keys, one changed) changed exactly that key in three trials (`SaveMAC` 0, 1, 0), and `Config.CPF.PendingRestart` reported the same four earlier `errlog` reasons before and after: the unchanged keys, `Comment` included, are untouched and no reason is added. A `Modify` of `HNSWLIBMemoryLimit` -1 and a refused `TODATEDefaultFormat` "" (`MINLEN` 1) and `LockThreshold` -5 changed nothing.
- `$SYSTEM.SQL.PurgeQueries({"allNamespace":1})` removed the cached queries of another namespace (`USER` 54 to 0, `HSCUSTOM` 153 to 1) in 0.08 s for a caller holding the read pairs only, and again (1 to 0 in `USER`, 0.002 s) for a `WRITEPAIRS` caller. It needs no pair beyond `WRITEPAIRS`.
- With `DelimitedIds` 0, and then with `DefaultSchema` changed, `smoke.sh --container ocupilot-ci` read 50 of 50 and `ConfigSettingRead` read 9 of 9 each time. Both stay read-only by Q4.
- `%CSP.UI.Portal.SQL.Configure.SQL`, `.TSQL` and `.ISQL` each answered as spelled from `NormalizePage`, with no custom resource. No shell, TSQL or ISQL node was stored before or after.
- A `%SYSTEM.TSQL` flag setter rewrites `DIALECT` from its argument, so with none stored the first flag set stores `Sybase` (the Design Notes' ruling, observed in `SqlSettingWrite`).

**Decided in-stage (implement):**

- The shell, ISQL and TSQL rosters are parameters of `ConfigPort` (`SHELLROSTER`, `ISQLROSTER`, `TSQLROSTER`): name, kind, shown=stored choices or length, stored default, settable. A node reads `$Get(node, default)`, so a text node cleared to empty reads back empty.
- Four seams beside `SendProperties`: `SendNode`, `SendTsql`, `StoredDialect` and `PurgeCachedQueries`; `ConfigGateSeam` records them. A choice is converted to its stored code before `SendNode`, so the live-safe class pins the code.
- Every port row carries `Purges`; the three 21.3 descriptors declare no `Purges` field, so their list rows do not, and `ConfigSettingRead` strips it before comparing a `GET` with a list row. The four new descriptors declare it.
- A TSQL, shell or ISQL set renders a script only for a settable roster name; `DraftRegistry`'s target-id roster names one setting for each of the three types.
- The empty `TODATEDefaultFormat` is judged by the vendor (400 `CONFIG.SETTING.VALUE`, logged), as the plan rules the vendor's own limits.

**Runner ruling at the spec gate (2026-11-15):** the strings escalated above and the TSQL dialect side effect are kept as planned (veto U-51).

## Verification

**Shared surfaces:** OS management roster and positions (`Navigation.cls:539` 60 and :549; `WireSecurityRead.cls:623-633`; `WireAreaAnyScreen.cls:271`; `LanguageServerWire.cls:298`; `ui/tools/navigation.test.mjs:250-252,517-519`; `Descriptor.cls:80-82`; `StageTwoTools.cls:141-143`; `ui/tools/screen-mirror.test.mjs:2743`), the tool registry (`ReadTool.cls:93` 431 and :94; `ToolWrite.cls:1326` 69; `ToolRoundTrip.cls:102`; `ReadDescriptions.cls:43` "Configuration settings"), entity types (`Descriptor.cls:1829` 82; `Prohibited.cls:233`), the `config` row shape and endpoint roster (`ConfigSettingRead.cls:300-348`, `ConfigSettingRules`, `ConfigSettingMint`, `ConfigSettingWrite`), `PortGate`, `ClassicPageGate.cls:76`, `MappingDescriptor.cls:24`, `SurfaceCoverage.cls:277-282`, `GovernanceBaseline`, `proposal-view.test.mjs:1166`, `ci-throwaway.sh`'s arming roster (`ui/tools/ci.test.mjs`), `TeardownGuard`. The implement stage greps `ui/browser`, `ui/tools`, the `ui/src` specs and `src/OcuPilot/Test` for each; every test it changes joins `(loop)`.
*Every test added or changed passes on a fresh environment, in either order.* Each set test restores the value and the node's defined state it found.

**Commands.** One per foreground call, `timeout: 600000`, against `ocupilot-ci` only; never two test calls in one message.

- `(loop)` `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/4667058b-f052-49c9-b08a-221f7f41dfab/scratchpad/e21u/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` -- expected: `LOADERRORS=0`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.SqlSettingRead`, one class per call, then each of `SqlSettingRules`, `SqlSettingWrite`, `ConfigSettingRead`, `ConfigSettingRules`, `ConfigSettingMint`, `ConfigSettingWrite`, `PortGate`, `SurfaceCoverage`, `GovernanceBaseline`, `Governance`, `Prohibited`, `ReadTool`, `ReadDescriptions`, `ToolEmit`, `ToolDispatch`, `ToolRoundTrip`, `ToolWrite`, `Descriptor`, `Navigation`, `ClassicPageGate`, `MappingDescriptor`, `DraftRegistry`, `StageTwoTools`, `Wire`, `WireAreaAnyScreen`, `WireSecurityRead`, `LanguageServerWire`, `TeardownGuard` -- expected: green.
- `(loop)` `uv run scripts/check-objectscript.py`, `uv run scripts/test_check_objectscript.py`, `bash scripts/lint-docs.sh` -- expected: clean.
- `(loop)` `cd ui && node --test tools/config-settings.test.mjs` and every `ui/tools` test the shared-surface sweep changes -- expected: green.
- `(loop)` `cd ui && npm run build` and `npm run test:components`; redeploy with `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`; then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/config-settings.browser-spec.mjs` -- expected: green.
- `(once)` `cd ui && npm run test:tools` -- expected: green.
- `(once)`, runner-owned: the full ObjectScript sweep one class per call, `smoke.sh --container ocupilot-ci`, and Rule 30's fresh check. The full browser suite is left to CI.

**Mutations (Rule 19), one per AC, each applied, observed red, reverted (byte-identical by `cmp`) and the reverted source reloaded into `ocupilot-ci`:**

- AC1: mutation: the shell roster maps `Display` to 1 -> `SqlSettingWrite` red on the stored-code assertion (also `SqlSettingRules`, three tests); mutation: the ISQL node write also writes `TRACE` -> `SqlSettingWrite` red on the round trip's other-nodes assertion; mutation: the TSQL flag set passes `MSSQL` regardless of the stored dialect -> `SqlSettingRules` red on the stored-dialect test.
- AC2: mutation: `PURGESQL` loses `ParameterSampling` -> `SqlSettingRules`, `SqlSettingWrite` and `SqlSettingRead` red; mutation: the page omits the purge sentence from the dialog's statement, or never sets the after-Save note -> `config-settings.page.spec.ts` red, one test each; mutation: the after-Save note drops `value !== target.current` -> the no-op Save test red.
- AC3: mutation: `SETTABLESQL` gains `DefaultSchema` -> `SqlSettingRead` and `SqlSettingRules` red (never run against `SqlSettingWrite`).
- AC4: mutation: `osmgmt.sqlsettings.set` `false` in `Baseline` -> `SqlSettingRead` red; `osmgmt.isqlsettings.set` `false` -> `SqlSettingWrite` red on two tests.
- AC5: mutation: one word of the purge sentence changed in `strings.ts` -> `config-settings.test.mjs` red.
- Also observed red: `Consequence` without the purge code -> `SqlSettingRules`; `SHELLROSTER` without `Path` -> `SqlSettingRead`; `Admit` answering OK -> `SqlSettingRead`; `IsqlSettingSet` without `CLASSICPAGES` -> `SqlSettingRead`; `NOTFOUND` answered 400 -> `SqlSettingWrite`; a descriptor dropped from the page's served lists -> `config-settings.page.spec.ts`; the purge consequence dropped from `consequenceSentence` -> `proposal-view.test.mjs`.

**QA pass (files and mutations):**

- (QA) `src/OcuPilot/Test/SqlSettingWrite.cls` (three tests added), `src/OcuPilot/Test/SeamSqlSettingSet.cls`, `src/OcuPilot/Test/SeamSqlActionFixture.cls`; `src/OcuPilot/Test/ConfigGateSeam.cls` gained `WriteThrough`.
- mutation: `TSQLREFUSAL` reads `Invalidx` -> `SqlSettingWrite.TestAVendorRefusalOfAnAdmittedTsqlValueIsAValueRefusalOnBothCallers` red (AC3).
- (review) mutation: `SetValue` runs `PurgeAfterSet` itself, as part of the write -> `SqlSettingWrite.TestAFailedPurgeStillMarksTheAgentsWrite` red (AC2, AC4, AD-15), run 871.
- (review) mutation: `PurgeAfterSet` answers OK after a failed purge -> `SqlSettingRules.TestAChangedPurgeKeyPurgesOnceAndAFailedPurgeIsInternal` red (AC2), run 872.
- (review) mutation: `PURGESQL` loses `ParameterSampling` -> `SqlSettingRules.TestAChangedPurgeKeyPurgesOnceAndAFailedPurgeIsInternal` red (AC2), run 873; the AC2 line above it stands for the rewritten test.

## Auto Run Result

Status: done
Blocking condition: none

Review pass: 15 findings; patched 1 medium and 3 low, deferred 2 (one medium unverified, one low), rejected 9 with reasons in the Review Triage Log. Follow-up review recommended: false (one medium patched).

Patches after review, verified on `ocupilot-ci`: `reload.sh` `LOADERRORS=0`; `SqlSettingWrite` green (4); the page spec green (14); `config-settings.browser-spec.mjs` green (7) on the rebuilt, redeployed bundle; `check-objectscript.py`, `lint-docs.sh` clean; `npm run test:tools` 2288 green; two mutations red and reverted byte-identical.

This pass: `ConfigPort` gained the `SQL`, `SQLShell`, `TSQL` and `ISQL` endpoints, `Purges` on every row and the four seams; `ConfigError` the purge consequence; `ConfigSettingSet` the purge code and four subclasses; four descriptors, four tools' governance keys, entity types and `Prohibited` rows; the page, strings, action tables, `EXPERIENCE.md` and the arming comment. Verified on `ocupilot-ci`: the loop commands in Verification, one class per call (all green), `check-objectscript.py` and its harness, `lint-docs.sh`, `npm run build`, `npm run test:components` (3460), `config-settings.browser-spec.mjs` (7) and `npm run test:tools` (2288); the mutations above.
