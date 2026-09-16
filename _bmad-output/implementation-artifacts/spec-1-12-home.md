---
title: 'Story 1.12 — Home'
type: 'feature'
created: '2026-09-12'
status: 'done'
baseline_revision: 'aa111352d7f975d9597e0eb6e5ced85e5dbbbb31'
baseline_commit: 'aa111352d7f975d9597e0eb6e5ced85e5dbbbb31'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-1-10-header-status-bar-and-page-chrome.md'
warnings: ['oversized']
deferred:
  - summary: >-
      Home's panel-widening acceptance criterion cannot be surface-anchored in Epic 1: no panel
      component exists, and none is built before Epic 4 (Story 4.3).
    evidence: |-
      AC4's own precondition is "when the panel is present", false for all of Epic 1. Its tokens
      already ship and are drift-tested (--ocu-panel-home, --ocu-motion-panel-width-duration;
      ui/src/styles/_metrics.scss:35-43, :64, :77-87). Route to the story that builds the panel,
      which owns both the Home width and the remembered width it restores on leaving.
    location: 'ui/src/styles/_metrics.scss:35-43 (tokens only; no consumer)'
    severity: medium
  - summary: >-
      A tile, and the locator's area segment, navigate into the area's first built screen
      without consulting that screen's own verdict, landing an allowed-area user on the
      refusal page instead of refusing in place as the side bar does.
    evidence: |-
      `screensForArea` is built-only, not verdict-filtered (navigation.ts:234-236), and
      `activate()` refuses on the area verdict alone (home.page.ts). Area and screen verdicts
      are independent sets in Screen/Gate.cls, so area-allowed/screen-denied is ordinary.
      side-bar.ts:219 refuses that same entry in place. Not patched: the I/O matrix specifies
      "router at the first built route", so changing the target is a spec-bound change. The
      pre-existing locator test that covered the screen-verdict case was replaced by the
      DW-143 area-verdict one, so the behavior is now unpinned too.
    location: 'ui/src/app/areas/home/home.page.ts (activate); ui/src/app/shell/locator-bar.ts (open)'
    severity: medium
  - summary: >-
      The command bar's filter-to-count pairing is now asserted in no state: the branch that
      emits `aria-describedby` is unreachable while `matchCount` returns `''`.
    evidence: |-
      The assertion that tied them (`expect(filter.getAttribute('aria-describedby')).toBe(count.id)`)
      was replaced by `expect(count.id).not.toBe('')`. Changing `filterDescribedBy` to return a
      literal that does not match `countId` leaves command-bar.spec.ts green. The first screen
      to give `matchCount` a value can therefore ship the dangling `aria-describedby` DW-141
      was filed for. Closing it needs a seam on `matchCount`; the story that implements a real
      count should add the row.
    location: 'ui/src/app/shell/command-bar.ts:158-182'
    severity: medium
  - summary: >-
      An unrecognised system mode is now ellipsized with no way to read it in full, and the
      clip reaches Home's instance line as well as the 24px status bar.
    evidence: |-
      DW-145's bound gives `.ocu-server-flag` `text-overflow: ellipsis` but, unlike the
      neighbouring `.ocu-status-bar-version`, no `title`. The `app-server-flag` host rule is a
      bare type selector, so Home's instance line clips too — two rules from where this story
      argues the opposite for the version ("page content with room to wrap"). Reachable only by
      a direct global write, which is why it is filed rather than patched.
    location: 'ui/src/styles/_components.scss (app-server-flag, .ocu-server-flag)'
    severity: medium
  - summary: >-
      DESIGN.md:1102 and EXPERIENCE.md give the tile caption as the area's screens so the
      contest task statement's parentheticals are visible on Home; rendering built screens only
      means all six ship empty, and nothing escalates that conflict where a later gate reads it.
    evidence: |-
      EXPERIENCE.md:157 (an unbuilt screen does not appear) and DESIGN.md:1102 (the caption
      exists so the contents are visible) cannot both hold while Home is the only descriptor.
      The spec records the build-only decision under Design Notes, but the document conflict
      itself has no ledger entry, so nothing revisits whether Home is meant to look empty at
      release. Related to DW-126/DW-139, both already escalated.
    location: '_bmad-output/planning-artifacts (DESIGN.md:1102 vs EXPERIENCE.md:157)'
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
| Tile activation | allowed area, with and without a built screen | with: router at the first built route **whose screen verdict allows**, gated when none does, current `?ns=` preserved (`withQuery`); without: no navigation. Both leave the side bar open on that area | a second activation never toggles it shut |
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
- `core/shell-state.ts:82-118` — `activateArea` (its toggle-shut branch is rail behavior, not tile behavior) and `setOpen`, which persists; `:82-90` already collapses without persisting, the precedent for DW-144.
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

