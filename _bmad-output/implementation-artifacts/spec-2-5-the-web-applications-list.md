---
title: 'Story 2.5: The web applications list'
type: 'feature'
created: '2026-09-14'
status: 'done'
baseline_revision: 'e25cab8f772fe6304303723e71b5b54858476acb'
baseline_commit: 'e25cab8f772fe6304303723e71b5b54858476acb'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/DESIGN.md'
warnings: ['oversized']
deferred:
  - summary: >-
      No list offers the manual Refresh action EXPERIENCE.md:562 requires on every list, and the web applications list is the first live one.
    evidence: |-
      ui/src/app/shell/command-bar.ts renders only the auto-refresh chip, gated on hasRefreshChip; no Fixed strings row names a Refresh action and no epics.md story carries it. Pre-existing in the 2.4 list page and command bar, surfaced by the first live list.
    location: >-
      ui/src/app/shell/command-bar.ts:128
    severity: medium
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

### Review Findings

Code review 2026-09-14 (`bmad-code-review`, full-opus tier; blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor). 43 raw findings: 10 entries kept (9 patch, 1 defer), 21 rejected.

- [x] [Review][Patch] (med) The command box reopened a side bar the user collapsed with Ctrl/Cmd+B and saved it open, against EXPERIENCE.md's side-bar row; `showArea` now runs only when the bar is open [ui/src/app/shell/command-box.ts:360]
- [x] [Review][Patch] (low) AC3's pair wording: the EXPERIENCE.md and DESIGN.md illustrations named a bare resource where AD-8 and every shipped string name the pair; corrected to `%Admin_Secure:USE` (and `%Admin_Manage:USE`) [_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md:216]
- [x] [Review][Patch] (low) AC1 and AC3 wording and the `answered()` gate recorded under Spec Change Log [_bmad-output/implementation-artifacts/spec-2-5-the-web-applications-list.md]
- [x] [Review][Patch] (low) The classic-page case assertion compared `CompiledClass.Name` to the id it was opened with, so it could not fail on its own; removed, the case now rests on the keyed open [src/OcuPilot/Test/Descriptor.cls:76]
- [x] [Review][Patch] (low) AC1's filter legs never went through Namespace; a `HSCUSTOM` leg added, mutation observed [ui/browser/web-applications.browser-spec.mjs:210]
- [x] [Review][Patch] (low) AC8's `arealists` clause had no recorded mutation; applied and recorded under Verification [src/OcuPilot/Install/Smoke.cls:536]
- [x] [Review][Patch] (low) "One screen" comments still present tense in `navigation.ts:319`, `Test/Screen/Refreshing.cls:1` and `app.wire.spec.ts:224` [ui/src/app/core/navigation.ts:319]
- [x] [Review][Patch] (low) `LIVE_PAYLOAD` comments called a hand-added screen entry a server capture [ui/tools/navigation-wire.test.mjs:13]
- [x] [Review][Patch] (low) README smoke paragraph left with 111- and 122-character lines [README.md:437]
- [x] [Review][Defer] (med) The fault banner's "Open messages.log" crosses areas with `navigateByUrl` alone, the DW-148 root cause; unreachable until a built screen serves messages.log [ui/src/app/shell/fault-banner.ts:155] — deferred: `occurrence` appended to DW-148; the residual belongs to `6-14-the-messages-log-viewer`

**Rejected:**

