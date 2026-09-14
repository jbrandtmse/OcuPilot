---
title: 'Story 1.18: Epic 1 burn-down'
type: 'bugfix'
created: '2026-09-13'
status: 'done'
baseline_revision: '0d1206bacdee58df1208e578e1a1e44c7b72973e'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['multiple-goals', 'oversized']
deferred:
  - 'Readiness answered HTTP 500 twice during a throwaway `docker restart` recompile (never `unreadable`); likely a class mid-compile at dispatch (inference), unrelated to the gate ladder.'
  - 'About 120 `EXPERIENCE.md :n` citations in `ui/` comments outside `strings.ts` now point at shifted lines after the Fixed-strings rows were added.'
  - summary: >-
      A widened SQL grant on OcuPilot_Kernel_State, another role or _PUBLIC holding it, is neither detected nor refused.
    evidence: |-
      DW-96's ledger evidence names "a revoked or widened grant"; the owner decision scoped this story to the unreadable state, read-back of the escalation role's grant and a derived schema, so the widened half is still open.
    location: >-
      src/OcuPilot/Install/Installer.cls EnsureSqlPrivileges
    severity: medium
  - summary: >-
      The client keeps INSTALL.FAILED and INSTALL.UPGRADEREQUIRED in the install backoff indefinitely, although neither clears by waiting.
    evidence: |-
      isInstallInFlight counts every INSTALL.* code except INSTALL.UNREADABLE, so the tab shows "Signing in…" and re-probes forever on a failed install; wait-readiness.sh exits 1 on both states. Pre-existing since Story 1.13.
    location: >-
      ui/src/app/core/session.ts isInstallInFlight
    severity: medium
  - summary: >-
      The pinned actions/checkout v4, actions/setup-node v4 and astral-sh/setup-uv v5 declare the node20 runtime.
    evidence: |-
      A reviewer read `using: node20` from each action through gh api. If GitHub has removed Node 20 action support from its runners, CI fails at checkout. Settle by checking GitHub's Node 20 runner deprecation date against the next push.
    location: >-
      .github/workflows/ci.yml uses
    severity: medium (unverified)
  - summary: >-
      The probe profile's matching role ProbeOcuPilotShell was still present after Uninstall("probe") on one throwaway.
    evidence: |-
      Seen by the rework-1 implementation pass on a throwaway that had already been through the orphaning replay, so it may not reproduce on a clean one. Settle by listing Security.Roles after a clean probe Install and Uninstall on a fresh throwaway.
    location: >-
      src/OcuPilot/Install/Installer.cls Uninstall
    severity: medium (unverified)
---

<intent-contract>

## Intent

**Problem:** Twelve Epic 1 findings remain open. They leave OcuPilot with four kinds of defect:
- a quickstart that cannot write its durable directory on Linux;
- a gate that reports a revoked grant as "still installing";
- a release bundle with no npm licence notices;
- a CI that floats three tools and runs shell gates it never executes.

A few behaviours are also pinned only by source text, or not pinned at all.

**Approach:** Close each entry with the smallest change that makes its behaviour observable, pinned by a test that executes that behaviour. Owner decisions recorded on the ledger entries are binding. Anything that destroys state or needs a first install runs on a throwaway environment.

## Boundaries & Constraints

**Always:**
- **Gate states.** The gate answers one of exactly five states: `installed`, `installing`, `failed`, `upgraderequired`, `unreadable`.
  - Toward the API, `unreadable` is a 503 `unavailable` with code `INSTALL.UNREADABLE`, written through `Error.Render`.
  - Toward readiness, it is a new `state` value inside readiness's existing three keys. No field is added (AD-45).
- **Grants.** Install reads back every SQL grant it makes and fails loudly when one did not take. The schema and the tables are derived from the compiled class dictionary.
- **Copy.** New copy is added to EXPERIENCE.md's Fixed-strings table first and to `strings.ts` second, verbatim. EXPERIENCE.md wins on copy.
- **Seams** follow the house pattern:
  - an overridable class method reached by `..` dispatch, overridden in a `Test/` subclass armed through a `^||` global;
  - or an explicit argument.
- **Throwaways.** Every destructive check or first-install check runs on `scripts/ci-throwaway.sh up`/`down`, or on a uniquely named Docker volume.
- **Shells.** CI invokes each shell script with the shell its shebang declares.
- **Pins.** Every tool CI invokes is pinned exactly, and `ui/tools/ci.test.mjs` asserts each pin.

**Never:**
- Fold the grant into `StateFingerprint` (DW-60).
- Map an unreadable read to `installing`.
- Name a schema, role, table or failing step in an envelope `reason` or a readiness body.
- Run `docker compose up`, `down` or `restart` against this repository's compose file.
- Change the live `ocupilot` container, or run `REVOKE` on the live instance.
- Run a recursive `chown` over an existing durable tree, or `chmod 777` on `iris-data`.
- Relax the converse test in `ui/tools/strings.test.mjs`, or grow `REQUIRED_ALONGSIDE_TABLE`.
- Pin a runtime behaviour a ledger entry names with text alone. Text may pin wiring beside an executing test; configuration such as a tool version is text by nature.
- Add any publish, release or registry step.
- Edit `CLAUDE.md` or the spine. Those edits are the lead's (Rule 20; see Design Notes).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Grant revoked (**DW-96**) | Throwaway: `REVOKE … ON SCHEMA OcuPilot_Kernel_State FROM %DB_OCUPILOT`. Then a non-`%All` API request, and an anonymous readiness GET. | The API request gets 503 `unavailable` `INSTALL.UNREADABLE`. Readiness gets 200 `{installed:false, version:"", state:"unreadable"}`. | Never `installing`. The reason names no schema or role. |
| Read throws or returns an error (**DW-96**) | The `GateLadderRow` seam is armed to return an error status, or to throw. | `GateStatus()` is `unreadable` in both cases. | — |
| No version row yet (**DW-96**) | The read succeeds and finds no row. | `installing`, unchanged. | — |
| Grant did not take (**DW-96**) | The read-back seam reports a table not held by the role. | `Install` fails at `EnsureSqlPrivileges`, naming the table and the role. No stamp is recorded. | Failing `%Status`. |
| Repair (**DW-96**) | Throwaway after the revoke: install runs again. | The grant is restored and read back. Readiness reports `installed`. | — |
| SPA meets `INSTALL.UNREADABLE` (**DW-96**) | Any data call answers 503 `INSTALL.UNREADABLE`. | A blocking notice renders `authInstallStateUnreadable` with `role="alert"` and a Retry control. No "Signing in…" appears and no backoff timer is armed. Retry re-checks once. | — |
| `wait-readiness.sh` meets unreadable (**DW-96**, **DW-229**) | Readiness body `"state":"unreadable"`. | Exits 1 on the first poll, naming the state. | — |
| Linux-owned durable root (**DW-234**) | A volume whose root is `0:0` mode `0755`. | Before `durable-init.sh` runs, uid 51773 cannot create `/durable/iris`. After it runs, uid 51773 can. | The init exits 1 and names the directory if uid 51773 still cannot write. |
| Root already writable (**DW-234**) | A root owned by 51773 with a root-owned child, or a Docker Desktop bind mount. | Exit 0. Nothing is changed and the child keeps its owner. | — |
| Smoke sign-out (**DW-228**) | `smoke.sh` against a healthy instance. This includes a run where an API read check fails. | A `sign-out` check signs out the pair sign-in minted. Afterwards, `/refresh` with that refresh token is refused. | If the check fails, the exit is non-zero. |
| Roster refusals (**DW-207**) | The roster seam yields a relative path, no `matchRole`, or an empty asserted set. | `Install` is refused with each message naming the roster key. | Failing `%Status`. |
| Fixture namespace (**DW-213**) | `Fixture.Create("probe", …, "USER")` is called from `HSCUSTOM`. | The web application (when created), the task and the error entry are all bound to `USER`. | `Remove("probe")` cleans up. |
| Licence notices (**DW-217**) | `npm run build`. Then a throwaway `GET /ocupilot/3rdpartylicenses.txt`. | `dist/ocupilot-ui/browser/3rdpartylicenses.txt` is byte-equal to the extracted file. The GET returns 200 `text/plain`. | — |
| Broken shell syntax (**DW-229**) | A script that fails `-n` under its declared shell. | The shell test is red and names the file. | — |
| Unpinned tool (**DW-215**, **DW-218**) | A floating `markdownlint-cli2`, Python, uv, action ref or runner. | `ci.test.mjs` refuses and names it. | — |

</intent-contract>

## Code Map

**DW-96: gate, grant and schema**
- `src/OcuPilot/Install/Installer.cls`
  - `GateStatus` `:1242-1276`. Its one read is `CurrentVersionRow` `:1251`. An error `%Status` skips `:1252` and falls to `installing`. The `Catch` at `:1256` does the same.
  - `EnsureSqlPrivileges` `:2689-2705`. The literal is `tSchema` `:2694`. There is no read-back. It is called at `:803`, after `EnsureApplications` `:771` creates the web applications.
  - The `%SYS` window is `:744-796`. `AssertApplications` `:2427-2480` is the read-back-and-refuse pattern to copy.
- `src/OcuPilot/Api/Router.cls:229-242` maps each state to `Render(503, #UNAVAILABLE, reason, code)`. `src/OcuPilot/Api/Error.cls` holds `INSTALLINSTALLING` `:59`, `INSTALLUPGRADEREQUIRED` `:65` and `INSTALLFAILED` `:70`. `Test/Envelope.cls:253` checks every code parameter.
- `src/OcuPilot/Api/Readiness.cls` returns `{installed, version, state}` at `:82-91`. `VersionStamp` `:111-127` already returns `""` on a read failure.
- Tests that pin read-failure-as-`installing` and must move to `unreadable`:
  - `Test/GateLadder.cls:90-95`. Its seam `Test/GateLadderRow.cls` has `ArmReadError` `:30` and no throw arm.
  - `Test/Gate.cls` through `GateFixture` (`_fixturePhase`).
  - `Test/Readiness.cls` through `ReadinessFixture`.
