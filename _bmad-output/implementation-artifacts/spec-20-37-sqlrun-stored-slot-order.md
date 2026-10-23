---
title: 'Story 20.37: SqlRun stored slot order'
type: 'bugfix'
created: '2026-10-22'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** Story 20.33 declared `Kind` between `Namespace` and `State` on `Kernel/State/SqlRun`, whose source carries no Storage section, so each compile numbers the data slots by declaration order and an update from release 1.0.12 shifts `State` through `Answer` by one slot. A background run saved under 1.0.12 then reads its old state as `Kind` and its old job id as `State`: its owner's poll answers 404 and no sweep ever removes it (DW-2500, found by the 1.0.13 upgrade check).

**Approach:** Declare `Kind` after `Answer`, so `RunKey` to `Answer` keep release 1.0.12's slots 1-10 and `Kind` takes slot 11. A 1.0.12 row has no slot 11, and every reader of `Kind` already treats an empty one as `sql`. One test method pins the compiled slot order.

## Boundaries & Constraints

**Always:**

- The fix is declaration order only: `Kind`'s doc comment and declaration move to directly after `Answer`. Nothing else in product code changes, including the code that reads and writes `Kind`.
- The compiler owns the slot order: the source never carries a Storage section (Consistency Conventions: Collections; New properties on a stored class).
- `SCHEMAVERSION` stays 1 (Design Notes).
- Existing test methods stay as they are and pass unchanged.

**Never:**

- No migration, install step, sweep or hand edit for stored rows, on any instance. No change to `Install/*`, the readers of `Kind`, the indexes, `SCHEMAVERSION`, `epics.md`, the spine, `ui/**` or the CI files.
- No new test class: `SqlRunStore` gains one method (Design Notes, Decided in-stage).
- Not DW-2501's general stored-order check (backlog, not owned here).

## I/O & Edge-Case Matrix

Rows run on `ocupilot-b-ci` after the whole `src` tree is loaded (Verification, Setup).

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Fixed compile | `Kind` declared after `Answer`, loaded over the throwaway's 20.33 compile (`Kind` at slot 4) | Compiled `SqlRunDefaultData`: 1 `RunKey`, 2 `UserName`, 3 `Namespace`, 4 `State`, 5 `JobId`, 6 `CancelRequested`, 7 `QueuedAt`, 8 `StartedAt`, 9 `EndedAt`, 10 `Answer`, 11 `Kind` | - |
| 20.33's order | `Kind` declared between `Namespace` and `State` again (the mutation) | Slot 4 reads `Kind`; the slot test is red | - |
| A row with no `Kind` | A live SQL run whose `Kind` is NULL, as slot 11 of a 1.0.12 row reads | Its owner finds it as `sql` and not as `mdx`; a second SQL reserve names it busy | - |

</intent-contract>

## Code Map

All paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-20`. Lines were read at `8558e9e265a3858770fca566a672cbcb882b6fa5`.

- **`src/OcuPilot/Kernel/State/SqlRun.cls`** (485 lines; extends `Kernel/State/Base`; no class extends it):
  - Class doc :6-10 ("A row stored before Kind existed reads as KINDSQL"); `KINDSQL` :37.
  - `Namespace` :56-57; **`Kind` doc and declaration :59-60**; `State` :62-63; `Answer` doc and declaration :79-83; indexes :85-87 (`RunKey`, `UserName`; none on `Kind`).
  - Readers of `Kind`, all unchanged: `GuardedReserve`'s ended-row delete :136 (`COALESCE(Kind, 'sql')`) and its insert :141; `Reconcile` :383 (`""` reads as `KINDSQL`); `IdForOwner` :434 (`COALESCE(Kind, 'sql')`), reached by `GuardedCancel` :250 and `GuardedViewForOwner` :291. `GuardedSweep` :334-357 selects by `State` and `EndedAt` only. No other class queries the table.
- **Release 1.0.12** (`release/1.0.12`, `ce5f1bd2`): the same class declares `RunKey` to `Answer` at :39-69, with no `Kind`.
- **Measured, read-only, on `ocupilot-slot-b`**, whose `SqlRun` defines no `Kind`: `%Dictionary.CompiledStorageDataValue` and `StorageDataValueDefinition` under `OcuPilot.Kernel.State.SqlRun||Default||SqlRunDefaultData` both hold 1-10 = `RunKey` to `Answer`. The compiled storage also holds the inherited `BaseDefaultData` (`%%CLASSNAME`, `RowVersion`); data location `^OcuPilot.Kernel.State.BaseD`, subscript `"SqlRun"`.
- **`src/OcuPilot/Kernel/State/Propose.cls`** :220-222: the sibling doc wording for a property declared last. `Turn.cls` :123-125: the sibling "Added with no `SCHEMAVERSION` move" paragraph.
- **`src/OcuPilot/Test/SqlRunStore.cls`** (366 lines; unarmed; `ui/tools/ci-timings.json` :570, 0.6 s): header :1-11; `STORE` :15; each test clears its probe owners' rows before and after. `TestLookupsMatchTheKindAndARowWithNoKindReadsAsSql` :339-364, with its no-kind leg at :356-359.
- **`src/OcuPilot/Test/ProposalTargetKey.cls`** :304-318, `TestARowStoredBeforeTheKeyKeepsEachColumnInItsSlot`: the slot-reading idiom this story copies. The class is armed by `OCUPILOT_ALLOW_PRODUCTION_INSTALL` (:15).
- **`src/OcuPilot/Install/Installer.cls`** :81: `SCHEMAVERSION` = 1, unchanged.
- **Other classes that use the store**, run unchanged (`(once)`; seconds from `ci-timings.json`): `SqlBackgroundRoutes` 3.5, `SqlBackgroundJob` 12, `Retention` 5.6, `ClassicPageGate` 19.7, `AnalyticsMdxJob` 25.9, `AnalyticsMdxRoutes` 23, `AnalyticsMdxGate` 5.3 and `AnalyticsMdxRead` 9.9. All but the first two are armed by `OCUPILOT_ALLOW_PRINCIPALS`.

## Tasks & Acceptance

**Execution:**

- [ ] **Task 0 (measure; no product code).** Confirm that `git rev-parse --show-toplevel` prints `/Users/jbrandt/git/OcuPilot/.worktrees/epic-20`. On `ocupilot-b-ci`, before any edit, read `SELECT Name, Value FROM %Dictionary.CompiledStorageDataValue WHERE parent = 'OcuPilot.Kernel.State.SqlRun||Default||SqlRunDefaultData'`. Expected: `Kind` at slot 4 (20.33's order), under that storage and data name. A different name or order halts the stage with the evidence.
- [ ] **`src/OcuPilot/Kernel/State/SqlRun.cls`** (DW-2500): move `Kind`'s doc comment and declaration (:59-60) to directly after `Answer` (:83), before the indexes. The declaration is unchanged. Its doc gains two short paragraphs:
  - it is declared after every other property, and a later one goes after it, because the class carries no Storage section (Propose :220-222's wording);
  - it was added with no `SCHEMAVERSION` move, because a row stored before it reads it back empty, which every reader treats as `KINDSQL`.

  Nothing else in the file changes.
- [ ] **`src/OcuPilot/Test/SqlRunStore.cls`** (AC1): add `TestARunStoredBeforeKindKeepsEachColumnInItsSlot`, in `ProposalTargetKey`'s idiom. It opens slots 1 to 11 of `..#STORE _ "||Default||SqlRunDefaultData||" _ slot` from `%Dictionary.CompiledStorageDataValue` and compares them, in one assertion, with the literal list `RunKey` to `Answer`, then `Kind`. A slot after 11 is not checked. Its doc names the convention and its mutation. The class header gains "and the data slots a row stored by release 1.0.12 is read from (Story 20.37)".
- [ ] Load, run and mutate as `## Verification` says, and record each mutation there.

**Acceptance Criteria:**

