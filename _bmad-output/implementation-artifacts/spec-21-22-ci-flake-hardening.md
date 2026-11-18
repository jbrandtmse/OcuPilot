---
title: 'Story 21.22: CI flake hardening'
type: 'chore'
created: '2026-11-15'
status: 'in-progress'
baseline_revision: '71dbd288249a605e50cd8193417b84c57acface6'
baseline_commit: '71dbd288249a605e50cd8193417b84c57acface6'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Eight CI flakes are routed here, each red once and green on an unchanged rerun, plus two test-hygiene entries (DW-2202 literal roster counts, DW-2476 copied settle helpers). The story's criterion: each flake's test waits on the system's own readiness signal or is fixed at its cause, and its entry closes with the evidence.

**Approach:** Fix the three flakes whose cause the code and CI log establish (DW-2534, DW-2565, DW-2553 after a Task 0 measurement). For the five whose cause is not established, land a named diagnosis step that makes the next red name its cause, add the readiness waits that are missing, and close them `wontfix-accepted` with a reopen condition. Take a bounded first slice of DW-2202 and DW-2476 and leave each residual ledgered with a scope note.

**Re-plan ruling (2026-11-18, orchestrator priority):** DW-2721 comes first. The gates job's `client suite` step (`npm test`) on Node 22.22.3 hangs until the job is canceled at 25 minutes with no log (five times on 2026-11-18 across feature and both epics; node 24/26 pass in about 9 minutes). Batch 1 is DW-2721 with DW-2567 and is committable and pushable on its own: a step timeout well under the job's so a hang fails with a log; the resource sampler with OOM lines on failure or cancel; the vitest half run with a bounded worker count and a per-worker heap cap sized for the CI runner's 2 CPUs (a 2-CPU Linux container ran a vitest fork out of heap at file 90 of 286; 4 CPU and macOS stay green); a way for the log to name the hanging file; and the fix. The flakes routed here since the first plan (DW-2627, DW-2648, DW-2649, DW-2685, DW-2713, DW-2714, DW-2720) join the inbox: address each or decline it with a reason. If the whole does not fit in ordered batches, recommend a split, keeping Batch 1 here.

## Boundaries & Constraints

**Always:** a fix removes a cause or waits on a signal the system already exposes; every changed test passes on a fresh environment, in either order; each entry's close carries its evidence (run id, mechanism, or the diagnostic that will name it).

**Never:** a retry, a rerun wrapper or a longer timeout presented as a fix; a new user-facing string; an AD change; editing `interop-editors.browser-spec.mjs` or `interop-viewers.browser-spec.mjs` (Epic 24 changed their imports); a `resolved-by` close on an entry whose cause is not shown.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| DW-2534 late view write | AC1 of web-applications ends with a "myapp" filter write still in flight | AC1 waits until the instance's stored view for `web-applications/list` holds `filter: "myapp"` before closing, so AC5's reset clears the last write | the wait times out naming the stored view it read |
| DW-2565 second boundary | the two `date +%s` reads straddle a second | one clock read per attempt; the 1-second-budget test retries once, under a stepped stub clock with no real sleep | none |
| DW-2553 padding-valid wrong password | a wrong password OpenSSL reports as other than `bad decrypt` (about 1 in 256) | Task 0 measures the vendor's answer; the test's wrong password is chosen deterministically | per Task 0's branch |
| Page load hangs after a long turn (DW-2544, DW-2549, DW-2566) | `page.goto` times out with only the document in flight | the error names whether a fresh Node fetch of the same URL answered, and its status and time | the probe's own failure is reported, never thrown in place of the timeout |
| DW-2548 namespace not yet resolved | AC7 types and runs before the shell resolved `ns` | AC7 waits for the namespace switch to read `ns`, then asserts the start POST carried `ns` and answered 4xx before the banner | the timeout text names whether the POST was sent, its `ns` and status |

</intent-contract>

## Code Map

Batch 1 (DW-2721, DW-2567):

