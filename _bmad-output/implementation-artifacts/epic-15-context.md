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
shell alone and adds no new screen area. **Stories 15.1 and 15.2 are done** and their landed
decisions are recorded below as constraints, not choices; **15.6 is deferred by owner decision**, so
the in-scope range is 15.3, 15.4 and 15.5.

## Stories

- Story 15.1: Change your own password — **done**
- Story 15.2: Favorites, recent items and menu search — **done**
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
  wording for the listed items. A preference kept only in `localStorage` fails the criterion rather
  than satisfying it cheaply, and a client test already bans `localStorage` outside the one module
  that owns it.
- **Everything new is filtered by what the user may reach**, and a gated entry stays listed and
  focusable naming the resource it needs — never removed, never natively disabled. That binds the
  shortcuts menu (16 fixed shortcuts), the links panel (documentation, support, InterSystems) and
  every favorite or recent row.
- **Home never scrolls horizontally at a supported width.** The System Information panel fits above
  or beside the area-tile grid, and the grid wraps rather than widening. Nothing is hidden by
  viewport width: the classic portal's "hide the panel below 1,100 px" behavior is explicitly
  rejected.
- **Build identity is chartered to 15.3 (DW-3, both halves):** a real build stamp — the installer
  currently ships the literal `dev` — and the stale-bundle reload prompt with its copy, which no
  planning document publishes yet. About is where build identity is displayed, so About owns the
  stamp and the prompt that compares against it. About's other fields are the classic page's
  system-overview set, read from instance identity plus license and journal settings; per-screen
  help opens that screen's documentation address; neither needs a new read of its own.
- **No inert control.** Every item added to a menu, panel or dialog ships with its handler.
- **Strings.** Every new user-facing string is published in the canonical UX string table **before**
  it exists as a client key, appended strictly after the current last row — the client's string
  source carries hard line-number comments back into that table, so an insertion above the tail
  breaks hundreds of them. The test demands exact set equality and globally unique values, so reuse
  an existing row rather than repeating a value; the literal-count band is widened with a comment
  naming the story when a story overruns it.
- **A password is a secret end to end** (15.1, landed): it never enters a log line, an exception, a
  `%Status`, a URL or an error message, because OcuPilot displays those logs itself.

## Technical Decisions

- **Privilege is the calling process's, checked at the moment of the call**, against a declared set
  of `(resource, permission)` pairs — never a single resource, never an elevation.
- **A self-service account action is the user's own write, outside the agent write path (AD-49,
  written by 15.1).** It mints no proposal, takes no confirm token, emits no agent marker and is
  never a tool; it calls the documented `%SYSTEM.*` method in the caller's own process. Landed:
  `POST /api/ocupilot/account/password` → `OcuPilot.Api.Account` calling
  `$System.Security.ChangePassword($Username, new, old, .tSC)`. The admin API's user-password route
  is the *administrator resets another user* case and belongs to Story 7.2. Where IRIS emits its own
  audit event for the operation, OcuPilot adds no second record. **A second direct mutation of an
  IRIS security object outside a port does not inherit this permission** — AD-49 sets four
  conditions it must show in its own Design Notes.
- **Per-user preferences are one `Kind`-discriminated store (AD-50, written by 15.2).** Landed:
  `OcuPilot.Kernel.State.Pref` in the protected database, unique on `(UserName, Kind, Name)`, on
  `Kernel/State/Base` so every write inherits the version-conditional guarded save. **15.5 extends
  it with further `Kind` values** — and a value property where one is needed — and never adds another
  `State` subclass: the 29-character cap on a `%Persistent` class name leaves 7 characters after
  `OcuPilot.Kernel.State.`. It is read and written through the caller-own shell-chrome route
  `GET`/`POST /api/ocupilot/account/preferences` (`OcuPilot.Api.Preferences`), **not** through a
  declared read, whose contract takes no per-caller argument; 15.5 adds members or a sibling route
  rather than a second per-user endpoint family. A preference is never screen context and never a
  tool's view.
- **Stored references to IRIS objects and screens are weak**: recorded as data, bound as SQL
  parameters, never a foreign key; a reference that no longer resolves degrades rather than failing
  the screen.
- **API preference order:** a documented official route first, the admin API second, a custom
  OcuPilot endpoint only where neither exists. Home's System Information maps to the dashboard route
  System usage already reads, plus production status.
- **Anything that lists rows goes through the descriptor-declared read** — one bounded read shared by
  screen and read tool, capped with truncation reported, secret-typed fields stripped — not a bespoke
  query. Shell chrome (About, the links panel, preferences) is the documented exception and uses
  caller-own handlers instead; none of it declares a screen descriptor, route, tool or proposal.
- **One error envelope** with a stable dotted code; a refusal, denial or fault is never a 500 and
  never an empty state. **A new violation code needs its arm in `Api/Error.cls`'s
  `ReasonForViolation` or its `reason` serializes empty.** Vendor text reaches a user only through an
  allow-list, and where a general-error code must be mapped it is mapped **site-scoped** — inside the
  one handler that knows what it just called — never allow-listed globally.
- **New REST routes are appended at the tail** of the router's `<Routes>` with a thin `Call=`
  wrapper; the ordering checker constrains only a prefix family, so a route sharing no prefix is
  unconstrained in position. Every new route also needs a wire test under `src/OcuPilot/Test/`
  carrying the four required markers — the build gate refuses the route without it. Adding an empty
  table needs no schema-version move.