- (low) The outlet mounts no page until the map answers (focus 1). No flash: before the answer neither the refusal nor a page renders. No lost deep link: the route is untouched and the page mounts on the answer. The blank window is the map's latency beyond the instance probe's, both issued in the same pass while the frame itself waits for the probe. The window is permanent only if the map read never settles, and then every screen read would hang on its skeleton the same way (only the connectivity probe passes `timeoutMs`, `connectivity.ts:297`, and `api.ts` bounds the refresh). A failed read counts as answered, pinned by `screen-outlet.spec.ts`. A busy placeholder adds UI for one round trip.
- (low) A failed map read mounts a denied deep link's page, which then issues a 403 read: DW-135 fail-open under AD-8, by design.
- (low) The command box opens a bar on an area whose verdict could deny when the screen's allows: no built screen's pairs differ from its area's.
- (low) The locator's area segment persists "open": EXPERIENCE.md's locator row says it opens the side bar, by design.
- (low) "No web applications in <NAMESPACE>." on an instance-scoped list: copy the spec authored, illustrated by EXPERIENCE.md `:238`; the state is unreachable.
- (low) The authored empty-state line carries no `[ASSUMPTION]` marker: a marker inside a Fixed strings row would be extracted as a literal.
- (low) EXPERIENCE.md `:N` citations past the insertion drift one line: DW-261, not reopened.
- (low) No manual Refresh action: DW-260.
- (low) The drift test reads only the first row: the live `WebApp.App` LIST's 45 rows all carry the six keys, empty values as `""` (probed 2026-09-14).
- (low) `WEBAPPLISTTOOL` repeats the tool id: a rename fails the check loudly with a 404.
- (low) Smoke's 403 line does not name the pair: `smoke.sh --user`, README and `CheckAreaLists` name `%Admin_Secure:USE`; CI signs in as `_SYSTEM`.
- (low) `SmokeListFault` never arms a non-200, and one null row would pass: the non-200 branch is the AC8 mutation's path; the route never emits a null row.
- (low) The browser spec does not check the demo opt-in before asserting `/csp/myapp`: a missing fixture fails loudly as a timeout.
- (low) `irisSession`/`mark` copied from `unreadable.browser-spec.mjs`: refactor, no defect.
- (low) No test reads the declared default sort's row order: the sort is 2.4's generic `applyView`, pinned by its corpus; the declaration is data.
- (low) Nothing reads the list under a second `?ns=`: the port LIST takes no namespace and the grammar has no namespace filter.
- (low) `Wire.cls`'s setup check does not confirm ADMINUSER lacks `%Admin_Secure`: a public grant fails the entry and 403 assertions loudly.
- (low) The review pass ran `Wire` on the live instance: a process record, not code; no `OcuPilotWire*` user or role remains on `ocupilot-iris` (queried 2026-09-14).
- (low) The spec's own `:128`, `:362` and `:314` citations: the fix edits the spec's intent sections; noted under Spec Change Log.
- (false) AC6's browser command-box step never changes route: AC6 is worded for a bar open on Logs over the list, which the step drives; the route change is `command-box.spec.ts`'s.
- (false) The filter legs can miss a row behind the virtual-scroll viewport: every leg narrows to at most nine rows; 27/27 green.

## Spec Change Log

- 2026-09-14, code review. **AC1's code face** is asserted on `/api/atelier`'s Dispatch class and `/csp/sys/op`'s Resource, not on `/csp/myapp`'s: those two cells are empty and read "(none)" in body type, the intent's own 2.4 cell rule, so AC1's `/csp/myapp` clause contradicts the Always block. Name and Namespace stay asserted on `/csp/myapp`.
- 2026-09-14, code review. **AC3's reason** ships as `Requires %Admin_Secure:USE` and `You need %Admin_Secure:USE to open Web applications.`. AD-8 has a denial name the failed pair, and the 1.9 formatter fills `<resource>` with it. The bare-resource illustrations were wrong at their origin: EXPERIENCE.md `:216`, `:236`, `:327`, `:329`, `:375`, `:453` and DESIGN.md `:988` now name the pair. The Fixed strings rows keep `<resource>`. `epic-2-context.md` is stale against both documents.
- 2026-09-14, code review. **`ScreenOutlet` mounts no page until `NavigationService.answered()`**, which a failed map read also sets. It was added outside the Execution list because a denied deep link otherwise issued AC3's forbidden read; the Code Map's "Gating UI already exists, so there is nothing to build" did not hold for the outlet.
- 2026-09-14, code review. **The command box calls `showArea` only on an open side bar.** A collapsed bar stays collapsed with its stored choice, per EXPERIENCE.md's side-bar row, and `setActiveArea` moves it with the route. AC6's command-box leg starts from an open bar and is unchanged.
- 2026-09-14, code review. The Execution task's `:128` and `:362` read `:330` and `:363` after the row insertion; the Code Map's `:314` is the pre-insertion line.

## Review Triage Log

### 2026-09-14 — Review pass

