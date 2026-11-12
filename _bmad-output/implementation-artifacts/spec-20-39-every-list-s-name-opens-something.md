---
title: "Story 20.39: Every list's name opens something"
type: 'bugfix'
created: '2026-11-12'
status: 'done'
baseline_revision: 'a87ff13cb6914ba63c42f45b493a8b64ce3ec55b'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** Story 20.38's link check holds an exact allow-list of 17 lists whose name links back to the list itself, so a click changes the address and the page stays put. The cause is the last arm of `nameLinkTarget`: a top-level list that pairs nothing links its name to its own id route.

**Approach:** Three lists whose rows are an entity with its own screen get a `rowTarget` to that screen: On-demand tasks and Upcoming tasks open Task details, and the Databases Free-space view opens Database details. The last arm of `nameLinkTarget` links a list to itself only for the five lists whose page opens a dialog at their own id route. Every other list that pairs nothing draws its name as plain text. The allow-list is deleted, and the check still fails on any new self-link.

## Boundaries & Constraints

**Always:**

- Links come from existing grammar only: `rowTarget` (AD-5) and the existing chain. `Registry.cls` and `screen-mirror.mjs` get comment edits only (DW-2504), and no validator or key changes.
- A list's own id route keeps selecting its row (ListPage `selectFromRoute`), and the agent's and change toasts' links are unchanged.
- The Design Notes table is the outcome for each list. A list with more than one plausible target renders plain text unless the table gives a reason for a target.
- Every changed doc comment states the contract only (Rule 14).

**Never:**

- No new screen, string, descriptor key, AD amendment, stored data, installer, write or agent tool.
- No change to the five dialog lists' behavior, or to any list that already links elsewhere.
- No change to `id` declarations.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| A task row | On-demand tasks or Upcoming tasks: click a task's Name | Task details at `tasks/schedule/details/<Id>`, with `?ns=` kept | - |
| A database row | Databases, Free-space view: click a Directory | Database details at `os-management/databases/details/<Directory>` | - |
| Nothing to open | Allowed directories: click a Directory | The cell is text with no link. The click selects the row, and the address does not change. | - |
| A dialog list | Task history: click a Name | The row's dialog opens, as before | - |
| A new list that pairs nothing | A top-level list that is not declared in either dialog set | Its name is text, and `name-links.test.mjs` stays green | - |
| A new self-link | A descriptor added to a dialog set, or a `rowTarget` naming the list itself | `name-links.test.mjs` goes red naming it, and the mirror refuses the `rowTarget` | Red test |

</intent-contract>

## Code Map

Paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-20`, and lines were read at `04efee338c3eaca2fd2da015187fe03a9617fe91`.

- `ui/src/app/core/navigation.ts`: `DIALOG_EDITORS` (:289), `rowTargetScreenFor` (:388), `nameLinkTarget` (:414; the fallback is :423 `(screen.parentScope === '' ? screen : null)`), `hasIdRoute` (:705).
- `ui/src/app/shell/data-table.ts` :671-702: draws a link only when `nameLinkTarget` answers a target with an id route. Otherwise it draws a `.ocu-data-table-text` cell. It is not edited.
- `ui/tools/name-links.test.mjs`: `NON_DEFECTS` (:28), `STORY_20_39_ALLOW_LIST` (:41), the exact-set test (:76), the unbuilt-target control built from `AllowedDirectoryList` (:96), the disjoint test and its temporary count of 17 (:105-121).
- Row targets, placed after `table` and before `toolIdentifier` as in `LockList.cls` :99. `TaskOnDemandList.cls` and `TaskUpcomingList.cls` both read `Id`, as `TaskDetails` (`tasks/schedule/details`, id `[Id]`) does. `DatabaseFreeSpace.cls` reads `Directory`, as `DatabaseDetails` (`os-management/databases/details`, id `[Directory]`) does. No built screen pairs a surface with any of the three routes (measured), so `rowTargetResolutionProblem` (`screen-mirror.mjs` :3023) admits each. `DatabaseFreeSpace.cls` :37-44 says a `rowTarget` is unavailable and that the name cell resolves to its own route. Both claims become false.
- The pages behind the five self-links: `AuditPage` (`audit.page.ts` :296-318, the detail dialog at the id route), `JournalRecordsPage` (:391), `HistoryPage` (:220), and the dialog editors' `ResourceListPage` and `AuditUserEventListPage`.
- The test fixture `ui/src/app/testing/table-declaration.ts` declares `TableProbe` at `web-applications/probe`, in no set. Tests that need its self-link: `data-table.spec.ts` :179 and :888, and `browser/data-table.browser-spec.mjs` :338 (the harness in `src/app/testing/table-harness/main.ts` :69, built by `ng build --configuration production,harness`). `app.routes.spec.ts` :211 shows how a test reads a set member: `[...DIALOG_EDITORS]`.
- Specs that click these lists' name cells (the sweep finds the rest). `browser/task-run.browser-spec.mjs` :219 `clickRowCentre(page, { text: taskName })` selects an On-demand row through its name cell, which will now navigate away. Browser specs that name the 17 routes: `system-explorer`, `-editor`, `-find`, `-documatic`, `permissions-sql-privileges`, `web-applications-class-access`, `auditing-screen`, `audit-events`, `allowed-directories`, `allowed-directory-write`, `databases`, `panel`, `screen-height`, `ecp-application-servers`, `tasks`, `task-run`, `csv-download`, `background-tasks`, `database-operations`, `system-explorer-docdb`, `interop-lookup-tables`, `analytics`, `screen-permissions` and `screen-permissions-agent`.
- DW-2504's stale "paired-surface chain in data-table.ts" comments: `Registry.cls` :4040-4041, `Descriptor/Base.cls` :338, `Descriptor/LockList.cls` :19, and `screen-mirror.mjs` :2860 and :4020. The :4020 comment is emitted into `screens.generated.ts`.
- EXPERIENCE.md :98 (Database details "Databases name cell") and :103 (Task details "Task schedule name cell"): where each screen is reached from.

## Tasks & Acceptance

**Execution:**

- `ui/src/app/core/navigation.ts`:
  - Add `DETAIL_DIALOG_LISTS`, exported beside `DIALOG_EDITORS`, with `AuditList`, `JournalRecordList` and `TaskHistoryList`. Its doc comment: lists whose page opens the row's detail dialog at the list's own id route.
  - Change the last arm of `nameLinkTarget` to `screen.parentScope === '' && (DIALOG_EDITORS.has(d) || DETAIL_DIALOG_LISTS.has(d)) ? screen : null`.
  - Rewrite the doc comment's "otherwise the list's own route" clause to say that this arm holds only for those lists and that every other list draws text.
- `src/OcuPilot/Screen/Descriptor/TaskOnDemandList.cls` and `TaskUpcomingList.cls`: `"rowTarget": {"route": "tasks/schedule/details", "field": "Id"}`.
- `src/OcuPilot/Screen/Descriptor/DatabaseFreeSpace.cls`: `"rowTarget": {"route": "os-management/databases/details", "field": "Directory"}`. Replace :37-44 with one contract sentence: the name cell opens Database details through this row target, as the General view's does.
- DW-2504, comment-only. In the five sites in the Code Map, "the paired-surface chain in data-table.ts" becomes "the paired-surface chain in `nameLinkTarget` (`ui/src/app/core/navigation.ts`)". Then regenerate `ui/src/app/core/screens.generated.ts` with `cd ui && node tools/screen-mirror.mjs`, and never hand-edit it.
- `ui/tools/name-links.test.mjs`:
  - Delete `STORY_20_39_ALLOW_LIST` and its count assertion. `NON_DEFECTS` becomes the five dialog lists, each with its reason. `LicenseKey` and `OpenApiViewer` leave it.
  - The exact-set test asserts `selfLinking()` equals `NON_DEFECTS`. It also asserts `DIALOG_EDITORS ∪ DETAIL_DIALOG_LISTS` equals `NON_DEFECTS`' keys, so that a member added to a set needs a reason added here.
  - Add a test with one row per list in the Design Notes table: the route `nameLinkTarget` answers, or text (`null`, or a target with no id route).
  - Add a control test: a copy of a declared top-level list, under a probe descriptor and route and in no set, answers `null`.
  - Rebuild the unbuilt-target control from a member of `DETAIL_DIALOG_LISTS`, because `AllowedDirectoryList` no longer links.
- `ui/src/app/shell/data-table.spec.ts`, `list-page.spec.ts`, `command-bar.spec.ts` and the table harness `main.ts`:
  - A test that asserts the probe's name link builds the probe with `descriptor` set to `[...DETAIL_DIALOG_LISTS][0]`.
  - Add an `it` showing the probe under its own descriptor: the name cell is `.ocu-data-table-text` with no `a`, and a click selects the row without navigating.
- Shared-surface sweep (Rule 30):
  - Grep `ui/browser`, `ui/tools`, the `ui/src` specs and `src/OcuPilot/Test` for the 17 routes and descriptors, and for the probe route.
  - Fix any name-cell click that expects to stay on the list. The fix clicks a non-name cell (`cell: <n>`), as `tasks.browser-spec.mjs` :895 does. Fix any `.ocu-data-table-link` or `link: true` expectation on a list that is now text.
  - Every changed file joins the `(loop)` set. Before changing a file Epic 23 has changed, apply the contention check in Design Notes.
- `ui/browser/databases.browser-spec.mjs`: add a test. On the Free-space view, clicking a database's Directory lands on `os-management/databases/details/<encoded Directory>` with Database details showing.
- `ui/browser/tasks.browser-spec.mjs`: add a test. Clicking the demo task's Name on On-demand tasks lands on `tasks/schedule/details/<Id>` and shows Task details. Clicking the first row's Name on Upcoming tasks does the same for that row's task, at the horizon whose rows the existing "Story 6.5 AC3" test reads.
- `ui/browser/allowed-directories.browser-spec.mjs`: add a test. A Directory name cell holds no `.ocu-data-table-link`, and clicking its center selects the row and leaves `location.pathname` unchanged.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`, edited in place with no line added:
  - :103 reads "Task schedule name cell · On-demand tasks and Upcoming tasks name cells · agent navigation (UJ-6) [AMENDED 2026-11-12 - Story 20.39]";
  - :98 reads "Databases name cell, in either view [AMENDED 2026-11-12 - Story 20.39]".

