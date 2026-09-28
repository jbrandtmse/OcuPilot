---
title: 'Story 13.5: CI in parallel - the two long suites split across containers'
type: 'feature'
created: '2026-09-27'
status: 'in-progress'
baseline_revision: 'f4ab7c49f1e66ef7e1850563f20654fcc0e24784'
baseline_commit: 'f4ab7c49f1e66ef7e1850563f20654fcc0e24784'
review_loop_iteration: 0
followup_review_recommended: true
context: []
warnings: ['oversized']
deferred:
  - summary: >-
      Whether any ObjectScript class or browser spec depends on residue from an item the shard split no longer runs before it is unverified locally.
    evidence: |-
      Only --shard 40/40 ran against a real instance (10 classes, 4 spec files). Settled by the lead's measured CI run: every instance and browser leg green on its fresh throwaway; a red that depends on composition is a coupling defect fixed in the test.
    location: >-
      .github/workflows/ci.yml instance-shard, browser-shard
    severity: medium (unverified)
  - summary: >-
      skill-rules.md Rule 29 still says CI runs the browser suite in its own `browser` job; that job is now the roll-up over three browser-shard legs.
    evidence: |-
      _bmad/custom/skill-rules.md:270 "CI runs it in its own `browser` job against a **fresh** throwaway"; after this story each browser-shard leg has its own fresh throwaway and `browser` only checks their records. Agent-context file, so the lead changes it with CLAUDE.md's job list.
    location: >-
      _bmad/custom/skill-rules.md:270
    severity: low
---

<intent-contract>

## Intent

**Problem:** A CI run takes about 50 minutes because two jobs each run a whole suite one item at a time against one container: `instance` ran 329 ObjectScript classes in 48.2 minutes and `browser` ran 115 spec files (501 tests) in about 51 minutes on feature run 36359053662. Every other job ends within 6 minutes, and both suites keep growing toward their limits.

**Approach:** Run each suite as three parallel shard jobs, each with its own throwaway, still one class or file at a time per instance. A committed timings file assigns items longest-first. Each shard uploads a record of what it ran, and a roll-up job per suite, still named `instance` and `browser`, fails unless every item ran in exactly one shard. The local, unsharded paths do not change.

## Boundaries & Constraints

**Always:** Inside a shard, items run one at a time, in the same relative order the unsharded run uses: the instance's list order for classes, sorted order for spec files. Assignment is a pure function of the offered item set and the timings file. It sorts by duration descending, then name in code-unit order (never `localeCompare`), and gives each item to the shard with the smallest running total, the lowest index on a tie, so every shard computes the same split. An item with no recorded time weighs the median of its suite's recorded times, or 1 when none are recorded. Every shard container is fresh (`ci-throwaway.sh up` scrubs its data), and nothing seeds agent definitions before a suite (DW-1759). Every new `uses:` action is pinned to a full commit SHA with its tag as a trailing comment. Slot B for every local command: `--container ocupilot-b-ci`, origin `http://localhost:52777`, both browser variables exported, one test run on the instance at a time.

**Never:** Change `test:browser` or `pretest:browser` in `ui/package.json`, or ci-runner's behavior without `--shard`. Run two classes or two spec files at once against one instance. Pin a class or spec to a shard by name. Use `if: always()` on anything but a teardown step (`ci.test.mjs` counts them). Add `continue-on-error`, `|| true` or a `secrets.` reference. Edit `scripts/ci-throwaway.sh` or `ui/browser.config.mjs`, or edit a spec under `ui/browser/` or an ObjectScript test class except to remove a dependence a `[CI]` task names. Push, or run a full suite locally as a gate.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Assignment | Offered set plus `ci-timings.json`, `--shard k/3` | Every item is in exactly one shard. Shard totals come within one largest item of each other, and each shard derives the same split | none |
| Unknown or stale item | A class or spec missing from the timings, or a timing for a removed item | The unknown item is assigned at the median weight. The stale entry is ignored | none |
| Bad shard option | `--shard 0/3`, `4/3`, `x`, or `--shard` beside `--class` | Usage refusal naming the flag | exit 2 |
| Empty share | More shards than items | The runner names its shard and refuses to report a pass | exit 1 |
| No shard option | `ci-runner.mjs --container X` | Lists, floor-checks and runs every class, with today's lines. It writes no record and prints no shard label | as today |
| Shard failure | A class or spec in shard 2 fails | Today's per-item lines, plus a summary naming `shard 2/3` and the failing class or spec file. The record is still written | exit 1 |
| Zero executed | Every test a shard reached was skipped, or its classes ran 0 methods | The runner names the shard | exit 1 |
| Roll-up, complete | Three records: offered lists equal, `ran` disjoint and covering, each shard with more than 0 tests, `--result success` | Prints items, tests and minutes per shard | exit 0 |
| Roll-up, gap | An item dropped or run twice, a record missing, offered lists that differ, a shard with 0 tests, or a result other than `success` | Names each problem: the item, both shards for a duplicate, the missing shard, the result | exit 1 |
| Refresh | `refresh --run <id>`, or `--records <dir>` | Rewrites each suite present in the records from their `ran` seconds with sorted keys, dropping stale entries. A suite absent from the records is kept | exit 1 naming what was unreadable |

