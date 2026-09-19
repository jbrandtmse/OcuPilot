---
title: 'Story 13.1: The uninstall hook'
type: 'feature'
created: '2026-09-19'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred: []
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
- Given an OcuPilot audit row emitted under the probe triple, when `Uninstall("probe",1)` completes, then the triple's registration is absent, the row is still readable from `%SYS.Audit`, and instance auditing is still enabled.
- Given an application at a roster path with no provenance row, when uninstall completes, then that application and its matching role both survive and the adoption is reported.
- Given `Uninstall("probe",1)` followed by `Install("probe")`, when both have returned OK, then `StateFingerprint` equals its pre-uninstall value and the probe API answers over loopback.
- Given a production `Uninstall("",1)` then `Install("")` on a throwaway, when both have returned OK, then `scripts/smoke.sh` reports a non-zero executed-check count with no failure.

## Spec Change Log

- 2026-09-19, lead spec gate: two planner claims corrected at origin. The orphaned-role residue was described as firing DW-244's `reopen_if`; DW-244's probe is a *clean* `Uninstall('probe')` leaving a `Probe*` role, which this code does not do, so the residue is a distinct in-story defect and DW-244 stays terminal and owned by `1-18-epic-1-burn-down`. The consequent task to reopen and close DW-244 in the ledger is removed: this story writes no ledger entry.

## Review Triage Log

## Design Notes

**Governing ADs.** AD-17 (one installer class, two entry points, idempotent, guard-then-act, roster generated from one source), AD-9 (protected database, guarding resource, privileged routine application, and the order that takes them down without orphaning), AD-21 (the unauthenticated applications' purpose-built application roles, created *and removed* by the installer; the both-directions invariant), AD-25 (demo fixture opt-in, removed by uninstall, a pre-existing `/csp/myapp` never touched), AD-45 (readiness is the third application, created and removed by the installer; the smoke path is the definition of "working"), AD-15 and AD-46 (the audit database's rows are the instance's record — registration is OcuPilot's, the rows are not), AD-38 (a production uninstall re-arms the container start path's first-install behavior, including `EnsureUnexpired`), AD-10 (removing OcuPilot's own applications, resource, role or database is an operator act through the install path and is never an agent tool), AD-32 (the installer's named SSL configuration, which uninstall removes), AD-16 (`%SYS` by explicit save and restore), AD-37 (OcuPilot deletes what OcuPilot created, and nothing else). Conventions rows *IRIS security objects* (a `%DB_*` resource's implicit role is IRIS-managed and vanishes with the resource — nothing deletes it explicitly, and nothing should) and *Tests*.

**This is gap-closure, not a build.** Per-AC state of the Epic 1 implementation: AC1 is met for the three applications, both matching roles, the admin resource and role, every roster audit triple, the database, its `%DB_*` resource, the mapping, the privileged routine application, the bundle directory and the SSL configuration — pinned by `Test/WebApp.cls:975` and `Test/Installer.cls:630`, with **no recorded mutation**. AC1 is unpinned for a real scheduled task and for five of the six demo-fixture kinds. AC2 is met and pinned at the profile level (`Test/Installer.cls:618`) and unpinned per target. AC3 is entirely unpinned. AC4 is exercised ~22 times a suite run as harness lifecycle but never asserted as *working*.

**"The scheduled tasks" in AC1 is satisfied by the fixture path.** The installer creates no `%SYS.Task` of its own (`grep %SYS.Task src/OcuPilot/Install/Installer.cls` → one comment, `:3549`); the only task is the demo fixture's `OcuPilot.Install.DemoTask`, removed through the fixture inventory. The clause is therefore vacuous outside demo mode today, which is why this story pins the fixture task rather than inventing an installer task. A later epic that adds a retention task (Operational Envelope, 7.2) must add it to the same roster-driven path so this hook removes it without an edit of its own.

**Whether an emitted audit row survives its registration's deletion is an open empirical question** *(inference: `Security.Events.Delete`'s body is not in the `irissys/` export, so the cascade cannot be settled statically)*. The AC3 pin is what settles it. If the rows do not survive, that is a HIGH defect against AD-15/AD-46 and an `intent gap` for the lead — not something to soften in the test.

