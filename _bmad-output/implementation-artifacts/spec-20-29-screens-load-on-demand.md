---
title: 'Story 20.29: Screens load on demand'
type: 'feature'
created: '2026-10-12'
status: 'in-progress'
baseline_revision: '9c4d80812ddfde4414c723f89510c46030148c1f'
baseline_commit: '21fe71330033007e50b891982d63d841d9ff75a0'
review_loop_iteration: 1
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: [oversized]
deferred:
  - summary: >-
      Two comments in ui/src/styles/_components.scss still say ngComponentOutlet renders the page host inside div.ocu-screen-outlet; the router outlet does since Story 20.29.
    evidence: |-
      grep -n ngComponentOutlet ui/src/styles/_components.scss answers lines 724 and 6053. The file is one Epic 18 stories edit often, and the gate rulings authorize no non-add-only edit to such a file beyond the four named.
    location: >-
      ui/src/styles/_components.scss:724, :6053
    severity: low
---

<intent-contract>

## Intent

**Problem:** Every screen's page is statically imported by `ScreenOutlet`, so the whole client (3,405,631 bytes) loads before the sign-in card shows, and each new screen moves the initial bundle toward its 4000 kB hard stop.

**Approach:** Every screen route gets a child route whose Angular `loadComponent` fetches that screen's page on first navigation. The shell, sign-in and chrome stay initial. The initial budget is re-based on the smaller initial total, and a per-chunk ceiling holds the lazy chunks. A tab whose screen code cannot load re-checks the instance's bundle, so the existing stale-bundle notice explains it.

## Boundaries & Constraints

**Always:**

- The route table stays generated from the descriptor mirror (AD-5). A new screen of an existing page is descriptor-only. A new page is one loader line in `screen-outlet.ts`'s maps.
- `ScreenOutlet` still decides whether a page mounts: not found, denied, held by the first-login gate, map unanswered. A page never mounts or reads before that.
- A built archetype with no page still fails `ng build` (`BuiltArchetypeKey`).
- No module in the initial set imports a page module statically.
- Budgets use the builder's units, where a kB is 1,000 bytes. `maximumWarning` is the measured initial total plus 5%, rounded up to the next kB (DW-1166). `maximumError` stays `4000kB`.
- Browser specs reach screens by navigation, never by importing page modules.

**Never:**

- Change `src/index.html`, the content-security policy, any response header, `StaticHandler` or any ObjectScript.
- Hand-edit `screens.generated.ts`. Change a prebuild checker.
- Add a router preloading strategy.
- Edit `.github/workflows/ci.yml`, `ui/tools/ci-shards.mjs`, `ui/tools/ci-timings.json` or `ui/tools/ci.test.mjs`.
- Move the area stores and actions that `app.ts` constructs (see Design Notes, named limit).
- Land a non-add-only edit to a Rule 11 file before the orchestrator answers.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Cold deep link | `/ocupilot/<route>`, signed out | Initial files plus that screen's page chunks; the page renders after sign-in | n/a |
| In-app navigation | Rail, side bar, command box or agent to an unvisited screen | Its page chunk is fetched once: 200, `application/javascript`, immutable cache. The page renders. A revisit fetches nothing new | n/a |
| Denied or held screen | Gate refuses, or first-login gate deciding | The refusal, or nothing. The page never mounts and issues no read; its code may download | n/a |
| Unknown URL | Wildcard route | The not-found sentence; no page chunk | n/a |
| Screen code cannot load | Stale tab after a start-path reinstall; the handler answers `index.html` (measured) | URL and screen stay. The client re-reads `/instance`; if another bundle is installed the stale-bundle notice shows | Browser refuses the module (strict MIME); only signed-in tabs re-read |
| Page made eager | A static page import in eager code | `build-output.test.mjs` red, naming the page's selector | n/a |
| Growth | Initial over `maximumWarning`, over `4000kB`, or a lazy chunk over its ceiling | Red naming the bytes and the limit; `ng build` fails at the hard stop | n/a |

</intent-contract>

## Code Map

- `ui/src/app/shell/screen-outlet.ts`:
  - :14-100 is 89 static page imports, including `ListPage` and `DetailPage`.
  - The maps: `ARCHETYPE_PAGES` :127-143, `DESCRIPTOR_PAGES` :161-292, `DESCRIPTOR_EDIT_PAGES` :304-315.
  - Resolvers :332-353; template :385-408; `page` :501-512, which returns `null` for not found, held, unanswered and denied.
- `ui/src/app/app.routes.ts` :63-84 `buildRoutes`: root, base and `:id` routes, all `component: ScreenOutlet`, wildcard last.
- `ui/src/app/app.ts`:
  - :13-77 import about 60 area stores and actions; :287-379 construct them for the tab's life. They stay initial (427,221 bytes of area code, measured).
  - :229 `<app-stale-bundle-notice />` renders inside `@if (frameShown)`; :248 is the root `<router-outlet />`.
- `ui/src/app/shell/panel.ts` :24 imports `AUDITING_FOCUS_ENABLE` from `areas/security/auditing-config.page.ts` (:46), which pulls that page into the initial bundle. Use :1857; `panel.spec.ts` :6, :344.
- `ui/src/app/shell/stale-bundle-notice.ts`: the notice. Its rule is `core/build-identity.ts` `isStale`, with `MAIN_BUNDLE_RE` at :21.
- `ui/src/app/core/instance.ts` :228-260 `verify`/`runVerify`: single-flight, settles once per principal; `reset()` flips status to `checking`.
- `ui/angular.json` :50-56: one `initial` budget, `3527kB` / `4000kB`.
- `ui/tools/angular-json.test.mjs` :347-553: DW-371 pins exactly one budget and the literal `'3527kB'`.
- `ui/tools/build-output.test.mjs`:
  - :174-201 measures `main` and `styles` only and refuses any other emitted JS or CSS.
  - :336-353 checks the Rule 1 strings in `main-*.js` only. In the prototype `STRINGS` and the mirror land in a shared initial chunk, so this check would go red.
- `ui/browser/structural-walk.mjs`: :600-613 `trackRequests` counts `/api/ocupilot` only; :619-633 `settle`, with `QUIET_MS` 500 at :162; :640 `goInApp`.
- `ui/browser/about-help-links.browser-spec.mjs`:
  - :115-137 `rewriteBuildIdentity`.
  - :327-345 the DW-3 test reads the version row, so it is red locally after a `docker cp` redeploy.
- `ui/browser/panel-spec.mjs` :62 `signedInAt`; `ui/tools/session.test.mjs` :1937-2160 hold the `InstanceService` tests.
- Specs that compare map values to classes:
  - `screen-outlet.spec.ts` :27-33, :174-212 (routes with no children), :376-490;
  - `areas/logs/explain-roster.spec.ts` :6-11, :35-42;
  - `areas/system-explorer/source-editor.page.spec.ts` :15, :328, `sql-query.page.spec.ts` :13, :199, `data-browser.page.spec.ts` :14, :264.
- Read-only:
  - `src/OcuPilot/Api/StaticHandler.cls`: :15-18 and :171-186 answer an unresolved path with `index.html`; :348-351 is the policy.
  - `Install/Installer.cls`: :2409-2460 clears and copies the bundle tree; :1480-1490 records `main-*.js` as the build identity.
  - `module.xml` :55 copies the whole directory. `scripts/ci-ipm-archive.sh` :318-330 checks every bundle file is in the archive.
  - `node_modules/@angular/build/src/utils/bundle-calculator.js`: :164-178 initial; :204-215 `anyScript` lists every `.js` file, initial ones included.

## Tasks & Acceptance

**Execution:**

0. Run `git diff --stat $(git merge-base HEAD origin/OCU-1-epic18) origin/OCU-1-epic18` over the Rule 11 files (Design Notes). At plan time it was empty (merge base and Epic 18 head both `857dd298`). Any non-empty result goes to the lead before Task 1.
1. `ui/src/app/shell/screen-outlet.ts`:
   - Delete the page imports and `NgComponentOutlet`.
   - Map values become `PageLoader` (`() => Promise<Type<unknown>>`). Each loads its page's module, as in `() => import('../areas/security/ssl-form.page').then((m) => m.SslFormPage)`.
   - `ArchetypePages` keeps its required `BuiltArchetypeKey` keys. The resolvers become generic over the value.
   - The page slot becomes `<router-outlet />` under the same paren-free `@if (page)`. `page` becomes a boolean with the same four conditions.
   - Doc comments state the contract only.
2. `ui/src/app/app.routes.ts` `buildRoutes`: the root, base and `:id` routes get `children: [{ path: '', loadComponent }]`. The loader is `DESCRIPTOR_EDIT_PAGES` first on an `:id` route, then `resolveScreenPage`. No loader means no child; the wildcard gets none.
3. Move `AUDITING_FOCUS_ENABLE`:
   - Into `areas/security/auditing-config.store.ts`.
   - `auditing-config.page.ts` imports and re-exports it.
   - `shell/panel.ts` and `panel.spec.ts` import it from the store.