- `Test/InstallerFault.cls` and `Test/InstallerThrow.cls` show the fault-subclass shape the read-back seam copies.
- `irislib/%SYSTEM/SQL/Security.cls:39` is `CheckPrivilege(Username, ObjectType, Object, Action, Namespace)`. Calling it for another name needs `%Admin_Secure:U`.

**DW-96: client and scripts**
- `ui/src/app/core/session.ts`
  - `isInstallInFlight` `:212-214` counts every `INSTALL.*` code as in flight. `ui/tools/session.test.mjs:126-127` pins that.
  - `sessionMessageKey` `:223-230` and `isWaiting` `:247-249`.
  - `noteInstallInFlight`/`enterInstalling` `:702-731` hold the backoff.
- `ui/src/app/core/fault.ts:70-72` is the `installing` → `not-installed` mapping.
- `ui/src/app/shell/instance-notice.ts:60-80` is the blocking-notice shape: `role="alert"`, `afterNextRender` focus.
- `scripts/wait-readiness.sh:51-67`: `installed` exits 0; `failed` and `upgraderequired` exit 1; anything else keeps polling.

**DW-234: durable directory**
- `docker-compose.yml` has one `iris` service. Its mount is `./iris-data:/durable` `:27`, it has no `user:` or `depends_on`, and its start hook is `:43`.
- `scripts/ci-throwaway.sh`
  - It writes its own compose file at `:119-146`; `ci.test.mjs:1158` holds its blocks equal to `docker-compose.yml`.
  - `chmod 777 "$DIR/data"` is at `:98` and `scrub_data` at `:74-78`.
- The pinned image (Ubuntu 24.04) runs as uid 51773 and ships `chown`, `stat`, `setpriv` and `su`. This was observed with `docker run --rm` on `intersystems/irishealth-community:2026.2`.
- `ui/tools/compose.test.mjs:96-98` asserts only that the mount line exists.
- `README.md:507-516` gives the throwaway's "chmod 777 before up" instruction.

**DW-217: licence notices**
- `ui/angular.json`: `outputPath` `:15`, `assets` `:21-27`.
- `ui/package.json` has a `prebuild` `:7` and no `postbuild`.
- The build extracts `ui/dist/ocupilot-ui/3rdpartylicenses.txt` next to `browser/`.
- `module.xml:55` has `<FileCopy Name="ui/dist/ocupilot-ui/browser/">`. `ui/tools/ipm-manifest.test.mjs:743-760` pins the `browser/` source.
- `src/OcuPilot/Api/StaticHandler.cls` serves any contained file and maps `txt` → `text/plain` at `:376`.
- `ATTRIBUTIONS.md:27-40` records the gap. `ui/tools/build-output.test.mjs` is where build-output assertions live.

**DW-215, DW-218: pins**
- `scripts/lint-docs.sh:29` and `.githooks/pre-commit:58` both call `npx --yes markdownlint-cli2`, unpinned.
- `.github/workflows/ci.yml`:
  - `astral-sh/setup-uv@v5` `:72` has no `with:`.
  - `uses:` refs are major tags at `:66,67,72,94,95,152`.
  - `runs-on: ubuntu-latest` at `:46,91,143`.
- `ui/tools/ci.test.mjs` holds `DECLARED_GATES` (~`:109`) and `DECLARED_USES` (`:197`).
- Local toolchain: `uv run` resolves Python 3.12.14 with uv 0.12.9. `npm view markdownlint-cli2 version` returns 0.23.2.

**DW-229: shell scripts**
- Every `scripts/*.sh` except `lint-docs.sh` declares `#!/bin/sh`, yet `ci.yml` runs them with `bash`. `lint-docs.sh` and `.githooks/pre-commit` are bash.
- Scripts spawned by tests:
  - `smoke.sh` at `ci.test.mjs:798,897`, looping over `/bin/sh`, `/bin/dash` and `/bin/bash`.
  - `ci-throwaway.sh` at `:954,1054`, with an inline stub `docker` at `:976-1002`.
- Scripts pinned as text only: `wait-readiness.sh` `:760`, `ci-image-compile.sh` `:930,1132`, `container-health.sh` (`compose.test.mjs`).
- `dash` is present locally; `shellcheck` is not.

**DW-230: flaky test**
- `ui/tools/refresh-connectivity.wire.test.mjs:273-319`:
  - `probeTimeoutMs: 5` arms a real `setTimeout` in `ApiService.arm()` (`api.ts:441-455`).
  - 8 `setImmediate` turns later, `:308` reads `signal.aborted`. That race is the failure.
- `:344-390` races a real 60 ms timer against a 5 ms `renew` timer (`api.ts:284`).

**DW-228: smoke sign-out**
- `src/OcuPilot/Install/Smoke.cls`:
  - `CheckSignIn` `:281-319` keeps the access token and drops the refresh token.
  - `CheckApiReads` `:323`.
  - `Render` `:435`.
  - Nothing calls `/logout`.
- A Bearer-only `POST /logout` ends only that sid (`Test/Token.cls:440-466`).

**DW-207, DW-213: seams**
- `Installer.cls` `RosterNames` `:288` (Private):
  - hard calls to `Roster.Application` at `:292` and `Roster.AssertedProperties` at `:321`;
  - refusals for a non-absolute path `:295-298`, no `matchRole` `:308-311`, and an empty asserted set `:322-325`;
  - its caller is `Names()` `:177`.
- `Test/InstallerProbe.AssertOneApplication` `:187` is the driver pattern for Private methods.
- `src/OcuPilot/Install/Fixture.cls`:
  - `Create(pProfile, ByRef pReports, Output pErrorEntryId)` `:118`, with `tInstallNs = tOrigNS` at `:129`.
  - `CreateWebApp`, `CreateTask` and `CreateErrorEntry` each take `pInstallNs`.
  - `Remove` `:789`.
- `Installer.CreateDemoFixtures` `:1095`.
- `Test/InstallNamespaceSource.cls:164-184` is the text pin being replaced. `Test/Demo.cls:109,130` runs `Create`/`Remove("probe")`.

**DW-126, DW-222: strings and accessibility**
- EXPERIENCE.md is at `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`:
  - Fixed strings table `:252-305` (`| String | Where |`; ` · ` separates siblings, ` / ` separates alternatives);
  - action-names row `:265`;
  - chip row `:287`;
  - State Patterns `:426-444`;
  - rail line `:64`;
  - classic-link-card `:353`.
- `ui/tools/strings.test.mjs`:
  - table parser `:48-68`;
  - `extractAreaNames` `:86`;
  - `extractServerFaultBanner` `:174`;
  - `EXTRACTED_FROM_PROSE` `:198-207`;
  - the no-overlap check `:282-287`;
  - sanity band 90-115 `:308-313`;
  - converse test `:339-354`;
  - `REQUIRED_ALONGSIDE_TABLE` `:333-337`;
  - `EXPERIENCE.md:n` references `:473-510`, which renumber when rows are inserted.
- Render sites:
  - `screen-denied.ts:27-44` reuses `privilegeRequiresResource`;
  - `status-bar.ts:58-86` has unlabeled segments;
  - `command-box.ts:135,157` has unlabeled `role="group"` elements;
  - `classic-link-card.ts:28-53` has no caption;
  - `refresh.ts:93,106` uses a per-rate literal scan, and `tools/screen-mirror.mjs:384` throws on an unpublished rate.
- `instance-notice.ts:60,62,74,119` has no spec.
- `sign-in.ts:180,185` holds the two `role="status"` elements.
- `server-flag.ts:40,54`: `[data-unbounded]`, set only at `areas/home/home.page.ts:150`.
- `app.spec.ts:463,471,477` query `[role="alert"]` without scope.
- `sign-in.spec.ts:20-78` is the TestBed template to copy.

## Tasks & Acceptance

**Execution:**
- **DW-96, server.** `src/OcuPilot/Install/Installer.cls`, `src/OcuPilot/Api/Error.cls`, `src/OcuPilot/Api/Router.cls`, `src/OcuPilot/Api/Readiness.cls`:
  - `GateStatus` answers `unreadable` when the version read returns an error status or throws, and `installing` only when the read succeeds with no row.
  - Add `INSTALLUNREADABLE = "INSTALL.UNREADABLE"` and the Router arm, with a generic reason that says waiting will not help.
  - `EnsureSqlPrivileges` derives its schema set and tables from `%Dictionary.CompiledClass`: the non-abstract persistent classes in `OcuPilot.Kernel.State`, using `SqlSchemaName` and `SqlQualifiedNameQ`.
  - It reads each table back through an overridable `SqlPrivilegeHeld(pRole, pTable, pNamespace)`, which calls `$SYSTEM.SQL.Security.CheckPrivilege(role, 1, table, "s,i,u,d", ns)`, and refuses naming the table and the role.
  - Move it before `EnsureApplications`, restoring the namespace explicitly around it (AD-16), so on the container path no web application exists before the grant.
- **DW-96, client and scripts.** `ui/src/app/core/session.ts` (+ `api.ts`/`fault.ts` as needed), the shell notice component, `scripts/wait-readiness.sh`:
  - `isInstallInFlight` excludes `INSTALL.UNREADABLE`. A sibling exported predicate classifies it into its own session state.
  - That state renders the blocking notice from the matrix, with no backoff armed.
  - `wait-readiness.sh` exits 1 on `unreadable`.
- **DW-96, tests.** `src/OcuPilot/Test/GateLadder.cls`, `GateLadderRow.cls`, `Gate.cls`, `Readiness.cls`, `Version.cls` (where it pins read-failure-as-installing), plus a read-back fault subclass:
  - move the read-failure rungs to `unreadable` and add a throw arm;
  - add the `INSTALL.UNREADABLE` wire case, including anonymous;
  - add readiness `state:"unreadable"`;
  - add a case where the read-back fails the install;
  - add a case where the derived schema equals what the dictionary reports for every `Kernel.State` class.

  Client: `session.test.mjs`, plus a component spec for the notice.
