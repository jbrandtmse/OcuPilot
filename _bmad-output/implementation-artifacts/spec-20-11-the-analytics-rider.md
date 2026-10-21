---
title: 'Story 20.11: The Analytics rider'
type: 'feature'
created: '2026-10-14'
status: 'done'
baseline_revision: '6a8fd1f06c43a82bf989f24990c3fa267a91cd62'
baseline_commit: 'f0a2e888a239e56e691b2686b998a6d0d40e6194'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: [oversized, multiple-goals]
deferred: []
---

<intent-contract>

## Intent

**Problem:** The Analytics area exists (Story 20.1) but holds no screen. To see a namespace's cubes, a cube's model, its term lists or its folder items, a person still opens the classic Model Browser, Term List Manager or Folder Manager. No port reaches the analytics classes, and nothing gates them: the vendor's analytics reads check no `%DeepSee_*` resource (measured).

**Approach (this spec is Part A; Design Notes › Split asks the orchestrator to move the links, the MDX tool and the cube manager to three stories):**

- **A port.** `Port/AnalyticsPort` calls the documented `%DeepSee` classes in process, as the signed-in user, behind its own gate (AD-29). It never calls `/api/deepsee`. A new read source kind, `analytics`, reaches it.
- **Four read surfaces, all read-only:**
  - **Cubes:** name, caption, class, last build and fact count.
  - **A cube's model:** three tabs (Measures, Dimensions, Relationships). This is the classic Model Browser's model tree, down to level depth.
  - **Term lists**, and one list's entries.
  - **Folder items:** pivots, dashboards and the other folder item kinds, with the signed-in person's favorites marked.
- **Not in this part.** The Architect, Analyzer and User Portal links, the MDX tool and the cube manager are Parts B, C and D, chartered in Design Notes › Split.

## Boundaries & Constraints

**Always:**

- **Gate first (AD-29).** Before any vendor call, `AnalyticsPort` checks, in order:
  1. the endpoint's pairs;
  2. the namespace's shape;
  3. that the namespace reports analytics (`NamespaceFeatures.Reports("analytics", ns)`), else 409 `ANALYTICS.NAMESPACE`;
  4. READ on the namespace's globals database and on its routines database (AD-9: database READ is routine execution, and a cube class's code runs).

  A refusal names the failed pair.
- **The vendor's own resource checks still apply.** A cube is read only when `%DeepSee.Utils.%CheckPrivilege` admits it; this is the check `%GetCubeList` applies. A folder item is listed only when its `%CheckResource()` admits it (`%GetFolderItemList` with show-all 0). The model tabs ask `%CheckPrivilege` and `%CubeExists` first, so a tab never shows a cube the Cubes list hides.
- **Only reads measured to write nothing.** The port calls these:
  - `%DeepSee.Utils`: `%GetCubeList(.l,"cubes",1)`, `%GetCubeClass`, `%GetCubeFactCount`, `%GetCubeMeasures`, `%GetDimensionList(cube,.info)`, `%GetRelatedCube`, `%CheckPrivilege`, `%CubeExists`;
  - `%DeepSee.CubeManager.Utils.GetLastUpdate(cube,"build")`;
  - `%DeepSee.TermList`: `%GetTermLists` and `%ToObj`;
  - `%DeepSee.UserLibrary.Utils`: `%GetFolderItemList(.l,"",0,"")` and `%GetFavoriteList`;
  - `%DeepSee.UserLibrary.FolderItem` (`%OpenId`, properties, `%GetTypeName`).
- **No SQL of its own.** The port prepares no statement; the vendor's methods run their own.
- **Namespace (AD-16).** The port switches by explicit save and restore. It calls no `OcuPilot.*` class while switched, and builds rows after it restores.
- **Untrusted content (AD-11, AD-60).** Cube, measure, level, term, value and folder item names and captions reach the screen only as interpolated text.
- **Contended files take add-only edits** (Design Notes › Contended files), with one named exception: the "fourteen sources" message.

**Never:**

- A call to `/api/deepsee`, `%Api.DeepSee` or `%DeepSee.REST.*` (Design Notes › Why not the REST API).
- These vendor calls, each measured to write:
  - `%GetMemberTree` writes `^DeepSee.Session`;
  - `%GetDimensionMembers` writes the MDX cache;
  - `%GetFavoritesForUser` deletes a person's favorites.
- Any MDX execution, a member-value read, `%BuildCube`, `%SynchronizeCube`, or any write tool, governance key or screen action. Those are Parts C and D.
- A caller value passed to `%GetFolderItemList`. Its `pFolderClass` is spliced into SQL.
- A link to Architect, Analyzer or the User Portal (Part B), and any vendor page loaded or framed.
- Edits to `app.routes.ts`, `angular.json`, `Kernel/Proposal/Prohibited.cls`, `Kernel/Governance/Baseline.cls`, `Port/LogSourcePort.cls`, `.github/workflows/ci.yml`, `ui/tools/ci-shards.mjs`, `ui/tools/ci-timings.json` or `ui/tools/ci.test.mjs`.

## I/O & Edge-Case Matrix

All rows read in USER on `ocupilot-b-ci`, with `AnalyticsProbe` created there.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Cubes | `analytics/cubes?ns=USER`, signed in as `_SYSTEM` | One row per visible probe cube: `{Name, Caption, Class, LastBuild, Facts}`. `Facts` equals `%GetCubeFactCount`; `LastBuild` is the instance's local `YYYY-MM-DD HH:MM:SS` of `GetLastUpdate(cube,"build")`, empty when there is none | - |
| Model tabs | A Cubes name cell → `analytics/cubes/document/<cube>` | Measures `{Name, Caption, Type, Hidden}`; Dimensions `{Position, Dimension, Hierarchy, Level}`, one row per level in model order; Relationships `{Name, RelatedCube}`. A Relationships row opens the related cube's Measures tab | - |
| Term lists | `analytics/term-lists`, then a name cell | `{Name, Caption, Modified}`. The entries list `analytics/term-lists/entries/<name>` shows `{TermList, Key, Value, Fields}`, where `Fields` joins each extra field as `<field>: <value>` with `; ` | - |
| Folder items | `analytics/folder-items` | `{Name, Type, Owner, Modified, Favorite}`. `Favorite` is true for the probe pivot, which the fixture marked for the signed-in user | - |
| Guarded | A cube or dashboard whose `resource` the caller lacks | Absent from Cubes or Folder items. The cube's tabs read zero rows | Vendor `%CheckPrivilege` / `%CheckResource` |
| Unknown cube | A tab for a name no cube holds | Zero rows. The tab's empty sentence | - |
| Missing criterion | A tab or entries read with no route id | Nothing reaches the port | 400 `READ.CRITERION` |
| No analytics | Any analytics read in HSCUSTOM | No vendor call | 409 `ANALYTICS.NAMESPACE`, its one sentence |
| Pair missing | A caller without `%DeepSee_PortalEdit:USE` (Term lists, entries) or `%Development:USE` (Folder items) | Refused before any vendor call | 403 `AUTH.NOPRIVILEGE`, `detail.failedPair` names it |
| Database READ missing | A caller without READ on USER's database | Refused before any vendor call | 403 naming `%DB_USER:READ` |
| Cap | More rows than `maxRows` | The first `maxRows` rows | `truncated` true |

</intent-contract>

## Code Map

All paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-20` (HEAD `1615a2d0`). No source path has changed since `bf8bc8b7`, where the pick-up was tried.

- **`_bmad-output/implementation-artifacts/set-aside/20-11-the-analytics-rider-1.patch`** is the implementation: 42 files, +4330 -45, from `story_base` `eb2479f8`, self-reviewed at `11bcb1fa` (Review Triage Log).
  - **New files:**
    - `Port/AnalyticsPort.cls` and `Api/AnalyticsError.cls`;
    - seven `Screen/Descriptor/Analytics*.cls`;
    - `Test/Analytics{Probe,Port,Gate,Descriptor,GateSeam}.cls`;
    - `ui/tools/analytics.test.mjs` and `ui/browser/analytics.browser-spec.mjs`.
  - **Edited files:**
    - `Screen/Read.cls`, `Screen/Registry.cls`, `Kernel/EntityType.cls`, `Api/Error.cls`;
    - `ui/tools/screen-mirror.mjs`, the mirror, `strings.ts`, `structural-walk.mjs`, `scripts/ci-throwaway.sh`;
    - the roster and sentence tests that Verification › Shared surfaces names.
- **`…/set-aside/20-11-the-analytics-rider-1.planning.patch`** changes EXPERIENCE.md :159 (the side-bar sentence) and :604 (the Fixed strings literals, with a Story 20.11 clause). Both target lines are byte-identical on HEAD, at the same numbers (measured).
- **Paths that moved since `eb2479f8`.** Ten of the 42 changed; the other 32 are untouched.
  - `ui/src/app/core/strings.ts`: Story 20.12's `agentWorkflow*` keys and nine workflow-prompt keys follow `interopMessagesEmptyAgent` (~:7477), where the patch appends its 47 `analytics*` keys. This is the known conflict.
  - `ui/src/app/core/screens.generated.ts`: 20.12's prompt `workflow` keys. It is regenerated, never hand-merged.
  - `Screen/Registry.cls` and `ui/tools/screen-mirror.mjs`: 20.12's `workflow` key in `SuggestedPromptsProblem` / `suggestedPromptsProblem` (AD-66). The patch's hunks for the source kind, the criteria rule and `RowTargetProblem` / `rowTargetProblem` land beside it.
  - `Test/Navigation.cls`: Story 23.11 derives the area verdicts from `Screen.Area.List`. The patch adds the analytics block.
  - Also moved:
    - `ui/tools/screen-mirror.test.mjs` and `ui/tools/strings.test.mjs`;
    - `Test/InteropDescriptor.cls`;
    - `Api/Error.cls`: the `WORKFLOW.` line in `ReasonForToolCode`, beside the patch's `ANALYTICS.` lines;
    - `scripts/ci-throwaway.sh`: 20.12's `WorkflowTurn, WorkflowGates` arming lines.
- **`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`**: 20.12 inserted rows at :605 and :606, directly below :604.
- **`ui/tools/strings.test.mjs`** :845-:880 requires every `/** EXPERIENCE.md:n */` comment to name the line that holds its value. All of the patch's keys cite :604.
- **The tab-arm pin:**
  - **`Test/RowTargetCorpus.cls`**: `Cases` (its declaration is a Locks-shaped list) and `DeclarationFor` :135-:149, which overrides `rowTarget`, `archetype` and `table`;
  - **`ui/tools/screen-mirror.test.mjs`**: `rowTargetDeclarationFor` :1053-:1060, run at :1069;
  - **`Test/Descriptor.cls`**: `TestEveryRowTargetCorpusCaseGetsItsSentence` :2092;
  - a real tab's shape: `InteropItemStatusTab.cls`:64, `{"group", "position", "labelKey"}`.
- **The browser spec's helpers** (`browser.config.mjs`, `list-spec.mjs`, `namespace-features.mjs`, `panel-spec.mjs`, `structural-walk.mjs`, `turnprobe-spec.mjs`, `tools/strings.mjs`) still export every name the spec imports (checked).
- **Vendor (read only):** `irislib/%DeepSee/Utils.cls`, `TermList.cls`, `CubeManager/Utils.cls`, `UserLibrary/Utils.cls` and `UserLibrary/FolderItem.cls`. AD-65's Rule and Design Notes › Measured carry the facts.

## Tasks & Acceptance

**Execution:**

- [x] **Task 0: re-apply the set-aside implementation (no new product code).** Work from `/Users/jbrandt/git/OcuPilot/.worktrees/epic-20`. Check `git rev-parse --show-toplevel` and a clean tree first.
  1. Run `git apply --whitespace=nowarn --3way _bmad-output/implementation-artifacts/set-aside/20-11-the-analytics-rider-1.patch`, then the same for `20-11-the-analytics-rider-1.planning.patch`. Judge each by its exit code: 1 means it left conflicts.
  2. Resolve every conflict as an append-only union that keeps both sides, then mark each path resolved with `git add -- <path>`:
     - **`ui/src/app/core/strings.ts`** (known): HEAD's 20.12 keys unmoved, then the patch's `analytics*` block, then `} as const;`.
     - **EXPERIENCE.md :604** (expected, inference: the patch's edit touches the line above 20.12's new rows): the patch's extended :604, then 20.12's :605 and :606 unchanged.
     - **`screens.generated.ts`**, if it conflicts: take either side, because step 4 regenerates it.
     - Afterwards, no conflict marker is left in any touched path.
  3. **Re-anchor the citations.** Every `/** EXPERIENCE.md:n */` the patch adds must name the line that holds its value. At plan, all 47 cite :604, which is still :604, so none should move. Fix any that `strings.test.mjs` names.
  4. **Regenerate the mirror:** `cd ui && node tools/screen-mirror.mjs`. Then `node tools/screen-mirror.mjs --check` reports no drift.
  5. **Re-read every shared roster the patch extends** in the merged tree (Code Map › Paths that moved). The patch's rows must sit in their own block, and no 20.12 or 23.11 row may be lost.
     - Then run `git apply --numstat _bmad-output/implementation-artifacts/set-aside/20-11-the-analytics-rider-1.patch | awk '{print $3}' | xargs git diff --stat HEAD...origin/OCU-1-epic23 --`. It was empty at plan (`132bd11f`).
     - A path that shows up takes an add-only union. Any other kind of change is a `## Clarification Needed`.
  6. **Run Verification.** A red that is not a stale shared-surface assertion halts the stage with its evidence.
  - Steps 1 and 2 belong to the implement stage itself. If its handoff prompt forbids `git apply`, the stage runs them before the handoff.
- [x] **Pin AD-5's tab arm** in `src/OcuPilot/Test/RowTargetCorpus.cls` and `ui/tools/screen-mirror.test.mjs`. This answers the rejected-low the 2026-10-20 review left open; Decided in-stage 1 says why.
  - `DeclarationFor` and `rowTargetDeclarationFor` each take a case's `tab` object, one line each. Their doc comments name `tab` beside `archetype` and `table`.
  - `Cases` gains this case: `{"name": "a tab of a tabbed group may declare one (AD-5)", "archetype": "detail", "tab": {"group": "os-management/row-target-corpus", "position": 1, "labelKey": "lockListLabel"}, "expected": null}`.
  - The existing case "a detail archetype is not a list" keeps pinning the refusal of a `detail` screen that is no tab.
- The rest of Part A, as the 2026-10-14 gate approved it, is the patch. The implement stage does not rewrite it.

**Acceptance Criteria:**

- **AC1 (the four surfaces read through the analytics port).**
  - **Given** `AnalyticsProbe` in USER.
  - **When** Cubes, a cube's three tabs, Term lists with entries and Folder items load, and their read tools run.
  - **Then:**
    - each answers the matrix's rows, equal to the vendor's own answer read on the instance;
    - the screen and the tool answer the same rows (AD-36);
    - no read changes the MDX cache, the process's DeepSee session node, a favorite, or the probe's term list or folder nodes.
- **AC2 (model and term-list navigation).**
  - **Given** Cubes in USER.
  - **When** the person opens `OcuPilotProbeVisits`' name cell.
  - **Then:**
    - the route is `analytics/cubes/document/<cube>`, with Measures, Dimensions and Relationships in that strip order;
    - the `CategoryRel` row opens `OcuPilotProbeCategories`' Measures tab;
    - a Term lists name cell opens `analytics/term-lists/entries/<name>`, whose `Fields` column shows the `Note` values.
- **AC3 (gate first; AD-29, AD-65).**
  - **Given** one of these:
    - HSCUSTOM;
    - P1, a principal holding `%Development:USE`, `%DB_USER:R` and READ on the install namespace's code database;
    - P2, which is P1 without `%DB_USER:R`.
  - **When** an analytics read runs.
  - **Then** each refusal is the gate's: 409 `ANALYTICS.NAMESPACE` with its sentence, or 403 naming the failed pair. For P2 that pair is `%DB_USER:READ`; a vendor call made first would have answered with an unnamed `<PROTECT>`.
  - **And** `PortGate` holds `AnalyticsPort`'s row and the denial of each of its pair sets.
  - **And** the vendor's own cube and folder-item resource checks still hide the guarded probe objects from P1.
- **AC4 (Integration, Rule 1).**
  - **Given** P1 signed in.
  - **When** `Screen/Read` serves `GET /screens/analytics.cubes/read?ns=USER`, and the agent's `analytics.cubes.read` runs in USER.
  - **Then** both answer the probe's visible cubes with `{Name, Caption, Class, LastBuild, Facts}` from `AnalyticsPort`.
