---
title: 'Story 15.2: Favorites, recent items and menu search'
type: 'feature'
created: '2026-09-19'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-15-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** A sixty-screen portal has no way to keep the four screens you use daily one click away, and nothing records where you have been. The classic portal's per-user favorites and recent items have no OcuPilot equivalent, and no OcuPilot store holds per-user state at all.

**Approach:** Add one per-user store in OcuPilot's protected database — `OcuPilot.Kernel.State.Pref`, one row per `(user, kind, name)` — behind a caller-own `GET`/`POST /api/ocupilot/account/preferences`. The locator bar gains a favorite toggle for the screen you are on, Home gains Favorites and Recent items blocks above the tile grid, a visit recorder registers each built screen you open, and the **existing** command box ranks favorited screens first. No second finder is built.

## Boundaries & Constraints

**Always:**

- Per-user state lives on the instance (`epics.md:5395`), never in browser storage. `ui/tools/api.test.mjs:694-708` already bans `localStorage` outside `core/preferences.ts`, and `PreferenceStore` refuses an unlisted key — do not add one.
- A stored route is a **weak reference** (AD-37): recorded as data, never a foreign key, bound as a SQL parameter (NFR-4, `check_state_sql_literal`). A route that no longer resolves to a built screen is dropped from the rendered list, never an error.
- Each entry is filtered by what the user may reach, and a gated entry stays listed and focusable with its reason inline — never removed, never natively disabled (EXPERIENCE.md `:216`, `:663`).
- Every new user-facing literal is published in EXPERIENCE.md's `**Fixed strings**` table **before** it exists as a `strings.ts` key, appended after the current last row.
- Both lists are bounded: favorites at 20 (a 21st is refused by the instance), recents at 10 (the store trims the oldest).
- One error envelope with a stable dotted code (AD-12, AD-39); a new violation code needs its arm in `Api/Error.cls` `ReasonForViolation` or its `reason` serializes empty.

**Never:**

- Never a second search surface. The command box is the finder; this story adds no input, no new result group, and no change to `commandBoxResultCount`.
- Never `%CSP.Portal.Utils`' classic favorites: its lists key on classic page URLs, which OcuPilot cannot navigate to, and it is a `[Hidden]` vendor internal.
- Never a declared read (AD-36) for these rows — see Design Notes.
- Never a screen descriptor, route, tool, proposal or confirm: this is shell chrome (AD-5, AD-40), and no agent write path touches it.
- Never block or delay a navigation on the visit registration, and never surface its failure.
- Never edit `ui/src/styles/_tokens.scss`, and never add a token — Story 15.6 owns that file and is deferred.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Read | signed-in user; `GET /api/ocupilot/account/preferences` | `200` `{"favorites":[…],"recents":[…]}`, each entry `{"route"}`; favorites oldest-first, recents newest-first, each capped | No error expected |
| Add a favorite | `POST` `{"kind":"favorite","action":"add","route":"web-apps/applications"}` | `200` with the same body `GET` answers; a second add of the same route is a no-op that still answers `200` | No error expected |
| Remove / clear | `POST` with `action` `remove` (with `route`) or `clear` (without) | `200` with the re-read body; removing a route not held is a no-op answering `200` | No error expected |
| Register a visit | `POST` `{"kind":"recent","action":"add","route":…}` | `200`; the row's `UpdatedAt` is refreshed, the list re-ordered, rows beyond 10 deleted | A concurrent register of the same route loses the conditional save; the store answers `$$$OK` because the outcome is already true (precedent `Nav.cls:137`) |
| Favorites full | 20 favorites held, an `add` of a 21st | `422`, slug `validation_failed`, code `PREFERENCES.LIMIT`, violation on `route` | Refused by the instance, not by the client alone |
| Unknown route | `route` is not a built screen's route, or is over `Base.cls` `ROUTEMAXLENGTH` (512) | `422`, code `PREFERENCES.ROUTE`, violation on `route` | Validated against `Screen.Registry` before any write |
| Malformed body | not JSON, not an object, an extra member, a missing member, a member of the wrong type, or `kind`/`action` outside their enums | `422`, code `PREFERENCES.BODY`, flat reason naming the members | Follow `Api/Context.cls:44-69` exactly, including binding the iterator's value to an unread variable and releasing the iterator |
| Route no longer built | a stored route whose screen was removed or is not `built` | The client drops it from both rendered lists and from the command box; the row stays stored | AD-37 degrade — never a fault, never an empty screen |
| Gated favorite | a favorited screen the user may no longer open | Rendered, focusable, `aria-disabled="true"`, reason inline after the label | Choosing it does nothing, as the command box already refuses gated rows |
| Server unreachable on Home | the read fails or the fault classifier reports unreachable | Both blocks render their empty state; the tile grid and instance line are unaffected | `JsonResult` `kind:'error'` with `status: 0` — the store keeps its last answer and does not clear it |

