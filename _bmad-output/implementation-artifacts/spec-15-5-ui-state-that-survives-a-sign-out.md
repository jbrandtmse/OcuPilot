---
title: 'Story 15.5: UI state that survives a sign-out'
type: 'feature'
created: '2026-09-20'
status: 'ready-for-dev'
baseline_revision: '42dd2018caacb38fe15f4b1485530734cda87430'
baseline_commit: '42dd2018caacb38fe15f4b1485530734cda87430'
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

**Problem:** The six things the portal remembers — per-screen sort, filter, max rows and auto-refresh rate, the side bar's open state, the panel's width — live in `localStorage` under four keys. They are lost on a second device, on cleared browser storage, and to any user who signs in elsewhere, which is what this story's second acceptance criterion and AD-50 both refuse.

**Approach:** Give AD-50's `Pref` store its first value column and three new `Kind` values, widen the existing `GET`/`POST /api/ocupilot/account/preferences` envelope to carry them, and re-point the three client stores that own the six items at the instance. The browser's preference carve-out is removed rather than layered over.

## Boundaries & Constraints

**Always:**

- One store, one endpoint family (AD-50): new `Kind` values and one `Value` property on `OcuPilot.Kernel.State.Pref`, carried by the two routes already at `Api/Router.cls:110-111`. No new `State` subclass, no new route, no second per-user endpoint.
- Every write goes through `Kernel/State/Base`'s guarded conditional save; a refusal is `STATE.CONFLICT`, never a retry (Conventions › Concurrent writes).
- A screen-scoped preference is keyed by its **route**, so `IsBuiltRoute()`, AD-37's weak-reference semantics and the unresolvable-route degradation all apply unchanged.
- Every refusal is a 422 decided before anything is written, in one envelope with a stable code (AD-12, AD-39).
- A new user-facing literal is published in EXPERIENCE.md's Fixed strings table after its current last row `:384` before it exists as a `strings.ts` key.
- `ui/src/app/core/` imports no `@angular/core`; the store is a plain subscribable that components mirror into signals (AD-19).

**Never:**

- Never keep any of the six in browser storage, even as a cache: AC2 states that the browser holds only the per-tab token pair (AD-28, AD-47).
- Never widen the `localStorage` ban's exemption, key allow-list, `storage`-listener ban or `BroadcastChannel` ban. This story **removes** the exemption; the bans stay and get stricter.
- Never add or remove a screen from AD-43's seven-screen auto-refresh roster. This story persists the rate a screen remembers, nothing else.
- Never regenerate `ui/src/app/core/screens.generated.ts`; `screen-mirror.mjs --check` stays green with no regeneration. No descriptor is edited.
- Never edit a production file under `ui/src/app/shell/panel*` — Epic 5 owns them.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Read | signed-in user; `GET /account/preferences` | `200` with `favorites`, `recents` unchanged plus `views`, `refreshRates`, `shell` | No error expected |
| Set a value | `POST {kind:"view", action:"set", route, value}` | `200`; one row per `(user, kind, route)`, created or conditionally updated | — |
| Concurrent set of the same key (DW-1327) | two writes of the same `(user, kind, name)` race | the documented no-op or the conditional update; never a 500 | duplicate-key violation is caught and the row re-read |
| Concurrent adds at the cap (DW-1327) | two adds of different routes with 19 held | at most `FAVORITEMAX` rows exist afterward | the count is taken inside the guarded frame, immediately before the save |
| Empty value | `value` is `""` | `422 PREFERENCES.VALUE` before any write | an empty `%String` stores as SQL `NULL` and is never matched again (`Api/Preferences.cls:13-16`) |
| Unknown shell member | `{kind:"shell", name:"anything"}` outside the closed set | `422 PREFERENCES.NAME` | closed enum, refused before the write |
| Extra member | any member outside the grammar | `422 PREFERENCES.BODY` | the existing ladder, taught `value` |
| Refused write reaches the user (DW-1326) | the instance answers a non-`ok` result | the store exposes the envelope's `reason` and the surface announces it as `role="alert"` (`EXPERIENCE.md:665`) | the previous lists stay standing; nothing is emptied |
| Read has not answered yet | sign-in, before the read settles | published defaults render (side bar open, panel 400 px, rate off, max rows 1,000); the remembered state applies once answered | a failed read keeps the defaults and never clears |
| All stored rows name no built screen (DW-1328) | every row in a Home block resolves to no built or listed screen | the block reports the stored count and keeps its Clear control | AD-37: renders as no-longer-present, never hides the rows' existence |
| Sign out and back in, fresh browser | browser storage empty | all six return as they were | — |