- `.github/workflows/ci.yml:68-72,122-124` -- gates job `timeout-minutes: 20`; step `client suite` runs `npm test` in `ui`. Run 44283101753 (node 22, its green rerun): the step took 4 m 33 s, the tools half 38 s, vitest 190.6 s over 293 files; the default reporter prints a line per file only when it finishes.
- `ui/angular.json` -- `test` target: `@angular/build:unit-test`, runner vitest, no `runnerConfig`. The builder defaults vitest `isolate: false` (`node_modules/@angular/build/src/builders/unit-test/runners/vitest/plugins.js:184`), merges a runner config file's `test` block over that default (`:205`), and takes `runnerConfig` as a path (`executor.js:277`).
- vitest 4.1.11 -- `maxWorkers` defaults to `availableParallelism - 1` (`resolveMaxWorkers` in `dist/chunks/cli-api.*.js`), so a 2-CPU runner runs one fork; `isolate`, `maxWorkers`, `execArgv` and reporter objects with `onTestModuleStart` are config options.
- Measured at plan (macOS, Node 26.8.1, `maxWorkers: 2`): non-isolated, each fork's RSS grew 250 MB to 2.8-2.9 GB over about 146 files (171 s); with `--isolate`, the largest fork peaked at 511 MB (230 s), 293/293 green. One fork carrying all files grows about twice as far (inference), consistent with the orchestrator's 2-CPU heap OOM at file 90.
- `ui/tools/ci.test.mjs:106-111` -- `DECLARED_GATES` holds `'npm test'`; `:230` holds it equal to the workflow's `run:` multiset; `:398` refuses `|| true` and `set +e`; `:2886-2890` (DW-2501) indexes `'npm test'`; `:3279` `jobSteps` parses each step's `run:` and `if:`.
- `ui/tools/angular-json.test.mjs:119-150` -- DW-93 pins the test target and the `test` script.
- `ui/tools/shell-scripts.test.mjs` -- every `scripts/*.sh` declares and parses under its shell (and dash); executing pins run scripts with `stub-bin.mjs` `writeStub`/`stubEnv`.

Batch 2 (causes established):

- `ui/browser/web-applications.browser-spec.mjs:214,227` -- AC1's last `filterToSubset(... 'myapp' ...)` then `context.close()`; cause (run 43445087881, `list-spec.mjs:138`): the late keystroke view write lands after AC5's reset clears `view`. `ui/browser/preferences-reset.mjs:66` `rememberedShellMember` is the sibling; `column-widths.browser-spec.mjs:194-195` reads `views[]` from `GET /api/ocupilot/account/preferences`.
- `scripts/ci-throwaway.sh:998-999` -- two `$(date +%s)` reads straddling a second cause DW-2565 (run 43645120786, `ci.test.mjs:2841`). `ui/tools/ci.test.mjs:2725` `runThrowawayUp` (real 2 s stub sleep); the test at `:2834`.
- `src/OcuPilot/Test/SslSecret.cls:100` -- wrong password `..Sentinel _ "Wrong"`; `src/OcuPilot/Test/X509Material.cls:168` `Run(dir, args...)` runs `openssl`; `src/OcuPilot/Port/AdminPort.cls:3863` `PROPERTYFAULTS` maps `Security.SSLConfig:732:@PrivateKeyPassword`. `irissys/%SYS/X509Credentials.cls:329-333` raises 732 only on `bad decrypt` or `pkcs12 cipherfinal error` (inference for `Security.SSLConfigs`).

Batch 3 (diagnosis and readiness waits):

- `ui/browser/panel-spec.mjs:82` `gotoNamingInflight`, `:101` shared `signedInAt`, used by stream-reply, agent-code-save, agent-picker, screen-permissions-agent and config-settings. Runs 43507916359 and 43543858957: after one turn never ends, each later `goto` times out with only the document in flight while Node fetches answer 200.
- `ui/browser/context-chip.browser-spec.mjs:302` -- a local `signedInAt` with a bare `page.goto`; test 7 at `:502`.
- `ui/browser/analytics-mdx.browser-spec.mjs:109` `writeStatement`, `:122` `pressRun` (clicks with no readiness), `:161` `answeredWith` (names the page state), `:552` AC7. `src/app/areas/analytics/mdx-query.page.ts:245-248` `blocked` (busy or empty statement) drives Run's `aria-disabled` (`:98`). DW-2714 (run 44143834574) and the DW-2522 sighting both read busy false and the idle prompt "Write one MDX statement, then Run.": Run was pressed and never started.
- `ui/browser/list-spec.mjs:56-66` -- `clearFilter`'s wait throws Puppeteer's bare timeout; users AC2 (`users.browser-spec.mjs:211`, run 44178940947) failed there on its second `filterToSubset`.
- `src/OcuPilot/Test/InteropItemRun.cls:102-126` -- `StartProbe` then `WaitJobs(1)`, ten seconds, whose error names only the count.