4. Update the specs that compare map values to classes:
   - Await the loaders, and give the route fixtures children.
   - `screen-outlet.spec.ts` gains a test that every loader in the three maps resolves to a component.
   - `app.routes.spec.ts` gains a test that every shipped route except the wildcard has exactly one `''` child whose `loadComponent` is the loader the maps name (edit page on `:id` routes), and that the wildcard has none.
5. `ui/tools/build-output.test.mjs`:
   - **Initial set:** the files the emitted `index.html` loads, plus everything reachable through static `import` statements (never `import(`). Lazy is the rest. Together they cover the emitted JS and CSS exactly.
   - **Budgets:** the initial total is at most `maximumWarning`. Every lazy chunk is at most `LAZYCHUNKMAX`, a commented constant here, set to the largest measured lazy chunk plus 5% (rounded up to the next kB).
   - **Page placement:** for each loader specifier in `screen-outlet.ts`, the page's component definition is in a lazy chunk and in no initial file. The definition is matched as `selectors:[[` followed by the page's quoted `selector`, with any quote character; the build emits backticks.
   - **Chrome placement:** every element `app.ts`'s template names is defined in the initial set.
   - **Other checks:** the Rule 1 checks read the initial JS set. Chunk names may carry `-` and `_`.
6. `ui/angular.json` and `ui/tools/angular-json.test.mjs`: set `maximumWarning` from the final measured initial total. Update the pinned literal and its message, and append one comment line. Keep exactly one budget.
7. `ui/src/app/core/instance.ts` `recheckBuild()`:
   - A no-op unless a verify has settled for this principal; otherwise single-flight.
   - It re-reads `/instance` and updates only the build identity, then notifies. It keeps the generation guard and never changes status.
   - The `/instance` read and parse are one private reader shared with `runVerify`.
   - Tests go in `ui/tools/session.test.mjs`: one request, identity updated, status unchanged, no request before settling or after `reset()`.
8. `ui/src/app/shell/stale-bundle-notice.ts`: on a router `NavigationError`, call `recheckBuild()`. Its spec covers this.
9. `ui/browser/structural-walk.mjs` `trackRequests`: also count same-origin `/ocupilot/` `.js` requests as in flight. This is hardening, so the walk never settles before a page's code arrives; it has no AC of its own, and the walk's green run is its check.
10. Browser specs:
    - New `ui/browser/lazy-screens.browser-spec.mjs`, signed in with `signedInAt` at Home. A rail or side-bar click to an unvisited area fetches at least one new `chunk-*.js` (200, `application/javascript`, `immutable`) and renders the page. A return visit fetches none. During the navigation, no `securitypolicyviolation` fires and no console error is logged from the shell path, using the filter at `shell.browser-spec.mjs` :111-124.
    - `about-help-links.browser-spec.mjs` gains a test. `rewriteBuildIdentity` is extended to answer with the document's own `main-*.js` until armed, then another name. Once armed, `chunk-*.js` requests are answered with the shell document as `text/html`.
    - In that test, a click to an unvisited area leaves the URL and the screen unchanged, and the stale-bundle notice appears. It must be absent before the click.
11. Record the measurements under `## Verification`: before and after, the initial total and file count; lazy count, total and largest; and the full chunk table from `npm run build -- --verbose`. The code commit message carries the totals.

**Acceptance Criteria:**

- AC1 (AD-5):
  - **Given** the production build,
  - **When** it is built,
  - **Then** every page the outlet's maps name is defined only in lazily loaded chunks, reached through each screen route's child `loadComponent`, and every element `app.ts`'s template names is in the initial set.
- AC2 (DW-1166):
  - **Given** the build before and after,
  - **When** it is measured,
  - **Then** the initial totals and chunk sizes are recorded, `maximumWarning` is the measured initial total plus 5% under the `4000kB` stop, and `npm run test:tools` is red when a lazy chunk exceeds its ceiling.
- AC3:
  - **Given** the browser suite and the prebuild checkers,
  - **When** they run,
  - **Then** the new spec sees a screen's chunk arrive on a person's navigation with no policy violation, and the prebuild chain passes unchanged with `screens.generated.ts` still generated.
- AC4:
  - **Given** a signed-in tab whose next screen's code cannot load,
  - **When** a person navigates there,
  - **Then** the screen and URL stay, and when the instance names another bundle the stale-bundle notice appears.

### Review Findings

Code review, 2026-10-12, four layers on the parent tier (`review_tier: full-opus`): 29 rows, 11 entries after grouping (high 0, medium 2, low 9), 15 rejected.

- [x] [Review][Patch] The cold-open check in `lazy-screens` copied `build-output.test.mjs`'s static-import regex with no stated reason (Rule 2, medium). Both now read `staticImportsOf` from the new `ui/tools/bundle-imports.mjs` [ui/tools/bundle-imports.mjs:15]
- [x] [Review][Patch] `openCold` copied the shared sign-in sequence (Rule 2, low). The shared `signedInAt` takes a `prepare` hook instead [ui/browser/panel-spec.mjs:64]
- [x] [Review][Patch] The AC4 test inlined `lazy-screens`' rail and side-bar click (Rule 2, low). `openFromSideBar` is now shared from `panel-spec.mjs` [ui/browser/panel-spec.mjs:89]
- [x] [Review][Patch] "Moves nothing else" could not see a re-check that copied any field but `instanceName`, or that settled the verdict again. The re-read now changes every field and answers a mismatching version [ui/tools/session.test.mjs:2304]
- [x] [Review][Patch] The `lazy-screens` header said it writes nothing, and the `about-help-links` header listed four things and no navigation. Both corrected [ui/browser/lazy-screens.browser-spec.mjs:19]
- [x] [Review][Patch] A mutation comment named `UserForm` where the observed red is the first built screen with an edit page [ui/src/app/app.routes.spec.ts:64]
- [x] [Review][Patch] The fixture test's "no child" checks also passed for a route that was never built. Each route is now asserted to exist first [ui/src/app/app.routes.spec.ts:168]
- [x] [Review][Patch] "Every loader resolves to a component" accepted any named class. It now requires `reflectComponentType` to answer a selector [ui/src/app/shell/screen-outlet.spec.ts:459]
- [x] [Review][Patch] The chrome placement test would fail on Angular's own `ng-container`, `ng-template` or `ng-content` in `app.ts`. These are now excluded [ui/tools/build-output.test.mjs:372]
- [x] [Review][Patch] The console clause of the `lazy-screens` tests had no demonstrated mutation (Rule 19, low). Now demonstrated; see `## Verification` [ui/browser/lazy-screens.browser-spec.mjs:206]
- [x] [Review][Defer] The agent navigator reports a page chunk that cannot load as a refusal for unsaved changes (`NAV.REFUSEDUNSAVED`), because a failed load now rejects `navigateByUrl` [ui/src/app/shell/agent-navigator.ts:106]. Deferred: in-epic medium with medium fix-risk, since it needs a new outcome in `Api/Turn.cls`'s closed vocabulary. DW-2369, `routed owner=burndown`.

**Rejected:**

- **Silent click on a chunk failure with an unchanged bundle** (false/low): the re-check's own `/instance` read reports through `ApiService.onFault`, so a network drop raises the connectivity banner. The remaining case, a chunk failing while `/instance` answers the same bundle, is not reachable from the static handler. The router retries `loadComponent` on the next click.
- **Unhandled `navigateByUrl` rejection in a stale tab** (low): console-only. The fix is router configuration in `main.ts`, outside the footprint.
- **Three one-line chunk-path regexes** (low): there is no named divergence harm.
- **Nothing bounds the total client size** (low): Design Notes decide that nothing reads the whole output directory. Page growth is the expected effect of adding pages, and a new total gate is more than a direct correction.
- **Recorded counts in `## Auto Run Result` and the cycle log** (reject): the fix edits the spec's run record or the lead's log.
- **DW-2368** (reject): adjudicated `wontfix-accepted` by the lead and orchestrator.
- **A dirty form's flag is cleared before a failed load** (low): the person had already chosen to leave without saving. It needs a stale tab, a dirty form and an unvisited target together, and the fix adds state to `FormDirty`.
- **A re-check during a reinstall answers `installing` and is not retried** (low): `Session` already surfaces the install, and the next failed click re-checks.
- **No timeout on the re-check read** (theoretical): `verify` has the same exposure by design (`api.ts`: every caller but the probe waits). The browser's own timeout ends the call, and `reset()` clears the slot.
- **The test's `fetch` of the renamed chunk can reject** (low): only when the throwaway is unreachable, where the test fails anyway.
- **A URL-unsafe `config.username`** (low): no slot's browser config names one.
- **No mutation for AC4's "URL and screen stay" or AC3's prebuild clause** (false): Rule 19 asks for one mutation per AC, and AC3 and AC4 each have demonstrated ones. The URL and screen assertion compares two reads taken in the same test.
- **The triage row on the console clause misstates the record** (false): it records only the policy clause as demonstrated.
- **The AC4 browser test does not pin the `index.html` answer** (reject): the client's contract is any answer that is not a module, and pinning the handler's answer would bind a client test to the server behavior Q1 left as it is.
- **The Code Map places the notice inside `@if (frameShown)`, and Task 0's result is not recorded** (reject): both fixes edit the spec. Today's Task 0 re-run is empty: no Epic 18 commit beyond the merge base touches a file in this diff. The notice's re-read is inert while signed out, through `settled`.

