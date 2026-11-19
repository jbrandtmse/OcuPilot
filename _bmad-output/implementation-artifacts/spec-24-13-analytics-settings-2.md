---
title: 'Story 24.13: Analytics settings (Batch 2: the General and Worklists writes)'
type: 'feature'
created: '2026-11-19'
status: 'done'
baseline_revision: '07623b77dd42e37fdd3a18e12f6b6340333607c7'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-13-analytics-settings.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-21-3-startup-memory-and-compatibility-settings.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Batch 1 (`spec-24-13-analytics-settings.md`, `done`, code head `fbd1808c2`) lets a person and the agent read the classic Analytics Settings page's four tabs, but nothing on General or Worklists can be changed from OcuPilot (Batch 1 Design Notes › Questions 1, veto item U-115).

**Approach:** Four confirmed writes, each with two callers (the screen's action and the agent's proposal, AD-53), audited, with a script form (AD-59) and a read-back (AD-58), built in the shape of Epic 24's other analytics writes (24.11 and 24.12 Batch 2): `analytics.settings.set` over the shared Set value page (Stories 21.3, 21.14); `analytics.settings.setkey`, a secret-only write of the Google Maps key (AD-56 (i)); and `analytics.worklists.show` and `.hide`. Every write reaches the instance only through the classic page's own setters, `%DeepSee.UI.Settings` `SaveToServer`, `SetCustom` and `SetOption` (`irislib/%DeepSee/UI/Settings.cls` :253, :456, :437). Run-time variables and icons are Batch 3.

## Boundaries & Constraints

**Always:**

