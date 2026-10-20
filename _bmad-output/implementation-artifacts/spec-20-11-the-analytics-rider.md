---
title: 'Story 20.11: The Analytics rider'
type: 'feature'
created: '2026-10-14'
status: 'done'
baseline_revision: '673ced36dc780d0d546622f006a03ac444cfb83f'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
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

All paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-20`. Line numbers were read at `bbc9028e`. Stories 20.8, 20.9, 20.30, 20.31 and 20.10 land first and touch the rosters below, so anchor by symbol.

### Port siblings (server)

- **`src/OcuPilot/Port/InteropPort.cls`** is the gate and read shape to follow:
  - `ENDPOINTS` :82, `Pairs` :744, `Serves` :786, `Invoke` :884, `Admit` :981-1004;
  - `Deny`, `Refuse` and `Conflict` :2561-2585, `RoutineResource` :1297, and `SnippetForm`/`Snippet` :3639/:3662;
  - `GateClass()` is the seam that `Test/InteropGateSeam.cls` overrides.
- **`src/OcuPilot/Port/MonitorPort.cls`** is a read-only port: `Pairs` :130, `Invoke` :211, `Gate` :265, and `Snippet` :693, which answers `[]`.
- **`src/OcuPilot/Port/DocDbPort.cls`** :493-510 and **`SqlActivityPort.cls`** :293-303 each carry their own private `Deny`/`Refuse`/`Conflict`.
- **`src/OcuPilot/Kernel/Shell/Namespaces.cls`**: `GlobalDatabase` :84 and `RoutineDatabase` :92.
- **`src/OcuPilot/Kernel/Shell/NamespaceFeatures.cls`**: `Reports` :26-27 calls `%IsDeepSeeEnabled`.
- **`src/OcuPilot/Api/InteropError.cls`**: `NAMESPACE` :14 and `REASONNAMESPACE` :16. **`ui/tools/interop.test.mjs`** :32 pins each sentence on three surfaces.
- **`AtelierPort.#NAMESPACEPATTERN`** is the shape check (`InteropPort` :988).

### Read path and registry (contended)

- **`src/OcuPilot/Screen/Read.cls`**:
  - `SOURCE*` parameters and `InteropPortClass()` :305-312;
  - the allowed list in `Execute` :429, and the interop branch :554-577 (criterion required when parent-scoped; `tQuery("namespace")`);
  - `DEFAULTMAXROWS` :101, `Project` :1431.
- **`src/OcuPilot/Screen/Registry.cls`**:
  - the source list and the "fourteen sources" message :1168-1169;
  - the per-port validation blocks (monitor :1283, interop :1304);
  - the criteria rule :1707-1708 (interop only when parent-scoped).
- **`ui/tools/screen-mirror.mjs`**:
  - `READ_SOURCE_PORTS` :983, the port-file endpoint parse :1102-1107 (InteropPort), `readProblem`'s branch ~:1404-1444;
  - the message :1330, the criteria-ports rule :1931, `SUGGESTED_PROMPTS_MIN` :2528.
- **`ui/tools/screen-mirror.test.mjs`**:2824 deep-equals the 14 ports. Its owners list is :2448-2496.
- **The "fourteen sources" sentence** is also expected in `Test/SqlActivityDescriptor.cls`:54, `DocDbDescriptor.cls`:59, `InteropDescriptor.cls`:101, `AdminPairCorpus.cls`:58 and `MetricsDescriptor.cls`:61.
- **`src/OcuPilot/Kernel/EntityType.cls`**:121 is `TYPES`. Its count is pinned at `Test/Descriptor.cls`:1792 (73).
- **`src/OcuPilot/Screen/Area.cls`**:90 is the `analytics` area: `appliesWhen` `analytics`, pair `%DeepSee_Portal:USE`.

### Descriptor siblings

- **`Screen/Descriptor/InteropLookupTableList.cls`** and **`InteropLookupEntryList.cls`**: a list and its parent-scoped entries, composite id `[Table, Key]`. The name cell reaches the entries through `childListFor`.
- **`InteropItemStatusTab.cls`** (head at `<list>/document`, `tab` position 1) and **`InteropItemQueueTab.cls`**: a parent-scoped `detail` tab group.
- **`ExplorerSqlProcedure.cls`**: every tab declares the parent's entity type (`class`).
- **`LogAnalyticsViewer.cls`**: an analytics screen with `%DeepSee_Portal:USE`.
- **Client.**
  - `shell/screen-outlet.ts` `ARCHETYPE_PAGES` :52-64: `list` → `ListPage`, `detail` → `DetailPage`. No page code and no `DESCRIPTOR_PAGES` line.
  - `core/navigation.ts` `documentScreenFor` :302-306; `shell/data-table.ts` :663-671 is the name-cell chain.

### Tests and rosters

- **`Test/PortGate.cls`**: `ROSTER` :29, `PortClasses()` :71, and the denial legs in `TestEveryPortEvaluatesItsDeclaredGate` :168 (interop leg ~:260-267, through `InteropGateSeam` and `ScreenGate.Hold`).
- **`Test/StageTwoTools.cls`** `Elsewhere` :120-258. `Analytics*` rows go between `AgentTranscripts` :131 and `AuditList` :132. The load-bearing test is `TestTheRosterAndElsewhereAreEveryRegisteredScreen`.
- **`Test/SurfaceCoverage.cls`**: `Coverage` XData, `<screen>` rows.
- **`Test/ReadTool.cls`**: the count :93 and names :94. **`Test/ToolRoundTrip.cls`** `REFUSEEMPTY` :94 (precedent `permissions.sqlprivileges.read:SQLPRIV.NAMESPACE`).
- **`Test/Navigation.cls`**: the per-area blocks (interop :537-544). Position-0 screens sort first, by class name.
- **`Test/InteropFloor.cls`**:
  - `BASESCREENS` :32 and `BASETOOLS` :38;
  - `TestEachPrincipalSignsInAndOpensExactlyItsRoster` :204-226;
  - `TestEveryOpenScreenMatchesItsClassicPage` :310-345, which needs the classic page's compiled `RESOURCE` to share the screen's pair.
- **`Test/DeveloperFloor.cls`**: the "forty-seven" tools comment :9, `AREAS` :27, `SCREENS` :38, `TOOLS` :41.
- **Unchanged, checked:**
  - `Test/Wire.cls`:429-430 ("Analytics is allowed on its public pair") stays true;
  - `Test/NamespaceFeatures.cls`:55-58, :131 and :146 are untouched by USER's enable, because the fixture restores it;
  - `InteropFloorOwnPairs` needs no row, because a non-`%Ens_Portal` pair is own;
  - the floor route and turn suites add no route.
- **Fixture siblings:**
  - `Test/ProductionProbe.cls`: `Create` :163 (`SetTextFromString`, `CompilePackage`), `Gone` :615, `Remove` :635;
  - `Test/InteropControl.cls`:23 and :44-61: `ARMINGVARIABLE`, then `OnBeforeAllTests`/`OnAfterAllTests`;
  - `Test/InteropLookupGate.cls`: `EnsurePrincipals` and the child-process `Probe` :263-292, :383;
  - `Test/TurnWireFixture.cls` `EnsurePrincipal` :77, `DeletePrincipal` :153;
  - `Test/Http.cls` `AbsoluteRequest` :207.
- **Arming.** `scripts/ci-throwaway.sh` lists the `OCUPILOT_ALLOW_PRINCIPALS` roster in its `# classes:` lines :434-497. `ui/tools/ci.test.mjs` :2275-2396 derives it, so it needs no edit. `scripts/check-objectscript.py` :1374-1389 is the arming rule for principals.
- **Client tests:**
  - `ui/tools/navigation.test.mjs`: the built-route roster :141-411 (analytics routes between :401 and :402), and the pairing-test precedent :757-775;
  - `ui/tools/strings.test.mjs`:613: the bound is 3,800, raised when the count comes within 50.
