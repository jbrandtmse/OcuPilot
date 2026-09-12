---
title: 'Story 1.12 — Home'
type: 'feature'
created: '2026-09-12'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-1-10-header-status-bar-and-page-chrome.md'
warnings: ['oversized']
deferred:
  - summary: >-
      Home's panel-widening acceptance criterion cannot be surface-anchored in Epic 1: no panel
      component exists, and none is built before Epic 5.
    evidence: |-
      AC4's own precondition is "when the panel is present", false for all of Epic 1. Its tokens
      already ship and are drift-tested (--ocu-panel-home, --ocu-motion-panel-width-duration;
      ui/src/styles/_metrics.scss:35-43, :64, :77-87). Route to the story that builds the panel,
      which owns both the Home width and the remembered width it restores on leaving.
    location: 'ui/src/styles/_metrics.scss:35-43 (tokens only; no consumer)'
    severity: medium
---

<intent-contract>

## Intent

**Problem:** Stories 1.5-1.11 built the whole chrome around an empty content area — `ScreenOutlet` renders nothing for an allowed screen, so a signed-in user reaches a shell with no screen in it and the six areas are invisible.

**Approach:** Render Home inside that outlet: six area tiles in a wrapping auto-fit grid, with the instance line beneath. The outlet picks the page from the descriptor's declared `archetype`, so Epic 2 adds screens by declaring descriptors, never by editing a router (AD-5). Home reads only services that already exist — no API change, no new user-facing string.

## Boundaries & Constraints

**Always:** Tile labels from `stringFor(area.labelKey)`, a gated tile's reason from `formatRequires(STRINGS.privilegeRequiresResource, …)` — both already shipped. A gated control stays listed, focusable and `aria-disabled="true"`; never `disabled`, never hidden (AD-8; DESIGN.md:1259). Tokens for every color, measure and duration. Paren-free member references in `@if` and attribute positions (`screen-outlet.ts:38-39`).

**Never:** No new key in `core/strings.ts` and no growth of `REQUIRED_ALONGSIDE_TABLE`. No server change — no endpoint, no descriptor field, no ObjectScript. No screen store, no auto-refresh (1.14), no panel. No edit to `screens.generated.ts`; it is generated.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Tile roster | payload with all eight areas allowed | six tiles in declared rail order (`logs`, `os-management`, `tasks`, `permissions`, `web-applications`, `security`); `home` and `agent` absent | none expected |
| Gated tile | `areaVerdict` = `{allowed:false, failedPair:'%Admin_Secure:USE'}` | focusable, `aria-disabled="true"`, reason `Requires %Admin_Secure:USE` on hover **and** focus; activation a no-op | never hidden, never the `disabled` attribute |
| Tile caption | area's built screens `[]` / two built | empty caption / their labels joined by `' · '`, separators `aria-hidden`; the tile always shows icon slot and area name | no placeholder text invented |
| Tile activation | allowed area, with and without a built screen | with: router at the first built route, current `?ns=` preserved (`withQuery`); without: no navigation. Both leave the side bar open on that area | a second activation never toggles it shut |
| Instance line | server, version, namespace, flag, user | the five in that order joined by `' · '`, separators `aria-hidden`, version rendered full and not ellipsized (**DW-146**) | an empty field drops with its separator; flag `none` renders nothing |
| Locator area segment | `areaVerdict(area)` denied | does not navigate; `aria-disabled="true"` with the rail's `Requires <resource>` reason (**DW-143**) | client affordance only — the server already refuses |
| Escape on the side bar | open, stored preference `true` | collapses; `ocupilot.side-bar.open` still `true`, so the next area opens expanded (**DW-144**) | Ctrl/Cmd+B still persists — it is the preference |
| Unrecognised system mode | `serverFlag` 200 characters | bounded and ellipsized; the status bar keeps its 24px height (**DW-145**) | reachable only by a direct global write |
| Filter field description | `matchCount` is `''` | the input carries no `aria-describedby` at all (**DW-141**, description half) | accessible name still absent — declined below |

</intent-contract>

## Code Map

