---
title: 'Story 21.4: NLS locales and SQL settings'
type: 'feature'
created: '2026-11-15'
status: 'draft'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['multiple-goals', 'oversized']
deferred: []
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
| SQL read | `GET` SQL settings | One row per `Config.SQL.Get` key (47 on slot A), each `Name`, `Value`, `Kind`, `Accepts`, `Restart`, `ReadOnly` | none |
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

Backing classes and classic pages for every leaf the epic AC names (measured or read at plan time):

- SQL: `irissys/%CSP/UI/Portal/SQL/Configure/SQL.cls` (`RESOURCE` `%Admin_Manage` :23; two tabs, SQL and SQL Shell :57; `SaveData` :328) -> `irislib/%CSP/UI/Portal/SQL/Utils.cls:506-640`: `Config.SQL.Get`/`Modify` with six booleans shown inverted (:511-513, :552-557), `IgnoreRedundant` fanned out to seven `DDLNo*` keys (:569-576), and a purge of all cached queries in every namespace when `DefaultSchema`, `AdaptiveMode`, `FastDistinct`, `AutoParallel`, `ODBCVarcharMaxlen` or `ParameterSampling` changes (:562-567, :621-628, `%CSP.UI.System.BackgroundTask.PurgeAllCachedQueries` :967). `Config.SQL` (`irissys/Config/SQL.cls:45-229`) is a `Config.*` single-section class, the `ConfigPort` shape exactly; `Get` on slot A answered 47 keys (measured, read-only).
- SQL Shell: no class. The classic page writes `^%SYS("sql","shell",<Name>)` (`Utils.cls:606-619`), read by `%SQL.Shell` (`irislib/%SQL/Shell.cls:355-369`). `EscapeCondition` is an ObjectScript condition the shell evaluates, `DisplayPath` and `DisplayFile` are paths.
- TSQL: `irissys/%CSP/UI/Portal/SQL/Configure/TSQL.cls:68-83` writes `^%SYS("tsql",...)` directly; the vendor API is `%SYSTEM.TSQL` (`irislib/%SYSTEM/TSQL.cls:18-230`, `Get*`/`Set*` per setting; each dialect-taking setter also rewrites `DIALECT`). `GetDialect()` answered empty on slot A (measured).
- ISQL: no class. `irissys/%CSP/UI/Portal/SQL/Configure/ISQL.cls:66-79` writes four `^%SYS("xsql","informix",...)` nodes; no other exported class or routine names them (grep of `irislib`/`irissys`).
- DDL mappings: `Config.SqlSysDatatypes`, `Config.SqlUserDatatypes` (`irissys/Config/SqlSysDatatypes.cls:35,76`, `SqlUserDatatypes.cls:54,90`; `List` query `Name,Datatype,Comments`), classic `%CSP.UI.Portal.Config.SQLDataTypes` (list with Delete, `?Subject=SystemDataTypes|UserDataTypes`) and `.SQLDataType` (edit). A named-entry list with create, edit and delete: a different shape from a settings table.
- NLS configured defaults: `irissys/%CSP/UI/Portal/NLSConfigDefs.cls:102-215`, display only, from `Config.NLS.Locales.OpenCurrent()` and `%SYS.NLS.Table("Config")` (`irissys/%SYS/NLS/Table.cls:80-123`, 19 categories, setters `Internal`), plus `^SYS("NLS","Config","LocaleFormat")`.
- Locale definitions: `irissys/%CSP/UI/Portal/NLS.cls` (list, Properties, Validate, Copy, Export, Install, Load Table, Delete, the locale-format toggle; :480-660) and the properties editor `NLSEdit.cls` (seven save groups and I/O table add and remove, :821-960), over `Config.NLS.Locales` (`irissys/Config/NLS/Locales.cls:282-657`) and `Config.NLS.Tables`. `Install` makes the locale current and can change IRISTEMP's default collation (`NLS.cls:611-630`).
- Import: `irissys/%CSP/UI/Portal/NLSImport.cls:125-170`, a server file path ending `.xml` or `.goq` to `Config.NLS.Locales.ImportAll`/`ImportLegacy`. Export (`NLS.cls:559-575`) writes a caller-named file.
- Model to extend: `src/OcuPilot/Port/ConfigPort.cls` (`ENDPOINTS` :46, `VendorClass` :154, `Collect` :275, `LimitsOf` :354, `IsReadOnly` :401, `NeedsRestart` :412, `VendorModify` :465); Story 21.3's spec Code Map for every other sibling and shared surface.

## Tasks & Acceptance

Not planned: the story is held for the split ruling below. Once ruled, the re-plan writes the tasks for 21.4's share from the Code Map above and Story 21.3's task list, which it follows file for file.

## Spec Change Log

- 2026-11-15 (lead): plan halt ruled (split, Q2-Q4); status reset to draft for re-plan.

## Review Triage Log

## Design Notes

**Why this halts (size).** The epic AC covers eight classic leaves over at least nine backing sources of four shapes: settings tables (`Config.SQL`, SQL Shell nodes, `%SYSTEM.TSQL`, ISQL nodes, NLS configured defaults), named-entry lists with create, edit and delete (two DDL mapping classes, locale definitions), a seven-section locale editor with install, validate, copy, load and delete, and file import and export. Story 21.3 built three settings tables on one shape and changed about 40 files. This story is several times that, against the plan rules' guide of about 8 tools or 15 files.

**Proposed split (recommended), siblings numbered after Epic 21's highest story, 21.12, and planned next in order:**

