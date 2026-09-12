---
title: 'Story 1.9: The screen descriptor registry and privilege-driven navigation'
type: 'feature'
created: '2026-09-12'
status: 'done'
baseline_revision: '33d8950c7ef2240250d1c059e08b02f9b76dfac2'
review_loop_iteration: 0
followup_review_recommended: true
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
  - summary: >-
      The navigation map is rebuilt from the class dictionary on every accessor call: each
      descriptor accessor reopens its XData and re-parses the JSON, and Roster calls
      ScreensForArea once per area. Measured 2.3 ms for the one shipped descriptor; the cost
      scales with descriptors x areas, and the shell fetches this on every sign-in and 403.
    evidence: |-
      Measured on ocupilot-iris 2026-09-12 by a reviewer: 57 us per accessor call, 36 us per
      Area.List(), 2.3 ms per Payload at one descriptor. Not patched here because the fix is a
      roster cache, which is not a trivial change and must not read as caching privilege - AD-8
      forbids caching the verdict, not the roster.
    location: 'src/OcuPilot/Screen/Registry.cls; src/OcuPilot/Api/Navigation.cls'
    severity: medium
  - summary: >-
      The two readers of the same XData disagree on two shapes: check-objectscript.py silently
      skips a single-line `XData Declaration { ... }` block, and screen-mirror.mjs mis-parses it;
      and the generator reads Descriptor/ non-recursively while the server matches the package
      prefix, so a descriptor in a sub-package would be served and absent from the mirror.
    evidence: |-
      Both confirmed by reviewers driving the functions directly. Neither shape occurs in the
      tree today - every descriptor uses the UDL convention and sits directly under Descriptor/ -
      so this is a silent bypass of the AD-14 build gate rather than a live defect.
    location: 'scripts/check-objectscript.py (iter_named_xdata_blocks); ui/tools/screen-mirror.mjs'
    severity: medium
  - summary: >-
      The DW-97 corpus closes the dot divergence but not the rest of its family: encodeURIComponent
      also leaves `!`, `~`, `*`, `'`, `(` and `)` unescaped where $ZConvert(...,"O","URL") does not
      necessarily agree, and neither parity corpus carries a row for any of them.
    evidence: |-
      Read directly from both corpora 2026-09-12: src/OcuPilot/Test/EntityId.cls Corpus() and
      ui/tools/entity-id.test.mjs CORPUS. The same class of one-sided change that DW-97 was filed
      for would still pass both suites for those six characters.
    location: 'src/OcuPilot/Test/EntityId.cls:22; ui/tools/entity-id.test.mjs:32-47'
    severity: medium
  - summary: >-
      scripts/check-objectscript.py has no test harness, so both rules this story changed - the
      rescoped class-name cap and the new entity-type rule - are pinned only by hand-applied
      mutations. Three of Registry.Validate's five refusals (route collision, empty toolIdentifier,
      unparsable declaration) likewise have no fixture.
    evidence: |-
      No test file exists for the script anywhere in the repo; it runs from .githooks/pre-commit.
      Both directions of the cap and the entity-type rule were demonstrated by hand this pass and
      recorded in `## Verification`, which is a human-only check that does not repeat.
    location: 'scripts/check-objectscript.py; src/OcuPilot/Screen/Registry.cls (Validate)'
    severity: medium
  - summary: >-
      Api.Navigation.Payload hand-copies each roster field rather than decorating the roster entry,
      so a field added to Registry.Roster is silently absent from the wire; and Roster's
      ScreensForArea error branch leaves already-pushed areas in the output while its Catch clears
      it, so a caller reading the output before the status can see a partial map.
    evidence: |-
      Read directly 2026-09-12. Both are developer-facing: the duplication has no live symptom
      today (the per-screen fields are now asserted), and the partial-output branch needs
      ScreensForArea to fail, which needs the dictionary query to fail.
    location: 'src/OcuPilot/Api/Navigation.cls; src/OcuPilot/Screen/Registry.cls (Roster)'
    severity: low
  - summary: >-
      Smaller shell-behaviour items left as filed: the Ctrl/Cmd+B chord does not exclude shiftKey;
      rail and side-bar navigation drop a `?ns=` selection; ShellState persists Home's collapse as a
      user preference and toggles when no area is visible; the composite-id codec accepts a part
      already containing its own separator with no guard and no adversarial test.
    evidence: |-
      Each read directly from the diff 2026-09-12 and confirmed against the source. None is
      reachable in Epic 1: there is no namespace switcher, no dialog, and no composite-id screen -
      the composite form exists only as a test fixture.
    location: 'ui/src/app/shell/side-bar.ts; ui/src/app/shell/rail.ts; ui/src/app/core/shell-state.ts; src/OcuPilot/Kernel/EntityId.cls'
    severity: low
  - summary: >-
      The map-to-rail join is never exercised as one path: the wire contract is spelled once in
      ObjectScript and once in TypeScript with nothing deriving one from the other, and all three
      component specs replace NavigationService with a local stub. The mirror-to-XData contract is
      pinned by a generated-artifact equality check; this one is not.
    evidence: |-
      Would settle it: a test that drives the real NavigationService from a payload recorded off
      GET /api/ocupilot/navigation. Related and unresolved: navigation.ts treats an area the map
      omitted as UNGATED, so a server that dropped an area fails open at the client.
    location: 'ui/src/app/core/navigation.ts; ui/src/app/shell/*.spec.ts; src/OcuPilot/Test/Wire.cls'
    severity: medium
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

