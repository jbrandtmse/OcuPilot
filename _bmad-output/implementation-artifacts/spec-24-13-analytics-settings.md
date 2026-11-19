---
title: 'Story 24.13: Analytics settings (Batch 1: the read surface, and partly applied cube updates audited)'
type: 'feature'
created: '2026-11-19'
status: 'done'
baseline_revision: 'b3866e9645634cfaede4cebec341af6c53a6de69'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-12-quality-measures.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-20-34-the-cube-manager-s-build-and-synchronize.md'
warnings: ['oversized']
deferred:
  - summary: >-
      A raised exception from the vendor's build or synchronize after a cube was updated is not pinned by any test.
    evidence: |-
      The `Catch` blocks of `VendorBuild` and `VendorSynchronize` merge the statistics so `PerformCube` can name the updated cubes, but `AnalyticsCubeSeam` replaces both methods whole and the real vendor reports a lock failure as a status, so no test enters either `Catch`. Deleting the merge line leaves every test green.
    location: >-
      src/OcuPilot/Port/AnalyticsPort.cls VendorBuild, VendorSynchronize
    severity: medium
---

<intent-contract>

## Intent

**Problem:** The classic Analytics Settings page (`%DeepSee.UI.Settings`: General, Worklists, Run-time Variables, User-defined Icons) has no OcuPilot screen. Separately (DW-2518, owner answer U-34 A), a cube build or synchronize the vendor ran that then failed after updating some cubes records no `ConfigChange` row, because `AnalyticsPort.PerformCube` returns before `AuditWrite` on every failed outcome.

**Approach:** Batches inside the story (Design Notes › Questions 1); this spec is Batch 1. `AnalyticsPort` gains four `LIST` endpoints, `Settings`, `Worklists`, `RuntimeVariables` and `UserIcons`, read by four descriptors forming one tab group, `analytics/settings`, whose read tools the registry derives; nothing about settings is written. `PerformCube` records a failed `ConfigChange` row naming the cubes the vendor reports updated.

## Boundaries & Constraints

**Always:**

