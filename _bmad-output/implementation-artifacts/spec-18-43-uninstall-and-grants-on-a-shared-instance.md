---
title: 'Story 18.43: Uninstall and grants on a shared instance'
type: 'feature'
created: '2026-10-12'
status: 'done'
baseline_revision: '4b8daea24d483d7bdd0c6a57b9284f9c8609e4f6'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-18-13-multi-namespace-install.md'
warnings: ['oversized']
deferred:
  - summary: >-
      A `zpm uninstall ocupilot` run in a second namespace deletes the live web applications and bundle directory, and no uninstall-phase guard `<Invoke>` can stop it (DW-2365, IPM tool-defect candidate).
    evidence: |-
      Measured on ocupilot-ci (IPM 0.10.5), 2026-10-12: a load refused by GuardTarget in a second namespace leaves the module registered there; `zpm uninstall ocupilot` there removed /ocupilot, /api/ocupilot, /api/ocupilot/readiness and csp/ocupilot/ in HSCUSTOM. IPM runs every resource processor's OnBeforePhase (web application and FileCopy deletes, by name) before the phase's Invoke elements: a probe module's Clean/Before Invoke returning an error did not stop its web application's deletion. NameDelete on the module registry deregisters it without touching the applications. Documented in README and DEVELOPMENT.md. Owner hold: decision-pending, never reported upstream.
    location: >-
      module.xml and IPM's %IPM.Storage.Module ExecutePhases
    severity: medium
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

### Review Findings

Code review 2026-10-12 (`full-opus`; blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor): 38 rows, 10 entries patched (2 medium, 8 low), 0 deferred, 0 decision-needed, 17 rejected.

- [x] [Review][Patch] (medium, fix-risk low) Nothing pinned row 8 or Task 2's "none when no row remains": deleting `If tText = "" Quit $$$OK` stayed green, and the doc's escalation-filter mutation claim was stale -- `TestACheckThatFindsNoOtherGranteeWarnsNothing` added, the before-leg asserts the escalation role is never named [src/OcuPilot/Test/GrantReadBack.cls:186, :225]
- [x] [Review][Patch] (medium, fix-risk med, Rule 2) `RolesInUse` copied `AssertNoForeignOcuPilotRole`'s application and `MatchRoles` read with no stated reason -- both now consume `ApplicationMatchRoles`; `RolesInUse`'s doc no longer claims an `Exists` failure is reported [src/OcuPilot/Install/Installer.cls:3089, :3122]
- [x] [Review][Patch] (low) `%ALTER`, `REFERENCES`, `EXECUTE` and `USE` reached the warn as bare letters -- mapped; the schema grant in the test now includes `%ALTER` [src/OcuPilot/Install/Installer.cls:3875; src/OcuPilot/Test/GrantReadBack.cls:202]
- [x] [Review][Patch] (low) The roles-read refusal was absent from the header and DEVELOPMENT.md and named no remedy -- one clause each, and a remedy in the message [src/OcuPilot/Install/Installer.cls:4215, :4379; docs/DEVELOPMENT.md:349]
- [x] [Review][Patch] (low) DEVELOPMENT.md's grant sentence left out columns and the unreadable-catalog warn, and its last clause was garbled -- rewritten [docs/DEVELOPMENT.md:219]
- [x] [Review][Patch] (low) The kept-directory warn gave a reason the code never checks ("still served from it") -- now "an application still sits at the shell's path" [src/OcuPilot/Install/Installer.cls:4620]
- [x] [Review][Patch] (low) The provenance-refusal test's mutation note said every assertion goes red; under an empty record the applications and directory stay -- corrected [src/OcuPilot/Test/UninstallGuard.cls:243]
- [x] [Review][Patch] (low) `TestAnAccountThatCannotEnterSysGetsOneWarnNamingTheSwitch` asserted a namespace restore that cannot fail (the switch throws before `$NAMESPACE` changes) -- assertion and the child's field removed [src/OcuPilot/Test/GrantReadBack.cls]
- [x] [Review][Patch] (low) The kept-directory test's last assertion passed through `ProbeApps.Remove`, not through uninstall -- it now removes the kept application and asserts a later uninstall removes the directory [src/OcuPilot/Test/Provenance.cls:323]
- [x] [Review][Patch] (low) "Nothing running" never checked that its interception fired, so a moved read path would read the instance and still pass when it is quiet -- the leg counts and asserts its answered reads [ui/browser/sql-activity.browser-spec.mjs:337]

