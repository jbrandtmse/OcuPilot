---
title: 'Story 21.21: Leaves that wait on the owner'
type: 'feature'
created: '2026-11-15'
status: 'done'
baseline_revision: 'd576e032e0da8e01cee1e7ef942f1fbb1830140b'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-21-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-21-12-mirroring.md'
warnings: ['multiple-goals', 'oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Owner answer U-65 (option A) leaves this story four items to build and four leaves to exclude. Dismount needs `%Admin_Manage:USE` only because the self-protection check reads the protected set through admin API routes that answer Manage alone, while the classic page lets an `%Admin_Operate` holder dismount (DW-1850). A write that fails after its confirm is claimed tells the person "That tool could not be answered on this instance." (DW-1280). An editor-opened tab inherits a copy of the tab's storage, token pair included (DW-2348). OcuPilot cannot assign a custom resource to a classic menu item (SH-27). Security escalation, Contact WRC, diagnostic reports and Web Gateway management have no exclusion-register row.

**Approach:** Read the dismount's protected set through `DatabasePort` from the vendor's configuration classes under the caller's own privilege (a new AD-27 named case), and drop Manage from dismount. Show a failed write's own fault sentence on the confirm path, the sentence the screen's action already shows. Measure `Cross-Origin-Opener-Policy: same-origin` on the shell document, and ship it only if it removes the copy and breaks nothing. Add four not-planned register rows with their catalog and extract edits. SH-27 needs an architecture record that AD-44 does not give, so its batch is written and held (see Design Notes).

## Boundaries & Constraints

**Always:**

- The protected set and its refusal stay as AD-10 states them. A read that fails refuses, on both callers.
- Every port gates first (AD-29), and `%SYS` is entered by save and restore (AD-16).
- A fault's sentence reaches the person exactly as the screen's own action shows it (AD-39, AD-53).
- The COOP header goes only on the shell document, never on the API or on assets.
- Register, catalog and extract change in the same commit, and the register is edited add-only.
- Shared registration files take add-only edits.

**Never:**

- No AD edit in this story. The runner writes the AD-27 named case at the spec gate, citing "owner answer U-65".
- No change to the other arms that call `OwnDatabaseNames`, the config arm and the key arm.
- No new product string unless the gate rules one.
- Nothing from Batch 5 (SH-27) until its record exists.
- Not planned here, waiting on owner item U-70: PM-24 resource export and import, TM-17 a task's output file, and TM-18's Task Manager mail password. DW-2625 is Story 21.24's.
- Nothing for PM-23 or OS-25, which are closed by design (DW-2614, DW-2615).
- No run or write on `ocupilot`. No run on `ocupilot-ci` until the runner frees it.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Operate-only dismount | Caller holds `%Admin_Operate:USE` and `%DB_IRISSYS:READ`, no Manage; target is a probe database | Dismounts on both callers; the proposal card and the row action succeed | No error expected |
| Operate-only dismount of a protected database | Same caller; target directory is `IRISSYS`'s, OcuPilot's, or the install namespace's globals database | 403 `PROHIBITED.OCUPILOTDATABASE` with its sentence; no port write | Refused, never `AUTH.NOPRIVILEGE` |
| Protected-set read fails | The `Config.*` read errors (fixture `names` or `directories`) | 403 `PROHIBITED.OCUPILOTDATABASE` | A failed read refuses |
| Write fails after the claim | Confirm passes every gate, then the port answers a fault such as `PORT.NOTFOUND` | 4xx or 500 with the fault's code and its own `Kernel.Fault` sentence; the row stays burned and confirmed; the tool-call card shows "failed — <that sentence>" | A fault with no reason falls back to the code's sentence |
| Editor-opened tab with COOP | Shell served with `Cross-Origin-Opener-Policy: same-origin`; the editor frame opens a tab without `noopener` | The new tab has no `ocupilot.token-pair` and `opener` is null | Measured in Task 0; not shipped if it does not hold |

</intent-contract>

## Code Map

- `src/OcuPilot/Screen/Tool/DatabaseDismount.cls:5-46` -- `OWNSETRESOURCE` (`%Admin_Manage`) and the `PrivilegePairs` override that appends it. Both go, along with the header paragraph that explains them.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls:3097-3114` -- the dismount branch of `Database` (`PortClassOf`, `OwnDatabaseNames`, `OwnDatabaseDirectories`, `DatabasePort.SameDirectory`).
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls:3166-3207` -- `OwnDatabaseNames` (admin API `Namespace.Namespace` `GET`) and `OwnDatabaseDirectories` (`Database.ConfigCRUD` `LIST`). The config arm (:3121, :3144) and the key arm (:3754-3756) call them too.
- `src/OcuPilot/Port/DatabasePort.cls:48,889` -- extends `AdminPort`; `SameDirectory`. Home of the new vendor-class reads.
- `src/OcuPilot/Test/DatabaseProhibitedFixture.cls:11-26` -- overrides both helpers (probe name; `^||OcuPilotDatabaseOwnFail`).
- `src/OcuPilot/Test/DatabaseActionsGate.cls:29,149` -- armed (`OCUPILOT_ALLOW_PRINCIPALS`). `OcuProbe184GateDismount` holds Manage; `TestAnOperateOnlyDismountIsRefusedForItsPairNeverProhibited` expects `AUTH.NOPRIVILEGE %Admin_Manage:USE`.
- `src/OcuPilot/Test/DatabaseDescriptor.cls:306-313`, `src/OcuPilot/Test/DatabaseActionsProhibited.cls:76-148`, `ui/browser/database-operations.browser-spec.mjs:447,571`, `ui/tools/impact.test.mjs:187` -- dismount pairs and the arm.
- `src/OcuPilot/Kernel/Proposal/Confirm.cls:248,461-485` -- `Transition`'s write-failure branch keeps only `tWriteFault.%Get("code")` and drops its `reason`. The public `Confirm` is at :130/:176.
- `src/OcuPilot/Api/Confirm.cls:45,116-127,146-151` -- `RenderRefusal` and `ReasonFor`, which falls to `Api/Error.ReasonForToolCode` and from there to `REASONTOOLUNAVAILABLE` (`Api/Error.cls:1037`, :1258).
- `src/OcuPilot/Kernel/Fault.cls:30,168-186` -- the `PORT.*` sentences. `Api/ScreenAction.cls:659-665` already renders them verbatim.
- `src/OcuPilot/Test/ProposalConfirm.cls:695`, `src/OcuPilot/Test/ConfirmRoute.cls:118-140` -- the failed-write and over-the-wire tests.
- `src/OcuPilot/Api/StaticHandler.cls:57-63,262-264,348` -- header parameters and `ServeIndex`, which is every document response. `/ocupilot` is a REST app (`Install/Roster.cls:113-126`).
- `src/OcuPilot/Test/Static.cls:152,185,199,226,273` -- document and asset header tests.
- `ui/browser/interop-editor-frame.browser-spec.mjs:132,178` -- editor sign-in and sign-out. `ui/browser/analytics-links.browser-spec.mjs:124-137,215-246` is the existing opener and storage probe.
- `docs/exclusion-register.md:127-134,222-237` -- gate kinds and the last group. `ui/tools/exclusion-register.test.mjs:93-114,236-286` holds register IDs equal to catalog P4 and to extract Stage 5, and group headings equal, by position, to `epics.md:9570` (Story 22.1).
- `_bmad-output/planning-artifacts/research/technical-ocupilot-portal-feature-landscape-2026-09-08/feature-catalog.md:23-38,73,75,145,244` -- the summary table and the four rows (P3).
- `_bmad-output/planning-artifacts/prds/prd-OcuPilot-2026-09-08/extract-stages.md` -- Stage 4 rows :379, :381, :395 and :419, with the totals listed in Batch 4; Stage 5 header :642 and last group :742.

## Tasks & Acceptance

**Execution.** Task 0 runs on `ocupilot-ci` once the runner frees it, and is recorded under Design Notes before any code. Each item is (inference) until measured:

- (a) A principal holding only `%Admin_Operate:USE` and `%DB_IRISSYS:READ` reads `Config.Namespaces.Get(<install namespace>)` (`Globals`, `Routines`) and `Config.Databases.Get(<name>)` (`Directory`) in `%SYS`. Without `%DB_IRISSYS:READ` the read is refused. The vendor dismount succeeds for the first principal. Create and delete the principal in the same probe. If any pair beyond those two is needed, HALT `intent gap`.
- (b) COOP, against the deployed bundle. Without the header, a tab opened from the Rule editor frame by `window.open(<editor url>, '_blank')` holds `ocupilot.token-pair` and has an opener; this reproduces Story 20.13's Q1. Then add the header to `ServeIndex` in a scratch build, and record for the same tab whether the pair and the opener are still there. Record whether the `interop-editor-frame`, `analytics-links` and `about-help-links` specs stay green, and whether a tab the configuration diagram opens still loads and signs itself in.
- Decision rule for (b): Batch 3 ships only when the pair is gone, the opener is null, and every check stays green. Otherwise Batch 3 is not built, and DW-2348 closes with the measurement, as `wontfix-accepted` with a `reopen_if` naming the failing check.

### Batch 1: DW-1850, the Operate-only dismount (server; commit when its loop is green)

- `src/OcuPilot/Port/DatabasePort.cls` -- add two class methods on the AD-27 named case:
  - `ProtectedNamespaceDatabases(pNamespace, Output pNames)` reads `Config.Namespaces.Get`'s `Globals` and `Routines`, upper-cased.
  - `ConfigDirectories(pNames, Output pDirectories)` reads `Config.Databases.Get`'s `Directory` for each name, skipping a name with no configuration.
  - Both run in `%SYS` by save and restore, under the caller's own privilege, and return an error status on any vendor error. No escalation.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` -- give `OwnDatabaseNames` and `OwnDatabaseDirectories` a trailing `pFromConfig As %Boolean = 0`. When it is 1, they read through the two `DatabasePort` methods instead of the admin API, keeping the same outputs and the same error-on-failure. Only the dismount branch passes 1. Update the doc comments that say "through the port as the caller".
- `src/OcuPilot/Screen/Tool/DatabaseDismount.cls` -- delete `OWNSETRESOURCE` and the `PrivilegePairs` override. The header says the refusal reads the protected set through the database port's configuration read under Database details' own pairs.
- `src/OcuPilot/Test/DatabaseProhibitedFixture.cls` -- both overrides take and forward `pFromConfig`.
- `src/OcuPilot/Test/DatabaseActionsGate.cls` -- drop `%Admin_Manage:U` from `OcuProbe184GateDismount`. Replace `TestAnOperateOnlyDismountIsRefusedForItsPairNeverProhibited` with `TestAnOperateOnlyDismountWritesAndAProtectedOneIsRefusedBySet`. On both callers, that principal dismounts the probe database and mounts it back, and is refused `PROHIBITED.OCUPILOTDATABASE` on `IRISSYS`'s directory.
- `src/OcuPilot/Test/DatabaseActionsProhibited.cls` -- add `TestTheDismountJudgesTheSetWithoutTheAdminRoutes`. Use a seam port whose `Invoke` fails for `Namespace.Namespace` and `Database.ConfigCRUD`; dismounting a protected directory is still refused `OCUPILOTDATABASE`, and dismounting the probe is permitted.
- Shared-surface updates: `DatabaseDescriptor` (dismount's pairs), `database-operations.browser-spec.mjs` and `impact.test.mjs` where they name Manage, and the comment in `ui/src/app/areas/os-management/database-details.page.ts:124` if it names Manage.

### Batch 2: DW-1280, a write that fails after the claim (server; commit when its loop is green)

- `src/OcuPilot/Kernel/Proposal/Confirm.cls` -- `Transition` and `Confirm` gain a trailing `Output pReason As %String`. On the write-failure branch it is set to `tWriteFault.%Get("reason")`; everywhere else it is "".
- `src/OcuPilot/Api/Confirm.cls` -- `RenderRefusal` takes an optional `pReason`. A non-empty value is rendered as the envelope's reason in place of `ReasonFor(pCode)`. The confirm call site (:45) passes it, and the cancel and draft call sites do not change.
- `src/OcuPilot/Test/ProposalConfirm.cls` -- `TestAFailedWriteLeavesTheProposalBurned` also asserts that the reason equals the fault's own sentence and is not `Api.Error.#REASONTOOLUNAVAILABLE`.
- `src/OcuPilot/Test/ConfirmRoute.cls` -- add `TestAWriteThatFailsAfterTheClaimAnswersItsFaultSentenceOverTheWire`. It uses the same failing-write fixture over HTTP and checks the status, code, sentence and `detail.state`.

### Batch 3: DW-2348, the COOP header (server; only if Task 0 (b) passes)

- `src/OcuPilot/Api/StaticHandler.cls` -- add `Parameter COOPHEADER = "Cross-Origin-Opener-Policy"` and `Parameter COOPVALUE = "same-origin"`, set in `ServeIndex` beside the CSP header. `ServeAsset` does not set it.
- `src/OcuPilot/Test/Static.cls` -- the root, HEAD and deep-link document tests assert the header. The hashed-asset test asserts that it is absent.
- `ui/browser/interop-editor-frame.browser-spec.mjs` -- add-only test "a tab the editor frame opens without noopener carries no token pair and no opener", using `analytics-links`' probe shape.

### Batch 4: the register rows (docs; commit with Batch 1 or alone)

- `docs/exclusion-register.md` -- add-only. Add a new last group `### Not planned` with rows SH-26, SH-28, TM-19 and WA-16, using the row text in Design Notes.
- `feature-catalog.md` -- change SH-26, SH-28, WA-16 and TM-19 to `P4`. Set TM-19's Co-pilot tool to `none`, append "— excluded: <reason>" to each Evidence cell as SH-29 does, and recompute the summary table (:23, :25, :27, :38).
- `extract-stages.md` -- move the four rows from Stage 4 into a new last Stage 5 group, `**Not planned** — 4 rows`, in the same row grammar. Name the group in Stage 5's prose (:644), and recompute every total that counted the rows. Starting list: :17, :28, :29, :369, :375, :390, :413, :624-638, :642, :767-779 (add a TM row), :816-831, the backing rows :837, :839, :843 and :850, :921, and :973-974. Then grep each ID and each count to find the rest.
- `epics.md:9570` -- Story 22.1's group list gains "; and not planned" last, only if the spec gate rules it (Epic 22's block; escalated). Without that ruling, Batch 4 is not built and is reported.

### Batch 5: SH-27, a custom resource on a classic menu item (MOVED to Story 21.37 by the orchestrator's ruling of 2026-11-20; AC6 to AC17 and the ruled strings below are 21.37's, kept here as its source and not built or reviewed in this story)

- `src/OcuPilot/Port/PortalResourcePort.cls` -- new, on `UserCopyPort`'s shape. `PAIRS` is `%Admin_Secure:USE`. `LIST` reads `%SYS.Portal.Resources:List`. `SET` calls `%CSP.Portal.Utils.%SetCustomResource(page, resource)` in `%SYS` for a page `%IsPortalPage` resolves and a resource `Security.Resources` defines. `CLEAR` is the same call with "".
- `src/OcuPilot/Screen/Descriptor/PortalPageResources.cls` -- new Permissions list with `classicPage` `%CSP.Portal.ResourceDialog`. Tools `permissions.pageresources.assign` and `.clear` (AD-51, AD-53), whose keys ship enabled and are added to `Baseline.cls`.
- Rosters: `ClassicPageGate.OWNPAIRS`, `Descriptor`, `SurfaceCoverage`, `EndpointCoverage`, `GovernanceBaseline`, `PortGate` and `navigation.test.mjs`. Plus strings, once they are ruled.
- Also: the `Prohibited.cls` arm for the two tools (beside `ScreenPermission`, add-only), `EntityType` (a `page-resource` type, add-only), `Screen/Registry.cls` and the generated `Titles.cls` and `screens.generated.ts` (regenerated by their tool), `ui/browser/page-resources.browser-spec.mjs` (new), and the Epic 24 contention check on each existing file.

**Acceptance Criteria:**

- AC1 (DW-1850): Given a principal with `%Admin_Operate:USE` and `%DB_IRISSYS:READ` and no Manage, when it dismounts a non-protected database through the confirm and through the row action, then both succeed. When it targets a protected database's directory, then both are refused 403 `PROHIBITED.OCUPILOTDATABASE`.
- AC2 (DW-1850): Given the admin API's namespace and configuration routes failing, when a dismount is judged, then the protected set is still read and enforced through `DatabasePort`'s configuration read.
- AC3 (DW-1280): Given a confirmed proposal whose port write fails after the claim, when the browser's confirm request returns, then the envelope's reason is the fault's own sentence, the row is burned and confirmed, and the tool-call card shows "failed — <that sentence>".
- AC4 (DW-2348; only if Batch 3 ships): Given the shell served with the header, when the editor frame opens a tab without `noopener`, then that tab holds no `ocupilot.token-pair` and has no opener, and every editor still signs itself in in its frame.
- AC5: Given the register, catalog and extract, when `exclusion-register.test.mjs` runs, then SH-26, SH-28, TM-19 and WA-16 each have a row in the not-planned group, with the reasons OcuPilot's own token's roles, a send to the vendor (NFR-6) for SH-28 and TM-19, and no backing class.
- AC6 (SH-27, assign): Given a caller with `%Admin_Secure:USE`, a page `%IsPortalPage` resolves that no OcuPilot screen declares, and a resource `Security.Resources` defines, when the person assigns it through the dialog and when the agent's confirmed proposal assigns it, then `%SYS.Portal.Resources` holds the row under the normalized class name (`%CSP.Portal.ResourceDialog.cls` is stored as `%CSP.Portal.ResourceDialog`), the list shows it, the read-back matches, and each accepted write is audited as AD-15 and AD-53 require.
- AC7 (SH-27, clear): Given a page with a custom resource, when the person clears it and when the agent's confirmed clear proposal runs, then the row is gone and the list no longer shows it. A clear of a page with none is refused with a sentence and no vendor call.
- AC8 (SH-27, own screens): Given a page that a Home or Agent co-pilot screen declares (`%CSP.Portal.Home`), when an assign is judged on either caller (the agent's at its mint, the person's at its Save), then it is refused 403 `PROHIBITED.OCUPILOTSCREEN` with the sentence already in `Prohibited.cls`, no port call, and no row written. The declared pages are derived from the registry's descriptors, never a literal list.
- AC9 (SH-27, lowering): Given a page that a built OcuPilot screen in an area that declares pairs replaces, and that already holds a custom resource, when the agent proposes a clear or a change of it, then the proposal is minted destructive with no typed name and carries the consequence line, and the person's dialog shows the same line at the field. An assign to a page with none, and a clear or change on a page no screen replaces, are not minted destructive.
- AC10 (SH-27, bad input): Given a page `%IsPortalPage` does not resolve, or a resource `Security.Resources` does not define, or an assign with an empty resource, when either caller sends it, then it is refused 422 on its own field before any vendor call, with the sentences in the strings list.
- AC11 (SH-27, stale): Given a proposal minted when a page held resource R1, when R1 is changed by someone else before the confirm, then the confirm refuses as stale and writes nothing (AD-51 fingerprint of the fresh read; AD-34's hold).
- AC12 (SH-27, the gate honors it): Given a custom resource assigned to a page a built screen replaces, when `Screen.Gate.RequiredPairs` is read on the next call, then it includes that resource at USE, a caller lacking it is refused that screen by name, and after the clear it is admitted again. The reader caches nothing (AD-64 item 2).
- AC13 (AD-59): Given each of the two tools, when its copy-out draft is rendered, then it shows the `%CSP.Portal.Utils.%SetCustomResource` call with the stored page and resource (an empty resource for the clear), runs no write, and `DraftRegistry` names no tool without a script form.
- AC14 (governance): Given the two tool keys `permissions.pageresources.assign` and `permissions.pageresources.clear`, then `Baseline.cls` carries both, shipping `true` (AD-22), and `GovernanceBaseline` is green.
- AC15 (port gate): Given a caller without `%Admin_Secure:USE`, when it calls any endpoint of `PortalResourcePort`, then it is refused `AUTH.NOPRIVILEGE` naming that pair before any vendor call (AD-29), and the screen's own gate refuses it the screen.
- AC16 (rosters): Given the new screen, tools, entity type and port, when `SurfaceCoverage`, `EndpointCoverage`, `PortGate`, `Descriptor`, `ScreenGrounding`, `ClassicPageGate` and `navigation.test.mjs` run, then each names them, each count derived from the registry (Rule 30).
- AC17 (browser, the outermost surface): Given the deployed bundle, when `page-resources.browser-spec.mjs` signs in as a `%Admin_Secure` holder, assigns a resource to a probe-safe page, sees its row, changes it, clears it, and tries a page a Home screen declares, then each step shows the screen's own answer, and the refusal shows the existing sentence.

### Review Findings

Code review 2026-11-20 (Batches 1, 2 and 4; full-opus, four layers; 33 rows, 14 entries: 0 high, 5 med, 9 low). Patches applied, uncommitted.

- [x] [Review][Patch] MED: a write that fails after the claim with an unnamed fault rendered `INTERNAL` without `detail.state`, so the card offered Confirm on a spent token [src/OcuPilot/Api/Confirm.cls RenderRefusal; Api/Error.cls RenderInternal gains an optional detail] -- pinned in `ReadBackRoute`.
- [x] [Review][Patch] MED: `ConfirmRenderProbe` copied `HandleConfirm`, so dropping `tReason` at the shipped call stayed green [Api/Confirm.cls `KernelConfirmClass` seam; Test/ConfirmRenderProbe.cls now runs `HandleConfirm`].
- [x] [Review][Patch] MED: the AC1 gate test sent the IRISSYS legs through the real port, so a regressed set would dismount IRISSYS [Test/DatabaseActionsGate.cls `Legs` accept flag; Test/DatabaseActionsGateProbe.cls] -- the legs now write through `DatabaseAcceptPort` and assert no dismount was sent.
- [x] [Review][Defer] MED: AD-8's Story 18.4 sentence (spine :282) and `.memlog.md:276` still say dismount declares `%Admin_Manage:USE` -- deferred: DW-2805 routed to this story for the runner's Rule 20 correction (no AD edit in-stage).
- [x] [Review][Defer] MED: WA-16's register reason "No IRIS class backs it" is false (`%CSP.Mgr.GatewayMgr` reads and sets the gateway's configuration) [docs/exclusion-register.md] -- deferred: DW-2806 decision-pending (ruled public text).
- [x] [Review][Patch] LOW: the two `DatabasePort` configuration reads had no direct test (the 420 skip never ran) [Test/DatabaseActionsProhibited.cls `TestTheConfigurationReadsSkipAMissingNameAndRestoreTheNamespace`].
- [x] [Review][Defer] LOW: the Globals half of `ProtectedNamespaceDatabases` is unpinned (no namespace on the instance separates globals and routines) -- deferred: DW-2807 wontfix-accepted.
- [x] [Review][Defer] LOW: stale planning counts beside the edit (`epics.md` :964, :973, :9812; `research.md` :440, :442) -- deferred: occurrence on DW-2619.
- [x] [Review][Patch] LOW: `ToolEmit` still read the removed `OWNSETRESOURCE`; dead, and Epic 24 has no unmerged edit there now [Test/ToolEmit.cls].
- [x] [Review][Patch] LOW: `ReadBackRoute`'s new test lacked a mutation line, a status check and a blank line, and called 500 "the vendor's own status" [Test/ReadBackRoute.cls].
- [x] [Review][Patch] LOW: `Transition`'s doc said `pReason` is set on every post-claim failure; it is set when the fault names its code [Kernel/Proposal/Confirm.cls].
- [x] [Review][Patch] LOW: `DatabaseProhibitedFixture`'s header said `PortClassOf` reroutes only the own-set reads; it reroutes every arm [Test/DatabaseProhibitedFixture.cls].
- LOW by-design: TM-19's reason names the mail half only, and Story 22.1's line reads "...; and not planned" after an earlier "and" -- both are ruled text (U-73, spec gate).

Rejected: the INTERNAL branch reaching `REASONTOOLUNAVAILABLE` (false: `RenderRefusal` renders `RenderInternal` before `ReasonFor`); `%FromJSON` erroring on an empty body (false: an error is red); an empty probe directory passing vacuously and a multi-code 420 status (low, unreachable here, fails closed); the removed tool-call leg (low: the pairs are pinned by `DatabaseDescriptor` and `ToolEmit`); `ReadBackRoute` counted as AC3 wire evidence and the stale "Pass scope" line and unrun full sweep (spec edits; CI's instance shards run the sweep); no client test for a closed-row refusal card (low: the reason flows the same way).

## Spec Change Log

- 2026-11-20, orchestrator ruling on the Batch 5 halt: SH-27 (Batch 5, AC6 to AC17) is split to Story 21.37 (epics.md, add-only, with an amended note on this story); owner answer U-74 carries to it. This story closes with Batches 1, 2 and 4; Batch 3 is not built under Task 0 (b)'s decision rule and DW-2348 is closed `wontfix-accepted` with its `reopen_if`. Batch 5's strings are ruled for 21.37 (veto item) with two changes: the screen-replaces line reads "<screen> follows this page's resource and will require it from the next request.", and the clear warning reads "After this, the page needs no custom resource."

## Review Triage Log

## Design Notes

**Pass scope (runner, 2026-11-20):** the pass built Task 0 and Batches 1, 2 and 4, each committed at its boundary, and wrote Batch 5's ACs and strings without building it. Batch 3 is not built (Task 0 (b) failed). The next pass builds Batch 5 once its strings are ruled.

**Task 0 results (2026-11-20, `ocupilot-ci`, bundle md5 `5e3a2fd1` as deployed):**

- (a) Measured with throwaway principals holding `%Admin_Operate:USE` and `%DB_IRISSYS:READ` (no Manage), and `%Admin_Operate:USE` alone, logged in a child process, over the probe database `OCUPROBE184ZA` in its own directory. As the first principal: `Config.Namespaces.Get("HSCUSTOM")` answered `Globals=HSCUSTOM`, `Routines=HSCUSTOM`; `Config.Databases.Get` answered `Directory=/durable/iris/mgr/HSCUSTOM/` for both and `/durable/iris/mgr/` for `IRISSYS`; `DatabasePort` `Database.Actions` `DISMOUNT` answered `sc=1 http=200` and the database read `Mounted false`. The same principal through `AdminPort.Invoke` was refused `PORT.ACCESSDENIED` (403) on `Namespace.Namespace` `GET` (with and without a name) and on `Database.ConfigCRUD` `LIST`. As the second principal (no `%DB_IRISSYS:READ`): the switch to `%SYS` raised `<PROTECT> 206 ... /durable/iris/mgr/`, so the `Config.*` reads are refused. No pair beyond those two was needed. The probe database was remounted, then the database, both users, both roles and the probe class were removed (read back: all absent).
- (b) Baseline, no header: a tab opened by a real click in the Rule editor frame (`window.open(<editor url>, '_blank')`) had an opener and held `ocupilot.token-pair` (and `ocupilot.tab-nonce`); the editor in it signed itself in. This reproduces Story 20.13's Q1, with the configuration diagram frame opening a rule editor tab and a classic portal tab the same way. With `Cross-Origin-Opener-Policy: same-origin` on the shell document (a scratch edit to `ServeIndex`, since reverted and reloaded; the header was absent from a hashed asset): the opener was `null` in all three cases and every tab still loaded and signed itself in (the diagram's rule editor tab and the classic portal tab loaded), but `ocupilot.token-pair` was still in each tab's session storage, read again after load. The header removes the opener and not the copy. The three browser specs were not run with the header, since the decision rule is already failed.
- Reverted with Edit; `git status --short` shows no change under `src/` and the bundle was not redeployed.
- Verdict: (a) PASS. (b) FAIL (do not build Batch 3): the check "the tab holds no `ocupilot.token-pair`" fails with the header on (pair present, opener null). DW-2348 closes `wontfix-accepted` with a `reopen_if` naming that check.

**Governing ADs:** AD-10 (the database arm, unchanged), AD-27 (the named case below), AD-29, AD-16, AD-8, AD-44 and AD-64 (SH-27), AD-52 and AD-53 (one operation, two callers), AD-39 and AD-12 (one envelope; the fault's sentence), AD-40 (confirm is not a tool), AD-28, AD-47 and AD-63 (storage copy, editor frame), AD-22 (dismount's key stays `false`).

**AD-27 amendment for the spec gate** (the runner writes it, citing "owner answer U-65"; proposed text):

> **Story 21.21's case, the protected set a dismount is judged against** [AMENDED <date>, Story 21.21 spec gate, owner answer U-65, DW-1850, Rule 20]. The admin API answers `Namespace.Namespace` `GET` and `Database.ConfigCRUD` `LIST` for `%Admin_Manage` alone (measured on `ocupilot-b-ci`), while the classic Database details page dismounts for an `%Admin_Operate` holder. So for a dismount, AD-10's `OCUPILOTDATABASE` arm reads the install namespace's globals and routines databases and the protected databases' directories through `DatabasePort`. The port calls `Config.Namespaces.Get` and `Config.Databases.Get` in `%SYS` (AD-16) under the caller's own privilege, `%DB_IRISSYS:READ`, which Database details already requires. A read that fails refuses, and the dismount tool no longer requires `%Admin_Manage:USE`. The config and key arms keep the admin API's reads.

**SH-27 halt (intent gap).** AD-64 rule 2 says a classic page's custom resource "is cleared only in the classic portal", and AD-44 covers reading a custom resource, not writing one. An OcuPilot tool that sets, changes or clears one contradicts the first and is outside the second. Two readings lead to different products:

- (A, recommended) Amend AD-44 and AD-64 and build Batch 5 as written.
- (B) Build only "assign where none is assigned", which raises a requirement and never clears one, and so needs no AD change. Its gap is that nothing assigned in OcuPilot can be removed in OcuPilot.

Proposed records for (A):

- AD-44: "A classic page's custom resource may be set and cleared from OcuPilot (Story 21.21): `Port/PortalResourcePort` calls `%CSP.Portal.Utils.%SetCustomResource` in `%SYS` under the caller's own `%Admin_Secure:USE`, which is the vendor's own check, for a page `%IsPortalPage` resolves and a resource the instance defines. A change to a page an OcuPilot screen declares changes that screen's requirement at its next gate call."
- AD-64 rule 2: "...which an adjustment never clears; it is cleared in the classic portal or by AD-44's custom-resource tools."
- AD-10: "An assignment on a classic page that a Home or Agent co-pilot screen declares (`%CSP.Portal.Home`) is refused `PROHIBITED.OCUPILOTSCREEN`. A clear or a change of a page an OcuPilot screen declares is minted destructive, as an AD-64 lowering is."

Measured on `ocupilot`, read-only: `NormalizePage("%CSP.Portal.ResourceDialog.cls")` answers `%CSP.Portal.ResourceDialog`, `%CSP.Portal.Utils.%SetCustomResource` exists, and no page has a custom resource.

**Decided in-stage:**

- DW-1850 uses one extended reader with a mode, not a second copy (Rule 31). The config and key arms keep the admin API because their callers already hold Manage, and the key arm's port is not `DatabasePort`. Moving those arms is a risk this story does not need.
- DW-1280 reuses the fault's own sentence rather than writing a new one. It is the sentence the screen's action shows for the same failure (AD-53), so the agent's caller and the person's caller agree. `REASONTOOLUNAVAILABLE` stays the fallback for a tool code.
- DW-1280's wire test could not live in `ConfirmRoute`: the process-private proposal fixture is invisible to a request run over HTTP, and no real post-claim write failure maps to a named fault (the vendor's 500s map to `INTERNAL`). The sentence is pinned in `ProposalConfirm` through `Test/ConfirmRenderProbe` (an `Api.Confirm` subclass that reaches the shipped `RenderRefusal`), and `ReadBackRoute` pins the unnamed-failure case over HTTP. The tool-call card already renders the envelope's `reason` (`turn.ts`, `panel.ts`, `tool-call-card.ts`), so there is no client change.
- COOP uses `same-origin` because the item asks for the stricter policy, and `same-origin-allow-popups` would keep the opener for the frame's popups (inference). Browsers ignore COOP on a non-secure origin other than `localhost`, so a plain-HTTP instance keeps today's behavior (inference).
- The four rows go to a new last group, because none of the nine groups fits their reasons. Gate kinds: SH-26, SH-28 and TM-19 `not-applicable`; WA-16 `dependency`.

