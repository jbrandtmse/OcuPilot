---
title: 'Story 21.12: Mirroring'
type: 'feature'
created: '2026-11-14'
status: 'done'
baseline_revision: '187a5d77ab1ea372129a30bde8e94a52011845e0'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Mirroring has no screen and no API in OcuPilot. The story's criteria ask that mirror create, edit for failover and async members, join, the monitor, and member and database actions each round-trip, that every mirroring write ship as a confirmed proposal with its key disabled, and that removing a mirror together with its databases join the kernel's prohibited set (AD-10).

**Approach:** Not planned. The first criterion cannot be met as worded on any runtime this project has, and the AD-10 arm this story must name describes a vendor effect that does not exist. Both need an owner ruling before a plan can be written (see Design Notes).

## Boundaries & Constraints

**Always:** whatever is ruled, every mirroring write is a confirmed proposal whose governance key ships `false` (AD-22), it reaches the vendor only through a gated `MirrorPort` (AD-29), and the AD-10 mirror case lives in the kernel and is refused from either caller.

**Never:** a write to `ocupilot`, a second instance, or a plan for code whose vendor call no project runtime can run, unless the owner chooses (B).

## I/O & Edge-Case Matrix

These are the only two rows that hold under every option below. Both are observed through the OcuPilot API on `ocupilot-ci`.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Monitor, not a member | `IsMember()` 0, `NoMirror()` 1 | No member or database rows, and the not-a-member and license notes | none |
| Kernel case | a mirror-removal proposal with `DeleteDB` set | Refused `PROHIBITED.MIRRORDATABASES` before any vendor call, from either caller | nothing called |

## Owner answer U-39 (2026-11-15)

The owner chose option A, quoted: "A: monitor + refusal (Recommended)". This story keeps the mirror monitor and OcuPilot's refusal of removing a mirror with the option that takes its databases out of mirroring (AD-10, wording corrected in the spine the same day). The mirroring writes are not built: each gets a row in Epic 22's exclusion register (`docs/exclusion-register.md`) in its license-gated group, add-only (Epic 24 also adds rows there). The story's criteria in `epics.md` are narrowed to match.

</intent-contract>

## Code Map

