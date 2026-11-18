---
title: 'Story 24.11: Listing groups (Batch 2: the seven writes)'
type: 'feature'
created: '2026-11-18'
status: 'done'
baseline_revision: 'ec633e8f9d15eefd74201e15277719d7aa7ece4f'
review_loop_iteration: 0
followup_review_recommended: true
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

**Review patches (open items only; one fresh pass).** Each new pinning test gets its `mutation:` line in `## Verification`; hermetic, first run on a fresh instance.

- [x] **P1** `Test/AnalyticsListingGroupWrite.cls` (or the class holding `TestEachRefusalWritesNothing`): COPY rows for a new name already a group (409 `TAKEN`), a new class already defined (409 `TAKEN`), a malformed new name (`PORT.FIELD.SHAPE`) and a `%` or `OcuPilot.` new class (422 `CLASS`), each asserting an unchanged `Snapshot()`.
- [x] **P2** `Test/AnalyticsListingGroupWriteEdge.cls`: a group saved with a `resource` and a caller holding every pair but WRITE on it is refused (403 naming that pair) on update, delete and copy; an add whose `Resource` the caller cannot write is refused; a copy needs it only on the copy's own resource. Snapshot unchanged.
- [x] **P3** `Test/AnalyticsListingWrite.cls`: an agent mint of `listinggrouplistings.add` and `.set` with SQL carries `ANALYTICS.LISTINGGROUP.SQL` as its consequence; a mint without the SQL pair is refused naming `%DeepSee_ListingGroupSQL:USE`.
- [x] **P4** `ui/src/app/areas/analytics/`: a page-level vitest spec mounting `ListingGroupListPage` and `ListingGroupListingListPage` asserting `add`, `update` and `copy` (groups) and `add`, `set` (listings) are registered, and that Change listing's `initial` carries the row's members. Remove listing needs no page entry (typed-name confirm in the handler); say so only if true.
- [x] **P5** Comment and fixture fixes: the browser spec's `TYPED_NAME_ROWS` comment states what is true; `Kernel/Proposal/Prohibited.cls` moves the added 24.11 block above the Story 20.5 comment it split (added lines only, nothing else on those lines changed); `Snapshot()` adds a checksum of the text; `Left()` reports leftover `classes` registry nodes and `LGW*` cube-listing nodes.


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

7. **Contention ruling (orchestrator, Option A; supersedes the in-line edit wording of item 6).** Epic 21's Story 21.14 also changes `Test/ReadTool.cls`, `Test/GovernanceBaseline.cls`, `Test/ClassicPageGate.cls`, `Test/MappingDescriptor.cls`, `Test/ToolRoundTrip.cls`, `Kernel/Proposal/Prohibited.cls`, `Test/Prohibited.cls`, `Test/ToolDispatch.cls`, `Test/ToolEmit.cls` and `Kernel/Governance/Baseline.cls`. In those ten files make only roster-union edits: add list entries, keys or branches, and change a roster count to the new derived value. The one logic edit allowed is the widened type condition in `Kernel/Proposal/Prohibited.cls`: one condition term added, nothing else on or around those lines changed. Record its exact before/after line under "Contended logic edit" below. Do not reformat, reorder or reword anything else in those files.

**Contended logic edit.** `Kernel/Proposal/Prohibited.cls` line 1561 (the one-line type condition of `Prohibits`). The line is otherwise byte-identical; the one term added is the new `IsListingGroupType` method's call, which names both types:

- before: `... && (tType '= ..#TYPEFOLDERITEM) && (tType '= ..#TYPESTARTUPSETTING) && ...`
- after: `... && (tType '= ..#TYPEFOLDERITEM) && '..IsListingGroupType(tType) && (tType '= ..#TYPESTARTUPSETTING) && ...`

Everything else in that file is added lines: the two type parameters, `IsListingGroupType`, the two `COVEREDTYPES` entries, the change and create field lists, and the create and reviewed-few branches.

