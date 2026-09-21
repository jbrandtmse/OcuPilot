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
shell alone and adds no new screen area. **Stories 15.1, 15.2, 15.3 and 15.4 are done** and their
landed decisions are recorded below as constraints, not choices; **15.6 is deferred by owner
decision**, so the in-scope range is **15.5 alone**.

## Stories

- Story 15.1: Change your own password — **done**
- Story 15.2: Favorites, recent items and menu search — **done**
- Story 15.3: About, help, shortcuts and the links panel — **done**
- Story 15.4: Home's System Information panel — **done**
- Story 15.5: UI state that survives a sign-out — **the only story in scope**
- Story 15.6: The light and dark theme — **DEFERRED, out of scope for this epic.** Owner decision:
  sequenced after Epic 5 merges, because it edits the `ui/src/styles/**` token files Epic 5 is
  concurrently editing and its contrast guards run in both modes. It stays in `backlog`, the
  orchestrator dispatches it later, and an Epic 15 run that reports done without it is correct. Do
  not build it, and do not pre-build a theme toggle for it. DW-39 and DW-118 stay attributed to it.

## Requirements & Constraints

- **15.5's whole subject is six remembered things**: per-screen sort, filter, max rows and
  auto-refresh rate; the side bar's open state; the panel's width. Each must return as it was after
  a sign-out and sign-in.
- **Per-user state lives on the instance, not in browser storage.** That is 15.5's second acceptance
  criterion and AD-50 says so in terms: a preference kept only in `localStorage` **fails** the
  criterion rather than satisfying it cheaply. The UX documents describe all six as "remembered per
  browser"; 15.5 is the story that supersedes that wording, and those same sentences are what the
  client's single `localStorage` carve-out cites as its own justification today.
- **Everything new is filtered by what the user may reach**, and a gated entry stays listed and
  focusable naming the resource it needs — never removed, never natively disabled.
- **Home never scrolls horizontally at a supported width.** 15.2, 15.3 and 15.4 landed **five**
  blocks above the auto-fit area-tile grid — Favorites, Recent items, Shortcuts, Links, System
  Information. The block row wraps by construction; nothing is hidden by viewport width.
- **No inert control.** Every item added to a menu, panel or dialog ships with its handler.
- **Strings.** Every new user-facing string is published in the canonical UX string table **before**
  it exists as a client key, appended strictly after the current last row — the client's string
  source carries hard line-number comments back into that table, so an insertion above the tail
  breaks hundreds of them. The test demands exact set equality and globally unique values, so reuse
  an existing row rather than repeating a value; the literal-count band is widened with a comment
  naming the story only when a story overruns it.

## Technical Decisions

- **15.5 is AD-50's second case and extends it rather than re-answering it.** Landed by 15.2:
  `OcuPilot.Kernel.State.Pref` in the protected database, unique on `(UserName, Kind, Name)`, on
  `Kernel/State/Base` so every write inherits the version-conditional guarded save, read and written
  through the caller-own route `GET`/`POST /api/ocupilot/account/preferences`
  (`OcuPilot.Api.Preferences`) — **not** through AD-36's declared read. 15.5 **adds `Kind` values**,
  and a value property where one is needed, and **never adds another `State` subclass** (the
  29-character cap leaves 7 characters after `OcuPilot.Kernel.State.`) and **never invents a second
  per-user endpoint family** — it adds members to that envelope, or a sibling route. A preference is
  never screen context and never a tool's view.
- **What the landed store does and does not do.** `Pref` holds **set membership, not values**: there
  is no value column, `Kind` is `MAXLEN 16`, `Name` is the route at `ROUTEMAXLENGTH` (512), and
  `UpdatedAt` is the only moving column. Its header says in terms that a later `Kind` needing a value
  adds one. Four of 15.5's six preferences are values, not memberships, and the fifth and sixth
  (side-bar open, panel width) are single scalars — so the value property is this story's first real
  schema move. The POST grammar is `{kind, action, route}` over closed enums that **refuses an extra
  member** 422 before writing anything, so a value-bearing write changes that grammar deliberately
  rather than by accident. **An empty `%String` is stored as SQL `NULL`** and then never matched
  again by the key lookup — the reason an empty route is refused, and a trap any value column
  inherits.
