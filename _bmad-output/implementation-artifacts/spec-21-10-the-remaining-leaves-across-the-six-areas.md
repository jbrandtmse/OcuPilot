---
title: 'Story 21.10: The remaining leaves across the six areas'
type: 'feature'
created: '2026-11-15'
status: 'draft'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-21-context.md'
warnings: ['multiple-goals', 'oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The story asks for every remaining shell, permission, security, task, OS management and log leaf, plus 34 routed ledger entries. Probed on slot A's `ocupilot`, that is 21 catalog leaves and about 15 write tools. Eight of the leaves need an owner decision or an AD change first. That is far past one implement pass (about 8 tools).

**Approach:** Split into six children inside Epic 21. This story keeps the security settings leaves and DW-2431. Each child is re-planned on its own once the runner rules the split.

## Boundaries & Constraints

**Always:** Each leaf joins the area slice that already owns its neighbours, through one descriptor and one port. Every write is a confirmed proposal. Every new destructive key ships disabled. Each leaf's backing class is named from the instance.

**Never:** Nothing is implemented in this pass. No AD is amended unattended except DW-2431's, which the owner approved (U-30). No leaf moves to the exclusion register without the owner. Nothing runs on `ocupilot-ci`.

## Runner rulings at the plan halt (2026-11-15, unattended)

- **Split (decide; 6 of 6 children):** this story keeps SS-38 system-wide security parameters, SS-37 mobile phone providers and SS-36 audit log export, plus DW-2431 and DW-2457. Story 21.19 takes SS-39, PM-24, TM-17, TM-18, WA-15 (DW-2372, DW-2471); 21.20 OS-24, OS-27, LG-12 (DW-1562, DW-1856, DW-2479); 21.21 the owner-gated leaves (SH-26, SH-27, SH-28, PM-23, TM-19, WA-16, OS-25; DW-1850, DW-1280, DW-2348); 21.22 the flakes plus DW-2476 and DW-2202; 21.23 the test-hygiene entries. DW-2214, DW-2367, DW-2473, DW-2355 and DW-2356 are closed as proposed. OS-26, OS-28 and OS-29 are already delivered. The leaf inventory in Design Notes stands as the second criterion's evidence.
- **DW-2431 (owner answer U-30, quoted: "I agree with your recommendations"):** amend AD-10's KMIP bullet so the refusal also judges journal encryption (the runner writes it into the spine at this story's spec gate, citing owner answer U-30); add the refusal, reusing `PROHIBITED.STARTUPKMIP`, with exactly this owner-approved sentence: "Journal encryption is on, or a journal file the instance still needs is encrypted, and OcuPilot cannot check that the KMIP server is reachable and holds its key, so a start that cannot activate it does not finish. Keep Unattended, or make this change on the classic Database Encryption page."
- **SS-38:** if it needs a new AD-10 arm beyond DW-2431's, HALT as an intent gap naming it (no owner answer covers it).

</intent-contract>

## I/O & Edge-Case Matrix

To be written by the re-plan for the narrowed story.

## Code Map

- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` -- `EncryptionStartup` and `LeavesKmipRequired`: the KMIP arm DW-2431 widens.
- `src/OcuPilot/Screen/Descriptor/AuthOptions.cls`, `AuditingConfig.cls` -- siblings for the system-wide security parameters form (`Security.System`).
- `src/OcuPilot/Screen/Tool/AuditCopy.cls`, `AuditPurge.cls` -- siblings the audit-log export extends.
- `src/OcuPilot/Screen/Tool/TaskExport.cls`, `TaskImport.cls`, `Port/TaskTransferPort.cls` -- siblings for resource export and import.
- `src/OcuPilot/Screen/Descriptor/SqlActivityList.cls` -- says "canceling a query is a later catalog row" (OS-24).
- `src/OcuPilot/Screen/Descriptor/ProcessDetails.cls` -- withholds `Variables` under AD-24, AD-35 and AD-48 (OS-25).
- `/Users/jbrandt/git/iris-execute-mcp-v2/src/ExecuteMCPv2/REST/Monitor.cls` -- `SystemAlerts` and `AlertsManage`, the bodies to harvest for LG-12 (AD-23).

## Tasks & Acceptance

**Execution:**

- `_bmad-output/planning-artifacts/epics.md` -- runner: rule the split in Design Notes and insert the children's story blocks -- the story is too large for one pass.

**Acceptance Criteria:**

- Given the runner's ruling, when each child is re-planned, then every leaf and every ledger entry below has exactly one owner or a closing disposition.

## Design Notes

**Governing ADs:** AD-10 (prohibited set, KMIP arm), AD-21 (no caller path: exports and imports), AD-23 (harvest seam), AD-27 (named cases), AD-35 (secrets), AD-44 (classic page keys), AD-51/AD-53/AD-56 (action writes, two callers, declared secrets), AD-52 (declared port).

**(a) Leaf inventory.** Probed read-only on `ocupilot` (`ocupilot-slot-a`), 2026-11-15, through `%Dictionary.CompiledClass`, `CompiledMethod` and `CompiledParameter` (`PAGENAME`, `RESOURCE`). Page sources were read in `irissys/`. The rows are the extract's Stage 4 six-area rows, plus the web-app rows (WA-15, WA-16): no other story owns them, and the story's six areas are the six contest areas (inference).

| Leaf | Classic page (resource) | Backing class (verified on the instance) | State |
|---|---|---|---|
| SS-38 System-wide security parameters | `%CSP.UI.Portal.Parameters` (`%Admin_Secure`) | `Security.System` `Get`/`Modify` (19 properties) | open |
| SS-37 Mobile phone providers | `%CSP.UI.Portal.PhoneProviders`, `PhoneProvider` (`%Admin_Secure`) | `%SYS.PhoneProviders` `Create`/`Modify`/`Delete`/`Get` | open |
| SS-36 Export audit log | `%CSP.UI.Portal.Audit.ExportLog` (`%Admin_Secure`) | `%SYS.Audit.Export` through the `AuditExport` background task | open |
| SS-39 Security Advisor | `%cspapp.sec.utilsyssecurityadvisor` over `%CSP.UI.System.SecurityAdvisorPane` | the pane's `Get*Recommendations`, `SetIgnoreFlag` | open |
| PM-24 Resource export/import | `%CSP.UI.Portal.Dialog.ExportResource` (`%Admin_Secure:USE`) | `Security.Resources` `Export`/`Import` | open |
| PM-23 TOTP QR code | `%CSP.UI.Portal.User` (GenerateQRCode link) | `$$GenerateQRCode^%SYS.SECURITY` | owner (AD-35) |
| TM-17 Task output file | none ("new": open the output file from Task details) | a file read of the task's output file | open; AD-21 check |
| TM-18 Task Manager email | `%cspapp.mgr.utilsystaskmail` (no source on the instance) | `%SYS.Task.Config` `EmailGet`/`EmailSet`/`AuthPassSet`/`UpdateData` (page-to-class link is an inference) | open |
| TM-19 Diagnostic reports | legacy page, no source | `%SYS.Task.DiagnosticReport` (archive directory; SMTP and WRC fields) | owner (sends to WRC) |
| OS-24 Cancel a running query | `%CSP.UI.Portal.SQL.CurrentStatements` | `%SYSTEM.SQL.CancelQuery` | open |
| OS-27 Transactions | `%CSP.UI.Portal.Transactions` (`%Admin_Operate`) | `SYS.Metrics.SystemMonitorStatus` | open |
| LG-12 System alerts state and reset | System Dashboard alerts meter | `%SYSTEM.Monitor` `GetAlerts`/`Alerts`/`Clear`; harvest `Monitor.SystemAlerts`/`AlertsManage` | open |
| OS-25 Process variables | `%CSP.UI.Portal.ProcessDetails` | `SYS.Process:VariableByPid` | owner (AD-24/35/48 withhold `Variables`) |
| WA-15 Web app copy | `%CSP.UI.Portal.Applications.Web` ("Copy from") | `CopyApp`, `Security.WebAppPctAccess.CopyAll`; no export or import on this build's page | open |
| WA-16 Web Gateway management | `%cspapp.mgr.utilsyscspgateway` (`%CSP.Util.Domain`) | none in IRIS: the page hands off to the gateway's own module (inference) | owner (exclusion) |
| SH-26 Security escalation | `%CSP.UI.Portal.Dialog.EscalateLogin` | `%session.EscalateLogin`, `$$GetEscalationRoles^%SYS.SECURITY` | owner (AD-28) |
| SH-27 Custom resource on a menu item | Home's resource mode, `%CSP.Portal.ResourceDialog` | `%CSP.Portal.Utils.%SetCustomResource` | owner (AD-44 write) |
| SH-28 Contact WRC | `%CSP.UI.Portal.Contact` (no resource) | an email to the vendor | owner (vendor report) |
| OS-26 Memory and startup | `Config.Memory`, `Config.Startup` | done by Story 21.3 | closed |
| OS-28 Full System Dashboard | `%cspapp.op.utildashboard` | done by Story 16.7 (`Dashboard.cls`) | closed |
| OS-29 Composite health verdict | -- | the `systemhealth` guided workflow (`Kernel/Agent/Workflow.cls`) | closed (inference: the workflow is the verdict) |

Also on the instance but outside the catalog's Stage 4 rows: `Applications.ClientList` (WA-17, P4, Windows-only), `UserProfile` (PM-17), `Audit.SelectiveWizard` (SS-12). None is added here.

**(b, c) Proposed children.** Six, this story included.

| Child | Leaves | Ledger entries | Size |
|---|---|---|---|
| **21.10** Security settings and the KMIP journal refusal | SS-38, SS-37, SS-36 | DW-2431, DW-2457 | 5 tools, 2 screens, 1 refusal arm |
| **21.19** Shell, advisor, permission and task leaves | SS-39, PM-24, TM-17, TM-18, WA-15 | DW-2372, DW-2471 | about 6 tools |
| **21.20** OS management and log leaves | OS-24, OS-27, LG-12 | DW-1562, DW-1856, DW-2479 | 2 tools, 2 reads, 2 extensions |
| **21.21** Leaves waiting on the owner | SH-26, SH-27, SH-28, PM-23, TM-19, WA-16, OS-25 | DW-1850, DW-1280, DW-2348 | planned only after the owner answers |
| **21.22** CI flake hardening | -- | DW-2534, DW-2544, DW-2548 (E24), DW-2549 (E24), DW-2553, DW-2565, DW-2566, DW-2567, DW-2476, DW-2202 | 10 entries, in batches |
| **21.23** Test hygiene and contended client fixes | -- | DW-2430, DW-2459, DW-2499, DW-2369 (E24), DW-2225 (E24), DW-2405 (E24), DW-2352 (E24), DW-2442 (E24), DW-2474 (E24) | 9 entries |

Proposed for closing:

- DW-2214 `wontfix-theoretical`: two load and revert cycles did not reproduce it. It is real only if it appears outside a mutation reload.
- DW-2367 `wontfix-accepted`: the initial bundle is 1.90 MB, under the owner's 2,500 kB warning. reopen_if: the initial bundle crosses 2,500 kB.
- DW-2473 `wontfix-accepted`: merging the branches rewrites a shared roster (fix-risk high). reopen_if: a third port branch joins `Screen/Read.Execute`.
- DW-2355 `wontfix-accepted`: HSCUSTOM stays covered by `load -dev` and every instance shard. reopen_if: an archive install into an interoperability namespace fails a release check.
- DW-2356 `wontfix-accepted`: `CompileWithoutInterop` and the package job already refuse the regression, in CI. reopen_if: such a dependency reaches a release.

Count: 2 + 2 + 3 + 3 + 10 + 9 child entries + 5 closes = 34.

**Epic 24 contention.** Epic 24 owns the interop, analytics and developer-tool areas and the agent's tools and undo. DW-2548, DW-2549, DW-2369, DW-2225, DW-2405, DW-2352, DW-2442 and DW-2474 fall in that footprint, and so does the already-closed DW-2473. The runner may re-own the six in 21.23 to Epic 24 instead, which leaves 21.23 with three. No leaf is in Epic 24's footprint.

**(d) DW-2431 is owned by 21.10** (owner answer U-30, option A: "I agree with your recommendations"). At 21.10's spec gate, the runner amends AD-10's KMIP bullet, citing "owner answer U-30", so that the refusal set also judges journal encryption: `DBEncJournal` set now or at the next start, or a journal file the instance still needs being encrypted. The refusal shares `PROHIBITED.STARTUPKMIP` and uses this owner-approved sentence verbatim: "Journal encryption is on, or a journal file the instance still needs is encrypted, and OcuPilot cannot check that the KMIP server is reachable and holds its key, so a start that cannot activate it does not finish. Keep Unattended, or make this change on the classic Database Encryption page."

**(e) Leaves that need a new AD entry or an owner call (all parked in 21.21):**

- SH-26 escalation: a session escalation re-roles OcuPilot's own token. That needs a new AD beside AD-28.
- SH-27: writing a classic page's custom resource changes privilege on the classic portal. That needs an AD-44 amendment (inference).
- PM-23: a TOTP QR code displays the shared secret, which AD-35 forbids.
- OS-25: AD-24, AD-35 and AD-48 withhold `Variables`. Owner: close it `by-design`, or amend those ADs.
- DW-1850: Manage-free dismount needs an AD-27 named case.
- SH-28 and TM-19: each sends to the vendor (owner-only). TM-19's local archive-only run could be split out if the owner allows.
- WA-16: no IRIS backing class. Moving it to the exclusion register drops scope (owner).
- DW-1280: needs a new user-facing sentence (string veto).
- DW-2348: a stricter security header (veto window).

Two leaves may need an AD change, to be settled when their child is planned. SS-38 might need an AD-10 arm, for example for `RequiredRole` (inference); it goes to the owner only if an arm is needed. TM-17 reads a path that the task definition stores rather than one the caller supplies; whether that fits AD-21 is an inference to check.

**Decided in-stage:** WA-15 and WA-16 count as six-area leaves. The child numbers follow Rule 17's highest-number rule (21.18 is the highest).

## Verification

Shared surfaces: none (nothing is implemented in this pass).

## Auto Run Result

Status: blocked
Blocking condition: intent gap -- split 21.10 into six children (21.10 security settings + DW-2431; 21.19 shell/advisor/permission/task; 21.20 OS and log; 21.21 owner-gated leaves; 21.22 CI flake hardening; 21.23 test hygiene); 21 leaves inventoried on ocupilot, 34 ledger entries assigned (29 to children, 5 proposed closed); see Design Notes.
