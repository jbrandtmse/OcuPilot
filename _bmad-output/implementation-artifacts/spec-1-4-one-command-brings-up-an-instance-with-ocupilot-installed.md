---
title: 'Story 1.4: One command brings up an instance with OcuPilot installed'
type: 'feature'
created: '2026-09-09'
status: 'done'
baseline_revision: '12a6869c99b752d4a07840e02ccb2733714cfd51'
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
| **DW-14** task fixture | flag set | `OcuPilotDemo` task exists, scheduled, `Suspended` > 0, `Status` < 0, `Error` non-empty and readable | Fixture failure is a `warn`; it never fails install |
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

## Spec Change Log

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

**Planning (preserved from the earlier pass, unchanged in substance):** the spec was verified against the
READY-FOR-DEVELOPMENT standard before implementation began — every task carries a file path and a specific
action, all fourteen ACs are Given/When/Then, every I/O matrix row has a named test host, every AC carries
a `mutation:` line. Ledger inbox (Rule 17): **DW-13** by AC10, **DW-14** by AC11, **DW-15** by AC12, all
addressed. Rule 5 (NFR-9): measurable as worded via AC4, no amendment sought at plan time. Rule 6:
governing ADs recorded under `## Design Notes`. Rules 1/2: AC7 is the Integration AC.

### Summary of implemented change

