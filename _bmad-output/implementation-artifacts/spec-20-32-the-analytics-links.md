---
title: 'Story 20.32: The analytics links'
type: 'feature'
created: '2026-10-14'
status: 'done'
baseline_revision: 'a0e965cd6b70c9fcbdc01533254fa6c6153b52d3'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** OcuPilot offers no way to reach Architect, Analyzer or the User Portal, so an analytics developer leaves for the classic portal to find them. The screen vocabulary's `external` archetype ("opens a new tab") has no screen, no page and no client behavior.

**Approach:** Add three listed Analytics screens of archetype `external`: Architect, Analyzer and User Portal.

- The instance composes each address from the namespace's default CSP application and a closed vocabulary of vendor pages, and answers it on the navigation map.
- The side bar and the command box open the address in a new tab with no opener.
- The screen's own route shows the classic-link card with the same address, or says why the page cannot open.
- OcuPilot rebuilds, frames and loads nothing of the vendor pages.

## Boundaries & Constraints

**Always:**

- **The address is the instance's.** `Screen/ExternalPage.Href(toolIdentifier, namespace)` composes it in four parts:
  1. `$System.CSP.GetDefaultApp(ns)`, given a leading and a trailing `/` exactly as `%DeepSee.Utils.%IsDeepSeeEnabled` does. The link therefore opens the application whose flag made the area apply.
  2. The vocabulary's page file.
  3. `?$NAMESPACE=`.
  4. The URL-encoded namespace.

  It answers `""` when the vocabulary has no entry, when the namespace is empty, or when the result fails `Registry.ClassicHrefProblem` (AD-47). No caller text enters it.
- **Only applying `external` entries carry `href`.** `Kernel/Shell/Navigation.Payload` sets `href` on an `external` screen's entry only when its area applies in the route's namespace and the address is not empty. No other entry carries `href`.
- **Pairs (AD-8, every pair).**
  - Architect: `%DeepSee_Portal:USE`, and its own `%DeepSee_Architect:USE`.
  - Analyzer: `%DeepSee_Portal:USE`, and its own `%DeepSee_Analyzer:USE`.
  - User Portal: `%DeepSee_Portal:USE`.
  - Each declares its classic page as `classicPage` (AD-44): `%DeepSee.UI.Architect`, `%DeepSee.UI.Analyzer` and `%DeepSee.UserPortal.Home`.
- **A new tab, with no opener.** The side bar and the command box call `openInNewTab(href)`, which runs `window.open(href, '_blank', 'noopener,noreferrer')`. Each calls it synchronously in the person's own click or key press. The page's link is the classic-link card's anchor (`target="_blank" rel="noreferrer"`). A tab opened with an opener starts with a copy of the tab's token pair (AD-47).
- **A gated entry is never hidden.** It stays drawn, `aria-disabled`, naming its pair, and opens nothing.
- **Rule 11 files take add-only edits.** The `ARCHETYPE_PAGES` entry is one added loader line, 20.29's pattern.

**Never:**

- Never frame, embed, fetch, proxy or rebuild a vendor page, and never call `/api/deepsee`. Nothing in OcuPilot, its tests or Task 0 loads a vendor page, because each load holds a license unit for 900 s; the loads this plan measured are recorded in Design Notes.
- Never compose an address on the client, from a person's text, or from `classicPage` (AD-44).
- Never call `window.open` without `noopener`, and never open a tab from a timer or after an `await`, which a browser blocks as a popup (inference).
- No read, table, action, write or read tool, governance key, entity type or `AnalyticsPort` change.
- No either-of gate. AD-64's is Screen permissions' alone.
- No edits to:
  - `app.routes.ts`, `angular.json` or `Kernel/Proposal/Prohibited.cls`;
  - `.github/workflows/ci.yml`, `ui/tools/ci-shards.mjs`, `ui/tools/ci-timings.json` or `ui/tools/ci.test.mjs`;
  - `epics.md`, or the spine (the lead writes the Design Notes drafts there).

## I/O & Edge-Case Matrix

Rows read on `ocupilot-b-ci`. "USER" means USER with analytics enabled by `AnalyticsProbe.Enable` (20.11, planned).

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Side bar | USER, signed in as `_SYSTEM`; side-bar Architect | A new tab at `/csp/user/_DeepSee.UI.Architect.zen?$NAMESPACE=USER`. Its `window.opener` is null and its session storage holds no `ocupilot.token-pair`. The OcuPilot tab's URL is unchanged | - |
| Command box | USER; type "analyzer", press Enter | A new tab at `/csp/user/_DeepSee.UI.Analyzer.zen?$NAMESPACE=USER`, with no opener | - |
| User Portal | USER; side-bar User Portal | A new tab at `/csp/user/_DeepSee.UserPortal.Home.zen?$NAMESPACE=USER` | - |
| Map | `GET /api/ocupilot/navigation?ns=USER` | Exactly the three `external` entries carry `href`, each equal to `ExternalPage.Href(<toolIdentifier>,"USER")` | - |
| Gated | The `%Developer` floor principal, who holds no `%DeepSee_Architect` or `%DeepSee_Analyzer` | Architect and Analyzer answer `allowed:false` with their own pair as `failedPair`. Each is drawn `aria-disabled` with "Requires %DeepSee_Architect" (or `_Analyzer`), and a click opens nothing. User Portal opens | The existing gated drawing |
| No analytics | HSCUSTOM | No `href` on the map, and the Analytics area is not drawn. `analytics/architect?ns=HSCUSTOM` shows "Analytics is not enabled in this namespace." and no link | - |
| Route page | `analytics/architect?ns=USER`, by deep link or the agent's `shell.screen.open` | The classic-link card: its title, its caption, and the anchor "Architect" to the address, with `target=_blank rel=noreferrer` | - |
| Undeclared | An `external` descriptor whose tool identifier the vocabulary lacks, or that declares a read or an action | `Registry.Validate` refuses it. `screen-mirror.mjs` refuses the read and action half with the same message | The refusal names AD-44 |

</intent-contract>

## Code Map

All paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-20`. Lines were read at `f1e24f58da0cad25039f0e30b6409141e1adeeb1`. Story 20.11 lands first, and every symbol it adds is marked **(20.11, planned)**. Task 0 re-anchors them.

**Server:**

- `src/OcuPilot/Kernel/Shell/Navigation.cls` `Payload` :25-64. The screen loop is :45-54, after `SetVerdict` :51. The area's `applies` is set at :41.
- `src/OcuPilot/Kernel/Shell/About.cls` `HelpHref` :145-164 is the sibling: it composes from the declared data and never from caller text.
- `src/OcuPilot/Kernel/Scope.cls`: `Set` :28, `Current` :36 and `Clear` :44.
- `src/OcuPilot/Screen/Registry.cls`:
  - `Validate` :158-391;
  - `ClassicLinkProblem` :3470;
  - `ClassicHrefProblem` ~:3598, the root-relative check to reuse;
  - `SUGGESTEDPROMPTSMIN` :3007;
  - `OwnPrivilegesProblem` :814 and `AreaCoverageProblem` :870. An own pair is needed because the area set is `%DeepSee_Portal:USE` only (`Screen/Area.cls`:90).
- `src/OcuPilot/Screen/Descriptor/InteropSchemaViewer.cls` is the descriptor sibling: built, listed, no read, an own pair.
- `src/OcuPilot/Screen/Descriptor/Base.cls` accessors: `Archetype` :204, `ToolIdentifier` :516 and `ClassicPage` :398.
- `src/OcuPilot/Screen/Archetype.cls`: `external` exists already, with link-out class `none`.
- `src/OcuPilot/Screen/Tool/Navigate.cls`:
  - `BuiltRoutes` :70-85 holds every built route, so the agent can open these routes, onto the card page. This stays unchanged.
  - `Test/ToolNavigate.cls`:14 derives the routes.

**Client:**

- `ui/src/app/core/navigation.ts`:
  - `ScreenVerdictWire` :55-59 and the map parse :1104-1112;
  - `firstOpenableEntry` :205-213 (Home tile and locator) and `openableEntry` :223-231.
- `ui/src/app/shell/side-bar.ts`: template :113-129, `resolved` :151-183, `open()` :247-254.
- `ui/src/app/shell/command-box.ts`: `CommandRow` :77-97, `choose()` :410-428, `screenCandidates` :458-484.
- `ui/src/app/shell/classic-link-card.ts`: `present`, `href` and `label` :81-99; glyph `↗`. It is mounted nowhere yet.
- `ui/src/app/shell/screen-outlet.ts` `ARCHETYPE_PAGES` :52-64. `ArchetypePages` :48-50 makes every built archetype a required key, so one built `external` descriptor fails `ng build` until it has a page.
- `ui/src/app/shell/list-page.ts`:181 resolves its screen through `navigation.screenForUrl(router.url)`.
- `ui/src/app/core/table-model.ts`:175 `formatClassicRowLinkDescription`, with `classicRowLinkDescription` at `strings.ts`:977. `data-table.ts`:386-388 carries it as `aria-description`.
- `ui/src/app/core/token-store.ts`:64 `PAIR_STORAGE_KEY`.
- `ui/tools/screen-mirror.mjs`:
  - `readProblem` :1325-1331 and `suggestedPromptsProblem` :2572;
  - the archetype check :3326-3332, and `BuiltArchetypeKey` :3446-3480.

**Tests and rosters:**

- `src/OcuPilot/Test/StageTwoTools.cls` `Elsewhere` :121. Rows go alphabetically after the `Analytics*` rows **(20.11, planned)**. The load-bearing test is :414.
- `src/OcuPilot/Test/SurfaceCoverage.cls` `Coverage` :54. Follow the row format of :249-251.
- `src/OcuPilot/Test/Navigation.cls` :427-560: the analytics block of 7 **(20.11, planned)**.
- `src/OcuPilot/Test/InteropFloor.cls` `BASESCREENS` :32 and `src/OcuPilot/Test/DeveloperFloor.cls` `SCREENS` :38, as 20.11 leaves them. `DeveloperFloor.ClassicResource` :516 reads a compiled `RESOURCE` list.
- `src/OcuPilot/Test/InteropEditorDescriptor.cls` is the descriptor-test sibling.
- `src/OcuPilot/Test/Http.cls` `AbsoluteRequest` :207, used as `Test/Wire.cls` uses it.
- `AnalyticsProbe` `Enable`, `Remove` and `Gone` **(20.11, planned)**.
- `scripts/ci-throwaway.sh` :434-503: the `# classes:` lines of the `OCUPILOT_ALLOW_PRINCIPALS` roster.
- Client tests:
  - `ui/tools/navigation.test.mjs` :141-425, with the analytics routes **(20.11, planned)**;
  - `ui/tools/screen-mirror.test.mjs` owners :2441-2477;
  - `ui/tools/strings.test.mjs` :474-509;
  - `screen-outlet.spec.ts` :564-588 and `app.routes.spec.ts` :69-92. Both pass once the loader line exists.