</intent-contract>

## Code Map

- `.github/workflows/ci.yml` -- `instance` `:112-167`, `browser` `:186-238`, header `:1-39`. `images` `:240-291` already brings up, drift-checks and smokes a fresh `irishealth-community:2026.2` every run. The port-reservation steps (`:145-146`, `:219-220`, `:267-268`) stay in every job that brings up a throwaway.
- `ui/tools/ci-runner.mjs` -- `parseArgs` `:359-380`, listing `:396-407`, on-disk floor `:420-432`, the unsharded "running N" line `:434`, run loop `:441-495` (it already holds `startedAt`/`finishedAt` per class), summary `:512-521`, `testClassesOnDisk` `:327-347`. The class list comes from `scripts/ci-unit-test.sh --list` (`ORDER BY c.Name`, `:80`).
- `ui/package.json:17-18` -- `pretest:browser` builds the table harness that `data-table*.browser-spec.mjs` load. `test:browser` is `node --test --test-concurrency=1 browser/*.browser-spec.mjs`. Both are pinned by `ui/tools/angular-json.test.mjs:222-229` and `:343` (read-only, must stay green).
- `ui/tools/ci.test.mjs` -- `DECLARED_GATES` `:102-155` (a multiset, one entry per `run:`), `PINNED_ACTIONS` `:188-192`, `jobNames` `:207-211`, the always()-per-teardown count `:381-402`, capture-before-teardown `:404-446` (jobs listed at `:414`), the five-jobs and readiness-order test `:463-490`, literal-Node pinners `:581-622` (`:590`), port and container facts `:1528-1657` (reservation loop `:1615-1618`, `--container` loop `:1644-1656`).
- `ui/tools/stub-bin.mjs` -- `writeStub`/`stubEnv`, the stub-`docker` idiom `ci.test.mjs:985-998` uses to run the real runner with no instance.
- `ui/browser/a11y-structural-invariants.browser-spec.mjs:7` -- "named so it sorts first", so it must run first on its shard's fresh instance. Sorted order within a shard keeps that.
- Seed data, run 36359053662 (feature `c46cafa9`, the 1.0.2 tree). Instance job `108741231253`: ci-runner prints no duration, but each class's time is the gap between consecutive log timestamps on its `ok`/`FAILED` lines. LPT over three shards gives 16.1/16.1/16.1 min. The largest class is `TurnLong` at 201 s, and setup before the suite is 2.2 min. Browser job `108741202204` (attempt 2): the TAP output flattens tests across files and never names the file, so per-file time is estimated (inference). Each top-level `ok`/`not ok` result goes to the first sorted spec file, at or after the previous one's, whose source contains the title's first 40 characters. 57 of 501 titles matched nothing and were charged to the preceding file. The estimate gives about 17.0 min per shard and 2.2 min of setup.
- Actions resolved 2026-09-27 with `gh api`, the lowest major whose `action.yml` runs `node24` (DW-238): `actions/upload-artifact` v6 `b7c566a772e6b6bfb58ed0dc250532a479d7789f`, `actions/download-artifact` v7 `37930b1c2abaa49bbe596cd826c3c89aef350131`.
- Node's test runner sorts the files it is given, with a code-unit sort. It accepts two reporters at once (`--test-reporter=tap --test-reporter-destination=stdout --test-reporter=tap --test-reporter-destination=<file>`), and TAP's `# pass N` excludes skips. Both were probed on Node 26.

## Tasks & Acceptance

**Execution:**

- `ui/tools/ci-shards.mjs` -- NEW. Imports only built-ins and `ci-runner.mjs`. Pure exports: `parseShard`, `assignShards`, `browserSpecsOnDisk` (the `*.browser-spec.mjs` predicate), `readTimings`, `checkRecords`, `refreshTimings`. CLI subcommands:
  - `assign --suite objectscript|browser --shards N` prints each shard's items and estimated minutes from the checkout's lists.
  - `check --suite S --shards N --records DIR --result R` reads every `*.json` under DIR recursively, and `--result` is required. For `browser`, the expected set is also the roll-up checkout's own `browserSpecsOnDisk()`.
  - `refresh (--run ID | --records DIR)` runs `gh run download ID --pattern 'ci-record-*' --dir <tmp>`, then rewrites `ci-timings.json`.
  - Record shape: `{suite, shard, shards, offered[], assigned[], ran[{name, seconds, tests, failed, outcome}]}`. The header documents the refresh command.