- verdicts: 45 findings — high 0, medium 7, low 32, false 6, maybe-false 0
- findings:
  - `[medium]` `[reject]` Command box `showArea` saves the side bar open, overriding a Ctrl+B close — the intent names `ShellState.showArea` for DW-148; `showArea` persisting is Home tiles' documented precedent; a non-persisting variant changes the intent's named surface.
  - `[medium]` `[patch]` A failed map read's `notify()` is untested, so an OnPush outlet could stay blank — `navigation.test.mjs` subscribes to the failing service and asserts one notification; mutation observed.
  - `[low]` `[reject]` The outlet renders nothing until the map answers — the frame itself waits for the instance probe issued in the same pass as the map read; a waiting state adds UI for one round trip.
  - `[low]` `[patch]` `navigation.ts` header still says only "nothing is gated" — header now says pages wait for `answered()`.
  - `[low]` `[patch]` `ScreenReadWire` keys clause cannot catch drift; `Type`/`DispatchClass`/`Resource` untyped; `tBad` overwritten — added string checks for the three, first problem per row kept.
  - `[low]` `[patch]` `context.fields` never held to the live row — the drift test now walks `ContextFields()` too.
  - `[low]` `[reject]` "No web applications in <NAMESPACE>." contradicts instance scope — copy written by the spec and accepted by the lead; the state is unreachable.
  - `[medium]` `[defer]` No manual Refresh action on the first live list (`EXPERIENCE.md:562`) — pre-existing in 2.4's list page and command bar; no story owns it.
  - `[low]` `[patch]` Smoke docs miss `webapplications` and its `%Admin_Secure:USE` need — README check list and pending line, `smoke.sh --user`, and `CheckAreaLists`' doc updated.
  - `[low]` `[reject]` Spec AC1/AC3 wording, Code Map "nothing to build" and `:362` left uncorrected — fix edits this build's spec; listed for the lead under Auto Run Result.
  - `[low]` `[patch]` AC3 browser assertions compare against the formatter only — literal sentence and "Requires %Admin_Secure:USE" asserted.
  - `[low]` `[patch]` `LIVE_PAYLOAD` "not hand-typed" comment untrue; three literals can drift — comment reworded; a cross-language literal compare rejected as new tooling.
  - `[low]` `[patch]` Single-screen comments now false — corrected in `app.routes.ts`, `app.routes.spec.ts`, `fault-banner.ts`, `navigation.ts`, `navigation.test.mjs`, `command-box.spec.ts`, `locator-bar.spec.ts`, `Test/ScreenRegistry.cls`, `Test/Navigation.cls`.
  - `[low]` `[reject]` `EXPERIENCE.md:N` citations past the insertion elsewhere in the tree are off by one — 137 citations, several already off at baseline (`strings.ts` `:328`/`:329`); a sweep is not a direct correction.
  - `[low]` `[patch]` The new row cites `:128` for the namespace switch's name — row now cites `:330`, the header row naming "Namespace".
  - `[medium]` `[patch]` The command box's Home skip is untested — Home-row test added; dropping `!area.navigates` goes red.
  - `[low]` `[patch]` `filterTo` waits on the Name cell only and can hang — waits on whole-row text and the named row.
  - `[low]` `[reject]` AC1 does not pin "(none)" in body type — `table-model.ts` returns `code: false` for an empty cell, pinned by 2.4's `table-model.test.mjs`.
  - `[low]` `[patch]` Drift test passes a `maxRows` the port ignores — removed.
  - `[low]` `[patch]` `CheckAreaLists` doc claims every area; `WEBAPPLISTTOOL` duplicates the tool id; test classes over 500 lines — doc reworded; the duplication is a named check's input; `Wire.cls` (619) and `Descriptor.cls` (527) were over 500 at baseline.
  - `[low]` `[reject]` A hung map read blanks every screen — no read timeout exists anywhere in the shell, and the frame needs the instance probe answered first.
  - `[low]` `[reject]` Command box could open a bar on an area the rail denies — no built screen's verdict differs from its area's today.
  - `[false]` `[reject]` Locator could open the bar on Home's area — Home is the only navigating area and its area segment is suppressed.
  - `[low]` `[patch]` Smoke fails for a principal without `%Admin_Secure` — documented (grouped with the smoke docs row).
  - `[low]` `[patch]` `ScreenRead` header overclaims "every production read" — narrowed to admin `LIST` reads.
  - `[low]` `[patch]` `values.SECURE` null passes the precondition — asserts `'0'`.
  - `[low]` `[reject]` AC1 code-face claim for the myapp row — grouped with the spec-wording row.
  - `[low]` `[reject]` AC3 sentence claim — grouped with the spec-wording row.
  - `[medium]` `[patch]` Failed map read notification untested — grouped with the notify row.
  - `[medium]` `[patch]` Home exception untested — grouped with the Home-row test.
  - `[medium]` `[patch]` Smoke "exactly one row" branch never exercised — `Test/SmokeListFault.cls` and `Smoke:TestAScreenReadWithoutOneRowFailsTheListCheck`; `If 0` mutation observed.
  - `[low]` `[patch]` AC7's `ReadTool` assertion has no own mutation — `toolIdentifier` `webapp.lists` applied, red, reverted; line written.
  - `[low]` `[reject]` AC3's mutation stops at the first wait — Rule 19 asks one mutation per AC; rail, side-bar and command-box gating are 1.9's pinned UI.
  - `[low]` `[patch]` Keys clause vacuous against drift — grouped with the `ScreenReadWire` row.
  - `[low]` `[patch]` Four stale comments — grouped with the single-screen comments row.
  - `[false]` `[reject]` "AdminPort is not called" unshown for this descriptor — the gate precedes the port for every descriptor, pinned by `ScreenRead:TestADeniedCallerIsRefusedBeforeThePort`.
  - `[false]` `[reject]` `Wire.cls` has no throwaway guard — its principal is suite-owned with teardown, the discipline the project sanctions.
  - `[low]` `[patch]` Filter fields other than Name unexercised at the surface — AC1's legs now narrow through Type, Resource, Dispatch class and Name.
  - `[false]` `[reject]` Cap notice not asserted in the UI — the matrix row asks for rows and `truncated`, which `ScreenReadWire` asserts.
  - `[low]` `[patch]` Drift test ignores context fields — grouped with the context-fields row.
  - `[low]` `[reject]` Empty-state scope tension — grouped with the empty-state row.
  - `[low]` `[patch]` Command-box path from a collapsed bar unasserted — collapsed leg added to the command-box test.
  - `[low]` `[patch]` `LIVE_PAYLOAD` provenance — grouped with the `LIVE_PAYLOAD` row.
  - `[false]` `[reject]` `answered()` gate beyond the Approach — needed for AC3's "no screen-read request", not per-screen code; recorded under Auto Run Result.
  - `[false]` `[reject]` Readings diverge from AC wording — both follow the intent contract's "(none)" rule and the shipped pair spelling; grouped with the spec-wording row.

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

