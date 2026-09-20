# Epic 15 Context: Shell conveniences and the theme

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Polish week. A user makes the portal their own: they change their own password without leaving for
the classic portal, keep favorites and recent items, find any screen through the one finder the
shell already has, open About, per-screen help, the fixed shortcuts menu and the links panel, see
the instance's state on Home, and come back the next morning to the sort, filter, panel width and
side-bar state they left behind. It is the last of FR-73's shell conveniences, and its unifying
constraint is that per-user state lives on the instance rather than in the browser, because the
browser deliberately holds nothing persistent but a per-tab token pair. The epic depends on Epic 1's
shell alone and adds no new screen area.

## Stories

- Story 15.1: Change your own password
- Story 15.2: Favorites, recent items and menu search
- Story 15.3: About, help, shortcuts and the links panel
- Story 15.4: Home's System Information panel
- Story 15.5: UI state that survives a sign-out
- Story 15.6: The light and dark theme — **DEFERRED, out of scope for this epic.** Owner decision:
  sequenced after Epic 5 merges, because it edits the `ui/src/styles/**` token files Epic 5 is
  concurrently editing and its contrast guards run in both modes. It stays in `backlog`, the
  orchestrator dispatches it later, and an Epic 15 run that reports done without it is correct. Do
  not build it, and do not pre-build a theme toggle for it.

## Requirements & Constraints

- **Per-user state lives on the instance, not in browser storage.** That is the acceptance
  condition behind favorites, recents, the context-sharing toggle and every item in 15.5 (per-screen
  sort, filter, max rows and auto-refresh rate; side-bar open state; panel width). The UX documents
  describe several of these as "remembered per browser"; 15.5 is the story that supersedes that
  wording for the listed items. The browser keeps only the per-tab token pair, which is deliberately
  not persistent.
- **The password change runs as the signing-in user.** No service account, no elevation anywhere on
  the request path. Fields are masked, never pre-filled, never echoed back. A rejected password shows
  the instance's own policy reason, not a generic failure.
- **A password is a secret end to end**: it never enters a log line, an exception, a `%Status`, a URL
  or an error message, because OcuPilot displays those logs itself and the agent reads them.
- **One finder, not two.** Menu search extends the existing command box over screens and the current
  screen's actions. Adding a second search surface is a defect, not a feature.
- **Everything new is filtered by what the user may reach**, and a gated entry stays listed and
  focusable naming the resource it needs — never removed, never natively disabled.
- **Home never scrolls horizontally at a supported width.** The System Information panel fits above
  or beside the area-tile grid, and the grid wraps rather than widening. Nothing is hidden by
  viewport width: the classic portal's "hide the panel below 1,100 px" behavior is explicitly
  rejected.
- **Build identity is chartered to 15.3 (DW-3, both halves):** a real build stamp — the installer
  currently ships the literal `dev` — and the stale-bundle reload prompt with its copy, which no
  planning document publishes yet. About is where build identity is displayed, so About owns the
  stamp and the prompt that compares against it.
- **No inert control.** Every item added to a menu, panel or dialog ships with its handler.
- **Strings.** Every new user-facing string is added to the canonical string table with its key in
  one pass; the test demands exact set equality and unique values, so reuse an existing row rather
  than repeating a value.

## Technical Decisions

- **Privilege is the calling process's, checked at the moment of the call**, against a declared set
  of `(resource, permission)` pairs — never a single resource. A denial names the pair that failed.
  The one permitted elevation is the protected-state one, and it is not in effect while tool, port or
  provider code runs.
- **OcuPilot's own state is a dedicated database behind a resource no ordinary role holds** — data
  only; the code stays in the install namespace's normal database. That is where a per-user
  preferences store belongs. No architecture decision names such a store today, so 15.2 introduces
  it and 15.5 extends it; treat its shape as this epic's to establish.
- **Stored references to IRIS objects are weak**: the scoped identity is recorded as data, never as a
  foreign key; a reference that no longer resolves renders as "no longer present" rather than failing
  the screen; the retention sweep drops state whose principal is gone. A favorite or recent pointing
  at a deleted screen target must degrade, not throw.
- **API preference order:** a documented official route first, the admin API second, a custom
  OcuPilot endpoint only where neither exists. Change password maps to the admin API's user-password
  route; About's system-overview fields come from the calls the header and status bar already make
  plus license and journal settings; Home's System Information maps to the dashboard route System
  usage already reads, plus production status.
- **Anything that lists rows goes through the descriptor-declared read** — one bounded read shared by
  screen and read tool, capped with truncation reported, secret-typed fields stripped from the tool's
  view — not a bespoke query. A declared read may name OcuPilot's own protected state as its source
  kind, which changes where rows come from and nothing else.
