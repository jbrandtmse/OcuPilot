---
title: 'Story 24.16: Purge, suspended messages, export and the archive manager (Batch 1: purge and its settings)'
type: 'feature'
created: '2026-11-22'
status: 'done'
baseline_revision: '7ba20b70cb5e43b7ab3a21acadb911810fec116e'
review_loop_iteration: 0
followup_review_recommended: true
owned_ledger: ''
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-15-credentials-default-settings-and-schedules-4.md'
warnings: ['oversized', 'multiple-goals']
deferred:
  - summary: >-
      An agent's purge that the vendor answers with an error status after deleting part carries no AD-15 agent marker.
    evidence: |-
      Confirm.cls treats any port error as a write that did not happen, so RecordAgentWrite is skipped; OcuPilot's own ConfigChange row (now with completed false) is the only record. Changing that is a kernel confirm rule shared by every tool.
    location: >-
      src/OcuPilot/Kernel/Proposal/Confirm.cls (the applied test after the port's answer)
    severity: medium
  - summary: >-
      AD-9 in the spine does not yet name the second `New $ROLES` (InteropPort.PurgeFrame) the guard now admits.
    evidence: |-
      The orchestrator ruled the allowlist entry on 2026-11-22; the spine line is a story-end edit (Design Notes, proposed AD-9 line), so the guard and AD-9 must land together at the story's end.
    location: >-
      _bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md (AD-9)
    severity: low
  - summary: >-
      The EXPERIENCE.md row and several one-line rosters this batch appends to are appended to at the same lines by Epic 21.
    evidence: |-
      Epic 21's 595d8a352 inserts its own Fixed strings row after EXPERIENCE.md :626 and both branches renumber strings.ts taskCreate; the same-line rosters are listed in the review triage. Each conflict is a union plus a recount at the merge.
    location: >-
      _bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md (:627), ui/src/app/core/strings.ts (EXPERIENCE.md:627 citations)
    severity: low
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

- [x] **Task 0** (`ocupilot-b-ci`, USER and HSCUSTOM, auditing on; every probe row, item, production, role, user and setting put back after; record under Design Notes › Measured): (a) a `PurgeSettings` set and a `PurgeAll` write no vendor audit row (with a positive control); (b) a principal holding `%Ens_Portal:USE`, `%Ens_Purge:USE` and the database's READ reads the counts; name every pair `PurgeAll` needs (database WRITE expected) and whether bitmap cleanup runs for that principal; (c) with Purge only completed sessions 1, a back-dated probe session holding one Queued header is kept whole; with 0 it is deleted, and say what a running probe production then does with that queue entry; (d) Include message bodies 0 keeps a probe body, 1 deletes it; (e) a `DaysToKeep` 3650 purge on the throwaway deletes only the probe rows (every other count unchanged); (f) the duration of a probe purge and of bitmap cleanup over USER; (g) the cutoff each kind's purge applies for `DaysToKeep` 7 (messages and logs through `GetDoNotDeleteDate`, managed alerts through their own midnight arithmetic, `ManagedAlert.cls` ~:462), for the record: no string states a date. HALT if a read writes, if (a) finds a vendor row, or if (c), (d) or (e) measures otherwise than the consequence sentences say.
- [x] `InteropPort.cls`, `InteropError.cls`: endpoints, gate, reads, both writes, lock, snippets, codes.
- [x] The two tools, the rules class, both descriptors, entity types, baseline keys, `Prohibited.cls` terms.
- [x] Client: the purge page and dialog (no store: the page keeps its two flags itself); the settings screen's registration; maps; strings; regenerated mirror and titles; the EXPERIENCE.md row.
- [x] Tests: the matrix in the four new classes, the fixture and a seam, the browser spec, a component spec, the rosters the sweep named (the full ObjectScript sweep is the lead's).

**Acceptance Criteria:**

- **AC1 (settings round trip, both callers).** Given USER's purge settings, when a person sets one from the screen and the agent's confirmed proposal sets another, then each reads back from `^Ens.Configuration("PurgeSettings")` as sent with `Stored` true, the read-back says `matches`, and a namespace with no node shows the classic defaults.
- **AC2 (purge round trip, both callers).** Given back-dated and current probe records, when a person's Purge and the agent's confirmed proposal each run with `DaysToKeep` 3650, then the back-dated probe records are gone, the current one remains, the counts read the change, and the integrity and bodies rows hold as the matrix says.
- **AC3 (refusals and gate).** Given each refusal row of the matrix, when either caller writes, then the named code answers before any vendor call, nothing is deleted or set, and no log line carries a description or a vendor status text.
- **AC4 (the proposal's namespace; Integration, Rule 1).** Given probe rows and settings in USER and HSCUSTOM, when the agent's set and purge are minted in USER and confirmed from HSCUSTOM, then each acts in USER only and HSCUSTOM is unchanged.
- **AC5 (browser).** Given a fresh instance, when a person sets a purge setting and purges probe records on the screens, then the settings list and the counts show each change.
- **AC6 (fresh, either order).** Given any new or changed test, run first on a fresh instance in either order, when it ends, then no probe record remains in either namespace and both `PurgeSettings` nodes read as before.

## Spec Change Log

- 2026-11-22, spec gate (runner, veto item U-142): every Design Notes veto item kept as recommended (four batches; Batch 1 purge and settings; the settings read gated by WRITE as the classic page; 2,000-character descriptions; the proposed strings). The PURGERUN and PURGEBITMAP consequences are provisional until Task 0 measures them true on `ocupilot-b-ci`; a sentence measured untrue HALTs `blocked` with `intent gap: new string`.

- 2026-11-22, implement (Task 0 measured; orchestrator ruling relayed by the lead): `PURGERUN` and `PURGEBITMAP` hold as written with two orchestrator-approved additions (days 0; the rights end when the cleanup returns); see Design Notes, Proposed strings, Final wording. The `$ROLES` containment test and the lost-answer audit are in scope (Decided in-stage, implement).

## Review Triage Log

### 2026-11-22 — Review pass

- verdicts: 16 findings — high 0, medium 6, low 10, false 0, maybe-false 0 (the roster of five divergences the intent layer listed is logged as four rows, two of them one root cause)
- findings:
  - `[low]` `[reject]` intent-alignment: `FINGERPRINTSUBJECT` of `InteropPurgeRun` adds `Running` to the contract's list — the sibling actions (`AnalyticsCubeBuild`, `AllowedDirectoryUpdate`) fingerprint their precondition field the same way; a purge that starts elsewhere after the review closes the proposal as moved. No harm.
  - `[low]` `[reject]` intent-alignment: days above the instance calendar are clamped before the vendor call, the audit row recording the days asked — measured at implement: the vendor answers 500 above about 67,000 days, and the clamp keeps every record, as those days say. Decided in-stage (implement) 5.
  - `[low]` `[reject]` intent-alignment: Purge is a row action and the settings screen archetype `list` — the action route admits only a declared row action; recorded as Decided in-stage (implement) 5, no acceptance criterion moved.
  - `[low]` `[reject]` intent-alignment: the gate roster names the install database while the tool resolves the namespace's globals database at run time — the roster's convention for every other write; both are exercised by the principal legs.
  - `[medium]` `[patch]` verification-gap: nothing showed the purge lock freed after a purge that ran, answered an error or threw — patched: `InteropPurgeRefusals.LockHeld` (positive control while the child holds it) asserted after the run and after each failing seam mode; mutation: remove the lock release from `PerformPurge`'s Catch -> the fault leg red.
  - `[medium]` `[patch]` verification-gap: the confirm-elsewhere purge could not tell whose settings it read, both namespaces holding the same — patched: HSCUSTOM holds Include message bodies 0 and USER 1, the old USER body must go; mutation: the purge reads HSCUSTOM's settings -> `InteropPurgeElsewhere` red.
  - `[medium]` `[patch]` verification-gap: the person's days refusal was asserted only as not 200 — patched: it must answer 400 `TOOL.ARGUMENTS` with the published sentence (an empty value is refused first by the action's own argument check, with its own sentence).
  - `[medium]` `[patch]` verification-gap: the roles test's success leg accepted any status; running it at 200 showed the principal held no SQL rights and got the vendor's error status, so the leg never ran a bitmap cleanup — patched: the principal holds the Ensemble administrator role, the leg asserts 200 and a new row of the vendor's bitmap maintenance for the namespace.
  - `[medium]` `[patch]` verification-gap: the audit row of a purge the vendor answered with an error status was not asserted — patched with the status seam leg; mutation: the audit call moved below the error quit -> that leg red.
  - `[low]` `[reject]` verification-gap: a purge that throws writes no audit row and nothing pins it — `wontfix-accepted`; reopen_if a thrown vendor call is seen to have deleted records.
  - `[low]` `[reject]` verification-gap: mutations of the gate leg, the log-text leg and the integrity and counts legs are named in test comments, not in `## Verification` — Rule 19 asks one demonstrated mutation per acceptance criterion, which each has.
  - `[low]` `[reject]` verification-gap: the vendor-audit assertions have no positive control in the test — the positive control was measured once in Task 0 (a), where a resource create and delete wrote two rows.
  - `[low]` `[reject]` verification-gap: two branches of `PurgeVendorStatus` (a lock or privilege status, a `<PROTECT>` text) are not exercised — real principals reach them in the gate legs only as refusals; no user-reachable wrong outcome.
  - `[low]` `[reject]` verification-gap: no server-side test posts to `/dryrun` for a running purge — the browser spec covers the dialog's review and the client spec the 409; `wontfix-accepted`, reopen_if the review of a running purge answers 200.
  - `[medium]` `[patch]` verification-gap: the browser spec judged the list's Messages count against a literal 1 — patched: it reads the vendor's own total after arranging and expects it minus one; its settings save and restore also became the fixture's JSON `SaveSettings`/`RestoreSettings`, because a fresh instance holds a description over several lines that the one-line text could not carry (first run on a fresh instance failed to restore).
  - `[low]` `[reject]` verification-gap: the after-test equality of saved settings can fail only if the restore does — it does, under the AC6 mutation.

### 2026-11-22 — QA and code review (four layers: AD-9, correctness, namespace and verification, strings and contention)

- verdicts: 27 findings — high 0, medium 6 (6 patched, one with a deferred part), low 21 (12 patched, 6 rejected, 3 deferred).
- findings:
  - `[medium]` `[patch]` no partial-purge test (orchestrator item 6) — the item holds (500, never 200); pinned by a principal without SQL delete rights (### QA).
  - `[medium]` `[patch]` the days clamp was not pinned at its boundary — named limit with the measured value, test at the boundary (### QA).
  - `[medium]` `[patch]` the roles test lacked the principal's raised-error leg and did not pin `_SYSTEM` — three legs (### QA).
  - `[medium]` `[patch]` a description of several lines (the fresh instance's own) was refused, and flattened by the one-line field — the purge rules accept CR and LF in text and the settings page draws a text area.
  - `[medium]` `[patch]` + `[defer]` a failed or partial purge's audit row read as a full one — `completed` added; the missing agent marker deferred (frontmatter).
  - `[medium]` `[patch]` `interop.test.mjs`'s sentence roster lacked the four purge sentences — four rows added.
  - `[low]` `[patch]` `PurgeFrame`'s doc said the vendor keeps `%All`; the KeepIntegrity parity claim; the stale rule-6 and page comments; the draft script passed unclamped days; the cross-namespace set's read-back unasserted; the lock's namespace at confirm unpinned; the browser spec's held-Purge check could not fail; a `## Verification` line overstated; the harness lacked a method and a trigger after `PurgeFrame`, and the checker admitted a trigger after it (member reset added); no failed-purge client case.
  - `[low]` `[reject]` the Catch switches back to release the lock before restoring — every path ends restored and no OcuPilot class runs switched.
  - `[low]` `[reject]` a vendor `<PROTECT>` after partial deletes answers 403 — the measured partial purge answers 500; 403 needs an Ensemble global outside the gated database (inference); never 200.
  - `[low]` `[reject]` a state read probing the lock can collide with a write's `:0` — the contract says "taken at once", as the classic page's own probe.
  - `[low]` `[reject]` the screen's Purge is not bound to the settings its dialog showed — the contract reads them at the write, as the classic Start Purge.
  - `[low]` `[reject]` the client spec's 422 mock — the violation branch serves the port's 422; the failed-purge case was added.
  - `[low]` `[reject]` `navigation.test.mjs` rewrite and `ReadTool.cls`'s half-bumped prose count — correct and contended (Epic 21) respectively; no assertion depends on the prose.
  - `[low]` `[defer]` AD-9's spine line; the Epic 21 same-line rosters and EXPERIENCE.md row (frontmatter).
- AD-9 containment: contained on every exit; the rule-6 entry admits one method of one file. Clamp: safe. Sed hunk: `strings.ts` `taskCreate`'s `EXPERIENCE.md:668` to `:669`, the one substitution, correct.

## Decisions

- QA and review, 2026-11-22: the purge rules accept CR and LF in a description, as the classic page's text area stores them, and still refuse every other control character.
- QA and review, 2026-11-22: the audit row of a purge carries `completed`, the vendor status's verdict; no user-facing text changes.
- QA and review, 2026-11-22: the draft script passes `+$Horolog - 2` for days past the calendar, as the port does.

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
   - **Final wording (orchestrator-approved additions, relayed 2026-11-22, measured in Task 0):** `PURGERUN` is the sentence above with, before "It cannot be undone.", the added sentence "With 0 days, everything up to the end of today is deleted, except managed alerts from today." `PURGEBITMAP` is `PURGERUN` as so worded, then "Bitmap cleanup then runs over every class in this namespace with full system rights, and can take a long time. Those rights end when it finishes."
   - Refusals: `DAYS` "Older than (days) is a whole number from 0 to 99999." · `RUNNING` "A purge is already running in this namespace. Try again when it has finished."
   - Empty states: "This namespace has no records to count." (agent phrase "purge old records") · "This namespace has no purge settings."
   - Prompts: "What does a purge delete in this namespace?" · "Which kind of record is most numerous here?" · "Purge records older than 30 days." · "Explain what each purge setting does." · "Does a purge here keep sessions that are still in progress?" · "Turn on Include message bodies."

**Proposed spine lines for story end (the orchestrator writes them, add-only; never written here).** Each takes `[AMENDED <date>, Story 24.16, Rule 20]`.

- AD-62, item 19: "**Purge and its settings.** `InteropPort` gains `PurgeSettings` over `^Ens.Configuration("PurgeSettings")`, the classic pages' own store (a named limit: no vendor method writes it), behind `%Ens_PurgeSettings:WRITE`, and `Purge` over `Ens.Purge.GetAllCounts` and `Ens.Purge.PurgeAll` behind `%Ens_Purge:USE`. A purge holds the classic page's lock `^IRIS.Temp.EnsPurgeAll($Namespace,"lock")` for its run and is refused while it is held; its days are judged before any vendor call; the stored settings are read at the write and fingerprinted."
- AD-7: "**A purge (Story 24.16)** runs in its confirm or action request, as a cube build does; the classic page's `%RunBackgroundMethod` job is not used. One that outlasts the Web Gateway's response timeout runs to its end in that request's process, and its answer is lost (named limit); its outcome, the namespace, the days, the settings and the count deleted of each kind, is in the audit log under Logs, Audit database, written when the vendor call returns whether or not the client is still connected."
- AD-15, named case: "**Purge and purge-setting writes** (Story 24.16), which the vendor does not audit, record OcuPilot's own `ConfigChange` from either caller, never a description."
- AD-9 (veto-window item, orchestrator to rule; the guard edit is already in this commit): "**A second `New $ROLES` (Story 24.16).** `InteropPort.PurgeFrame` is the one method outside the installer's `AsAdministrator` that may say `New $ROLES`: it gives the process's roles back on every exit of the vendor purge, whose bitmap cleanup adds `%All` for itself. It escalates nothing; `AddRoles` stays refused there. `scripts/check-objectscript.py` rule 6 allows exactly that file and method; an explicit `Set $ROLES` restore was not used because a signed-in principal without `%All` cannot set its own roles (measured on `ocupilot-b-ci`: `Set $ROLES` raises `<PROTECT>`)."
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

**Decided in-stage (implement), from Task 0 and the orchestrator's ruling relayed 2026-11-22 (binding).**

1. **`$ROLES` containment.** The vendor purge and bitmap call run inside a frame that does `New $ROLES` (restored on every exit, the Catch path included, so on an error, a trapped `<INTERRUPT>` or a timeout). A test reads `$ROLES` before and after a bitmap-cleanup purge over back-dated probes on the success path and a forced error path; removing the restore reddens it (a `mutation:` line).
2. **A lost answer.** Past the gateway timeout the `ConfigChange` row and the purge's counts are written in the request process after the vendor call returns, connected or not. The named limit's wording says the person finds the outcome in the audit log, under Logs, Audit, as that screen is named.
3. **Days 0 is accepted** and measured: see Measured (g); `PURGERUN` states it.
4. **Partial purge without SQL delete rights** (Task 0 (b)) is a named limit, not a refusal: the vendor answers an error status after deleting only part, the port reports it as a failed purge and still audits it, and no new string is added. The roles test's principal holds the Ensemble administrator role for that reason.
5. **Implement-stage choices, each for the lead to confirm.** (a) The Purge action is a declared **row action** (`rowActions` `purge`, no primary action): `POST /screens/:screen/action` admits only a row action (`Descriptor.RowActionIds`), so the plan's primary action cannot reach the tool; the page registers it and it purges the namespace whichever count row is selected. (b) The settings screen is archetype `list` (the shared settings page draws it as the other settings screens), not `detail`: it has no tab group. (c) A person's Purge first asks `POST /screens/:screen/dryrun` (the tool declares `DRYRUN`; `DryRunReview` answers the three settings and the description), so the dialog shows the settings before the days are asked and a running purge refuses it there; the review's value is 0 days, which writes nothing. (d) The agent-facing empty-state phrase of Purge data settings is "change a purge setting", beside the published one for Purge. (e) The purge's target id is the namespace name; the mint refuses a `Name` that is not the request's namespace with a one-sentence argument problem built from the argument name and the namespace, as `AuditPurge`'s date problem is. (f) Days are accepted to 99999 as published, but the vendor errors on a cut-off before the instance's first day (see the named limit below); the port gives the vendor no more days than the instance's calendar holds, which keeps every record as the days say, and the audit row records the days asked. (g) The `$ROLES` frame is `InteropPort.PurgeFrame`; `scripts/check-objectscript.py` rule 6 refused `New $ROLES` there, so its method allowlist gained `InteropPort.cls` `PurgeFrame` beside the installer's `AsAdministrator`, scoped to that one method of that one file (orchestrator ruling, 2026-11-22), with six harness tests. (h) A caught vendor exception reaches the log as its error codes alone, as a vendor status does.

**Measured (Task 0, `ocupilot-b-ci`, 2026-11-22, auditing on, probe records marked `OcuProbe2416` back-dated 7,300 days, `DaysToKeep` 3650; probe class, probe user and role removed after; both namespaces' `PurgeSettings` nodes as found; HSCUSTOM and USER hold no other interoperability records).**

- (a) No vendor audit row: a `PurgeSettings` global write and five `PurgeAll` runs wrote none (`%SYS.Audit` read since the start stamp); the positive control (create and delete of a resource) wrote two `%System/%Security/ResourceChange` rows. The counts reads wrote nothing.
- (b) A principal holding `%Ens_Portal:USE`, `%Ens_Purge:USE` and `%DB_USER:R` reads the counts (`GetAllCounts` answered) and its `PurgeAll` fails (`<PROTECT>` on the I/O log delete, SQLCODE -99 on managed alerts) and deletes nothing. A principal holding `%DB_USER:RW` alone (no Ensemble resource) purges event, rule and I/O log rows, but the message purge silently deletes nothing (its SELECT is refused without a status) and managed alerts fail with SQLCODE -99: the purge needs SQL delete rights on the Ensemble tables beyond database WRITE. A principal holding `%EnsRole_Administrator` and `%DB_USER` purges every kind. No vendor purge tests `%Ens_Purge`. No resource pair beyond `%Ens_Purge:USE` and the database WRITE is measured; the SQL delete rights are not a resource pair, so the gate cannot name them and a principal without them gets a partial purge, answered as the vendor's error status (the managed alert purge fails), with the message purge silently skipped (named limit, Decided in-stage).
- Bitmap cleanup (`NamespaceBitmapMaint` 1) ran for the same principal without `%All` (rows of `%SYS_Maint.Bitmap` for the namespace, status Finished), and the principal's `$ROLES` read the same before and after the call: the vendor adds `%All` in its own frame and drops it when it returns. `PURGEBITMAP` takes the orchestrator-approved clause (Proposed strings).
- (c) Purge only completed sessions 1: a back-dated session of one Completed and one Queued header was kept whole (both headers and bodies), an old closed managed alert deleted and an old open one kept; with 0, both headers and the open alert were deleted. What a running production does with a deleted queue entry was not measured (no probe production runs on the throwaway).
- (d) Include message bodies 0 kept the probe body (an orphan with no header); 1 deleted it (`Message Bodies=1`).
- (e) The 3650-day purge removed only probe rows; USER's other counts (all 0) did not move. HSCUSTOM's event log count rises on its own between calls (a running production), so tests compare probe-marker counts, never the vendor totals.
- (f) Probe purges took 0.01 to 0.30 s; with bitmap cleanup 0.06 s over USER and 0.27 s over HSCUSTOM, both nearly empty; no measure of a large namespace.
- (g) Cutoffs for `DaysToKeep` 7 on 2026-11-22: messages, logs and the other kinds through `GetDoNotDeleteDate` at local midnight 2026-11-16 00:00; managed alerts at 2026-11-15 00:00 (their own arithmetic keeps one day more). `DaysToKeep` 0: the message cutoff is the next local midnight, so today's messages, logs, I/O and rule log rows were deleted; managed alerts used today's midnight, so today's alerts survived. No string states a date.
- Not probed: business process records (the table was empty and a probe host class was not built; source: completed records only, always integrity-kept).

**Named limits (review, orchestrator ruling 2026-11-22).**

- **Days past the calendar.** The vendor's `GetDoNotDeleteDate` raises `<VALUE OUT OF RANGE>` from `+$Horolog + 2` days on (measured on `ocupilot-b-ci` 2026-11-22: 67,897 answered, 67,898 raised). The port passes at most `+$Horolog - 2` days (67,894 that day), a cut-off of 1841-01-03 that predates any record OcuPilot or the vendor could hold, so the outcome is the one the days ask: nothing is old enough to delete. `InteropPurgeRefusals.TestDaysAtTheEdgeOfTheCalendarReachTheVendorAsAPurgeOfNothing` pins it at the boundary: `+$Horolog - 3` and `- 2` reach the vendor as asked, `- 1` and 99999 as `- 2`, and the vendor's own purge answers 200 at `- 2` and `- 1` with no probe deleted. No user-facing wording.
- **Business process records.** Not measured; no production runs on the throwaway.
- **A running production's deleted queue entries.** Not measured; no production runs on the throwaway.

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

**Mutations** (each AC's pinning test shown red on `ocupilot-b-ci`, `src` reloaded after each and reverted byte-identical, the client one on a rebuilt and redeployed bundle):

- mutation: AC1, the port's `SETTINGSET` stores the value under the `KeepIntegrity` node whatever the setting -> `InteropPurgeSettingControl` red (the set-from-either-caller and the 2,000-character legs).
- mutation: AC2, `PurgeAll` called with Include message bodies 0 always -> `InteropPurgeControl` red (the bodies leg and the agent's purge); `DaysToKeep` passed as 0 -> `InteropPurgeControl` red (the kept-current-row leg).
- mutation: AC3, the write's lock test answers held 1 whatever the lock says -> `InteropPurgeRefusals` red (the lock leg); the days rule accepts a leading minus -> `InteropPurgeRefusals` red (the `-1` leg and nothing-deleted).
- mutation: AC4, `InteropPurgeRun`'s `FINGERPRINTSUBJECT` without `Namespace` -> `InteropPurgeElsewhere` red (the purge leg); without `BodiesToo` -> `InteropPurgeControl` red (the moved leg).
- mutation: AC5, the dialog emits `DaysToKeep` 0 -> `interop-purge.browser-spec.mjs` red (the purge test).
- mutation: AC6, `InteropPurgeFixture.RestoreSettings` restores nothing -> `InteropPurgeSettingControl` red (the settings-unchanged leg of every test).
- mutation: `$ROLES` containment, `New $ROLES` removed from `PurgeFrame` -> `InteropPurgeRefusals` red (leg (c), `_SYSTEM`'s raised error, on the roles equality; legs (a) and (b), a principal without `%All`, hold either way because a principal cannot change its own roles).
- mutation: AC4, `PerformPurge` reads the settings of HSCUSTOM instead of the proposal's namespace -> `InteropPurgeElsewhere` red (the purge leg, USER's old body kept).
- mutation: AC3, the lock release removed from `PerformPurge`'s Catch -> `InteropPurgeRefusals` red (the fault leg, and the class's leaked-lock check); the audit call moved below the vendor-error quit -> `InteropPurgeRefusals` red (the status leg).

### QA

Added in the code review, each run on `ocupilot-b-ci` (mutations on the pre-rebuild instance, `InteropPort` recompiled with its subclasses; the client one in the component runner), then reverted and every class green on its first run on the rebuilt instance:

- `InteropPurgeRefusals.TestTheProcessRolesAreGivenBackOnSuccessAndOnAnError`: legs (a) principal success, (b) principal raising after the vendor's purge and bitmap cleanup, (c) `_SYSTEM` raising with a role added inside. mutation: `New $ROLES` removed -> leg (c) red, alone.
- `InteropPurgeRefusals.TestAPurgeWithoutTheSqlDeleteRightsAnswersTheVendorsFailure`: a principal with `%DB_USER:RW` and no SQL delete rights gets 500, never 200, and a row with `completed` false. mutation: `PerformPurge` ignores the vendor's status -> red (answered 200).
- `InteropPurgeRefusals.TestDaysAtTheEdgeOfTheCalendarReachTheVendorAsAPurgeOfNothing`: the clamp at its boundary. mutation: the clamp at `+$Horolog - 1` -> red (67,895 and 99999 reached the vendor as 67,895).
- `InteropPurgeElsewhere.TestThePurgeConfirmedElsewhereIsRefusedWhileItsOwnNamespaceIsPurging`, and the setting leg's read-back verdict. mutation: `PurgeFacts` and `PerformPurge` take the lock in the request's namespace -> red (the purge ran in USER while USER's lock was held).
- `InteropPurgeSettingControl.TestADescriptionKeepsItsLineBreaks` and the component spec's purge description case. mutation: `PerformPurgeSetting` judges by `ConfigSettingRules` -> red (400 `CONFIG.SETTING.VALUE`); the page's purge `multiline` clause never matching -> the component case red.
- `InteropPurgeControl`: the success row's `completed` true and the script form's clamped days at 99999; the component spec's failed-purge case; `interop.test.mjs`'s four purge sentence rows; the browser spec's held-Purge check; two harness tests (a method and a trigger after `PurgeFrame`). mutation: the checker's member reset removed -> the trigger test red.

## Auto Run Result

Status: done
Blocking condition: none

**Final (2026-11-22).** Batch 1 is built, reviewed and verified. Task 0 is under Design Notes, Measured: no vendor audit row; a purge needs SQL delete rights on the Ensemble tables beyond database WRITE; a principal without `%All` keeps its roles across the vendor's bitmap cleanup; integrity, bodies, cutoffs and days 0 as the strings now say (two orchestrator-approved clauses added to `PURGERUN` and `PURGEBITMAP`).

- Files: the port and error classes (`InteropPort.cls`, `InteropError.cls`), two tools, the rules class, two descriptors, entity types, baseline keys, `Prohibited.cls` terms, `Titles.cls`; the client purge page, dialog and settings registration, strings, maps and the regenerated mirror; the EXPERIENCE.md row; four test classes with a fixture and a seam, one browser spec, one component spec, the rosters; the `scripts/check-objectscript.py` allowlist and its harness for `PurgeFrame`; one roster line in `scripts/ci-throwaway.sh`.
- Review: 16 findings (medium 6, low 10): 6 patched and each proved by a mutation run, 10 rejected with reasons in the log; none deferred.
- `followup_review_recommended: true`, because two or more medium findings were patched: the patched test legs (lock release after each outcome, settings read in the proposal's namespace, audit row on an error status, the person's days refusal, the roles leg's principal, the browser spec's count and settings restore) have not been read by a second reviewer.
- Verification on a throwaway rebuilt fresh (`ocupilot-b-ci`): the four new classes green on first run forward and in reverse; the browser pair `interop-purge` and `interop-schedules` green forward and in reverse on the first run of the rebuild; the `(once)` sweep, shards 1 to 17 of 17, green (no known flake fired); the a11y structural spec 13 of 13; `npm run test:tools` 2,395 and `npm run test:components` 3,881; `check-objectscript.py` 0 problems; `lint-docs.sh` clean.
- Residual risks: the AD-9 spine line for `InteropPort.PurgeFrame` lands at story end (deferred); a purge by a principal without SQL delete rights is partial (named limit); business process records and a running production's queue entry were not probed (named limits).
- QA and code review (2026-11-22): 27 findings, see the triage log; patched and verified on a rebuilt `ocupilot-b-ci`: the four purge classes, `ConfirmNamespaceRoster` and `DraftRegistry` green on their first run (7, 3, 8, 6, 3, 9 tests); browser `interop-purge` and `config-settings` green; components 3,883 in four runs; `test:tools` 2,395; the checker 0 problems, its harness 182.

**Implement (Batch 1).** Built on `ocupilot-b-ci` as the Task list says. Verified: the four new classes and the fixture's two seams green on a first full run each (`InteropPurgeSettingControl` 5, `InteropPurgeControl` 8, `InteropPurgeRefusals` 5, `InteropPurgeElsewhere` 2 tests), every mutation above red and reverted, and the rosters the sweep named green (`Descriptor`, `GovernanceBaseline`, `Governance`, `Prohibited`, `DraftRegistry`, `ToolWrite`, `ReadTool`, `SurfaceCoverage`, `StageTwoTools`, `InteropFloor`, `ToolRoundTrip`, `ToolEmit`, `Navigation`, `InteropDescriptor`, `InteropHostDescriptor`, `SaveHoldCoverage`, `ConfirmNamespaceRoster`, `CompositeMintSweep`, `ClassicPageGate`, `MappingDescriptor`, `ToolDispatch`). Client: `npm run build` (2.25 MB initial), `npm run test:tools` (2,395) and `npm run test:components` (3,881) green; the browser pair `interop-purge` and `interop-schedules` green on the rebuilt bundle. `check-objectscript.py` and its harness (180) and `lint-docs.sh` clean. The choices are in Design Notes, Decided in-stage (implement) 5.

**Plan.** Batch 1 of four: Purge data settings and Purge management data through `InteropPort`, each write reached by the screen and the agent, every proposal keeping its namespace and every confirm judging there. Veto items: Design Notes 1 to 9 (the split first). The story-end spine lines and README clauses are under Design Notes. Read-only probes on `ocupilot-b-ci` (52777, identity checked, by a research subagent): the purge classes check no privilege and write no audit row; bitmap cleanup adds `%All` for itself; the stores map to the namespace's own database; USER holds two settings and a description, HSCUSTOM none; `GetAllCounts` reads 0 for every type in both; the purge lock is free. Nothing was written to the instance.