### Review Findings

**2026-09-12 — code review (first review).** 4 layers, full-opus tier; 38 rows → 26 root-cause
entries: high 0, medium 7, low 19. All 7 mediums are patched or ledgered with an owner; nothing
is unresolved. The theme the dispatch asked for is real and recurs: **four declarations were
absent and held only because of where the element happened to sit** — the same shape as the
DW-145 host fix the implement stage found in its own work.

- [x] [Review][Patch] DW-145's cap was on the wrong box, so the ellipsis it promises is itself clipped — no global `box-sizing` reset exists, so `max-width: 100%` capped the *content* box and the pill's border box overran the clipping host by its 8px padding and 1px border. A 200-character mode ended in a cut word, not an ellipsis. `box-sizing: border-box`; `line-height` 18px → 16px so the 18px pill has no vertical overflow to clip [ui/src/styles/_components.scss:1425]
- [x] [Review][Patch] The pill's published `label` type role was inherited, not stated — it held in the 24px bar (`label`) and failed on Home's instance line (`caption`), so this story's second host drew the same badge two sizes and a weight apart from DESIGN.md `:1025` [ui/src/styles/_components.scss:1425]
- [x] [Review][Patch] The 24px icon slot had no `display`; a `<span>` is an inline box and ignores `width`/`height`, so DESIGN.md `:1102`'s geometry was a property of `.ocu-area-tile` being a flex container. `.ocu-rail-glyph`, which the comment cites as the precedent, does declare one [ui/src/styles/_components.scss:1523]
- [x] [Review][Patch] `overflow: hidden` moves an inline-block's baseline to its bottom margin edge — the story's own residual risk names this. `vertical-align: middle` on the host makes the placement a property of the rule rather than of two parents that happen to center their items [ui/src/styles/_components.scss:1419]
- [x] [Review][Patch] (Rule 19) The gated tile's "does not navigate" **URL** assertion could not fail: `permissions/users` was absent from the file's router table, so `router.url` could never leave `/`. The row reddened only through `visibleArea`. Target route added; the identical defect was fixed one row down by moving that row to `/logs` [ui/src/app/areas/home/home.page.spec.ts:200]
- [x] [Review][Patch] (Rule 19) DW-146's stylesheet pin carried the append hole the same pass had just closed for DW-145 — appending `text-overflow: ellipsis` inside `.ocu-instance-version` left three presence-only assertions green. `doesNotMatch` guards added [ui/tools/design-tokens.test.mjs]
- [x] [Review][Patch] (Rule 19) `showArea`'s one contentious behavior — replacing a stored `false` preference, which its doc comment spends a paragraph justifying — was asserted only from a default-open store [ui/tools/shell-state.test.mjs]
- [x] [Review][Patch] (Rule 19) QA's `resolveArchetypePage` guard suite had no `mutation:` row, and the roster's `&& !area.pinBottom` line said "red, alone" when it reddens two rows. Both demonstrated and written into `## Verification` [_bmad-output/implementation-artifacts/spec-1-12-home.md]
- [x] [Review][Patch] Two dead gated-state class bindings — `.ocu-area-tile-gated` and `.ocu-locator-link-gated` have no stylesheet rule and no test; both new surfaces style off `[aria-disabled='true']` instead. Bindings deleted (the attribute selector cannot drift from the state it styles) [ui/src/app/areas/home/home.page.ts:114, ui/src/app/shell/locator-bar.ts:95]
- [x] [Review][Patch] The harvest filed five new ledger entries and appended no `occurrence` to any root cause this story re-hit (Rule 15). `occurrence=1-12-home` appended to DW-126, DW-148, DW-149, DW-159 [_bmad-output/implementation-artifacts/deferred-work.md]
- [x] [Review][Defer] A screen's declared `archetype` is never validated against `ARCHETYPE_PAGES`, so a typo routes, builds and renders a blank content area with no message — indistinguishable today from the map comment's declared "an archetype with no entry renders nothing" — **DW-165**, routed to `2-4-the-data-table`, the first story that registers a second archetype [ui/src/app/shell/screen-outlet.ts:34]
- [x] [Review][Defer] Home ships with no heading, so EXPERIENCE.md `:583`'s "route changes move focus to the new screen's heading" has no target — the refusal path for `/` has an `<h1>`, the allowed path does not. Same root cause as the missing skip link: UX-DR68 is unimplemented and unowned. `occurrence=1-12-home` on **DW-149**; whether a screen carries a visible heading beside the locator is the owner's call at the decision sheet [ui/src/app/areas/home/home.page.ts]
- [x] [Review][Defer] **DW-148**'s evidence line — "closing it needs `ShellState` surface that does not exist" — is falsified by this story: `showArea()` is exactly that surface, and `locator-bar.ts`'s `open()` comment was rewritten in the same diff to drop the sentence. Corrected at the ledger, which is where a later gate reads it [_bmad-output/implementation-artifacts/deferred-work.md]

