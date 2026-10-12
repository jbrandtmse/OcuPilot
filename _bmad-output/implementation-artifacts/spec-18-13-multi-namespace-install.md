---
title: 'Story 18.13: Multi-namespace install'
type: 'feature'
created: '2026-10-12'
status: 'done'
baseline_revision: 'c3f331c662ef211e2a06e39dba1340d63f713b0d'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred:
  - summary: >-
      IPM's exporter drops <SystemRequirements> from the archive's module.xml, so the archive carries no IRIS version floor and only the installer enforces it (DW-1333's IPM half).
    evidence: |-
      Measured at Story 13.3 on IPM 0.10.5 (scripts/ci-ipm-archive.sh): the exported manifest has no <SystemRequirements>, though the committed module.xml declares Version ">=2026.2". 18.13 enforces the floor in Installer.GuardVersionFloor and leaves IPM's own version unchecked (AD-18). Owner hold: decision-pending, never reported upstream.
    location: >-
      module.xml :28 and the IPM exporter
    severity: low
---

<intent-contract>

## Intent

**Problem:** OcuPilot already installs into the namespace each path names (DW-12), but nothing stops an install or uninstall from a second namespace half-moving it, nothing says where its package must resolve from, a stored definition's credential rung is not confirmed against the install namespace, IPM's archive carries no version floor (DW-1333), and `Stamp` keeps one row per run forever (DW-423).

**Approach:** The namespace each path already names is the validated target: install refuses a system or missing namespace (exists), a namespace whose `OcuPilot` package resolves from another database, an instance below the roster's IRIS floor, and any namespace but the one holding the profile's global mapping (one install namespace per instance); it maps the profile's globals there (exists), reports definitions whose `creds` rung it cannot reach, and the retention sweep keeps each profile's newest 100 stamps.

## Boundaries & Constraints

**Always:** A refusal changes nothing in either namespace and writes no version row. The container hook refuses before it compiles. Code stays in the install namespace's own routine database (AD-9). The IPM `<Invoke>`, `StartPath` and `MarkInstalling` call shapes are unchanged. A test removes every namespace, database, directory, resource, grant and row it creates.

**Never:** Create a package or routine mapping; move OcuPilot between namespaces; refuse an install over a credential rung; check IPM's version (AD-18); edit `Kernel/Proposal/Prohibited.cls`; build DW-219 or DW-2172 (Story 18.43); build on a `decision-pending` entry.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Chosen namespace | Install runs in T; the profile is installed nowhere | `<mappingPattern>` mapping in T to the profile's database; its applications' `NameSpace` T; a second run leaves `StateFingerprint` equal and adds only its own Stamp row | No error expected |
| Second namespace | The profile's mapping exists in HSCUSTOM; Install or Uninstall runs in T, or `OCUPILOT_NAMESPACE` names T | Refused naming HSCUSTOM and the remedy; nothing changes in either namespace | Container: exit 1 before LoadDir |
| System or missing | `%SYS`, a listed system name, or an override naming an absent namespace | Refused (existing: `GuardInstallNamespace`, container-start.sh) | Unchanged |
| Package elsewhere | `GetPackageDest(T,"OcuPilot")` differs from `GetRoutineDest(T)` | Refused naming both destinations | Nothing written |
| Old instance | IRIS below the roster's `systemRequirements.version` | Refused naming both versions | Nothing written |
| Creds rung | A stored definition on `creds`; `CredentialsRungAvailable()` 0 here | Install succeeds; a warn names each such definition | Unreadable store: a warn, install succeeds |
| Stamp retention | A profile holds more than 100 Stamp rows | The sweep keeps its newest 100; other profiles keep theirs | Step failure logged; the sweep goes on |

</intent-contract>

## Code Map

Under `src/OcuPilot/` unless `scripts/`, `ui/` or root, at `fe132688`.

- **Guards.** `Install/Installer.cls`: `ResolveNamespace` :422, `GuardInstallNamespace` :464 (system refusal only; the target is `$NAMESPACE`). `Install` :715: guard :735, `Names` :742, `LockInstall` :749, version read :783-819, `EnsureMapping` call :869, `RecordAuditMarking` :947, `RecordStamp` :959. `StartPath` :1044 delegates to `Install`; `MarkInstalling` :1141 (its call shape is a cross-version contract, :1136-1140). `Uninstall` :3851 (guard :3863, lock :3876, first read :3903).
- **Where code and data live.** `EnsureApplication` :2123 and `EnsureIdentityApplication` :2192 name `Config.Namespaces.Routines` in the `Routines` allow-list (:2133-2138); `CodeDatabaseResource` :2280 grants read on the routine and globals databases; `EnsureMapping` :2906 creates `<mappingPattern>` (Base `MAPPINGPATTERN` "OcuPilot*" :86 to `DATABASENAME` "OCUPILOT" :70, directory `<mgr>/ocupilot/`, `Names` :210-211); `EnsureSqlPrivileges` :3432 grants in the install namespace; `StateFingerprint` :3549. A probe install's Version and Stamp rows ride the production mapping (`Uninstall` :3842-3849), so in a namespace without it they land in that namespace's globals database (inference; Task 0 measures).
- **Floor.** `Install/Roster.cls` :92-95 (`systemRequirements.version` ">=2026.2"); `module.xml` :28 carries it, the archive does not (DW-1333).
- **Rung.** `Kernel/Secret/Ladder.cls` `CredentialsRungAvailable` :125; `Api/Definitions.cls` :1163 already refuses a `creds` save where it answers 0; `Kernel/State/Agent.cls` `GuardedList` :449, `CredType` :72, `Name` :33.
- **Stamp.** `Kernel/State/Stamp.cls` (production rows store `Profile` NULL, :14-24; read only by tests); `Kernel/Retention.cls` `Sweep` :37-125, one `Step` per store (siblings `Turn.GuardedSweep`, `SqlRun.GuardedSweep`).
- **Container.** `scripts/container-start.sh` resolution session :175-195 (in `%SYS`, before LoadDir), the DW-195 literal `tRefusedList` :182, outcome branches :198-222; `ui/tools/compose.test.mjs` :472 and :501-525 pin the refusal and the literal.
- **Seams and precedents.** `Test/InstallerProbe.cls` (subclass, `LogWarn` capture :25); `Test/WebApp.cls` :673-757 creates and removes a namespace; `Test/Installer.cls` :154 pins no package mapping, :918 the caller's namespace, :961 system names.
- **Arming.** `scripts/ci-throwaway.sh` :494-506 `# classes:` rosters, pinned by `ui/tools/ci.test.mjs` :2366.
- **Docs.** `README.md` :360-381 (says IPM refuses an older version; DW-1333 makes that false); `docs/DEVELOPMENT.md` :604-617.
- **Read on `ocupilot` (2026-10-12):** `OcuPilot*` to OCUPILOT is mapped in HSCUSTOM only (none in USER or `%ALL`, which is listed), so the new guard passes its next start.

## Tasks & Acceptance

**Task 0** (`ocupilot-ci`, after `LOAD-OK` and `STARTPATH-OK`; halt on a contradiction). Record S0. Create `%DB_OCUPROBE1813`, then database OCUPROBE1813 in a new directory `<mgr>/ocuprobe1813/` (never the manager directory), then namespace OCUPROBE1813 (routines: the install namespace's routine database; globals: OCUPROBE1813). From it: `Install("probe")`; read back the probe mapping, the probe applications' `NameSpace`, where probe Version and Stamp rows land, the SQL grant; install again and diff `StateFingerprint("probe")`; read `GetPackageDest`, `GetRoutineDest` and `Config.Namespaces:List` (is `%ALL` listed). `Uninstall("probe", 1)`, revoke the grant if the uninstall leaves it, remove namespace, database, directory and resource; confirm S0. Do not run a production install from it before Task 1 exists. Then settle AD-17's open IPM question (orchestrator, 2026-10-12): import IPM into `ocupilot-ci` the way `scripts/ci-ipm-archive.sh` does (S0 then includes IPM until the runner rebuilds the throwaway), `load` the module from the worktree in OCUPROBE1813 while production is installed in HSCUSTOM, and read whether `/ocupilot`'s and `/api/ocupilot`'s `NameSpace` changed before the installer refused. If it is real, fix it here when it fits (refuse before the applications change, through the `<Invoke>`'s phase in the roster that generates `module.xml`, or restore them on refusal) and pin it; if it does not fit, put it in `deferred:` as a MED for the Epic 18 burn-down. If it is not real, say so; the lead deletes the AD-17 sentence.

**Execution:**

1. `Install/Installer.cls`, each guard writing nothing and naming no failing step:
   - `GuardVersionFloor(pWhat)`, seam `InstanceVersion()`: refuse below the roster's floor, naming both. `Install` calls it after `GuardInstallNamespace`; `Uninstall` does not.
   - `GuardPackageHome(pWhat, pInstallNs)`, seam `PackageDestination(pNs)`: refuse unless the `OcuPilot` package resolves from the namespace's own routine database. Called by `Install` beside the floor.
   - `GuardOneInstallNamespace(pWhat, .pNames, pInstallNs)`: in one `%SYS` window (AD-16), list namespaces, skip the current one and `%ALL`, and refuse naming the first whose `pNames("mappingPattern")` mapping targets `pNames("database")`, with the remedy (run it there, or uninstall there first). `Install` and `Uninstall` call it after their lock, before any read.
   - `ReportCredentialsRung(.pReports)`, seam `CredentialsRungAvailable()` (delegates to `Ladder`): after `RecordAuditMarking`, when the rung is unavailable, warn naming each definition whose `CredType` is `creds`; never fails install.
   - Header: one install namespace per instance, named by each path.
2. `Kernel/State/Stamp.cls`: `Parameter KEEPRUNS = 100`; `GuardedSweep()` deletes all but each profile's newest `KEEPRUNS` rows by ID, NULL a group. `Kernel/Retention.cls`: one `Step` ("install stamps past the kept runs could not be swept"); header lists it.
3. `scripts/container-start.sh`: after `tExists`, an `OTHER:<ns>` outcome when another namespace (not `%ALL`) maps literal `OcuPilot*` to `OCUPILOT`; `tUsable` 0; its branch exits 1 naming both namespaces and the remedy. One statement per line.
4. `ui/tools/compose.test.mjs`: `OTHER:` is refused in the resolution session before LoadDir, and its two literals equal Base's `MAPPINGPATTERN` and `DATABASENAME`.
5. `README.md` :360-381 and `docs/DEVELOPMENT.md` :604-617: one install namespace, a second refused naming the first; the installer, not IPM, refuses an IRIS older than 2026.2. `bash scripts/lint-docs.sh`.
6. `Test/InstallTarget.cls` (new, under 500 lines; arms `OCUPILOT_ALLOW_PRODUCTION_INSTALL`): `OnBeforeAllTests` builds Task 0's namespace (removing a leftover first), `OnAfterAllTests` removes it; each test primes production, uninstalls the probe after.
   - Chosen namespace: probe installs in T; mapping and `NameSpace` read back; a second run leaves the fingerprint equal; uninstall from T leaves none.
   - Second namespace: probe installed in HSCUSTOM; `Install("probe")` and `Uninstall("probe",1)` from T each refused naming HSCUSTOM, and `GuardOneInstallNamespace` called from T with the production `Names` refused the same way (never `Install("")` from T: under the mutation it would move the production install); HSCUSTOM's fingerprints and T's mappings unchanged.
   - Package, floor, rung through `InstallerProbe` seams: a foreign destination and "2026.1" refused; "2026.2" and "2027.1" pass; a seeded `creds` definition (`OcuProbe1813Creds`, deleted after) named by a warn when the rung reads 0, absent at 1.
7. `Test/StampRetention.cls` (new; arms as `Test/Retention`): seed 103 probe rows, run `Retention.Sweep()`, assert the newest 100 remain; `DeleteByProfile("probe")` after.
8. `scripts/ci-throwaway.sh`: add-only `# classes:` entries for both classes.
9. **Rule 30 sweep.** Grep `src/OcuPilot/Test`, `ui/tools` for the guards, the container outcomes, sweep steps and Stamp counts; run `Installer`, `InstallNamespaceSource`, `Version`, `UninstallGuard`, `Retention`, `RetentionTask`, `GrantReadBack`, `InstallLock`, `State`, editing only if red.

**Acceptance Criteria:**

- Given namespace T holding OcuPilot's code in its own routine database and the profile installed nowhere, when install runs in T, then the profile's globals are mapped into T and its applications run in T.
- Given install run twice in the same namespace, when the second run completes, then `StateFingerprint` is unchanged and the only new row is that run's Stamp.
- Given the profile installed in HSCUSTOM, when Install or Uninstall runs in T, or the container start names T, then each is refused naming HSCUSTOM and nothing changes.
- Given `%SYS`, a missing namespace, a package resolving from another database, or an IRIS below the floor, when install validates the target, then it refuses naming the reason.
- Given a stored definition on `creds` where the rung is unavailable, when install runs, then it succeeds and its log names that definition.
- Given a profile with 103 Stamp rows, when the retention sweep runs, then its newest 100 remain.

## Spec Change Log

- 2026-10-12, lead, spec gate: split for size (Rule 5); DW-219 and DW-2172 moved to Story 18.43. The AC is amended in `epics.md` to this plan's readings (one install namespace, the AD-9 package check, the rung reported). AD-17 and the Operational Envelope's Retention row are amended as proposed. The second-namespace production leg calls the guard rather than `Install("")`. Task 8's `ci-throwaway.sh` lines are add-only (slot rule), reported to the orchestrator.
- 2026-10-12, orchestrator: split and order ratified (18.43 right after this story); the rung reported, not refused, accepted as a product call; the IPM re-point is not acceptable as a named limit, so Task 0 measures it and the story fixes it or defers it as a MED.

## Review Triage Log

### 2026-10-12 -- Review pass

- verdicts: 20 findings -- high 0, medium 4, low 12, false 4, maybe-false 0
- findings:
  - `[medium]` `[patch]` The container's second-namespace refusal is pinned only as source text -- `compose.test.mjs` now also pins the scan's clauses (skips the target and `%ALL`, matches on the database) and the `OTHER` arm ahead of `OK`; both mutations red. No executing test added: it needs a live two-namespace container; the session was run by hand (Verification). Same root cause as the intent auditor's container-hook divergence.
  - `[medium]` `[patch]` `GuardTarget`'s version-floor and package-home calls had no test -- probe-seam legs added to the floor and package tests; mutation red (681).
  - `[low]` `[reject]` Nothing runs IPM to show the guard fires before the applications change -- measured once on `ocupilot-ci`; the declared phase is pinned (roster, generated and committed manifest, `Test/Manifest`). A second-namespace load needs an interoperability-enabled namespace in `ci-ipm-archive.sh`, which Epic 20 is reworking. reopen_if=an IPM release updates web applications before Compile, or the package job gains a second-namespace leg.
  - `[low]` `[patch]` The installer's rung predicate was never observed unarmed -- `TestTheInstallersRungPredicateIsTheLaddersOwn` compares it with the ladder in both namespaces; mutation red (681).
  - `[low]` `[patch]` The `creds`-only filter was unpinned -- an `env` definition is stored beside and must not be named; mutation red (681).
  - `[low]` `[patch]` Empty version and empty package destination (the seam-testable fail-closed branches) had no assertion -- legs added; covered by the guards-answer-OK mutation (657) by reading, not re-run.
  - `[low]` `[reject]` Roster-unreadable, namespace-list-unreadable and `%ALL` branches untested -- no seam, theoretical, and `%ALL` is not listed on the throwaway; guards would add a seam per branch.
  - `[low]` `[reject]` The stamp sweep's failure isolation is unverified -- needs a fault-injection seam no sibling step has; the step loop's isolation is pinned by `Retention`'s failing-step test. reopen_if=a stamp-table fault stops the later retention steps.
  - `[medium]` `[patch]` `StampRetention` asserted unfiltered counts for profile `probe`, state an earlier class could leave -- unique profile names and an `OnBeforeOneTest` clean.
  - `[medium]` `[patch]` `InstallTarget` assumed no earlier probe install -- `OnBeforeOneTest` now removes one from both namespaces.
  - `[low]` `[reject]` AC1's "applications run in T" half has no mutation of its own -- Rule 19 asks one mutation per AC, and AC1's is recorded (654).
  - `[low]` `[reject]` The container hook is exercised as text only (intent auditor) -- grouped with the first row.
  - `[low]` `[patch]` README and DEVELOPMENT said an IPM-path refusal "changes nothing", but IPM has compiled the package before the guard runs -- both now say the installer changes nothing in either namespace.
  - `[low]` `[reject]` Package-home and floor refusals come after the compile on the container path -- the Matrix, Task 3 and AC3 put only the second-namespace refusal before it; the image is pinned to 2026.2 and AD-9 rules out a package mapping; a pre-compile probe adds a second copy of both checks.
  - `[false]` `[reject]` The guard adds a second `<Invoke>` -- the install `<Invoke>` is unchanged (class, method, phase, when, no `<Arg>`); the orchestrator's Task 0(d) ruling sanctions a fix through the manifest's phase.
  - `[false]` `[reject]` The refusal is per profile mapping, not per instance -- the intent defines the target as the namespace "holding the profile's global mapping".
  - `[low]` `[reject]` Package, floor and rung legs arm seams -- Task 6 specifies seams; the unarmed rung predicate is now observed (row 4).
  - `[low]` `[reject]` Stamp seeding cannot tell ID order from Timestamp order, no stamp-step failure is induced, and the production-group test trims real production stamps -- Task 2 keeps the newest by ID; failure isolation is row 8; the trimmed rows are write-only history on an armed throwaway.
  - `[false]` `[reject]` The AD-17 and Retention-row replacements live in the spec, not the spine -- Task 0 hands the sentence to the lead, who edits the spine; the replacement text is under "For the lead".
  - `[false]` `[reject]` The README sentence on IPM's version check was rewritten -- Task 5 requires it; DW-1333 made the old sentence false.

## Design Notes

**Ledger.** DW-1333: Task 1's floor (and Task 5). DW-423: Tasks 2 and 7; Stamp is write-only history, so a count bound keeps every row a reader uses. DW-219, DW-2172: proposed for a sibling story (Auto Run Result). DW-1788 stays `wontfix-theoretical`: the second-namespace refusal keeps OcuPilot's applications in one namespace.

**Governing ADs:** AD-9, AD-10 (its one install-namespace arm stays true), AD-16, AD-17, AD-18, AD-21, AD-25, AD-37, AD-38, AD-44; Conventions › Dates. No write key (AD-22), no error code, Fixed string, client or bundle change.

**Install paths, unchanged.** Container: `OCUPILOT_NAMESPACE`, else HSCUSTOM then USER. IPM: where `zpm` runs; `<Invoke>` takes no argument. Hand: the session's namespace. In T, code is T's routine database, data OCUPILOT behind `OcuPilot*` in T only; applications, roles, allow-lists, grant and retention task follow T.

**"Maps the package", under AD-9:** the globals mapping plus the package-home check. Session-agent's `InstallIntoNamespace` package-maps code from another database, contradicting AD-9, AD-21 and `Test/Installer` :154.

**Creds: report, not refuse.** A refusal stops every definition for one key; the save already refuses the rung.

**Rule 31.** Guards sit beside `GuardInstallNamespace`; the container outcome follows DW-195's; `Stamp.GuardedSweep` follows `SqlRun.GuardedSweep`; tests follow `WebApp` :673 and `InstallerProbe`.

**Consumes:** 1.4, 1.17, 3.9, 14.4, 23.2. **Consumed-by:** 18.41 (inference). No service is introduced.

**For the lead** (Rule 20):

- **AD-17** and the Operational Envelope's **Retention** row: applied at the gate (Spec Change Log). **AD-17's open IPM sentence is real and fixed** (Task 0, measured on `ocupilot-ci` with production in HSCUSTOM): `zpm`'s `load -dev` run from an interoperability-enabled second namespace re-pointed `/ocupilot`, `/api/ocupilot` and `/api/ocupilot/readiness` to that namespace before the installer refused (IPM's web application processor updates them in `OnBeforePhase` of `Activate`, ahead of any `Activate` invoke), and the shell answered 401 until `StartPath` repaired them. The roster now declares a `guard` invoke (`Installer.GuardTarget`, `Phase="Compile" When="After"`): the same load fails in Compile with the installer's refusal, the three applications stay in HSCUSTOM and the shell answers 200; a load in HSCUSTOM passes the guard and completes. Replace the sentence "Open, and measured at Story 18.13's Task 0: ..." with: "IPM updates a module's web applications at the start of `Activate`, before any `Activate` invoke, so the manifest carries a guard `<Invoke>` after `Compile` (`Installer.GuardTarget`) that makes the install's refusals before IPM touches an application." In a namespace without interoperability the load fails earlier, in Compile, until Story 20.28 lands.
- **AD-9 reading** above; the package-mapping alternative restates AD-9, AD-21 and AD-10's database arm, the owner's call.
- **DW-1333:** IPM's exporter dropping `<SystemRequirements>` is an IPM tool-defect candidate (Story 13.3), never reported upstream; IPM's version stays unchecked (AD-18).
- **Pre-authorization (Rule 11):** Task 8's add-only lines in `ci-throwaway.sh` (Epic 20's).