- Browser:
  - `ui/browser/interop-viewers.browser-spec.mjs`:485 `waitForTarget`;
  - `about-help-links.browser-spec.mjs` :115-161 interception;
  - `interop-host-tabs.browser-spec.mjs` :80-104 `structural`;
  - `side-bar-spec.mjs` `sideBarLabels`, and `namespace-features.mjs` `waitForMapAnswered`;
  - `structural-walk.mjs` walks every built screen without an id in HSCUSTOM (:76, :218, :743). No `SKIP` is needed.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`:
  - the side-bar prose :159 (20.11's Analytics sentence);
  - the Fixed strings, last row :604; classic-link rows :305-306;
  - `external` :72 and :838;
  - the new-tab ban :887.

**Vendor (read only):**

- `RESOURCE` is any-of at USE (`irissys/%ZEN/Controller.cls`:32-50):
  - Architect `%DeepSee_Architect,%DeepSee_ArchitectEdit` (`irislib/%DeepSee/UI/Architect.cls`:17);
  - Analyzer `%DeepSee_Analyzer,%DeepSee_AnalyzerEdit` (`UI/Analyzer.cls`:10);
  - Home `%DeepSee_Portal,%DeepSee_PortalEdit` (`UserPortal/standardPage.cls`:23).
- The classic menu is `%DeepSee/UI/Application.cls` `GetDeepSeeArray` :342-368, in the order Architect, Analyzer, User Portal. Its URLs come from `%ZEN/Portal/standardPage.cls` `GetNewURL` :1121-1150: `GetPortalApp`, the page, then `$NAMESPACE=<ns>`.
- `%SYSTEM/CSP.cls`: `GetDefaultApp` :159 and `GetPortalApp` :307.
- `%DeepSee/Utils.cls` `%IsDeepSeeEnabled` :11052-11080.

## Tasks & Acceptance

**Execution:**

- [x] **Task 0 (re-anchor and measure, no product code).** First run `git rev-parse --show-toplevel`.
  - **Re-anchor.** After 20.11 merges, re-anchor every (20.11, planned) symbol above. If 20.11's listed positions are not 1-3, the links take the next three.
  - **Contention.** Run `git diff --stat $(git merge-base HEAD origin/OCU-1-epic18) origin/OCU-1-epic18` over the Rule 11 files. It was empty at plan; a non-empty result goes to the lead.
  - **Measure on `ocupilot-b-ci`.** Read `$System.License.LUConsumed()` first, and load no vendor page.
    1. After `AnalyticsProbe.Enable`, `ExternalPage.Href` for USER uses the application `%IsDeepSeeEnabled("USER")` read, and `%SYS.Portal.Resources.NormalizePage` of each address answers its classic page.
    2. **The browser recipe.** A browser-level `Fetch.enable` pauses the first request of a `noopener` tab, and `LUConsumed()` reads unchanged afterwards. If it does not pause it, use the fallback in Design Notes.
    3. **The strings.** The new values are unique in `strings.ts`, and the Fixed strings count stays more than 50 under its bound.
  - A measurement that contradicts this spec halts the stage, with its evidence.
- [x] `src/OcuPilot/Screen/ExternalPage.cls` (new) -- the closed vocabulary, keyed by tool identifier:
  - `analytics.architect` → `_DeepSee.UI.Architect.zen` and `%DeepSee.UI.Architect`;
  - `analytics.analyzer` → `_DeepSee.UI.Analyzer.zen` and `%DeepSee.UI.Analyzer`;
  - `analytics.userportal` → `_DeepSee.UserPortal.Home.zen` and `%DeepSee.UserPortal.Home`.

  It has `File(pScreen)`, `ClassicPage(pScreen)` and `Href(pScreen, pNamespace)`, composed as Always says. It is pure: no gate, no namespace switch, no write. The doc comment names AD-44, AD-47 and AD-65.
- [x] `src/OcuPilot/Screen/Registry.cls` (add-only) -- add `ExternalProblem(pDescriptor)`, called from `Validate` beside `ClassicLinkProblem`. It refuses, each with a message naming AD-44:
  - an `external` screen with no vocabulary entry;
  - a vocabulary identifier on any other archetype;
  - a `classicPage` other than the vocabulary's;
  - an `external` screen that declares a `read`, a `table`, an action, a `tab` or a `parentScope`.
- [x] `ui/tools/screen-mirror.mjs` -- an `externalProblem` that refuses the read, table, action, tab and parentScope half with `Registry`'s exact message. The vocabulary half is server-only (Design Notes).
- [x] `src/OcuPilot/Kernel/Shell/Navigation.cls` -- in the screen loop, after `SetVerdict`: when the screen's `Archetype()` is `external` and its area applies, set `href` to `ExternalPage.Href(ToolIdentifier(), Scope.Current())` if it is not empty. Add one doc-comment sentence on `href`.
- [x] `src/OcuPilot/Screen/Descriptor/AnalyticsArchitectLink.cls`, `AnalyticsAnalyzerLink.cls`, `AnalyticsUserPortalLink.cls` (new; sibling `InteropSchemaViewer`).
  - Each has area `analytics`, archetype `external`, `built` true, `refreshes` false, scope `namespace`, id `none`, `entityType` `""`, no read and no actions, `classicLinkExemption` all-false, and empty `context.fields`.
  - Three prompts in `promptGroupGettingStarted`.
  - Doc comments name AD-5, AD-8, AD-44, AD-47 and AD-65.

  | Class | Route · position | toolIdentifier | Pairs (own) | classicPage | commandAliases |
  |---|---|---|---|---|---|
  | `AnalyticsArchitectLink` | `analytics/architect` · 4 | `analytics.architect` | Portal + `%DeepSee_Architect:USE` (own) | `%DeepSee.UI.Architect` | architect, cube designer, deepsee architect |
  | `AnalyticsAnalyzerLink` | `analytics/analyzer` · 5 | `analytics.analyzer` | Portal + `%DeepSee_Analyzer:USE` (own) | `%DeepSee.UI.Analyzer` | analyzer, pivot tables, deepsee analyzer |
  | `AnalyticsUserPortalLink` | `analytics/user-portal` · 6 | `analytics.userportal` | Portal | `%DeepSee.UserPortal.Home` | user portal, dashboards, deepsee portal |

- [x] `ui/src/app/core/strings.ts` (add-only) -- the literals in Design Notes › Strings. Then regenerate the mirror with `cd ui && node tools/screen-mirror.mjs`.
- [x] `ui/src/app/core/navigation.ts`:
  - Parse an optional string `href` per screen entry, held with the verdicts and reset with the map.
  - Add `screenHref(route): string`, answering `''` when there is none.
  - `firstOpenableEntry` skips `archetype === 'external'`, so Home's tile and the locator never route onto a link.
- [x] `ui/src/app/shell/new-tab.ts` (new) -- `openInNewTab(href)`, the one `window.open(href, '_blank', 'noopener,noreferrer')` call.
- [x] `ui/src/app/shell/side-bar.ts`:
  - An allowed `external` entry with an `href` carries the glyph and an `aria-description` from `formatClassicRowLinkDescription(STRINGS.classicRowLinkDescription, label)`.
  - `open()` calls `openInNewTab` and does not route.
  - An `external` entry with no `href` routes as today, onto its page, which says why.
- [x] `ui/src/app/shell/command-box.ts` -- `CommandRow` gains `href`, and `choose()` makes the same branch for a `screen` row.
- [x] `ui/src/app/shell/classic-link-card.ts` -- an optional input `link` (`{href, label}`) that, when given, stands in for the exemption in `present`, `href` and `label`.
- [x] `ui/src/app/shell/external-page.ts` (new) -- the `external` page.
  - It resolves its screen as `ListPage` does and is headed by its title.
  - With `screenHref` set it shows `<app-classic-link-card [link]>`. Without it, it shows `externalAreaNotEnabled` with the area's label.
  - It issues no request and uses tokens only.
- [x] `ui/src/app/shell/screen-outlet.ts` -- the one line `external: () => import('./external-page').then((m) => m.ExternalPage)`.
- [x] **Server tests.**
  - `src/OcuPilot/Test/AnalyticsLinkDescriptor.cls` (new, unarmed, read-only):
    - `TestTheLinkScreensRegister`: the table's values; `Validate` passes; each `classicPage` equals `NormalizePage` of its file and is compiled; Architect's and Analyzer's compiled `RESOURCE` (`DeveloperFloor.ClassicResource`) names their own pair.
    - `TestTheVocabularyIsClosed`: `""` for an unknown identifier and for an empty namespace. `Href("analytics.architect","USER")` equals the normalized `GetDefaultApp("USER")` + file + `?$NAMESPACE=USER`. Each of `ExternalProblem`'s four refusals fires on a doctored declaration.
    - `TestHscustomCarriesNoAddress`: `Scope.Set("HSCUSTOM")`, then `Payload`. No entry carries `href`. `Scope.Clear()` after.
  - `src/OcuPilot/Test/AnalyticsLinkMap.cls` (new, armed `OCUPILOT_ALLOW_PRINCIPALS`; `AnalyticsProbe` `Remove` and `Enable` before all, `Remove` and `Gone` after all) -- `TestTheMapAnswersEachAddress`: over HTTP (`Http.AbsoluteRequest`) as `_SYSTEM`, `GET /api/ocupilot/navigation?ns=USER` gives exactly three entries with `href`, each equal to `Href`. `?ns=HSCUSTOM` gives none.
- [x] **Rosters, each name read from the instance:**
  - `StageTwoTools` `Elsewhere`: three rows;
  - `SurfaceCoverage`: three `<screen>` rows naming `AnalyticsLinkDescriptor` `TestTheLinkScreensRegister`;
  - `Navigation.cls`: the analytics block goes from 7 to 10, the links last in position order;
  - `InteropFloor` `BASESCREENS` and `DeveloperFloor` `SCREENS`: add `AnalyticsUserPortalLink` and update their comments;
  - `scripts/ci-throwaway.sh`: a `# classes:` entry for `AnalyticsLinkMap` under `OCUPILOT_ALLOW_PRINCIPALS`.
- [x] **Client tests.**
  - `ui/tools/navigation.test.mjs`:
    - the three routes in the roster;
    - `firstOpenableEntry` skips an `external` entry;
    - the map parse keeps `href`, and `screenHref` answers `''` with none.
  - `ui/tools/screen-mirror.test.mjs`: Architect and Analyzer join the owners list, plus an `externalProblem` refusal case.
  - `side-bar.spec.ts` and `command-box.spec.ts`, with `openInNewTab` stubbed:
    - an allowed external entry calls it once with the `href` and never routes;
    - a gated one calls nothing;
    - one with no `href` routes.
  - `classic-link-card.spec.ts`: the `link` input.
  - `external-page.spec.ts` (new): the card with an `href`; the sentence with none.
- [x] `ui/browser/analytics-links.browser-spec.mjs` (new).
  - **`before`:** refuse the live container, require readiness, then `runIris` `AnalyticsProbe.Remove` and `Enable`. Arm the interception (Design Notes): every `*/_DeepSee.*` request is answered with a stub and counted.
  - **`after`:** `Remove`, then assert `Gone`.
  - **Legs, each with its mutation comment:**
    - **AC1.** In USER, `sideBarLabels('analytics')` ends with Architect, Analyzer and User Portal. Each side-bar click opens a target at its matrix address with `window.opener === null` and no `PAIR_STORAGE_KEY`, and the shell URL is unchanged. The command box's "analyzer" Enter does the same.
    - **AC3.** `analytics/architect?ns=HSCUSTOM` shows the sentence and no anchor.
    - **AC4.** `analytics/architect?ns=USER` shows the card, whose anchor `href` equals the map's.
    - **AC5.** `structural` on the three routes in USER: no fresh entry.
    - **Count.** Every vendor request was answered by the stub.
