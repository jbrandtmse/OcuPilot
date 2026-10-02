# Epic 23 Context: The range-end cleanup

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Keep the deferred-work ledger honest and the code it names correct between releases. After each release a standing cleanup story drains at most twelve `range-end-cleanup` entries by priority: CI health and flakes, then security, then repeat occurrences, then lowest fix-risk. Story 23.3, chartered after the `release/1.0.5` cut, makes CI faster and trustworthy and keeps declared secrets out of what the agent shows.

## Stories

- Story 23.1: The range-end cleanup (closed)
- Story 23.2: The range-end cleanup, part 2 (done)
- Story 23.3: The range-end cleanup, part 3

## Requirements & Constraints

- **Roster** (owner key `23-3-the-range-end-cleanup-part-3`): DW-1901, 1866, 1822, 1808, 1865, 1759, 1839, 1204, 434, 1782, 1881, 1307. Each ends terminal through the ledger tool: `resolved-by` with the commit, or `wontfix-accepted` / `by-design` with a reason and any reopen condition.
- **Batches, in order**, grouped by area, one commit each, CI green on its head, a red batch reopened alone: (a) DW-1901; (b) flakes 1866, 1865, 1808, 1822; (c) isolation 1759, 1839, 1204, 434; (d) security, DW-1782 first (owner), then 1881, 1307.
- **DW-1901** (instance legs 38-46 min; timeout raised to 61 meanwhile): four instance legs from timings refreshed off a green run (`cd ui && node tools/ci-shards.mjs refresh --run <id>`); every class in exactly one leg; `ui/tools/ci.test.mjs` holds the new shape; no `timeout-minutes` lowered; report a green run's longest instance leg. A fourth browser leg is optional (routing note), not required.
- **Flakes and isolation:** the plan names each reproduction and the fix passes under it. A test assuming instance state (agent definitions, a governance override, a seeded row, a monitor state) creates and restores it, or asserts only on what its own action produced.
  - DW-1866: `AdminPortAbsence.TestAVerifiedDeletePostsNoAlert` judges alerts instance-wide, so a vendor alert (#7802) or an instance already at Warning (DW-1762) fails it; assert on lines this delete posts.
  - DW-1865 (`proposal-demo` spec): wait for the card's "done". DW-1808 (`audit-events` AC2): wait for the re-read by URL, not a fixed window. DW-1822 (`a11y-structural-invariants`): protocol timeout in the structural walk; raise `protocolTimeout` or split the per-screen evaluation.
  - DW-1759: 29 methods in seven classes fail when any agent definition exists (one seeded definition reproduces it). DW-1839: a stored governance override fails five classes (DeviceDelete, DeviceWire, DeviceWriteGate, Prohibited, ToolDispatch).
  - DW-1204: browser specs relying on seeded state (measured: `audit.browser-spec.mjs`) fail after the ObjectScript sweep ran on the same container; establish the set by running, not by grep.
  - DW-434: `switches.page.spec.ts` and `definition-form.page.spec.ts` assert `not.toContain` a transcribed STATE.CONFLICT reason, vacuous on a rewording; the pin must redden when the reason changes.
- **Security:** a test reddens on each defect.
  - DW-1782: a declared secret the model sends as an id never reaches a progress step's target (`Kernel.State.Step.Target`), the stored transcript or the panel; store the redaction mark at write time, as the ledger does.
  - DW-1881: a privileged role at a service address, under any name (`%Manager` too) and in either spelling (`|` or classic `address:roles`), is minted destructive. Direction: `RoleGrantsAdministrativePrivilege` plus `EntryParts` for held entries, which Story 16.13 does not canonicalize.
  - DW-1307: `Test/TurnSecretResidue` also sweeps the log line its header and Story 5.4's AC5 name.

## Technical Decisions

- **Ledger:** `bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md show|append`; append-only; never open the file.
- **Spine (Rule 20: amend when decided):**
  - DW-1901: Stack › CI and Operational Envelope › Build and CI say three shards per suite; amend both, and correct CLAUDE.md's CI paragraph and `docs/DEVELOPMENT.md`'s job table at origin. Roll-ups fail unless every item ran in exactly one leg and no leg ran zero tests.
  - Conventions › Tests: no test depends on another's leftovers, order or instance age; a shard-composition red is fixed in the test, never by pinning to a shard.
  - AD-2 (DW-1866): a read answered 404 logs nothing; other port failures log at error severity, which IRIS copies to `alerts.log` and counts toward its alert state.
  - AD-22 (DW-1839): governance resolves stored per-key setting, then preset, then baseline.
  - AD-33, AD-35, AD-41, AD-46 (DW-1782, DW-1307): progress is untrusted content in protected storage; no secret reaches a surface or log OcuPilot displays; secrets are excluded at write time, never redacted afterwards.
  - AD-10 (DW-1881): a permitted privilege grant is minted destructive, no typed name, its diff naming the privilege; the prohibited set has one kernel home, stated over effect, not payload shape (AD-53); effective privilege is composed only by `Kernel.Shell.Effective` (AD-8).
- **Verification:** slot profile on every MCP call; one test class at a time, totals from `%UnitTest_Result`; a Rule 19 mutation per AC; recompile the tree before reading a mutation; redeploy the bundle before a browser result; full ObjectScript sweep once before `dev_complete` (Rule 29); `npm run test:tools` when `ci.yml`, `epics.md` or EXPERIENCE.md changes.
- **Git:** stage by path; push a code commit alone before any `[skip ci]` commit; never commit to a release branch.

## UX & Interaction Patterns

- DW-1782: the tool-call card renders the step target, so it shows the redaction mark, as the ledger viewer does.
- DW-1881: the card carries EXPERIENCE.md's privilege-grant consequence sentence. The service editor sets an address's roles only through Edit roles.
- DW-434: Switches and the Definition form show EXPERIENCE.md's stale-save sentence, never the server's reason.

## Cross-Story Dependencies

- DW-1881 builds on Story 23.2's DW-1663 and Story 16.13's service arm; Epic 23 holds `Prohibited.cls`.
- DW-1782 extends Story 16.16's ledger redaction. DW-1866 pins DW-1814's AD-2 rule. DW-1204 generalizes DW-1190; DW-1447 showed a reused container's browser suite is not idempotent.
- `ci.yml` and `ci-timings.json` serve every lane, Epic 19's parallel runs included.
