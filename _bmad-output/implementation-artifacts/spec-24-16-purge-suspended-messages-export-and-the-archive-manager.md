---
title: 'Story 24.16: Purge, suspended messages, export and the archive manager (Batch 1: purge and its settings)'
type: 'feature'
created: '2026-11-22'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
owned_ledger: ''
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-15-credentials-default-settings-and-schedules-4.md'
warnings: ['oversized', 'multiple-goals']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Interoperability has no OcuPilot screen or tool for the classic Purge Data Settings and Purge Management Data pages (`EnsPortal.PurgeSettings`, `EnsPortal.PurgeAll`), nor for Suspended Messages, Export Messages and the Local Archive Manager, so none of the story's surfaces round-trips over its backing class.

**Approach:** Batch 1 of four (Design Notes, veto item 1): **Purge data settings** (one row per setting, each set by itself) and **Purge management data** (six record counts and one destructive Purge), both through `InteropPort`, each write one operation reached by the screen and by the agent. "Round-trips" means: a setting set from either caller reads back from `^Ens.Configuration("PurgeSettings")` as sent, and a purge from either caller removes, through `Ens.Purge.PurgeAll`, the probe records created before its cutoff, keeps the newer ones, and the counts read the change.

## Boundaries & Constraints

**Always:**

- **One port (AD-62).** `InteropPort` gains `PurgeSettings` (`LIST`, `SETTING`, `SETTINGSET`) over `^Ens.Configuration("PurgeSettings", "BodiesToo"|"KeepIntegrity"|"NamespaceBitmapMaint")` and `("PurgeSettings","Desc")`, the store both classic pages write (no vendor method writes it: a named limit), and `Purge` (`LIST`, `PURGESTATE`, `PURGE`) over `Ens.Purge.GetAllCounts` and `Ens.Purge.PurgeAll`. Switched, no `OcuPilot.*` call while switched.
- **Rows.** Settings `{Name, Value, Stored, Kind, Accepts, Namespace}`, four rows named by the classic captions (Design Notes 9), each unset one reading the classic default with `Stored` false: Include message bodies 0, Purge only completed sessions 1, Run bitmap cleanup for namespace 0, Description `""`. Counts `{Type, Count, Namespace}`, the six `GetAllCounts` rows in the classic order, `Type` the vendor's own name. `PURGESTATE` `{BodiesToo, KeepIntegrity, NamespaceBitmapMaint, Description, DaysToKeep, Running, Namespace}`.
- **Gate (AD-29, AD-8), before any vendor call or any value is judged; never cached.** Settings read: `%Ens_Portal:USE`, `%Ens_PurgeSettings:WRITE` (the classic page's `RESOURCE`), then `Admit`. Settings set: the same plus WRITE on the database `^Ens.Configuration` maps to. Counts read: `%Ens_Portal:USE`, `%Ens_Purge:USE`, then `Admit`. Purge: `%Ens_Purge:USE` and WRITE on the namespace's globals database, plus any pair Task 0 (b) measures.
- **Refusals by name, after the gate, before any vendor call.** A setting the list does not report, and a value its kind does not accept (a boolean other than 0 or 1, a description over 2,000 characters), answer the config-setting family's existing codes (`CONFIG.SETTING.NOTFOUND`, `CONFIG.SETTING.VALUE`). A `DaysToKeep` that is not a whole number from 0 to 99999 is 422 `INTEROP.PURGE.DAYS` (the vendor validates nothing; a negative value deletes everything). A purge while the classic page's lock `^IRIS.Temp.EnsPurgeAll($Namespace,"lock")` cannot be taken at once is 409 `INTEROP.PURGE.RUNNING`.
- **The purge runs as the classic Start Purge does.** It holds that lock for the whole `PurgeAll` call, passes the stored `BodiesToo` and `KeepIntegrity` read at the write, and sets only `pExtendedOptions("NamespaceBitmapMaint")` when stored as 1. It runs in its confirm or action request (AD-7), with no transaction; one that outlasts the Web Gateway's response timeout runs to its end in that process and its answer is lost (named limit).
- **Writes (AD-3, AD-6, AD-34, AD-51, AD-53, AD-56, AD-58, AD-59, AD-14, AD-10, AD-22).** `interop.purgesettings.set` extends `ConfigSettingSet`; its read-back compares `Value`; key `true`. `interop.purge.run` is action-style with one declared value `DaysToKeep` (`SCREENVALUES "purge=DaysToKeep"`, as `AuditPurge`); `FINGERPRINTSUBJECT` `BodiesToo,KeepIntegrity,NamespaceBitmapMaint,DaysToKeep,Namespace`, so a settings change after the review closes the proposal as moved; `Running` is its precondition field; `DESTRUCTIVE`; key `false`; the screen's Purge types the namespace's name. A script form per tool. A screen action mints nothing and is not gated by read-only or the kill switch.
- **Namespace at confirm (AD-52).** Both stored proposals carry `Namespace`, and every judgment at confirm (the fresh read, the lock test, the settings read, the value rules) runs in the proposal's namespace, whichever namespace the confirm is sent from.
- **Audit (AD-15).** The agent's marker on every agent write; OcuPilot's own `ConfigChange` from either caller through `AuditRuntime`: a set names the namespace and the setting, never its value; a purge names the namespace, `DaysToKeep`, the three settings it used and the vendor's deleted count per kind.

**Never:**

- `%RunBackgroundMethod`, `JOB`, `%SYSTEM.WorkMgr` or any `pExtendedOptions` key but `NamespaceBitmapMaint`; `Ens.Purge.KillGlobals` or the per-type purge methods; `Ens.Util.Tasks.Purge`; writing any `^IRIS.Temp.EnsPurgeAll` node (only its lock is taken); `^Ens.Configuration("MessagePurge")`.
- A description value in a log line or an audit row; a vendor status text in a log (`LogFault` gets a fixed message and the vendor's code).
- Suspended messages, export and the archive manager (Batches 2 to 4); a README or spine edit.
- `src/OcuPilot/Api/Error.cls` (frozen); `ui/angular.json`; `ui/vitest-base.config.mjs`; `scripts/ci-throwaway.sh` beyond add-only roster lines and never its bring-up retry block; any `Prohibited.cls` logic beyond the appended terms in the Code Map.

## I/O & Edge-Case Matrix

Route namespace USER unless named. Probe records carry the marker `OcuProbe2416` and are created back-dated 7,300 days; a probe purge uses `DaysToKeep` 3650. Every test puts USER's and HSCUSTOM's `PurgeSettings` nodes back exactly as it found them.

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Set, both callers | Include message bodies 1 from the screen; Description from the agent | Each reads back as sent, `Stored` true; read-back `matches` | - |
| Defaults | HSCUSTOM with no `PurgeSettings` node | Four rows with the classic defaults, `Stored` false; nothing written | - |
| Bad value | Boolean 2; description of 2,001 characters; an unknown name | Refused; node unchanged | 400 `CONFIG.SETTING.VALUE`; 404 `CONFIG.SETTING.NOTFOUND` |
| Purge, both callers | Probe headers, bodies, event-log rows back-dated, one probe header created now | Back-dated probe rows gone, today's kept, counts fall by them; card destructive | - |
| Integrity | Probe session back-dated with one header Queued, Purge only completed sessions 1 | The whole session kept | - |
| Bodies | Include message bodies 0, then 1 | A probe body kept, then deleted | - |
| Days | -1, 1.5, 100000, `x` | Refused; nothing deleted | 422 `INTEROP.PURGE.DAYS` |
| Running | The lock held by another process | Refused; nothing deleted | 409 `INTEROP.PURGE.RUNNING` |
| Gate | No `%Ens_Purge:USE`; no `%Ens_PurgeSettings:WRITE`; no database WRITE | Refused before any vendor call | 403 naming the pair |
| Moved | A setting changed after the agent's purge was minted | Confirm refused, nothing deleted | `PROPOSAL.TARGETCHANGED` |
| Confirm elsewhere | Set and purge minted in USER, confirmed with `?ns=HSCUSTOM`, HSCUSTOM holding its own probe rows | Each acts in USER only; HSCUSTOM's node and probe rows unchanged | - |
| Script | Each tool's draft | Renders the namespace switch, the global set or the locked `PurgeAll`, and runs nothing; a bad value renders no draft | - |

</intent-contract>

## Code Map

Paths under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-24` (HEAD `98abd23ca`). **Contention with Epic 21:** none of this batch's files is in `git log --no-merges origin/OCU-1-epic21 ^origin/feature/OCU-1_ocupilot-mvp` at plan (its diff is `ci.yml`, `Test/Journal*`, `ui/browser/structural-walk.mjs`, three `ui/tools` tests); re-check each before editing, keep rosters add-only, `Prohibited.cls` appended terms only.

- **`Port/InteropPort.cls`** (11,274 lines; sibling: the schedule family :9021-9408, extend the pattern): `ENDPOINTS` :128, `ENDPOINTSCHEDULES` :200, `SCHEDULEPAIRS`/`SCHEDULEWRITEPAIR` :307/:311, types :563-573, keys :993-1003, `IsScheduleWrite` :1176, `IsAnyWrite` :1189, `Pairs` :1219 (write-pair line ~:1272), `Serves` :1285, `Invoke` :1399 (schedule branch ~:1458), `Admit` :1521, `Violations` :2375, `LogFault` :3728, `Refuse`/`Conflict` :3734-3779, `AuditRuntime` :6414, `SnippetForm` :6426, `Snippet` :6455, `Literal` :11265; vendor-lock precedent `LockTable`/`UnlockTable` :6673/:6681. The settings rows mirror `AnalyticsPort.SettingRoster` :8108 (fourth element the default) and `SETTINGTEXTMAX` 2000 :690.
- **Vendor (read-only):** `irislib/EnsPortal/PurgeSettings.cls` (`RESOURCE` :13, `DoSaveSettings` :118-124, `GetPurgeSettings` :127-131 defaults); `irislib/EnsPortal/PurgeAll.cls` (`RESOURCE` :14, `DoSaveSettings` :358-365, `CallPurge` :628, lock :640-665, `DoPurge` :667-716, `GetCounts` :521); `irislib/Ens/Purge.cls` (`PurgeAll` :14-63, deleted keys :20-55, `GetAllCounts` :87, `GetDoNotDeleteDate` :213); `irislib/Ensemble.inc` :336-342; `irislib/Ens/Util/MessagePurge.cls` (keep-integrity statuses :282-289, bodies :340-355, suspended journaling :324); `irislib/Ens/MonitorService.cls` :369-396. Measured at plan on `ocupilot-b-ci`: none of the purges checks a privilege or audits; `%SYS.Maint.Bitmap.Namespace` adds `%All` temporarily; `^Ens.Configuration` and `^Ens.MessageHeaderD` map to the namespace's own database; USER holds `BodiesToo` 0, `KeepIntegrity` 1, a default `Desc`; HSCUSTOM holds none.
- **`Api/InteropError.cls`:** codes `PURGEDAYS`, `PURGERUNNING`, consequences `PURGERUN`, `PURGEBITMAP`, after the schedule block :496-526; `PurgeCodes`/`PurgePreconditionCodes` beside `ScheduleCodes` :809/:816, joined into `Codes` :697 and `ConsequenceCodes` :703; `ReasonFor` arms beside :997-1003.
- **Tools (new, `Screen/Tool/`):** `InteropPurgeSettingSet` (extends `ConfigSettingSet` as `AnalyticsSettingSet` does: `PORTCLASS` InteropPort, `READTYPE` `SETTING`, `WRITETYPE` `SETTINGSET`, `ENDPOINTNAME` `PurgeSettings`, `RULES` the new rules class, `CLASSICPAGES` `EnsPortal.PurgeSettings`); `InteropPurgeRun` (extends `InteropAction` as `InteropQueueAbort` does; `WRITERESOURCE` `%Ens_Purge`, `WRITEPERMISSION` `USE`, `READTYPE` `PURGESTATE`, `WRITETYPE` `PURGE`, `SCREENACTIONS` `purge`, `SCREENVALUES`, `PRECONDITIONFIELD` `Running`, `CONSEQUENCECODE`, a `Consequence` answering `PURGEBITMAP` when `NamespaceBitmapMaint` is 1; `DaysToKeep` reaches the query through `PortQuery`, as `AuditPurge.PortQuery` :99, `CutoffProblem` :109, `ScreenActionDelta` :130).
- **Rules (new):** `Area/Interop/PurgeSettingRules.cls` extending `Area/OsMgmt/ConfigSettingRules.cls` with `Limits` from the port, as `Area/Analytics/SettingRules.cls` (16 lines).
- **Descriptors (new):** `Screen/Descriptor/InteropPurgeList.cls` (route `interoperability/purge`, side bar 16, `list`, scope `namespace`, id `single`, entity type `interop-purge`, primary `purge`, no row actions, `classicPage` `EnsPortal.PurgeAll`, `toolIdentifier` `interop.purge`); `Screen/Descriptor/InteropPurgeSettingList.cls` (route `interoperability/purge-settings`, side bar 17, `detail`, scope `namespace`, id `single`, entity type `interop-purge-setting`, row action `set`, `classicPage` `EnsPortal.PurgeSettings`, `toolIdentifier` `interop.purgesettings`), each modeled on `AnalyticsSettingList.cls` and `InteropScheduleList.cls`.
- **Kernel:** `Kernel/EntityType.cls` :120/:165 add both types; `Kernel/Governance/Baseline.cls` two keys after :336; `Prohibited.cls` (append-only): `TYPEINTEROPPURGE`, `TYPEINTEROPPURGESETTING` beside :876, `COVEREDTYPES` :320, the type chain :1759, a `PermittedChangeFields` arm (`Value`) beside :1483, the action arm beside the queue and job arms :2188/:2196.
- **Client (`ui/src/app/`):** `areas/interoperability/interop-purge-{list.page,dialog,store}.ts` and specs (page and store as the schedule files; dialog as `areas/security/audit-purge-dialog.ts` :48, showing the three settings and the namespace's description as text above the days field); the settings screen on the shared `CONFIG_SETTINGS_PAGE` (`shell/screen-outlet.ts` :79/:168, as Analytics settings); `shell/screen-outlet.ts` :285, `core/screen-actions.ts` :325, `shell/screen-action-handler.ts` :154/:635/:839/:960/:1008, `core/proposal-view.ts` :552/:609, `core/strings.ts` after :9490; regenerate `screens.generated.ts` and `Screen/Titles.cls`.
- **Tests (new; principal legs armed by `OCUPILOT_ALLOW_PRINCIPALS`, a `# classes:` line beside `scripts/ci-throwaway.sh` :579):** `Test/InteropPurgeSettingControl.cls` (both callers, defaults, values, read-back, audit, drafts), `Test/InteropPurgeControl.cls` (both callers, integrity, bodies, counts, moved, audit, drafts), `Test/InteropPurgeRefusals.cls` (days, the lock held by a child job the test starts and ends, the gate as principals, no value in a log line), `Test/InteropPurgeElsewhere.cls` (the two cross-namespace confirms, as `InteropScheduleElsewhere`). Fixture `Test/InteropPurgeFixture.cls`: back-dated probe headers and bodies through `InteropMessageRead.StoreHeader` (:89, `pAgo` seconds), probe event-log rows, `DropProbes` by marker in both namespaces, `SaveSettings`/`RestoreSettings` keeping each node's `$Data` and value. Browser: `ui/browser/interop-purge.browser-spec.mjs`, imports as `interop-schedules.browser-spec.mjs`.
- **Rosters (Rule 30; re-grep `interop-schedule`, `InteropScheduleList`, `interop.schedules` across `src/OcuPilot/Test`, `ui/tools`, `ui/browser`, `ui/src`):** `ConfirmNamespaceRoster` (`CHECKEDFLOOR` 118 → 120), `DraftRegistry` (`ARGUMENTVALUES` :71 for `DaysToKeep`), `ToolWrite` :1326 (161 → 163), `Descriptor` (entity types 115 → 117 :1868, screen rows :272), `SurfaceCoverage` :272/:599, `StageTwoTools` :238, `InteropFloor` :71/:74, `GovernanceBaseline.DISABLED` :15, `Governance` :60, `Prohibited` :233, `ReadTool` :94, `ToolRoundTrip` :115, `ToolEmit` :361, `ui/tools/screen-mirror.test.mjs` :2853. No new route: both writes reach `POST /screens/:screen/action` (`Api/ScreenAction.cls` `ToolFor` :643), so `EndpointCoverage` and `SaveHoldCoverage` are unchanged.
- **EXPERIENCE.md:** one Fixed strings row after :626, once the strings are ruled.

## Tasks & Acceptance

**Execution:**

- [ ] **Task 0** (`ocupilot-b-ci`, USER and HSCUSTOM, auditing on; every probe row, item, production, role, user and setting put back after; record under Design Notes › Measured): (a) a `PurgeSettings` set and a `PurgeAll` write no vendor audit row (with a positive control); (b) a principal holding `%Ens_Portal:USE`, `%Ens_Purge:USE` and the database's READ reads the counts; name every pair `PurgeAll` needs (database WRITE expected) and whether bitmap cleanup runs for that principal; (c) with Purge only completed sessions 1, a back-dated probe session holding one Queued header is kept whole; with 0 it is deleted, and say what a running probe production then does with that queue entry; (d) Include message bodies 0 keeps a probe body, 1 deletes it; (e) a `DaysToKeep` 3650 purge on the throwaway deletes only the probe rows (every other count unchanged); (f) the duration of a probe purge and of bitmap cleanup over USER; (g) the cutoff each kind's purge applies for `DaysToKeep` 7 (messages and logs through `GetDoNotDeleteDate`, managed alerts through their own midnight arithmetic, `ManagedAlert.cls` ~:462), for the record: no string states a date. HALT if a read writes, if (a) finds a vendor row, or if (c), (d) or (e) measures otherwise than the consequence sentences say.
- [ ] `InteropPort.cls`, `InteropError.cls`: endpoints, gate, reads, both writes, lock, snippets, codes.
- [ ] The two tools, the rules class, both descriptors, entity types, baseline keys, `Prohibited.cls` terms.
- [ ] Client: the purge page, dialog and store; the settings screen's registration; maps; strings; regenerated mirror and titles; the EXPERIENCE.md row.
- [ ] Tests: the matrix in the four new classes and the fixture, the browser spec, component specs, every roster.

**Acceptance Criteria:**

- **AC1 (settings round trip, both callers).** Given USER's purge settings, when a person sets one from the screen and the agent's confirmed proposal sets another, then each reads back from `^Ens.Configuration("PurgeSettings")` as sent with `Stored` true, the read-back says `matches`, and a namespace with no node shows the classic defaults.
- **AC2 (purge round trip, both callers).** Given back-dated and current probe records, when a person's Purge and the agent's confirmed proposal each run with `DaysToKeep` 3650, then the back-dated probe records are gone, the current one remains, the counts read the change, and the integrity and bodies rows hold as the matrix says.
- **AC3 (refusals and gate).** Given each refusal row of the matrix, when either caller writes, then the named code answers before any vendor call, nothing is deleted or set, and no log line carries a description or a vendor status text.
- **AC4 (the proposal's namespace; Integration, Rule 1).** Given probe rows and settings in USER and HSCUSTOM, when the agent's set and purge are minted in USER and confirmed from HSCUSTOM, then each acts in USER only and HSCUSTOM is unchanged.
- **AC5 (browser).** Given a fresh instance, when a person sets a purge setting and purges probe records on the screens, then the settings list and the counts show each change.
- **AC6 (fresh, either order).** Given any new or changed test, run first on a fresh instance in either order, when it ends, then no probe record remains in either namespace and both `PurgeSettings` nodes read as before.

## Spec Change Log

- 2026-11-22, spec gate (runner, veto item U-142): every Design Notes veto item kept as recommended (four batches; Batch 1 purge and settings; the settings read gated by WRITE as the classic page; 2,000-character descriptions; the proposed strings). The PURGERUN and PURGEBITMAP consequences are provisional until Task 0 measures them true on `ocupilot-b-ci`; a sentence measured untrue HALTs `blocked` with `intent gap: new string`.

## Review Triage Log

## Design Notes

**Veto items (recommended option first).**

1. **Split into four batches**, each its own spec and commit series: **1** purge and its settings (this spec); **2** Suspended messages: a list of `Ens.MessageHeader` rows with Status Suspended (the classic page's 2,000 cap), resubmit through `Ens.MessageHeader.ResubmitMessage` (the vendor audits it), edit-and-resubmit on Story 20.31's edit path, discard (status set; OcuPilot's own `ConfigChange`) and delete (header, body and search-table rows as the classic `DeleteMessage`; destructive, key `false`), each on a reviewed selection of at most 100, with no Discard All or Delete All background job; **3** Export messages: a person's export of a reviewed message selection to a download, built in the request in an instance-computed temporary directory, separator and character set from fixed lists, the vendor's `AuditViewMessage` per message, without the background saved-search mode; **4** Local archive manager: its settings in `^Ens.ArchiveManager` (target namespace from the instance's interoperability namespaces, days), its error list, and Run archive in the request under the vendor's lock (moves and deletes messages; destructive, key `false`), the archive class shown and not settable (it runs code). The README clauses go in the last batch. Alternative: one spec per surface as separate stories.
2. **Two screens, one per classic page; each setting set by itself** (as Analytics settings), not a whole-form Save. An unset setting keeps reading the classic default, so a single-node write means what the classic Save means.
3. **The settings screen needs `%Ens_PurgeSettings:WRITE` to read**, as the classic page's `RESOURCE` says; a holder of `%Ens_Purge:USE` alone sees the counts, and the purge dialog and card still show the three settings it will use.
4. **The purge runs in the request, not in a background job** (AD-7, as a cube build and an index rebuild); the named limit is that an answer outlasting the gateway is lost.
5. **`DaysToKeep` is 0 to 99999** (stricter than the vendor, which validates nothing, and the classic page, which takes any whole number). 0 purges every record, today's included, as the classic page does after its second question.
6. **A description is at most 2,000 characters** (the analytics text limit; the classic page has none).
7. **Bitmap cleanup is honored as stored**, as the classic Start Purge does: the vendor's `%SYS.Maint.Bitmap.Namespace` adds `%All` for itself, as AD-62 item 4's vendor escalation; the card says so. Alternative: ignore the setting.
8. **Purge only completed sessions may be off**; the card shows it and no refusal applies.
9. **Proposed strings** (reused: "Purge" (`auditDatabasePurgeConfirm`, also the action and dialog title), "Older than (days)" (`auditDatabasePurgeDays`), "Type" (`tableColumnType`), "Count" (`interopColumnCount`), "Set value" (`interopItemSettingSetAction`), "Description" (`tableColumnDescription`), each read true here; the six count rows show the vendor's own type names as data):
   - Labels: "Purge management data" · "Purge data settings".
   - Setting names (row data, the classic captions): "Include message bodies" · "Purge only completed sessions" · "Run bitmap cleanup for namespace" · "Description".
   - Consequences: `PURGERUN` "Deletes this namespace's event log entries, messages, completed business process records, business rule log entries, I/O log entries, host monitor data and managed alerts older than the days to keep, and their message bodies when Include message bodies is on. When Purge only completed sessions is on, a session with a message still in progress is kept whole, and so is an open managed alert. It cannot be undone." · `PURGEBITMAP` the same, then "Bitmap cleanup then runs over every class in this namespace with full system rights, and can take a long time."
   - Refusals: `DAYS` "Older than (days) is a whole number from 0 to 99999." · `RUNNING` "A purge is already running in this namespace. Try again when it has finished."
   - Empty states: "This namespace has no records to count." (agent phrase "purge old records") · "This namespace has no purge settings."
   - Prompts: "What does a purge delete in this namespace?" · "Which kind of record is most numerous here?" · "Purge records older than 30 days." · "Explain what each purge setting does." · "Does a purge here keep sessions that are still in progress?" · "Turn on Include message bodies."

**Proposed spine lines for story end (the orchestrator writes them, add-only; never written here).** Each takes `[AMENDED <date>, Story 24.16, Rule 20]`.

- AD-62, item 19: "**Purge and its settings.** `InteropPort` gains `PurgeSettings` over `^Ens.Configuration("PurgeSettings")`, the classic pages' own store (a named limit: no vendor method writes it), behind `%Ens_PurgeSettings:WRITE`, and `Purge` over `Ens.Purge.GetAllCounts` and `Ens.Purge.PurgeAll` behind `%Ens_Purge:USE`. A purge holds the classic page's lock `^IRIS.Temp.EnsPurgeAll($Namespace,"lock")` for its run and is refused while it is held; its days are judged before any vendor call; the stored settings are read at the write and fingerprinted."
- AD-7: "**A purge (Story 24.16)** runs in its confirm or action request, as a cube build does; the classic page's `%RunBackgroundMethod` job is not used. One that outlasts the Web Gateway's response timeout runs to its end in that request's process, and its answer is lost (named limit)."
- AD-15, named case: "**Purge and purge-setting writes** (Story 24.16), which the vendor does not audit, record OcuPilot's own `ConfigChange` from either caller, never a description."
- AD-22: "**Story 24.16's Batch 1 keys:** `interop.purge.run` ships `false`; `interop.purgesettings.set` ships `true`."

**README (story end, last batch).** The Interoperability paragraph gains "keep the purge settings and purge old management data"; the switched-off list gains "purging interoperability management data".

**Decided in-stage (plan).**

1. Epic context reused as committed (dispatch instruction); the planning files newer than it carry Story 21.39's insertion and Story 24.15's add-only spine lines, which this plan read directly.
2. The lead's ledger commit `98abd23ca` landed during this stage; this stage left it untouched.
3. The setting names are the classic captions, not the vendor keys, so no internal id reaches a person; the port maps them.
4. The purge takes the vendor lock and writes none of the classic page's run nodes; a classic page open meanwhile reads the purge as running from the lock.
5. No source-control refusal: neither store is a source-controlled document.
6. The counts read is `GetAllCounts` (six `COUNT(*)` queries); host monitor data has no count row, as on the classic page.
7. The namespace's description is shown in the purge dialog, the page's "explanatory box", as text never run (AD-11).
8. Tests purge only with `DaysToKeep` 3650 over rows back-dated 7,300 days, never 0, and with bitmap cleanup off; Task 0 (f) measures it once.
9. Siblings (Rule 31): `ConfigSettingSet`/`AnalyticsSettingSet` and `Analytics/SettingRules` (set), `InteropAction`/`InteropQueueAbort` (destructive action), `AuditPurge` (one declared value), `CONFIG_SETTINGS_PAGE` (settings client), the schedule family (port, tests), `InteropMessageRead.StoreHeader` (back-dated probes).
10. Side-bar positions 16 and 17, after Schedule specs.

**Measured (Task 0).** Filled by the implement stage.

**Governing ADs (Rule 6):** AD-3, AD-6, AD-7, AD-8, AD-10, AD-11, AD-13, AD-14, AD-15, AD-16, AD-21, AD-22, AD-29, AD-34, AD-36, AD-44, AD-51, AD-52, AD-53, AD-56, AD-58, AD-59, AD-60, AD-62. Not engaged: AD-23 (no harvest), AD-35 (no secret), AD-54 (no create), AD-63, AD-65, AD-66.

**Integration and linkage (Rules 1, 2).** Integration: AC4 (the kernel's confirm consumes the stored proposal in its own namespace) and AC1's agent leg (the derived read tool). Consumes: `InteropPort` (`Admit`, `AuditRuntime`), `ConfigSettingSet`, `InteropAction`, the kernel's proposal, confirm, governance and audit. Consumed-by: Batch 2's Suspended messages screen reuses the purge fixture's back-dated probes; Story 24.20's undo names the purge as not restorable. DW-2841 (the database WRITE pair read in the confirming namespace, owner `burndown`) applies to both new tools through `InteropAction`; not addressed here.

**Ledger inbox (Rule 17):** `LEDGER slice 24-16-...` empty at plan; `owned_ledger=0`.

## Verification

**Commands** (one `ci-runner` call per message; `ocupilot-b-ci` only):

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.InteropPurgeSettingControl`, then likewise `InteropPurgeControl`, `InteropPurgeRefusals`, `InteropPurgeElsewhere`, `ConfirmNamespaceRoster`, `DraftRegistry`, `Prohibited`, `GovernanceBaseline`, and every class the roster sweep changes. Expected: green; new classes green on their first run.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`. Expected: green.
- `(loop)` `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/interop-purge.browser-spec.mjs browser/interop-schedules.browser-spec.mjs`. Expected: green.
- `(once)` The full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17` for k = 1 to 17, one call each. Expected: green. The full browser suite is left to CI.
- `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh`. Expected: clean.

**Shared surfaces:** the Interoperability side bar; the entity-type vocabulary; the governance baseline; `COVEREDTYPES`; the read-tool, coverage, draft, confirm-namespace and other-port write rosters; `InteropError`'s code lists; `screen-mirror.test.mjs`; the arming roster; USER's and HSCUSTOM's `PurgeSettings` nodes and interoperability records.

**Hermeticity:** every test added or changed passes on its first run on a fresh instance, in either order; it asserts on its own probe rows by marker, removes them, and puts both `PurgeSettings` nodes back exactly; a child job it starts ends before the test does.

**Mutations** (each AC's pinning test shown red, reverted byte-identical, recorded as `mutation: <change> -> <test>`; the planned ones):

- AC1: the port's `SETTINGSET` writes `KeepIntegrity` under the `BodiesToo` key -> `InteropPurgeSettingControl` read-back leg red.
- AC2: `PurgeAll` called with `pBodiesToo` 0 always -> `InteropPurgeControl` bodies leg red; `DaysToKeep` passed as 0 -> its kept-current-row leg red.
- AC3: the `Running` lock test answers free -> `InteropPurgeRefusals` lock leg red; the days rule admits a negative -> its days leg red.
- AC4: `InteropPurgeRun`'s `FINGERPRINTSUBJECT` without `Namespace` -> `InteropPurgeElsewhere` purge leg red.
- AC5: the dialog sends `DaysToKeep` 0 (bundle rebuilt and redeployed) -> `interop-purge.browser-spec.mjs` red.
- AC6: `InteropPurgeFixture.RestoreSettings` restores nothing -> the settings-unchanged leg red.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

**Plan.** Batch 1 of four: Purge data settings and Purge management data through `InteropPort`, each write reached by the screen and the agent, every proposal keeping its namespace and every confirm judging there. Veto items: Design Notes 1 to 9 (the split first). The story-end spine lines and README clauses are under Design Notes. Read-only probes on `ocupilot-b-ci` (52777, identity checked, by a research subagent): the purge classes check no privilege and write no audit row; bitmap cleanup adds `%All` for itself; the stores map to the namespace's own database; USER holds two settings and a description, HSCUSTOM none; `GetAllCounts` reads 0 for every type in both; the purge lock is free. Nothing was written to the instance.