</intent-contract>

## Code Map

### Server

- `src/OcuPilot/Kernel/State/Pref.cls` — `UserName` `:26`, `Kind` MAXLEN 16 `:30`, `Name` MAXLEN 512 `:36`, `UpdatedAt` `:41`, unique `PrefUserKindNameIdx` `:43`. Kind parameters `:46`/`:49`, caps `:53`/`:57`. `GuardedListForUser` `:68` (entry built `:80-81`), `GuardedAdd` `:98`, `GuardedRemove` `:130`, `GuardedClear` `:147`, `GuardedTouch` `:171`, `GuardedTrim` `:205` (its `:200-204` warning: only `recent` has an ordering branch), `OpenByKey` `:253`, `Text` `:283` (the `$Char(0)` normalizer every column read goes through). The header's own sentence at `:16-17` charters the value column.
- `src/OcuPilot/Kernel/State/Base.cls` — `RowVersion` `:97`, `ROUTEMAXLENGTH` `:114`, `GuardedSaveIfCurrent` `:167` (conditional update `:188`, zero-rowcount refusal `:193-195`), `IsStaleSave` `:215`. Reusable SQL seams `:461`, `:606`, `:715`.
- `src/OcuPilot/Api/Preferences.cls` — grammar members `:20-36`, `CallerUsername` `:39`, `HandleRead` `:47`, `HandleUpdate` `:75`, the refusal ladder `:80-151` (**unknown-member refusal `:98-108` is what must learn `value`**), `Apply` `:171`, `Body` `:190-207`, `Routes` `:212`, `IsKnownKind` `:226`, `IsKnownAction` `:234`, `IsBuiltRoute` `:246`, `RenderViolation` `:272`. Header `:13-16` documents the SQL-`NULL` trap.
- `src/OcuPilot/Api/Error.cls` — `ReasonForViolation` `:1030-1070` (its `Quit ""` fallthrough `:1069` is the trap), violation arms `:1065-1066`, the `PREFERENCES.*` parameter/reason pairs `:1232-1254`, `STATECONFLICT` `:575`.
- `src/OcuPilot/Api/Router.cls` — `/account/preferences` GET `:110` and POST `:111`; `<Routes>` ends `:115`. **Unchanged by this story.**
- `src/OcuPilot/Test/EndpointCoverage.cls` — rows `:76` (GET) and `:77` (POST, `refusal="1"`) already cover both verbs, so **no probe row is added**; `TestEveryRouteHasAProbeAndEveryProbeHasARoute` `:327` stays green.
- `src/OcuPilot/Test/PrefState.cls` — the store-level suite (nine tests `:96-247`); `src/OcuPilot/Test/PreferencesWire.cls` — the wire suite and the class shape a new `Kind` extends: `PREFERENCESPATH` `:18`, `Payload` `:83`, the four `check-objectscript` markers at `:50`/`:78` (request), `:111` (status), `:112` (content type), `:52`/`:113` (body shape).
- `scripts/check-objectscript.py` — `WIRE_MARKERS` `:1473-1478`, `names_key` `:1515-1528`, `check_handler_wire_tests` `:1531`, `check_route_ordering` `:1760`.

### Client