- [x] `EXPERIENCE.md`:
  - :159: after 20.11's Analytics sentence, "then Architect · Analyzer · User Portal, each opening the namespace's own classic page in a new tab (Story 20.32)".
  - :604: one Fixed strings row with the literals.
  - :838 and :72: `external` "opens a new tab from the side bar and the command box; its route shows the classic-link card, or why the page cannot open (Story 20.32)".
  - :887: the new-tab exceptions gain "an `external` screen's side-bar entry and command-box result (Story 20.32)".
  - Then run `cd ui && npm run test:tools`.
- [x] **Roster sweep (Rule 30).** Search `src/OcuPilot/Test`, `ui/tools`, `ui/browser` and the `ui/src` specs for the analytics side bar, the built-screen and route counts, `BASESCREENS`/`SCREENS` and the map's screen-entry keys. Each file changed joins `(loop)`.

**Acceptance Criteria:**

- **AC1 (the story's criterion: linked, not rebuilt).**
  - **Given** USER with analytics enabled and `_SYSTEM` signed in.
  - **When** the person chooses Architect, Analyzer or User Portal in the side bar, or Analyzer in the command box.
  - **Then:**
    - a new tab opens at the instance's address for that page in USER, with no opener and no token pair;
    - the OcuPilot tab stays where it was;
    - OcuPilot itself loads, frames and draws nothing of the vendor page.
- **AC2 (gated; AD-8).**
  - **Given** a caller without `%DeepSee_Architect:USE` or `%DeepSee_Analyzer:USE`.
  - **When** the map answers.
  - **Then:**
    - Architect and Analyzer are refused naming that pair, drawn unavailable, and open nothing;
    - User Portal opens;
    - each floor's roster gains only `AnalyticsUserPortalLink`.
- **AC3 (where it cannot work).**
  - **Given** HSCUSTOM.
  - **When** the map answers and a link's route is opened.
  - **Then** no entry carries `href`, and the page says "Analytics is not enabled in this namespace." with no link.
- **AC4 (the route's page).**
  - **Given** USER.
  - **When** `analytics/architect` is opened as a route, by deep link or by the agent.
  - **Then** the classic-link card shows the same address, opening a new tab.
- **AC5 (declared, closed, rostered, structural).**
  - **Given** the three descriptors.
  - **When** the instance validates them and the build regenerates the mirror.
  - **Then:**
    - each validates on both sides with three prompts;
    - each of `ExternalProblem`'s refusals fires;
    - each screen is in `Elsewhere`, and removing one row reddens that test alone;
    - Analytics navigation carries 10 screens in the pinned order;
    - the structural walk and the spec's `structural` find no fresh entry in either theme.
- **AC6 (Integration, Rule 1).**
  - **Given** USER enabled.
  - **When** `GET /api/ocupilot/navigation?ns=USER` is served.
  - **Then** `Navigation.Payload` answers exactly the three `external` entries with `href` from `ExternalPage.Href`, and the side bar opens that `href` (AC1).

## Spec Change Log

- 2026-10-14, spec gate (runner): the orchestrator ruled Q1 (A); the spine carries the four Story 20.32 clauses (AD-8's names the `*Edit`-only holder's refusal).

## Review Triage Log

### 2026-10-21 -- Review pass

- verdicts: 24 findings -- high 0, medium 0, low 14, false 10, maybe-false 0
- findings:
  - `[low]` `[patch]` `Href`'s empty-default-application guard has no test -- `GetDefaultApp("NOSUCHNS")` reads `""` and without the guard `Href` answers `/_DeepSee.UI.Architect.zen?$NAMESPACE=NOSUCHNS`; added the assertion to `TestTheVocabularyIsClosed`, and dropping the guard reddens it alone.
  - `[low]` `[reject]` `Href`'s leading-slash prepend and `ClassicHrefProblem` refusal are untested -- reaching either needs a web application whose path lacks a leading slash or fails the root-relative check, `GetDefaultApp` answers a leading slash on this build, and creating one writes web-application state for a branch `Payload` cannot reach.
  - `[low]` `[patch]` AC5's mirror half (`externalProblem` and its `buildMirror` call) has no recorded mutation -- ran it: `buildMirror` no longer calling `externalProblem` reddens the buildMirror case alone; line written.
  - `[low]` `[reject]` AC5's "10 screens in the pinned order" has no recorded mutation -- Rule 19 asks one demonstrated mutation per AC and AC5 now carries seven; a position swap reddens the same pinned list.
  - `[low]` `[reject]` AC5's "three prompts" has no recorded mutation -- the floor is the existing `SuggestedPromptsProblem` that every `Validate` call runs, and the new tests assert the three keys; a dropped prompt reddens `Validate` before any new assertion.
  - `[low]` `[patch]` AC2's client half (gated side-bar and command-box entries open nothing) has no recorded mutation -- ran it: removing the gated refusal from `open()` and `choose()` reddens both gated external cases; line written.
  - `[low]` `[reject]` The no-address fallback tests have no mutation -- the fallback is the unmodified routing an entry without `href` takes, AC3 carries two recorded mutations, and any mutation that reddens it also reddens the existing routing tests.
  - `[low]` `[patch]` The Count leg's mutation comment named a mutation that lets a request reach the instance and none was recorded -- rewrote it to a stub-only mutation, ran it (`openInNewTab` also fetching the address: "2 !== 1", every request stubbed, license use unchanged) and wrote the line.
  - `[low]` `[patch]` The `SurfaceCoverage` rows and `AnalyticsUserPortalLink` in the floor rosters have no mutation -- ran both: a removed `SurfaceCoverage` row reddens `TestEveryDeclaredScreenHasACoverageRowAndBack` alone, and the floor row reddens two `InteropFloor` tests; lines written.
  - `[low]` `[patch]` `screenHref` is not tied to `appliesAnswered()` -- read `reload()`: after a namespace move the stored addresses stay until the re-read lands, so a mounted external page could offer the previous namespace's link; `screenHref` now fails closed, with a moved-namespace case that its guard reddens alone.
  - `[low]` `[patch]` `externalProblem` counts `primaryAction: {"id": null}` as an action and `Registry` does not -- `%Get("id")` reads a JSON null as `""`; the mirror now treats null as absent, with a case its old condition reddens.
  - `[false]` `[reject]` The parity check "Registry returns the same sentence" is a source-text include -- the chain holds: the JS sentence must appear in `Registry.cls`, and `AnalyticsLinkDescriptor` compares `ExternalProblem`'s runtime output with its `DECLARES` literal, so drift on any one side reddens a test.
  - `[false]` `[reject]` Gated entries carry `href` on the map (reading A1) -- the spec's Always clause sets `href` whenever the area applies and the address is not empty, the side bar and command box compute `href` only for an openable entry, and Design Notes record that `shell.privileges.read` shows the addresses.
  - `[false]` `[reject]` `firstOpenableEntry` skipping links is a rail and Home effect the intent does not mention -- Tasks and Design Notes require it, and "Decided in-stage" records its one consequence.
  - `[false]` `[reject]` The browser legs read opener and storage from a stub document -- the intent's Never clause requires the stub, and Task 0 measured that it pauses the `noopener` tab's first request; the address, opener and storage read are the tab's own.
  - `[low]` `[reject]` No browser leg signs in as a non-admin principal for the gated path -- the spec plans none; the wire half (`AnalyticsLinkMap`, two probe principals) and the component half pin it, the gated drawing is existing behavior (`namespace-categories`), and a principal-creating browser leg is more than a direct correction.
  - `[false]` `[reject]` "The Analytics area is not drawn" in HSCUSTOM has no new test -- it is Story 20.11's behavior, pinned by `namespace-categories` and `analytics.browser-spec`, both green.
  - `[false]` `[reject]` No new test drives the route through `shell.screen.open` -- Design Notes decide the agent needs no new code and `BuiltRoutes` is unchanged; `ToolNavigate` derives its routes from the built roster and ran green with the three added.
  - `[low]` `[patch]` Only four shapes of the Undeclared row ran through `Validate` -- probed: tab, parentScope and rowActions through `Validate` give the exact AD-44 sentence, so the loop now runs cases 1 to 7; read and table stay on values because an earlier rule refuses a doctored read's missing parts.
  - `[false]` `[reject]` Server and mirror messages are tied by a source-text include -- the same claim as the parity row above.
  - `[false]` `[reject]` `Href` also answers `""` for a namespace with no default application, a fourth empty case -- not a defect; the first row now pins it.
  - `[low]` `[reject]` One generic "not enabled" sentence covers every empty-`href` cause, including an applying area whose address could not be composed -- Design Notes decide one generic sentence, and the composed-failure case needs an applying area whose real default application fails `ClassicHrefProblem`.
  - `[false]` `[reject]` Several existing lines were rewritten in `Navigation.cls`, `Registry.cls`, `command-box.ts` and `side-bar.ts` -- Epic 23's branch changes five `Test/*.cls` classes (checked 2026-10-21), none of these files, and each rewrite is the minimal edit: a local variable, one doc-comment sentence, one row field.
  - `[false]` `[reject]` `scripts/ci-throwaway.sh` and EXPERIENCE.md are in the diff and not on the intent's list -- both are Tasks of this spec, and neither is in the intent's no-edit list.

## Design Notes

**Governing ADs (Rule 6).**

- **AD-5:** three descriptors and no router edit; an archetype page is one loader line.
- **AD-8:** every declared pair; the own pairs are below.
- **AD-44:** each link declares its classic page; no URL comes from `classicPage`.
- **AD-47:** a new tab with no opener; the address is a root-relative, same-origin path.
- **AD-65:** these are the rider's links (its Binds names 20.32).
- **AD-64:** the screens are adjustable; nothing either-of.
- **AD-19:** the client stays zoneless and `OnPush`.
- **AD-20:** absolute API URLs are unchanged.
- **AD-28:** per-tab tokens.

Checked and not engaged: AD-29 and AD-36 (no port, no read), AD-51 to AD-53 (no write), AD-63 (nothing framed), AD-43 (no refresh).

**Measured at this plan** (2026-10-14, `ocupilot-b-ci`, IRIS for Health 2026.2 build 221U). Probes and principals were removed and verified gone. Nine vendor page requests were made in total, with one session per principal; license use peaked at 4 of 8 units.

- **`RESOURCE` is any-of, at USE** (quoted above). Only `%DeepSee_Portal` is public (USE), and no role holds any `%DeepSee_*` resource, so only `%All` reaches Architect and Analyzer by default.
- **The narrower pair suffices.** A principal holding `%DeepSee_Architect:USE`, `%DeepSee_Analyzer:USE`, `%Development:USE` and `%DB_HSLIB:R` passes the vendor's view checks (`CheckArchitectViewAccess` and `CheckAnalyzerViewAccess` read 1; the write checks read 0). Architect and Analyzer answered 200 in HSLIB, read-only.
- **Without those resources** both answered 403. The User Portal answered 200 read-only to a `%Development`-only principal. An unauthenticated request answered 200 with the login page.
- **`GetDefaultApp`** needs no privilege and takes about 7 µs. It answered `/csp/user`, `/csp/hscustom`, `/csp/healthshare` (HSLIB), `/csp/hssys` and `/csp/sys`, with no trailing `/`.
- **`GetPortalApp`** answers `""` unless the caller has a permission on the namespace's default database.
- **Analytics enabled:** HSLIB and HSSYS only. USER, HSCUSTOM and `%SYS` are not.
- **`NormalizePage`** of each file, with or without its application path, answers `%DeepSee.UI.Architect`, `%DeepSee.UI.Analyzer` and `%DeepSee.UserPortal.Home`. No custom resource is assigned.
- **Namespace switching.** Architect and Analyzer have `AUTONS` 1 and honor `$NAMESPACE`. The User Portal has `AUTONS` 0 and runs in its application's namespace.

**Decisions.**

- **The address rides the navigation map.** The map is already read per namespace and recomputed per call, and the side bar must hold the address before the click: a tab opened after an `await` is blocked (inference).
  - *Rejected:* a Help-style `GET /ui/link?route=` (`UiAbout.HandleHelp`). Help's cache is keyed by route, and this address varies by namespace.
  - *Consequence:* `shell.privileges.read` also shows the three addresses.
- **`GetDefaultApp`, not `GetPortalApp`.** `%IsDeepSeeEnabled` decides whether the area applies from `GetDefaultApp`'s application, so the link opens exactly that application.
  - *Named limit:* a person with no permission on the namespace's database meets the vendor's own refusal in the new tab, where the classic menu would gray the item out.
- **The route has a page.** A built archetype requires one (`ArchetypePages`), and a deep link, the agent's `shell.screen.open` and the structural walk all reach the route. The page is the classic-link card, which EXPERIENCE.md already allows to open a new tab. The agent therefore needs no new code, and `BuiltRoutes` is unchanged.
- **`window.open` with `noopener`** in the side bar and the command box. Their entries are a roving-focus button list and an ARIA option list, and are not anchors. The `noopener,noreferrer` feature string severs the opener and the session-storage copy, which the browser leg pins.
- **The vocabulary is keyed by tool identifier, not by `classicPage`,** because `Registry` holds that no URL is derived from `classicPage` (AD-44). Its half of `ExternalProblem` is server-only, as `CLASSICPAGES` is: the client never reads the vocabulary or composes an address.
- **`firstOpenableEntry` skips links,** so Home's Analytics tile opens Cubes and never a link page.
- **One generic sentence,** `externalAreaNotEnabled` "<area> is not enabled in this namespace.", because the `external` page is not analytics-specific. With "Analytics" it reads as 20.11's refusal sentence.

**Interception (the browser recipe; Task 0 confirms it).**

1. Arm it before any click. Open a browser-level CDP session (`browser.target().createCDPSession()`) and send `Fetch.enable` with `{patterns:[{urlPattern:'*_DeepSee.*'}]}`.
2. On each `Fetch.requestPaused`, record the URL and answer `Fetch.fulfillRequest` with `<!doctype html><title>stub</title>`.
3. Catch the tab with `context.waitForTarget(t => t.url().includes('_DeepSee.'))`, as `interop-viewers` :485 does. Then run `evaluate(() => [window.opener === null, sessionStorage.getItem('ocupilot.token-pair')])`.

*Fallback:* `Target.setAutoAttach({autoAttach:true, waitForDebuggerOnStart:true, flatten:true})` on the opener's session, with `Fetch.enable` in the attached session before `Runtime.runIfWaitingForDebugger`.

**Gate question (for the orchestrator).**

- **Q1, Architect's and Analyzer's either-of lists against AD-8's every-pair rule.** *Ruled (A) by the orchestrator, 2026-10-14:* the narrower pair each; an `*Edit`-only holder sees "Requires %DeepSee_Architect:USE" (or Analyzer) at the refusal, in EXPERIENCE.md's "Requires..." form; no to (B). The AD-5, AD-8, AD-44 and AD-47 clauses are written in the spine, AD-8's with that named limit.
  - **(A)** One named narrower pair each: `%DeepSee_Architect:USE` and `%DeepSee_Analyzer:USE`. This follows 20.11's Q2 (A). It is measured sufficient, and no shipped role holds any of the four resources. A custom role holding only an `*Edit` resource is refused here, though the vendor admits it. Recommended; this spec is planned on (A).
  - **(B)** Generalize AD-64's either-of check (`Gate.Alternatives`) to these two screens. This is a spine change, and it re-opens this spec.

**Spine and UX drafts (Rule 20; the lead writes them at the gate).**

- **AD-5, a Story 20.32 clause:** "An `external` screen declares no read, table, action, tab or parentScope. Its tool identifier names a page in `Screen/ExternalPage`'s closed vocabulary. The navigation map answers its `href`, composed on the instance, when its area applies. The side bar and the command box open it in a new tab with no opener, and its route shows the classic-link card."
- **AD-8, a Story 20.32 clause:** "Architect `%DeepSee_Architect:USE` and Analyzer `%DeepSee_Analyzer:USE`, each its own pair and a named narrower audience than the page's any-of `RESOURCE`. User Portal `%DeepSee_Portal:USE`."
- **AD-44, a Story 20.32 clause:** "The analytics links declare `%DeepSee.UI.Architect`, `%DeepSee.UI.Analyzer` and `%DeepSee.UserPortal.Home` as the classic pages they open (`NormalizePage`, measured)."
- **AD-47, a Story 20.32 clause:** "A link screen opens `<GetDefaultApp(ns)>/<vocabulary file>?$NAMESPACE=<ns>`, a root-relative same-origin path the instance composes and `ClassicHrefProblem` checks, in a new tab opened with `noopener`."
- **EXPERIENCE.md:** :72, :159, :604, :838 and :887, as Tasks says.

**Strings (add-only; 13 literals).**

- **Labels:** `analyticsArchitectLabel` "Architect", `analyticsAnalyzerLabel` "Analyzer", `analyticsUserPortalLabel` "User Portal".
- **Sentence:** `externalAreaNotEnabled` "<area> is not enabled in this namespace."
- **Prompts (Getting started):**
  - **Architect:** "What can I change about a cube in Architect?", "Which cubes here could I open in Architect?", "What do I need before Architect can build a cube?"
  - **Analyzer:** "What can I explore in Analyzer?", "Which cubes here could I analyze?", "How do I save a pivot table from Analyzer?"
  - **User Portal:** "What will I find in the User Portal?", "Which dashboards could I open in the User Portal?", "Which of my favorites does the User Portal show?"
- **Reused:** `classicRowLinkDescription`, `classicLinkCardTitle`, `classicLinkCardCaption` and `privilegeRequiresResource`.

**Integration, Consumes, Consumed-by (Rules 1 and 2).**

- **Integration:** AC6. `Navigation.Payload` consumes `ExternalPage.Href`, and the side bar and command box consume the map's `href` (AC1).
- **Consumes:**
  - 20.11's Analytics area, listed positions and `AnalyticsProbe`;
  - 20.1's `applies`;
  - 20.29's loader map;
  - the classic-link card.
- **Consumed-by:** none chartered. Epic 21 or 22's next `external` screen joins the vocabulary.

**Rule 31.**

- **Extended in place:** `Navigation.Payload`, `navigation.ts`, `side-bar.ts`, `command-box.ts`, the classic-link card (an input) and `Registry`. `ClassicHrefProblem` and `formatClassicRowLinkDescription` are reused.
- **`ExternalPage`** follows `About.HelpHref`'s composition. It is its own class because Help's address is the documentation's, per screen, and this one is per namespace.
- **`ExternalPage.ts`** is a new archetype page, as `ListPage` is.
- **`AnalyticsLinkDescriptor`** follows `InteropEditorDescriptor`. It reads `RESOURCE` through `DeveloperFloor.ClassicResource`, because `AssertPageSharesOwnPair` is a private instance method.

**Contended files (Rule 11).** `origin/OCU-1-epic18` (`cc34c272`) changed none of the Rule 11 files since the merge base. Epic 23 (`72e34617`) has committed only planning files.

- Every edit here is add-only. The loader line follows 20.29's ruling.
- `ARCHETYPE_PAGES`, `strings.ts`, `screens.generated.ts`, `Registry.cls`, `StageTwoTools`, `SurfaceCoverage`, the side-bar spec and EXPERIENCE.md are touched.

**Ledger inbox (Rule 17):** none owned (`owned_ledger=0`).

**Named limits.**

- The classic page may ask the person to sign in again; the card's caption says so. `/api/ocupilot` shares `GroupById` `%ISCMgtPortal` with `/csp/healthshare` (measured; the other applications were not read), but whether a session carries over is unmeasured.
- Holders of the narrower pairs see Architect and Analyzer read-only unless they also hold the `*Edit` resource.
- A namespace whose analytics is enabled on an application other than its default is not linked, as `%IsDeepSeeEnabled` would not report it either.

**Weight.** The initial bundle gains the parse, the two branches, three mirror entries and 13 strings, about 3 kB (inference). It was measured at 1.94 MB against a `maximumWarning` of 1992 kB. The page is one new lazy chunk of about 4 kB, under the 88 kB ceiling (inference).

**Size.** One story; no seam is worth a split.

**Decided in-stage.**

- **`openInNewTab` is stubbed through `window.open`.** The Angular unit-test builder refuses `vi.mock` of a relative import, so `side-bar.spec.ts` and `command-box.spec.ts` spy on the one `window.open` call and assert its arguments, and `new-tab.spec.ts` pins the exact feature string.
- **`ExternalPage` also answers `Identifiers()` and `Has()`,** which `Registry.ExternalProblem` reads; `File`, `ClassicPage` and `Href` are as specified.
- **The `<area>` placeholder has its own formatter,** `formatExternalArea`, because `formatArea`'s placeholder is `<Area>` and the Fixed strings literal is lowercase.
- **The page is headed by an `h3`,** under the locator's `h2`, which already carries the screen's title.
- **Two additions beyond the listed tests:** `AnalyticsLinkMap.TestAPrincipalWithoutAnOwnPairIsRefusedNamingIt` pins AC2 over HTTP for a developer-floor principal and one holding only the Architect's pair; `Test/ExternalLink/Doctored` and `Test/ExternalLinkRegistry` run `ExternalProblem`'s shapes through `Validate`, so dropping its call reddens a test.
- **A caller whose only openable Analytics entries are links** (reachable only through an AD-64 adjustment) sees Home's Analytics tile gated in place, naming Cubes' pair, because `firstOpenableEntry` skips links.
- **`NavigationService.screenHref` is fail closed like `applies()`:** it offers no address while the map on hand was read under a namespace the shell has left, so the external page never shows a link for the previous namespace.

## Verification

**Shared surfaces:**

- the analytics side bar and Home tile;
- the navigation map's screen entries (new `href`), and `shell.privileges.read`;
- `ARCHETYPE_PAGES` and the built-archetype set;
- `StageTwoTools` `Elsewhere` and `SurfaceCoverage`;
- `Navigation.cls`' analytics block, and the floors' `BASESCREENS` and `SCREENS`;
- the `OCUPILOT_ALLOW_PRINCIPALS` roster;
- `navigation.test.mjs`' routes, and `screen-mirror.test.mjs`' owners;
- the built-screen count that Screen permissions derives (+3) and the structural walk's count (+3);
- the strings table, and EXPERIENCE.md :72, :159, :604, :838 and :887.

*Every test added or changed passes on a fresh environment, in either order.* `AnalyticsProbe` restores USER's flags, and no test asserts on an analytics state it did not make.

**Setup (slot B; never the dev instance `ocupilot-slot-b`):**

- **Load `src`:**
  1. Run `rsync -a --checksum --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-20/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`.
  2. In `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`, run `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)`.
- **Before any browser run:** `cd ui && npm run build && docker exec ocupilot-b-ci sh -c 'cd /durable/iris/csp/ocupilot && rm -rf ./*' && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`.

**Commands.** Run each in the foreground with `timeout: 600000`, one at a time. Read each class's result from `%UnitTest_Result`.

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.AnalyticsLinkDescriptor --class OcuPilot.Test.AnalyticsLinkMap --class OcuPilot.Test.StageTwoTools --class OcuPilot.Test.SurfaceCoverage --class OcuPilot.Test.Navigation --class OcuPilot.Test.ToolNavigate`. Expected: green.
- `(loop)` The same runner with `InteropFloor`, `DeveloperFloor`, `Descriptor`, `Wire`, `WireAreaAnyScreen`, `ScreenAccessWire`, `CompileWithoutInterop` and every class the sweep changes. Their recorded total is about 1.5 minutes (`ci-timings.json`). Expected: green.
- `(loop)` `cd ui && npm run test:tools`, then `cd ui && npm run test:components`. Expected: green.
- `(loop)` `cd ui && npm run build -- --verbose`. Expected: the prebuild chain is green and the external page chunk is under 88 kB. The initial total is bound by the owner-fixed budget in `ui/angular.json` (warning 2500 kB, error 4000 kB), not by the 1992 kB planning estimate, which predates Story 20.11; a total above 1992 kB and under 2500 kB is a recorded measurement, not a failure. Record the measured initial total and the external page chunk size.
- `(loop)` `uv run scripts/check-objectscript.py <each changed .cls>` and `bash scripts/lint-docs.sh`. Expected: clean.
- `(loop)` `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/<file>`, one file per call, after the redeploy. Expected: green.
  - `analytics-links.browser-spec.mjs`
  - `analytics.browser-spec.mjs` (20.11's; its side bar grew)
  - `namespace-categories.browser-spec.mjs`
  - `a11y-structural-invariants.browser-spec.mjs` (about 462 s)
  - each spec the sweep changes
- **Lead-owned (the runner's):**
  - the full ObjectScript sweep;
  - `cd ui && npm test`;
  - `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`;
  - Rule 30's fresh check.
- **Left to CI:** the full browser suite.

**Planned pinning mutations (Rule 19).** Revert each byte-identical. Reload, or rebuild and redeploy, before the next.

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | `side-bar.ts` `open()` loses the external branch | `side-bar.spec.ts`, and the browser AC1 side-bar leg (no target) |
| AC1 | `openInNewTab` drops `noopener,noreferrer` | The browser AC1 opener and token leg |
| AC1 | `command-box.ts` `choose()` loses the branch | `command-box.spec.ts`, and the browser command-box leg |
| AC1/AC6 | `Href` omits the trailing `/` normalization | `TestTheVocabularyIsClosed`, `AnalyticsLinkMap`, and the browser URL |
| AC2 | Architect loses its own `%DeepSee_Architect:USE` | `InteropFloor`'s and `DeveloperFloor`'s roster tests, and `TestTheLinkScreensRegister` |
| AC3 | `Payload` sets `href` without the `applies` check | `TestHscustomCarriesNoAddress` |
| AC3 | `ExternalPage` draws the card with no `href` | `external-page.spec.ts`, and the browser AC3 |
| AC4 | The card ignores its `link` input | `classic-link-card.spec.ts`, and the browser AC4 |
| AC5 | `Validate` stops calling `ExternalProblem` | `TestTheVocabularyIsClosed`'s refusal legs |
| AC5 | One link's `Elsewhere` row is removed | `StageTwoTools.TestTheRosterAndElsewhereAreEveryRegisteredScreen`, alone |
| AC5 | `firstOpenableEntry` stops skipping links | `navigation.test.mjs`' skip case |
| AC5 | A pale color on the external page | The browser `structural` leg |
| AC6 | `Payload` sets `href` on every screen | `AnalyticsLinkMap` (exactly three) |

**Results (implement pass, `ocupilot-b-ci`).**

- **Task 0.**
  - *Re-anchor.* 20.11's listed positions are 1 to 3, so the links take 4 to 6. Every (20.11, planned) symbol exists. EXPERIENCE.md's cited lines moved: `external` is at :72 and :841, the new-tab ban at :890.
  - *Contention.* `origin/OCU-1-epic18` no longer exists, so the epic-18 diff could not be run. Epic 23's branch changes only five `Test/*.cls` classes, none of them mine.
  - *Measured.* After `AnalyticsProbe.Enable`, `ExternalPage.Href` for USER is `/csp/user/<file>?$NAMESPACE=USER` from `GetDefaultApp("USER")`, `%IsDeepSeeEnabled("USER")` reads 1, and `NormalizePage` of each address answers `%DeepSee.UI.Architect`, `%DeepSee.UI.Analyzer` and `%DeepSee.UserPortal.Home`.
  - *Browser recipe.* A browser-level `Fetch.enable` on `*_DeepSee.*` paused the first request of the `noopener` tab, a stub answered it, the tab read `window.opener === null` and no `ocupilot.token-pair`, and `LUConsumed()` read 1 before and after. The fallback was not needed.
  - *Strings.* All 13 values are unique in `strings.ts`; the Fixed strings table now holds 3,572 literals against the 3,800 bound.
- **ObjectScript.**
  - `AnalyticsLinkDescriptor` 3 tests, `AnalyticsLinkMap` 2, `StageTwoTools` 4, `SurfaceCoverage` 4, `Navigation` 14, `ToolNavigate` 23: green.
  - `InteropFloor` 8, `DeveloperFloor` 10, `Descriptor` 60, `Wire` 20, `WireAreaAnyScreen` 3, `ScreenAccessWire` 8, `CompileWithoutInterop` 7: green.
  - Sweep: `ScreenAccessDescriptor`, `InteropFloorOwnPairs`, `InteropFloorRoutes`, `DeveloperFloorRoutes`, `RosterWant`, `LedgerEmptyPairs`, `PreferencesWire`, `ReadTool`, `ClassicPageGate`: green.
- **Client.** `npm run test:tools` 2,087 pass; `npm run test:components` 258 files and 3,302 tests pass; `npm run build -- --verbose` runs the seven checkers green.
- **Browser.** `analytics-links` 5 of 5, `analytics` 5 of 5, `namespace-categories` 4 of 4, `a11y-structural-invariants` 13 of 13 (369 s). License use read 1 before and after.
- **Static.** `check-objectscript.py` over the 16 changed classes and `lint-docs.sh`: clean.
- **Review pass.** After the patches the tree was rebuilt and redeployed and re-run on `ocupilot-b-ci`: `AnalyticsLinkDescriptor`, `AnalyticsLinkMap`, `StageTwoTools`, `SurfaceCoverage`, `Navigation`, `ToolNavigate` and `DeveloperFloor` green (60 tests); browser `analytics-links` 5 of 5, `analytics` 5 of 5, `namespace-categories` 4 of 4 and `a11y-structural-invariants` 13 of 13; initial total 1.99 MB (354.44 kB transferred). The throwaway ended with no probe state, no `OcuP2032*` principals and license use at 1.
- **Bundle.** Initial total 1,991.67 kB raw (354.50 kB transferred) against the owner-fixed warning of 2,500 kB and error of 4,000 kB. The external page chunk is 2.80 kB raw (1.10 kB transferred), under the 88 kB ceiling.
- **Mutations (Rule 19).** Each applied, observed red, and reverted; `git status --short` and `git diff HEAD` read the same hash before the first and after the last.
  - mutation: `Validate` stops calling `ExternalProblem` -> `AnalyticsLinkDescriptor.TestTheVocabularyIsClosed`, alone (AC5)
  - mutation: `Payload` sets `href` without the `applies` test -> `AnalyticsLinkDescriptor.TestHscustomCarriesNoAddress` and `AnalyticsLinkMap.TestTheMapAnswersEachAddress` (AC3)
  - mutation: `Payload` sets `href` on every screen entry -> `AnalyticsLinkMap.TestTheMapAnswersEachAddress`, the exactly-three leg (AC6)
  - mutation: `Href` omits the trailing `/` normalization -> `TestTheVocabularyIsClosed`, and both `AnalyticsLinkMap` tests (AC1, AC6)
  - mutation: `AnalyticsArchitectLink` loses `%DeepSee_Architect:USE` -> `TestTheLinkScreensRegister`, `AnalyticsLinkMap.TestAPrincipalWithoutAnOwnPairIsRefusedNamingIt`, and the roster and classic-page tests of `InteropFloor` and `DeveloperFloor` (AC2)
  - mutation: one link's `Elsewhere` row removed -> `StageTwoTools.TestTheRosterAndElsewhereAreEveryRegisteredScreen`, alone (AC5)
  - mutation: `side-bar.ts` `open()` loses the external branch -> `side-bar.spec.ts`, and the browser AC1 leg timing out for its target (AC1)
  - mutation: `openInNewTab` drops `noopener,noreferrer` -> `new-tab.spec.ts`, `side-bar.spec.ts`, `command-box.spec.ts`, and the browser AC1 leg: "Architect: the tab has no opener" (AC1)
  - mutation: `command-box.ts` `choose()` loses the branch -> `command-box.spec.ts`, and the browser AC1 command-box clause timing out for its target (AC1)
  - mutation: `ExternalPage` hands the card a link whatever the map answered -> `external-page.spec.ts` (2 tests), and the browser AC3 leg: no sentence (AC3)
  - mutation: the card ignores its `link` input -> `classic-link-card.spec.ts` and `external-page.spec.ts` (3 tests), and the browser AC4 leg waiting for the anchor (AC4)
  - mutation: `firstOpenableEntry` stops skipping links -> `navigation.test.mjs`' skip case, alone (AC5)
  - mutation: `.ocu-external-page-title` coloured `var(--ocu-surface-container-high)` -> the browser AC5 leg: contrast 1.2:1 light and 1.33:1 dark on `analytics/architect` (AC5)
  - Review pass (each applied, observed red, reverted; the tree fingerprint read the same before the first and after the last):
  - mutation: `Href` drops the empty-default-application guard -> `AnalyticsLinkDescriptor.TestTheVocabularyIsClosed`, alone (AC1)
  - mutation: `screenHref` drops its `appliesAnswered()` test -> `navigation.test.mjs`' moved-namespace case, alone (AC4)
  - mutation: `buildMirror` stops calling `externalProblem` -> `screen-mirror.test.mjs`' buildMirror case, alone (AC5)
  - mutation: `externalProblem` counts a null action id as an action -> `screen-mirror.test.mjs`' externalProblem case, alone (AC5)
  - mutation: the gated refusal removed from `side-bar.ts` `open()` and `command-box.ts` `choose()` -> the gated external cases of `side-bar.spec.ts` and `command-box.spec.ts`, beside the existing gated cases (AC2)
  - mutation: `openInNewTab` also calls `fetch(href)` -> the browser Count leg: "the click made one vendor request", 2 !== 1, both answered by the stub and license use unchanged (AC1)
  - mutation: one `SurfaceCoverage` link row removed -> `TestEveryDeclaredScreenHasACoverageRowAndBack`, alone (AC5)
  - mutation: `AnalyticsUserPortalLink` removed from `InteropFloor.BASESCREENS` -> `TestEachPrincipalSignsInAndOpensExactlyItsRoster` and `TestEveryOpenScreenMatchesItsClassicPage` (AC2)

## Auto Run Result

Status: done
Blocking condition: none

**Summary.** Analytics gains three `external` screens, Architect, Analyzer and User Portal, at listed positions 4 to 6. The instance composes each address in `Screen/ExternalPage` (the namespace's default application, the vocabulary's page file, `?$NAMESPACE=`, the encoded namespace) and `Navigation.Payload` answers it as `href` on an applying area's entry. The side bar and the command box open it with `openInNewTab` (`noopener,noreferrer`) and route nowhere. The route shows the classic-link card with the same address, or says the area is not enabled in this namespace. `Registry.ExternalProblem` and the mirror's `externalProblem` refuse an undeclared or over-declared `external` screen. Nothing of a vendor page is loaded, framed or fetched.

**Files changed.**

- Server: `Screen/ExternalPage.cls` (new vocabulary and `Href`), `Screen/Registry.cls` (`ExternalProblem`, `ExternalFaultProblem`, one `Validate` call), `Kernel/Shell/Navigation.cls` (`href`), three `Screen/Descriptor/Analytics*Link.cls`.
- Client: `new-tab.ts`, `external-page.ts` (new), `navigation.ts` (`href` parse, `screenHref`, `firstOpenableEntry` skip), `side-bar.ts`, `command-box.ts`, `classic-link-card.ts` (`link` input), `screen-outlet.ts` (one loader line), `strings.ts` (13 literals), `screens.generated.ts` (regenerated), `_components.scss`, `screen-mirror.mjs`.
- Tests and rosters: `AnalyticsLinkDescriptor`, `AnalyticsLinkMap`, `ExternalLink/Doctored`, `ExternalLinkRegistry` (new); `StageTwoTools`, `SurfaceCoverage`, `Navigation`, `InteropFloor`, `DeveloperFloor`; `scripts/ci-throwaway.sh`; client specs and tool tests; `analytics-links.browser-spec.mjs` (new) and `analytics.browser-spec.mjs`.
- Planning: EXPERIENCE.md rows for `external`, the side-bar prose, the Fixed strings and the new-tab exceptions.

**Review.** 24 findings: 14 low, 10 false, none high or medium. Eight low findings were patched in this pass and 16 were rejected, each with its reason in the Review Triage Log. Nothing is deferred.

- Patched: the empty-application case of `Href` is pinned; `screenHref` fails closed after a namespace move; the mirror reads a null action id as the instance does; `Validate` runs seven refusal shapes; the Count leg's comment no longer prescribes a vendor load; and eight `mutation:` lines were demonstrated for the client halves, the mirror, the Count leg and the roster rows.
- Rejected: two untested defensive branches of `Href`; AC5 mutations beyond one per AC; the no-address fallback; a non-admin browser leg the spec does not plan; the parity-by-source-text claim; and nine readings and additions that the spec, Design Notes or Epic 23's branch settle.

**Follow-up review recommended: false.** Patched this pass: high 0, medium 0, low 8.

**Verification.** On `ocupilot-b-ci` after the patches: seven ObjectScript classes green (60 tests), earlier lists green (166 tests), `npm run test:tools` 2,087 and `npm run test:components` 3,302 pass, the build runs the seven checkers (initial total 1.99 MB, external page chunk 2.80 kB), `check-objectscript.py` and `lint-docs.sh` clean, and the four browser specs green (`analytics-links` 5, `analytics` 5, `namespace-categories` 4, `a11y-structural-invariants` 13). Every mutation was applied, observed red and reverted. The full ObjectScript sweep, `npm test`, smoke and Rule 30's fresh check are the runner's.

**Residual risks.**

- A caller whose only openable Analytics entries are links (reachable only through an AD-64 adjustment) sees Home's Analytics tile gated in place, naming Cubes' pair.
- A custom role holding only an `*Edit` resource is refused Architect or Analyzer here, though the vendor admits it (Q1 (A)).
- The classic page may ask the person to sign in again; whether a session carries over is unmeasured.
- The Epic 18 contention diff could not be run because `origin/OCU-1-epic18` no longer exists; Epic 23's branch touches no file this story edits.
