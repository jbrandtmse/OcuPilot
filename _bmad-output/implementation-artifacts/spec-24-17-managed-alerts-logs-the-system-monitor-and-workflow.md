---
title: 'Story 24.17: Managed alerts, logs, the system monitor and workflow (Batch 1: managed alerts)'
type: 'feature'
created: '2026-11-23'
status: 'in-review'
baseline_revision: '7dc6c95514ced45270e19bec3573c19ef3baba39'
review_loop_iteration: 0
followup_review_recommended: false
owned_ledger: ''
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-16-purge-suspended-messages-export-and-the-archive-manager.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-16-purge-suspended-messages-export-and-the-archive-manager-4.md'
warnings: ['oversized', 'multiple-goals']
deferred: []
---

<intent-contract>

## Intent

**Problem:** OcuPilot has nothing for the classic Alerts page (`EnsPortal.ManagedAlerts`) or the Managed Alert Viewer (`EnsPortal.ManagedAlertViewer`), nor for the story's other surfaces (rule and business-process logs, the system monitor, workflow), so a namespace's managed alerts cannot be listed, their history read, or an alert assigned, closed, reopened, escalated or rescheduled, and nothing round-trips over `Ens.Alerting.ManagedAlert`.

**Approach:** Batch 1 of five (Design Notes, Batch split): **Managed alerts** (a list) and **Alert history** (its sub-screen) through `InteropPort`, with one write, **Update alert**, one operation reached by the screen and by the agent, extending Story 24.16's families. "Round-trips" means: an update from either caller leaves the alert as `Ens.Alerting.ManagedAlert` then reads it (owner, open state, escalation level, next action time as sent), adds one history row naming the caller and the reason, and both screens read the change.

## Boundaries & Constraints

**Always:**

