---
title: 'Story 24.11: Listing groups (Batch 1: the read surface)'
type: 'feature'
created: '2026-11-17'
status: 'done'
baseline_revision: 'b5199c97eb3a915453398eb55af85d844a0ff5b6'
baseline_commit: 'b5199c97eb3a915453398eb55af85d844a0ff5b6'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-2-the-analytics-editors.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-10-folder-manager-transfer-and-term-list-import-export-and-copy.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The classic Listing Group Manager (`%DeepSee.UI.ListingGroupManager`) has no OcuPilot screen. A listing group is a class extending `%DeepSee.ListingGroupDefinition` whose `Listings` XData holds the group and its listings; compiling it publishes them to `^DeepSee.ListingGroups` (measured). Nobody can see or change one from OcuPilot.

**Approach:** Two batches (Design Notes › Proposed batches). This spec is Batch 1, the read surface. `AnalyticsPort` gains two `LIST` endpoints, `ListingGroups` and `ListingGroupListings`. Two descriptors use them: Listing groups and a group's Listings, the second parent-scoped as Term list entries is. The registry derives the read tools `analytics.listinggroups.read` and `analytics.listinggrouplistings.read`. Nothing is written.

## Boundaries & Constraints

**Always:**

- **Gate, in AD-65's order:** `LISTINGGROUPPAIRS` = `%DeepSee_Portal:USE,%DeepSee_ListingGroup:USE` (Question 3), then `AdmitNamespace`. The vendor runs nothing before the gate passes.
- **Vendor calls are the measured pure reads only.** `%DeepSee.ListingGroup.%GetListingGroups(.list, 0)` gives the rows. It lists every saved group and applies the vendor's own filter on the group's `resource`. `%GetListingGroups(.list, 1)` gives `Compiled`: true when the compiled list names the same class. `%GetModel(class)` gives the counts and listings.
- **Rows.**
  - `ListingGroups`: `Name`, `Caption`, `Cubes`, `Class`, `Compiled`, `Listings` (count), `Disabled`, `Description`, `Resource`, `DefaultResource`.
  - `ListingGroupListings` (criterion `listinggroup`): `ListingGroup`, `Name`, `DisplayName`, `Type`, `Fields`, `OrderBy`, `Joins`, `Formats`, `Source`, `Resource`, `SelectMode`, `Disabled`, `Description`, `SQL`.
- **`SQL` is answered only to a holder of `%DeepSee_ListingGroupSQL:USE`.** Anyone else gets `""`, as the classic page hides the field (measured). The screen and the agent's read apply the same rule.
- **One capped read** serves the screen and the tool, and reports truncation (AD-36). It reaches the model through the existing sanitizer (AD-60).

**Never:**

- Any write. That includes `%SaveToClass`, `$system.OBJ.*`, `%DeleteListingGroup` and `%RegisterRecentItem`, which the classic Open calls. It writes the user's recent items (inference, from source).
- `/api/deepsee`, or any vendor call not listed under Always.
- `emptyAgentKey` on these read-only descriptors (`screen-mirror.mjs` :3412 refuses it). Batch 2 adds it.
- Edits to `scripts/ci-throwaway.sh` beyond an added line (contended: add-only).

## I/O & Edge-Case Matrix

Rows run in USER on `ocupilot-b-ci`. They use marker groups that the test saves and compiles over an `AnalyticsProbe` cube, and removes afterwards.

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Compiled | A group with two listings | The row has `Compiled` true, `Listings` 2 and `Cubes` | - |
| Saved, not compiled | A group whose target cube does not exist | The row is present with `Compiled` false | - |
| Listings | Criterion = the group's name | One row per listing; each field equals the class's XData | - |
| SQL | A listing with `sql` | A holder of the SQL pair sees the text; a principal without it reads `""` | - |
| Hidden group | A group whose `resource` the principal holds nothing on | The row is absent | - |
| Unknown group | A criterion naming no group | No rows | - |
| Cap | `maxRows` below the count | `truncated` true | - |
| Gate | No `%DeepSee_ListingGroup:USE`; a namespace without analytics | Refused before any vendor call | 403 naming the pair; 409 `ANALYTICS.NAMESPACE` |

