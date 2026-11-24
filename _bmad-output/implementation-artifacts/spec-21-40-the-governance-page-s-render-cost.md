---
title: "Story 21.40: The governance page's render cost"
type: 'bugfix'
created: '2026-11-23'
status: 'done'
baseline_revision: '28aa3919626d4f80acb67fe982276cc1f40f1706'
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
  - Assert `settled` true and `ms` ≤ 3000. The `.ocu-governance-key` count equals twice the keys of an unmodified GET from Node, read in the same test. The longest long task after the mark is ≤ 1000 ms.
  - Throttle back to 1 and close the context in `finally`.
  - DW-1822.

**Acceptance Criteria:**

- Given `ocupilot-ci` on this story's tree, when `GET /api/ocupilot/agent/governance` answers, then its body equals the pre-change answer for the same state, and `Effective` parses the Baseline once: `TestOneReadResolvesEveryRowFromOneParse` passes, and `Governance` and `GovernanceWire` stay green.
- Given the Governance page at 1280 px light, CPU throttled 4x, with the read's keys doubled in the browser, when it is opened from the shell with the walk's `goInApp`, then it settles within 3,000 ms, it draws twice the instance's key count, and no long task exceeds 1,000 ms (DW-1822).
- Given scratch tree C (Baseline and write keys doubled, outside the worktree, never committed) loaded on `ocupilot-ci` with this fix, when the read is timed by `curl` three times, then its median is within 0.3 s of tree B's. The pre-fix gap was 1.9 s (3.5 s against 1.6 s). Recorded under Verification. `ocupilot-ci` is then restored to this story's tree.

### Review Findings

Code review 2026-11-24 of 27de51476 (full-opus; blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor): 0 high, 1 med, 11 low entries from 25 rows.

