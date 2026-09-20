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
shell alone and adds no new screen area. **Stories 15.1, 15.2 and 15.3 are done** and their landed
decisions are recorded below as constraints, not choices; **15.6 is deferred by owner decision**, so
the in-scope range is 15.4 and 15.5.

## Stories

- Story 15.1: Change your own password — **done**
- Story 15.2: Favorites, recent items and menu search — **done**
- Story 15.3: About, help, shortcuts and the links panel — **done**
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
  focusable naming the resource it needs — never removed, never natively disabled. That bound 15.3's
  shortcuts and links and binds every row the System Information panel renders from a privileged
  read.
- **Home never scrolls horizontally at a supported width.** 15.2 and 15.3 landed **four** blocks
  above the auto-fit area-tile grid — Favorites, Recent items, Shortcuts, Links. **15.4's System
  Information panel is a fifth**, and its own acceptance criterion is that with all of them present
  Home still fits above or beside the grid and **wraps rather than widening** at every supported
  width. Nothing is hidden by viewport width: the classic portal's "hide the panel below 1,100 px"
  behavior is explicitly rejected.
- **15.4 owns uptime and mirror state, because 15.3 declined them.** About deliberately carries
  eleven of the classic About page's fourteen fields and declines three: **mirror state** and **time
  system started (uptime)** on the express ground that Story 15.4's panel owns them and there must be
  one source for each, so About will never show them and the panel must; and **cluster support**,
  declined outright on its own ground (its only accessor is `[ Internal ]` and returns untranslated
  vendor prose rather than data) — that one is not 15.4's to resurrect.
- **Build identity is closed.** DW-3's two halves landed in 15.3: the installer records the deployed
  bundle's hashed `main-*.js` name in the version row, and the client compares its own, showing a
  polite Reload prompt only when both sides name a hashed bundle and they differ.
- **No inert control.** Every item added to a menu, panel or dialog ships with its handler.
- **Strings.** Every new user-facing string is published in the canonical UX string table **before**
  it exists as a client key, appended strictly after the current last row (15.3's) — the client's
  string source carries hard line-number comments back into that table, so an insertion above the
  tail breaks hundreds of them. The test demands exact set equality and globally unique values, so
  reuse an existing row rather than repeating a value; the literal-count band is widened with a
  comment naming the story only when a story overruns it.
- **A password is a secret end to end** (15.1, landed): it never enters a log line, an exception, a
  `%Status`, a URL or an error message, because OcuPilot displays those logs itself.

## Technical Decisions

- **Privilege is the calling process's, checked at the moment of the call**, against a declared set
  of `(resource, permission)` pairs — never a single resource, never an elevation.
- **A self-service account action is the user's own write, outside the agent write path (AD-49,
  written by 15.1).** It mints no proposal, takes no confirm token, emits no agent marker and is
  never a tool; it calls the documented `%SYSTEM.*` method in the caller's own process. Landed:
  `POST /api/ocupilot/account/password` → `OcuPilot.Api.Account`. **A second direct mutation of an
  IRIS security object outside a port does not inherit this permission** — AD-49 sets four
  conditions it must show in its own Design Notes.
- **Per-user preferences are one `Kind`-discriminated store (AD-50, written by 15.2).** Landed:
  `OcuPilot.Kernel.State.Pref` in the protected database, unique on `(UserName, Kind, Name)`, on
  `Kernel/State/Base` so every write inherits the version-conditional guarded save. **15.5 extends
  it with further `Kind` values** — and a value property where one is needed — and never adds another
  `State` subclass: the 29-character cap on a `%Persistent` class name leaves 7 characters after
  `OcuPilot.Kernel.State.`. It is read and written through the caller-own route
  `GET`/`POST /api/ocupilot/account/preferences` (`OcuPilot.Api.Preferences`), **not** through a
  declared read; 15.5 adds members or a sibling route rather than a second per-user endpoint family.
  A preference is never screen context and never a tool's view.
