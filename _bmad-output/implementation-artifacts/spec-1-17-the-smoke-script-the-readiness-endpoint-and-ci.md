---
title: 'Story 1.17: The smoke script, the readiness endpoint and CI'
type: 'feature'
created: '2026-09-13'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/README.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Nothing in this repository can say "installed and working" and be believed. Every gate the
epic built — five `prebuild` checkers, the pre-commit hook, the container start hook, the health check —
is asserted as source text and run by a human at most once; `/epic-cycle` has recorded `ci=none` for all
sixteen stories. A running instance cannot be asked whether OcuPilot is installed at all: the only
answer is an `iris session` inside the container.

**Approach:** Three things that make the answer mechanical. A **readiness endpoint** on its own
unauthenticated web application, so an instance answers for itself over HTTP. One **smoke script** owned
by `Install/` that is the definition of installed-and-working — asserting what exists and reporting the
rest as pending, never passing vacuously. And **CI**, the first place in this repository where a gate is
run rather than described: it builds, lints, runs every suite, brings up a throwaway container and runs
the smoke script against it. The third web application arrives through the roster the way any future one
will, which is also where install finally learns which applications it created.

## Boundaries & Constraints

**Always:** Readiness reports **only** installed, the version stamp, and which of install's four states
the instance is in — including `failed` (DW-2). It is one more roster application, created and removed by
the installer like the other two, carrying exactly one purpose-built matching role, read-only on the
install namespace's code database and nothing else (AD-21). Install **refuses** to adopt a web
application at any of its three paths that it did not create, names the conflict, changes nothing, and
uninstall removes only what a provenance record says install created (DW-94, owner decision 2026-09-11).
The roster is iterated, never keyed by literal (DW-192): a fourth application must be one roster edit.
The smoke script is one script with one assertion set; CI and Epic 17's clean-clone run differ only in
what created the instance. Every gate CI runs reports the size of what it looked at, so "found nothing
wrong" and "looked at nothing" are distinguishable.