Batch 4 (bounded slices):

- `ui/tools/browser-settle.test.mjs:250,300` -- `SETTLE_BODIES` and the `declared >= 30` floor; 36 files declare `transitionsSettled`.
- `ui/browser/system-explorer-data-browser-tabs.browser-spec.mjs:313` -- literal 10; derive from `DATA_BROWSER_SHORTCUTS` (`ui/src/app/core/data-browser-model.ts:855`, imported as `rail.browser-spec.mjs:30` imports core TS).
- `src/OcuPilot/Test/WireSecurityRead.cls:782,815,1239` -- literal field counts; derive through `DeclarationJson` as `Dashboard.cls:99` does.

## Tasks & Acceptance

**Execution (four batches in order; each is verifiable, committable and pushable alone; Batch 1 first):**

**Scope of the current pass: Batch 1 only.** Implement the Batch 1 tasks and run the Batch 1 and "Every batch" verification lines and the Batch 1 mutations; do not start Batches 2 to 4 (no `ocupilot-ci`, ObjectScript or browser work). The pass finalizes at `status: in-progress`.

Batch 1 -- the node 22 client-suite hang (DW-2721, DW-2567):

- `ui/vitest-base.config.mjs` (new) -- plain default export (no import): `test.isolate: true` (the fix: no fork carries the module graph of earlier files), `test.maxWorkers: 2`, `test.execArgv: ['--max-old-space-size=1536']` (three times the measured isolated peak), and `test.reporters: ['default', <object reporter>]` whose `onTestModuleStart` prints `vitest start <file relative to ui/>` -- so the file in flight at a cut is named.
- `ui/angular.json` -- `test.options.runnerConfig: "vitest-base.config.mjs"`.
- `ui/tools/angular-json.test.mjs` -- extend the DW-93 test: `runnerConfig` names that file; importing it yields `isolate === true`, a numeric `maxWorkers` of 1 or 2, one `--max-old-space-size=<n>` in `execArgv` with 1024 <= n <= 2048, and a reporter object with `onTestModuleStart`.
- `scripts/ci-resource-sample.sh` (new, `#!/bin/sh`) -- `-- <cmd...>`: runs the command, and every 15 s (`--interval <s>` overrides) prints a UTC stamp, `free -m`'s Mem line, `/proc/loadavg` and the three largest node processes by RSS (`ps`), each reading `unavailable` where the platform lacks it; on exit or a signal it kills the sampler (`$!` captured, `trap`) and exits with the command's status. `--report`: prints the kernel's OOM lines (`sudo -n dmesg`, falling back to `dmesg`), or `no OOM lines`, or `kernel log unavailable`, and exits 0. No `|| true`, no `set +e`.
- `.github/workflows/ci.yml` -- `client suite` runs `sh ../scripts/ci-resource-sample.sh -- npm test` with step `timeout-minutes: 12`; a next step `client suite resources`, `if: failure() || cancelled()`, runs `sh scripts/ci-resource-sample.sh --report` from the repository root.
- `ui/tools/ci.test.mjs` -- `DECLARED_GATES` and the DW-2501 index follow the two `run:` lines; a new test asserts the client suite step's `timeout-minutes` is below the gates job's, its `run:` goes through the sampler, and the step after it is the `--report` step with an `if:` naming both `failure()` and `cancelled()`.
- `ui/tools/shell-scripts.test.mjs` -- executing pins with stub `free`, `ps` and `dmesg`: `--interval 1 -- sh -c 'sleep 2; exit 3'` exits 3 with at least one sample line and leaves no sampler process (a unique marker read through `ps`); `--report` prints the stub's OOM line, and `no OOM lines` for an empty log.