**Rejected:**

- (low, by-design) The provenance refusal's remedy (`Install` with no profile) may not repair an unreadable record, since `Install` reads the version row first (inference) -- Task 1 names this remedy; reopens only by spec amendment.
- (low, wontfix-accepted) README names a refused `zpm load`, not `zpm "install ocupilot"` -- DW-2365's documentation (owner hold); reopen_if=a refused `zpm "install ocupilot"` in a second namespace shows `ocupilot` in that namespace's `zpm list`.
- (low, by-design) The IPM cleanup leaves the compiled package and shows `NameDelete` as a bare expression -- DW-2365's scope (owner hold).
- (low, wontfix-theoretical) `RolesInUse`/`ApplicationMatchRoles` skip an application `Exists` cannot read, and neither catalog loop checks `Next`'s status -- real if `Exists` or a fetch fails for a listed application while `List` and `Get` succeed.
- (low, by-design) `Grantable` is not reported -- the spec asks for grantee, object and privilege.
- (low, by-design) Holders of the escalation role itself are not reported -- AD-38's amendment scopes the check to other grantees; who holds `%DB_OCUPILOT` is AD-9's.
- (low, wontfix-theoretical) A procedure grant (type 9) in OcuPilot's schema is not reported -- the schema holds no views and only the generated `*_Extent` procedures, which read the database AD-9 guards; real if a procedure there returns data its grantee could not otherwise read.
- (false) A quoted `SqlQualifiedNameQ` would miss the catalog -- every name in the State package is unquoted (acceptance-auditor probe).
- (low, wontfix-theoretical) A `Uninstall("probe")` after a production uninstall is refused -- the probe profile is test-only and no test uninstalls production.
- (low, wontfix-theoretical) `MatchRoles` changed between the roles read and the role loop -- concurrent administration during an uninstall.
- (low) One application naming a role twice in different case is listed twice in the warn -- cosmetic, unlikely.
- (low, wontfix-theoretical) `ProbeApps.RemoveShellDirectory` reports OK when its `Exists` check throws -- real if `Security.Applications.Exists` raises in `%SYS`.
- (low, wontfix-theoretical) `RunAsLimited` leaves its child running after a 60 s timeout -- the project-wide JOB-and-wait pattern; real if a child outlives the wait.
- (low, wontfix-theoretical) "Probe stopped" needs every row rendered -- a throwaway runs a handful of statements; real if more run than the grid renders.
- (low, by-design) DW-2240's browser-spec edit is outside the code boundary -- the orchestrator pulled DW-2240 into this story.
- (low) Two role tests key on `%Operator`, `%Manager` and `%Developer`, which they did not create -- built-in roles on every instance; the tests create and remove the applications that carry them.
- (low) Stale spec lines (Residual, an earlier reject) and the spec's size -- their fix edits the spec under review.

## Spec Change Log

- 2026-10-12, lead, spec gate: DW-219's three semantics (keep the directory and a carried role, refuse on an unreadable record, path 3 pinned) and DW-2172's warn-only detection accepted; Task 0 (b) struck (it changes a grant the probe did not create); AD-37 and AD-38 amended as proposed. Story 18.13 lands first, so the implement stage re-anchors the Code Map by method name.
- 2026-10-12, lead: DW-2365 routed in by Story 18.13's code review (unverified, MED); Task 0 (e) measures it first. Story 18.13 has landed: re-anchor the Code Map by method name (`GuardOneInstallNamespace` now accepts a namespace that holds the mapping itself).