- **Client shape:** Angular standalone, zoneless, `OnPush`; screen state is a store keyed by its
  descriptor, never a component field. `ui/src/app/core/` imports no `@angular/core`, so a store
  there is a plain subscribable that components mirror into signals and release on destroy.
  Cross-screen communication is the change-event bus and the router, nothing else.
- **One error envelope**; a refusal, denial or fault is never a 500 and never an empty state.
- **Auto-refresh is one framework and its roster is closed at seven screens.** Home's System
  Information panel is not among them; a screen joins only by declaring it in its descriptor *and*
  appearing in that roster.
- **Outbound links.** A list archetype never links back to the classic portal; only a detail may, and
  only under a declared exemption, of which Release 1 has exactly one (OAuth 2.0). Help, the links
  panel and the shortcuts menu point at documentation and InterSystems destinations rather than at
  classic pages — confirm how the build-time classic-links checker treats each new outbound link
  before adding it.
- **Routes** carry the namespace as data scope, and an entity id is percent-encoded into exactly one
  path segment. Each screen descriptor names the classic page it replaces, by normalized class name,
  or says explicitly that it has none.

## UX & Interaction Patterns

- **The account menu is the status bar's user segment** — the name with a ▾ glyph, styled as a
  row-overflow menu, the one interactive element in the bar. 15.1 adds Change password beside Sign
  out; the theme toggle joins it later. **Adding a second menu item trips DW-115's stated reopen
  condition:** the menu ships `role="menu"` / `role="menuitem"` with no arrow, Home/End or roving
  tabindex model, accepted only while it held a single item, and the UX documents define an arrow
  model for the side bar and table rows but none for menus. Expect to settle that keyboard model.
- **Change password is a dialog.** Dialogs are one level deep and never stack; Escape and Cancel
  close without effect; focus returns to the opener; the shell chords are inert while one is open.
  The fields follow the masked-secret pattern: a password input with a labeled show/hide toggle,
  write-only, the value never returned. A server rejection sets `aria-invalid` with the message in
  `aria-describedby`, and a failed save focuses the error summary as an alert.
- **Home layout.** The panel widens on Home; the six area tiles sit in an auto-fit grid that wraps to
  a second or third row under a one-line locator, with the instance line beneath. System information,
  favorites and recents go above or beside that grid.
- **The System Information panel** reports uptime, mirror state, database, journal, lock and
  write-daemon alerts, and production status where the instance reports them. Color is never the only
  signal — each state carries its word.
- **Command box** opens on click or Ctrl/Cmd+K, filters every screen the user may open plus the
  current screen's command-bar actions, groups results under "Screens" and "Actions" with a polite
  count and an empty-result sentence, and Enter navigates or runs. It is not a channel to the agent.
  Gated results render as non-selectable rows with the reason inline in the accessible name.
- **Announcements.** Polite `role="status"` for saves, counts and transitions; `role="alert"` (or
  moved focus) for sign-in and save failures and for 403s.

## Cross-Story Dependencies

- **Upstream: Epic 1 alone.** The shell this epic extends is already built — header and command box,
  status bar with its account menu and sign-out, Home with its tiles and instance line, the session
  and instance-identity calls, the design tokens and the string table. Epic 2's declared read, gate
  and list machinery are what any row-listing surface here reuses, and Epic 6's dashboard read is the
  precedent shape for 15.4's panel.
- **Within the epic:** 15.2 establishes the per-user store that 15.5 extends (and that 15.6's theme
  choice will later use); 15.3's About displays the build identity DW-3 charters, which the
  stale-bundle prompt compares against; 15.1 and the deferred 15.6 both land in the account menu, so
  15.1's keyboard model decision governs both.
- **Parallel runners.** Epic 5 owns `ui/src/app/shell/panel`, `proposal-card`, `reply` and
  `tool-call-card`; Epic 15 works outside them. Its own shell surfaces are `header*`,
  `account-menu*`, `side-bar*` and `command-box*`. `ui/src/app/core/**` and `ui/src/styles/**` are
  shared with other epics in flight — expect reconciliation at merge, and keep edits there minimal.
- **Deferred, tracked, not dropped:** Story 15.6 carries DW-39 (the dark class flip reaches only the
  colour roles with a Material counterpart, not the 34 OcuPilot-only ones) and DW-118 (the
  OcuPilot colour layer is theme-static, so components keep their light values in dark mode). Both
  stay with 15.6; do not attempt either in 15.1–15.5.
