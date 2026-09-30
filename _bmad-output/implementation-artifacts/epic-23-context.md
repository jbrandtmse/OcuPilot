# Epic 23 Context: The range-end cleanup

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Keep the deferred-work ledger honest and the code it names correct between releases. Closable entries that block no release and no downstream story are drained by standing cleanup stories of at most twelve entries each, chosen by priority: CI flakes, then security, then repeat occurrences, then lowest fix-risk. Story 23.1 is closed as it stood. Story 23.2 fixes, or declines with a reason, twelve owner-approved entries, so every CI lane stops paying for the same flakes and the guardrails do what they say.

## Stories

- Story 23.1: The range-end cleanup (closed)
- Story 23.2: The range-end cleanup, part 2

## Requirements & Constraints

- **Roster** (owner key `23-2-the-range-end-cleanup-part-2`): DW-1829, DW-1831, DW-1450, DW-1663, DW-1289, DW-1451, DW-1497, DW-1290, DW-1440, DW-1210, DW-1669, DW-48. Each entry's evidence and trailers carry its probe and recorded direction.
- **Every entry ends terminal, written by the ledger tool:** `resolved-by:` this story with the commit, or `wontfix-accepted` / `by-design` with a reason and any reopen condition. No onward re-owning unless the plan says why.
- **CI flakes** (DW-1829 background-task seed, DW-1831 OAuth discover `content` case): the plan names how each was reproduced; the fix is shown passing under that condition; a wait or predicate fix carries a Rule 19 mutation. DW-1829's trailers mark its 30 s-wait half void and name the DW-1802 mint-to-confirm race as the open cause.
- **Security** (DW-1450, DW-1663, DW-48): a test reddens on each defect. DW-48: a product install compiles no `Test.*` class; CI and throwaway paths still load them.
- **Batches:** grouped by area, one commit each, CI green on its head; a red batch reopens alone. Each merges to the feature branch once green, in this order: flakes, user-visible defects, security, the rest, DW-48 last. The story starts before the `release/1.0.4` cut; what is green on feature at the cut ships. Never commit to a release branch.
- **User-visible changes** are named in the plan with their entry; a fix that contradicts a document replaces the wrong sentence at origin.

## Technical Decisions

- **Ledger:** `bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md show|append`. Trailers are append-only; never read or hand-edit the whole file.
- **The spine (60 ADs) is a contract.** An AD a fix contradicts is amended in the spine's grammar when decided (Rule 20):
  - DW-1289/DW-1290: a validation-routine refusal carries 5001 (`$$$GeneralError`); allow-listing it reopens the catch-all AD-39 closes, so a 422 with the instance's reason needs AD-39 amended. 838 (no such user) stays opaque. The wire test needs an oracle independent of the code's index derivation.
  - DW-1440: IRIS checks the default globals database's resource; the installer derives the anonymous role from the routines database. Direction: grant both, amend AD-21. Reproduce where the two differ.
  - DW-1497: AD-34's per-target lock is the proposal store's; the screen caller (AD-53, AD-55's Save) writes unclaimed. A lock must cover both callers' port write, or record why vendor ordering suffices.
  - DW-1663: AD-10 permits privilege grants at the destructive confirmation with the diff naming the privilege; today's check is name-only and IRIS ships no `%Admin_` role. Judge the role by its privileges (a `Security.Roles` read, composed as `Kernel.Shell.Effective` does), which a two-pair principal may be refused; the client line needs a server-computed mark.
  - DW-1210: progress stays bounded (AD-33, AD-36); a per-poll bound on the steps projection is a poll-contract decision.
  - DW-48: AD-17 generates the compile roster and IPM manifest from one source, and the spine's source tree and CLAUDE.md place `Test/` under `src/OcuPilot/`. The recorded direction (a sibling tree excluded from the start hook and manifest) corrects them at origin.
- **DW-1450:** the confirm channel is closed to declared secrets (AD-6, AD-56). The settable set must be PermittedFields-aware in `Screen.Registry` and `ui/tools/screen-mirror.mjs`; the plain field list would reject every declared secret.
- **DW-1451:** `check-objectscript.py`'s destructive-test guard matches call shapes in one file and cannot follow a confirm; arming on the tool's class name reddened the shipped tree.
- **DW-1669:** `pollUntilTerminal` stops at the turn's end, so the privilege line goes stale. Direction: re-read live proposals slowly after the turn; Confirm already refuses a lost privilege.
- **Verification:** MCP tools on the runner's slot profile; one test class at a time, results from `%UnitTest_Result`; recompile the affected tree before reading a mutation; rebuild and redeploy before a browser result; `check-objectscript.py`, `lint-docs.sh`, and `npm run test:tools` when `epics.md` or EXPERIENCE.md changes.
- **Git:** stage by path; never push a `[skip ci]` commit together with a code commit.

## UX & Interaction Patterns

- The proposal card's privilege line says "requires", never "sufficient"; Confirm stays available and the instance's refusal is the verdict.
- A privilege-granting proposal takes the destructive treatment (no typed name) and its diff names the privilege.
- A refusal sentence is written once on the server and once in EXPERIENCE.md's Fixed strings, pinned equal by a test; change both together.

## Cross-Story Dependencies

- The flake fixtures belong to other epics: `Test/BackgroundSeed` and `Test/BackgroundTasksLive` (Story 16.5), `Test/OAuthServerDiscover` (Epic 12).
- DW-1289 and DW-1290 share Story 15.1's change-password path; the ledger pairs them.
- DW-48 changes the start hook, the throwaway and CI load paths and the manifest roster every later install uses, so it merges last.
