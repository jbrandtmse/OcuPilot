# Epic 23 Context: The range-end cleanup

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Epic 23 holds the standing cleanup stories chartered between releases. Each takes an owner-approved slice of the deferred-work ledger, at most twelve entries chosen by priority: CI flakes, then security, then repeat occurrences, then lowest fix-risk. Every entry in the slice ends with a disposition, fixed or declined with a reason, so the ledger stays honest and the code it names stays correct. Story 23.10 is next. It carries four CI flakes ahead of everything else, then the two sweeps it was chartered for, two refusal-classifier edges, one Rule 31 lift and one visible journal-order defect.

## Stories

- Story 23.1: The range-end cleanup (done)
- Story 23.2: The range-end cleanup, part 2 (done)
- Story 23.3: The range-end cleanup, part 3 (done)
- Story 23.4: The range-end cleanup, part 4 (done)
- Story 23.5: The range-end cleanup, part 5 (done)
- Story 23.6: The Haiku-story cleanup (done)
- Story 23.7: The range-end cleanup, part 6 (done)
- Story 23.8: The range-end cleanup, part 7 (done)
- Story 23.9: The range-end cleanup, part 8 (batch 3 still open)
- Story 23.10: The range-end cleanup, part 9: two sweeps (next)
- Story 23.11: The range-end cleanup, part 10 (done)
- Story 23.12: The agent picks the right list (done, shipped in 1.0.14)

## Requirements & Constraints

**Standing rules for every cleanup story**

- The ledger tool writes each entry's disposition: `resolved-by` with the commit, or `wontfix-accepted` / `by-design` with a reason, plus the condition that would reopen it where one exists.
- Each entry is a finding to verify at head, not a fact. Recount any count it quotes against the structure, never by grep. An entry already fixed at head closes with the commit that fixed it.
- A test reddens on the defect before the fix, shown by a recorded mutation, or the entry says why none can.
- Fixes land in batches grouped by area, each with CI green on its own head, so a failing batch is reopened alone.
- A CLAUDE.md line changes only through the Planner, with the owner's OK.

**Story 23.10 slice (10 entries)**

- **CI flakes, first.** For each, the plan names how it was reproduced, and the fix passes under that same condition.
  - DW-2513: `data-table-columns.browser-spec.mjs` failed 17 of 18 at its own `goto` against its local server (main push run 40026736561).
  - DW-2517: `JournalRecords` reverse-order test read its next page as `PORT.TIMEOUT` once in a full sweep; the class reran alone 10/10 green.
  - DW-2522: `analytics-mdx.browser-spec.mjs` AC1's first query grid did not appear within the navigation timeout on browser shard 2/5. It absorbs DW-2523's occurrence (dropped as a duplicate). A cold first query on a fresh leg is the working guess (inference).
  - DW-2524: `context-chip.browser-spec.mjs` test 7 (Fresh at Send) waited past 30 s on shard 4/5. DW-2493, routed to burndown, records the same test failing the same way earlier; the plan decides whether to fold it in.
- **DW-2417, sweep one.** Two-argument `%GetNext` over a caller's JSON answers 500 past MAXSTRING/MAXNUMBER. The ledger counts 109 sites in 54 Area files; recount them. Route key loops through one typed helper beside `Kernel.Utils.ReadRequestBody`, add the type argument at nested loops, and check untyped `%Get`. An out-of-range value must answer its field refusal.
- **DW-2426, sweep two.** 48 test classes run `OnAfterAllTests` cleanup on an unarmed instance. `%UnitTest` runs it even after `OnBeforeAllTests` refuses, and `GovernanceFixture.Restore` over no snapshot deletes every policy row. Guard each class by its own arming condition, not inside `Restore`. A test run must never delete shared state it did not set up.
- **DW-2431.** First measure on a throwaway whether a KMIP start with journal encryption on, and none of the three databases encrypted, actually fails. Decide AD-10's scope from that measurement.
- **DW-2432.** A resource edit that adds public USE to a resource guarding an enabled application whose MatchRoles grant a privileged role takes the privileged-grant treatment. This is decided; it is the reverse of DW-2425.
- **DW-2525.** Sixteen delete tools repeat `Write.RemovalRows`'s loop over `FingerprintSubject()` (11) or `ReadAnswers()` (5, four with the unassigned skip). Give `RemovalRows` a names argument defaulting to `REMOVALROWS` and move the sixteen onto it.
- **DW-1979.** Journal records' Newest first fetches the newest rows but draws them ascending. The page must steer the store's remembered sort. Fix-risk is medium.
- **Each sweep:** a test reddens on a representative site. The story says how a new site written the old way is caught, or why none can be, and each sweep lands as its own batch.

## Technical Decisions

- **AD-10 refusal arms.** The KMIP arm refuses a startup KMIP change while the audit log, IRISSECURITY or IRISTEMP is encrypted. The privileged-grant arm covers MatchRoles and resource grants. Measure before widening an arm, and amend AD-10 in the spine (Rule 20) when one widens.
- **Rule 31: extend the sibling.** Name the sibling each change extends: `Write.cls` `RemovalRows` for DW-2525, `ReadRequestBody` for the typed key helper, `ProviderSslCallTime`'s arming guard for DW-2426. A copy needs a stated reason.
- **Tests are hermetic.** A test creates and restores the state it asserts on. A count asserted outside its roster's own test is derived, never literal. Every changed test passes on a fresh throwaway, in either order (Rules 19 and 30).
- **Verification (Rules 29, 30 and 32).**
  - Work on slot A: `server: "ocupilot-slot-a"`, throwaway `ocupilot-ci` on 52776/1975.
  - Run one ObjectScript test class per call, and take totals from `%UnitTest_Result`.
  - Rebuild and redeploy the bundle before reading any browser result. The full browser suite is left to CI.
  - Never start, stop or recreate `ocupilot` or any `ocupilot-slot-*` container. Tear down only a throwaway this run started.
- **Prose (Rule 14).** Comments state contracts only. Source text is ASCII, with `\uXXXX` escapes.

## UX & Interaction Patterns

- DW-1979 is visible: the Newest first criterion must draw newest rows first, and a component or browser spec reddens on the old order.

## Cross-Story Dependencies

- **Order.** 23.10 may plan now. Its implement waits until 23.9 closes. 23.9's batch 3 (DW-1177, DW-1760, DW-1761) waits on Story 20.39 merging, because 20.39 changed `Screen/Registry.cls` and `ui/tools/screen-mirror.mjs`.
- **Concurrency.** Epic 20 runs beside this epic on slot B. Its next stories are 20.36, 20.25, 20.26, 20.40 and 20.41, then its burn-down. Its footprint overlaps Epic 23's: `Port`, `Kernel`, `Api`, `Screen`, `Install`, `Test`, `ui/src/app/{areas,shell,core}`, `ui/tools` and `ui/browser`.
  - Rule 11 applies to contended files: a contended edit goes to `## Clarification Needed`.
  - `Screen/**` is Epic 20's. Check contention before DW-2525 touches the sixteen delete tools. `Kernel/Proposal/Prohibited.cls` is Epic 20-contended for DW-2431 and DW-2432.
- **Footprint.** Epic 23 covers `src/OcuPilot/`, `ui/src/`, `ui/tools/`, `ui/browser/`, `scripts/`, `docs/` and the planning artifacts. CLAUDE.md is outside it, so report any edit there under `footprint_extensions:`.
