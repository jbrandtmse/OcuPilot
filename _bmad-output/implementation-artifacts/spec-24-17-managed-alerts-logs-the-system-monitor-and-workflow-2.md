---
title: 'Story 24.17: Managed alerts, logs, the system monitor and workflow (Batch 2: business rule log and business process log)'
type: 'feature'
created: '2026-11-23'
status: 'in-review'
baseline_revision: '2c22660e7d4febe7564aa0feb0130618d86ea6a2'
review_loop_iteration: 0
followup_review_recommended: false
owned_ledger: ''
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-17-managed-alerts-logs-the-system-monitor-and-workflow.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-16-purge-suspended-messages-export-and-the-archive-manager.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** OcuPilot has nothing for the classic Rule Log page (`EnsPortal.RuleLog`) or the Business Process Instances page (`EnsPortal.BPInstances`), so a namespace's business rule log and business process records cannot be listed or purged by age, and nothing round-trips over `Ens_Rule.Log` or `Ens.BusinessProcess`.

**Approach:** Batch 2 of five (Batch 1's Design Notes, Batch split): **Business rule log** and **Business process log**, two lists through `InteropPort`, each with one destructive write, **Purge**, reached by the screen and by the agent, extending Story 24.16's purge family. "Round-trips" means: a purge from either caller removes, through the vendor's own purge, the probe rows older than its days, keeps the newer ones (and, for business processes, a running one), and the list reads the change.

## Boundaries & Constraints

**Always:**

- **One port (AD-62).** `InteropPort` gains `RuleLog` (`LIST`; `RULELOGSTATE`; the write `PURGERULELOG`) and `ProcessLog` (`LIST`; `PROCESSLOGSTATE`; the write `PURGEPROCESSLOG`), both in `SEARCHENDPOINTS`. Reads use `%ExecDirectNoPriv` after the gate, newest first (`ORDER BY ID DESC`), capped, truncation reported (AD-36). Switched by save and restore; no other `OcuPilot.*` class is called while switched, logging included; a fault is logged after the restore.
- **Rows.** Rule log `{ID, TimeExecuted, SessionId, RuleName, ConfigName, IsError, ReturnValue, Reason, Namespace}`, criterion `errors` (`yes`/`no`). Business process `{ID, TimeCreated, TimeCompleted, IsCompleted, ConfigName, SessionId, Namespace}` from `Ens.BusinessProcess` (`%TimeCreated`, `%TimeCompleted`, `%IsCompleted`, `%ConfigName`, `%SessionId`), criterion `completed` (`yes`/`no`). Times as the instance's local time (`LocalStamp`). Each state read `{Count, DaysToKeep, Namespace}`, `Count` the vendor's `RuleLogCount`/`BusinessProcessCount`, `DaysToKeep` empty.
- **Gate (AD-29, AD-8), before any vendor call or value judged; never cached.** Rule log reads: `%Ens_Portal:USE`, `%Ens_RuleLog:USE` (`RuleLog.cls:12`), then `Admit`. Business process reads: `%Ens_Portal:USE`, `%Ens_Jobs:READ` (`BPInstances.cls:12`), then `Admit`. Each purge: its list's pairs plus `%Ens_Purge:USE` (both pages' `EDITRESOURCE`, `:15`, demanded for `DoPurge` by `GetHyperEventResources`, `RuleLog.cls:846-849`, `BPInstances.cls:892-898`) and WRITE on the namespace's globals database. Plus any pair Task 0 (b) measures.
- **Days (AD-56).** `DaysToKeep` judged by `PurgeDaysOK` (0 to 99999), 422 `INTEROP.PURGE.DAYS` with its published sentence, before any vendor call; days past the calendar clamped to `+$Horolog - 2` as `PerformPurge` does.
- **The purges run as the classic pages' `DoPurge` (`RuleLog.cls:690-700`, `BPInstances.cls:570-580`)**, in the proposal's namespace, inside `PurgeFrame` (AD-9's `New $ROLES` containment: `Ens.Rule.Log.Purge`'s `PurgeBitmaps` reaches `%SYS.Maint.Bitmap.OneClass`, which adds `%All` for itself, `Bitmap.cls:181`): `Ens.Purge.PurgeRuleLogsByDate(days, .deleted)` and `Ens.Purge.PurgeBusinessProcessesByDate(days, .deleted, 1)`, integrity always kept. No lock, no transaction, in the confirm or action request (AD-7). A single operation, as the purge: a vendor error status answers 500 `INTERNAL`, never 200, even after a partial delete, and its audit row reads `completed` false.
- **The tools (AD-3, AD-6, AD-10, AD-14, AD-22, AD-34, AD-51, AD-53, AD-58, AD-59).** `interop.rulelog.purge` and `interop.processlog.purge`, extending `InteropPurgeRun`: action-style, `DRYRUN`, `DESTRUCTIVE`, key `false`; target the namespace; `SCREENVALUES` `purge=DaysToKeep`; `FINGERPRINTSUBJECT` `DaysToKeep,Namespace`; no precondition field; consequence `INTEROP.RULELOG.PURGE` / `INTEROP.PROCESSLOG.PURGE`; the screen's Purge types the namespace's name. Classified in `ConfirmNamespaceRoster` and `DraftRegistry`. Each script form shape-checks the days, renders nothing for a bad value, and renders the switch and the vendor call with the clamped days, running none. A screen action mints nothing and is not gated by read-only or the kill switch.
- **Namespace at confirm (AD-52).** Each stored proposal carries `Namespace`; every confirm-time judgment (the fresh read, the days, the vendor call) runs there, whichever namespace the confirm is sent from.
- **Audit (AD-15).** The agent's marker on the agent's write; OcuPilot's own `ConfigChange` from either caller through `AuditRuntime`, after the restore, naming the namespace, the days asked, the vendor's deleted count and `completed`.
- **Bounds.** `RULELOGMAX` and `PROCESSLOGMAX` (provisional 2,000, the classic page-size maximum; Task 0 (e) sets each), boundary-tested at the cap and one over through a seam. A purge has no row cap: the purge family's named limit (AD-7, veto item 5).
- **README.** The switched-off count rises by two and the off list gains this batch's clause (veto item 1), in the same commit as the keys.
- **Rosters.** `interop-rule-log` then `interop-process-log` after feature's last entries in `TYPES` and `COVEREDTYPES`; their `Prohibited.cls` terms appended; no earlier type reaches a different arm (a pinning test). Every pinned roster is in the Code Map.

**Never:**