Batch 2 -- causes established (DW-2534, DW-2565, DW-2553). Task 0 (implement, on `ocupilot-ci`, before the DW-2553 tasks; result under Design Notes): loop `X509Material.Run(dir,"pkey","-in",dir_"ssl-key.pem","-passin","pass:"_candidate,"-noout")` over `Sentinel_"Wrong"_n` (n <= 3000) until one candidate's stderr lacks `bad decrypt`; PUT it to `/ssl/<probe>` and record the HTTP status, vendor code and text. Branch **(a)** a code used only for failed key decryption: map it; **(b)** a code shared with another fault: no mapping, add a `deferred:` item naming the gap; **(c)** accepted: add a `deferred:` item.

- `ui/browser/preferences-reset.mjs` -- an exported wait that polls the preferences read until the `views` entry for a route holds an expected `filter`, failing with the stored value last read (DW-2534).
- `ui/browser/web-applications.browser-spec.mjs` -- before AC1's `context.close()`, await it for `web-applications/list` and `myapp` (DW-2534).
- `scripts/ci-throwaway.sh` -- **only if an orchestrator ruling is recorded under Design Notes** (Epic 24 holds an uncommitted edit to this file and the change replaces lines): read the clock once per attempt and derive the deadline and the remainder from it (DW-2565).
- `ui/tools/ci.test.mjs` -- with that task only: `runThrowawayUp` gets a stepped stub `date` on `PATH` (counter file, plus one per read; the first `up` advances it by `firstUpSeconds` instead of sleeping), used by the `:2834` test (DW-2565).
- `src/OcuPilot/Test/X509Material.cls` -- class methods returning a wrong password the image's `openssl pkey` reports as `bad decrypt`, and one it does not (bounded search) (DW-2553).
- `src/OcuPilot/Test/SslSecret.cls` -- the existing test uses the `bad decrypt` helper; branch (a) only, one test saving the other kind and asserting 422 `SSL.PRIVATEKEYPASSWORD.WRONG` on `PrivateKeyPassword` (DW-2553).
- `src/OcuPilot/Port/AdminPort.cls` -- branch (a) only: one `PROPERTYFAULTS` entry for the measured code (DW-2553).

Batch 3 -- diagnosis and readiness waits:

- `ui/browser/panel-spec.mjs` -- `gotoNamingInflight` takes an optional probe; on a navigation timeout it fetches the same URL from Node over a fresh connection (bounded) and appends `node fetch: <status> in <ms> ms` or `node fetch failed: <reason>`; the shared `signedInAt` passes it; a probe failure never replaces the original error (DW-2544, DW-2549, DW-2566, DW-2648, DW-2649, DW-2685).
- `ui/tools/panel-spec.test.mjs` -- pin the appended line for an answering, a failing and an absent probe.
- `ui/browser/context-chip.browser-spec.mjs` -- replace the local `signedInAt` with the shared one or its `trackInflightRequests`/`gotoNamingInflight` pair, and `waitForSlotFree` before test 7's first Send (DW-2566).
- `ui/browser/analytics-mdx.browser-spec.mjs` -- `pressRun` first waits for Run's `aria-disabled` to read `false` (the store holds the statement) and `#ocu-namespace-switch-value` to read the page's namespace, failing with the textarea's value and `aria-disabled` (DW-2714); AC7 then awaits the start POST `/api/ocupilot/analytics/mdx/background`, asserts it carried `ns` and answered 4xx, and only then waits for the banner, whose timeout names the POST's presence, `ns` and status (DW-2548).
- `ui/browser/list-spec.mjs` -- `clearFilter`'s timeout re-reads and names the filter field's value, the grid's `aria-rowcount` and the expected total (DW-2720).
- `src/OcuPilot/Test/InteropItemRun.cls` -- `WaitJobs`'s failing status also names the seconds waited, the production's state and `Facts()` (DW-2713).

Batch 4 -- bounded slices (DW-2202, DW-2476):

- `ui/browser/system-explorer-data-browser-tabs.browser-spec.mjs:313` and `src/OcuPilot/Test/WireSecurityRead.cls:782,815,1239` -- derive the four counts (DW-2202).
- The twelve specs `license-key`, `system-explorer-editor`, `ecp-application-servers`, `system-explorer-transfer`, `journal-settings`, `encryption-startup`, `ecp-settings`, `screen-permissions`, `encryption-keys`, `system-explorer-docdb`, `license-servers`, `oauth-registered-client-editor` (`ui/browser/<name>.browser-spec.mjs`) -- delete the local `transitionsSettled`, import panel-spec's, call it as `transitionsSettled(page, config.navigationTimeoutMs)` (DW-2476).
- `ui/tools/browser-settle.test.mjs` -- replace the `>= 30` floor with a ratchet: the files declaring their own `transitionsSettled` equal a `RESIDUAL_COPIES` list of the 23 not converted (the doc comment says it only shrinks and goes with the last copy), and every caller declaring none imports it from `./panel-spec.mjs`; keep the hollow-body check (DW-2476).