**Never:** Nothing in CI publishes, lists, releases or pushes to any registry — no Open Exchange, no
`npm publish`, no container push, no GitHub release, no `secrets.*` reference (stealth policy until the
owner's 2026-09-24 release). Readiness names no instance detail, no failing step, no namespace, no
directory, and requires no privilege. No `docker compose up`/`down`/`restart` against this repository's
compose file — every container this story starts is a throwaway with its own project name, container
name, ports (never 52774/1973) and scratch volume. No namespace, database or account is created,
deleted, mounted, dismounted, modified or expired on the live instance. No second response writer, error
envelope, installer entry point or install path. The container health check is **not** rewritten to call
readiness — the pinned image ships no HTTP client.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Readiness, installed | Anonymous `GET /api/ocupilot/readiness` on a healthy instance | 200, `application/json`, exactly `{installed:true, version:<stamp>, state:"installed"}` | No error expected |
| Readiness, install failed (**DW-2**) | Version row `failed` | 200 with `installed:false`, `state:"failed"` — distinguishable from an install that never started | No error expected; the failing step is **not** disclosed |
| Readiness, mid-install | Version row `installing`, or absent | 200, `state:"installing"`, `version:""` | No error expected |
| Readiness, upgrade pending | Stored schema version below the deployed one | 200, `state:"upgraderequired"` | No error expected |
| Readiness, wrong verb | `POST` to the readiness path | 405 with `Allow`, through `Error.Render405` | One envelope, no body leak |
| Readiness with no privilege floor | The matching role absent | Install refuses; a live request would 500 with `<PROTECT>` naming the database directory (AD-21) | Install-time assertion fails loudly |
| Foreign application at a roster path (**DW-94**) | `/ocupilot`, `/api/ocupilot` or the readiness path exists with no provenance row | Install refuses naming the path and the conflict, creates and repairs **nothing** | Failing `%Status`; no partial install |
| Uninstall, adopted application (**DW-94**) | An application at a roster path with no provenance row | Left in place and reported; everything install did create is removed | Reported, not an error |
| Uninstall from the wrong namespace (**DW-191**) | `Uninstall` called from a system namespace, or one with no install | Refused by the same guard `Install`/`StartPath`/`MarkInstalling` use | Failing `%Status`, nothing removed |
| Fourth roster application (**DW-192**) | A new entry added to the roster only | It reaches `module.xml`, `Install()`, `StateFingerprint` and the install-time assertion with no second edit | Shape refusal names the roster key |
| System namespace at container start (**DW-195**) | `OCUPILOT_NAMESPACE` naming `%SYS` | The start hook refuses **before** `LoadDir` compiles anything | `exit 1`, no classes compiled |
| Malformed generated manifest (**DW-197**) | `module.xml` not well-formed XML | The check refuses naming the parse error and offset | Gate fails |
| Description drift (**DW-199**) | An application's `Description` edited on the instance | Repaired on the next install, like every other asserted property | Repaired, reported |
| Probe against a half-open socket (**DW-167**) | Connection accepted, never answered | The request aborts at the timeout and the backoff chain continues | Reported as unreachable, chain re-arms |
| Smoke against a healthy instance | Throwaway container, install complete | Exit 0; one line per check; pending items listed with the story that will make them real | — |
| Smoke, nothing asserted | Every check skipped or the check list empty | **Non-zero exit** — zero executed checks is a failure, never a pass | Names the empty count |
| Smoke against a broken install | Readiness reports `failed` | Non-zero exit naming the first failed check | — |
| CI gate deleted from the workflow | A gate command removed from `.github/workflows/ci.yml` | The wiring test refuses, naming the missing gate | `npm run test:tools` red |
| CI publish step added | Any registry push, release or `secrets.` reference in the workflow | The wiring test refuses naming it (stealth policy) | `npm run test:tools` red |

</intent-contract>

## Code Map

- `src/OcuPilot/Install/Roster.cls` — `XData Manifest` `:64-127`; `applications` array `:88-119` (`shell` `:89-101`, `api` `:102-118`, each with `key`/`path`/`description`/`manifest`/`installer`). `Get()` `:135`, `Application()` `:161`, `AssertedProperties()` `:200` (manifest ∪ installer). **The third application and its declared matching role are added here and nowhere else.**
- `src/OcuPilot/Install/Installer.cls` (2,904 lines) — `Names()` `:123`, which hardcodes the keys at `:166-173` (`RosterNames("shell")`, `RosterNames("api")`, then `shellApplication`/`apiApplication`/`shellRole` literals) — **this is DW-192**; the same two literals recur at `EnsureShellApplication` `:2019`, `EnsureApiApplication` `:2036` and `StateFingerprint` `:2517-2518`. `EnsureWebApplication` `:2111` — create branch `:2135-2143` (`Type=2` `:2138` and `Description` `:2139` are create-only: **DW-199**), repair branch `:2115-2134`, and the presence-only test at `:2115` `Security.Applications.Exists(pName,…)` that is **all the provenance there is** (**DW-94**). `WantFromRoster` `:2055`, `ApplicationFingerprint` `:2543`, `EnsureShellRole` `:1870` (resource set `CodeDatabaseResource(ns)_":R"` `:1875-1877`) — the privilege-floor pattern the readiness role copies. `GuardInstallNamespace` `:282` (called from `Install` `:530`, `StartPath` `:783`, `MarkInstalling` `:886` — **not** from `Uninstall`). `Uninstall` `:2649`, taking the caller's namespace at `:2659` (**DW-191**) and deleting both applications by name at `:2801`/`:2805`. `ReportGatewayGap` `:1283`, whose "created no web application" line `:1306` reads the per-run `pCreatedApps` (**DW-198**). `GateStatus` `:1109`, ladder `:1127-1142` — the four states readiness reports. `RecordStamp` `:2379`.
- `src/OcuPilot/Kernel/State/Stamp.cls` — one row per profile naming the objects install created (`:25-35`); the provenance record's home. A new `%Persistent` sibling must stay ≤29 dotted characters (`OcuPilot.Kernel.State.WebApp` is 28); a `list Of %String` on a `%Persistent` class is forbidden — subtable or relationship.
- `src/OcuPilot/Api/Router.cls` — `UrlMap` `:56-63`; `OnPreDispatch` `:220-287` with the install gate **before** identity `:229-244`; `Error.Render405` use; `ReportHttpStatusCode` `:293`. The readiness dispatch class is a **separate** `%CSP.REST` sibling, not a route here.
- `src/OcuPilot/Api/Error.cls` — `Render()` `:200`, the twelve-slug enum `:20-54`, the machine codes `:59-170`, `Render405` `:284`. `src/OcuPilot/Api/Response.cls` — `JSON` `:13`, `JSONStatus` `:25`. Readiness writes through these; it adds no envelope.
- `src/OcuPilot/Test/Http.cls` — the over-the-wire client: `%Net.HttpRequest`, `AbsoluteRequest` `:193-213` (any path from the origin root, caller-supplied principal **or none** — the anonymous readiness request), `GetTestServer`/`GetTestPort` `:19-69`. Test-scope only; `Install/Smoke.cls` cannot depend on it and uses `%Net.HttpRequest` directly.
- `src/OcuPilot/Test/Wire.cls` — 13 over-the-wire cases and two run-minted principals `:76`; readiness's HTTP integration test joins these. `Test/WebApp.cls`, `Test/Installer.cls`, `Test/Manifest.cls`, `Test/InstallNamespaceSource.cls` (**pins DW-191's current behaviour — it must be updated, not deleted**), `Test/GatewayGapIpmPath.cls` (**pins DW-198's current message**), `Test/Inventory.cls` (AD-27's endpoint-inventory fixture CI must run), `Test/GateLadder.cls`, `Test/Static.cls`.
- `ui/package.json` `:6-15` — `prebuild`/`prestart` chain the five checkers; `test` is `node --test tools/ && ng test`; `engines` `:16-18`. `ui/tools/` — `ipm-manifest.mjs` (`firstDrift` `:456` is a **text** compare, no parse: **DW-197**; `main()` `:677`), `classic-links.mjs` (`:385` sets `exitCode`, never `exit`), `screen-mirror.mjs` (`--check` `:531`), `client-lint.mjs` (whole-tree, two rules), `version-guard.mjs`, `compose.test.mjs` (text assertions over `docker-compose.yml` and `container-start.sh` — the precedent for asserting a YAML gate as text), `classic-links.test.mjs:510-552` (**the gate-wiring test pattern to copy**, asserting `|| STATUS=1` and that no chain swallows a check).
- `.githooks/pre-commit` — `OS_TRIGGER` `:84-87` (a git pathspec, root **and** nested forms both needed); dispatches `check-objectscript.py` `:91`, `client-lint.mjs` `:102`, `classic-links.mjs` `:115`, `ipm-manifest.mjs --check` `:127` — **`screen-mirror.mjs --check` is absent (DW-184)**. `--cached` is used only to decide *whether* to run `:40`/`:84`/`:141`; every checker then reads the working tree (**DW-196**; the header comment at `:3` says "staged files only" and is wrong about scope).
- `scripts/check-objectscript.py` — `main()` `:829-849`, ten checks in order `:831-840` (`check_naming` `:285`, `check_write_discipline` `:455`, `check_product_vocabulary` `:631`, …); fail-closed vocabulary readers `:340`/`:715`/`:772`; `iter_named_xdata_blocks` `:666`. **No rule exists for `Test*` properties, embedded Python, CDN references, non-ASCII string literals, or handler↔HTTP-test coverage.** Harness `scripts/test_check_objectscript.py` — `FixtureTreeCase` monkey-patches `ROOT`/`SCAN_ROOTS` to a temp tree; added by Story 1.9, so **DW-35's "no test of its own" is stale**; what remains is that it runs only when a `.py` file is staged (`:141`).
- `scripts/container-start.sh` — `SRC_DIR` `:76`, `BUNDLE_DIR` `:81`; the namespace is resolved and the version row marked in an **earlier** `%SYS` session `:158-197`, and `LoadDir` + `StartPath` run at `:280-291` — so a system-namespace refusal belongs in the earlier session (**DW-195**); outcome markers `LOAD-FAILED` / `STARTPATH-FAILED` `:287`, dispatch `:303-343`. `scripts/container-health.sh` — start-scoped marker `:29`, `GateStatus` read `:100-118`; the image ships no HTTP client, which is why it shells `iris session`.
- `docker-compose.yml` — image `:7` (`intersystems/irishealth-community:2026.2`, digest in the comment `:6`), `restart: on-failure:3` `:17`, ports `:18-20`, `OCUPILOT_DEMO` `:21-25`, mounts `:26-35`, start hook `:39`, healthcheck `:40-48`.
- `README.md:357-409` — § "Verifying the start path against a throwaway container": the scratch `compose.yml`, project and container name `ocupilot-fresh`, ports `1975:1972`/`52776:52773`, `up -d --wait` then `down -v`. `README.md:478-519` — the IPM variant.
- `ui/src/app/core/connectivity.ts` — `ConnectivityService` `:56`, `runProbe()` `:249-256` (awaits `requestJson` with **no** `AbortController`, `AbortSignal` or timeout anywhere in `ui/src` — **DW-167**), `armProbe()` `:233-242`, backoff constants `:41-42` (500ms doubling to 8s). `ui/src/app/core/api.ts` — `ApiService` `:182`, `ApiRequestInit` `:65-75` (**no `signal` field**), `request()` `:209`, the absolute-path guard `:170`. `ui/src/main.ts:47,50,79` — the injected bare `fetch`.
- `ui/angular.json` — three targets only: `build` `:12` (`outputPath: dist/ocupilot-ui`, `outputHashing: all` `:20`, `baseHref: /ocupilot/` `:19`), `test` `:54-63` (`@angular/build:unit-test`, vitest, jsdom), `serve` `:64`. **No `e2e` target, no browser harness anywhere in `ui/`** (DW-159); `ui/tools/angular-json.test.mjs:90-101` pins the `test` target's shape and must be extended, not bypassed. `ui/proxy.conf.json` proxies `/api/ocupilot` to `localhost:52774` — dev only, never CI.
- `ui/src/app/core/strings.ts` — the one user-facing string source; `client-lint.mjs` fails the build on any template literal not interpolating a key here. It carries connectivity and status copy (`:74-88`, `:344-348`) and **no** readiness vocabulary.
- **Absent:** `.github/` does not exist. There is no `.gitlab-ci.yml`, `Jenkinsfile`, `.circleci/` or `Dockerfile`. `client-lint.mjs:7` records why: "there is no CI in this repository, so `prebuild` is the only mechanism that makes 'fails the build' literally true".

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Install/Roster.cls` — add the readiness application (`key`, `path` under `/api/ocupilot/`, `description`, `manifest` with `AutheEnabled` 64 and its dispatch class, `installer` list) and give **every** application a declared `matchRole`. Move `Description` out of the create-only branch by declaring it in the asserted set (**DW-199**).
- `src/OcuPilot/Install/Installer.cls` — `Names()` `:166-173` iterates `roster.applications` instead of naming `shell` and `api`; `EnsureShellApplication`/`EnsureApiApplication` collapse into one roster-driven loop; `StateFingerprint` `:2517-2518` and the install-time assertion derive from the same iteration (**DW-192**). `EnsureShellRole` generalises to ensure each application's declared `matchRole`, resource set unchanged (AD-21).
- `src/OcuPilot/Install/Installer.cls` + `src/OcuPilot/Kernel/State/` — a provenance record written when install **creates** a web application and read before any repair: an existing application with no record is a refusal naming the path, and `Uninstall` removes only recorded applications and reports the rest (**DW-94**). `ReportGatewayGap` `:1283` reads the record rather than the per-run `pCreatedApps`, so the IPM path stops claiming it created nothing (**DW-198**). `Uninstall` `:2649` calls `GuardInstallNamespace` like every other entry point (**DW-191**).
- `src/OcuPilot/Api/Readiness.cls` — **new** `%CSP.REST` dispatch class for the third application. One `GET /` route returning `{installed, version, state}` from `Installer.GateStatus()` and the version row, through `Response.JSON`; 405 with `Allow` on any other verb through `Error.Render405`. It resolves no user, reads no namespace from the caller, and discloses no failing step (**DW-2**).
- `src/OcuPilot/Install/Smoke.cls` — **new**. One check list, each entry `pass` / `fail` / `pending` with a reason; checks readiness, the static shell and a deep link, sign-in minting a token pair, `/instance`, `/namespaces`, `/navigation`, the audit-event registration, and the demo fixture when `OCUPILOT_DEMO` was set; reports one-live-list-per-area, the confirmed agent write and the audit marker as **pending**, naming the epic that makes each real. Prints the counts it executed; **zero executed checks is a failure**. Uses `%Net.HttpRequest` directly (`Test/Http.cls` is test-scope).
- `scripts/smoke.sh` — **new**. The one entry point CI and Epic 17 both call: takes the container or host/port and credentials, runs `Install.Smoke` through `iris session`, maps the verdict to an exit code, prints the report unchanged.
- `ui/tools/ci-runner.mjs` — **new**. The serialized ObjectScript runner CI's instance job calls: one class per `iris session` invocation, each class's result confirmed with the numeric-run-index `%UnitTest_Result` probe before the next starts, failing if any two runs of this invocation overlap (**DW-54**).
- `.github/workflows/ci.yml` — **new**. `on: push`, `pull_request`, `workflow_dispatch`; `permissions: contents: read`; `concurrency` with `cancel-in-progress`. Three jobs: **gates** (`npm ci`, `npm run build`, `npm test`, `uv run scripts/check-objectscript.py`, `uv run scripts/test_check_objectscript.py`, `bash scripts/lint-docs.sh`); **instance** (build the bundle, bring up a throwaway from a generated compose file, wait on the health check, run `ui/tools/ci-runner.mjs`, then `scripts/smoke.sh`, then the browser spec, then `down -v`); **images** (matrix over `intersystems/irishealth-community:2026.2` and `intersystems/iris-community:2026.2`: compile `src/OcuPilot/` and confirm the admin API answers v2 on each). No publish step, no `secrets.` reference, no `continue-on-error`, no `|| true`.
- `ui/tools/ci.test.mjs` — **new**. Text assertions over `.github/workflows/ci.yml` in the `compose.test.mjs` style: every declared gate appears as a `run:` command **and** every gate-shaped `run:` is declared (equality, both directions); every command names a file that exists; no `continue-on-error`, `|| true`, `set +e`, `secrets.`, registry push, release action or Open Exchange step; the triggers and permissions are as above.
- `.githooks/pre-commit` — dispatch `screen-mirror.mjs --check` in the `OS_TRIGGER` block in the `:115` shape (**DW-184**); correct the `:3` header comment to say the hook triggers on staged paths but checks the working tree, and name CI as the gate over committed content (**DW-196**).
- `scripts/check-objectscript.py` + `scripts/test_check_objectscript.py` — four rules, each with fixture-tree cases: no property whose name begins with `Test` on a `%UnitTest.TestCase` subclass; no `[ Language = python ]` in any shipped class; every `Call=` target in a router `UrlMap` has an over-the-wire test asserting status, content type and body shape; no literal non-ASCII byte in a **string literal** under `src/OcuPilot/` (comments exempt per Rule 14) (**DW-43**).
- `ui/tools/client-lint.mjs` + `ui/tools/client-lint.test.mjs` — two rules: no CDN or off-origin URL in `ui/src/**` or `index.html`; no literal non-ASCII byte in a string literal or template text node (**DW-43**).
- `ui/tools/ipm-manifest.mjs` + `src/OcuPilot/Test/Manifest.cls` — parse the committed `module.xml` as XML (`%XML.TextReader` on the ObjectScript side) and assert its element set, not only its bytes (**DW-197**).
- `scripts/container-start.sh` + `ui/tools/compose.test.mjs` — refuse a system-namespace `OCUPILOT_NAMESPACE` in the **earlier** `%SYS` session at `:158-197`, before `LoadDir` compiles anything; pin the shell's namespace list against `Installer.SYSTEMNAMESPACES` the way the candidate order is already pinned (**DW-195**).
- `ui/src/app/core/api.ts` + `ui/src/app/core/connectivity.ts` + their tests — an abort-based timeout on every request the probe issues, so a connection accepted and never answered aborts and the backoff chain continues (**DW-167**).
- `ui/package.json`, `ui/browser.config.*`, `ui/browser/shell.browser-spec.*` — **new**: a headless-Chrome runner pinned to an exact version, its config, a `test:browser` script, and **one** spec against the throwaway container: the shell loads at `/ocupilot` with no console error and non-zero laid-out geometry for the rail and side bar, a deep link resolves to the shell, and silent-first sign-in succeeds once a classic-portal login has minted the browser-id cookie. Extend `ui/tools/angular-json.test.mjs`'s target assertions rather than relaxing them (**DW-159, harness half**). The runner is a dev dependency only — nothing it pulls reaches the shipped bundle (NFR-10).
- `src/OcuPilot/Test/Readiness.cls`, `src/OcuPilot/Test/Provenance.cls`, `src/OcuPilot/Test/Smoke.cls` — **new** `%UnitTest` classes; plus updates to `Test/Wire.cls` (the anonymous readiness request), `Test/WebApp.cls`, `Test/Installer.cls`, `Test/Manifest.cls`, `Test/InstallNamespaceSource.cls` and `Test/GatewayGapIpmPath.cls`, the last two moving from pinning the old behaviour to pinning the new. Between them these cover **every row of the I/O & Edge-Case Matrix**; the rows whose input is a container or a running instance are covered by the throwaway run named in `## Verification` and are marked as such where they land.
- `README.md` — the readiness endpoint, the smoke script and how to run it, and what CI runs.

**Acceptance Criteria:**

- Given a roster carrying a third application, when `Install()` runs on an instance where none of the three exists, then all three are created with exactly their declared properties and matching roles, `module.xml`, `StateFingerprint` and the install-time assertion all cover three, and adding the entry required **no** edit outside the roster (**DW-192**).
- Given a web application already at one of the three roster paths with no provenance record, when install runs, then it refuses naming the path, creates nothing and repairs nothing; and given uninstall on that instance, everything install created is removed and the adopted application is left in place and reported (**DW-94**).
- **Integration AC (Rule 1).** Given a throwaway container whose install completed, when `scripts/smoke.sh` runs against it, then it reads the readiness endpoint over real HTTP as an anonymous caller, exits 0, and prints the executed and pending counts; and given the same instance with the version row forced to `failed`, the smoke script exits non-zero naming readiness as the failed check — the smoke's verdict is observable from its exit code alone, not from readiness's internals.
- **Integration AC (Rule 1).** Given CI's instance job, when the throwaway comes up, then the job waits on readiness reporting `installed` before running any suite, and a container whose install failed stops the job at that step rather than producing a green run over an uninstalled instance.
- Given the committed workflow, when `npm run test:tools` runs, then the wiring test passes; and given any gate command deleted from the workflow, or any publish, release, registry-push or `secrets.` reference added to it, the wiring test refuses naming what changed.
- Given CI's instance job, when the ObjectScript suite runs, then classes execute one at a time with each result confirmed in `%UnitTest_Result` before the next starts, and two overlapping runs inside one invocation fail the job (**DW-54**).
- Given a shipped class carrying an embedded-Python method, a test class carrying a `Test*` property, a router route with no over-the-wire test, a CDN reference in the client, or a literal non-ASCII byte in a string literal, when the checkers run, then each is refused naming the file and line, and each refusal runs in CI on every change (**DW-35, DW-43, DW-50, DW-193, DW-196**).
- Given both stock Community images at the pinned version, when the images job runs, then `src/OcuPilot/` compiles clean on each and the admin API answers v2 on each, so no HealthShare-only dependency exists; the plain-Community install path remains deferred past the 2026-09-27 floor by owner decision, with the risk of a late failure accepted.
- Given a request the instance accepts and never answers, when the connectivity probe issues it, then the request aborts at its timeout and the backoff chain continues rather than stalling (**DW-167**).
- Given the shell served by a throwaway container, when the browser spec runs in headless Chrome, then the shell renders with non-zero laid-out geometry, a deep link resolves to the shell, and silent-first sign-in completes — none of which jsdom can observe (**DW-159**, harness half).

## Design Notes

**Governing ADs (Rule 6).** **AD-45** (one smoke path, owned by `Install/`, also the definition of "step
complete"; readiness reports only installed, version and whether install is running; it lives on a third
unauthenticated application at a path under `/api/ocupilot/`, resolved by longest prefix, created and
removed by the installer). **AD-38** (install completes before the API serves; the four gate states
readiness reports are `GateStatus`'s, and the health check stays start-scoped). **AD-21** (an
unauthenticated application still needs a one-matching-role privilege floor, read-only on the install
namespace's code database and nothing else; anonymous does not mean unprivileged, so readiness resolves
no user and infers nothing from roles). Also **AD-17** (one installer, two entry points, idempotent; the
roster and the manifest generated from one source), **AD-12**/**AD-39** (one response writer, one flat
envelope — readiness adds neither), **AD-16** (namespace by explicit save and restore), **AD-25** (the
demo fixture is opt-in; the smoke asserts it only when the flag was set), **AD-27** (the image is pinned
to an explicit tag, and the endpoint-inventory fixture runs in CI), **AD-28**/**AD-47** (the browser spec
drives the instance's own origin, never a second origin; no CORS allowance is introduced), **AD-18** (CI
must not assume IPM exists in the runtime image), **AD-10** (CI grants no privilege and the manifest
widens no role). Consistency Conventions: the 29-character cap on `%Persistent` class names, Storage
sections never hand-written, ISO-8601 UTC, "Every handler gets an HTTP integration test asserting status,
content type and body shape", "Test classes carry no property whose name begins with `Test`" — the last
two are why two of this story's checker rules exist.

**Consumes:** 1.3 (`Kernel/State` protected storage and its escalation discipline). 1.4 (the container,
`container-start.sh`, `container-health.sh`, the throwaway-compose recipe, `GateStatus`). 1.5
(`Api.StaticHandler`, the two web applications, the shell role, `Test/Http.cls`'s over-the-wire client).
1.6/1.7 (JWT login and logout, which the smoke and the browser spec exercise). 1.8 (`GET /instance`).
1.9 (`GET /navigation`, the endpoint-inventory fixture's neighbourhood). 1.13 (`ConnectivityService` and
its backoff). 1.15 (`classic-links.test.mjs`'s gate-wiring test — the pattern `ci.test.mjs` copies).
1.16 (`Install/Roster.cls`, `ipm-manifest.mjs`, the committed `module.xml`, the pre-commit hook's
dispatch shape, `compose.test.mjs`'s text-assertion precedent).

**Consumed-by:** Every later story in every epic — CI runs their suites, and the smoke script is what
"this step is complete" means. Epic 2 (`AdminPort` and the endpoint-inventory fixture run in CI; each
area's first live list turns one of the smoke's `pending` lines into a real check). Epic 3 (the confirmed
agent write and the audit marker — the last two pending lines). Epic 17 (the clean-clone run: the same
`scripts/smoke.sh` with the same assertions, differing only in what created the instance). Story 1.18,
the Epic 1 burn-down story, takes the browser back-fill below.

**How the seventeen routed entries are dispositioned.** Sixteen are addressed above; one is split.

1. *Gates asserted as source text, never run* — **DW-193, DW-50, DW-35** are addressed by CI itself: every
   checker, both Python harnesses, `npm test`, the ObjectScript suite and a real container start now run
   on every change, and the container/health-check/HTTP/demo-flag surfaces DW-50 names are exercised by
   the instance job rather than by a one-off manual run. DW-35's original claim is **stale** — Story 1.9
   added `scripts/test_check_objectscript.py`; what remained is that it runs only when a `.py` file is
   staged, which CI closes *(inference — from the hook's `:141` trigger, not from an observed miss)*.
   **DW-184** and **DW-196** are addressed directly: the hook gains the missing dispatch, and its wrong
   header comment is corrected at its origin rather than annotated. DW-196's substance — that a partially
   staged pair passes — is closed by CI checking the committed tree, not by rebuilding four whole-tree
   checkers around a temporary index. **DW-43** is addressed as a checker over **string literals and
   template text**; see the declined half below.
2. *No browser-runtime harness* — **DW-159** is **split**. This story lands the harness and the one spec
   the smoke script's own "sign-in" clause needs, which makes the entry's title false. The back-fill —
   real-browser assertions for the shell surfaces built across 1.5–1.16 — is **recommended for Story 1.18**.
3. *Install-path residue* — **DW-191, DW-192, DW-195, DW-197, DW-198, DW-199** are all addressed, each in
   a file this story already opens. DW-192 is load-bearing, not incidental: the third application cannot
   install without it.
4. *Readiness and probe behaviour* — **DW-2** and **DW-167** are addressed.
5. *The owner decision now due* — **DW-94** is addressed, and the provenance record it needs is the same
   record the third application is created through. **DW-54** is addressed by CI's serialized runner and
   its overlap check, plus the procedural rule restated in `## Verification`.

**Declined DW-43 (comment half): Rule 14 exempts comments, so ~250 of the 259 lines need no change.** A
tree-wide scan of `ui/src/`, `ui/tools/`, `src/OcuPilot/` and `scripts/` found 259 lines in 42 files
carrying 275 non-ASCII characters, 242 of them em dashes. Rule 14 binds *source code* and exempts "prose
files … comments where project convention allows"; the Conventions row binds *string sources*. Rewriting
a quarter of a thousand comment em dashes as backslash-u-2014 escapes would be a large unreviewable diff that
makes the comments harder to read and enforces nothing the rule asks for. Four occurrences are in string
literals or test data rather than comments — `ui/tools/version-guard.mjs:105`,
`ui/src/app/shell/rail.spec.ts:219`, `ui/tools/navigation.test.mjs:137`, `ui/tools/strings.test.mjs:94`
— and that is a **sample, not the population**: the new checker's first run is what enumerates the rest.
The three test-data occurrences mirror `strings.ts`'s own `\uXXXX` escapes and must become escapes, never
transliterations, or the assertions stop matching the shipped strings.

**Recommended for Story 1.18, the Epic 1 burn-down story (Rule 17 (3)).** Seventeen entries is more than
one story can carry honestly, and one item is genuinely a story of its own: **DW-159's back-fill** —
real-browser assertions for every shell surface built in Stories 1.5 through 1.16. Its own ledger fields
are `severity: high, fix-risk: high, footprint: out-of-footprint`, and its routing note already says
"standing up a harness is CI infrastructure". Fifteen spec files' worth of surfaces re-asserted against a
real runtime is multi-day work whose only prerequisite — a harness and a container serving the bundle —
this story delivers. Folding it in here would swell a story that already carries five acceptance blocks,
a new web application, a new install-path invariant and a new build system. `1.18` is the next free
number under Epic 1 (`1.9` is taken, so Rule 17's conventional `N.9` is unavailable); chartering it is
the lead's call at the burn-down gate, not this story's.

**Decision (overnight) — readiness reports the `failed` state but never the failing step.** DW-2's guard
line asks for "a fourth state 'install failed' with the failing step". AD-45 forbids "anything that aids
reconnaissance", and a step name is internal detail handed to an anonymous caller. The substance of DW-2
— that a failed install is distinguishable from one that never started — is met by the state alone. The
failing step stays on the version row, in the container logs, and in AD-45's authenticated deeper health
view. Note the disclosure is not new: `OnPreDispatch` already evaluates the install gate **before**
identity (`Router.cls:229`), so an anonymous caller can distinguish `failed` today from the 503 slug.

**Decision (overnight) — each application declares its own matching role in the roster.** AD-45 says
readiness carries "the same privilege floor as the shell (AD-21)". Reusing `OcuPilotShell` would be one
fewer object but leaves a role named for one application matched by another, and keeps the role list a
literal. Declaring `matchRole` per roster application makes the floor data, makes the install-time
assertion ("exactly these three applications, each carrying exactly the role the roster declares and
nothing else") generic, and is the same iteration DW-192 requires. The readiness role's resource set is
byte-identical to the shell's: read on the install namespace's code database and nothing else.

**Decision (overnight) — the smoke script's assertions live in `Install/Smoke.cls`, with one thin shell
entry point.** AD-45 says the smoke path is owned by `Install/`, which is an ObjectScript package, and
requires CI's run and Epic 17's clean-clone run to be "the same script with the same assertions, differing
only in what created the instance". Assertions that run *inside* the instance make that literally true:
`scripts/smoke.sh` only locates an instance and maps a verdict to an exit code. `Install.Smoke` ships
(it is in `OcuPilot.PKG`, not the test scope), so an operator can ask a running instance the same
question CI asks.

**Decision (overnight) — `container-health.sh` is not rewritten to call readiness.** AD-45 calls the smoke
path "also the health check", but the pinned image ships no HTTP client (verified, Story 1.4), which is
why the probe shells `iris session` today. Readiness and the health check read the **same** `GateStatus()`
ladder, so they cannot disagree; a test pins that equality. Rewriting the probe would trade a working
check for a curl that does not exist.

**Decision (overnight) — CI asserts the workflow as text, and its first real run is the owner's.** This
story may not push, so no GitHub run can exist when it closes. The falsifiability substitute is three
things, none of which needs a push: `ci.test.mjs`'s equality in both directions between declared gates and
`run:` commands (a gate deleted from either side is red), every gate command executed locally and recorded
in `## Verification`, and each gate reporting non-zero counts so a run over an empty population is itself
a failure. There is no YAML parser in this toolchain and none is added; `compose.test.mjs` already
established text assertions over YAML, and its own review found four hook mutations that passed text pins
— so the assertions here are over structure-bearing strings and over **absences** (`continue-on-error`,
`|| true`, `secrets.`, publish actions), which a text pin catches reliably.

**NFR tripwire check (Rule 5) — passes, no amendment sought.** NFR-9 ("Install, upgrade and the Docker
start path are safe to repeat") is measurable: install twice on a throwaway and compare `StateFingerprint`.
No NFR states a CI wall-clock budget, so none is contradicted by a container-bearing job; NFR-1's two- and
ten-second budgets are user-facing and unrelated. NFR-11 (desktop Chrome is the tested browser) is what
the browser harness is chosen to satisfy. NFR-13 names both Community editions, which the images job
exercises; the epic's own deferral of the plain-Community **install** path is honoured by compiling and
probing there rather than installing.

**Escalated planning-artifact defects, planned around, not resolved here.** **DW-126** (EXPERIENCE.md
publishes no Fixed-strings rows for several rendered surfaces) and **DW-139** (DESIGN.md and
EXPERIENCE.md diverge with no precedence rule) are the owner's call at the decision sheet. This story is
planned to render **no new user-facing copy**: readiness is a machine surface, the smoke report and CI
output are developer text, and the browser spec asserts existing strings. Neither entry therefore binds
it, and neither is resolved by editing a planning document.

## Verification

**What runs live and what needs a throwaway.** Read-only, idempotent work — compiling into `HSCUSTOM`,
running `%UnitTest` classes, SQL probes, `iris_webapp_get` reads — is safe against the live `ocupilot`
container (web 52774, SuperServer 1973), and **every IRIS MCP call passes `server: "ocupilot-iris"`**.
Everything that starts, installs into, or tears down an instance runs on a **throwaway** per
`README.md:357-409`: its own project and container name, its own ports (never 52774/1973), its own scratch
volume, `up -d --wait` then `down -v`, and the scratch directory removed. **Never run `docker compose up`,
`down`, `restart` or `down -v` against this repository's compose file.** `ps`, `logs`, `exec` and `cp` are
safe against the live container (`cp` writes as root — clean a temp copy with `exec -u root`). Never
create, delete, mount or dismount a namespace or database on the live instance; never modify, lock or
expire a real account; never end a browser session the tests did not mint. Specifically: the provenance
refusal, the three-application install, the uninstall path, the smoke script, the browser spec and the
system-namespace start-hook refusal are **throwaway only**; the readiness handler's unit tests, the
checker rules, the client tests and the wiring test run anywhere.

**Test-runner discipline (DW-54).** `mcp__iris-dev__iris_execute_tests` — **one test class per tool call,
one call per message, awaited; never two in a message, and never re-submitted on a client-side timeout.**
A timeout is not a failed run: wait, then read `%UnitTest_Result` with the numeric-run-index probe. The
2026-09-11 incident behind this rule cost a human restart.

**Commands:**
- `cd ui && npm run build` — expected: exit 0; the five `prebuild` checkers pass and print their counts.
- `cd ui && npm test` — expected: green, including the new `ci.test.mjs`, `client-lint.test.mjs` and probe-timeout cases.
- `cd ui && npm run test:browser` — expected: green against a throwaway container (never the live one).
- `uv run scripts/check-objectscript.py` — expected: exit 0 after the four new rules and the string-literal sweep they find.
- `uv run scripts/test_check_objectscript.py` — expected: green, including the new fixture-tree cases.
- `bash scripts/lint-docs.sh` — expected: clean, for the README change.
- `bash scripts/smoke.sh` against the throwaway's host and port — expected: exit 0, one line per check, non-zero executed count, the pending list naming its epics.
- `docker manifest inspect intersystems/iris-community:2026.2` — expected: the tag resolves; run **before** it is written into the workflow, and read-only (it starts no container).
- `mcp__iris-dev__iris_execute_tests`, `server: "ocupilot-iris"`, one class per call: `OcuPilot.Test.Readiness`, `OcuPilot.Test.Provenance`, `OcuPilot.Test.WebApp`, `OcuPilot.Test.Installer`, `OcuPilot.Test.Manifest`, `OcuPilot.Test.InstallNamespaceSource`, `OcuPilot.Test.GatewayGapIpmPath`, `OcuPilot.Test.Wire`, `OcuPilot.Test.GateLadder`. Confirm each against `%UnitTest_Result` before reporting it green.
- 🚫 Do not `git commit`, `git push`, `git reset` or `git rebase`, and run nothing that mutates a remote or triggers CI.

**Pinning tests (Rule 19).** One demonstrated mutation per criterion: apply it, observe red, revert, and
confirm `git status --short` and `git diff --stat` are unchanged.

- Three roster applications install with their declared properties and roles, from one roster edit (**DW-192, DW-199**) → `src/OcuPilot/Test/WebApp.cls`, `src/OcuPilot/Test/Manifest.cls`. mutation: _(implement stage)_
- A foreign application is refused, and uninstall removes only what install created (**DW-94**) → `src/OcuPilot/Test/Provenance.cls`. mutation: _(implement stage)_
- `Uninstall` refuses from a namespace the guard rejects (**DW-191**) → `src/OcuPilot/Test/InstallNamespaceSource.cls`, updated from pinning the old behaviour. mutation: _(implement stage)_
- Readiness reports the four states and nothing more, anonymously, and never names the failing step (**DW-2**) → `src/OcuPilot/Test/Readiness.cls` plus the anonymous over-the-wire case in `src/OcuPilot/Test/Wire.cls`. mutation: _(implement stage)_
- Readiness and `container-health.sh` read the same gate ladder → `src/OcuPilot/Test/Readiness.cls`. mutation: _(implement stage)_
- The smoke script fails on an empty check list and on a failed install, and passes only with a non-zero executed count → `src/OcuPilot/Test/Smoke.cls` for the check list, and the throwaway run for the verdict. mutation: _(implement stage)_
- CI's declared gates equal its `run:` commands, in both directions, and no publish, `secrets.`, `continue-on-error` or `|| true` appears → `ui/tools/ci.test.mjs`. mutation: _(implement stage)_
- The ObjectScript suite runs serialized and an overlap fails the job (**DW-54**) → `ui/tools/ci.test.mjs` for the runner's wiring and a unit case over `ci-runner.mjs`'s overlap detection. mutation: _(implement stage)_
- The hook dispatches `screen-mirror.mjs --check` and no chain swallows it (**DW-184**) → `ui/tools/screen-mirror.test.mjs`, in `classic-links.test.mjs:510-552`'s shape. mutation: _(implement stage)_
- The four new ObjectScript checker rules each refuse (**DW-35, DW-43**, epic AC4) → `scripts/test_check_objectscript.py` fixture trees. mutation: _(implement stage)_
- The two new client checker rules each refuse — CDN reference, non-ASCII string literal (**DW-43**, epic AC4) → `ui/tools/client-lint.test.mjs`. mutation: _(implement stage)_
- The generated manifest is parsed as XML, not only compared as bytes (**DW-197**) → `src/OcuPilot/Test/Manifest.cls`. mutation: _(implement stage)_
- The start hook refuses a system namespace before `LoadDir` compiles anything (**DW-195**) → `ui/tools/compose.test.mjs`, updated from pinning the current ordering. mutation: _(implement stage)_
- The gateway-gap report reads the provenance record, not the per-run array (**DW-198**) → `src/OcuPilot/Test/GatewayGapIpmPath.cls`, updated from pinning the current message. mutation: _(implement stage)_
- The probe aborts at its timeout and the chain continues (**DW-167**) → `ui/tools/refresh-connectivity.wire.test.mjs` or a sibling, with a fetch seam that never resolves. mutation: _(implement stage)_
- The shell renders with real layout, a deep link resolves, and silent-first sign-in completes in headless Chrome (**DW-159**, harness half) → the one browser spec, against a throwaway. mutation: _(implement stage)_
- **Known limitation, recorded rather than claimed:** no GitHub Actions run can exist when this story closes, because the story may not push. The workflow's correctness rests on the wiring test, on every gate command having been run locally, and on each gate's non-zero counts. The first real run is the owner's.

**Ledger (`owned_ledger=DW-2, DW-35, DW-43, DW-50, DW-54, DW-94, DW-159, DW-167, DW-184, DW-191, DW-192,
DW-193, DW-195, DW-196, DW-197, DW-198, DW-199`).** Sixteen addressed by the tasks and acceptance criteria
above; **DW-43**'s comment half declined with the Rule 14 exemption as the reason; **DW-159** split, with
the back-fill recommended for Story 1.18.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
