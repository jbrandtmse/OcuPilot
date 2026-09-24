# Epic 15 Context: Shell conveniences and the theme

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Polish week: the user makes the portal their own. Stories 15.1 to 15.6 are done: own password,
favorites and recents, About/help/shortcuts/links, Home's System Information, UI state kept on the
instance, and the light and dark theme. Their results are now constraints, not choices. **15.7** is
next. It replaces the rail's letters with the area icons drawn in the Home mockup, and Home's tiles
get the same icons, so a screenshot reads as a finished product rather than a wireframe. **15.8**
(columns you can read) is not in this run. Epic 7 has merged, so it is released, but it runs later
on its own, ranked after Epic 12.

## Stories

- Story 15.1: Change your own password (done)
- Story 15.2: Favorites, recent items and menu search (done)
- Story 15.3: About, help, shortcuts and the links panel (done)
- Story 15.4: Home's System Information panel (done)
- Story 15.5: UI state that survives a sign-out (done)
- Story 15.6: The light and dark theme (done)
- Story 15.7: The rail's icons
- Story 15.8: Columns you can read (not in this run; separate later dispatch)

## Requirements & Constraints

- **15.7 icons.** Each of the eight rail items takes the icon drawn for its area in the rail of
  `ux-designs/ux-OcuPilot-2026-09-08/mockups/key-home.html`. The items are Home, Logs, OS
  management, Tasks, Permissions, Web applications and REST API explorer, Security and secrets, and
  Agent co-pilot. Each icon is inline SVG on a 20×20 view box with a 1.5 stroke in `currentColor`,
  and no letter remains. Home's six area tiles take the 24px version of the same icon. Nothing
  loads from outside the bundle.
- **State colors come only through `currentColor`, in both themes.** The contrast figures are
  DESIGN.md's `rail-item` rows, light / dark on `shell`:
  - rest: `on-shell` at 72%, 6.15:1 / 7.31:1
  - hover and active: `on-shell` at 100%
  - gated: `on-shell` at 45%
  - tile icon: `primary`; gated tile icon: `restrained`

  The attention dot sits at the icon's top-right, drawn in `agent-accent-dark` with a 1.5px `shell`
  ring and offset 2px. The contrast floor is 3:1 for non-text and 4.5:1 for text, the same in both
  modes.
- **The icons are decorative.** A screen reader hears only the area name, which is the
  `aria-label` on a rail item and the visible name on a tile. Nothing is announced from the SVG.
- **Correct the docs at origin when 15.7 completes.** DESIGN.md's `rail` paragraph must name the
  mockup's icons in place of the interim Material Symbols set (UX-DR15, amended 2026-09-23).
  EXPERIENCE.md's rail row still reads "Placeholder icons until the owner's icon work lands"
  (inference: the same correction belongs there). The other interim-glyph slots (empty states,
  inline notices, sign-in) are out of scope and keep the vendored Material Symbols placeholder.
  Never draw an initial in a circle.
- **The DW-1337 structural gate now covers every change.**
  `ui/browser/a11y-structural-invariants.browser-spec.mjs`, using `structural-walk.mjs`, walks every
  built screen from the registry in both themes. It checks accessible names, control minimum
  widths, overflow and text contrast against `ui/browser/structural-baseline.json`, which holds 190
  entries. CI's `browser` job fails only on a violation outside the baseline. If a change removes a
  baseline violation, the gate prints that entry as stale and stays green, and the entry should be
  deleted. The gate fails on a visit that does not settle within 20s.
- **Strings.** A new user-facing string is appended to EXPERIENCE.md's Fixed strings table before it
  exists as a `strings.ts` key. The test requires exact set equality with globally unique values.
  15.7 should need none, because the area names and the "<Area> · Ctrl+B toggles the side bar"
  tooltip already exist.

## Technical Decisions

