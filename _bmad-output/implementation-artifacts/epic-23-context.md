# Epic 23 Context: The range-end cleanup

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Epic 23 holds the standing cleanup stories chartered between releases. Each takes an approved slice of the deferred-work ledger, at most twelve entries, by priority: CI flakes first, then security, then repeat occurrences, then lowest fix-risk. Every entry ends with a disposition, fixed or declined with a reason, so the ledger stays honest and the code it names stays right. Story 23.14 is next and closes the epic: the burn-down of the 12 story-closable entries the burn-down gate took after Story 23.13. Eight are CI or local flakes; the rest are a Confirm privilege check on the wrong namespace, test leftovers, a missing stored-slot-order check, and a Journal records cold-open race. The other 20 burn-down entries went to Epic 21 stories.

## Stories

- Story 23.1: The range-end cleanup (done)
- Story 23.2: The range-end cleanup, part 2 (done)
- Story 23.3: The range-end cleanup, part 3 (done)
- Story 23.4: The range-end cleanup, part 4 (done)
- Story 23.5: The range-end cleanup, part 5 (done)
- Story 23.6: The Haiku-story cleanup (done)
- Story 23.7: The range-end cleanup, part 6 (done)
- Story 23.8: The range-end cleanup, part 7 (done)
- Story 23.9: The range-end cleanup, part 8 (done)
- Story 23.10: The range-end cleanup, part 9: two sweeps (done)
- Story 23.11: The range-end cleanup, part 10 (done)
- Story 23.12: The agent picks the right list (done, shipped in 1.0.14)
- Story 23.13: The range-end cleanup, part 11 (done)
- Story 23.14: Epic 23 burn-down (next)

## Requirements & Constraints

**Standing rules for every cleanup story**

- The ledger tool writes each entry's disposition: `resolved-by` with the commit, or `wontfix-accepted` / `by-design` with a reason, plus the condition that would reopen it where there is one.
- Treat each entry as a finding to verify at head, not as a fact. Recount any count against the structure, not by grep. An entry already fixed at head closes with the commit that fixed it.
- A test reddens on the defect before the fix, shown by a recorded mutation, or the entry says why no test can.
- Fixes land in batches grouped by area, each with CI green on its own head, so a failing batch is reopened alone.
- A CLAUDE.md line changes only through the Planner, with the owner's OK.

**Story 23.14 slice (12 entries)**

CI and local flakes come first. Each is fixed in the test or harness, and the plan names how it reproduces the flake.

- **DW-2236.** BackgroundTasksLive: Pause or Cancel answers 409 `TASK.BACKGROUND.STATE` because the seeded compact left Running. This recurs after three earlier fixes. Measured so far: suspending the portal job does not stop the work, and a cross-process hold blocks 30 s.
- **DW-2461.** `encryption-startup.browser-spec.mjs` C1, C2 and C9 time out waiting for the None start-mode control. Seen in four CI runs.
- **DW-2123.** A runner holds host port 52776 through all three of `ci-throwaway.sh`'s bring-up attempts, so the shard dies before any class runs. The bounded retry from DW-439 does not outlast it. A longer or backed-off wait, or a port probe, would cover it.
- **DW-2301.** a11y-structural-invariants AC5 reads a screen as unsettled within 20 s. A second form is headless Chrome dropping its connection. Log timings per visit before changing `SETTLE_TIMEOUT_MS` or `QUIET_MS`.
- **DW-2397.** turn spec "Markup in a reply renders as literal text" reads the reply before its text finishes arriving. The spec must wait for the reply's settled state.
- **DW-2111.** Five error-log browser navigations time out at 30 s in one run. The suspect is that spec's own heavy seeding (inference). Probe it alone on a fresh throwaway.
- **DW-2526.** `LogHubErrors.TestASeededErrorReadsInTheHubsForm` asserts on the store's newest row. A concurrent error can take that row (inference).

Then the rest:

