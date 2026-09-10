---
title: 'Story 1.4: One command brings up an instance with OcuPilot installed'
type: 'feature'
created: '2026-09-09'
status: 'in-progress'
baseline_revision: 'd8bae2f1de2232bab0e32f0962c0b466842b281f'
baseline_commit: '12a6869c99b752d4a07840e02ccb2733714cfd51'

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
  - summary: 'OcuPilot.Test.Demo TestDemoTaskIsSuspendedAfterAnError is flaky on this specific long-lived ocupilot container (Task Manager daemon latency growing well past 90s, then past 300s, after repeated task churn)'
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

- [ ] [Review][Patch] **Production `Uninstall` destroys the demo inventory before `Fixture.Remove` reads it — every production fixture is orphaned (AD-25).** [src/OcuPilot/Install/Installer.cls:1321] `Uninstall` deletes the `OcuPilot*` global mapping, the `OcuPilotState` privileged routine application and the `OCUPILOT` database *first*, then calls `Fixture.Remove(pProfile)`. By then `Demo.GuardedIdsForProfile` has neither its data global nor its escalation point, so it returns no rows (or an error), `Remove` reports `$$$OK` having removed nothing, and `/csp/myapp`, `OcuPilotDemoTLS`, `OcuPilotDemoCert` and the demo task survive uninstall. AD-25's Rule ends "and uninstall removes it"; `Demo.cls`'s own header says the inventory exists "so uninstall removes exactly what install created". Invisible to the suite because the probe profile's mapping pattern (`ProbeOcuPilotState*`) does not cover `^OcuPilot.Kernel.State.BaseD` and its escalation application is unsuffixed, so probe rows survive the database delete. severity=high fix-risk=med footprint=in-story spec-clear. Suggested shape: move fixture removal to before the mapping/application/database block, keeping the read-in-install-namespace → remove-in-%SYS → purge-after-restore ordering the Design Notes prescribe.
- [ ] [Review][Patch] **Three fixture names carry no profile, so the `"probe"` teardown deletes production (or an operator's) objects — AD-25 "never writes on an operator's instance".** [src/OcuPilot/Install/Fixture.cls:183] `CreateSslConfig` (`OcuPilotDemoTLS`), `CreateX509Credential` (`OcuPilotDemoCert`) and `CreateTask` (`OcuPilotDemo nightly purge`) derive their names from `#DEMOPREFIX` alone, and all three call `NoteRow` on their *already-exists* branch — adopting an object this run did not create into the calling profile's inventory. `Test.Demo.OnBeforeAllTests` calls `Fixture.Create("probe")` and `OnAfterAllTests` calls `Fixture.Remove("probe")`, so on any instance where `StartPath(1)` has created the production fixtures — which `docker-compose.yml`'s `OCUPILOT_DEMO: "1"` makes the default from the first start — a test run deletes them. `CreateWebApp` deliberately does *not* `NoteRow` on collision and documents why; the other three contradict it silently. severity=high fix-risk=med footprint=in-story spec-clear. Suggested shape: treat an already-existing object the way `CreateWebApp` treats a collision (warn, no `NoteRow`), or qualify the names by profile.
- [ ] [Review][Patch] **`RemoveOne` still discards three of four `Delete` statuses, and its own comment claims the opposite.** [src/OcuPilot/Install/Fixture.cls:456] `Do ##class(Security.Applications).Delete(pName)`, `Do ##class(Security.SSLConfigs).Delete(pName)` and `Do ##class(%SYS.X509Credentials).Delete(pName)` are bare `Do`s in the same method where iteration 2 wrapped `%DeleteId` in `$$$ISERR` with a long comment about silent failure undermining AD-25. This is the half-applied form of the one defect iteration 2 actually confirmed. Violates `.claude/rules/objectscript-basics.md` ("Do not silently discard write failures") and the spine's *Status handling* row. The false clause in the comment is corrected below (A-3); the code is not. severity=high fix-risk=low footprint=in-story spec-clear.
- [ ] [Review][Patch] **The DW-53 regression pin tests a retyped copy of the guard, not the guard — Rule 19.** [src/OcuPilot/Test/Demo.cls:301] `TestNoMatchGuardResolvesEmptyWithoutThrowing` re-implements `If $$$ISOK(tQSC) && $Data(tIds) { Set tFirst = $Order(tIds("")) Set tId = tIds(tFirst) }` inline and asserts *that copy* does not throw. It never references `OcuPilot.Install.Fixture` — and cannot, since `CreateTask`/`RemoveOne` are `[ Private ]`. Reverting `Fixture.cls:270` to the literal `$Data(tIds(tFirst))` form leaves this test green. Its own doc, and the spec's DW-53 correction paragraph, both state the opposite ("fails loudly and deterministically here"), and the triage records the gap as closed. This is the story's gate that cannot fail. severity=high fix-risk=med footprint=in-story spec-clear. Suggested shape: expose the guard as a callable helper (or drop `[ Private ]` on `CreateTask`) and drive the real one.
- [ ] [Review][Patch] **Three of AC9's five fixtures have no positive assertion, and `CreateWebApp`'s create branch is structurally unreachable in the suite.** [src/OcuPilot/Test/Demo.cls:28] `Parameter COLLISIONPATH = "/csp/myapp"` is the *same value* as `Fixture.cls:34`'s `Parameter APPPATH`, and `OnBeforeAllTests` creates that application before calling `Fixture.Create("probe")` — so every run takes `CreateWebApp`'s DW-13 collision branch and its create path never executes. No test asserts `OcuPilotDemoTLS` exists, that `OcuPilotDemoCert` exists, that either carries the `OcuPilotDemo` prefix or has an inventory row, or that the demo web application is created **disabled with no resource** (a security-relevant property the spec's own `%All`-trap section says is a property read `%All` cannot mask). Deleting `CreateSslConfig`'s or `CreateX509Credential`'s body entirely leaves every test green. **Not covered by DW-50**, whose scope is the container/health-check/HTTP/shell surface — these need no container. severity=high fix-risk=low footprint=in-story spec-clear. Suggested shape: give `Test.Demo` a distinct collision path so `APPPATH` is genuinely absent, then assert existence + properties + one inventory row per fixture.

**Rework loop — MED (fix now, Rule 15: fix-risk ≤ med and in-footprint, so not deferrable).**

- [ ] [Review][Patch] **A failed first install permanently disables the `_SYSTEM` unexpire (AC2).** [src/OcuPilot/Install/Installer.cls:258] `tFirstInstall` is derived from the version row's *presence*, and the `ElseIf tFailingStep '= ""` branch writes a `failed` row on almost every failure path. So a first install that fails after `Names()` leaves a row behind, every later start reads `tFirstInstall = 0`, and `EnsureUnexpired` is skipped for good — while `README.md` and `CLAUDE.md` now both promise a clean `docker compose up -d --wait` needs no manual step. AC14's literal wording ("only when this profile carries no version row") is the mechanism, not the promise; a failed attempt is not an install (Boundaries: "never unexpire on a start that is not the first install on this durable volume"). Capped at med because CLAUDE.md keeps the manual command as a documented recovery path. severity=med fix-risk=low footprint=in-story. Suggested shape: treat a `failed` row as not-yet-installed for this gate only.
- [ ] [Review][Patch] **`GateStatus()` returns `installed` when the stored schema version is *ahead* of the deployed code.** [src/OcuPilot/Install/Installer.cls:440] The ladder is `failed` → not-`installed` → `tStoredVersion < #SCHEMAVERSION` → `installed`, so a downgrade — the one case `PlanMigration` refuses outright — falls through to `installed`. After a refused downgrade `StartPath` returns an error and the hook exits non-zero, but the health check reads `GateStatus()`, sees `installed`, and reports the container **healthy** while old code serves traffic against a newer schema. AC3's "the health check never reports healthy" does not hold for that case. AC6's "changes nothing" is not violated by a read. severity=med fix-risk=low footprint=in-story.
- [ ] [Review][Patch] **`Fixture.Remove` purges the inventory on two paths where nothing was removed.** [src/OcuPilot/Install/Fixture.cls:426] The second `Try`'s `SwitchNamespace` failure warns "nothing removed" and `Quit`s the block, and `Catch ex2` does the same — both then fall through to the unconditional `DeleteByProfile(pProfile)`, whose own warn text reads "Demo fixture objects **were removed** but the inventory rows could not be purged". Objects left on the instance, the only record of them deleted. This is exactly the orphan-on-read-failure defect the same diff fixed three lines above (`Set tInventoryReadable = 0`, with a comment explaining why), left unfixed on the removal stage. severity=med fix-risk=low footprint=in-story.
- [ ] [Review][Patch] **`RemoveOne`'s task branch queries every namespace.** [src/OcuPilot/Install/Fixture.cls:481] `QueryTasks("OcuPilot.Install.DemoTask", pName, "", .tIds)` passes `""` for the namespace, while `CreateTask` passes `pInstallNs`; every id returned is then deleted. The inventory row's `Scope` (the install namespace) is read into `tKinds`/`tNames` and never passed down — `RemoveOne` has no scope parameter. Uninstalling one namespace's fixtures removes another namespace's identically-named demo task. severity=med fix-risk=low footprint=in-story.
- [ ] [Review][Patch] **`Kernel.State.Demo.DeleteByProfile("")` cannot match the rows its own siblings find.** [src/OcuPilot/Kernel/State/Demo.cls:40] It uses `WHERE Profile = ?` bound to `""`, which never matches SQL `NULL`, while `GuardedRowExists` and `GuardedIdsForProfile` in the same class both special-case `Profile IS NULL`. Documented as a deliberate no-op inherited from `Stamp` — but `Stamp` is an append-only history where retention is intended, whereas `Demo`'s rows *are* the removal roster. Currently masked by the uninstall-ordering finding above; it becomes live the moment that one is fixed. severity=med fix-risk=low footprint=in-story.
- [ ] [Review][Patch] **AC12's fixture confirms rather than seeds, and depends on the unbounded Task Manager daemon.** [src/OcuPilot/Install/Fixture.cls:348] `CreateErrorEntry` guards on `If '$Data(^ERRORS)` and otherwise writes an inventory row — it raises nothing. The Design Notes prescribe the opposite ("the fixture **raises a real, controlled error inside its own routine** and lets the trap log it"), and the AC12 mutation line is worded "swallow the deliberate error **in the seeding routine**". Two consequences: any pre-existing `^ERRORS` entry from an unrelated source satisfies the check, and the report then over-claims it came "from the demo task fixture's own deliberate failure"; and on a clean container with the >1h daemon latency this spec itself records, `^ERRORS` stays empty, AC12 is unmet, and Story 5.13's stated dependency ("a non-empty fingerprint set on a clean install") does not hold. The mechanism change was never recorded in the Spec Change Log. severity=med fix-risk=med footprint=in-story.
- [ ] [Review][Patch] **AC4's "exactly one version row exists per profile" is asserted nowhere and has no mutation line.** [src/OcuPilot/Install/Installer.cls:468] Every reader is `SELECT TOP 1 … ORDER BY ID DESC`, so a duplicate row is invisible; `StateFingerprint` folds in the newest row's values and would be byte-identical across duplicates. Changing `EnsureVersion` to always `%New()` leaves the whole suite green. Distinct from DW-47 (no unique constraint, research): the missing *assertion* is one `COUNT(*)` appended to `TestFirstInstallFlagComesFromTheVersionRow`, which already installs twice. severity=med fix-risk=low footprint=in-story.
- [ ] [Review][Patch] **AC3's `StartPath` error propagation is pinned one frame below the mutation the spec names.** [src/OcuPilot/Install/Installer.cls:377] The AC3 mutation line says "in `StartPath`, discard the failing step's `%Status` and fall through" and pins it to `TestFailingStepLeavesPhaseFailed` — which drives `MigrateFault.Install("probe")`, never `StartPath`. Changing `Set tSC = ..Install("")  If $$$ISERR(tSC) Quit tSC` to swallow the error leaves that test green; the only other `StartPath` caller in the tree asserts `$$$AssertStatusOK` on a healthy instance. The hook's exit code — the whole point — then reports success after a failed install. severity=med fix-risk=low footprint=in-story.
- [ ] [Review][Patch] **AC13's "the caller's namespace is unchanged" assertion cannot fail — Rule 19.** [src/OcuPilot/Test/Version.cls:293] `TestInstallRefusesFromWrongNs` reaches the guard through `Installer.TestOnlyInstallFromSys`, which ends with an unconditional `Set $NAMESPACE = tOrig` outside its `Try`/`Catch`. Whatever `Install` leaves `$NAMESPACE` set to, the seam resets it before returning, so `$$$AssertEquals($NAMESPACE, tStart, …)` passes either way. The spec's AC13 mutation line explicitly claims this catches "a guard that refuses but leaves the namespace moved". It does not. severity=med fix-risk=low footprint=in-story. Suggested shape: have the seam capture `$NAMESPACE` immediately after `..Install()` returns and expose it as an `Output` argument.
- [ ] [Review][Patch] **AC8's timeout test compares `ReportGatewayGap`'s output against the same method that produced it, and passes vacuously when both reads are empty.** [src/OcuPilot/Test/Version.cls:320] `TestGatewayTimeoutIsReportedFromTheLiveSource` calls `ReportGatewayGap`, then calls `GatewayResponseTimeout` as the "independent read" — but `ReportGatewayGap` obtains its own value from exactly that method, so any defect inside it appears identically on both sides. On an instance where neither source answers, both are `""` and the test asserts `"" = ""` — two runs compared that both produce nothing. It also never reads `tData.source`, though AC8 requires the report to name the source. The two cheap halves are in scope now (assert `source '= ""`; make the empty/empty case an explicit skip or a red); a genuinely independent read means parsing `CSP.ini` in the test, which is DW-51's territory. severity=med fix-risk=low footprint=in-story.
- [ ] [Review][Patch] **`Fixture.Create`'s inventory loop drops a `GuardedRowExists` failure silently.** [src/OcuPilot/Install/Fixture.cls:118] `If $$$ISOK(tExistsSC) && ('tExists)` has no `else` branch — an error status skips the row with no `warn`, so a fixture object is created with no inventory row and can never be removed by `Remove`. Every other failure in this class is reported. severity=med fix-risk=low footprint=in-story.
- [ ] [Review][Patch] **`TestPopulatedRowsSurviveMigration` depends on this instance's accumulated history, so AC5's survival half fails on the container the story is about.** [src/OcuPilot/Test/Version.cls] It asserts `SELECT TOP 1 … FROM OcuPilot_Kernel_State.Stamp` returns a row, justified in the class doc by "this instance already carries hundreds from earlier install runs". On a fresh container that table is empty and the test fails for environmental reasons, on the exact "one command on a clean clone" path this story ships. severity=med fix-risk=low footprint=in-story. Suggested shape: have the test seed its own probe-profile row before migrating.

**Applied by the reviewer (mechanical corrections only; verified by recompile + `Test.Version` 14/14).**

- [x] [Review][Patch] **A-1 `DemoTask.cls`'s class header asserted `Status = -2` at its own origin.** [src/OcuPilot/Install/DemoTask.cls:4] The header claimed the Task Manager "writes a populated `Status` (`-2`, `JobUntrappedError`)" while the same file's `OnTask` doc, the Spec Change Log and AC11 all record that this build leaves `Status` at `1`. Corrected at origin (CLAUDE.md's "correct a wrong claim at its origin", which this story has already been bitten by twice).
- [x] [Review][Patch] **A-2 `README.md` labelled an authenticated probe "Confirmed unauthenticated".** [README.md:105] The command carries `-u _SYSTEM:SYS`, and AC2 itself calls it "an authenticated `HEAD /api/atelier/`". Corrected to "Confirmed authenticated".
- [x] [Review][Patch] **A-3 `RemoveOne`'s comment claimed a discipline the method does not follow.** [src/OcuPilot/Install/Fixture.cls:490] It ended "the same guard-then-act discipline every other fixture removal in this method already follows" — false when written; three of four branches still discard their status. Comment corrected to say so and to name the open finding. The code fix stays in the rework list above.
- [x] [Review][Patch] **A-4 `EnsureUnexpired`'s report text contradicted its own parameter's documentation.** [src/OcuPilot/Install/Installer.cls:536] It emitted "the installing account's password" and "the installing identity", while `#UNEXPIREACCOUNT`'s header says in bold that the target is the fixed constant `_SYSTEM` and deliberately **not** `$Username` (verified live as `irisowner` in the container). Reworded to "the named install account".
- [x] [Review][Patch] **A-5 `Test/Demo.cls` hardcoded the 300s wait budget in the DW-46 skip message.** [src/OcuPilot/Test/Demo.cls:209] `(300 + ..#EXTRAWAITSECONDS)` duplicated `Fixture.#TASKWAITSECONDS`, which has already moved once this story (90 → 300); the next change would have made the message state a false wall-clock figure. Now reads the parameter.
- [x] [Review][Patch] **A-6 Two comments stated an observation about `QueryTasks` as a property of `$Data`.** [src/OcuPilot/Install/Fixture.cls:268] `$Data` is also truthy at `1` (a top-level value with no descendants), where `$Order(x(""))` returns `""` and the next line would throw the very `<SUBSCRIPT>` the guard prevents. The sites are safe only because `QueryTasks` was *observed* returning `$Data` of 0 or 10 and never 1 — a handful of probes, not a proof, and `%SYS.TaskSuper` ships with every method body stripped so it cannot be settled from source. Both comments now label the inference as one and point at F-1. Also corrected `Test/Demo.cls`'s copy, which narrowed the throw to "when `QueryTasks` matches nothing" — it throws unconditionally; matching nothing is where it *bites*.

**`## Fix Pack` — LOW two-way doors, one bounded iteration (Rule 15).**

- [ ] [Review][Patch] **F-1 Make the `QueryTasks` guard unconditionally correct: `$Data(tIds) \ 10`.** [src/OcuPilot/Install/Fixture.cls:270, :481; src/OcuPilot/Test/Demo.cls:183] Removes the residual dependence on the observation in A-6 entirely. Behaviour-affecting, so it needs its own demonstrated mutation — pair it with the H4 test-seam fix that would pin it.
- [ ] [Review][Patch] **F-2 `container-start.sh`'s `LOAD-FAILED` branch is defeated by multi-line error text.** [scripts/container-start.sh:104] `grep -o 'OCUPILOT-RESULT-START:.*:OCUPILOT-RESULT-END'` matches within one line; `$System.Status.GetErrorText` on a multi-document compile failure can span lines, leaving `RESULT` empty so control reaches the `*)` fallback and prints "see the phase and failing step recorded on the version row" — the exact misleading message the `LOAD-FAILED*` case was added to avoid. Exit code stays correct. Fix: `$Translate(tOutcome, $Char(13,10), "  ")` before the `Write`. Needs a throwaway-container check, so it is not a reviewer patch.
- [ ] [Review][Patch] **F-3 `container-health.sh` spawns two full `iris session` logins per probe, every 10s, for the container's life.** [scripts/container-health.sh:12] The namespace-resolution session is re-run on every probe although its answer cannot change. Every branch is also a bare `exit 1` with no message, so `docker inspect`'s health log records nothing beyond the code. (Labelled as an inference, not verified: on an instance whose installer has just enabled auditing, each login may also be an auditable event.)
- [ ] [Review][Patch] **F-4 `GatewayResponseTimeout` leaks the file handle on the error path.** [src/OcuPilot/Install/Installer.cls] `Do tFile.Close()` runs only after the `While` loop completes normally; an exception inside `ReadLine` lands in `Catch ex` with the file still open.
- [ ] [Review][Patch] **F-5 `ReportGatewayGap` always reports "No web application was created by this run"** [src/OcuPilot/Install/Installer.cls:558] — including on `StartPath(1)`, where `CreateWebApp` did create one and emits its own gap line into the same drained stream. Two contradictory lines in one report.
- [ ] [Review][Patch] **F-6 Two tests hardcode `"HSCUSTOM"`** [src/OcuPilot/Test/Demo.cls:243, :310] while the rest of the class resolves the namespace through `Installer.ResolveNamespace()`. AC2 and AC12 both admit `USER` as the install namespace, where both tests would silently probe the wrong one.
- [ ] [Review][Patch] **F-7 `Test/Demo.cls:183`'s guard is `If $Data(tIds)` where the other three sites are `If $$$ISOK(tQSC) && $Data(tIds)`.** Not a live defect — but `TestNoMatchGuardResolvesEmptyWithoutThrowing` is declared to be the regression pin for *this* shape and encodes the stricter one, so a regression dropping the `$Data` check here would leave the pin green.

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
install and uninstall.** `Test.Version` manipulates version rows and calls the migration, phase and guard
methods directly; it invokes `Install("probe")` in exactly **one** method (the downgrade-refusal
integration test) with its own targeted teardown. `Test.Gate` and `Test.Demo` install nothing —
`Test.Demo` drives `Install.Fixture` directly under the probe profile. Net addition: one cycle per full
run, not fifteen.

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
  phase `installed` → `TestFailingStepLeavesPhaseFailed` in `Test/Version.cls` (driven by
  `Test.MigrateFault`) goes red on both the phase and the named failing step. That pins the load-bearing
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
  goes red because the call from `%SYS` no longer returns the error naming both namespaces. Verify by
  reading the caller's `$NAMESPACE` after the call as well, so a guard that refuses but leaves the namespace
  moved is also caught.
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

### Residual risks

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
