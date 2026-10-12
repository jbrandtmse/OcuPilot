---
title: 'Story 18.43: Uninstall and grants on a shared instance'
type: 'feature'
created: '2026-10-12'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-18-13-multi-namespace-install.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** On an instance OcuPilot does not wholly own, `Uninstall` deletes the shell bundle directory under an application it keeps (DW-219 path 1), carries on past an unreadable provenance record and strips the state surviving applications need (path 2), and deletes a matching role another application still carries (path 3's sibling). Install never notices a grant on its schemas held by another role or `_PUBLIC` (DW-2172).

**Approach:** Uninstall keeps, and reports, what a surviving application still uses, and refuses before removing anything when it cannot read its record. Install reads the instance's privilege catalog beside its grant read-back and warns naming each other grantee.

## Boundaries & Constraints

**Always:** A refusal removes nothing. An object left in place is named in a warn with its remedy. Detection never fails install, refuses or revokes; its read failure is a warn. Code stays in `Install/Installer.cls` and `src/OcuPilot/Test`. A test creates every role, application and grant it asserts on and removes it.

**Never:** Edit `scripts/ci-throwaway.sh`, `Kernel/Proposal/Prohibited.cls` or a client file; add a Fixed string, error code or write key; change `Install`'s refusals (18.13's); keep the admin or identity role; build on a `decision-pending` entry.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Kept shell | shell's provenance row deleted, confirmed uninstall | shell application and bundle directory stay, named in a warn; the preview omits the directory | -- |
| Recorded shell | plain install, confirmed uninstall | application, role, directory removed (unchanged) | -- |
| Unreadable record | provenance read fails, the profile's routine application exists | refused naming the record and remedy; nothing removed | a warn |
| Record's application gone | that application absent (repeat uninstall) | completes, removing no web application (unchanged) | -- |
| Role in use | a non-roster application carries the probe shell's role | role stays, named with that application; a later uninstall without it removes the role | -- |
| Orphaned role | roster application removed by hand | its role removed (path 3, unchanged) | -- |
| Widened grant | a probe role holds SELECT on the schema, `_PUBLIC` on a table | install succeeds; one warn names each grantee, object, privilege and the remedy; grants kept | catalog unreadable: a warn; install succeeds |
| Own grant only | only the escalation role's grant | no warn names the escalation role | -- |

</intent-contract>

## Code Map

Under `src/OcuPilot/` at `59a6d1ca` (`Installer.cls` unchanged since `fe132688`). Story 18.13 lands first and shifts these lines: re-anchor by symbol.