- `ui/tools/ci-timings.json` -- NEW. `{source, objectscript{class: seconds}, browser{file: seconds}}`, seeded by the method in the Code Map with keys sorted. `source` names the run and says the browser half is estimated.
- `ui/tools/ci-runner.mjs` -- Add `--shard k/n`, `--timings` (default `ui/tools/ci-timings.json`) and `--record PATH`; `--record` is also accepted without `--shard`. `--shard` with `--class` is refused with exit 2. With a shard, it lists and floor-checks as today. It then keeps its share in the instance's order and replaces the `:434` line with `ci-runner: shard k/n -- running a of b test class(es), one at a time (DW-54)`. It prefixes the summary and problem lines with `shard k/n` and writes the record after the loop. Without `--shard` nothing changes.
- `ui/tools/ci-browser.mjs` -- NEW browser shard runner: `--shard k/n` (required, exit 2 without it), `--record`, `--timings`, `--dir` (default `browser`, so tests can use fixtures). It runs its share sorted, one `node --test --test-concurrency=1` per file with live TAP on stdout and a second TAP reporter to a temp file, deleting `NODE_TEST_CONTEXT` from the child's environment. It counts executed tests as pass plus fail. It exits 1 on a failed file, on unreadable counts, or on zero executed tests, printing `ci-browser: shard k/n -- ...` naming each failing file, and always writes the record.
- `ui/package.json` -- Add `"test:browser:shard": "node tools/ci-browser.mjs"` and `"pretest:browser:shard": "ng build --configuration production,harness"`. Change no other script.
- `.github/workflows/ci.yml` -- Seven jobs in this order: `gates`, `instance-shard`, `instance`, `browser-shard`, `browser`, `images`, `package`.
  - `instance-shard` (`name: instance shard ${{ matrix.shard }}/3`, `strategy.fail-fast: false`, `matrix.shard: [1, 2, 3]`, `timeout-minutes: 40`) takes today's `instance` steps. `admin-spec.mjs` (before the runner) and `smoke.sh` (after it) carry `if: ${{ matrix.shard == 1 }}`. The runner step is `node tools/ci-runner.mjs --container ocupilot-ci --shard ${{ matrix.shard }}/3 --record ${{ runner.temp }}/ci-records/objectscript-shard-${{ matrix.shard }}.json`.
  - `browser-shard` is the same shape: it takes today's `browser` steps with `npm run test:browser:shard -- --shard ${{ matrix.shard }}/3 --record ${{ runner.temp }}/ci-records/browser-shard-${{ matrix.shard }}.json` and the same `env:` pair.
  - Every shard job keeps its capture and teardown steps. It uploads its record as `ci-record-objectscript-${{ matrix.shard }}` or `ci-record-browser-${{ matrix.shard }}` with `if: ${{ !cancelled() }}` and `if-no-files-found: error`. Records live under `${{ runner.temp }}`, never in the checkout.
  - `instance` and `browser` are the roll-ups (`needs:` their shard job, `if: ${{ !cancelled() }}`, `timeout-minutes: 10`). Each runs checkout, setup-node 22.22.3, and download-artifact with `pattern: ci-record-objectscript-*` (or `ci-record-browser-*`), `merge-multiple: true` and `path: ${{ runner.temp }}/ci-records`. It then runs `node tools/ci-shards.mjs check --suite objectscript --shards 3 --records ${{ runner.temp }}/ci-records --result ${{ needs.instance-shard.result }}`, or the `browser` / `browser-shard` equivalent.
  - Rewrite the header's job list and the stale timeout comments in place.
- `ui/tools/ci.test.mjs` -- These are changes to existing lines (see Design Notes).
  - `DECLARED_GATES`: the new commands, one entry per occurrence.
  - `PINNED_ACTIONS`: add the two artifact actions.
  - `jobNames`: equality with the seven jobs.
  - The capture test: over `instance-shard`, `browser-shard` and `images`.
  - The readiness-order test: per shard-job slice.
  - The literal-Node pinners: add `instance-shard` and `browser-shard`. The roll-ups keep the keys `instance` and `browser` and pin 22.22.3 too.
  - The reservation loop: over the shard jobs.
  - New assertions:
    - Both shard matrices are exactly `[1, 2, 3]`, and the `/3` in their commands and the roll-ups' `--shards 3` equal that length.
    - Each shard job has `fail-fast: false`, and each roll-up `needs` its shard job, runs on `!cancelled()` and passes that job's result.
    - `admin-spec.mjs` and `smoke.sh` each appear exactly once in `instance-shard`, under `matrix.shard == 1`, with 1 in the matrix, in today's order around the runner.
    - Each shard job's `timeout-minutes` is at least 1.5 × (its suite's largest shard estimate from `ci-timings.json` over the checkout's items + 3 setup minutes).
