# Epic 23 Context: The range-end cleanup

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Epic 23 holds the standing cleanup stories chartered between releases. Each one takes an owner-approved slice of the deferred-work ledger, at most twelve entries chosen by priority (CI flakes, then security, then repeat occurrences, then lowest fix-risk). Every entry in the slice ends with a disposition: fixed, or declined with a reason. That keeps the ledger honest and the code it names correct. This dispatch resumes after the owner's pause, with 1.0.13 and 1.0.14 released. Story 23.9 runs first, its two CI flakes ahead of everything else. Story 23.10's two sweeps follow, then the epic's burn-down.

## Stories

- Story 23.1: The range-end cleanup (done)
- Story 23.2: The range-end cleanup, part 2 (done)
- Story 23.3: The range-end cleanup, part 3 (done)
- Story 23.4: The range-end cleanup, part 4 (done)
- Story 23.5: The range-end cleanup, part 5 (done)
- Story 23.6: The Haiku-story cleanup (done)
- Story 23.7: The range-end cleanup, part 6 (done)
- Story 23.8: The range-end cleanup, part 7 (done)
- Story 23.9: The range-end cleanup, part 8 (next)
- Story 23.10: The range-end cleanup, part 9: two sweeps (after 23.9)
- Story 23.11: The range-end cleanup, part 10 (done)
- Story 23.12: The agent picks the right list (done, shipped in 1.0.14)

## Requirements & Constraints

**Standing rules for every cleanup story**

- The ledger tool writes each entry's disposition: `resolved-by` with the commit, or `wontfix-accepted` / `by-design` with a reason. Where some condition would reopen the entry, the disposition names it.
- Treat each entry as a finding to verify at head, not as a fact. Recount any count it quotes against the structure, not by grep. An entry already fixed at head is closed with the commit that fixed it.
- A test reddens on the defect before the fix, shown by a recorded mutation. If no test can, the entry says why.
- Fixes land in batches grouped by area, each batch with CI green on its own head, so a failing batch is reopened alone.
- A CLAUDE.md line changes only through the Planner, with the owner's OK.

**Story 23.9 entries (12)**

- **CI flakes, first:**
  - DW-1822: the a11y structural walk stalls on `Runtime.callFunctionOn`. Raising `protocolTimeout` to 600 s did not hold. On the last recurrence the spec took 1912.6 s against 414.8 s recorded, and browser shard 1/5 hit its 55-minute limit. The ledger proposes splitting the per-screen evaluation.
  - DW-2512: `local-databases.browser-spec.mjs` hits a 30 s navigation timeout at `signedInAt`'s `page.goto`.
  - For each flake, the plan names how it was reproduced, and the fix passes under that same condition.
- **Docs that no longer match the code:**
  - DW-446 and DW-1177: the CLAUDE.md line on `check-objectscript.py`'s rule count and on staged-path scope. Check these against CLAUDE.md as it reads now.
  - DW-1706: `Api/Error.cls` documents `PROVIDERTRANSPORT` as "never retried". In fact a failure with no status line is retried once on a new connection; a connect that never opened (`#6059`) is not retried.
  - DW-2060: the code count in the `Codes` doc of `Kernel/Proposal/Prohibited.cls`.
- **Pair validation, in both engines alike:**
  - DW-1760: `Screen/Registry.cls` and `ui/tools/screen-mirror.mjs` must refuse an own pair that the screen's area already declares, and an `ownPrivileges` equal to all of `privileges`.
  - DW-1761: the instance must refuse a non-string resource or permission, as the client mirror already does. Add a non-string case to the shared corpus.
- **Duplication and tooling:**
  - DW-2259: `ui/tools/ci-runner.mjs` finds test classes on disk by their direct `Extends` only. It must also count a class that reaches `%UnitTest.TestCase` through a project base class, such as `StreamCase`.
  - DW-2260: the client declares `USERS_PATH` twice. Keep one export.
  - DW-2299: lift the delete tools' repeated `StateDiff` body into `Screen/Tool/Write.cls`, and make the delete tools extend it. The lift is add-only.
- **Journal record browser:**
  - DW-1981: the offset and value inputs get a `maxlength`, as `code-list.page.ts` sets one. Check the bundle budget at head.

**Story 23.10 entries (5)**