- **Shell chrome is caller-own, and 15.3 set the shape to copy.** Landed: `GET /api/ocupilot/ui/about`
  and `GET /api/ocupilot/ui/help` as `OcuPilot.Kernel.Shell.About` (payload) plus `OcuPilot.Api.UiAbout`
  (thin handler), reproducing `Kernel/Shell/Instance.cls`'s per-field `ReadSource` seam with each
  caller wrapping its own read in `Try` so one refused source degrades that field to `""` and logs,
  never a 500, and switching to `%SYS` only by explicit save/restore. **15.4's panel is a further Home
  block and follows this precedent rather than inventing one**: shell chrome declares no screen
  descriptor, tool, proposal or auto-refresh, and where the panel needs instance state it reuses the
  dashboard read Epic 6's System usage screen already declares — plus production status — or extends
  the `Kernel/Shell/*` + `Api/Ui*` pair. One caveat 15.3 measured: some vendor accessors set their own
  `$ZTrap` and return `0` or `""` instead of throwing, so a per-field `Try` does not catch them and a
  broken value renders as a plausible number rather than a blank.
- **API preference order:** a documented official route first, the admin API second, a custom
  OcuPilot endpoint only where neither exists.
- **Stored references to IRIS objects and screens are weak**: recorded as data, bound as SQL
  parameters, never a foreign key; a reference that no longer resolves degrades rather than failing
  the screen.
- **Anything that lists rows goes through the descriptor-declared read** — one bounded read shared by
  screen and read tool, capped with truncation reported, secret-typed fields stripped — not a bespoke
  query. Shell chrome (About, help, the links panel, preferences) is the documented exception.
- **One error envelope** with a stable dotted code; a refusal, denial or fault is never a 500 and
  never an empty state. **A new violation code needs its arm in `Api/Error.cls`'s
  `ReasonForViolation` or its `reason` serializes empty**, and a field-level code outside the
  `AGENT.*` family is pinned over the wire rather than by the violation-code sweep. Vendor text
  reaches a user only through an allow-list, and a general-error mapping is **site-scoped** — inside
  the one handler that knows what it just called — never allow-listed globally.
- **New REST routes are appended at the tail** of the router's `<Routes>` with a thin `Call=`
  wrapper; the ordering checker constrains only a prefix family. Every new route needs a wire test
  under `src/OcuPilot/Test/` carrying the four required markers, **and a matching probe row in
  `src/OcuPilot/Test/EndpointCoverage.cls` or CI's `instance` job reddens** — that one has bitten
  this branch twice, at the Epic 13 merge and again at 15.3's code review. Adding an empty table
  needs no schema-version move.
- **Client shape:** Angular standalone, zoneless, `OnPush`; screen state is a store keyed by its
  descriptor. `ui/src/app/core/` imports no `@angular/core`, so a store there is a plain subscribable
  that components mirror into signals and release on destroy. The house instance-backed store shape —
  request-counted so a late answer cannot overwrite a newer one, a generation counter so an answer
  resolved for a departed principal cannot land on the next, never cleared on a transport failure —
  is landed three times over (`core/account-preferences.ts`, `core/about.ts`, `core/help.ts`); copy
  it, do not re-derive it.
- **Auto-refresh is one framework and its roster is closed at seven screens.** Home's System
  Information panel is **not** among them: it settles with its own read, and adds no timer.
- **Outbound links.** A list archetype never links back to the classic portal; only a detail may, and
  only under Release 1's single declared exemption. The build-time classic-links checker reads
  ObjectScript descriptors only, so it never sees a chrome anchor; the house pattern for one is
  `target="_blank" rel="noreferrer"` with the external glyph, and nothing on a chrome surface fetches
  off-origin.

## UX & Interaction Patterns

- **The account menu is the status bar's user segment** — the name with a ▾ glyph, the one
  interactive element in the bar. It now holds three items in order: **About**, Change password, Sign
  out, over the house n-item keyboard model (per-`menuitem` `tabindex="-1"`, wrap-around Arrows,
  Home/End, Escape returning focus to the trigger). The model is n-item by construction, so 15.6's
  toggle becomes a fourth item with no keyboard work.
- **Dialogs** are one level deep and never stack; Escape and Cancel close without effect; focus
  returns to the opener; the shell chords are inert while one is open. A server rejection sets
  `aria-invalid` with the message in `aria-describedby`, and a failed save focuses the error summary
  as an alert.
- **Home layout.** The panel widens on Home; the area tiles sit in an auto-fit grid that wraps under
  a one-line locator, with the instance line beneath. The four landed blocks sit above that grid,
  each a `role="list"` of `role="listitem"` rows reusing Home's own keyboard model — the removable
  ones with per-row remove and a Clear, the fixed ones (Shortcuts, Links) without. System information
  goes above or beside the grid as a fifth block of the same shape.
