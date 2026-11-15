---
title: 'Story 21.12: Mirroring'
type: 'feature'
created: '2026-11-14'
status: 'draft'
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

- `irissys/SYS/Mirror.cls:653` (`CreateNewMirrorSet`), `:697` (`JoinMirrorAsFailoverMember`), `:743` (`JoinMirrorAsAsyncMember`), `:399/:410` (`StartMirror`/`StopMirror`), `:917-999` (promote family), `:937/:942` (demote), `:1273/:1287` (no-failover), `:224/:236` (database activate/remove), `:466/:523/:568` (monitor queries), `:1178/:1195` (the two removals). Bodies are object code only.
- `irissys/SYS/Mirror.cls:1166-1177` and `:1185-1189`: `DeleteDB`/`DeleteDBs` "removes the 'mirror' attribute of all mirrored databases ... and leave[s] the databases in the configuration". The classic dialogs label the flag "Remove mirror attribute?" (`irissys/%CSP/UI/Portal/Mirror/Dialog/FailoverRemoveConfig.cls:79`, `AsyncRemoveConfig.cls:67`, `RemoveLocalConfig.cls:68`), and `RemoveLocalConfig.cls:82` says "the databases themselves are not deleted".
- `MIRRORMGR.int:53-55` (`%SYS`, read on slot A): `if $System.License.NoMirror() { ... "Mirroring not started, license does not allow Mirroring." ... goto dmnexit }`.
- `MIRROR.int:51-62` (`%SYS`): the create and join menu entries appear only when `SYS.MirrorConfiguration.EnableMirrorMenu(n)` is true.
- Classic pages: `%CSP.UI.Portal.Mirror.Create` (`RESOURCE` `%Admin_Manage`, `Create.cls:13`), `Monitor` (`%Admin_Operate`, `Monitor.cls:22`, with an `%Admin_Manage:USE` check at `:946`), `EditFailover`, `EditAsync`, `JoinFailover`, `JoinAsync` and eleven dialogs under `Mirror/Dialog/`.
- Harvest source `iris-execute-mcp-v2` at `c6aad31`: only `REST/Monitor.cls:413` `MirrorStatus` (a read). No mirroring write body exists to harvest, so every write would be port-authored, like 21.2's freeze.
- Catalog (`research/technical-ocupilot-portal-feature-landscape-2026-09-08/feature-catalog.md:351-355,389-390`): SA-45 create, SA-46 edit mirror, SA-47 edit async, SA-48 join failover, SA-49 join async, SO-16 monitor, SO-17 member and database actions. All seven rows are sized L. SO-17 alone lists 14 actions.
- Pattern to reuse once ruled: `spec-21-2-backup.md` (a gated port, keys shipped `false`, `GovernanceBaseline`'s `DISABLED`, an armed write class, a fixture seam for an unmeasurable predicate). It is `ready-for-dev`, not implemented, so `BackupPort`, `BackupRules`, `BackupError` and the DW-2560 checker rule are dependencies on 21.2's delivered classes, not code to plan against yet.

## Tasks & Acceptance

None until the owner rules on the two questions in Design Notes.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs:** AD-10 (the mirror-removal arm), AD-22 (keys ship `false`), AD-23 (only `MirrorStatus` exists to harvest), AD-29 (a `MirrorPort` gate), AD-21, AD-36, AD-51 to AD-53, AD-58, AD-6, AD-34, AD-15, AD-14, AD-44.

**Measured on slot A (`ocupilot`, read-only calls, 2026-11-14):**

- `$System.License.NoMirror()` = 1. The license is "InterSystems IRIS Community license". `MIRRORMGR` refuses to start mirroring under it.
- `%Service_Mirror` is disabled. `$$IsMirrorServiceEnabled^MIRRORCTL()` = 0, and `EnableMirrorMenu(1)` to `(7)` all read 0.
- `SYS.Mirror.CheckISCAgent()` answers OK. `$System.Mirror.IsMember()` = 0.
- `ocupilot-ci` and CI's throwaways run the same image, so they carry the same license (inference).

**Question 1: the first criterion cannot be met as worded (`intent gap`).**

| Operation | On `ocupilot-ci` |
|---|---|
| Monitor (SO-16) | Round-trips only in the not-a-member state. Member and database rows can be checked by shape through a fixture seam only. |
| Create (SA-45) | Cannot round-trip. It needs `%Service_Mirror` enabled (a write), and the license stops mirroring from starting. Whether `CreateNewMirrorSet` itself refuses is unmeasured. The vendor will not remove a primary's configuration (`Mirror.cls:1176`), so a create may not be reversible on the throwaway (inference). |
| Edit failover or async (SA-46, SA-47) | Cannot be exercised: it needs a mirror member. |
| Join failover or async (SA-48, SA-49) | Cannot be exercised: it needs a second instance, and the memory rule forbids one. |
| Member actions (SO-17) | Refusal only: start and stop, no-failover, promote, demote and authorize all need a member. |
| Database actions (SO-17) | Refusal only: mount, activate, catch-up, download and remove all need a mirrored database. |
| AD-10 kernel case | Round-trips as a kernel refusal, whatever the license. |

The story is also far past one pass even if it could be tested: seven L rows and about 25 write tools.

Recommended amendment (A), which the owner must rule on because it moves rows across epics:

- 21.12 keeps the monitor (SO-16) and the AD-10 kernel case.
- SA-45 to SA-49 and SO-17 move to Epic 22's license-gated group. Their gate is "a mirroring-licensed instance pair the pipeline can run".
- The amended criterion: "Given the mirror monitor, when it runs, then it round-trips over `SYS.Mirror` and `%SYSTEM.Mirror`, and on an instance whose license does not allow mirroring it says so."

Alternatives:

- (B) Keep every write in 21.12. A `MirrorPort` would refuse each one with `MIRROR.UNLICENSED` before any vendor call while `NoMirror()` is 1, checked only through fixture seams, in three batches or sibling stories. Not recommended: about 25 tools whose vendor calls never run anywhere ("measure, don't guess"; "text claims only what the product does").
- (C) The owner supplies a mirroring license and a second instance. That touches money, accounts and the memory rule, so it is owner-only.

**Question 2: AD-10's arm names an effect the vendor does not have.** AD-10 says "removing a mirror's configuration with its databases deleted (`RemoveMirrorConfiguration` with `DeleteDB`, `RemoveOneMirrorSet` with `DeleteDBs`)". Measured from the vendor source above: those flags take the databases out of mirroring and keep them. No call removes a mirror and deletes its databases.

**Proposed spine edits (need ruling):**

- AD-10, recommended: "Removing a mirror's configuration and taking its databases out of mirroring in the same call (`DeleteDB` / `DeleteDBs` set) is refused `PROHIBITED.MIRRORDATABASES` from either caller. The databases are kept, but making them mirrored again means seeding every member again (inference). The same removal with the flag clear is an ordinary disabled-by-default write." The alternative is to delete the arm, since no data-deleting path exists.
- The pointer "its code is named at Story 21.2's spec gate" becomes Story 21.12's gate, with the code above.
- AD-29 Binds gains `MirrorPort`, whose read pairs follow the classic Monitor (`%Admin_Operate:USE`, plus `%Admin_Manage:USE` for its actions). Any write would take `%Admin_Manage:USE`, from `Create.cls:13`.

**Proposed strings (need ruling):**

- Refusal for `PROHIBITED.MIRRORDATABASES`: "OcuPilot does not take databases out of mirroring while it removes a mirror. Remove the mirror on its own, or use the classic portal."
- Under (A): the title "Mirror monitor" · "This instance is not a mirror member." · "This instance's license does not allow mirroring."

**Decided in-stage:**

- No write was made on any instance, as the dispatch ordered. Enabling `%Service_Mirror` and trying `CreateNewMirrorSet` on `ocupilot-ci` would be Task 0 of a re-plan under (B) or (C) only.

**Integration ACs / Consumed-by / Consumes:** deferred to the re-plan. Under (A) the monitor's consumers would be its descriptor and read tool. It would consume `Screen/Read`, `Screen.Gate` and `Kernel/Proposal/Prohibited`.

**Ledger inbox:** none.

## Verification

**Shared surfaces:** to be named at the re-plan. They are expected to include the governance baseline, `Prohibited`'s codes, the OS management rail and `PortGate`'s roster. *Every test added or changed passes on a fresh environment, in either order.*

**Commands:**

- `(once)` `bash scripts/lint-docs.sh` -- expected: no finding on this spec.

## Auto Run Result

Status: blocked
Blocking condition: intent gap -- (1) AC1 "each runs ... round-trips" cannot be met on any project runtime: `$System.License.NoMirror()` = 1 on the Community image (measured on slot A; the same image is inferred for `ocupilot-ci` and CI), so MIRRORMGR never starts mirroring. Join needs a second instance (forbidden), and edit, member and database actions need a member. Only the monitor (not-a-member state) and the AD-10 kernel refusal can round-trip. Recommended (A): 21.12 keeps SO-16 and the kernel case, and SA-45..49 and SO-17 move to Epic 22's license-gated group (owner-only: epic boundary). (2) AD-10's mirror arm says `DeleteDB`/`DeleteDBs` deletes databases. The vendor source says it only removes the mirror attribute and keeps them. Proposed: refuse that flag as `PROHIBITED.MIRRORDATABASES`, with the sentence in Design Notes, or delete the arm.