### CI red on f92b0dcf (run 38329739528) - rework iteration 1

Both failures are product behavior that lazy loading changed, ruled a story red by the orchestrator: fix the cause in the product, never by adding waits to specs.

- [x] [CI] **Focus is lost on a lazily loaded page.** `oauth.browser-spec.mjs:289` (browser shard 3/5), AC1: after Right then Enter opens a tab, "the tab it opened holds focus on the page that replaced the strip" read `'BODY'`, expected `'security/oauth/clients'`. The focus hand-off runs before the chunk's component exists. Restore it after the lazy component renders, for every path that hands focus to a page (tab strips, side bar, row targets, the agent's navigation), as EXPERIENCE.md's focus rules require; pin it with a test that goes red on the old ordering. Closed (reproduced): Enter reaches `open` twice, and with the chunk loading the second navigation supersedes the first, whose `false` answer cleared the request the second had just made. A request is now owned by its navigation (`detail-page.ts`).
- [x] [CI] **The shell reads ready before the loaded page.** `language-server-editor.browser-spec.mjs` test 1 (browser shard 5/5), AC1/AC2/AC4: "No element found for selector: `.ocu-form-bar-actions .ocu-button-text`". Make the shell's screen-ready state wait for the loaded page (the form bar renders inside it), so specs and people see the same thing; pin it. Closed (reproduced with the editor's form read held 300 ms, 2 of 2 on the bundle without the fix): `import()` settles a task even for a cached module, so a navigation to a route whose loader had not run yet left the page it replaces one more render. The create form showed its saved confirmation, which the spec reads as done, while the editor that replaces it draws no form bar until its read lands. `rememberedPage` (`app.routes.ts`) answers an already resolved loader's class at once, so such a navigation commits before the next render, as before pages were lazy. `ScreenOutlet`'s host also reads `aria-busy="true"` from creation until its page has rendered once, which `settle` already waits on.
- [x] [CI] **Find every other place that assumed a page exists synchronously** after a navigation (focus, scroll restore, first-field focus, the screen-ready or settled signals the browser helpers and the structural walk read), and fix each in the product. Record the list in this section. Closed: the list is under the direction bullets.

Direction for this pass (lead; orchestrator ruling: the cause is fixed in the product, never with a wait or a sleep in a spec):

- **Reproduce first**, on the deployed bundle of the slot B throwaway `ocupilot-b-ci` (web 52777): rebuild and redeploy as the Setup line under `## Verification` says, then one file per call, `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/<file>`, for `oauth.browser-spec.mjs` and `language-server-editor.browser-spec.mjs`. Logs of the two CI legs: `/private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/1518373f-040c-4be6-a814-a27bfbff2961/scratchpad/e20r/rw-2029/ci-browser-3of5.log` and `ci-browser-5of5.log` (read the failing test's block only). A red that does not reproduce on the first run is still an ordering bug: find it by reading the code path, and make the fix's pinning test go red on the old ordering.
- **Focus** (item 1): fix where the shell hands focus to a page after a navigation so it runs once the routed page has rendered, for the tab strip's Enter (`shell/detail-page.ts` `focusOnArrival`), the side bar, row targets, the agent's navigation and first-field focus. The behavior contract is EXPERIENCE.md's focus rules (search "focus").
- **Ready** (item 2): the shell's screen-ready state, which the browser helpers, `structural-walk.mjs`'s `settle` and a person's first interaction read, must hold until the loaded page exists, so a form bar or a list inside the page exists when the shell reads ready.
- **Specs to run** on the redeployed bundle, one file per call, after the fix: `oauth`, `language-server-editor`, `lazy-screens`, `about-help-links` (stamp test skipped as the Verification line says), `navigate`, `shell`, `rail`, `gate`, `a11y-structural-invariants`, and every other spec the search shows reads a signal this pass changed (name them in the list below). No `--shard` runs; the runner runs the whole suite.
- **Rule 19:** every pinning test this pass adds or changes gets its `mutation:` line in `## Verification` (the old ordering: focus or ready signalled before the page renders), observed red on a rebuilt and redeployed bundle, then reverted with the tree byte-identical.
- Do not edit `.github/workflows/ci.yml`, `ui/tools/ci-shards.mjs`, `ui/tools/ci-timings.json` or `ui/tools/ci.test.mjs`. Tick each `[CI]` item above when it is done.

**Other synchronous page assumptions (item 3).** Searched in `ui/src`, apart from specs: every `navigateByUrl` caller that uses its answer, every page-level `NavigationEnd` subscriber, every `.focus()` that lands on arrival, and every scroll restore.

- **Fixed:** the tab strip's focus request (`detail-page.ts`); the navigation that waited a task on a cached module (`rememberedPage`, `app.routes.ts`); the outlet on screen before its page (`screen-outlet.ts`).
- **Remains:** a hand-off to a page of another module (a wizard to its editor) leaves the departing page on screen for that first fetch, as any lazy load does.
- **Holds, read at construction:** a page is built after `NavigationEnd`, not during it, and all 38 pages with a `NavigationEnd` handler take the current route in their constructors: 29 set `followed` from the URL, eight set `readFor`, call `follow()` or `readIfMoved()` or build their source from it, and `auditing-config.page.ts` reads `currentNavigation() ?? lastSuccessfulNavigation()` for the navigation state. `ScreenArrivals` and the gate's `arriveFromGate()` are set before the move or the hold.
- **Holds, answers used with the store, not the page:** `home.page.ts` `fixAndRequest`, `citation-navigator.ts` and `agent-navigator.ts` compare the target store's `lastUpdate()` or announce, and touch no page element.
- **Not page code:** the locator bar's heading focus (the agent's navigation) and `app.ts` `focusOnFrameArrival` land on shell elements; the side bar keeps its own focus, and a row's name cell and the command box hand focus to no page, as EXPERIENCE.md names only the tab strip and the agent heading; there is no router scroll restoration, and a screen's scroll offset is applied by the data table's own render.
- **Specs run for them**, one file per call on `ocupilot-b-ci` with the final bundle: `oauth`, `language-server-editor`, `lazy-screens`, `about-help-links`, `navigate`, `shell`, `rail`, `gate`, `a11y-structural-invariants`, `auditing-screen`, `definitions`, `users-editor`, `interop-host-tabs`, `system-explorer-sql`, `license-usage`, `ecp-application-servers`.

## Spec Change Log

## Review Triage Log

### 2026-10-12 - Review pass