- **Gate, in AD-65's order:** `SETTINGSPAIRS` (Questions 2), then `AdmitNamespace`. No vendor call before both pass.
- **Rows** (namespace `?ns=`; values as the classic page's `%OnAfterCreatePage` shows them, `irislib/%DeepSee/UI/Settings.cls` :286-404, 408-428):
  - `Settings`: `{Name, Value, Stored}`, one row per node the page's `SaveToServer` (:253-273) and `SetCustom` (:456) write: `Scheme` (`simple` when unset), `ChartSeriesScheme`, `PageTitle`, `CompanyName`, `CompanyImage`, `CompanyLink`, `GoogleMapsKey`, `MailEnabled` (0 when unset), `DefaultResource`, `DashboardNoTitle`, `DashboardNoBorder`, `Controls.showCalculated`, `autosaveAnalyzer`, `autosaveUserPortal`, `Worklist` (the customized-worklists flag). `Stored` is whether the node exists. `GoogleMapsKey`'s `Value` is `OcuPilot.Port.SqlPort.#CREDENTIALMASK` when stored, `""` when not, and never the key (Questions 3).
  - `Worklists`: `{Page, Panel, Worklist, Class, Shown}`, 16 rows: pages `Home` and `DashboardViewer`, panels 1 and 2, the four classes the page lists (:355-358), `Worklist` the class's `%GetName()`, `Shown` the node's existence (:419).
  - `RuntimeVariables`: `{Name, Value, Comment, Context}` from `%DeepSee.UserPortal.Utils.%GetUserSettingsList(.l, "")`; `Value` is the stored expression as text.
  - `UserIcons`: `{Name, Path}` from `%GetUserIconList`.
- **Vendor calls are the measured pure reads only:** `%GetUserSettingsList`, `%GetUserIconList`, the four worklist classes' `%GetName`, and `^DeepSee.UserPortalSettings` read by name (Questions 4).
- **One capped read** per screen and tool, reporting truncation (AD-36); text reaches the model through the sanitizer (AD-60); paths and expressions are shown as text, never rendered or run (AD-11).
- **DW-2518:** after a failed outcome (`denied`, `busy`, `absent`, `failed`, or a raised exception) `PerformCube` records, after the restore, one `AuditWrite` row with the same verb and cube and effects `{namespace, cubes, failed: true}`, where `cubes` are the cubes whose vendor statistics carry a `status` that is OK or holds only #20006, by logical name; none applied, no row. The answer sent is unchanged.

**Never:**

- `%GetUserSetting` (it executes the expression, `Utils.cls` :552-575), or any settings write: `SaveToServer`, `SetOption`, `SetCustom`, `%SetUserSetting`, `%SetUserIcon`, `%Remove*`, `%Clear*`.
- `emptyAgentKey` on these read-only descriptors; a spine edit (the lead applies the sentences below).
- A second vendor build or synchronize call in `PerformCube`, or a changed refusal for any outcome.

## I/O & Edge-Case Matrix

Rows run in USER on `ocupilot-b-ci`; every setting a test changes is restored from a snapshot taken first.

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Stored | Marker values written through the vendor's own methods for every node, a variable, an icon, two worklist options | Each row equals the stored value; `Stored` true; the two options `Shown` true | - |
| Unset | No node stored | 15 Settings rows with the page's defaults, `Stored` false; 16 Worklists rows `Shown` false; no variable or icon row | - |
| Key | A marker Google Maps key stored | Its row's `Value` is the mask; the key text is in neither the screen read nor the tool answer | - |
| Never run | A variable whose expression is `$Increment(^OcuProbe2413Ran)` | Read as text; `^OcuProbe2413Ran` stays undefined | - |
| Cap | `maxRows` below the count | `truncated` true | - |
| Gate | Without the pair; a namespace without analytics | Refused before any vendor call | 403 naming the pair; 409 `ANALYTICS.NAMESPACE` |
| Partial build (seam) | Statistics: Categories OK, Visits #20005; answer #20005 | One row `build`, `failed` true, `cubes` `["OcuPilotProbeCategories"]` | 409 `ANALYTICS.CUBE.BUSY` |
| Partial synchronize (seam) | Statistics: target OK, dependent failed; answer failed | One row `synchronize`, `failed` true, the target only | 409 `ANALYTICS.CUBE.FAILED` |
| Partial build (real) | Another process holds Visits' build lock; the precondition probe answers free | Categories rebuilt; one failed row naming Categories alone | 409 `ANALYTICS.CUBE.BUSY` |
| Nothing applied | Every existing seam failure leg | No row, as today | unchanged |

</intent-contract>

## Code Map

Paths under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-24` (HEAD `a90e7151f`). **Follow Story 24.12 Batch 1's read-surface commit `0b6c2cdb5` file for file** (QA `52720f987`), with the top-level tab-group form of `Screen/Descriptor/OAuthServerDescriptionTab.cls` (first tab carries the side-bar position, the others 0, archetype `detail`). Epic 21 has changed none of these files beyond feature (`git log --no-merges origin/OCU-1-epic21 ^origin/feature/OCU-1_ocupilot-mvp`, 2026-11-19: only `ci.yml`, `ci-timings.json` and the spine); re-run before implementing.

- **`src/OcuPilot/Port/AnalyticsPort.cls`**: `ENDPOINTS` :120, endpoint parameters beside :152-158, `SETTINGSPAIRS` beside :178, a `Pairs` :561 branch; `Collect` :847 branches after the quality-measure one (:996-1056), between the switch and restore; `Rows` :1083 branches after :1186. DW-2518: `PerformCube` :2293 (failed branches :2308-2314), `VendorBuild` :2341 (merge the statistics in the `Catch` too), `VendorSynchronize` :2367 (pass `%SynchronizeCube`'s seventh argument, its statistics, to a new output), `AuditWrite` :2499 reused; a new pure helper for the applied cubes, beside `BuildLines` :2453. Vendor: `%BuildCube` sets each cube's `status` before failing (`irislib/%DeepSee/Utils.cls` :276), `%SynchronizeCube` likewise (:2031).
- **Descriptors** (new): `AnalyticsSettingList.cls` (route `analytics/settings`, side bar 11, tab 1), `AnalyticsWorklistList.cls` (`.../worklists`, 2), `AnalyticsRuntimeVariableList.cls` (`.../variables`, 3), `AnalyticsUserIconList.cls` (`.../icons`, 4); `classicPage` `%DeepSee.UI.Settings`; ids single by `Name`, Worklists composite `[Page, Panel, Class]`; no actions.
- **`src/OcuPilot/Kernel/EntityType.cls`**: `analytics-setting`, `analytics-worklist`, `analytics-runtime-variable`, `analytics-user-icon`.
- **Client:** `ui/src/app/core/strings.ts` (analytics block, after :8302, once ruled); `screens.generated.ts` and `Screen/Titles.cls` regenerated by `screen-mirror.mjs`. No page component.
- **Rosters:** every file 24.12's Code Map › Rosters names, found by grepping `AnalyticsQualityMeasureMetaList` and `qualitymeasuremetas`; `scripts/ci-throwaway.sh` arming roster (contended: add-only) with `ui/tools/ci.test.mjs`; `ui/tools/analytics.test.mjs` gains a Story 24.13 source guard.
- **Tests:** `Test/AnalyticsProbe.cls` (settings snapshot, markers, restore, `Left()`); new `Test/AnalyticsSettingsRead.cls` modeled on `AnalyticsQualityMeasureRead.cls`, armed by `OCUPILOT_ALLOW_PRINCIPALS`; `Test/AnalyticsCubeSeam.cls` (a `partial` mode per verb, and a `real` mode that calls the port's own vendor methods and answers the precondition probe free); `Test/AnalyticsCubeManager.cls` beside `TestTheVendorsAnswersAreMapped` :296; `ui/browser/analytics.browser-spec.mjs`.
- **EXPERIENCE.md:** one Fixed strings row after the table's last row.

## Tasks & Acceptance

**Execution:**

- [x] Task 0: on `ocupilot-b-ci`, confirm the Partial build (real) row's state (Categories' `status` OK, Visits' #20005) before relying on it; record it under Design Notes › Measured.
- [x] `AnalyticsPort.cls`: the four endpoints, pairs, `Collect` and `Rows` branches; the DW-2518 change.
- [x] The four descriptors, entity types, strings (once ruled), the regenerated mirror and titles, the EXPERIENCE.md row.
- [x] Tests: the fixture, `AnalyticsSettingsRead` (the read rows of the matrix at the port and over `GET /screens/<id>/read`, the journal scan, the restore check), the seam modes and the DW-2518 test, the browser test, every roster.

**Acceptance Criteria:**

- **AC1 (round trip).** Given marker settings written through the vendor's own methods. When the four screens are read. Then every row equals what those methods stored, and an unset node reads the page's default.
- **AC2 (Integration, Rule 1).** Given the same settings. When `GET /screens/<id>/read` and the agent's read tool run for each screen. Then both answer the same rows.
- **AC3 (browser).** Given the markers. When a person opens Analytics › Settings and each tab. Then each shows its rows, and the Google Maps key row shows the mask.
- **AC4 (writes and runs nothing).** Given the markers. When every read runs, first on a fresh instance. Then a journal scan of the calling process finds no global write, and the variable's expression never ran.
- **AC5 (the key is never answered).** Given a stored marker key. When every read and tool runs. Then the key text appears in no answer.
- **AC6 (declared and rostered).** Given the four descriptors. When the roster tests run. Then each holds their rows, and removing one row reddens that test alone.
- **AC7 (leaves USER as found).** Given any new or changed test, in either order. When it ends. Then the three settings globals equal their snapshot and no marker remains.
- **AC8 (DW-2518).** Given a build or synchronize the vendor ran that updated at least one cube and then failed. When the cube manager's write answers. Then its refusal is unchanged and one `ConfigChange` row for that verb and cube carries `failed` true and names exactly the updated cubes; a failure that updated none records no row.

## Spec Change Log

- 2026-11-19, spec gate (runner): Questions 1-5 kept as recommended (veto item U-115): three batches, this spec Batch 1; pairs `%DeepSee_Portal:USE,%Development:USE`; the key masked; `^DeepSee.UserPortalSettings` read by name with the AD-65 line left proposed; the proposed strings. The AD-15 sentence is applied to the spine (owner answer U-34 A).

## Review Triage Log

### 2026-11-19 — Review pass

- verdicts: 11 findings — high 0, medium 2, low 8, false 1, maybe-false 0
- findings:
  - `[medium]` `[defer]` The `Catch` merges of the statistics in `VendorBuild` and `VendorSynchronize` are run by no test: the seam replaces both methods whole, and the real vendor returns a lock failure as a status, so a raised exception after a cube updated records no pinned row — a test needs a way to make the vendor call raise after one cube is updated, which the seam cannot give without replacing the wrapper under test; recorded in frontmatter `deferred:`.
  - `[low]` `[patch]` Two `'[` assertions in `TestAFailedUpdateRecordsTheCubesItUpdated` tested upper-case text against logical names and could not fail — the build one now tests `OcuPilotProbeVisits`; the dependent one stays upper-case because the seam's dependent cube has no logical name and falls back to its index.
  - `[medium]` `[patch]` Assertions guarded by `If $IsObject(row)` with no assertion that the row exists (key, scheme, both variables, the icon, the capped and fitting reads) passed vacuously when a read failed — an existence assertion now precedes each.
  - `[low]` `[patch]` `TestTheStoredKeyIsNeverAnswered` switched namespace around `SaveToServer` with no `Try` — a `Try`/`Catch` now restores it.
  - `[false]` `[reject]` The synchronize statistics' key spelling may differ from the port's logical-name lookup — `%SynchronizeCube` files `pSynchronizeStatistics("cubes", tCubeToBuild, "status")` under the same index `%BuildCube` uses (`irislib/%DeepSee/Utils.cls` :274-276, :2030-2031), and `$Get(pNames(i), i)` falls back to the index anyway.
  - `[low]` `[reject]` Intent audit: a stored empty Google Maps key reads stored with no mask, where the contract says the mask whenever stored — Decided in-stage (implement) 1: the mask means a key exists, and an empty value is not one; reversible in one line of `Collect`.
  - `[low]` `[reject]` Intent audit: `Stored` of the `Worklist` row is the node's own value (`$Data # 2`), `Shown` is any existence — the customized flag's value is what the classic page reads, and the two differ only for options stored without the flag.
  - `[low]` `[reject]` Intent audit: the cap test omits User-defined icons and the tool leg omits `truncated` — the icons branch shares the other list's loop, and the screen leg pins the flag; not worth a new test.
  - `[low]` `[reject]` Intent audit: a denied, absent or raised outcome after a partial update has no test of its own — every non-ok outcome takes the one `AuditFailedUpdate` branch the busy and failed legs exercise.
  - `[low]` `[reject]` Intent audit: the gate pair's alternative `%DeepSee_Admin:USE` is untested and the `emptyAgentKey` reading — the pairs are the spec's ruled set (U-115) and every descriptor's `emptyAgentKey` is empty.
  - `[low]` `[reject]` Intent audit: the `real` seam mode overrides the port's state read and the source-text guard cannot see a dynamic call to a forbidden method — the seam's reason is recorded (Decided in-stage 4), and the journal scan catches a write at run time.

## Design Notes

**Questions for the runner (intent gap).**

1. **Batches (Rule 5 tier 2).** The page has four tabs and eight writes. Recommended: three batches in this story, each planned after the previous code head is committed, `done` when all three are. **Batch 1 (this spec):** the four reads and DW-2518. **Batch 2:** General and Worklists writes: `analytics.settings.set` over the shared Set value page (`ui/src/app/areas/os-management/config-settings.page.ts`, Stories 21.3 and 21.14), which adds `Kind` and `Accepts` to the Settings rows and reuses `OcuPilot.Api.ConfigError`'s accepts sentences, a secret-only write for the key (AD-56), and Worklists `show` and `hide`. **Batch 3:** run-time variable and icon `add`, `set` and `remove`, as the term-list entry writes (Story 24.2). Alternative, two batches: rejected for size (24.11's seven writes ran oversized).
2. **Pairs (veto: stricter than classic).** The classic page admits `%DeepSee_Admin:USE` or `%Development:USE` (`RESOURCE` :16, `%OnPreHTTP` :976-980); OcuPilot's pairs are a conjunction. Recommended `%DeepSee_Portal:USE,%Development:USE`, as MDX query took for the same classic resource (`MDXPAIRS`); a run-time variable is code. Alternative: `MANAGERPAIRS`' `%DeepSee_Admin:USE`.
3. **The Google Maps key is never shown (veto: stricter than classic).** Conventions › Secrets: never returned. The row reads the SQL credential mask, so a person still sees that one is stored.
4. **AD-65 (it names the port's vendor-global use as the cube lock probe).** No vendor class reads `^DeepSee.UserPortalSettings`; the classic page reads it by name. Recommended: read it by name, measured to write nothing, with the proposed AD-65 line below.
5. **Proposed strings (veto).**
   - Labels: "Worklists", "Run-time variables", "User-defined icons", "Panel", "Worklist", "Shown", "Context", "Stored". Reused: "Settings" (`interopItemTabSettings`, side bar), "General" (`processDetailsGroupGeneral`, tab), "Setting", "Value", "Name", "Expression", "Comment", "Path", "Page", "Class".
   - Columns: General: Setting, Value, Stored; Worklists: Page, Panel, Worklist, Shown; Run-time variables: Name, Expression, Comment, Context; User-defined icons: Name, Path.
   - Empty states: "No analytics setting can be read in this namespace." · "No worklist can be read in this namespace." · "No run-time variable is defined in this namespace." · "No user-defined icon is defined in this namespace."
   - Prompts, General: "Summarize the analytics settings in this namespace." · "Which settings still have their default value?" · "Can dashboards send email in this namespace?"
   - Prompts, Worklists: "Which worklists does the home page show?" · "Are the worklists customized in this namespace?" · "Which worklists does the dashboard page show?"
   - Prompts, Run-time variables: "Summarize the run-time variables in this namespace." · "Explain what each run-time variable's expression returns." · "Which run-time variables have no comment?"
   - Prompts, User-defined icons: "Summarize the user-defined icons in this namespace." · "Which icons point outside this instance?" · "List each icon's name and path."
   - Agent empty-state phrases Batch 3 will need: "add a run-time variable" · "add a user-defined icon".

**Spine sentence (owner-sanctioned, U-34 A):** AD-15, appended to the cube manager paragraph: "A build or synchronize that the vendor ran and that then failed records the same `ConfigChange` row with `failed` true, naming only the cubes whose own status in the vendor's statistics reports them updated, and records none when no cube was updated."

**Proposed spine line (the owner's attended update; never written here).** AD-65: "`%DeepSee.UserPortal.Utils` `%GetUserSettingsList` and `%GetUserIconList` and the worklist classes' `%GetName` join the measured pure reads, `^DeepSee.UserPortalSettings` is read by name as the classic Settings page reads it, and `%GetUserSetting`, which runs a run-time variable's expression, is never called (Story 24.13)."

**Measured** (plan, 2026-11-19, `ocupilot-b-ci`, USER; a probe variable and icon were set first and removed after, nothing left): the three globals map to `/durable/iris/mgr/user/`, USER's globals database; `%GetUserSettingsList`, `%GetUserIconList`, `%GetColorSchemes`, `%GetChartSeriesSchemes`, the four `%GetName` calls and reads of `^DeepSee.UserPortalSettings` recorded no set or kill of the process in the journal, where a control `Set` was the one record; `%GetName` answers "Favorites", "Recent items", "Alert List", "Details".

**Measured (Task 0, implement, 2026-11-19, `ocupilot-b-ci`, USER).** A child process held `^DeepSee.Build("OCUPILOTPROBEVISITS")` and `%BuildCube("OcuPilotProbeCategories", 1, 0, 0, 0, 0, .stats)` returned `#20005` (code 20005 alone). `stats("cubes","OCUPILOTPROBECATEGORIES","status")` read `1` (OK) and `stats("cubes","OCUPILOTPROBEVISITS","status")` read the `#20005` error status; both cubes' `async`, `method` and counters were present, and the failed cube's `factCount` (5) and `elapsedTime` were its predecessor's, since `%BuildOneCube`'s statistics are not cleared on the lock failure. So a cube's `status`, not its counters, says whether it was updated. The probe and the holder were removed after (`Gone` 1). The synchronize's per-cube `status` is read from source (`%SynchronizeCube`, the vendor sets it before it throws) and exercised through the seam.

**Decided in-stage (plan).**

1. A tab group, as OAuth's, because the classic page is one page of four tabs; General first, carrying the side bar.
2. General rows are name and value rows, Story 21.3's shape, so Batch 2 extends its Set value page rather than copying a form page; `Kind` and `Accepts` wait for Batch 2, which defines what each accepts.
3. Names are the vendor's node names (AD-13); the nested `Controls,showCalculated` node is `Controls.showCalculated`.
4. The Dashboard top panel's fixed Filters item is not stored, so it is no row.
5. A variable's evaluated value, which the classic page shows, is not read: the read is shared with the agent's tool, which never runs code (AD-36, AD-60).
6. Icons and logos are paths shown as text, never loaded (AD-11).
7. No gate test class: as 24.12 Batch 1 Decided 7, `PortGate` pins the pair and the read class the namespace refusal.
8. DW-2518 rides Batch 1: it is small, independent, and its sentence is gated now.

**Decided in-stage (implement).**

1. A stored Google Maps key of empty text is stored and reads no mask: the mask means a key is stored, and the save the classic page makes stores an empty one when it is given none.
2. The key never enters `pData`: `Collect` blanks it and passes only whether one is stored, and `Rows` (after the restore, where `SqlPort` is visible) turns that into the mask.
3. `Panel` is a number; `Shown`, `Stored` and `Compiled`-style flags are booleans; a Settings row's `Value` is always a string (`MailEnabled` and `Worklist` read as `0` or `1`).
4. `AnalyticsCubeSeam`'s `real` mode overrides `CollectState`, not the port's `Here` methods: they run in the target namespace, where the seam class is not visible (AD-16).
5. The probe's settings fixture keeps its snapshot in `^OcuPilotProbeSettings` in `USER`, so a run that died is restored by the next `Remove`, and `ClearSettings` is the one place that kills the three globals, to make the unset state the matrix needs.
6. `%SynchronizeCube` is called with the vendor's own defaults for its fourth to sixth arguments (`1, 1, 0`) to reach its statistics argument.

**Governing ADs (Rule 6):** AD-65 (port, pure reads), AD-29 and AD-8 (gate), AD-16 (switch), AD-36 (capped read), AD-5, AD-44 and AD-24 (descriptors, classic page, context), AD-11 and AD-60 (text is untrusted, no code runs), AD-35 and Conventions › Secrets (the key), AD-13 (ids), AD-15 (DW-2518's row).

**Integration and linkage (Rules 1, 2).** `Consumes:` `AnalyticsPort`'s gate, `Screen/Read.cls`, the registry's derived read tools, `Test/AnalyticsProbe`, `Kernel.Audit.Event.Record` through `AuditWrite`. `Consumed-by:` Batches 2 and 3, whose writes compose their fresh read from these endpoints. AC2 is the Integration AC. Siblings extended: `Collect`, `Rows`, `Pairs`; the 24.12 descriptors and `OAuthServerDescriptionTab`'s tab form; `AnalyticsQualityMeasureRead`; `AnalyticsCubeSeam`; `SqlPort.#CREDENTIALMASK`.

**Ledger inbox:** DW-2518 addressed by AC8.

## Verification

**Commands** (one `ci-runner` call per message):

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.AnalyticsSettingsRead`, then likewise `AnalyticsCubeManager`, `AnalyticsDescriptor`, `ReadTool`, `PortGate`, `Descriptor`, `Navigation`, `StageTwoTools`, `SurfaceCoverage`, `ToolNavigateContract`, `ToolRoundTrip` and every class the shared-surface sweep changes. Expected: green.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`. Expected: green.
- `(loop)` `cd ui && npm run build`, `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/analytics.browser-spec.mjs browser/analytics-links.browser-spec.mjs`. Expected: green.
- `(once)` the full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17`, k = 1 to 17, one call each. Expected: green.
- `uv run scripts/check-objectscript.py`, `bash scripts/lint-docs.sh`. Expected: clean. The full browser suite is left to CI.

**Shared surfaces:** the analytics side bar, `ReadTool`'s count and names, the entity-type count, `AnalyticsDescriptor` `SCREENS`, the descriptor and endpoint rosters in `screen-mirror.test.mjs`, `StageTwoTools`, `SurfaceCoverage`, `ToolNavigateContract`, `Navigation`, `structural-walk.mjs`, the arming roster in `ci-throwaway.sh` and `ci.test.mjs`, and `AnalyticsCubeManager`'s audit-row assertions.

**Hermeticity:** every test added or changed passes on its first run on a fresh instance, in either order, and restores every analytics setting it changes.

**Mutations:** each applied to `ocupilot-b-ci`'s copy of the source, observed red, and reverted (`cmp` identical to the saved copy, reloaded).

- mutation: AC1 `AnalyticsPort.Collect` reads `Stored` as 1 for every settings row -> `TestAnUnsetNodeReadsThePagesDefault` red alone.
- mutation: AC2 `Screen.Tool.Read.View` answers no rows -> `TestTheScreensAndTheAgentsToolsAnswerTheSameRows` red on all four screens (the key test, which reads the tool's key row, red beside it).
- mutation: AC3 `AnalyticsPort.Rows` answers the key's stored text in place of the mask (`Collect` no longer blanks it) -> the Story 24.13 browser test red on the `GoogleMapsKey` row (`OcuProbe2413SecretKey` read for `[redacted]`).
- mutation: AC4 the variables branch of `Collect` calls the vendor's evaluating read -> `TestAAReadsMakeNoJournaledWrite` red naming the `SET ^OcuProbe2413Ran` records, and `TestAVariablesExpressionNeverRuns` red.
- mutation: AC5 the same key mutation as AC3 -> `TestTheStoredKeyIsNeverAnswered` red on the port, screen and tool legs, with `TestTheStoredSettingsAreReadAsStored` red on the key row.
- mutation: AC6 the `AnalyticsRuntimeVariableList` row removed from `StageTwoTools` -> `TestTheRosterAndElsewhereAreEveryRegisteredScreen` red alone; `SETTINGSPAIRS` naming `%DeepSee_PortalEdit:USE` for `%Development:USE` -> `PortGate` red on the four endpoints and `TestTheGateRefusesBeforeAnyVendorCall` red; the worklists branch without its `pMax` stop -> `TestACapBoundsTheListsAndTheScreensSaySo` red alone.
- mutation: AC7 `AnalyticsProbe.RestoreSettings` leaves `^DeepSee.User.Icons` as the markers made it -> `TestZRestoringTheSettingsLeavesThemAsFound` and the class's `OnAfterAllTests` red, naming the icon node.
- mutation: AC8 `AnalyticsPort.UpdatedCubes` lists every cube the statistics name -> `TestAFailedUpdateRecordsTheCubesItUpdated` (both rows) and `TestAPartialBuildTheVendorRanIsRecordedWithTheCubeItBuilt` red; `VendorBuild` merges the statistics into a variable the caller never reads -> the real-vendor test red alone, on the missing row.
- Each pre-existing failure leg of `TestTheVendorsAnswersAreMapped` asserts no row, and stays green: the seam's statistics carry no `status`, so no cube is reported updated.

## Auto Run Result

Status: done
Blocking condition: none

- **Review pass:** 11 findings (high 0, medium 2, low 8, false 1). Patched: existence assertions before every `If $IsObject(row)` guard in `AnalyticsSettingsRead`, a `Try`/`Catch` around the test's vendor save, and a falsifiable negative in `AnalyticsCubeManager`. Deferred: the unpinned `Catch` statistics merges (frontmatter `deferred:`). Rejected: the rest, each with its reason in the Review Triage Log. Follow-up review recommended: false (one medium patched, no high).
- **Sweep:** all 17 shards of the full ObjectScript sweep ran on a freshly rebuilt `ocupilot-b-ci`; shard 10 found `DeveloperFloor` red because the developer now opens the four new screens and four read tools (its pairs include `%Development:USE`), so its two rosters gained them (82 tools); the class then ran green and every other shard was green. `check-objectscript` 0 problems, `lint-docs` clean, `test:tools` 2331, `test:components` 3612, the two Story 24.13 browser specs and `analytics-links` green.
- **Residual risks:** a stored empty Google Maps key reads stored with no mask (Decided in-stage, implement 1); a raised vendor exception after a cube updated is not test-pinned (deferred); the proposed AD-65 line is still unwritten, as ruled.

- **Implement pass:** Task 0 measured (Design Notes › Measured); the four `AnalyticsPort` endpoints behind `SETTINGSPAIRS`, four descriptors in one tab group, four entity types, 24 strings and one EXPERIENCE.md row, the regenerated mirror and titles; DW-2518 (`UpdatedCubes`, `AuditFailedUpdate`, `VendorSynchronize`'s statistics output); `AnalyticsSettingsRead` (10 tests), two `AnalyticsCubeManager` tests, the seam's `partial` and `real` modes, the probe's settings fixture, two browser tests and every roster.
- **Verification:** `AnalyticsSettingsRead` and `AnalyticsCubeManager` green on `ocupilot-b-ci` (their first runs were red on a fixture check and green after it was fixed, and each ran green again in either order, leaving the three settings globals as found); `AnalyticsDescriptor`, `Descriptor`, `ReadTool`, `PortGate`, `Navigation`, `StageTwoTools`, `SurfaceCoverage`, `ToolNavigateContract`, `ToolRoundTrip`, `ClassicPageGate`, `ToolEmit`, `MappingDescriptor`, `Prohibited`, `ToolDispatch`, `AnalyticsQualityMeasureRead`, `AnalyticsCubeActions` and `AnalyticsCubeGate` green; `test:tools` 2331/2331, `test:components` 3612/3612; `npm run build` clean (initial bundle 2.15 MB); the two Story 24.13 browser tests, `analytics-links` and the existing analytics specs I ran (AC1 to AC5, the Quality measures one) green; `check-objectscript` 0 problems. The full sweep and the full browser suite are the lead's.
- **Contended (add-only):** `scripts/ci-throwaway.sh` (one arming-roster line), `strings.ts` (new keys, one citation line moved by the new row), `screens.generated.ts`, `Test/ReadTool.cls`, `Test/SurfaceCoverage.cls`, `Test/ToolRoundTrip.cls`, `Kernel/EntityType.cls` (four names).
