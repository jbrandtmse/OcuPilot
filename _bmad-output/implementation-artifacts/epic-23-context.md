# Epic 23 Context: The range-end cleanup

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Epic 23 holds the cleanup stories chartered between releases. Each takes an owner-approved slice of the deferred-work ledger and gives every entry a recorded disposition, so the ledger stays honest and the code it names stays right. Stories 23.1 to 23.6 are done. Story 23.11, dispatched now on slot A ahead of 23.7, takes ten entries. The first is the agent's inability to read a large class's view. The rest are two screens that raise a second, wrong alert when the instance is unreachable, fixed heights that clip under a text-only resize, and test-harness defects: literal counts, an assertion that depends on how many rows the instance holds, a browser config that falls back to slot A, 720 px passes that measure before the layout settles, and three flakes. The aim is that the agent can read any class it can list, and that the suites stay green as the product grows or runs on another slot.

## Stories

- Story 23.1: The range-end cleanup (done)
- Story 23.2: The range-end cleanup, part 2 (done)
- Story 23.3: The range-end cleanup, part 3 (done)
- Story 23.4: The range-end cleanup, part 4 (done)
- Story 23.5: The range-end cleanup, part 5 (done)
- Story 23.6: The Haiku-story cleanup (done)
- Story 23.7: The range-end cleanup, part 6 (backlog)
- Story 23.8: The range-end cleanup, part 7 (backlog)
- Story 23.9: The range-end cleanup, part 8 (backlog)
- Story 23.10: The range-end cleanup, part 9: two sweeps (backlog)
- Story 23.11: The range-end cleanup, part 10 (dispatched)

## Requirements & Constraints

**Every cleanup story.**

- Every owned entry ends with a disposition the ledger tool writes (`bash _bmad/scripts/ledger.sh <ledger> slice|show|append`): `resolved-by` the story with the commit, or `wontfix-accepted` or `by-design` with a reason and any condition that would reopen it. Never read or edit the ledger whole.
- Each entry is a finding, not a fact. Verify it at head and record it as confirmed, refuted or already fixed.
- A story takes at most 12 entries, in this priority order: CI flakes, security, repeat occurrences, then the lowest fix-risk (Rule 27).
- Every fix needs a test that reddens on the defect before the fix, recorded on a Rule 19 `mutation:` line. If no test can, the entry says why.
- Fixes land in batches by area, each green in CI on its own head, so a failing batch is reopened alone.
- A fix that contradicts a planning document corrects that document at its origin. A CLAUDE.md line changes only through the Planner, with the owner's OK.

**Story 23.11** (`23-11-the-range-end-cleanup-part-10`): 10 entries. DW-2246 goes in the first batch.

- **DW-2246.** `explorer.class.read` answers `TOOL.RESULTTOOLARGE` for a large class (`OcuPilot.Port.AdminPort.cls`, about 248 KB).
  - Measure the cause before fixing it. A test over a class larger than the result cap reddens before the fix and passes after it.
  - 23.5's plan traced it to the kernel's total bound (inference): the bound measures its base with `rowsSent` 0 but writes the kept count, so a kept set within two characters of the cap is refused.
- **DW-2449.** On the Guardrails page and a web application's class-access tab, every failed read draws the generic server-fault sentence as `role="alert"`, status 0 included. An unreachable instance therefore shows a second alert, with the wrong sentence, beside the shell's banner. The root cause is DW-1401's, so the fix takes DW-1401's shape.
- **DW-2439.** About twenty text-bearing controls and rows set a fixed `height` where the height should be a minimum, so a text-only resize clips them. DW-1392 fixed only the System Information row.
- **DW-2182.** `WireSecurityRead`'s task-history pair-set test asserts that nothing is cut at 1,000 rows, so it reddens on an instance holding more history. Assert the pair-set refusal and a row instead.
- **DW-2202.** Some tests outside their roster's own test assert literal shared-surface counts.
  - 23.5's plan found an area count of 11 written out in 7 files, and the entity-type count in the descriptor tests. Its estimate was 15 to 18 sites in all.
  - Derive each count from the registry, a descriptor or the mirror.
  - The roster pins stay literal: `SurfaceCoverage`, `EndpointCoverage` and the floor-only roster.
- **DW-2221.** `browserConfig` falls back to slot A's throwaway when `OCUPILOT_BROWSER_ORIGIN` and `OCUPILOT_BROWSER_CONTAINER` are both unset.
  - Make it refuse unless both are set. CI sets both per shard, so CI is unaffected.
  - Update `browser-config.test.mjs` and the browser-run lines in README and DEVELOPMENT.
  - Report the CLAUDE.md wording the change needs; do not edit CLAUDE.md.
- **DW-2455.** About 44 of the 81 specs that use the narrow viewport measure right after a bare `setViewport` (a grep count, inference).
  - Settle the layout before each narrow pass.
  - Settling can expose an overflow it was hiding, as it exposed DW-2454. Any overflow it exposes gets fixed too.
- **DW-2458.** `log-viewer.spec.ts` AC6 counts pending fake timers, and it has gone red on node 24 and node 26. This is DW-2415 coming back after Story 20.8's fix.
  - Drain or clear the timers before the count, on all three Node bands.
  - Prove the fix with an interval mutation and a self-re-arming-poll mutation.