- **DW-2417, a sweep:** two-argument `%GetNext` over a caller's JSON answers 500 past MAXSTRING/MAXNUMBER. The ledger counts 109 sites in 54 Area files; recount them.
  - Route the key loops through one typed helper beside `Kernel.Utils.ReadRequestBody`.
  - Add the type argument at nested loops, and check untyped `%Get`.
  - An out-of-range value must answer its field refusal.
- **DW-2426, a sweep:** 48 test classes run `OnAfterAllTests` cleanup on an unarmed instance. `%UnitTest` runs it even after a refused `OnBeforeAllTests`, and `GovernanceFixture.Restore` over no snapshot deletes every policy row. A test run must never delete shared state it did not set up.
- **DW-2431:** measure on a throwaway whether a KMIP start with journal encryption on, and none of the three databases encrypted, actually fails. Widen the KMIP arm only after that measurement.
- **DW-2432:** a resource edit that adds public USE to a resource guarding an enabled application gets the privileged-grant treatment when that application's MatchRoles grant a privileged role.
- **DW-1979:** Newest first reads the newest rows but draws them ascending. The page must steer the store's remembered sort. Fix-risk is medium.
- **Each sweep:** a test reddens on a representative site. The story says how a new site written the old way is caught, or why none can be. Each sweep lands as its own batch.

## Technical Decisions

- **The descriptor is the single source (AD-5).** Pair validation keeps `Screen.Registry` and `screen-mirror.mjs` equal over one shared corpus. A fix lands in both engines, with a case in both corpora.
- **Own pairs (AD-8 as amended).** `ownPrivileges` is a subset of `privileges`. `AreaCoverageProblem` holds the area's declared set to every pair its screens declare, less each screen's own pairs. So an own pair must never let a screen leave that check.
- **AD-42 transport retry.** A failure with no status line is retried once, on a new connection, inside the same budget. A `#6059` connect that never opened is not retried. A write never retries mid-flight.
- **AD-10 refusal arms (23.10).**
  - The KMIP arm refuses a startup KMIP change while the audit log, IRISSECURITY or IRISTEMP is encrypted.
  - The privileged-grant arm covers MatchRoles and resource grants.
  - Measure first. Amend AD-10 in the spine (Rule 20) when an arm widens.
- **Rule 31: extend the sibling.** Name the sibling each change extends: `Write.cls` for `StateDiff`, the existing `ReadRequestBody` helper, the one exported path constant. A copy needs a stated reason.
- **Tests are hermetic.**
  - A test creates and restores the state it asserts on.
  - A count asserted outside its roster's own test is derived, never literal.
  - Every changed test passes on a fresh throwaway, in either order (Rules 19 and 30).
- **Verification (Rules 29, 30 and 32).**
  - Work on slot A: `server: "ocupilot-slot-a"`, with throwaway `ocupilot-ci` on 52776/1975.
  - Run one ObjectScript test class per call, and take totals from `%UnitTest_Result`.
  - Rebuild and redeploy the bundle before reading any browser result.
  - The full browser suite is left to CI.
  - Never start, stop or recreate `ocupilot` or any `ocupilot-slot-*` container. Tear down only a throwaway this run started.
- **Prose (Rule 14).** Comments state contracts only. Source text is ASCII, with `\uXXXX` escapes.

## Cross-Story Dependencies

- **Order.** 23.9 runs on slot A, with DW-1822 and DW-2512 first. 23.10 and then the epic's burn-down follow. DW-1979 moved from 23.9 to 23.10 to keep 23.9 at twelve entries.
- **Concurrency.** Epic 20 runs beside this epic on slot B (20.34 next). Its footprint overlaps Epic 23's: `Port`, `Kernel`, `Api`, `Screen`, `Install`, `Test`, `ui/src/app/{areas,shell,core}`, `ui/tools` and `ui/browser`.
  - Files there are contended. Rule 11 applies: a contended edit goes to `## Clarification Needed`.
  - `Screen/Tool/Write.cls` takes the `StateDiff` lift as an add-only change.
- **Footprint.** Epic 23 covers `src/OcuPilot/`, `ui/src/`, `ui/tools/`, `ui/browser/`, `scripts/`, `docs/` and the planning artifacts. CLAUDE.md is outside it, so report any edit there under `footprint_extensions:`.