**Footprint (Epic 5 also holds `src/OcuPilot/Install/**` and `src/OcuPilot/Test/**`).** Both new test classes are files this story creates, so they are ours. **One edit to an existing file is required and is a Clarification for the lead:** `src/OcuPilot/Install/Installer.cls`, method `Uninstall`, the roster-role loop at `:3657-3665` only. It cannot live in a new class: the loop runs inside a ~350-line method that holds the `%SYS` namespace switch, the profile install lock, the ordered teardown and the `tRemovedKeys` array built by the immediately preceding application-delete loop — a subclass override would have to reproduce the whole method, and `Uninstall` is `AD-17`'s single entry point, not a seam. **No edit to `src/OcuPilot/Install/Smoke.cls` is planned**; AC4's "working" is proved by `scripts/smoke.sh` against a throwaway (AD-45's one path) rather than by a new smoke check, which would have needed `Smoke.Run:212`.

**Integration ACs (Rule 1).** This story introduces no service, module or shared component — it closes a residue in an existing method and adds test classes. No consumer exists in this story. **Consumes:** `OcuPilot.Install.Installer` (`Uninstall`, `Install`, `StateFingerprint`, `Names`), `OcuPilot.Install.Roster`, `OcuPilot.Install.Fixture`, `OcuPilot.Kernel.Audit.Event`, `OcuPilot.Kernel.State.Base`, `scripts/ci-throwaway.sh`, `scripts/ci-unit-test.sh`, `scripts/smoke.sh`. **Consumed-by:** Story 13.2 (its stock-image CI suite runs both new classes and counts them toward the coverage floor), Story 13.3 (its dry-run archive must install on a fresh instance, which the symmetry pin is the standing evidence for).

## Verification

**Commands** (slot B throughout; every IRIS MCP call carries `server: "ocupilot-slot-b"`):

- `uv run scripts/check-objectscript.py src/OcuPilot/Install/Installer.cls src/OcuPilot/Test/UninstallResidue.cls src/OcuPilot/Test/UninstallSurvival.cls` -- expected: clean, 21 rules.
- Compile the three classes through the IRIS MCP tools against `ocupilot-slot-b` -- expected: no errors. Recompile the whole `OcuPilot.Install` and `OcuPilot.Test` packages before reading any mutation result (an inherited method keeps a per-subclass compiled copy).
- `bash scripts/ci-throwaway.sh --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci --web 52777 --super 1976 --container ocupilot-b-ci` -- expected: the throwaway comes up installed. **Every destructive class below runs there, never on `ocupilot-slot-b`.**
- `sh scripts/ci-unit-test.sh --container ocupilot-b-ci --class OcuPilot.Test.UninstallResidue` -- expected: all methods pass, `PROBEAPPS` clean. **One class per call; send the next only once this run has landed in `%UnitTest_Result` (Rule 18 (3)).**
- `sh scripts/ci-unit-test.sh --container ocupilot-b-ci --class OcuPilot.Test.UninstallSurvival` -- same, as a separate call.
- Regression, one class per call, in this order: `OcuPilot.Test.UninstallGuard`, `OcuPilot.Test.Installer`, `OcuPilot.Test.WebApp`, `OcuPilot.Test.Provenance`, `OcuPilot.Test.InstallLock` -- expected: unchanged. `Provenance` and `WebApp` are the two the role-loop edit can move.
- Production cycle, on the throwaway only: `docker exec ocupilot-b-ci iris session iris -U HSCUSTOM` running `Uninstall("",1)` then `Install("")`, then `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` -- expected: smoke reports a non-zero executed-check count and no failure. Zero executed checks is a failure, never a pass.
- Verify totals with the `%UnitTest_Result` SQL probe before claiming green; the MCP envelope truncates.
- Tear down the throwaway only if this session's transcript names its own `up` (Rule 24).

**Rule 19 mutations** — one per AC. Each line below names the mutation to apply; the implement stage applies it, observes red, reverts, and rewrites the line as `mutation: <what was changed> -> <which test went red>` with the run it was observed in. The four already-met ACs get their missing lines in the same pass, since the mutation for an existing pinning test is this story's deliverable:

- AC1, applications and roles -- mutation: delete one of the four deletes in `Uninstall`'s application/role block -> expected red: `Test.WebApp.TestUninstallRemovesBothApplicationsTheRoleAndTheDirectory`.
- AC1, admin resource / role / audit triples / database -- mutation: skip the admin-role delete at `:3684` -> expected red: `Test.Installer.TestUninstallLeavesNoResidue`.
- AC1, the scheduled task -- mutation: make `Fixture.RemoveOne`'s task branch skip `%DeleteId` -> expected red: `Test.UninstallResidue`'s task leg.
- AC1 ∩ AC2, the orphaned role -- mutation: restore `If '$Data(tRemovedKeys(tRKey)) Continue` -> expected red: `Test.UninstallResidue`'s orphaned-role leg.
- AC2, per-target absence -- mutation: drop one `Exists` guard so an absent target errors -> expected red: that target's row in `Test.UninstallResidue`'s table-driven leg.
- AC3 -- mutation: add a delete of `%SYS.Audit` rows for OcuPilot's source and type to `Uninstall` -> expected red: `Test.UninstallSurvival`'s row-survives assertion, with the registration-absent assertion staying green — the pair is what discriminates.
- AC4 -- mutation: skip one ensure step in `Install` so the reinstall is incomplete -> expected red: `Test.UninstallSurvival`'s `StateFingerprint` equality.

Each mutation: apply, observe red, revert, and confirm `git status --short` and `git diff --stat` are byte-identical to before.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