- `Ens.Purge.PurgeAll`, `KillGlobals`, the per-class `%DeleteId`, an SQL `DELETE` of OcuPilot's own, `^IRIS.Temp.EnsPurgeAll`, `%RunBackgroundMethod` or `JOB`; any `EnsPortal.*` call in product code; a keep-integrity choice.
- A vendor status text in a log (`LogFault` gets a fixed message and the codes).
- `Set $ROLES`, `AddRoles`, or a `New $ROLES` outside `PurgeFrame`; a change to `scripts/check-objectscript.py`'s rule 6 entry.
- Batches 3 to 5's surfaces; the README's Interoperability paragraph (Batch 5); a spine edit.
- `src/OcuPilot/Api/Error.cls` (frozen; codes go in `InteropError.cls`); `ui/angular.json`; `ui/vitest-base.config.mjs`; `scripts/ci-throwaway.sh` beyond add-only `# classes:` lines, never its bring-up retry block; `Prohibited.cls` beyond appended terms; `shell/screen-action-handler.ts`, `shell/warning-dialog.ts`, `shell/screen-action-dialogs.ts` beyond add-only map entries; any non-add-only edit to a file marked (c).

## I/O & Edge-Case Matrix

Route namespace USER. Probe rule log rows carry `RuleName` `OcuProbe2417`; probe business processes carry `%ConfigName` `OcuProbe2417` (class per Task 0 (c)); "old" is back-dated 7,300 days, a probe purge uses `DaysToKeep` 3650. HSCUSTOM holds its own probes.

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Lists | Old and new probes, errors and not, completed and running | Each lists its probes newest first; `errors=yes` the errors only; `completed=no` the running only | - |
| Purge rule log, both callers | Old and new probes, one with a debug row | Old gone with its debug row, new kept, `Count` falls by the old; one `ConfigChange` each | - |
| Purge processes, both callers | Old completed, old running, new completed | Old completed gone; old running and new kept | - |
| Days | -1, 1.5, 100000, `x`, empty | Refused; nothing deleted | 422 `INTEROP.PURGE.DAYS` (person: 400 `TOOL.ARGUMENTS`, as the purge) |
| Gate | No `%Ens_RuleLog:USE` / `%Ens_Jobs:READ`; no `%Ens_Purge:USE`; no database WRITE | Refused before any vendor call | 403 naming the pair |
| Vendor error | The seam answers an error status after deleting one probe | Never 200; audit `completed` false; no vendor text logged | 500 `INTERNAL` |
| Roles | Seam adds a role, then succeeds; then raises | `$ROLES` after equals before, both paths | - |
| Confirm elsewhere | Minted in USER, confirmed with `?ns=HSCUSTOM`, both holding old probes | Acts in USER only; HSCUSTOM's probes kept | - |
| Cap | Seam cap 3: three probes, then four | Three; four listed as three with truncation | - |
| Script | Each draft; days `x` | Renders the switch and the vendor call with the days, runs nothing; `x` renders no draft | - |

</intent-contract>

## Code Map

