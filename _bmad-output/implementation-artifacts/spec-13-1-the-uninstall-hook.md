---
title: 'Story 13.1: The uninstall hook'
type: 'feature'
created: '2026-09-19'
status: 'done'
baseline_revision: '3213b2b557f614aae707700999e8fc310d7a4676'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred:
  - summary: >-
      Uninstall's unconfirmed dry-run preview still filters the role list by provenance, so it
      under-reports the roles the confirmed run now deletes, and one warning states the opposite.
    evidence: |-
      Installer.cls:3532 lists a role only when $Data(tRecorded(tUName)); the role loop at :3665
      now also deletes a role whose application is absent. Divergent state: role present,
      application absent, no provenance row -- reachable when GuardedPathsForProfile fails
      (:3507, which Kills tRecorded) or when an install failed between EnsureApplicationRoles
      (:824) and EnsureApplications (:844). The :3509 warning "no web application and no
      application matching role will be removed" is then false. Only orphan roles are affected,
      so no AD-21 floor is stripped. Fix is outside the granted footprint (role loop only).
    location: >-
      src/OcuPilot/Install/Installer.cls:3509,3528-3536
    severity: medium
  - summary: >-
      The AC5 StateFingerprint equality is green but no mutation has been shown to redden it.
    evidence: |-
      Recorded at origin in the spec's AC4 Verification bullet: both readings come from the same
      guard-then-act path against the same freshly-uninstalled state, so a uniform change to
      Install moves them together; the asymmetric attempt (Uninstall skipping the application
      delete, run 20) left it green because Install repairs an application already at its roster
      path. The named test is falsifiable on its install/loopback half (run 21). Settled by
      finding a genuinely asymmetric mutation, or by re-scoping the assertion to idempotency.
    location: >-
      src/OcuPilot/Test/UninstallSurvival.cls TestUninstallThenInstallRestoresTheProfileAndServes
    severity: medium
  - summary: >-
      The intent-contract's Symmetry row and AC6 name Install(""), but the reinstall that
      reaches a smoke-green instance is StartPath(pDemo, pBundleSource).
    evidence: |-
      Install takes no demo opt-in and no bundle source (AD-25), so a bare Install("") leaves the
      demofixture, x509 and wallet smoke checks failing on a healthy instance. Corrected in the
      Verification bullet; the intent-contract is read-only to this stage, so the claim still
      stands at its origin and wants a lead amendment at a spec boundary.
    location: >-
      _bmad-output/implementation-artifacts/spec-13-1-the-uninstall-hook.md intent-contract
    severity: low
  - summary: >-
      Security.Applications.Exists in the role loop reads a failed lookup as "absent" and
      deletes the role -- the unsafe direction for the DW-94 hazard.
    evidence: |-
      Installer.cls:3665 discards the by-ref status tSW2; Exists answers 0 both for absence and
      for a failed read. The pre-existing application loop at :3639 has the same pattern but
      fails safe (Continue). Not patched: the correct fix needs an error-code-specific branch
      (distinguishing "does not exist" from other failures), which guards a state never shown
      reachable in %SYS mid-uninstall, and getting it wrong silently reverts this story's core
      behavior. AnyObjectExists repeats the pattern at eight sites.
    location: >-
      src/OcuPilot/Install/Installer.cls:3665
    severity: low
  - summary: >-
      Test/Provenance.cls:238-240's Rule 19 recipe names the pre-edit guard text.
    evidence: |-
      The recipe says to drop "'$Data(tRemovedKeys(tRKey)) Continue"; the guard is now a compound
      condition. The recipe still reddens as written (verified: removing the whole guard produced
      the run-8 red), so this is wording drift, not a broken recipe. Provenance.cls is read-only
      to this story, so it was not corrected at origin.
    location: >-
      src/OcuPilot/Test/Provenance.cls:238-240
    severity: low
  - summary: >-
      AC6 (production uninstall, reinstall, smoke) and the loopback / auditing-enabled halves
      carry no mutation line.
    evidence: |-
      AC6's evidence is the single recorded run (executed=45 passed=45); nothing re-executes a
      production Uninstall("",1) -- the CI instance job installs and smokes but never uninstalls.
      The probe-profile classes exercise the same profile-agnostic path, so marginal risk is low.
      The loopback and auditing-enabled assertions are structurally falsifiable (both helpers
      answer -1 on a failed read) but neither has been observed red.
    location: >-
      _bmad-output/implementation-artifacts/spec-13-1-the-uninstall-hook.md Verification
    severity: low
  - summary: >-
      Residue() and the AC2 target table are narrower than the sentences asserted with them.
    evidence: |-
      Residue() omits the shell bundle directory, the Kernel.State.Version row, the
      Kernel.State.WebApp provenance rows and the five non-task demo-inventory kinds, yet backs
      "every other object install created is gone too". DeleteTarget covers 5 of roughly 11
      separately guarded targets in Uninstall (no leg for the database, the %DB_ resource, the
      admin resource, the privileged routine application or the bundle directory).
    location: >-
      src/OcuPilot/Test/UninstallResidue.cls Residue, DeleteTarget
    severity: low
  - summary: >-
      Probe-role cleanup is asymmetric between the two new classes, and two helpers swallow
      every failure.
    evidence: |-
      UninstallResidue.CleanProbe sweeps orphaned probe roles; UninstallSurvival's teardown calls
      a bare ProbeApps.Remove(), which deletes a role only when its application is still present,
      and ci-unit-test.sh's PROBEAPPS leak check reads applications only. RemoveProbeRoles and
      RemoveTaskAndRows return nothing and Catch into a discard, so CleanProbe can answer OK with
      residue still on the instance.
    location: >-
      src/OcuPilot/Test/UninstallResidue.cls:84-125; src/OcuPilot/Test/UninstallSurvival.cls:66-78
    severity: low
  - summary: >-
      scripts/ci-throwaway.sh's arming-roster comment is stale at its origin.
    evidence: |-
      It names "the twelve test classes that run OcuPilot's PRODUCTION install" and enumerates
      them; both new classes run Install("") under that variable, making it fourteen, and the
      OCUPILOT_ALLOW_AUDIT_EVENTS line omits UninstallSurvival. check-objectscript.py's
      destructive-test-guard rule is pattern-based and cannot catch a stale comment roster.
      Out of this story's granted footprint.
    location: >-
      scripts/ci-throwaway.sh:169,177-181
    severity: low