- **DW-234.** New `scripts/durable-init.sh` (`#!/bin/sh`), plus `docker-compose.yml`, `scripts/ci-throwaway.sh`, `README.md`, `ui/tools/compose.test.mjs`, `ui/tools/ci.test.mjs`:
  - The script exits 0, changing nothing, when uid 51773 can create a directory in `/durable` (checked with `setpriv`).
  - Otherwise it `chown`s the root only, re-checks, and exits 1 naming the directory on failure.
  - Add a one-shot `durable-init` service to `docker-compose.yml` (pinned image, `user: "0:0"`, the same mounts, `restart: "no"`). `iris` gains `depends_on: durable-init: condition: service_completed_successfully`.
  - The throwaway's generated compose carries the same service, held equal by `ci.test.mjs`. Its `chmod 777` is deleted, which makes CI's `instance` job the end-to-end Linux proof.
  - Add a README quickstart note, and remove the throwaway chmod instruction.
- **DW-234, reproduction.** New `scripts/ci-durable-ownership.sh`, run first in CI's `instance` job and declared in `DECLARED_GATES`:
  - On a uniquely named volume whose root is set to `0:0 0755`, require a negative control: uid 51773 cannot `mkdir /durable/iris`. If it can, exit 1 with "reproduction inert".
  - Run `durable-init.sh`, then require that uid 51773 can create the directory.
  - Check non-recursion on a second volume.
  - Remove the volumes on every exit (`trap`).
- **DW-217.** `ui/package.json` (`postbuild`), a new `ui/tools/licenses.mjs`, `ui/tools/build-output.test.mjs`, `ATTRIBUTIONS.md`:
  - `postbuild` copies `dist/ocupilot-ui/3rdpartylicenses.txt` into `dist/ocupilot-ui/browser/`. It fails if the source is absent or empty.
  - A test asserts byte equality on the real build output.
  - Replace ATTRIBUTIONS.md's "open gap" sentences with the shipped location.
- **DW-215, DW-218.** `scripts/lint-docs.sh`, `.githooks/pre-commit`, `.python-version` (new), `.github/workflows/ci.yml`, `ui/tools/ci.test.mjs`:
  - `markdownlint-cli2@0.23.2` at both call sites.
  - `.python-version` = `3.12.14`, which `uv run` resolves locally and in CI. `setup-uv` gets `version: "0.12.9"`.
  - Every `uses:` is pinned to the full commit SHA its current tag resolves to, looked up with `gh api` at implementation, with the tag in a trailing comment.
  - `runs-on: ubuntu-24.04`.
  - `ci.test.mjs` asserts each pin exactly, and that both markdownlint call sites agree.
- **DW-229.** New `ui/tools/shell-scripts.test.mjs`, a new `ui/tools/stub-bin.mjs` helper (extracted from `ci.test.mjs:976-1002`), `ci.yml`, `ci.test.mjs`:
  - Every `scripts/*.sh` and `.githooks/*` must declare `sh` or `bash`, and must pass `-n` under that shell. `#!/bin/sh` files also run under `/bin/dash` where present.
  - `ci.yml` invokes each script with its declared shell; `ci.test.mjs` holds the two equal.
  - Add executing pins, run under `/bin/sh` and `/bin/dash`, for:
    - `wait-readiness.sh` (every state, the timeout, exit 2 on bad arguments);
    - `ci-image-compile.sh` (`version=2` → 0, anything else → 1);
    - `container-health.sh`, with a stub `iris` and marker paths overridable through environment variables that default to today's paths.
- **DW-230.** `ui/tools/refresh-connectivity.wire.test.mjs`:
  - Record `signal.aborted` inside the fake `fetch` at call time. Drive both abort cases without racing real timers, using `node:test` mock timers or call-time capture; no production change unless a test cannot be made deterministic without one.
  - Sweep `ui/tools/*.test.mjs` for a real timer of 50 ms or less raced against an assertion. Fix each one and list them in `## Auto Run Result`.
- **DW-228.** `src/OcuPilot/Install/Smoke.cls`, `src/OcuPilot/Test/Smoke.cls`:
  - Keep the refresh token.
  - A `sign-out` check always runs after the API read checks. It sends a Bearer `POST /logout`, then confirms `/refresh` with the minted refresh token is refused.
  - A refresh that unexpectedly succeeds is signed out too before the check fails.
  - The report counts it.
- **DW-207.** `Installer.cls`, plus a new `src/OcuPilot/Test/RosterFault.cls` (extends `InstallerProbe`) with a test class:
  - `RosterNames` reaches the roster through overridable `RosterApplication`/`RosterAssertedProperties`.
  - The fault subclass arms a relative path, a missing `matchRole` and an empty asserted set.
  - A driver calls `Names()`. Each refusal is asserted by message.