- **The System Information panel** reports uptime, mirror state, database, journal, lock and
  write-daemon alerts, and production status where the instance reports them. Color is never the only
  signal — each state carries its word, and a dashboard state word (Normal / Warning / Troubled) is
  rendered as the source reports it rather than translated, the precedent System usage's meters set.
- **Help** is a locator-bar control beside the screen heading, present only for a built screen whose
  descriptor names a classic page, opening that page's own documentation address in a new tab.
- **Command box.** Opens on click or Ctrl/Cmd+K, filters every screen the user may open plus the
  current screen's command-bar actions, groups results under "Screens" and "Actions" with a polite
  count and an empty-result sentence. **It is the one finder** — adding a second search surface, or a
  second roster that behaves like one, is a defect. Gated results render as non-selectable rows with
  the reason inline in the accessible name.
- **Announcements.** Polite `role="status"` for saves, counts, transitions, the favorites and
  recent-items confirmations and the stale-bundle reload prompt; `role="alert"` (or moved focus) for
  sign-in and save failures and for 403s.

## Cross-Story Dependencies

- **Upstream: Epic 1 alone.** The shell this epic extends is already built — header and command box,
  status bar with its account menu, Home with its tiles and instance line, the session and
  instance-identity calls, the design tokens and the string table. Epic 2's declared read, gate and
  list machinery are what any row-listing surface reuses; **Epic 6's dashboard read is the precedent
  shape for 15.4's panel data**, and 15.3's `/ui/about` pair is the precedent shape for a chrome read.
- **Within the epic:** 15.4 delivers the uptime and mirror state 15.3's About declined, and is the
  fifth Home block beside 15.2's and 15.3's four. 15.5 extends 15.2's `Pref` store and
  `/account/preferences` envelope, and inherits three escalated defects that are AD invariants rather
  than deferral candidates — **DW-1326** (a refused preference write reaches no surface; the client
  stub cannot refuse, and the announcement guards in the locator bar and Home are where a reason would
  go), **DW-1327** (the store's add and touch paths are check-then-insert, so concurrent adds trip the
  unique index, and the read-then-write cap check can store 21), and **DW-1328** (a Home block whose
  every stored row names no built screen shows its empty state with no Clear, leaving stored rows
  invisible and unclearable). 15.1's landed keyboard model governs any later account-menu item.
- **Range-end cleanup** carries 15.1's DW-1289 (a password refused by a configured policy routine
  answers 500, to be fixed **site-scoped** inside the change-password handler) and DW-1290, plus
  15.3's DW-1377 (`HELP.ROUTE` is a third field-level code family outside the gate that checks such a
  code has a published sentence) and 15.3's low residuals. None blocks 15.4 or 15.5.
- **Parallel runners and contended paths.** Epic 13 is merged onto this branch. Epic 5 is still in
  flight and owns `ui/src/app/shell/panel*`, `proposal-card`, `reply`, `tool-call-card`,
  `context-chip`, `core/proposal-view.ts` and `core/turn.ts`; Epic 15 works outside them and also
  treats `ui/src/app/core/screens.generated.ts` and `core/navigation.ts` as **read only** — never
  regenerate the mirror, which Epic 5 has modified. Epic 15's own shell surfaces are `header*`,
  `account-menu*`, `side-bar*`, `command-box*`, `locator-bar`, `recents-recorder`, `about-dialog`,
  `stale-bundle-notice` and Home. `src/OcuPilot/Api/Router.cls`, `src/OcuPilot/Api/Error.cls`, the UX
  string table, `ui/src/app/core/strings.ts` and `ui/src/styles/_components.scss` are under an
  epic-wide **shared-append** grant: append at the tail only, never reorder, never insert, never touch
  a line another epic added, and run `uv run scripts/check-objectscript.py` before every commit
  touching the router. `ui/browser/**` is **shared-create** (orchestrator ruling 2026-09-20) — a new
  uniquely-named spec file there is this epic's and is reported under `footprint_extensions:`, while
  modifying an existing file there stays a Clarification. Never touch `ui/src/styles/_tokens.scss`,
  which 15.6 owns.
- **Deferred, tracked, not dropped:** Story 15.6 carries DW-39 (the dark class flip reaches only the
  colour roles with a Material counterpart, not the 34 OcuPilot-only ones) and DW-118 (the OcuPilot
  colour layer is theme-static, so components keep their light values in dark mode). Both stay with
  15.6; do not attempt either in 15.4 or 15.5.
