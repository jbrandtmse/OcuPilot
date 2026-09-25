# Epic 15 Context: Shell conveniences and the theme

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Polish week: the user makes the portal their own. Stories 15.1 to 15.7 are done: own password,
favorites and recents, About/help/shortcuts/links, Home's System Information, UI state kept on the
instance, the light and dark theme, and the rail's icons. Their results are now constraints, not
choices. Two stories remain, run by one runner on slot A, 15.8 first. **15.8** makes list columns
readable: widths follow the content, columns can be resized, and a cut value shows in full.
**15.9** puts sign-out where people look for it and removes the filter from screens with nothing to
filter. Together they make the shell read as finished to a first-time judge.

## Stories

- Story 15.1: Change your own password (done)
- Story 15.2: Favorites, recent items and menu search (done)
- Story 15.3: About, help, shortcuts and the links panel (done)
- Story 15.4: Home's System Information panel (done)
- Story 15.5: UI state that survives a sign-out (done)
- Story 15.6: The light and dark theme (done)
- Story 15.7: The rail's icons (done)
- Story 15.8: Columns you can read
- Story 15.9: Sign-out where people look, and no filter where there is nothing to filter

## Requirements & Constraints

- **15.8 widths.** A column's default width follows what it holds: identifier and code columns
  are wide, status and number columns narrow. The header label sets each column's minimum and is
  never cut. When the columns are wider than the content area, the table scrolls horizontally
  inside its own frame, with the sticky header aligned to the body. Data tables are the one
  two-dimensional reflow exception, and the page never scrolls sideways.
- **15.8 resizing.** Dragging a header edge resizes the column, never below its label. The
  keyboard can do the same on the grid's active column, the binding is listed in the shortcuts
  menu, and the new width is announced. A width the user sets is restored on return and after a
  sign-out, stored per screen on the instance beside sort, filter and max rows. It is never kept
  in browser storage.
- **15.8 cut values.** A cut cell shows its whole value in a tooltip when the pointer rests on it
  or the active cell moves onto it. A cell that is not cut shows none. A bare `title` attribute
  never carries the value, because it cannot be reached by keyboard (DW-146).
- **15.8 row geometry.** Row and header heights never change on resize or scroll: the virtual list
  has a fixed row height, and the browser specs that pin both heights must stay green.
- **15.8 owns DW-1586.** A data-table name link renders narrower than the 24px control floor
  (devices 7.2px, users 21.6px). The floor is that every control is at least 24×24 CSS px. The
  issue accounts for 4 structural-baseline keys, which this story fixes and deletes.
- **Docs to correct at origin for 15.8 (inference).** Interaction Primitives says "No drag except
  the panel-resize-handle", and the keyboard-model table has no column binding. Both conflict with
  the ACs and need amending in EXPERIENCE.md.
- **15.9 header account button.** The header's right end, beside the namespace switch, carries a
  button naming the signed-in user. It opens the account menu: About, Change password, Dark theme
  and Sign out, with the same actions they have today. The status bar keeps the user name as
  information only, so the menu has one trigger.
- **15.9 Sign out command.** Typing "sign out" in the command search offers a Sign out command,
  which signs out exactly as the menu does.
- **15.9 filter removal.** Screens that declare no read show no filter field and no match count:
  Home, the form pages and the application-error drill-down. A command bar left with nothing to
  show does not render at all. List screens keep their filter.
- **15.9 docs at origin.** EXPERIENCE.md's status-bar and Sign out rows must state the header
  placement, and the Sign out row's `[ASSUMPTION]` about a command-box entry is resolved. DESIGN.md
  says "Nothing else lives in the header" and calls the user the status bar's one interactive
  segment (inference: both need the same correction). Browser specs pin four things: the header
  button opens the menu, it signs out, Home shows no filter field, and a list still filters.
- **15.9 owns DW-1597 (decided).** Suppress the change toast raised by the open screen's own Save.
  Keep it for agent writes and for writes made elsewhere. DESIGN.md's toast recipe forbids a toast
  confirming what the user just did on the open screen.
- **Strings.** A new user-facing string is appended to EXPERIENCE.md's Fixed strings table before
  it exists as a `strings.ts` key. The test requires exact set equality and globally unique values.
  "Sign out" already exists (`actionSignOut`). A resize handle's name, the width announcement and
  any tooltip copy do not.
- **Structural gate (DW-1337).** It walks every registry screen in both themes. CI's `browser` job
  fails only on a violation outside `ui/browser/structural-baseline.json`, which currently holds
  212 entries. A fixed violation is printed as stale while the job stays green. Delete that entry.
- **Bundle.** At the Epic 9 merge the bundle measured 1,576,591 B, just under `maximumWarning`
  (1577kB). `maximumError` is 2000kB. Stop and ask before crossing 1900kB. The warning re-base
  policy is unchanged.

## Technical Decisions