**Acceptance Criteria:**

- Given the gates job on any Node band, when the client suite runs, then its component half runs isolated forks, at most two at once, each with a heap cap, and its log names each test file as it starts (DW-2721).
- Given a client suite that hangs, when 12 minutes pass, then the step fails with its log kept, holding 15-second memory, load and process samples, and the next step prints the kernel's OOM lines or says there are none (DW-2721, DW-2567).
- Given a fork that outgrows its cap, when the suite runs, then the run fails non-zero naming the out-of-memory fork and the file it had started, and does not hang (DW-2721).
- Given AC1 left a filter write in flight, when AC5 starts, then it reads the unfiltered list, because AC1 returned only once the instance held its last write (DW-2534).
- Given the bind-budget test under a clock that advances one second per read, when the first attempt fails, then the script retries once, with no real sleep (DW-2565, if ruled).
- Given `SslSecret`'s wrong password, when the test runs, then it is always one OpenSSL reports as `bad decrypt`; on Task 0's branch (a), a wrong password of the other kind is also refused on its field (DW-2553).
- Given a page load that times out, when the error is thrown, then it names the in-flight requests and a fresh Node fetch's result for the same URL (the page-load entries).
- Given an MDX test, when Run is pressed, then the statement was already in the screen's store and the namespace resolved; a run that never starts or a missing banner names what the page and the start POST did (DW-2714, DW-2548).
- Given `clearFilter` or `WaitJobs` times out, when the error is raised, then it names the state it last read (DW-2720, DW-2713).
- Given the four derived counts and the twelve converted specs, when a roster gains a member or a spec declares a new copy, then no literal needs editing and the ratchet reddens (DW-2202, DW-2476).

## Spec Change Log

- 2026-11-18 (runner): re-plan for the orchestrator's priority ruling (DW-2721 first) and seven newly routed flakes; status reset to draft.

## Review Triage Log

### 2026-11-18 — Review pass (Batch 1)

- verdicts: 12 findings — high 0, medium 0, low 10, false 1, maybe-false 1
- findings:
  - `[low]` `[patch]` sampler header promised signal handling the script defers until the command returns — verified by the reviewer under sh and bash; the header now states what the trap does (a group signal ends command and sampler; a signal to the script alone is acted on after the command returns). No test added: the deferral is not a promised behavior.
  - `[low]` `[reject]` reporter and `maxWorkers` reaching the real builder are pinned only on the config file, plus the manual `vitest start` lines and the cap mutation — an include-limited `ng test` inside `test:tools` is a heavy fix for a regression only a toolchain bump could cause.
  - `[low]` `[reject]` no mutation for the 15-second clause or the `out of memory` and `oom_reaper` patterns — one demonstrated mutation per AC is the bar and each Batch 1 AC has one.
  - `[low]` `[reject]` AC3 (fork out of heap fails non-zero naming its file) rests on the observed macOS mutation — it cannot be reproduced on 2-CPU Linux here; CI's node 22.22.3 leg is the evidence the spec names.
  - `[low]` `[patch]` the `ci.test.mjs` message said a timed-out step becomes canceled — a step timeout fails the step; the message now says the cancel condition covers a superseded run or the job's own bound.
  - `[low]` `[reject]` the `if:` pin is two loose regexes, so `failure() && !cancelled()` would pass — nobody is expected to write that; a stricter match adds a parser for no named harm.
  - `[false]` `[reject]` module-level `printed` Set makes the reporter test order-dependent — the test imports the module once and prints two distinct files; the Set only dedupes within one run.
  - `[maybe-false]` `[reject]` 12-minute bound against the isolated 2-worker run time on a 2-CPU runner — the green node 22 run took 4 m 33 s and isolation added 35% locally (about 6 minutes, inference); the node 22.22.3 gates leg judges it. Would be low if wrong: a red step with its log.
  - `[low]` `[reject]` intent audit: the expectation lives on the hosted node 22.22.3 runner and the local runs are macOS and Node 26 — known; the spec names that leg as DW-2721's evidence.
  - `[low]` `[reject]` intent audit: the cause is measured on macOS and the 2-CPU extrapolation is an inference — the spec labels it so; no code claims otherwise.
  - `[low]` `[reject]` intent audit: the sampler and report run against stubs, not the runner's real `/proc` and `dmesg` — the three outcomes are each a reported sentence; the CI log shows the real read.
  - `[low]` `[reject]` intent audit: the log names the file by its start line, and with two workers the last line may not be the hung file — the default reporter prints each file as it finishes, so the unfinished files are the difference.