Paths under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-24` (HEAD `26cc156bf`). **(c)** marks a file Epic 21 changed beyond feature (`git log --no-merges origin/OCU-1-epic21 ^origin/feature/OCU-1_ocupilot-mvp`, at plan): `EntityType.cls`, `Baseline.cls`, `Prohibited.cls`, `strings.ts`, `screens.generated.ts`, `screen-actions.ts`, `proposal-view.ts`, `screen-action-handler.ts`, `screen-action-dialogs.ts`, `warning-dialog.ts` and the test rosters `ClassicPageGate`, `CompositeMintSweep`, `Descriptor`, `Governance`, `GovernanceBaseline`, `MappingDescriptor`, `Prohibited`, `ReadTool`, `SurfaceCoverage`, `ToolRoundTrip`, `ToolWrite`. Add-only there; re-check before editing.

- **`Port/InteropPort.cls`** (13,961 lines; sibling Story 24.16's purge family :10017-10523, extend it, Rule 31): `ENDPOINTS` :128, `SEARCHENDPOINTS` :242, `IsAnyWrite` :1223, `Pairs` :1253 (purge arms :1265-1268), `Serves` :1338 (:1354-1355), `Invoke` :1460 (:1526-1531), `Admit` :1606, `SqlRows` :4451, `LocalStamp` :4383, `RefuseCriterion` :4645, `AuditRuntime` :6988, `SnippetForm` :7000 (:7011), `Snippet` :7035 (:7043-7044), `PurgeDaysOK` :10247, `InvokePurge` :10340, `VendorCodesStatus` :10381, `PurgeFrame` :10399 (gains a trailing optional kind; `""` calls `VendorPurge` unchanged, a log kind a new overridable `VendorLogPurge(pKind, pDays, Output pDeleted)`), `PerformPurge` :10424 (shape of the new performs), `PurgeSnippet` :10509, `ListAlerts` :11399 (shape of the new lists, criterion and cap via `AlertCap`).
- **Vendor (read-only, read at plan):** `irislib/Ens/Purge.cls` (:77-85, counts :110-120, `GetDoNotDeleteDate` :213); `irislib/Ens/Rule/Log.cls` (properties :15-63, `Purge` :101-120, debug-row trigger :123-133); `irislib/Ens/Rule/RuleLog.cls` :95-107 (also purged); `irislib/Ens/BusinessProcess.cls` (properties :97-115, `Purge` :1182-1243: integrity keeps rows not `%IsCompleted`, a failure `$$$LOGWARNING`s and continues); `irislib/Ens/Util/BitmapPurge.cls` :18-93; `irissys/%SYS/Maint/Bitmap.cls` :163-191; `irissys/%sySecurity.inc` :426; `irislib/EnsPortal/RuleLog.cls` (`RESOURCE` :12, `EDITRESOURCE` :15, table :154-192, page sizes to 2,000 :220-222, `DoPurge` :690-700, hyper-event :846-849; its Errors box is not applied by `CreateResultSet` :291-384); `irislib/EnsPortal/BPInstances.cls` (`RESOURCE` :12, `EDITRESOURCE` :15, table :133-171, `DoPurge` :570-580, hyper-event :892-898). No vendor call here audits or switches namespace (read; Task 0 (a) measures).
- **`Api/InteropError.cls`:** consequences `RULELOGPURGE` (`INTEROP.RULELOG.PURGE`) and `PROCESSLOGPURGE` (`INTEROP.PROCESSLOG.PURGE`) beside `PURGERUN` :538, joined into `ConsequenceCodes` :861 and a `LogPurgeCodes` list beside `PurgeCodes` :981, `ReasonFor` arms beside :1219. No new refusal code.
- **Tools (new, `Screen/Tool/`):** `InteropRuleLogPurge`, `InteropProcessLogPurge` extending `InteropPurgeRun` (`Screen/Tool/InteropPurgeRun.cls`): override `TOOLNAME`, `DESCRIPTION`, `DESCRIPTORCLASS`, `READTYPE`, `READANSWERS` (`Count,DaysToKeep,Namespace`), `WRITETYPE`, `CLASSICPAGES` (`EnsPortal.RuleLog` / `EnsPortal.BPInstances`), `STATEMARKER`, `FINGERPRINTSUBJECT`, `PRECONDITIONFIELD`/`CODES` (empty), `CONSEQUENCECODE`, `Consequence`, `DryRunReview` (`Count`), `Endpoint`; inherit the days rules, `PortQuery`, `ArgumentProblem`, `ScreenActionDelta`, `InputSchema`.
- **Descriptors (new):** `Screen/Descriptor/InteropRuleLogList.cls` (route `interoperability/rule-log`, side bar 23, `list`, scope `namespace`, entity `interop-rule-log`, row action `purge`, `classicPage` `EnsPortal.RuleLog`, `toolIdentifier` `interop.rulelog`, criterion `errors` with `interopMessagesCriterionErrors`); `Screen/Descriptor/InteropProcessLogList.cls` (route `interoperability/process-log`, side bar 24, entity `interop-process-log`, `classicPage` `EnsPortal.BPInstances`, `toolIdentifier` `interop.processlog`, criterion `completed`); each modeled on `InteropPurgeList.cls` and `InteropManagedAlertList.cls`, `ownPrivileges` the classic `RESOURCE`. Columns reuse `interopColumnId`, `auditColumnTime`, `webSessionColumnSession`, `explorerSqlColumnRule`, `auditEventFieldSource` (`ConfigName`), `errorLogColumnText` (`IsError`, status), `explorerSqlColumnReturnValue`, `agentSwitchesFieldReason`, `journalColumnCreated`, `taskHistoryColumnCompleted` (`TimeCompleted`); `IsCompleted` takes the new "Is completed".
- **Kernel:** `Kernel/EntityType.cls` (c) :178 and the doc beside :126, both types after `interop-managed-alert`, each one namespace's log keyed by its name as `interop-purge`; `Kernel/Governance/Baseline.cls` (c) two keys `false` in name order; `Kernel/Proposal/Prohibited.cls` (c) append-only: two `TYPE*` after :909, `COVEREDTYPES` :338 last, the uncovered chain :1806 extended at its end, two `ReviewedFewOnly` arms after :2289-2292.
- **Client (`ui/src/app/`):** one page for both lists, sibling `areas/interoperability/interop-purge-list.page.ts` (registers Purge, `dryRunFor` then `sendFor` on the namespace, :93-140), and the dialog `interop-purge-dialog.ts` extended to show `Count` (`interopColumnCount`) in place of the settings, or a copy with its reason recorded; `shell/screen-outlet.ts` registrations; `shell/screen-action-handler.ts` (c) add-only (`DRY_RUN_ACTIONS` :555, page actions :709, typed-name and consequence maps); `core/screen-actions.ts` (c); `core/proposal-view.ts` (c); `core/strings.ts` (c); regenerate `screens.generated.ts` (c) and `Screen/Titles.cls`.
- **Tests (new; principal legs armed by `OCUPILOT_ALLOW_PRINCIPALS`, one add-only `# classes:` line in `scripts/ci-throwaway.sh`):** case `Test/InteropLogPurgeCase.cls` (refuses to start while either namespace holds a rule log or business process row older than 3,650 days that is not a probe; drops probes in both namespaces before and after every test); fixture `Test/InteropLogPurgeFixture.cls` (`ProbeRule`, `ProbeProcess`, `DropProbes` by marker, a probe principal as `InteropAlertFixture`); seam `Test/InteropLogPurgeSeam.cls` extending `InteropPort` (`VendorLogPurge` modes: status after one delete, throw, a role added then success or a raise; captured `LogFault`; caps lowered to three); `InteropLogList` (both lists, criteria, both readers, caps), `InteropLogPurgeControl` (both purges from both callers, integrity, debug rows, counts, audit, drafts), `InteropLogPurgeRefusals` (days, gate as principals, vendor error, throw, `$ROLES` legs, nothing logged while switched, no vendor text logged), `InteropLogPurgeElsewhere`; each under 500 lines. Browser `ui/browser/interop-log-purge.browser-spec.mjs` (sibling `interop-purge.browser-spec.mjs`); component specs for the page and dialog.
- **Rosters (Rule 30; re-grep `interop.purge.run`, `InteropPurgeRun`, `interop-purge`, `InteropPurgeList`, `ManagedAlerts` across `src/OcuPilot/Test`, `ui/tools`, `ui/browser`, `ui/src`, `scripts/`):** `ConfirmNamespaceRoster` `CHECKEDFLOOR` :34 128 → 130; `DraftRegistry` `ARGUMENTVALUES` :71 and `TYPEDTARGETIDS` :60; `ToolWrite` (c); `Descriptor` (c); `SurfaceCoverage` (c); `StageTwoTools`; `InteropFloor`; `GovernanceBaseline` (c, `DISABLED`); `Governance` (c); `Prohibited` (c); `ReadTool` (c); `ReadDescriptions`; `ToolRoundTrip` (c); `ToolEmit`; `ClassicPageGate` (c); `MappingDescriptor` (c); `CompositeMintSweep` (c); `DryRunRoute`; `InteropDescriptor`; `Navigation`; `InteropHostDescriptor` (`ENDPOINTS`); `InteropMessageDescriptor` :201 (`SEARCHENDPOINTS`); `ui/tools/interop.test.mjs` (sentence rows, and :365-391's README count and off-list clause); `screen-mirror.test.mjs`; `navigation.test.mjs`; `ci.test.mjs`. After any union with feature or Epic 21, check the entity-type order against every pinned assertion. No new route.
- **`README.md`** :164 (the count) and :182 (the off list); **EXPERIENCE.md** (c): one Fixed strings row after the managed alerts row (:633), once the strings are ruled.

## Tasks & Acceptance

**Execution:**

- [x] **Task 0** (`ocupilot-b-ci` only, USER and HSCUSTOM, auditing on; every probe row, user and role removed after; record under Design Notes, Measured): (a) each vendor purge, run inside `PurgeFrame`, writes only the namespace's own database (journal by process id) and no vendor audit row (with a positive control); whether `Ens.Rule.Log`'s purge reaches `OneClass` (a `%SYS_Maint.Bitmap` row); `$ROLES`, `$USERNAME` and `$NAMESPACE` before and after for a principal without `%All` and for `_SYSTEM`; (b) a principal holding `%Ens_Portal:U` and `%Ens_RuleLog:U` (then `%Ens_Jobs:R`) and `%DB_USER:R` reads each list through `%ExecDirectNoPriv`, and the classic page's own query (`RuleLog.cls:374-377`, `BPInstances.cls:635-647`, prepared as that principal through `%Library.ResultSet`) answers rows or an SQL privilege refusal; with `%Ens_Purge:U` and `%DB_USER:RW` each purge succeeds, with `%DB_USER:R` what the vendor answers; name any further pair; (c) which class a fixture can save business process probes as in both namespaces (`Ens.BusinessProcess` itself first: `OcuPilot.Test` classes are not compiled in USER, measured at plan) with a back-dated `%TimeCreated`, and that the vendor purge deletes an old completed one, keeps an old running one and a new one; that back-dated rule log rows (with a `DebugId` debug row) are purged with their debug rows; (d) days 0: today's rule log rows deleted; today's completed business process deleted, a running one kept; (e) each list read's time at 1,000 and 2,000 probes: the cap is the larger whose read ends within 5 s here (7.5 s on CI at 1.5 times), never above 2,000; and each purge's time over 10,000 rule log rows and 2,000 business processes, recorded for the named limit. HALT `blocked` if a read writes data; if `$ROLES`, `$USERNAME` or `$NAMESPACE` differs after `PurgeFrame` returns; if (a) finds a vendor audit row or a write outside the namespace's database; if (b) finds the classic query needs an SQL privilege the gate does not ask (`## Clarification Needed`: security posture); if (c) finds no class that saves and purges in both namespaces (`intent gap: fixture`); if (d) measures otherwise than the consequences say (`intent gap: new string`); or if 1,000 does not fit (e).
- [x] `src/OcuPilot/Port/InteropPort.cls`, `src/OcuPilot/Api/InteropError.cls` -- the two endpoints, gate, lists, state reads, both purges through `PurgeFrame`, snippets, consequence codes -- one port, the purge family extended.
- [x] `src/OcuPilot/Screen/Tool/InteropRuleLogPurge.cls`, `InteropProcessLogPurge.cls`, the two descriptors, `EntityType.cls`, `Baseline.cls`, `Prohibited.cls` -- the tools, screens, types, keys and terms.
- [x] `ui/src/app/areas/interoperability/` page and dialog, the add-only maps, strings and outlet registrations; regenerate the mirror and titles; the EXPERIENCE.md row; `README.md` count and off-list clause with `ui/tools/interop.test.mjs`'s clause.
- [x] `src/OcuPilot/Test/InteropLog*.cls`, `ui/browser/interop-log-purge.browser-spec.mjs`, the component specs, the `# classes:` line and the rosters the sweep names -- the matrix, either order.

**Acceptance Criteria:**

- **AC1 (lists).** Given USER's rule log and business process probes, when a person opens Business rule log and Business process log and the agent reads both, then each lists exactly its probes newest first, `errors=yes` the errors only and `completed=no` the running only.
- **AC2 (purge, both callers).** Given old and new probes, when a person's Purge and the agent's confirmed proposal each run with `DaysToKeep` 3650, then the old rule log probes and their debug rows and the old completed business process are gone, the new probes and the old running business process remain, the lists and `Count` read the change, and each purge has one `ConfigChange` naming the namespace, the days, the count and `completed` true.
- **AC3 (refusals and gate).** Given each refusal row of the matrix, when either caller purges, then the named code answers before any vendor call and nothing is deleted.
- **AC4 (vendor error).** Given the seam's error status after a partial delete, when either caller purges, then the answer is 500 `INTERNAL`, never 200, the audit row reads `completed` false, and no log line carries a vendor text.
- **AC5 (roles contained, AD-9).** Given the seam adds a role inside the vendor call, when a purge succeeds and when it raises, then `$ROLES` after equals `$ROLES` before.
- **AC6 (the proposal's namespace; Integration, Rule 1).** Given old probes in USER and HSCUSTOM, when each agent purge is minted in USER and confirmed from HSCUSTOM, then it acts in USER only and HSCUSTOM's probes remain.
- **AC7 (rosters, script, switched).** Given the two tools, when `ConfirmNamespaceRoster`, `DraftRegistry` and `Prohibited` run, then each is green with its rows and red with one removed; each draft renders the switch and the vendor call and nothing for bad days; and nothing is logged while switched.
- **AC8 (README).** Given the two `false` keys, when `interop.test.mjs` runs, then the README's count and off-list clause hold, and red with the count one less.
- **AC9 (browser).** Given a fresh instance, when a person purges each log with 3650 days on its screen, typing the namespace's name, then the old probe leaves the list and the new one stays.
- **AC10 (fresh, either order).** Given any new or changed test, run first on a fresh instance in either order, when it ends, then no probe row, user or role remains in either namespace.

## Spec Change Log

## Review Triage Log

### 2026-11-25, code review (Opus; four layers; `19c85b326..b20dd9c24`, patched on HEAD `7cf604bee`)

No HIGH. Runs are on `ocupilot-b-ci`.

- **R1 MED, escalated (Clarification Needed).** Gating the state read with the SQL check also gates both purge callers for a principal who holds the purge pairs but no grant: the screen's review and the agent's mint and confirm read the state first. The classic page counts and purges without SQL privilege (`RuleLog.cls:682-700`). Measured: `RuleLogCount` and `BusinessProcessCount` answered for a principal whose `CheckPrivilege` read 0. Kept as built.
  - Ruled (a) by the lead; patched in the rework.
- **R2 MED, patched.** The log reads' faults logged vendor text (`Mapped`), against the Never list. Now `LogMapped`. Mutation run 994.
- **R3 MED, patched.** `Foreign` missed the vendor's id-based business process selection. Probe: a completed non-probe process created today in `USER`. Patched, the class refused to start (run 998). The old predicate let it start, and its purge deleted that process (run 999).
- **R4 MED, patched.** The state leg of the "nothing logged while switched" test raised in the privilege check, never in `ReadLogState`'s own block. The seam now has a `herestate` mode. Mutation run 993.
- **R5 MED, patched.** The SQL equality test ran in `USER` only and never asserted the login. Added: `HSCUSTOM` legs, `loggedIn`, and a database-only principal. Mutation run 995.
- **R6-R10 LOW, patched.**
  - R6: `CreateGated` reports a failed grant.
  - R7: the process agent leg gains the rule leg's assertions.
  - R8: roles legs for a principal without `%All`, on an error status and on a raise. Regression evidence only, because such a principal cannot change its roles.
  - R9: stale doc comments and spec claims corrected (Decided (implement) 2 and 5).
  - R10: unused test helpers removed.
- **Closed:**
  - R11 `wontfix-theoretical`: a `CheckPrivilege` status read as 403. `reopen_if`: a caller with the grant is refused naming the table.
  - R12 `wontfix-accepted`: `maxRows` is judged before the SQL check. `reopen_if`: a 400 where 403 named the table.
  - R13 `by-design`: no hard cap over the caller's `maxRows` (the `AlertCap` family).
  - R14 `wontfix-theoretical`: `<PROTECT>` text kept. The gate demands WRITE first.
  - R15 `by-design`: the business process sentence omits the vendor's id-based selection, and the rule log sentence omits debug rows (V1-ruled strings). `reopen_if`: process ids out of creation order.
  - R16 `wontfix-accepted`: the component spec stubs a 409 these purges never send.
  - R17 `by-design`: the page's flags on a reject repeat the sibling page.
  - R18 `by-design`: `strings.ts` citation renumbered, `ci-throwaway.sh` comment lines added.
  - R19 `wontfix-accepted`: the snippet renders the clamp as text.
  - R20 `false`: governance hermeticity. `ci-runner.mjs` sets the policy aside per class; the test stayed green with both keys stored on.
  - R21 `wontfix-accepted`: revoke results are not asserted, because REVOKE answers SQLCODE 100 when already revoked. The rebuild holds no `OcuP2417*` user, role or SQL privilege. `reopen_if`: one appears.
  - R22 `false`: Rule 19 asks one mutation per AC.
  - R23: `CHECKEDFLOOR` recommended at 152 (measured on HEAD), not edited.
  - R24 `by-design`: the `{Namespace}` fallback.
- **R25 MED, ledger candidate.** Story 24.16's `PerformPurge` writes no audit row when the vendor raises (AD-15). Owner: burndown.

## Veto items

Each is the lead's to take to the veto gate; the recommended option is first.

1. **New user-facing strings** (reused, each read true here: "Purge" (`auditDatabasePurgeConfirm`), "Older than (days)" (`auditDatabasePurgeDays`), "Older than (days) is a whole number from 0 to 99999." (`INTEROP.PURGE.DAYS`), "Count" (`interopColumnCount`), "ID" (`interopColumnId`), "Time" (`auditColumnTime`), "Session" (`webSessionColumnSession`), "Rule" (`explorerSqlColumnRule`), "Source" (`auditEventFieldSource`), "Error" (`errorLogColumnText`), "Return value" (`explorerSqlColumnReturnValue`), "Reason" (`agentSwitchesFieldReason`), "Created" (`journalColumnCreated`), "Completed" (`taskHistoryColumnCompleted`), "Marked as an error" (`interopMessagesCriterionErrors`)):
   - Labels: "Business rule log" · "Business process log". Column and criterion: "Is completed".
   - Consequences (provisional until Task 0 (d)): `RULELOGPURGE` "Deletes this namespace's business rule log entries older than the days to keep. With 0 days, everything up to the end of today is deleted. It cannot be undone." · `PROCESSLOGPURGE` "Deletes this namespace's completed business process records older than the days to keep; a business process still running is kept. With 0 days, every completed one up to the end of today is deleted. It cannot be undone."
   - Empty states: "No business rule log entries in this namespace." (agent phrase "purge the business rule log") · "No business process records in this namespace." (agent phrase "purge business process records").
   - Prompts: "Which rules returned an error recently?" · "Which rule fires most often here?" · "Purge business rule log entries older than 30 days." · "Which business processes are still running?" · "Which business process has the most records?" · "Purge completed business process records older than 30 days."
   - README :164, "Ninety-six agent actions ship switched off" becomes "Ninety-eight agent actions ship switched off" (the number `interop.test.mjs` derives: the Baseline's `false` keys less the people-only keys; if Epic 21's Story 21.31 has landed on feature by the integrate, the integrate re-derives it); README :182, "purging interoperability management data," becomes "purging interoperability management data, the business rule log or the business process log,", and `interop.test.mjs`'s off-list assertion takes the same text.
2. **Governance keys and confirm.** `interop.rulelog.purge` and `interop.processlog.purge` ship `false`, destructive: the card's destructive treatment, and the screen's Purge types the namespace's name, as Story 24.16's purge.
3. **Security posture.** Lists: `%Ens_Portal:USE` and the classic page's `RESOURCE` (`%Ens_RuleLog:USE`, `RuleLog.cls:12`; `%Ens_Jobs:READ`, `BPInstances.cls:12`), then READ on the namespace's globals database, read with `%ExecDirectNoPriv` as AD-62's message reads (Task 0 (b) compares the classic query's SQL privilege). Purge: plus `%Ens_Purge:USE` (`:15` and the hyper-event check) and WRITE on the namespace's globals database, which the classic page does not name (stricter, as Story 24.16's purge; inference until Task 0 (b)). Alternative: the resource pairs alone.
4. **Values narrower than the classic pages.** Days a whole number from 0 to 99999, refused otherwise (the classic pages accept any number that is not negative, a fraction included); the business process purge always keeps integrity, the classic page's own call, with no switch offered.
5. **The purge's bound.** No row cap: a purge runs to its end in the request, its answer lost past the Web Gateway's timeout and its audit row written then (AD-7's purge named limit; the classic `DoPurge` runs in its request too); Task 0 (e) records the rate. Alternative: count first and refuse above a measured cap, with a new refusal sentence.
6. **AD amendments (story end, the lead writes them, add-only, `[AMENDED <date>, Story 24.17, Rule 20]`).** AD-62, the item after Batch 1's: "**Business rule log and business process log** (Story 24.17). `InteropPort` gains `RuleLog` over `Ens_Rule.Log`, behind `%Ens_RuleLog:USE`, and `ProcessLog` over `Ens.BusinessProcess`, behind `%Ens_Jobs:READ`, the classic pages' `RESOURCE`, each read newest first and capped, and a purge of each by days, `Ens.Purge.PurgeRuleLogsByDate` and `PurgeBusinessProcessesByDate` with integrity kept, behind `%Ens_Purge:USE` and WRITE on the namespace's globals database, its days judged before any vendor call." AD-9, after the second `New $ROLES` paragraph's first sentence: "`PurgeFrame` also contains the business rule log and business process purges (Story 24.17): the rule log purge's bitmap compaction adds `%All` for itself, as the full purge's does." AD-7: "**A business rule log or business process purge (Story 24.17)** runs in its confirm or action request, as Story 24.16's purge does; one that outlasts the Web Gateway's response timeout runs to its end in that request's process, and its answer is lost (named limit)." AD-15, named case: "**A business rule log or business process purge** (Story 24.17), which the vendor does not audit, records OcuPilot's own `ConfigChange` from either caller: the namespace, the days, the count deleted and whether it completed." AD-22: "**Story 24.17's Batch 2 keys:** `interop.rulelog.purge` and `interop.processlog.purge` ship `false`."

No new dependency; no privilege, role or access grant; nothing is written into another namespace.

**Lead rulings at the spec gate (2026-11-24; filed as an INBOX veto item, binding unless the orchestrator reverses them).** Every veto item is kept as recommended:

- **V1:** kept. If Task 0 (d) measures a consequence sentence untrue, HALT with `## Clarification Needed`; never reword it in-stage. The README count is never typed from this plan: derive it from the merged Baseline on the tree you commit. If Story 21.31 lands on feature first, the lead's integrate re-derives it.
- **V2:** kept. Both keys ship `false`, behind the typed namespace name.
- **V3:** kept. If Task 0 (b) shows the classic query needs an SQL privilege the gate does not ask for, HALT; never widen it quietly.
- **V4:** kept, the narrower values.
- **V5:** kept, as Story 24.16's AD-7 named limit for a purge. Task 0 (e) records the rate.
- **V6:** kept for story end; the lead writes the lines. The AD-9 line extends `PurgeFrame`'s containment to these purges and still never lets OcuPilot add a role. It also names, as that escalation's known effect, the vendor's own maintenance records: the `^%SYS.Maint.BitmapD` and `^%SYS.Maint.BitmapResultsD` rows and the `%SYS_Maint.Bitmap` row. Story 24.16's purge falls under the same line.

**Orchestrator rulings after Task 0's V3 halt (2026-11-24).**

- **V3: option 2.** Both list reads check the user's effective SQL SELECT on their table (`Ens_Rule.Log`, `Ens.BusinessProcess`) and refuse by name before the read, with the existing `AUTH.NOPRIVILEGE` shape.
  - Read the privilege through the vendor's own check, run in the target namespace (`$SYSTEM.SQL.Security.CheckPrivilege`, or this build's equivalent read from the class source). Never parse grants yourself, so roles, `%All` and grants through a role resolve the vendor's way.
  - Pin it by equality with the classic behavior. For each probe principal (with the grant, without it, `%All`), the check's verdict equals whether the classic `%Library.ResultSet` prepare answers `#5580`. Record that table here, under Measured.
  - An agent read refused this way names the missing privilege in plain words, reusing the existing `AUTH.NOPRIVILEGE` sentence. If no published sentence fits, HALT for a veto addendum.
  - The purges are unaffected.
