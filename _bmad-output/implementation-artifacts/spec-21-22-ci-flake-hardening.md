---
title: 'Story 21.22: CI flake hardening'
type: 'chore'
created: '2026-11-15'
status: 'draft'
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

- `ui/browser/web-applications.browser-spec.mjs:214-227` -- AC1's last `filterToSubset('myapp')` then `context.close()`; AC5 (`:230`) reads `total` after `signedInAtList`'s reset. Cause (CI run 43445087881 job 131952325102, `list-spec.mjs:138`): the late keystroke write (`screen-store.ts:532-536,608-618`, `account-preferences.ts:425-450`, sent one at a time, newest last) lands after the reset's `view` clear, so AC5 opens filtered.
- `ui/browser/preferences-reset.mjs:66` -- `rememberedShellMember`; the new remembered-view wait goes beside it (add-only). `column-widths.browser-spec.mjs:194-195` already reads `GET /api/ocupilot/account/preferences` `views[]`.
- `scripts/ci-throwaway.sh:954-955` -- two `$(date +%s)` reads; the cause of DW-2565 (run 43645120786 job 132601047925, `ci.test.mjs:2841` `1 !== 0`, "still bound after 1 attempt(s) over a 1 second budget"). Epic 24 has three commits on this file (near line 600); 21.24 changed it in this epic (37538ee8a).
- `ui/tools/ci.test.mjs:2725-2786` -- `runThrowawayUp` (real 2 s docker-stub sleep at `:2745`, comment `:2733`); the test at `:2834-2843`. `:230` pins the workflow's `run:` multiset against `DECLARED_GATES`; `:398` refuses `|| true` anywhere in the workflow.
- `src/OcuPilot/Test/SslSecret.cls:49-55,89-118` -- the key is PKCS#8 AES-256-CBC under `..Sentinel`; the wrong password is `..Sentinel _ "Wrong"` (`:100`); assertions `:103` (422 on `PrivateKeyPassword`) and `:116` (`#732` in the log). Armed; throwaway only.
- `src/OcuPilot/Test/X509Material.cls:168` -- `Run(dir, args...)` runs `openssl`; the deterministic wrong-password helper extends this class (Rule 2).
- `src/OcuPilot/Port/AdminPort.cls:3846` -- `PROPERTYFAULTS` maps `Security.SSLConfig:732:@PrivateKeyPassword` to `SSL.PRIVATEKEYPASSWORD.WRONG` (reason exists, `Api/Error.cls:3826-3828`). `irissys/%SYS/X509Credentials.cls:329-333` raises 732 only on `bad decrypt` or `pkcs12 cipherfinal error` (inference for `Security.SSLConfigs`, deployed without source).
- `ui/browser/panel-spec.mjs:82-93` -- `gotoNamingInflight`, used by the shared `signedInAt` (`:115`); the diagnosis probe extends it (add-only). Tests in `ui/tools/panel-spec.test.mjs`.
- `ui/browser/context-chip.browser-spec.mjs:302-314` -- a local `signedInAt` with a bare `page.goto`; test 7 (`:502`) sends without `waitForSlotFree` (`turnprobe-spec.mjs`) after test 6.
- `ui/browser/stream-reply.browser-spec.mjs`, `ui/browser/agent-code-save.browser-spec.mjs` -- use the shared `signedInAt`; no edit. Logs: runs 43507916359 (shard 4/5) and 43543858957 (shard 5/5) show one turn never ending, then each later `goto` timing out with only `/ocupilot/?ns=` in flight while `resetRememberedState`'s Node fetches return 200; a fresh browser recovers.
- `ui/browser/analytics-mdx.browser-spec.mjs:552-568` -- AC7 writes and runs before the shell resolved `ns` (`scope.ts:214` answers `''`; `api.ts:443-445` then sends no `ns`). Signals: `#ocu-namespace-switch-value` (`namespace-switch.ts:89`), the start POST `/api/ocupilot/analytics/mdx/background`.
- `.github/workflows/ci.yml:120-122` -- gates `client suite` step (`npm test`); job `timeout-minutes: 20` (`:73`). Run 43675769752 job 132695467996: `The runner has received a shutdown signal` at 04:16:38.20 precedes every `EPIPE`; run 43713431335's log is gone (`BlobNotFound`). vitest 4.1.11, default `forks` pool, no config file; the upstream EPIPE bug (vitest#9014) is fixed in 4.0.10.
- `ui/tools/browser-settle.test.mjs:250,291-301` -- `SETTLE_BODIES` and the `declared >= 30` floor.
- `ui/browser/system-explorer-data-browser-tabs.browser-spec.mjs:313` -- literal 10 shortcuts; derive from `DATA_BROWSER_SHORTCUTS` (`ui/src/app/core/data-browser-model.ts:855`, imported the way `rail.browser-spec.mjs:30` imports core TS).
- `src/OcuPilot/Test/WireSecurityRead.cls:782,815,1239` -- literal field counts 18, 9, 24; derive through `DeclarationJson` as `Dashboard.cls:99` does.

