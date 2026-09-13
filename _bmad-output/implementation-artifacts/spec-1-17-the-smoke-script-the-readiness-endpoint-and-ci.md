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
      CI's `npx puppeteer browsers install chrome` ran on a Linux runner and succeeded; what the
      local verification used instead is recorded here.
    evidence: |-
      Half closed by run 34773637146: `install the pinned headless browser` executed and exited 0
      on ubuntu-latest, so the pinned download works there. The `browser spec` step that would
      LAUNCH it was skipped in that run, so a launched Chrome on a runner is still unobserved;
      locally it was verified against a system Chrome through OCUPILOT_BROWSER_EXECUTABLE, this
      sandbox's puppeteer download extracting without its Frameworks directory.
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
      CLAUDE.md does not say that the `gates` job now runs once per declared Node band.
    evidence: |-
      Superseded in substance and re-scoped at rework 2. The original claim -- that CLAUDE.md
      still carried "TODO once code exists" and named no gate but lint-docs.sh -- is stale: its
      "Running and verifying" section now documents `npm test`, `npm run build`,
      check-objectscript, `scripts/smoke.sh` and CI's three jobs. What remains is that the CI
      paragraph describes `gates` as one job; after rework 2 it is a three-leg Node matrix, and
      an agent reading only CLAUDE.md will not know a band can fail on its own. Deferred rather
      than patched because the fix edits an agent-context file, which this stage routes to the
      lead.
    location: >-
      CLAUDE.md:128
    severity: low
  - summary: >-
      DW-230's reopen condition fired during this pass: the connectivity probe's abort-timeout
      test flaked once with its failing site captured.
    evidence: |-
      `ui/tools/refresh-connectivity.wire.test.mjs:308`, `calls[0].signal.aborted` `true !== false`
      -- a `probeTimeoutMs: 5` deadline firing before the assertion reads it. Green on every
      re-run here. DW-230's trailer names exactly this as `reopen_if`, and the gates matrix now
      runs the suite three times per push on runners slower than this machine, so the per-push
      chance of a red run over a working probe is three times what it was.
    location: >-
      ui/tools/refresh-connectivity.wire.test.mjs:287,308,371
    severity: medium
  - summary: >-
      `docker-compose.yml`'s own `./iris-data:/durable` mount carries the Linux ownership defect
      this pass fixed in the throwaway, and nothing pins it.
    evidence: |-
      Same cause, one mount over: the image runs as uid 51773 and a bind mount keeps the host's
      ownership, so a Linux clone whose `./iris-data` was created by the cloning user at 0755
      fails `docker compose up -d --wait` exactly as run 34773637146's throwaway did.
      `ui/tools/compose.test.mjs`'s only assertion about that mount is that the line exists.
      Out of this rework's footprint -- its two items are the CI jobs -- and unreachable for the
      owner, whose machine is macOS, where Docker Desktop maps the ownership away.
    location: >-
      docker-compose.yml:27
    severity: medium
  - summary: >-
      `ci-throwaway.sh`'s scratch-root guard admits any absolute path when `TMPDIR` is `/`, and
      the directory it guards is now removed by a root container.
    evidence: |-
      The guard is `case "$DIR" in /tmp/?*|/private/tmp/?*|"${TMPDIR:-/nonexistent-tmpdir}"?*`.
      With `TMPDIR=/` the third pattern is `/?*`, which matches every absolute path, and `down`
      then runs `rm -rf /scratch/data` as uid 0 inside a container over that directory. Pre-dates
      this pass (the guard is rework 1's); what this pass changed is that the removal it guards
      can now succeed against files the invoking user does not own. No realistic `TMPDIR=/`.
    location: >-
      scripts/ci-throwaway.sh:57-60
    severity: low
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

- [x] [Smoke] `scripts/smoke.sh:87` refuses every credential pair, so the sign-in check and the three API reads that need its token can never run, and `.github/workflows/ci.yml:99` — which calls the script with `--user _SYSTEM --password SYS` — exits 2 on its first real run. `case "$SMOKE_USER$SMOKE_PASSWORD" in *"$(printf '\n')"*)` cannot work: command substitution strips trailing newlines, so `$(printf '\n')` is the empty string and the pattern is `*""*`, which matches every input. The fix must keep a real newline in a shell variable (the `x=$(printf '\nx'); x=${x%x}` idiom, or an equivalent that survives `sh`), and it must be pinned by a test that passes an ordinary credential pair and a newline-bearing one and distinguishes them — the present guard is a refusal arm no test executed.

- [x] [CI] `gates` job, run 34773637146: `node --test tools/` fails on Node 22.22.3 with `Cannot find module .../ui/tools` (MODULE_NOT_FOUND), `fail 1` — https://github.com/jbrandtmse/OcuPilot/actions/runs/34773637146. Directory scanning for `--test` postdates Node 22, so the command that scans `tools/` on the local Node 26.8.1 tries to LOAD it as a module on 22. `version-guard` declares `^22.22.3` supported and `ci.yml` pins exactly 22.22.3, so the declared floor cannot run the project's own test command. `node --test tools/*.test.mjs` gives 584/584 on Node 26 and is portable across all three declared bands; whatever form is chosen must be pinned by something that would have caught this — a text assertion that the script does not say `--test tools/` is not that. (**DW-231**)
- [x] [CI] `instance` job, same run: `container ocupilot-ci is unhealthy` five seconds after start, exit 1, with `wait for readiness`, the ObjectScript suite, the smoke and the browser spec all skipped. Five seconds is before the first health check could run (`interval: 10s`, `start_period: 60s`), so the container was not running rather than failing a probe. The cause is not in the log because the job captures nothing on the failure path, and `tear the throwaway down` runs `if: always()` and removes the evidence. Fix both halves: add a failure-path capture (`docker compose logs`, `ps -a`) that runs before teardown, then diagnose and fix the bring-up itself against a real runner-like environment. (**DW-232**)

### Review Findings

**2026-09-13 — code review (first review, four layers, full-opus tier).** No HIGH. 14 root causes
patched in-pass, 11 ledgered. Every patch is listed under `## Verification` with its demonstrated
mutation; nothing below re-opens the story.

*Patched (in-story unless noted).*

- **AD-47 — CORS was unpinned on the readiness class.** `Test.Token` asserted
  `HandleCorsRequest = 0` on the router and the static handler only, so deleting the parameter
  from the one anonymous endpoint meant to be polled from outside left the suite green.
  `TestNeitherDispatchClassEnablesCors` → `TestNoDispatchClassEnablesCors`, three assertions.
- **AD-10 — two of `AssertApplications`' four refusal arms were executed by nothing.** The
  application-resource arm and the absent-application arm now have cases through the existing
  `AssertOneApplication` seam.
- **AD-21, DW-192 — nothing pinned what a declared matching role *grants*.** The application-level
  assertions pin that readiness carries `:OcuPilotReadiness`; only the shell role's resource set
  was asserted. `TestEveryDeclaredMatchingRoleGrantsOnlyReadOnTheCodeDatabase` derives the list
  from the roster, so a fourth application's floor is one roster edit.
- **DW-192 — `StateFingerprint`'s fold of the third application was unpinned.** The drift test
  covered the first two applications and the shell role; narrowing the loop by one key was green.
  Readiness's application and role are now drifted too.
- **DW-167 — the probe's abort timeout did not cover `/refresh`.** `request()` reaches the network
  three times and `Session.post` builds its init with no `signal`, so a half-open refresh stalled
  the probe before the timed-out read was issued — and, being single-flight, stalled every
  concurrent caller. `ApiService.renew()` bounds both refresh awaits by the caller's own timeout;
  `connectivity.ts`'s "true of every failure" claim is corrected at its origin.
- **Frozen constraint — two of the five prebuild gates reported no size.** "Every gate CI runs
  reports the size of what it looked at" is in `## Boundaries & Constraints`; `version-guard` and
  `screen-mirror` printed a bare "supported"/"up to date". Both now print a census.
- **Claim/evidence — "the admin API answers v2" was a class-existence test.** `ci-image-compile.sh`
  read `%ExistsId("%Api.Admin.Dispatch.v2")`. It now calls
  `AdminPort.HighestDispatchVersion("%Api.Admin")`, the same read the port makes at startup; run
  against **both** editions (`reported version=2`). The header, `ci.yml` and README say what is
  checked, and `ci.test.mjs` pins the arms.
- **The throwaway's port and name were five independent declarations**, one of them (`env:
  OCUPILOT_BROWSER_ORIGIN`) invisible to `runCommands()`. `ci.test.mjs` now holds them equal.
- **`ci-throwaway.sh down` ran `rm -rf "$DIR"` unguarded**, and `up` reused a stale volume. Scratch
  roots only; `up` clears first.
- **`Install/Smoke.cls` guarded 2 of 5 roster-path builders** (four layers). All five now refuse an
  unreadable roster by name, and `Render` fails closed on an outcome outside its vocabulary.
- **The non-ASCII rule silently exempted XData**, where the roster's asserted application
  descriptions live; the wire-coverage rule could be satisfied by a doc comment, and `ROUTE_RE`
  read one attribute order. All three fixed, three harness cases added (42 → 45).
- **`client-lint` still allowlisted the GitHub README URL** whose only call site `853a8a6` deleted
  for DW-166, and did not scan `ui/browser*`. Entry removed, walk extended, rule count derived.
- **`Test.Manifest`'s skip was `$$$AssertTrue(1, …)`** — a tautology counted as a pass, and the
  only outcome that method has ever had on this project's own container. Logged, not asserted;
  `docker-compose.yml`'s mount is now pinned by `compose.test.mjs`.
- **`853a8a6` — the OFL `assets` entry was pinned by nothing**, while every sibling change in that
  commit is. `angular-json.test.mjs` asserts the entry, its output directory, and that a licence
  ships beside each family's faces.
- Smaller: `ci-runner.mjs`'s orphaned JSDoc, "four fields" (five), `testClassesOnDisk`'s "same
  population" (it is a floor), and a trailing flag with no value; `smoke.sh --help` overrunning into
  `set -e` and a newline-bearing credential; `wait-readiness.sh --interval 0`; `ci-unit-test.sh`'s
  "always exits 0"; `container-health.sh`'s dangling sentence; `Uninstall`'s dry-run listing roles
  it will not remove; `VersionStamp`'s `$Char(0)`; `ATTRIBUTIONS.md` unreferenced by README.

*Ledgered, not blocking (`DW-217`…`DW-227`).* `escalated owner=burndown`: the npm licence file is
generated and never distributed (**217**); CI's Python interpreter is the one unpinned tool
(**218**); `Uninstall`'s three half-state paths on an instance OcuPilot does not wholly own —
bundle removed under a kept application, an unreadable provenance record that continues, an
orphaned role — each with two defensible semantics (**219**). `routed owner=burndown`: the DW-94
acceptance bullet and matrix row still state the superseded "no provenance row → refuse" contract,
a Rule 5 apply-and-report correction (**220**); the spine's Stack table carries no row for the
pinned browser harness, Rule 20 (**221**); `853a8a6`'s DW-108 and DW-163 changes have no executing
assertion (**222**); the decision sheet's twelve chartered entries have no ledger trailer, no
`1-18` sprint key and a stale census (**223**). Closed terminal: **224**–**227**.

*Not changed, recorded.* `## Auto Run Result

**Rework iteration 2 — the two `[CI]` items the workflow's first real run opened.** Both were
invisible to every local gate, for the same reason: one is a Node-version behaviour difference and
the other a Linux file-ownership one, and this machine is neither.

**Changed** — 6 files, +563 / −19, the spec aside.

- `ui/package.json` — `test` and `test:tools` name files (`tools/*.test.mjs`) instead of the
  directory. On Node 22.22.3 a directory argument is loaded as a module, so the gates job ran one
  "test" named `tools`, failed it, and reported nothing about the 584 it never opened. Node's v22
  documentation records positional arguments as glob patterns and no directory form at all.
- `.github/workflows/ci.yml` — the `gates` job becomes a matrix over the floor of every band
  `engines.node` declares (`22.22.3`, `24.15.0`, `26.0.0`), `fail-fast: false`; and an
  `if: failure() || cancelled()` capture step before the teardown. The first defect was not really
  a bad argument, it was that CI ran one Node while the project claimed three; the condition on the
  second is `|| cancelled()` because `timeout-minutes` and `cancel-in-progress` cancel rather than
  fail, and a hung bring-up is the case with the most to capture.
- `scripts/ci-throwaway.sh` — `chmod 777 "$DIR/data"` before the container starts, because the
  durable directory has to be writable by uid 51773 and a bind mount keeps the host's ownership;
  `chmod -R a+rX` on the read-only copies for the same reason; a `scrub_data` helper that removes
  the durable tree through the pinned image when the invoking user cannot unlink what IRIS wrote;
  and a `logs` action for the failure path.
- `ui/tools/ci.test.mjs` — eight cases (38 in the file): three over the test-command form, one
  holding the matrix, `engines.node` and `version-guard.mjs` equal, one scoping the instance job's
  literal pin, two executing `ci-throwaway.sh` with a stub `docker` on `PATH`, and the capture-step
  position. Every text pin over that script now reads code rather than comments.
- `README.md`, `CLAUDE.md` — the matrix and the capture step in the CI table, the Linux permission
  step moved above the `up` it must precede, and the test command's new form where CLAUDE.md
  quotes it.

**Verification.** Every gates-job command run locally and green: `npm test` (591 tools + 184
components), `npm run build`, `uv run scripts/check-objectscript.py` (123 files, 14 rules),
`uv run scripts/test_check_objectscript.py` (45), `bash scripts/lint-docs.sh` (19 files). Then each
matrix leg as CI will run it — `node:22.22.3-slim`, `node:24.15.0-slim`, `node:26.0.0-slim`, over a
clone of this working tree: `npm ci` under `ui/.npmrc`'s `engine-strict`, `npm run build` and
`npm test` all green on all three, 591 tools tests and 184 component tests, `fail 0` each. The
instance job's bring-up ran end to end against a throwaway (up healthy, readiness `installed`,
`wait-readiness.sh` 0, `smoke.sh … --user _SYSTEM --password SYS` 0 with `executed=9 passed=9`,
`logs`, `down` clean, no orphan container, volume or directory; the live `ocupilot` container
untouched). 14 mutations applied, red observed and reverted across the pass's two rounds, the
tree confirmed byte-identical after each; the whole diff was then read at review, where an
unreverted mutation would show. The rows are in `## Verification`.