**Observed (implementation pass, 2026-09-14):**

- `npm run build` green (prebuild, mirror up to date). `npm test`: 702 node and 236 component tests green.
- `check-objectscript.py` 0 problems over 171 files; its harness 73 OK; `lint-docs.sh` 0 issues.
- `%UnitTest_Result` on `ocupilot-iris`: ReadTool run 1494 11/11, Descriptor 1503 20/20, ScreenRead 1504 18/18, ScreenReadWire 1505 3/3, Smoke 1506 12/12.
- Throwaway `ocupilot-ci`: Wire 15/15 (run 3); `smoke.sh` PASSED, `webapplications` pass, `arealists` pending naming Epic 2; `npm run test:browser` 27/27. Torn down after.

Mutations, each reverted with the tree confirmed identical to the pre-mutation `git status`/`git diff` snapshot (throwaway mutations were made in its scratch copy and reloaded back):

- mutation: Enabled column `kind` `text`, mirror rebuilt and installed on the throwaway → `web-applications.browser-spec.mjs` AC1 "Enabled shows a 7px outline disc and then No".
- mutation: the declaration reads `NameSpace` → `ScreenRead:TestEveryDeclaredReadFieldIsAKeyOfTheLiveRow` names the field; `ScreenReadWire:TestTheWebApplicationsListReadsOverTheWire` fields and per-row assertions.
- mutation: `privileges` `[]` in the throwaway's descriptor → browser AC3 (the list renders, the denied title never appears) and `Wire:TestTheWebApplicationsListIsDeniedToAPrincipalWithoutAdminSecure` entry, 403, code and `failedPair`.
- mutation: `ScreenOutlet.page` drops the `answered()` guard → browser AC3 "no screen read was issued"; `screen-outlet.spec.ts` "before the navigation map has answered".
- mutation: id kind `none`, mirror rebuilt and installed → browser AC5.
- mutation: `choose()` drops `showArea` → browser AC6; `command-box.spec.ts` "choosing a screen moves an open side bar to that screen's area". `open()` drops `showArea` → `locator-bar.spec.ts` "the area segment opens the side bar".
- mutation: `classicPage` lower-cased → `Descriptor:TestTheWebApplicationsListValidatesAndNamesItsClassicPageInItsOwnCase`.
- mutation: `WEBAPPLISTTOOL` `webapp.nosuch` → `Smoke:TestTheWebApplicationsListIsALiveCheck`, and `smoke.sh` on the throwaway reports `fail webapplications` and FAILED.
- mutation: `toolIdentifier` `webapp.lists` (AC7) → `ReadTool:TestTheRegistryListsDescriptorReadsAndInheritedKinds` (run 1510).
- mutation: `choose()` drops `!area.navigates` → `command-box.spec.ts` "choosing a screen whose area navigates (Home)".
- mutation: the failed-read branch of `runLoad` drops `notify()` → `navigation.test.mjs` "the map has answered once a read completes".
- mutation: `If tCount '= 1` → `If 0` in `CheckAreaLists` → `Smoke:TestAScreenReadWithoutOneRowFailsTheListCheck` (run 1511).