- **The bitmap bookkeeping writes** are confirmed as the vendor's own maintenance records, written by the code `PurgeFrame` contains. They are not an OcuPilot write into another namespace, and not an AD-9 store.
- **Accepted:** V5 (worst case 0.90 s at 1.5 times, so no cap), both list caps at 2,000, and `PRECONDITIONFIELD = "Namespace"`.
- **Story 20.9's message reads:** ledgered as DW-2865 (burndown). Not widened here.

## Design Notes

**Decided in-stage (plan).**

1. Epic context reused as committed: only EXPERIENCE.md is newer (Batch 1's rework row), and this plan read its purge and managed alerts rows directly; no recompile, since this dispatch commits the spec alone.
2. Names: endpoints `RuleLog` and `ProcessLog` (`Processes` is the BPL class list); types `RULELOGSTATE`, `PURGERULELOG`, `PROCESSLOGSTATE`, `PURGEPROCESSLOG`, unique because `IsAnyWrite` reads a type port-wide; routes `interoperability/rule-log` and `interoperability/process-log`.
3. Purge is the page's own action on the namespace, declared as a row action, as Story 24.16 Batch 1's Decided in-stage (implement) 5(a) and 5(e).
4. No lock: the classic pages take none, and `^IRIS.Temp.EnsPurgeAll` is the full purge's; a log purge beside it deletes the same rows by id (inference).
5. `PurgeFrame` gains a trailing optional kind; `VendorPurge` keeps its signature, so `InteropPurgeSeam`'s override and the checker's rule 6 entry are unchanged.
6. The rule log's `errors` criterion is applied by the port, though the classic page draws an Errors box it never applies.
7. `Count` is in the state read and the dialog (the classic "Current Count") and not in the fingerprint: rules and processes add rows continuously, so it would close every proposal as moved.
8. The answer of a purge is the state read again; the deleted count is in the audit row, so no new result string.
9. The base table `Ens.BusinessProcess` only; the classic page's per-class table and Context column (`BPInstances.cls:757-803`) are not offered (named limit).
10. Siblings (Rule 31): the purge family (`PerformPurge`, `PurgeFrame`, `PurgeSnippet`), `ListAlerts` (list, criterion, cap), `InteropPurgeRun` (tools), `InteropPurgeList`/`InteropManagedAlertList` (descriptors), `interop-purge-list.page.ts`/`interop-purge-dialog.ts` (client), `InteropPurgeSeam` and `InteropAlertCase`/`InteropAlertFixture` (tests).
11. Side-bar positions 23 and 24, after Managed alerts.
12. The README's Interoperability paragraph waits for Batch 5, per Batch 1's split; only the count and the off-list clause land here, because `interop.test.mjs` reddens without them.
13. Story 24.21's harvested `rule_log` and `get_business_process_instance` stay its own; these are the screens' declared reads.

**Decided in-stage (implement).**

1. `PRECONDITIONFIELD` is `Namespace` (the orchestrator's ruling), and `PRECONDITIONCODES` is `INTEROP.NAMESPACE`, not empty: the fresh read's one refusal, a namespace that runs no interoperability, is answered with that code as every sibling write tool lists it.
2. The SQL SELECT check gates the two lists only; the state reads, which are the purges' fresh read, take no SQL check, as the classic page and the V3 ruling say.
3. No `LogPurgeCodes` list: the log purges answer no code beyond `INTEROP.PURGE.DAYS`, which `PurgeCodes` already lists, so a list would only repeat it. The two consequence codes join `ConsequenceCodes`.
4. `InteropProcessLogPurge` extends `InteropRuleLogPurge`, which extends `InteropPurgeRun`; it overrides only what differs (name, description, descriptor, types, page, consequence, endpoint).
5. A purge that raises is audited as `completed` false with the count the vendor had reached, as a purge the vendor answers an error status is; the sibling full purge writes no audit row for a raised error.
6. `PurgeFrame` gained the trailing optional `pKind`; `VendorLogPurge(pKind, pDays, Output pDeleted)` is the new seam, called only from the frame. A `LogHere()` hook sits inside the switched blocks of the privilege check and the state read, as `AlertHere()` does for Batch 1, so a test can prove nothing is logged there.
7. The list's criterion refusal for `completed` is the port's generic sentence `completed is not valid.`, the same fallback `open` takes; no new string.
8. The test suite adds `InteropLogPurgeGate` (principal legs and the SQL equality) and `InteropLogPurgeChild` (the child process) beside the four named classes, to hold each class under 500 lines. The arming roster line names the case class alone.
9. `ui/tools/screen-mirror.mjs` was run to regenerate `screens.generated.ts` and `Titles.cls`, the generator the spec names; every other file was written with Edit or Write.

**Decided in-stage (review).**

1. The log reads' faults go through a new `LogMapped` (the `AlertMapped` shape), so no vendor text reaches the log.
2. `Foreign` counts every non-probe completed business process, or one with no creation time, whatever its age, because the vendor's integrity-kept purge selects by id below the newest old record.
3. The SQL check gates the lists only (R1, ruled (a)).

**Measured at plan (`ocupilot-b-ci`, read-only global and dictionary reads).** USER and HSCUSTOM hold no `^Ens.Rule.LogD` or `^Ens.BusinessProcessD` data; `OcuPilot.Test.InteropAlertCase` is compiled in HSCUSTOM and not in USER; `Ens.BusinessProcess` is not abstract.

**Measured (Task 0, `ocupilot-b-ci`, 2026-11-24, USER and HSCUSTOM, auditing on, probes marked `OcuProbe2417`; every probe row, user, role, resource and the probe class removed after; both namespaces hold no rule log or business process row; HALT at (b)).** The session ran as `irisowner`; principals ran in a child job after `$System.Security.Login`.

- (a) Both vendor purges, run in a frame that saves `$ROLES`, wrote no vendor audit row (`%SYS.Audit` read since the start; positive control, a resource create and delete, wrote two `%System/%Security/ResourceChange` rows). Journal records by process id: the business process purge wrote only the namespace's own `^Ens.BusinessProcessD` and `^Ens.BusinessProcessI` (plus, cold in HSCUSTOM, the instance's SQL statement index `^%SYS` and `^rINDEXSQL`). The rule log purge wrote the namespace's `^Ens.Rule.LogD`, `^Ens.Rule.LogI` and `^Ens.Rule.DebugLogD`/`I` and, because `Ens.Rule.Log.Purge` reaches `%SYS.Maint.Bitmap.OneClass`, `^%SYS.Maint.BitmapD` and `^%SYS.Maint.BitmapResultsD` in the instance's manager database: one `%SYS_Maint.Bitmap` row, status Finished, per purge. The business process purge reaches no bitmap cleanup. A list read wrote no journal record.
- (b) A principal holding `%Ens_Portal:U`, `%Ens_RuleLog:U` and `%DB_USER:R` (and one holding `%Ens_Portal:U`, `%Ens_Jobs:R` and `%DB_USER:R`) read each list through `%ExecDirectNoPriv`; the classic page's own query (`RuleLog.cls:374-377`, `BPInstances.cls:635-647`), prepared as that principal through `%Library.ResultSet`, was refused: `ERROR #5580: SQL Privilege Violation`. A principal holding only `%DB_USER:RW` is refused alike. In USER, SELECT on `Ens_Rule.Log` is granted to `%EnsRole_Operator` and `%EnsRole_RulesDeveloper`, and on `Ens.BusinessProcess` to `%EnsRole_Operator`: the SQL privilege is a table grant the gate's pairs do not name. Purges: with `%Ens_Purge:U` and `%DB_USER:RW` each succeeds and deletes the old probes and their debug rows; a principal holding `%DB_USER:RW` alone purges both alike (no SQL privilege is checked); with `%DB_USER:R` the rule log purge answers success having deleted nothing, and the business process purge answers `<PROTECT>` (status 5002).
- `$ROLES`, `$USERNAME` and `$NAMESPACE` read the same after the frame for `_SYSTEM` (`%All`) and for three principals without `%All`.
- (c) `Ens.BusinessProcess` itself cannot be saved as a probe: its `x__ClassName` is empty and the vendor purge raises `<SUBSCRIPT>`. `EnsLib.MsgRouter.RoutingEngine`, a concrete subclass present in USER and HSCUSTOM, saves with a back-dated `%TimeCreated`, `%IsCompleted`, `%ConfigName` and `%SessionId`. At 3650 days the purge deleted the old completed probe, kept the old running probe and the new one; the rule log purge deleted old rows with their debug rows and kept the new.
- (d) Days 0 deleted today's rule log rows with their debug rows and today's completed business process, and kept a running one; days 1 kept all of today's. Both consequence sentences hold.
- (e) List reads (port-shaped, `%ExecDirectNoPriv`, columns read): 1,000 rows 0.004 s and 2,000 rows 0.008 s for each list, so both caps are 2,000. Purges: rule log 10,000 rows (1,000 with a debug row) 0.10 s, 50,000 rows (5,000 with a debug row) 0.60 s; business processes 2,000 records 0.03 s, 10,000 records 0.13 s. Worst case 0.60 s at 50,000 rows, 1.5 times 0.90 s, within the orchestrator's 30 s bound (V5: no row cap).

**Measured (V3 equality, implement, `ocupilot-b-ci`, 2026-11-24).** For each probe principal, in each namespace, the new check (`$SYSTEM.SQL.Security.CheckPrivilege($USERNAME, 1, <table>, "s", <namespace>)` with the namespace switched) against whether the classic page's own query prepared through `%Library.ResultSet`. Every pair was equal: the check answered 1 exactly when the query prepared, and 0 exactly when it answered `#5580`.

| Principal (pairs and `%DB_USER:R`, then) | Table | USER | HSCUSTOM |
| --- | --- | --- | --- |
| no SQL grant | rule log, business process | refused, `#5580` | refused, `#5580` |
| `%EnsRole_Operator` | rule log, business process | held, prepared | refused, `#5580` (the role's grants are USER's) |
| direct grant on both tables | rule log, business process | held, prepared | held, prepared |
| direct grant on the rule log alone | rule log; business process | held, prepared; refused, `#5580` | held, prepared; refused, `#5580` |
| `%DB_USER:R` and `%DB_HSCUSTOM:R` only | rule log, business process | refused, `#5580` | refused, `#5580` |
| `%All` | rule log, business process | held, prepared | held, prepared |

The check reads `Ens_Rule.Log` and `Ens.BusinessProcess` as the vendor names the tables; the refusal is 403 `AUTH.NOPRIVILEGE` with `detail.failedPair` `Ens_Rule.Log:SELECT` or `Ens.BusinessProcess:SELECT`, and the published sentence "This account does not hold the privilege this request requires." fits it, so no veto addendum is needed. The probe principals, their grants and the probe class were removed after; its source file stays in the throwaway's `/tmp`, which the container refuses to let the session remove.

**Integration and linkage (Rules 1, 2).** Integration: AC6 (the kernel's confirm consumes each stored proposal in its own namespace) and AC1's agent leg (the derived read tools). Consumes: the purge family, `InteropPurgeRun`, `InteropAction`, the kernel's proposal, confirm, governance and audit. Consumed-by: no consumer in this story; Story 24.20's undo names these purges as not restorable (inference). DW-2841 (the database pair read in the confirming namespace, owner `burndown`) applies through `InteropAction`; not addressed here. Story 24.16's deferred agent marker on a failed agent purge applies alike.

**Ledger inbox (Rule 17):** `LEDGER slice 24-17-managed-alerts-logs-the-system-monitor-and-workflow` empty at plan; `owned_ledger=0`.

## Verification

**Commands** (one `ci-runner` call per message; `ocupilot-b-ci` only):

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.InteropLogList`, then likewise `InteropLogPurgeControl`, `InteropLogPurgeRefusals`, `InteropLogPurgeElsewhere`, `InteropPurgeRefusals`, `InteropPurgeControl`, `ConfirmNamespaceRoster`, `DraftRegistry`, `Prohibited`, `GovernanceBaseline`, `ClassicPageGate`, and every class the roster sweep changes. Expected: green; new classes green on their first run.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`. Expected: green.
- `(loop)` `cd ui && npm run build`, `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/interop-log-purge.browser-spec.mjs browser/interop-purge.browser-spec.mjs`. Expected: green.
- `(once)` The full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17` for k = 1 to 17, one call each. Expected: green. The full browser suite is left to CI.
- `uv run scripts/check-objectscript.py`, `uv run scripts/test_check_objectscript.py` and `bash scripts/lint-docs.sh`. Expected: clean.

**Shared surfaces:** the Interoperability side bar; the entity-type vocabulary and `COVEREDTYPES`; the governance baseline and the README's switched-off count; the read-tool, coverage, draft, dry-run, classic-page, confirm-namespace and write rosters; `InteropPort`'s `ENDPOINTS` and `SEARCHENDPOINTS`; `InteropError`'s code lists; `interop.test.mjs`'s sentence rows; `screen-mirror.test.mjs`; the arming roster; both namespaces' rule log and business process rows.

**Hermeticity:** every test added or changed passes on its first run on a fresh instance, in either order; it makes its own probes, asserts on them by marker, drops them in both namespaces, and removes any principal it made.

**Mutations** (each AC's pinning test shown red on `ocupilot-b-ci`, `src` reloaded with subclasses and reverted byte-identical; client ones on a rebuilt, redeployed bundle or in the component runner), recorded as `mutation: <change> -> <test red>`. Each was applied, run, reverted and compared with the file as it stood before (`cmp`, or `diff` showing only the next mutation's hunk), then the tree was reloaded with every subclass:

- mutation: the `errors` and `completed` criterion ignored in `ListLog` -> `InteropLogList.TestEachListAnswersItsProbesNewestFirstAndTheCriterionNarrowsIt` red (AC1).
- mutation: the business process purge passes integrity 0 -> `InteropLogPurgeControl.TestABusinessProcessPurgeFromEitherCallerKeepsTheRunningOneAndTheCurrentOne` red (AC2).
- mutation: the purge pair dropped from `Pairs` -> `InteropLogPurgeGate.TestTheGateRefusesEachPrincipalBeforeAnyVendorCall` red on `OcuP2417gNoPurge`'s two purge legs (AC3).
- mutation: the privilege check asks the other log's table -> `InteropLogPurgeGate` red in both tests, on `OcuP2417gNoSelect`'s four read legs and the refusal's named table (AC3).
- mutation: the vendor's error status ignored in `PerformLogPurge` -> `InteropLogPurgeRefusals.TestAVendorErrorIsNeverA200AndIsAuditedAsNotCompleted` red (AC4).
- mutation: the vendor call made outside `PurgeFrame` -> `InteropLogPurgeRefusals.TestTheProcessRolesAreGivenBackOnSuccessAndOnAnError` red on legs (b) and (c) for both logs (AC5).
- mutation: the tool's confirm query loses the proposal's namespace (`PortQuery` kills the namespace key) -> `InteropLogPurgeElsewhere.TestThePurgeIsConfirmedInTheNamespaceItWasReadIn` red (AC6). Dropping `Namespace` from `FINGERPRINTSUBJECT` is refused at registration by `Registry.FingerprintSubjectProblem`, because `PRECONDITIONFIELD` is `Namespace`, so it was not run.
- mutation: the two `DraftRegistry` argument rows removed -> `DraftRegistry.TestNoSecretReachesAnyRenderedScript` red naming both tools; a tool's `NAMESPACEFIELD` made `Wrong` -> `ConfirmNamespaceRoster.TestEveryWriteToolAsksItsPortInTheNamespaceItsProposalRead` red naming both tools (the roster asks 149 write tools, and `CHECKEDFLOOR` 130 is a floor under it); a `LogFault` inside `PerformLogPurge`'s switched `Catch` -> `InteropLogPurgeRefusals` red in two tests; the new arm placed ahead of the table arm and widened to `sql-table` -> `Prohibited` red on the table legs (AC7).
- mutation: the README count typed one less -> `interop.test.mjs` red (AC8; run by the client delegate).
- mutation: the dialog's Purge sends `'0'` days, on a rebuilt and redeployed bundle -> `interop-log-purge.browser-spec.mjs` red in both tests; the component runner reddened for two more client mutations (the page's registration of Purge dropped; the dialog's count line) (AC9).
- mutation: `DropProbes` leaves the rule log probes -> `InteropLogPurgeElsewhere` red on `OnAfterOneTest`'s assertion that none survives (AC10).
- mutation (review): `LogSelectGate` asks `CheckPrivilege` in `USER` whatever the namespace -> `InteropLogPurgeGate.TestTheSqlSelectCheckIsTheClassicPagesOwn` red on the `HSCUSTOM` legs (AC3); a `LogFault` in `ReadLogState`'s switched `Catch` -> `InteropLogPurgeRefusals.TestNothingIsLoggedWhileTheNamespaceIsSwitched` red on the state leg, and the privilege check mapped through `Mapped` -> red on "names no vendor text" (AC7); `Foreign`'s old date-only predicate -> the class starts beside a foreign business process created today and deletes it (AC10).

## Auto Run Result

Status: in-review
Blocking condition: none.

**Rework pass (2026-11-25).**

- **Changed:** R1 ruled (a): the two state reads take no SQL check and `LogSelectGate` gates the lists only. `InteropLogPurgeGate` pins the principal with the purge pairs and no grant: its state reads and purges answer the log's count while its lists are refused naming the table. The seam's `herestate` mode went, since the state read has one hook. `CHECKEDFLOOR` is 152, the count the walk asks on HEAD (measured).
- **Verified:** on `ocupilot-b-ci`, the five Batch 2 classes (forward, then reversed), `ConfirmNamespaceRoster`, `GovernanceBaseline`, `Governance`, `ToolDispatch` and `InteropPurgeControl` are green; `test:tools` and `ci.test.mjs` are green.
- mutation: `LogSelectGate` put back at the head of `ReadLogState` -> `InteropLogPurgeGate.TestTheGateRefusesEachPrincipalBeforeAnyVendorCall` red on the no-grant principal's state legs and on both purge answers' count (run 40).
- mutation: `CHECKEDFLOOR` 153 -> `ConfirmNamespaceRoster.TestEveryWriteToolAsksItsPortInTheNamespaceItsProposalRead` red, 152 asked (run 41).

**Review pass (2026-11-25).**

- **Changed:** `LogMapped` for the log reads' faults; `Foreign` matched to the vendor's selection; the seam's `herestate` mode; the equality test in both namespaces; and the LOW patches R6-R10 (Review Triage Log).
- **Verified:** `ocupilot-b-ci` was rebuilt on HEAD at 16:08:50 UTC. The five Batch 2 classes ran forward and reversed. The sibling purge classes, 21 rosters and Story 21.31's three classes ran too. All green. Nothing is left in either namespace.
- **Browser and client:** browser `interop-log-purge` and `interop-purge` are green on a rebuilt bundle. The client gates and `check-objectscript.py` are clean.
