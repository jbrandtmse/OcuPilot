---
title: 'Story 24.11: Listing groups (Batch 2: the seven writes)'
type: 'feature'
created: '2026-11-18'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-11-listing-groups.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-2-the-analytics-editors.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-10-folder-manager-transfer-and-term-list-import-export-and-copy-2.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Batch 1 (`spec-24-11-listing-groups.md`, `done`, code head `d65c399a1`) lets a person and the agent read listing groups and their listings, but nobody can create, change, copy or delete one from OcuPilot. The story's criterion is a round trip over the backing class, a class extending `%DeepSee.ListingGroupDefinition`.

**Approach:** The seven writes in Batch 1's Design Notes (Batch 2 preview), each one confirmed proposal with two callers. They go through `AnalyticsPort`, which composes the group's class from a fresh model and saves, compiles and deletes it through `AtelierPort`, as `DevToolPort.Promote` does (runner ruling U-108). A compile that fails restores the prior definition, so nothing is half-applied.

## Boundaries & Constraints

**Always:**

- **Tools and keys (AD-22).** `analytics.listinggroups.add`, `.update` and `.copy`, and `analytics.listinggrouplistings.add` and `.set`, ship `true`. `analytics.listinggroups.delete` and `analytics.listinggrouplistings.remove` are `DESTRUCTIVE` and ship `false`; each confirms with a typed name and its consequence, as 24.10's folder-item delete does.
- **Gate, refused by name before any write (AD-8, AD-29, AD-61 rule 1).**
  - The listing group read pairs (`LISTINGGROUPPAIRS`).
  - `%DeepSee_ListingGroupEdit:USE` (measured in Batch 1: `CheckListingGroupWriteAccess`).
  - `AtelierPort.WritePairs(namespace)`, which adds `%Development:USE`. This is stricter than the classic page (U-108).
  - WRITE on the database `^DeepSee.ListingGroups` maps to.
  - `%DeepSee_ListingGroupSQL:USE` when a write sets or changes a listing's SQL.
  - WRITE on the group's `resource` when it names one (classic `canWrite` :695). A copy needs it only on the copy's own resource.
- **Composition.** Every write composes the whole model from `%GetModel(class)` read at the write. It never composes from the screen rows, so SQL hidden from the caller is kept as stored. The model is serialized by the vendor's own writer, as `%SaveToClass` (`Model/ListingGroup/listingGroup.cls` :91) writes it. An update or listing write replaces only the class's `Listings` XData and its `DependsOn`. Every other line of the class text is kept.
- **Write path.** `AtelierPort` `TYPECREATE` for add and copy, `TYPESAVE` with the version read for the others, then `TYPECOMPILE`, and `TYPEDELETE` for delete. The fingerprint covers that version, so a class changed after the mint closes the proposal.
- **Pre-checks, each with its own code before any write.** A taken group name or class. A class name that is malformed, begins with `%`, or is in an `OcuPilot` package. A target cube that is missing or refuses listing groups. A listing name the group repeats, or that a target cube or another group already defines (`ListingGroupDefinition.cls` :78-130). A group name that two classes declare: this addresses DW-2719, because these writes are keyed by group name. The codes are the `ANALYTICS.LISTINGGROUP.*` set in the matrix, plus `ABSENT` and `READONLY` as the term list has them, each with its own sentence in `Api/AnalyticsError.cls`.
- **Compile failure.** For update and the listing writes, the prior text is saved back, and recompiled only if the fresh read had `Compiled` true. For add and copy, the new class is deleted. The answer is 422 `ANALYTICS.LISTINGGROUP.COMPILE`. The compiler's text is logged and never sent (AD-39).
- **Audit and the rest of the write set.** Each write records `ConfigChange` from either caller, including a restored one with its outcome (AD-15). Each has a script form (AD-59) and a read-back (AD-58): `READBACKFIELDS`, and absence for delete and remove.

**Never:**

