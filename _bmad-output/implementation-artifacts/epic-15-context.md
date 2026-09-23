# Epic 15 Context: Shell conveniences and the theme

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Polish week: the user makes the portal their own. Stories 15.1 to 15.5 are done: own password,
favorites and recents, About/help/shortcuts/links, Home's System Information, and UI state kept on
the instance. Their results are now constraints, not choices. Three stories remain. **15.6** adds
the dark theme the community asked for, as a toggle that flips one flag over complete token sets.
**15.7** swaps the rail's letters for the drawn area icons, so screenshots stop looking like a
wireframe. **15.8** makes list columns readable. The current run covers **15.6 then 15.7** on slot
B. **15.8 is not in it**: it waits for Epic 7 to merge, because Epic 7 is editing the shared data
table.

## Stories

- Story 15.1: Change your own password (done)
- Story 15.2: Favorites, recent items and menu search (done)
- Story 15.3: About, help, shortcuts and the links panel (done)
- Story 15.4: Home's System Information panel (done)
- Story 15.5: UI state that survives a sign-out (done)
- Story 15.6: The light and dark theme
- Story 15.7: The rail's icons
- Story 15.8: Columns you can read (dispatched after Epic 7 merges; not in the 15.6/15.7 run)

## Requirements & Constraints

- **15.6: the dark token set does not exist yet, and building it is the story's work.** The AC was
  amended on 2026-09-23. The dark scope (`:root.ocu-theme-dark`) re-points only the 30
  `--mat-sys-*` roles and redefines none of the 34 `--ocu-*` roles, so every OcuPilot color keeps
  its light value in dark mode (DW-39, DW-118). The one component rule that names a `-dark` token,
  `.ocu-server-flag`, computes a pairing that never occurs. Define all 34 dark values from
  DESIGN.md's `-dark` column, so the toggle stays a flag flip rather than per-component
  re-theming.
- **Contrast floor is the same in both modes**: 4.5:1 for text, 3:1 for non-text and focus. The
  guards in `ui/tools/design-tokens.test.mjs` run in both modes, including its three marginal
  guards. One of those is the 4.497:1 dark pair: the gated caption on a keyboard-active menu row,
  which is remedied by drawing it in `on-secondary-container`.
- **Light is the default on first load.** The toggle sits in the status bar's account menu beside
  Change password. The choice persists **per user on the instance** across a sign-out, never in
  browser storage.
- **The chrome stays navy in dark mode and only deepens** (`shell-dark` `#0B2440`). Anything drawn
  on the chrome uses its dark variant in both themes: the focus ring is `focus-ring-dark` with a
  `shell` halo, the attention dot is `agent-accent-dark`, and the rail indicator and any other teal
  on the chrome is `secondary-dark`. The light `focus-ring` measures 1.18:1 on the shell and is
  never drawn there. `code-surface` is dark in both modes.
- **15.6 carries DW-1337's owner-approved structural gate.** One registry-driven walk covers every
  declared screen and runs the contrast guard alongside three checks: every input, select and
  textarea has an accessible name; no interactive control is narrower than its declared minimum;
  no element overflows its container. It runs in **baseline form**: the baseline is taken once
  from the current tree, and each baseline entry becomes its own ledger item routed to the epic
  that owns the screen, or to range-end cleanup. CI fails only on a violation outside the
  baseline, so the gate is a ratchet. **15.6 fixes nothing the gate finds** unless the fix is a
  token inside its own footprint. DW-1388 enters the baseline already diagnosed: the agent panel
  overflows by about 22px at 720px. DW-1335 and DW-1336 are owner-reported and tagged for the same
  baseline.
- **15.7 icons.** The eight rail items take the icons drawn in the rail of
  `ux-designs/ux-OcuPilot-2026-09-08/mockups/key-home.html`. Each is inline SVG on a 20×20 view
  box with a 1.5 stroke in `currentColor`, and no letter remains. Home's tiles take the 24px
  version of the same icon. Every state's color comes through `currentColor`, in both themes:
  - rest: `on-shell` at 72%
  - hover and active: 100%
  - gated: 45%
  - tile icon: `primary`; gated tile: `restrained`

  The icons are decorative, so a screen reader hears only the area name. Nothing loads from outside
  the bundle. When 15.7 completes, DESIGN.md's `rail` paragraph must name the mockup icons in place
  of the interim Material Symbols set (UX-DR15 as amended 2026-09-23). The other interim-glyph
  slots (empty states, inline notices, sign-in) are out of scope.
- **15.8 columns.**
  - Default widths follow content: identifier and code columns wide, status and number columns
    narrow.
  - A header label is never cut; it sets the column's minimum width.
  - Overflow scrolls horizontally inside the table frame, with the sticky header aligned. The page
    body never scrolls sideways.
  - Columns resize by drag, and by keyboard on the active column. The binding is listed in the
    shortcuts menu, and the new width is announced.
  - The width is stored per screen, next to sort, filter and max rows.
  - A cut cell shows the full value in a tooltip on hover **and** when the grid's active cell
    lands on it. An uncut cell shows none. A bare `title` attribute is never used (DW-146), and
    hover-only affordances are banned.
  - Row height (36px) and header height stay fixed under virtual scroll.