**For the lead's browser gate, beyond the three Manual checks.** The patches above changed the
flag pill's rendered height from 20px to 18px (border-box plus the 1px borders) and its type role
on Home from `caption` to `label`. Nothing executed observes either — check the pill in the 24px
bar **and on Home's instance line**, which the Manual checks list omits even though the Residual
risk paragraph names it.

**Rejected** — `false` on its refutation, `low` with why it was not worth fixing:

- `low` The spec frontmatter's AC4 deferral says "none is built before Epic 4 (Story 4.3)"; DW-160 and `epics.md:2404` say Epic 4 / Story 4.3. The routing target is right and the ledger is what a later gate reads; the fix edits this spec.
- `low` `## Auto Run Result`'s arithmetic is off — "`ng test` 146 green" (it is 146 since QA's test), "27 mutation lines (26 distinct)" (the roster carries 27 lines, 26 distinct), "seventeen entries patched (7 medium, 10 low)" (the triage log carries 17: 7 medium, 10 low). Narrative only; the fix edits this spec.
- `low` The frontmatter's DW-164 entry frames the conflict as EXPERIENCE.md `:157` (a *side-bar* rule) against DESIGN.md `:1102`. EXPERIENCE.md `:352` and DESIGN.md `:1102` agree with each other and both enumerate the names; the real conflict is those two against the build-only reading — which is exactly how DW-164's own ledger entry states it. `home.page.ts`'s citation of `:352` + `:157` is correct as written.
- `low` Design Notes says captions come from "the navigation payload"; they come from the generated mirror (`screensForArea` → `builtScreensForArea` → `SCREENS`), the payload contributing verdicts only. The behavior is right and Epic 2 cannot break it — the consequence worth carrying forward is that a descriptor must be **regenerated into `screens.generated.ts`** for its name to reach a caption; adding it server-side alone changes nothing on Home.
- `low` `wontfix-accepted` `ARCHETYPE_PAGES` holds statically imported components, so every area page joins the initial chunk; no AD covers lazy loading. Bounded by archetype count, not screen count. `reopen_if=ng build reports a bundle-budget warning` (`build-output.test.mjs` runs a real build).
- `low` `wontfix-theoretical` The DW-145/146 stylesheet extractions bind only the first rule carrying each selector. The regexes are line-anchored, so today's `.ocu-server-flag[data-flag='live']` and `:root.ocu-theme-dark .ocu-server-flag` do not defeat them; a second *bare* rule appended later would. Real when a second bare rule exists.
- `low` `wontfix-theoretical` A denial with an empty `failedPair` renders "Requires " naming no privilege. Shared verbatim with the rail since 1.9; no denial path in `Screen/Gate.cls` produces one. Real when a gate returns `allowed:false` with no pair.
- `low` Before the navigation map answers, `areaVerdict` defaults to `UNGATED` and every tile paints allowed. Pre-existing and identical on the rail; AD-8 puts the real refusal on the server.
- `low` The Integration AC's route-table assertion overlaps `app.routes.spec.ts`. It is the AC's own "not through a route-table entry naming the component" half and belongs where the AC is pinned.
- `low` `side-bar.spec.ts:419`'s `querySelector('nav')` is captioned about the preference but reopens regardless of it. True and supplementary; the claim is carried by `:420`, which reddens under the spec's named mutation.
- `low` DW-162 is labeled `in-epic` with an Epic 2 owner while DW-160 is `out-of-footprint` with an Epic 4 owner. The entry body is write-once and neither owner is wrong.
- `low` The spec more than doubled while flagged `oversized`. The fix edits this spec, which step 3 excludes; noted so the next re-open appends only open items.