## Verification

**Shared surfaces:** installer refusals, container-start outcomes, the retention sweep's steps, Stamp row counts, the arming rosters, README and DEVELOPMENT install tables.

**Standing criterion:** every test added or changed passes on a fresh environment, in either order.

**Commands:**

- `(loop)` `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/carry-2026-10-08/epic-18-d8/load-ocupilot-ci.sh` -- expected `LOAD-OK` and `STARTPATH-OK` (the in-place upgrade from the previous head).
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one at a time, totals from `%UnitTest_Result`: `InstallTarget`, `StampRetention`, and Task 9's classes.
- `(loop)` `cd ui && npm run test:tools`; `uv run scripts/check-objectscript.py`; `bash scripts/lint-docs.sh`.
- Full ObjectScript sweep: the runner's; browser suite: CI's (no spec touched).
- Upgrade from 1.0.11: install changed 24 lines since `72db8709`, none in the mapping or namespace steps, so a 1.0.11 instance meets one mapping in its install namespace (inference); the next cut's upgrade check executes it.

**Mutations (Rule 19),** each reverted byte-identical (`cmp` against a copy taken first) and every descendant recompiled by the loader, run on `ocupilot-ci` 2026-10-12:

- mutation: `Install` skips `EnsureMapping` -> `InstallTarget`'s chosen-namespace and second-namespace legs red (run 654). `EnsureWebApplication` stamps `$ZTimeStamp` into `Description` -> "leaves the state fingerprint unchanged" red (655).
- mutation: `GuardOneInstallNamespace` answers OK -> the install, uninstall, production and IPM-guard refusal assertions red (656). The container `OTHER:` branch removed -> `compose.test.mjs` red; the session's mapping literal changed -> its literal-equality test red.
- mutation: `GuardPackageHome` and `GuardVersionFloor` answer OK -> `TestAPackageResolvedFromAnotherDatabaseIsRefused` and `TestAnInstanceBelowTheFloorIsRefused` red (657).
- mutation: the `ReportCredentialsRung` call removed from `Install` -> `TestACredsDefinitionIsReportedWhereTheRungIsUnavailable` red (658).
- mutation: the stamp step removed from `Retention.Sweep` -> both `StampRetention` tests red (659). The empty-profile group skipped -> the production-group test red (660). One bound on the whole table -> both red (661).
- mutation: the guard `<Invoke>` phase `Activate` -> the fixture roster: `ipm-manifest.test.mjs` red; the real roster: `ipm-manifest.mjs --check` reports the drift and `Test/Manifest` red (662).
- mutation: `GuardTarget` without its `GuardVersionFloor` and `GuardPackageHome` calls -> the two "IPM guard invoke refuses ..." legs of `InstallTarget` red; `CredentialsRungAvailable` answering 1 -> `TestTheInstallersRungPredicateIsTheLaddersOwn` red in OCUPROBE1813; the `creds` filter removed from `CredsDefinitionNames` -> "none names the definition on the env rung" red (all one run, 681; reverted `cmp`-identical, reloaded, green at 682).
- mutation: the `$ZConvert(...)=tUpper:""` clause deleted from the container scan -> `compose.test.mjs` "the second-namespace scan skips the target ..." red; the `tExists: "OK:"` arm moved ahead of `OTHER:` -> the same test red (reverted `cmp`-identical).
- manual check (also executed by the two (QA) tests below): the container resolution session, run on `ocupilot-ci` up to its outcome line with `OCUPILOT_NAMESPACE` unset and `HSCUSTOM` answered `OK:HSCUSTOM`, `USER` answered `OTHER:HSCUSTOM:USER`, `%SYS` answered `SYSTEM:%SYS`, `NOSUCH` answered `MISSING:NOSUCH`; the mark step was left out so the throwaway stayed installed.
- (QA) `src/OcuPilot/Test/ContainerStartNamespace.cls` (4 tests, run 729 green; armed under `OCUPILOT_ALLOW_PRODUCTION_INSTALL` in `scripts/ci-throwaway.sh`): executes the start script's resolution session in `%SYS` against a namespace it creates (own directory, resource and database, all removed): `OK`, `OTHER:<holder>:<target>` with `tUsable` 0, a mapping onto another database not counted, `SYSTEM`, `MISSING`. It reads `/opt/ocupilot/scripts/container-start.sh`, so the throwaway's `scripts/` copy must be the worktree's (the loader syncs `src` only).
- (QA) `ui/tools/container-start-outcome.test.mjs` (3 tests): runs the script under `sh` with a stub `iris`; `OTHER`, `SYSTEM` and `MISSING` exit 1 after the one resolution session, `OK` goes on to the next.
- mutation (QA, each reverted `cmp`-identical, reloaded and green after): `Install` without its `GuardOneInstallNamespace` call -> only the install leg of `TestASecondNamespaceIsRefusedAndNothingChanges` red, 3 of 6 tests via its leftover (688); `Uninstall` without it -> the uninstall leg red (690); the guard matching only the probe database -> the guard and IPM guard-invoke legs red, the install and uninstall legs green (730).
- mutation (QA): `GuardVersionFloor` answers OK -> `TestAnInstanceBelowTheFloorIsRefused` red incl. the unreadable and IPM legs (692); `GuardPackageHome` answers OK -> `TestAPackageResolvedFromAnotherDatabaseIsRefused` red (694); `Install` without the floor call -> only its floor leg red (696); without the package call -> only its package leg red (698); `GuardTarget` without the floor call -> only the IPM floor leg red (700); without the package call -> only the IPM package leg red (702); `GuardTarget` handing the guard an empty install namespace -> "passes in the namespace that holds the install" red alone (704); `GuardTarget` without its last guard -> the IPM refusal legs red alone (706).
- mutation (QA): `Uninstall` gated by the floor -> "uninstall is not gated by the floor" red (708); `VersionBelow` comparing pieces as strings -> "2026.10 meets the floor" red (710); equal versions counted below the floor -> all 6 `InstallTarget` tests red, the prime install refusing on the instance's own 2026.2 (712); `IsSystemNamespace` without the `%` rule -> `Installer.TestSystemNamespacesAreRefusedAsInstallTargets` (732) and `Version.TestInstallRefusesFromWrongNs` (733) red.
- mutation (QA): the installer's rung predicate answering 1 -> `TestTheInstallersRungPredicateIsTheLaddersOwn` red alone (714); the `creds` filter removed -> "none names the definition on the env rung" red alone (716); the unreadable-store warn skipped -> "warns that they could not be read" red alone (718); the stamp cutoff inclusive (`ID <=`) -> both `StampRetention` tests red (720).
- mutation (QA): the scan counting the resolved namespace -> `ContainerStartNamespace` install-namespace tests red (722); the scan ignoring the database -> the other-database test red (724); the `OK` arm ahead of `OTHER` -> the second-namespace test red (726); `tUsable` ignoring another holder -> the same test red on `|1` (728); the `OTHER:*)` branch without `exit 1` -> `container-start-outcome.test.mjs` second-namespace test red on the session count; the `OK` branch not setting `INSTALL_NS` -> its resolved-namespace test red; the `SYSTEM:*)` branch without `exit 1` -> its session-count test red; the `ContainerStartNamespace` row removed from `ci-throwaway.sh` -> `ci.test.mjs` "each arming roster" red.

