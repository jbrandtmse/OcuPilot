# Epic 23 Context: The range-end cleanup

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Epic 23 holds the standing cleanup stories chartered between releases. Each takes an owner-approved slice of the deferred-work ledger, at most twelve entries, by priority: CI flakes first, then security, then repeat occurrences, then lowest fix-risk. Every entry ends with a disposition, fixed or declined with a reason, so the ledger stays honest and the code it names stays right. Story 23.13 is next. It was split from Story 23.10 at that story's spec gate. It carries one reopened CI flake first, then two AD-10 refusal-classifier edges, one Rule 31 lift across sixteen delete tools, and two Journal records defects in the Newest first order.

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
- Story 23.13: The range-end cleanup, part 11 (next)

## Requirements & Constraints

**Standing rules for every cleanup story**

- The ledger tool writes each entry's disposition: `resolved-by` with the commit, or `wontfix-accepted` / `by-design` with a reason, plus the condition that would reopen it where there is one.
- Treat each entry as a finding to verify at head, not as a fact. Recount any count it quotes against the structure, not by grep. An entry already fixed at head closes with the commit that fixed it.
- A test reddens on the defect before the fix, shown by a recorded mutation, or the entry says why no test can.
- Fixes land in batches grouped by area, each with CI green on its own head, so a failing batch is reopened alone.
- A CLAUDE.md line changes only through the Planner, with the owner's OK.

**Story 23.13 slice (6 entries)**

- **DW-1822, CI flake, first.** The a11y-structural-invariants walk times out. Story 23.9 already bounded the settle through `fonts.status`, with a 60 s deadline per call and a retried pass. It recurred on staging run 43379465200, attempt 1: AC5's settle on `/agent/governance` at 720 px timed out at `protocol-retry.mjs:48`. The plan names how it reproduces it, and the fix passes under that same condition. This worktree's ledger copy still shows the entry resolved by 23.9; the routing to 23.13 comes from the epics file.
- **DW-2431.** AD-10's KMIP arm ignores journal encryption. Measure first, on a throwaway: a KMIP startup server at an unreachable host, `DBEncJournal` on, none of the three databases encrypted, then one restart. If that start does not finish, widen the arm. If the vendor refuses the setting or the start finishes, keep the arm (`wontfix-accepted` with a `reopen_if`). Story 23.10's plan holds the Task 0 steps and the decision rule.
- **DW-2432.** This one is decided: treat it as DW-2425 was treated. A resource edit that adds public `U` to a resource guarding an enabled web or privileged routine application whose `MatchRoles` grant a privileged role mints `GRANT.PRIVILEGED` at the destructive treatment, and a failed lookup counts as a grant.
- **DW-2525.** Sixteen delete tools repeat `Write.RemovalRows`'s loop: eleven over `FingerprintSubject()`, five over `ReadAnswers()` (four of those with the unassigned skip). Give `RemovalRows` a names argument and move all sixteen onto it, without changing behavior. A new-site sweep test catches the old form.
- **DW-1979 (visible).** Newest first fetches the newest rows but draws them in ascending order. The page must steer the store's remembered sort direction. Fix-risk is medium.
- **DW-2527.** Paging Newest first, when the matches end exactly at the page cap, can scan back to the start of the journal and answer `PORT.TIMEOUT`. The cause: the vendor's hidden ListTask seeks one match past `MaxRows`. That timeout is unmeasured (inference).

## Technical Decisions

- **AD-10 refusal arms.** Today the KMIP arm refuses a startup KMIP change only while the audit log, IRISSECURITY or IRISTEMP is encrypted. The journal arm (`PROHIBITED.STARTUPJOURNAL`) runs for Interactive only. Measure before widening an arm. A widening amends AD-10 in the spine (Rule 20) and needs wording settled at the spec gate. Any new code, on-screen string or posture stricter than the classic portal is a veto-window escalation. AD-55 means one tool serves both callers, so a treatment covers the agent and a person's Save.
- **Reuse 23.10's plan.** Story 23.10's spec holds the investigation for batches 4 to 6: Code Map, Tasks, Design Notes, dispositions and siblings. Its line numbers are at `9546204ad`, so locate code by symbol.
- **Rule 31 siblings.**
  - `LeavesModeJournal` follows `LeavesModeRequired`.
  - `GuardsPrivilegedApplication` reuses DW-2425's `ApplicationRolesEscalate`, `EnabledOn` and `ReadMember`.
  - DW-2525 extends `RemovalRows` itself.
  - DW-1979 calls the store's existing `setDirection`, as the command bar does (AD-19, AD-50).
- **Never raise product bounds.** Leave `AdminPort.ASYNCTIMEOUT`, the MDX bounds and `navigationTimeoutMs` in `ui/browser/browser.config.mjs` alone. Fix flakes in the test or harness.
- **Tests are hermetic.** A test creates and restores the state it asserts on, and a teardown undoes only what its own setup did. A changed test passes on a fresh throwaway, in either order (Rules 19 and 30).
- **Verification.**
  - Work on slot A: `server: "ocupilot-slot-a"`, throwaway `ocupilot-ci` on 52776/1975.
  - Run one ObjectScript test class per call, and take totals from `%UnitTest_Result`.
  - Rebuild and redeploy the bundle before reading any browser result. The full browser suite and the full ObjectScript sweep belong to CI and the lead.
  - DW-2431's restart of `ocupilot-ci` needs the lead's grant, and a rebuild follows it. Never start, stop or recreate `ocupilot` or any `ocupilot-slot-*` container.
- **Out of bounds.** Do not edit `CLAUDE.md`, `.claude/**`, `_bmad/**`, `.github/workflows/ci.yml` or `ui/tools/ci-timings.json`, and do not add a 22nd `check-objectscript.py` rule. Comments state contracts only (Rule 14), and source stays ASCII.
- **No release-upgrade trigger is expected.** The planned edits touch no `Kernel/State`, `Install`, `module.xml` or compose file.

## UX & Interaction Patterns

- DW-1979: Newest first draws the newest rows first. Oldest first draws ascending. A component spec reddens on the old order. Steering the direction writes the same remembered-view row the command bar writes.
- DW-2432 reuses the existing `privilegedGrantEffect` sentence on the agent's card and adds no new string. Whether a person's Save on the Resources editor should show a field line is an optional wording escalation; parity with DW-2425 means none.

## Cross-Story Dependencies

- **Epic 20 runs beside this epic on slot B.** Story 20.25 has merged. Story 20.40 is in implement, followed by 20.26 and 20.41.
  - `Kernel/Proposal/Prohibited.cls` is planned by 20.26, 20.40 and 20.41. The DW-2431 and DW-2432 edits there are not add-only, so they land either before those stories implement or after they merge, with a Rule 11 ask.
  - `Screen/**` belongs to Epic 20. Check contention before DW-2525 touches `Screen/Tool/Write.cls` and the sixteen delete tools.
  - Keys added to `strings.ts` must be add-only.
  - Before each batch, re-check with `git -C ../epic-20 diff --stat origin/feature/OCU-1_ocupilot-mvp...HEAD` and `status -s`.
- **Footprint.** Epic 23 covers `src/OcuPilot/`, `ui/src/`, `ui/tools/`, `ui/browser/`, `scripts/`, `docs/` and the planning artifacts. CLAUDE.md is outside it.