- `ui/src/app/core/preferences.ts` — the carve-out being removed: `SIDE_BAR_OPEN_KEY` `:23`, `SCREEN_REFRESH_RATES_KEY` `:34`, `SCREEN_VIEWS_KEY` `:41`, `PANEL_WIDTH_KEY` `:44`, `PREFERENCE_KEYS` `:51-56`, `ScreenViewPreference` `:59-64`, `readPreferenceStorage` `:89`, `PreferenceStore` `:97` with `sideBarOpen` `:139`, `setSideBarOpen` `:145`, `panelWidth` `:154`, `setPanelWidth` `:162`, `refreshRate` `:177`, `setRefreshRate` `:184`, `screenView` `:194`, `setScreenView` `:209`. Its EXPERIENCE.md citations sit at `:5-10`, `:26-27`, `:37-39`, `:43`.
- `ui/src/app/core/account-preferences.ts` — the store to extend, not to duplicate: `ACCOUNT_PREFERENCES_PATH` `:30`, kinds `:33`/`:36`, `generation` `:104`, `request` `:114`, `load` `:150`, `add`/`remove`/`clear` `:155`-`:165`, `reset` `:185`, `write` `:194`, **`settle` `:203` whose `:209-211` is DW-1326's park**. Provided `ui/src/main.ts:193`, `:252`; injected `ui/src/app/app.ts:195`, reset `:486`, loaded `:523`.
- `ui/src/app/core/shell-state.ts` — side-bar open: read `:66`, persist `:238` (`setOpen` `:236`); the two branches that deliberately do **not** persist are `:181-186` (yield collapse, DW-134) and `:223-227` (Escape, DW-144); `core/panel-layout.ts:270-281` likewise moves no preference.
- `ui/src/app/core/panel-layout.ts` — width: read `:170`, writes `:303` (`endDrag`) and `:330` (`applyWidth`). Applied by `ui/src/app/app.ts:178` over the getter `:325-327`. `ui/src/app/shell/panel-resize-handle.ts` references neither `preferences` nor the key — it calls `PanelState` only, so the **production** path is entirely inside `core/`.
- `ui/src/app/core/screen-store.ts` — sort/filter/maxRows/rate: restore `:81-87`, `setSort` `:240-242`, `setFilter` `:262`, `setMaxRows` `:275-278`, `setRate` `:297-300`, `rememberView` `:305-312`, `reset` `:347-349`.
- `ui/src/app/areas/home/home.page.ts` — DW-1328's site: `rowsFor` `:830-848` with the drop guard `:833-834`, `resolvedBlocks` `:505-530`, rows rendered `:252-275`, **Clear control `:277-279`**, empty state `:281`.
- `ui/src/app/testing/account-preferences.ts` — the stub; every `/account/preferences` call answers `ok` (`:53-60`), so **it has no refusal path** — DW-1326's rider.
- `ui/tools/api.test.mjs` — the ban: `PREFERENCE_MODULE_PATH` `:705`, `PREFERENCE_MODULE_ALLOWS` `:708`, `FORBIDDEN` `:710-719` (cookie `:711`, `localStorage` `:712`, `BroadcastChannel` `:713`, `storage` listener `:714-717`), the exemption clause `:754`, its integrity test `:762-786`, the raw-handle allow-list `:793`, the key allow-list `:807-830`.
- `ui/src/app/core/strings.ts` — last table key `:1225` with its `/** EXPERIENCE.md:384 */` at `:1224`, `} as const;` `:1252`, a per-story comment block at `:1206-1211`. `ui/tools/strings.test.mjs` — count band `:461-464` (150..600, not widened), set equality `:467-471` and `:491-500`, unique values `:504-509`.
- `ui/browser/preferences-integration.browser-spec.mjs` — the template: a real sign-out `:221-233`, sign-in in a **new `BrowserContext`** `:243-244`, and the storage assertions `:199-217`.

### Read-only evidence

- `prd.md:1003` FR-73's done-condition — "per-user state survives a sign-out". The five EXPERIENCE.md sentences saying "per browser", each one physical line: `:53`, `:395` (side bar); `:55`, `:406`, `:455` (panel width). `prd.md:314` says the same of the panel. `EXPERIENCE.md:407` already publishes "remembered per user" for the context switch.
- `EXPERIENCE.md:643` the auto-refresh roster and "Setting, sort, filter and max rows persist per screen"; `:445` the max-rows cap; `:665` the `role="status"` / `role="alert"` split; `:682` the yield auto-collapse keeping the remembered state; `:384` the Fixed strings table's last row.

## Tasks & Acceptance

**Execution:**

- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` — replace "per browser" with "per user, on the instance" **in place and line-neutrally** at `:53`, `:55`, `:395`, `:406` and `:455`, each annotated `[AMENDED 2026-09-20 — see the story change log]`. No line above `:384` changes its number. Then **append** one Fixed strings row after `:384` for DW-1328's empty-state sentence.
- `_bmad-output/planning-artifacts/prds/prd-OcuPilot-2026-09-08/prd.md` — the same line-neutral correction at `:314` (FR-10's panel bullet), so the PRD stops contradicting its own FR-73 done-condition.
- `src/OcuPilot/Kernel/State/Pref.cls` — add `Property Value As %String(MAXLEN = 256)` after `:36`, **outside** the unique index at `:43`, read through `Text()`. Document at the property that this is **not** a `SCHEMAVERSION` move: every pre-existing row reads `Value` as the safe default `""` and the membership kinds ignore it. Add `KINDSCREENVIEW = "view"`, `KINDREFRESH = "refresh"`, `KINDSHELL = "shell"` and the closed set of `shell` member names. Add `GuardedSetValue(pUserName, pKind, pName, pValue)` — create or conditionally update in one guarded frame; emit `value` from `GuardedListForUser` `:80-81`. State at the class that the three new kinds are never trimmed (one row per key), so `:200-204`'s ordering warning does not apply.
- `src/OcuPilot/Kernel/State/Pref.cls` — **DW-1327**: make `GuardedAdd` `:98` and `GuardedTouch` `:171` survive the race their check-then-insert loses. Catch the `PrefUserKindNameIdx` violation and re-read the row, so a concurrent duplicate is the documented no-op rather than a 500; take the cap count inside the guarded frame immediately before the save so two adds of different routes cannot both pass at 19. `GuardedSetValue` inherits the same shape rather than repeating the defect.
- `src/OcuPilot/Api/Preferences.cls` — widen the envelope: `Body()` `:190-207` gains `views`, `refreshRates` and `shell`; `Routes()` `:212` keeps membership kinds at `{route}` and emits `{route, value}` / `{name, value}` for the value-bearing ones. Add `ACTIONSET` and an optional `value` member to the grammar at `:20-36`, teach the unknown-member refusal `:98-108` about `value`, refuse `value` on a membership kind and require it on `set`, validate a `shell` name against the closed set and a screen-scoped name with `IsBuiltRoute()` `:246`, and add the `set` arm to `Apply()` `:171`. Every refusal stays 422 before any write.
- `src/OcuPilot/Api/Error.cls` — **shared-append**: add `PREFERENCESVALUE` / `REASONPREFERENCESVALUE` and `PREFERENCESNAME` / `REASONPREFERENCESNAME` near `:1249`, **and an arm for each in `ReasonForViolation` `:1030-1070`** — without the arm the `reason` serializes empty at `:1069`.
- `src/OcuPilot/Test/PrefState.cls` — extend: the value column round-trips through `Text()`; a value-bearing row is keyed by the same triple; the two DW-1327 races (duplicate insert, cap at 19) each answer their documented outcome; the three new kinds are never trimmed.
- `src/OcuPilot/Test/PreferencesWire.cls` — extend: the widened `GET` body; a `set` round trip; the three new 422 codes each carrying a non-empty `reason`; a membership kind refusing `value`. Keep the four wire markers.
- `ui/src/app/core/account-preferences.ts` — carry the four new kinds on the one store: `views()`, `refreshRates()`, `shell()`, and `setValue(kind, name, value)` over the existing `write()` `:194`. Keep the request and generation counters, the never-cleared-on-transport-failure branch and `reset()` `:185`. **DW-1326**: replace the silent park at `:209-211` with a recorded fault carrying the envelope's `reason`, and expose `fault()` for a surface to read.
- `ui/src/app/core/shell-state.ts`, `core/panel-layout.ts`, `core/screen-store.ts` — re-point the six reads and writes at the account store. The non-persisting branches (`shell-state.ts:181-186`, `:223-227`, `panel-layout.ts:270-281`) stay non-persisting, so `EXPERIENCE.md:682`'s yield rule is unchanged. Until the read answers, the published defaults render; the remembered state applies once, on the answer.
- `ui/src/app/core/preferences.ts` — delete the module, its four keys and `readPreferenceStorage`. `ui/src/main.ts` and `ui/src/app/app.ts` drop the provider.
- `ui/tools/api.test.mjs` — remove the exemption (`:705`, `:708`, `:754`, `:767`, `:781`, `:793`) and the key allow-list tests `:807-830`; keep every ban at `:710-719` and assert that `localStorage` now has **no** exempted path. The ban is narrowed, never widened.
- `ui/src/app/shell/locator-bar.ts`, `ui/src/app/areas/home/home.page.ts` — **DW-1326**: the announcement guards read `fault()` and announce the refusal as `role="alert"` (`EXPERIENCE.md:665`), not the polite `role="status"` a success takes.
- `ui/src/app/areas/home/home.page.ts` — **DW-1328**: carry the count of rows the instance holds on each block, before `rowsFor` `:830-848` drops the unresolvable ones; render the Clear control `:277-279` whenever that count is non-zero, and have the empty state `:281` say the block holds rows naming no screen that exists here. AD-37's Rule is what this satisfies.
- `ui/src/app/testing/account-preferences.ts` — add the refusal and transport-failure paths the stub lacks, so DW-1326's surfacing has a client test.
- `ui/src/app/core/strings.ts` — **shared-append** the new keys in one block with a leading comment naming the story; reuse an existing key rather than repeating a value.
- `ui/tools/{account-preferences,panel-layout,shell-state,screen-store,refresh}.test.mjs` — re-point every assertion that reads a `localStorage` key at the account store; add the new store's cases (a value set, a refusal surfacing, the defaults-before-answer settle).
- `ui/src/app/shell/side-bar.spec.ts`, `command-box.spec.ts`, `areas/home/home.page.spec.ts`, `shell/{rail,rail-wire,data-table,list-page,status-bar}.spec.ts` — the same re-point; plus Home's DW-1328 rows.
- `ui/browser/ui-state-survives-sign-out.browser-spec.mjs` — NEW. Against the redeployed bundle: set a sort, a filter, a max-rows cap and a refresh rate on a roster screen, collapse the side bar, resize the panel; assert neither `localStorage` nor `sessionStorage` holds any of them; sign out for real and sign in again in a **brand-new `BrowserContext`**; assert all six return as they were.

**Acceptance Criteria:**

- Given per-screen sort, filter, max rows and auto-refresh rate, the side bar's open state and the panel's width, when the user signs out and signs back in, then each returns as it was.
- Given a browser whose storage has been cleared, when the user signs in, then all six still return — and neither `localStorage` nor `sessionStorage` holds any of them, the browser carrying only the per-tab token pair.
- **Integration AC (Rule 1):** Given the six set on one browser context, when the user signs in from a **new** browser context against the deployed bundle, then all six render as they were — the widened store, the widened envelope and the three re-pointed client stores observed end to end in the browser tier, not by inspecting the handler.
- Given a preference write the instance refuses, when the refusal arrives, then its published reason is announced as `role="alert"` and the previous state stays on screen (DW-1326).
- Given a Home block all of whose stored rows name no built screen, when Home renders, then the block reports that it holds rows and keeps its Clear control (DW-1328).
- Given AD-43's seven-screen roster, when this story ships, then the roster is unchanged and no screen descriptor is edited — `screen-mirror.mjs --check` is green with no regeneration.

## Spec Change Log

- 2026-09-20 (lead, after the orchestrator's ruling): unblocked. `panel-resize-handle*` is released from Epic 5's carve and treated as trunk, so the three `PANEL_WIDTH_KEY` assertions in `ui/src/app/shell/panel-resize-handle.spec.ts` are re-pointed at the account store; the file is reported under `footprint_extensions:` against `origin/OCU-1-epic5` at `b04e2a1`. Frontmatter `status` reset `blocked` -> `ready-for-dev`.

## Review Triage Log

## Design Notes

**Governing ADs (Rule 6):** **AD-50** (one `Kind`-discriminated store, the value property it anticipates, the caller-own route, and "a preference kept only in `localStorage` fails the criterion"), **AD-19** (framework-free store, components mirror into signals), **AD-9** (the protected database and the escalated frame), **AD-37** (weak references — DW-1328), **AD-43** (the roster is closed at seven; only the remembered rate changes), **AD-36** (this is not a declared read), **AD-12** and **AD-39** (one envelope; a field-level code needs its published reason), **AD-28** and **AD-47** (the browser holds only the per-tab token pair), **AD-21** (values are bound, never concatenated). Conventions rows: *When `SCHEMAVERSION` moves*, *Concurrent writes to OcuPilot's own state*, *`%String` reads*, *REST route ordering*, *Client asset homes*, *Tests*, *ObjectScript naming*.

**Why the carve-out is removed rather than layered over.** AC2 does not merely say the state lives on the instance; it says what the browser holds — "only the per-tab token pair, which is deliberately not persistent". A `localStorage` copy kept as a cache contradicts that clause directly, and AD-50's "only" is what makes the cheap reading available at all. So the four keys go, the module goes, and `ui/tools/api.test.mjs`'s `localStorage` rule loses its one exemption. That is a narrowing of the ban, not a widening: the exact-path exemption, the closed key allow-list, the `storage`-listener ban and the `BroadcastChannel` ban are all either kept or made stricter.

**Why `EXPERIENCE.md`'s "per browser" is corrected rather than halted on.** Three authorities agree that this state is per user on the instance — `prd.md:1003`'s FR-73 done-condition ("per-user state survives a sign-out"), this story's own AC2, and AD-50, which is `status: final` and binds Story 15.5 by name. One document disagrees, in five sentences and one PRD bullet, and `EXPERIENCE.md:407` already publishes the per-user scope for a sibling preference. That is a stale scope word, not a second defensible reading, so it is corrected at its origin (Rule 5, apply-and-report). Each of the six is a single physical line, so every edit is line-neutral and no `EXPERIENCE.md:N` comment in the client moves.

**Why screen-scoped preferences are keyed by route.** The client keys them by descriptor class name today. Keying the stored row by route instead reuses `IsBuiltRoute()`, keeps AD-37's weak reference and the unresolvable-route degradation identical to favorites and recents, and needs no change to `screens.generated.ts`. The client already resolves a screen's route from its descriptor.

**Why the value column does not move `SCHEMAVERSION`, and no probe row is added.** Conventions › *When `SCHEMAVERSION` moves*: a property every pre-existing row reads as a safe default is not a meaning change — a `favorite` row written before this story reads `Value` as `""` and ignores it, as `RowVersion` reaching all eight `State` subclasses moved nothing. An empty value is refused at the handler rather than stored, because IRIS stores an empty `%String` as SQL `NULL` and the key lookup never matches it again (`Api/Preferences.cls:13-16`). And no route is added, so `EndpointCoverage.cls:76` and `:77` already cover both verbs and `TestEveryRouteHasAProbeAndEveryProbeHasARoute` (`:327`) is unaffected.

**Ledger inbox (Rule 17).** All three entries are addressed by Tasks & Acceptance items citing them: **DW-1326** (the store records a fault and two surfaces announce it; the stub gains a refusal path), **DW-1327** (both create paths catch the unique-index violation and the cap count moves inside the guarded frame), **DW-1328** (the block carries its stored count and keeps Clear). None is declined.

**Contended and out-of-footprint paths, declared (Rule 11).** Epic 15's own: `ui/src/app/core/**` (except the six files Epic 5 has modified, which stay read-only), `ui/src/app/shell/{side-bar,command-box,locator-bar,rail,status-bar}*`, `ui/src/styles/**`, `src/OcuPilot/Api/*`. Shared-append: `src/OcuPilot/Api/Error.cls`, `ui/src/app/core/strings.ts`, EXPERIENCE.md's Fixed strings table after `:384`. Shared-create: `ui/browser/ui-state-survives-sign-out.browser-spec.mjs`. To be reported under `footprint_extensions:` — `src/OcuPilot/Kernel/State/Pref.cls`, `src/OcuPilot/Test/{PrefState,PreferencesWire}.cls`, `ui/src/main.ts`, `ui/src/app/app.ts`, `ui/src/app/areas/home/home.page.ts` (+ spec), `ui/src/app/testing/account-preferences.ts`, and the `ui/tools/*.test.mjs` and `*.spec.ts` files listed under Execution. `ui/browser/panel.browser-spec.mjs:298` asserts the width survives a reload, which it still does — expected to stay green, re-verify rather than edit.

**`panel-resize-handle*` is trunk, and the three assertions are in scope (orchestrator ruling 2026-09-20).** `ui/src/app/shell/panel-resize-handle.spec.ts` asserts `stored.get(PANEL_WIDTH_KEY)` at `:69`, `:91` and `:102`; those cannot stay green once the width leaves browser storage. The carve on `shell/panel*` protects Epic 5's proposal and turn surface, and this file matched it by name only: Epic 4 created it in Story 4.3 and has merged, Epic 5 has never touched it or `panel-resize-handle.ts`, and the production file names neither `preferences` nor the key. The carve is now narrowed to `panel.ts`, `panel.spec.ts`, `proposal-card*`, `reply*`, `tool-call-card*`, `core/proposal-view.ts` and `core/turn.ts`. Re-point the three assertions at the account store and report the file under `footprint_extensions:` against `origin/OCU-1-epic5` at `b04e2a1`.

**Consumes:** `OcuPilot.Kernel.State.Base`'s guarded conditional save; `OcuPilot.Api.Response` / `Error.RenderViolation`; `ui/src/app/core/api.ts`'s `requestJson`; `core/account-preferences.ts`'s landed store shape; `Screen.Registry`'s built-route set.

**Consumed-by:** `core/shell-state.ts`, `core/panel-layout.ts` and `core/screen-store.ts` are the three consumers in this story, and the Integration AC exercises all three through the browser. Story 15.6 (the theme, deferred) is the next `Kind` this store will carry; no other story in this epic consumes it.

## Verification

**Slot B.** Every IRIS MCP call carries `server: "ocupilot-slot-b"`; the dev container is `ocupilot-slot-b`. Anything mutating shared runtime state — the wire tests, the browser specs — runs on the **throwaway** `bash scripts/ci-throwaway.sh up --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci --web 52777 --super 1976`, torn down only by whoever ran its `up`. A browser run exports both `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci`. Stateful tests run **one class or suite per tool call**, waiting for each to land in `%UnitTest_Result` before the next.

**Targeted `(loop)`** — run these while implementing, patching and on every rework pass:

- `(loop)` `uv run scripts/check-objectscript.py` — green, including `check_handler_wire_tests` still finding `Test/PreferencesWire.cls`. **Required before any commit touching `Api/Error.cls`; quote the result.**
- `(loop)` `cd ui && npm run test:tools` — green including the re-pointed `api`, `account-preferences`, `panel-layout`, `shell-state`, `screen-store` and `refresh` suites, and `strings.test.mjs` inside the unchanged `150..600` band.
- `(loop)` `cd ui && npm run test:components` — green including Home's DW-1328 rows and the re-pointed shell specs.
- `(loop)` `cd ui && npm run build` — all six `prebuild` checkers pass; **`screen-mirror.mjs --check` green with no regeneration**.
- `(loop)` `bash scripts/lint-docs.sh` — green over the EXPERIENCE.md and prd.md edits.
- `(loop)` Compile through the IRIS MCP tools against `ocupilot-slot-b`, then run `OcuPilot.Test.PrefState` and `OcuPilot.Test.PreferencesWire` **by name, one class per call**.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/ui-state-survives-sign-out.browser-spec.mjs`, after `npm run build` and `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`.
- `(loop)` `bash scripts/smoke.sh --container ocupilot-slot-b --user _SYSTEM --password SYS` — non-zero executed checks, all passing.

**Full `(once, before dev_complete)`** — both run once at the end of the implement stage, and again at the lead's smoke gate and in CI, which is where a regression outside this story's own files is caught:

- `(once)` the **full ObjectScript sweep** over `OcuPilot.Test.*`, one class per call.
- `(once)` `cd ui && npm run build`, `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then the **full** `npm run test:browser`. **The output directory is `dist/ocupilot-ui`**; a result read before the rebuild and redeploy is not evidence. Known non-findings: DW-1169's flake in `context-chip.browser-spec.mjs` and `switches.browser-spec.mjs`, and DW-1387's `messages-log` tail-window effect on a second full run against one container.

**Mutations (Rule 19)** — one per AC, each applied, observed red, reverted, the tree confirmed byte-identical; record each here as `mutation: <change> -> <test that went red>`.

**Manual checks:**

- Sign in on a second browser profile and confirm the six arrive as the first profile left them.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

**What this pass planned.** The whole story is specified and dev-ready apart from one decision the runner may not take. AC2 states the browser holds only the per-tab token pair, so the six preferences move onto AD-50's `Pref` store — its first `Value` property, three new `Kind` values, a widened `/account/preferences` envelope, the three `core/` stores re-pointed, and `ui/src/app/core/preferences.ts` with its `localStorage` exemption removed. All three ledger entries are chartered as Tasks & Acceptance items.

**The decision taken.** The production path stays inside `core/`: `shell/panel-resize-handle.ts` references neither `preferences` nor `PANEL_WIDTH_KEY`, and every width write goes through `core/panel-layout.ts:303` and `:330`. The orchestrator granted option (a) on 2026-09-20 and narrowed the carve: `panel-resize-handle*` is released as trunk, so the three assertions are re-pointed at the account store. Option (b), a `localStorage` copy for the width alone, was costed and rejected because it contradicts AC2 and AD-50.