- **Footprint fact 15.5 must confront.** Its first AC names "the panel width", and Epic 5 owns
  `ui/src/app/shell/panel*` as a decision. Measured on this branch today, panel width lives in
  `ui/src/app/core/panel-layout.ts`, `ui/src/app/core/preferences.ts`, `ui/src/app/app.ts`,
  `ui/src/styles/{_metrics,_components}.scss` and `ui/src/app/shell/panel-resize-handle.ts`. **Only
  `shell/panel-resize-handle.ts` is inside Epic 5's carve**, and Epic 5 has **not** modified
  `core/panel-layout.ts`. Plan the persistence through `core/` rather than through Epic 5's
  component wherever it can be done there.
- **The browser-storage store is a distinct module from the instance-backed one.**
  `ui/src/app/core/preferences.ts` is the one module permitted to touch `localStorage` and today
  holds exactly 15.5's six items under four declared keys (side-bar open; one descriptor-to-seconds
  refresh-rate map; one descriptor-to-view map of sort, direction, filter and max rows; panel width
  in px). `ui/src/app/core/account-preferences.ts` is 15.2's separate instance-backed store. The
  `localStorage` ban is a source scan with an **exact path exemption, never a pattern**, plus a
  closed key allow-list, no `storage` listener and no `BroadcastChannel`; those four parts are
  load-bearing and none may be widened.
- **15.5 owns three escalated ledger entries**, kept on this story under the standing AD-invariant
  ruling rather than re-owned: **DW-1326** — a refused preference write is never surfaced (the client
  parks every non-`ok` result, no component reads a fault, the test stub has no refusal path, and the
  announcement guards in the locator bar and Home are where a reason would go); **DW-1327** — the
  store's add and touch paths are check-then-insert, so two concurrent adds of the same
  `(user, kind, route)` trip the unique index and answer 500 instead of the documented no-op, and the
  read-then-write cap check can store 21; **DW-1328** — when every stored row in a Home block names
  no built screen (now including an unlisted screen at `sideBarPosition` 0), the block shows its
  empty state with no Clear, so rows the instance still holds are invisible and unclearable.
- **A self-service account action is the user's own write, outside the agent write path (AD-49,
  written by 15.1).** It mints no proposal, takes no confirm token, emits no agent marker and is
  never a tool.
- **Shell chrome is caller-own, and 15.3 set the shape 15.4 copied.** Landed: `GET /ui/about`,
  `GET /ui/help`, `GET /ui/system` as a `Kernel/Shell/*` payload class plus a thin `Api/Ui*` handler,
  with a per-field `Try` so one refused source degrades that field to `""` and logs, never a 500, and
  `%SYS` entered only by explicit save/restore with the restore as the first line of the `Catch`.
  **15.4 landed uptime, mirror state, the four dashboard alerts and production status**, each
  rendered as the vendor reports it and never translated, scoped to the request's validated `?ns=`;
  About will never show uptime or mirror state, and cluster support is not resurrected. One caveat
  worth carrying: some vendor accessors catch their own errors and answer a plausible value instead
  of throwing, so a per-field `Try` does not see them.
- **One error envelope** with a stable dotted code; a refusal, denial or fault is never a 500 and
  never an empty state. **A new violation code needs its arm in `Api/Error.cls`'s
  `ReasonForViolation` or its `reason` serializes empty**, and a field-level code outside the
  `AGENT.*` family is pinned over the wire. Adding a property that every pre-existing row reads as a
  safe default does **not** move `SCHEMAVERSION` — record the reasoning where the change is made.
- **New REST routes are appended at the tail** of the router's `<Routes>` with a thin `Call=`
  wrapper; the ordering checker constrains only a prefix family. Every new route needs a wire test
  carrying the four required markers, **and a matching probe row in
  `src/OcuPilot/Test/EndpointCoverage.cls` or CI's `instance` job reddens** — that has bitten this
  branch three times: the Epic 13 merge, 15.3's review and 15.4's implement pass.
