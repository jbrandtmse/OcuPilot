# Epic 13 Context: Bonus deliverables and engineering hygiene

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

The entry reads as finished rather than as a demo. OcuPilot can be removed leaving nothing behind, the test suite keeps pace with the code in CI against a stock image so a later change cannot silently break a Release 1 screen or agent write, and the package is ready for the community registry. Stories 13.1 to 13.3 are done; the registry publish itself stays with the owner. Story 13.4's bonus items were scratched on 2026-09-19. The remaining work is Story 13.5, added after the submission and ranked by the owner as the first story after release 1.0.2. A CI run currently takes about 55 minutes, because two suites each run one item at a time against a single container: the ObjectScript suite (327 classes, about 52 minutes against a 60-minute limit) and the browser specs (100 files, about 48 minutes). Splitting each suite across three parallel shards brings a run to about 20 minutes and keeps both suites inside their limits as they grow.

## Stories

- Story 13.1: The uninstall hook (done)
- Story 13.2: The test suite grows in CI against a stock image (done)
- Story 13.3: Publish the package to the community registry (done; the publish is held by the owner)
- Story 13.5: CI in parallel - the two long suites split across containers

## Requirements & Constraints

Story 13.5:

- Each suite runs as **three parallel shard jobs**, and each shard brings up its own throwaway container. Inside a shard, classes and spec files still run **one at a time**. Classes share one instance's fixtures, so one-at-a-time is a rule per instance, not per run.
- Shard assignment is **deterministic** and balanced by recorded duration, longest first, from a **timings file committed to the repository**. A class or spec file with no recorded time is still assigned, and one documented command refreshes the timings file from a run's output.
- Each suite has a **roll-up job, still named `instance` and `browser`**. It fails unless every test class the instance offers and every spec file the checkout carries ran in exactly one shard, and it also fails if any shard executed zero tests. Nothing may be dropped silently.
- A failure names its shard and the failing class or spec. That shard's capture-on-failure step still collects its container's logs.
- The **admin API drift check** and the **smoke script** each still run once per run, against a freshly installed instance. They run once, not once per shard, and neither is dropped.
- Without a shard option, `ui/tools/ci-runner.mjs` and `npm run test:browser` behave exactly as they do today: the full suite, one class or file at a time.
- The pinned workflow rosters in `ui/tools/ci.test.mjs` are updated in the same change. Removing a shard from either matrix must turn a test red.
- The story's own green run on GitHub-hosted runners takes **25 minutes or less** from its first job's start to its last job's end, with about 20 as the target, and the story records the measured time. Each shard's `timeout-minutes` must be at least 1.5 times its measured share.

These hold from 13.1 to 13.3 and must not regress:

- Uninstall removes everything install created and nothing IRIS owns; the audit rows stay. A target that is already absent returns OK, and running uninstall then install reaches a working OcuPilot.
- CI runs against a stock image and executes the ObjectScript unit and HTTP integration suites, the client unit tests and the endpoint-inventory fixture. Coverage of built screens and `write` tools is a derived-versus-declared equality in both directions, and a gap fails CI naming the member.
- The drift check diffs a vendored v2 path-and-method table against the instance's generated spec. The table is derived from upstream and carries the upstream SHA; the upstream document itself is never vendored, because it has no license. **The expected diff is not empty**: one path differs, `/v2/security/oauth2/revoke` upstream against `/v2/security/oauth2/server/revoke` on the instance.
- Nothing contacts the public registry or reads a registry credential. Publishing is the owner's act alone.

## Technical Decisions

- **Install at container start (AD-17, AD-38).** A container compiles and installs OcuPilot when it starts, never when the image is built, and install is idempotent and fast. Health and readiness read healthy only once this start's install has recorded success, so a container that is up is not necessarily installed. Every shard must therefore wait for readiness to report `installed` before it runs anything, and every shard's install time counts against the time budget.
- **One smoke path (AD-45).** The smoke script is the single definition of "installed and working". It is also the container health check and what CI runs. Its assertions live in `OcuPilot.Install.Smoke` inside the instance, and a run that executes zero checks is a failure. Readiness is an unauthenticated endpoint on its own web application, and it reports only installed, version and installing.
- **Pinned image and inventory fixture (AD-27).** The image is an explicit 2026.2 tag, never `latest-cd`. The endpoint-inventory fixture re-derives the admin API inventory from the running instance and fails when the instance disagrees. It is one test class in the shared-out set, so it lands in exactly one shard.
- **IPM is a distribution channel only (AD-18).** The runtime image has no loaded IPM, and nothing in CI's install path may assume it.
- **Stack table, CI row:** GitHub Actions on `ubuntu-24.04`. `gates` runs once per `engines.node` band floor. `instance` and `browser` each run against their own throwaway. `images` compiles, installs, drift-checks `/api/admin` and smokes on both stock Community editions, where plain IRIS Community installs into `USER`. Every `uses:` action is pinned to a full commit SHA.
- **Stack table, CI tool pins:** uv `0.12.9`, Python `3.12.14` (`.python-version`), `markdownlint-cli2@0.23.2` and puppeteer `24.24.0`. New shard jobs keep these pins and the SHA-pinned actions.
- **The spine is a contract.** Its Stack CI row and CLAUDE.md's CI paragraph both describe a single `instance` job and a single `browser` job. A change to that layout amends both texts in the same change, so neither is left stale.
- **Browser specs run against the deployed bundle, not the working tree.** Each browser shard's container must carry the bundle built from the same checkout.

## Cross-Story Dependencies

- CI runs on every push through `.github/workflows/ci.yml`, which has five jobs: `gates`, `instance`, `browser`, `images` and `package`. `gates` runs once per Node band floor (22.22.3, 24.15.0 and 26.0.0), and `ui/tools/ci.test.mjs` holds that list equal to `engines.node`. CI is the gate over what was committed, where the pre-commit hook checks only the working tree.
- `concurrency` is `cancel-in-progress`, so a second push cancels the first push's run. Measure the story's time on a run that nothing cancelled.
- `ci.test.mjs` also pins the arming rosters in `scripts/ci-throwaway.sh`. When a pinned roster reddens, updating it falls to the story that changed it.
- Locally, each slot has its own throwaway: `ocupilot-ci` on 52776/1975, `ocupilot-b-ci` on 52777/1976 and `ocupilot-c-ci` on 52779/1978. The script refuses the live and slot container names and ports. Tear down only a throwaway you brought up yourself.
- Never run two test classes at once against one instance. On 2026-09-11 an overlapping run left a probe database mounted with no directory behind it and wedged seven classes. Sharding is safe only because each shard owns its own container.
- The epic depends on Epic 1 alone: the installer, the generated roster, the smoke path, the readiness endpoint and CI.
- 13.5 changes which classes and specs share an instance, and in what order. Earlier ledger items showed coupling between suites on a shared instance: a Wallet test deleted shared demo data, and the audit spec's thousand-row seed read 919 after a full sweep. A new grouping can therefore surface a red that depends on order (inference).