## Review Triage Log

### 2026-10-12 -- Review pass

- verdicts: 19 findings -- high 0, medium 2, low 15, false 2, maybe-false 0
- findings:
  - `[medium]` `[patch]` Column-grant classification in `ReportWidenedGrants` had no test -- a column grant and its assertion added to `TestAWidenedGrantIsNamedAndKept`, mutation red (692).
  - `[low]` `[patch]` Privilege naming and joining tested for one SELECT only -- the schema grant now carries four privileges and the joined text is asserted, mutation red (693).
  - `[low]` `[reject]` The namespace filter is not discriminated by any test -- a second namespace holding a same-named OcuPilot schema is refused by 18.13's one-namespace rule; the fix needs a second namespace and database. reopen_if=OcuPilot may be installed in two namespaces.
  - `[low]` `[reject]` The CI leftover check cannot see the foreign application, role, grant or directory the new tests create -- each is removed at three sites and every CI leg starts on a fresh throwaway. reopen_if=a CI class reddens on a Story 18.43 fixture leaked by an earlier class.
  - `[false]` `[reject]` Some legs have no recorded mutation -- Rule 19 requires one per acceptance criterion and A1 to A4 each carry one.
  - `[low]` `[patch]` Two mutation recipes in unchanged test comments named code the diff removed -- both rewritten against the new guards and run red (694, 695).
  - `[low]` `[patch]` `Provenance` preview leg was negative-only -- a companion assertion on the preview's own text added.
  - `[low]` `[reject]` The unreadable-catalog test reaches only the exception arm -- the status and namespace-switch arms set the same failure and emit the same warn.
  - `[medium]` `[patch]` The widened-grant test's baseline asserted that no widened grant existed on the instance -- it now asserts the test's own grantee and `_PUBLIC` grant are absent.
  - `[low]` `[reject]` `DropProbeGrants` would revoke a `_PUBLIC` grant that predates the test -- the class runs on a throwaway only (`ARMINGVARIABLE`).
  - `[low]` `[reject]` `zpm uninstall` bypasses `Installer.Uninstall` -- the intent names `Uninstall`; DW-2365 was routed in with the direction to document and defer when no guard fits.
  - `[low]` `[patch]` The kept application's warn had no remedy while the directory and roles did -- a remedy clause appended; `Provenance`, `WebApp`, `UninstallResidue` and `UninstallSurvival` green.
  - `[low]` `[reject]` The directory remedy says delete by hand while a later uninstall also removes it -- both are true and the warn names one valid remedy.
  - `[low]` `[reject]` Failures are induced at the call boundary, not inside the real reads -- the project's fault-seam pattern; the real reads cannot be failed without breaking the instance.
  - `[low]` `[reject]` The role rule is wider than the matrix row and no test covers a present application that does not carry the role -- A3's first sentence requires it, and the absent-application test shares the `tInUse` lookup.
  - `[false]` `[reject]` The warn surfaces only in the console log -- the spec asks for a warn and the install result is unchanged by design.
  - `[low]` `[reject]` The warn text and report sit outside the `Try` in `ReportWidenedGrants` -- they iterate an in-memory array and call `Report`, which every install step uses; theoretical.
  - `[low]` `[reject]` `ProbeApps.Existing()` reports applications only -- same root as the leftover-check row above.
  - `[low]` `[reject]` Additions beyond the matrix (roles-read refusal, refused preview, column forms, README and DEVELOPMENT.md) -- each follows the Always clause or Task 0, and the roles-read refusal is now pinned by `TestUninstallRefusesWhenTheApplicationRolesCannotBeRead`.

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

**Task 0, measured on `ocupilot-ci` 2026-10-12:**