### 2026-09-12 — Review pass

- verdicts: 70 findings — high 3, medium 26, low 26, false 9, maybe-false 6
- findings:
  - `[high]` `[patch]` BH/EC: `Gate.Evaluate` admits any compiled class that is not a descriptor — verified live before the fix: `Evaluate("%Library.File")`, `("OcuPilot.Api.Router")` and `("…Descriptor.Base")` each answered `allowed=1`. `RequiredPairs` now reports `pResolved`, and an unresolved requirement is refused.
  - `[high]` `[patch]` BH/EC: `RequiredPairs`' `Catch` fails open while `EvaluatePairs`' fails closed — same root cause; a descriptor whose declaration will not parse read as "requires nothing". Fixed by the same `pResolved` guard, which now checks `DeclarationJson`'s status first.
  - `[high]` `[patch]` EC: `ClassicResource` throwing discards the declared pairs — same root cause; covered by the `pResolved` guard.
  - `[medium]` `[patch]` BH/EC: a declared privilege pair missing a half is silently dropped and ships an ungated screen — `Registry.Validate` now refuses it via `MalformedPair`; pinned by `Test.Navigation:TestAMalformedPrivilegePairIsRefused` over the new `Test.Pair.Bad` fixture.
  - `[medium]` `[patch]` BH/EC: `screenForUrl` resolved unbuilt screens, rendering a blank content area — now only built screens resolve, so an unbuilt route reaches the not-found screen.
  - `[medium]` `[patch]` BH/EC: the side bar's roving tabindex was never clamped, so switching to a shorter area left no tab stop — clamped in `resolved()`; pinned by a new `side-bar.spec.ts` test.
  - `[medium]` `[patch]` BH/EC: screen verdicts were stored without the guard area keys get, so an entry omitting `route` clobbered Home's verdict — now skipped unless `route` is a string.
  - `[medium]` `[patch]` VG/EC: `NavigationService.reset()` could be overwritten by a map already in flight, reinstating the previous principal's gating — generation counter added, mirroring `InstanceService`.
  - `[medium]` `[patch]` BH: `readPreferenceStorage()` hands out raw `localStorage`, so the key allow-list can be bypassed without the token the scan greps for — `api.test.mjs` now asserts the handle is imported only by `preferences.ts` and `main.ts`.
  - `[medium]` `[patch]` VG: `main.ts`'s `onForbidden` wiring and `NavigationService` provider had no pin — deleting either left the suite green. Two `assert.match` assertions added to `session.test.mjs`; confirmed red on deletion.
  - `[medium]` `[patch]` VG: `app.ts`'s `navigation.load()` / `navigation.reset()` had no pin — same shape as the existing `instance.reset()` pin. Added; confirmed red on deletion.
  - `[medium]` `[patch]` VG: the rail's navigation half was unobservable — the spec's router had no routes, so "did not navigate" and "navigated to Home" were the same assertion. `rail.spec.ts` now parks at `/permissions/users` and asserts the move.
  - `[medium]` `[patch]` BH: no test pinned the per-screen half of the navigation payload, which is what the client keys `screenVerdict` on — assertions added to `Test.Navigation:TestThePayloadCarriesEveryAreaWithAVerdict`.
  - `[medium]` `[patch]` BH/VG: `Count()` was asserted against its own definition and could not fail — now pinned to the literal 26.
  - `[medium]` `[defer]` BH: the navigation map rebuilds every accessor from `%Dictionary.XDataDefinition`; measured 2.3 ms at one descriptor, and the cost scales with descriptors × areas. Deferred — the fix is a roster cache, which is not a trivial patch and needs care not to read as caching privilege (AD-8 forbids that, not this).
  - `[medium]` `[defer]` BH/EC: `iter_named_xdata_blocks` silently skips a single-line `XData Declaration { … }`, and the JS reader mis-parses the same form — a silent bypass of the AD-14 build gate for a form no descriptor uses today.
  - `[medium]` `[defer]` BH/EC: the mirror generator reads `Descriptor/` non-recursively while the server matches `%STARTSWITH 'OcuPilot.Screen.Descriptor.'` — a descriptor in a sub-package would be served and absent from the mirror, drift check still green.
  - `[medium]` `[defer]` BH: the DW-97 corpus closes the `.` divergence but not `!`, `~`, `*`, `'`, `(`, `)`, which `encodeURIComponent` also leaves unescaped — the same class of client/server divergence would still pass both parity suites.
  - `[medium]` `[defer]` BH: three of `Validate`'s five refusals (route collision, empty `toolIdentifier`, unparsable declaration) have no fixture; the malformed-pair and unknown-type refusals now do.
  - `[medium]` `[defer]` VG: `check-objectscript.py` has no test harness at all, so its two new rules are pinned only by hand-applied mutations.
  - `[medium]` `[reject]` EC: `gets_data_global` does not follow vendor superclasses, so a class extending a vendor persistent class is uncapped — true, and documented verbatim in the script's own docstring as this line-oriented checker's scope. The tree has no such class; rejecting as by-design, `reopen_if` a project class extends a vendor persistent class.
  - `[low]` `[patch]` BH/EC/VG: `ui/tools/navigation.test.mjs`'s mutation note named an `inFlight` guard `noteForbidden` deliberately does not have — corrected to name `load()`'s slot ordering, which is the real single-flight rule.
  - `[low]` `[patch]` BH/VG: the spec's pinning row named `screen-denied.spec.ts`, which does not exist — corrected to `screen-outlet.spec.ts` (Rule 19's sanctioned `## Verification` edit; the `mutation:` line beneath it already named it correctly).
  - `[low]` `[patch]` BH: the side bar bound `aria-describedby` on every entry while only gated entries render the reason element — now bound only when one exists; pinned by a new `side-bar.spec.ts` test.
  - `[low]` `[patch]` BH: the rail's doc claimed the tab stop follows the active area; the code always starts at the first item — doc corrected to match the code rather than changing focus behaviour untested.
  - `[low]` `[patch]` BH: `Registry`'s doc implied `Validate` runs on the instance; nothing on the serving path calls it — doc now says who calls it and why `Roster` does not.
  - `[low]` `[patch]` BH: `check-objectscript.py`'s docstring listed the new rule as 8 between rules 2 and 3 and still said "seven ACs" — renumbered and corrected.
  - `[low]` `[patch]` BH: the `COMPOSITESEPARATOR` inference label rendered as a bold `(inference` with a stray bold `)` — reduced to the one word CLAUDE.md asks for.
  - `[low]` `[reject]` BH/EC: a denial carrying an empty `failedPair` would render "Requires " with nothing after it — every denial the roster can produce now names a pair, and the remaining path needs `$System.Security.Check` itself to throw. `reopen_if` a denied entry is ever observed with no pair named.
  - `[low]` `[defer]` BH/EC: `isSideBarChord` does not exclude `shiftKey`, so Ctrl/Cmd+Shift+B also toggles.
  - `[low]` `[defer]` BH/EC: `Roster`'s `ScreensForArea` error branch leaves already-pushed areas in the output while the `Catch` clears it — a caller reading the output before the status sees a partial map.
  - `[low]` `[defer]` BH/EC: `Payload` hand-copies each roster field, so a field added to `Roster` is silently absent from the wire.
  - `[low]` `[defer]` BH/EC: `JoinComposite`/`SplitComposite` accept a part already containing `$Char(1)` with no guard, and no adversarial test covers it; nor does `Validate` check `id.kind` against `id.parts`.
  - `[low]` `[reject]` BH/VG: `Api.Error.AUTHNOPRIVILEGE` has no call site or test — the spec tasks declaring it ahead of its Epic 2 consumer and its doc says so; a constant with no behaviour is not worth a test.
  - `[low]` `[reject]` BH: `tsconfig.spec.json`'s `vitest/globals` types are unused because every spec imports explicitly — harmless, and removing it invites a later spec to fail confusingly.
  - `[low]` `[defer]` EC: `ShellState.activateArea`'s Home branch persists the collapse as a user preference, and `toggleOpen` flips the flag when no area is visible.
  - `[low]` `[defer]` EC: rail and side-bar navigation drop a `?ns=` namespace selection (AD-13 carries it as a query parameter); no namespace switcher exists until a later story.
  - `[maybe-false]` `[defer]` EC: a 403 arriving mid-fetch joins the running load, whose answer may predate the revocation it reports — would settle it: a test driving a 403 whose response is already in flight. If true it is medium; the single-flight rule is what keeps the map's own 403 from looping, so the two pull against each other.
  - `[false]` `[reject]` VG: "the rail/side-bar `mutation:` line turns neither named test red" — refuted by observation: the mutation was applied and `rail.spec.ts`'s open-without-navigating test and `side-bar.spec.ts`'s Home test both went red (recorded in `## Verification`).
  - `[false]` `[reject]` VG: "`%Get("failedPair") = ""` cannot fail" — true as filed; now moot, both `Test.Navigation` and `Test.Wire` use `%IsDefined` so omission is observable.
  - `[false]` `[reject]` VG: "the rescoped cap's positive branch has no subject in the tree" — the branch was driven in both directions in this pass (a 41-character `%Persistent` class refused, a 50-character storage-free descriptor passed) and recorded in `## Verification`.
  - `[low]` `[reject]` IA: the tooltip's hover/focus reveal lives in CSS, which no test reads — accurate; the ARIA wiring is asserted and the reveal is a DESIGN.md transcription. `reopen_if` `build-output.test.mjs` grows a rule-level reader.
  - `[low]` `[reject]` IA: new rail/side-bar rules carry raw pixel literals rather than tokens — consistent with `_components.scss`'s existing documented convention for component-own geometry.
  - `[maybe-false]` `[defer]` IA: the map→rail join is never exercised as one path; the wire contract is spelled twice in two languages with nothing deriving one from the other. Would settle it: a test that drives the real `NavigationService` from a recorded server payload.
  - `[false]` `[reject]` IA: the gated deep link is exercised on a screen production cannot deny — true of Home today, and unavoidable while Home is the only descriptor; the refusal path itself is asserted and the server half is covered by `Test.Wire`.
  - `[false]` `[reject]` IA: DW-97 is never traversed end to end in one test — the server half and the client half each cover their side, and the two corpora are asserted byte-equal; a single traversal would need a descriptor Epic 2 adds.
  - `[false]` `[reject]` IA: "no refusal is demonstrated against a checked-in XData block carrying a bad value" — by construction: such a block cannot be committed, which is what the build gate means. The gate was demonstrated by applying exactly that block and observing the refusal.
  - `[false]` `[reject]` IA: the area names moved authority from the Fixed strings table to prose — that is the `deferred:` item already filed at plan time for the lead to close by adding a table row.
  - `[maybe-false]` `[defer]` IA: `navigation.ts` treats an area the map omitted as `UNGATED`, so a server dropping an area fails open at the client — would settle it: whether any path can produce a partial map now that `Roster`'s partial-output branch is filed above.
  - `[medium]` `[reject]` BH: `Validate` has no production caller — kept as a finding against the doc (patched above) rather than the code: adding a per-request roster walk is the performance problem deferred above, and install-time validation is not this story's task.
  - `[low]` `[reject]` EC: `JoinComposite` on an empty list yields `""` while `SplitComposite("")` yields one empty part — asymmetric but unreachable; no descriptor declares an empty composite part list.
  - `[false]` `[reject]` EC: "a broken descriptor sorting before Home shadows it at the application root" — `Roster` reads `Route()` per descriptor and a broken one now fails `Validate`; the collision itself is the deferred untested branch above.
  - `[maybe-false]` `[defer]` EC: `Registry.Validate` does not check `id.kind` against `id.parts` — grouped with the composite-guard entry above.
  - `[maybe-false]` `[defer]` EC: an unparsable declaration makes `Route()` read empty, which could collide with Home's empty route — grouped with the untested-refusals entry above.
  - `[maybe-false]` `[defer]` VG: the wire contract is duplicated between `Payload` and `Roster` — grouped with the `Payload` entry above.
  - `[false]` `[reject]` ×9, `[low]` `[reject]` ×6: the remaining rows from all four layers restate one of the entries above at a second location (the Gate fail-open at three call sites, the `noteForbidden` mutation note at three layers, the `screen-denied.spec.ts` reference at two, the dangling `aria-describedby` at two, the side-bar tabindex at two, the unbuilt-screen resolution at two) — each shares its group's verdict and route and is closed by the same patch.

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
  plus `ui/tools/screen-mirror.test.mjs`'s drift check.
  `mutation: Registry.Roster emitted a literal route instead of the descriptor's Route() → Test.Descriptor:TestOneDeclarationDrivesRouteNavigationAndGate red ("whose navigation entry names the declared route")`
