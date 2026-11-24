---
title: "Story 21.40: The governance page's render cost"
type: 'bugfix'
created: '2026-11-23'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-21-context.md'
warnings: ['oversized']
deferred:
  - summary: 'Every governance read rebuilds the tool registry: Registry.ListTools takes 1.17 s in a new process (617 tools) and 5 ms once cached, and the process cache does not outlive a REST request, so it is about 1.2 s of the read''s 1.6 s.'
    evidence: 'ocupilot-ci 2026-11-23, tree 90e0b706d: ListTools first call 1.169 s, second 0.005 s; Effective after a warm ListTools 0.428 s; GET /agent/governance 1.65 s by curl. Grows per registered tool, not per key; out of this page''s footprint.'
    location: 'src/OcuPilot/Screen/Tool/Registry.cls:114 ListTools'
    severity: low
---

<intent-contract>

## Intent

**Problem:** DW-1822: CI's structural walk loses the renderer at the 1280 px light settle of `/ocupilot/agent/governance`, and the governance key list keeps growing. Measured on `ocupilot-ci` (Design Notes): the page's render is one 0.13-0.18 s long task at 4x CPU throttle (0.22 s at double the keys). The read behind it is quadratic: `Policy.Effective` re-parses the Baseline XData twice per key, which takes 0.43 s at 371 keys and about 2.3 s at 742.

**Approach:** Cut the per-row work where it grows faster than the key list: a governance read parses the Baseline once and resolves every row from that one parse. Add a browser test that bounds the page's settle and its longest task under 4x throttle at double the instance's key count. The extra keys are added only inside the test's browser.

## Boundaries & Constraints

**Always:**

- The read's answer (`{preset, rowVersion, keys[{key, baseline, setting, enabled, source}]}`) and its row order are byte-for-byte unchanged for the same instance state.
- The Gate path (`Policy.Resolve` → `Cascade` → `Baseline.Seed`) reads the stored policy and the baseline on every call, as today (AD-22). Only `Effective` uses the single parse.
- The test's synthetic keys never reach the instance. They are added to the GET answer inside the test's own browser, and the test saves nothing.
- Measurements and tests run on `ocupilot-ci` only. `ocupilot-slot-a` is read-only.

**Never:**

- No change to `SETTLE_TIMEOUT_MS`, `QUIET_MS`, `WALKCALLDEADLINE`, `protocolTimeout`, the walk's retry or any other deadline, and no retry added.
- No edit to an existing line of `Kernel/Governance/Baseline.cls`: Epic 24 has commits on it (c94cacdb1), so edits there are add-only.
- No change to the governance page's markup, strings, grouping or row set, and no new user-facing string.
- No fake key, test tool or Baseline line in a shipped class.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Read, default policy | 371 write keys, no stored policy | Same rows as today, each `source` `baseline`, from one baseline parse | none |
| Key the parsed list lists, the XData does not | `Rows` given a list holding `probe.render.x2: true` | `baseline` `enabled`, `enabled` true, `source` `baseline` | none |
| Key the list does not list | `Rows` given a list without the key | `baseline` `absent`, `enabled` false | none |
| Baseline unreadable | `Keys` returns an error | Every row `absent` and disabled, as `Seed` answers today | the read still answers 200 |
| Gate call | `Resolve(key, "write")` | Unchanged: reads the store and `Seed` per call | unchanged |

</intent-contract>

## Code Map

