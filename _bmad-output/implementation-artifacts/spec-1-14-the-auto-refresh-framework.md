---
title: 'Story 1.14: The auto-refresh framework'
type: 'feature'
created: '2026-09-12'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** No screen can keep itself current. There is no timer, no per-screen store, no client event bus, and the two chrome slots that display refresh (`command-bar.ts:97` spacer, `status-bar.ts:150` `hasStamp` returning a hard `false`) are wired to nothing. Separately, three sightings in this epic — DW-4, DW-102, DW-157 — show the same defect: a single-flight read that *joins* an in-flight request is right for a duplicate and wrong when the input changed, and each was patched locally.

**Approach:** Build the one framework AD-43 requires — a descriptor-declared refresh setting, one shared timer behind an injected `schedule` seam, one per-descriptor signal store with a persisted subset, one client-side change/proposal bus — and give the join-versus-queue question its general answer as a shared `single-flight` primitive (join on unchanged input, mark-dirty-and-re-run-**once** on changed input), consumed by both the refresh tick and `NavigationService.reload()`.

## Boundaries & Constraints

**Always:**
- Refresh consumes Story 1.13's taxonomy and connectivity service. A tick that meets a `Fault` **suspends and parks one re-arm** via `connectivity.retryWhenReachable`; it never probes, never classifies, never re-arms itself. `refresh.ts` imports no `ApiService`.
- The timer is injected: `schedule?: (run, delayMs) => void` defaulting to `setTimeout`, byte-identical in shape to `connectivity.ts:52` / `session.ts:110`. The seam returns **no cancel handle**, so cancellation is a generation counter captured at arm time and compared inside the callback (`session.ts:305-311` precedent). A clock reading is a second injected seam, `now?: () => Date`.
- Exactly one pending arm exists at any moment, across every bound screen and every rate change.
- The framework re-fetches through the screen's **registered read**, passing the store's `maxRows` and recording the read's `truncated` flag. Binding a refreshing screen that registered no read is refused.
- `refreshes` and `refreshRates` are declared in the screen descriptor (AD-5) and travel to the client through `screen-mirror.mjs`, never a second hand-written source.
- Per-screen preferences go through `PreferenceStore` — the only module permitted to touch `localStorage` — under **one** newly-declared allow-list key, so the closed list stays closed.
- Resume is a predicate over all three conditions (`rate > 0`, no live proposal, no fault-suspension), recomputed on every transition. Never a single `paused` boolean.