- **Client shape (AD-19).** The client is standalone, zoneless and `OnPush`. Per-screen sort,
  filter, max rows and selection live in a store keyed by the screen's descriptor, never in a
  component field. `ui/src/app/core/` imports no `@angular/core`: its stores are plain
  subscribables that components mirror into signals.
- **Per-user preferences (AD-50).** They live in one Kind-discriminated store,
  `OcuPilot.Kernel.State.Pref`, read and written through the caller-own preferences endpoint and
  never through a declared read, screen context or a tool. The per-screen table view is the
  existing `view` kind, keyed by route (inference: column widths extend that value rather than
  adding a kind or a class). Writes are version-conditional, and a lost race is a 409
  `STATE.CONFLICT`.
- **Columns come from the descriptor's `table` declaration (AD-5).** It gives each column's label
  key and kind. `screens.generated.ts` is emitted by `ui/tools/screen-mirror.mjs` and is never
  hand-edited. Grid tracks derive from the declared column kinds so that the Databases free-space
  cells fill without a reflow, and content-sized widths must keep that property.
- **Sign-out (AD-28, AD-31).** `POST /api/ocupilot/logout` carries both the Bearer and the cookie,
  ends the browser-level login, and first abandons the caller's running turns. The new header
  button and the command reuse the existing path. There is no tab-only variant.
- **Change events (AD-14).** An editor's Save still publishes on the bus, so the open screen
  re-fetches and highlights. DW-1597 suppresses only the toast.
- **Theme and tokens.** Components draw bare `--ocu-*` and `--mat-sys-*` roles and never select on
  `ocu-theme-dark`. No literal color appears outside `_tokens.scss`, and client-lint's hex regex
  applies.
- **Browser specs run against the deployed bundle.** Rebuild and `docker cp` into the throwaway
  (`ocupilot-ci`, 52776) before reading any geometry result. Each context calls
  `resetRememberedState()` once, from `ui/browser/preferences-reset.mjs`.
- **AD-53 and AD-55 do not apply.** Neither story writes to an instance object.

## UX & Interaction Patterns

- **Data table.** It is Material on CDK virtual scroll, inside a 1px `outline-variant` frame. The
  header row is 36px, sticky, in `label` type and `on-surface-variant`. Identifier columns (name,
  path, class, resource, pid) use `code` type. Numbers are tabular and right-aligned. The name cell
  is a `secondary` link, and the last column is the 28px ⋮ trigger. There is no page-size control.
- **Grid keyboard (APG).** The whole grid is one Tab stop, and focus stays on the container with
  `aria-activedescendant`. Up and Down move the row, Right and Left step into cells, and
  Alt/Option+Down opens the row menu. Resizing must fit this model without taking a Tab stop of its
  own (inference).
- **Tooltips** use `inverse-on-surface` on `inverse-surface`, `rounded.sm`, 5px 8px padding,
  `caption` type and elevation 2. They show on hover and on focus.
- **Header.** It is 48px on the shell gradient: the lockup on the left, the 360px command box in
  the center, and the namespace switch on the right. Header text is never drawn below 100%
  `on-shell` (5.35:1 light and 6.43:1 dark on `shell-edge`), and focus uses
  `focus-ring.on-chrome`. The account menu keeps the `row-overflow-menu` styling.
- **Command bar.** Its height is a minimum: it wraps rather than scrolling sideways at the 640px
  content minimum. The filter field is 220px and its match count is a polite status. The command
  box groups results as Screens and Actions and states the count "<n> screens, <m> actions".
- **Toast.** It appears at the bottom right of the content area, clear of the panel, stacks three
  deep, and is `role="status"`. It is never used for errors or for the open screen's own action.

## Cross-Story Dependencies

- **Order.** 15.8 runs first, then 15.9, in one runner on slot A (`ocupilot-slot-a`). 15.8 builds
  on 15.5's `view` kind and 15.3's shortcuts menu. Epics 7 and 9 have merged, including their edits
  to `data-table*`, `command-bar*`, `command-box*` and `app.ts`.
- **Epic 12 runs on slot B and modifies `ui/src/app/app.ts`.** Treat that file as a contended edit:
  read the other branch first, append only, and report it under `footprint_extensions:`.
  `status-bar*`, `account-menu*` and `header*` are untouched by other epics.
- **Shared-append files** are edited at the tail only, never reordered or inserted into:
  - `src/OcuPilot/Api/Router.cls`
  - `src/OcuPilot/Api/Error.cls`
  - the EXPERIENCE.md Fixed strings table
  - `ui/src/app/core/strings.ts`
  - `_components.scss`, where a token substitution is also permitted
- **Shared-create:** `ui/browser/**`. A new, uniquely named spec there is reported under
  `footprint_extensions:`.
- **Not owned here.** The other baseline items (DW-1583, DW-1584 and DW-1587, for the panel
  handle, the status bar at 720px and native checkboxes) belong to range-end cleanup.