**Observed (review pass, 2026-09-14), after the patches:**

- `npm run build` green; `npm test` 702 node and 237 component tests green; `check-objectscript.py` 0 problems over 172 files, harness OK; `lint-docs.sh` 0 issues.
- Live `ocupilot`: `ci-runner.mjs` 48 classes, 434 tests, 0 failed (runs 1512-1559); `smoke.sh` PASSED, `webapplications` pass.
- Throwaway `ocupilot-ci`: Wire 15/15; `smoke.sh` PASSED with `webapplications` and `demofixture` pass; `npm run test:browser` 27/27; torn down.

**QA pass (2026-09-14) — closing the `screen-outlet.ts` gap named in the QA stage brief:**

The implementer's `answered()` gate on `ScreenOutlet.page` (outside the Execution list, per "For the lead") already had two of its four claims pinned with a demonstrated mutation each, both pre-existing in this diff: no read before the map answers (`screen-outlet.spec.ts:165`, "before the navigation map has answered..."; mutation on record above) and a denied deep link issuing no read (`web-applications.browser-spec.mjs` AC3, `reads` asserted `[]`; mutation on record above). The other two claims -- a failed map read still renders the page rather than hanging on a blank outlet, and Home specifically still renders once it does -- had no test exercising the actual `notify()`-driven transition from unanswered to answered-by-failure; the existing tests only ever construct the harness already in one static state (`answer` fixed at `true` or `false` for the whole test). Closed with one new test in `screen-outlet.spec.ts` (QA) that starts unanswered, flips the stub to answered (the shape a failed `runLoad` leaves: `answered() === true`, every verdict still `UNGATED`) and fires the same `notify()` callback the service calls, then asserts Home renders.

- test file (QA): `ui/src/app/shell/screen-outlet.spec.ts` -- `StubNavigation.subscribe`/`notify` changed from a no-op to the same listener-set pattern already used in `rail.spec.ts`, `side-bar.spec.ts`, `command-box.spec.ts` and `home.page.spec.ts` (no behavior change, only lets this stub be notified like theirs); new test "a map read that completes with a failure still counts as answered (DW-135 fail-open), so Home renders once it lands rather than staying on a blank outlet forever".
- mutation: `screen-outlet.ts` constructor's `this.navigation.subscribe(() => this.mapGeneration.set(this.mapGeneration() + 1))` replaced with `this.navigation.subscribe(() => {})` (the signal bump dropped, `mapGeneration` never moves) → the new test's `expect(root.querySelector('app-home-page')).not.toBeNull()` went red (`expected null not to be null`); the other 13 tests in the file, including the pre-existing "before the navigation map has answered" test, stayed green. Reverted; `git status --short` shows only the spec file changed and `git diff --stat` on `screen-outlet.ts` is empty.
- `ng test --include="src/app/shell/screen-outlet.spec.ts"`: 14/14 green pre-mutation, 13/14 (the new test red) at the mutation, 14/14 green after revert. Full `npm test` re-run clean at 702 node / 238 component tests (237 + 1).
- (c) "does not hang on a skeleton" and (d) "Home still renders" are one claim exercised through one path here, not two independently falsifiable behaviors in this harness: the only mounted route is Home, and the `page` getter's answered-then-UNGATED branch is the single piece of logic both items describe. One mutation demonstrates both; see `mutations_demonstrated` in Decisions.