**Never:**
- No spinner, skeleton, toast or live region on a tick; sort, filter, selection, scroll and max rows are untouched by a re-fetch.
- No second failure classifier, second banner, second probe, second timer, or per-screen refresh implementation.
- No invented user-facing copy and no growth of `REQUIRED_ALONGSIDE_TABLE` (DW-126 is the owner's, escalated).
- No test that waits on a real clock. No `docker compose up`/`down`/`restart`.
- Not in scope: the descriptor-declared read's implementation (Story 2.3), the data table (2.4), any proposal *publisher* (Epic 5), any write *publisher* (Epic 2).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Bind a refreshing screen | descriptor `refreshes: true`, `refreshRates: [10]`, stored rate 10 | one arm at the seam with `delayMs === 10000`; chip reads `Auto-refresh: every 10 s`; `hasStamp` true | registered read missing → bind throws naming the descriptor |
| Bind a non-refreshing screen | Home (`refreshes: false`) | nothing armed; no chip; `hasStamp` false | — |
| A tick fires | armed, store holds sort/filter/selection/scroll/maxRows | exactly one call to the registered read with the store's `maxRows`; `data`, `truncated`, `lastUpdate` replaced; the other five slots compare identical before/after | read reports a `Fault` → suspend row below |
| Rate changed mid-interval | armed at generation G; user sets rate | G's callback returns without re-arming; exactly one pending arm afterwards | — |
| **DW-157** duplicate request, key unchanged | a read in flight, `request()` again | joins — exactly one read issued, no queued re-run | a refusal reported *during* the fetch (`navigation.test.mjs:285` DW-9 stub) arms nothing and cannot loop |
| **DW-157** input changed mid-flight | read in flight for `ns=A`; scope resolves to `B`; further changes to `C` | dirty mark set; exactly **one** re-run after settle, issued against the latest key; N changes still yield one re-run | a failed re-run parks through connectivity, it does not chain |
| Tick meets a fault | the registered read returns any `FaultKind` | timer suspends; one `retryWhenReachable(REFRESH_KEY, resume)` park; zero arms at the seam | the park is the only trigger left; `connectivity.reset()` (sign-out) drops it together with `refresh.reset()` |
| `proposal-open` on the bound entity type + scope | bus event | paused; chip reads `Auto-refresh paused — a proposal is awaiting confirmation`; zero pending arms | an event for another entity type or scope is ignored |
| Two opens, one `proposal-closed` | two live proposal ids | stays paused until the last id closes, then re-arms once | a close for an id never opened is ignored |
| A proposal whose close never arrives | `proposal-open` carrying `expiresAt` (AD-6, 10 min) | driving the seam past `expiresAt` drops the id and re-arms | resume still requires no fault and `rate > 0` |
| `proposal-open` lands while a tick's read is in flight | | the landing read updates the store and does **not** re-arm; the pause survives | — |
| Leave and return to a screen | rate set, navigate away, navigate back | the stored rate is restored from `PreferenceStore` | a stored rate no longer in `refreshRates`, or an unparseable blob → descriptor default, no throw |
| Descriptor declares an unpublished rate | `refreshRates: [30]` with no matching chip string | `screen-mirror.mjs` throws naming the rate and `strings.ts` | build fails; no partial mirror is written |

</intent-contract>

## Code Map

- `src/OcuPilot/Screen/Descriptor/Base.cls` — `:22-33` field list, `:286` `ToolIdentifier()` is the accessor pattern to copy; `:35` already reserves "the refresh declarations" for this story.
- `src/OcuPilot/Screen/Descriptor/Home.cls` — `:41` the only descriptor; gains `refreshes: false`.
- `src/OcuPilot/Screen/Registry.cls` — `Validate()` `:123`, refusal messages `:135-178` (`:164` is the shape to copy).
- `ui/tools/screen-mirror.mjs` — `buildMirror()` `:211`, emitted interface `:312`, and the unknown-entity-type throw `:230-236` — the exact shape for the unpublished-rate throw.
- `ui/src/app/core/screens.generated.ts` — `ScreenDeclaration` `:49-71`; **generated, never hand-edited**.
- `ui/src/app/core/navigation.ts` — DW-157's site. `load()` `:304-323` fills the in-flight slot *before* the fetch starts (deliberate; keep that property); `reload()` `:347`, `noteForbidden()` `:335`, `runLoad()` `:365`, failure park `:380`, `generation` `:236`.
- `ui/tools/navigation.test.mjs` — `:247-283` the stale DW-157 pin (asserts `calls.length === 1`); `:285-298` the DW-9 stub, which calls `noteForbidden()` synchronously inside every `requestJson` and always answers 403.
- `ui/src/app/core/connectivity.ts` — `schedule` seam `:52`/`:58`/`:94-98`; `retryWhenReachable` `:215`; `note()` arming rules `:148-166`; `drain()` `:269-276`; `reset()` `:189`.
- `ui/src/app/core/session.ts` — `:305-311` and `:756-770`: the generation-guard idiom for a seam with no cancel handle.
- `ui/src/app/core/fault.ts` — `FaultKind` `:40-46`, `classifyFault(result, path)` `:68`, `isBannerFault` `:101`.
- `ui/src/app/core/entity-ref.ts` — `EntityRef` `:42-46`, `entityRefKey` `:59`, `scopeFor` `:89`. The bus routes on these; do not re-derive.
- `ui/src/app/core/scope.ts` — `onScopeChange()` `:405-413` (resolved-scope-only channel, names this story); `namespace()` `:201`.
- `ui/src/app/core/preferences.ts` — `PREFERENCE_KEYS` `:30` (closed allow-list), `UNLISTED_KEY_MESSAGE` `:33`, throw at `:117`, `sideBarOpen()` `:105` is the typed-accessor pattern.
- `ui/src/app/core/strings.ts` — `statusAutoRefreshOff:186`, `statusAutoRefreshOn:188`, `statusAutoRefreshPaused:190`, `statusLastUpdate:192`. `ui/tools/strings.test.mjs` re-derives the expected list from EXPERIENCE.md at run time, so an invented string fails the suite.
- `ui/src/app/shell/command-bar.ts` — spacer anchor `:97`, documented chip placeholder `:43-46`, `screen` computed `:113`, unavailable-control pattern `:86-95`.
- `ui/src/app/shell/status-bar.ts` — stamp slot `:78-80`, `hasStamp` hard `false` `:150-153`.
- `ui/src/app/app.ts` — `:205-211` the sign-out teardown block (`instance/navigation/scope/connectivity.reset()`); `ui/src/main.ts:103-105` `onScopeChange` wiring, `:111-112` / `:128` `useValue` provider style.

## Tasks & Acceptance

**Execution:**
- `src/OcuPilot/Screen/Descriptor/Base.cls` — add `Refreshes()` and `RefreshRates()` accessors and document the two declared fields — the descriptor is the single source (AD-5/AD-43).
- `src/OcuPilot/Screen/Descriptor/Home.cls` — declare `"refreshes": false, "refreshRates": []` — Home is not one of EXPERIENCE.md's auto-refresh screens.
- `src/OcuPilot/Screen/Registry.cls` — extend `Validate()`: rates must be empty unless `refreshes`, and otherwise positive ascending integer seconds — a malformed declaration fails at install, not at render.
- `ui/tools/screen-mirror.mjs` — carry both fields into `ScreenDeclaration`; throw when a declared rate has no chip string in `strings.ts` — makes DW-126's missing copy a build failure instead of invented text.
- `ui/src/app/core/screens.generated.ts` — regenerate via `node tools/screen-mirror.mjs`; never hand-edit.
- `ui/src/app/core/single-flight.ts` — **new**: `createSingleFlight(run, keyOf)` — join on unchanged key, mark-dirty-and-re-run-once on changed key. The general answer to DW-4 / DW-102 / **DW-157**.
- `ui/src/app/core/navigation.ts` — put `load()`/`reload()` on the primitive with the resolved namespace as key, keeping the fill-slot-before-fetch property — closes **DW-157**.
- `ui/src/app/core/change-bus.ts` — **new**: one bus carrying `changed` / `proposal-open` (with `expiresAt`) / `proposal-closed`, routed on the AD-13 triple — built before there is a publisher (AD-14/AD-43).
- `ui/src/app/core/screen-store.ts` — **new**: per-descriptor signal store (AD-19 slots) with `rate`, `sort`, `filter`, `maxRows` persisted and `data`, `selection`, `scroll`, `truncated`, `lastUpdate` not.
- `ui/src/app/core/preferences.ts` — declare one new allow-list key holding a descriptor→rate map, plus its typed accessor — keeps the closed list closed.
- `ui/src/app/core/refresh.ts` — **new**: `RefreshService` — bind/unbind, one generation-guarded arm, the three-condition resume predicate, fault suspend + one connectivity park, bus subscription, expiry sweep.
- `ui/src/main.ts` / `ui/src/app/app.ts` — provide the three services by `useValue`; add `refresh.reset()` to the sign-out teardown block.
- `ui/src/app/shell/command-bar.ts` — render the chip at the spacer, advancing through the descriptor's permitted rates and back to off.
- `ui/src/app/shell/status-bar.ts` — drive `hasStamp` and the stamp text from the service.
- `ui/tools/single-flight.test.mjs`, `ui/tools/refresh.test.mjs`, `ui/tools/change-bus.test.mjs` — **new**; `ui/tools/navigation.test.mjs`, `ui/tools/screen-mirror.test.mjs`, `ui/src/app/shell/command-bar.spec.ts`, `ui/src/app/shell/status-bar.spec.ts` — extend. Cover every I/O matrix row.
- `src/OcuPilot/Test/Descriptor.cls`, `src/OcuPilot/Test/ScreenRegistry.cls` — extend for the two new fields and their refusals.

**Acceptance Criteria:**
- Given a descriptor declaring `refreshes` and its rates, when the framework binds it, then one shared timer, one persisted per-screen setting and one silent re-fetch serve it, and no screen file contains a timer of its own (AD-43).
- Given a bound screen, when the rate, a proposal event, a fault, an unbind or a sign-out changes the state, then exactly one pending arm exists afterwards and no stale generation ever re-arms.
- Given the chip and the stamp, when they render and when a tick updates them, then neither node nor any ancestor carries `aria-live`, `role="status"` or `role="alert"`, and no live region is mutated by a tick.
- **Integration AC (Rule 1).** Given `NavigationService` — a real consumer of the new primitive, exercised against the real module, not a mock — when a scope change lands while its map read is in flight, then exactly two reads are issued and the second carries the new namespace; when `reload()` is called twice with an unchanged namespace, exactly one is issued; and the DW-9 403 stub at `navigation.test.mjs:285` still issues exactly one. (**DW-157**)
- **Integration AC (Rule 1).** Given `CommandBar` and `StatusBar` as consumers, when the service reports a rate and a last-update time for the active screen, then the chip renders the matching published literal and `hasStamp` becomes true — asserted through the component runner's DOM, never the service's internals.
- Given a refreshing screen with no registered read, when the framework binds it, then binding is refused naming the descriptor — the framework never issues a read of its own (AD-36).

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs (Rule 6).** AD-43 (the framework and the proposal pause), AD-19 (signal store keyed by descriptor; components read signals), AD-5 (the descriptor declares it), AD-14 (one bus, closed entity-type enum, re-fetch never patch), AD-13 (the `(type, scope, id)` triple), AD-36 (one bounded descriptor-declared read), AD-6/AD-34/AD-40 (proposal open, close, expiry, sibling cancel, turn death), AD-44 (namespace is data scope; switching re-fetches, never re-routes), AD-8 (privilege re-checked every tick server-side; a 403 is never retried), AD-28 (the token timer is the API service's; this is a second, unrelated timer and must not race it), AD-47 (`localStorage` carve-out discipline), AD-12/AD-39 (one flat envelope), AD-37 (a re-fetch that no longer resolves renders "no longer present").

**Consumes:** Story 1.13 — `fault.ts` (`FaultKind`, `classifyFault`), `connectivity.ts` (`retryWhenReachable`, `subscribe`, `reset`, the `schedule` seam shape). Story 1.11 — `scope.ts` `onScopeChange`, `entity-ref.ts`. Story 1.9 — the descriptor registry and `screen-mirror.mjs`. Story 1.10 — the command bar's spacer anchor and the status bar's stamp slot. Story 1.2 — `strings.ts`.

**Consumed-by:** Story 2.3 (registers the descriptor-declared read the tick calls), 2.4 (the data table fills the store's sort/filter/selection/maxRows slots), 2.5–2.12 (the ten refreshing list screens), Epic 2 writes (publish `changed` on the bus), Epic 5 (publishes `proposal-open`/`proposal-closed`), Story 1.15 (the reduced form's link-out card shares the command-bar row).

**NFR tripwire check (Rule 5) — passes; no intent gap.** The ACs name no numeric cadence: the rate is descriptor-declared, and every cadence, backoff and expiry is observable as the `delayMs` argument handed to the injected `schedule` seam. The timer is therefore falsifiable without waiting, and the one number that does appear in published copy (`10 s`) is asserted against that argument. Nothing here is unmeasurable, contradictory or impossible as worded.

**Decision (overnight) — Release 1 permits `off` and `10 s`, and nothing else.** EXPERIENCE.md `:561` lists `5 s · 10 s · 30 s · 60 s` inside an explicit `[ASSUMPTION]` marker; the Fixed-strings table publishes exactly three chip literals, and `statusAutoRefreshOn` is the fixed text `Auto-refresh: every 10 s` with no `<n>` placeholder. `strings.test.mjs` re-derives its expected list from EXPERIENCE.md, so adding copy for 5/30/60 s would fail the suite — inventing it is not available. The *mechanism* takes a list of permitted rates; the *published copy* admits one non-off value. The mirror refuses a declared rate with no chip string, so the blockage is a build failure rather than a comment, and publishing copy later makes those rates legal with no framework change. This is a fresh **DW-126** occurrence (owner's call, escalated) — not resolved here.

**Decision (overnight) — the chip advances through the permitted rates; there is no menu.** A menu needs an accessible name and per-option labels, none of which are published (DW-126). A chip whose visible literal *is* its accessible name invents nothing. With one published rate it reads as a toggle; with four it cycles. A menu is deferred to whenever the copy lands.

**Decision (overnight) — the stamp renders in the status bar, the chip in the command bar.** DESIGN.md `:1037` puts a stamp in the command bar while `:890`/`:1021` and EXPERIENCE.md `:318` put it in the status bar, with no precedence rule (**DW-139**, escalated). Three things break the tie without amending either document: EXPERIENCE.md `:318` states the division of labour outright ("a readout, not a control — the command-bar chip is the control"), the status bar already carries a live `hasStamp` slot naming this story, and the epic context assigns 1.14 "the command bar's rate chip and the status bar's stamp". Fresh DW-139 occurrence.

**Decision (overnight) — "never announced" means no live region, not `aria-hidden`.** EXPERIENCE.md `:583` places the stamp and the ticks outside the polite `role="status"` set. Hiding them from the accessibility tree would remove information a screen-reader user can otherwise read on demand, and the chip is a control. Both render as ordinary non-live content; the pin is the *absence* of live-region attributes on those nodes and their ancestors.

**Decision (overnight) — AC 4's bounded read is a seam here, not an implementation.** No client read layer, max-rows cap or truncation flag exists (Home makes no data read; `tableRowCapNotice` is published and unused), and Story 2.3 owns "one descriptor-declared read serves both the screen and its tool". This story therefore owns the *contract*: the tick calls the screen's registered read with the store's `maxRows` and records `truncated`, and refuses to bind a refreshing screen that registered none. Epic 2 supplies the read.

**Why join-versus-queue gets one primitive.** A naive queue re-runs on *every* request, which is why it loops against the DW-9 stub. Keying the decision on the input instead makes the refusal path arm nothing (key unchanged) while a scope change re-runs once (key changed). `ScopeService.load()` is deliberately left alone: its input is the instance-wide namespace list, so no caller can change its key mid-flight and the seam would be inert *(inference)*.

**The 1.13 caution, applied.** Three times in Story 1.13 a recovery path was cancelled by the very event meant to drive it. Four places here are the same shape, each with its own matrix row: (a) resume is a predicate over three conditions, so a `proposal-closed` cannot resume a fault-suspended timer; (b) live proposals are a **set of ids**, so two opens and one close stays paused; (c) `proposal-open` carries `expiresAt` and the framework sweeps it at the seam, so a close that never arrives does not strand the pause (AD-34's sibling-cancel and AD-40's turn-death are further closes, handled identically); (d) a fault suspension's only trigger is the connectivity park, which `connectivity.reset()` drops — correct only because `refresh.reset()` joins the same sign-out teardown. Each test must instantiate the component that does the cancelling and use a multi-reader ordering, or the mutation stays green (Story 1.13 `:298`).

## Verification

**How it is checked.** Cadence, expiry and suspension are asserted at the injected `schedule` and `now` seams — `schedule: (run, delayMs) => scheduled.push({run, delayMs})`, driven by hand and asserted on `delayMs`, as `ui/tools/fault.test.mjs:72,86-89,240,252` does. **No test waits on a real clock.** The ObjectScript half (descriptor accessors, registry refusals) runs **live** against the `ocupilot` container; everything else runs at a seam or in jsdom. Component specs use no fake timers — none exist here; they neutralize the seam with `schedule: () => {}` (`fault-banner.wire.spec.ts:73-79`) and settle with a macrotask flush (`:97`).

**Commands:**
- `cd ui && npm run test:tools` — expected: green, including the new `single-flight`, `refresh` and `change-bus` suites and the amended `navigation` and `screen-mirror` suites.
- `cd ui && npm run test:components` — expected: green, including the amended `command-bar` and `status-bar` specs.
- `cd ui && npm run build` — expected: succeeds; `prebuild` runs `version-guard`, `client-lint` and `screen-mirror --check`, so a hand-edited or stale mirror fails here.
- `node tools/screen-mirror.mjs` from `ui/` after the descriptor change — expected: regenerates `screens.generated.ts` with both new fields.
- IRIS: load and compile `src/OcuPilot/` with the `iris-dev` MCP tools, **always `server: "ocupilot-iris"`**. Then `iris_execute_tests` — **one test class per tool call, per message, awaited; never two in one message and never a re-submit on a client-side timeout** (`.claude/rules/objectscript-testing.md`). Run `OcuPilot.Test.Descriptor`, then `OcuPilot.Test.ScreenRegistry`. Confirm totals with the numeric-run-index SQL probe before reporting green. Never `docker compose up`/`down`/`restart`.
- `bash scripts/lint-docs.sh` — expected: clean.

**Pinning tests (Rule 19).** One mutation per AC; `mutation:` lines are written at implement time.
- One framework, one timer, no per-screen timer → `ui/tools/refresh.test.mjs` "one arm at a time across bind, rate change and unbind" + a source scan asserting no `setTimeout`/`setInterval` under `ui/src/app/areas/`. mutation: _(implement stage)_
- No stale generation re-arms → `ui/tools/refresh.test.mjs` "a rate change orphans the previous generation". mutation: _(implement stage)_
- A tick is silent and preserves the five untouched slots → `ui/tools/refresh.test.mjs` "a tick replaces data, truncated and lastUpdate and nothing else". mutation: _(implement stage)_
- No live region on chip or stamp → `ui/src/app/shell/status-bar.spec.ts` + `command-bar.spec.ts` "the stamp and chip are outside every live region". mutation: _(implement stage)_
- **DW-157** join vs. queue → `ui/tools/navigation.test.mjs` "a scope change mid-flight re-runs the map read once against the new namespace" (replacing the stale `calls.length === 1` pin at `:247-283`), plus the unchanged-key and DW-9 rows. mutation: _(implement stage)_
- Chip and stamp render from the service → `ui/src/app/shell/command-bar.spec.ts` / `status-bar.spec.ts` DOM assertions. mutation: _(implement stage)_
- Refresh suspends on a fault and resumes only from the park → `ui/tools/refresh.test.mjs` "a fault suspends and parks exactly one re-arm". mutation: _(implement stage)_
- Two opens, one close, stays paused → `ui/tools/refresh.test.mjs` "the live-proposal set is not a boolean". mutation: _(implement stage)_
- An unclosed proposal expires at the seam → `ui/tools/refresh.test.mjs` "a close that never arrives does not strand the pause". mutation: _(implement stage)_
- Per-screen rate persists, and an unpermitted stored rate falls back → `ui/tools/refresh.test.mjs` against a map-backed `PreferenceStorage`. mutation: _(implement stage)_
- An unpublished rate fails the build → `ui/tools/screen-mirror.test.mjs` "a declared rate with no chip string throws". mutation: _(implement stage)_
- Descriptor fields and registry refusals → `OcuPilot.Test.Descriptor`, `OcuPilot.Test.ScreenRegistry` (live). mutation: _(implement stage)_
- Binding without a registered read is refused → `ui/tools/refresh.test.mjs`. mutation: _(implement stage)_

**Ledger (`owned_ledger=DW-157`).** Addressed by the `single-flight.ts` task, the `navigation.ts` task, two I/O matrix rows and the first Integration AC.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Planning only; halt after planning was directed. Nothing was implemented, and no commit was made.