**Measured** (Task 0, 2026-11-18, `ocupilot-b-ci`, USER; probe classes and groups removed afterwards):

- **Delete.** `AtelierPort` `TYPEDELETE` of the compiled probe group answered `deleted` and removed the class, its `groups` and `classes` nodes and the group's `cubes` listing nodes (`$Data` 1, 1, 10 before; 0, 0, 0 after).
- **Refused compile.** Saving the class with a missing target cube (`TYPESAVE`, `Compile` 0) and compiling it answered `errors` true with "Target cube does not exist". The class text stays as saved, `CompiledClass` stays present, and the group's registry nodes are gone (`$Data` 0, 0, 0; absent from the compiled list). Saving the prior text back and compiling it re-registered the group (1, 1, 10; present in the compiled list).
- **Journal.** `%XML.Writer` over the model, with `NoXMLDeclaration` and `Indent` as `%SaveToClass` sets them, wrote 928 characters and the journal scan of this process found 0 set or kill records.
- **Round trip.** The class text read through `TYPELIST` is the document's lines, the last of them empty; joined by a line feed it ends in one, and `TYPESAVE` writes it back as it was. The spliced text equals the original outside the `Listings` body and `DependsOn` in every test of `AnalyticsListingGroupWrite` and `AnalyticsListingWrite` (`Outside`). The writer adds `disabled="false"` and `selectMode="2"` where the source omitted them, so the XML differs from its source in those defaults while the model reads equal. The vendor's text service takes a carriage return and a line feed between lines; the Atelier save takes a line feed.
- **Found in the writes.** The relationship's keys keep a gap after `RemoveAt`, so the compose walks the listings by key. `AtelierPort.WritePairs` carries no `%Development:USE` (the source code API's own `PAIRS` do), so the gate adds `AtelierPort.Pairs()`.

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

**Mutations:**