**Code review pass (2026-09-14):**

- mutation: `AddPending`'s `arealists` line says "a later epic" for "Epic 2" (AC8) → `Smoke:TestTheRealListExecutesSomething` (run 1561, "the pending list names the epic"). Reverted; tree identical; reloaded.
- mutation: `choose()` drops `&& this.shell.open()` → `command-box.spec.ts` "…leaves a collapsed one collapsed" (`expected true to be false`). Reverted; tree identical.
- mutation: `Namespace` dropped from `read.filter`, mirror and bundle rebuilt and installed on the throwaway → `web-applications.browser-spec.mjs` AC1 `filterTo(page, 'HSCUSTOM', '/csp/myapp')` timed out. Reverted; tree identical; throwaway reinstalled.
- `npm run build` green; `npm test` 702 node and 238 component tests green; `check-objectscript.py` 0 problems over 172 files, harness 73 OK; `lint-docs.sh` 0 issues.
- Live `ocupilot-iris`: Descriptor run 1560 20/20; Smoke run 1562 13/13.
- Throwaway `ocupilot-ci`: `npm run test:browser` 27/27; `smoke.sh` PASSED, `webapplications` pass, `arealists` pending naming Epic 2; torn down.

## Auto Run Result

Status: done
Blocking condition: none

**Implemented.** `Screen/Descriptor/WebAppList.cls` and its mirror, the EXPERIENCE.md row and eight string keys, the `webapplications` smoke check, DW-148 through `ShellState.showArea` in the command box and the locator's area segment, and the tests the Execution list names.

**Files:**

- `src/OcuPilot/Screen/Descriptor/WebAppList.cls`, `ui/src/app/core/screens.generated.ts`: the declaration and its mirror.
- `src/OcuPilot/Install/Smoke.cls`, `scripts/smoke.sh`, `README.md`: the `webapplications` check, the pending line, the docs.
- `ui/src/app/core/navigation.ts`, `ui/src/app/shell/screen-outlet.ts`: `answered()`; the outlet mounts no page before the map answers.
- `ui/src/app/shell/command-box.ts`, `locator-bar.ts`: `showArea` before navigating.
- `ui/src/app/core/strings.ts`, EXPERIENCE.md: the Fixed strings row and keys.
- Tests: `Test/{Descriptor,ReadTool,ScreenRead,ScreenReadWire,Smoke,SmokeListFault,Wire,Read/WebApps}.cls`; `ui/browser/web-applications.browser-spec.mjs`; `command-box`, `locator-bar`, `screen-outlet`, `header`, `command-bar`, `rail-wire` specs; `navigation`, `navigation-wire`, `screen-mirror`, `strings` tool tests.
- Comments corrected: `app.routes.ts`, `app.routes.spec.ts`, `fault-banner.ts`, `Test/ScreenRegistry.cls`, `Test/Navigation.cls`, `ui/browser/unreadable.browser-spec.mjs`, `app.wire.spec.ts`.

**Review:** 45 findings. 26 patched in 19 entries (3 medium: failed-read notification test, Home-skip test, smoke rows-shape test; 16 low). 1 deferred (no manual Refresh action on any list). 18 rejected, each with its reason in the Review Triage Log.

**Follow-up review recommended: true.** Patched by entry verdict: high 0, medium 3, low 16 entries. The unverified risk is the shell-wide mount change: every screen's page, Home included, now waits for the navigation map. It was checked on a local instance and the throwaway only, never on a slow or partly reachable instance.

**Verification:** see Verification › Observed (review pass).

**For the lead:**

- `NavigationService.answered()` is outside the Execution list. The Code Map's "Gating UI already exists" did not hold: a denied deep link issued a 403 read before the map answered, which fails AC3.
- AC wording the delivered tests read differently: AC1's code face for `/csp/myapp`'s empty Dispatch class and Resource cells (they render "(none)" in body type; pinned on `/api/atelier` and `/csp/sys/op` instead), and AC3's sentence, which ships as `%Admin_Secure:USE`.
- The row cites `:363` for the second line, the spec's `:362` after the insertion. `epic-2-context.md` is stale against the new row.
- `EXPERIENCE.md:N` citations past `:314` elsewhere in the tree now read one line early. Some were already off before this story.