- (a) Shell row deleted, then uninstall: the shell application and its role stayed, the directory was removed, and `GET /probeocupilot/index.html` went from 200 to 503 `STATIC.NOBUNDLE`.
- (c) A foreign `/csp/ocuprobe1843` carrying the shell's role lost it: the role was deleted and its `MatchRoles` read empty. `Security.Applications:Detail("*", -1)` answers 49 rows of 53 columns in 2 ms, but its `MatchRoles` column holds only conditional entries (1 of 49 non-empty; unconditional `:Role` entries sit in `AddedRoles`), so `RolesInUse` reads `List` then `Get` as `AssertNoForeignOcuPilotRole` does (49 rows, 21 non-empty, 2 ms).
- (d) `Security.SQLPrivileges:List` (29,346 rows, 0.19 s) answers a schema as `5,OCUPILOT_KERNEL_STATE`, a table as `1,OcuPilot_Kernel_State.Version` and a column as `1,OcuPilot_Kernel_State.Stamp.Profile`, with letters `s i u d`, grantor `irisowner`, Grantable 0. Every form is answered; the column inference was wrong and no form is a named limit.
- (e) DW-2365 is real and no uninstall-phase `<Invoke>` fits: see `deferred:`. The remedy (`NameDelete` in that namespace) is in README and DEVELOPMENT.md.

**For the lead** (Rule 20):

- **AD-37** (applied at the gate) gains: "Uninstall keeps, and reports, the shell bundle directory while an application sits at the shell's path and a roster matching role while a surviving application carries it, and refuses, removing nothing, when its provenance record is unreadable while the profile's routine application exists (DW-219)."
- **AD-38** (applied at the gate) gains: "Install warns naming every grant on OcuPilot's schemas to a grantee other than the escalation role, read from `Security.SQLPrivileges`; it never refuses or revokes one (DW-2172)."
- Rule 11: Epic 20's diff (`32990136`) touches only `scripts/ci-throwaway.sh`, which this story does not. One IPM tool-defect candidate (DW-2365, `deferred:`), decision-pending.

## Verification

**Shared surfaces:** Uninstall's preview text and left-in-place warn; the roles and directory it removes; `ProbeApps.Remove` and `ShellDirectory`; `UninstallFault`'s faults; install's grant warns; DEVELOPMENT.md's grant and provenance paragraphs.

**Standing criterion:** every test added or changed passes on a fresh environment, in either order.

**Commands** (each inside one 10-minute foreground call):

- `(loop)` `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/carry-2026-10-08/epic-18-d8/load-ocupilot-ci.sh` -- expected `LOAD-OK` and `STARTPATH-OK`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one at a time, totals from `%UnitTest_Result`: `Provenance`, `UninstallGuard`, `GrantReadBack`, `UninstallResidue`, then Task 9's (each under 80 s in `ui/tools/ci-timings.json`).
- `(loop)` `uv run scripts/check-objectscript.py`; `bash scripts/lint-docs.sh`.
- Full ObjectScript sweep: the runner's; browser suite: CI's (no client change).

**Mutations (Rule 19),** run on `ocupilot-ci` 2026-10-12, each reverted `cmp`-identical and reloaded (final-tree runs 697-709, all green):