**Acceptance Criteria:**

- **AC1.** Given each list in Story 20.38's allow-list, when its name is clicked, then it opens the screen the Design Notes table names, or the name is plain text, and the click selects the row and leaves the address unchanged.
- **AC2.** Given `name-links.test.mjs`, when `npm run test:tools` runs, then no allow-list exists, and the lists linking to themselves are exactly the five dialog lists. A new self-link, from a dialog-set member with no declared reason or from an unpaired list linking to itself, turns it red.
- **AC3.** Given Resources, User events, Audit, Journal records and Task history, when a row's name is clicked, then its dialog opens as before.
- **AC4 (DW-2504).** Given the five comment sites, when they are read, then each places the chain in `nameLinkTarget` in `navigation.ts`, and `screens.generated.ts` matches the regenerated mirror.

## Spec Change Log

## Review Triage Log

### 2026-11-12 - Review pass

- verdicts: 11 findings - high 0, medium 0, low 11, false 0, maybe-false 0
- findings:
  - `[low]` `patch` The `TableProbe` marker in `build-output.test.mjs` "no harness code reaches the shipped bundle" can no longer fail, because the fixture's default descriptor is now `AuditList` - marker changed to the fixture's route `web-applications/probe`, shown present in a harness build and absent from the production build.
  - `[low]` `patch` The Free-space browser test could read General's rows before the Free-space view drew - it now waits for the Disk free column header, which only the Free-space view draws; the spec passes.
  - `[low]` `reject` The databases and tasks browser mutations are combined with the old last arm - the `rowTarget`-only isolation is the per-list row in `name-links.test.mjs`, recorded in the mutation lines.
  - `[low]` `reject` AC3 has a mutation line for `TaskHistoryList` only - the exact-set test reddens for any set member removed, and the other four lists' browser specs are unchanged.
  - `[low]` `reject` The `SQL_SCHEMAS` assertion duplicates the exact-set test - no user-reachable harm.
  - `[low]` `reject` `tableDeclaration()`'s default reads the first set member - every member links to itself, so any order serves.
  - `[low]` `reject` The Allowed-directories address assertion is read right after the selection appears - the zero-link assertion carries the test and runs after the rows are drawn.
  - `[low]` `reject` Intent audit: no test for a `rowTarget` naming the list itself - `rowTargetResolutionProblem` already refuses a route that names no other declared screen, and `screen-mirror.test.mjs` pins it.
  - `[low]` `reject` Intent audit: resolver-level checks cover the other 13 former self-links - the intent's expectation for them is text, which `nameLinkTarget` answering `null` fully decides.
  - `[low]` `reject` Intent audit: the fixture default changed and `LicenseKey` and `OpenApiViewer` left `NON_DEFECTS` - both are stated in the spec's tasks.
  - `[low]` `reject` Intent audit: `app-upcoming-page` in `_components.scss` - the Upcoming table measured a zero-height viewport and no row was clickable; pinned by the Upcoming browser test's mutation.

