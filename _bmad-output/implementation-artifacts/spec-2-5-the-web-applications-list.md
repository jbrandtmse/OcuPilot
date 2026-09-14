---
title: 'Story 2.5: The web applications list'
type: 'feature'
created: '2026-09-14'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/DESIGN.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** No area shows live data yet. The read (2.3), the table (2.4) and the AdminPort (2.1) exist, but no production descriptor declares a read, so nothing crosses the wire. Separately, the command box and the locator's area segment leave the side bar on the previous area (DW-148).

**Approach:** Add one hand-written descriptor, `OcuPilot.Screen.Descriptor.WebAppList`, that declares the vendor `WebApp.App` LIST as its read and six columns as its table. `ListPage` and the generated mirror render it with no per-screen client code. Add the missing Fixed strings, flip the tripwires that pinned "no production read", and close DW-148 with `ShellState.showArea`.

## Boundaries & Constraints

**Always:**
- **The declaration.** Fields are the live LIST row keys, probed 2026-09-14. The row carries `Namespace` (not `NameSpace`, which is the GET/PUT schema's spelling), `Type` as a string, `Enabled` as a boolean, and `DispatchClass` and `Resource` as strings.
  ```json
  "route": "web-applications/list", "area": "web-applications", "labelKey": "webAppListLabel",
  "sideBarPosition": 1, "archetype": "list", "built": true, "refreshes": false, "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}],
  "entityType": "web-application", "secondaryEntityTypes": [], "scope": "instance", "parentScope": "",
  "id": {"kind": "single", "parts": []}, "primaryAction": {"id": "", "selfProtection": ""}, "rowActions": [],
  "context": {"fields": ["Name","Namespace","Type","Enabled","DispatchClass","Resource"], "secretFields": []},
  "emptyStateKey": "webAppListEmpty", "commandAliases": ["web apps"],
  "classicPage": "%CSP.UI.Portal.Applications.WebList",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {"source": {"port": "admin", "endpoint": "WebApp.App", "type": "LIST"},
    "fields": ["Name","Namespace","Type","Enabled","DispatchClass","Resource"],
    "filter": ["Name","Namespace","Type","DispatchClass","Resource"],
    "sort": {"fields": ["Name","Namespace","Type","DispatchClass","Resource"], "default": "Name", "direction": "asc"},
    "paging": "cap"},
  "table": {"columns": [
      {"field": "Name", "labelKey": "webAppColumnName", "kind": "name"},
      {"field": "Namespace", "labelKey": "headerNamespaceLabel", "kind": "identifier"},
      {"field": "Type", "labelKey": "webAppColumnType", "kind": "text"},
      {"field": "Enabled", "labelKey": "webAppColumnEnabled", "kind": "status"},
      {"field": "DispatchClass", "labelKey": "webAppColumnDispatchClass", "kind": "identifier"},
      {"field": "Resource", "labelKey": "webAppColumnResource", "kind": "identifier"}],
    "emptyNextKey": "webAppListEmptyNext", "emptyAgentKey": ""},
  "toolIdentifier": "webapp.list"
  ```
  The Namespace column reuses `headerNamespaceLabel`, which keeps the one-namespace-key tripwire at `strings.test.mjs:345-372` true.
- `Type` renders the vendor's string verbatim (`CSP`, `System,CSP`). An empty `Resource` or `DispatchClass` reads "(none)" through 2.4's cell rule.
- Every string comes from EXPERIENCE.md's Fixed strings table. Non-ASCII characters are written as `\uXXXX`.
- A denial test uses a real principal holding `%Admin_Operate:USE` and not `%Admin_Secure`, created and deleted by the test, only on the throwaway (`scripts/ci-throwaway.sh`, container `ocupilot-ci`, `OCUPILOT_DEMO=1`).

**Never:**
- No per-screen route, handler, tool class, page, store, or `ui/src/app/areas/web-applications/` file.
- No primary action or row actions: Create is Story 8.1, and enable, disable and delete are Story 7.1.
- No auto-refresh, and no link out to the classic portal.
- Do not flip `navigates` on the area: true would remove its side bar and tile (`side-bar.ts:173`, `home.page.ts:197`).
- No namespace filter on the rows: the list is "every web application on this instance".
- No `docker compose up`/`down`, and no security-object mutation on the live `ocupilot` instance. Run one `iris_execute_tests` call per message.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Demo row | Fixture `/csp/myapp`: `Enabled` false, no Resource, no DispatchClass | Enabled shows the `outline` disc and "No"; Resource and Dispatch class read "(none)" | No error |
| System app | `/csp/sys` with `Type` `System,CSP` | The Type cell reads `System,CSP` as body text | No error |
| Cap | `maxRows=2` over the 45 live apps | Two rows, `truncated: true` | No error |
| Filter | "Filter rows" set to `myapp` | Only rows whose Name, Namespace, Type, Dispatch class or Resource contains `myapp` | No error |
| Denied read | Caller lacks `%Admin_Secure:USE` | 403 `AUTH.NOPRIVILEGE` naming `%Admin_Secure:USE`; AdminPort is not called | Refused before the port |
| Field drift | A declared read field is absent from the live row (e.g. `NameSpace`) | The field-presence test fails naming the field | Suite red, never a silent `null` column |

</intent-contract>

## Code Map

- `src/OcuPilot/Screen/Descriptor/Home.cls`: shape and doc-comment precedent. `Test/Read/WebApps.cls` is the fixture over the same endpoint, and it still reads the wrong key `NameSpace`.
- `src/OcuPilot/Screen/Registry.cls`
  - `Validate` `:128`, `ReadProblem` `:295`, `TableProblem` `:429`.
  - `DESCRIPTORPACKAGE` `:38`: the server enumerates by package. `ui/tools/screen-mirror.mjs:45,244-252` reads `Screen/Descriptor/` flat, so the class goes directly in that folder.
- `src/OcuPilot/Screen/Gate.cls`
  - `Evaluate` does not add the area's pairs (`:43-52`), so the descriptor declares `%Admin_Secure:USE` itself.
  - `ClassicResource` does not case-fold (`:135-139`).
  - Probe: `WebApp.App` `ResourcesOR()` answers `%Admin_Secure`, and `WebList.cls:22` has `RESOURCE = "%Admin_Secure"`.
- `src/OcuPilot/Screen/Read.cls:116-130`: `Project` writes `null` for a missing key, so a misspelled field is not caught today. `Test/ScreenRead.cls:157` is the only test over the real LIST.
- Tripwires:
  - `Test/ReadTool.cls:78-80` asserts that the production tool count is 0.
  - `ui/tools/navigation.test.mjs:112-116` expects built routes `['']`.
  - `Test/Smoke.cls:125-134` requires the report to contain "Epic 2".
  - `LIVE_PAYLOAD` in `ui/tools/navigation-wire.test.mjs` and `ui/src/app/shell/rail-wire.spec.ts` claims to be an exact capture.
  - Stale comments: `Test/ScreenReadWire.cls:3`, `app.wire.spec.ts:29`.
- Tools
  - `Screen/Tool/Read.cls:30-33` names a tool `<toolIdentifier>.read`.
  - `Tool/Registry.cls:108-121` lists one tool per read-declaring descriptor.
  - The read route's `:screen` segment is the tool identifier.
- Gating UI already exists, so there is nothing to build:
  - rail `rail.ts:125-133`, side bar `side-bar.ts:150-160`, command box `command-box.ts:392-403`
  - the denied deep link `screen-outlet.ts:116-118` with `screen-denied.ts:27-41`
  - server verdicts `Api/Navigation.cls:63-69`
- DW-148
  - `command-box.ts:346-352` `choose()` and `locator-bar.ts:263-266` `open()` only navigate.
  - `shell-state.ts:118-122` `showArea` opens the bar on an area. `home.page.ts:298-300` is the precedent.
  - `shell-state.test.mjs:64-78` pins the `setActiveArea` guard, so do not change the guard.
  - Neither spec provides `ShellState` (`main.ts:168`).
- Real principal and the throwaway
  - `Test/Wire.cls`: `ADMINUSER` with `%Admin_Operate` (`EnsurePrincipal` `:181-185`, teardown `:145-148`), and `TestTheNavigationMapGatesEveryAreaForARealPrincipal` `:355`.
  - `ui/browser/unreadable.browser-spec.mjs:60-140` creates a probe user through `docker exec` and refuses the live container.
- `src/OcuPilot/Install/Smoke.cls`: `CheckApiReads` `:389-419` is the HTTP read pattern; the `arealists` pending line is at `:490`.
- The id route: `app.routes.ts:36-52` adds `route/:id` when `hasIdRoute`. `data-table.ts:404-411` builds the link. `screen-outlet.ts:156-158` decodes once into `data-id`. `/csp/myapp` is already in both encoder corpora (`entity-id.test.mjs:41`, `Test/EntityId.cls:37`).
- Fixed strings: the table is at `EXPERIENCE.md:252-317`, and the last table row before insertion is `:314`. `strings.ts:289-310` holds the table keys with `EXPERIENCE.md:<line>` comments, which `strings.test.mjs` checks against the lines.

## Tasks & Acceptance

**Execution:**
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`: after `:314`, add this row:
  - String: `| "Web applications" · "Name" · "Type" · "Enabled" · "Dispatch class" · "Resource" · "No web applications in <NAMESPACE>." · "Open another screen from the command box." |`
  - Where: Web applications list side-bar entry and screen title (`:167`); its column headers, with Namespace reusing the namespace switch's name (`:128`, `epics.md` Story 2.5); its empty-state title (`:238`) and read-only second line (`:362`).
  - This makes `epic-2-context.md` stale for the lead's pre-warm.
- `ui/src/app/core/strings.ts`, `ui/tools/strings.test.mjs`
  - Add `webAppListLabel`, `webAppColumnName`, `webAppColumnType`, `webAppColumnEnabled`, `webAppColumnDispatchClass`, `webAppColumnResource`, `webAppListEmpty` and `webAppListEmptyNext`.
  - Update the `EXPERIENCE.md:<line>` comments that shift. Widen the sanity window only if the count leaves it.
- `src/OcuPilot/Screen/Descriptor/WebAppList.cls` (new): the declaration in Always, with a doc comment covering the scope, the id, the classic page and the reused label. Then run `node ui/tools/screen-mirror.mjs` to regenerate `ui/src/app/core/screens.generated.ts` -- AD-5, AD-36, AD-44.
- `src/OcuPilot/Test/Read/WebApps.cls`: rename every `NameSpace` to `Namespace`, so the one fixture over the real endpoint agrees with the vendor row.
- `src/OcuPilot/Test/ReadTool.cls`, `src/OcuPilot/Test/Descriptor.cls`
  - The zero-tools assertion now pins exactly one production tool: `webapp.list.read`, of kind `read`, from `OcuPilot.Screen.Descriptor.WebAppList`.
  - Add: the descriptor validates, and its `ClassicPage()` names a compiled class whose name matches case-sensitively.
- `src/OcuPilot/Test/ScreenRead.cls`: add a test over every production descriptor whose read source is an admin `LIST`. Every declared read field is a key of the live first row. The test fails when a read answers no row (the Field drift row).
- `src/OcuPilot/Test/ScreenReadWire.cls`: add the success-over-the-wire test (AC2) and correct the header comment.
- `src/OcuPilot/Test/Wire.cls`: for `ADMINUSER`, the navigation map's `web-applications/list` screen entry is denied with `%Admin_Secure:USE`, and the read route answers 403 (AC4).
- `ui/tools/navigation.test.mjs`, `ui/tools/navigation-wire.test.mjs`, `ui/src/app/shell/rail-wire.spec.ts`
  - Built routes become `['', 'web-applications/list']`.
  - Both `LIVE_PAYLOAD`s gain the denied screen entry exactly as `Wire.cls` observes it.
- `ui/src/app/shell/command-box.ts`, `locator-bar.ts` and their specs (DW-148)
  - Before navigating to a screen, call `ShellState.showArea(area)`. The command box skips areas that navigate (Home).
  - Both specs provide a real `ShellState` and assert that it opened on the target area.
- `src/OcuPilot/Install/Smoke.cls`, `src/OcuPilot/Test/Smoke.cls`
  - Add a `webapplications` check: `GET <api>/screens/webapp.list/read?maxRows=1` answers 200 with a one-row `rows` array.
  - The `arealists` pending line names the five remaining areas and still says Epic 2 -- AD-45.
- `ui/browser/web-applications.browser-spec.mjs` (new): AC1, AC3, AC5 and AC6 on the throwaway.
  - It asserts that `config.container` is not the live container.
  - It creates the denied principal through `docker exec` (a role with install-namespace code-database read plus `%Admin_Operate:USE`, as `Wire.cls` builds it) and deletes it in teardown.

**Acceptance Criteria:**
- **AC1 (integration: read, table and AdminPort over the wire).** Given the throwaway with the demo fixture, signed in as `_SYSTEM`, when the browser opens `/ocupilot/web-applications/list?ns=HSCUSTOM`, then:
  - exactly one `GET /api/ocupilot/screens/webapp.list/read` is issued
  - the column headers read Name, Namespace, Type, Enabled, Dispatch class, Resource
  - the `/csp/myapp` row shows Enabled "No" after a 7px disc, and Resource "(none)"
  - its Name, Namespace, Dispatch class and Resource cells use the code font family
  - the `/csp/sys` row's Type cell reads `System,CSP` in body type
  - typing `myapp` in "Filter rows" leaves that row in view
- **AC2 (the route over HTTP).** Given the installed instance, when `OcuPilot.Test.ScreenReadWire` calls `GET /api/ocupilot/screens/webapp.list/read?maxRows=1000` as the test principal, then:
  - it answers 200 as one JSON envelope
  - `fields` equals the six declared fields, and every row carries exactly those keys
  - `Name` and `Namespace` are non-empty strings and `Enabled` is a boolean on every row
  - `truncated` is false, and `maxRows=2` answers two rows with `truncated` true
- **AC3 (gated, browser).** Given the denied principal signed in on the throwaway:
  - When it views the rail, types "web apps" in the command box, and shows that area's side bar (for example with Ctrl+B after the deep link below), then the rail item, the command-box row and the side-bar entry "Web applications" are each `aria-disabled="true"` with "Requires %Admin_Secure".
  - When it opens `/ocupilot/web-applications/list?ns=HSCUSTOM`, then the screen renders the title "Web applications" and "You need %Admin_Secure to open Web applications.", and no screen-read request is issued.
- **AC4 (gated, server).** Given `Wire.cls`'s `%Admin_Operate` principal, when it reads `/api/ocupilot/navigation` and then the screen read, then the `web-applications/list` entry has `allowed` false with `failedPair` `%Admin_Secure:USE`, and the read answers 403 `AUTH.NOPRIVILEGE`.
- **AC5 (the id in a route).** Given the AC1 list, when the `/csp/myapp` name link is followed, then the location path ends in `/web-applications/list/%252Fcsp%252Fmyapp` and the outlet's `data-id` reads `/csp/myapp`.
- **AC6 (DW-148).** Given `_SYSTEM` on the throwaway:
  - Given the side bar opened on Logs from the rail, when "web apps" is chosen in the command box, then the side bar is the Web applications area's and lists "Web applications" as current.
  - Given the side bar closed (Ctrl+B) on the list, when the locator's area segment is activated, then the side bar opens on the Web applications area.
- **AC7 (descriptor and tool).** Given the production registry, when `ReadTool` and `Descriptor` run, then `webapp.list.read` is the one production read tool, the descriptor validates, and its classic page resolves to a compiled class in the class's own case.
- **AC8 (smoke).** Given `scripts/smoke.sh` against the throwaway, when it runs, then `webapplications` reports pass and `arealists` stays pending naming Epic 2.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs:**
- AD-2, AD-26, AD-27: the synchronous LIST goes through the port; the classic page is declared.
- AD-5: one hand-written descriptor, mirrored.
- AD-8, AD-29: the pair set, where `%Admin_Secure:USE` equals the vendor's `ResourcesOR`.
- AD-13: a single id in one segment, instance scope.
- AD-14: `web-application` from the kernel enum.
- AD-19: no store outside `ScreenStores`.
- AD-24: context fields, none secret.
- AD-25: the demo row is asserted only where the opt-in ran.
- AD-36: one read for the route and the tool.
- AD-43: not in the six auto-refreshing screens (`EXPERIENCE.md:576`).
- AD-44: list archetype, no link-out, classic union.
- AD-45: the smoke's first live list.
- Conventions: Screen archetype (a list declares `table`), Tool naming (`webapp.list.read`), Tests.

**Readings chosen where the documents leave room:**
- **Scope `instance`, unfiltered.** Epics says "every web application on this instance". `Security.Applications` is keyed by name alone (`IdKey NameLowerCase`). UJ-3's "6 rows" is a mock count.
- **Id `single`.** Web applications are keyed by name alone.
  - `epics.md:1313` (Story 1.9) says Story 2.5 needs "the composite id". That claim is wrong (inference: nothing in the vendor identity is composite).
  - Recommended apply-and-report correction at its origin: drop the web-applications example there, or name a real composite-id screen.
- **Namespace renders in code**, per `DESIGN.md:870`. Epics' "name, dispatch class and resource" is a floor, not an exhaustive list.
- **The empty state's second line is copy authored here.** `:362` publishes only its shape. The state cannot be reached on a real instance, because the vendor LIST always includes the nine `System,CSP` applications. The lead may reword the row.
- **Angular naming Conventions row.** The row's per-screen `page`/`store`/`descriptor` trio is not created, because `ListPage` and the mirror already serve that role (2.3, 2.4). Recommended Rule 20 amendment: a screen gets its own client files only when its archetype page does not serve it.
- **1,000-row timing.** The end-to-end 1,000-row instance read stays with Story 2.10 (epic context). The live list holds 45 rows.

**Integration ACs:** AC1 (browser, real instance), AC2 and AC4 (HTTP), AC8 (smoke).

**Consumes:**
- 2.1 `AdminPort.Invoke`
- 2.3 `Screen.Read.Execute`, the screen-read route and the tool registry
- 2.4 the `table` grammar, `ListPage` and `DataTable`
- 1.9 registry, gate and navigation map
- 1.12 `ShellState.showArea`
- 1.4 demo fixture
- 1.17 smoke

**Consumed-by:**
- 5.8 enables `/csp/myapp` and highlights its row.
- 6.1 REST API explorer joins this list.
- 7.1 row actions `webapp.list.enable`/`disable`/`delete`.
- 8.1 Create as primary action.
- 9.2 editor at the id route.
- 2.6–2.9 copy the descriptor shape and the field-presence test.

**Ledger inbox:** DW-148 is addressed by the command-box/locator task and AC6.

## Verification

**Commands:**
- `cd ui && npm run build` -- expected: prebuild green, mirror up to date, classic-links check green.
- `cd ui && npm test` -- expected: all node and component suites green.
- `uv run scripts/check-objectscript.py` and `uv run scripts/test_check_objectscript.py` -- expected: zero problems.
- `bash scripts/lint-docs.sh` -- expected: the EXPERIENCE.md row lints clean.
- Live `ocupilot-iris`, reads only, one `iris_execute_tests` call per message: `OcuPilot.Test.ReadTool`, `OcuPilot.Test.Descriptor`, `OcuPilot.Test.ScreenRead`, `OcuPilot.Test.ScreenReadWire`, `OcuPilot.Test.Smoke` -- expected: zero failures, confirmed in `%UnitTest_Result`.
- Throwaway: `sh scripts/ci-throwaway.sh up`; `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.Wire`; `sh scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS`; `cd ui && npm run test:browser`; `sh scripts/ci-throwaway.sh down` -- expected: Wire green, smoke passes with `webapplications` pass, every browser spec green. The principal mutations run here only.

**Planned mutations (Rule 19; apply, observe red, revert, confirm the tree is byte-identical):**
- AC1: the Enabled column kind is `text` -> the disc-and-"No" assertion goes red.
- AC2: the declaration reads `NameSpace` -> the non-empty `Namespace` assertion goes red, as does the field-presence test.
- AC3: `privileges` is `[]` -> the deep link renders the list and the denied-message assertion goes red.
- AC4: `privileges` is `[]` -> the `failedPair` assertion in `Wire.cls` goes red.
- AC5: id kind is `none` -> no name link, and the path assertion goes red.
- AC6: `choose()` drops `showArea` -> the command-box side-bar assertion goes red (browser and `command-box.spec.ts`).
- AC7: `classicPage` is lower-cased -> the `Descriptor` case test goes red.
- AC8: the smoke check requests `webapp.nosuch` -> `webapplications` reports fail.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

**Planned.** Halted after planning, as the dispatch directed.

**Evidence** (live `ocupilot-iris`, reads only):
- `AdminPort.Invoke("WebApp.App","LIST")` returned 45 rows keyed `Name, Namespace, NamespaceDefault, Enabled, Type, Resource, AuthenticationMethods, IsSystemApp, DispatchClass`.
- `ResourcesOR()` answered `%Admin_Secure`.
- The admin spec lists `GET /v2/web-apps`.
- `/csp/myapp` is absent on the live container, which predates Story 1.4. The demo row is therefore asserted on the throwaway, where `OCUPILOT_DEMO=1`.

**For the lead:**
- The step-01 tree check found one uncommitted lead line in `cycle-log-epic-2.md` (the `protocol_violation` entry). This plan-only dispatch neither read nor wrote it. Commit it before the implement dispatch.
- Two recommended apply-and-report amendments are listed under Design Notes: `epics.md:1313`'s composite-id claim, and the Angular naming Conventions row.
- The EXPERIENCE.md row this story adds makes `epic-2-context.md` stale after implementation.