**Matrix Test Audit.** This pass changed no behaviour any I/O & Edge-Case Matrix row describes: the
diff is the workflow, the throwaway script, the test-command form, their pins and two documents. The
rows whose covering tests are in this diff's reach ran and passed here — the two CI-wiring rows
(`ci.test.mjs`, 38/38) and "Smoke against a healthy instance" (the throwaway run above, exit 0). The
ObjectScript-covered rows rest on the runs recorded in the passes that wrote them; **this pass did
not re-run the `%UnitTest` classes, `ui/tools/ci-runner.mjs` or the browser spec**, and nothing in
the diff reaches them.

**Review.** Four layers, 43 findings: high 0, medium 19, low 23, false 1. 25 patched in-pass, 4
deferred, 13 rejected with reasons, 1 refuted — every row in `## Review Triage Log`. The
substantive patches: the coverage pin compared one population with itself and now derives it from
Node's own discovery rules; `version-guard.mjs`'s third copy of the band list was unreachable from
the new equality; `failure()` skipped the cancellation case; a failing `ps -a` swallowed the
capture; and two of the three matrix legs had never actually been installed on.

**What is confirmed and what is not.** The `gates` fix is confirmed: the failing command and its
replacement were both executed on 22.22.3, and the whole suite installs and passes on all three
legs. The `instance` defect's **cause** is confirmed on the runner itself — run 34773637146's log
carries `ERROR #5001: Cannot create target: /durable/iris/` six times — and the **repair** is
confirmed only as a mechanism, reproduced under real Linux ownership in a named volume. No local
bring-up can fail this way: Docker Desktop maps bind-mount ownership to the caller, so the
end-to-end throwaway run passes with or without the `chmod`. If the runner's bring-up fails for a
second reason, the new capture is what will say so, and that step is itself unexercised on a runner.
Also unexercised on a runner: the browser spec's launch (its install step did run and succeed).
One file this pass did not touch is modified in the tree by a concurrent session —
`_bmad-output/implementation-artifacts/deferred-work.md` (decision-sheet trailers, `by=merge_gate`,
18:42-18:48) — and is deliberately not in this commit.

**Follow-up review recommended: true.** No review finding this pass was `high`, so by the letter of
the follow-up rule this would be `false`; it is `true` because the item the pass exists to fix,
DW-232, is a ledger `high`, and the rule's other condition is met — a specific unverified risk can
be named. That risk: the workflow has still never run green on GitHub Actions, and the one fix that
cannot be proven from this machine is the throwaway's durable-directory permission. The next push is
the proof, and it is a push the lead makes, not this pass. The lead may downgrade this on the
reading that a review found nothing to escalate.

Status: done
Blocking condition: none