- **Strings.** Every new user-facing string (the toggle's label, the resize announcement) is
  published in EXPERIENCE.md's Fixed strings table, appended after the current last row, before it
  exists as a `strings.ts` key. The test demands exact set equality and globally unique values.
- **No inert control.** Every menu or control item ships with its handler.

## Technical Decisions

- **Per-user state has one store (AD-50).** It is `OcuPilot.Kernel.State.Pref`, one row per
  `(UserName, Kind, Name)`, and 15.5 gave it a `Value` column. Its kinds are `favorite`, `recent`,
  `view`, `refresh` and `shell`, where `shell` has a closed member set. It is read and written
  through `GET`/`POST /api/ocupilot/account/preferences` and the client store
  `core/account-preferences.ts` (`setValue`, `loaded()`, `fault()`).
  - The theme choice (15.6) and column widths (15.8) extend this store and envelope.
  - Never add a new `State` subclass (the 29-character class-name cap leaves 7 characters), and
    never add a second per-user route.
  - Never use `localStorage`: 15.5 removed the preference carve-out, and the ban in
    `ui/tools/api.test.mjs` may only get stricter.
  - An empty `%String` value stores as SQL `NULL` and never matches again, so the handler refuses
    it with a 422.
- **Theme choice is a self-service account action (AD-49).** It is the user's own write. It mints
  no proposal, takes no confirm token, emits no agent marker, and is never a tool.
- **Token layer.** The token files live under `ui/src/styles/`. Material 3 is configured through
  `mat.theme($config, $overrides)`, which fixes the `--mat-sys-*` prefix. 15.6 owns the four token
  files exclusively: `_tokens.scss`, `_theme.scss`, `_metrics.scss` and `_typography.scss`
  (inference: the orchestrator's carve names "four token files" beside `_components.scss`).
  `_components.scss` is shared-append (tail only), except that a token substitution is permitted
  there.
- **Assets are vendored in the bundle; nothing comes from a CDN** (AD-47, NFR-10). client-lint
  enforces `no-hardcoded-color` and `no-off-origin-url`. Its hex regex flags any `#` followed by 3,
  4, 6 or 8 hex characters, including an SVG fragment or sprite id (DW-40), so inline-SVG ids must
  not look like hex colors.
- **Client shape.** Angular standalone, zoneless, `OnPush`. `ui/src/app/core/` imports no
  `@angular/core`: stores are plain subscribables that components mirror into signals.
- **Browser specs run against the deployed bundle.** Rebuild and redeploy before reading any
  geometry or contrast result. jsdom computes no layout, so geometry belongs in `ui/browser/`.
  Every spec signs in as the same account, so reset the value kinds per context with
  `ui/browser/preferences-reset.mjs`.
- **CI bundle budget.** The owner pre-approved DW-1166's budget for this run.

## UX & Interaction Patterns

- **Account menu.** It opens from the status bar's user segment and is styled as
  `row-overflow-menu`. It currently holds Sign out and Change password; the theme toggle joins
  them.
- **Rail items.** Each has a 48×48 hit area with a 20px icon centered in it. `aria-label` is the
  area name, `aria-current="page"` marks the active item, and the tooltip reads
  "<Area> · Ctrl+B toggles the side bar". A gated item stays focusable with
  `aria-disabled="true"` and a "Requires <resource>" tooltip. The active indicator is a solid 3px
  `secondary-dark` bar, never a gradient. The attention dot sits at the icon's top-right corner.
- **Area tiles.** A 24px icon in `primary` sits above the area name. Tiles wrap in an auto-fit
  grid, and Home never scrolls horizontally.
- **Data table.** It is an APG grid: one Tab stop, and focus stays on the container with
  `aria-activedescendant`. Left and Right step through a row's cells. The header is sticky and
  36px tall. EXPERIENCE.md currently says "No drag except the panel-resize-handle", and DESIGN.md
  calls the panel "the only resizable edge in the shell". 15.8's column drag contradicts the first
  statement, so correct that sentence where it is written. The polite `role="status"` region
  carries announcements such as the new width.
- **Announcements.** Use `role="status"` for saves, counts and transitions. Use `role="alert"` for
  save failures and 403 responses; a refused preference write, surfaced through `fault()`, takes
  that form.

## Cross-Story Dependencies

- **15.6 comes before 15.7.** 15.7's state colors must meet contrast "in both themes" at the
  ratios DESIGN.md's `rail-item` rows record.
- **15.6 and 15.8 depend on 15.5's store.** 15.6 adds the theme preference and 15.8 adds the
  per-screen width to that store's value kinds.
- **Epic 5 is not merged.** It still owns these paths, which Epic 15 does not edit:
  - `ui/src/app/shell/panel.ts` and `panel.spec.ts`
  - `proposal-card*`, `reply*` and `tool-call-card*`
  - `core/proposal-view.ts` and `core/turn.ts`

  DW-1388's overflow is inside that carve. Never regenerate `screens.generated.ts`.
- **Epic 7 is editing `ui/src/app/shell/data-table*`.** That is why 15.8 waits for Epic 7 to
  merge. The current runner stops before integrating if Epic 7 merges mid-run. Epic 7 has not
  touched the rail, Home or 15.6's token files; its `_components.scss` change is an append.
- **Shared-append files** (tail only, never reorder or insert): `src/OcuPilot/Api/Router.cls`,
  `src/OcuPilot/Api/Error.cls`, the EXPERIENCE.md strings table, `ui/src/app/core/strings.ts` and
  `_components.scss`.
- **Shared-create:** `ui/browser/**`. A new, uniquely named spec there is reported under
  `footprint_extensions:`.