---

<intent-contract>

## Intent

**Problem:** `OcuPilot.Install.Installer.Uninstall` already exists and already removes almost everything install creates (Epic 1, Story 1.4). What is missing is **proof against this story's four acceptance criteria**, plus one real residue: a roster-declared application role whose web application is already absent is never removed, so "everything the installer created" is not true once any target has gone by another hand. Three of the four ACs have no falsifiable pin at all — nothing anywhere asserts that the IRIS audit database keeps OcuPilot's marker rows through an uninstall (AC3), that a *partially* absent instance still uninstalls cleanly (AC2), or that uninstall-then-install reaches a **working** OcuPilot rather than merely a present one (AC4).

**Approach:** Close the one residue with a bounded edit to `Uninstall`'s roster-role loop, and add two new test classes that pin AC1's uncovered targets, AC2's per-target absence, AC3's survival pair and AC4's symmetry. Record a Rule 19 mutation for every AC, including the ACs Epic 1 already satisfies — for those, the story's deliverable is the evidence, not a rewrite.

## Boundaries & Constraints

**Always:** Guard-then-act in both directions — every removal stays behind its `Exists` check and an absent target returns `$$$OK` (AD-17). Uninstall removes only what install created: an application at a roster path with no provenance row, and its matching role, stay exactly as they are and are reported (AD-21, AD-25, AD-37; DW-94). Removal order stays as it is — fixtures first, then applications, then roles, then the escalation infrastructure, then the database, then the events and the SSL configuration (AD-9). Destructive tests run against the disposable `"probe"` profile only, armed by `Parameter ARMINGVARIABLE` and refused otherwise, with the second guard in `OnAfterAllTests` that `OcuPilot.Test.Static:73-90` explains. Audit-row reads carry `%NOINDEX` on the three event predicates and a `UTCTimeStamp` bound (DW-85), or they read a false zero.

**Never:** No test calls `Uninstall("")` (production) on any shared instance — the production cycle is proved on a throwaway only. Nothing deletes, purges or filters rows in the IRIS audit database: OcuPilot's markers are the instance's record, not OcuPilot's (AD-15, AD-46). Uninstall never disables instance-wide auditing, never revokes the role grant of an application it kept, and never touches a pre-existing `/csp/myapp` (AD-25). No second uninstall path is written — there is one entry point (AD-17), and no new notion of "working" beside the smoke path (AD-45).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Full probe teardown | Probe installed, all targets present | `Uninstall("probe",1)` = OK; all three applications, both matching roles, admin resource + role, every roster audit-event triple, `%DB_OCUPILOTPROBE`, the database and its directory, the privileged routine application, the mapping, the SSL configuration and every demo-fixture object are gone | No error expected |
| One target already absent | Probe installed, then exactly one target deleted by hand (per-target table: shell application, admin role, SSL configuration, mapping, one audit triple) | `Uninstall("probe",1)` = OK, and every remaining target is still removed | Already-absent is never an error (AD-17) |
| Application absent, its role present | Probe installed, shell application deleted by hand, role `ProbeOcuPilotShell` left | `Uninstall("probe",1)` = OK **and the orphaned role is removed** — no roster-declared role survives when no application sits at its roster path | A distinct defect from DW-244, whose `reopen_if` names a *clean* uninstall |
| Application adopted, its role present | An application at a roster path with no provenance row | The application **and** its matching role both survive, and the adoption is reported | Not an error; a warn names the adopted path (DW-94) |
| Marker rows outlive the registration | A row emitted under the probe triple, then `Uninstall("probe",1)` | `Security.Events.Exists` for the triple is **false**; the emitted row is **still readable** from `%SYS.Audit`; instance auditing is still enabled | If the row is gone, uninstall has destroyed the instance's record — a HIGH defect, not a test failure to work around |
| Demo task fixture | A `%SYS.Task` fixture row recorded in the demo inventory | The task is gone from `%SYS.Task` after uninstall, and its inventory row with it | A failed task delete keeps the row and refuses the database drop (DW-65, already pinned) |
| Symmetry | Probe installed → `Uninstall("probe",1)` → `Install("probe")` | `StateFingerprint` is byte-identical to the pre-uninstall value, and the probe API answers over loopback | Any difference is an asymmetry, reported as a diff of the two fingerprints |

</intent-contract>

## Code Map