## Design Notes

- **Governing ADs (Rule 6):** none is amended.
  - AD-5: the descriptor is the source of a screen's links. `rowTarget` is the cross-screen row link, resolved ahead of the paired-surface chain, and validated alike by `Registry.cls` and the mirror.
  - AD-13: a row target's field is encoded by the shared pair. A one-part composite id equals its value (`joinCompositeId`).
  - AD-19: client state lives in the store.
  - AD-44: a list archetype carries no classic link.
- **Decided in-stage (unattended):**
  - **Plain text without new grammar.** The spine names no "text" link option, and a new descriptor key would be new link grammar, which is the orchestrator's call. The chain therefore links a list to itself only where its page opens a dialog at that id route. These lists are named in client sets beside the existing `DIALOG_EDITORS`, which already declares, in the client, the lists whose name opens a dialog. The default becomes text, so a new list cannot self-link by accident. This is reversible inside the story.
  - **The rule for each row:** a name opens the screen of the row's own entity (its `entityType`). A row whose entity has no screen of its own renders text.
  - **Database free space** opens Database details, not text. EXPERIENCE.md :97 makes Free space a view of the Databases list, and :98 has Database details reached from the "Databases name cell". Both views draw on `DatabasesPage` and key rows by `Directory`. The Local databases editor belongs to another list.
  - **The allow-list is deleted,** not kept empty, together with its temporary count, as the test's own comment directs.
  - The link tests' fixture becomes a set member read from the export, not a literal.
- **The 17 lists:**

| # | List · name field | Now |
|---|---|---|
| 2 | `system-explorer/classes/document` · Name | text: a structure member has no screen |
| 3 | `system-explorer/routines/document` · Name | text, for the same reason |
| 4 | `permissions/sql-privileges` · Object | text (choice): a grant has no screen, and one row target cannot route across the mixed Types |
| 5 | `permissions/sql-column-privileges` · Column | text |
| 6 | `permissions/sql-admin-privileges` · Privilege | text |
| 7 | `web-applications/list/class-access` · Name | text (choice): a class-access rule has no screen |
| 8 | `security/auditing/system-events` · EventName | text |
| 9 | `security/allowed-directories` · Directory | text |
| 10 | `os-management/database-free-space` · Directory | Database details (choice, reason above) |
| 11 | `os-management/ecp-application-servers/ssl` · SSLComputerName | text |
| 12 | `tasks/on-demand` · Name | Task details, through `rowTarget` field `Id` |
| 13 | `tasks/upcoming` · Name | Task details, through `rowTarget` field `Id` |
| 14 | `tasks/background` · Task | text |
| 15 | `system-explorer/docdb` · Name | text (choice): a document database is not a namespace database |
| 16 | `interoperability/business-partners` · Name | text (choice): no partner screen exists |
| 17 | `analytics/folder-items` · Name | text (choice): the vendor pages are screen links, not row links |
| 18 | `agent/screenpermissions` · Screen | text (choice): a route is not an id, and Adjust is a row action |

- **Rule 31:** the new set extends `DIALOG_EDITORS`' precedent. The targets reuse `rowTarget` and its siblings `LockList` and `InteropJobList`. The tests extend `name-links.test.mjs`, `data-table.spec.ts` and the three browser specs.
- **Integration (Rules 1 and 2):** no service is introduced.
  - Consumes: Story 20.38's `nameLinkTarget` and link check.
  - Consumed-by: none.
- **Contention (Epic 23, read-only `git diff --stat origin/feature/OCU-1_ocupilot-mvp...HEAD` and `status -s` at plan time):**
  - Epic 23 has changed `structural-walk.mjs`, `panel-spec.mjs`, `protocol-retry.mjs`, `local-databases.browser-spec.mjs`, `BackgroundSeed.cls`, `BackgroundTasksLive.cls`, three tool tests and `epics.md`. No planned file is among them.
  - If the sweep must change one of those files, an add-only edit is fine. Anything else is `## Clarification Needed`.
  - The walk's id segments come only from links under a list's own prefix, which feed `parentScope` children. None of the 17 has one, so the walk needs no change.
  - Contended: none.