- **Client shape:** Angular standalone, zoneless, `OnPush`. `ui/src/app/core/` imports no
  `@angular/core`, so a store there is a plain subscribable that components mirror into signals and
  release on destroy. The house instance-backed store shape — request-counted so a late answer cannot
  overwrite a newer one, a generation counter so an answer resolved for a departed principal cannot
  land on the next, never cleared on a transport failure, `reset()` on sign-out — is landed four
  times over (`core/account-preferences.ts`, `core/about.ts`, `core/help.ts`, `core/system-info.ts`);
  copy it, do not re-derive it.
- **Auto-refresh is one framework and its roster is closed at seven screens.** Home is not among
  them; 15.5 changes which rate a screen remembers, never which screens may refresh.
- **Stored references to IRIS objects and screens are weak**: recorded as data, bound as SQL
  parameters, never a foreign key; a reference that no longer resolves degrades rather than failing
  the screen.

## UX & Interaction Patterns

- **Where the six preferences surface.** The data table's footer carries the row count and the
  editable max-rows field; sort and filter are the table's own controls; the auto-refresh chip is a
  command-bar control on the seven roster screens with the last-update stamp in the status bar; the
  side bar opens on its rail item, collapses on the same click, on Ctrl/Cmd+B or through the yield
  order — **and the yield order's auto-collapse keeps the remembered state rather than overwriting
  it**; the panel is the shell's only resizable edge, 400 px default and 320 px minimum, widening on
  Home and restoring the remembered width on leaving Home.
- **Announcements.** Polite `role="status"` for saves, counts and transitions; `role="alert"` (or
  moved focus) for save failures and 403s — the shape a surfaced preference refusal would take.
- **Dialogs** are one level deep and never stack; Escape and Cancel close without effect; focus
  returns to the opener. A server rejection sets `aria-invalid` with the message in
  `aria-describedby`.
- **Command box.** **It is the one finder** — adding a second search surface, or a second roster that
  behaves like one, is a defect. Gated results render as non-selectable rows with the reason inline.

## Cross-Story Dependencies

- **Upstream: Epic 1 alone.** The shell this epic extends is already built. Epic 2's declared read,
  table, sort, filter and max-rows machinery is what 15.5's per-screen preferences attach to; 15.2's
  `Pref` store and `/account/preferences` envelope are what 15.5 extends.
- **Range-end cleanup** carries 15.1's DW-1289 (a password refused by a configured policy routine
  answers 500, to be fixed **site-scoped** inside the change-password handler) and DW-1290, plus
  15.3's DW-1377 (`HELP.ROUTE` is a third field-level code family outside the gate that checks such a
  code has a published sentence) and the low residuals of 15.3 and 15.4. None blocks 15.5.
- **Parallel runners and contended paths.** Epic 13 is merged onto this branch. Epic 5 is still in
  flight and owns `ui/src/app/shell/panel*`, `proposal-card`, `reply`, `tool-call-card`,
  `context-chip`, `core/proposal-view.ts` and `core/turn.ts`; Epic 15 works outside them and treats
  the `core/` files Epic 5 has modified — `agent-status.ts`, `navigation.ts`, `proposal-view.ts`,
  `screens.generated.ts`, `suggested-view.ts`, `turn.ts` — as **read only**; never regenerate the
  screen mirror, and `screen-mirror.mjs --check` must stay green with no regeneration. Epic 15's own
  shell surfaces are `header*`, `account-menu*`, `side-bar*`, `command-box*`, `locator-bar`,
  `recents-recorder`, `about-dialog`, `stale-bundle-notice` and Home. `src/OcuPilot/Api/Router.cls`,
  `src/OcuPilot/Api/Error.cls`, the UX string table, `ui/src/app/core/strings.ts` and
  `ui/src/styles/_components.scss` are under an epic-wide **shared-append** grant: append at the tail
  only, never reorder, never insert, never touch a line another epic added, and run
  `uv run scripts/check-objectscript.py` before every commit touching the router. `ui/browser/**` is
  **shared-create** (orchestrator ruling 2026-09-20) — a new uniquely-named spec file there is this
  epic's and is reported under `footprint_extensions:`, while modifying an existing file there stays
  a Clarification. Never touch `ui/src/styles/_tokens.scss`, which 15.6 owns.
