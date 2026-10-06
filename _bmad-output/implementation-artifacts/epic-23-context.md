# Epic 23 Context: The range-end cleanup

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Keep the deferred-work ledger honest and the code it names correct between releases. Each standing cleanup story drains an owner-approved slice of the `range-end-cleanup` queue. Story 23.4 is the current one. Its batch (a) fixes CI and test-environment health: flakes, test isolation, lost local throwaways and a fifth instance shard. Its batch (b) fixes open product correctness and safety entries. It also deduplicates the ledger's repeated ids, so later stories stop paying for flakes and no known unsafe path stays open.

## Stories

- Story 23.1: The range-end cleanup (done)
- Story 23.2: The range-end cleanup, part 2 (done)
- Story 23.3: The range-end cleanup, part 3 (done)
- Story 23.4: The range-end cleanup, part 4

## Requirements & Constraints

- **Roster** (owner key `23-4-the-range-end-cleanup-part-4`). Each entry ends terminal through the ledger tool: `resolved-by` with the commit, or `wontfix-accepted` / `by-design` with a reason and any reopen condition. Batch (c) polish, batch (d) hygiene and the IRIS defect candidates are out of scope.
  - (a) DW-2034, 2026, 2058, 1925, 1935, 1915, 1937, 1983, 1984, 1873, 1916, 1917, 1929, 1936, 1938, 2027, 1297, 1086, 2102.
  - (b) DW-1827, 1869, 1882, 1641, 1013, 1864, 1939, 1449, 1414, 1637, 1710, 1465.
- **Batches.** (a) and (b) each land with CI green on their own head and merge on their own. A red batch is reopened alone.
- **DW-2034.** Move the local throwaway root out of `/tmp` and leave CI's Linux path unchanged. `ci-throwaway.sh`'s scratch-root guard currently admits only `/tmp`, `/private/tmp` and `$TMPDIR`. `down` must remove a throwaway whose `compose.yml` is gone (`docker compose -p`). A check fails when a mounted local database has no `IRIS.DAT`.
- **DW-2102.** Five instance shard legs from timings refreshed off a green run (`node tools/ci-shards.mjs refresh --run <id>`). Every class runs in exactly one leg. `ui/tools/ci.test.mjs` holds the new shape; it pins `/4` in the matrix command today. Its AC9 needs timeout ≥ 1.5 × (largest leg + 3 min). Lower no `timeout-minutes` (81 now), and report a green run's longest instance leg.
- **Flakes and isolation (a).** The plan names each reproduction, and the fix passes under it. A test that assumes instance state creates and restores it, or asserts only on what its own action produced. Ledger directions:
  - DW-2026: protocol hangs across specs, 730 s even after DW-1822's 600 s `protocolTimeout`. Fix it once in the browser harness: a fresh page or browser and one retry per protocol timeout, not per spec.
  - DW-2058: `structural-walk.mjs` must tolerate a node replaced mid-walk.
  - DW-1983: key waits to the second turn's settled reply.
  - DW-1984: wait for `.ocu-form-bar-actions` before looking up Cancel.
  - DW-1873: exclude or move off a hover-revealed rail tooltip before the capture.
  - DW-1915 and DW-1937: audit row timing against the read window (inference).
  - DW-1916, 1917, 1929, 1938: reused-container leftovers. Delete the policy row when none existed, clean up the `_SYSTEM` turn and conversation, and set aside and restore preferences, switches and Turn/Step.
  - DW-1936: extend `GovernanceRestore` to `ErrorDelete`, and sweep for any other class that exercises a governance key.
  - DW-2027: exclude stored interop credentials, or assert only on globals this test's own action names.
  - DW-1297: the install-lock refusal names the `^$LOCK` holder.
  - DW-1086: extract the turnprobe helpers into one module, as `list-spec.mjs` did, on `iris-session.mjs`'s marker.
- **Correctness and safety (b).** A test reddens on each defect before the fix and passes after it.
- **Ledger dedup.** DW-1223, 1864, 1925 and 2027 each have two blocks. Each id ends with one entry carrying the union of both copies' trailers in time order, and `ledger.sh load` counts each id once. DW-1223's two blocks describe different defects: a proposal-card disclosure, and error-log navigation timeouts. Both carry the same `resolved-by:5-8` trailer, so the plan must decide that case explicitly.