- `shell/screen-outlet.ts` — every generated route points here; `:45-60` renders only not-found and denied, `:22-23` names this story as the filler. Gains the archetype map. `:38-39` is the client-lint paren-free constraint.
- `core/screens.generated.ts` — **generated, never edited.** `AREAS` `:104-199` (eight, declared order, `navigates` true only for `home`); `SCREENS` `:202-241` (Home alone, `route: ""`, `archetype: "home"`).
- `core/navigation.ts` — `Verdict` `:32-39`, `areaVerdict` `:261-263`, `screensForArea` `:234-236`, `formatRequires` `:120-122`, `withQuery` `:142-150`.
- `shell/rail.ts:119-133,158-162` — the refusal pattern to copy for tiles and for the locator: `gated`, `ariaDisabled`, the reason, an early `return` in activate.
- `shell/side-bar.ts:146-159` (reason + `aria-describedby`), `:255-270` (`closeFromKeyboard` → `shell.toggleOpen()` — the DW-144 defect).
- `core/shell-state.ts:82-118` — `activateArea` (its toggle-shut branch is rail behaviour, not tile behaviour) and `setOpen`, which persists; `:82-90` already collapses without persisting, the precedent for DW-144.
- `shell/locator-bar.ts:111-132`, `:185-197` — segments built with `navigates: areaHasSomewhereToGo(...)` and no verdict consulted: the DW-143 defect.
- `shell/command-bar.ts:64-73` (dangling `aria-describedby`), `:154-156` (`matchCount` returns `''` unconditionally).
- Instance-line sources, all existing: `core/instance.ts` `serverName()` `:182`, `instanceVersion()` `:158`, `serverFlag()` `:172`; `core/scope.ts` `namespace()` `:193`; `core/session.ts` `userName()` `:276`; `shell/server-flag.ts` is the reusable flag component (words at `strings.ts:329-332`).
- `styles/_metrics.scss:52-58` — `--ocu-tile-min-width: 168px`, declared and unconsumed. `styles/_components.scss:1354-1364` — `.ocu-server-flag`, nowrap and unbounded: the DW-145 defect.
- `core/strings.ts:289-296` (eight area names), `:196` (`privilegeRequiresResource`).

All paths are under `ui/src/app/` unless shown otherwise.

## Tasks & Acceptance

**Execution:**
- `ui/src/app/areas/home/home.page.ts` -- new standalone `OnPush` component, first tenant of `areas/` per the spine's Angular-naming convention -- renders the tile grid and instance line from the services above.
- `ui/src/app/shell/screen-outlet.ts` -- archetype→component map; render the match for an allowed screen -- AD-5: adding a screen must not edit a router.
- `ui/src/styles/_components.scss` -- `.ocu-area-tile` grid and tile rules (auto-fit, `--ocu-tile-min-width` minimum, `--ocu-space-2` gaps, wrap, 24px icon slot, `--ocu-radius-md`, hover/focus/gated states) and the instance-line rule with the version not ellipsized -- tokens only.
- `ui/src/styles/_components.scss` -- bound `.ocu-server-flag` (`max-width`, `min-width: 0`, `overflow: hidden`, `text-overflow: ellipsis`) -- **DW-145**.
- `ui/src/app/core/shell-state.ts` -- an unconditional show-area-open entry for tile activation, and a transient collapse that moves visible state without calling `setOpen` -- **DW-144**.
- `ui/src/app/shell/side-bar.ts` -- `closeFromKeyboard` uses the transient collapse; Ctrl/Cmd+B keeps `toggleOpen()` -- **DW-144**.
- `ui/src/app/shell/locator-bar.ts` -- the area segment consults `areaVerdict` and refuses exactly as the rail does -- **DW-143**.
- `ui/src/app/shell/command-bar.ts` -- bind `aria-describedby` through a paren-free getter that is `null` while `matchCount` is empty -- **DW-141**, description half.
- `ui/src/app/areas/home/home.page.spec.ts` (new) and the existing `ui/src/app/shell/{screen-outlet,locator-bar,side-bar,command-bar}.spec.ts` -- cover every I/O matrix row at the component tier with stub services.
- `ui/tools/design-tokens.test.mjs` -- assert the `.ocu-server-flag` bound reaches the stylesheet -- jsdom computes no layout, so the stylesheet tier is where it is falsifiable.