- **Ledger inbox (Rule 17):** DW-2504 is addressed by the DW-2504 task and AC4.
- **Upgrade triggers:** none.

## Verification

All runtime work targets the throwaway `ocupilot-b-ci` (52777), and every MCP call uses `ocupilot-slot-b`. Each call runs in the foreground and fits about 150 s. A longer run is started detached and supervised per common.md. Tests run one runner at a time.

**Shared surfaces:**

- the screen mirror (`screens.generated.ts`);
- `nameLinkTarget`'s answers for every list, together with every spec that clicks or asserts a name cell on the 17 lists or on the `TableProbe` fixture;
- `name-links.test.mjs`'s declared sets;
- EXPERIENCE.md :98 and :103 (in place).

Every test added or changed passes on a fresh environment, in either order.

**Commands:**

- (loop) `cd ui && node tools/screen-mirror.mjs`, then `git diff --stat` shows `screens.generated.ts` changed only where expected.
- (loop) `cd ui && npm run test:tools`: green, `name-links.test.mjs` included.
- (loop) `cd ui && npm run test:components`, detached if long: green.
- (loop) `cd ui && npm run build`, detached if long: the prebuild checkers pass, and the bundle stays under 2500 kB / 4000 kB (a crossing is reported, never re-based).
- (loop) Load `src` (`rsync` then `LoadDir`, per common.md) with `tErrors` 0. Then `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.Descriptor --class OcuPilot.Test.ScreenRead`: green.
- (loop) Redeploy the bundle (common.md). Then, one per call, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci`:
  - `node --test --test-concurrency=1 browser/databases.browser-spec.mjs`;
  - `browser/allowed-directories.browser-spec.mjs`;
  - `browser/task-run.browser-spec.mjs`;
  - `node --test --test-concurrency=1 --test-name-pattern="Story 20.39" browser/tasks.browser-spec.mjs` (the whole file is about 185 s, so it runs detached when the sweep changed other tests in it);
  - each spec file the sweep changed.
- (loop) `cd ui && npx ng build --configuration production,harness && node --test --test-concurrency=1 browser/data-table.browser-spec.mjs`: green (no instance needed).
- (loop) `uv run scripts/check-objectscript.py` reports 0 problems, and `bash scripts/lint-docs.sh` is clean.
- **Lead-owned:** the full ObjectScript sweep, the smoke and the Rule 30 fresh check. **Left to CI:** the full browser suite.

**Pinning tests and planned mutations (Rule 19; the implement stage records each `mutation:` line):**

- AC1, targets: the `tasks.browser-spec.mjs` and `databases.browser-spec.mjs` tests. Drop `TaskOnDemandList`'s or `DatabaseFreeSpace`'s `rowTarget`, regenerate, rebuild and redeploy, and its test goes red. The name-links per-list test goes red too.
- AC1, text: the `allowed-directories.browser-spec.mjs` test. Restore the old fallback, then rebuild and redeploy, and it goes red.
- AC2: `name-links.test.mjs`. Restore the old fallback, and the exact-set test goes red naming the lists that become self-links again. Add a descriptor to `DETAIL_DIALOG_LISTS`, and the set-equality assertion goes red.
- AC3: `tasks.browser-spec.mjs` "Story 6.6 AC3" (:816, run by name pattern) and the exact-set test. Drop `TaskHistoryList` from `DETAIL_DIALOG_LISTS`, and both go red.
- AC4: `screen-mirror.mjs --check` in the prebuild. Edit :4020 without regenerating, and the check fails.

**Mutations demonstrated (Rule 19; each reverted, tree byte-identical):**

- mutation: `name-links.test.mjs` exact-set and per-list tests. Restore the old last arm of `nameLinkTarget` (`screen.parentScope === '' ? screen : null`) -> both go red naming the lists that self-link again. `data-table.spec.ts` "Story 20.39: a list in no dialog set draws its name as text" goes red alone.
- mutation: `name-links.test.mjs` set equality. Drop `TaskHistoryList` from `DETAIL_DIALOG_LISTS` -> the exact-set test goes red; add `AllowedDirectoryList` to it -> the exact-set and per-list tests go red. `NON_DEFECTS` is a hand-written roster, so a set change alone cannot keep the test green.
- mutation: `name-links.test.mjs` per-list row. Delete `DatabaseFreeSpace`'s `rowTarget` and regenerate the mirror -> only the per-list test goes red, naming `os-management/database-free-space`.
- mutation: `allowed-directories.browser-spec.mjs` "Story 20.39 AC1" (old last arm, rebuilt and redeployed) -> red.
- mutation: `databases.browser-spec.mjs` and `tasks.browser-spec.mjs` "Story 20.39 AC1" (old last arm plus the three `rowTarget`s dropped, regenerated, rebuilt, redeployed) -> all three red. Combined with the old last arm, so the `rowTarget`-only isolation is the per-list row above.
- mutation: `tasks.browser-spec.mjs` "Story 6.6 AC3" (`TaskHistoryList` dropped from `DETAIL_DIALOG_LISTS`, rebuilt, redeployed) -> red.
- mutation: `tasks.browser-spec.mjs` Upcoming test, also the pin for the layout host. Remove `app-upcoming-page` from the host list in `_components.scss`, rebuilt, redeployed -> `clickRowCentre` fails: the table viewport measures `clientHeight` 0.
- mutation: `screen-mirror.mjs --check` (AC4). Edit the :4020 comment without regenerating -> "the checked-in mirror is stale".

**Decided in-stage:** `tableDeclaration()`'s default descriptor is now `[...DETAIL_DIALOG_LISTS][0]`, and `TABLE_PROBE_DESCRIPTOR` is the descriptor whose name is text. `app-upcoming-page` joins the host selectors in `_components.scss` that fill the outlet, because the Upcoming table measured a zero-height viewport and no row was clickable; the new Upcoming test needs it.

## Auto Run Result

Status: done
Blocking condition: none

Summary: the last arm of `nameLinkTarget` links a list to itself only for the five dialog lists (`DIALOG_EDITORS` plus the new `DETAIL_DIALOG_LISTS`); On-demand tasks and Upcoming tasks open Task details and Database free space opens Database details through `rowTarget`; every other unpaired list draws text. The allow-list is deleted. DW-2504's five comment sites now point at `nameLinkTarget`, and the mirror is regenerated.

Files changed:

- `ui/src/app/core/navigation.ts`: `DETAIL_DIALOG_LISTS` and the new last arm.
- `src/OcuPilot/Screen/Descriptor/TaskOnDemandList.cls`, `TaskUpcomingList.cls`, `DatabaseFreeSpace.cls`: `rowTarget`.
- `Base.cls`, `LockList.cls`, `Registry.cls`, `ui/tools/screen-mirror.mjs`, `ui/src/app/core/screens.generated.ts`: comment edits (DW-2504) and the regenerated mirror.
- `ui/tools/name-links.test.mjs`, `ui/tools/build-output.test.mjs`: the five-list roster, per-list outcomes, the control, and the harness marker.
- `ui/src/app/testing/table-declaration.ts`, `shell/data-table.spec.ts`, `shell/list-page.spec.ts`: fixture default and text-cell test.
- `ui/browser/databases`, `tasks`, `allowed-directories`, `task-run` browser specs: new and adjusted tests.
- `ui/src/styles/_components.scss`: `app-upcoming-page` joins the outlet-filling hosts (a zero-height Upcoming table made rows unclickable).
- `EXPERIENCE.md` :98 and :103: amended in place.

Review: 2 patches applied (harness marker, Free-space readiness wait), 9 rejected low findings with reasons in the triage log, nothing deferred. Follow-up review recommended: false.

Verification: `screen-mirror.mjs --check` up to date; `npm run test:tools` 2184 pass; `npm run test:components` 3346 pass; `npm run build` prebuild checkers pass, initial bundle 2.02 MB; Descriptor, ScreenRead, Navigation and TaskLists classes green on `ocupilot-b-ci`; browser specs databases, allowed-directories, task-run, tasks (whole file), audit-events, screen-height, permissions-sql-privileges, web-applications-class-access and data-table (harness) green; `check-objectscript.py` 0 problems; `lint-docs.sh` clean.

Residual risk: the full ObjectScript sweep, the smoke, the Rule 30 fresh check and the full browser suite are the runner's and CI's.