- **DW-2460.** `SqlBackgroundJob`'s early-cancel test failed once in a full sweep and passed when re-run.
- **DW-2462.** `LogTail`'s absent-file test found the file present in a full sweep, and passes alone. The ledger suspects an earlier class leaves the file behind (inference).

## Technical Decisions

- **Read bounds (AD-24, AD-36).**
  - One declared read serves a screen and its tool. The tool's view is rows only; a document's whole text goes to the screen alone.
  - The kernel bounds every tool result:
    - a row cap, 200 by default;
    - 65,536 characters in total, cut by whole rows from the end;
    - 1,000 characters a field, a cut value ending in U+2026.
  - The result reports `rowsSent`, `rowsAvailable`, `truncated` and `truncatedFields`.
  - The only named field exception is the source reads' 60,000-character whole-line text. The total bound still applies to it, and the tool results of one turn share 262,144 characters.
  - A fix inside the bound keeps this contract. Paging or cutting the class view changes the contract, so the spine is amended first (Rule 20).
- **Errors (AD-12, AD-39).**
  - The envelope is flat: `{error, reason, code, detail}`.
  - The client classifies a failure's kind with `classifyFault` and `isBannerFault` in `core/fault.ts`. When the kind is one the shell's banner shows, a non-modal surface adds no alert of its own. Other kinds use `FaultBanner`'s in-place mode.
  - Extend `FaultBanner` rather than copying it (Rule 31). The About dialog is the exception and shows its own alert, because it is modal.
- **Test hermeticity (Conventions › Tests, Rule 30).**
  - A test class or spec depends on nothing another left behind, on run order, or on instance age.
  - A red that depends on how the shards are composed is fixed in the test, never by pinning a test to a shard.
  - A test asserts on its own rows by marker. A count asserted outside its roster's own test is derived.
- **Browser harness.** `ui/browser/panel-spec.mjs` shares two waits:
  - `settleViewport` sets the viewport, waits for `clientWidth`, then waits two frames. It does not wait for the panel's 120 ms width transition.
  - `transitionsSettled` waits for that transition.
  - Reuse these two rather than adding another wait.
- **Client.**
  - The client is zoneless, signal-based and `OnPush`.
  - Strings live only in `core/strings.ts`, each with its EXPERIENCE.md row cite and its entry in the Fixed strings table.
  - Colors come from design tokens only.
  - The theme is `ocu-theme-dark` on `<html>`, and components never select on it.
- **Verification (slot A).**
  - Every MCP call passes `server: "ocupilot-slot-a"`.
  - The throwaway is `ocupilot-ci` (52776/1975). This runner brings it up and tears it down at its close.
  - Every browser command sets both browser variables inline.
  - Run one ObjectScript test class per call, and take totals from `%UnitTest_Result`.
  - Rebuild and redeploy the bundle before reading any browser result. Check geometry in both themes.
  - Rule 29: the implement stage runs only the targeted classes and specs. The full ObjectScript sweep runs once, before `dev_complete`.
  - Rule 30: because the story touches many screens, the fresh check runs the full browser suite before the push.
- **Prose and Git.**
  - Comments state the contract and never narrate stories, runs or mutations. Non-ASCII characters are written as `\uXXXX` escapes.
  - Stage by path.
  - Push the code head alone, without `[skip ci]`, and confirm its run by `headSha`.
  - Never touch `main` or a release branch.

## UX & Interaction Patterns

- **Reflow.** Every height is a `min-height`, except the rows of the virtualized `data-table` and `log-viewer`. A text-only zoom grows a row and never clips it.
  - DW-1392's test shape: double the caption and body type-size and line-height tokens on `documentElement`, wait two frames, then assert `scrollHeight <= clientHeight + 1`, in light and in dark.
- **Unreachable instance.** Exactly one banner, `role="alert"`, at the top of the content: "The instance is unreachable. Check that IRIS is running, then retry.", with Retry.
- **Generic error (5xx).** "Something failed on the instance. Retry; if it keeps failing, check messages.log.", as `role="alert"`, with Retry and Open messages.log.
- **A 403.** An inline alert names the missing resource, and the screen's data stays.
- **Narrow width.** At 720 px (a 1,440 px laptop at 200% zoom), the panel settles at its 320 px minimum, and the page never scrolls sideways.

## Cross-Story Dependencies

- **Order.** 23.11 runs alone on slot A, ahead of 23.7. Stories 23.7, 23.8, 23.9 and 23.10 follow it; this dispatch does not touch them. Implement runs on Sonnet.
- **Epic 20 alongside.** Epic 20 runs at the same time on slot B, from Story 20.9 on (interoperability messages and the analytics rider).
  - Most of DW-2202's sites are in Epic 20's tests. `strings.ts`, `screen-actions.ts` and the interop areas are the likely contended files.
  - Check Epic 20's diff before editing any of them (Rule 11). An add-only edit is fine; anything else asks the orchestrator.
  - Forward-merge before implement and at each boundary. Regenerate `screens.generated.ts` after a merge; never hand-merge it.
- **What 23.11 builds on.**
  - DW-2449 and DW-2439 follow Story 23.5's DW-1401 and DW-1392 fixes.
  - DW-2455 uses 23.5's settle helpers.
  - DW-2458 follows Story 20.8's fix for DW-2415. Read that entry's remaining risk: a real timer that re-arms for the worker's whole life.
- **Files this story does not edit.** `_bmad/custom/*.yaml` and `CLAUDE.md` belong to the orchestrator and the Planner. Report any change they need.