## Spec Change Log

- 2026-09-12 (lead, Rule 5 amendment during Story 1.13's planning): the tile-activation row said "the first built
  route", which lands an allowed-area user on the refusal page whenever that screen's own verdict denies - the defect
  ledgered as DW-161. The row now reads "the first built route whose screen verdict allows, gated when none does".
  Story 1.13 implements it; this story's shipped behavior is the one the row previously described.

**Decision (implement) — the tile roster is derived, not enumerated.** Naming `home` and `agent` in the page would be a second source for the area vocabulary beside the mirror, so the filter reads the declaration: Home is the one area whose rail item `navigates`, Agent the one that is `pinBottom`. A ninth area takes a tile without editing the page.

**Decision (implement) — the DW-145 bound needed two properties beyond the four named.** All four ship, but `text-overflow` applies to a block container and the pill was `inline-flex`, so they were inert: the pill is now `inline-block` with an explicit `line-height`, and the `app-server-flag` host carries `display: inline-block` plus `min-width: 0` (review found the host had no `display`, which left the bound dependent on its parent being a flex container).

## Review Triage Log

### 2026-09-12 — Review pass

- verdicts: 37 findings — high 0, medium 16, low 20, false 1, maybe-false 0
- findings:
  - `[medium]` `[defer]` A tile navigates into a screen the map denies — verified: `screensForArea` is built-only and `activate()` refuses on the area verdict alone, while `side-bar.ts:219` refuses the same entry in place. Filed; the matrix specifies "the first built route", so retargeting is spec-bound.
  - `[medium]` `[patch]` The tile's accessible name will absorb the caption once areas have built screens, contradicting the doc comment — verified by reading the template: the caption spans are inside the `<button>`. Comment and test title corrected to state what is pinned.
  - `[medium]` `[defer]` All six captions ship empty, and the DESIGN.md/EXPERIENCE.md conflict behind that is escalated nowhere a gate reads — the empty rendering is the dispatch's stated intent; the unescalated document conflict is filed.
  - `[low]` `[patch]` `ARCHETYPE_PAGES[...] ?? null` walks the prototype chain — verified: `archetype` is free-form mirror text, so `constructor` would resolve to an inherited function and survive `?? null`. Replaced with `Object.hasOwn`.
  - `[low]` `[reject]` The DW-146 stylesheet rule is composed of initial values — true but harmless: it is a deliberate marker, and DW-146's real pin is the DOM assertion, which I demonstrated falsifiable. Deleting a documented marker is churn.
  - `[low]` `[patch]` Presence-only regexes survive re-adding `inline-flex` after `inline-block` — verified by applying exactly that append; the assertion stayed green. Added `assert.doesNotMatch`.
  - `[medium]` `[patch]` The DW-145 bound depends on an ambient layout fact — verified: every other `app-*` host sets an explicit `display`; this one did not, and an inline box ignores `min-width`/`overflow`. Added `display: inline-block`, asserted it.
  - `[medium]` `[patch]` The scope and session subscriptions are unpinned — verified: dropping either left all tests green while the namespace would freeze. Added a test; demonstrated its mutation.
  - `[medium]` `[defer]` `filterDescribedBy`'s positive branch is unreachable and the field-to-count pairing is now asserted in no state — filed; closing it needs a `matchCount` seam this story does not own.
  - `[medium]` `[patch]` The `UNGATED_SEGMENT` justification is factually wrong — verified against `app.ts`: the locator renders above `router-outlet`, so it is drawn over a refusal, not instead of one. Comment corrected in source and in the mirrored spec stub.
  - `[low]` `[reject]` A tile click rewrites the side-bar preference — by design: `activateArea`'s opening branch persists identically, and the Tasks item asks for an unconditional show-area-open entry.
  - `[low]` `[patch]` Home has no group semantics — six buttons with no set. Added `role="list"`/`role="listitem"`; roles carry no copy, so DW-126 does not block it.
  - `[false]` `[reject]` Spec frontmatter and body disagree on status — mid-run state only; finalize writes both.
  - `[low]` `[reject]` An already-`oversized` spec was grown further — the mutation roster and change-log decisions are both mandated by the dispatch; step 4 also rejects findings whose fix edits this build's spec. The two decision paragraphs were trimmed anyway.
  - `[low]` `[patch]` The stylesheet header's story list was stale — corrected to "1.7 through 1.12".
  - `[medium]` `[defer]` (edge case) Tile → denied first screen — same root cause as the first row.
  - `[medium]` `[defer]` (edge case) Locator area segment → denied first screen — same root cause as the first row.
  - `[low]` `[patch]` (edge case) Prototype-key archetype reaches `ngComponentOutlet` — same root cause as the `Object.hasOwn` row.
  - `[medium]` `[defer]` (edge case) The pill now ellipsizes with no `title`, and the clip reaches Home — filed; reachable only by a direct global write.
  - `[low]` `[reject]` (edge case) Whitespace-only values render a blank segment — no demonstrated source of a whitespace-only value, and the shipped status bar uses the same predicate; diverging here would be the inconsistency.
  - `[medium]` `[patch]` (verification gap) The locator's gated-reason reveal is unpinned at every tier — confirmed by grep. Added the `design-tokens.test.mjs` row and demonstrated its mutation.
  - `[medium]` `[defer]` (verification gap) The command bar's describedby-to-count linkage lost its only assertion — filed, per that layer's own disposition.
  - `[medium]` `[patch]` (verification gap) `expect(router.url).toBe('/')` cannot fail — verified: `withQuery('', '/')` is `/`. The row now starts at `/logs`; deleting the guard reddens it.
  - `[low]` `[patch]` (verification gap) The Enter/Space mutation was inert with respect to its criterion — replaced as primary with the `[disabled]` mutation, which genuinely removes keyboard activation.
  - `[low]` `[patch]` (verification gap) Two added tests were absent from the pinning roster, and the geometric criterion had no row — rows added.
  - `[low]` `[reject]` (verification gap) The "24px icon slot" size is asserted nowhere — the measure is the `--ocu-space-6` token, already pinned in the metrics tier; asserting the consumer too is not worth a row.
  - `[low]` `[reject]` (verification gap) "AC4" names different criteria in two places — the frontmatter wording is the plan's and the dispatch says keep it; the ambiguity is avoided in this section instead.
  - `[low]` `[reject]` (verification gap) The DW-145 re-layout has no executed-code verification — true and already routed to the lead's browser gate; it is this pass's named residual risk.
  - `[low]` `[reject]` (intent) Three rows' expectations sit at a surface no test reaches — the component-contract reading is chosen openly and labeled, not concealed.
  - `[medium]` `[patch]` (intent) DW-145's stated observable cannot fail — verified: `.ocu-status-bar` declares a fixed 24px height and does not wrap, so the height holds either way. The manual check now names the horizontal failure.
  - `[medium]` `[defer]` (intent) The DW-145 change is at a wider selector than the row places it — same root cause as the pill/`title` row.
  - `[low]` `[patch]` (intent) The roster invariant is unasserted — added assertions that exactly one area `navigates` and one is `pinBottom`.
  - `[low]` `[reject]` (intent) The caption's positive case is exercised only against a stub — unavoidable while Home is the only descriptor, and the spec header says so.
  - `[medium]` `[defer]` (intent) DW-141 lost the other branch's coverage — same root cause as the `filterDescribedBy` row.
  - `[low]` `[patch]` (intent) The keyboard criterion's test is markup, not behavior — same root cause as the Enter/Space mutation row.
  - `[low]` `[reject]` (intent) The live tier exercises the payload, not the page — no browser-runtime harness exists (DW-159); named as residual risk.
  - `[low]` `[patch]` (intent) "The running container serves a pre-1.10 bundle" is wrong — the served bundle carries 1.10 and 1.11 markers. Corrected below; the conclusion (a redeploy is needed) stands.

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

**Pinning tests** (Rule 19 — every mutation below was applied, observed red, reverted, and the tree confirmed byte-identical at the implement stage):

- Outlet renders Home by archetype (Integration AC) -- `screen-outlet.spec.ts`
  - mutation: keyed `ARCHETYPE_PAGES` on `list` instead of `home` → "Integration AC: an allowed screen renders the page its declared archetype names" red, alone in the suite
  - mutation (QA's extracted guard, demonstrated at review): `resolveArchetypePage` back to `pages[archetype] ?? null` → "the archetype map guard (Object.hasOwn, not a bare index)" red, alone
- Tile roster, order, Home/Agent absent -- `home.page.spec.ts`
  - mutation: dropped `&& !area.pinBottom` from the tile filter → "renders one tile per area in rail order, with Home and Agent co-pilot absent" red, together with the six-item list row
  - the same row asserts the invariant the derivation rests on (exactly one area `navigates`, one `pinBottom`), so a later area declared `navigates` fails as itself rather than as a label mismatch
  - mutation: dropped `role="list"` from the grid → "the grid is a list of six items" red, alone
- Gated tile focusable, `aria-disabled`, reason on hover and focus, activation refused -- `home.page.spec.ts`
  - mutation: bound `[disabled]="tile.gated"` on the tile → "a gated tile stays listed and focusable..." and the keyboard row both red
  - mutation: deleted `if (tile.gated) return;` from `activate()` → "a gated tile does not navigate and does not touch the side bar" red, alone
  - mutation (review): guarded only the side bar, `if (!tile.gated) this.shell.showArea(...)`, so a gated tile navigates → the same row red on its **URL** assertion. That half could not fail until the review added `permissions/users` to the file's router table
  - the reveal-on-focus half is stylesheet-only and is pinned in `design-tokens.test.mjs`; jsdom computes no layout _(inference: the browser gate below is what observes the reveal itself)_
- Tile caption from built screens, empty when none -- `home.page.spec.ts`
  - mutation: forced each caption part's `separated` to `false` → "a tile's caption is its area's built screen names, joined by aria-hidden separators" red, alone
- Tile activation with and without a built screen; `?ns=` preserved; side bar left open -- `home.page.spec.ts`
  - mutation: navigated with `'/' + tile.route` instead of `withQuery` → "activating a tile opens the area's first built screen and leaves the side bar open on it" red, alone
  - mutation: pointed `activate()` at `activateArea` instead of `showArea` → "a second activation never toggles the side bar shut" red, alone
  - mutation: deleted `if (!tile.hasScreen) return;` → "an area with no built screen still opens its list, and navigates nowhere" red, alone. That row began at `/`, where `withQuery('', '/')` is itself `/` and the assertion could not fail; it now starts at `/logs`
- Keyboard activation (Enter / Space) -- `home.page.spec.ts`
  - mutation: bound `[disabled]="tile.gated"` on the tile → "Enter and Space activate exactly as a click does, because the tile is a native button" red. This is the mutation that falsifies the criterion: a disabled button does not activate on either key. jsdom synthesizes no activation click, so the row asserts the native element that guarantees one
  - mutation: dropped the tile's explicit `type="button"` → the same row red, alone
- Instance line: five values, order, `aria-hidden` separators, version not truncated (DW-146) -- `home.page.spec.ts`
  - mutation: swapped the namespace and flag segments → "the instance line carries the five values in order" red, alone
  - mutation: bound `[attr.title]` on the version segment → the DW-146 row red, alone
  - mutation (review): appended `text-overflow: ellipsis` inside `.ocu-instance-version` → the `design-tokens.test.mjs` DW-146 row red, alone. Presence-only assertions survived the append, as DW-145's did before its own guard
  - mutation: dropped the scope subscription → "the line follows the scope and the session, not only the instance" red, alone. Story 1.11 made the namespace switchable, so a line read once at construction would name the namespace the user had just left
- DW-143 locator area segment refuses a denied area -- `locator-bar.spec.ts`
  - mutation: hard-coded the area verdict to allowed → the DW-143 row red, alone
  - mutation: dropped `|| segment.gated` from `open()`'s guard → the DW-143 row red, alone
  - mutation: deleted the `:focus-visible +` half of `.ocu-locator-reason`'s reveal → `design-tokens.test.mjs` "the locator's gated reason reveals on hover AND focus" red, alone. The reveal had no pin at any tier before this pass
- DW-144 Escape collapses without writing the preference -- `side-bar.spec.ts`
  - mutation: pointed `closeFromKeyboard` back at `toggleFromKeyboard()` → the DW-144 row red, alone
  - mutation: made `ShellState.collapse()` call `setOpen(false)` → `shell-state.test.mjs` "a dismissal collapses the bar without writing the preference (DW-144)" red, alone
  - mutation (review): made `showArea` set `currentOpen` directly instead of `setOpen(true)` → `shell-state.test.mjs` "a tile shows its area's list and never toggles it shut" red, alone. The contentious half — a tile replacing a stored `false` — had no pin until the review added one
- DW-145 `.ocu-server-flag` bounded and ellipsized -- `ui/tools/design-tokens.test.mjs`
  - mutation: deleted `max-width` from `.ocu-server-flag` → the DW-145 row red, alone
  - mutation: restored `display: inline-flex` → the DW-145 row red, alone; without `inline-block` the other four properties are inert
  - mutation: re-added `display: inline-flex` *after* `inline-block` — the append case, which last-declaration-wins made silently inert while a presence-only assertion stayed green → the DW-145 row red, alone
  - mutation: deleted `display: inline-block` from the `app-server-flag` host → the DW-145 row red, alone. A custom element is an inline box, which ignores `min-width` and `overflow`; without it the bound held only where a parent blockified the host
  - mutation (review): deleted `box-sizing: border-box` from `.ocu-server-flag` → the DW-145 row red, alone. With no global reset `max-width: 100%` caps the *content* box, so the pill's border box overran the clipping host by its padding and border and the ellipsis itself was cut off
  - mutation (review): deleted `vertical-align: middle` from the host → the DW-145 row red, alone. `overflow: hidden` moves an inline-block's baseline to its bottom margin edge
  - mutation (review): deleted `@include typo.ocu-type('label')` from `.ocu-server-flag` → the DW-145 row red, alone. The published `label` role was inherited, so the badge drew at `caption` on Home and `label` in the status bar
- The grid wraps on the declared minimum (the geometric criterion's stylesheet half) -- `ui/tools/design-tokens.test.mjs`
  - mutation: replacing `auto-fit` / `minmax(var(--ocu-tile-min-width), 1fr)` with a fixed track → "Home's tile grid wraps on the declared minimum" red. The wrap itself is geometry and stays the lead's browser gate _(inference: jsdom computes no layout, so no assertion here observes a reflow)_
  - mutation (review): deleted `display: inline-block` from `.ocu-area-tile-icon` → the same row red, alone. A `<span>` is an inline box and ignores `width`/`height`; the 24px slot held only because the tile is a flex container
- DW-141 no `aria-describedby` while the count is empty -- `command-bar.spec.ts`
  - mutation: made `filterDescribedBy` return the id unconditionally → the DW-141 description row red, alone
- No new string keys -- `ui/tools/strings.test.mjs` + `client-lint.mjs`
  - mutation: planted a literal `Instance details` text node in Home's template → `client-lint.mjs` exit 1, naming file, line and `no-literal-text-node`
  - mutation: added a `homeInstanceLabel` key to `strings.ts` → `strings.test.mjs` "the string source holds nothing the documents do not authorize" red, alone

**Live instance vs throwaway principals.** This story changes no ObjectScript, adds no `%UnitTest` class and needs no throwaway principal. The live check is a regression run of the two suites that already pin the payload the tiles consume — `OcuPilot.Test.Navigation`, then `OcuPilot.Test.Wire` (which mints its own throwaway `OcuPilotWire*` principals and deletes them in teardown) — each in its own `iris_execute_tests` call with `server: "ocupilot-iris"`, the second sent only after the first has landed in `%UnitTest_Result`. Do not recreate the `ocupilot` container.

**Manual checks (the lead's browser gate — jsdom computes no layout and there is still no browser-runtime harness, DW-159):**

- The tile grid wraps rather than scrolling horizontally at 1,280 / 1,024 / 900 px, keeping the 168px minimum and 8px gaps.
- The gated tile's reason appears on hover **and** on keyboard focus, and so does the locator area segment's — the same clipped-to-visible shape, added by DW-143.
- A 200-character system mode ellipsizes inside the pill and does not push the status bar's right-hand group off the viewport (DW-145). Not the bar's height: `.ocu-status-bar` declares `height: var(--ocu-status-bar-height)` and does not wrap, so 24px holds with or without this fix — the failure DW-145 describes is horizontal.

## Auto Run Result

Status: done
Blocking condition: none

**What this pass built.** `areas/home/home.page.ts` — six area tiles in the auto-fit grid, the
instance line beneath — and the archetype→component map in `screen-outlet.ts` that resolves it,
plus the four routed ledger items: DW-141's description half, DW-143's locator refusal, DW-144's
non-persisting Escape (two new `ShellState` entries, `showArea` and `collapse`), DW-145's bound on
the flag pill. DW-146 closes as a consequence of the instance line, not as a change of its own.
No server file, no string key, no descriptor.

**Files changed.** New: `areas/home/home.page.ts`, `areas/home/home.page.spec.ts`. Client:
`core/shell-state.ts` (`showArea`, `collapse`), `shell/screen-outlet.ts` (the archetype map),
`shell/locator-bar.ts` (the gated area segment), `shell/side-bar.ts` (Escape dismisses without
persisting), `shell/command-bar.ts` (the conditional description). Styles: `_components.scss` —
the Home section, the locator's gated reason, the flag pill's bound. Tests:
`screen-outlet/locator-bar/side-bar/command-bar.spec.ts` and
`tools/{design-tokens,shell-state}.test.mjs` extended.

**Review findings.** 37 findings across four layers — 0 high, 16 medium, 20 low, 1 false. Fifteen
entries patched in-pass (7 medium, 8 low), five filed to `deferred:`, the rest rejected on their
refutations; every finding has a row in the triage log above. The patches: the `app-server-flag`
host had no `display`, which left the DW-145 bound depending on its parent being a flex container;
`ARCHETYPE_PAGES` was indexed rather than `hasOwn`-checked, so a descriptor archetype spelled
`constructor` would have reached `ngComponentOutlet`; the new `UNGATED_SEGMENT` comment asserted
that a locator is never drawn over a refusal, which `app.ts` disproves; the tile doc comment
claimed an accessible name that will stop being true when captions fill; the grid had no list
semantics; and four verification holes — the locator's reason reveal was unpinned at every tier,
`expect(router.url).toBe('/')` could not fail, the scope and session subscriptions were unpinned,
and the DW-145 assertions survived re-adding `inline-flex` after `inline-block`.

**How it was verified.** `node --test tools/` 351 green; `ng test` 146 green across 15 files;
`client-lint: clean`; `screen-mirror: up to date`. Live regression, one class per call with
`server: "ocupilot-iris"`: `OcuPilot.Test.Navigation` 11/11 then `OcuPilot.Test.Wire` 13/13,
confirmed against `%UnitTest_Result` by the SQL probe in `.claude/rules/objectscript-testing.md`
rather than from the runner envelope. Every `mutation:` line above was applied by this agent,
observed red, reverted, and the tree confirmed byte-identical after each — 25 in all. The Matrix
Test Audit passed: each of the nine I/O rows has a covering test that ran and passed in this
pass's output.

**Residual risk (why a follow-up review is recommended).** The DW-145 fix changes real layout —
the pill moved from `inline-flex` to `inline-block` with an explicit `line-height`, and both it
and its host now clip — in the 24px status bar and on Home. No executed test observes rendering:
jsdom computes no layout, so the stylesheet tier asserts source text only. `overflow` other than
`visible` also moves an inline-block's baseline, invisible today only because both parents center
their items. That is the one changed rendering in this diff with no executed-code verification,
and it is what the browser gate must look at first.

**Left for the lead.** The Manual checks: the grid's wrap at 1,280 / 1,024 / 900 px, the gated
reason's reveal on hover and focus for both the tile and the locator, and a 200-character system
mode's behavior in the status bar. The running container serves a build that predates this story
— its bundle carries Story 1.10 and 1.11 markers but no `ocu-area-tile` — so the browser gate
needs a redeploy, which is the owner's call. The panel-widening criterion stays deferred in the
frontmatter, with four findings filed beside it.