- [x] [Review][Patch] (med) Byte-identity was pinned only row against row through `SeedFrom`, never against `Seed`, nor under stored overrides: a uniformly wrong lookup passed. Added `GovernanceBaseline.TestRowsEqualThePerKeyPath` (rows byte-identical to the per-key path under five override sets, `Effective` equal over the store as read, `SeedFrom` = `Seed` over every key). [fix-risk low: test-only]
- [x] [Review][Patch] (low) `Rows` given a non-object list read `absent` but resolved `enabled` through `Seed`, contradicting its doc. `Rows` now treats it as `{}`; pinned in the same test. [fix-risk low: one guard line]
- [x] [Review][Patch] (low) AC2 asserted the row count before `settled`, hiding `visit.why`; reordered. [fix-risk low]
- [x] [Review][Patch] (low) AC2's Node GET had no status check; added. [fix-risk low]
- [x] [Review][Patch] (low) The spec header did not say what AC2 needs; added. [fix-risk low]
- [x] [Review][Patch] (low) The test class header and `TestOneReadResolvesEveryRowFromOneParse`'s doc omitted what they pin (the empty-list rows, `Rows` not `Effective`); corrected. [fix-risk low]
- [x] [Review][Patch] (low) AC2's settle bound had no observed red; mutation run and recorded under Verification. [fix-risk low]
- [x] [Review][Defer] (low) No automated check counts baseline parses per read -- DW-2868 `wontfix-accepted`. [fix-risk med: needs a seam on add-only Baseline.cls]
- [x] [Review][Defer] (low) The settle bound comes from local runs; CI headroom is thinner than 1.5x (inference) -- DW-2869 `by-design` (the ruling's derivation). [fix-risk low]
- [x] [Review][Defer] (low) A non-`%DynamicObject` list would error in `SeedFrom` -- DW-2870 `wontfix-theoretical`. [fix-risk low]
- [x] [Review][Defer] (low) `SeedFrom` repeats `Seed`'s lookup (Rule 2, forced by add-only) -- DW-2867 `wontfix-accepted`, now pinned equal. [fix-risk low]
- [x] [Review][Dismiss] (low) Auto Run Result prose: a stale trailing `Status: ready-for-dev` block, a 4-vs-5 rejected tally, "below" for the bounds table, unnamed `Baseline.*` callers. Outside the review's sanctioned spec edits; left for the runner.

Rejected:

- `false`: the plan-gate ruling's 2026-11-24 date is wrong -- the ruling's commit bc0d278ee is dated 2026-11-24 03:59 UTC.
- `false`: the tracker still reads `ready-for-dev` -- the review's sprint-status sync sets it.
- `low`: `Rows` returns no `%Status` -- the spec fixes its signature; errors reach `Effective`'s `Catch`.
- `false`: the handler drops `content-encoding` beyond the spec -- required, since `Fetch.getResponseBody` returns the decoded body.

## Spec Change Log

- 2026-11-24, orchestrator ruling at the plan gate, authoritative over the bounds written elsewhere in this spec:
  - **Proceed** with the single Baseline parse and the 4x browser test.
  - **The bounds are measured after the fix, not fixed in advance.** Measure tree C at 4x again on `ocupilot-ci` with at least 5 cold runs. The settle bound is at least 1.5 times the worst of those runs, rounded up to a whole second. The longest-task bound is derived the same way, and 1,000 ms is used only if 1.5 times the measured worst is at or below it. Record both measurements and the derivation in Design Notes; the 5,000 ms and 1,000 ms figures above are superseded.
  - **The registry cache stays deferred.** Caching across requests needs invalidation on compile and upgrade, so it is a story of its own (`deferred:`, ledgered low to burn-down). **The panel's forced layout is not changed.** No markup change and no new strings.
  - **DW-1822 is re-owned at this story's end, not resolved.** The runner routes it to burn-down with the measurements.

## Review Triage Log

### 2026-11-23 — Review pass

- verdicts: 6 findings — high 0, medium 0, low 4, false 2, maybe-false 0
- findings:
  - `[low]` `[reject]` Neither the settle bound nor AC3's read time has a mutation that reddens it by wall-clock — the settle bound sits above the pre-fix settle at the instance's real key count, so the server half is pinned structurally by `TestOneReadResolvesEveryRowFromOneParse`; a time gate on the server read would be flaky, so a fix would add a new flaky check for little gain.
  - `[low]` `[reject]` The settle bound's margin over the measured worst is 1.65x and includes the unthrottled server read — the bound is the ruling's derivation (1.5x the worst of twelve runs, rounded up); widening it is the owner's call.
  - `[false]` `[reject]` The `longtask` observer cannot fail on a browser without support — the pinned Chrome supports it, and the busy-loop mutation was observed red.
  - `[low]` `[patch]` No test covers the matrix row "Baseline unreadable" (every row absent and disabled) — added an assertion that `Rows` over an empty list answers every row absent and disabled, with a `mutation:` line, run red then green (run 1011 red, 1012 green); the `Keys`-error fallback in `Effective` itself is a two-line guard no test provokes.
  - `[false]` `[reject]` Intent audit: the browser test doubles the answer after the instance has answered, so it does not measure the server parse — as designed by the intent ("extra keys are added only inside the test's browser"); the server parse is pinned by the new ObjectScript test.
  - `[low]` `[reject]` Intent audit: the ObjectScript test exercises `Rows`, not `Effective`, so an `Effective` that parsed per key before `Rows` is not caught — `Effective` calls `Keys` once and `Rows` is the only loop, so the per-key parse has no place to return without reddening the test; the byte-identical answer was compared whole before and after (371 keys, 42,646 bytes).

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

**Post-fix bounds** (the ruling in the Spec Change Log). Same method and instance as above, with the fix loaded and the rebuilt bundle deployed; every run a cold browser at 4x, 742 keys drawn.

| Configuration | Runs | Settle ms | Longest task ms |
|---|---|---|---|
| The test's own: this tree, the answer doubled in the browser | 6 | 1817, 1818, 1716, 1714, 1719, 1814 | 232, 248, 241, 227, 235, 245 |
| Tree C with the fix: Baseline and write keys doubled on the instance | 6 | 1610, 1712, 1709, 1716, 1716, 1716 | 239, 227, 240, 221, 229, 240 |

- Worst settle is 1,818 ms; 1.5 times it is 2,727 ms, so the bound is 3,000 ms.
- Worst longest task is 248 ms; 1.5 times it is 372 ms, at or below 1,000 ms, so the bound stays 1,000 ms.
- The read by `curl`, median of three: 1.18 s on this tree and 1.18 s on tree C (1.205, 1.176, 1.182), against 1.6 s and 3.5 s before the fix. The answer on this tree is byte-identical to the pre-change answer.

**For the orchestrator (evidence, not a halt):** some costs do grow with the key list, so the plan designs the fix the ruling asks for. The magnitudes do not explain the stall, though.

- At the stall, governance had answered, and the renderer then answered no DevTools call for 60 s.
- The page's whole render here is one long task of 0.13-0.22 s at 4x, more than 250 times below that deadline. This fix bounds what grows; it is not expected to end DW-1822's stall (inference).
- So adjudication should re-own DW-1822's residual (the renderer deaf to CDP) rather than resolve it.
- Also: DW-1822's four latest trailer lines read only `routed`, with no owner, so `slice 21-40-…` is empty.

**Decided in-stage:**

- The fix cuts the read's per-row parse ("less work per row") and leaves the page's markup alone. Collapsed groups would need new grouping and strings for at most 0.2 s at 4x. Virtualisation would take rows out of the DOM that the a11y walk inspects.
- The doubled count is made in the browser: Fetch fulfils the real GET answer with `.x2` copies. That gives the page's render at twice the keys with no fake key on the instance. The server half is pinned by `TestOneReadResolvesEveryRowFromOneParse`.
- The bounds are 3,000 ms settle and 1,000 ms longest task, derived from the post-fix measurements below. Before the fix, at 4x and double the keys with the server doubled too, the settle was 4.1 s and the longest task 222 ms.

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

  Result on `ocupilot-ci`: this tree 1.182, 1.192, 1.180 s (median 1.182 s); tree C 1.205, 1.176, 1.182 s (median 1.182 s), a gap of 0 s against 1.9 s before the fix. The answer on this tree is byte-identical to the pre-change answer (371 keys, 42,646 bytes). The worktree was reloaded afterwards.
- mutation (server): `Rows` reads `Baseline.Seed(tKey, .tListed)` instead of `SeedFrom` -> only `TestOneReadResolvesEveryRowFromOneParse` red (the `.x2` rows differ from their originals). `Cascade` ignoring `pBaseline` -> the same test red, on the `.x2` rows and on the list-only key. Each applied, observed red, reverted and reloaded into `ocupilot-ci`, and the test green again.
- mutation (server, empty list): `SeedFrom`'s `%GetTypeOf(pKey) '= "boolean"` guard removed -> `TestOneReadResolvesEveryRowFromOneParse` red (an empty list's rows read disabled instead of absent). Reverted and reloaded into `ocupilot-ci`, `git diff` showing only the added method, and the test green again (run 1012).
- mutation (browser): a 1,500 ms synchronous busy loop at the top of `GovernancePage.rowViews` -> after a rebuild and redeploy, only AC2 red, "the longest task ran 1742 ms, over 1000 ms" (AC1 stayed green). The `.x2` doubling removed from the Fetch handler -> AC2 red on the row count (371 against 742). Each reverted, rebuilt and redeployed, `git status` showing no change to `governance.page.ts`.
- mutation (review, server): `SeedFrom` answering `1` for every listed key -> only `TestRowsEqualThePerKeyPath` red (run 1017); `TestOneReadResolvesEveryRowFromOneParse` stayed green. `Rows` without its non-object guard -> the same test red on "Rows given no list" (run 1018). Each reverted, `git diff` clean on the mutated lines, reloaded, green (run 1021).
- mutation (review, browser): a 1,300 ms wait before the Fetch handler fulfils the governance answer -> AC2 red, "the page settled in 3150 ms, over 3000 ms". Reverted, `git status` showing only the review's patches.
- review evidence on `ocupilot-ci`: a stored policy (read-only preset, then no preset, with 186 keys enabled or disabled) -> `TestRowsEqualThePerKeyPath`'s `Effective` comparison green over each (runs 1019, 1020); the policy cleared and the answer byte-identical to the one read before (372 keys). A baseline line flipped and reloaded -> the next GET answers it (no parse outlives a read); reverted and byte-identical again.

Shared surfaces: none (no roster, menu, schema or count changes; `governance.browser-spec.mjs` gains one test and its time in `ci-timings.json` follows at the next refresh). Every test added or changed passes on a fresh environment, in either order.

## Auto Run Result

Status: done
Blocking condition: none

Summary: a governance read parses the Baseline once (`Effective` calls `Baseline.Keys` once and hands the list to the new `Policy.Rows`; `Cascade` takes an optional parsed list; `Baseline.SeedFrom` is the lookup over it). The Gate path is unchanged and the read's answer is byte-identical (371 keys, 42,646 bytes). `governance.browser-spec.mjs` gains AC2: 4x CPU throttle, keys doubled in the test's own browser, settle bound 3,000 ms, longest-task bound 1,000 ms, both derived from twelve cold runs (worst settle 1,818 ms, worst task 248 ms).

Files changed:

- `src/OcuPilot/Kernel/Governance/Baseline.cls`: add-only `SeedFrom`.
- `src/OcuPilot/Kernel/Governance/Policy.cls`: `Cascade`'s optional list, new `Rows`, `Effective` parses once.
- `src/OcuPilot/Test/GovernanceBaseline.cls`: `TestOneReadResolvesEveryRowFromOneParse`.
- `ui/browser/governance.browser-spec.mjs`: AC2 and its header.

Review: 6 findings, 1 patched (an empty-list assertion with its mutation line), 5 low and false findings rejected with reasons in the Review Triage Log, nothing deferred by review. Follow-up review recommended: false (0 high, 0 medium patched).

Verification: reload `LOADERRORS=0`; ObjectScript classes green one per call (`GovernanceBaseline` 4, `Governance` 14, `GovernanceWire` 6, `ToolDispatch` 19, `SurfaceCoverage` 4, and the classes that call `Baseline.*`); `check-objectscript.py` 0 problems; `lint-docs.sh` 0 issues; `test:tools` 2415 passed; `test:components` 3940 passed; browser `governance` forward and reversed 2 of 2; `a11y-structural-invariants` 13 of 13; curl medians 1.182 s on this tree and on tree C; five mutations run red and reverted.

Residual risks: the settle includes the unthrottled `Registry.ListTools` rebuild of about 1.2 s per read (deferred); DW-1822 is not resolved and is re-owned by the runner with the measurements.