</intent-contract>

## Code Map

### Server — reuse, do not re-derive

- `src/OcuPilot/Kernel/State/Sharing.cls` — **the shape precedent**: `UserName As %String(MAXLEN = 160)` `:21`, `Index … On UserName [ Unique ]` `:26`, the weak-reference header `:7-9`, the lookup-or-create idiom `GuardedSetForUser` `:55-72`, the "absent is the ordinary answer" read `:34`, `DeleteAllGuarded()` `:76`. `MAXLEN = 160` is `Security.Users.Name`'s length on this build.
- `src/OcuPilot/Kernel/State/Base.cls` — `GuardedSave` `:132`, `GuardedSaveIfCurrent` `:167` (the conditional `UPDATE … WHERE ID = ? AND COALESCE(RowVersion,0) = ?` at `:188`), `IsStaleSave` `:215`, `GuardedOpenOneWhere` `:518`, `GuardedIdsWhere` `:690`, `GuardedIdsBounded` `:784`, `Parameter ROUTEMAXLENGTH = 512` `:114`. `Private` helpers are reached by inherited `..` dispatch, never `##class(Base)` (`:451-460`).
- `src/OcuPilot/Kernel/State/Nav.cls:119`, `:137` — `If ..IsStaleSave(tSC) Set tSC = $$$OK`: the precedent for swallowing a stale save when losing the race still leaves the caller's outcome true.
- `src/OcuPilot/Api/Context.cls` — the caller-own, ungated-beyond-the-router handler: `CallerUsername()` `:12-15` (`Quit $Username`), `HandleRead` `:20-34`, the body-rejection ladder `:40-87`, and the mutate-then-re-render-the-read shape `:77-82`. Copy this whole structure.
- `src/OcuPilot/Api/Account.cls` — Story 15.1's freshest caller-own class: allow-list parameters `:32`/`:38`, `RenderBodyRefusal` `:116`, violations through `Kernel.AgentRules.ViolationsJson` `:168-180`, and the iterator release `:74`.
- `src/OcuPilot/Api/Error.cls` — `Render` `:1208`, `#VALIDATIONFAILED` `:44`, `ReasonForViolation` `:1030` (**a new code needs an arm here**), `RenderInternal` `:1258`.
- `src/OcuPilot/Api/Router.cls` — `XData UrlMap` `:72-111`; the last three routes `:107-109`; the last `Call=` wrapper `AccountPasswordChange` `:371-378`. The three ordering invariants are documented at `:54-71`; invariant 3 binds only a prefix family, and no existing route shares `/account/preferences`' leading segments beyond `/account/password`, which is the same length.
- `src/OcuPilot/Screen/Registry.cls` — `Descriptors` `:84` (embedded SQL, deliberately — see `:71-79`), `Roster` `:2168`, `DescriptorForRoute` `:2247`. `Roster` is what validates a submitted route as a built screen.
- `src/OcuPilot/Kernel/Shell/Navigation.cls` — `Payload` `:20`, `SetVerdict` `:64-70`. The per-caller `allowed` verdict the client already holds; favorites/recents do **not** re-compute it.
- `scripts/check-objectscript.py` — `check_naming` `:381` with `MAX_CLASS_NAME_LENGTH = 29` `:206` (`OcuPilot.Kernel.State.` spends 22, so the leaf is capped at 7 — `Pref` is 26); `check_state_package_isolation` `:823`; `check_state_sql_literal` `:964` (first argument one whole string literal); `check_handler_wire_tests` `:1531` with its four `WIRE_MARKERS` `:1473-1478`; `check_route_ordering` `:1760`.
- `src/OcuPilot/Test/SwitchState.cls` — the State-subclass test model (weak-reference leg `:93`, teardown that asserts nothing survives). `src/OcuPilot/Test/AccountPasswordWire.cls` — the wire-test model; `src/OcuPilot/Test/SwitchesWire.cls:15` `Parameter APIBASE`. Neither this store nor its endpoint creates an IRIS principal, so **no `ARMINGVARIABLE` guard is needed** (`Test/SwitchFixture.cls:8` is the precedent).
- Nothing in `src/OcuPilot/Install/` changes: `Roster.cls:95` declares package folders, the global mapping is by pattern (`Base.cls:69` `"OcuPilot*"`), grants are on the resource, and a new empty table needs no migration — so `Installer.cls:68` `SCHEMAVERSION` stays 1.