- **AC5 (declared, gated, rostered, structural).**
  - **Given** the seven descriptors.
  - **When** the instance validates them and the build regenerates the mirror.
  - **Then:**
    - each validates on both sides with Design Notes › Descriptors' values and at least three prompts;
    - each is in `Elsewhere`, and removing one row reddens that test alone;
    - the Analytics navigation carries 7 screens in the pinned order;
    - every floor principal opens the Cubes list and its tabs, the developer principal also opens Folder items, and no floor principal opens Term lists;
    - both engines' row-target grammar admits a tab of a tabbed group and refuses a `detail` screen that is no tab (AD-5 as amended);
    - the structural walk finds no fresh entry in either theme.
- **AC6 (the fixture leaves USER as found).**
  - **Given** a run of either test class or of the browser spec.
  - **When** it ends.
  - **Then** `AnalyticsProbe.Gone()` is true:
    - no probe class, cube, term list, folder item, favorite or `CubeEvent` row remains;
    - USER's two flags read their recorded values;
    - USER reports no analytics.

### Review Findings

Code review 2026-10-21 (full-opus; blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor): 16 entries from 32 layer rows plus two of the reviewer's own (high 1, medium 5, low 10); 12 patched, 4 ledgered, 6 rejected.

- [x] [Review][Patch] High: the Measures read raised `<NULL VALUE>` (500) for any cube with a calculated measure, which the vendor lists as `$LB(name, caption, type)` [src/OcuPilot/Port/AnalyticsPort.cls:318] - `$ListGet`; the guarded probe cube defines one and `TestTheCubeTabsAnswerTheModel` reads it (AC1).
- [x] [Review][Patch] Medium: the probe's build-event delete and its `Left` count used `%SQLUPPER(CubeKey) %STARTSWITH`, which never matches, so 155 probe `CubeEvent` rows had leaked into USER on the throwaway and AC6's check could not fail [src/OcuPilot/Test/AnalyticsProbe.cls:440] - plain `CubeKey %STARTSWITH`.
- [x] [Review][Patch] Medium: `Left`'s favorite check read the user from the probe node `Remove` kills, and its cube check ran only while USER reported analytics, so neither could fail after `Remove` [src/OcuPilot/Test/AnalyticsProbe.cls:499] - favorites are removed and checked for every user; the cube check is unguarded.
- [x] [Review][Patch] Medium: `AnalyticsPort.Under` always answered 0, so `TestTheReadsWriteNothing` never compared a node below a root [src/OcuPilot/Test/AnalyticsPort.cls:332] - `Return 0` on a mismatch.
- [x] [Review][Patch] Medium: `AnalyticsGate.EnsurePrincipals` copied the creation loop of the shared `InteropTestGate.CreatePrincipals` (Rule 2) [src/OcuPilot/Test/AnalyticsGate.cls:432] - it calls the shared helper.
- [x] [Review][Patch] Low: the entries read ignored `%ToObj`'s status, so a vendor fault part-way answered 200 with a partial list [src/OcuPilot/Port/AnalyticsPort.cls:364].
- [x] [Review][Patch] Low: `Mapped` answered a raised #940 status 500 while its doc said it answers as `Statused` does [src/OcuPilot/Port/AnalyticsPort.cls:513] - it delegates to `Statused`.
- [x] [Review][Patch] Low: `Remove`'s doc said the first failure is the status returned; its removal steps' statuses are not kept [src/OcuPilot/Test/AnalyticsProbe.cls:401] - the doc says `Left` names what a failed step leaves.
- [x] [Review][Patch] Low: `analytics.test.mjs`' header said the client draws the refusal sentence [ui/tools/analytics.test.mjs:4].
- [x] [Review][Patch] Low: the AC5 mutation note named a token that does not exist [ui/browser/analytics.browser-spec.mjs:333].
- [x] [Review][Patch] Low: the mirror test's note said the corpus criteria case reddens when `SOURCE_ANALYTICS` leaves the parent-only rule; the tabs' "criteria pass" legs do (run here) [ui/tools/screen-mirror.test.mjs:3259].
- [x] [Review][Defer] Medium: `Screen/Read.Execute`'s analytics branch repeats the interop branch line for line (Rule 2) [src/OcuPilot/Screen/Read.cls:590] - deferred: DW-2473 escalated; merging them rewrites the interop branch in a contended roster file.
- [x] [Review][Defer] Low: Cubes' empty sentence, and the cube tabs', are untrue when cubes are hidden by their resource [ui/src/app/core/strings.ts:7544] - deferred: DW-2474 decision-pending (user-facing wording in EXPERIENCE.md :604).
- [x] [Review][Defer] Low: a failed fact count's null is pinned in `Rows` only, not through `Collect` [src/OcuPilot/Port/AnalyticsPort.cls:303] - deferred: DW-2475 wontfix-accepted.
- [x] [Review][Defer] Low: the criteria refusal sentence still names five ports [src/OcuPilot/Screen/Registry.cls:1745] - deferred: DW-2277 (occurrence; re-closed).
- [x] [Review][Defer] Low: `AnalyticsGate.ProbeAs` copies the gate classes' child-probe wrapper [src/OcuPilot/Test/AnalyticsGate.cls:336] - deferred: DW-2381 (occurrence; the project's convention).

Rejected:

- false: hidden levels and relationships are left out of the tabs - the classic Model Browser's `%GetMemberTree` leaves out hidden dimensions and levels too (`%DeepSee.Utils` :4400-:4607).
- false: a `%DeepSee` call runs before the database READ checks - the analytics check before database READ is AD-65's order and the spec's.
- low: a cube tab declared unparented, or with another criterion, passes both registries and reads 400 - developer-only, the seven declarations are pinned, and the fix adds a branch to two engines.
- low: the entries' Key column borrows `oauthClientAlgKey` - strings are reused by value across areas (`errorLogColumnValue` in six descriptors).
- spec edit: the Auto Run Result's counts predate QA's tests - this review re-ran them (AnalyticsPort 11, AnalyticsGate 8, AnalyticsDescriptor 5, PortGate 4, browser 5 of 5).
- spec edit: the add-only list does not name the row-target tab arm - AD-5 as amended at `bf8bc8b7` sanctions it.

### Rework (CI)

- [x] [CI] browser shard 1/5: `panel.browser-spec.mjs` test 7 ("Signing out clears the panel draft and full screen; the next sign-in starts fresh") times out waiting for `app-panel aside.ocu-panel` — https://github.com/jbrandtmse/OcuPilot/actions/runs/39549375345 (attempts 1 and 2) — the defect is in `ui/src/app/core/session.ts`, not in the test or this story's code. `signOut()` settles the tab and shows the sign-in card, then awaits `/turn/abandon` (up to `SIGN_OUT_ABANDON_WAIT_MS`) and posts `/logout` with `credentials: 'include'`. A sign-in submitted in that window is answered first, and the late cookie-carrying `/logout` ends the new login: on a freshly rebuilt `ocupilot-b-ci`, `/login` answered 200 at 07:01:31.767 and `/logout` at .779, then `/agent/restraint`, `/refresh` and `/login` answered 401 and the card came back. It reproduces with feature's code alone. What the fix must do: a form submit, and every other `/login` the session client posts, waits for an in-flight sign-out's `/logout` to settle before it posts. The wait is bounded, so a hung logout cannot hold a sign-in forever (a named bound). The tab still clears and settles locally first (DW-5's order is unchanged). Pin it in `ui/tools/session.test.mjs`: with a sign-out whose `/logout` is held, a submit posts `/login` only after the logout settles; mutation: drop the wait, and that test goes red. `panel.browser-spec.mjs` stays unchanged as the browser-level pin; the lead re-runs it on a freshly rebuilt throwaway, where it failed before the fix. The wait is bounded by `LOGIN_AFTER_SIGN_OUT_WAIT_MS` (8,000 ms: the abandon's 3,000 ms plus 5,000 ms for the `/logout`).

## Spec Change Log

