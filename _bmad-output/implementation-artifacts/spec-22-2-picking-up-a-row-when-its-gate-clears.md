---
title: 'Story 22.2: Picking up a row when its gate clears'
type: 'chore'
created: '2026-11-14'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** Story 22.1's register says what clears each excluded row, but nothing says what a builder does when someone asks for one: that the gate is checked before anything is designed, what a refusal says, where the request is recorded, and what a built row must be. Without that, demand is answered case by case or reopens the catalog.

**Approach:** Add a `## Picking up a row` section to `docs/exclusion-register.md` with three steps in order (assess the gate, answer when it has not cleared, build when it has), naming the real files of the screen contract, and extend `ui/tools/exclusion-register.test.mjs` so the section's order, its use of the register's columns, every gate kind's check and every path it cites are held by tests that can fail.

## Boundaries & Constraints

**Always:**

- The procedure is the register's own section, before `## Gate kinds`, so 22.1's parser (kinds between `## Gate kinds` and `## The register`, rows after it) reads exactly what it reads today.
- Assessment comes first: nothing is designed or built until the row's recorded gate reads cleared. A license, edition or platform check is re-run, read only, on the instance the request is for (named, never a default), and the value and date are recorded; the register's slot B reading is not the answer.
- A refused request is answered with the row's `Gate` cell and what its check read, and changes no file.
- A cleared request is recorded in a sprint change proposal (`bmad-correct-course`, under `_bmad-output/planning-artifacts/`) that the owner approves; it re-tiers the catalog row, moves it out of the extract's Stage 5 and adds the story that builds it, and the same change removes the row from the register.
- A built row follows FR-80's contract in the slice that owns its area; acceptance is that contract plus the row's own backing route or class. Anything finer is the pick-up story's.
- Column names the test requires the procedure to use are derived from the test's `REGISTER_COLUMNS`; every repository path the section names must exist.

**Never:**

- No row is built, promoted, re-tiered or re-read into the register; no sample pick-up or demo row.
- No edit to any planning document, `README.md`, `docs/DEVELOPMENT.md`, `CLAUDE.md`, `.claude/` or `_bmad/`; no ObjectScript, `ui/src` or product string; no new tracker or artifact type.
- No IRIS call and no throwaway.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| In step | section present, three steps in order, every kind checked, every path real | tests pass | none |
| Missing or misplaced | no `## Picking up a row`, or it follows `## Gate kinds` | red, naming the heading | never a vacuous green |
| Wrong order | a step heading missing or out of order | red, naming the expected order | none |
| Column not named | the assess or refuse step omits a register column it must quote | red, naming step and column | none |
| Kind without a check | a Gate kinds row with an empty `How a request checks it` cell | red, naming the kind | floor: kinds read > 0 |
| Stale path | a backticked repository path that does not exist | red, naming the path | a `<placeholder>` path checks its directory |
| Contract gap | the build step omits a contract file | red, naming the file | none |

</intent-contract>

## Code Map