- verdicts: 20 findings - high 0, medium 3, low 10, false 7, maybe-false 0
- findings:
  - `[low]` `[patch]` `lazy-screens` asserted `homeFetched >= fetched`, true for any array that is only pushed to - deleted with the unused `fetched`.
  - `[false]` `[reject]` the return-visit assertion cannot tell a router that re-runs `loadComponent` from one that does not - the claim it pins is the network one (no new chunk request on a revisit), and it goes red on a URL or cache-header regression; router caching is not a claim of the story.
  - `[low]` `[patch]` the policy and console clauses of the AC3 test had no recorded mutation - a policy-violating `new Function` in `ListPage` demonstrated the policy clause red with the page still rendering; recorded under `## Verification`.
  - `[medium]` `[patch]` the page-placement gate examined only pages written as `import(...).then((m) => m.X)`, so a hand-merged `Promise.resolve(NewPage)` over a static import shipped in `main` with every test green - the eager half now reads every `*.page.ts` selector (plus `list-page.ts`, `detail-page.ts`) from disk; mutation recorded.
  - `[medium]` `[patch]` "an unknown URL renders no page" could not fail, since the harness wildcard had no child - the wildcard now carries a child that would mount Home's page; deleting the `screen() === null` guard reddens it alone.
  - `[low]` `[patch]` `initial.size + lazy.length === emitted.length` is true by construction - deleted; the unclassified-file and emitted-file assertions are the real guards.
  - `[low]` `[reject]` `trackRequests` hardening has no check of its own - Task 9 records it as hardening whose check is the walk's green run, and a deterministic check needs a fake-page harness for a timing-only behavior.
  - `[low]` `[defer]` two comments in `_components.scss` still say `ngComponentOutlet` renders the page host - the file is one Epic 18 edits and the gate rulings authorize no other non-add-only edit to such a file; in the spec's `deferred:` list.
  - `[low]` `[patch]` the "stops listening to the router when it is destroyed" test had no mutation line - unsubscribe removed, test red alone; recorded in the spec's header and under `## Verification`.
  - `[low]` `[reject]` a cold deep link's chunk requests are not recorded while signed out - the observable half (the page renders after sign-in) is pinned by `users`, `gate` and `shell`, and asserting when the router fetches would pin its internals.
  - `[low]` `[reject]` the command box and agent paths are not driven by `lazy-screens` - they go through the same router navigation; `navigate` drives the agent path and is green.
  - `[false]` `[reject]` the chunk bodies are re-fetched with Node `fetch` rather than read from the page - chunk names are content hashes, so the bytes are the ones the page ran.
  - `[false]` `[reject]` page identity now comes from the route table while `ScreenOutlet.screen()` reads the mirror - both read the mirror, and the unchanged "no declared route is swallowed" test holds the agreement.
  - `[low]` `[reject]` the stale tab is simulated by interception rather than a real reinstall - the simulation reproduces the measured `index.html` answer, and a reinstall test is heavier than the Q1 ruling asks.
  - `[false]` `[reject]` the recheck fires on any `NavigationError`, wider than a chunk failure - Task 8 specifies it, and the recheck is single-flight, read-only and moves only the build identity.
  - `[low]` `[reject]` no request-level assertion for an unknown URL's missing chunk - the wildcard has no child (`app.routes.spec.ts`) and the outlet renders no page.
  - `[false]` `[reject]` the per-chunk ceiling is a test constant, not an `angular.json` budget - Design Notes record the decision (`anyScript` would also bound `main`).
  - `[medium]` `[patch]` the loader pattern is the only way the placement gate finds pages (same root cause as the page-placement row above) - fixed by that patch.
  - `[false]` `[reject]` AUDITING_FOCUS_ENABLE's move, the `readInstance()` refactor, the walk hardening and the awaited loaders are outside the contract's list - each is a numbered Task in this spec.
  - `[false]` `[reject]` the initial total is recorded, not asserted - the DW-371 test measures the emitted initial set against `maximumWarning`.


## Design Notes

**Governing ADs:**

- **AD-5** routes are generated from the mirror; a page registration is one line.
- **AD-19** zoneless, OnPush; `core/` stays framework-free, so the loaders live in `shell/`.
- **AD-20** the absolute API URLs are untouched; chunks resolve against their importer under `/ocupilot/`.
- **AD-21** unchanged: the handler serves chunk files, and answers a missing one with `index.html`.
- **AD-47** unchanged policy: `script-src 'self'` admits the same-origin chunks and `modulepreload`. Chunks are the bundle's own module files, not fetched text evaluated (inference).
- **AD-12** the static carve-out applies; **AD-28** and **AD-63** are unaffected.
- NFR-1 and NFR-10.

**Measured at this plan.** Throwaway `ocupilot-b-ci`, a prototype in the scratchpad (never in the tree). The tree's bundle (`main-XIZQM6QR.js`) was rebuilt and redeployed afterwards, with the directory cleared first.

- **Before:** `main` 3,200,160 bytes plus `styles` 205,471 bytes = 3,405,631, one initial JS file.
- **Prototype after:**
  - Initial: 1,895,548 bytes in 20 files.
  - Lazy: 127 chunks, 1,662,079 bytes; the largest is 83,328 (the data browser page).
  - All files together come to 3,557,627 bytes, 4.5% more than before.
  - No page selector appears in an initial file, and the nine chrome selectors are all present there.
  - Suggested figures: `maximumWarning` 1991kB and `LAZYCHUNKMAX` 88 kB. The implement stage sets both from its own build.
- **Opening and navigating:** a cold open to the sign-in card took a median of 159 ms against 208 ms before (7 runs each, cache off, localhost). An unvisited lazy screen rendered in 71 to 83 ms.
- **Serving:** a chunk answers 200, `application/javascript`, immutable, `nosniff`. A missing chunk answers `index.html` as 200 `text/html`, `no-store`. Chrome refused it ("Strict MIME type checking is enforced for module scripts"), so the navigation failed and the URL and screen stayed.
- **The emitted `index.html`** gains `<link rel="modulepreload">` hints; `src/index.html` is unchanged. Chunk names can carry `-` and `_`, from Angular's Rolldown chunk optimizer (`environment-options.js` :135-160).
- **Build identity:** changing one page changed `main`'s hash, so `main-*.js` still names the whole build (measured once).
- **Tests on the prototype:**
  - Green: `rail`, `shell`, `gate`, `switches`, `users`, `screen-height`, `navigate` and `a11y-structural-invariants` (359 s).
  - Component suite: 234 of 234 files green with the five map-comparing specs set aside. Those five fail to compile, as Task 4 expects.

**Decisions:**

- **`loadComponent` per route, under `ScreenOutlet`,** because AC1 names Angular's route mechanism. A dynamic `import()` inside the outlet was rejected: it is not route-level, and it commits the URL before the code arrives.
- **The maps stay in `screen-outlet.ts`,** so Epic 18 keeps its one-line pattern. TypeScript refuses a class where a loader belongs.
- **The lazy ceiling lives in `build-output.test.mjs`, not as `anyScript`.** `anyScript` also bounds `main` (about 800 kB) (`bundle-calculator.js` :204-215), so it would hold no lazy chunk. Named limit: a small chunk can grow up to the ceiling unflagged.
- **After the change, which check reads which number:**
  - `ng build` errors on the initial total over 4000 kB.
  - `build-output.test.mjs` (CI `gates`, `npm test`) checks the initial total against `maximumWarning`, and each lazy chunk against its ceiling.
  - Nothing reads the whole output directory, before or after. CI needs no edit; the new spec file joins the browser roll-up on its own.
- **AC4 uses the existing stale-bundle notice and its string.** No new string, no `strings.ts` entry and no EXPERIENCE.md row.
- **AC2's "recorded in the commit"** is met by the totals in the commit message plus the chunk table in this spec, which ships in the same commit.
- **The prebuild checkers are unchanged.** `screen-mirror`, `classic-links`, `field-lists` and `ipm-manifest` read ObjectScript sources or the roster. `browser-reset` reads `ui/browser`. `client-lint` admits `import('../areas/…')`. None reads the outlet or the routes.

**Named limit.** The area stores and actions `app.ts` constructs (427,221 bytes) stay initial. They register declared Creates before the first change-detection pass. A follow-up story could move them; none is chartered here.

**Rule 11 asks.** These edits are not add-only, on files Epic 18 changes:

1. `ui/src/app/shell/screen-outlet.ts` (45 Epic 18 commits since 2026-09-25): every page import is deleted and every map value rewritten. After this, a new page is one loader line.
2. `ui/src/app/app.routes.ts`: three `push` lines in `buildRoutes` gain `children`, plus one import.
3. `ui/angular.json`: the `maximumWarning` literal. Epic 18 re-bases it too, and the forward merge re-measures.
4. `ui/tools/angular-json.test.mjs`: the pinned literal and its message.
5. `ui/src/app/shell/screen-outlet.spec.ts` and `ui/src/app/app.routes.spec.ts`: map and route assertions.

Consequence: an Epic 18 branch that adds a statically imported page conflicts at its forward merge, and stops compiling until the entry is a loader. Epic 18 has not touched the other edited files since 2026-09-25.