- **Browser:**
  - `ui/browser/structural-walk.mjs`: it walks `?ns=HSCUSTOM` :76; `needsId` :211; `SKIP` :101-129;
  - `ui/browser/interop-host-tabs.browser-spec.mjs`: `before`/`after` :198-215, and the per-spec `structural` :81-102 (1280 light, 720 light, 1280 dark);
  - `list-spec.mjs`, `panel-spec.mjs`, `turnprobe-spec.mjs` (`runIris`, `markerValue`), and `namespace-features.mjs` (`waitForMapAnswered`).
- **EXPERIENCE.md:** the side-bar prose :159; Fixed strings, header :252 and last row :604; the state matrix :856.

### Vendor (read only)

- **`irislib/%DeepSee/Utils.cls`:**
  - `%GetCubeFactCount` :3097 (the cube class's generated `%Count`);
  - `%GetCubeName` :3172, `%GetCubeCaption` :3266, `%CheckPrivilege` :3331, `%GetCubeClass` :3343;
  - `%GetRelatedCube` :3832, `%GetDimensionList` :3865 (`info(d,h,l)=$LB(type,dim,hier,level)`, type `l` or `r`), `%GetCubeMeasures` :5341;
  - `%GetCubeList` :7962 (`l(UPPER)=$LB(name,caption,schemaDate,type)`, filtered by `%CheckPrivilege`), `%IsDeepSeeEnabled` :11052.
- **`irislib/%DeepSee/CubeManager/Utils.cls`** `GetLastUpdate` :101-113: embedded SQL over `%DeepSee_CubeManager.CubeEvent`.
- **`irislib/%DeepSee/TermList.cls`**: `%GetTermLists` :15 and `%ToObj` :557 (field list and values, read only).
- **`irislib/%DeepSee/UserLibrary/Utils.cls`**: `%GetFavoriteList` :197, and `%GetFolderItemList` :523, which prepares a fixed statement and splices `pFolderClass` at :535.
- **`irislib/%DeepSee/UserLibrary/FolderItem.cls`**: properties :31-89, `%CheckResource` :160, `%GetTypeName` :216.
- **Classic `RESOURCE`s:**
  - `irislib/%DeepSee/UI/ModelBrowser.cls` inherits `%DeepSee_Portal,%DeepSee_PortalEdit` (`UI/standardPage.cls`:17);
  - `TermListManager.cls`: `%DeepSee_PortalEdit`;
  - `FolderManager.cls`: `%DeepSee_Admin,%Development`.
- **Why not REST:** `irissys/%Api/DeepSee.cls`:71, :92 and :117; `irislib/%DeepSee/REST/v3/InfoServer.cls` routes Cubes :355, Measures :613 and TermLists :853.

## Tasks & Acceptance

**Execution:**

- [ ] **Task 0 (re-anchor and measure, no product code).** First run `git rev-parse --show-toplevel`.
  - Re-read the rosters above after 20.8–20.10 land, and record each count.
  - Run `git diff --stat HEAD...origin/OCU-1-epic18` over the contended files. If Epic 18 has changed `Screen/Registry.cls` or `Screen/Read.cls`, stop and ask the orchestrator before the message edit.
  - Measure on `ocupilot-b-ci` with `AnalyticsProbe`:
    1. after the fixture's `Modify`, the same process reads `NamespaceFeatures.Reports("analytics","USER")` 1 (inference);
    2. `GetLastUpdate`'s form (local or UTC) and its answer for a principal holding no SQL privilege;
    3. `FolderItem.timeModified`'s zone;
    4. `%ToObj`, `%GetCubeFactCount` and `GetLastUpdate` write nothing (USER's `^DeepSee*` node counts unchanged), and the time each takes;
    5. `%SYS.Portal.Resources.NormalizePage` of the three `_DeepSee.UI.*.zen` pages.
    6. (orchestrator ruling 2026-10-14) that the in-process reads apply the vendor's own cube `Resource` check as the caller: against a probe cube carrying a resource the caller lacks, `Cubes` omits it and each model tab refuses it, as `%CheckPrivilege` decides; record the measurement in one line under Design Notes.

  A measurement that contradicts this spec halts the stage with its evidence.
- [ ] **`src/OcuPilot/Api/AnalyticsError.cls`** (new; sibling of `InteropError`): `NAMESPACE = "ANALYTICS.NAMESPACE"` and `REASONNAMESPACE = "Analytics is not enabled in this namespace."`.
- [ ] **`src/OcuPilot/Port/AnalyticsPort.cls`** (new; shaped like `InteropPort`'s gate and `MonitorPort`'s read-only `Snippet`).
  - **Parameters and gate.**
    - `ENDPOINTS = "Cubes,Measures,Dimensions,Relationships,TermLists,TermListEntries,FolderItems"`.
    - `PORTALPAIRS = "%DeepSee_Portal:USE"`; `TERMLISTPAIRS` adds `%DeepSee_PortalEdit:USE`; `FOLDERPAIRS` adds `%Development:USE`.
    - `Pairs(endpoint)`, `Serves`, a `GateClass()` seam, `Admit` in the Always order, and `Invoke` (`LIST` only; any other type 501).
    - Private `Deny`, `Refuse` and `Conflict`.
  - **Rows**, built after the namespace is restored:
    - Cubes, per `%GetCubeList` entry: `%GetCubeName`, `%GetCubeCaption`, `%GetCubeClass`, `%GetCubeFactCount`, and `GetLastUpdate(…,"build")` as local time.
    - Measures (criterion `cube`).
    - Dimensions (criterion `cube`): type `l` entries, `Position` counting from 1.
    - Relationships (criterion `cube`): type `r` entries through `%GetRelatedCube`.
    - Each tab first asks `%CubeExists` and `%CheckPrivilege`, and reads zero rows when either is false.
    - TermLists: `$ZDate(modDate,3)`.
    - TermListEntries (criterion `termlist`), through `%ToObj`. An unknown name reads zero rows.
    - FolderItems: `%GetFolderItemList(.l,"",0,"")`, `%OpenId` each, `%GetTypeName()`, and the `%GetFavoriteList` membership of `fullName`.
  - **Bounds and faults.** Every list stops at `maxRows+1`. A vendor status or `<PROTECT>` maps as `InteropPort` maps it: `PORT.ACCESSDENIED`, else `INTERNAL`, logged and never sent.
  - **Doc comments.** The class doc names AD-29, AD-36 and the new analytics AD (its number as the spine records it at the spec gate), and why REST is not used.
- [ ] **`Screen/Read.cls`, `Screen/Registry.cls`, `ui/tools/screen-mirror.mjs`.** Add source kind `analytics` the way `interop`'s is added:
  - parameter, port class, allowed list, dispatch branch with `namespace` and the required parent-scoped criterion;
  - per-port validation of `ENDPOINTS`, and the mirror's endpoint parse;
  - the criteria rule: analytics criteria only on a parent-scoped list.
  - Change "fourteen sources" to "fifteen sources" in both copies and in the five test classes' expected sentences, and the 14-port list in `screen-mirror.test.mjs` to 15.
- [ ] **`Kernel/EntityType.cls`** (add-only): `cube`, `term-list`, `term-list-entry` and `folder-item`, each with a doc paragraph (ids kept exactly, AD-13). `Test/Descriptor.cls`'s count rises by 4.
- [ ] **Seven descriptors** in `src/OcuPilot/Screen/Descriptor/`. All are `area` `analytics`, `scope` `namespace`, `built` true, `refreshes` false, with no actions, `classicLinkExemption` all-false, three prompts and `context.fields` equal to the read fields. Each doc comment names AD-5, AD-29, AD-36, AD-44 and the new analytics AD.

  | Class | Route · position · archetype | Pairs (own) | Classic page | Entity · id | Read endpoint · criterion | Tool |
  |---|---|---|---|---|---|---|
  | `AnalyticsCubeList` | `analytics/cubes` · 1 · list | Portal | `%DeepSee.UI.ModelBrowser` | `cube` · single `Name` | Cubes | `analytics.cubes` |
  | `AnalyticsCubeMeasuresTab` | `analytics/cubes/document` · 0 · detail, `tab` pos 1 | Portal | ModelBrowser | `cube` | Measures · `cube` | `analytics.cubemeasures` |
  | `AnalyticsCubeDimensionsTab` | `analytics/cubes/dimensions` · 0 · detail, pos 2 | Portal | ModelBrowser | `cube` | Dimensions · `cube` | `analytics.cubedimensions` |
  | `AnalyticsCubeRelationshipsTab` | `analytics/cubes/relationships` · 0 · detail, pos 3; `rowTarget {route: analytics/cubes/document, field: RelatedCube}` | Portal | ModelBrowser | `cube` | Relationships · `cube` | `analytics.cuberelationships` |
  | `AnalyticsTermListList` | `analytics/term-lists` · 2 · list | Portal + PortalEdit (own) | `%DeepSee.UI.TermListManager` | `term-list` (+`term-list-entry`) · single `Name` | TermLists | `analytics.termlists` |
  | `AnalyticsTermListEntryList` | `analytics/term-lists/entries` · 0 · list, `parentScope analytics/term-lists` | Portal + PortalEdit (own) | TermListManager | `term-list-entry` (+`term-list`) · composite `[TermList, Key]` | TermListEntries · `termlist` | `analytics.termlistentries` |
  | `AnalyticsFolderItemList` | `analytics/folder-items` · 3 · list | Portal + `%Development:USE` (own) | `%DeepSee.UI.FolderManager` | `folder-item` · single `Name` | FolderItems | `analytics.folderitems` |

  - "Portal" is `%DeepSee_Portal:USE`. The tabs' `tab.group` is `analytics/cubes/document`. Every tab has `parentScope` `analytics/cubes`.
  - A criterion is `kind` text, `maxLength` 255, with a `hint` naming the read tool that answers the name.
  - Columns:
    - Name `name`, Caption `text`, Class `identifier`, LastBuild `text`, Facts `number`;
    - Position `number`, Hidden and Favorite `status`;
    - every other field `text`.
  - Default sorts: Name; Dimensions by Position; entries by Key.
- [ ] **`src/OcuPilot/Test/AnalyticsProbe.cls`** (new fixture, about 350 lines; sibling of `ProductionProbe`).
  - **`Enable()`.** It refuses unless USER reports no analytics, or the probe node shows the probe's own earlier enable (a run that died). It records the default application's `DeepSeeEnabled` and `iKnowEnabled` in the probe node, then sets both to 1 through `Security.Applications.Get`/`Modify` in `%SYS`, by explicit save and restore. The measured `Modify` alone writes the six class-access rows.
  - **`Create(pFavoriteUser)`.**
    - Compile `OcuPilotProbe.Analytics.Category` (5 rows) and `.Visit` (1,000 deterministic rows, `DSTIME = "AUTO"`, a reference to Category).
    - Compile the cubes `OcuPilotProbeVisits` (time and category dimensions, two measures, a listing, and the relationship `CategoryRel` to Categories), `OcuPilotProbeCategories`, and `OcuPilotProbeGuarded` (`resource` `%DeepSee_Admin`).
    - `%BuildCube` `OcuPilotProbeCategories`, which also rebuilds the dependent Visits (measured), then the guarded cube.
    - Term list `OcuPilotProbeTerms`: three keys and one field, `Note`.
    - In folder `OcuPilotProbe`: a pivot, a dashboard, and a dashboard with `resource` `%DeepSee_Admin`.
    - `%AddFavorite` for `pFavoriteUser` of the pivot, and of `OcuPilotProbe/Gone.pivot`, which names no item.
  - **`Remove()`.**
    - `%KillCube` each cube; delete the classes and their extents and the probe's `^OBJ.DSTIME` nodes;
    - `%DeleteTermList`; `%DeleteFolderItem` each item, then the folder; `%RemoveFavorite` of both favorites;
    - delete the probe cubes' `CubeEvent` rows by `CubeKey`;
    - restore the recorded flags, and kill the probe node last.
  - **`Gone()`** checks each of these, that USER reports no analytics, and that the probe node is gone.
  - **Named.** The vendor bookkeeping a first build creates in a namespace (`^DeepSee.Agents`, `Tasks`, `TaskGroups`) stays.
- [ ] **`src/OcuPilot/Test/AnalyticsPort.cls`** (new, armed `OCUPILOT_ALLOW_PRINCIPALS`; `Remove`, `Enable` and `Create` in `OnBeforeAllTests`; `Remove` and `Gone` in `OnAfterAllTests`).
  - Each endpoint's rows equal the vendor's own answer, read in USER for the probe.
  - The guarded cube is listed for the test's own process, which holds `%All`; `AnalyticsGate` pins its absence, and its tabs' zero rows, for P1.
  - HSCUSTOM is refused 409 `ANALYTICS.NAMESPACE`.
  - `TestTheReadsWriteNothing`: around every endpoint, USER's `^DeepSee.Cache.*` and `^DeepSee.Session($Job)` nodes for the probe, the test user's favorites node (the dangling `OcuPilotProbe/Gone.pivot` favorite included), and the probe's term list and folder nodes read identically.
- [ ] **`src/OcuPilot/Test/AnalyticsGate.cls`** (new, armed `OCUPILOT_ALLOW_PRINCIPALS`; sibling of `InteropLookupGate`; the probe as `AnalyticsPort` uses it, and its principals created and removed).
  - **P1** holds `%Development:USE` (the floor), `%DB_USER:R` and READ on the install namespace's code database. Over HTTP:
    - `GET /screens/analytics.cubes/read?ns=USER` answers the probe cubes less the guarded one;
    - Folder items answers the probe items less the guarded dashboard;
    - Term lists is refused 403 naming `%DeepSee_PortalEdit:USE`.
  - **P2** is P1 without `%DB_USER:R`. Cubes is refused, naming `%DB_USER:READ`.
  - **Integration.** For P1, the agent's `analytics.cubes.read` answers the same rows as the screen read.
- [ ] **`src/OcuPilot/Test/AnalyticsDescriptor.cls`** (new, unarmed, read-only).
  - The seven declarations carry the table's values, and `Registry.Validate` passes.
  - Each `classicPage` equals `NormalizePage` of its `.zen`.
  - Each classic page's compiled `RESOURCE` names a pair the screen declares.
- [ ] **`src/OcuPilot/Test/AnalyticsGateSeam.cls`** (new; a copy of `InteropGateSeam`'s pattern). In `Test/PortGate.cls`: a `ROSTER` row `OcuPilot.Port.AnalyticsPort=PORTALPAIRS;TERMLISTPAIRS;FOLDERPAIRS` and a denial leg per pair set.
- [ ] **Rosters, each row named from the instance:**
  - `StageTwoTools` `Elsewhere`: seven rows;
  - `SurfaceCoverage`: seven `<screen>` rows;
  - `ReadTool`: +7 names;
  - `ToolRoundTrip` `REFUSEEMPTY`: the three listed reads `:ANALYTICS.NAMESPACE` and the four parent-scoped `:READ.CRITERION`;
  - `Navigation.cls`: an analytics block of 7, in its pinned order;
  - `InteropFloor`: `BASESCREENS` and `BASETOOLS` +4 (the Cubes list and tabs), and the `BASESCREENS` comment (its principals hold no `%Development`, :104);
  - `DeveloperFloor`: `SCREENS` and `TOOLS` +5, adding Folder items, and its tools-count comment.
- [ ] **`ui/src/app/core/strings.ts`** (add-only) gets the literals in Design Notes › Strings. Then regenerate `screens.generated.ts` with `cd ui && node tools/screen-mirror.mjs`.
- [ ] **`ui/tools/analytics.test.mjs`** (new; sibling of `interop.test.mjs`): `REASONNAMESPACE` equals `analyticsRefusalNamespace` and its EXPERIENCE.md literal.
- [ ] **`ui/tools/navigation.test.mjs`:** the seven routes in the roster; `documentScreenFor('analytics/cubes')` is the Measures tab, and `childListFor('analytics/term-lists')` is the entries. **`ui/tools/screen-mirror.test.mjs`:** the three own-pair descriptors join the owners list, and an analytics criteria case follows interop's.
- [ ] **`ui/browser/structural-walk.mjs`.** Add `SKIP` rows for the three tabs and the entries list: "HSCUSTOM is not analytics-enabled; analytics.browser-spec.mjs walks them in USER on its probe". Fix or append any fresh baseline entry, as the file says.
- [ ] **`ui/browser/analytics.browser-spec.mjs`** (new).
  - **`before`.** Refuse the live container and require readiness `installed`. Through `runIris`, call `AnalyticsProbe` `Remove`, `Enable` and `Create("_SYSTEM")`.
  - **`after`.** Call `Remove`, then assert `Gone`.
  - **Tests**, each carrying its mutation comment:
    1. **AC1.** In USER: the side bar lists Cubes, Term lists and Folder items, and each list's rows equal the instance's.
    2. **AC2.** Cubes name cell → Measures → Dimensions → Relationships → the related cube; Term lists name cell → entries.
    3. **AC3.** In HSCUSTOM, a direct `analytics/cubes` route shows the refusal sentence.
    4. **AC5.** The per-spec `structural` helper, for each of the seven screens in USER: no fresh entry at 1280 light, 720 light or 1280 dark.
- [ ] **EXPERIENCE.md:**
  - :159: after the Interoperability sentence, "Analytics (Story 20.11): Cubes · Term lists · Folder items. A Cubes name cell opens the cube's model, in tabs: Measures · Dimensions · Relationships; a Relationships row opens the related cube's model. A Term lists name cell opens the list's entries."
  - :604: the literals with a Story 20.11 clause.
  - Then run `cd ui && npm run test:tools`.
- [ ] **Roster sweep (Rule 30).** Search `src/OcuPilot/Test`, `ui/tools`, `ui/browser` and the `ui/src` specs for the source-kind count, the analytics area, `BASESCREENS`/`SCREENS` and the floors' tool lists. Each changed file joins `(loop)`.

**Acceptance Criteria:**

- **AC1 (the four surfaces read through the analytics port; the story's first criterion).**
  - **Given** `AnalyticsProbe` in USER.
  - **When** Cubes, a cube's three tabs, Term lists with entries, and Folder items each load, and their read tools run.
  - **Then:**
    - each answers the matrix's rows, equal to the vendor's own answer read on the instance;
    - the screen and the tool answer the same rows (AD-36);
    - no read changes the MDX cache, the process's DeepSee session node, a favorite, or the probe's term list or folder nodes.
- **AC2 (the model browser and term-list navigation).**
  - **Given** Cubes in USER.
  - **When** the person opens `OcuPilotProbeVisits`' name cell.
  - **Then:**
    - the route is `analytics/cubes/document/<cube>`, and Measures, Dimensions and Relationships read in that strip order;
    - the `CategoryRel` row opens `OcuPilotProbeCategories`' Measures;
    - a Term lists name cell opens `analytics/term-lists/entries/<name>`, whose `Fields` shows the `Note` values.
- **AC3 (gate first; AD-29).**
  - **Given** HSCUSTOM, or P1 or P2.
  - **When** an analytics read runs.
  - **Then** each refusal in the matrix is the gate's: 409 `ANALYTICS.NAMESPACE` with its sentence, or 403 naming the failed pair. For P2 that pair is `%DB_USER:READ`, which a vendor call made first would answer as an unnamed `<PROTECT>`.
  - **And** `PortGate` holds `AnalyticsPort`'s row, and each of its pair sets' denial.
  - **And** the vendor's own cube and folder-item resource checks still hide the guarded probe objects from P1.
- **AC4 (Integration, Rule 1).**
  - **Given** P1 signed in.
  - **When** `Screen/Read` serves `GET /screens/analytics.cubes/read?ns=USER`, and the agent's `analytics.cubes.read` runs in USER.
  - **Then** both answer the probe's visible cubes with `{Name, Caption, Class, LastBuild, Facts}` from `AnalyticsPort`.
- **AC5 (declared, gated, rostered, structural).**
  - **Given** the seven descriptors.
  - **When** the instance validates them and the build regenerates the mirror.
  - **Then:**
    - each validates on both sides with the table's values and at least three prompts;
    - each is in `Elsewhere` (one row removed reddens that test alone);
    - Analytics navigation carries 7 screens in the pinned order;
    - every floor principal opens the Cubes list and its tabs, the developer principal (`%Development:USE`) also opens Folder items, and no floor principal opens Term lists;
    - the structural walk finds no fresh entry in either theme.
- **AC6 (the fixture leaves USER as found).**
  - **Given** a run of either test class or the browser spec.
  - **When** it ends.
  - **Then** `AnalyticsProbe.Gone()` is true: no probe class, cube, term list, folder item, favorite or `CubeEvent` row remains, USER's two flags read their recorded values, and USER reports no analytics.

## Spec Change Log

- 2026-10-14, spec gate (runner): the orchestrator ruled Q1 A (Parts B, C and D are Stories 20.32, 20.33 and 20.34, chartered in `epics.md` with their criteria verbatim; order 20.11, 20.32, 20.33, 20.34, then 20.12) and Q2 A (Folder items on `%Development:USE`, a named narrower audience in AD-8). `epics.md` Story 20.11 is amended under Rule 5 (the split, and the first criterion's API reworded to the vendor's classes, apply-and-report). The new AD is AD-65 (claimed from the coordination counter), with the AD-29, AD-36, AD-8, AD-44, AD-13 and AD-7 clauses. Task 0 gains the cube `Resource` check measurement (the orchestrator's). The REST layer finding is DW-2416, decision-pending under the owner's hold.
- 2026-10-14, lead (20.33's spec gate, orchestrator rulings Q1 A and Q2 C): Part C's splice limits become the screen's ask-first confirmation and the agent's refusal; the agent's MDX read is Story 20.35.

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


## Design Notes

**Governing ADs (Rule 6).**

- **AD-29:** the port's own gate, the whole gate (measured).
- **AD-1:** in process, never HTTP.
- **AD-5:** seven descriptors, a tab group and a parent-scoped list, with no page code.
- **AD-7:** what the reads cost (below).
- **AD-8:** pairs (below).
- **AD-9:** routines READ.
- **AD-11 and AD-60:** untrusted names.
- **AD-13:** ids kept exactly.
- **AD-16:** switched reads.
- **AD-24:** context fields.
- **AD-36:** source kind `analytics`, one read for screen and tool, the cap, a parent's route id as the criterion.
- **AD-44:** the three classic pages.
- **AD-62:** the precedent this port copies.
- **AD-64:** the port's pairs are not adjustable; the screens are.

Checked and not engaged: AD-10, AD-22, AD-51 to AD-53 (no write); AD-43 (no refresh); AD-47 and AD-63 (nothing loaded or framed); AD-21 (no caller text reaches SQL, and the vendor's spliced `pFolderClass` is never passed).

**Why not the REST API.** The AC's "analytics API" is read as the vendor's analytics classes. These are the methods `/api/deepsee`'s Info routes call: Cubes → `%GetCubeList`, Measures → `%GetCubeMeasures`, TermLists → `%GetTermLists`, GetTermList → `%GetValueArray`. AD-1 forbids reaching them over HTTP. Calling the route methods in process (AD-61's way) brings four faults with it:

- `%Api.DeepSee` resets `$ROLES` to the login roles (`irissys/%Api/DeepSee.cls`:92);
- no route checks a `%DeepSee_*` resource (`AccessCheck` is always 1, :117);
- `MDXExecute` and `MDXDrillthrough` append the caller's `FILTERS` and `RETURN` text;
- the routes read `%session.AppTimeout`.

The port therefore calls the classes themselves, as `InteropPort` does (AD-62).

**Measured at this plan on `ocupilot-b-ci`** (2026-10-14; IRIS for Health 2026.2 build 221U). Every probe was removed and verified gone. The residue is journal records, about 64 statement-index rows in USER and 20 in `%SYS`, and 32 `^ISC.Src.Jrn` entries naming the probe classes.

- **Enabling.**
  - USER and HSCUSTOM do not report analytics; HSLIB and HSSYS do.
  - `Security.Applications.Modify` with both flags 1 writes six class-access rows for `/csp/user/` (`%DeepSee.`, `%iKnow.`, `%ZEN.Dialog.` and three more). Nothing else changes: no global, mapping, task or CPF line.
  - With 0 it removes all six. `%IsDeepSeeEnabled` follows the rows (inference).
- **No `%DeepSee_*` check.** A principal holding only `%DB_USER:RW` read every model, term list and folder item; created and deleted a term list; built and synchronized; and ran MDX, async and cancel included.
  - Only a cube's `resource` filtered anything: it was absent from `%GetCubeList` and "Cannot find Subject Area" elsewhere.
  - So did a folder item's `resource`: hidden at show-all 0, shown at 1.
  - Without `%DB_USER`, `%GetCubeList` throws `<PROTECT>`; the others return it as a status.
  - No shipped role holds any `%DeepSee_*` resource, and `%DeepSee_Portal` is public USE.
- **Reads that write nothing** (node counts before and after): `%GetCubeList`, `%GetCubeMeasures`, `%GetDimensionList`, `%GetCubeLevels`, `%GetRelatedCube`, `%GetDependentCubes`, the term-list reads, `%GetFolderItemList`, `%GetPivotList`/`%GetDashboardList`, and `%GetFavoriteList`.
- **Reads that write:**
  - `%GetMemberTree` writes `^DeepSee.Session(pid)`;
  - `%GetDimensionMembers` writes `^DeepSee.Cache.Results`/`Axis`/`LocalResults`;
  - `%GetFavoritesForUser` deleted a favorite whose item was gone.
- **Timings:** all of these model reads under 0.1 ms; a cold MDX 2.7 ms.
- **Cube facts.**
  - `%GetCubeList`'s date is the schema's compile time, not the last build.
  - `GetLastUpdate` reads `CubeEvent` rows, which a direct `%BuildCube` writes (`UserName`, `StartTime`, `CubeSize`).
  - Names are case-insensitive.
  - Building the "many" side of a relationship before the "one" side fails with #20006 while still storing facts. Building the "one" side rebuilds its dependents in the same call.
- **The pages.** In an enabled namespace all eight classic DeepSee pages answer 200. In HSCUSTOM they answer 403. Each cookieless page load holds a license unit for its session's 900 s: eight loads exhausted the throwaway's Community license for about five minutes. That matters to Part B.

**Decisions.**

- **Levels, not member values.** "Member tree (cubes, measures, filters)" is the Info routes' cubes, measures and filters, which `%GetCubeMeasures` and `%GetDimensionList` answer without writing. Member values run MDX and write the cache, so they arrive with Part C, whose member tree needs them under its AD-7 ruling.
- **One cube tab group under the Cubes list.** It follows the item tabs' precedent: the head at `<list>/document`, the name cell through `documentScreenFor`, and every tab declaring the parent's entity type, as the SQL procedure tabs do. The Cubes list declares the Model Browser, which lists cubes and is open to every account. The Cube Manager (`%DeepSee_Admin`) is Part D's own screen.
- **Term list entries follow lookup entries.** It is a parent-scoped list, composite id `[TermList, Key]`, read through `%ToObj` so the field list comes with the values.
  - *Rejected, one column per field:* a descriptor's table is fixed.
  - Named limit: the whole term list is loaded before the cap. Term lists are lookup tables (inference: small).
- **Folder items.**
  - Show-all 0 keeps the vendor's per-item resource check, which is stricter than the classic Folder Manager (inference: it shows all).
  - `Favorite` is the signed-in person's, through `%GetFavoriteList`.
  - Named limit: the vendor opens every item before the cap.
- **`Last build`** is `GetLastUpdate(…,"build")`: build and repair events only. A cube built only by synchronize, or never tracked, reads empty (named limit).
  - *Rejected, `^DeepSee.Update`:* a vendor-internal global that a synchronize also stamps.
- **Routines READ.** The cube's generated `%Count` runs from the routines database (AD-9), so the gate requires READ on it as well as on the globals database. The two are one database on USER, so the separate refusal is untested there (inference).
- **Arming.** The probe changes USER's web application, so its suites declare `OCUPILOT_ALLOW_PRINCIPALS`, as `ProductionProbe`'s do. `AnalyticsGate` also creates principals.

**Split (`multiple-goals`; recommended).** This story is four capabilities with clean seams.

- **Part A (this spec)** is the port and the four read surfaces: the story's first criterion.
- **Part B, "The analytics links"** (fourth criterion). Architect, Analyzer and User Portal open the namespace's own page in a new tab, never rebuilt.
  - **Shape (recommended).** Three listed screens of the vocabulary's existing `external` archetype ("opens a new tab and has none", `Archetype.cls`:2-5), each naming a page from a closed vocabulary.
    - The address is composed on the instance from `$System.CSP.GetDefaultApp(ns)` (USER `/csp/user`, HSLIB `/csp/healthshare`), never from a caller's text, and answered as Help's is.
    - The side bar and the command box open it with `noopener`.
  - **Needs:**
    - registry and mirror rules for `external` (no `href` key exists);
    - an `ARCHETYPE_PAGES` entry;
    - EXPERIENCE.md :887's new-tab list, and an AD-44/AD-47 clause.
  - **Its gate:** Architect's and Analyzer's OR lists (`%DeepSee_Architect,%DeepSee_ArchitectEdit`, and the Analyzer pair) against AD-8's every-pair rule. Its browser test must not load the pages repeatedly (the license, above). Size: small to medium (inference).
- **Part C, "The MDX query tool"** (second criterion).
  - **Run and cancel.** `%PrepareMDX` and `%ExecuteAsynch(.key,,0)` run on DeepSee's agents in the caller's security context (documented, `%SYSTEM/WorkMgr.cls`:38,74). `%GetQueryStatus` polls, and `%CancelQuery(cube,key)` stops it (measured: the query then reports the vendor's cancel error #5001) with no owner check. So OcuPilot keeps an owner-scoped run row, as the SQL console's background run does (AD-7, AD-33).
  - **Bounds.** Cells or rows read capped, time bounded, and cancel.
  - **Drill-through.** `DRILLTHROUGH` defaults to 1,000 rows and needs SQL SELECT on the source table (-99 without it, measured).
  - **Never a write.** MDX has no DML. `CREATE` and `DROP` write only the session, and are refused.
  - **Query text that runs code or SQL** (orchestrator ruling Q2 C at Story 20.33's spec gate, 2026-10-14; AD-65): `%SEARCH`, `%SQLRESTRICT`, `RETURN` and `%ORDER` run server-side code or SQL with the caller's rights. The person's MDX screen (20.33) asks first, in a confirmation naming that consequence, then runs; the agent's MDX read (Story 20.35) refuses them with `ANALYTICS.MDX.SQL`. SQL computed dimensions and `%KPI` classes are the cube author's code and stay named limits.
  - **Its gate:**
    - AD-7's new shape (queries write `^DeepSee.Cache.*`, `^DeepSee.AgentLog` and IRISTEMP: the vendor's derived cache);
    - the MDX Query Tool's OR pair (Q2's answer applies);
    - whether the agent gets an MDX read tool (ruled at 20.33's gate: not in 20.33; Story 20.35).
- **Part D, "The cube manager's build and synchronize"** (third criterion).
  - **Screen.** A listed Cube manager with the own pair `%DeepSee_Admin:USE`, classic page `%DeepSee.UI.CubeRegistry`. Its row actions Build and Synchronize are action-style writes through `AnalyticsPort` (AD-51, AD-52), over a port-composed `STATE` read.
  - **Refused by name:** a synchronize on a source without `DSTIME` (`NoDSTIME`), and a build while one holds `^DeepSee.Build`.
  - **Repair.** "Repair" is the same `%BuildCube`: REST `RepairBuild` calls it, and `RegistryMapCube.Repair` calls an undefined method. So Repair is offered as Build, a Rule 5 restatement.
  - **Destructiveness (`Write.cls` :43-52).**
    - Build kills every fact first, makes the cube and its dependents unqueryable while it runs, and leaves the facts gone if it fails. It is destructive, so its key ships `false`.
    - Synchronize applies only the recorded source changes and keeps the cube queryable. It loses nothing, as recover deletes nothing (AD-62 (6)), so it is not destructive and its key ships `true`.
  - **Impact.** The card names the dependent cubes (`%GetDependentCubes`, pure).
  - **Its gate:**
    - AD-7: a build can outlast the confirm request; the classic page `JOB`s it and polls a tracking global;
    - the audit: the vendor writes `CubeEvent` rows, not an audit event;
    - the user code a build runs (`^DeepSee.InitCode`, registry Post code).
- **Order:** 20.11 (A), then B, C and D, then 20.12, 20.25, 20.26 and the burn-down. Epic 21's 21.8 waits on A's Term lists and Folder items, and its remaining editors may extend D's Cube manager (inference). Epic 21 starts on slot B after Epic 20 ends.

**Gate questions (for the orchestrator).**

- **Q1, split.**
  - (A) Four stories, as above, numbered by the lead. Rule 5 ask-first: it defers criteria 2, 3 and 4. Recommended.
  - (B) Three stories: A plus B, then C, then D.
  - (C) One story.
  - Under (B) or (C), the lead re-opens this spec to `draft`.
- **Q2, Folder items' pair.** The classic Folder Manager takes `%DeepSee_Admin` or `%Development`; AD-8 requires every pair.
  - (A) `%Development:USE`, a named narrower audience. No shipped role holds `%DeepSee_Admin` (measured), so only a custom-role holder of it alone is refused. Recommended.
  - (B) `%DeepSee_Admin:USE`, which only `%All` holds.
  - (C) Extend AD-64's either-of check to this screen: a spine change.

**Rule 5 drafts (for the lead).**

- **Q1 (A).** `epics.md` Story 20.11 keeps its title and its first criterion. The second, third and fourth criteria move, verbatim, to three new stories in the order above.
- **Apply-and-report.** The first criterion's "reads through the analytics API" becomes "reads through the vendor's analytics classes in process, behind OcuPilot's own gate (the methods `/api/deepsee`'s Info routes call)". It corrects the API the AC cites; the intent is unchanged.

**Spine and UX drafts (Rule 20; the lead writes them at the gate; the AD number comes from the orchestrator's counter).**

- **AD-<next>, "Analytics is reached through one port that calls the vendor's `%DeepSee` classes in process, behind its own gate".**
  - *Binds:* the Analytics rider's screens, read tools and later writes; `Port/AnalyticsPort`; AD-1, AD-7, AD-8, AD-13, AD-16, AD-29, AD-36 and AD-44.
  - *Prevents:*
    - an analytics read with no gate of OcuPilot's, because neither the classes nor `/api/deepsee` check a `%DeepSee_*` resource;
    - a read that writes the vendor's cache or deletes a favorite;
    - caller text that `/api/deepsee` splices into MDX and SQL.
  - *Rule:* the Always list's calls and gate order, the Never list's vendor calls, source kind `analytics` and its seven endpoints, and the measured facts above.
- **AD-29** *Binds*, and the Design Paradigm's port list (:46, :53): add `AnalyticsPort`.
- **AD-36, a Story 20.11 clause:** "A declared read may name the analytics port (source kind `analytics`): `LIST` on `Cubes`, `TermLists` and `FolderItems`, and on `Measures`, `Dimensions` and `Relationships` (criterion `cube`) and `TermListEntries` (criterion `termlist`), each parent-scoped read taking its parent's route id."
- **AD-8, a Story 20.11 clause:** the pairs in the descriptor table, and Q2's named narrower audience. An account holding only `%DeepSee_*` resources is refused by the API floor. Admitting one would be an owner decision, as DW-2140 was (named limit).
- **AD-44, a Story 20.11 clause:** `%DeepSee.UI.ModelBrowser`, `%DeepSee.UI.TermListManager` and `%DeepSee.UI.FolderManager` (`NormalizePage`, measured at Task 0).
- **AD-13:** a `cube` id is the cube's logical name, a `term-list` id its name, a `term-list-entry` id `[TermList, Key]`, and a `folder-item` id its full name, each kept exactly.
- **AD-7, the fifth shape:** "So does `AnalyticsPort`'s folder-item list, whose vendor method prepares one fixed statement (Story 20.11)."
- **EXPERIENCE.md:** :159 and :604, as Tasks says.

**Strings (about 50 literals, add-only; values checked unique at Task 0).** The count was about 3,440 after 20.31 (inference), and stays under 3,750.

- **Labels:**
  - `analyticsCubesLabel` "Cubes"; `analyticsTermListsLabel` "Term lists"; `analyticsTermListEntriesLabel` "Term list entries"; `analyticsFolderItemsLabel` "Folder items";
  - tabs: "Measures" · "Dimensions" · "Relationships";
  - columns: "Caption" · "Class" · "Last build" · "Facts" · "Hidden" · "Hierarchy" · "Level" · "Related cube" · "Key" · "Value" · "Fields" · "Owner" · "Modified" · "Favorite" (reuse an existing key where its value is identical).
- **Empty:**
  - "No cube is defined in this namespace.";
  - "This cube no longer exists, or it has no measures."; "This cube no longer exists, or it has no dimensions."; "This cube no longer exists, or it has no relationships.";
  - "No term list is defined in this namespace."; "This term list no longer exists, or it has no entries.";
  - "No folder item in this namespace is visible to you."
- **Refusal:** `analyticsRefusalNamespace` "Analytics is not enabled in this namespace."
- **Prompts (three each):**
  - Cubes: "Which cube holds the most facts?", "When was each cube last built?", "Which cubes have never been built?"
  - Measures: "Summarize what this cube measures.", "Which measures of this cube are hidden?", "Which measures could I compare across a dimension?"
  - Dimensions: "Which dimensions can I filter this cube by?", "Which levels does each hierarchy of this cube have?", "Does this cube have a time dimension?"
  - Relationships: "Which cubes does this cube relate to?", "Which related cube must be built first?", "How do I use this relationship in a query?"
  - Term lists: "Summarize the term lists in this namespace.", "Which term list changed most recently?", "Which term lists could a cube use to translate codes?"
  - Entries: "Summarize what this term list maps.", "Which keys map to the same value?", "Are any values in this term list empty?"
  - Folder items: "Which dashboards are in this namespace?", "Which items are my favorites?", "Which folder items changed most recently?"

**Integration, Consumes, Consumed-by (Rules 1 and 2).**

- **Integration:** AC4. `Screen/Read` and the read-tool dispatch consume `AnalyticsPort` against the real instance.
- **Consumes:**
  - 20.1: the Analytics area and `NamespaceFeatures`;
  - the read route, `ListPage` and `DetailPage`;
  - `Kernel/Shell/Namespaces`;
  - `ScreenGate.Hold`, `TurnWireFixture`, `Http.AbsoluteRequest`, and the floors' principals.
- **Consumed-by:**
  - Part B: the area and its first listed screens;
  - Part C: Cubes as its cube picker, and `AnalyticsPort`;
  - Part D: `AnalyticsPort`'s writes and Cubes' Last build and Facts as its read-back;
  - Epic 21's 21.8: the term-list editor and the folder manager's actions extend Term lists, Folder items and `AnalyticsPort`.

**Ledger inbox (Rule 17):** none owned (`owned_ledger=0`).

**Rule 31 (extend, don't copy).**

- **`AnalyticsPort`** follows `InteropPort`'s gate and `MonitorPort`'s read-only shape as a new port class. Every in-process port (`DocDbPort`, `SqlActivityPort`, `InteropPort`) keeps its own private `Deny`/`Refuse`/`Conflict`, and a shared base would couple unrelated vendor areas. It reuses `Kernel.Denial`, `Kernel/Shell/Namespaces`, `NamespaceFeatures` and `AtelierPort.#NAMESPACEPATTERN`.
- **`AnalyticsError`** is a sibling of `InteropError`.
- **`AnalyticsProbe`** follows `ProductionProbe`'s create, remove and gone shape for another vendor area.
- **`AnalyticsGate`** reuses `InteropLookupGate`'s principal pattern and `Http`.
- **`analytics.test.mjs`** repeats `interop.test.mjs`'s few parameter-reading lines, because its helpers are file-local and a shared module would couple two areas' tests.
- The descriptors, the browser spec and the seam extend their named siblings.

**Contended files (Rule 11).** `origin/OCU-1-epic18` (`5fa674b7`) changed none of `Registry.cls`, `Read.cls`, `EntityType.cls`, `Descriptor.cls`, `ReadTool.cls`, `SurfaceCoverage.cls`, `StageTwoTools.cls`, `ToolRoundTrip.cls`, `ToolWrite.cls`, `screens.generated.ts`, `strings.ts`, `screen-actions.ts` or `screen-outlet.ts` since the merge base.

- Every edit there is add-only, except the "fourteen sources" to "fifteen sources" message in `Registry.cls` and `screen-mirror.mjs`. That one is a one-word change that Task 0 re-checks.
- `ToolWrite`, the governance baseline, the prohibited set, `screen-actions.ts`, `screen-outlet.ts`, `app.routes.ts` and `angular.json` are untouched.

**Named limits:**

- Member values are not shown (Part C).
- A cube's `Last build` is empty when no tracked build or repair is recorded.
- Subject areas and abstract cubes are not listed.
- A term list is read whole before the cap.
- Folder items list only items the caller's resources admit and the portal shows.
- A relationship to a cube the caller cannot see is still named.

**Weight.** No page code and no lazy chunk. The initial bundle gains seven mirror entries and about 50 strings, roughly 8 to 10 kB (inference). It was about 1.92 MB against `maximumWarning` 1992kB.

## Verification

**Shared surfaces:**

- the read source kinds (the "fifteen sources" message in `Registry.cls`, `screen-mirror.mjs` and five test classes; `screen-mirror.test.mjs`'s port list);
- the `EntityType` count;
- `PortGate`'s `ROSTER`;
- `StageTwoTools`' `Elsewhere`, `SurfaceCoverage`'s screen rows, `ReadTool`'s count and names, `ToolRoundTrip`'s `REFUSEEMPTY`;
- `Navigation.cls`' analytics block;
- `InteropFloor`'s `BASESCREENS` and `BASETOOLS`, and `DeveloperFloor`'s `SCREENS`, `TOOLS` and tools-count comment;
- `navigation.test.mjs`'s routes; `screen-mirror.test.mjs`'s owners;
- the structural walk's `SKIP` and its baseline;
- the strings table, and EXPERIENCE.md :159 and :604;
- USER's analytics flags while a probe runs;
- the built-screen count Screen permissions derives (+7).

*Every test added or changed passes on a fresh environment, in either order.* `AnalyticsProbe` creates and removes everything it asserts on, and restores USER's flags.

**Setup (slot B; never the dev instance `ocupilot-slot-b`):**

- `(loop)` **Load `src`:**
  1. Run `rsync -a --checksum --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-20/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`.
  2. In `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`, run `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)`.
- `(loop)` **Before any browser run:** `cd ui && npm run build && docker exec ocupilot-b-ci sh -c 'cd /durable/iris/csp/ocupilot && rm -rf ./*' && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`.

**Commands.** Run each in the foreground with `timeout: 600000`, one at a time. Read each class's result from `%UnitTest_Result`. Size batches from `ui/tools/ci-timings.json` to about 8 minutes.

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.AnalyticsPort --class OcuPilot.Test.AnalyticsGate --class OcuPilot.Test.AnalyticsDescriptor --class OcuPilot.Test.PortGate`. Expected: green.
- `(loop)` The same runner, in batches, with `StageTwoTools`, `SurfaceCoverage`, `ReadTool`, `ToolRoundTrip`, `ToolEmit`, `Navigation`, `Wire`, `Descriptor`, `NamespaceFeatures`, `ScreenAccessWire`, `SqlActivityDescriptor`, `DocDbDescriptor`, `InteropDescriptor`, `AdminPairCorpus` and `MetricsDescriptor`. Then `InteropFloor` and `DeveloperFloor`, then every class the sweep changes. Expected: green.
- `(loop)` `cd ui && npm run test:tools`, then `cd ui && npm run test:components`. Expected: green.
- `(loop)` `cd ui && npm run build -- --verbose`. Expected: the prebuild chain is green, no new lazy chunk, and the initial total is under 1992kB (record it).
- `(loop)` `uv run scripts/check-objectscript.py <each changed .cls>` and `bash scripts/lint-docs.sh`. Expected: clean.
- `(loop)` `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/<file>`, one file per call, after the redeploy:
  - `analytics.browser-spec.mjs`
  - `namespace-categories.browser-spec.mjs`
  - `a11y-structural-invariants.browser-spec.mjs` (about 430 s)
  - each side-bar spec the sweep changes

  Expected: green.
- `(once)`, **lead-owned (the runner's):** the full ObjectScript sweep, `cd ui && npm test`, `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`, and Rule 30's fresh check.
- **Left to CI:** the full browser suite.

**Planned pinning mutations (Rule 19).** Revert each byte-identical. Reload, or rebuild and redeploy, before the next.

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | The Cubes read answers `Facts` as 0 | `AnalyticsPort`'s Cubes test (1,000 expected) and the browser AC1 rows |
| AC1 | The Dimensions read uses `%GetMemberTree` | `TestTheReadsWriteNothing` (the session node) |
| AC1 | Folder items read favorites through `%GetFavoritesForUser` | `TestTheReadsWriteNothing` (the dangling favorite is deleted) |
| AC2 | The Relationships tab drops `rowTarget` | The browser AC2 related-cube leg |
| AC2 | `%ToObj`'s extra fields are not joined into `Fields` | The port's entries test and the browser AC2 `Note` clause |
| AC3 | `Admit` omits the analytics check | `AnalyticsPort`'s HSCUSTOM test (200 with no rows, not 409) and the browser AC3 |
| AC3 | `Admit` checks database READ after the vendor call | `AnalyticsGate`'s P2 clause (an unnamed `<PROTECT>` refusal) |
| AC3 | `TERMLISTPAIRS` loses `%DeepSee_PortalEdit:USE` | `AnalyticsGate` (P1 reads Term lists), and `PortGate`'s denial leg |
| AC3 | The tabs skip `%CheckPrivilege` | `AnalyticsGate`'s guarded-cube tab clause |
| AC4 | The read tool's view drops `LastBuild` | `AnalyticsGate`'s integration clause |
| AC5 | One analytics `Elsewhere` row is removed | `StageTwoTools.TestTheRosterAndElsewhereAreEveryRegisteredScreen`, alone |
| AC5 | A pale color in a list cell | The browser structural test |
| AC6 | `Remove` skips the flag restore | `AnalyticsProbe.Gone()` in each suite's `OnAfterAllTests`, and the browser `after` |

**Mutations run (Rule 19), each reverted byte-identical and reloaded or redeployed before the next (`ocupilot-b-ci`).**

- mutation: the Cubes read answers `Facts` as 0 -> `AnalyticsPort.TestCubesEqualTheVendorsAnswer` and the browser AC1.
- mutation: the Dimensions read also calls `%GetMemberTree` -> `AnalyticsPort.TestTheReadsWriteNothing`, alone (it ends the process's DeepSee session first, because the vendor writes the session node only once per process).
- mutation: Folder items reads favorites through `%DeepSee.UserPortal.Utils.%GetFavoritesForUser` -> `AnalyticsPort.TestTheReadsWriteNothing` and `TestFolderItemsAnswerTheVendorsList`.
- mutation: the Relationships tab drops `rowTarget` (mirror regenerated, bundle rebuilt and redeployed) -> the browser AC2 related-cube leg ("the row carries no .ocu-data-table-link").
- mutation: `%ToObj`'s extra fields are not joined into `Fields` -> `AnalyticsPort.TestTermListsAndEntriesAnswerTheVendorsList` and the browser AC2.
- mutation: `Admit` omits the analytics check -> `AnalyticsPort.TestANamespaceWithoutAnalyticsIsRefusedOnEveryEndpoint` and the browser AC3.
- mutation: `Admit` omits the globals-database READ check, so the vendor call raises first -> `AnalyticsGate.TestAPrincipalWithoutTheDatabaseIsRefusedNamingIt` (the port's refusal is unnamed `PORT.ACCESSDENIED`).
- mutation: `TERMLISTPAIRS` loses `%DeepSee_PortalEdit:USE` -> `AnalyticsGate.TestTermListsNeedTheTermListManagersPair`, `PortGate.TestEveryPortEvaluatesItsDeclaredGate` and `analytics.test.mjs`.
- mutation: the tabs skip `%CubeExists` and `%CheckPrivilege` -> `AnalyticsGate.TestTheVendorsOwnResourceChecksStillHideWhatTheyHide`; dropping `%CheckPrivilege` alone reddens nothing, because the vendor's `%CubeExists` already answers false for a cube its resource check hides.
- mutation: `Screen/Tool/Read.View` removes `LastBuild` from each row -> `AnalyticsGate.TestTheAgentsCubesReadAnswersTheScreensRows`.
- mutation: the `AnalyticsCubeList` `Elsewhere` row removed -> `StageTwoTools.TestTheRosterAndElsewhereAreEveryRegisteredScreen`, alone.
- mutation: `.ocu-data-table-cell` takes `color: var(--ocu-surface-container-high)` (a hard-coded color is refused by `client-lint`) -> the browser AC5 (`analytics/cubes|contrast|dark ... 1.43:1`).
- mutation: `Remove` skips the flag restore -> `OnAfterAllTests` of `AnalyticsPort` and `AnalyticsGate` ("left probe state in USER: analytics reported") and the browser `after`.
- mutation: the analytics branch of `Screen/Read` asks the port for `maxRows` rows instead of one more -> `AnalyticsGate.TestTheVendorsOwnResourceChecksStillHideWhatTheyHide` (the matrix's Cap row: two cubes, `truncated` true).
- mutation: `AnalyticsPort.LocalStamp` answers its input without converting it -> `AnalyticsPort.TestTheTimeShapesAreTheInstancesLocalTime`, its two zone legs (sessions started with `TZ` set; the throwaway itself runs in UTC).
- mutation: `AnalyticsPort.Fail` puts the vendor's status text into the fault's reason -> `AnalyticsPort.TestAVendorFailureIsAnsweredInThePortsWordsAndLoggedWhole` (the 500 cases).
- mutation: `Admit` omits the routines-database READ check -> `PortGate.TestEveryPortEvaluatesItsDeclaredGate` (the routines leg, in HSLIB through the seam).
- mutation: `Remove` restores `DeepSeeEnabled` and not `iKnowEnabled` -> `OnAfterAllTests` of `AnalyticsPort` ("the two flags ... did not read back as recorded"; the next unmutated `Remove` restored USER).
- mutation: the FolderItems loop in `Collect` ignores `maxRows` -> `AnalyticsPort.TestTheRequestShapesTheGateAndThePortRefuse` (Folder items to two).

**In-stage decisions and measurements (implement, 2026-10-20).**

- Task 0 measured on `ocupilot-b-ci`: after the fixture's `Modify`, the same process reads `Reports("analytics","USER")` 1. `GetLastUpdate` is the server's local time (`UTCtoLocalWithZTIMEZONE`, unaffected by the process's `$ZTIMEZONE`) and answers the same for a principal holding no SQL privilege; `FolderItem.timeModified` is UTC, so Folder items converts it to local. `%ToObj`, `%GetCubeFactCount`, `GetLastUpdate`, the cube, term list and folder reads write no `^DeepSee*` or `^OBJ*` node (4,175 nodes unchanged, `%GetMemberTree` as the control adds one), each under 0.5 ms once warm (the first `GetLastUpdate` 17 ms). `NormalizePage` of the three `.zen` pages is the three class names. Cube `Resource` as the caller: a caller lacking `%DeepSee_Admin` has the guarded cube absent from `%GetCubeList`, refused by `%CubeExists`, `%CheckPrivilege` and `%GetCubeMeasures`, yet `%GetDimensionList` still answers it, so every tab asks first.
- A tab of a tabbed group may declare `rowTarget` (`RowTargetProblem` in `Registry.cls` and `rowTargetProblem` in `screen-mirror.mjs`), because this spec's descriptor table gives the Relationships tab a `rowTarget` and both validators refused a row target on any archetype but `list`. A `detail` screen that is no tab is still refused. AD-5's row-target sentence names lists only and is left unedited (an AD amendment is the lead's, Rule 20; veto-window item); the lead may extend it with: "A tab of a tabbed group (a `detail` screen drawing a table) may declare one too: a cube's Relationships tab opens the related cube's Measures tab (Story 20.11)."
- The Dimensions tab's name column is `Level`; the Cubes list and its tabs omit `ownPrivileges`, as every descriptor without an own pair does; `Facts` is JSON null when the vendor's count fails; the Cubes cap is applied to the cube list, so a failing cube is not hidden.
- `analyticsRefusalNamespace` joins `strings.test.mjs`'s namespace-key roster, and `AnalyticsTermListEntryList`'s `Key` joins its credential-name exemptions, as the lookup entries' do.
- The page does not draw the refusal sentence for a failed list read (the shell draws `request refused` and Retry); browser AC3 therefore pins the 409 body's code and sentence and the shell's refusal, not a drawn sentence.
- Deferred: the `(once)` line and the full browser suite (the lead's and CI's); drawing the refusal sentence on a failed list read (a client change this spec forbids); Parts B, C and D.

## Auto Run Result

Status: done
Blocking condition: none

- **Implemented (Part A):** `AnalyticsPort` (gate in the AD-29 order, then the listed `%DeepSee` reads, switched by save and restore), the `analytics` read source kind, `AnalyticsError`, four entity types, and seven descriptors (Cubes with its Measures, Dimensions and Relationships tabs, Term lists with entries, Folder items), with strings, the regenerated mirror, EXPERIENCE.md :159 and :604, and the rosters.
- **Files:** new `Port/AnalyticsPort.cls`, `Api/AnalyticsError.cls`, seven `Screen/Descriptor/Analytics*.cls`, `Test/Analytics{Probe,Port,Gate,Descriptor,GateSeam}.cls`, `ui/tools/analytics.test.mjs`, `ui/browser/analytics.browser-spec.mjs`; edited `Screen/Read.cls`, `Screen/Registry.cls`, `Kernel/EntityType.cls`, `Api/Error.cls` (two delegation lines), `ui/tools/screen-mirror.mjs`, the mirror, `strings.ts`, `structural-walk.mjs`, `scripts/ci-throwaway.sh` (arming roster), and the roster and sentence tests named in Verification.
- **Review:** 30 findings (medium 7, low 16, false 7): 12 patched, 18 rejected with reasons, none deferred (`deferred:` is empty). Patched: the UTC-to-local conversion now has two `TZ` session legs; the fault mapping, the routines-database READ half, the cap on Measures and Folder items, the snapshot's own failure, the flag read-back (AC6) and the browser spec's cleanup are each pinned and mutation-proved.
- **Follow-up review recommended: true.** Seven medium findings were patched (all test-side). The unverified risk: the two `TZ` session legs start `iris session` children and need the container's zone data, which this throwaway has; CI's instance legs run them for the first time (inference).
- **Verification (on `ocupilot-b-ci`, after the last edit):**
  - the 4 analytics classes (21 tests) and 16 sweep classes (203 tests) green; `AdminPairCorpus` is a corpus and runs no method;
  - `npm run test:tools` 2040, `npm run test:components` 3272, `npm run build` green with no new lazy chunk, initial total 1.98 MB (351.88 kB transfer; under the 1992 kB expectation and the fixed 2500/4000 kB budgets);
  - `check-objectscript.py` 0 problems, `lint-docs.sh` 0; `analytics.browser-spec.mjs` 4/4, `namespace-categories` 4/4, `a11y-structural-invariants` 13/13 (run before the test-only patches; the bundle is unchanged since).
  - The `(once)` line and the full browser suite are the runner's and CI's.
- **For the lead:**
  - **Veto-window item:** the tab arm of `RowTargetProblem` and `rowTargetProblem` (the Relationships tab's `rowTarget`, which the descriptor table requires) is outside AD-5's sentence, which names lists. The sentence is left unedited; suggested text is in the in-stage decisions above.
  - Browser AC3 pins the 409 body and the shell's generic refusal, not a drawn sentence (page code is out of this part).
  - `ProductionProbe.Remove` deletes the whole `OcuPilotProbe` package, so it would remove the analytics fixture if it ran mid-suite; the analytics probe heals its own leftovers.