### Client — reuse, do not re-derive

- `ui/src/app/core/shell-state.ts:62`, `:69-74`, `:241-243` — the framework-free store skeleton (`listeners` set, `subscribe()` returning an unsubscribe, `private notify()`). `core/screen-store.ts:314-316` copies the listener set before notifying; do that.
- `ui/src/app/core/agent-status.ts:229-278` — the instance-backed variant: a request counter so only the newest read settles, and state that is not cleared on a transport failure.
- `ui/src/app/core/account.ts` — Story 15.1's `core/` module against the API; `core/api.ts` `API_PATH_PREFIX` `:156`, `requestJson<T>` `:328`, the `JsonResult` union `:107-121`; `core/violations.ts` `violationsOf` `:35`.
- `ui/src/app/shell/command-box.ts` — `CommandRow` `:56-72`, `rows` `:229-233` (the one seam), `screenCandidates` `:397-423`, `matchesScreen` `:477-482`, the `generation` subscriptions `:235-245`, group filters `:251-257`, `countMessage` `:268-273`. Read `:83-86` and `:111-112` before editing.
- `ui/src/app/shell/locator-bar.ts:104-120` — the `<nav class="ocu-locator-bar">` and the `screen` segment's `<h2 id="ocu-locator-screen">`; `LocatorSegment` `:33-48`; the `router.events` bump `:321`.
- `ui/src/app/areas/home/home.page.ts` — `<section class="ocu-home">` with the tile grid `:113-141` and the instance line `:144-159`; the mirror-and-release constructor `:259-276`. A `role="list"` of `role="listitem"` wrapping real buttons is the page's own keyboard model — reuse it, so no roving-tabindex model is invented (DW-115 is Story 15.1's and stays there).
- `ui/src/app/shell/agent-navigator.ts` + `ui/src/app/app.ts:202-205` — the precedent for a service injected purely for its routing side effect. `ui/src/main.ts:190-232` — where a store is constructed and provided.
- `ui/src/app/core/strings.ts` — **shared-append**: add keys only at the end, one pair per line, single quotes, trailing comma, each preceded by `/** EXPERIENCE.md:N */`. Story 15.1's block `:1104-1117` is the format. `stringFor` `:1156`.
- `ui/tools/strings.test.mjs` — `:456-460` and `:480-500` (exact set equality; a key with no table row fails), `:584`/`:593` (unique keys, **unique values**), `:642-687` (every `/** EXPERIENCE.md:N */` must resolve), and the literal-count band at `:395` (currently `150..520`) — **this story overruns it and must widen it with a comment saying why**.
- `ui/tools/client-lint.mjs` — `aria-label="{{ STRINGS.key }}"` must be exactly one interpolation (`:288-293`); a composed name uses `[attr.aria-label]` over a published placeholder string, as `formatRequires` does. `@if` conditions are paren-free member references. Non-ASCII is a `\uXXXX` escape. No hardcoded color outside `_tokens.scss`.
- `ui/tools/overlay-stack.test.mjs:1-27` — the `node --test` file shape: header naming what is pinned, an explicit `Mutations (Rule 19)` list, top-level `await import()` of the `.ts` source by absolute path.

### Read-only evidence