- The pair set is required whole, unioned with the classic custom resource, and names the failed pair →
  `OcuPilot.Test.Navigation`.
  `mutation: Gate.EvaluatePairs allowed on the first pair held (OR, not AND) → Test.Navigation:TestATwoPairSetIsRequiredWholeAndTheFailureIsNamed red, with TestTheClassicPagesCustomResourceIsUnionedOn and TestTheGateRecomputesRatherThanCaching red beside it`
- The three awkward forms and tool identity → `OcuPilot.Test.Descriptor`'s fixture descriptors.
  `mutation: dropped "oauth2-server-definition" from Test.Screen.Multi's secondaryEntityTypes → Test.Descriptor:TestAMultiEntityDescriptorDeclaresPrimaryAndSecondaryTypes red`
- An unknown entity type fails the build → `scripts/check-objectscript.py`'s own rule exercised on a
  fixture, plus the generator's refusal.
  `mutation: set Test.Screen.Multi's entityType to "not-a-real-entity-type" → check-objectscript.py exit 1, naming file, line and value. The rescoped cap was driven both ways in the same pass: a 41-character %Persistent class is refused, a 50-character storage-free descriptor passes.`
- **Integration AC** (the rail renders denied areas `aria-disabled` and focusable from the fetched map) →
  the new `rail.spec.ts`, plus `OcuPilot.Test.Wire`'s over-the-wire navigation test for the map itself.
  `mutation: removed [attr.aria-disabled] from rail.ts's item → rail.spec.ts "Integration AC: a denied area stays listed, focusable and aria-disabled..." red (expected null to be 'true')`