- 2026-10-14, spec gate (runner): the orchestrator ruled Q1 A (Parts B, C and D are Stories 20.32, 20.33 and 20.34, chartered in `epics.md` with their criteria verbatim; order 20.11, 20.32, 20.33, 20.34, then 20.12) and Q2 A (Folder items on `%Development:USE`, a named narrower audience in AD-8). `epics.md` Story 20.11 is amended under Rule 5 (the split, and the first criterion's API reworded to the vendor's classes, apply-and-report). The new AD is AD-65 (claimed from the coordination counter), with the AD-29, AD-36, AD-8, AD-44, AD-13 and AD-7 clauses. Task 0 gains the cube `Resource` check measurement (the orchestrator's). The REST layer finding is DW-2416, decision-pending under the owner's hold.
- 2026-10-14, lead (20.33's spec gate, orchestrator rulings Q1 A and Q2 C): Part C's splice limits become the screen's ask-first confirmation and the agent's refusal; the agent's MDX read is Story 20.35.
- 2026-10-21, runner (owner answer U-1 A): AD-5 amended (`bf8bc8b7`); the pick-up's three-way apply conflicted in `strings.ts`, so the story is re-planned from the set-aside patches (Design Notes › Owner answer U-1).

## Review Triage Log

### 2026-10-20 - Review pass

- verdicts: 30 findings - high 0, medium 7, low 16, false 7, maybe-false 0 (two layers; the intent-alignment layer is descriptive, and each divergence it listed is a row)
- findings:
  - `[medium]` `[patch]` `LocalStamp` (Folder items `Modified`, UTC to local) unpinned, and its instant leg one-sided - the throwaway runs in UTC, so the conversion could vanish unseen; patched: the instant leg is two-sided and two sessions started with `TZ` set (Los Angeles, Tokyo) read fixed UTC stamps; the conversion was also measured by hand in three zones (LA winter and summer, Tokyo); mutation line written.
  - `[medium]` `[patch]` The port's fault mapping (`Statused`, `Mapped`, `Fail`, `LogFault`) unpinned - vendor text could reach the wire unseen; patched: `AnalyticsGateSeam` arms a vendor failure and captures the log, and `AnalyticsPort` gains a test for five failure shapes; mutation line written.
  - `[medium]` `[patch]` The routines-database READ half of `Admit` never executes (USER keeps both in one database) - patched: `PortGate` drives it in HSLIB through the seam's `routines` answer (named resource refused by name; unnameable one 400); mutation line written.
  - `[medium]` `[patch]` The cap is pinned on three of seven endpoints - patched for Measures and Folder items (the unbounded one); mutation line written.
  - `[low]` `[reject]` The cap on TermLists and Relationships has no leg - both need a second probe row, and the loop is the shape the four covered endpoints share; not worth a fixture change (reopen_if: a cap regression ships in either).
  - `[medium]` `[patch]` `Snapshot` returns the digest of its own error text, so a throwing snapshot compares equal to itself - patched: it returns the error unhashed and the test asserts the snapshot was taken.
  - `[low]` `[reject]` Three of `TestTheReadsWriteNothing`'s five node groups (cache, term list, folder) have no mutation line - Rule 19 asks one demonstrated mutation per acceptance criterion, and AC1 has two (session node, favorites).
  - `[low]` `[reject]` The tab arm of `RowTargetProblem` is outside `RowTargetCorpus` - the corpus overrides `archetype` and `table` only, so a tab case means changing both engines' declaration builders; the supported shape (Relationships passes `Registry.Validate` and the mirror) and the refused shape (a detail that is no tab) are pinned in `AnalyticsDescriptor` and `screen-mirror.test.mjs`.
  - `[low]` `[reject]` The `Facts` JSON-null branch is never read - it needs a cube whose count fails; the branch is two lines (reopen_if: a failing count is seen drawn as 0).
  - `[medium]` `[patch]` AC6 says the two flags read their recorded values, and `Gone` checks only that analytics is not reported - patched: `Remove` reads both flags back and returns an error naming the mismatch; mutation line written.
  - `[low]` `[patch]` Header mutation claims with no recorded run (the descriptor, mirror and navigation tests) - each was run: the descriptor test's four, the mirror test's two, the navigation test's two demonstrated, and one claim the mirror's own tab check makes unreachable was reworded.
  - `[low]` `[reject]` Pinning tests with no `mutation:` line of their own (cube tab rows, navigation, pair legs, floors) - each AC has at least one recorded mutation, which is the bar.
  - `[low]` `[patch]` `AnalyticsDescriptor.TestTheAnalyticsSourceRefusals` claimed the corpus's criteria case pins the parent-only rule; the case is refused either way - the claim now names the test that pins it.
  - `[low]` `[patch]` `analytics.test.mjs`'s second test is titled as if it read the descriptors and reads only the port's source - retitled.
  - `[medium]` `[patch]` The browser spec sets `created` only after `Create` succeeds, so a part-way `Enable` or `Create` leaves USER analytics-enabled until the next run - `created` is now set before `Enable`, so `after` always removes the probe.
  - `[low]` `[patch]` The time test's docstring says "within two seconds" and asserts one side - fixed with the first row.
  - `[false]` `[reject]` Intent alignment, model tabs: HTTP asserts only non-empty or zero rows - the port test pins each tab's rows and order, and the browser pins the related-cube click.
  - `[low]` `[reject]` `Fields` joins with `; ` and the probe term list has one extra field, so the separator is never read - the fixture is the spec's (three keys, one field); the join is one loop line.
  - `[false]` `[reject]` Guarded rows pinned only over HTTP for a caller lacking the resource - the spec places that pin in `AnalyticsGate`, and the port test runs as `%All`, which sees them.
  - `[low]` `[reject]` An unknown or hidden cube's empty sentence is not drawn in a browser leg - the sentence is the shared page's `emptyStateKey`, and the spec lists no such leg.
  - `[false]` `[reject]` `READ.CRITERION` is asserted through the tool roster only - that code is `Screen/Read`'s own branch, which the tool path executes; the port's missing-criterion refusal is a different code, `PORT.VALIDATION`, pinned in the port test.
  - `[low]` `[reject]` The browser draws the shell's `request refused`, not the 409 sentence, in HSCUSTOM - the wire carries the sentence (pinned), the Analytics area is not offered where analytics is off, and drawing it is page code the spec's Weight section rules out; interop's namespace refusal is the same.
  - `[false]` `[reject]` Pair-missing is asserted over HTTP with the same code the port gives - `PortGate` and the gate class's child-process `Invoke` pin the port's own refusal.
  - `[false]` `[reject]` Database READ missing over HTTP is the router's `NS.DENIED`, not the port's - both name `%DB_USER:READ`, and `AnalyticsGate` pins the port's own through a child process.
  - `[low]` `[patch]` `truncated` is asserted once, over HTTP on Cubes - closed before this review by the Matrix audit: the leg exists and its mutation line is written.
  - `[low]` `[reject]` Contended files are edited in four places beyond add-only - the allowed list and the criteria rule are what Tasks name, and the tab `rowTarget` relaxation is what the Relationships descriptor needs; AD-5's sentence is left unedited and offered to the lead (Auto Run Result).
  - `[false]` `[reject]` Classic-page links declared on each descriptor - the spec's design (AD-44): a link, never loaded or framed.
  - `[low]` `[reject]` The "all" level is not listed - the spec keeps type `l` entries.
  - `[low]` `[reject]` No test feeds markup-bearing names - rows reach the screen through the shared table renderer, which interpolates (AD-11); the port adds no rendering.
  - `[false]` `[reject]` Seven agent read tools the intent does not name - every descriptor with a `toolIdentifier` yields one, and the spec's table names them.


### 2026-10-20 - Review pass (the re-applied patch)

- verdicts: 20 findings - high 0, medium 1, low 13, false 6, maybe-false 0 (two layers; the intent-alignment layer is descriptive, and each divergence it listed is a row)
- findings:
  - `[medium]` `[patch]` The `ANALYTICS.` lines of `Error.ReasonForToolCode` and `ReasonForViolation` are exercised by no test (siblings pin theirs, e.g. the Journal family) - patched: `AnalyticsDescriptor.TestTheAnalyticsCodeReadsItsOwnSentence` asserts the sentence and both resolvers; each line dropped in turn reddened it alone; mutation line written.
  - `[low]` `[patch]` The guarded cube's Relationships-tab zero-rows leg cannot fail (the cube defines no relationship) - patched: the leg asserts the visible cube's tab only, and the doc comment says so; the other two tabs share the guard branch and still redden (mutation re-run). A second relationship would change the shared fixture's other counts (reopen_if: the Relationships guard is split from the Measures and Dimensions branch).
  - `[low]` `[reject]` The gate's analytics-before-database-READ order has no leg for a caller lacking READ in a namespace without analytics - the difference shows only on the in-process tool path as a different refusal code, and the router's `NS.DENIED` hides it over HTTP (reopen_if: a no-analytics namespace refusal is seen naming a database pair).
  - `[low]` `[reject]` carried: sub-clauses with no `mutation:` line of their own (strip order, navigation order, floors, the other six tools' rows) - Rule 19 asks one demonstrated mutation per AC, and each AC has at least one.
  - `[low]` `[reject]` No record that the [re-demonstrate] and [new] mutation lines were run - the run record is this section's Auto Run Result, and the stage re-ran the [new] `strings.ts` and `rowTargetProblem` mutations itself.
  - `[false]` `[reject]` Tests depend on environment they do not create (zoneinfo, `/usr/bin/env`, the install namespace reporting no analytics, HSLIB reporting analytics) - each asserts its precondition and fails loudly; none can pass falsely.
  - `[low]` `[patch]` The AC3 browser leg fills `reads` after `await response.text()` and reads it as soon as the refusal draws - patched: `reads` holds the pending body, and the leg awaits it.
  - `[low]` `[patch]` `analytics.test.mjs`' header claims the strings and tools the descriptors name must exist, which neither test checks - patched: the header names the endpoint list the mirror generator reads.
  - `[low]` `[patch]` The `AnalyticsPort` class comment lists three test seams and `AnalyticsGateSeam` overrides `Collect` too - patched: the comment names four.
  - `[false]` `[reject]` carried: Missing criterion is asserted through the tool roster only - `READ.CRITERION` is `Screen/Read`'s own branch, which the tool path executes.
  - `[low]` `[reject]` carried: the cap has no leg on TermLists and Relationships, and `truncated` is read over HTTP on Cubes only - the loop is the shape the covered endpoints share.
  - `[low]` `[reject]` carried: the browser draws the shell's `request refused`, not the 409 sentence - the sentence travels on the wire and is pinned there.
  - `[false]` `[reject]` Folder items' pair has no real principal that lacks it - `PortGate` denies `FolderItems` naming `%Development:USE` through the gate, and the descriptor's pairs hide the screen from floors without it.
  - `[false]` `[reject]` The database READ refusal is reached only through a child process and the seam - `AnalyticsGate` and `PortGate` pin the port's own refusal; the HTTP route answers `NS.DENIED` naming the same pair.
  - `[low]` `[reject]` The entries table omits the `TermList` column the row carries - `InteropLookupEntryList` omits its `Table` column the same way, and the route and the id carry the list name.
  - `[false]` `[reject]` `LastBuild` and `Modified` zones are untested against an independent source - the spec measured `GetLastUpdate` as local time and `timeModified` as UTC, and `TestTheTimeShapesAreTheInstancesLocalTime` pins the conversion in two zones.
  - `[low]` `[reject]` carried: shared validators change in both engines beyond add-only - Decided in-stage 4 and AD-5 as amended cover the tab arm, the allowed list and the criteria rule; `origin/OCU-1-epic23` (`9b927443`) touches none of the 44 paths.
  - `[false]` `[reject]` carried: a classic-page link on each descriptor - AD-44 (a link, never loaded or framed), and none is to Architect, Analyzer or the User Portal.
  - `[low]` `[reject]` The Never list's negatives (no forbidden vendor call, no SQL, no `OcuPilot.*` call while switched) have no static test - the observable, no changed node, is pinned by `TestTheReadsWriteNothing` with two recorded mutations.
  - `[low]` `[reject]` carried: no test feeds markup-bearing names - rows reach the screen through the shared table renderer, which interpolates (AD-11).

### 2026-10-21 - Review pass (the CI rework)

- verdicts: 9 findings - high 0, medium 0, low 3, false 6, maybe-false 0 (two layers; the intent-alignment layer is descriptive, and each divergence it listed is a row)
- findings:
  - `[low]` `[reject]` The identity guard that stops a settled first sign-out clearing a later one's marker is unpinned - it needs a logout that hangs past the bound and a second sign-out, and a test needs per-call logout releases (about 30 lines, past Rule 15's fifteen); reopen_if: a login is seen ended by a late first logout.
  - `[low]` `[patch]` The bound's magnitude is unpinned (shrunk to the abandon wait plus 1 ms, all green) - patched: the bound test asserts it leaves the logout five seconds after the abandon wait; the shrink mutation reddens it alone.
  - `[low]` `[patch]` The abandon-window test has no `mutation:` line of its own - the marker counted only once the logout is sent was applied and reddens that test alone; line written.
  - `[false]` `[reject]` The wait's 8,000 ms equals `BACKOFF_MAX_MS`, so delay-matched timers could be mis-read - no new test arms a backoff, and each finds its one timer; nothing fails or can fail as written.
  - `[false]` `[reject]` Part A's behavior is untouched by the diff - the dispatched item is the CI rework of the client's sign-out, and the spec names the defect as outside this story's code.
  - `[false]` `[reject]` The defect lies outside the intent's surfaces - the same claim, from the other side; the Analytics rows are pinned by their own classes.
  - `[false]` `[reject]` The diff's tests are unit-level - the item names them, and the browser-level pin (`panel.browser-spec.mjs`, unchanged) ran green, 13 of 13, on the redeployed bundle.
  - `[false]` `[reject]` `signOut` and `abandonTurns` are restructured, not add-only - the add-only rule is for shared rosters; `session.ts` is on no contended list, and Epic 23 does not touch it.
  - `[false]` `[reject]` The Auto Run Result still reads done and the mutation line seems to count five - this pass rewrites the result at finalize, and the line names four mutations.

## Design Notes

**Owner answer U-1 and the re-plan (2026-10-21).**

- **The answer.** The owner answered U-1 with A, and AD-5's row-target bullet was amended at `bf8bc8b7`. A tab of a tabbed group (a `detail` screen drawing a table) may now declare a row target. So the Relationships tab's `rowTarget`, and the tab arm of `RowTargetProblem` / `rowTargetProblem`, are within AD-5.
- **The first pick-up.** `git apply --whitespace=nowarn --3way` of the code patch on `bf8bc8b7` exited 1. Its one conflict was the append-only union at `strings.ts`. The source was restored and the story re-planned.
- **This plan.** Task 0 re-applies both patches and keeps both sides of every union.

**Governing ADs (Rule 6).**

- **AD-65:** the analytics port, its gate order and call list, and source kind `analytics`.
- **AD-5 (amended `bf8bc8b7`):** seven descriptors and no page code. A tab may declare a row target.
- **AD-29:** the port's own gate is the whole gate.
- **AD-1:** in process, never HTTP.
- **AD-7:** the reads' cost (Measured).
- **AD-8:** the pairs, below.
- **AD-9:** READ on the routines database.
- **AD-11 and AD-60:** names are untrusted content.
- **AD-13:** ids are kept exactly.
- **AD-16:** switched reads.
- **AD-24:** context fields.
- **AD-36:** one read for screen and tool, the cap, and a parent's route id as the criterion.
- **AD-44:** the three classic pages.
- **AD-62:** the precedent this port copies.
- **AD-64:** the screens' pairs are adjustable; the port's are not.

Checked and not engaged:

- AD-10, AD-22 and AD-51 to AD-53: no write.
- AD-43: no refresh.
- AD-47 and AD-63: nothing is loaded or framed.
- AD-21: no caller text reaches SQL, and the vendor's spliced `pFolderClass` is never passed.
- AD-66: no analytics prompt names a workflow.

**Decided in-stage (plan, 2026-10-20).**

1. **The tab arm is pinned.** It costs two one-line builder changes and one corpus case. So the rejected-low "the tab arm of `RowTargetProblem` is outside `RowTargetCorpus`" is closed by a pin.
2. **The `strings.ts` union order.** HEAD's 20.12 keys come first, then the analytics block. No test reads key order, and HEAD's lines stay where they are.
3. **The citations stay :604.** Measured: the line the planning patch replaces is byte-identical at :604 on HEAD, and 20.12's rows are :605 and :606.
4. **Two in-place list edits count as add-only.** They are the allowed-list edit (`Read.cls` `Execute`) and the criteria-rule edit (`Registry.cls`, `screen-mirror.mjs`).
   - Each extends a list expression in place, and no existing source's behavior changes.
   - The gate-approved Tasks named both, and the 2026-10-20 review closed them.
   - Epic 23's branch touches neither file.
   - The "fourteen" to "fifteen sources" message is the intent's own named exception.
5. **The strings bound stays 3,800.** Measured with the test's extractor rule: the table holds 3,490 distinct literals now and about 3,537 after the union, so the count is not within 50 of the bound.
6. **The analytics classes run one per call.** `ui/tools/ci-timings.json` has no row for them yet.
7. **`context:` drops EXPERIENCE.md.** The stage reads its two rows by line.

**Descriptors (the values AC5 cites; all built).** Every descriptor shares these values:

- area `analytics`, scope `namespace`, `refreshes` false;
- no actions, `classicLinkExemption` all-false, and three prompts;
- `context.fields` equal to the read's fields.

| Class | Route · position · archetype | Pairs | Classic page | Entity · id | Endpoint · criterion | Tool |
|---|---|---|---|---|---|---|
| `AnalyticsCubeList` | `analytics/cubes` · 1 · list | Portal | `%DeepSee.UI.ModelBrowser` | `cube` · `Name` | Cubes | `analytics.cubes` |
| `AnalyticsCubeMeasuresTab` | `analytics/cubes/document` · 0 · detail, tab 1 | Portal | ModelBrowser | `cube` | Measures · `cube` | `analytics.cubemeasures` |
| `AnalyticsCubeDimensionsTab` | `analytics/cubes/dimensions` · 0 · detail, tab 2 | Portal | ModelBrowser | `cube` | Dimensions · `cube` | `analytics.cubedimensions` |
| `AnalyticsCubeRelationshipsTab` | `analytics/cubes/relationships` · 0 · detail, tab 3; `rowTarget {analytics/cubes/document, RelatedCube}` | Portal | ModelBrowser | `cube` | Relationships · `cube` | `analytics.cuberelationships` |
| `AnalyticsTermListList` | `analytics/term-lists` · 2 · list | Portal + `%DeepSee_PortalEdit:USE` (own) | `%DeepSee.UI.TermListManager` | `term-list` · `Name` | TermLists | `analytics.termlists` |
| `AnalyticsTermListEntryList` | `analytics/term-lists/entries` · 0 · list, parent `analytics/term-lists` | as Term lists | TermListManager | `term-list-entry` · `[TermList, Key]` | TermListEntries · `termlist` | `analytics.termlistentries` |
| `AnalyticsFolderItemList` | `analytics/folder-items` · 3 · list | Portal + `%Development:USE` (own) | `%DeepSee.UI.FolderManager` | `folder-item` · `Name` | FolderItems | `analytics.folderitems` |

- "Portal" is `%DeepSee_Portal:USE`.
- The tabs' `tab.group` is `analytics/cubes/document`, and their `parentScope` is `analytics/cubes`.
- A criterion is text, `maxLength` 255.

**Measured** (2026-10-14 plan and 2026-10-20 implement, on `ocupilot-b-ci`, build 221U).

- **Turning analytics on.**
  - USER and HSCUSTOM report no analytics.
  - `Security.Applications.Modify` with both flags at 1 writes six class-access rows for `/csp/user/` and nothing else. With 0 it removes them.
  - After it, the same process reads `Reports("analytics","USER")` 1.
- **The vendor checks no `%DeepSee_*` resource.**
  - Only a cube's or a folder item's own `resource` filters anything.
  - Without `%DB_USER`, `%GetCubeList` throws `<PROTECT>`.
  - For a caller lacking a guarded cube's resource, the cube is absent from `%GetCubeList` and refused by `%CubeExists`, `%CheckPrivilege` and `%GetCubeMeasures`. Yet `%GetDimensionList` still answers it, so every tab asks first.
- **Which calls write.**
  - The port's calls write no `^DeepSee*` or `^OBJ*` node: 4,175 nodes were unchanged. Each takes under 0.5 ms once warm.
  - `%GetMemberTree` writes the session node, and `%GetDimensionMembers` writes the cache.
  - `%GetFavoritesForUser` deletes a dangling favorite.
- **Times and pages.**
  - `GetLastUpdate` answers the server's local time.
  - `FolderItem.timeModified` is UTC, so the port converts it to local time (`LocalStamp`).
  - `NormalizePage` of the three `.zen` pages is the three class names.

**Decisions (gate-approved, carried in the patch).**

- **Model reads stop at levels.** Member values run MDX and write the cache; they belong to Story 20.33.
- **One cube tab group under the Cubes list**, following the item tabs' precedent.
- **Term list entries follow the lookup entries.** They are read through `%ToObj`, and `Fields` joins each extra field as `<field>: <value>`.
- **Folder items.**
  - The list reads with show-all 0, which keeps the vendor's per-item check.
  - `Favorite` is the signed-in person's, read through `%GetFavoriteList`.
  - The `%Development:USE` pair is AD-8's named narrower audience (Q2 A).
- **`Last build`** is `GetLastUpdate(…,"build")`.
- **Database READ.** The gate requires READ on the routines database as well as the globals database.
- **Arming.** The suites declare `OCUPILOT_ALLOW_PRINCIPALS`.
- **Implement-stage choices.**
  - The Dimensions tab's name column is `Level`.
  - `Facts` is JSON null when the count fails.
  - The Cubes cap applies to the cube list.
  - `analyticsRefusalNamespace` joins `strings.test.mjs`'s namespace-key roster.
  - The entries' `Key` joins its credential-name exemptions.

**Split.** The 2026-10-14 gate ruled Q1 A (Spec Change Log). Parts B, C and D are Stories 20.32, 20.33 and 20.34, and the agent's MDX read is Story 20.35. The spine clauses are written: AD-65, plus its AD-29, AD-36, AD-8, AD-44, AD-13 and AD-7 clauses.

**Integration, Consumes, Consumed-by (Rules 1 and 2).**

- **Integration:** AC4. `Screen/Read` and the read-tool dispatch consume `AnalyticsPort` against the real instance.
- **Consumes:**
  - Story 20.1: the Analytics area and `NamespaceFeatures`;
  - the read route, `ListPage` and `DetailPage`;
  - `Kernel/Shell/Namespaces`;
  - `ScreenGate.Hold`, `TurnWireFixture`, `Http.AbsoluteRequest`, and the floors' principals.
- **Consumed-by:**
  - **20.32:** the area and its listed screens, beside its links.
  - **20.33:** Cubes as its cube picker, and `AnalyticsPort`'s MDX calls.
  - **20.35:** `AnalyticsPort`, through 20.33's `MdxRun`.
  - **20.34:** `AnalyticsPort`, `AnalyticsError`, `AnalyticsProbe`, the gate principals, the `cube` type, and Cubes' Last build and Facts.
  - **Epic 21's 21.8:** its editors extend Term lists, Folder items and `AnalyticsPort`.

**Ledger inbox (Rule 17):** none owned (`owned_ledger=0`). `LEDGER slice 20-11-the-analytics-rider` was empty at plan.

**Extend, don't copy (Rules 2 and 31).**

- **`AnalyticsPort`** follows `InteropPort`'s gate and `MonitorPort`'s read-only shape.
  - Each in-process port keeps its own private `Deny`, `Refuse` and `Conflict`. A shared base would couple unrelated vendor areas.
  - It reuses `Kernel.Denial`, `Kernel/Shell/Namespaces`, `NamespaceFeatures` and `AtelierPort.#NAMESPACEPATTERN`.
- **Siblings extended:**
  - `AnalyticsError` is a sibling of `InteropError`. `Api/Error.cls` is near ERROR #5290's limit.
  - `AnalyticsProbe` follows `ProductionProbe`.
  - `AnalyticsGate` follows `InteropLookupGate`, and `AnalyticsGateSeam` follows `InteropGateSeam`.
  - The descriptors and the browser spec extend their named siblings.
- **One copy.** `analytics.test.mjs` repeats a few of `interop.test.mjs`'s file-local lines, because a shared module would couple two areas' tests.

**Contended files (Rule 11).**

- Epic 23's open branch `origin/OCU-1-epic23` (`132bd11f`) touches none of the 42 paths. `log-viewer.spec.ts` is not touched.
- Every edit to a shared roster is add-only, except the named message and Decided in-stage 4.
- These stay untouched: `app.routes.ts`, `angular.json`, `Prohibited.cls`, `Baseline.cls`, `LogSourcePort.cls`, and the CI files.

**Named limits.**

- Member values are not shown.
- `Last build` is empty when no tracked build or repair is recorded.
- Subject areas and abstract cubes are not listed.
- A term list is read whole, and the vendor opens every folder item, before the cap.
- A relationship to a cube the caller cannot see is still named.
- In a namespace without analytics, a list read draws the shell's generic refusal. The wire carries the 409 sentence, as interop's does.

**Weight.**

- No page code and no lazy chunk.
- The set-aside build measured 1.98 MB initial (351.88 kB transfer).
- HEAD is at 1.97 MB, so about 1.99 MB is expected (inference), under the fixed 2500 kB warning and 4000 kB error.

## Verification

**Shared surfaces:**

- **The read source kinds:** the "fifteen sources" sentence in `Registry.cls`, in `screen-mirror.mjs` and in five test classes, and `screen-mirror.test.mjs`'s port list.
- **Server rosters:**
  - the `EntityType` count, and `PortGate`'s `ROSTER`;
  - `StageTwoTools`' `Elsewhere`, `SurfaceCoverage`'s screen rows, `ReadTool`'s count and names, and `ToolRoundTrip`'s `REFUSEEMPTY`;
  - `Navigation.cls`' analytics block;
  - `InteropFloor`'s `BASESCREENS` and `BASETOOLS`, and `DeveloperFloor`'s `SCREENS`, `TOOLS` and tools-count comment;
  - `RowTargetCorpus`' `Cases`.
- **Client rosters:**
  - `navigation.test.mjs`' routes, and `screen-mirror.test.mjs`' owners;
  - the structural walk's `SKIP` and its baseline;
  - `ci-throwaway.sh`'s arming roster;
  - the strings table, EXPERIENCE.md :159 and :604, and `strings.test.mjs`' namespace-key roster and credential-name exemptions.
- **Counts and state:** the built-screen count Screen permissions derives (+7), and USER's analytics flags while a probe runs.

*Every test added or changed passes on a fresh environment, in either order.* `AnalyticsProbe` creates and removes everything it asserts on, and restores USER's flags.

**Setup (slot B, the throwaway only; never the dev instance `ocupilot-slot-b`):**

- `(loop)` **Load `src`:**
  1. Run `rsync -a --checksum --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-20/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`.
  2. In `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`, run `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)`.
- `(loop)` **Before any browser run:** `cd ui && npm run build && docker exec ocupilot-b-ci sh -c 'cd /durable/iris/csp/ocupilot && rm -rf ./*' && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`.

**Commands.** Run each in the foreground with `timeout: 600000`, one at a time, and read results from `%UnitTest_Result`.

- `(loop)` Run `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.AnalyticsPort`.
  - Then, one call each, the same runner with `--class OcuPilot.Test.AnalyticsGate`, and with `--class OcuPilot.Test.AnalyticsDescriptor --class OcuPilot.Test.PortGate`.
  - Expected: green. No timing is recorded for these classes.
- `(loop)` Run the same runner, in one call, with `StageTwoTools`, `SurfaceCoverage`, `ReadTool`, `ToolRoundTrip`, `ToolEmit`, `Navigation`, `Wire`, `Descriptor`, `NamespaceFeatures`, `ScreenAccessWire`, `SqlActivityDescriptor`, `DocDbDescriptor`, `InteropDescriptor`, `MetricsDescriptor`, `InteropFloor` and `DeveloperFloor`.
  - `ReadTool` runs `AdminPairCorpus`, and `Descriptor` runs `RowTargetCorpus`.
  - Expected: green, in about 140 s by `ci-timings.json`.
  - Then run every class the roster sweep changes.
- `(loop)` `cd ui && npm run test:tools`, then `cd ui && npm run test:components`. Expected: green.
- `(loop)` `cd ui && npm run build -- --verbose`. Expected: the prebuild chain is green, there is no new lazy chunk, and the initial total is under 2500 kB. Record the total.
- `(loop)` `uv run scripts/check-objectscript.py <each changed .cls>` and `bash scripts/lint-docs.sh`. Expected: clean.
- `(loop)` After the redeploy, one file per call: `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/<file>`. Expected: green.
  - `analytics.browser-spec.mjs`
  - `namespace-categories.browser-spec.mjs`
  - `a11y-structural-invariants.browser-spec.mjs` (about 430 s)
  - each spec the roster sweep changes
- **Lead-owned (the runner's):** the full ObjectScript sweep, `cd ui && npm test`, `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`, and Rule 30's fresh check.
- **Left to CI:** the full browser suite.

**Pinning mutations (Rule 19).**

- Each was applied on `ocupilot-b-ci`, observed red, and reverted byte-identical; the tree was reloaded, or the bundle rebuilt and redeployed, before the next.
- The lines marked **[re-demonstrate]** are re-run by the implement stage after Task 0, because their code under test moved in the merge. **[new]** lines are run for the first time. The rest still hold from `11bcb1fa`, since their code under test is unchanged.

- mutation: the Cubes read answers `Facts` as 0 -> `AnalyticsPort.TestCubesEqualTheVendorsAnswer` and the browser AC1.
- mutation: the Dimensions read also calls `%GetMemberTree` -> `AnalyticsPort.TestTheReadsWriteNothing`, alone.
- mutation: Folder items reads favorites through `%GetFavoritesForUser` -> `AnalyticsPort.TestTheReadsWriteNothing` and `TestFolderItemsAnswerTheVendorsList`.
- mutation: **[re-demonstrated by QA]** the Relationships tab drops `rowTarget` (mirror regenerated, bundle redeployed) -> the browser AC2 related-cube leg (`clickRowCentre: the row carries no .ocu-data-table-link`). The registry, the mirror generator and the mirror all moved.
- mutation: `%ToObj`'s extra fields are not joined into `Fields` -> `AnalyticsPort.TestTermListsAndEntriesAnswerTheVendorsList` and the browser AC2.
- mutation: `Admit` omits the analytics check -> `AnalyticsPort.TestANamespaceWithoutAnalyticsIsRefusedOnEveryEndpoint` and the browser AC3.
- mutation: `Admit` omits the globals-database READ check -> `AnalyticsGate.TestAPrincipalWithoutTheDatabaseIsRefusedNamingIt`.
- mutation: `Admit` omits the routines-database READ check -> `PortGate.TestEveryPortEvaluatesItsDeclaredGate`, in its routines leg.
- mutation: `TERMLISTPAIRS` loses `%DeepSee_PortalEdit:USE` -> `AnalyticsGate.TestTermListsNeedTheTermListManagersPair`, `PortGate.TestEveryPortEvaluatesItsDeclaredGate` and `analytics.test.mjs`.
- mutation: the tabs skip `%CubeExists` and `%CheckPrivilege` (the guard reads `If 1`) -> `AnalyticsGate.TestTheVendorsOwnResourceChecksStillHideWhatTheyHide`, at the reader's Measures and Dimensions legs, and `AnalyticsGate.TestAGuardedCubesRelationshipsAreHiddenFromWhoLacksItsResource`, at the Relationships leg.
- mutation: `Screen/Tool/Read.View` drops `LastBuild` -> `AnalyticsGate.TestTheAgentsCubesReadAnswersTheScreensRows`.
- mutation: the analytics branch of `Screen/Read` asks for `maxRows` rows rather than one more -> `AnalyticsGate.TestTheVendorsOwnResourceChecksStillHideWhatTheyHide`, at the Cap row.
- mutation: the FolderItems loop ignores `maxRows` -> `AnalyticsPort.TestTheRequestShapesTheGateAndThePortRefuse`.
- mutation: `LocalStamp` answers its input unconverted -> `AnalyticsPort.TestTheTimeShapesAreTheInstancesLocalTime`, in its two `TZ` legs.
- mutation: `Fail` puts the vendor's text into the reason -> `AnalyticsPort.TestAVendorFailureIsAnsweredInThePortsWordsAndLoggedWhole`.
- mutation: the `ANALYTICS.` line is dropped from `Error.ReasonForToolCode`, or from `ReasonForViolation` -> `AnalyticsDescriptor.TestTheAnalyticsCodeReadsItsOwnSentence`, alone, each.
- mutation: the `AnalyticsCubeList` `Elsewhere` row is removed -> `StageTwoTools.TestTheRosterAndElsewhereAreEveryRegisteredScreen`, alone.
- mutation: **[re-demonstrated by QA]** `.ocu-data-table-cell` takes `color: var(--ocu-surface-container-high)` -> the browser AC5 (`analytics/cubes|contrast|dark`, also `|light`). The bundle it inspects changed with 20.12.
- mutation: **[new]** the tab arm is dropped from `RowTargetProblem` -> `Descriptor.TestEveryRowTargetCorpusCaseGetsItsSentence`, at the tab case (the shipped Relationships tab also reddens the roster tests beside it). Then the same from `rowTargetProblem` -> `screen-mirror.test.mjs`' corpus test, at the tab case (the mirror build tests redden beside it).
- mutation: **[new]** one word of `analyticsRefusalNamespace` changes in `strings.ts` -> `analytics.test.mjs`. `strings.ts` and EXPERIENCE.md :604 are the union's two files.
- mutation: `Remove` skips the flag restore -> `OnAfterAllTests` of `AnalyticsPort` and `AnalyticsGate`, and the browser `after`.
- mutation: `Remove` restores `DeepSeeEnabled` and not `iKnowEnabled` -> `OnAfterAllTests` of `AnalyticsPort`.
- mutation: **(QA)** the Relationships endpoint alone skips the `%CubeExists` and `%CheckPrivilege` test -> `AnalyticsGate.TestAGuardedCubesRelationshipsAreHiddenFromWhoLacksItsResource`, alone.
- mutation: **(QA)** the analytics branch of `Screen/Read` skips its required-criterion check -> `AnalyticsGate.TestAMissingCriterionIsRefusedBeforeThePort`, alone, in all six legs (the port answers `PORT.VALIDATION` instead).
- mutation: **(QA)** `Screen/Tool/Read.View` drops the criteria it was given -> `AnalyticsGate.TestEveryReadToolAnswersItsScreensRows`, in the four tools that take one.
- mutation: **(QA)** `Screen/Tool/Read.View` drops `LastBuild` (re-run: the tool probe now runs through `ToolLeg`) -> `AnalyticsGate.TestTheAgentsCubesReadAnswersTheScreensRows` and `TestEveryReadToolAnswersItsScreensRows`.
- mutation: **(QA)** `FOLDERPAIRS` loses `%Development:USE` -> `AnalyticsGate.TestFolderItemsNeedTheDeveloperResource`, alone, at the viewer's port leg.
- mutation: **(QA)** the entries join their fields with `, ` -> `AnalyticsPort.TestAMultiFieldTermListJoinsItsFieldsInOrderAndTheCapBoundsTermLists`, alone.
- mutation: **(QA)** the TermLists loop ignores the cap -> the same test, alone, at its cap leg.
- mutation: **(QA)** `Rows` answers a failed fact count as 0 -> `AnalyticsPort.TestAFailedFactCountIsNullAndAnEmptyCubeIsZero`, alone.
- mutation: **(QA)** `AnalyticsCubeMeasuresTab` names `analyticsCubesEmpty` as its `emptyStateKey` (mirror regenerated, bundle redeployed) -> the browser Matrix leg, at the Measures screen.
- mutation: **(CR)** `Collect` reads a measure's caption, type and hidden flag with `$List`, not `$ListGet` -> `AnalyticsPort.TestTheCubeTabsAnswerTheModel`, alone, at the guarded cube's calculated-measure leg (run 802).
- mutation: **(CR)** the entries read increments a node under the probe term list -> `AnalyticsPort.TestTheReadsWriteNothing`, alone, at its TermListEntries leg (run 804); a write of an unchanged value is not seen, since the snapshot compares values.
- mutation: **(CR)** `AnalyticsProbe.Remove` deletes build events through `%SQLUPPER(CubeKey) %STARTSWITH` -> `OnAfterAllTests` of `AnalyticsPort`, naming "build events" (run 805).
- mutation: **(CR)** `AnalyticsProbe.Remove` keeps the probe favorites -> `OnAfterAllTests` of `AnalyticsPort`, naming the favorite's user (run 806).
- mutation: **(CI)** `Session.postLogin` drops the wait on the in-flight sign-out -> `session.test.mjs`' four hold tests (submit, silent probe, abandon window, bound); `probeAndSettle` posting `/login` without the wait -> the silent-probe test, alone; the in-flight marker never cleared -> the settled-sign-out test, alone; `postLogin` waiting on the sign-out with no bound, or `LOGIN_AFTER_SIGN_OUT_WAIT_MS` shrunk to the abandon wait plus 1 ms -> the bound test, alone in each; the in-flight marker counted only once the `/logout` is sent -> the abandon-window test, alone.

**(QA) test files changed** (none created; the four analytics classes, the helper, the seam and the browser spec):

- `src/OcuPilot/Test/AnalyticsProbe.cls` (QA): `CreateLinks` makes a guarded cube that defines a relationship, `CreateTermListTwo` and `DeleteTermListTwo` a second term list; `Remove` and `Left` cover both.
- `src/OcuPilot/Test/AnalyticsGate.cls` (QA): the viewer principal, `TestAGuardedCubesRelationshipsAreHiddenFromWhoLacksItsResource`, `TestAMissingCriterionIsRefusedBeforeThePort`, `TestEveryReadToolAnswersItsScreensRows`, `TestFolderItemsNeedTheDeveloperResource`; the cube-name lists of the existing guard test count the link pair.
- `src/OcuPilot/Test/AnalyticsPort.cls` (QA): `TestAMultiFieldTermListJoinsItsFieldsInOrderAndTheCapBoundsTermLists`, `TestAFailedFactCountIsNullAndAnEmptyCubeIsZero`, and an `OnAfterOneTest` that deletes the second term list.
- `src/OcuPilot/Test/AnalyticsGateSeam.cls` (QA): `CubeRowFor`.
- `ui/browser/analytics.browser-spec.mjs` (QA): the Matrix test for a cube or term list no one holds.

**Evidence from the set-aside pass (`11bcb1fa`, before the merge):**

- 4 analytics classes (21 tests) and 16 sweep classes (203 tests) were green.
- `test:tools` passed 2,040 and `test:components` 3,272.
- The build was green at 1.98 MB.
- `check-objectscript.py` and `lint-docs.sh` reported 0.
- The browser specs `analytics` (4 of 4), `namespace-categories` (4 of 4) and `a11y-structural-invariants` (13 of 13) passed.

## Auto Run Result

Status: done
Blocking condition: none

- **This pass (implement, 2026-10-21): the `[CI]` rework, now ticked.**
  - `Session.postLogin` holds every `/login` until a sign-out still in flight settles, for at most `LOGIN_AFTER_SIGN_OUT_WAIT_MS` (8,000 ms: the abandon's 3,000 plus 5,000 for the `/logout`). The form submit (`formLogin`) and the silent probe (`probeAndSettle`, which the backoff and refused-refresh re-probes share) both post through it; `/refresh` does not.
  - The sign-out is in flight from its `/turn/abandon` until its `/logout` settles (`signOutInFlight`). The tab still clears and settles first (DW-5). The abandon's settle-or-bound logic is now `settleWithin`, shared by both waits.
- **Files changed (3):** `ui/src/app/core/session.ts`; `ui/tools/session.test.mjs` (five tests, one helper, the constant's import); this spec (the item ticked, one `mutation:` line, the triage entry).
- **Review:** 9 findings, 2 patched (both low), 0 deferred, 7 rejected with their reasons in the triage log. Follow-up review recommended: false (a follow-up pass that patched no high).
- **Verification (slot B):**
  - `session.test.mjs` 125 of 125; `test:tools` 2,057 and `test:components` 3,290 green; `tsc --noEmit -p tsconfig.app.json` clean; `npm run build` green.
  - The bundle was redeployed to `ocupilot-b-ci` and `panel.browser-spec.mjs` passed, 13 of 13.
  - Mutations (Rule 19), each red on the named test and reverted byte-identical: the line under Verification.
- **Residual risk:** the panel spec failed before the fix only on a freshly started throwaway, and this one was already up, so its pass shows no regression and does not show the race closed; the runner's fresh-throwaway re-run is that check.