**Footprint extensions** (outside Epic 20's `paths_hint`): `ui/src/app/app.routes.ts`, `ui/src/app/app.routes.spec.ts`, `ui/angular.json`.

**Questions for the orchestrator** (not blocking):

- **Q1, a missing chunk answered with `index.html`.**
  - (A, planned) Leave it. The browser never executes it, and AC4 surfaces the notice.
  - (B) Answer 404 for an unresolved name that has an extension. That amends AD-21 and is ObjectScript work, outside this client-only story.
- **Q2:** whether to charter the named limit's follow-up.

**Size.** One story. If the lead wants a smaller cut, Tasks 7, 8 and 10's second bullet (AC4) can split off. Without them, a stale tab's click to an unvisited screen does nothing visible.

**Rule 2:**

- `buildRoutes`, the maps, `trackRequests` and `rewriteBuildIdentity` are extended in place.
- `recheckBuild` shares `runVerify`'s reader. It is its own method because `reset()` with `verify()` would replace the product surface with the blocking notice.

**Rule 1, Consumes:** the mirror's `builtScreens()`, the Router's `loadComponent`, `/instance`'s `buildIdentity`, and the static handler.

**Rule 1, Consumed-by:** every later page (Epic 18's rest, 20.7-20.11, 20.25-20.27, Epics 21 and 22), one loader line each.

**Rule 3:** the real-runtime evidence is the two Task 10 browser tests.

**Ledger inbox:** this story owns no entry.

- DW-1371 (owner `23-5-…`) is in the same component; this story neither settles nor worsens it.
- DW-1166's policy is applied.

**Gate rulings (lead and orchestrator, 2026-10-12).** AD-5's amendment below is applied to the spine as written.

- **Rule 11: all four asks are pre-authorized** (screen-outlet.ts loaders with one line per page; app.routes.ts's three `push` lines gain `children` plus one import; `angular.json`'s `maximumWarning` and its `angular-json.test.mjs` pin, re-measured at every forward merge as the initial total plus 5%, never taken from either side; the screen-outlet.spec.ts and app.routes.spec.ts assertions). A conflict resolves as a union under Rule 22: a new Epic 18 page becomes a loader entry. All four are footprint extensions.
- **Q1: (A).** The missing chunk keeps its `index.html` answer. The failed navigation must surface as the existing stale-bundle notice after re-reading `/instance`, never as a blank screen, pinned by a browser test that requests a renamed chunk.
- **Q2:** the eagerly built area stores and actions (427,221 bytes) are ledgered as DW-2367, a MED for the Epic 20 burn-down; no story is chartered.
- **The per-lazy-chunk cap** in `build-output.test.mjs` names the chunk and the cap in its failure message.

**Spine, Rule 20.** AD-5 text, as applied at the spec gate:

> **Each built screen's page loads on demand** [AMENDED 2026-10-12, Story 20.29 spec gate, Rule 20].
>
> - Every screen route and id route has one child route whose `loadComponent` is the loader `ScreenOutlet`'s maps name for it. `ScreenOutlet` still decides whether it mounts.
> - No module of the initial bundle imports a page module statically, and a new page is one loader line.
> - `build-output.test.mjs` holds this on the emitted files. It also keeps the initial total under `angular.json`'s warning (about 5% above the measured initial total; 4000 kB is the hard stop) and each lazy chunk under its ceiling.

## Verification

**Shared surfaces:**

- Route table shape (every route gains a child).
- `.ocu-screen-outlet`'s children (a `<router-outlet>` precedes the page).
- The value type of the three maps, and the five specs that read it.
- The emitted file set (chunks).
- The initial budget literal, and the new lazy ceiling.
- `structural-walk.mjs`'s request tracker.
- `about-help-links`' interception helper.
- `InstanceService`'s API.

*Every test added or changed passes on a fresh environment, in either order.*

**Setup after any client change (slot B only):** `cd ui && npm run build && docker exec ocupilot-b-ci sh -c 'cd /durable/iris/csp/ocupilot && rm -rf ./*' && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`.

**Commands.** Run each in the foreground with `timeout: 600000`, one per call. Browser calls carry `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci` inline.

- `cd ui && npm run build -- --verbose` (loop). Expected: the prebuild chain green and the full chunk table.
- `cd ui && npm run test:tools` (loop). Expected: green.
- `cd ui && npm run test:components` (loop). Expected: green.
- `cd ui && node --test --test-concurrency=1 browser/<file>` (loop), one call per file: `lazy-screens`, `shell`, `rail`, `gate`, `switches`, `users`, `screen-height`, `navigate`, `a11y-structural-invariants`. Expected: green.
- `cd ui && node --test --test-concurrency=1 --test-skip-pattern='matches the stamp the installer recorded' browser/about-help-links.browser-spec.mjs` (loop). Expected: green. The skipped test reads the version row, which a `docker cp` does not restamp; the file's other two DW-3 tests run.
- **Lead-owned:**
  - The full ObjectScript sweep; no ObjectScript changes.
  - The smoke.
  - Rule 30's fresh check. It rebuilds the throwaway, so `about-help-links` runs whole.
- **Left to CI:** the full browser suite.

**Mutations to demonstrate** (revert each; `git status --short` and `git diff --stat` unchanged):

- AC1:
  - A static `import` of `MacroLookupPage` used in `panel.ts` → `build-output` red, naming `app-macro-lookup-page`.
  - An `:id` route given the base loader → the `app.routes.spec` child test red, on `UserForm`.
- AC2:
  - `maximumWarning` 1 kB under the measured total → red.
  - `LAZYCHUNKMAX` under the largest chunk → red, naming the chunk.
  - The literal changed in `angular.json` alone → `angular-json.test` red.
- AC3: the rail target's page statically imported → `lazy-screens` red, no new chunk.
- AC4:
  - The `NavigationError` subscription removed → the new `about-help-links` test red.
  - `recheckBuild` made a no-op → the `session.test.mjs` test red.

**Measured (implement stage, throwaway slot B, `npm run build -- --verbose`):**

- Before: initial 3,405,631 bytes in 2 files (`main-XIZQM6QR.js` 3,200,160 plus `styles-GGTH2IYI.css` 205,471); no lazy chunk.
- After: initial 1,896,272 bytes in 20 files (`main-N6R2BVZN.js` 784,236, `styles-GGTH2IYI.css` 205,471 and 18 shared chunks); lazy 127 chunks, 1,662,065 bytes, the largest `chunk-CEWNV5ZR.js` at 83,326 (the data browser page). All files together 3,558,337 bytes, 4.5% above before.
- `maximumWarning` 1992kB: 1,896,272 plus 5% is 1,991,086, rounded up to the next kB. `LAZYCHUNKMAX` 88 kB (88,000 bytes): 83,326 plus 5% is 87,493, rounded up to the next kB. `maximumError` stays 4000kB.
- The builder keeps a small re-export chunk (712 bytes in the probe) for a dynamic `import()` of a module that is also imported statically, so a page made eager still fetches one stub on navigation. The browser spec therefore asserts that a fetched chunk defines the page, not only that a chunk arrived.

Full chunk table, from the final clean build:

```text
Initial chunk files | Names                              |  Raw size | Estimated transfer size
main-N6R2BVZN.js    | main                               | 784.24 kB |               153.43 kB
chunk-CajYbjv5.js   | -                                  | 755.87 kB |               125.11 kB
styles-GGTH2IYI.css | styles                             | 205.47 kB |                18.40 kB
chunk-COd95_cQ.js   | -                                  |  88.92 kB |                22.47 kB
chunk-CM4fNkGs.js   | -                                  |  10.73 kB |                 3.15 kB
chunk-AQyPyEDI.js   | -                                  |   9.59 kB |                 2.90 kB
chunk-u2iImbTr.js   | -                                  |   7.65 kB |                 2.17 kB
chunk-DOZc5T1E.js   | -                                  |   6.41 kB |                 1.67 kB
chunk-e64gN7-t.js   | -                                  |   4.54 kB |                 1.55 kB
chunk-BnIeTlaC.js   | -                                  |   4.01 kB |                 1.14 kB
chunk-Cn5eO2__.js   | -                                  |   3.46 kB |                 1.47 kB
chunk-DrQy8MkQ.js   | -                                  |   3.42 kB |                 1.25 kB
chunk-B2v5NvMw.js   | -                                  |   2.83 kB |                 1.13 kB
chunk-D_awn-uk.js   | -                                  |   2.52 kB |               944 bytes
chunk-D3xd2-jK.js   | -                                  |   2.30 kB |                 1.06 kB
chunk-Cn3xwvnx.js   | -                                  |   1.50 kB |               620 bytes
chunk-C3ajTZbZ.js   | -                                  |   1.02 kB |                 1.02 kB
chunk-5rPYG65F.js   | -                                  | 798 bytes |               798 bytes
chunk-mjGv2hh2.js   | -                                  | 518 bytes |               518 bytes
chunk-CiRvTzrI.js   | -                                  | 491 bytes |               491 bytes

                    | Initial total                      |   1.90 MB |               341.28 kB

Lazy chunk files    | Names                              |  Raw size | Estimated transfer size
chunk-CEWNV5ZR.js   | data-browser-page                  |  83.33 kB |                20.26 kB
chunk-DOrfYN2d.js   | -                                  |  57.89 kB |                13.45 kB
chunk-CEvDnyJf.js   | -                                  |  44.11 kB |                10.07 kB
chunk-CMl3NI7H.js   | -                                  |  38.72 kB |                10.37 kB
chunk-CtIhvciL2.js  | ldap-editor-page                   |  36.18 kB |                 7.60 kB
chunk-DWTutLs02.js  | web-app-editor-page                |  36.01 kB |                 8.21 kB
chunk-DH-e50eD.js   | ssl-form-page                      |  30.52 kB |                 6.61 kB
chunk-DFxK4q-C2.js  | user-editor-page                   |  30.50 kB |                 6.60 kB
chunk-BIRnABky2.js  | routine-app-form-page              |  30.02 kB |                 6.63 kB
chunk-CHyCfxY32.js  | openapi-viewer-page                |  28.30 kB |                 8.45 kB
chunk-H0p20JlZ.js   | wallet-secret-form-page            |  27.82 kB |                 6.20 kB
chunk-BcV9m9y9.js   | definition-form-page               |  26.84 kB |                 5.51 kB
chunk-BQ2fXQK02.js  | service-editor-page                |  26.64 kB |                 7.02 kB
chunk-C6dgezKQ2.js  | -                                  |  26.58 kB |                 5.80 kB
chunk-QR7XP_un.js   | oauth-registered-client-form-page  |  26.02 kB |                 6.50 kB
chunk-5V5bfGAZ.js   | -                                  |  25.82 kB |                 6.86 kB
chunk-BkjtXska2.js  | oauth-server-form-page             |  25.39 kB |                 6.25 kB
chunk-8xhMopm5.js   | oauth-resource-server-form-page    |  25.03 kB |                 6.46 kB
chunk-BCFqigU7.js   | role-editor-page                   |  23.99 kB |                 5.91 kB
chunk-DXhHNn912.js  | home-page                          |  23.71 kB |                 6.30 kB
chunk-BfAOzNIF.js   | oauth-client-form-page             |  23.54 kB |                 6.02 kB
chunk-GPnatEUa.js   | auditing-config-page               |  22.61 kB |                 6.17 kB
chunk-Caq1lHQ0.js   | -                                  |  20.85 kB |                 5.05 kB
chunk-DQE3FhCF2.js  | error-log-page                     |  19.86 kB |                 5.52 kB
chunk-BDFqUgnL2.js  | switches-page                      |  19.43 kB |                 4.74 kB
chunk-BaO2Wx_D.js   | superserver-form-page              |  19.40 kB |                 4.46 kB
chunk-C9Za4S8S2.js  | encryption-key-file-page           |  19.19 kB |                 4.29 kB
chunk-XFAyHFLC2.js  | database-editor-page               |  19.13 kB |                 4.95 kB
chunk-B8kFtQBs2.js  | oauth-server-description-form-page |  19.10 kB |                 4.87 kB
chunk-H3EswGsv.js   | create-form-page                   |  18.95 kB |                 4.13 kB
chunk-CNCXb-AD2.js  | encryption-startup-page            |  18.84 kB |                 4.73 kB
chunk-CPilPIMY2.js  | -                                  |  18.51 kB |                 4.46 kB
chunk-DKD6a45R2.js  | log-hub-page                       |  16.98 kB |                 4.63 kB
chunk-C1goaWUZ.js   | x509-form-page                     |  16.63 kB |                 3.98 kB
chunk-D5nUYrX5.js   | auth-options-page                  |  16.55 kB |                 4.11 kB
chunk-DGefTT42.js   | code-list-page                     |  16.39 kB |                 4.71 kB
chunk-C_7LwYRF.js   | log-viewer-page                    |  15.99 kB |                 4.62 kB
chunk-De7Ew__A2.js  | language-server-form-page          |  15.66 kB |                 4.17 kB
chunk-UX6lFPdp.js   | user-create-form-page              |  15.60 kB |                 3.84 kB
chunk-CO7lVpUH2.js  | device-form-page                   |  15.29 kB |                 3.71 kB
chunk-WvOMmh-n.js   | database-details-page              |  15.25 kB |                 4.19 kB
chunk-DbP7R3L72.js  | -                                  |  14.51 kB |                 4.04 kB
chunk-BO5YtEkH2.js  | journal-settings-page              |  13.89 kB |                 3.69 kB
chunk-OKaaGmtx.js   | document-viewer-page               |  13.82 kB |                 3.85 kB
chunk-BUGvoe0y.js   | mft-connection-form-page           |  13.58 kB |                 3.53 kB
chunk-LCrTFqRf2.js  | ledger-page                        |  13.21 kB |                 3.55 kB
chunk-DDzkCACu2.js  | license-key-page                   |  13.19 kB |                 4.01 kB
chunk-CRdnQx0y2.js  | interop-item-list-page             |  13.07 kB |                 3.41 kB
chunk-C9iJjkuA2.js  | docdb-app-form-page                |  12.57 kB |                 3.41 kB
chunk-CksvS5yv.js   | sql-query-page                     |  12.23 kB |                 3.31 kB
chunk-B2RGJ3Lf.js   | remote-database-form-page          |  12.22 kB |                 3.38 kB
chunk-CP3Oiy1e.js   | role-create-form-page              |  12.20 kB |                 3.33 kB
chunk-BtNiNJYx.js   | dashboard-page                     |  12.06 kB |                 3.73 kB
chunk-CNQ1jSKi2.js  | interop-item-test-page             |  12.04 kB |                 3.76 kB
chunk-C0qrULZj2.js  | encryption-keys-page               |  11.73 kB |                 3.47 kB
chunk-BpgPsFba.js   | encryption-key-file-form-page      |  11.65 kB |                 3.30 kB
chunk-C9R6OCzG.js   | journal-records-page               |  11.53 kB |                 3.71 kB
chunk-DtDthUln2.js  | -                                  |  11.47 kB |                 3.54 kB
chunk-CdaWH5yW.js   | governance-page                    |  11.20 kB |                 3.54 kB
chunk-B0YN9sMX2.js  | mapping-form-page                  |  10.99 kB |                 3.27 kB
chunk-rBC9bAlF2.js  | ecp-data-server-form-page          |  10.91 kB |                 3.21 kB
chunk-BDD3dfBh.js   | resource-list-page                 |  10.66 kB |                 3.24 kB
chunk-C3isy05-.js   | database-integrity-page            |  10.62 kB |                 2.99 kB
chunk-DS3qhPXJ2.js  | ecp-settings-page                  |  10.57 kB |                 3.09 kB
chunk-BIy4IuuZ.js   | license-server-form-page           |  10.08 kB |                 2.95 kB
chunk-Cj4fNLgi2.js  | rest-api-list-page                 |   9.44 kB |                 3.01 kB
chunk-CRjoI6bj2.js  | task-schedule-page                 |   9.39 kB |                 2.60 kB
chunk-DHBsJzg5.js   | screen-permissions-page            |   9.23 kB |                 3.02 kB
chunk-D80p_RPq2.js  | -                                  |   9.16 kB |                 2.78 kB
chunk-BixChdcl.js   | audit-user-event-list-page         |   9.15 kB |                 2.99 kB
chunk-DtQnnyJw2.js  | code-search-page                   |   8.90 kB |                 2.83 kB
chunk-BfPXmff-.js   | lock-list-page                     |   8.87 kB |                 3.10 kB
chunk-Dy56EG0a.js   | history-page                       |   8.74 kB |                 2.86 kB
chunk-BZJ9XnnG.js   | ecp-data-server-list-page          |   8.58 kB |                 3.09 kB
chunk-BjM8qbTz2.js  | -                                  |   8.53 kB |                 2.13 kB
chunk-6YvMF68i.js   | journal-file-details-page          |   8.52 kB |                 2.68 kB
chunk-BsXmv2lJ2.js  | audit-page                         |   8.29 kB |                 2.69 kB
chunk-CvBq-spm.js   | task-editor-page                   |   7.86 kB |                 2.73 kB
chunk-CSlNH6UH.js   | process-details-page               |   7.81 kB |                 2.69 kB
chunk-CEeSn9Vg2.js  | interop-lookup-table-list-page     |   7.79 kB |                 2.55 kB
chunk-BTB1vSqP.js   | -                                  |   7.78 kB |                 2.33 kB
chunk-Bh-5gYyV.js   | -                                  |   7.74 kB |                 2.35 kB
chunk-Bm7cCO0p.js   | docdb-list-page                    |   7.53 kB |                 2.62 kB
chunk-CKhdVxdV.js   | source-editor-page                 |   7.39 kB |                 2.37 kB
chunk-ByygOlrc.js   | details-page                       |   7.36 kB |                 2.40 kB
chunk-PEnfNVrh2.js  | code-compare-page                  |   7.24 kB |                 2.51 kB
chunk-K4WicjpD.js   | macro-lookup-page                  |   7.21 kB |                 2.37 kB
chunk-DJHyutgU.js   | transcript-page                    |   7.05 kB |                 2.55 kB
chunk-CzJEqHbu2.js  | namespace-list-page                |   7.03 kB |                 2.43 kB
chunk-BGugQ-0Y.js   | -                                  |   7.00 kB |                 2.00 kB
chunk-Dvc1OgBX2.js  | -                                  |   6.77 kB |                 2.28 kB
chunk-938okQbI.js   | -                                  |   6.11 kB |                 1.90 kB
chunk-Cqykk1KF2.js  | -                                  |   5.63 kB |                 2.03 kB
chunk-D41Q742a2.js  | -                                  |   5.49 kB |                 1.97 kB
chunk-DFMabAFe.js   | guardrails-page                    |   5.38 kB |                 1.57 kB
chunk-DPF5Mdoa.js   | upcoming-page                      |   5.33 kB |                 2.02 kB
chunk-aQ9CUbYz.js   | -                                  |   5.32 kB |                 1.54 kB
chunk-D62cgApE2.js  | statistics-page                    |   4.79 kB |                 1.82 kB
chunk-BTP-d4RS.js   | interop-lookup-entry-list-page     |   4.45 kB |                 1.65 kB
chunk-BgeK9NeB.js   | -                                  |   4.16 kB |                 1.31 kB
chunk-DC9OWDOJ2.js  | databases-page                     |   3.94 kB |                 1.57 kB
chunk-VivL8kX4.js   | -                                  |   3.90 kB |                 1.49 kB
chunk--KJS5JFr.js   | -                                  |   3.90 kB |                 1.24 kB
chunk-a-8-tYbQ2.js  | system-usage-page                  |   3.86 kB |                 1.51 kB
chunk-D1yd10Oa.js   | -                                  |   3.79 kB |                 1.45 kB
chunk-IzlYZB_g.js   | interop-item-setting-list-page     |   3.54 kB |                 1.41 kB
chunk-BjlGjMN-.js   | -                                  |   3.52 kB |                 1.23 kB
chunk-i5H3JECK2.js  | -                                  |   3.40 kB |                 1.45 kB
chunk-cTASlCha2.js  | journal-list-page                  |   3.35 kB |                 1.39 kB
chunk-ML4hoQKd.js   | -                                  |   3.02 kB |                 1.17 kB
chunk-kRZMzViD.js   | -                                  |   2.92 kB |                 1.27 kB
chunk-B4gXiKcw.js   | -                                  |   2.74 kB |                 1.21 kB
chunk-CVj-RnxC.js   | -                                  |   2.24 kB |               834 bytes
chunk-CEx_vTaT2.js  | -                                  |   2.23 kB |               871 bytes
chunk-DpLatsBk.js   | -                                  |   2.19 kB |               778 bytes
chunk-Cxl7vbeb.js   | -                                  |   1.79 kB |               710 bytes
chunk-Bos_o6J0.js   | -                                  |   1.62 kB |               575 bytes
chunk-CzXcRE1Z.js   | -                                  |   1.19 kB |               599 bytes
chunk-BvnNVIkq.js   | -                                  | 774 bytes |               774 bytes
chunk-9mhWIi6Y2.js  | detail-page                        | 709 bytes |               709 bytes
chunk-D5ng8cxb.js   | list-page                          | 657 bytes |               657 bytes
chunk-DpxR9KBn.js   | -                                  | 564 bytes |               564 bytes
chunk-mCMvf1_o.js   | -                                  | 471 bytes |               471 bytes
chunk-CaeAZQRC2.js  | database-wizard-page               | 470 bytes |               470 bytes
chunk-DJyeq0-y.js   | task-wizard-page                   | 413 bytes |               413 bytes
chunk-B8NmImio.js   | -                                  | 368 bytes |               368 bytes
chunk-DHotihUu2.js  | namespace-form-page                | 312 bytes |               312 bytes
```

**Results:**

- `npm run build -- --verbose`: the seven-checker prebuild chain green, then the table above.
- `npm run test:tools`: 1947 of 1947. `npm run test:components`: 239 files, 2978 tests, all green.
- Browser, one file per call on `ocupilot-b-ci` with the clean bundle: `lazy-screens` 1 of 1; `about-help-links` 6 of 6 with the stamp test skipped as the command above says; `shell` 6; `rail` 2; `gate` 6; `switches` 4; `users` 4; `screen-height` 15; `navigate` 6; `a11y-structural-invariants` 13 (the screen walk 335.8 s).

**Mutations observed** (each applied, red observed, reverted with the tree byte-identical by a diff-plus-untracked checksum; the client ones on a rebuilt and redeployed bundle, and the clean bundle rebuilt and redeployed after):

- mutation: AC1, `MacroLookupPage` imported in `shell/panel.ts` and used -> `build-output.test.mjs` page placement red, naming `app-macro-lookup-page` defined in the initial `main-4VRBITYV.js`.
- mutation: AC1, `<app-toast-host />` wrapped in `@defer` in `app.ts` -> chrome placement red, naming `app-toast-host`.
- mutation: AC1, every `:id` route given the base loader -> `app.routes.spec.ts` two tests red (the shipped-route test on `LocalDatabaseForm`, the first screen with an edit page, and the fixture test on `UserForm`).
- mutation: AC1, the root push without `children` -> four tests red across `app.routes.spec.ts` and `screen-outlet.spec.ts`.
- mutation: AC1, one loader made to resolve to nothing -> `screen-outlet.spec.ts` "every loader in the three maps resolves to a component" red, naming `DESCRIPTOR_PAGES[OcuPilot.Screen.Descriptor.SslForm]`.
- mutation: AC2, `maximumWarning` 1895kB -> `build-output.test.mjs` DW-371 red (1,896,272 bytes against 1,895,000).
- mutation: AC2, `LAZYCHUNKMAX` 80,000 -> the lazy-chunk test red, naming `chunk-CEWNV5ZR.js is 83326 bytes` and the cap.
- mutation: AC2, the literal changed in `angular.json` alone (1895kB) -> `angular-json.test.mjs` red (`'1895kB' !== '1992kB'`).
- mutation: AC3, `ListPage` imported in `shell/panel.ts` and used, bundle rebuilt and redeployed -> `lazy-screens` red: the click fetched only the 712-byte stub `chunk-DMl14oHr2.js`, which defines no page. The first version of the spec, asserting only that a chunk arrived, stayed green here, so the page-definition assertion was added.
- mutation: AC4, the `NavigationError` subscription removed from `stale-bundle-notice.ts` -> `stale-bundle-notice.spec.ts` two of eight red, and with the bundle rebuilt and redeployed the new `about-help-links` test red (timed out waiting for the notice).
- mutation: AC4, `recheckBuild` made a no-op -> `session.test.mjs` two tests red; its `settled` guard dropped -> the "before a verify" test red; its single-flight dropped -> the single-flight test red; its generation check dropped -> the "after a reset" test red; `instanceName` replaced as well -> the "moves nothing else" test red.
- mutation: AC4, the `stale` getter returning `false` -> `stale-bundle-notice.spec.ts` four of eight red; `chooseReload` a no-op -> one red.
- mutation: AC1 (review pass), `ExplorerMacro`'s loader written as `() => Promise.resolve(MacroLookupPage)` over a static import in `screen-outlet.ts` -> `build-output.test.mjs` page placement red, found through the page module on disk (the loader line no longer matches the loader pattern).
- mutation: AC1 (review pass), `this.screen() === null ||` dropped from `ScreenOutlet.page` -> `screen-outlet.spec.ts` "an unknown URL renders no page" red alone (the test's wildcard now carries a child that would mount Home's page).
- mutation: AC3 (review pass), `try { new Function('return 1')(); } catch {}` added to `ListPage`'s constructor, bundle rebuilt and redeployed -> `lazy-screens` red on "no content-security-policy violation fired" (`script-src eval`, twice), every earlier assertion green; the clean bundle (`main-N6R2BVZN.js`) was rebuilt and redeployed after.
- mutation: AC4 (review pass), the `onDestroy` unsubscribe removed from `stale-bundle-notice.ts` -> `stale-bundle-notice.spec.ts` "stops listening to the router when it is destroyed" red, one of eight.

**QA stage (2026-10-12).** No new file; two browser specs extended (QA):

- `ui/browser/lazy-screens.browser-spec.mjs` (QA): two tests, a full page load at the Users list's URL and at the Users editor's id route (`/ocupilot/permissions/users/edit/<account>`). Each signs in on a fresh context with chunk and policy watchers attached before the first request, and asserts a chunk outside the initial set (the static-import closure of `index.html`, read from the instance) defines the page, every chunk is 200 / JavaScript / immutable, no `securitypolicyviolation`, and no console error about a file under `/ocupilot/`. The id route also asserts the edit page, not the base create form, is what renders. Shared assertions became `assertServedAsModules` and `assertDefinesPage`.
- `ui/browser/about-help-links.browser-spec.mjs` (QA): the AC4 test now requests a renamed chunk (`chunk-RENAMEDBYREINSTALL.js`) and the page gets the instance's own answer for it, recorded and asserted not to be JavaScript, instead of a hand-built copy of the shell document; it also asserts the click did ask for a chunk.
- Rows checked against a pinning test that can fail: cold deep link (new), in-app navigation (`lazy-screens`), denied or held (`screen-outlet.spec.ts`, `app.gate-outlet.wire.spec.ts`), unknown URL (`screen-outlet.spec.ts`, `app.routes.spec.ts`), stale tab (`about-help-links`, `session.test.mjs`, `stale-bundle-notice.spec.ts`), eager page and growth (`build-output.test.mjs`). The seven prebuild checkers pass run one by one (`screen-mirror` mirrored 185 descriptors).
- mutation (QA): AC1/AC3 cold id route, every `:id` route given the base loader in `buildRoutes`, bundle rebuilt and redeployed -> `lazy-screens` id-route test red alone ("none of [...] defines app-user-editor-page"); the list tests stay green.
- mutation (QA): AC3 cold list, the base-route push in `buildRoutes` loses `...page` -> the cold list test and the in-app test red (30 s timeout, no page mounts), the id-route test green.
- mutation (QA): AC4 renamed chunk, `recheckBuild()` no longer called on `NavigationError` in `stale-bundle-notice.ts` -> the reworked `about-help-links` AC4 test red alone (`.ocu-stale-bundle` never appears).
- mutation (QA): I/O "held", `this.shell.screenHeld()` dropped from `ScreenOutlet.page` -> `app.gate-outlet.wire.spec.ts` "holds the requested screen off the outlet" red (one read issued), `screen-outlet.spec.ts` green. I/O "denied", `this.allowed()` dropped -> "a denied screen renders the refusal in place of its page" red. I/O "map unanswered", `answered()` dropped -> two `screen-outlet.spec.ts` tests red.
- After each client mutation the file was restored and the bundle rebuilt: `main-N6R2BVZN.js` again, redeployed to `ocupilot-b-ci`; `git status` shows only the two specs above and this spec.
- Runs on the clean bundle: `lazy-screens` 3 of 3 (twice), `about-help-links` 6 of 6 with the stamp test skipped as the command above says, `npm run test:tools` 1947 of 1947.

**Code review (2026-10-12).** Each mutation was applied, observed red and reverted. The working tree was confirmed identical afterwards.

- mutation (review): AC3 console clause. `console.error('ocupilot console probe')` was added to `ListPage`'s constructor, and the bundle was rebuilt and redeployed (`main-N3XTLVUK.js`). Result: `lazy-screens`' in-app test and its cold list test went red on "nothing was logged as a console error from the shell", with the policy assertion before it green. The id-route test stayed green. The clean `main-N6R2BVZN.js` was rebuilt and redeployed afterwards.
- mutation (review): AC4. `runRecheck` was made to also copy `serverFlag`, so "recheckBuild ... moves nothing else" went red on the field roster. A second mutation, `runRecheck` setting the status from the re-read's version, turned the same test red.
- mutation (review): AC1. The SSL form's loader was made to resolve to its store class `SslForm`, so "every loader in the three maps resolves to a component" went red, naming `DESCRIPTOR_PAGES[OcuPilot.Screen.Descriptor.SslForm]`.
- mutation (review): AC1. `buildRoutes` was made to skip a screen no loader names, so the fixture test went red on "a screen with no page still has its route".
- Runs after the review patches:
  - `npm run test:tools`: 1947 of 1947, and the build still emits `main-N6R2BVZN.js`.
  - `screen-outlet.spec.ts` and `app.routes.spec.ts`: 34 of 34.
  - On the clean bundle: `lazy-screens` 3 of 3, and `about-help-links` 6 of 6 with the stamp test skipped.

**CI rework 1 (2026-10-12), work in progress (hold).** Clean bundle `main-4FXQL74C.js` is on `ocupilot-b-ci`; the initial total stays under 1992kB. Green on it so far: `npm run test:tools` 1954, `npm run test:components` 2986, and the browser files `oauth` 6, `language-server-editor` 4, `lazy-screens` 3, `about-help-links` 6, `navigate` 6, `shell` 6, `rail` 2, `gate` 6, `a11y-structural-invariants` 13. Not yet run: `auditing-screen`, `definitions`, `users-editor`, `interop-host-tabs`, `system-explorer-sql`, `license-usage`, `ecp-application-servers`, and the create-then-edit specs (`ldap-editor`, `namespaces`, `oauth-client-editor`). The review step (step 4) has not run. Each mutation below was applied, observed red and reverted, the tree confirmed byte-identical; the client ones on a rebuilt and redeployed bundle, and the clean bundle rebuilt and redeployed after.

- mutation: ready, `rememberedPage` returns its loader unwrapped, bundle rebuilt and redeployed -> `language-server-editor` test 1 red at the Cancel click ("No element found", 2 of 2 with the form read held 300 ms); `app.routes.spec.ts` "is answered at once, to every route that shares its loader" and "lets the router commit the next navigation to it before the next task" red together.

- mutation: focus, `DetailPage.open` returned to the single module-level route string cleared by any `false` answer, bundle rebuilt and redeployed -> `oauth.browser-spec.mjs` test 1 red with the CI message (`'BODY'` against `'security/oauth/clients'`); the component test "a tab opened twice before the router answers" red alone.
- mutation: focus, `forget` dropped from the `false` branch -> "a tab whose navigation the router refuses leaves no focus request" red alone.
- mutation: ready, the static `aria-busy` dropped from `ScreenOutlet`'s host, bundle rebuilt and redeployed -> `lazy-screens` in-app test red, three outlets recorded ready without a page; the `screen-outlet.spec.ts` test "reads busy from the moment the router creates it" red alone.
- mutation: ready, `pageRendered` set in `onPageActivated` instead of after the next render -> "still reads busy when the page it routed renders for the first time" red alone.
- mutation: ready, `this.page` dropped from `busyValue` -> "is not left busy by a screen that mounts no page" red alone; `this.pageRouted` dropped -> "is not left busy by a route that carries no page" red alone.
- Runs on the final bundle: `npm run test:tools` 1954 of 1954; `npm run test:components` 239 files, 2984 tests; browser files as listed under item 3, all green (`a11y-structural-invariants` 13, the screen walk 337 s; `oauth` 6; `language-server-editor` 4; `lazy-screens` 3; `about-help-links` 6; `navigate` 6; `shell` 6; `rail` 2; `gate` 6).

## Auto Run Result

Status: done
Blocking condition: none

**Summary.** Every screen's page now loads on demand. `ScreenOutlet`'s three maps hold loaders, each screen route and `:id` route has one `''` child whose `loadComponent` is the loader the maps name (the edit page first on an `:id` route), and the outlet renders `<router-outlet />` under the same mount decision. A signed-in tab whose navigation fails re-reads `/instance` through the new `InstanceService.recheckBuild()`, so the existing stale-bundle notice explains it.

**Measured.** Initial 3,405,631 bytes in 2 files before; 1,896,272 bytes in 20 files after. Lazy: 127 chunks, 1,662,065 bytes, largest 83,326 (`chunk-CEWNV5ZR.js`, the data browser page). `maximumWarning` 1992kB, `LAZYCHUNKMAX` 88 kB, `maximumError` 4000kB. The full chunk table is under `## Verification`.

**Files changed.**

- `ui/src/app/shell/screen-outlet.ts`: loaders in place of 89 page imports; the page slot is a router outlet.
- `ui/src/app/app.routes.ts`: the page child on every screen route.
- `ui/src/app/core/instance.ts`, `ui/src/app/shell/stale-bundle-notice.ts`: `recheckBuild()` and its `NavigationError` cue.
- `ui/src/app/areas/security/auditing-config.store.ts`, `auditing-config.page.ts`, `shell/panel.ts`: `AUDITING_FOCUS_ENABLE` moved to the store so the panel imports no page.
- `ui/angular.json`, `ui/tools/angular-json.test.mjs`: `maximumWarning` re-based to 1992kB.
- `ui/tools/build-output.test.mjs`: initial and lazy sets, the lazy ceiling, page placement, chrome placement.
- `ui/tools/session.test.mjs`, `stale-bundle-notice.spec.ts`, `screen-outlet.spec.ts`, `app.routes.spec.ts`, four map-comparing specs: the matching tests.
- `ui/browser/lazy-screens.browser-spec.mjs` (new), `about-help-links.browser-spec.mjs`, `structural-walk.mjs`: the browser evidence.

**Review.** Two layers ran (verification-gap, intent-alignment; the project turns the other two off): 20 findings, none high. Patched: 2 medium entries (the page-placement blind spot, now found through the page modules on disk, with the loader-pattern finding grouped into it; the unfalsifiable unknown-URL test) and 4 lows (a tautological assertion, a coverage assertion true by construction, two missing mutation lines). Deferred: 1 low (`_components.scss` comments). Rejected: 12, each with its reason in the triage log. Follow-up review recommended: false; the patches are test-only and each was exercised by a demonstrated mutation.

**Verification.** `npm run build -- --verbose` green with the seven-checker prebuild chain. `npm run test:tools` 1947 of 1947 and `npm run test:components` 239 files, 2978 tests, after the review patches. Browser, one file per call on `ocupilot-b-ci`: `lazy-screens` 1, `about-help-links` 6 (stamp test skipped as specified), `shell` 6, `rail` 2, `gate` 6, `switches` 4, `users` 4, `screen-height` 15, `navigate` 6, `a11y-structural-invariants` 13. The throwaway serves the clean bundle `main-N6R2BVZN.js`. Mutations are under `## Verification`.

**Residual risks.**

- A failed navigation also rejects `navigateByUrl` unhandled, as the router does by default, so a stale tab logs a console error beside the notice.
- The area stores and actions `app.ts` constructs (427,221 bytes) stay in the initial bundle (DW-2367).
- The page-placement gate treats every `*.page.ts` as a routed page; a future non-routed component in such a file would redden it, and the failure message says which selector.