- `%SaveToClass`, `%SaveListingGroup`, `%DeleteListingGroup`, `$system.OBJ.*`, `%RegisterRecentItem`, `/api/deepsee` or `/api/atelier` over HTTP. `AnalyticsPort` names no `%Api.Atelier.*` class (AD-61).
- AD-15's partial cube update, or anything that touches U-34. That question belongs to 24.13.
- A listing rename, or a group rename other than through copy.
- Changes to the spine. Any edit to a contended file other than an addition, except the roster unions in Design Notes › Decided in-stage 6.

## I/O & Edge-Case Matrix

The rows run in USER on `ocupilot-b-ci`. Each test makes and removes its own marked listing-group classes in the `OcuPilotProbe.Analytics` package (AC6).

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Add | A new name and class over the probe cube | The group is compiled and listed with `Compiled` true; the read-back matches | - |
| Add refused | A name or class taken; a missing cube; a `%` or `OcuPilot.` class | Nothing is written | 409 `ANALYTICS.LISTINGGROUP.TAKEN`; 422 `.CUBE`; 422 `.CLASS` |
| Update | Caption and cubes, on a group with a hidden SQL and an extra class member | The fields change; the SQL and the member are unchanged | - |
| Copy | A new name and class, other target cubes | A new compiled group; the source is unchanged | - |
| Copy refused | The same cubes as an enabled source | Nothing is written | 409 `ANALYTICS.LISTINGGROUP.LISTINGTAKEN` |
| Delete | Typed name; the key turned on by the test | The class and its `^DeepSee.ListingGroups` nodes are gone | - |
| Listing add, set, remove | A listing of the group | The model holds exactly the change; the read-back matches | - |
| SQL | Set a listing's SQL without the SQL pair | Nothing is written | 403 naming `%DeepSee_ListingGroupSQL:USE` |
| Twin | Two classes declare the group's name | Every write is refused before any write | 409 `ANALYTICS.LISTINGGROUP.AMBIGUOUS` |
| Compile fails | A test seam fails the compile after the pre-checks | The prior text is back, or the new class is gone | 422 `ANALYTICS.LISTINGGROUP.COMPILE` |
| Stale | The class changes between the mint and the confirm | The proposal closes as target-changed | 409 |
| Key off | A destructive tool at its shipped `false` | Governance refuses it | 403 |
| Gate | No `%Development:USE`; no `%DeepSee_ListingGroupEdit:USE` | Refused before any write | 403 naming the pair |

</intent-contract>

## Code Map

Paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-24` (HEAD `a8e43794e`). **(contended: add-only)** marks a file that Epic 21 has changed beyond feature (`git log origin/OCU-1-epic21 ^origin/feature/OCU-1_ocupilot-mvp`, checked 2026-11-18).

- **`src/OcuPilot/Port/AnalyticsPort.cls`** (4,355 lines). This is the write path, extending the term-list write pattern:
  - `Serves` :460 and `IsTermListType` :494; dispatch from `Invoke` :542 to a new `InvokeListingGroup`, beside `InvokeTermList` :2797 and `PerformTermList` :2869;
  - the single-object fresh reads (`LISTINGGROUP`, `LISTING`, and a copy target as in 24.10's `COPYTARGET`) with the class version;
  - the violations (`TermListViolations` :2526 is the shape), `AuditWrite` :2258 and `Snippet` :2291.
  - Add `AtelierPortClass()`, overridable as `DevToolPort.AtelierPortClass` :339 is, so a fixture can fail the compile. `AnalyticsTermListSeam.cls` is the seam test's shape.
  - `Admit` :640-642 needs its own listing-group branch, because a write there now falls through to the cube check (`FACTGLOBAL`).
- **`src/OcuPilot/Port/DevToolPort.cls`**: the sibling the write path extends (Rule 2). `Promote` :1537 shows the `AtelierPort.Invoke` calls, `ReadVersion` :1803 the version read and `Snippet` :1890 the script form. Lift `ReadVersion` into a shared helper rather than copying it.
- **`src/OcuPilot/Port/AtelierPort.cls`**: read only. `WritePairs` :788, `Invoke` :874, `SaveSet` :2545 (create and save), `CompileSet` :1896, `DeleteSet` :1933.
- **Tools, in `src/OcuPilot/Screen/Tool/`.** These are new.
  - `AnalyticsListingGroupAction` extends `AnalyticsAction`, as `AnalyticsTermListAction.cls` does: `DESTINATIONGLOBAL` `^DeepSee.ListingGroups`, and `PrivilegePairs` adds the edit pair and `WritePairs`.
  - `AnalyticsListingAction` follows `AnalyticsTermListEntryAction.cls`, with the composite id `[ListingGroup, Name]` and a mint as `AnalyticsTermListEntryMint` builds one.
  - The seven tools take the shapes of `AnalyticsTermList{Add,Update,Copy,Delete}` and `AnalyticsTermListEntry{Add,Set,Remove}`.
- **Descriptors:**
  - `AnalyticsListingGroupList.cls` gains `primaryAction` `add` and `rowActions` `update`, `copy` and `delete`.
  - `AnalyticsListingGroupListingList.cls` (rows 29-30) gains `add`, `set` and `remove`.
  - On both, `table.emptyAgentKey` replaces `emptyNextKey`, as a write-capable descriptor requires (`ui/tools/screen-mirror.mjs` :3404-3410). Each doc's "offers no action" sentence is replaced.
- **Screens' own Saves (AD-55):** `src/OcuPilot/Area/Analytics/ListingGroup{Save,Form}.cls` and `ListingSave.cls`, modeled on `TermList{Save,Form}.cls` and `TermListEntrySave.cls`. Their routes go in `Api/Router.cls` :275-277 **(contended: add-only)**.
- **Client:** `ui/src/app/areas/analytics/` gains listing-group pages, dialogs and a store, modeled on the `term-list-*` files. These maps gain entries, each **(contended: add-only)**:
  - `ui/src/app/shell/screen-outlet.ts` `DESCRIPTOR_PAGES` :104;
  - `ui/src/app/shell/screen-action-handler.ts`: `SCREEN_ACTION_DESCRIPTORS` :70, `UNDRAWN_ACTIONS` :471, `DESTRUCTIVE_CONSEQUENCES` :641 and `TYPED_NAME_ROWS` :759;
  - `ui/src/app/core/screen-actions.ts` `DESCRIPTOR_ACTION_LABELS` :170.

  `screen-action-handler-termlist.spec.ts` is the model for the typed-name spec. Also `ui/src/app/core/strings.ts` :8072-8160 **(contended: add-only)**, `proposal-view.ts` (the consequences) **(contended: add-only)**, and `screens.generated.ts`, regenerated.
- **Kernel and API:**
  - `Kernel/Governance/Baseline.cls` :262-273, the seven keys **(contended: add-only)**;
  - `Api/AnalyticsError.cls` :97-210, the new codes and sentences;
  - `Kernel/Proposal/Prohibited.cls` **(contended: add-only)**. Add `listing-group` and `listing-group-listing` types beside `TYPETERMLIST` and `TYPETERMLISTENTRY`, with change and create lists (AD-54); see :767-769, :1290, :1459, :1543, :1704 and :1915. The rule against an `OcuPilot` class belongs here (AD-10), where the class type's rule for OcuPilot's own classes is (inference).
- **Rosters (Rule 30).** These are the files where the term-list and folder-item write tools are pinned (grep, 2026-11-18). All of the following are **(contended: add-only)**:
  - `ReadTool` :93-94 (the registry count and names);
  - `SurfaceCoverage` :284-293;
  - `Governance` :69-72 (add a `LISTINGGROUPDISABLED` line);
  - `GovernanceBaseline` :15;
  - `ClassicPageGate` :76 and :656-659;
  - `MappingDescriptor` :24;
  - `ToolRoundTrip` :106;
  - `EndpointCoverage` :289-291 (the new routes);
  - `ui/tools/screen-mirror.test.mjs` :2755-2756 and :3528-3529;
  - `ui/src/app/core/proposal-view.ts`.

  Also these, from the registration trace (2026-11-18):
  - `Test/ToolEmit.cls` :263-277, a listing-group `ElseIf` before the cube branch **(contended: add-only)**;
  - `Test/ToolDispatch.cls` :193-194, the disabled parameters **(contended: add-only)**;
  - `Test/Prohibited.cls` :233 and :461 **(contended: add-only)**;
  - `Test/AnalyticsDescriptor.cls` :141-142, the action and empty-state pins;
  - `Test/CompositeMintSweep.cls` :61, the listing mint's row;
  - `Test/SaveHoldCoverage.cls` :106-108, the new routes;
  - in `ui/tools/analytics.test.mjs`, the tool lists :334 and :395, the consequences :348-360 and :409-416, and the vendor-call pins :362-382 and :418-426. Rewrite the last so the port still never calls `%SaveToClass` or `%DeleteListingGroup`.

  The implement stage re-runs the grep, adds every file it finds, and lists the set under Verification.
- **Fixture:** `Test/AnalyticsProbe.cls` (`LISTGROUP*` :117-147, `CreateListingGroups`, `RemoveListingGroups`, `Left`).
- **EXPERIENCE.md:** one Fixed strings row after :611, in the form of 24.10's row at :610. It also replaces the sentence in :611 that says neither screen offers an action.
- **Vendor (read only):** `irislib/%DeepSee/ListingGroupDefinition.cls` (`%Generate` :55-160), `ListingGroup.cls` (`%DeleteListingGroup` :99), `Model/ListingGroup/listingGroup.cls` (`%SaveToClass` :91, `%Validate`), `listing.cls`, `UI/ListingGroupManager.cls` (`SubmitListingGroupContent` :644, `canWrite` :695, `onPopupAction` :1139).

## Tasks & Acceptance

**Execution:**

- [ ] **Task 0, on `ocupilot-b-ci` only, with marked classes removed afterwards.** Measure each of the following and record it under Design Notes › Measured:
  - that `AtelierPort` `TYPEDELETE` of a compiled group removes its `^DeepSee.ListingGroups` nodes, as `%DeleteListingGroup` did in Batch 1 (inference: both reach `Delete^%apiOBJ`);
  - what a refused compile leaves behind, and that a restore re-registers the prior group;
  - that the vendor's XML writer journals nothing;
  - that the spliced text round-trips byte-identical outside `Listings` and `DependsOn`.
- [ ] `AnalyticsPort.cls`: the reads, the writes, the pre-checks, the restore, the audit and the script forms.
- [ ] The two action bases, the seven tools, the descriptor edits, the three `Area` classes and their routes, `Baseline.cls`, `AnalyticsError.cls`, the client, the strings (once ruled), the regenerated mirror and the EXPERIENCE.md rows.
- [ ] Tests:
  - new `Test/AnalyticsListingGroupWrite.cls` (the group writes) and `Test/AnalyticsListingWrite.cls` (the listing writes and SQL);
  - new `Test/AnalyticsListingGroupWriteEdge.cls` (the twin, the compile-fails seam, stale, key off and the gate);
  - `AnalyticsListingGroupWriteEdge` uses probe principals, so it is armed by `OCUPILOT_ALLOW_PRINCIPALS` and rostered in `scripts/ci-throwaway.sh` **(contended: add-only)**, as 24.10's `AnalyticsFolderItemGate` is;
  - in `ui/browser/analytics.browser-spec.mjs`, add, edit, add a listing, then a typed-name delete;
  - every roster under Code Map.

**Acceptance Criteria:**

- **AC1 (round trip, both callers).** Given a group made by each write, through the screen action and through the agent's confirmed proposal. When Batch 1's reads and `%GetModel` read it. Then they hold exactly what was sent, and every class line outside `Listings` and `DependsOn` is unchanged.
- **AC2 (Integration, Rule 1).** Given each write. When it is confirmed. Then Batch 1's `GET /screens/analytics.listinggroups/read` and `analytics.listinggrouplistings.read` answer the new state, and the read-back verdict is `matches` (`gone` for delete and remove).
- **AC3 (nothing half-applied).** Given the compile-fails seam on each write. When it runs. Then the class text and the compiled list equal their state before the write.
- **AC4 (browser).** Given the probe cube. When a person creates a group, edits it, adds a listing and deletes the group by typing its name. Then each screen shows each change.
- **AC5 (governed, audited, declared).** Given the seven tools. When the roster tests run. Then each declares `write`, `AnalyticsPort` and `%DeepSee.UI.ListingGroupManager`. The baseline holds five keys at `true` and two at `false`. Each write records `ConfigChange`. Removing any one roster row reddens that test alone.
- **AC6 (leaves USER as found).** Given any new or changed test, in either order, on a fresh instance. When it ends. Then no marked class and no marked `^DeepSee.ListingGroups` node remains.

## Spec Change Log

- 2026-11-18, spec gate: the runner kept the copy-target rule, the key states, the duplicate-name refusal, the proposed strings and the proposed spine lines (veto item U-110). The in-line roster edits in files Epic 21 has changed are held for the orchestrator's ruling before implement.

## Design Notes

**Ruled (runner, U-108; not re-opened).** The writes go through `AtelierPort`, and the siblings they extend are `DevToolPort.Promote` and `AtelierPort` (Rule 2). The helper is shaped for Story 24.12. A failed compile restores the prior definition. Delete confirms with a typed name. Reads stay on Batch 1's narrowed pairs. Batch 1's strings are kept.

**Decided in-stage (plan).**

1. Writes are keyed by group name, the id the read rows carry. A name that two classes declare is refused rather than resolved, because it is safer.
2. Copy takes `NewName`, `NewClass` and optional `TargetCubes`. The vendor refuses a listing that another group already defines in a cube (`ListingGroupDefinition.cls` :124-130), so a compiled copy into the same cubes as an enabled source is refused by name. The classic Save As does not compile its copy.
3. Every write compiles, as ruled. A disabled group compiles without registering, as Batch 1 measured.
4. A restored write still records `ConfigChange`, with its outcome, because its class was briefly changed.
5. The pairs of a write that sets SQL are judged at the mint and again at the write, as Batch 1's SQL rule is judged in `Invoke`.
6. **Contention.** Some edits to contended files are within a line rather than added lines:
   - the `ReadTool` count literal at :93;
   - the one-line lists in `GovernanceBaseline` :15, `ClassicPageGate` :76 and `MappingDescriptor` :24;
   - the `ToolRoundTrip` :106 list;
   - `Prohibited.cls`'s one-line type condition at :1543.

   Each is a roster union, and the integrate-forward resolves it (Rule 22, `resolve-plain`). Everything else is appended. Batch 1 changed the same count. The runner rules this exception.

**Proposed strings (veto; added to EXPERIENCE.md only once ruled).**

- Kept from Batch 1: the agent empty-state phrases "create a listing group" and "add a listing to this listing group".
- Actions: "New listing group", "Edit", "Copy", "Delete"; "Add listing", "Change listing", "Remove listing".
- Labels: "Class", "Default resource", "Resource", "Disabled", "Order by", "Formats", "Select mode", "SQL query", "New name", "New class".
- Consequences, in the form of `analyticsFolderItemDeleteConsequence` (`strings.ts` :8122):
  - Delete: "Deleting this listing group deletes its class, and cubes lose its listings. This cannot be undone from OcuPilot."
  - Remove: "Removing this listing takes it out of its group, and cubes lose it. This cannot be undone from OcuPilot."
  - SQL: "This listing runs its SQL with the rights of whoever opens it."
  - Every write: "The listing group's class is saved and compiled."
- Refusals:
  - "This namespace already holds a listing group or class with that name."
  - "Name the class with letters, digits and dots, outside the % and OcuPilot packages."
  - "A target cube does not exist or does not accept listing groups."
  - "A listing of this group is already defined for a target cube. Choose other target cubes."
  - "Two classes define this listing group. Change it in its class instead."
  - "The instance refused to compile the listing group, so nothing was changed."
  - "This listing group or listing no longer exists."
  - "The database that holds listing groups is read-only."
- Prompts: none added. The registry's three per screen are Batch 1's.

**Governing ADs (Rule 6).** The write set is AD-3, AD-4, AD-6, AD-14, AD-15, AD-22, AD-34, AD-40, AD-51, AD-52, AD-53, AD-54 (add and copy), AD-55, AD-58 and AD-59. The gate and namespace are AD-8, AD-16, AD-29, AD-61 (the write pairs and rule 6's outcomes) and AD-65. Entity ids are AD-13. AD-39 covers the compiler's text and AD-10 the prohibited set.

**Proposed spine lines (the owner's attended update; never written here).**

- **AD-65:** "Listing group writes compose the class from `%GetModel` and save, compile and delete it through `AtelierPort` (AD-61), under `%DeepSee_ListingGroupEdit:USE` and `AtelierPort.WritePairs`. A failed compile restores the prior definition."
- **AD-22:** "`analytics.listinggroups.delete` and `analytics.listinggrouplistings.remove` ship `false`."

**Integration and linkage (Rules 1, 2).**

- `Consumes:` Batch 1's two reads; `AtelierPort`'s create, save, compile and delete; `DevToolPort.ReadVersion` (lifted); `AnalyticsAction`; `Area/Interop/ItemSave`.
- `Consumed-by:` Story 24.12, whose quality measures save and compile a class the same way, through the lifted helper.
- AC2 is the Integration AC.

**Ledger inbox:** none.

## Verification

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.AnalyticsListingGroupWrite`, then the same, one call at a time, for `AnalyticsListingWrite`, `AnalyticsListingGroupWriteEdge`, `AnalyticsListingGroupRead`, `AnalyticsListingGroupGate`, each roster class under Code Map, and every class the shared-surface sweep changes. Expected: green.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`. Expected: green.
- `(loop)` `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/analytics.browser-spec.mjs`. Expected: green.
- `(once)` the full ObjectScript sweep: `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17`, one call per shard for k = 1 to 17, as Batch 1 ran it. Expected: green.
- `uv run scripts/check-objectscript.py`, `bash scripts/lint-docs.sh`. Expected: clean.
- The full browser suite is left to CI.

**Shared surfaces:** the two listing-group descriptors' actions and empty states, the governance baseline, the write-tool rosters under Code Map, `Router.cls`'s routes, `AnalyticsError` codes and `ci-timings.json`, which has no rows for the new classes.

**Hermeticity:** every test added or changed passes on its first run on a fresh instance, and in either order. IRIS journals its own SQL statistics and statement-index records on first use (Batch 1), so no test counts journal records without Batch 1's engine exclusions.

**Mutations:** one `mutation:` line per AC, written by the implement stage.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

**Planned (Batch 2: the seven writes).** The plan meets READY-FOR-DEVELOPMENT and halts after planning, as asked. Three items are left for the runner's gate under Design Notes:

- the proposed strings, which are a veto item;
- Decided in-stage 2: copy into the same cubes is refused, while the classic Save As does not compile its copy;
- Decided in-stage 6: line edits in contended rosters, resolved as roster unions.

One pass is planned. If the runner prefers to split, the natural boundary is the four group writes plus the class-write helper, then the three listing writes. The plan read the vendor source, and its four measurements are Task 0's, on `ocupilot-b-ci`. The spec is `oversized`.