- `src/OcuPilot/Install/Installer.cls:3440` -- `Uninstall(pProfile, pConfirmDataLoss)`, the one entry point; doc contract `:3366-3439`. **Read by line range only (231 KB).**
- `src/OcuPilot/Install/Installer.cls:3657-3665` -- the roster-role loop. `If '$Data(tRemovedKeys(tRKey)) Continue` (`:3659`) is the residue: it removes a role only when *this run* removed its application. **The one edit this story needs.** The DW-94 rationale above it (`:3651-3656`) protects a role whose application is still present; it does not speak to an application that is already absent.
- `src/OcuPilot/Install/Installer.cls:3636-3650` -- the application-delete loop, provenance-gated (`:3640-3643`); `:3338-3364` `AnyObjectExists` (caller contract: `$NAMESPACE` must be `%SYS`); `:3161-3292` `StateFingerprint`, the ready-made symmetry oracle (does **not** cover the SQL grant, DW-96); `:140-247` `Names`, which resolves every target name and the `Probe` suffix.
- `src/OcuPilot/Install/Roster.cls:107-142` -- shell / API / readiness application keys, paths and matching roles. The application set is roster-driven; the database, resources, mapping and SSL configuration are hand-enumerated in `Names`.
- `src/OcuPilot/Kernel/Audit/Event.cls:68-99` -- `Source()`, `Type()`, `Roster()`, `Names(pSuffix)`. Both profiles share Source and Type and differ only in the event **Name** suffix, so a probe row is emitted under `(AUDITSOURCE, AUDITTYPE, "<name>Probe")`.
- `src/OcuPilot/Install/Fixture.cls:528` `CreateTask`, `:846` `Remove`, `:1016` `%SYS.Task.%DeleteId`, `:69` `APPPATH = "/csp/myapp"`, `:265,290-292` the pre-existing-application early return that never records a row. The demo fixture's task is the **only** scheduled task OcuPilot creates — the installer creates none.
- `src/OcuPilot/Test/AuditEvent.cls:133` -- the DW-85 audit-row read idiom (`%NOINDEX` + `UTCTimeStamp >= ?`). **Copy the idiom into the new class; do not edit this file.** Its `Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_AUDIT_EVENTS"` (`:26`) is the second arming variable.
- `src/OcuPilot/Test/Static.cls:60-90` -- the destructive-setup precedent, including the second arming guard in `OnAfterAllTests` that a new destructive class must copy.
- `src/OcuPilot/Test/WebApp.cls:975-1001`, `src/OcuPilot/Test/Installer.cls:618-671,686-746`, `src/OcuPilot/Test/Provenance.cls:210-252`, `src/OcuPilot/Test/UninstallGuard.cls:85-217` -- the existing pins. **Read-only: no edit to any of them.** `Test/WebApp.cls:972-974` carries an unrecorded mutation note; `Test/Installer.cls:630` carries none.
- `src/OcuPilot/Test/ProbeApps.cls:10-11` -- the roster-derived leak check `ci-unit-test.sh` runs before and after every class; it reads **applications only, not roles** (DW-244's second trailer).
- `scripts/ci-unit-test.sh` -- one class per invocation; `scripts/ci-throwaway.sh`, `scripts/smoke.sh` -- the throwaway and the definition of "installed and working" (AD-45).

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Install/Installer.cls` -- in `Uninstall`'s roster-role loop (`:3657-3665`), keep a roster-declared matching role **only while an application still sits at that key's roster path**; remove it otherwise, behind the existing `Security.Roles.Exists` guard -- so an application removed by another hand cannot leave its role behind, while DW-94's kept-application floor is untouched. Extend the loop's doc comment with the absent-application arm in one sentence. **No other change to this file.**
- `src/OcuPilot/Test/UninstallResidue.cls` -- **new class.** Pins AC1's uncovered targets and AC2's per-target absence: a real `%SYS.Task` demo-fixture row is gone after uninstall; a table-driven leg deletes exactly one target by hand, runs `Uninstall("probe",1)`, and asserts OK plus removal of the rest; the orphaned-role leg above. Arms on `OCUPILOT_ALLOW_PRODUCTION_INSTALL`, installs and tears down the `"probe"` profile only, and carries the `OnAfterAllTests` second guard.
- `src/OcuPilot/Test/UninstallSurvival.cls` -- **new class.** Pins AC3 and AC4: emit one row under the probe triple, uninstall, then assert as one pair that the **registration is gone** and the **row is still readable** (DW-85 read idiom) and that instance auditing is still enabled; then `Install("probe")` and assert `StateFingerprint` is identical to the pre-uninstall value and that the probe API answers over loopback. Arms on both `OCUPILOT_ALLOW_PRODUCTION_INSTALL` and `OCUPILOT_ALLOW_AUDIT_EVENTS`.
- No ledger write is part of this story's execution. DW-244 is terminal (`wontfix-accepted`) and owned by `1-18-epic-1-burn-down`; its `reopen_if` names a **clean-throwaway** `Uninstall('probe')` leaving a `Probe*` role, which the code as written does not do, so it does not fire. The residue this story closes needs an application removed by hand first and is in-story scope, pinned by an acceptance criterion rather than tracked as deferred work.

**Acceptance Criteria:**

- Given a probe install in which exactly one target has been removed by hand, when `Uninstall("probe",1)` runs, then it returns OK and every other target install created is gone — including a matching role whose application was the target removed.
- Given an application uninstall **deliberately left in place** (adopted, no provenance row) and an application that was **already absent**, when the roster-role loop runs, then the two cases remain distinguishable in the code and in its doc comment: the first keeps its matching role to preserve that application's AD-21 privilege floor (DW-94), the second has no floor to preserve and its role is removed. A change that makes the two indistinguishable is wrong even if the other criteria pass.
- Given an OcuPilot audit row emitted under the probe triple, when `Uninstall("probe",1)` completes, then the triple's registration is absent, the row is still readable from `%SYS.Audit`, and instance auditing is still enabled.
- Given an application at a roster path with no provenance row, when uninstall completes, then that application and its matching role both survive and the adoption is reported.
- Given `Uninstall("probe",1)` followed by `Install("probe")`, when both have returned OK, then `StateFingerprint` equals its pre-uninstall value and the probe API answers over loopback.
- Given a production `Uninstall("",1)` then `Install("")` on a throwaway, when both have returned OK, then `scripts/smoke.sh` reports a non-zero executed-check count with no failure.

## Spec Change Log

- 2026-09-19, orchestrator clarification (granted): the bounded edit to `Installer.cls` `Uninstall` (3657-3665) is authorised, with the requirement that the DW-94 distinction stay explicit -- added above as an acceptance criterion. Clearance re-verified against `origin/OCU-1-epic5` = `2767f5a`.
- 2026-09-19, lead spec gate: two planner claims corrected at origin. The orphaned-role residue was described as firing DW-244's `reopen_if`; DW-244's probe is a *clean* `Uninstall('probe')` leaving a `Probe*` role, which this code does not do, so the residue is a distinct in-story defect and DW-244 stays terminal and owned by `1-18-epic-1-burn-down`. The consequent task to reopen and close DW-244 in the ledger is removed: this story writes no ledger entry.

## Review Triage Log

### 2026-09-19 — Review pass

- verdicts: 52 findings — high 0, medium 4, low 23, false 13, maybe-false 0, rejected-on-refutation counted under false
- findings:
  - `[medium]` `[defer]` blind-hunter: dry-run preview no longer describes what the run destroys (`Installer.cls:3528-3536`) — verified at :3532 vs :3665; divergent state (role present, application absent, no provenance row) is reachable via the :3507 failure branch and a part-failed install. Only orphan roles are affected, so no AD-21 floor is stripped. Fix is outside the granted role-loop footprint → deferred #1.
  - `[low]` `[reject]` blind-hunter: role delete lost its provenance gate (AD-37) — real but spec-bound: acceptance criterion 2 states the name-based rule verbatim ("no roster-declared role survives when no application sits at its roster path"). Closed `by-design`; roles carry no provenance record, and install's `AssertNoForeignOcuPilotRole` (`:2581`) already refuses a foreign same-named role.
  - `[false]` `[reject]` blind-hunter: guard asks "is there an application at this key's path" rather than "is this role matched by any application" — roster `matchRole` values are distinct per key (`shell`→`OcuPilotShell`, `api`→none, `readiness`→`OcuPilotReadiness`), so no sibling key can strip a surviving application's floor; the cross-application case needs an operator to hand an OcuPilot role to a foreign application, which install refuses.
  - `[low]` `[defer]` blind-hunter: failed existence check read as "absent" (`:3665`) — verified, `tSW2` discarded. Not patched: the fix needs an error-code branch guarding a state never shown reachable, and a wrong branch silently reverts the story's core behavior. Pre-existing house pattern at `:3639` and eight sites in `AnyObjectExists` → deferred #4.
  - `[low]` `[defer]` blind-hunter: `Test/Provenance.cls:238-239` mutation recipe names code that no longer exists — verified as wording drift only: removing the whole guard still reddens the test (run 8). `Provenance.cls` is read-only to this story → deferred #5.
  - `[medium]` `[patch]` blind-hunter: no test re-verifies the kept-role arm after the guard changed — the arm IS pinned by `Provenance.TestUninstallLeavesAKeptApplicationsPrivilegeFloorIntact`, but its red had never been observed against the new guard. Patched: mutation applied on the throwaway, observed red (run 8), reverted, green again (run 11), and recorded as a new `## Verification` bullet.
  - `[medium]` `[patch]`/`[defer]` blind-hunter: two of six ACs have no mutation line — the DW-94 arm is now recorded (above); AC6 remains unrecorded → deferred #6.
  - `[medium]` `[defer]` blind-hunter: `StateFingerprint` equality unfalsifiable and not recorded durably — verified from the spec's own AC4 bullet; now also carried in frontmatter `deferred` → deferred #2.
  - `[low]` `[patch]` blind-hunter: residue failure message throws away the residue — verified against `irislib/%UnitTest/TestCase.cls` `AssertEqualsViaMacro` (`If '$data(description)`), so a described failure never appends the actual. Patched: every residue/task/row/status assertion in both new classes now carries its actual.
  - `[low]` `[patch]` blind-hunter: `RowCount` is the one helper with no `Try`/`Catch` — verified; patched to trap, check `%SQLCODE` and answer `-1` like its siblings, with the doc updated.
  - `[low]` `[patch]` blind-hunter: database directory name transcribed (`:142`) — verified; patched to derive it from `#DATABASENAME` the way `Installer.Names` does, and the class header's "derived, not transcribed" claim now names its one remaining exception.
  - `[low]` `[defer]` blind-hunter: `Residue()` narrower than the sentence it backs — verified (omits the bundle directory, version row, provenance rows, five demo kinds) → deferred #7.
  - `[low]` `[defer]` blind-hunter: `DeleteTarget` covers 5 of the separately guarded targets — verified against `Uninstall`'s guard sites → deferred #7.
  - `[low]` `[patch]` blind-hunter: HTTP 200 cannot tell a working reinstall from a broken one — verified: `Readiness` answers 200 in every gate state and `Answers()` discards the body. The assertion is not vacuous (it proves reachability and dispatch) but its doc overstated it; patched the doc to say what the 200 does and does not prove.
  - `[low]` `[patch]` blind-hunter: loopback rationale does not hold (an anonymous GET exercises no SQL grant) — verified; patched in the same doc rewrite.
  - `[low]` `[patch]` blind-hunter: header overstates the second guard — verified: `OnAfterAllTests` checked one arming variable while the header claimed both. Patched the guard to check both, making the claim true.
  - `[low]` `[defer]` blind-hunter: `RemoveProbeRoles` / `RemoveTaskAndRows` swallow every failure — verified (`Catch` into a discard) → deferred #8.
  - `[low]` `[defer]` blind-hunter: probe-role leakage asymmetric between the classes — verified against `ProbeApps.Remove` and the applications-only leak check → deferred #8.
  - `[false]` `[reject]` blind-hunter: duplicates the private `Fixture.CreateTask` property block — the duplication is deliberate and documented (the test hand-creates one task rather than running `Fixture.Create`, which would create four other objects and run the task); `TaskIds` is the shared query both go through, so a divergence would fail the test loudly rather than silently.
  - `[low]` `[reject]` blind-hunter: task name breaks the naming convention (`OcuPilotDemoProbeResidue purge`) — cosmetic; the name is deliberately distinct so a run never removes another profile's fixture, and nothing parses it. Fix would be a rename with no behavioral gain.
  - `[low]` `[defer]` blind-hunter: `ci-throwaway.sh` arming roster stale — verified; out of the granted footprint → deferred #9.
  - `[low]` `[patch]` blind-hunter: Verification bundle-build ordering wrong — verified: `ci-throwaway.sh` copies `ui/dist` at `up` time and mounts it read-only. Patched the bullet to say "before `ci-throwaway.sh up`".
  - `[low]` `[reject]` blind-hunter: table leg keeps looping after its own setup assertions fail — real but the per-row design is deliberate and a failing setup row already names itself; the fix adds branching for a case that only arises when the instance is already broken.
  - `[low]` `[reject]` blind-hunter: the spec was `oversized` and this pass grew it — acknowledged; the added text is the Rule 19 mutation record this story exists to produce, which the workflow requires in this section. Kept, not padded further.
  - `[low]` `[defer]` blind-hunter: the `$Get` form decides a destruction — same root cause as the `Exists` finding → deferred #4.
  - `[low]` `[defer]` edge-case: `Exists` fails for a reason other than absence → role deleted — same root cause → deferred #4.
  - `[low]` `[reject]` edge-case: roster role present, application absent, never recorded → deleted against AD-37 — spec-bound, same refutation as the AD-37 row above.
  - `[low]` `[patch]` edge-case: `OnAfterAllTests` arming asymmetry — patched (above). The stated consequence (a confirmed data-loss uninstall) overstated it: the teardown calls `ProbeApps.Remove()`, not `Uninstall`.
  - `[low]` `[patch]` edge-case: `#DATABASENAME` change would silently stop the directory check — patched (above).
  - `[low]` `[defer]` edge-case: `Provenance.cls:238` recipe names a deleted line — same root cause → deferred #5.
  - `[low]` `[defer]` edge-case: adopted-application survival is conditional on `Exists` answering non-zero — same root cause → deferred #4.
  - `[low]` `[patch]` edge-case: `UninstallSurvival.cls:18` header claim — patched (above).
  - `[low]` `[patch]` edge-case: `UninstallResidue.cls:142` "derived not transcribed" claim — patched (above).
  - `[medium]` `[defer]` verification-gap: dry-run preview filters roles by provenance, deletion no longer does — same root cause as blind-hunter's first row → deferred #1. Its suggested patch (a `Uninstall(profile, 0)` leg asserting the refusal text names the role) is the right shape but lands outside the granted footprint.
  - `[medium]` `[defer]` verification-gap: AC5's `StateFingerprint` equality not falsifiable — same root cause → deferred #2. Filed disposition `defer`, honoured.
  - `[low]` `[defer]` verification-gap: loopback and auditing-enabled halves carry no mutation line — both are structurally falsifiable (helpers answer `-1` on a failed read) but neither observed red → deferred #6.
  - `[medium]` `[patch]` verification-gap: AC (DW-94) has no mutation line and its in-code recipe no longer exists — patched: mutation observed red at run 8 and recorded. The `Provenance.cls` half stays deferred (#5), as the layer itself recommended raising rather than silently fixing.
  - `[low]` `[defer]` verification-gap: AC6 pinned by a one-time manual command — verified: the CI `instance` job never runs a production `Uninstall("",1)` → deferred #6.
  - `[low]` `[defer]` verification-gap (other): `:3528-3529` comment states something false — same root cause → deferred #1.
  - `[low]` `[defer]` verification-gap (other): failed lookup read as a negative result — same root cause → deferred #4.
  - `[low]` `[reject]` verification-gap (other): the new rule widens AD-37 — the layer itself concludes the spec frames the widening as intentional; spec-bound, closed `by-design`.
  - `[low]` `[defer]` verification-gap (other): `Provenance.cls:238-240` cites the deleted line — same root cause → deferred #5.
  - `[medium]` `[defer]` intent-alignment D1: AC4's expectation lives at the symmetry assertion; the recorded red lands at `Install`'s own assert — same root cause → deferred #2.
  - `[medium]` `[patch]` intent-alignment D2: the edit's own keep arm is unfalsified — the single most consequential observation of the pass, and the one the footprint grant was conditioned on. Patched by running the mutation (run 8 red, run 11 green) and recording it.
  - `[low]` `[reject]` intent-alignment D3: AC3's mutation is coarser than the intent's (date-range rather than source/type-scoped) — refuted as unavoidable: the instance refuses `DELETE FROM %SYS.Audit` (SQLCODE -134) and `%DeleteId` (ERROR #673), so the vendor's date-range `Delete` is the only route that removes a row at all. Recorded in the AC3 bullet.
  - `[low]` `[defer]` intent-alignment D4: AC1's expectation spans the demo inventory; the assertion surface is the security/config set plus one seeded row — same root cause → deferred #7. The spec's Design Notes already scope five of six demo kinds out.
  - `[low]` `[defer]` intent-alignment D5: five AC2 rows asserted, one falsified — same root cause → deferred #7.
  - `[false]` `[reject]` intent-alignment D6: the production cycle is a procedure, not an artifact — descriptive, and the layer notes the intent's own "Never" clause makes this the sanctioned shape. Coverage concern captured in deferred #6.
  - `[low]` `[defer]` intent-alignment D7: the reinstall entry point moved from `Install("")` to `StartPath` — verified and sound in substance, but the intent-contract still names `Install("")` → deferred #3 for a lead amendment.
  - `[false]` `[reject]` intent-alignment D8: "probe profile only" vs a production install in setup — refuted: the probe's protected database is created through production's privileged routine application, so a production install is a precondition of a probe install, and both classes are armed for it.
  - `[false]` `[reject]` intent-alignment D9: the implemented rule is wider than the matrix row it closes — the spec's acceptance criterion 2, not the matrix row, states the implemented rule; the code matches the AC.
  - `[low]` `[defer]` intent-alignment D10: corrections made in Verification rather than at the intent-contract origin — the intent-contract is read-only to this stage → deferred #3.
  - `[false]` `[reject]` intent-alignment: readings R1–R7 enumerated with no divergence claimed beyond D1–D10 — descriptive context, no defect asserted.

## Design Notes

**Governing ADs.** AD-17 (one installer class, two entry points, idempotent, guard-then-act, roster generated from one source), AD-9 (protected database, guarding resource, privileged routine application, and the order that takes them down without orphaning), AD-21 (the unauthenticated applications' purpose-built application roles, created *and removed* by the installer; the both-directions invariant), AD-25 (demo fixture opt-in, removed by uninstall, a pre-existing `/csp/myapp` never touched), AD-45 (readiness is the third application, created and removed by the installer; the smoke path is the definition of "working"), AD-15 and AD-46 (the audit database's rows are the instance's record — registration is OcuPilot's, the rows are not), AD-38 (a production uninstall re-arms the container start path's first-install behavior, including `EnsureUnexpired`), AD-10 (removing OcuPilot's own applications, resource, role or database is an operator act through the install path and is never an agent tool), AD-32 (the installer's named SSL configuration, which uninstall removes), AD-16 (`%SYS` by explicit save and restore), AD-37 (OcuPilot deletes what OcuPilot created, and nothing else). Conventions rows *IRIS security objects* (a `%DB_*` resource's implicit role is IRIS-managed and vanishes with the resource — nothing deletes it explicitly, and nothing should) and *Tests*.

**This is gap-closure, not a build.** Per-AC state of the Epic 1 implementation: AC1 is met for the three applications, both matching roles, the admin resource and role, every roster audit triple, the database, its `%DB_*` resource, the mapping, the privileged routine application, the bundle directory and the SSL configuration — pinned by `Test/WebApp.cls:975` and `Test/Installer.cls:630`, with **no recorded mutation**. AC1 is unpinned for a real scheduled task and for five of the six demo-fixture kinds. AC2 is met and pinned at the profile level (`Test/Installer.cls:618`) and unpinned per target. AC3 is entirely unpinned. AC4 is exercised ~22 times a suite run as harness lifecycle but never asserted as *working*.

**"The scheduled tasks" in AC1 is satisfied by the fixture path.** The installer creates no `%SYS.Task` of its own (`grep %SYS.Task src/OcuPilot/Install/Installer.cls` → one comment, `:3549`); the only task is the demo fixture's `OcuPilot.Install.DemoTask`, removed through the fixture inventory. The clause is therefore vacuous outside demo mode today, which is why this story pins the fixture task rather than inventing an installer task. A later epic that adds a retention task (Operational Envelope, 7.2) must add it to the same roster-driven path so this hook removes it without an edit of its own.

**Whether an emitted audit row survives its registration's deletion is an open empirical question** *(inference: `Security.Events.Delete`'s body is not in the `irissys/` export, so the cascade cannot be settled statically)*. The AC3 pin is what settles it. If the rows do not survive, that is a HIGH defect against AD-15/AD-46 and an `intent gap` for the lead — not something to soften in the test.

**Footprint (Epic 5 also holds `src/OcuPilot/Install/**` and `src/OcuPilot/Test/**`).** Both new test classes are files this story creates, so they are ours. **One edit to an existing file is required. GRANTED by the orchestrator 2026-09-19**, re-verified immediately before the edit against Epic 5's pushed head `origin/OCU-1-epic5` = `2767f5a`, which touches zero files under `src/OcuPilot/Install/` when diffed against merge-base `1f5f1c3`. Reported under `footprint_extensions:` at completion. The grant carries one binding constraint, now an acceptance criterion above: the DW-94 distinction between an application left in place and one already absent must stay visible in the code and in the doc sentence. The edit is: `src/OcuPilot/Install/Installer.cls`, method `Uninstall`, the roster-role loop at `:3657-3665` only. It cannot live in a new class: the loop runs inside a ~350-line method that holds the `%SYS` namespace switch, the profile install lock, the ordered teardown and the `tRemovedKeys` array built by the immediately preceding application-delete loop — a subclass override would have to reproduce the whole method, and `Uninstall` is `AD-17`'s single entry point, not a seam. **No edit to `src/OcuPilot/Install/Smoke.cls` is planned**; AC4's "working" is proved by `scripts/smoke.sh` against a throwaway (AD-45's one path) rather than by a new smoke check, which would have needed `Smoke.Run:212`.

**Integration ACs (Rule 1).** This story introduces no service, module or shared component — it closes a residue in an existing method and adds test classes. No consumer exists in this story. **Consumes:** `OcuPilot.Install.Installer` (`Uninstall`, `Install`, `StateFingerprint`, `Names`), `OcuPilot.Install.Roster`, `OcuPilot.Install.Fixture`, `OcuPilot.Kernel.Audit.Event`, `OcuPilot.Kernel.State.Base`, `scripts/ci-throwaway.sh`, `scripts/ci-unit-test.sh`, `scripts/smoke.sh`. **Consumed-by:** Story 13.2 (its stock-image CI suite runs both new classes and counts them toward the coverage floor), Story 13.3 (its dry-run archive must install on a fresh instance, which the symmetry pin is the standing evidence for).

## Verification

**Commands** (slot B throughout; every IRIS MCP call carries `server: "ocupilot-slot-b"`):

- `uv run scripts/check-objectscript.py src/OcuPilot/Install/Installer.cls src/OcuPilot/Test/UninstallResidue.cls src/OcuPilot/Test/UninstallSurvival.cls` -- expected: clean, 21 rules.
- Compile the three classes through the IRIS MCP tools against `ocupilot-slot-b` -- expected: no errors. Recompile the whole `OcuPilot.Install` and `OcuPilot.Test` packages before reading any mutation result (an inherited method keeps a per-subclass compiled copy).
- `bash scripts/ci-throwaway.sh up --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci --web 52777 --super 1976` -- expected: the throwaway comes up installed, its container named for the project. The script takes an action word first and has no `--container` flag. **Every destructive class below runs there, never on `ocupilot-slot-b`.**
- `sh scripts/ci-unit-test.sh --container ocupilot-b-ci --class OcuPilot.Test.UninstallResidue` -- expected: all methods pass, `PROBEAPPS` clean. **One class per call; send the next only once this run has landed in `%UnitTest_Result` (Rule 18 (3)).**
- `sh scripts/ci-unit-test.sh --container ocupilot-b-ci --class OcuPilot.Test.UninstallSurvival` -- same, as a separate call.
- Regression, one class per call, in this order: `OcuPilot.Test.UninstallGuard`, `OcuPilot.Test.Installer`, `OcuPilot.Test.WebApp`, `OcuPilot.Test.Provenance`, `OcuPilot.Test.InstallLock` -- expected: unchanged. `Provenance` and `WebApp` are the two the role-loop edit can move.
- Production cycle, on the throwaway only: `docker exec ocupilot-b-ci iris session iris -U HSCUSTOM` running `Uninstall("",1)` then `StartPath(1, "/opt/ocupilot/ui/dist/ocupilot-ui/browser")`, then `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` -- expected: smoke reports a non-zero executed-check count and no failure. Zero executed checks is a failure, never a pass. The reinstall is the container hook's own entry point, not a bare `Install("")`: the demo opt-in and the bundle source are `StartPath`'s arguments (AD-25), so a bare `Install("")` leaves the fixtures uncreated and the `demofixture`, `x509` and `wallet` checks fail on an instance where nothing is wrong. A client bundle must be built (`cd ui && npm run build`) **before `ci-throwaway.sh up`**, which copies `ui/dist` into the throwaway and mounts it read-only; building it after `up` reaches nothing, and the `shell` and `deeplink` checks then fail for the same reason.
- Verify totals with the `%UnitTest_Result` SQL probe before claiming green; the MCP envelope truncates.
- Tear down the throwaway only if this session's transcript names its own `up` (Rule 24).

**Rule 19 mutations** — one per AC, each applied on the slot-B throwaway `ocupilot-b-ci`, recompiled with `$System.OBJ.LoadDir` plus `$System.OBJ.CompilePackage("OcuPilot","ck-d")` so every subclass's inherited copy was rebuilt, observed, reverted, and the tree confirmed byte-identical by checksum and by `git status --short` / `git diff --stat`. Run numbers are `^UnitTest.Result` indexes on that container:

- AC1, applications and roles -- mutation: `Uninstall`'s roster-role loop takes `Set tSC = $$$OK` in place of `##class(Security.Roles).Delete(tRRole)` -> `Test.WebApp.TestUninstallRemovesBothApplicationsTheRoleAndTheDirectory` red on "the shell role is gone" and "and so is the readiness role" (run 19).
- AC1, admin resource / role / audit triples / database -- mutation: `Uninstall` takes `Set tSC = $$$OK` in place of `##class(Security.Roles).Delete(tNames("adminRole"))` -> `Test.Installer.TestUninstallLeavesNoResidue` red on "the role is gone" (run 12).
- AC1, the scheduled task -- mutation: `Fixture.RemoveOne`'s task branch takes `Set tDelSC = $$$OK` in place of `##class(%SYS.Task).%DeleteId(tIds(tI))` -> `Test.UninstallResidue.TestUninstallRemovesARealScheduledTaskFixture` red on "the scheduled task is gone from %SYS.Task after uninstall" (run 13).
- AC1 ∩ AC2, the orphaned role -- mutation: the roster-role loop's guard restored to `If '$Data(tRemovedKeys(tRKey)) Continue` -> `Test.UninstallResidue.TestUninstallRemovesAMatchingRoleWhoseApplicationIsAlreadyGone` red on "the orphaned matching role is removed", and the `roledapplication` row of `TestUninstallCompletesWithOneTargetAlreadyAbsent` red with it (run 14).
- AC2, per-target absence -- mutation: the SSL configuration's `##class(Security.SSLConfigs).Exists` guard in `Uninstall` replaced by `If 1` -> `Test.UninstallResidue.TestUninstallCompletesWithOneTargetAlreadyAbsent` red on the `sslconfig` row alone, carrying `ERROR #979: SSL configuration OcuPilotProviderProbe does not exist`; every other row stayed green (run 15).
- AC3 -- mutation: `Uninstall` gains `Do ##class(%SYS.Audit).Delete(.tMutNum, "2000-01-01 00:00:00", "2999-12-31 23:59:59")` after its event-registration deletes -> `Test.UninstallSurvival.TestAnEmittedRowOutlivesItsRegistration` red on the row-survives assertion alone, with the registration-absent and auditing-enabled assertions green: the pair is what discriminates (run 18). `DELETE FROM %SYS.Audit` (SQLCODE -134) and `%SYS.Audit.%DeleteId` (ERROR #673) are both refused in `%SYS` by the instance itself, so the vendor's own date-range `Delete` is the only route that removes a row at all.
- AC (DW-94), the kept-application arm -- mutation: the whole `If '$Data(tRemovedKeys(tRKey)), ##class(Security.Applications).Exists(...) Continue` guard removed from the roster-role loop, so an adopted application's role is deleted with the rest -> `Test.Provenance.TestUninstallLeavesAKeptApplicationsPrivilegeFloorIntact` red on "and still carries the matching role it needs to answer at all", the other five methods green (run 8); green again on the reverted tree (run 11). This is the arm the footprint grant was conditioned on, and it is the mutation `Test/Provenance.cls:238-240` already names.
- AC4 -- mutation: `Install` takes `Set tSC = $$$OK` in place of `..EnsureApplications(...)` -> `Test.UninstallSurvival.TestUninstallThenInstallRestoresTheProfileAndServes` red (run 21). The red lands on the install rather than on the fingerprint comparison, because `Install`'s own `AssertApplications` catches the incomplete install first. **The `StateFingerprint` equality itself was not reddened by any uniform change to `Install`**: both readings come from the same guard-then-act path against the same freshly-uninstalled state, so a uniform change moves them together. It is falsifiable only by an asymmetric change -- an uninstall that removes what install does not restore -- and the one tried, `Uninstall` skipping the application delete, left it green (run 20), because install recognises and repairs an application already sitting at its own roster path. The equality stands as an idempotency regression guard rather than as a mutation-falsified assertion; the loopback half of the same test is what pins "working".

Each mutation: apply, observe red, revert, and confirm `git status --short` and `git diff --stat` are byte-identical to before.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** Closed the one residue in `Uninstall`'s roster-role loop -- a roster-declared matching
role is now kept only while an application still sits at that key's roster path, so a role whose
application another hand removed no longer survives, while DW-94's kept-application floor is
untouched. Added the two test classes that pin AC1's uncovered targets, AC2's per-target absence,
AC3's survival pair and AC4's symmetry, and recorded a Rule 19 mutation for every AC including the
keep arm the footprint grant was conditioned on.

**Files.**

- `src/OcuPilot/Install/Installer.cls` -- the granted edit, `Uninstall`'s roster-role loop only:
  the guard gains a `Security.Applications.Exists` conjunct, and the comment states both arms.
- `src/OcuPilot/Test/UninstallResidue.cls` -- new; the task-fixture leg, the five-row
  already-absent table, and the orphaned-role leg.
- `src/OcuPilot/Test/UninstallSurvival.cls` -- new; the AC3 registration/row pair and the AC4
  fingerprint-plus-loopback symmetry leg.
- `_bmad-output/implementation-artifacts/spec-13-1-the-uninstall-hook.md` -- `## Verification`
  rewritten as observed, two wrong commands corrected at origin, triage log and `deferred` list.

**Review.** 52 findings across four layers: 0 high, 4 medium, 23 low, 13 false/rejected-on-
refutation. 7 patched (1 medium, 6 low), 9 deferred entries recorded in frontmatter, 12 rejected
with reasons in the triage log. The medium patch was the missing Rule 19 mutation for the DW-94
keep arm; the others corrected assertion messages that discarded their actuals, a missing trap in
`RowCount`, a transcribed database-directory literal, an arming guard that checked one of two
variables while its header claimed both, an overstated loopback rationale, and a wrong
bundle-build ordering in the Verification list. Rejections that matter: the "lost provenance gate"
findings are spec-bound -- acceptance criterion 2 states the name-based rule verbatim -- and AC3's
coarse mutation is unavoidable because the instance refuses every scoped `%SYS.Audit` delete.

**Verification (independent of the implementation subagent's report, all on slot B).**

- `uv run scripts/check-objectscript.py` clean, 496 files, 21 rules, 0 problems;
  `bash scripts/lint-docs.sh` 0 issues.
- Throwaway `ocupilot-b-ci` (52777/1976) brought up by this stage; every destructive class ran
  there, one class per call, never on `ocupilot-slot-b`.
- After patches, re-run one class per call and confirmed against `%UnitTest_Result` by
  latest-run SQL probe: `UninstallResidue` 3/3, `UninstallSurvival` 2/2, `UninstallGuard` 3/3,
  `Installer` 27/27, `WebApp` 25/25, `Provenance` 6/6, `InstallLock` 6/6 -- 72 methods, 0 failures.
- AC6 production cycle on the throwaway: `Uninstall("",1)` then
  `StartPath(1, "/opt/ocupilot/ui/dist/ocupilot-ui/browser")`, then `scripts/smoke.sh` --
  executed=45 passed=45 failed=0 pending=2 skipped=0.
- Matrix Test Audit: all seven rows covered by a test that ran and passed. The adopted-application
  row is covered by `Test.Provenance.TestUninstallLeavesAKeptApplicationsPrivilegeFloorIntact`,
  which asserts both the application and its `MatchRoles` survive -- green on the delivered tree,
  and red under the keep-arm mutation, which is what proves the DW-94 distinction still fires.
- AC3 is settled empirically and the answer is the safe one: an audit row emitted under OcuPilot's
  triple survives `Security.Events.Delete` of its registration. No HIGH defect, no intent gap.

**Residual risk.** The `StateFingerprint` equality is green but has never been observed red
(deferred #2); the unconfirmed dry-run preview now under-reports the orphan roles the confirmed
run removes, and its fix lies outside this story's granted footprint (deferred #1). Neither
affects the delivered behavior: no AD-21 privilege floor is stripped in any state reached.