**Strings, escalated for the spec gate's ruling** (proposed; nothing is used until ruled):

- DW-1280: no new sentence. On the confirm path, a write that fails after the claim shows its fault's own sentence from `Kernel/Fault.cls:168-186`, the sentence the screen's action already shows. Examples: "That item is no longer present on this instance", "The instance rejected one of the values supplied". The ledger entry and the 21.10 inventory record no other wording.
- Register rows (public docs):

  | ID | Feature | Reason | Gate kind | Gate | How to tell it has cleared |
  | --- | --- | --- | --- | --- | --- |
  | SH-26 | Security escalation (escalate a session to a role; end it) | Escalation changes the roles of the session OcuPilot's own token runs in, which the architecture does not allow. | `not-applicable` | An approved architecture amendment lets a session escalation re-role OcuPilot's token. | The spine carries an approved amendment that names session escalation. |
  | SH-28 | Contact the WRC (send an issue to the vendor) | It sends mail to the vendor, and OcuPilot sends nothing off the instance except to the configured model provider (NFR-6). | `not-applicable` | An approved amendment to NFR-6 and the spine lets OcuPilot send to the vendor. | The PRD and the spine carry an approved amendment that names a send to the vendor. |
  | TM-19 | Diagnostic reports (the report task for the WRC) | It mails a report to the vendor, and OcuPilot sends nothing off the instance except to the configured model provider (NFR-6). | `not-applicable` | An approved amendment to NFR-6 and the spine lets OcuPilot send to the vendor. | The PRD and the spine carry an approved amendment that names a send to the vendor. |
  | WA-16 | Web Gateway management | No IRIS class backs it: the classic page hands off to the Web Gateway's own management pages. | `dependency` | An IRIS class backs Web Gateway management on a supported release. | Cite the class, on a supported release, that reads and sets the gateway's systems and settings. |