- `irissys/%CSP/UI/Portal/Mirror/Monitor.cls` -- the classic page: `RESOURCE` `%Admin_Operate` (:22), `MirrorMemberType` from `$System.Mirror.IsMember()` (:42; 0 none, 1 failover, 2 async), "This system is not a mirror member." (:1223-1228), member tables over `MemberStatusList` (:1236, :1315). Its menu entry is disabled without `%DB_IRISSYS` READ and WRITE (`irissys/%CSP/UI/Portal/Application.cls:346,440`).
- `irissys/SYS/Mirror.cls:446-468` -- `MemberStatusList(MirrorName)`, columns `MemberName`, `CurrentRole`, `CurrentStatus`, `JournalLatency`, `DatabaseLatency` (localized text). `irissys/MIRRORMGR.int:54-56` -- mirroring does not start while `$System.License.NoMirror()` is 1.
- `irissys/SYS/Mirror.cls:1166-1189` -- `RemoveMirrorConfiguration(DeleteDB)` and `RemoveOneMirrorSet(DeleteDBs)`: the flag takes the databases out of mirroring and keeps them.
- Port model: `src/OcuPilot/Port/BackupPort.cls` (`PAIRS` :30, `GATECLASS` :37, `ENDPOINTS` :53, `TYPELIST`/`TYPEGET` :61-63, `GateClass` :117, `LogFault` :124, the `ClusteredSystem` seam :133, `Invoke` :190, `Rows` :238, `Admit` :258, `Deny`/`Fail` :676-708). Shell sibling: `Kernel/Shell/SystemInfo.cls:175` reads `$SYSTEM.Mirror.GetMemberStatus()` for the status bar.
- Read source kind, as `backup` and `config` were added: `Screen/Read.cls:297-318` (`SOURCE<X>`, `<X>PortClass`), `:478` (allowed list), `:684-700` (dispatch), `BannerKey` :1364-1375 (port choice); `Screen/Registry.cls:979` (banner ports), `:1223-1224` (source list and its "eighteen sources" message), `:1338-1360` (per-kind shape). Client twin: `ui/tools/screen-mirror.mjs:1047-1049`, `:1204-1217` (endpoints parsed from the port's `ENDPOINTS`), `:1665-1680`, `:2075` and `:4010` (banner ports).
- Descriptor model: `Screen/Descriptor/BackupHistoryList.cls` (read-only list: `entityType` "", id kind `none`, no actions, generic list page) and `BackupTaskList.cls` (`banner` block, `ownPrivileges` `%DB_IRISSYS:WRITE`). `Screen/Registry.cls:927` banner severities `info,warning,restrained`.
- Kernel: `Kernel/Proposal/Prohibited.cls` -- `TYPE<X>` parameters, `COVEREDTYPES` :282, `Codes()` :1083, `ReasonFor` :1090, `Prohibits` :1460 (the uncovered check :1472, the type chain :1475, the reads-no-target arms from :1480, e.g. `ScreenPermission`). Both callers reach it through `Kernel/Proposal/Operation.cls` `Gate` :398 (`Kernel/Proposal/Confirm.cls:299`, `Api/ScreenAction.cls:407`). `Kernel/EntityType.cls` `TYPES` (no `IDRULES` row keeps an id exactly).
- Kernel tests: `Test/Prohibited.cls` (`Seed` :95, `Confirm` :121, `TestAnUncoveredEntityTypeIsRefusedWholesale` :219 with the covered-types literal, `TestAScreenPermissionOnOneOfOcuPilotsOwnScreensIsRefused` :745, the code count 38 at :768). `Kernel/Shell/Guardrails.cls:59-63` lists every code with its sentence. `ui/tools/self-protection.test.mjs:269` `KERNEL_REFUSALS` (code, `strings.ts` key, EXPERIENCE.md Fixed strings).
- Register: `docs/exclusion-register.md` (groups under `## The register`), `ui/tools/exclusion-register.test.mjs` (register == catalog P4 rows; groups == the extract's Stage 5 groups by position, headed with Story 22.1's wording, `epics.md:9388`). Catalog `_bmad-output/planning-artifacts/research/technical-ocupilot-portal-feature-landscape-2026-09-08/feature-catalog.md:351-355,390` (SA-45..SA-49, SO-17, all P3 and L) and its summary table :21-32. Extract `_bmad-output/planning-artifacts/prds/prd-OcuPilot-2026-09-08/extract-stages.md` (Stage 4 :367-, its SA and SO tables :438-482, :819-820, :863-871; Stage 5 :646-660, :756, :920; totals in section 1).
- Gate seam and roster: `Test/PortGate.cls:29` (`ROSTER`), `:338-352` (`BackupGateSeam`). Test model: `Test/BackupRead.cls`.

## Tasks & Acceptance

**Behavior** (on `ocupilot-ci`, through the OcuPilot API; extends the intent's matrix):

| Scenario | State | Expected |
|---|---|---|
| Not a member, unlicensed | `IsMember()` 0, `NoMirror()` 1 (read live) | `State` `Unlicensed`; Members zero rows, no vendor query; banner `mirrorUnlicensedBanner`; empty text `mirrorMonitorEmpty` |
| Not a member, licensed | seam: `IsMember()` 0, `NoMirror()` 0 | `State` `NotMember`; zero rows; banner `mirrorNotMemberBanner` |
| Failover or async member | seam: `IsMember()` 1 or 2, three rows | `State` `Failover` or `Async`; rows carry the five fields; no banner |
| Capped read | seam rows above the cap | rows cut to the cap, truncation reported (AD-36) |
| Gate | caller lacks a port pair | 403 `AUTH.NOPRIVILEGE` naming it; no vendor call |
| Removal with databases | `mirror` target, payload `DeleteDB` or `DeleteDBs` true, either caller | 403 `PROHIBITED.MIRRORDATABASES`, its sentence; nothing reaches a port |
| Any other mirror write | `mirror` target, flag absent or false, or an unparseable payload | 403 `PROHIBITED.UNCOVERED` |

**Execution, batch 1 (server; commit when its loop commands are green):**

- Task 0, on `ocupilot-ci`, recorded under Design Notes before code: `NormalizePage("%CSP.UI.Portal.Mirror.Monitor")` and any custom resource on that page (AD-44); a principal holding only `%Admin_Operate:USE` and `%DB_IRISSYS:READ` reads `State` and `Members` through the port without a refusal, and one lacking `%DB_IRISSYS:READ` is refused by the port's gate (AD-29's least-privileged run; create and delete the principal in the same probe).
- `src/OcuPilot/Port/MirrorPort.cls` -- new, on `BackupPort`'s shape. `PAIRS` `%Admin_Operate:USE,%DB_IRISSYS:READ`; `ENDPOINTS` `Members`; `STATEENDPOINT` `State`. `Invoke`: `Members`/`LIST` and `State`/`GET` only (anything else refused as `BackupPort` refuses an unknown type); `Rows` for the executor. `State` answers `{State, MirrorName}`. `Members` answers zero rows without calling the vendor when `IsMember()` is 0 (the vendor refuses #2074 there, measured), else `SYS.Mirror:MemberStatusList("")` rows of the five fields, read to the cap plus one. `$NAMESPACE` switched to `%SYS` by save and restore (AD-16). Seams: `GateClass`, `LogFault`, `Membership(Output pMember, Output pNoMirror)` and `MemberRows(pMax, Output pRows)`.
- `src/OcuPilot/Screen/Descriptor/MirrorMonitor.cls` -- new. Route `os-management/mirror-monitor`, archetype `list`, the next free OS management position (33 after Story 21.4's 29-32), `refreshes` false, `privileges` `%Admin_Operate:USE`, `%DB_IRISSYS:READ`, `%DB_IRISSYS:WRITE`, `ownPrivileges` `%DB_IRISSYS:WRITE`, `entityType` "", id kind `none`, no actions, `classicPage` from Task 0. Read `{"port": "mirror", "endpoint": "Members", "type": "LIST"}`, fields and context the five, filter `MemberName`, `CurrentRole`, `CurrentStatus`, sort `MemberName` asc, paging `cap`. Banner `{"port": "mirror", "endpoint": "State", "type": "GET"}` on field `State`, cases `NotMember` and `Unlicensed`, severity `info`. `toolIdentifier` `osmgmt.mirrormonitor`. Strings under Design Notes.
- `src/OcuPilot/Screen/Read.cls`, `src/OcuPilot/Screen/Registry.cls` -- add-only: `SOURCEMIRROR` `mirror` and `MirrorPortClass()` seam; the source in both allowed lists and the registry's message; the `LIST`-only shape check against `MirrorPort.ENDPOINTS`; `mirror` as a banner port in `BannerProblem` and `BannerKey`.
- `src/OcuPilot/Kernel/EntityType.cls` -- add `mirror` (one mirror of the instance, keyed by its name, kept exactly, no `IDRULES` row).
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` -- `TYPEMIRROR` covered; `MIRRORDATABASES` with `MIRRORDATABASESREASON`, appended to `Codes()` (thirty-nine) and answered in `ReasonFor` as `If pCode = ..#MIRRORDATABASES Quit ..#MIRRORDATABASESREASON`; a `mirror` arm among the reads-no-target arms, before any port read: payload `DeleteDB` or `DeleteDBs` true refuses `MIRRORDATABASES`, everything else `UNCOVERED`; the doc comments that count codes and types updated.
- `src/OcuPilot/Screen/Titles.cls` -- regenerated.
- `src/OcuPilot/Test/MirrorPortFixture.cls` (new, not a test case: arms membership, license and rows through a process-private global) and `src/OcuPilot/Test/MirrorRead.cls` (new, live-safe) -- every Behavior row from "Not a member, unlicensed" to "Gate": the live state read against the instance's own `IsMember()` and `NoMirror()`, the screen read and `osmgmt.mirrormonitor.read` agreeing, the fixture rows, the cut, the gate refusals.
- `src/OcuPilot/Test/Prohibited.cls` -- one method for the last two Behavior rows: the predicate matrix, `Operation.Gate` with `Api.ScreenAction.ProhibitedClassName()`, and a seeded `mirror` proposal refused at confirm with no port write (`Seed`, `Confirm`, `ProposalFixture.WriteCount`); the covered-types literal and the code count.
- `src/OcuPilot/Test/PortGate.cls` -- `OcuPilot.Port.MirrorPort=PAIRS` and a seam row on `BackupGateSeam`'s model.
- The shared-surface tests under Verification, each to its new shape.

**Execution, batch 2 (client):**

- `ui/tools/screen-mirror.mjs` and `ui/tools/screen-mirror.test.mjs` -- the `mirror` source (endpoints from `MirrorPort.ENDPOINTS`, `LIST` only) and banner port, with a case each; `ui/src/app/core/screens.generated.ts` regenerated.
- `ui/src/app/core/strings.ts`, `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` -- the ruled strings into Fixed strings, and the screen into OS management's side-bar row; `ui/tools/self-protection.test.mjs` -- `['MIRRORDATABASES', 'mirrorRefusalDatabases']` in `KERNEL_REFUSALS`.
- `ui/browser/mirror-monitor.browser-spec.mjs` -- new: after the answered signal the screen shows no rows, the empty text, and the banner the live state selects.

**Execution, batch 3 (planning and docs):**

- `docs/exclusion-register.md` -- add-only: a `### License-gated mirroring` group after the sharding group with six rows (Design Notes), and one new paragraph after the slot B sentence naming the slot A reading.
- `_bmad-output/planning-artifacts/research/technical-ocupilot-portal-feature-landscape-2026-09-08/feature-catalog.md` -- SA-45..SA-49 and SO-17 to P4 with the reason in Evidence; the summary table recomputed.
- `_bmad-output/planning-artifacts/prds/prd-OcuPilot-2026-09-08/extract-stages.md` -- the six rows leave Stage 4 for a new Stage 5 group `**License-gated (mirroring)** — 6 rows`, second, with the same row grammar; every total that counted them recomputed from the rows (grep each ID and each count); Stage 4's prose names only the mirror monitor; Stage 5's group list and gate line (:756) name the mirroring license.
- `_bmad-output/planning-artifacts/epics.md:9388` -- Story 22.1's group list gains "license-gated mirroring;" second, if the spec gate rules it (Design Notes, escalated).

**Acceptance Criteria:**

- AC1. Given `ocupilot-ci`, when the Mirror monitor's read, its read tool and its screen in a browser run, then they show the instance's state as `IsMember()` and `NoMirror()` read live: on Community, no rows, the empty text and the unlicensed banner.
- AC2. Given the port fixture's failover, async and licensed-non-member states, when `Members` and `State` are read, then each answers its Behavior row, and a read past the cap reports truncation.
- AC3. Given a caller missing `%Admin_Operate:USE` or `%DB_IRISSYS:READ`, when it reads either endpoint, then 403 `AUTH.NOPRIVILEGE` names the pair before any vendor call; a holder of OS management's pairs without `%DB_IRISSYS:WRITE` sees the screen unavailable naming it.
- AC4. Given a `mirror` target whose payload sets `DeleteDB` or `DeleteDBs`, when the agent's confirm or the screen action's gate asks the set, then it is refused 403 `PROHIBITED.MIRRORDATABASES` with its sentence and nothing is written; any other `mirror` write is refused `PROHIBITED.UNCOVERED`; Guardrails lists the new code.
- AC5. Given the register, catalog and extract, when `exclusion-register.test.mjs` runs, then SA-45..SA-49 and SO-17 each have a row in the license-gated mirroring group whose gate names the mirroring license.

### Review Findings

Code review 2026-11-15, full-opus, four layers. 0 decision-needed, 8 patch (applied), 5 defer (ledgered), 15 rejected.

- [x] [Review][Patch] `State.MirrorName` was always empty on an async member (the vendor `MirrorName()` answers only on a failover member) and no test reached the member branch -- `MirrorNames` seam, `GetMirrorNames()` off a failover member, fixture arms a name, armed test asserts it [src/OcuPilot/Port/MirrorPort.cls]
- [x] [Review][Patch] `MemberRows` ignored a failed fetch (`Next()` without status) and closed its result set only after leaving `%SYS` -- `Next(.tSC)` and an explicit close in `%SYS` [src/OcuPilot/Port/MirrorPort.cls]
- [x] [Review][Patch] The vendor-query test's "answers no rows" could not fail -- it now asserts the query ran and refused [src/OcuPilot/Test/MirrorRead.cls]
- [x] [Review][Patch] The fixture's two latency values were identical, so a column swap stayed green -- `DatabaseLatency` now `Behind N` [src/OcuPilot/Test/MirrorPortFixture.cls]
- [x] [Review][Patch] `MirrorRefusal` called `DeleteDBs` a database list; both vendor flags are booleans -- method and doc reworded [src/OcuPilot/Test/MirrorRefusal.cls]
- [x] [Review][Patch] `RefusalCopy`'s names-no-caller roster lacked `MIRRORDATABASES` [src/OcuPilot/Test/RefusalCopy.cls]
- [x] [Review][Patch] The six re-tiered catalog rows kept Co-pilot tool `write-confirm`, where every other P4 row reads `none` [feature-catalog.md:351-355,390]
- [x] [Review][Patch] SA-22's note said every other mirror page is Stage 5, but SA-43, SA-44 and SO-15 are Stage 4 [extract-stages.md:130]
- [x] [Review][Defer] SA-43 and SA-44 have no story after U-39 [extract-stages.md:462-463] -- deferred: DW-2620, decision-pending (owner)
- [x] [Review][Defer] An async member tracking several mirrors may list one mirror's members (inference) [src/OcuPilot/Port/MirrorPort.cls] -- deferred: DW-2621, decision-pending, human=measure on a licensed async member
- [x] [Review][Defer] Twelfth port copy of `Deny`/`Refuse`/`Fail` (Rule 31, low) -- deferred: DW-2622 wontfix-accepted
- [x] [Review][Defer] Twelfth per-source block in `Registry.ReadProblem` (Rule 31, low; spec held the file add-only) -- deferred: DW-2623 wontfix-accepted
- [x] [Review][Defer] `Prohibits`' doc says an empty diff prohibits nothing; the mirror and screen-permission arms ignore the diff (contended file) -- deferred: DW-2624 wontfix-accepted

**Rejected:**

- false: `Invoke` checks the body before `Serves` -- the documented contract (500 for a body) and `BackupPort`'s order.
- false: `{"DeleteDBs":["DB1"]}` should be `MIRRORDATABASES` -- both vendor flags are `%Boolean` (`SYS/Mirror.cls:1178,1195`), an array is not true, and the spec sends anything not true to `UNCOVERED`; both codes refuse (AD-10 holds).
- false: `prd.md` keeps "removing a mirror together with its databases" -- AD-10's own heading uses those words.
- false: register intro and gate cells contradict -- the cells are owner-ruled strings (U-53) and the spec required an add-only paragraph.
- low: text flags such as `"2"` read `UNCOVERED` while ObjectScript reads them true -- both refuse; real only when a mirror write is built, which replaces the arm.
- low: membership could change between `IsMember()` and the query -- a 500 on a transient, not reachable here.
- low: the registry accepts a mirror banner endpoint the port does not serve, and has no `%DB_IRISSYS:READ` rule for `mirror` -- same as `backup` and `config`; the descriptor is pinned by `MirrorRead`.
- low: the read tool cannot tell unlicensed from not-a-member -- zero rows answers the membership prompt; the tool's shape is shared by every screen.
- low: the tool leg of AC1 compares two empty counts -- the mirror branch of `Read.Execute` is pinned by the fixture tests; the tool path is shared.
- low: `MirrorRead` switches to `%SYS` around `%OpenId` without a try -- a compiled-query open does not throw in practice.
- low: `MirrorGate.Steps` would error on a fault with no detail -- the test still goes red.
- low: the register's gate check names only `NoMirror()` and not membership or the mirror service -- owner-ruled cells (U-53).
- low: Story 22.1's "56 excluded rows" and Epic 21's "165 rows" are stale -- already DW-2619.
- low: the spec's intent block still reads "Not planned" -- the fix edits the spec under review, whose intent is frozen.
- low: QA's note that `MirrorName` was asserted -- superseded by the first patch above.

## Spec Change Log

## Review Triage Log

### 2026-11-15 — Review pass

- verdicts: 12 findings — high 0, medium 1, low 3, false 8, maybe-false 0
- findings:
  - `[medium]` `[patch]` The real `MemberRows`, the five-field list against the vendor query's row specification and `State.MirrorName` ran in no test (the fixture replaced them) — patched: `MirrorRead.TestTheVendorQueryCarriesTheFieldsAndTheReadRestoresTheNamespace` and a `MirrorName` assertion; both mutations seen red and reverted.
  - `[low]` `[patch]` AC5's "gate names the mirroring license" had no assertion — patched: `exclusion-register.test.mjs` pins the group's six rows, the license wording and the `NoMirror()` check; the SO-17 gate reworded -> red, reverted.
  - `[low]` `[reject]` `TestTheLiveStateIsTheInstancesOwn` compares two empty row counts on a non-member — the `FieldsJson` comparison beside it observes the tool and the state assertion observes the screen; no fix worth its guard.
  - `[low]` `[reject]` The browser spec's member branch waits for an empty banner at once — the branch cannot run on Community, and the banner is asserted after the rows are drawn.
  - `[false]` `[reject]` The `MirrorRead` doc comment names a different AC3 mutation than the spec — both are valid, and the spec's line is the recorded one.
  - `[false]` `[reject]` Refusal exercised through the predicate, the gate and a seeded confirm, not a real mirror-removal producer — no mirror write is built by the owner's answer U-39; both callers' paths are covered.
  - `[false]` `[reject]` No mirrored-database rows in the monitor — the named limit in Design Notes, ruled with the story.
  - `[false]` `[reject]` `%DB_IRISSYS:WRITE` as the screen's own pair on a read-only screen — ruled stricter pair (veto U-53).
  - `[false]` `[reject]` AD-22 and AD-29 constraints met vacuously — no mirror write exists; the refusal is the kernel half.
  - `[false]` `[reject]` Wider PRD, catalog and EXPERIENCE.md edits — ruled at the spec gate (U-52), forced by the register test.
  - `[false]` `[reject]` Vendor query never runs on a member in any test — no runtime here can be one; the fixture holds the row shape, and the new test pins the query's columns.
  - `[false]` `[reject]` Epics narrowing only in Epic 22's line — Story 21.12's own criteria already carry the narrowing.

## Design Notes

**Governing ADs:** AD-10 (the arm and its home), AD-29 (`MirrorPort`'s gate, the least-privileged run), AD-36 (bounded read, one read for screen and tool), AD-5, AD-44 (descriptor, classic page), AD-8 (pairs, stricter allowed), AD-16, AD-34 and AD-53 (the predicate inside each caller's transition, one predicate for both), AD-39 (the sentence), AD-43 (no refresh), AD-23 (no harvest, below), AD-22 (no write key added), AD-13 (`mirror` ids exact).

**Refusal code, named for the spec gate:** `PROHIBITED.MIRRORDATABASES`. With no mirror write tool built, it is reached the way every AD-10 arm is: a predicate in `Prohibited.Prohibits`, which both callers ask through `Operation.Gate` against the stored write. A `mirror` target is judged by its payload alone (as `ScreenPermission` judges by id), so no target read is needed. Because no mirroring write is reviewed, every other `mirror` write answers `UNCOVERED`, failing closed; a story that builds one replaces that answer with its reviewed fields. No built type reaches the effect: no reviewed field list names a database's mirror membership (checked: the mirror-named fields are a superserver's `EnableMirror`, a task's `MirrorStatus` and an ECP server's `MirrorConnection`).

**Measured on slot A (`ocupilot`, read-only, 2026-11-15):** `NoMirror()` 1, `IsMember()` 0, `GetMemberType()` "Not Member", `GetMemberStatus()` "Not initialized", `MirrorName()` empty, `Config.Mirrors.NumberOfMirrorSet()` 0; `SYS.Mirror:MemberStatusList` refuses "ERROR #2074: This system has not been configured as a Mirror Member"; `MirroredDatabaseList` answers no rows; `NormalizePage` answers `%CSP.UI.Portal.Mirror.Monitor` as spelled. `ocupilot-ci` runs the same image (inference); the tests read the state live and assume none.

**Decided in-stage:**

- No harvest of `ExecuteMCPv2.REST.Monitor:MirrorStatus` (Rule 31, a copy reads better, as at 21.3): it answers five `%SYSTEM.Mirror` accessors the port calls itself, reads neither the license nor the member list, and its not-member branch fixes English text the product would not show; harvesting it would give `Port/Harvest/Monitor` a second caller, which `check-objectscript.py:754`'s one-caller roster does not express. `SystemInfo`'s one accessor call is not shared: the port must not depend on shell chrome.
- Pairs follow the classic System Operation menu, which disables the monitor without `%DB_IRISSYS` WRITE (`Application.cls:346`), as Story 21.2 ruled for Backup: stricter than the page's own `%Admin_Operate`, never looser.
- `refreshes` false (smaller; the classic page refreshes on a timer). The rows come only from a member, so no runtime here shows them; the fixture holds their shape.
- SO-17 is one catalog row for the member and the database actions, so it is one register row.
- Register rows, Gate kind `license` each, the dated check `$System.License.NoMirror()` returns 0, cited at `MIRRORMGR.int`, lines 54 to 56, "Slot A read 1 on 2026-11-15." Gates: SA-45 Create a mirror: the instance holds a license that allows mirroring. SA-46 Edit a mirror's failover members and SA-47 Edit an async member: that license, and the instance is a failover (`IsMember()` 1) or async (`IsMember()` 2) member. SA-48 and SA-49 Join a mirror as a failover or an async member: that license on this instance and on the instance whose mirror it joins. SO-17 Mirror member and database actions: that license, and the instance is a member. Reason cell: "Needs a license that allows mirroring, which Community Edition lacks."; for joins, "... and a second instance that runs the mirror."

**Escalated for the spec gate (veto window, unattended):**

- **Strings.** Title "Mirror monitor". Empty "No mirror members to show." Banners "This instance is not a mirror member." and "This instance is not a mirror member, and its license does not allow mirroring." Columns "Role", "Journal transfer latency", "Dejournal latency" (reusing "Name", "Status"). Prompts "Is this instance a mirror member?" · "Which members does this mirror have, and what role does each play?" · "Is any mirror member behind on journal transfer or dejournaling?". Aliases "mirror monitor", "mirroring", "mirror status". `MIRRORDATABASESREASON`: "Removing a mirror together with taking its databases out of mirroring is not available here." The register rows' cells above are public text in `docs/`.
- **Stricter pairs:** the screen's own `%DB_IRISSYS:WRITE` (above).
- **Planning-document edits** the register test forces (`register == catalog P4`, `groups == extract Stage 5 by position, under Story 22.1's wording`): the catalog re-tier, the extract's Stage 4 to Stage 5 move with its totals, and `epics.md:9388`, Story 22.1's AC line, a done epic's block. All follow from U-39. If the gate declines the 22.1 line, the fallback is the six rows under `### License-gated sharding` and the extract's sharding group, with no new group; the test passes, and the heading then misnames them.
- **Named limit:** no mirrored-database table (SO-16's database half). `MirroredDatabaseList` answers no rows here; a second screen would add a descriptor and its strings for rows no runtime shows.
- **Proposed spine text (Rule 20, for the runner):** AD-10's mirror paragraph, replace "its code is named at Story 21.2's spec gate" with "refused `PROHIBITED.MIRRORDATABASES` (Story 21.12), judged by the payload on a `mirror` target, which reads no target; every other `mirror` write is refused `PROHIBITED.UNCOVERED` until a story builds it". AD-29's Binds gains `MirrorPort` (beside DW-2559's `ConfigPort`).

**Noted for the runner:** SA-43 (add databases to a mirror) and SA-44 (mirror database properties) are mirroring writes outside this story's criteria; whichever story holds them meets the same license gate (inference).

**Extend, don't copy (Rule 2/31):** `MirrorPort` follows `BackupPort`; `MirrorMonitor` follows `BackupHistoryList` with `BackupTaskList`'s banner; the arm follows `ScreenPermission`'s reads-no-target branch; the tests follow `BackupRead` and `Prohibited`'s `Seed`/`Confirm`.

**Integration ACs:** `MirrorPort` is consumed in this story by the descriptor's read, through the screen read route and `osmgmt.mirrormonitor.read` (AC1). **Consumed-by:** none planned; a register row's pick-up (Story 22.2's procedure) would be the first. **Consumes:** `Screen.Gate`, `Screen.Read`, `Kernel.Fault`, `Kernel.Proposal.Operation`.

**Ledger inbox:** none. **Contended paths:** `origin/OCU-1-epic24` has changed none of the files named here (checked 2026-11-15); Epic 22 is done. Shared registration files take add-only rows.

**Task 0, measured on `ocupilot-ci` (2026-11-15):**

- `NormalizePage("%CSP.UI.Portal.Mirror.Monitor")` answers `%CSP.UI.Portal.Mirror.Monitor`, with or without the URL form; that is the descriptor's `classicPage`. `IsMember()` 0, `NoMirror()` 1, `MirrorName()` empty.
- Through the screen route, a principal holding `%Admin_Operate:USE` and `%DB_IRISSYS:READ` only is refused 403 `AUTH.NOPRIVILEGE` naming `%DB_IRISSYS:WRITE` (the screen's own pair), and a principal holding those and `%DB_IRISSYS:WRITE` reads 200 with the unlicensed banner and no rows. The screen route needs all three pairs, so the port ran under the three, never under the two; that the vendor calls need no more than the port's two pairs is an inference (`IsMember()`, `NoMirror()` and `MirrorName()` are accessors, and the member query is not run on a non-member). Both principals and their roles were created and deleted in the same probe.

**Decided in-stage:**

- `MirrorPort` copies `BackupPort`'s `Deny`, `Refuse` and `Fail` (private there, three short methods): a shared base would couple a read-only port to a write port's `Admit`.
- The mirror read has no read label: the screen has no confusable sibling, and `ReadDescriptions` requires a label only for a confusable group.
- The Role column reuses `userRoleField` ("Role"): `strings.ts` holds one key per value. "Role" is therefore not added to Fixed strings, whose row names it as reused.
- `RowFor` shapes a member row from the vendor's column values, so the fixture's rows pass through the builder the instance's rows do.
- `exclusion-register.test.mjs` read "slot B read" for every license, edition and platform gate; it reads "slot A or slot B" now, since the mirroring rows were read on slot A (`ocupilot`, read only).
- Counts and the catalog Co-pilot tool column: the six catalog rows keep `write-confirm`; the extract's Stage 5 rows carry the grammar of the existing group. Totals recomputed from rows: Stage 4 159 rows, S 60 / M 79 / L 20, custom endpoints 152; Stage 5 62 rows, S 11 / M 29 / L 22, custom endpoints 38; catalog P3 158, P4 62; all five stages unchanged at 357, 118 / 179 / 60, 202.
- Left unchanged for the runner: `epics.md` counts that still read the old totals ("Epic 21's 165 rows", "the 56 excluded rows" in Story 22.1, "Stages 2-6" custom endpoints 167), the research summaries ("56 rows"), and `reconcile-catalog.md`.

**Runner and orchestrator rulings at the spec gate (2026-11-15):**

- Strings and the screen's own `%DB_IRISSYS:WRITE` pair: kept as planned (veto U-53).
- Register group (orchestrator ruling U-52, option A): create the 'License-gated mirroring' group; move catalog rows SA-45..SA-49 and SO-17 from P3 to P4, the extract's rows from Stage 4 to Stage 5 with its totals re-derived; add 'license-gated mirroring' to Story 22.1's acceptance line in `epics.md` (add-only, Rule 5 consequence of U-39). Epic 24 also adds register rows (U-45): a conflict there is a union, totals re-derived from the merged rows.
- AD-10's pointer now names `PROHIBITED.MIRRORDATABASES` at this story (done by the runner in the spine, citing owner answer U-39 and ruling U-52). The `MirrorPort` addition to AD-29's Binds stays a proposal beside DW-2559.

## Verification

**Shared surfaces:** OS management's screen roster, positions and visible or unavailable sets (`Navigation`, `WireSecurityRead`, `WireAreaAnyScreen`, `LanguageServerWire`, `ui/browser/language-servers.browser-spec.mjs`, `ui/tools/navigation.test.mjs`, `Descriptor`, `StageTwoTools`, `ui/tools/screen-mirror.test.mjs`), the read-tool roster (`ReadTool`, `ReadDescriptions`, `ToolDispatch`, `ToolEmit`, `SurfaceCoverage`), the read source kinds and banner ports (`screen-mirror.test.mjs`, `BannerCorpus`, `AdminPairCorpus`, `DocDbDescriptor`, `InteropDescriptor`, `MetricsDescriptor`, `SqlActivityDescriptor`), entity types (`Descriptor`, `EntityRef`, `Prohibited`'s covered-types literal), the prohibited codes (`Prohibited`'s count, `GuardrailsWire`, `ui/browser/guardrails.browser-spec.mjs`, `self-protection.test.mjs`), `PortGate`, `ClassicPageGate`, `MappingDescriptor`, `TeardownGuard` (only if a new class tears down shared state), and the register (`exclusion-register.test.mjs`). The implement stage greps `ui/browser`, `ui/tools`, the `ui/src` specs and `src/OcuPilot/Test` for each; every test it changes joins `(loop)`.
*Every test added or changed passes on a fresh environment, in either order.*

**Commands.** One per foreground call, `timeout: 600000`, against `ocupilot-ci` only, never two test calls in one message.

- `(loop)` `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/b708a79b-b765-42ec-adea-dbc87acf6251/scratchpad/e21u/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` -- expected: `LOADERRORS=0`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.MirrorRead`, one class per call, then each of `Prohibited`, `PortGate`, and every shared-surface class above -- expected: green.
- `(loop)` `uv run scripts/check-objectscript.py`, `uv run scripts/test_check_objectscript.py`, `bash scripts/lint-docs.sh` -- expected: clean.
- `(loop)` `cd ui && node --test tools/exclusion-register.test.mjs tools/self-protection.test.mjs tools/screen-mirror.test.mjs tools/navigation.test.mjs` -- expected: green.
- `(loop)` `cd ui && npm run build`, `npm run test:components`, `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/mirror-monitor.browser-spec.mjs browser/language-servers.browser-spec.mjs browser/guardrails.browser-spec.mjs` -- expected: green.
- `(once)` `cd ui && npm run test:tools` -- expected: green.
- `(once)`, runner-owned: the full ObjectScript sweep one class per call, `smoke.sh --container ocupilot-ci`, Rule 30's fresh check. The full browser suite is left to CI.

**Mutations (Rule 19), one per AC, each applied, observed red, reverted (tree identical by `git status --short` and `git diff --stat`), reverted source reloaded:**

- AC1: `MirrorPort` answers `NotMember` whatever `NoMirror()` reads -> `MirrorRead` red; the descriptor's `Unlicensed` case removed -> `mirror-monitor.browser-spec.mjs` red after rebuild and redeploy.
- AC2: the row builder drops `CurrentStatus` -> `MirrorRead`'s fixture test red.
- AC3: `PAIRS` loses `%DB_IRISSYS:READ` -> `PortGate`'s seam row red.
- AC4: the arm stops reading `DeleteDBs` -> `Prohibited`'s mirror test red; the arm removed -> its code assertions red.
- AC5: the SO-17 row removed from the register -> `exclusion-register.test.mjs` red.

**Mutations run (Rule 19), each applied, observed red, reverted (checksum identical), the reverted source reloaded into `ocupilot-ci`:**

- mutation: AC1, `MirrorPort.State` answers `NotMember` whatever `NoMirror()` reads -> `MirrorRead` red (`TestTheLiveStateIsTheInstancesOwn` and `TestEachArmedStateAnswersItsRowsAndBanner`); the descriptor's `Unlicensed` case removed, mirror and bundle rebuilt and redeployed -> `mirror-monitor.browser-spec.mjs` red.
- mutation: AC2, `FIELDS` renames `CurrentStatus` to `Status` -> `MirrorRead.TestTheVendorQueryCarriesTheFieldsAndTheReadRestoresTheNamespace` red; `MemberRows` drops its namespace restore -> the same method red; `FIELDS` drops `CurrentStatus` -> `MirrorRead.TestEachArmedStateAnswersItsRowsAndBanner` red; `Read.Execute` asks the mirror port for the cap rather than the cap plus one -> `TestARowCountPastTheCapReportsTruncation` red.
- mutation: AC3, `PAIRS` loses `%DB_IRISSYS:READ` -> `PortGate.TestEveryPortEvaluatesItsDeclaredGate` red; the descriptor's `ownPrivileges` emptied -> `MirrorRead.TestTheScreenDeclaresItsPagePairsAndSource` red; `ReadProblem`'s mirror arm admits any endpoint -> `MirrorRead.TestTheMirrorSourceRefusals` red.
- mutation: AC4, `MIRRORDATABASEFIELDS` without `DeleteDBs` -> `Prohibited.TestAMirrorRemovalWithItsDatabasesIsRefusedAndEveryOtherMirrorWriteIsUncovered` red; the `Mirror` call removed from the arm -> the same method red.
- mutation: AC5, the SO-17 row removed from the register -> `exclusion-register.test.mjs` red (the catalog and extract-position tests); the SO-17 gate reworded to a sharding license -> the license-gated mirroring wording test red.

**Verified (loop), on `ocupilot-ci`:** `reload.sh` `LOADERRORS=0`; `MirrorRead` 7, `Prohibited` 16, `PortGate` 4 and the 22 shared-surface classes above green; `check-objectscript.py` 0 problems, `test_check_objectscript.py` 152 OK, `lint-docs.sh` 0 issues; `node --test` over the four files and `npm run test:tools` (2292) green; `npm run build` and `npm run test:components` (3469) green; `mirror-monitor`, `language-servers` and `guardrails` browser specs green on the redeployed bundle.

**QA additions (QA), on `ocupilot-ci`:**

- `src/OcuPilot/Test/MirrorGate.cls` (QA, armed by `OCUPILOT_ALLOW_PRINCIPALS`, roster line added in `scripts/ci-throwaway.sh`), `src/OcuPilot/Test/MirrorProbe.cls` (QA, its principals' fixture) and `src/OcuPilot/Test/MirrorRefusal.cls` (QA, live-safe). The gate class runs `MirrorPort` itself, unfixtured, as a real principal holding only `%Admin_Operate:USE` and `%DB_IRISSYS:READ` (both endpoints read, 200), as ones missing either pair (403 naming it), and reads the screen over HTTP as the two-pair holder (403 naming `%DB_IRISSYS:WRITE`) and the three-pair holder (200, live banner). The refusal class pins the flag spellings, null, empty, array and object values, non-object payloads, and independence from the stored diff and the mirror's name.
- mutation: AC1, `MirrorPort.State` ignores `NoMirror()` -> `MirrorGate` red (two tests).
- mutation: AC2, `RowFor` blanks `CurrentStatus` -> `MirrorRead.TestEachArmedStateAnswersItsRowsAndBanner` red.
- mutation: AC3, `PAIRS` loses `%DB_IRISSYS:READ` -> `MirrorGate.TestEachMissingPortPairIsRefusedByNameOnEveryEndpoint` red; the descriptor's write pair and `ownPrivileges` removed -> `MirrorGate.TestTheScreenNamesItsOwnWritePairToTheTwoPairHolder` red.
- mutation: AC4, the arm's `true` comparison drops its case folding -> `MirrorRefusal.TestEachSpellingOfASetFlagIsRefusedWithItsCodeAndNoOtherIs` red.
- mutation: AC5, the SA-47 row removed from the register -> `exclusion-register.test.mjs` red (three tests).
- Each mutation reverted by restoring the saved source (checksum equal), reloaded into `ocupilot-ci`; `MirrorRead` 8, `Prohibited` 16, `MirrorGate` 3 and `MirrorRefusal` 4 green after; `ci.test.mjs` and `exclusion-register.test.mjs` 120 green; `check-objectscript.py` 0 problems.

**Code review additions, on `ocupilot-ci`:**

- mutation: `State` calls `$System.Mirror.MirrorName()` directly instead of `MirrorNames` -> `MirrorRead.TestEachArmedStateAnswersItsRowsAndBanner` red; `MemberRows` quits OK before the vendor query -> `MirrorRead.TestTheVendorQueryCarriesTheFieldsAndTheReadRestoresTheNamespace` red; `ReasonFor` answers a literal naming the agent for `MIRRORDATABASES` -> `RefusalCopy.TestEachKernelRefusalIsItsParameterAndNamesNoCaller` red. Each reverted (checksum equal) and reloaded.
- After: `LOADERRORS=0`; `MirrorRead` 8, `MirrorRefusal` 4, `RefusalCopy` 8, `PortGate` 4, `MirrorGate` 3, `Prohibited` 16 green; `check-objectscript.py` 0, `lint-docs.sh` 0, `npm run test:tools` 2293 green.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** Mirror monitor (`MirrorPort`, `MirrorMonitor` at OS management position 33, `mirror` read source and banner port) and the kernel refusal `PROHIBITED.MIRRORDATABASES` (`mirror` entity type, payload-only arm; every other mirror write `UNCOVERED`), per owner answer U-39. Register: six license-gated mirroring rows; catalog SA-45..SA-49 and SO-17 to P4; extract Stage 4 to Stage 5 with totals re-derived; Story 22.1's line gains "license-gated mirroring". Client strings, EXPERIENCE.md, generated screens and 20 shared-surface tests updated; new `MirrorRead`, fixtures, `Prohibited` method and `mirror-monitor.browser-spec.mjs`.

**Review.** 12 findings: 1 medium and 1 low patched (real-query columns, namespace restore and `MirrorName` test; register wording test), 2 lows and 8 false rejected with reasons in the triage log, none deferred. Follow-up review recommended: false (one medium patched).

**Verification.** `(loop)` on `ocupilot-ci`: `LOADERRORS=0`; `MirrorRead` 8, `Prohibited`, `PortGate` and the shared-surface classes green; `check-objectscript.py` 0 problems; `lint-docs.sh` 0; `exclusion-register.test.mjs` 17 green; `npm run test:tools`, `npm run build`, `npm run test:components` and the three browser specs green before the patch. The review patch re-ran `MirrorRead` and the register test only.

**Residual risks.** The port's query on a real mirror member and the least-privileged probe through the port alone are not runnable here (inference, noted in Design Notes). Left to the runner: the full ObjectScript sweep, the AD-29 Binds proposal beside DW-2559, and the stale "56 excluded rows" and "165 rows" wording in `epics.md` and the research summaries.