- **DW-2253.** System Explorer's compile, delete and import Confirm check WRITE on the request's namespace, while the write targets the proposal's namespace. This is a false refusal only. The decided fix follows Story 20.20's saves and creates: store `Namespace` in the mint args and read it in `ArgumentPairs`. This is the slice's security entry (inference).
- **DW-2403.** The turn wire test classes leave their probe user's ledger rows. `TurnWireFixture.SweepSince` reads the collated key, so the exact match misses it (measured: 7 rows left). Fix it with `%EXACT`, sweep the siblings, and cover TurnNavigate's teardown.
- **DW-2408.** `interop-item-test.browser-spec.mjs` cleanup leaves message headers and the probe production's `Ens_Util.Log` rows in USER. The spec must remove what it caused.
- **DW-2501.** Nothing fails when a new stored property on a `%Persistent` class without a source Storage section is declared anywhere but last. The owner asked for a check that compares each persistent class's stored property order against the previous release tag.
- **DW-2543.** Journal records: a cold open that arrives with Newest first calls `setDirection`. That saves the whole default view before the account read answers, so it can lose the remembered filter, row limit and widths. The timing is unverified. Settle it by arriving at the records URL with `order=1` after remembering a filter, then reading the preference row. Fix ideas: skip `rememberView` until `remembered()` is true, or defer the write until adoption.

## Technical Decisions

- **Privilege is checked at call time against the target.** The write gate sits on the write. Namespace is a first-class parameter, and a Confirm's privilege pairs must name the namespace the write actually targets (AD-8, AD-40, AD-44).
- **Stored-slot order.** A property added to a `%Persistent` class of OcuPilot's own state is declared after every existing property. The source carries no Storage section, so an insertion shifts slots and earlier rows read wrong values. A rename or removal needs a migration. A new check enforces this convention. It does not change it.
- **Remembered view.** Per-user preferences are one store. Every write is a guarded, version-conditional save (AD-50). Screen state lives in the store, never in a component field (AD-19). Story 23.13 added `remembered()` and `restoredView()` and the journal page's `followOrder()`. Build on those.
- **Ledger rows** are bounded audit records (AD-41). A test removes only the rows its own turns created.
- **Never raise product bounds.** Leave `AdminPort.ASYNCTIMEOUT`, MDX bounds and `navigationTimeoutMs` alone. Fix flakes in the test or harness.
- **Tests are hermetic.** A test creates and restores the state it asserts on, and a teardown undoes only what its own setup did. A changed test passes on a fresh throwaway, in either order. Test classes compile only on a throwaway (AD-17).
- **Verification.**
  - Work on slot A: `server: "ocupilot-slot-a"`, throwaway `ocupilot-ci` on 52776/1975.
  - Run one ObjectScript test class per call, and take totals from `%UnitTest_Result`.
  - Rebuild and redeploy the bundle before reading any browser result. The full browser suite and the full ObjectScript sweep belong to CI and the lead.
  - Never start, stop or recreate `ocupilot` or any `ocupilot-slot-*` container.
- **Out of bounds.** Do not edit `CLAUDE.md`, `.claude/**`, `_bmad/**`, `.github/workflows/ci.yml` or `ui/tools/ci-timings.json`. A new `check-objectscript.py` rule would make CLAUDE.md's "21 rules" stale, which goes to the Planner. Comments state contracts only, and source stays ASCII.

## UX & Interaction Patterns

- DW-2543: a cold open with Newest first must keep the person's remembered filter, row limit and column widths. Story 23.13's Newest-first and remembered-direction behavior must stay green.

## Cross-Story Dependencies

- **Epic 20 runs beside this epic on slot B.** Stories 20.40 and 20.41 are done in its worktree, and 20.26 is ready for dev.
  - Epic 20's branch changes `scripts/ci-throwaway.sh`, which is DW-2123's file. Its edit lands either before or after that change, with a Rule 11 ask.
  - `Screen/**` belongs to Epic 20. Check contention before DW-2253 touches `Screen/Tool/ExplorerWrite.cls`.
  - Before each batch, re-check with `git -C ../epic-20 diff --stat origin/feature/OCU-1_ocupilot-mvp...HEAD` and `status -s`.
- **Story 23.13** shipped the journal order fix that DW-2543 builds on.
- **Epic 23 closes after this story.** Its footprint covers `src/OcuPilot/`, `ui/src/`, `ui/tools/`, `ui/browser/`, `scripts/`, `docs/` and the planning artifacts.
