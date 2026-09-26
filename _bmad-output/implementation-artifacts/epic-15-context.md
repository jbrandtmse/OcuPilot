# Epic 15 Context: Shell conveniences and the theme

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Polish week: the user makes the portal their own. Stories 15.1 to 15.9 are done: own password,
favorites and recents, About/help/shortcuts/links, Home's System Information, UI state kept on the
instance, the light and dark theme, the rail's icons, readable list columns, and sign-out in the
header. What they shipped now constrains the last story. **15.10** replaces the header's reversed
lockup, whose transparent cut-out fringes against the navy chrome, with the navy-wordmark lockup on
a white rounded tile. The logo is the first thing a judge sees, so it has to look finished. It is
high priority and must merge before the submission cut.

## Stories

- Story 15.1: Change your own password (done)
- Story 15.2: Favorites, recent items and menu search (done)
- Story 15.3: About, help, shortcuts and the links panel (done)
- Story 15.4: Home's System Information panel (done)
- Story 15.5: UI state that survives a sign-out (done)
- Story 15.6: The light and dark theme (done)
- Story 15.7: The rail's icons (done)
- Story 15.8: Columns you can read (done)
- Story 15.9: Sign-out where people look, and no filter where there is nothing to filter (done)
- Story 15.10: The header logo on a white tile

## Requirements & Constraints

- **The asset.** The header draws `OcuPilot-Lockup-horizontal.png`, the navy-wordmark file the
  sign-in card already uses, on a white tile. The tile has rounded corners and even padding and is
  sized to sit inside the 48px header band. The reversed file
  (`OcuPilot-Lockup-horizontal-reversed.png`) is no longer drawn in the header.
- **Same in both themes.** The tile must look identical in light and dark. It must not draw
  `surface-container-lowest`, because that role re-points to `#0B0E10` in dark mode. The chrome
  itself stays navy and only deepens in dark mode (`shell` `#0F3A5F` becomes `shell-dark`
  `#0B2440`). The tile therefore needs a white that does not follow the theme.
- **Focus and link.** The focus ring surrounds the tile, not only the image. The link still goes
  Home, carries the `?ns=` it carries today, and keeps its accessible name `headerHomeLink`
  ("OcuPilot — Home"). No new user-facing string is expected.
- **Correct the docs at origin.** Both specs still describe the reversed file with no plate, and
  each place must now state the tile:
  - DESIGN.md: the `logo-lockup` frontmatter tokens (`asset`, `plate: none`), the `logo-lockup`
    component prose, the brand paragraph under Visual references, the rows for both lockup files
    in the references table, and the Do's and Don'ts row that forbids a white plate and forbids
    the navy file on the chrome.
  - EXPERIENCE.md: the `logo-lockup` component-pattern row.
  - `header.ts`'s doc comment, and the comment above `.ocu-header-lockup` in `_components.scss`
    (inference). Replace each wrong sentence rather than appending a correction.
- **Browser spec.** A browser spec pins that the header draws the navy lockup on a white tile.
- **Structural gate (DW-1337).** It walks every registry screen in both themes. CI's `browser` job
  fails only on a violation that is not in `ui/browser/structural-baseline.json`. When a fix makes
  an entry stale, delete that entry.
- **DW-151 (wontfix-accepted, still true).** The lockup is a CSS background on an empty anchor, so
  forced-colors mode drops it. Do not reopen it unless the change makes Home unreachable by sight.

## Technical Decisions

- **Theme convention.** The whole theme is `ocu-theme-dark` on `<html>`. It is set by
  `ui/src/app/core/theme.ts` and selected only in `ui/src/styles/_theme.scss`, which re-points
  every bare `--ocu-*` and `--mat-sys-*` role to its `-dark` twin. Components draw bare roles and
  never select on the theme. A value that does not follow the roles goes into `_tokens.scss` as a
  non-role token, never into a component rule. Any new non-role token is also registered in
  `NON_ROLE_TOKENS` in `ui/tools/design-tokens.mjs`, which keeps it out of the 64-role count. A
  literal color may appear only in `_tokens.scss`, and client-lint enforces that.
- **Client asset homes.** Global styles and tokens live in `ui/src/styles/`. The lockups are
  vendored in `ui/src/assets/lockup/`: no CDN (AD-47, NFR-10). Each is drawn as a CSS
  `background-image` `url()`, which is how the builder hashes the file and copies it into the
  bundle. `angular.json`'s `assets` array stays empty apart from the font licences. Radii come
  from `--ocu-radius-{sm,md,lg}` (4/6/12px) in `_metrics.scss`.
- **Shared-append files.** `_components.scss` and `strings.ts` accept appends at the tail and
  token substitutions only. Editing the existing `.ocu-header-lockup` rule in place is the story's
  own change: report it under `footprint_extensions:` (inference).
- **Browser specs run the deployed bundle.** Rebuild, then `docker cp` into the slot's throwaway
  before you read a result. Each context calls `resetRememberedState()` once.
- **Nothing server-side.** No ObjectScript, instance object or AD-53/AD-55 write is involved.

## UX & Interaction Patterns

- **Header band.** 48px on the gradient from `shell` to `shell-edge`. It carries the lockup at the
  left, 8px from the edge and aligned over the rail, then the 360px command box centred, then the
  namespace switch and the account button at the right. Header text is never drawn below 100%
  `on-shell`.
- **The lockup today.** The reversed file is drawn 32px tall and about 156px wide (the source is
  623×128), with no plate and no hover state. The sign-in card draws the navy file at 40px on its
  white card, and that treatment is the reference for the navy file's rendering.
- **Focus ring on the chrome.** `focus-ring.on-chrome`: 2px `focus-ring-dark` outside a 2px `shell`
  halo in both modes. The light-mode `focus-ring` is never drawn on the chrome. The ring shows on
  `:focus-visible` only.
- **Why the plate came back.** The navy wordmark measures 1.02:1 against `shell`, so the navy file
  can never sit bare on the chrome. The tile is the ground that makes it legible.

## Cross-Story Dependencies

- 15.10 runs alone on **slot B**: profile `ocupilot-slot-b`, throwaway `ocupilot-b-ci` on
  52777/1976. It builds on 15.9's header layout (`header.ts`, `account-menu.ts`) and on 15.6's
  theme scope and token pairs. It must not disturb either.
- The sign-in card (`sign-in.ts`, `.ocu-signin-lockup`) already draws the navy file. Keep its
  rendering unchanged.