- `docs/exclusion-register.md` -- 22.1's register. Opening lines 1-28 (lines 22-23: "Promoting a row ... in the same change"); `## Gate kinds` line 30, a `| Kind | What clears it |` table of eight kinds; `## The register` line 43, groups after it. Extend here.
- `ui/tools/exclusion-register.test.mjs` -- 22.1's drift test: `cellsOf`, `linesOf`, `REGISTER_COLUMNS`, `parseRegister()` (reads only `cellsOf(line)[0]` of the kinds table, so a third column is safe). Extend; reuse its helpers.
- `src/OcuPilot/Screen/Area.cls` (`XData Areas`, lines 80-92) -- the 11 area keys; `appliesWhen` exists only per area (a `Kernel/Shell/NamespaceFeatures` feature), not per screen.
- Slice homes: `src/OcuPilot/Area/<Area>/` (folders `Analytics Explorer Interop OsMgmt Permissions Security Task WebApp`) and `ui/src/app/areas/<area>/` (area keys). No file maps catalog prefixes to areas; the catalog's section headings are the nearest (inference: SA and SO span areas).
- `src/OcuPilot/Screen/Descriptor/Base.cls` (fields lines 14-39, `toolIdentifier` line 46, `CLASSICPAGES` line 64) and `src/OcuPilot/Screen/Registry.cls` (`Validate`, line 160) -- one descriptor, validated; `ui/tools/screen-mirror.mjs` generates `ui/src/app/core/screens.generated.ts` (`--check` in `prebuild`).
- Read tool: `src/OcuPilot/Screen/Tool/Registry.cls` (lines 11-17: `<toolIdentifier>.read` per descriptor that declares a read), answered by `src/OcuPilot/Screen/Tool/Read.cls`; `src/OcuPilot/Screen/Read.cls` is the one executor (AD-36).
- Write tools: `src/OcuPilot/Screen/Tool/Write.cls` (`PORTCLASS` line 114, AD-52); field lists via `ui/tools/field-lists.mjs` into `Screen/Tool/ToolFields.cls` (AD-3); proposal `src/OcuPilot/Kernel/Proposal/Mint.cls`, `Confirm.cls`; prohibited set `src/OcuPilot/Kernel/Proposal/Prohibited.cls` (AD-10); baseline `src/OcuPilot/Kernel/Governance/Baseline.cls` (AD-22).
- Rosters that hold every screen: `src/OcuPilot/Test/SurfaceCoverage.cls`, `EndpointCoverage.cls`, `SaveHoldCoverage.cls`, `GovernanceBaseline.cls`; client `ui/tools/navigation.test.mjs`, `ui/tools/classic-links.mjs`.
- Worked example to cite: License servers (Story 18.6) -- `Screen/Descriptor/LicenseServerList.cls`, `LicenseServerForm.cls`, `Area/OsMgmt/LicenseServerSave.cls`, `Screen/Tool/LicenseServerCreate.cls`, `Update.cls`, `Delete.cls`, through `src/OcuPilot/Port/AdminPort.cls`.

## Tasks & Acceptance

**Execution:**