- `Install/Installer.cls` `Uninstall` :3851 (header :3777): guard :3863, lock :3876 (18.13's guard follows it), direct `WebApp.GuardedPathsForProfile` read :3918-3922 (path 2), `%SYS` switch :3924, nothing-exists return :3927, preview :3932-3953, inventory refusal :4014 (the DW-65 precedent), application loop :4049, role loop :4075-4083 (roster path only; :4079 closes path 3), bundle directory :4089-4092 (path 1), left-in-place warn :4162.
- Same class: `ReadApplicationProvenance` :1587 (Install's read; an absent `tNames("application")`, `OcuPilotState` for production, answers an empty set :1590), `EscalationApplicationExists` :1329, `AnyObjectExists` :3747, `Names` (`bundleKey` :257, `shellDirectory` :262), `EnsureSqlPrivileges` :3432 (read-back :3450-3466), `StateTables` :3479. `IDENTITYRESOURCES` is `%Admin_Secure:U,%DB_IRISSYS:R`.
- Grantee source, read on `ocupilot` 2026-10-12: `Security.SQLPrivileges` (`%SYS`; documented `List` query, `irissys/Security/SQLPrivileges.cls` :63) holds the grant as `5,OCUPILOT_KERNEL_STATE`, `d,i,s,u`, grantee `%DB_OCUPILOT`, grantors `_SYSTEM` and `irisowner`, in `HSCUSTOM`, and no other grantee. `INFORMATION_SCHEMA.TABLE_PRIVILEGES` does not exist (SQLCODE -30); 18.9's admin read takes one grantee.
- Tests (lines): `UninstallFault` (74; fault toggles), `UninstallGuard` (305; inventory pair :166, :199), `Provenance` (388; `CleanProbe` :73, `CreateForeignApplication` :81, preview :261), `UninstallResidue` (535; path 3's pin :354, `ShellDirectory` :406), `ProbeApps.Remove` :73, `GrantReadBack` (167), `InstallerProbe.CapturedAllWithData` :172.
- Docs: `docs/DEVELOPMENT.md` :209-217 (grant) and :339-341 (provenance).

## Tasks & Acceptance

**Task 0** (`ocupilot-ci`, after `LOAD-OK` and `STARTPATH-OK`; record S0; halt on a contradiction with this plan).

- (a) Install the probe, delete its shell provenance row, uninstall: record the shell application, whether the directory stays (today: removed), and `GET http://localhost:52776/probeocupilot/`.
- (b) Struck at the spec gate: it would revoke a grant the probe did not create; Task 5's fault seam pins A2.
- (c) Create `/csp/ocuprobe1843` (`%CSP.REST`) carrying the probe shell's role, uninstall: record the role and that application's `MatchRoles` (today: stripped), and the shape, rows and time of one `%SYS` read of every application's `MatchRoles`.
- (d) Role `OcuProbe1843Grantee` granted SELECT on the schema, one table and one column, and `_PUBLIC` SELECT on the schema: record each catalog row's `SQLObject`, `Privilege`, `Grantee`, `Grantor`. A form the catalog does not answer (the column, inference) is a named limit.

- (e) DW-2365 (routed in by Story 18.13's code review): with production installed in HSCUSTOM and IPM imported (as `scripts/ci-ipm-archive.sh` does), a refused `zpm load` from a second namespace, then `zpm list` and `zpm uninstall` there: record what IPM leaves in that namespace and whether the live `/ocupilot`, `/api/ocupilot` and `csp/ocupilot/` survive. If the uninstall deletes them, restore with `StartPath(1,"")` and `docker cp` of the built bundle, then fix it here (an uninstall-phase guard invoke) if it fits, or document the cleanup and defer a MED.

Remove what (a)-(d) created; confirm S0.

**Execution:**

1. `Install/Installer.cls` `Uninstall` (DW-219):
   - Read the record through `..ReadApplicationProvenance(pProfile, .tNames, .tRecorded, .tScratch)`, its reports discarded.
   - After the nothing-exists return, if that read failed: restore the namespace, warn, and return an error naming the record, that nothing was removed, and the remedy (`Install` with no profile, then uninstall again). Before the preview and any removal.
   - New `RolesInUse(ByRef pExcept, Output pRoles)`, in `%SYS`: one read of every application's `MatchRoles` (Task 0 (c)), skipping `pExcept`, answering `pRoles(<ROLE upper-cased>) = <applications>`.
   - Role loop: delete an existing roster role unless `RolesInUse` names it. The admin and identity roles keep their unconditional removal.
   - Bundle directory: removed only when no application sits at `tNames("appName", tNames("bundleKey"))` after the application loop.
   - The left-in-place warn also names each kept role with its applications, and a kept directory, with the remedy.
   - The preview mirrors this: a role is listed only when `RolesInUse` (excepting the recorded roster applications) does not name it, the directory only when the shell application is absent or recorded.
   - Header: one sentence per rule, replacing the sentences they supersede.
2. `Install/Installer.cls`: new `ReportWidenedGrants(pInstallNs, ByRef pTables, ByRef pReports)`, called by `EnsureSqlPrivileges` after its read-back (DW-2172).
   - In one `%SYS` window (AD-16), read `Security.SQLPrivileges:List`; keep rows in `pInstallNs` whose object is one of `pTables`' schemas or tables (Task 0 (d)'s forms, case-insensitive); drop grantee `DBRESOURCE`.
   - One warn lists each `{grantee, object, privileges}` with the remedy: revoke it with SQL or the classic portal (OcuPilot's tools refuse it, `PROHIBITED.OCUPILOTSQLPRIVILEGE`). None when no row remains.
   - A failed read is one warn; it always returns OK; its doc names any form Task 0 found unanswered.
3. `docs/DEVELOPMENT.md`: add one sentence at :216 (the warn and that install never revokes one) and one at :341 (the three uninstall rules). Then run `bash scripts/lint-docs.sh`.
4. `Test/UninstallFault.cls`: add `SetProvenanceReadFails(pFails)` and a `ReadApplicationProvenance` override that fails on demand, else `##super`. `Disarm` clears it.
5. `Test/UninstallGuard.cls`: `TestUninstallRefusesWhenTheProvenanceRecordCannotBeRead`. With the fault armed, `UninstallFault.Uninstall("probe",1)` is refused naming the record and remedy, with a warn; every probe application (`ProbeApps.Existing()`), the database, `IRIS.DAT`, mapping and bundle directory remain.
6. `Test/ProbeApps.cls`: add `ShellDirectory()`, lifted from `UninstallResidue.ShellDirectory`, whose body becomes a delegation to it. `Remove` deletes that directory once no probe shell application remains.
7. `Test/Provenance.cls`: `CreateForeignApplication` gains an optional `pMatchRoles`. Add two tests:
   - `TestUninstallKeepsTheBundleDirectoryOfAKeptShellApplication` (matrix row 1). After `CleanProbe`, the directory is gone.
   - `TestUninstallKeepsAMatchingRoleAnotherApplicationCarries` (row 5). It deletes its foreign application in every exit path.
8. `Test/GrantReadBack.cls`: `TestAWidenedGrantIsNamedAndKept` (rows 7, 8): role `OcuProbe1843Grantee` with SELECT on the schema and `_PUBLIC` on one table (Task 0's forms). Before the grants an `InstallerProbe.Install("probe")` warns of neither; after, install is OK, one warn names both grantees and objects and not `DBRESOURCE`, and `CheckPrivilege` still holds both. New `DropProbeGrants()` revokes both and deletes the role, at the test's end and in `OnAfterOneTest`.
9. **Rule 30 sweep.** The seven classes that pin Uninstall: `Installer`, `UninstallGuard`, `UninstallResidue`, `UninstallSurvival`, `Provenance`, `WebApp`, `InstallLock`; also `GrantReadBack`, `IdentityInstall`, `InstallNamespaceSource` and 18.13's `InstallTarget`. Grep `src/OcuPilot/Test` and `ui/tools` for the preview text, `shellDirectory`, the left-in-place warn and `GuardedPathsForProfile`; edit only if red. `SetInventoryAppAbsent` now also empties the provenance set, so `TestUninstallContinuesWhenTheInventoryIsGone` leaves the probe applications to `OnAfterOneTest` (inference: still green).

**Acceptance Criteria:**

- **A1 (path 1).** Given an application at the shell's roster path that uninstall leaves in place, when uninstall runs, then the bundle directory stays, the warn names it, and the preview does not list it.
- **A2 (path 2).** Given a provenance record that cannot be read while the profile's privileged routine application exists, when uninstall runs, then it is refused and removes nothing. Given that application absent, uninstall completes as today.
- **A3 (path 3).** Given a roster matching role that no surviving application carries, when uninstall runs, then the role is removed. Given one that an application left on the instance carries, then the role stays and is named.
- **A4 (DW-2172).** Given a grant on OcuPilot's schemas held by another role or `_PUBLIC`, when install reads its grants back, then it succeeds, logs one warn naming each such grantee, object and privilege, and keeps the grant.

## Spec Change Log

- 2026-10-12, lead, spec gate: DW-219's three semantics (keep the directory and a carried role, refuse on an unreadable record, path 3 pinned) and DW-2172's warn-only detection accepted; Task 0 (b) struck (it changes a grant the probe did not create); AD-37 and AD-38 amended as proposed. Story 18.13 lands first, so the implement stage re-anchors the Code Map by method name.
- 2026-10-12, lead: DW-2365 routed in by Story 18.13's code review (unverified, MED); Task 0 (e) measures it first. Story 18.13 has landed: re-anchor the Code Map by method name (`GuardOneInstallNamespace` now accepts a namespace that holds the mapping itself).

## Review Triage Log

## Design Notes

**DW-219, decided:**

- **Path 1, keep.** A kept application must keep working (DW-94's "left in place" rule), and the directory is what it serves.
- **Path 2, refuse.** Without the record uninstall cannot tell what OcuPilot created (AD-37), and continuing strips the state surviving applications need; "could not tell" is never "nothing" (DW-65). Once that application is gone, `ReadApplicationProvenance` answers empty, so a repeat uninstall stays a no-op.
- **Path 3, remove once unused.** AD-21's floor role is the installer's to remove, but deleting a role strips it from every application matching it, so a role a surviving application carries stays. The admin and identity roles hold OcuPilot's own resources and `%Admin_Secure:U`; keeping them would leave a privilege behind. Its existing pin (`UninstallResidue` :354) gets a mutation line.

**DW-2172, decided: a warn.** A refusal fails install, which `on-failure:3` turns into a stopped OcuPilot over an operator's grant; a revoke undoes a grant OcuPilot did not make (AD-37); DW-236's refusal half already keeps OcuPilot's tools out.

**Rule 31.** Uninstall reuses `ReadApplicationProvenance`; `UninstallFault` gains its third fault; `ProbeApps` takes over `ShellDirectory`; one catalog read replaces per-grantee `SqlPrivilegeHeld` calls.

**Governing ADs:** AD-9, AD-10, AD-16, AD-17, AD-21, AD-25, AD-37, AD-38; Conventions › Tests, › IRIS security objects. No write key (AD-22), Fixed string, error code, client or bundle change. No test creates a database (the probe's names its own directory).

**Integration:** no service is introduced. **Consumes:** 1.17 (provenance), 1.18 (read-back), 13.1 (residue), 18.9 (the refusal half), 18.13 (`GuardOneInstallNamespace`, `InstallTarget`). **Consumed-by:** none. **Ledger inbox:** DW-219 and DW-2172, both addressed above.

**Where this meets 18.13:** `Uninstall`'s prelude (the provenance read stays after 18.13's guard), its header, `InstallTarget` (swept), and `UninstallFault`, which inherits 18.13's `InstallerProbe` seams. 18.13 edits neither `EnsureSqlPrivileges` nor the removal block.

**For the lead** (Rule 20):

- **AD-37** (applied at the gate) gains: "Uninstall keeps, and reports, the shell bundle directory while an application sits at the shell's path and a roster matching role while a surviving application carries it, and refuses, removing nothing, when its provenance record is unreadable while the profile's routine application exists (DW-219)."
- **AD-38** (applied at the gate) gains: "Install warns naming every grant on OcuPilot's schemas to a grantee other than the escalation role, read from `Security.SQLPrivileges`; it never refuses or revokes one (DW-2172)."
- Rule 11: Epic 20's diff (`32990136`) touches only `scripts/ci-throwaway.sh`, which this story does not. No vendor defect candidate.

## Verification

**Shared surfaces:** Uninstall's preview text and left-in-place warn; the roles and directory it removes; `ProbeApps.Remove` and `ShellDirectory`; `UninstallFault`'s faults; install's grant warns; DEVELOPMENT.md's grant and provenance paragraphs.

**Standing criterion:** every test added or changed passes on a fresh environment, in either order.

**Commands** (each inside one 10-minute foreground call):

- `(loop)` `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/carry-2026-10-08/epic-18-d8/load-ocupilot-ci.sh` -- expected `LOAD-OK` and `STARTPATH-OK`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one at a time, totals from `%UnitTest_Result`: `Provenance`, `UninstallGuard`, `GrantReadBack`, `UninstallResidue`, then Task 9's (each under 80 s in `ui/tools/ci-timings.json`).
- `(loop)` `uv run scripts/check-objectscript.py`; `bash scripts/lint-docs.sh`.
- Full ObjectScript sweep: the runner's; browser suite: CI's (no client change).

**Mutations (Rule 19),** each recorded as `mutation:`, reverted byte-identical, descendants recompiled:

- A1: unconditional directory removal -> the kept-shell test; the preview always listing it -> its preview leg.
- A2: warn-and-continue restored -> the new `UninstallGuard` test; `ReadApplicationProvenance`'s absent branch erroring -> `TestUninstallContinuesWhenTheInventoryIsGone`.
- A3: the role loop keeping every role whose key was not removed this run -> `UninstallResidue` :354; the roster-path-only check restored -> the foreign-role test.
- A4: the `ReportWidenedGrants` call dropped -> the widened-grant test; the `DBRESOURCE` filter dropped -> its escalation-role assertion.

**S0:** no `OcuProbe1843Grantee` role, no `/csp/ocuprobe1843` application, no probe grant in the catalog, and no probe profile object or bundle directory.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