- Deep link to a gated route renders title plus message and leaves the shell working →
  `screen-outlet.spec.ts` (the routed component; `screen-denied.ts` is its presentational half).
  `mutation: ScreenOutlet.denied forced to false → screen-outlet.spec.ts "renders the screen title and the failed pair when the route is gated" red`
- The rail and side bar contract → `rail.spec.ts` and `side-bar.spec.ts` (keyboard, `aria-current`,
  indicator, open-without-navigating, Home's exception, persistence, Ctrl/Cmd+B).
  `mutation: ShellState.activateArea always returned true, so every rail click navigates → rail.spec.ts "opens an area without navigating, while Home navigates and collapses" and side-bar.spec.ts "is absent on Home and absent while collapsed" red`
- **DW-9** → `ui/tools/navigation.test.mjs`, a 403 re-reading the map; and `OcuPilot.Test.Navigation`
  asserting the gate recomputes rather than caching.
  `mutation: NavigationService.noteForbidden made a no-op → navigation.test.mjs "DW-9: a 403 re-reads the map..." and "...the map's own call re-reads nothing, so the shell cannot loop" red`
- **DW-93** → the component suite existing and running under `npm --prefix ui test`, asserted the way
  `client-lint.test.mjs:266-268` asserts its own wiring.
  `mutation: dropped "&& ng test" from ui/package.json's test script → angular-json.test.mjs "DW-93: a component test target exists, runs vitest, and is what npm test invokes" red`
- **DW-97** → `OcuPilot.Test.Static`'s double-encoded dotted deep link plus the literal-`..` 400, and the
  dotted corpus rows in `OcuPilot.Test.EntityId` and `ui/tools/entity-id.test.mjs`.
  `mutation: dropped the "." escape from Kernel.EntityId.PercentEncode → Test.Static:TestDottedEntityIdDeepLinksWhileLiteralDotsAreStillRefused red while both literal-.. refusals stayed green; dropping it from ui/src/app/core/entity-id.ts alone → entity-id.test.mjs's parity and no-literal-.. rows red, which is the one-sided change the dotted corpus rows exist to catch`

Whoever adds or materially changes a pinning test writes its `mutation:` line in the same pass: name the
smallest change that violates the AC, apply it, observe red, revert, and confirm `git status --short` and
`git diff --stat` are unchanged.

**Manual checks:**

- In desktop Chrome against the live instance at `http://localhost:52774/ocupilot/`: sign in and confirm the
  rail renders eight items with Agent co-pilot at the bottom, that Tab reaches the rail once and Up/Down
  move within it, that a rail click opens the side bar without changing the URL while Home navigates and
  collapses it, and that Ctrl/Cmd+B toggles the side bar and its state survives a reload.

## Auto Run Result

**Implemented.** A screen is declared once, in one JSON `XData` block, and the route table, the
navigation entry and the privilege gate all resolve through it. Server: the closed entity-type
enum, the eight-area vocabulary, the descriptor base and Home's descriptor, the registry, the
`(resource, permission)` gate with the classic-page union, and `GET /api/ocupilot/navigation`.
Client: the generated mirror plus its drift check, a framework-free registry and navigation
service, the preference store, the rail, the side bar, the routed outlet and the gated-screen
component, with the route table built from the mirror. All three routed ledger items closed:
DW-9 (a 403 re-reads the map), DW-93 (the component runner), DW-97 (the dotted id).

**Files changed.** 61 files. Server — `Kernel/EntityType.cls`, `Screen/Area.cls`,
`Screen/Descriptor/{Base,Home}.cls`, `Screen/{Registry,Gate}.cls`, `Api/Navigation.cls` (new);
`Api/{Router,Error}.cls` and `Kernel/EntityId.cls` (route, code, dot escape). Client —
`core/{screens.generated,navigation,preferences,shell-state}.ts`,
`shell/{rail,side-bar,screen-denied,screen-outlet}.ts`, `tools/screen-mirror.mjs` (new);
`app.routes.ts`, `app.ts`, `main.ts`, `core/{api,entity-id,strings}.ts`, `_components.scss`
(rail, side bar, denied screen). Tooling — `check-objectscript.py` (cap rescoped to storage
classes, entity-type rule added), `angular.json` + `package.json` + `tsconfig*.json` (the vitest
runner). Tests — `Test/{Descriptor,Navigation,PairRegistry,ScreenGate,ScreenRegistry,BadRegistry}.cls`,
`Test/Screen/*`, `Test/Bad/Unknown.cls`, `Test/Pair/Bad.cls`, four `*.spec.ts`, and four new
`ui/tools/*.test.mjs`. `shell/deep-link.ts` deleted.

**Review findings.** 70 findings across four layers. Patched 28 (1 grouped `high` entry — the
gate admitted any compiled class that was not a descriptor, verified live at `allowed=1` for
`%Library.File` before the fix — plus 11 `medium` and 16 `low`). Deferred 7 new items to the
frontmatter `deferred:` list (11 total with the four filed at plan time). Rejected: the vendor
superclass the rescoped cap cannot follow (by-design, documented in the script's own docstring);
a denial rendering `Requires ` with no pair (no reachable path now names an empty pair);
`AUTHNOPRIVILEGE` having no caller (the spec tasks declaring it ahead of its Epic 2 consumer);
`vitest/globals` being unused; and nine `false` rows the verification disproved, including three
Rule 19 flags this pass had already closed by demonstrating the mutation.

**Follow-up review recommended: true.** A `high` was patched. The specific unverified risk: the
gate now refuses any target whose requirement it cannot read, which changes the answer for every
non-descriptor class; its one production caller is `Api.Navigation.SetVerdict`, which only ever
passes declared areas and registry descriptors, so the new refusal path is exercised by tests and
not by the running shell. Patched by verdict — high 1, medium 11, low 16.

**Verification.** `npm --prefix ui test` exit 0 — 279 Node tests and 29 executed component tests,
0 failures. `npm --prefix ui run build` exit 0, `client-lint: clean`, `screen-mirror: up to date`,
initial 294.07 kB. `uv run scripts/check-objectscript.py` 0 problems. `bash scripts/lint-docs.sh`
clean. 91 classes load and compile clean against `ocupilot-iris`. Six test classes, one per
message and each awaited, confirmed independently by the `%UnitTest_Result` run-index probe:
`Descriptor` 11/11, `Navigation` 11/11, `EntityId` 4/4, `Static` 16/16, `Wire` 11/11,
`Routing` 12/12 — 65 tests, 0 failures. Thirteen mutations were applied and reverted by hand to
fill the ten `mutation:` lines above, the tree confirmed byte-identical after each.

**Residual risks.** The manual browser check was not run — it needs this bundle installed into
the owner's live container, which this story must not recreate. The composed map-to-rail path is
still not exercised end to end (filed under `deferred:`): the wire contract is spelled once in
each language with nothing deriving one from the other. `check-objectscript.py` still has no test
harness, so its two rules are pinned only by the hand-applied mutations recorded above. The
navigation map's per-request cost is measured and filed, not fixed.

Status: done
Blocking condition: none