- **Client shape:** Angular standalone, zoneless, `OnPush`; screen state is a store keyed by its
  descriptor. `ui/src/app/core/` imports no `@angular/core`, so a store there is a plain subscribable
  that components mirror into signals and release on destroy. Landed for 15.2:
  `core/account-preferences.ts` (instance-backed, request-counted so a late answer cannot overwrite a
  newer one, never cleared on a transport failure) — distinct from `core/preferences.ts`, which is
  the browser-storage store; and `shell/recents-recorder.ts`, a fire-and-forget visit recorder that
  never blocks or surfaces a navigation failure.
- **Auto-refresh is one framework and its roster is closed at seven screens.** Home's System
  Information panel is not among them.
- **Outbound links.** A list archetype never links back to the classic portal; only a detail may, and
  only under Release 1's single declared exemption. Help, the links panel and the shortcuts menu
  point at documentation and InterSystems destinations — confirm how the build-time classic-links
  checker treats each new outbound link before adding it.

## UX & Interaction Patterns

- **The account menu is the status bar's user segment** — the name with a ▾ glyph, styled as a
  row-overflow menu, the one interactive element in the bar. 15.1 landed **Change password** above
  Sign out **and the house n-item keyboard model** copied from the data table's menu: `tabindex="-1"`
  per `role="menuitem"`, wrap-around Arrow keys, Home/End, Escape closing and returning focus to the
  trigger. DW-115 is closed by that. The model is n-item by construction, so 15.6's toggle becomes a
  third item with no keyboard work.
- **Dialogs** are one level deep and never stack; Escape and Cancel close without effect; focus
  returns to the opener; the shell chords are inert while one is open. A server rejection sets
  `aria-invalid` with the message in `aria-describedby`, and a failed save focuses the error summary
  as an alert. The change-password dialog is the shared dialog component over two masked, write-only
  fields with labeled show/hide toggles.
- **Home layout.** The panel widens on Home; the six area tiles sit in an auto-fit grid that wraps
  under a one-line locator, with the instance line beneath. System information goes above or beside
  that grid — as 15.2's Favorites and Recent items blocks already do, each a `role="list"` of
  `role="listitem"` rows reusing Home's own keyboard model, with per-row remove and a Clear.
- **The System Information panel** reports uptime, mirror state, database, journal, lock and
  write-daemon alerts, and production status where the instance reports them. Color is never the only
  signal — each state carries its word.
- **Command box.** Opens on click or Ctrl/Cmd+K, filters every screen the user may open plus the
  current screen's command-bar actions, groups results under "Screens" and "Actions" with a polite
  count and an empty-result sentence, and Enter navigates or runs. **Menu search is this box and
  nothing else** — 15.2 satisfied it by ranking favorited screens first inside the Screens group, with
  no new input, group or count string. Adding a second search surface is a defect. Gated results
  render as non-selectable rows with the reason inline in the accessible name.
- **Announcements.** Polite `role="status"` for saves, counts, transitions and the favorites and
  recent-items confirmations; `role="alert"` (or moved focus) for sign-in and save failures and for
  403s. A favorite toggle lives beside the locator bar's screen heading, with `aria-pressed`.

## Cross-Story Dependencies

- **Upstream: Epic 1 alone.** The shell this epic extends is already built — header and command box,
  status bar with its account menu, Home with its tiles and instance line, the session and
  instance-identity calls, the design tokens and the string table. Epic 2's declared read, gate and
  list machinery are what any row-listing surface reuses; Epic 6's dashboard read is the precedent
  shape for 15.4's panel.
- **Within the epic:** 15.5 extends 15.2's `Pref` store and `/account/preferences` envelope, and
  inherits three escalated defects that are AD invariants rather than deferral candidates —
  **DW-1326** (a refused preference write reaches no surface; the client stub cannot refuse, and the
  announcement guards in the locator bar and Home are where a reason would go), **DW-1327** (the
  store's add and touch paths are check-then-insert, so concurrent adds trip the unique index, and
  the read-then-write cap check can store 21), and **DW-1328** (a Home block whose every stored row
  names no built screen shows its empty state with no Clear, leaving stored rows invisible and
  unclearable). 15.3's About displays the build identity DW-3 charters. 15.1's landed keyboard model
  governs any later account-menu item.
- **Range-end cleanup carries two 15.1 items:** DW-1289 (a password refused by a configured policy
  routine answers 500, to be fixed **site-scoped** inside the change-password handler so no other
  site gains a general-error channel) and DW-1290 (the wire test re-derives the code's own assumption,
  accepted with the residual stated in the test's doc comment).
- **Parallel runners and contended paths.** Epic 13 is merged onto this branch. Epic 5 is still in
  flight and owns `ui/src/app/shell/panel*`, `proposal-card`, `reply`, `tool-call-card`,
  `context-chip`, `core/proposal-view.ts` and `core/turn.ts`; Epic 15 works outside them. Epic 15's
  own shell surfaces are `header*`, `account-menu*`, `side-bar*`, `command-box*`, `locator-bar`,
  `recents-recorder` and Home. `src/OcuPilot/Api/Router.cls`, the UX string table and
  `ui/src/app/core/strings.ts` are under an epic-wide **shared-append** grant: append at the tail
  only, never reorder, never insert, never touch a line another epic added, and run
  `uv run scripts/check-objectscript.py` before every commit touching the router. `ui/src/styles/**`
  is shared — keep edits there minimal and never touch the token file, which 15.6 owns.
- **Deferred, tracked, not dropped:** Story 15.6 carries DW-39 (the dark class flip reaches only the
  colour roles with a Material counterpart, not the 34 OcuPilot-only ones) and DW-118 (the OcuPilot
  colour layer is theme-static, so components keep their light values in dark mode). Both stay with
  15.6; do not attempt either in 15.3–15.5.