**S0:** no OCUPROBE1813 namespace, database, directory or resource; no `ProbeOcuPilotState*` mapping; no `OcuProbe1813Creds` definition.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** One install namespace per instance: `Install` refuses a system or missing namespace, an IRIS below the roster's floor (`GuardVersionFloor`, DW-1333), a package that resolves from another database (`GuardPackageHome`, AD-9) and a second namespace (`GuardOneInstallNamespace`, also in `Uninstall`); a `creds` definition on an unreachable rung is reported, never refused; the retention sweep keeps each profile's newest 100 stamps (DW-423). The container start refuses a second namespace before `LoadDir`. AD-17's IPM re-point was real: IPM updates the web applications at the start of `Activate`, so the roster now declares a `guard` invoke (`GuardTarget`, `Compile`, After) that refuses first.

**Files.** `Install/Installer.cls` (guards, rung report, seams), `Install/Roster.cls`, `module.xml`, `ui/tools/ipm-manifest.mjs` (the guard invoke), `Kernel/State/Stamp.cls`, `Kernel/Retention.cls` (the sweep), `scripts/container-start.sh` (`OTHER:` outcome), `scripts/ci-throwaway.sh` (two add-only `# classes:` lines), `README.md`, `docs/DEVELOPMENT.md`; tests `Test/InstallTarget.cls` and `Test/StampRetention.cls` (new, 499 and 140 lines), `Test/InstallerProbe.cls`, `Test/Manifest.cls`, `ui/tools/compose.test.mjs`, `ui/tools/ipm-manifest.test.mjs`.