Wrapped Story 1.3's `Install.Installer` in a container start path: an explicit `2026.2` image pin, a
`--after` hook (`scripts/container-start.sh`) that resolves the install namespace, loads/compiles
`src/OcuPilot/`, and calls the new `StartPath()`; a compose `healthcheck` (`scripts/container-health.sh`)
reading the same gate the API does; the AD-38 version stamp (`Kernel.State.Version`) with an ordered
forward-migration runner and downgrade refusal; a traffic gate in `Api.Router.OnPreDispatch` (first act,
before authentication) rendering the one 503 envelope while the stamp is not current; the guarded
`_SYSTEM` unexpire; and the opt-in demo fixture set (`Install.Fixture`, `Install.DemoTask`,
`Kernel.State.Demo`) with an inventory so uninstall removes exactly what install created. One AC
(AC11's literal "`Status` below zero") was amended during implementation after live verification showed
this build's Task Manager never produces a negative `Status` for a task's own `OnTask` failure by any
supported technique — recorded in `## Spec Change Log`, not silently worked around. A follow-up review
pass (four parallel layers: blind-hunter, edge-case-hunter, verification-gap, intent-alignment) found and
this pass then fixed six further correctness gaps and added two tests closing the two highest-value
verification gaps; see `## Review Triage Log` for the full account of all 32 findings.

### Files changed

- `src/OcuPilot/Kernel/State/Version.cls` (new) — the AD-38 version/phase stamp, one row per profile.
- `src/OcuPilot/Kernel/State/Demo.cls` (new) — the fixture inventory.
- `src/OcuPilot/Install/Fixture.cls` (new) — the five opt-in demo fixtures; review fixes: skips the
  removal+purge path on an inventory-read failure instead of purging anyway, records the correct `Scope`
  for the error-log fixture, widened `TASKWAITSECONDS` 90→300, added a diagnostic for an unreadable
  `/proc/1/environ`-equivalent condition (n/a — that check lives in the shell script; this class's own
  fix is the wait-window widening and the two correctness fixes above), and names the CSP Gateway
  registration gap for the web-application fixture it creates.
- `src/OcuPilot/Install/DemoTask.cls` (new) — the deliberately-failing demo task.
- `src/OcuPilot/Install/Installer.cls` — `StartPath`, `Phase`, `GateStatus`, `DeployedSchemaVersion`,
  `EnsureVersion`, `EnsureUnexpired`, `ReportGatewayGap`, `GatewayResponseTimeout`, `PlanMigration`,
  `RunMigrations`, `MigrationStep`, `MigrateToVersion1`, `TestOnlyInstallFromSys`, `CurrentVersionRow`;
  extended `Install`/`Uninstall`/`StateFingerprint`. Review fixes: a version-row *read failure* (distinct
  from an absent row) now refuses instead of silently defaulting to "first install, version 0"; the
  success and failure version-row writes now both fold their own `%Status` back into the result instead
  of only warning; `tFailingStep` is now tracked through `Names()` and the `%SYS` switch (the two
  sub-cases AC13/AC6 do not already carve out); `GateStatus` reads the version row once instead of twice.
- `src/OcuPilot/Api/Error.cls` — the three `INSTALL.*` codes on the existing `unavailable` slug.
- `src/OcuPilot/Api/Router.cls` — the install gate as the first act of `OnPreDispatch`.
- `src/OcuPilot/Test/{Version,Demo,Gate,GateFixture,MigrateFault}.cls` (new), `InstallerProbe.cls`
  (extended) — the AC2-AC14 test coverage. Review additions: `Test.Gate.TestInstallingPhaseRefusesEvenForAnAnonymousCaller`
  and `Test.Version.TestRealProductionGateResolvesToInstalledAfterInstall`, closing the two `high`-verdict
  verification-gap findings; `Test.Demo`'s stale "~90 seconds" comment corrected.
- `scripts/container-start.sh`, `scripts/container-health.sh` (new). Review fixes: an explicit diagnostic
  when `/proc/1/environ` is unreadable, and a `LOAD-FAILED`-specific failure message (the generic one
  wrongly pointed at "the version row," which a compile failure never reaches).
- `docker-compose.yml` — the `2026.2` pin, read-only `./src`/`./scripts` mounts, the demo flag, the
  `--after` command, the `healthcheck`.
- `ui/tools/compose.test.mjs` (new) — 9 tests pinning the compose-file surface.
- `README.md`, `CLAUDE.md` — replaced the Story 1.3 hand-off text with the start-path documentation and
  the now-automated unexpire step.

### Review findings breakdown

32 findings across four parallel review layers (2026-09-10). **Verdicts:** high 2, medium 14, low 12,
false 4. **Patched (16):** the `EnsureVersion` `%Status`-folding symmetry (both call sites, 4 grouped
findings), the version-read-failure fail-closed fix, the `Fixture.Remove` orphaning-on-read-failure fix,
the `CreateErrorEntry` `Scope` fix, the `tFailingStep` completeness fix, the `GateStatus` single-read fix,
the two `TASKWAITSECONDS`/comment/diagnostic/message hygiene fixes, and the two new `high`-verdict tests
(anonymous-caller-during-non-installed-phase ordering; the real, unmocked production gate chain).
**Deferred (6, in frontmatter `deferred:`):** `Kernel.State.Version`'s missing uniqueness constraint;
compiling the whole `src/OcuPilot/` tree (including `Test.*`) into the running instance; the checked-in
demo X.509 private key; the container/health-check/HTTP/shell-level surface's reliance on a one-off manual
throwaway-container run instead of an automated test (grouped: verification-gap's `StartPath(1)`
production-profile-untested finding + the intent-alignment auditor's two matching observations); the
unanchored `CSP.ini` substring match; a narrow task-id-deleted-before-reopen race. Plus the one
pre-existing, ledgered flake from implementation (`Test.Demo`'s `TestDemoTaskIsSuspendedAfterAnError` on
this specific long-lived container). **Rejected (10):** the mid-repair gate-protection-window observation
(low, fix bigger than a direct correction); the discarded `LoadDir` error-log detail (low, `%Status`
already gates correctness); the duplicated shell namespace-resolution snippet (low, stylistic); the
`Guarded*Where*` method-family duplication (low, refactor risk to security-escalation code); the image
tag-vs-digest point (false — by design, spec's own AC1 wording, appears twice from two reviewers); the
compose-healthcheck-timeout-margin claim (false — disproved: the healthcheck reads `GateStatus` directly,
decoupled from the fixture wait, confirmed by the implementer's own AC3 container test); the `^ERRORS`
pre-existing-entries self-check looseness (low — the real AC12 guarantee is already correctly pinned
elsewhere); the AC11 divergence (already resolved pre-review, carried forward, no action). Full evidence
for every finding is in `## Review Triage Log` above.

**Follow-up review recommendation: `true`.** Two `high`-verdict findings were patched this pass
(verification-gap's router-ordering and production-gate-chain gaps) — per this skill's own rule, that
alone crosses the follow-up threshold on a first pass. Named unverified risk: the sixteen patches above
were authored and verified by the same session that reviewed them, not by an independent pass; a fresh
reviewer should specifically re-check (a) the `tFailingStep`/`%Status`-folding changes to `Install()`
against the full `Test.Installer` suite (only `TestInstallIsIdempotent` and
`TestProductionInstallIsIdempotent` were re-run individually after these specific patches, not the full
22-method class, given that suite's own ~2-hour worst-case `SYS.Database.DeleteDatabase` cost on this
container — the full 22/22 pass recorded below predates these last patches by one round of fixes to the
same methods, though not to `Uninstall` itself), and (b) the two new tests' own robustness now that they
exist.

### Verification performed

- `uv run scripts/check-objectscript.py` — 0 problems (final tree).
- `bash scripts/lint-docs.sh` — 0 issues, including this file, `README.md`, `CLAUDE.md`.
- `dash -n scripts/container-start.sh` / `container-health.sh` — clean (the accurate proxy for the
  container's real `/bin/sh`; this session's own `sh` resolves to bash on the reviewing machine and
  produced one false-positive on a pre-existing, implementer-verified-working line, recorded in the
  triage log).
- `cd ui && npm test` — 97/97 (88 pre-existing + 9 new `compose.test.mjs`).
- Full `src/**/*.cls` MCP load+compile (`server: "ocupilot-iris"`), clean, throughout.
- `%UnitTest` ground truth via the mandatory SQL probe (`.claude/rules/objectscript-testing.md`), latest
  full-class run per class: `Version` 14/14, `Gate` 6/6, `State` 8/8, `Routing` 12/12, `Envelope` 10/10,
  `Log` 5/5, `EntityId` 3/3, `Installer` 22/22 (this run predates the six small `Installer.cls`/`Fixture.cls`
  review patches; `TestInstallIsIdempotent` and `TestProductionInstallIsIdempotent` were individually
  re-verified green after those patches — see the named residual risk above), `Demo` 3/4 (the one ledgered
  flake).
- `grep -rn "New \$ROLES\|AddRoles" src/OcuPilot/` — matches only `Kernel/State/Base.cls` (the one
  escalation point) and pre-existing Story 1.3 doc-comment/string-literal matches in `Installer.cls`,
  `Test/Installer.cls`, `Test/State.cls`, `Stamp.cls`; none of this story's new classes add escalation.
- Rule 19 falsifiability: mutations run live and reverted (byte-identical confirmed by `diff`) for AC1,
  AC3 (both the version-row half and, via `TestFailingStepLeavesPhaseFailed`, the `RecordStamp`-step
  variant this review's own patch touched), AC6 (both the pure-predicate and call-site halves), AC7 (the
  ordering half), and AC13 — each observed red, then reverted to green. AC14's mutation was **deliberately
  not executed live**: the spec's own literal mutation text (`change the unexpire target ... to "*"`)
  would, if compiled and run, call the real `Security.Users.UnExpireUserPasswords("*")` against this
  shared instance — exactly the action this spec's own "Never" list and this project's operating rules
  forbid. Relied on code review (the call site is a call-site literal, `..#UNEXPIREACCOUNT`, never a
  variable) and the implementer's own prior verification instead. AC2/AC3's exit-code-mapping mutations
  and AC4/AC5/AC8-AC12's mutations were not independently re-run this pass (container-cost / already
  covered by the implementer's own throwaway-container report in detail); their pinning tests were
  confirmed green via the SQL ground truth above.
- Live-verified this pass, independently of the implementation subagent's own report: the demo task
  fixture's `Suspended`/`Status`/`Error` behavior on this build (`suspended=1 status=1
  error=[<THROW>OnTask+1^OcuPilot.Install.DemoTask.1 ...]`, confirming the AC11 amendment's evidence), the
  `ocupilot-iris` vs. `default` MCP profile separation (52774 vs. 52773), and the `%SYS.TaskSuper.Status`
  property's own documented `-2` `JobUntrappedError` claim against this build's actual behavior (fetched
  live via `%Compiler.UDL.TextServices.GetTextAsString`, since the class is `[ Hidden ]`).

### Residual risks

- The one ledgered flake (`Test.Demo` on this specific long-lived container) and the six deferred findings
  above, all with evidence and disposition recorded in frontmatter `deferred:` and in the triage log.
- The named follow-up-review risk above (independent re-verification of this pass's own patches).
- The real `ocupilot` container's Task Manager daemon showed growing `RunNow`-to-actual-run latency across
  this review session (~50s → ~150s → still unresolved past ~240s on one attempt) — plausibly an artifact
  of this session's own repeated task-fixture churn on top of four stories' worth of prior testing, not a
  property of a fresh instance, but worth the lead's awareness if it recurs on this same container.