- **AC1 (the slots).** Given `SqlRun.cls` with `Kind` after `Answer`, loaded with the whole `src` tree on `ocupilot-b-ci`, when `TestARunStoredBeforeKindKeepsEachColumnInItsSlot` reads the compiled storage map, then slots 1-10 of `SqlRunDefaultData` are release 1.0.12's (`RunKey`, `UserName`, `Namespace`, `State`, `JobId`, `CancelRequested`, `QueuedAt`, `StartedAt`, `EndedAt`, `Answer`) and slot 11 is `Kind`.
- **AC2 (a row stored before `Kind` reads as SQL, so no migration).** Given a live SQL run whose `Kind` reads empty, as a 1.0.12 row's slot 11 does, when its owner looks it up and reserves another SQL run, then it is found as a SQL run, not as MDX, and named busy. The pin is `TestLookupsMatchTheKindAndARowWithNoKindReadsAsSql`, unchanged and green.
- **AC3 (nothing else changes).** Given the story's diff from its `baseline_revision`, when it is listed, then:
  - the only product change is in `SqlRun.cls` (`Kind`'s block moved, its doc grown);
  - `SqlRunStore.cls` gains one method and the header phrase, and no existing test method changes;
  - every class in the `(once)` batch passes.
- [ ] **DW-2500** (ledger; routed by load 2026-10-23): `Kernel/State/SqlRun` declares `Kind` between `Namespace` and `State` with no source Storage section, so an update from 1.0.12 shifts stored slots 4-10 and a pre-update background run reads 404 and is never swept. The `SqlRun.cls` task and AC1 close it. The orchestrator's 1.0.13 upgrade re-check is its end-to-end proof.

## Spec Change Log

## Review Triage Log

## Design Notes

**Why moving the declaration is the whole fix.**

- **What a 1.0.12 row reads after the fix.** Its list ends at slot 10, so every column reads where 1.0.12 wrote it. `Kind`, slot 11, reads empty: SQL NULL, and `""` through the object. Every reader already maps that to `sql` (`COALESCE(Kind, 'sql')` at :136 and :434, and `Reconcile` :383; AC2 pins it). No index covers `Kind`, and the sweep reads only `State` and `EndedAt`. So the run answers its owner's poll and is swept 900 s after it ends.
- **The 1.0.12 layout is measured twice:** the release's declared order, and `ocupilot-slot-b`'s compiled map (Code Map).
- **The load regenerates the map from declaration order.** Story 20.31's rework measured it on this throwaway (the spine's Conventions row), and the 1.0.13 upgrade check measured it on an update from 1.0.12 (DW-2500's evidence). The IPM path compiles from the same source, so the same holds there (inference).

**Rows written in 20.33's order.**

- **Where they are.** Only code since Story 20.33 writes them, so only development instances and throwaways hold them. Measured: 20.33 (`70125af9`) is not in `origin/main`, and no release branch after `release/1.0.12` exists.
- **How they read after the fix.** Such a row's `State` holds its kind (`sql` or `mdx`). No reconcile, reserve or sweep selects that value, so the row stays and is inert: it is never live and never counted against a cap (inference, from the code).
- **No migration is planned.** The owner's charter is the move, and a data change on a shared development instance is the owner's call.
- **For the lead:** `epic-20-context.md` :57 says such rows are swept 900 s after they end (inference). By the reading above they are not, so correct that line at its origin.

**`SCHEMAVERSION` stays 1** (Conventions: when `SCHEMAVERSION` moves). No stored row's meaning changes: a 1.0.12 row reads every column as written, and reads `Kind` as the safe default `sql`, the case that row names (`RowVersion`, `CredentialCreated`). `Kind`'s doc comment records this, as `Turn.Workflow`'s does.

**Governing ADs and conventions (Rule 6).**

- **Conventions:** *New properties on a stored class* (the rule this story restores); *When `SCHEMAVERSION` moves*; *Collections* (no hand-written Storage section); *Tests* (no test depends on another).
- **AD-17 and AD-38:** upgrade is install again, on a populated instance, so a row saved before the update must read after it.
- **AD-37:** the retention sweep is the declared lifecycle that a stranded row escapes.
- **AD-41:** background runs and their kind. The clause is unchanged.
- **AD-9:** the store stays on `Kernel/State/Base`, and its globals do not move.
- **Checked and not engaged:** AD-18 (IPM, covered above), AD-7 (no turn), and the spine's DW-2456 ruling (no index changes).

**Decided in-stage.**

- **The compiled dictionary, not the definition.** The test reads `%Dictionary.CompiledStorageDataValue`. It exists only after a successful compile, and it is the map the class's generated load and save code uses. The definition copy is the compiler's write-back, which the load replaces from a source that has none. The two are equal after a good compile (measured on `ocupilot-slot-b`), and the sibling reads the compiled one.
- **A prefix, not an exact count.** The test checks slots 1-11 by name. A property appended later takes slot 12 and needs no edit here, while any insertion before `Kind` turns the test red.
- **The host is `SqlRunStore`, not a new class.** It is the store's own test class, unarmed and already sharded, so no `ui/tools` roster file changes and CI runs the method with its class. `ProposalTargetKey`, the storage sibling, belongs to the proposal store and is armed for a production install.
- **A copy of the idiom (Rules 2 and 31).** The method repeats `ProposalTargetKey`'s six-line slot loop. A shared helper would tie the SQL run store's tests to the armed proposal class, and two short copies read better. DW-2501's general check (backlog) is where a shared form would live (inference).
- **No hand-built 1.0.12 row.** Building a row in the shared `Base` global, with its index entries, is fragile. AC1 and AC2 cover the two halves, and the orchestrator's upgrade re-check from `release/1.0.12` is the end-to-end proof.
- **The consumer batch runs `(once)`.** The slot test is the story's own, and the runner's full sweep repeats the batch.

**Integration (Rule 1), Consumes and Consumed-by (Rule 2).** A defect fix to an existing class: no service, module or shared component is introduced. Consumes: release 1.0.12's stored layout. Consumed-by, unchanged: the SQL console's background runs (Story 19.15), MDX query's runs (Story 20.33), and the 1.0.13 upgrade re-check.

**Ledger inbox (Rule 17).** DW-2500 is addressed by the `SqlRun.cls` task and AC1 (`owned_ledger=1`).

**Rule 11.** The footprint is `SqlRun.cls` and `SqlRunStore.cls`. Relative to feature, `origin/OCU-1-epic23` (`40de2a58`) changes neither of them, nor `ui/tools/ci-timings.json` or `ci.test.mjs`. No footprint extension.

**Context.** Of the 21 `%Persistent` classes under `src/OcuPilot`, all in `Kernel/State`, `SqlRun` is the only one whose release 1.0.12 declared order is not a prefix of its current one. This is a source-level check; `Propose.TargetKey` and `Turn.Workflow` were appended.

## Verification

Shared surfaces: `SqlRun`'s compiled storage map. No other test reads it: `State`, `AgentSchema` and `AnalyticsMdxRoutes` read the shared `^OcuPilot.Kernel.State.Base*` locations, which do not move.

*Every test added or changed passes on a fresh environment, in either order.* The slot test reads the dictionary and writes nothing.

**Setup (slot B; never the dev instance `ocupilot-slot-b`):**

- `(loop)` **Load `src`:** `rsync -a --checksum --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-20/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`, then in `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`: `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)`.

**Commands.** Run each in the foreground with `timeout: 600000`, one at a time. Read each class's result from `%UnitTest_Result`; `ci-runner` confirms it.

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.SqlRunStore`. Expected: green, with the new method.
- `(loop)` `cd ui && npm run test:tools`. Expected: green. `epics.md` gained 20.37's block, and suites cite it by line.
- `(loop)` `uv run scripts/check-objectscript.py src/OcuPilot/Kernel/State/SqlRun.cls src/OcuPilot/Test/SqlRunStore.cls`, then `bash scripts/lint-docs.sh`. Expected: clean.
- `(loop)` `git diff --stat` against this spec's frontmatter `baseline_revision` (recorded by the implement stage). Expected: `SqlRun.cls`, `SqlRunStore.cls` and this spec only (AC3).
- `(once)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.SqlBackgroundRoutes --class OcuPilot.Test.SqlBackgroundJob --class OcuPilot.Test.Retention --class OcuPilot.Test.ClassicPageGate --class OcuPilot.Test.AnalyticsMdxJob --class OcuPilot.Test.AnalyticsMdxRoutes --class OcuPilot.Test.AnalyticsMdxGate --class OcuPilot.Test.AnalyticsMdxRead` (about 105 s in `ci-timings.json`). Expected: green.
- **Lead-owned (the runner's):** the full ObjectScript sweep, `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`, and Rule 30's fresh check.
- **Left to CI:** the full browser suite (no client change).
- **After the merge (the orchestrator's):** the 1.0.13 upgrade re-check from `release/1.0.12`.

**Pinning mutations (Rule 19),** each on `ocupilot-b-ci`: apply it, reload the whole `src` tree, see the named test red, revert with the file's git blob hash equal before and after, reload, see it green.

| AC | Mutation | Red |
|---|---|---|
| AC1 | `Kind` declared between `Namespace` and `State` again | `TestARunStoredBeforeKindKeepsEachColumnInItsSlot`, alone in its class |
| AC2 | `IdForOwner`'s statement compares `Kind = ?` without `COALESCE` | `TestLookupsMatchTheKindAndARowWithNoKindReadsAsSql` ("reads as SQL") |
| AC3 | None: a scope criterion, checked by the diff | - |

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Planned only (halt after planning). The spec moves `Kind` after `Answer` in `Kernel/State/SqlRun.cls` and pins slots 1-11 with one method in `Test/SqlRunStore.cls`, so no roster file changes. `SCHEMAVERSION` stays 1. DW-2500 is addressed. Nothing was created or changed on any instance; the `ocupilot-slot-b` probes were read-only.