- mutation: A1 -- the shell directory removed unconditionally -> `Provenance.TestUninstallKeepsTheBundleDirectoryOfAKeptShellApplication` red (666); the preview always listing it -> its preview leg red (667).
- mutation: A2 -- the refusal block disabled (warn and continue) -> `UninstallGuard.TestUninstallRefusesWhenTheProvenanceRecordCannotBeRead` red (668); Uninstall treating an absent routine application as a read failure -> `TestUninstallContinuesWhenTheInventoryIsGone` red (669); Uninstall carrying on past a failed roles read -> `UninstallGuard.TestUninstallRefusesWhenTheApplicationRolesCannotBeRead` red (685).
- mutation: A3 -- the role loop keeping every role whose application was not removed this run -> `UninstallResidue.TestUninstallRemovesAMatchingRoleWhoseApplicationIsAlreadyGone` and the `roledapplication` leg of `TestUninstallCompletesWithOneTargetAlreadyAbsent` red (670); the roster-path-only check restored -> `Provenance.TestUninstallKeepsAMatchingRoleAnotherApplicationCarries` red (671); the `tInUse` guard dropped from the role loop -> that test, `TestUninstallLeavesAKeptApplicationsPrivilegeFloorIntact` and `TestThePreviewListsTheRolesTheConfirmedRunDeletes` red (695); dropped from the preview's role list -> the preview test red (694).
- mutation: A4 -- the `ReportWidenedGrants` call dropped -> `GrantReadBack.TestAWidenedGrantIsNamedAndKept` red (672); the escalation-role filter dropped -> its "no widened grant" and "never the escalation role" assertions red (673). The failure branch of `ReportWidenedGrants` made silent -> `GrantReadBack.TestAnUnreadablePrivilegeCatalogIsOneWarn` red (684); the column arm of the object classification disabled -> `TestAWidenedGrantIsNamedAndKept` red (692); a privilege letter relabelled -> the same test red (693).
- (QA) Tests added to existing classes: `GrantReadBack` (`TestACatalogQueryThatFailsToExecuteIsOneWarn`, `TestOnlyAGrantOnOcuPilotsSchemaInTheInstallNamespaceIsReported`, `TestAnAccountThatCannotEnterSysGetsOneWarnNamingTheSwitch`) and `UninstallGuard` (`TestRolesInUseNamesARoleInEveryFormAnApplicationCarriesIt`, `TestUninstallRemovesAMatchingRoleThatAPresentApplicationDoesNotCarry`), through `InstallerProbe` seams (`SetPrivilegeCatalogExecuteFails`, `DriveReportWidenedGrants`, `WidenedGrantWarns`, `DriveRolesInUse`); `Provenance`'s foreign-application helpers and `RoleExists` are class methods; `ui/browser/sql-activity.browser-spec.mjs` (DW-2240). Final-tree runs on `ocupilot-ci`, totals from `%UnitTest_Result`: GrantReadBack 725 (8), UninstallGuard 726 (7), Provenance 727 (9).
- mutation: (QA) A4 -- the status check after `tRS.Execute()` in `ReportWidenedGrants` dropped -> `GrantReadBack.TestACatalogQueryThatFailsToExecuteIsOneWarn` red (717); the failure branch after the namespace switch dropped -> `TestAnAccountThatCannotEnterSysGetsOneWarnNamingTheSwitch` red (718); the namespace comparison dropped -> `TestOnlyAGrantOnOcuPilotsSchemaInTheInstallNamespaceIsReported` red (719); the object classification (`If tKind = "" Continue`) dropped -> the same test red (720).
- mutation: (QA) A3 -- `RoleNamesIn` reading only the last role of each entry -> `UninstallGuard.TestRolesInUseNamesARoleInEveryFormAnApplicationCarriesIt` red (721); `RolesInUse` ignoring its excepted applications -> that test and `TestUninstallRemovesAMatchingRoleThatAPresentApplicationDoesNotCarry` red (722); the role loop keeping every roster role while any application carries any role -> the second test red (724).
- (QA, DW-2240) Reproduced on `ocupilot-ci` with a second SQL probe job running: the old "Nothing running" leg timed out at 30 s; the rewritten spec (8 tests: "Probe stopped" asserts the probe's row and statement are gone, "Nothing running" answers the screen's read with no statement in the browser and asserts the empty-state sentence) passed 8 of 8 in the same state.
- (QA, DW-2240) Bundle rebuilt and redeployed; `node --test --test-concurrency=1 browser/sql-activity.browser-spec.mjs` with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`: run 1 8 of 8, run 2 8 of 8, run 3 8 of 8, run 4 8 of 8 straight after `system-explorer-sql-query.browser-spec.mjs` (3 of 3).
- mutation: (QA, DW-2240) the `Stop` call in "Probe stopped" replaced by a read-only call -> that leg red (the probe's row is still listed); the descriptor's `emptyStateKey` set to `sqlActivityLabel`, mirror regenerated, bundle rebuilt and redeployed -> "Nothing running" red; both reverted `cmp`-identical, bundle rebuilt and redeployed clean.
- mutation: (CR) A4 -- `If tText = "" Quit $$$OK` deleted from `ReportWidenedGrants` -> `GrantReadBack.TestACheckThatFindsNoOtherGranteeWarnsNothing` red (729); the escalation-role filter dropped -> both escalation-role assertions of `TestAWidenedGrantIsNamedAndKept` red (730). A3 -- `ApplicationMatchRoles` storing an empty `MatchRoles` -> `WebApp.TestTheInstallTimeAssertionRefusesAnOcuPilotRoleOnAnotherApplication` red (737) and `UninstallGuard.TestRolesInUseNamesARoleInEveryFormAnApplicationCarriesIt` red (738). DW-2240 -- `READ_PATH` pointed elsewhere -> "Nothing running" red on its answered-read assertion. Each reverted `cmp`-identical and reloaded; final-tree runs on `ocupilot-ci`: GrantReadBack 739 (9), UninstallGuard 740 (7), WebApp 741 (26), Provenance 732 (9), Installer 734 (27), UninstallResidue 735 (4), UninstallSurvival 736 (2); bundle rebuilt and redeployed, `sql-activity` 8 of 8.

**S0:** no `OcuProbe1843Grantee` role, no `/csp/ocuprobe1843` application, no probe grant in the catalog, and no probe profile object or bundle directory.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** `Uninstall` reads the provenance record through `ReadApplicationProvenance` and refuses, removing nothing, when it cannot while the profile's routine application exists. It keeps the shell bundle directory while an application sits at the shell's path, and a roster role while another application's `MatchRoles` names it (`RolesInUse`), and names each in one left-in-place warn with its remedy. A failed roles read also refuses. `EnsureSqlPrivileges` calls `ReportWidenedGrants`: one warn naming each non-escalation grantee, object and privilege on OcuPilot's schema, tables and columns, never refusing or revoking; an unreadable catalog is one warn.

**Files.**

- `src/OcuPilot/Install/Installer.cls`: `Uninstall`, `RolesInUse`, `ReportWidenedGrants`, seam `SqlPrivilegeQuery`.
- `src/OcuPilot/Test/`: `UninstallFault` (provenance and roles faults), `InstallerProbe` (catalog seam), `ProbeApps` (`ShellDirectory`, `RemoveShellDirectory`), `Provenance` (two tests), `UninstallGuard` (two refusal tests), `GrantReadBack` (two tests, `ProbeColumn`, `DropProbeGrants`), `UninstallResidue` (delegation).
- `docs/DEVELOPMENT.md` and `README.md`: the grant warn, the three uninstall rules, and the DW-2365 cleanup.

**Review.** 19 findings: 6 patched (2 medium, 4 low), 13 rejected (reasons in the log above), 0 new deferred. `deferred:` holds DW-2365 from the implement pass. Follow-up review: not recommended; the patches are test-side or a warn-text clause and each carries a recorded mutation or a green final-tree run.

**Verification.** Task 0 on `ocupilot-ci`: DW-2365 is real and no uninstall-phase guard fits (IPM removes the web applications before any `<Invoke>`); the cleanup is `NameDelete` in that namespace. Column and every other grant form are answered by `Security.SQLPrivileges:List`. Final-tree runs on `ocupilot-ci`, totals read from `%UnitTest_Result`: GrantReadBack 697 (5), Provenance 698 (9), WebApp 699 (26), UninstallResidue 700 (4), UninstallSurvival 701 (2), UninstallGuard 702 (5), Installer 703 (27), InstallTarget 704 (7), InstallLock 705 (6), IdentityInstall 706 (6), InstallNamespaceSource 707 (3), ContainerStartNamespace 708 (5), Manifest 709 (10). `check-objectscript.py` and `lint-docs.sh`: 0 problems. The throwaway reads S0; IPM remains imported in its second namespace until the runner rebuilds it.

**Residual.** The `ReportWidenedGrants` status and namespace-switch arms, and the namespace filter, have no test (rows above).