- `docs/exclusion-register.md` -- insert `## Picking up a row` between the opening and `## Gate kinds`, with `### Assess the gate first`, `### When the gate has not cleared`, `### When the gate has cleared`, in that order. Assess names the `Gate kind`, `Gate` and `How to tell it has cleared` columns and points at the Gate kinds table. Refuse says the answer quotes the row's `Gate` and what its `How to tell it has cleared` check read, and that nothing changes. Build covers, briefly and by path: the request's record and re-tier (Always), the owning area and slice (none owns it: amend the spine first), one descriptor and its classic page (AD-5, AD-44), the derived read tool (AD-36), confirmed write tools through the proposal path with their declared port and baseline lines (AD-3, AD-6, AD-15, AD-22, AD-52, AD-53), the port (AD-27 for OS-31, OS-32, SA-50; AD-62, AD-65; a new outside system is a new port, spine first, AD-29), a license, edition or platform gate the descriptor cannot declare per screen (spine first), new strings in EXPERIENCE.md first, and the four rosters, citing the License servers example. Add a third column `How a request checks it` to the Gate kinds table, one sentence per kind; point lines 22-23 at the new section. Cite every file by its full repository path.
- `ui/tools/exclusion-register.test.mjs` -- add `parsePickUp()` (the section's `###` subsections) and tests: placement and step order; assess names `REGISTER_COLUMNS` 3-5 and refuse names 4-5, each as a backticked column name (a bare `Gate` would match `Gate kinds`); every kind's check cell non-empty, the license, edition and platform cells naming "the instance the request is for"; every backticked path under `src/ ui/ docs/ scripts/ _bmad-output/` exists; the build step names each file of a `CONTRACT_PATHS` roster (the Code Map's descriptor base, registry, area, mirror, read-tool registry, write base, prohibited set, baseline and the four test classes). Update the header comment.

**Acceptance Criteria:**

- Given a request for an excluded row, when the procedure is read, then its first step checks the row's recorded gate through the register's columns and the Gate kinds table, and says nothing is built before the gate reads cleared (AC1); `exclusion-register.test.mjs` fails if the step is missing, out of order or omits a column.
- Given a gate that has not cleared, when the request is answered, then the answer names the gate and what its check read, and the row stays; a row removed from the register while the catalog still reads P4 reddens 22.1's row-set test (AC3).
- Given a gate that has cleared, when the row is built, then the procedure puts it in the slice that owns its area as one descriptor with its derived read tool and confirmed write tools, names each by an existing path, and names the rosters that already hold every screen to that contract (AC2).
- Given the change, when `bash scripts/lint-docs.sh` and `node tools/client-lint.mjs` run, then both pass, and the story's diff, this spec aside, touches only the register and its test.

## Spec Change Log

## Review Triage Log

## Design Notes

**Architecture decisions.** FR-80 and the Design Paradigm (one slice per area, never reaching into another) govern a pick-up; the spine gives Stage 6 no AD. The procedure cites AD-5, AD-3, AD-6, AD-8 (privilege set), AD-10, AD-15, AD-22, AD-27, AD-29, AD-36, AD-44, AD-52, AD-53, AD-62, AD-65. No AC contradicts an AD.

**Integration ACs.** No service is introduced. Consumes: Story 22.1's register (a row's `Gate kind`, `Gate` and `How to tell it has cleared`, which the assess and refuse steps quote; the test derives those names from `REGISTER_COLUMNS`, so renaming a column reddens both). Consumed-by: none yet; the first real pick-up story will follow it.

**Extend, don't copy (Rule 31).** Extends 22.1's register and test; no new file.

**What can be verified here.** No request exists, so no row is built. AC2's outcome on a real row is observed at its pick-up, by the rosters the procedure names, which apply to every descriptor already and need no change. In this story AC2 is verified as the build step naming the contract by existing paths, held by tests.

**Decided in-stage:**

- Record of a request: a new sprint change proposal written by `bmad-correct-course`, the change record the project already uses (`_bmad-output/planning-artifacts/sprint-change-proposal-2026-09-16.md` shows its form; the procedure must not name that dated file as the place a new request goes), because re-tiering the catalog is a planning change anyway. A refusal is recorded nowhere: the register already holds the evidence.
- Where a gate is checked: on the instance the request is for. Where its check fails elsewhere, the pick-up story decides how the screen behaves; the procedure prescribes no behavior.
- Baseline values: the procedure cites AD-22 and FR-80 and leaves each key's value to the pick-up story, without restating a default. (inference) FR-80 says a later stage's destructive action is absent from the baseline, while AD-22 as amended and `GovernanceBaseline.cls` require every key to have a line; not this story's to resolve (lead, spec gate: confirmed against both texts and ledgered as DW-2558, routed outside this epic).
- Placement before `## Gate kinds`: 22.1's register parser has no end bound.
- Concurrency: `origin/OCU-1-epic21` has no commit beyond the feature branch.
- Ledger inbox: none.

## Verification

**Commands:**

- `(loop)` `cd ui && node --test tools/exclusion-register.test.mjs` -- expected: all pass.
- `(loop)` `bash scripts/lint-docs.sh` -- expected: exit 0 (the register and this spec).
- `(loop)` `cd ui && node tools/client-lint.mjs` -- expected: exit 0.
- `(once)` `cd ui && npm run test:tools` -- expected: all pass.
- No ObjectScript sweep (no ObjectScript change); no browser spec; the full browser suite is left to CI.

**Shared surfaces:** the register's Gate kinds table (read only by `exclusion-register.test.mjs`). Every test added or changed passes on a fresh environment, in either order.

**Planned mutations (Rule 19), each reverted:**

- mutation: move `### When the gate has cleared` above `### Assess the gate first` -> the step-order test red.
- mutation: delete `How to tell it has cleared` from the refuse step -> the column test red naming the step.
- mutation: blank the `license` row's `How a request checks it` cell -> the kinds test red naming `license`.
- mutation: change a cited path to `src/OcuPilot/Screen/Registry2.cls` -> the path test red naming it.
- mutation: remove `src/OcuPilot/Test/SurfaceCoverage.cls` from the build step -> the contract test red naming it.
- mutation: delete the SA-50 register row -> 22.1's row-set test red naming SA-50 missing.
- mutation: change `## Gate kinds` to `####` -> `bash scripts/lint-docs.sh` exit 1.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