- mutation (AC1): `Splice` made to keep the class header -> `AnalyticsListingGroupWrite` `TestAnUpdateChangesTheHeaderAndKeepsTheSqlAndEveryOtherLine` went red on the `DependsOn` leg alone (run 94); the SQL pair judged as held in the compose -> `AnalyticsListingWrite` `TestASqlChangeNeedsItsPairAndASilentOneKeepsTheSql` went red on its five legs without the pair (run 95).
- mutation (AC2): `Caption` answered empty in `ListingGroupRow` -> `AnalyticsListingGroupWrite` `TestAGroupIsAddedByEachCallerAndReadsBack` and `TestAnUpdateChangesTheHeaderAndKeepsTheSqlAndEveryOtherLine` went red on their read-back verdicts (run 107); `Version` blanked in `ListingGroupRow` -> `AnalyticsListingGroupWriteEdge` `TestAChangedClassClosesTheProposalAndTheBaselineShipsTwoKeysOff` went red (run 97).
- mutation (AC3): `RestoreListingGroup` made to return before it does anything -> `AnalyticsListingGroupWriteEdge` `TestARefusedCompileUndoesEachWrite` went red on the text, model, unregistered and snapshot legs (run 96).
- mutation (AC4): `LISTING_GROUP_PATH` made the term lists' route, bundle rebuilt and redeployed -> the browser spec's Story 24.11 write test timed out waiting for the new row; the listings' `TYPED_NAME_ROWS` entry dropped -> `screen-action-handler-listinggroup.spec.ts` went red on the composite-id leg. The groups' own entry is unproven by any mutation: a group's id is its name, so the dialog types the same text whether the entry is declared.
- mutation (AC5): `analytics.listinggroups.delete` shipped `true` in `Baseline.cls` -> `AnalyticsListingGroupWrite` `TestADeleteRemovesTheClassAndItsNodesAndShipsOff` went red (run 98); the `analytics.listinggroups.copy` row removed from `SurfaceCoverage` -> its write-tool test went red alone (run 99); the `analytics.listinggroups.update` entry removed from `ToolRoundTrip` -> its sweep went red alone (run 100); the listing set entry removed from `MappingDescriptor` -> its roster test went red alone (run 101); `analytics.listinggrouplistings.remove` removed from `GovernanceBaseline` -> its disabled-line test went red alone (run 102).
- mutation (AC6): `AnalyticsProbe.RemoveListingGroups` made not to delete the write marker's classes -> `AnalyticsListingGroupWrite` `TestAGroupIsAddedByEachCallerAndReadsBack` went red on the leftover groups (run 103).
- mutation (P1, copy refusals): the new-class half of `VendorListingGroupCompose`'s taken check dropped for a copy -> `AnalyticsListingGroupWrite` `TestEachCopyRefusalWritesNothing` went red on the class-taken leg alone (run 115); the copy dropped from `PlanListingGroup`'s class-shape check -> its `%`, `OcuPilot` and no-package legs and the free-copy leg went red (run 116).
- mutation (P2, resource guard): `ResourceDenied` made to answer 0 -> `AnalyticsListingGroupWriteEdge` `TestAGroupsResourceGuardsItsWrites` went red on its four refusal legs and the legs after them, and no other test did (run 117).
- mutation (P3, SQL mint): `AnalyticsListingAction.Consequence` made to answer the tool's own code -> `AnalyticsListingWrite` `TestAnAgentsSqlListingMintStatesItsConsequenceAndNeedsItsPair` went red on its two SQL consequence legs (run 118); `PlanListingGroup`'s SQL pair judged as held -> that test's two refusal legs and the existing SQL test's five legs went red (run 119). The mint-time refusal is 400 `TOOL.ARGUMENTS` carrying the privilege sentence, not the pair's name; the write's own refusal names the pair (`TestASqlChangeNeedsItsPairAndASilentOneKeepsTheSql`).
- mutation (P4, client): the `copy` registration dropped from `ListingGroupListPage`, the `set` registration dropped from `ListingGroupListingListPage`, `Type` read as empty and `Disabled` read as false in its `onOpenSet`, each alone -> `listing-group-list.page.spec.ts` went red on that page's one registration-and-open test; each reverted by `cmp`. No bundle is involved: the component runner builds from source.
- (P5) `Left()` was shown to report a seeded `classes` registry node and an `LGW` cube-listing node, and `""` after they were killed; the `Snapshot()` checksum, the `Prohibited.cls` block move and the browser spec comment are not behavior a test pins.
- Each server mutation was reverted by `cmp` against the saved copy, the whole tree reloaded and compiled into `ocupilot-b-ci`, and the class that went red was green after. The client ones were reverted by `cmp`, rebuilt and redeployed.

