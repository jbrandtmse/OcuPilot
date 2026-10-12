---
title: 'Story 20.29: Screens load on demand'
type: 'feature'
created: '2026-10-12'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: [oversized]
deferred: []
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

## Spec Change Log

## Review Triage Log

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

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