</intent-contract>

## Code Map

Paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-24` (HEAD `75c3e6564`). Epic 21 has touched none of them beyond feature (checked 2026-11-17), except `scripts/ci-throwaway.sh` (contended: add-only).

- **`src/OcuPilot/Port/AnalyticsPort.cls`** (4,248 lines). Extend the term-list read pattern; do not copy it.
  - Endpoints and pairs: `ENDPOINTS` :94 and the endpoint parameters :97-119. Put `LISTINGGROUPPAIRS` beside `TERMLISTPAIRS` :128, and add its branch to `Pairs` :419.
  - Dispatch: `Serves` :438; the `LIST` path in `Invoke` :548-583; `Admit` :599.
  - `Collect` :668: add branches after the term-list ones (:738-768) and keep the `pMax` stop. `Rows` :794.
- **Descriptors.** Add `src/OcuPilot/Screen/Descriptor/AnalyticsListingGroupList.cls`, modeled on `AnalyticsCubeList.cls` (read-only, no actions). Add `AnalyticsListingGroupListingList.cls`, modeled on `AnalyticsTermListEntryList.cls` :13-60 (`parentScope`, criteria) minus its actions. Both declare `classicPage` `%DeepSee.UI.ListingGroupManager`. The routes are `analytics/listing-groups` and `analytics/listing-groups/listings`.
- **`Screen/Read.cls`** :654-678 serves any analytics source. It needs no edit.
- **`src/OcuPilot/Kernel/EntityType.cls`**: add `listing-group` and `listing-group-listing` to `TYPES` :138 and to the doc :115-118.
- **Client:**
  - `ui/src/app/core/strings.ts`: the analytics block, :7818-8128.
  - `screens.generated.ts`: regenerate it with `screen-mirror.mjs`.
  - No page component: the archetype's list page serves read-only lists, as it does Cubes.
- **Rosters (Rule 30: rows are derived, a roster's own pin stays literal):**
  - `Test/ReadTool.cls`: the count :93, the names :94 and the pairs :112.
  - `Test/PortGate.cls` :302-305; `Test/Descriptor.cls` :92-94; `Test/AnalyticsDescriptor.cls` `SCREENS` :17 and :165; `Test/MappingDescriptor.cls` `CLASSICROSTER` :24.
  - `ui/tools/screen-mirror.test.mjs` :2750-2755 and :3515-3525; `navigation.test.mjs` :456-458 and :934-936; `analytics.test.mjs`.
- **Fixture:** extend `Test/AnalyticsProbe.cls` with `CreateListingGroups` and `RemoveListingGroups`, beside `CreateTermListTwo` :465.
- **EXPERIENCE.md** (`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/`): add a Fixed strings row after :610.
- **Vendor (read only):** `irislib/%DeepSee/ListingGroup.cls` (`%GetListingGroups`, `%GetModel`, `%DeleteListingGroup`); `ListingGroupDefinition.cls` (`%Generate`: the compile-time checks); `ListingGroupProjection.cls`; `Model/ListingGroup/listingGroup.cls` and `listing.cls`; `UI/ListingGroupManager.cls` (`RESOURCE` :15, `SubmitListingGroupContent` :644, `%OnAfterCreatePage` :669, `Delete` :821).

## Tasks & Acceptance

**Execution:**

- [x] **Task 0, on `ocupilot-b-ci` only:** a journal scan for writes by this process around `%GetListingGroups(.l, 0)`, `(.l, 1)` and `%GetModel` over the marker groups. Repeat it with one group whose XData is malformed, and record what the vendor answers. Record both under Design Notes › Measured.
- [x] `src/OcuPilot/Port/AnalyticsPort.cls`: the two endpoints, their pairs, `Collect` and `Rows` branches, and the `SQL` rule.
- [x] The two descriptors, the `EntityType` values, `strings.ts` (Proposed strings, once ruled), the regenerated mirror, and the EXPERIENCE.md row.
- [x] Tests:
  - `Test/AnalyticsProbe.cls`: the fixture methods.
  - New `Test/AnalyticsListingGroupRead.cls`: the matrix at the port and over `GET /screens/<id>/read`.
  - New `Test/AnalyticsListingGroupGate.cls`: the pairs, the SQL rule and the hidden group, with probe principals.
  - `ui/browser/analytics.browser-spec.mjs`: one spec that opens Listing groups, then a group's Listings.
  - Every roster under Code Map.

**Acceptance Criteria:**

- **AC1 (round trip over the backing class).** Given a marker group the test saved and compiled. When Listing groups and the group's Listings are read. Then every field equals the model `%GetModel` reads from the class.
- **AC2 (Integration, Rule 1).** Given the same group. When `GET /screens/analytics.listinggroups/read` and the agent's `analytics.listinggroups.read` run. Then both answer the same row. The same holds for the listings pair.
- **AC3 (browser).** Given the group. When a person opens Analytics › Listing groups and selects it. Then its Listings screen shows its listing rows.
- **AC4 (writes nothing).** Given the marker groups. When any read in the matrix runs. Then a journal scan of the calling process records no global write.
- **AC5 (declared and rostered).** Given the two descriptors. When the roster tests under Code Map run. Then each holds their rows and the classic page, and removing one row reddens that test alone.
- **AC6 (leaves USER as found).** Given any new or changed test. When it ends, in either order. Then no marker group class and no `^DeepSee.ListingGroups` node of a marker group remains.

## Spec Change Log

- 2026-11-17, spec gate: blocked -> ready-for-dev on the runner's rulings (U-108); this spec is Batch 1.

## Review Triage Log

### 2026-11-17 -- Review pass

- verdicts: 13 findings -- high 0, medium 2, low 7, false 4, maybe-false 0
- findings:
  - `[medium]` `[patch]` Two classes naming one group: the Listings branch's choice had no test -- `AnalyticsProbe.CreateTwinListingGroup`/`RemoveTwinListingGroup` and `TestTheCompiledClassAnswersWhenTwoClassesNameOneGroup` added; mutation recorded below.
  - `[low]` `[patch]` The unreadable-group guard's test filtered by prefix -- an `AnalyticsListingGroupRead.Nameless` assertion over the whole read added.
  - `[medium]` `[patch]` The editor's tool refusals accepted any status of 400 or more -- both legs now assert `403|AUTH.NOPRIVILEGE|%DeepSee_ListingGroup:USE` and that the leg answered.
  - `[low]` `[reject]` AC6's leftover check reads only the registry node in `Probe.Left` -- `Probe.Remove` deletes the classes through `RemoveListingGroups`, and the Read class's own check covers them; not worth a second check.
  - `[low]` `[patch]` AC2 comparisons sat inside an `If $IsObject` -- a presence assertion now precedes each block.
  - `[low]` `[reject]` Journal switch makes the scan answer -1 -- it reddens, never passes, so it is loud.
  - `[false]` `[reject]` AC4's scan misses the HTTP screen read -- the spec scopes AC4 to the calling process.
  - `[low]` `[reject]` The Listings `truncated` flag is asserted by row count at the port only -- the flag is `Read.cls`'s, shared with the groups screen, which asserts it.
  - `[false]` `[reject]` AC1 compares to the vendor model, not the class text -- AC1 says "equals the model `%GetModel` reads from the class".
  - `[low]` `[reject]` AD-60 sanitizer not exercised by the new tests -- no sanitizer code is touched; the tool path is the existing one.
  - `[false]` `[reject]` The journal scan does not cover the web process -- same as the AC4 row above.
  - `[false]` `[reject]` Other browser specs counting the Analytics side bar were not searched -- searched: the cube manager and term list specs find entries by label, not position.
  - `[low]` `[reject]` No browser assertion on the SQL cell -- the Listings table has no SQL column; the SQL rule is pinned at the port and over HTTP.

## Design Notes

**Ruled at the spec gate (runner, veto item U-108).** (1) Two batches inside the story: this spec is Batch 1 (the read surface); Batch 2 (the seven writes) is planned in a second spec for this story key after Batch 1's code head is committed, and the story reaches `done` only when both have. (2) Batch 2 saves, compiles and deletes the listing-group class through AtelierPort, as `DevToolPort.Promote` does (adds `%Development:USE`; stricter than the classic page); Story 24.12 follows the same path. (3) The read pairs are narrowed as proposed. (4) The proposed strings are kept. The proposed AD-65 line stays here for the owner's attended update; the code complies without a spine edit.

**Questions for the runner (intent gap).**

1. **Proposed batches (Rule 5 tier 2).** The full story is two read screens plus seven writes. The writes are a group's add, update, copy (classic Save As) and delete, and a listing's add, change and remove. Each write saves and compiles a class. 24.2's six tools alone ran oversized, and the 21.8 lineage is at `split_children`. Recommended: this spec is Batch 1. Batch 2, the seven writes, is planned in a second spec after Batch 1's code head is committed. Its first draft is under Batch 2 preview below. The story is `done` only when both batches are.
   - Alternative: Batch 1 also takes the group writes. That is rejected, because they wait on Question 2.
2. **Batch 2's class-write path (contradicts the epic context, not an AD).** Every write saves the group's class and compiles it, and a delete deletes the class. The epic context says "Never load or compile through `$system.OBJ`".
   - **Recommended: through `AtelierPort`, as `DevToolPort.Promote` :1537 does.** It saves the composed class (`TYPESAVE`/`TYPECREATE`), compiles it (`TYPECOMPILE`, failure read as `Route` :3045 reads it), and deletes it (`TYPEDELETE`). Its gate is `AtelierPort.WritePairs`, which adds `%Development:USE`. That is stricter than the classic page: a holder of `%DeepSee_ListingGroupEdit:USE` without `%Development` saved, compiled and deleted a group through the vendor (measured). This is a veto item.
   - **Alternative:** `AnalyticsPort` calls `%SaveToClass`, `$system.OBJ.Compile(class, "c")` and `%DeleteListingGroup`, as the classic page does. That posture equals the classic page's, but it breaks the epic context's rule.
3. **Read pairs (veto: stricter).** The classic page admits a holder of any one of `%DeepSee_ListingGroup`, `%DeepSee_ListingGroupEdit` or `%DeepSee_ListingGroupSQL` at USE (measured with `CheckListingGroupUseAccess^%qdsUtils`). OcuPilot's gate requires every pair it lists, so the plan narrows the read to the view resource, as 24.10 narrowed the Folder Manager.
   - Writes (Batch 2) add `%DeepSee_ListingGroupEdit:USE` (measured: `CheckListingGroupWriteAccess`).
   - Changing a listing's SQL adds `%DeepSee_ListingGroupSQL:USE`.
   - Changing a group that names a `resource` adds WRITE on that resource, as the classic page's `canWrite` :695 does.
4. **Proposed strings (veto).**
   - Labels: "Listing groups", "Listings", "Listing group" (criterion), "Target cubes", "Compiled", "Type", "Fields", "Data connector". "Name", "Caption" and "Description" reuse existing keys.
   - Empty states: "No listing group in this namespace is visible to you." and "This listing group no longer exists, or it has no listings."
   - Prompts for Listing groups: "Summarize the listing groups in this namespace." · "Which listing groups are not compiled?" · "Which cubes do these listing groups add listings to?"
   - Prompts for Listings: "Summarize the listings in this group." · "Which listings use a custom SQL query?" · "Which listings need a resource to open?"
   - Batch 2's agent empty-state phrases, which the registry will require once the screens can write: "create a listing group" and "add a listing to this listing group".

**Batch 2 preview (not planned here).** These seven tools extend `AnalyticsAction` through a new `AnalyticsListingGroupAction`, as `AnalyticsTermListAction` does:

- `analytics.listinggroups.add`, `.update` and `.copy`, whose keys ship `true`;
- `analytics.listinggroups.delete`, which is `DESTRUCTIVE` with its key `false`;
- `analytics.listinggrouplistings.add` and `.set`, whose keys ship `true`;
- `analytics.listinggrouplistings.remove`, which is `DESTRUCTIVE` with its key `false`.

How each write works:

- It composes the whole model from a fresh read (AD-4, AD-51). Add and copy are creates (AD-54), and refuse a taken name or class before any write.
- It pre-checks what the compile would refuse (measured: a missing target cube, a listing name the cube already holds, a group name already compiled).
- When the compile still fails, it restores the prior definition, or removes the new class, so nothing is half-applied. This keeps U-34 untouched, as 24.2 did. U-34 (AD-15 partial cube update, 24.13's) is not otherwise engaged.
- Each write records `ConfigChange` (AD-15) and has its script form (AD-59).
- The delete confirms with typed name and a consequence: "Cubes lose this group's listings."
- A listing's SQL shows the consequence "This listing runs its SQL with the rights of whoever opens it."

Story 24.12 also saves and compiles a class, so Question 2's ruling sets its path too.

**Measured** (plan, 2026-11-17, `ocupilot-b-ci`, USER, scratch classes and principals removed afterwards):

- **Privileges.** `CheckListingGroupWriteAccess` passes `%DeepSee_ListingGroupEdit:USE` alone. `CheckListingGroupSQLViewAccess` passes `%DeepSee_ListingGroupSQL:USE` alone. `%DeepSee_Admin`, `%DeepSee_Architect`, `%DeepSee_Portal`, `%DeepSee_PortalEdit` and `%Development` pass neither check, and fail the use check too.
- **Save.** `%SaveToClass` wrote only `^oddDEF`, `^rINDEXCLASS` and `^ISC.Src.Jrn`. `%GetListingGroups(.l, 0)` and `%GetModel` recorded no journaled write. Before a compile, the group is listed by `(.l, 0)` and not by `(.l, 1)`.
- **Compile.** It set `^DeepSee.ListingGroups` `groups`, `classes` and `cubes` nodes. A compile refused for a missing cube (#5001, "Target cube does not exist") or a listing name the cube holds ("Listing is already defined in target cube") still leaves `%Dictionary.CompiledClass` present. So `Compiled` is read from the vendor's compiled list, never from the class dictionary.
- **Delete.** `%DeleteListingGroup` killed the class and every metadata node through the projection.

**Measured** (Task 0, 2026-11-17, `ocupilot-b-ci`, USER; probe groups and classes removed afterwards):

- **Journal scan.** `AnalyticsProbe.JournalMark` and `JournalWrites` list the set and kill records this job wrote after a mark. A control `Set` made after the reads was the one record the scan found, so the scan sees a write. `%GetListingGroups(.l, 0)`, `(.l, 1)` and `%GetModel` over the four marker groups wrote none. The unit-test framework journals each assertion it records, so the tests assert only after the scans.
- **Malformed XData.** Three groups were read: unclosed XML (saved through `%Dictionary.XDataDefinition`, because `SetTextFromString` refuses XData that does not parse), well-formed XML with another root element, and `disabled='perhaps'`. Called directly, `%LoadFromClass` answers the parse error as its status. `%GetModel` passes that argument without a dot, so its own status stays OK and it answers an empty model: no name, no listings. `%GetListingGroups(.l, 0)` skips a model with no name, answers OK and lists the other groups; the scan found no write. A malformed group is therefore no row on either screen, and breaks no other read.
- **Lists.** `(.l, 0)` lists a saved group whose compile was refused (the cube is missing) and a disabled group, which compiles without registering; `(.l, 1)` lists only the registered ones. A group whose `resource` the caller holds nothing on is absent from `(.l, 0)`.
- **Pairs.** `%DeepSee_Portal:USE` is public, so no principal can lack it; the port's refusal naming it is pinned in process.

**Decided in-stage (plan).**

1. `Compiled` comes from the vendor's compiled list, as measured above.
2. An unknown group answers no rows, as Term list entries does.
3. `Joins` and `Formats` are read because the classic form shows join info, and Batch 2's round trip needs every model field (inference: `formatList` is not on the classic form).
4. The read tool names come from the registry's `<toolIdentifier>.read`, so there are no tool classes.

**Decided in-stage (implement).**

5. `Caption` is the vendor list's caption (the display name, else the name); `Cubes` is the model's `targetCubes` as written, not the list's upper-cased copy.
6. A criterion that names no group, or none, answers no rows, so the port adds no refusal sentence. Two classes that name one group answer from the compiled one, else the first saved.
7. The SQL pair is judged in `Invoke` through the gate class, where it is visible (AD-16), and `Rows` takes `pShowSQL`, which defaults to 0. Listing groups sits at side-bar position 9, after the Cube manager; both descriptors declare `%DeepSee_ListingGroup:USE` as their own pair, and `%DeepSee_ListingGroupSQL:USE` is not a pair of either screen.
8. The tests need no write tool: `AnalyticsProbe` makes the group classes from class text, and `CreateBrokenListingGroup` makes the refused-attribute variant, the one `SetTextFromString` accepts.

**Governing ADs (Rule 6):**

- AD-65 (the port and its pure-read list), AD-29 and AD-8 (the gate), AD-16 (the switch);
- AD-36 (the capped read), AD-5 and AD-44 (the descriptors and the classic page), AD-24 (screen context);
- AD-11 and AD-60 (the XData text is untrusted), AD-13 (entity ids).
- Batch 2 adds the AD-6 to AD-59 write set, as 24.10's did.

**Proposed spine lines (the owner's attended update; this run never writes them):**

- **AD-65:** "`%DeepSee.ListingGroup` `%GetListingGroups` (both forms) and `%GetModel` join the measured pure reads; the `ListingGroups` and `ListingGroupListings` endpoints answer a listing's SQL only to `%DeepSee_ListingGroupSQL:USE`."
- Batch 2's write path, once Question 2 is ruled.

**Integration and linkage (Rules 1, 2).**

- `Consumes:` `AnalyticsPort`'s gate; `Screen/Read.cls`; the tool registry's derived read tools; `Test/AnalyticsProbe`.
- `Consumed-by:` Story 24.11 Batch 2, whose writes compose their fresh read from these endpoints.
- AC2 is the Integration AC.
- Siblings extended: `Collect` and `Rows`; `AnalyticsCubeList`, plus `AnalyticsTermListEntryList` as the shape of the descriptors; `AnalyticsProbe` for the fixture.

**Ledger inbox:** none.

## Verification

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.AnalyticsListingGroupRead`. Run the same, one call at a time, for `AnalyticsListingGroupGate`, `AnalyticsDescriptor`, `AnalyticsPort`, `ReadTool`, `PortGate`, `Descriptor`, `MappingDescriptor` and every class the shared-surface sweep changes. Expected: green.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`. Expected: green.
- `(loop)` `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/analytics.browser-spec.mjs`. Expected: green.
- `(once)` the full ObjectScript sweep: `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17`, one call per shard, k = 1 to 17. Expected: green.
- `uv run scripts/check-objectscript.py`, `bash scripts/lint-docs.sh`. Expected: clean.
- The full browser suite is left to CI.

**Shared surfaces:** the analytics side bar, `ReadTool`'s count and names, the entity types, `AnalyticsDescriptor` `SCREENS`, the descriptor and endpoint rosters in `screen-mirror`, `MappingDescriptor`'s `CLASSICROSTER`, and `ci-timings.json` (the new classes have no row).

**Hermeticity:** every test added or changed passes on a fresh environment, in either order.

**Mutations:** one `mutation:` line per AC, written by the implement stage.

- mutation (AC1): `Compiled` pushed as 1 for every row in `AnalyticsPort.Collect` -> `AnalyticsListingGroupRead` `TestTheGroupsAreTheModelsOfTheirClasses` went red on the saved and disabled groups; `Compiled` read from `%Dictionary.CompiledClass` instead of the vendor's compiled list -> the same legs went red; `joinInfo` pushed empty -> `TestAGroupsListingsAreTheModelsListings` (Joins) went red; the criterion not upper-cased -> its listings legs, the cap leg and the integration leg went red.
- mutation (AC2): `Screen/Tool/Read.cls` `View` made to pass no criteria -> `TestTheScreenAndTheAgentsToolAnswerTheSameRows` went red (the Listings tool answered 400 `READ.CRITERION`).
- mutation (AC3): the Compiled column removed from `AnalyticsListingGroupList`, the mirror regenerated, the bundle rebuilt and copied into `ocupilot-b-ci` -> the browser spec's Listing groups leg went red; reverted, regenerated (the three generated files `cmp` equal), rebuilt and redeployed, it is green.
- mutation (AC4): a `Set` of a global in USER added to the groups branch of `Collect` -> `TestNoReadMakesAJournaledWrite` went red naming the record; `TestACapBoundsTheListAndTheScreenSaysSo`'s one-listing leg went red when the listings branch lost its `pMax` stop.
- mutation (AC5): `analytics.listinggroups.read` removed from `ReadTool`'s names, the Listings row from `Descriptor`'s committed table, its row from `SurfaceCoverage` and the Listing groups row from `StageTwoTools` -> each of those four tests went red, alone; the Listing groups descriptor's `classicPage` made `%DeepSee.UI.ListingGroupManagerx` -> `AnalyticsDescriptor` went red.
- mutation (AC6): `RemoveListingGroups` made to delete no class -> `TestRemovingTheListingGroupsLeavesNothing` went red.
- mutation (gate): the SQL pair judged as held (`tShowSQL` 1) -> `AnalyticsListingGroupGate` `TestAViewerReadsWhatItsResourcesAdmitAndNoSql`, `TestTheAgentsToolsApplyTheSameRules` and `TestAListingsSqlNeedsItsOwnPair` went red; `LISTINGGROUPPAIRS` made the portal's pair alone -> `TestThePortRefusesBeforeAnyVendorCall` and the editor's tool legs went red.
- mutation (review patch, twin class): the Listings branch of `Collect` made to take the first saved class of the name, whatever the compiled list says -> `TestTheCompiledClassAnswersWhenTwoClassesNameOneGroup` went red; reverted (`cmp` equal), reloaded, green.
- Each server mutation was reverted byte-identically (`cmp` against the saved copy) and the tree reloaded into `ocupilot-b-ci`, and the class that went red was green after.

## Auto Run Result

Status: done
Blocking condition: none

**Changed.** `AnalyticsPort` gains the `ListingGroups` and `ListingGroupListings` reads (pairs `LISTINGGROUPPAIRS`, the SQL answered only to `LISTINGGROUPSQLPAIRS`); two read-only descriptors, the `listing-group` and `listing-group-listing` entity types, 14 strings and the EXPERIENCE.md row (the one later citation, `strings.ts` :652, moved to :653); `AnalyticsProbe` gains the listing group fixtures (compiled, saved, guarded, disabled, broken and twin groups, their removal, the journal scan helpers); new `AnalyticsListingGroupRead` (7 tests) and `AnalyticsListingGroupGate` (6), both armed and rostered in `scripts/ci-throwaway.sh`; one browser spec; the rosters under Code Map, `ToolRoundTrip`, `ToolNavigateContract`, `analytics-links.browser-spec.mjs`, `structural-walk.mjs` and the regenerated mirror.

**Review.** 13 findings: 2 medium and 3 low patched (the twin-class test, the tool refusals pinned to 403 and the failed pair, a nameless-row check, presence assertions before the AC2 comparisons), 4 low rejected with reasons, 4 false. Nothing deferred. Patched by verdict: medium 2, low 3, so a follow-up review is recommended (`followup_review_recommended: true`): the twin test relies on the vendor listing the two classes of one name in the order measured on this build.

**Verified on `ocupilot-b-ci`.** The `(loop)` classes green (the two new classes after the review patches: 7 and 6 tests); the `(once)` sweep, shards 1 to 17 of 17, every shard green with 0 failed and no probe leftovers; `test:tools` 2,300 and `test:components` 3,538 green and `npm run build` green with the initial bundle at 2.11 MB (before the review patches, which touch no client file); `analytics.browser-spec.mjs` 7 of 7 and `analytics-links.browser-spec.mjs` 6 of 6 on the redeployed bundle; `check-objectscript` and `lint-docs` clean. Mutations are under Verification.

**Residual risks.** The journal scan covers journaled databases of the calling process only. `ci-timings.json` has no row for the two new classes. The full browser suite is left to CI.
