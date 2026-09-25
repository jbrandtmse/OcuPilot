# Epic 15 Context: Shell conveniences and the theme

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Polish week: the user makes the portal their own. Stories 15.1 to 15.8 are done: own password,
favorites and recents, About/help/shortcuts/links, Home's System Information, UI state kept on the
instance, the light and dark theme, the rail's icons, and readable list columns. What they shipped
is now a set of constraints. One story remains. **15.9** moves sign-out to where web applications
put it, removes the filter from screens that have nothing to filter, and closes three routed items:
the toast raised by the open screen's own Save, a pinned row-action column, and a hardened
row-click test helper. It is the last step in making the shell read as finished to a first-time
judge.

## Stories

- Story 15.1: Change your own password (done)
- Story 15.2: Favorites, recent items and menu search (done)
- Story 15.3: About, help, shortcuts and the links panel (done)
- Story 15.4: Home's System Information panel (done)
- Story 15.5: UI state that survives a sign-out (done)
- Story 15.6: The light and dark theme (done)
- Story 15.7: The rail's icons (done)
- Story 15.8: Columns you can read (done)
- Story 15.9: Sign-out where people look, and no filter where there is nothing to filter

## Requirements & Constraints

- **Header account button.** It sits at the header's right end, beside the namespace switch, and
  names the signed-in user. It opens the account menu: About, Change password, Dark theme and Sign
  out, each doing what it does today. The status bar still shows the user name, but only as
  information, so the menu has one trigger.
- **Sign out command.** Typing "sign out" in the command search offers a Sign out command. It
  signs out exactly as the menu does, and it resolves the `[ASSUMPTION]` about a command-box entry
  in the Sign out row.
- **Filter removal.** A screen that declares no read shows no filter field and no match count. That
  covers Home, the form pages and the application-error drill-down. A command bar left with nothing
  to show does not render. List screens keep their filter unchanged.
- **Correct the docs at origin.** EXPERIENCE.md's status-bar and Sign out rows must state the header
  placement. DESIGN.md says "Nothing else lives in the header" and calls the user the status bar's
  one interactive segment; both need the same correction (inference). Browser specs pin four
  things: the header button opens the menu, it signs out, Home shows no filter field, and a list
  still filters.
- **DW-1597 (decided).** Suppress the change toast raised by the open screen's own Save. Keep it
  for agent writes and for writes made elsewhere.
- **DW-1648 (decided: pin).** Pin the row-action (⋮) column to the table frame's right edge, so the
  row menu is visible without scrolling sideways. Leave column widths as 15.8 set them. At 1280px
  with the panel open, about 24 of the 38 tables are wider than the frame. The "Trigger reach"
  spec's two "starts past the frame" assertions in `data-table-columns.browser-spec.mjs` change with
  this. The DW-1337 gate must still find no overlap or overflow in either theme.
- **DW-1649.** `clickRowCentre` in `ui/browser/list-spec.mjs` measures and clicks in separate round
  trips, so a re-render in between misclicks and the caller times out on the row trigger. Add a
  capture-phase `pointerdown` probe that checks the target is inside the wanted row, identified by
  its first cell's text, and names the miss. It has 25 caller files, and every one must be run.
- **Strings.** Append a new user-facing string to EXPERIENCE.md's Fixed strings table before it
  becomes a key in `strings.ts`. The test requires exact set equality and globally unique values.
  "Sign out" already exists as `actionSignOut`.
- **Structural gate (DW-1337).** It walks every registry screen in both themes. CI's `browser` job
  fails only on a violation that is not in `ui/browser/structural-baseline.json`, which now holds
  208 entries. When a fix makes an entry stale the job stays green but prints it; delete the entry.
  Of the remaining baseline items, DW-1583, DW-1584 and DW-1587 belong to range-end cleanup.
- **Bundle.** After 15.8 it measures 1,590,556 B. `maximumWarning` is 1670kB and `maximumError`
  2000kB. Stop and ask before going past 1900kB.

## Technical Decisions

- **Client shape (AD-19).** The client is standalone, zoneless and `OnPush`. Per-screen view state
  lives in a store keyed by the screen's descriptor. `ui/src/app/core/` imports no `@angular/core`;
  components mirror its plain subscribables into signals.
- **Reads decide the filter.** Whether a screen declares a read comes from its descriptor.
  `screens.generated.ts` is emitted by `ui/tools/screen-mirror.mjs` and is never hand-edited.
- **Sign-out (AD-28, AD-31).** `POST /api/ocupilot/logout` sends both the Bearer and the cookie. It
  abandons the caller's running turns and then ends the browser-level login. The header button and
  the command reuse this path, and there is no tab-only variant.
- **Change events (AD-14).** An editor's Save still publishes on the bus, so the open screen
  re-fetches and highlights the row. DW-1597 suppresses only the toast.
- **Preferences (AD-50).** Column widths, sort, filter and max rows are the route-keyed `view`
  kind, stored on the instance and never in browser storage.
- **Theme and tokens.** Components use bare `--ocu-*` and `--mat-sys-*` roles and never select on
  `ocu-theme-dark`. A literal color appears only in `_tokens.scss`, which client-lint's hex regex
  enforces.
- **Browser specs run the deployed bundle.** Rebuild and `docker cp` into the throwaway
  (`ocupilot-ci`, 52776) before reading a result. Each context calls `resetRememberedState()` once.
- **AD-53 and AD-55 do not apply.** This story writes no instance object.

## UX & Interaction Patterns

- **Header.** It is 48px on the shell gradient: the lockup at the left, the 360px command box in the
  center, and the namespace switch at the right. Header text is never drawn below 100% `on-shell`,
  and focus uses `focus-ring.on-chrome`. The account menu keeps the `row-overflow-menu` styling.
- **Command bar and box.** The bar's height is a minimum and it wraps rather than scrolling sideways
  at 640px. The filter is 220px and its match count is a polite status. The box groups its results
  under Screens and Actions and states "<n> screens, <m> actions".
- **Toast.** It appears at the content area's bottom right, stacks three deep and uses
  `role="status"`. It is never used for errors or for the open screen's own action.
- **Data table after 15.8.** Default widths follow the column kind: name and identifier 240px, text
  160px, number and status 112px. Each is floored at its header label plus a 12px sort slot, and
  a column the user sized keeps its width. Columns scroll sideways inside the frame with the sticky
  36px header following the body, and the page never scrolls sideways. A 24px `col-resize` hit
  area sits on each data column's right edge. Alt/Option+Shift+Left or Right resizes the active
  cell's column by 16px, does nothing at row level or on the ⋮ cell, and announces the new width. A
  cut cell's tooltip follows the tooltip recipe, and no cell carries a `title`. The last column is
  the 28px ⋮ trigger. The grid is one Tab stop driven by `aria-activedescendant`, and
  Alt/Option+Down opens the row menu.

## Cross-Story Dependencies

- 15.9 runs alone on slot A (`ocupilot-slot-a`). It builds on 15.3's About and shortcuts, 15.1's
  change password, 15.6's theme toggle and 15.8's column model (`table-model.ts`,
  `data-table*`).
- **Shared-append files.** Edit these only at the tail, and never reorder or insert: `Router.cls`,
  `Error.cls`, the EXPERIENCE.md Fixed strings table, `ui/src/app/core/strings.ts` and
  `_components.scss`. A token substitution is also allowed in `_components.scss`.
- **Contended and shared-create files.** Treat `ui/src/app/app.ts` as a contended edit: read the
  other branches first and append only. A new spec under `ui/browser/**` needs a unique name. Report
  both under `footprint_extensions:`.