- **One port (AD-62).** `InteropPort` gains `ManagedAlerts` (`LIST`; `ALERT`, the action's composed read; `ALERTOWNERS`, the owner choices; the write `UPDATEALERT`) and `ManagedAlertActions` (`LIST`, criterion `alert`, an alert `ID`). Reads use `%ExecDirectNoPriv` after the gate, newest first, capped, truncation reported (AD-36). Switched by save and restore; no `OcuPilot.*` call while switched, logging included; a fault is logged after the restore.
- **Rows.** List `{ID, AlertTime, AlertText, SourceConfigName, Production, SessionId, CurrentOwner, EscalationLevel, IsOpen, LastActionTime, NextActionTime, Namespace}`, criterion `open` (`yes`/`no`, unset for all). History `{ActionTime, Username, Action, Reason, OldValues, NewValues}`, `Action` the vendor's `Ens.DataType.ManagedAlertAction.GetText`, the two value arrays rendered `Name: value` joined by `; `. `ALERT` `{ID, CurrentOwner, IsOpen, EscalationLevel, NextActionTime, ActionCount, Namespace}`.
- **Gate (AD-29, AD-8), before any vendor call or value judged; never cached.** Every read: `%Ens_Portal:USE`, `%Ens_Alerts:READ` (both classic pages' `RESOURCE`, `ManagedAlerts.cls:15`, `ManagedAlertViewer.cls:15`), then `Admit`. Owner choices and the update: plus `%Ens_Alerts:WRITE` (`EDITRESOURCE`, `ManagedAlerts.cls:18`) and WRITE on the namespace's globals database; the update, at the write and before the vendor call, also `%Ens_AlertAdministration:USE` when the alert's stored owner is neither empty nor the caller (`ManagedAlert.cls:547-561`, `ManagedAlertViewer.cls:1013-1015`), refused 403 naming the pair. Plus any pair Task 0 (b) measures.
- **Values (AD-56), each optional but `Reason`; absent means unchanged.** `Owner`: `""` (unassigned), the caller, or a name `ALERTOWNERS` answers (`%SYS.Ensemble.ListAlertingUsers` limited to the namespace, the classic form's list); `Open` `0`/`1`; `EscalationLevel` the current level plus or minus one, never below 0 (the classic form's choices); `NextActionMinutes` a whole number from 1 to `ALERTNEXTMAX` 20160, set as `$system.SQL.DATEADD("mi", n, <UTC now>)` at the write (the classic `NOW+`); `Reason` 1 to 500 characters (`Ens.Alerting.Action.Reason`) with no control character.
- **Refusals by name, after the gate, before any vendor call**, in this order: alert gone 404 `INTEROP.ALERT.NOTFOUND`; a value outside its rule 422 `INTEROP.ALERT.OWNER`, `.LEVEL`, `.NEXTACTION`, `.REASON`; no value differing from the fresh read 409 `INTEROP.ALERT.UNCHANGED` (the vendor would record an empty or repeated action).
- **The write.** In the proposal's namespace, `Ens.Alerting.ManagedAlert.UpdateManagedAlert(id, bits, .changes, reason)` with only the changed fields and their bits (`EnsConstants.inc:193-196`), no transaction. A single operation, as the purge (Story 24.16): a vendor error status answers 500 `INTERNAL`, never 200, and its audit row reads `completed` false.
- **The tool (AD-3, AD-6, AD-10, AD-14, AD-22, AD-34, AD-51, AD-53, AD-58, AD-59).** `interop.managedalerts.update`: action-style, `DRYRUN`, not destructive, key `true`; screen action `update` with `SCREENVALUES` `update=Owner:Open:EscalationLevel:NextActionMinutes:Reason`; `FINGERPRINTSUBJECT` `CurrentOwner,IsOpen,EscalationLevel,NextActionTime,ActionCount,Namespace`, so any update after the review closes the proposal as moved; read-back compares the four fields. Classified in `ConfirmNamespaceRoster` and `DraftRegistry`. A script form that shape-checks the id and every value, renders nothing when one fails, and renders the switch, each refusal as a one-line guard and the vendor call, running none. A screen action mints nothing and is not gated by read-only or the kill switch.
- **Namespace at confirm (AD-52).** The stored proposal carries `Namespace`; every confirm-time judgment (the fresh read, the owner list, the administration pair, the vendor call) runs there, whichever namespace the confirm is sent from.
- **Audit (AD-15).** The agent's marker on the agent's write; OcuPilot's own `ConfigChange` from either caller through `AuditRuntime` (unless Task 0 (a) finds a vendor row), naming the namespace, the alert id, each changed field with its new value and `completed`, never the reason, written after the restore.
- **Bounds (named limits, boundary-tested at the cap and one over through a seam).** `ALERTSMAX` (provisional 1,000, the viewer's default rows; Task 0 (e) sets it) and `ALERTACTIONSMAX` 1,000.
- **Rosters.** The entity type `interop-managed-alert` goes after feature's last entries in `TYPES` and `COVEREDTYPES`; its `Prohibited.cls` terms are appended and no earlier type reaches a different arm (a pinning test). Every pinned roster is in the Code Map.

**Never:**

- `ManagedAlert.BulkClose`, `ManagedAlert.Purge`, `%DeleteId`, a property set and `%Save` outside `UpdateManagedAlert`, the `SendUpdate` or `Reoccurrence` bits; any `EnsPortal.*` call in product code.
- A reason in a log line, an audit row or a vendor-status log (`LogFault` gets a fixed message and the vendor's code).
- Batches 2 to 5's surfaces; a README or spine edit.
- `src/OcuPilot/Api/Error.cls` (frozen; codes go in `InteropError.cls`); `ui/angular.json`; `ui/vitest-base.config.mjs`; `scripts/ci-throwaway.sh` beyond add-only `# classes:` lines, never its bring-up retry block; `Prohibited.cls` beyond appended terms; `shell/screen-action-handler.ts`, `shell/warning-dialog.ts`, `shell/screen-action-dialogs.ts` beyond add-only map entries; any non-add-only edit to a file marked (c).

## I/O & Edge-Case Matrix

Route namespace USER. Probes are `Ens.Alerting.ManagedAlert` rows with `SourceConfigName` `OcuProbe2417`, saved by the fixture as `_SYSTEM`; HSCUSTOM holds its own. No production is needed.

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| List | Open, closed, owned and unassigned probes | All listed newest first; `open=yes` lists the open only | - |
| History | A probe updated twice | Two rows newest first, each with the caller, reason and values | - |
| Update, both callers | Owner the caller, then closed; level +1 and next action 60 from the agent | Each reads back as sent; one history row each; one `ConfigChange` each, no reason in it | - |
| Reopen | A closed probe, `Open` 1 | Open again; history row | - |
| Values | Owner `nobody`; level +2 and -1 from 0; minutes 0, 20161, `x`; reason empty, 501 characters, a tab | Refused; alert unchanged | 422 `INTEROP.ALERT.OWNER` / `.LEVEL` / `.NEXTACTION` / `.REASON` |
| Unchanged | Every value as stored | Nothing saved | 409 `INTEROP.ALERT.UNCHANGED` |
| Gone | A deleted probe id | Nothing saved | 404 `INTEROP.ALERT.NOTFOUND` |
| Another's alert | Owned by a probe user; caller without `%Ens_AlertAdministration:USE`; then with it | Refused, then updated | 403 naming the pair |
| Gate | No `%Ens_Alerts:READ`; no `:WRITE`; no database WRITE | Refused before any vendor call | 403 naming the pair |
| Vendor error | The seam answers an error status | Never 200; audit `completed` false; no vendor text logged | 500 `INTERNAL` |
| Moved | The alert updated after the agent's proposal was minted | Confirm refused, nothing saved | `PROPOSAL.TARGETCHANGED` |
| Confirm elsewhere | Minted in USER, confirmed with `?ns=HSCUSTOM`, HSCUSTOM holding a probe under the same id | Acts in USER only; HSCUSTOM's probe unchanged | - |
| Cap | Seam cap 3: three probes, then four | Three listed; four listed as three with truncation | - |
| Script | The draft; a bad id or value | Renders the switch, guards and vendor call, runs nothing; a bad value renders no draft | - |

</intent-contract>

## Code Map

Paths under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-24` (HEAD `eedeed40f`). **(c)** marks a file Epic 21 changed beyond feature (`git log --no-merges origin/OCU-1-epic21 ^origin/feature/OCU-1_ocupilot-mvp`, at plan): `EntityType.cls`, `Baseline.cls`, `Prohibited.cls`, `strings.ts`, `screens.generated.ts`, `screen-actions.ts`, `proposal-view.ts`, `screen-action-handler.ts`, `screen-action-dialogs.ts`, `warning-dialog.ts`, `EXPERIENCE.md` and the test rosters `ClassicPageGate`, `Descriptor`, `Governance`, `GovernanceBaseline`, `MappingDescriptor`, `Prohibited`, `ReadTool`, `SurfaceCoverage`, `ToolRoundTrip`, `ToolWrite`. Add-only there; re-check before editing.

- **`Port/InteropPort.cls`** (13,359 lines; sibling Story 24.16 Batch 4's archive family, extend it, Rule 31): `ENDPOINTS` :128, `IsAnyWrite` :1223, `Pairs` :1253, `Serves` :1335, `Invoke` :1455 (archive branches :1534-1538), `Admit` :1597, `Statused` :3757, `LogFault` :3804, `Refuse` :3818, `Conflict` :3827, `Fail` :3855, `ListMessages` :4665 (the capped `%ExecDirectNoPriv` read), `AuditRuntime` :6978, `SnippetForm` :6990, `Snippet` :7024 (archive :7037-7041), `ENDPOINTARCHIVEERRORS` :10519, `ARCHIVEERRORSMAX` :10543, `ArchiveFacts` :10782, `ReadArchive` :10841, `ListArchiveErrors` :10888, `InvokeArchive` :10932, `PerformArchive` :11069 (audit after restore), `ArchiveSnippet` :11167, `Literal` :13350.
- **Vendor (read-only, read at plan):** `irislib/Ens/Alerting/ManagedAlert.cls` (properties :19-66, indices :76-92, `UpdateAlert` :128-197, `UpdateManagedAlert` :296-312, `GetProperties` :510-544, `%OnAddToSaveSet` :547-561, `BulkClose` :354-450 and `Purge` :453-506 never called); `irislib/Ens/Alerting/Action.cls` :9-25; `irislib/Ens/DataType/ManagedAlertAction.cls` (`GetText`); `irislib/EnsPortal/ManagedAlerts.cls` (`RESOURCE` :15, `EDITRESOURCE` :18, `DoUpdateAlert` :349-381, `GetAlertData` :1076-1131, hyper-event resources :1146-1151); `irislib/EnsPortal/ManagedAlertViewer.cls` (`RESOURCE` :15, table :129-171, filters :201-242, edit form :1004-1160); `irislib/%SYS/Ensemble.cls` (`ListAlertingUsers` :343-357 and `findAlertMembers`, which add `%All` and switch to `%SYS` in their own frame, `$$$AddAllRoleTemporaryInTry`, `%sySecurity.inc:426`). No vendor class audits; `UpdateAlert` and `%OnAddToSaveSet` neither switch namespace nor touch `$ROLES`.
- **`Api/InteropError.cls`:** codes `ALERTNOTFOUND`, `ALERTUNCHANGED`, `ALERTOWNER`, `ALERTLEVEL`, `ALERTNEXTACTION`, `ALERTREASON`, consequence `ALERTUPDATE`, beside the archive block :550-572; an `AlertCodes` list beside `ArchiveCodes` :965, joined into `Codes` :825 and `ConsequenceCodes` :831; `ReasonFor` arms :1073.
- **Tool (new, `Screen/Tool/InteropManagedAlertUpdate.cls`):** extends `InteropAction` (sibling `InteropArchiveRun` for the dry run and precondition shape, `InteropMessageExport` for several `SCREENVALUES`): `WRITERESOURCE` `%Ens_Alerts`, `WRITEPERMISSION` `WRITE`, `READTYPE` `ALERT`, `WRITETYPE` `UPDATEALERT`, `CLASSICPAGES` `EnsPortal.ManagedAlerts`, `IdArgument` `ID`; an `ArgumentProblem` for the value rules (the port judges them again at the write, in the proposal's namespace).
- **Descriptors (new):** `Screen/Descriptor/InteropManagedAlertList.cls` (route `interoperability/managed-alerts`, side bar 22, `list`, scope `namespace`, id `single` on `ID`, entity type `interop-managed-alert`, row action `update`, `rowTarget` to the history, `classicPage` `EnsPortal.ManagedAlertViewer`, `toolIdentifier` `interop.managedalerts`, the `open` criterion as `InteropMessageList.cls` :60-71's `errors`); `Screen/Descriptor/InteropManagedAlertHistory.cls` (route `interoperability/managed-alerts/history`, side bar 0, `list`, parent `alert`, entity `""`, no actions, `classicPage` `EnsPortal.ManagedAlertViewer`, `toolIdentifier` `interop.managedalerthistory`; model `InteropArchiveErrorList.cls`). Both `ownPrivileges` `%Ens_Alerts:READ`.
- **Kernel:** `Kernel/EntityType.cls` (c) :176 and the doc beside :124, `interop-managed-alert` after `interop-archive-setting`; `Kernel/Governance/Baseline.cls` (c) one key `true` in name order; `Kernel/Proposal/Prohibited.cls` (c) append-only: `TYPEINTEROPMANAGEDALERT` after :907, `COVEREDTYPES` :338 last, the uncovered chain :1804 extended at its end, a review arm after :2283 as the archive's `ReviewedFewOnly`.
- **Client (`ui/src/app/`):** `areas/interoperability/interop-managed-alert-list.page.ts` (sibling `interop-archive-list.page.ts`) and `interop-managed-alert-dialog.ts` (siblings `interop-archive-dialog.ts`, `interop-message-export-dialog.ts`: extend or record why a copy reads better): the dialog reads `ALERTOWNERS` and the alert through `handler.dryRunFor`, offers Owner (Unassigned, the caller, the list), Open, Escalation level (current, one up, one down), Next action in (minutes) and Reason, sends only what changed, then Update and Cancel; the history on the shared list page; `shell/screen-outlet.ts` (c) beside :295-297; `shell/screen-action-handler.ts` (c) add-only (`DRY_RUN_ACTIONS` :556, page actions :709, `ACTION_ADDRESS`, consequences); `core/screen-actions.ts` (c) beside :362; `core/proposal-view.ts` (c) beside :570/:829; `core/strings.ts` (c) after :9754; regenerate `screens.generated.ts` (c) and `Screen/Titles.cls`.
- **Tests (new; every class armed by `OCUPILOT_ALLOW_PRINCIPALS`, one add-only `# classes:` line in `scripts/ci-throwaway.sh`):** case `Test/InteropAlertCase.cls` (refuses to start while either namespace holds a managed alert that is not its probe; drops probes in both namespaces before and after every test); fixture `Test/InteropAlertFixture.cls` (`Probe`, `ProbeWithId` raising the lower namespace's `^Ens.Alerting.ManagedAlertD` counter so USER and HSCUSTOM hold a probe under one id, `DropProbes`, a probe principal and user as `InteropArchiveFixture`); seam `Test/InteropAlertSeam.cls` extending `InteropPort` (the caps, the vendor status, a throw, an `AlertHere` hook inside the switched block); classes `InteropAlertList` (list, criterion, history, both readers, caps), `InteropAlertUpdate` (both callers, each value, reopen, read-back, history, audit, draft), `InteropAlertRefusals` (values, unchanged, gone, another's alert and the gate as principals, vendor error, no reason or vendor text in a log, nothing logged while switched), `InteropAlertElsewhere`; each under 500 lines. Browser `ui/browser/interop-managed-alerts.browser-spec.mjs` (sibling `interop-archive.browser-spec.mjs`); component specs for the page and dialog.
- **Rosters (Rule 30; re-grep `interop.archive.run`, `InteropArchiveRun`, `interop-archive`, `InteropArchiveList` across `src/OcuPilot/Test`, `ui/tools`, `ui/browser`, `ui/src`, `scripts/`):** `ConfirmNamespaceRoster` `CHECKEDFLOOR` :34 127 → 128; `DraftRegistry` `ARGUMENTVALUES` :71 (`interop.managedalerts.update=Reason:Draft,interop.managedalerts.update=Open:0`); `ToolWrite` (c); `Descriptor` (c, entity types and screen rows); `SurfaceCoverage` (c); `StageTwoTools`; `InteropFloor`; `GovernanceBaseline` (c); `Governance` (c); `Prohibited` (c); `ReadTool` (c); `ReadDescriptions`; `ToolRoundTrip` (c); `ToolEmit`; `ClassicPageGate` (c); `MappingDescriptor` (c); `DryRunRoute`; `InteropDescriptor`; `ui/tools/interop.test.mjs` (sentence rows; the README count unchanged, a `true` key); `ui/tools/screen-mirror.test.mjs`; `ui/tools/navigation.test.mjs`; `ui/tools/ci.test.mjs`. After any union with feature or Epic 21, check the entity-type order against every pinned assertion. No new route: the write reaches `POST /screens/:screen/action` and `/dryrun`.
- **EXPERIENCE.md** (c): one Fixed strings row after the archive row (:631), once the strings are ruled.

## Tasks & Acceptance

**Execution:**

- [ ] **Task 0** (`ocupilot-b-ci` only, USER and HSCUSTOM, auditing on; every probe alert, user and role removed after; record under Design Notes, Measured): (a) `UpdateManagedAlert` for each bit writes only the alert and its `Actions` rows in the namespace's own globals database, `^Ens.Alerting.ManagedAlertD` maps there, and no vendor audit row is written (with a positive control); (b) a principal holding `%Ens_Portal:U`, `%Ens_Alerts:RW` and `%DB_USER:RW` reads the list and history through `%ExecDirectNoPriv` and updates an unassigned and its own alert, is refused another's without `%Ens_AlertAdministration:U` and updates it with it; name any further pair; with `%DB_USER:R`, where the vendor fails; (c) `ListAlertingUsers(.u, "USER")` for that principal and for `_SYSTEM`: what it answers, and `$USERNAME`, `$ROLES` and `$NAMESPACE` the same after; (d) each value's history row (`Username`, `Reason`, `GetText`, old and new values), reopen of a closed alert, `NextActionTime` from `DATEADD` in UTC; (e) the list read's time at 1,000 and 2,000 probes with three actions each; the cap is the larger whose read ends within 5 s here (1.5 times is 7.5 s on CI), never above 2,000. HALT `blocked` if a read writes, if a vendor call leaves `$ROLES`, `$USERNAME` or `$NAMESPACE` changed, if 1,000 does not fit (e), or if (d) measures otherwise than `ALERTUPDATE` says (`intent gap: new string`).
- [ ] `src/OcuPilot/Port/InteropPort.cls`, `src/OcuPilot/Api/InteropError.cls` -- the two endpoints, the gate and the administration pair, the reads, the owner list, the write, the snippet, the codes -- one port, the archive family extended.
- [ ] `src/OcuPilot/Screen/Tool/InteropManagedAlertUpdate.cls`, the two descriptors, `EntityType.cls`, `Baseline.cls`, `Prohibited.cls` -- the tool, screens, type, key and terms.
- [ ] `ui/src/app/areas/interoperability/interop-managed-alert-list.page.ts`, `interop-managed-alert-dialog.ts`, the add-only maps, strings and outlet registrations; regenerate the mirror and titles; add the EXPERIENCE.md row.
- [ ] `src/OcuPilot/Test/InteropAlert*.cls`, `ui/browser/interop-managed-alerts.browser-spec.mjs`, the component specs, the `# classes:` line and the rosters the sweep names -- the matrix, either order.

**Acceptance Criteria:**

- **AC1 (list and history).** Given USER's open, closed, owned and unassigned probes, when a person opens Managed alerts and Alert history and the agent reads both, then each lists exactly the probes and their history rows newest first, `open=yes` the open ones only.
- **AC2 (update, both callers).** Given USER's probes, when a person updates one from the screen and the agent's confirmed proposal updates another, then each reads back as sent, its history gains one row naming the caller and the reason, both screens read the change, and each write has one `ConfigChange` holding no reason.
- **AC3 (refusals and gate).** Given each refusal row of the matrix, when either caller updates, then the named code answers before any vendor call, the alert is unchanged, and no log line carries a reason or a vendor text.
- **AC4 (vendor error).** Given the seam's error status, when either caller updates, then the answer is never 200 and the audit row reads `completed` false.
- **AC5 (the proposal's namespace; Integration, Rule 1).** Given probes under one id in USER and HSCUSTOM, when the agent's update is minted in USER and confirmed from HSCUSTOM, then it acts in USER only and HSCUSTOM's probe is unchanged.
- **AC6 (rosters, script, switched).** Given the tool, when `ConfirmNamespaceRoster`, `DraftRegistry` and `Prohibited` run, then each is green with its row and red with it removed; the draft shape-checks every value and renders nothing for a bad one; and nothing is logged while switched.
- **AC7 (browser).** Given a fresh instance, when a person assigns a probe alert to themselves and closes it with a reason on the screen, then the list shows it closed and owned, and Alert history shows the row.
- **AC8 (fresh, either order).** Given any new or changed test, run first on a fresh instance in either order, when it ends, then no probe alert, user or role remains in either namespace.

## Spec Change Log

## Review Triage Log

### 2026-11-24, Batch 1 code review (Opus; four layers: adversarial, edge cases, verification gaps, intent)

- **H1** (patch) AD-36: `AlertCap` clamped a caller's cap to the limit, so a history over 1,000 rows (the default cap) or a list read at a cap of 2,000 or more dropped rows unreported. Siblings' form adopted (Decided in-stage (review) 1).
- **H2** (patch) AD-59: `AlertSnippet` opened `If tOk {` on one line and closed it lines later; one line each now, and a new test pastes the draft line by line.
- **M1** (patch) The moved-proposal test touched the level, which the fingerprint holds anyway; its interposed update is now a reoccurrence that moves only `ActionCount` (point 3).
- **M2** (patch) Another user's alert was refused only at the write, after the dialog opened or the proposal was stored; the update's review now judges the pair (Decided in-stage (review) 2), with a gate-test leg per principal.
- **M3** (patch) The draft judged a kept owner against the owner list, which the port does not; guard conditioned on a changed owner.
- **M4** (patch) Nothing pinned `DryRunReview`'s owner list; `InteropAlertList` asserts a listed owner in it, and the HSCUSTOM owners verdict it discarded.
- **M5** (patch) Point 4: `TestAVendorErrorIsNeverA200...` counted each mode's row from its own since-time and printed no count; one window and a cumulative count now. Not reproduced: four fresh runs green, three in a row. Cause undetermined.
- **M6** (patch) "Never below 0" was only reached two steps away; a level-0 probe's `-1` leg added.
- **M7** (defer) `READBACKFIELDS` leaves out the next action time against the Always line "read-back compares the four fields" (implement Decided item 2); spec-bound, for the lead.
- **M8** (veto addendum) `homeSuggestedOpen` is a verb ("the accessible name of a suggested-view line's open control", EXPERIENCE.md:355); here it labels a state. Reuse left in place.
- **Low, patched:** `TestTheFreshReadAtTheConfirmIsTheProposalsNamespaces` asserted only non-200 and claimed a mutation it cannot meet (both namespaces close it as moved): it asserts `PROPOSAL.TARGETCHANGED` and drops the claim; the `ci-throwaway.sh` comment's "each missing one pair" corrected.
- **Low, rejected** (`reopen_if` in brackets): no agent read of the owner choices [an agent proposal is refused `INTEROP.ALERT.OWNER` for a name the dialog offers]; history values and the `ALERT` next action time as stored UTC, by-design (Decided item 6); history prompt groups [a prompt reads wrong on the history screen]; the screen's "'Open' must be 0 or 1", the siblings' argument form and unreachable from the dialog; `DryRunReview` answers `[]` on an owner-list fault [a writer reports an empty owner list]; the `taskCreate` line reference in `strings.ts`, forced by the EXPERIENCE.md row [it conflicts at an Epic 21 merge]; HSCUSTOM's raised id counter [a later class counts on it]; status-only screen leg and the counter-only write check [either hides a regression].
- **False:** JSON-type drops (`Registry.ValidateArguments` refuses a type the schema does not declare before the tool runs); `element_key` text order (measured: 11 rows read newest first); `InputSchema`'s `required` guard (the derived schema always carries it); a stale owner between the read and the vendor (the vendor's `%OnAddToSaveSet` judges the stored owner again); a 129-character owner (theoretical); OcuPilot hooks while switched (`AlertHere`, `VendorAlertUpdate`, as the archive family's).

## Veto items

Each is the lead's to take to the veto gate; the recommended option is first.

1. **New user-facing strings** (reused, each read true here: "ID" (`interopColumnId`), "Source" (`auditEventFieldSource`), "Production" (`systemInfoProduction`), "Session" (`webSessionColumnSession`), "Owner" (`explorerSqlColumnOwner`), "Time" (`auditColumnTime`), "User" (`processColumnUser`), "Action" (`sqlPrivilegeColumnAction`), "Reason" (`agentSwitchesFieldReason`), "Update" (`actionUpdate`), "Cancel" (`actionCancel`), "Yes"/"No" (`tableStatusYes`/`tableStatusNo`), "An internal error occurred" (`Kernel/Fault.cls` `DEFAULTREASON`)):
   - Labels: "Managed alerts" · "Alert history". Action and dialog title: "Update alert".
   - Columns and fields: "Alert time" · "Alert text" · "Current owner" · "Escalation level" · "Open" · "Last action time" · "Next action time" · "Old values" · "New values" · "Next action in (minutes)". Owner choice: "Unassigned".
   - Consequence (`ALERTUPDATE`, provisional until Task 0 (d)): "Updating saves each change in the alert's history with your username and the reason given. The alert can be updated again, and a closed alert can be opened again."
   - Refusals: `NOTFOUND` "This managed alert no longer exists." · `UNCHANGED` "Nothing would change. Choose a new owner, open state, escalation level or next action time." · `OWNER` "The owner must be unassigned, you, or a user who can work on managed alerts in this namespace." · `LEVEL` "The escalation level moves one step up or down from its current level, and never below 0." · `NEXTACTION` "Next action in (minutes) is a whole number from 1 to 20160." · `REASON` "Give a reason of 1 to 500 characters, with no control characters."
   - Empty states: "No managed alerts in this namespace." (agent phrase "update a managed alert") · "This alert has no history yet."
   - Prompts: "Which managed alerts are open and unassigned?" · "Which open alerts are past their next action time?" · "Who owns the most open alerts?" · "What has happened to this alert so far?" · "Close this alert with the reason that it is resolved."
2. **Security posture: who sees which alerts.** The list shows every owner's alerts to a holder of `%Ens_Alerts:READ`, as the classic Managed Alert Viewer does (`ManagedAlertViewer.cls:215`: its owner filter offers All to any reader). The classic Alerts page shows a non-administrator only their own and unassigned alerts (`ManagedAlerts.cls:1094-1098`). Equal to the viewer, which the screen replaces. Alternative: the Alerts page's narrower rows for a reader without `%Ens_AlertAdministration:USE`.
3. **Security posture: the update's pairs.** `%Ens_Alerts:WRITE`, WRITE on the namespace's globals database, and `%Ens_AlertAdministration:USE` for an alert another user owns, judged by OcuPilot before the vendor call; the vendor's `%OnAddToSaveSet` checks the first and third itself. The database pair is the classic posture made explicit (inference until Task 0 (b)). Alternative: the resource pairs alone.
4. **Values narrower than the classic form.** An owner from the classic form's list only (stricter than the vendor, which takes any name); one escalation step, as the form; a next action time set only forward from now, 1 to 20160 minutes (the form also offers times relative to the current value, down to 30 minutes earlier). Alternative: an absolute UTC time from now to two weeks ahead.
5. **Governance key.** `interop.managedalerts.update` ships `true` and is not destructive: every change is recorded in the alert's history and can be changed back. Alternative: `false`.
6. **AD amendments (story end, the lead writes them, add-only, `[AMENDED <date>, Story 24.17, Rule 20]`).** AD-62, the next item: "**Managed alerts** (Story 24.17). `InteropPort` gains `ManagedAlerts` and `ManagedAlertActions` over `Ens.Alerting.ManagedAlert`, behind `%Ens_Alerts:READ`, the classic pages' `RESOURCE`, and an update through `UpdateManagedAlert` behind `%Ens_Alerts:WRITE`, WRITE on the namespace's globals database, and `%Ens_AlertAdministration:USE` for an alert another user owns. The owner is one the classic form offers, the level moves one step, and a change of nothing is refused before any vendor call." AD-22: "**Story 24.17's Batch 1 key:** `interop.managedalerts.update` ships `true`." AD-15, named case: "**A managed alert update** (Story 24.17), which the vendor records only in the alert's own history, records OcuPilot's own `ConfigChange` from either caller, never the reason."

No new dependency; no privilege, role or access grant; nothing is written into another namespace.

**Lead rulings at the spec gate (2026-11-23; filed as an INBOX veto item, binding unless the orchestrator reverses them).** Every veto item is kept as recommended:

- **V1:** kept. If Task 0 (d) measures `ALERTUPDATE` untrue, HALT with `## Clarification Needed`. Never reword it in-stage.
- **V2:** kept. All owners' alerts go to a holder of `%Ens_Alerts:READ`, equal to the classic Managed Alert Viewer the screen replaces, and never looser than it.
- **V3:** kept. If Task 0 (b) shows the vendor needs more than the listed pairs, the pairs gain it.
- **V4:** kept, the narrower values.
- **V5:** kept. The update ships `true`.
- **V6:** kept for story end; the lead writes the lines.
- **Batch 5 note:** `%SYS.Ensemble.GetEnsMetrics` adds `%All` temporarily. Batch 5's plan must contain it as AD-9's `PurgeFrame` exception allows, or HALT.

## Design Notes

**Batch split** (each its own spec, `-2` onward, and commit series; by size: managed alerts two pages and one write, the logs two lists and two purges, workflow four pages and eight writes, the monitor one read):

1. Managed alerts: the list, the history and the update (this spec).
2. Business rule log and business process log: two lists over `Ens_Rule.Log` and `Ens.BusinessProcess`, each with its purge by days (`Ens.Purge.PurgeRuleLogsByDate`, `PurgeBusinessProcessesByDate` with integrity kept), destructive with keys `false`, behind `%Ens_RuleLog:USE` and `%Ens_Jobs:READ` and `%Ens_Purge:USE`, extending Story 24.16's purge family.
3. Workflow roles, users and membership: two lists over `EnsLib.Workflow.RoleDefinition` and `UserDefinition` with create, edit, delete and add or remove a member, behind `%Ens_WorkflowConfig:READ`/`WRITE`.
4. Workflow tasks and worklist: the task list with assign, unassign and cancel through `EnsLib.Workflow.Engine` (cancel needs the running production), and the worklist read, behind the portal gate and `%Ens_WorkflowConfig:WRITE` for a write.
5. The Interoperability System Monitor: an instance-wide read in `%SYS` through `%SYS.Ensemble.GetEnsMetrics` behind `%Ens_Dashboard:USE`, whose vendor escalation Task 0 measures; and the story's README clauses, the switched-off count derived by `interop.test.mjs` (Batches 2 to 4 add `false` keys).

**Decided in-stage (plan).**

1. Epic context recompiled (the planning files were newer); left uncommitted for the lead, since this dispatch commits the spec alone.
2. Managed alerts first, in the story's order.
3. One list replaces both classic pages: its `classicPage` is the viewer, whose rows it shows, and the update tool's `CLASSICPAGES` the Alerts page, whose Update it performs, so neither page's custom resource is lost (AD-44).
4. History is a sub-screen, not a detail pane, so its rows are a declared read the agent shares (AD-36); `Action` is the vendor's own text, shown as data.
5. A value absent means unchanged and `Owner` `""` means unassigned, so the vendor gets only the changed fields and their bits, as the classic form sends them.
6. `ActionCount` is in the fingerprint, so a reminder or escalation the vendor's alert monitor writes after the review also closes the proposal as moved.
7. The reason stays out of OcuPilot's audit row and logs (as a purge description); the vendor keeps it in the alert's history.
8. Siblings (Rule 31): the archive family (port reads, audit order, seam hook, case, browser spec), `InteropArchiveRun` and `InteropMessageExport` (tool), `InteropArchiveList`/`InteropArchiveErrorList` (descriptors), `interop-archive-dialog.ts` and `interop-message-export-dialog.ts` (dialog), `InteropArchiveFixture` (principals).
9. Side-bar position 22, after Archive errors; the history takes none.
10. Story 24.21's harvested `rule_log` and `get_business_process_instance` stay its own; Batch 2's reads are the screens' declared reads.

**Measured (Task 0, `ocupilot-b-ci`, USER and HSCUSTOM, auditing on; no HALT).** The session ran as `irisowner`; the principals ran in a child job after `$System.Security.Login`.

- (a) Six `UpdateManagedAlert` calls (each of the four bits alone, then all four) wrote only `^Ens.Alerting.ManagedAlertD` (the alert and its `Actions` rows) and `^Ens.Alerting.ManagedAlertI`, both in the namespace's own database (journal read by process id), nothing in HSCUSTOM's, and no audit row (a positive control, one `%Ensemble` row, was read). Both globals map to each namespace's own database (`/durable/iris/mgr/user/`, `/durable/iris/mgr/HSCUSTOM/`). The list and history reads write no data; the first preparation of a statement writes the SQL statement cache (`^rINDEXSQL`, `^%SYS`) and a second run writes nothing.
- (b) A principal holding `%Ens_Portal:U`, `%Ens_Alerts:RW`, `%DB_USER:RW` (and `%DB_HSCUSTOM:R` to run code from the install namespace) reads the list, the history and `LastActionTime` through `%ExecDirectNoPriv`, updates an unassigned alert and its own, and is refused another's (`ERROR #940`); with `%Ens_AlertAdministration:U` it updates another's. With `%DB_USER:R` the vendor fails with `<PROTECT>%SaveData` on `^Ens.Alerting.ManagedAlertI` (status 5002), the alert unchanged; with `%Ens_Alerts:R` or without the resource the vendor answers `#940`, and the reads still succeed, so the port gates its reads itself. No further pair is needed.
- (c) `%SYS.Ensemble.ListAlertingUsers(.u, "USER")` answers `Admin` for `irisowner` and for a principal holding `%Ens_Alerts:W`, and `ERROR #940` without it; a user holding `%EnsRole_AlertOperator` and WRITE on USER's database is added, and none is listed for HSCUSTOM. `$ROLES`, `$USERNAME` and `$NAMESPACE` read the same before and after, for every principal and for `irisowner`.
- (d) Each history row names `$USERNAME`, the reason and `GetText` of its bits (`Assign`, `Close`, `Change Escalation Level`, `Change Next Action Time`, joined by ` | `), with the old and new values by name. A reopen is recorded under bit 2 and `GetText` reads `Close` for it too. An assign to the same owner is recorded as an action (so the port refuses it first); a lower-than-0 or unchanged level and an unchanged open state record nothing and answer OK; an empty reason (`#5659`) and 501 characters (`#7201`) fail in the vendor; a tab in the reason and an owner not in the list are accepted by it (so the port's rules are stricter). `DATEADD("mi", 60, <UTC now>)` reads exactly 60 minutes later in the stored `Ens.DataType.UTC` form (trailing zeros of the fraction dropped). `ALERTUPDATE` holds as drafted.
- (e) The list read (newest first, `LastActionTime` included, one more row than the cap) ends in 0.08 s the first time and 0.02 s after for 1,000 probes with three actions each, and in 0.04 s for 2,000; the history of one alert reads in under 0.03 s. `ALERTSMAX` is 2,000 (the larger, never above 2,000).
- Residue: every probe alert, user and role, the scratch class and its globals are gone; USER and HSCUSTOM hold no managed alert (SQL count 0); HSCUSTOM's alert globals, absent before, are killed; USER's id counter is 2,040 (it read 12) and its bitmap index nodes are empty.

**Decided in-stage (implement, ObjectScript half).**

1. `ALERTSMAX` is 2,000 (Measured (e)); `ALERTACTIONSMAX` 1,000; `ALERTNEXTMAX` 20,160; a list answers the caller's `maxRows` when it names one and the named limit otherwise, as the port's other capped lists do, so the caller's cap-plus-one row is its truncation signal (AD-36), and a seam subclass (`InteropAlertCapSeam`) lowers both caps to three.
2. The fresh read `ALERT` answers `{ID, CurrentOwner, IsOpen, EscalationLevel, NextActionTime, ActionCount, Namespace}` and four more members, `Owner` and `Open` (what the alert holds, so a merge that sets one to that leaves it unchanged), `NextActionMinutes` and `Reason` (empty), because the screen action's merge (`Mint.Merge`) refuses an argument its read does not carry. `FINGERPRINTSUBJECT` and `READANSWERS` name them beside the spec's six, since the stored payload is narrowed to the subject and the port reads the values from it; the read-back compares `Owner`, `Open` and `EscalationLevel`, not the next action time, which is set from the clock at the write.
3. The three `Prohibited.cls` edits are additive (type parameter, `COVEREDTYPES` last, the uncovered guard extended by suffix, one review arm after the archive's); no `PermittedChangeFields` arm, because the tool's values travel in the port's query and are no field of the type (`Test/Prohibited` pins both).
4. A review that carries no value (the dry run that opens the dialog) reads the state alone; any value present is judged, `Reason` required. An owner equal to the alert's own is never judged against the owner list.
5. The owner choices, like the update, require `%Ens_Alerts:WRITE` and WRITE on the namespace's globals database (`Admit` takes `ALERTOWNERS` as a write for its database permission).
6. List and history times read as the instance's local time, as the other lists show them; the `ALERT` row's next action time is as stored (UTC) for the fingerprint. A bad open state answers `PORT.VALIDATION` through the shared criterion sentence ("Open is not valid."), reachable only from a direct port call.
7. The vendor-error leg (AC4) runs through the port seam (`InteropAlertSeam`), which both callers' writes reach; a real vendor failure for the HTTP callers has no cheap probe.
8. The keys the client must publish, none beyond the spec's quoted strings: labels `interopManagedAlertsLabel`, `interopManagedAlertHistoryLabel`; columns `interopAlertColumnTime`, `interopAlertColumnText`, `interopAlertColumnOwner`, `interopAlertColumnLevel`, `interopAlertColumnOpen` (also the `open` criterion), `interopAlertColumnLastAction`, `interopAlertColumnNextAction`, `interopAlertColumnOldValues`, `interopAlertColumnNewValues`; empty states `interopManagedAlertsEmpty`, `interopManagedAlertsEmptyAgent`, `interopManagedAlertHistoryEmpty`; prompts `interopManagedAlertsPrompt1` to `4` and `interopManagedAlertHistoryPrompt1`; `Titles.cls` is edited by hand for the two labels and the mirror must reproduce it.

**Decided in-stage (implement, client half and sweep).**

1. "Open" reuses the existing string `homeSuggestedOpen` (the strings test needs unique values), so the `IsOpen` column and the `open` criterion carry it; the descriptor's `labelKey` was edited to match.
2. Strings the spec quotes but item 8 above did not key: `interopManagedAlertUpdateAction`, `interopAlertFieldNextMinutes`, `interopAlertOwnerUnassigned`, `interopManagedAlertUpdateConsequence`, `interopManagedAlertRefusalNotFound`, `...Unchanged`, `...Owner`, `...Level`, `...NextAction`, `...Reason`.
3. The dialog sends only the values that differ from the alert, and `Reason` only when typed, so an empty reason reaches the instance's own `INTEROP.ALERT.REASON` sentence; the caller's name comes from `Session.userName()`.
4. The history opens from the list's name cell through the shared child-list mechanism; the list descriptor carries no `rowTarget`.
5. Three rosters outside the Code Map pinned the changed shared surfaces and were updated: `Test/Navigation` (41 Interoperability screens, two order entries), `Test/InteropHostDescriptor` (`ENDPOINTS`) and `Test/InteropMessageDescriptor` (`SEARCHENDPOINTS`); each is green alone.

**Decided in-stage (review).**

1. Both lists answer the caller's own `maxRows` when it names one (the siblings' form, `ListMessages`, `ListSuspended`, `ListArchiveErrors`); `ALERTSMAX` and `ALERTACTIONSMAX` bound a call that names none. A clamp at the limit lost AD-36's truncation signal whenever the caller's cap reached it (the history's 1,000 equals the default cap).
2. The review of an update (the dialog's dry run and the agent's mint, which ask the read for the update action) judges the administration pair for another user's alert, as the write does, so a non-administrator gets the refusal before a dialog or a proposal; the stored payload's re-read and read-back ask no action and are unaffected.
3. The script form's value lines are one line each, so no line opens a block it does not close (AD-59); its owner-list guard runs only for an owner that differs from the alert's own, as the port judges.
4. "Open" keeps `homeSuggestedOpen` for now; its published meaning is a verb, so a distinct string is proposed to the lead as a veto addendum ("Is open"), never decided here.

**Governing ADs (Rule 6):** AD-3, AD-6, AD-7, AD-8, AD-10, AD-11, AD-13, AD-14, AD-15, AD-16, AD-21, AD-22, AD-29, AD-34, AD-36, AD-44, AD-51, AD-52, AD-53, AD-56, AD-58, AD-59, AD-60, AD-62. Not engaged: AD-9 (the vendor's owner list adds `%All` in its own frame; a change after it returns HALTs), AD-23, AD-35, AD-54, AD-63, AD-65, AD-66.

**Integration and linkage (Rules 1, 2).** Integration: AC5 (the kernel's confirm consumes the stored proposal in its own namespace) and AC1's agent leg (the derived read tools). Consumes: the archive family, `InteropAction`, the kernel's proposal, confirm, governance and audit. Consumed-by: no consumer in this story; Story 24.20's undo is the first candidate (inference).

**Ledger inbox (Rule 17):** `LEDGER slice 24-17-managed-alerts-logs-the-system-monitor-and-workflow` empty at plan; `owned_ledger=0`.

## Verification

**Commands** (one `ci-runner` call per message; `ocupilot-b-ci` only):

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.InteropAlertList`, then likewise `InteropAlertUpdate`, `InteropAlertRefusals`, `InteropAlertElsewhere`, `ConfirmNamespaceRoster`, `DraftRegistry`, `Prohibited`, `GovernanceBaseline`, `ClassicPageGate`, and every class the roster sweep changes. Expected: green; new classes green on their first run.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`. Expected: green.
- `(loop)` `cd ui && npm run build`, `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/interop-managed-alerts.browser-spec.mjs browser/interop-archive.browser-spec.mjs`. Expected: green.
- `(once)` The full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17` for k = 1 to 17, one call each. Expected: green. The full browser suite is left to CI.
- `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh`. Expected: clean.

**Shared surfaces:** the Interoperability side bar; the entity-type vocabulary and `COVEREDTYPES`; the governance baseline; the read-tool, coverage, draft, dry-run, classic-page, confirm-namespace and write rosters; `InteropError`'s code lists; `interop.test.mjs`'s sentence rows; `screen-mirror.test.mjs`; the arming roster; both namespaces' managed alerts.

**Hermeticity:** every test added or changed passes on its first run on a fresh instance, in either order; it makes its own probes, asserts on them by marker or id, drops them in both namespaces, and removes any principal it made.

**Mutations** (each AC's pinning test shown red on `ocupilot-b-ci`, `src` reloaded with subclasses and reverted byte-identical; client ones on a rebuilt, redeployed bundle or in the component runner), recorded by the implement stage as `mutation: <change> -> <test red>`. Planned: AC1 the list's `open` criterion ignored -> `InteropAlertList` red; AC2 the write sends every field's bit -> `InteropAlertUpdate` red (history leg); AC3 the administration pair skipped -> `InteropAlertRefusals` red, the unchanged refusal removed -> red; AC4 the vendor status ignored -> `InteropAlertRefusals` red; AC5 `FINGERPRINTSUBJECT` without `Namespace` -> `InteropAlertElsewhere` red; AC6 the tool's `DraftRegistry` row removed -> red, a log line inside the switched block -> `InteropAlertRefusals` red, the new `Prohibited` arm placed before an earlier one -> `Prohibited` red; AC7 the dialog sends no reason -> the browser spec red; AC8 the case's `DropProbes` skipped -> `InteropAlertElsewhere`'s after-all check red.

**Mutations run** (`ocupilot-b-ci`, each file copied before, edited, reloaded with every compiled subclass, the pinning class red, reverted by Edit, `cmp` identical to the copy, reloaded, the same class green; a client one on a rebuilt and redeployed bundle):

- mutation: AC1 `ListAlerts` ignores the `open` criterion -> `InteropAlertList.TestTheListAnswersEveryProbeNewestFirstAndTheCriterionNarrowsIt` red.
- mutation: AC2 `PerformAlertUpdate` sends every field's bit (15) -> `InteropAlertUpdate.TestAnUpdateFromEitherCallerReadsBackAsSentWithOneHistoryRowEach` and `.TestAClosedAlertIsOpenedAgain` red (history leg).
- mutation: AC3 the administration pair skipped for another's alert -> `InteropAlertRefusals.TestTheGateRefusesEachPrincipalBeforeAnyVendorCall` red.
- mutation: AC3 the unchanged refusal removed from `AlertJudge` -> `InteropAlertRefusals.TestAnUpdateThatChangesNothingIsRefusedBeforeTheVendor` red.
- mutation: AC4 the vendor status ignored in `PerformAlertUpdate` -> `InteropAlertRefusals.TestAVendorErrorIsNeverA200AndIsAuditedAsNotCompleted` red.
- mutation: AC5 `Namespace` dropped from `InteropManagedAlertUpdate.FINGERPRINTSUBJECT` -> `InteropAlertElsewhere.TestTheUpdateIsConfirmedInTheNamespaceItWasReadIn` and `.TestAnOwnerIsJudgedInTheProposalsNamespace` red; the same edit reddens `ConfirmNamespaceRoster.TestEveryWriteToolAsksItsPortInTheNamespaceItsProposalRead`, naming the tool.
- mutation: AC6 `DraftRegistry` row `interop-managed-alert=2417` removed from `TYPEDTARGETIDS` -> `DraftRegistry.TestNoSecretReachesAnyRenderedScript` red.
- mutation: AC6 a log line in the switched `Catch` of `PerformAlertUpdate`, before the restore -> `InteropAlertRefusals.TestNothingIsLoggedWhileTheNamespaceIsSwitched` red.
- mutation: AC6 the reason's shape check removed from `AlertSnippet` -> `InteropAlertUpdate.TestTheScriptFormRendersTheGuardedUpdateAndRunsNothing` red.
- mutation: AC6 the managed alert arm placed ahead of the table arm and widened to `sql-table` -> `Prohibited.TestTheManagedAlertArmLeavesEarlierTypesTheirOwnVerdicts` red (and two more); `interop-managed-alert` removed from `COVEREDTYPES` -> `Prohibited.TestTheManagedAlertArmLeavesEarlierTypesTheirOwnVerdicts`, `.TestAnUncoveredEntityTypeIsRefusedWholesale` and `.TestNoRegisteredWriteToolHasAnUncoveredEntityType` red.
- mutation: AC7 the dialog sends no reason (bundle rebuilt and redeployed) -> `interop-managed-alerts.browser-spec.mjs` red at the dialog-close wait; green again on a bundle rebuilt from the reverted source.
- mutation: AC8 `DropProbes` skips the delete -> `InteropAlertElsewhere` red in all three tests at the case's `OnAfterOneTest` assertion; the reverted class's first run removed the leftovers.
- mutation (review): AC2 `ActionCount` dropped from `FINGERPRINTSUBJECT` -> `InteropAlertUpdate.TestAnUpdateAfterTheMintClosesTheConfirmTargetChanged` red (its interposed update is now a reoccurrence, which moves only `ActionCount`).
- mutation (review): AC1 `AlertCap` clamps the caller's cap to the limit again -> `InteropAlertList.TestBothListsStopAtTheirNamedLimit` red.
- mutation (review): AC3 the administration check dropped from `ReadAlert` -> `InteropAlertRefusals.TestTheGateRefusesEachPrincipalBeforeAnyVendorCall` red (review leg).
- mutation (review): AC3 `AlertLevelShapeOK` takes a minus sign -> `InteropAlertRefusals.TestEachValueOutsideItsRuleIsRefusedByNameAndNothingIsSaved` red (one step below level 0).
- mutation (review): AC4 `AuditRuntime` skipped on a vendor error -> `InteropAlertRefusals.TestAVendorErrorIsNeverA200AndIsAuditedAsNotCompleted` red.
- mutation (review): AC6 `AlertSnippet`'s value lines in one block opened and closed on different lines -> `InteropAlertUpdate.TestTheScriptFormRunsPastedLineByLine` red; its owner guard made unconditional -> the same test red (kept-owner leg).
- mutation (review): AC2 `DryRunReview` asks the port for `ALERT` in place of `ALERTOWNERS` -> `InteropAlertList.TestTheOwnersAreTheUsersTheClassicFormOffersAndReadingWritesNothing` red.

Unproven row: `ConfirmNamespaceRoster.CHECKEDFLOOR` raised to 129 stays green because the walk asks 147 write tools, so the floor (128) is a loose lower bound, not a pin; the tool's classification is pinned by the `FINGERPRINTSUBJECT` mutation above. One run of `InteropAlertRefusals.TestAVendorErrorIsNeverA200AndIsAuditedAsNotCompleted` (the first after a reload, byte-identical code) failed its `OcuPilot records one ConfigChange` assertion; the count was not recorded, so the cause is undetermined (Review Triage Log, M5); the next run was green.

## Auto Run Result

Status: in-review
Blocking condition: none

**Review (Batch 1).** Two high and six medium findings patched in `InteropPort.cls` and the four `InteropAlert*` test classes, one medium deferred and one proposed as a veto addendum (Review Triage Log). Verified on `ocupilot-b-ci` rebuilt at 02:10 UTC on 2026-11-24: the four classes forward and reversed, `InteropAlertRefusals` four times (three in a row), 21 rosters and eight Story 24.16 archive and purge classes, all green; the two browser specs on a rebuilt bundle; `ci.test.mjs`, `check-objectscript.py`. Eight mutations, under Verification. No probe alert, principal or production left.

**Implement (Batch 1).** Built to the spec on `ocupilot-b-ci`; Task 0 under Design Notes, "Measured" (no HALT; `ALERTSMAX` 2,000). Verified: all 17 ObjectScript shards, 893 classes and 6,747 tests, green after three stale rosters outside the Code Map were updated (Decided in-stage, client half and sweep, item 5); new browser spec 1 of 1 and `interop-archive.browser-spec.mjs` 2 of 2 on a rebuilt bundle; `smoke.sh` 50 of 50; `npm run build`, `npm test` (2,413 tool tests; 335 component files, 3,948 tests) and `tools/ci.test.mjs` (109) green; `check-objectscript.py` 0 problems; `lint-docs.sh` 0 issues. Mutations: one or more per AC, under Verification. Residue: no managed alert in USER or HSCUSTOM, no production in USER; the role `OcuPilotProbeProhibitedRouteRole` belongs to `Test.ProhibitedRoute`, not this batch. One `InteropAlertRefusals` ConfigChange assertion did not read 1 once on the first run after a reload and was green in the sweep (Verification, last paragraph).

**Plan.** Batch 1 of five: Managed alerts and Alert history through `InteropPort`, with Update alert reached by the screen and the agent; the proposal keeps its namespace and every confirm judges there. Veto items 1 to 6; the batch split and decided-in-stage list under Design Notes. Read-only check on `ocupilot-b-ci` (52777, image `irishealth-community:2026.2`): USER and HSCUSTOM hold no managed alert, rule log, business process or workflow row. Nothing was written to the instance.