## Design Notes

**ADs:** none binds the client test runner's pool settings; the spine's Stack rows "Client test runners" and "CI" stay true as written. AD-19 (the screen's own signal is the readiness signal: Run's `aria-disabled`, the stored view), AD-14, AD-43, AD-7 (a turn's slot), AD-17 (test classes only on a throwaway), AD-36. Test-and-CI only apart from Task 0's branch (a). No AD change.

**Consumes:** the shared helpers in `panel-spec.mjs`, `list-spec.mjs`, `preferences-reset.mjs`, `turnprobe-spec.mjs`, `X509Material`, `stub-bin.mjs`. No consumers: nothing here is a service.

**Rule 2:** the sampler pins extend `shell-scripts.test.mjs`; the runner-config pins extend `angular-json.test.mjs`'s DW-93 test; the preferences wait extends `preferences-reset.mjs`; the probe extends `gotoNamingInflight`; context-chip drops its `signedInAt` copy; `pressRun` gains the wait for every MDX test rather than a per-test copy; the password helpers extend `X509Material`. The sampler is new: no script samples resources.

**Declined DW-2627:** not a flake; its cause (config-settings left a SQL setting changed) was fixed by 6a5bcf05f, merged with 21.24 at 48e3593a3, and no occurrence follows 2026-11-16T05:07Z. The runner closes it `resolved-by` 21.24's key.

**Ledger closes, written by the runner at adjudication:**

- DW-2721, DW-2567: `resolved-by:21-22-ci-flake-hardening` once the Batch 1 head's node 22.22.3 gates leg is green and the cap mutation is recorded; mechanism: per-fork heap growth in non-isolated vitest forks (measured), removed by isolation, bounded by the cap and the step timeout.
- DW-2534, DW-2565 (if ruled), DW-2714: `resolved-by` with the mechanisms above.
- DW-2553: `resolved-by` on branch (a); on (b) or (c), `wontfix-accepted note=reopen_if=SslSecret's deterministic wrong password reddens again`.
- DW-2544, DW-2549, DW-2566, DW-2648, DW-2649, DW-2685 (one page-load signature; DW-1545 and DW-2512 are earlier sightings): `wontfix-accepted note=reopen_if=a page.goto timeout whose node fetch line shows the instance answering or not`.
- DW-2548, DW-2720, DW-2713: `wontfix-accepted note=reopen_if=<the test> reddens again; its text names the state it read`.
- DW-2202: residual re-owned `note=residual: WireSecurityRead 19 + WireOAuthRead 5 per-principal roster literals (each test keeps its own containment literal); web-applications-actions:430 unchecked`.
- DW-2476: residual re-owned `note=residual: 23 copies in browser-settle.test.mjs RESIDUAL_COPIES`.

**Epic 24 contention** (2026-11-18): no Epic 24 commit ahead of feature on any path above; the epic-24 worktree holds an uncommitted edit to `scripts/ci-throwaway.sh`, so the DW-2565 task waits for an orchestrator ruling (it replaces lines). Epic 24's `interop-editors` and `interop-viewers` specs stay out.

**Decided in-stage:**

- Batch 1: the start reporter prints on `onTestModuleQueued` as well as `onTestModuleStart`, once per file. Vitest reports a file as started only after its import, so a fork that runs out of memory during the import never named its file; it is reported as queued when the worker begins it (measured: two forks died on files with no start line until this change).
- Batch 1: `maxWorkers: 2` and the 1536 MB cap hold on macOS; the spec's mutation cap of 512 does not fail there, so the recorded mutation uses 256.
- The fix is isolation, not the cap: the measurement shows growth per fork, and a cap alone turns a hang into a crash. `maxWorkers: 2` keeps a 2-CPU runner from oversubscribing and leaves a 4-CPU runner one worker short (plan-measured cost: isolation added 35% locally).
- 12 minutes for the step is over twice the slowest green client suite (4 m 33 s) and leaves the 20-minute job room for its report step.
- `runnerConfig` goes in `angular.json` so `npx ng test` and `npm test` load the same settings.
- No Linux container reproduction: the shared-resource rule bars extra instances; the evidence is the local measurement, the cap mutation and CI's node 22 leg.
- The page-load group gains DW-2648, DW-2649 and DW-2685: each failed in `signedInAt` with one request in flight.
- DW-2714 joins DW-2548 in `pressRun`: the page state shows Run pressed while the statement was not yet in the store.
- DW-2476 takes twelve non-interop copies under a ratchet; DW-2202 takes the four count literals (the 24 per-principal literals carry high fix-risk).

## Verification

**Shared surfaces:** `ci.test.mjs`'s `DECLARED_GATES` and gates step pins, `angular-json.test.mjs`'s test target, `shell-scripts.test.mjs`'s `scripts/*.sh` population, `browser-settle.test.mjs`'s settle-helper census, `AdminPort.PROPERTYFAULTS` (branch a). The implement stage greps `ui/browser`, `ui/tools`, the `ui/src` specs and `src/OcuPilot/Test` for each; every test it changes joins `(loop)`.
*Every test added or changed passes on a fresh environment, in either order.*

**Commands.** One per foreground call, `timeout: 600000`; ObjectScript and browser runs against `ocupilot-ci` only, never two test calls in one message. Every browser run follows `cd ui && npm run build` and `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`.

Batch 1:

- `(loop)` `cd ui && node --test tools/ci.test.mjs tools/angular-json.test.mjs tools/shell-scripts.test.mjs` -- green.
- `(loop)` the component suite in three calls, each about 2 minutes: `cd ui && sh ../scripts/ci-resource-sample.sh -- npx ng test --include 'src/app/areas/os-management/**/*.spec.ts' --include 'src/app/areas/security/**/*.spec.ts'`, then `--include 'src/app/areas/**/*.spec.ts' --exclude 'src/app/areas/os-management/**' --exclude 'src/app/areas/security/**'`, then `--exclude 'src/app/areas/**'` -- green, with `vitest start` and sample lines in the output.
- `(once)` `sh scripts/ci-resource-sample.sh --report` -- exit 0 and one of its three sentences.

Batches 2-4:

- `(loop)` `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/b708a79b-b765-42ec-adea-dbc87acf6251/scratchpad/e21u/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` -- `LOADERRORS=0`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.SslSecret`, then `InteropItemRun`, then `WireSecurityRead`, one call each -- green.
- `(loop)` `cd ui && node --test tools/ci.test.mjs tools/panel-spec.test.mjs tools/browser-settle.test.mjs` -- green.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/web-applications.browser-spec.mjs browser/analytics-mdx.browser-spec.mjs browser/users.browser-spec.mjs browser/context-chip.browser-spec.mjs` -- green.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/stream-reply.browser-spec.mjs browser/agent-code-save.browser-spec.mjs browser/system-explorer-data-browser-tabs.browser-spec.mjs` -- green.
- `(loop)` `cd ui && node --test --test-concurrency=1` over the twelve Batch 4 specs, in two calls of six -- green.

Every batch:

- `(loop)` `uv run scripts/check-objectscript.py`, `uv run scripts/test_check_objectscript.py`, `bash scripts/lint-docs.sh` -- clean.
- `(once)` `cd ui && npm run test:tools` -- green.
- `(once)`, runner-owned: the full ObjectScript sweep one class per call, `smoke.sh --container ocupilot-ci`, Rule 30's fresh check. The full browser suite and the node 22.22.3 gates leg are CI's; the Batch 1 head's run is DW-2721's evidence.

**Mutations (Rule 19), one per AC, each applied, observed red, reverted (tree identical by `git status --short` and `git diff --stat`), reverted ObjectScript reloaded:**

- Isolation and cap: set `isolate: false` and the cap to 512 -> the os-management and security call exits non-zero naming the out-of-memory fork, with a `vitest start` line for a file that never finished, inside the call; drop `runnerConfig` from `angular.json` -> `angular-json.test.mjs` red.
  - mutation (Batch 1, observed): `isolate: false` with the cap at 512 stayed green on macOS (92 files, 2 forks peaked near 380 MB RSS); with the cap at 256 the call exited 1 in 45 s with two `FATAL ERROR ... JavaScript heap out of memory` blocks, two `Worker exited unexpectedly` errors, and `vitest start` lines for `mapping-form.page.spec.ts` and `superserver-actions.spec.ts`, which never finished. Reverted; tree identical.
  - mutation (Batch 1, observed): delete `runnerConfig` from `angular.json` -> `angular-json.test.mjs` red at "the target names the runner config file"; set `isolate: false` in `vitest-base.config.mjs` -> the same test red. Reverted; tree identical.
- Step bound: drop the step's `timeout-minutes`, or the `--report` step's `cancelled()` -> `ci.test.mjs` red; the sampler stops propagating the command's status, or stops killing its sampler -> `shell-scripts.test.mjs` red.
  - mutation (Batch 1, observed): delete the step's `timeout-minutes` -> `ci.test.mjs` red ("carries its own timeout-minutes"); the report step's `if:` narrowed to `failure()` -> red ("after a cancellation"); the script ends `exit 0` -> `shell-scripts.test.mjs` red ("the command's own status"); drop `trap stop_sampler EXIT` and the `stop_sampler` call -> red ("no process carrying the marker survives"); drop `killed process` from the OOM pattern -> the `--report` test red. Each reverted; tree identical.
- DW-2534: delete AC5's `resetRememberedState()` -> AC5 red with CI's message; point AC1's wait at `myap` -> AC1 red naming the stored view.
- DW-2565: restore the second `date` read -> the stepped-clock test red.
- DW-2553: the existing test draws from the non-`bad decrypt` helper -> red; branch (a): drop the new `PROPERTYFAULTS` entry -> the new test red.
- Probe: the shared `signedInAt` stops passing the probe -> `panel-spec.test.mjs` red.
- DW-2566: drop test 7's `waitForSlotFree` and delay test 6's slot release -> test 7 red.
- DW-2714/DW-2548: `writeStatement` stops dispatching `input` -> AC1 red at `pressRun` naming the textarea and `aria-disabled` within the navigation timeout, not after 145 s; `mdx-query.page.ts:201` scope answers `''` -> AC7's `ns` assertion red.
- DW-2720: pass AC2's `filterToSubset` a total one too high -> red naming the field, count and total. DW-2713: `StartProbe` waits for 2 jobs -> red naming state and seconds.
- DW-2202: the SystemUsage read drops one declared field -> the derived `WireSecurityRead` assertion red; the data browser renders one shortcut fewer -> the browser assertion red.
- DW-2476: re-add a copy to a converted spec -> the ratchet red; drop a converted spec's import -> the import check red.

## Auto Run Result

Status: in-progress
Blocking condition: none

Batch 1 implemented (DW-2721, DW-2567); Batches 2 to 4 not started. Added `ui/vitest-base.config.mjs` (isolated forks, `maxWorkers: 2`, 1536 MB heap cap, start reporter), `runnerConfig` in `ui/angular.json`, `scripts/ci-resource-sample.sh`, the workflow's bounded `client suite` step (12 minutes) and `client suite resources` report step, and the pins in `ci.test.mjs`, `angular-json.test.mjs` and `shell-scripts.test.mjs`. Verified: the three test files green (135), the component suite in three sampled calls (92 + 121 + 80 = 293 files, 3581 tests green), `--report` exit 0, the Batch 1 mutations above, `check-objectscript` clean. Review: 12 findings, none high or medium; 2 low patches applied (sampler header wording, one test message), 9 rejected with reasons in the triage log, none deferred; follow-up review not recommended. After the patches: the three test files green (135), `npm run test:tools` green (2319). Residual: nothing was run on Linux or Node 22; the node 22.22.3 gates leg on the pushed head is DW-2721's evidence, and the 12-minute step bound against the isolated run time is judged there.