**Verification roster.** The grep for the write tools' pins over `src/OcuPilot/Test`, `ui/tools` and `ui/browser` found, and this pass changed: `ReadTool` (the count 491, the seven names, the write count), `SurfaceCoverage` (seven rows), `Governance` (`LISTINGGROUPDISABLED`), `GovernanceBaseline`, `ClassicPageGate` (`OWNPAIRS`, the principals' resources, the two enabled keys), `MappingDescriptor` (`CLASSICROSTER`), `ToolRoundTrip` (`REFUSEEMPTY`), `ToolDispatch`, `ToolEmit` (a listing group branch), `Prohibited` (the covered types, the copy's three values), `EndpointCoverage` (three probes), `AnalyticsDescriptor`, `CompositeMintSweep`, `SaveHoldCoverage`, `ToolWrite` (the other-port count 103), `AnalyticsProbe`, `ui/tools/analytics.test.mjs`, `ui/browser/analytics.browser-spec.mjs`, and `scripts/ci-throwaway.sh`. `PortGate`, `Descriptor`, `ToolNavigateContract`, `StageTwoTools` and `Navigation` ran green unchanged.

## Review Triage Log

### 2026-11-18 — Review pass

- verdicts: 20 findings — high 0, medium 4, low 16, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` Copy's own refusals (taken name, taken class, malformed name, `%`/`OcuPilot` class) have no test; the refusal table runs on ADD only — `VendorListingGroupCompose` can lose its `pNewClass` half unseen. Fix: COPY rows (task P1).
  - `[medium]` `[patch]` `ResourceDenied` (WRITE on the group's resource, on an add's resource, copy's own resource) is pinned by no test; making it `Quit 0` stays green — a caller could change a guarded group. Fix: task P2.
  - `[medium]` `[patch]` The agent's SQL listing mint: the `ANALYTICS.LISTINGGROUP.SQL` consequence and the mint-time SQL-pair refusal are never exercised. Fix: task P3.
  - `[medium]` `[patch]` Copy, Change listing and Remove listing controls run on pages no spec mounts; dropping the `copy` or `set` registration stays green. Fix: task P4.
  - `[low]` `[patch]` The groups' `TYPED_NAME_ROWS` entry has no mutation and the browser spec comment says it does; correct the comment at its origin (task P5).
  - `[low]` `[patch]` In `Prohibited.cls` the new 24.11 comment splits the Story 20.5 comment from the block it describes; move the added block above that comment, added lines only (task P5).
  - `[low]` `[patch]` `Snapshot()` fingerprints a class by text length and its doc comment overclaims; fingerprint with a checksum too (task P5).
  - `[low]` `[patch]` `AnalyticsProbe.Left()` does not report leftover `classes` registry nodes or `LGW*` cube-listing nodes that `RemoveListingGroups` kills; AC6 reads wider than the check (task P5).
  - `[low]` `[reject]` AC5 mutation line covers five of the roster edits — Rule 19 asks one demonstrated mutation per AC, and the rosters are declared-versus-derived completeness tests; not worth more lines.
  - `[low]` `[reject]` The refused-compile audit row is checked for existence, not its `restored`/`restorefailed` outcome — the `restorefailed` branch needs a second seam; a failed restore is logged and audited, and no user-reachable path was shown.
  - `[low]` `[reject]` `listing-group-dialogs.spec.ts` `settle()` is time-based — the stub answers immediately; no flake shown.
  - `[low]` `[reject]` `TestAChangedClassCloses...` calls `GovernanceFixture.Clear()` before any policy snapshot — wipes rows only a fresh instance lacks; harmless on every instance the suite runs on.
  - `[low]` `[reject]` AC2 says verdict `gone`; the code and tests say `notFound` — fix would edit the intent contract, which this build cannot; the shipped vocabulary is `ReadBack`'s.
  - `[low]` `[reject]` Intent auditor: the restore's "recompile only if `Compiled`" is unobservable through the seam — Task 0 measured it on a real refused compile; no further test is worth its seam.
  - `[low]` `[reject]` Intent auditor: the typed name is enforced by the client only — as 24.10's folder-item delete; spec-bound.
  - `[low]` `[reject]` Intent auditor: an update that sets a new `Resource` is not checked against it — the stored resource guards the change and a new one only narrows access; spec-bound (classic `canWrite` reads the stored resource).
  - `[low]` `[reject]` Intent auditor: the script form uses `$System.OBJ.*` text while the code path does not — the script form is the person's own console equivalent (AD-59), the port never calls it.
  - `[low]` `[reject]` Intent auditor: no test compares the writer's XML with `%SaveToClass`'s — Task 0 measured the equivalence, and a compare would call the forbidden method.
  - `[low]` `[reject]` Intent auditor: the DB-WRITE gate (`READONLY`) has no test — a read-only database cannot be made on the throwaway without the database-directory hazard the rules forbid; the check is one `AdmitDestination` call shared with the term list's tested path.
  - `[low]` `[reject]` Intent auditor: the extra pair `WritePairs` adds has no leg of its own — the gate loop holds every pair but one for the two pairs the spec names; the rest is `AtelierPort`'s own tested set.

## Auto Run Result

Status: done
Blocking condition: none

**Implemented (Batch 2: the seven writes).** Listing groups and their listings are added, updated, copied, deleted and set or removed through `AnalyticsPort` for both callers. The group's class is composed from `%GetModel` and saved, compiled and deleted through `AtelierPort` by the new `Kernel/SourceDocument` and `Kernel/ListingGroupText` (`DevToolPort.ReadVersion` now delegates to `SourceDocument`). A refused compile restores the prior text or deletes the new class. Five keys ship on, delete and remove ship off.

**Files changed (one line each).**

- Server: `Port/AnalyticsPort` (reads, pre-checks, writes, restore, audit, script forms), `Kernel/SourceDocument`, `Kernel/ListingGroupText`, `Port/DevToolPort`, nine tools under `Screen/Tool/AnalyticsListing*`, `Area/Analytics/ListingGroup{Save,Form}` and `ListingSave` with their routes, `Api/AnalyticsError`, `Kernel/Governance/Baseline`, `Kernel/Proposal/Prohibited`, the two descriptors.
- Client: `ui/src/app/areas/analytics/listing-group*` (store, dialogs, two pages, specs), handler, outlet, action-label and proposal-view maps, strings, regenerated mirror, EXPERIENCE.md row.
- Tests: `AnalyticsListingGroup{Base,Write,WriteEdge,Atelier,Seam}`, `AnalyticsListingWrite`, `AnalyticsProbe`, roster unions in the ten contended files and the other roster classes, `ui/tools/analytics.test.mjs`, the browser spec, an arming-roster comment in `scripts/ci-throwaway.sh`.

**Review.** One pass, two layers: 20 findings, patch 8 (medium 4, low 4), reject 12. The four medium patches (P1 to P4) added a copy-refusal test, a resource-guard test, an agent SQL-mint test and a page-registration spec, each with a mutation line. Triage and the rejected rows' reasons are in `## Review Triage Log`. No findings deferred.

**Follow-up review recommended: true.** Four medium findings were patched. The unverified risk: the four new tests were written and mutated in one pass, and the agent mint's refusal answers the generic privilege sentence, not the pair name (the write names it).

**Deviations from the spec's wording, for the runner.**

- `%Development:USE` comes from `AtelierPort.Pairs()`, not `WritePairs`; the gate adds both.
- Copy's cube argument is `NewCubes`, because `Test/Prohibited` refuses `TargetCubes` on a no-body tool; the query key and screen row are unchanged.
- Shape errors reuse `PORT.FIELD.SHAPE`; no new sentence was added.
- The EXPERIENCE.md :611 sentence "offers no action" was replaced (it became false), as the spec asked; the `strings.ts` cite of that file moved one line.
- The arming roster names `AnalyticsListingGroupBase`, the abstract class that declares `OCUPILOT_ALLOW_PRINCIPALS`.
- `ci-timings.json` is untouched and has no rows for the new classes.

**Verification.** On a throwaway rebuilt for this check, the three new classes were run first and each passed on its first run (8, 4 and 5 tests). The full ObjectScript sweep ran once after the last patch as 17 shards (k/17), all green, 0 failed, 0 probe leftovers, 0 overlaps. Earlier in the pass: the touched roster, read, gate and port classes, `test:tools` 2,302, `test:components` 3,550, `npm run build` (initial bundle 2.11 MB, under both budgets), the browser specs `analytics` 8 of 8 and `analytics-links` 6 of 6 on the redeployed bundle, `check-objectscript` 0 problems, `lint-docs` clean. One mutation per AC is in `## Verification`. The full browser suite is left to CI.

**Residual risks.** The `TYPED_NAME_ROWS` entry for a group is unpinned by any mutation (a group's id is its name). The database-read-only refusal and the extra `WritePairs` pair have no test of their own. A patch-pass subagent sent two test-runner calls in one message once; the runner reported 0 overlaps and both classes were re-run alone, green.