- **The theme is one root class (Conventions › Theme).** `ocu-theme-dark` on `<html>` is the whole
  theme. `core/theme.ts` sets it and `_theme.scss` selects it, re-pointing every bare `--ocu-<role>`
  and `--mat-sys-*` variable to its `-dark` twin. A component draws bare roles and never selects on
  the theme. Where a surface's variant is reversed between modes, the fix is a non-role token pair
  in `_tokens.scss`, never a component rule. Chrome rules that name `-dark` tokens
  (`secondary-dark`, `focus-ring-dark`, `agent-accent-dark`) keep doing so in both modes.
- **The theme choice is stored on the instance.** It is the `shell` kind's `theme` member
  (`light`/`dark`) in AD-50's single per-user store, `OcuPilot.Kernel.State.Pref`. Any other value
  gets a 422 `PREFERENCES.CHOICE`. It is a self-service account action (AD-49): no proposal, no
  marker, no tool. Light is the default until the read settles. Never use browser storage.
- **Assets are vendored and lint-checked (AD-47, NFR-10).** client-lint's `no-hardcoded-color` hex
  regex flags `#` followed by 3, 4, 6 or 8 hex characters, so no SVG id or fragment may look like a
  hex color (DW-40). `no-off-origin-url` allowlists the `w3.org` SVG, XHTML and XLink namespace
  URIs and nothing else.
- **Client shape (AD-19).** The client is Angular standalone, zoneless and `OnPush`.
  `ui/src/app/core/` imports no `@angular/core`: stores are plain subscribables that components
  mirror into signals.
- **Design tokens only.** No literal color appears outside `_tokens.scss`.
- **Browser specs run against the deployed bundle.** Rebuild and redeploy before reading any
  geometry or contrast result. Each context resets remembered state once with
  `resetRememberedState()` from `ui/browser/preferences-reset.mjs`, which also clears `theme`.
- **AD-53 and AD-56 (Epic 7) do not touch this story.** They govern the paths through which a
  screen action and an agent write reach an instance object. The rail and Home do not write.

## UX & Interaction Patterns

- **Rail.** The rail is 48px wide on `shell` in both modes, and the chrome only deepens in dark
  mode (`shell-dark`). Each item has a 48×48 hit area with a 20px icon centered in it. The rail is
  one Tab stop: Up and Down move between items, and Enter or Space activates. The active item
  carries `aria-current="page"`. Its tooltip, shown on hover after 300ms and on focus, reads
  "<Area> · Ctrl+B toggles the side bar". The active indicator is a solid 3px `secondary-dark` bar,
  inset 8px top and bottom, never a gradient. Hover adds an `on-shell` background at 8%. A gated
  item stays focusable with `aria-disabled="true"`, has no hover state, and shows a "Requires
  <resource>" tooltip. Focus is drawn with `focus-ring.on-chrome`. The rail never shows counts.
- **Area tiles.** The tiles sit in an auto-fit grid that wraps, and Home never scrolls
  horizontally. Each tile has a 24px `primary` icon above the area name, in caption weight 500,
  with its screens beneath. On hover the border turns `secondary`. A gated tile draws its text and
  icon in `restrained`, has no hover state, and shows the resource tooltip.

## Cross-Story Dependencies

- **15.7 builds on 15.6.** Its state colors must hold in both themes, and the structural gate from
  15.6 walks the rail and Home on every run.
- **Paths.** 15.7 edits `ui/src/app/shell/rail*` and `ui/src/app/areas/home/**`. Neither Epic 7
  nor Epic 8 touches them (measured 2026-09-23). Epic 9 is running on slot A in parallel. Never
  regenerate `screens.generated.ts`.
- **Shared-append files** are edited at the tail only, never reordered or inserted into:
  - `src/OcuPilot/Api/Router.cls`
  - `src/OcuPilot/Api/Error.cls`
  - the EXPERIENCE.md strings table
  - `ui/src/app/core/strings.ts`
  - `_components.scss`, where a token substitution is also permitted
- **Shared-create:** `ui/browser/**`. A new, uniquely named spec there is reported under
  `footprint_extensions:`.
- **15.8 is out of this run.** It depends on 15.5's store for per-screen widths. It must also
  address DW-1586: data-table name links render narrower than the 24px floor, which is already in
  the structural baseline.