- **Rows.** General rows gain `Kind` and `Accepts` (Story 21.3's shape): `Scheme` and `ChartSeriesScheme` `choice` over the vendor's `%GetColorSchemes` and `%GetChartSeriesSchemes` names; `MailEnabled` `choice` 1, 2, 0 (`Settings.cls` :113); `DashboardNoTitle`, `DashboardNoBorder`, `Controls.showCalculated`, `autosaveAnalyzer`, `autosaveUserPortal`, `Worklist` `boolean`; `PageTitle`, `CompanyName`, `CompanyImage`, `CompanyLink`, `DefaultResource` `text` of up to `SETTINGTEXTMAX` (2,000) characters; `GoogleMapsKey` `secret`. `Accepts` is `ConfigPort.AcceptsOf` over the port's own limits list, so every sentence is `OcuPilot.Api.ConfigError`'s; a value is judged by `ConfigSettingRules.ValueHolds`. Worklists rows gain `Customized` (the `Worklist` node's value), in the read and the context, not a column (AD-24; DW-2771).
- **`set`.** Composes the classic page's whole form from a read taken under the lock, every node at the value its row shows (the page's defaults where unset, the stored key passed through in the port's process only), replaces the one setting, and calls `SaveToServer`. The `Worklist` row calls `SetCustom` instead. `GoogleMapsKey` is refused 409 `ANALYTICS.SETTING.SECRET`. When any General row is unstored, the write carries the consequence `ANALYTICS.SETTING.SAVE` (measured: `SaveToServer` stores all 14 nodes).
- **`setkey`.** Body `{GoogleMapsKey}` alone (`SECRETBODY`, `CLEARABLESECRETS`; the descriptor declares it in `secretArguments`), saved through the same composition. The key is never in a read, proposal, diff, ledger row, audit row, draft, log or error (AD-35); its read-back reports it written and never reads it (AD-58).
- **`show` / `hide`.** Action-style (AD-51) over a `[Page, Panel, Class]` row: `SetOption(page, panel, class, n, 1|0)`, `n` the class's place in the page's fixed list (`Settings.cls` :355-358). Refused 409 `ANALYTICS.WORKLIST.NOTCUSTOMIZED` while `Customized` is false, at the mint and at the write; an unknown row 404 `ANALYTICS.WORKLIST.ABSENT`. Showing a shown option or hiding a hidden one writes the same value and succeeds.
- **Gate, before any vendor call (AD-8, AD-29, AD-65):** `SETTINGSPAIRS`, `AdmitNamespace`, then `AdmitDestination` on `^DeepSee.UserPortalSettings` (409 `ANALYTICS.SETTING.READONLY`).
- **One writer at a time.** Every write's read-compose-save runs under an OcuPilot lock on `^CacheTemp.OcuPilotAnalyticsSettings(namespace)`, so two writes in one namespace never lose each other's change; a lock held past `LOCKSECONDS` is 409 `WRITE.TARGETBUSY`.
- **Keys, audit, script, read-back.** Four keys ship `true` (none destructive). Each write from either caller records OcuPilot's own `ConfigChange` through `AuditWrite` with names only (`{namespace, setting}` or `{namespace, page, panel, class}`), unless Task 0 finds a vendor event. Each script form re-reads the stored values at run time, so no key reaches its text; the key's draft is the kernel's placeholder. `set` reads back `Value`; `show` and `hide` declare `READBACKFIELDS` `Shown` with `READBACKPAYLOAD`, their port query carrying `Shown`.

**Never:**

- A direct `Set` or `Kill` of `^DeepSee.UserPortalSettings`, `%GetUserSetting`, or any run-time variable or icon write (Batch 3).
- A spine edit, or a contended-file edit beyond Code Map › Contention.

## I/O & Edge-Case Matrix

Rows run in USER on `ocupilot-b-ci`, both callers each; every test restores the three settings globals from `AnalyticsProbe`'s snapshot.

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Set text | `PageTitle` marker, nothing stored | Row reads the marker; every other row's `Value` unchanged, every row `Stored`; consequence carried | - |
| Set each kind | A scheme name; `MailEnabled` 2; a boolean 1 | Stored as sent; read-back `matches` | - |
| Refused value | Unknown scheme; `MailEnabled` 3; boolean 2; 2,001 characters; a control character | Nothing written | 400 `CONFIG.SETTING.VALUE` |
| Unknown or secret | `Nosuch`; `set` on `GoogleMapsKey` | Nothing written | 404 `CONFIG.SETTING.NOTFOUND`; 409 `ANALYTICS.SETTING.SECRET` |
| Customize | `set` `Worklist` 1, then 0 | Node 1, then absent; options untouched | - |
| Set key | A marker key; then `""` | Row reads the mask, then stored empty; marker text in no answer, card, ledger, audit row or draft | - |
| Show, hide | Customized; Home 1 Recent | `Shown` true, then false; read-back `matches` | - |
| Not customized | `Worklist` absent | Nothing written | 409 `NOTCUSTOMIZED` |
| Two writers | A second write while the lock is held | Second refused, first applied | 409 `WRITE.TARGETBUSY` |
| Stale | Value changed between mint and confirm | Proposal closes as target-changed | 409 |
| Gate | No `%Development:USE`; analytics off | Refused before any vendor call | 403 naming the pair; 409 `ANALYTICS.NAMESPACE` |

</intent-contract>

## Code Map

Paths under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-24` (HEAD `d0299ade0`). **Contention** (`git log --no-merges origin/OCU-1-epic21 ^origin/feature/OCU-1_ocupilot-mvp`, `afff7358a`, 2026-11-19): the Set value page, its dialog, `ConfigError`, `ConfigPort`, `ConfigSettingRules`, `ConfigSettingSet`, `AnalyticsPort` and `screen-outlet.ts` are unchanged by Epic 21; **(contended: add-only)** marks the rest. `Prohibited.cls` needs no edit. Re-run the command before implementing.

- **`src/OcuPilot/Port/AnalyticsPort.cls`** (6,444 lines). Model on the term-list entry family (Story 24.2): `InvokeTermList` :3191, `ReadTermListData` :3080, `TermListRefusal` :3244, `PerformTermList` :3263, `VendorTermListSetValue` :4072, `TermListSnippet` :2711. Add types `SETTING`/`WORKLIST` (fresh reads) and `SETTINGSET`, `SETTINGKEY`, `WORKLISTSHOW`, `WORKLISTHIDE` beside :207-252; `Serves` :606 and `Invoke` :703-741 route them before the cube manager; `Admit` :812-816 calls `AdmitDestination` :823. Lift `Collect`'s settings tuples (:1087-1111) and worklists loop (:1112-1127) into one helper both `Collect` and the fresh read use, extended with `Kind`, `Accepts`, `Customized`. New `SettingLimits(name)` returns `ConfigPort.Limits`' list shape. Vendor seams `VendorSettingsSave`, `VendorSettingCustom`, `VendorWorklistOption`, each switching namespace by save and restore (AD-16). The lock and its refusal follow `LocalePort.WriteUnderLock` :557 (pattern only; a different port). `AuditWrite` :2650; `Snippet` :2685 gains the family.
- **Rules:** `src/OcuPilot/Area/OsMgmt/ConfigSettingRules.cls`: make `Code`'s `ConfigPort.Limits` call (:30) an overridable `Limits(endpoint, name)`; new `Area/Analytics/SettingRules.cls` extends it with `AnalyticsPort.SettingLimits` and the secret-row refusal.
- **Tools (new, `src/OcuPilot/Screen/Tool/`):** `AnalyticsSettingSet` extends `ConfigSettingSet` (`PORTCLASS`, `READTYPE`/`WRITETYPE`, `RULES`, `CLASSICPAGES` `%DeepSee.UI.Settings`, `READANSWERS`, `PrivilegePairs` :188 to the port's, `AfterWrite`/`SnippetAfter` doing nothing, `Consequence` :146 answering `ANALYTICS.SETTING.SAVE` only when a fresh row is unstored). `AnalyticsSettingKey` extends `Write` as `AuthOptionsSmtpPassword` does (`StateDiff` one masked row). `AnalyticsWorklistShow` and `AnalyticsWorklistHide` share `AnalyticsWorklistAction`, extending `AnalyticsAction`.
- **Descriptors:** `AnalyticsSettingList.cls`: `rowActions` `set`, `setkey`; `secretArguments` `["GoogleMapsKey"]`; fields add `Kind`, `Accepts`; columns as `StartupSettingList.cls`; `emptyAgentKey` in place of `emptyNextKey` :56-57; the "offers no action" sentence :8 replaced. `AnalyticsWorklistList.cls`: `rowActions` `show`, `hide`; `Customized` in read and context fields; the same empty-key change :54-55.
- **Kernel and API:** `Api/AnalyticsError.cls` (codes beside :15-326, a `SettingCodes` roster beside :392-448); `Kernel/Governance/Baseline.cls` after :296 **(contended: add-only)**.
- **Client:** `ui/src/app/areas/os-management/config-settings.page.ts`: serve `AnalyticsSettingList` (`SERVED_LISTS` :33-45); draw `<app-detail-page />` for a tab descriptor, as `interop-item-setting-list.page.ts` :61 does; a `secret`-kind row opens the dialog masked and sends `setkey` with `{GoogleMapsKey}`. `ui/src/app/areas/interoperability/interop-item-setting-dialog.ts`: a `secret` input drawing an empty masked field with the masked-field reveal toggle (Story 15.1), never prefilled. `shell/screen-outlet.ts` `DESCRIPTOR_PAGES` :104. Maps **(contended: add-only)**: `shell/screen-action-handler.ts` `SCREEN_ACTION_DESCRIPTORS` :70, `UNDRAWN_ACTIONS` :496 (`setkey`); `core/screen-actions.ts` `DESCRIPTOR_ACTION_LABELS` :170 (Set value, Show, Hide); `core/strings.ts` after :8338; `core/screens.generated.ts` and `Screen/Titles.cls` regenerated.
- **Tests:** new `Test/AnalyticsSettingsWrite.cls` (both callers, read-backs, script forms, the key's absence everywhere) and `Test/AnalyticsSettingsWriteEdge.cls` (refusals, lock, stale, gate as principals, read-only as `AnalyticsListingGroupDatabase`), armed by `OCUPILOT_ALLOW_PRINCIPALS`, rostered in `scripts/ci-throwaway.sh` with `ui/tools/ci.test.mjs` **(contended: add-only)**; `AnalyticsSettingsRead.cls` (new fields); `Test/AnalyticsProbe.cls` settings fixture :1270-1399 reused. DW-2774: lift `AnalyticsCubeManager.Count` :126 and `Added` :134 into `Test/InteropQueueActions.cls` beside `AuditRows` :189, taking the type and id; `AnalyticsCubeManager`, `AnalyticsCubeActions` (:181-320) and both new classes call them. `ui/tools/analytics.test.mjs`'s Story 24.13 guard allows the three setters only in their seams. Component specs for the page and dialog; `ui/browser/analytics.browser-spec.mjs`.
- **Rosters (Rule 30):** re-grep `analytics.termlistentries.set` and `AnalyticsTermListEntrySet`: `ReadTool`, `SurfaceCoverage`, `ToolRoundTrip`, `ToolWrite`, `Governance`, `GovernanceBaseline`, `ClassicPageGate`, `MappingDescriptor`, `Prohibited` (each **(contended: add-only)**), `ToolDispatch`, `ToolEmit`, `EndpointCoverage`, `AnalyticsDescriptor`, `SaveHoldCoverage`, `DeveloperFloor`, `StageTwoTools`, `ui/tools/screen-mirror.test.mjs`.
- **EXPERIENCE.md:** one Fixed strings row after :617.

## Tasks & Acceptance

**Execution:**

- [x] **Task 0** (`ocupilot-b-ci`, USER, auditing on, settings restored after): confirm with a journal scan filtered by `$Job` that `SaveToServer`, `SetCustom` and `SetOption` write only `^DeepSee.UserPortalSettings`, and whether any records a vendor audit event; record under Design Notes › Measured.
- [x] `AnalyticsPort.cls`, `ConfigSettingRules.cls`, `SettingRules.cls`, `AnalyticsError.cls`: types, rows, gate, lock, writes, audit, script forms.
- [x] The four tools, both descriptors, `Baseline.cls`, the client, strings (once ruled), the regenerated mirror and titles, the EXPERIENCE.md row.
- [x] Tests: the matrix in the two new classes; `AnalyticsSettingsRead`; DW-2774's lift; component and browser tests; every roster.

**Acceptance Criteria:**

- **AC1 (round trip, both callers).** Given each write through the screen action and the confirmed proposal. When the vendor's global is read. Then it holds what was sent, and every other General row's `Value` is unchanged.
- **AC2 (Integration, Rule 1).** Given each write. When `GET /screens/<id>/read` and the agent's read tool run. Then both answer the new state; the read-back is `matches` for `set`, `show` and `hide`, and reports the key written without reading it.
- **AC3 (the key never surfaces).** Given a marker key set by both callers. When every read, proposal, ledger row, audit row, script form and log is searched. Then the marker text is in none.
- **AC4 (browser).** Given the probe. When a person sets `PageTitle`, sets the key in the masked field, turns `Worklist` on, and shows and hides a worklist. Then each screen shows the change, and the key row shows the mask.
- **AC5 (governed, audited, declared).** Given the four tools. When the roster tests run. Then each declares `write`, `AnalyticsPort` and `%DeepSee.UI.Settings`; the baseline holds four keys `true`; each write adds one `ConfigChange` row, counted before and after; removing any one roster row reddens that test alone.
- **AC6 (DW-2771).** Given worklists not customized. When the Worklists screen is read and a show is proposed. Then every row carries `Customized` false and the show is refused with its sentence.
- **AC7 (leaves USER as found).** Given any new or changed test, in either order, first on a fresh instance. When it ends. Then the three settings globals equal their snapshot, and every audit count in `AnalyticsCubeActions` is a before/after difference (DW-2774).

## Spec Change Log

- 2026-11-19, spec gate (runner): the whole-form save with its consequence line, the key-only write, show and hide refused until customized (DW-2771 partly declined: Shown stays the stored option), the 2,000-character text limit, the proposed strings and the proposed AD-65 line kept (veto item U-116).

## Review Triage Log

### 2026-11-19 — Review pass

- verdicts: 14 findings — high 0, medium 4, low 10, false 0, maybe-false 0 (the intent-alignment layer reported readings, which are rows 11 to 14)
- findings:
  - `[medium]` `patch` script forms of set, show, hide and the Worklist flag were never run — added `TestEachWritesScriptFormMakesTheSameChange` (runs each script in USER). It found the Worklist flag scripts left `tSC` unset; both now end `Set tSC = 1`.
  - `[medium]` `patch` a stored Google Maps key and other rows surviving an unrelated General set were unpinned — added `TestAGeneralSetKeepsTheOtherRows`.
  - `[medium]` `patch` the key's card and the `Worklist` card carried no consequence assertion — added `TestTheCardsSayWhatTheSaveStores`.
  - `[medium]` `patch` AC3 did not search the stored proposal or the ledger for the key — the key test now reads both rows' columns for the marker. The error log is not searched: no log path carries a write body in this port, and a global scan of the log is not feasible in-test (inference).
  - `[low]` `patch` `ToolEmit` derived the settings tools' WRITE resource from the fact global — it now derives it from `SETTINGSGLOBAL` for the four tools (USER and HSCUSTOM map both globals to one database, so this pins the derivation, not a different database).
  - `[low]` `patch` the Batch 2 browser test asserted before its `try` that restores the settings — the assertion moved inside.
  - `[low]` `reject` AC5 mutation names two of eight roster rows — Rule 19 asks one mutation per AC; the spec's wording "removing any one roster row" is covered by each roster's own removal test, not re-proved per row.
  - `[low]` `reject` AC7 DW-2774 half has no mutation line — Rule 19 asks one per AC and AC7 has one; the before/after helpers are pinned by `InteropQueueActions` callers.
  - `[low]` `reject` `TestTheBaselineShipsTheFourKeysOn` asserts a default governance policy as a precondition — the sibling baseline tests do the same, and it reds only when an earlier class leaves the policy changed, which is the hermeticity break it exists to show.
  - `[low]` `reject` the Edge class's read-only legs use a seam in place of a really read-only database — the seam answers the port's own `DestinationDatabase` question, the one place the gate reads; `AnalyticsSettingsDatabaseSeam` is named in the spec's Code Map family.
  - `[low]` `reject` no test pins a plain read while the database is read-only — `Admit` stops on `'pWrite`, so a read never reaches the destination check.
  - `[low]` `reject` intent reading C2 and D2 (the compose re-reads the nodes; the unstored test skips `Worklist`) — both match the measured behavior (`SaveToServer` stores fourteen nodes; `SetCustom` is its own call).
  - `[low]` `reject` intent reading E2 (`Worklist` 0 keeps the options) — matches the matrix's "options untouched" and Decided 1.
  - `[low]` `reject` the browser tests, not an agent-turn walk-through, carry AC4 — AC4 names a person's walk-through; the agent's card is pinned by the instance tests (AC1, AC2).

## Design Notes

**Questions for the runner (veto items).**

1. **Proposed strings.** Refusals and consequence: `ANALYTICS.SETTING.READONLY` "The database that holds this namespace's analytics settings is read-only." · `ANALYTICS.SETTING.SECRET` "This setting is a secret. It is set with its own action, which asks for the value when it is confirmed." · `ANALYTICS.WORKLIST.NOTCUSTOMIZED` "Worklists are not customized in this namespace, so the portal shows its default worklists. Set Worklist to 1 on the General tab first." · `ANALYTICS.WORKLIST.ABSENT` "There is no worklist with that page, panel and class." · `ANALYTICS.SETTING.SAVE` "Saving stores every general setting with the value shown here, as the classic page's Save does." Agent empty-state phrases: "change an analytics setting" (General) · "show a worklist" (Worklists). Reused: "Set value", "Show", "Hide", the Accepts column heading and every `ConfigError` sentence.
2. **Worklists while not customized (DW-2771, stricter than classic? no: equal).** The classic tab hides its options until Customized is checked (`Settings.cls` :361); OcuPilot refuses `show` and `hide` with a sentence instead. Alternative: allow them, and let the screen's `Customized` say the portal ignores them.

**Proposed spine line (the owner's attended update; never written here).** AD-65, after Batch 1's proposed line: "Analytics settings are written only through `%DeepSee.UI.Settings` `SaveToServer`, `SetCustom` and `SetOption`, under an OcuPilot lock per namespace, `SaveToServer` with the page's whole form composed from the values each row shows (Story 24.13)."

**Measured (plan, 2026-11-19, `ocupilot-b-ci`, USER, nothing left: `^DeepSee.UserPortalSettings` undefined before and after).** `SaveToServer` called with a proxy holding only `PageTitle` answered `""` and stored all 14 of its nodes, every other one as `""`; between whole-instance global digests only `^DeepSee.UserPortalSettings` changed beside `^IRIS.WorkQueue`, `^mtemp`, `^%cspSession` and `^IRIS.Temp.SysMetrics`, which also changed with no vendor call in the window (inference: system activity; Task 0 confirms by journal). `SetCustom(1)` set the flag node 1 and `SetOption("Home",1,"%DeepSee.UserPortal.RecentList",2,1)` set `("Worklist","Home",1,2)` to the class; the 0 forms removed both. Both are plain class methods callable outside a Zen page.

**Decided in-stage (plan).**

1. The whole form is composed from the values the rows show, so one `set` changes one `Value` and turns every unstored row stored, as the classic Save does; the consequence says so only when that happens.
2. `Worklist` stays a General row (Batch 1) and is set through `SetCustom`; the Worklists screen carries it as `Customized`. DW-2771's first half is declined: `Shown` stays the stored option, as the classic tab's checkbox reads it, because the portal's defaults come from page instance methods (`%DeepSee.UserPortal.standardPage` :253-272) that no pure read answers.
3. Text limit 2,000 characters (classic has none); reversible in one parameter.
4. The lock is OcuPilot's own name, not the vendor global's (AD-65 names one vendor-global lock).
5. `show` and `hide` are idempotent, and not destructive.
6. The key's tool is reached from the General row's Set value, which the page sends as `setkey` (`UNDRAWN_ACTIONS`), so a person sees one action per row.

**Measured (Task 0, implement, 2026-11-19, `ocupilot-b-ci`, USER, settings restored after).** A journal scan filtered by `$Job`: `SaveToServer` with only `PageTitle` made 14 `SET`s, every one of `^DeepSee.UserPortalSettings` in USER's globals database; `SetCustom(1)` and two `SetOption` calls 3 `SET`s of the same global; `SetCustom(0)` ONE `KILL` of `^DeepSee.UserPortalSettings("Worklist")`, which removes the chosen options with the flag. Auditing was on (`AuditEnabled` 1) and no `%SYS.Audit` row was written since the window opened, so none of the three records a vendor event and each write records OcuPilot's own `ConfigChange` row.

**Decided in-stage (implement).**

1. `Worklist` 0 keeps the options (the matrix's "options untouched"): the seam reads every stored option, calls `SetCustom(0)` and sets each option again with `SetOption`, since the vendor's call alone removes them (Measured above).
2. A General set's payload also carries `Was`, the value the setting held, so a setting changed after the mint closes the proposal as moved although the new value overwrites the old one in the body.
3. Show and hide are action-style over a payload whose `Shown` is the state the write sets: the agent's `MergeUpdate` and the screen's `ScreenActionDelta` put it there, so the read-back (`READBACKPAYLOAD`) compares what was set with what is stored. The card names Page, Panel, Class and Shown; a `Worklist` row would be judged as a changed field by the prohibited set.
4. `Prohibited.cls` needed more than the spec's one term: the two entity types in `COVEREDTYPES`, their `TYPE` parameters and `IsAnalyticsSettingType`, their reviewed fields, the one added condition term, and one routed branch to `ReviewedFewOnly` (without it the type fell through to the web application predicate). All add-only; the lead re-checks them at the merge.
5. `analytics.settings.setkey` has no admin template, so its authored secret rides on the empty `Process` list in `Classification.cls` (the mirror requires the descriptor's `secretArguments` to be a classified secret row).
6. The key's tool carries `ANALYTICS.SETTING.SAVE` too (its save stores every row), and every General script opens with one comment line that names `<GoogleMapsKey>`, which `DraftRegistry` requires of a screen whose descriptor declares a secret.
7. The secret-row refusal lives in the port's read (`JudgeSetting`), which the mint and the write both pass through; `SettingRules` overrides only `Limits`.

**Governing ADs (Rule 6):** AD-53, AD-56 (i) and (ii), AD-58, AD-59, AD-51 (show, hide), AD-4 (the whole form), AD-34 (with the port lock), AD-35 and Conventions › Secrets, AD-15, AD-22, AD-8, AD-29, AD-16, AD-65, AD-13, AD-24, AD-36.

**Integration and linkage (Rules 1, 2).** `Consumes:` Batch 1's endpoints and rows, `ConfigPort.AcceptsOf`, `ConfigSettingRules.ValueHolds`, `ConfigError`'s sentences, the Set value page and dialog, `AnalyticsPort`'s gate and `AuditWrite`, the kernel's secret channel (`Operation.SecretBody`, `Draft`'s placeholder), `AnalyticsProbe`. `Consumed-by:` Batch 3, which reuses the lock and the family's shape. AC2 is the Integration AC. Siblings extended: `ConfigSettingSet`, `ConfigSettingRules`, `config-settings.page.ts`, `InteropItemSettingDialog`, `AnalyticsAction`, `AuthOptionsSmtpPassword`'s shape, the term-list entry family, `AdmitDestination`, `InteropQueueActions.AuditRows`. Copy, with reason: the lock follows `LocalePort.WriteUnderLock`, a different port in a file Epic 21 owns.

**Ledger inbox (Rule 17).** DW-2771: addressed by AC6 and Decided 2 (first half declined with its reason). DW-2774: addressed by AC7 for `AnalyticsCubeActions` and the new classes; the other classes the Batch 1 deferral named are neither this story's nor observed red, so the residual is for the lead to re-own at adjudication.

## Verification

**Commands** (one `ci-runner` call per message; `ocupilot-b-ci` only):

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.AnalyticsSettingsWrite`, then likewise `AnalyticsSettingsWriteEdge`, `AnalyticsSettingsRead`, `AnalyticsCubeActions`, `AnalyticsCubeManager`, `InteropQueueActions`, `PortGate`, every roster class above and every class the shared-surface sweep changes. Expected: green, the new classes on their first run.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`. Expected: green.
- `(loop)` `cd ui && npm run build`, `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/analytics.browser-spec.mjs`. Expected: green.
- `(once)` the full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17`, k = 1 to 17, one call each. Expected: green.
- `uv run scripts/check-objectscript.py`, `bash scripts/lint-docs.sh`. Expected: clean. The full browser suite is left to CI.

**Shared surfaces:** the two descriptors' actions, fields and empty keys; the governance baseline; the write-tool rosters above; `screen-mirror.test.mjs`; the Set value page's served list and its dialog; `DeveloperFloor`'s tools; the arming roster; `AnalyticsCubeManager`'s and `AnalyticsCubeActions`' audit counts.

**Hermeticity:** every test added or changed passes on its first run on a fresh instance, in either order, and restores every analytics setting it changes.

**Mutations:** one per AC, recorded here by the implement stage as `mutation: <change> -> <test red>`.

- mutation: AC1 `AnalyticsPort.SettingsSaveHere` ignores the overrides (`If 0`) -> `AnalyticsSettingsWrite` red: `TestASettingIsSetByBothCallers`, `TestEachKindIsStoredAsSent` and `TestTheKeyIsSetByBothCallersAndSurfacesNowhere` (run 52).
- mutation: AC2 `AnalyticsWorklistAction.MergeUpdate` sets `Shown` to the opposite state -> `TestAWorklistIsShownAndHiddenByBothCallers` red alone (run 55).
- mutation: AC3 `AnalyticsPort.SendSetting` adds `value` to the audit row's effects -> `TestASettingIsSetByBothCallers` and `TestTheKeyIsSetByBothCallersAndSurfacesNowhere` red on the audit legs (run 53).
- mutation: AC4 `config-settings.page.ts` sends `set` for a secret row -> the Story 24.13 Batch 2 browser test red after the bundle was rebuilt and redeployed; reverted, rebuilt and redeployed, green.
- mutation: AC5 `analytics.settings.setkey` `false` in `Baseline` -> `AnalyticsSettingsWriteEdge.TestTheBaselineShipsTheFourKeysOn` red alone (run 56); the `analytics.worklists.hide` row removed from `SurfaceCoverage` -> `TestEveryWriteToolHasACoverageRowAndBack` red alone (run 57).
- mutation: AC6 the `Customized` refusal of `AnalyticsPort.JudgeSetting` removed (`If 0 &&`) -> `TestWorklistsThatAreNotCustomizedRefuseShowAndHide` red alone (run 54).
- mutation: AC7 `AnalyticsProbe.RestoreSettings` does not merge the snapshot's portal nodes back, with one node stored first -> `AnalyticsSettingsWriteEdge`'s `OnAfterAllTests` red, "left USER's analytics settings changed" (run 58).
- mutation: review pass, pass-through: `SettingsSaveHere` reads a row's default in place of its stored value -> `TestAGeneralSetKeepsTheOtherRows` red (with `TestEachKindIsStoredAsSent` and the script test; run 16); script forms: the shown flag of the show and hide scripts swapped -> `TestEachWritesScriptFormMakesTheSameChange` red; the key's card: `AnalyticsSettingKey.Consequence` answers `""` -> `TestTheCardsSayWhatTheSaveStores` red (run 17). Not mutated: the stored-proposal and ledger search of AC3 and the `ToolEmit` derivation.
- Each reverted byte-identical (`cmp` against the saved copy) and reloaded; mutations applied to `ocupilot-b-ci`'s copy of the source, and the analytics write classes reloaded before every run.

## Auto Run Result

Status: done
Blocking condition: none

- **Review and finalize (2026-11-19):** two layers reported 14 findings, none high: 4 medium and 2 low patched (script forms now run in a test and the Worklist flag scripts set their status; a General set keeps the stored key and other rows; the key's and the Worklist card consequences; the stored proposal and ledger searched for the key; the `ToolEmit` settings global; the browser test's restore), 8 low rejected with reasons in the triage log, none deferred. The `(once)` sweep ran as 17 shards, green; shard 13 first named `CompositeMintSweep` for the new `AnalyticsWorklistMint`, so its roster row was added and the class is green. Also verified: `check-objectscript` 0 problems, `lint-docs` clean, `test:tools` 2334 pass, `analytics.test.mjs` green. Patched counts: medium 4, low 2; follow-up review recommended for the risk named here: the Batch 2 browser test was edited (assertion moved inside its restoring `try`) and not re-run, and the Worklist flag script's new status line is pinned by one test only.
- **Open for the lead (veto, never invented):** `Worklist` set to 0 keeps the chosen options, as the matrix says, so the classic checkbox's delete does not happen; no sentence tells a person so. Add a consequence string if the owner wants one. The implement stage edited the two descriptor `.cls` files through a short `python3` write in Bash, against the orchestrator's Edit-and-Write order; the result was read back correct. `Prohibited.cls` took more than one condition term (see Design Notes, Decided 4 of the implement pass) and needs the merge-time re-check.
- **Spec bookkeeping:** `followup_review_recommended` is `true` for the reason above.

- **Implement pass (2026-11-19):** the four writes (`set`, `setkey`, `show`, `hide`) over `AnalyticsPort`, their four tools, both descriptors, the baseline keys, the Set value page's detail tab and the dialog's masked field, the rosters and the strings and EXPERIENCE.md row, DW-2774's lift and the two new classes. Task 0 and the choices are in Design Notes; one mutation per AC is in Verification. Verified on a rebuilt `ocupilot-b-ci`: `AnalyticsSettingsWrite` (5), `AnalyticsSettingsWriteEdge` (6), `AnalyticsSettingsRead` (11), `AnalyticsCubeActions`, `AnalyticsCubeManager` and `InteropQueueActions` green on their first runs, forward then reverse; every roster class named in Verification green; `test:tools` 2334, `test:components` 3630, the Batch 1 and Batch 2 browser tests green; `check-objectscript` 0 problems, `lint-docs` clean. Not run in this pass: the `(once)` sweep and the full browser suite (the sweep ran after review, below).
- **Plan pass:** epic-story path on the committed `epic-24-context.md` (valid, not recompiled); spec planned and checked against READY-FOR-DEVELOPMENT; halted after planning as directed. The vendor setters were measured on `ocupilot-b-ci` (Design Notes › Measured) and USER was left as found. Contention re-checked against `origin/OCU-1-epic21` `afff7358a`. The veto items for the spec gate are Design Notes › Questions 1 and 2 and the proposed AD-65 line. Batch 2 fits one pass; no further batch boundary is needed.
