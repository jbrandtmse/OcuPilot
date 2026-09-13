---
title: 'Story 1.17: The smoke script, the readiness endpoint and CI'
type: 'feature'
created: '2026-09-13'
status: 'done'
baseline_revision: '09aeea5fd2510dbf8d183697a50414b9b8d86dc0'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/README.md'
warnings: ['oversized']
deferred:
  - summary: >-
      CI's `npx puppeteer browsers install chrome` step is the one gate command never executed as
      written here.
    evidence: |-
      This sandbox's puppeteer download extracts without its Frameworks directory, so the browser
      spec was verified against a system Chrome through the OCUPILOT_BROWSER_EXECUTABLE override.
      The spec and the throwaway it drives are verified (4/4, red under a layout mutation); what
      is unverified is that the pinned download works on a Linux runner. It surfaces as a failed
      install step on the workflow's first real run, which is the owner's.
    location: >-
      .github/workflows/ci.yml (instance job)
    severity: low
  - summary: >-
      `scripts/lint-docs.sh` runs `npx --yes markdownlint-cli2`, unpinned and fetched from the
      network, while every other tool this story touches is pinned exactly.
    evidence: |-
      Pre-existing: lint-docs.sh is not in this diff. CI now runs it on every change, so a
      markdownlint-cli2 release can turn the document gate red with no change to this repository.
      Everything else CI runs is pinned (puppeteer 24.24.0, typescript 6.0.3, Node 22.22.3, the
      2026.2 image tag) and ci.test.mjs asserts those pins.
    location: >-
      scripts/lint-docs.sh:31
    severity: medium
  - summary: >-
      `OcuPilot.Install.Smoke.Port()` assumes the OcuPilot applications answer on the instance's
      own configured web-server port at localhost.
    evidence: |-
      For an instance fronted by an external Web Gateway — the normal production shape —
      Config.Startup.WebServerPort is not where /ocupilot answers, so every HTTP check would fail
      on a correctly installed instance. The class ships and is offered to operators ("an operator
      can ask a running instance the same question CI asks"), and the constraint is documented
      nowhere. Not reachable from CI or Epic 17, both of which drive a container that serves its
      own port.
    location: >-
      src/OcuPilot/Install/Smoke.cls (Port)
    severity: medium
  - summary: >-
      CLAUDE.md's "Running and verifying" section still says "TODO once code exists: the Angular
      build and test invocations" and names lint-docs.sh as one of only two mechanical gates.
    evidence: |-
      That TODO is what this story closes, and CLAUDE.md is the file the next agent reads first:
      it does not mention `npm test`, `scripts/smoke.sh`, `scripts/ci-throwaway.sh`, or that CI
      now exists. Deferred rather than patched because the fix edits an agent-context file, which
      this stage routes to the lead.
    location: >-
      CLAUDE.md
    severity: medium
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

- Three roster applications install with their declared properties and roles, from one roster edit (**DW-192, DW-199**) → `src/OcuPilot/Test/WebApp.cls`, `src/OcuPilot/Test/Manifest.cls`. mutation: readiness's `matchRole` changed to `OcuPilotReadinessMUT` in `Install/Roster.cls` and re-installed → `Test.Manifest:TestRosterDeclaresTheProductionApplications` ("readiness carries its own, not the shell's") and `Test.WebApp:TestReadinessApplicationSettings` ("exactly one matching role, its own") both red.
- The install-time assertion refuses an application that has lost its declared matching role (**AD-21**, the matrix's "Readiness with no privilege floor" row) → `src/OcuPilot/Test/WebApp.cls`, through `Test/InstallerProbe.AssertOneApplication`. Added at the Matrix Test Audit: `AssertApplications` had no test at all, and on a healthy instance its refusal arms are unreachable end-to-end because the ensure steps have just made every state it refuses impossible. mutation: the `MatchRoles` comparison deleted from `AssertApplications` → the mismatch assertions red, the positive control green. Deleting the declared role produces one state, not two (`Security.Roles.Delete` strips the name from the application; `Modify` refuses a dangling one), and both guards refuse it — so removing either alone leaves the install still refusing, which is what a last-line assertion is for.
- A foreign application is refused, and uninstall removes only what install created (**DW-94**) → `src/OcuPilot/Test/Provenance.cls`. mutation: the `RefuseForeignApplications` call deleted from `Installer.Install` → `Test.Provenance:TestForeignApplicationAtARosterPathIsRefusedAndNothingIsCreated` red on "nothing was created" and "not even the first application the loop would have reached" — install still refuses, but only after making the database and the shell application, which is the ordering this row asserts.
- `Uninstall` refuses from a namespace the guard rejects (**DW-191**) → `src/OcuPilot/Test/InstallNamespaceSource.cls`, updated from pinning the old behaviour. mutation: the `GuardInstallNamespace` call deleted from `Installer.Uninstall` → all four assertions of `TestUninstallIsRefusedByTheSameGuardAsEveryOtherEntryPoint` red, the probe shell application removed by the unguarded call.
- Readiness reports the four states and nothing more, anonymously, and never names the failing step (**DW-2**) → `src/OcuPilot/Test/Readiness.cls` plus the anonymous over-the-wire case in `src/OcuPilot/Test/Wire.cls`. mutation: `failed` folded into `installing` in `Api/Readiness.Readiness` → `TestFailedIsItsOwnStateAndNamesNoStep` red on DW-2's distinguishability. The no-step half was observed live: on a throwaway whose version row carried `FailingStep='EnsureDatabase'`, the anonymous body was `{"installed":false,"version":"","state":"failed"}`, the step nowhere in it.
- Readiness and `container-health.sh` read the same gate ladder → `src/OcuPilot/Test/Readiness.cls`. mutation: `Api/Readiness.GateStatus`'s delegation replaced with `Quit "upgraderequired"` → `TestReadinessAndTheHealthCheckReadTheSameLadder` and `TestAnonymousRequestOverTheWire` both red. A differing constant, not a matching one: the two agree on whatever state the instance happens to be in.
- The smoke script fails on an empty check list and on a failed install, and passes only with a non-zero executed count → `src/OcuPilot/Test/Smoke.cls` for the check list, and the throwaway run for the verdict. mutation: the `tExecuted > 0` clause dropped from `Install/Smoke.Render`'s verdict → `TestZeroExecutedChecksIsAFailure` (both arms) and `TestPendingNeverMovesTheVerdict` red. Verdict half, on a throwaway with the version row forced `failed`: `scripts/smoke.sh` exited 1 naming readiness first (executed=9 passed=5 failed=4), and `wait-readiness.sh` exited 1 in 0 s rather than waiting out its 120 s budget.
- CI's declared gates equal its `run:` commands, in both directions, and no publish, `secrets.`, `continue-on-error` or `|| true` appears → `ui/tools/ci.test.mjs`. mutation: three, one per direction and one for the absences — `bash scripts/lint-docs.sh` deleted from `ci.yml` → both equality tests red naming it; an undeclared `run:` step added → "every run: command in the workflow is a declared gate" red; `continue-on-error: true` added → "no step can fail without failing the job" red.
- The ObjectScript suite runs serialized and an overlap fails the job (**DW-54**) → `ui/tools/ci.test.mjs` for the runner's wiring and a unit case over `ci-runner.mjs`'s overlap detection. mutation: `overlappingRuns` made to compare each run only with the one before it → "DW-54: every overlapping pair is reported, not only the neighbouring one" red.
- The hook dispatches `screen-mirror.mjs --check` and no chain swallows it (**DW-184**) → `ui/tools/screen-mirror.test.mjs`, in `classic-links.test.mjs:510-552`'s shape. mutation: the hook's `screen-mirror.mjs --check` dispatch replaced with `true` → "the mirror drift check is named in prebuild, in prestart and in the pre-commit hook (DW-184)" red.
- The four new ObjectScript checker rules each refuse (**DW-35, DW-43**, epic AC4) → `scripts/test_check_objectscript.py` fixture trees. mutation: all four rule functions made to return immediately → 9 of the harness's 41 cases red, spread across all four rule classes, plus the whole-tree production case.
- The two new client checker rules each refuse — CDN reference, non-ASCII string literal (**DW-43**, epic AC4) → `ui/tools/client-lint.test.mjs`. mutation: a `<script src="https://cdn.example.com/...">` added to `ui/src/index.html` → `client-lint` exit 1 at `src/index.html:8 [no-off-origin-url]`, and `npm run build` exit 1 with it; a literal em dash added to a `core/strings.ts` string literal → exit 1 at `[no-literal-non-ascii] U+2014`, naming the escape to use.
- The generated manifest is parsed as XML, not only compared as bytes (**DW-197**) → `src/OcuPilot/Test/Manifest.cls`. mutation: `</Module>` dropped from the committed `module.xml` → `TestTheCommittedManifestParsesAsXml` red with IRIS's own `ERROR #6301 ... line 58 offset 5`, and `ipm-manifest.mjs --check` exit 1 naming the fault at offset 2772 — both readers refuse the same document. The mount that lets the ObjectScript half run at all is pinned with it: `module.xml` dropped from `ci-throwaway.sh`'s volumes → `ci.test.mjs` red.
- The start hook refuses a system namespace before `LoadDir` compiles anything (**DW-195**) → `ui/tools/compose.test.mjs`, updated from pinning the current ordering. mutation: the `SYSTEM:*)` branch deleted from `container-start.sh` → "a system-namespace override is refused in the resolution session, before LoadDir (DW-195)" red.
- The gateway-gap report reads the provenance record, not the per-run array (**DW-198**) → `src/OcuPilot/Test/GatewayGapIpmPath.cls`, updated from pinning the current message. mutation: `ReportGatewayGap`'s `GuardedUnreportedForProfile` read replaced with `$$$OK` → both `Test.GatewayGapIpmPath` tests red, the recorded application's gap never named.
- The probe aborts at its timeout and the chain continues (**DW-167**) → `ui/tools/refresh-connectivity.wire.test.mjs` or a sibling, with a fetch seam that never resolves. mutation: `ApiService.buildInit` stopped passing the abort signal → "DW-167: the probe carries an abort timeout" red on "carried an abort signal, which is what a half-open socket needs". Chosen over deleting the timer because it fails fast rather than hanging the run.
- The shell renders with real layout, a deep link resolves, and silent-first sign-in completes in headless Chrome (**DW-159**, harness half) → the one browser spec, against a throwaway. mutation: `app-rail .ocu-rail{display:none !important}` appended to the served bundle's stylesheet on the throwaway → "the shell loads with no console error and lays out the rail and the side bar" red with `the rail is laid out: {"width":0,"height":0}` — the zeros jsdom answers for every element, here meaning what they say.
**Added at review** (each demonstrated the same way):

- Uninstall leaves a kept application's **privilege floor** intact, not just its existence (**DW-94**, AD-21) → `src/OcuPilot/Test/Provenance.cls`. mutation: the `'$Data(tRemovedKeys(tRKey)) Continue` guard dropped from `Uninstall`'s role loop → "still carries the matching role it needs to answer at all" red. The role loop deleted every declared role unconditionally while the application loop skipped unrecorded ones, and deleting a role strips it from every application matching it — so an application uninstall deliberately kept came back with `MatchRoles` empty and a 500 `<PROTECT>` for anonymous callers.
- An unmapped path under the readiness application is OcuPilot's one error envelope (**AD-12**) → `src/OcuPilot/Test/Readiness.cls`. mutation: `Api/Readiness.ReportHttpStatusCode` deleted → the superclass writes its own document and the envelope assertion goes red. Deleting only its 404 arm does **not** go red: the `Else` arm resolves the same slug and code, which the test's own comment now records rather than assumes.
- CI's declared gates equal its `run:` commands **per occurrence**, and every `uses:` action is allowlisted → `ui/tools/ci.test.mjs`. mutation: one of the two `npm ci` steps deleted → the multiset equality red. The previous set comparison de-duplicated, so `npm ci` and `npm run build` — which run in two jobs each — could lose an occurrence with both directions still green.
- `wait-readiness.sh` and `smoke.sh` map their outcomes to the exit codes CI's verdict rests on → `ui/tools/ci.test.mjs`. mutations: the `"state":"failed"` branch deleted from `wait-readiness.sh` → red; `smoke.sh`'s no-verdict arm changed to `exit 0` → red. Neither script's body was read by any test before.
- The throwaway refuses the live container's ports, name and project, and its generated start path equals `docker-compose.yml`'s → `ui/tools/ci.test.mjs`. mutations: the live-port refusal deleted → red; the throwaway's `restart:` drifted → red.
- The ObjectScript checker's production scan covers a real population → `scripts/test_check_objectscript.py`. mutation: `SCAN_ROOTS` pointed away from the source tree → the new floor red, where all 41 previous cases stayed green over zero files.
- **Known limitation, recorded rather than claimed:** no GitHub Actions run can exist when this story closes, because the story may not push. The workflow's correctness rests on the wiring test, on every gate command having been run locally, and on each gate's non-zero counts. The first real run is the owner's.

**Ledger (`owned_ledger=DW-2, DW-35, DW-43, DW-50, DW-54, DW-94, DW-159, DW-167, DW-184, DW-191, DW-192,
DW-193, DW-195, DW-196, DW-197, DW-198, DW-199`).** Sixteen addressed by the tasks and acceptance criteria
above; **DW-43**'s comment half declined with the Rule 14 exemption as the reason; **DW-159** split, with
the back-fill recommended for Story 1.18.

## Review Triage Log

### 2026-09-13 — Review pass

- verdicts: 56 findings — high 2, medium 29, low 24, false 1, maybe-false 0
- findings:
  - `[high]` `[patch]` Uninstall deletes every declared matching role regardless of provenance (blind-hunter) — confirmed at `Installer.cls`: the application loop skips unrecorded paths, the role loop did not, and `Security.Roles.Delete` strips the name from every application matching it, so an application uninstall deliberately keeps came back with `MatchRoles` empty and a 500 `<PROTECT>` for anonymous callers. Fixed with a `tRemovedKeys` guard; pinned by a new `Test/Provenance.cls` case, mutation demonstrated.
  - `[high]` `[patch]` Same defect, filed independently (edge-case-hunter) — grouped with the row above; same fix.
  - `[medium]` `[patch]` `container-start.sh`'s `$Parameter` read of `Installer.SYSTEMNAMESPACES` is dead (blind-hunter) — confirmed: it runs while `$NAMESPACE` is `%SYS`, where OcuPilot's classes are invisible, and the ordering cannot be changed because the decision selects the namespace. Dead branch deleted, literal kept, comment corrected, and `compose.test.mjs` now holds the literal equal to the parameter and forbids the dead form returning.
  - `[medium]` `[patch]` Same, filed independently (edge-case-hunter) — grouped with the row above.
  - `[medium]` `[patch]` `ci-runner`'s overlap check can never fire (blind-hunter) — confirmed: `shell()` is `spawnSync`, so this process's runs cannot overlap. Claim corrected to what it is, and a check that *can* fire added: non-consecutive `%UnitTest` run indices, which detect a concurrent writer against the shared instance.
  - `[medium]` `[patch]` Discovery query matches direct superclasses only (blind-hunter) — confirmed against the instance: `Super` is direct, `PrimarySuper` holds the chain. Query switched to `PrimarySuper [ '~%UnitTest.TestCase~'`.
  - `[medium]` `[patch]` Discovery floor is only "more than zero" (blind-hunter) — `ci-runner` now compares what the instance offered against the test classes the checkout carries and fails naming any it did not offer.
  - `[medium]` `[patch]` The throwaway's copied compose keys are pinned by nothing although the script says they are (blind-hunter, verification-gap) — `ci.test.mjs` now holds `restart`, `command` and the three healthcheck keys equal to `docker-compose.yml`'s; mutation demonstrated.
  - `[medium]` `[patch]` No test covers the throwaway's or the image probe's safety refusals (blind-hunter) — the live-port, live-name and floating-tag refusals are now pinned; mutation demonstrated.
  - `[medium]` `[patch]` The `run:` equality does not constrain `uses:` (blind-hunter) — a closed `DECLARED_USES` allowlist added, which is the other way a release action arrives.
  - `[medium]` `[defer]` `lint-docs.sh` runs an unpinned `npx markdownlint-cli2` (blind-hunter) — real and now run on every change by CI, but `lint-docs.sh` is not in this diff; deferred with evidence.
  - `[medium]` `[patch]` `docker-compose.yml` lacks the `module.xml` mount, so DW-197's parse stays a permanent skip on this project's own container (blind-hunter) — mount added there as well as in the throwaway.
  - `[medium]` `[patch]` `Test/Provenance.cls` and `Test/GatewayGapIpmPath.cls` headers claim nothing touches production while `OnBeforeOneTest` installs it (blind-hunter) — both headers corrected to say what the setup does and why it is needed.
  - `[medium]` `[patch]` `Install/Smoke.cls` promises "a smoke run that cannot find the declared path says so" and does not (blind-hunter, edge-case-hunter) — readiness and shell checks now fail explicitly naming the unreadable roster.
  - `[medium]` `[patch]` Readiness sets no cache directive (blind-hunter) — `Cache-Control: no-store` added and verified live on a throwaway; a cached `{"installed":true}` outliving its state is the one thing this endpoint exists to prevent.
  - `[medium]` `[patch]` No test covers the shell halves of `smoke.sh` or `wait-readiness.sh` (blind-hunter, verification-gap) — both now text-pinned in `ci.test.mjs`; mutations demonstrated.
  - `[medium]` `[defer]` CLAUDE.md still carries "TODO once code exists" and names only two mechanical gates (blind-hunter) — real and load-bearing for the next agent, but the fix edits an agent-context file, which this stage routes to defer.
  - `[medium]` `[patch]` `ci-unit-test.sh` reads the highest run index without comparing it to the one before the run (edge-case-hunter) — confirmed misattribution risk: a class that recorded nothing reported the previous class's counts. `tBefore` captured and compared.
  - `[medium]` `[patch]` `RunTest`'s `%Status` was set and never read (edge-case-hunter) — now carried in the marker as a sixth field, and a refused run is its own failing outcome in `classifyRun`.
  - `[medium]` `[patch]` `wait-readiness.sh` has no `upgraderequired` branch (edge-case-hunter) — confirmed it would wait out the whole budget and report a timeout; branch added, exits 1.
  - `[medium]` `[patch]` `ReportGatewayGap`'s legacy one-argument callers now resolve to the production profile (edge-case-hunter, verification-gap) — confirmed at `Test/Version.cls` and `Test/GatewayIni.cls`; both now pass `"probe"`.
  - `[medium]` `[patch]` The only document-level manifest assertion counts a skip as a pass (verification-gap) — addressed by making it run rather than by failing the skip: both compose files now mount `module.xml`, and `ci.test.mjs` pins the mount. Verified on a throwaway that the parse executes eight real assertions, and red under a malformed manifest.
  - `[medium]` `[patch]` The checker's production-tree case passes over an empty scan (verification-gap) — a population floor added to the harness; mutation demonstrated (`SCAN_ROOTS` pointed away → red, where all 41 previous cases stayed green).
  - `[medium]` `[patch]` `Api/Readiness.ReportHttpStatusCode` is a copied three-branch method no test runs (verification-gap) — a 404-envelope case added. The mutation also disproved part of the filed claim: deleting only the 404 arm is *not* red, because the `Else` arm resolves the same slug and code. Recorded at the test rather than left as an assumption.
  - `[medium]` `[patch]` No pinning row for the readiness-wait acceptance criterion (verification-gap, Rule 19) — `wait-readiness.sh` pinned and a row added to `## Verification`.
  - `[medium]` `[patch]` No pinning row for the images acceptance criterion, and `ci-image-compile.sh` had never been executed (verification-gap, Rule 19) — run against **both** editions: plain `intersystems/iris-community:2026.2` compiles all 123 classes (into `USER`) and answers admin API v2, as does the Health edition. All three of its guards exercised.
  - `[medium]` `[patch]` `runCommands()` de-duplicated, so the both-directions claim was false for `npm ci` and `npm run build` (verification-gap) — duplicates kept, declared list carries one entry per occurrence, multiset equality added; mutation demonstrated.
  - `[low]` `[patch]` The provenance-read-failure warn said no application would be removed while roles still were (blind-hunter) — reworded with the fix above.
  - `[low]` `[reject]` `AssertApplications` does not re-read the matching role's `Resources` (blind-hunter) — real but not worth the surface: `EnsureApplicationRoles` asserts and repairs the resource set immediately before, and `Test/WebApp.cls` pins it independently; the matrix row this method serves is about the role's presence.
  - `[low]` `[patch]` The floating-tag guard misses a tagless reference (blind-hunter) — confirmed, `intersystems/iris-community` needs no colon; a last-segment check added and exercised (exit 2).
  - `[low]` `[patch]` No `timeout-minutes` on any job (blind-hunter) — 20/45/30 added; a hung instance job would otherwise burn the six-hour default.
  - `[low]` `[reject]` The `gates` job downloads a browser it never uses (blind-hunter) — real waste, but the fix adds environment configuration to a job for a cost nobody meets in everyday use.
  - `[low]` `[patch]` "over 14 rule(s)" is a hard-coded literal (blind-hunter) — both numbers now derived; the file count is the ObjectScript population the rules actually read, not the scan-root size.
  - `[low]` `[patch]` `ManifestPath()`'s second candidate resolves to the first (blind-hunter) — dead candidate removed.
  - `[low]` `[patch]` `CleanProbe()` hard-codes the three probe paths (blind-hunter) — derived from `Roster.Keys()` and `ProbeApplicationPath()`, so DW-192's "one roster edit" holds of the suite that pins it.
  - `[low]` `[reject]` `Roster.Keys()` collapses a read failure into "declares no application" (blind-hunter) — the refusal text already hedges ("asserts nothing it cannot read"); returning a `%Status` touches every caller for a message nuance.
  - `[low]` `[reject]` Unauthenticated request amplification on the escalated gate read (blind-hunter) — no named reachable harm: one indexed read per request, on an instance already serving the shell anonymously.
  - `[low]` `[defer]` `Smoke.Port()` assumes the instance's own web-server port (blind-hunter) — real for a Gateway-fronted instance and documented nowhere; deferred with evidence, out of reach of CI and Epic 17, which both drive a container serving its own port.
  - `[low]` `[reject]` `WantFromRoster`'s `pDescription` output is dead for the production caller (blind-hunter) — removing it changes a signature and its tests for no behavioural gain.
  - `[low]` `[patch]` `Smoke.Render`'s "Left-padded" comment contradicts the code (blind-hunter) — corrected; the code pads right.
  - `[false]` `[reject]` The lockfile's `@types/jasmine` removal is unremarked noise (blind-hunter) — checked: `ui/package.json` carries no jasmine dependency at all, so the lockfile was stale and its removal is a correct sync, not a change this story introduced.
  - `[low]` `[reject]` Torn read between `GateStatus()` and `VersionStamp()` (edge-case-hunter) — two reads microseconds apart; the worst case is an empty version beside an installed state, and the body's own field-agreement rule is derived from one value.
  - `[low]` `[reject]` `GuardedMarkGatewayReported`'s status is discarded (edge-case-hunter) — a failed mark re-emits one informational line on the next install; `ReportGatewayGap` is documented never to fail an install.
  - `[low]` `[patch]` `BrowserContext.cookies()` ignores the origin argument (edge-case-hunter) — confirmed against the API; the filter is now applied in the spec.
  - `[low]` `[patch]` `--user` without `--password` signs in with an empty password (edge-case-hunter) — refused as the caller error it is.
  - `[low]` `[reject]` `--project`/`--service` without `--compose-file` are silently ignored (edge-case-hunter) — a confusing run, not a wrong one; the fix adds branches for a case no caller in this repository makes.
  - `[low]` `[reject]` A trailing flag with no value throws instead of printing usage (edge-case-hunter) — developer-only and immediately obvious at the point of the mistake.
  - `[low]` `[reject]` The DW-94 acceptance criterion says every unrecorded application is refused; the code adopts one carrying the declared dispatch class (edge-case-hunter, intent-alignment) — the behaviour is correct and necessary: refusing on the absence of a row alone would refuse install on this repository's own container and on every IPM install, where the applications exist before `Install()` runs. Documented at `RefuseForeignApplications`, `EnsureWebApplication` and in README; recorded as a Decision in `## Spec Change Log`.
  - `[low]` `[reject]` Tests pin the application count as 3 while DW-192 says a fourth is one roster edit (edge-case-hunter) — the count pin is a deliberate shape assertion and its mutation line says so.
  - `[low]` `[reject]` The spec says `smoke.sh` takes host/port and it takes neither (edge-case-hunter) — the fix is either a spec edit or new public surface; the container and compose forms cover every caller this story has.
  - `[low]` `[patch]` `## Auto Run Result` still read `ready-for-dev` (verification-gap) — written at finalize.
  - `[low]` `[reject]` R3-versus-R4 reading of DW-94's boundary (intent-alignment) — the one reading-level divergence the auditor found; same disposition as the row above, recorded as a Decision rather than changed.

## Spec Change Log

- **Decision (overnight) — "a web application install did not create" is tested by the provenance
  record *or* by the dispatch class the roster declares.** The matrix row for DW-94 reads "exists
  with no provenance row → install refuses", and the implementation refuses only when the
  application also dispatches to something other than OcuPilot's own declared class. Taken
  literally, the row would refuse install on every instance that predates the provenance record —
  this repository's own container among them — and on the entire IPM path, where IPM's
  `<WebApplication>` elements create the applications in `Activate` before the `When="After"`
  `<Invoke>` runs `Install()` at all. The intent's own verb is "did not create", and an
  application at OcuPilot's path dispatching to OcuPilot's declared class is one OcuPilot created;
  the row's "no provenance row" is a proxy for that which is imprecise on a first upgrade. Such an
  application is recorded `adopted` and repaired; anything else is refused naming the path, the
  declared class and the class found. Two reviewers raised the divergence independently, and both
  are recorded as rejected findings above.

## Auto Run Result

**What was built.** A readiness endpoint on a third unauthenticated web application at
`/api/ocupilot/readiness/`, answering `{installed, version, state}` and nothing else. A provenance
record (`OcuPilot.Kernel.State.WebApp`) that makes "install created this" a fact on the instance,
with install refusing a foreign application at any roster path and uninstall removing only what it
created. The installer, the generated manifest, the state fingerprint and the install-time
assertion now **iterate** the roster instead of naming `shell` and `api`, so the third application
arrived as one roster edit. `Install/Smoke.cls` plus `scripts/smoke.sh`, where zero executed checks
is a failure. `.github/workflows/ci.yml` with three jobs, and the supporting scripts and wiring
test that make each gate falsifiable.

**Files changed** — 57 files, +7,686 / −334. New: `Api/Readiness.cls`, `Install/Smoke.cls`,
`Kernel/State/WebApp.cls`, `Test/{Readiness,ReadinessFixture,Provenance,Smoke}.cls`,
`.github/workflows/ci.yml`, `scripts/{smoke,wait-readiness,ci-throwaway,ci-unit-test,ci-image-compile}.sh`,
`ui/tools/{ci-runner.mjs,ci.test.mjs}`, `ui/browser.config.mjs`, `ui/browser/shell.browser-spec.mjs`.
Changed: `Install/{Installer,Roster}.cls` (roster iteration, provenance, `Uninstall`'s namespace
guard); six existing test classes moved from pinning old behaviour to pinning the new;
`check-objectscript.py` +4 rules, `client-lint.mjs` +2 rule families, `ipm-manifest.mjs` XML scan;
`container-start.sh` system-namespace refusal; `.githooks/pre-commit` mirror dispatch;
`api.ts`/`connectivity.ts` probe abort timeout; `docker-compose.yml` manifest mount; README.

**Review findings** — 56 findings across four layers: 2 high, 29 medium, 24 low, 1 false.
**32 patched, 3 deferred, 21 rejected.** Every row with its verdict and evidence is in
`## Review Triage Log` above. The high (both rows are the same defect, found independently) was
uninstall deleting the matching role of an application it deliberately leaves in place, stripping
that application's AD-21 privilege floor. Rejections in brief: two on `AssertApplications`'
resource re-read and `Roster.Keys()`'s failure message (already covered elsewhere, or more surface
than the harm); three on argument-validation and status-discard paths with no reachable harm; one
on request amplification; two on dead-but-harmless code whose removal changes signatures; four on
claims whose only fix edits this spec; one false (the lockfile's `@types/jasmine` removal is a
correct sync — `package.json` carries no jasmine).

**Follow-up review recommended: true.** A `high` was patched, and the specific unverified risk is
named rather than general: **the workflow has never run on GitHub Actions.** Every gate command was
executed locally and recorded below, but no job, runner, matrix expansion or `uses:` action has
been exercised as a workflow, and `npx puppeteer browsers install chrome` has not been executed as
written at all (this sandbox's download is truncated; the browser spec was verified against a
system Chrome). Patched by verdict: high 1 entry, medium 22, low 9.

**Verification.** All local: `npm run build` exit 0 with five prebuild checkers printing their
counts; `npm test` 575 tool + 184 component, 0 failed; `uv run scripts/check-objectscript.py`
0 problems over 123 ObjectScript files and 14 rules; `uv run scripts/test_check_objectscript.py`
42 tests OK; `bash scripts/lint-docs.sh` clean. Against the live `ocupilot` container (compile and
`%UnitTest` only): 123 classes compile clean, and every named suite green, confirmed against
`%UnitTest_Result` as well as the runner. On throwaway containers (own project and container name,
ports 52776/1975, scratch volume, `down -v`, all three confirmed gone with no orphan volumes):
first install on a fresh volume; readiness answering `{"installed":true,...}` anonymously over HTTP
with `Cache-Control: no-store`; `ci-runner` **38 classes, 346 tests, 0 failed, 0 overlaps, 0 foreign
runs**; `smoke.sh` exit 0 with executed=9 passed=9 pending=3, and exit 1 naming readiness first when
the version row was forced `failed`; `wait-readiness.sh` exit 1 in 0 s on that same state;
`npm run test:browser` 4/4. `ci-image-compile.sh` run against **both** editions: plain
`intersystems/iris-community:2026.2` compiles all 123 classes (into `USER`, which that edition
carries instead of `HSCUSTOM`) and answers admin API v2, as does the Health edition — NFR-13's
compile-and-probe half now has evidence rather than a plan. 25 mutations were applied, observed
red, reverted and confirmed byte-identical.

**Residual risks.** (1) The workflow's first real run is the owner's; its correctness rests on the
wiring test, on every gate command having been run locally, and on each gate reporting non-zero
counts. (2) The three `deferred:` items: the unpinned `markdownlint-cli2`, `Smoke.Port()`'s
assumption for a Gateway-fronted instance, and CLAUDE.md's stale "TODO once code exists". (3) The
live container now carries the readiness application, the `OcuPilotReadiness` role and provenance
rows — all install's own objects, created by the idempotent install path the suite exercises.

Status: done
Blocking condition: none