- **21.4, SQL settings** (keeps its key; a retitle is the runner's choice and changes the key under Rule 5): the SQL, TSQL and ISQL settings, including the classic SQL page's SQL Shell tab; four settings-table endpoints on `ConfigPort`. Takes the first AC's "SQL, TSQL, ISQL ... settings" and the second AC (English interface).
- **21.13, DDL mappings:** system and user DDL mappings over `Config.SqlSysDatatypes` and `Config.SqlUserDatatypes`: list, create, edit, delete (delete destructive, disabled by default). Takes "DDL-mapping settings".
- **21.14, NLS configured defaults and locale definitions:** the configured-defaults table and the locale list with properties, validate, copy, install, load table and delete. Takes "NLS configured defaults, the locale definitions editor" and the second AC.
- **21.15, Locale and table import:** import (and the locale export the definitions page offers), which needs an AD-21 ruling on how a caller names a file. Takes "locale and table import" and the second AC.

**Questions for the runner (each with a recommendation):**

- Q1, split: A (recommended) the four-way split above; B two-way (SQL and DDL in 21.4, NLS in one sibling), which still exceeds the size guide.
- Q2, no backing class for ISQL and SQL Shell: A (recommended) the port writes the fixed roster of `^%SYS` nodes the classic page writes, named in a parameter, never a caller subscript; TSQL goes through `%SYSTEM.TSQL`'s setters. B leave ISQL and SQL Shell read-only.
- Q3, cached-query purge: the classic page purges every namespace's cached queries after six of the SQL keys change. A (recommended) the confirmed write does the same through the vendor purge, and the answer states it in a new string for the gate to rule; B no purge, a stated consequence only.
- Q4, settable set (stricter posture, veto window): A (recommended) list every `Config.SQL` key and settable only those the classic page sets. `ExtrinsicFunctions`, `QueryProcedures`, `AllowRowIDUpdate`, `ECPSync`, `IdTrxFrom` and `IdTrxTo` stay read-only, because the classic page never offers them and the first two widen what SQL may run. `DelimitedIds` and `DefaultSchema` are read-only too, because either could break OcuPilot's own SQL (inference; Task 0 probes it on the throwaway by checking whether OcuPilot's compiled queries use quoted identifiers or unqualified names). The SQL Shell's `EscapeCondition` (evaluated code), `DisplayPath` and `DisplayFile` (paths, AD-21) are read-only.
- For 21.14 (recorded now, ruled at its plan): `Install` and the configured defaults for `Process`, `CSP` and `Collation` can change how OcuPilot's own process reads, writes or collates (inference); recommend that `Install` ship as a destructive key disabled by default behind the typed confirm, and that those configured defaults be read-only.

**Governing ADs (for 21.4's share):** AD-4, AD-6, AD-10, AD-14, AD-15, AD-16, AD-21, AD-22, AD-29, AD-34, AD-35 (no `Config.SQL` key holds a credential; checked by name and type at plan time), AD-36, AD-39, AD-44, AD-52, AD-53, AD-56, AD-58, AD-59.

**Extend, don't copy (Rule 2/31):** 21.4 extends `ConfigPort`, `ConfigSettingRules`, `ConfigError`, the abstract `ConfigSettingSet` and `config-settings.page.ts` with new endpoints and descriptors; no new port.

**Integration ACs:** `ConfigPort`'s new endpoints are consumed by their own descriptors and set tools (AD-53's two callers). **Consumed-by:** none known. **Consumes:** Story 21.3's `ConfigPort` and its set-tool and page siblings.

**Shared surfaces (for the re-plan):** Story 21.3's Verification list (OS management roster and positions, tool registry counts, entity types, read-source kinds, `PortGate`, `ClassicPageGate`, `SurfaceCoverage`, `proposal-view.test.mjs`, `ci-throwaway.sh` arming roster, `TeardownGuard`), plus `WireSecurityRead`, `LanguageServerWire`, `language-servers.browser-spec.mjs`, `Navigation` and `Descriptor`. The re-plan re-derives each line number.

**Ledger inbox:** none.

**Contended paths:** not checked at this plan; the re-plan checks them before naming files.

**Context cache:** `epic-21-context.md` reused as the runner directed, although `epics.md` and `EXPERIENCE.md` are newer than it.

## Verification

Not planned (held for the ruling). The re-plan follows Story 21.3's Verification shape: `(loop)` the story's own classes and every shared-surface class on `ocupilot-ci`, one per call; `(once)` `npm run test:tools`; the full ObjectScript sweep is the runner's; the full browser suite is CI's.

## Auto Run Result

Status: blocked
Blocking condition: intent gap -- Story 21.4 is too large for one implement pass (eight classic leaves over at least nine backing sources of four shapes: settings tables, named-entry lists with create and delete, a locale editor with install, and file import and export). Recommended split: 21.4 SQL settings (SQL with its SQL Shell tab, TSQL, ISQL, on ConfigPort; first AC's SQL/TSQL/ISQL part plus the English AC); 21.13 DDL mappings; 21.14 NLS configured defaults and locale definitions; 21.15 locale and table import (needs an AD-21 file-naming ruling). Also asked, with recommendations under Design Notes: Q2 ISQL and SQL Shell have no backing class (write the fixed roster of the classic page's ^%SYS nodes); Q3 the classic cached-query purge after six SQL keys change (do the same and state it); Q4 the settable set (classic page's set only; ExtrinsicFunctions, QueryProcedures, AllowRowIDUpdate, ECPSync, IdTrxFrom, IdTrxTo, DelimitedIds, DefaultSchema, EscapeCondition, DisplayPath and DisplayFile read-only).

Investigation is recorded in the Code Map. Probes were read-only on slot A (`Config.SQL.Get`, `%SYSTEM.TSQL.GetDialect`); nothing ran against `ocupilot-ci`.