- `ui/tools/ci-shards.test.mjs` -- NEW. Covers every I/O-matrix row.
  - Executed runs of `ci-runner.mjs` through a stub `docker`, which answers the list session with a fixed class list and each class session with a landed, passing run whose index comes from a counter file: the no-shard path runs all classes with today's line and writes no record; shards 1-3 run disjoint shares in list order, and their three real records pass `check`, then fail it when one class is removed.
  - `ci-browser.mjs` over fixture specs covers a passing shard, a failing file named with its shard, and a skipped-only shard with zero executed.
  - `refresh` runs through a stub `gh`.
  - `test:browser`, `pretest:browser` and `pretest:browser:shard` are held byte-equal to today's harness build string.
- `docs/DEVELOPMENT.md:438-447` -- The CI table and the paragraph under it describe the shard and roll-up jobs and the refresh command. This is a footprint extension.

**Rework iteration 1 (trigger: CI run 36372545149 on `8cd58d28`, 21.5 min, three reds that the regrouped shards exposed; the roll-ups named each):**

- [ ] [CI] instance shard 3/3: `OcuPilot.Test.AuditStarted` `TestAnAgentCopyStillRunningAtTheBoundIsAppliedAndMarked` -- "the instance's audit database holds records to copy (0)" (`src/OcuPilot/Test/AuditStarted.cls:86`, run 14 of the shard, about two minutes after install). `OcuPilot.Test.AuditCopy.Count` is `SELECT COUNT(*) FROM %SYS.Audit`, and the audit indexes lag about 60 s (DW-85, `AuditRecord.cls` header), so on a young instance it reads 0 (inference). Fix: the precondition must hold on a freshly installed instance at any position in a shard -- count through the master map (`%NOINDEX`, as `OcuPilot.Test.AuditEvent.RowsCarrying` reads) or wait, bounded, for a record; never by moving the class. Same for `:108` and any other `Count("%SYS")` precondition in the audit test classes.
- [ ] [CI] browser shard 2/3: `ui/browser/audit-copy-purge.browser-spec.mjs:176` AC1 -- "the instance holds records to copy (0)", second file on its shard's fresh instance (the first was `account-and-filter`). It passed locally on a fresh instance a few minutes after install, so the likely cause is the same index lag (inference). Fix in the spec: its precondition must hold on a young instance.
- [ ] [CI] browser shard 2/3: `ui/browser/oauth-server-editor.browser-spec.mjs:92` (`removeAll`, before hook at `:215`) -- "/oauth2 is left in place" `'0' !== '1'`; every test fails in the hook. `/oauth2` exists only after an earlier OAuth spec created it; reproduced red on a fresh `ocupilot-b-ci` with no OAuth spec before it. Fix: the hook must not require `/oauth2` to pre-exist (assert it is left as found, or establish it), keeping what the assertion protects.
- [ ] [CI] Search `ui/browser/` and `src/OcuPilot/Test/` for other preconditions with either root cause (an audit count or audit read that assumes an indexed record on a young instance; `/oauth2` or another object a sibling creates) and fix each the same way; list what was searched and found in `## Auto Run Result`.
- [ ] Refresh the timings from the run's real records: `cd ui && node tools/ci-shards.mjs refresh --run 36372545149` (the browser half becomes measured per file); keep `ci.test.mjs` and `ci-shards.test.mjs` green over the refreshed file.

**Acceptance Criteria:**

- **AC1.** Given a CI run, when the ObjectScript suite runs, then `instance shard 1/3`, `2/3` and `3/3` each bring up their own throwaway and run their share one class at a time, exactly as the single job did.
- **AC2.** Given a CI run, when the browser specs run, then `browser shard 1/3`, `2/3` and `3/3` each bring up their own throwaway and run their share one file at a time, sorted.
- **AC3.** Given the offered classes and spec files, when shards are assigned, then the split follows the Always rule (deterministic, longest first, from `ci-timings.json`) and an item with no recorded time is still assigned. Given a run's records, when `cd ui && node tools/ci-shards.mjs refresh --run <run-id>` runs, then it rewrites that file from them.
- **AC4.** Given finished shards, when a roll-up job runs, then it fails unless every item ran in exactly one shard and each shard executed at least one test. For `instance` the items are the classes the instances offered, and for `browser` they are the spec files the checkout carries. It also fails on any shard result other than `success`.
- **AC5.** Given a failing class or spec, when its shard fails, then the output names the shard and the class or spec, and that shard's `failure() || cancelled()` capture step collects its container's logs before teardown.
- **AC6.** Given a CI run, when its shard jobs run, then the admin API drift check and `smoke.sh` each run exactly once. They run in shard 1: the drift check before any class, the smoke after its share, as today (Design Notes).
- **AC7.** Given `ci-runner.mjs` or `npm run test:browser` run locally without a shard option, when it runs, then it behaves exactly as today: the full suite, one class or file at a time.
- **AC8.** Given `ui/tools/ci.test.mjs`, when the workflow changes, then its rosters change in the same diff, and removing a shard from either matrix turns a test red.
- **AC9.** Given the story's own green run on GitHub-hosted runners, when it is measured, then the time from its first job's start to its last job's end is 25 minutes or less, with about 20 the target. The measured time is recorded here, and each shard job's `timeout-minutes` is at least 1.5 times its measured duration.

