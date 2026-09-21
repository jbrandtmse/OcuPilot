---
title: 'Story 15.2: Favorites, recent items and menu search'
type: 'feature'
created: '2026-09-19'
status: 'done'
baseline_revision: '31619c352286199e8dcfe223d31fea9984c0a210'
baseline_commit: '31619c352286199e8dcfe223d31fea9984c0a210'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-15-context.md'
warnings: ['oversized']
deferred:
  - summary: >-
      A refused preference write is never surfaced to the user: the client parks every
      non-ok result and no component reads a fault.
    evidence: |-
      `core/account-preferences.ts` `settle` returns on `result.kind !== 'ok'`, and no
      consumer reads a refusal. At the 20-favorite cap the instance answers 422
      PREFERENCES.LIMIT with a written reason (`Api/Error.cls` REASONPREFERENCESLIMIT)
      that reaches no surface. Fixing it needs a published string and an EXPERIENCE.md row.
    location: >-
      ui/src/app/core/account-preferences.ts (settle) and ui/src/app/shell/locator-bar.ts
    severity: medium
  - summary: >-
      Two concurrent adds of the same (user, kind, route) can trip the unique index and
      answer 500 instead of the documented no-op.
    evidence: |-
      `Pref.GuardedAdd` is check-then-insert: `OpenByKey` finds nothing in both processes
      and both save, so one loses on PrefUserKindNameIdx. Reachable from two tabs pinning
      or visiting the same screen at once. The matrix's concurrency row covers the update
      path (GuardedTouch/GuardedSaveIfCurrent), not the create path.
    location: >-
      src/OcuPilot/Kernel/State/Pref.cls GuardedAdd
    severity: medium
  - summary: >-
      When every stored row in a Home block names no built screen, the block shows its
      empty state and no Clear control, so rows the instance still holds are invisible and
      unclearable.
    evidence: |-
      `home.page.ts` renders the list and the Clear button under `@if (block.rows.length)`,
      and `rowsFor` drops routes that resolve to no built screen (AD-37). Reachable once a
      screen is withdrawn from the product. The per-row remove path is now open (the handler
      no longer requires a built route on remove), but the row is not rendered to remove.
    location: >-
      ui/src/app/areas/home/home.page.ts template
    severity: medium
  - summary: >-
      The Integration AC's browser-level observable -- sign out, sign in in a new tab, clear
      site data, both lists still there -- was not executed.
    evidence: |-
      The spec's Verification names it as a manual check and this pass did not perform it;
      it needs a browser and two sessions. Each link is covered separately (PreferencesWire
      on the instance, the app.spec rows on the wiring, api.test.mjs's localStorage ban),
      but the composition is not. A browser spec against the slot-C throwaway, with this
      story's bundle and server code deployed into it, would settle it.
    location: >-
      ui/browser/ (no spec) and the spec's ## Verification manual check
    severity: medium
  - summary: >-
      `app.ts`'s `inject(RecentsRecorder)` -- the only thing that brings the recorder into
      existence in the shipped app -- is pinned by no test.
    evidence: |-
      `recents-recorder.spec.ts` injects the service itself, so deleting the `app.ts` field
      reddens nothing and Recent items would be permanently empty. tsconfig sets no
      noUnusedLocals. An app.spec row navigating the real router to a built screen and
      asserting a visit on the captured stub would settle it.
    location: >-
      ui/src/app/app.ts:211
    severity: medium
  - summary: >-
      No test measures that a long remembered-screen label actually ellipsizes.
    evidence: |-
      `min-width: 0` was added to `.ocu-home-block-label` this pass, but jsdom computes no
      layout, so only a browser spec can observe it -- the shape
      `ui/browser/classic-link-card.browser-spec.mjs` already uses
      (`scrollWidth > clientWidth` plus the computed `text-overflow`).
    location: >-
      ui/src/styles/_components.scss .ocu-home-block-label
    severity: low
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

### Review Findings

2026-09-20, code review (tier full-opus; five layers: server/AD-conformance, client, acceptance
auditor, test falsifiability, adversarial). 36 findings, grouped to 26 entries: high 1, medium 8,
low 17, of which 2 were disproved on the instance. Fifteen patched here, three escalated with an
owner, three newly ledgered, three accepted as-is.

**High, patched — an unlisted screen was recorded, offered to the toggle and rendered on Home.**
`screenForUrl` answers the id-less parent declaration for an entity-keyed URL, so opening
definition 42 stored `agent/definitions/edit`, whose Home row opens the Definition form with no
definition. Eleven built screens declare `sideBarPosition: 0`, and every definition edit, database
drill and wallet-secret view poisoned Recent items with no user action. `command-box.ts` already
filters `isListedScreen` against exactly this, and the spec's `Consumes:` line names that helper;
no new surface called it. Now filtered at all three sites — `recents-recorder.ts` stops recording
one, `home.page.ts` `rowsFor` drops the rows an earlier build stored, and `locator-bar.ts` offers
no toggle — each with a pinning row, each falsified.

**Medium, patched.** (1) Home read the lists only at sign-in: `load()` has one production caller,
`App.verifyWhenSignedIn`, which fires on a session *state change*, so a write whose answer the
store parked left both blocks wrong for the life of the tab — and arriving at Home was the one
gesture that could not repair it. Home now reads on arrival. This also retires the triage log's
`[low] [reject]` of the parked-write finding, whose stated reason ("the next `load()` repairs it")
was false. (2) `favoritesCleared`, `recentsRemoveNamed` and `recentsRemoved` were wired at one site
each and asserted nowhere, so a crossed pair would name the wrong list to a screen-reader user with
the suite green; a row now reads each. (3) `app.ts`'s `recentsRecorder.reset()` was pinned by no
test although the triage log said it was; pinned now, and falsified. (4) AC2's remove and Clear
were approved on jsdom alone (Rule 3): both are now driven in the browser against the redeployed
bundle, with the instance re-read over the wire afterwards. (5) The browser spec asserted "no
browser storage" only against the context that *read* the lists, not the one that wrote them.

**Two findings disproved, recorded so they are not re-filed.** A layer reported cross-user leakage
from `Pref.UserName`'s case-folding collation, reasoning that `Security.Users.Name` is exact. The
precondition fails: `Security.Users`' IDKEY is `NameLowerCaseIndex` over a lowercased name
(verified on slot C — `_SYSTEM` stores `_system`), so IRIS keys principals case-insensitively and
`Alice` and `alice` cannot coexist. The store's granularity matches the principal store's. A second
layer reported `action: "remove"` with a long route answering 500 via `SQLCODE -490`. The -490 is
real through the Atelier query endpoint but not through the store: driven over the wire at the
shipped `MAXLEN = 512` with the guard as shipped, a 600-character remove answers 200, the
documented no-op. A speculative fix was written, disproved against the pre-patch shape, and
reverted rather than shipped.

**Escalated, owner `15-5-ui-state-that-survives-a-sign-out`:** DW-1326 (a refusal reaches no
surface), DW-1327 (check-then-insert — two further sites found: the cap check admits two adds of
*different* routes at 19, which catching the index violation would not fix, and `GuardedTouch`'s
create branch is the path every navigation drives), DW-1328 (Clear hidden when every stored row is
unresolvable, now reachable by one more route). **Newly ledgered:** DW-1340 (the wire suite clears
the operator's own lists), DW-1341 (the recorder writes after sign-out), DW-1342 (the toggle is not
a toggle within one round trip).

**Closed in the ledger, not here.** DW-1329, DW-1330 and DW-1331 are resolved by QA's work plus
this pass's additions. The frontmatter `deferred:` list and `## Auto Run Result`'s residual risks
still describe all six as open; they are build-auto's own record of what the implement stage
handed over, and the ledger is the authority on what is still open.

**Accepted as-is.** `AccountPreferences.generation` is dominated by `request`, since `reset()` bumps
both — defense in depth that matches the house shape (`agent-status.ts`); reopen if `reset()` ever
stops bumping `request`. The *Server unreachable on Home* matrix row is pinned at the store rather
than at Home; Home reads only the store, whose park is pinned under `node --test`.

## Spec Change Log

- 2026-09-20, lead spec gate: **AD-50** added to the governing ADs. The plan stage settled the per-user store's shape and correctly flagged it as architectural rather than writing the spine itself; the lead wrote the AD at this gate, so the plan could not have cited it. The sign-out/new-tab criterion is labeled the Integration AC (Rule 1) — it already was one in substance, naming Home as the consumer, the instance as the source and an observable effect across a session boundary.

## Review Triage Log

### 2026-09-20 — Review pass

- verdicts: 52 findings — high 0, medium 24, low 24, false 4, maybe-false 0
- findings:
  - `[medium]` `[patch]` A favorite whose screen is no longer built cannot be removed — `HandleUpdate` ran `IsBuiltRoute` for `remove` as well as `add`, so the row was stuck consuming a cap slot; the check is now add-only and `PreferencesWire` gained a leg proving a `remove` of an unbuilt route answers 200.
  - `[medium]` `[patch]` Every confirmation was announced before the write and never reflected its outcome — the two handlers now clear the region, issue the write, and set the sentence in `.then()` only when the store actually moved.
  - `[medium]` `[defer]` No refusal is ever surfaced to the user — real; fixing it needs a published string and an EXPERIENCE.md row, so it is deferred rather than invented here.
  - `[medium]` `[patch]` The two polite regions were visible page text that never cleared — both spans now carry `ocu-visually-hidden` (the `account-menu.ts:122` idiom) and the wrong SCSS comment is gone.
  - `[medium]` `[patch]` Repeating an action announced nothing — clearing the region before the write gives a repeat a real change to announce.
  - `[low]` `[patch]` `answered()` has no consumer and Home contradicts its documented contract — Home's empty-on-unreachable rendering is what the matrix asks for, so the wrong doc sentence was replaced rather than a gate added.
  - `[low]` `[patch]` `RecentsRecorder.lastRoute` survived a principal change — the recorder gained `reset()`, called from `app.ts`'s sign-out branch, pinned by a new spec row.
  - `[medium]` `[patch]` Recents could not re-order within one second — `Turn.Timestamp()` is whole seconds; `Pref.cls` now stamps at microsecond resolution and a new `PrefState` row (A, B, A with no `Hang`) is red at second resolution.
  - `[low]` `[patch]` The wire suite's ordering assertion was not load-bearing — the same stamp fix makes `ORDER BY UpdatedAt DESC` decide it; the 14 s `Hang` test is kept as the second-boundary case.
  - `[low]` `[patch]` `PreferencesWire` cleared the wrong account when the process user and the test user differ — `Clear()` now resolves `Http.GetTestUsername()`, which is the account the requests authenticate as.
  - `[low]` `[reject]` The wire suite hard-asserts the size of the screen roster — a roster shrinking below 21 built screens is not an everyday state, and the failure is loud and self-describing; guarding it would add a skip path.
  - `[low]` `[reject]` `Pref.DeleteAllGuarded()` is dead — the spec's Tasks name it explicitly, on the `Sharing`/`Hold` precedent; removing it is spec-bound.
  - `[medium]` `[defer]` The Integration AC's sign-out/new-tab/cleared-site-data observable was not executed — deferred with the browser-spec recipe that would settle it.
  - `[medium]` `[patch]` `app.ts`'s `accountPreferences.reset()` was pinned nowhere — `app.spec.ts` now captures the stub and carries two `Mutation (Rule 19)` assertions beside the three already there.
  - `[low]` `[reject]` AC2's "the locator toggle reads unpressed" after a Home removal is asserted in no single spec — both surfaces read one shared store, so the composition holds by construction; a cross-surface mount is more machinery than the claim is worth.
  - `[low]` `[reject]` The block headings are `<h2>`, siblings of the screen title — neither DESIGN.md nor EXPERIENCE.md fixes a level for them, so any change is a guess with no named harm.
  - `[low]` `[patch]` An ellipsized row label had no `title` — bound `[title]="row.label"`, the DW-146 remedy this file already records.
  - `[low]` `[reject]` Route validation uses `DescriptorForRoute` where the spec's Code Map names `Roster` — both are `Screen.Registry` and the behavior is identical; the only fix is to edit this build's spec.
  - `[low]` `[patch]` `OpenByKey`'s doc asserted an unverified case-insensitive-collation fact — the claim is deleted; the doc states only what the method does.
  - `[low]` `[reject]` `GuardedTouch` and `GuardedTrim` are two unguarded steps — a failure between them leaves the list one row over its cap until the next visit trims it; no user-reachable harm, and a transaction is complexity for a self-healing window.
  - `[low]` `[patch]` A dead `.map()` in the new command-box row (the assertion was on array length) — now asserts on `screens` directly. The two `async` rows with no `await` are harmless and were left.
  - `[low]` `[patch]` A body-read fault was refused 422 with nothing logged — `Account.cls`'s precedent logs the stage through `Fault.LogRaw`; `Preferences.cls` now does the same. The 422 and its code are unchanged, which is correct per that same precedent.
  - `[medium]` `[defer]` Two concurrent adds of the same key can trip the unique index — real check-then-insert race on the create path; the fix guards state this pass did not demonstrate.
  - `[medium]` `[patch]` A revisit inside one second does not move to the front — same root cause as the stamp finding above; closed by the microsecond stamp.
  - `[low]` `[reject]` A parked write discards a concurrent in-flight read — reachable only when a refused or failed write overlaps the first read, and the next `load()` repairs it; the fix adds branching to the request counter.
  - `[low]` `[patch]` Home paints its empty state before the first read settles — the matrix asks for exactly that on an unreachable instance; the store's wrong doc sentence was corrected instead.
  - `[medium]` `[defer]` The Clear control is hidden when every stored row is unresolvable — real; rendering it needs the block to carry a stored count the rendering does not have.
  - `[medium]` `[patch]` The locator toggle announces before the write — closed with the announcement rewrite above.
  - `[medium]` `[patch]` Home's remove and clear announce before the write — closed with the same rewrite.
  - `[medium]` `[patch]` Two consecutive removals announce once — closed by clearing the region first.
  - `[low]` `[patch]` `lastRoute` is not reset on a principal change — closed by `RecentsRecorder.reset()`.
  - `[low]` `[patch]` `PreferencesWire.Clear()` resolves the process user, not the request user — closed by `Http.GetTestUsername()`.
  - `[low]` `[reject]` `answered()` is documented as a render gate with no consumer — closed as a doc correction above; adding the gate would contradict the matrix's unreachable-Home row.
  - `[low]` `[reject]` The testing stub validates no route and enforces no cap — that is what a stub is for; both instance halves are pinned by `PreferencesWire`.
  - `[medium]` `[patch]` `void this.accountPreferences.load()` was pinned nowhere — closed by the `app.spec.ts` rows above.
  - `[medium]` `[patch]` `this.accountPreferences.reset()` was pinned nowhere — closed by the same rows.
  - `[medium]` `[defer]` Nothing constructs `RecentsRecorder` under an app-level test — deferred with the app.spec navigation row that would settle it.
  - `[medium]` `[patch]` Two `recents-recorder.spec.ts` rows could not fail for the guard they name — `stubAccountPreferences` now records its calls and both rows assert no POST was issued; the Home row also had to start from another route, since a same-URL navigation fires no `NavigationEnd`.
  - `[medium]` `[patch]` `.ocu-home-block-label` cannot ellipsize without `min-width: 0` — added, citing the same rule `.ocu-status-bar-version` carries. The browser measurement is deferred.
  - `[medium]` `[patch]` The locator toggle announces success before the write and never retracts it — closed with the announcement rewrite.
  - `[low]` `[patch]` `AccountPreferences.answered()` has no production consumer — closed as the doc correction above.
  - `[low]` `[reject]` Re-ranking an open command box moves the active option — reachable only if a favorites answer settles in the seconds the box is open during the first read; the fix adds a branch to the bump path.
  - `[false]` `[reject]` The added AD-37 command-box row cannot fail — it is red against the implementation the matrix row exists to exclude (a Screens group fed from the stored favorites rather than from the navigation roster), which is the realistic wrong shape, not a type-level tautology.
  - `[false]` `[reject]` Three AC sub-clauses carry no `mutation:` line — Rule 19 scopes one demonstrated mutation per acceptance criterion, not per clause, and every AC has one.
  - `[false]` `[reject]` `PREFERENCESBODY` has no `ReasonForViolation` arm — the layer filed this as "no gap there" itself: the code is an envelope reason, never a field violation, and the wire test asserts the flat shape.
  - `[medium]` `[patch]` The two new `app.ts` lines are pinned at no surface — closed by the `app.spec.ts` rows.
  - `[medium]` `[patch]` Recents ordering is exercised only at a timing regime the product does not produce — closed by the microsecond stamp, which makes the no-`Hang` row the pin.
  - `[medium]` `[defer]` The refusal's user-facing surface is never exercised against a refusal — same entry as the deferred refusal surfacing above.
  - `[false]` `[reject]` The command box's "drop" clause is a no-op — descriptive and correct: rows come from the navigation roster, so the clause is satisfied by construction rather than unimplemented; the added row pins that it stays so.
  - `[low]` `[patch]` `answered()` is a declared render gate with no consumer — closed as the doc correction.
  - `[low]` `[reject]` Caller-own is asserted where the username is an argument — `PrefState` pins per-user isolation through the store and `PreferencesWire` pins that the route accepts no `user` member; there is no second principal the route can reach.
  - `[medium]` `[defer]` The Integration AC's observable is declared not performed — same entry as the deferred Integration AC above.
  - `[low]` `[reject]` `IsBuiltRoute`'s length guard cannot produce an outcome distinct from the registry lookup — true, and it is a cheap defense-in-depth the spec names; removing it buys nothing.


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

**Lead AD gate (AD-50), executed by the lead on the slot C throwaway `ocupilot-c-ci`, 2026-09-20.** The throwaway was rebuilt from this story's source and bundle first, so the thing measured was the shipped artifact rather than the working tree.

- `mutation: OcuPilot.Kernel.State.Pref's three query sites change WHERE UserName = ? to WHERE UserName <> ? -> OcuPilot.Test.PreferencesWire went red, 3 of 6 methods` -- `TestAFavoriteRoundTripsOverTheWire` failed on "answering the list the read would answer", on the second-add no-op and on "leaving one entry". Baseline 6/6 before, 6/6 again after revert and recompile, and the throwaway's copy diffed byte-identical against the working tree. This pins AD-50's load-bearing claim -- that the store is keyed per user -- at all three sites at once rather than at the one a single test happens to reach.
- End-to-end on the same instance before the mutation: `GET /api/ocupilot/account/preferences` answers `200` with `{"favorites":[],"recents":[]}`, and `OcuPilot.Kernel.State.Pref` and `OcuPilot.Api.Preferences` are both compiled there.


**Commands** (slot C — every IRIS MCP call carries `server: "ocupilot-slot-c"`; the dev container is `ocupilot-slot-c`; the throwaway is `--dir /tmp/ocupilot-c-ci --project ocupilot-c-ci --web 52779 --super 1978`; a browser run exports `OCUPILOT_BROWSER_ORIGIN=http://localhost:52779` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-c-ci`):

- `uv run scripts/check-objectscript.py` — expected: green, including `check_naming` (the 29-character cap on `OcuPilot.Kernel.State.Pref`), `check_state_package_isolation`, `check_state_sql_literal`, `check_route_ordering` and `check_handler_wire_tests` over the two new routes.
- `cd ui && npm test` — expected: `node --test tools/*.test.mjs` green including the new `account-preferences.test.mjs` and a `strings.test.mjs` whose widened band and fifteen new keys both pass, then the Angular runner green including the Home and command-box legs.
- `cd ui && npm run build` — expected: all six `prebuild` checkers pass. `client-lint.mjs` is the one that bites: every visible word is `{{ STRINGS.<key> }}`, every plain `aria-label` is exactly one interpolation (a composed name uses `[attr.aria-label]`), every non-ASCII byte is a `\uXXXX` escape, every `@if` condition is a paren-free member reference, and no color is hardcoded outside `_tokens.scss`.
- `bash scripts/lint-docs.sh` — expected: green over the appended EXPERIENCE.md row.
- Compile through the IRIS MCP tools against `ocupilot-slot-c`, then run `OcuPilot.Test.PrefState` and `OcuPilot.Test.PreferencesWire` **one class per call**, waiting for each to land in `%UnitTest_Result` before sending the next.
- `bash scripts/smoke.sh --container ocupilot-slot-c --user _SYSTEM --password SYS` — expected: non-zero executed checks, all passing.

**Mutations (Rule 19)** -- each applied, observed red, reverted, and the tree confirmed byte-identical:

- AC1 (pin from the locator bar): mutation: replace the `: this.preferences.add(FAVORITE_KIND, route)` arm of `pending` in `locator-bar.ts` `toggleFavorite` with `Promise.resolve()` -> `locator-bar.spec.ts` "activating the toggle pins the screen" and "a second activation unpins it" go red on `preferences.favorites()`. (Repaired at code review: the announcement rewrite had made the recorded line name text the file no longer contains, so it could only have reddened by failing to compile.)
- AC2 (remove and clear from Home): mutation: replace `removeRemembered`'s write callback in `home.page.ts` with `() => Promise.resolve()` -> `home.page.spec.ts` "a per-row remove control names the screen it removes" goes red on `favorites()`, and, against the redeployed bundle, `ui/browser/preferences-integration.browser-spec.mjs` fails waiting for the Favorites block's empty state (executed at code review). (Repaired: the recorded line named text `announceOnChange` had already absorbed.)
- AC3 (recents registered by visiting): mutation: replace `this.preferences.registerVisit(screen.route)` in `recents-recorder.ts` with a no-op -> `recents-recorder.spec.ts` goes red on 5 of its 7 rows; only "registers nothing for a URL that resolves to no built screen" and the unlisted-screen row stay green. (Count repaired at code review: later patch groups added rows the original figure predates.)
- AC3 (newest-first and capped): mutation: change `IdsForUser`'s recent branch to `ORDER BY ID` -> `OcuPilot.Test.PrefState:TestRecentsReadNewestFirstAndTrimToTheDeclaredMaximum` failed on 3 assertions.
- Integration AC (the state is on the instance): mutation: drop `Set tSC = ..GuardedSave(tRow)` from `Pref.GuardedAdd` -> `OcuPilot.Test.PreferencesWire:TestAFavoriteRoundTripsOverTheWire` failed on 4 assertions, because the list the next read answers never held it. The browser-storage half is `ui/tools/api.test.mjs`'s standing ban, which `core/account-preferences.ts` does not touch.
- AC5 (favorites first in the command box): mutation: return `rows` instead of `[...favorite, ...rest]` from `screenCandidates` -> `command-box.spec.ts` went red on 2 rows, while the one-input/two-group/count assertions in the same rows stayed green.

**Matrix coverage added at the implement gate's audit:** the *Route no longer built* row says the
client drops such a route from both rendered lists **and from the command box**. The rendering half
was pinned by `home.page.spec.ts`; the command-box half was not, so `command-box.spec.ts` gained
"a favorite naming no built screen adds no row here, and the count is unchanged". It is a
matrix-row test, not an acceptance criterion's pinning test, so it carries no `mutation:` line.

**QA pass (DW-1329, DW-1330, DW-1331), executed on the slot C throwaway `ocupilot-c-ci`, 2026-09-20 (QA).**

- `ui/browser/preferences-integration.browser-spec.mjs` (QA) -- repaired: it called
  `leaveFirstLoginGate` once, inside `signedInAt`, then made two further `page.goto` calls with
  no call after either, so the gate (which re-fires on every fresh SPA bootstrap on a throwaway
  with no enabled definition) put the browser on the Definition form and the spec timed out
  waiting for `.ocu-home-block`. Fixed by calling `leaveFirstLoginGate` after each `goto`, the
  house pattern `ui/browser/processes.browser-spec.mjs` already uses.
  `mutation: drop the leaveFirstLoginGate call added after the HOME_URL goto -> the spec's one
  test failed on the exact reported symptom, TimeoutError waiting for .ocu-home-block`. This also
  settles the Integration AC's manual check above: a real second `BrowserContext` (a strict
  superset of "a new tab") now drives it, so favorites and recents held before sign-out render
  unchanged after signing back in with none of the first tab's storage.
- `ui/src/app/app.spec.ts` (QA) -- DW-1330: `app.ts`'s `inject(RecentsRecorder)` was pinned by no
  test; `recents-recorder.spec.ts` injects the service itself, so deleting that field reddened
  nothing there. Added a test that navigates the real router through the whole `App` tree and
  reads `AccountPreferences.recents()`.
  `mutation: replace inject(RecentsRecorder) with { reset: () => {} } in app.ts -> the new test
  failed (expected ['permissions/users'], got []), the other 31 app.spec.ts tests stayed green`.
- DW-1331 (rider, closed): `.ocu-home-block-label`'s `min-width: 0` had no test measuring that a
  long remembered-screen label ellipsizes; added to the same repaired spec.
  `mutation: drop min-width: 0 from .ocu-home-block-open in _components.scss, rebuild, redeploy
  -> the assertion failed (scrollWidth == clientWidth == 930, no overflow)`. Note for the next
  reader: `.ocu-home-block-label`'s own `min-width: 0` is not what gates this -- its
  `overflow: hidden` already gives it an automatic minimum size of 0 per the flexbox spec, so the
  same mutation applied to the label instead left the assertion green; `.ocu-home-block-open`'s is
  the load-bearing declaration.

**Code-review pass, executed on slot C (`server: "ocupilot-slot-c"`, dev container
`ocupilot-slot-c`; browser runs against the throwaway `ocupilot-c-ci`), 2026-09-20.** The bundle
was rebuilt and `docker cp`-ed into the throwaway before every browser result quoted here.

- `uv run scripts/check-objectscript.py` 500 files / 21 rules / 0 problems; `cd ui && npm test`
  1070 `node --test` + 695 component, 0 failures; `cd ui && npm run build` all six prebuild
  checkers clean; `bash scripts/lint-docs.sh` 0 issues over 93 files.
- All 500 classes loaded and compiled clean, then one class per call:
  `OcuPilot.Test.PrefState` 9/9, `OcuPilot.Test.PreferencesWire` 6/6.
- **Full browser suite against the redeployed bundle: 191 tests, 191 pass, 0 fail** — including
  `context-chip.browser-spec.mjs` and `switches.browser-spec.mjs`, which DW-1169 makes flaky and
  which did not flake on this run.
- mutation: drop `|| !isListedScreen(screen)` from `RecentsRecorder.record` ->
  `recents-recorder.spec.ts` "registers nothing for an unlisted screen" went red, answering
  `["agent/definitions/edit"]`. The same guard's two siblings were falsified together: mutation:
  drop it from `HomePage.rowsFor` and from `LocatorBar.favoriteRoute`, and drop
  `void this.preferences.load()` from HomePage's constructor -> 3 rows red across
  `home.page.spec.ts` and `locator-bar.spec.ts`, 692 green.
- mutation: delete `this.recentsRecorder.reset()` from `App.verifyWhenSignedIn`'s signed-out branch
  -> `app.spec.ts` "leaving the signed-in state..." went red at its last assertion (expected
  `['permissions/users']`, got `[]`), 694 green.
- mutation: replace `removeRemembered`'s write callback in `home.page.ts` with
  `() => Promise.resolve()`, rebuild, redeploy -> `preferences-integration.browser-spec.mjs` failed
  with a TimeoutError waiting for the Favorites block's empty state. This is the first real-runtime
  evidence for AC2's remove.
- Two reported findings were **disproved on the instance** rather than patched; the disproofs are
  in `## Review Findings` so the next pass does not re-file them.

**Manual checks:**

- Sign in, favorite a screen, sign out, sign back in **in a new tab**, open Home: both lists are as they were, and the lists survive a fresh browser context holding none of the first tab's storage. Automated by `ui/browser/preferences-integration.browser-spec.mjs` (QA); `OcuPilot.Test.PreferencesWire` is its instance-side half.

## Auto Run Result

Status: done
Blocking condition: none

**Built.** `Kernel/State/Pref.cls` (AD-50's one `Kind`-discriminated per-user store, keyed
`(UserName, Kind, Name)` unique, microsecond `UpdatedAt`), `Api/Preferences.cls` behind the two
`/account/preferences` routes appended to `Api/Router.cls`, three violation codes appended to
`Api/Error.cls`, `core/account-preferences.ts`, `shell/recents-recorder.ts`, the locator bar's
favorite toggle, Home's Favorites and Recent items blocks, the command box's favorites-first
partition, `_components.scss` rules from the published `row-overflow-menu` metrics, the fifteen
strings with their EXPERIENCE.md row, `main.ts`/`app.ts` wiring, and five test files.

**Files changed.** Server: `Kernel/State/Pref.cls` (new, the store), `Api/Preferences.cls` (new,
the caller-own handler), `Api/Error.cls` (+3 codes, append-only), `Api/Router.cls` (+2 routes and
their wrappers, append-only at the tail), `Test/PrefState.cls` and `Test/PreferencesWire.cls`
(new). Client: `core/account-preferences.ts` (new store), `shell/recents-recorder.ts` (new),
`shell/locator-bar.ts` (toggle), `areas/home/home.page.ts` (two blocks), `shell/command-box.ts`
(ranking), `core/strings.ts` (+15 keys, append-only), `main.ts` and `app.ts` (construct, provide,
load, reset), `styles/_components.scss` (block and toggle rules), `testing/account-preferences.ts`
(new stub with a call log), `tools/account-preferences.test.mjs` (new), `tools/strings.test.mjs`
(band widened with its reason), plus the component specs and the six app-level specs that now
provide the store.

**Review.** 52 findings over four layers: 0 high, 24 medium, 24 low, 4 false. Twelve patch groups
applied (the add-only route check, the body-read log, the microsecond stamp, the wire test's
account, the post-settle announcements on both surfaces, `ocu-visually-hidden`, `min-width: 0`
plus `[title]`, the stub's call log, the two `app.spec.ts` mutation rows, `RecentsRecorder.reset()`,
two doc corrections and a dead `map`). Six items deferred to the frontmatter `deferred:` list.
Rejected, each with its reason in the triage log: the roster-size assertion, `DeleteAllGuarded`
(spec-bound), the cross-surface AC2 clause, the heading level, the `Roster` naming (its fix edits
this spec), the two-step trim window, the parked-write request counter, the stub's missing cap,
the open command box's re-ranking, the caller-own framing, the length guard, and four `false`
findings.

**Follow-up review recommended: true.** Two or more medium entries were patched on a first pass.
The specific unverified risk: the announcement path was rewritten in `locator-bar.ts` and
`home.page.ts` to fire only after the write settles, and the stored timestamp changed resolution.
Neither has been exercised against a real refusal or a real browser -- `stubAccountPreferences`
cannot refuse, and jsdom computes no layout -- so both are verified in jsdom and on the instance,
not on the deployed bundle.

**Verified** (slot C, `server: "ocupilot-slot-c"`, container `ocupilot-slot-c`), all re-run after
the patches: `uv run scripts/check-objectscript.py` 500 files / 21 rules / 0 problems;
`cd ui && npm test` 1070 `node --test` + 689 component tests, 0 failures; `cd ui && npm run build`
all six prebuild checkers clean; `bash scripts/lint-docs.sh` 0 issues over 93 files; all 500 classes
loaded and compiled clean; `OcuPilot.Test.PrefState` 9/9 then `OcuPilot.Test.PreferencesWire` 6/6,
one class per call; `bash scripts/smoke.sh --container ocupilot-slot-c` executed=45 passed=45
failed=0 pending=2. Matrix Test Audit: every I/O row covered by a test that ran and passed; the
*Route no longer built* row's command-box half had no covering test and gained one.

**Residual risks.** The Integration AC's browser-level observable was not executed (deferred, with
the recipe). A refused write announces nothing rather than announcing a reason (deferred). A stored
route whose screen is withdrawn is now removable over the wire but is not rendered on Home, so it
is reachable only by Clear (deferred). Two concurrent adds of the same key can trip the unique
index (deferred).

**Beyond the declared footprint**, to be reported under `footprint_extensions:`:
`ui/src/app/testing/account-preferences.ts` (new stub), `ui/src/app/shell/recents-recorder.spec.ts`
(new), and a provider line in `app.spec.ts`, `app.wire.spec.ts`, `app.gate-outlet.wire.spec.ts`,
`shell/command-bar.spec.ts`, `shell/header.spec.ts` and `shell/screen-outlet.spec.ts`, each of
which mounts a component that now injects `AccountPreferences`.
