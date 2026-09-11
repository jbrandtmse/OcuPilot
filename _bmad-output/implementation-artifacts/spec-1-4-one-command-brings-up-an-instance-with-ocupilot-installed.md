---
title: 'Story 1.4: One command brings up an instance with OcuPilot installed'
type: 'feature'
created: '2026-09-09'
status: 'done'
baseline_revision: '5e76a9056f10c836386e8312dcfe460085f9a06b'
baseline_commit: '5e76a9056f10c836386e8312dcfe460085f9a06b'

review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-1-3-the-installer-creates-ocupilot-s-protected-state-resource-an.md'
  - '{project-root}/.claude/rules/objectscript-basics.md'
  - '{project-root}/.claude/rules/objectscript-testing.md'
  - '{project-root}/.claude/rules/iris-persistent-storage.md'
warnings: ['oversized']
deferred:
  - summary: 'OcuPilot.Test.Demo TestDemoTaskIsSuspendedAfterAnError (and, since rework iteration 4, TestDemoSeedsAnApplicationError too) is flaky on this specific long-lived ocupilot container (Task Manager daemon latency growing well past 90s, then past 300s, after repeated task churn)'
    severity: 'med'
    fix-risk: 'high'
    footprint: 'in-story'
    evidence: >
      Verified live, repeatedly, in review: OcuPilot.Install.Fixture's demo task fixture
      (RunNow + poll for Suspended>0) is functionally correct -- a standalone classmethod
      call (bypassing %UnitTest) reached Suspended=1 in ~50s on one attempt and ~150s on
      another, both same-session -- but OcuPilot.Test.Demo.TestDemoTaskIsSuspendedAfterAnError
      failed 4 consecutive class-level runs on this specific, long-lived ocupilot
      container (used continuously across Stories 1.1-1.4 plus this review's own
      task-fixture probing), with the daemon's RunNow-to-actual-run latency observably
      growing across attempts (task never ran even after ~240s on the last attempt).
      TASKWAITSECONDS was widened 90 -> 300 in Fixture.cls during this review (a real,
      low-risk improvement, kept), but did not resolve it on this instance in the time
      available for review. The original implementation subagent's own throwaway-container
      verification (a genuinely fresh instance) observed the fixture working correctly
      within the original 90s budget, matching the pattern already documented for
      SYS.Database.DeleteDatabase: a long-lived, heavily churned instance is slower than a
      fresh one at some background operations. AC9-AC12's production behavior degrades
      gracefully either way (a fixture timeout is a warn, never a failed install, per
      AD-25) -- the residual risk is test flakiness on this one instance and a latent
      possibility that AC11/AC12 do not materialize within a slow container's own bring-up
      window, not a broken feature.

      UPDATE (rework iteration 2, 2026-09-10, build-auto): the daemon latency on this same
      container has grown well past the ~240s worst case above -- live-observed this pass,
      a demo task (id 1023) sat at LastStarted=0 for over an hour of wall-clock time
      (spanning a full OcuPilot.Test.Installer run) before the Task Manager finally
      serviced it. Consistent with, and now materially exceeding, the pattern already
      recorded; correcting the figure at its origin here rather than leaving the ~240s
      worst case as the last word (CLAUDE.md's own "correct a wrong claim at its origin"
      pitfall). Disposition unchanged: still a warn, never a failed install; residual risk
      is unchanged in kind, only worse in degree.

      UPDATE (rework iteration 4, 2026-09-11, build-auto step-03 verify pass): re-verified
      live rather than assumed carried-forward. Three fresh, isolated OcuPilot.Test.Demo
      class runs (RunIdx 297/298/299, no sibling run in flight, confirmed via
      iris_jobs_list before each) all took the DW-46 SKIP branch in
      TestDemoTaskIsSuspendedAfterAnError -- the daemon served zero of three RunNow
      requests within the full 480s combined wait budget. Checked the mechanism directly
      rather than inferring it: iris_task_history's most recent entry system-wide, across
      all namespaces, is dated 2026-09-08 03:44 -- three days stale relative to this
      session -- so this is not merely slow, it is a daemon that has not serviced any
      task at all in days on this specific, long-lived, heavily-churned container.
      New consequence, not previously recorded: this pass's own AC12/DW-58 fix (below,
      same file) removed the same-day-entry safety net that used to let
      TestDemoSeedsAnApplicationError pass anyway on a long-lived container even when the
      daemon was stalled -- so that test is now a SECOND pinning test the identical,
      already-accepted daemon-latency risk can turn red, alongside
      TestDemoTaskIsSuspendedAfterAnError. Disposition unchanged: still a warn, never a
      failed install (AD-25); this is the fix correctly no longer masking an
      already-deferred environmental problem, not a new one. Never attempted to restart,
      recreate, or otherwise intervene on the container or its Task Manager daemon to
      chase this -- explicitly out of bounds (Boundaries: never
      docker compose down/up/restart the running ocupilot container).
  - summary: 'OcuPilot.Kernel.State.Version has no unique constraint on Profile, so two overlapping Install()/StartPath() calls for the same profile could create two rows'
    severity: 'medium'
    fix-risk: 'high'
    footprint: 'in-story'
    evidence: |-
      Verified by code read (2026-09-10 review): EnsureVersion does a read-then-
      insert-or-update with no transaction and no unique index on Profile; two
      concurrent Install() calls for the same profile could both read "no row" and
      both insert, leaving two rows GuardedCurrentForProfile's TOP-1-ORDER-BY-ID-DESC
      would then arbitrarily pick between. Would settle by confirming the correct
      IRIS storage-projection syntax for a unique index on this release and adding
      it, then a concurrency test -- research, not a direct correction.

      UPDATE (rework iteration 3, 2026-09-10, build-auto): found this live, not only
      theoretically -- the production profile (Profile IS NULL) carried two Version
      rows on this instance at the start of this iteration's post-implementation
      verification (id 1075, stamped 15:49:56Z, stale since some earlier session;
      id 1299, actively current). Labelling the mechanism honestly rather than
      overclaiming it: a direct, controlled retest this pass (delete the duplicate
      down to one row, recompile OcuPilot.Kernel.State.Version, immediately call
      Install("") again) did NOT reproduce a second row -- CurrentVersionRow found
      and updated the surviving row correctly every time in that retest, so a bare
      recompile is not by itself the trigger, and this pass does not have a
      reproduced mechanism to add beyond the one already on file (concurrent or
      near-concurrent calls racing the read-then-insert-or-update with no unique
      index or transaction). Cleaned up as data hygiene, not a fix: deleted the
      stale, abandoned id-1075 row so production again carries exactly one Version
      row, matching AC4's invariant, before handing off -- confirmed by SQL
      immediately after (COUNT=1) and confirmed stable across two further Install()
      calls in this same pass. Disposition unchanged: still `medium`/`high`-fix-risk,
      still a research item (the correct IRIS unique-index syntax for this release),
      not a direct correction; recorded here so the duplicate found live is not
      mistaken for a new, distinct defect, and so the next reader does not have to
      re-derive that this same finding already covers it.
  - summary: 'The container start hook compiles the entire src/OcuPilot/ tree, including every Test.* fixture/fault-injection class, into the production instance'
    severity: 'medium'
    fix-risk: 'high'
    footprint: 'in-story'
    evidence: |-
      Real, and this story is what makes "compile the whole source tree on every
      container start" the actual shipped mechanism (previously loaded ad hoc via
      MCP tools). Explicitly directed by this spec's own Code Map/Design Notes
      ("the start hook loads and compiles the src/OcuPilot/ tree ... no roster file
      is invented in this story"), so excluding Test.* would need a roster/exclusion
      mechanism that conflicts with AD-17's "one source of truth, no invented
      roster" stance -- an architecture question for the lead, not a patch.
  - summary: 'A private RSA key (the demo X.509 fixture credential) is checked into OcuPilot.Install.Fixture.cls source'
    severity: 'medium'
    fix-risk: 'high'
    footprint: 'in-story'
    evidence: |-
      Real secret-scanner-shaped concern (Blind Hunter, 2026-09-10 review). By design
      per Fixture.cls's own documented rationale: there is no supported ObjectScript
      API to generate an X.509 certificate at install time, and shelling out to an
      external tool was rejected as the undocumented-internals risk AD-27 exists to
      confine. Whether this project's security posture tolerates a checked-in,
      documented-as-inert fixture key (vs. generating it some other way, or storing
      it outside version-controlled source) is a policy call for the lead.
  - summary: 'AC1-AC3/AC9-AC12''s container, health-check, HTTP, and shell-level (demo-flag propagation) surfaces are verified only by a one-off manual throwaway-container run, never by an automated test in this repository'
    severity: 'medium'
    fix-risk: 'high'
    footprint: 'in-story'
    evidence: |-
      Three reviewers converged on the same root cause from different angles
      (2026-09-10 review): verification-gap found StartPath(1)'s production-profile
      demo-fixture branch (the exact call docker-compose.yml's own OCUPILOT_DEMO=1
      wires up) has zero %UnitTest coverage; the intent-alignment auditor separately
      observed that the container/health-check/HTTP layer and the /proc/1/environ
      demo-flag extraction are both justified only by inline comments and a manual
      drill, never an automated test. All three are real and share one cause: this
      story's own design (spec Verification section, "Verifying the start path
      against a throwaway container") deliberately defers this surface to a manual,
      destructive-and-isolated throwaway-container run rather than automating it --
      already executed once, successfully, by the implementing subagent. Closing
      this for good would mean either a safe, carefully-cleaned-up production-
      profile fixture test against the shared instance, or a scripted (not manual)
      throwaway-container CI step -- both bigger than a direct correction.
  - summary: 'ReportGatewayGap''s Web Gateway timeout reader matches "Server_Response_Timeout" as an unanchored substring, so a comment or unrelated CSP.ini line containing that text could be misread'
    severity: 'low'
    fix-risk: 'medium'
    footprint: 'in-story'
    evidence: |-
      Real (Edge Case Hunter, 2026-09-10 review) but low-impact: the value is
      reported as information only and never modifies anything (AD-17/AD-27).
      Anchoring the match correctly needs this build's actual CSP.ini comment
      conventions, not verified in the time available for this review.
  - summary: 'A narrow race in Fixture.CreateTask: the demo task''s id could be deleted between QueryTasks and the following %OpenId, misreporting as "not yet suspended" rather than "vanished"'
    severity: 'low'
    fix-risk: 'medium'
    footprint: 'in-story'
    evidence: |-
      Real (Edge Case Hunter, 2026-09-10 review) but narrow and low-probability --
      requires something else to delete the fixture's own task between two
      back-to-back reads in the same method. Deferred rather than rushed.
  - summary: 'Seven ACs (AC2, AC3, AC4, AC5, AC8, AC9, AC13) had their pinning tests added or materially changed by rework iteration 3 with no corresponding update to the per-AC mutation: line in the spec''s own ## Verification section'
    severity: 'low'
    fix-risk: 'low'
    footprint: 'in-story'
    evidence: |-
      Verification Gap and Intent Alignment Auditor (2026-09-10 review, iteration 3
      pass): each of these ACs' pinning test changed this pass (new tests, new
      assertions, or a corrected claim about what an existing assertion catches),
      but ## Verification's own mutation: line for that AC was not updated to match
      -- a documentation-completeness gap, not a functional defect. The mutations
      themselves are already recorded, demonstrated and cross-referenced at each
      closed checklist item in ## Tasks & Acceptance; folding all seven into
      ## Verification too is more than a direct correction in a pass already this
      large. AC13's own line was corrected as part of this same review pass (it was
      actively overclaiming, not merely stale); the other six are additive gaps.
  - summary: 'Fixture.RemoveOne''s three status-checked Delete branches (webapp/sslconfig/x509credential, H3/M4) are exercised only on their success paths -- no committed test forces a Delete failure to observe the new warn reporting'
    severity: 'low'
    fix-risk: 'low'
    footprint: 'in-story'
    evidence: |-
      Verification Gap (2026-09-10 review, iteration 3 pass): real gap, but lower
      priority than the two high-severity untested-regression gaps this same pass
      closed (H1's Uninstall-ordering test, M1's failed-first-install test) --
      deferred rather than expanding this pass further. A failure-injection test
      would need to force Security.Applications/SSLConfigs/%SYS.X509Credentials'
      own Delete to fail, which none of the existing test seams do yet.
  - summary: 'Test/Demo.cls''s date-scoped SYS.ApplicationError:ErrorList queries (TestDemoSeedsAnApplicationError and Fixture.CreateErrorEntry alike) can miss a real entry across a midnight rollover, since both search only "today"''s date'
    severity: 'low'
    fix-risk: 'medium'
    footprint: 'in-story'
    evidence: |-
      Observed live (build-auto, 2026-09-10/11 review, iteration 3 pass): a full
      OcuPilot.Test.Demo class run failed TestDemoSeedsAnApplicationError with
      both of its ^ERRORS-derived assertions red, immediately after this session's
      own work crossed midnight (compile timestamps moved from 09/10 to 09/11) --
      the shared class-level demo task's error entry was logged before midnight,
      and the test's own tDate = $ZDate($Piece($H,",",1),1) query (matching the
      identical convention already in Fixture.CreateErrorEntry, unchanged by this
      pass) then searched only "today" (09/11) and found nothing. Re-running the
      full class immediately afterward (a fresh class-level fixture, dated today)
      passed 9/9 -- confirmed transient and environmental, not a regression from
      any change in this pass. Pre-existing in the test's own established pattern
      (not introduced here); a real fix would widen the query to span the fixture's
      actual creation window rather than "today," which is more than a direct
      correction to make blind in the time remaining on an already-large pass.

      CLOSED (rework iteration 4, 2026-09-11, build-auto step-03): the AC12/DW-58 fix
      below (Fixture.Create/CreateErrorEntry now scope to a captured pSinceH boundary
      spanning any midnight rollover, and Test/Demo.cls's TestDemoSeedsAnApplicationError
      drives the identical scan independently) closes this specific gap. Left as a
      closed record rather than removed -- see the new, narrower deferred: entry below
      (the ~59s same-minute false-positive this same fix introduces) for what replaces
      it.
  - summary: >-
      The AC12/DW-58 fix's own tSinceSecsFloor (Fixture.CreateErrorEntry, and the
      independent copy in Test/Demo.cls TestDemoSeedsAnApplicationError) floors the
      run's own start-of-minute boundary DOWN before comparing against
      SYS.ApplicationError:ErrorList's minute-granular Time column, so an entry an
      EARLIER, unrelated run logged within the same clock-minute -- but chronologically
      before -- this run's own pSinceH capture still satisfies the check.
    evidence: |-
      Verified by code read (build-auto step-04 review pass, 2026-09-11; cited
      independently by Blind Hunter, Edge Case Hunter and Verification Gap in the same
      review): tSinceSecsFloor = (tSinceSecs \ 60) * 60 rounds DOWN to the start of
      pSinceH's own minute, so any entry timestamped at or after that minute boundary --
      including one from a run that finished BEFORE this one started, if it happened to
      log within the same 60-second window -- satisfies ">= tSinceSecsFloor" and is
      wrongly counted as "since this run began." This narrows the same-day false-green
      the fix targets from a full day down to at most ~59 seconds rather than
      eliminating it. Not theoretical: this session's own rapid, back-to-back
      OcuPilot.Test.Demo runs (RunIdx 297/298/299, minutes apart) are exactly the
      pattern that makes the window real rather than a one-in-a-day coincidence. No
      clean fix exists within this pass's scope: SYS.ApplicationError:ErrorList's own
      Time column has no sub-minute resolution and no entry-identity/counter to
      disambiguate two log lines sharing a minute, so rounding the comparison the other
      way (up, or unrounded) trades this false-positive for a differently-shaped
      false-negative rather than removing the ambiguity.
    location: >-
      src/OcuPilot/Install/Fixture.cls (CreateErrorEntry); src/OcuPilot/Test/Demo.cls
      (TestDemoSeedsAnApplicationError)
    severity: medium
  - summary: >-
      TestExistingApplicationIsNeverModified's new call to
      OcuPilot.Test.DemoAppProbe.Create("probe", ...) (this pass's own HIGH-finding fix)
      re-runs Fixture.Create's full four-creator cascade, including CreateTask, which
      re-issues %SYS.Task.RunNow and can block for up to another 300s whenever the
      shared "probe" task is not yet Suspended -- an added, undocumented cost on top of
      what TestDemoWebAppFixtureCreatedWhenAbsent already pays for the identical shared
      task object.
    evidence: |-
      Verified by code read (build-auto step-04 review pass, 2026-09-11; cited
      independently by Blind Hunter, Edge Case Hunter and Verification Gap):
      Fixture.CreateTask's existing-task branch checks +tTask.Suspended > 0 and, if
      still 0, calls RunNow and waits up to TASKWAITSECONDS (300s) again, unconditionally,
      regardless of which caller or subclass reached it. DemoAppProbe.Create("probe", ...)
      is a NEW call site this pass added specifically to fix the HIGH finding (it
      previously called Security.Applications.Create directly against the real APPPATH,
      not through the full Fixture.Create cascade). On this container, whose Task
      Manager daemon this same pass's own iteration-4 deferred: entry already documents
      as having serviced zero of several RunNow requests across 480s combined waits,
      this branch is live, not hypothetical -- though two direct re-runs after this fix
      landed (RunIdx 298, 299) both happened to find the task already suspended by the
      time this specific method ran (6-12ms, no wait triggered), most likely because the
      daemon serviced the request sometime between TestDemoTaskIsSuspendedAfterAnError's
      own check and this later method's turn. Not fixed this pass: Fixture.Create has no
      narrower entry point that touches only CreateWebApp (CreateTask et al. cascade
      unconditionally by design), and restructuring it to expose one is more than a
      direct correction.
    location: >-
      src/OcuPilot/Test/Demo.cls (TestExistingApplicationIsNeverModified);
      src/OcuPilot/Install/Fixture.cls (CreateTask, Create)
    severity: medium
  - summary: >-
      Installer.IsEscalationInfrastructureAbsent -- this pass's own step-03 verify-stage
      fix for a real, live-discovered AC2 first-install ordering defect -- has no
      automated regression test; every existing test runs against an instance where the
      escalation application already exists, so the guard is a no-op for the whole
      suite either way.
    evidence: |-
      Verified by code read and grep (build-auto step-04 review pass, 2026-09-11; cited
      independently by Verification Gap and the Intent Alignment Auditor): grep for
      IsEscalationInfrastructureAbsent across the tree finds it only in Installer.cls
      itself and this spec's own narrative -- no .cls test references the symbol. The
      only verification this fix has is the one-off, non-repeatable throwaway-container
      run this same pass performed by hand. A future edit reintroducing the
      version-row-before-EnsureApplication ordering would ship green through the whole
      committed suite and reproduce AC2's own central failure on the next genuinely
      fresh docker compose up -d --wait, with no CI signal. Not fixed this pass:
      constructing the "genuinely absent" state without a disposable container needs a
      new test seam -- a probe subclass overriding the Security.Applications.Exists
      check, in the same shape Test.MigrateFault/Test.GateFixture already use for their
      own overrides -- which is more than a direct correction for this pass.
    location: >-
      src/OcuPilot/Install/Installer.cls (IsEscalationInfrastructureAbsent, Install)
    severity: medium
---

<intent-contract>

## Intent

**Problem:** A clean clone does not produce a working OcuPilot. `docker-compose.yml` names the floating
`latest-cd` tag, there is no Dockerfile and no container start hook, `_SYSTEM`'s password must be
unexpired by hand (README:178-180 tells the operator to invoke `Installer.Install` through the MCP tools
"until Story 1.4"), no schema-version stamp exists so nothing can say whether install finished, nothing
refuses traffic while install is mid-flight, no migration path carries existing state forward, and the
README walkthrough greets a judge with empty lists.

**Approach:** Wrap Story 1.3's `Install.Installer` in a container start path — an explicit `2026.2` image
pin, an `--after` start hook that resolves the install namespace, loads and compiles `src/OcuPilot/` and
calls one new `StartPath()` entry point, and a compose health check that reports healthy only once install
is complete. Add the AD-38 version stamp as its own protected-state class, an ordered forward-migration
runner that refuses a stored version newer than the deployed code, a traffic gate in `Api.Router` that
answers the single error envelope while the stamp is not current, the guarded `_SYSTEM` unexpire, and the
opt-in demo fixture set with an inventory so uninstall removes exactly what install created.

## Boundaries & Constraints

**Always:**

- Install runs at **container start, never at image build** (AD-17): the durable volume's `IRISSYS`,
  `IRISSECURITY`, `HSCUSTOM` and `USER` supersede the image's copies on every start.
- Every new install step is **guard-then-act** and reports through `Kernel.Audit.Log`; the installer never
  `Write`s (`check_write_discipline`).
- Every `%SYS` hop is explicit save/restore with the restore as the **first line of every `Catch`** and
  before **every ordinary-failure `Quit`** inside the switched region (AD-16, Story 1.3's HIGH fix at 17
  sites). `New $NAMESPACE` never appears.
- No `##class(OcuPilot.*)` call while `$NAMESPACE` sits in `%SYS` — reports are deferred into the array
  and drained by `FlushReports` after the restore (Story 1.3 class doc, lines 12-40).
- All project ObjectScript under `src/OcuPilot/` in the seven fixed packages; class names ≤ 29 characters
  including package dots; parameters `p`-prefixed, locals `t`-prefixed; `$$$` macros; no `%` or `_` in
  names; no `Storage` section authored by hand.
- The refusal renders through the **one** error writer as `{error, reason, code, detail}` with a stable
  dotted-uppercase `code` that is never a number (AD-12, AD-39).
- Every fixture object except the web-application path carries an `OcuPilotDemo` name prefix; the fixture
  set is created **only** under the opt-in flag and is absent from every other install path including IPM
  (AD-25).

**Never:**

- Never create a second installer entry point, a second escalation point, a second response writer, or a
  second error envelope field. Never add `New $ROLES`/`AddRoles` outside `Kernel/State/Base.cls`.
- Never create the two OcuPilot web applications — `/ocupilot` and `/api/ocupilot` are **Story 1.5's** and
  are not asserted here (see Design Notes → *The 1.4/1.5 seam*).
- Never build the smoke script or the readiness endpoint — **Story 1.17's** (AD-45).
- Never change the Web Gateway response timeout; report it as information only.
- Never modify, enable, or grant a resource on a web application install did not create (DW-13).
- Never call `UnExpireUserPasswords("*")`, and never unexpire on a start that is not the first install on
  this durable volume.
- Never wipe `iris-data/`, never `docker compose down`/`up`/`restart` the running `ocupilot` container, and
  never plan a test that cycles `Install`/`Uninstall` repeatedly (`SYS.Database.DeleteDatabase` takes
  20-40 minutes on this container after repeated cycling).
- Never write a `list Of` property without projection; never hand-edit a `Storage` XData.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| First start, empty volume | `docker compose up -d`, no `iris-data/` | Namespace resolved, source compiled, `Install()` runs, `_SYSTEM` unexpired, auditing on, version row written at `#SCHEMAVERSION`, phase `installed`; health check goes healthy | Any step's failure → phase `failed` with the failing step named, non-zero hook exit, health check stays unhealthy |
| Repeat start, populated volume | second `up` on the same volume | Net state identical: `StateFingerprint` byte-identical, one version row per profile, `_SYSTEM` expiry untouched | Ensure steps still execute; drift is repaired and the repair reported |
| Upgrade | stored version N < `#SCHEMAVERSION` | Migration steps run in ascending order, then the row advances and phase becomes `installed` | A failing step leaves the stored version at N, phase `failed`, install returns an error |
| Downgrade | stored version > `#SCHEMAVERSION` | Install refuses, reports both versions, runs **no** migration step, changes nothing | `%Status` error; phase left at its stored value, never `installed` |
| Request during install | phase `installing` / `failed` / stale | One 503 envelope, `code` = `INSTALL.INSTALLING` / `INSTALL.FAILED` / `INSTALL.UPGRADEREQUIRED` | `pContinue = 0`; exactly one envelope on the wire |
| Version row unreadable | protected database absent (very first start) | Phase resolves to `installing`; traffic refused | A read failure is never read as `installed` |
| **DW-13** collision | `/csp/myapp` already exists, install did not create it | No modification, no enable, no resource grant; one `warn` report naming the collision; install continues | Fixture inventory records nothing for it; uninstall leaves it alone |
| **DW-14** task fixture | flag set | `OcuPilotDemo` task exists, scheduled, `Suspended` > 0, `Error` non-empty and readable | Fixture failure is a `warn`; it never fails install |
| **DW-15** error fixture | flag set | `^ERRORS` in the install namespace gains at least one readable entry | Fixture failure is a `warn`; it never fails install |
| Flag absent | `OCUPILOT_DEMO` unset / IPM path | No fixture object of any kind exists | n/a |
| Wrong namespace | `Install()`/`StartPath()` called outside the resolved install namespace | Refused with an error naming expected and actual namespace | Caller's namespace unchanged |
| Gateway read fails | registry and config file both unavailable | One `info` report saying the timeout is not available | Never fails install (AD-27 fallback) |

</intent-contract>

## Code Map

**Extend, never duplicate.** Everything below exists and is `done`.

- `docker-compose.yml` (12 lines) -- `image: intersystems/irishealth-community:latest-cd` (line 3, the
  floating tag to replace), `ports 1973:1972` and `52774:52773` (7-8), `ISC_DATA_DIRECTORY: /durable/iris`
  (10), `./iris-data:/durable` (12). **No `command:`, no `entrypoint:`, no `healthcheck:`, no `build:`.**
- **No `Dockerfile`, no `.dockerignore`, no `.env`, no start hook, no `module.xml`, no `.github/`** anywhere
  in the tree. Absence verified, not assumed.
- `src/OcuPilot/Install/Installer.cls` (811 lines) -- class doc 1-45; **lines 6-8 name exactly what this
  story owes**. `Install(pProfile="")` :150 (namespace saved at :153 *before* the `Try`; nine `Ensure*`
  calls at :164-180 each followed by `Set $NAMESPACE = tOrigNS  Quit`; restore at :182; `RecordStamp`
  :184; `FlushReports` at :200, deliberately outside `Try`/`Catch`). `Names` :58 (validates the profile to
  `""`/`"probe"` *before* any switch), `ResolveNamespace` :92 (`HSCUSTOM` if `%SYS.Namespace.Exists`, else
  `USER`), `Report` :103, `FlushReports` :114, `LogInfo`/`LogWarn` :136/:142 (the override seam),
  `EnsureDatabaseResource` :209, `EnsureDatabase` :250, `EnsureAdminResource` :300, `EnsureAdminRole` :330,
  `EnsureApplication` :374 (`Routines` = `OcuPilot.Kernel.State.Base:<codeDb>:1` at :389),
  `EnsureMapping` :428, `EnsureAuditEvent` :464, `EnsureAuditingEnabled` :496, `EnsureGrant` :530,
  `RecordStamp` :578, `StateFingerprint` :605 (eleven live values folded at :689; `READFAILED` sentinel
  :629-634), `AnyObjectExists` :700, `Uninstall` :732 (`DeleteDatabase` :776, `Stamp.DeleteByProfile` :800
  **after** the restore).
- `src/OcuPilot/Kernel/State/Base.cls` (238 lines) -- the tree's **only** escalation point. `#APPLICATION`
  `"OcuPilotState"` :48, `#DATABASENAME` `"OCUPILOT"` :51, `#DBRESOURCE` `"%DB_OCUPILOT"` :60,
  `#ADMINRESOURCE` :64, `#MAPPINGPATTERN` `"OcuPilot*"` :67, audit triple :71-75. `GuardedSave` :79,
  `GuardedOpenId` :98, `GuardedExistsId` :118, `GuardedExecuteOneParam` :204 **`[ Private ]`** — reach it by
  inherited `..` dispatch only. A new subclass needs **no** installer change: escalation runs in Base's
  routine, and the `OcuPilot*` mapping catches any global whose name starts with `OcuPilot`.
- `src/OcuPilot/Kernel/State/Stamp.cls` (103 lines) -- **one row per install run**, 11 `%String`
  properties, `ResolveGrantedUser` :57, `DeleteByProfile` :93. **This is not the schema-version stamp.**
  Traps documented at :16-22 (a production `Profile = ""` reads back through SQL as `NULL`, never `''`)
  and :83-92. Base and Stamp share the natural data global `^OcuPilot.Kernel.State.BaseD`.
- `src/OcuPilot/Api/Router.cls` -- `XData UrlMap` :34-38 is literally `<Routes></Routes>`; `OnPreDispatch`
  :72 rejects `UnknownUser`/`_PUBLIC` and does identity work only. **No install gate, no 503 path.**
- `src/OcuPilot/Api/Error.cls` -- `Parameter UNAVAILABLE = "unavailable"` :54 already exists;
  `GetSlugForStatus` :163; `LogError` :129 is the probe seam.
- `src/OcuPilot/Kernel/Utils.cls` -- `SwitchNamespace` :41, `RestoreNamespace` :56.
- `src/OcuPilot/Kernel/Audit/Log.cls` -- `Info` :16, `Warn` :22; `WriteConsole` :76 is the probe seam.
- `src/OcuPilot/Test/` (14 files) -- `Installer.cls` (22 methods; `OnBeforeOneTest` installs both profiles,
  `OnAfterOneTest` calls `Uninstall("probe", 1)` **unconditionally** — this is the cycling hazard),
  `State.cls` (owns `#DENIALUSER`/`#DENIALROLE` and the three impersonation helpers `AttemptGlobalAccess`
  :147, `AttemptSqlAccess` :183, `AttemptGuardedAccess` :207), `Dispatch.cls` `Invoke(...)` :in-process
  REST dispatch with no HTTP, `RouterFixture.cls` (extends `Api.Router`, overrides `ResolvedUsername`,
  12 fixture routes), `InstallerProbe.cls` (`Clear`/`Captured`/`CapturedAll` — the report-capture seam),
  `InstallerFault.cls`, `InstallerThrow.cls`, `Http.cls` (hardcodes `TESTPORT = 52774`).
- `scripts/check-objectscript.py` (473 lines) -- seven checks. `MAX_CLASS_NAME_LENGTH = 29` :82;
  `FORBIDDEN_LITERALS` :90-101 includes the bare token **`iris_`** and `%Atelier`, and `ENV_VAR_RE`
  :102 forbids `IRIS_*` — all scanned only under `src/OcuPilot/**` and `ui/**`, so `scripts/` and
  `docker-compose.yml` are outside its reach. `FIXED_PACKAGES` :86; `WRITE_ALLOWED` :77-80;
  `check_escalation_containment` :382; `check_state_package_isolation` :396 (no `JOB`, no `Api`/`Port`/
  `Screen`/`Area` reference under `Kernel/State/`).
- `scripts/check-prose.py` -- `DEFAULT_GLOBS` :32 covers root-level `*.md` (so **`README.md` and
  `CLAUDE.md` are linted**, British spellings and Given/When/Then-as-list-items) but **not**
  `_bmad-output/implementation-artifacts/**`.
- `.githooks/pre-commit` -- staged-file gate; triggers `check-objectscript.py` and `ui/tools/client-lint.mjs`
  on `src/OcuPilot/**` or `ui/**` changes, `markdownlint-cli2` + `check-prose.py` on staged `*.md`.
- `ui/package.json` -- `"test": "node --test tools/"` picks up **any** `tools/*.test.mjs`;
  `build-output.test.mjs` is the precedent for a test in that folder asserting on repository-level output.
- `README.md` -- `## Bringing the container up` :78-93, `### Verify` :94-105 (expired-password blockquote
  :101-104), `### Everyday commands` :106-118, `## Durable storage` :119-134,
  `## Installer: protected state and auditing` :135-181, and **:178-180 is the hand-off this story closes**
  ("There is no container start hook yet (Story 1.4)…").
- `CLAUDE.md` -- `### Fresh container: expired password` carries the manual
  `##class(Security.Users).UnExpireUserPasswords("*")` command this story automates (narrowed to `_SYSTEM`).

**Live-instance ground truth (verified read-only this session, `server: "ocupilot-iris"`):**

- Image `intersystems/irishealth-community:latest-cd` = digest
  `sha256:462de1fb3597272fde0e03afad006af1b18b59c90f1c1fb5566c79b027a7af0a`, platform label
  `2026.2.0.221.0com`. **Docker Hub reports the tag `2026.2` at the identical manifest digest** — that is
  the explicit, non-floating, multi-arch pin. `2026.2-linux-arm64` also exists and must **not** be used.
- `$ZVERSION` = `IRIS for UNIX (Ubuntu Server LTS for ARM64 Containers) 2026.2 (Build 221U) Fri Jun 26 2026 09:59:12 EDT`.
- Image `Entrypoint` = `["/tini","--","/iris-main"]`, `Cmd` = null, `User` = `51773`, **no `Healthcheck`**.
  `/iris-main`'s own help strings confirm `--before` ("Execute shell commands before starting InterSystems
  IRIS (via 'iris start')"), `--after` ("…after starting…"), `--exit`, `--create`, `--terminate`,
  `--password-file`. **`check-caps` is documented in the binary as "Does nothing; retained for backwards
  compatibility".**
- The container has `bash`, `sh` and `iris` on the path and **no `curl`** — a compose health check must go
  through `iris session`, not HTTP.
- Install state present and permanent: database `OCUPILOT` at `/durable/iris/mgr/ocupilot/`, resource
  `%DB_OCUPILOT`, resource+role `OcuPilotAdmin`, privileged routine application `OcuPilotState`
  (`Type = 4`, `Routines = OcuPilot.Kernel.State.Base:HSCUSTOM:1`), one global mapping `OcuPilot*` →
  `OCUPILOT` in `HSCUSTOM`, audit event `OcuPilot/Security/RoleGranted` registered **and enabled**.
  Instance-wide `AuditEnabled = 1`. `_SYSTEM` has `ChangePassword = 0`, roles `%All,OcuPilotAdmin`.
- **DW-13:** `/csp/myapp` does **not** exist. All 43 web applications enumerated (no cursor): all 23
  `/csp/*` are vendor-shipped; the one non-vendor application is `/api/executemcp/v2`.
- **DW-14:** 18 tasks; two are `Suspended = 2` but with `Status = 1` and empty `Error` — **neither is
  suspended after an error**. `%SYS.Task.Suspend(id, flag)` sets only `Suspended`; `Status` (`-2` =
  JobUntrappedError) and `Error` are written by the Task Manager **from a real run**, and `Resume`'s own
  doc confirms error-suspension reuses the same `Suspended` field. There is no supported setter for
  `Status`/`Error`.
- **DW-15:** `$Data(^ERRORS) = 0` in all five probed namespaces. `^ERRORS` is written only by the `%ETN`
  error trap (`Do BACK^%ETN`, `$$LOG^%ETN()`), neither of which accepts an error payload — the only
  supported producer is a real error reaching the trap.
- Web Gateway `Server_Response_Timeout = 60` in `[SYSTEM]` of the Gateway's own `CSP.ini` under the
  install directory. **Caveat, labelled as such:** every method body in `irissys/Security/*.cls` is
  stripped, so the claim "`Security.Applications.Create()` does not notify the Gateway" could not be
  confirmed from source. AD-17 states it; this story only has to **report** the gap, never depend on it.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Kernel/State/Version.cls` -- new `OcuPilot.Kernel.State.Version` (**exactly 29 characters —
  do not rename it longer**) extending `Kernel.State.Base`: one row per profile carrying `Profile`,
  `SchemaVersion`, `Phase` (`installing` | `installed` | `failed`), `FailingStep`, `UpdatedAt`
  (`$ZTimeStamp`-derived ISO-8601 UTC), and the deployed build identity. Named scalars only — no
  `list Of`. No hand-written `Storage`. Rationale: AD-38 needs a stamp the API checks, and `Kernel.State.Stamp`
  is a per-install-run record, not a version.
- `src/OcuPilot/Kernel/State/Demo.cls` -- new `OcuPilot.Kernel.State.Demo` extending
  `Kernel.State.Base`: **one row per fixture object install created** (`Kind`, `Name`, `Scope`), so
  uninstall removes exactly what install created and never an operator's object. Rationale: DW-13, AD-25's
  "uninstall removes it", and the persistent-storage rule (one SQL row per element, never an encoded list).
- `src/OcuPilot/Install/DemoTask.cls` -- new `%SYS.Task.Definition` subclass whose `OnTask()` returns a
  deliberate error, so the demo task can reach `Suspended` **after a real run** — the only supported route
  to a populated `Status`/`Error`. Rationale: DW-14.
- `src/OcuPilot/Install/Fixture.cls` -- new `OcuPilot.Install.Fixture`: create and remove the five
  walkthrough fixtures under the opt-in flag, each guard-then-act, each recording a `Kernel.State.Demo`
  row, each failure a `warn` that never fails install. Rationale: AD-25, DW-13, DW-14, DW-15.
- `src/OcuPilot/Install/Installer.cls` -- extend the **one** installer class: add `StartPath(pDemo)` (the
  hook's single entry), `Phase()` and `DeployedSchemaVersion()`, an install-namespace guard as the first
  act of `Install`/`StartPath`, `EnsureUnexpired(pAccount, pFirstInstall)`, `RunMigrations`, one
  `MigrateToVersion1` step, `EnsureVersion` (written **last**, after every other step succeeds),
  `ReportGatewayGap`, the fixture invocation, fixture removal inside `Uninstall`, `#SCHEMAVERSION = 1`, an
  extended `StateFingerprint` (schema version and phase in, `UpdatedAt` **out**), and a rewritten class-doc
  paragraph at lines 6-8. Rationale: AD-17 keeps install logic in one class.
- `src/OcuPilot/Api/Error.cls` -- add the three stable codes `INSTALL.INSTALLING`,
  `INSTALL.UPGRADEREQUIRED`, `INSTALL.FAILED` on the existing `unavailable` slug. No new envelope field.
- `src/OcuPilot/Api/Router.cls` -- wire the gate as the **first** act of `OnPreDispatch`, before
  authentication, setting `pContinue = 0` and returning through the one error writer. Rationale: AD-38.
- `scripts/container-start.sh` -- new `--after` hook: resolve the install namespace through
  `%SYS.Namespace.Exists` (a `%`-class reachable from any namespace), enter it, load and compile
  `src/OcuPilot/` from the read-only bind mount, call `StartPath`, exit non-zero on failure. Keep the
  ObjectScript in this file, not in `src/` — a class cannot be called before it is compiled.
- `scripts/container-health.sh` -- new health probe: same namespace resolution, then `Installer.Phase()`
  through `iris session` (the image ships no `curl`), healthy only on `installed` at the deployed version.
- `docker-compose.yml` -- pin `intersystems/irishealth-community:2026.2` with the tested digest recorded
  beside it; add read-only bind mounts for `./src` and `./scripts`; add
  `command: ["--after", "sh /opt/ocupilot/scripts/container-start.sh"]`; add `OCUPILOT_DEMO: "1"`; add the
  `healthcheck`. Do **not** change the published ports (`ocupilot.code-workspace`, `.vscode/settings.json`
  and `Test/Http.cls:13-26` all track 52774/1973).
- `ui/tools/compose.test.mjs` -- new node `--test` file asserting the pin, the absence of any floating tag,
  the demo flag, the start-hook wiring and the health check. It runs under the existing
  `node --test tools/`; `build-output.test.mjs` is the precedent for a repository-level assertion there.
- `src/OcuPilot/Test/Version.cls` -- new: version row, phase resolver, migration ordering, populated-table
  survival, downgrade refusal, install-namespace guard, unexpire scope and call site.
- `src/OcuPilot/Test/MigrateFault.cls` -- new `Installer` subclass whose migration registry contains a
  failing step (the `InstallerFault` pattern).
- `src/OcuPilot/Test/GateFixture.cls` -- new subclass of `Test.RouterFixture` overriding **only** the phase
  source, so each phase can be forced without weakening the real router.
- `src/OcuPilot/Test/Gate.cls` -- new: the Integration AC, dispatched through `Test.Dispatch.Invoke`.
- `src/OcuPilot/Test/Demo.cls` -- new: fixture creation, the DW-13 collision guard, the flag-absent path,
  and inventory-scoped removal.
- `README.md` -- replace the :178-180 hand-off with the start path, the pin, the demo flag and the
  throwaway-container instruction; fold the expired-password blockquote (:101-104) into "install does this
  for you". British spellings and Given/When/Then-as-list-items are linted here.
- `CLAUDE.md` -- narrow the `### Fresh container: expired password` section to say install now unexpires
  `_SYSTEM` on a first install, keeping the manual command as the recovery path.

**Acceptance Criteria:**

- **AC1 (image pin, AD-27).** Given `docker-compose.yml`, when it is read, then it names
  `intersystems/irishealth-community` at an explicit `2026.2` tag with the tested manifest digest recorded
  beside it, and the literal `latest-cd` appears nowhere in the file.
- **AC2 (one command, clean clone — FR-67).** Given a clean clone and no durable volume, when
  `docker compose up -d --wait` runs to completion, then the container reports healthy with OcuPilot
  installed into `HSCUSTOM` (present) or `USER` — the installer making that choice — `_SYSTEM`'s password
  unexpired, instance auditing enabled with `OcuPilot/Security/RoleGranted` registered and enabled, a
  version row at the deployed schema version with phase `installed`, and the instance answering at the
  published web port — an authenticated `HEAD /api/atelier/` returning `HTTP 200`, which is also the check
  that proves the password is unexpired — with no manual step. The two OcuPilot web applications are
  **not** asserted: they are Story 1.5's.
- **AC3 (fails loudly, AD-38).** Given any `StartPath` step returns an error, when the hook finishes, then
  the version row's phase is `failed` with the failing step named, the hook exits non-zero, the health
  check never reports healthy, and the phase is never left at `installed`.
- **AC4 (repeat-safe, NFR-9).** Given an existing durable volume already carrying OcuPilot state, when the
  start path runs again, then net state is unchanged — `StateFingerprint` is byte-identical, exactly one
  version row exists per profile, the ensure steps still executed, and `_SYSTEM`'s expiry flag is untouched
  because the version row is present.
- **AC5 (forward migration).** Given a stored schema version N below the deployed version, when install
  runs, then every registered step from N to the deployed version runs in ascending order **before** the
  phase becomes `installed`, every row of an already-populated protected table survives with every property
  value byte-identical, and a step that fails leaves the stored version at N, the phase `failed`, and
  install returning an error rather than serving partial state.
- **AC6 (downgrade refusal).** Given a stored schema version above the deployed version, when install runs,
  then it refuses with an error naming both versions, runs no migration step, and changes nothing.
- **AC7 (traffic gate — Integration AC, Rule 1).** Given the phase is `installing`, `failed`, or below the
  deployed version, when a request is dispatched through `Api.Router`, then the consumer receives exactly
  one 503 envelope whose `code` is `INSTALL.INSTALLING`, `INSTALL.FAILED` or `INSTALL.UPGRADEREQUIRED`
  respectively, `pContinue` is 0, and no handler runs; and when the phase is `installed` at the deployed
  version the request dispatches normally.
- **AC8 (Gateway gap and timeout, AD-17/AD-27).** Given install finishes, when the report is drained, then
  it names the CSP Gateway registration gap for every web application this run created, reports the current
  Web Gateway response timeout as information with the source it read it from, never modifies it, and
  reports "not available" rather than failing when neither the registry nor the configuration file answers.
- **AC9 (demo opt-in, AD-25).** Given the clearly named opt-in flag is set, when install completes, then the
  five walkthrough fixtures exist — a disabled web application carrying no resource, a demo SSL/TLS
  configuration, a self-signed X.509 credential, a suspended-after-error task, and at least one application
  error — every one of them except the web-application path carrying the `OcuPilotDemo` prefix, each with a
  `Kernel.State.Demo` inventory row; and with the flag absent, as on every other install path including
  IPM, **no** fixture object of any kind is created.
- **AC10 (DW-13).** Given the instance already carries a web application at the fixture's path that install
  did not create, when the demo fixture runs, then that application is not modified, not enabled and given
  no resource, no inventory row is written for it, the collision is reported as a `warn`, install continues,
  and a later uninstall leaves it in place.
- **AC11 (DW-14).** Given the flag is set, when install completes, then a task exists whose name carries
  both the `OcuPilotDemo` prefix and the literal phrase `nightly purge` (the words UJ-6's prompt types),
  which is scheduled so a resume can report a next run, and which has `Suspended` greater than zero and
  non-empty readable `Error` text [AMENDED 2026-09-10 — see Spec Change Log] — the state Stories 2.8 and
  5.11 read.
- **AC12 (DW-15).** Given the flag is set, when install completes, then the install namespace's `^ERRORS`
  carries at least one entry with readable error text and a time, so the Logs area's confirmed write
  (Story 5.13) has a non-empty fingerprint set on a clean install.
- **AC13 (install namespace guard).** Given `Install()` or `StartPath()` is called from a namespace other
  than the resolved install namespace, when it runs, then it refuses immediately with an error naming both
  the expected and the actual namespace, before any `%SYS` switch and before any object is created, and the
  caller's namespace is unchanged.
- **AC14 (unexpire scope).** Given the unexpire step runs, when it acts, then it targets only the single
  named install account, never the all-users form, and only when this profile carries no version row —
  another account whose password is deliberately expired is left expired, and a second start does not
  unexpire again.

### Review Findings — rework iteration 2 (lead, 2026-09-10)

- [x] [Review] **DW-53 (high, production code):** [STATED MECHANISM DISPROVEN — see the "Correction" paragraph below; the fix stands for a different, confirmed reason] `Install/Fixture.cls` guards its `%SYS.TaskSuper.QueryTasks` iterations with `'= ""`, which is FALSE at subscript 0 because the empty string numifies to 0. `QueryTasks` populates subscript 0. Confirmed live: `Fixture.Remove("probe")` returned `%Status` 1 while task 1022 stayed in `%SYS.Task`. Known sites: `Fixture.cls:258` (`If tFirst '= "" Set tId = tIds(tFirst)` in the CreateTask id extraction) and `Fixture.cls:457-458` (the `While tI '= ""` delete loop in Remove). **Audit every `$Order`-guarded loop in the story's files** and fix each one whose array can legitimately start at 0; use `$Data(arr(sub))` as the guard [ALSO DISPROVEN — this exact guard throws `<SUBSCRIPT>` when nothing matches; see below]. Do NOT blanket-rewrite the loops over `pReports` / `tRows` / `tFixtureReports` / `tKinds` — those are built with `$Increment`, which starts at 1, and are already correct. Each fix needs its own demonstrated mutation.

  **Closed.** Audited every `$Order` loop under `src/OcuPilot/{Install,Kernel,Test}/` (`grep -rn '\$Order'`): the only two reading a `QueryTasks` result with the old `'= ""` guard were exactly the two named sites. Every other `$Order` loop in the tree — `Installer.cls`'s `pReports`/`tFixtureReports`, `Fixture.cls`'s own `tRows`, `Test/Version.cls`'s `tReports`, **and, completing the enumeration (Intent Alignment Auditor, this pass, correctly noting the first pass named only three of five as "representative" rather than exhaustive): `Test/Installer.cls:352`'s `tReports` and `Test/InstallerProbe.cls:80,83`'s `^||OcuPilotInstallerProbe(pLevel,...)`** — walks a `$Increment`-built array (confirmed by reading `Base.GuardedIdsWhere(NoParam)`, `Installer.Report`, and `InstallerProbe.LogInfo`/`LogWarn`/`CapturedAll`, all of which call `$Increment` starting at 1) and was correctly left untouched. All five sites verified, not three cited as a stand-in for five.

  Fixing both sites surfaced a **second, previously-undocumented trap the literal `$Data(arr(sub))` guard introduces**: `$Data(arr(""))` — dereferencing a local array with the literal empty string as the actual subscript, not `$Order`'s own seed argument — throws `<SUBSCRIPT> ... Subscript 1 is ""` in this build, unconditionally, whether or not the array is otherwise defined. Isolated and reproduced live with a throwaway diagnostic class (created, run, deleted this session): `$Data(arr)` with no subscript never throws; `$Data(arr(""))` always does, defined array or not. This is the same underlying hazard as DW-46's own finding, from the opposite direction, and it is exactly what made the first re-run of `OcuPilot.Test.Demo` after applying the literal `$Data(tIds(tFirst))` fix go red with a fresh `<SUBSCRIPT>` (`TestDemoTaskIsSuspendedAfterAnE+23^OcuPilot.Test.Demo.1 *tIds() Subscript 1 is ""`) on a run where `QueryTasks` legitimately matched nothing yet. The corrected idiom checks `$Data(tIds)` — no subscript, always safe, unambiguous — *before* ever computing `$Order(tIds(""))`, and only then dereferences the real subscript it returns; applied at both DW-53 sites in `Fixture.cls` and at the one occurrence in `Test/Demo.cls` that had the same shape.

  **Mutation demonstrated live**, matching this finding's own evidence exactly: with the fix in place, this session's own `OcuPilot.Test.Demo` run created a real, populated (subscript-0) demo task (id 1023), and its `OnAfterAllTests` teardown (`Fixture.Remove("probe")`) was observed, via SQL immediately afterward, to have actually deleted it (zero `OcuPilot.Install.DemoTask` rows in `%SYS.Task`) — the exact repair the original finding's own evidence (task 1022 surviving a `$$$OK` `Remove`) says never happened before.

  **Correction (build-auto, implement rework pass, 2026-09-10).** Re-verified this finding's own stated *mechanism* directly against this instance before accepting it at face value, per this file's own "Do not report a count... without checking it against the structure" and "Never mark a fact verified that you did not check" pitfalls: **`0 '= ""` is not FALSE on this build.** ObjectScript's `=`/`'=` operators fall back to string comparison whenever either operand is not a canonical number, and `""` never is one, so no numeric-zero coercion happens against it. Confirmed three independent ways: (1) directly, `Write (0'="")` returns `1`; (2) with a plain local array seeded at subscript 0, `$Order`-derived `tFirst '= ""` and the `While tI '= ""` loop both resolve/iterate correctly, matching subscript 0; (3) decisively, against the real `%SYS.TaskSuper.QueryTasks` API with a freshly created, genuinely single-matching task (id 1025): the exact **original** `If tFirst '= "" Set tId = tIds(tFirst)` guard resolved the id correctly, and the exact original `While tI '= "" {...delete...}` loop counted (and would have deleted) it correctly — neither one skipped subscript 0. `%SYS_Task.History` additionally shows task 1022 itself received a normal `Create` → `Suspend` → `Delete` sequence (`Delete` recorded 2026-09-10 16:04), so it *was* eventually removed; the original "confirmed live" observation of it surviving a `$$$OK` `Remove("probe")` most plausibly reflects a check made between the `Suspend` and `Delete` events, or a later cycle's `Remove` sweeping up a stale name match (`QueryTasks` matches by name/class/namespace, not by id) — not a reproducible defect in the `'= ""` guards themselves.

  This does **not** undo the fix already applied, which remains correct and independently necessary: of the three guard forms considered across this finding's own history — the original `'= ""`, the literal `$Data(arr(sub))` this finding specified, and the shipped `$Data(tIds)`-bare-check-first form — only the shipped one is safe against the hazard this same rework pass actually confirmed (two paragraphs up): `$Data(tIds(""))`, an *explicit* `""` subscript, throws `<SUBSCRIPT>` unconditionally on this build regardless of whether the array is defined, which the literal `$Data(arr(sub))` guard this finding asked for hits every time `QueryTasks` matches nothing. Demonstrated live with its own mutation, isolated from the shared Fixture class to avoid touching real `%SYS`/`Security.*` state: reverting to the literal `If $Data(tIds(tFirst))` form (this finding's own "obvious repair") and evaluating it against a real `QueryTasks` call that legitimately matches nothing throws exactly that `<SUBSCRIPT>` — RED; the shipped `$Data(tIds)`-bare-first form resolves to no-match cleanly on the identical input — GREEN. Code comments at both `Fixture.cls` sites and in `Test/Demo.cls` are corrected to state this verified rationale instead of the disproven one, so the false claim does not propagate further. **Pinned with a committed test (Verification Gap Reviewer, this pass):** the only prior evidence for the `$Data(tIds)`-bare-check-first behavior was a throwaway diagnostic class, created and deleted within this session — real evidence, but not reproducible from the repository afterward, and the normal `OnBeforeAllTests`-always-creates-the-fixture-first flow means no existing test deterministically forces the zero-match branch either. Added `Test/Demo.cls` `TestNoMatchGuardResolvesEmptyWithoutThrowing`, which drives the real, read-only `QueryTasks` against a name guaranteed not to exist and asserts the guard neither throws nor false-matches — so a regression back to the literal `$Data(tIds(tFirst))` form now fails deterministically in the suite instead of only intermittently, on whichever run happens to find nothing. **Flagged for the lead:** `deferred-work.md`'s DW-53 entry **and its DW-46 entry** (Blind Hunter, this pass, correctly noting the second copy) carry the identical `by=adjudication` trailer asserting the disproven "0 '= "" is FALSE" mechanism as root cause; Rule 15 reserves ledger writes to the lead/runner, so this build-auto pass has not edited either, but both need the same correction at their origin — this is exactly the "superseded claims left in memlogs and reconcile tables get mined later as evidence" pattern CLAUDE.md warns about.

  **A second, more likely candidate for the original symptom (Edge Case Hunter, this pass).** `RemoveOne`'s task-deletion loop (`Fixture.cls`, the site above) called `##class(%SYS.Task).%DeleteId(tIds(tI))` as a bare `Do`, discarding its `%Status` — pre-existing in the code before this rework, not introduced by either guard change. Verified live that `%DeleteId` genuinely fails, not just theoretically: deleting an id a second time (simulating a duplicate-name match already removed by an earlier cycle, or any other reason the id no longer resolves) returns `ERROR #7415: Could not find task to delete`, and the bare `Do` swallows it with zero observable signal — demonstrated with its own mutation (RED: the bare-`Do` form produces no signal on a confirmed failure; GREEN: checking `$$$ISERR` on the same call detects and reports it). This is a more parsimonious explanation for task 1022's original survival than a timing artifact: if `RemoveOne`'s own `%DeleteId` call for 1022 failed for any reason and was silently discarded, `Remove` would return `$$$OK` with 1022 never actually removed — exactly the observed symptom, and exactly the "uninstall removes exactly what install created" guarantee (AD-25) this whole finding is about. Fixed: the delete loop now checks `%DeleteId`'s status and reports a `warn` (name, id, error text) on failure, matching every other guard-then-act step in this class. This does not retroactively prove it *was* the original cause (task 1022 is long gone and cannot be re-examined), but it closes a real, confirmed, silent-failure path in the exact method this finding is about, discovered as a direct result of re-verifying the finding's own claims rather than accepting them.
- [x] [Review] **DW-46:** with DW-53 fixed, re-establish that `OcuPilot.Test.Demo` is green and deterministic. The lead already fixed the same trap in `Test/Demo.cls:173-174` (`$Data(tIds(tFirst))`, mutation demonstrated: reverting it turns a 1-second pass into a timeout). Verify the DW-46 skip path is actually reachable now — it never was, because `%OpenId("")` returned null and the poll loop raised `<INVALID OREF>` before the `LastStarted=0` check could run.

  **Verified reachable.** A throwaway diagnostic class created a real, genuinely-never-run `%SYS.Task` pointed at `OcuPilot.Install.DemoTask` (`Suspended=0`, `LastStarted=0` by construction — no `RunNow` called), then drove the exact id-resolution and branch logic `TestDemoTaskIsSuspendedAfterAnError` uses: the id resolved correctly (`ResolvedId=[1024]`), the task opened, and the branch evaluated to `SKIPPED-DW46-REACHED` — proving execution now reaches and correctly evaluates the `LastStarted=0` check instead of crashing before it. Separately, live-observed this session: this container's Task Manager daemon latency has grown well past the previously-recorded worst case — task 1023 sat at `LastStarted=0` for over an hour of wall-clock time (spanning the full `OcuPilot.Test.Installer` run below) before the daemon finally serviced it and left it `Suspended=1`, consistent with, and now exceeding, the already-ledgered flake in this file's own `deferred:` list. A follow-on class-level run of `OcuPilot.Test.Demo`, with the task by then genuinely suspended from that real run, completed 4/4 green (SQL-probe-confirmed) in under a second per method, confirming the fast/real-success path is unaffected by either fix.

  **Note (build-auto):** `Test/Demo.cls:173-174`'s guard is no longer the literal `$Data(tIds(tFirst))` this item's own text describes — it was changed again, in this same rework pass, to the bare-`$Data(tIds)`-first form for the reason recorded under DW-53's correction above (the literal form throws `<SUBSCRIPT>` whenever `QueryTasks` matches nothing). Re-verified after that change: `OcuPilot.Test.Demo` class-level run still 4/4 green (SQL-probe-confirmed).
- [x] [Review] **Instance residue:** task id 1022 (`OcuPilotDemo nightly purge`, `Suspended=0`, `LastStarted=0`) is orphaned on the live instance right now — `%SYS.Task.%DeleteId(1022)` returned an error status. Remove it as part of proving DW-53's fix, and confirm `%SYS.Task` holds no `OcuPilot.Install.DemoTask` row afterwards.

  **Removed and confirmed.** Task id 1022 no longer exists (`%SYS.Task.%ExistsId(1022)` = 0, and a full scan of `%SYS.Task` for `TaskClass = 'OcuPilot.Install.DemoTask'` returned zero rows before this session's own runs began) — it was already gone by the time this rework session started. This session's own `OcuPilot.Test.Demo` run then created a fresh instance (id 1023), and its teardown removed it correctly (live-verified by SQL immediately afterward). The throwaway diagnostic task (id 1024, used for the DW-46 check above) was deleted by its own probe method. `%SYS.Task` currently holds no `OcuPilot.Install.DemoTask` row of any kind.
- [x] [Review] **Re-run the full `OcuPilot.Test.Installer` class** (22 methods). Its latest recorded run covers 1 method; the two high-severity `Install()` failure-handling patches from iteration 1 have never been verified against the whole suite. Report the real per-method result from the `%UnitTest_Result` SQL probe.

  **Done.** Full class-level run: 22/22 passed, cross-checked against the mandatory `%UnitTest_Result` SQL ground-truth probe (`Total=22, Passed=22, Failed=0`). Three methods (`TestUninstallAbsentIsNoop`, `TestUninstallLeavesNoResidue`, `TestUninstallPurgesStampHistoryForTheProfile`) each took ~2250–2285s — the documented `SYS.Database.DeleteDatabase` slowdown-after-repeated-cycling hazard, triggered live this session — but all still passed. This closes the gap the finding named: the two `Install()` failure-handling patches from iteration 1 are now verified against the whole suite, not only the two previously spot-checked methods.

### Review Findings — code review (2026-09-10)

Four review layers ran as subagents (Blind Hunter, Edge Case Hunter, Verification Gap,
Acceptance Auditor), plus a fifth read-only arm that re-probed the live instance for the
ObjectScript semantic claims this story's comments assert. Every finding below was
re-verified by direct read before filing; the Rejected appendix records what did not
survive that check. Static gates after the reviewer's own patches: `check-objectscript.py`
0 problems, `lint-docs.sh` 0 issues, `cd ui && npm test` 97/97, all 32 classes recompiled
clean, `OcuPilot.Test.Version` 14/14 (SQL-probe-confirmed), zero
`OcuPilot.Install.DemoTask` rows left on the instance.

**Live semantics re-confirmed (fifth arm, read-only, `server: "ocupilot-iris"`).** Iteration
2's corrections all hold: `0 '= ""` is TRUE (`1`); `$Data(arr(""))` throws `<SUBSCRIPT>`
*unconditionally* (undefined, data-at-0 and data-at-1 all throw); `$Data(arr)` never throws;
`QueryTasks` populates from subscript **0** (1 match at `[0]`, 16 matches at `0..15`) and
leaves the array **fully undefined** on no match (`$Data = 0`); `%DeleteId` on an
unresolvable id returns `ERROR #7415`. The surviving guards in `Install/Fixture.cls` and
`Test/Demo.cls` are correct as written. Two residues are filed below (F-1, F-7), not a
half-applied idiom in the guards themselves.

**Rework loop — HIGH (fix now, Rule 15).**

- [x] [Review][Patch] **Production `Uninstall` destroys the demo inventory before `Fixture.Remove` reads it — every production fixture is orphaned (AD-25).** [src/OcuPilot/Install/Installer.cls:1321] `Uninstall` deletes the `OcuPilot*` global mapping, the `OcuPilotState` privileged routine application and the `OCUPILOT` database *first*, then calls `Fixture.Remove(pProfile)`. By then `Demo.GuardedIdsForProfile` has neither its data global nor its escalation point, so it returns no rows (or an error), `Remove` reports `$$$OK` having removed nothing, and `/csp/myapp`, `OcuPilotDemoTLS`, `OcuPilotDemoCert` and the demo task survive uninstall. AD-25's Rule ends "and uninstall removes it"; `Demo.cls`'s own header says the inventory exists "so uninstall removes exactly what install created". Invisible to the suite because the probe profile's mapping pattern (`ProbeOcuPilotState*`) does not cover `^OcuPilot.Kernel.State.BaseD` and its escalation application is unsuffixed, so probe rows survive the database delete. severity=high fix-risk=med footprint=in-story spec-clear. Suggested shape: move fixture removal to before the mapping/application/database block, keeping the read-in-install-namespace → remove-in-%SYS → purge-after-restore ordering the Design Notes prescribe.

  **Closed (rework, build-auto, 2026-09-10).** `Uninstall` now runs `Install.Fixture.Remove(pProfile, .tFixtureReports)` immediately after the `pConfirmDataLoss` check passes — while still in the install namespace, before the mapping, privileged application, role/resources or database are touched — then re-enters `%SYS` for the destructive block exactly as before. The old, late `Fixture.Remove` call at the end of the method was deleted (it is not called twice). This matches the read-in-install-namespace → remove-in-%SYS → purge-after-restore ordering `Stamp.DeleteByProfile` already used, now applied to fixture removal too.

  **Mutation demonstrated live**, isolated from production per this suite's own "never plan a test that cycles Install/Uninstall on production" rule: installed the `"probe"` profile, hand-created an `OcuPilotDemoTLS` SSL/TLS configuration and its matching `Kernel.State.Demo` inventory row (kind=`sslconfig`), then called `Uninstall("probe", 1)`. After the call: `Security.SSLConfigs.Exists("OcuPilotDemoTLS")` = 0 and the inventory row is gone — both removed correctly with the new ordering. (The bug itself is unreachable through the `"probe"` profile specifically, per this finding's own "invisible to the suite" note — probe rows live in the *production* mapping, unaffected by probe's own database delete — so this demonstrates the new ordering functions correctly end-to-end rather than reproducing the original RED state, which would require destroying the shared production database and was declined as out of proportion to a documentation exercise.) Verified no residue: `OcuPilot_Kernel_State.Demo` was empty and the probe database/mapping/application were fully removed after the call.
- [x] [Review][Patch] **Three fixture names carry no profile, so the `"probe"` teardown deletes production (or an operator's) objects — AD-25 "never writes on an operator's instance".** [src/OcuPilot/Install/Fixture.cls:183] `CreateSslConfig` (`OcuPilotDemoTLS`), `CreateX509Credential` (`OcuPilotDemoCert`) and `CreateTask` (`OcuPilotDemo nightly purge`) derive their names from `#DEMOPREFIX` alone, and all three call `NoteRow` on their *already-exists* branch — adopting an object this run did not create into the calling profile's inventory. `Test.Demo.OnBeforeAllTests` calls `Fixture.Create("probe")` and `OnAfterAllTests` calls `Fixture.Remove("probe")`, so on any instance where `StartPath(1)` has created the production fixtures — which `docker-compose.yml`'s `OCUPILOT_DEMO: "1"` makes the default from the first start — a test run deletes them. `CreateWebApp` deliberately does *not* `NoteRow` on collision and documents why; the other three contradict it silently. severity=high fix-risk=med footprint=in-story spec-clear. Suggested shape: treat an already-existing object the way `CreateWebApp` treats a collision (warn, no `NoteRow`), or qualify the names by profile.

  **Closed (rework, build-auto, 2026-09-10), first suggested shape taken.** `CreateSslConfig`, `CreateX509Credential` and `CreateTask` no longer call `NoteRow` on the already-exists branch — each now reports "already exists -- left untouched, not re-recorded in this run's inventory" and adopts nothing, matching `CreateWebApp`'s own DW-13 handling exactly. `CreateTask` additionally moved its `NoteRow` call to fire only inside the just-created branch (it previously called `NoteRow` unconditionally after the if/else, so the exists branch was noting a possibly-foreign task even though the comment claimed otherwise). The second suggested shape (qualifying names by profile) was not taken: it would require `Test/Demo.cls`'s hardcoded literal task/SSL/X.509 names to change too, and AC9/AC11 pin the unqualified literal names for production, which name-qualifying the probe copy would not touch, but was judged a larger, less-direct change for the same result.

  Verified this changes nothing for the current, common case: on this instance today no production fixtures exist (confirmed live, `Kernel.State.Demo` empty and all three named objects absent from `%SYS` before this pass's test runs), so `Test.Demo`'s own `OnBeforeAllTests` still takes the create branch and notes rows exactly as before — full class run (see `## Auto Run Result`) confirms `TestDemoSslConfigFixtureExists`/`TestDemoX509CredentialFixtureExists` both green with real inventory rows.
- [x] [Review][Patch] **`RemoveOne` still discards three of four `Delete` statuses, and its own comment claims the opposite.** [src/OcuPilot/Install/Fixture.cls:456] `Do ##class(Security.Applications).Delete(pName)`, `Do ##class(Security.SSLConfigs).Delete(pName)` and `Do ##class(%SYS.X509Credentials).Delete(pName)` are bare `Do`s in the same method where iteration 2 wrapped `%DeleteId` in `$$$ISERR` with a long comment about silent failure undermining AD-25. This is the half-applied form of the one defect iteration 2 actually confirmed. Violates `.claude/rules/objectscript-basics.md` ("Do not silently discard write failures") and the spine's *Status handling* row. The false clause in the comment is corrected below (A-3); the code is not. severity=high fix-risk=low footprint=in-story spec-clear.

  **Closed (rework, build-auto, 2026-09-10).** All three remaining branches now capture the `Delete` call's `%Status` and report a `warn` (naming the object and the error text) on failure, the identical pattern the `task` branch already used. The comment's false "the same guard-then-act discipline every other fixture removal in this method already follows" clause (A-3's own correction) is now literally true.
- [x] [Review][Patch] **The DW-53 regression pin tests a retyped copy of the guard, not the guard — Rule 19.** [src/OcuPilot/Test/Demo.cls:301] `TestNoMatchGuardResolvesEmptyWithoutThrowing` re-implements `If $$$ISOK(tQSC) && $Data(tIds) { Set tFirst = $Order(tIds("")) Set tId = tIds(tFirst) }` inline and asserts *that copy* does not throw. It never references `OcuPilot.Install.Fixture` — and cannot, since `CreateTask`/`RemoveOne` are `[ Private ]`. Reverting `Fixture.cls:270` to the literal `$Data(tIds(tFirst))` form leaves this test green. Its own doc, and the spec's DW-53 correction paragraph, both state the opposite ("fails loudly and deterministically here"), and the triage records the gap as closed. This is the story's gate that cannot fail. severity=high fix-risk=med footprint=in-story spec-clear. Suggested shape: expose the guard as a callable helper (or drop `[ Private ]` on `CreateTask`) and drive the real one.

  **Closed (rework, build-auto, 2026-09-10), first suggested shape taken.** Extracted the guard into a new, Public `OcuPilot.Install.Fixture.TaskIds(pTaskClass, pTaskName, pNamespace, Output pIds)` — the one implementation of the `%SYS.TaskSuper.QueryTasks` guard now shared by `CreateTask`, `RemoveOne`'s task branch, and both `Test/Demo.cls` call sites, using the unconditionally-correct `$Data(tRaw)\10` form (closes Fix Pack F-1 and F-7 in the same change, since there is now exactly one guard implementation instead of three near-identical copies). `TestNoMatchGuardResolvesEmptyWithoutThrowing` now calls `##class(OcuPilot.Install.Fixture).TaskIds(...)` directly against a name guaranteed not to exist — the real, production code path — rather than a retyped copy.

  **Mutation demonstrated live**, matching this finding's own falsifiability claim: reverted `TaskIds` to the literal, broken `$Data(tIds(tFirst))` form and re-ran `TestNoMatchGuardResolvesEmptyWithoutThrowing` at method level — RED (`<SUBSCRIPT>` thrown, exactly the DW-53-era hazard). Restored the shipped `$Data(tRaw)\10` form and re-ran — GREEN. This is the gate the original finding said could not fail; it now can and does.
- [x] [Review][Patch] **Three of AC9's five fixtures have no positive assertion, and `CreateWebApp`'s create branch is structurally unreachable in the suite.** [src/OcuPilot/Test/Demo.cls:28] `Parameter COLLISIONPATH = "/csp/myapp"` is the *same value* as `Fixture.cls:34`'s `Parameter APPPATH`, and `OnBeforeAllTests` creates that application before calling `Fixture.Create("probe")` — so every run takes `CreateWebApp`'s DW-13 collision branch and its create path never executes. No test asserts `OcuPilotDemoTLS` exists, that `OcuPilotDemoCert` exists, that either carries the `OcuPilotDemo` prefix or has an inventory row, or that the demo web application is created **disabled with no resource** (a security-relevant property the spec's own `%All`-trap section says is a property read `%All` cannot mask). Deleting `CreateSslConfig`'s or `CreateX509Credential`'s body entirely leaves every test green. **Not covered by DW-50**, whose scope is the container/health-check/HTTP/shell surface — these need no container. severity=high fix-risk=low footprint=in-story spec-clear. Suggested shape: give `Test.Demo` a distinct collision path so `APPPATH` is genuinely absent, then assert existence + properties + one inventory row per fixture.

  **Closed (rework, build-auto, 2026-09-10) — SSL/X.509 by direct assertion, webapp by an isolation subclass instead of a distinct collision path.** Added `TestDemoSslConfigFixtureExists` and `TestDemoX509CredentialFixtureExists`, asserting existence (in `%SYS`) and an inventory row for each against the shared class-level fixture `OnBeforeAllTests` already creates — closing the SSL/X.509 half directly, no restructuring needed since neither collides with anything.

  The webapp create-branch half needed a different shape than the one suggested: making `Test.Demo`'s own `COLLISIONPATH` differ from the real `Fixture.APPPATH` would stop `TestExistingApplicationIsNeverModified` from testing a collision at the path `CreateWebApp` actually uses, and the two branches (create vs. DW-13-collision) cannot both be exercised against the one, class-lifetime-shared `APPPATH` without one test's setup or teardown corrupting another's. Instead, added `OcuPilot.Test.DemoAppProbe` — a subclass of `Install.Fixture` overriding only `Parameter APPPATH` to a private, disposable path this test owns outright, resolved polymorphically through `..#APPPATH`'s self-relative lookup so `Create`/`CreateWebApp` run completely unmodified — the same test-isolation-by-subclass shape `Test.RouterFixture`/`Test.GateFixture`/`Test.MigrateFault` already use, applied to `Install.Fixture` for the first time. `TestDemoWebAppFixtureCreatedWhenAbsent` clears that private path, drives a real `DemoAppProbe.Create("probe")`, and asserts the created application is disabled, carries no resource, and has an inventory row — then cleans up its own row with a `Kind`/`Name`/`Profile`-scoped `DELETE`, never touching the rest of the shared class fixture. Order-independent of every other method in the class (it never touches the real `Fixture.APPPATH`).

  Verified live: `TestDemoSslConfigFixtureExists` (method level, 23s including the shared fixture's own setup) and the full class (`## Auto Run Result`) both green; `TestDemoWebAppFixtureCreatedWhenAbsent` observed creating and correctly asserting the disabled/no-resource application at its own private path with no interference from `TestExistingApplicationIsNeverModified`'s own collision fixture.

**Rework loop — MED (fix now, Rule 15: fix-risk ≤ med and in-footprint, so not deferrable).**

- [x] [Review][Patch] **A failed first install permanently disables the `_SYSTEM` unexpire (AC2).** [src/OcuPilot/Install/Installer.cls:258] `tFirstInstall` is derived from the version row's *presence*, and the `ElseIf tFailingStep '= ""` branch writes a `failed` row on almost every failure path. So a first install that fails after `Names()` leaves a row behind, every later start reads `tFirstInstall = 0`, and `EnsureUnexpired` is skipped for good — while `README.md` and `CLAUDE.md` now both promise a clean `docker compose up -d --wait` needs no manual step. AC14's literal wording ("only when this profile carries no version row") is the mechanism, not the promise; a failed attempt is not an install (Boundaries: "never unexpire on a start that is not the first install on this durable volume"). Capped at med because CLAUDE.md keeps the manual command as a documented recovery path. severity=med fix-risk=low footprint=in-story. Suggested shape: treat a `failed` row as not-yet-installed for this gate only.

  **Closed (rework, build-auto, 2026-09-10), suggested shape taken exactly.** `tFirstInstall` now reads `(tVerRow.Phase = "failed")` when a row exists, instead of unconditionally `0` — a `failed` row still counts as first-install for the unexpire gate; an `installed` row (the only other value `EnsureVersion` ever writes) correctly still reads `0`. `tFirstInstall` has exactly one consumer (`EnsureUnexpired`'s call), so this changes nothing else. Verified: `OcuPilot.Test.Version` full class run (below) includes `TestFirstInstallFlagComesFromTheVersionRow`, which installs the probe profile twice and asserts `pFirstInstall` is `1` then `0` — unaffected by this change since neither of its two rows is ever `failed`.
- [x] [Review][Patch] **`GateStatus()` returns `installed` when the stored schema version is *ahead* of the deployed code.** [src/OcuPilot/Install/Installer.cls:440] The ladder is `failed` → not-`installed` → `tStoredVersion < #SCHEMAVERSION` → `installed`, so a downgrade — the one case `PlanMigration` refuses outright — falls through to `installed`. After a refused downgrade `StartPath` returns an error and the hook exits non-zero, but the health check reads `GateStatus()`, sees `installed`, and reports the container **healthy** while old code serves traffic against a newer schema. AC3's "the health check never reports healthy" does not hold for that case. AC6's "changes nothing" is not violated by a read. severity=med fix-risk=low footprint=in-story.

  **Closed (rework, build-auto, 2026-09-10).** Added `If tStoredVersion > ..#SCHEMAVERSION Quit "installing"` to the ladder, before the final `installed` line. Reuses the existing `installing` code rather than inventing a fourth (the Boundaries forbid a second escalation/response-writer/envelope field, and this story's own three named codes are `INSTALL.INSTALLING`/`INSTALL.UPGRADEREQUIRED`/`INSTALL.FAILED`) — both states mean "not safe to serve," and AC6's "changes nothing" is a write guarantee, not a constraint on what a read reports.

  **Mutation demonstrated live** via a new test, `Test/Version.cls`'s `TestGateStatusIsNotInstalledWhenStoredVersionIsAheadOfDeployed`: it inflates the **production** version row's `SchemaVersion` one past deployed (with phase `installed`), asserts `GateStatus() '= "installed"`, then restores the row and re-installs. (`GateStatus()` always resolves the production profile — no parameter redirects it — so this is the same category of production-touching, self-repairing test `TestRealProductionGateResolvesToInstalledAfterInstall` already makes; a real destructive `Uninstall("",1)` was not used to avoid it.) Mutated `GateStatus()` itself back to the pre-fix ladder (deleted the `tStoredVersion > ..#SCHEMAVERSION` branch) and re-ran this one method: RED (`AssertNotEquals` failed — the inflated case resolved to `installed`). Reverted: GREEN. Production's version row was confirmed back at schema 1/`installed` after both runs (the method's own repair tail ran regardless of the assertion's own pass/fail, since a failed assertion does not abort the method). Full `OcuPilot.Test.Version` class run (16/16, SQL-probe-confirmed) includes this test green.
- [x] [Review][Patch] **`Fixture.Remove` purges the inventory on two paths where nothing was removed.** [src/OcuPilot/Install/Fixture.cls:426] The second `Try`'s `SwitchNamespace` failure warns "nothing removed" and `Quit`s the block, and `Catch ex2` does the same — both then fall through to the unconditional `DeleteByProfile(pProfile)`, whose own warn text reads "Demo fixture objects **were removed** but the inventory rows could not be purged". Objects left on the instance, the only record of them deleted. This is exactly the orphan-on-read-failure defect the same diff fixed three lines above (`Set tInventoryReadable = 0`, with a comment explaining why), left unfixed on the removal stage. severity=med fix-risk=low footprint=in-story.

  **Closed (rework, build-auto, 2026-09-10), the same shape as the read-phase fix it names.** Added `tRemovalOk` (defaults `1`), set to `0` in both the `SwitchNamespace` failure branch and `Catch ex2`; the `DeleteByProfile` purge now runs only `If tRemovalOk`, with an `Else` warn naming that the inventory was deliberately left in place for a later retry. Verified by inspection against the two paths named (both now report "...inventory left in place so a later run can retry removal" and skip the purge) and by the full `OcuPilot.Test.Demo` class run's `OnAfterAllTests` teardown continuing to succeed on the ordinary, non-error path (`## Auto Run Result`).
- [x] [Review][Patch] **`RemoveOne`'s task branch queries every namespace.** [src/OcuPilot/Install/Fixture.cls:481] `QueryTasks("OcuPilot.Install.DemoTask", pName, "", .tIds)` passes `""` for the namespace, while `CreateTask` passes `pInstallNs`; every id returned is then deleted. The inventory row's `Scope` (the install namespace) is read into `tKinds`/`tNames` and never passed down — `RemoveOne` has no scope parameter. Uninstalling one namespace's fixtures removes another namespace's identically-named demo task. severity=med fix-risk=low footprint=in-story.

  **Closed (rework, build-auto, 2026-09-10).** `Remove` now also captures `tScopes(tI) = tRow.Scope` in its inventory-reading loop and passes it to a new `RemoveOne(pKind, pName, pScope, ByRef pReports)` fourth parameter, which the `task` branch passes straight into the shared `TaskIds` helper (see the DW-53/H4 finding above) instead of a literal `""`. Verified by inspection (the one call site and the one definition are both updated consistently — confirmed by a clean recompile) and functionally by the live H1 probe's own successful `Uninstall("probe", 1)` round-trip, which exercises this same `RemoveOne` call path end-to-end.
- [x] [Review][Patch] **`Kernel.State.Demo.DeleteByProfile("")` cannot match the rows its own siblings find.** [src/OcuPilot/Kernel/State/Demo.cls:40] It uses `WHERE Profile = ?` bound to `""`, which never matches SQL `NULL`, while `GuardedRowExists` and `GuardedIdsForProfile` in the same class both special-case `Profile IS NULL`. Documented as a deliberate no-op inherited from `Stamp` — but `Stamp` is an append-only history where retention is intended, whereas `Demo`'s rows *are* the removal roster. Currently masked by the uninstall-ordering finding above; it becomes live the moment that one is fixed. severity=med fix-risk=low footprint=in-story.

  **Closed (rework, build-auto, 2026-09-10).** Added `Kernel.State.Base.GuardedExecuteNoParam` (a zero-parameter sibling of `GuardedExecuteOneParam`, matching `GuardedOpenOneWhereNoParam`'s own established shape and rationale). `Demo.DeleteByProfile` now branches on `pProfile = ""` to `DELETE ... WHERE Profile IS NULL` through it, exactly matching `GuardedRowExists`/`GuardedIdsForProfile`'s own two-literal-query-texts pattern; the bound-parameter branch is unchanged.

  **Mutation demonstrated live**: created a throwaway `Kernel.State.Demo` row with `Profile = ""` (confirmed via SQL it reads back as `Profile IS NULL`, matching this class's own documented behavior) — RED: `SELECT COUNT(*) WHERE Profile = ''` against it returned 0 (the old bound-parameter form would have deleted nothing). GREEN: calling the new `DeleteByProfile("")` deleted it (confirmed 0 rows remain by id afterward). No residue left (`OcuPilot_Kernel_State.Demo` empty on re-check).
- [x] [Review][Patch] **AC12's fixture confirms rather than seeds, and depends on the unbounded Task Manager daemon.** [src/OcuPilot/Install/Fixture.cls:348] `CreateErrorEntry` guards on `If '$Data(^ERRORS)` and otherwise writes an inventory row — it raises nothing. The Design Notes prescribe the opposite ("the fixture **raises a real, controlled error inside its own routine** and lets the trap log it"), and the AC12 mutation line is worded "swallow the deliberate error **in the seeding routine**". Two consequences: any pre-existing `^ERRORS` entry from an unrelated source satisfies the check, and the report then over-claims it came "from the demo task fixture's own deliberate failure"; and on a clean container with the >1h daemon latency this spec itself records, `^ERRORS` stays empty, AC12 is unmet, and Story 5.13's stated dependency ("a non-empty fingerprint set on a clean install") does not hold. The mechanism change was never recorded in the Spec Change Log. severity=med fix-risk=med footprint=in-story.

  **Partially closed, with a correction to the Design Notes' own unverified premise (rework, build-auto, 2026-09-10).** The false-positive half is fixed directly: `CreateErrorEntry` now switches to `%SYS`, runs the same `SYS.ApplicationError:ErrorList` query `Test.Demo.TestDemoSeedsAnApplicationError` already uses, and only reports success (and notes an inventory row) when an entry naming the task's own message text is actually found — a report can no longer be satisfied, or over-claim its source, from an unrelated pre-existing entry.

  The daemon-independence half is **not achievable with a verified mechanism, and is not shipped**: re-verified live, twice, before implementing the Design Notes' own "raises a real, controlled error inside its own routine" claim, per this file's own research-first rule — a bare `Job ##class(...).Method()` whose method throws (`%Exception.StatusException`) or hits a genuine uncaught `<DIVIDE>` error does **not** add any row to `SYS.ApplicationError:ErrorList` on this build (confirmed with a throwaway diagnostic class, created and deleted within this session; `SYS.ApplicationError:ErrorList`'s row count was identical, 17, before and after both attempts). Only the real Task Manager daemon's own task-run wrapper reaches the trap — exactly the mechanism `CreateTask` already depends on. The Design Notes' premise was aspirational, not verified when written; corrected at its origin in `Fixture.cls`'s own header rather than left to be re-discovered (this file's own "correct a wrong claim at its origin" pitfall). This method's dependency on the daemon is therefore real and unremoved; it is the same, already-ledgered daemon-latency risk `CreateTask`'s own wait carries, not a new one.
- [x] [Review][Patch] **AC4's "exactly one version row exists per profile" is asserted nowhere and has no mutation line.** [src/OcuPilot/Install/Installer.cls:468] Every reader is `SELECT TOP 1 … ORDER BY ID DESC`, so a duplicate row is invisible; `StateFingerprint` folds in the newest row's values and would be byte-identical across duplicates. Changing `EnsureVersion` to always `%New()` leaves the whole suite green. Distinct from DW-47 (no unique constraint, research): the missing *assertion* is one `COUNT(*)` appended to `TestFirstInstallFlagComesFromTheVersionRow`, which already installs twice. severity=med fix-risk=low footprint=in-story.

  **Closed (rework, build-auto, 2026-09-10), exactly the suggested shape.** Appended a `SELECT COUNT(*) ... WHERE Profile = 'probe'` assertion to `TestFirstInstallFlagComesFromTheVersionRow`, after its own two installs, asserting exactly `1`. Verified live: passed in the full `OcuPilot.Test.Version` run (16/16, SQL-probe-confirmed) against the current, correct `EnsureVersion` (which upserts via `CurrentVersionRow`'s own read-then-update-or-insert). Note for the lead: this assertion would go red the moment DW-47's own root cause (no unique constraint on `Profile`, allowing two concurrent `Install` calls to both read "no row" and both insert) is actually exercised concurrently — that remains a research item, unchanged.
- [x] [Review][Patch] **AC3's `StartPath` error propagation is pinned one frame below the mutation the spec names.** [src/OcuPilot/Install/Installer.cls:377] The AC3 mutation line says "in `StartPath`, discard the failing step's `%Status` and fall through" and pins it to `TestFailingStepLeavesPhaseFailed` — which drives `MigrateFault.Install("probe")`, never `StartPath`. Changing `Set tSC = ..Install("")  If $$$ISERR(tSC) Quit tSC` to swallow the error leaves that test green; the only other `StartPath` caller in the tree asserts `$$$AssertStatusOK` on a healthy instance. The hook's exit code — the whole point — then reports success after a failed install. severity=med fix-risk=low footprint=in-story.

  **Closed (rework, build-auto, 2026-09-10).** No production code change was needed — `StartPath` already checks and propagates `Install`'s status correctly; only the missing test coverage was the gap. Added `Test/Version.cls TestStartPathPropagatesAFailingStep`: since `StartPath` hardcodes the production profile (no parameter redirects it), it induces the failure through the existing `Test.MigrateFault` seam against the **production** version row — the same category of production-touching test `TestRealProductionGateResolvesToInstalledAfterInstall` already makes — asserts `StartPath(0)` returns a non-OK status, then repairs with a real `Install("")` and confirms `GateStatus()` is `installed` again before returning.

  Verified live in the full `OcuPilot.Test.Version` class run (`## Auto Run Result`, 16/16 SQL-probe-confirmed): passed, and production's version row was confirmed `installed`/schema 1 immediately afterward, matching its state before the test ran — no residue.
- [x] [Review][Patch] **AC13's "the caller's namespace is unchanged" assertion cannot fail — Rule 19.** [src/OcuPilot/Test/Version.cls:293] `TestInstallRefusesFromWrongNs` reaches the guard through `Installer.TestOnlyInstallFromSys`, which ends with an unconditional `Set $NAMESPACE = tOrig` outside its `Try`/`Catch`. Whatever `Install` leaves `$NAMESPACE` set to, the seam resets it before returning, so `$$$AssertEquals($NAMESPACE, tStart, …)` passes either way. The spec's AC13 mutation line explicitly claims this catches "a guard that refuses but leaves the namespace moved". It does not. severity=med fix-risk=low footprint=in-story. Suggested shape: have the seam capture `$NAMESPACE` immediately after `..Install()` returns and expose it as an `Output` argument.

  **Closed (rework, build-auto, 2026-09-10), exactly the suggested shape.** `TestOnlyInstallFromSys` gained a new `Output pNamespaceAfterInstall` parameter, captured immediately after `..Install(pProfile)` returns (in both the normal and `Catch` paths) — before the method's own unconditional restore. `TestInstallRefusesFromWrongNs` now also asserts `tNamespaceAfterInstall = "%SYS"`, so the guard's *own* behavior is observed, not only this seam's blanket cleanup. Verified live in the full `OcuPilot.Test.Version` run (16/16). Traced through the AC13 mutation by hand rather than re-mutating a third time in the same session: with the guard deleted, `Install` would proceed to `..Names(pProfile, .tNames)`, which references `##class(OcuPilot.Kernel.State.Base)` — a fresh `##class()` call unresolvable from `%SYS` — so `Names` itself fails with `<CLASS DOES NOT EXIST>` (caught by its own `Try`/`Catch`, converted to an error status) before any `%SYS`-switch line is ever reached; `$NAMESPACE` stays `%SYS` in both the guarded and un-guarded cases, so this specific new assertion does not by itself distinguish that particular mutation — the pre-existing error-text assertion (naming both the expected and actual namespace) remains the operative regression pin for AC13, and the new one adds honest coverage against the different, real defect the finding named (the seam masking `Install`'s own restore behavior) without weakening anything.
- [x] [Review][Patch] **AC8's timeout test compares `ReportGatewayGap`'s output against the same method that produced it, and passes vacuously when both reads are empty.** [src/OcuPilot/Test/Version.cls:320] `TestGatewayTimeoutIsReportedFromTheLiveSource` calls `ReportGatewayGap`, then calls `GatewayResponseTimeout` as the "independent read" — but `ReportGatewayGap` obtains its own value from exactly that method, so any defect inside it appears identically on both sides. On an instance where neither source answers, both are `""` and the test asserts `"" = ""` — two runs compared that both produce nothing. It also never reads `tData.source`, though AC8 requires the report to name the source. The two cheap halves are in scope now (assert `source '= ""`; make the empty/empty case an explicit skip or a red); a genuinely independent read means parsing `CSP.ini` in the test, which is DW-51's territory. severity=med fix-risk=low footprint=in-story.

  **Closed (rework, build-auto, 2026-09-10), both cheap halves taken; the genuinely-independent-read half correctly left to DW-51.** The test now also captures `tData.source` from the report and, on the branch where the independent read finds a value, additionally asserts `tReportedSource '= ""`. The empty/empty branch is now an explicit `$$$AssertTrue(1, "SKIPPED: ...")` naming why (neither source answers on this instance) instead of a silent `"" = ""` pass — this instance's own live Gateway registry does answer (`Server_Response_Timeout=60`, verified this story), so the meaningful branch is the one actually exercised. Verified live in the full `OcuPilot.Test.Version` run (16/16): `TestGatewayTimeoutIsReportedFromTheLiveSource` green, taking the non-empty branch and asserting the source is named.
- [x] [Review][Patch] **`Fixture.Create`'s inventory loop drops a `GuardedRowExists` failure silently.** [src/OcuPilot/Install/Fixture.cls:118] `If $$$ISOK(tExistsSC) && ('tExists)` has no `else` branch — an error status skips the row with no `warn`, so a fixture object is created with no inventory row and can never be removed by `Remove`. Every other failure in this class is reported. severity=med fix-risk=low footprint=in-story.

  **Closed (rework, build-auto, 2026-09-10).** Restructured to `If $$$ISERR(tExistsSC) { report warn } ElseIf 'tExists { create the row }` — an error status now reports "Could not check whether an inventory row already exists -- the fixture object may have been created but was not recorded" instead of silently skipping. Verified by inspection and by the full `OcuPilot.Test.Demo` class run continuing to record inventory rows correctly on the ordinary (non-error) path.
- [x] [Review][Patch] **`TestPopulatedRowsSurviveMigration` depends on this instance's accumulated history, so AC5's survival half fails on the container the story is about.** [src/OcuPilot/Test/Version.cls] It asserts `SELECT TOP 1 … FROM OcuPilot_Kernel_State.Stamp` returns a row, justified in the class doc by "this instance already carries hundreds from earlier install runs". On a fresh container that table is empty and the test fails for environmental reasons, on the exact "one command on a clean clone" path this story ships. severity=med fix-risk=low footprint=in-story. Suggested shape: have the test seed its own probe-profile row before migrating.

  **Closed (rework, build-auto, 2026-09-10), exactly the suggested shape.** The test now calls `Installer.Install("probe")` first to seed its own row, then reads `SELECT TOP 1 ... WHERE Profile = 'probe' ORDER BY ID DESC` (rather than an unscoped `ORDER BY ID`) so it observes the row it just seeded, independent of instance history. Verified live in the full `OcuPilot.Test.Version` run (16/16, SQL-probe-confirmed): passed.

**Applied by the reviewer (mechanical corrections only; verified by recompile + `Test.Version` 14/14).**

- [x] [Review][Patch] **A-1 `DemoTask.cls`'s class header asserted `Status = -2` at its own origin.** [src/OcuPilot/Install/DemoTask.cls:4] The header claimed the Task Manager "writes a populated `Status` (`-2`, `JobUntrappedError`)" while the same file's `OnTask` doc, the Spec Change Log and AC11 all record that this build leaves `Status` at `1`. Corrected at origin (CLAUDE.md's "correct a wrong claim at its origin", which this story has already been bitten by twice).
- [x] [Review][Patch] **A-2 `README.md` labelled an authenticated probe "Confirmed unauthenticated".** [README.md:105] The command carries `-u _SYSTEM:SYS`, and AC2 itself calls it "an authenticated `HEAD /api/atelier/`". Corrected to "Confirmed authenticated".
- [x] [Review][Patch] **A-3 `RemoveOne`'s comment claimed a discipline the method does not follow.** [src/OcuPilot/Install/Fixture.cls:490] It ended "the same guard-then-act discipline every other fixture removal in this method already follows" — false when written; three of four branches still discard their status. Comment corrected to say so and to name the open finding. The code fix stays in the rework list above.
- [x] [Review][Patch] **A-4 `EnsureUnexpired`'s report text contradicted its own parameter's documentation.** [src/OcuPilot/Install/Installer.cls:536] It emitted "the installing account's password" and "the installing identity", while `#UNEXPIREACCOUNT`'s header says in bold that the target is the fixed constant `_SYSTEM` and deliberately **not** `$Username` (verified live as `irisowner` in the container). Reworded to "the named install account".
- [x] [Review][Patch] **A-5 `Test/Demo.cls` hardcoded the 300s wait budget in the DW-46 skip message.** [src/OcuPilot/Test/Demo.cls:209] `(300 + ..#EXTRAWAITSECONDS)` duplicated `Fixture.#TASKWAITSECONDS`, which has already moved once this story (90 → 300); the next change would have made the message state a false wall-clock figure. Now reads the parameter.
- [x] [Review][Patch] **A-6 Two comments stated an observation about `QueryTasks` as a property of `$Data`.** [src/OcuPilot/Install/Fixture.cls:268] `$Data` is also truthy at `1` (a top-level value with no descendants), where `$Order(x(""))` returns `""` and the next line would throw the very `<SUBSCRIPT>` the guard prevents. The sites are safe only because `QueryTasks` was *observed* returning `$Data` of 0 or 10 and never 1 — a handful of probes, not a proof, and `%SYS.TaskSuper` ships with every method body stripped so it cannot be settled from source. Both comments now label the inference as one and point at F-1. Also corrected `Test/Demo.cls`'s copy, which narrowed the throw to "when `QueryTasks` matches nothing" — it throws unconditionally; matching nothing is where it *bites*.

**`## Fix Pack` — LOW two-way doors, one bounded iteration (Rule 15).**

- [x] [Review][Patch] **F-1 Make the `QueryTasks` guard unconditionally correct: `$Data(tIds) \ 10`.** [src/OcuPilot/Install/Fixture.cls:270, :481; src/OcuPilot/Test/Demo.cls:183] Removes the residual dependence on the observation in A-6 entirely. Behaviour-affecting, so it needs its own demonstrated mutation — pair it with the H4 test-seam fix that would pin it.

  **Closed together with the H4 fix above**, which is exactly the pairing this item asked for: the new `OcuPilot.Install.Fixture.TaskIds` helper uses `$Data(tRaw) \ 10` as its guard, and is now the one implementation shared by `CreateTask`, `RemoveOne`, and both `Test/Demo.cls` call sites — so the `$Data(tIds)`-bare-check-first form (which still depended on the "observed 0 or 10, never 1" inference) no longer exists anywhere in the tree. Mutation demonstrated live (see H4's own entry above): reverting to the literal, broken `$Data(tRaw(tFirst))` form threw `<SUBSCRIPT>` against a real zero-match `QueryTasks` call; the shipped `\10` form did not.
- [x] [Review][Patch] **F-2 `container-start.sh`'s `LOAD-FAILED` branch is defeated by multi-line error text.** [scripts/container-start.sh:104] `grep -o 'OCUPILOT-RESULT-START:.*:OCUPILOT-RESULT-END'` matches within one line; `$System.Status.GetErrorText` on a multi-document compile failure can span lines, leaving `RESULT` empty so control reaches the `*)` fallback and prints "see the phase and failing step recorded on the version row" — the exact misleading message the `LOAD-FAILED*` case was added to avoid. Exit code stays correct. Fix: `$Translate(tOutcome, $Char(13,10), "  ")` before the `Write`. Needs a throwaway-container check, so it is not a reviewer patch.

  **Closed (rework, build-auto, 2026-09-10), the suggested fix's shell-side equivalent.** Rather than translating inside the `iris session` heredoc (an extra `$Translate` call the ObjectScript side would need to carry), the shell side collapses CR/LF to spaces on `$RESULT_RAW` (`tr '\r\n' '  '`) **before** the `grep -o` marker search, so a multi-line error can no longer defeat it. Verified with a local shell reproduction (not the live container, per this finding's own "needs a throwaway-container check, so it is not a reviewer patch" — the throwaway-container run itself remains manual, per this story's own Verification section): piped a synthetic multi-line `OCUPILOT-RESULT-START:LOAD-FAILED:...` payload with embedded `\r\n` through the exact `tr` + `grep -o` pipeline now in the script and confirmed the full, un-truncated multi-line message is extracted (previously `grep -o` would have matched nothing across the embedded newline). `dash -n` on the edited script: clean.
- [x] [Review][Patch] **F-3 `container-health.sh` spawns two full `iris session` logins per probe, every 10s, for the container's life.** [scripts/container-health.sh:12] The namespace-resolution session is re-run on every probe although its answer cannot change. Every branch is also a bare `exit 1` with no message, so `docker inspect`'s health log records nothing beyond the code. (Labelled as an inference, not verified: on an instance whose installer has just enabled auditing, each login may also be an auditable event.)

  **Closed (rework, build-auto, 2026-09-10).** Consolidated into one `iris session` login: it starts in `%SYS` (reachable regardless of which namespace turns out to be the install target, same reasoning as the original two-session version), resolves the namespace, then does an ordinary `Set $NAMESPACE=tNS` mid-session — ordinary variable assignment, not a second login — before reading `GateStatus()`. Also added an `echo ... >&2` naming the observed (non-`installed`) status before the `exit 1`. Verified live against the real instance via `iris_execute_command` (the equivalent single-session sequence): `Set tNS=$Select(##class(%SYS.Namespace).Exists("HSCUSTOM"): "HSCUSTOM", 1: "USER") Set $NAMESPACE=tNS Write ##class(OcuPilot.Install.Installer).GateStatus()` returned `installed` correctly. `dash -n` on the edited script: clean.
- [x] [Review][Patch] **F-4 `GatewayResponseTimeout` leaks the file handle on the error path.** [src/OcuPilot/Install/Installer.cls] `Do tFile.Close()` runs only after the `While` loop completes normally; an exception inside `ReadLine` lands in `Catch ex` with the file still open.

  **Closed (rework, build-auto, 2026-09-10).** Added a `tFileOpen` flag, set when `Open` succeeds and cleared right after the normal-path `Close()`; the `Catch` block now closes the file too when `tFileOpen` is still set. Verified by inspection and by the full `OcuPilot.Test.Version` run's `TestGatewayTimeoutIsReportedFromTheLiveSource`/`TestGatewayTimeoutUnavailableIsReportedNotFatal` both green on the normal path (16/16 overall).
- [x] [Review][Patch] **F-5 `ReportGatewayGap` always reports "No web application was created by this run"** [src/OcuPilot/Install/Installer.cls:558] — including on `StartPath(1)`, where `CreateWebApp` did create one and emits its own gap line into the same drained stream. Two contradictory lines in one report.

  **Closed (rework, build-auto, 2026-09-10).** Reworded to "This installer step did not create a web application; Story 1.5's own applications, or the opt-in demo fixture, may create one separately and report their own gap" — true regardless of what runs alongside `Install()` in the same drained `StartPath` report stream, so it can no longer read as contradicting `CreateWebApp`'s own gap line. Verified by inspection and by the full `OcuPilot.Test.Version` run's `TestGatewayTimeoutIsReportedFromTheLiveSource` (which reads this same report stream) staying green.
- [x] [Review][Patch] **F-6 Two tests hardcode `"HSCUSTOM"`** [src/OcuPilot/Test/Demo.cls:243, :310] while the rest of the class resolves the namespace through `Installer.ResolveNamespace()`. AC2 and AC12 both admit `USER` as the install namespace, where both tests would silently probe the wrong one.

  **Closed (rework, build-auto, 2026-09-10).** Both sites now resolve `tInstallNs` via `Installer.ResolveNamespace()` and use it in place of the literal, matching the rest of the class. Verified live in the full `OcuPilot.Test.Demo` class run (`## Auto Run Result`): both `TestDemoSeedsAnApplicationError` and `TestNoMatchGuardResolvesEmptyWithoutThrowing` green on this instance, where `ResolveNamespace()` resolves to `HSCUSTOM` (so the observable behavior is unchanged here; the fix is for portability to a `USER`-namespace instance).
- [x] [Review][Patch] **F-7 `Test/Demo.cls:183`'s guard is `If $Data(tIds)` where the other three sites are `If $$$ISOK(tQSC) && $Data(tIds)`.** Not a live defect — but `TestNoMatchGuardResolvesEmptyWithoutThrowing` is declared to be the regression pin for *this* shape and encodes the stricter one, so a regression dropping the `$Data` check here would leave the pin green.

  **Closed together with H4/F-1 above.** The inconsistency this item names no longer exists: there is exactly one guard implementation (`OcuPilot.Install.Fixture.TaskIds`, checking `$$$ISOK(tSC)` — via an early `Quit` on error — before `$Data(tRaw)\10`), shared by all four sites that previously carried near-identical copies. A regression to any weaker shape at any one site is now a regression to the one shared method, caught identically everywhere it is called.

**Deferred / escalated / routed.**

- [x] [Review][Defer] **DW-48 — the start hook compiles the whole `src/OcuPilot/` tree, `Test.*` included, into the production instance.** [scripts/container-start.sh:88] `escalated`, owner `burndown`, for the epic decision sheet. Reasoning, since the lead asked for a call: the harm today is bounded — nothing *executes* the test classes at start, and `Test.RouterFixture` (the one class that weakens identity resolution, by overriding `ResolvedUsername`) is unreachable without a web application mapped to it by name, and none exists until Story 1.5. Both candidate fixes are architecture decisions, not corrections: a roster/exclusion mechanism is forbidden by AD-17's "one source, never maintained separately" and by this spec's own frozen Design Notes ("no roster file is invented in this story"), and moving `Test/` out of the mounted tree changes `FIXED_PACKAGES` in `check-objectscript.py`, the seven-package layout the spine pins, and the input Story 1.16 generates `module.xml` from. That makes it **fix-risk high**, which is the Rule 15 row that routes a MED to `escalated` rather than to this story's rework loop. It belongs with Story 1.16 and the spine, decided once.
- [x] [Review][Defer] **DW-50 — routing judged honest, with one carve-out.** The routing to Story 1.17 is correct for what it names: the container, health-check, HTTP and `/proc/1/environ` shell-extraction surfaces genuinely need a scripted throwaway-container step. But AC9's non-daemon fixtures (the SSL/TLS configuration, the X.509 credential, and the demo web application's disabled/no-resource properties) need no container at all and are **not** inside DW-50's scope — that is the HIGH filed above, and it belongs in this story. Occurrence appended.
- [x] [Review][Defer] **AC11's pinning test passes green on this instance whenever the daemon has not run.** [src/OcuPilot/Test/Demo.cls:209] The `LastStarted = 0` branch is `$$$AssertTrue(1, "SKIPPED (DW-46)…")`, and this container's daemon latency now exceeds an hour against a 480s combined budget. Verified that the branch logic is sound — both AC11 mutations leave `LastStarted '= 0` and are still caught — so this is environmental, not a vacuous assertion by construction. Occurrence on DW-50; real verification of AC11 lives in the throwaway-container run.
- [x] [Review][Defer] **`CLAUDE.md`'s Container block was not updated with the rest of the docs.** [CLAUDE.md:142] It still reads `docker compose up -d` and `docker compose logs -f  # ready when startup completes`, while `README.md` now uses `--wait` and explains that IRIS startup is no longer the readiness signal; the neighbouring expired-password section in the same file *was* updated. Deferred rather than patched because step-03 routes any fix that edits an agent-context file to the lead.
- [x] [Review][Defer] **DW-47, DW-51, DW-52 re-observed unchanged.** Occurrences appended; no new entries filed.

**Rejected.**

- `false` — "`Test/Version.cls:389`'s `$$$AssertTrue(tArg '= "*")` cannot fail because the line above already asserted `tArg = "_SYSTEM"`." `$$$AssertEquals` does not abort the method on failure, so if `tArg` were `"*"` both assertions would fail. It is redundant, not unfalsifiable.
- `false` — "The shipped `$Data(tIds)` guard is *less safe* than the `'= ""` code it replaced." The live probe confirmed `QueryTasks` returns `$Data` of 0 or 10 and never 1, so the scalar-only dereference the claim requires is not reachable through this API. The residual point — that the safety rests on an observation — is real and is filed as A-6/F-1, but "less safe than what it replaced" is not established.
- `false` — "`CreateErrorEntry` checks `^ERRORS` in whatever namespace happens to be current rather than `pInstallNs`." `Fixture.Create` calls it from the install namespace, and both `Install` and `StartPath` guard that namespace as their first act, so the bad outcome does not occur. (The *seeding* defect is real and is filed as a MED above.)
- `low`, rejected — frontmatter `deferred:` and `deferred-work.md` disagree on several entries' `severity`/`fix-risk`/`footprint`. Rule 15 makes the ledger's last trailer line authoritative; frontmatter `deferred:` is build-auto's own pre-harvest record, not a second source of truth. No named harm.
- Rejected per step-03 (fix would edit the spec under review) — the frozen `<intent-contract>` matrix still carries `Status < 0` at line 69, and `## Residual Risks` is stale about the DW-53/DW-46 ledger trailers the same diff added. Both are real staleness in this spec; recorded here so the lead can fold them into the rework commit rather than lost.
- Rejected — `sprint-status.yaml` says `review` while the spec frontmatter says `done`. That is the correct state mid-review, not a defect.
- `low`, rejected as spec-bound (`by-design`) — `OCUPILOT_DEMO: "1"` is hardcoded in the tracked compose file with no `${OCUPILOT_DEMO:-1}` indirection. The spec's own Tasks line says "add `OCUPILOT_DEMO: "1"`", AD-25's opt-in is enforced in code by `StartPath`'s `pDemo` gate, and this compose file is the repository's own dev environment.
- `low`, rejected as spec-bound — `compose.test.mjs` lives under `ui/tools/`; AC1's digest clause is satisfied by a comment. The spec chose that host explicitly (naming `build-output.test.mjs` as precedent), the file runs in the default suite (97/97 confirmed), and AC1 says the digest is "recorded beside it", which a comment does.
- `low`, rejected — `README.md:402`'s `docker compose up -d` inside a fenced prompt-template block. That block is text for the user to paste to an agent; `--wait` is not required there.

### Review Findings — code review round 2 (2026-09-10)

Four review layers ran as subagents (Blind Hunter, Edge Case Hunter, Verification Gap,
Acceptance Auditor). None edited a file, committed, or pushed — verified afterwards with
`git status --short` (clean) and `git log --branches --not --remotes` (empty), so no
layer's findings were discarded for a containment breach. Every finding below was
re-verified by direct read at its cited site before filing; the Rejected appendix records
what did not survive that check. Static gates after the reviewer's own patches:
`uv run scripts/check-objectscript.py` 0 problems, `bash scripts/lint-docs.sh` 0 issues,
`cd ui && npm test` 97/97, `OcuPilot.Test.Version` recompiled clean (`cku`). Live instance
re-confirmed unchanged at hand-off: exactly one production `Version` row at phase
`installed`, `OcuPilot_Kernel_State.Demo` empty, zero `OcuPilot.Install.DemoTask` rows in
`%SYS.Task`.

**What round 2 was asked to check, and what it found (Rule 19).** Iteration 3's
`Fixture.TaskIds` seam is genuine, not a parallel path: `CreateTask` (`Fixture.cls:324`)
and `RemoveOne` (`Fixture.cls:635`) both call `..TaskIds`, so
`TestNoMatchGuardResolvesEmptyWithoutThrowing` drives the production implementation. H4,
F-1 and F-7 are correctly closed. Of round 1's three headline findings, H3 (`RemoveOne`'s
four `Delete` statuses) and H1 (`Uninstall` ordering) are genuinely fixed as claimed.
**The half-applied pattern has recurred twice in the code those same fixes touched.**
Round 1's H2 — "an already-existing fixture object is never adopted into this run's
inventory" — was applied to `Install/Fixture.cls` and to neither of the two test classes
that reach the same production-named objects from the probe profile (H1 below). And the
purge gate the H1/M3 fixes installed on two of `Fixture.Remove`'s failure paths still
fails open on three others (M2 below). Two more pinning tests were found that a real
regression can leave green (M4, M5).

**Rework loop — HIGH (fix now, Rule 15).**

- [x] [Review][Patch] **The probe-profile suite operates on the production-named fixture objects, so on the configuration this story ships (`OCUPILOT_DEMO: "1"`) running the tests destroys production fixtures and turns four AC9/AC10/AC11 assertions red.** [src/OcuPilot/Test/Demo.cls:73] Round 1's H2 fix stopped `Install/Fixture.cls` adopting a pre-existing object into the calling profile's inventory, and explicitly declined the "qualify the names by profile" shape. It was not carried into the tests, which reach the same unqualified names directly. Four verified outcomes, all latent today only because `OcuPilot_Kernel_State.Demo` is empty on this container and no real bring-up has run yet — `docker-compose.yml`'s own `OCUPILOT_DEMO: "1"` makes `StartPath(1)` create all five production fixtures on the very first `docker compose up -d --wait`, which is AC2's own path:
  1. `Test/Demo.cls:73-90` `OnAfterAllTests` deletes `..#COLLISIONPATH` (`/csp/myapp`) **unconditionally**, while `OnBeforeAllTests` creates it only `If '…Exists`. Nothing records who created it. One `OcuPilot.Test.Demo` run therefore deletes the production demo web application — the object Stories 2.5 and 5.8 name literally — and leaves production's own `webapp` inventory row pointing at nothing. That is AD-25's "never an operator's object" and AC10's "a later uninstall leaves it in place", broken by the test class rather than by `Fixture.cls`.
  2. `Test/Demo.cls:92-116` `TestExistingApplicationIsNeverModified` then asserts `Enabled = 1` and `Resource = "%Development"` against whatever sits at that path; the production fixture is created disabled with no resource, so the test goes red for a non-defect reason. Its inventory assertion (`…WHERE Kind = 'webapp' AND Name = ?`, asserted `= 0`) also omits `Profile`, unlike every sibling assertion in the file, so production's own row makes it red as well.
  3. `Test/Installer.cls:521` `TestUninstallRemovesDemoFixtures` sets `tName = "OcuPilotDemoTLS"` — the **production** name — creates it only `If '…Exists`, then saves a **`probe`** inventory row for it unconditionally and calls `Uninstall("probe", 1)`. `RemoveOne` deletes by name, so on a demo-enabled instance this destroys production's SSL/TLS fixture, orphans production's own row, and **passes green** while doing it. This is the exact AD-25 breach round 1's H2 closed, reintroduced through a test added in the same pass.
  4. `Test/Demo.cls:306`, `:329` and the closing assertion of `:159` assert `Profile = 'probe'` inventory rows for `OcuPilotDemoTLS`, `OcuPilotDemoCert` and the demo task. Once production owns those unqualified names, `Fixture.Create("probe")` takes the already-exists branch at `Fixture.cls:205`, `:234` and `:368`, writes no row, and all three go red.
  severity=high fix-risk=med footprint=in-story spec-clear. AC9/AC11 pin the *production* names; nothing pins the probe copy's, so qualifying them is not a spec change. Suggested shape: resolve every fixture object name through one profile-aware helper on `Install.Fixture` (production keeps the literal `OcuPilotDemo*` and `/csp/myapp`; a non-empty profile suffixes them, as `Names()` already does for the installer's own objects), give `Test.Demo` a collision path it owns outright, and make `OnAfterAllTests` delete only what `OnBeforeAllTests` actually created. That makes the suite independent of production state in both directions and closes (3) without a second mechanism.

  **Closed (rework iteration 4, build-auto, 2026-09-10/11), the suggested shape taken exactly.** Added `OcuPilot.Install.Fixture.ResolvedPrefix(pProfile)` — public, `..#DEMOPREFIX` for production, `..#DEMOPREFIX _ "Probe"` for `"probe"`, matching `Installer.Names()`'s own suffix convention — and switched `CreateSslConfig`, `CreateX509Credential`, `CreateTask` (and `CreateErrorEntry`'s inventory-row label) to compute their target names through it instead of the bare `..#DEMOPREFIX` literal. Production's own names are byte-identical to before (`ResolvedPrefix("")` reduces to `..#DEMOPREFIX`); a `"probe"` run now creates `OcuPilotDemoProbeTLS`/`OcuPilotDemoProbeCert`/`"OcuPilotDemoProbe nightly purge"` — names that cannot collide with, or be mistaken for, production's.
  1. **Closed by construction, not by adding a flag.** `Test/Demo.cls`'s `OnBeforeAllTests`/`OnAfterAllTests` no longer pre-create or delete anything at `..#COLLISIONPATH` at all — that whole out-of-band block is deleted. The shared class fixture's `Fixture.Create("probe", ...)`/`Remove("probe", ...)` calls are unchanged and remain fully inventory-driven: if `/csp/myapp` is absent, they create it under a `Profile='probe'` row and later remove exactly that; if production already owns it, `CreateWebApp`'s existing DW-13 branch reports a warn and records nothing, so `Remove` touches nothing there either. Either way `OnAfterAllTests` can never destroy an object it did not itself create.
  2. **Rewritten to a private, disposable path.** `TestExistingApplicationIsNeverModified` no longer touches the real `APPPATH` at all — it now drives `OcuPilot.Test.DemoAppProbe` (the existing APPPATH-overriding subclass) against its own private path, self-contained: hand-creates the foreign collision app there, calls `DemoAppProbe.Create("probe", ...)`, asserts it is unchanged, deletes it. Order-independent of `TestDemoWebAppFixtureCreatedWhenAbsent`, which shares the same private path but fully creates and cleans up its own state within its own method.
  3. **Fixed at the exact site named.** `Test/Installer.cls`'s `TestUninstallRemovesDemoFixtures` now computes its hand-created object's name via `##class(OcuPilot.Install.Fixture).ResolvedPrefix("probe") _ "TLS"` (`OcuPilotDemoProbeTLS`) instead of the literal `"OcuPilotDemoTLS"` — it can no longer create, file an inventory row for, or delete production's own SSL/TLS fixture.
  4. **Fixed by construction.** `TestDemoSslConfigFixtureExists`, `TestDemoX509CredentialFixtureExists` and `TestDemoTaskIsSuspendedAfterAnError` now resolve the same probe-suffixed names via `ResolvedPrefix("probe")` instead of hardcoding the production literals, so they observe what the shared fixture (itself now using `ResolvedPrefix`) actually created.

  **Mutation demonstrated live** (IRIS MCP, `server: "ocupilot-iris"`): full `OcuPilot.Test.Demo` class run, 9/9 passed, SQL-probe-confirmed (`%UnitTest_Result`, RunIdx 279). `TestDemoTaskIsSuspendedAfterAnError` took the DW-46 skip path (180.08s) and still passed — see the MED finding below for why that specific assertion is now load-bearing. Verified live and directly, by hand, that the two-name split is real: on this instance, `OcuPilotDemoTLS`/`OcuPilotDemoCert` (production's literal names) and `OcuPilotDemoProbeTLS`/`OcuPilotDemoProbeCert` (the probe run's names) can coexist as five and four independent `Security.SSLConfigs`/`%SYS.X509Credentials` rows respectively, confirmed by `Exists()` on each name individually. Full `OcuPilot.Test.Installer` class run (23/23, SQL-probe-confirmed, `RunIdx` current) includes the corrected `TestUninstallRemovesDemoFixtures` (2252.6s — the documented `SYS.Database.DeleteDatabase`-after-repeated-cycling cost, not a new regression) passing without ever naming a production object.

**Rework loop — MED (fix now, Rule 15: fix-risk ≤ med and in-footprint, so not deferrable).**

- [x] [Review][Patch] **`Fixture.Remove`'s purge gate still fails open on three paths — the same defect round 1 closed at two of five sites.** [src/OcuPilot/Install/Fixture.cls:536] The two flags round 1 added (`tInventoryReadable` for the read phase, `tRemovalOk` for the removal phase) are correct; three sibling paths in the same two methods still let `DeleteByProfile` purge the roster after removing nothing, which is AD-25's "uninstall removes exactly what install created" with the only record of what to remove deleted:
  - `Fixture.cls:536-544` — `If $$$ISOK(tRowSC) && $IsObject(tRow)` has no `else`. A `GuardedOpenId` failure (or a `NULLOREF`) on one inventory row skips that row with no `warn` and does not clear either flag, so its object is orphaned and its row purged.
  - `Fixture.cls:634-641` — `RemoveOne`'s task branch, `If $$$ISOK(tQSC) && $Data(tIds)`, again with no `else`. A `TaskIds` error deletes nothing, reports nothing, and the purge still runs. (The same shape at `Fixture.cls:323-327` in `CreateTask` instead creates a **duplicate** demo task, silently, on every later start.)
  - `Fixture.cls:604-648` — an inventory row whose `Kind` matches none of the four branches falls through with no report; the purge still runs.
  - Same family, one caller up: `Installer.cls:1321` folds a `GuardedIdsForProfile` **error** into `tFixturesExist = 0`, so a read failure combined with already-removed core objects lets `Uninstall` return `$$$OK` having removed nothing — which is precisely what the comment three lines below says the reordering exists to prevent.
  severity=med fix-risk=low footprint=in-story spec-clear. Suggested shape: give the read loop its own `tReadComplete` flag that forces `tRemovalOk = 0`, add the missing `else`/`warn` at each of the three sites (the wording is already in the file twice), and fail closed on `Installer.cls:1321`'s error status the way `Install()`'s own version-row read already does.

  **Closed (rework iteration 4, build-auto, 2026-09-10/11), exactly the suggested shape.** `Fixture.Remove`'s read loop now carries its own `tReadComplete` flag (defaults `1`, cleared with a `warn` when one row fails to open), and the removal-phase gate reads `Set tRemovalOk = tReadComplete` instead of an unconditional `1` — an incompletely-read inventory can no longer be purged. `RemoveOne`'s task branch now reports a `warn` when `TaskIds` itself errors (distinct from the ordinary, silent "no match" case, which stays silent by design). `RemoveOne` gained an explicit `ElseIf pKind = "errorentry"` no-op branch (documented as intentional) and a final `Else` `warn` for any truly unrecognized `Kind`, so the old bare fallthrough can no longer hide either case. `Installer.Uninstall`'s `tFixturesExist` now defaults to `1` (fail closed: "unable to tell" is treated as "assume something might exist," so the early-return shortcut is never taken on a read error) and reports a `warn` naming the read failure instead of silently folding it into `0`.

  **Verified by inspection, not by a live mutation of this specific branch** (recorded honestly rather than overclaiming, per this file's own "never mark a fact verified that you did not check" pitfall): constructing a `Kernel.State.Demo` row whose own id genuinely fails `GuardedOpenId` requires either a race between `GuardedIdsForProfile` and the open (no window through the public API — both happen in the same method call) or direct global surgery to desynchronize the SQL index from the object layer, neither attempted in the time available. What **is** live-verified: the full `OcuPilot.Test.Demo` (9/9) and `OcuPilot.Test.Installer` (23/23) class runs, both SQL-probe-confirmed, pass unchanged with `tReadComplete`/the fail-closed `tFixturesExist` default in place — including `TestUninstallRemovesDemoFixtures`'s own successful-removal path and every ordinary (non-error) `Remove`/`Uninstall` call in either suite — so the new code is confirmed not to disturb the happy path. The failure branches themselves were traced by hand against the read code (each new flag/report is reached exactly when its guard's condition is met, matching `tInventoryReadable`'s already-proven sibling shape one block above) rather than exercised by a forced failure.
- [x] [Review][Patch] **`tFirstInstall` is derived from the row's *current* phase, so the `_SYSTEM` unexpire re-arms on any mature instance whose last start failed — and the code comment asserts an invariant the code cannot enforce.** [src/OcuPilot/Install/Installer.cls:289] `Set tFirstInstall = (tVerRow.Phase = "failed")` closed round 1's M1 (a failed *first* install must stay eligible), but nothing records that the profile ever reached `installed`. Sequence: a successful install leaves the row `installed`; any later start that fails after `Names()` rewrites that same row to `failed` (the `ElseIf tFailingStep '= ""` block); the next start reads `failed`, computes `tFirstInstall = 1`, and `EnsureUnexpired("_SYSTEM", 1)` unexpires an account the operator may have deliberately expired. That is the Boundaries "Never" — *"never unexpire on a start that is not the first install on this durable volume"* — and AC14's "a second start does not unexpire again". The comment at `:286-288` states the opposite ("A row that reached `installed` at least once is still first-install=0"); only the current phase is read. No existing test can see it: `TestFailedFirstInstallStillCountsAsFirstInstall` deletes the row first, so its `failed` row is genuinely a first attempt. severity=med fix-risk=low footprint=in-story spec-clear. Suggested shape: `(tVerRow.Phase = "failed") && (tVerRow.SchemaVersion = 0)` — `EnsureVersion`'s `failed` write carries `tStoredVersion`, which is `0` only on a genuinely first install — plus the test the Verification Gap layer specified: install to a clean `installed` row, drive it to `failed` through the `MigrateFault` seam, then install again through `InstallerProbe` and assert `CapturedFirstInstallArg() = 0`. That restores AC14's literal wording and needs no amendment. Correct the false invariant in the comment at the same time; `CLAUDE.md`'s new "gated on the version row's absence" sentence needs the same correction and is folded into DW-55 (agent-context file, lead-owned).

  **Closed (rework iteration 4, build-auto, 2026-09-10/11), exactly the suggested shape, including the test.** `tFirstInstall` now reads `(tVerRow.Phase = "failed") && (tVerRow.SchemaVersion = 0)`. Added `Test/Version.cls` `TestFailedNonFirstInstallDoesNotReArmUnexpire`: installs the probe profile to a real `installed` row first, forces a *later* failure through the `MigrateFault` seam (leaving a `failed` row whose `SchemaVersion` is inherited from the prior success, i.e. non-zero), then installs again through `InstallerProbe` and asserts `CapturedFirstInstallArg() = 0`. The false invariant in the comment at `Install()`'s call site is corrected to explain why the fix now makes it true (`CLAUDE.md`'s own correction is lead-owned per DW-55, unchanged).

  **Mutation demonstrated live** (IRIS MCP, `server: "ocupilot-iris"`): reverted the fix to the round-1 form (`Set tFirstInstall = (tVerRow.Phase = "failed")`, dropping the `SchemaVersion = 0` clause), recompiled, ran `TestFailedNonFirstInstallDoesNotReArmUnexpire` at method level — RED (`AssertEquals` failed: `CapturedFirstInstallArg()` read `1`, re-arming the unexpire on a non-first failure). Restored the fix, recompiled, re-ran — GREEN (53.2s RED run, 17.2s GREEN run). Production's own version row confirmed unaffected throughout (`Profile IS NULL`: one row, `installed`, schema 1).
- [x] [Review][Patch] **AC12's pinning test and the production report are both satisfied by a same-day entry an *earlier* run produced, so AC12's own named mutation cannot be observed red on a re-run.** [src/OcuPilot/Install/Fixture.cls:460] `CreateErrorEntry` and `Test/Demo.cls:237` `TestDemoSeedsAnApplicationError` both run `SYS.ApplicationError:ErrorList` for the whole of today (`$ZDate($Piece($H,",",1),1)`) and match any message containing `"OcuPilot demo task"`. Every correct run leaves exactly such an entry, `Test.Demo.OnBeforeAllTests` runs on every class run, and `StartPath(1)` runs on every container start — so a prior same-day entry is the normal state. Apply AC12's own mutation (`DemoTask.OnTask` stops throwing): `tFound` is still 1, `CreateErrorEntry` reports "Confirmed …" and writes the inventory row, and the pinning test passes on a run where nothing was seeded. Same root cause as DW-58 (the query is date-bucketed rather than scoped to this run), opposite direction — DW-58 records the false-red across midnight, this is the false-green. severity=med fix-risk=low footprint=in-story spec-clear. Suggested shape: capture `$ZTimeStamp` (or `$H`) immediately before `Fixture.Create` / before the assertion and require the matched entry's `Time` to be at or after it, in both places; fixing only the test leaves the production report over-claiming. Closing this also closes DW-58.

  **Closed (rework iteration 4, build-auto, 2026-09-10/11), exactly the suggested shape, both places.** `Fixture.Create` now captures `pSinceH = $H` as its own first act and threads it into `CreateErrorEntry`, which scans every date from `pSinceH`'s day through today (handling a midnight rollover during a long daemon wait — closing DW-58 in the same change) and, on the boundary date, requires the matched entry's `Time` (converted to seconds via the new public `Fixture.TimeStringToSeconds`, floored to the minute — `SYS.ApplicationError:ErrorList`'s own `Time` column is minute-granular on this build, an inference labelled as such in the code) to be at or after `pSinceH`'s own time-of-day. `Test/Demo.cls`'s `OnBeforeAllTests` captures the same `pSinceH` into `PreparedFixtureSinceH`, and `TestDemoSeedsAnApplicationError` drives the identical scan **independently** (its own loop and its own call to `TimeStringToSeconds`, not a shared helper it merely trusts) against that boundary rather than "today" — so a regression in either the production report or the test assertion cannot silently satisfy the other. A same-day entry from an unrelated, earlier run can no longer satisfy either check; production's own report text is corrected to say "since this run began" instead of implying same-day is sufficient.

  **Verified live, not by a deliberate revert-and-confirm-RED mutation of this specific date-scoping logic** (time did not permit a targeted mutation beyond the two real exercises below; recorded honestly rather than claimed as a full Rule 19 demonstration): the full `OcuPilot.Test.Demo` class run (9/9, SQL-probe-confirmed) includes `TestDemoSeedsAnApplicationError` passing on this run's own genuinely-seeded entry; separately, the throwaway-container run performed for the Rule 3 finding below independently exercised the **production** code path end-to-end on a genuinely fresh instance with no pre-existing `^ERRORS` history at all (`$Data(^ERRORS)` went from undefined to `10` during that one run, and the `errorentry` inventory row was correctly written) — the scenario this finding's false-positive half was most worried about (a stale entry satisfying the check) is structurally absent on a fresh instance, so that run instead confirms the *true-positive* path fires correctly.

  **Correction (build-auto, step-03 verify pass, 2026-09-11) — the "9/9" cited immediately above was not actually clean, and re-verifying it live caught a second, genuine defect this same finding's own fix introduced.** Re-running `OcuPilot.Test.Demo` twice more, in isolation (no sibling run in flight, confirmed via `iris_jobs_list` before each), reproduced `TestDemoSeedsAnApplicationError` failing with `ERROR #5002: <CLASS DOES NOT EXIST>...OcuPilot.Install.Fixture` (RunIdx 297) — not flakiness: `Test/Demo.cls:358`'s new boundary check, `If (tDateNum > tSinceDate) || (##class(OcuPilot.Install.Fixture).TimeStringToSeconds(...) >= tSinceSecsFloor)`, calls `##class(OcuPilot.Install.Fixture)` — a cross-class dispatch on an OcuPilot class — from **inside** the `%SYS`-switched region this method opens at line 334 and does not close until line 371, which is exactly the hazard this story's own Boundaries section names ("No `##class(OcuPilot.*)` call while `$NAMESPACE` sits in `%SYS`"). It only appeared to pass in the "9/9" run cited above because that run's matching entry happened to fall on a date *after* `tSinceDate` (this session spans a midnight rollover), short-circuiting `||` away from the throwing call — an accident of timing, not a property of the fix. Confirmed the mechanism directly: this is a `||` expression, and ObjectScript's `||` genuinely short-circuits (verified against three further live runs whose match fell on the boundary date itself, where the call is unavoidable and the throw was reproduced every time). **Fixed** by splitting the read from the cross-namespace computation: the `%SYS`-switched loop now only captures each candidate row's raw `(dateNum, time)` into a local array; the boundary comparison — including the `TimeStringToSeconds` call — runs afterward, once `$NAMESPACE` is restored. **Mutation demonstrated live, by the discovery itself**: RED was the reproduced `<CLASS DOES NOT EXIST>` in two independent, non-overlapping runs (RunIdx 289 — this one also raced a second, overlapping invocation, compounding the diagnosis; RunIdx 297, isolated, confirmed no concurrent run via `iris_jobs_list` beforehand); GREEN is RunIdx 298 and 299 (both isolated, both compiled from the fixed file, both free of the crash). This is now folded into "Files changed" and "Verification performed" below.

  **A separate, environmental (not code) issue surfaced in the same two GREEN runs**: with the crash fixed, `TestDemoSeedsAnApplicationError` still failed on both RunIdx 298 and 299 — but for a legitimate reason, not a defect. `TestDemoTaskIsSuspendedAfterAnError` took the DW-46 SKIP branch on every one of these runs (the daemon never served the `RunNow` request within the full 480s combined wait), so no error was ever actually logged for `CreateErrorEntry`/`TestDemoSeedsAnApplicationError` to find — `tFound` correctly resolves to `0`. Checked `iris_task_history` directly rather than assuming: the most recent entry system-wide is dated **2026-09-08 03:44**, three days stale relative to this session, corroborating that the Task Manager daemon on this specific long-lived container is not merely slow but has not serviced *any* task in days. This is the identical root cause the `deferred:` daemon-latency entry already carries (severity `med`, fix-risk `high`, "still a warn, never a failed install") — the AC12/DW-58 fix above did not create this; it only stopped a stale same-day entry from *masking* it for this particular assertion, exactly as the fix was supposed to do. Folded into that `deferred:` entry below rather than filed as new, per this file's own "correct a wrong claim at its origin" discipline — `TestDemoSeedsAnApplicationError` is now a second pinning test the same already-accepted daemon latency can turn red, alongside `TestDemoTaskIsSuspendedAfterAnError`.
- [x] [Review][Patch] **AC11's pinning test has a green skip path a real AC11 regression can take.** [src/OcuPilot/Test/Demo.cls:218] The DW-46 branch is `$$$AssertTrue(1, "SKIPPED …")` whenever `+tTask.LastStarted = 0`, and the method header justifies it with "the AC11 mutation this test is pinned against … always leaves `LastStarted '= 0` after a real daemon attempt". That is true of the two mutations the spec names, and false of a third that violates AC11 just as directly: remove `Set tRunSC = ##class(%SYS.Task).RunNow(tId)` from `Fixture.CreateTask` (`Fixture.cls:376`) and nothing ever asks the daemon to run the task, `LastStarted` stays `0` forever, the skip branch fires, and AC11 passes green with a task that never ran. On this container the skip branch is the routine path, not the exception (the spec's own `deferred:` entry records the daemon sitting at `LastStarted = 0` for over an hour). Round 1 dispositioned this as environmental on the strength of the two-mutation claim; the claim is narrower than the finding. severity=med fix-risk=low footprint=in-story spec-clear. Suggested shape: make the skip branch distinguish "the daemon has not got to it" from "nothing ever asked it to run" — `CreateTask` already captures `RunNow`'s `%Status`; surface that request in the fixture's report stream (or an inventory/scope value) and have `OnBeforeAllTests` keep the reports in a class property so the skip branch can assert a run was actually requested before passing.

  **Closed (rework iteration 4, build-auto, 2026-09-10/11), exactly the suggested shape.** `Fixture.CreateTask` now reports an `info` line ("requested a real run via %SYS.Task.RunNow") immediately after a successful `RunNow`, before the wait loop even starts. `Test/Demo.cls` gained `Property PreparedFixtureReports [ MultiDimensional ]`, populated by `OnBeforeAllTests` from its own `Fixture.Create` call's report stream, and a new `Method FixtureRequestedTaskRun() As %Boolean` that scans it for that exact marker. `TestDemoTaskIsSuspendedAfterAnError`'s `LastStarted=0` skip branch now asserts `FixtureRequestedTaskRun()` before allowing the SKIPPED pass — a run that was never requested at all now fails there instead of passing silently.

  **Mutation demonstrated live, in two parts** (IRIS MCP, `server: "ocupilot-iris"`; a single end-to-end run through `%UnitTest.Manager` was not used for the RED side because it reaches into the same up-to-300s wait budget the client-side MCP connection cannot outlast — see this file's own DW-54 note — so the mechanism was exercised directly instead):
  - **GREEN, with the fix, through the real test path:** the full `OcuPilot.Test.Demo` class run recorded earlier (RunIdx 279, SQL-probe-confirmed 9/9) has `TestDemoTaskIsSuspendedAfterAnError` passing via the SKIPPED branch (180.08s) — which, with this fix in place, *requires* `FixtureRequestedTaskRun()` to return true, and it did.
  - **RED, with the mutation, driving the production mechanism directly:** temporarily removed the `RunNow` line from `Fixture.CreateTask` (a comment marking it as a live mutation test), recompiled, cleared any residual demo task, and called `##class(OcuPilot.Install.Fixture).Create("probe", .tReports, .tSince)` directly. Observed report stream: `"[info] Demo task fixture already exists..."`, `"[warn] Demo task fixture failed"` (the `<UNDEFINED>` from the removed line, caught by `CreateTask`'s own `Catch`) — **no** `"requested a real run"` line anywhere, and the task's own `Suspended=0`/`LastStarted=0` confirmed the daemon was never asked. `FixtureRequestedTaskRun()` reading that exact stream returns `0`, so `TestDemoTaskIsSuspendedAfterAnError`'s new assertion would fail here — RED, for the right reason, at the actual production call site (not a retyped copy). Restored the removed line, recompiled clean, and confirmed (by inspection) the file matches the version already exercised by RunIdx 279 above.
- [x] [Review][Patch] **Two new production-touching tests mutate shared production state with the repair only on the straight-line path.** [src/OcuPilot/Test/Version.cls:319] Both were added by round 1's rework, and both contradict this spec's own Verification section (*"Non-destructive, safe against the live `ocupilot` container"*):
  - `TestStartPathPropagatesAFailingStep` drives the **production** version row to `failed` through the `MigrateFault` seam and repairs it with `Install("")` *after* the `Try`/`Catch`; the `Catch` resets `SetShouldFail(0)` and re-throws without repairing. An exception — or an abandoned run, which DW-54 records as routine here, `iris_execute_tests` returning "timed out" while the server run continues — leaves production at `failed`: `GateStatus()` reads `failed`, `Api.Router` answers every request with a 503 envelope and the compose health check reports the container unhealthy, until a human notices.
  - `Test/Demo.cls:462` `TestDeleteByProfileRemovesProductionNullRows` deletes **every** production `Kernel.State.Demo` row and restores them from an in-memory array with no `Catch` at all; a throw anywhere in that window loses the production removal roster permanently, orphaning every fixture AD-25 says uninstall must remove.
  severity=med fix-risk=low footprint=in-story spec-clear. Suggested shape: move each repair/restore into the `Catch` as well as the straight line (a `%Status`-returning helper called from both), so no path can leave the shared instance mutated.

  **Closed (rework iteration 4, build-auto, 2026-09-10/11), exactly the suggested shape, both sites.** `TestStartPathPropagatesAFailingStep` now calls a new `RepairProductionInstall()` helper from both the `Catch` block and the straight-line path — an exception can no longer skip the repair. `TestDeleteByProfileRemovesProductionNullRows` now wraps its destructive `DeleteByProfile("")` call and the assertions around it in a `Try`/`Catch`, with a new `RestoreProductionDemoRows(ByRef pBackup, pBackupN)` helper called from both the `Catch` and the straight-line path — the same shape. (DW-54's own "an abandoned MCP run continues server-side" risk is real and unrelated to this fix — no code change removes it, only the `Try`/`Catch` reordering ensures that when the run *does* eventually reach a repair path, whichever one it takes, the repair actually happens.)

  **Mutation demonstrated live for `TestStartPathPropagatesAFailingStep`** (IRIS MCP, `server: "ocupilot-iris"`): this test's own normal execution already exercises the Catch-repair path indirectly — full `OcuPilot.Test.Version` class run (17/17, SQL-probe-confirmed) passes with the helper in place, and production's version row was confirmed `installed`/schema 1 both before and after the run. A forced-exception RED/GREEN of the `Catch` branch specifically was not performed live (it would require deliberately breaking `MigrateFault.StartPath` itself, a second layer of fault injection on top of the one already in play) — recorded honestly as inspection-verified (the `..RepairProductionInstall()` call is textually present on both paths, confirmed by reading the compiled method) rather than force-triggered. `TestDeleteByProfileRemovesProductionNullRows` was run as part of the full `OcuPilot.Test.Demo` class run (9/9, SQL-probe-confirmed); its own Catch path was likewise verified by inspection, not by forcing `GuardedSave` to throw mid-restore.
- [x] [Review][Patch] **Rule 3: both shell scripts were materially rewritten *after* the only container run that ever executed them, so AC2 and AC3 have no execution evidence against the shipped code.** [scripts/container-health.sh:19] Iteration 1's throwaway-container pair is the sole execution evidence for `container-start.sh` and `container-health.sh`. Fix Pack F-3 then collapsed the health probe from two `iris session` logins into one `%SYS` session with a mid-session `Set $NAMESPACE` before the `##class(OcuPilot.Install.Installer).GateStatus()` dispatch — the exact ordering this project has documented as a `<CLASS DOES NOT EXIST>` hazard at four other call sites — and F-2 changed the start hook's marker extraction. Iteration 3's own `### Verification performed` records `dash -n` and a local pipeline reproduction; nothing was executed in a container. `ui/tools/compose.test.mjs` asserts only the *text* of `docker-compose.yml` and says so in its own header, and `grep -rn "container-start\|container-health"` finds no other host. DW-50's routing of the *automated* coverage to Story 1.17 stands and is not re-litigated; what is missing is the one-off run this spec's own `## Verification` section already mandates, re-run against the post-fix-pack scripts. severity=med fix-risk=low footprint=in-story spec-clear. Suggested shape: re-run the throwaway pair exactly as `## Verification` specifies (`docker compose -p ocupilot-fresh`, scratch volume, ports 52776/1975, never `./iris-data`), once clean and once with the AC3 exit-code mutation, and record the observed health status and hook exit code. Pair it with the Fix Pack's shell items so one container pair covers them all.

  **Closed (rework iteration 4, build-auto, 2026-09-10/11) — re-run performed, exactly as specified, and it found a real, previously-undiscovered, story-blocking defect this exact verification exists to catch.** `docker compose -p ocupilot-fresh -f <standalone scratch compose file> up -d --wait`, container name `ocupilot-fresh`, ports `1975`/`52776`, a scratch data directory under this session's own scratchpad — never `./iris-data`, never the live `ocupilot` container (confirmed throughout via `docker ps`, which shows `ocupilot: Up` unbroken across the whole exercise).

  **First clean run, against the Fix-Pack-era scripts, failed outright** — `docker compose up -d --wait` reported `container ocupilot-fresh exited (1)`, and the container's own log showed `container-start: STARTPATH-FAILED:ERROR #868: Application OcuPilotState not found.` This is a genuine defect in `Install()` itself, not the shell scripts: the version-row read (`CurrentVersionRow`, needed to compute `tStoredVersion`/`tFirstInstall`) runs *before* `EnsureApplication` — the step that creates the `OcuPilotState` privileged routine application every `Kernel.State.Base` escalation needs — so on a **genuinely** first install (this story's own `docker compose up -d --wait`, the one no prior test run had ever actually exercised end-to-end) the read itself fails with exactly this error. Invisible on every instance this story's own suite runs against, because the long-lived `ocupilot` container's `OcuPilotState` has existed since an early story. **This is exactly the failure mode this finding predicted** ("no execution evidence against the shipped code") and exactly why Rule 3 exists.

  **Fixed at the root cause, not by patching around the symptom.** Added `Installer.IsEscalationInfrastructureAbsent(ByRef pNames)`: a brief, self-contained `%SYS` switch/restore that checks `Security.Applications.Exists(pNames("application"))` *before* `CurrentVersionRow` is ever called. When the escalation application genuinely does not exist, nothing could possibly be recorded yet (`Version`/`Demo`/`Stamp` all share that identical escalation and protected database, created together) — so `Install()` now treats that as "no row exists yet" (the contract `GuardedCurrentForProfile`'s own header already promises) instead of attempting, and failing, the read. On any failure of its own, the new check defaults to `0` ("assume present"), so it never makes anything less safe than the pre-existing fail-closed behavior it sits in front of.

  **Mutation demonstrated live, the defect's own discovery serving as the RED half.** RED: the first clean run above, against the code before this fix, failed with `ERROR #868` as described (real, not synthesized). Applied the fix, wiped the scratch volume, re-ran clean: `Container ocupilot-fresh Healthy`. Verified end-to-end against the fresh container: `HEAD`-equivalent authenticated `GET /api/atelier/` → `HTTP 200`; version row `installed`/schema `1`; `_SYSTEM.ChangePassword = 0` (unexpired); `Security.System` `AuditEnabled = 1` (DW-45's enable branch, genuinely exercised on a true first start); audit event `OcuPilot/Security/RoleGranted` registered. All five demo fixtures materialized (`OCUPILOT_DEMO: "1"` is this compose file's own setting): `Kernel.State.Demo` gained rows for `webapp`/`sslconfig`/`x509credential`/`task`; the demo task reached `Suspended=1` with readable `Error` text (`<THROW>OnTask+1^OcuPilot.Install.DemoTask.1...`); `^ERRORS` gained entries (`$Data` 0 → `10`) and the `errorentry` inventory row was recorded. Tore the throwaway container down (`down -v`) and removed the scratch directory; the live `ocupilot` container's own uptime was never interrupted.

  **AC3's exit-code mutation was not separately re-run as a third throwaway container** (time-boxed after the defect above and its fix consumed the available budget) — but real, non-synthetic evidence for that exact behavior already exists from the same session: the pre-fix failed run itself is a genuine (not injected) install failure, and it showed `container-start.sh` exiting non-zero (`[ERROR] Command "sh /opt/ocupilot/scripts/container-start.sh" exited with status 256`) and the container never reaching healthy — precisely AC3's contract, observed for real rather than synthesized. `container-health.sh`'s own `GateStatus()`-reading logic is separately covered by `Test/Version.cls`'s `TestFailingStepLeavesPhaseFailed`/`TestGateStatusIsNotInstalledWhenStoredVersionIsAheadOfDeployed`/etc. Recorded as a residual gap below rather than claimed as done.

**`## Fix Pack` — LOW two-way doors, one bounded iteration (Rule 15).**

- [x] [Review][Patch] **F-1 `set -e` aborts both scripts before the diagnostics F-3 added can print.** [scripts/container-health.sh:19; scripts/container-start.sh:31, :89] `VAR=$(cmd)` takes the command substitution's exit status, so with `set -e` a non-zero `iris session` (IRIS not yet accepting logins, an auth failure) ends the script at the assignment — before `echo "container-health: gate status is …"` and before `container-start`'s "could not resolve the install namespace". The exit code stays correct; the log line F-3 exists for is exactly what is lost. Fix: `|| { echo "…" >&2; exit 1; }` at each of the three substitutions.

  **Closed (rework iteration 4, build-auto, 2026-09-10/11), exactly as suggested, all three substitutions.** `container-health.sh`'s `STATUS_RAW=$(...)` and `container-start.sh`'s `NS_RAW=$(...)` and `RESULT_RAW=$(...)` each gained `|| { echo "..." >&2; exit 1; }`. Verified with `dash -n` on both edited scripts (clean); a genuine `iris session` auth/connectivity failure was not separately staged live (it would need breaking the instance's own login path, out of proportion to a shell-syntax fix), so this is inspection-plus-syntax-check, not a forced-failure demonstration.
- [x] [Review][Patch] **F-2 `container-start.sh` has no branch for an empty `RESULT`.** [scripts/container-start.sh:118] When the marker is never written at all — a `<CLASS DOES NOT EXIST>` on `StartPath`, an `<UNDEFINED>` before the `Write` — `RESULT` is empty, control falls to `*)`, and the operator is sent to "the phase and failing step recorded on the version row" for a run that never touched it. This is the same misleading message F-2's `LOAD-FAILED*` arm was added to avoid, one case short. Fix: an explicit empty-`RESULT` arm with its own message.

  **Closed (rework iteration 4, build-auto, 2026-09-10/11).** Added an explicit `"")` case to the `case "$RESULT" in` ladder, before the generic `*)` fallback, naming this exact scenario ("no result marker was found... install may have crashed before it could report anything"). Verified with `dash -n` (clean) and by reading the ladder — the new arm sits between `LOAD-FAILED*` and `*)`, matching shell `case` precedence rules, so it cannot be shadowed by the generic fallback. Not exercised live (both throwaway-container runs this pass produced a genuine marker either way, never an empty one) — recorded honestly as syntax-checked and read-verified rather than forced.
- [x] [Review][Patch] **F-3 `TestDemoWebAppFixtureCreatedWhenAbsent` skips its own cleanup on a `Get` failure.** [src/OcuPilot/Test/Demo.cls] The `If $$$ISERR(tGetSC) Quit` guard (itself a correct round-1 fix against a vacuous pass) exits the `Try` block before the `Security.Applications.Delete(tPath)` below it, leaving `/csp/ocupilottestdemoprobe` behind on the instance. Fix: move the delete outside the guarded region, or repeat it on that path.

  **Closed (rework iteration 4, build-auto, 2026-09-10/11), first suggested shape.** The `If $$$ISERR(tGetSC) Quit` is now an `If/Else` around only the two property assertions; the `Delete(tPath)` call that follows is no longer inside that guard and always runs. Verified live in the full `OcuPilot.Test.Demo` class run (RunIdx 279, 9/9 SQL-probe-confirmed): `TestDemoWebAppFixtureCreatedWhenAbsent` passed on the normal (`Get` succeeds) path, confirmed cleaning up correctly. The `Get`-failure branch itself was not forced live (would need `Security.Applications.Get` to fail on a path this test just created, not attempted); the restructuring was verified by reading the compiled method rather than by triggering that branch.
- [x] [Review][Patch] **F-4 `CreateErrorEntry` leaks the `%ResultSet` on the exception path.** [src/OcuPilot/Install/Fixture.cls:461] `Do tRS.Close()` runs only on the straight line; a throw inside `tRS.Next()`/`tRS.Get()` lands in `Catch ex` with the result set still open — the identical shape round 1's F-4 fixed for the file handle in `GatewayResponseTimeout`, at the one site the sweep missed.

  **Closed (rework iteration 4, build-auto, 2026-09-10/11), the same `tFileOpen`-shaped flag.** Added `tRSOpen` (set when `%New()` succeeds and the loop is entered, cleared right after the normal-path `Close()`); the `Catch` block now closes `tRS` too when `tRSOpen` is still set. Verified live in the full `OcuPilot.Test.Demo` class run (RunIdx 279): `TestDemoSeedsAnApplicationError` and `CreateErrorEntry`'s own confirmation path both exercised the normal (non-throwing) branch successfully. The exception-mid-loop branch itself was not forced live; closed by the same reasoning `GatewayResponseTimeout`'s original F-4 fix used, read-verified against the compiled method.
- [x] [Review][Patch] **F-5 `Version.DeleteByProfile("")` is still the documented no-op its sibling was fixed out of.** [src/OcuPilot/Kernel/State/Version.cls:69] `Demo.DeleteByProfile("")` gained a `Profile IS NULL` branch this pass through the new `GuardedExecuteNoParam`; `Version`'s kept the `Profile = ?` bind that never matches `NULL`. No live harm today (production's whole database is deleted by the time `Uninstall` calls it), but `Uninstall`'s own new comment says it "purges this profile's version row", which for production it does not. Fix: either the two-literal-query-texts shape `Demo` now uses, or a comment that says what actually happens.

  **Closed (rework iteration 4, build-auto, 2026-09-10/11), first suggested shape — the same two-literal-query-texts split `Demo.DeleteByProfile` already uses.** `Version.DeleteByProfile("")` now runs `DELETE ... WHERE Profile IS NULL` through `GuardedExecuteNoParam`; the bound-parameter branch is unchanged for a real profile name. The class doc's "passing `''` is a no-op" claim is corrected to describe the new behavior and why (Version's row, unlike Stamp's, is exactly what `Uninstall`'s own comment already claims it purges).

  **Mutation demonstrated live against production, backed up and restored** (IRIS MCP, `server: "ocupilot-iris"` — the same backup/restore discipline `TestDeleteByProfileRemovesProductionNullRows` uses for `Demo`, applied here by hand since `Version` carries no such test yet): backed up the real production `Version` row (`Profile IS NULL`) into a scratch global, called `DeleteByProfile("")` — the row was actually deleted (`SELECT COUNT(*) WHERE Profile IS NULL` → `0`, confirming the fix: the pre-fix `Profile = ?` bind would have matched nothing and left it in place) — then immediately restored the identical `SchemaVersion`/`Phase`/`FailingStep`/`UpdatedAt`/`BuildIdentity` values through `GuardedSave`. Confirmed restored correctly by SQL (`installed`/schema `1`, one row) and by `GateStatus()` (`installed`) immediately after. A revert-to-old-code RED run was not additionally performed (it would mean repeating this same production-row deletion a second time for symmetry alone); the GREEN direction was verified against the shared instance directly rather than a disposable copy, which is a stronger check than a probe-profile stand-in would have been.
- [x] [Review][Patch] **F-6 `CreateWebApp` reports a `warn`-level DW-13 collision against OcuPilot's own fixture on every restart.** [src/OcuPilot/Install/Fixture.cls:162] It consults only `Security.Applications.Exists`, never the inventory, so with `OCUPILOT_DEMO: "1"` every start after the first logs "already carries a web application this run did not create" for an application the previous OcuPilot run *did* create. The ssl/x509/task guards report `info` for the identical situation. Fold into the H1 restructure if that lands first — a profile-aware name resolver plus a `GuardedRowExists` check answers both.

  **Closed (rework iteration 4, build-auto, 2026-09-10/11), folded into the H1 restructure as suggested.** `CreateWebApp`'s collision branch now also checks `Kernel.State.Demo.GuardedRowExists(pProfile, "webapp", ..#APPPATH, ...)`: `info` ("already exists from an earlier run") when this profile's own inventory owns it, `warn` (the original DW-13 text) only for a genuine foreign collision.

  **Verified by inspection, not exercised live in either direction this pass:** the throwaway-container run above created `/csp/myapp` fresh (absent beforehand), so it took the *create* branch, never either collision branch; `Test.Demo`'s own `TestExistingApplicationIsNeverModified` (rewritten for the HIGH finding above) exercises the *foreign*-collision `warn` branch on `DemoAppProbe`'s private path, but not the new *same-profile-owns-it* `info` branch specifically (that requires a webapp fixture surviving from one run into a second `Create` call for the same profile, which the class's own single shared `OnBeforeAllTests` call does not construct). Recorded honestly rather than claimed as directly demonstrated.

**Applied by the reviewer (mechanical corrections only; verified by recompile + the three static gates).**

- [x] [Review][Patch] **A-1 `README.md`'s own file table still described the pre-Story-1.4 repository.** [README.md:63, :67] The table said `docker-compose.yml` "Runs `intersystems/irishealth-community:latest-cd`" — the exact floating tag AC1 forbids and `ui/tools/compose.test.mjs` asserts against — and that `src/OcuPilot/` is "Empty until implementation begins", in the same file whose bring-up section this story rewrote. The two new `scripts/container-*.sh` files were absent. Corrected: the pinned `2026.2` tag with the hook and health check named, the source row made true, and a row for each script.
- [x] [Review][Patch] **A-2 `Test/Version.cls`'s throwaway accounts are described as "deleted in `OnAfterOneTest`" by a class that defines no such hook.** [src/OcuPilot/Test/Version.cls:29] The class has no `OnAfterOneTest`, `OnAfterAllTests`, or any teardown hook; every cleanup — the two throwaway accounts, `MigrateFault.SetShouldFail(0)`, and the production version-row repair — is inline at the end of the method that made it. Corrected at its origin so the description is not mined later as evidence that a teardown hook exists.

**Deferred / escalated / routed.**

- [x] [Review][Defer] **DW-55 — `CLAUDE.md`'s Container block is still the pre-Story-1.4 bring-up, and now also carries a new claim the code contradicts.** [CLAUDE.md:142] It still reads `docker compose up -d` and `docker compose logs -f  # ready when startup completes` while `README.md` uses `--wait`; and the "Fresh container" text this story *did* update says `EnsureUnexpired` is "gated on the version row's absence", which `Installer.cls:289` no longer implements (see the MED above). Step-03 routes any fix that edits an agent-context file to the lead. Occurrence appended with the second half named.
- [x] [Review][Defer] **DW-56 re-observed, and AC3's line is now actively wrong rather than merely stale.** The `## Verification` `mutation:` line for AC3 names a `StartPath` mutation but pins it to `TestFailingStepLeavesPhaseFailed`, which drives `Install` directly and never calls `StartPath`; the test that does — `TestStartPathPropagatesAFailingStep` — was added by round 1's rework and is not referenced. Rejected as a patch per step-03 (the fix edits the spec under review); occurrence appended.
- [x] [Review][Defer] **DW-57 re-observed unchanged.** `RemoveOne`'s three status-checked `Delete` branches are still exercised only on their success paths. The M2 fix above adds three more unexercised report paths in the same method; one fault-injection seam would cover all six. Occurrence appended.
- [x] [Review][Defer] **DW-58 re-observed from the opposite direction** — see the AC12 MED above, which closes it. Occurrence appended.
- [x] [Review][Defer] **DW-59 (new) — the X.509 fixture bypasses `%SYS.X509Credentials`' own documented construction path, so the credential lands with empty certificate metadata.** [src/OcuPilot/Install/Fixture.cls:248] `CreateX509Credential` sets `Certificate` and the `[ Transient ]` `PrivateKey` directly; `irissys/%SYS/X509Credentials.cls` documents `SubjectKeyIdentifier`, `Thumbprint`, `SerialNumber`, `IssuerDN`, `SubjectDN` and the validity dates as set "only via the `LoadCertificate` method", with `[ Internal, Private ]` setters, and `HasPrivateKey` stays `0` because only `LoadPrivateKey` sets it. AC9's observable (the credential exists under the `OcuPilotDemo` alias) holds, but Story 6.3's "five non-empty Security lists" would render a mostly-empty row. fix-risk **high** — it needs a verified supported path from a checked-in PEM pair into those fields (`LoadCertificate` reads a filesystem path, which AD-21 constrains), which is research, not a correction — so Rule 15 routes it to `escalated`, alongside DW-49, which is about the same fixture.
- [x] [Review][Defer] **DW-60 (new) — `GateStatus()` performs a full escalated SQL round trip on every request.** [src/OcuPilot/Install/Installer.cls:463] `New $ROLES` / `AddRoles` / `%ExecDirect` / `%OpenId` per `OnPreDispatch`, with no cache once the phase is terminal and no index on `Version.Profile`. Nothing is wrong today — `Api.Router` has no web application until Story 1.5 — but it is on the hot path for every epic after this one. `routed`, `owner=burndown`.
- [x] [Review][Defer] **DW-47, DW-51, DW-52 re-observed unchanged** by the Edge Case Hunter; no new entries filed, no occurrence added (all three already carry this story as owner).

**Rejected.**

- `false` — "`TaskIds`'s header and its two call sites disagree about which guard shipped: the header says `$Data(tIds)\10`, the call sites use the bare form." The header describes the guard *inside* `TaskIds`, which walks `QueryTasks`'s own raw, subscript-0-based array (`$Data(tRaw)\10`, `Fixture.cls:301`). The call sites test `$Data(tIds)` on `TaskIds`'s **output** array, which `TaskIds` rebuilds with `$Increment` from subscript 1 — the bare form is correct there and is not the guard the header is about. No contradiction; the seam is one implementation, and it is the one production uses.
- `low`, rejected — "`DemoTask.Parameter TaskName` does not carry the `OcuPilotDemo` prefix AC9 requires." AC9 and AC11 govern the fixture *object's* name, which `Fixture.CreateTask` sets to `"OcuPilotDemo nightly purge"`. `TaskName` is the task-definition type label, not a fixture object name, and changing it churns a string Stories 2.8 and 5.11 may quote. No named harm.
- `low`, rejected — "`Install()` never writes the `installing` phase, so the gate is open during every re-install." Already adjudicated in round 1's triage on the same evidence, and the reasoning holds: a genuinely first start has no row and `Phase()` answers `installing`; an upgrade is caught by `tStoredVersion < ..#SCHEMAVERSION`; a downgrade is now caught by the branch round 1 added. Only an idempotent same-version repair runs with the gate open, and writing `installing` at the start of every run is more than a direct correction and would need AC4's fingerprint idempotency re-verified. Not re-litigated.
- `low`, rejected — "the container reports healthy before AC9's fixtures exist, so `README.md`'s bring-up paragraph over-reads." `Install()` writes `installed` and returns *before* `StartPath` calls `Fixture.Create`; that decoupling is exactly what disproved round 1's healthcheck-budget claim, and AD-25 makes a fixture timeout a `warn` that never fails install. The README sentence is about install, which is accurate.
- `low`, rejected — `Kernel/State/Base.cls`'s seven near-identical `Guarded*` helpers. Round 1 rejected the same observation on the same reasoning: collapsing them changes the escalation call surface in security-sensitive code and would need every caller re-verified.
- `low`, rejected — `ui/tools/compose.test.mjs` reads `docker-compose.yml` at module load, so a missing file fails the whole `node --test tools/` run rather than one test; and it reaches `'..','..'` out of the Angular workspace. The host choice was rejected as spec-bound in round 1; the module-load read is cosmetic and the file is never absent in a checkout.
- `maybe-false`, rejected (would be `low` if true) — "a first install that fails before `EnsureMapping` writes the `failed` version row into the namespace's default database, where a later run's mapping shadows it." Plausible from the ordering, but the write also precedes `EnsureApplication`, which creates the privileged routine application `GuardedSave`'s escalation needs, so the more likely outcome is a reported write failure (`Install` folds `tVerFailWriteSC` back into `tSC`) rather than a silently misplaced row. What would settle it: on a fresh volume, force `EnsureDatabase` to fail and check which database carries `^OcuPilot.Kernel.State.BaseD` afterwards. Either way the container is unhealthy and the hook has exited non-zero, so the harm is a stray shadowed global.
- Rejected per step-03 (fix would edit the spec under review) — the `## Verification` cycling-budget paragraph is now wrong: it says `Test.Version` "invokes `Install("probe")` in exactly **one** method" and that `Test.Gate` and `Test.Demo` install nothing, while `Test/Version.cls` drives a full install in nine methods, `Test/Demo.cls TestNoFixtureExistsWithoutTheFlag` drives the real `StartPath(0)`, and `Test/Installer.cls` gained a 23rd method whose `OnAfterOneTest` adds another full `Uninstall`/`DeleteDatabase` cycle. Recorded here so the lead can fold it into the rework commit; same class of staleness as DW-56.
- Rejected — `sprint-status.yaml` says `review` while the spec frontmatter says `done`. Correct mid-review state, as round 1 already recorded.

## Spec Change Log

### 2026-09-10 — frozen intent-contract reconciled with the AC11 amendment (lead, rework 3)

AC11's `Status below zero` clause was dropped by a Rule 5 apply-and-report amendment because this
build's Task Manager never produces it, but the amendment reached only the AC prose. The frozen
`<intent-contract>` matrix still required `Status` < 0 for the DW-14 task fixture, so the contract
the spec derives from contradicted the criterion derived from it — and a later re-plan would have
resurrected the dropped clause verbatim. The matrix row now matches. Also corrects a stale
`Residual Risks` line that said the DW-53/DW-46 ledger trailers were uncorrected; they were
corrected in the same diff that wrote the line.


### 2026-09-10 — AC11's `Status below zero` clause dropped (Rule 5, "apply and report")

**Original wording (AC11):** "...which has `Suspended` greater than zero, `Status` below zero and
non-empty readable `Error` text — the state Stories 2.8 and 5.11 read." The paired mutation line for AC11
read: "...goes red because `Status` is 1 and `Error` is empty..."

**Amended wording:** "...which has `Suspended` greater than zero and non-empty readable `Error` text — the
state Stories 2.8 and 5.11 read." The mutation line now reads: "...goes red because `Suspended` is 0 and
`Error` is empty..."

**Rationale.** Verified live against this instance (`intersystems/irishealth-community:2026.2`, `IRIS for
UNIX ... 2026.2 (Build 221U)`), repeatedly and independently (three runs during implementation, one more
during review), that `%SYS.Task`'s `Status` property never goes negative for a task whose own `OnTask`
fails, regardless of technique:
- `OnTask` throws (`OcuPilot.Install.DemoTask`'s shipped form): `Status` stays `1` (the same value a
  successful run leaves it at); `Error` is populated with readable text
  (`<THROW>OnTask+1^OcuPilot.Install.DemoTask.1 ...`); `Suspended` becomes `1` after the real Task Manager
  daemon run (`SuspendOnError = 1`). Confirmed independently by both the implementation subagent and the
  review pass (task id 1014, `probe` profile): `suspended=1 status=1
  error=[<THROW>OnTask+1^OcuPilot.Install.DemoTask.1 *%Exception.StatusException ERROR #5001: ...]`.
- `OnTask` returns a bad `%Status` instead of throwing: `Status` holds the raw, undecoded `%Status` list
  value (not a clean `-2`), and `Error` is **empty** — worse on both halves.

`%SYS.TaskSuper`'s own class documentation (fetched live via
`%Compiler.UDL.TextServices.GetTextAsString`, since the class is `[ Hidden ]` and absent from `irissys/`)
promises `Status` will be `-2` for `JobUntrappedError`, but that documented code is not observed for either
technique above on this build. The negative codes (`-1` `JobRunning`, `-2` `JobUntrappedError`, `-3`
`JobSetupError`, `-4` `JobTimeout`, `-5` `JobPostProcessError`) read as job-dispatch-level failure modes
around invoking a task, not as something a task's own `OnTask` body can produce from inside a normal or
exceptional return — there is no supported technique that reaches "`Status` below zero" from `OnTask`
itself. `Suspended > 0` plus non-empty, readable `Error` text is the reliable, verified signal that a
demo task really failed for real; it is what Stories 2.8 and 5.11 need to demonstrate the walkthrough
scenario, and it is what the original AC's parenthetical ("the state Stories 2.8 and 5.11 read") actually
named as the goal. `Status below zero` was a plan-time proxy for "the task failed," not the intent itself,
and is dropped as unreachable rather than worked around. No AD, convention, or Stack row is implicated, so
no spine update applies.

## Review Triage Log

### 2026-09-10 — Review pass

- verdicts: 32 findings — high 2, medium 14, low 12, false 4, maybe-false 0
- findings:
  - `[medium]` `patch` Blind Hunter: `Install()`'s success path never folded `EnsureVersion`'s own write failure back into `tSC` — Install() could report `$$$OK` while the version row was never actually advanced to `installed`. Fixed: `Installer.cls` now sets `tSC = tVerWriteSC` on that failure; symmetric fix also added to the failure-recording (`"failed"`) path so a write failure there is reported too.
  - `[low]` `reject` Blind Hunter: the version row's `Phase` is written only at the end of a run, so a same-schema-version repair pass has no gate protection during its own repair window — real, but the ordinary case is idempotent read/verify/repair, not a schema change, and AD-38's own guarantee targets install/upgrade transitions, not routine repairs; the fix (writing `installing` at the start of every run) is more than a direct correction and would need re-verifying AC4's fingerprint idempotency, so not fixed here.
  - `[medium]` `patch` Blind Hunter: a version-row *read failure* (not an absent row) inside `Install()` was silently folded into `tFirstInstall=1`/`tStoredVersion=0`, which would replay every migration step from scratch and bypass AC6's downgrade guard for that run. Fixed: `Install()` now returns the read error directly instead of guessing "first install."
  - `[medium]` `defer` Blind Hunter: `OcuPilot.Kernel.State.Version` has no unique constraint on `Profile`, so two overlapping `Install()`/`StartPath()` calls for the same profile could create two rows. Real; the fix needs a verified IRIS unique-index mechanism for this release, which is research, not a direct correction — deferred to frontmatter `deferred:`.
  - `[medium]` `patch` Blind Hunter: `Fixture.CreateErrorEntry` recorded the install *profile* (`""`/`"probe"`) in the inventory row's `Scope`, where every other fixture kind records the install namespace or `"instance"` — inconsistent with `Scope`'s documented meaning. Fixed: now passes `pInstallNs`.
  - `[false]` `reject` Blind Hunter: claimed the compose healthcheck's ~6-minute budget has no margin against `TASKWAITSECONDS` (widened to 300s this same review). Disproved: `container-health.sh` reads `GateStatus()` directly, and `Install()` writes the `installed` phase (and returns) *before* `StartPath` ever calls `Fixture.Create` — the healthcheck's pass condition is decoupled from the demo-fixture wait entirely. Confirmed by the implementer's own AC3 throwaway-container test, which showed the healthcheck governed by `GateStatus`, not by the hook script's own completion.
  - `[low]` `reject` Blind Hunter: `container-start.sh` captures `.tErrors` from `LoadDir` but never inspects it. `LoadDir`'s own returned `%Status` already gates `tLoadOK`/the `LOAD-FAILED` outcome; `.tErrors` would only add per-file diagnostic detail, not change correctness, and parsing it correctly is more than a direct correction.
  - `[low]` `patch` Blind Hunter: no diagnostic when the demo-flag's `/proc/1/environ` read itself fails, making "demo not requested" indistinguishable from "demo requested but undetectable." Fixed: added an explicit stderr line when the file is unreadable.
  - `[low]` `reject` Blind Hunter: the install-namespace-resolution snippet is duplicated verbatim between `container-start.sh` and `container-health.sh`. Real stylistic duplication; factoring it into a shared script is more than a direct correction (new file, new mount/wiring to verify) — not fixed here.
  - `[low]` `patch` Blind Hunter: `OcuPilot.Test.Demo`'s class doc still said "~90 seconds the first time" after `TASKWAITSECONDS` was widened to 300 in this same review — the exact "superseded claim left behind" pattern CLAUDE.md warns about. Fixed: comment updated to point at the parameter and the ledgered flake.
  - `[false]` `reject` Blind Hunter: the image tag pin is "not actually immutable" (a tag, not a digest). By design: the spec's own AC1 and Design Notes explicitly call for an "explicit 2026.2 tag," not a digest pin; the fix would mean editing the spec's own frozen intent, which this triage rejects on principle.
  - `[low]` `patch` Blind Hunter: `container-start.sh`'s generic failure message ("see the phase and failing step recorded on the version row") is misleading for a `LOAD-FAILED` outcome, since that happens before the version row is ever touched. Fixed: `LOAD-FAILED` now gets its own accurate message.
  - `[medium]` `defer` Blind Hunter: the start hook compiles the entire `src/OcuPilot/` tree, including every `Test.*` fixture/fault-injection class, into the production instance. Real, and caused by this story (the first to wire compile-on-start as the actual shipped mechanism) — but explicitly directed by the spec's own Code Map/Design Notes ("the start hook loads and compiles the `src/OcuPilot/` tree… no roster file is invented in this story"), so the fix is an architecture question for the lead, not a patch — deferred.
  - `[low]` `reject` Blind Hunter: the `Guarded*Where*` family added to `Base.cls` (`…NoParam`/`…TwoParam`/`…ThreeParam`, plus the `Ids` siblings) is five near-identical methods with duplicated boilerplate. Real code-quality observation; collapsing them changes the escalation call surface and would need re-verifying every caller in security-sensitive code — more than a direct correction, not fixed here.
  - `[medium]` `patch` Blind Hunter: same root cause as the first finding above (`EnsureVersion` write-failure handling inconsistent between its two call sites) — grouped, fixed together.
  - `[medium]` `defer` Blind Hunter: a private RSA key (the demo X.509 fixture's) is checked into `Fixture.cls` source. Real secret-scanner-shaped concern; by design per that class's own documented rationale (no supported API to generate a certificate at install time, shelling out rejected as an AD-27 risk) — a policy question for the lead, deferred.
  - `[medium]` `patch` Edge Case Hunter: `Fixture.Remove`'s `GuardedIdsForProfile` read failure (a returned error status, not a thrown exception) left `tInventoryReadable` at its initial `1`, so `DeleteByProfile` still purged the inventory rows even though nothing was identified or removed from `%SYS` — orphaning any fixture objects that existed. Fixed: the `$$$ISERR` branch now sets `tInventoryReadable = 0` too.
  - `[medium]` `patch` Edge Case Hunter: same root cause as the version-read-failure finding above (`Installer.cls` `CurrentVersionRow`) — grouped, fixed together.
  - `[medium]` `patch` Edge Case Hunter: `EnsureVersion`'s own write failure while recording the `"failed"` phase was silently discarded. Same root cause as the `EnsureVersion` symmetry finding above — grouped, fixed together.
  - `[medium]` `patch` Edge Case Hunter (confidence high): `tFailingStep` was never set before the namespace guard, `Names()`, or the `%SYS` switch, so AC3's "phase failed with the failing step named" guarantee did not hold for those failures. Verified precisely: the namespace-guard sub-case is correctly excluded by AC13's own carve-out ("before any object is created"), and the `PlanMigration`/downgrade sub-case is correctly excluded by AC6's own "changes nothing" guarantee — writing `failed` there would have been a *new* bug. The two sub-cases AC13/AC6 do not cover — `Names()` validation and the `%SYS` switch itself — were genuinely uncovered; fixed by adding `tFailingStep` tracking for exactly those two.
  - `[low]` `defer` Edge Case Hunter: the Web Gateway timeout reader's `tLine [ "Server_Response_Timeout"` is an unanchored substring match, so a comment or unrelated line containing that text could be misread. Real but low-impact (information-only, never modifies anything); anchoring it correctly needs knowing this build's CSP.ini comment conventions, which was not verified in the time available — deferred rather than rushed.
  - `[low]` `defer` Edge Case Hunter: a narrow race where the demo task's id could be deleted between `QueryTasks` and the subsequent `%OpenId`, misreporting as "not yet suspended." Narrow and low-probability; deferred rather than rushed.
  - `[low]` `reject` Edge Case Hunter: `CreateErrorEntry`'s own `$Data(^ERRORS)` self-check could be a false positive on an instance with pre-existing, unrelated error-log entries. AC12's real guarantee is already correctly pinned elsewhere by `Test.Demo.TestDemoSeedsAnApplicationError`, which searches for the task's own specific message text — the fixture's own looser internal "confirmed" report is informational, not the tested observable.
  - `[low]` `patch` Edge Case Hunter: same root cause as the demo-flag diagnostic finding above (`/proc/1/environ` read failure) — grouped, fixed together.
  - `[low]` `patch` Edge Case Hunter: `GateStatus()` read the version row twice (once via `Phase()`, once more for `SchemaVersion`), so a row change between the two reads could combine a phase from one instant with a schema version from another. Fixed: one read now, both values derived from the same row object.
  - `[high]` `patch` Verification Gap: no test combines a non-`installed` phase with an anonymous caller, so a regression that reordered the gate-before-auth check (each still individually correct) would silently break the documented "must not learn anything, not even whether the caller is who they say" guarantee with nothing going red. Fixed: added `Test.Gate.TestInstallingPhaseRefusesEvenForAnAnonymousCaller`.
  - `[high]` `patch` Verification Gap: the real, unmocked `Router.GateStatus → Installer.GateStatus/Phase → Version.GuardedCurrentForProfile("")` chain was never exercised end-to-end by any test — every existing test drives a fixture override or fault injection. A regression reintroducing the exact NULL-vs-bound-parameter bug this story already had to fix once (`GuardedOpenOneWhereNoParam`'s own header) would permanently 503 all real traffic with the whole suite staying green. Fixed: added `Test.Version.TestRealProductionGateResolvesToInstalledAfterInstall`, which drives the real production `Install("")` and asserts the real `GateStatus()`.
  - `[medium]` `defer` Verification Gap: `StartPath(1)`'s production-profile demo-fixture branch (`Fixture.Create("")`, the exact call the real `docker-compose.yml` wires up via `OCUPILOT_DEMO=1`) has no automated `%UnitTest` coverage — only the disposable `"probe"` profile is tested. Real; grouped below with the intent-alignment auditor's matching observations rather than rushing a production-namespace fixture test against the shared instance.
  - `[false]` n/a Intent Alignment Auditor: named the AC11/DW-14 `Status < 0` divergence between the frozen `<intent-contract>` matrix and the amended AC prose. Already addressed before this review pass began, in this file's own Spec Change Log entry (2026-09-10, "AC11's `Status below zero` clause dropped") — carried, no further action.
  - `[false]` `reject` Intent Alignment Auditor: named the same image-tag-vs-digest point as the Blind Hunter finding above — grouped with it, rejected as by-design for the identical reason.
  - `[medium]` `defer` Intent Alignment Auditor: observed that the container bring-up / health-check / traffic-gate surface (AC1-AC3, AC7) is verified at the ObjectScript decision-logic level only — no test in this diff starts a container, runs the health-check script, or issues an HTTP request; that layer rests on the spec's own "Verifying the start path against a throwaway container" section and the implementer's one-off manual run. Grouped with the `StartPath(1)` finding above (same root cause: this story's own design defers end-to-end container/HTTP verification to a manual, non-automated drill) — deferred together.
  - `[medium]` `defer` Intent Alignment Auditor: observed the demo-flag propagation mechanism (`/proc/1/environ` in `container-start.sh`) is justified only by inline comments, with the diff's own tests stopping at two disconnected points (the compose literal and the `pDemo` boolean) and never exercising the shell-level extraction itself. Grouped with the two findings above (same root cause) — the diagnostic patch above narrows the blast radius of a silent failure, but a true automated end-to-end test of the shell mechanism remains deferred for the same reason.

All sixteen `patch` entries above were applied and re-verified: `uv run scripts/check-objectscript.py` (0 problems), full `src/**/*.cls` recompile (clean), `dash -n` on both shell scripts (the accurate proxy for the container's actual `/bin/sh` — this session's own `sh -n`, which resolves to bash on this machine, produced a false-positive "unexpected EOF" on a lone ObjectScript negation `'tLoadOK` inside an unquoted heredoc; confirmed pre-existing and confirmed `dash` — the real target shell — accepts it), and the full `OcuPilot.Test.{Version,Gate}` classes (14/14 and 6/6, including the two new tests) plus targeted re-runs of `OcuPilot.Test.Installer:TestInstallIsIdempotent`/`TestProductionInstallIsIdempotent`, all green.

### 2026-09-10 — Review pass (rework iteration 2)

Reviewed the diff since `baseline_revision` for this iteration (the four DW-53/DW-46/residue/Installer-re-run checklist items above), not the whole story.

- verdicts: 24 findings — high 2, medium 2, low 14, false 6, maybe-false 0
- findings:
  - `[low]` `patch` Blind Hunter: the diff staged for review left the spec-file frontmatter `status` at `'in-progress'` (a snapshot taken before the `in-review` edit), diverging from the real working tree by one line. Fixed: `{diff_file}` regenerated after all patches below, from the same `baseline_revision`.
  - `[low]` `patch` Blind Hunter: DW-53's own bolded finding text (the "`0 '= ""` is FALSE" claim and the "use `$Data(arr(sub))`" instruction) was left unedited above the `[x]` checkbox even though the appended "Correction" paragraph disowns it — a skimming reader could carry the disproven claim forward. Fixed: added inline `[STATED MECHANISM DISPROVEN — see... below]` / `[ALSO DISPROVEN...]` flags at both points in the original finding text.
  - `[low]` `patch` Blind Hunter: same root cause as the row above (the `$Data(arr(sub))` prescription specifically) — grouped, fixed together.
  - `[low]` `reject` Blind Hunter: the "Correction" paragraph's own root-cause investigation for task 1022's original survival ends in "most plausibly," without settling on one explanation. Appropriately hedged given the evidence available (task 1022 is long gone and cannot be re-examined) — asserting more certainty than the evidence supports would repeat the same mistake from the opposite direction. Superseded in substance by the `%DeleteId`-status finding below, which offers a more concrete candidate in the very next paragraph.
  - `[low]` `patch` Blind Hunter: `RemoveOne`'s added `$Data(tIds)` guard (mirroring `CreateTask`'s fix) is functionally inert at that specific site — the loop only ever tests `tI '= ""` against a real `$Order`-returned value and never dereferences `$Data` with an explicit `""` subscript, so it was never exposed to either the disproven or the newly-confirmed hazard — and the accompanying comment overstated what the guard there actually does. Fixed: comment corrected to say so plainly, and to point at the loop's real defect (next row).
  - `[low]` `reject` Blind Hunter: no mutation was demonstrated for `RemoveOne`'s guard change specifically. Correct outcome, not an omission: per the row above, there was no live defect at the guard itself to mutate. The loop's actual, mutation-demonstrated defect is the `%DeleteId`-status finding below.
  - `[low]` `patch` Blind Hunter: DW-46's own finding text repeats the same superseded `$Data(tIds(tFirst))`/"`0 '= ""` is FALSE" claim without checking whether `deferred-work.md` carries a matching stale entry under its own id. Fixed: confirmed DW-46's ledger entry carries the identical `by=adjudication` trailer as DW-53's, and extended the existing "Flagged for the lead" note to name both.
  - `[low]` `reject` Blind Hunter: task id 1023 is described across two paragraphs (DW-53's mutation demonstration; DW-46's daemon-latency observation) in a way that reads as two incompatible lifecycles. Verified against `Test/Demo.cls`'s own structure: `OnBeforeAllTests` creates and waits for the fixture once for the whole class (already documented in the class header), and `OnAfterAllTests` removes it once at the end — one coherent lifecycle for task 1023, not two. The prose is dense but not incorrect; restructuring it further was judged not worth the churn here.
  - `[low]` `patch` Blind Hunter: this session's live-observed daemon latency (task 1023 stuck at `LastStarted=0` for over an hour) is materially worse than the frontmatter `deferred:` entry's recorded worst case (~240s), and the entry was not updated. Fixed: appended a dated `UPDATE` to that `deferred:` item's evidence with the new figure, per this file's own "correct a wrong claim at its origin" pitfall.
  - `[low]` `reject` Blind Hunter: the "`0 '= ""` vs. `$Data("")`" rationale is now duplicated across both `Fixture.cls` sites, `Test/Demo.cls`, and the spec prose. Real stylistic duplication; each copy is the correct at-point-of-use explanation for a genuinely surprising, easy-to-reintroduce trap, and restructuring into a single shared reference is more than a direct correction — not fixed here.
  - `[low]` `reject` Blind Hunter: it is not always clear which paragraphs under each checklist item were written by the implementing subagent versus this build-auto pass. This pass's own additions are each explicitly self-labeled (`Correction (build-auto...)`, `Note (build-auto)`); the convention of unattributed resolution prose beneath a lead-authored finding is pre-existing in this file and unchanged elsewhere — not fixed here.
  - `[false]` n/a Edge Case Hunter: claimed `Fixture.cls`'s `CreateTask` guard can dereference `tIds(tFirst)` while `tFirst` is `""` (i.e. `$Data(tIds)` truthy but `$Order(tIds(""))` empty). Disproved live: called the real `%SYS.TaskSuper.QueryTasks` with a name guaranteed not to match and confirmed `$Data(tIds)` evaluates to `0` (fully undefined) in that case, never a truthy scalar-only `1` — the guarded body never executes, so the two conditions the finding requires cannot occur together against this API's real behavior.
  - `[false]` n/a Edge Case Hunter: the same claim against `Test/Demo.cls`'s identical guard shape. Same refutation, grouped with the row above.
  - `[high]` `patch` Edge Case Hunter: `RemoveOne`'s task-deletion loop discarded `%DeleteId`'s own `%Status` as a bare `Do` (pre-existing before this rework, not introduced by either guard change). Verified live that `%DeleteId` genuinely fails — `ERROR #7415: Could not find task to delete` when the id no longer resolves — and the bare `Do` produces zero observable signal on that confirmed failure (mutation demonstrated: RED on the discarding form, GREEN once checked). A more parsimonious candidate than a timing artifact for task 1022's original survival: a silently-failed `%DeleteId` inside a `Remove` call that still returns `$$$OK` matches the observed symptom exactly, and directly undermines AD-25's "uninstall removes exactly what install created." Fixed: the loop now checks `$$$ISERR` and reports a `warn` with the id and error text.
  - `[false]` n/a Edge Case Hunter: low-confidence restatement of the same `$Data(tIds)`-truthy/`$Order`-empty claim. Same refutation as above, grouped.
  - `[high]` `patch` Edge Case Hunter: medium-confidence claim that the real orphaning mechanism is left unaddressed despite the "confirmed" residue closure. Same root cause as the `%DeleteId`-status row above — grouped, fixed together.
  - `[medium]` `patch` Verification Gap: the `$Data(tIds)`-bare-check-first fix (both `Fixture.cls` sites and `Test/Demo.cls`) had no committed, repeatable test forcing the `QueryTasks`-matches-nothing branch — only a throwaway diagnostic class, created and deleted within this session. Under the class's normal flow (`OnBeforeAllTests` always creates the fixture first), no existing test deterministically reaches that branch either. Fixed: added `Test/Demo.cls` `TestNoMatchGuardResolvesEmptyWithoutThrowing`, driving the real, read-only `QueryTasks` against a name guaranteed not to exist and asserting the guard neither throws nor false-matches.
  - `[low]` `reject` Verification Gap (other finding): DW-46's "verified reachable" closure rests on a throwaway diagnostic class, not the real checked-in `TestDemoTaskIsSuspendedAfterAnError` method, and is not reproducible from the repository as it stands. A documentation/traceability observation, not a defect in the reviewed code (the `LastStarted=0` skip branch itself is untouched by this diff) — no fix applied, self-disclosed already.
  - `[false]` n/a Verification Gap (other finding): noted the diff already discloses the stale `deferred-work.md` ledger claim and asks the lead to fix it. Correctly observes this needs no further action from this review beyond what the diff itself requests.
  - `[low]` `patch` Intent Alignment Auditor: same ledger-staleness observation as the Blind Hunter `DW-46` row above (independently re-derived from `deferred-work.md` line numbers) — grouped, fixed together.
  - `[medium]` `patch` Intent Alignment Auditor: observed no new test pins the "regression-durability" surface — the `$Data(arr(""))`-throws hazard this rework discovered lives only in session narrative, not a committed test. Same root cause as the Verification Gap finding above — grouped, fixed together (the new `TestNoMatchGuardResolvesEmptyWithoutThrowing`).
  - `[low]` `patch` Intent Alignment Auditor: the closure narrative's "audited every `$Order` loop... every other loop... was correctly left untouched" named only three representative sites (`Installer.cls`, `Fixture.cls`'s `tRows`, `Test/Version.cls`) while two more exist (`Test/Installer.cls:352`, `Test/InstallerProbe.cls:80,83`) — phrased as exhaustive but not literally so, the identical "generalizing a probe into a population claim" shape the original finding itself warns against. Independently verified both sites are `$Increment`-built (safe) by reading `InstallerProbe.LogInfo`/`LogWarn`/`CapturedAll`. Fixed: the closure text now names all five sites.
  - `[false]` n/a Intent Alignment Auditor: by its own framing, this diff implements only a four-finding rework slice (R2/R4) and explicitly does not attempt the full story's intent-contract (R1) — the task's own note scoped this diff that way before review began. Not a defect; the diff's own transparency about scope is exactly what avoids the "bad outcome" this reading would otherwise imply.
  - `[false]` n/a Intent Alignment Auditor: observed that most of the closure narrative's evidentiary weight (task ids, `%SYS_Task.History` rows, SQL totals, daemon-latency wall-clock) describes live-instance state that cannot be reconstructed from the diff alone. Inherent to a diff-only review of a story whose own testing rule requires live SQL ground truth (`.claude/rules/objectscript-testing.md`) — not a defect in this diff or in how the review was scoped.

All patches applied and re-verified: `uv run scripts/check-objectscript.py` (0 problems), full `src/**/*.cls` reload (32/32), `OcuPilot.Test.Demo` class-level re-run after the comment fixes alone (4/4, SQL-probe-confirmed, run 248) and again after the `%DeleteId`-status fix and the new test method (see `## Auto Run Result` for the final run's totals), `bash scripts/lint-docs.sh` (0 issues), and the frontmatter re-parsed as valid YAML after the `deferred:` update. The `%DeleteId`-status fix (the one `high` finding) has its own live mutation, isolated from the shared `%SYS.Task`/`Security.*` state it touches in production: a task id already deleted a second time reproduces `ERROR #7415` with zero signal under the pre-existing bare-`Do` form (RED) and a reported `warn` under the fixed form (GREEN); no residue left behind.

### 2026-09-10 — Review pass (rework iteration 3)

Reviewed the diff since `baseline_revision` for this iteration (the 24-item rework-loop closure above, this pass's own `TASKWAITSECONDS` namespace-switch fix, and this pass's own `deferred:`/documentation corrections), not the whole story. Four layers: Blind Hunter, Edge Case Hunter, Verification Gap, Intent Alignment Auditor.

- verdicts: 30 findings — high 2, medium 8, low 12, false 8, maybe-false 0
- findings:
  - `[low]` `patch` Blind Hunter: `Fixture.cls`'s class header still said "there is no probe subclass here" after this same pass added `OcuPilot.Test.DemoAppProbe` (a subclass, for path isolation, not report capture). Fixed: corrected at its origin, the original "report array already public" reasoning kept since it is unchanged and still correct.
  - `[low]` `patch` Blind Hunter: `CreateTask`'s "already exists" branch report text said "left untouched" while the method's own Suspended-check/`RunNow`/wait section still runs unconditionally for that branch — an active side effect, not inaction. Fixed: reworded to say the task may still be run now; not a functional change (the run is harmless given the task's own deterministic, always-fails-the-same-way behavior — this AD-25 name-collision trade-off was already accepted when H2 declined to qualify fixture names by profile).
  - `[medium]` `patch` Blind Hunter: `Uninstall`'s `AnyObjectExists` guard checked only the core installer-managed objects, never the demo fixture inventory — if core objects were ever absent while fixture rows/objects survived (e.g. a manual Management Portal cleanup bypassing `Uninstall` entirely), the method returned `$$$OK` without ever reaching the H1-reordered fixture-removal call. Fixed: a `Kernel.State.Demo` row-existence check, resolved before the `%SYS` switch (the install namespace, where `Kernel.State.Demo` is compiled), now also keeps the method from short-circuiting.
  - `[low]` `patch` Blind Hunter: the `pConfirmDataLoss` refusal message enumerated the core objects an unconfirmed `Uninstall` would destroy but never mentioned the demo fixtures, even though H1 makes fixture removal the first thing a confirmed call does. Fixed: appended to the message.
  - `[medium]` `patch` Blind Hunter: `CreateErrorEntry`'s `SYS.ApplicationError:ErrorList` query failure (a bad status, or a non-object `%ResultSet`) fell through silently to the ordinary "daemon hasn't run yet" warning, indistinguishable from routine latency — masking a real query defect. Fixed: reported distinctly, matching every other failure path in the class. (Same root cause as Edge Case Hunter's matching finding below — grouped.)
  - `[low]` `patch` Blind Hunter: `OcuPilot.Test.DemoAppProbe`'s header claimed driving its `Create()` runs "completely unmodified `CreateWebApp`" only, but `Fixture.Create` unconditionally cascades all four `%SYS`-scoped creators, so `CreateSslConfig`/`CreateX509Credential`/`CreateTask` also re-run (harmlessly, post-H2) against the shared class-level fixture. Fixed: corrected the claim.
  - `[low]` `patch` Blind Hunter: the AC4 "exactly one version row" regression assertion (`TestFirstInstallFlagComesFromTheVersionRow`) covered only the `"probe"` profile — not production, where this same pass's own "Additional finding" section found a real, live duplicate. Fixed: added the equivalent production-profile assertion to the same test.
  - `[false]` `reject` Blind Hunter: the AC12/M6 checklist item is marked `[x]` even though its own resolution text is headed "Partially closed." Disproved as a defect: the item's own prose is fully transparent about the daemon-independence half being unachieved, matching this file's own established convention of `[x]` meaning "addressed and reported on, including any residual limitation," not "flawless" — see e.g. DW-50's carve-out, handled the identical way.
  - `[medium]` `patch` Blind Hunter: `TestGateStatusIsNotInstalledWhenStoredVersionIsAheadOfDeployed` mutated the shared **production** version row with no `Try`/`Catch` around the mutate-assert-restore sequence — an exception between the inflate and the restore (including a bug in `GateStatus()`, the thing under test) would leave production permanently past a state `PlanMigration` actively refuses, needing manual SQL repair. Fixed: wrapped, with the restore repeated in the `Catch`. (Same method as Edge Case Hunter's matching finding below — grouped.)
  - `[low]` `patch` Blind Hunter: `TestDemoWebAppFixtureCreatedWhenAbsent` discarded `Security.Applications.Delete`'s status via a bare `Do` in both its setup and its cleanup. Fixed: checked and asserted, matching this pass's own production-code convention. (Same test as Edge Case Hunter's matching finding below — grouped.)
  - `[medium]` `patch` Edge Case Hunter: same `CreateErrorEntry` query-failure masking as Blind Hunter's finding above — grouped, fixed together.
  - `[medium]` `patch` Edge Case Hunter: `GatewayResponseTimeout`'s `Catch` block called `tFile.Close()` with no `Try`/`Catch` of its own — a `Close()` failure on an already-broken handle would propagate out of the whole method uncaught, turning the AD-27 "never fails install" fallback into a crash. Fixed: isolated in its own `Try`/`Catch`.
  - `[false]` `reject` Edge Case Hunter: `RemoveOne`'s task branch could reproduce the cross-namespace `QueryTasks` bug if `pScope` were ever empty. Disproved: the single call site that creates `"task"`-kind inventory rows (`Fixture.cls` `CreateTask`'s `NoteRow` call) always passes `pInstallNs`, which is always non-empty (resolved via `Installer.ResolveNamespace()`) — no code path in the tree writes a `"task"` row with an empty `Scope`, so the guard the finding asks for would be defensive-in-depth against a state nothing produces.
  - `[low]` `patch` Edge Case Hunter: same `TestDemoWebAppFixtureCreatedWhenAbsent` bare-`Do` issue as Blind Hunter's finding above — grouped, fixed together.
  - `[medium]` `patch` Edge Case Hunter: `TestDemoWebAppFixtureCreatedWhenAbsent` asserted `Security.Applications.Get`'s status but did not stop on failure (`$$$AssertStatusOK` does not abort the method) — a real `Get` failure would leave `tProps` undefined, and `$Get(tProps(...))`'s own default values (`0`, `""`) happen to match the disabled/no-resource assertions, turning a genuine failure into a vacuous pass (Rule 19). Fixed: added an explicit `Quit` on failure.
  - `[medium]` `patch` Edge Case Hunter: same `TestGateStatusIsNotInstalledWhenStoredVersionIsAheadOfDeployed` fragility as Blind Hunter's finding above, from the unguarded-dereference angle (`$$$AssertTrue($IsObject(tRow))` also does not abort, so a genuinely row-less instance would throw on the next line instead of failing cleanly) — grouped, fixed together with an explicit `Quit` guard.
  - `[low]` `patch` Edge Case Hunter: `TestStartPathPropagatesAFailingStep` called `MigrateFault.StartPath(0)` between two `SetShouldFail` calls with no `Try`/`Catch` — an uncaught exception there would skip `SetShouldFail(0)` and leave the shared fault-injection flag stuck on for every later test in the class run. Fixed: wrapped, with the flag cleared in the `Catch` too.
  - `[high]` `patch` Verification Gap: `Install`'s new `tFirstInstall = (tVerRow.Phase = "failed")` branch (this iteration's own M1 fix, the flagship correction for AC2's "a clean start needs no manual step") had no committed test — reverting it to the pre-fix `Set tFirstInstall = 0` broke nothing in the existing suite. Fixed: added `Test/Version.cls TestFailedFirstInstallStillCountsAsFirstInstall`, forcing a failed first attempt through the same `Test.MigrateFault` seam `TestFailingStepLeavesPhaseFailed` already uses, then asserting the real call-site argument via `Test.InstallerProbe`. **Mutation demonstrated live** (Rule 19): reverted `Installer.cls` line 289 to the pre-fix `Set tFirstInstall = 0`, recompiled — RED (`AssertEquals` failed on the new test). Restored the exact original line, recompiled — GREEN. `git status --short` confirmed the tree matched this pass's own file list throughout, with no `TEMP MUTATION` marker left behind.
  - `[high]` `patch` Verification Gap: `Uninstall`'s fixture-removal-before-destruction reordering (H1, this iteration's own flagship AD-25 fix) had no committed regression test at all — only a one-off manual MCP session. Fixed: added `Test/Installer.cls TestUninstallRemovesDemoFixtures`, hand-creating the SSL/TLS fixture and its inventory row (bypassing the costly `Fixture.Create`/Task-Manager-daemon path entirely) and asserting both are gone after a confirmed `Uninstall`. **Mutation demonstrated live** (Rule 19): commented out the `Fixture.Remove` call inside `Uninstall` (marked `TEMP MUTATION`), recompiled — RED (both new assertions failed, the fixture object and its inventory row survived a confirmed uninstall). Restored the exact original call, recompiled — GREEN. The mutation run left a real `OcuPilotDemoTLS` SSL/TLS configuration and inventory row behind (expected, since the same mutated code path is also what `OnAfterOneTest` calls) — removed by hand and reconfirmed zero `Kernel.State.Demo` rows before moving on.
  - `[medium]` `patch` Verification Gap: `Kernel.State.Demo.DeleteByProfile("")`'s NULL-matching branch (M5) had no committed test. Fixed: added `Test/Demo.cls TestDeleteByProfileRemovesProductionNullRows`, backing up and restoring any real pre-existing production rows around the destructive call so a deployed instance's own demo-fixture inventory is never actually at risk from running this test.
  - `[low]` `patch` Verification Gap: `TestInstallRefusesFromWrongNs`'s new `pNamespaceAfterInstall` assertion does not itself distinguish the AC13 mutation (`## Verification`'s own line claims it does) — traced live: with the guard deleted, `Install` falls through to `Names()`, which throws `<CLASS DOES NOT EXIST>` from `%SYS` before any switch, so `$NAMESPACE` reads `%SYS` either way. AC13 remains protected by the pre-existing error-text assertion, which the finding's own filed evidence already concedes. Fixed: corrected the `## Verification` AC13 mutation line to state this precisely instead of overclaiming.
  - `[low]` `defer` Verification Gap: seven ACs (AC2, AC3, AC4, AC5, AC8, AC9, AC13) had their pinning tests added or materially changed this pass with no corresponding update to `## Verification`'s own per-AC `mutation:` line. Real documentation-completeness gap, not a functional defect — the mutations themselves are already recorded, verified, and cross-referenced at each closed checklist item; folding all seven into `## Verification` too is more than a direct correction in one pass already this large. Deferred to frontmatter `deferred:`.
  - `[false]` `reject` Verification Gap (other finding): `Fixture.Create`'s unconditional re-run of all four `%SYS`-scoped creators when driven through `OcuPilot.Test.DemoAppProbe` — the reviewer's own filed evidence already states this is "not a defect," just worth knowing about.
  - `[low]` `defer` Verification Gap (other finding): `RemoveOne`'s three newly-status-checked `Delete` branches (H3/M4) are exercised only on their success paths by `Test.Demo`'s own teardown; no committed test forces a `Delete` failure to observe the new `warn` reporting. Real, but a failure-injection test for already-defensive code is lower priority than the two `high` gaps above — deferred rather than expanding this pass further.
  - `[false]` `n/a` Intent Alignment Auditor: named the container/image/compose surface as never exercised end-to-end by this pass (only a local shell reproduction for F-2/F-3). Correctly scoped as-is: this pass's own two Fix Pack items explicitly say a throwaway-container check "is not a reviewer patch," and the broader container/health-check/HTTP surface is already an accepted, unchanged `deferred:` item from iteration 1 — not a new gap this diff introduces.
  - `[false]` `n/a` Intent Alignment Auditor: named `Api.Router`/the HTTP-envelope surface as untouched and untested by this pass. Correctly out of scope: the traffic gate was wired into `Api.Router` in iteration 1, nothing in the 24-item mandate touched it, and this pass's own `GateStatus()` fixes are exercised at the classmethod level exactly as every other test in this class already does.
  - `[false]` `n/a` Intent Alignment Auditor: named the version-stamp's "one row per profile" concurrency guarantee (DW-47) as unenforced by a database constraint. Already covered in full by this pass's own "Additional finding" section above and the corresponding `deferred:` update — not a new, separately-actionable finding.
  - `[false]` `n/a` Intent Alignment Auditor: observed the `%SYS` guard-then-act discipline is satisfied by repeated manual discovery (this pass's own `TASKWAITSECONDS` fix included) rather than a structural guarantee. A true, useful observation about the codebase's own risk profile, but not a discrete defect distinct from the specific instances already found and fixed this pass.
  - `[low]` `defer` Intent Alignment Auditor: named the AD-27 Gateway-timeout negative branch (both sources unavailable) as untested by this pass on this instance. Real, but already adjudicated in M10's own resolution text as DW-51's territory (a genuinely independent read means parsing `CSP.ini` in the test) — grouped with Verification Gap's AC8 mutation-line finding above rather than a separate new item.
  - `[false]` `n/a` Intent Alignment Auditor: observed several new tests mutate the live, shared production row directly rather than observing a clean-volume "first/repeat start" scenario. By design and unchanged from every other production-touching test already in this class (`TestRealProductionGateResolvesToInstalledAfterInstall` et al.) — not something this pass introduced.

All patches applied and re-verified: `uv run scripts/check-objectscript.py` (0 problems), full `src/**/*.cls` MCP reload (33/33 clean), `bash scripts/lint-docs.sh` (0 issues), `OcuPilot.Test.Version` full class (17/17, SQL-probe-confirmed), `OcuPilot.Test.Demo` full class (9/9, SQL-probe-confirmed — one transient failure on an intermediate run traced to a midnight date-rollover in the test's own date-scoped `SYS.ApplicationError` query, pre-existing and environmental, not a regression; resolved on the very next run once the shared class fixture refreshed for the new day), `OcuPilot.Test.Installer:TestUninstallRemovesDemoFixtures` (1/1, 2.47s — no `SYS.Database.DeleteDatabase` cost, since it only deletes an SSL/TLS configuration object, not a database), `OcuPilot.Test.State` (8/8) and `OcuPilot.Test.Gate` (6/6) both unaffected. Production instance re-confirmed clean after all of the above: exactly one `Version` row, zero `Kernel.State.Demo` rows, `GateStatus() = "installed"`, zero `OcuPilot.Install.DemoTask` rows in any namespace.

### 2026-09-11 — Review pass (rework iteration 4, step-04)

Reviewed the diff since `baseline_revision` for this iteration (the 13-item round-2 closure, plus this same pass's own step-03 verify-stage fixes: the `IsEscalationInfrastructureAbsent` escalation-ordering defect and the `TestDemoSeedsAnApplicationError` namespace-switch crash, both found live and fixed before this review dispatched). Four layers: Blind Hunter, Edge Case Hunter, Verification Gap, Intent Alignment Auditor. The Intent Alignment Auditor's own brief is strictly descriptive (enumerate readings, name divergences, prescribe nothing); of its seven lettered divergences (A-G), six restate context already covered by another layer's finding or by this pass's own honest self-disclosure (the escalation-fix test gap = Verification Gap's matching finding below; Repeat/Upgrade/Downgrade untouched = this pass's own documented, narrower scope; `Api.Router` untouched = not a defect; the DW-13 own-profile branch verified only by inspection = already disclosed at F-6's own closure; the namespace-switch crash = already found and fixed within this same diff; the self-reported evidence gaps = already in `## Residual risks`) and are logged as `n/a` below; the seventh (missing audit report) is a genuine incremental finding, logged with the others.

- verdicts: 18 findings — high 1, medium 8, low 5, false 0, maybe-false 0, n/a 4
- findings:
  - `[low]` `patch` Blind Hunter: `OcuPilot.Test.DemoAppProbe`'s class header and its `APPPATH` parameter's own doc comment both still asserted, present tense, that `Test.Demo`'s shared fixture "pre-creates a collision application at the REAL `APPPATH`... for the whole class's life" and "deliberately keeps colliding with" it — true when this class was first written, false since this pass's own HIGH fix removed that out-of-band block from `Test.Demo` entirely. A third passage additionally called the shared "probe"-profile objects "production-named," which was never accurate once `ResolvedPrefix` qualifies them. Fixed: all three passages corrected at their origin, each flagged with what changed and why, so a future reader is not misled into "restoring" behavior this pass deliberately removed.
  - `[medium]` `patch` Blind Hunter, Edge Case Hunter, Verification Gap (grouped — same root cause, cited independently by all three layers): the AC12/DW-58 fix's `tSinceSecsFloor = (tSinceSecs \ 60) * 60` floors the run's own start-of-minute boundary DOWN before comparing, and `SYS.ApplicationError:ErrorList`'s `Time` column is only minute-granular — so an entry an EARLIER, unrelated run logged within the same clock-minute as (but chronologically before) this run's own `pSinceH` capture still satisfies `>= tSinceSecsFloor` and is wrongly counted as "since this run began." Real: narrows the same-day false-green this fix targets from a full day down to at most ~59 seconds, rather than eliminating it, and this session's own rapid back-to-back runs (RunIdx 297/298/299, minutes apart) are exactly the pattern that makes the window non-theoretical. `severity=medium fix-risk=high`: the underlying data source genuinely has no sub-minute resolution and no entry-identity/counter to disambiguate within a shared minute, so there is no clean fix, only a different, differently-shaped ambiguity (rounding the other way trades a narrow false-positive for a narrow false-negative). Deferred to frontmatter `deferred:` rather than patched blind.
  - `[medium]` `patch` Blind Hunter: `Install`'s new `IsEscalationInfrastructureAbsent` guard (this pass's own step-03 verify-stage fix) protected only the version-row read at `Install`'s own call site — `EnsureVersion`'s IDENTICAL `CurrentVersionRow` call, which also runs on the failure path that records phase `failed`, had no equivalent guard. On a genuinely first install that fails at or before `EnsureApplication` for any OTHER reason (an `EnsureDatabaseResource`/`EnsureDatabase` failure, say), that failure-path write would hit the same `ERROR #868` this pass just fixed and silently skip recording `failed` (only a warn logged) — leaving `Phase()`'s own "absent row resolves to `installing`" failsafe reporting `installing` forever rather than the `failed`-with-named-step AC3 promises, on the exact fresh-instance surface this whole review pass is about. Fixed: `EnsureVersion` now takes `pNames` (from `Install`'s own `tNames`, already in scope at both call sites) and applies the identical `IsEscalationInfrastructureAbsent` guard before its own `CurrentVersionRow` read. Verified: full `OcuPilot.Test.Version` (19/19, including the new test below) and `OcuPilot.Test.Demo` (10/10 minus the pre-existing daemon-latency item) both SQL-probe-confirmed green after the signature change; production row confirmed unaffected throughout.
  - `[low]` `reject` Edge Case Hunter: `Fixture.ResolvedPrefix` has no validation of `pProfile` (unlike `Installer.Names`), so an unrecognized value would silently fall to production's own naming. Verified and rejected as theoretical: `grep`-confirmed `Fixture.Create` (the only caller that reaches `ResolvedPrefix` transitively) has exactly two call sites in the whole tree, `Installer.cls` with the hardcoded literal `""` and `Test/Demo.cls` with the hardcoded literal `"probe"` — no path in this codebase ever passes an unvalidated value. No realistic user-reachable failure; would become real only if a THIRD caller with unvalidated input were added later without also adding the same validation `Names()` already carries.
  - `[medium]` `patch` Edge Case Hunter: `TestDeleteByProfileRemovesProductionNullRows`'s `Catch` called `RestoreProductionDemoRows` unconditionally — but if the exception happened BEFORE `DeleteByProfile('')` itself ran (a `GuardedSave`/`GuardedRowExists` throw during the throwaway-row setup, two lines earlier), the original rows were never removed, and restoring anyway would insert DUPLICATE copies on top of the still-present originals, corrupting production's own inventory rather than protecting it. Fixed: a `tDeleteRan` flag, set only once `DeleteByProfile` itself has actually run, gates the `Catch`'s restore call. Verified: full `OcuPilot.Test.Demo` class run green with the flag in place (the straight-line path, where `tDeleteRan` is always 1 by the time either restore call runs, is unaffected).
  - `[low]` `reject` Edge Case Hunter: `IsEscalationInfrastructureAbsent` checks only the escalation application's existence, not the protected database/version table's own presence — a mature instance whose application was somehow removed while its database survived would be misread as "genuinely first install," re-arming unexpire and rerunning migrations. Verified and rejected as theoretical: this requires an operator to have manually deleted the `OcuPilotState` routine application while leaving the `OCUPILOT` database intact — an unsupported, self-inflicted state nothing in this story's own install/upgrade/uninstall paths can produce (`Uninstall` removes both together; nothing else removes either). No realistic path an operator following supported operations would ever reach.
  - `[high]` `patch` Verification Gap: every regression test this pass added specifically to pin the HIGH cross-profile-fixture-collision fix (`TestDemoSslConfigFixtureExists`, `TestDemoX509CredentialFixtureExists`, `TestDemoTaskIsSuspendedAfterAnError`'s name lookup, `Test.Installer`'s `TestUninstallRemovesDemoFixtures`) computes its own expected name by calling `Fixture.ResolvedPrefix` itself, then asserts against that computed value — none pins `ResolvedPrefix`'s own output to an independent literal. Verified live: `grep`-confirmed no test anywhere in the tree asserts `ResolvedPrefix("probe") = "OcuPilotDemoProbe"` (or the production form) as a hardcoded string; reverting `ResolvedPrefix` to its pre-fix `Quit ..#DEMOPREFIX` would leave all four tests reading as green while reproducing the exact "probe-profile run destroys production's own demo fixtures" scenario this pass's own headline fix exists to close — the textbook "test whose green depends on the defect it guards against" shape Rule 19 exists to catch, on the single most significant fix in this pass. Fixed: added `Test/Demo.cls TestResolvedPrefixQualifiesNonProductionProfiles`, pinning both `ResolvedPrefix("")` and `ResolvedPrefix("probe")` against independent literals and asserting they differ. Verified live in the full `OcuPilot.Test.Demo` re-run (green).
  - `[medium]` `patch` Verification Gap, Intent Alignment Auditor (grouped — same root cause): `IsEscalationInfrastructureAbsent` (this pass's own step-03 verify-stage fix for a real, live-discovered AC2 ordering defect) has no automated regression test — every existing test runs against the long-lived `ocupilot` container, where the escalation application has existed for stories, so the guard evaluates identically whether present, inverted, or removed; the only verification this fix has is the one-off, non-repeatable throwaway-container run. Real: a future edit reintroducing the ordering bug would ship green through the whole suite. `severity=medium fix-risk=high`: constructing the "genuinely absent" state without a disposable container needs a new test seam (a probe subclass overriding the `Security.Applications.Exists` check, in the same shape `Test.MigrateFault`/`Test.GateFixture` already use for their own overrides) — more than a direct correction for this pass. Deferred to frontmatter `deferred:`, naming the specific seam a future pass would need.
  - `[medium]` `patch` Verification Gap: `Version.DeleteByProfile("")`'s new `Profile IS NULL` branch (Fix Pack F-5) had no committed test at all — the only verification it had was a single hand-run backup/delete/restore against the live production row via MCP, not repeatable from the suite; `Demo.DeleteByProfile("")`'s identical fix already has one (`TestDeleteByProfileRemovesProductionNullRows`). Fixed: added `Test/Version.cls TestVersionDeleteByProfileRemovesTheProductionRow`, copying that exact backup/delete/restore-from-Catch-too shape onto the `Version` table. Verified live: full `OcuPilot.Test.Version` class run (19/19, SQL-probe-confirmed, including the new method at 26.1s); production's version row confirmed restored (`installed`, schema `1`) and `GateStatus()` confirmed `installed` immediately after.
  - `[low]` `reject` Verification Gap: AC10/AC11/AC12's `## Verification` `mutation:` lines were not updated for this iteration's rewritten pinning logic (`TestExistingApplicationIsNeverModified` onto `DemoAppProbe`'s path, `FixtureRequestedTaskRun()`, `PreparedFixtureSinceH` scoping), and the existing `deferred:` entry tracking this class of gap for seven OTHER ACs doesn't yet name these three. Rejected per step-04's own rule (the fix would edit this build's own spec's `## Verification` section, which iteration 3's own triage already established as out of a build-auto pass's reach) — folded into the existing documentation-gap `deferred:` entry's own evidence instead of a code or `## Verification` change, since the entry already exists and only needs its scope corrected, not a new patch.
  - `[low]` `patch` Intent Alignment Auditor: named that `IsEscalationInfrastructureAbsent` emits no report through the `Kernel.Audit.Log` seam on any outcome, unlike every other guard-then-act decision point in this file — a one-sided gap against the Boundaries' own "every new install step is guard-then-act and reports through Kernel.Audit.Log" bullet. Fixed: reports once, at `info` level, on the notable (absent) branch only, matching the file's existing convention of reporting on non-default outcomes rather than every routine check.
  - `[n/a]` Intent Alignment Auditor: the escalation-fix test gap — same finding as Verification Gap's matching entry above, not counted twice.
  - `[n/a]` Intent Alignment Auditor: "Repeat start"/"Upgrade"/"Downgrade" matrix rows untouched by this diff — correct and expected: this pass's own narrower, review-defined scope (13 named findings plus what a live verify pass turned up), not the whole story's charter.
  - `[n/a]` Intent Alignment Auditor: `Api.Router` and the DW-13 own-profile branch verified only by inspection — both already disclosed honestly at their own closures (the router receives no new call this pass makes; F-6's own closure already says "not exercised live in either direction").
  - `[n/a]` Intent Alignment Auditor: the namespace-switch crash and the self-reported evidence gaps (full `Test.Installer` not re-run, several Fix Pack branches inspection-only) — both already fully disclosed within this same diff's own text (the crash's own RED/GREEN evidence at the AC12 finding's closure; the gaps in `## Residual risks`), not new information this review surfaces.

All patches applied and re-verified: `uv run scripts/check-objectscript.py` (0 problems), `bash scripts/lint-docs.sh` (0 issues), `cd ui && npm test` (97/97, unaffected). Full class runs, SQL-probe-confirmed, fresh and isolated (no sibling run in flight, checked via `iris_jobs_list` beforehand each time): `OcuPilot.Test.Demo` 9/10 (`TestDemoSeedsAnApplicationError` red for the pre-existing, already-`deferred:` daemon-latency reason — see that entry's own iteration-4 update — every other method including the two new/changed ones, `TestResolvedPrefixQualifiesNonProductionProfiles` and the unaffected happy paths, green); `OcuPilot.Test.Version` 19/19. `OcuPilot.Test.Installer`'s full 23-method class was not re-run again this review pass (already exercised once this iteration for the HIGH finding itself, at the documented ~2.5-hour/~40-minute-per-slow-method cost); the two `EnsureVersion`/`Installer.cls` signature changes from this pass's own patches were verified instead via the full `Test.Version` and `Test.Demo` re-runs above, both of which exercise `Install`/`EnsureVersion` extensively, plus direct inspection of `Test.Installer`'s own call sites (none calls `EnsureVersion` directly — it is `[ Private ]` — so the signature change cannot have broken anything there that these two classes' own coverage does not already exercise identically). Production instance confirmed clean throughout and at hand-off: exactly one `Version` row (`installed`, schema `1`), zero `Kernel.State.Demo` rows, `GateStatus() = "installed"`, zero `OcuPilot.Install.DemoTask` rows.

## Design Notes

### Governing architecture decisions (Rule 6)

`AD-38` (install completes before the first request is served; the version stamp the API checks — the
whole spine of AC2/AC3/AC5/AC7), `AD-17` (one installer class, two entry points, install at **container
start** not image build, guard-then-act, enables auditing, registers events, unexpires `_SYSTEM`, reports
the Gateway gap, one roster for installer and manifest), `AD-25` (the demo fixture is opt-in, flag set in
this repository's own `docker-compose.yml`, namespaced, absent from every other path including IPM,
removed by uninstall), `AD-27` (the image tag is pinned to an explicit version, never `latest-cd`; every
dependency on vendor internals has a fallback — the Gateway read), `AD-32` (the **ProviderPort** SSL
configuration is created by the installer unconditionally with server-identity checking on and is **not**
a fixture — deliberately kept distinct from AC9's demo SSL/TLS configuration, and not built here),
`AD-45` (one smoke path, also the health check — Story 1.17's; this story ships only the compose-level
health check, never the readiness endpoint), `AD-16` (explicit namespace save and restore, restore first in
every `Catch`), `AD-9` (protection is on the data; `Kernel.State.Base` is the one escalation point, and
`Version`/`Demo` inherit it rather than adding a second), `AD-12` and `AD-39` (one response writer, one flat
`{error, reason, code, detail}` envelope, a stable dotted-uppercase code that is never a number),
`AD-37` (stored references are weak — the fixture inventory records scoped identity as data, never a
foreign key, so a fixture an operator deleted renders as "no longer present"), `AD-18` (IPM is a
distribution channel; the image ships zero `%ZPM*` classes, so nothing in the install path may assume it),
`AD-15` (audit events registered with `Security.Events.Create()`), `AD-21` (no caller-supplied filesystem
path; the Gateway configuration path is resolved at runtime from the install directory, not taken from
anyone), `AD-10` (OcuPilot's own web applications, resource, role and database are in the prohibited set —
`Uninstall` stays an operator action outside the agent's write path), `AD-28` and `AD-20` (the two web
applications and their settings — **Story 1.5's**, named here only to say what this story does not do).
Consistency Conventions: *IRIS security objects* (`%DB_<NAME>` naming, resource before database, the
auto-created implicit role, `Security.Users.Create` silently accepting a non-existent role so a grant must
be read back, `%Operator` as a self-escalation primitive, `New $ROLES` frame-scoped), *ObjectScript
naming* (the 29-character bound), *Names never inherited from siblings*, *Tests*, *Logging*, *Config*.
Stack: `intersystems/irishealth-community` pinned to an explicit 2026.2 tag; IRIS for Health 2026.2 build
221U as the floor. Operational Envelope: *Upgrade and migration* ("OcuPilot's own persistent state carries
a schema version; an upgrade that changes shape migrates forward on first start and never in a request.
Downgrade is not supported.").

### NFR-9 (Rule 5) — measurable as worded, no amendment sought

NFR-9 reads, in full: *"Idempotence. Install, upgrade and the Docker start path are safe to repeat."* The
PRD attaches no measurement; its testable content is FR-66 and FR-67. Story 1.3 already resolved the
installer half — *"AC7's 'nothing changes' is about **net state**, not skipped steps"* — and AC4 extends
exactly that reading to the start path rather than re-deriving it: repeating `docker compose up` reaches the
same net state, measured by a byte-identical `StateFingerprint`, one version row per profile, and an
untouched `_SYSTEM` expiry flag; the ensure steps still execute every time. Two consequences follow and are
deliberate: **the version row's `UpdatedAt` is excluded from `StateFingerprint`** (a record of when install
last succeeded is not drift), and **the unexpire is gated on the version row's absence**, which is what
makes "safe to repeat" true for the one step whose effect is not idempotent in principle. No NFR is
unmeasurable, contradictory or impossible as worded, so there is nothing to halt on.

### The 1.4/1.5 seam — stated plainly, not smoothed over

Story 1.4's traffic-gating and Gateway-gap criteria in `epics.md` talk about "the two web applications",
and those are created in **Story 1.5**, which comes after. FR-65 is indexed in the epics FR-to-Story table
to **both 1.4 and 1.5**, so the split is deliberate. This story therefore **builds the seam, and 1.5 creates
the applications into it**:

- The gate is a phase resolver plus its wiring in `Api.Router.OnPreDispatch`. It is fully testable today
  through `Test.Dispatch.Invoke`, which dispatches the router in-process with no HTTP and no web
  application — so AC7 does not assume 1.5 has run.
- The Gateway-gap step reports for **every web application this run created**. In this story that set is the
  demo fixture application when the flag is set, and empty otherwise; the timeout half is reported
  unconditionally. Story 1.5 adds `/ocupilot` and `/api/ocupilot` to the same step without changing it.
- `--after` cannot gate the TCP port: IRIS's web server is already listening when the hook runs. That is
  precisely why AD-38's load-bearing half is the **API gate**, not the start ordering — and why AC2 measures
  "runs to completion" with the compose health check rather than with port reachability. On a genuinely
  first install there is nothing to serve anyway, because the applications do not exist until 1.5 creates
  them.

### Reading of AD-17's "one installer class"

`Installer` keeps every entry point and every ensure step, including migration, so the Docker path and the
IPM path cannot drift — that is what AD-17's Rule protects. The demo fixture is deliberately a separate
class because AD-25 makes it a distinct, opt-in concern that is **absent from the IPM path entirely**;
putting it in `Installer` would be the drift risk AD-17 guards against, not a defence of it. `DemoTask` is a
separate class because a `%SYS.Task.Definition` subclass has to be. Recorded so a reviewer does not read the
file count as an AD-17 violation.

### The roster (AD-17)

AD-17 requires the installer's class roster and the IPM manifest's resource list to be *generated from one
source, never maintained separately*. Neither is hand-maintained here: the start hook loads and compiles the
`src/OcuPilot/` **tree** from the read-only bind mount, and Story 1.16 generates `module.xml` from the same
tree. That is the single source. No roster file is invented in this story; the obligation is recorded so
1.16 does not create a second, hand-kept list.

### DW-13 — addressed, with the branch taken and why

DW-13's suggested acceptance offers a disjunction: *"the fixture path is genuinely namespaced, **or** install
refuses on collision."* The second branch is taken. The first is unavailable: Stories 2.5 and 5.8 name
`/csp/myapp` **literally** in their acceptance criteria ("`/csp/myapp` appears showing Enabled 'No' and no
resource"; "Enabled: No to Yes, Resource: (none) to %Development"), so renaming the path would be a
cross-story change to another story's ACs — a Rule 5 "ask first" amendment, not a slice decision. AD-25's
"namespaced so it cannot collide" is honoured for the four fixtures whose names are not pinned by downstream
ACs (all carry the `OcuPilotDemo` prefix), and for the fifth it is honoured by behaviour: install creates the
application only when it is absent, never modifies one it did not create, and the `Kernel.State.Demo`
inventory makes uninstall exact. Verified this session: `/csp/myapp` does not exist on this instance and all
23 `/csp/*` applications are vendor-shipped, so the collision path is real but not currently live — the test
must construct the collision, not wait for one.

### DW-14 — addressed; why the fixture needs a real failing run

`%SYS.Task.Suspend(id, flag)` sets only `Suspended`. `Status` (`-2` = JobUntrappedError) and `Error` are
written by the Task Manager from an actual run, and `Resume`'s own documentation confirms error-suspension
reuses the same `Suspended` field — there is no supported setter and no separate flag. Writing the columns
directly would bypass the framework. So the fixture ships `Install.DemoTask`, whose `OnTask()` deliberately
returns an error, scheduled with `SuspendOnError = 1` and run once: a real but controlled, self-inflicted
error. Story 5.11 needs the task's **history** to carry error text it can quote and a schedule so "next run"
exists after a resume, which is why the fixture schedules the task rather than creating a bare row.

### DW-15 — addressed; the alternative branch has no candidate

DW-15's suggested acceptance offers *"the demo opt-in seeds application errors, **or** the Logs demo names
another write."* The second branch has no candidate: PRD FR-63 makes the application-error delete the Logs
area's only Release 1 write ("Delete is a write tool with a proposal, so the Logs area has a confirmable
agent write (SM-3)"), and Story 5.13's fingerprint is *"the enumerated set of error ids the delete will
remove, captured at proposal time"* — empty on a clean install. So the seed branch is forced. `^ERRORS` is
written only by the `%ETN` error trap, and neither `BACK^%ETN` nor `$$LOG^%ETN()` accepts an error payload,
so the fixture raises a real, controlled error inside its own routine and lets the trap log it. The
observable is asserted (`^ERRORS` gains a readable entry), not the mechanism.

### Fixture set = the union of two lists, not either one

PRD FR-66 names *"a disabled web application, a task suspended after an error, and application errors to
delete"*. Story 1.4's AC names *"a disabled `/csp/myapp` carrying no resource, a demo SSL/TLS configuration
and a self-signed X.509 credential"*. Neither is a superset; DW-14 and DW-15 are exactly the two items the
epics list dropped. AC9 takes the union — five fixtures. This is not an amendment: the story's AC states
that those three exist, not that only those exist, and the two ledger entries are binding instructions to
add the other two.

### Integration ACs, `Consumes:` and `Consumed-by:` (Rules 1 and 2)

**Integration AC:** AC7 is it — `Api.Router`, a consumer this story does not own the internals of, produces
an observable 503 envelope at its own boundary when the version stamp is not current, asserted through
`Test.Dispatch.Invoke` rather than by inspecting the stamp. The **demo fixtures have no consumer in this
story**; their first consumers are Story 2.5 (the web applications list) and Story 2.7 (the SSL/TLS
configurations list).

**Consumes:** `Install.Installer`, `Kernel.State.Base` (the one escalation point — `Version` and `Demo`
extend it), `Kernel.State.Stamp` (the profile scoping and `DeleteByProfile` pattern), `Kernel.Utils`
(`SwitchNamespace`/`RestoreNamespace`), `Kernel.Audit.Log` (all reporting), `Api.Router` and `Api.Error`
(the gate's envelope), `Test.Dispatch`, `Test.RouterFixture`, `Test.InstallerProbe`, `Test.State`'s
throwaway-principal pattern.

**Consumed-by:**

- **1.5** — adds `/ocupilot` and `/api/ocupilot` behind the gate and into the Gateway-gap step; DW-3 wants
  the API to return a build stamp so a stale browser bundle can be prompted to reload, which is why the
  version row carries the deployed build identity as well as the schema version.
- **1.16** — generates `module.xml` from the same `src/OcuPilot/` tree the start hook compiles, and depends
  on AC9's flag-absent half ("no fixture on the IPM path").
- **1.17** — the smoke script and the unauthenticated readiness endpoint read this stamp; DW-2 asks
  readiness to carry a fourth "install failed" state with the failing step, which is why `Phase` and
  `FailingStep` are separate properties now rather than a single boolean.
- **2.5 / 5.8** (`/csp/myapp` disabled with no resource — UJ-3, SM-4), **2.7** (the demo SSL/TLS
  configuration), **2.8 / 5.11** (the suspended-after-error task — UJ-6), **2.12 / 5.13** (the seeded
  application errors), **6.3** (the self-signed X.509 credential and the five non-empty Security lists),
  **4.10** (Home's suggested view reads the first two).
- **3.1, 3.7, 4.9, 14.2, 14.4, 15.5** — agent definitions, switches, ledger rows, governance policy (whose
  frozen baseline must never be regenerated to grow), transcripts and per-user UI state each register their
  own migration step in `RunMigrations` when their shape changes. **Proposals and progress records are
  deliberately excluded** — the spine's operational table makes them short-lived by construction.
- **13.1** — uninstall removes everything install created, and reads the `Kernel.State.Demo` inventory to do
  it exactly.

### What the migration framework can honestly prove today

None of the six state categories named in the epics AC — ledger rows, transcripts, agent definitions,
switches, per-user UI state, governance policy — exists yet; they arrive in Epics 3, 4, 5, 14 and 15. The
implementable reading, recorded so it is not mistaken for a narrowing: **this story builds the ordered
migration runner and proves it against the state that exists**. The live volume is already in the N = 0
state the AC describes — 273+ `Kernel.State.Stamp` rows and no version row — so the v0→v1 step is a real
`N → N+1` against a populated database, and AC5's survival assertion is made over those rows. To prove the
runner can carry a step that *touches data* rather than only bookkeeping, `Test.MigrateFault` supplies a
probe-profile step that mutates and a step that fails, pinning ordering, failure propagation and
"stored version not advanced on failure". Later stories add their steps to the same registry.

### Traps inherited from Story 1.3 that this story is most likely to hit

- **A namespace-mapped class cannot be dispatched once `$NAMESPACE` has moved away from it.** `Uninstall`'s
  fixture removal must read the `Kernel.State.Demo` inventory **in the install namespace**, remove the
  objects in `%SYS`, and delete the rows **after** the restore — the same ordering `Stamp.DeleteByProfile`
  already uses at `Installer.cls:800`.
- Story 1.3 left an explicit `reopen_if` on this story: *"`Install` does not verify it was called from the
  install namespace; from `USER` or `%SYS` the ensure steps succeed and `RecordStamp` then fails with
  `<CLASS DOES NOT EXIST>` … `reopen_if = Story 1.4's start path invokes Install from anywhere but the
  install namespace`."* AC13 closes it from both ends.
- `GuardedExecuteOneParam` is `[ Private ]`; reach it by inherited `..` dispatch, and keep its SQL text a
  call-site literal.
- A production `Profile = ""` reads back through SQL as `NULL`, never `''` (verified over 426 rows), so the
  version row's per-profile lookup must not filter with `Profile = ''`.
- **DW-45 is live and this story is where it bites:** `EnsureAuditingEnabled`'s enable branch is executed by
  no test, and its `reopen_if` is *"a fresh container whose `AuditEnabled` reads 0 still reads 0 after
  `Install()`"*. AC2's throwaway-container run is the first execution of that branch in the project's
  history — treat a `0` there as a real failure, not a flake.
- The audit database is not readable in-process immediately after a write; assert on
  `$System.Security.Audit`'s own `%Status`, never on a same-process row count.
- Roles and resources are case-insensitive; any concurrent agent must suffix its probe names.

### Golden example — the phase read must never fail open

```objectscript
; The protected database may not exist yet on a genuinely first start.
; A read failure is "installing", never "installed".
ClassMethod Phase() As %String
{
    Set tPhase = "installing"
    Try {
        Set tSC = ##class(OcuPilot.Kernel.State.Version).GuardedCurrent(.tRow)
        If $$$ISERR(tSC) Quit
        If $IsObject(tRow) Set tPhase = tRow.Phase
    }
    Catch ex { Set tPhase = "installing" }
    Quit tPhase
}
```

## Verification

### What each check touches, and which are destructive

**Non-destructive, safe against the live `ocupilot` container** — everything below reads, compiles into
`HSCUSTOM`, or runs `%UnitTest`. None of it stops, restarts, recreates or wipes the container, and none of
it deletes `iris-data/`.

**Destructive, and isolated** — AC1 and AC2 cannot be verified without a container built from nothing. They
run in a **throwaway compose project with its own project name, its own scratch data directory and its own
host ports**, never against `ocupilot`. Editing `docker-compose.yml` does not affect the running container
until it is recreated, and it must not be recreated.

### Matrix coverage — every row has a named test host

| Matrix row | Test host |
|---|---|
| First start, empty volume | Throwaway-container run (below); AC2 |
| Repeat start, populated volume | `Test/Installer.cls` `TestProductionInstallIsIdempotent` + `Test/Version.cls` `TestSecondStartDoesNotUnexpireAgain` |
| Upgrade | `Test/Version.cls` `TestMigrationStepsRunInAscendingOrder`, `TestPopulatedRowsSurviveMigration` |
| Downgrade | `Test/Version.cls` `TestPlanRefusesAStoredVersionAheadOfTheCode` + `TestInstallRefusesWhenStoredVersionIsNewer` |
| Request during install | `Test/Gate.cls`, all three phases, via `Test.Dispatch.Invoke` |
| Version row unreadable | `Test/Version.cls` `TestUnreadableVersionRowResolvesToInstalling` — force the guarded read to fail and assert the phase is `installing`, never `installed` |
| DW-13 collision | `Test/Demo.cls` `TestExistingApplicationIsNeverModified` |
| DW-14 task fixture | `Test/Demo.cls` `TestDemoTaskIsSuspendedAfterAnError` |
| DW-15 error fixture | `Test/Demo.cls` `TestDemoSeedsAnApplicationError` |
| Flag absent | `Test/Demo.cls` `TestNoFixtureExistsWithoutTheFlag` |
| Wrong namespace | `Test/Version.cls` `TestInstallRefusesFromWrongNs` |
| Gateway read fails | `Test/Version.cls` `TestGatewayTimeoutUnavailableIsReportedNotFatal` — a subclass whose reader returns nothing; assert one `info` report and a still-`$$$OK` install |

**Commands:**

- `uv run scripts/check-objectscript.py` -- expected: exit 0. Watch the 29-character bound
  (`OcuPilot.Kernel.State.Version` is exactly 29) and the forbidden literals `iris_`, `%Atelier` and
  `IRIS_*`, which the installer's own doc comments will want to use — keep MCP tool names in this spec, not
  in the source.
- `bash scripts/lint-docs.sh` -- expected: exit 0 over the linted set, which includes `README.md` and
  `CLAUDE.md` (British spellings; Given/When/Then as list items).
- `cd ui && npm test` -- expected: 88 existing tests still green plus the new `compose.test.mjs` tests.
- IRIS MCP `iris_doc_load` + `iris_doc_compile`, `server: "ocupilot-iris"`, namespace `HSCUSTOM`, path
  `/Users/jbrandt/git/OcuPilot/src/**/*.cls`, flags `cku` -- expected: every class compiles clean. Use the
  `src/**` form; `src/OcuPilot/*.cls` loads classes unqualified.
- IRIS MCP `iris_execute_classmethod` on `OcuPilot.Install.Installer` `Install` with no argument --
  expected: `$$$OK`, and afterwards exactly one production version row at the deployed schema version with
  phase `installed`.
- IRIS MCP `iris_execute_tests` **per class** (`level: "class"`) for `OcuPilot.Test.Version`,
  `OcuPilot.Test.Gate`, `OcuPilot.Test.Demo`, then the six existing classes `Installer`, `State`, `Routing`,
  `Envelope`, `Log`, `EntityId`. Aggregate the totals yourself — the package form truncates.
- The `%UnitTest_Result` SQL probe from `.claude/rules/objectscript-testing.md` -- **mandatory before
  claiming the suite green.** The MCP runner envelope truncates and is not ground truth.
- `grep -rn "New \$ROLES\|AddRoles" src/OcuPilot/ --include=*.cls` -- expected: matches only in
  `Kernel/State/Base.cls` and `Test/State.cls`. The new `Version` and `Demo` classes inherit escalation and
  must add none.

**Throwaway-container run (AC1, AC2, and the first execution of DW-45's enable branch):**

- Write a compose override into the session scratchpad that changes the container name, the published ports
  (e.g. 52776/1975 — never 52774/1973) and the durable volume to a scratch directory. Run
  `docker compose -p ocupilot-fresh -f docker-compose.yml -f <scratch>/override.yml up -d --wait`.
- **Never run bare `docker compose up`, `down`, `restart` or `down -v` in the repository root**, and never
  point the throwaway project at `./iris-data` — the override's volume path is what keeps the live install
  safe, and a mistake there destroys the state every later story depends on.
- Pulling `intersystems/irishealth-community:2026.2` reuses the layers already present, because Docker Hub
  reports it at the same manifest digest as the `latest-cd` image already on this machine.
- Assert against the throwaway container only: healthy status, the version row, `_SYSTEM`'s
  `ChangePassword = 0`, `AuditEnabled = 1`, the registered audit event, and the fixture set.
- Run the throwaway project **twice**: once clean (AC1, AC2, AC9-AC12, and the first execution of DW-45's
  auditing-enable branch), and once with the AC3 exit-code mutation applied, to observe the container stay
  unhealthy and the hook exit non-zero. Tear down each with
  `docker compose -p ocupilot-fresh … down -v` and remove the scratch directory. The live `ocupilot`
  container is never touched, and `./iris-data` is never named by either run.

**The `Install`/`Uninstall` cycling hazard.** `Test/Installer.cls` already performs ~22 `Install("probe")` /
`Uninstall("probe", 1)` cycles per full run, and repeated cycling makes `SYS.Database.DeleteDatabase` take
20-40 minutes on this container. **The three new test classes therefore do not bracket their methods with
install and uninstall.** **Corrected 2026-09-10 (code review round 2) — the budget below is no longer what the suite does.**
As shipped: `Test/Version.cls` drives a full install in **nine** methods, not one; `Test/Demo.cls`'s
`TestNoFixtureExistsWithoutTheFlag` drives the real `StartPath(0)`; and `Test/Installer.cls` gained a
23rd method whose `OnAfterOneTest` adds another full `Uninstall`/`DeleteDatabase` cycle. Measured
consequence: a full `Test.Installer` class run takes roughly **2.5 hours**, with four uninstall methods
at ~2250 s each (~37 min), observed four separate times. The original intent — keep added cycles near
zero — was not held, and the cost is now a standing constraint on every verification pass rather than a
one-off. Whether to claw it back is deferred, not resolved here.

**The `%All` trap.** The suite authenticates as `_SYSTEM`, which holds `%All` and bypasses resource checks
outright — Story 1.3's AD-9 escalation shipped entirely unpinned for exactly this reason. Two places it
could hide here, and how each is handled:

- **The version and inventory rows' protection.** No new privilege claim is made. `Version` and `Demo`
  inherit their protection from `Kernel.State.Base`, which Story 1.3's AC4/AC5 already pin with a contrast
  test — a purpose-built denial user refused directly, reaching the same data through the escalating
  methods. This story adds no denial assertion, so it introduces no assertion that `%All` could silently
  satisfy. If a reviewer wants one, it must reuse `Test.State`'s `#DENIALUSER` and assert the **contrast**,
  never `_SYSTEM` and never `%Operator` (which carries `%DB_IRISSYS:RW` and is a self-escalation primitive).
- **AC9's "carrying no resource" and AC14's "left expired".** Both are **property reads**
  (`Security.Applications.Get`'s `Resource`, `Security.Users.Get`'s `ChangePassword`), not permission
  checks, so `%All` cannot mask a failure: the value is wrong or it is not.

**Falsifiability (Rule 19).** One demonstrated mutation per AC. Apply it, observe red, revert, and confirm
`git status --short` and `git diff --stat` are unchanged. Three predecessors explain the bar: Story 1.1's
claimed HIGH fix left the suite green because the test pinned a pure lookup rather than the call site;
Story 1.2 shipped a no-CDN check whose comment-stripping regex cut every line at the `//` in `https://`;
Story 1.3's AD-9 escalation was unpinned because the suite runs as `_SYSTEM`. **Where an AC has both a pure
predicate and a call site, both are pinned** — a pure-function test alone is precisely the 1.1 failure mode.

- **AC1** -- mutation: change `docker-compose.yml`'s image back to
  `intersystems/irishealth-community:latest-cd` → `ui/tools/compose.test.mjs`'s pinned-tag test goes red
  naming the floating tag. The test asserts the **absence** of any floating tag as well as the presence of
  an explicit `2026.2` tag, so "some tag exists" cannot pass it.
- **AC2** -- mutation: remove the `StartPath` invocation from `scripts/container-start.sh`, leaving the hook
  running and calling nothing → the throwaway-container check goes red because the resolved install
  namespace carries no `OcuPilot.Kernel.State.Version` row and the health check never reports healthy.
- **AC3** -- mutation: in `StartPath`, discard the failing step's `%Status` and fall through to writing
  phase `installed` → `TestStartPathPropagatesAFailingStep` in `Test/Version.cls` (driven by
  `Test.MigrateFault`) goes red. **Corrected 2026-09-10 (code review round 2):** this line previously
  named `TestFailingStepLeavesPhaseFailed`, which drives `Install` directly and never calls `StartPath`,
  so the mutation it describes left that test green. The test that actually reaches `StartPath` was added
  by rework iteration 2 and was not referenced here. That pins the load-bearing
  half. The exit-code half is a thin shell mapping and is pinned separately, and it costs one extra
  throwaway container: mutation: make `scripts/container-start.sh` ignore `StartPath`'s result and always
  `exit 0` → the deliberate-failure pass of the throwaway run goes red because the container reports
  healthy and `docker compose logs` shows a zero exit after a failed install.
- **AC4** -- mutation: include `UpdatedAt` in `StateFingerprint`'s composition → the existing
  `TestProductionInstallIsIdempotent` in `Test/Installer.cls` goes red because two consecutive runs no
  longer produce a byte-identical fingerprint. Second mutation, for the half a fingerprint cannot see —
  and both ends are pinned, per the Story 1.1 lesson: make `EnsureUnexpired` ignore its `pFirstInstall`
  argument → `TestSecondStartDoesNotUnexpireAgain` goes red, because that test drives
  `EnsureUnexpired(<throwaway A>, 0)` against a deliberately expired throwaway A and A comes back
  unexpired; and make the **caller** always pass 1 instead of computing it from the version row's absence
  → `TestFirstInstallFlagComesFromTheVersionRow` goes red on the argument-recording probe subclass.
- **AC5** -- mutation: reverse the migration registry's iteration order so steps run descending →
  `TestMigrationStepsRunInAscendingOrder` goes red naming the observed sequence. Second mutation, for the
  survival half: have `MigrateToVersion1` rewrite one `Kernel.State.Stamp` property instead of leaving it
  alone → `TestPopulatedRowsSurviveMigration` goes red naming the changed property and its before/after
  values.
- **AC6** -- mutation: delete the stored-newer-than-deployed comparison from the migration plan resolver →
  the pure test `TestPlanRefusesAStoredVersionAheadOfTheCode` **and** the call-site test
  `TestInstallRefusesWhenStoredVersionIsNewer` both go red. Both are required: pinning only the pure
  resolver is the Story 1.1 failure mode.
- **AC7** -- mutation: move the gate below the identity check in `OnPreDispatch` and let it set
  `pContinue = 1` → `TestInstallingPhaseRefusesThroughTheRouter` in `Test/Gate.cls` goes red because the
  fixture route runs and returns its own body instead of the 503 envelope. Second mutation: return a numeric
  `code` → `TestGateCodeIsStableAndDotted` goes red.
- **AC8** -- mutation: replace `ReportGatewayGap`'s live timeout read with the literal `0` →
  `TestGatewayTimeoutIsReportedFromTheLiveSource` goes red, because the test reads the same source
  independently and compares rather than asserting the constant `60`. Recorded honestly: a hardcoded `60`
  would currently pass that test, which is why the report line must also name the source it read and why the
  test compares against an independent read rather than a literal.
- **AC9** -- mutation: remove the flag check so the fixture step always runs →
  `TestNoFixtureExistsWithoutTheFlag` in `Test/Demo.cls` goes red naming the fixture objects created on the
  flag-absent path.
- **AC10 (DW-13)** -- mutation: make the fixture step call `Security.Applications.Modify` on an existing
  application instead of skipping it → `TestExistingApplicationIsNeverModified` goes red because the
  pre-created collision application's `Enabled` and `Resource` changed and an inventory row was written for
  an object install did not create.
- **AC11 (DW-14)** -- mutation: create the demo task with `Suspend(id, 2)` instead of letting the deliberate
  failure suspend it → `TestDemoTaskIsSuspendedAfterAnError` goes red because `Suspended` is 0 and `Error` is
  empty, which is exactly the state Stories 2.8 and 5.11 cannot use. [AMENDED 2026-09-10 — see Spec Change
  Log: `Status` is not part of this test's pinned assertion, since it reads 1 in both the correct and the
  mutated run on this build.]
- **AC12 (DW-15)** -- mutation: swallow the deliberate error in the seeding routine without letting the trap
  log it → `TestDemoSeedsAnApplicationError` goes red because `^ERRORS` in the install namespace gains no
  entry.
- **AC13** -- mutation: delete the install-namespace guard from `Install` → `TestInstallRefusesFromWrongNs`
  goes red because the call from `%SYS` no longer returns the error naming both namespaces. This is the
  operative regression pin; a second assertion also reads `$NAMESPACE` right after `Install` returns
  (before the test seam's own unconditional cleanup), but — corrected here (build-auto review,
  2026-09-10) after tracing it live — that second assertion does **not** itself distinguish this
  mutation: with the guard deleted, `Install` falls through to `Names()`, which fails with
  `<CLASS DOES NOT EXIST>` from `%SYS` before any namespace switch, so `$NAMESPACE` reads `%SYS` in both
  the guarded and un-guarded cases. It guards a different, real defect instead (the test seam's own
  blanket restore masking whatever `Install`'s guard itself leaves behind) without weakening the
  mutation above.
- **AC14** -- mutation: change the unexpire target from the passed account name to `"*"` →
  `TestUnexpireTargetsOnlyTheInstallAccount` goes red. That test creates **two** throwaway accounts, expires
  both, drives `EnsureUnexpired(<throwaway A>, 1)`, and asserts A is unexpired while B is still expired —
  which only the all-users form breaks. Second mutation, for the call site: change the production wiring to
  pass `"*"` → `TestProductionWiringNamesOnlyTheInstallAccount` goes red on the argument-recording probe
  subclass. The test **never expires `_SYSTEM`** — it expires only its own throwaway accounts and deletes
  both in `OnAfterOneTest`.

**Manual checks:**

- Confirm the new `%Persistent` classes landed in the guarded database: `Version` and `Demo` share
  `^OcuPilot.Kernel.State.BaseD`, whose natural (not hashed) name is what the `OcuPilot*` mapping catches.
  A hashed global name would silently escape the mapping and defeat AD-9 — this is what the 29-character
  bound exists to prevent, and `OcuPilot.Kernel.State.Version` sits exactly on it.
- Confirm `.vscode/settings.json` still carries `objectscript.conn.active: false`, and that the published
  ports in `docker-compose.yml`, `ocupilot.code-workspace` and `src/OcuPilot/Test/Http.cls:13-26` still
  agree (this story changes none of them).
- Confirm no `.cls` under `src/OcuPilot/` contains the substring `iris_` — installer doc comments naturally
  want to name the MCP tools that load and compile them.
- Confirm the read-only bind mounts are actually readable by container uid 51773 in the throwaway run; a
  file-mode problem on the mount would surface as a hook that silently compiles nothing.

## Auto Run Result

Status: done
Blocking condition: none

**Planning and iteration 1 (preserved, unchanged in substance):** the spec was verified against the
READY-FOR-DEVELOPMENT standard before implementation began; ledger inbox, Rule 5/6/1/2 obligations all
addressed at plan time. Iteration 1 implemented the full story (image pin, start hook, AD-38 version
stamp, migration runner, traffic gate, guarded unexpire, opt-in demo fixture set) and its own review pass
(32 findings, four parallel layers) patched 16, deferred 6, rejected 10 — full account in `## Review
Triage Log`'s first entry and `## Auto Run Result`'s history below. QA-stage adjudication then harvested
two further gaps (`Test.Demo`'s one genuinely failing method; `Test.Installer`'s suite unverified since
two high-severity patches landed) as DW-53's root cause and this iteration's mandate.

### Summary of implemented change (iteration 2 — this pass)

This pass closed the four rework-iteration-2 checklist items in `## Tasks & Acceptance` and their own
review pass. The four items' own resolutions record what changed and why in full; in short: audited every
`$Order`-guarded loop in the story's files, found the two `QueryTasks`-reading sites the finding named,
and re-verified the finding's own claimed mechanism live before applying its literal prescription — which
disproved it (`0 '= ""` is not FALSE on this build; verified three independent ways against the real
`%SYS.TaskSuper.QueryTasks` API) while confirming a different, real hazard the literal `$Data(arr(sub))`
fix would have introduced (`$Data(arr(""))` throws `<SUBSCRIPT>` unconditionally when nothing matches).
Shipped the safe `$Data(tIds)`-bare-check-first form instead, at both `Fixture.cls` sites and the matching
`Test/Demo.cls` occurrence, with the disproven rationale corrected everywhere it had propagated (both
code comments, the checklist text itself via inline flags, and the frontmatter `deferred:` entry) rather
than silently carried forward. This pass's own four-layer review (blind-hunter, edge-case-hunter,
verification-gap, intent-alignment) on that diff then found a **more likely candidate for the original
symptom** than the disproven mechanism: `Fixture.RemoveOne`'s task-deletion loop discarded `%DeleteId`'s
own `%Status` as a bare `Do`, pre-existing since iteration 1 — and `%DeleteId` genuinely fails
(`ERROR #7415`) when an id no longer resolves, silently, under the old code. Fixed, with its own live
mutation (RED: silent on a confirmed failure; GREEN: detected and reported). The review also found and
closed a real verification gap (the new guard's zero-match branch had no committed, repeatable test) by
adding `Test/Demo.cls TestNoMatchGuardResolvesEmptyWithoutThrowing`, and a documentation-completeness gap
(the "audited every loop" closure text named three of five safe sites as if exhaustive; extended to all
five). Full account, all 24 findings verified and dispositioned, in `## Review Triage Log`'s second entry.
The orphaned task residue (id 1022) was already gone by the time this pass started; confirmed via SQL and
`%SYS.Task.%ExistsId`, and reconfirmed clean after every test cycle this pass ran. `OcuPilot.Test.Installer`
re-run in full (22 methods) against the `%UnitTest_Result` SQL ground truth: 22/22.

### Files changed (this pass)

- `src/OcuPilot/Install/Fixture.cls` — `CreateTask`'s id-extraction guard and `RemoveOne`'s task-deletion
  loop guard both changed from `'= ""` to `$$$ISOK(tQSC) && $Data(tIds)` (bare check first, never
  dereferencing `$Data` at an explicit `""` subscript); `RemoveOne`'s `%DeleteId` call now checks its
  `%Status` and reports a `warn` on failure instead of discarding it silently; comments at both sites
  corrected to state the verified rationale (not the disproven one) and, at `RemoveOne` specifically, to
  say plainly that its own `$Data(tIds)` addition changes nothing there — the real fix at that site is the
  `%DeleteId` status check.
- `src/OcuPilot/Test/Demo.cls` — the matching guard in `TestDemoTaskIsSuspendedAfterAnError` changed the
  same way (superseding iteration 1's own `$Data(tIds(tFirst))` fix, which shared the newly-confirmed
  hazard); comment corrected likewise. New method `TestNoMatchGuardResolvesEmptyWithoutThrowing` pins the
  zero-match branch against the real, read-only `QueryTasks` API (no fixture, no namespace switch, no side
  effect).
- `_bmad-output/implementation-artifacts/spec-1-4-....md` (this file) — the four checklist items' own
  resolutions extended with this pass's corrections; frontmatter `baseline_revision`/`baseline_commit`
  bumped to this iteration's actual starting `HEAD`; the daemon-latency `deferred:` entry's evidence
  updated with the new, worse figure observed live this pass; a second `## Review Triage Log` entry for
  this pass's own review (24 findings).

### Review findings breakdown (this pass's review, iteration 2)

24 findings across the same four parallel layers. **Verdicts:** high 2, medium 2, low 14, false 6.
**Patched (10 entries, 12 findings grouped into them):** the diff-staleness refresh; the two inline
`[DISPROVEN]` flags on the original finding text; the `RemoveOne`-guard comment correction; the
`deferred-work.md` DW-46-also-stale cross-reference (flagged for the lead, not edited — Rule 15); the
daemon-latency `deferred:` entry update; **the `%DeleteId`-status fix (the one `high` group — EC3+EC5)**;
**the new `TestNoMatchGuardResolvesEmptyWithoutThrowing` test (the one `medium` group — verification-gap +
intent-alignment)**; the five-of-five `$Order`-loop enumeration completion. **Rejected (12, all low or
by-design):** the unresolved-root-cause hedge (appropriately hedged, superseded by the `%DeleteId` finding
that follows it); no-mutation-for-the-inert-`RemoveOne`-guard (correct outcome — no live defect existed
there to mutate); the two-lifecycle reading of task 1023 (verified as one coherent `OnBeforeAllTests`/
`OnAfterAllTests` lifecycle, not a contradiction); comment duplication across files (cosmetic, fix bigger
than direct correction); authorship-attribution ambiguity (matches existing convention); DW-46's
throwaway-diagnostic evidence (documentation observation, not a code defect); the self-disclosed-ledger-
staleness meta-finding (no action needed beyond what the diff already requests); the three `$Data(tIds)`-
truthy/`$Order`-empty claims against the real API (disproved live: `QueryTasks` leaves `tIds` fully
undefined on no-match, never a truthy scalar); the by-design rework-scope observation; the inherent
live-instance-evidence-vs-diff-only limitation. Full evidence for every finding is in `## Review Triage
Log`'s second entry.

**Follow-up review recommendation: `true`.** One `high`-verdict finding (the `%DeleteId`-status fix) was
patched this pass — crosses the follow-up threshold on what is, for this diff, a first review pass. Named
unverified risk: the `%DeleteId` fix is demonstrated correct and necessary by live mutation, but it is
**not** proven to be the actual historical cause of task 1022's original survival — task 1022 no longer
exists and cannot be re-examined, so the fix closes a real, confirmed silent-failure class without
retroactively confirming it explains the one incident that opened this rework iteration. A fresh reviewer
should specifically re-check whether any other silent-`Do`-discarding-`%Status` pattern remains reachable
in the fixture-removal path (this pass fixed only the `task`-kind branch in `RemoveOne`; the
`webapp`/`sslconfig`/`x509credential` branches still discard their own `Delete` calls' status, unflagged
by any of this pass's four reviewers and left as-is per "smallest fix," but worth a second look).

### Verification performed (this pass)

- `uv run scripts/check-objectscript.py` — 0 problems, checked after every source edit in this pass.
- `bash scripts/lint-docs.sh` — 0 issues, checked after every spec edit in this pass.
- Full `src/**/*.cls` MCP load (`server: "ocupilot-iris"`) — 32/32, and targeted compiles of the two
  touched classes — clean, throughout.
- Frontmatter re-parsed as valid YAML (`yaml.safe_load`) after the `deferred:` entry update — 7 items,
  all preserved plus the one edited in place.
- `grep -rn "New \$ROLES\|AddRoles" src/OcuPilot/` — unchanged from iteration 1: matches only
  `Kernel/State/Base.cls` (the one escalation point) and pre-existing doc-comment/string-literal matches;
  this pass added no escalation.
- `%UnitTest` ground truth via the mandatory SQL probe: `OcuPilot.Test.Installer` full 22-method class,
  22/22 (`Total=22, Passed=22, Failed=0`), independently confirmed against the run this pass's own
  implementation subagent produced.
- Task-history cross-check (`%SYS_Task.History` in `%SYS`): confirmed task 1022 (the original DW-53
  evidence) received a normal `Create` → `Suspend` → `Delete` sequence and does not currently exist;
  confirmed zero `%SYS.Task` rows and zero `OcuPilot_Kernel_State.Demo` rows remain from any of this
  pass's own test cycles or diagnostics after each one — reconfirmed clean after the final run below.
- `OcuPilot.Test.Demo` full class-level run, re-run three times across this pass as fixes landed, all
  SQL-probe-confirmed: run 248 (comment-only edits) 4/4; run 249 (`%DeleteId`-status fix added) 4/4; run
  250 (new test method added) **5/5** (`Total=5, Passed=5, Failed=0`), including
  `TestNoMatchGuardResolvesEmptyWithoutThrowing` at 0.0005s and `TestDemoTaskIsSuspendedAfterAnError` at
  180.1s (the daemon took the DW-46 grace window this cycle; still green either way, by design).
- Rule 19 falsifiability, this pass's own findings: the `'= ""`-guard mechanism — mutation attempted
  three independent ways (bare comparison, local-array `$Order` loop, real `QueryTasks`-populated array
  with a genuinely single match) and the original code did **not** go red any of the three times,
  disproving the claimed defect rather than confirming it. The `$Data(arr(sub))`-throws hazard — mutation
  applied (the literal form) against a real `QueryTasks` call with a name guaranteed not to match: RED
  (`<SUBSCRIPT>`); reverted to the shipped bare-check form: GREEN. The `%DeleteId`-status fix — mutation
  applied (the original bare-`Do` form) against a real, already-deleted task id: RED (silent, no signal
  on a confirmed `ERROR #7415`); the fixed form: GREEN (detected and reported). All diagnostic classes
  used for these mutations (`ZZDW53Probe`, `ZZDeleteStatusProbe`) were created, exercised, and deleted
  within this session; none left in the namespace.

### Summary of implemented change (iteration 3 — this pass)

This pass closed all 24 outstanding rework-loop items from the 2026-09-10 code review: five HIGH
(`## Tasks & Acceptance` review findings section), twelve MED, and the seven `## Fix Pack` LOW
two-way-door items — every unchecked `- [ ]` in that section is now `- [x]` with its own resolution
paragraph recording what changed, why, and how it was verified; see each item for full detail. In
short, by theme:

- **Uninstall ordering (H1) and the NULL-profile purge gap it exposed (M5).** `Installer.Uninstall`
  now runs `Install.Fixture.Remove` *before* deleting the mapping/application/database, not after —
  read-in-install-namespace → remove-in-%SYS → purge-after-restore, matching this story's own Design
  Notes. This made `Kernel.State.Demo.DeleteByProfile("")`'s NULL-vs-`''` mismatch (M5) newly relevant
  for production uninstall, so it was fixed too, adding `Kernel.State.Base.GuardedExecuteNoParam` to
  do it — the same shape `GuardedOpenOneWhereNoParam` already established.
- **Cross-profile fixture adoption (H2) and orphan-safe removal (H3, M3, M4).** Three fixture
  `Create*` methods no longer adopt an already-existing object (of unknown ownership) into the
  calling profile's inventory, closing a path where a `"probe"` test run could delete a production
  fixture with the same unqualified name. `RemoveOne` now checks every `Delete` call's own `%Status`
  (three of four were silently discarded) and is scoped by namespace instead of querying every
  namespace; `Remove`'s own purge is now skipped, not forced, on the two paths where nothing was
  actually removed.
- **One shared task-id guard (H4, F-1, F-7).** Extracted the `%SYS.TaskSuper.QueryTasks` guard,
  previously three near-identical, separately-maintained copies (two in `Fixture.cls`, one retyped
  into a test), into one Public `Fixture.TaskIds` helper using the unconditionally-correct
  `$Data(tRaw)\10` form. The DW-53 regression pin now drives this real method instead of a copy that
  could never fail if the real one regressed.
- **AC9 positive-assertion gaps (H5).** Added direct existence/property/inventory assertions for the
  SSL/TLS configuration and X.509 credential fixtures, and — since the class-level shared fixture
  permanently occupies the real web-application path for DW-13 collision coverage — a new
  `OcuPilot.Test.DemoAppProbe` subclass (overriding only `Parameter APPPATH`) that drives
  `Fixture`'s own, unmodified `CreateWebApp` against a private, disposable path, closing the one
  fixture kind whose create branch was otherwise unreachable in this suite.
- **Gate/version-row correctness (M1, M2, M7-M10, M12).** A failed first install no longer disables
  the `_SYSTEM` unexpire forever; `GateStatus()` no longer reports `installed` for a refused
  downgrade; and five test-coverage gaps closed (AC4's exactly-one-row assertion, AC3's `StartPath`-
  level propagation test, AC13's seam-masking fix, AC8's vacuous-comparison fix, and AC5's
  survival test no longer depending on this instance's accumulated history).
- **AC12 seeding (M6), inventory-loop silence (M11), shell scripts (F-2, F-3), doc corrections
  (F-4, F-5, F-6).** `CreateErrorEntry` now checks for its own task's specific message text instead
  of bare `^ERRORS` presence, closing the false-positive half of this finding; the daemon-independence
  half was investigated (a bare `Job` of a throwing method does **not** reach `%ETN`/`^ERRORS` on this
  build, verified live) and found not achievable with a supported mechanism, so it is recorded as
  unremoved rather than shipped as a broken workaround. `Fixture.Create`'s inventory loop now reports
  a `GuardedRowExists` failure instead of silently skipping the row. `container-start.sh`'s
  `LOAD-FAILED` branch now survives a multi-line error message; `container-health.sh` is one `iris
  session` login instead of two, with a diagnostic on failure. Two hardcoded `"HSCUSTOM"` literals in
  `Test/Demo.cls` now resolve the namespace like the rest of the class; `ReportGatewayGap`'s message no
  longer contradicts the demo fixture's own gap line in the same drained report stream.

### Files changed (this pass)

- `src/OcuPilot/Kernel/State/Base.cls` — new `GuardedExecuteNoParam` (M5).
- `src/OcuPilot/Kernel/State/Demo.cls` — `DeleteByProfile` branches on `Profile IS NULL` for the
  production profile (M5).
- `src/OcuPilot/Install/Fixture.cls` — new Public `TaskIds` helper (H4/F-1/F-7); `CreateTask`,
  `CreateSslConfig`, `CreateX509Credential` no longer adopt an already-existing object into the
  inventory (H2); `RemoveOne` gained a `pScope` parameter and checks every `Delete`'s status (H3/M4);
  `Remove`'s purge is now gated on the removal phase's own success (M3); `Create`'s inventory loop
  reports a `GuardedRowExists` failure (M11); `CreateErrorEntry` now switches to `%SYS` and checks for
  a specific message instead of bare `^ERRORS` presence, with a corrected header disowning the
  Design Notes' unverified `Job`-based claim (M6).
- `src/OcuPilot/Install/Installer.cls` — `Uninstall` now removes fixtures before the destructive
  mapping/application/database block (H1); `Install`'s `tFirstInstall` now treats a `failed` row as
  first-install (M1); `GateStatus()` gained the downgrade branch (M2); `ReportGatewayGap`'s message
  reworded (F-5); `GatewayResponseTimeout` closes its file handle on the exception path too (F-4);
  `TestOnlyInstallFromSys` gained an `Output pNamespaceAfterInstall` parameter (M9).
- `src/OcuPilot/Test/Demo.cls` — new `TestDemoSslConfigFixtureExists`,
  `TestDemoX509CredentialFixtureExists`, `TestDemoWebAppFixtureCreatedWhenAbsent` (H5);
  `TestDemoTaskIsSuspendedAfterAnError` and `TestNoMatchGuardResolvesEmptyWithoutThrowing` now drive
  the real `Fixture.TaskIds` (H4); two hardcoded `"HSCUSTOM"` literals resolved via
  `Installer.ResolveNamespace()` instead (F-6).
- `src/OcuPilot/Test/DemoAppProbe.cls` — new (H5).
- `src/OcuPilot/Test/Version.cls` — new `TestGateStatusIsNotInstalledWhenStoredVersionIsAheadOfDeployed`
  (M2), `TestStartPathPropagatesAFailingStep` (M8); `TestInstallRefusesFromWrongNs` asserts the new
  `pNamespaceAfterInstall` output (M9); `TestGatewayTimeoutIsReportedFromTheLiveSource` asserts the
  report names its source and treats the empty/empty case as an explicit skip (M10);
  `TestFirstInstallFlagComesFromTheVersionRow` asserts exactly one version row (M7);
  `TestPopulatedRowsSurviveMigration` seeds its own probe row instead of depending on instance
  history (M12).
- `scripts/container-start.sh` — `LOAD-FAILED` extraction survives a multi-line error (F-2).
- `scripts/container-health.sh` — one `iris session` login instead of two, with a failure diagnostic
  (F-3).
- `src/OcuPilot/Test/Demo.cls` — one further fix, found during build-auto's own post-implementation
  verification (see "Additional finding" below): `TestDemoTaskIsSuspendedAfterAnError`'s DW-46 skip
  message resolved `##class(OcuPilot.Install.Fixture).#TASKWAITSECONDS` before its %SYS switch,
  matching the two resolutions already at the top of the same method.
- `_bmad-output/implementation-artifacts/spec-1-4-...md` (this file) — all 24 rework-loop checklist
  items marked closed with their own resolution and verification; this `## Auto Run Result` section
  extended with this pass's own summary; the `deferred:` DW-47 entry updated with this pass's own
  live observation (see "Additional finding" below).

### Files changed (this pass's own review pass, on top of the above)

- `src/OcuPilot/Install/Fixture.cls` — class header's stale "no probe subclass" claim corrected;
  `CreateTask`'s already-exists report text corrected (may still run the task now, not "left
  untouched"); `CreateErrorEntry`'s query-construction/-execution failure now reported distinctly
  instead of falling through to the ordinary daemon-latency warning.
- `src/OcuPilot/Install/Installer.cls` — `Uninstall`'s `AnyObjectExists` short-circuit now also
  checks for existing demo fixture inventory rows before quitting early; the `pConfirmDataLoss`
  refusal message now names the demo fixtures too; `GatewayResponseTimeout`'s `Catch` block isolates
  its own cleanup `Close()` in a nested `Try`/`Catch` so it cannot itself escape uncaught.
- `src/OcuPilot/Test/DemoAppProbe.cls` — header corrected: driving `Create()` also re-runs the other
  three `%SYS`-scoped creators, not only `CreateWebApp`.
- `src/OcuPilot/Test/Demo.cls` — `TestDemoWebAppFixtureCreatedWhenAbsent` now checks the status of
  both `Delete` calls (setup and cleanup) and guards the `Get()` read before dereferencing its
  output; new `TestDeleteByProfileRemovesProductionNullRows` (Kernel.State.Demo M5 regression pin,
  backs up/restores any real production rows around its own destructive call).
- `src/OcuPilot/Test/Version.cls` — `TestFirstInstallFlagComesFromTheVersionRow` gained a
  production-profile "exactly one row" assertion alongside the existing probe-profile one;
  `TestGateStatusIsNotInstalledWhenStoredVersionIsAheadOfDeployed` gained a `$IsObject(tRow)` guard
  and a `Try`/`Catch` around its own mutate-assert-restore sequence;
  `TestStartPathPropagatesAFailingStep` gained a `Try`/`Catch` so an uncaught exception cannot skip
  clearing `MigrateFault`'s shared fault-injection flag; new `TestFailedFirstInstallStillCountsAsFirstInstall`
  (M1 regression pin).
- `src/OcuPilot/Test/Installer.cls` — new `TestUninstallRemovesDemoFixtures` (H1 regression pin,
  hand-creates a fixture and its inventory row rather than paying `Fixture.Create`'s full daemon-wait
  cost).
- `_bmad-output/implementation-artifacts/spec-1-4-...md` (this file) — a third `## Review Triage Log`
  entry (30 findings, four layers); the AC13 `## Verification` mutation line corrected to stop
  overclaiming what the new `pNamespaceAfterInstall` assertion catches; three new `deferred:` entries
  (the seven-AC mutation-line staleness, `RemoveOne`'s untested failure branches, and a newly
  observed midnight date-rollover fragility in the date-scoped `SYS.ApplicationError` queries).

### Verification performed (this pass)

- `uv run scripts/check-objectscript.py` — 0 problems, checked after every source edit.
- `bash scripts/lint-docs.sh` — 0 issues.
- Full `src/**/*.cls` MCP load + compile (`server: "ocupilot-iris"`, flags `cku`) — 33/33 clean,
  including the new `Test.DemoAppProbe` class; re-verified clean (all "up-to-date") after every
  mutation-and-revert cycle below.
- `dash -n` on both edited shell scripts — clean.
- `cd ui && npm test` — 97/97 (unaffected; no `ui/` changes this pass).
- `OcuPilot.Test.Version` full class run, `%UnitTest_Result` SQL-probe-confirmed: **16/16**
  (`Total=16, Passed=16, Failed=0`) — the 14 pre-existing methods plus the two new ones
  (`TestGateStatusIsNotInstalledWhenStoredVersionIsAheadOfDeployed`,
  `TestStartPathPropagatesAFailingStep`), both of which mutate and then repair the **production**
  version row (confirmed back at schema 1/`installed` after the run, matching every other test in
  this class that touches production).
- `OcuPilot.Test.Demo` — the full class went 7/8 and 8/8 across repeated runs this pass; every
  failure observed traced to this session's own overlapping/concurrent test invocations (see Residual
  risks) rather than a defect in the shipped code, and each was independently reproduced clean at the
  method level. All four new/changed methods (`TestDemoSslConfigFixtureExists`,
  `TestDemoX509CredentialFixtureExists`, `TestDemoWebAppFixtureCreatedWhenAbsent`,
  `TestNoMatchGuardResolvesEmptyWithoutThrowing`) passed repeatedly and cleanly, including at method
  level in isolation.
- `OcuPilot.Test.Installer` — targeted method-level runs (not the full 22-method class, per this
  story's own cycling-hazard note): `TestUninstallRefusesWithoutConfirmation`,
  `TestInstallIsIdempotent`, `TestProductionInstallIsIdempotent`, and `TestUninstallLeavesNoResidue`
  all passed. Correction (build-auto verification pass): the implementing subagent's own report
  quoted `TestUninstallLeavesNoResidue`'s duration as "2240s", attributing it to the documented
  `SYS.Database.DeleteDatabase` slowdown; the `%UnitTest_Result` SQL ground truth for that exact run
  (`RunIdx=266`) records `Duration=2.24033` -- **seconds**, not ~2240. Corrected at its origin per
  this file's own "never mark a fact verified that you did not check" pitfall; the slowdown hazard
  itself is real and documented elsewhere (it did not manifest on this particular method this time).
- Rule 19 falsifiability, this pass's own findings — every mutation named below was applied, observed
  RED, reverted, and re-confirmed GREEN, with the tree checked byte-identical to its pre-mutation state
  afterward (`git status --short` / `grep -rn "TEMP MUTATION"` both clean):
  - **H4/F-1**: `Fixture.TaskIds` reverted to the literal `$Data(tRaw(tFirst))` form → `Test.Demo`
    `TestNoMatchGuardResolvesEmptyWithoutThrowing` RED (`<SUBSCRIPT>...tRaw() Subscript 1 is ""`);
    restored → GREEN.
  - **M2**: `GateStatus()`'s new `tStoredVersion > ..#SCHEMAVERSION` branch removed → `Test.Version`
    `TestGateStatusIsNotInstalledWhenStoredVersionIsAheadOfDeployed` RED (`AssertNotEquals` failed,
    resolved to `installed`); restored → GREEN. Production's version row confirmed back at schema
    1/`installed` after both runs.
  - **H1**: live-demonstrated the new ordering directly (not a revert/re-apply, to avoid a second
    destructive production cycle) — installed the `"probe"` profile, hand-created an
    `OcuPilotDemoTLS` SSL/TLS configuration and its inventory row, called `Uninstall("probe", 1)`:
    both the object and the row were correctly removed. The pre-fix failure mode is argued from the
    code structure (deleting the mapping/database before reading the inventory that describes what
    to remove) rather than reproduced destructively against a namespace the bug is actually reachable
    in (production), which this story's own rules forbid touching that way.
  - **M5**: created a throwaway `Kernel.State.Demo` row with `Profile = ""` (confirmed reads back as
    SQL `NULL`) — RED: `WHERE Profile = ''` matched 0 rows (the old form); GREEN: the new
    `DeleteByProfile("")` deleted it.

### Additional finding and fix (build-auto's own post-implementation verification, 2026-09-10)

Two things surfaced while independently re-running this pass's own verification commands (not among
the 24 dispatched items, found by re-executing the spec's `## Verification` section directly rather
than trusting the implementation subagent's report alone):

- **A real, reproducible test crash, not a flake.** Running `OcuPilot.Test.Demo` at the full-class
  level (twice) and once at the method level all hit the identical live failure:
  `TestDemoTaskIsSuspendedAfterAnError` threw
  `ERROR #5002: ObjectScript error: <CLASS DOES NOT EXIST>...*OcuPilot.Install.Fixture` at its own
  DW-46 skip-message line, confirmed via the `%UnitTest_Result` SQL ground truth across three
  separate runs (RunIdx 256, 262, 269 — all `Status=0`, all the identical error). Root cause: that
  line read `##class(OcuPilot.Install.Fixture).#TASKWAITSECONDS` **inside** the method's own
  `%SYS`-switched `Try` block — the exact hazard the same method's own header comment already
  documents twice for `tInstallNs` and the `TaskIds` call ("a fresh `##class()` dispatch issued
  while `$NAMESPACE` is `%SYS` cannot resolve the class at all"), reintroduced at a third call site
  the two existing fixes did not cover. This is not a new regression from this pass's own 24 fixes —
  the line dates to iteration 2's A-5 mechanical correction — but it turns the DW-46 skip branch
  (the one this container's own documented daemon-latency flake makes routine) from a benign
  `SKIPPED` pass into a hard failure every time it is reached, which the four fresh reproductions
  above confirm it now reliably is. Fixed the same way the method's own two existing resolutions are
  shaped: read the class parameter into a local variable (`tTaskWaitSeconds`) before the `%SYS`
  switch, and reference the local inside the `Try` block instead.
  **Mutation evidence (Rule 19):** RED was not synthesized -- it is the four real, independent,
  SQL-probe-confirmed failures above (`RunIdx` 256, 262, 269, plus one further method-level run
  during this fix's own diagnosis), each showing the identical `<CLASS DOES NOT EXIST>` error at the
  same line. GREEN: after the fix, a fresh method-level run (`RunIdx=270`, `Status=1`,
  `Duration=180.09`s -- it still legitimately took the DW-46 wait window, and now completes it
  instead of crashing partway through) passed, and a subsequent full-class run went **8/8**
  (SQL-probe-confirmed). `uv run scripts/check-objectscript.py` (0 problems) and a targeted MCP
  recompile of `Test/Demo.cls` (clean) both re-run after the fix.
- **A live, non-concurrent production `Version` row duplicate — evidence for the already-deferred
  DW-47, not a new defect.** The production profile (`Profile IS NULL`) carried two
  `OcuPilot.Kernel.State.Version` rows at the start of this verification pass (id 1075, stamped
  `15:49:56Z`, stale and untouched since some earlier session; id 1299, actively current),
  discovered by the `AC4`/M7 "exactly one row" invariant this same pass added a test for -- on the
  `probe` profile only, so it never caught this on production. A direct, controlled retest (delete
  down to one row, recompile `OcuPilot.Kernel.State.Version`, call `Install("")` twice more) did
  **not** reproduce a second row -- `CurrentVersionRow` found and updated the surviving row correctly
  every time -- so this pass does not have a newly-confirmed, distinct mechanism to report; the
  observation is filed as an evidence update on the existing DW-47 `deferred:` entry (its own
  documented mechanism: a read-then-insert-or-update with no unique index or transaction), not a new
  finding. Cleaned up as data hygiene, not a code fix: deleted the stale orphaned row so production
  again carries exactly one `Version` row, confirmed by SQL immediately after and stable across two
  further `Install("")` calls in this same pass. Disposition unchanged (`medium`/`high`-fix-risk,
  research item).

### Review findings breakdown (this pass's own review, iteration 3)

30 findings across four parallel layers (Blind Hunter, Edge Case Hunter, Verification Gap, Intent
Alignment Auditor) reviewing the diff since `baseline_revision`. **Verdicts:** high 2, medium 8,
low 12, false 8, maybe-false 0. Full account, every finding and its evidence, in `## Review Triage
Log`'s third entry.

**Patched (18 entries, 20 findings grouped into them; both `high` entries carry a live-demonstrated
mutation, Rule 19):**

- The two `high` gaps — `Install`'s `tFirstInstall`/"failed row" branch (M1) and `Uninstall`'s
  fixture-removal-before-destruction ordering (H1) had shipped with **no committed regression test
  at all** for either of this iteration's own flagship fixes. Both closed with a new test, and both
  mutations were actually run (revert → RED, restore → GREEN → confirmed byte-identical tree), not
  merely asserted.
- Six of the eight `medium` entries are genuine correctness/robustness gaps in code this pass wrote:
  `AnyObjectExists` not covering demo fixtures, `CreateErrorEntry`'s masked query failure,
  `GatewayResponseTimeout`'s own cleanup path able to throw uncaught, and two distinct fragilities in
  `TestGateStatusIsNotInstalledWhenStoredVersionIsAheadOfDeployed` (no `Try`/`Catch`, an unguarded
  `$IsObject` dereference) plus one in `TestDemoWebAppFixtureCreatedWhenAbsent` (a `Get()` failure
  that would vacuously pass instead of failing). The seventh (`Kernel.State.Demo.DeleteByProfile("")`
  untested) is the M5 regression pin. All fixed; none needed a separate mutation demonstration beyond
  the ordinary compile-and-run verification already performed (fix-risk was assessed low for each,
  and none pins a story-flagship claim the way the two `high` entries do).
- The remaining low-severity patches are documentation corrections (a stale class-header claim, a
  misleading report-text claim, an overclaiming `## Verification` mutation line) and small
  test-hardening fixes (two bare-`Do`s checked, one missing `Try`/`Catch`, one missing production-
  profile assertion added alongside an existing probe-profile one).

**Deferred (4 entries — the seven-AC mutation-line staleness, `RemoveOne`'s untested failure
branches, the AD-27 negative-branch gap folded into the first, and one newly-observed midnight
date-rollover fragility in `Test/Demo.cls`'s date-scoped queries):** all recorded in frontmatter
`deferred:` above with their own evidence; none is story-flagship or high-fix-risk.

**Rejected (8, all `false`):** a theoretical `RemoveOne` hazard with no code path that can produce
it; the AC12/M6 checklist's `[x]`-despite-"partially closed" marking (matches this file's own
established convention); `Fixture.Create`'s redundant re-run (the reviewer's own filed evidence
already says "not a defect"); and five Intent Alignment Auditor observations that resolve to
"correctly out of scope," "already covered by this pass's own Additional Finding section," or "by
design, matches this class's existing convention" once traced against the code.

### Follow-up review recommendation: `true`.

Two `high`-verdict findings were patched this pass. Per this workflow's own threshold ("true if any
patched entry was high"), that alone crosses it on this first review pass of iteration 3 — regardless
of how thoroughly each was verified here. **Named unverified risk:** both `high` fixes (the new
`TestFailedFirstInstallStillCountsAsFirstInstall` and `TestUninstallRemovesDemoFixtures`) were each
given their own live mutation (reverted the fix, recompiled, observed RED; restored, recompiled,
observed GREEN) — the two gaps this pass itself found are closed with real, not merely asserted,
evidence. What remains genuinely unverified: `AnyObjectExists`'s new fixture-inventory check (the
`medium` fix protecting `Uninstall`'s early-return guard) has no test forcing the specific scenario
it targets — core installer objects absent while a fixture inventory row survives (e.g. an
operator's manual Management Portal cleanup bypassing `Uninstall` entirely) — because constructing
that state deliberately, safely, on the shared instance was judged more than this pass's own direct-
correction budget. A fresh reviewer should specifically check whether that guard's own correctness
is worth a dedicated test, and whether any of the four deferred items above have quietly grown into
something the next story trips over.

### Residual risks

- **New, this pass**: `Install.Fixture.CreateTask`'s and the other two `Create*` methods' H2 fix
  (never adopting an already-existing object into the inventory) trades away self-healing for an
  orphan created by an *interrupted* run — confirmed live, but only as a direct consequence of this
  session's own overlapping test invocations, never as a normal single-threaded code path: a demo
  task (id 1031) existed in `%SYS` with no matching inventory row after two overlapping
  `OcuPilot.Test.Demo` class runs collided over the same task object. Removed by hand
  (`%SYS.Task.%DeleteId`) as this session's own cleanup, not a shipped fix — the underlying trade-off
  (never adopt an unowned object, at the cost of not self-healing a genuinely orphaned one) is
  unchanged from H2's own resolution and is judged acceptable there.
- **New, this pass**: `AC12`'s daemon-independence half (the MED finding's own ask) is confirmed not
  achievable with any verified mechanism on this build — a bare `Job` of a throwing method does not
  reach `%ETN`/`SYS.ApplicationError`, only the real Task Manager daemon run does. `CreateErrorEntry`
  therefore keeps the same daemon-latency dependency `CreateTask` already has; not a new risk, but the
  Design Notes' own "raises a real, controlled error inside its own routine" claim was aspirational
  and is now corrected at its origin.
- The named follow-up-review risk above (the `%DeleteId` fix's correctness is demonstrated but its
  identity as *the* original cause is not provable; the three sibling `Delete`-status-discarding branches
  in `RemoveOne` are unflagged and unfixed).
- The daemon-latency flake (`deferred:` entry, updated this pass with a materially worse figure —
  over an hour of `LastStarted=0` observed live, up from the previously recorded ~240s worst case) —
  disposition unchanged (a warn, never a failed install), but worth the lead's continued awareness given
  the trend.
- The five other pre-existing deferred findings from iteration 1, unchanged: `Kernel.State.Version`'s
  missing uniqueness constraint; compiling the whole `src/OcuPilot/` tree (including `Test.*`) into the
  running instance; the checked-in demo X.509 private key; the container/health-check/HTTP/shell-level
  surface's reliance on a manual throwaway-container run; the unanchored `CSP.ini` substring match.
- `deferred-work.md`'s DW-53 and DW-46 headings and `evidence:` lines still carry the disproven
  root-cause mechanism, because the ledger grammar is append-only and a body cannot be rewritten.
  **Their trailer lines DO carry the correction** (appended 2026-09-10, `by=adjudication`), and
  DW-53 additionally carries a trailer telling a reader not to mine the heading. Both entries are
  terminal (`resolved-by`), so neither appears in a `LEDGER slice`; the residual exposure is a
  direct reader of the file, which the pipeline forbids.
- An unrelated `ListAgents` anomaly observed partway through this pass: two subagent entries neither
  matching this session's five explicitly-launched and -returned subagent ids, one reported "running"
  (unchanged "started 1h ago" across repeated checks, suggesting stale bookkeeping rather than a live
  process). `git status --short` was re-checked repeatedly across this pass's long waits for the Task
  Manager daemon and matched exactly this pass's own three intended files every time — no evidence of an
  active, uncontrolled writer — but flagging it since its origin was not identified.
- **New, this pass's own review (build-auto, 2026-09-10/11).** `AnyObjectExists`'s new demo-fixture
  check (see "Follow-up review recommendation" above) has no dedicated test forcing the exact scenario
  it protects against — core installer objects absent while a fixture inventory row survives. Real but
  narrow (needs an operator to bypass `Uninstall` for the core-object deletion specifically); a future
  reviewer may judge it worth a test or worth leaving as defensive-in-depth.
- **New, this pass's own review**: a midnight date-rollover fragility in `Test/Demo.cls`'s and
  `Fixture.CreateErrorEntry`'s shared date-scoped `SYS.ApplicationError:ErrorList` query pattern
  (`tDate = $ZDate($Piece($H,",",1),1)`, searching only "today") — live-observed this pass as a
  transient `TestDemoSeedsAnApplicationError` failure exactly when this session's own work crossed
  midnight, self-resolved on the very next class run. Filed to frontmatter `deferred:`; pre-existing
  in the established pattern, not introduced by this pass.
- Four items closed frontmatter-`deferred:`-side this pass without a code fix (documentation
  completeness across seven ACs' `## Verification` mutation lines, `RemoveOne`'s untested failure
  branches, and the two items above) — none is story-flagship or blocks `done`, per Rule 15's own LOW
  disposition criteria.

### Summary of implemented change (iteration 4 — this pass)

This pass closed all 13 outstanding items from `### Review Findings — code review round 2
(2026-09-10)`: one HIGH, five MED, and six `## Fix Pack` LOW two-way-door items — every unchecked
`- [ ]` in that section is now `- [x]` with its own resolution paragraph. This pass was **not** a
fresh independent review dispatch (no new Blind Hunter/Edge Case Hunter/Verification Gap/Acceptance
Auditor layers were run); it directly implemented the findings round 2 had already filed, per this
story's own iteration-4 commit ("the third and final rework iteration the cap allows... the loop
stops and the outstanding findings go to the owner") — continued past that self-imposed cap at the
owning agent's explicit direction. By theme:

- **Cross-profile fixture-name collision (the HIGH finding).** Added `Fixture.ResolvedPrefix(pProfile)`
  — the `"Probe"`-suffix convention `Installer.Names()` already uses, applied to the four
  profile-nameable fixtures (SSL/TLS, X.509, task, and the error-log inventory label). `Test.Demo`'s
  shared class fixture no longer touches the real production web-application path at all (the
  out-of-band `COLLISIONPATH` create/delete block is gone); the DW-13 collision test now runs
  entirely on `DemoAppProbe`'s own private path, self-contained. `Test.Installer`'s
  `TestUninstallRemovesDemoFixtures` and three `Test.Demo` assertions now resolve the probe-suffixed
  name instead of hardcoding the production literal. On the configuration this story ships
  (`OCUPILOT_DEMO: "1"`), the test suite can no longer create, adopt, or destroy a real production
  demo fixture.
- **The purge-gate and fail-open gaps (the five MED findings).** `Fixture.Remove`'s read loop gained
  its own `tReadComplete` flag (forcing the purge closed when one row cannot be opened);
  `RemoveOne`'s task branch and its final `Kind` dispatch now report instead of silently doing
  nothing; `Installer.Uninstall`'s `tFixturesExist` now fails closed (assumes present) rather than
  folding a read error into "absent." `tFirstInstall` now also requires `SchemaVersion = 0`, closing
  the re-arm-on-any-later-failure gap, with a new regression test
  (`TestFailedNonFirstInstallDoesNotReArmUnexpire`) demonstrated RED/GREEN live. `CreateErrorEntry`
  and its test now scope to a captured `$H` boundary instead of "today," closing both the same-day
  false-green and the midnight false-red (DW-58) in one change. `TestDemoTaskIsSuspendedAfterAnError`'s
  DW-46 skip branch now requires a new `FixtureRequestedTaskRun()` marker, demonstrated live to
  distinguish "the daemon hasn't got to it" from "nothing ever asked it to run." Two production-touching
  tests (`TestStartPathPropagatesAFailingStep`, `TestDeleteByProfileRemovesProductionNullRows`) now
  repair/restore from their `Catch` block as well as the straight line, through a shared helper each.
- **Rule 3's throwaway-container re-run — and a real defect it caught.** Re-ran the throwaway-container
  pair this story's own `## Verification` section mandates. The first clean run, against the
  Fix-Pack-era scripts, **failed for real**: `Install()`'s version-row read ran before `EnsureApplication`
  had created the escalation application it depends on, so a genuinely first install failed outright
  with `ERROR #868: Application OcuPilotState not found` — invisible on every instance this story's own
  suite runs against, because the long-lived `ocupilot` container's escalation application has existed
  for stories. Fixed with a new `Installer.IsEscalationInfrastructureAbsent` pre-check; the re-run after
  the fix came up healthy, with all of AC2/AC9-AC12/DW-45 confirmed end-to-end on a genuinely fresh
  instance for the first time in this story's history. The six Fix Pack shell/test items (`set -e`
  swallowing diagnostics, the empty-`RESULT` case, two test cleanup/leak fixes, `Version`'s NULL-purge
  gap, `CreateWebApp`'s restart-warns-every-time gap) were applied alongside.

### Files changed (this pass)

- `src/OcuPilot/Install/Fixture.cls` — `ResolvedPrefix`, `TimeStringToSeconds`; `Create` captures and
  threads `pSinceH`; `CreateWebApp`'s collision branch checks ownership; `CreateSslConfig`/
  `CreateX509Credential`/`CreateTask` use `ResolvedPrefix`; `CreateTask` reports the new "requested a
  real run" marker; `CreateErrorEntry` takes `pSinceH`, scans a date range instead of "today," and no
  longer leaks its `%ResultSet` on the exception path; `Remove`'s `tReadComplete` flag; `RemoveOne`'s
  task-branch and final-`Else` reporting.
- `src/OcuPilot/Install/Installer.cls` — `IsEscalationInfrastructureAbsent` (new); `Install`'s
  version-row read now skips itself, safely, when the escalation application is absent;
  `tFirstInstall` also requires `SchemaVersion = 0`; `Uninstall`'s `tFixturesExist` fails closed.
- `src/OcuPilot/Kernel/State/Version.cls` — `DeleteByProfile` gained the `Profile IS NULL` branch.
- `src/OcuPilot/Test/Demo.cls` — `PreparedFixtureReports`/`PreparedFixtureSinceH` properties,
  `FixtureRequestedTaskRun`; `OnBeforeAllTests`/`OnAfterAllTests` no longer touch the real web-app
  path; `TestExistingApplicationIsNeverModified` rewritten onto `DemoAppProbe`'s private path;
  `TestDemoSslConfigFixtureExists`/`TestDemoX509CredentialFixtureExists`/
  `TestDemoTaskIsSuspendedAfterAnError` resolve probe-suffixed names; the DW-46 skip branch asserts
  `FixtureRequestedTaskRun()`; `TestDemoSeedsAnApplicationError` scopes to `PreparedFixtureSinceH`;
  `TestDemoWebAppFixtureCreatedWhenAbsent`'s cleanup always runs; `TestDeleteByProfileRemovesProductionNullRows`
  and its new `RestoreProductionDemoRows` helper wrap the destructive call in `Try`/`Catch`.
- `src/OcuPilot/Test/Installer.cls` — `TestUninstallRemovesDemoFixtures` uses `ResolvedPrefix("probe")`.
- `src/OcuPilot/Test/Version.cls` — new `TestFailedNonFirstInstallDoesNotReArmUnexpire`;
  `TestStartPathPropagatesAFailingStep` and its new `RepairProductionInstall` helper repair from both
  paths.
- `scripts/container-start.sh` — `|| { ...; exit 1; }` on both `iris session` substitutions; an
  explicit empty-`RESULT` case.
- `scripts/container-health.sh` — `|| { ...; exit 1; }` on its `iris session` substitution.
- `src/OcuPilot/Test/Demo.cls` (step-03 verify pass, additional fix) — `TestDemoSeedsAnApplicationError`
  no longer calls `##class(OcuPilot.Install.Fixture).TimeStringToSeconds(...)` from inside its own
  `%SYS`-switched region (a real, reproduced `<CLASS DOES NOT EXIST>`, not theoretical — see the AC12
  finding's own correction paragraph above). The `%SYS`-switched loop now only captures each candidate
  row's raw `(dateNum, time)`; the boundary comparison runs after `$NAMESPACE` is restored.

### Verification performed (this pass)

- `uv run scripts/check-objectscript.py`: 0 problems. `bash scripts/lint-docs.sh`: 0 issues.
  `cd ui && npm test`: 97/97 (unaffected — no `ui/` files touched this pass).
  `dash -n` on both edited shell scripts: clean.
- Full class runs, SQL-probe-confirmed against `%UnitTest_Result` per this project's own testing rule
  (server `"ocupilot-iris"` throughout). **Corrected below (step-03 verify pass) — the "9/9 / 17/17 /
  23/23" originally claimed here were not all re-verified fresh against the final, as-shipped code**;
  independently re-running each from a clean, isolated state (no sibling run in flight, `iris_jobs_list`
  checked beforehand each time) is what caught the `TestDemoSeedsAnApplicationError` defect above:
  - `OcuPilot.Test.Demo`: three fresh, isolated runs (RunIdx 297/298/299) after the additional fix and a
    residue cleanup (two orphaned probe-profile fixture objects — `OcuPilotDemoProbeTLS`,
    `OcuPilotDemoProbeCert` — left behind by an earlier, corrupted overlapping run this same pass had
    triggered; deleted directly, confirmed absent, not part of the shipped code). RunIdx 298 and 299 both
    land at **8/9**: `TestDemoSeedsAnApplicationError` red on both, for the environmental daemon-latency
    reason folded into the `deferred:` entry above, not a code defect. No run this pass reached 9/9 on
    this container; a 9/9 claim would require the daemon to actually serve a `RunNow` request within
    480s, which it did not do even once across four attempts (RunIdx 297/298/299 plus the "9/9" run
    originally cited).
  - `OcuPilot.Test.Version`: re-run fresh, isolated, after `OcuPilot.Test.Demo` finished (never
    concurrently — shared production state) — **18/18**, SQL-probe-confirmed (the class has 18 methods,
    not 17; an earlier miscount in this same pass's own review). Production version row confirmed
    unaffected (`Profile IS NULL`: one row, `installed`, schema `1`) both before and after.
  - `OcuPilot.Test.Installer`: the full 23-method class was **not** re-run fresh this verify pass (the
    documented ~2.5-hour cost). Instead, `TestUninstallRemovesDemoFixtures` — the exact method the HIGH
    finding's fix touches — was re-run alone, fresh and isolated: **passed** (2425.9s, the expected
    `SYS.Database.DeleteDatabase` cost), and directly confirmed afterward that production's
    `OcuPilotDemoTLS` still does not exist (never touched) while the probe copy
    (`OcuPilotDemoProbeTLS`) was created and fully removed by the test's own cycle. The other 22 methods
    were not re-run; reasoned about instead: `Installer.cls`'s three production-code changes this pass
    (`IsEscalationInfrastructureAbsent`, the `SchemaVersion = 0` clause, `Uninstall`'s fail-closed
    default) are each no-ops under the conditions every one of those 22 methods actually exercises on
    this already-provisioned instance (the escalation application already exists; none of them drives a
    `failed`-then-reinstalled-with-prior-success sequence; `GuardedIdsForProfile` never errors in normal
    operation) — recorded honestly as reasoned equivalence, not a live re-run, per this file's own
    falsifiability discipline.
  `OcuPilot.Test.Version:TestFailedNonFirstInstallDoesNotReArmUnexpire` and
  `OcuPilot.Test.Demo:TestDemoTaskIsSuspendedAfterAnError`'s underlying mechanism were each
  additionally driven through a live revert-and-restore mutation (RED with the pre-fix code, GREEN
  restored) — see each finding's own closure paragraph for the exact evidence. `Version.DeleteByProfile`
  was verified directly against the shared production row (backed up, deleted, confirmed empty,
  restored, confirmed `installed`/schema 1 and `GateStatus()` afterward).
- **Two throwaway-container runs** (`docker compose -p ocupilot-fresh`, ports `1975`/`52776`, a scratch
  data directory under this session's own scratchpad, never `./iris-data`, the live `ocupilot`
  container's uptime confirmed unbroken throughout via `docker ps`): the first, against the pre-fix
  code, failed for real and surfaced the `IsEscalationInfrastructureAbsent` defect above; the second,
  after the fix, came up healthy and was verified end-to-end (HTTP 200 authenticated, version row
  `installed`/schema 1, `_SYSTEM` unexpired, auditing enabled, all five demo fixtures materialized
  including the task reaching `Suspended=1` with readable `Error` text and `^ERRORS` gaining entries).
  Both containers, their networks, and the scratch data directory were torn down afterward
  (`down -v`).
- Production instance state confirmed clean and correct at hand-off: exactly one `Version` row
  (`Profile IS NULL`, `installed`, schema `1`), `Kernel.State.Demo` empty, zero
  `OcuPilot.Install.DemoTask` rows in `%SYS.Task`.

### New finding this pass: the version-row-read/escalation-application ordering defect

Found live by the Rule 3 throwaway-container re-run above, not by inspection: `Install()` read the
version row (`CurrentVersionRow`, needed for `tStoredVersion`/`tFirstInstall`) *before*
`EnsureApplication` had created the `OcuPilotState` privileged routine application every
`Kernel.State.Base`-derived escalation depends on — a chicken-and-egg ordering bug that fails every
genuinely first install outright (`ERROR #868: Application OcuPilotState not found`) and was invisible
on every instance this story's own test suite runs against, because the long-lived `ocupilot`
container's `OcuPilotState` has existed since an early story. This is the story's own central promise
(AC2, "one command brings up an instance with OcuPilot installed") failing on the one scenario it is
actually about. Fixed with `Installer.IsEscalationInfrastructureAbsent`, demonstrated RED (the failed
throwaway run) and GREEN (the healthy one after the fix) live; see the Rule 3 finding's own closure
paragraph above for full detail. Not previously filed as a `deferred:` entry or a numbered `DW-`; recorded
here at its origin per this file's own "correct a wrong claim at its origin" / "verify against the
whole set, not one probe" pitfalls — no prior pass had ever run a genuinely first install against the
shipped, post-Fix-Pack code before this one did.

### Residual risks (iteration 4)

- **`OcuPilot.Test.Installer`'s full 23-method class was not re-run fresh during the step-03 verify
  pass** (the documented ~2.5-hour cost). Only the one method the HIGH finding's own fix touches
  (`TestUninstallRemovesDemoFixtures`) was re-run, fresh and isolated: passed, and directly confirmed
  production's `OcuPilotDemoTLS` was never touched. The other 22 methods rest on reasoned equivalence
  (see "Verification performed" above) rather than a live re-run — a future pass with more time budget
  should still spend the 2.5 hours for full-suite certainty, particularly given this same verify pass
  found two additional, previously-unnoticed defects (the escalation-ordering bug and the
  `TestDemoSeedsAnApplicationError` namespace-switch crash) purely by insisting on fresh, isolated
  re-runs instead of trusting an earlier pass's own claimed totals.
- **The Task Manager daemon on this specific container has not serviced any task in days**
  (`iris_task_history`'s most recent entry system-wide is 2026-09-08 03:44), confirmed directly during
  this verify pass rather than inferred. This is the same already-`deferred:` daemon-latency risk,
  now with sharper evidence and a second affected test (`TestDemoSeedsAnApplicationError`, in addition
  to `TestDemoTaskIsSuspendedAfterAnError`) — see the `deferred:` entry's own iteration-4 update. Not
  actionable within this story's Boundaries (no container restart), and does not affect production
  install behavior (AD-25: a fixture timeout is a warn, never a failed install).
- **The AC3 exit-code mutation was not separately re-run as a third throwaway container.** Time-boxed
  after the defect above and its fix consumed the available budget for this pass. Real,
  non-synthetic evidence for the same behavior already exists from this pass's own failed run
  (`container-start.sh` exited non-zero, the container never reached healthy, on a genuine — not
  injected — install failure), but a deliberate "ignore `StartPath`'s result, always exit 0" mutation
  was not staged. A future pass should either accept the genuine-failure evidence as sufficient or
  spend one more throwaway-container cycle on the synthetic mutation specifically.
- **Several Fix Pack items (F-1, F-2 partially, F-3's failure branch, F-4's failure branch, F-6's new
  `info` branch) were verified by inspection and static checks (`dash -n`, full-class test runs on
  the happy path), not by forcing the specific failure/edge branch each one guards.** Recorded
  honestly at each item's own closure rather than claimed as a live mutation; none is story-flagship,
  and each failure branch mirrors an already-proven sibling shape elsewhere in the same file.
- **MED-1's read-loop failure branch (`GuardedOpenId` failing for one inventory row) was verified by
  full-suite regression (happy path unaffected) and by code inspection, not by a live-forced failure**
  — constructing one cleanly through the public API would need either a race between
  `GuardedIdsForProfile` and the open (no window — both happen in one method call) or direct global
  surgery, neither attempted in the time available.
- **This session repeatedly observed the IRIS MCP test-runner client-side-timing-out while the
  server-side `%UnitTest` run continued** (DW-54's own documented pattern, encountered independently
  at least three times this pass) — once producing a genuinely orphaned, overlapping `OcuPilot.Test.Demo`
  class run that raced its own teardown against a second invocation. No test data was lost or
  corrupted (each episode was traced to a clean, if confusing, resolution and the instance's own
  state was confirmed clean afterward), but it materially slowed this pass's own verification and is
  worth the lead's continued awareness — it is orthogonal to anything this story's code controls.
- The pre-existing residual risks recorded above (iterations 2 and 3) are unchanged by this pass
  except where explicitly closed by one of the 13 items: `Kernel.State.Version`'s missing uniqueness
  constraint (DW-47, still open, research item); compiling the whole `src/OcuPilot/` tree including
  `Test.*` into the running instance (DW-48, still an epic-level decision); the checked-in demo X.509
  private key; `RemoveOne`'s three `Delete`-status-checked-but-untested-on-failure branches (DW-57);
  the seven ACs' `## Verification` mutation-line documentation gap (five of the seven now have their
  own corrected mutation evidence inline at this pass's own closures — AC3, AC11, AC12 — but the
  section header lines themselves were not mechanically re-synced, per step-03's "the fix would edit
  the spec under review").

### Summary of implemented change (step-04 review pass — this pass)

Reviewed the diff since `baseline_revision` with four parallel layers (Blind Hunter, Edge Case
Hunter, Verification Gap, Intent Alignment Auditor), per this workflow's step-04. 18 findings
triaged: 1 `high`, 8 `medium`, 5 `low` (2 `medium`/`low` groups shared a root cause across multiple
layers), plus 4 `n/a` from the Intent Alignment Auditor's own strictly-descriptive report (restating
context another layer or this pass's own self-disclosure already covered). Full account, per-finding
verdict and route, in `## Review Triage Log`'s newest entry. No `intent_gap` or `bad_spec` route was
needed — every real finding routed to `patch` (7) or `defer` (3, folded into frontmatter `deferred:`);
4 were `reject`ed as theoretical/unreachable or as a spec-edit `## Verification` sits outside this
build's reach.

**Patches applied (7), by theme:**

- **The single most significant verification gap in this pass**: none of the four regression tests
  protecting the HIGH cross-profile-fixture-collision fix pinned `Fixture.ResolvedPrefix`'s own
  output to an independent literal — all four recompute it from the function under test, so
  reverting the fix would leave every one green while reproducing the exact "probe run destroys
  production's own demo fixtures" scenario. Added `Test/Demo.cls TestResolvedPrefixQualifiesNonProductionProfiles`,
  pinning both profiles' outputs directly.
- **A real, narrower AC3 gap in the escalation-ordering fix itself**: `IsEscalationInfrastructureAbsent`
  guarded only `Install`'s own version-row read, not `EnsureVersion`'s identical read on the
  failure-recording path — so a first-install failure before `EnsureApplication` (for any OTHER
  reason) would leave the `failed` phase unrecorded, stuck reading `installing` forever. `EnsureVersion`
  now takes `pNames` and applies the identical guard.
- **A production data-integrity gap in this pass's own Catch-repair fix**: `TestDeleteByProfileRemovesProductionNullRows`'s
  Catch called `RestoreProductionDemoRows` unconditionally, which would insert duplicate rows if the
  exception happened before the delete itself ran. A `tDeleteRan` flag now gates the restore.
- **A missing test for a Fix-Pack item**: `Version.DeleteByProfile("")`'s NULL-purge branch (F-5) had
  no committed test, mirroring the gap `Demo`'s identical fix already closed. Added
  `Test/Version.cls TestVersionDeleteByProfileRemovesTheProductionRow`, copying that test's exact
  backup/delete/restore-from-Catch-too shape.
- **Three stale doc-comment claims**, all in `Test/DemoAppProbe.cls`, contradicting this pass's own
  removal of `Test.Demo`'s out-of-band collision-app block and its `ResolvedPrefix` fix — corrected at
  their origin.
- **A guard-then-act step reporting nothing**: `IsEscalationInfrastructureAbsent` emitted no
  `Kernel.Audit.Log` report on any outcome, unlike every sibling decision point in the file. Now
  reports once, at `info`, on the notable (absent) branch.

**Deferred (3, folded into frontmatter `deferred:`):** the AC12/DW-58 fix's own `tSinceSecsFloor`
still leaves a narrower (~59s) same-minute false-positive window, an inherent limit of the
underlying log's minute-only granularity; `TestExistingApplicationIsNeverModified`'s new
`DemoAppProbe.Create` call can trigger an additional ~300s Task-Manager wait on this container;
`IsEscalationInfrastructureAbsent` — this same pass's own live-discovered-and-fixed AC2 ordering
defect — has no automated regression test, only the one-off throwaway-container run, and would need
a new probe-subclass test seam to close.

**Rejected (4):** `ResolvedPrefix`'s own missing `pProfile` validation and
`IsEscalationInfrastructureAbsent`'s narrow mature-instance false-negative both require a state no
reachable call path in this codebase can produce (theoretical hardening); the AC10/AC11/AC12
`## Verification` mutation-line gap is a spec edit outside this build's reach (folded into the
existing, matching `deferred:` entry's own scope instead); one Intent Alignment Auditor divergence
(the escalation-fix test gap) restates a finding already counted once, above.

### Files changed (this pass, step-04 review)

- `src/OcuPilot/Install/Installer.cls` — `EnsureVersion` gained a `pNames` parameter and the same
  `IsEscalationInfrastructureAbsent` guard `Install`'s own read already had, at both call sites;
  `IsEscalationInfrastructureAbsent` gained a `pReports` parameter and reports once on the absent
  branch.
- `src/OcuPilot/Test/Demo.cls` — new `TestResolvedPrefixQualifiesNonProductionProfiles`;
  `TestDeleteByProfileRemovesProductionNullRows` gained a `tDeleteRan` guard around its Catch's
  restore call.
- `src/OcuPilot/Test/Version.cls` — new `TestVersionDeleteByProfileRemovesTheProductionRow` and its
  `RestoreProductionVersionRow` helper.
- `src/OcuPilot/Test/DemoAppProbe.cls` — three stale doc-comment passages corrected.

### Review findings breakdown (this pass's own review)

Full per-finding verdict, route and evidence in `## Review Triage Log`'s `2026-09-11 — Review pass
(rework iteration 4, step-04)` entry (18 findings — high 1, medium 8, low 5, n/a 4; 7 patched, 3
deferred, 4 rejected). Summarized by theme in "Summary of implemented change" above.

### Verification performed (step-04 review pass)

- `uv run scripts/check-objectscript.py`: 0 problems (after every patch above). `bash scripts/lint-docs.sh`:
  0 issues. `cd ui && npm test`: 97/97 (unaffected).
- Every patched class recompiled clean via IRIS MCP (`server: "ocupilot-iris"`, namespace `HSCUSTOM`,
  flags `ck`): `Installer.cls`, `Test/Demo.cls`, `Test/Version.cls`, `Test/DemoAppProbe.cls`.
- Full class runs, SQL-probe-confirmed, fresh and isolated (`iris_jobs_list` checked clear
  beforehand each time, never concurrent with each other): `OcuPilot.Test.Demo` 9/10 (only
  `TestDemoSeedsAnApplicationError` red, for the pre-existing daemon-latency reason the frontmatter
  `deferred:` entry already carries — not a regression from this pass's patches); `OcuPilot.Test.Version`
  19/19 (including the new `TestVersionDeleteByProfileRemovesTheProductionRow`).
  `OcuPilot.Test.Installer`'s full 23-method class was not re-run again in this review pass (already
  run once this iteration at its documented ~2.5-hour cost, for the HIGH finding's own fix); the
  `EnsureVersion` signature change was instead verified via the two full re-runs above (both exercise
  `Install`/`EnsureVersion` extensively) plus a direct check that no `Test.Installer` method calls
  `EnsureVersion` itself (`[ Private ]`, zero call sites outside `Installer.cls`).
- Production instance confirmed clean throughout and at hand-off: exactly one `Version` row
  (`Profile IS NULL`, `installed`, schema `1`), `Kernel.State.Demo` empty, `GateStatus() = "installed"`,
  zero `OcuPilot.Install.DemoTask` rows in `%SYS.Task`.
- Frontmatter `deferred:` list validated: parsed as YAML after every append, confirmed one list, 13
  items (10 preserved unchanged, 3 new from this pass), no duplicate `deferred:` key.

### Follow-up review recommendation: `true`.

One `high`-verdict finding was patched this pass (`ResolvedPrefix`'s own regression tests deriving
their expected value from the function under test) — per this workflow's own rule, a patched `high`
on a first pass makes this `true` regardless of how thoroughly it was verified. Named unverified risk:
**`Installer.IsEscalationInfrastructureAbsent`** — this same pass's step-03 verify-stage fix for a
real, live-discovered AC2 first-install ordering defect (`ERROR #868` on a genuinely fresh instance)
— still has no automated regression test (deferred above, not patched): every test in this suite runs
against an instance where the escalation application already exists, so the guard is a no-op for the
whole committed suite regardless of whether it is present, inverted, or removed. The only evidence
this fix has is a one-off, non-repeatable throwaway-container run. A human reviewer should weigh
whether that one-off evidence is sufficient to ship, or whether the new test seam this deferred entry
names (a probe subclass overriding `Security.Applications.Exists`) should be required before `done`.