## Tasks & Acceptance

**Execution (three batches, each verifiable and committable on its own):**

Task 0 (implement stage, on `ocupilot-ci`, before Batch 1's DW-2553 task; record the result under Design Notes). Loop `X509Material.Run(dir,"pkey","-in",dir_"ssl-key.pem","-passin","pass:"_candidate,"-noout")` over `Sentinel_"Wrong"_n` until one candidate's stderr lacks `bad decrypt` (bound the loop at 3000). PUT that candidate to `/ssl/<probe>` and record the HTTP status, the vendor's status code and its text. Branch: **(a)** the vendor answers a code it uses only for a failed key decryption: map it in `PROPERTYFAULTS`; **(b)** the code is shared with another fault (a key and certificate mismatch): no mapping, and add a `deferred:` item naming the measured gap; **(c)** the vendor accepts it: add a `deferred:` item. The plan stage ran nothing here: `ocupilot-ci` was in use by another stage.

Batch 1, causes established:

- `ui/browser/preferences-reset.mjs` -- add an exported wait that polls the preferences read until the `views` entry for a route holds an expected `filter`, failing with the stored value it last read -- the system's own record of the write (DW-2534).
- `ui/browser/web-applications.browser-spec.mjs` -- before AC1's `context.close()`, await that wait for `web-applications/list` and `myapp` (DW-2534).
- `scripts/ci-throwaway.sh` -- **ask the orchestrator first** (Epic 24 changed this file, and this replaces two lines). Read the clock once per attempt (`BIND_NOW=$(date +%s)`) and derive the deadline and the remainder from it (DW-2565).
- `ui/tools/ci.test.mjs` -- give `runThrowawayUp` a stepped stub `date` on `PATH` (a counter file, plus one per read; the first `up` advances it by `firstUpSeconds` instead of sleeping); use it in the `:2834` test; correct the `:2733` comment (DW-2565).
- `src/OcuPilot/Test/X509Material.cls` -- add a class method returning a wrong password the image's `openssl pkey` reports as `bad decrypt`, and one returning a wrong password it does not (bounded search) (DW-2553).
- `src/OcuPilot/Test/SslSecret.cls` -- the existing test uses the `bad decrypt` helper. Branch (a) only: add one test saving the other kind and asserting 422 `SSL.PRIVATEKEYPASSWORD.WRONG` on `PrivateKeyPassword` (DW-2553).
- `src/OcuPilot/Port/AdminPort.cls` -- branch (a) only: one `PROPERTYFAULTS` entry for the measured code (DW-2553).

Batch 2, diagnosis steps and missing readiness waits:

- `ui/browser/panel-spec.mjs` -- `gotoNamingInflight` takes an optional probe; on a navigation timeout it fetches the same URL from Node over a fresh connection (bounded) and appends `node fetch: <status> in <ms> ms` or `node fetch failed: <reason>`; the shared `signedInAt` passes it. A probe failure never replaces the original error (DW-2544, DW-2549, DW-2566).
- `ui/tools/panel-spec.test.mjs` -- pin the appended line for an answering, a failing and an absent probe.
- `ui/browser/context-chip.browser-spec.mjs` -- replace the local `signedInAt` with the shared one or its `trackInflightRequests` and `gotoNamingInflight` pair (Rule 2), and add `waitForSlotFree` before test 7's first Send (DW-2566).
- `ui/browser/analytics-mdx.browser-spec.mjs` -- AC7 waits for `#ocu-namespace-switch-value` to read `ns`, awaits the start POST's response, asserts it carried `ns` and answered 4xx, and only then waits for the banner, whose timeout text names the POST's presence, `ns` and status (DW-2548).
- `scripts/ci-resource-sample.sh` (new) -- runs a command under a sampler printing `free -m` and `/proc/loadavg` every 15 s, kills the sampler on exit (capture `$!`, `trap`), and exits with the command's status; a `--report` mode prints kernel OOM lines. No `|| true` (DW-2567).
- `.github/workflows/ci.yml` -- gates `client suite` runs `npm test` through the sampler with a step `timeout-minutes` below the job's 20; a following step with `if: failure() || cancelled()` runs `--report` (DW-2567).
- `ui/tools/ci.test.mjs` -- `DECLARED_GATES` and any step pin follow the new `run:` lines (DW-2567).

Batch 3, bounded slices:

- `ui/browser/system-explorer-data-browser-tabs.browser-spec.mjs:313` and `src/OcuPilot/Test/WireSecurityRead.cls:782,815,1239` -- derive the four counts (DW-2202).
- The twelve specs `license-key`, `system-explorer-editor`, `ecp-application-servers`, `system-explorer-transfer`, `journal-settings`, `encryption-startup`, `ecp-settings`, `screen-permissions`, `encryption-keys`, `system-explorer-docdb`, `license-servers`, `oauth-registered-client-editor` (all `ui/browser/<name>.browser-spec.mjs`) -- delete the local `transitionsSettled`, import panel-spec's, and call it as `transitionsSettled(page, config.navigationTimeoutMs)` (DW-2476).
- `ui/tools/browser-settle.test.mjs` -- replace the `>= 30` floor with: the set of files declaring their own `transitionsSettled` equals a `RESIDUAL_COPIES` list of the 23 not converted (a ratchet: converting one or adding one goes red; the doc comment says the list only shrinks and is deleted with the last copy), and every caller that declares none imports it from `./panel-spec.mjs`. Keep the hollow-body check (DW-2476).

**Acceptance Criteria:**

- Given AC1 left a filter write in flight, when AC5 starts, then it reads the unfiltered list, because AC1 returned only once the instance held its last write (DW-2534).
- Given the bind-budget test under a clock that advances one second per read, when the first attempt fails, then the script retries once, with no real sleep (DW-2565).
- Given `SslSecret`'s wrong password, when the test runs, then it is always one OpenSSL reports as `bad decrypt`; and on Task 0's branch (a), a wrong password of the other kind is also refused on its field (DW-2553).
- Given a page load that times out, when the error is thrown, then it names the in-flight requests and the result of a fresh Node fetch of the same URL (DW-2544, DW-2549, DW-2566).
- Given AC7 (QA) of analytics-mdx, when Run is pressed, then the namespace was already resolved, and a missing banner reports what the start POST did (DW-2548).
- Given the gates client suite, when it fails or is cut off, then its log holds memory and load samples and the kernel's OOM lines (DW-2567).
- Given the four derived counts and the twelve converted specs, when a member is added to a roster or a spec declares a new copy, then no literal needs editing and the ratchet test reddens (DW-2202, DW-2476).

## Spec Change Log

- 2026-11-18 (runner): re-plan for the orchestrator's priority ruling (DW-2721 first) and seven newly routed flakes; status reset to draft.

## Review Triage Log

## Design Notes

**ADs:** AD-19 (screen stores notify; the answered state is the readiness signal), AD-14, AD-43, AD-7 (the turn polls; a proposal card appears by poll), AD-17 (test classes only on a throwaway), AD-36. Test-only apart from Task 0's branch (a), one fault-map entry. No AD changes.

**Consumes:** the shared helpers in `panel-spec.mjs`, `preferences-reset.mjs`, `turnprobe-spec.mjs`, `X509Material`. No consumers: nothing here is a service.

**Rule 2:** the preferences wait extends `preferences-reset.mjs`; the probe extends `gotoNamingInflight`; context-chip drops its `signedInAt` copy; the password helpers extend `X509Material`; the sampler is a new script because no sibling samples resources.

**Ledger closes, written by the runner at adjudication:**

- DW-2534, DW-2565: `resolved-by:21-22-ci-flake-hardening` with the mechanism above.
- DW-2553: `resolved-by` on branch (a); on (b) or (c), `wontfix-accepted note=reopen_if=SslSecret's deterministic wrong password reddens again`, and the measured gap is harvested from `deferred:`.
- DW-2544, DW-2549, DW-2566 (one signature; DW-1545 and DW-2512 are earlier sightings): `wontfix-accepted note=reopen_if=a page.goto timeout whose node fetch line shows the instance answering (browser side) or not answering (instance side)`.
- DW-2548: `wontfix-accepted note=reopen_if=AC7 reddens again; its text names the start POST's ns and status`.
- DW-2567: `wontfix-accepted note=reopen_if=a gates client suite fails without a preceding runner shutdown line, or the sampler or --report shows memory at the limit`.
- DW-2202: residual re-owned with `note=residual: WireSecurityRead 19 + WireOAuthRead 5 per-principal roster literals (derive via Wire.ExpectedScreens with held pairs, keep a per-screen containment literal); web-applications-actions:430 unchecked`. Fix-risk high: both sides would read the same gate, so each test must keep its own containment literal.
- DW-2476: residual re-owned with `note=residual: 23 copies listed in browser-settle.test.mjs RESIDUAL_COPIES, including interop-editors and interop-viewers after Epic 24 merges`.

**Epic 24 contention** (`git log origin/OCU-1-epic24 ^origin/feature/OCU-1_ocupilot-mvp -- <path>`, 2026-11-16): `scripts/ci-throwaway.sh` has 3 commits (`12f9fd65c`, `87704295e`, `c25e3207b`; ask first). Empty for every other file above: `web-applications`, `context-chip`, `stream-reply`, `agent-code-save`, `analytics-mdx` and `system-explorer-data-browser-tabs` specs, `panel-spec.mjs`, `preferences-reset.mjs`, `turnprobe-spec.mjs`, `tools/panel-spec.test.mjs`, `tools/ci.test.mjs`, `tools/browser-settle.test.mjs`, `.github/workflows/ci.yml`, `SslSecret.cls`, `X509Material.cls`, `AdminPort.cls`, `WireSecurityRead.cls`, and the twelve slice specs. Epic 24 changed `interop-editors` and `interop-viewers`, which stay out. `origin/OCU-1-epic22` no longer exists. No flake entry lives wholly in Epic 24's footprint: agent-code-save's cause is the shared page-load signature, not the agent's tools.

**Decided in-stage:**

- The tree held 21.24's uncommitted work when this plan started (committed as 37538ee8a during it); the plan wrote only this spec. The committed epic context was reused, as the plan block directs.
- DW-2476 takes the twelve fastest non-interop copies (about 3 minutes of browser time) under a ratchet, not all 33: it fixes no flake (none of the five flake specs holds a copy).
- DW-2202 takes the four count literals; the 24 per-principal literals carry high fix-risk.
- No Chrome net-log: the Node probe alone separates the browser side from the instance side.

## Verification

**Shared surfaces:** `browser-settle.test.mjs`'s settle-helper census, `ci.test.mjs`'s `DECLARED_GATES` and step pins, `AdminPort.PROPERTYFAULTS` (branch a only; sweep `src/OcuPilot/Test` for tests that count or list it). The implement stage greps `ui/browser`, `ui/tools`, the `ui/src` specs and `src/OcuPilot/Test` for each; every test it changes joins `(loop)`.
*Every test added or changed passes on a fresh environment, in either order.*

**Commands.** One per foreground call, `timeout: 600000`, against `ocupilot-ci` only, never two test calls in one message. Every browser spec run follows `cd ui && npm run build` and `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`.

- `(loop)` `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/b708a79b-b765-42ec-adea-dbc87acf6251/scratchpad/e21u/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` -- expected: `LOADERRORS=0`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.SslSecret`, then the same for `WireSecurityRead`, and for any class the shared-surface sweep changes -- expected: green.
- `(loop)` `cd ui && node --test tools/ci.test.mjs tools/panel-spec.test.mjs tools/browser-settle.test.mjs` -- expected: green.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/web-applications.browser-spec.mjs browser/analytics-mdx.browser-spec.mjs browser/system-explorer-data-browser-tabs.browser-spec.mjs browser/context-chip.browser-spec.mjs` -- expected: green.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/stream-reply.browser-spec.mjs browser/agent-code-save.browser-spec.mjs` -- expected: green.
- `(loop)` `cd ui && node --test --test-concurrency=1` over the twelve Batch 3 specs -- expected: green.
- `(loop)` `bash scripts/ci-resource-sample.sh -- true` and `-- false` -- expected: exit 0 and 1, sampler gone afterwards.
- `(loop)` `uv run scripts/check-objectscript.py`, `uv run scripts/test_check_objectscript.py`, `bash scripts/lint-docs.sh` -- expected: clean.
- `(once)` `cd ui && npm run test:tools` and `npm run test:components` -- expected: green.
- `(once)`, runner-owned: the full ObjectScript sweep one class per call, `smoke.sh --container ocupilot-ci`, Rule 30's fresh check. The full browser suite is left to CI, whose run is also the first evidence for Batch 2's diagnostics.

**Mutations (Rule 19), one per AC, each applied, observed red, reverted (tree identical by `git status --short` and `git diff --stat`), reverted source reloaded:**

- DW-2534: delete AC5's `resetRememberedState()` call -> AC5 red with CI's message (the mechanism); point AC1's wait at `myap` -> AC1 red naming the stored view. The race itself cannot be forced locally.
- DW-2565: restore the second `date` read -> the stepped-clock test red.
- DW-2553: the existing test draws from the non-`bad decrypt` helper -> red; branch (a): drop the new `PROPERTYFAULTS` entry -> the new test red.
- Probe: the shared `signedInAt` stops passing the probe -> `panel-spec.test.mjs`'s probe line test red.
- DW-2566: drop test 7's `waitForSlotFree` and delay test 6's slot release -> test 7 red.
- DW-2548: `mdx-query.page.ts:201` scope answers `''` -> AC7's `ns` assertion red.
- DW-2567: the sampler stops propagating the command's status -> the `-- false` check red; drop the `--report` step -> `ci.test.mjs` red.
- DW-2202: the SystemUsage read drops one declared field -> the derived `WireSecurityRead` assertion red; the data browser renders one shortcut fewer -> the derived browser assertion red.
- DW-2476: re-add a copy to one converted spec -> the ratchet red; drop one converted spec's import -> the import check red.

**Runner ruling at the spec gate (2026-11-16):** validated. The `scripts/ci-throwaway.sh` two-line clock fix (DW-2565) and the `.github/workflows/ci.yml` sampler step (DW-2567) are asked of the orchestrator before implement, the first because Epic 24 has changed that file and the edit is not add-only, the second because the workflow is shared by every branch. The implement stage builds those two tasks only if a ruling is recorded here.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