## Spec Change Log

- 2026-09-27, lead at the spec gate (Rule 20): the spine's Stack `CI` row, Operational Envelope `Build and CI` row and Conventions `Tests` row now state the shard layout and that a test depends on nothing its shard neighbours left; no new AD. The roll-up jobs keep both their job keys and their `name:` values, `instance` and `browser`.
- 2026-09-27, lead, rework iteration 1 (trigger `ci`, run 36372545149): re-opened with the five tasks above. The Never clause now permits editing a spec under `ui/browser/` or an ObjectScript test class only to remove a dependence a `[CI]` task names (Rule 5 tier 1: the Design Notes' Risks already say such a red is fixed in the test).

## Review Triage Log

### 2026-09-27 — Review pass

- verdicts: 19 findings — high 0, medium 4, low 10, false 4, maybe-false 1
- findings:
  - `[medium]` `[patch]` The `browser` roll-up's checkout expected set was pinned only through `checkRecords`, never through `check` — added a CLI test with a spec file no leg was offered; `expected = null` turns it red.
  - `[low]` `[patch]` The no-shard "writes no record" assertion could not fail for a default record path — the runner now runs with `cwd` at the temp tree, and the test holds the tree's JSON files to the timings file.
  - `[medium]` `[patch]` A timed-out browser test (reported `cancelled`, `fail 0`) fails its shard only through two untested branches — added a timeout fixture test; dropping both branches turns it red.
  - `[low]` `[patch]` AC3 refresh half had no `mutation:` line — demonstrated and recorded.
  - `[low]` `[patch]` AC4 clauses had no `mutation:` line — the browser-checkout clause is now demonstrated; the result and duplicate clauses are covered by AC4's existing lines (Rule 19 is per AC).
  - `[low]` `[patch]` AC5 browser half had no `mutation:` line — demonstrated and recorded.
  - `[low]` `[patch]` AC6 admin-spec condition had no `mutation:` line — demonstrated and recorded.
  - `[low]` `[patch]` AC7 `npm run test:browser` half had no `mutation:` line — demonstrated and recorded.
  - `[low]` `[patch]` AC2 "sorted" clause had no `mutation:` line — demonstrated and recorded.
  - `[false]` `[reject]` AC9's measured duration is untested — the spec assigns it to the lead's push; no local test can observe a GitHub-hosted duration.
  - `[low]` `[reject]` Record `seconds` asserted only `>= 0`, and `assign` has no executed test — seconds feed only `refresh`, whose diff the lead reviews, and `assign` is a hand-run listing exercised in Verification.
  - `[medium]` `[patch]` Artifact names are per run, not per attempt (upload-artifact README and issue #480), so re-running a failed leg would 409 at its upload — added `overwrite: true` to both uploads and pinned it in `ci.test.mjs`.
  - `[false]` `[reject]` The Actions-runtime surface (matrix results, download layout) is not exercised by the diff's tests — by design; the spec's "Lead, on push" checks are that proof.
  - `[maybe-false]` `[defer]` A class or spec that depends on residue from a predecessor the split no longer places before it is unexercised locally — settled by the lead's measured run with every leg green on fresh throwaways.
  - `[low]` `[defer]` `_bmad/custom/skill-rules.md:270` says CI runs the browser suite in "its own `browser` job", now a roll-up over `browser-shard` legs — agent-context file, the lead's to change with `CLAUDE.md`.
  - `[false]` `[reject]` Smoke now follows a third of the suite — the spec's Design Notes choose this and say why.
  - `[false]` `[reject]` The median is over offered items' times, not the whole suite table — consistent with the matrix row that ignores stale entries; the split stays a pure function of the offered set and the file.
  - `[low]` `[reject]` `--record` and `--timings` are accepted without `--shard`, and `--timings` alone is ignored — the spec prescribes `--record` without `--shard`; refusing `--timings` would add a guard for a flag nobody passes alone.
  - `[medium]` `[patch]` The timings-file test required the browser `source` to say "estimated", so the lead's mandated `refresh` would turn `test:tools` red — the test now requires only that each half names its run.

## Design Notes

**Governing ADs.**

- **AD-17 and AD-38:** every shard installs at container start and waits for readiness to report `installed` before running anything.
- **AD-27:** the image stays pinned, the drift check runs once, and the inventory fixture is one class, so it lands in exactly one shard.
- **AD-45:** one smoke path, run once.
- The Stack rows `CI`, `CI tool pins` and `Client test runners`, and the Operational Envelope row `Build and CI`.

The spine is changed by the lead at the spec gate, not by this story (Rule 20). These texts become false and are corrected at their origin:

- **Spine `:796`**: "`instance` and `browser` each against their own throwaway container". It becomes: each suite runs as three shard jobs, each against its own throwaway, with its share assigned longest-first from `ui/tools/ci-timings.json`, and a roll-up per suite, still named `instance` and `browser`, holds every class and spec to exactly one shard.
- **Spine `:933`**: "against a throwaway container" becomes "against throwaway containers, each suite split across three shards".
- **`CLAUDE.md:141`**: "five jobs" becomes the seven-job layout. The lead makes this change after the measured run, on the 13.3 precedent that an agent-context file is corrected from what was observed.
- **The `ci.yml` header** (this story).

No new AD is needed (inference). One convention may be: a class or spec must not depend on another's residue, because shard neighbors change. The lead decides.

**Where the drift check and smoke run, and why that instance counts as freshly installed.** Both run in shard 1, in today's positions: the drift check after readiness and before any class, and the smoke after the suite. The instance is one this run created from this checkout on a scrubbed volume, and its own start hook installed it. That is the sense in which today's single job smoked "a freshly installed instance", also after its suite. Moving the smoke before the suite would put its residue (a sign-in, a confirmed write and restore, audit and ledger rows) ahead of classes that have never followed it. The cost is that smoke now follows a third of the suite, not all of it. The `images` irishealth leg still drift-checks and smokes an untouched instance of the same image on every run.

**Why the browser shard has its own entry.** `test:browser` is left byte-identical. The shard runner spawns one `node --test` per file, which is the same per-file process isolation `node --test` already uses, and that gives an exact per-file time, pass and fail counts, and the failing file's name. Today's TAP names the failing test, not the file.

**Why records travel as artifacts.** Matrix job outputs collide across legs. The roll-up uses `!cancelled()` because `always()` is reserved for teardowns, and it checks the shard result explicitly, because a skipped roll-up does not read as a failure. A shard that timed out has no record, and the roll-up names it as missing.

**Existing lines changed in contended `ui/tools/ci.test.mjs`** (the lead reports these): the `DECLARED_GATES` entries for the instance runner and `npm run test:browser`, the `jobNames` equality, the capture test's job list, the literal-pinner list, the reservation loop, the readiness-order test, and `PINNED_ACTIONS`. `scripts/ci-throwaway.sh` is untouched. **Footprint extension:** `docs/DEVELOPMENT.md`.

**Integration ACs and linkage (Rules 1 and 2).**

- The consumer `instance`/`browser` roll-up reads the shard records `ci-runner.mjs` and `ci-browser.mjs` write, and turns red naming a dropped item. This is pinned in `ci-shards.test.mjs` over the real runners' records and proven on the lead's CI run.
- `Consumed-by:` this story's CI jobs. Also Stories 16.9 and 16.24, whose new specs and classes arrive as unknowns and must still be assigned, and every later story's CI run.
- `Consumes:`
  - Story 1.17 (`ci-runner.mjs`, the CI shape, DW-54).
  - Story 13.2 (the `ci.test.mjs` rosters and the stub-`docker` idiom).
  - Story 8.9 (the `images` job).
  - DW-439 (the port reservation) and DW-232 (capture on failure).

**Risks, named rather than found.** A new grouping changes which classes share an instance and what precedes what. A red that depends on shard composition is a real coupling defect, fixed in the test and never by pinning an item to a shard (inference). `home-findings.browser-spec.mjs` AC1 failed once, nondeterministically, on run 36359053662. The lead reports how it behaves in the measured run and claims nothing about it. Same-run artifact download is expected to need no permission beyond `contents: read` (inference). If the push shows otherwise, adding `actions: read` changes a pinned equality and is the lead's call.

**Rule 17:** the ledger inbox is empty. Nothing to address or decline.

## Verification

**Commands (loop):**

- `cd ui && npm run test:tools` -- expected: green, including `ci-shards.test.mjs`, `ci.test.mjs` and `angular-json.test.mjs`.
- `cd ui && node tools/ci-shards.mjs assign --suite objectscript --shards 3 && node tools/ci-shards.mjs assign --suite browser --shards 3` -- expected: every checkout class and spec listed exactly once, and shard estimates within one largest item of each other.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard 40/40 --record /tmp/epic-13-13-5/objectscript-shard-40.json` -- expected: only that share runs, the shard is named, exit 0, and a record is written. Then, never concurrently: `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci npm run test:browser:shard -- --shard 40/40 --record /tmp/epic-13-13-5/browser-shard-40.json` -- expected: the same. No client source changes, so no bundle redeploy is needed.
- `git diff -- ui/package.json` -- expected: two added lines, with `test:browser` and `pretest:browser` untouched.

**Commands (once, before dev_complete):**

- `cd ui && npm run build && npm test` and `bash scripts/lint-docs.sh` -- expected: green.
- The full suites are CI's, proven on the lead's push. The implement stage runs no full suite locally.

**Lead, on push:**

- Record the run id and `max(completedAt) - min(startedAt)` from `gh run view <id> --json jobs` (at most 25 min), measured on a run no other CI run overlapped.
- Record each shard job's duration against `timeout-minutes` 40 (at least 1.5 times).
- Run `node tools/ci-shards.mjs refresh --run <id>` and commit it if it changes the file.
- Mutate one downloaded record: dropping a class turns `check` red, naming it.
- Report `home-findings`.

**Mutations (Rule 19; each one planned, then observed and recorded):**

- AC1/AC2/AC8: delete `3` from either shard matrix -> the matrix-roster test goes red.
- AC3: skip untimed items in `assignShards` -> the unknown-item test goes red. Sort ascending -> the longest-first test goes red.
- AC4: drop the coverage check or the zero-tests check in `checkRecords` -> the stub-produced record test goes red.
- AC5: delete `browser-shard`'s capture step -> the capture test goes red. Drop the shard label from the failure summary -> the failing-shard test goes red.
- AC6: remove the `matrix.shard == 1` condition from the smoke step -> the once-per-run test goes red.
- AC7: default an absent `--shard` to `1/3` -> the no-shard test goes red.
- AC9: set a shard job's `timeout-minutes` to 25 -> the margin test goes red.

**Observed (implement stage, 2026-09-27):**

- `npm run test:tools`: 1642/1642 (`ci-shards.test.mjs` 27, `ci.test.mjs` 75). `npm run build` and `npm test` (1642 tools, 1599 components) green; `lint-docs.sh` and `check-objectscript.py` 0 problems.
- `assign`: objectscript 327 classes at 16.1/16.1/16.1 min, browser 115 files at 17.2/17.1/17.1 min (1 untimed); each item listed once; spreads 0.0 s and 2.3 s against largest items of 201.5 s and 171.3 s.
- `ci-runner.mjs --container ocupilot-b-ci --shard 40/40 --record ...`: 10 of 329 classes, 78 tests, exit 0, record written. `test:browser:shard -- --shard 40/40` on 52777/`ocupilot-b-ci`: 4 of 115 files, 11 tests, exit 0, record written.
- `git diff -- ui/package.json`: two added lines; `test:browser` and `pretest:browser` untouched.
- mutation: `shard: [1, 2]` in `instance-shard`, then in `browser-shard` → the `[1, 2, 3]` matrix test (and the AC9 margin test) red.
- mutation: `assignShards` iterates only recorded items → the unknown-item test red (plus five executed tests).
- mutation: `assignShards` sorts ascending → the longest-first test red (plus six others).
- mutation: `checkRecords` drops the ran-in-no-shard push → the three-shard stub-record test red (plus two check tests).
- mutation: `checkRecords` drops the zero-tests push → the three-shard stub-record test red (plus one check test).
- mutation: `browser-shard`'s capture step deleted → the DW-232 capture test red (plus the three gate-equality tests).
- mutation: `ci-runner.mjs` problem lines lose the `shard k/n:` prefix → the failing-shard-2 test red (plus the zero-executed test).
- mutation: `if: ${{ matrix.shard == 1 }}` removed from the smoke step → the AC6 once-per-run test red, alone.
- mutation: absent `--shard` defaulted to `{index: 1, count: 3}` → the no-shard test red, alone.
- mutation: `instance-shard` `timeout-minutes: 25` → the AC9 margin test red, alone.

**Observed (review patches, 2026-09-27):** `npm run test:tools` 1644/1644, `lint-docs.sh` 0 problems; each mutation below went red alone and was reverted byte-identical.

- mutation: `check` passes `expected = null` for `browser` → the roll-up-holds-the-checkout test red (AC4, browser clause).
- mutation: `ci-browser.mjs` drops the `cancelled` and non-zero-exit branches → the timed-out-spec test red.
- mutation: `ci-runner.mjs` defaults `record` to `ci-records/objectscript-shard-1.json` → the no-shard test red (AC7, no record).
- mutation: `overwrite: true` removed from `browser-shard`'s upload → the AC4 upload/roll-up test red.
- mutation: `refreshTimings` starts each suite from the current table → the refresh test red (AC3, refresh).
- mutation: `ci-browser.mjs` problem lines lose `shard k/n --` → the failing-spec-file test red (AC5, browser).
- mutation: `test:browser` rewritten → the unsharded-scripts test red (AC7, `npm run test:browser`).
- mutation: shares keep assignment order instead of offered order → the sorted-share browser test red (AC2, sorted).
- mutation: `if: ${{ matrix.shard == 1 }}` removed from the admin-spec step → the AC6 once-per-run test red.

**Observed (QA gap-closing, 2026-09-27):** `ci-browser.mjs`'s "Empty share" row (share.length === 0)
was pinned for `ci-runner.mjs` but not for `ci-browser.mjs` itself. Added
`ui/tools/ci-shards.test.mjs`: "a browser shard assigned no spec file names itself distinctly from a
skipped-all shard, and its record says it ran nothing" (shard 3/3 over two fixture files, both
untimed, so the third leg gets none). `npm run test:tools` 1645/1645.

- mutation: `ci-browser.mjs`'s `share.length === 0` ternary branch collapsed into the general
  zero-tests message (`share.length === 0` → `false`) → the new test red (1 of 1 failed), applied
  to the tracked `ci-browser.mjs` by the lead and reverted; `git status --short` unchanged.

## Auto Run Result

**Summary.** Both long suites run as three-leg matrix jobs (`instance-shard`, `browser-shard`), each leg on its own fresh throwaway, one item at a time, its share assigned longest-first from `ui/tools/ci-timings.json`. Each leg uploads a record; the roll-ups `instance` and `browser` fail unless every item ran in exactly one leg, every leg executed a test, and the legs succeeded. Unsharded local paths are unchanged.

**Files.**

- `.github/workflows/ci.yml` -- seven jobs; shard matrices, record uploads (`overwrite: true`), roll-ups; header and timeout comments rewritten.
- `ui/tools/ci-shards.mjs` -- new: assignment, record check, `assign`/`check`/`refresh` CLI.
- `ui/tools/ci-browser.mjs` -- new: browser shard runner, one `node --test` per file.
- `ui/tools/ci-runner.mjs` -- `--shard`, `--timings`, `--record`; no-shard output unchanged.
- `ui/tools/ci-timings.json` -- new: seeded from run 36359053662 (browser half estimated).
- `ui/tools/ci-shards.test.mjs` -- new: 29 tests over every I/O-matrix row.
- `ui/tools/ci.test.mjs` -- existing lines changed: the runner and browser `DECLARED_GATES` entries (plus two `check` entries), `PINNED_ACTIONS`, the capture test's job list, the jobs/readiness test (now seven jobs, per shard job), the literal-Node pinner list, the reservation loop; new shard-matrix, roll-up, AC6 and AC9-margin tests.
- `ui/package.json` -- `test:browser:shard` and `pretest:browser:shard` added only.
- `docs/DEVELOPMENT.md` -- CI table and shard paragraph (footprint extension).

**Review.** 19 findings: 11 patched (4 medium, 7 low), 2 deferred (1 medium unverified, 1 low), 6 rejected (4 false, 2 low) -- reasons in the Review Triage Log.

**Follow-up review recommended: true** (4 medium patched). The unverified risk is the Actions-runtime wiring: `overwrite: true` on a re-run leg, `download-artifact` `merge-multiple` layout, and `needs.<matrix job>.result` are proven only by the lead's push.

**Verification.** `npm run build` and `npm test` green once (1642 tools, 120 component files); after patches `npm run test:tools` 1644/1644 and `lint-docs.sh` 0 problems. `assign`: 327 classes at 16.1/16.1/16.1 min, 115 specs at 17.2/17.1/17.1 min, each listed once. Real runs on `ocupilot-b-ci`, sequential: `ci-runner --shard 40/40` 10 of 329 classes, 78 tests, green, record written; `test:browser:shard -- --shard 40/40` 4 of 115 files, 11 tests, green, record written. Workflow parses as YAML with the seven jobs. All Rule 19 mutations in `## Verification` observed red and reverted byte-identical.

**Residual risks.** Timeouts (40 min) rest on estimates until the lead measures; `actions: read` not added (same-run artifacts use the runtime token, inference); Node 22/24 run the two-reporter form first in the `gates` legs. `home-findings.browser-spec.mjs` was not in the 40/40 share, so nothing was observed about it. `CLAUDE.md`'s "five jobs" line is left for the lead.

Status: done
Blocking condition: none
