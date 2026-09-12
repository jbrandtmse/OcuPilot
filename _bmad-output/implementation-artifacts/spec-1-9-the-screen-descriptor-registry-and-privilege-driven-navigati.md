---
title: 'Story 1.9: The screen descriptor registry and privilege-driven navigation'
type: 'feature'
created: '2026-09-12'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-1-8-instance-identity-and-the-api-version-guard.md'
  - '{project-root}/.claude/rules/objectscript-testing.md'
warnings: ['oversized']
deferred:
  - summary: >-
      EXPERIENCE.md's Fixed strings table carries no row for the eight area names, though the
      rail, the `<Area>` tooltip substitution, the side-bar landmark name and eyebrow, the
      area tile and the locator bar are all made of them. This story sources them by
      extracting EXPERIENCE.md:64; the lead should add the table row so the extraction does
      not become a second authority.
    evidence: |-
      Read directly 2026-09-12: EXPERIENCE.md:252-303 holds no row naming an area.
      EXPERIENCE.md:64 (Information Architecture) enumerates all eight verbatim, and :297's
      canonical string carries the `<Area>` placeholder they resolve. Amending a planning
      artifact is the lead's (Rule 5).
    location: 'EXPERIENCE.md Fixed strings table (:252-303); ui/tools/strings.test.mjs'
    severity: medium
  - summary: >-
      AD-44 says the classic portal "keys custom page resources by normalized page URL". The
      live API keys them by normalized **class name**: `%SYS.Portal.Resources`' IdKey `Page`
      is a class name, and `NormalizePage` exists to turn a URL into one. The AD's wording
      should be sharpened so a later descriptor author does not declare a URL as the key.
    evidence: |-
      irissys/%SYS/Portal/Resources.cls:97-164 (`NormalizePage`, doc "Normalize a CSP or Zen
      link to the underlying class name"); :288 the `List` query with ROWSPEC Page/Resource.
      Confirmed live: `%GetCustomResource("%CSP.UI.Portal.Mappings")` = "" and the store holds
      0 rows. Amending an AD is the lead's (Rule 5, Rule 20).
    location: 'ARCHITECTURE-SPINE.md AD-44; src/OcuPilot/Screen/Gate.cls'
    severity: medium
  - summary: >-
      DESIGN.md and EXPERIENCE.md disagree on whether the two blocking notices carry a banner.
      This touches Story 1.8's shipped `instance-notice`, not only this story's gated
      appearance, so it wants one ruling rather than a per-story reading.
    evidence: |-
      DESIGN.md:1066 "Both render as an `empty-state` ... Neither is a banner"; EXPERIENCE.md
      :348, :428, :429 "empty-state shape with a banner (error)". EXPERIENCE.md:35's
      precedence rule does not settle it: appearance is DESIGN's, component pattern is
      EXPERIENCE's, and this is both.
    location: 'DESIGN.md:1066; EXPERIENCE.md:348, :428, :429; ui/src/app/shell/instance-notice.ts'
    severity: low
  - summary: >-
      The Fixed strings table has no permission-denied row. This story renders the deep-linked
      gated screen with the canonical `Requires <resource>` string resolved to the failed pair,
      which satisfies the AC with an authorized literal but is thinner than EXPERIENCE.md:220's
      "the permission-denied message" implies.
    evidence: |-
      EXPERIENCE.md:220 and :431 describe the behaviour but name no string; :234 and :437 spell
      sentences the table's own rule (:248) calls illustrations. Authoring product copy is the
      owner's call.
    location: 'EXPERIENCE.md:220, :431; ui/src/app/shell/screen-denied.ts'
    severity: low
---

<intent-contract>

## Intent

**Problem:** `app.routes.ts` and `shell/deep-link.ts` are Story 1.5's placeholder — four routes onto one
component that renders four data attributes — and both name this story as their replacement. There is no
descriptor, no registry, no navigation, and no privilege gate finer than `Router.cls`'s one
`HoldsAdminResource()` boolean. Every screen in Epics 2-22 resolves its route, nav entry, gate, tools,
change-event key and classic link through a mechanism that does not exist yet.

**Approach:** Declare a screen once, in a hand-written ObjectScript class carrying a JSON `XData`, and
resolve the route table, the navigation entry and the privilege gate through it. The server evaluates
`(resource, permission)` pair sets in the calling process and serves a navigation map; the client mirrors
the declarations as generated TypeScript, builds its route table from them, and renders the rail and side
bar with gated entries that stay reachable. Three routed ledger items close here.

## Boundaries & Constraints

**Always:**

- One declaration per screen (AD-5): route, area, side-bar position, archetype, privilege set, entity-type
  key and scope, id accessor, context serializer with its secret-typed field list, actions, empty-state
  text, command-box aliases, and the classic page it replaces. Adding a screen never edits a router or a
  nav list.
- Privilege is a **set** of `(resource, permission)` pairs, all required, evaluated in the calling process
  at call time and never cached (AD-8). A denial names the pair that failed.
- Entity-type keys come from one closed kernel enum (AD-14); an unknown value fails the build.
- The client mirror is a **checked-in generated artifact** derived from the same `XData` the server reads —
  never runtime reflection, never a second hand-written source (AD-3's rule applied to AD-5).
- `ui/src/app/core/` stays framework-free so `node --test` executes it: the registry, the gate view and the
  preference store import no `@angular/*` symbol. The descriptor→`Routes` adapter lives outside `core/`.
- Gated entries are `aria-disabled="true"`, never `disabled`, never hidden, and keep their place in the Tab
  and arrow order (EXPERIENCE.md:214).
- Every user-facing word from `strings.ts`; every colour from an existing `--ocu-*` token; every geometry
  from `_metrics.scss`, which already declares `--ocu-rail-width` and `--ocu-side-bar-width`.
- No real account is created, modified, locked or expired, and no browser session this story did not mint
  is ever ended. Denial tests mint throwaway principals and remove them in teardown.

**Never:**

- No second response writer, no second envelope field, no second install gate, no namespace switch for the
  classic-resource read (`%CSP.Portal.Utils` is `%`-mapped; verified live from `HSCUSTOM`).
- No command box, no header, no status bar, no locator bar, no area tile, no Home page content — 1.10 and
  1.12 own those. This story delivers the gated-entry contract and applies it to the rail and side bar
  only; the two surfaces EXPERIENCE.md:214 names that do not exist yet apply it when they land.
- No area screen is built here. The six areas' first screens are Epic 2's, so every area side bar is empty
  at the end of Epic 1.
- No read tool, no write tool, no change-event bus, no auto-refresh timer. The descriptor **declares** the
  fields those consume; nothing consumes them yet.
- No `disabled` attribute, no hidden entry, no `opacity` fade on gated copy (DESIGN.md:1265).
- No AD-21 amendment: the `..` refusal stays literal and the codec stops emitting one.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Navigation map | Signed-in caller with some admin resources | 200 carrying every area and built screen, each with `allowed` and, when denied, the failed `(resource, permission)` pair | Envelope through the one writer; never a partial list |
| Gated rail entry | Caller lacks an area's pair set | The entry stays listed, focusable and `aria-disabled="true"`, tooltip on hover **and** focus reading `Requires <pair>` | Never hidden, never `disabled` |
| Deep link to a gated route | `/ocupilot/permissions/users` with no `%Admin_Secure:U` | The screen renders its title and the permission-denied message naming the pair; rail, side bar and the rest of the shell keep working | Not an `empty-state`, not a banner (EXPERIENCE.md:348) |
| Dotted entity id (**DW-97**) | Id `a..b` in a deep link | The codec emits `a%252E%252Eb`; `StaticHandler` sees no literal `..` and serves `index.html`; the SPA decodes back to `a..b` | The literal-`..` refusal is untouched and still answers 400 for a hand-typed path |
| Privileges change after load (**DW-9**) | A role is revoked after the nav map was fetched | Any 403 from any API call re-reads the map; the server recomputes from live state on every call | Stale gating corrects itself without a reload |
| Classic page carries a custom resource | Operator assigned a resource to the page a screen replaces | The pair set is the union of the declared set and that resource at `U` | Absent assignment reads `""` and adds nothing |
| Unknown entity type | A descriptor names a value not in the kernel enum | `check-objectscript.py` fails and the mirror generator refuses to emit | Named file, named value — never a silent skip |
| Area with no built screens | Every area, at the end of Epic 1 | The rail entry works and opens an empty side bar; no dead entries | No invented empty-state string |
| Unknown route | `/ocupilot/nope/nope` | The shell renders its not-found screen; the rail and side bar keep working | No redirect, no blank page |

</intent-contract>

## Code Map

**Extend, never duplicate.** Anchors verified 2026-09-12 against the working tree and the live instance.

- `src/OcuPilot/Api/Router.cls` (235) — `UrlMap` holds **one** route `:59`; ordering invariants `:41-55`;
  `ADMINRESOURCES` (thirteen) `:39`; `OnPreDispatch` `:152-198` (install `:157`, anonymous `:174`,
  `AUTH.NOADMIN` `:181`, `?ns=` `:187`); `HoldsAdminResource` `:100-112` holds the tree's **only**
  `$System.Security.Check` call site `:106`; `Call=` idiom `:63-68`; test seams `:76-79`, `:89-92`.
- `src/OcuPilot/Api/Error.cls` — 12-slug enum `:20-54`; declared `code` parameters `:59-90` (`forbidden`
  and `not_found` exist; **no code for a per-screen denial** — add one, `STATIC.*`'s two-line precedent).
  `Render` `:105-131` refuses an empty code `:113-116`. `Api/Response.cls` — `JSON` `:13-22`.
- `src/OcuPilot/Kernel/EntityId.cls` (58) — `Encode` `:36-38`, `PercentEncode` `:43-45`, `Decode` `:53-55`.
  Verified live: `$ZConvert("a.b","O","URL")` leaves the dot, `$ZConvert("a%2Eb","I","URL")` returns `a.b`,
  so **only the encode side changes**.
- `src/OcuPilot/Api/StaticHandler.cls` (421) — literal `..` refusal `:158`, containment `:178`/`:198-203`,
  400 `STATIC.BADPATH` `:216-217`. Probed live: `a%252E%252Eb` → 200 `index.html`; `a%2E%2Eb` → 400;
  `a..b` → 400. The hop decodes the segment exactly once and does no dot-segment normalization.
- `src/OcuPilot/Port/AdminPort.cls` — `%Dictionary.XDataDefinition.IDKEYOpen` `:81`, the XData-read idiom.
  `src/OcuPilot/Test/AdminInventory.cls:117` — `SELECT Name FROM %Dictionary.CompiledClass WHERE Name
  %STARTSWITH ?`, the registry-scan idiom; `Regenerate()` + a drift test is the generated-artifact pattern.
- `irissys/%CSP/Portal/Utils.cls:195-207` — `%GetCustomResource(<URL-encoded class name>)`, `""` when none,
  not `Internal`, no privilege guard on the read. Union semantics read directly: `%ZEN/Controller.cls:34-62`
  gates the page's own `RESOURCE` **then** the custom resource; `%CSP/Portal/Utils.cls:430-435` appends it.
  Permission checked is `"USE"` (`Controller.cls:56`). `%SYS/Portal/Resources.cls:97-164` `NormalizePage`
  (query and fragment stripped, one percent-decode, `.cls`/`.zen` dropped, leading `_`→`%`, **no case
  folding for a class**), `:288` the `List` query. Live: store holds 0 rows; no namespace switch needed.
- `ui/src/app/app.routes.ts` (20) — the four-entry placeholder `:15-20`, its own header naming this story
  `:12-13`. `ui/src/app/shell/deep-link.ts` (54) — `:22-32` renders one empty div with four data
  attributes; `decodeEntityId` at `:48-51` is the single client decode point. Both are replaced.
- `ui/src/app/app.ts` (113) — template `:46-56`, `<router-outlet />` nested inside `@if (signedIn)` →
  `@if (instanceReady)` `:50`; paren-free getters `:89-95`. **`session.test.mjs:1631-1712` brace-matches
  this nesting and `:1636` requires the template literal to end exactly `` `,\n}) `` — preserve or update.**
- `ui/src/main.ts` (59) — services built at module scope `:28-46` and provided `useValue` `:54-57`;
  `provideRouter(routes)` `:53`.
- `ui/src/app/core/` — `api.ts` (242) `request` `:144`, `requestJson` `:183`, path guard `:117-127`,
  `buildInit` `:233-241`; `instance.ts` (220) `isInstanceReady` `:43-45`; `session.ts` (670) `subscribe`
  `:346`; `entity-id.ts` (41) `encodeEntityId` `:24-26` (**no production call site yet**), contract note
  `:15-18`; `strings.ts` (280) 108 keys, `privilegeRequiresResource` `:196` = `'Requires <resource>'`,
  `navRailItemTooltip` `:242` = `'<Area> · Ctrl+B toggles the side bar'`. **No `@angular/*` import
  anywhere in `core/` — confirmed.**
- `ui/src/app/shell/account-menu.ts` (145) — the exemplar: `viewChild` refs `:89-91`, `effect()` focus
  `:108-111`, `(keydown.escape)` `:50`, `role="menu"`/`menuitem` ARIA `:56-68`, focus-before-removal
  `:130-134`, core-service→signal mirror with `DestroyRef` `:96-102`. Inline template, `OnPush`, no
  `styles:` — uniform across all four shell components.
- `ui/tools/` — `client-lint.mjs` (348): colours `:80-107` (exempt path is exactly `_tokens.scss` `:43`;
  `rgba(var(--ocu-…), α)` allowed `:93`), literal text nodes `:175-194`, literal copy attributes
  `:256-275`, **control-flow blanker `:154-155` tolerates one paren group — every template condition must
  be a paren-free getter**. `strings.test.mjs` (204) `extractFixedStringsTable` `:48-68`,
  `REQUIRED_ALONGSIDE_TABLE` `:97-101` whose comment forbids growing it as a bypass, count assertion
  `:112-118`. `api.test.mjs` (581) the `ui/src` scan `:525-537` — `localStorage`, `document.cookie`,
  `BroadcastChannel`, `storage` listener and `postMessage` are forbidden **anywhere**; `sessionStorage` is
  explicitly fine (`:558`). `entity-id.test.mjs` (84) `CORPUS` `:32-41` — **no dotted row**;
  `angular-json.test.mjs` (99) `:22-24` every builder must start `@angular/build:`; `build-output.test.mjs`
  (312) reads `app.ts`'s **first** `{{ STRINGS.<key> }}` and **first** `class="..."` `:221-230` and asserts
  that class has a rule in the global bundle `:253-270`.
- `ui/package.json` (39) — `"test": "node --test tools/"` `:11`; devDeps `:31-38` carry `@angular/build`
  22.1.5 but **no runner**. `ui/angular.json` (72) — `build` `:13` and `serve` `:55`, **no `test` target**.
  `ui/node_modules/@angular/build/src/builders/unit-test/` **exists**, `builders.json` declares it, its
  schema takes `runner` ∈ {karma, vitest} default vitest; `vitest ^4.0.8` is an optional peer and `vite` is
  already transitively installed. `tsconfig.spec.json` (8) is vestigial `ng new` scaffolding.
- `src/OcuPilot/Test/EntityId.cls:22` — `Corpus()`, eight rows, **none dotted**; `:65` the browser-parity
  assertion. `Test/Wire.cls` (444) — `EnsurePrincipal` `:169-186` (caller must already be in `%SYS` `:168`),
  grant readback `:108`, `OnAfterAllTests` `:130-165` reporting through the **returned status**, never an
  assertion `:120-129`. `Test/Http.cls:206` `AbsoluteRequest`. `Test/RouterFixture.cls:18` the
  fixture-subclass pattern; `Test/Static.cls` (405), `Test/Routing.cls` (183).
- `scripts/check-objectscript.py` (536) — **`MAX_CLASS_NAME_LENGTH = 29` `:82` applied to every declared
  class `:210-214`, with no `%Persistent` test anywhere.** `CLASS_RE` `:106` never reads `Extends`.
  `check_package_placement:265` tests only `parts[1]`, so a sub-package under `Screen` already passes.
  `iter_code_lines` `:272-322` skips XData; `iter_non_comment_lines` `:409-424` keeps it.
- `ui/src/styles/_metrics.scss` — `--ocu-rail-width: 48px` `:28`, `--ocu-side-bar-width: 240px` `:29`,
  spacing scale `:13-19`, radii `:22-25`, motion `:63-65` collapsed under reduced motion `:73-79`; its
  header `:5-7` says this story is what reads them. `_tokens.scss` — `--ocu-shell` `:103`, `--ocu-on-shell`
  `:105`, `--ocu-shell-edge` `:107`, `--ocu-secondary` `:44`, **`--ocu-secondary-dark` `:45` is the dark
  value of the `secondary` role, not a darker shade**; `--ocu-restrained` `:126`; `--ocu-focus-ring` `:159`.
  `_components.scss` (428) — `@mixin ocu-focus-ring` `:31-35`, `.ocu-account*` `:358-423` the menu pattern.
  **Nothing rail- or nav-related exists yet.**
- `EXPERIENCE.md` — rail `:64` (the eight, verbatim, in **Information Architecture**), `:311-314` keyboard,
  ARIA and side bar, `:212-225` Privilege Gating (`:214` the mechanism; `:224` **the Agent co-pilot rail
  item never gates**), `:220` deep link to a gated route, `:348` **not an empty-state**, `:157` side bar
  lists only built screens, `:159-167` the area screen lists, `:173-186` the ten-item screen contract,
  `:248` the table's placeholder and illustration rule, `:287` `Requires <resource>`, `:297` the `<Area>`
  tooltip, `:530-532`/`:582` Ctrl/Cmd+B, `:580` landmark names, `:592` 48×48 hit area.
  `DESIGN.md` — `rail` `:236-241`, `rail-item` `:242-252` (indicator `:249`, `color-gated` `:247`),
  `attention-dot` `:253-257`, `side-bar` `:258-271` (`item-indicator-selected` `:269` is `secondary`,
  not `secondary-dark`; `resize-handle: none` `:271`), anatomy `:972-1003`, gated appearance `:986`/`:1003`,
  `restrained` not opacity `:1265`, `focus-ring.on-chrome` `:658`.

## Tasks & Acceptance

**Execution — server:**

- `src/OcuPilot/Kernel/EntityType.cls` — *new*. The closed entity-type enum (AD-14) plus `IsKnown()`.
  Seed it with the vocabulary EXPERIENCE.md `:159-167`'s Release 1 screen lists and epics.md `:3714` imply
  — web application, REST service, user, role, resource, service, SSL configuration, X.509 credential,
  LDAP configuration, wallet collection, wallet secret, the five OAuth 2.0 types, audit event, task, task
  history entry, process, lock, database, device, audit record, application error, log entry. A later story
  that needs a value adds it here; nothing invents one locally.
- `src/OcuPilot/Screen/Descriptor/Base.cls` — *new*. One `XData Declaration` of JSON per subclass, read
  through typed accessors (`%Dictionary.XDataDefinition.IDKEYOpen`, the `AdminPort.cls:81` idiom). Fields:
  route, area, side-bar position, archetype, `built`, privilege pair set, **primary** entity type plus
  **secondary** types, scope, parent-scope reference, id accessor (single or composite parts), context
  serializer field list with secret-typed fields, primary and row actions with self-protection rules,
  empty-state text key, command-box aliases, classic page class name, and `classicLinkExemption` with its
  reason. The tool identifier is its own field, **never derived from route or display name**.
- `src/OcuPilot/Screen/Descriptor/Home.cls` — *new*. The one real screen descriptor this story authors:
  archetype `home`, no entity type, no privilege set, classic page `%CSP.Portal.Home`. Story 1.12 builds
  the page behind it.
- `src/OcuPilot/Screen/Area.cls` — *new*. The closed area vocabulary: the eight rail entries in
  EXPERIENCE.md `:64`'s order with rail position, label key, `navigates` flag (Home only) and the area's
  own privilege pair set. 1.12's tile gating (epics.md `:1441-1443`) needs an area-level set, so it lives
  here rather than being derived from a screen list that is empty in Epic 1.
- `src/OcuPilot/Screen/Registry.cls` — *new*. Enumerates `OcuPilot.Screen.Descriptor.*` by parameterized
  `%Dictionary.CompiledClass` query, refuses a descriptor whose entity types are not `EntityType.IsKnown`,
  and answers the ordered area→screen roster. The route table, the navigation entry and the gate all read
  it; nothing else enumerates descriptors.
- `src/OcuPilot/Screen/Gate.cls` — *new*. `Evaluate(pDescriptorOrArea, Output pFailedPair) As %Boolean`:
  the declared pair set **unioned** with `##class(%CSP.Portal.Utils).%GetCustomResource(<URL-encoded class
  name>)` at `U` when the classic page declares one, every pair required, each checked with
  `$System.Security.Check` in the calling process (the `Router.cls:106` idiom). No cache, no service
  account, no `$ROLES` inspection. Returns the first failed pair as `resource:permission`.
- `src/OcuPilot/Api/Navigation.cls` — *new*. The thin handler: emit areas and built screens in declared
  order, each with `allowed` and, when denied, `failedPair`. Recomputed per call (AD-8) — **DW-9's server
  half**. Success through `Response.JSON`, failure through `Error.Render`.
- `src/OcuPilot/Api/Router.cls` — add `<Route Url="/navigation" Method="GET" Call="Navigation"/>` after
  `/instance` plus its thin wrapper. Both are explicit-verb single-segment routes, so `:41-55`'s three
  ordering invariants are unaffected.
- `src/OcuPilot/Api/Error.cls` — add one declared `code` parameter `AUTHNOPRIVILEGE` = `"AUTH.NOPRIVILEGE"`
  for a per-screen privilege denial, beside `AUTHNOADMIN` `:90`. `AUTH.NOADMIN` is the instance-level gate
  and must not be reused for "holds admin, but not this screen's pair".
- `src/OcuPilot/Kernel/EntityId.cls` — `PercentEncode` `:45` additionally replaces `.` with `%2E`, so
  `Encode` never emits a literal `..`. `Decode` is unchanged: `$ZConvert(...,"I","URL")` already reads
  `%2E`. **DW-97**, without amending AD-21.

**Execution — client:**

- `ui/src/app/core/screens.generated.ts` — *new, generated and checked in*. The TypeScript mirror of every
  descriptor's `XData` (AD-5). Never hand-edited.
- `ui/tools/screen-mirror.mjs` — *new*. Derives the mirror from the `XData` blocks in
  `src/OcuPilot/Screen/**/*.cls` on disk — no container, no runtime reflection — and a test asserts the
  checked-in file equals what it produces. Refuses an entity type absent from `Kernel/EntityType.cls`.
- `ui/src/app/core/navigation.ts` — *new, framework-free*. The client registry over the mirror: ordered
  areas, each area's built screens, the route→descriptor lookup, and a `NavigationService` holding the
  fetched map plus `noteForbidden()`, which re-reads it. **DW-9's client half.**
- `ui/src/app/core/api.ts` — call an `onForbidden` option on a 403, the shape `noteInstallInFlight` already
  has. `request()`'s existing pins stay untouched.
- `ui/src/app/core/preferences.ts` — *new, framework-free*. The **only** module permitted to touch
  `localStorage`, with a declared key allow-list it refuses to write outside. Holds the side bar's open
  state (EXPERIENCE.md `:51` "remembered per browser"). No `storage` listener, no `BroadcastChannel`.
- `ui/tools/api.test.mjs` — narrow the forbidden-channel scan `:525-537` to exempt exactly
  `src/app/core/preferences.ts` (an exact path, never a pattern — `client-lint.mjs:43`'s precedent), and
  add a test that the preference module refuses a key outside its allow-list. Every other forbidden shape,
  `localStorage` elsewhere included, still fails.
- `ui/src/app/app.routes.ts` — replaced: built from `screens.generated.ts`, one route per built screen plus
  `/<area>/<screen>/:id`, a not-found route and the gated-screen route. The adapter imports
  `@angular/router` and therefore lives here, outside `core/`.
- `ui/src/app/shell/rail.ts` — *new*. `app-rail`, `OnPush`, inline template. Eight items in declared order,
  Agent co-pilot pinned bottom; one Tab stop with Up/Down between items and Enter or Space activating
  (EXPERIENCE.md `:311`); `aria-current="page"` on the active area; `navigation` landmark named "Areas"
  (`:580`); no count badge. A click opens that area's side bar **without navigating**; the active item
  collapses it; Home navigates **and collapses** (`:50`). Gated items keep their place with
  `aria-disabled="true"` and the reason as a tooltip on hover and focus via `aria-describedby`; **the Agent
  co-pilot item never gates** (`:224`).
- `ui/src/app/shell/side-bar.ts` — *new*. `app-side-bar`, fixed `--ocu-side-bar-width`, no sash or resize
  affordance, `navigation` landmark named "<Area> screens", lists only `built` screens, arrow keys move and
  Enter opens, `aria-current="page"` on the current screen, gated entries carrying the reason **inline
  after the label** as well as on focus (`:314`). Open state through `preferences.ts`. Ctrl/Cmd+B toggles;
  with focus inside the side bar it moves focus to that area's rail item (`:314`, `:532`, `:582`); it is
  inert while a dialog or overlay is open (`:530-532`). Absent on Home (`:51`).
- `ui/src/app/shell/screen-denied.ts` — *new*. The deep-linked gated route: the screen's title and the
  permission-denied message naming the failed pair, `role="alert"`. Not an `empty-state` and not a banner
  (EXPERIENCE.md `:348`); the rail, side bar and shell keep working.
- `ui/src/app/app.ts` — render `<app-rail />` and `<app-side-bar />` inside the existing
  `@if (signedIn)` → `@if (instanceReady)` branch, around `<router-outlet />`. **Keep
  `session.test.mjs:1631-1712`'s nesting and terminator assertions passing, and keep whatever class the
  template names first covered by a rule in `_components.scss`** (`build-output.test.mjs:221-270`).
- `ui/src/main.ts` — build and provide `NavigationService` and the preference store the `useValue` way
  `:54-57` already uses.
- `ui/src/app/core/entity-id.ts` — `encodeEntityId` escapes `.` as `%2E` before the double
  `encodeURIComponent`, matching the server byte for byte. `decodeEntityId` unchanged.
- `ui/src/app/core/strings.ts` — add the eight area labels, verbatim from EXPERIENCE.md `:64`.
- `ui/tools/strings.test.mjs` — authorize them by **extracting `:64`**, as `extractFixedStringsTable`
  `:48-68` extracts the table, in a third category distinct from `REQUIRED_ALONGSIDE_TABLE` `:97-101` —
  whose comment forbids growing it and must stay at three. Update the count assertion `:112-118`.
- `ui/src/styles/_components.scss` — `.ocu-rail`, `.ocu-rail-item`, `.ocu-side-bar`, `.ocu-side-bar-item`
  and `.ocu-screen-denied` from existing tokens and metrics only: 48×48 items, the solid 3px
  `--ocu-secondary-dark` rail indicator inset 8px with `0 2px 2px 0` corners (DESIGN.md `:249`, `:984`),
  the 3px `--ocu-secondary` side-bar selected indicator (`:269`), 28px entries, gated copy in
  `--ocu-restrained` at **full opacity**, and the on-chrome focus variant. Add no colour token.

**Execution — tooling and tests:**

- `scripts/check-objectscript.py` — (a) scope `MAX_CLASS_NAME_LENGTH` `:82`/`:210-214` to classes that get
  a data global, by reading the `Extends` clause `CLASS_RE` `:106` currently discards, so the cap binds
  `%Persistent` and its descendants and not descriptors, ports, handlers, fixtures or test classes; update
  the docstring `:19-21`. **Without this the first descriptor fails the check: `OcuPilot.Screen.Descriptor.`
  alone spends 27 of 29.** (b) Add a rule, over `iter_non_comment_lines` `:409-424` so it sees XData, that
  every entity type named in a descriptor exists in `Kernel/EntityType.cls` — the "build fails on a value
  not in it" mechanism.
- `ui/angular.json` — add a `test` target using `@angular/build:unit-test` with `runner: "vitest"`. It is
  the only route compatible with `angular-json.test.mjs:22-24`'s `@angular/build:` assertion, and the
  builder is already installed. `ui/package.json` — add `vitest` (the declared optional peer range) and
  make `test` run the Node suite **and** the component suite. `ui/tsconfig.spec.json` — point it at the
  new runner instead of the vestigial `jasmine` types. **DW-93.**
- `ui/src/app/shell/*.spec.ts` — *new*. The first executed component tests: the rail's keyboard model and
  ARIA, the side bar's built-screens-only listing and persisted state, gated entries carrying
  `aria-disabled` and the reason, the deep-linked gated route rendering title plus message, and the route
  table built from the mirror. These are the tests DW-93 exists for.
- `src/OcuPilot/Test/Descriptor.cls` — *new*. The declaration contract and the three awkward forms, over
  fixture descriptors under `Test/`: a multi-entity descriptor (primary plus secondaries, all participating
  in change-event routing), a sub-resource descriptor with a parent-scope reference, and a composite-id
  descriptor whose id accessor round-trips through the one shared encode/decode pair. Also: a tool
  identifier that survives renaming its screen, and a descriptor naming an unknown entity type being
  refused by the registry.
- `src/OcuPilot/Test/Navigation.cls` — *new*. The gate over fixture descriptors: a pair set with two pairs
  is refused when either is missing and allowed only with both; the union with a classic-page custom
  resource; the failed pair named. The fixture overrides the classic-resource seam, so **no custom resource
  is ever written to the instance**.
- `src/OcuPilot/Test/Wire.cls` — add the over-the-wire navigation test: a throwaway principal holding
  exactly one admin resource gets 200 with that area allowed and the others denied, each naming its failed
  pair. Reuse `EnsurePrincipal` `:169-186` and the `OnAfterAllTests` teardown `:130-165`.
- `src/OcuPilot/Test/EntityId.cls` — add dotted rows (`a..b`, a leading `..`, a trailing `.`) to `Corpus()`
  `:22`; `ui/tools/entity-id.test.mjs` — add the same rows to `CORPUS` `:32-41`. Neither corpus has a dot
  today, so both parity suites would stay green through a one-sided change.
- `src/OcuPilot/Test/Static.cls` — add the DW-97 wire case: a double-encoded dotted id resolves to
  `index.html`, while a hand-typed literal `..` still answers 400 `STATIC.BADPATH`.

**Acceptance Criteria:**

- Given a screen declared by one descriptor class, when the registry loads it, then its route, its
  navigation entry and its privilege gate all resolve through that one declaration, and adding a screen
  edits no router and no nav list.
- Given a descriptor whose privilege set holds two pairs, when the gate evaluates it for a caller holding
  one of them, then access is refused and the response names the pair that failed; and when the classic
  page it replaces carries an operator-assigned custom resource, that resource at `U` is required too.
- Given a descriptor that administers several entity types, is a sub-resource of another screen's entity,
  or is keyed by a composite id, when it is declared, then it expresses a primary plus secondary types, a
  parent-scope reference and a composite id accessor that round-trips through the shared codec — and its
  tool identifier is unchanged by renaming the screen.
- Given a descriptor naming an entity type outside the kernel enum, when the build runs, then it fails
  naming the file and the value, and the mirror generator refuses to emit.
- **Integration AC** — given a signed-in caller whose privileges allow some areas and not others, when the
  shell fetches `GET /api/ocupilot/navigation`, then the rail renders every area in declared order with the
  denied ones `aria-disabled="true"`, focusable, in the Tab and arrow order, carrying the failed pair as a
  tooltip on hover and on focus, none hidden and none using the `disabled` attribute; and the Agent
  co-pilot entry never gates.
- Given a user deep-links to a route their privileges do not allow, when the screen loads, then it renders
  its title and a permission-denied message naming the failed pair, and the rail, side bar and the rest of
  the shell keep working.
- Given the rail and side bar, when they render, then the rail is one Tab stop with Up/Down between its
  eight items, marks the active area `aria-current="page"` with the solid 3px `secondary-dark` left
  indicator and shows no count badge; a rail item opens its area's side bar without navigating while the
  active item collapses it and Home navigates and collapses; and the side bar is fixed at 240px with no
  resize affordance, lists only built screens, remembers its open state per browser, and toggles with
  Ctrl/Cmd+B.
- **DW-9** — given the navigation map has been fetched, when any API call answers 403, then the map is
  re-read, and the server recomputes every gate from live state on every call rather than from anything
  resolved at startup.
- **DW-93** — given the client route table, the rail, the side bar and the gated-screen component, when the
  default test command runs, then an executed component suite asserts their rendered DOM — the first
  client tests in this project that render rather than read source text.
- **DW-97** — given an entity id containing two consecutive dots, when it is deep-linked, then the codec
  emits no literal `..`, the static handler serves `index.html`, and the SPA decodes the id back
  byte-for-byte — while a hand-typed literal `..` path still answers 400.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs (Rule 6).** AD-5 (one descriptor is the source of everything about a screen, including the
awkward forms and tool identity), AD-8 (privilege is the process's, a set of pairs, checked at call time,
never cached), AD-13 (one percent-encoded segment, encode-twice/decode-once, the `(entity type, scope, id)`
triple), AD-14 (the closed kernel-owned entity-type enum), AD-19 (zoneless, `OnPush`, signals; screen state
in a store keyed by its descriptor), AD-20 (absolute API paths through the one service), AD-21 (the literal
`..` rejection, kept intact; no caller-supplied path), AD-12/AD-39 (one writer, one flat envelope, the
stable `code`), AD-44 (the classic-page union and namespace as data scope), AD-47 (per-tab token storage, no
cross-tab broadcast), AD-24/AD-36/AD-43 (the context cap, the one declared read and the refresh
declaration — **declared** here, consumed later), AD-27 (every screen keeps its classic-portal link).

**Decision (overnight) — DW-93 is closed, not deferred a fourth time.** The cost turned out to be one
devDependency: `@angular/build:unit-test` already ships inside the installed `@angular/build@22.1.5`,
`vite` is already transitively present, and `angular-json.test.mjs:22-24` accepts an `@angular/build:`
builder. Three stories deferred this because their client half was small; this story's is almost entirely
rendered behaviour — keyboard order, ARIA state, focus movement — which source-text regexes cannot pin at
all. Deferring again would mean shipping the epic's navigation contract with no executed test host. If the
dependency cannot be installed offline, that is an environment blocker to report, not a reason to re-defer.

**Decision (overnight) — the descriptor's declaration is one JSON `XData`, read by both sides.** The
ObjectScript registry reads it through `%Dictionary.XDataDefinition` (`AdminPort.cls:81`) and the mirror
generator reads the same block off disk, so "hand-written declarative class, mirrored to the client as
generated TypeScript" (AD-5) has one source and no parser ambiguity. The generator runs on the repo, not in
the container — the container has no source mount, so a class method could not write the file.

**Decision (overnight) — DW-97 is fixed in the codec, not by amending AD-21.** Escaping `.` to `%2E` in
both `PercentEncode` and `encodeEntityId` means a double-encoded id carries `%252E%252E`, the one hop
decodes it to the text `%2E%2E`, and no layer sees a literal `..`. Probed live 2026-09-12 on this
instance's shell application: `a%252E%252Eb` → 200 `index.html`, `a%2E%2Eb` → 400, `a..b` → 400 — so the
hop decodes exactly once and does no dot-segment normalization. Scope: that is what was tested, for `%2E`
in one path segment of one application; it is not a claim about other encodings, and `%2F` and `%00`
already behave differently. The alternative — teaching the static handler to accept some `..` — would
weaken a containment check to carry data, which AD-21 exists to prevent.

**Decision (overnight) — the area labels are placeholder resolutions, not new copy.** EXPERIENCE.md `:297`
is canonical for `"<Area> · Ctrl+B toggles the side bar"`, and `:248` permits an illustration to *resolve*
a placeholder. The eight names are the domain of `<Area>`, enumerated at `:64`, which sits in Information
Architecture — outside the three sections `:248` reduces to illustrations. They are therefore authorized by
extraction from `:64`, the same shape `extractFixedStringsTable` uses, and **not** by adding entries to
`REQUIRED_ALONGSIDE_TABLE`, whose own comment calls that the bypass it must not become. Filed under
`deferred:` for the lead to add a table row.

**Decision (overnight) — the permission-denied message reuses `Requires <resource>`.** The table has no
permission-denied row, and `:234`/`:437`'s sentences are illustrations. `privilegeRequiresResource`
(`strings.ts:196`) resolved to `resource:permission` names the failed pair, satisfies the AC literally, and
adds no unauthorized copy. The pair spelling also answers the epic's "names the pair that failed" without a
new string shape.

**Decision (overnight) — the side bar's state uses `localStorage` through one allow-listed module.**
EXPERIENCE.md `:51` says "remembered per browser", which `sessionStorage` does not deliver.
`api.test.mjs:525-537` bans `localStorage` anywhere under `ui/src`, but its own failure message and AD-47's
Rule are about **credential channels** and cross-tab broadcast. The narrow carve-out — one module, an exact
path exemption, a declared key allow-list, and no `storage` listener or `BroadcastChannel` — honours both.
Widening the exemption to a pattern would not.

**Decision (overnight) — this story authors one real screen descriptor, not a roster.** The epic names no
descriptors, and the six areas' first screens are Epic 2's. So: the eight area declarations, Home's
descriptor (1.12 builds the page), and the three awkward forms as fixture descriptors under `Test/` — the
epic's "declared here rather than retrofitted" (`epics.md:1313`) is about the *forms* the mechanism must
express, since all three named screens land in later epics. A consequence worth stating: every area side
bar is empty at the end of Epic 1, and that is the correct rendering of "lists only screens that are built"
(`EXPERIENCE.md:157`), not a missing empty state.

**Decision (overnight) — the classic-page key is a normalized class name.** `%SYS.Portal.Resources`' IdKey
is the class name `NormalizePage` produces, and it does **not** case-fold a `.cls`/`.zen` class, so a
descriptor must spell the classic page in its canonical case or the lookup silently returns `""`. The read
needs no `%SYS` switch and carries no privilege guard, unlike the write path. The portal itself ANDs the
custom resource onto the page's own requirement and checks it at `"USE"`, which is exactly the union AD-44
asks for — read in `%ZEN/Controller.cls:34-62`, not inferred. AD-44's "normalized page URL" wording is
filed under `deferred:`.

**Consumes:** 1.1 (`Api.Response`, `Api.Error` and its enums, `Kernel.Utils`), 1.5 (`Api.Router`'s
`OnPreDispatch` and ordering invariants, `Api.StaticHandler`, `Kernel.EntityId`, `Test.Http`), 1.6
(`Session`, `ApiService`), 1.7 (`Test.Token`/`Test.Wire`'s throwaway-principal pattern), 1.8
(`isInstanceReady`, `requestJson`, `app.ts`'s two gates, `Port.AdminPort`).

**Consumed-by:** 1.10 — the command box enumerates every descriptor the user may open plus the current
screen's declared actions, matched against each descriptor's command-box aliases, and the locator bar reads
the area and screen names; 1.11 — reads the declared scope to decide re-fetch versus re-route and the id
accessor to build the `(entity type, scope, id)` triple; 1.12 — reads each area's built-screen list for its
tile caption, its first screen for the tile's target, and the area privilege set for tile gating; 1.13 —
names the failed pair on a 403 and owns the retry this story's 403 re-read does not schedule; 1.14 — reads
the descriptor's refresh declaration, permitted rates and entity type; 1.15 — reads the archetype and
classic-page declaration and enforces `classicLinkExemption` on detail archetypes only; 1.16 — the
descriptor classes are roster members in the generated manifest; 1.17 — puts the component suite and the
mirror drift check in CI; Epic 2 onward — every screen is added by adding a descriptor.

**Ledger inbox.** DW-9, DW-93 and DW-97 each have a matrix row, a task and an acceptance criterion. None
is declined.

## Verification

**Environments.** The live `ocupilot` container (web 52774, SuperServer 1973) must **not** be recreated —
no `docker compose up`/`down`/`restart` against this repository's compose file. Every check here is
read-only or idempotent and runs against it through the IRIS MCP tools with **`server: "ocupilot-iris"`** on
every call. Nothing in this story is install-path or destructive, so **no throwaway container is required**;
if one becomes necessary it is a separate scratch compose project with its own project name, container
name, host ports (never 52774/1973) and scratch volume, per `README.md` § "Verifying the start path against
a throwaway container", torn down with `down -v`. **Privilege-driven navigation must not be tested by
changing a real user's roles:** every denial test mints a purpose-built throwaway principal via
`Test.Wire.EnsurePrincipal` and removes it in `OnAfterAllTests`. No real account is created, modified,
locked or expired; no browser session this story did not mint is ended; `_SYSTEM` is the owner's working
account and is never altered. The classic-resource union is tested through a fixture seam — **no custom
resource is ever written to `%SYS.Portal.Resources`**, whose store is empty on this instance and stays so.

**One test class per tool call.** Send **one** `iris_execute_tests` call per message, wait for it to land in
`%UnitTest_Result`, and never re-submit on a client-side timeout — a returned call is not a finished run,
and these classes share one instance.

**Commands:**

- `npm --prefix ui test` — expected: green, now covering both the Node tool suite and the new component
  suite.
- `npm --prefix ui run build` — expected: exit 0, `client-lint: clean`, `initial` under the 1MB budget.
- `uv run scripts/check-objectscript.py` — expected: no findings, with the class-name cap now scoped and
  the entity-type rule firing on a bad value.
- `bash scripts/lint-docs.sh` — expected: clean.
- `iris_doc_load` + `iris_doc_compile` on `src/OcuPilot/` (`server: "ocupilot-iris"`) — expected: clean.
- `iris_execute_tests` on `OcuPilot.Test.Descriptor`, then `OcuPilot.Test.Navigation`, then
  `OcuPilot.Test.EntityId`, then `OcuPilot.Test.Static`, then `OcuPilot.Test.Wire`, then
  `OcuPilot.Test.Routing` — **one class per message, each awaited**, then the totals confirmed by the
  `%UnitTest_Result` SQL probe in `.claude/rules/objectscript-testing.md`.

**Pinning tests (Rule 19) — one per acceptance criterion:**

- One declaration drives route, nav entry and gate → `OcuPilot.Test.Descriptor`, the registry round trip,
  plus `ui/tools/screen-mirror.test.mjs`'s drift check. `mutation: _(implement stage)_`
- The pair set is required whole, unioned with the classic custom resource, and names the failed pair →
  `OcuPilot.Test.Navigation`. `mutation: _(implement stage)_`
- The three awkward forms and tool identity → `OcuPilot.Test.Descriptor`'s fixture descriptors.
  `mutation: _(implement stage)_`
- An unknown entity type fails the build → `scripts/check-objectscript.py`'s own rule exercised on a
  fixture, plus the generator's refusal. `mutation: _(implement stage)_`
- **Integration AC** (the rail renders denied areas `aria-disabled` and focusable from the fetched map) →
  the new `rail.spec.ts`, plus `OcuPilot.Test.Wire`'s over-the-wire navigation test for the map itself.
  `mutation: _(implement stage)_`
- Deep link to a gated route renders title plus message and leaves the shell working →
  `screen-denied.spec.ts`. `mutation: _(implement stage)_`
- The rail and side bar contract → `rail.spec.ts` and `side-bar.spec.ts` (keyboard, `aria-current`,
  indicator, open-without-navigating, Home's exception, persistence, Ctrl/Cmd+B).
  `mutation: _(implement stage)_`
- **DW-9** → `ui/tools/navigation.test.mjs`, a 403 re-reading the map; and `OcuPilot.Test.Navigation`
  asserting the gate recomputes rather than caching. `mutation: _(implement stage)_`
- **DW-93** → the component suite existing and running under `npm --prefix ui test`, asserted the way
  `client-lint.test.mjs:266-268` asserts its own wiring. `mutation: _(implement stage)_`
- **DW-97** → `OcuPilot.Test.Static`'s double-encoded dotted deep link plus the literal-`..` 400, and the
  dotted corpus rows in `OcuPilot.Test.EntityId` and `ui/tools/entity-id.test.mjs`.
  `mutation: _(implement stage)_`

Whoever adds or materially changes a pinning test writes its `mutation:` line in the same pass: name the
smallest change that violates the AC, apply it, observe red, revert, and confirm `git status --short` and
`git diff --stat` are unchanged.

**Manual checks:**

- In desktop Chrome against the live instance at `http://localhost:52774/ocupilot/`: sign in and confirm the
  rail renders eight items with Agent co-pilot at the bottom, that Tab reaches the rail once and Up/Down
  move within it, that a rail click opens the side bar without changing the URL while Home navigates and
  collapses it, and that Ctrl/Cmd+B toggles the side bar and its state survives a reload.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