- `_bmad-output/planning-artifacts/research/.../feature-catalog.md:60-62` — SH-13/14/15. The "API backing" column reads `custom(%CSP.Portal.Utils) or OcuPilot per-user store`, `custom or local`, and `none (client-side)`; `prds/.../extract-catalog.md:530` records the storage location as undecided. `epics.md:5395` decides it: the instance.
- `ux-designs/.../DESIGN.md:898` — *"Polish-week additions (system information, favorites, recents) go above or beside the grid."* `EXPERIENCE.md:83` agrees. Neither document specifies the affordance, the list shape, the ordering, the cap, or a star glyph; DESIGN.md `:954` allows a vendored Material Symbols Outlined placeholder.
- `EXPERIENCE.md:432-438` — the command box's full contract, already built. `:701` records that the classic 220 ms menu-only typeahead was **rejected in favour of** the command box, which is why SH-15 needs no new surface.
- `EXPERIENCE.md:250-382` — the Fixed strings table: header `:252`, first row `:254`, **current last row `:381`** (Story 15.1's). Append at `:382`. The table is located by its heading, not by line number (`strings.test.mjs:43-46`), but `strings.ts`'s `/** EXPERIENCE.md:N */` comments are hard line numbers, so nothing may be inserted above `:381`.
- `ARCHITECTURE-SPINE.md:322` (AD-24, *"The sharing toggle is remembered per user on the instance"*) is the only existing spine precedent for per-user instance state; no AD names a per-user preferences store.

## Tasks & Acceptance

**Execution:**

- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` — **append** one Fixed strings row immediately after `:381`, publishing the fifteen literals below, annotated `[ADDED 2026-09-19 — see the story change log]`; and add favorites/recents to the polite-status enumeration at `:662` **in place and line-neutral**. Never insert above `:381`.
- `src/OcuPilot/Kernel/State/Pref.cls` — NEW. `Extends OcuPilot.Kernel.State.Base`. Properties `UserName As %String(MAXLEN = 160)`, `Kind As %String(MAXLEN = 16)`, `Name As %String(MAXLEN = 512)`, `UpdatedAt`. `Index PrefUserKindNameIdx On (UserName, Kind, Name) [ Unique ]`. Guarded class methods: `GuardedListForUser(pUserName, pKind, Output pRows)`, `GuardedAdd`, `GuardedRemove`, `GuardedClear`, `GuardedTouch` (the recents upsert, conditional per `GuardedSaveIfCurrent`, swallowing a stale save), `GuardedTrim(pUserName, pKind, pKeep)`, `DeleteAllGuarded()` for tests. Every SQL first argument is one whole string literal.
- `src/OcuPilot/Api/Preferences.cls` — NEW. Caller-own, `CallerUsername()` = `$Username`. `HandleRead()` and `HandleUpdate()` following `Api/Context.cls`'s ladder exactly. Validate `kind` ∈ {favorite, recent}, `action` ∈ {add, remove, clear}, and the route against `Screen.Registry` before any write. Three violation codes: `PREFERENCES.BODY`, `PREFERENCES.ROUTE`, `PREFERENCES.LIMIT`.
- `src/OcuPilot/Api/Error.cls` — append the three codes, their reasons, and their `ReasonForViolation` arms. Append only; touch no existing line.
- `src/OcuPilot/Api/Router.cls` — **shared-append grant**: add `<Route Url="/account/preferences" Method="GET" Call="AccountPreferences"/>` and its `POST` sibling as the **last** lines of `<Routes>`, and their thin wrappers after `AccountPasswordChange` `:378`. Run `uv run scripts/check-objectscript.py` and quote its result in the commit.
- `ui/src/app/core/account-preferences.ts` — NEW. Framework-free `AccountPreferences` store: `favorites()`, `recents()`, `isFavorite(route)`, `load()`, `add`/`remove`/`clear`, `registerVisit(route)`; `subscribe()`/`private notify()`; a request counter so a late answer cannot overwrite a newer one; never cleared on a transport failure. Named `account-preferences.ts` because `core/preferences.ts` is the browser-storage store and must not be confused with it.
- `ui/src/app/core/strings.ts` — **shared-append** the fifteen keys at the end, in one block with a leading comment naming the story: `favoritesHeading` "Favorites", `favoritesEmpty` "No favorites yet.", `favoritesAdd` "Add to favorites", `favoritesRemove` "Remove from favorites", `favoritesRemoveNamed` "Remove \<name\> from favorites", `favoritesClear` "Clear favorites", `favoritesAdded` "Added to favorites", `favoritesRemoved` "Removed from favorites", `favoritesCleared` "Favorites cleared", `recentsHeading` "Recent items", `recentsEmpty` "No recent items yet.", `recentsRemoveNamed` "Remove \<name\> from recent items", `recentsClear` "Clear recent items", `recentsRemoved` "Removed from recent items", `recentsCleared` "Recent items cleared".
- `ui/tools/strings.test.mjs` — widen the literal-count band at `:395` to cover the fifteen, with a comment saying which story moved it and why. This is the file's own documented protocol; it is not a test weakening.
- `ui/src/app/shell/locator-bar.ts` — add a favorite toggle button beside the `screen` segment's `<h2>`, present only for a built screen, `aria-pressed` reflecting `isFavorite(route)`, its accessible name `favoritesAdd`/`favoritesRemove`, announcing through the existing polite region. One control, on every route — this is AC1's "any screen".
- `ui/src/app/shell/recents-recorder.ts` — NEW. Subscribes to `NavigationEnd`, resolves `NavigationService.screenForUrl`, and calls `registerVisit` for a built screen whose route differs from the last one this tab registered. Fire-and-forget: never awaited by navigation, never surfaces a failure.
- `ui/src/app/areas/home/home.page.ts` — add a Favorites block and a Recent items block as siblings **above** the tile grid (`:113`). Each is a `role="list"` of `role="listitem"` rows: a navigating button carrying the screen's label, a per-row remove button named through `[attr.aria-label]` over the `*RemoveNamed` placeholder, and a Clear button per list. Gated rows keep their reason inline; rows whose route no longer resolves to a built screen are dropped.
- `ui/src/app/shell/command-box.ts` — in `screenCandidates`, order favorited screens before the rest within the Screens group. No new group, no new input, no change to `countMessage`.
- `ui/src/styles/_components.scss` (**not** `_tokens.scss`, and no new token) — rules for the two Home blocks and the locator toggle, using existing tokens only (32px rows, `{typography.body}`, `{colors.surface-container-lowest}`), mirroring the `row-overflow-menu` metrics at DESIGN.md `:353-366`.
- `ui/src/main.ts` and `ui/src/app/app.ts` — construct and provide `AccountPreferences`; inject `RecentsRecorder` for its side effect, as `AgentNavigator` is injected at `app.ts:205`.
- `src/OcuPilot/Test/PrefState.cls` — NEW. Pins the store: per-user isolation, the unique index, the weak reference (a username the instance does not hold is a legitimate row), the recents trim, the stale-save swallow, and removal of every row it wrote with a teardown assertion that none survives.
- `src/OcuPilot/Test/PreferencesWire.cls` — NEW. The `check_handler_wire_tests` contract: the literal route, `"GET"` and `"POST"` as quoted literals, an over-the-wire request, a status assertion, a content-type assertion and `%FromJSON`. Covers every I/O Matrix row above.
- `ui/tools/account-preferences.test.mjs` — NEW. `node --test` over the store: ordering, caps, the transport-failure hold, `isFavorite`, and that a late answer does not overwrite a newer one. Carry the `Mutations (Rule 19)` header.
- `ui/src/app/areas/home/home.page.spec.ts` and `ui/src/app/shell/command-box.spec.ts` — add the component legs: Home renders both blocks with their empty states, drops an unresolvable route, and keeps a gated row listed; the command box still reports exactly two groups and the unchanged count string, and ranks a favorited screen first.

**Acceptance Criteria:**

- Given a signed-in user on any built screen, when they activate the locator bar's favorite toggle, then the screen appears in Home's Favorites block, the toggle reads pressed on return, and a polite status announces it.
- Given favorites held, when the user removes one or clears the list from Home, then the rows disappear, the instance holds none of them on the next read, and the locator toggle reads unpressed.
- Given a user who opens several built screens, when Home renders, then Recent items lists them newest-first, capped at ten, with per-row remove and a clear — registered by visiting, with no explicit action.
- **Integration AC (Rule 1):** Given favorites and recents held, when the user signs out, signs back in **in a new tab**, and opens Home, then both lists are unchanged — the state was read from the instance, and no browser storage holds it.
- Given the command box, when it opens, then the shell still has exactly one search input and exactly two result groups, the count still reads `<n> screens, <m> actions`, and favorited screens are listed first within Screens.

## Spec Change Log

- 2026-09-20, lead spec gate: **AD-50** added to the governing ADs. The plan stage settled the per-user store's shape and correctly flagged it as architectural rather than writing the spine itself; the lead wrote the AD at this gate, so the plan could not have cited it. The sign-out/new-tab criterion is labeled the Integration AC (Rule 1) — it already was one in substance, naming Home as the consumer, the instance as the source and an observable effect across a session boundary.

## Review Triage Log

## Design Notes

**Governing ADs (Rule 6):** **AD-50** (written into the spine at this story's spec gate, after planning: per-user preferences are one `Kind`-discriminated store in the protected database, read through a caller-own shell-chrome route rather than a declared read — this story is its originating case and Story 15.5 extends it by adding `Kind` values, never `State` subclasses), **AD-9** (the store is OcuPilot's own state in the protected database, escalating only inside the storage frame and re-entering nothing) and **AD-37** (route and username are both weak references; an unresolvable one degrades) are the two this story turns on. Also binding: AD-8, AD-12, AD-39, AD-19, AD-20, AD-21, AD-5, AD-40, AD-28, AD-47. Conventions rows: *Concurrent writes to OcuPilot's own state*, *ObjectScript naming* (the 29-character cap), *REST route ordering*, *Error shape*, *Tests*, *Client asset homes*.

**Why not a declared read (AD-36).** AD-36's second source kind resolves against `GuardedScreenRows(Output pRows, pMaxRows)` (`Screen/Read.cls:167`, `:424`), which takes no caller argument and reads a store's whole list. A per-user read cannot go through it without changing that contract, which is an architecture change and not this story's. Shell chrome is already served by dedicated caller-own handlers — `/navigation`, `/instance`, `/agent/context` — and Home declares no `read` or `table` (`Screen/Descriptor/Home.cls`, four of the 26 declaration keys omitted). This story follows that precedent and leaves AD-36 untouched; **AD-50 now records that boundary in the spine**, so a later story does not re-answer it.

**Why no `RowVersion` on the wire.** The Conventions row binds a write conditional on the version the caller read, and the window it names is a handler that reads, works, then writes. Modelling one row per `(user, kind, name)` makes add a create and remove a delete by key, so favorites have no read-modify-write and no conflict window at all. The one update is the recents visit timestamp, which uses `GuardedSaveIfCurrent` with the version just read and swallows a stale save — losing that race means another tab registered the same visit, so the caller's outcome is already true (`Nav.cls:137`).

**Decisions this story settles that a later story must not re-answer differently** (the lead writes any spine entry, Rule 20):

1. **Per-user state is one store, `OcuPilot.Kernel.State.Pref`, keyed `(UserName, Kind, Name)` with a `Value`-free row for set membership.** Story 15.5's per-screen sort, filter, max rows, auto-refresh rate, side-bar state and panel width extend it with further `Kind` values (adding a `Value` property when one of them needs it), rather than adding four more State classes. The 29-character class-name cap makes a class per preference unworkable: `OcuPilot.Kernel.State.` spends 22, so `Favorite` (30) and `Bookmark` (30) do not even fit.
2. **The wire is `/api/ocupilot/account/preferences`,** caller-own and ungated beyond the router, answering the members this story defines. 15.5 adds members or a sibling route; it does not invent a second per-user endpoint family.
3. **"Menu search" is the command box, and nothing else.** EXPERIENCE.md `:701` already records the classic 220 ms menu-only typeahead as rejected in favour of it, and `:436` already has it searching every screen the user may open plus the current screen's actions, matching label, route and `commandAliases` — which is SH-15's name/title/tags. The only change is ranking, so the AC's "one finder, not two" holds by construction.

**Two choices the documents did not make** (inference, stated rather than hidden): the caps (20 favorites, 10 recents) and the affordance's placement (the locator bar, because DESIGN.md `:887` declares the header band closed at three things and the side bar is absent on Home). Both are observable and both are cheap to move.

**Contended and out-of-footprint paths, declared (Rule 11).** `src/OcuPilot/Api/Router.cls` and `EXPERIENCE.md` are under the orchestrator's epic-wide shared-append grant: append only at the tail, never reorder, never insert, never touch a line another epic added, and quote `uv run scripts/check-objectscript.py` before every commit touching `Router.cls`. `ui/src/app/core/**` and `src/OcuPilot/Test/**` are shared-create, so `core/account-preferences.ts`, `Test/PrefState.cls` and `Test/PreferencesWire.cls` are new files with names no other epic would pick. `ui/src/app/core/strings.ts` is shared-append. Outside Epic 15's footprint and owned by no concurrent epic, to be reported under `footprint_extensions:`: `ui/src/app/shell/locator-bar.ts`, `ui/src/app/shell/recents-recorder.ts` (new), `ui/src/app/areas/home/home.page.ts` (+ spec), `ui/src/main.ts`, `ui/src/app/app.ts`, `ui/tools/strings.test.mjs`, `src/OcuPilot/Api/Error.cls`. None is on Epic 5's carve list (`panel*`, `proposal-card`, `reply`, `tool-call-card`, `context-chip`, `core/proposal-view.ts`, `core/turn.ts`) or in Epic 13's paths, and `core/navigation.ts` — which Epic 5 has modified — is **read only** here.

**Ledger inbox (Rule 17):** `ledger.sh slice 15-2-favorites-recent-items-and-menu-search` is empty — this story owns no ledger entries, so there is nothing to address or decline.

**Consumes:** `ui/src/app/core/api.ts` and `violations.ts` (transport and refusal decoding); `ui/src/app/core/navigation.ts` (`builtScreens`, `screenForUrl`, `screenVerdict`, `isListedScreen`) — read only; `OcuPilot.Screen.Registry.Roster` (route validation); `OcuPilot.Kernel.Utils.ReadRequestBody`; `OcuPilot.Kernel.AgentRules.ViolationsJson`.

**Consumed-by:** Story 15.5 (extends `Kernel.State.Pref` and the `/account/preferences` envelope with per-screen sort, filter, max rows, auto-refresh rate, side-bar open state and panel width); Story 15.6 (the theme choice is a per-user preference and takes a `Kind` in the same store). Story 15.3's About and links panel consume none of this.

## Verification

**Commands** (slot C — every IRIS MCP call carries `server: "ocupilot-slot-c"`; the dev container is `ocupilot-slot-c`; the throwaway is `--dir /tmp/ocupilot-c-ci --project ocupilot-c-ci --web 52779 --super 1978`; a browser run exports `OCUPILOT_BROWSER_ORIGIN=http://localhost:52779` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-c-ci`):

- `uv run scripts/check-objectscript.py` — expected: green, including `check_naming` (the 29-character cap on `OcuPilot.Kernel.State.Pref`), `check_state_package_isolation`, `check_state_sql_literal`, `check_route_ordering` and `check_handler_wire_tests` over the two new routes.
- `cd ui && npm test` — expected: `node --test tools/*.test.mjs` green including the new `account-preferences.test.mjs` and a `strings.test.mjs` whose widened band and fifteen new keys both pass, then the Angular runner green including the Home and command-box legs.
- `cd ui && npm run build` — expected: all six `prebuild` checkers pass. `client-lint.mjs` is the one that bites: every visible word is `{{ STRINGS.<key> }}`, every plain `aria-label` is exactly one interpolation (a composed name uses `[attr.aria-label]`), every non-ASCII byte is a `\uXXXX` escape, every `@if` condition is a paren-free member reference, and no color is hardcoded outside `_tokens.scss`.
- `bash scripts/lint-docs.sh` — expected: green over the appended EXPERIENCE.md row.
- Compile through the IRIS MCP tools against `ocupilot-slot-c`, then run `OcuPilot.Test.PrefState` and `OcuPilot.Test.PreferencesWire` **one class per call**, waiting for each to land in `%UnitTest_Result` before sending the next.
- `bash scripts/smoke.sh --container ocupilot-slot-c --user _SYSTEM --password SYS` — expected: non-zero executed checks, all passing.

**Manual checks:**

- Sign in, favorite a screen, sign out, sign back in **in a new tab**, open Home: both lists are as they were. Then clear the browser's site data for the origin and repeat — the lists are still there, which is the observable that distinguishes instance storage from browser storage.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