**Review.** Patched: 4 mediums and 4 lows (log above). Deferred: the IPM exporter's dropped `<SystemRequirements>` (owner hold). Rejected: 4 false and 8 low, each with its reason in the log. Follow-up review recommended: the container `OTHER` outcome is pinned by source text and one by-hand run, and the review patches were checked by one combined mutation run rather than one run each.

**Verification (`ocupilot-ci`).** `LOAD-OK` and `STARTPATH-OK`; `InstallTarget` 6 tests (run 682), `StampRetention` 2 (680), `Manifest` 10 (668); the Rule 30 classes `Installer` 27, `InstallNamespaceSource` 3, `Version` 19, `UninstallGuard` 3, `Retention` 10, `RetentionTask` 4, `GrantReadBack` 3, `InstallLock` 6, `State` 12, `ToolEmit` 11 (runs 669-678), 0 failed each; `npm run test:tools` 1922/1922; `check-objectscript.py` 0 problems; `lint-docs.sh` 0 problems; `ipm-manifest.mjs --check` up to date. Throwaway at S0 plus IPM imported in HSCUSTOM with a dev-loaded `ocupilot` module registered there (unregistering it would delete the web applications; the runner's rebuild clears it).

**Upgrade from 1.0.11.** Not run against 1.0.11 itself. The live `ocupilot` holds the `OcuPilot*` mapping in HSCUSTOM only, and the resolution session answers `OK:HSCUSTOM` there; repeated in-place `StartPath` runs on the throwaway stayed idempotent. A 1.0.11 instance with a stale mapping in a second namespace would now be refused at its next start, which is the intended rule.

**Residual.** Epic 20's 20.28 package job installs into a created `NOINTEROP` namespace on a fresh instance; the new guard only refuses where another namespace on that instance holds the mapping, which that job does not create.