**Acceptance Criteria:**
- **Integration AC (Rule 1).** Given Home's descriptor declares `archetype: "home"` and its verdict is allowed, when the router is at route `''`, then `ScreenOutlet` — the consumer — renders the Home page inside `.ocu-screen-outlet`, resolved through the archetype map and not through a route-table entry naming the component.
- Given a tile has DOM focus, when Enter or Space is pressed, then activation is identical to a click, including the refusal when the tile is gated.
- Given the story is complete, when `node tools/client-lint.mjs` and `node --test tools/strings.test.mjs` run, then both pass with `strings.ts` unchanged — no new user-facing copy was introduced.
- Given the six tiles render, when the viewport narrows to the supported minimum, then the grid wraps to further rows and Home never scrolls horizontally. _(Geometric — not falsifiable under jsdom; see Verification.)_

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs.** AD-5 (the descriptor drives route, navigation and gating; the archetype map is what keeps "adding a screen" from editing a router), AD-8 (a `(resource, permission)` set checked at call time; a denial names the failed pair), AD-19 (zoneless, `OnPush`, signals), AD-20 (absolute API paths — Home adds no call), AD-44 (the route's namespace is data scope; tile navigation carries `?ns=`), AD-47 (nothing fetched at runtime — the icon slot may not reach a CDN).

**Decision (overnight): tile captions come from the navigation payload, not from authored copy.** EXPERIENCE.md:352 defines the caption as "its Release 1 side-bar entries" and EXPERIENCE.md:157 says an unbuilt screen does not appear in the side bar, so rendering the area's built screen labels *is* the published contract — no new string, and it fills in as Epic 2 lands descriptors. Hard-coding the ~30 screen names would create a second source for every screen name beside its descriptor's `labelKey`, the drift AD-5 exists to prevent. Consequence, stated plainly: today all six captions render empty, because Home is the only built descriptor.

**Decision (overnight): no `home.store.ts`.** AD-19 scopes a store to "data, sort, filter, selection, max-rows and auto-refresh state"; Home has none of those and derives every value from shared services, so the convention's page+store pair would add an empty file for a reviewer to review. Epic 2's first screen with rows establishes the store's shape.

**Decision (overnight): the tile icon is a 24px `aria-hidden` placeholder slot.** DESIGN.md:1102 publishes size and color; DESIGN.md:952/974 say the glyphs are the owner's and unpublished, and no Material Symbols set is vendored. The slot reserves the published geometry, mirroring the rail; no per-area glyph is invented.

**Decision (overnight): the instance line carries no per-field labels.** DESIGN.md:896's "(server · version · namespace · flag · user)" is the whole published contract and EXPERIENCE.md publishes no Fixed-strings row for it (DW-126). Values joined by `' · '` with `aria-hidden` separators (EXPERIENCE.md:588) matches Story 1.10's recorded decision that the status bar carries no per-segment labels — consistent and copy-free. It also closes **DW-146**: the full version, truncated to a `title` in the 24px status bar, is now page content on Home. No API change is needed for it — `server`, `version` and `flag` are the `serverName` / `instanceVersion` / `serverFlag` fields Story 1.8 already added to `/instance`, `namespace` is `ScopeService`'s resolved scope, and `user` is the session's own name.

**Declined DW-141** (accessible-name half): naming the filter field needs a label EXPERIENCE.md does not publish — DW-126, escalated. The description half is fixed above at no copy cost. The CR's wider point (nothing reads the filter signal) is out of Home's reach: Home is a tile grid, not a list archetype, and has no rows to filter; Epic 2's first list gives the signal a consumer.

**Declined DW-147:** the view-options control has no published label and no published menu items — only a shape (DESIGN.md:1037) and two example view names in prose — and the two UX documents diverge on whether a sort control sits beside it (DW-139, escalated). Home has no view variants to switch between; Epic 2's Databases list is the first screen with two.

**Declined (AC4, panel widening):** deferred via the frontmatter entry — the panel does not exist in Epic 1 and AC4's own precondition, "when the panel is present", is false for the whole epic. Its tokens already ship and are drift-tested; the story that builds the panel owns both the Home width and the remembered width it restores.

**Consumes:** `NavigationService` (area verdicts, `screensForArea`, `withQuery`), `InstanceService` (`serverName`, `instanceVersion`, `serverFlag`), `ScopeService` (`namespace`), `Session` (`userName`), `ShellState`, `ScreenOutlet`, `ServerFlag`.

**Consumed-by:** the archetype→component map is consumed by every Epic 2 screen page (first: Story 2.1); `ShellState`'s new show-area entry has no second consumer in Epic 1.

## Verification

**Commands** (one runner invocation per tool call, awaited; never two in one message, never re-submitted on a client-side timeout):
- `cd ui && npm test` -- expected: the `node --test tools/` tier and `ng test` both green.
- `cd ui && node tools/client-lint.mjs` -- expected: exit 0, proving no literal user-facing text entered a template.
- `cd ui && node tools/screen-mirror.mjs --check` -- expected: no drift; this story does not change the mirror.

**Pinning tests** (Rule 19 — one demonstrated mutation per criterion, recorded at implement time):
- Outlet renders Home by archetype (Integration AC) -- `screen-outlet.spec.ts` -- mutation: _(implement stage)_
- Tile roster, order, Home/Agent absent -- `home.page.spec.ts` -- mutation: _(implement stage)_
- Gated tile focusable, `aria-disabled`, reason on hover and focus, activation refused -- `home.page.spec.ts` -- mutation: _(implement stage)_
- Tile caption from built screens, empty when none -- `home.page.spec.ts` -- mutation: _(implement stage)_
- Tile activation with and without a built screen; `?ns=` preserved; side bar left open -- `home.page.spec.ts` -- mutation: _(implement stage)_
- Keyboard activation (Enter / Space) -- `home.page.spec.ts` -- mutation: _(implement stage)_
- Instance line: five values, order, `aria-hidden` separators, version not truncated (DW-146) -- `home.page.spec.ts` -- mutation: _(implement stage)_
- DW-143 locator area segment refuses a denied area -- `locator-bar.spec.ts` -- mutation: _(implement stage)_
- DW-144 Escape collapses without writing the preference -- `side-bar.spec.ts` -- mutation: _(implement stage)_
- DW-145 `.ocu-server-flag` bounded and ellipsized -- `ui/tools/design-tokens.test.mjs` -- mutation: _(implement stage)_
- DW-141 no `aria-describedby` while the count is empty -- `command-bar.spec.ts` -- mutation: _(implement stage)_
- No new string keys -- `ui/tools/strings.test.mjs` + `client-lint.mjs` -- mutation: _(implement stage)_

**Live instance vs throwaway principals.** This story changes no ObjectScript, adds no `%UnitTest` class and needs no throwaway principal. The live check is a regression run of the two suites that already pin the payload the tiles consume — `OcuPilot.Test.Navigation`, then `OcuPilot.Test.Wire` (which mints its own throwaway `OcuPilotWire*` principals and deletes them in teardown) — each in its own `iris_execute_tests` call with `server: "ocupilot-iris"`, the second sent only after the first has landed in `%UnitTest_Result`. Do not recreate the `ocupilot` container.

**Manual checks (the lead's browser gate — jsdom computes no layout and there is still no browser-runtime harness, DW-159):**
- The tile grid wraps rather than scrolling horizontally at 1,280 / 1,024 / 900 px, keeping the 168px minimum and 8px gaps.
- The gated tile's reason appears on hover **and** on keyboard focus.
- A 200-character system mode leaves the status bar 24px tall (DW-145).

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Planning only — the dispatch directed a halt after planning; nothing was implemented and nothing was committed. Ledger inbox: DW-143, DW-144, DW-145, DW-146 addressed by a Tasks item or I/O matrix row; DW-141 split (description half addressed, accessible-name half declined under DW-126); DW-147 declined. Spec is `oversized` against the 900-1,600 token budget at ~4,000: one trim pass was made, and the remainder is the nine-row I/O matrix, the six ledger dispositions and Rule 19's per-criterion pinning roster, none of which can be dropped.