- Story 22.1's group line (`epics.md:9570`, Epic 22's block) gains "; and not planned".

**Strings for Batch 5, escalated** (proposed in EXPERIENCE.md's style; nothing is used until ruled; each is modeled on the Screen permissions row, `EXPERIENCE.md:604`, or the Resources and Roles lists, `:359-360`; the screen is the Permissions list, source kind `portalresource`):

- Title and side-bar entry: "Page resources" (as "Screen permissions").
- Columns: "Page" (the classic page's class), "Resource", "Screen" (the OcuPilot screen that replaces the page, empty if none; reuses the shared "Screen" header).
- Empty state: "No classic pages have a custom resource on this instance." (as "No resources on this instance."); its second line invites the agent with "assign a resource to a classic page" (as "add an item to this production").
- Note under the title: "A page's custom resource decides who may open it in the classic portal and in OcuPilot. The instance still checks every read and write." (as "Changing a screen's permissions changes who OcuPilot lets open it; ...").
- Suggested prompts: "Which classic pages have a custom resource?", "Which resource does the Users page require?", "Which OcuPilot screens follow a page's custom resource?" (as the Screen permissions three).
- Action labels: primary "Assign resource"; row actions "Change resource" and "Clear resource" (as "Change permissions" and "Reset permissions").
- Dialog titles: "Assign a resource to a page"; "Change the resource of <page>" (as "Change the permissions of <screen>"). Field labels "Page" and "Resource". Page field help: "Name a classic page by its class." Resource field help: "Name a resource this instance defines."
- Line for a page an OcuPilot screen replaces: "<screen> follows this page's resource and will require it, at USE, from the next request." (as "The classic portal also requires <pair> here, ...").
- Line for a page no screen replaces: "No OcuPilot screen replaces this page, so only the classic portal uses this resource."
- Consequence, change: "Accounts that hold only the old resource can no longer open <screen>." Consequence, clear: "More accounts may open <screen>. The instance still checks what they do there." (as "More accounts may open this screen. ..."). Clear's warning before it is sent: "This page will need no custom resource again." (as "This screen will require its declared permissions again.").
- Proposal card summaries: "Assign <resource> to <page>", "Change the resource of <page> to <resource>", "Clear the resource of <page>" (as "<name>: <n> changed fields").
- Refusals the server sends: unknown page "No classic portal page has that name." (as "No screen has that identifier."); an empty resource on assign "Name the resource to assign. To remove one, clear it instead."; a clear with none "This page has no custom resource, so there is nothing to clear." (as "This screen already requires its declared permissions, so there is nothing to reset."). Reused unchanged: "This instance defines no resource of that name." and the `PROHIBITED.OCUPILOTSCREEN` sentence ("This is OcuPilot's own screen. Its permissions cannot be changed.").
- Not user-facing, decided in-stage: the two tools' model-facing descriptions and the dialog's accessible names that reuse "Page" and "Resource".

**Noted for the runner:** if Batch 3 ships, the sentence in AD-28, AD-47 and AD-63 that "a tab a page in it opens without `noopener` starts with a copy" holds only where the header is ignored. Correcting it is a Rule 20 call, not this story's edit.

**Contended paths (Epic 24, slot B; `git log origin/OCU-1-epic24 ^origin/feature/OCU-1_ocupilot-mvp`, 2026-11-15):**

- `Prohibited.cls` was changed by Epic 24 (24.3, in `PermittedChangeFields` and the production branch of `Prohibits`). This story edits only the database arm and its two helpers, in different hunks. Ruled here: allowed.
- `ClassicPageGate`, `Baseline.cls`, `strings.ts` and `screens.generated.ts` were also changed by Epic 24. Batches 1 to 4 do not edit them; a regenerated `screens.generated.ts` is generated output.
- None of these show an Epic 24 commit: `DatabasePort`, `DatabaseDismount`, the database tests, `Kernel/Proposal/Confirm`, `Api/Confirm`, `Api/Error`, `StaticHandler`, `Static`, the register, catalog and extract, and `exclusion-register.test.mjs`.

**Integration ACs and linkage (Rules 1-2):** `DatabasePort`'s new reads are consumed in this story by `Prohibited`'s dismount arm (AC1, AC2, against a real principal on `ocupilot-ci`). **Consumed-by:** none planned. **Consumes:** `Screen.Gate`, `Kernel.Proposal.Operation`, `Kernel.Fault`, `Api.Error`.

**Ledger inbox:** DW-1850 → Batch 1 (AC1, AC2); DW-1280 → Batch 2 (AC3); DW-2348 → Task 0 (b) and Batch 3 (AC4), or closed with the measurement. Declined: none.

## Verification

Shared surfaces (each is in the `(loop)` set; the implement stage greps `ui/browser`, `ui/tools`, the `ui/src` specs and `src/OcuPilot/Test` for the old shape):

- Dismount's pairs: `DatabaseActionsGate`, `DatabaseDescriptor`, `DatabaseActions`, `SeamDatabaseDismount`, `database-operations.browser-spec.mjs`, `impact.test.mjs`, and `screens.generated.ts` if it mirrors tool pairs.
- The database arm: `DatabaseActionsProhibited`, `DatabaseWrite` (`OwnDatabaseNames` call at :460), `DatabaseRefusals`.
- The confirm envelope: `ProposalConfirm`, `ConfirmRoute`.
- Document headers: `Static`.
- Register, catalog and extract: `exclusion-register.test.mjs`.
- Batch 5: `SurfaceCoverage`, `EndpointCoverage`, `GovernanceBaseline`, `PortGate`, `Descriptor`, `ScreenGrounding`, `ClassicPageGate`, `DraftRegistry`, `Prohibited`, `navigation.test.mjs`, `screens.generated.ts` and the `Titles.cls` regeneration.

Every test added or changed passes on a fresh environment, in either order. Mutations (Rule 19), one per AC:

- AC1: restore `OWNSETRESOURCE` → `DatabaseActionsGate` goes red.
- AC2: the dismount branch passes `pFromConfig` 0 → `TestTheDismountJudgesTheSetWithoutTheAdminRoutes` goes red.
- AC3: `RenderRefusal` ignores `pReason` → `ProposalConfirm` goes red.
- AC4: not built (Task 0 (b) failed), so no mutation.
- AC5: remove one register row → `exclusion-register.test.mjs` goes red.

Batch 5 mutation plans (to be applied when it is built; each `mutation:` line is written then):

- mutation (plan): AC6, `PortalResourcePort.SET` writes the page un-normalized -> the new `PortalResourcePort` test's stored-key assertion red.
- mutation (plan): AC7, `CLEAR` calls `SET` with the old resource -> the clear test red (the row stays).
- mutation (plan): AC8, the new `Prohibited` arm skips the declared-pages check -> `Prohibited` and the new wire test red on both callers.
- mutation (plan): AC9, the mint classifies every change non-destructive -> the destructive-mint test red.
- mutation (plan): AC10, drop the `%IsPortalPage` check -> the unknown-page test red; drop the `Security.Resources` check -> the unknown-resource test red.
- mutation (plan): AC11, the tool fingerprints nothing -> the stale-confirm test red.
- mutation (plan): AC12, `Gate.ClassicResource` reads a cached copy -> the gate test red after a clear.
- mutation (plan): AC13, remove the port's `Snippet` branch for the clear -> `DraftRegistry` red, naming the tool.
- mutation (plan): AC14, remove one key from `Baseline.cls` -> `GovernanceBaseline` red.
- mutation (plan): AC15, drop `PAIRS` -> `PortGate` red.
- mutation (plan): AC16, delete the `SurfaceCoverage` row -> `SurfaceCoverage` red alone.
- mutation (plan): AC17, remove the `clear` row action from the descriptor -> the browser spec red, against a rebuilt and redeployed bundle.

Mutations run (Batch 1, `ocupilot-ci`), each reverted with Edit (checksums equal) and the reverted source reloaded:

- mutation: AC1, `OWNSETRESOURCE` and its `PrivilegePairs` override restored on `DatabaseDismount` -> `DatabaseActionsGate` red (`TestAnOperateOnlyDismountWritesAndAProtectedOneIsRefusedBySet` and `TestExactlyTheDeclaredPairsWriteOnBothCallers`).
- mutation: AC2, the dismount branch of `Prohibited.Database` passes `pFromConfig` 0 -> `DatabaseActionsProhibited.TestTheDismountJudgesTheSetWithoutTheAdminRoutes` red.
- mutation: AC3 (Batch 2), `Api.Confirm.RenderRefusal` ignores `pReason` -> `ProposalConfirm.TestAWriteThatFailsAfterTheClaimRendersItsFaultSentence` red (`ConfirmRoute` stays green: it cannot arm the fixture); and `Kernel.Proposal.Confirm.Transition`'s write-failure branch drops its `pReason` assignment -> `ProposalConfirm.TestAFailedWriteLeavesTheProposalBurned` and the same test red. Both reverted with Edit (`git diff` shows only the intended change) and the source reloaded.
- mutation (code review): AC3, `Api.Confirm.HandleConfirm` drops `tReason` from its `RenderRefusal` call -> `ProposalConfirm.TestAWriteThatFailsAfterTheClaimRendersItsFaultSentence` red (run 917); and `RenderRefusal`'s internal branch drops `pDetail` -> `ReadBackRoute.TestAnUnnamedVendorFailureAfterTheClaimStaysGenericOverTheWire` red (run 918). Reverted (`cmp` identical) and reloaded.
- mutation (code review): AC2, `DatabasePort.ConfigDirectories` refuses on a missing name -> `DatabaseActionsProhibited.TestTheConfigurationReadsSkipAMissingNameAndRestoreTheNamespace` red alone (run 919). Reverted (`cmp` identical) and reloaded.
- mutation: AC5 (Batch 4), the SH-28 row removed from the register -> `exclusion-register.test.mjs` red (the catalog-P4 test, the extract-position test and the new not-planned test; 15 pass, 3 fail); restored with Edit, `cmp` against the pre-mutation copy identical, 18 pass.

**Commands** (one per foreground call, `timeout: 600000`, against `ocupilot-ci` only, never two test calls in one message):

- `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/b708a79b-b765-42ec-adea-dbc87acf6251/scratchpad/e21u/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` (loop) -- expected: `LOADERRORS=0`.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<Class>` (loop), once each for `DatabaseActionsGate`, `DatabaseActionsProhibited`, `DatabaseActions`, `DatabaseDescriptor`, `DatabaseWrite`, `DatabaseRefusals`, `SeamDatabaseDismount` (if a test case), `ProposalConfirm`, `ConfirmRoute` and `Static` -- expected: green.
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/` (loop) -- expected: within the 2500/4000 kB budgets.
- `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/<file>.browser-spec.mjs` (loop), one call per file: `database-operations`, `interop-editor-frame`, `analytics-links`, `about-help-links` -- expected: green.
- `cd ui && node --test tools/exclusion-register.test.mjs tools/impact.test.mjs` and `cd ui && npm run test:tools` (loop) -- expected: green.
- `uv run scripts/check-objectscript.py`, `bash scripts/lint-docs.sh` (loop) -- expected: clean.
- The full ObjectScript sweep over `src/OcuPilot/Test` (once, before `dev_complete`), one class per call or in batches sized from `ui/tools/ci-timings.json` to about 8 minutes -- expected: green. The full browser suite is left to CI (Rule 29).

**Runner ruling at the spec gate (2026-11-16):** the AD-27 named case is written into the spine (owner answer U-65). Batches 1 to 4 are ready. Batch 5 (SH-27) is held: whether owner answer U-65 covers the AD-44 and AD-64 records is asked of the orchestrator, and the implement stage builds Batch 5 only if a ruling is recorded here. Story 22.1's group line is extended add-only. The escalated strings and register rows are kept (veto U-73).

**Owner answer U-74 (2026-11-16, "A: amend and build (Recommended)"):** the AD-44 and AD-64 records are written into the spine as proposed. The AD-10 `PROHIBITED.OCUPILOTSCREEN` arm proposed beside them is written too (orchestrator ruling U-75: U-74 covers it). Batch 5 is built in this story.

## Auto Run Result

Status: done
Blocking condition: none (lead, 2026-11-20: Batch 5 split to Story 21.37 by the orchestrator's ruling; this story's scope is Batches 1, 2 and 4, built below)

This pass (2026-11-20, baseline d576e032e): Task 0 measured on `ocupilot-ci`, (a) PASS and (b) FAIL (see "Task 0 results"). Committed: Batch 1 `db22ccb70` (DW-1850, AC1 and AC2), Batch 2 `d0b4d7101` (DW-1280, AC3), Batch 4 `e7f4b799d` (AC5). Batch 3 (DW-2348, AC4) is not built: the header removed the opener but not the stored token pair, so DW-2348 closes `wontfix-accepted` with a `reopen_if` naming the pair check. Batch 5 (AC6 to AC17) and its strings are written above and not built. Verification run on the committed tree: every Database test class (11), `ProposalConfirm`, `ConfirmRoute`, `ReadBackRoute`, `Static`, `ScreenGrounding`, `DraftRegistry`, `Prohibited`, `PortGate` green; `exclusion-register.test.mjs`, `npm run test:tools`, `check-objectscript.py` and `lint-docs.sh` clean. Not run: the full ObjectScript sweep and the code-review layers, which follow Batch 5.