- **DW-213.** `Fixture.cls`, `Installer.CreateDemoFixtures`, `Test/InstallNamespaceSource.cls` (or a new test class):
  - `Create` gains `pNamespace` (`""` means the caller's `$NAMESPACE`) and binds every object to it.
  - `CreateDemoFixtures` passes the namespace it installs into.
  - Delete the source-text test.
  - The new test calls `Create("probe", …, "USER")` from `HSCUSTOM`, asserts every binding it created is `USER`, and removes the fixture in teardown.
- **DW-126.**
  - EXPERIENCE.md: the rows listed in Design Notes, plus a State Patterns row "Install state unreadable".
  - `ui/src/app/core/strings.ts`: the matching keys, with renumbered `EXPERIENCE.md:n` references.
  - `ui/tools/strings.test.mjs`:
    - retire `extractAreaNames` as a source;
    - stop the server-fault extractor supplying Retry and Open messages.log;
    - move the sanity band to the new count with the same margin.
  - Render sites: `screen-denied.ts`, `status-bar.ts` (accessible names), `command-box.ts` (group `aria-label`s), `classic-link-card.ts`, `refresh.ts` + `tools/screen-mirror.mjs` (`<n>` substitution replaces the per-rate literal and the throw).
  - Update their specs.
- **DW-222.**
  - New `ui/src/app/shell/instance-notice.spec.ts`: `role="alert"`, focus on the section via `document.activeElement`, and one `h1` per variant.
  - `sign-in.spec.ts`: both `role="status"` banners.
  - Assert on the server flag that `data-unbounded` is present exactly when `[unbounded]` is true.
  - `app.spec.ts`: scope the `[role="alert"]` queries to the fault banner.

**Acceptance Criteria:**
- **Integration AC (Rule 1).**
  - Given the throwaway, `durable-init` and `ci-durable-ownership.sh` on CI's Linux `instance` job, when the job runs, then:
    - the reproduction's negative control fails;
    - the init makes the volume writable;
    - the throwaway, now without `chmod 777`, reports healthy with readiness `installed`.
  - Given `durable-init.sh` made a no-op, when `ci-durable-ownership.sh` runs on this macOS machine, then it exits 1.
- **Integration AC (Rule 1).** Given a throwaway whose grant was revoked, when `scripts/wait-readiness.sh` polls readiness, then it exits 1 on its first poll naming `unreadable`. And given the SPA loads against that instance, then it shows the unreadable notice and never "Signing in…".
- Given a clean build, when `module.xml`'s `FileCopy` or the container start path installs the bundle, then `3rdpartylicenses.txt` is served from the shell's root as `text/plain` (**DW-217**).
- Given the committed tree, when `npm test` runs, then:
  - every shell script passes `-n` under its declared shell;
  - the four scripts' executing pins pass under `sh` and `dash`;
  - every CI tool pin is asserted (**DW-215, DW-218, DW-229**).
- Given 8 busy CPU loops, when `refresh-connectivity.wire.test.mjs` runs 50 times in a row, then all 50 pass (**DW-230**).
- Given the lead's per-story smoke, when `scripts/smoke.sh --container ocupilot --user _SYSTEM --password SYS` runs against the live instance, then it exits 0 with `sign-out` passed, and the minted refresh token is refused afterwards (**DW-228**).
- Given the committed EXPERIENCE.md and `strings.ts`, when `strings.test.mjs` runs, then forward and converse equality hold with no new prose extractor and `REQUIRED_ALONGSIDE_TABLE` still at length 3. Every string in Design Notes appears verbatim in both files (**DW-126**).
- Given each behaviour DW-207, DW-213 and DW-222 name, when its test's subject is mutated, then the test goes red, and no assertion in it reads source text.

- [x] [CI] `instance` job, run 34793616419: `GrantReadBack.TestAGrantThatDidNotTakeFailsTheInstall` fails with "precondition: no probe web application exists before the install" when it runs after the fifteen classes before it, and passes 3/3 alone. Reproduced deterministically on a throwaway by running CI's first sixteen classes in order: `/api/probeocupilot/readiness` is left behind. Bisect those fifteen to the leaking class and fix its cleanup to remove every roster application for the probe profile rather than a literal list — `GatewayGapIpmPath` defines `PROBEREADINESS` and is the first suspect, unconfirmed. Do not weaken `GrantReadBack`'s precondition; it caught a real leak. Pin the fix with something that fails when a probe application survives a class's teardown, and demonstrate that red by reintroducing the leak. Sweep every other probe-installing test class for the same literal-list cleanup and fix each one found. Name the confirmed leaking class in `## Auto Run Result`. (DW-242)
- [x] [CI] `ui/tools/ci-runner.mjs` reports a failing class but not the failing method or its assertion message, so this red run named no cause. For every failed method, print the method name and each failed assertion's description and message, read from `%UnitTest_Result` or `^UnitTest.Result` by the run's own numeric index (never `MAX(ID)`). Pin the output shape in `ui/tools/ci.test.mjs` or the runner's own test. (DW-243)

### Review Findings

Code review 2026-09-13 (full-opus: Blind Hunter, Edge Case Hunter, Verification Gap, Acceptance Auditor). 51 rows, 17 entries after grouping.

- [x] [Review][Patch] **High, Rule 3.** The DW-96 chain had no real-runtime test: the notice, the revoke and repair rows and Retry's re-check were hand-run only [ui/browser/unreadable.browser-spec.mjs:174] — the new spec revokes the grant on the throwaway for a non-`%All` principal, asserts readiness, the 503 envelope, `wait-readiness.sh` and the SPA (notice, focus, no "Signing in", no traffic for 4 s, one `/instance` per Retry), then repairs. `test:browser` now runs one file at a time; `angular-json.test.mjs` guards every spec's port and container.
- [x] [Review][Patch] **Med, DW-238.** Actions pinned to node20 releases [.github/workflows/ci.yml:71] — re-pinned to checkout v5, setup-node v5, setup-uv v7 (SHAs and `using: node24` read through `gh api`).
- [x] [Review][Patch] **Med, Rule 19.** `CheckSignOut`'s 401 rule and accepted-refresh sign-out had no pinning test [src/OcuPilot/Install/Smoke.cls:380] — `Test/SmokeRefreshFault.cls` and two `Test.Smoke` methods.
- [x] [Review][Patch] Gate docs left at four states or `INSTALL.INSTALLING`, and "health and readiness cannot disagree" is false under a revoke [README.md:252, README.md:407, README.md:412, scripts/container-health.sh:7, src/OcuPilot/Kernel/State/Version.cls:29].
- [x] [Review][Patch] A stale backoff timer cleared a newer chain's `backoffArmed`, so a refresh could arm a second chain [ui/src/app/core/session.ts:796].
- [x] [Review][Patch] Two "never Signing in" assertions could not fail [ui/src/app/app.spec.ts, ui/src/app/shell/instance-notice.spec.ts:125] — removed; the browser spec holds the falsifiable form.
- [x] [Review][Patch] Rule 19: no `mutation:` line for the absent-row and throw rungs of `GateLadder` — recorded under Verification.
- [x] [Review][Patch] Stale comments: the filter label is now published [ui/src/app/shell/command-bar.ts:67]; the notice's EXPERIENCE.md citations and its "no new string" claim [ui/src/app/shell/instance-notice.ts:22]; the inventory-namespace comment [src/OcuPilot/Install/Fixture.cls:161].
- [x] [Review][Patch] The licence spec claimed to prove `module.xml`'s `FileCopy` and said "next to `browser/`"; the config header said "the one spec" [ui/browser/licence.browser-spec.mjs:16, ui/browser.config.mjs].
- [x] [Review][Defer] Two frontmatter deferred items never reached the ledger — filed as DW-239 (restart-recompile 500) and DW-240 (stale `:n` citations), both `wontfix-accepted` with `reopen_if`.
- [x] [Review][Defer] Lead edit 8814be5: new Stack rows sit under a "verified 2026-09-09" header — DW-241, `wontfix-accepted`.
- [x] [Review][Defer] DW-237 (client backs off on `INSTALL.FAILED`/`UPGRADEREQUIRED`) — decided `wontfix-accepted` by=cr: on the container path both clear by restart or install, so backoff is right; a terminal notice would strand a recovering tab.
- [x] [Review][Defer] By design: any failed version read is `unreadable`, including a transient one mid-recompile — the matrix row and AD-38 require it; reopen through a spec amendment if `unreadable` is observed during a restart.
- [x] [Review][Defer] By design: `durable-init.sh` checks only the root, not an existing `/durable/iris` (matrix row "Root already writable"); `StateTables` selects by package (the task names the package).

Rejected:
- `false` CLAUDE.md's `bash scripts/smoke.sh` runs an untested shell — `ci.test.mjs:910` executes `smoke.sh` under `/bin/bash`.
- `false` "Four scripts under sh and dash" — the fourth is `smoke.sh` (`ci.test.mjs:910`).
- `false` The untracked QA spec is a defect — the lead commits it after the smoke.
- `false` Smoke's Bearer-only logout violates AD-28 — AD-28 governs the client's Sign out; the smoke holds no browser-id cookie.
- `false` `CheckPrivilege` answering 1 for a missing table defeats read-back — the grant is schema-level and the table set is pinned by `TestDerivedTablesEqualTheDictionary`.
- `false` A quoted `SqlQualifiedNameQ` breaks read-back — no state table needs quoting, and one would fail install loudly.
- `false` A downgrade reading `installing` strands `wait-readiness.sh` — pre-existing and recorded in Design Notes.
- `low` `ProbeStampCount` returns -1 on a failed query — the suite runs as `%All`; the fix is a guard.
- `low` A renewal failing while the notice shows returns to "Signing in" — it recovers to the notice on the next data call (earlier triage).
- `low` `FixtureNamespace`'s web-app branch is skipped where the demo owns `/csp/myapp` — the matrix makes it conditional; it executed on the dev instance.
- `low` Smoke login answering 200 without a refresh token leaves a session — the token endpoint always returns both.
- `low` `ci-durable-ownership.sh` setup calls exit under `set -e` without their own message — docker's stderr names the cause.
- `low` The licence spec skips the readiness precondition and spells "licence" — it fails loudly either way; no rule covers `.mjs` names.
- `low` `durable-init` mounts fewer paths than `iris` — recorded deviation, least privilege.
- `low` Integration AC #1's Linux half has not run in CI — CI after the lead's push is that gate; red CI re-opens the story.

## Spec Change Log

## Review Triage Log

### 2026-09-13 — Review pass
- verdicts: 60 findings — high 0, medium 12, low 33, false 11, maybe-false 4
- findings:
  - `[maybe-false]` `[reject]` Any failed version read answers `unreadable`, including a transient one mid-recompile — the matrix row "Read throws or returns an error" and AD-38 require it; restart polls on the throwaway saw 000/500/installed and no `unreadable`; settle by polling readiness through many restarts.
  - `[false]` `SqlPrivilegeHeld` reports "could not check" as "not held" — `EnsureDatabaseResource`, `EnsureAdminRole` and the other steps before it already need `%Admin_Secure:U`, and the namespace passed is the install namespace.
  - `[false]` A quoted table name may not match in the read-back — no current table needs quoting; a future one fails install loudly.
  - `[low]` `[patch]` Stale mutation comment in `GateLadder.TestInstalledAtTheDeployedVersionServes` — now names `unreadable` at 0 and `TestReadErrorRefusesAsUnreadable`.
  - `[medium]` `[patch]` The demo-fixture namespace hand-off in `StartPathLocked` is unpinned — `InstallerProbe` records it; `DemoOptIn` asserts it equals the install namespace (mutation recorded).
  - `[medium]` `[patch]` The `app.ts` `installUnreadable` branch has no test — new `app.spec.ts` case (mutation recorded).
  - `[low]` `[reject]` A probe or renewal already in flight can move the tab off the notice — needs a token failure while the notice shows; that failure's own state is correct and the next data call returns to the notice; the fix adds guards.
  - `[medium]` `[defer]` A widened grant (another role holding the schema) is not detected — pre-existing; the owner decision on DW-96 scoped the fix to the unreadable state.
  - `[low]` `[defer]` Stale `EXPERIENCE.md :n` citations outside `strings.ts`, e.g. `strings.mjs:57` — already carried by the implement pass's deferred item.
  - `[low]` `[patch]` `smoke.sh`'s usage header says `bash` — now `sh`.
  - `[false]` "Every tool is pinned exactly" overstates — the spec defines the pin set; `ubuntu-24.04` is the finest runner pin offered and the image tag is AD-27's rule.
  - `[maybe-false]` `[defer]` The pinned `v4`/`v5` action SHAs run on Node 20 — pre-existing majors; settle by checking GitHub's Node 20 runner removal date.
  - `[low]` `[reject]` The unhashed licence file is served immutable and was not deferred — accepted in Design Notes (DW-217).
  - `[low]` `[patch]` A failing `chown` in `durable-init.sh` exits before naming the directory, and no test runs the exit-1 path — `chown` failure now falls through to the named message; `ci-durable-ownership.sh` runs it over a read-only mount.
  - `[low]` `[patch]` The ownership negative control accepts any failure — it now requires `Permission denied`.
  - `[low]` `[reject]` `OCUPILOT_START_MARKER_FILE` is read by the health hook only — a test-only override no container environment sets.
  - `[low]` `[reject]` `FixtureNamespace` checks the app only when created and the task through its refusal — the matrix makes the app conditional; the error-entry binding's mutation is recorded.
  - `[false]` Shell tests pass with no interpreter — `/bin/sh` exists on macOS and every Linux runner.
  - `[false]` The downgrade comment contradicts the `unreadable` rationale — Design Notes record that decision; a refused downgrade clears when the deployment catches up.
  - `[low]` `[reject]` `Installer.Phase()` has no production caller yet was extended — keeping it equal to `GateStatus` avoids a second fail-open answer; removal is outside this story.
  - `[low]` `[reject]` A failed logout leaves the smoke session live — the run already fails; a broken logout cannot be used to sign out.
  - `[low]` `[patch]` The `Install` comment names the wrong grantee for the probe profile — now names `Base.DBRESOURCE` for every profile.
  - `[low]` `[reject]` Edited comments not re-wrapped — cosmetic; no lint rule.
  - `[low]` `[reject]` A `/refresh` or `/login` started before the notice settles after it — same root cause and reason as the in-flight probe row.
  - `[false]` The read-back reports "not held" without `%Admin_Secure:U` — same refutation as the earlier `SqlPrivilegeHeld` row.
  - `[maybe-false]` `[reject]` A transient read error answers `unreadable` — same as the first row.
  - `[medium]` `[patch]` `CheckSignOut` passes on any non-200 refresh — now requires the 401 a dead refresh token gets (`Test/Token.cls:403`).
  - `[medium]` `[defer]` The client keeps `INSTALL.FAILED` and `INSTALL.UPGRADEREQUIRED` in the install backoff forever — pre-existing since Story 1.13.
  - `[low]` `[patch]` A leftover `.ocupilot-durable-init.$$` probe directory blocks every later run — the probe is now `mktemp -d`.
  - `[low]` `[reject]` `postbuild` fails a development-configuration `npm run build` — the spec task requires it to fail when the extracted file is absent.
  - `[low]` `[reject]` The health and start hooks can disagree on the marker path — same as the earlier marker row.
  - `[low]` `[reject]` A refused renewal while the notice shows sets `probing` — same root cause as the in-flight probe row.
  - `[low]` `[patch]` The `Install` comment claims no request can reach the gate before the grant on every start — now says on a first install.
  - `[medium]` `[patch]` SPA half of the Integration AC unpinned — same patch as the `app.ts` branch row.
  - `[medium]` `[patch]` `TestNoCredentialsSkipsRatherThanPasses` cannot fail on the sign-out skip — now asserts each skipped line (mutation recorded).
  - `[low]` `[reject]` `TestSignOutRunsWhenAReadFails` never raises from the reads — `Request` catches its own errors, so a raise is not a demonstrated path; the noted read failure the matrix names is pinned (mutation recorded).
  - `[low]` `[reject]` The accepted-refresh cleanup is never run by a test — reachable only when logout itself is broken; the fix needs a request-stubbing fault class.
  - `[low]` `[patch]` Rule 19: no `mutation:` line for the SPA half — recorded.
  - `[low]` `[patch]` Rule 19: no `mutation:` line for DW-228's failed-read run — recorded.
  - `[low]` `[patch]` Rule 19: no `mutation:` line for DW-234 non-recursion — recorded.
  - `[low]` `[patch]` Rule 19: no `mutation:` line for DW-126 string equality — recorded.
  - `[medium]` `[patch]` DW-217's `text/plain` serving had no executing pin — `Static.TestLicenceNoticesAreServedAsPlainText` (mutation recorded).
  - `[medium]` `[patch]` `CheckSignOut` accepts any non-200 refresh — same patch as the 401 row.
  - `[low]` `[reject]` A failed renewal while unreadable can arm a backoff — same root cause as the in-flight probe row.
  - `[low]` `[patch]` `api.test.mjs`'s "same table, both ways" invariant is false for `INSTALL.UNREADABLE` — row added, invariant covers both predicates (mutation recorded).
  - `[low]` `[reject]` The REVOKE-to-gate chain is only checked by hand — the spec keeps REVOKE off the live instance; each OcuPilot link is pinned and the chain was re-observed on a throwaway this pass.
  - `[low]` `[reject]` Repair has no committed test — same reason; re-observed on a throwaway this pass.
  - `[medium]` `[patch]` The whole tab, not just the notice, must avoid "Signing in…" — same patch as the `app.ts` branch row; one identity pass on Retry observed in the browser.
  - `[false]` `ApiService` still classifies `INSTALL.UNREADABLE` as `installing` — an internal kind; the session state is `install-unreadable` and the browser showed no retry traffic over 12 s.
  - `[maybe-false]` `[reject]` Any read error becomes `unreadable` — same as the first row.
  - `[low]` `[reject]` The health check may read `installed` under a revoke — health's AD-38 contract is this start's install success; the intent names no health change.
  - `[low]` `[patch]` `durable-init.sh`'s exit-1 path is never executed — same patch as the `chown` row.
  - `[low]` `[reject]` Smoke raises and `smoke.sh`'s exit on a failed sign-out are untested — raise as above; the exit mapping is pinned by `TestOneFailedCheckFailsTheRun`.
  - `[false]` Roster refusals are driven through `Names()`, not `Install` — the spec task names that driver, and `Install` calls `Names()`.
  - `[medium]` `[patch]` Fixture namespace: the `StartPath` hand-off is uncaptured — same patch as the hand-off row; the task refusal is IRIS `ERROR #7414`.
  - `[medium]` `[patch]` No committed check fetches the licence file — same patch as the `text/plain` row.
  - `[false]` Images by tag and a rolling runner label — same refutation as the pins row.
  - `[low]` `[reject]` `SmokeReadFault` is not `^||`-armed and shell overrides are environment variables — a dedicated always-faulting subclass and shell scripts have no class-method seam.
  - `[false]` Tests install and create fixtures on the live instance — the spec's Verification lists `%UnitTest` classes as live-safe, and `Installer`/`Version` already run the same installs.
  - `[false]` DW-126 publishes copy with no render site, drops the rate refusal and retires the rail extractor — the spec's Tasks and Design Notes direct each.

### 2026-09-13 — Review pass (rework 1, CI items)
- verdicts: 34 findings — high 0, medium 9, low 17, false 8, maybe-false 0
- findings:
  - `[medium]` `[patch]` A raising `OnAfterAllTests` prints under `ok` and exits 0 — `classifyFailureDetail` fails a class with a class-level entry (executed test, mutation recorded).
  - `[low]` `[patch]` `ProbeApps.Remove` deletes the provenance row after a failed application delete — the row goes only once the application is gone; a failed removal is returned.
  - `[low]` `[reject]` `Existing()` skips an unreadable roster key or a status-only `Exists` failure — install refuses both roster shapes, so no such application can exist; the fix adds guards.
  - `[medium]` `[patch]` The leak check blames every later class for one leak — the session prints a before-run answer; added paths are `LEAKED`, pre-existing ones `INHERITED` (still red), executed test and mutation recorded.
  - `[low]` `[patch]` An unknown leak answer on a passing class prints no session tail — the tail now prints for any non-`ok` outcome.
  - `[low]` `[reject]` Suite-level failures are not in the detail — the class is already failed (`EMPTY`/refused) with its session tail; not a failed method.
  - `[low]` `[reject]` The run index is the highest after `RunTest` — pre-existing, guarded by `tLanded` and `nonConsecutiveRuns`, and the suite is one run in flight.
  - `[false]` The spec records none of the rework — `## Auto Run Result` is written at finalize.
  - `[low]` `[patch]` `GatewayGapIpmPath`'s header narrates the leak — reduced to the caller contract.
  - `[low]` `[reject]` `InstallLock` has no teardown — its failure path already fails it and the runner now attributes the leftover; a teardown taking the install lock in the class that JOBs lock holders risks a new refusal.
  - `[medium]` `[patch]` Nothing tests `ProbeApps` against an independent source — `Provenance.TestTheLeftoverCheckSeesEveryRecordedProbeApplication` compares `Existing()` with install's own rows and removes a row-orphaned application (mutation recorded).
  - `[low]` `[reject]` The gate checks only roster applications — the intent scopes the pin to roster applications; no other leftover was observed in the full run.
  - `[low]` `[patch]` The summary line omits leaks — it now counts classes with probe leftovers.
  - `[low]` `[reject]` `CleanProbe` and `ProbeApplications` are one-line forwarders — they keep existing call sites; the doc is accurate.
  - `[false]` `ProbeApps` bypasses `SwitchNamespace` (AD-16) — AD-16's Rule is exactly the explicit save, set and restore-first-in-`Catch` form used.
  - `[medium]` `[patch]` A class-level failure leaves the job green — same patch as the `OnAfterAllTests` row.
  - `[low]` `[reject]` A `<LIST>` or `<MAXSTRING>` mid-walk writes a partial array — nodes are framework-written, and the count check now fails a detail that disagrees with the run.
  - `[low]` `[reject]` Suite-level refusal prints no cause — same as the suite-level row.
  - `[low]` `[patch]` Row deleted after a failed delete — same patch as the `Remove` row.
  - `[medium]` `[patch]` No before snapshot — same patch as the blame row.
  - `[false]` The leaking class is not named — named at finalize.
  - `[false]` No reintroduced-leak red — observed on the throwaway; mutation lines recorded.
  - `[low]` `[reject]` Highest run index — same as the run-index row.
  - `[medium]` `[patch]` The `FAILS` producer is never executed and a missing or wrong marker is accepted — a landed run with no readable detail, or a method count unequal to the run's, fails the class (executed tests; producer mutation observed on the throwaway).
  - `[medium]` `[patch]` `Existing()` is only asserted empty — same patch as the independent-source row.
  - `[false]` Leaking class never named — named at finalize.
  - `[false]` Red simulated only — reproduced on the throwaway (mutation lines).
  - `[medium]` `[patch]` ObjectScript half has no committed test — same patch as the independent-source row.
  - `[low]` `[reject]` Sweep matches neither reading — same as the `InstallLock` row; uninstall-only classes delete no rows.
  - `[low]` `[reject]` Prefix versus roster coverage — same as the roster-only row.
  - `[false]` The method's error is suppressed when its action is empty — that text is the framework's fixed "There are failed TestAsserts", observed in run 60.
  - `[low]` `[reject]` Run index reading G1 — same as the run-index row.
  - `[medium]` `[patch]` Only the printed shape is pinned — same patch as the producer row.
  - `[false]` The spec's task text was rewritten — the stage agent carried the lead's rework instructions outside `<intent-contract>`.

## Design Notes

**Why a fifth gate state (DW-96).**
- An earlier review chose `installing` for a stored version ahead of the code. That reuse was sound because every consumer's correct action was the same: keep polling.
- `unreadable` needs the opposite action. A revoked grant never clears by itself, so the session backoff, `wait-readiness.sh` and a reader of the envelope would each wait forever with the cause thrown away.
- A consumer can only choose the right action if the code differs, so a new code is required.
- The `INSTALL.` prefix is kept on purpose. A client that knows only "`INSTALL.*` means not serving" still refuses to serve. The updated client tells the two apart.
- **Readiness (AD-45).** `state` already answers "is install running", so `unreadable` adds a value, not a field. It also discloses less than `failed` already does.
- **Code (AD-39).** A stable machine code in the one envelope.

**What the gate cannot tell apart.**
- A read before the grant exists fails exactly like a read after a revoke.
- Moving `EnsureSqlPrivileges` ahead of `EnsureApplications` closes that window on the container path and the `Install()` path.
- On a first IPM install, IPM activates the applications before `<Invoke>`. Until the grant exists, the gate answers `unreadable`. This is accepted on AD-38's IPM-window ground (inference).
- The client's Retry and IPM's own completion clear the state.

**How grant read-back was established.** Probe, 2026-09-13, `ocupilot-iris`/HSCUSTOM, read-only:
- `CheckPrivilege("%DB_OCUPILOT", 1, "OcuPilot_Kernel_State.<T>", "s,i,u,d")` returned 1 for Version, Stamp, WebApp and Demo.
- `%Operator` returned 0.
- The schema-level form, type 5, returned 0 although the grant is in place, so it is not usable for read-back.
- Grants surviving a class recompile is an inference from `RSQL_droptable`: even `DROP TABLE` keeps object privileges. The throwaway restart check verifies it.

**DW-234.** A bind mount keeps the host's ownership, and Docker Desktop hides that. A named volume lives in Docker Desktop's Linux VM, so its ownership is real Linux ownership; the negative control proves the reproduction is live on this machine. CI's `instance` job is the end-to-end proof, because the throwaway loses its `chmod 777`.

**DW-217.** `postbuild` is used rather than `assets` or `outputPath`:
- `assets` copies workspace sources, not files the build generates.
- Setting `outputPath.browser: ""` would move the served root that `module.xml`, the roster, `container-start.sh` and `ipm-manifest.test.mjs` all name.
- The licence file is unhashed, so its immutable cache header can go stale across upgrades (accepted, LOW).

**DW-213 sweep.** The patterns searched were `GetTextAsString`, `%Dictionary.*` method and definition reads, `.Implementation`, `$Find(` over class text, and file reads in `src/OcuPilot/Test/`. Two tests pin production code this way:
1. `InstallNamespaceSource.TestFixtureCreateUsesTheCallersNamespaceNotTheResolvedDefault` is replaced here.
2. `UnexpireScope.TestInstallsArgumentContractMakesTheZeroArgumentInvokeSafe` (`:35-56`) reads `%Dictionary.CompiledMethod.FormalSpec`. It is kept. Its behavioural equivalent is a zero-argument production `Install()`, which can only run on a throwaway, and CI's `instance` job compiles from the committed tree.

Also found:
- Five uses of the same APIs that do not pin production code: `AdminInventory` ×3, `Manifest`, `Envelope`.
- Two repo-file text pins in `ui/tools/compose.test.mjs` (`:405`, `:468`) over `Installer.cls`.

One gap is left open: if the `pNamespace` default (`""` → `$NAMESPACE`) is broken, no test sees it on an instance with a single install. Production passes the namespace explicitly.

**DW-228.** The throwaway-only line in Story 1.17 is superseded: the per-story smoke gate runs `smoke.sh` against the live instance. That line lived in 1.17's `## Verification`, which commit `98e1cb3` removed from the file, so no origin sentence remains to replace. A Bearer-only logout is correct for the smoke: it carries no browser-id cookie, and per-sid logout is pinned by `Test/Token.cls:440-466`. AD-28's "always both" rule governs the SPA's Sign out.

**Strings added (DW-126).** Listed as key = literal, followed by the table's Where cell and the render site.

- **Area names** (existing keys `navArea*`): `"Home" · "Logs" · "OS management" · "Tasks" · "Permissions" · "Web applications and REST API explorer" · "Security and secrets" · "Agent co-pilot"`.
  - Where: area names on the rail, the rail-item tooltip, the side-bar landmark, the locator-bar eyebrow and the area tiles.
  - Render: already rendered.
- `privilegeDeniedScreen` = "You need <resource> to open <screen>."
  - Where: permission-denied screen.
  - Render: `screen-denied.ts`.
- `privilegeDeniedAction` = "You need <resource> to <action>."
  - Where: request-refused inline message (403).
  - Render: published; its first consumer is the first write action.
- `statusSegmentServer` · `statusSegmentInstance` · `statusSegmentLicensedTo` = "Server" · "Instance" · "Licensed to".
  - Where: accessible names of the status-bar segments.
  - Render: `status-bar.ts`.
- `commandBarFilterLabel` = "Filter rows".
  - Where: command-bar filter field label.
  - Render: published; Story 2.4 renders it (DW-141).
- `commandBoxGroupScreens` · `commandBoxGroupActions` = "Screens" · "Actions".
  - Where: command-box result-group labels.
  - Render: `command-box.ts`.
- `faultAbsentEntity` = "<name> is no longer present on this instance. Return to the list to see what is there now."
  - Where: a detail view whose target no longer resolves (AD-37).
  - Render: published; the first Epic 2 detail route.
- `authSignInUnreachable` = "Sign-in couldn't reach the instance. Check that IRIS is running, then sign in again."
  - Where: Form login, when a submit meets an unreachable instance.
  - Render: published.
- `navPrivilegeMapUnread` = "Your privileges couldn't be read, so screens you can't open may be listed. Retry to check again."
  - Where: shell, after a failed privilege-map read.
  - Render: published.
- `actionRetry` · `actionOpenMessagesLog` (existing) are appended to the action-names row.
- `statusAutoRefreshOn` changes to "Auto-refresh: every <n> s".
  - Render: `refresh.ts`.
- `classicLinkCardCaption` = "The classic portal may ask you to sign in again."
  - Where: classic-link-card caption (OQ15).
  - Render: `classic-link-card.ts`.
- `authInstallStateUnreadable` = "OcuPilot can't read its own state on this instance, so waiting won't help. An administrator needs to run the install again."
  - Where: install-state-unreadable notice.
  - Render: the DW-96 notice.

Values must stay unique, which the converse count relies on.

**Governing ADs:**
- AD-9, AD-16 and AD-17 (the installer).
- AD-12 and AD-39 (the envelope).
- AD-19 (`core/` stays framework-free).
- AD-21 (the derived schema name is concatenated, but no caller supplies it).
- AD-25 (fixtures).
- AD-27 (pinned image).
- AD-28 (logout).
- AD-38 and AD-45 (gate and readiness).
- AD-47 (the served root carries no user content).
- Conventions: IRIS security objects (read a grant back before believing it), Tests, Client asset homes.
- Stack: CI.

**Spine and agent-context edits for the lead (Rule 20):**
- AD-38's Rule lists the refusal responses; add `unreadable` and the IPM first-install window.
- The Stack rows for CI and for Python/uv/markdownlint pins.
- CLAUDE.md's Container section should name the `durable-init` service.

**Consumed-by:**
- Story 2.1 reads `GateStatus` on every AdminPort request (DW-60).
- Epic 17's clean-clone run uses the compose quickstart (`durable-init`) and `smoke.sh`.
- Story 2.4 renders `commandBarFilterLabel`.

**Consumes:**
- Story 1.17: readiness, `smoke.sh`, `ci-throwaway.sh`, `ci.yml`.
- Story 1.13: the fault taxonomy and the session backoff.
- Story 1.16: the roster.
- Story 1.4: the start hook.

**Ledger:** all twelve entries are addressed; none is declined.

## Verification

**Where each check runs.**
- Safe on the live `ocupilot` container (every IRIS MCP call passes `server: "ocupilot-iris"`):
  - compiling into `HSCUSTOM`;
  - `%UnitTest` classes;
  - read-only SQL;
  - the live smoke.
- On a throwaway (`bash scripts/ci-throwaway.sh up` … `down`), never live:
  - the revoke and repair;
  - restarting a container;
  - a first install;
  - the licence GET.
- **Test-runner discipline:** one test class per tool call, awaited. Never two in one message, and never re-submitted after a client timeout; read `%UnitTest_Result` with the numeric-run-index probe instead.

**Commands:**
- `cd ui && npm run build` — expected: prebuild gates green, and `dist/ocupilot-ui/browser/3rdpartylicenses.txt` present.
- `cd ui && npm test` — expected: green, including `shell-scripts.test.mjs`, `ci.test.mjs`, `strings.test.mjs` and the new component specs.
- `uv run scripts/check-objectscript.py && uv run scripts/test_check_objectscript.py && bash scripts/lint-docs.sh` — expected: green, with uv on Python 3.12.14.
- `sh scripts/ci-durable-ownership.sh --image intersystems/irishealth-community:2026.2` — expected: negative control observed, then exit 0, with no volume left.
- `cd ui && for i in $(seq 50); do node --test tools/refresh-connectivity.wire.test.mjs || exit 1; done` under 8 busy `node -e 'for(;;){}'` loops — expected: 50/50.
- ObjectScript, one class per call:
  - `OcuPilot.Test.GateLadder`, `Gate`, `Readiness`, `Version`, `Envelope`, `Smoke`, `Demo`;
  - the read-back, roster and fixture-namespace classes.
- Throwaway:
  1. Revoke the grant through `docker exec ocupilot-ci iris session`. Anonymous readiness returns `unreadable`. A request as a purpose-built non-`%All` user created on the throwaway returns 503 `INSTALL.UNREADABLE`. `wait-readiness.sh --url http://localhost:52776/api/ocupilot/readiness/` exits 1.
  2. Run the install again. Readiness returns `installed`.
  3. `docker restart ocupilot-ci`. Poll readiness through the restart: never `unreadable`, and the grant is still held after recompile.
  4. `curl -i http://localhost:52776/ocupilot/3rdpartylicenses.txt` returns 200 `text/plain`.
  5. `smoke.sh --container ocupilot-ci` exits 0 with `sign-out` passed.
- `durable-init.sh` over a `/tmp` scratch bind mount on Docker Desktop (`docker run --rm --user 0:0`) — expected: exit 0, so the owner's next compose `up` is safe.
- Live: `sh scripts/smoke.sh --container ocupilot --user _SYSTEM --password SYS` — expected: exit 0 with `sign-out` passed.

**Planned mutations (Rule 19; record `mutation:` lines as the pins land):**

- The read-failure arm returns `installing` → `GateLadder` goes red.
- The read-back loop is removed → the read-back fault test goes red.
- `durable-init.sh` does nothing → `ci-durable-ownership.sh` goes red.
- `postbuild` is deleted → `build-output.test.mjs` goes red.
- The logout call is removed → `sign-out` fails.
- A `RosterNames` refusal is deleted → `RosterFault` goes red.
- `Create` ignores `pNamespace` → the fixture-namespace test goes red.
- `role="alert"` is deleted → `instance-notice.spec.ts` goes red.
- A floating `@v4` or `markdownlint-cli2` without a version → `ci.test.mjs` goes red.
- A missing `fi` → `shell-scripts.test.mjs` goes red.
- The post-settle `aborted` read comes back with a 1 ms deadline → the DW-230 test goes red.

**Observed mutations (each reverted; tree confirmed byte-identical):**

- mutation: `GateStatus` read-error arm sets `installing` → `GateLadder.TestReadErrorRefusesAsUnreadable` red.
- mutation: `SqlPrivilegeHeld` check replaced by `If 0` → `GrantReadBack.TestAGrantThatDidNotTakeFailsTheInstall` red (install succeeds, stamp recorded). (This mutant leaves probe applications with no provenance row, which `Uninstall` cannot remove; they were deleted by hand, and the test now asserts their absence as a precondition.)
- mutation: `EnsureSqlPrivileges` moved back after `EnsureApplications` → same test red on "no probe web application was created before the grant".
- mutation: `StateTables` drops `Abstract = 0` → `GrantReadBack.TestDerivedTablesEqualTheDictionary` red.
- mutation: Router `unreadable` arm deleted → `Gate.TestUnreadablePhaseRefusesThroughTheRouter` red.
- mutation: `Readiness` maps `unreadable` to `installing` → `Readiness.TestUnreadableIsItsOwnStateInTheSameThreeKeys` red.
- mutation: `durable-init.sh` exits 0 first → `dash scripts/ci-durable-ownership.sh` exit 1 ("still cannot create /durable/iris").
- mutation: `postbuild` deleted → `build-output.test.mjs` licence test red.
- mutation: Bearer `POST /logout` removed from `CheckSignOut` → `Smoke.TestSignOutEndsTheMintedPair` red ("refresh token … still accepted").
- mutation: `matchRole` refusal, then the absolute-path and asserted-set refusals, deleted → the matching `RosterRefusal` tests red.
- mutation: `Fixture.Create` sets `tInstallNs = tOrigNS` → `FixtureNamespace` red on every binding.
- mutation: `code !== INSTALL_UNREADABLE_CODE` dropped from `isInstallInFlight` → `session.test.mjs` DW-96 predicate test red.
- mutation: `role="alert"` deleted, or the `afterNextRender` focus emptied, in `instance-notice.ts` → all three `instance-notice.spec.ts` tests red; the other DW-126/DW-222 render-site mutations (group `aria-label`, caption, `<n>` substitution, `data-unbounded`, status-bar label, sign-in `role="status"`, screen-denied sentence, area-row order, rate refusal) each turned their spec red.
- mutation: a `uses:` back to `@v4`; `runs-on: ubuntu-latest`; setup-uv `version: "latest"`; `.python-version` 3.12.13; `markdownlint-cli2` unversioned; `bash` for `smoke.sh` → the matching `ci.test.mjs` pin red. `chmod 777` restored in `ci-throwaway.sh`, or `depends_on` dropped from either compose → `ci.test.mjs`/`compose.test.mjs` red.
- mutation: last `fi` removed from `smoke.sh` → `shell-scripts.test.mjs` `-n` test red; `unreadable` arm deleted from `wait-readiness.sh`, `ADMIN_V2` test inverted in `ci-image-compile.sh`, marker comparison removed from `container-health.sh` → the matching executing pin red under sh and dash.
- mutation: `ApiService.arm()` aborts immediately → DW-167 call-time `abortedAtCall` assertion red; the old post-settle read on real timers with a 1 ms deadline → red in 2 of 3 runs.
- mutation (review pass): `@if (installUnreadable)` in `app.ts` made `@if (false)` → `app.spec.ts` "DW-96: an unreadable install state renders the blocking notice ahead of both gates" red.
- mutation (review pass): the `isInstallUnreadable` arm deleted from `Session.noteInstallInFlight` → `api.test.mjs` classification row `503 / INSTALL.UNREADABLE` red.
- mutation (review pass): `CheckSignOut`'s no-pair guard deleted → `Smoke.TestNoCredentialsSkipsRatherThanPasses` red; `Run` skips `CheckSignOut` after any failed check → `Smoke.TestSignOutRunsWhenAReadFails` red.
- mutation (review pass): `StartPathLocked` hands `CreateDemoFixtures` `""` → `DemoOptIn.TestDemoFlagReachesTheFixtureCallSite` red.
- mutation (review pass): the `txt` arm deleted from `StaticHandler`'s media-type map → `Static.TestLicenceNoticesAreServedAsPlainText` red (`application/octet-stream`).
- mutation (review pass): `chown -R` in `durable-init.sh` → `ci-durable-ownership.sh` exit 1 ("changed the owner of a child"); its final `exit 1` made `exit 0` → exit 1 ("exited 0 over a read-only root").
- mutation (review pass): `classicLinkCardCaption` respelled in `strings.ts` → three `strings.test.mjs` equality tests red.

**Added by QA (this pass).** The prior verification proved DW-217's two ends separately: the
build emits the licence file (`build-output.test.mjs`), and `StaticHandler` serves a `.txt` as
`text/plain` (`Static.TestLicenceNoticesAreServedAsPlainText`, against a synthetic fixture,
`Test/Static.cls:31`). Nothing committed proved the two ends are the same file on a real running
instance -- only a hand-run `curl` on a throwaway. New:

- `ui/browser/licence.browser-spec.mjs` (QA) -- runs via `cd ui && npm run test:browser`, after
  `npm run build` and `sh scripts/ci-throwaway.sh up`; already wired into CI's `instance` job,
  which runs both in that order. Reads the real `dist/ocupilot-ui/browser/3rdpartylicenses.txt`
  this run's own build produced and asserts the running instance's `GET /ocupilot/3rdpartylicenses.txt`
  is 200 `text/plain` and byte-equal to it.
- `ui/browser.config.mjs`: added `LICENCE_PATH` beside the file's other path constants.

mutation: on `ocupilot-ci` (a throwaway, never the live container), the served copy at
`/durable/iris/csp/ocupilot/3rdpartylicenses.txt` was overwritten in place (no source or git-tree
change) → `licence.browser-spec.mjs`'s byte-equality assertion red, naming the mismatch; restored
from the real build output → green again. `git status --short` / `git diff --stat` showed only
the two files above throughout, confirming the mutation touched the running container and not
the tree. Demonstrated 2026-09-13; the throwaway was torn down afterward (`docker ps -a` /
`docker volume ls` confirmed nothing survived).

**Added by code review (each reverted; `git status --short` unchanged throughout).**

- mutation (code review): `GateStatus`'s absent-row arm sets `unreadable` and its `Catch` sets `installing` → `GateLadder.TestAbsentRowRefusesAsInstalling` and `TestReadThrowRefusesAsUnreadable` red (run 1202); restored, 9/9 (run 1203).
- mutation (code review): `CheckSignOut`'s `'= 401` arm deleted and its accepted-refresh logout deleted → `Smoke.TestSignOutFailsWhenTheRefreshIsNotRefused` and `TestAnAcceptedRefreshIsSignedOutBeforeTheCheckFails` red (run 1200); restored, 11/11 (run 1201).
- mutation (code review): `backoffArmed = false` moved back ahead of the generation checks in `enterInstalling`'s timer → `session.test.mjs` "a timer orphaned by the unreadable answer" red.
- mutation (code review, throwaway only): the served `main-*.js` with `INSTALL.UNREADABLE` rewritten → `unreadable.browser-spec.mjs` SPA test red (notice never shown); bundle restored, checksum equal to `ui/dist`.
- mutation (code review, throwaway only): an `Installer.cls` whose `GateStatus` sets `installing` for `unreadable` loaded into `ocupilot-ci` → the readiness, envelope and `wait-readiness.sh` tests red; the mounted source reloaded, full `test:browser` 10/10. Run with `OCUPILOT_BROWSER_EXECUTABLE` pointing at the pinned 141.0.7390.76 headless shell (the local puppeteer cache was incomplete). Teardown confirmed by `docker ps -a` and `docker volume ls`.
- Also green after the patches: `npm test` (614 tool, 192 component), `npm run build`, `check-objectscript.py`, `lint-docs.sh`.

- **Rework 1 (CI, 2026-09-13).** Run 34793616419: `durable-init` passed on Linux and the node24 action pins passed; the ObjectScript suite failed one method, an order-dependent probe-application leak. Scope is the two `[CI]` items and the tests they name; nothing else is re-derived or re-verified.
  - Throwaway only (these classes install probe profiles; never against `ocupilot`): `sh scripts/ci-throwaway.sh up`, then from `ui/`, `node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>` for AuditEnable, Demo, DemoFaults, DemoOptIn, Descriptor, EntityId, EntityRef, Envelope, Escalation, Fault, FixtureNamespace, Gate, GateLadder, GatewayGapIpmPath, GatewayIni, GrantReadBack, in that order, one at a time — expected: GrantReadBack 3/3 and `%SYS` `Security.Applications` lists no `/api/probeocupilot*` application.
  - Then `node tools/ci-runner.mjs --container ocupilot-ci` with no `--class` — expected: all 41 classes, 0 failed.
  - `cd ui && npm test` — expected: green, including the DW-243 output-shape pin.
  - `sh scripts/ci-throwaway.sh down`, then `docker ps -a` and `docker volume ls` show nothing of the throwaway.
  - mutation (throwaway only): `GatewayGapIpmPath`'s teardown back to deleting only the readiness row and `Escalation`'s `OnAfterAllTests` removed → runner `LEAKED` on both, and `GrantReadBack` `FAILED` printing `TestAGrantThatDidNotTakeFailsTheInstall` with "precondition: no probe web application exists before the install (found: /api/probeocupilot/readiness)".
  - mutation (throwaway state only): probe installed and its readiness row deleted, then `GrantReadBack` run → run 60 `FAILED`, both CI assertion messages printed with their locations; with the session's `FAILS` walk reading status from `$ListGet(tNode, 2)` → "the failure detail names 0 failed method(s) but run 60 recorded 1", and the leftover reported `INHERITED`.
  - mutation: the `describeFailures` loop dropped from `main()` → `ci.test.mjs` "DW-243: a failing class prints the failed method and its assertion message (executed)" red; `problems.push(leftover)` dropped → "DW-242: a probe web application that survives a class fails that class…" red; `problems.push(...detailProblems)` dropped → "DW-243: failure detail that is missing, disagrees with the count, or names a raising teardown…" red; `classifyLeftovers` treating nothing as inherited → "DW-242: a leftover already present before the class ran…" red.
  - mutation (throwaway copy of the source only): `ProbeApps.Paths` skipping the last roster key → `Provenance.TestTheLeftoverCheckSeesEveryRecordedProbeApplication` red (with the class's other install tests, over the readiness application the mutated removal left behind); restored, `Provenance` 6/6.

## Auto Run Result

**Summary.** All twelve ledger entries are implemented:

- DW-96: a fifth gate state `unreadable` (503 `INSTALL.UNREADABLE`, readiness `state`), a dictionary-derived grant read back at install and run before the web applications, the SPA's blocking notice with one Retry, and `wait-readiness.sh` failing fast.
- DW-234: a one-shot `durable-init` service and its Linux reproduction.
- DW-217: licence notices shipped in the served root.
- DW-215, DW-218: exact tool pins.
- DW-229: shell parse checks and executing pins.
- DW-230: mock timers.
- DW-228: smoke sign-out.
- DW-207: roster seams.
- DW-213: fixture namespace argument.
- DW-126, DW-222: copy and accessibility.

**Deviations from the plan:**

- `Installer.Phase()` also answers `unreadable`.
- `ApiService` still returns `installing` to its caller for `INSTALL.UNREADABLE`; the session holds the notice.
- DW-213's task in `USER` is refused by IRIS (`ERROR #7414`), so the test asserts that refusal names `USER`.
- `durable-init` mounts only the durable root and `scripts`.
- `container-start.sh` failed `-n` under macOS `/bin/sh` on a here-doc quote; fixed.
- The hooks take test-only environment overrides for the start key and marker.
- The DW-230 sweep found no other short-timer race.

**Files changed:**

- Server: `Installer.cls` (gate, grant, seams, fixture namespace), `Error.cls`/`Router.cls`/`Readiness.cls` (the code and arm), `Fixture.cls` (namespace argument), `Smoke.cls` (sign-out).
- Server tests: new `GrantReadBack`, `GrantFault`, `RosterFault`, `RosterRefusal`, `FixtureNamespace` and `SmokeReadFault`; updated `GateLadder`, `GateLadderRow`, `Gate`, `GateFixture`, `Readiness`, `ReadinessFixture`, `Version`, `MigrateFault`, `Smoke`, `Static`, `DemoOptIn` and `InstallerProbe`; the source-text pin in `InstallNamespaceSource` removed.
- Client: `session.ts`, `app.ts` and `instance-notice.ts` (the unreadable state); `strings.ts`, `refresh.ts`, `navigation.ts`, `status-bar.ts`, `command-box.ts`, `classic-link-card.ts`, `screen-denied.ts`, `_components.scss` and `screen-store.ts`/`command-bar.ts`/`api.ts`/`fault.ts` comments (DW-126).
- Client tests: new `instance-notice.spec.ts` and `server-flag.spec.ts`; updated `app`, `sign-in`, `status-bar`, `command-bar`, `command-box`, `classic-link-card`, `screen-outlet`, `home.page` and `app.wire` specs.
- Tools: new `licenses.mjs`, `stub-bin.mjs`, `shell-scripts.test.mjs`; updated `ci`, `compose`, `build-output`, `strings`, `refresh`, `refresh-connectivity.wire`, `session`, `api`, `navigation`, `screen-mirror` and `design-tokens` tests, and `strings.mjs`/`screen-mirror.mjs`.
- Scripts and CI: new `durable-init.sh`, `ci-durable-ownership.sh`, `.python-version`; updated `docker-compose.yml`, `ci.yml`, `ci-throwaway.sh`, `wait-readiness.sh`, `container-health.sh`, `container-start.sh`, `lint-docs.sh`, `smoke.sh` (header), `.githooks/pre-commit`, `package.json`.
- Docs: `README.md`, `ATTRIBUTIONS.md`, EXPERIENCE.md.

**Review (one pass, 60 findings; rows in `## Review Triage Log`).**

- Patched, 22 rows in 14 root causes, of which 5 were medium:
  - the `app.ts` branch test;
  - the `StartPath` fixture-namespace capture;
  - sign-out requiring 401;
  - per-line skip assertions;
  - a `text/plain` serving test for the licence file.
  - The low patches: `durable-init.sh` (`mktemp` probe, `chown` failure reaches the named exit, read-only failure check, negative control requires `Permission denied`), the `api.test.mjs` row, four mutation lines, and comments in `GateLadder`, `Installer` and `smoke.sh`.
- Deferred: 3 new items in frontmatter (widened grant, client backoff on FAILED/UPGRADEREQUIRED, node20 actions). One further row is already carried.
- Rejected: 20 rows, each with its reason in the triage log. 11 were false.

**Follow-up review recommended: true.** Five medium entries were patched. The named unverified risk: the patched `durable-init.sh` (`mktemp` probe, `chown` fall-through) and `ci-durable-ownership.sh`'s read-only check have run only on Docker Desktop's VM volumes, so CI's Linux `instance` job is their first run on a runner and on a Linux bind mount.

**Verification this pass:**

- Build and checks: `npm run build` (licence file byte-equal) and `npm test` (613 tool tests and 192 component tests, after patches) green; `check-objectscript.py`, its harness and `lint-docs.sh` green on uv 0.12.9 and Python 3.12.14.
- Wire test: 50/50 under 8 busy loops.
- Ownership: `ci-durable-ownership.sh` green before and after patches, leaving no volume. `durable-init.sh` over a `/tmp` bind mount exited 0 and changed nothing. With `durable-init.sh` made a no-op, the reproduction exits 1.
- ObjectScript on `ocupilot-iris`, one class per call, with latest-run totals confirmed by the run-index probe:
  - `GateLadder` 9, `Gate` 7, `Readiness` 8, `Version` 19, `GrantReadBack` 3, `RosterRefusal` 4, `FixtureNamespace` 1;
  - `Envelope` 15, `Demo` 9, `InstallNamespaceSource` 3, `Installer` 26;
  - after patches: `Smoke` 9, `DemoOptIn` 4, `Static` 17.
- Throwaway, re-run by the stage agent:
  - healthy with `durable-init`; licence GET 200 `text/plain`, byte-equal; smoke passed with `sign-out`;
  - after REVOKE: readiness `unreadable`, a non-`%All` user 503 `INSTALL.UNREADABLE`, `wait-readiness.sh` exit 1;
  - the SPA showed the notice, made no requests over 12 s, and Retry ran one identity pass;
  - install again restored the grant; a restart answered 000/500/installed and never `unreadable`, with the grant held;
  - teardown left nothing.
- Live smoke exits 0 with `sign-out` passed (re-run after the 401 patch).

**Residual risks:**

- A transient read error during a restart recompile answers `unreadable` by design (not observed; the matrix requires it).
- `docker compose up --wait` with a one-shot dependency on the runner's Compose version.
- Mock timers on the Node 22.22.3 floor.
- `CLAUDE.md` still says `bash scripts/smoke.sh` (the lead's file).

### Rework 1 (CI run 34793616419)

**Leaking class, confirmed by replay on the throwaway: `GatewayGapIpmPath`.** `Escalation` leaves the probe profile installed; `GatewayGapIpmPath`'s teardown then deleted the readiness application's provenance row, so no later `Uninstall("probe")` could remove `/api/probeocupilot/readiness`. Reproduced without code change: probe install plus that row deleted makes `GrantReadBack` fail with CI's two messages.

**Changed (diff base `3cd5320a0e3a0056b1e2b8f54dc7becca8adf3f4`; frontmatter `baseline_revision` kept as the story's):**
- `src/OcuPilot/Test/ProbeApps.cls` (new): roster-derived `Paths`, `Existing` (fails closed as `error:`), `Remove` (uninstall, then remove every remaining roster application; a row goes only once its application is gone).
- `GatewayGapIpmPath`: setup and teardown call `ProbeApps.Remove()`. `Escalation`, `InstallMark`, `UnexpireScope`, `Version`: `OnAfterAllTests` removes the probe profile (the sweep: each left probe applications). `GrantReadBack.ProbeApplications` and `Provenance.CleanProbe` delegate to `ProbeApps`; the precondition is unchanged and now names what it found.
- `Provenance.TestTheLeftoverCheckSeesEveryRecordedProbeApplication`: `Existing()` equals install's own rows; removal clears a row-orphaned application.
- `scripts/ci-unit-test.sh`: prints leftovers before and after `RunTest`, and a `FAILS` JSON marker (failed methods, assertion action/description/location, raised setup/teardown) read at `tRun` only when the run landed.
- `ui/tools/ci-runner.mjs`: prints each failed method and assertion; fails a class that added a probe application (`LEAKED`), still fails an inherited one (`INHERITED`), fails unreadable or count-disagreeing detail and a raising class teardown; summary counts leftovers. `ui/tools/ci.test.mjs`: six tests, four executing the real runner over a stub session.

**Review:** 34 findings (0 high, 9 medium, 17 low, 8 false). Patched 8 entries (4 medium, 4 low); rejected 18 rows with reasons in the triage log; no reviewer finding deferred. One implementation observation deferred to frontmatter (a probe role seen after uninstall).

**Follow-up review recommended: false.** Follow-up pass; no high was patched.

**Verification:**
- Throwaway (fresh, patched tree): the sixteen classes in CI order each `ok`, `GrantReadBack` 3/3, `%SYS` application listing shows no `probeocupilot` application (control query lists the three production ones); then the full runner: 41 classes, 365 tests, 0 failed, 0 with probe leftovers. The same was green before patches (364 tests). Torn down; `docker ps -a` shows only `ocupilot` and `iris-community-edition`, `docker volume ls` is empty.
- `npm test` 620 tool and 192 component tests green; `check-objectscript.py` and its harness green. Mutations under `## Verification`, each reverted with `shasum` equal. Nothing ran against the live `ocupilot` container.

**Residual risks:** the live `ocupilot` instance does not yet have `OcuPilot.Test.ProbeApps` compiled, so `ci-runner.mjs --container ocupilot` fails every class as unreported until it is loaded; `Remove()` in the four `OnAfterAllTests` adds one probe uninstall per class to CI time.

Status: done
Blocking condition: none