- `src/OcuPilot/Kernel/Governance/Policy.cls:141-176` `Effective` -- the per-key loop. `:159` calls `Baseline.Seed` and `:162` calls `Cascade`, which calls `Seed` again at `:131`, so the XData is parsed 2N times. The only caller is `Api/Governance.cls:126` (GET and the answer after PUT).
- `src/OcuPilot/Kernel/Governance/Policy.cls:109-134` `Cascade(ByRef pValues, pKey, pKind, Output pEnabled, Output pSource)` -- the doc says "Pure: reads nothing but the baseline". `Resolve` (`:84-97`) is the Gate's caller.
- `src/OcuPilot/Kernel/Governance/Baseline.cls:397-405` `Seed` (calls `Keys` each time) and `:410` `Keys(Output pList)` (opens and parses the XData, 0.6 ms at 371 lines and 1.6 ms at 742). Contended: add-only.
- `src/OcuPilot/Api/Governance.cls:81` -- the PUT's `WriteKeys`. It does no per-key Seed and is unchanged.
- `src/OcuPilot/Test/GovernanceBaseline.cls` (75 lines) -- the baseline pins. The new pin goes here; `Test/Governance.cls` is already 643 lines.
- `ui/browser/governance.browser-spec.mjs` (115 lines, one test, AC1) -- extended. Its header says "One claim".
- `ui/browser/panel-spec.mjs:155` `signedInAt(browser, config, url, viewport, mediaFeatures)` -- the walk's sign-in. `ui/browser/structural-walk.mjs:68` `VIEWPORTS.wide`, `:939` `trackRequests`, `:985` `settle` (the a11y spec's settle: no `/api/ocupilot` or shell script in flight for 500 ms, no `aria-busy`, fonts loaded), `:1024` `goInApp`.
- `ui/src/app/areas/agent/governance.page.ts:284` `rowViews` -- the render path. Mutation target only; unchanged.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Kernel/Governance/Baseline.cls` -- add (add-only) `ClassMethod SeedFrom(pList As %DynamicObject, pKey As %String, Output pListed As %Boolean) As %Boolean`. It returns the value `pList` lists for `pKey` with `pListed` 1, or 0 with `pListed` 0 when the key is not listed or `pList` is not an object. It is `Seed`'s lookup over a list already parsed. `Seed` is unchanged.
- `src/OcuPilot/Kernel/Governance/Policy.cls`:
  - `Cascade` gains a trailing `pBaseline As %DynamicObject = ""`. When it is an object, the baseline layer reads `SeedFrom(pBaseline, …)`; otherwise it reads `Seed`, as today. Update its doc comment.
  - Add `ClassMethod Rows(ByRef pKeys, ByRef pValues, pBaseline As %DynamicObject, Output pRows As %DynamicArray)`. It holds the row-building loop moved out of `Effective`, reads the baseline only through `pBaseline`, and passes it to `Cascade`.
  - `Effective` = `WriteKeys`, `GuardedAll`, one `Baseline.Keys` (on error, an empty `{}`, so every row reads `absent` and disabled as today), then `Rows`.
  - DW-1822.
- `src/OcuPilot/Test/GovernanceBaseline.cls` -- add `TestOneReadResolvesEveryRowFromOneParse`. It takes `WriteKeys`, adds a `.x2` copy of each key, and builds a list from `Baseline.Keys` plus each `.x2` key at its original's value. With empty stored values, `Rows` then answers 2N rows, and every `.x2` row's `baseline` and `enabled` equal its original's. A key in neither the XData nor the list reads `absent`. `Cascade` given the list resolves a list-only key from it.
- `ui/browser/governance.browser-spec.mjs` -- add test `AC2 (Story 21.40): …`, then update the header to state the two claims and what the new one needs:
  - Sign in with `panel-spec.mjs`'s `signedInAt` at `/ocupilot/?ns=HSCUSTOM`, `VIEWPORTS.wide`, light and reduced motion, then `trackRequests` and `settle`.
  - On a page CDP session, `Fetch.enable` for the governance path at `requestStage: 'Response'`. A GET answer's `keys` get a `.x2` copy of every row, in name order; the test fulfils with the new body and drops `content-length`. Anything else continues.
  - Then `Emulation.setCPUThrottlingRate` 4, and a `longtask` `PerformanceObserver` from a start mark.
  - `goInApp` to `/ocupilot/agent/governance?ns=HSCUSTOM`.
  - Assert `settled` true and `ms` ≤ 5000. The `.ocu-governance-key` count equals twice the keys of an unmodified GET from Node, read in the same test. The longest long task after the mark is ≤ 1000 ms.
  - Throttle back to 1 and close the context in `finally`.
  - DW-1822.

**Acceptance Criteria:**

- Given `ocupilot-ci` on this story's tree, when `GET /api/ocupilot/agent/governance` answers, then its body equals the pre-change answer for the same state, and `Effective` parses the Baseline once: `TestOneReadResolvesEveryRowFromOneParse` passes, and `Governance` and `GovernanceWire` stay green.
- Given the Governance page at 1280 px light, CPU throttled 4x, with the read's keys doubled in the browser, when it is opened from the shell with the walk's `goInApp`, then it settles within 5,000 ms, it draws twice the instance's key count, and no long task exceeds 1,000 ms (DW-1822).
- Given scratch tree C (Baseline and write keys doubled, outside the worktree, never committed) loaded on `ocupilot-ci` with this fix, when the read is timed by `curl` three times, then its median is within 0.3 s of tree B's. The pre-fix gap was 1.9 s (3.5 s against 1.6 s). Recorded under Verification. `ocupilot-ci` is then restored to this story's tree.

## Spec Change Log

- 2026-11-24, orchestrator ruling at the plan gate, authoritative over the bounds written elsewhere in this spec:
  - **Proceed** with the single Baseline parse and the 4x browser test.
  - **The bounds are measured after the fix, not fixed in advance.** Measure tree C at 4x again on `ocupilot-ci` with at least 5 cold runs. The settle bound is at least 1.5 times the worst of those runs, rounded up to a whole second. The longest-task bound is derived the same way, and 1,000 ms is used only if 1.5 times the measured worst is at or below it. Record both measurements and the derivation in Design Notes; the 5,000 ms and 1,000 ms figures above are superseded.
  - **The registry cache stays deferred.** Caching across requests needs invalidation on compile and upgrade, so it is a story of its own (`deferred:`, ledgered low to burn-down). **The panel's forced layout is not changed.** No markup change and no new strings.
  - **DW-1822 is re-owned at this story's end, not resolved.** The runner routes it to burn-down with the measurements.

## Review Triage Log

## Design Notes

**Governing ADs:**

- AD-22: the baseline layer and the cascade are unchanged, and the Gate still reads per call.
- AD-19: client unchanged.
- AD-36: the read's shape is unchanged.
- AD-12 and AD-39: the envelope is unchanged.
- Operational Envelope: the NFR-1 performance budget.

No AD changes.

**Measured** on `ocupilot-ci` 2026-11-23, headless pinned Chrome (puppeteer 24.24.0), macOS arm64.

Method: a cold browser per run; the walk's `signedInAt` at 1280x900, light, reduced motion; a `settle` on home; then `Emulation.setCPUThrottlingRate`, the walk's push-state navigation and its `settle`. Three runs per cell, median (min-max). "Gov" is the governance answer's time. "Detect" is `detectScreen` with all four invariants, timed after the settle.

Trees:

- A is 626172470 with Story 21.31's 8 added classes deleted from the throwaway.
- B is 90e0b706d, which is the worktree's code.
- C is B with the Baseline doubled to 742 lines and `WriteKeys` answering a `.x2` copy of each key. C was a scratch build, never committed.

| Tree | CPU | Keys | Settle ms | Gov ms | Long tasks n / longest / total ms | Script/style/layout ms | DOM nodes (elements) | JS heap MB | Detect ms |
|---|---|---|---|---|---|---|---|---|---|
| A | 1x | 368 | 2118 (2118-2121) | 1585 (1583-1615) | 0 / 0 / 0 | 12/8/12 | 15887 (3609) | 10.7 | 169 (156-234) |
| A | 4x | 368 | 2118 (2118-2220) | 1597 (1589-1660) | 1 / 127 (125-139) / 127 | 52/32/48 | 15887 (3609) | 10.7 | 631 (611-659) |
| B | 1x | 371 | 2420 (2120-2928) | 1862 (1567-2367) | 0 / 0 / 0 | 14/8/13 | 16001 (3636) | 10.7 | 159 (154-184) |
| B | 4x | 371 | 2623 (2115-3135) | 2080 (1598-2613) | 1 / 172 (129-177) / 172 | 64/45/68 | 16001 (3636) | 10.7 | 668 (634-956) |
| C | 1x | 742 | 4039 (4034-4339) | 3524 (3475-3744) | 1 / 52 (52-54) / 52 | 18/14/21 | 28101 (6975) | 9.8 | 299 (295-333) |
| C | 4x | 742 | 4127 (4036-4134) | 3540 (3515-3546) | 1 / 222 (222-224) / 222 | 75/55/87 | 28101 (6975) | 9.8 | 1161 (1150-1164) |

**Dominant cost:**

- The settle is the governance read plus `QUIET_MS`. The read costs about 1.2 s for `Registry.ListTools`, which is rebuilt on every request (out of footprint; see `deferred:`), plus `Effective`'s own loop.
- The loop parses the Baseline twice per key. That is 0.43 s at 371 keys and about 2.3 s at 742, so it grows per key times per baseline line.
- In the renderer, the profiles' largest JS self time is `panel-follow.ts:37`'s `newestTop`, reached from `panel.ts:846`'s `afterEveryRender`. It reads `scrollHeight` and so forces the table's layout: 80, 116 and 146 ms at 4x for A, B and C.
- That layout is the one long task: it grows per key, linearly, and is not extra work, since the frame would lay out the table anyway. Angular's row creation is the rest of the script time.
- The page's row work is per key, not per group, because there are no groups.

**Throttle and runner.** The rate is 4 and applies to the renderer only, so the IRIS read is unthrottled here.

- The orchestrator's CI reading is about 1.4x slower: client suite 11.8 against 8.5 min in run 45048213834 (inference).
- 4x covers that with margin (inference). The CI stall line answered governance in 1,626 ms, the same as here.

**For the orchestrator (evidence, not a halt):** some costs do grow with the key list, so the plan designs the fix the ruling asks for. The magnitudes do not explain the stall, though.

- At the stall, governance had answered, and the renderer then answered no DevTools call for 60 s.
- The page's whole render here is one long task of 0.13-0.22 s at 4x, more than 250 times below that deadline. This fix bounds what grows; it is not expected to end DW-1822's stall (inference).
- So adjudication should re-own DW-1822's residual (the renderer deaf to CDP) rather than resolve it.
- Also: DW-1822's four latest trailer lines read only `routed`, with no owner, so `slice 21-40-…` is empty.

**Decided in-stage:**

- The fix cuts the read's per-row parse ("less work per row") and leaves the page's markup alone. Collapsed groups would need new grouping and strings for at most 0.2 s at 4x. Virtualisation would take rows out of the DOM that the a11y walk inspects.
- The doubled count is made in the browser: Fetch fulfils the real GET answer with `.x2` copies. That gives the page's render at twice the keys with no fake key on the instance. The server half is pinned by `TestOneReadResolvesEveryRowFromOneParse`.
- The bounds are 5,000 ms settle and 1,000 ms longest task. Measured at 4x and double the keys: 4.1 s settle before the fix, with the server doubled too, and a 222 ms task.

**Rule 2:**

- `SeedFrom` copies `Seed`'s three-line lookup, because `Baseline.cls` is add-only here. A later story may make `Seed` delegate.
- `Rows` is moved out of `Effective`, not copied.
- The new browser test reuses the walk's `signedInAt`, `trackRequests`, `settle` and `goInApp`.

**Ledger inbox:** DW-1822 is addressed by the Tasks marked DW-1822, with the residual above.

**Integration ACs:** none. `Rows` and `SeedFrom` have one consumer, `Effective`, which the GET exercises.

## Verification

**Commands:**

- `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/e21-kit/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` -- `(loop)` expected: `LOADERRORS=0`.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.GovernanceBaseline` -- `(loop)` expected: green, with the new test.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.Governance` -- `(loop)` expected: green.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.GovernanceWire` -- `(loop)` expected: green.
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, then `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/governance.browser-spec.mjs` -- `(loop)` expected: 2/2. Record the settle ms, the longest task and the row count.
- `uv run scripts/check-objectscript.py` -- `(once)` expected: clean.
- Full ObjectScript sweep on `ocupilot-ci`, one class per call or batches of about 8 minutes from `ui/tools/ci-timings.json` -- `(once)` expected: green. The browser suite is left to CI (Rule 29), except `a11y-structural-invariants.browser-spec.mjs` once -- `(once)` expected: 13/13; record the governance visits' ms.
- Before-and-after read timing -- `(once)`: `curl -s -o /dev/null -w '%{time_total}' -u _SYSTEM:SYS http://localhost:52776/api/ocupilot/agent/governance`, three times each:
  - on this tree;
  - on a scratch tree C, made by the implement stage's own script under its own scratch directory. It is a `git archive HEAD` of this tree, extracted outside the worktree. The `Keys` XData gets a `"<key>.x2"` line at each existing line's value, and `WriteKeys` adds a `.x2` copy of each key after its loop. It is loaded with `reload.sh <tree-C>`;
  - then reload the worktree.

  Expected: C's median is within 0.3 s of this tree's.
- mutation (server): `Rows` reads `Baseline.Seed(tKey, .tListed)` instead of `SeedFrom` -> only `TestOneReadResolvesEveryRowFromOneParse` red (the `.x2` rows read `absent`). `Cascade` ignoring `pBaseline` -> the same test red on `enabled`. Each reverted and reloaded, with `git diff` clean.
- mutation (browser): a 1,500 ms synchronous busy loop at the top of `GovernancePage.rowViews` -> after a rebuild and redeploy, only AC2 red on the long-task bound. The `.x2` doubling removed from the Fetch handler -> AC2 red on the row count. Each reverted, rebuilt and redeployed.

Shared surfaces: none (no roster, menu, schema or count changes; `governance.browser-spec.mjs` gains one test and its time in `ci-timings.json` follows at the next refresh). Every test added or changed passes on a fresh environment, in either order.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