## Technical Decisions

- **Ledger.** Use `bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md load|slice|show|append` only. It is append-only; never open the file.
- **Spine amendments (Rule 20), corrected at origin.**
  - DW-2102: Stack › CI and Operational Envelope › Build and CI both say four ObjectScript shards. CLAUDE.md's CI paragraph and `docs/DEVELOPMENT.md`'s job table and shard sentence say four too.
  - DW-1882: AD-34 says a screen Save (AD-55) "does not hold it yet". DW-1497's per-target hold (`CLAIMLOCKSECONDS`, 409 `WRITE.TARGETBUSY`, AD-13 canonical key, escalated frame) currently covers confirm and row action only.
  - DW-1710: decided. A create re-reads by `createdId` through the update tool's read, and AD-58's wording and the Deferred row are amended with the fix.
  - DW-1827: AD-22 ships `tasks.schedule.import` disabled until import reviews `TaskClass` and `RunAsUser`. Classify run-as-other at the strongest confirmation and apply the create's rules, then re-enable.
- **Other ADs in play.**
  - AD-10 (DW-1869): every permitted privilege grant is minted destructive, with no typed name and a diff naming the privilege. DW-1881's 23.3 fix (f2168084, `EntryParts` reads both spellings, roles judged by privilege) may already cover DW-1869 (inference). Confirm on the instance first.
  - AD-12 (DW-1864): the one response writer, with the `}{` and one-envelope tests. Stream `%ToJSON()` to the device rather than as one string.
  - AD-14 (DW-1939): entity types are one closed kernel enum. Either add a remote type (DW-1529 precedent; prove AD-34's lock key cannot diverge) or make the lookup owner-aware.
  - AD-26 (DW-1637): a queued write past the bound answers "started" and is marked applied. Record a durable started outcome, for example a `PORT.STARTED` code.
  - AD-4 (DW-1641): merge the agent's `Metadata` over the fresh read through `Write.MergeUpdate`.
  - AD-15, AD-8, AD-9 (DW-1449): a manual re-enable needs a privileged producer.
  - Conventions › Tests: no test depends on another's leftovers, order or instance age.
- **Verification.**
  - Pass the slot profile on every MCP call, and run one test class at a time with totals from `%UnitTest_Result`.
  - Do a Rule 19 mutation per AC, and recompile the tree before reading it.
  - Redeploy the bundle before reporting a browser result.
  - Run the full sweeps once before `dev_complete` (Rule 29), and `npm run test:tools` when `ci.yml`, `epics.md` or EXPERIENCE.md changes.
- **Git.** Stage by path, push a code commit alone before any `[skip ci]` commit, and never touch a release branch.

## UX & Interaction Patterns

- DW-1939: a toast's "Open in <list>" opens the entity's own list with the entity selected.
- DW-1449: the "Agent writes are not being marked" banner must clear when auditing is on, however it was re-enabled.
- DW-1013: the screen reads an empty Allowed IP addresses list as "Unrestricted" (any address may connect), but the model still sees a bare `[]`.
- DW-1465: the proposal card's title names its target, which reads as a number for integer-keyed targets (task, process).
- DW-1637: a still-running copy reads "Read back: not checked, the write is still running".
- DW-1414: a failure is announced once (`role="alert"`) and attributed to its true origin.

## Cross-Story Dependencies

- DW-2102 repeats 23.3's DW-1901 (fourth shard). DW-1936 extends 23.3's DW-1839 `GovernanceRestore`. DW-2026 follows DW-1822. DW-1916, 1917 and 1929 are DW-1204's family.
- DW-1882 extends 23.2's DW-1497. DW-1869 follows 23.2's DW-1663 and 23.3's DW-1881. DW-1013 may reuse Story 19.18's AD-36 criterion hints, `CriterionHints` (inference).
- `ci.yml` and `ci-timings.json` serve every lane, including Epic 20's next runs. Slot A runs 23.4 before Epic 20.
