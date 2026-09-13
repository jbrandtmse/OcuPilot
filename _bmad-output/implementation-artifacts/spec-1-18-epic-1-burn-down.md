---
title: 'Story 1.18: Epic 1 burn-down'
type: 'bugfix'
created: '2026-09-13'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['multiple-goals', 'oversized']
deferred: []
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

## Spec Change Log

## Review Triage Log

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

## Auto Run Result

Planned only (halt after planning). All twelve ledger entries are addressed and none is declined. Warnings: multiple-goals, oversized.

Status: ready-for-dev
Blocking condition: none
